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
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
$artifact = [IO.Path]::GetFullPath($ArtifactPath)
$storeSource = Join-Path $PSScriptRoot "content_addressed_artifact_store.ps1"
if (-not (Test-Path -LiteralPath $storeSource -PathType Leaf)) {
    throw "QSDK-R23D49 materialized artifact-store source is missing: $storeSource"
}
if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
    throw "QSDK-R23D49 trace artifact is missing: $artifact"
}
if ($ExpectedSha256 -cnotmatch '^sha256:[0-9a-f]{64}$') {
    throw "QSDK-R23D49 expected trace SHA-256 is invalid"
}
$actualDigest = "sha256:" + (
    Get-FileHash -LiteralPath $artifact -Algorithm SHA256
).Hash.ToLowerInvariant()
$actualLength = (Get-Item -LiteralPath $artifact).Length
if ($actualDigest -cne $ExpectedSha256 -or $actualLength -ne $ExpectedByteLength) {
    throw "QSDK-R23D49 trace bytes do not match the evaluator receipt"
}
if ($TestOnly -and [string]::IsNullOrWhiteSpace($EvidenceRootOverride)) {
    throw "QSDK-R23D49 test publication requires an evidence-root override"
}
if (-not $TestOnly -and -not [string]::IsNullOrWhiteSpace($EvidenceRootOverride)) {
    throw "QSDK-R23D49 production publication forbids an evidence-root override"
}

. $storeSource
$publicationArguments = @{
    RepoRoot = $repo
    ArtifactPath = $artifact
    MediaType = "application/x-ndjson"
}
if ($TestOnly) {
    $publicationArguments.TestOnly = $true
    $publicationArguments.EvidenceRootOverride = [IO.Path]::GetFullPath(
        $EvidenceRootOverride
    )
}

$attemptErrors = [Collections.Generic.List[string]]::new()
$receipt = $null
for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
        $receipt = Publish-SporeSporeContentAddressedArtifact @publicationArguments
        break
    } catch {
        $attemptErrors.Add((
            "attempt={0} type={1} message={2}" -f
            $attempt,
            $_.Exception.GetType().FullName,
            $_.Exception.Message
        ))
        if ($attempt -lt 3) { Start-Sleep -Milliseconds (250 * $attempt) }
    }
}
if ($null -eq $receipt) {
    throw (
        "QSDK-R23D49 trace publication failed after 3 attempts: " +
        ($attemptErrors -join " | ")
    )
}
if ([string]$receipt.sha256 -cne $ExpectedSha256 -or
    [long]$receipt.byte_length -ne $ExpectedByteLength -or
    [bool]$receipt.physical_acceptance_authority) {
    throw "QSDK-R23D49 trace publication receipt changed"
}
$manifest = Get-Content -Raw -LiteralPath ([string]$receipt.manifest_path) |
    ConvertFrom-Json -AsHashtable -Depth 16
if ([string]$manifest.media_type -cne "application/x-ndjson" -or
    [string]$manifest.sha256 -cne $ExpectedSha256 -or
    [long]$manifest.byte_length -ne $ExpectedByteLength) {
    throw "QSDK-R23D49 retained trace manifest changed"
}
Write-Host (
    "QSDK_R23D49_TRACE_CAS " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
