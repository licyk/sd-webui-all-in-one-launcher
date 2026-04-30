<#
.SYNOPSIS
    Windows GUI launcher for sd-webui-all-in-one PowerShell installers.

.DESCRIPTION
    A Windows-only WPF launcher that installs and manages multiple AI WebUI /
    training tools through the sd-webui-all-in-one PowerShell installer scripts.

.NOTES
    Requirements:
    - Windows PowerShell 5.1+ or PowerShell 7+ on Windows
    - .NET/WPF support
#>

param()

$script:INSTALLER_LAUNCHER_GUI_VERSION = "0.1.0"
$script:APP_NAME = "installer-launcher"
$script:APP_TITLE = "SD WebUI All In One Installer Launcher GUI"
$script:SELF_REMOTE_URLS = @(
    "https://raw.githubusercontent.com/licyk/sd-webui-all-in-one-launcher/main/installer_launcher_gui.ps1",
    "https://gitee.com/licyk/sd-webui-all-in-one-launcher/raw/main/installer_launcher_gui.ps1"
)

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    Write-Error "installer_launcher_gui.ps1 only supports Windows."
    exit 1
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class LauncherWindowHelper {
    [StructLayout(LayoutKind.Sequential)]
    public struct AccentPolicy {
        public int AccentState;
        public int AccentFlags;
        public int GradientColor;
        public int AnimationId;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct WindowCompositionAttributeData {
        public int Attribute;
        public IntPtr Data;
        public int SizeOfData;
    }

    [DllImport("user32.dll")]
    public static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);

    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    public static void SetBlurState(IntPtr hwnd, int state) {
        var accent = new AccentPolicy();
        accent.AccentState = state;

        var accentStructSize = Marshal.SizeOf(accent);
        var accentPtr = Marshal.AllocHGlobal(accentStructSize);
        Marshal.StructureToPtr(accent, accentPtr, false);

        var data = new WindowCompositionAttributeData();
        data.Attribute = 19;
        data.SizeOfData = accentStructSize;
        data.Data = accentPtr;

        SetWindowCompositionAttribute(hwnd, ref data);
        Marshal.FreeHGlobal(accentPtr);
    }

    public static void EnableBlur(IntPtr hwnd) {
        SetBlurState(hwnd, 3);
    }

    public static void SetDarkMode(IntPtr hwnd, bool enabled) {
        int preference = enabled ? 1 : 0;
        DwmSetWindowAttribute(hwnd, 20, ref preference, sizeof(int));
    }

    public static void SetRounding(IntPtr hwnd, bool enabled) {
        int preference = enabled ? 2 : 1;
        DwmSetWindowAttribute(hwnd, 33, ref preference, sizeof(int));
    }
}

public class LauncherChoice {
    public string Name { get; set; }
    public string Label { get; set; }

    public LauncherChoice(string name, string label) {
        Name = name;
        Label = label;
    }

    public override string ToString() {
        return Label;
    }
}
"@ -ErrorAction SilentlyContinue | Out-Null

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:ConfigHome = Join-Path $env:APPDATA $script:APP_NAME
$script:ProjectConfigHome = Join-Path $script:ConfigHome "projects"
$script:LocalHome = Join-Path $env:LOCALAPPDATA $script:APP_NAME
$script:CacheHome = Join-Path $script:LocalHome "cache"
$script:LogHome = Join-Path $script:LocalHome "logs"
$script:MainConfigFile = Join-Path $script:ConfigHome "main.json"
$script:LogFile = Join-Path $script:LogHome ("installer-launcher-gui-{0}.log" -f (Get-Date -Format "yyyyMMdd"))
$script:AutoUpdateIntervalSeconds = 3600
$script:RunspacePool = $null

function New-ProjectRegistry {
    $commonInstallerHost = "https://github.com/licyk/sd-webui-all-in-one"
    $projects = [ordered]@{}

    $projects.sd_webui = [ordered]@{
        Key = "sd_webui"
        Name = "Stable Diffusion WebUI Installer"
        InstallerFile = "stable_diffusion_webui_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/stable_diffusion_webui_installer/stable_diffusion_webui_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/stable_diffusion_webui_installer/stable_diffusion_webui_installer.ps1",
            "$commonInstallerHost/raw/main/installer/stable_diffusion_webui_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/stable_diffusion_webui_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/stable_diffusion_webui_installer.ps1"
        )
        DefaultDir = "stable-diffusion-webui"
        DefaultBranch = "sd_webui_dev"
        Branches = [ordered]@{
            sd_webui_main = "AUTOMATIC1111 主分支"; sd_webui_dev = "AUTOMATIC1111 测试分支"; sd_webui_forge = "Forge 分支"
            sd_webui_reforge_main = "reForge 主分支"; sd_webui_reforge_dev = "reForge 测试分支"; sd_webui_forge_classic = "Forge-Classic 分支"
            sd_webui_forge_neo = "Forge-Neo 分支"; sd_webui_amdgpu = "AMDGPU 分支"; sd_next_main = "SD.NEXT 主分支"; sd_next_dev = "SD.NEXT 测试分支"
        }
        Scripts = [ordered]@{
            "launch.ps1" = "启动 Stable Diffusion WebUI"; "update.ps1" = "更新 Stable Diffusion WebUI"; "update_extension.ps1" = "更新扩展"
            "switch_branch.ps1" = "切换分支"; "terminal.ps1" = "打开交互终端"; "settings.ps1" = "管理设置"
            "download_models.ps1" = "下载模型"; "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_stable_diffusion_webui_installer.ps1" = "获取最新安装器并运行"
        }
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "InstallBranch", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoPreDownloadExtension", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableCUDAMalloc", "DisableEnvCheck")
    }

    $projects.comfyui = [ordered]@{
        Key = "comfyui"; Name = "ComfyUI Installer"; InstallerFile = "comfyui_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/comfyui_installer/comfyui_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/comfyui_installer/comfyui_installer.ps1",
            "$commonInstallerHost/raw/main/installer/comfyui_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/comfyui_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/comfyui_installer.ps1"
        )
        DefaultDir = "ComfyUI"; DefaultBranch = ""
        Branches = [ordered]@{}
        Scripts = [ordered]@{
            "launch.ps1" = "启动 ComfyUI"; "update.ps1" = "更新 ComfyUI"; "update_node.ps1" = "更新自定义节点"
            "terminal.ps1" = "打开交互终端"; "settings.ps1" = "管理设置"; "download_models.ps1" = "下载模型"
            "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_comfyui_installer.ps1" = "获取最新安装器并运行"
        }
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoPreDownloadNode", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror")
    }

    $projects.invokeai = [ordered]@{
        Key = "invokeai"; Name = "InvokeAI Installer"; InstallerFile = "invokeai_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/invokeai_installer/invokeai_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/invokeai_installer/invokeai_installer.ps1",
            "$commonInstallerHost/raw/main/installer/invokeai_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/invokeai_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/invokeai_installer.ps1"
        )
        DefaultDir = "InvokeAI"; DefaultBranch = ""
        Branches = [ordered]@{}
        Scripts = [ordered]@{
            "launch.ps1" = "启动 InvokeAI"; "update.ps1" = "更新 InvokeAI"; "update_node.ps1" = "更新节点"
            "terminal.ps1" = "打开交互终端"; "settings.ps1" = "管理设置"; "download_models.ps1" = "下载模型"
            "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_invokeai_installer.ps1" = "获取最新安装器并运行"
        }
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableCUDAMalloc", "DisableEnvCheck")
    }

    $projects.fooocus = [ordered]@{
        Key = "fooocus"; Name = "Fooocus Installer"; InstallerFile = "fooocus_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/fooocus_installer/fooocus_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/fooocus_installer/fooocus_installer.ps1",
            "$commonInstallerHost/raw/main/installer/fooocus_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/fooocus_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/fooocus_installer.ps1"
        )
        DefaultDir = "Fooocus"; DefaultBranch = "fooocus_main"
        Branches = [ordered]@{ fooocus_main = "lllyasviel/Fooocus"; ruined_fooocus_main = "runew0lf/RuinedFooocus"; fooocus_mre_main = "MoonRide303/Fooocus-MRE" }
        Scripts = [ordered]@{
            "launch.ps1" = "启动 Fooocus"; "update.ps1" = "更新 Fooocus"; "switch_branch.ps1" = "切换分支"; "terminal.ps1" = "打开交互终端"
            "settings.ps1" = "管理设置"; "download_models.ps1" = "下载模型"; "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_fooocus_installer.ps1" = "获取最新安装器并运行"
        }
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "InstallBranch", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror")
    }

    $projects.sd_trainer = [ordered]@{
        Key = "sd_trainer"; Name = "SD Trainer Installer"; InstallerFile = "sd_trainer_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/sd_trainer_installer/sd_trainer_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/sd_trainer_installer/sd_trainer_installer.ps1",
            "$commonInstallerHost/raw/main/installer/sd_trainer_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/sd_trainer_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/sd_trainer_installer.ps1"
        )
        DefaultDir = "SD-Trainer"; DefaultBranch = "sd_trainer_main"
        Branches = [ordered]@{ sd_trainer_main = "Akegarasu/SD-Trainer"; kohya_gui_main = "bmaltais/Kohya GUI" }
        Scripts = [ordered]@{
            "launch.ps1" = "启动 SD Trainer"; "update.ps1" = "更新 SD Trainer"; "switch_branch.ps1" = "切换分支"; "terminal.ps1" = "打开交互终端"
            "settings.ps1" = "管理设置"; "download_models.ps1" = "下载模型"; "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_sd_trainer_installer.ps1" = "获取最新安装器并运行"
        }
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "InstallBranch", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror")
    }

    $projects.sd_trainer_script = [ordered]@{
        Key = "sd_trainer_script"; Name = "SD Trainer Script Installer"; InstallerFile = "sd_trainer_script_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/sd_trainer_script_installer/sd_trainer_script_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/sd_trainer_script_installer/sd_trainer_script_installer.ps1",
            "$commonInstallerHost/raw/main/installer/sd_trainer_script_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/sd_trainer_script_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/sd_trainer_script_installer.ps1"
        )
        DefaultDir = "SD-Trainer-Script"; DefaultBranch = "sd_scripts_main"
        Branches = [ordered]@{
            sd_scripts_main = "kohya-ss/sd-scripts 主分支"; sd_scripts_dev = "kohya-ss/sd-scripts 测试分支"; sd_scripts_sd3 = "kohya-ss/sd-scripts SD3 分支"
            ai_toolkit_main = "ostris/ai-toolkit"; finetrainers_main = "a-r-r-o-w/finetrainers"; diffusion_pipe_main = "tdrussell/diffusion-pipe"; musubi_tuner_main = "kohya-ss/musubi-tuner"
        }
        Scripts = [ordered]@{
            "train.ps1" = "运行训练脚本"; "update.ps1" = "更新 SD-Trainer-Script"; "switch_branch.ps1" = "切换分支"; "terminal.ps1" = "打开交互终端"
            "settings.ps1" = "管理设置"; "download_models.ps1" = "下载模型"; "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_sd_trainer_script_installer.ps1" = "获取最新安装器并运行"
        }
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "InstallBranch", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableCUDAMalloc", "DisableEnvCheck")
    }

    $projects.qwen_tts_webui = [ordered]@{
        Key = "qwen_tts_webui"; Name = "Qwen TTS WebUI Installer"; InstallerFile = "qwen_tts_webui_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/qwen_tts_webui_installer/qwen_tts_webui_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/qwen_tts_webui_installer/qwen_tts_webui_installer.ps1",
            "$commonInstallerHost/raw/main/installer/qwen_tts_webui_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/qwen_tts_webui_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/qwen_tts_webui_installer.ps1"
        )
        DefaultDir = "qwen-tts-webui"; DefaultBranch = ""
        Branches = [ordered]@{}
        Scripts = [ordered]@{
            "launch.ps1" = "启动 Qwen TTS WebUI"; "update.ps1" = "更新 Qwen TTS WebUI"; "terminal.ps1" = "打开交互终端"
            "settings.ps1" = "管理设置"; "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_qwen_tts_webui_installer.ps1" = "获取最新安装器并运行"
        }
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoCleanCache", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableCUDAMalloc", "DisableEnvCheck")
    }

    return $projects
}

$script:Projects = New-ProjectRegistry

function Initialize-Directories {
    New-Item -ItemType Directory -Force -Path $script:ConfigHome, $script:ProjectConfigHome, $script:CacheHome, $script:LogHome | Out-Null
}

function ConvertTo-PlainHashtable {
    param($InputObject)
    $hash = @{}
    if ($null -eq $InputObject) { return $hash }
    foreach ($property in $InputObject.PSObject.Properties) {
        $hash[$property.Name] = $property.Value
    }
    return $hash
}

function Test-DictionaryKey {
    param($Dictionary, [string]$Key)
    if ($null -eq $Dictionary) { return $false }
    if ($Dictionary -is [hashtable]) { return $Dictionary.ContainsKey($Key) }
    if ($Dictionary -is [System.Collections.IDictionary]) { return $Dictionary.Contains($Key) }
    return $false
}

function Get-DefaultMainConfig {
    [ordered]@{
        CURRENT_PROJECT = ""
        AUTO_UPDATE_ENABLED = $true
        SHOW_WELCOME_SCREEN = $true
        LOG_LEVEL = "DEBUG"
        PROXY_MODE = "auto"
        MANUAL_PROXY = ""
        AUTO_UPDATE_LAST_CHECK = 0
    }
}

function Get-DefaultProjectConfig {
    param([string]$ProjectKey)
    $project = $script:Projects[$ProjectKey]
    [ordered]@{
        INSTALL_PATH = ""
        INSTALL_BRANCH = $project.DefaultBranch
        CORE_PREFIX = ""
        PYTORCH_MIRROR_TYPE = ""
        PYTHON_VERSION = ""
        PROXY = ""
        GITHUB_MIRROR = ""
        HUGGINGFACE_MIRROR = ""
        EXTRA_INSTALL_ARGS = ""
        DISABLE_PYPI_MIRROR = $false
        DISABLE_PROXY = $false
        DISABLE_UV = $false
        DISABLE_GITHUB_MIRROR = $false
        DISABLE_MODEL_MIRROR = $false
        DISABLE_HUGGINGFACE_MIRROR = $false
        DISABLE_CUDA_MALLOC = $false
        DISABLE_ENV_CHECK = $false
        NO_PRE_DOWNLOAD_EXTENSION = $false
        NO_PRE_DOWNLOAD_NODE = $false
        NO_PRE_DOWNLOAD_MODEL = $false
        NO_CLEAN_CACHE = $false
        ScriptParams = @{}
        ScriptArgs = @{}
    }
}

function Copy-Dictionary {
    param([System.Collections.IDictionary]$Source)
    $copy = [ordered]@{}
    foreach ($key in $Source.Keys) {
        $copy[$key] = $Source[$key]
    }
    return $copy
}

function Read-JsonConfig {
    param([string]$Path, [System.Collections.IDictionary]$Default)
    if (-not (Test-Path $Path -PathType Leaf)) {
        return (Copy-Dictionary $Default)
    }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return (Copy-Dictionary $Default) }
        $loaded = ConvertTo-PlainHashtable ($raw | ConvertFrom-Json)
        $merged = Copy-Dictionary $Default
        foreach ($key in $loaded.Keys) {
            $merged[$key] = $loaded[$key]
        }
        if ($merged.Contains("ScriptArgs") -and $null -ne $merged["ScriptArgs"] -and -not ($merged["ScriptArgs"] -is [System.Collections.IDictionary])) {
            $merged["ScriptArgs"] = ConvertTo-PlainHashtable $merged["ScriptArgs"]
        }
        if ($merged.Contains("ScriptParams") -and $null -ne $merged["ScriptParams"] -and -not ($merged["ScriptParams"] -is [System.Collections.IDictionary])) {
            $merged["ScriptParams"] = ConvertTo-PlainHashtable $merged["ScriptParams"]
        }
        if ($merged.Contains("ScriptParams") -and $null -ne $merged["ScriptParams"]) {
            foreach ($scriptName in @($merged["ScriptParams"].Keys)) {
                if ($null -ne $merged["ScriptParams"][$scriptName] -and -not ($merged["ScriptParams"][$scriptName] -is [System.Collections.IDictionary])) {
                    $merged["ScriptParams"][$scriptName] = ConvertTo-PlainHashtable $merged["ScriptParams"][$scriptName]
                }
            }
        }
        return $merged
    } catch {
        Write-Log WARN "failed to read config: path=$Path error=$($_.Exception.Message)"
        return (Copy-Dictionary $Default)
    }
}

function Save-JsonConfig {
    param([string]$Path, [System.Collections.IDictionary]$Config)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    $Config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-ProjectConfigPath {
    param([string]$ProjectKey)
    Join-Path $script:ProjectConfigHome "$ProjectKey.json"
}

function Get-ProjectConfig {
    param([string]$ProjectKey)
    Read-JsonConfig -Path (Get-ProjectConfigPath $ProjectKey) -Default (Get-DefaultProjectConfig $ProjectKey)
}

function Save-ProjectConfig {
    param([string]$ProjectKey, [System.Collections.IDictionary]$Config)
    Save-JsonConfig -Path (Get-ProjectConfigPath $ProjectKey) -Config $Config
}

function Normalize-LogLevel {
    param([string]$Value)
    switch (($Value + "").ToUpperInvariant()) {
        "DEBUG" { "DEBUG"; break }
        "INFO" { "INFO"; break }
        "WARN" { "WARN"; break }
        "ERROR" { "ERROR"; break }
        default { "DEBUG" }
    }
}

function Normalize-ProxyMode {
    param([string]$Value)
    switch (($Value + "").ToLowerInvariant()) {
        "manual" { "manual"; break }
        "off" { "off"; break }
        "none" { "off"; break }
        "disabled" { "off"; break }
        default { "auto" }
    }
}

function Get-LogLevelValue {
    param([string]$Level)
    switch ($Level) {
        "DEBUG" { 10; break }
        "INFO" { 20; break }
        "WARN" { 30; break }
        "ERROR" { 40; break }
        default { 20 }
    }
}

function Test-ShouldLog {
    param([string]$Level)
    (Get-LogLevelValue $Level) -ge (Get-LogLevelValue $script:MainConfig["LOG_LEVEL"])
}

function ConvertTo-SafeLogText {
    param([string]$Message)
    if ($null -eq $Message) { return "" }
    $safe = $Message -replace '(?i)(token|password|passwd|secret|api_key|access_key|private_key)=\S+', '$1=<redacted>'
    $safe = $safe -replace '(?i)(token|password|passwd|secret|api_key|access_key|private_key):\S+', '$1:<redacted>'
    $safe = $safe -replace '(?i)(https?://)[^/@\s]+:[^/@\s]+@', '$1<redacted>@'
    return $safe
}

function Format-LogArgs {
    param([string[]]$Args)
    if ($null -eq $Args -or $Args.Count -eq 0) { return "(none)" }
    $items = @()
    foreach ($arg in $Args) {
        $items += ('"{0}"' -f ((ConvertTo-SafeLogText $arg) -replace '"', '\"'))
    }
    return ($items -join " ")
}

function Split-Shlex {
    param([Parameter(Mandatory)][string]$InputString)

    $result = [System.Collections.Generic.List[string]]::new()
    $current = ""
    $inSingleQuote = $false
    $inDoubleQuote = $false
    $escapeNext = $false

    foreach ($char in $InputString.ToCharArray()) {
        if ($escapeNext) {
            $current += $char
            $escapeNext = $false
            continue
        }

        if (-not $inDoubleQuote -and $char -eq "'") {
            $inSingleQuote = -not $inSingleQuote
            continue
        }

        if (-not $inSingleQuote -and $char -eq '"') {
            $inDoubleQuote = -not $inDoubleQuote
            continue
        }

        if (-not $inSingleQuote -and -not $inDoubleQuote -and [char]::IsWhiteSpace($char)) {
            if ($current.Length -gt 0) {
                $result.Add($current)
                $current = ""
            }
            continue
        }

        $current += $char
    }
    if ($current.Length -gt 0) { $result.Add($current) }
    if ($inSingleQuote -or $inDoubleQuote) { throw "Unterminated quoted string" }
    return $result
}

function Join-Shlex {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $params = $Arguments.ForEach{
        if ($_ -match '\s|"') { "'{0}'" -f ($_ -replace "'", "''") }
        else { $_ }
    } -join ' '

    return $params
}

function Test-ArgsContains {
    param([string[]]$Args, [string]$ParamName)
    foreach ($arg in @($Args)) {
        if ($arg -ieq $ParamName) { return $true }
    }
    return $false
}

function Write-Log {
    param([string]$Level, [string]$Message)
    if ($null -eq $script:MainConfig) { $minLevel = "DEBUG" } else { $minLevel = $script:MainConfig["LOG_LEVEL"] }
    if ((Get-LogLevelValue $Level) -lt (Get-LogLevelValue $minLevel)) { return }
    try {
        $line = "{0} | {1} | pid={2} | {3}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $PID, (ConvertTo-SafeLogText $Message)
        Add-Content -LiteralPath $script:LogFile -Encoding UTF8 -Value $line
    } catch {
        Write-Warning "无法写入日志文件: $($script:LogFile)"
    }
}

function Show-Message {
    param([string]$Message, [string]$Title = "提示", [string]$Icon = "Information")
    [System.Windows.MessageBox]::Show($Message, $Title, "OK", $Icon) | Out-Null
}

function Report-UiError {
    param([string]$Context, [object]$ErrorObject, [bool]$ShowDialog = $true)
    $message = "未知错误"
    $detail = ""
    if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) {
        $message = $ErrorObject.Exception.Message
        $detail = "line=$($ErrorObject.InvocationInfo.ScriptLineNumber) command=$($ErrorObject.InvocationInfo.Line) stack=$($ErrorObject.ScriptStackTrace)"
    } elseif ($ErrorObject -is [System.Exception]) {
        $message = $ErrorObject.Message
        $detail = $ErrorObject.StackTrace
    } elseif ($null -ne $ErrorObject) {
        $message = [string]$ErrorObject
    }
    Write-Log ERROR "$Context failed: $message $detail"
    if ($ShowDialog) {
        try {
            Show-Message "$Context 失败:`n$message`n`n日志: $($script:LogFile)" "启动器错误" "Error"
        } catch {}
    }
}

function Confirm-Message {
    param([string]$Message, [string]$Title = "确认")
    $result = [System.Windows.MessageBox]::Show($Message, $Title, "YesNo", "Warning")
    return $result -eq [System.Windows.MessageBoxResult]::Yes
}

function Show-InputDialog {
    param([string]$Title, [string]$Message, [string]$DefaultText = "")
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="$Title" Width="460" Height="180" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
    </Grid.RowDefinitions>
    <TextBlock Grid.Row="0" Text="$Message" TextWrapping="Wrap" Margin="0,0,0,12"/>
    <TextBox Grid.Row="1" Name="InputBox" Height="28"/>
    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Bottom">
      <Button Name="OkBtn" Content="确定" Width="86" Margin="0,0,8,0"/>
      <Button Name="CancelBtn" Content="取消" Width="86"/>
    </StackPanel>
  </Grid>
</Window>
"@
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $box = $window.FindName("InputBox")
    $box.Text = $DefaultText
    $result = $null
    $inputDialogResult = $null
    $window.FindName("OkBtn").Add_Click({ $inputDialogResult = $box.Text; $window.DialogResult = $true; $window.Close() }.GetNewClosure())
    $window.FindName("CancelBtn").Add_Click({ $inputDialogResult = $null; $window.DialogResult = $false; $window.Close() }.GetNewClosure())
    if ($window.ShowDialog()) { $result = $inputDialogResult }
    return $result
}

function Get-WindowsSystemProxy {
    try {
        $internet = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction Stop
        if ($internet.ProxyEnable -ne 1 -or [string]::IsNullOrWhiteSpace($internet.ProxyServer)) { return "" }
        $proxyAddr = [string]$internet.ProxyServer
        if (($proxyAddr -match "http=(.*?);") -or ($proxyAddr -match "https=(.*?);")) {
            $value = $matches[1].ToString().Replace("http://", "").Replace("https://", "")
            return "http://$value"
        }
        if ($proxyAddr -match "socks=(.*)") {
            $value = $matches[1].ToString().Replace("socks://", "")
            return "socks://$value"
        }
        $proxyAddr = $proxyAddr.Replace("http://", "").Replace("https://", "")
        return "http://$proxyAddr"
    } catch {
        Write-Log WARN "failed to detect windows proxy: $($_.Exception.Message)"
        return ""
    }
}

function Clear-ProxyEnvironment {
    Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:http_proxy -ErrorAction SilentlyContinue
    Remove-Item Env:https_proxy -ErrorAction SilentlyContinue
    Write-Log INFO "proxy disabled for gui process"
}

function Set-ProxyEnvironment {
    param([string]$ProxyValue, [string]$Source)
    if ([string]::IsNullOrWhiteSpace($ProxyValue)) { return }
    $env:NO_PROXY = "localhost,127.0.0.1,::1"
    $env:no_proxy = $env:NO_PROXY
    $env:HTTP_PROXY = $ProxyValue
    $env:HTTPS_PROXY = $ProxyValue
    $env:http_proxy = $ProxyValue
    $env:https_proxy = $ProxyValue
    Write-Log INFO "proxy configured: source=$Source value=$(ConvertTo-SafeLogText $ProxyValue)"
}

function Configure-ProxyFromMainConfig {
    $mode = Normalize-ProxyMode $script:MainConfig["PROXY_MODE"]
    $script:MainConfig["PROXY_MODE"] = $mode
    if ($mode -eq "off") {
        Clear-ProxyEnvironment
        return
    }
    if ($mode -eq "manual") {
        if ([string]::IsNullOrWhiteSpace($script:MainConfig["MANUAL_PROXY"])) {
            Clear-ProxyEnvironment
            return
        }
        Set-ProxyEnvironment -ProxyValue $script:MainConfig["MANUAL_PROXY"] -Source "manual"
        return
    }
    if (-not [string]::IsNullOrWhiteSpace($env:HTTP_PROXY) -or -not [string]::IsNullOrWhiteSpace($env:HTTPS_PROXY) -or -not [string]::IsNullOrWhiteSpace($env:http_proxy) -or -not [string]::IsNullOrWhiteSpace($env:https_proxy)) {
        Write-Log DEBUG "proxy environment already exists, skip auto proxy"
        return
    }
    $proxy = Get-WindowsSystemProxy
    if (-not [string]::IsNullOrWhiteSpace($proxy)) {
        Set-ProxyEnvironment -ProxyValue $proxy -Source "windows"
    }
}

function Test-ProjectParam {
    param($Project, [string]$ParamName)
    return @($Project.Params) -contains $ParamName
}

function Get-ManagementScriptParams {
    param([string]$ProjectKey, [string]$ScriptName)
    switch ($ScriptName) {
        "launch.ps1" { return @("CorePrefix", "BuildMode", "DisablePyPIMirror", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableGithubMirror", "UseCustomGithubMirror", "DisableUV", "LaunchArg", "EnableShortcut", "DisableCUDAMalloc", "DisableEnvCheck", "NoPause") }
        "download_models.ps1" { return @("CorePrefix", "BuildMode", "BuildWithModel", "DisableProxy", "UseCustomProxy", "DisableUpdate", "DisableModelMirror", "NoPause") }
        "reinstall_pytorch.ps1" { return @("CorePrefix", "BuildMode", "BuildWithTorch", "BuildWithTorchReinstall", "DisablePyPIMirror", "DisableUpdate", "DisableUV", "DisableProxy", "UseCustomProxy", "NoPause") }
        "settings.ps1" { return @("CorePrefix", "DisableProxy", "UseCustomProxy", "NoPause") }
        "switch_branch.ps1" { return @("CorePrefix", "BuildMode", "BuildWithBranch", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableGithubMirror", "UseCustomGithubMirror", "NoPause") }
        "update.ps1" {
            if ($ProjectKey -eq "invokeai") { return @("CorePrefix", "BuildMode", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisablePyPIMirror", "DisableUV", "NoPause") }
            return @("CorePrefix", "BuildMode", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableGithubMirror", "UseCustomGithubMirror", "NoPause")
        }
        { $_ -in @("update_node.ps1", "update_extension.ps1") } { return @("CorePrefix", "BuildMode", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableGithubMirror", "UseCustomGithubMirror", "NoPause") }
        default { return @("NoPause") }
    }
}

function Test-ManagementScriptParam {
    param([string]$ProjectKey, [string]$ScriptName, [string]$ParamName)
    return @((Get-ManagementScriptParams $ProjectKey $ScriptName)) -contains $ParamName
}

function Test-ScriptParamIsFlag {
    param([string]$ParamName)
    return $ParamName -in @("BuildMode", "DisablePyPIMirror", "DisableUpdate", "DisableProxy", "DisableHuggingFaceMirror", "DisableGithubMirror", "DisableUV", "EnableShortcut", "DisableCUDAMalloc", "DisableEnvCheck", "DisableModelMirror", "BuildWithTorchReinstall")
}

function Get-SelectedScriptName {
    param($ScriptCombo)
    if ($null -eq $ScriptCombo -or $null -eq $ScriptCombo.SelectedItem) { return "" }
    $selected = $ScriptCombo.SelectedItem
    if ($selected -is [System.Windows.Controls.ComboBoxItem]) { return [string]$selected.Tag }
    if ($null -ne $selected.PSObject.Properties["Name"]) { return [string]$selected.PSObject.Properties["Name"].Value }
    return [string]$selected
}

function Get-ScriptParamLabel {
    param([string]$ParamName)
    switch ($ParamName) {
        "CorePrefix" { "内核路径前缀 -CorePrefix"; break }
        "BuildMode" { "构建模式 -BuildMode"; break }
        "BuildWithModel" { "构建后下载模型编号 -BuildWithModel"; break }
        "BuildWithTorch" { "PyTorch 版本编号 -BuildWithTorch"; break }
        "BuildWithTorchReinstall" { "强制重装 PyTorch -BuildWithTorchReinstall"; break }
        "BuildWithBranch" { "构建分支 -BuildWithBranch"; break }
        "DisablePyPIMirror" { "禁用 PyPI 镜像 -DisablePyPIMirror"; break }
        "DisableUpdate" { "禁用更新检查 -DisableUpdate"; break }
        "DisableProxy" { "禁用自动代理 -DisableProxy"; break }
        "UseCustomProxy" { "自定义代理 -UseCustomProxy"; break }
        "DisableHuggingFaceMirror" { "禁用 HuggingFace 镜像 -DisableHuggingFaceMirror"; break }
        "UseCustomHuggingFaceMirror" { "自定义 HuggingFace 镜像 -UseCustomHuggingFaceMirror"; break }
        "DisableGithubMirror" { "禁用 Github 镜像 -DisableGithubMirror"; break }
        "UseCustomGithubMirror" { "自定义 Github 镜像 -UseCustomGithubMirror"; break }
        "DisableUV" { "禁用 uv -DisableUV"; break }
        "LaunchArg" { "启动参数 -LaunchArg"; break }
        "EnableShortcut" { "创建快捷方式 -EnableShortcut"; break }
        "DisableCUDAMalloc" { "禁用 CUDA 内存分配器 -DisableCUDAMalloc"; break }
        "DisableEnvCheck" { "禁用环境检查 -DisableEnvCheck"; break }
        "DisableModelMirror" { "禁用模型镜像 -DisableModelMirror"; break }
        default { $ParamName; break }
    }
}

function Get-EffectiveInstallPath {
    param($Project, [System.Collections.IDictionary]$Config)
    if (-not [string]::IsNullOrWhiteSpace($Config["INSTALL_PATH"])) { return $Config["INSTALL_PATH"] }
    return (Join-Path ([Environment]::GetFolderPath("UserProfile")) $Project.DefaultDir)
}

function Get-InstallerCachePath {
    param($Project)
    $dir = Join-Path (Join-Path $script:CacheHome "installers") $Project.Key
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    return (Join-Path $dir $Project.InstallerFile)
}

function Build-InstallerArgs {
    param($Project, [System.Collections.IDictionary]$Config)
    $args = New-Object System.Collections.Generic.List[string]
    if (Test-ProjectParam $Project "InstallPath") { $args.Add("-InstallPath"); $args.Add((Get-EffectiveInstallPath $Project $Config)) }
    if ((Test-ProjectParam $Project "CorePrefix") -and -not [string]::IsNullOrWhiteSpace($Config["CORE_PREFIX"])) { $args.Add("-CorePrefix"); $args.Add($Config["CORE_PREFIX"]) }
    if ((Test-ProjectParam $Project "PyTorchMirrorType") -and -not [string]::IsNullOrWhiteSpace($Config["PYTORCH_MIRROR_TYPE"])) { $args.Add("-PyTorchMirrorType"); $args.Add($Config["PYTORCH_MIRROR_TYPE"]) }
    if ((Test-ProjectParam $Project "InstallPythonVersion") -and -not [string]::IsNullOrWhiteSpace($Config["PYTHON_VERSION"])) { $args.Add("-InstallPythonVersion"); $args.Add($Config["PYTHON_VERSION"]) }
    if ((Test-ProjectParam $Project "InstallBranch") -and -not [string]::IsNullOrWhiteSpace($Config["INSTALL_BRANCH"])) { $args.Add("-InstallBranch"); $args.Add($Config["INSTALL_BRANCH"]) }
    if ((Test-ProjectParam $Project "DisablePyPIMirror") -and $Config["DISABLE_PYPI_MIRROR"]) { $args.Add("-DisablePyPIMirror") }
    if ((Test-ProjectParam $Project "DisableProxy") -and $Config["DISABLE_PROXY"]) { $args.Add("-DisableProxy") }
    if ((Test-ProjectParam $Project "UseCustomProxy") -and -not [string]::IsNullOrWhiteSpace($Config["PROXY"])) { $args.Add("-UseCustomProxy"); $args.Add($Config["PROXY"]) }
    if ((Test-ProjectParam $Project "DisableUV") -and $Config["DISABLE_UV"]) { $args.Add("-DisableUV") }
    if ((Test-ProjectParam $Project "DisableGithubMirror") -and $Config["DISABLE_GITHUB_MIRROR"]) { $args.Add("-DisableGithubMirror") }
    if ((Test-ProjectParam $Project "UseCustomGithubMirror") -and -not [string]::IsNullOrWhiteSpace($Config["GITHUB_MIRROR"])) { $args.Add("-UseCustomGithubMirror"); $args.Add($Config["GITHUB_MIRROR"]) }
    if ((Test-ProjectParam $Project "NoPreDownloadExtension") -and $Config["NO_PRE_DOWNLOAD_EXTENSION"]) { $args.Add("-NoPreDownloadExtension") }
    if ((Test-ProjectParam $Project "NoPreDownloadNode") -and $Config["NO_PRE_DOWNLOAD_NODE"]) { $args.Add("-NoPreDownloadNode") }
    if ((Test-ProjectParam $Project "NoPreDownloadModel") -and $Config["NO_PRE_DOWNLOAD_MODEL"]) { $args.Add("-NoPreDownloadModel") }
    if ((Test-ProjectParam $Project "NoCleanCache") -and $Config["NO_CLEAN_CACHE"]) { $args.Add("-NoCleanCache") }
    if ((Test-ProjectParam $Project "DisableModelMirror") -and $Config["DISABLE_MODEL_MIRROR"]) { $args.Add("-DisableModelMirror") }
    if ((Test-ProjectParam $Project "DisableHuggingFaceMirror") -and $Config["DISABLE_HUGGINGFACE_MIRROR"]) { $args.Add("-DisableHuggingFaceMirror") }
    if ((Test-ProjectParam $Project "UseCustomHuggingFaceMirror") -and -not [string]::IsNullOrWhiteSpace($Config["HUGGINGFACE_MIRROR"])) { $args.Add("-UseCustomHuggingFaceMirror"); $args.Add($Config["HUGGINGFACE_MIRROR"]) }
    if ((Test-ProjectParam $Project "DisableCUDAMalloc") -and $Config["DISABLE_CUDA_MALLOC"]) { $args.Add("-DisableCUDAMalloc") }
    if ((Test-ProjectParam $Project "DisableEnvCheck") -and $Config["DISABLE_ENV_CHECK"]) { $args.Add("-DisableEnvCheck") }
    if (-not [string]::IsNullOrWhiteSpace($Config["EXTRA_INSTALL_ARGS"])) {
        foreach ($arg in (Split-Shlex $Config["EXTRA_INSTALL_ARGS"])) { $args.Add($arg) }
    }
    if (-not (Test-ArgsContains @($args) "-NoPause")) { $args.Add("-NoPause") }
    return @($args)
}

function Build-ManagementScriptArgs {
    param([string]$ProjectKey, [string]$ScriptName, [System.Collections.IDictionary]$Config)
    $args = New-Object System.Collections.Generic.List[string]
    $scriptParams = @{}
    if ($Config.Contains("ScriptParams") -and $null -ne $Config["ScriptParams"] -and (Test-DictionaryKey $Config["ScriptParams"] $ScriptName)) {
        $scriptParams = $Config["ScriptParams"][$ScriptName]
    }
    foreach ($paramName in (Get-ManagementScriptParams $ProjectKey $ScriptName)) {
        if ($paramName -eq "NoPause") { continue }
        $value = ""
        if ($null -ne $scriptParams -and (Test-DictionaryKey $scriptParams $paramName)) { $value = $scriptParams[$paramName] }
        if (Test-ScriptParamIsFlag $paramName) {
            if ([bool]$value) { $args.Add("-$paramName") }
        } elseif (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            $args.Add("-$paramName")
            $args.Add([string]$value)
        }
    }
    if ($Config.Contains("ScriptArgs") -and $null -ne $Config["ScriptArgs"] -and (Test-DictionaryKey $Config["ScriptArgs"] $ScriptName)) {
        $argsText = [string]$Config["ScriptArgs"][$ScriptName]
        if (-not [string]::IsNullOrWhiteSpace($argsText)) {
            foreach ($arg in (Split-Shlex $argsText)) { $args.Add($arg) }
        }
    }
    if ((Test-ManagementScriptParam $ProjectKey $ScriptName "NoPause") -and -not (Test-ArgsContains @($args) "-NoPause")) { $args.Add("-NoPause") }
    return @($args)
}

function Resolve-PowerShellCommand {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($null -ne $pwsh) { return $pwsh.Source }
    $powershell = Get-Command powershell -ErrorAction SilentlyContinue
    if ($null -ne $powershell) { return $powershell.Source }
    return ""
}

function Get-InstallationStatus {
    param($Project, [System.Collections.IDictionary]$Config)
    $path = Get-EffectiveInstallPath $Project $Config
    if (-not (Test-Path $path -PathType Container)) {
        return [PSCustomObject]@{ Code = "missing"; Label = "未安装"; Detail = "未检测到安装目录: $path"; Path = $path }
    }
    foreach ($scriptName in $Project.Scripts.Keys) {
        if (Test-Path (Join-Path $path $scriptName) -PathType Leaf) {
            return [PSCustomObject]@{ Code = "installed"; Label = "已安装"; Detail = "安装路径: $path"; Path = $path }
        }
    }
    return [PSCustomObject]@{ Code = "incomplete"; Label = "安装不完整"; Detail = "检测到安装目录，但未找到管理脚本: $path"; Path = $path }
}

function New-ConsoleWrapperScript {
    $path = Join-Path $env:TEMP ("installer-launcher-wrapper-{0}.ps1" -f ([guid]::NewGuid().ToString("N")))
    @'
param(
    [Parameter(Mandatory=$true)][string]$ScriptPath,
    [string]$ArgsTextPath = "",
    [Parameter(Mandatory=$true)][string]$BaseExpression
)
$ErrorActionPreference = "Continue"
$ScriptArgsText = ""
if (-not [string]::IsNullOrWhiteSpace($ArgsTextPath) -and (Test-Path -LiteralPath $ArgsTextPath -PathType Leaf)) {
    $ScriptArgsText = (Get-Content -LiteralPath $ArgsTextPath -Raw).Trim()
}
Set-Location -LiteralPath (Split-Path -Parent $ScriptPath)
Write-Host ""
Write-Host "Running PowerShell script:" -ForegroundColor Cyan
Write-Host $ScriptPath -ForegroundColor Gray
Write-Host "Arguments:" -ForegroundColor Cyan
if (-not [string]::IsNullOrWhiteSpace($ScriptArgsText)) {
    Write-Host "  $ScriptArgsText" -ForegroundColor Gray
} else {
    Write-Host "  (none)" -ForegroundColor DarkGray
}
Write-Host ""
$Expression = $BaseExpression
if (-not [string]::IsNullOrWhiteSpace($ScriptArgsText)) { $Expression = "$Expression $ScriptArgsText" }
$invokeError = ""
try {
    Invoke-Expression $Expression
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
} catch {
    $invokeError = $_.Exception.Message
    $code = 1
}
if ($code -ne 0) {
    Write-Host ""
    Write-Host "PowerShell 脚本异常退出。" -ForegroundColor Red
    Write-Host "退出代码: $code" -ForegroundColor Red
    if (-not [string]::IsNullOrWhiteSpace($invokeError)) {
        Write-Host "错误信息: $invokeError" -ForegroundColor Red
    }
    Write-Host "请先查看上方 PowerShell 输出日志，确认具体失败原因。" -ForegroundColor Yellow
    Read-Host "按 Enter 关闭窗口"
}
exit $code
'@ | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Quote-ProcessArgument {
    param([string]$Argument)
    if ($null -eq $Argument) { return '""' }
    if ($Argument -notmatch '[\s"]' -and $Argument.Length -gt 0) { return $Argument }
    return '"' + ($Argument -replace '"', '\"') + '"'
}

function Join-ProcessArguments {
    param([string[]]$Arguments)
    $quoted = @()
    foreach ($arg in $Arguments) { $quoted += (Quote-ProcessArgument $arg) }
    return ($quoted -join " ")
}

function Start-PowerShellScriptProcess {
    param([string]$ScriptPath, [string[]]$ScriptArgs)
    $command = Resolve-PowerShellCommand
    if ([string]::IsNullOrWhiteSpace($command)) { throw "未找到 pwsh 或 powershell。" }
    $wrapper = New-ConsoleWrapperScript
    if ($null -eq $ScriptArgs -or $ScriptArgs.Count -eq 0) { $argsText = "" } else { $argsText = Join-Shlex $ScriptArgs }
    $argsTextPath = ""
    if (-not [string]::IsNullOrWhiteSpace($argsText)) {
        $argsTextPath = Join-Path $env:TEMP ("installer-launcher-args-{0}.txt" -f ([guid]::NewGuid().ToString("N")))
        Set-Content -LiteralPath $argsTextPath -Encoding UTF8 -Value $argsText
    }
    $baseExpression = "& " + (Join-Shlex @($command, "-NoLogo", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath))
    $arguments = New-Object System.Collections.Generic.List[string]
    $arguments.Add("-NoLogo")
    $arguments.Add("-ExecutionPolicy")
    $arguments.Add("Bypass")
    $arguments.Add("-File")
    $arguments.Add($wrapper)
    $arguments.Add("-ScriptPath")
    $arguments.Add($ScriptPath)
    if (-not [string]::IsNullOrWhiteSpace($argsTextPath)) {
        $arguments.Add("-ArgsTextPath")
        $arguments.Add($argsTextPath)
    }
    $arguments.Add("-BaseExpression")
    $arguments.Add($baseExpression)
    $argumentLine = Join-ProcessArguments @($arguments)
    Write-Log DEBUG "powershell process prepared: command=$command script=$ScriptPath args=$(Format-LogArgs $ScriptArgs) process_args=$argumentLine"
    $process = Start-Process -FilePath $command -ArgumentList $argumentLine -Wait -PassThru -WindowStyle Normal
    Remove-Item -LiteralPath $wrapper -Force -ErrorAction SilentlyContinue
    if (-not [string]::IsNullOrWhiteSpace($argsTextPath)) { Remove-Item -LiteralPath $argsTextPath -Force -ErrorAction SilentlyContinue }
    return $process.ExitCode
}

function Invoke-DownloadWithRetry {
    param([string[]]$Urls, [string]$OutputPath)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
    $errors = New-Object System.Collections.Generic.List[string]
    foreach ($url in $Urls) {
        try {
            $temp = "$OutputPath.tmp"
            Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $temp -TimeoutSec 30 -ErrorAction Stop
            Move-Item -LiteralPath $temp -Destination $OutputPath -Force
            return [PSCustomObject]@{ Success = $true; Url = $url; Errors = @($errors) }
        } catch {
            Remove-Item -LiteralPath "$OutputPath.tmp" -Force -ErrorAction SilentlyContinue
            $errors.Add("$url -> $($_.Exception.Message)")
        }
    }
    return [PSCustomObject]@{ Success = $false; Url = ""; Errors = @($errors) }
}

function Start-GuiOperation {
    param(
        $UI,
        $State,
        [string]$Name,
        [scriptblock]$ScriptBlock,
        [object[]]$Arguments,
        [scriptblock]$OnComplete
    )
    if ($null -ne $State.CurrentOperation) {
        Show-Message "已有任务正在运行，请等待当前任务完成。" "任务运行中" "Warning"
        return
    }
    Set-UiBusy -UI $UI -Busy $true -Message "$Name 正在运行..."
    $ps = [powershell]::Create()
    $ps.RunspacePool = $script:RunspacePool
    [void]$ps.AddScript($ScriptBlock.ToString())
    foreach ($arg in $Arguments) { [void]$ps.AddArgument($arg) }
    $async = $ps.BeginInvoke()
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(250)
    $State.CurrentOperation = [PSCustomObject]@{ PowerShell = $ps; Async = $async; Timer = $timer; Name = $Name }
    $timer.Add_Tick({
        if (-not $async.IsCompleted) { return }
        $timer.Stop()
        try {
            $result = $ps.EndInvoke($async)
            $streamErrors = @($ps.Streams.Error | ForEach-Object { $_.ToString() })
            & $OnComplete $result $streamErrors
        } catch {
            Write-Log ERROR "$Name failed: $($_.Exception.Message)"
            Append-UiLog -UI $UI -Text "$Name 失败: $($_.Exception.Message)"
            Show-Message "$Name 失败:`n$($_.Exception.Message)" "错误" "Error"
        } finally {
            $ps.Dispose()
            $State.CurrentOperation = $null
            Set-UiBusy -UI $UI -Busy $false -Message ""
        }
    }.GetNewClosure())
    $timer.Start()
}

function Append-UiLog {
    param($UI, [string]$Text)
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Text
    $logBox = $null
    if ($null -ne $UI -and $null -ne $UI.PSObject.Properties["LogBox"]) {
        $logBox = $UI.PSObject.Properties["LogBox"].Value
    }
    if ($null -ne $logBox) {
        $logBox.AppendText($line + [Environment]::NewLine)
        $logBox.ScrollToEnd()
    }
    Write-Log INFO $Text
}

function Set-UiBusy {
    param($UI, [bool]$Busy, [string]$Message)
    $enabled = -not $Busy
    foreach ($button in @($UI.UninstallBtn, $UI.SaveConfigBtn, $UI.CheckUpdateBtn, $UI.UnifiedStartBtn, $UI.SaveMainBtn, $UI.OpenConfigFolderBtn)) {
        if ($null -ne $button) { $button.IsEnabled = $enabled }
    }
    if ($null -ne $UI.BusyText) { $UI.BusyText.Text = $Message }
}

function Save-MainConfig {
    Save-JsonConfig -Path $script:MainConfigFile -Config $script:MainConfig
    Configure-ProxyFromMainConfig
}

function Load-AllConfig {
    Initialize-Directories
    $script:MainConfig = Read-JsonConfig -Path $script:MainConfigFile -Default (Get-DefaultMainConfig)
    $script:MainConfig["LOG_LEVEL"] = Normalize-LogLevel $script:MainConfig["LOG_LEVEL"]
    $script:MainConfig["PROXY_MODE"] = Normalize-ProxyMode $script:MainConfig["PROXY_MODE"]
    if ($null -eq $script:MainConfig["MANUAL_PROXY"]) { $script:MainConfig["MANUAL_PROXY"] = "" }
    Save-MainConfig
}

function Get-CurrentProjectKey {
    if ([string]::IsNullOrWhiteSpace($script:MainConfig["CURRENT_PROJECT"])) { return "" }
    if (-not $script:Projects.Contains($script:MainConfig["CURRENT_PROJECT"])) { return "" }
    return $script:MainConfig["CURRENT_PROJECT"]
}

function Collect-ProjectConfigFromUi {
    param($State)
    $config = $State.ProjectConfig
    foreach ($key in $State.ConfigControls.Keys) {
        $control = $State.ConfigControls[$key]
        if ($control -is [System.Windows.Controls.CheckBox]) {
            $config[$key] = [bool]$control.IsChecked
        } elseif ($control -is [System.Windows.Controls.ComboBox]) {
            if ($null -ne $control.SelectedItem -and $control.SelectedItem -is [System.Windows.Controls.ComboBoxItem]) {
                $config[$key] = [string]$control.SelectedItem.Tag
            } elseif ($null -ne $control.SelectedItem -and $null -ne $control.SelectedItem.PSObject.Properties["Key"]) {
                $config[$key] = [string]$control.SelectedItem.PSObject.Properties["Key"].Value
            } elseif ($null -ne $control.SelectedValue) {
                $config[$key] = [string]$control.SelectedValue
            } elseif ($null -ne $control.Text) {
                $config[$key] = [string]$control.Text
            } else {
                $config[$key] = ""
            }
        } elseif ($control -is [System.Windows.Controls.TextBox]) {
            $config[$key] = $control.Text
        }
    }
    return $config
}

function Select-FolderPath {
    param([string]$InitialPath)
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "选择安装路径"
    $dialog.ShowNewFolderButton = $true
    if (-not [string]::IsNullOrWhiteSpace($InitialPath) -and (Test-Path -LiteralPath $InitialPath -PathType Container)) {
        $dialog.SelectedPath = $InitialPath
    }
    $result = $dialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    }
    return $null
}

function New-ConfigCardRow {
    param([string]$Label)
    $card = New-Object System.Windows.Controls.Border
    $card.Margin = "0,0,0,10"
    $card.Padding = "14"
    $card.CornerRadius = 8
    $card.BorderThickness = 1
    $card.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "HeaderBGBrush")
    $card.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, "BorderBrush")

    $grid = New-Object System.Windows.Controls.Grid
    $left = New-Object System.Windows.Controls.ColumnDefinition
    $left.Width = New-Object System.Windows.GridLength(260)
    $right = New-Object System.Windows.Controls.ColumnDefinition
    $right.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $grid.ColumnDefinitions.Add($left) | Out-Null
    $grid.ColumnDefinitions.Add($right) | Out-Null

    $labelBlock = New-Object System.Windows.Controls.TextBlock
    $labelBlock.Text = $Label
    $labelBlock.FontWeight = "SemiBold"
    $labelBlock.TextWrapping = "Wrap"
    $labelBlock.VerticalAlignment = "Center"
    $labelBlock.Margin = "0,0,16,0"
    [System.Windows.Controls.Grid]::SetColumn($labelBlock, 0)
    $grid.Children.Add($labelBlock) | Out-Null
    $card.Child = $grid

    return [PSCustomObject]@{ Card = $card; Grid = $grid }
}

function Add-ConfigTextBox {
    param($Panel, $State, [string]$Key, [string]$Label, [string]$Value)
    $rowInfo = New-ConfigCardRow $Label
    $box = New-Object System.Windows.Controls.TextBox
    $box.Text = $Value
    if ($Key -eq "INSTALL_PATH") {
        $row = New-Object System.Windows.Controls.Grid
        $col1 = New-Object System.Windows.Controls.ColumnDefinition
        $col1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $col2 = New-Object System.Windows.Controls.ColumnDefinition
        $col2.Width = New-Object System.Windows.GridLength(86)
        $row.ColumnDefinitions.Add($col1) | Out-Null
        $row.ColumnDefinitions.Add($col2) | Out-Null
        $browseButton = New-Object System.Windows.Controls.Button
        $browseButton.Content = "选择..."
        $browseButton.Margin = "8,0,0,0"
        [System.Windows.Controls.Grid]::SetColumn($box, 0)
        [System.Windows.Controls.Grid]::SetColumn($browseButton, 1)
        $row.Children.Add($box) | Out-Null
        $row.Children.Add($browseButton) | Out-Null
        $browseButton.Add_Click({
            $selectedPath = Select-FolderPath $box.Text
            if (-not [string]::IsNullOrWhiteSpace($selectedPath)) {
                $box.Text = $selectedPath
            }
        }.GetNewClosure())
        [System.Windows.Controls.Grid]::SetColumn($row, 1)
        $rowInfo.Grid.Children.Add($row) | Out-Null
    } else {
        [System.Windows.Controls.Grid]::SetColumn($box, 1)
        $rowInfo.Grid.Children.Add($box) | Out-Null
    }
    $Panel.Children.Add($rowInfo.Card) | Out-Null
    $State.ConfigControls[$Key] = $box
}

function Add-ConfigComboBox {
    param($Panel, $State, [string]$Key, [string]$Label, [System.Collections.IDictionary]$Options, [string]$Value)
    $rowInfo = New-ConfigCardRow $Label
    $combo = New-Object System.Windows.Controls.ComboBox
    $combo.IsEditable = $false
    if ($null -ne $Options) {
        foreach ($optionKey in $Options.Keys) {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = "$optionKey - $($Options[$optionKey])"
            $item.Tag = [string]$optionKey
            $combo.Items.Add($item) | Out-Null
            if ([string]$optionKey -eq $Value) {
                $combo.SelectedItem = $item
            }
        }
    }
    if ($null -eq $combo.SelectedItem -and $combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }
    [System.Windows.Controls.Grid]::SetColumn($combo, 1)
    $rowInfo.Grid.Children.Add($combo) | Out-Null
    $Panel.Children.Add($rowInfo.Card) | Out-Null
    $State.ConfigControls[$Key] = $combo
}

function Add-ConfigCheckBox {
    param($Panel, $State, [string]$Key, [string]$Label, [bool]$Value)
    $rowInfo = New-ConfigCardRow $Label
    $box = New-Object System.Windows.Controls.CheckBox
    $box.IsChecked = $Value
    $box.HorizontalAlignment = "Right"
    $box.VerticalAlignment = "Center"
    [System.Windows.Controls.Grid]::SetColumn($box, 1)
    $rowInfo.Grid.Children.Add($box) | Out-Null
    $Panel.Children.Add($rowInfo.Card) | Out-Null
    $State.ConfigControls[$Key] = $box
}

function Refresh-ScriptParamUi {
    param($UI, $State)
    if ($null -eq $UI.ScriptParamPanel) { return }
    $UI.ScriptParamPanel.Children.Clear()
    $State.ScriptParamControls = @{}
    $key = Get-CurrentProjectKey
    if ([string]::IsNullOrWhiteSpace($key) -or $null -eq $UI.ScriptCombo.SelectedItem) { return }
    $scriptName = Get-SelectedScriptName $UI.ScriptCombo
    $config = Get-ProjectConfig $key
    $scriptParams = @{}
    if ($config.Contains("ScriptParams") -and $null -ne $config["ScriptParams"] -and (Test-DictionaryKey $config["ScriptParams"] $scriptName)) {
        $scriptParams = $config["ScriptParams"][$scriptName]
    }
    $scriptState = [PSCustomObject]@{ ConfigControls = @{} }
    foreach ($paramName in (Get-ManagementScriptParams $key $scriptName)) {
        if ($paramName -eq "NoPause") { continue }
        $value = ""
        if ($null -ne $scriptParams -and (Test-DictionaryKey $scriptParams $paramName)) { $value = $scriptParams[$paramName] }
        if (Test-ScriptParamIsFlag $paramName) {
            Add-ConfigCheckBox $UI.ScriptParamPanel $scriptState $paramName (Get-ScriptParamLabel $paramName) ([bool]$value)
        } else {
            Add-ConfigTextBox $UI.ScriptParamPanel $scriptState $paramName (Get-ScriptParamLabel $paramName) ([string]$value)
        }
    }
    $State.ScriptParamControls = $scriptState.ConfigControls
}

function Save-ScriptParamUi {
    param($UI, $State, [System.Collections.IDictionary]$Config)
    if ($null -eq $UI.ScriptCombo -or $null -eq $UI.ScriptCombo.SelectedItem) { return }
    if ($null -eq $Config["ScriptParams"]) { $Config["ScriptParams"] = @{} }
    $scriptName = Get-SelectedScriptName $UI.ScriptCombo
    if ([string]::IsNullOrWhiteSpace($scriptName)) { return }
    $values = @{}
    foreach ($paramName in $State.ScriptParamControls.Keys) {
        $control = $State.ScriptParamControls[$paramName]
        if ($control -is [System.Windows.Controls.CheckBox]) {
            $values[$paramName] = [bool]$control.IsChecked
        } elseif ($control -is [System.Windows.Controls.TextBox]) {
            $values[$paramName] = $control.Text
        }
    }
    $Config["ScriptParams"][$scriptName] = $values
}

function Collect-ProjectAndScriptConfigFromUi {
    param($UI, $State)
    $config = Collect-ProjectConfigFromUi $State
    if ($null -ne $UI.ScriptCombo -and $null -ne $UI.ScriptCombo.SelectedItem) {
        if ($null -eq $config["ScriptArgs"]) { $config["ScriptArgs"] = @{} }
        $scriptName = Get-SelectedScriptName $UI.ScriptCombo
        if (-not [string]::IsNullOrWhiteSpace($scriptName)) {
            $config["ScriptArgs"][$scriptName] = $UI.ScriptArgsBox.Text
            Save-ScriptParamUi $UI $State $config
        }
    }
    return $config
}

function Refresh-ProjectConfigUi {
    param($UI, $State)
    $UI.PathPanel.Children.Clear()
    $UI.ConfigPanel.Children.Clear()
    $State.ConfigControls = @{}
    $key = Get-CurrentProjectKey
    if ([string]::IsNullOrWhiteSpace($key)) {
        $hint = New-Object System.Windows.Controls.TextBlock
        $hint.Text = "请先在左侧选择要安装或管理的 WebUI / 工具。"
        $hint.TextWrapping = "Wrap"
        $UI.PathPanel.Children.Add($hint) | Out-Null
        $hint = New-Object System.Windows.Controls.TextBlock
        $hint.Text = "请先在左侧选择要安装或管理的 WebUI / 工具。"
        $hint.TextWrapping = "Wrap"
        $UI.ConfigPanel.Children.Add($hint) | Out-Null
        return
    }
    $project = $script:Projects[$key]
    if ($null -eq $project) {
        throw "项目注册表中找不到项目: $key"
    }
    $config = Get-ProjectConfig $key
    $State.ProjectConfig = $config
    if (Test-ProjectParam $project "InstallPath") {
        Add-ConfigTextBox $UI.PathPanel $State "INSTALL_PATH" "安装路径（留空使用默认: $(Get-EffectiveInstallPath $project $config)）" $config["INSTALL_PATH"]
    } else {
        $hint = New-Object System.Windows.Controls.TextBlock
        $hint.Text = "当前项目不支持自定义安装路径。"
        $hint.TextWrapping = "Wrap"
        $UI.PathPanel.Children.Add($hint) | Out-Null
    }
    if (Test-ProjectParam $project "InstallBranch") { Add-ConfigComboBox $UI.ConfigPanel $State "INSTALL_BRANCH" "安装分支" $project.Branches $config["INSTALL_BRANCH"] }
    if (Test-ProjectParam $project "CorePrefix") { Add-ConfigTextBox $UI.ConfigPanel $State "CORE_PREFIX" "内核路径前缀" $config["CORE_PREFIX"] }
    if (Test-ProjectParam $project "PyTorchMirrorType") { Add-ConfigTextBox $UI.ConfigPanel $State "PYTORCH_MIRROR_TYPE" "PyTorch 镜像类型" $config["PYTORCH_MIRROR_TYPE"] }
    if (Test-ProjectParam $project "InstallPythonVersion") { Add-ConfigTextBox $UI.ConfigPanel $State "PYTHON_VERSION" "Python 版本" $config["PYTHON_VERSION"] }
    if (Test-ProjectParam $project "UseCustomProxy") { Add-ConfigTextBox $UI.ConfigPanel $State "PROXY" "安装器自定义代理 -UseCustomProxy" $config["PROXY"] }
    if (Test-ProjectParam $project "UseCustomGithubMirror") { Add-ConfigTextBox $UI.ConfigPanel $State "GITHUB_MIRROR" "Github 镜像 -UseCustomGithubMirror" $config["GITHUB_MIRROR"] }
    if (Test-ProjectParam $project "UseCustomHuggingFaceMirror") { Add-ConfigTextBox $UI.ConfigPanel $State "HUGGINGFACE_MIRROR" "HuggingFace 镜像 -UseCustomHuggingFaceMirror" $config["HUGGINGFACE_MIRROR"] }
    Add-ConfigTextBox $UI.ConfigPanel $State "EXTRA_INSTALL_ARGS" "安装器自定义参数（追加到结构化参数之后）" $config["EXTRA_INSTALL_ARGS"]
    $flags = @(
        [PSCustomObject]@{ Key = "DISABLE_PYPI_MIRROR"; Label = "禁用 PyPI 镜像 -DisablePyPIMirror"; Param = "DisablePyPIMirror" },
        [PSCustomObject]@{ Key = "DISABLE_PROXY"; Label = "禁用安装器自动代理 -DisableProxy"; Param = "DisableProxy" },
        [PSCustomObject]@{ Key = "DISABLE_UV"; Label = "禁用 uv -DisableUV"; Param = "DisableUV" },
        [PSCustomObject]@{ Key = "DISABLE_GITHUB_MIRROR"; Label = "禁用 Github 镜像 -DisableGithubMirror"; Param = "DisableGithubMirror" },
        [PSCustomObject]@{ Key = "NO_PRE_DOWNLOAD_EXTENSION"; Label = "跳过预下载扩展 -NoPreDownloadExtension"; Param = "NoPreDownloadExtension" },
        [PSCustomObject]@{ Key = "NO_PRE_DOWNLOAD_NODE"; Label = "跳过预下载节点 -NoPreDownloadNode"; Param = "NoPreDownloadNode" },
        [PSCustomObject]@{ Key = "NO_PRE_DOWNLOAD_MODEL"; Label = "跳过预下载模型 -NoPreDownloadModel"; Param = "NoPreDownloadModel" },
        [PSCustomObject]@{ Key = "NO_CLEAN_CACHE"; Label = "不清理安装缓存 -NoCleanCache"; Param = "NoCleanCache" },
        [PSCustomObject]@{ Key = "DISABLE_MODEL_MIRROR"; Label = "禁用模型镜像 -DisableModelMirror"; Param = "DisableModelMirror" },
        [PSCustomObject]@{ Key = "DISABLE_HUGGINGFACE_MIRROR"; Label = "禁用 HuggingFace 镜像 -DisableHuggingFaceMirror"; Param = "DisableHuggingFaceMirror" },
        [PSCustomObject]@{ Key = "DISABLE_CUDA_MALLOC"; Label = "禁用 CUDA 内存分配器设置 -DisableCUDAMalloc"; Param = "DisableCUDAMalloc" },
        [PSCustomObject]@{ Key = "DISABLE_ENV_CHECK"; Label = "禁用环境检查 -DisableEnvCheck"; Param = "DisableEnvCheck" }
    )
    foreach ($flag in $flags) {
        if (Test-ProjectParam $project $flag.Param) { Add-ConfigCheckBox $UI.ConfigPanel $State $flag.Key $flag.Label ([bool]$config[$flag.Key]) }
    }
}

function Refresh-Status {
    param($UI, $State)
    $key = Get-CurrentProjectKey
    if ([string]::IsNullOrWhiteSpace($key)) {
        $UI.ProjectStatusText.Text = "当前项目: 未选择`n安装状态: 未检测`n请先在左侧选择要安装或管理的 WebUI / 工具。"
        $UI.ScriptCombo.ItemsSource = $null
        if ($null -ne $UI.LaunchScriptList) { $UI.LaunchScriptList.ItemsSource = $null }
        if ($null -ne $UI.StartHintText) { $UI.StartHintText.Text = "请先进入「软件选择」选择要安装或管理的 WebUI / 工具。" }
        if ($null -ne $UI.InstallHintText) { $UI.InstallHintText.Text = "请先选择项目，再确认安装路径和安装器参数。" }
        Set-OneClickModeFromStatus $UI $State "none"
        return
    }
    $project = $script:Projects[$key]
    $config = Get-ProjectConfig $key
    $status = Get-InstallationStatus $project $config
    $proxyMode = $script:MainConfig["PROXY_MODE"]
    $autoUpdate = $script:MainConfig["AUTO_UPDATE_ENABLED"]
    $nextStep = "先在安装路径确认目标目录，再到高级选项确认分支和镜像，然后运行安装器完成首次安装。"
    if ($status.Code -eq "installed") {
        $nextStep = "已安装完成。请进入管理脚本运行 launch.ps1 启动软件，或运行 update.ps1 / terminal.ps1 做维护。"
    } elseif ($status.Code -eq "incomplete") {
        $nextStep = "检测到安装目录但缺少管理脚本。请重新运行安装器修复完整安装。"
    }
    $UI.ProjectStatusText.Text = "当前项目: $($project.Name)`n安装状态: $($status.Label)`n$($status.Detail)`n下一步: $nextStep`n代理模式: $proxyMode    自动更新: $autoUpdate"
    $scripts = @()
    foreach ($scriptName in $project.Scripts.Keys) {
        $scripts += [LauncherChoice]::new($scriptName, "$scriptName - $($project.Scripts[$scriptName])")
    }
    $UI.ScriptCombo.ItemsSource = $scripts
    if ($scripts.Count -gt 0) { $UI.ScriptCombo.SelectedIndex = 0 }
    if ($null -ne $UI.LaunchScriptList) {
        $launchItems = @()
        foreach ($scriptName in $project.Scripts.Keys) {
            $launchItems += [LauncherChoice]::new($scriptName, "$scriptName - $($project.Scripts[$scriptName])")
        }
        $UI.LaunchScriptList.ItemsSource = $launchItems
        if ($launchItems.Count -gt 0) { $UI.LaunchScriptList.SelectedIndex = 0 }
    }
    if ($null -ne $UI.StartHintText) {
        if ($status.Code -eq "installed") {
            $UI.StartHintText.Text = "启动模式会运行已安装目录中的管理脚本。通常选择 launch.ps1 启动软件，选择 terminal.ps1 打开交互终端。"
        } else {
            $UI.StartHintText.Text = "当前项目还未完整安装。请选择安装模式，确认路径和高级选项后运行安装器。"
        }
    }
    if ($null -ne $UI.InstallHintText) {
        if ($status.Code -eq "installed") {
            $UI.InstallHintText.Text = "当前项目已安装。只有需要修复、更新安装器配置或重新安装时，才建议运行安装器。"
        } elseif ($status.Code -eq "incomplete") {
            $UI.InstallHintText.Text = "检测到安装目录但缺少管理脚本。建议运行安装器修复完整安装。"
        } else {
            $UI.InstallHintText.Text = "当前项目未安装。确认高级选项中的安装路径、分支和镜像后，点击右侧按钮运行安装器。"
        }
    }
    Set-OneClickModeFromStatus $UI $State $status.Code
}

function Select-RelevantMainTab {
    param($UI)
    if ($null -eq $UI.MainTabs) { return }
    $key = Get-CurrentProjectKey
    if ([string]::IsNullOrWhiteSpace($key)) {
        $UI.MainTabs.SelectedIndex = 0
        return
    }
    $project = $script:Projects[$key]
    $config = Get-ProjectConfig $key
    $status = Get-InstallationStatus $project $config
    if ($status.Code -eq "installed") {
        $UI.MainTabs.SelectedIndex = 2
    } else {
        $UI.MainTabs.SelectedIndex = 0
    }
}

function Set-NavButtonSelected {
    param($UI, [string]$PageName)
    foreach ($entry in @(
        @{ Name = "start"; Button = $UI.OneClickNavBtn; Label = $UI.OneClickNavLabel },
        @{ Name = "advanced"; Button = $UI.AdvancedNavBtn; Label = $UI.AdvancedNavLabel },
        @{ Name = "software"; Button = $UI.SoftwareNavBtn; Label = $UI.SoftwareNavLabel },
        @{ Name = "settings"; Button = $UI.SettingsNavBtn; Label = $UI.SettingsNavLabel }
    )) {
        $button = $entry["Button"]
        $label = $entry["Label"]
        if ($null -eq $button) { continue }
        if ($entry["Name"] -eq $PageName) {
            $button.Background = $UI.Window.Resources["HeaderBGBrush"]
            $button.BorderBrush = $UI.Window.Resources["PrimaryBrush"]
            $button.FontWeight = "SemiBold"
            if ($null -ne $label) { $label.Visibility = "Collapsed" }
        } else {
            $button.Background = [System.Windows.Media.Brushes]::Transparent
            $button.BorderBrush = [System.Windows.Media.Brushes]::Transparent
            $button.FontWeight = "Normal"
            if ($null -ne $label) { $label.Visibility = "Visible" }
        }
    }
}

function Show-AppPage {
    param($UI, [string]$PageName)
    foreach ($page in @($UI.StartPage, $UI.AdvancedPage, $UI.SoftwarePage, $UI.SettingsPage)) {
        if ($null -ne $page) { $page.Visibility = "Collapsed" }
    }
    switch ($PageName) {
        "advanced" { if ($null -ne $UI.AdvancedPage) { $UI.AdvancedPage.Visibility = "Visible" } }
        "software" { if ($null -ne $UI.SoftwarePage) { $UI.SoftwarePage.Visibility = "Visible" } }
        "settings" { if ($null -ne $UI.SettingsPage) { $UI.SettingsPage.Visibility = "Visible" } }
        default { if ($null -ne $UI.StartPage) { $UI.StartPage.Visibility = "Visible" }; $PageName = "start" }
    }
    Set-NavButtonSelected $UI $PageName
}

function Update-OneClickModeUi {
    param($UI)
    if ($null -eq $UI.StartModeTabs -or $null -eq $UI.LaunchScriptList) { return }
    if ($UI.StartModeTabs.SelectedIndex -eq 1) {
        $UI.LaunchScriptList.IsEnabled = $false
        if ($null -ne $UI.UnifiedStartBtn) { $UI.UnifiedStartBtn.Content = "▶ 运行安装器" }
    } else {
        $UI.LaunchScriptList.IsEnabled = $true
        if ($null -ne $UI.UnifiedStartBtn) { $UI.UnifiedStartBtn.Content = "▶ 启动所选脚本" }
    }
}

function Set-OneClickModeFromStatus {
    param($UI, $State, [string]$StatusCode)
    if ($null -eq $UI.StartModeTabs) { return }
    if ($null -ne $State -and $null -ne $State.PSObject.Properties["LastOneClickStatus"]) {
        if ([string]$State.LastOneClickStatus -eq $StatusCode) {
            Update-OneClickModeUi $UI
            return
        }
        $State.LastOneClickStatus = $StatusCode
    }
    if ($StatusCode -eq "installed") {
        $UI.StartModeTabs.SelectedIndex = 0
    } else {
        $UI.StartModeTabs.SelectedIndex = 1
    }
    Update-OneClickModeUi $UI
}

function Select-ScriptByName {
    param($UI, [string]$ScriptName)
    if ($null -eq $UI.ScriptCombo -or [string]::IsNullOrWhiteSpace($ScriptName)) { return }
    foreach ($item in $UI.ScriptCombo.Items) {
        $itemName = ""
        if ($item -is [System.Windows.Controls.ComboBoxItem]) {
            $itemName = [string]$item.Tag
        } elseif ($null -ne $item.PSObject.Properties["Name"]) {
            $itemName = [string]$item.PSObject.Properties["Name"].Value
        }
        if ($itemName -eq $ScriptName) {
            $UI.ScriptCombo.SelectedItem = $item
            return
        }
    }
}

function Invoke-OneClickAction {
    param($UI, $State)
    if ($null -eq $UI.StartModeTabs -or $UI.StartModeTabs.SelectedIndex -eq 1) {
        Invoke-RunInstaller $UI $State
        return
    }
    if ($null -eq $UI.LaunchScriptList -or $null -eq $UI.LaunchScriptList.SelectedItem) {
        Show-Message "请选择要启动的管理脚本。" "未选择脚本" "Warning"
        return
    }
    $scriptName = ""
    if ($null -ne $UI.LaunchScriptList.SelectedItem.PSObject.Properties["Name"]) {
        $scriptName = [string]$UI.LaunchScriptList.SelectedItem.PSObject.Properties["Name"].Value
    }
    if ([string]::IsNullOrWhiteSpace($scriptName)) {
        Show-Message "无法识别所选管理脚本，请重新选择。" "脚本选择异常" "Warning"
        return
    }
    Select-ScriptByName $UI $scriptName
    Invoke-RunManagementScript $UI $State
}

function Open-ConfigFolder {
    $path = $script:ConfigHome
    if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Force -Path $path | Out-Null }
    Start-Process -FilePath "explorer.exe" -ArgumentList @($path) | Out-Null
}

function Refresh-MainConfigUi {
    param($UI)
    $UI.AutoUpdateCheck.IsChecked = [bool]$script:MainConfig["AUTO_UPDATE_ENABLED"]
    $UI.WelcomeCheck.IsChecked = [bool]$script:MainConfig["SHOW_WELCOME_SCREEN"]
    $UI.LogLevelCombo.SelectedItem = $script:MainConfig["LOG_LEVEL"]
    $UI.ProxyModeCombo.SelectedItem = $script:MainConfig["PROXY_MODE"]
    $UI.ManualProxyBox.Text = [string]$script:MainConfig["MANUAL_PROXY"]
}

function Save-MainConfigFromUi {
    param($UI)
    $script:MainConfig["AUTO_UPDATE_ENABLED"] = [bool]$UI.AutoUpdateCheck.IsChecked
    $script:MainConfig["SHOW_WELCOME_SCREEN"] = [bool]$UI.WelcomeCheck.IsChecked
    $script:MainConfig["LOG_LEVEL"] = Normalize-LogLevel ([string]$UI.LogLevelCombo.SelectedItem)
    $script:MainConfig["PROXY_MODE"] = Normalize-ProxyMode ([string]$UI.ProxyModeCombo.SelectedItem)
    $script:MainConfig["MANUAL_PROXY"] = $UI.ManualProxyBox.Text
    Save-MainConfig
}

function Invoke-RunInstaller {
    param($UI, $State)
    $key = Get-CurrentProjectKey
    if ([string]::IsNullOrWhiteSpace($key)) { Show-Message "请先选择项目。" "未选择项目" "Warning"; return }
    $project = $script:Projects[$key]
    $config = Collect-ProjectAndScriptConfigFromUi $UI $State
    Save-ProjectConfig $key $config
    $args = Build-InstallerArgs $project $config
    $scriptPath = Get-InstallerCachePath $project
    if ($null -eq $args -or $args.Count -eq 0) { $argsText = "" } else { $argsText = Join-Shlex $args }
    Write-Log DEBUG "installer args prepared: project=$key path=$scriptPath args=$(Format-LogArgs $args) args_text=$argsText"
    $confirmation = @"
即将运行安装任务，请确认配置。

项目: $($project.Name)
安装路径: $(Get-EffectiveInstallPath $project $config)
安装器缓存: $scriptPath

下载源:
$($project.InstallerUrls -join [Environment]::NewLine)

PowerShell 参数:
$($args -join [Environment]::NewLine)
"@
    if (-not (Confirm-Message $confirmation "确认运行安装器")) { Append-UiLog $UI "安装任务已取消。"; return }
    $operation = {
        param($Project, $Config, [string]$InstallerArgsText, [string]$OutputPath)
        function Invoke-DownloadWithRetry {
            param([string[]]$Urls, [string]$OutputPath)
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
            $errors = New-Object System.Collections.Generic.List[string]
            foreach ($url in $Urls) {
                try {
                    $temp = "$OutputPath.tmp"
                    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $temp -TimeoutSec 30 -ErrorAction Stop
                    Move-Item -LiteralPath $temp -Destination $OutputPath -Force
                    return [PSCustomObject]@{ Success = $true; Url = $url; Errors = @($errors) }
                } catch {
                    Remove-Item -LiteralPath "$OutputPath.tmp" -Force -ErrorAction SilentlyContinue
                    $errors.Add("$url -> $($_.Exception.Message)")
                }
            }
            return [PSCustomObject]@{ Success = $false; Url = ""; Errors = @($errors) }
        }
        function Resolve-PowerShellCommand {
            $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
            if ($null -ne $pwsh) { return $pwsh.Source }
            $powershell = Get-Command powershell -ErrorAction SilentlyContinue
            if ($null -ne $powershell) { return $powershell.Source }
            return ""
        }
        function New-ConsoleWrapperScript {
            $path = Join-Path $env:TEMP ("installer-launcher-wrapper-{0}.ps1" -f ([guid]::NewGuid().ToString("N")))
            @'
param([Parameter(Mandatory=$true)][string]$ScriptPath,[string]$ArgsTextPath="",[Parameter(Mandatory=$true)][string]$BaseExpression)
$ScriptArgsText = ""
if (-not [string]::IsNullOrWhiteSpace($ArgsTextPath) -and (Test-Path -LiteralPath $ArgsTextPath -PathType Leaf)) {
    $ScriptArgsText = (Get-Content -LiteralPath $ArgsTextPath -Raw).Trim()
}
Set-Location -LiteralPath (Split-Path -Parent $ScriptPath)
Write-Host ""
Write-Host "Running PowerShell script:" -ForegroundColor Cyan
Write-Host $ScriptPath -ForegroundColor Gray
Write-Host "Arguments:" -ForegroundColor Cyan
if (-not [string]::IsNullOrWhiteSpace($ScriptArgsText)) {
    Write-Host "  $ScriptArgsText" -ForegroundColor Gray
} else {
    Write-Host "  (none)" -ForegroundColor DarkGray
}
Write-Host ""
$Expression = $BaseExpression
if (-not [string]::IsNullOrWhiteSpace($ScriptArgsText)) { $Expression = "$Expression $ScriptArgsText" }
$invokeError = ""
try {
    Invoke-Expression $Expression
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
} catch {
    $invokeError = $_.Exception.Message
    $code = 1
}
if ($code -ne 0) {
    Write-Host ""
    Write-Host "PowerShell 脚本异常退出。" -ForegroundColor Red
    Write-Host "退出代码: $code" -ForegroundColor Red
    if (-not [string]::IsNullOrWhiteSpace($invokeError)) {
        Write-Host "错误信息: $invokeError" -ForegroundColor Red
    }
    Write-Host "请先查看上方 PowerShell 输出日志，确认具体失败原因。" -ForegroundColor Yellow
    Read-Host "按 Enter 关闭窗口"
}
exit $code
'@ | Set-Content -LiteralPath $path -Encoding UTF8
            return $path
        }
        function Quote-ProcessArgument {
            param([string]$Argument)
            if ($null -eq $Argument) { return '""' }
            if ($Argument -notmatch '[\s"]' -and $Argument.Length -gt 0) { return $Argument }
            return '"' + ($Argument -replace '"', '\"') + '"'
        }
        function Join-ProcessArguments {
            param([string[]]$Arguments)
            $quoted = @()
            foreach ($arg in $Arguments) { $quoted += (Quote-ProcessArgument $arg) }
            return ($quoted -join " ")
        }
        function Join-Shlex {
            param([Parameter(Mandatory)][string[]]$Arguments)
            $params = $Arguments.ForEach{
                if ($_ -match '\s|"') { "'{0}'" -f ($_ -replace "'", "''") }
                else { $_ }
            } -join ' '
            return $params
        }
        $download = Invoke-DownloadWithRetry -Urls ([string[]]$Project.InstallerUrls) -OutputPath $OutputPath
        if (-not $download.Success) {
            return [PSCustomObject]@{ Success = $false; Stage = "download"; ExitCode = 1; Message = "安装器下载失败"; Detail = ($download.Errors -join "`n") }
        }
        $command = Resolve-PowerShellCommand
        if ([string]::IsNullOrWhiteSpace($command)) {
            return [PSCustomObject]@{ Success = $false; Stage = "powershell"; ExitCode = 127; Message = "未找到 pwsh 或 powershell"; Detail = "" }
        }
        $wrapper = New-ConsoleWrapperScript
        $argsTextPath = ""
        if (-not [string]::IsNullOrWhiteSpace($InstallerArgsText)) {
            $argsTextPath = Join-Path $env:TEMP ("installer-launcher-args-{0}.txt" -f ([guid]::NewGuid().ToString("N")))
            Set-Content -LiteralPath $argsTextPath -Encoding UTF8 -Value $InstallerArgsText
        }
        $baseExpression = "& " + (Join-Shlex @($command, "-NoLogo", "-ExecutionPolicy", "Bypass", "-File", $OutputPath))
        $argumentList = @("-NoLogo", "-ExecutionPolicy", "Bypass", "-File", $wrapper, "-ScriptPath", $OutputPath)
        if (-not [string]::IsNullOrWhiteSpace($argsTextPath)) { $argumentList += "-ArgsTextPath"; $argumentList += $argsTextPath }
        $argumentList += "-BaseExpression"; $argumentList += $baseExpression
        $argumentLine = Join-ProcessArguments ([string[]]$argumentList)
        $process = Start-Process -FilePath $command -ArgumentList $argumentLine -Wait -PassThru -WindowStyle Normal
        Remove-Item -LiteralPath $wrapper -Force -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($argsTextPath)) { Remove-Item -LiteralPath $argsTextPath -Force -ErrorAction SilentlyContinue }
        return [PSCustomObject]@{ Success = ($process.ExitCode -eq 0); Stage = "execute"; ExitCode = $process.ExitCode; Message = "安装器执行完成"; Detail = "下载源: $($download.Url)"; ProcessArgs = $argumentLine; ScriptArgsText = $InstallerArgsText }
    }
    Start-GuiOperation -UI $UI -State $State -Name "运行安装器" -ScriptBlock $operation -Arguments @($project, $config, $argsText, $scriptPath) -OnComplete {
        param($result, $streamErrors)
        $item = $result | Select-Object -First 1
        if ($null -eq $item) { Show-Message "安装任务没有返回结果。" "错误" "Error"; return }
        if ($item.Success) {
            Write-Log DEBUG "installer process args: $($item.ProcessArgs)"
            Write-Log DEBUG "installer script args text: $($item.ScriptArgsText)"
            Append-UiLog $UI "安装器执行成功。$($item.Detail)"
            Show-Message "安装器执行成功。`n$($item.Detail)" "完成"
        } else {
            Write-Log DEBUG "installer process args: $($item.ProcessArgs)"
            Write-Log DEBUG "installer script args text: $($item.ScriptArgsText)"
            Append-UiLog $UI "安装器执行失败: $($item.Message) exit=$($item.ExitCode) $($item.Detail)"
            Show-Message "安装器执行失败。`n阶段: $($item.Stage)`n退出代码: $($item.ExitCode)`n$($item.Detail)" "失败" "Error"
        }
        Refresh-Status $UI $State
    }
}

function Invoke-RunManagementScript {
    param($UI, $State)
    $key = Get-CurrentProjectKey
    if ([string]::IsNullOrWhiteSpace($key)) { Show-Message "请先选择项目。" "未选择项目" "Warning"; return }
    $project = $script:Projects[$key]
    $config = Get-ProjectConfig $key
    $selected = $UI.ScriptCombo.SelectedItem
    if ($null -eq $selected) { Show-Message "请选择要运行的管理脚本。" "未选择脚本" "Warning"; return }
    $scriptName = Get-SelectedScriptName $UI.ScriptCombo
    $installPath = Get-EffectiveInstallPath $project $config
    $scriptPath = Join-Path $installPath $scriptName
    if (-not (Test-Path $scriptPath -PathType Leaf)) {
        Show-Message "未找到管理脚本:`n$scriptPath`n`n请先运行安装器，或检查安装路径。" "脚本不存在" "Error"
        return
    }
    if ($scriptName -eq "launch.ps1") {
        if (-not (Confirm-Message "即将运行 launch.ps1。`n`n运行开始后会打开 PowerShell 控制台。如果需要终止运行中的服务，可在控制台按 Ctrl+C。" "继续运行 launch.ps1")) { return }
    } elseif ($scriptName -eq "terminal.ps1") {
        if (-not (Confirm-Message "即将打开 terminal.ps1 交互终端。`n`n打开后可以输入命令并回车执行；需要退出时输入 exit 并回车。" "继续打开 terminal.ps1")) { return }
    }
    if ($null -eq $config["ScriptArgs"]) { $config["ScriptArgs"] = @{} }
    $config["ScriptArgs"][$scriptName] = $UI.ScriptArgsBox.Text
    Save-ScriptParamUi $UI $State $config
    Save-ProjectConfig $key $config
    $scriptArgs = @(Build-ManagementScriptArgs $key $scriptName $config)
    if ($null -eq $scriptArgs -or $scriptArgs.Count -eq 0) { $scriptArgsText = "" } else { $scriptArgsText = Join-Shlex $scriptArgs }
    Write-Log DEBUG "management script args prepared: project=$key script=$scriptName path=$scriptPath args=$(Format-LogArgs $scriptArgs) args_text=$scriptArgsText"
    $operation = {
        param([string]$ScriptPath, [string]$ScriptArgsText, [string]$DisplayScriptName)
        function Resolve-PowerShellCommand {
            $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
            if ($null -ne $pwsh) { return $pwsh.Source }
            $powershell = Get-Command powershell -ErrorAction SilentlyContinue
            if ($null -ne $powershell) { return $powershell.Source }
            return ""
        }
        function New-ConsoleWrapperScript {
            $path = Join-Path $env:TEMP ("installer-launcher-wrapper-{0}.ps1" -f ([guid]::NewGuid().ToString("N")))
            @'
param([Parameter(Mandatory=$true)][string]$ScriptPath,[string]$ArgsTextPath="",[Parameter(Mandatory=$true)][string]$BaseExpression)
$ScriptArgsText = ""
if (-not [string]::IsNullOrWhiteSpace($ArgsTextPath) -and (Test-Path -LiteralPath $ArgsTextPath -PathType Leaf)) {
    $ScriptArgsText = (Get-Content -LiteralPath $ArgsTextPath -Raw).Trim()
}
Set-Location -LiteralPath (Split-Path -Parent $ScriptPath)
Write-Host ""
Write-Host "Running PowerShell script:" -ForegroundColor Cyan
Write-Host $ScriptPath -ForegroundColor Gray
Write-Host "Arguments:" -ForegroundColor Cyan
if (-not [string]::IsNullOrWhiteSpace($ScriptArgsText)) {
    Write-Host "  $ScriptArgsText" -ForegroundColor Gray
} else {
    Write-Host "  (none)" -ForegroundColor DarkGray
}
Write-Host ""
$Expression = $BaseExpression
if (-not [string]::IsNullOrWhiteSpace($ScriptArgsText)) { $Expression = "$Expression $ScriptArgsText" }
$invokeError = ""
try {
    Invoke-Expression $Expression
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
} catch {
    $invokeError = $_.Exception.Message
    $code = 1
}
if ($code -ne 0) {
    Write-Host ""
    Write-Host "PowerShell 脚本异常退出。" -ForegroundColor Red
    Write-Host "退出代码: $code" -ForegroundColor Red
    if (-not [string]::IsNullOrWhiteSpace($invokeError)) {
        Write-Host "错误信息: $invokeError" -ForegroundColor Red
    }
    Write-Host "请先查看上方 PowerShell 输出日志，确认具体失败原因。" -ForegroundColor Yellow
    Read-Host "按 Enter 关闭窗口"
}
exit $code
'@ | Set-Content -LiteralPath $path -Encoding UTF8
            return $path
        }
        function Quote-ProcessArgument {
            param([string]$Argument)
            if ($null -eq $Argument) { return '""' }
            if ($Argument -notmatch '[\s"]' -and $Argument.Length -gt 0) { return $Argument }
            return '"' + ($Argument -replace '"', '\"') + '"'
        }
        function Join-ProcessArguments {
            param([string[]]$Arguments)
            $quoted = @()
            foreach ($arg in $Arguments) { $quoted += (Quote-ProcessArgument $arg) }
            return ($quoted -join " ")
        }
        $command = Resolve-PowerShellCommand
        if ([string]::IsNullOrWhiteSpace($command)) {
            return [PSCustomObject]@{ Success = $false; ExitCode = 127; Message = "未找到 pwsh 或 powershell"; ScriptName = $DisplayScriptName }
        }
        $wrapper = New-ConsoleWrapperScript
        function Join-Shlex {
            param([Parameter(Mandatory)][string[]]$Arguments)
            $params = $Arguments.ForEach{
                if ($_ -match '\s|"') { "'{0}'" -f ($_ -replace "'", "''") }
                else { $_ }
            } -join ' '
            return $params
        }
        $argsTextPath = ""
        if (-not [string]::IsNullOrWhiteSpace($ScriptArgsText)) {
            $argsTextPath = Join-Path $env:TEMP ("installer-launcher-args-{0}.txt" -f ([guid]::NewGuid().ToString("N")))
            Set-Content -LiteralPath $argsTextPath -Encoding UTF8 -Value $ScriptArgsText
        }
        $baseExpression = "& " + (Join-Shlex @($command, "-NoLogo", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath))
        $argumentList = @("-NoLogo", "-ExecutionPolicy", "Bypass", "-File", $wrapper, "-ScriptPath", $ScriptPath)
        if (-not [string]::IsNullOrWhiteSpace($argsTextPath)) { $argumentList += "-ArgsTextPath"; $argumentList += $argsTextPath }
        $argumentList += "-BaseExpression"; $argumentList += $baseExpression
        $argumentLine = Join-ProcessArguments ([string[]]$argumentList)
        $process = Start-Process -FilePath $command -ArgumentList $argumentLine -Wait -PassThru -WindowStyle Normal
        Remove-Item -LiteralPath $wrapper -Force -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($argsTextPath)) { Remove-Item -LiteralPath $argsTextPath -Force -ErrorAction SilentlyContinue }
        return [PSCustomObject]@{ Success = ($process.ExitCode -eq 0); ExitCode = $process.ExitCode; Message = "管理脚本执行完成"; ProcessArgs = $argumentLine; ScriptArgsText = $ScriptArgsText; ScriptName = $DisplayScriptName }
    }
    Start-GuiOperation -UI $UI -State $State -Name "运行管理脚本" -ScriptBlock $operation -Arguments @($scriptPath, $scriptArgsText, $scriptName) -OnComplete {
        param($result, $streamErrors)
        $item = $result | Select-Object -First 1
        $displayScriptName = $item.ScriptName
        if ([string]::IsNullOrWhiteSpace($displayScriptName)) { $displayScriptName = "管理脚本" }
        if ($item.Success) {
            Write-Log DEBUG "management script process args: $($item.ProcessArgs)"
            Write-Log DEBUG "management script args text: $($item.ScriptArgsText)"
            Append-UiLog $UI "$displayScriptName 执行成功。"
        } else {
            Write-Log DEBUG "management script process args: $($item.ProcessArgs)"
            Write-Log DEBUG "management script args text: $($item.ScriptArgsText)"
            Append-UiLog $UI "$displayScriptName 执行失败，退出代码: $($item.ExitCode)"
            Show-Message "$displayScriptName 执行失败。`n退出代码: $($item.ExitCode)`n请查看 PowerShell 控制台输出。" "失败" "Error"
        }
    }
}

function Invoke-UninstallProject {
    param($UI, $State)
    $key = Get-CurrentProjectKey
    if ([string]::IsNullOrWhiteSpace($key)) { Show-Message "请先选择项目。" "未选择项目" "Warning"; return }
    $project = $script:Projects[$key]
    $config = Get-ProjectConfig $key
    if ($null -ne $State -and $null -ne $State.ConfigControls -and $State.ConfigControls.ContainsKey("INSTALL_PATH")) {
        $config = Collect-ProjectConfigFromUi $State
        Save-ProjectConfig $key $config
    }
    $path = Get-EffectiveInstallPath $project $config
    if ([string]::IsNullOrWhiteSpace($path) -or $path -eq "\" -or $path -eq ([Environment]::GetFolderPath("UserProfile"))) {
        Show-Message "卸载路径不安全，已拒绝: $path" "拒绝卸载" "Error"
        return
    }
    if (-not (Test-Path $path)) {
        Show-Message "未找到安装目录: $path" "无法卸载" "Warning"
        return
    }
    $confirmText = "DELETE $key"
    if (-not (Confirm-Message "警告：即将删除安装目录及其内部所有文件。`n`n项目: $($project.Name)`n安装目录: $path`n`n此操作不可撤销。下一步还需要输入确认文本。" "卸载 $($project.Name)")) { return }
    $typed = Show-InputDialog -Title "最终确认" -Message "请输入以下内容确认卸载:`n$confirmText" -DefaultText ""
    if ($typed -ne $confirmText) {
        Append-UiLog $UI "卸载最终确认失败，已取消。"
        return
    }
    try {
        Remove-Item -LiteralPath $path -Recurse -Force
        Append-UiLog $UI "已卸载 $($project.Name): $path"
        Show-Message "已卸载: $path" "卸载完成"
    } catch {
        Append-UiLog $UI "卸载失败: $($_.Exception.Message)"
        Show-Message "卸载失败:`n$($_.Exception.Message)" "卸载失败" "Error"
    }
    Refresh-Status $UI $State
}

function Invoke-UpdateCheck {
    param($UI, $State, [bool]$Manual)
    Write-Log DEBUG "update check requested: manual=$Manual"
    $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()
    if (-not $Manual -and -not [bool]$script:MainConfig["AUTO_UPDATE_ENABLED"]) { return }
    if (-not $Manual) {
        $last = 0
        [void][Int64]::TryParse([string]$script:MainConfig["AUTO_UPDATE_LAST_CHECK"], [ref]$last)
        if (($now - $last) -lt $script:AutoUpdateIntervalSeconds) { return }
    }
    $script:MainConfig["AUTO_UPDATE_LAST_CHECK"] = $now
    Save-MainConfig
    $operation = {
        param([string[]]$Urls, [string]$CurrentVersion, [string]$SelfPath)
        foreach ($url in $Urls) {
            try {
                $content = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 20 -ErrorAction Stop).Content
                if ($content -match '\$script:INSTALLER_LAUNCHER_GUI_VERSION\s*=\s*"([^"]+)"') {
                    $remote = $matches[1]
                    if ([version]$remote -le [version]$CurrentVersion) {
                        return [PSCustomObject]@{ Success = $true; Updated = $false; Message = "已是最新版本: $CurrentVersion" }
                    }
                    $temp = Join-Path $env:TEMP "installer_launcher_gui.update.ps1"
                    Set-Content -LiteralPath $temp -Encoding UTF8 -Value $content
                    Copy-Item -LiteralPath $temp -Destination $SelfPath -Force
                    Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
                    return [PSCustomObject]@{ Success = $true; Updated = $true; Message = "已更新到 $remote，重新启动 GUI 后生效。" }
                }
            } catch {
                $lastError = $_.Exception.Message
            }
        }
        return [PSCustomObject]@{ Success = $false; Updated = $false; Message = "更新检查失败: $lastError" }
    }
    $manualCheck = $Manual
    Start-GuiOperation -UI $UI -State $State -Name "检查更新" -ScriptBlock $operation -Arguments @((,[string[]]($script:SELF_REMOTE_URLS)), $script:INSTALLER_LAUNCHER_GUI_VERSION, $PSCommandPath) -OnComplete {
        param($result, $streamErrors)
        $item = $result | Select-Object -First 1
        if ($null -eq $item) {
            Append-UiLog $UI "更新检查没有返回结果。"
            if ($manualCheck) { Show-Message "更新检查没有返回结果。" "更新检查" "Warning" }
            return
        }
        Append-UiLog $UI $item.Message
        if ($manualCheck -or $item.Updated) {
            $icon = "Information"
            if (-not $item.Success) { $icon = "Warning" }
            Show-Message $item.Message "更新检查" $icon
        }
    }.GetNewClosure()
}

function Show-HelpWindow {
    $message = @"
Windows GUI 启动器使用说明

1. 在左侧选择要安装或管理的 WebUI / 工具。
2. 在「安装路径」中确认目标目录，在「高级选项」中调整分支、镜像、代理和开关参数。
3. 点击「保存配置」，再点击「运行安装器」。GUI 会重新下载安装器并打开 PowerShell 控制台执行。
4. 安装完成后，在「管理脚本」中选择 launch.ps1、update.ps1、terminal.ps1 等脚本运行。
5. 管理脚本参数会按当前脚本文档动态显示；结构化参数会排在「额外原始参数」之前，-NoPause 会自动追加。

代理:
- auto: 自动读取 Windows 系统代理，不覆盖已有环境变量。
- manual: 使用手动代理地址。
- off: 清理当前 GUI 进程代理变量。

日志:
$($script:LogHome)

配置:
$($script:ConfigHome)

注意:
launch.ps1 运行后可在控制台按 Ctrl+C 终止服务。
terminal.ps1 打开后输入 exit 并回车退出终端。
"@
    Show-Message $message "使用帮助"
}

function Show-LogWindow {
    if (-not (Test-Path $script:LogFile)) {
        Show-Message "还没有日志文件: $($script:LogFile)" "日志"
        return
    }
    $content = (Get-Content -LiteralPath $script:LogFile -Tail 200 -Encoding UTF8) -join [Environment]::NewLine
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="最近日志" Width="900" Height="560" WindowStartupLocation="CenterScreen">
  <Grid Margin="12">
    <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <TextBox Name="LogText" Grid.Row="0" IsReadOnly="True" AcceptsReturn="True" AcceptsTab="True" TextWrapping="NoWrap"
             VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" FontFamily="Consolas"/>
    <Button Name="CloseBtn" Grid.Row="1" Content="关闭" Width="100" Margin="0,10,0,0" HorizontalAlignment="Right"/>
  </Grid>
</Window>
"@
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $window.FindName("LogText").Text = $content
    $window.FindName("CloseBtn").Add_Click({ $window.Close() }.GetNewClosure())
    $window.ShowDialog() | Out-Null
}

function Get-ThemeColors {
    $dark = $false
    try {
        $reg = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
        if ($null -ne $reg -and $reg.AppsUseLightTheme -eq 0) { $dark = $true }
    } catch {}
    if ($dark) {
        return @{
            IsDark = $true; WinBG1 = "#E61E1E1E"; WinBG2 = "#E6121212"; PanelBG = "#661F1F1F"; TextMain = "#FFFFFF"; TextSec = "#AAAAAA"; Border = "#44FFFFFF"; InputBG = "#2B2B2B"; BtnNormal = "#3A3A3A"; BtnHover = "#4A4A4A"; ItemHover = "#33FFFFFF"; HeaderBG = "#22FFFFFF"
        }
    }
    return @{
        IsDark = $false; WinBG1 = "#EEF9FAFC"; WinBG2 = "#EEF3F7FB"; PanelBG = "#EEFFFFFF"; TextMain = "#242424"; TextSec = "#646464"; Border = "#FFD7DCE2"; InputBG = "#FCFCFD"; BtnNormal = "#FFFFFFFF"; BtnHover = "#FFF3F8FF"; ItemHover = "#FFEAF4FF"; HeaderBG = "#FFF5F9FF"
    }
}

function Start-App {
    Initialize-Directories
    $script:MainConfig = Get-DefaultMainConfig
    Write-Log INFO "gui launcher starting version=$script:INSTALLER_LAUNCHER_GUI_VERSION"
    Load-AllConfig
    Configure-ProxyFromMainConfig
    $script:RunspacePool = [runspacefactory]::CreateRunspacePool(1, 3)
    $script:RunspacePool.ApartmentState = "STA"
    $script:RunspacePool.Open()
    $colors = Get-ThemeColors
    $displayConfigHome = $script:ConfigHome
    $displayLogFile = $script:LogFile

    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$script:APP_TITLE" Height="820" Width="1280" MinHeight="720" MinWidth="1040"
        WindowStartupLocation="CenterScreen" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ResizeMode="CanResizeWithGrip">
  <Window.Resources>
    <SolidColorBrush x:Key="PrimaryBrush" Color="#0078D4"/>
    <SolidColorBrush x:Key="PrimaryHoverBrush" Color="#1689DF"/>
    <SolidColorBrush x:Key="PrimaryPressedBrush" Color="#005A9E"/>
    <SolidColorBrush x:Key="TextMainBrush" Color="$($colors.TextMain)"/>
    <SolidColorBrush x:Key="TextSecBrush" Color="$($colors.TextSec)"/>
    <SolidColorBrush x:Key="BorderBrush" Color="$($colors.Border)"/>
    <SolidColorBrush x:Key="InputBGBrush" Color="$($colors.InputBG)"/>
    <SolidColorBrush x:Key="BtnNormalBrush" Color="$($colors.BtnNormal)"/>
    <SolidColorBrush x:Key="BtnHoverBrush" Color="$($colors.BtnHover)"/>
    <SolidColorBrush x:Key="ItemHoverBrush" Color="$($colors.ItemHover)"/>
    <SolidColorBrush x:Key="HeaderBGBrush" Color="$($colors.HeaderBG)"/>
    <SolidColorBrush x:Key="PanelBGBrush" Color="$($colors.PanelBG)"/>
    <Style TargetType="Button">
      <Setter Property="Background" Value="{DynamicResource BtnNormalBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="12,7"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7" SnapsToDevicePixels="True">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource BtnHoverBrush}"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bd" Property="RenderTransform">
                  <Setter.Value><ScaleTransform ScaleX="0.98" ScaleY="0.98"/></Setter.Value>
                </Setter>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.48"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="PrimaryButton" TargetType="Button">
      <Setter Property="Background" Value="{DynamicResource PrimaryBrush}"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="12,7"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="7" SnapsToDevicePixels="True">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource PrimaryHoverBrush}"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource PrimaryPressedBrush}"/>
                <Setter TargetName="Bd" Property="RenderTransform">
                  <Setter.Value><ScaleTransform ScaleX="0.98" ScaleY="0.98"/></Setter.Value>
                </Setter>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.48"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="{DynamicResource InputBGBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="12,8"/>
      <Setter Property="MinHeight" Value="38"/>
      <Setter Property="CaretBrush" Value="{DynamicResource TextMainBrush}"/>
      <Setter Property="SelectionBrush" Value="{DynamicResource PrimaryBrush}"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Grid>
              <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6"/>
              <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}" Focusable="False" HorizontalScrollBarVisibility="{TemplateBinding HorizontalScrollBarVisibility}" VerticalScrollBarVisibility="{TemplateBinding VerticalScrollBarVisibility}"/>
              <Border x:Name="FocusLine" Height="2" CornerRadius="1" Background="{DynamicResource PrimaryBrush}" HorizontalAlignment="Stretch" VerticalAlignment="Bottom" Margin="2,0,2,1" Opacity="0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsKeyboardFocused" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="{DynamicResource PrimaryBrush}"/>
                <Setter TargetName="FocusLine" Property="Opacity" Value="1"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="{DynamicResource PrimaryBrush}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.55"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Background" Value="{DynamicResource InputBGBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="9,6"/>
      <Setter Property="MinHeight" Value="32"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
      <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Auto"/>
      <Setter Property="ScrollViewer.VerticalScrollBarVisibility" Value="Auto"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7"/>
              <ContentPresenter x:Name="ContentSite" IsHitTestVisible="False" Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" ContentStringFormat="{TemplateBinding SelectionBoxItemStringFormat}" Margin="10,0,32,0" VerticalAlignment="Center" HorizontalAlignment="Left"/>
              <Path x:Name="Arrow" Data="M 0 0 L 4 4 L 8 0 Z" Fill="{DynamicResource TextSecBrush}" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,12,0"/>
              <ToggleButton x:Name="ToggleButton" Focusable="False" Background="Transparent" BorderThickness="0" IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}" ClickMode="Press">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border Background="Transparent"/>
                  </ControlTemplate>
                </ToggleButton.Template>
              </ToggleButton>
              <Popup x:Name="Popup" Placement="Bottom" PlacementTarget="{Binding ElementName=ToggleButton}" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                <Border Background="{DynamicResource InputBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="7" MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                  <ScrollViewer Margin="4" SnapsToDevicePixels="True">
                    <ItemsPresenter KeyboardNavigation.DirectionalNavigation="Contained"/>
                  </ScrollViewer>
                </Border>
              </Popup>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="{DynamicResource PrimaryBrush}"/>
              </Trigger>
              <Trigger Property="IsKeyboardFocusWithin" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="{DynamicResource PrimaryBrush}"/>
              </Trigger>
              <Trigger Property="IsDropDownOpen" Value="True">
                <Setter TargetName="Arrow" Property="RenderTransform">
                  <Setter.Value><RotateTransform Angle="180" CenterX="4" CenterY="2"/></Setter.Value>
                </Setter>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.55"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ComboBoxItem">
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
      <Setter Property="Padding" Value="8,6"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border x:Name="Bd" Background="Transparent" CornerRadius="5" Padding="{TemplateBinding Padding}">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource ItemHoverBrush}"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource ItemHoverBrush}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
      <Setter Property="Margin" Value="0,0,0,8"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <ContentPresenter Grid.Column="0" VerticalAlignment="Center" Margin="0,0,10,0"/>
              <Border Grid.Column="1" x:Name="Track" Width="48" Height="24" CornerRadius="12" Background="{DynamicResource InputBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" HorizontalAlignment="Right">
                <Ellipse x:Name="Thumb" Width="16" Height="16" Fill="{DynamicResource TextSecBrush}" HorizontalAlignment="Left" Margin="3,0,0,0"/>
              </Border>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Track" Property="BorderBrush" Value="{DynamicResource PrimaryBrush}"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Track" Property="Background" Value="{DynamicResource PrimaryBrush}"/>
                <Setter TargetName="Track" Property="BorderBrush" Value="{DynamicResource PrimaryBrush}"/>
                <Setter TargetName="Thumb" Property="Fill" Value="White"/>
                <Setter TargetName="Thumb" Property="HorizontalAlignment" Value="Right"/>
                <Setter TargetName="Thumb" Property="Margin" Value="0,0,3,0"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.55"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TabControl">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
    </Style>
    <Style TargetType="TabItem">
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
      <Setter Property="Padding" Value="12,8"/>
      <Setter Property="Margin" Value="0,0,6,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border x:Name="Bd" Background="Transparent" CornerRadius="7" Padding="{TemplateBinding Padding}">
              <ContentPresenter ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource ItemHoverBrush}"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource HeaderBGBrush}"/>
                <Setter Property="FontWeight" Value="SemiBold"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ListBox">
      <Setter Property="Background" Value="{DynamicResource InputBGBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="4"/>
    </Style>
    <Style TargetType="ListBoxItem">
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
      <Setter Property="Padding" Value="8,6"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Border x:Name="Bd" Background="Transparent" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource ItemHoverBrush}"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource HeaderBGBrush}"/>
                <Setter Property="FontWeight" Value="SemiBold"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Border Name="MainBorder" CornerRadius="12" BorderThickness="1" BorderBrush="{DynamicResource BorderBrush}">
    <Border.Effect>
      <DropShadowEffect BlurRadius="26" ShadowDepth="0" Opacity="0.22"/>
    </Border.Effect>
    <Border.Background>
      <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
        <GradientStop Color="$($colors.WinBG1)" Offset="0"/>
        <GradientStop Color="$($colors.WinBG2)" Offset="1"/>
      </LinearGradientBrush>
    </Border.Background>
    <Grid>
      <Grid.RowDefinitions><RowDefinition Height="48"/><RowDefinition Height="*"/></Grid.RowDefinitions>
      <Grid Name="TitleBar" Grid.Row="0" Background="#08FFFFFF">
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal" Margin="18,0,0,0" VerticalAlignment="Center">
          <Border Width="24" Height="24" CornerRadius="7" Background="{DynamicResource PrimaryBrush}" Margin="0,0,10,0">
            <TextBlock Text="AI" Foreground="White" FontSize="10" FontWeight="SemiBold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <TextBlock Text="SD WebUI All In One Launcher" FontSize="15" FontWeight="SemiBold"/>
          <TextBlock Text="  v$script:INSTALLER_LAUNCHER_GUI_VERSION" FontSize="13" Foreground="{DynamicResource TextSecBrush}" VerticalAlignment="Center"/>
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
          <Button Name="HelpBtn" Content="?" Width="34" Height="32" Padding="0" Margin="0,0,2,0" BorderThickness="0" Background="Transparent"/>
          <Button Name="ShowLogBtn" Content="日志" Width="50" Height="32" Padding="0" Margin="0,0,8,0" BorderThickness="0" Background="Transparent"/>
          <Button Name="MinBtn" Content="—" Width="44" Height="32" Padding="0" Margin="0" BorderThickness="0" Background="Transparent"/>
          <Button Name="MaxBtn" Content="□" Width="44" Height="32" Padding="0" Margin="0" BorderThickness="0" Background="Transparent"/>
          <Button Name="CloseBtn" Content="×" Width="44" Height="32" Padding="0" Margin="0" BorderThickness="0" Background="Transparent"/>
        </StackPanel>
      </Grid>
      <Grid Grid.Row="1">
        <Grid.ColumnDefinitions><ColumnDefinition Width="112"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
        <Border Grid.Column="0" Background="#22FFFFFF" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="0,1,1,0">
          <DockPanel Margin="8,14,8,14">
            <StackPanel DockPanel.Dock="Top">
              <Button Name="OneClickNavBtn" Width="72" Height="72" Padding="4" Margin="0,0,0,10" BorderThickness="1">
                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                  <TextBlock Text="▶" FontSize="20" HorizontalAlignment="Center" Margin="0,0,0,4"/>
                  <TextBlock Name="OneClickNavLabel" Text="一键启动" FontSize="12" HorizontalAlignment="Center"/>
                </StackPanel>
              </Button>
              <Button Name="AdvancedNavBtn" Width="72" Height="72" Padding="4" Margin="0,0,0,10" BorderThickness="1">
                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                  <TextBlock Text="☷" FontSize="20" HorizontalAlignment="Center" Margin="0,0,0,4"/>
                  <TextBlock Name="AdvancedNavLabel" Text="高级选项" FontSize="12" HorizontalAlignment="Center"/>
                </StackPanel>
              </Button>
              <Button Name="SoftwareNavBtn" Width="72" Height="72" Padding="4" Margin="0,0,0,10" BorderThickness="1">
                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                  <TextBlock Text="▣" FontSize="20" HorizontalAlignment="Center" Margin="0,0,0,4"/>
                  <TextBlock Name="SoftwareNavLabel" Text="软件选择" FontSize="12" HorizontalAlignment="Center"/>
                </StackPanel>
              </Button>
            </StackPanel>
            <StackPanel DockPanel.Dock="Bottom">
              <Button Name="SettingsNavBtn" Width="72" Height="72" Padding="4" BorderThickness="1">
                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                  <TextBlock Text="⚙" FontSize="20" HorizontalAlignment="Center" Margin="0,0,0,4"/>
                  <TextBlock Name="SettingsNavLabel" Text="设置" FontSize="12" HorizontalAlignment="Center"/>
                </StackPanel>
              </Button>
            </StackPanel>
          </DockPanel>
        </Border>
        <Grid Grid.Column="1" Margin="24,20,24,20">
          <Grid Name="StartPage">
          <Grid.RowDefinitions><RowDefinition Height="142"/><RowDefinition Height="*"/><RowDefinition Height="132"/></Grid.RowDefinitions>
          <Border Grid.Row="0" CornerRadius="10" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" Padding="22" Margin="0,0,0,18">
            <Border.Background>
              <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                <GradientStop Color="#FF0B75C9" Offset="0"/>
                <GradientStop Color="#CC39D1C8" Offset="0.56"/>
                <GradientStop Color="#55FFFFFF" Offset="1"/>
              </LinearGradientBrush>
            </Border.Background>
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="300"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <StackPanel VerticalAlignment="Center">
                <TextBlock Text="AI WebUI 安装与管理" Foreground="White" FontSize="16" Opacity="0.9"/>
                <TextBlock Text="启动器控制台" Foreground="White" FontSize="26" FontWeight="Bold" Margin="0,6,0,0"/>
              </StackPanel>
              <TextBlock Grid.Column="1" Name="ProjectStatusText" TextWrapping="Wrap" Foreground="White" FontSize="13" MaxWidth="760" VerticalAlignment="Center" Margin="28,0,20,0"/>
              <StackPanel Grid.Column="2" VerticalAlignment="Bottom" HorizontalAlignment="Right">
                <TextBlock Name="BusyText" HorizontalAlignment="Right" Foreground="White" Opacity="0.9" Margin="0,0,8,12"/>
              </StackPanel>
            </Grid>
          </Border>
          <Grid Grid.Row="1">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="330"/></Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="{DynamicResource PanelBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="10" Padding="18" Margin="0,0,18,0">
              <DockPanel>
                <StackPanel DockPanel.Dock="Top" Margin="0,0,0,16">
                  <TextBlock Text="启动方式" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,10"/>
                </StackPanel>
                <TabControl Name="StartModeTabs">
                  <TabItem Header="启动模式">
                    <Grid Margin="2,14,2,0">
                      <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                      <TextBlock Name="StartHintText" TextWrapping="Wrap" Foreground="{DynamicResource TextSecBrush}" Margin="0,0,0,12"/>
                      <ListBox Name="LaunchScriptList" Grid.Row="1" DisplayMemberPath="Label"/>
                    </Grid>
                  </TabItem>
                  <TabItem Header="安装模式">
                    <Border Margin="2,14,2,0" Background="{DynamicResource HeaderBGBrush}" CornerRadius="8" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" Padding="14">
                      <TextBlock Name="InstallHintText" TextWrapping="Wrap" Foreground="{DynamicResource TextSecBrush}"/>
                    </Border>
                  </TabItem>
                </TabControl>
              </DockPanel>
            </Border>
            <Border Grid.Column="1" Background="{DynamicResource PanelBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="10" Padding="18">
              <StackPanel>
                <TextBlock Text="快速操作" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,14"/>
                <TextBlock Text="已安装后：使用启动模式，选择 launch.ps1 启动软件，或选择 update.ps1 / terminal.ps1 做维护。" Foreground="{DynamicResource TextSecBrush}" TextWrapping="Wrap" Margin="0,0,0,10"/>
                <TextBlock Text="未安装时：先在「高级选项」确认安装路径、分支和镜像，再切回安装模式运行安装器。" Foreground="{DynamicResource TextSecBrush}" TextWrapping="Wrap" Margin="0,0,0,10"/>
                <TextBlock Text="如果检测到安装不完整，请重新运行安装器修复后再启动。" Foreground="{DynamicResource TextSecBrush}" TextWrapping="Wrap" Margin="0,0,0,18"/>
                <Border Background="{DynamicResource HeaderBGBrush}" CornerRadius="8" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" Padding="14" Margin="0,0,0,14">
                  <TextBlock Text="PowerShell 脚本会在独立控制台中运行；如果返回非零退出码，窗口会停留以便查看上游日志。" TextWrapping="Wrap" Foreground="{DynamicResource TextSecBrush}"/>
                </Border>
                <TextBlock Text="右下角统一启动按钮会根据当前模式运行安装器或所选管理脚本。" TextWrapping="Wrap" Foreground="{DynamicResource TextSecBrush}" Margin="0,0,0,18"/>
                <Button Name="UnifiedStartBtn" Content="▶ 启动所选脚本" Style="{StaticResource PrimaryButton}" Padding="18,12" FontSize="16" HorizontalAlignment="Stretch"/>
              </StackPanel>
            </Border>
          </Grid>
          <Border Grid.Row="2" Background="{DynamicResource PanelBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="10" Padding="8" Margin="0,16,0,0">
            <DockPanel>
              <TextBlock DockPanel.Dock="Top" Text="运行日志" FontWeight="SemiBold" Margin="2,0,0,4"/>
              <TextBox Name="LogBox" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="Transparent" BorderThickness="0" Padding="4,2" VerticalContentAlignment="Top" FontFamily="Consolas"/>
            </DockPanel>
          </Border>
          </Grid>
          <Grid Name="AdvancedPage" Visibility="Collapsed">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
            <DockPanel Grid.Row="0" Margin="0,0,0,18">
              <StackPanel>
                <TextBlock Text="高级选项" FontSize="28" FontWeight="Bold"/>
                <TextBlock Text="设置安装路径、安装器参数和管理脚本参数。" Foreground="{DynamicResource TextSecBrush}" Margin="0,4,0,0"/>
              </StackPanel>
              <Button Name="SaveConfigBtn" DockPanel.Dock="Right" Content="保存配置" Style="{StaticResource PrimaryButton}" Padding="16,9" HorizontalAlignment="Right"/>
            </DockPanel>
            <Border Grid.Row="1" Background="{DynamicResource PanelBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="10" Padding="18">
              <TabControl Name="MainTabs">
                <TabItem Header="安装路径">
                  <DockPanel Margin="2,14,2,0">
                    <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" Margin="0,14,0,0">
                      <Button Name="UninstallBtn" Content="卸载已安装软件"/>
                    </StackPanel>
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                      <StackPanel>
                        <StackPanel Name="PathPanel"/>
                        <Border Background="{DynamicResource HeaderBGBrush}" CornerRadius="8" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" Padding="14" Margin="0,8,0,0">
                          <TextBlock Text="安装路径用于检测当前项目是否已安装，也会作为 -InstallPath 传给安装器。卸载按钮会删除该路径指向的已安装软件，并要求二次确认。" TextWrapping="Wrap" Foreground="{DynamicResource TextSecBrush}"/>
                        </Border>
                      </StackPanel>
                    </ScrollViewer>
                  </DockPanel>
                </TabItem>
                <TabItem Header="安装器设置">
                  <DockPanel Margin="2,14,2,0">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                      <StackPanel Name="ConfigPanel"/>
                    </ScrollViewer>
                  </DockPanel>
                </TabItem>
                <TabItem Header="管理脚本设置">
                  <Grid Margin="2,14,2,0">
                    <Grid.RowDefinitions>
                      <RowDefinition Height="Auto"/>
                      <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <ComboBox Name="ScriptCombo" Grid.Row="0" Margin="0,0,0,12" DisplayMemberPath="Label"/>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,0,0,14">
                      <StackPanel>
                        <StackPanel Name="ScriptParamPanel"/>
                        <TextBlock Text="额外原始参数（追加到结构化参数之后）" FontWeight="SemiBold" Margin="0,4,0,8"/>
                        <TextBox Name="ScriptArgsBox" MinHeight="96" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" ToolTip="保存给当前管理脚本的额外原始参数"/>
                      </StackPanel>
                    </ScrollViewer>
                  </Grid>
                </TabItem>
              </TabControl>
            </Border>
          </Grid>
          <Grid Name="SoftwarePage" Visibility="Collapsed">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
            <StackPanel Grid.Row="0" Margin="0,0,0,18">
              <TextBlock Text="软件选择" FontSize="28" FontWeight="Bold"/>
              <TextBlock Text="选择要安装或管理的 WebUI / 工具。切换后会自动刷新安装状态和可用脚本。" Foreground="{DynamicResource TextSecBrush}" Margin="0,4,0,0"/>
            </StackPanel>
            <Border Grid.Row="1" Background="{DynamicResource PanelBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="10" Padding="18">
              <ListBox Name="ProjectList" DisplayMemberPath="Name"/>
            </Border>
          </Grid>
          <Grid Name="SettingsPage" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <DockPanel Grid.Row="0" Margin="0,0,0,18">
            <StackPanel>
              <TextBlock Text="启动器设置" FontSize="28" FontWeight="Bold"/>
              <TextBlock Text="管理自动更新、欢迎页、日志等级、代理和配置文件位置。" Foreground="{DynamicResource TextSecBrush}" Margin="0,4,0,0"/>
            </StackPanel>
          </DockPanel>
          <Grid Grid.Row="1">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="360"/></Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="{DynamicResource PanelBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="10" Padding="22" Margin="0,0,18,0">
              <ScrollViewer VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="680" HorizontalAlignment="Left">
                  <TextBlock Text="基础行为" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,14"/>
                  <CheckBox Name="AutoUpdateCheck" Content="启动时自动检查更新"/>
                  <CheckBox Name="WelcomeCheck" Content="启动时显示欢迎提示" Margin="0,0,0,18"/>
                  <TextBlock Text="日志等级" FontWeight="SemiBold" Margin="0,0,0,5"/>
                  <ComboBox Name="LogLevelCombo" Margin="0,0,0,14"/>
                  <TextBlock Text="代理模式" FontWeight="SemiBold" Margin="0,0,0,5"/>
                  <ComboBox Name="ProxyModeCombo" Margin="0,0,0,14"/>
                  <TextBlock Text="手动代理地址" FontWeight="SemiBold" Margin="0,0,0,5"/>
                  <TextBox Name="ManualProxyBox" Margin="0,0,0,20"/>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,18">
                    <Button Name="SaveMainBtn" Content="保存设置" Style="{StaticResource PrimaryButton}"/>
                    <Button Name="CheckUpdateBtn" Content="检查更新"/>
                    <Button Name="OpenConfigFolderBtn" Content="打开配置文件夹"/>
                  </StackPanel>
                </StackPanel>
              </ScrollViewer>
            </Border>
            <Border Grid.Column="1" Background="{DynamicResource PanelBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="10" Padding="18">
              <StackPanel>
                <TextBlock Text="设置说明" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,14"/>
                <TextBlock Text="自动更新只会更新启动器自身，失败不会阻止你继续使用当前版本。" Foreground="{DynamicResource TextSecBrush}" TextWrapping="Wrap" Margin="0,0,0,12"/>
                <TextBlock Text="代理模式 auto 会读取 Windows 系统代理；manual 使用下方手动地址；off 会清理当前启动器进程中的代理变量。" Foreground="{DynamicResource TextSecBrush}" TextWrapping="Wrap"/>
              </StackPanel>
            </Border>
          </Grid>
          </Grid>
        </Grid>
      </Grid>
    </Grid>
  </Border>
</Window>
"@
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $window.Dispatcher.add_UnhandledException({
        param($sender, $eventArgs)
        Report-UiError -Context "WPF 事件处理" -ErrorObject $eventArgs.Exception -ShowDialog $true
        $eventArgs.Handled = $true
    })
    $UI = [PSCustomObject]@{
        Window = $window; TitleBar = $window.FindName("TitleBar"); MinBtn = $window.FindName("MinBtn"); MaxBtn = $window.FindName("MaxBtn"); CloseBtn = $window.FindName("CloseBtn")
        MainBorder = $window.FindName("MainBorder"); StartPage = $window.FindName("StartPage"); AdvancedPage = $window.FindName("AdvancedPage"); SoftwarePage = $window.FindName("SoftwarePage"); SettingsPage = $window.FindName("SettingsPage"); MainTabs = $window.FindName("MainTabs"); ProjectList = $window.FindName("ProjectList"); ProjectStatusText = $window.FindName("ProjectStatusText"); BusyText = $window.FindName("BusyText")
        PathPanel = $window.FindName("PathPanel"); ConfigPanel = $window.FindName("ConfigPanel"); SaveConfigBtn = $window.FindName("SaveConfigBtn")
        ScriptCombo = $window.FindName("ScriptCombo"); ScriptParamPanel = $window.FindName("ScriptParamPanel"); ScriptArgsBox = $window.FindName("ScriptArgsBox")
        StartModeTabs = $window.FindName("StartModeTabs"); LaunchScriptList = $window.FindName("LaunchScriptList"); UnifiedStartBtn = $window.FindName("UnifiedStartBtn"); StartHintText = $window.FindName("StartHintText"); InstallHintText = $window.FindName("InstallHintText")
        AutoUpdateCheck = $window.FindName("AutoUpdateCheck"); WelcomeCheck = $window.FindName("WelcomeCheck"); LogLevelCombo = $window.FindName("LogLevelCombo"); ProxyModeCombo = $window.FindName("ProxyModeCombo"); ManualProxyBox = $window.FindName("ManualProxyBox")
        SaveMainBtn = $window.FindName("SaveMainBtn"); CheckUpdateBtn = $window.FindName("CheckUpdateBtn"); OpenConfigFolderBtn = $window.FindName("OpenConfigFolderBtn"); UninstallBtn = $window.FindName("UninstallBtn"); OneClickNavBtn = $window.FindName("OneClickNavBtn"); AdvancedNavBtn = $window.FindName("AdvancedNavBtn"); SoftwareNavBtn = $window.FindName("SoftwareNavBtn"); SettingsNavBtn = $window.FindName("SettingsNavBtn"); OneClickNavLabel = $window.FindName("OneClickNavLabel"); AdvancedNavLabel = $window.FindName("AdvancedNavLabel"); SoftwareNavLabel = $window.FindName("SoftwareNavLabel"); SettingsNavLabel = $window.FindName("SettingsNavLabel"); HelpBtn = $window.FindName("HelpBtn"); ShowLogBtn = $window.FindName("ShowLogBtn")
        LogBox = $window.FindName("LogBox")
    }
    $State = [PSCustomObject]@{ CurrentOperation = $null; ConfigControls = @{}; ScriptParamControls = @{}; ProjectConfig = @{}; StatusRefreshTimer = $null; LastOneClickStatus = "" }
    $mainConfig = $script:MainConfig

    $UI.LogLevelCombo.ItemsSource = @("DEBUG", "INFO", "WARN", "ERROR")
    $UI.ProxyModeCombo.ItemsSource = @("auto", "manual", "off")
    $UI.StartModeTabs.SelectedIndex = 0
    Update-OneClickModeUi $UI
    Refresh-MainConfigUi $UI
    $projectItems = @()
    $projectShortNames = @{
        sd_webui = "SD WebUI"
        comfyui = "ComfyUI"
        invokeai = "InvokeAI"
        fooocus = "Fooocus"
        sd_trainer = "Trainer"
        sd_trainer_script = "Scripts"
        qwen_tts_webui = "Qwen TTS"
    }
    foreach ($key in $script:Projects.Keys) {
        $shortName = $script:Projects[$key].Name
        if ($projectShortNames.ContainsKey($key)) { $shortName = $projectShortNames[$key] }
        $projectItems += [PSCustomObject]@{ Key = $key; Name = $script:Projects[$key].Name; ShortName = $shortName }
    }
    $UI.ProjectList.ItemsSource = $projectItems
    foreach ($item in $projectItems) {
        if ($item.Key -eq $mainConfig["CURRENT_PROJECT"]) { $UI.ProjectList.SelectedItem = $item; break }
    }

    $UI.ProjectList.Add_SelectionChanged({
        try {
            if ($null -eq $UI.ProjectList.SelectedItem) { return }
            $mainConfig["CURRENT_PROJECT"] = $UI.ProjectList.SelectedItem.Key
            Save-MainConfig
            Refresh-ProjectConfigUi $UI $State
            Refresh-Status $UI $State
            Select-RelevantMainTab $UI
            $currentProject = $mainConfig["CURRENT_PROJECT"]
            Append-UiLog $UI "当前项目已切换: $currentProject"
        } catch {
            Report-UiError -Context "切换项目" -ErrorObject $_ -ShowDialog $true
        }
    }.GetNewClosure())
    $UI.SaveConfigBtn.Add_Click({
        $key = Get-CurrentProjectKey
        if ([string]::IsNullOrWhiteSpace($key)) { Show-Message "请先选择项目。" "未选择项目" "Warning"; return }
        Save-ProjectConfig $key (Collect-ProjectAndScriptConfigFromUi $UI $State)
        Refresh-Status $UI $State
        Append-UiLog $UI "项目配置和当前管理脚本参数已保存: $key"
    }.GetNewClosure())
    $UI.StartModeTabs.Add_SelectionChanged({ Update-OneClickModeUi $UI }.GetNewClosure())
    $UI.UnifiedStartBtn.Add_Click({ Invoke-OneClickAction $UI $State }.GetNewClosure())
    $UI.ScriptCombo.Add_SelectionChanged({
        $key = Get-CurrentProjectKey
        if ([string]::IsNullOrWhiteSpace($key) -or $null -eq $UI.ScriptCombo.SelectedItem) { return }
        $config = Get-ProjectConfig $key
        $scriptName = Get-SelectedScriptName $UI.ScriptCombo
        if ($null -ne $config["ScriptArgs"] -and (Test-DictionaryKey $config["ScriptArgs"] $scriptName)) {
            $UI.ScriptArgsBox.Text = [string]$config["ScriptArgs"][$scriptName]
        } else {
            $UI.ScriptArgsBox.Text = ""
        }
        Refresh-ScriptParamUi $UI $State
    }.GetNewClosure())
    $UI.SaveMainBtn.Add_Click({
        Save-MainConfigFromUi $UI
        Refresh-Status $UI $State
        Append-UiLog $UI "启动器设置已保存。"
    }.GetNewClosure())
    $UI.CheckUpdateBtn.Add_Click({ Invoke-UpdateCheck $UI $State $true }.GetNewClosure())
    $UI.OpenConfigFolderBtn.Add_Click({ Open-ConfigFolder }.GetNewClosure())
    $UI.OneClickNavBtn.Add_Click({ Show-AppPage $UI "start" }.GetNewClosure())
    $UI.AdvancedNavBtn.Add_Click({ Show-AppPage $UI "advanced"; Select-RelevantMainTab $UI }.GetNewClosure())
    $UI.SoftwareNavBtn.Add_Click({ Show-AppPage $UI "software" }.GetNewClosure())
    $UI.SettingsNavBtn.Add_Click({ Show-AppPage $UI "settings" }.GetNewClosure())
    $UI.UninstallBtn.Add_Click({ Invoke-UninstallProject $UI $State }.GetNewClosure())
    $UI.HelpBtn.Add_Click({ Show-HelpWindow }.GetNewClosure())
    $UI.ShowLogBtn.Add_Click({ Show-LogWindow }.GetNewClosure())

    $script:RestoreBounds = $null
    $UI.TitleBar.Add_MouseLeftButtonDown({
        if ($_.ClickCount -eq 2) { $UI.MaxBtn.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent))); return }
        $window.DragMove()
    })
    $UI.MinBtn.Add_Click({ $window.WindowState = "Minimized" })
    $UI.MaxBtn.Add_Click({
        if ($window.WindowState -eq "Maximized") { $window.WindowState = "Normal"; $UI.MaxBtn.Content = "□"; $UI.MainBorder.CornerRadius = 12 } else { $window.WindowState = "Maximized"; $UI.MaxBtn.Content = "❐"; $UI.MainBorder.CornerRadius = 0 }
    })
    $UI.CloseBtn.Add_Click({ $window.Close() })
    $window.Add_Loaded({
        try {
            try {
                $handle = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
                [LauncherWindowHelper]::EnableBlur($handle)
                [LauncherWindowHelper]::SetDarkMode($handle, [bool]$colors.IsDark)
                [LauncherWindowHelper]::SetRounding($handle, $true)
            } catch {
                Write-Log WARN "window decoration setup failed: $($_.Exception.Message)"
            }
            Refresh-ProjectConfigUi $UI $State
            Refresh-Status $UI $State
            Select-RelevantMainTab $UI
            Show-AppPage $UI "start"
            Append-UiLog $UI "GUI 启动完成。配置: $displayConfigHome 日志: $displayLogFile"
            if ([bool]$mainConfig["SHOW_WELCOME_SCREEN"]) {
                Append-UiLog $UI "选择项目，调整配置，然后运行安装器。"
            }

            $statusRefreshTimer = New-Object System.Windows.Threading.DispatcherTimer
            $statusRefreshTimer.Interval = [TimeSpan]::FromSeconds(15)
            $statusRefreshTimer.Add_Tick({
                try {
                    if ($null -ne $State.CurrentOperation) { return }
                    Refresh-Status $UI $State
                } catch {
                    Report-UiError -Context "自动刷新安装状态" -ErrorObject $_ -ShowDialog $false
                }
            }.GetNewClosure())
            $State.StatusRefreshTimer = $statusRefreshTimer
            $statusRefreshTimer.Start()

            $startupUpdateTimer = New-Object System.Windows.Threading.DispatcherTimer
            $startupUpdateTimer.Interval = [TimeSpan]::FromMilliseconds(1200)
            $startupUpdateTimer.Add_Tick({
                $startupUpdateTimer.Stop()
                try {
                    Invoke-UpdateCheck $UI $State $false
                } catch {
                    Report-UiError -Context "启动时自动更新检查" -ErrorObject $_ -ShowDialog $false
                    Append-UiLog $UI "启动时自动更新检查失败，已继续运行当前版本。"
                }
            }.GetNewClosure())
            $startupUpdateTimer.Start()
        } catch {
            Report-UiError -Context "GUI 初始化" -ErrorObject $_ -ShowDialog $true
        }
    }.GetNewClosure())
    $window.ShowDialog() | Out-Null
    if ($null -ne $State.StatusRefreshTimer) { $State.StatusRefreshTimer.Stop() }
    if ($null -ne $script:RunspacePool) { $script:RunspacePool.Close(); $script:RunspacePool.Dispose() }
    Write-Log INFO "gui launcher exited"
}

try {
    Start-App
} catch {
    try { Write-Log ERROR "fatal gui error: $($_.Exception.Message)" } catch {}
    [System.Windows.MessageBox]::Show("启动器异常退出:`n$($_.Exception.Message)`n`n日志: $($script:LogFile)", "启动器错误", "OK", "Error") | Out-Null
    throw
}
