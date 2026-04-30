#!/usr/bin/env bash

usage() {
  cat <<EOF
$APP_TITLE $APP_VERSION

Usage:
  $0 tui
  $0 list-projects
  $0 install [project]
  $0 uninstall [project]
  $0 run-script <script.ps1> [args...]
  $0 set-main <key> <value>
  $0 set-project <project> <key> <value>
  $0 set-script-param <project> <script.ps1> <param> <value>
  $0 set-script-args <project> <script.ps1> <args>
  $0 config [project]
  $0 show-log [lines]
  $0 install-launcher [--yes]
  $0 uninstall-launcher

Examples:
  $0 tui
  $0 install-launcher
  $0 install-launcher --yes
  $0 install comfyui
  $0 uninstall comfyui
  $0 set-project sd_webui INSTALL_PATH /data/stable-diffusion-webui
  $0 set-project fooocus INSTALL_BRANCH fooocus_mre_main
  $0 set-script-param comfyui launch.ps1 LaunchArg "--listen 0.0.0.0 --port 8188"
  $0 set-script-param comfyui launch.ps1 DisableUpdate 1
  $0 set-script-args comfyui launch.ps1 "--listen 0.0.0.0 --port 8188"
  $0 set-main AUTO_UPDATE_ENABLED 0
  $0 set-main SHOW_WELCOME_SCREEN 0
  $0 set-main LOG_LEVEL INFO
  $0 set-main PROXY_MODE manual
  $0 set-main MANUAL_PROXY http://127.0.0.1:7890
  $0 show-log 120
EOF
}

main() {
  # shellcheck disable=SC2034
  ORIGINAL_ARGS=("$@")
  local command="${1:-tui}" key value
  load_log_level_hint
  init_logging
  register_crash_trap
  log_info "startup: command=$command args=$(format_log_args "$@") script_dir=${SCRIPT_DIR:-unknown} config_home=$CONFIG_HOME cache_home=$CACHE_HOME state_home=$STATE_HOME"
  load_main_config
  configure_proxy_from_main_config
  if [[ -n "$CURRENT_PROJECT" ]] && project_name "$CURRENT_PROJECT" >/dev/null 2>&1; then
    load_project_config "$CURRENT_PROJECT"
  else
    reset_project_config_vars
  fi
  init_ui
  log_debug "config loaded: current_project=${CURRENT_PROJECT:-<none>} auto_update=${AUTO_UPDATE_ENABLED:-1} welcome=${SHOW_WELCOME_SCREEN:-1} log_level=$LOG_LEVEL proxy_mode=$PROXY_MODE manual_proxy=$(sanitize_config_log_value MANUAL_PROXY "$MANUAL_PROXY")"
  case "$command" in
    set-main|install-launcher|uninstall-launcher|show-log|help|-h|--help) ;;
    *) check_and_update_launcher_if_due ;;
  esac
  if [[ "$command" != "tui" && -n "${STARTUP_NOTICE:-}" ]]; then
    printf '%s\n' "$STARTUP_NOTICE" >&2
  fi
  case "$command" in
    tui)
      log_info "enter tui"
      main_menu
      ;;
    list-projects)
      log_info "list projects"
      local key
      for key in "${PROJECT_KEYS[@]}"; do
        printf '%s\t%s\n' "$key" "$(project_name "$key")"
      done
      ;;
    install)
      key="${2:-$CURRENT_PROJECT}"
      require_project_key "$key"
      log_info "install command: project=$key"
      run_installer "$key"
      ;;
    uninstall)
      key="${2:-$CURRENT_PROJECT}"
      require_project_key "$key"
      log_warn "uninstall command: project=$key"
      uninstall_project "$key"
      ;;
    run-script)
      shift
      [[ "$#" -ge 1 ]] || die "缺少脚本名"
      require_project_key "$CURRENT_PROJECT"
      local script_name="$1"
      shift
      log_info "run-script command: project=$CURRENT_PROJECT script=$script_name args=$(format_log_args "$@")"
      run_management_script "$CURRENT_PROJECT" "$script_name" "$*"
      ;;
    set-main)
      [[ "$#" -eq 3 ]] || die "用法: $0 set-main <CURRENT_PROJECT> <value>"
      case "$2" in
        CURRENT_PROJECT)
          value="$(normalize_project_key_value "$3")"
          [[ -z "$value" ]] || require_project_key "$value"
          CURRENT_PROJECT="$value"
          save_main_config
          log_info "set main config: CURRENT_PROJECT=${CURRENT_PROJECT:-<none>}"
          ;;
        AUTO_UPDATE_ENABLED|SHOW_WELCOME_SCREEN)
          case "$3" in
            1|true|TRUE|on|ON|yes|YES) value=1 ;;
            0|false|FALSE|off|OFF|no|NO) value=0 ;;
            *) die "配置值必须是 1/0、true/false、on/off 或 yes/no" ;;
          esac
          printf -v "$2" '%s' "$value"
          save_main_config
          log_info "set main config: $2=$value"
          ;;
        LOG_LEVEL)
          value="$(normalize_log_level "$3")" || die "日志等级必须是 DEBUG、INFO、WARN 或 ERROR"
          LOG_LEVEL="$value"
          save_main_config
          log_info "set main config: LOG_LEVEL=$LOG_LEVEL"
          ;;
        PROXY_MODE)
          value="$(normalize_proxy_mode "$3")" || die "代理模式必须是 auto、manual 或 off"
          PROXY_MODE="$value"
          save_main_config
          log_info "set main config: PROXY_MODE=$PROXY_MODE"
          ;;
        MANUAL_PROXY)
          MANUAL_PROXY="$3"
          save_main_config
          log_info "set main config: MANUAL_PROXY=$(sanitize_config_log_value MANUAL_PROXY "$MANUAL_PROXY")"
          ;;
        *) die "不支持的主配置项: $2" ;;
      esac
      ;;
    set-project)
      [[ "$#" -eq 4 ]] || die "用法: $0 set-project <project> <key> <value>"
      log_info "set project config: project=$2 key=$3 value=$(sanitize_config_log_value "$3" "$4")"
      set_project_config_key "$2" "$3" "$4"
      ;;
    set-script-param)
      [[ "$#" -eq 5 ]] || die "用法: $0 set-script-param <project> <script.ps1> <param> <value>"
      require_project_key "$2"
      management_script_supports_param "$2" "$3" "$4" || die "$3 不支持管理脚本参数: $4"
      [[ "$4" != "NoPause" ]] || die "NoPause 会自动追加，不需要配置。"
      load_project_config "$2"
      set_script_param_value "$3" "$4" "$5"
      save_project_config "$2"
      log_info "set script param: project=$2 script=$3 param=$4 value=$(sanitize_config_log_value "$4" "$5")"
      ;;
    set-script-args)
      [[ "$#" -eq 4 ]] || die "用法: $0 set-script-args <project> <script.ps1> <args>"
      load_project_config "$2"
      set_script_args "$3" "$4"
      save_project_config "$2"
      log_info "set script args: project=$2 script=$3 args=$(sanitize_config_log_value EXTRA_INSTALL_ARGS "$4")"
      ;;
    config)
      key="${2:-$CURRENT_PROJECT}"
      require_project_key "$key"
      log_info "show config: project=$key"
      show_config "$key"
      ;;
    show-log) show_log "${2:-80}" ;;
    install-launcher) install_launcher "${2:-}" ;;
    uninstall-launcher) uninstall_launcher ;;
    help|-h|--help) usage ;;
    *) usage; exit 1 ;;
  esac
}
