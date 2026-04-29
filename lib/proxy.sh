#!/usr/bin/env bash

windows_system_proxy_script() {
  cat <<'EOF'
$internet_setting = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$proxy_addr = $internet_setting.ProxyServer

if (-not $internet_setting.ProxyEnable -or [string]::IsNullOrWhiteSpace($proxy_addr)) {
    exit 0
}

if (($proxy_addr -match "http=(.*?);") -or ($proxy_addr -match "https=(.*?);")) {
    $proxy_value = $matches[1]
    $proxy_value = $proxy_value.ToString().Replace("http://", "").Replace("https://", "")
    Write-Host "http://$proxy_value"
} elseif ($proxy_addr -match "socks=(.*)") {
    $proxy_value = $matches[1]
    $proxy_value = $proxy_value.ToString().Replace("socks://", "")
    Write-Host "socks://$proxy_value"
} else {
    $proxy_value = $proxy_addr.ToString().Replace("http://", "").Replace("https://", "")
    Write-Host "http://$proxy_value"
}
EOF
}

get_windows_system_proxy_address() {
  local ps_cmd=""
  if need_cmd powershell; then
    ps_cmd="powershell"
  elif need_cmd pwsh; then
    ps_cmd="pwsh"
  else
    return 1
  fi
  "$ps_cmd" -NoProfile -Command "$(windows_system_proxy_script)" 2>/dev/null | head -n 1
}

get_gnome_system_proxy_address() {
  local mode http_host http_port socks_host socks_port
  need_cmd gsettings || return 1
  mode="$(gsettings get org.gnome.system.proxy mode 2>/dev/null | sed "s/'//g")"
  [[ "$mode" == "manual" ]] || return 1
  http_host="$(gsettings get org.gnome.system.proxy.http host 2>/dev/null | sed "s/'//g")"
  http_port="$(gsettings get org.gnome.system.proxy.http port 2>/dev/null)"
  socks_host="$(gsettings get org.gnome.system.proxy.socks host 2>/dev/null | sed "s/'//g")"
  socks_port="$(gsettings get org.gnome.system.proxy.socks port 2>/dev/null)"
  if [[ -n "$http_host" && -n "$http_port" && "$http_port" != "0" ]]; then
    printf 'http://%s:%s\n' "$http_host" "$http_port"
  elif [[ -n "$socks_host" && -n "$socks_port" && "$socks_port" != "0" ]]; then
    printf 'socks://%s:%s\n' "$socks_host" "$socks_port"
  else
    return 1
  fi
}

get_kde_system_proxy_address() {
  local config_file="$HOME/.config/kioslaverc" proxy_type http_proxy socks_proxy
  [[ -f "$config_file" ]] || return 1
  proxy_type="$(awk -F= '$1 == "ProxyType" {print $2; exit}' "$config_file" 2>/dev/null)"
  [[ "$proxy_type" == "1" ]] || return 1
  http_proxy="$(awk -F= '$1 == "httpProxy" {gsub(/ /, ":", $2); print $2; exit}' "$config_file" 2>/dev/null)"
  socks_proxy="$(awk -F= '$1 == "socksProxy" {gsub(/ /, ":", $2); print $2; exit}' "$config_file" 2>/dev/null)"
  if [[ -n "$http_proxy" ]]; then
    [[ "$http_proxy" == http://* || "$http_proxy" == https://* ]] || http_proxy="http://$http_proxy"
    printf '%s\n' "$http_proxy"
  elif [[ -n "$socks_proxy" ]]; then
    [[ "$socks_proxy" == socks://* ]] || socks_proxy="socks://$socks_proxy"
    printf '%s\n' "$socks_proxy"
  else
    return 1
  fi
}

get_macos_system_proxy_address() {
  scutil --proxy 2>/dev/null | awk '
    /HTTPEnable/ { http_enabled = $3 }
    /HTTPProxy/ { http_server = $3 }
    /HTTPPort/ { http_port = $3 }
    /SOCKSEnable/ { socks_enabled = $3 }
    /SOCKSProxy/ { socks_server = $3 }
    /SOCKSPort/ { socks_port = $3 }
    END {
      if (http_enabled == "1" && http_server != "" && http_port != "") {
        print "http://" http_server ":" http_port
      } else if (socks_enabled == "1" && socks_server != "" && socks_port != "") {
        print "socks://" socks_server ":" socks_port
      }
    }'
}

get_system_proxy_address() {
  case "${OSTYPE:-}" in
    msys*|cygwin*) get_windows_system_proxy_address ;;
    linux*)
      get_gnome_system_proxy_address || get_kde_system_proxy_address
      ;;
    darwin*) get_macos_system_proxy_address ;;
    *) return 1 ;;
  esac
}

set_proxy_environment() {
  local proxy_value="${1:-}" proxy_source="${2:-manual}"
  [[ -n "$proxy_value" ]] || return 1
  export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1}"
  export no_proxy="${no_proxy:-$NO_PROXY}"
  export HTTP_PROXY="$proxy_value"
  export HTTPS_PROXY="$proxy_value"
  export http_proxy="$proxy_value"
  export https_proxy="$proxy_value"
  log_info "system proxy configured: source=$proxy_source value=$(sanitize_log_message "$proxy_value")"
}

clear_proxy_environment() {
  unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
  log_info "proxy mode is off, cleared proxy environment variables"
}

configure_proxy_from_main_config() {
  local proxy_value
  case "${PROXY_MODE:-auto}" in
    off)
      clear_proxy_environment
      return 0
      ;;
    manual)
      if [[ -z "${MANUAL_PROXY:-}" ]]; then
        log_warn "proxy mode is manual but MANUAL_PROXY is empty"
        clear_proxy_environment
        return 0
      fi
      set_proxy_environment "$MANUAL_PROXY" "manual"
      ;;
    auto)
      [[ -z "${HTTP_PROXY:-}${HTTPS_PROXY:-}${http_proxy:-}${https_proxy:-}" ]] || {
        log_debug "proxy environment already configured, skip system proxy detection"
        return 0
      }
      proxy_value="$(get_system_proxy_address || true)"
      [[ -n "$proxy_value" ]] || {
        log_debug "system proxy not detected"
        return 0
      }
      set_proxy_environment "$proxy_value" "system"
      ;;
    *)
      log_warn "unknown proxy mode: ${PROXY_MODE:-}"
      ;;
  esac
}
