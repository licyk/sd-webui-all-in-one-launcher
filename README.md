# sd-webui-all-in-one-launcher

一个用于安装、启动和维护多个 AI WebUI / 训练工具的 Bash TUI/CLI 启动器。

它基于 `sd-webui-all-in-one` 系列 PowerShell 安装器工作：用户只需要选择要安装的 WebUI 类型，设置安装路径、分支、镜像或代理等参数，启动器会重新下载最新安装器脚本并执行安装。安装完成后，也可以继续通过它运行项目生成的启动、更新、终端、模型下载等管理脚本。

## 功能

- 支持 TUI 和 CLI 两种使用方式。
- 可通过同一套界面安装和管理多个 WebUI / 工具：
  - Stable Diffusion WebUI
  - ComfyUI
  - InvokeAI
  - Fooocus
  - SD Trainer
  - SD Trainer Script
  - Qwen TTS WebUI
- 适合把“安装 WebUI、配置安装参数、运行启动脚本、后续更新维护”放在一个入口中完成。
- 每次运行安装器都会重新下载 PowerShell 脚本，尽量保证使用最新版本。
- 每个安装器内置多个下载源，会按顺序重试；任意一个下载成功就继续执行。
- 按项目能力动态显示和传递参数，不支持的参数不会出现在界面中。
- 自动传入 `-InstallPath`，未设置时使用 `$HOME/<项目默认目录>`。
- 支持安装后管理脚本运行，例如 `launch.ps1`、`update.ps1`、`terminal.ps1`。
- 支持卸载各项目已安装软件，卸载前需要警告确认和输入指定文本的最终确认。
- 支持安装/更新启动器自身，并注册 `installer-launcher` 命令。
- 默认启动时自动检查启动器更新，检测到新版本会自动尝试更新。
- TUI 启动时显示欢迎页，包含版本、更新状态和 dialog 操作提示。
- 支持卸载启动器自身，同时清理命令注册、配置和缓存。

## 环境要求

- Bash 5 或更高版本。
- PowerShell：需要 `pwsh` 命令，用于执行上游安装器和管理脚本。
- 下载工具：`curl` 或 `wget`。
- 可选：`dialog`，用于 TUI 图形化终端界面。没有 `dialog` 时会退回到文本交互。
- 可选：`git`，用于安装/更新启动器自身。没有 `git` 时会尝试使用源码压缩包。

### macOS

macOS 自带 Bash 版本通常较低。脚本在 macOS 上会检测 Bash 版本：

- 如果当前 Bash 版本低于 5，会尝试使用 `/opt/homebrew/bin/bash` 重新运行自身。
- 如果该路径不存在，会提示先安装 Homebrew Bash。

```bash
brew install bash
```

## 安装

推荐使用一键安装脚本。它会先检查并尝试安装 Homebrew、PowerShell、dialog、git 等依赖，然后自动安装并注册 `installer-launcher` 命令。

```bash
curl -fsSL https://github.com/licyk/sd-webui-all-in-one-launcher/raw/main/install.sh | bash
```

如果自动安装 PowerShell 失败，请根据终端提示按 Microsoft Learn 官方文档手动安装后重试。

如果已经下载了源码，也可以在仓库目录中运行本地脚本：

```bash
bash install.sh
```

### 手动安装

推荐使用 `git` 获取启动器源码：

```bash
git clone https://github.com/licyk/sd-webui-all-in-one-launcher.git \
  "$HOME/.local/share/sd-webui-all-in-one-launcher"
cd "$HOME/.local/share/sd-webui-all-in-one-launcher"
chmod +x installer_launcher.sh
```

如果没有 `git`，也可以下载源码压缩包：

```bash
curl -L -o "$HOME/.local/share/sd-webui-all-in-one-launcher.tar.gz" \
  https://github.com/licyk/sd-webui-all-in-one-launcher/archive/refs/heads/main.tar.gz
mkdir -p "$HOME/.local/share/sd-webui-all-in-one-launcher"
tar -xzf "$HOME/.local/share/sd-webui-all-in-one-launcher.tar.gz" \
  --strip-components=1 -C "$HOME/.local/share/sd-webui-all-in-one-launcher"
cd "$HOME/.local/share/sd-webui-all-in-one-launcher"
chmod +x installer_launcher.sh
```

安装依赖后，可以先从源码目录直接启动：

```bash
./installer_launcher.sh tui
```

确认可用后，建议将启动器安装到用户目录并注册 `installer-launcher` 命令：

```bash
./installer_launcher.sh install-launcher
```

如果需要跳过确认提示，可使用：

```bash
./installer_launcher.sh install-launcher --yes
```

这个命令会做三件事：

1. 将启动器安装到用户数据目录。
2. 创建命令链接 `$HOME/.local/bin/installer-launcher`。
3. 根据当前 shell，将 `$HOME/.local/bin` 写入 shell 配置文件中的 PATH 注册块。

默认安装位置：

```text
${XDG_DATA_HOME:-$HOME/.local/share}/installer-launcher
```

注册的命令位置：

```text
$HOME/.local/bin/installer-launcher
```

自动写入的 shell 配置文件通常是：

```text
bash: $HOME/.bashrc
zsh:  $HOME/.zshrc
其他: $HOME/.profile
```

安装后重新打开终端，或执行脚本提示的 `source <shell rc file>` 命令，然后可以直接运行：

```bash
installer-launcher tui
```

如果命令注册没有生效，可以手动把下面内容加入当前 shell 的配置文件：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

然后重新打开终端，或执行：

```bash
source ~/.bashrc
```

如果使用 zsh，则执行：

```bash
source ~/.zshrc
```

更新启动器也使用同一个命令：

```bash
installer-launcher install-launcher
```

## 快速开始

首次使用建议按下面流程安装一个 WebUI：

1. 进入 `选择不同类型的安装器`，选择要安装的 WebUI 或工具。
2. 进入 `当前安装器配置`，检查安装路径、分支、镜像、代理等安装参数。
3. 返回主界面，选择 `下载安装器并运行`。
4. 安装完成后，使用 `运行安装后生成的管理脚本` 启动 WebUI、更新项目、进入终端环境或执行其他维护操作。

## 自动更新

启动器默认启用自动检查更新。

- 检查间隔为 60 分钟。
- 检查时会读取远程仓库 `lib/core.sh` 中的 `APP_VERSION`。
- 如果远程版本高于本地版本，会自动尝试安装新版启动器。
- 如果检查或更新失败，会提示用户，但不会阻止当前启动器继续运行。
- 检查和更新过程中会在终端输出简短状态，例如正在检查、已是最新版本、发现新版本或更新失败。

关闭自动更新：

```bash
./installer_launcher.sh set-main AUTO_UPDATE_ENABLED 0
```

重新开启自动更新：

```bash
./installer_launcher.sh set-main AUTO_UPDATE_ENABLED 1
```

## TUI 使用

启动 TUI：

```bash
./installer_launcher.sh tui
```

如果已经注册命令：

```bash
installer-launcher tui
```

进入 TUI 时默认会显示欢迎页，包含当前版本、自动更新状态和 dialog 操作方式。

关闭欢迎页：

```bash
./installer_launcher.sh set-main SHOW_WELCOME_SCREEN 0
```

重新开启欢迎页：

```bash
./installer_launcher.sh set-main SHOW_WELCOME_SCREEN 1
```

dialog 常用操作：

- 方向键：移动菜单项或滚动文本。
- `Tab`：在按钮之间切换。
- `Enter`：确认当前选择。
- `Space`：切换复选框。
- `Esc`：返回或取消当前窗口。
- 文本页面可使用方向键、`PageUp`、`PageDown` 滚动。

主界面顶部会自动检测当前项目安装状态：

- `未选择`：还没有选择要安装或管理的 WebUI / 工具。
- `未安装`：安装路径不存在，可以先调整配置再运行安装器。
- `安装目录存在，但缺少管理脚本`：目录存在但不像完整安装结果，建议重新运行安装器。
- `已安装`：找到了管理脚本，可以运行启动、更新、终端或维护操作。

主菜单常用入口：

- `选择不同类型的安装器`：选择要安装或管理的 WebUI / 工具类型。
- `下载安装器并运行`：重新下载安装器并执行 WebUI / 工具安装。
- `卸载当前已安装软件`：删除当前项目安装目录，需要双确认。
- `运行安装后生成的管理脚本`：执行安装目录中的启动、更新、终端等管理脚本。
- `调整子脚本默认启动参数`：给 `launch.ps1` 等脚本保存默认参数。
- `当前安装器配置`：配置安装路径、分支、镜像、代理、开关参数等。
- `启动器主配置`：设置当前项目、自动更新和欢迎页显示。
- `查看当前配置`：查看主配置和项目配置。
- `TUI 使用帮助`：查看更详细的界面说明。

## CLI 使用

查看帮助：

```bash
./installer_launcher.sh --help
```

列出支持的项目：

```bash
./installer_launcher.sh list-projects
```

设置当前项目：

```bash
./installer_launcher.sh set-main CURRENT_PROJECT comfyui
```

清空当前项目：

```bash
./installer_launcher.sh set-main CURRENT_PROJECT null
```

运行安装器：

```bash
./installer_launcher.sh install comfyui
```

卸载已安装软件：

```bash
./installer_launcher.sh uninstall comfyui
```

卸载会先显示警告确认，再要求输入提示中的确认文本。未传项目时会使用当前项目。

未传项目时会使用当前项目：

```bash
./installer_launcher.sh install
```

查看配置：

```bash
./installer_launcher.sh config comfyui
```

设置项目安装路径：

```bash
./installer_launcher.sh set-project comfyui INSTALL_PATH /data/ComfyUI
```

设置安装分支：

```bash
./installer_launcher.sh set-project fooocus INSTALL_BRANCH fooocus_mre_main
```

给管理脚本保存默认参数：

```bash
./installer_launcher.sh set-script-args comfyui launch.ps1 "--listen 0.0.0.0 --port 8188"
```

运行管理脚本：

```bash
./installer_launcher.sh run-script launch.ps1
```

查看当前日志：

```bash
./installer_launcher.sh show-log 120
```

## 配置位置

主配置：

```text
${XDG_CONFIG_HOME:-$HOME/.config}/installer-launcher/main.conf
```

项目配置：

```text
${XDG_CONFIG_HOME:-$HOME/.config}/installer-launcher/projects/<project>.conf
```

安装器缓存：

```text
${XDG_CACHE_HOME:-$HOME/.cache}/installer-launcher/installers/<project>/
```

日志目录：

```text
${XDG_STATE_HOME:-$HOME/.local/state}/installer-launcher/logs/
```

## 日志与崩溃记录

启动器会记录运行日志，默认级别为 `DEBUG`，不会自动删除旧日志。日志按日期写入：

```text
installer-launcher-YYYYMMDD.log
```

日志会记录启动参数、配置加载与修改、自动更新检查、安装器下载源尝试、PowerShell 脚本执行、管理脚本运行、项目卸载和启动器卸载等关键操作。

日志等级表示最低写入级别，可选 `DEBUG`、`INFO`、`WARN`、`ERROR`。例如设置为 `WARN` 时，只写入警告和错误。

修改日志等级：

```bash
./installer_launcher.sh set-main LOG_LEVEL INFO
```

当脚本因为未处理错误异常退出时，会通过 `ERR` trap 写入崩溃记录，包括退出码、失败命令、行号、调用栈和当前命令参数。这样可以帮助定位“没有任何输出就退出”的问题。

查看最近日志：

```bash
./installer_launcher.sh show-log
./installer_launcher.sh show-log 200
```

日志会保留安装路径、项目名和脚本名，方便排查；代理地址、镜像地址、额外参数中的 token、password、key 等敏感内容会做脱敏处理。

## 安装器下载策略

运行安装器时，启动器会：

1. 根据当前项目构建 PowerShell 参数。
2. 显示确认页，包含安装路径、下载源列表和参数。
3. 用户确认后，按下载源顺序下载 PowerShell 安装器。
4. 任意一个下载源成功后，保存到缓存目录并执行。
5. 如果所有下载源都失败，打印已尝试的地址并返回错误。

下载时不会使用进度条，只输出普通文本日志。

如果 PowerShell 安装器返回非零退出代码，启动器会停留在当前终端，提示脚本异常退出并要求先查看上方 PowerShell 输出日志。按 Enter 后才会返回 TUI，避免错误日志被界面覆盖。

## 管理脚本说明

安装完成后，各项目会在安装目录中生成管理脚本。启动器只从有效安装路径中查找这些脚本。

常见脚本：

- `launch.ps1`：启动项目。运行前会显示确认提示；确认后继续执行，运行期间可按 `Ctrl+C` 终止。
- `update.ps1`：更新项目。
- `terminal.ps1`：打开项目交互终端。运行前会显示确认提示；确认后可在已激活的项目环境中运行命令，退出时输入 `exit` 并回车。
- `settings.ps1`：管理项目设置。
- `download_models.ps1`：下载模型。
- `reinstall_pytorch.ps1`：重装 PyTorch。

`activate.ps1` 不会在启动器中单独显示，因为 `terminal.ps1` 会自动处理环境激活。

如果管理脚本返回非零退出代码，启动器同样会停留在当前终端，等待用户查看 PowerShell 输出后按 Enter 返回。

## 卸载启动器

卸载启动器自身：

```bash
./installer_launcher.sh uninstall-launcher
```

卸载会删除：

- 启动器安装目录。
- `$HOME/.local/bin/installer-launcher` 命令链接。
- shell 配置文件中的 PATH 注册块。
- 启动器配置目录。
- 启动器缓存目录。

卸载启动器同样需要两步确认：先确认警告，再输入提示中的确认文本。

卸载不会删除 Stable Diffusion WebUI、ComfyUI 等项目本体安装目录。

## 开发与检查

修改脚本后建议运行：

```bash
bash -n install.sh installer_launcher.sh lib/*.sh
shellcheck install.sh installer_launcher.sh lib/*.sh
```

基础 smoke test：

```bash
./installer_launcher.sh --help
./installer_launcher.sh list-projects
```

项目协作和编码规则见 [AGENTS.md](AGENTS.md)。

## 项目文档

- [架构文档](docs/architecture.md)
- [TODO 状态板](docs/todo.md)
