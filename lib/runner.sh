#!/usr/bin/env bash

download_file() {
  local url="$1" output="$2" temp="${2}.tmp"
  mkdir -p "$(dirname "$output")"
  log_debug "download file: url=$url output=$output"
  if need_cmd curl; then
    if ! curl -fL --retry 3 --connect-timeout 20 -o "$temp" "$url"; then
      rm -f "$temp"
      log_warn "download failed with curl: url=$url"
      return 1
    fi
  elif need_cmd wget; then
    if ! wget -O "$temp" "$url"; then
      rm -f "$temp"
      log_warn "download failed with wget: url=$url"
      return 1
    fi
  else
    log_error "download failed: curl/wget not found"
    return 127
  fi
  mv "$temp" "$output"
  log_debug "download file saved: output=$output"
}

effective_install_path() {
  local key="$1"
  if [[ -n "${INSTALL_PATH:-}" ]]; then
    printf '%s' "$INSTALL_PATH"
  else
    project_default_install_path "$key"
  fi
}

installer_cache_path() {
  local key="$1"
  printf '%s/installers/%s/%s' "$CACHE_HOME" "$key" "$(project_installer_file "$key")"
}

download_installer() {
  local key="${1:-$CURRENT_PROJECT}" url output failed_urls=()
  output="$(installer_cache_path "$key")"
  mkdir -p "$(dirname "$output")"
  while IFS= read -r url; do
    [[ -n "$url" ]] || continue
    info "Downloading: $url"
    log_info "installer download attempt: project=$key url=$url"
    if download_file "$url" "$output"; then
      info "Saved to: $output"
      log_info "installer download success: project=$key url=$url output=$output"
      return 0
    fi
    failed_urls+=("$url")
    info "Download failed, trying next source."
    log_warn "installer download failed: project=$key url=$url"
  done < <(project_installer_urls "$key")

  log_error "installer download failed all sources: project=$key output=$output"
  printf 'Error: 安装器下载失败，已尝试所有下载源。\n' >&2
  for url in "${failed_urls[@]}"; do
    printf '  %s\n' "$url" >&2
  done
  return 1
}

require_pwsh() {
  need_cmd pwsh || die "未找到 pwsh。请先安装 PowerShell，再运行 PowerShell 脚本。"
}

args_contains_param() {
  local param="$1"
  shift
  local arg
  for arg in "$@"; do
    [[ "${arg,,}" == "${param,,}" ]] && return 0
  done
  return 1
}

append_no_pause_arg() {
  local key="$1" output_name="$2"
  # shellcheck disable=SC2178
  local -n output_ref="$output_name"
  project_supports_param "$key" NoPause || return 0
  args_contains_param "-NoPause" "${output_ref[@]}" && return 0
  output_ref+=("-NoPause")
}

build_installer_args() {
  local key="$1" output_name="$2"
  # shellcheck disable=SC2178
  local -n output_ref="$output_name"
  output_ref=()
  project_supports_param "$key" InstallPath && output_ref+=("-InstallPath" "$(effective_install_path "$key")")
  project_supports_param "$key" CorePrefix && [[ -n "${CORE_PREFIX:-}" ]] && output_ref+=("-CorePrefix" "$CORE_PREFIX")
  project_supports_param "$key" PyTorchMirrorType && [[ -n "${PYTORCH_MIRROR_TYPE:-}" ]] && output_ref+=("-PyTorchMirrorType" "$PYTORCH_MIRROR_TYPE")
  project_supports_param "$key" InstallPythonVersion && [[ -n "${PYTHON_VERSION:-}" ]] && output_ref+=("-InstallPythonVersion" "$PYTHON_VERSION")
  project_supports_param "$key" InstallBranch && [[ -n "${INSTALL_BRANCH:-}" ]] && output_ref+=("-InstallBranch" "$INSTALL_BRANCH")
  project_supports_param "$key" DisablePyPIMirror && [[ "${DISABLE_PYPI_MIRROR:-0}" == "1" ]] && output_ref+=("-DisablePyPIMirror")
  project_supports_param "$key" DisableProxy && [[ "${DISABLE_PROXY:-0}" == "1" ]] && output_ref+=("-DisableProxy")
  project_supports_param "$key" UseCustomProxy && [[ -n "${PROXY:-}" ]] && output_ref+=("-UseCustomProxy" "$PROXY")
  project_supports_param "$key" DisableUV && [[ "${DISABLE_UV:-0}" == "1" ]] && output_ref+=("-DisableUV")
  project_supports_param "$key" DisableGithubMirror && [[ "${DISABLE_GITHUB_MIRROR:-0}" == "1" ]] && output_ref+=("-DisableGithubMirror")
  project_supports_param "$key" UseCustomGithubMirror && [[ -n "${GITHUB_MIRROR:-}" ]] && output_ref+=("-UseCustomGithubMirror" "$GITHUB_MIRROR")
  project_supports_param "$key" NoPreDownloadExtension && [[ "${NO_PRE_DOWNLOAD_EXTENSION:-0}" == "1" ]] && output_ref+=("-NoPreDownloadExtension")
  project_supports_param "$key" NoPreDownloadNode && [[ "${NO_PRE_DOWNLOAD_NODE:-0}" == "1" ]] && output_ref+=("-NoPreDownloadNode")
  project_supports_param "$key" NoPreDownloadModel && [[ "${NO_PRE_DOWNLOAD_MODEL:-0}" == "1" ]] && output_ref+=("-NoPreDownloadModel")
  project_supports_param "$key" NoCleanCache && [[ "${NO_CLEAN_CACHE:-0}" == "1" ]] && output_ref+=("-NoCleanCache")
  project_supports_param "$key" DisableModelMirror && [[ "${DISABLE_MODEL_MIRROR:-0}" == "1" ]] && output_ref+=("-DisableModelMirror")
  project_supports_param "$key" DisableHuggingFaceMirror && [[ "${DISABLE_HUGGINGFACE_MIRROR:-0}" == "1" ]] && output_ref+=("-DisableHuggingFaceMirror")
  project_supports_param "$key" UseCustomHuggingFaceMirror && [[ -n "${HUGGINGFACE_MIRROR:-}" ]] && output_ref+=("-UseCustomHuggingFaceMirror" "$HUGGINGFACE_MIRROR")
  project_supports_param "$key" DisableCUDAMalloc && [[ "${DISABLE_CUDA_MALLOC:-0}" == "1" ]] && output_ref+=("-DisableCUDAMalloc")
  project_supports_param "$key" DisableEnvCheck && [[ "${DISABLE_ENV_CHECK:-0}" == "1" ]] && output_ref+=("-DisableEnvCheck")
  local extra_args=()
  split_args "${EXTRA_INSTALL_ARGS:-}" extra_args
  output_ref+=("${extra_args[@]}")
  append_no_pause_arg "$key" "$output_name"
}

installer_confirmation_text() {
  local key="$1" script="$2" output_name="$3" arg url
  # shellcheck disable=SC2178
  local -n args_ref="$output_name"
  cat <<EOF
即将运行安装任务，请确认配置。

项目: $(project_name "$key")
安装器缓存: $script
安装路径: $(effective_install_path "$key")

安装器下载源:
EOF
  while IFS= read -r url; do
    [[ -n "$url" ]] || continue
    printf '  %s\n' "$url"
  done < <(project_installer_urls "$key")

  cat <<EOF

PowerShell 参数:
EOF
  if [[ "${#args_ref[@]}" -eq 0 ]]; then
    printf '  无\n'
  else
    for arg in "${args_ref[@]}"; do
      printf '  %s\n' "$arg"
    done
  fi

  cat <<EOF

当前项目配置:
  INSTALL_PATH=${INSTALL_PATH:-$(project_default_install_path "$key")}
EOF
  project_supports_param "$key" InstallBranch && printf '  INSTALL_BRANCH=%s\n' "${INSTALL_BRANCH:-}"
  project_supports_param "$key" CorePrefix && printf '  CORE_PREFIX=%s\n' "${CORE_PREFIX:-}"
  project_supports_param "$key" PyTorchMirrorType && printf '  PYTORCH_MIRROR_TYPE=%s\n' "${PYTORCH_MIRROR_TYPE:-}"
  project_supports_param "$key" InstallPythonVersion && printf '  PYTHON_VERSION=%s\n' "${PYTHON_VERSION:-}"
  project_supports_param "$key" UseCustomProxy && printf '  PROXY=%s\n' "${PROXY:-}"
  project_supports_param "$key" UseCustomGithubMirror && printf '  GITHUB_MIRROR=%s\n' "${GITHUB_MIRROR:-}"
  project_supports_param "$key" UseCustomHuggingFaceMirror && printf '  HUGGINGFACE_MIRROR=%s\n' "${HUGGINGFACE_MIRROR:-}"
  printf '  EXTRA_INSTALL_ARGS=%s\n' "${EXTRA_INSTALL_ARGS:-}"

  printf '\n确认后将重新下载安装器并执行 PowerShell 脚本。\n'
}

run_pwsh_script() {
  local script_path="$1" script_dir
  shift
  require_pwsh
  [[ -f "$script_path" ]] || die "脚本不存在: $script_path"
  script_dir="$(cd "$(dirname "$script_path")" && pwd)"
  log_info "pwsh start: script=$script_path args=$(format_log_args "$@")"
  (cd "$script_dir" && pwsh -NoLogo -ExecutionPolicy Bypass -File "./$(basename "$script_path")" "$@")
}

show_pwsh_failure_notice() {
  local script_path="$1" status="$2"
  printf '\nPowerShell 脚本异常退出。\n' >&2
  printf '脚本: %s\n' "$script_path" >&2
  printf '退出代码: %s\n' "$status" >&2
  printf '\n请先查看上方 PowerShell 输出日志，确认具体失败原因。\n' >&2
  printf '按 Enter 返回启动器界面。' >&2
  if [[ -t 0 ]]; then
    read -r _ || true
  else
    printf '\n' >&2
  fi
}

run_installer() {
  local key="${1:-$CURRENT_PROJECT}" script args=() confirmation status
  load_project_config "$key"
  script="$(installer_cache_path "$key")"
  build_installer_args "$key" args
  log_info "installer prepared: project=$key script=$script install_path=$(effective_install_path "$key") args=$(format_log_args "${args[@]}")"
  confirmation="$(installer_confirmation_text "$key" "$script" args)"
  confirm_screen "确认运行安装器" "$confirmation" || {
    info "安装任务已取消。"
    log_warn "installer canceled by user: project=$key"
    return 0
  }
  if ! download_installer "$key"; then
    log_error "installer download failed before execution: project=$key"
    return 1
  fi
  if dialog_available; then
    clear || true
  fi
  info "Running: pwsh -File $script ${args[*]}"
  if run_pwsh_script "$script" "${args[@]}"; then
    log_info "installer finished: project=$key status=0"
  else
    status=$?
    log_error "installer failed: project=$key status=$status"
    show_pwsh_failure_notice "$script" "$status"
    return "$status"
  fi
}

project_uninstall_summary() {
  local key="$1" install_path="$2" confirm_text="$3"
  cat <<EOF
警告：即将卸载已安装的软件。

项目: $(project_name "$key")
安装目录: $install_path

确认后将删除该安装目录及其内部所有文件。
启动器保存的项目配置不会被删除。

此操作不可撤销。
第一步确认后，还需要输入以下内容进行最终确认:
${confirm_text}
EOF
}

validate_uninstall_path() {
  local path="$1"
  [[ -n "$path" ]] || {
    printf '卸载路径为空，拒绝执行。\n' >&2
    return 1
  }
  [[ "$path" != "/" ]] || {
    printf '卸载路径为根目录，拒绝执行。\n' >&2
    return 1
  }
  [[ "$path" != "$HOME" ]] || {
    printf '卸载路径为 HOME 目录，拒绝执行。\n' >&2
    return 1
  }
  [[ "$path" == "$HOME/"* || "$path" == /* ]] || {
    printf '卸载路径必须是绝对路径，拒绝执行: %s\n' "$path" >&2
    return 1
  }
}

uninstall_project() {
  local key="${1:-$CURRENT_PROJECT}" install_path confirm_text
  load_project_config "$key"
  install_path="$(effective_install_path "$key")"
  if ! validate_uninstall_path "$install_path"; then
    log_error "project uninstall refused unsafe path: project=$key path=$install_path"
    show_error "卸载路径不安全，已取消: $install_path"
    return 1
  fi
  [[ -e "$install_path" ]] || {
    log_warn "project uninstall missing path: project=$key path=$install_path"
    show_error "未找到安装目录: $install_path"
    return 1
  }

  confirm_text="DELETE $key"
  log_warn "project uninstall warning shown: project=$key path=$install_path"
  confirm_screen "卸载 $(project_name "$key")" "$(project_uninstall_summary "$key" "$install_path" "$confirm_text")" || {
    info "卸载任务已取消。"
    log_warn "project uninstall canceled at warning: project=$key path=$install_path"
    return 0
  }
  typed_confirm_screen "最终确认" "将删除安装目录:
$install_path

如果并非要卸载 $(project_name "$key")，请取消。" "$confirm_text" || {
    info "最终确认失败，卸载任务已取消。"
    log_warn "project uninstall final confirmation failed: project=$key path=$install_path"
    return 0
  }

  log_warn "project uninstall deleting: project=$key path=$install_path"
  rm -rf -- "$install_path"
  info "已卸载 $(project_name "$key"): $install_path"
  log_info "project uninstall finished: project=$key path=$install_path"
}

management_root_candidates() {
  printf '%s\n' "$(effective_install_path "$1")"
}

check_installation() {
  local key="${1:-$CURRENT_PROJECT}" install_path entry script_name found=0
  load_project_config "$key"
  install_path="$(effective_install_path "$key")"

  [[ -d "$install_path" ]] || {
    printf '未检测到安装目录: %s\n' "$install_path"
    return 1
  }

  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    script_name="${entry%%:*}"
    if [[ -f "$install_path/$script_name" ]]; then
      found=1
      break
    fi
  done < <(script_entries_for_project "$key")

  if [[ "$found" -eq 1 ]]; then
    printf '已安装: %s\n安装路径: %s\n' "$(project_name "$key")" "$install_path"
    return 0
  fi

  printf '检测到安装目录，但未找到管理脚本: %s\n' "$install_path"
  return 2
}

find_management_script() {
  local key="$1" script_name="$2" root
  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    if [[ -f "$root/$script_name" ]]; then
      printf '%s' "$root/$script_name"
      return 0
    fi
  done < <(management_root_candidates "$key")
  return 1
}

get_script_args() {
  local var
  var="$(script_arg_var_name "$1")"
  printf '%s' "${!var:-}"
}

set_script_args() {
  local var
  var="$(script_arg_var_name "$1")"
  printf -v "$var" '%s' "$2"
}

show_management_script_hint() {
  case "$1" in
    launch.ps1)
      confirm_screen "继续运行 launch.ps1" "即将运行 launch.ps1 启动当前 WebUI / 工具。

运行开始后，PowerShell 输出会显示在当前终端中。
如果需要终止运行中的服务，可以在终端按 Ctrl+C。

选择 Yes / 确认，或在文本模式输入 y 后回车，即可继续运行。
选择 No / 取消会返回启动器，不会执行脚本。"
      ;;
    terminal.ps1)
      confirm_screen "继续打开 terminal.ps1" "即将打开 terminal.ps1 交互终端。

打开后可以在已激活的项目环境中输入命令并回车执行。
需要退出交互终端时，输入 exit 并回车。

选择 Yes / 确认，或在文本模式输入 y 后回车，即可继续打开。
选择 No / 取消会返回启动器，不会执行脚本。"
      ;;
  esac
}

run_management_script() {
  local key="${1:-$CURRENT_PROJECT}" script_name="${2:-}" args_raw="${3-}" script_path args=() status
  load_project_config "$key"
  [[ -n "$script_name" ]] || script_name="$(select_management_script "$key")" || return 0
  [[ -n "${args_raw:-}" ]] || args_raw="$(get_script_args "$script_name")"
  if ! script_path="$(find_management_script "$key" "$script_name")"; then
    log_error "management script not found: project=$key script=$script_name install_path=$(effective_install_path "$key")"
    show_error "未找到 $script_name。请先运行安装器，或检查 INSTALL_PATH。"
    return 1
  fi
  split_args "$args_raw" args
  append_no_pause_arg "$key" args
  log_info "management script prepared: project=$key script=$script_name path=$script_path args=$(format_log_args "${args[@]}")"
  if dialog_available; then
    clear || true
  fi
  if ! show_management_script_hint "$script_name"; then
    log_info "management script canceled at hint: project=$key script=$script_name"
    info "已取消运行 $script_name。"
    return 0
  fi
  info "Running: pwsh -File $script_path ${args[*]}"
  if run_pwsh_script "$script_path" "${args[@]}"; then
    log_info "management script finished: project=$key script=$script_name status=0"
  else
    status=$?
    log_error "management script failed: project=$key script=$script_name status=$status"
    show_pwsh_failure_notice "$script_path" "$status"
    return "$status"
  fi
}
