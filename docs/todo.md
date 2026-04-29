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
- [x] 支持 `show-log [lines]` 查看当前日志路径和最近日志内容。
- [x] 支持卸载启动器自身，卸载时移除命令注册、配置目录和缓存目录。
- [x] `AGENTS.md` 已创建，用于记录项目约定、编码风格和验证规则。
- [x] `README.md` 已创建，用于面向用户说明安装、TUI/CLI 使用、配置、下载策略和卸载。
- [x] `docs/` 已创建，维护类文档已迁移到该目录。
- [x] `docs/architecture.md` 已创建，用于说明项目架构、模块职责和主要流程。
- [x] 本文件已整理为分组状态板，避免继续堆叠流水账。

## 项目结构

- [x] `lib/core.sh`：应用常量、通用工具、日志系统、崩溃捕获、项目键校验。
- [x] `lib/projects.sh`：项目注册表、安装器 URL 列表、支持参数、管理脚本列表。
- [x] `lib/config.sh`：主配置和项目配置的创建、加载、保存、展示。
- [x] `lib/ui.sh`：dialog/text UI 适配、动态尺寸、确认框、文本查看器。
- [x] `lib/runner.sh`：下载、参数构建、PowerShell 执行、安装检测、管理脚本运行、项目安装目录卸载。
- [x] `lib/self_manage.sh`：启动器自身安装、命令注册、卸载和 shell 配置清理。
- [x] `lib/menus.sh`：TUI 菜单、配置交互、主界面状态、帮助页面。
- [x] `lib/cli.sh`：CLI 命令分发和帮助文本。
- [x] `lib/bootstrap.sh`：统一加载模块。

## 配置与项目选择

- [x] 主配置包含 `CURRENT_PROJECT`、`AUTO_UPDATE_ENABLED`、`SHOW_WELCOME_SCREEN`、`LOG_LEVEL`、`AUTO_UPDATE_LAST_CHECK`。
- [x] `CURRENT_PROJECT` 默认为空，不再隐式回填 `sd_webui`。
- [x] `AUTO_UPDATE_ENABLED` 默认为 `1`。
- [x] `SHOW_WELCOME_SCREEN` 默认为 `1`。
- [x] `LOG_LEVEL` 默认为 `DEBUG`，可设置为 `DEBUG`、`INFO`、`WARN`、`ERROR`。
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
- [x] `NoPause` 不再作为用户配置项；项目支持时自动追加 `-NoPause`。
- [x] 运行安装器时显式传入 `-InstallPath`，未配置时使用 `$HOME/<项目默认目录>`。
- [x] `EXTRA_INSTALL_ARGS` 会追加到结构化安装器参数之后。
- [x] 运行安装器前展示确认信息，包括项目、安装器下载源列表、缓存路径、安装路径、PowerShell 参数和当前项目配置。
- [x] 用户取消确认时不会下载，也不会执行 PowerShell。
- [x] PowerShell 安装器返回非零退出代码时，会停留在当前终端提示用户查看输出日志，按 Enter 后再返回 TUI。

## 下载与缓存

- [x] 安装器下载位置为 `${XDG_CACHE_HOME:-$HOME/.cache}/installer-launcher/installers/<project>/`。
- [x] 运行安装器前每次重新下载。
- [x] 每个安装器配置 5 个下载源：GitHub Release、Gitee Release、GitHub raw、Gitee raw、GitLab raw。
- [x] 下载安装器时按下载源顺序重试，只要一个源下载成功就执行安装器。
- [x] 所有下载源都失败时返回错误，并打印已尝试的下载地址。
- [x] 已移除“仅下载安装器”功能。
- [x] 下载阶段使用普通文本提示，不再使用 dialog 进度条。

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
- [x] `terminal.ps1` 会自动处理环境激活，因此已移除 `activate.ps1` 入口。
- [x] 已从管理脚本入口中移除 `init.ps1` 和 `tensorboard.ps1`。
- [x] 运行 `launch.ps1` 前显示确认提示，说明确认后继续执行且可按 `Ctrl+C` 终止。
- [x] 运行 `terminal.ps1` 前显示确认提示，说明确认后打开交互终端，输入 `exit` 并回车退出。
- [x] `terminal.ps1` 的界面说明已改为打开交互终端，可在已激活的项目环境中执行命令。
- [x] 管理脚本返回非零退出代码时，会停留在当前终端提示用户查看 PowerShell 输出日志，按 Enter 后再返回 TUI。
- [x] 子脚本默认参数可按项目配置保存。

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

## macOS 兼容

- [x] 入口脚本在 macOS 上检测 Bash 版本。
- [x] 如果 macOS 自带 Bash 版本低于 5，会尝试使用 `/opt/homebrew/bin/bash` 递归运行自身。
- [x] 如果 Homebrew Bash 不存在，会提示用户执行 `brew install bash` 并退出。
- [x] macOS Bash 检测逻辑位于 `set -Eeuo pipefail` 之前，保持 Bash 3.x 可解析。
- [x] `install.sh` 保持 macOS Bash 3.x 可解析，并会先安装 Homebrew/Bash 5/PowerShell。

## 依赖引导安装

- [x] `install.sh` 会先检查命令是否存在，避免重复安装已存在的依赖。
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
- [x] `README.md` 已补充日志位置、崩溃记录、脱敏策略和 `show-log` 命令。
- [x] `README.md` 已补充日志等级设置方法。
- [x] `README.md` 已润色项目定位，突出可通过启动器安装和管理多个 AI WebUI / 训练工具。
- [x] `AGENTS.md` 已补充日志规则和敏感信息脱敏要求。
- [x] `AGENTS.md` 已补充 `install.sh` 需兼容 macOS Bash 3.x 的约定。
- [x] TUI 欢迎页和帮助文档已润色，突出“选择 WebUI / 工具并完成安装、启动、更新和维护”的使用方式。
- [x] `docs/architecture.md` 已同步项目定位描述。

## 验证记录

- [x] 多次运行 `bash -n installer_launcher.sh lib/*.sh`，通过。
- [x] 多次运行 `shellcheck installer_launcher.sh lib/*.sh`，通过。
- [x] 运行 `bash -n install.sh installer_launcher.sh lib/*.sh`，通过。
- [x] 运行 `shellcheck install.sh installer_launcher.sh lib/*.sh`，通过。
- [x] 验证 `install.sh` dry-run 在 `pwsh/dialog/git` 已存在时会跳过依赖安装并调用 `install-launcher --yes`。
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

## 待办

- [ ] 暂无明确待办；后续需求进入此区域并按完成情况移动到对应分组。
