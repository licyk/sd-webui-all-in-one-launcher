# Core constants, helpers, logging.

$script:INSTALLER_LAUNCHER_GUI_VERSION = "0.2.0"
$script:APP_NAME = "installer-launcher"
$script:APP_TITLE = "SD WebUI All In One Installer Launcher GUI"
$script:SELF_REMOTE_URLS = @(
    "https://github.com/licyk/sd-webui-all-in-one-launcher/releases/download/launcher/installer_launcher_gui.ps1",
    "https://gitee.com/licyk/sd-webui-all-in-one-launcher/releases/download/launcher/installer_launcher_gui.ps1"
)
$script:HERO_IMAGE_URLS = @(
    "https://raw.githubusercontent.com/licyk/sd-webui-all-in-one/main/.github/head_image.jpg",
    "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/.github/head_image.jpg"
)
$script:SHORTCUT_ICON_URLS = @(
    "https://modelscope.cn/models/licyks/sd-webui-all-in-one/resolve/master/icon/sd_webui_all_in_one_launcher.ico",
    "https://huggingface.co/licyk/sd-webui-all-in-one/resolve/main/icon/sd_webui_all_in_one_launcher.ico"
)
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

    public static void SetBlurState(IntPtr hwnd, int state, int flags, int gradientColor) {
        var accent = new AccentPolicy();
        accent.AccentState = state;
        accent.AccentFlags = flags;
        accent.GradientColor = gradientColor;

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
        SetBlurState(hwnd, 3, 0, 0);
    }

    public static void EnableAcrylic(IntPtr hwnd, bool dark) {
        int gradientColor = dark ? unchecked((int)0x2E080808) : unchecked((int)0x28FFFFFF);
        SetBlurState(hwnd, 4, 2, gradientColor);
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
$script:HeroImageFile = Join-Path $script:ConfigHome "head_image.jpg"
$script:ShortcutIconFile = Join-Path $script:ConfigHome "sd_webui_all_in_one_launcher.ico"
$script:LogFile = Join-Path $script:LogHome ("installer-launcher-gui-{0}.log" -f (Get-Date -Format "yyyyMMdd"))
$script:UninstallRegistryKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SDWebUIAllInOneLauncherGUI"
$script:AutoUpdateIntervalSeconds = 3600
$script:RunspacePool = $null
$script:MainConfig = $null
$script:InstallerLauncherGuiUi = $null
$script:InstallerLauncherGuiState = $null
if ($null -eq (Get-Variable -Name InstallerLauncherGuiUpdateCheckSemaphore -Scope Global -ErrorAction SilentlyContinue)) {
    $global:InstallerLauncherGuiUpdateCheckSemaphore = [System.Threading.SemaphoreSlim]::new(1, 1)
}

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

function Get-ObjectPropertyValue {
    param($InputObject, [string]$Name, $Default = $null)
    if ($null -eq $InputObject -or [string]::IsNullOrWhiteSpace($Name)) { return $Default }
    if ($null -eq $InputObject.PSObject.Properties[$Name]) { return $Default }
    return $InputObject.PSObject.Properties[$Name].Value
}

function Ensure-GuiState {
    param($State)
    if ($null -eq $State) {
        return [PSCustomObject]@{ CurrentOperation = $null; ConfigControls = @{}; ScriptParamControls = @{}; ProjectConfig = @{}; DiscoveredInstalls = @(); StatusRefreshTimer = $null; LastOneClickStatus = ""; IsRefreshing = $false; AutoSaveProjectConfig = $null; IsAutoSavingMainConfig = $false }
    }
    $defaults = [ordered]@{
        CurrentOperation = $null
        ConfigControls = @{}
        ScriptParamControls = @{}
        ProjectConfig = @{}
        DiscoveredInstalls = @()
        StatusRefreshTimer = $null
        LastOneClickStatus = ""
        IsRefreshing = $false
        AutoSaveProjectConfig = $null
        IsAutoSavingMainConfig = $false
    }
    foreach ($name in $defaults.Keys) {
        if ($null -eq $State.PSObject.Properties[$name]) {
            $State | Add-Member -MemberType NoteProperty -Name $name -Value $defaults[$name] -Force
        }
    }
    return $State
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
