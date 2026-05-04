# Project registry.

function New-ProjectRegistry {
    $commonInstallerHost = "https://github.com/licyk/sd-webui-all-in-one"
    $projects = [ordered]@{}

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
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "InstallBranch", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoPreDownloadExtension", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableCUDAMalloc", "DisableEnvCheck")
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
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoPreDownloadNode", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror")
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
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableCUDAMalloc", "DisableEnvCheck")
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
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "InstallBranch", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror")
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
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "InstallBranch", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror")
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
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "InstallBranch", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoPreDownloadModel", "NoCleanCache", "DisableModelMirror", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableCUDAMalloc", "DisableEnvCheck")
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
        Params = @("CorePrefix", "InstallPath", "PyTorchMirrorType", "InstallPythonVersion", "DisablePyPIMirror", "DisableProxy", "UseCustomProxy", "DisableUV", "DisableGithubMirror", "UseCustomGithubMirror", "NoCleanCache", "NoPause", "DisableHuggingFaceMirror", "UseCustomHuggingFaceMirror", "DisableCUDAMalloc", "DisableEnvCheck")
    }

    return $projects
}

$script:Projects = New-ProjectRegistry
