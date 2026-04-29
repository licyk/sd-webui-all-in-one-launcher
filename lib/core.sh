#!/usr/bin/env bash
# shellcheck disable=SC2034

APP_NAME="installer-launcher"
APP_TITLE="Installer Launcher"
APP_VERSION="0.3.0"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/${APP_NAME}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/${APP_NAME}"
MAIN_CONFIG_FILE="${CONFIG_HOME}/main.conf"
PROJECT_CONFIG_DIR="${CONFIG_HOME}/projects"
AUTO_UPDATE_INTERVAL_SECONDS=3600

HAS_DIALOG=0
CURRENT_PROJECT=""
AUTO_UPDATE_ENABLED=1
SHOW_WELCOME_SCREEN=1
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
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
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
