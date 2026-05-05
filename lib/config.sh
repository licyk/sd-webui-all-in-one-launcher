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
      printf 'PROXY_MODE="auto"\n'
      printf 'MANUAL_PROXY=""\n'
      printf 'AUTO_UPDATE_LAST_CHECK="0"\n'
    } >"$MAIN_CONFIG_FILE"
  fi
}

ensure_project_config() {
  local key="$1" file branch schema
  file="$(project_config_file "$key")"
  branch="$(project_default_branch "$key")"
  mkdir -p "$PROJECT_CONFIG_DIR"
  if [[ -f "$file" ]]; then
    schema="$(sed -n 's/^CONFIG_SCHEMA_VERSION=//p' "$file" | head -n 1)"
    if [[ "$schema" != "2" && "$schema" != '"2"' && "$schema" != "'2'" ]]; then
      log_warn "reset incompatible project config schema: project=$key file=$file"
      rm -f -- "$file"
    fi
  fi
  if [[ ! -f "$file" ]]; then
    log_info "create project config v2: project=$key file=$file"
    write_default_project_config_v2 "$key" "$branch" >"$file"
  fi
}

write_default_project_config_v2() {
  local key="$1" branch="$2" param var default_value
  printf 'CONFIG_SCHEMA_VERSION="2"\n'
  while IFS= read -r param; do
    [[ -n "$param" ]] || continue
    installer_param_config_var_name "$param" >/dev/null 2>&1 || continue
    var="$(installer_param_var_name "$param")"
    case "$param" in
      InstallBranch) default_value="$branch" ;;
      Disable*|No*) default_value="0" ;;
      *) default_value="" ;;
    esac
    printf '%s=%s\n' "$var" "$(quote_config "$default_value")"
  done < <(project_param_entries "$key")
  printf 'INSTALLER_EXTRA_ARGS=""\n'
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
  if ! PROXY_MODE="$(normalize_proxy_mode "${PROXY_MODE:-auto}")"; then
    PROXY_MODE="auto"
    log_warn "invalid PROXY_MODE in main config, reset to auto"
  fi
  MANUAL_PROXY="${MANUAL_PROXY:-}"
  AUTO_UPDATE_LAST_CHECK="${AUTO_UPDATE_LAST_CHECK:-0}"
}

save_main_config() {
  mkdir -p "$CONFIG_HOME"
  {
    printf 'CURRENT_PROJECT=%s\n' "$(quote_config "$CURRENT_PROJECT")"
    printf 'AUTO_UPDATE_ENABLED=%s\n' "$(quote_config "$AUTO_UPDATE_ENABLED")"
    printf 'SHOW_WELCOME_SCREEN=%s\n' "$(quote_config "$SHOW_WELCOME_SCREEN")"
    printf 'LOG_LEVEL=%s\n' "$(quote_config "$LOG_LEVEL")"
    printf 'PROXY_MODE=%s\n' "$(quote_config "$PROXY_MODE")"
    printf 'MANUAL_PROXY=%s\n' "$(quote_config "$MANUAL_PROXY")"
    printf 'AUTO_UPDATE_LAST_CHECK=%s\n' "$(quote_config "$AUTO_UPDATE_LAST_CHECK")"
  } >"$MAIN_CONFIG_FILE"
  log_debug "saved main config: file=$MAIN_CONFIG_FILE current_project=${CURRENT_PROJECT:-<none>} auto_update=$AUTO_UPDATE_ENABLED welcome=$SHOW_WELCOME_SCREEN log_level=$LOG_LEVEL proxy_mode=$PROXY_MODE manual_proxy=$(sanitize_config_log_value MANUAL_PROXY "$MANUAL_PROXY") last_check=$AUTO_UPDATE_LAST_CHECK"
}

reset_project_config_vars() {
  CONFIG_SCHEMA_VERSION=2
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

installer_param_config_var_name() {
  case "$1" in
    InstallPath) printf 'INSTALL_PATH' ;;
    InstallBranch) printf 'INSTALL_BRANCH' ;;
    CorePrefix) printf 'CORE_PREFIX' ;;
    PyTorchMirrorType) printf 'PYTORCH_MIRROR_TYPE' ;;
    InstallPythonVersion) printf 'PYTHON_VERSION' ;;
    UseCustomProxy) printf 'PROXY' ;;
    UseCustomGithubMirror) printf 'GITHUB_MIRROR' ;;
    UseCustomHuggingFaceMirror) printf 'HUGGINGFACE_MIRROR' ;;
    DisablePyPIMirror) printf 'DISABLE_PYPI_MIRROR' ;;
    DisableProxy) printf 'DISABLE_PROXY' ;;
    DisableUV) printf 'DISABLE_UV' ;;
    DisableGithubMirror) printf 'DISABLE_GITHUB_MIRROR' ;;
    DisableModelMirror) printf 'DISABLE_MODEL_MIRROR' ;;
    DisableHuggingFaceMirror) printf 'DISABLE_HUGGINGFACE_MIRROR' ;;
    DisableCUDAMalloc) printf 'DISABLE_CUDA_MALLOC' ;;
    DisableEnvCheck) printf 'DISABLE_ENV_CHECK' ;;
    NoPreDownloadExtension) printf 'NO_PRE_DOWNLOAD_EXTENSION' ;;
    NoPreDownloadNode) printf 'NO_PRE_DOWNLOAD_NODE' ;;
    NoPreDownloadModel) printf 'NO_PRE_DOWNLOAD_MODEL' ;;
    NoCleanCache) printf 'NO_CLEAN_CACHE' ;;
    *) return 1 ;;
  esac
}

sync_installer_params_from_v2_vars() {
  local key="$1" param source_var target_var value
  while IFS= read -r param; do
    [[ -n "$param" ]] || continue
    target_var="$(installer_param_config_var_name "$param")" || continue
    source_var="$(installer_param_var_name "$param")"
    value="${!source_var:-}"
    printf -v "$target_var" '%s' "$value"
  done < <(project_param_entries "$key")
  INSTALL_BRANCH="${INSTALL_BRANCH:-$(project_default_branch "$key")}"
  EXTRA_INSTALL_ARGS="${INSTALLER_EXTRA_ARGS:-}"
}

load_project_config() {
  local key="$1"
  require_project_key "$key"
  reset_project_config_vars
  ensure_project_config "$key"
  # shellcheck disable=SC1090
  source "$(project_config_file "$key")"
  sync_installer_params_from_v2_vars "$key"
}

save_project_config() {
  local key="$1" file entry script var param value source_var
  file="$(project_config_file "$key")"
  mkdir -p "$PROJECT_CONFIG_DIR"
  {
    printf 'CONFIG_SCHEMA_VERSION="2"\n'
    while IFS= read -r param; do
      [[ -n "$param" ]] || continue
      source_var="$(installer_param_config_var_name "$param")" || continue
      var="$(installer_param_var_name "$param")"
      printf '%s=%s\n' "$var" "$(quote_config "${!source_var:-}")"
    done < <(project_param_entries "$key")
    printf 'INSTALLER_EXTRA_ARGS=%s\n' "$(quote_config "${EXTRA_INSTALL_ARGS:-}")"
    while IFS= read -r entry; do
      [[ -n "$entry" ]] || continue
      script="${entry%%:*}"
      var="$(script_arg_var_name "$script")"
      printf '%s=%s\n' "$var" "$(quote_config "${!var:-}")"
      while IFS= read -r param; do
        [[ -n "$param" ]] || continue
        [[ "$param" == "NoPause" ]] && continue
        var="$(script_param_var_name "$script" "$param")"
        value="${!var:-}"
        printf '%s=%s\n' "$var" "$(quote_config "$value")"
      done < <(management_script_param_entries "$key" "$script")
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
  local key="${1:-$CURRENT_PROJECT}" entry script param value
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
PROXY_MODE=$PROXY_MODE
MANUAL_PROXY=$MANUAL_PROXY
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
  printf '\nManagement script args:\n'
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    script="${entry%%:*}"
    printf '[%s]\n' "$script"
    while IFS= read -r param; do
      [[ -n "$param" ]] || continue
      management_script_param_is_visible "$key" "$script" "$param" || continue
      value="$(get_script_param_value "$script" "$param")"
      [[ -n "$value" ]] && printf '  %s=%s\n' "$param" "$value"
    done < <(management_script_param_entries "$key" "$script")
    printf '  EXTRA_ARGS=%s\n' "$(get_script_args "$script")"
  done < <(script_entries_for_project "$key")
}
