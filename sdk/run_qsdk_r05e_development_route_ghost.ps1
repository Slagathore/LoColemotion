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
    CampaignId = "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST"
    CellTimeoutSeconds = $CellTimeoutSeconds
}
if ($PreflightOnly) {
    $arguments.PreflightOnly = $true
} else {
    $arguments.Output = $Output
    $arguments.ExecutionAuthority = Join-Path (
        $PSScriptRoot
    ) "qsdk_r05e_development_route_ghost_execution_authority.json"
}

& $runner @arguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
