# Project registry.

function Get-LauncherParamKind {
    param([string]$Name)
    if ($Name -in @("BuildMode", "BuildWithLaunch", "BuildWithTorchReinstall", "BuildWithUpdate", "BuildWithUpdateExtension", "BuildWithUpdateNode", "DisablePyPIMirror", "DisableUpdate", "DisableProxy", "DisableHuggingFaceMirror", "DisableGithubMirror", "DisableUV", "EnableShortcut", "DisableCUDAMalloc", "DisableEnvCheck", "DisableHotpatcher", "DisableModelMirror", "EnableHotpatcherRuntime", "InstallHanamizuki", "NoCleanCache", "NoPause", "NoPreDownloadExtension", "NoPreDownloadModel", "NoPreDownloadNode", "UseUpdateMode")) {
        return "flag"
    }
    return "value"
}

function Get-LauncherParamConfigKey {
    param([string]$Name)
    switch ($Name) {
        "InstallPath" { "INSTALL_PATH"; break }
        "InstallBranch" { "INSTALL_BRANCH"; break }
        "CorePrefix" { "CORE_PREFIX"; break }
        "PyTorchMirrorType" { "PYTORCH_MIRROR_TYPE"; break }
        "InstallPythonVersion" { "PYTHON_VERSION"; break }
        "UseCustomProxy" { "PROXY"; break }
        "UseCustomGithubMirror" { "GITHUB_MIRROR"; break }
        "UseCustomHuggingFaceMirror" { "HUGGINGFACE_MIRROR"; break }
        "DisableHotpatcher" { "DISABLE_HOTPATCHER"; break }
        "HotpatcherConfig" { "HOTPATCHER_CONFIG"; break }
        "HotpatcherPort" { "HOTPATCHER_PORT"; break }
        "EnableHotpatcherRuntime" { "ENABLE_HOTPATCHER_RUNTIME"; break }
        "DisablePyPIMirror" { "DISABLE_PYPI_MIRROR"; break }
        "DisableProxy" { "DISABLE_PROXY"; break }
        "DisableUV" { "DISABLE_UV"; break }
        "DisableGithubMirror" { "DISABLE_GITHUB_MIRROR"; break }
        "DisableModelMirror" { "DISABLE_MODEL_MIRROR"; break }
        "DisableHuggingFaceMirror" { "DISABLE_HUGGINGFACE_MIRROR"; break }
        "DisableCUDAMalloc" { "DISABLE_CUDA_MALLOC"; break }
        "DisableEnvCheck" { "DISABLE_ENV_CHECK"; break }
        "NoPreDownloadExtension" { "NO_PRE_DOWNLOAD_EXTENSION"; break }
        "NoPreDownloadNode" { "NO_PRE_DOWNLOAD_NODE"; break }
        "NoPreDownloadModel" { "NO_PRE_DOWNLOAD_MODEL"; break }
        "NoCleanCache" { "NO_CLEAN_CACHE"; break }
        default { $Name; break }
    }
}

function Get-LauncherParamLabel {
    param([string]$Name)
    switch ($Name) {
        "CorePrefix" { "内核路径前缀 -CorePrefix"; break }
        "InstallPath" { "安装路径 -InstallPath"; break }
        "InstallBranch" { "安装分支 -InstallBranch"; break }
        "PyTorchMirrorType" { "PyTorch 镜像类型 -PyTorchMirrorType"; break }
        "InstallPythonVersion" { "Python 版本 -InstallPythonVersion"; break }
        "UseUpdateMode" { "更新模式 -UseUpdateMode"; break }
        "BuildMode" { "构建模式 -BuildMode"; break }
        "BuildWithTorch" { "PyTorch 版本编号 -BuildWithTorch"; break }
        "BuildWithTorchReinstall" { "强制重装 PyTorch -BuildWithTorchReinstall"; break }
        "BuildWithModel" { "构建后下载模型编号 -BuildWithModel"; break }
        "BuildWithBranch" { "构建分支 -BuildWithBranch"; break }
        "BuildWithUpdate" { "构建后更新 -BuildWithUpdate"; break }
        "BuildWithUpdateExtension" { "构建后更新扩展 -BuildWithUpdateExtension"; break }
        "BuildWithUpdateNode" { "构建后更新节点 -BuildWithUpdateNode"; break }
        "BuildWithLaunch" { "构建后启动检查 -BuildWithLaunch"; break }
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
        "DisableHotpatcher" { "禁用 Hotpatcher -DisableHotpatcher"; break }
        "HotpatcherConfig" { "Hotpatcher 配置文件 -HotpatcherConfig"; break }
        "HotpatcherPort" { "Hotpatcher 通信端口 -HotpatcherPort"; break }
        "EnableHotpatcherRuntime" { "启用 Hotpatcher runtime -EnableHotpatcherRuntime"; break }
        "EnableShortcut" { "创建快捷方式 -EnableShortcut"; break }
        "DisableCUDAMalloc" { "禁用 CUDA 内存分配器 -DisableCUDAMalloc"; break }
        "DisableEnvCheck" { "禁用环境检查 -DisableEnvCheck"; break }
        "DisableModelMirror" { "禁用模型镜像 -DisableModelMirror"; break }
        "NoPreDownloadExtension" { "跳过预下载扩展 -NoPreDownloadExtension"; break }
        "NoPreDownloadNode" { "跳过预下载节点 -NoPreDownloadNode"; break }
        "NoPreDownloadModel" { "跳过预下载模型 -NoPreDownloadModel"; break }
        "NoCleanCache" { "不清理安装缓存 -NoCleanCache"; break }
        "PyTorchPackage" { "PyTorch 软件包 -PyTorchPackage"; break }
        "xFormersPackage" { "xFormers 软件包 -xFormersPackage"; break }
        "InstallHanamizuki" { "安装绘世启动器 -InstallHanamizuki"; break }
        "NoPause" { "执行结束后不暂停 -NoPause"; break }
        default { $Name; break }
    }
}

function New-LauncherParamSpec {
    param(
        [string]$Name,
        [string[]]$VisibleNames = @(),
        [string[]]$AutoAppendNames = @()
    )
    [PSCustomObject]@{
        Name = $Name
        Kind = Get-LauncherParamKind $Name
        ConfigKey = Get-LauncherParamConfigKey $Name
        Label = Get-LauncherParamLabel $Name
        Visible = @($VisibleNames) -contains $Name
        AutoAppend = @($AutoAppendNames) -contains $Name
    }
}

function New-LauncherParamSpecs {
    param(
        [string[]]$Names,
        [string[]]$VisibleNames = $Names,
        [string[]]$AutoAppendNames = @()
    )
    $specs = @()
    foreach ($name in @($Names)) {
        if ([string]::IsNullOrWhiteSpace($name) -or $name -eq "Help") { continue }
        $specs += New-LauncherParamSpec -Name $name -VisibleNames $VisibleNames -AutoAppendNames $AutoAppendNames
    }
    return @($specs)
}

function New-ProjectRegistry {
    $commonInstallerHost = "https://github.com/licyk/sd-webui-all-in-one"
    $projects = [ordered]@{}

    $installerVisibleBase = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "InstallBranch", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoPreDownloadExtension", "NoPreDownloadNode", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableHotpatcher", "HotpatcherConfig", "HotpatcherPort", "EnableHotpatcherRuntime", "DisableCUDAMalloc", "DisableEnvCheck")
    $installerAllBase = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "UseUpdateMode", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "InstallBranch", "BuildMode", "BuildWithTorch", "BuildWithTorchReinstall", "BuildWithModel", "BuildWithBranch", "BuildWithUpdate", "BuildWithUpdateExtension", "BuildWithUpdateNode", "BuildWithLaunch", "NoPreDownloadExtension", "NoPreDownloadNode", "NoPreDownloadModel", "PyTorchPackage", "xFormersPackage", "InstallHanamizuki", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableUpdate", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "LaunchArg", "DisableHotpatcher", "HotpatcherConfig", "HotpatcherPort", "EnableHotpatcherRuntime", "EnableShortcut", "DisableCUDAMalloc", "DisableEnvCheck")
    $launchScriptParams = @("CorePrefix", "BuildMode", "DisablePyPIMirror", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableGithubMirror", "UseCustomGithubMirror", "DisableUV", "LaunchArg", "DisableHotpatcher", "HotpatcherConfig", "HotpatcherPort", "EnableHotpatcherRuntime", "EnableShortcut", "DisableCUDAMalloc", "DisableEnvCheck", "NoPause")
    $launchScriptVisible = @("CorePrefix", "BuildMode", "DisablePyPIMirror", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableGithubMirror", "UseCustomGithubMirror", "DisableUV", "LaunchArg", "DisableHotpatcher", "HotpatcherConfig", "HotpatcherPort", "EnableHotpatcherRuntime", "EnableShortcut", "DisableCUDAMalloc", "DisableEnvCheck")
    $sdTrainerScriptInitParams = @("CorePrefix", "BuildMode", "DisablePyPIMirror", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableGithubMirror", "UseCustomGithubMirror", "DisableUV", "DisableCUDAMalloc", "DisableEnvCheck", "DisableHotpatcher", "HotpatcherConfig", "HotpatcherPort", "EnableHotpatcherRuntime", "NoPause")
    $downloadModelParams = @("CorePrefix", "BuildMode", "BuildWithModel", "DisableProxy", "UseCustomProxy", "DisableUpdate", "DisableModelMirror", "NoPause")
    $downloadModelVisible = @("CorePrefix", "BuildMode", "BuildWithModel", "DisableProxy", "UseCustomProxy", "DisableUpdate", "DisableModelMirror")
    $reinstallTorchParams = @("CorePrefix", "BuildMode", "BuildWithTorch", "BuildWithTorchReinstall", "DisablePyPIMirror", "DisableUpdate", "DisableUV", "DisableProxy", "UseCustomProxy", "NoPause")
    $reinstallTorchVisible = @("CorePrefix", "BuildMode", "BuildWithTorch", "BuildWithTorchReinstall", "DisablePyPIMirror", "DisableUpdate", "DisableUV", "DisableProxy", "UseCustomProxy")
    $settingsParams = @("CorePrefix", "DisableProxy", "UseCustomProxy", "NoPause")
    $settingsVisible = @("CorePrefix", "DisableProxy", "UseCustomProxy")
    $switchBranchParams = @("CorePrefix", "BuildMode", "BuildWithBranch", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableGithubMirror", "UseCustomGithubMirror", "NoPause")
    $switchBranchVisible = @("CorePrefix", "BuildMode", "BuildWithBranch", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableGithubMirror", "UseCustomGithubMirror")
    $versionManagerParams = @("CorePrefix", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableGithubMirror", "UseCustomGithubMirror", "NoPause")
    $versionManagerVisible = @("CorePrefix", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableGithubMirror", "UseCustomGithubMirror")
    $updateParams = @("CorePrefix", "BuildMode", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableGithubMirror", "UseCustomGithubMirror", "NoPause")
    $updateVisible = @("CorePrefix", "BuildMode", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisableGithubMirror", "UseCustomGithubMirror")
    $invokeAiUpdateParams = @("CorePrefix", "BuildMode", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisablePyPIMirror", "DisableUV", "NoPause")
    $invokeAiUpdateVisible = @("CorePrefix", "BuildMode", "DisableUpdate", "DisableProxy", "UseCustomProxy", "DisablePyPIMirror", "DisableUV")
    $terminalParams = @("CorePrefix", "DisablePyPIMirror", "DisableGithubMirror", "UseCustomGithubMirror", "DisableProxy", "UseCustomProxy", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "NoPause")
    $launcherInstallerParams = @("NoPause")

    $projects.sd_webui = [ordered]@{
        Key = "sd_webui"
        Name = "Stable Diffusion WebUI Installer"
        InstallerFile = "stable_diffusion_webui_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/stable_diffusion_webui_installer/stable_diffusion_webui_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/stable_diffusion_webui_installer/stable_diffusion_webui_installer.ps1",
            "$commonInstallerHost/raw/main/installer/stable_diffusion_webui_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/stable_diffusion_webui_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/stable_diffusion_webui_installer.ps1"
        )
        DefaultDir = "stable-diffusion-webui"
        DefaultBranch = "sd_webui_dev"
        Branches = [ordered]@{
            sd_webui_main = "AUTOMATIC1111 主分支"; sd_webui_dev = "AUTOMATIC1111 测试分支"; sd_webui_forge = "Forge 分支"
            sd_webui_reforge_main = "reForge 主分支"; sd_webui_reforge_dev = "reForge 测试分支"; sd_webui_forge_classic = "Forge-Classic 分支"
            sd_webui_forge_neo = "Forge-Neo 分支"; sd_webui_amdgpu = "AMDGPU 分支"; sd_next_main = "SD.NEXT 主分支"; sd_next_dev = "SD.NEXT 测试分支"
        }
        Scripts = [ordered]@{
            "launch.ps1" = "启动 Stable Diffusion WebUI"; "update.ps1" = "更新 Stable Diffusion WebUI"; "update_extension.ps1" = "更新扩展"
            "switch_branch.ps1" = "切换分支"; "version_manager.ps1" = "管理 WebUI 和扩展版本"; "terminal.ps1" = "打开交互终端"; "settings.ps1" = "管理设置"
            "download_models.ps1" = "下载模型"; "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_stable_diffusion_webui_installer.ps1" = "获取最新安装器并运行"
        }
        ScriptParams = [ordered]@{
            "launch.ps1" = New-LauncherParamSpecs -Names $launchScriptParams -VisibleNames $launchScriptVisible -AutoAppendNames @("NoPause")
            "update.ps1" = New-LauncherParamSpecs -Names $updateParams -VisibleNames $updateVisible -AutoAppendNames @("NoPause")
            "update_extension.ps1" = New-LauncherParamSpecs -Names $updateParams -VisibleNames $updateVisible -AutoAppendNames @("NoPause")
            "switch_branch.ps1" = New-LauncherParamSpecs -Names $switchBranchParams -VisibleNames $switchBranchVisible -AutoAppendNames @("NoPause")
            "version_manager.ps1" = New-LauncherParamSpecs -Names $versionManagerParams -VisibleNames $versionManagerVisible -AutoAppendNames @("NoPause")
            "terminal.ps1" = New-LauncherParamSpecs -Names $terminalParams -VisibleNames @() -AutoAppendNames @("NoPause")
            "settings.ps1" = New-LauncherParamSpecs -Names $settingsParams -VisibleNames $settingsVisible -AutoAppendNames @("NoPause")
            "download_models.ps1" = New-LauncherParamSpecs -Names $downloadModelParams -VisibleNames $downloadModelVisible -AutoAppendNames @("NoPause")
            "reinstall_pytorch.ps1" = New-LauncherParamSpecs -Names $reinstallTorchParams -VisibleNames $reinstallTorchVisible -AutoAppendNames @("NoPause")
            "launch_stable_diffusion_webui_installer.ps1" = New-LauncherParamSpecs -Names $launcherInstallerParams -VisibleNames @() -AutoAppendNames @("NoPause")
        }
        Installer = [ordered]@{
            Params = New-LauncherParamSpecs -Names $installerAllBase -VisibleNames @($installerVisibleBase | Where-Object { $_ -ne "NoPreDownloadNode" }) -AutoAppendNames @("NoPause")
        }
    }

    $projects.comfyui = [ordered]@{
        Key = "comfyui"; Name = "ComfyUI Installer"; InstallerFile = "comfyui_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/comfyui_installer/comfyui_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/comfyui_installer/comfyui_installer.ps1",
            "$commonInstallerHost/raw/main/installer/comfyui_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/comfyui_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/comfyui_installer.ps1"
        )
        DefaultDir = "ComfyUI"; DefaultBranch = ""
        Branches = [ordered]@{}
        Scripts = [ordered]@{
            "launch.ps1" = "启动 ComfyUI"; "update.ps1" = "更新 ComfyUI"; "update_node.ps1" = "更新自定义节点"
            "version_manager.ps1" = "管理 ComfyUI 和自定义节点版本"; "terminal.ps1" = "打开交互终端"; "settings.ps1" = "管理设置"; "download_models.ps1" = "下载模型"
            "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_comfyui_installer.ps1" = "获取最新安装器并运行"
        }
        ScriptParams = [ordered]@{
            "launch.ps1" = New-LauncherParamSpecs -Names $launchScriptParams -VisibleNames $launchScriptVisible -AutoAppendNames @("NoPause")
            "update.ps1" = New-LauncherParamSpecs -Names $updateParams -VisibleNames $updateVisible -AutoAppendNames @("NoPause")
            "update_node.ps1" = New-LauncherParamSpecs -Names $updateParams -VisibleNames $updateVisible -AutoAppendNames @("NoPause")
            "version_manager.ps1" = New-LauncherParamSpecs -Names $versionManagerParams -VisibleNames $versionManagerVisible -AutoAppendNames @("NoPause")
            "terminal.ps1" = New-LauncherParamSpecs -Names $terminalParams -VisibleNames @() -AutoAppendNames @("NoPause")
            "settings.ps1" = New-LauncherParamSpecs -Names $settingsParams -VisibleNames $settingsVisible -AutoAppendNames @("NoPause")
            "download_models.ps1" = New-LauncherParamSpecs -Names $downloadModelParams -VisibleNames $downloadModelVisible -AutoAppendNames @("NoPause")
            "reinstall_pytorch.ps1" = New-LauncherParamSpecs -Names $reinstallTorchParams -VisibleNames $reinstallTorchVisible -AutoAppendNames @("NoPause")
            "launch_comfyui_installer.ps1" = New-LauncherParamSpecs -Names $launcherInstallerParams -VisibleNames @() -AutoAppendNames @("NoPause")
        }
        Installer = [ordered]@{
            Params = New-LauncherParamSpecs -Names @($installerAllBase | Where-Object { $_ -notin @("InstallBranch", "BuildWithBranch", "BuildWithUpdateExtension") }) -VisibleNames @($installerVisibleBase | Where-Object { $_ -notin @("InstallBranch", "NoPreDownloadExtension", "DisableCUDAMalloc", "DisableEnvCheck") }) -AutoAppendNames @("NoPause")
        }
    }

    $projects.invokeai = [ordered]@{
        Key = "invokeai"; Name = "InvokeAI Installer"; InstallerFile = "invokeai_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/invokeai_installer/invokeai_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/invokeai_installer/invokeai_installer.ps1",
            "$commonInstallerHost/raw/main/installer/invokeai_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/invokeai_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/invokeai_installer.ps1"
        )
        DefaultDir = "InvokeAI"; DefaultBranch = ""
        Branches = [ordered]@{}
        Scripts = [ordered]@{
            "launch.ps1" = "启动 InvokeAI"; "update.ps1" = "更新 InvokeAI"; "update_node.ps1" = "更新节点"
            "version_manager.ps1" = "管理 InvokeAI 和节点版本"; "terminal.ps1" = "打开交互终端"; "settings.ps1" = "管理设置"; "download_models.ps1" = "下载模型"
            "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_invokeai_installer.ps1" = "获取最新安装器并运行"
        }
        ScriptParams = [ordered]@{
            "launch.ps1" = New-LauncherParamSpecs -Names $launchScriptParams -VisibleNames $launchScriptVisible -AutoAppendNames @("NoPause")
            "update.ps1" = New-LauncherParamSpecs -Names $invokeAiUpdateParams -VisibleNames $invokeAiUpdateVisible -AutoAppendNames @("NoPause")
            "update_node.ps1" = New-LauncherParamSpecs -Names $updateParams -VisibleNames $updateVisible -AutoAppendNames @("NoPause")
            "version_manager.ps1" = New-LauncherParamSpecs -Names $versionManagerParams -VisibleNames $versionManagerVisible -AutoAppendNames @("NoPause")
            "terminal.ps1" = New-LauncherParamSpecs -Names $terminalParams -VisibleNames @() -AutoAppendNames @("NoPause")
            "settings.ps1" = New-LauncherParamSpecs -Names $settingsParams -VisibleNames $settingsVisible -AutoAppendNames @("NoPause")
            "download_models.ps1" = New-LauncherParamSpecs -Names $downloadModelParams -VisibleNames $downloadModelVisible -AutoAppendNames @("NoPause")
            "reinstall_pytorch.ps1" = New-LauncherParamSpecs -Names @("CorePrefix", "BuildMode", "BuildWithTorch", "DisablePyPIMirror", "DisableUpdate", "DisableUV", "DisableProxy", "UseCustomProxy", "NoPause") -VisibleNames @("CorePrefix", "BuildMode", "BuildWithTorch", "DisablePyPIMirror", "DisableUpdate", "DisableUV", "DisableProxy", "UseCustomProxy") -AutoAppendNames @("NoPause")
            "launch_invokeai_installer.ps1" = New-LauncherParamSpecs -Names $launcherInstallerParams -VisibleNames @() -AutoAppendNames @("NoPause")
        }
        Installer = [ordered]@{
            Params = New-LauncherParamSpecs -Names @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "UseUpdateMode", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "BuildMode", "BuildWithTorch", "BuildWithModel", "BuildWithUpdate", "BuildWithUpdateNode", "BuildWithLaunch", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableUpdate", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "LaunchArg", "DisableHotpatcher", "HotpatcherConfig", "HotpatcherPort", "EnableHotpatcherRuntime", "EnableShortcut", "DisableCUDAMalloc", "DisableEnvCheck") -VisibleNames @($installerVisibleBase | Where-Object { $_ -notin @("InstallBranch", "NoPreDownloadExtension", "NoPreDownloadNode") }) -AutoAppendNames @("NoPause")
        }
    }

    $projects.fooocus = [ordered]@{
        Key = "fooocus"; Name = "Fooocus Installer"; InstallerFile = "fooocus_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/fooocus_installer/fooocus_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/fooocus_installer/fooocus_installer.ps1",
            "$commonInstallerHost/raw/main/installer/fooocus_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/fooocus_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/fooocus_installer.ps1"
        )
        DefaultDir = "Fooocus"; DefaultBranch = "fooocus_main"
        Branches = [ordered]@{ fooocus_main = "lllyasviel/Fooocus"; ruined_fooocus_main = "runew0lf/RuinedFooocus"; fooocus_mre_main = "MoonRide303/Fooocus-MRE" }
        Scripts = [ordered]@{
            "launch.ps1" = "启动 Fooocus"; "update.ps1" = "更新 Fooocus"; "switch_branch.ps1" = "切换分支"; "version_manager.ps1" = "管理 Fooocus 版本"
            "terminal.ps1" = "打开交互终端"; "settings.ps1" = "管理设置"; "download_models.ps1" = "下载模型"; "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_fooocus_installer.ps1" = "获取最新安装器并运行"
        }
        ScriptParams = [ordered]@{
            "launch.ps1" = New-LauncherParamSpecs -Names $launchScriptParams -VisibleNames $launchScriptVisible -AutoAppendNames @("NoPause")
            "update.ps1" = New-LauncherParamSpecs -Names $updateParams -VisibleNames $updateVisible -AutoAppendNames @("NoPause")
            "switch_branch.ps1" = New-LauncherParamSpecs -Names $switchBranchParams -VisibleNames $switchBranchVisible -AutoAppendNames @("NoPause")
            "version_manager.ps1" = New-LauncherParamSpecs -Names $versionManagerParams -VisibleNames $versionManagerVisible -AutoAppendNames @("NoPause")
            "terminal.ps1" = New-LauncherParamSpecs -Names $terminalParams -VisibleNames @() -AutoAppendNames @("NoPause")
            "settings.ps1" = New-LauncherParamSpecs -Names $settingsParams -VisibleNames $settingsVisible -AutoAppendNames @("NoPause")
            "download_models.ps1" = New-LauncherParamSpecs -Names $downloadModelParams -VisibleNames $downloadModelVisible -AutoAppendNames @("NoPause")
            "reinstall_pytorch.ps1" = New-LauncherParamSpecs -Names $reinstallTorchParams -VisibleNames $reinstallTorchVisible -AutoAppendNames @("NoPause")
            "launch_fooocus_installer.ps1" = New-LauncherParamSpecs -Names $launcherInstallerParams -VisibleNames @() -AutoAppendNames @("NoPause")
        }
        Installer = [ordered]@{
            Params = New-LauncherParamSpecs -Names @($installerAllBase | Where-Object { $_ -notin @("BuildWithUpdateExtension", "BuildWithUpdateNode", "NoPreDownloadExtension", "NoPreDownloadNode") }) -VisibleNames @($installerVisibleBase | Where-Object { $_ -notin @("NoPreDownloadExtension", "NoPreDownloadNode", "DisableCUDAMalloc", "DisableEnvCheck") }) -AutoAppendNames @("NoPause")
        }
    }

    $projects.sd_trainer = [ordered]@{
        Key = "sd_trainer"; Name = "SD Trainer Installer"; InstallerFile = "sd_trainer_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/sd_trainer_installer/sd_trainer_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/sd_trainer_installer/sd_trainer_installer.ps1",
            "$commonInstallerHost/raw/main/installer/sd_trainer_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/sd_trainer_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/sd_trainer_installer.ps1"
        )
        DefaultDir = "SD-Trainer"; DefaultBranch = "sd_trainer_main"
        Branches = [ordered]@{ sd_trainer_main = "Akegarasu/SD-Trainer"; kohya_gui_main = "bmaltais/Kohya GUI" }
        Scripts = [ordered]@{
            "launch.ps1" = "启动 SD Trainer"; "update.ps1" = "更新 SD Trainer"; "switch_branch.ps1" = "切换分支"; "version_manager.ps1" = "管理 SD Trainer 版本"
            "terminal.ps1" = "打开交互终端"; "settings.ps1" = "管理设置"; "download_models.ps1" = "下载模型"; "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_sd_trainer_installer.ps1" = "获取最新安装器并运行"
        }
        ScriptParams = [ordered]@{
            "launch.ps1" = New-LauncherParamSpecs -Names $launchScriptParams -VisibleNames $launchScriptVisible -AutoAppendNames @("NoPause")
            "update.ps1" = New-LauncherParamSpecs -Names $updateParams -VisibleNames $updateVisible -AutoAppendNames @("NoPause")
            "switch_branch.ps1" = New-LauncherParamSpecs -Names $switchBranchParams -VisibleNames $switchBranchVisible -AutoAppendNames @("NoPause")
            "version_manager.ps1" = New-LauncherParamSpecs -Names $versionManagerParams -VisibleNames $versionManagerVisible -AutoAppendNames @("NoPause")
            "terminal.ps1" = New-LauncherParamSpecs -Names $terminalParams -VisibleNames @() -AutoAppendNames @("NoPause")
            "settings.ps1" = New-LauncherParamSpecs -Names $settingsParams -VisibleNames $settingsVisible -AutoAppendNames @("NoPause")
            "download_models.ps1" = New-LauncherParamSpecs -Names $downloadModelParams -VisibleNames $downloadModelVisible -AutoAppendNames @("NoPause")
            "reinstall_pytorch.ps1" = New-LauncherParamSpecs -Names $reinstallTorchParams -VisibleNames $reinstallTorchVisible -AutoAppendNames @("NoPause")
            "launch_sd_trainer_installer.ps1" = New-LauncherParamSpecs -Names $launcherInstallerParams -VisibleNames @() -AutoAppendNames @("NoPause")
        }
        Installer = [ordered]@{
            Params = New-LauncherParamSpecs -Names @($installerAllBase | Where-Object { $_ -notin @("BuildWithUpdateExtension", "BuildWithUpdateNode", "NoPreDownloadExtension", "NoPreDownloadNode") }) -VisibleNames @($installerVisibleBase | Where-Object { $_ -notin @("NoPreDownloadExtension", "NoPreDownloadNode", "DisableCUDAMalloc", "DisableEnvCheck") }) -AutoAppendNames @("NoPause")
        }
    }

    $projects.sd_trainer_script = [ordered]@{
        Key = "sd_trainer_script"; Name = "SD Trainer Script Installer"; InstallerFile = "sd_trainer_script_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/sd_trainer_script_installer/sd_trainer_script_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/sd_trainer_script_installer/sd_trainer_script_installer.ps1",
            "$commonInstallerHost/raw/main/installer/sd_trainer_script_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/sd_trainer_script_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/sd_trainer_script_installer.ps1"
        )
        DefaultDir = "SD-Trainer-Script"; DefaultBranch = "sd_scripts_main"
        Branches = [ordered]@{
            sd_scripts_main = "kohya-ss/sd-scripts 主分支"; sd_scripts_dev = "kohya-ss/sd-scripts 测试分支"; sd_scripts_sd3 = "kohya-ss/sd-scripts SD3 分支"
            ai_toolkit_main = "ostris/ai-toolkit"; finetrainers_main = "a-r-r-o-w/finetrainers"; diffusion_pipe_main = "tdrussell/diffusion-pipe"; musubi_tuner_main = "kohya-ss/musubi-tuner"
        }
        Scripts = [ordered]@{
            "train.ps1" = "运行训练脚本"; "update.ps1" = "更新 SD-Trainer-Script"; "switch_branch.ps1" = "切换分支"; "version_manager.ps1" = "管理 SD-Trainer-Script 版本"
            "terminal.ps1" = "打开交互终端"; "settings.ps1" = "管理设置"; "download_models.ps1" = "下载模型"; "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_sd_trainer_script_installer.ps1" = "获取最新安装器并运行"
        }
        ScriptParams = [ordered]@{
            "train.ps1" = @()
            "update.ps1" = New-LauncherParamSpecs -Names $updateParams -VisibleNames $updateVisible -AutoAppendNames @("NoPause")
            "switch_branch.ps1" = New-LauncherParamSpecs -Names $switchBranchParams -VisibleNames $switchBranchVisible -AutoAppendNames @("NoPause")
            "version_manager.ps1" = New-LauncherParamSpecs -Names $versionManagerParams -VisibleNames $versionManagerVisible -AutoAppendNames @("NoPause")
            "terminal.ps1" = New-LauncherParamSpecs -Names $terminalParams -VisibleNames @() -AutoAppendNames @("NoPause")
            "settings.ps1" = New-LauncherParamSpecs -Names $settingsParams -VisibleNames $settingsVisible -AutoAppendNames @("NoPause")
            "download_models.ps1" = New-LauncherParamSpecs -Names $downloadModelParams -VisibleNames $downloadModelVisible -AutoAppendNames @("NoPause")
            "reinstall_pytorch.ps1" = New-LauncherParamSpecs -Names $reinstallTorchParams -VisibleNames $reinstallTorchVisible -AutoAppendNames @("NoPause")
            "launch_sd_trainer_script_installer.ps1" = New-LauncherParamSpecs -Names $launcherInstallerParams -VisibleNames @() -AutoAppendNames @("NoPause")
            "init.ps1" = New-LauncherParamSpecs -Names $sdTrainerScriptInitParams -VisibleNames @() -AutoAppendNames @("NoPause")
        }
        Installer = [ordered]@{
            Params = New-LauncherParamSpecs -Names @($installerAllBase | Where-Object { $_ -notin @("BuildWithUpdateExtension", "BuildWithUpdateNode", "NoPreDownloadExtension", "NoPreDownloadNode", "InstallHanamizuki", "EnableShortcut") }) -VisibleNames @($installerVisibleBase | Where-Object { $_ -notin @("NoPreDownloadExtension", "NoPreDownloadNode") }) -AutoAppendNames @("NoPause")
        }
    }

    $projects.qwen_tts_webui = [ordered]@{
        Key = "qwen_tts_webui"; Name = "Qwen TTS WebUI Installer"; InstallerFile = "qwen_tts_webui_installer.ps1"
        InstallerUrls = @(
            "$commonInstallerHost/releases/download/qwen_tts_webui_installer/qwen_tts_webui_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/qwen_tts_webui_installer/qwen_tts_webui_installer.ps1",
            "$commonInstallerHost/raw/main/installer/qwen_tts_webui_installer.ps1",
            "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/qwen_tts_webui_installer.ps1",
            "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/qwen_tts_webui_installer.ps1"
        )
        DefaultDir = "qwen-tts-webui"; DefaultBranch = ""
        Branches = [ordered]@{}
        Scripts = [ordered]@{
            "launch.ps1" = "启动 Qwen TTS WebUI"; "update.ps1" = "更新 Qwen TTS WebUI"; "version_manager.ps1" = "管理 Qwen TTS WebUI 版本"
            "terminal.ps1" = "打开交互终端"; "settings.ps1" = "管理设置"; "reinstall_pytorch.ps1" = "重装 PyTorch"; "launch_qwen_tts_webui_installer.ps1" = "获取最新安装器并运行"
        }
        ScriptParams = [ordered]@{
            "launch.ps1" = New-LauncherParamSpecs -Names $launchScriptParams -VisibleNames $launchScriptVisible -AutoAppendNames @("NoPause")
            "update.ps1" = New-LauncherParamSpecs -Names $updateParams -VisibleNames $updateVisible -AutoAppendNames @("NoPause")
            "version_manager.ps1" = New-LauncherParamSpecs -Names $versionManagerParams -VisibleNames $versionManagerVisible -AutoAppendNames @("NoPause")
            "terminal.ps1" = New-LauncherParamSpecs -Names $terminalParams -VisibleNames @() -AutoAppendNames @("NoPause")
            "settings.ps1" = New-LauncherParamSpecs -Names $settingsParams -VisibleNames $settingsVisible -AutoAppendNames @("NoPause")
            "reinstall_pytorch.ps1" = New-LauncherParamSpecs -Names $reinstallTorchParams -VisibleNames $reinstallTorchVisible -AutoAppendNames @("NoPause")
            "launch_qwen_tts_webui_installer.ps1" = New-LauncherParamSpecs -Names $launcherInstallerParams -VisibleNames @() -AutoAppendNames @("NoPause")
        }
        Installer = [ordered]@{
            Params = New-LauncherParamSpecs -Names @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "UseUpdateMode", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "BuildMode", "BuildWithTorch", "BuildWithTorchReinstall", "BuildWithUpdate", "BuildWithLaunch", "PyTorchPackage", "xFormersPackage", "NoCleanCache", "NoPause", "DisableUpdate", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "LaunchArg", "DisableHotpatcher", "HotpatcherConfig", "HotpatcherPort", "EnableHotpatcherRuntime", "EnableShortcut", "DisableCUDAMalloc", "DisableEnvCheck") -VisibleNames @($installerVisibleBase | Where-Object { $_ -notin @("InstallBranch", "NoPreDownloadExtension", "NoPreDownloadNode", "NoPreDownloadModel", "DisableModelMirror") }) -AutoAppendNames @("NoPause")
        }
    }

    return $projects
}

$script:Projects = New-ProjectRegistry
