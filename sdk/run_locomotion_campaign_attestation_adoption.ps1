#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Manifest,
    [Parameter(Mandatory)][string]$ScopedAttestation,
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter(Mandatory)][string]$ExpectedCampaignId,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
. (Join-Path $sdkRoot "locomotion_campaign_attestation_adoption.ps1")

$result = Publish-SporeSporeCampaignAttestationAdoption `
    -RepoRoot $repoRoot `
    -ManifestPath ([IO.Path]::GetFullPath($Manifest)) `
    -ScopedAttestationPath ([IO.Path]::GetFullPath($ScopedAttestation)) `
    -OutputPath ([IO.Path]::GetFullPath($OutputPath)) `
    -Godot ([IO.Path]::GetFullPath($Godot)) `
    -Python $Python `
    -ExpectedCampaignId $ExpectedCampaignId

Write-Host (
    "CAMPAIGN_ATTESTATION_ADOPTION_PASS path=$($result.path) " +
    "sha256=$($result.sha256) source=$($result.source_commit) " +
    "campaign=$($result.campaign_id) physical_prerequisite=True " +
    "physical_authority=False release_authority=False"
)
