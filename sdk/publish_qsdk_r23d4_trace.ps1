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
$repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
$artifact = [IO.Path]::GetFullPath($ArtifactPath)
$expectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
).TrimEnd('\', '/')

if ($repo -cne $expectedRoot) {
    throw "QSDK-R23D4 trace publisher repository root mismatch"
}
if ((git -C $repo rev-parse --show-toplevel).Replace('/', '\') -cne $repo) {
    throw "QSDK-R23D4 trace publisher Git root mismatch"
}
if ((git -C $repo remote get-url origin) -cne
    "https://github.com/Slagathore/sporespore.git") {
    throw "QSDK-R23D4 trace publisher origin mismatch"
}
if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
    throw "QSDK-R23D4 trace artifact is missing"
}
if ($ExpectedSha256 -cnotmatch '^sha256:[0-9a-f]{64}$') {
    throw "QSDK-R23D4 expected trace SHA-256 is invalid"
}

$actualDigest = "sha256:" + (
    Get-FileHash -LiteralPath $artifact -Algorithm SHA256
).Hash.ToLowerInvariant()
$actualLength = (Get-Item -LiteralPath $artifact).Length
if ($actualDigest -cne $ExpectedSha256 -or
    $actualLength -ne $ExpectedByteLength) {
    throw "QSDK-R23D4 trace bytes do not match the worker receipt"
}
if ($TestOnly -and [string]::IsNullOrWhiteSpace($EvidenceRootOverride)) {
    throw "QSDK-R23D4 test publication requires an evidence-root override"
}
if (-not $TestOnly -and -not [string]::IsNullOrWhiteSpace($EvidenceRootOverride)) {
    throw "QSDK-R23D4 production publication forbids an evidence-root override"
}

. (Join-Path $repo "sdk\content_addressed_artifact_store.ps1")
$arguments = @{
    RepoRoot = $repo
    ArtifactPath = $artifact
    MediaType = "application/x-ndjson"
}
if ($TestOnly) {
    $arguments.TestOnly = $true
    $arguments.EvidenceRootOverride = [IO.Path]::GetFullPath($EvidenceRootOverride)
}
$receipt = Publish-SporeSporeContentAddressedArtifact @arguments
if (-not (Test-SporeSporeStoredArtifact `
    -Directory (Split-Path -Parent ([string]$receipt.payload_path)) `
    -ExpectedSha256 $ExpectedSha256.Substring(7) `
    -ExpectedByteLength $ExpectedByteLength)) {
    throw "QSDK-R23D4 retained trace failed content-addressed verification"
}

Write-Host (
    "QSDK_R23D4_TRACE_CAS " +
    ($receipt | ConvertTo-Json -Depth 16 -Compress)
)
