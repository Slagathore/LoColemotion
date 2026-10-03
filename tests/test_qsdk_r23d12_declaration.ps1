#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$turningRoot = Join-Path $sdkRoot "turning"
$declarationPath = Join-Path $turningRoot "r23d12_measurement_semantics_preregistration_v1.json"
$oraclePath = Join-Path $turningRoot "r23d12_measurement_semantics.py"
$oracleTestPath = Join-Path $turningRoot "test_r23d12_measurement_semantics.py"
$predecessorClosurePath = Join-Path $turningRoot "r23d11_physical_closure_v1.json"
$predecessorAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d11_closure.ps1"

function Assert-R23D12Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D12Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

foreach ($path in @(
    $declarationPath,
    $oraclePath,
    $oracleTestPath,
    $predecessorClosurePath,
    $predecessorAuditPath
)) {
    Assert-R23D12Exact (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D12 required source is missing: $path"
    )
}

$declaration = Get-Content -LiteralPath $declarationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D12Exact (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d12_measurement_semantics_preregistration_v1" -and
    [string]$declaration.status -ceq
        "prospectively_frozen_stage_zero_zero_world_only" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D12" -and
    [string]$declaration.release_gate_id -ceq "QSDK-R23" -and
    [string]$declaration.study_classification -ceq
        "prospective_exact_finite_implementation_recovery_screen_after_consumed_infrastructure_invalid_campaign"
) "QSDK-R23D12 declaration identity changed"

$lineage = $declaration.lineage
Assert-R23D12Exact (
    [string]$lineage.immutable_predecessor_gate_id -ceq "QSDK-R23D11" -and
    [string]$lineage.predecessor_physical_source_commit -ceq
        "2477b6bece55a31257b1306a64330f59633b6c58" -and
    [string]$lineage.predecessor_closure_commit -ceq
        "a873b54ec60e3435c09714c09c78ba848cfa47d8" -and
    [bool]$lineage.predecessor_same_identity_rerun_forbidden -and
    -not [bool]$lineage.predecessor_scientific_positive -and
    -not [bool]$lineage.predecessor_scientific_negative -and
    -not [bool]$lineage.predecessor_physics_outcome_interpretable -and
    [int]$lineage.predecessor_stage_a_world_count -eq 2 -and
    [int]$lineage.predecessor_stage_b_world_count -eq 0 -and
    (Get-R23D12Sha256 -Path $predecessorClosurePath) -ceq
        [string]$lineage.predecessor_closure_raw_sha256 -and
    (Get-R23D12Sha256 -Path $predecessorAuditPath) -ceq
        [string]$lineage.predecessor_closure_audit_raw_sha256
) "QSDK-R23D12 immutable predecessor boundary changed"

$use = $declaration.declared_use_of_predecessor_data
Assert-R23D12Exact (
    [bool]$use.development_informed -and
    -not [bool]$use.independent_validation -and
    [int]$use.retained_trace_row_count -eq 7784 -and
    [int]$use.diagnostic_failure_row_count -eq 1832 -and
    [int]$use.diagnostic_failure_class_count -eq 1 -and
    [string]$use.failure_class -ceq "R23D11_TRACE_DIAGNOSTICS" -and
    -not [bool]$use.physics_outcome_reinterpreted -and
    -not [bool]$use.post_hoc_projection_promoted_to_evidence -and
    -not [bool]$use.controller_gain_or_threshold_fit_to_r23d11 -and
    -not [bool]$use.counterfactual_success_claimed
) "QSDK-R23D12 predecessor-data use changed"

$successor = $declaration.distinct_successor_boundary
Assert-R23D12Exact (
    [bool]$successor.new_campaign_identity -and
    [bool]$successor.fresh_worlds_required -and
    [bool]$successor.r23d11_attempt_or_trace_replay_as_new_evidence_forbidden -and
    -not [bool]$successor.physical_policy_changed -and
    -not [bool]$successor.fixture_changed -and
    -not [bool]$successor.morphology_changed -and
    -not [bool]$successor.turning_controller_changed -and
    -not [bool]$successor.terminal_controller_changed -and
    -not [bool]$successor.scientific_threshold_changed -and
    -not [bool]$successor.selector_changed -and
    -not [bool]$successor.stage_topology_changed -and
    [bool]$successor.trace_schema_changed -and
    [bool]$successor.diagnostic_validation_semantics_changed -and
    [int]$successor.new_decision_threshold_count -eq 0 -and
    -not [bool]$successor.marker_only_same_identity_rerun
) "QSDK-R23D12 distinct-successor boundary changed"

$schema = $declaration.prospective_diagnostic_schema
Assert-R23D12Exact (
    [string]$schema.new_field -ceq
        "minimum_dynamic_support_margin_availability" -and
    (@($schema.planner_availability_active_values) -join "|") -ceq
        "available|observation_unavailable|planning_infeasible" -and
    $null -eq $schema.planner_availability_passive_value -and
    (@($schema.support_margin_availability_values) -join "|") -ceq
        "measured|measurement_unavailable" -and
    [bool]$schema.planner_availability_may_not_determine_support_margin_availability -and
    [bool]$schema.support_margin_availability_may_not_determine_planner_availability -and
    [bool]$schema.observation_unavailable_with_measured_finite_margin_is_valid -and
    [bool]$schema.diagnostics_add_no_outcome_threshold -and
    [bool]$schema.diagnostics_add_no_actuation_command
) "QSDK-R23D12 diagnostic schema changed"

$oracle = $declaration.pure_measurement_semantics_oracle
Assert-R23D12Exact (
    (Get-R23D12Sha256 -Path $oraclePath) -ceq [string]$oracle.source_raw_sha256 -and
    (Get-R23D12Sha256 -Path $oracleTestPath) -ceq [string]$oracle.test_raw_sha256 -and
    [int]$oracle.declared_valid_canary_count -eq 7 -and
    [int]$oracle.declared_active_cross_product_count -eq 6 -and
    [int]$oracle.declared_mutation_control_count -eq 14 -and
    [bool]$oracle.deterministic_receipt_required -and
    [int]$oracle.world_build_count -eq 0
) "QSDK-R23D12 measurement-semantics oracle changed"

$stageZero = $declaration.stage_zero_authority
$claims = $declaration.claim_boundary
Assert-R23D12Exact (
    [bool]$stageZero.declaration_complete -and
    [bool]$stageZero.measurement_semantics_oracle_complete -and
    [int]$stageZero.native_engine_route_count -eq 0 -and
    [int]$stageZero.physical_worker_count -eq 0 -and
    [int]$stageZero.evaluator_implementation_count -eq 0 -and
    [int]$stageZero.supervisor_implementation_count -eq 0 -and
    [int]$stageZero.physical_process_launch_count -eq 0 -and
    [int]$stageZero.model_construction_count -eq 0 -and
    [int]$stageZero.world_attempt_count -eq 0 -and
    [int]$stageZero.world_build_count -eq 0 -and
    -not [bool]$stageZero.physical_execution_authorized -and
    [bool]$claims.stage_zero_design_complete -and
    -not [bool]$claims.measurement_semantics_physically_tested -and
    -not [bool]$claims.stage_a_result_exists -and
    -not [bool]$claims.stage_b_result_exists -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.bilateral_signed_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D12 stage-zero claim boundary changed"

$allowedR23D12Paths = @(
    "sdk/turning/r23d12_measurement_semantics.py",
    "sdk/turning/r23d12_measurement_semantics_preregistration_v1.json",
    "sdk/turning/test_r23d12_measurement_semantics.py",
    "sdk/run_qsdk_r23d12_stage_zero_gate.ps1",
    "tests/test_qsdk_r23d12_declaration.ps1"
) | Sort-Object
$actualR23D12Paths = @(
    git -C $repoRoot ls-files --cached --others --exclude-standard |
        Where-Object { [IO.Path]::GetFileName($_) -match "r23d12" } |
        Sort-Object
)
Assert-R23D12Exact (
    ($actualR23D12Paths -join "|") -ceq ($allowedR23D12Paths -join "|")
) "QSDK-R23D12 stage-zero unexpectedly contains a future route"

$predecessorOutput = @(
    & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File $predecessorAuditPath 2>&1
) -join "`n"
Assert-R23D12Exact (
    $LASTEXITCODE -eq 0 -and
    $predecessorOutput.Contains("QSDK_R23D11_CLOSURE_PASS") -and
    $predecessorOutput.Contains("same_identity_rerun=False") -and
    $predecessorOutput.Contains("scientific_result=False")
) "QSDK-R23D12 predecessor closure audit did not pass"

$pythonOutput = @(
    & $Python -m unittest sdk.turning.test_r23d12_measurement_semantics -v 2>&1
) -join "`n"
Assert-R23D12Exact (
    $LASTEXITCODE -eq 0 -and
    $pythonOutput.Contains("Ran 4 tests") -and
    $pythonOutput.Contains("OK")
) "QSDK-R23D12 pure measurement-semantics tests failed"
$global:LASTEXITCODE = 0

Write-Host (
    "QSDK_R23D12_DECLARATION_PASS canaries=7 cross_product=6 mutations=14 " +
    "predecessor_worlds=2 fresh_worlds=0 native_routes=0 workers=0 " +
    "models=0 worlds=0 turning=False equivalence=False physical_authority=False"
)
