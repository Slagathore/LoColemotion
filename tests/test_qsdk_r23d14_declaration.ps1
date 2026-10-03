#requires -Version 7.0

[CmdletBinding()]
param([string]$Python = "python")

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$declarationPath = Join-Path $turningRoot (
    "r23d14_tight_gated_horizon_preregistration_v1.json"
)
$oraclePath = Join-Path $turningRoot "r23d14_tight_gated_horizon.py"
$oracleTestPath = Join-Path $turningRoot "test_r23d14_tight_gated_horizon.py"
$stageZeroGatePath = Join-Path $repoRoot "sdk\run_qsdk_r23d14_stage_zero_gate.ps1"

function Assert-R23D14([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D14Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Resolve-R23D14Path([string]$Relative) {
    return Join-Path $repoRoot $Relative.Replace("/", "\")
}

function Assert-R23D14Array(
    [object[]]$Actual, [object[]]$Expected, [string]$Message
) {
    Assert-R23D14 (
        ($Actual | ConvertTo-Json -Compress -Depth 20) -ceq
        ($Expected | ConvertTo-Json -Compress -Depth 20)
    ) $Message
}

$root = (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\")
$origin = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D14 (
    $root -ceq "C:\Users\Cole\CodeStuff\games\SporeSpore" -and
    $origin -ceq "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D14 repository identity mismatch"

foreach ($path in @(
    $declarationPath, $oraclePath, $oracleTestPath, $stageZeroGatePath
)) {
    Assert-R23D14 (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D14 required source is missing: $path"
    )
}
$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D14 (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d14_tight_gated_horizon_preregistration_v1" -and
    [string]$declaration.status -ceq
        "prospectively_frozen_stage_zero_zero_world_only" -and
    [string]$declaration.campaign_id -ceq
        "QSDK-R23D14-TIGHT-GATED-HORIZON-THREE-ENGINE-TURN-CONFIRMATION" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D14" -and
    [string]$declaration.release_gate_id -ceq "QSDK-R23" -and
    [string]$declaration.study_classification -ceq
        "prospective_exact_finite_three_engine_confirmation_after_outcome_visible_mujoco_development_selection"
) "QSDK-R23D14 declaration identity changed"

$lineage = $declaration.lineage
$predecessorPath = Resolve-R23D14Path $lineage.predecessor_closure_path
$predecessorAudit = Resolve-R23D14Path $lineage.predecessor_closure_audit_path
$predecessor = Get-Content -Raw -LiteralPath $predecessorPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D14 (
    [string]$lineage.immutable_predecessor_gate_id -ceq "QSDK-R23D13" -and
    [string]$lineage.predecessor_physical_source_commit -ceq
        "2283625319c1d082082f584d288511d403608952" -and
    [string]$lineage.predecessor_closure_commit -ceq
        "78e01b8b9f046490f11e2438f612c7b35d7c3fdc" -and
    [bool]$lineage.predecessor_same_identity_rerun_forbidden -and
    [bool]$lineage.predecessor_scientific_negative -and
    [string]$lineage.predecessor_selected_terminal_policy_id -ceq "NONE" -and
    [int]$lineage.predecessor_stage_a_world_count -eq 2 -and
    [int]$lineage.predecessor_stage_b_world_count -eq 0 -and
    (Get-R23D14Sha256 $predecessorPath) -ceq
        [string]$lineage.predecessor_closure_raw_sha256 -and
    (Get-R23D14Sha256 $predecessorAudit) -ceq
        [string]$lineage.predecessor_closure_audit_raw_sha256 -and
    [string]$predecessor.status -ceq
        "closed_consumed_valid_none_stage_a_negative_heading_quiescent_taper_failure" -and
    [string]$predecessor.source_identity.commit -ceq
        [string]$lineage.predecessor_physical_source_commit -and
    [string]$predecessor.immutable_completion_record.selected_terminal_policy_id -ceq
        "NONE" -and
    [int]$predecessor.attempt.stage_b_worker_process_count -eq 0
) "QSDK-R23D14 immutable predecessor boundary changed"

$selection = $declaration.development_selection_lineage
foreach ($binding in @(
    [ordered]@{
        path = $selection.threshold_provenance_audit_path
        sha = $selection.threshold_provenance_audit_raw_sha256
    },
    [ordered]@{
        path = $selection.first_candidate_closure_path
        sha = $selection.first_candidate_closure_raw_sha256
    },
    [ordered]@{
        path = $selection.first_candidate_closure_audit_path
        sha = $selection.first_candidate_closure_audit_raw_sha256
    },
    [ordered]@{
        path = $selection.selected_candidate_closure_path
        sha = $selection.selected_candidate_closure_raw_sha256
    },
    [ordered]@{
        path = $selection.selected_candidate_closure_audit_path
        sha = $selection.selected_candidate_closure_audit_raw_sha256
    }
)) {
    $path = Resolve-R23D14Path ([string]$binding.path)
    Assert-R23D14 (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-R23D14Sha256 $path) -ceq [string]$binding.sha
    ) "QSDK-R23D14 development lineage changed: $([string]$binding.path)"
}
$first = Get-Content -Raw -LiteralPath (
    Resolve-R23D14Path $selection.first_candidate_closure_path
) | ConvertFrom-Json -AsHashtable -Depth 100
$selected = Get-Content -Raw -LiteralPath (
    Resolve-R23D14Path $selection.selected_candidate_closure_path
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D14 (
    -not [bool]$selection.threshold_rewrite_authorized -and
    [string]$selection.first_candidate_result -ceq
        "near_miss_not_selected_as_complete_candidate" -and
    -not [bool]$first.claims.candidate_selection_complete -and
    [string]$selection.selected_candidate_id -ceq
        "tight_gated_acquisition_active600_v2" -and
    [string]$selection.selected_policy_id -ceq
        "sporespore_tight_gated_acquisition_active600_v1" -and
    [int]$selection.selected_development_world_count -eq 2 -and
    [int]$selection.selected_development_pass_count -eq 2 -and
    [bool]$selected.claims.candidate_selection_complete -and
    [bool]$selection.successor_design_authorized -and
    -not [bool]$selection.successor_physical_execution_authorized
) "QSDK-R23D14 development selection boundary changed"

$use = $declaration.declared_use_of_development_data
Assert-R23D14 (
    [bool]$use.development_informed -and
    [bool]$use.outcomes_were_visible_before_this_declaration -and
    -not [bool]$use.independent_validation -and
    [int]$use.positive_first_tight_active_index -eq 318 -and
    [int]$use.positive_confirmed_handoff_after_active_index -eq 438 -and
    [int]$use.positive_passive_step_count -eq 521 -and
    [int]$use.negative_first_tight_active_index -eq 459 -and
    [int]$use.negative_confirmed_handoff_after_active_index -eq 579 -and
    [int]$use.negative_passive_step_count -eq 380 -and
    [bool]$use.both_development_screens_passed -and
    [bool]$use.development_outcomes_cannot_satisfy_r23d14 -and
    [bool]$use.fresh_production_worlds_required
) "QSDK-R23D14 disclosed development-data use changed"

$distinct = $declaration.scientifically_distinct_successor
Assert-R23D14 (
    [bool]$distinct.new_campaign_identity -and
    [bool]$distinct.fresh_worlds_required -and
    -not [bool]$distinct.fixture_changed -and
    -not [bool]$distinct.morphology_changed -and
    -not [bool]$distinct.walking_turning_controller_changed -and
    -not [bool]$distinct.r23d13_residual_pose_authority_changed -and
    [bool]$distinct.tight_pose_gates_taper_entry_and_continuation -and
    [bool]$distinct.tight_pose_loss_resets_full_acquisition -and
    [int]$distinct.maximum_active_step_count_changed_from -eq 540 -and
    [int]$distinct.maximum_active_step_count_changed_to -eq 600 -and
    [int]$distinct.terminal_step_count_changed_from -eq 900 -and
    [int]$distinct.terminal_step_count_changed_to -eq 960 -and
    -not [bool]$distinct.minimum_confirmed_taper_step_count_changed -and
    -not [bool]$distinct.minimum_passive_step_count_changed -and
    -not [bool]$distinct.walking_turning_or_pose_threshold_changed -and
    [int]$distinct.new_tunable_gain_count -eq 0 -and
    [int]$distinct.new_decision_threshold_count -eq 0 -and
    -not [bool]$distinct.arm_identity_or_command_sign_is_control_input -and
    -not [bool]$distinct.marker_only_same_policy_rerun
) "QSDK-R23D14 scientific distinction changed"

$temporal = $declaration.terminal_policy_contract
Assert-R23D14 (
    (Get-R23D14Sha256 $oraclePath) -ceq [string]$temporal.source_raw_sha256 -and
    [string]$temporal.policy_id -ceq
        "sporespore_tight_gated_acquisition_active600_v1" -and
    [int]$temporal.terminal_step_count -eq 960 -and
    [int]$temporal.maximum_active_step_count -eq 600 -and
    [int]$temporal.minimum_quiescent_taper_step_count -eq 120 -and
    [int]$temporal.minimum_passive_step_count -eq 360 -and
    [double]$temporal.coarse_maximum_torso_tilt_rad -eq 0.035 -and
    [double]$temporal.coarse_maximum_joint_position_error_rad -eq 0.32 -and
    [double]$temporal.tight_maximum_torso_tilt_rad -eq 0.01 -and
    [double]$temporal.tight_maximum_joint_position_error_rad -eq 0.2 -and
    [bool]$temporal.taper_entry_requires_tight_pose -and
    [bool]$temporal.every_taper_step_requires_tight_pose -and
    [bool]$temporal.tight_pose_loss_resets_to_full_acquisition -and
    -not [bool]$temporal.deadline_forced_handoff_can_pass -and
    -not [bool]$temporal.mode_reactivation_after_passive_handoff_permitted -and
    [bool]$temporal.every_post_handoff_step_requires_all_four_contacts -and
    [bool]$temporal.every_post_handoff_step_requires_zero_native_actuation -and
    [bool]$temporal.all_960_terminal_steps_execute
) "QSDK-R23D14 temporal contract changed"

$composition = $declaration.inherited_whole_body_composition
$residual = $declaration.inherited_residual_pose_authority
foreach ($binding in @(
    [ordered]@{ path = $composition.preregistration_path; sha = $composition.preregistration_raw_sha256 },
    [ordered]@{ path = $composition.oracle_path; sha = $composition.oracle_raw_sha256 },
    [ordered]@{ path = $residual.preregistration_path; sha = $residual.preregistration_raw_sha256 },
    [ordered]@{ path = $residual.oracle_path; sha = $residual.oracle_raw_sha256 }
)) {
    Assert-R23D14 (
        (Get-R23D14Sha256 (Resolve-R23D14Path $binding.path)) -ceq
            [string]$binding.sha
    ) "QSDK-R23D14 inherited controller dependency changed: $($binding.path)"
}
Assert-R23D14 (
    [int]$composition.ordered_actuator_count -eq 8 -and
    [double]$composition.maximum_pre_taper_combined_velocity_magnitude_rad_s -eq
        0.425 -and
    [bool]$composition.complete_neutral_plus_stability_command_is_feedback_scaled -and
    [bool]$composition.host_mapping_applied_once_after_feedback_scale -and
    [int]$residual.scale_denominator -eq 120 -and
    [bool]$residual.authority_floor_may_never_reduce_temporal_authority -and
    [bool]$residual.recovery_may_never_reactivate_after_passive_handoff -and
    -not [bool]$residual.arm_identity_heading_sign_or_outcome_branching
) "QSDK-R23D14 inherited controller composition changed"

$oracle = $declaration.pure_zero_world_oracle
Assert-R23D14 (
    (Get-R23D14Sha256 $oraclePath) -ceq [string]$oracle.source_raw_sha256 -and
    (Get-R23D14Sha256 $oracleTestPath) -ceq [string]$oracle.test_raw_sha256 -and
    [int]$oracle.declared_canary_count -eq 12 -and
    [int]$oracle.declared_mutation_control_count -eq 14 -and
    [int]$oracle.new_tunable_gain_count -eq 0 -and
    [int]$oracle.native_engine_route_count -eq 0 -and
    [int]$oracle.world_build_count -eq 0
) "QSDK-R23D14 pure zero-world oracle changed"

$matrix = $declaration.finite_three_engine_confirmation
Assert-R23D14Array @($matrix.ordered_engine_ids) @(
    "godot_jolt", "rapier_parry", "mujoco"
) "QSDK-R23D14 engine order changed"
Assert-R23D14Array @($matrix.ordered_arm_ids) @(
    "reference_zero", "positive_heading", "negative_heading"
) "QSDK-R23D14 arm order changed"
Assert-R23D14 (
    [int]$matrix.declared_cell_count -eq 9 -and
    [int]$matrix.declared_world_count -eq 9 -and
    [bool]$matrix.all_cells_execute_without_outcome_based_early_stop -and
    -not [bool]$matrix.parallel_execution_permitted -and
    -not [bool]$matrix.replacement_or_selective_rerun_permitted -and
    [bool]$matrix.reference_zero_requires_zero_command_straight_walk_compatibility -and
    [bool]$matrix.positive_and_negative_require_correct_signed_yaw -and
    [bool]$matrix.every_cell_requires_complete_walking_and_confirmed_handoff_conjunction -and
    [bool]$matrix.complete_nine_report_aggregate_required -and
    [bool]$matrix.finite_positive_may_satisfy_q_sdk_r23 -and
    [bool]$matrix.finite_positive_does_not_establish_population_robustness -and
    [bool]$matrix.finite_positive_does_not_establish_cross_engine_equivalence
) "QSDK-R23D14 finite confirmation topology changed"

$authority = $declaration.stage_zero_authority
$claims = $declaration.claim_boundary
Assert-R23D14 (
    [bool]$authority.declaration_complete -and
    [bool]$authority.pure_temporal_oracle_complete -and
    [int]$authority.native_engine_route_count -eq 0 -and
    [int]$authority.physical_worker_count -eq 0 -and
    [int]$authority.evaluator_implementation_count -eq 0 -and
    [int]$authority.supervisor_implementation_count -eq 0 -and
    [int]$authority.physical_process_launch_count -eq 0 -and
    [int]$authority.model_construction_count -eq 0 -and
    [int]$authority.world_attempt_count -eq 0 -and
    [int]$authority.world_build_count -eq 0 -and
    -not [bool]$authority.physical_execution_authorized -and
    [bool]$claims.stage_zero_design_complete -and
    -not [bool]$claims.selected_policy_physically_confirmed_under_r23d14 -and
    -not [bool]$claims.finite_three_engine_result_exists -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.bilateral_signed_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D14 stage-zero authority or claims changed"

$allowed = @(
    "sdk/run_qsdk_r23d14_stage_zero_gate.ps1",
    "sdk/turning/r23d14_tight_gated_horizon.py",
    "sdk/turning/r23d14_tight_gated_horizon_preregistration_v1.json",
    "sdk/turning/test_r23d14_tight_gated_horizon.py",
    "tests/test_qsdk_r23d14_declaration.ps1"
) | Sort-Object
$actual = @(
    git -C $repoRoot ls-files --cached --others --exclude-standard |
        Where-Object { [IO.Path]::GetFileName($_) -match "r23d14" } |
        Sort-Object
)
Assert-R23D14 (($actual -join "|") -ceq ($allowed -join "|")) (
    "QSDK-R23D14 stage zero unexpectedly contains a future route: " +
    ($actual -join "|")
)

$pythonOutput = @(
    & $Python -m unittest sdk.turning.test_r23d14_tight_gated_horizon -v 2>&1
) -join "`n"
Assert-R23D14 (
    $LASTEXITCODE -eq 0 -and
    $pythonOutput.Contains("Ran 6 tests") -and
    $pythonOutput.Contains("OK")
) "QSDK-R23D14 pure temporal-oracle tests failed: $pythonOutput"
$global:LASTEXITCODE = 0

Write-Host (
    "QSDK_R23D14_DECLARATION_PASS canaries=12 mutations=14 gains=0 " +
    "development_worlds=2 confirmation_cells=9 fresh_worlds=0 " +
    "native_routes=0 workers=0 models=0 worlds=0 turning=False " +
    "equivalence=False physical_authority=False"
)
