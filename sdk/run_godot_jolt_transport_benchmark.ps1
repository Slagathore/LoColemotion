#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$EvidenceRoot = "",
    [Parameter(Mandatory = $false)]
    [string]$CargoTargetRoot = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$canonicalTarget = [System.IO.Path]::GetFullPath(
    (Join-Path $repoRoot "sdk\target")
)

$actualRoot = [System.IO.Path]::GetFullPath(
    (& git -C $repoRoot rev-parse --show-toplevel).Trim()
)
if ($LASTEXITCODE -ne 0 -or $actualRoot -cne $repoRoot) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_REPOSITORY_ROOT_MISMATCH"
}
$actualRemote = (& git -C $repoRoot remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRemote -cne $expectedRemote) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_REMOTE_MISMATCH"
}
$headBefore = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_HEAD_FAILED"
}
$statusBefore = @(& git -C $repoRoot status --short)
if ($LASTEXITCODE -ne 0) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_STATUS_FAILED"
}

$durableEvidenceBase = Join-Path (
    Split-Path -Parent $repoRoot
) "SporeSpore_Evidence"
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
    $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    $EvidenceRoot = Join-Path $durableEvidenceBase "gjtp1-transport-benchmark-$stamp"
}
$evidenceRootFull = [System.IO.Path]::GetFullPath($EvidenceRoot)
$repoPrefix = $repoRoot.TrimEnd('\') + '\'
if (
    $evidenceRootFull -ceq $repoRoot -or
    $evidenceRootFull.StartsWith(
        $repoPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )
) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_EVIDENCE_INSIDE_REPOSITORY"
}
if (Test-Path -LiteralPath $evidenceRootFull) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_EVIDENCE_ROOT_ALREADY_EXISTS"
}

if ([string]::IsNullOrWhiteSpace($CargoTargetRoot)) {
    $CargoTargetRoot = Join-Path (
        $durableEvidenceBase
    ) "gjtp1-transport-benchmark-cargo-target"
}
$isolatedTarget = [System.IO.Path]::GetFullPath($CargoTargetRoot)
$canonicalTargetPrefix = $canonicalTarget.TrimEnd('\') + '\'
if (
    $isolatedTarget -ceq $canonicalTarget -or
    $isolatedTarget.StartsWith(
        $canonicalTargetPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )
) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_CANONICAL_TARGET_SELECTED"
}
$evidenceRootPrefix = $evidenceRootFull.TrimEnd('\') + '\'
$isolatedTargetPrefix = $isolatedTarget.TrimEnd('\') + '\'
if (
    $isolatedTarget -ceq $evidenceRootFull -or
    $isolatedTarget.StartsWith(
        $evidenceRootPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    ) -or
    $evidenceRootFull.StartsWith(
        $isolatedTargetPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )
) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_TARGET_EVIDENCE_OVERLAP"
}

function Get-OptionalSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

$canonicalArtifacts = [ordered]@{
    locomotion_core_release_dll = Join-Path (
        $canonicalTarget
    ) "release\sporespore_locomotion_core.dll"
    godot_adapter_release_dll = Join-Path (
        $canonicalTarget
    ) "release\sporespore_godot_adapter.dll"
}
$canonicalBefore = [ordered]@{}
foreach ($entry in $canonicalArtifacts.GetEnumerator()) {
    $canonicalBefore[$entry.Key] = Get-OptionalSha256 -Path $entry.Value
}

New-Item -ItemType Directory -Path $evidenceRootFull | Out-Null
New-Item -ItemType Directory -Path $isolatedTarget -Force | Out-Null
$artifactBackupRoot = Join-Path $evidenceRootFull "canonical-release-artifact-backup"
New-Item -ItemType Directory -Path $artifactBackupRoot | Out-Null
foreach ($entry in $canonicalArtifacts.GetEnumerator()) {
    if (Test-Path -LiteralPath $entry.Value -PathType Leaf) {
        Copy-Item -LiteralPath $entry.Value -Destination $artifactBackupRoot
    }
}
$transcriptPath = Join-Path $evidenceRootFull "stdout-stderr.log"
$receiptPath = Join-Path $evidenceRootFull "receipt.json"
$manifestPath = Join-Path $repoRoot "sdk\Cargo.toml"
$testName = (
    "tests::benchmark_single_pass_against_legacy_two_pass_balanced_wave"
)

$startedUtc = (Get-Date).ToUniversalTime().ToString("o")
$output = @(
    & cargo test `
        --manifest-path $manifestPath `
        --target-dir $isolatedTarget `
        -p sporespore-godot-adapter `
        --release `
        --offline `
        $testName `
        -- `
        --ignored `
        --exact `
        --nocapture 2>&1
)
$cargoExitCode = $LASTEXITCODE
$completedUtc = (Get-Date).ToUniversalTime().ToString("o")
$output | Set-Content -LiteralPath $transcriptPath -Encoding utf8
$output | ForEach-Object { Write-Host $_ }

$canonicalAfter = [ordered]@{}
$canonicalUnchanged = $true
foreach ($entry in $canonicalArtifacts.GetEnumerator()) {
    $canonicalAfter[$entry.Key] = Get-OptionalSha256 -Path $entry.Value
    if ($canonicalAfter[$entry.Key] -cne $canonicalBefore[$entry.Key]) {
        $canonicalUnchanged = $false
    }
}

$benchmarkLine = @(
    $output | Where-Object {
        [string]$_ -like "*GODOT_JOLT_TRANSPORT_MICROBENCHMARK*"
    }
)
$statusAfter = @(& git -C $repoRoot status --short)
if ($LASTEXITCODE -ne 0) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_STATUS_FAILED"
}
$headAfter = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_HEAD_FAILED"
}
$sourceUnchanged = (
    $headAfter -ceq $headBefore -and
    ($statusAfter -join "`n") -ceq ($statusBefore -join "`n")
)

$receipt = [ordered]@{
    schema_version = "sporespore_godot_jolt_transport_benchmark_receipt_v1"
    status = if (
        $cargoExitCode -eq 0 -and
        $benchmarkLine.Count -eq 1 -and
        $canonicalUnchanged -and
        $sourceUnchanged
    ) { "complete" } else { "failed" }
    claim_scope = "development_native_boundary_microbenchmark_only"
    source = [ordered]@{
        repository_root = $repoRoot
        remote_url = $actualRemote
        unchanged_during_benchmark = $sourceUnchanged
        head_before = $headBefore
        head_after = $headAfter
        status_entries_before = $statusBefore
        status_entries_after = $statusAfter
    }
    execution = [ordered]@{
        started_utc = $startedUtc
        completed_utc = $completedUtc
        cargo_exit_code = $cargoExitCode
        cargo_target = $isolatedTarget
        canonical_sdk_target_permitted = $false
        benchmark_line = if ($benchmarkLine.Count -eq 1) {
            [string]$benchmarkLine[0]
        } else {
            $null
        }
    }
    canonical_release_artifacts = [ordered]@{
        unchanged = $canonicalUnchanged
        before = $canonicalBefore
        after = $canonicalAfter
        backup_root = $artifactBackupRoot
    }
    evidence = [ordered]@{
        transcript_path = $transcriptPath
        transcript_sha256 = "sha256:" + (
            Get-FileHash -Algorithm SHA256 -LiteralPath $transcriptPath
        ).Hash.ToLowerInvariant()
    }
    world_build_count = 0
    physical_acceptance_authority = $false
}
$receipt | ConvertTo-Json -Depth 16 | Set-Content `
    -LiteralPath $receiptPath `
    -Encoding utf8

if (-not $canonicalUnchanged) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_CANONICAL_ARTIFACT_MUTATION"
}
if (-not $sourceUnchanged) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_SOURCE_DRIFT"
}
if ($cargoExitCode -ne 0) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_CARGO_FAILED:$cargoExitCode"
}
if ($benchmarkLine.Count -ne 1) {
    throw "GODOT_JOLT_TRANSPORT_BENCHMARK_RESULT_CARDINALITY"
}

Write-Host (
    "GODOT_JOLT_TRANSPORT_BENCHMARK_PASS " +
    "target_isolated=True canonical_artifacts_unchanged=True worlds=0 " +
    "physical_authority=False receipt=$receiptPath"
)
