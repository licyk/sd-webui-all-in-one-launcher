# Runtime operations, process management, update, uninstall.

function Get-UpdateCheckSemaphore {
    if ($null -eq (Get-Variable -Name InstallerLauncherGuiUpdateCheckSemaphore -Scope Global -ErrorAction SilentlyContinue)) {
        $global:InstallerLauncherGuiUpdateCheckSemaphore = [System.Threading.SemaphoreSlim]::new(1, 1)
    }
    return (Get-Variable -Name InstallerLauncherGuiUpdateCheckSemaphore -Scope Global -ErrorAction Stop).Value
}

function Release-UpdateCheckLock {
    try {
        $semaphore = Get-UpdateCheckSemaphore
        if ($null -ne $semaphore) {
            [void]$semaphore.Release()
            Write-Log DEBUG "update check lock released"
        }
    } catch [System.Threading.SemaphoreFullException] {
        Write-Log WARN "update check lock release ignored: semaphore already full"
    } catch {
        Write-Log WARN "update check lock release failed: $($_.Exception.Message)"
    }
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
            Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $temp -TimeoutSec 15 -ErrorAction Stop
            Move-Item -LiteralPath $temp -Destination $OutputPath -Force
            return [PSCustomObject]@{ Success = $true; Url = $url; Errors = @($errors) }
        } catch {
            Remove-Item -LiteralPath "$OutputPath.tmp" -Force -ErrorAction SilentlyContinue
            $errors.Add("$url -> $($_.Exception.Message)")
        }
    }
    return [PSCustomObject]@{ Success = $false; Url = ""; Errors = @($errors) }
}

function Invoke-DownloadUrlToPath {
    param(
        [string]$Url,
        [string]$OutputPath,
        $Attempts,
        [hashtable]$Headers = $null
    )
    try {
        if ($null -ne $Attempts) { [void]$Attempts.Add("TRY url=$Url path=$OutputPath") }
        if ($null -eq $Headers) {
            Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $OutputPath -TimeoutSec 15 -ErrorAction Stop
        } else {
            Invoke-WebRequest -UseBasicParsing -Uri $Url -Headers $Headers -OutFile $OutputPath -TimeoutSec 15 -ErrorAction Stop
        }
        if ($null -ne $Attempts) {
            [void]$Attempts.Add("DOWNLOADED url=$Url path=$OutputPath exists=$([bool](Test-Path -LiteralPath $OutputPath -PathType Leaf))")
        }
        return [PSCustomObject]@{ Success = $true; Url = $Url; Path = $OutputPath; Error = "" }
    } catch {
        $message = $_.Exception.Message
        Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue
        if ($null -ne $Attempts) { [void]$Attempts.Add("FAIL $Url $message") }
        return [PSCustomObject]@{ Success = $false; Url = $Url; Path = $OutputPath; Error = $message }
    }
}

function Get-LauncherChildProcessIds {
    param([int]$RootPid)
    $children = @()
    try {
        $items = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$RootPid" -ErrorAction Stop)
    } catch {
        try {
            $items = @(Get-WmiObject Win32_Process -Filter "ParentProcessId=$RootPid" -ErrorAction Stop)
        } catch {
            return @()
        }
    }
    foreach ($item in $items) {
        $childPid = [int]$item.ProcessId
        $children += $childPid
        $children += @(Get-LauncherChildProcessIds -RootPid $childPid)
    }
    return @($children)
}

function Stop-LauncherProcessTree {
    param([int]$RootPid)
    $errors = New-Object System.Collections.Generic.List[string]
    if ($RootPid -le 0) { return @("无有效进程 PID。") }
    $ids = @(Get-LauncherChildProcessIds -RootPid $RootPid)
    [array]::Reverse($ids)
    $ids += $RootPid
    foreach ($processId in ($ids | Select-Object -Unique)) {
        try {
            $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
            if ($null -ne $process) {
                Stop-Process -Id $processId -Force -ErrorAction Stop
                Write-Log INFO "terminated process pid=$processId root=$RootPid"
            } else {
                Write-Log DEBUG "process already exited pid=$processId root=$RootPid"
            }
        } catch {
            if ($null -eq (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
                Write-Log INFO "process already exited during termination pid=$processId root=$RootPid"
                continue
            }
            $errors.Add("pid=${processId}: $($_.Exception.Message)")
            Write-Log WARN "failed to terminate process pid=$processId root=$RootPid error=$($_.Exception.Message)"
        }
    }
    return @($errors)
}

function Get-WorkerChildProcessIds {
    param([int]$RootPid)
    $children = @()
    try {
        $items = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$RootPid" -ErrorAction Stop)
    } catch {
        try {
            $items = @(Get-WmiObject Win32_Process -Filter "ParentProcessId=$RootPid" -ErrorAction Stop)
        } catch {
            return @()
        }
    }
    foreach ($item in $items) {
        $childPid = [int]$item.ProcessId
        $children += $childPid
        $children += @(Get-WorkerChildProcessIds -RootPid $childPid)
    }
    return @($children)
}

function Stop-WorkerProcessTree {
    param([int]$RootPid)
    $errors = New-Object System.Collections.Generic.List[string]
    if ($RootPid -le 0) { return @("无有效进程 PID。") }
    $ids = @(Get-WorkerChildProcessIds -RootPid $RootPid)
    [array]::Reverse($ids)
    $ids += $RootPid
    foreach ($processId in ($ids | Select-Object -Unique)) {
        try {
            $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
            if ($null -ne $process) { Stop-Process -Id $processId -Force -ErrorAction Stop }
        } catch {
            if ($null -eq (Get-Process -Id $processId -ErrorAction SilentlyContinue)) { continue }
            $errors.Add("pid=${processId}: $($_.Exception.Message)")
        }
    }
    return @($errors)
}

function Invoke-TrackedPowerShellScript {
    param(
        [string]$ScriptPath,
        [string]$ScriptArgsText,
        [string]$DisplayName,
        [hashtable]$Control
    )
    $command = Resolve-PowerShellCommand
    if ([string]::IsNullOrWhiteSpace($command)) {
        return [PSCustomObject]@{ Success = $false; ExitCode = 127; Message = "未找到 pwsh 或 powershell"; ProcessArgs = ""; ScriptArgsText = $ScriptArgsText; ScriptName = $DisplayName; ScriptPath = $ScriptPath; ProcessId = 0; Terminated = $false; TerminationErrors = "" }
    }

    $wrapper = New-ConsoleWrapperScript
    $argsTextPath = ""
    try {
        if (-not [string]::IsNullOrWhiteSpace($ScriptArgsText)) {
            $argsTextPath = Join-Path $env:TEMP ("installer-launcher-args-{0}.txt" -f ([guid]::NewGuid().ToString("N")))
            Set-Content -LiteralPath $argsTextPath -Encoding UTF8 -Value $ScriptArgsText
        }
        $baseExpression = "& " + (Join-Shlex @($command, "-NoLogo", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath))
        $argumentList = @("-NoLogo", "-ExecutionPolicy", "Bypass", "-File", $wrapper, "-ScriptPath", $ScriptPath)
        if (-not [string]::IsNullOrWhiteSpace($argsTextPath)) {
            $argumentList += "-ArgsTextPath"
            $argumentList += $argsTextPath
        }
        $argumentList += "-BaseExpression"
        $argumentList += $baseExpression
        $argumentLine = Join-ProcessArguments ([string[]]$argumentList)
        $process = Start-Process -FilePath $command -ArgumentList $argumentLine -PassThru -WindowStyle Normal
        $Control["ProcessId"] = [int]$process.Id
        $Control["ScriptPath"] = $ScriptPath
        $Control["StartedAt"] = (Get-Date).ToString("s")

        $terminated = $false
        $terminationErrors = @()
        while (-not $process.HasExited) {
            if ([bool]$Control["StopRequested"]) {
                $Control["IsTerminating"] = $true
                $terminated = $true
                $terminationErrors = @(Stop-WorkerProcessTree -RootPid ([int]$process.Id))
                break
            }
            Start-Sleep -Milliseconds 250
            try { $process.Refresh() } catch {}
        }
        if ([bool]$Control["StopRequested"]) { $terminated = $true }
        if (-not $process.HasExited) {
            try { Wait-Process -Id $process.Id -Timeout 5 -ErrorAction SilentlyContinue } catch {}
            try { $process.Refresh() } catch {}
        }
        if ($terminated) {
            $exitCode = 130
        } elseif ($process.HasExited) {
            $exitCode = $process.ExitCode
        } else {
            $exitCode = 1
        }
        return [PSCustomObject]@{ Success = ($exitCode -eq 0); ExitCode = $exitCode; Message = "$DisplayName 执行完成"; ProcessArgs = $argumentLine; ScriptArgsText = $ScriptArgsText; ScriptName = $DisplayName; ScriptPath = $ScriptPath; ProcessId = $Control["ProcessId"]; Terminated = $terminated; TerminationErrors = ($terminationErrors -join "`n") }
    } finally {
        Remove-Item -LiteralPath $wrapper -Force -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($argsTextPath)) {
            Remove-Item -LiteralPath $argsTextPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-RuntimeWorkerPrelude {
    $functionNames = @(
        "Join-Shlex",
        "Resolve-PowerShellCommand",
        "New-ConsoleWrapperScript",
        "Quote-ProcessArgument",
        "Join-ProcessArguments",
        "Invoke-DownloadWithRetry",
        "Invoke-DownloadUrlToPath",
        "Get-WorkerChildProcessIds",
        "Stop-WorkerProcessTree",
        "Invoke-TrackedPowerShellScript"
    )
    $chunks = New-Object System.Collections.Generic.List[string]
    foreach ($name in $functionNames) {
        $command = Get-Command $name -CommandType Function -ErrorAction Stop
        $chunks.Add("function $name {`n$($command.ScriptBlock.ToString())`n}")
    }
    return ($chunks -join "`n`n")
}

function Write-TrackedScriptResultDebug {
    param([string]$Kind, $Item)
    if ($null -eq $Item) { return }
    Write-Log DEBUG "$Kind process args: $($Item.ProcessArgs)"
    Write-Log DEBUG "$Kind script args text: $($Item.ScriptArgsText)"
}

function Handle-TrackedScriptTermination {
    param($UI, $Item, [string]$LogKind, [string]$DisplayName)
    if (-not [bool](Get-ObjectPropertyValue $Item "Terminated" $false)) { return $false }
    $processId = Get-ObjectPropertyValue $Item "ProcessId" 0
    $itemScriptPath = [string](Get-ObjectPropertyValue $Item "ScriptPath" "")
    $terminationErrors = [string](Get-ObjectPropertyValue $Item "TerminationErrors" "")
    Write-Log INFO "$LogKind terminated by user pid=$processId script=$DisplayName path=$itemScriptPath"
    Append-UiLog $UI "$DisplayName 已被用户终止。pid=$processId"
    if (-not [string]::IsNullOrWhiteSpace($terminationErrors)) {
        Show-Message "$DisplayName 已终止，但部分进程可能需要手动关闭。`n`n$terminationErrors" "已终止" "Warning"
    }
    return $true
}

function Select-GuiOperationResultItem {
    param($Result, [string[]]$PreferredProperties = @())
    $items = @($Result)
    foreach ($item in $items) {
        if ($null -eq $item) { continue }
        foreach ($propertyName in @($PreferredProperties)) {
            if ($item.PSObject.Properties[$propertyName]) { return $item }
        }
    }
    foreach ($item in $items) {
        if ($null -ne $item) { return $item }
    }
    return $null
}

function New-OperationControl {
    param([string]$Name)
    return [hashtable]::Synchronized(@{
        Name = $Name
        StopRequested = $false
        IsTerminating = $false
        ProcessId = 0
        ScriptPath = ""
        StartedAt = ""
    })
}

function Start-GuiOperation {
    param(
        $UI,
        $State,
        [string]$Name,
        [scriptblock]$ScriptBlock,
        [object[]]$Arguments,
        [scriptblock]$OnComplete,
        [bool]$CanTerminate = $true
    )
    $State = Ensure-GuiState $State
    if ($null -ne (Get-ObjectPropertyValue $State "CurrentOperation" $null)) {
        Show-Message "已有任务正在运行，请等待当前任务完成。" "任务运行中" "Warning"
        return
    }
    $control = New-OperationControl -Name $Name
    $control["CanTerminate"] = $CanTerminate
    $busyMessage = "$Name 正在运行..."
    if ($CanTerminate) { $busyMessage = "$Name 正在运行，可点击终止当前任务。" }
    Set-UiBusy -UI $UI -Busy $true -Message $busyMessage -CanTerminate $CanTerminate
    $ps = [powershell]::Create()
    $ps.RunspacePool = $script:RunspacePool
    $workerPrelude = Get-RuntimeWorkerPrelude
    $operationBody = $ScriptBlock.ToString()
    $operationScript = @"
$workerPrelude

`$__InstallerLauncherOperation = {
$operationBody
}
& `$__InstallerLauncherOperation @args
"@
    [void]$ps.AddScript($operationScript)
    foreach ($arg in $Arguments) { [void]$ps.AddArgument($arg) }
    [void]$ps.AddArgument($control)
    $async = $ps.BeginInvoke()
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(250)
    $State.CurrentOperation = [PSCustomObject]@{ PowerShell = $ps; Async = $async; Timer = $timer; Name = $Name; Control = $control; LoggedProcessId = 0 }
    $timer.Add_Tick({
        if (-not $async.IsCompleted) {
            $currentProcessId = [int]$control["ProcessId"]
            if ($currentProcessId -gt 0 -and $null -ne $State.CurrentOperation -and [int]$State.CurrentOperation.LoggedProcessId -ne $currentProcessId) {
                $State.CurrentOperation.LoggedProcessId = $currentProcessId
                $currentScriptPath = [string]$control["ScriptPath"]
                Write-Log INFO "$Name external process started pid=$currentProcessId script=$currentScriptPath"
                Append-UiLog -UI $UI -Text "$Name 已打开 PowerShell 控制台。pid=$currentProcessId"
            }
            return
        }
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

function Invoke-TerminateCurrentOperation {
    param($UI, $State)
    $State = Ensure-GuiState $State
    if ($null -eq $State.CurrentOperation) {
        Show-Message "当前没有正在运行的任务。" "无需终止" "Information"
        return
    }
    $control = $State.CurrentOperation.Control
    if (-not [bool]$control["CanTerminate"]) {
        Show-Message "当前任务不支持从这里终止。" "无法终止" "Information"
        return
    }
    $name = [string]$control["Name"]
    $scriptPath = [string]$control["ScriptPath"]
    $processId = [int]$control["ProcessId"]
    if ([string]::IsNullOrWhiteSpace($name)) { $name = [string]$State.CurrentOperation.Name }
    $message = "即将终止当前任务。`n`n任务: $name`n脚本: $scriptPath`nPID: $processId`n`n这只会终止当前启动器记录的任务进程树。"
    if (-not (Confirm-Message $message "确认终止当前任务")) { return }
    $control["StopRequested"] = $true
    $control["IsTerminating"] = $true
    Set-UiBusy -UI $UI -Busy $true -Message "$name 正在终止..." -CanTerminate $true
    Append-UiLog $UI "正在终止当前任务: $name pid=$processId"
    if ($processId -le 0) {
        Append-UiLog $UI "任务进程尚未创建，已记录终止请求。"
        return
    }
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        Append-UiLog $UI "任务进程已结束。"
        return
    }
    $errors = @(Stop-LauncherProcessTree -RootPid $processId)
    if ($errors.Count -gt 0) {
        Append-UiLog $UI "部分进程终止失败，请手动关闭残留控制台。$($errors -join '; ')"
        Show-Message "部分进程终止失败，请手动关闭残留控制台。`n`n$($errors -join [Environment]::NewLine)" "终止未完全成功" "Warning"
    } else {
        Append-UiLog $UI "已发送终止请求。"
    }
}

function ConvertTo-SingleQuotedLiteral {
    param([string]$Value)
    return "'{0}'" -f (($Value -replace "'", "''"))
}

function Register-LauncherUninstallEntry {
    try {
        $selfPath = $script:EntryScriptPath
        if ([string]::IsNullOrWhiteSpace($selfPath) -or -not (Test-Path -LiteralPath $selfPath -PathType Leaf)) { return }
        $launcherPath = (Get-Process -Id $PID).Path
        $uninstallCommand = '"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" -UninstallLauncher' -f $launcherPath, $selfPath
        New-Item -Path $script:UninstallRegistryKey -Force | Out-Null
        New-ItemProperty -Path $script:UninstallRegistryKey -Name "DisplayName" -Value "SD WebUI All In One Launcher" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $script:UninstallRegistryKey -Name "DisplayVersion" -Value $script:INSTALLER_LAUNCHER_GUI_VERSION -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $script:UninstallRegistryKey -Name "Publisher" -Value "licyk" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $script:UninstallRegistryKey -Name "InstallLocation" -Value (Split-Path -Parent $selfPath) -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $script:UninstallRegistryKey -Name "DisplayIcon" -Value $script:ShortcutIconFile -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $script:UninstallRegistryKey -Name "UninstallString" -Value $uninstallCommand -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $script:UninstallRegistryKey -Name "NoModify" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $script:UninstallRegistryKey -Name "NoRepair" -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Log DEBUG "registered launcher uninstall entry: $script:UninstallRegistryKey"
    } catch {
        Write-Log WARN "failed to register launcher uninstall entry: $($_.Exception.Message)"
    }
}

function Start-LauncherUninstallWorker {
    param([string]$SelfPath, [int]$ParentPid)
    $tempScript = Join-Path $env:TEMP ("installer-launcher-uninstall-{0}.ps1" -f ([guid]::NewGuid().ToString("N")))
    $shortcutName = "SD WebUI All In One Launcher.lnk"
    $scriptContent = @"
`$ErrorActionPreference = 'SilentlyContinue'
Start-Sleep -Milliseconds 500
`$parentPid = $ParentPid
if (`$parentPid -gt 0) {
    try {
        `$parent = Get-Process -Id `$parentPid -ErrorAction SilentlyContinue
        if (`$null -ne `$parent) {
            `$parent.WaitForExit(3000) | Out-Null
            `$parent = Get-Process -Id `$parentPid -ErrorAction SilentlyContinue
            if (`$null -ne `$parent) {
                Stop-Process -Id `$parentPid -Force -ErrorAction SilentlyContinue
                for (`$wait = 0; `$wait -lt 20; `$wait++) {
                    if (`$null -eq (Get-Process -Id `$parentPid -ErrorAction SilentlyContinue)) { break }
                    Start-Sleep -Milliseconds 250
                }
            }
        }
    } catch {}
}
`$selfPath = $(ConvertTo-SingleQuotedLiteral $SelfPath)
`$configHome = $(ConvertTo-SingleQuotedLiteral $script:ConfigHome)
`$localHome = $(ConvertTo-SingleQuotedLiteral $script:LocalHome)
`$registryKey = $(ConvertTo-SingleQuotedLiteral $script:UninstallRegistryKey)
`$shortcutName = $(ConvertTo-SingleQuotedLiteral $shortcutName)
`$desktop = [System.Environment]::GetFolderPath('Desktop')
`$programs = Join-Path ([System.Environment]::GetFolderPath('ApplicationData')) 'Microsoft\Windows\Start Menu\Programs'

function Remove-LauncherPath {
    param([string]`$Path, [switch]`$Recurse)
    if ([string]::IsNullOrWhiteSpace(`$Path) -or -not (Test-Path -LiteralPath `$Path)) { return `$true }
    try {
        if (`$Recurse) {
            Remove-Item -LiteralPath `$Path -Recurse -Force -ErrorAction Stop
        } else {
            Remove-Item -LiteralPath `$Path -Force -ErrorAction Stop
        }
        return -not (Test-Path -LiteralPath `$Path)
    } catch {
        return `$false
    }
}
for (`$i = 0; `$i -lt 30; `$i++) {
    foreach (`$shortcutPath in @((Join-Path `$desktop `$shortcutName), (Join-Path `$programs `$shortcutName))) {
        Remove-LauncherPath -Path `$shortcutPath | Out-Null
    }
    Remove-LauncherPath -Path `$registryKey -Recurse | Out-Null
    Remove-LauncherPath -Path `$selfPath | Out-Null
    Remove-LauncherPath -Path `$localHome -Recurse | Out-Null
    Remove-LauncherPath -Path `$configHome -Recurse | Out-Null
    if ((-not (Test-Path -LiteralPath `$configHome)) -and (-not (Test-Path -LiteralPath `$localHome)) -and (-not (Test-Path -LiteralPath `$selfPath))) {
        break
    }
    Start-Sleep -Milliseconds 500
}
try {
    Add-Type -AssemblyName PresentationFramework
    `$remainingPaths = New-Object System.Collections.Generic.List[string]
    foreach (`$checkPath in @(`$selfPath, `$configHome, `$localHome)) {
        if (-not [string]::IsNullOrWhiteSpace(`$checkPath) -and (Test-Path -LiteralPath `$checkPath)) {
            `$remainingPaths.Add(`$checkPath) | Out-Null
        }
    }
    if (`$remainingPaths.Count -eq 0) {
        [System.Windows.MessageBox]::Show('SD WebUI All In One Launcher 已卸载。', '卸载完成', 'OK', 'Information') | Out-Null
    } else {
        [System.Windows.MessageBox]::Show(("卸载已执行，但以下路径仍未能删除:`n`n{0}`n`n请确认没有启动器进程仍在运行后手动删除。" -f (`$remainingPaths -join "`n")), '卸载未完全完成', 'OK', 'Warning') | Out-Null
    }
} catch {}
Remove-Item -LiteralPath `$PSCommandPath -Force
"@
    Set-Content -LiteralPath $tempScript -Encoding UTF8 -Value $scriptContent
    $launcherPath = (Get-Process -Id $PID).Path
    $cmdArgs = "/d /c start `"`" /min `"$launcherPath`" -NoProfile -ExecutionPolicy Bypass -File `"$tempScript`""
    Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArgs -WindowStyle Hidden | Out-Null
}

function Invoke-UninstallLauncher {
    param($UI = $null)
    $selfPath = $script:EntryScriptPath
    if ([string]::IsNullOrWhiteSpace($selfPath) -or -not (Test-Path -LiteralPath $selfPath -PathType Leaf)) {
        Show-Message "无法确定当前 GUI 脚本路径，不能卸载启动器。" "卸载启动器" "Error"
        return
    }
    $warning = "即将卸载 SD WebUI All In One Launcher。`n`n将删除:`n- 桌面和开始菜单快捷方式`n- 当前 GUI 脚本: $selfPath`n- 配置目录: $script:ConfigHome`n- 日志/缓存目录: $script:LocalHome`n- 控制面板卸载注册项`n`n此操作不可撤销。"
    if (-not (Confirm-Message $warning "卸载启动器")) { return }
    $countdownMessage = "即将卸载启动器并删除配置、日志、缓存、快捷方式和卸载注册项。`n`n目标脚本: $selfPath`n配置目录: $script:ConfigHome`n日志/缓存目录: $script:LocalHome"
    if (-not (Show-CountdownConfirmDialog -Title "最终确认" -Message $countdownMessage -Seconds 5)) {
        if ($null -ne $UI) { Append-UiLog $UI "启动器卸载最终确认取消。" }
        Write-Log INFO "launcher uninstall canceled at countdown confirmation"
        return
    }
    Write-Log INFO "launcher uninstall requested self=$selfPath config=$script:ConfigHome local=$script:LocalHome"
    if ($null -ne $UI) { Append-UiLog $UI "启动器卸载已确认，正在退出并执行删除。" }
    Start-LauncherUninstallWorker -SelfPath $selfPath -ParentPid $PID
    [System.Environment]::Exit(0)
}

function Invoke-CreateLauncherShortcut {
    param($UI, $State)
    $selfPath = $script:EntryScriptPath
    if ([string]::IsNullOrWhiteSpace($selfPath) -or -not (Test-Path -LiteralPath $selfPath -PathType Leaf)) {
        Show-Message "无法确定当前 GUI 脚本路径，不能创建快捷方式。" "创建快捷方式" "Error"
        return
    }
    $launcherPath = (Get-Process -Id $PID).Path
    $iconUrlPayload = ConvertTo-Json -Compress -InputObject ([string[]]$script:SHORTCUT_ICON_URLS)
    $operation = {
        param([string]$IconUrlPayload, [string]$IconPath, [string]$SelfPath, [string]$LauncherPath, [string]$ShortcutName, $Control)
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

        function Add-WindowsShortcut {
            param([string]$Name, [string]$IconPath, [string]$TargetPath, [string]$ScriptPath)
            $shell = New-Object -ComObject WScript.Shell
            $desktop = [System.Environment]::GetFolderPath("Desktop")
            $programs = Join-Path ([System.Environment]::GetFolderPath("ApplicationData")) "Microsoft\Windows\Start Menu\Programs"
            New-Item -ItemType Directory -Force -Path $desktop, $programs | Out-Null
            $desktopShortcut = Join-Path $desktop "$Name.lnk"
            $programsShortcut = Join-Path $programs "$Name.lnk"
            foreach ($shortcutPath in @($desktopShortcut, $programsShortcut)) {
                $shortcut = $shell.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = $TargetPath
                $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
                $shortcut.WorkingDirectory = Split-Path -Parent $ScriptPath
                $shortcut.IconLocation = $IconPath
                $shortcut.Save()
            }
            return @($desktopShortcut, $programsShortcut)
        }

        $attempts = New-Object System.Collections.ArrayList
        if (-not (Test-IconFile $IconPath)) {
            $urls = @()
            try {
                $parsedUrls = ConvertFrom-Json -InputObject $IconUrlPayload -ErrorAction Stop
                $urls = @($parsedUrls | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            } catch {
                return [PSCustomObject]@{ Success = $false; Message = "图标下载源解析失败: $($_.Exception.Message)"; Attempts = @($attempts.ToArray()); Paths = @() }
            }
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $IconPath) | Out-Null
            foreach ($url in $urls) {
                $temp = "$IconPath.tmp"
                $headers = @{ "User-Agent" = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36" }
                $download = Invoke-DownloadUrlToPath -Url $url -OutputPath $temp -Headers $headers -Attempts $attempts
                if (-not $download.Success) { continue }
                try {
                    if (-not (Test-IconFile $temp)) { throw "下载的文件不是有效 icon" }
                    Move-Item -LiteralPath $temp -Destination $IconPath -Force
                    [void]$attempts.Add("OK $url")
                    break
                } catch {
                    Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
                    [void]$attempts.Add("FAIL $url $($_.Exception.Message)")
                }
            }
        } else {
            [void]$attempts.Add("OK cached icon $IconPath")
        }

        if (-not (Test-IconFile $IconPath)) {
            return [PSCustomObject]@{ Success = $false; Message = "快捷方式图标下载失败，未创建快捷方式。"; Attempts = @($attempts.ToArray()); Paths = @() }
        }

        try {
            $paths = Add-WindowsShortcut -Name $ShortcutName -IconPath $IconPath -TargetPath $LauncherPath -ScriptPath $SelfPath
            return [PSCustomObject]@{ Success = $true; Message = "快捷方式已创建。"; Attempts = @($attempts.ToArray()); Paths = @($paths) }
        } catch {
            return [PSCustomObject]@{ Success = $false; Message = "创建快捷方式失败: $($_.Exception.Message)"; Attempts = @($attempts.ToArray()); Paths = @() }
        }
    }
    Start-GuiOperation -UI $UI -State $State -Name "创建快捷方式" -ScriptBlock $operation -Arguments @($iconUrlPayload, $script:ShortcutIconFile, $selfPath, $launcherPath, "SD WebUI All In One Launcher") -CanTerminate $false -OnComplete {
        param($result, $streamErrors)
        $item = Select-GuiOperationResultItem -Result $result -PreferredProperties @("Paths", "Message")
        if ($null -eq $item) {
            Append-UiLog $UI "创建快捷方式没有返回结果。"
            Show-Message "创建快捷方式没有返回结果。" "创建快捷方式" "Warning"
            return
        }
        foreach ($attempt in @($item.Attempts)) {
            Write-Log DEBUG "shortcut icon attempt: $attempt"
        }
        if ($item.Success) {
            $paths = @($item.Paths) -join [Environment]::NewLine
            Append-UiLog $UI "快捷方式已创建: $paths"
            Show-Message "$($item.Message)`n`n$paths" "创建快捷方式"
        } else {
            Append-UiLog $UI $item.Message
            Show-Message $item.Message "创建快捷方式" "Error"
        }
    }.GetNewClosure()
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
        param($Project, $Config, [string]$InstallerArgsText, [string]$OutputPath, [hashtable]$Control)
        $download = Invoke-DownloadWithRetry -Urls ([string[]]$Project.InstallerUrls) -OutputPath $OutputPath
        if (-not $download.Success) {
            return [PSCustomObject]@{ Success = $false; Stage = "download"; ExitCode = 1; Message = "安装器下载失败"; Detail = ($download.Errors -join "`n") }
        }
        $result = Invoke-TrackedPowerShellScript -ScriptPath $OutputPath -ScriptArgsText $InstallerArgsText -DisplayName "安装器" -Control $Control
        $stage = "execute"
        if ([int]$result.ExitCode -eq 127) { $stage = "powershell" }
        $result | Add-Member -NotePropertyName Stage -NotePropertyValue $stage -Force
        $result | Add-Member -NotePropertyName Detail -NotePropertyValue "下载源: $($download.Url)" -Force
        return $result
    }
    Start-GuiOperation -UI $UI -State $State -Name "运行安装器" -ScriptBlock $operation -Arguments @($project, $config, $argsText, $scriptPath) -OnComplete {
        param($result, $streamErrors)
        $item = Select-GuiOperationResultItem -Result $result -PreferredProperties @("ProcessArgs", "ExitCode", "Success")
        if ($null -eq $item) { Show-Message "安装任务没有返回结果。" "错误" "Error"; return }
        if (Handle-TrackedScriptTermination -UI $UI -Item $item -LogKind "installer process" -DisplayName "安装器") {
        } elseif ($item.Success) {
            Write-TrackedScriptResultDebug -Kind "installer" -Item $item
            Append-UiLog $UI "安装器执行成功。$($item.Detail)"
            Show-Message "安装器执行成功。`n$($item.Detail)" "完成"
        } else {
            Write-TrackedScriptResultDebug -Kind "installer" -Item $item
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
    if ($null -eq $config["ScriptArgs"]) { $config["ScriptArgs"] = @{} }
    $config["ScriptArgs"][$scriptName] = $UI.ScriptArgsBox.Text
    Save-ScriptParamUi $UI $State $config
    Save-ProjectConfig $key $config
    $scriptArgs = @(Build-ManagementScriptArgs $key $scriptName $config)
    if ($null -eq $scriptArgs -or $scriptArgs.Count -eq 0) { $scriptArgsText = "" } else { $scriptArgsText = Join-Shlex $scriptArgs }
    Write-Log DEBUG "management script args prepared: project=$key script=$scriptName path=$scriptPath args=$(Format-LogArgs $scriptArgs) args_text=$scriptArgsText"
    $operation = {
        param([string]$ScriptPath, [string]$ScriptArgsText, [string]$DisplayScriptName, [hashtable]$Control)
        return (Invoke-TrackedPowerShellScript -ScriptPath $ScriptPath -ScriptArgsText $ScriptArgsText -DisplayName $DisplayScriptName -Control $Control)
    }
    Start-GuiOperation -UI $UI -State $State -Name "运行管理脚本" -ScriptBlock $operation -Arguments @($scriptPath, $scriptArgsText, $scriptName) -OnComplete {
        param($result, $streamErrors)
        $item = Select-GuiOperationResultItem -Result $result -PreferredProperties @("ScriptName", "ProcessArgs", "ExitCode", "Success")
        if ($null -eq $item) {
            Append-UiLog $UI "管理脚本没有返回结果。"
            Show-Message "管理脚本没有返回结果。" "错误" "Error"
            return
        }
        $displayScriptName = [string](Get-ObjectPropertyValue $item "ScriptName" "")
        if ([string]::IsNullOrWhiteSpace($displayScriptName)) { $displayScriptName = "管理脚本" }
        if (Handle-TrackedScriptTermination -UI $UI -Item $item -LogKind "management script" -DisplayName $displayScriptName) {
        } elseif ($item.Success) {
            Write-TrackedScriptResultDebug -Kind "management script" -Item $item
            Append-UiLog $UI "$displayScriptName 执行成功。"
        } else {
            Write-TrackedScriptResultDebug -Kind "management script" -Item $item
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
    if (-not (Confirm-Message "警告：即将删除安装目录及其内部所有文件。`n`n项目: $($project.Name)`n安装目录: $path`n`n此操作不可撤销。下一步需要等待倒计时结束后再次确认。" "卸载 $($project.Name)")) { return }
    $countdownMessage = "即将删除当前项目的安装目录及其内部所有文件。`n`n项目: $($project.Name)`n安装目录: $path"
    if (-not (Show-CountdownConfirmDialog -Title "最终确认" -Message $countdownMessage -Seconds 5)) {
        Append-UiLog $UI "卸载最终确认取消。"
        Write-Log INFO "project uninstall canceled at countdown confirmation project=$key path=$path"
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
    $State = Ensure-GuiState $State
    Write-Log DEBUG "update check requested: manual=$Manual"
    $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()
    if (-not $Manual -and -not [bool]$script:MainConfig["AUTO_UPDATE_ENABLED"]) {
        Write-Log DEBUG "update check skipped: auto update disabled"
        return
    }
    $bundledXaml = Get-Variable -Name BundledXamlResources -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $bundledXaml -or $null -eq $bundledXaml.Value) {
        Write-Log DEBUG "update check skipped: source multi-file mode"
        if ($Manual) {
            Append-UiLog $UI "当前以源码多文件模式运行，跳过 GUI 自更新。发布版单文件可通过 install.ps1 或 Release 获取。"
            Show-Message "当前运行的是源码多文件入口，不会用 Release 单文件覆盖源码。`n`n请通过 install.ps1 安装，或下载 Release 中的 installer_launcher_gui.ps1 后再检查更新。" "源码模式" "Information"
        }
        return
    }
    if (-not $Manual) {
        $last = 0
        [void][Int64]::TryParse([string]$script:MainConfig["AUTO_UPDATE_LAST_CHECK"], [ref]$last)
        if (($now - $last) -lt $script:AutoUpdateIntervalSeconds) {
            Write-Log DEBUG "update check skipped: interval not reached now=$now last=$last interval=$script:AutoUpdateIntervalSeconds"
            return
        }
    }
    if ($null -ne (Get-ObjectPropertyValue $State "CurrentOperation" $null)) {
        $runningName = [string](Get-ObjectPropertyValue $State.CurrentOperation "Name" "当前任务")
        Write-Log DEBUG "update check skipped: operation already running name=$runningName manual=$Manual"
        if ($Manual) {
            Append-UiLog $UI "已有任务正在运行，暂时不能检查更新。"
            Show-Message "已有任务正在运行，请等待当前任务完成后再检查更新。" "任务运行中" "Warning"
        }
        return
    }
    if (-not (Get-UpdateCheckSemaphore).Wait(0)) {
        Write-Log DEBUG "update check skipped: update lock is held manual=$Manual"
        if ($Manual) {
            Append-UiLog $UI "更新检查正在运行，请稍候。"
            Show-Message "更新检查正在运行，请稍候。" "更新检查" "Information"
        }
        return
    }
    $script:MainConfig["AUTO_UPDATE_LAST_CHECK"] = $now
    Save-MainConfig
    $urlPayload = ConvertTo-Json -Compress -InputObject ([string[]]$script:SELF_REMOTE_URLS)
    Write-Log DEBUG "update check dispatch: manual=$Manual current_version=$script:INSTALLER_LAUNCHER_GUI_VERSION self=$script:EntryScriptPath cache=$(Join-Path $script:CacheHome "self-update") urls=$urlPayload"
    $operation = {
        param([string]$UrlPayload, [string]$CurrentVersion, [string]$SelfPath, [string]$UpdateCacheDir)
        $Urls = @()
        $attempts = New-Object System.Collections.ArrayList
        [void]$attempts.Add("BEGIN current_version=$CurrentVersion self=$SelfPath cache=$UpdateCacheDir")
        try {
            $parsedUrls = ConvertFrom-Json -InputObject $UrlPayload -ErrorAction Stop
            $Urls = @($parsedUrls | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            [void]$attempts.Add("URLS count=$($Urls.Count)")
        } catch {
            [void]$attempts.Add("FAIL parse-url-payload $($_.Exception.Message)")
            return [PSCustomObject]@{ Success = $false; Updated = $false; Message = "更新检查失败：更新源列表解析失败: $($_.Exception.Message)"; Attempts = @($attempts.ToArray()) }
        }
        $lastError = ""
        if ([string]::IsNullOrWhiteSpace($UpdateCacheDir)) {
            $UpdateCacheDir = Join-Path $env:TEMP "installer-launcher-self-update"
            [void]$attempts.Add("CACHE fallback=$UpdateCacheDir")
        }
        New-Item -ItemType Directory -Force -Path $UpdateCacheDir | Out-Null
        [void]$attempts.Add("CACHE ready=$UpdateCacheDir exists=$([bool](Test-Path -LiteralPath $UpdateCacheDir -PathType Container))")
        foreach ($url in $Urls) {
            $cachedScript = Join-Path $UpdateCacheDir ("installer_launcher_gui-{0}.ps1" -f ([guid]::NewGuid().ToString("N")))
            try {
                $headers = @{ "User-Agent" = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36" }
                $download = Invoke-DownloadUrlToPath -Url $url -OutputPath $cachedScript -Headers $headers -Attempts $attempts
                if (-not $download.Success) {
                    $lastError = $download.Error
                    continue
                }
                if (-not (Test-Path -LiteralPath $cachedScript -PathType Leaf) -or (Get-Item -LiteralPath $cachedScript).Length -le 0) {
                    throw "下载后的脚本文件为空"
                }
                $cachedLength = (Get-Item -LiteralPath $cachedScript).Length
                [void]$attempts.Add("CACHE_FILE size=$cachedLength path=$cachedScript")
                $content = Get-Content -LiteralPath $cachedScript -Raw -Encoding UTF8
                [void]$attempts.Add("READ cache_file=$cachedScript chars=$($content.Length)")
                if ($content -match '\$script:INSTALLER_LAUNCHER_GUI_VERSION\s*=\s*"([^"]+)"') {
                    $remote = $matches[1]
                    [void]$attempts.Add("OK $url version=$remote")
                    [void]$attempts.Add("COMPARE remote=$remote current=$CurrentVersion")
                    if ([version]$remote -le [version]$CurrentVersion) {
                        [void]$attempts.Add("SKIP replace reason=not-newer remote=$remote current=$CurrentVersion")
                        return [PSCustomObject]@{ Success = $true; Updated = $false; Message = "已是最新版本: $CurrentVersion"; Attempts = @($attempts.ToArray()) }
                    }
                    [void]$attempts.Add("REPLACE source=$cachedScript destination=$SelfPath")
                    Copy-Item -LiteralPath $cachedScript -Destination $SelfPath -Force
                    [void]$attempts.Add("REPLACED destination=$SelfPath")
                    return [PSCustomObject]@{ Success = $true; Updated = $true; Message = "已更新到 $remote，重新启动 GUI 后生效。"; Attempts = @($attempts.ToArray()) }
                }
                $lastError = "未在远程脚本中找到 GUI 版本号"
                [void]$attempts.Add("FAIL $url $lastError")
            } catch {
                $lastError = $_.Exception.Message
                [void]$attempts.Add("FAIL $url $lastError")
            } finally {
                [void]$attempts.Add("CLEAN cache_file=$cachedScript exists_before=$([bool](Test-Path -LiteralPath $cachedScript -PathType Leaf))")
                Remove-Item -LiteralPath $cachedScript -Force -ErrorAction SilentlyContinue
                [void]$attempts.Add("CLEANED cache_file=$cachedScript exists_after=$([bool](Test-Path -LiteralPath $cachedScript -PathType Leaf))")
            }
        }
        return [PSCustomObject]@{ Success = $false; Updated = $false; Message = "更新检查失败：无法从远程地址获取 GUI 脚本。最后错误: $lastError"; Attempts = @($attempts.ToArray()) }
    }
    $manualCheck = $Manual
    $updateCacheDir = Join-Path $script:CacheHome "self-update"
    try {
        Start-GuiOperation -UI $UI -State $State -Name "检查更新" -ScriptBlock $operation -Arguments @($urlPayload, $script:INSTALLER_LAUNCHER_GUI_VERSION, $script:EntryScriptPath, $updateCacheDir) -CanTerminate $false -OnComplete {
            param($result, $streamErrors)
            try {
                $item = Select-GuiOperationResultItem -Result $result -PreferredProperties @("Updated", "Message", "Success")
                if ($null -eq $item) {
                    Append-UiLog $UI "更新检查没有返回结果。"
                    if ($manualCheck) { Show-Message "更新检查没有返回结果。" "更新检查" "Warning" }
                    return
                }
                foreach ($attempt in @($item.Attempts)) {
                    Write-Log DEBUG "update source attempt: $attempt"
                }
                Append-UiLog $UI $item.Message
                if ($manualCheck -or $item.Updated) {
                    $icon = "Information"
                    if (-not $item.Success) { $icon = "Warning" }
                    Show-Message $item.Message "更新检查" $icon
                }
            } finally {
                Release-UpdateCheckLock
            }
        }.GetNewClosure()
    } catch {
        Release-UpdateCheckLock
        Write-Log DEBUG "update check lock released after dispatch failure"
        throw
    }
}
