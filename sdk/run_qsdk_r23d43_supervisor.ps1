#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$CampaignAttestationAdoption = "",
    [string]$OutputRoot = "",
    [string]$Python = "python",
    [string]$PowerShell = "pwsh",
    [ValidateRange(300, 3600)][int]$CellTimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"
$inherited = Join-Path $PSScriptRoot "run_qsdk_r23d27_supervisor.ps1"
if (-not (Test-Path -LiteralPath $inherited -PathType Leaf)) {
    throw "QSDK-R23D43 inherited supervisor transport is missing"
}
$arguments = @(
    "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", $inherited,
    "-CampaignVariant", "R23D43",
    "-Python", $Python,
    "-PowerShell", $PowerShell,
    "-CellTimeoutSeconds", [string]$CellTimeoutSeconds
)
if ($PreflightOnly) { $arguments += "-PreflightOnly" }
if ($RunPhysical) { $arguments += "-RunPhysical" }
if (-not [string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) {
    $arguments += @("-CampaignAttestationAdoption", $CampaignAttestationAdoption)
}
if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
    $arguments += @("-OutputRoot", $OutputRoot)
}
& (Join-Path $PSHOME "pwsh.exe") @arguments
exit $LASTEXITCODE
