#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$contractPath = Join-Path $turningRoot "r23d15_stage_one_evidence_contract_v1.json"
$stageZeroClosureAudit = Join-Path $PSScriptRoot "test_qsdk_r23d15_stage_zero_closure.ps1"
$provenanceAudit = Join-Path $PSScriptRoot "test_closure_evidence_provenance_contract.ps1"
$futurePaths = @(
    "sdk/turning/r23d15_physical_implementation_contract_v1.json",
    "sdk/turning/r23d15_dependency_closure.ps1",
    "sdk/turning/r23d15_terminal_marker_classifier.ps1",
    "sdk/run_qsdk_r23d15_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d15_supervisor.ps1",
    "sdk/run_qsdk_r23d15_zero_world_gate.ps1",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d15_physical.py",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d15_physical.rs",
    "tests/test_sdk_qsdk_r23d15_godot_jolt_physical_worker.gd"
)

function Assert-R23D15StageOne([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D15RawSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D15StageOne (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D15 stage-one repository identity mismatch"

foreach ($path in @($contractPath, $stageZeroClosureAudit, $provenanceAudit)) {
    Assert-R23D15StageOne (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D15 stage-one authority missing: $path"
    )
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$bindings = @($contract.source_bindings)
Assert-R23D15StageOne ($bindings.Count -eq 14) (
    "QSDK-R23D15 stage-one source binding count changed"
)
$bindingPaths = @($bindings | ForEach-Object { [string]$_.path })
Assert-R23D15StageOne (
    @($bindingPaths | Sort-Object -Unique).Count -eq $bindingPaths.Count
) "QSDK-R23D15 stage-one duplicate source binding"
foreach ($binding in $bindings) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-R23D15StageOne (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D15 stage-one source binding missing: $($binding.path)"
    )
    Assert-R23D15StageOne (
        (Get-R23D15RawSha256 $path) -ceq [string]$binding.raw_sha256
    ) "QSDK-R23D15 stage-one source binding changed: $($binding.path)"
}
foreach ($futurePath in $futurePaths) {
    Assert-R23D15StageOne (
        -not (Test-Path -LiteralPath (Join-Path $repoRoot $futurePath))
    ) "QSDK-R23D15 stage-one already contains future physical route: $futurePath"
}

$science = $contract.frozen_scientific_question
$trace = $contract.production_trace_contract
$retention = $contract.content_addressed_retention
$evaluator = $contract.production_evaluator_contract
$claims = $contract.claims
Assert-R23D15StageOne (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d15_stage_one_evidence_contract_v1" -and
    [string]$contract.status -ceq
        "stage_one_zero_world_trace_retention_and_direct_matrix_evaluator_complete_no_physical_workers" -and
    [string]$contract.campaign_id -ceq
        "QSDK-R23D15-PRODUCTION-COMPOSITION-RECOVERY-THREE-ENGINE-TURN-CONFIRMATION" -and
    [string]$contract.gate_id -ceq "QSDK-R23D15" -and
    [string]$contract.matrix_stage_id -ceq
        "finite_three_engine_confirmation_recovery" -and
    [string]$contract.inherited_temporal_policy_id -ceq
        "sporespore_tight_gated_acquisition_active600_v1" -and
    [bool]$science.changed_from_r23d14 -eq $false -and
    [int]$science.controller_step_count -eq 2992 -and
    [int]$science.terminal_step_count -eq 960 -and
    [int]$science.total_trace_row_count_per_cell -eq 3952 -and
    [int]$science.maximum_active_step_count -eq 600 -and
    [int]$science.minimum_taper_step_count -eq 120 -and
    [int]$science.minimum_passive_step_count -eq 360 -and
    [double]$science.coarse_maximum_torso_tilt_rad -eq 0.035 -and
    [double]$science.coarse_maximum_joint_position_error_rad -eq 0.32 -and
    [double]$science.tight_maximum_torso_tilt_rad -eq 0.01 -and
    [double]$science.tight_maximum_joint_position_error_rad -eq 0.2 -and
    [int]$science.new_tunable_gain_count -eq 0 -and
    [int]$science.new_decision_threshold_count -eq 0 -and
    [string]$trace.trace_schema -ceq
        "sporespore_qsdk_r23d15_physical_trace_v1" -and
    [string]$trace.row_schema -ceq
        "sporespore_qsdk_r23d15_physical_trace_row_v1" -and
    [int]$trace.declared_trace_identity_count -eq 9 -and
    [int]$trace.trace_test_count -eq 6 -and
    [bool]$trace.all_nine_synthetic_traces_replayed -and
    [bool]$trace.inherited_r23d14_temporal_oracle_unchanged -and
    [bool]$retention.content_addressed_before_terminal_entry -and
    [bool]$retention.production_evidence_override_forbidden -and
    [bool]$retention.test_override_requires_test_only -and
    [int]$evaluator.evaluator_test_count -eq 7 -and
    [int]$evaluator.retained_test_trace_identity_count -eq 10 -and
    [string]$evaluator.complete_success_marker -ceq
        "QSDK_R23D15_COMPLETE_EVALUATION " -and
    [bool]$evaluator.valid_positive_negative_and_invalid_preserved -and
    [bool]$evaluator.all_nine_ordered_cells_required -and
    [bool]$evaluator.formal_equivalence_inference_performed -eq $false -and
    [int]$contract.physical_worker_count -eq 0 -and
    [int]$contract.physical_process_launch_count -eq 0 -and
    [int]$contract.model_construction_count -eq 0 -and
    [int]$contract.world_attempt_count -eq 0 -and
    [int]$contract.world_build_count -eq 0 -and
    [bool]$contract.physical_execution_authorized -eq $false -and
    [bool]$claims.command_conditioned_turning -eq $false -and
    [bool]$claims.cross_engine_equivalence -eq $false -and
    [bool]$claims.prone_to_standing -eq $false -and
    [bool]$claims.release_authorized -eq $false -and
    [bool]$claims.physical_acceptance_authority -eq $false
) "QSDK-R23D15 stage-one evidence contract boundary changed"

& $stageZeroClosureAudit
Assert-R23D15StageOne ($LASTEXITCODE -eq 0) (
    "QSDK-R23D15 stage-zero closure audit failed"
)
& $provenanceAudit
Assert-R23D15StageOne ($LASTEXITCODE -eq 0) (
    "QSDK-R23D15 CEP1 provenance audit failed"
)

Push-Location -LiteralPath $turningRoot
try {
    & python -m unittest -v `
        test_r23d15_physical_trace.py `
        test_r23d15_physical_evaluator.py
    Assert-R23D15StageOne ($LASTEXITCODE -eq 0) (
        "QSDK-R23D15 stage-one trace/evaluator tests failed"
    )
} finally {
    Pop-Location
}

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d15_stage_one_evidence_gate_v1"
    source_binding_count = $bindings.Count
    trace_test_count = 6
    evaluator_test_count = 7
    complete_test_count = 13
    declared_trace_identity_count = 9
    trace_rows_per_identity = 3952
    retained_test_trace_identity_count = 10
    physical_worker_count = 0
    physical_process_launch_count = 0
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    turning = $false
    equivalence = $false
    physical_acceptance_authority = $false
}
Write-Host (
    "QSDK_R23D15_STAGE_ONE_EVIDENCE_PASS " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
