#!/usr/bin/env bash

if [[ "$(uname -s 2>/dev/null)" == "Darwin" && "${BASH_VERSINFO[0]}" -lt 5 ]]; then
  HOMEBREW_BASH="/opt/homebrew/bin/bash"
  if [[ -x "$HOMEBREW_BASH" && "${BASH:-}" != "$HOMEBREW_BASH" ]]; then
    exec "$HOMEBREW_BASH" "$0" "$@"
  fi
  printf 'Error: macOS 自带 Bash 版本过低，需要 Bash >= 5。\n' >&2
  printf '请先使用 Homebrew 安装 Bash: brew install bash\n' >&2
  printf '安装后请确认解释器存在: /opt/homebrew/bin/bash\n' >&2
  exit 1
fi

set -Eeuo pipefail

early_log() {
  local log_dir log_file message="$*"
  message="$(printf '%s' "$message" | sed -E 's#(token|password|passwd|secret|api_key|access_key|private_key)=([^[:space:]]+)#\1=<redacted>#Ig')"
  message="$(printf '%s' "$message" | sed -E 's#(https?://)[^/@[:space:]]+:[^/@[:space:]]+@#\1<redacted>@#Ig')"
  log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/installer-launcher/logs"
  mkdir -p "$log_dir" 2>/dev/null || return 0
  log_file="${log_dir}/installer-launcher-$(date +%Y%m%d).log"
  printf '%s | ERROR | pid=%s | bootstrap | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$$" "$message" >>"$log_file" 2>/dev/null || true
}

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_LINK_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" == /* ]] || SCRIPT_PATH="$SCRIPT_LINK_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/lib/bootstrap.sh" ]]; then
  DEFAULT_SCRIPT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/installer-launcher"
  if [[ -f "$DEFAULT_SCRIPT_DIR/lib/bootstrap.sh" ]]; then
    SCRIPT_DIR="$DEFAULT_SCRIPT_DIR"
  fi
fi

if [[ ! -f "$SCRIPT_DIR/lib/bootstrap.sh" ]]; then
  early_log "missing bootstrap: script_dir=$SCRIPT_DIR default_dir=${XDG_DATA_HOME:-$HOME/.local/share}/installer-launcher args=$*"
  printf 'Error: 无法找到启动器模块: %s/lib/bootstrap.sh\n' "$SCRIPT_DIR" >&2
  printf '已尝试默认安装目录: %s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/installer-launcher" >&2
  exit 1
fi

# shellcheck disable=SC1091
# shellcheck source=lib/bootstrap.sh
source "$SCRIPT_DIR/lib/bootstrap.sh"

main "$@"
