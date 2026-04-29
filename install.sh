#!/usr/bin/env bash

set -u

HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
POWERSHELL_MACOS_DOC="https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-macos"
POWERSHELL_LINUX_DOC="https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux"
DRY_RUN="${INSTALLER_LAUNCHER_INSTALL_DRY_RUN:-0}"

info() {
  printf '%s\n' "$*"
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

error() {
  printf 'Error: %s\n' "$*" >&2
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_cmd() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '[dry-run]'
    printf ' %s' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    run_cmd "$@"
    return $?
  fi
  if have_cmd sudo; then
    run_cmd sudo "$@"
    return $?
  fi
  error "需要 sudo 或 root 权限执行: $*"
  return 1
}

download_file() {
  local url="$1" output="$2"
  if have_cmd curl; then
    run_cmd curl -fsSL "$url" -o "$output"
    return $?
  fi
  if have_cmd wget; then
    run_cmd wget -q "$url" -O "$output"
    return $?
  fi
  return 1
}

have_powershell() {
  have_cmd pwsh || have_cmd powershell
}

windows_system_proxy_script() {
  cat <<'EOF'
$internet_setting = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$proxy_addr = $internet_setting.ProxyServer
if (-not $internet_setting.ProxyEnable -or [string]::IsNullOrWhiteSpace($proxy_addr)) { exit 0 }
if (($proxy_addr -match "http=(.*?);") -or ($proxy_addr -match "https=(.*?);")) {
    $proxy_value = $matches[1].ToString().Replace("http://", "").Replace("https://", "")
    Write-Host "http://$proxy_value"
} elseif ($proxy_addr -match "socks=(.*)") {
    $proxy_value = $matches[1].ToString().Replace("socks://", "")
    Write-Host "socks://$proxy_value"
} else {
    $proxy_value = $proxy_addr.ToString().Replace("http://", "").Replace("https://", "")
    Write-Host "http://$proxy_value"
}
EOF
}

get_windows_system_proxy_address() {
  if have_cmd powershell; then
    powershell -NoProfile -Command "$(windows_system_proxy_script)" 2>/dev/null | head -n 1
  elif have_cmd pwsh; then
    pwsh -NoProfile -Command "$(windows_system_proxy_script)" 2>/dev/null | head -n 1
  else
    return 1
  fi
}

get_gnome_system_proxy_address() {
  local mode http_host http_port socks_host socks_port
  have_cmd gsettings || return 1
  mode="$(gsettings get org.gnome.system.proxy mode 2>/dev/null | sed "s/'//g")"
  [ "$mode" = "manual" ] || return 1
  http_host="$(gsettings get org.gnome.system.proxy.http host 2>/dev/null | sed "s/'//g")"
  http_port="$(gsettings get org.gnome.system.proxy.http port 2>/dev/null)"
  socks_host="$(gsettings get org.gnome.system.proxy.socks host 2>/dev/null | sed "s/'//g")"
  socks_port="$(gsettings get org.gnome.system.proxy.socks port 2>/dev/null)"
  if [ -n "$http_host" ] && [ -n "$http_port" ] && [ "$http_port" != "0" ]; then
    printf 'http://%s:%s\n' "$http_host" "$http_port"
  elif [ -n "$socks_host" ] && [ -n "$socks_port" ] && [ "$socks_port" != "0" ]; then
    printf 'socks://%s:%s\n' "$socks_host" "$socks_port"
  else
    return 1
  fi
}

get_kde_system_proxy_address() {
  local config_file="$HOME/.config/kioslaverc" proxy_type http_proxy socks_proxy
  [ -f "$config_file" ] || return 1
  proxy_type="$(awk -F= '$1 == "ProxyType" {print $2; exit}' "$config_file" 2>/dev/null)"
  [ "$proxy_type" = "1" ] || return 1
  http_proxy="$(awk -F= '$1 == "httpProxy" {gsub(/ /, ":", $2); print $2; exit}' "$config_file" 2>/dev/null)"
  socks_proxy="$(awk -F= '$1 == "socksProxy" {gsub(/ /, ":", $2); print $2; exit}' "$config_file" 2>/dev/null)"
  if [ -n "$http_proxy" ]; then
    case "$http_proxy" in http://*|https://*) ;; *) http_proxy="http://$http_proxy" ;; esac
    printf '%s\n' "$http_proxy"
  elif [ -n "$socks_proxy" ]; then
    case "$socks_proxy" in socks://*) ;; *) socks_proxy="socks://$socks_proxy" ;; esac
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
    linux*) get_gnome_system_proxy_address || get_kde_system_proxy_address ;;
    darwin*) get_macos_system_proxy_address ;;
    *) return 1 ;;
  esac
}

auto_configure_system_proxy() {
  local proxy_value
  [ -z "${HTTP_PROXY:-}${HTTPS_PROXY:-}${http_proxy:-}${https_proxy:-}" ] || {
    info "已存在代理环境变量，跳过系统代理检测。"
    return 0
  }
  proxy_value="$(get_system_proxy_address 2>/dev/null || true)"
  [ -n "$proxy_value" ] || return 0
  export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1}"
  export no_proxy="${no_proxy:-$NO_PROXY}"
  export HTTP_PROXY="$proxy_value"
  export HTTPS_PROXY="$proxy_value"
  export http_proxy="$proxy_value"
  export https_proxy="$proxy_value"
  info "已自动设置系统代理: $proxy_value"
}

prepend_path_if_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    case ":$PATH:" in
      *":$dir:"*) ;;
      *) PATH="$dir:$PATH"; export PATH ;;
    esac
  fi
}

refresh_homebrew_path() {
  prepend_path_if_dir "/opt/homebrew/bin"
  prepend_path_if_dir "/usr/local/bin"
  prepend_path_if_dir "/home/linuxbrew/.linuxbrew/bin"
}

bash_major_version() {
  local bash_cmd="${1:-bash}"
  # shellcheck disable=SC2016
  "$bash_cmd" -c 'printf "%s" "${BASH_VERSINFO[0]:-0}"' 2>/dev/null || printf '0'
}

bash_is_at_least_5() {
  local bash_cmd="${1:-bash}" major
  major="$(bash_major_version "$bash_cmd")"
  case "$major" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$major" -ge 5 ]
}

detect_repo_root() {
  local script_path script_dir
  script_path="${BASH_SOURCE[0]}"
  while [ -L "$script_path" ]; do
    script_dir="$(cd -P "$(dirname "$script_path")" && pwd)" || return 1
    script_path="$(readlink "$script_path")" || return 1
    case "$script_path" in
      /*) ;;
      *) script_path="$script_dir/$script_path" ;;
    esac
  done
  cd -P "$(dirname "$script_path")" && pwd
}

install_homebrew_if_needed() {
  if have_cmd brew; then
    info "Homebrew 已安装: $(command -v brew)"
    return 0
  fi

  info "未检测到 Homebrew，正在使用官方安装脚本安装..."
  if ! have_cmd curl; then
    error "安装 Homebrew 需要 curl。请先安装 curl 后重试。"
    return 1
  fi
  if [ "$DRY_RUN" = "1" ]; then
    run_cmd /bin/bash -c "curl -fsSL $HOMEBREW_INSTALL_URL | bash" || return 1
  else
    if ! /bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALL_URL")"; then
      error "Homebrew 安装失败。请重试，或按官方文档手动安装: https://brew.sh/"
      return 1
    fi
  fi
  refresh_homebrew_path
  have_cmd brew
}

brew_install_if_missing() {
  local command_name="$1" package_name="$2"
  if have_cmd "$command_name"; then
    info "$command_name 已安装: $(command -v "$command_name")"
    return 0
  fi
  info "正在通过 Homebrew 安装 $package_name..."
  run_cmd brew install "$package_name"
}

brew_install_bash5_if_needed() {
  if select_homebrew_bash >/dev/null 2>&1; then
    info "Bash 5+ 已安装: $(select_homebrew_bash)"
    return 0
  fi
  info "正在通过 Homebrew 安装 Bash 5+..."
  run_cmd brew install bash
}

select_homebrew_bash() {
  if [ -x "/opt/homebrew/bin/bash" ] && bash_is_at_least_5 "/opt/homebrew/bin/bash"; then
    printf '%s' "/opt/homebrew/bin/bash"
    return 0
  fi
  if [ -x "/usr/local/bin/bash" ] && bash_is_at_least_5 "/usr/local/bin/bash"; then
    printf '%s' "/usr/local/bin/bash"
    return 0
  fi
  if bash_is_at_least_5 "bash"; then
    command -v bash
    return 0
  fi
  return 1
}

linux_package_manager() {
  if have_cmd apt-get; then printf 'apt'; return 0; fi
  if have_cmd dnf; then printf 'dnf'; return 0; fi
  if have_cmd yum; then printf 'yum'; return 0; fi
  if have_cmd apk; then printf 'apk'; return 0; fi
  if have_cmd zypper; then printf 'zypper'; return 0; fi
  if have_cmd pacman; then printf 'pacman'; return 0; fi
  return 1
}

install_linux_packages() {
  local pm="$1"
  shift
  case "$pm" in
    apt)
      run_root apt-get update || return 1
      run_root apt-get install -y "$@"
      ;;
    dnf) run_root dnf install -y "$@" ;;
    yum) run_root yum install -y "$@" ;;
    apk) run_root apk add --no-cache "$@" ;;
    zypper) run_root zypper install -y "$@" ;;
    pacman) run_root pacman -Sy --noconfirm "$@" ;;
    *) return 1 ;;
  esac
}

install_linux_command_if_missing() {
  local command_name="$1" package_name="$2" pm
  if have_cmd "$command_name"; then
    info "$command_name 已安装: $(command -v "$command_name")"
    return 0
  fi
  pm="$(linux_package_manager)" || return 1
  info "正在通过 $pm 安装 $package_name..."
  install_linux_packages "$pm" "$package_name"
}

load_os_release() {
  OS_ID=""
  OS_VERSION_ID=""
  OS_ID_LIKE=""
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-}"
    OS_VERSION_ID="${VERSION_ID:-}"
    OS_ID_LIKE="${ID_LIKE:-}"
  fi
}

install_powershell_apt_repo() {
  local distro="$1" version_id="$2" repo_deb
  [ -n "$version_id" ] || return 1
  install_linux_command_if_missing wget wget || return 1
  if [ "$distro" = "ubuntu" ]; then
    install_linux_packages apt apt-transport-https software-properties-common || true
  fi
  repo_deb="$(mktemp "${TMPDIR:-/tmp}/packages-microsoft-prod.XXXXXX")" || return 1
  if ! download_file "https://packages.microsoft.com/config/$distro/$version_id/packages-microsoft-prod.deb" "$repo_deb"; then
    rm -f "$repo_deb"
    return 1
  fi
  if ! run_root dpkg -i "$repo_deb"; then
    rm -f "$repo_deb"
    return 1
  fi
  rm -f "$repo_deb"
  run_root apt-get update || return 1
  run_root apt-get install -y powershell
}

install_powershell_rpm_repo() {
  local distro="$1" version_id="$2" major repo_rpm pm
  [ -n "$version_id" ] || return 1
  major="${version_id%%.*}"
  repo_rpm="$(mktemp "${TMPDIR:-/tmp}/packages-microsoft-prod.XXXXXX")" || return 1
  if ! download_file "https://packages.microsoft.com/config/$distro/$major/packages-microsoft-prod.rpm" "$repo_rpm"; then
    rm -f "$repo_rpm"
    return 1
  fi
  if have_cmd rpm; then
    run_root rpm -Uvh "$repo_rpm" || {
      rm -f "$repo_rpm"
      return 1
    }
  else
    rm -f "$repo_rpm"
    return 1
  fi
  rm -f "$repo_rpm"
  if have_cmd dnf; then
    pm=dnf
  elif have_cmd yum; then
    pm=yum
  else
    return 1
  fi
  install_linux_packages "$pm" powershell
}

install_powershell_official_linux() {
  local id="$1" version_id="$2" id_like="$3"
  case "$id" in
    ubuntu) install_powershell_apt_repo ubuntu "$version_id" ;;
    debian) install_powershell_apt_repo debian "$version_id" ;;
    rhel|centos|rocky|almalinux) install_powershell_rpm_repo rhel "$version_id" ;;
    fedora) install_powershell_rpm_repo fedora "$version_id" ;;
    alpine) return 1 ;;
    *)
      case "$id_like" in
        *debian*) install_powershell_apt_repo debian "$version_id" ;;
        *rhel*|*fedora*) install_powershell_rpm_repo rhel "$version_id" ;;
        *) return 1 ;;
      esac
      ;;
  esac
}

install_powershell_fallback_linux() {
  local pm
  pm="$(linux_package_manager)" || return 1
  case "$pm" in
    apt|dnf|yum|apk|zypper) install_linux_packages "$pm" powershell ;;
    pacman)
      warn "检测到 pacman，但 PowerShell 通常来自 AUR，install.sh 不自动安装 AUR 包。"
      return 1
      ;;
    *) return 1 ;;
  esac
}

ensure_linux_powershell() {
  if have_powershell; then
    if have_cmd pwsh; then
      info "PowerShell 已安装: $(command -v pwsh)"
    else
      info "PowerShell 已安装: $(command -v powershell)"
    fi
    return 0
  fi

  load_os_release
  info "未检测到 pwsh，正在尝试自动安装 PowerShell..."
  if install_powershell_official_linux "$OS_ID" "$OS_VERSION_ID" "$OS_ID_LIKE"; then
    have_powershell && return 0
  fi

  warn "官方仓库安装 PowerShell 失败，正在尝试系统包管理器 fallback..."
  if install_powershell_fallback_linux; then
    have_powershell && return 0
  fi

  error "当前 Linux 环境不支持自动安装 PowerShell，或自动安装失败。"
  error "请根据 Microsoft Learn 手动安装 PowerShell: $POWERSHELL_LINUX_DOC"
  return 1
}

ensure_linux_bash5() {
  local pm bash_cmd
  if bash_is_at_least_5 "bash"; then
    return 0
  fi
  warn "当前 Bash 版本低于 5，正在尝试通过系统包管理器安装/升级 bash..."
  pm="$(linux_package_manager)" || {
    error "无法检测到支持的包管理器，请手动安装 Bash 5+。"
    return 1
  }
  install_linux_packages "$pm" bash || return 1
  bash_cmd="$(command -v bash)"
  if bash_is_at_least_5 "$bash_cmd"; then
    return 0
  fi
  error "Bash 仍低于 5，请手动安装 Bash 5+ 后重试。"
  return 1
}

ensure_linux_optional_tools() {
  local pm missing=""
  pm="$(linux_package_manager)" || {
    warn "未检测到支持的包管理器，跳过 dialog/git 自动安装。"
    return 0
  }
  have_cmd dialog || missing="$missing dialog"
  have_cmd git || missing="$missing git"
  if [ -z "$missing" ]; then
    info "dialog 和 git 已安装。"
    return 0
  fi
  info "正在安装可选工具:$missing"
  # shellcheck disable=SC2086
  install_linux_packages "$pm" $missing || warn "dialog/git 安装失败，可稍后手动安装。"
}

install_macos_dependencies() {
  local bash_cmd
  info "检测到 macOS。"
  refresh_homebrew_path
  install_homebrew_if_needed || return 1
  refresh_homebrew_path

  if ! bash_is_at_least_5 "bash"; then
    brew_install_bash5_if_needed || {
      error "Bash 5+ 安装失败。请重试或手动执行: brew install bash"
      return 1
    }
  fi
  bash_cmd="$(select_homebrew_bash)" || {
    error "未找到 Bash 5+。请手动安装 Homebrew Bash 后重试。"
    return 1
  }

  if have_powershell; then
    if have_cmd pwsh; then
      info "PowerShell 已安装: $(command -v pwsh)"
    else
      info "PowerShell 已安装: $(command -v powershell)"
    fi
  elif ! brew_install_if_missing pwsh powershell; then
    error "PowerShell 安装失败。请重试或按官方文档手动安装: $POWERSHELL_MACOS_DOC"
    return 1
  fi
  brew_install_if_missing dialog dialog || warn "dialog 安装失败，可稍后手动安装。"
  brew_install_if_missing git git || warn "git 安装失败，可稍后手动安装。"
  printf '%s' "$bash_cmd" >"${TMPDIR:-/tmp}/installer-launcher-bash-cmd.$$"
}

install_linux_dependencies() {
  local bash_cmd
  info "检测到 Linux。"
  ensure_linux_bash5 || return 1
  ensure_linux_powershell || return 1
  ensure_linux_optional_tools
  bash_cmd="$(command -v bash)"
  printf '%s' "$bash_cmd" >"${TMPDIR:-/tmp}/installer-launcher-bash-cmd.$$"
}

install_launcher_noninteractive() {
  local repo_root="$1" bash_cmd_file bash_cmd
  bash_cmd_file="${TMPDIR:-/tmp}/installer-launcher-bash-cmd.$$"
  if [ -f "$bash_cmd_file" ]; then
    bash_cmd="$(cat "$bash_cmd_file")"
    rm -f "$bash_cmd_file"
  else
    bash_cmd="$(command -v bash)"
  fi
  info "正在安装 installer launcher..."
  run_cmd "$bash_cmd" "$repo_root/installer_launcher.sh" install-launcher --yes || return 1
  info "installer launcher 安装完成。"
  info "命令路径: $HOME/.local/bin/installer-launcher"
  info "如果当前终端还不能直接运行 installer-launcher，请重新打开终端，或 source 当前 shell 的配置文件。"
}

main() {
  local repo_root os_name
  repo_root="$(detect_repo_root)" || {
    error "无法定位 install.sh 所在目录。"
    exit 1
  }
  os_name="$(uname -s 2>/dev/null || printf unknown)"
  info "Installer Launcher bootstrap"
  info "仓库目录: $repo_root"
  auto_configure_system_proxy

  case "$os_name" in
    Darwin) install_macos_dependencies || exit 1 ;;
    Linux) install_linux_dependencies || exit 1 ;;
    *)
      error "不支持的系统: $os_name"
      exit 1
      ;;
  esac

  install_launcher_noninteractive "$repo_root" || exit 1
}

main "$@"
