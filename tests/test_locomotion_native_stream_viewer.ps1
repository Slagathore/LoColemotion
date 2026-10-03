#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$viewer = "res://scripts/tools/locomotion_native_stream_viewer.gd"
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw "LIVE_EXPLORER_VIEWER_GODOT_MISSING:$Godot"
}

$output = @(
    & $Godot `
        --headless `
        --path $repoRoot `
        --script $viewer `
        -- `
        --self-test 2>&1
)
$exitCode = $LASTEXITCODE
$text = $output -join [Environment]::NewLine
$output | Write-Host
if (
    $exitCode -ne 0 -or
    $text -match "SCRIPT ERROR|Parse Error|ERROR:" -or
    $text -notmatch "LOCOMOTION_NATIVE_STREAM_VIEWER_PASS worlds=0"
) {
    throw "LIVE_EXPLORER_VIEWER_SELF_TEST_FAILED:$exitCode"
}
