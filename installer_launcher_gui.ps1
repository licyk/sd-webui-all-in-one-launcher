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

param(
    [switch]$UninstallLauncher
)

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    Write-Error "installer_launcher_gui.ps1 only supports Windows."
    exit 1
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:EntryScriptPath = $PSCommandPath
$script:RepoRoot = $PSScriptRoot
$bootstrapPath = Join-Path (Join-Path $PSScriptRoot "gui") "bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrapPath -PathType Leaf)) {
    throw "GUI bootstrap 文件不存在: $bootstrapPath"
}
. $bootstrapPath

try {
    if ($UninstallLauncher) {
        Initialize-Directories
        $script:MainConfig = Read-JsonConfig -Path $script:MainConfigFile -Default (Get-DefaultMainConfig)
        $script:MainConfig["LOG_LEVEL"] = Normalize-LogLevel $script:MainConfig["LOG_LEVEL"]
        $script:MainConfig["PROXY_MODE"] = Normalize-ProxyMode $script:MainConfig["PROXY_MODE"]
        if ($null -eq $script:MainConfig["MANUAL_PROXY"]) { $script:MainConfig["MANUAL_PROXY"] = "" }
        Write-Log INFO "launcher uninstall mode starting version=$script:INSTALLER_LAUNCHER_GUI_VERSION"
        Invoke-UninstallLauncher
    } else {
        Start-App
    }
} catch {
    try { Write-Log ERROR "fatal gui error: $($_.Exception.Message)" } catch {}
    [System.Windows.MessageBox]::Show("启动器异常退出:`n$($_.Exception.Message)`n`n日志: $($script:LogFile)", "启动器错误", "OK", "Error") | Out-Null
    throw
}
