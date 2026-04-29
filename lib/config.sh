#!/usr/bin/env bash
# shellcheck disable=SC2034

ensure_main_config() {
  mkdir -p "$CONFIG_HOME" "$PROJECT_CONFIG_DIR"
  if [[ ! -f "$MAIN_CONFIG_FILE" ]]; then
    log_info "create main config: $MAIN_CONFIG_FILE"
    {
      printf 'CURRENT_PROJECT=""\n'
      printf 'AUTO_UPDATE_ENABLED="1"\n'
      printf 'SHOW_WELCOME_SCREEN="1"\n'
      printf 'LOG_LEVEL="DEBUG"\n'
      printf 'AUTO_UPDATE_LAST_CHECK="0"\n'
    } >"$MAIN_CONFIG_FILE"
  fi
}

ensure_project_config() {
  local key="$1" file branch
  file="$(project_config_file "$key")"
  branch="$(project_default_branch "$key")"
  mkdir -p "$PROJECT_CONFIG_DIR"
  if [[ ! -f "$file" ]]; then
    log_info "create project config: project=$key file=$file"
    {
      printf 'INSTALL_PATH=""\n'
      printf 'INSTALL_BRANCH=%s\n' "$(quote_config "$branch")"
      printf 'CORE_PREFIX=""\n'
      printf 'PYTORCH_MIRROR_TYPE=""\n'
      printf 'PYTHON_VERSION=""\n'
      printf 'PROXY=""\n'
      printf 'GITHUB_MIRROR=""\n'
      printf 'HUGGINGFACE_MIRROR=""\n'
      printf 'EXTRA_INSTALL_ARGS=""\n'
      printf 'DISABLE_PYPI_MIRROR="0"\n'
      printf 'DISABLE_PROXY="0"\n'
      printf 'DISABLE_UV="0"\n'
      printf 'DISABLE_GITHUB_MIRROR="0"\n'
      printf 'DISABLE_MODEL_MIRROR="0"\n'
      printf 'DISABLE_HUGGINGFACE_MIRROR="0"\n'
      printf 'DISABLE_CUDA_MALLOC="0"\n'
      printf 'DISABLE_ENV_CHECK="0"\n'
      printf 'NO_PRE_DOWNLOAD_EXTENSION="0"\n'
      printf 'NO_PRE_DOWNLOAD_NODE="0"\n'
      printf 'NO_PRE_DOWNLOAD_MODEL="0"\n'
      printf 'NO_CLEAN_CACHE="0"\n'
    } >"$file"
  fi
}

load_log_level_hint() {
  local saved_level
  [[ -f "$MAIN_CONFIG_FILE" ]] || return 0
  # shellcheck disable=SC1090
  source "$MAIN_CONFIG_FILE"
  if saved_level="$(normalize_log_level "${LOG_LEVEL:-DEBUG}")"; then
    LOG_LEVEL="$saved_level"
  else
    LOG_LEVEL="DEBUG"
  fi
}

load_main_config() {
  ensure_main_config
  # shellcheck disable=SC1090
  source "$MAIN_CONFIG_FILE"
  CURRENT_PROJECT="$(normalize_project_key_value "${CURRENT_PROJECT:-}")"
  AUTO_UPDATE_ENABLED="${AUTO_UPDATE_ENABLED:-1}"
  SHOW_WELCOME_SCREEN="${SHOW_WELCOME_SCREEN:-1}"
  if ! LOG_LEVEL="$(normalize_log_level "${LOG_LEVEL:-DEBUG}")"; then
    LOG_LEVEL="DEBUG"
    log_warn "invalid LOG_LEVEL in main config, reset to DEBUG"
  fi
  AUTO_UPDATE_LAST_CHECK="${AUTO_UPDATE_LAST_CHECK:-0}"
}

save_main_config() {
  mkdir -p "$CONFIG_HOME"
  {
    printf 'CURRENT_PROJECT=%s\n' "$(quote_config "$CURRENT_PROJECT")"
    printf 'AUTO_UPDATE_ENABLED=%s\n' "$(quote_config "$AUTO_UPDATE_ENABLED")"
    printf 'SHOW_WELCOME_SCREEN=%s\n' "$(quote_config "$SHOW_WELCOME_SCREEN")"
    printf 'LOG_LEVEL=%s\n' "$(quote_config "$LOG_LEVEL")"
    printf 'AUTO_UPDATE_LAST_CHECK=%s\n' "$(quote_config "$AUTO_UPDATE_LAST_CHECK")"
  } >"$MAIN_CONFIG_FILE"
  log_debug "saved main config: file=$MAIN_CONFIG_FILE current_project=${CURRENT_PROJECT:-<none>} auto_update=$AUTO_UPDATE_ENABLED welcome=$SHOW_WELCOME_SCREEN log_level=$LOG_LEVEL last_check=$AUTO_UPDATE_LAST_CHECK"
}

reset_project_config_vars() {
  INSTALL_PATH=""
  INSTALL_BRANCH=""
  CORE_PREFIX=""
  PYTORCH_MIRROR_TYPE=""
  PYTHON_VERSION=""
  PROXY=""
  GITHUB_MIRROR=""
  HUGGINGFACE_MIRROR=""
  EXTRA_INSTALL_ARGS=""
  DISABLE_PYPI_MIRROR=0
  DISABLE_PROXY=0
  DISABLE_UV=0
  DISABLE_GITHUB_MIRROR=0
  DISABLE_MODEL_MIRROR=0
  DISABLE_HUGGINGFACE_MIRROR=0
  DISABLE_CUDA_MALLOC=0
  DISABLE_ENV_CHECK=0
  NO_PRE_DOWNLOAD_EXTENSION=0
  NO_PRE_DOWNLOAD_NODE=0
  NO_PRE_DOWNLOAD_MODEL=0
  NO_CLEAN_CACHE=0
}

load_project_config() {
  local key="$1"
  require_project_key "$key"
  reset_project_config_vars
  ensure_project_config "$key"
  # shellcheck disable=SC1090
  source "$(project_config_file "$key")"
  INSTALL_BRANCH="${INSTALL_BRANCH:-$(project_default_branch "$key")}"
}

save_project_config() {
  local key="$1" file config_key entry script var
  file="$(project_config_file "$key")"
  mkdir -p "$PROJECT_CONFIG_DIR"
  {
    for config_key in "${PROJECT_CONFIG_KEYS[@]}"; do
      printf '%s=%s\n' "$config_key" "$(quote_config "${!config_key:-}")"
    done
    while IFS= read -r entry; do
      [[ -n "$entry" ]] || continue
      script="${entry%%:*}"
      var="$(script_arg_var_name "$script")"
      printf '%s=%s\n' "$var" "$(quote_config "${!var:-}")"
    done < <(script_entries_for_project "$key")
  } >"$file"
  log_debug "saved project config: project=$key file=$file install_path=${INSTALL_PATH:-<default>} branch=${INSTALL_BRANCH:-<none>} extra_args=$(sanitize_config_log_value EXTRA_INSTALL_ARGS "${EXTRA_INSTALL_ARGS:-}")"
}

load_all_config() {
  load_main_config
  if [[ -n "$CURRENT_PROJECT" ]] && project_name "$CURRENT_PROJECT" >/dev/null 2>&1; then
    load_project_config "$CURRENT_PROJECT"
  else
    reset_project_config_vars
  fi
}

config_key_param_name() {
  case "$1" in
    INSTALL_PATH) printf 'InstallPath' ;;
    INSTALL_BRANCH) printf 'InstallBranch' ;;
    CORE_PREFIX) printf 'CorePrefix' ;;
    PYTORCH_MIRROR_TYPE) printf 'PyTorchMirrorType' ;;
    PYTHON_VERSION) printf 'InstallPythonVersion' ;;
    PROXY) printf 'UseCustomProxy' ;;
    GITHUB_MIRROR) printf 'UseCustomGithubMirror' ;;
    HUGGINGFACE_MIRROR) printf 'UseCustomHuggingFaceMirror' ;;
    DISABLE_PYPI_MIRROR) printf 'DisablePyPIMirror' ;;
    DISABLE_PROXY) printf 'DisableProxy' ;;
    DISABLE_UV) printf 'DisableUV' ;;
    DISABLE_GITHUB_MIRROR) printf 'DisableGithubMirror' ;;
    DISABLE_MODEL_MIRROR) printf 'DisableModelMirror' ;;
    DISABLE_HUGGINGFACE_MIRROR) printf 'DisableHuggingFaceMirror' ;;
    DISABLE_CUDA_MALLOC) printf 'DisableCUDAMalloc' ;;
    DISABLE_ENV_CHECK) printf 'DisableEnvCheck' ;;
    NO_PRE_DOWNLOAD_EXTENSION) printf 'NoPreDownloadExtension' ;;
    NO_PRE_DOWNLOAD_NODE) printf 'NoPreDownloadNode' ;;
    NO_PRE_DOWNLOAD_MODEL) printf 'NoPreDownloadModel' ;;
    NO_CLEAN_CACHE) printf 'NoCleanCache' ;;
    *) return 1 ;;
  esac
}

config_key_supported_by_project() {
  local key="$1" config_key="$2" param
  [[ "$config_key" == "EXTRA_INSTALL_ARGS" ]] && return 0
  param="$(config_key_param_name "$config_key")" || return 0
  project_supports_param "$key" "$param"
}

set_project_config_key() {
  local key="$1" config_key="$2" value="$3"
  load_project_config "$key"
  case "$config_key" in
    INSTALL_PATH|INSTALL_BRANCH|CORE_PREFIX|PYTORCH_MIRROR_TYPE|PYTHON_VERSION|PROXY|GITHUB_MIRROR|HUGGINGFACE_MIRROR|EXTRA_INSTALL_ARGS|DISABLE_PYPI_MIRROR|DISABLE_PROXY|DISABLE_UV|DISABLE_GITHUB_MIRROR|DISABLE_MODEL_MIRROR|DISABLE_HUGGINGFACE_MIRROR|DISABLE_CUDA_MALLOC|DISABLE_ENV_CHECK|NO_PRE_DOWNLOAD_EXTENSION|NO_PRE_DOWNLOAD_NODE|NO_PRE_DOWNLOAD_MODEL|NO_CLEAN_CACHE)
      config_key_supported_by_project "$key" "$config_key" || die "$(project_name "$key") 不支持配置项: $config_key"
      printf -v "$config_key" '%s' "$value"
      save_project_config "$key"
      log_info "project config updated: project=$key key=$config_key value=$(sanitize_config_log_value "$config_key" "$value")"
      ;;
    *) die "不支持的项目配置项: $config_key" ;;
  esac
}

show_config() {
  local key="${1:-$CURRENT_PROJECT}"
  load_main_config
  require_project_key "$key"
  load_project_config "$key"
cat <<EOF
Main config: $MAIN_CONFIG_FILE
Project config: $(project_config_file "$key")
CURRENT_PROJECT=$CURRENT_PROJECT
AUTO_UPDATE_ENABLED=$AUTO_UPDATE_ENABLED
SHOW_WELCOME_SCREEN=$SHOW_WELCOME_SCREEN
LOG_LEVEL=$LOG_LEVEL
AUTO_UPDATE_LAST_CHECK=$AUTO_UPDATE_LAST_CHECK

[$key] $(project_name "$key")
EOF
  config_key_supported_by_project "$key" INSTALL_PATH && printf 'INSTALL_PATH=%s\n' "${INSTALL_PATH:-$(project_default_install_path "$key")}"
  config_key_supported_by_project "$key" INSTALL_BRANCH && printf 'INSTALL_BRANCH=%s\n' "${INSTALL_BRANCH:-}"
  config_key_supported_by_project "$key" CORE_PREFIX && printf 'CORE_PREFIX=%s\n' "${CORE_PREFIX:-}"
  config_key_supported_by_project "$key" PYTORCH_MIRROR_TYPE && printf 'PYTORCH_MIRROR_TYPE=%s\n' "${PYTORCH_MIRROR_TYPE:-}"
  config_key_supported_by_project "$key" PYTHON_VERSION && printf 'PYTHON_VERSION=%s\n' "${PYTHON_VERSION:-}"
  config_key_supported_by_project "$key" PROXY && printf 'PROXY=%s\n' "${PROXY:-}"
  config_key_supported_by_project "$key" GITHUB_MIRROR && printf 'GITHUB_MIRROR=%s\n' "${GITHUB_MIRROR:-}"
  config_key_supported_by_project "$key" HUGGINGFACE_MIRROR && printf 'HUGGINGFACE_MIRROR=%s\n' "${HUGGINGFACE_MIRROR:-}"
  printf 'EXTRA_INSTALL_ARGS=%s\n' "${EXTRA_INSTALL_ARGS:-}"
}
