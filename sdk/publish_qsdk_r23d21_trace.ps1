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

function ConvertTo-R23D21LocalWindowsPathIdentity {
    param([Parameter(Mandatory)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "QSDK-R23D21 trace publisher path identity is empty"
    }
    $full = [IO.Path]::GetFullPath($Path).Replace('/', '\')
    if ($full.StartsWith('\\?\UNC\', [StringComparison]::OrdinalIgnoreCase) -or
        $full.StartsWith('\\.\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "QSDK-R23D21 trace publisher path identity kind is unsupported"
    }
    if ($full.StartsWith('\\?\', [StringComparison]::Ordinal)) {
        $full = $full.Substring(4)
    }
    if ($full -cnotmatch '^[A-Za-z]:\\') {
        throw "QSDK-R23D21 trace publisher path identity is not a local drive path"
    }
    return $full.TrimEnd('\')
}

$repo = ConvertTo-R23D21LocalWindowsPathIdentity -Path $RepoRoot
$artifact = [IO.Path]::GetFullPath($ArtifactPath)
$expectedRoot = ConvertTo-R23D21LocalWindowsPathIdentity -Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)

if (-not [string]::Equals(
    $repo,
    $expectedRoot,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "QSDK-R23D21 trace publisher repository root mismatch"
}
$gitRoot = ConvertTo-R23D21LocalWindowsPathIdentity -Path (
    (git -C $repo rev-parse --show-toplevel).Trim()
)
if (-not [string]::Equals(
    $gitRoot,
    $repo,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "QSDK-R23D21 trace publisher Git root mismatch"
}
if ((git -C $repo remote get-url origin) -cne
    "https://github.com/Slagathore/sporespore.git") {
    throw "QSDK-R23D21 trace publisher origin mismatch"
}
if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
    throw "QSDK-R23D21 trace artifact is missing"
}
if ($ExpectedSha256 -cnotmatch '^sha256:[0-9a-f]{64}$') {
    throw "QSDK-R23D21 expected trace SHA-256 is invalid"
}

$actualDigest = "sha256:" + (
    Get-FileHash -LiteralPath $artifact -Algorithm SHA256
).Hash.ToLowerInvariant()
$actualLength = (Get-Item -LiteralPath $artifact).Length
if ($actualDigest -cne $ExpectedSha256 -or
    $actualLength -ne $ExpectedByteLength) {
    throw "QSDK-R23D21 trace bytes do not match the worker receipt"
}
if ($TestOnly -and [string]::IsNullOrWhiteSpace($EvidenceRootOverride)) {
    throw "QSDK-R23D21 test publication requires an evidence-root override"
}
if (-not $TestOnly -and -not [string]::IsNullOrWhiteSpace($EvidenceRootOverride)) {
    throw "QSDK-R23D21 production publication forbids an evidence-root override"
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
    throw "QSDK-R23D21 retained trace failed content-addressed verification"
}

Write-Host (
    "QSDK_R23D21_TRACE_CAS " +
    ($receipt | ConvertTo-Json -Depth 16 -Compress)
)
