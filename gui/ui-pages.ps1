# Page rendering and dynamic configuration UI.

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

function Get-InstallDiscoveryFeatureRows {
    $rows = @()
    foreach ($projectKey in $script:Projects.Keys) {
        $project = $script:Projects[$projectKey]
        foreach ($scriptName in $project.Scripts.Keys) {
            if ($scriptName -match '^launch_.+_installer\.ps1$') {
                $rows += [PSCustomObject]@{
                    FeatureScript = [string]$scriptName
                    ProjectKey = [string]$projectKey
                    ProjectName = [string]$project.Name
                    ManagementScripts = @($project.Scripts.Keys)
                }
            }
        }
    }
    return @($rows)
}

function Get-DefaultInstallDiscoveryRoots {
    $roots = @()
    try {
        foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
            if ($drive.DriveType -eq [System.IO.DriveType]::Fixed -and $drive.IsReady) {
                $roots += $drive.RootDirectory.FullName
            }
        }
    } catch {
        Write-Log WARN "failed to enumerate fixed drives for install discovery: $($_.Exception.Message)"
    }
    if ($roots.Count -eq 0) {
        $roots += [Environment]::GetFolderPath("UserProfile")
    }
    return @($roots | Select-Object -Unique)
}

function Refresh-DiscoveredInstallList {
    param($UI, $State)
    $panel = Get-UiControl $UI "DiscoveredInstallPanel"
    $statusText = Get-UiControl $UI "DiscoveryStatusText"
    if ($null -eq $panel) { return }
    $panel.Children.Clear()
    $items = @()
    if ($null -ne $State -and $null -ne $State.PSObject.Properties["DiscoveredInstalls"]) {
        $items = @($State.DiscoveredInstalls)
    }
    if ($items.Count -eq 0) {
        if ($null -ne $statusText -and [string]::IsNullOrWhiteSpace($statusText.Text)) {
            $statusText.Text = "尚未搜索到已安装实例。可以扫描固定磁盘，或选择某个目录进行快速搜索。"
        }
        $empty = New-Object System.Windows.Controls.TextBlock
        $empty.Text = '暂无发现结果。搜索不会覆盖当前安装路径，只有点击“设为当前管理目标”才会写入配置。'
        $empty.TextWrapping = "Wrap"
        $empty.Margin = "0,8,0,0"
        $empty.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "TextSecBrush")
        $panel.Children.Add($empty) | Out-Null
        return
    }
    if ($null -ne $statusText) {
        $projectCount = @($items | Select-Object -ExpandProperty ProjectKey -Unique).Count
        $statusText.Text = "已发现 $($items.Count) 个安装实例，覆盖 $projectCount 种 WebUI / 工具。"
    }
    $currentProjectKey = Get-CurrentProjectKey
    $groups = @($items | Sort-Object ProjectName, InstallPath | Group-Object ProjectKey)
    foreach ($group in $groups) {
        $first = @($group.Group | Select-Object -First 1)[0]
        $groupProjectKey = [string](Get-ObjectPropertyValue $first "ProjectKey" "")
        $isCurrentProjectGroup = (-not [string]::IsNullOrWhiteSpace($currentProjectKey) -and $groupProjectKey -eq $currentProjectKey)
        $header = New-Object System.Windows.Controls.TextBlock
        if ($isCurrentProjectGroup) {
            $header.Text = "$($first.ProjectName)（当前软件类型）"
        } else {
            $header.Text = "$($first.ProjectName)（需先切换软件类型）"
        }
        $header.FontSize = 15
        $header.FontWeight = "SemiBold"
        $header.Margin = "0,14,0,8"
        $panel.Children.Add($header) | Out-Null
        foreach ($item in @($group.Group)) {
            $card = New-Object System.Windows.Controls.Border
            $card.Margin = "0,0,0,10"
            $card.Padding = "12"
            $card.CornerRadius = 8
            $card.BorderThickness = 1
            $card.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "HeaderBGBrush")
            $card.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, "BorderBrush")

            $grid = New-Object System.Windows.Controls.Grid
            $left = New-Object System.Windows.Controls.ColumnDefinition
            $left.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
            $right = New-Object System.Windows.Controls.ColumnDefinition
            $right.Width = New-Object System.Windows.GridLength(170)
            $grid.ColumnDefinitions.Add($left) | Out-Null
            $grid.ColumnDefinitions.Add($right) | Out-Null

            $text = New-Object System.Windows.Controls.TextBlock
            $projectKey = [string](Get-ObjectPropertyValue $item "ProjectKey" "")
            $isCurrentProjectItem = (-not [string]::IsNullOrWhiteSpace($currentProjectKey) -and $projectKey -eq $currentProjectKey)
            $itemText = "$($item.InstallPath)`n特征脚本: $($item.FeatureScript)    可用管理脚本: $($item.ManagementScriptCount)    状态: $($item.Status)"
            if (-not $isCurrentProjectItem) {
                $itemText += "`n提示: 请先在软件选择中切换到 $($item.ProjectName)，再选择这个路径。"
            }
            $text.Text = $itemText
            $text.TextWrapping = "Wrap"
            $text.Margin = "0,0,14,0"
            [System.Windows.Controls.Grid]::SetColumn($text, 0)
            $grid.Children.Add($text) | Out-Null

            $button = New-Object System.Windows.Controls.Button
            if ($isCurrentProjectItem) {
                $button.Content = "设为当前管理目标"
                $button.IsEnabled = $true
            } else {
                $button.Content = "先切换软件类型"
                $button.IsEnabled = $false
            }
            $button.Tag = $item
            $button.VerticalAlignment = "Center"
            if ($isCurrentProjectItem -and $null -ne $UI.Window.Resources["PrimaryButton"]) {
                $button.Style = $UI.Window.Resources["PrimaryButton"]
            }
            [System.Windows.Controls.Grid]::SetColumn($button, 1)
            $grid.Children.Add($button) | Out-Null
            $button.Add_Click({
                param($sender, $eventArgs)
                Apply-DiscoveredInstallTarget $script:InstallerLauncherGuiUi $script:InstallerLauncherGuiState $sender.Tag
            })

            $card.Child = $grid
            $panel.Children.Add($card) | Out-Null
        }
    }
}

function Apply-DiscoveredInstallTarget {
    param($UI, $State, $InstallTarget)
    if ($null -eq $InstallTarget) { return }
    $projectKey = [string](Get-ObjectPropertyValue $InstallTarget "ProjectKey" "")
    $installPath = [string](Get-ObjectPropertyValue $InstallTarget "InstallPath" "")
    if ([string]::IsNullOrWhiteSpace($projectKey) -or -not $script:Projects.Contains($projectKey)) {
        Show-Message "发现结果中的项目类型无效，无法应用。" "无法应用" "Warning"
        return
    }
    $currentProjectKey = Get-CurrentProjectKey
    if ([string]::IsNullOrWhiteSpace($currentProjectKey) -or $currentProjectKey -ne $projectKey) {
        $projectName = [string](Get-ObjectPropertyValue $InstallTarget "ProjectName" $projectKey)
        Show-Message "这个发现结果属于 $projectName。`n`n请先在软件选择中切换到对应软件类型，再选择这个路径。" "请先切换软件类型" "Information"
        return
    }
    if ([string]::IsNullOrWhiteSpace($installPath)) {
        Show-Message "发现结果中的安装路径为空，无法应用。" "无法应用" "Warning"
        return
    }
    $script:MainConfig["CURRENT_PROJECT"] = $projectKey
    Save-MainConfig

    $config = Get-ProjectConfig $projectKey
    $config["INSTALL_PATH"] = $installPath
    Save-ProjectConfig $projectKey $config

    $projectList = Get-UiControl $UI "ProjectList"
    if ($null -ne $projectList) {
        foreach ($item in $projectList.Items) {
            if ($item.Key -eq $projectKey) {
                $projectList.SelectedItem = $item
                break
            }
        }
    }
    Refresh-ProjectConfigUi $UI $State
    Refresh-Status $UI $State
    Select-RelevantMainTab $UI
    Append-UiLog $UI "已切换管理目标: $projectKey -> $installPath"
}

function Set-DiscoverySearchBusy {
    param($UI, $State, [bool]$Busy, [string]$Message = "")
    foreach ($name in @("DiscoverInstallsBtn", "DiscoverFolderInstallsBtn")) {
        $button = Get-UiControl $UI $name
        if ($null -ne $button) { $button.IsEnabled = -not $Busy }
    }
    $cancelButton = Get-UiControl $UI "CancelDiscoveryBtn"
    if ($null -ne $cancelButton) {
        $cancelButton.Visibility = $(if ($Busy) { "Visible" } else { "Collapsed" })
        $cancelButton.IsEnabled = $Busy
    }
    $progressBar = Get-UiControl $UI "DiscoveryProgressBar"
    if ($null -ne $progressBar) {
        $progressBar.IsIndeterminate = $true
        $progressBar.Visibility = $(if ($Busy) { "Visible" } else { "Collapsed" })
    }
    $progressText = Get-UiControl $UI "DiscoveryProgressText"
    if ($null -ne $progressText) {
        $progressText.Text = $Message
        $progressText.Visibility = $(if ($Busy -and -not [string]::IsNullOrWhiteSpace($Message)) { "Visible" } else { "Collapsed" })
    }
    if (-not $Busy -and $null -ne $State -and $null -ne (Get-ObjectPropertyValue $State "DiscoveryProgressTimer" $null)) {
        try { $State.DiscoveryProgressTimer.Stop() } catch {}
        $State.DiscoveryProgressTimer = $null
    }
}

function Update-DiscoveryProgressUi {
    param($UI, $State)
    $operation = Get-ObjectPropertyValue $State "DiscoveryOperation" $null
    if ($null -eq $operation -or [string](Get-ObjectPropertyValue $operation "Name" "") -ne "搜索已安装 WebUI") {
        Set-DiscoverySearchBusy $UI $State $false
        return
    }
    $control = Get-ObjectPropertyValue $operation "Control" $null
    if ($null -eq $control) { return }
    $scanned = [int]$control["ScannedDirectories"]
    $found = [int]$control["FoundCount"]
    $root = [string]$control["CurrentRoot"]
    $message = "正在搜索，已扫描 $scanned 个目录，发现 $found 个实例。"
    if (-not [string]::IsNullOrWhiteSpace($root)) { $message += " 当前范围: $root" }
    $progressText = Get-UiControl $UI "DiscoveryProgressText"
    if ($null -ne $progressText) {
        $progressText.Text = $message
        $progressText.Visibility = "Visible"
    }
}

function Start-DiscoveryProgressTimer {
    param($UI, $State)
    if ($null -ne (Get-ObjectPropertyValue $State "DiscoveryProgressTimer" $null)) {
        try { $State.DiscoveryProgressTimer.Stop() } catch {}
    }
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.Add_Tick({
        try {
            Update-DiscoveryProgressUi $UI $State
        } catch {
            Write-Log WARN "discovery progress ui update failed: $($_.Exception.Message)"
        }
    }.GetNewClosure())
    $State.DiscoveryProgressTimer = $timer
    $timer.Start()
}

function Invoke-CancelDiscoverySearch {
    param($UI, $State)
    $operation = Get-ObjectPropertyValue $State "DiscoveryOperation" $null
    if ($null -eq $operation -or [string](Get-ObjectPropertyValue $operation "Name" "") -ne "搜索已安装 WebUI") {
        Show-Message "当前没有正在搜索的任务。" "无需停止" "Information"
        return
    }
    $control = Get-ObjectPropertyValue $operation "Control" $null
    if ($null -eq $control) { return }
    $control["StopRequested"] = $true
    $control["IsTerminating"] = $true
    $cancelButton = Get-UiControl $UI "CancelDiscoveryBtn"
    if ($null -ne $cancelButton) { $cancelButton.IsEnabled = $false }
    $progressText = Get-UiControl $UI "DiscoveryProgressText"
    if ($null -ne $progressText) {
        $progressText.Text = "正在停止搜索，请稍候..."
        $progressText.Visibility = "Visible"
    }
    $status = Get-UiControl $UI "DiscoveryStatusText"
    if ($null -ne $status) { $status.Text = "正在停止搜索..." }
    Append-UiLog $UI "已请求停止搜索已安装 WebUI。"
}

function Invoke-DiscoverInstalledWebUis {
    param($UI, $State, [string[]]$Roots)
    $State = Ensure-GuiState $State
    if ($null -ne (Get-ObjectPropertyValue $State "DiscoveryOperation" $null)) {
        Show-Message "搜索任务正在运行，请等待当前搜索完成或先停止搜索。" "搜索运行中" "Warning"
        return
    }
    if ($null -eq $Roots -or $Roots.Count -eq 0) {
        $Roots = @(Get-DefaultInstallDiscoveryRoots)
    }
    $featureRows = @(Get-InstallDiscoveryFeatureRows)
    if ($featureRows.Count -eq 0) {
        Show-Message "没有可用于搜索的安装特征脚本。" "无法搜索" "Warning"
        return
    }
    $statusText = Get-UiControl $UI "DiscoveryStatusText"
    if ($null -ne $statusText) {
        $statusText.Text = "正在搜索: $($Roots -join ', ')"
    }
    Set-DiscoverySearchBusy $UI $State $true "正在搜索，已扫描 0 个目录，发现 0 个实例。"
    Append-UiLog $UI "开始搜索已安装 WebUI: $($Roots -join ', ')"

    $operation = {
        param($FeatureRows, [string[]]$Roots, $Control)
        $Control["ScannedDirectories"] = 0
        $Control["FoundCount"] = 0
        $Control["CurrentRoot"] = ""
        $results = New-Object System.Collections.Generic.List[object]
        $attempts = New-Object System.Collections.Generic.List[string]
        $seen = @{}
        $skipNames = @(
            "Windows", "Program Files", "Program Files (x86)", "ProgramData", "`$Recycle.Bin", "System Volume Information",
            ".git", ".hg", ".svn", ".cache", ".gradle", ".nuget", "node_modules", "__pycache__", "Temp", "tmp"
        )
        $skipSet = @{}
        foreach ($name in $skipNames) { $skipSet[$name.ToLowerInvariant()] = $true }
        $skipped = 0
        $errors = 0
        $scanned = 0
        $cancelled = $false
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        foreach ($root in @($Roots)) {
            if ([bool]$Control["StopRequested"]) {
                $cancelled = $true
                break
            }
            if ([string]::IsNullOrWhiteSpace($root)) { continue }
            if (-not (Test-Path -LiteralPath $root -PathType Container)) {
                [void]$attempts.Add("ROOT missing: $root")
                continue
            }
            $rootPath = [System.IO.Path]::GetFullPath($root)
            $Control["CurrentRoot"] = $rootPath
            [void]$attempts.Add("ROOT scan: $rootPath")
            $stack = New-Object System.Collections.Generic.Stack[string]
            $stack.Push($rootPath)
            while ($stack.Count -gt 0) {
                if ([bool]$Control["StopRequested"]) {
                    $cancelled = $true
                    break
                }
                $dir = $stack.Pop()
                $scanned++
                if (($scanned % 25) -eq 0) {
                    $Control["ScannedDirectories"] = $scanned
                    $Control["FoundCount"] = $results.Count
                }
                try {
                    $fileSet = @{}
                    $directoryInfo = New-Object System.IO.DirectoryInfo($dir)
                    foreach ($entry in $directoryInfo.EnumerateFileSystemInfos()) {
                        try {
                            if (($entry.Attributes -band [System.IO.FileAttributes]::Directory) -ne 0) {
                                if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                                    $skipped++
                                    continue
                                }
                                if ($skipSet.ContainsKey($entry.Name.ToLowerInvariant())) {
                                    $skipped++
                                    continue
                                }
                                $stack.Push($entry.FullName)
                            } else {
                                $fileSet[$entry.Name.ToLowerInvariant()] = $entry.FullName
                            }
                        } catch {
                            $errors++
                            if ($errors -le 50) { [void]$attempts.Add("ENTRY skip: $($entry.FullName) -> $($_.Exception.Message)") }
                        }
                    }

                    foreach ($row in @($FeatureRows)) {
                        $featureScript = [string]$row.FeatureScript
                        $featureKey = $featureScript.ToLowerInvariant()
                        if (-not $fileSet.ContainsKey($featureKey)) { continue }
                        $featurePath = [string]$fileSet[$featureKey]
                        $projectKey = [string]$row.ProjectKey
                        $normalizedDir = [System.IO.Path]::GetFullPath($dir).TrimEnd('\')
                        $dedupeKey = ("{0}|{1}" -f $projectKey, $normalizedDir).ToLowerInvariant()
                        if ($seen.ContainsKey($dedupeKey)) { continue }
                        $seen[$dedupeKey] = $true
                        $availableScripts = New-Object System.Collections.Generic.List[string]
                        foreach ($scriptName in @($row.ManagementScripts)) {
                            $scriptKey = ([string]$scriptName).ToLowerInvariant()
                            if ($fileSet.ContainsKey($scriptKey)) {
                                [void]$availableScripts.Add([string]$scriptName)
                            }
                        }
                        $status = "仅发现特征脚本"
                        if ($availableScripts.Count -gt 0) { $status = "发现管理脚本" }
                        [void]$results.Add([PSCustomObject]@{
                            ProjectKey = $projectKey
                            ProjectName = [string]$row.ProjectName
                            InstallPath = $normalizedDir
                            FeatureScript = $featureScript
                            FeaturePath = $featurePath
                            Status = $status
                            ManagementScriptCount = $availableScripts.Count
                            ManagementScripts = @($availableScripts.ToArray())
                        })
                        [void]$attempts.Add("HIT project=$projectKey path=$normalizedDir feature=$featureScript scripts=$($availableScripts.Count)")
                        $Control["FoundCount"] = $results.Count
                    }
                } catch {
                    $errors++
                    if ($errors -le 50) { [void]$attempts.Add("DIR error: $dir -> $($_.Exception.Message)") }
                }
            }
            if ($cancelled) { break }
        }
        $stopwatch.Stop()
        $Control["ScannedDirectories"] = $scanned
        $Control["FoundCount"] = $results.Count
        [void]$attempts.Add("SUMMARY results=$($results.Count) scanned=$scanned skipped=$skipped errors=$errors cancelled=$cancelled elapsed_ms=$($stopwatch.ElapsedMilliseconds)")
        if ($cancelled) {
            return [PSCustomObject]@{
                Success = $false
                Cancelled = $true
                Results = @($results.ToArray())
                Attempts = @($attempts.ToArray())
                Message = "搜索已取消，已扫描 $scanned 个目录，发现 $($results.Count) 个实例。"
            }
        }
        return [PSCustomObject]@{
            Success = $true
            Cancelled = $false
            Results = @($results.ToArray())
            Attempts = @($attempts.ToArray())
            Message = "搜索完成，扫描 $scanned 个目录，发现 $($results.Count) 个安装实例。"
        }
    }

    Start-GuiOperation -UI $UI -State $State -Name "搜索已安装 WebUI" -ScriptBlock $operation -Arguments @($featureRows, @($Roots)) -CanTerminate $false -UseGlobalBusy $false -StateProperty "DiscoveryOperation" -OnComplete {
        param($result, $streamErrors)
        Set-DiscoverySearchBusy $UI $State $false
        $item = Select-GuiOperationResultItem -Result $result -PreferredProperties @("Results", "Message", "Success")
        if ($null -eq $item) {
            Append-UiLog $UI "搜索已安装 WebUI 没有返回结果。"
            $status = Get-UiControl $UI "DiscoveryStatusText"
            if ($null -ne $status) { $status.Text = "搜索没有返回结果。" }
            return
        }
        foreach ($attempt in @($item.Attempts)) {
            Write-Log DEBUG "install discovery: $attempt"
        }
        if ([bool](Get-ObjectPropertyValue $item "Cancelled" $false)) {
            Append-UiLog $UI $item.Message
            $partialResults = @($item.Results)
            $status = Get-UiControl $UI "DiscoveryStatusText"
            if ($partialResults.Count -gt 0) {
                $State.DiscoveredInstalls = @($partialResults)
                Refresh-DiscoveredInstallList $UI $State
                if ($null -ne $status) { $status.Text = "搜索已取消，已显示本次中途发现的 $($partialResults.Count) 个结果，未写入配置。" }
            } elseif ($null -ne $status) {
                $status.Text = "搜索已取消，未发现新的安装实例，已保留当前发现列表，未写入配置。"
            }
            return
        }
        $State.DiscoveredInstalls = @($item.Results)
        Refresh-DiscoveredInstallList $UI $State
        Append-UiLog $UI $item.Message
        if (@($item.Results).Count -eq 0) {
            $status = Get-UiControl $UI "DiscoveryStatusText"
            if ($null -ne $status) { $status.Text = "未发现已安装实例。可以选择更靠近安装目录的父目录再搜索一次。" }
        }
    }.GetNewClosure()
    Start-DiscoveryProgressTimer $UI $State
}

function Invoke-DiscoverInstalledWebUisInFolder {
    param($UI, $State)
    $initial = [Environment]::GetFolderPath("UserProfile")
    $key = Get-CurrentProjectKey
    if (-not [string]::IsNullOrWhiteSpace($key)) {
        $project = $script:Projects[$key]
        $config = Get-ProjectConfig $key
        $currentPath = Get-EffectiveInstallPath $project $config
        if (-not [string]::IsNullOrWhiteSpace($currentPath)) {
            if (Test-Path -LiteralPath $currentPath -PathType Container) {
                $initial = $currentPath
            } else {
                $parent = Split-Path -Parent $currentPath
                if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container)) {
                    $initial = $parent
                }
            }
        }
    }
    $selected = Select-FolderPath $initial "选择要扫描的目录"
    if ([string]::IsNullOrWhiteSpace($selected)) { return }
    Invoke-DiscoverInstalledWebUis -UI $UI -State $State -Roots @($selected)
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
    $box.VerticalContentAlignment = "Center"
    $autoSave = $null
    if ($null -ne $State.PSObject.Properties["AutoSaveProjectConfig"]) {
        $autoSave = $State.AutoSaveProjectConfig
    }
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
    if ($null -ne $autoSave) {
        $box.Add_TextChanged({ & $autoSave }.GetNewClosure())
    }
}

function Add-ConfigComboBox {
    param($Panel, $State, [string]$Key, [string]$Label, [System.Collections.IDictionary]$Options, [string]$Value)
    $rowInfo = New-ConfigCardRow $Label
    $combo = New-Object System.Windows.Controls.ComboBox
    $combo.IsEditable = $false
    $autoSave = $null
    if ($null -ne $State.PSObject.Properties["AutoSaveProjectConfig"]) {
        $autoSave = $State.AutoSaveProjectConfig
    }
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
    if ($null -ne $autoSave) {
        $combo.Add_SelectionChanged({ & $autoSave }.GetNewClosure())
    }
}

function Add-ConfigCheckBox {
    param($Panel, $State, [string]$Key, [string]$Label, [bool]$Value)
    $rowInfo = New-ConfigCardRow $Label
    $box = New-Object System.Windows.Controls.CheckBox
    $box.IsChecked = $Value
    $autoSave = $null
    if ($null -ne $State.PSObject.Properties["AutoSaveProjectConfig"]) {
        $autoSave = $State.AutoSaveProjectConfig
    }
    $box.HorizontalAlignment = "Right"
    $box.VerticalAlignment = "Center"
    [System.Windows.Controls.Grid]::SetColumn($box, 1)
    $rowInfo.Grid.Children.Add($box) | Out-Null
    $Panel.Children.Add($rowInfo.Card) | Out-Null
    $State.ConfigControls[$Key] = $box
    if ($null -ne $autoSave) {
        $box.Add_Checked({ & $autoSave }.GetNewClosure())
        $box.Add_Unchecked({ & $autoSave }.GetNewClosure())
    }
}

function Refresh-ScriptParamUi {
    param($UI, $State)
    if ($null -eq $UI.ScriptParamPanel) { return }
    $State.IsRefreshing = $true
    try {
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
    } finally {
        $State.IsRefreshing = $false
    }
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

function Save-CurrentProjectConfigFromUi {
    param($UI, $State, [bool]$RefreshStatus = $true)
    if ($null -ne $State -and $null -ne $State.PSObject.Properties["IsRefreshing"] -and [bool]$State.IsRefreshing) { return }
    $key = Get-CurrentProjectKey
    if ([string]::IsNullOrWhiteSpace($key)) { return }
    Save-ProjectConfig $key (Collect-ProjectAndScriptConfigFromUi $UI $State)
    if ($RefreshStatus) { Refresh-Status $UI $State }
    Write-Log DEBUG "project config auto saved: $key"
}

function Refresh-ProjectConfigUi {
    param($UI, $State)
    $State.IsRefreshing = $true
    try {
    $UI.PathPanel.Children.Clear()
    $UI.ConfigPanel.Children.Clear()
    $State.ConfigControls = @{}
    $key = Get-CurrentProjectKey
    if ([string]::IsNullOrWhiteSpace($key)) {
        $hint = New-Object System.Windows.Controls.TextBlock
        $hint.Text = "请先在左侧「软件选择」中选择要安装或管理的 WebUI / 工具。"
        $hint.TextWrapping = "Wrap"
        $UI.PathPanel.Children.Add($hint) | Out-Null
        $hint = New-Object System.Windows.Controls.TextBlock
        $hint.Text = "请先在左侧「软件选择」中选择要安装或管理的 WebUI / 工具。"
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
    } finally {
        $State.IsRefreshing = $false
    }
}

function Refresh-Status {
    param($UI, $State)
    $projectStatusText = Get-UiControl $UI "ProjectStatusText"
    $selectedProjectHintText = Get-UiControl $UI "SelectedProjectHintText"
    $scriptCombo = Get-UiControl $UI "ScriptCombo"
    $launchScriptList = Get-UiControl $UI "LaunchScriptList"
    $startHintText = Get-UiControl $UI "StartHintText"
    $installHintText = Get-UiControl $UI "InstallHintText"
    $key = Get-CurrentProjectKey
    if ([string]::IsNullOrWhiteSpace($key)) {
        if ($null -ne $projectStatusText) { $projectStatusText.Text = "当前项目: 未选择`n安装状态: 未检测`n下一步: 先到「软件选择」选择要安装或管理的 WebUI / 工具；如果不确定怎么选，可以点击左上角 ? 查看启动器说明。" }
        if ($null -ne $selectedProjectHintText) { $selectedProjectHintText.Text = "当前未选择软件。请先选中一个 WebUI / 工具，启动器才会显示对应的 installer 参数和管理脚本。" }
        if ($null -ne $scriptCombo) { $scriptCombo.ItemsSource = $null }
        if ($null -ne $launchScriptList) { $launchScriptList.ItemsSource = $null }
        if ($null -ne $startHintText) { $startHintText.Text = "还没有选择 WebUI / 工具。请先进入「软件选择」，再回到这里运行安装器或管理脚本。" }
        if ($null -ne $installHintText) { $installHintText.Text = "选择项目后，先确认安装路径和 installer 参数，再运行安装器。启动器会负责下载最新 installer 并传入配置。" }
        Set-OneClickModeFromStatus $UI $State "none"
        return
    }
    $project = $script:Projects[$key]
    $config = Get-ProjectConfig $key
    $status = Get-InstallationStatus $project $config
    $proxyMode = $script:MainConfig["PROXY_MODE"]
    $autoUpdate = $script:MainConfig["AUTO_UPDATE_ENABLED"]
    $nextStep = "先在「安装路径」确认目标目录，再在「安装器设置」确认分支、镜像和代理，然后回到安装模式运行 installer 完成首次安装。"
    if ($status.Code -eq "installed") {
        $nextStep = "已安装完成。请在启动模式运行 launch.ps1 启动 WebUI；如果需要维护，可运行 update.ps1、terminal.ps1 或 version_manager.ps1。WebUI 使用教程可从左上角 ? 打开 SD Note。"
    } elseif ($status.Code -eq "incomplete") {
        $nextStep = "检测到安装目录但缺少管理脚本。请进入安装模式重新运行 installer 修复完整安装。"
    }
    if ($null -ne $projectStatusText) { $projectStatusText.Text = "当前项目: $($project.Name)`n安装状态: $($status.Label)`n$($status.Detail)`n下一步: $nextStep`n代理模式: $proxyMode    自动更新: $autoUpdate" }
    if ($null -ne $selectedProjectHintText) {
        $sameProjectDiscovered = 0
        if ($null -ne $State -and $null -ne $State.PSObject.Properties["DiscoveredInstalls"]) {
            $sameProjectDiscovered = @($State.DiscoveredInstalls | Where-Object { $_.ProjectKey -eq $key }).Count
        }
        $hint = "当前选择：$($project.Name)    管理路径：$($status.Path)    安装状态：$($status.Label)"
        if ($sameProjectDiscovered -gt 1) {
            $hint = "$hint    已发现 $sameProjectDiscovered 个同类型路径，可在「安装路径」页切换。"
        }
        $selectedProjectHintText.Text = $hint
    }
    $scripts = @()
    foreach ($scriptName in $project.Scripts.Keys) {
        $scripts += [LauncherChoice]::new($scriptName, "$scriptName - $($project.Scripts[$scriptName])")
    }
    if ($null -ne $scriptCombo) {
        $scriptCombo.ItemsSource = $scripts
        if ($scripts.Count -gt 0) { $scriptCombo.SelectedIndex = 0 }
    }
    if ($null -ne $launchScriptList) {
        $launchItems = @()
        foreach ($scriptName in $project.Scripts.Keys) {
            $launchItems += [LauncherChoice]::new($scriptName, "$scriptName - $($project.Scripts[$scriptName])")
        }
        $launchScriptList.ItemsSource = $launchItems
        if ($launchItems.Count -gt 0) { $launchScriptList.SelectedIndex = 0 }
    }
    if ($null -ne $startHintText) {
        if ($status.Code -eq "installed") {
            $startHintText.Text = "启动模式会运行安装目录中的管理脚本。通常选择 launch.ps1 启动 WebUI，选择 terminal.ps1 打开交互终端，选择 version_manager.ps1 管理 WebUI / 扩展 / 节点版本。"
        } else {
            $startHintText.Text = "当前项目还未完整安装。请切到安装模式，确认路径和安装器设置后运行 installer。"
        }
    }
    if ($null -ne $installHintText) {
        if ($status.Code -eq "installed") {
            $installHintText.Text = "当前项目已安装。日常启动请用启动模式；只有需要修复环境、重新套用 installer 配置或重新安装时，才建议运行安装器。"
        } elseif ($status.Code -eq "incomplete") {
            $installHintText.Text = "检测到安装目录但缺少管理脚本。建议运行 installer 修复完整安装，修复后再回到启动模式。"
        } else {
            $installHintText.Text = "当前项目未安装。启动器会重新下载最新 installer，并把安装路径、分支、镜像和代理等配置传给它。确认无误后点击右侧按钮开始安装。"
        }
    }
    Set-OneClickModeFromStatus $UI $State $status.Code
}

function Refresh-MainConfigUi {
    param($UI)
    $UI.AutoUpdateCheck.IsChecked = [bool]$script:MainConfig["AUTO_UPDATE_ENABLED"]
    $UI.LogLevelCombo.SelectedItem = $script:MainConfig["LOG_LEVEL"]
    $UI.ProxyModeCombo.SelectedItem = $script:MainConfig["PROXY_MODE"]
    $UI.ManualProxyBox.Text = [string]$script:MainConfig["MANUAL_PROXY"]
}

function Save-MainConfigFromUi {
    param($UI)
    $script:MainConfig["AUTO_UPDATE_ENABLED"] = [bool]$UI.AutoUpdateCheck.IsChecked
    $script:MainConfig["LOG_LEVEL"] = Normalize-LogLevel ([string]$UI.LogLevelCombo.SelectedItem)
    $script:MainConfig["PROXY_MODE"] = Normalize-ProxyMode ([string]$UI.ProxyModeCombo.SelectedItem)
    $script:MainConfig["MANUAL_PROXY"] = $UI.ManualProxyBox.Text
    Save-MainConfig
}

function AutoSave-MainConfigFromUi {
    param($UI, $State)
    $State = Ensure-GuiState $State
    if ([bool](Get-ObjectPropertyValue $State "IsRefreshing" $false) -or [bool](Get-ObjectPropertyValue $State "IsAutoSavingMainConfig" $false)) { return }
    $State.IsAutoSavingMainConfig = $true
    try {
        Save-MainConfigFromUi $UI
        Append-UiLog $UI "启动器设置已自动保存。"
    } finally {
        $State.IsAutoSavingMainConfig = $false
    }
}
