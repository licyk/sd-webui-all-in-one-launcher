# AGENTS.md

## Project Overview

This project provides launchers for multiple PowerShell installer scripts:

- Bash TUI/CLI launcher for Linux/macOS/Windows-like shells.
- Windows-only PowerShell WPF GUI launcher.

The dependency bootstrap entry point is `install.sh`. The Bash launcher entry point is `installer_launcher.sh`. The Windows GUI entry point is `installer_launcher_gui.ps1`. Most Bash launcher behavior lives in `lib/` modules:

- `lib/bootstrap.sh`: sources all modules in the required order.
- `lib/core.sh`: application constants, global defaults, logging/crash helpers, generic helpers.
- `lib/proxy.sh`: system proxy detection and environment setup before network access.
- `lib/projects.sh`: project registry, installer URLs, supported parameters, management script lists.
- `lib/config.sh`: main and per-project config creation, loading, saving, validation, display.
- `lib/ui.sh`: dialog/text UI helpers, dynamic terminal sizing, prompts, viewers.
- `lib/runner.sh`: installer download, argument construction, PowerShell execution, install detection, management script execution, project uninstall.
- `lib/self_manage.sh`: install/update/uninstall this launcher, command registration, shell rc cleanup.
- `lib/menus.sh`: TUI menus, configuration flows, main-menu status/help text.
- `lib/cli.sh`: command-line dispatch and usage text.

`docs/todo.md` is part of the workflow. Update it whenever you modify behavior, tests, or documentation.

## Windows GUI Rules

- `installer_launcher_gui.ps1` is Windows-only and should use PowerShell/WPF, not Bash.
- Keep it self-contained so users can download and run a single `.ps1` file.
- Keep the GUI project registry synchronized with `lib/projects.sh`: project keys, installer URL lists, default directories, branch lists, supported parameters, and direct management scripts.
- GUI config uses Windows-native paths:
  - `%APPDATA%\installer-launcher\main.json`
  - `%APPDATA%\installer-launcher\projects\<project>.json`
  - `%LOCALAPPDATA%\installer-launcher\cache\installers\<project>\`
  - `%LOCALAPPDATA%\installer-launcher\logs\`
- GUI proxy modes mirror the Bash launcher: `auto`, `manual`, and `off`.
- GUI execution should open PowerShell scripts in a visible console window so upstream script output and prompts remain visible.
- GUI self-update only replaces `installer_launcher_gui.ps1`; do not add Bash shell command registration or shell rc cleanup to the GUI.

## Shell Requirements

- The script requires Bash 5+ for the main implementation.
- `install.sh` is a bootstrap script and must remain compatible with macOS Bash 3.x.
- `installer_launcher.sh` contains a macOS guard before strict mode:
  - If macOS is using Bash < 5, it tries `/opt/homebrew/bin/bash`.
  - If Homebrew Bash is missing, it prints installation guidance and exits.
- Keep any logic before `set -Eeuo pipefail` compatible with macOS Bash 3.x.
- Do not use Bash 5-only syntax in `install.sh`; it may be the first script a macOS user runs.

## Coding Style

- Use Bash, not Python or other languages, unless the user explicitly asks otherwise.
- Keep files ASCII unless the existing user-facing Chinese UI text requires Chinese.
- Prefer small focused functions over large inline blocks.
- Quote variable expansions unless there is a deliberate word-splitting reason.
- Avoid ad hoc string parsing when arrays or existing helper functions are available.
- Use `local` for function variables.
- Be careful with Bash dynamic scoping:
  - Do not reuse output variable names as local temporary variable names in helper functions using `printf -v`.
  - Avoid `trap RETURN` inside long-running menu functions.
- Keep `shellcheck` clean. If a warning is unavoidable, use the narrowest possible suppression near the relevant command.

## Strict Mode Rules

The entry script uses:

```bash
set -Eeuo pipefail
```

Therefore:

- Treat non-zero command statuses deliberately.
- Use `if command; then ... else ... fi` when a non-zero status is expected.
- Use `|| true` only when the failure is intentionally non-fatal.
- Avoid command substitutions that may return non-zero unless wrapped safely.
- Initialize variables before use, especially values passed by name.

## Logging Rules

- Initialize logging from `main` with `init_logging`, then register `register_crash_trap`.
- Use `log_debug`, `log_info`, `log_warn`, and `log_error` for operational events.
- Logging must be non-fatal. If log directory or file creation fails, continue the main flow.
- Default log level is `DEBUG`; users may change it through main config. Do not add automatic old-log cleanup unless explicitly requested.
- Keep log messages useful for debugging startup, config changes, downloads, PowerShell execution, uninstalls, and auto-update.
- Do not log obvious secrets directly:
  - redact `PROXY`, `GITHUB_MIRROR`, `HUGGINGFACE_MIRROR`, and `EXTRA_INSTALL_ARGS` values;
  - use `format_log_args` or `sanitize_config_log_value` when logging user-provided arguments;
  - keep project names, script names, install paths, and non-sensitive statuses visible.
- Bootstrap-before-module errors in `installer_launcher.sh` may use the minimal `early_log` helper.

## Proxy Rules

- Configure proxy before any network operation.
- `main` should load main config, call `configure_proxy_from_main_config`, then load project config and continue to auto-update/dispatch.
- In `auto` mode, do not override existing `HTTP_PROXY`, `HTTPS_PROXY`, `http_proxy`, or `https_proxy`.
- In `manual` mode, use `MANUAL_PROXY`; in `off` mode, clear proxy variables for the launcher process.
- Keep `install.sh` proxy detection self-contained because it runs before launcher modules are available.

## Configuration Rules

- Main config stores `CURRENT_PROJECT`, `AUTO_UPDATE_ENABLED`, `SHOW_WELCOME_SCREEN`, `LOG_LEVEL`, `PROXY_MODE`, `MANUAL_PROXY`, and `AUTO_UPDATE_LAST_CHECK`.
- `CURRENT_PROJECT` defaults to empty. Do not silently default it to a project.
- `AUTO_UPDATE_ENABLED` defaults to `1`.
- `SHOW_WELCOME_SCREEN` defaults to `1`.
- `LOG_LEVEL` defaults to `DEBUG` and must be one of `DEBUG`, `INFO`, `WARN`, or `ERROR`.
- `PROXY_MODE` defaults to `auto` and must be one of `auto`, `manual`, or `off`.
- `MANUAL_PROXY` defaults to empty and is used only when `PROXY_MODE=manual`.
- `null`, `none`, `nil`, and `undefined` are normalized to empty for `CURRENT_PROJECT`.
- Per-project configs live under:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/installer-launcher/projects/<project>.conf
```

- Main config lives at:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/installer-launcher/main.conf
```

- Installer cache lives under:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/installer-launcher/installers/<project>/
```

- Runtime logs live under:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/installer-launcher/logs/
```

- The launcher itself installs to:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/installer-launcher
```

- The registered launcher command is:

```text
$HOME/.local/bin/installer-launcher
```

- `WORKSPACE_DIR` was removed. Do not reintroduce workspace-based fallback behavior.
- Effective install path is:
  - configured `INSTALL_PATH`, or
  - default `$HOME/<project default directory>`.

## Project Registry Rules

Project definitions belong in `lib/projects.sh`.

When adding or changing a project:

- Add/update the project key in `PROJECT_KEYS`.
- Define:
  - `PROJECT_<key>_NAME`
  - `PROJECT_<key>_INSTALLER_URL`
  - `PROJECT_<key>_INSTALLER_FILE`
  - `PROJECT_<key>_DEFAULT_DIR`
  - `PROJECT_<key>_MANAGEMENT_SCRIPTS`
  - `PROJECT_<key>_PARAMS`
- Add branches only when the upstream installer supports `InstallBranch`.
- Only include management scripts users should run directly.
  - Do not expose `activate.ps1`; `terminal.ps1` handles activation.
  - Do not expose removed internal entries like `init.ps1` and `tensorboard.ps1`.

## Parameter Rules

- TUI and CLI must respect per-project capability tables.
- Do not show or pass parameters unsupported by the selected project.
- `NoPause` is not a user-facing config option.
  - If the selected project supports it, append `-NoPause` automatically.
  - Do not add duplicate `-NoPause`.
- `run-installer` must explicitly pass `-InstallPath` when supported.
- `EXTRA_INSTALL_ARGS` is appended after structured installer arguments.

## TUI Rules

- Use helpers in `lib/ui.sh`; do not call `dialog` directly from new code unless adding a reusable helper.
- TUI sizes must be computed from terminal dimensions. Do not hard-code dialog heights or widths in feature code.
- Use `text_viewer` for long text such as help and config output.
- Use `confirm_screen` before destructive or long-running actions.
- `run-installer` must show an installation confirmation with effective config before downloading or executing.
- Downloading the installer should use normal text output, not a dialog progress gauge.
- The main menu status should include:
  - current project,
  - installation state,
  - detection detail,
  - next-step guidance.
- If no current project is selected, TUI actions that need a project must show a clear prompt instead of failing.

## Runner Rules

- Always download the installer fresh before running it.
- Download into the cache directory, not the project directory.
- Use `pwsh -NoLogo -ExecutionPolicy Bypass -File` when available; fall back to `powershell` with the same arguments when `pwsh` is not found.
- `run_installer` flow:
  1. Load project config.
  2. Build installer args.
  3. Show confirmation.
  4. Download installer.
  5. Execute PowerShell script.
- `run_management_script` should:
  - find scripts only under the effective install path,
  - append `-NoPause` when supported,
  - show special hints:
    - `launch.ps1`: Ctrl+C terminates the running service.
    - `terminal.ps1`: type `exit` and press Enter to leave the terminal.
- Project uninstall must use two confirmations:
  - first a warning confirmation,
  - then a typed confirmation using the exact displayed text.
- Project uninstall must refuse obviously dangerous paths such as empty path, `/`, or `$HOME`.

## CLI Rules

- Keep CLI usage text synchronized with implemented commands.
- Commands requiring a current project must validate it with `require_project_key`.
- `list-projects` must work even when no current project is selected.
- `set-main CURRENT_PROJECT null` should clear the current project.
- `install-launcher` installs or updates this launcher from `licyk/sd-webui-all-in-one-launcher`.
- `install-launcher --yes` skips only the install confirmation and is intended for `install.sh`.
- `uninstall-launcher` must remove the installed launcher, registered command, shell PATH block, config directory, and cache directory after the same two-confirmation pattern used by project uninstall.
- Startup auto-update checks must be non-fatal. If the check or update fails, continue running and show a user-facing notice.
- Do not re-add removed commands such as:
  - `check-install`
  - `download-only`
  - `update-mode`

## Validation Checklist

After modifying scripts, run:

```bash
bash -n install.sh installer_launcher.sh lib/*.sh
shellcheck install.sh installer_launcher.sh lib/*.sh
```

For behavior changes, add a focused smoke test. Examples:

```bash
./installer_launcher.sh --help
./installer_launcher.sh list-projects
tmpdir=$(mktemp -d)
XDG_CONFIG_HOME="$tmpdir" ./installer_launcher.sh set-main CURRENT_PROJECT comfyui
XDG_CONFIG_HOME="$tmpdir" ./installer_launcher.sh config comfyui
```

For UI helper changes, test functions directly in a clean shell when possible:

```bash
bash --noprofile --norc -u -c 'source lib/bootstrap.sh; dialog_menu_size h w mh 9; printf "%s %s %s\n" "$h" "$w" "$mh"'
```

## Documentation Rules

- Keep `docs/todo.md` updated for every change.
- Update TUI help text when user-facing behavior changes.
- Keep `AGENTS.md` current when project conventions change.
