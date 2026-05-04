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
        ScriptParams = @{}
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
    return @($Project.Params) -contains $ParamName
}

function Get-ManagementScriptParams {
    param([string]$ProjectKey, [string]$ScriptName)
    switch ($ScriptName) {
        "launch.ps1" { return @("CorePrefix", "BuildMode", "DisablePyPIMirror", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableGithubMirror", "UseCustomGithubMirror", "DisableUV", "LaunchArg", "EnableShortcut", "DisableCUDAMalloc", "DisableEnvCheck", "NoPause") }
        "download_models.ps1" { return @("CorePrefix", "BuildMode", "BuildWithModel", "DisableProxy", "UseCustomProxy", "DisableUpdate", "DisableModelMirror", "NoPause") }
        "reinstall_pytorch.ps1" { return @("CorePrefix", "BuildMode", "BuildWithTorch", "BuildWithTorchReinstall", "DisablePyPIMirror", "DisableUpdate", "DisableUV", "DisableProxy", "UseCustomProxy", "NoPause") }
        "settings.ps1" { return @("CorePrefix", "DisableProxy", "UseCustomProxy", "NoPause") }
        "switch_branch.ps1" { return @("CorePrefix", "BuildMode", "BuildWithBranch", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableGithubMirror", "UseCustomGithubMirror", "NoPause") }
        "version_manager.ps1" { return @("CorePrefix", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableGithubMirror", "UseCustomGithubMirror", "NoPause") }
        "update.ps1" {
            if ($ProjectKey -eq "invokeai") { return @("CorePrefix", "BuildMode", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisablePyPIMirror", "DisableUV", "NoPause") }
            return @("CorePrefix", "BuildMode", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableGithubMirror", "UseCustomGithubMirror", "NoPause")
        }
        { $_ -in @("update_node.ps1", "update_extension.ps1") } { return @("CorePrefix", "BuildMode", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableGithubMirror", "UseCustomGithubMirror", "NoPause") }
        default { return @("NoPause") }
    }
}

function Test-ManagementScriptParam {
    param([string]$ProjectKey, [string]$ScriptName, [string]$ParamName)
    return @((Get-ManagementScriptParams $ProjectKey $ScriptName)) -contains $ParamName
}

function Test-ScriptParamIsFlag {
    param([string]$ParamName)
    return $ParamName -in @("BuildMode", "DisablePyPIMirror", "DisableUpdate", "DisableProxy", "DisableHuggingFaceMirror", "DisableGithubMirror", "DisableUV", "EnableShortcut", "DisableCUDAMalloc", "DisableEnvCheck", "DisableModelMirror", "BuildWithTorchReinstall")
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
    param([string]$ParamName)
    switch ($ParamName) {
        "CorePrefix" { "内核路径前缀 -CorePrefix"; break }
        "BuildMode" { "构建模式 -BuildMode"; break }
        "BuildWithModel" { "构建后下载模型编号 -BuildWithModel"; break }
        "BuildWithTorch" { "PyTorch 版本编号 -BuildWithTorch"; break }
        "BuildWithTorchReinstall" { "强制重装 PyTorch -BuildWithTorchReinstall"; break }
        "BuildWithBranch" { "构建分支 -BuildWithBranch"; break }
        "DisablePyPIMirror" { "禁用 PyPI 镜像 -DisablePyPIMirror"; break }
        "DisableUpdate" { "禁用更新检查 -DisableUpdate"; break }
        "DisableProxy" { "禁用自动代理 -DisableProxy"; break }
        "UseCustomProxy" { "自定义代理 -UseCustomProxy"; break }
        "DisableHuggingFaceMirror" { "禁用 HuggingFace 镜像 -DisableHuggingFaceMirror"; break }
        "UseCustomHuggingFaceMirror" { "自定义 HuggingFace 镜像 -UseCustomHuggingFaceMirror"; break }
        "DisableGithubMirror" { "禁用 Github 镜像 -DisableGithubMirror"; break }
        "UseCustomGithubMirror" { "自定义 Github 镜像 -UseCustomGithubMirror"; break }
        "DisableUV" { "禁用 uv -DisableUV"; break }
        "LaunchArg" { "启动参数 -LaunchArg"; break }
        "EnableShortcut" { "创建快捷方式 -EnableShortcut"; break }
        "DisableCUDAMalloc" { "禁用 CUDA 内存分配器 -DisableCUDAMalloc"; break }
        "DisableEnvCheck" { "禁用环境检查 -DisableEnvCheck"; break }
        "DisableModelMirror" { "禁用模型镜像 -DisableModelMirror"; break }
        default { $ParamName; break }
    }
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
    if (-not (Test-ArgsContains @($args) "-NoPause")) { $args.Add("-NoPause") }
    return @($args)
}

function Build-ManagementScriptArgs {
    param([string]$ProjectKey, [string]$ScriptName, [System.Collections.IDictionary]$Config)
    $args = New-Object System.Collections.Generic.List[string]
    $scriptParams = @{}
    if ($Config.Contains("ScriptParams") -and $null -ne $Config["ScriptParams"] -and (Test-DictionaryKey $Config["ScriptParams"] $ScriptName)) {
        $scriptParams = $Config["ScriptParams"][$ScriptName]
    }
    foreach ($paramName in (Get-ManagementScriptParams $ProjectKey $ScriptName)) {
        if ($paramName -eq "NoPause") { continue }
        $value = ""
        if ($null -ne $scriptParams -and (Test-DictionaryKey $scriptParams $paramName)) { $value = $scriptParams[$paramName] }
        if (Test-ScriptParamIsFlag $paramName) {
            if ([bool]$value) { $args.Add("-$paramName") }
        } elseif (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            $args.Add("-$paramName")
            $args.Add([string]$value)
        }
    }
    if ($Config.Contains("ScriptArgs") -and $null -ne $Config["ScriptArgs"] -and (Test-DictionaryKey $Config["ScriptArgs"] $ScriptName)) {
        $argsText = [string]$Config["ScriptArgs"][$ScriptName]
        if (-not [string]::IsNullOrWhiteSpace($argsText)) {
            foreach ($arg in (Split-Shlex $argsText)) { $args.Add($arg) }
        }
    }
    if ((Test-ManagementScriptParam $ProjectKey $ScriptName "NoPause") -and -not (Test-ArgsContains @($args) "-NoPause")) { $args.Add("-NoPause") }
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

