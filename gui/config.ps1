# Configuration, proxy, and argument construction.

function Get-DefaultMainConfig {
    [ordered]@{
        CURRENT_PROJECT = ""
        AUTO_UPDATE_ENABLED = $true
        USER_AGREEMENT_ACCEPTED = $false
        LOG_LEVEL = "DEBUG"
        PROXY_MODE = "auto"
        MANUAL_PROXY = ""
        AUTO_UPDATE_LAST_CHECK = 0
    }
}

function Get-DefaultProjectConfig {
    param([string]$ProjectKey)
    $project = $script:Projects[$ProjectKey]
    $config = [ordered]@{
        SchemaVersion = 2
        Installer = [ordered]@{
            Params = [ordered]@{}
            ExtraArgs = ""
        }
        Scripts = [ordered]@{}
    }
    foreach ($spec in (Get-InstallerParamSpecs $project)) {
        $config.Installer.Params[$spec.Name] = Get-DefaultParamValue $spec $project
    }
    foreach ($scriptName in @($project.Scripts.Keys)) {
        $config.Scripts[$scriptName] = [ordered]@{
            Params = [ordered]@{}
            ExtraArgs = ""
        }
        foreach ($spec in (Get-ManagementScriptParamSpecs $ProjectKey $scriptName)) {
            $config.Scripts[$scriptName].Params[$spec.Name] = Get-DefaultParamValue $spec $project
        }
    }
    return $config
}

function Copy-Dictionary {
    param([System.Collections.IDictionary]$Source)
    $copy = [ordered]@{}
    foreach ($key in $Source.Keys) {
        $copy[$key] = $Source[$key]
    }
    return $copy
}

function Get-DefaultParamValue {
    param($Spec, $Project)
    if ($Spec.Name -eq "InstallBranch") { return [string]$Project.DefaultBranch }
    if ($Spec.Kind -eq "flag") { return $false }
    return ""
}

function Get-InstallerParamSpecs {
    param($Project)
    if ($null -ne $Project -and $Project.Contains("Installer") -and $null -ne $Project.Installer -and $Project.Installer.Contains("Params")) {
        return @($Project.Installer.Params)
    }
    return @()
}

function Get-InstallerParamSpec {
    param($Project, [string]$ParamName)
    foreach ($spec in (Get-InstallerParamSpecs $Project)) {
        if ($spec.Name -eq $ParamName) { return $spec }
    }
    return $null
}

function Get-InstallerParamSpecByConfigKey {
    param($Project, [string]$ConfigKey)
    foreach ($spec in (Get-InstallerParamSpecs $Project)) {
        if ($spec.ConfigKey -eq $ConfigKey) { return $spec }
    }
    return $null
}

function Get-ManagementScriptParamSpecs {
    param([string]$ProjectKey, [string]$ScriptName)
    if ([string]::IsNullOrWhiteSpace($ProjectKey) -or -not $script:Projects.Contains($ProjectKey)) { return @() }
    $project = $script:Projects[$ProjectKey]
    if ($null -eq $project -or -not $project.Contains("ScriptParams") -or $null -eq $project.ScriptParams) { return @() }
    if (-not (Test-DictionaryKey $project.ScriptParams $ScriptName)) { return @() }
    return @($project.ScriptParams[$ScriptName])
}

function Get-ManagementScriptParamSpec {
    param([string]$ProjectKey, [string]$ScriptName, [string]$ParamName)
    foreach ($spec in (Get-ManagementScriptParamSpecs $ProjectKey $ScriptName)) {
        if ($spec.Name -eq $ParamName) { return $spec }
    }
    return $null
}

function Get-InstallerParamsTable {
    param([System.Collections.IDictionary]$Config)
    if ($null -eq $Config["Installer"] -or -not ($Config["Installer"] -is [System.Collections.IDictionary])) { $Config["Installer"] = [ordered]@{} }
    if (-not $Config["Installer"].Contains("Params") -or $null -eq $Config["Installer"]["Params"] -or -not ($Config["Installer"]["Params"] -is [System.Collections.IDictionary])) { $Config["Installer"]["Params"] = [ordered]@{} }
    if (-not $Config["Installer"].Contains("ExtraArgs") -or $null -eq $Config["Installer"]["ExtraArgs"]) { $Config["Installer"]["ExtraArgs"] = "" }
    return $Config["Installer"]["Params"]
}

function Get-ScriptConfigTable {
    param([System.Collections.IDictionary]$Config, [string]$ScriptName)
    if ($null -eq $Config["Scripts"] -or -not ($Config["Scripts"] -is [System.Collections.IDictionary])) { $Config["Scripts"] = [ordered]@{} }
    if (-not (Test-DictionaryKey $Config["Scripts"] $ScriptName) -or $null -eq $Config["Scripts"][$ScriptName] -or -not ($Config["Scripts"][$ScriptName] -is [System.Collections.IDictionary])) {
        $Config["Scripts"][$ScriptName] = [ordered]@{ Params = [ordered]@{}; ExtraArgs = "" }
    }
    if (-not $Config["Scripts"][$ScriptName].Contains("Params") -or $null -eq $Config["Scripts"][$ScriptName]["Params"] -or -not ($Config["Scripts"][$ScriptName]["Params"] -is [System.Collections.IDictionary])) {
        $Config["Scripts"][$ScriptName]["Params"] = [ordered]@{}
    }
    if (-not $Config["Scripts"][$ScriptName].Contains("ExtraArgs") -or $null -eq $Config["Scripts"][$ScriptName]["ExtraArgs"]) {
        $Config["Scripts"][$ScriptName]["ExtraArgs"] = ""
    }
    return $Config["Scripts"][$ScriptName]
}

function Get-InstallerParamValue {
    param([System.Collections.IDictionary]$Config, [string]$ParamName)
    $params = Get-InstallerParamsTable $Config
    if (Test-DictionaryKey $params $ParamName) { return $params[$ParamName] }
    return ""
}

function Set-InstallerParamValue {
    param([System.Collections.IDictionary]$Config, [string]$ParamName, $Value)
    $params = Get-InstallerParamsTable $Config
    $params[$ParamName] = $Value
}

function Get-InstallerConfigValue {
    param($Project, [System.Collections.IDictionary]$Config, [string]$ConfigKey)
    if ($ConfigKey -eq "EXTRA_INSTALL_ARGS") {
        [void](Get-InstallerParamsTable $Config)
        return [string]$Config["Installer"]["ExtraArgs"]
    }
    $spec = Get-InstallerParamSpecByConfigKey $Project $ConfigKey
    if ($null -eq $spec) { return "" }
    return (Get-InstallerParamValue $Config $spec.Name)
}

function Set-InstallerConfigValue {
    param($Project, [System.Collections.IDictionary]$Config, [string]$ConfigKey, $Value)
    if ($ConfigKey -eq "EXTRA_INSTALL_ARGS") {
        [void](Get-InstallerParamsTable $Config)
        $Config["Installer"]["ExtraArgs"] = [string]$Value
        return
    }
    $spec = Get-InstallerParamSpecByConfigKey $Project $ConfigKey
    if ($null -eq $spec) { return }
    Set-InstallerParamValue $Config $spec.Name $Value
}

function Get-ScriptParamValue {
    param([System.Collections.IDictionary]$Config, [string]$ScriptName, [string]$ParamName)
    $scriptConfig = Get-ScriptConfigTable $Config $ScriptName
    if (Test-DictionaryKey $scriptConfig.Params $ParamName) { return $scriptConfig.Params[$ParamName] }
    return ""
}

function Set-ScriptParamValue {
    param([System.Collections.IDictionary]$Config, [string]$ScriptName, [string]$ParamName, $Value)
    $scriptConfig = Get-ScriptConfigTable $Config $ScriptName
    $scriptConfig.Params[$ParamName] = $Value
}

function Get-ScriptExtraArgs {
    param([System.Collections.IDictionary]$Config, [string]$ScriptName)
    $scriptConfig = Get-ScriptConfigTable $Config $ScriptName
    return [string]$scriptConfig.ExtraArgs
}

function Set-ScriptExtraArgs {
    param([System.Collections.IDictionary]$Config, [string]$ScriptName, [string]$Value)
    $scriptConfig = Get-ScriptConfigTable $Config $ScriptName
    $scriptConfig.ExtraArgs = $Value
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

function Read-ProjectJsonConfig {
    param([string]$Path, [System.Collections.IDictionary]$Default)
    if (-not (Test-Path $Path -PathType Leaf)) {
        return (Copy-Dictionary $Default)
    }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) {
            Save-JsonConfig -Path $Path -Config $Default
            return (Copy-Dictionary $Default)
        }
        $loaded = ConvertTo-PlainHashtable ($raw | ConvertFrom-Json)
        if (-not $loaded.Contains("SchemaVersion") -or [int]$loaded["SchemaVersion"] -ne 2) {
            Write-Log WARN "project config schema reset to v2: path=$Path"
            Save-JsonConfig -Path $Path -Config $Default
            return (Copy-Dictionary $Default)
        }
        $merged = Copy-Dictionary $Default
        if ($loaded.Contains("Installer") -and $null -ne $loaded["Installer"]) {
            if (-not ($loaded["Installer"] -is [System.Collections.IDictionary])) { $loaded["Installer"] = ConvertTo-PlainHashtable $loaded["Installer"] }
            if ($loaded["Installer"].Contains("ExtraArgs")) { $merged["Installer"]["ExtraArgs"] = [string]$loaded["Installer"]["ExtraArgs"] }
            if ($loaded["Installer"].Contains("Params") -and $null -ne $loaded["Installer"]["Params"]) {
                if (-not ($loaded["Installer"]["Params"] -is [System.Collections.IDictionary])) { $loaded["Installer"]["Params"] = ConvertTo-PlainHashtable $loaded["Installer"]["Params"] }
                foreach ($paramName in @($loaded["Installer"]["Params"].Keys)) {
                    $merged["Installer"]["Params"][$paramName] = $loaded["Installer"]["Params"][$paramName]
                }
            }
        }
        if ($loaded.Contains("Scripts") -and $null -ne $loaded["Scripts"]) {
            if (-not ($loaded["Scripts"] -is [System.Collections.IDictionary])) { $loaded["Scripts"] = ConvertTo-PlainHashtable $loaded["Scripts"] }
            foreach ($scriptName in @($loaded["Scripts"].Keys)) {
                if ([string]::IsNullOrWhiteSpace($scriptName)) { continue }
                $scriptConfig = Get-ScriptConfigTable $merged $scriptName
                $loadedScript = $loaded["Scripts"][$scriptName]
                if ($null -eq $loadedScript) { continue }
                if (-not ($loadedScript -is [System.Collections.IDictionary])) { $loadedScript = ConvertTo-PlainHashtable $loadedScript }
                if ($loadedScript.Contains("ExtraArgs")) { $scriptConfig["ExtraArgs"] = [string]$loadedScript["ExtraArgs"] }
                if ($loadedScript.Contains("Params") -and $null -ne $loadedScript["Params"]) {
                    if (-not ($loadedScript["Params"] -is [System.Collections.IDictionary])) { $loadedScript["Params"] = ConvertTo-PlainHashtable $loadedScript["Params"] }
                    foreach ($paramName in @($loadedScript["Params"].Keys)) {
                        $scriptConfig["Params"][$paramName] = $loadedScript["Params"][$paramName]
                    }
                }
            }
        }
        return $merged
    } catch {
        Write-Log WARN "failed to read project config, reset to defaults: path=$Path error=$($_.Exception.Message)"
        Save-JsonConfig -Path $Path -Config $Default
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
    Read-ProjectJsonConfig -Path (Get-ProjectConfigPath $ProjectKey) -Default (Get-DefaultProjectConfig $ProjectKey)
}

function Save-ProjectConfig {
    param([string]$ProjectKey, [System.Collections.IDictionary]$Config)
    Save-JsonConfig -Path (Get-ProjectConfigPath $ProjectKey) -Config $Config
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
    return $null -ne (Get-InstallerParamSpec $Project $ParamName)
}

function Get-ManagementScriptParams {
    param([string]$ProjectKey, [string]$ScriptName)
    return @((Get-ManagementScriptParamSpecs $ProjectKey $ScriptName) | ForEach-Object { $_.Name })
}

function Test-ManagementScriptParam {
    param([string]$ProjectKey, [string]$ScriptName, [string]$ParamName)
    return $null -ne (Get-ManagementScriptParamSpec $ProjectKey $ScriptName $ParamName)
}

function Test-ScriptParamIsFlag {
    param([string]$ParamName, $Spec = $null)
    if ($null -ne $Spec) { return $Spec.Kind -eq "flag" }
    return (Get-LauncherParamKind $ParamName) -eq "flag"
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
    param([string]$ParamName, $Spec = $null)
    if ($null -ne $Spec -and -not [string]::IsNullOrWhiteSpace($Spec.Label)) { return [string]$Spec.Label }
    return (Get-LauncherParamLabel $ParamName)
}

function Get-EffectiveInstallPath {
    param($Project, [System.Collections.IDictionary]$Config)
    $installPath = [string](Get-InstallerParamValue $Config "InstallPath")
    if (-not [string]::IsNullOrWhiteSpace($installPath)) { return $installPath }
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
    $autoAppendSpecs = @()
    foreach ($spec in (Get-InstallerParamSpecs $Project)) {
        if ($spec.AutoAppend) {
            $autoAppendSpecs += $spec
            continue
        }
        if ($spec.Name -eq "InstallPath") {
            $args.Add("-InstallPath")
            $args.Add((Get-EffectiveInstallPath $Project $Config))
            continue
        }
        $value = Get-InstallerParamValue $Config $spec.Name
        if ($spec.Kind -eq "flag") {
            if ([bool]$value) { $args.Add("-$($spec.Name)") }
        } elseif (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            $args.Add("-$($spec.Name)")
            $args.Add([string]$value)
        }
    }
    $extraArgs = [string]$Config["Installer"]["ExtraArgs"]
    if (-not [string]::IsNullOrWhiteSpace($extraArgs)) {
        foreach ($arg in (Split-Shlex $extraArgs)) { $args.Add($arg) }
    }
    foreach ($spec in $autoAppendSpecs) {
        if (-not (Test-ArgsContains @($args) "-$($spec.Name)")) { $args.Add("-$($spec.Name)") }
    }
    return @($args)
}

function Build-ManagementScriptArgs {
    param([string]$ProjectKey, [string]$ScriptName, [System.Collections.IDictionary]$Config)
    $args = New-Object System.Collections.Generic.List[string]
    $autoAppendSpecs = @()
    foreach ($spec in (Get-ManagementScriptParamSpecs $ProjectKey $ScriptName)) {
        if ($spec.AutoAppend) {
            $autoAppendSpecs += $spec
            continue
        }
        $value = Get-ScriptParamValue $Config $ScriptName $spec.Name
        if ($spec.Kind -eq "flag") {
            if ([bool]$value) { $args.Add("-$($spec.Name)") }
        } elseif (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            $args.Add("-$($spec.Name)")
            $args.Add([string]$value)
        }
    }
    $argsText = Get-ScriptExtraArgs $Config $ScriptName
    if (-not [string]::IsNullOrWhiteSpace($argsText)) {
        foreach ($arg in (Split-Shlex $argsText)) { $args.Add($arg) }
    }
    foreach ($spec in $autoAppendSpecs) {
        if (-not (Test-ArgsContains @($args) "-$($spec.Name)")) { $args.Add("-$($spec.Name)") }
    }
    return @($args)
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
