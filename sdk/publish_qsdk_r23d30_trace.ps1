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
$publisher = Join-Path ([IO.Path]::GetFullPath($RepoRoot)) (
    "sdk\publish_qsdk_r23d27_trace.ps1"
)
if (-not (Test-Path -LiteralPath $publisher -PathType Leaf)) {
    throw "QSDK-R23D30 inherited content-addressed trace publisher is missing"
}

$arguments = @(
    "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", $publisher,
    "-RepoRoot", $RepoRoot,
    "-ArtifactPath", $ArtifactPath,
    "-ExpectedSha256", $ExpectedSha256,
    "-ExpectedByteLength", [string]$ExpectedByteLength
)
if ($TestOnly) {
    $arguments += @("-TestOnly", "-EvidenceRootOverride", $EvidenceRootOverride)
}
$output = @(& (Join-Path $PSHOME "pwsh.exe") @arguments 2>&1)
$exitCode = $LASTEXITCODE
$prefix = "QSDK_R23D27_TRACE_CAS "
$markers = @($output | ForEach-Object { [string]$_ } | Where-Object {
    $_.StartsWith($prefix, [StringComparison]::Ordinal)
})
if ($exitCode -ne 0 -or $markers.Count -ne 1) {
    throw (
        "QSDK-R23D30 inherited trace publication failed: exit={0} markers={1} output={2}" -f
        $exitCode, $markers.Count, (($output | ForEach-Object { [string]$_ }) -join "`n")
    )
}
$payload = $markers[0].Substring($prefix.Length)
$receipt = $payload | ConvertFrom-Json -AsHashtable -Depth 100
if ([string]$receipt.sha256 -cne $ExpectedSha256 -or
    [long]$receipt.byte_length -ne $ExpectedByteLength -or
    [bool]$receipt.physical_acceptance_authority) {
    throw "QSDK-R23D30 inherited trace publication receipt changed"
}
Write-Host ("QSDK_R23D30_TRACE_CAS " + $payload)
