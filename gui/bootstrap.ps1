# GUI module bootstrap. Dot-source from installer_launcher_gui.ps1 only.

$script:GuiRoot = $PSScriptRoot
if ($null -eq (Get-Variable -Name RepoRoot -Scope Script -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($script:RepoRoot)) {
    $script:RepoRoot = Split-Path -Parent $script:GuiRoot
}
$script:GuiXamlHome = Join-Path $script:GuiRoot "xaml"

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

foreach ($moduleName in $moduleNames) {
    $modulePath = Join-Path $script:GuiRoot $moduleName
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        throw "GUI 模块不存在: $modulePath"
    }
    . $modulePath
}
