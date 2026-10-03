#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$ArtifactPath,
    [Parameter(Mandatory)][string]$ExpectedSha256,
    [Parameter(Mandatory)][long]$ExpectedByteLength,
    [string]$EvidenceRootOverride = "",
    [switch]$TestOnly
)

$ErrorActionPreference = "Stop"
. (Join-Path ([IO.Path]::GetFullPath($RepoRoot)) "sdk\content_addressed_artifact_store.ps1")
$arguments = @{
    RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
    ArtifactPath = [IO.Path]::GetFullPath($ArtifactPath)
    MediaType = "application/x-ndjson"
}
if ($TestOnly) {
    $arguments.TestOnly = $true
    $arguments.EvidenceRootOverride = [IO.Path]::GetFullPath($EvidenceRootOverride)
}
$receipt = Publish-SporeSporeContentAddressedArtifact @arguments
if ([string]$receipt.sha256 -cne $ExpectedSha256 -or
    [long]$receipt.byte_length -ne $ExpectedByteLength -or
    [bool]$receipt.physical_acceptance_authority) {
    throw "QSDK-R23D33 trace publication receipt changed"
}
Write-Host ("QSDK_R23D33_TRACE_CAS " + ($receipt | ConvertTo-Json -Depth 20 -Compress))
