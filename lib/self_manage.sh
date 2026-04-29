#!/usr/bin/env bash

SELF_REPO="licyk/sd-webui-all-in-one-launcher"
SELF_REPO_URL="https://github.com/${SELF_REPO}.git"
SELF_ARCHIVE_URL="https://github.com/${SELF_REPO}/archive/refs/heads/main.tar.gz"
SELF_REMOTE_CORE_URL="https://raw.githubusercontent.com/${SELF_REPO}/main/lib/core.sh"
SELF_COMMAND_NAME="installer-launcher"
SELF_INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/${APP_NAME}"
SELF_BIN_DIR="$HOME/.local/bin"
SELF_COMMAND_PATH="${SELF_BIN_DIR}/${SELF_COMMAND_NAME}"
SELF_PATH_MARK_BEGIN="# >>> ${APP_NAME} >>>"
SELF_PATH_MARK_END="# <<< ${APP_NAME} <<<"

launcher_progress() {
  local message="$1"
  log_info "$message"
  printf '%s\n' "$message" >&2
}

launcher_shell_rc_file() {
  local shell_name
  shell_name="$(basename "${SHELL:-}")"
  case "$shell_name" in
    zsh) printf '%s/.zshrc' "$HOME" ;;
    bash) printf '%s/.bashrc' "$HOME" ;;
    *) printf '%s/.profile' "$HOME" ;;
  esac
}

launcher_shell_rc_candidates() {
  printf '%s\n' "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"
}

download_launcher_source() {
  local target_dir="$1" archive_path
  mkdir -p "$target_dir"
  log_info "launcher source download start: target=$target_dir"
  launcher_progress "正在获取启动器源码..."

  if need_cmd git; then
    log_debug "launcher source download using git: repo=$SELF_REPO_URL"
    launcher_progress "使用 git 从 GitHub 克隆启动器源码..."
    git clone --depth 1 "$SELF_REPO_URL" "$target_dir"
    log_info "launcher source download success with git: target=$target_dir"
    return 0
  fi

  need_cmd tar || die "未找到 git 或 tar，无法安装启动器。"
  archive_path="${target_dir}.tar.gz"
  log_debug "launcher source download using archive: url=$SELF_ARCHIVE_URL"
  launcher_progress "未找到 git，正在下载启动器源码压缩包..."
  download_file "$SELF_ARCHIVE_URL" "$archive_path"
  launcher_progress "正在解压启动器源码..."
  tar -xzf "$archive_path" --strip-components=1 -C "$target_dir"
  rm -f "$archive_path"
  log_info "launcher source download success with archive: target=$target_dir"
}

install_launcher_files() {
  local source_dir="$1" stage_dir backup_dir
  stage_dir="${SELF_INSTALL_DIR}.tmp.$$"
  backup_dir="${SELF_INSTALL_DIR}.bak.$$"

  rm -rf "$stage_dir" "$backup_dir"
  mkdir -p "$(dirname "$SELF_INSTALL_DIR")" "$stage_dir"
  log_info "launcher install files: source=$source_dir target=$SELF_INSTALL_DIR"
  launcher_progress "正在安装启动器文件到: $SELF_INSTALL_DIR"
  cp -R "$source_dir/." "$stage_dir"
  rm -rf "$stage_dir/.git"
  chmod +x "$stage_dir/installer_launcher.sh"

  if [[ -e "$SELF_INSTALL_DIR" || -L "$SELF_INSTALL_DIR" ]]; then
    mv "$SELF_INSTALL_DIR" "$backup_dir"
  fi
  mv "$stage_dir" "$SELF_INSTALL_DIR"
  rm -rf "$backup_dir"
  log_info "launcher install files complete: target=$SELF_INSTALL_DIR"
}

register_launcher_command() {
  local rc_file
  mkdir -p "$SELF_BIN_DIR"
  ln -sfn "$SELF_INSTALL_DIR/installer_launcher.sh" "$SELF_COMMAND_PATH"
  log_info "launcher command registered: command=$SELF_COMMAND_PATH target=$SELF_INSTALL_DIR/installer_launcher.sh"
  launcher_progress "正在注册命令: $SELF_COMMAND_PATH"

  rc_file="$(launcher_shell_rc_file)"
  mkdir -p "$(dirname "$rc_file")"
  touch "$rc_file"
  if ! grep -Fqx "$SELF_PATH_MARK_BEGIN" "$rc_file"; then
    {
      printf '\n%s\n' "$SELF_PATH_MARK_BEGIN"
      # shellcheck disable=SC2016
      printf 'export PATH="$HOME/.local/bin:$PATH"\n'
      printf '%s\n' "$SELF_PATH_MARK_END"
    } >>"$rc_file"
    log_info "launcher PATH block added: rc_file=$rc_file"
    launcher_progress "已写入 PATH 注册块: $rc_file"
  else
    log_debug "launcher PATH block already exists: rc_file=$rc_file"
    launcher_progress "PATH 注册块已存在: $rc_file"
  fi
}

remove_launcher_path_block() {
  local file="$1" temp_file
  [[ -f "$file" ]] || return 0
  grep -Fqx "$SELF_PATH_MARK_BEGIN" "$file" || return 0
  temp_file="$(mktemp "${TMPDIR:-/tmp}/installer-launcher-rc.XXXXXX")" || return 1
  awk -v begin="$SELF_PATH_MARK_BEGIN" -v end="$SELF_PATH_MARK_END" '
    $0 == begin { skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping { print }
  ' "$file" >"$temp_file"
  mv "$temp_file" "$file"
}

unregister_launcher_command() {
  local rc_file
  if [[ -L "$SELF_COMMAND_PATH" ]]; then
    rm -f "$SELF_COMMAND_PATH"
    log_info "launcher command link removed: $SELF_COMMAND_PATH"
  elif [[ -e "$SELF_COMMAND_PATH" ]]; then
    info "跳过删除非符号链接命令文件: $SELF_COMMAND_PATH"
    log_warn "launcher command path is not symlink, skipped: $SELF_COMMAND_PATH"
  fi

  while IFS= read -r rc_file; do
    remove_launcher_path_block "$rc_file"
  done < <(launcher_shell_rc_candidates)
}

launcher_installation_summary() {
  local rc_file
  rc_file="$(launcher_shell_rc_file)"
  cat <<EOF
即将安装或更新启动器。

来源仓库: https://github.com/${SELF_REPO}
安装目录: $SELF_INSTALL_DIR
注册命令: $SELF_COMMAND_PATH
Shell 配置: $rc_file

确认后会从 GitHub 获取最新源码，并将 $SELF_COMMAND_NAME 注册到 shell。
EOF
}

launcher_uninstall_summary() {
  local confirm_text="$1"
  cat <<EOF
即将卸载启动器。

将删除:
  安装目录: $SELF_INSTALL_DIR
  命令链接: $SELF_COMMAND_PATH
  配置目录: $CONFIG_HOME
  缓存目录: $CACHE_HOME

还会从以下 shell 配置文件中移除启动器 PATH 注册块:
  $HOME/.bashrc
  $HOME/.zshrc
  $HOME/.profile

项目本体安装目录不会被删除，例如 Stable Diffusion WebUI、ComfyUI 等。

此操作不可撤销。
第一步确认后，还需要输入以下内容进行最终确认:
${confirm_text}
EOF
}

install_launcher_from_source() {
  local temp_dir source_dir
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/installer-launcher-src.XXXXXX")" || return 1
  source_dir="$temp_dir/source"
  log_info "launcher install from source start: temp=$temp_dir"
  launcher_progress "开始安装/更新启动器..."
  if ! download_launcher_source "$source_dir"; then
    rm -rf "$temp_dir"
    log_error "launcher install failed while downloading source"
    return 1
  fi
  if ! install_launcher_files "$source_dir"; then
    rm -rf "$temp_dir"
    log_error "launcher install failed while installing files"
    return 1
  fi
  if ! register_launcher_command; then
    rm -rf "$temp_dir"
    log_error "launcher install failed while registering command"
    return 1
  fi
  rm -rf "$temp_dir"
  log_info "launcher install from source finished"
  launcher_progress "启动器安装/更新流程完成。"
}

install_launcher() {
  confirm_screen "安装/更新启动器" "$(launcher_installation_summary)" || {
    info "安装启动器已取消。"
    log_warn "launcher install canceled by user"
    return 0
  }

  if ! install_launcher_from_source; then
    log_error "launcher install failed"
    return 1
  fi

  info "启动器已安装: $SELF_INSTALL_DIR"
  info "命令已注册: $SELF_COMMAND_NAME"
  info "如果当前 shell 还不能直接运行该命令，请重新打开终端或执行: source $(launcher_shell_rc_file)"
}

uninstall_launcher() {
  local confirm_text="DELETE installer-launcher"
  log_warn "launcher uninstall warning shown: install_dir=$SELF_INSTALL_DIR config=$CONFIG_HOME cache=$CACHE_HOME"
  confirm_screen "卸载启动器" "$(launcher_uninstall_summary "$confirm_text")" || {
    info "卸载启动器已取消。"
    log_warn "launcher uninstall canceled at warning"
    return 0
  }
  typed_confirm_screen "最终确认" "将删除启动器安装目录、命令链接、配置目录和缓存目录。

项目本体安装目录不会被删除。" "$confirm_text" || {
    info "最终确认失败，卸载启动器已取消。"
    log_warn "launcher uninstall final confirmation failed"
    return 0
  }

  log_warn "launcher uninstall deleting: install_dir=$SELF_INSTALL_DIR config=$CONFIG_HOME cache=$CACHE_HOME"
  unregister_launcher_command
  rm -rf "$SELF_INSTALL_DIR" "$CONFIG_HOME" "$CACHE_HOME"

  info "启动器已卸载。"
  info "如果当前 shell 仍保留旧 PATH，请重新打开终端。"
}

parse_app_version_from_file() {
  local file="$1" line version
  line="$(grep -E '^APP_VERSION=' "$file" | head -n 1)" || return 1
  version="${line#APP_VERSION=}"
  version="${version%\"}"
  version="${version#\"}"
  [[ -n "$version" ]] || return 1
  printf '%s' "$version"
}

fetch_remote_launcher_version() {
  local temp_file version
  temp_file="$(mktemp "${TMPDIR:-/tmp}/installer-launcher-core.XXXXXX")" || return 1
  log_debug "fetch remote launcher version: url=$SELF_REMOTE_CORE_URL"
  if ! download_file "$SELF_REMOTE_CORE_URL" "$temp_file"; then
    rm -f "$temp_file"
    return 1
  fi
  if ! version="$(parse_app_version_from_file "$temp_file")"; then
    rm -f "$temp_file"
    return 1
  fi
  rm -f "$temp_file"
  log_info "remote launcher version fetched: version=$version"
  printf '%s' "$version"
}

version_is_newer() {
  local remote="$1" local_version="$2" index remote_part local_part
  local remote_parts=() local_parts=()
  IFS=. read -r -a remote_parts <<<"$remote"
  IFS=. read -r -a local_parts <<<"$local_version"
  for index in 0 1 2; do
    remote_part="${remote_parts[$index]:-0}"
    local_part="${local_parts[$index]:-0}"
    [[ "$remote_part" =~ ^[0-9]+$ ]] || remote_part=0
    [[ "$local_part" =~ ^[0-9]+$ ]] || local_part=0
    (( remote_part > local_part )) && return 0
    (( remote_part < local_part )) && return 1
  done
  return 1
}

launcher_update_check_due() {
  local now last_check
  [[ "${AUTO_UPDATE_ENABLED:-1}" == "1" ]] || return 1
  now="$(date +%s)"
  last_check="${AUTO_UPDATE_LAST_CHECK:-0}"
  [[ "$last_check" =~ ^[0-9]+$ ]] || last_check=0
  (( now - last_check >= AUTO_UPDATE_INTERVAL_SECONDS ))
}

append_startup_notice() {
  local message="$1"
  if [[ -n "${STARTUP_NOTICE:-}" ]]; then
    STARTUP_NOTICE="${STARTUP_NOTICE}
${message}"
  else
    STARTUP_NOTICE="$message"
  fi
}

check_and_update_launcher_if_due() {
  local now remote_version
  launcher_update_check_due || return 0

  now="$(date +%s)"
  AUTO_UPDATE_LAST_CHECK="$now"
  save_main_config
  log_info "auto update check started"
  printf '正在检查启动器更新...\n' >&2

  if ! remote_version="$(fetch_remote_launcher_version 2>/dev/null)"; then
    printf '自动更新检查失败，继续运行当前版本。\n' >&2
    append_startup_notice "自动更新检查失败：无法获取远程版本。将继续运行当前版本。"
    log_warn "auto update check failed: unable to fetch remote version"
    return 0
  fi

  if ! version_is_newer "$remote_version" "$APP_VERSION"; then
    printf '启动器已是最新版本: %s\n' "$APP_VERSION" >&2
    log_debug "auto update not needed: local=$APP_VERSION remote=$remote_version"
    return 0
  fi

  log_info "auto update available: local=$APP_VERSION remote=$remote_version"
  printf '检测到启动器新版本: %s -> %s，正在自动更新...\n' "$APP_VERSION" "$remote_version" >&2
  if install_launcher_from_source; then
    printf '启动器已自动更新到 %s。重新打开终端后将使用新版本。\n' "$remote_version" >&2
    append_startup_notice "检测到新版本 $remote_version，已自动更新启动器。重新打开终端后将使用新版本。"
    log_info "auto update success: remote=$remote_version"
  else
    printf '启动器自动更新失败，继续运行当前版本。\n' >&2
    append_startup_notice "检测到新版本 $remote_version，但自动更新失败。将继续运行当前版本。"
    log_error "auto update failed: remote=$remote_version"
  fi
}
