#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_balanced_wave_bw4_characterization"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"
$runner = Join-Path $PSScriptRoot (
    "run_godot_jolt_friction_ladder_characterization.ps1"
)
& $runner `
    -Campaign BW4 `
    -Godot $Godot `
    -LogRoot $LogRoot `
    -Output $Output `
    -PreflightOnly:$PreflightOnly
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
