#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$predecessorPath = Join-Path $turningRoot (
    "r23d48_support_loss_conditioned_three_engine_turning_closure_v1.json"
)
$preregistrationPath = Join-Path $turningRoot (
    "r23d49_rapier_retention_repair_replay_preregistration_v1.json"
)
$expectedPredecessorHash = (
    "sha256:5b2ce3553a78836035c6a7b6ff11ee585cb615f0ebcc70341902e7bca58b7063"
)

function Assert-R23D49Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D49 LINEAGE: $Message" }
}

function Get-R23D49Hash([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D49Lineage (
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
$repair = $preregistration.implementation_repair_boundary
$matrix = $preregistration.frozen_matrix
$measurement = $preregistration.cycle_integrated_measurement

Assert-R23D49Lineage (
    (Get-R23D49Hash $predecessorPath) -ceq $expectedPredecessorHash -and
    [string]$lineage.r23d48_closure_raw_sha256 -ceq $expectedPredecessorHash -and
    [string]$lineage.r23d48_closure_path -ceq
        "sdk/turning/r23d48_support_loss_conditioned_three_engine_turning_closure_v1.json"
) "R48 closure binding changed"

Assert-R23D49Lineage (
    [bool]$predecessor.identity_consumed -and
    -not [bool]$predecessor.same_identity_rerun_allowed -and
    [string]$predecessor.official_disposition.classification -ceq
        "invalid_or_incomplete_three_engine_portable_turning_validation" -and
    [int]$predecessor.physical_evidence.observed_world_build_count -eq 9 -and
    [int]$predecessor.physical_evidence.official_worker_failure_cell_count -eq 3 -and
    [bool]$lineage.r23d48_identity_consumed -and
    -not [bool]$lineage.r23d48_same_identity_rerun_permitted -and
    [bool]$lineage.r23d48_rapier_outcomes_exposed_before_this_preregistration -and
    -not [bool]$lineage.r23d48_godot_negative_reinterpreted -and
    -not [bool]$lineage.r23d48_mujoco_positive_reinterpreted -and
    -not [bool]$lineage.historical_world_reused_as_a_new_cell -and
    -not [bool]$lineage.same_identity_rerun_permitted
) "R48 consumed negative and no-rerun boundary changed"

Assert-R23D49Lineage (
    [string]$preregistration.status -ceq "prospective_zero_world_only" -and
    [string]$preregistration.study_classification -ceq
        "prospective_exact_outcome_exposed_rapier_evidence_implementation_repair_replay" -and
    [string]$repair.single_permitted_change -ceq
        "Invoke the exact pinned publisher with -ExecutionPolicy Bypass in that child process only." -and
    [bool]$repair.exact_rust_to_python_to_powershell_to_cas_canary_required_before_first_world -and
    [bool]$repair.production_evidence_root_required_for_canary -and
    [int]$repair.synthetic_trace_row_count -eq 2992 -and
    -not [bool]$repair.controller_behavior_changed -and
    -not [bool]$repair.physics_or_adapter_actuation_changed -and
    -not [bool]$repair.startup_transform_changed -and
    -not [bool]$repair.fixture_or_seed_changed -and
    -not [bool]$repair.command_schedule_changed -and
    -not [bool]$repair.measurement_changed -and
    -not [bool]$repair.physical_threshold_changed -and
    -not [bool]$repair.other_implementation_changes_permitted
) "single-change implementation-repair boundary changed"

Assert-R23D49Lineage (
    @($matrix.ordered_engine_ids).Count -eq 1 -and
    [string]$matrix.ordered_engine_ids[0] -ceq "rapier_parry" -and
    [int]$matrix.declared_cell_count -eq 3 -and
    [int]$matrix.declared_world_count -eq 3 -and
    [int]$matrix.seed -eq 21512 -and
    [bool]$matrix.seed_was_outcome_exposed_before_preregistration -and
    [string]$matrix.startup_transform_id -ceq
        "support_loss_latched_smoothstep_one_cycle_v1" -and
    [bool]$matrix.serial_execution_required -and
    [bool]$matrix.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$measurement.inherited_unchanged_from_r23d31 -and
    -not [bool]$measurement.threshold_changed_from_r23d48 -and
    -not [bool]$preregistration.claims.fresh_rapier_turning_replication -and
    -not [bool]$preregistration.claims.finite_three_engine_turning -and
    -not [bool]$preregistration.claims.cross_engine_equivalence
) "outcome-exposed exact replay boundary changed"

Write-Host (
    "QSDK_R23D49_LINEAGE_PASS predecessor=R23D48 seed=21512 worlds=3 " +
    "controller_changes=0 evidence_repairs=1 physical=False"
)
