# GUI Compiler

本文档说明 Windows GUI 启动器的单文件编译器、源码约束和验证方式。

GUI 源码保持多文件结构，正式发布给用户的是编译产物：

```text
源码入口: installer_launcher_gui.ps1
源码模块: gui/*.ps1
XAML 视图: gui/xaml/*.xaml
编译器: tools/compile_gui.py
发布产物: dist/installer_launcher_gui.ps1
```

不要手工编辑 `dist/installer_launcher_gui.ps1`。它是生成文件，下一次编译会覆盖。

## 构建命令

在仓库根目录运行：

```bash
python3 tools/compile_gui.py --output dist/installer_launcher_gui.ps1
```

默认输出路径也是 `dist/installer_launcher_gui.ps1`：

```bash
python3 tools/compile_gui.py
```

编译器会：

- 读取 `installer_launcher_gui.ps1` 的入口前缀和顶层分发逻辑。
- 从 `gui/bootstrap.ps1` 解析 `$moduleNames` 的加载顺序。
- 按顺序展开 `gui/*.ps1`。
- 将 `gui/xaml/*.xaml` 以 Base64 UTF-8 内嵌到 `$script:BundledXamlResources`。
- 用 UTF-8 with BOM 和 CRLF 写出 PowerShell 产物，兼容 Windows PowerShell 5.1。
- 在产物中保留 `#region bundled: <path>`，方便根据报错定位原始文件。

## 源码约束

### 入口脚本

`installer_launcher_gui.ps1` 必须保持薄入口结构：

- 参数和 Windows 检查可以留在入口。
- 业务逻辑必须放到 `gui/` 模块中。
- 入口中必须保留 `$bootstrapPath =` 这一行附近的 bootstrap 加载结构。
- 入口中必须保留顶层 `try { ... } catch { ... }` 分发结构。

编译器目前通过这些标记拆分入口。若重构入口，请同步更新 `tools/compile_gui.py`。

### 模块加载顺序

`gui/bootstrap.ps1` 中的模块列表必须保持这种简单形态：

```powershell
$moduleNames = @(
    "core.ps1",
    "registry.ps1",
    "config.ps1",
    "runtime.ps1",
    "ui-dialogs.ps1",
    "ui-wpf.ps1",
    "ui-pages.ps1",
    "app.ps1"
)
```

编译器只解析 `$moduleNames` 中双引号包裹的 `.ps1` 文件名。新增模块时：

- 把模块放在 `gui/` 下。
- 加入 `$moduleNames` 的正确位置。
- 确保模块在 dot-source 后可以直接运行，不依赖未加载的后续模块。

### XAML 资源

所有 XAML 文件必须放在 `gui/xaml/` 下，并通过 `Load-GuiXamlWindow "<name>.xaml"` 加载。

不要在业务代码中直接 `Get-Content $script:GuiXamlHome` 读取 XAML。编译成单文件后，XAML 不再是文件，而是内嵌资源。

XAML 约束：

- 必须是合法 XML。
- 可以是 UTF-8 with BOM；编译器会去除内嵌资源中的 BOM。
- 不要写 PowerShell 插值，例如 `$script:`、`$()`。
- 版本号、路径、主题色、状态文本等动态内容应在加载后通过 PowerShell 控件赋值。

如果编译产物报错类似“无法将值 `<Window ...>` 转换为 `System.Xml.XmlDocument`”，优先检查内嵌 XAML 是否带 BOM 或不是合法 XML。

### WPF 事件和 PowerShell 5.1

Windows PowerShell 5.1 对 WPF 事件脚本块的函数查找更窄。继续遵守这些规则：

- 在注册 WPF 事件前调用 `Export-GuiEventFunctions`。
- 被事件调用的 helper 必须导出到 `Global:`。
- 动态创建控件时，如果事件里调用新的 helper，也要加入导出列表。
- 不要依赖本地闭包保存事件 handler。
- 不要恢复 `$script:GuiHandler_*` 缓存脚本块方案。

### 自更新和发布产物

源码多文件模式没有 `$script:BundledXamlResources`，因此会跳过 GUI 自更新，避免开发入口被 release 单文件覆盖。

编译产物包含 `$script:BundledXamlResources`，可以正常执行自更新。自更新、`install.ps1` 和 release 下载地址都应指向 release asset：

```text
https://github.com/licyk/sd-webui-all-in-one-launcher/releases/download/launcher/installer_launcher_gui.ps1
https://gitee.com/licyk/sd-webui-all-in-one-launcher/releases/download/launcher/installer_launcher_gui.ps1
```

不要再让用户安装或自更新下载仓库根目录的源码入口脚本。

## 验证步骤

GUI 代码现在采用“源码多文件、发布单文件”的模型。只要修改了 `installer_launcher_gui.ps1`、`gui/*.ps1`、`gui/xaml/*.xaml`、`tools/compile_gui.py`、`install.ps1` 或 Release 流程，就应按下面顺序验证。普通文档-only 修改至少运行 `git diff --check`。

### 1. 编译器和单文件产物

先确认 Python 编译器自身可解析，再生成单文件产物：

```bash
python3 -m py_compile tools/compile_gui.py
python3 tools/compile_gui.py --output dist/installer_launcher_gui.ps1
```

`dist/` 是生成目录，不需要提交。它用于本地验证和 Release artifact 生成。

### 2. PowerShell 语法解析

检查编译产物、源码入口、全部 GUI 模块和安装脚本都能被 PowerShell 解析：

```bash
pwsh -NoProfile -Command '$null = [scriptblock]::Create((Get-Content -LiteralPath ./dist/installer_launcher_gui.ps1 -Raw)); $null = [scriptblock]::Create((Get-Content -LiteralPath ./installer_launcher_gui.ps1 -Raw)); Get-ChildItem ./gui -Filter *.ps1 -Recurse | ForEach-Object { $null = [scriptblock]::Create((Get-Content -LiteralPath $_.FullName -Raw)) }; $null = [scriptblock]::Create((Get-Content -LiteralPath ./install.ps1 -Raw))'
```

这一步只做语法解析，不能代替 Windows WPF 运行验证。

### 3. 源码 XAML 解析

先验证源码 XAML 是合法 XML：

```bash
pwsh -NoProfile -Command 'Get-ChildItem ./gui/xaml -Filter *.xaml | ForEach-Object { [xml]$x = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8; Write-Host "$($_.Name) => $($x.DocumentElement.Name)" }'
```

### 4. 内嵌 XAML 解析

再验证编译产物中的内嵌 XAML 能被 PowerShell 解码并转为 XML：

```bash
tmpdir=$(mktemp -d /tmp/gui-xaml-test.XXXXXX)
python3 - "$tmpdir" <<'PY'
import base64, re, sys
from pathlib import Path
out = Path(sys.argv[1])
text = Path("dist/installer_launcher_gui.ps1").read_text(encoding="utf-8-sig")
for name, body in re.findall(r'\$script:BundledXamlResources\["([^"]+)"\]\s*=\s*@"\n(.*?)\n"@', text, re.S):
    data = base64.b64decode(re.sub(r"\s+", "", body))
    (out / name).write_bytes(data)
PY
pwsh -NoProfile -Command "Get-ChildItem -LiteralPath '$tmpdir' -Filter *.xaml | ForEach-Object { [xml]\$x = Get-Content -LiteralPath \$_.FullName -Raw -Encoding UTF8; Write-Host \"\$(\$_.Name) => \$(\$x.DocumentElement.Name)\" }"
rm -rf "$tmpdir"
```

如果这里失败，常见原因是 XAML 不是合法 XML、XAML 含 UTF-8 BOM 未被正确去除、或者编译器的 Base64 资源写入格式被破坏。

### 5. Bash 侧静态检查

触及 `install.sh`、`installer_launcher.sh`、`lib/*.sh`、Bash 文档命令或跨端项目注册表时，继续运行 Bash 检查：

```bash
bash -n install.sh installer_launcher.sh lib/*.sh
shellcheck install.sh installer_launcher.sh lib/*.sh
```

### 6. Diff 检查

提交前总是运行：

```bash
git diff --check
```

### 7. Windows 手动验证

以下内容需要在 Windows 环境完成，Linux 上的 `pwsh` 解析检查无法覆盖 WPF 运行时差异：

- 用 Windows PowerShell 5.1 启动 `dist/installer_launcher_gui.ps1`。
- 用 PowerShell 7 启动 `dist/installer_launcher_gui.ps1`。
- 将 `dist/installer_launcher_gui.ps1` 单独复制到空目录运行，确认不依赖 `gui/` 目录。
- 首次启动时确认用户协议弹窗可显示、同意后写入配置、拒绝后退出。
- 打开帮助、日志、倒计时确认和输入对话框，确认 XAML 都能加载。
- 选择项目后确认一键启动模式、安装模式、高级选项、管理脚本参数和软件选择页能正常刷新。
- 运行一个安装器或管理脚本，确认会打开独立 PowerShell 控制台并记录 PID。
- 运行中点击“终止当前任务”，确认只终止当前 GUI 创建的进程树。
- 手动检查更新和启动自动更新不能并发破坏缓存或脚本文件。
- 创建快捷方式、启动器卸载、项目卸载、已安装 WebUI 搜索和多路径切换按预期工作。

### 8. 触发完整验证的情况

以下改动必须跑完整 GUI 验证链路，也就是第 1 到第 7 步中能在当前环境执行的全部项目：

- 修改 `gui/xaml/*.xaml`。
- 修改 `gui/ui-wpf.ps1`、`gui/ui-dialogs.ps1`、`gui/app.ps1` 或事件注册/导出逻辑。
- 修改 `gui/runtime.ps1` 中的 Runspace、外部进程、终止任务、自更新、下载、快捷方式或卸载逻辑。
- 修改 `tools/compile_gui.py`。
- 修改 `install.ps1`、Release workflow 或 GUI 自更新 URL。
- 修改项目注册表、参数构建或管理脚本列表。

## Release 接入

`.github/workflows/release.yml` 应先运行：

```bash
python tools/compile_gui.py --output dist/installer_launcher_gui.ps1
```

然后：

- 用 `dist/installer_launcher_gui.ps1` 生成 `dist/installer_launcher_gui.bat`。
- 上传 `dist/installer_launcher_gui.ps1`。
- 上传 `dist/installer_launcher_gui.bat`。
- 继续上传 `install.ps1`、`install.bat`、`install.sh`、`installer_launcher.sh`。

`dist/` 是本地生成目录，已在 `.gitignore` 中忽略。CI 会重新生成 release artifact。

## 常见问题

- 编译产物找不到 `gui/bootstrap.ps1`：说明产物里还残留源码入口 dot-source 逻辑，检查 `tools/compile_gui.py` 的入口拆分。
- 编译产物找不到 XAML 文件：说明代码绕过了 `Load-GuiXamlWindow` 直接访问文件系统。
- 编译产物 XAML 转 XML 失败：优先检查 BOM 和 XML 合法性。
- PowerShell 5.1 中事件找不到函数：把事件 helper 加入 `Export-GuiEventFunctions`。
- 自更新把开发入口覆盖：源码模式必须跳过自更新，只有编译产物允许更新自身。
