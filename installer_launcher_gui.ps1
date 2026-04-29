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
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    public static void SetDarkMode(IntPtr hwnd, bool enabled) {
        int preference = enabled ? 1 : 0;
        DwmSetWindowAttribute(hwnd, 20, ref preference, sizeof(int));
    }

    public static void SetRounding(IntPtr hwnd, bool enabled) {
        int preference = enabled ? 2 : 1;
        DwmSetWindowAttribute(hwnd, 33, ref preference, sizeof(int));
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
    if ((Test-ProjectParam $Project "NoPause") -and -not (@($args) -contains "-NoPause")) { $args.Add("-NoPause") }
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
Invoke-Expression $Expression
$code = $LASTEXITCODE
if ($null -eq $code) { $code = 0 }
if ($code -ne 0) {
    Write-Host ""
    Write-Host "PowerShell 脚本异常退出。" -ForegroundColor Red
    Write-Host "退出代码: $code" -ForegroundColor Red
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
    if ($null -ne $UI.LogBox) {
        $UI.LogBox.AppendText($line + [Environment]::NewLine)
        $UI.LogBox.ScrollToEnd()
    }
    Write-Log INFO $Text
}

function Set-UiBusy {
    param($UI, [bool]$Busy, [string]$Message)
    $enabled = -not $Busy
    foreach ($button in @($UI.RunInstallerBtn, $UI.RunScriptBtn, $UI.UninstallBtn, $UI.SaveConfigBtn, $UI.RefreshStatusBtn, $UI.CheckUpdateBtn)) {
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
            $config[$key] = [string]$control.SelectedValue
            if ([string]::IsNullOrWhiteSpace($config[$key]) -and $null -ne $control.Text) { $config[$key] = [string]$control.Text }
        } elseif ($control -is [System.Windows.Controls.TextBox]) {
            $config[$key] = $control.Text
        }
    }
    return $config
}

function Add-ConfigTextBox {
    param($Panel, $State, [string]$Key, [string]$Label, [string]$Value)
    $block = New-Object System.Windows.Controls.StackPanel
    $block.Margin = "0,0,0,10"
    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = $Label
    $text.Margin = "0,0,0,4"
    $box = New-Object System.Windows.Controls.TextBox
    $box.Text = $Value
    $block.Children.Add($text) | Out-Null
    $block.Children.Add($box) | Out-Null
    $Panel.Children.Add($block) | Out-Null
    $State.ConfigControls[$Key] = $box
}

function Add-ConfigComboBox {
    param($Panel, $State, [string]$Key, [string]$Label, [System.Collections.IDictionary]$Options, [string]$Value)
    $block = New-Object System.Windows.Controls.StackPanel
    $block.Margin = "0,0,0,10"
    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = $Label
    $text.Margin = "0,0,0,4"
    $combo = New-Object System.Windows.Controls.ComboBox
    $combo.IsEditable = $true
    if ($null -ne $Options) {
        foreach ($optionKey in $Options.Keys) {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = "$optionKey - $($Options[$optionKey])"
            $item.Tag = $optionKey
            $combo.Items.Add($item) | Out-Null
            if ($optionKey -eq $Value) { $combo.SelectedItem = $item }
        }
    }
    if ($null -eq $combo.SelectedItem -and -not [string]::IsNullOrWhiteSpace($Value)) {
        $combo.Text = $Value
    }
    $combo.Add_SelectionChanged({
        if ($null -ne $combo.SelectedItem -and $null -ne $combo.SelectedItem.Tag) {
            $combo.SelectedValue = [string]$combo.SelectedItem.Tag
        }
    }.GetNewClosure())
    $block.Children.Add($text) | Out-Null
    $block.Children.Add($combo) | Out-Null
    $Panel.Children.Add($block) | Out-Null
    $State.ConfigControls[$Key] = $combo
}

function Add-ConfigCheckBox {
    param($Panel, $State, [string]$Key, [string]$Label, [bool]$Value)
    $box = New-Object System.Windows.Controls.CheckBox
    $box.Content = $Label
    $box.IsChecked = $Value
    $box.Margin = "0,0,0,8"
    $Panel.Children.Add($box) | Out-Null
    $State.ConfigControls[$Key] = $box
}

function Refresh-ProjectConfigUi {
    param($UI, $State)
    $UI.ConfigPanel.Children.Clear()
    $State.ConfigControls = @{}
    $key = Get-CurrentProjectKey
    if ([string]::IsNullOrWhiteSpace($key)) {
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
    if (Test-ProjectParam $project "InstallPath") { Add-ConfigTextBox $UI.ConfigPanel $State "INSTALL_PATH" "安装路径（留空使用默认: $(Get-EffectiveInstallPath $project $config)）" $config["INSTALL_PATH"] }
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
        return
    }
    $project = $script:Projects[$key]
    $config = Get-ProjectConfig $key
    $status = Get-InstallationStatus $project $config
    $proxyMode = $script:MainConfig["PROXY_MODE"]
    $autoUpdate = $script:MainConfig["AUTO_UPDATE_ENABLED"]
    $UI.ProjectStatusText.Text = "当前项目: $($project.Name)`n安装状态: $($status.Label)`n$($status.Detail)`n代理模式: $proxyMode    自动更新: $autoUpdate"
    $scripts = @()
    foreach ($scriptName in $project.Scripts.Keys) {
        $scripts += [PSCustomObject]@{ Name = $scriptName; Label = "$scriptName - $($project.Scripts[$scriptName])" }
    }
    $UI.ScriptCombo.ItemsSource = $scripts
    $UI.ScriptCombo.DisplayMemberPath = "Label"
    $UI.ScriptCombo.SelectedValuePath = "Name"
    if ($scripts.Count -gt 0) { $UI.ScriptCombo.SelectedIndex = 0 }
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
    $config = Collect-ProjectConfigFromUi $State
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
Invoke-Expression $Expression
$code = $LASTEXITCODE
if ($null -eq $code) { $code = 0 }
if ($code -ne 0) {
    Write-Host ""
    Write-Host "PowerShell 脚本异常退出。" -ForegroundColor Red
    Write-Host "退出代码: $code" -ForegroundColor Red
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
    $scriptName = $selected.Name
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
    $argsText = ""
    if ($null -ne $config["ScriptArgs"] -and (Test-DictionaryKey $config["ScriptArgs"] $scriptName)) { $argsText = [string]$config["ScriptArgs"][$scriptName] }
    if ([string]::IsNullOrWhiteSpace($argsText)) { $scriptArgs = @() } else { $scriptArgs = @(Split-Shlex $argsText) }
    if ($null -eq $scriptArgs -or $scriptArgs.Count -eq 0) { $scriptArgsText = "" } else { $scriptArgsText = Join-Shlex $scriptArgs }
    Write-Log DEBUG "management script args prepared: project=$key script=$scriptName path=$scriptPath args=$(Format-LogArgs $scriptArgs) args_text=$scriptArgsText"
    $operation = {
        param([string]$ScriptPath, [string]$ScriptArgsText)
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
Invoke-Expression $Expression
$code = $LASTEXITCODE
if ($null -eq $code) { $code = 0 }
if ($code -ne 0) {
    Write-Host ""
    Write-Host "PowerShell 脚本异常退出。" -ForegroundColor Red
    Write-Host "退出代码: $code" -ForegroundColor Red
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
            return [PSCustomObject]@{ Success = $false; ExitCode = 127; Message = "未找到 pwsh 或 powershell" }
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
        return [PSCustomObject]@{ Success = ($process.ExitCode -eq 0); ExitCode = $process.ExitCode; Message = "管理脚本执行完成"; ProcessArgs = $argumentLine; ScriptArgsText = $ScriptArgsText }
    }
    Start-GuiOperation -UI $UI -State $State -Name "运行管理脚本" -ScriptBlock $operation -Arguments @($scriptPath, $scriptArgsText) -OnComplete {
        param($result, $streamErrors)
        $item = $result | Select-Object -First 1
        if ($item.Success) {
            Write-Log DEBUG "management script process args: $($item.ProcessArgs)"
            Write-Log DEBUG "management script args text: $($item.ScriptArgsText)"
            Append-UiLog $UI "$scriptName 执行成功。"
        } else {
            Write-Log DEBUG "management script process args: $($item.ProcessArgs)"
            Write-Log DEBUG "management script args text: $($item.ScriptArgsText)"
            Append-UiLog $UI "$scriptName 执行失败，退出代码: $($item.ExitCode)"
            Show-Message "$scriptName 执行失败。`n退出代码: $($item.ExitCode)`n请查看 PowerShell 控制台输出。" "失败" "Error"
        }
    }
}

function Invoke-UninstallProject {
    param($UI, $State)
    $key = Get-CurrentProjectKey
    if ([string]::IsNullOrWhiteSpace($key)) { Show-Message "请先选择项目。" "未选择项目" "Warning"; return }
    $project = $script:Projects[$key]
    $config = Get-ProjectConfig $key
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
2. 在“安装器配置”中调整安装路径、分支、镜像、代理和开关参数。
3. 点击“保存配置”，再点击“运行安装器”。GUI 会重新下载安装器并打开 PowerShell 控制台执行。
4. 安装完成后，在“管理脚本”中选择 launch.ps1、update.ps1、terminal.ps1 等脚本运行。

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
            IsDark = $true; WinBG1 = "#CC1E1E1E"; WinBG2 = "#CC121212"; PanelBG = "#44000000"; TextMain = "#FFFFFF"; TextSec = "#AAAAAA"; Border = "#44FFFFFF"; InputBG = "#333333"; BtnNormal = "#4A4A4A"; BtnHover = "#5A5A5A"; ItemHover = "#33FFFFFF"; HeaderBG = "#11FFFFFF"
        }
    }
    return @{
        IsDark = $false; WinBG1 = "#CCF9FAFB"; WinBG2 = "#CCF3F4F6"; PanelBG = "#44FFFFFF"; TextMain = "#323130"; TextSec = "#666666"; Border = "#88C1C1C1"; InputBG = "#FFFFFF"; BtnNormal = "#FFFFFF"; BtnHover = "#F9F9F9"; ItemHover = "#F2F7FF"; HeaderBG = "#F9FAFB"
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
        Title="$script:APP_TITLE" Height="760" Width="1120" MinHeight="680" MinWidth="980"
        WindowStartupLocation="CenterScreen" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ResizeMode="CanResizeWithGrip">
  <Window.Resources>
    <SolidColorBrush x:Key="PrimaryBrush" Color="#0078D4"/>
    <SolidColorBrush x:Key="TextMainBrush" Color="$($colors.TextMain)"/>
    <SolidColorBrush x:Key="TextSecBrush" Color="$($colors.TextSec)"/>
    <SolidColorBrush x:Key="BorderBrush" Color="$($colors.Border)"/>
    <SolidColorBrush x:Key="InputBGBrush" Color="$($colors.InputBG)"/>
    <SolidColorBrush x:Key="BtnNormalBrush" Color="$($colors.BtnNormal)"/>
    <SolidColorBrush x:Key="PanelBGBrush" Color="$($colors.PanelBG)"/>
    <Style TargetType="Button">
      <Setter Property="Background" Value="{DynamicResource BtnNormalBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
    </Style>
    <Style x:Key="PrimaryButton" TargetType="Button">
      <Setter Property="Background" Value="#0078D4"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="{DynamicResource InputBGBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/>
      <Setter Property="Padding" Value="7,4"/>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Background" Value="{DynamicResource InputBGBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
      <Setter Property="Padding" Value="6,3"/>
    </Style>
    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="{DynamicResource TextMainBrush}"/>
    </Style>
  </Window.Resources>
  <Border Name="MainBorder" CornerRadius="12" BorderThickness="1" BorderBrush="{DynamicResource BorderBrush}">
    <Border.Background>
      <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
        <GradientStop Color="$($colors.WinBG1)" Offset="0"/>
        <GradientStop Color="$($colors.WinBG2)" Offset="1"/>
      </LinearGradientBrush>
    </Border.Background>
    <Grid>
      <Grid.RowDefinitions><RowDefinition Height="34"/><RowDefinition Height="*"/></Grid.RowDefinitions>
      <Grid Name="TitleBar" Grid.Row="0">
        <StackPanel Orientation="Horizontal" Margin="14,0,0,0" VerticalAlignment="Center">
          <TextBlock Text="SD WebUI All In One Launcher GUI" FontSize="12" Foreground="{DynamicResource TextSecBrush}"/>
          <TextBlock Text="  v$script:INSTALLER_LAUNCHER_GUI_VERSION" FontSize="12" Foreground="{DynamicResource TextSecBrush}"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button Name="MinBtn" Content="—" Width="44" Height="32" BorderThickness="0" Background="Transparent"/>
          <Button Name="MaxBtn" Content="□" Width="44" Height="32" BorderThickness="0" Background="Transparent"/>
          <Button Name="CloseBtn" Content="×" Width="44" Height="32" BorderThickness="0" Background="Transparent"/>
        </StackPanel>
      </Grid>
      <Grid Grid.Row="1" Margin="18">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="150"/></Grid.RowDefinitions>
        <Border Grid.Row="0" Background="{DynamicResource PanelBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,0,0,12">
          <Grid>
            <TextBlock Name="ProjectStatusText" TextWrapping="Wrap"/>
            <TextBlock Name="BusyText" HorizontalAlignment="Right" Foreground="{DynamicResource TextSecBrush}"/>
          </Grid>
        </Border>
        <Grid Grid.Row="1">
          <Grid.ColumnDefinitions><ColumnDefinition Width="280"/><ColumnDefinition Width="*"/><ColumnDefinition Width="320"/></Grid.ColumnDefinitions>
          <Border Grid.Column="0" Background="{DynamicResource PanelBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,0,12,0">
            <DockPanel>
              <TextBlock DockPanel.Dock="Top" Text="项目" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10"/>
              <ListBox Name="ProjectList" DisplayMemberPath="Name"/>
            </DockPanel>
          </Border>
          <Border Grid.Column="1" Background="{DynamicResource PanelBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,0,12,0">
            <DockPanel>
              <StackPanel DockPanel.Dock="Top">
                <TextBlock Text="安装器配置" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                  <Button Name="SaveConfigBtn" Content="保存配置" Style="{StaticResource PrimaryButton}"/>
                  <Button Name="RunInstallerBtn" Content="运行安装器" Style="{StaticResource PrimaryButton}"/>
                  <Button Name="RefreshStatusBtn" Content="刷新状态"/>
                </StackPanel>
              </StackPanel>
              <ScrollViewer VerticalScrollBarVisibility="Auto">
                <StackPanel Name="ConfigPanel"/>
              </ScrollViewer>
            </DockPanel>
          </Border>
          <Border Grid.Column="2" Background="{DynamicResource PanelBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="8" Padding="12">
            <StackPanel>
              <TextBlock Text="管理脚本" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10"/>
              <ComboBox Name="ScriptCombo" Margin="0,0,0,8"/>
              <TextBox Name="ScriptArgsBox" Height="60" AcceptsReturn="True" TextWrapping="Wrap" Margin="0,0,0,10" ToolTip="保存给当前管理脚本的默认参数"/>
              <StackPanel Orientation="Horizontal" Margin="0,0,0,14">
                <Button Name="SaveScriptArgsBtn" Content="保存脚本参数"/>
                <Button Name="RunScriptBtn" Content="运行脚本" Style="{StaticResource PrimaryButton}"/>
              </StackPanel>
              <TextBlock Text="启动器设置" FontSize="16" FontWeight="SemiBold" Margin="0,6,0,10"/>
              <CheckBox Name="AutoUpdateCheck" Content="启动时自动检查更新" Margin="0,0,0,8"/>
              <CheckBox Name="WelcomeCheck" Content="启动时显示欢迎提示" Margin="0,0,0,8"/>
              <TextBlock Text="日志等级" Margin="0,0,0,4"/>
              <ComboBox Name="LogLevelCombo" Margin="0,0,0,8"/>
              <TextBlock Text="代理模式" Margin="0,0,0,4"/>
              <ComboBox Name="ProxyModeCombo" Margin="0,0,0,8"/>
              <TextBlock Text="手动代理地址" Margin="0,0,0,4"/>
              <TextBox Name="ManualProxyBox" Margin="0,0,0,10"/>
              <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                <Button Name="SaveMainBtn" Content="保存设置" Style="{StaticResource PrimaryButton}"/>
                <Button Name="CheckUpdateBtn" Content="检查更新"/>
              </StackPanel>
              <StackPanel Orientation="Horizontal">
                <Button Name="UninstallBtn" Content="卸载已安装软件"/>
                <Button Name="HelpBtn" Content="帮助"/>
                <Button Name="ShowLogBtn" Content="日志"/>
              </StackPanel>
            </StackPanel>
          </Border>
        </Grid>
        <Border Grid.Row="2" Background="{DynamicResource PanelBGBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="8" Padding="8" Margin="0,12,0,0">
          <TextBox Name="LogBox" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="Transparent" BorderThickness="0" FontFamily="Consolas"/>
        </Border>
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
        MainBorder = $window.FindName("MainBorder"); ProjectList = $window.FindName("ProjectList"); ProjectStatusText = $window.FindName("ProjectStatusText"); BusyText = $window.FindName("BusyText")
        ConfigPanel = $window.FindName("ConfigPanel"); SaveConfigBtn = $window.FindName("SaveConfigBtn"); RunInstallerBtn = $window.FindName("RunInstallerBtn"); RefreshStatusBtn = $window.FindName("RefreshStatusBtn")
        ScriptCombo = $window.FindName("ScriptCombo"); ScriptArgsBox = $window.FindName("ScriptArgsBox"); SaveScriptArgsBtn = $window.FindName("SaveScriptArgsBtn"); RunScriptBtn = $window.FindName("RunScriptBtn")
        AutoUpdateCheck = $window.FindName("AutoUpdateCheck"); WelcomeCheck = $window.FindName("WelcomeCheck"); LogLevelCombo = $window.FindName("LogLevelCombo"); ProxyModeCombo = $window.FindName("ProxyModeCombo"); ManualProxyBox = $window.FindName("ManualProxyBox")
        SaveMainBtn = $window.FindName("SaveMainBtn"); CheckUpdateBtn = $window.FindName("CheckUpdateBtn"); UninstallBtn = $window.FindName("UninstallBtn"); HelpBtn = $window.FindName("HelpBtn"); ShowLogBtn = $window.FindName("ShowLogBtn")
        LogBox = $window.FindName("LogBox")
    }
    $State = [PSCustomObject]@{ CurrentOperation = $null; ConfigControls = @{}; ProjectConfig = @{} }
    $mainConfig = $script:MainConfig

    $UI.LogLevelCombo.ItemsSource = @("DEBUG", "INFO", "WARN", "ERROR")
    $UI.ProxyModeCombo.ItemsSource = @("auto", "manual", "off")
    Refresh-MainConfigUi $UI
    $projectItems = @()
    foreach ($key in $script:Projects.Keys) { $projectItems += [PSCustomObject]@{ Key = $key; Name = $script:Projects[$key].Name } }
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
            $currentProject = $mainConfig["CURRENT_PROJECT"]
            Append-UiLog $UI "当前项目已切换: $currentProject"
        } catch {
            Report-UiError -Context "切换项目" -ErrorObject $_ -ShowDialog $true
        }
    }.GetNewClosure())
    $UI.SaveConfigBtn.Add_Click({
        $key = Get-CurrentProjectKey
        if ([string]::IsNullOrWhiteSpace($key)) { Show-Message "请先选择项目。" "未选择项目" "Warning"; return }
        Save-ProjectConfig $key (Collect-ProjectConfigFromUi $State)
        Refresh-Status $UI $State
        Append-UiLog $UI "项目配置已保存: $key"
    }.GetNewClosure())
    $UI.RunInstallerBtn.Add_Click({ Invoke-RunInstaller $UI $State }.GetNewClosure())
    $UI.RefreshStatusBtn.Add_Click({ Refresh-Status $UI $State }.GetNewClosure())
    $UI.ScriptCombo.Add_SelectionChanged({
        $key = Get-CurrentProjectKey
        if ([string]::IsNullOrWhiteSpace($key) -or $null -eq $UI.ScriptCombo.SelectedItem) { return }
        $config = Get-ProjectConfig $key
        $scriptName = $UI.ScriptCombo.SelectedItem.Name
        if ($null -ne $config["ScriptArgs"] -and (Test-DictionaryKey $config["ScriptArgs"] $scriptName)) {
            $UI.ScriptArgsBox.Text = [string]$config["ScriptArgs"][$scriptName]
        } else {
            $UI.ScriptArgsBox.Text = ""
        }
    }.GetNewClosure())
    $UI.SaveScriptArgsBtn.Add_Click({
        $key = Get-CurrentProjectKey
        if ([string]::IsNullOrWhiteSpace($key) -or $null -eq $UI.ScriptCombo.SelectedItem) { return }
        $config = Get-ProjectConfig $key
        if ($null -eq $config["ScriptArgs"]) { $config["ScriptArgs"] = @{} }
        $config["ScriptArgs"][$UI.ScriptCombo.SelectedItem.Name] = $UI.ScriptArgsBox.Text
        Save-ProjectConfig $key $config
        Append-UiLog $UI "管理脚本参数已保存: $($UI.ScriptCombo.SelectedItem.Name)"
    }.GetNewClosure())
    $UI.RunScriptBtn.Add_Click({ Invoke-RunManagementScript $UI $State }.GetNewClosure())
    $UI.SaveMainBtn.Add_Click({
        Save-MainConfigFromUi $UI
        Refresh-Status $UI $State
        Append-UiLog $UI "启动器设置已保存。"
    }.GetNewClosure())
    $UI.CheckUpdateBtn.Add_Click({ Invoke-UpdateCheck $UI $State $true }.GetNewClosure())
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
                [LauncherWindowHelper]::SetDarkMode($handle, [bool]$colors.IsDark)
                [LauncherWindowHelper]::SetRounding($handle, $true)
            } catch {
                Write-Log WARN "window decoration setup failed: $($_.Exception.Message)"
            }
            Refresh-ProjectConfigUi $UI $State
            Refresh-Status $UI $State
            Append-UiLog $UI "GUI 启动完成。配置: $displayConfigHome 日志: $displayLogFile"
            if ([bool]$mainConfig["SHOW_WELCOME_SCREEN"]) {
                Append-UiLog $UI "选择项目，调整配置，然后运行安装器。"
            }

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
