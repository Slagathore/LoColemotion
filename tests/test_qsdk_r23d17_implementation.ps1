#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$contractPath = Join-Path $repoRoot (
    "sdk\turning\r23d17_physical_implementation_contract_v1.json"
)
$preregistrationPath = Join-Path $repoRoot (
    "sdk\turning\r23d17_live_composition_recovery_preregistration_v1.json"
)

function Assert-R23D17Implementation {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D17ImplementationRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D17ImplementationSource {
    param([Parameter(Mandatory)][string]$RelativePath)
    $path = Join-Path $repoRoot ($RelativePath.Replace("/", "\"))
    Assert-R23D17Implementation (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D17 implementation source missing: $RelativePath"
    )
    return Get-Content -Raw -LiteralPath $path
}

Assert-R23D17Implementation (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq $expectedRemote
) "QSDK-R23D17 implementation repository identity changed"

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D17Implementation (
    $contract.schema_version -ceq
        "sporespore_qsdk_r23d17_physical_implementation_contract_v1" -and
    $contract.status -ceq
        "dormant_physical_implementation_zero_world_only_pending_clean_push_freeze" -and
    $contract.campaign_id -ceq
        "QSDK-R23D17-LIVE-COMPOSITION-RECOVERY-THREE-ENGINE-TURN-CONFIRMATION" -and
    $contract.gate_id -ceq "QSDK-R23D17" -and
    $contract.release_gate_id -ceq "QSDK-R23"
) "QSDK-R23D17 implementation identity changed"

Assert-R23D17Implementation (
    $contract.preregistration_path -ceq
        "sdk/turning/r23d17_live_composition_recovery_preregistration_v1.json" -and
    (Get-R23D17ImplementationRawSha256 $preregistrationPath) -ceq
        $contract.preregistration_raw_sha256 -and
    $preregistration.schema_version -ceq
        "sporespore_qsdk_r23d17_implementation_recovery_preregistration_v1"
) "QSDK-R23D17 preregistration binding changed"

$lineage = $contract.lineage
$lineageFiles = @(
    @{
        path = $lineage.predecessor_closure_path
        digest = $lineage.predecessor_closure_raw_sha256
    },
    @{
        path = $lineage.inherited_temporal_preregistration_path
        digest = $lineage.inherited_temporal_preregistration_raw_sha256
    }
)
foreach ($binding in $lineageFiles) {
    $path = Join-Path $repoRoot ([string]$binding.path).Replace("/", "\")
    Assert-R23D17Implementation (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-R23D17ImplementationRawSha256 $path) -ceq [string]$binding.digest
    ) "QSDK-R23D17 immutable lineage binding changed: $($binding.path)"
}
Assert-R23D17Implementation (
    $lineage.predecessor_gate_id -ceq "QSDK-R23D16" -and
    $lineage.predecessor_physical_source_commit -ceq
        "c645a18917a75e806284080ff7f3936181946f37" -and
    $lineage.predecessor_physical_closure_commit -ceq
        "64a543253fa2a0d89bfc2a6507b88152b854a44c" -and
    [bool]$lineage.predecessor_same_identity_rerun_forbidden -and
    [bool]$lineage.r23d14_tight_gated_horizon_inherited_unchanged -and
    -not [bool]$lineage.new_temporal_controller_created
) "QSDK-R23D17 immutable source lineage changed"

$workers = @($contract.workers)
Assert-R23D17Implementation (
    $workers.Count -eq 3 -and
    (@($workers.engine_id) -join "|") -ceq "mujoco|rapier_parry|godot_jolt"
) "QSDK-R23D17 worker order changed"
$expectedWorkerPaths = @{
    mujoco = @(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d17_physical.py",
        "sdk/adapters/mujoco/test_qsdk_r23d17_physical.py",
        "sdk/run_qsdk_r23d17_mujoco_worker_preflight.ps1",
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d14_tight_gated_horizon.py"
    )
    rapier_parry = @(
        "sdk/adapters/rapier/src/bin/qsdk_r23d17_physical.rs",
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d17_physical.rs",
        "sdk/run_qsdk_r23d17_rapier_worker_preflight.ps1",
        "sdk/adapters/rapier/src/qsdk_r23d14_tight_gated_horizon.rs",
        "sdk/adapters/rapier/src/qsdk_r23d17_composition_recovery.rs"
    )
    godot_jolt = @(
        "tests/test_sdk_qsdk_r23d17_godot_jolt_physical_worker.gd",
        "sdk/run_qsdk_r23d17_godot_jolt_worker_preflight.ps1",
        "scripts/lab/gait/sdk_godot_jolt_r23d14_tight_gated_horizon.gd",
        "scripts/lab/gait/physical_wave_gait_quadruped.gd"
    )
}
foreach ($worker in $workers) {
    Assert-R23D17Implementation (
        (@($worker.stage_scope) -join "|") -ceq
            "finite_three_engine_confirmation_live_composition_recovery" -and
        [int]$worker.declared_identity_count -eq 3 -and
        [bool]$worker.physical_worker_implemented -and
        [int]$worker.physical_world_count_before_freeze -eq 0
    ) "QSDK-R23D17 worker declaration changed: $($worker.engine_id)"
    foreach ($relativePath in @($expectedWorkerPaths[[string]$worker.engine_id])) {
        Assert-R23D17Implementation (
            Test-Path -LiteralPath (
                Join-Path $repoRoot $relativePath.Replace("/", "\")
            ) -PathType Leaf
        ) "QSDK-R23D17 worker path missing: $relativePath"
    }
}

$science = $contract.frozen_scientific_question
Assert-R23D17Implementation (
    -not [bool]$science.changed_from_r23d16 -and
    $science.selected_policy_id -ceq
        "sporespore_tight_gated_acquisition_active600_v1" -and
    [int]$science.controller_step_count -eq 2992 -and
    [int]$science.terminal_step_count -eq 960 -and
    [int]$science.total_trace_row_count_per_cell -eq 3952 -and
    [int]$science.maximum_active_neutral_acquisition_step_count -eq 600 -and
    [int]$science.minimum_confirmed_taper_step_count -eq 120 -and
    [int]$science.minimum_post_handoff_zero_actuation_step_count -eq 360 -and
    [double]$science.coarse_maximum_torso_tilt_rad -eq 0.035 -and
    [double]$science.coarse_maximum_joint_position_error_rad -eq 0.32 -and
    [double]$science.tight_maximum_torso_tilt_rad -eq 0.01 -and
    [double]$science.tight_maximum_joint_position_error_rad -eq 0.20
) "QSDK-R23D17 fixed scientific values changed"
$changedFlags = @(
    "walking_turning_controller_changed", "fixture_changed",
    "morphology_changed", "actuation_mode_changed", "material_profile_changed",
    "threshold_changed", "horizon_changed", "gain_changed",
    "observed_engine_outcomes_used_to_tune_successor"
)
foreach ($name in $changedFlags) {
    Assert-R23D17Implementation (-not [bool]$science[$name]) (
        "QSDK-R23D17 forbidden scientific change enabled: $name"
    )
}

$recovery = $contract.implementation_recovery
Assert-R23D17Implementation (
    $recovery.godot_production_helper_path -ceq
        "scripts/lab/gait/physical_wave_gait_quadruped.gd" -and
    $recovery.godot_production_helper -ceq
        "_sdk_terminal_ordered_actuator_ids" -and
    $recovery.godot_exact_predicate_helper -ceq
        "_sdk_r23d13_trace_authority_input_failure" -and
    [int]$recovery.godot_positive_canary_count -eq 8 -and
    [int]$recovery.godot_mutation_control_count -eq 8 -and
    $recovery.godot_failure_diagnostics_worker_path -ceq
        "tests/test_sdk_qsdk_r23d17_godot_jolt_physical_worker.gd" -and
    $recovery.rapier_evaluator_path -ceq
        "sdk/turning/r23d17_physical_evaluator.py" -and
    $recovery.rapier_child_execution_policy -ceq "Bypass" -and
    $recovery.rapier_publisher_path -ceq
        "sdk/publish_qsdk_r23d17_trace.ps1" -and
    $recovery.rapier_path_identity_helper -ceq
        "ConvertTo-R23D17LocalWindowsPathIdentity" -and
    [int]$recovery.rapier_extended_local_drive_positive_canary_count -eq 1 -and
    [int]$recovery.rapier_ordinary_local_drive_positive_canary_count -eq 1 -and
    [int]$recovery.rapier_wrong_root_mutation_control_count -eq 1 -and
    [int]$recovery.rapier_unsupported_path_kind_mutation_control_count -eq 2 -and
    [int]$recovery.rapier_retained_fixture_row_count -eq 3952 -and
    $recovery.rapier_retained_fixture_raw_sha256 -ceq
        "sha256:4dba3fa814f726823598b07d958238567677a929fbe40fd9dea657c0211089fb" -and
    -not [bool]$recovery.changes_temporal_policy -and
    -not [bool]$recovery.changes_controller_or_physics
) "QSDK-R23D17 implementation recovery changed"

Assert-R23D17Implementation (
    $contract.production_evaluator.path -ceq
        "sdk/turning/r23d17_physical_evaluator.py" -and
    $contract.production_evaluator.trace_schema_version -ceq
        "sporespore_qsdk_r23d17_physical_trace_v1" -and
    $contract.production_evaluator.trace_row_schema_version -ceq
        "sporespore_qsdk_r23d17_physical_trace_row_v1" -and
    -not [bool]$contract.production_evaluator.worker_authored_outcome_bits_authoritative -and
    -not [bool]$contract.production_evaluator.formal_cross_engine_equivalence_inference_performed -and
    [bool]$contract.trace_retention.content_addressed_before_terminal_entry_required -and
    [int]$contract.trace_retention.rows_per_complete_cell -eq 3952 -and
    [int]$contract.trace_retention.projected_trace_rows_for_complete_matrix -eq 35568
) "QSDK-R23D17 evidence contract changed"

$supervisor = $contract.supervisor
$expectedCells = @(
    "godot_jolt__tight_gated_horizon__reference_zero",
    "godot_jolt__tight_gated_horizon__positive_heading",
    "godot_jolt__tight_gated_horizon__negative_heading",
    "rapier_parry__tight_gated_horizon__reference_zero",
    "rapier_parry__tight_gated_horizon__positive_heading",
    "rapier_parry__tight_gated_horizon__negative_heading",
    "mujoco__tight_gated_horizon__reference_zero",
    "mujoco__tight_gated_horizon__positive_heading",
    "mujoco__tight_gated_horizon__negative_heading"
)
Assert-R23D17Implementation (
    $supervisor.path -ceq "sdk/run_qsdk_r23d17_supervisor.ps1" -and
    $supervisor.stage_id -ceq "finite_three_engine_confirmation_live_composition_recovery" -and
    (@($supervisor.ordered_engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    (@($supervisor.ordered_arm_ids) -join "|") -ceq
        "reference_zero|positive_heading|negative_heading" -and
    (@($supervisor.ordered_matrix_cell_ids) -join "|") -ceq
        ($expectedCells -join "|") -and
    [int]$supervisor.declared_world_count -eq 9 -and
    [bool]$supervisor.all_cells_serial_without_outcome_early_stop -and
    -not [bool]$supervisor.parallel_execution_permitted -and
    -not [bool]$supervisor.replacement_or_selective_rerun_permitted -and
    [bool]$supervisor.matrix_authorization_immutable_before_first_world -and
    [bool]$supervisor.evaluator_expected_source_commit_forwarded_from_frozen_source -and
    [bool]$supervisor.every_launched_process_gets_a_content_addressed_terminal_entry
) "QSDK-R23D17 supervisor contract changed"

$freeze = $contract.runtime_freeze
Assert-R23D17Implementation (
    $freeze.schema_version -ceq "sporespore_qsdk_r23d17_physical_freeze_v1" -and
    $freeze.attempt_schema_version -ceq "sporespore_qsdk_r23d17_attempt_v1" -and
    $freeze.engine_cell_report_schema_version -ceq
        "sporespore_qsdk_r23d17_engine_cell_report_v1" -and
    $freeze.worker_failure_schema_version -ceq
        "sporespore_qsdk_r23d17_worker_failure_v1" -and
    $freeze.materialization_path -ceq
        "sdk/r23d3_reproducible_runtime_materialization.ps1" -and
    [bool]$freeze.source_bindings_must_equal_git_blob_bytes -and
    [bool]$freeze.msvc_brepro_required -and
    [bool]$freeze.full_godot_v2_attestation_required -and
    [bool]$freeze.global_operation_lock_required
) "QSDK-R23D17 runtime freeze changed"

$sourcePaths = @($contract.source_binding_policy.exact_paths)
$uniqueSourcePaths = @($sourcePaths | Sort-Object -Unique -CaseSensitive)
Assert-R23D17Implementation (
    $sourcePaths.Count -eq $uniqueSourcePaths.Count -and
    @($sourcePaths | Where-Object { $_ -match '[*?\[]' }).Count -eq 0 -and
    (@($contract.source_binding_policy.tracked_prefixes) -join "|") -ceq
        "sdk/core/src/"
) "QSDK-R23D17 source-binding policy is not exact"
foreach ($relativePath in $sourcePaths) {
    Assert-R23D17Implementation (
        Test-Path -LiteralPath (
            Join-Path $repoRoot ([string]$relativePath).Replace("/", "\")
        ) -PathType Leaf
    ) "QSDK-R23D17 source binding missing: $relativePath"
}
$dependency = $contract.dependency_closure
$dependencyUnion = @(
    foreach ($workerId in @($dependency.declared_worker_ids)) {
        @($dependency.required_dependency_paths_by_worker[$workerId])
    }
) | Sort-Object -Unique -CaseSensitive
Assert-R23D17Implementation (
    $dependency.manifest_schema_version -ceq
        "sporespore_qsdk_r23d17_worker_dependency_manifest_v1" -and
    [int]$dependency.declared_worker_count -eq 3 -and
    [int]$dependency.declared_unique_dependency_count -eq 77 -and
    $dependencyUnion.Count -eq 77 -and
    @($dependencyUnion | Where-Object { $_ -cnotin $sourcePaths }).Count -eq 0 -and
    [bool]$dependency.one_removal_negative_control_per_dependency_required
) "QSDK-R23D17 dependency declaration changed"

$mujocoSource = Get-R23D17ImplementationSource (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d17_physical.py"
)
$rapierSource = Get-R23D17ImplementationSource (
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d17_physical.rs"
)
$godotSource = Get-R23D17ImplementationSource (
    "tests/test_sdk_qsdk_r23d17_godot_jolt_physical_worker.gd"
)
$waveSource = Get-R23D17ImplementationSource (
    "scripts/lab/gait/physical_wave_gait_quadruped.gd"
)
$supervisorSource = Get-R23D17ImplementationSource (
    "sdk/run_qsdk_r23d17_supervisor.ps1"
)
$rapierEvaluatorSource = Get-R23D17ImplementationSource (
    "sdk/turning/r23d17_physical_evaluator.py"
)
$rapierPublisherSource = Get-R23D17ImplementationSource (
    "sdk/publish_qsdk_r23d17_trace.ps1"
)
Assert-R23D17Implementation (
    $mujocoSource.Contains("qsdk_r23d14_tight_gated_horizon as temporal_native") -and
    $mujocoSource.Contains("r23d17_live_composition_recovery_preregistration_v1.json") -and
    -not $mujocoSource.Contains("qsdk_r23d17_tight_gated_horizon") -and
    $rapierSource.Contains("crate::qsdk_r23d14_tight_gated_horizon") -and
    $rapierSource.Contains(
        "run_qsdk_r23d17_rapier_inherited_composition_preflight"
    ) -and
    $godotSource.Contains("sdk_godot_jolt_r23d14_tight_gated_horizon.gd") -and
    $godotSource.Contains("run_sdk_terminal_diagnostics_schema_canary") -and
    $godotSource.Contains("run_sdk_terminal_authority_input_envelope_canary") -and
    $godotSource.Contains('_r23d17_worker_failure(') -and
    $godotSource.Contains('"diagnostic_only": true') -and
    $waveSource.Contains("sporespore_qsdk_r23d17_physical_trace_v1") -and
    $waveSource.Contains("sporespore_qsdk_r23d17_physical_trace_row_v1") -and
    $waveSource.Contains("_sdk_terminal_uses_independent_support_margin_availability") -and
    $waveSource.Contains("_sdk_terminal_ordered_actuator_ids") -and
    $waveSource.Contains("_sdk_r23d13_trace_authority_input_failure") -and
    $rapierEvaluatorSource.Contains('"-ExecutionPolicy"') -and
    $rapierEvaluatorSource.Contains('"Bypass"') -and
    $rapierPublisherSource.Contains("ConvertTo-R23D17LocalWindowsPathIdentity") -and
    $rapierPublisherSource.Contains("'\\?\'") -and
    $supervisorSource.Contains("[Diagnostics.ProcessStartInfo]::new()") -and
    $supervisorSource -match (
        '\[int\]\$authorizationCanaryReceipt\.content_addressed_input_count\s*' +
        '-eq\s*\[int\]\$implementation\.dependency_closure\.' +
        'declared_unique_dependency_count\s*-and'
    ) -and
    $supervisorSource -notmatch (
        '\[int\]\$authorizationCanaryReceipt\.content_addressed_input_count\s*' +
        '-eq\s*\d+'
    ) -and
    -not $supervisorSource.Contains("ForEach-Object -Parallel")
) "QSDK-R23D17 live implementation seam changed"

Assert-R23D17Implementation (
    -not [bool]$contract.authorization.physical_execution_authorized -and
    -not [bool]$contract.authorization.physical_acceptance_authority -and
    [int]$contract.authorization.world_attempt_count -eq 0 -and
    [int]$contract.authorization.world_build_count -eq 0
) "QSDK-R23D17 physical authorization opened before freeze"
foreach ($claim in @(
    "physical_implementation_zero_world_qualified",
    "selected_policy_physically_confirmed_under_r23d17",
    "finite_three_engine_result_exists", "command_conditioned_turning",
    "bilateral_signed_turning", "portable_basic_turning",
    "cross_engine_equivalence", "q_sdk_r23_satisfied", "prone_to_standing",
    "release_authorized", "physical_acceptance_authority"
)) {
    Assert-R23D17Implementation (-not [bool]$contract.claims[$claim]) (
        "QSDK-R23D17 prospective claim opened: $claim"
    )
}

Write-Host (
    "QSDK_R23D17_IMPLEMENTATION_PASS workers=3 identities=9 dependencies=77 " +
    "source_exact_paths=$($sourcePaths.Count) trace_rows_per_cell=3952 " +
    "worlds=0 physical_authority=False"
)
