# TODO

## 当前状态

- [x] 项目已完成多文件模块化重构，入口为 `installer_launcher.sh`，主逻辑位于 `lib/`。
- [x] 支持 7 个安装器：SD WebUI、ComfyUI、InvokeAI、Fooocus、SD Trainer、SD Trainer Script、Qwen TTS WebUI。
- [x] TUI 和 CLI 都基于当前项目配置运行，`CURRENT_PROJECT` 默认为空，首次使用需选择安装器。
- [x] 安装器每次运行前都会重新下载到缓存目录，确保使用最新脚本。
- [x] 安装器支持多个下载源，按顺序重试，任意一个下载成功即可继续执行。
- [x] 运行安装器前会展示确认页，用户确认后才下载并执行。
- [x] 支持卸载每个类型对应的已安装软件，卸载前需要警告确认和输入指定文本的最终确认。
- [x] 支持从 GitHub 安装/更新启动器自身，并注册 `installer-launcher` 命令。
- [x] 支持 `install.sh` 一键引导安装依赖并自动安装启动器。
- [x] 入口脚本会解析符号链接真实路径，确保通过 `$HOME/.local/bin/installer-launcher` 启动时能加载安装目录中的 `lib/`。
- [x] 如果解析真实路径后仍找不到 `lib/bootstrap.sh`，入口脚本会回退到 `${XDG_DATA_HOME:-$HOME/.local/share}/installer-launcher`。
- [x] 支持启动时自动检查启动器更新，默认启用，检查间隔 60 分钟。
- [x] 支持 TUI 启动欢迎页，默认显示，可在启动器主配置中关闭。
- [x] 支持统一日志系统，默认 DEBUG 级别，异常退出时记录崩溃上下文。
- [x] 支持启动时按启动器代理模式处理联网代理，默认自动读取系统代理。
- [x] 支持 `show-log [lines]` 查看当前日志路径和最近日志内容。
- [x] 支持卸载启动器自身，卸载时移除命令注册、配置目录和缓存目录。
- [x] `AGENTS.md` 已创建，用于记录项目约定、编码风格和验证规则。
- [x] `README.md` 已创建，用于面向用户说明安装、TUI/CLI 使用、配置、下载策略和卸载。
- [x] 已新增 Windows PowerShell WPF GUI 版启动器 `installer_launcher_gui.ps1`。
- [x] `docs/` 已创建，维护类文档已迁移到该目录。
- [x] `docs/architecture.md` 已创建，用于说明项目架构、模块职责和主要流程。
- [x] 本文件已整理为分组状态板，避免继续堆叠流水账。

## 项目结构

- [x] `lib/core.sh`：应用常量、通用工具、日志系统、崩溃捕获、项目键校验。
- [x] `lib/proxy.sh`：系统代理检测和联网前代理环境变量设置。
- [x] `lib/projects.sh`：项目注册表、安装器 URL 列表、支持参数、管理脚本列表。
- [x] `lib/config.sh`：主配置和项目配置的创建、加载、保存、展示。
- [x] `lib/ui.sh`：dialog/text UI 适配、动态尺寸、确认框、文本查看器。
- [x] `lib/runner.sh`：下载、参数构建、PowerShell 执行、安装检测、管理脚本运行、项目安装目录卸载。
- [x] `lib/self_manage.sh`：启动器自身安装、命令注册、卸载和 shell 配置清理。
- [x] `lib/menus.sh`：TUI 菜单、配置交互、主界面状态、帮助页面。
- [x] `lib/cli.sh`：CLI 命令分发和帮助文本。
- [x] `lib/bootstrap.sh`：统一加载模块。
- [x] `installer_launcher_gui.ps1`：Windows-only 单文件 WPF GUI，内置项目注册表、配置、下载、执行、日志、代理和自动更新。

## 配置与项目选择

- [x] 主配置包含 `CURRENT_PROJECT`、`AUTO_UPDATE_ENABLED`、`SHOW_WELCOME_SCREEN`、`LOG_LEVEL`、`PROXY_MODE`、`MANUAL_PROXY`、`AUTO_UPDATE_LAST_CHECK`。
- [x] `CURRENT_PROJECT` 默认为空，不再隐式回填 `sd_webui`。
- [x] `AUTO_UPDATE_ENABLED` 默认为 `1`。
- [x] `SHOW_WELCOME_SCREEN` 默认为 `1`。
- [x] `LOG_LEVEL` 默认为 `DEBUG`，可设置为 `DEBUG`、`INFO`、`WARN`、`ERROR`。
- [x] `PROXY_MODE` 默认为 `auto`，可设置为 `auto`、`manual`、`off`。
- [x] `MANUAL_PROXY` 默认为空，仅在 `PROXY_MODE=manual` 时使用。
- [x] `null` / `NULL` / `none` / `nil` / `undefined` 会被视为未选择。
- [x] 未选择项目时，TUI 显示“未选择”，需要项目上下文的操作会提示先选择安装器。
- [x] `set-main CURRENT_PROJECT null` 可清空当前项目。
- [x] 已移除 `WORKSPACE_DIR` 及其管理脚本查找兜底逻辑。
- [x] 每个项目使用独立配置文件：`${XDG_CONFIG_HOME:-$HOME/.config}/installer-launcher/projects/<project>.conf`。

## 参数与安装器运行

- [x] 为项目注册表增加参数能力表。
- [x] TUI 配置界面按当前项目支持的参数动态显示字段。
- [x] 构建安装器参数时只传递当前项目支持的参数。
- [x] `set-project` 会拒绝设置当前项目不支持的结构化配置项。
- [x] `NoPause` 不再作为用户配置项；运行安装器和管理脚本时始终自动追加 `-NoPause`，并避免重复添加。
- [x] 运行安装器时显式传入 `-InstallPath`，未配置时使用 `$HOME/<项目默认目录>`。
- [x] `EXTRA_INSTALL_ARGS` 会追加到结构化安装器参数之后。
- [x] 运行安装器前展示确认信息，包括项目、安装器下载源列表、缓存路径、安装路径、PowerShell 参数和当前项目配置。
- [x] 用户取消确认时不会下载，也不会执行 PowerShell。
- [x] PowerShell 安装器返回非零退出代码时，会停留在当前终端提示用户查看输出日志，按 Enter 后再返回 TUI。
- [x] 执行 PowerShell 脚本时优先使用 `pwsh`，找不到时回退到 `powershell`。

## 下载与缓存

- [x] 安装器下载位置为 `${XDG_CACHE_HOME:-$HOME/.cache}/installer-launcher/installers/<project>/`。
- [x] 运行安装器前每次重新下载。
- [x] 每个安装器配置 5 个下载源：GitHub Release、Gitee Release、GitHub raw、Gitee raw、GitLab raw。
- [x] 下载安装器时按下载源顺序重试，只要一个源下载成功就执行安装器。
- [x] 所有下载源都失败时返回错误，并打印已尝试的下载地址。
- [x] 已移除“仅下载安装器”功能。
- [x] 下载阶段使用普通文本提示，不再使用 dialog 进度条。

## 系统代理

- [x] 启动器启动后、配置加载和自动更新前会按 `PROXY_MODE` 处理代理。
- [x] `auto` 模式会自动检测系统代理；如果用户已经设置代理环境变量，则不会覆盖。
- [x] `manual` 模式会使用 `MANUAL_PROXY`，并覆盖当前启动器进程的代理环境变量；手动代理为空时会清理代理环境变量。
- [x] `off` 模式会清理当前启动器进程的代理环境变量，让启动器不使用代理。
- [x] 已支持 Windows 注册表代理、GNOME gsettings、KDE kioslaverc、macOS scutil 代理读取。
- [x] 检测到系统代理后会设置 `HTTP_PROXY`、`HTTPS_PROXY`、小写代理变量和 `NO_PROXY`。
- [x] 启动器主配置界面可调整代理模式和手动代理地址。
- [x] CLI 支持 `set-main PROXY_MODE auto|manual|off` 和 `set-main MANUAL_PROXY <url>`。
- [x] `install.sh` 内置独立代理检测，确保安装 Homebrew、PowerShell 等依赖前也能使用系统代理。

## 日志与崩溃记录

- [x] 日志目录为 `${XDG_STATE_HOME:-$HOME/.local/state}/installer-launcher/logs/`。
- [x] 日志文件按日期写入 `installer-launcher-YYYYMMDD.log`。
- [x] 默认日志级别为 `DEBUG`，可通过主配置修改，不自动清理旧日志。
- [x] 已提供 `log_debug`、`log_info`、`log_warn`、`log_error` helper。
- [x] `main` 启动时初始化日志并注册 `ERR` trap。
- [x] `die()` 会同时写入 `ERROR` 日志。
- [x] bootstrap 前找不到 `lib/bootstrap.sh` 时会用 early log 记录有限错误信息。
- [x] 崩溃日志记录退出码、失败命令、行号、调用栈和当前命令参数。
- [x] 已记录启动、配置变更、自动更新、下载源尝试、PowerShell 执行、管理脚本运行、项目卸载和启动器卸载等关键操作。
- [x] 对代理、镜像、额外参数和 token/password/key 类内容做日志脱敏。
- [x] 日志写入失败不影响主流程，最多向 stderr 提示一次。

## 启动器自身安装与卸载

- [x] 新增 `install.sh` bootstrap 脚本，用于检查并安装 Homebrew、PowerShell、dialog、git 等依赖。
- [x] 新增 `install-launcher` CLI 命令。
- [x] 新增 `uninstall-launcher` CLI 命令。
- [x] 主界面新增“安装/更新启动器”入口。
- [x] 主界面新增“卸载启动器”入口。
- [x] 安装/更新启动器时从 `https://github.com/licyk/sd-webui-all-in-one-launcher` 获取最新源码。
- [x] 启动时自动读取远程 `lib/core.sh` 中的 `APP_VERSION` 判断是否存在新版本。
- [x] 自动更新失败不会中断启动器运行，会在启动时给用户提示。
- [x] 自动更新检查和自我更新执行时会输出简短阶段状态，避免长时间静默。
- [x] 启动器默认安装到 `${XDG_DATA_HOME:-$HOME/.local/share}/installer-launcher`。
- [x] 注册命令为 `$HOME/.local/bin/installer-launcher`。
- [x] 注册命令时会向当前 shell 的 rc 文件写入受标记管理的 PATH 配置块。
- [x] `install-launcher --yes` 可跳过安装确认，用于 `install.sh` 非交互安装启动器。
- [x] 卸载时会移除安装目录、命令链接、shell PATH 配置块、配置目录和缓存目录。
- [x] 卸载启动器自身时使用警告确认和输入指定文本的最终确认。
- [x] 卸载不会删除 Stable Diffusion WebUI、ComfyUI 等项目本体安装目录。

## 已安装软件卸载

- [x] 新增 `uninstall [project]` CLI 命令。
- [x] 主界面新增“卸载当前已安装软件”入口。
- [x] 卸载项目时只删除有效安装路径，不删除启动器项目配置。
- [x] 卸载项目时拒绝空路径、根目录和 HOME 目录等危险路径。
- [x] 卸载项目时先展示警告确认，再要求输入 `DELETE <project>`。

## 安装检测与主界面

- [x] 已移除独立 `check-install` CLI/TUI 入口。
- [x] 主界面顶部会自动检测当前项目安装状态。
- [x] 检测基于有效安装路径：`INSTALL_PATH` 或默认 `$HOME/<项目默认目录>`。
- [x] 已安装时显示安装路径，不重复显示 `已安装: 项目名称`。
- [x] 未安装时提示：可先修改当前安装器配置，然后选择“下载安装器并运行”。
- [x] 安装目录存在但缺少管理脚本时提示：当前安装不完整，请重新运行安装器完成安装。
- [x] 已安装时提示：可以运行管理脚本执行启动、更新或维护操作。

## 管理脚本

- [x] 管理脚本只从有效安装路径查找。
- [x] 已根据 `manager_script_docs.md` 为管理脚本增加按脚本粒度的参数能力表。
- [x] TUI 中“调整子脚本默认启动参数”已改为动态结构化配置界面，只显示当前管理脚本支持的参数。
- [x] CLI 已新增 `set-script-param <project> <script.ps1> <param> <value>`，用于配置管理脚本结构化参数。
- [x] GUI 管理脚本页已增加动态参数配置面板，并保留额外原始参数作为兜底。
- [x] 修复 GUI 管理脚本下拉框显示 `@{Name=...; Label=...}` 的问题，改用 `ComboBoxItem.Content/Tag` 分离显示文本和真实脚本名。
- [x] 修复 GUI 事件处理失败时因日志控件缺失属性再次报错的问题。
- [x] 运行管理脚本时会先拼接结构化参数，再追加额外原始参数，最后自动追加 `-NoPause` 并避免重复。
- [x] `terminal.ps1` 会自动处理环境激活，因此已移除 `activate.ps1` 入口。
- [x] 已从管理脚本入口中移除 `init.ps1` 和 `tensorboard.ps1`。
- [x] 运行 `launch.ps1` 前显示确认提示，说明确认后继续执行且可按 `Ctrl+C` 终止。
- [x] 运行 `terminal.ps1` 前显示确认提示，说明确认后打开交互终端，输入 `exit` 并回车退出。
- [x] `terminal.ps1` 的界面说明已改为打开交互终端，可在已激活的项目环境中执行命令。
- [x] 管理脚本返回非零退出代码时，会停留在当前终端提示用户查看 PowerShell 输出日志，按 Enter 后再返回 TUI。
- [x] 子脚本默认参数可按项目配置保存。
- [x] 子脚本结构化参数会随项目配置保存，并在 `show-config` 中展示。

## TUI

- [x] TUI 使用 `dialog`，并统一通过 `lib/ui.sh` helper 调用。
- [x] dialog 尺寸根据终端大小动态计算，不再直接硬编码宽高。
- [x] 长文本使用 `text_viewer` 和 `dialog --textbox` 展示。
- [x] TUI 帮助页面已添加到主界面。
- [x] TUI 启动欢迎页已添加，展示版本信息、自动更新状态和 dialog 操作提示。
- [x] 启动欢迎页可通过“启动器主配置”关闭或开启。
- [x] 启动欢迎页使用非致命展示；dialog 取消、终端尺寸问题或渲染失败不会导致启动器退出。
- [x] TUI 帮助文档已补充首次使用流程、状态含义、配置细节、常见问题和 CLI 辅助命令。
- [x] `show-config` 使用 `text_viewer` 展示配置，避免长文本导致异常退出。
- [x] 修复 `menu_height` / `list_height` 与动态尺寸 helper 内部变量同名导致的未绑定变量问题。

## CLI

- [x] `list-projects` 可在未选择当前项目时正常运行。
- [x] `install [project]` 支持显式项目；未传项目时使用当前项目。
- [x] `config [project]` 支持显式项目；未传项目时使用当前项目。
- [x] 需要项目上下文的命令会使用 `require_project_key` 校验。
- [x] 已移除 `update-mode`。
- [x] 已移除 `check-install`。
- [x] 已移除 `download-only`。
- [x] 已添加 `install-launcher` 和 `uninstall-launcher`。
- [x] 已添加 `install-launcher --yes` 非交互安装入口。
- [x] 已添加 `uninstall [project]`。
- [x] 已添加 `show-log [lines]`。
- [x] CLI 帮助文本已与当前命令保持一致。
- [x] `set-main AUTO_UPDATE_ENABLED 0/1` 可关闭或开启启动时自动更新。
- [x] `set-main SHOW_WELCOME_SCREEN 0/1` 可关闭或开启 TUI 启动欢迎页。
- [x] `set-main LOG_LEVEL DEBUG|INFO|WARN|ERROR` 可修改日志等级。
- [x] `set-main PROXY_MODE auto|manual|off` 可修改启动器代理模式。
- [x] `set-main MANUAL_PROXY <url>` 可修改手动代理地址。

## macOS 兼容

- [x] 入口脚本在 macOS 上检测 Bash 版本。
- [x] 如果 macOS 自带 Bash 版本低于 5，会尝试使用 `/opt/homebrew/bin/bash` 递归运行自身。
- [x] 如果 Homebrew Bash 不存在，会提示用户执行 `brew install bash` 并退出。
- [x] macOS Bash 检测逻辑位于 `set -Eeuo pipefail` 之前，保持 Bash 3.x 可解析。
- [x] `install.sh` 保持 macOS Bash 3.x 可解析，并会先安装 Homebrew/Bash 5/PowerShell。

## 依赖引导安装

- [x] `install.sh` 会先检查命令是否存在，避免重复安装已存在的依赖。
- [x] `install.sh` 会在安装依赖前自动检测系统代理并设置联网环境变量。
- [x] `install.sh` 会将 `pwsh` 或 `powershell` 任一命令视为 PowerShell 已可用。
- [x] macOS 缺少 Homebrew 时，使用 Homebrew 官方安装脚本安装。
- [x] macOS 缺少 PowerShell 时，使用 `brew install powershell` 安装。
- [x] Linux 缺少 PowerShell 时，优先尝试 Microsoft 官方仓库方式，再尝试系统包管理器 fallback。
- [x] Linux 自动安装 PowerShell 失败时，提示用户按 Microsoft Learn 手动安装。
- [x] `install.sh` 会尽量安装 `dialog` 和 `git`，失败时提示可手动安装。
- [x] `install.sh` 最后调用 `installer_launcher.sh install-launcher --yes` 自动安装并注册启动器。

## 文档

- [x] `AGENTS.md` 已记录项目结构、编码风格、实现规则和验证要求。
- [x] `README.md` 已记录项目介绍、环境要求、快速开始、安装命令、TUI/CLI 用法、配置位置、下载策略、管理脚本和卸载方式。
- [x] `README.md` 已补充从 GitHub 获取源码、源码压缩包安装、注册命令和更新启动器的方法。
- [x] `README.md` 已补充通过 `curl -fsSL https://github.com/licyk/sd-webui-all-in-one-launcher/raw/main/install.sh | bash` 远程执行一键安装脚本。
- [x] `README.md` 保留本地源码目录中运行 `bash install.sh` 的方式。
- [x] `README.md` 安装章节中的源码目录已改为 `$HOME/.local/share/sd-webui-all-in-one-launcher`。
- [x] `README.md` 已补充 `install-launcher` 如何创建命令链接、写入 PATH，以及手动注册 PATH 的方法。
- [x] `README.md` 已补充已安装软件卸载和双确认说明。
- [x] `README.md` 已补充自动更新和 dialog 操作说明。
- [x] `README.md` 已补充管理脚本结构化参数配置、额外原始参数和 `-NoPause` 自动追加说明。
- [x] `README.md` 已补充自动更新检查/更新过程会输出状态。
- [x] `todo.md` 已移动到 `docs/todo.md`。
- [x] `docs/architecture.md` 已记录入口脚本、模块职责、配置数据流、TUI 数据流、安装器运行流程和安装检测逻辑。
- [x] `docs/architecture.md` 已补充项目卸载流程和双确认要求。
- [x] `docs/architecture.md` 已补充自动更新和启动欢迎页流程。
- [x] `docs/architecture.md` 已补充日志系统和崩溃捕获流程。
- [x] TUI 帮助文档已随用户可见行为更新。
- [x] `docs/todo.md` 已重新整理为分组状态板。
- [x] TUI 帮助文档已补充启动器自身安装、命令注册和卸载行为。
- [x] TUI 帮助文档已补充自动更新检查/更新过程会输出状态。
- [x] TUI 帮助文档已补充安装器多下载源重试行为。
- [x] TUI 帮助文档已补充日志位置、崩溃记录和 CLI 查看日志方法。
- [x] TUI 帮助文档已补充日志等级设置说明。
- [x] TUI 帮助文档已补充代理模式、手动代理地址和 `off` 模式行为。

## Windows GUI

- [x] 新增 `installer_launcher_gui.ps1`，使用 PowerShell/WPF 实现 Windows 图形界面。
- [x] GUI 版内置 7 个项目的安装器下载源、默认目录、分支、管理脚本和支持参数。
- [x] GUI 版使用 Windows 原生路径保存配置、缓存和日志。
- [x] GUI 主界面包含项目选择、安装状态、动态安装器配置、管理脚本、启动器设置和日志输出。
- [x] GUI 已移除顶部手动“刷新状态”按钮，改为每隔 15 秒自动刷新当前项目安装状态。
- [x] GUI 版运行安装器前展示确认信息，确认后重新下载安装器并执行。
- [x] GUI 版按项目能力动态显示配置项，不显示当前项目不支持的参数。
- [x] GUI 版执行 PowerShell 脚本时优先使用 `pwsh`，找不到时回退到 `powershell`。
- [x] GUI 版执行安装器和管理脚本时打开独立 PowerShell 控制台，并在非零退出时保留窗口提示用户查看输出。
- [x] GUI 版支持 `launch.ps1` 和 `terminal.ps1` 的运行前提示。
- [x] GUI 版支持项目卸载，卸载前使用警告确认和输入 `DELETE <project>` 的最终确认。
- [x] GUI 版支持 `auto` / `manual` / `off` 三种代理模式。
- [x] GUI 版支持按日志等级写入 `%LOCALAPPDATA%\installer-launcher\logs\`。
- [x] GUI 版支持自动检查并尝试更新 `installer_launcher_gui.ps1` 自身。
- [x] 修复 GUI 在 Windows 中选择项目时因字典配置使用属性写入导致的 `CURRENT_PROJECT` 崩溃。
- [x] 修复 GUI 日志中配置路径和日志路径因作用域变量字符串插值不正确显示为空的问题。
- [x] 修复 GUI 自动更新回调中 `$Manual` 闭包变量丢失导致的更新检查错误。
- [x] 强化 GUI 启动阶段异常处理：Loaded 回调、WPF Dispatcher 异常和启动时自动更新失败都会写日志，避免直接崩溃。
- [x] GUI 启动时自动更新改为延迟执行，失败时只写入日志和界面日志，不再用弹窗打断首次渲染。
- [x] 修复 GUI 动态开关配置使用数组索引导致 PowerShell 数组展开后可能报 `Cannot index into a null array` 的问题。
- [x] GUI 错误日志已增强为包含行号、命令和调用栈，便于定位 Windows 端 WPF 事件异常。
- [x] 修复 GUI WPF 事件闭包中 `$script:MainConfig` 作用域指向变化，导致选择项目时报 `Cannot index into a null array` 的问题。
- [x] 修复 GUI 残留 `Report-UiError -Exception` 调用，确保初始化、Dispatcher 和自动更新异常都能按新格式记录。
- [x] GUI 版已记录安装器和管理脚本的最终启动参数摘要，便于定位参数拼接问题。
- [x] GUI 版执行 PowerShell 时不再把目标脚本参数直接拼进 `Start-Process -ArgumentList`，改为提前处理成已引用的参数字符串并写入临时文本文件，由 wrapper 读取后通过 `powershell/pwsh -File <script> <args>` 传入目标脚本，避免空格路径和复杂参数被二次拆分。
- [x] GUI/TUI 在参数传递修复后恢复管理脚本自动追加 `-NoPause`。
- [x] GUI 后台任务传递字符串数组参数时使用一元逗号保护，避免空数组或参数数组被 PowerShell 展开导致形参绑定偏移。
- [x] GUI wrapper 不再在当前会话中用 `& $ScriptPath @ScriptArgs` 调用目标脚本，改为再次通过 `powershell/pwsh -File <script> <args>` 启动，保持与用户直接运行脚本相同的参数入口语义。
- [x] GUI wrapper 启动目标脚本时改用 `Invoke-Expression` 执行完整的 `powershell/pwsh -File` 表达式，并对每个参数做单引号引用，继续排查上游脚本位置参数解析问题。
- [x] GUI 参数文件不再保存 JSON 数组，改为保存已处理的参数字符串，避免 `-NoPause` 被中间层参数绑定吞掉，以及带空格参数丢失引用格式。
- [x] GUI 参数分割和合并已统一改为 `Split-Shlex` / `Join-Shlex`，移除旧的 `PSParser` 分割和自定义合并实现。
- [x] GUI wrapper 中 `Invoke-Expression` 已加入 `try/catch`，启动脚本抛异常时仍会显示错误信息和等待用户确认。
- [x] 修复 GUI 管理脚本完成回调依赖外层 `$scriptName` 导致严格模式下提示变量未设置的问题。
- [x] 修复 GUI 安装分支下拉框保存时读不到分支 key 的问题，改为绑定 `Key/Label` 对象并保存 `SelectedItem.Key`。
- [x] GUI 主界面已重构为项目列表 + 标签页布局，将安装器配置、管理脚本和启动器设置拆分，降低单屏拥挤度。
- [x] GUI 已将安装路径独立为单独标签页，用于集中配置安装目录和查看路径说明。
- [x] GUI 已将“卸载已安装软件”从启动器设置页移动到“安装路径”标签页，和目标安装目录放在一起。
- [x] GUI 主界面继续重构为参考图风格的应用壳：顶部标题栏、左侧项目导航、大横幅状态区、主内容页和底部运行日志。
- [x] GUI 动态安装器配置项已改成参考图风格的设置行卡片，左侧说明、右侧控件，减少表单堆叠感。
- [x] GUI 启动器设置入口已移动到左下角，检查更新移动到启动器设置页内部。
- [x] GUI 启动器设置已拆成整页视图，左下角进入设置后可通过“返回主页”回到主界面。
- [x] GUI 检测到当前项目已安装时会优先切换到管理脚本页，并在横幅状态中提示运行 `launch.ps1` 启动或运行维护脚本。
- [x] GUI 安装路径输入支持通过文件夹选择器选择目录。
- [x] GUI 主窗口已接入 Windows blur/acrylic 风格毛玻璃效果，并保留暗色模式和圆角窗口设置。
- [x] GUI 输入框、下拉框、复选框、列表项、标签页和按钮已改为自定义 WPF 模板，避免使用默认原生控件外观。
- [x] GUI 已重构为 WPFUI 风格左侧功能导航，包含“一键启动 / 高级选项 / 软件选择 / 设置”四个方形入口，并按当前页面高亮。
- [x] GUI “一键启动”页支持在安装模式和启动模式之间切换；启动模式会列出可运行的管理脚本，并通过右下角统一启动按钮执行。
- [x] GUI “高级选项”页集中管理安装路径、安装器参数和管理脚本参数；“软件选择”页承载原项目选择列表；“设置”页新增打开配置文件夹按钮。
- [x] GUI 脚本中的智能引号已替换为 `「」`，避免 PowerShell 将 `“”` 当作字符串定界符导致解析失败。
- [x] GUI “一键启动”的模式选择已从下拉框改为标签页，并会在安装状态变化时自动切到安装模式或启动模式。
- [x] GUI 一键启动页已修复管理脚本列表显示对象类型名的问题，横幅文字和日志区域尺寸也已收紧以避免遮挡。
- [x] GUI 左侧功能栏已改为图标在上、文字在下的按钮布局；当前选中页会隐藏文字，仅保留高亮图标。
- [x] GUI 管理脚本设置下拉框已改用带 `ToString()` 的 `LauncherChoice` 数据对象和 `DisplayMemberPath`，避免选中区显示 `@{Name=...; Label=...}` 或控件类型名。
- [x] GUI 高级选项和启动器设置中的复选框已改为滑动开关样式，输入框已改为扁平浅底并在聚焦时显示蓝色强调线。
- [x] GUI 高级选项页已移除重复的局部“运行安装器”“保存脚本参数”“运行脚本”按钮；右上角“保存配置”会同时保存安装器配置和当前管理脚本参数。
- [x] `README.md` 已补充日志位置、崩溃记录、脱敏策略和 `show-log` 命令。
- [x] `README.md` 已补充日志等级设置方法。
- [x] `README.md` 已润色项目定位，突出可通过启动器安装和管理多个 AI WebUI / 训练工具。
- [x] `AGENTS.md` 已补充日志规则和敏感信息脱敏要求。
- [x] `AGENTS.md` 已补充 `install.sh` 需兼容 macOS Bash 3.x 的约定。
- [x] TUI 欢迎页和帮助文档已润色，突出“选择 WebUI / 工具并完成安装、启动、更新和维护”的使用方式。
- [x] `docs/architecture.md` 已同步项目定位描述。
- [x] `README.md` 已补充 Windows GUI 启动方式、功能说明、配置路径和与 Bash 版的差异。
- [x] `docs/architecture.md` 已补充 Windows GUI 入口、数据路径和运行流程。
- [x] `AGENTS.md` 已补充 Windows GUI 维护规则。

## 验证记录

- [x] 多次运行 `bash -n installer_launcher.sh lib/*.sh`，通过。
- [x] 多次运行 `shellcheck installer_launcher.sh lib/*.sh`，通过。
- [x] 运行 `bash -n install.sh installer_launcher.sh lib/*.sh`，通过。
- [x] 运行 `shellcheck install.sh installer_launcher.sh lib/*.sh`，通过。
- [x] 新增 Windows GUI 后再次运行 `bash -n install.sh installer_launcher.sh lib/*.sh`，通过。
- [x] 新增 Windows GUI 后再次运行 `shellcheck install.sh installer_launcher.sh lib/*.sh`，通过。
- [x] 当前 Linux 环境未安装 `pwsh` / `powershell`，无法在本机解析或启动 WPF GUI，Windows 验证待补跑。
- [x] 验证 `install.sh` dry-run 在 `pwsh/dialog/git` 已存在时会跳过依赖安装并调用 `install-launcher --yes`。
- [x] 验证只有 `powershell` mock、没有 `pwsh` 时，运行器会回退到 `powershell`。
- [x] 验证 `install.sh` dry-run 在仅存在 `powershell` 时会视为 PowerShell 已安装。
- [x] 验证自动代理不会覆盖已有 `HTTP_PROXY`。
- [x] 验证手动代理模式会设置 `HTTP_PROXY` 和 `HTTPS_PROXY`。
- [x] 验证手动代理模式在代理地址为空时会清理已有代理环境变量。
- [x] 验证关闭代理模式会清理当前启动器进程中的代理环境变量。
- [x] 验证 `set-main PROXY_MODE manual` 和 `set-main MANUAL_PROXY <url>` 可正确写入主配置。
- [x] 验证 GNOME 系统代理读取可生成 `http://host:port` 地址。
- [x] 验证 `install.sh` dry-run 在已有代理环境变量时会跳过系统代理检测。
- [x] 验证 CLI 帮助中包含 `install-launcher --yes` 示例。
- [x] 验证 `list-projects` 可列出全部 7 个安装器。
- [x] 验证空配置下直接运行需要项目上下文的命令会提示先选择安装器。
- [x] 验证 `set-main CURRENT_PROJECT comfyui` 后可正常显示项目配置。
- [x] 验证 `set-main CURRENT_PROJECT null` / `NULL` 可清空当前项目。
- [x] 验证安装器参数默认包含 `-InstallPath <有效路径>` 和自动追加的 `-NoPause`。
- [x] 验证取消安装确认后不会下载，也不会执行 PowerShell。
- [x] 验证未安装、安装不完整、已安装三种主界面状态提示。
- [x] 验证 `text_viewer`、动态尺寸 helper、菜单尺寸计算在 `bash -u` 下不触发未绑定变量。
- [x] 验证新增 `install-launcher` / `uninstall-launcher` 已出现在 CLI 帮助中。
- [x] 验证 `lib/self_manage.sh` 可在 `bash -u` 下随 `lib/bootstrap.sh` 正常加载并解析安装路径。
- [x] 验证版本比较函数可在 `bash -u` 下判断 `0.3.1 > 0.3.0`。
- [x] 验证 `set-main AUTO_UPDATE_ENABLED 0` 可关闭自动更新，并且普通 CLI 命令不再触发启动更新检查。
- [x] 验证 `set-main SHOW_WELCOME_SCREEN 0` 可保存欢迎页开关。
- [x] 验证 `set-main LOG_LEVEL INFO` 可保存日志等级。
- [x] 验证 `LOG_LEVEL=INFO/WARN` 会按最低等级过滤日志，非法等级会被拒绝。
- [x] 验证卸载路径保护会拒绝根目录、HOME 目录和相对路径。
- [x] 验证项目卸载最终确认输入错误时不会删除安装目录。
- [x] 验证项目卸载最终确认输入正确时会删除安装目录。
- [x] 验证 `--help` 启动后会生成当天日志文件。
- [x] 验证 `show-log 20` 可输出日志路径和最近日志内容。
- [x] 验证 `list-projects` 会记录启动和命令分发日志。
- [x] 验证自动更新检查会向 stderr 输出检查状态和最新版本状态，不影响命令 stdout。
- [x] 验证下载失败时会记录下载 URL 和失败状态。
- [x] 验证 `ERR` trap 会记录退出码、失败命令、行号和调用栈。
- [x] 验证 bootstrap 前找不到模块时会写入 early log，并对 token 类参数脱敏。
- [x] 验证代理配置和 token/password 类参数在日志中已脱敏。
- [x] 验证 PowerShell 非零退出提示会显示脚本路径、退出代码，并等待 Enter 后返回。
- [ ] 在 Windows PowerShell 5.1 中运行 `installer_launcher_gui.ps1`，验证 WPF 界面可正常启动。
- [ ] 在 Windows 中验证 GUI 首次启动会创建 AppData / LocalAppData 配置、缓存和日志目录。
- [ ] 在 Windows 中验证 GUI 安装器下载重试、PowerShell 执行、安装检测、管理脚本运行和项目卸载流程。

## 待办

- [ ] 暂无明确待办；后续需求进入此区域并按完成情况移动到对应分组。
