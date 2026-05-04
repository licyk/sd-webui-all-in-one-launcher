# Dialogs and secondary windows.

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

function Show-CountdownConfirmDialog {
    param(
        [string]$Title = "最终确认",
        [string]$Message,
        [string]$ConfirmButtonText = "确认卸载",
        [string]$CancelButtonText = "取消卸载",
        [int]$Seconds = 5
    )
    if ($Seconds -lt 0) { $Seconds = 0 }
    $window = Load-GuiXamlWindow "countdown_confirm.xaml"
    $window.Title = $Title
    $messageText = $window.FindName("MessageText")
    $countdownText = $window.FindName("CountdownText")
    $confirmBtn = $window.FindName("ConfirmBtn")
    $cancelBtn = $window.FindName("CancelBtn")
    $messageText.Text = $Message
    $cancelBtn.Content = $CancelButtonText
    $state = [PSCustomObject]@{
        Remaining = $Seconds
        Result = $false
        ConfirmText = $ConfirmButtonText
        ConfirmButton = $confirmBtn
        CountdownText = $countdownText
        Timer = $null
    }

    $updateCountdown = {
        param($CountdownState)
        if ($CountdownState.Remaining -gt 0) {
            $CountdownState.ConfirmButton.IsEnabled = $false
            $CountdownState.ConfirmButton.Content = "$($CountdownState.ConfirmText) ($($CountdownState.Remaining))"
            $CountdownState.CountdownText.Text = "请等待 $($CountdownState.Remaining) 秒后确认卸载。"
        } else {
            $CountdownState.ConfirmButton.IsEnabled = $true
            $CountdownState.ConfirmButton.Content = $CountdownState.ConfirmText
            $CountdownState.CountdownText.Text = "倒计时结束，可以确认卸载。"
        }
    }.GetNewClosure()

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $state.Timer = $timer
    $timer | Add-Member -NotePropertyName CountdownState -NotePropertyValue $state -Force
    $timer | Add-Member -NotePropertyName UpdateCountdown -NotePropertyValue $updateCountdown -Force
    $timer.Add_Tick({
        param($sender, $eventArgs)
        $timerState = $sender.CountdownState
        $timerState.Remaining = [Math]::Max(0, ([int]$timerState.Remaining - 1))
        & $sender.UpdateCountdown $timerState
        if ($timerState.Remaining -le 0) { $sender.Stop() }
    })

    & $updateCountdown $state
    $confirmBtn.Tag = $state
    $cancelBtn.Tag = $state
    $confirmBtn.Add_Click({
        param($sender, $eventArgs)
        $dialogState = $sender.Tag
        if (-not $dialogState.ConfirmButton.IsEnabled) { return }
        $dialogState.Result = $true
        $dialogWindow = [System.Windows.Window]::GetWindow($sender)
        $dialogWindow.DialogResult = $true
        $dialogWindow.Close()
    })
    $cancelBtn.Add_Click({
        param($sender, $eventArgs)
        $dialogState = $sender.Tag
        $dialogState.Result = $false
        $dialogWindow = [System.Windows.Window]::GetWindow($sender)
        $dialogWindow.DialogResult = $false
        $dialogWindow.Close()
    })
    $window.Tag = $state
    $window.Add_Closed({
        param($sender, $eventArgs)
        $dialogState = $sender.Tag
        if ($null -ne $dialogState -and $null -ne $dialogState.Timer -and $dialogState.Timer.IsEnabled) {
            $dialogState.Timer.Stop()
        }
    })
    if ($Seconds -gt 0) { $timer.Start() }
    $null = $window.ShowDialog()
    return [bool]$state.Result
}

function Get-UserAgreementText {
@"
使用该软件代表您已阅读并同意以下用户协议：
您不得实施包括但不限于以下行为，也不得为任何违反法律法规的行为提供便利：
    反对宪法所规定的基本原则的。
    危害国家安全，泄露国家秘密，颠覆国家政权，破坏国家统一的。
    损害国家荣誉和利益的。
    煽动民族仇恨、民族歧视，破坏民族团结的。
    破坏国家宗教政策，宣扬邪教和封建迷信的。
    散布谣言，扰乱社会秩序，破坏社会稳定的。
    散布淫秽、色情、赌博、暴力、凶杀、恐怖或教唆犯罪的。
    侮辱或诽谤他人，侵害他人合法权益的。
    实施任何违背“七条底线”的行为。
    含有法律、行政法规禁止的其他内容的。
因您的数据的产生、收集、处理、使用等任何相关事项存在违反法律法规等情况而造成的全部结果及责任均由您自行承担。
"@
}

function Show-UserAgreementDialog {
    $window = Load-GuiXamlWindow "user_agreement.xaml"
    $window.FindName("AgreementText").Text = Get-UserAgreementText
    $window.FindName("AgreeBtn").Add_Click({ $window.DialogResult = $true; $window.Close() }.GetNewClosure())
    $window.FindName("DeclineBtn").Add_Click({ $window.DialogResult = $false; $window.Close() }.GetNewClosure())
    $result = $window.ShowDialog()
    return $result -eq $true
}

function Show-InputDialog {
    param([string]$Title, [string]$Message, [string]$DefaultText = "")
    $window = Load-GuiXamlWindow "input_dialog.xaml"
    $window.Title = $Title
    $window.FindName("MessageText").Text = $Message
    $box = $window.FindName("InputBox")
    $box.Text = $DefaultText
    $result = $null
    $inputDialogResult = $null
    $window.FindName("OkBtn").Add_Click({ $inputDialogResult = $box.Text; $window.DialogResult = $true; $window.Close() }.GetNewClosure())
    $window.FindName("CancelBtn").Add_Click({ $inputDialogResult = $null; $window.DialogResult = $false; $window.Close() }.GetNewClosure())
    if ($window.ShowDialog()) { $result = $inputDialogResult }
    return $result
}

function Show-HelpWindow {
    $window = Load-GuiXamlWindow "help_window.xaml"
    $launcherDocVar = Get-Variable -Name LAUNCHER_GUI_DOC_URL -Scope Script -ErrorAction SilentlyContinue
    $launcherDocUrl = ""
    if ($null -ne $launcherDocVar) { $launcherDocUrl = [string]$launcherDocVar.Value }
    if ([string]::IsNullOrWhiteSpace($launcherDocUrl)) {
        $launcherDocUrl = "https://licyk.github.io/sd-webui-all-in-one/tools/launcher-gui"
    }
    $sdNoteVar = Get-Variable -Name SDNOTE_URL -Scope Script -ErrorAction SilentlyContinue
    $sdNoteUrl = ""
    if ($null -ne $sdNoteVar) { $sdNoteUrl = [string]$sdNoteVar.Value }
    if ([string]::IsNullOrWhiteSpace($sdNoteUrl)) {
        $sdNoteUrl = "https://licyk.github.io/SDNote"
    }
    $openLauncherDocBtn = $window.FindName("OpenLauncherDocBtn")
    $openLauncherDocBtn.Tag = $launcherDocUrl
    $openLauncherDocBtn.Add_Click({
        param($sender, $eventArgs)
        Invoke-OpenTaggedUrl $sender
    })
    $openSdNoteBtn = $window.FindName("OpenSdNoteBtn")
    $openSdNoteBtn.Tag = $sdNoteUrl
    $openSdNoteBtn.Add_Click({
        param($sender, $eventArgs)
        Invoke-OpenTaggedUrl $sender
    })
    $window.FindName("CloseBtn").Add_Click({
        $window.Close()
    }.GetNewClosure())
    $window.ShowDialog() | Out-Null
}

function Show-LogWindow {
    if (-not (Test-Path $script:LogFile)) {
        Show-Message "还没有日志文件: $($script:LogFile)" "日志"
        return
    }
    $content = (Get-Content -LiteralPath $script:LogFile -Encoding UTF8) -join [Environment]::NewLine
    $window = Load-GuiXamlWindow "log_window.xaml"
    $window.FindName("LogText").Text = $content
    $window.FindName("CloseBtn").Add_Click({ $window.Close() }.GetNewClosure())
    $window.ShowDialog() | Out-Null
}
