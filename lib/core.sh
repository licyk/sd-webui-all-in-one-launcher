#!/usr/bin/env bash
# shellcheck disable=SC2034

APP_NAME="installer-launcher"
APP_TITLE="SD WebUI All In One Installer Launcher"
APP_VERSION="0.3.2"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/${APP_NAME}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/${APP_NAME}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/${APP_NAME}"
LOG_DIR="${STATE_HOME}/logs"
LOG_FILE=""
LOG_LEVEL="DEBUG"
LOG_INITIALIZED=0
LOG_WRITE_FAILED=0
ORIGINAL_ARGS=()
MAIN_CONFIG_FILE="${CONFIG_HOME}/main.conf"
PROJECT_CONFIG_DIR="${CONFIG_HOME}/projects"
AUTO_UPDATE_INTERVAL_SECONDS=3600

HAS_DIALOG=0
CURRENT_PROJECT=""
AUTO_UPDATE_ENABLED=1
SHOW_WELCOME_SCREEN=1
PROXY_MODE="auto"
MANUAL_PROXY=""
AUTO_UPDATE_LAST_CHECK=0
STARTUP_NOTICE=""

PROJECT_CONFIG_KEYS=(
  INSTALL_PATH INSTALL_BRANCH CORE_PREFIX PYTORCH_MIRROR_TYPE PYTHON_VERSION
  PROXY GITHUB_MIRROR HUGGINGFACE_MIRROR EXTRA_INSTALL_ARGS
  DISABLE_PYPI_MIRROR DISABLE_PROXY DISABLE_UV DISABLE_GITHUB_MIRROR
  DISABLE_MODEL_MIRROR DISABLE_HUGGINGFACE_MIRROR DISABLE_CUDA_MALLOC
  DISABLE_ENV_CHECK NO_PRE_DOWNLOAD_EXTENSION NO_PRE_DOWNLOAD_NODE
  NO_PRE_DOWNLOAD_MODEL NO_CLEAN_CACHE
)

die() {
  log_error "$*"
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

info() {
  log_info "$*"
  printf '%s\n' "$*"
}

log_level_value() {
  case "${1:-INFO}" in
    DEBUG) printf '10' ;;
    INFO) printf '20' ;;
    WARN) printf '30' ;;
    ERROR) printf '40' ;;
    *) printf '20' ;;
  esac
}

normalize_log_level() {
  local value="${1:-DEBUG}"
  case "${value^^}" in
    DEBUG|INFO|WARN|ERROR) printf '%s' "${value^^}" ;;
    *) return 1 ;;
  esac
}

log_should_write() {
  local message_level="$1" configured_level="${LOG_LEVEL:-DEBUG}"
  local message_value configured_value
  message_value="$(log_level_value "$message_level")"
  configured_value="$(log_level_value "$configured_level")"
  (( message_value >= configured_value ))
}

sanitize_log_message() {
  local message="$*"
  message="$(printf '%s' "$message" | sed -E 's#(token|password|passwd|secret|api_key|access_key|private_key)=([^[:space:]]+)#\1=<redacted>#Ig')"
  message="$(printf '%s' "$message" | sed -E 's#(token|password|passwd|secret|api_key|access_key|private_key):([^[:space:]]+)#\1:<redacted>#Ig')"
  message="$(printf '%s' "$message" | sed -E 's#(https?://)[^/@[:space:]]+:[^/@[:space:]]+@#\1<redacted>@#Ig')"
  printf '%s' "$message"
}

log_context() {
  local depth=3
  [[ -n "${BASH_SOURCE[$depth]:-}" ]] || depth=2
  local source="${BASH_SOURCE[$depth]:-main}" line="${BASH_LINENO[$((depth - 1))]:-0}" func="${FUNCNAME[$depth]:-main}"
  printf '%s:%s:%s' "$(basename "$source")" "$line" "$func"
}

init_logging() {
  mkdir -p "$LOG_DIR" || {
    [[ "$LOG_WRITE_FAILED" -eq 1 ]] || printf 'Warning: 无法创建日志目录: %s\n' "$LOG_DIR" >&2
    LOG_WRITE_FAILED=1
    return 0
  }
  LOG_FILE="${LOG_DIR}/installer-launcher-$(date +%Y%m%d).log"
  touch "$LOG_FILE" 2>/dev/null || {
    [[ "$LOG_WRITE_FAILED" -eq 1 ]] || printf 'Warning: 无法写入日志文件: %s\n' "$LOG_FILE" >&2
    LOG_WRITE_FAILED=1
    return 0
  }
  LOG_INITIALIZED=1
  log_debug "logging initialized: file=$LOG_FILE level=$LOG_LEVEL"
}

write_log() {
  local level="$1"
  shift
  local message timestamp context
  [[ "$LOG_INITIALIZED" -eq 1 ]] || return 0
  log_should_write "$level" || return 0
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  context="$(log_context)"
  message="$(sanitize_log_message "$*")"
  printf '%s | %s | pid=%s | %s | %s\n' "$timestamp" "$level" "$$" "$context" "$message" >>"$LOG_FILE" 2>/dev/null || {
    [[ "$LOG_WRITE_FAILED" -eq 1 ]] || printf 'Warning: 无法写入日志文件: %s\n' "$LOG_FILE" >&2
    LOG_WRITE_FAILED=1
  }
}

log_debug() { write_log DEBUG "$*"; }
log_info() { write_log INFO "$*"; }
log_warn() { write_log WARN "$*"; }
log_error() { write_log ERROR "$*"; }

format_log_args() {
  local output=() arg redact_next=0 lower_arg
  for arg in "$@"; do
    if [[ "$redact_next" -eq 1 ]]; then
      output+=("<redacted>")
      redact_next=0
      continue
    fi
    lower_arg="${arg,,}"
    case "$lower_arg" in
      -usecustomproxy|-usecustomgithubmirror|-usecustomhuggingfacemirror|proxy|github_mirror|huggingface_mirror|extra_install_args)
        output+=("$(sanitize_log_message "$arg")")
        redact_next=1
        ;;
      *token=*|*password=*|*passwd=*|*secret=*|*key=*|*token:*|*password:*|*passwd:*|*secret:*|*key:*)
        output+=("$(sanitize_log_message "$arg")")
        ;;
      *token*|*password*|*passwd*|*secret*|*key*)
        output+=("$(sanitize_log_message "$arg")")
        redact_next=1
        ;;
      *) output+=("$(sanitize_log_message "$arg")") ;;
    esac
  done
  printf '%s' "${output[*]}"
}

sanitize_config_log_value() {
  local key="$1" value="$2"
  case "$key" in
    PROXY|MANUAL_PROXY|GITHUB_MIRROR|HUGGINGFACE_MIRROR|EXTRA_INSTALL_ARGS) printf '<redacted>' ;;
    *) sanitize_log_message "$value" ;;
  esac
}

normalize_proxy_mode() {
  local value="${1:-auto}"
  case "${value,,}" in
    auto|manual|off) printf '%s' "${value,,}" ;;
    none|disabled|disable|false|0) printf 'off' ;;
    *) return 1 ;;
  esac
}

log_call_stack() {
  local index stack=""
  for ((index = 1; index < ${#FUNCNAME[@]}; index++)); do
    stack+="${FUNCNAME[$index]}:${BASH_LINENO[$((index - 1))]} "
  done
  printf '%s' "$stack"
}

log_crash() {
  local exit_code="$1" line_no="$2" command="$3"
  trap - ERR
  log_error "crash captured: exit=$exit_code line=$line_no command=$(sanitize_log_message "$command") args=$(format_log_args "${ORIGINAL_ARGS[@]}") stack=$(log_call_stack)"
}

register_crash_trap() {
  trap 'log_crash "$?" "$LINENO" "$BASH_COMMAND"' ERR
}

show_log() {
  local lines="${1:-80}"
  [[ "$lines" =~ ^[0-9]+$ ]] || lines=80
  init_logging
  printf 'Log file: %s\n' "$LOG_FILE"
  if [[ -f "$LOG_FILE" ]]; then
    tail -n "$lines" "$LOG_FILE"
  fi
}

normalize_project_key_value() {
  local value="${1:-}"
  case "${value,,}" in
    ""|null|none|nil|undefined) printf '' ;;
    *) printf '%s' "$value" ;;
  esac
}

require_project_key() {
  local key="${1:-}"
  key="$(normalize_project_key_value "$key")"
  [[ -n "$key" ]] || die "尚未选择安装器，请先运行 '$0 set-main CURRENT_PROJECT <project>' 或在 TUI 中选择安装器。"
  project_name "$key" >/dev/null || die "未知安装器: $key"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

quote_config() {
  printf '%q' "$1"
}

script_arg_var_name() {
  local safe
  safe="$(printf '%s' "$1" | tr '[:lower:].-' '[:upper:]__' | tr -c 'A-Z0-9_' '_')"
  printf 'SCRIPT_ARGS_%s' "$safe"
}

split_args() {
  local raw="$1" output_name="$2"
  # shellcheck disable=SC2178
  local -n output_ref="$output_name"
  output_ref=()
  [[ -z "$raw" ]] && return 0
  # Intentionally honor shell-like quoting in user-configured argument strings.
  eval "output_ref=($raw)"
}
