# Architecture

本文档说明 `sd-webui-all-in-one-launcher` 的模块划分、数据流和主要运行流程。

## 总体结构

项目是一个 Bash 5+ 编写的 TUI/CLI 启动器，用于通过 `sd-webui-all-in-one` 系列 PowerShell 安装器安装和管理多个 AI WebUI / 训练工具。入口脚本只负责运行环境检查和加载模块，业务逻辑拆分在 `lib/` 目录中。

```text
installer_launcher.sh
└── lib/bootstrap.sh
    ├── lib/core.sh
    ├── lib/projects.sh
    ├── lib/config.sh
    ├── lib/ui.sh
    ├── lib/runner.sh
    ├── lib/self_manage.sh
    ├── lib/menus.sh
    └── lib/cli.sh
```

核心原则：

- 入口脚本保持轻量，不承载业务逻辑。
- 项目元数据集中在 `lib/projects.sh`。
- 配置读写集中在 `lib/config.sh`。
- UI 交互通过 `lib/ui.sh` helper 统一处理。
- PowerShell 安装器下载和执行集中在 `lib/runner.sh`。
- 启动器自身安装/卸载集中在 `lib/self_manage.sh`。
- 启动器自动更新检查集中在 `lib/self_manage.sh`，启动分发由 `lib/cli.sh` 调用。
- 日志和异常退出记录集中在 `lib/core.sh`，由 `lib/cli.sh` 启动时初始化。

## 入口脚本

`installer_launcher.sh` 是唯一直接执行入口。

职责：

- 在 macOS 上检测 Bash 版本。
- 当 macOS Bash 低于 5 时，尝试使用 `/opt/homebrew/bin/bash` 递归运行自身。
- 启用 `set -Eeuo pipefail`。
- 计算 `SCRIPT_DIR`。
- 加载 `lib/bootstrap.sh`。
- 调用 `main "$@"`。

入口脚本中位于 strict mode 之前的逻辑需要兼容 macOS 自带 Bash 3.x。

## 模块职责

### `lib/bootstrap.sh`

统一加载所有模块，并设置 `INSTALLER_LAUNCHER_ROOT`。

加载顺序很重要：

1. `core.sh` 提供全局常量和基础工具。
2. `projects.sh` 依赖核心 helper，并提供项目元数据。
3. `config.sh` 依赖项目注册表。
4. `ui.sh` 提供 TUI/text helper。
5. `runner.sh` 依赖配置、项目和 UI。
6. `self_manage.sh` 依赖下载和 UI helper。
7. `menus.sh` 组合 TUI 交互。
8. `cli.sh` 提供 `main` 命令分发。

### `lib/core.sh`

提供应用级常量和通用函数。

主要内容：

- `APP_NAME`、`APP_TITLE`、`APP_VERSION`。
- 配置、缓存和状态路径常量。
- 自动更新检查间隔常量。
- `CURRENT_PROJECT` 默认值。
- 自动更新和欢迎页默认值。
- `PROJECT_CONFIG_KEYS`。
- 日志初始化、日志级别判断、日志写入和敏感信息脱敏。
- `ERR` trap 崩溃记录和调用栈输出。
- `die`、`info`、`need_cmd`。
- `normalize_project_key_value`。
- `require_project_key`。
- `quote_config`。
- `split_args`。

`CURRENT_PROJECT` 默认是空值。需要项目上下文的操作必须调用 `require_project_key`。

### `lib/projects.sh`

项目注册表。

每个项目定义：

- 展示名称。
- 安装器首选 URL。
- 安装器 URL 列表。
- 安装器文件名。
- 默认安装目录。
- 可选分支列表。
- 管理脚本列表。
- 支持的安装器参数。

关键 helper：

- `project_name`
- `project_installer_url`
- `project_installer_urls`
- `project_installer_file`
- `project_default_dir`
- `project_default_branch`
- `project_default_install_path`
- `script_entries_for_project`
- `branch_entries_for_project`
- `project_supports_param`

TUI 和 CLI 都应通过这些 helper 获取项目能力，避免硬编码项目行为。

### `lib/config.sh`

负责主配置和项目配置的生命周期。

主配置：

```text
${XDG_CONFIG_HOME:-$HOME/.config}/installer-launcher/main.conf
```

项目配置：

```text
${XDG_CONFIG_HOME:-$HOME/.config}/installer-launcher/projects/<project>.conf
```

主要职责：

- 创建默认配置。
- 加载主配置和项目配置。
- 保存主配置和项目配置。
- 重置项目配置变量。
- 按项目能力校验配置项。
- 展示当前配置。

主配置保存：

- `CURRENT_PROJECT`
- `AUTO_UPDATE_ENABLED`
- `SHOW_WELCOME_SCREEN`
- `LOG_LEVEL`
- `AUTO_UPDATE_LAST_CHECK`

项目配置保存安装路径、分支、镜像、代理、额外参数和子脚本默认参数。

### `lib/ui.sh`

封装 TUI 和纯文本交互。

如果系统存在 `dialog` 且 stdout 是 TTY，则启用 dialog TUI；否则使用文本交互。

主要 helper：

- `init_ui`
- `dialog_available`
- `terminal_size`
- `dialog_*_size`
- `show_error`
- `pause_screen`
- `text_viewer`
- `confirm_screen`
- `input_box`
- `menu_select`
- `checklist_select`

所有 TUI 尺寸都根据终端尺寸动态计算。新功能需要复用这些 helper，避免在业务代码中直接硬编码 dialog 尺寸。

### `lib/runner.sh`

负责下载、构建参数、执行 PowerShell 脚本和安装检测。

主要职责：

- 使用 `curl` 或 `wget` 下载文件。
- 计算安装器缓存路径。
- 按项目下载源列表重试下载安装器。
- 构建 PowerShell 安装器参数。
- 自动追加 `-NoPause`。
- 展示安装确认内容。
- 执行 `pwsh -NoLogo -ExecutionPolicy Bypass -File`。
- 根据安装路径检测安装状态。
- 查找并运行管理脚本。
- 卸载当前项目安装目录。

安装器运行流程：

```text
run_installer
├── load_project_config
├── installer_cache_path
├── build_installer_args
├── installer_confirmation_text
├── confirm_screen
├── download_installer
└── run_pwsh_script
```

下载流程：

```text
download_installer
└── project_installer_urls
    ├── download_file URL 1
    ├── download_file URL 2
    ├── ...
    └── 全部失败时打印已尝试 URL 并返回错误
```

项目卸载流程：

```text
uninstall_project
├── load_project_config
├── effective_install_path
├── validate_uninstall_path
├── confirm_screen
├── typed_confirm_screen
└── rm -rf -- install_path
```

项目卸载只删除有效安装路径，不删除启动器保存的项目配置。

### `lib/self_manage.sh`

负责启动器自身的安装、更新、命令注册和卸载。

安装/更新：

- 从 `licyk/sd-webui-all-in-one-launcher` 获取源码。
- 优先使用 `git clone --depth 1`。
- 没有 `git` 时下载源码压缩包。
- 安装到 `${XDG_DATA_HOME:-$HOME/.local/share}/installer-launcher`。
- 创建 `$HOME/.local/bin/installer-launcher` 符号链接。
- 向当前 shell rc 文件写入受标记管理的 PATH 配置块。

卸载：

- 删除命令链接。
- 从 `.bashrc`、`.zshrc`、`.profile` 移除 PATH 配置块。
- 删除启动器安装目录。
- 删除启动器配置目录。
- 删除启动器缓存目录。
- 卸载前需要先确认警告，再输入指定确认文本。

卸载不会删除各项目本体安装目录。

自动更新：

- 启动时由 `lib/cli.sh` 调用 `check_and_update_launcher_if_due`。
- 默认每 60 分钟最多检查一次。
- 远程版本来自 GitHub raw `lib/core.sh` 中的 `APP_VERSION`。
- 远程版本高于本地 `APP_VERSION` 时，自动下载源码并安装到用户目录。
- 检查或更新失败只写入启动提示，不中断当前命令。

### `lib/menus.sh`

组合 TUI 菜单和交互流程。

主要职责：

- 选择当前项目。
- 配置项目参数。
- 配置主配置。
- 配置子脚本默认参数。
- 构建主界面状态提示。
- 显示启动欢迎页。
- 显示 TUI 帮助。
- 分发主菜单动作。

主界面每次显示时都会自动调用安装检测逻辑，提示当前项目是否已安装、未安装或安装不完整。

### `lib/cli.sh`

命令行入口和 `main` 函数所在模块。

支持命令：

- `tui`
- `list-projects`
- `install [project]`
- `uninstall [project]`
- `run-script <script.ps1> [args...]`
- `set-main <CURRENT_PROJECT> <value>`
- `set-project <project> <key> <value>`
- `set-script-args <project> <script.ps1> <args>`
- `config [project]`
- `install-launcher`
- `uninstall-launcher`
- `show-log [lines]`

未传命令时默认进入 `tui`。

启动时 `main` 会先初始化日志和崩溃捕获，再加载配置、初始化 UI、按间隔执行自动更新检查，最后分发具体命令。

## 配置数据流

启动时：

```text
main
├── init_logging
├── register_crash_trap
├── load_all_config
│   ├── load_main_config
│   └── load_project_config 当前项目
├── init_ui
├── check_and_update_launcher_if_due
└── 分发 CLI/TUI 命令
```

项目配置只在当前项目有效时加载。如果 `CURRENT_PROJECT` 为空或无效，项目配置变量会被重置为空。

## 日志数据流

日志目录：

```text
${XDG_STATE_HOME:-$HOME/.local/state}/installer-launcher/logs/
```

日志文件按日期写入：

```text
installer-launcher-YYYYMMDD.log
```

日志默认级别为 `DEBUG`，可通过主配置 `LOG_LEVEL` 调整为 `INFO`、`WARN` 或 `ERROR`，不自动清理旧日志。写入失败不会中断主流程。

主要记录内容：

- 启动命令、参数、脚本路径、配置路径和状态路径。
- 主配置和项目配置创建、保存、修改。
- 自动更新检查结果、远程版本和更新结果。
- 安装器下载源尝试、失败和成功源。
- PowerShell 安装器、管理脚本执行摘要和返回码。
- 项目卸载和启动器卸载的确认、目标路径和结果。

异常退出时，`ERR` trap 会记录退出码、失败命令、行号、调用栈和当前命令参数。

日志会保留项目名、安装路径和脚本名；代理、镜像、额外参数和 token/password/key 类内容会做脱敏处理。

## TUI 数据流

```text
main_menu
├── show_welcome_screen
├── show_startup_notice_if_needed
├── main_menu_status
│   └── check_installation
├── menu_select
└── case choice
    ├── change_current_project
    ├── run_installer
    ├── uninstall_project
    ├── run_management_script
    ├── configure_script_args
    ├── configure_project
    ├── configure_main
    ├── show_config
    ├── install_launcher
    ├── uninstall_launcher
    └── show_tui_help
```

需要项目上下文的入口必须先调用 `ensure_current_project_selected`。

## 安装器参数构建

参数构建以项目能力表为准。

例如：

- 只有项目支持 `InstallPath` 时才传 `-InstallPath`。
- 只有项目支持 `InstallBranch` 时才传 `-InstallBranch`。
- 只有项目支持 `UseCustomProxy` 时才传 `-UseCustomProxy`。
- `NoPause` 不展示为用户配置项，但项目支持时自动追加 `-NoPause`。

`EXTRA_INSTALL_ARGS` 会在结构化参数之后追加，适合临时传递未内置的安装器参数。

## 安装检测

安装检测只基于有效安装路径：

```text
INSTALL_PATH 或 $HOME/<项目默认目录>
```

检测结果：

- 返回 `0`：安装路径存在，并找到至少一个管理脚本。
- 返回 `1`：安装路径不存在。
- 返回 `2`：安装路径存在，但没有找到管理脚本。

主界面会将这些状态转换为用户提示。

## 启动欢迎页

TUI 启动时默认显示欢迎页。

欢迎页展示：

- 当前启动器版本。
- 当前安装器。
- 自动更新开关状态。
- 自动更新启动提示。
- dialog 常用操作方式。

是否显示由主配置 `SHOW_WELCOME_SCREEN` 控制。

如果欢迎页关闭，但自动更新产生了失败或成功提示，启动器会单独显示提示，避免用户错过更新状态。

## 文档目录

`docs/` 存放项目维护文档：

- `docs/todo.md`：当前完成状态、验证记录和后续待办。
- `docs/architecture.md`：项目架构、模块职责和主要流程。

面向普通用户的文档保留在仓库根目录 `README.md`。
