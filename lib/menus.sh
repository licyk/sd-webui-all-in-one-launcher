#!/usr/bin/env bash

select_project() {
  local menu_args=() key
  for key in "${PROJECT_KEYS[@]}"; do
    menu_args+=("$key" "$(project_name "$key")")
  done
  menu_select "选择安装器" "选择主页要管理的安装器类型" "${menu_args[@]}"
}

change_current_project() {
  local selected_project
  selected_project="$(select_project)" || return 0
  [[ -n "$selected_project" ]] || return 0
  CURRENT_PROJECT="$selected_project"
  save_main_config
  load_project_config "$CURRENT_PROJECT"
}

current_project_is_selected() {
  [[ -n "${CURRENT_PROJECT:-}" ]] && project_name "$CURRENT_PROJECT" >/dev/null 2>&1
}

current_project_label() {
  if current_project_is_selected; then
    project_name "$CURRENT_PROJECT"
  else
    printf '未选择'
  fi
}

ensure_current_project_selected() {
  if current_project_is_selected; then
    return 0
  fi
  show_error "尚未选择安装器，请先进入 '选择不同类型的安装器' 进行设置。"
  return 1
}

select_branch() {
  local key="$1" menu_args=() entry
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    menu_args+=("${entry%%:*}" "${entry#*:}")
  done < <(branch_entries_for_project "$key")
  [[ "${#menu_args[@]}" -gt 0 ]] || return 1
  menu_select "安装分支" "选择传给 -InstallBranch 的分支" "${menu_args[@]}"
}

select_management_script() {
  local key="$1" menu_args=() entry
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    menu_args+=("${entry%%:*}" "${entry#*:}")
  done < <(script_entries_for_project "$key")
  menu_select "管理脚本" "选择要处理的 PowerShell 子脚本" "${menu_args[@]}"
}

configure_script_args() {
  local key="${1:-$CURRENT_PROJECT}" script_name="${2:-}" current new_value
  load_project_config "$key"
  [[ -n "$script_name" ]] || script_name="$(select_management_script "$key")" || return 0
  current="$(get_script_args "$script_name")"
  new_value="$(input_box "子脚本参数" "保存给 $script_name 的默认运行参数，留空表示无参数" "$current")" || return 0
  set_script_args "$script_name" "$new_value"
  save_project_config "$key"
}

configure_flags() {
  local key="$1" selected
  local checklist_args=()
  project_supports_param "$key" DisablePyPIMirror && checklist_args+=("DISABLE_PYPI_MIRROR" "禁用 PyPI 镜像 -DisablePyPIMirror" "$(flag_state "$DISABLE_PYPI_MIRROR")")
  project_supports_param "$key" DisableProxy && checklist_args+=("DISABLE_PROXY" "禁用自动代理 -DisableProxy" "$(flag_state "$DISABLE_PROXY")")
  project_supports_param "$key" DisableUV && checklist_args+=("DISABLE_UV" "禁用 uv -DisableUV" "$(flag_state "$DISABLE_UV")")
  project_supports_param "$key" DisableGithubMirror && checklist_args+=("DISABLE_GITHUB_MIRROR" "禁用 Github 镜像 -DisableGithubMirror" "$(flag_state "$DISABLE_GITHUB_MIRROR")")
  project_supports_param "$key" NoPreDownloadExtension && checklist_args+=("NO_PRE_DOWNLOAD_EXTENSION" "跳过预下载扩展 -NoPreDownloadExtension" "$(flag_state "$NO_PRE_DOWNLOAD_EXTENSION")")
  project_supports_param "$key" NoPreDownloadNode && checklist_args+=("NO_PRE_DOWNLOAD_NODE" "跳过预下载节点 -NoPreDownloadNode" "$(flag_state "$NO_PRE_DOWNLOAD_NODE")")
  project_supports_param "$key" NoPreDownloadModel && checklist_args+=("NO_PRE_DOWNLOAD_MODEL" "跳过预下载模型 -NoPreDownloadModel" "$(flag_state "$NO_PRE_DOWNLOAD_MODEL")")
  project_supports_param "$key" NoCleanCache && checklist_args+=("NO_CLEAN_CACHE" "不清理安装缓存 -NoCleanCache" "$(flag_state "$NO_CLEAN_CACHE")")
  project_supports_param "$key" DisableModelMirror && checklist_args+=("DISABLE_MODEL_MIRROR" "不用 ModelScope 下载模型 -DisableModelMirror" "$(flag_state "$DISABLE_MODEL_MIRROR")")
  project_supports_param "$key" DisableHuggingFaceMirror && checklist_args+=("DISABLE_HUGGINGFACE_MIRROR" "禁用 HuggingFace 镜像 -DisableHuggingFaceMirror" "$(flag_state "$DISABLE_HUGGINGFACE_MIRROR")")
  project_supports_param "$key" DisableCUDAMalloc && checklist_args+=("DISABLE_CUDA_MALLOC" "禁用 CUDA 内存分配器设置 -DisableCUDAMalloc" "$(flag_state "$DISABLE_CUDA_MALLOC")")
  project_supports_param "$key" DisableEnvCheck && checklist_args+=("DISABLE_ENV_CHECK" "禁用环境检查 -DisableEnvCheck" "$(flag_state "$DISABLE_ENV_CHECK")")

  if [[ "${#checklist_args[@]}" -eq 0 ]]; then
    pause_screen "当前安装器没有可配置的开关参数。"
    return 0
  fi

  selected="$(checklist_select "开关参数" "选择当前安装器运行时的开关参数" "${checklist_args[@]}")" || return 0
  DISABLE_PYPI_MIRROR=0 DISABLE_PROXY=0 DISABLE_UV=0 DISABLE_GITHUB_MIRROR=0
  DISABLE_MODEL_MIRROR=0 DISABLE_HUGGINGFACE_MIRROR=0 DISABLE_CUDA_MALLOC=0
  DISABLE_ENV_CHECK=0 NO_PRE_DOWNLOAD_EXTENSION=0 NO_PRE_DOWNLOAD_NODE=0
  NO_PRE_DOWNLOAD_MODEL=0 NO_CLEAN_CACHE=0
  [[ " $selected " == *" DISABLE_PYPI_MIRROR "* ]] && DISABLE_PYPI_MIRROR=1
  [[ " $selected " == *" DISABLE_PROXY "* ]] && DISABLE_PROXY=1
  [[ " $selected " == *" DISABLE_UV "* ]] && DISABLE_UV=1
  [[ " $selected " == *" DISABLE_GITHUB_MIRROR "* ]] && DISABLE_GITHUB_MIRROR=1
  [[ " $selected " == *" NO_PRE_DOWNLOAD_EXTENSION "* ]] && NO_PRE_DOWNLOAD_EXTENSION=1
  [[ " $selected " == *" NO_PRE_DOWNLOAD_NODE "* ]] && NO_PRE_DOWNLOAD_NODE=1
  [[ " $selected " == *" NO_PRE_DOWNLOAD_MODEL "* ]] && NO_PRE_DOWNLOAD_MODEL=1
  [[ " $selected " == *" NO_CLEAN_CACHE "* ]] && NO_CLEAN_CACHE=1
  [[ " $selected " == *" DISABLE_MODEL_MIRROR "* ]] && DISABLE_MODEL_MIRROR=1
  [[ " $selected " == *" DISABLE_HUGGINGFACE_MIRROR "* ]] && DISABLE_HUGGINGFACE_MIRROR=1
  [[ " $selected " == *" DISABLE_CUDA_MALLOC "* ]] && DISABLE_CUDA_MALLOC=1
  [[ " $selected " == *" DISABLE_ENV_CHECK "* ]] && DISABLE_ENV_CHECK=1
  save_project_config "$key"
}

configure_project() {
  local key="${1:-$CURRENT_PROJECT}" choice
  load_project_config "$key"
  while true; do
    local menu_args=()
    project_supports_param "$key" InstallPath && menu_args+=("install_path" "安装路径: ${INSTALL_PATH:-$(project_default_install_path "$key")}")
    project_supports_param "$key" InstallBranch && menu_args+=("branch" "安装分支: ${INSTALL_BRANCH:-未设置}")
    project_supports_param "$key" CorePrefix && menu_args+=("core_prefix" "内核路径前缀: ${CORE_PREFIX:-默认}")
    project_supports_param "$key" PyTorchMirrorType && menu_args+=("torch" "PyTorch 镜像类型: ${PYTORCH_MIRROR_TYPE:-默认}")
    project_supports_param "$key" InstallPythonVersion && menu_args+=("python" "Python 版本: ${PYTHON_VERSION:-默认}")
    project_supports_param "$key" UseCustomProxy && menu_args+=("proxy" "代理: ${PROXY:-未设置}")
    project_supports_param "$key" UseCustomGithubMirror && menu_args+=("github_mirror" "Github 镜像: ${GITHUB_MIRROR:-默认}")
    project_supports_param "$key" UseCustomHuggingFaceMirror && menu_args+=("hf_mirror" "HuggingFace 镜像: ${HUGGINGFACE_MIRROR:-默认}")
    menu_args+=("flags" "开关参数")
    menu_args+=("extra" "主安装器自定义参数: ${EXTRA_INSTALL_ARGS:-无}")
    menu_args+=("script_args" "子脚本默认启动参数设置")
    menu_args+=("back" "返回")

    choice="$(menu_select "$(project_name "$key") 配置" "项目配置文件: $(project_config_file "$key")" "${menu_args[@]}")" || return 0
    case "$choice" in
      install_path) INSTALL_PATH="$(input_box "安装路径" "安装目标绝对路径，留空使用默认路径" "${INSTALL_PATH:-$(project_default_install_path "$key")}")" || true ;;
      branch)
        if project_has_branches "$key"; then
          INSTALL_BRANCH="$(select_branch "$key")" || true
        else
          INSTALL_BRANCH="$(input_box "安装分支" "可手动填写 -InstallBranch，留空不传" "${INSTALL_BRANCH:-}")" || true
        fi
        ;;
      core_prefix) CORE_PREFIX="$(input_box "内核路径前缀" "例如 core，留空使用默认值" "${CORE_PREFIX:-}")" || true ;;
      torch) PYTORCH_MIRROR_TYPE="$(input_box "PyTorch 镜像类型" "例如 cu121、cu124、cpu、directml、all，留空不传" "${PYTORCH_MIRROR_TYPE:-}")" || true ;;
      python) PYTHON_VERSION="$(input_box "Python 版本" "例如 3.10 / 3.11 / 3.12，留空不传" "${PYTHON_VERSION:-}")" || true ;;
      proxy) PROXY="$(input_box "代理" "例如 http://127.0.0.1:10809，留空不传" "${PROXY:-}")" || true ;;
      github_mirror) GITHUB_MIRROR="$(input_box "Github 镜像" "例如 https://ghfast.top/https://github.com，留空不传" "${GITHUB_MIRROR:-}")" || true ;;
      hf_mirror) HUGGINGFACE_MIRROR="$(input_box "HuggingFace 镜像" "例如 https://hf-mirror.com，留空不传" "${HUGGINGFACE_MIRROR:-}")" || true ;;
      flags) configure_flags "$key" || true ;;
      extra) EXTRA_INSTALL_ARGS="$(input_box "主安装器自定义参数" "直接追加给 $(project_installer_file "$key") 的参数" "${EXTRA_INSTALL_ARGS:-}")" || true ;;
      script_args) configure_script_args "$key" || true ;;
      back) save_project_config "$key"; return 0 ;;
    esac
    save_project_config "$key"
  done
}

configure_main() {
  local choice
  while true; do
    choice="$(menu_select "主配置" "主配置文件: $MAIN_CONFIG_FILE" \
      "project" "当前安装器: $(current_project_label)" \
      "auto_update" "启动时自动检查更新: $(flag_state "$AUTO_UPDATE_ENABLED")" \
      "welcome" "启动欢迎界面: $(flag_state "$SHOW_WELCOME_SCREEN")" \
      "log_level" "日志等级: $LOG_LEVEL" \
      "back" "返回")" || return 0
    case "$choice" in
      project) change_current_project ;;
      auto_update)
        if [[ "$AUTO_UPDATE_ENABLED" == "1" ]]; then
          AUTO_UPDATE_ENABLED=0
        else
          AUTO_UPDATE_ENABLED=1
        fi
        ;;
      welcome)
        if [[ "$SHOW_WELCOME_SCREEN" == "1" ]]; then
          SHOW_WELCOME_SCREEN=0
        else
          SHOW_WELCOME_SCREEN=1
        fi
        ;;
      log_level)
        choice="$(menu_select "日志等级" "选择写入日志文件的最低等级" \
          "DEBUG" "DEBUG: 记录最详细信息，适合排查问题" \
          "INFO" "INFO: 记录常规操作和警告错误" \
          "WARN" "WARN: 只记录警告和错误" \
          "ERROR" "ERROR: 只记录错误和崩溃")" || true
        if [[ -n "${choice:-}" ]]; then
          LOG_LEVEL="$choice"
        fi
        ;;
      back) save_main_config; return 0 ;;
    esac
    save_main_config
  done
}

main_menu_status() {
  local check_output check_status status_detail status_hint status_label
  if ! current_project_is_selected; then
    printf '当前安装器: 未选择\n安装状态: 未检测\n请先选择要安装或管理的 WebUI / 工具类型。'
    return 0
  fi

  if check_output="$(check_installation "$CURRENT_PROJECT")"; then
    check_status=0
  else
    check_status=$?
  fi

  case "$check_status" in
    0)
      status_label="安装状态: 已安装"
      status_hint="下一步: 可以运行管理脚本执行启动、更新或维护操作。"
      ;;
    1)
      status_label="安装状态: 未安装"
      status_hint='下一步: 可以先修改当前安装器配置，然后选择 "下载安装器并运行" 安装对应 WebUI / 工具。'
      ;;
    2)
      status_label="安装状态: 安装目录存在，但缺少管理脚本"
      status_hint='下一步: 当前安装不完整，请选择 "下载安装器并运行" 完成 WebUI / 工具安装。'
      ;;
    *)
      status_label="安装状态: 检测失败"
      status_hint="下一步: 请检查当前安装器配置和安装路径。"
      ;;
  esac

  status_detail="$(printf '%s\n' "$check_output" | sed '/^已安装: /d')"
  printf '当前安装器: %s\n%s\n%s\n%s' "$(current_project_label)" "$status_label" "$status_detail" "$status_hint"
}

show_tui_help() {
  local help_text
  help_text="$(cat <<EOF
TUI 使用帮助

基本思路
  这个启动器是安装和管理 AI WebUI / 训练工具的统一入口。
  你可以选择要安装的 WebUI 类型，保存安装参数，下载安装器并运行 PowerShell 脚本。
  它不会把安装器脚本固定在仓库里；每次运行安装器都会重新下载到缓存目录，
  这样可以尽量使用上游最新脚本。

首次使用流程
  1. 进入 "选择不同类型的安装器"，选择要安装的 WebUI 或工具。
  2. 进入 "当前安装器配置"，确认安装路径、分支、镜像、代理等安装参数。
  3. 返回主界面，选择 "下载安装器并运行" 开始安装对应 WebUI。
  4. 安装完成后，使用 "运行安装后生成的管理脚本" 启动 WebUI、更新项目或进入终端环境。

dialog 操作方式
  方向键: 在菜单项之间移动。
  Tab: 在按钮之间切换。
  Enter: 确认当前选择。
  Space: 在复选框中切换开关。
  Esc: 返回或取消当前窗口。
  文本页面: 使用方向键、PageUp、PageDown 滚动内容。

启动欢迎界面
  默认启动 TUI 时会先显示欢迎界面，包含版本信息、自动更新状态和 dialog 操作提示。
  可在 "启动器主配置" 中关闭或重新开启。

自动更新
  默认启用。启动器每 60 分钟最多检查一次远程 lib/core.sh 中的 APP_VERSION。
  如果远程版本高于本地版本，会自动尝试更新启动器自身。
  更新失败不会阻止启动器继续运行，会在启动时显示提示。
  检查和更新过程中会在终端输出简短状态，便于判断当前是否正在联网检查或更新。

主界面顶部状态
  当前安装器: 显示当前选择的 WebUI / 工具。若显示 "未选择"，需要先选择要安装的类型。
  安装状态: 每次进入主界面都会根据安装路径自动检测。
    已安装: 安装路径存在，并且找到了该项目的管理脚本。
    未安装: 安装路径不存在。
    安装目录存在，但缺少管理脚本: 路径存在，但不像完整安装结果。
  安装路径: 检测成功时会显示实际路径，方便确认当前管理的是哪份安装。

主菜单入口
  选择不同类型的安装器
    选择要安装或管理的 WebUI / 工具。选择后会保存到主配置，下次启动继续使用。

  下载安装器并运行
    每次都会重新下载安装器到缓存目录，然后执行它，用于安装当前选择的 WebUI / 工具。
    每个安装器会按内置下载源列表依次尝试下载；只要任意一个下载成功就继续执行。
    如果全部下载源都失败，会显示已经尝试过的地址并终止安装任务。
    启动器会显式传入 -InstallPath。
    如果当前安装器支持 -NoPause，会自动追加，避免 PowerShell 脚本结束后阻塞。
    如果 PowerShell 返回非零退出代码，启动器会停留在当前终端，等待你查看输出日志后按 Enter 返回。

  卸载当前已安装软件
    删除当前安装器对应的安装目录。
    卸载前会先显示警告确认，再要求输入指定确认文本。
    启动器保存的项目配置不会被删除。

  运行安装后生成的管理脚本
    用于执行安装目录里的 launch.ps1、update.ps1、terminal.ps1 等脚本。
    这些脚本通常用于启动 WebUI、更新项目、打开交互终端、进入项目环境或下载模型。
    运行 launch.ps1 和 terminal.ps1 前会显示确认提示；选择确认后才会继续执行。
    terminal.ps1 会自动做环境激活，不需要单独运行 activate.ps1。
    如果脚本异常退出，启动器会先停留在当前终端，方便查看 PowerShell 输出日志。
    如果提示找不到脚本，通常说明项目还没安装成功，或安装路径配置不对。

  调整子脚本默认启动参数
    给某个管理脚本保存默认参数。例如给 launch.ps1 保存监听地址、端口等。
    这些参数只在运行对应子脚本时使用，不会传给主安装器。

  当前安装器配置
    配置当前项目的安装参数。界面会按项目动态显示支持项，不支持的参数不会出现。
    常见项目参数:
      安装路径: 传给 -InstallPath。留空时使用 \$HOME/<项目默认目录>。
      安装分支: 传给 -InstallBranch，仅支持分支选择的项目会显示。
      PyTorch 镜像类型: 传给 -PyTorchMirrorType，例如 cu121、cu124、cpu。
      Python 版本: 传给 -InstallPythonVersion。
      代理和镜像: 用于 Github、HuggingFace、PyPI 等下载加速或网络环境适配。
      开关参数: 例如禁用代理、禁用镜像、跳过预下载模型、禁用环境检查等。
      主安装器自定义参数: 原样追加给主安装器，适合临时传递未内置的参数。

  启动器主配置
    当前安装器: 可重新选择当前项目，或在 CLI 中使用 null 清空当前项目。
    启动时自动检查更新: 控制是否每 60 分钟检查一次启动器更新。
    启动欢迎界面: 控制进入 TUI 时是否显示第一屏欢迎和操作提示。
    日志等级: 控制写入日志文件的最低等级，可选 DEBUG、INFO、WARN、ERROR。
    注意: 实际安装路径优先看项目配置里的安装路径；未设置才使用默认安装路径。

  安装/更新启动器
    从 https://github.com/licyk/sd-webui-all-in-one-launcher 获取最新启动器源码，
    安装到用户目录，并注册 installer-launcher 命令。
    注册命令会创建 ~/.local/bin/installer-launcher，并按当前 shell 写入 PATH 配置块。
    如果安装后当前终端还不能直接运行 installer-launcher，请重新打开终端。

  卸载启动器
    删除启动器自身安装目录、命令链接、配置目录和缓存目录。
    卸载前会先显示警告确认，再要求输入指定确认文本。
    卸载不会删除各项目本体安装目录，例如 Stable Diffusion WebUI 或 ComfyUI。
    如果卸载后当前终端仍保留旧 PATH，请重新打开终端。

  查看当前配置
    显示主配置文件、项目配置文件和当前生效的项目参数。
    当排查路径、分支、代理或镜像问题时，先看这里。

配置保存位置
  主配置:
    \${XDG_CONFIG_HOME:-\$HOME/.config}/installer-launcher/main.conf
  项目配置:
    \${XDG_CONFIG_HOME:-\$HOME/.config}/installer-launcher/projects/<project>.conf
  安装器缓存:
    \${XDG_CACHE_HOME:-\$HOME/.cache}/installer-launcher/installers/<project>/
  日志目录:
    \${XDG_STATE_HOME:-\$HOME/.local/state}/installer-launcher/logs/

日志与崩溃记录
  默认日志级别为 DEBUG，可在 "启动器主配置" 中调整为 INFO、WARN 或 ERROR。
  日志等级表示最低写入级别；例如 WARN 只写入 WARN 和 ERROR。
  日志不会自动清理旧文件。
  启动、配置变更、下载、安装、管理脚本运行、卸载和自动更新都会写入日志。
  脚本异常退出时，会记录失败命令、退出码、行号和调用栈。
  日志会脱敏代理、镜像、自定义参数以及 token/password/key 类字段。

常见情况
  提示尚未选择安装器:
    进入 "选择不同类型的安装器" 选择一个项目。

  主界面显示未安装:
    当前安装路径不存在。检查 "当前安装器配置" 中的安装路径，或直接运行安装器。

  主界面显示目录存在但缺少管理脚本:
    这个目录可能不是该项目的完整安装目录。请检查安装路径是否指向项目根目录。

  安装器运行失败:
    查看 PowerShell 输出。常见原因是网络不可用、代理/镜像配置不正确、缺少 pwsh 或 powershell。

  修改参数后没有生效:
    确认改的是正确入口:
      主安装器参数在 "当前安装器配置" 中设置。
      launch.ps1 等子脚本参数在 "调整子脚本默认启动参数" 中设置。

CLI 辅助命令
  ./installer_launcher.sh list-projects
    列出所有支持的项目 key。
  ./installer_launcher.sh set-main CURRENT_PROJECT <project>
    设置当前项目；使用 null 可清空当前项目。
  ./installer_launcher.sh set-main AUTO_UPDATE_ENABLED 0
    关闭启动时自动检查更新；使用 1 可重新开启。
  ./installer_launcher.sh set-main SHOW_WELCOME_SCREEN 0
    关闭 TUI 启动欢迎界面；使用 1 可重新开启。
  ./installer_launcher.sh set-main LOG_LEVEL INFO
    设置日志等级。可选 DEBUG、INFO、WARN、ERROR。
  ./installer_launcher.sh config [project]
    查看项目配置。未传 project 时使用当前项目。
  ./installer_launcher.sh show-log [lines]
    显示当前日志文件路径和最近日志内容，默认显示 80 行。
  ./installer_launcher.sh uninstall [project]
    卸载某个已安装软件。未传 project 时使用当前项目。
  ./installer_launcher.sh install-launcher
    从 GitHub 安装或更新启动器，并注册 installer-launcher 命令。
  ./installer_launcher.sh uninstall-launcher
    卸载启动器、移除命令注册并删除启动器配置。

按确认键关闭本帮助。
EOF
)"
  if dialog_available; then
    text_viewer "TUI 使用帮助" "$help_text"
  else
    printf '\n%s\n' "$help_text"
    read -r _ || true
  fi
}

show_welcome_screen() {
  local notice_text="${STARTUP_NOTICE:-无}" welcome_text
  [[ "${SHOW_WELCOME_SCREEN:-1}" == "1" ]] || return 0
  welcome_text="$(cat <<EOF
欢迎使用 $APP_TITLE

这是用于安装、启动和维护多个 AI WebUI / 训练工具的终端启动器。

当前版本: $APP_VERSION
当前安装器: $(current_project_label)
自动检查更新: $(flag_state "$AUTO_UPDATE_ENABLED")
日志等级: $LOG_LEVEL
更新检查间隔: 60 分钟

启动提示:
$notice_text

dialog 操作提示:
  方向键: 移动菜单项或滚动文本。
  Tab: 切换按钮。
  Enter: 确认。
  Space: 切换复选框。
  Esc: 返回或取消。

首次使用请先选择要安装的 WebUI / 工具，再进入当前安装器配置确认安装路径。
可以在 "启动器主配置" 中关闭启动欢迎界面或自动更新。
EOF
)"
  text_viewer "欢迎" "$welcome_text" || true
}

show_startup_notice_if_needed() {
  [[ -n "${STARTUP_NOTICE:-}" ]] || return 0
  [[ "${SHOW_WELCOME_SCREEN:-1}" == "1" ]] && return 0
  pause_screen "$STARTUP_NOTICE" || true
}

main_menu() {
  local choice prompt
  show_welcome_screen
  show_startup_notice_if_needed
  while true; do
    prompt="$(main_menu_status)"
    choice="$(menu_select "$APP_TITLE" "$prompt" \
      "select-project" "选择不同类型的安装器" \
      "run-installer" "下载安装器并运行" \
      "uninstall-project" "卸载当前已安装软件" \
      "manage" "运行安装后生成的管理脚本" \
      "script-args" "调整子脚本默认启动参数" \
      "project-config" "当前安装器配置" \
      "main-config" "启动器主配置" \
      "show-config" "查看当前配置" \
      "install-launcher" "安装/更新启动器" \
      "uninstall-launcher" "卸载启动器" \
      "help" "TUI 使用帮助" \
      "quit" "退出")" || return 0
    case "$choice" in
      select-project) change_current_project ;;
      run-installer)
        if ensure_current_project_selected; then
          run_installer "$CURRENT_PROJECT" || show_error "安装器运行失败。"
        fi
        ;;
      uninstall-project)
        if ensure_current_project_selected; then
          uninstall_project "$CURRENT_PROJECT" || show_error "卸载当前已安装软件失败。"
        fi
        ;;
      manage)
        if ensure_current_project_selected; then
          run_management_script "$CURRENT_PROJECT" || true
        fi
        ;;
      script-args)
        if ensure_current_project_selected; then
          configure_script_args "$CURRENT_PROJECT" || true
        fi
        ;;
      project-config) ensure_current_project_selected && configure_project "$CURRENT_PROJECT" ;;
      main-config) configure_main ;;
      show-config)
        ensure_current_project_selected || continue
        text_viewer "当前配置" "$(show_config "$CURRENT_PROJECT")" || true
        ;;
      install-launcher) install_launcher || show_error "安装/更新启动器失败。" ;;
      uninstall-launcher) uninstall_launcher || show_error "卸载启动器失败。" ;;
      help) show_tui_help || true ;;
      quit) return 0 ;;
    esac
  done
}
