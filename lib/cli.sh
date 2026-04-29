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
  $0 set-script-args <project> <script.ps1> <args>
  $0 config [project]
  $0 install-launcher
  $0 uninstall-launcher

Examples:
  $0 tui
  $0 install-launcher
  $0 install comfyui
  $0 uninstall comfyui
  $0 set-project sd_webui INSTALL_PATH /data/stable-diffusion-webui
  $0 set-project fooocus INSTALL_BRANCH fooocus_mre_main
  $0 set-script-args comfyui launch.ps1 "--listen 0.0.0.0 --port 8188"
  $0 set-main AUTO_UPDATE_ENABLED 0
  $0 set-main SHOW_WELCOME_SCREEN 0
EOF
}

main() {
  load_all_config
  init_ui
  local command="${1:-tui}" key value
  case "$command" in
    set-main|install-launcher|uninstall-launcher|help|-h|--help) ;;
    *) check_and_update_launcher_if_due ;;
  esac
  if [[ "$command" != "tui" && -n "${STARTUP_NOTICE:-}" ]]; then
    printf '%s\n' "$STARTUP_NOTICE" >&2
  fi
  case "$command" in
    tui) main_menu ;;
    list-projects)
      local key
      for key in "${PROJECT_KEYS[@]}"; do
        printf '%s\t%s\n' "$key" "$(project_name "$key")"
      done
      ;;
    install)
      key="${2:-$CURRENT_PROJECT}"
      require_project_key "$key"
      run_installer "$key"
      ;;
    uninstall)
      key="${2:-$CURRENT_PROJECT}"
      require_project_key "$key"
      uninstall_project "$key"
      ;;
    run-script)
      shift
      [[ "$#" -ge 1 ]] || die "缺少脚本名"
      require_project_key "$CURRENT_PROJECT"
      local script_name="$1"
      shift
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
          ;;
        AUTO_UPDATE_ENABLED|SHOW_WELCOME_SCREEN)
          case "$3" in
            1|true|TRUE|on|ON|yes|YES) value=1 ;;
            0|false|FALSE|off|OFF|no|NO) value=0 ;;
            *) die "配置值必须是 1/0、true/false、on/off 或 yes/no" ;;
          esac
          printf -v "$2" '%s' "$value"
          save_main_config
          ;;
        *) die "不支持的主配置项: $2" ;;
      esac
      ;;
    set-project)
      [[ "$#" -eq 4 ]] || die "用法: $0 set-project <project> <key> <value>"
      set_project_config_key "$2" "$3" "$4"
      ;;
    set-script-args)
      [[ "$#" -eq 4 ]] || die "用法: $0 set-script-args <project> <script.ps1> <args>"
      load_project_config "$2"
      set_script_args "$3" "$4"
      save_project_config "$2"
      ;;
    config)
      key="${2:-$CURRENT_PROJECT}"
      require_project_key "$key"
      show_config "$key"
      ;;
    install-launcher) install_launcher ;;
    uninstall-launcher) uninstall_launcher ;;
    help|-h|--help) usage ;;
    *) usage; exit 1 ;;
  esac
}
