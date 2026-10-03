#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$ArtifactPath,
    [Parameter(Mandatory)][string]$ExpectedSha256,
    [Parameter(Mandatory)][long]$ExpectedByteLength,
    [ValidateSet("application/x-ndjson", "application/json")]
    [string]$MediaType = "application/x-ndjson",
    [string]$EvidenceRootOverride = "",
    [switch]$TestOnly
)

$ErrorActionPreference = "Stop"
. (Join-Path ([IO.Path]::GetFullPath($RepoRoot)) "sdk\content_addressed_artifact_store.ps1")
$arguments = @{
    RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
    ArtifactPath = [IO.Path]::GetFullPath($ArtifactPath)
    MediaType = $MediaType
}
if ($TestOnly) {
    $arguments.TestOnly = $true
    $arguments.EvidenceRootOverride = [IO.Path]::GetFullPath($EvidenceRootOverride)
}
$receipt = Publish-SporeSporeContentAddressedArtifact @arguments
if ([string]$receipt.sha256 -cne $ExpectedSha256 -or
    [long]$receipt.byte_length -ne $ExpectedByteLength -or
    [bool]$receipt.physical_acceptance_authority) {
    throw "QSDK-R23D41 evidence publication receipt changed"
}
Write-Host ("QSDK_R23D41_EVIDENCE_CAS " + ($receipt | ConvertTo-Json -Depth 20 -Compress))
