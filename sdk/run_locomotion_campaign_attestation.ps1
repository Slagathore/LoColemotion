#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Manifest,
    [Parameter(Mandatory)][string]$OutputRoot,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "python",
    [ValidateRange(1, 7200)][int]$GateTimeoutSeconds = 3600
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$modulePath = Join-Path $sdkRoot "locomotion_campaign_attestation.ps1"
. $modulePath

$result = Invoke-SporeSporeCampaignAttestation `
    -RepoRoot $repoRoot `
    -ManifestPath ([IO.Path]::GetFullPath($Manifest)) `
    -Godot ([IO.Path]::GetFullPath($Godot)) `
    -Python $Python `
    -OutputRoot ([IO.Path]::GetFullPath($OutputRoot)) `
    -GateTimeoutSeconds $GateTimeoutSeconds

Write-Host (
    "CAMPAIGN_LOCAL_ATTESTATION_PUBLISHED path=$($result.path) " +
    "sha256=$($result.sha256) source=$($result.source_commit) " +
    "campaign=$($result.campaign_id) commissioned=False " +
    "physical_prerequisite=False physical_authority=False"
)
