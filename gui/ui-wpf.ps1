# WPF helpers, resources, navigation, imagery.

function Get-GuiXamlPath {
    param([Parameter(Mandatory)][string]$Name)
    Join-Path $script:GuiXamlHome $Name
}

function Load-GuiXamlWindow {
    param([Parameter(Mandatory)][string]$Name)
    $bundled = Get-Variable -Name BundledXamlResources -Scope Script -ErrorAction SilentlyContinue
    if ($null -ne $bundled -and $null -ne $bundled.Value -and (Test-DictionaryKey $bundled.Value $Name)) {
        $encoded = [string]$bundled.Value[$Name]
        if ([string]::IsNullOrWhiteSpace($encoded)) {
            throw "GUI 内嵌 XAML 为空: $Name"
        }
        $bytes = [Convert]::FromBase64String(($encoded -replace '\s', ''))
        $xamlText = [System.Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
        [xml]$xaml = $xamlText
        $reader = New-Object System.Xml.XmlNodeReader $xaml
        return [Windows.Markup.XamlReader]::Load($reader)
    }

    $path = Get-GuiXamlPath $Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "GUI XAML 文件不存在: $path"
    }
    [xml]$xaml = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    [Windows.Markup.XamlReader]::Load($reader)
}

function Set-GuiBrushResource {
    param($Window, [string]$Name, [string]$Color)
    if ($null -eq $Window -or [string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Color)) { return }
    $converter = New-Object System.Windows.Media.BrushConverter
    $brush = $converter.ConvertFromString($Color)
    if ($Window.Resources.Contains($Name)) {
        $Window.Resources[$Name] = $brush
    } else {
        $Window.Resources.Add($Name, $brush)
    }
}

function Set-ThemeResources {
    param($Window, [hashtable]$Colors)
    if ($null -eq $Window -or $null -eq $Colors) { return }
    Set-GuiBrushResource $Window "TextMainBrush" $Colors.TextMain
    Set-GuiBrushResource $Window "TextSecBrush" $Colors.TextSec
    Set-GuiBrushResource $Window "BorderBrush" $Colors.Border
    Set-GuiBrushResource $Window "InputBGBrush" $Colors.InputBG
    Set-GuiBrushResource $Window "DropDownBGBrush" $Colors.DropDownBG
    Set-GuiBrushResource $Window "BtnNormalBrush" $Colors.BtnNormal
    Set-GuiBrushResource $Window "BtnHoverBrush" $Colors.BtnHover
    Set-GuiBrushResource $Window "ItemHoverBrush" $Colors.ItemHover
    Set-GuiBrushResource $Window "HeaderBGBrush" $Colors.HeaderBG
    Set-GuiBrushResource $Window "PanelBGBrush" $Colors.PanelBG
    $mainBorder = $Window.FindName("MainBorder")
    if ($null -ne $mainBorder) {
        $gradient = New-Object System.Windows.Media.LinearGradientBrush
        $gradient.StartPoint = New-Object System.Windows.Point -ArgumentList 0, 0
        $gradient.EndPoint = New-Object System.Windows.Point -ArgumentList 1, 1
        $startStop = New-Object System.Windows.Media.GradientStop
        $startStop.Color = [System.Windows.Media.ColorConverter]::ConvertFromString($Colors.WinBG1)
        $startStop.Offset = 0
        $endStop = New-Object System.Windows.Media.GradientStop
        $endStop.Color = [System.Windows.Media.ColorConverter]::ConvertFromString($Colors.WinBG2)
        $endStop.Offset = 1
        [void]$gradient.GradientStops.Add($startStop)
        [void]$gradient.GradientStops.Add($endStop)
        $mainBorder.Background = $gradient
    }
}

function Export-GuiEventFunctions {
    $names = @(
        "Append-UiLog", "Get-GuiXamlPath", "Load-GuiXamlWindow", "Set-ThemeResources", "Apply-DiscoveredInstallTarget", "Apply-HeroImage", "AutoSave-MainConfigFromUi", "Ensure-GuiState", "Get-CurrentProjectKey", "Get-DefaultInstallDiscoveryRoots", "Get-EffectiveInstallPath", "Get-InstallDiscoveryFeatureRows", "Get-ObjectPropertyValue", "Get-ProjectConfig",
        "Get-SelectedScriptName", "Get-UiControl", "Get-UpdateCheckSemaphore", "Invoke-CreateLauncherShortcut", "Invoke-DiscoverInstalledWebUis", "Invoke-DiscoverInstalledWebUisInFolder", "Invoke-OneClickAction", "Invoke-TerminateCurrentOperation", "Invoke-UninstallLauncher",
        "Invoke-UninstallProject", "Invoke-UpdateCheck", "Open-CacheFolder", "Open-ConfigFolder", "Open-ExternalUrl", "Open-LogFolder", "Refresh-MainConfigUi",
        "Refresh-DiscoveredInstallList", "Refresh-ProjectConfigUi", "Refresh-ScriptParamUi", "Refresh-Status", "Release-UpdateCheckLock", "Report-UiError",
        "Save-CurrentProjectConfigFromUi", "Save-MainConfig", "Save-MainConfigFromUi", "Save-ProjectConfig",
        "Select-FolderPath", "Select-RelevantMainTab", "Set-UiBusy", "Show-AppPage",
        "Show-CountdownConfirmDialog", "Show-HelpWindow", "Show-LogWindow", "Show-Message", "Show-UserAgreementDialog", "Start-HeroImageDownload", "Start-LauncherIconDownload", "Start-TabTransition",
        "Test-DictionaryKey", "Toggle-CustomMaximizeWindow", "Update-OneClickModeUi", "Write-Log"
    )
    foreach ($name in $names) {
        $command = Get-Command -Name $name -CommandType Function -ErrorAction Stop
        Set-Item -Path "Function:\Global:$name" -Value $command.ScriptBlock -Force
    }
}

function Get-ThemeColors {
    $dark = $false
    try {
        $reg = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
        if ($null -ne $reg -and $reg.AppsUseLightTheme -eq 0) { $dark = $true }
    } catch {}
    if ($dark) {
        return @{
            IsDark = $true; WinBG1 = "#A81E1E1E"; WinBG2 = "#94121212"; PanelBG = "#461F1F1F"; TextMain = "#FFFFFF"; TextSec = "#B8BFC7"; Border = "#58FFFFFF"; InputBG = "#662B2B2B"; DropDownBG = "#FF242424"; BtnNormal = "#553A3A3A"; BtnHover = "#744A4A4A"; ItemHover = "#2EFFFFFF"; HeaderBG = "#18FFFFFF"
        }
    }
    return @{
        IsDark = $false; WinBG1 = "#B8F9FAFC"; WinBG2 = "#A6F3F7FB"; PanelBG = "#A8FFFFFF"; TextMain = "#242424"; TextSec = "#5A636D"; Border = "#C8D7DCE2"; InputBG = "#B8FCFCFD"; DropDownBG = "#FFFCFCFD"; BtnNormal = "#A8FFFFFF"; BtnHover = "#C8F3F8FF"; ItemHover = "#C8EAF4FF"; HeaderBG = "#8CF5F9FF"
    }
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
    param($UI, [bool]$Busy, [string]$Message, [bool]$CanTerminate = $true)
    $enabled = -not $Busy
    foreach ($name in @("UninstallBtn", "CheckUpdateBtn", "UnifiedStartBtn", "OpenConfigFolderBtn", "OpenLogFolderBtn", "OpenCacheFolderBtn", "ShowLogBtn", "CreateShortcutBtn", "UninstallLauncherBtn", "DiscoverInstallsBtn", "DiscoverFolderInstallsBtn")) {
        $button = Get-UiControl $UI $name
        if ($null -ne $button) { $button.IsEnabled = $enabled }
    }
    $terminateButton = Get-UiControl $UI "TerminateOperationBtn"
    if ($null -ne $terminateButton) {
        $terminateButton.Visibility = $(if ($Busy -and $CanTerminate) { "Visible" } else { "Collapsed" })
        $terminateButton.IsEnabled = $Busy -and $CanTerminate -and ($Message -notmatch "正在终止")
    }
    $progressBar = Get-UiControl $UI "StartProgressBar"
    if ($null -ne $progressBar) {
        $progressBar.Visibility = $(if ($Busy -and $CanTerminate) { "Visible" } else { "Collapsed" })
    }
    $busyText = Get-UiControl $UI "BusyText"
    if ($null -ne $busyText) { $busyText.Text = $Message }
}

function Get-UiControl {
    param($UI, [string]$Name)
    if ($null -eq $UI -or [string]::IsNullOrWhiteSpace($Name)) { return $null }
    if ($null -eq $UI.PSObject.Properties[$Name]) { return $null }
    return $UI.PSObject.Properties[$Name].Value
}

function Select-FolderPath {
    param([string]$InitialPath, [string]$Description = "选择安装路径")
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Description
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
        @{ Name = "start"; Button = $UI.OneClickNavBtn; Label = $UI.OneClickNavLabel; Icon = $UI.OneClickNavIcon },
        @{ Name = "advanced"; Button = $UI.AdvancedNavBtn; Label = $UI.AdvancedNavLabel; Icon = $UI.AdvancedNavIcon },
        @{ Name = "software"; Button = $UI.SoftwareNavBtn; Label = $UI.SoftwareNavLabel; Icon = $UI.SoftwareNavIcon },
        @{ Name = "settings"; Button = $UI.SettingsNavBtn; Label = $UI.SettingsNavLabel; Icon = $UI.SettingsNavIcon },
        @{ Name = "about"; Button = $UI.AboutNavBtn; Label = $UI.AboutNavLabel; Icon = $UI.AboutNavIcon }
    )) {
        $button = $entry["Button"]
        $label = $entry["Label"]
        $icon = $entry["Icon"]
        if ($null -eq $button) { continue }
        if ($entry["Name"] -eq $PageName) {
            $button.Background = $UI.Window.Resources["HeaderBGBrush"]
            $button.BorderBrush = $UI.Window.Resources["PrimaryBrush"]
            $button.FontWeight = "SemiBold"
            if ($null -ne $label) { $label.Visibility = "Collapsed" }
            if ($null -ne $icon) { $icon.Foreground = $UI.Window.Resources["PrimaryBrush"] }
        } else {
            $button.Background = [System.Windows.Media.Brushes]::Transparent
            $button.BorderBrush = [System.Windows.Media.Brushes]::Transparent
            $button.FontWeight = "Normal"
            if ($null -ne $label) { $label.Visibility = "Visible" }
            if ($null -ne $icon) { $icon.Foreground = $UI.Window.Resources["TextMainBrush"] }
        }
    }
}

function Start-PageTransition {
    param($Page)
    if ($null -eq $Page) { return }
    $duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(180))
    $opacityAnimation = New-Object System.Windows.Media.Animation.DoubleAnimation
    $opacityAnimation.From = 0.0
    $opacityAnimation.To = 1.0
    $opacityAnimation.Duration = $duration
    $opacityAnimation.EasingFunction = New-Object System.Windows.Media.Animation.CubicEase -Property @{ EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut }
    $translate = New-Object System.Windows.Media.TranslateTransform
    $Page.RenderTransform = $translate
    $Page.Opacity = 0.0
    $yAnimation = New-Object System.Windows.Media.Animation.DoubleAnimation
    $yAnimation.From = 14.0
    $yAnimation.To = 0.0
    $yAnimation.Duration = $duration
    $yAnimation.EasingFunction = New-Object System.Windows.Media.Animation.CubicEase -Property @{ EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut }
    $Page.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $opacityAnimation)
    $translate.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $yAnimation)
}

function Start-TabTransition {
    param($TabControl)
    if ($null -eq $TabControl -or $null -eq $TabControl.SelectedContent) { return }
    $content = $TabControl.SelectedContent
    if (-not ($content -is [System.Windows.UIElement])) { return }

    $duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(150))
    $opacityAnimation = New-Object System.Windows.Media.Animation.DoubleAnimation
    $opacityAnimation.From = 0.0
    $opacityAnimation.To = 1.0
    $opacityAnimation.Duration = $duration
    $opacityAnimation.EasingFunction = New-Object System.Windows.Media.Animation.CubicEase -Property @{ EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut }

    $translate = New-Object System.Windows.Media.TranslateTransform
    $content.RenderTransform = $translate
    $content.Opacity = 0.0

    $yAnimation = New-Object System.Windows.Media.Animation.DoubleAnimation
    $yAnimation.From = 8.0
    $yAnimation.To = 0.0
    $yAnimation.Duration = $duration
    $yAnimation.EasingFunction = New-Object System.Windows.Media.Animation.CubicEase -Property @{ EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut }

    $content.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $opacityAnimation)
    $translate.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $yAnimation)
}

function Test-IconFile {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $icon = New-Object System.Drawing.Icon($stream)
            $icon.Dispose()
            return $true
        } finally {
            $stream.Dispose()
        }
    } catch {
        return $false
    }
}

function Apply-LauncherIcon {
    param($UI, [string]$IconPath)
    if (-not (Test-IconFile $IconPath)) { return $false }
    $titleLogoImage = Get-UiControl $UI "TitleLogoImage"
    $titleLogoText = Get-UiControl $UI "TitleLogoText"
    try {
        $iconUri = New-Object System.Uri($IconPath, [System.UriKind]::Absolute)
        $frame = [System.Windows.Media.Imaging.BitmapFrame]::Create($iconUri)
        if ($null -ne $UI -and $null -ne $UI.Window) {
            $UI.Window.Icon = $frame
        }
        if ($null -ne $titleLogoImage) {
            $titleLogoImage.Source = $frame
            $titleLogoImage.Visibility = "Visible"
        }
        if ($null -ne $titleLogoText) { $titleLogoText.Visibility = "Collapsed" }
        Write-Log INFO "launcher icon applied: $IconPath"
        return $true
    } catch {
        Write-Log WARN "failed to apply launcher icon: $($_.Exception.Message)"
        return $false
    }
}

function Start-LauncherIconDownload {
    param($UI)
    if (Apply-LauncherIcon $UI $script:ShortcutIconFile) {
        Write-Log DEBUG "using cached launcher icon: $script:ShortcutIconFile"
        return
    }
    if ($null -eq $script:RunspacePool) { return }
    Write-Log DEBUG "cached launcher icon missing or invalid, starting download"
    $operation = {
        param([string[]]$Urls, [string]$OutputPath)
        function Test-IconFile {
            param([string]$Path)
            if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
            try {
                Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
                $stream = [System.IO.File]::OpenRead($Path)
                try {
                    $icon = New-Object System.Drawing.Icon($stream)
                    $icon.Dispose()
                    return $true
                } finally {
                    $stream.Dispose()
                }
            } catch {
                return $false
            }
        }

        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
        $lastError = ""
        foreach ($url in $Urls) {
            $temp = "$OutputPath.tmp"
            try {
                $headers = @{ "User-Agent" = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36" }
                Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $headers -OutFile $temp -TimeoutSec 15 -ErrorAction Stop
                if (-not (Test-IconFile $temp)) { throw "下载的文件不是有效 icon" }
                Move-Item -LiteralPath $temp -Destination $OutputPath -Force
                return [PSCustomObject]@{ Success = $true; Path = $OutputPath; Url = $url; Message = "" }
            } catch {
                Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
                $lastError = $_.Exception.Message
            }
        }
        return [PSCustomObject]@{ Success = $false; Path = ""; Url = ""; Message = $lastError }
    }

    try {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $script:RunspacePool
        [void]$ps.AddScript($operation.ToString())
        [void]$ps.AddArgument([string[]]$script:SHORTCUT_ICON_URLS)
        [void]$ps.AddArgument($script:ShortcutIconFile)
        $async = $ps.BeginInvoke()
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(300)
        $timer.Add_Tick({
            if (-not $async.IsCompleted) { return }
            $timer.Stop()
            try {
                $result = $ps.EndInvoke($async) | Select-Object -First 1
                if ($null -ne $result -and $result.Success) {
                    Write-Log INFO "launcher icon downloaded: $($result.Url)"
                    Apply-LauncherIcon $UI ([string]$result.Path)
                } else {
                    $message = ""
                    if ($null -ne $result) { $message = [string]$result.Message }
                    Write-Log WARN "launcher icon download failed: $message"
                }
            } catch {
                Write-Log WARN "launcher icon download task failed: $($_.Exception.Message)"
            } finally {
                $ps.Dispose()
            }
        }.GetNewClosure())
        $timer.Start()
    } catch {
        Write-Log WARN "failed to start launcher icon download: $($_.Exception.Message)"
    }
}

function Apply-HeroImage {
    param($UI, [string]$ImagePath)
    if ([string]::IsNullOrWhiteSpace($ImagePath) -or -not (Test-Path -LiteralPath $ImagePath -PathType Leaf)) { return $false }
    $heroImage = Get-UiControl $UI "HeroImage"
    $heroOverlay = Get-UiControl $UI "HeroImageOverlay"
    $aboutHeroImage = Get-UiControl $UI "AboutHeroImage"
    $aboutHeroOverlay = Get-UiControl $UI "AboutHeroOverlay"
    if ($null -eq $heroImage -and $null -eq $aboutHeroImage) { return $false }

    try {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.UriSource = New-Object System.Uri($ImagePath, [System.UriKind]::Absolute)
        $bitmap.EndInit()
        $bitmap.Freeze()

        $duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(420))
        $imageAnimation = New-Object System.Windows.Media.Animation.DoubleAnimation
        $imageAnimation.From = 0.0
        $imageAnimation.To = 1.0
        $imageAnimation.Duration = $duration
        $imageAnimation.EasingFunction = New-Object System.Windows.Media.Animation.CubicEase -Property @{ EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut }

        $overlayAnimation = New-Object System.Windows.Media.Animation.DoubleAnimation
        $overlayAnimation.From = 0.0
        $overlayAnimation.To = 0.48
        $overlayAnimation.Duration = $duration
        $overlayAnimation.EasingFunction = New-Object System.Windows.Media.Animation.CubicEase -Property @{ EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut }

        foreach ($target in @(
            @{ Image = $heroImage; Overlay = $heroOverlay },
            @{ Image = $aboutHeroImage; Overlay = $aboutHeroOverlay }
        )) {
            $image = $target["Image"]
            $overlay = $target["Overlay"]
            if ($null -eq $image) { continue }
            $image.Source = $bitmap
            $image.Visibility = "Visible"
            $image.Opacity = 0.0
            $image.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $imageAnimation)
            if ($null -ne $overlay) {
                $overlay.Visibility = "Visible"
                $overlay.Opacity = 0.0
                $overlay.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $overlayAnimation)
            }
        }

        Write-Log INFO "hero image applied: $ImagePath"
        return $true
    } catch {
        Write-Log WARN "failed to apply hero image: $($_.Exception.Message)"
        return $false
    }
}

function Start-HeroImageDownload {
    param($UI)
    if (Apply-HeroImage $UI $script:HeroImageFile) {
        Write-Log DEBUG "using cached hero image: $script:HeroImageFile"
        return
    }
    Write-Log DEBUG "cached hero image missing or invalid, starting download"
    if ($null -eq $script:RunspacePool) { return }
    $operation = {
        param([string[]]$Urls, [string]$OutputPath)
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
        $lastError = ""
        foreach ($url in $Urls) {
            try {
                $temp = "$OutputPath.tmp"
                Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $temp -TimeoutSec 15 -ErrorAction Stop
                Move-Item -LiteralPath $temp -Destination $OutputPath -Force
                return [PSCustomObject]@{ Success = $true; Path = $OutputPath; Url = $url; Message = "" }
            } catch {
                Remove-Item -LiteralPath "$OutputPath.tmp" -Force -ErrorAction SilentlyContinue
                $lastError = $_.Exception.Message
            }
        }
        return [PSCustomObject]@{ Success = $false; Path = ""; Url = ""; Message = $lastError }
    }

    try {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $script:RunspacePool
        [void]$ps.AddScript($operation.ToString())
        [void]$ps.AddArgument([string[]]$script:HERO_IMAGE_URLS)
        [void]$ps.AddArgument($script:HeroImageFile)
        $async = $ps.BeginInvoke()
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(300)
        $timer.Add_Tick({
            if (-not $async.IsCompleted) { return }
            $timer.Stop()
            try {
                $result = $ps.EndInvoke($async) | Select-Object -First 1
                if ($null -ne $result -and $result.Success) {
                    Write-Log INFO "hero image downloaded: $($result.Url)"
                    Apply-HeroImage $UI ([string]$result.Path)
                } else {
                    $message = ""
                    if ($null -ne $result) { $message = [string]$result.Message }
                    Write-Log WARN "hero image download failed: $message"
                }
            } catch {
                Write-Log WARN "hero image download task failed: $($_.Exception.Message)"
            } finally {
                $ps.Dispose()
            }
        }.GetNewClosure())
        $timer.Start()
    } catch {
        Write-Log WARN "failed to start hero image download: $($_.Exception.Message)"
    }
}

function Show-AppPage {
    param($UI, [string]$PageName)
    $startPageTransition = ${function:Start-PageTransition}
    $setNavButtonSelected = ${function:Set-NavButtonSelected}
    foreach ($page in @($UI.StartPage, $UI.AdvancedPage, $UI.SoftwarePage, $UI.SettingsPage, $UI.AboutPage)) {
        if ($null -ne $page) { $page.Visibility = "Collapsed" }
    }
    $visiblePage = $UI.StartPage
    switch ($PageName) {
        "advanced" { $visiblePage = $UI.AdvancedPage }
        "software" { $visiblePage = $UI.SoftwarePage }
        "settings" { $visiblePage = $UI.SettingsPage }
        "about" { $visiblePage = $UI.AboutPage }
        default { $visiblePage = $UI.StartPage; $PageName = "start" }
    }
    if ($null -ne $visiblePage) {
        $visiblePage.Visibility = "Visible"
        & $startPageTransition $visiblePage
    }
    & $setNavButtonSelected $UI $PageName
}

function Convert-ScreenRectToWpfRect {
    param($Window, [System.Drawing.Rectangle]$ScreenRect)
    $source = [System.Windows.PresentationSource]::FromVisual($Window)
    if ($null -eq $source -or $null -eq $source.CompositionTarget) {
        return [PSCustomObject]@{
            Left = [double]$ScreenRect.Left
            Top = [double]$ScreenRect.Top
            Width = [double]$ScreenRect.Width
            Height = [double]$ScreenRect.Height
        }
    }

    $transform = $source.CompositionTarget.TransformFromDevice
    $topLeft = $transform.Transform((New-Object System.Windows.Point([double]$ScreenRect.Left, [double]$ScreenRect.Top)))
    $bottomRight = $transform.Transform((New-Object System.Windows.Point([double]$ScreenRect.Right, [double]$ScreenRect.Bottom)))
    return [PSCustomObject]@{
        Left = $topLeft.X
        Top = $topLeft.Y
        Width = $bottomRight.X - $topLeft.X
        Height = $bottomRight.Y - $topLeft.Y
    }
}

function Toggle-CustomMaximizeWindow {
    param($UI)
    if ($null -eq $UI -or $null -eq $UI.Window) { return }
    $window = $UI.Window

    if ([bool](Get-ObjectPropertyValue $script:WindowChromeState "IsMaximized" $false)) {
        $bounds = Get-ObjectPropertyValue $script:WindowChromeState "RestoreBounds" $null
        $script:WindowChromeState.IsMaximized = $false
        if ($null -ne $bounds) {
            $window.Left = [double]$bounds.Left
            $window.Top = [double]$bounds.Top
            $window.Width = [double]$bounds.Width
            $window.Height = [double]$bounds.Height
        } else {
            $window.WindowState = "Normal"
        }
        if ($null -ne $UI.MaxBtn) { $UI.MaxBtn.Content = "⬜" }
        if ($null -ne $UI.MainBorder) { $UI.MainBorder.CornerRadius = 12 }
        return
    }

    if ($window.WindowState -eq "Minimized") { $window.WindowState = "Normal" }
    $script:WindowChromeState.RestoreBounds = [PSCustomObject]@{
        Left = $window.Left
        Top = $window.Top
        Width = $window.Width
        Height = $window.Height
    }

    $handle = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
    $screen = [System.Windows.Forms.Screen]::FromHandle($handle)
    $workArea = Convert-ScreenRectToWpfRect -Window $window -ScreenRect $screen.WorkingArea
    $window.WindowState = "Normal"
    $window.Left = $workArea.Left
    $window.Top = $workArea.Top
    $window.Width = $workArea.Width
    $window.Height = $workArea.Height
    $script:WindowChromeState.IsMaximized = $true
    if ($null -ne $UI.MaxBtn) { $UI.MaxBtn.Content = "❐" }
    if ($null -ne $UI.MainBorder) { $UI.MainBorder.CornerRadius = 0 }
}

function Update-OneClickModeUi {
    param($UI)
    $startModeTabs = Get-UiControl $UI "StartModeTabs"
    $launchScriptList = Get-UiControl $UI "LaunchScriptList"
    $unifiedStartBtn = Get-UiControl $UI "UnifiedStartBtn"
    if ($null -eq $startModeTabs -or $null -eq $launchScriptList) { return }
    $startLabel = Get-UiControl $UI "UnifiedStartLabel"
    if ($startModeTabs.SelectedIndex -eq 1) {
        $launchScriptList.IsEnabled = $false
        if ($null -ne $startLabel) { $startLabel.Text = "运行安装器" }
        elseif ($null -ne $unifiedStartBtn) { $unifiedStartBtn.Content = "▶ 运行安装器" }
    } else {
        $launchScriptList.IsEnabled = $true
        if ($null -ne $startLabel) { $startLabel.Text = "启动所选脚本" }
        elseif ($null -ne $unifiedStartBtn) { $unifiedStartBtn.Content = "▶ 启动所选脚本" }
    }
}

function Set-OneClickModeFromStatus {
    param($UI, $State, [string]$StatusCode)
    $updateOneClickModeUi = ${function:Update-OneClickModeUi}
    $startModeTabs = Get-UiControl $UI "StartModeTabs"
    if ($null -eq $startModeTabs) { return }
    if ($null -ne $State -and $null -ne $State.PSObject.Properties["LastOneClickStatus"]) {
        if ([string]$State.LastOneClickStatus -eq $StatusCode) {
            & $updateOneClickModeUi $UI
            return
        }
        $State.LastOneClickStatus = $StatusCode
    }
    if ($StatusCode -eq "installed") {
        $startModeTabs.SelectedIndex = 0
    } else {
        $startModeTabs.SelectedIndex = 1
    }
    & $updateOneClickModeUi $UI
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
    $startModeTabs = Get-UiControl $UI "StartModeTabs"
    $launchScriptList = Get-UiControl $UI "LaunchScriptList"
    if ($null -eq $startModeTabs -or $startModeTabs.SelectedIndex -eq 1) {
        Invoke-RunInstaller $UI $State
        return
    }
    if ($null -eq $launchScriptList -or $null -eq $launchScriptList.SelectedItem) {
        Show-Message "请选择要启动的管理脚本。" "未选择脚本" "Warning"
        return
    }
    $scriptName = ""
    if ($null -ne $launchScriptList.SelectedItem.PSObject.Properties["Name"]) {
        $scriptName = [string]$launchScriptList.SelectedItem.PSObject.Properties["Name"].Value
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

function Open-CacheFolder {
    $path = $script:CacheHome
    if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Force -Path $path | Out-Null }
    Start-Process -FilePath "explorer.exe" -ArgumentList @($path) | Out-Null
}

function Open-LogFolder {
    $path = $script:LogHome
    if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Force -Path $path | Out-Null }
    Start-Process -FilePath "explorer.exe" -ArgumentList @($path) | Out-Null
}

function Open-ExternalUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return }
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $Url
        $startInfo.UseShellExecute = $true
        [System.Diagnostics.Process]::Start($startInfo) | Out-Null
    } catch {
        try {
            Start-Process -FilePath "explorer.exe" -ArgumentList @($Url) | Out-Null
        } catch {
            Write-Log WARN "failed to open external url: $Url error=$($_.Exception.Message)"
            Show-Message "无法打开链接: $Url`n$($_.Exception.Message)" "打开链接失败" "Warning"
        }
    }
}
