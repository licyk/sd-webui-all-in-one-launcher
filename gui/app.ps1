# Application entry flow and event wiring.

function Start-App {
    Initialize-Directories
    $script:MainConfig = Get-DefaultMainConfig
    Write-Log INFO "gui launcher starting version=$script:INSTALLER_LAUNCHER_GUI_VERSION"
    $runtimeEdition = if ($PSVersionTable.ContainsKey("PSEdition")) { [string]$PSVersionTable["PSEdition"] } else { "Desktop" }
    $runtimeOs = if ($PSVersionTable.ContainsKey("OS")) { [string]$PSVersionTable["OS"] } else { [System.Environment]::OSVersion.VersionString }
    $runtimeClr = if ($PSVersionTable.ContainsKey("CLRVersion")) { [string]$PSVersionTable["CLRVersion"] } else { "" }
    Write-Log INFO "powershell runtime: version=$($PSVersionTable.PSVersion) edition=$runtimeEdition host=$($Host.Name) clr=$runtimeClr os=$runtimeOs"
    Register-LauncherUninstallEntry
    Load-AllConfig
    if (-not [bool]$script:MainConfig["USER_AGREEMENT_ACCEPTED"]) {
        if (-not (Show-UserAgreementDialog)) {
            Write-Log INFO "user agreement declined, gui launcher exiting"
            return
        }
        $script:MainConfig["USER_AGREEMENT_ACCEPTED"] = $true
        Save-MainConfig
        Write-Log INFO "user agreement accepted"
    }
    Configure-ProxyFromMainConfig
    $script:RunspacePool = [runspacefactory]::CreateRunspacePool(1, 3)
    $script:RunspacePool.ApartmentState = "STA"
    $script:RunspacePool.Open()
    $colors = Get-ThemeColors
    $displayConfigHome = $script:ConfigHome
    $displayLogFile = $script:LogFile
    $window = Load-GuiXamlWindow "main.xaml"
    Set-ThemeResources -Window $window -Colors $colors
    $window.Title = $script:APP_TITLE
    $titleVersionText = $window.FindName("TitleVersionText")
    if ($null -ne $titleVersionText) { $titleVersionText.Text = "  v$script:INSTALLER_LAUNCHER_GUI_VERSION" }
    $aboutVersionText = $window.FindName("AboutVersionText")
    if ($null -ne $aboutVersionText) { $aboutVersionText.Text = "v$script:INSTALLER_LAUNCHER_GUI_VERSION" }
    Export-GuiEventFunctions
    $window.Dispatcher.add_UnhandledException({
        param($sender, $eventArgs)
        Report-UiError -Context "WPF 事件处理" -ErrorObject $eventArgs.Exception -ShowDialog $true
        $eventArgs.Handled = $true
    }.GetNewClosure())
    $UI = [PSCustomObject]@{
        Window = $window; TitleBar = $window.FindName("TitleBar"); MinBtn = $window.FindName("MinBtn"); MaxBtn = $window.FindName("MaxBtn"); CloseBtn = $window.FindName("CloseBtn")
        MainBorder = $window.FindName("MainBorder"); StartPage = $window.FindName("StartPage"); AdvancedPage = $window.FindName("AdvancedPage"); SoftwarePage = $window.FindName("SoftwarePage"); SettingsPage = $window.FindName("SettingsPage"); AboutPage = $window.FindName("AboutPage"); MainTabs = $window.FindName("MainTabs"); ProjectList = $window.FindName("ProjectList"); ProjectStatusText = $window.FindName("ProjectStatusText"); BusyText = $window.FindName("BusyText"); HeroImage = $window.FindName("HeroImage"); HeroImageOverlay = $window.FindName("HeroImageOverlay"); AboutHeroImage = $window.FindName("AboutHeroImage"); AboutHeroOverlay = $window.FindName("AboutHeroOverlay"); TitleLogoBorder = $window.FindName("TitleLogoBorder"); TitleLogoImage = $window.FindName("TitleLogoImage"); TitleLogoText = $window.FindName("TitleLogoText")
        SelectedProjectHintText = $window.FindName("SelectedProjectHintText")
        PathPanel = $window.FindName("PathPanel"); ConfigPanel = $window.FindName("ConfigPanel")
        DiscoverInstallsBtn = $window.FindName("DiscoverInstallsBtn"); DiscoverFolderInstallsBtn = $window.FindName("DiscoverFolderInstallsBtn"); CancelDiscoveryBtn = $window.FindName("CancelDiscoveryBtn"); DiscoveryProgressBar = $window.FindName("DiscoveryProgressBar"); DiscoveryProgressText = $window.FindName("DiscoveryProgressText"); DiscoveryStatusText = $window.FindName("DiscoveryStatusText"); DiscoveredInstallPanel = $window.FindName("DiscoveredInstallPanel")
        ScriptCombo = $window.FindName("ScriptCombo"); ScriptParamPanel = $window.FindName("ScriptParamPanel"); ScriptArgsBox = $window.FindName("ScriptArgsBox")
        StartModeTabs = $window.FindName("StartModeTabs"); LaunchScriptList = $window.FindName("LaunchScriptList"); UnifiedStartBtn = $window.FindName("UnifiedStartBtn"); UnifiedStartLabel = $window.FindName("UnifiedStartLabel"); StartProgressBar = $window.FindName("StartProgressBar"); TerminateOperationBtn = $window.FindName("TerminateOperationBtn"); StartHintText = $window.FindName("StartHintText"); InstallHintText = $window.FindName("InstallHintText")
        AutoUpdateCheck = $window.FindName("AutoUpdateCheck"); LogLevelCombo = $window.FindName("LogLevelCombo"); ProxyModeCombo = $window.FindName("ProxyModeCombo"); ManualProxyBox = $window.FindName("ManualProxyBox")
        CheckUpdateBtn = $window.FindName("CheckUpdateBtn"); OpenConfigFolderBtn = $window.FindName("OpenConfigFolderBtn"); OpenLogFolderBtn = $window.FindName("OpenLogFolderBtn"); OpenCacheFolderBtn = $window.FindName("OpenCacheFolderBtn"); CreateShortcutBtn = $window.FindName("CreateShortcutBtn"); UninstallLauncherBtn = $window.FindName("UninstallLauncherBtn"); UninstallBtn = $window.FindName("UninstallBtn"); OneClickNavBtn = $window.FindName("OneClickNavBtn"); AdvancedNavBtn = $window.FindName("AdvancedNavBtn"); SoftwareNavBtn = $window.FindName("SoftwareNavBtn"); SettingsNavBtn = $window.FindName("SettingsNavBtn"); AboutNavBtn = $window.FindName("AboutNavBtn"); OneClickNavLabel = $window.FindName("OneClickNavLabel"); AdvancedNavLabel = $window.FindName("AdvancedNavLabel"); SoftwareNavLabel = $window.FindName("SoftwareNavLabel"); SettingsNavLabel = $window.FindName("SettingsNavLabel"); AboutNavLabel = $window.FindName("AboutNavLabel"); OneClickNavIcon = $window.FindName("OneClickNavIcon"); AdvancedNavIcon = $window.FindName("AdvancedNavIcon"); SoftwareNavIcon = $window.FindName("SoftwareNavIcon"); SettingsNavIcon = $window.FindName("SettingsNavIcon"); AboutNavIcon = $window.FindName("AboutNavIcon"); HelpBtn = $window.FindName("HelpBtn"); ShowLogBtn = $window.FindName("ShowLogBtn"); AboutAgreementText = $window.FindName("AboutAgreementText")
        AboutSdAllInOneBtn = $window.FindName("AboutSdAllInOneBtn"); AboutLauncherBtn = $window.FindName("AboutLauncherBtn"); AboutAuthorBtn = $window.FindName("AboutAuthorBtn"); AboutBlogBtn = $window.FindName("AboutBlogBtn"); AboutBilibiliBtn = $window.FindName("AboutBilibiliBtn")
        LogBox = $window.FindName("LogBox")
    }
    $State = [PSCustomObject]@{ CurrentOperation = $null; ConfigControls = @{}; ScriptParamControls = @{}; ProjectConfig = @{}; DiscoveredInstalls = @(); StatusRefreshTimer = $null; DiscoveryProgressTimer = $null; LastOneClickStatus = ""; IsRefreshing = $false; AutoSaveProjectConfig = $null; IsAutoSavingMainConfig = $false }
    $script:InstallerLauncherGuiUi = $UI
    $script:InstallerLauncherGuiState = $State
    $mainConfig = $script:MainConfig
    $State.AutoSaveProjectConfig = { Save-CurrentProjectConfigFromUi $UI $State $false }.GetNewClosure()
    if ($null -ne $UI.AboutAgreementText) {
        $UI.AboutAgreementText.Text = Get-UserAgreementText
    }

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
            Refresh-DiscoveredInstallList $UI $State
            Select-RelevantMainTab $UI
            $currentProject = $mainConfig["CURRENT_PROJECT"]
            Append-UiLog $UI "当前项目已切换: $currentProject"
        } catch {
            Report-UiError -Context "切换项目" -ErrorObject $_ -ShowDialog $true
        }
    }.GetNewClosure())
    $UI.StartModeTabs.Add_SelectionChanged({ Update-OneClickModeUi $UI; Start-TabTransition $UI.StartModeTabs }.GetNewClosure())
    $UI.MainTabs.Add_SelectionChanged({ Start-TabTransition $UI.MainTabs }.GetNewClosure())
    $UI.UnifiedStartBtn.Add_Click({ Invoke-OneClickAction $UI $State }.GetNewClosure())
    $UI.TerminateOperationBtn.Add_Click({ Invoke-TerminateCurrentOperation $UI $State }.GetNewClosure())
    $UI.ScriptCombo.Add_SelectionChanged({
        $key = Get-CurrentProjectKey
        if ([string]::IsNullOrWhiteSpace($key) -or $null -eq $UI.ScriptCombo.SelectedItem) { return }
        $config = Get-ProjectConfig $key
        $scriptName = Get-SelectedScriptName $UI.ScriptCombo
        $State.IsRefreshing = $true
        try {
        if ($null -ne $config["ScriptArgs"] -and (Test-DictionaryKey $config["ScriptArgs"] $scriptName)) {
            $UI.ScriptArgsBox.Text = [string]$config["ScriptArgs"][$scriptName]
        } else {
            $UI.ScriptArgsBox.Text = ""
        }
        Refresh-ScriptParamUi $UI $State
        } finally {
            $State.IsRefreshing = $false
        }
    }.GetNewClosure())
    $UI.ScriptArgsBox.Add_TextChanged({ Save-CurrentProjectConfigFromUi $UI $State $false }.GetNewClosure())
    $UI.AutoUpdateCheck.Add_Checked({ AutoSave-MainConfigFromUi $UI $State }.GetNewClosure())
    $UI.AutoUpdateCheck.Add_Unchecked({ AutoSave-MainConfigFromUi $UI $State }.GetNewClosure())
    $UI.LogLevelCombo.Add_SelectionChanged({ AutoSave-MainConfigFromUi $UI $State }.GetNewClosure())
    $UI.ProxyModeCombo.Add_SelectionChanged({ AutoSave-MainConfigFromUi $UI $State }.GetNewClosure())
    $UI.ManualProxyBox.Add_TextChanged({ AutoSave-MainConfigFromUi $UI $State }.GetNewClosure())
    $UI.CheckUpdateBtn.Add_Click({ Invoke-UpdateCheck $UI $State $true }.GetNewClosure())
    $UI.OpenConfigFolderBtn.Add_Click({ Open-ConfigFolder }.GetNewClosure())
    $UI.OpenLogFolderBtn.Add_Click({ Open-LogFolder }.GetNewClosure())
    $UI.OpenCacheFolderBtn.Add_Click({ Open-CacheFolder }.GetNewClosure())
    $UI.CreateShortcutBtn.Add_Click({ Invoke-CreateLauncherShortcut $UI $State }.GetNewClosure())
    $UI.UninstallLauncherBtn.Add_Click({ Invoke-UninstallLauncher $UI }.GetNewClosure())
    $UI.DiscoverInstallsBtn.Add_Click({ Invoke-DiscoverInstalledWebUis -UI $UI -State $State }.GetNewClosure())
    $UI.DiscoverFolderInstallsBtn.Add_Click({ Invoke-DiscoverInstalledWebUisInFolder $UI $State }.GetNewClosure())
    $UI.CancelDiscoveryBtn.Add_Click({ Invoke-CancelDiscoverySearch $UI $State }.GetNewClosure())
    $UI.OneClickNavBtn.Add_Click({ Show-AppPage $UI "start" }.GetNewClosure())
    $UI.AdvancedNavBtn.Add_Click({ Show-AppPage $UI "advanced"; Select-RelevantMainTab $UI }.GetNewClosure())
    $UI.SoftwareNavBtn.Add_Click({ Show-AppPage $UI "software" }.GetNewClosure())
    $UI.SettingsNavBtn.Add_Click({ Show-AppPage $UI "settings" }.GetNewClosure())
    $UI.AboutNavBtn.Add_Click({ Show-AppPage $UI "about" }.GetNewClosure())
    $UI.UninstallBtn.Add_Click({ Invoke-UninstallProject $UI $State }.GetNewClosure())
    $UI.HelpBtn.Add_Click({ Show-HelpWindow }.GetNewClosure())
    $UI.ShowLogBtn.Add_Click({ Show-LogWindow }.GetNewClosure())
    foreach ($button in @($UI.AboutSdAllInOneBtn, $UI.AboutLauncherBtn, $UI.AboutAuthorBtn, $UI.AboutBlogBtn, $UI.AboutBilibiliBtn)) {
        if ($null -ne $button) {
            $button.Add_Click({
                param($sender, $eventArgs)
                Open-ExternalUrl ([string]$sender.Tag)
            }.GetNewClosure())
        }
    }

    $script:WindowChromeState = [PSCustomObject]@{ IsMaximized = $false; RestoreBounds = $null }
    $UI.TitleBar.Add_MouseLeftButtonDown({
        if ($_.ClickCount -eq 2) { $UI.MaxBtn.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent))); return }
        if ([bool](Get-ObjectPropertyValue $script:WindowChromeState "IsMaximized" $false)) { return }
        $window.DragMove()
    })
    $UI.MinBtn.Add_Click({ $window.WindowState = "Minimized" })
    $UI.MaxBtn.Add_Click({
        Toggle-CustomMaximizeWindow $UI
    })
    $UI.CloseBtn.Add_Click({ $window.Close() })
    $window.Add_Loaded({
        try {
            try {
                $handle = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
                try {
                    [LauncherWindowHelper]::EnableAcrylic($handle, [bool]$colors.IsDark)
                } catch {
                    Write-Log WARN "acrylic setup failed, fallback to blur: $($_.Exception.Message)"
                    [LauncherWindowHelper]::EnableBlur($handle)
                }
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
            Append-UiLog $UI "先选择 WebUI / 工具；未安装时运行 installer，已安装后运行管理脚本。"
            Start-LauncherIconDownload $UI
            Start-HeroImageDownload $UI

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
