[CmdletBinding()]
param(
    [switch]$ReuseWindow
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$godot = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
$offendingExtension = "neikeq.godot-csharp-vscode"

if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
    throw "The configured Godot 4.7 executable does not exist: $godot"
}

$codeCommand = Get-Command "code-insiders.cmd" -ErrorAction SilentlyContinue
if ($null -eq $codeCommand) {
    $fallback = Join-Path $env:LOCALAPPDATA `
        "Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd"
    if (-not (Test-Path -LiteralPath $fallback -PathType Leaf)) {
        throw @"
VS Code Insiders was not found.
Expected code-insiders.cmd on PATH or at:
$fallback
"@
    }
    $codeExecutable = $fallback
}
else {
    $codeExecutable = $codeCommand.Source
}

$windowArgument = if ($ReuseWindow) { "--reuse-window" } else { "--new-window" }
$arguments = @(
    $windowArgument
    "--disable-extension"
    $offendingExtension
    $repositoryRoot
)

Write-Host "Opening SporeSpore in VS Code Insiders."
Write-Host "Godot: $godot"
Write-Host "Session-disabled extension: $offendingExtension"
Write-Host "This disable is intentionally project-launch scoped and is not persisted globally."

& $codeExecutable @arguments
if ($LASTEXITCODE -ne 0) {
    throw "VS Code Insiders exited with code $LASTEXITCODE."
}
