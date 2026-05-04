# Architecture

本文档说明 `sd-webui-all-in-one-launcher` 的模块划分、数据流和主要运行流程。

## 总体结构

项目包含两个启动器入口，用于通过 `sd-webui-all-in-one` 系列 PowerShell 安装器安装和管理多个 AI WebUI / 训练工具：

- Bash 5+ TUI/CLI 启动器：入口为 `installer_launcher.sh`，业务逻辑拆分在 `lib/`。
- Windows PowerShell WPF GUI 启动器：源码入口为 `installer_launcher_gui.ps1`，业务逻辑拆分在 `gui/`；发布时通过 `tools/compile_gui.py` 生成单文件产物。

```text
installer_launcher.sh
└── lib/bootstrap.sh
    ├── lib/core.sh
    ├── lib/proxy.sh
    ├── lib/projects.sh
    ├── lib/config.sh
    ├── lib/ui.sh
    ├── lib/runner.sh
    ├── lib/self_manage.sh
    ├── lib/menus.sh
    └── lib/cli.sh

installer_launcher_gui.ps1
└── gui/bootstrap.ps1
    ├── gui/core.ps1
    ├── gui/registry.ps1
    ├── gui/config.ps1
    ├── gui/runtime.ps1
    ├── gui/ui-dialogs.ps1
    ├── gui/ui-wpf.ps1
    ├── gui/ui-pages.ps1
    └── gui/app.ps1

tools/compile_gui.py
└── dist/installer_launcher_gui.ps1
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
- 启动器联网代理处理集中在 `lib/proxy.sh`，并在自动更新、下载安装器等联网操作之前执行。
- Windows GUI 使用独立 PowerShell 实现，但行为需要与 Bash 版的项目注册表、参数构建、代理模式和安装检测保持一致。

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

## Windows GUI 架构

Windows GUI 只面向 Windows PowerShell/WPF 环境。开发时维护多文件源码，用户安装、自更新和 Release 下载使用编译后的单文件产物。

```text
开发入口: installer_launcher_gui.ps1
源码模块: gui/*.ps1
XAML 视图: gui/xaml/*.xaml
编译器: tools/compile_gui.py
发布产物: dist/installer_launcher_gui.ps1
```

`installer_launcher_gui.ps1` 是薄入口，只负责参数、Windows 环境检查、加载 `gui/bootstrap.ps1`，以及分发 `Start-App` / `-UninstallLauncher`。实际业务逻辑必须放在 `gui/` 模块中。Release 产物会把模块和 XAML 内嵌成单文件，因此正式安装、`install.ps1`、自更新都应指向 Release asset，而不是仓库根目录的源码入口。

### GUI 模块分层

`gui/bootstrap.ps1` 按固定顺序加载模块：

- `gui/core.ps1`：GUI 版本、路径常量、通用 helper、Add-Type、日志、崩溃记录、全局状态初始化。
- `gui/registry.ps1`：项目注册表、安装器下载源、默认目录、分支、安装器参数、管理脚本和脚本参数定义。这里需要与 `lib/projects.sh` 保持同步。
- `gui/config.ps1`：主配置和项目 JSON 配置读写、默认值补齐、代理配置、安装状态检测、参数构建。
- `gui/runtime.ps1`：Runspace 后台任务、操作锁、下载重试、外部 PowerShell 控制台启动、进程树终止、自更新、快捷方式、启动器卸载。
- `gui/ui-dialogs.ps1`：消息框、倒计时确认、用户协议、帮助窗口、日志窗口和输入窗口。
- `gui/ui-wpf.ps1`：XAML 加载、主题资源、窗口效果、标题栏/最大化、导航动画、Tab 动画、头图和图标加载。
- `gui/ui-pages.ps1`：页面刷新、动态安装器配置 UI、管理脚本参数 UI、安装状态刷新、已安装 WebUI 搜索和多路径选择。
- `gui/app.ps1`：`Start-App`、主窗口控件收集、事件注册、启动流程和退出流程。

PowerShell 5.1 对 WPF 事件和 `DispatcherTimer` 回调的函数查找范围更窄。所有会被 WPF 事件调用的 helper 都要在注册事件前通过 `Export-GuiEventFunctions` 导出到 `Global:`，不要依赖本地闭包或 `$script:GuiHandler_*` 缓存脚本块。

### GUI 数据路径

Windows GUI 数据路径：

```text
主配置: %APPDATA%\installer-launcher\main.json
项目配置: %APPDATA%\installer-launcher\projects\<project>.json
缓存目录: %LOCALAPPDATA%\installer-launcher\cache\installers\<project>\
日志目录: %LOCALAPPDATA%\installer-launcher\logs\
```

配置目录还会缓存 GUI 头图、快捷方式图标和已安装的 GUI 脚本本体。项目的当前管理目标仍由项目配置中的 `INSTALL_PATH` 决定；已安装 WebUI 搜索结果只是运行时选择列表，用户点击“设为当前管理目标”后才会写入对应项目配置。

### GUI 启动流程

GUI 启动时按以下顺序初始化：

1. 初始化路径、日志和崩溃处理，并记录 PowerShell 版本、Edition、Host、CLR 和 OS。
2. 注册当前用户级卸载项，便于系统设置或控制面板调用 `-UninstallLauncher`。
3. 加载主配置和项目配置，补齐默认值。
4. 按 `PROXY_MODE` 配置当前进程代理，保证后续更新、头图、图标和安装器下载使用正确代理。
5. 首次启动时展示用户协议；用户拒绝则退出，用户同意后写入 `USER_AGREEMENT_ACCEPTED`。
6. 加载 XAML 主窗口。源码模式读取 `gui/xaml/`，编译产物优先读取 `$script:BundledXamlResources` 中的内嵌 XAML。
7. 收集控件、导出 WPF 事件 helper、注册事件和定时器。
8. 刷新当前项目、安装状态、一键启动模式、动态参数 UI 和运行日志。
9. 后台加载/下载头图和图标，并按自动更新间隔触发非致命更新检查。

### GUI 页面职责

- “一键启动”：面向日常使用。未安装时默认安装模式，运行当前项目 installer；已安装时默认启动模式，列出可用管理脚本并通过统一启动按钮运行。
- “高级选项”：维护当前项目的安装路径、installer 参数和管理脚本参数；输入变化自动保存。
- “软件选择”：选择要安装或管理的 WebUI / 工具，并显示当前选中的项目和管理路径。
- “设置”：维护 GUI 主配置，包括自动更新、日志等级、代理模式、目录入口、快捷方式创建和启动器卸载。
- “关于”：展示项目链接、版本信息、头图和用户协议。

### GUI 操作流

耗时操作通过 `Start-GuiOperation` 进入后台 Runspace。UI 侧使用 `DispatcherTimer` 轮询任务状态，并在完成后统一恢复按钮、刷新安装状态、写入日志和展示必要提示。

安装器运行流程：

1. 从当前项目配置构建结构化参数，支持 `InstallPath` 时显式传入安装路径。
2. 追加额外原始参数，最后自动追加 `-NoPause` 并避免重复。
3. 每次运行前按下载源顺序重新下载安装到缓存目录。
4. 创建 wrapper，在独立 PowerShell 控制台中运行 installer，保留上游输出。
5. 记录外部进程 PID、退出码、脚本路径和参数摘要；非零退出时提示用户查看控制台输出。

管理脚本运行流程：

1. 只从当前有效安装路径中查找可直接运行的管理脚本。
2. 根据当前脚本支持的参数动态构建参数 UI。
3. 启动独立 PowerShell 控制台运行脚本，并记录 PID。
4. 运行中可以点击“终止当前任务”，确认后递归终止当前 GUI 实例创建的进程树，不扫描或终止用户手动打开的终端。

已安装 WebUI 搜索流程：

1. 默认异步扫描固定磁盘，或由用户选择目录扫描。
2. 以 `launch_*_installer.ps1` 作为特征文件识别项目类型。
3. 将特征脚本父目录作为候选安装路径，并用该项目的管理脚本列表做轻量校验。
4. 用户选择候选项后，写入 `CURRENT_PROJECT` 和对应项目 `INSTALL_PATH`，再刷新状态和脚本列表。

### GUI 编译与验证

GUI 发布流程：

1. 开发时维护 `installer_launcher_gui.ps1`、`gui/*.ps1` 和 `gui/xaml/*.xaml`。
2. 发布前运行 `python tools/compile_gui.py --output dist/installer_launcher_gui.ps1`。
3. 编译器按 `gui/bootstrap.ps1` 中的模块顺序展开代码，并将 XAML 以 Base64 UTF-8 资源内嵌。
4. Release 上传 `dist/installer_launcher_gui.ps1`；`install.ps1` 和 GUI 自更新都下载该编译产物。

修改 GUI 模块、XAML、编译器、安装脚本或 Release 流程后，至少需要完成：

- 重新生成 `dist/installer_launcher_gui.ps1`。
- 解析检查源码入口、所有 `gui/*.ps1`、`install.ps1` 和编译产物。
- 解析检查源码 XAML 和编译产物中的内嵌 XAML。
- 运行 `git diff --check`。

触及 Bash 入口、`lib/`、`install.sh` 或共享文档中的命令时，还需要运行 Bash 侧的 `bash -n` 和 `shellcheck`。完整命令和 Windows 手动验证清单记录在 `docs/gui-compiler.md`。

## 模块职责

### `lib/bootstrap.sh`

统一加载所有模块，并设置 `INSTALLER_LAUNCHER_ROOT`。

加载顺序很重要：

1. `core.sh` 提供全局常量和基础工具。
2. `proxy.sh` 依赖核心 helper，并提供系统代理检测和代理环境设置。
3. `projects.sh` 依赖核心 helper，并提供项目元数据。
4. `config.sh` 依赖项目注册表。
5. `ui.sh` 提供 TUI/text helper。
6. `runner.sh` 依赖配置、项目和 UI。
7. `self_manage.sh` 依赖下载和 UI helper。
8. `menus.sh` 组合 TUI 交互。
9. `cli.sh` 提供 `main` 命令分发。

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

### `lib/proxy.sh`

负责启动器运行期的代理处理。`main` 会在加载主配置后、自动更新和命令分发前调用 `configure_proxy_from_main_config`，保证之后的联网操作使用已选代理策略。

代理模式保存在主配置 `PROXY_MODE` 中：

- `auto`：默认模式。若用户已经设置 `HTTP_PROXY`、`HTTPS_PROXY`、`http_proxy` 或 `https_proxy`，则不覆盖；否则尝试读取系统代理并设置到当前启动器进程。
- `manual`：使用主配置 `MANUAL_PROXY`，并显式覆盖当前启动器进程的代理环境变量；如果手动代理地址为空，则清理代理环境变量。
- `off`：清理当前启动器进程中的代理环境变量，使启动器联网操作不使用代理。

系统代理读取来源：

- Windows：当前用户 Internet Settings 注册表。
- Linux GNOME：`gsettings org.gnome.system.proxy`。
- Linux KDE：`~/.config/kioslaverc`。
- macOS：`scutil --proxy`。

`install.sh` 在启动器模块加载前运行，因此保留独立的自动代理检测逻辑，不读取启动器主配置。

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
- `PROXY_MODE`
- `MANUAL_PROXY`
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
- 安装器和管理脚本执行时自动追加 `-NoPause`。
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
├── load_main_config
├── configure_proxy_from_main_config
├── load_project_config 当前项目
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
- `NoPause` 不展示为用户配置项；安装器和管理脚本执行时都会自动追加 `-NoPause`，并避免重复添加。

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
