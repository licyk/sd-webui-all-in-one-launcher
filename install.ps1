<#
.SYNOPSIS
    Install the Windows GUI launcher for the current user.

.DESCRIPTION
    Copies or downloads installer_launcher_gui.ps1 into
    %APPDATA%\installer-launcher, downloads the launcher icon, creates desktop
    and Start Menu shortcuts, and registers a current-user uninstall entry.
#>

[CmdletBinding()]
param(
    [switch]$SkipDesktopShortcut,
    [switch]$SkipStartMenuShortcut,
    [switch]$NoGui
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$AppName = "installer-launcher"
$DisplayName = "SD WebUI All In One Launcher"
$GuiScriptName = "installer_launcher_gui.ps1"
$InstallDir = Join-Path $env:APPDATA $AppName
$InstalledGuiPath = Join-Path $InstallDir $GuiScriptName
$IconPath = Join-Path $InstallDir "sd_webui_all_in_one_launcher.ico"
$UninstallRegistryKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SDWebUIAllInOneLauncherGUI"
$GuiScriptUrls = @(
    "https://raw.githubusercontent.com/licyk/sd-webui-all-in-one-launcher/main/installer_launcher_gui.ps1",
    "https://github.com/licyk/sd-webui-all-in-one-launcher/raw/main/installer_launcher_gui.ps1",
    "https://gitee.com/licyk/sd-webui-all-in-one-launcher/raw/main/installer_launcher_gui.ps1",
    "https://raw.githubusercontent.com/licyk/sd-webui-all-in-one-launcher/master/installer_launcher_gui.ps1",
    "https://github.com/licyk/sd-webui-all-in-one-launcher/raw/master/installer_launcher_gui.ps1",
    "https://gitee.com/licyk/sd-webui-all-in-one-launcher/raw/master/installer_launcher_gui.ps1"
)
$IconUrls = @(
    "https://modelscope.cn/models/licyks/sd-webui-all-in-one/resolve/master/icon/sd_webui_all_in_one_launcher.ico",
    "https://huggingface.co/licyk/sd-webui-all-in-one/resolve/main/icon/sd_webui_all_in_one_launcher.ico"
)
$script:InstallLogBox = $null
$script:InstallStatusLabel = $null
$script:InstallProgressBar = $null

function Write-Step {
    param([string]$Message)
    $line = "[installer-launcher] $Message"
    Write-Host $line
    if ($null -ne $script:InstallLogBox) {
        $script:InstallLogBox.AppendText($line + [Environment]::NewLine)
        $script:InstallLogBox.SelectionStart = $script:InstallLogBox.TextLength
        $script:InstallLogBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
    if ($null -ne $script:InstallStatusLabel) {
        $script:InstallStatusLabel.Text = $Message
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Assert-Windows {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        throw "install.ps1 only supports Windows."
    }
}

function Get-CurrentPowerShellPath {
    $process = Get-Process -Id $PID -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($process.Path)) {
        throw "无法确定当前 PowerShell 可执行文件路径。"
    }
    return $process.Path
}

function Invoke-DownloadFirst {
    param(
        [Parameter(Mandatory)][string[]]$Urls,
        [Parameter(Mandatory)][string]$OutputPath,
        [scriptblock]$Validate
    )
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
    $lastError = ""
    foreach ($url in $Urls) {
        $temp = "$OutputPath.tmp"
        try {
            Write-Step "尝试下载: $url"
            Invoke-WebRequest -UseBasicParsing -Uri $url -Headers @{ "User-Agent" = "installer-launcher-gui-installer" } -OutFile $temp -TimeoutSec 45 -ErrorAction Stop
            if ($null -ne $Validate -and -not (& $Validate $temp)) {
                throw "下载文件校验失败"
            }
            Move-Item -LiteralPath $temp -Destination $OutputPath -Force
            return $url
        } catch {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
            $lastError = $_.Exception.Message
            Write-Step "下载失败: $lastError"
        }
    }
    throw "所有下载源都失败。最后错误: $lastError"
}

function Test-PowerShellScriptFile {
    param([string]$Path)
    try {
        $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        [void][scriptblock]::Create($content)
        return $true
    } catch {
        return $false
    }
}

function Test-IconFile {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $icon = New-Object System.Drawing.Icon -ArgumentList $stream
            $icon.Dispose()
            return $true
        } finally {
            $stream.Dispose()
        }
    } catch {
        return $false
    }
}

function Install-GuiScript {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $localGuiPath = Join-Path $PSScriptRoot $GuiScriptName
    if (Test-Path -LiteralPath $localGuiPath -PathType Leaf) {
        Write-Step "复制 GUI 脚本到: $InstalledGuiPath"
        Copy-Item -LiteralPath $localGuiPath -Destination $InstalledGuiPath -Force
        if (-not (Test-PowerShellScriptFile $InstalledGuiPath)) {
            throw "复制后的 GUI 脚本无法通过 PowerShell 语法解析。"
        }
        return
    }

    Write-Step "本地未找到 $GuiScriptName，改为联网下载。"
    $source = Invoke-DownloadFirst -Urls $GuiScriptUrls -OutputPath $InstalledGuiPath -Validate ${function:Test-PowerShellScriptFile}
    Write-Step "GUI 脚本下载完成: $source"
}

function Install-Icon {
    if (Test-IconFile $IconPath) {
        Write-Step "使用已存在的图标: $IconPath"
        return
    }
    $source = Invoke-DownloadFirst -Urls $IconUrls -OutputPath $IconPath -Validate ${function:Test-IconFile}
    Write-Step "图标下载完成: $source"
}

function New-LauncherShortcut {
    param(
        [Parameter(Mandatory)][string]$ShortcutPath,
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$IconPath
    )
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ShortcutPath) | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $shortcut.WorkingDirectory = Split-Path -Parent $ScriptPath
    if (Test-IconFile $IconPath) {
        $shortcut.IconLocation = $IconPath
    }
    $shortcut.Save()
}

function Install-Shortcuts {
    param([string]$PowerShellPath)
    $shortcutName = "$DisplayName.lnk"
    if (-not $SkipDesktopShortcut) {
        $desktopShortcut = Join-Path ([System.Environment]::GetFolderPath("Desktop")) $shortcutName
        New-LauncherShortcut -ShortcutPath $desktopShortcut -TargetPath $PowerShellPath -ScriptPath $InstalledGuiPath -IconPath $IconPath
        Write-Step "桌面快捷方式已创建: $desktopShortcut"
    }
    if (-not $SkipStartMenuShortcut) {
        $programs = Join-Path ([System.Environment]::GetFolderPath("ApplicationData")) "Microsoft\Windows\Start Menu\Programs"
        $startMenuShortcut = Join-Path $programs $shortcutName
        New-LauncherShortcut -ShortcutPath $startMenuShortcut -TargetPath $PowerShellPath -ScriptPath $InstalledGuiPath -IconPath $IconPath
        Write-Step "开始菜单快捷方式已创建: $startMenuShortcut"
    }
}

function Get-InstalledGuiVersion {
    try {
        $content = Get-Content -LiteralPath $InstalledGuiPath -Raw -Encoding UTF8
        $match = [regex]::Match($content, '\$script:INSTALLER_LAUNCHER_GUI_VERSION\s*=\s*"([^"]+)"')
        if ($match.Success) { return $match.Groups[1].Value }
    } catch {}
    return "0.0.0"
}

function Register-UninstallEntry {
    param([string]$PowerShellPath)
    $uninstallCommand = '"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" -UninstallLauncher' -f $PowerShellPath, $InstalledGuiPath
    $version = Get-InstalledGuiVersion
    New-Item -Path $UninstallRegistryKey -Force | Out-Null
    New-ItemProperty -Path $UninstallRegistryKey -Name "DisplayName" -Value $DisplayName -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallRegistryKey -Name "DisplayVersion" -Value $version -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallRegistryKey -Name "Publisher" -Value "licyk" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallRegistryKey -Name "InstallLocation" -Value $InstallDir -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallRegistryKey -Name "DisplayIcon" -Value $IconPath -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallRegistryKey -Name "UninstallString" -Value $uninstallCommand -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallRegistryKey -Name "NoModify" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $UninstallRegistryKey -Name "NoRepair" -Value 1 -PropertyType DWord -Force | Out-Null
    Write-Step "卸载信息已注册: $UninstallRegistryKey"
}

function Invoke-InstallMain {
    Assert-Windows
    $powerShellPath = Get-CurrentPowerShellPath
    Write-Step "安装目录: $InstallDir"
    Install-GuiScript
    Install-Icon
    Install-Shortcuts -PowerShellPath $powerShellPath
    Register-UninstallEntry -PowerShellPath $powerShellPath
    Write-Step "安装完成。"
    Write-Step "启动脚本: $InstalledGuiPath"
}

function Show-InstallWindow {
    Assert-Windows
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "$DisplayName 安装器"
    $form.StartPosition = "CenterScreen"
    $form.Size = New-Object System.Drawing.Size(720, 520)
    $form.MinimumSize = New-Object System.Drawing.Size(640, 440)
    $form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
    $form.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "安装 SD WebUI All In One Launcher GUI"
    $title.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 16, [System.Drawing.FontStyle]::Bold)
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(22, 20)
    $form.Controls.Add($title)

    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Text = "将 GUI 脚本安装到当前用户配置目录，创建快捷方式并注册卸载信息。"
    $subtitle.ForeColor = [System.Drawing.Color]::FromArgb(89, 99, 109)
    $subtitle.AutoSize = $true
    $subtitle.Location = New-Object System.Drawing.Point(24, 58)
    $form.Controls.Add($subtitle)

    $pathLabel = New-Object System.Windows.Forms.Label
    $pathLabel.Text = "安装目录: $InstallDir"
    $pathLabel.AutoEllipsis = $true
    $pathLabel.Location = New-Object System.Drawing.Point(24, 88)
    $pathLabel.Size = New-Object System.Drawing.Size(655, 24)
    $form.Controls.Add($pathLabel)

    $script:InstallStatusLabel = New-Object System.Windows.Forms.Label
    $script:InstallStatusLabel.Text = "准备安装..."
    $script:InstallStatusLabel.AutoEllipsis = $true
    $script:InstallStatusLabel.Location = New-Object System.Drawing.Point(24, 122)
    $script:InstallStatusLabel.Size = New-Object System.Drawing.Size(655, 24)
    $form.Controls.Add($script:InstallStatusLabel)

    $script:InstallProgressBar = New-Object System.Windows.Forms.ProgressBar
    $script:InstallProgressBar.Style = "Marquee"
    $script:InstallProgressBar.MarqueeAnimationSpeed = 25
    $script:InstallProgressBar.Location = New-Object System.Drawing.Point(24, 152)
    $script:InstallProgressBar.Size = New-Object System.Drawing.Size(655, 18)
    $form.Controls.Add($script:InstallProgressBar)

    $script:InstallLogBox = New-Object System.Windows.Forms.TextBox
    $script:InstallLogBox.Multiline = $true
    $script:InstallLogBox.ReadOnly = $true
    $script:InstallLogBox.ScrollBars = "Vertical"
    $script:InstallLogBox.WordWrap = $true
    $script:InstallLogBox.BackColor = [System.Drawing.Color]::White
    $script:InstallLogBox.BorderStyle = "FixedSingle"
    $script:InstallLogBox.Location = New-Object System.Drawing.Point(24, 188)
    $script:InstallLogBox.Size = New-Object System.Drawing.Size(655, 220)
    $form.Controls.Add($script:InstallLogBox)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = "关闭"
    $closeButton.Enabled = $false
    $closeButton.Size = New-Object System.Drawing.Size(96, 34)
    $closeButton.Location = New-Object System.Drawing.Point(583, 426)
    $closeButton.Add_Click({ $form.Close() })
    $form.Controls.Add($closeButton)

    $openButton = New-Object System.Windows.Forms.Button
    $openButton.Text = "启动"
    $openButton.Enabled = $false
    $openButton.Size = New-Object System.Drawing.Size(96, 34)
    $openButton.Location = New-Object System.Drawing.Point(475, 426)
    $openButton.Add_Click({
        try {
            $powerShellPath = Get-CurrentPowerShellPath
            Start-Process -FilePath $powerShellPath -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $InstalledGuiPath) | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("启动失败: $($_.Exception.Message)", "启动器安装", "OK", "Error") | Out-Null
        }
    })
    $form.Controls.Add($openButton)

    $form.Add_Shown({
        try {
            Invoke-InstallMain
            $script:InstallStatusLabel.Text = "安装完成。"
            $script:InstallProgressBar.Style = "Blocks"
            $script:InstallProgressBar.Value = 100
            $openButton.Enabled = $true
            [System.Windows.Forms.MessageBox]::Show("安装完成。可以从桌面或开始菜单启动，也可以点击「启动」。", "启动器安装", "OK", "Information") | Out-Null
        } catch {
            $message = $_.Exception.Message
            Write-Step "安装失败: $message"
            $script:InstallStatusLabel.Text = "安装失败。"
            $script:InstallProgressBar.Style = "Blocks"
            $script:InstallProgressBar.Value = 0
            [System.Windows.Forms.MessageBox]::Show("安装失败:`n$message", "启动器安装", "OK", "Error") | Out-Null
        } finally {
            $script:InstallProgressBar.MarqueeAnimationSpeed = 0
            $closeButton.Enabled = $true
        }
    })

    [void]$form.ShowDialog()
}

if ($NoGui) {
    Invoke-InstallMain
} else {
    Show-InstallWindow
}
