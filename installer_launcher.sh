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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=lib/bootstrap.sh
source "$SCRIPT_DIR/lib/bootstrap.sh"

main "$@"
