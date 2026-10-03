#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_balanced_wave_bw5v_validation"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"
$runner = Join-Path $PSScriptRoot "run_balanced_wave_bw3_validation.ps1"
& $runner `
    -Campaign BW5V `
    -Candidate BW5R-B `
    -Godot $Godot `
    -LogRoot $LogRoot `
    -Output $Output `
    -PreflightOnly:$PreflightOnly
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
