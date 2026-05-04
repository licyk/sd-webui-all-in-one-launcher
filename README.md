# SD WebUI All In One Launcher

一个用于安装、启动和维护多个 AI WebUI / 训练工具的启动器。它基于 `sd-webui-all-in-one` 系列 PowerShell 安装器工作：选择软件类型，设置安装路径和参数，启动器会重新下载最新安装器脚本并执行。安装完成后，也可以继续运行 `launch.ps1`、`update.ps1`、`terminal.ps1` 等管理脚本。

## 目录

- [支持的软件](#支持的软件)
- [选择入口](#选择入口)
- [Windows GUI 快速安装](#windows-gui-快速安装)
- [Linux / macOS TUI 和 CLI 安装](#linux--macos-tui-和-cli-安装)
- [首次使用流程](#首次使用流程)
- [TUI 使用](#tui-使用)
- [CLI 使用](#cli-使用)
- [配置、日志和代理](#配置日志和代理)
- [安装器和管理脚本](#安装器和管理脚本)
- [更新与卸载](#更新与卸载)
- [开发与项目文档](#开发与项目文档)

## 支持的软件

- Stable Diffusion WebUI
- ComfyUI
- InvokeAI
- Fooocus
- SD Trainer
- SD Trainer Script
- Qwen TTS WebUI

主要能力：

- 同一入口安装和管理多个 WebUI / 工具。
- 每次运行安装器前重新下载安装到缓存目录。
- 多下载源按顺序重试，任意一个下载成功即可继续。
- 按项目能力动态显示和传递参数。
- 自动传入 `-InstallPath`，未设置时使用项目默认目录。
- 安装后运行启动、更新、终端、模型下载等管理脚本。
- 支持项目卸载、启动器自更新、日志记录和代理配置。

## 选择入口

| 使用场景 | 推荐入口 |
| --- | --- |
| Windows 用户，想用图形界面 | Windows GUI |
| Linux / macOS / 终端用户 | Bash TUI |
| 脚本化或自动化 | Bash CLI |
| 临时试用 Windows GUI | Release 单文件 `installer_launcher_gui.ps1` |

### Windows GUI 要求

- Windows PowerShell 5.1 或 PowerShell 7+。
- Windows WPF / .NET 桌面环境。
- `pwsh` 或 `powershell`，用于执行上游安装器和管理脚本。

### Bash TUI/CLI 要求

- Bash 5 或更高版本。
- `pwsh` 或 `powershell`，用于执行上游 PowerShell 脚本。
- `curl` 或 `wget`。
- 可选：`dialog`，用于 TUI 终端界面；没有时回退文本交互。
- 可选：`git`，用于安装或更新启动器源码；没有时会尝试源码压缩包。

macOS 自带 Bash 通常低于 5。启动器会尝试使用 `/opt/homebrew/bin/bash` 重新运行自身；如果不存在，请先安装 Homebrew Bash：

```bash
brew install bash
```

## Windows GUI 快速安装

推荐下载 `install.bat` 后双击运行。它会启动图形安装器，从 Release 获取编译后的单文件 GUI 脚本和图标，并创建桌面 / 开始菜单快捷方式：

| 下载源 | 下载 |
| --- | --- |
| GitHub Release | [![下载 install.bat](https://img.shields.io/badge/下载-install.bat-0078D4?style=for-the-badge&logo=github&logoColor=white)](https://github.com/licyk/sd-webui-all-in-one-launcher/releases/download/launcher/install.bat) |
| Gitee Release | [![下载 install.bat](https://img.shields.io/badge/下载-install.bat-C71D23?style=for-the-badge&logo=gitee&logoColor=white)](https://gitee.com/licyk/sd-webui-all-in-one-launcher/releases/download/launcher/install.bat) |

安装完成后：

- GUI 脚本位置：`%APPDATA%\installer-launcher\installer_launcher_gui.ps1`
- 可以从桌面或开始菜单启动。
- 会注册当前用户级卸载项，可在系统“应用和功能”中卸载。

### 从源码运行安装脚本

如果已经下载本仓库源码，也可以运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

纯命令行安装：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -NoGui
```

安装脚本默认自动读取 Windows 系统代理；也可以临时指定代理：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -ProxyMode manual -ManualProxy http://127.0.0.1:7890
```

关闭安装脚本代理：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -ProxyMode off
```

`install.ps1` 不读取 GUI 配置文件；它只为当前安装进程临时配置代理。

### 直接运行 GUI 单文件

如果不想安装，可以下载 Release 中的 `installer_launcher_gui.ps1` 后直接运行：

| 下载源 | 下载 |
| --- | --- |
| GitHub Release | [![下载 installer_launcher_gui.ps1](https://img.shields.io/badge/下载-installer__launcher__gui.ps1-0078D4?style=for-the-badge&logo=github&logoColor=white)](https://github.com/licyk/sd-webui-all-in-one-launcher/releases/download/launcher/installer_launcher_gui.ps1) |
| Gitee Release | [![下载 installer_launcher_gui.ps1](https://img.shields.io/badge/下载-installer__launcher__gui.ps1-C71D23?style=for-the-badge&logo=gitee&logoColor=white)](https://gitee.com/licyk/sd-webui-all-in-one-launcher/releases/download/launcher/installer_launcher_gui.ps1) |

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\installer_launcher_gui.ps1
```

注意：仓库根目录的 `installer_launcher_gui.ps1` 是源码开发入口，需要配合 `gui/` 目录运行；普通用户应使用 Release 中的单文件产物。

## Linux / macOS TUI 和 CLI 安装

推荐使用一键安装脚本。它会检查依赖并注册 `installer-launcher` 命令。

```bash
curl -fsSL https://github.com/licyk/sd-webui-all-in-one-launcher/raw/main/install.sh | bash
```

如果已经下载源码，也可以在仓库目录运行：

```bash
bash install.sh
```

### 手动安装源码

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

## 首次使用流程

### Windows GUI

1. 首次启动时阅读并同意用户协议。
2. 进入左侧“软件选择”，选择要安装或管理的 WebUI / 工具。
3. 进入“高级选项”，确认安装路径、安装器参数和管理脚本参数。
4. 如果系统中已经有安装好的 WebUI，可以在“安装路径”区域搜索并选择现有路径。
5. 回到“一键启动”。未安装时运行安装器，已安装后运行管理脚本。
6. 安装器会在独立 PowerShell 控制台中执行。
7. 安装完成后，在启动模式选择 `launch.ps1` 启动 WebUI。
8. 后续维护可运行 `update.ps1`、`terminal.ps1`、`version_manager.ps1` 等脚本。

`launch.ps1` 运行期间可在控制台按 `Ctrl+C` 终止服务。`terminal.ps1` 打开交互终端后，输入 `exit` 并回车退出。GUI 中的“终止当前任务”只终止当前启动器创建的 PowerShell 进程树。

GUI 会定时自动刷新安装状态；安装完成、目录移动或卸载后无需手动点击刷新按钮。

### Bash TUI

1. 进入“选择不同类型的安装器”，选择要安装或管理的 WebUI / 工具。
2. 进入“当前安装器配置”，检查安装路径、分支、镜像、代理等参数。
3. 返回主界面，运行“下载安装器并运行”。
4. 安装完成后，使用“运行安装后生成的管理脚本”启动或维护项目。

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
- `启动器主配置`：设置当前项目、自动更新、欢迎页、日志等级和代理模式。
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

卸载会先显示警告确认，再要求输入提示中的确认文本。

未传项目时，多数项目命令会使用当前项目。例如运行当前项目安装器：

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

给管理脚本保存结构化参数：

```bash
./installer_launcher.sh set-script-param comfyui launch.ps1 LaunchArg "--listen 0.0.0.0 --port 8188"
./installer_launcher.sh set-script-param comfyui launch.ps1 DisableUpdate 1
```

给管理脚本追加额外原始参数：

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

## 配置、日志和代理

### Windows GUI 路径

```text
主配置: %APPDATA%\installer-launcher\main.json
GUI 脚本: %APPDATA%\installer-launcher\installer_launcher_gui.ps1
项目配置: %APPDATA%\installer-launcher\projects\<project>.json
缓存目录: %LOCALAPPDATA%\installer-launcher\cache\installers\<project>\
日志目录: %LOCALAPPDATA%\installer-launcher\logs\
```

GUI 支持项目选择、动态安装器配置、搜索当前系统中已安装的 WebUI 并切换管理路径、管理脚本运行、项目卸载、日志、代理模式、关于页和 GUI 自更新。GUI 不会注册 Bash 命令，也不会执行 Linux / macOS 依赖引导或 shell rc 清理。

### Bash TUI/CLI 路径

```text
主配置: ${XDG_CONFIG_HOME:-$HOME/.config}/installer-launcher/main.conf
项目配置: ${XDG_CONFIG_HOME:-$HOME/.config}/installer-launcher/projects/<project>.conf
安装器缓存: ${XDG_CACHE_HOME:-$HOME/.cache}/installer-launcher/installers/<project>/
日志目录: ${XDG_STATE_HOME:-$HOME/.local/state}/installer-launcher/logs/
启动器安装目录: ${XDG_DATA_HOME:-$HOME/.local/share}/installer-launcher
命令链接: $HOME/.local/bin/installer-launcher
```

### 日志

日志默认级别为 `DEBUG`，不会自动删除旧日志。日志会记录配置加载、自动更新、下载源尝试、PowerShell 脚本执行、管理脚本运行、卸载等关键操作。

日志会保留安装路径、项目名和脚本名，方便排查；代理地址、镜像地址、额外参数中的 token、password、key 等敏感内容会做脱敏处理。

修改日志等级：

```bash
installer-launcher set-main LOG_LEVEL INFO
```

查看日志：

```bash
installer-launcher show-log
installer-launcher show-log 200
```

### 代理

Bash TUI/CLI 启动器默认自动读取系统代理。自动模式不会覆盖用户已有的 `HTTP_PROXY` / `HTTPS_PROXY` 环境变量；关闭代理模式只会清理当前启动器进程中的代理环境变量。

```bash
# 自动读取系统代理，默认模式
installer-launcher set-main PROXY_MODE auto

# 使用手动代理
installer-launcher set-main PROXY_MODE manual
installer-launcher set-main MANUAL_PROXY http://127.0.0.1:7890

# 不使用代理
installer-launcher set-main PROXY_MODE off
```

Windows GUI 的代理模式在“设置”页修改并自动保存。`install.ps1` 是安装器脚本，独立于 GUI 配置：它默认自动检测 Windows 系统代理，也可通过 `-ProxyMode` 和 `-ManualProxy` 临时覆盖。

## 安装器和管理脚本

运行安装器时，启动器会：

1. 根据当前项目构建 PowerShell 参数。
2. 显示确认页。
3. 用户确认后，按下载源顺序重新下载安装器脚本。
4. 任意一个下载源成功后，保存到缓存目录并执行。
5. 在独立 PowerShell 控制台中保留上游输出和错误信息。

安装完成后，各项目会在安装目录中生成管理脚本。启动器只从有效安装路径中查找这些脚本。

常见脚本：

- `launch.ps1`：启动项目。
- `update.ps1`：更新项目。
- `terminal.ps1`：打开项目交互终端。
- `settings.ps1`：管理项目设置。
- `download_models.ps1`：下载模型。
- `reinstall_pytorch.ps1`：重装 PyTorch。

`activate.ps1` 不会单独显示，因为 `terminal.ps1` 会处理环境激活。

如果安装器或管理脚本返回非零退出代码，启动器会提示查看 PowerShell 控制台输出。

## 更新与卸载

### 自动更新

启动器默认启用自动检查更新。Bash 版会检查并尝试更新启动器源码；Windows GUI 版只下载并替换 Release 中的编译版 `installer_launcher_gui.ps1`。

关闭自动更新：

```bash
installer-launcher set-main AUTO_UPDATE_ENABLED 0
```

重新开启：

```bash
installer-launcher set-main AUTO_UPDATE_ENABLED 1
```

手动更新 Bash 启动器：

```bash
installer-launcher install-launcher
```

### 卸载启动器

Bash 启动器卸载：

```bash
installer-launcher uninstall-launcher
```

卸载会删除：

- 启动器安装目录。
- `$HOME/.local/bin/installer-launcher` 命令链接。
- shell 配置文件中的 PATH 注册块。
- 启动器配置目录。
- 启动器缓存目录。

Windows GUI 可以在系统“应用和功能”/控制面板中卸载 `SD WebUI All In One Launcher`，也可以在 GUI 设置页执行卸载。GUI 卸载会移除 GUI 脚本本体、快捷方式、配置目录以及日志 / 缓存目录。

卸载启动器不会删除 Stable Diffusion WebUI、ComfyUI 等项目本体安装目录。

## 开发与项目文档

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

更多维护文档：

- [架构文档](docs/architecture.md)
- [GUI 编译器文档](docs/gui-compiler.md)
- [TODO 状态板](docs/todo.md)
- [项目协作规则](AGENTS.md)
