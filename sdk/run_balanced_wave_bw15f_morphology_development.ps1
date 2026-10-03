#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("BW15F-A", "BW15F-B", "BW15F-C", "BW15F-D")]
    [string]$Candidate,
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
$runner = Join-Path $PSScriptRoot "run_qsdk_r05_independent_morphology.ps1"
$arguments = @{
    Godot = $Godot
    CampaignId = "BW15F-MORPHOLOGY-DEVELOPMENT"
    Candidate = $Candidate
    CellTimeoutSeconds = $CellTimeoutSeconds
}
if ($PreflightOnly) {
    $arguments.PreflightOnly = $true
} else {
    $arguments.Output = $Output
}

& $runner @arguments
