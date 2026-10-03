#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot "sdk\godot_jolt_phase_timing_gjpt2_closure.json"
$gjpt1ClosurePath = Join-Path $repoRoot "sdk\godot_jolt_phase_timing_gjpt1_closure.json"

function Assert-Gjpt2Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Gjpt2ClosureHash {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

Assert-Gjpt2Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "GJPT2 closure is missing: $closurePath"
)
Assert-Gjpt2Closure (Test-Path -LiteralPath $gjpt1ClosurePath -PathType Leaf) (
    "GJPT1 predecessor closure is missing: $gjpt1ClosurePath"
)
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 64
$gjpt1Closure = Get-Content -Raw -LiteralPath $gjpt1ClosurePath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Gjpt2Closure (
    [string]$closure.schema_version -ceq
        "sporespore_godot_jolt_phase_timing_gjpt2_closure_v1" -and
    [string]$closure.contract_id -ceq "GJPT2" -and
    [string]$closure.status -ceq "completed_development_measurement" -and
    [int]$closure.execution.physical_world_count -eq 1 -and
    [int]$closure.execution.instrumented_tick_count -eq 3472 -and
    [bool]$closure.execution.physical_identity_consumed -and
    -not [bool]$closure.execution.same_identity_rerun_allowed -and
    [bool]$closure.execution.synthetic_projection_canary_passed_before_world -and
    -not [bool]$closure.claims.total_cell_speedup_directly_measured -and
    -not [bool]$closure.claims.performance_generalization_authorized -and
    -not [bool]$closure.claims.physics_frame_wait_is_solver_only -and
    -not [bool]$closure.claims.source_world_outcome_interpreted -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "GJPT2 closure identity or claim boundary changed"
Assert-Gjpt2Closure (
    "sha256:$(Get-Gjpt2ClosureHash $gjpt1ClosurePath)" -ceq
        [string]$closure.source_identity.gjpt1_invalid_closure_raw_sha256 -and
    [string]$gjpt1Closure.schema_version -ceq
        "sporespore_godot_jolt_phase_timing_closure_v1" -and
    [string]$gjpt1Closure.contract_id -ceq "GJPT1" -and
    [string]$gjpt1Closure.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$gjpt1Closure.source_commit -ceq
        "d5e6e034748238c583f3e75431cb2a437ca06104" -and
    [int]$gjpt1Closure.attempt.physical_world_attempt_count -eq 1 -and
    [int]$gjpt1Closure.attempt.confirmed_physical_world_count -eq -1 -and
    [bool]$gjpt1Closure.attempt.physical_identity_consumed -and
    -not [bool]$gjpt1Closure.attempt.same_identity_rerun_allowed -and
    [string]$gjpt1Closure.observed_failure.failure_code -ceq
        "GJPT1_SOURCE_SHAPED_EVIDENCE_PROJECTION_FAILED" -and
    -not [bool]$gjpt1Closure.observed_failure.phase_measurement_authorized -and
    [bool]$gjpt1Closure.root_cause.predictable_before_world -and
    -not [bool]$gjpt1Closure.claims.phase_measurement_authorized -and
    -not [bool]$gjpt1Closure.claims.physical_acceptance_authority
) "GJPT1 immutable predecessor closure or linkage changed"

$gjpt1EvidenceRoot = [string]$gjpt1Closure.evidence_root
Assert-Gjpt2Closure (
    Test-Path -LiteralPath $gjpt1EvidenceRoot -PathType Container
) "GJPT1 durable evidence root is missing: $gjpt1EvidenceRoot"
foreach ($entry in $gjpt1Closure.retained_artifacts.GetEnumerator()) {
    $record = $entry.Value
    $path = Join-Path $gjpt1EvidenceRoot ([string]$record.relative_path)
    Assert-Gjpt2Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        "sha256:$(Get-Gjpt2ClosureHash $path)" -ceq [string]$record.raw_sha256 -and
        (Get-Item -LiteralPath $path).Length -eq [long]$record.byte_length
    ) "GJPT1 retained predecessor artifact changed: $($entry.Key)"
}
foreach ($entry in $gjpt1Closure.content_addressed_inputs_retained_before_process.GetEnumerator()) {
    $record = $entry.Value
    $path = [string]$record.payload_path
    Assert-Gjpt2Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        "sha256:$(Get-Gjpt2ClosureHash $path)" -ceq [string]$record.raw_sha256
    ) "GJPT1 content-addressed predecessor input changed: $($entry.Key)"
}

$sourceCommit = [string]$closure.source_commit
& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Gjpt2Closure ($LASTEXITCODE -eq 0) "GJPT2 source commit is unavailable"
$frozenContractBytes = & git -C $repoRoot show (
    "$sourceCommit`:" + [string]$closure.source_identity.contract_path
)
Assert-Gjpt2Closure ($LASTEXITCODE -eq 0) "GJPT2 frozen contract is unavailable"
$tempContract = Join-Path $repoRoot "sdk\target\gjpt2\closure-contract.json"
[void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $tempContract))
[System.IO.File]::WriteAllText(
    $tempContract,
    ($frozenContractBytes -join "`n") + "`n",
    [System.Text.UTF8Encoding]::new($false)
)
Assert-Gjpt2Closure (
    "sha256:$(Get-Gjpt2ClosureHash $tempContract)" -ceq
        [string]$closure.source_identity.contract_raw_sha256
) "GJPT2 frozen source contract digest changed"

$evidenceRoot = [string]$closure.evidence_root
Assert-Gjpt2Closure (
    (Test-Path -LiteralPath $evidenceRoot -PathType Container)
) "GJPT2 durable evidence root is missing: $evidenceRoot"
foreach ($entry in $closure.retained_artifacts.GetEnumerator()) {
    $record = $entry.Value
    $path = Join-Path $evidenceRoot ([string]$record.relative_path)
    Assert-Gjpt2Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        ("sha256:$(Get-Gjpt2ClosureHash $path)" -ceq [string]$record.raw_sha256) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$record.byte_length
    ) "GJPT2 retained artifact changed: $($entry.Key)"
}
foreach ($entry in $closure.content_addressed_inputs.GetEnumerator()) {
    $path = [string]$entry.Value
    $expected = if ($entry.Key -ceq "instrumented_runner_payload") {
        [string]$closure.source_identity.instrumented_runner_raw_sha256
    } else {
        [string]$closure.source_identity.godot_adapter_artifact_raw_sha256
    }
    Assert-Gjpt2Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        "sha256:$(Get-Gjpt2ClosureHash $path)" -ceq $expected
    ) "GJPT2 content-addressed input changed: $($entry.Key)"
}

$reportPath = Join-Path $evidenceRoot "phase_report.json"
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$completion = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "completion.json") |
    ConvertFrom-Json -AsHashtable -Depth 32
$authorization = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "authorization.json") |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Gjpt2Closure (
    [string]$report.status -ceq "completed_development_measurement" -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [int]$report.instrumented_tick_count -eq 3472 -and
    [int]$report.physical_world_count -eq 1 -and
    [bool]$report.physical_identity_consumed -and
    -not [bool]$report.same_identity_rerun_allowed -and
    -not [bool]$report.performance_generalization_authorized -and
    -not [bool]$report.physical_acceptance_authority -and
    [string]$completion.report_raw_sha256 -ceq
        "sha256:$(Get-Gjpt2ClosureHash $reportPath)" -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [string]$authorization.origin_main_commit -ceq $sourceCommit -and
    [string]$authorization.live_github_main_commit -ceq $sourceCommit -and
    [bool]$authorization.synthetic_projection_canary_passed -and
    -not [bool]$authorization.physical_acceptance_authority
) "GJPT2 report, completion, or authorization linkage changed"

$phaseSum = [long](($report.phase_durations.Values | Measure-Object -Sum).Sum)
Assert-Gjpt2Closure (
    $phaseSum -eq [long]$report.instrumented_denominator_usec -and
    $phaseSum -eq [long]$closure.phase_durations_usec.exact_sum
) "GJPT2 phase durations no longer close exactly"
$shareSum = [double](($report.phase_shares.Values | Measure-Object -Sum).Sum)
Assert-Gjpt2Closure (
    [Math]::Abs(
        $shareSum - [double]$closure.phase_shares.reported_binary64_sum
    ) -le 1e-15
) "GJPT2 phase shares no longer sum within binary64 tolerance"
$nativeShare = [double]$report.phase_shares.native_boundary_share
$speedup = [double]$report.persistent_session_analysis.gjps1_native_boundary_speedup
$expectedRecovered = 1.0 + $nativeShare * ($speedup - 1.0)
Assert-Gjpt2Closure (
    [Math]::Abs(
        $expectedRecovered -
        [double]$report.persistent_session_analysis.
            estimated_recovered_stateless_to_persistent_total_cell_speedup
    ) -le 1e-12 -and
    [Math]::Abs(
        $expectedRecovered -
        [double]$closure.persistent_session_analysis.
            estimated_recovered_stateless_to_persistent_total_cell_speedup
    ) -le 1e-12
) "GJPT2 post-optimization native-share analysis changed"

$authorizations = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) `
        -Filter authorization.json -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object {
        try {
            $value = Get-Content -Raw -LiteralPath $_.FullName |
                ConvertFrom-Json -AsHashtable -Depth 32
            [string]$value.contract_id -ceq "GJPT2"
        } catch { $false }
    }
)
Assert-Gjpt2Closure ($authorizations.Count -eq 1) (
    "GJPT2 expected exactly one retained physical authorization, observed " +
    $authorizations.Count
)

Write-Host (
    "GJPT2_PHASE_TIMING_CLOSURE_PASS worlds=1 ticks=3472 " +
    "native_share=$($nativeShare.ToString('F6', [Globalization.CultureInfo]::InvariantCulture)) " +
    "estimated_recovered_speedup=$($expectedRecovered.ToString('F4', [Globalization.CultureInfo]::InvariantCulture)) " +
    "same_identity_rerun=False performance_generalization=False " +
    "physical_authority=False closure_sha256=$(Get-Gjpt2ClosureHash $closurePath)"
)
