#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly,
    [ValidateRange(30, 600)]
    [int]$CellTimeoutSeconds = 240
)

$ErrorActionPreference = "Stop"
$runner = Join-Path $PSScriptRoot "run_qsdk_independent_morphology_v2.ps1"
$arguments = @{
    Godot = $Godot
    CampaignId = "QSDK-R05C"
    CellTimeoutSeconds = $CellTimeoutSeconds
}
if ($PreflightOnly) {
    $arguments.PreflightOnly = $true
} else {
    $arguments.Output = $Output
}

& $runner @arguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
