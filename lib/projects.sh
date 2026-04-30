#!/usr/bin/env bash
# shellcheck disable=SC2034

PROJECT_KEYS=(sd_webui comfyui invokeai fooocus sd_trainer sd_trainer_script qwen_tts_webui)

# Project definitions are resolved through indirect expansion helpers.
# shellcheck disable=SC2034
PROJECT_sd_webui_NAME="Stable Diffusion WebUI Installer"
# shellcheck disable=SC2034
PROJECT_sd_webui_INSTALLER_URL="https://github.com/licyk/sd-webui-all-in-one/releases/download/stable_diffusion_webui_installer/stable_diffusion_webui_installer.ps1"
# shellcheck disable=SC2034
PROJECT_sd_webui_INSTALLER_URLS=(
  "https://github.com/licyk/sd-webui-all-in-one/releases/download/stable_diffusion_webui_installer/stable_diffusion_webui_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/stable_diffusion_webui_installer/stable_diffusion_webui_installer.ps1"
  "https://github.com/licyk/sd-webui-all-in-one/raw/main/installer/stable_diffusion_webui_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/stable_diffusion_webui_installer.ps1"
  "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/stable_diffusion_webui_installer.ps1"
)
# shellcheck disable=SC2034
PROJECT_sd_webui_INSTALLER_FILE="stable_diffusion_webui_installer.ps1"
# shellcheck disable=SC2034
PROJECT_sd_webui_DEFAULT_DIR="stable-diffusion-webui"
# shellcheck disable=SC2034
PROJECT_sd_webui_DEFAULT_BRANCH="sd_webui_dev"
# shellcheck disable=SC2034
PROJECT_sd_webui_MANAGEMENT_SCRIPTS=(
  "launch.ps1:启动 Stable Diffusion WebUI"
  "update.ps1:更新 Stable Diffusion WebUI"
  "update_extension.ps1:更新扩展"
  "switch_branch.ps1:切换分支"
  "terminal.ps1:打开交互终端"
  "settings.ps1:管理设置"
  "download_models.ps1:下载模型"
  "reinstall_pytorch.ps1:重装 PyTorch"
  "launch_stable_diffusion_webui_installer.ps1:获取最新安装器并运行"
)
# shellcheck disable=SC2034
PROJECT_sd_webui_BRANCHES=(
  "sd_webui_main:AUTOMATIC1111 主分支"
  "sd_webui_dev:AUTOMATIC1111 测试分支"
  "sd_webui_forge:Forge 分支"
  "sd_webui_reforge_main:reForge 主分支"
  "sd_webui_reforge_dev:reForge 测试分支"
  "sd_webui_forge_classic:Forge-Classic 分支"
  "sd_webui_forge_neo:Forge-Neo 分支"
  "sd_webui_amdgpu:AMDGPU 分支"
  "sd_next_main:SD.NEXT 主分支"
  "sd_next_dev:SD.NEXT 测试分支"
)
# shellcheck disable=SC2034
PROJECT_sd_webui_PARAMS=(
  CorePrefix InstallPath PyTorchMirrorType InstallPythonVersion InstallBranch
  DisablePyPIMirror DisableProxy UseCustomProxy DisableUV DisableGithubMirror
  UseCustomGithubMirror NoPreDownloadExtension NoPreDownloadModel NoCleanCache
  DisableModelMirror NoPause DisableHuggingFaceMirror UseCustomHuggingFaceMirror
  DisableCUDAMalloc DisableEnvCheck
)

# shellcheck disable=SC2034
PROJECT_comfyui_NAME="ComfyUI Installer"
# shellcheck disable=SC2034
PROJECT_comfyui_INSTALLER_URL="https://github.com/licyk/sd-webui-all-in-one/releases/download/comfyui_installer/comfyui_installer.ps1"
# shellcheck disable=SC2034
PROJECT_comfyui_INSTALLER_URLS=(
  "https://github.com/licyk/sd-webui-all-in-one/releases/download/comfyui_installer/comfyui_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/comfyui_installer/comfyui_installer.ps1"
  "https://github.com/licyk/sd-webui-all-in-one/raw/main/installer/comfyui_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/comfyui_installer.ps1"
  "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/comfyui_installer.ps1"
)
# shellcheck disable=SC2034
PROJECT_comfyui_INSTALLER_FILE="comfyui_installer.ps1"
# shellcheck disable=SC2034
PROJECT_comfyui_DEFAULT_DIR="ComfyUI"
# shellcheck disable=SC2034
PROJECT_comfyui_MANAGEMENT_SCRIPTS=(
  "launch.ps1:启动 ComfyUI"
  "update.ps1:更新 ComfyUI"
  "update_node.ps1:更新自定义节点"
  "terminal.ps1:打开交互终端"
  "settings.ps1:管理设置"
  "download_models.ps1:下载模型"
  "reinstall_pytorch.ps1:重装 PyTorch"
  "launch_comfyui_installer.ps1:获取最新安装器并运行"
)
# shellcheck disable=SC2034
PROJECT_comfyui_PARAMS=(
  CorePrefix InstallPath PyTorchMirrorType InstallPythonVersion DisablePyPIMirror
  DisableProxy UseCustomProxy DisableUV DisableGithubMirror UseCustomGithubMirror
  NoPreDownloadNode NoPreDownloadModel NoCleanCache DisableModelMirror NoPause
  DisableHuggingFaceMirror UseCustomHuggingFaceMirror
)

# shellcheck disable=SC2034
PROJECT_invokeai_NAME="InvokeAI Installer"
# shellcheck disable=SC2034
PROJECT_invokeai_INSTALLER_URL="https://github.com/licyk/sd-webui-all-in-one/releases/download/invokeai_installer/invokeai_installer.ps1"
# shellcheck disable=SC2034
PROJECT_invokeai_INSTALLER_URLS=(
  "https://github.com/licyk/sd-webui-all-in-one/releases/download/invokeai_installer/invokeai_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/invokeai_installer/invokeai_installer.ps1"
  "https://github.com/licyk/sd-webui-all-in-one/raw/main/installer/invokeai_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/invokeai_installer.ps1"
  "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/invokeai_installer.ps1"
)
# shellcheck disable=SC2034
PROJECT_invokeai_INSTALLER_FILE="invokeai_installer.ps1"
# shellcheck disable=SC2034
PROJECT_invokeai_DEFAULT_DIR="InvokeAI"
# shellcheck disable=SC2034
PROJECT_invokeai_MANAGEMENT_SCRIPTS=(
  "launch.ps1:启动 InvokeAI"
  "update.ps1:更新 InvokeAI"
  "update_node.ps1:更新节点"
  "terminal.ps1:打开交互终端"
  "settings.ps1:管理设置"
  "download_models.ps1:下载模型"
  "reinstall_pytorch.ps1:重装 PyTorch"
  "launch_invokeai_installer.ps1:获取最新安装器并运行"
)
# shellcheck disable=SC2034
PROJECT_invokeai_PARAMS=(
  CorePrefix InstallPath PyTorchMirrorType InstallPythonVersion DisablePyPIMirror
  DisableProxy UseCustomProxy DisableUV DisableGithubMirror UseCustomGithubMirror
  NoPreDownloadModel NoCleanCache DisableModelMirror NoPause
  DisableHuggingFaceMirror UseCustomHuggingFaceMirror DisableCUDAMalloc
  DisableEnvCheck
)

# shellcheck disable=SC2034
PROJECT_fooocus_NAME="Fooocus Installer"
# shellcheck disable=SC2034
PROJECT_fooocus_INSTALLER_URL="https://github.com/licyk/sd-webui-all-in-one/releases/download/fooocus_installer/fooocus_installer.ps1"
# shellcheck disable=SC2034
PROJECT_fooocus_INSTALLER_URLS=(
  "https://github.com/licyk/sd-webui-all-in-one/releases/download/fooocus_installer/fooocus_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/fooocus_installer/fooocus_installer.ps1"
  "https://github.com/licyk/sd-webui-all-in-one/raw/main/installer/fooocus_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/fooocus_installer.ps1"
  "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/fooocus_installer.ps1"
)
# shellcheck disable=SC2034
PROJECT_fooocus_INSTALLER_FILE="fooocus_installer.ps1"
# shellcheck disable=SC2034
PROJECT_fooocus_DEFAULT_DIR="Fooocus"
# shellcheck disable=SC2034
PROJECT_fooocus_DEFAULT_BRANCH="fooocus_main"
# shellcheck disable=SC2034
PROJECT_fooocus_MANAGEMENT_SCRIPTS=(
  "launch.ps1:启动 Fooocus"
  "update.ps1:更新 Fooocus"
  "switch_branch.ps1:切换分支"
  "terminal.ps1:打开交互终端"
  "settings.ps1:管理设置"
  "download_models.ps1:下载模型"
  "reinstall_pytorch.ps1:重装 PyTorch"
  "launch_fooocus_installer.ps1:获取最新安装器并运行"
)
# shellcheck disable=SC2034
PROJECT_fooocus_BRANCHES=(
  "fooocus_main:lllyasviel/Fooocus"
  "ruined_fooocus_main:runew0lf/RuinedFooocus"
  "fooocus_mre_main:MoonRide303/Fooocus-MRE"
)
# shellcheck disable=SC2034
PROJECT_fooocus_PARAMS=(
  CorePrefix InstallPath PyTorchMirrorType InstallPythonVersion InstallBranch
  DisablePyPIMirror DisableProxy UseCustomProxy DisableUV DisableGithubMirror
  UseCustomGithubMirror NoPreDownloadModel NoCleanCache DisableModelMirror
  NoPause DisableHuggingFaceMirror UseCustomHuggingFaceMirror
)

# shellcheck disable=SC2034
PROJECT_sd_trainer_NAME="SD Trainer Installer"
# shellcheck disable=SC2034
PROJECT_sd_trainer_INSTALLER_URL="https://github.com/licyk/sd-webui-all-in-one/releases/download/sd_trainer_installer/sd_trainer_installer.ps1"
# shellcheck disable=SC2034
PROJECT_sd_trainer_INSTALLER_URLS=(
  "https://github.com/licyk/sd-webui-all-in-one/releases/download/sd_trainer_installer/sd_trainer_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/sd_trainer_installer/sd_trainer_installer.ps1"
  "https://github.com/licyk/sd-webui-all-in-one/raw/main/installer/sd_trainer_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/sd_trainer_installer.ps1"
  "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/sd_trainer_installer.ps1"
)
# shellcheck disable=SC2034
PROJECT_sd_trainer_INSTALLER_FILE="sd_trainer_installer.ps1"
# shellcheck disable=SC2034
PROJECT_sd_trainer_DEFAULT_DIR="SD-Trainer"
# shellcheck disable=SC2034
PROJECT_sd_trainer_DEFAULT_BRANCH="sd_trainer_main"
# shellcheck disable=SC2034
PROJECT_sd_trainer_MANAGEMENT_SCRIPTS=(
  "launch.ps1:启动 SD Trainer"
  "update.ps1:更新 SD Trainer"
  "switch_branch.ps1:切换分支"
  "terminal.ps1:打开交互终端"
  "settings.ps1:管理设置"
  "download_models.ps1:下载模型"
  "reinstall_pytorch.ps1:重装 PyTorch"
  "launch_sd_trainer_installer.ps1:获取最新安装器并运行"
)
# shellcheck disable=SC2034
PROJECT_sd_trainer_BRANCHES=(
  "sd_trainer_main:Akegarasu/SD-Trainer"
  "kohya_gui_main:bmaltais/Kohya GUI"
)
# shellcheck disable=SC2034
PROJECT_sd_trainer_PARAMS=(
  CorePrefix InstallPath PyTorchMirrorType InstallPythonVersion InstallBranch
  DisablePyPIMirror DisableProxy UseCustomProxy DisableUV DisableGithubMirror
  UseCustomGithubMirror NoPreDownloadModel NoCleanCache DisableModelMirror
  NoPause DisableHuggingFaceMirror UseCustomHuggingFaceMirror
)

# shellcheck disable=SC2034
PROJECT_sd_trainer_script_NAME="SD Trainer Script Installer"
# shellcheck disable=SC2034
PROJECT_sd_trainer_script_INSTALLER_URL="https://github.com/licyk/sd-webui-all-in-one/releases/download/sd_trainer_script_installer/sd_trainer_script_installer.ps1"
# shellcheck disable=SC2034
PROJECT_sd_trainer_script_INSTALLER_URLS=(
  "https://github.com/licyk/sd-webui-all-in-one/releases/download/sd_trainer_script_installer/sd_trainer_script_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/sd_trainer_script_installer/sd_trainer_script_installer.ps1"
  "https://github.com/licyk/sd-webui-all-in-one/raw/main/installer/sd_trainer_script_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/sd_trainer_script_installer.ps1"
  "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/sd_trainer_script_installer.ps1"
)
# shellcheck disable=SC2034
PROJECT_sd_trainer_script_INSTALLER_FILE="sd_trainer_script_installer.ps1"
# shellcheck disable=SC2034
PROJECT_sd_trainer_script_DEFAULT_DIR="SD-Trainer-Script"
# shellcheck disable=SC2034
PROJECT_sd_trainer_script_DEFAULT_BRANCH="sd_scripts_main"
# shellcheck disable=SC2034
PROJECT_sd_trainer_script_MANAGEMENT_SCRIPTS=(
  "train.ps1:运行训练脚本"
  "update.ps1:更新 SD-Trainer-Script"
  "switch_branch.ps1:切换分支"
  "terminal.ps1:打开交互终端"
  "settings.ps1:管理设置"
  "download_models.ps1:下载模型"
  "reinstall_pytorch.ps1:重装 PyTorch"
  "launch_sd_trainer_script_installer.ps1:获取最新安装器并运行"
)
# shellcheck disable=SC2034
PROJECT_sd_trainer_script_BRANCHES=(
  "sd_scripts_main:kohya-ss/sd-scripts 主分支"
  "sd_scripts_dev:kohya-ss/sd-scripts 测试分支"
  "sd_scripts_sd3:kohya-ss/sd-scripts SD3 分支"
  "ai_toolkit_main:ostris/ai-toolkit"
  "finetrainers_main:a-r-r-o-w/finetrainers"
  "diffusion_pipe_main:tdrussell/diffusion-pipe"
  "musubi_tuner_main:kohya-ss/musubi-tuner"
)
# shellcheck disable=SC2034
PROJECT_sd_trainer_script_PARAMS=(
  CorePrefix InstallPath PyTorchMirrorType InstallPythonVersion InstallBranch
  DisablePyPIMirror DisableProxy UseCustomProxy DisableUV DisableGithubMirror
  UseCustomGithubMirror NoPreDownloadModel NoCleanCache DisableModelMirror
  NoPause DisableHuggingFaceMirror UseCustomHuggingFaceMirror DisableCUDAMalloc
  DisableEnvCheck
)

# shellcheck disable=SC2034
PROJECT_qwen_tts_webui_NAME="Qwen TTS WebUI Installer"
# shellcheck disable=SC2034
PROJECT_qwen_tts_webui_INSTALLER_URL="https://github.com/licyk/sd-webui-all-in-one/releases/download/qwen_tts_webui_installer/qwen_tts_webui_installer.ps1"
# shellcheck disable=SC2034
PROJECT_qwen_tts_webui_INSTALLER_URLS=(
  "https://github.com/licyk/sd-webui-all-in-one/releases/download/qwen_tts_webui_installer/qwen_tts_webui_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/releases/download/qwen_tts_webui_installer/qwen_tts_webui_installer.ps1"
  "https://github.com/licyk/sd-webui-all-in-one/raw/main/installer/qwen_tts_webui_installer.ps1"
  "https://gitee.com/licyk/sd-webui-all-in-one/raw/main/installer/qwen_tts_webui_installer.ps1"
  "https://gitlab.com/licyk/sd-webui-all-in-one/-/raw/main/installer/qwen_tts_webui_installer.ps1"
)
# shellcheck disable=SC2034
PROJECT_qwen_tts_webui_INSTALLER_FILE="qwen_tts_webui_installer.ps1"
# shellcheck disable=SC2034
PROJECT_qwen_tts_webui_DEFAULT_DIR="qwen-tts-webui"
# shellcheck disable=SC2034
PROJECT_qwen_tts_webui_MANAGEMENT_SCRIPTS=(
  "launch.ps1:启动 Qwen TTS WebUI"
  "update.ps1:更新 Qwen TTS WebUI"
  "terminal.ps1:打开交互终端"
  "settings.ps1:管理设置"
  "reinstall_pytorch.ps1:重装 PyTorch"
  "launch_qwen_tts_webui_installer.ps1:获取最新安装器并运行"
)
# shellcheck disable=SC2034
PROJECT_qwen_tts_webui_PARAMS=(
  CorePrefix InstallPath PyTorchMirrorType InstallPythonVersion DisablePyPIMirror
  DisableProxy UseCustomProxy DisableUV DisableGithubMirror UseCustomGithubMirror
  NoCleanCache NoPause DisableHuggingFaceMirror UseCustomHuggingFaceMirror
  DisableCUDAMalloc DisableEnvCheck
)

project_var() {
  local key="$1" suffix="$2" var
  [[ -n "$key" ]] || return 1
  var="PROJECT_${key}_${suffix}"
  [[ -v "$var" ]] || return 1
  printf '%s' "${!var}"
}

project_var_or_empty() {
  local key="$1" suffix="$2" var
  var="PROJECT_${key}_${suffix}"
  [[ -v "$var" ]] && printf '%s' "${!var}"
  return 0
}

project_name() { project_var "$1" NAME; }
project_installer_url() { project_var "$1" INSTALLER_URL; }
project_installer_file() { project_var "$1" INSTALLER_FILE; }
project_default_dir() { project_var "$1" DEFAULT_DIR; }
project_default_branch() { project_var_or_empty "$1" DEFAULT_BRANCH; }
project_config_file() { printf '%s/%s.conf' "$PROJECT_CONFIG_DIR" "$1"; }
project_default_install_path() { printf '%s/%s' "$HOME" "$(project_default_dir "$1")"; }

project_installer_urls() {
  local key="$1" array_name="PROJECT_${1}_INSTALLER_URLS[@]"
  if declare -p "PROJECT_${key}_INSTALLER_URLS" >/dev/null 2>&1; then
    printf '%s\n' "${!array_name}"
  else
    project_installer_url "$key"
  fi
}

script_entries_for_project() {
  local array_name="PROJECT_${1}_MANAGEMENT_SCRIPTS[@]"
  printf '%s\n' "${!array_name}"
}

branch_entries_for_project() {
  local key="$1" array_name="PROJECT_${1}_BRANCHES[@]"
  if declare -p "PROJECT_${key}_BRANCHES" >/dev/null 2>&1; then
    printf '%s\n' "${!array_name}"
  fi
}

project_has_branches() {
  declare -p "PROJECT_${1}_BRANCHES" >/dev/null 2>&1
}

project_param_entries() {
  local array_name="PROJECT_${1}_PARAMS[@]"
  printf '%s\n' "${!array_name}"
}

project_supports_param() {
  local key="$1" param="$2" entry
  while IFS= read -r entry; do
    [[ "$entry" == "$param" ]] && return 0
  done < <(project_param_entries "$key")
  return 1
}

management_script_param_entries() {
  local key="$1" script_name="$2"
  case "$script_name" in
    launch.ps1)
      printf '%s\n' CorePrefix BuildMode DisablePyPIMirror DisableUpdate DisableProxy UseCustomProxy DisableHuggingFaceMirror UseCustomHuggingFaceMirror DisableGithubMirror UseCustomGithubMirror DisableUV LaunchArg EnableShortcut DisableCUDAMalloc DisableEnvCheck NoPause
      ;;
    download_models.ps1)
      printf '%s\n' CorePrefix BuildMode BuildWithModel DisableProxy UseCustomProxy DisableUpdate DisableModelMirror NoPause
      ;;
    reinstall_pytorch.ps1)
      printf '%s\n' CorePrefix BuildMode BuildWithTorch BuildWithTorchReinstall DisablePyPIMirror DisableUpdate DisableUV DisableProxy UseCustomProxy NoPause
      ;;
    settings.ps1)
      printf '%s\n' CorePrefix DisableProxy UseCustomProxy NoPause
      ;;
    switch_branch.ps1)
      printf '%s\n' CorePrefix BuildMode BuildWithBranch DisableUpdate DisableProxy UseCustomProxy DisableGithubMirror UseCustomGithubMirror NoPause
      ;;
    update.ps1)
      if [[ "$key" == "invokeai" ]]; then
        printf '%s\n' CorePrefix BuildMode DisableUpdate DisableProxy UseCustomProxy DisablePyPIMirror DisableUV NoPause
      else
        printf '%s\n' CorePrefix BuildMode DisableUpdate DisableProxy UseCustomProxy DisableGithubMirror UseCustomGithubMirror NoPause
      fi
      ;;
    update_node.ps1|update_extension.ps1)
      printf '%s\n' CorePrefix BuildMode DisableUpdate DisableProxy UseCustomProxy DisableGithubMirror UseCustomGithubMirror NoPause
      ;;
    *)
      printf '%s\n' NoPause
      ;;
  esac
}

management_script_supports_param() {
  local key="$1" script_name="$2" param="$3" entry
  while IFS= read -r entry; do
    [[ "$entry" == "$param" ]] && return 0
  done < <(management_script_param_entries "$key" "$script_name")
  return 1
}
