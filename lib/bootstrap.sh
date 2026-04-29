#!/usr/bin/env bash

INSTALLER_LAUNCHER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=lib/core.sh
source "$INSTALLER_LAUNCHER_ROOT/lib/core.sh"
# shellcheck source=lib/proxy.sh
source "$INSTALLER_LAUNCHER_ROOT/lib/proxy.sh"
# shellcheck source=lib/projects.sh
source "$INSTALLER_LAUNCHER_ROOT/lib/projects.sh"
# shellcheck source=lib/config.sh
source "$INSTALLER_LAUNCHER_ROOT/lib/config.sh"
# shellcheck source=lib/ui.sh
source "$INSTALLER_LAUNCHER_ROOT/lib/ui.sh"
# shellcheck source=lib/runner.sh
source "$INSTALLER_LAUNCHER_ROOT/lib/runner.sh"
# shellcheck source=lib/self_manage.sh
source "$INSTALLER_LAUNCHER_ROOT/lib/self_manage.sh"
# shellcheck source=lib/menus.sh
source "$INSTALLER_LAUNCHER_ROOT/lib/menus.sh"
# shellcheck source=lib/cli.sh
source "$INSTALLER_LAUNCHER_ROOT/lib/cli.sh"
