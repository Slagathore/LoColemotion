#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$predecessorPath = Join-Path $turningRoot (
    "r23d41_three_engine_startup_ramp_turning_closure_v1.json"
)
$preregistrationPath = Join-Path $turningRoot (
    "r23d42_three_engine_startup_ramp_turning_preregistration_v1.json"
)
$expectedPredecessorHash = (
    "sha256:d3160ffabc7dfb9f697fcc55f1e9efb827cc5316647543d9b6841d994fda6ba4"
)

function Assert-R23D42Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D42 LINEAGE: $Message" }
}

function Get-R23D42Hash([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D42Lineage (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$predecessor = Get-Content -Raw -LiteralPath $predecessorPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$lineage = $preregistration.immutable_lineage
$successor = $preregistration.scientifically_distinct_successor
$failure = $predecessor.implementation_failure

Assert-R23D42Lineage (
    (Get-R23D42Hash $predecessorPath) -ceq $expectedPredecessorHash -and
    [string]$lineage.trace_interface_invalid_predecessor_closure_raw_sha256 -ceq
        $expectedPredecessorHash -and
    [string]$lineage.trace_interface_invalid_predecessor_closure_path -ceq
        "sdk/turning/r23d41_three_engine_startup_ramp_turning_closure_v1.json"
) "R41 predecessor bytes or binding changed"

Assert-R23D42Lineage (
    [string]$predecessor.status -ceq
        "closed_consumed_invalid_complete_trace_interfaces_with_valid_mujoco_turning_positive" -and
    [bool]$predecessor.identity_consumed -and
    -not [bool]$predecessor.same_identity_rerun_allowed -and
    [bool]$failure.successor_must_use_fresh_seed -and
    [bool]$failure.successor_must_exercise_each_exact_production_trace_retention_path_before_world -and
    [string]$failure.rapier_mechanism -ceq
        "worker_invoked_r23d41_evaluator_retain_trace_with_undeclared_source_root_argument_instead_of_declared_repo_root" -and
    [string]$failure.godot_jolt_mechanism -ceq
        "all_physical_rows_retained_old_r23d3_trace_schema_instead_of_declared_r23d41_trace_schema" -and
    -not [bool]$predecessor.claims.finite_three_engine_turning -and
    -not [bool]$predecessor.claims.cross_engine_equivalence
) "R41 result or repair obligation changed"

Assert-R23D42Lineage (
    [string]$preregistration.status -ceq "prospective_zero_world_only" -and
    [int]$preregistration.frozen_matrix.seed -eq 21510 -and
    [int]$preregistration.frozen_matrix.declared_world_count -eq 9 -and
    [bool]$preregistration.frozen_matrix.serial_execution_required -and
    [bool]$preregistration.frozen_matrix.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$lineage.r23d41_identity_consumed -and
    -not [bool]$lineage.r23d41_same_identity_rerun_permitted -and
    [int]$successor.fresh_held_out_seed -eq 21510 -and
    [bool]$successor.fresh_held_out_condition_selected -and
    -not [bool]$successor.outcome_exposed_before_preregistration -and
    [bool]$successor.rapier_retain_trace_cli_contract_fixed -and
    [bool]$successor.godot_trace_row_schema_caller_declaration_fixed -and
    -not [bool]$successor.physics_or_controller_behavior_changed -and
    -not [bool]$preregistration.claims.finite_three_engine_turning -and
    -not [bool]$preregistration.claims.cross_engine_equivalence
) "prospective R42 boundary changed"

Write-Host (
    "QSDK_R23D42_LINEAGE_PASS predecessor=R23D41 seed=21510 worlds=9 " +
    "repairs=2 controller_changes=0 physical=False"
)
