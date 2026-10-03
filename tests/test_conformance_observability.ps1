#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$modulePath = Join-Path $sdkRoot "conformance_observability.ps1"
$contractPath = Join-Path $sdkRoot "conformance_observability_contract_v1.json"
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"

function Assert-ConformanceObservation {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "CONFORMANCE_OBSERVABILITY $Message"
    }
}

foreach ($path in @($modulePath, $contractPath, $runnerPath)) {
    Assert-ConformanceObservation `
        (Test-Path -LiteralPath $path -PathType Leaf) `
        "required source is missing: $path"
}
[void][scriptblock]::Create((Get-Content -LiteralPath $modulePath -Raw))
[void][scriptblock]::Create((Get-Content -LiteralPath $runnerPath -Raw))
. $modulePath

$contract = Get-SporeSporeConformanceObservationContract
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
$moduleSource = Get-Content -LiteralPath $modulePath -Raw
Assert-ConformanceObservation `
    ($contract.stage_order.Count -eq 8) `
    "contract must declare exactly eight ordered stages"
Assert-ConformanceObservation `
    ([string]$contract.cache_boundary.status -ceq "disabled_uncommissioned" -and
        -not [bool]$contract.cache_boundary.lookup_permitted -and
        -not [bool]$contract.cache_boundary.reuse_permitted -and
        -not [bool]$contract.cache_boundary.cache_hit_authority -and
        [bool]$contract.cache_boundary.full_source_exact_conformance_remains_required) `
    "cache boundary must remain fail-closed and uncommissioned"
Assert-ConformanceObservation `
    (-not [bool]$contract.input_identity_boundary.transitive_dependency_key_complete -and
        -not [bool]$contract.input_identity_boundary.undeclared_dependency_detection_complete -and
        -not [bool]$contract.input_identity_boundary.host_semantics_key_complete) `
    "instrumentation must not claim a complete dependency key"
Assert-ConformanceObservation `
    ($runnerSource.Contains('. $observabilityPath', [StringComparison]::Ordinal) -and
        $runnerSource.Contains('Start-Transcript', [StringComparison]::Ordinal) -and
        $runnerSource.Contains('Complete-SporeSporeConformanceObservation', [StringComparison]::Ordinal) -and
        $moduleSource.Contains(
            'New-SporeSporeConformanceDependencyKeyCandidate',
            [StringComparison]::Ordinal) -and
        $moduleSource.Contains('dependency_key_candidate =', [StringComparison]::Ordinal) -and
        $moduleSource.Contains(
            'if ($index -eq 0 -and [bool]$Session.dependency_key_candidate_required)',
            [StringComparison]::Ordinal)) `
    "canonical runner is not wired to observation and transcript finalization"
Assert-ConformanceObservation `
    (-not $runnerSource.Contains("UseCached", [StringComparison]::OrdinalIgnoreCase) -and
        -not $moduleSource.Contains("lookup_performed = `$true", [StringComparison]::Ordinal) -and
        -not $moduleSource.Contains("result_reused = `$true", [StringComparison]::Ordinal)) `
    "cache lookup or result reuse became reachable before commissioning"

$lastIndex = -1
foreach ($stage in $contract.stage_order) {
    $needle = '-StageId "' + [string]$stage.stage_id + '"'
    $index = $runnerSource.IndexOf($needle, [StringComparison]::Ordinal)
    Assert-ConformanceObservation `
        ($index -gt $lastIndex) `
        "canonical runner lost ordered stage marker $($stage.stage_id)"
    Assert-ConformanceObservation `
        ($runnerSource.IndexOf($needle, $index + 1, [StringComparison]::Ordinal) -lt 0) `
        "canonical runner duplicates stage marker $($stage.stage_id)"
    $lastIndex = $index
}

$targetParent = [System.IO.Path]::GetFullPath((Join-Path $sdkRoot "target"))
$testRoot = Join-Path $targetParent (
    "conformance-observability-test-" + [guid]::NewGuid().ToString("N")
)
[void][System.IO.Directory]::CreateDirectory($testRoot)
try {
    $successEvidence = Join-Path $testRoot "success-evidence"
    $success = New-SporeSporeConformanceObservationSession `
        -RepoRoot $repoRoot `
        -RunnerPath $runnerPath `
        -SkipGodot $true `
        -EvidenceRootOverride $successEvidence `
        -TestOnly `
        -SkipToolProbes `
        -SkipDependencyKeyCandidate `
        -SuppressConsoleReceipts
    [System.IO.File]::WriteAllText(
        $success.log_path,
        "synthetic successful conformance transcript`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    foreach ($stage in $contract.stage_order) {
        Start-SporeSporeConformanceStage `
            -Session $success `
            -StageId ([string]$stage.stage_id)
        $status = if ([string]$stage.stage_id -ceq "godot_runtime_regression") {
            "skipped"
        } else { "passed" }
        [void](Complete-SporeSporeConformanceStage `
            -Session $success `
            -Status $status)
    }
    $successSummary = Complete-SporeSporeConformanceObservation `
        -Session $success `
        -Status passed
    $successReceipt = Get-Content -LiteralPath $success.run_receipt_path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 32
    Assert-ConformanceObservation `
        ([string]$successSummary.status -ceq "passed" -and
            [string]$successSummary.tier -ceq "canonical_no_godot" -and
            [string]$successReceipt.schema_version -ceq
                "sporespore_conformance_run_observation_v1" -and
            [string]$successReceipt.tier -ceq "canonical_no_godot" -and
            $successReceipt.stage_receipts.Count -eq 8 -and
            [string]$successReceipt.cache.status -ceq "disabled_uncommissioned" -and
            -not [bool]$successReceipt.cache.lookup_performed -and
            -not [bool]$successReceipt.cache.result_reused -and
            -not [bool]$successReceipt.cache.reuse_authority -and
            -not [bool]$successReceipt.input_identity.transitive_dependency_key_complete -and
            [string]$successReceipt.input_identity.dependency_key_candidate.status -ceq
                "test_fixture_candidate_skipped") `
        "successful run receipt exceeded the instrumentation-only boundary"
    Assert-ConformanceObservation `
        ((Get-SporeSporeConformanceRawSha256 `
            $successReceipt.full_log.cas_payload_path) -ceq
            [string]$successReceipt.full_log.raw_sha256) `
        "successful transcript CAS payload does not reproduce retained bytes"
    foreach ($stageProjection in $successReceipt.stage_receipts) {
        $stageReceipt = Get-Content -LiteralPath $stageProjection.receipt_path -Raw |
            ConvertFrom-Json -AsHashtable -Depth 16
        foreach ($field in $contract.receipt_requirements.required_stage_fields) {
            Assert-ConformanceObservation `
                $stageReceipt.ContainsKey([string]$field) `
                "stage receipt $($stageProjection.stage_id) lacks $field"
        }
        Assert-ConformanceObservation `
            ((Get-SporeSporeConformanceRawSha256 `
                $stageProjection.receipt_cas_payload_path) -ceq
                [string]$stageProjection.receipt_raw_sha256 -and
                -not [bool]$stageReceipt.cache.result_reused -and
                -not [bool]$stageReceipt.claims.physical_acceptance_authority) `
            "stage receipt $($stageProjection.stage_id) failed CAS or non-authority checks"
    }

    $wrongOrder = New-SporeSporeConformanceObservationSession `
        -RepoRoot $repoRoot `
        -RunnerPath $runnerPath `
        -SkipGodot $true `
        -EvidenceRootOverride (Join-Path $testRoot "wrong-order") `
        -TestOnly `
        -SkipToolProbes `
        -SkipDependencyKeyCandidate `
        -SuppressConsoleReceipts
    $wrongOrderRejected = $false
    try {
        Start-SporeSporeConformanceStage `
            -Session $wrongOrder `
            -StageId "source_inventory_and_zero_world_preflights"
    } catch { $wrongOrderRejected = $true }
    Assert-ConformanceObservation $wrongOrderRejected "wrong stage order was accepted"

    $duplicate = New-SporeSporeConformanceObservationSession `
        -RepoRoot $repoRoot `
        -RunnerPath $runnerPath `
        -SkipGodot $true `
        -EvidenceRootOverride (Join-Path $testRoot "duplicate") `
        -TestOnly `
        -SkipToolProbes `
        -SkipDependencyKeyCandidate `
        -SuppressConsoleReceipts
    Start-SporeSporeConformanceStage `
        -Session $duplicate `
        -StageId "authority_and_historical_closures"
    $duplicateRejected = $false
    try {
        Start-SporeSporeConformanceStage `
            -Session $duplicate `
            -StageId "authority_and_historical_closures"
    } catch { $duplicateRejected = $true }
    Assert-ConformanceObservation $duplicateRejected "overlapping stage was accepted"

    $incomplete = New-SporeSporeConformanceObservationSession `
        -RepoRoot $repoRoot `
        -RunnerPath $runnerPath `
        -SkipGodot $true `
        -EvidenceRootOverride (Join-Path $testRoot "incomplete") `
        -TestOnly `
        -SkipToolProbes `
        -SkipDependencyKeyCandidate `
        -SuppressConsoleReceipts
    [System.IO.File]::WriteAllText(
        $incomplete.log_path,
        "incomplete transcript`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    Start-SporeSporeConformanceStage `
        -Session $incomplete `
        -StageId "authority_and_historical_closures"
    [void](Complete-SporeSporeConformanceStage -Session $incomplete)
    $incompleteRejected = $false
    try {
        [void](Complete-SporeSporeConformanceObservation `
            -Session $incomplete `
            -Status passed)
    } catch { $incompleteRejected = $true }
    Assert-ConformanceObservation $incompleteRejected "partial passing run was accepted"

    $failure = New-SporeSporeConformanceObservationSession `
        -RepoRoot $repoRoot `
        -RunnerPath $runnerPath `
        -SkipGodot $true `
        -EvidenceRootOverride (Join-Path $testRoot "failure") `
        -TestOnly `
        -SkipToolProbes `
        -SkipDependencyKeyCandidate `
        -SuppressConsoleReceipts
    [System.IO.File]::WriteAllText(
        $failure.log_path,
        ((1..60 | ForEach-Object { "failure-log-line-$_" }) -join "`n") + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    Start-SporeSporeConformanceStage `
        -Session $failure `
        -StageId "authority_and_historical_closures"
    $syntheticError = $null
    try { throw "synthetic retained failure" } catch { $syntheticError = $_ }
    [void](Fail-SporeSporeConformanceStage `
        -Session $failure `
        -ErrorRecord $syntheticError `
        -ExitCode 17)
    $failureSummary = Complete-SporeSporeConformanceObservation `
        -Session $failure `
        -Status failed
    $failureReceipt = Get-Content -LiteralPath $failure.run_receipt_path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 32
    Assert-ConformanceObservation `
        ([string]$failureSummary.status -ceq "failed" -and
            $failureReceipt.stage_receipts.Count -eq 1 -and
            [string]$failureReceipt.stage_receipts[0].status -ceq "failed" -and
            [int]$failureReceipt.stage_receipts[0].exit_code -eq 17 -and
            (Test-Path -LiteralPath $failureReceipt.failure_excerpt.path -PathType Leaf) -and
            (Test-Path -LiteralPath $failureReceipt.failure_excerpt.cas_payload_path -PathType Leaf) -and
            (Get-Item -LiteralPath $failureReceipt.failure_excerpt.path).Length -gt 0 -and
            -not [bool]$failureReceipt.claims.scientific_result) `
        "failed run did not retain its bounded excerpt and non-authority receipt"

    $candidateFailure = New-SporeSporeConformanceObservationSession `
        -RepoRoot $repoRoot `
        -RunnerPath $runnerPath `
        -SkipGodot $true `
        -EvidenceRootOverride (Join-Path $testRoot "candidate-failure") `
        -TestOnly `
        -SkipToolProbes `
        -SuppressConsoleReceipts
    [System.IO.File]::WriteAllText(
        $candidateFailure.log_path,
        "candidate construction failure transcript`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $originalCandidateFunction = (
        Get-Item Function:\New-SporeSporeConformanceDependencyKeyCandidate
    ).ScriptBlock
    $candidateError = $null
    try {
        Set-Item `
            Function:\New-SporeSporeConformanceDependencyKeyCandidate `
            -Value { throw "synthetic dependency candidate failure" }
        try {
            Start-SporeSporeConformanceStage `
                -Session $candidateFailure `
                -StageId "authority_and_historical_closures"
        } catch { $candidateError = $_ }
    } finally {
        Set-Item `
            Function:\New-SporeSporeConformanceDependencyKeyCandidate `
            -Value $originalCandidateFunction
    }
    Assert-ConformanceObservation `
        ($null -ne $candidateError -and
            $null -ne $candidateFailure.current_stage -and
            [string]$candidateFailure.dependency_key_candidate.status -ceq
                "candidate_construction_failed") `
        "dependency candidate failure escaped the retained stage boundary"
    [void](Fail-SporeSporeConformanceStage `
        -Session $candidateFailure `
        -ErrorRecord $candidateError `
        -ExitCode 23)
    $candidateFailureSummary = Complete-SporeSporeConformanceObservation `
        -Session $candidateFailure `
        -Status failed
    $candidateFailureReceipt = Get-Content `
        -LiteralPath $candidateFailure.run_receipt_path `
        -Raw | ConvertFrom-Json -AsHashtable -Depth 32
    Assert-ConformanceObservation `
        ([string]$candidateFailureSummary.status -ceq "failed" -and
            $candidateFailureReceipt.stage_receipts.Count -eq 1 -and
            [int]$candidateFailureReceipt.stage_receipts[0].exit_code -eq 23 -and
            [string]$candidateFailureReceipt.input_identity.
                dependency_key_candidate.status -ceq
                "candidate_construction_failed" -and
            -not [bool]$candidateFailureReceipt.cache.result_reused) `
        "dependency candidate failure was not retained fail-closed"

    $productionOverrideRejected = $false
    try {
        [void](New-SporeSporeConformanceObservationSession `
            -RepoRoot $repoRoot `
            -RunnerPath $runnerPath `
            -SkipGodot $true `
            -EvidenceRootOverride (Join-Path $testRoot "forbidden-production-root"))
    } catch { $productionOverrideRejected = $true }
    Assert-ConformanceObservation `
        $productionOverrideRejected `
        "production observation accepted a noncanonical evidence root"

    Write-Output (
        "CONFORMANCE_OBSERVABILITY_PASS stages=8 success_receipts=8 " +
        "cache=disabled_uncommissioned cas_retention=True failure_retained=True " +
        "mutation_controls=6 worlds=0 physical_authority=False"
    )
} finally {
    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    $safePrefix = $targetParent.TrimEnd('\', '/') +
        [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedTestRoot.StartsWith(
        $safePrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    ) -or (Split-Path -Leaf $resolvedTestRoot) -notlike
        "conformance-observability-test-*") {
        throw "Refusing unsafe conformance-observability test cleanup: $resolvedTestRoot"
    }
    if (Test-Path -LiteralPath $resolvedTestRoot) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
