#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot (
    "turning\r23d14_physical_implementation_contract_v1.json"
)
$preregistrationPath = Join-Path $sdkRoot (
    "turning\r23d14_tight_gated_horizon_preregistration_v1.json"
)
$dependencyPath = Join-Path $sdkRoot "turning\r23d14_dependency_closure.ps1"
$campaignId = "QSDK-R23D14-TIGHT-GATED-HORIZON-THREE-ENGINE-TURN-CONFIRMATION"

function Assert-R23D14Implementation {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D14ImplementationRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D14ImplementationSource {
    param([Parameter(Mandatory)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    Assert-R23D14Implementation (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D14 implementation source is missing: $RelativePath"
    )
    return [IO.File]::ReadAllText($path)
}

function Assert-R23D14ImplementationSourceContains {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string[]]$Needles
    )
    $source = Get-R23D14ImplementationSource $RelativePath
    foreach ($needle in $Needles) {
        Assert-R23D14Implementation (
            $source.Contains($needle, [StringComparison]::Ordinal)
        ) "QSDK-R23D14 source seam is missing: $RelativePath :: $needle"
    }
}

function Assert-R23D14ImplementationSourceExcludes {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string[]]$Needles
    )
    $source = Get-R23D14ImplementationSource $RelativePath
    foreach ($needle in $Needles) {
        Assert-R23D14Implementation (
            -not $source.Contains($needle, [StringComparison]::Ordinal)
        ) "QSDK-R23D14 forbidden source alias is present: $RelativePath :: $needle"
    }
}

Assert-R23D14Implementation (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D14 implementation repository identity changed"
foreach ($path in @($contractPath, $preregistrationPath, $dependencyPath)) {
    Assert-R23D14Implementation (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D14 implementation authority is missing: $path"
    )
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D14Implementation (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d14_physical_implementation_contract_v1" -and
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq "QSDK-R23D14" -and
    [string]$contract.release_gate_id -ceq "QSDK-R23" -and
    [string]$contract.preregistration_raw_sha256 -ceq
        (Get-R23D14ImplementationRawSha256 $preregistrationPath) -and
    @($contract.workers).Count -eq 3 -and
    @($contract.workers.engine_id) -join "|" -ceq
        "mujoco|rapier_parry|godot_jolt" -and
    @($contract.workers | Where-Object {
        -not [bool]$_.physical_worker_implemented -or
        [int]$_.physical_world_count_before_freeze -ne 0
    }).Count -eq 0 -and
    [int]$contract.fixed_schedule.turning_controller_step_count -eq 2992 -and
    [int]$contract.fixed_schedule.terminal_quiescent_taper_step_count -eq 960 -and
    [int]$contract.fixed_schedule.total_trace_row_count_per_cell -eq 3952 -and
    [int]$contract.fixed_schedule.maximum_active_neutral_acquisition_step_count -eq 600 -and
    [int]$contract.fixed_schedule.minimum_quiescent_taper_step_count -eq 120 -and
    [int]$contract.fixed_schedule.minimum_post_handoff_zero_actuation_step_count -eq 360 -and
    [int]$contract.fixed_schedule.exact_post_handoff_native_application_count -eq 0 -and
    [string]$contract.tight_gated_horizon_implementation.terminal_policy_id -ceq
        "sporespore_tight_gated_acquisition_active600_v1" -and
    [bool]$contract.tight_gated_horizon_implementation.transition_applies_to_following_step -and
    [bool]$contract.tight_gated_horizon_implementation.taper_scale_applied_to_canonical_velocity_before_host_mapping_required -and
    [bool]$contract.tight_gated_horizon_implementation.handoff_is_irreversible -and
    -not [bool]$contract.tight_gated_horizon_implementation.post_handoff_reactivation_permitted -and
    -not [bool]$contract.tight_gated_horizon_implementation.post_handoff_native_actuation_permitted -and
    -not [bool]$contract.tight_gated_horizon_implementation.deadline_forced_handoff_can_pass -and
    [bool]$contract.tight_gated_horizon_implementation.tight_pose_loss_resets_full_acquisition -and
    [int]$contract.tight_gated_horizon_implementation.native_temporal_canary_count_per_worker_route -eq 12 -and
    [int]$contract.tight_gated_horizon_implementation.native_temporal_mutation_control_count_per_worker_route -eq 14 -and
    [int]$contract.tight_gated_horizon_implementation.composition_canary_count_per_native_route -eq 7 -and
    [int]$contract.tight_gated_horizon_implementation.composition_mutation_control_count_per_native_route -eq 18 -and
    [int]$contract.tight_gated_horizon_implementation.diagnostic_valid_canary_count_per_native_route -eq 7 -and
    [int]$contract.tight_gated_horizon_implementation.diagnostic_mutation_control_count_per_native_route -eq 14 -and
    [int]$contract.tight_gated_horizon_implementation.pose_authority_canary_count_per_native_route -eq 10 -and
    [int]$contract.tight_gated_horizon_implementation.pose_authority_mutation_control_count_per_native_route -eq 20 -and
    [bool]$contract.tight_gated_horizon_implementation.command_time_feedback_is_previous_completed_step -and
    [bool]$contract.tight_gated_horizon_implementation.authority_floor_applied_to_complete_combined_velocity_once -and
    [bool]$contract.tight_gated_horizon_implementation.authority_floor_may_never_reduce_temporal_authority -and
    [bool]$contract.tight_gated_horizon_implementation.passive_authority_numerator_is_exact_zero -and
    -not [bool]$contract.tight_gated_horizon_implementation.arm_identity_or_command_sign_is_control_input -and
    -not [bool]$contract.independent_diagnostic_availability_implementation.physical_result_observed_before_implementation -and
    -not [bool]$contract.independent_diagnostic_availability_implementation.decision_or_acceptance_threshold_changed -and
    [bool]$contract.independent_diagnostic_availability_implementation.planner_and_support_margin_availability_are_independent -and
    [string]$contract.independent_diagnostic_availability_implementation.immutable_stage_two_commit -ceq
        "b45432d7f5db4968e2b0aaac331d9e8e63e98238" -and
    [bool]$contract.production_evaluator.trace_retention_cli_producer_consumer_integration_required -and
    [bool]$contract.production_evaluator.evaluator_success_marker_requires_zero_exit_and_forbids_generic_marker -and
    [bool]$contract.supervisor.evaluator_expected_source_commit_forwarded_from_frozen_source -and
    [string]$contract.supervisor.stage_id -ceq
        "finite_three_engine_confirmation" -and
    [int]$contract.supervisor.declared_world_count -eq 9 -and
    (@($contract.supervisor.ordered_matrix_cell_ids) -join "|") -ceq
        "godot_jolt__tight_gated_horizon__reference_zero|godot_jolt__tight_gated_horizon__positive_heading|godot_jolt__tight_gated_horizon__negative_heading|rapier_parry__tight_gated_horizon__reference_zero|rapier_parry__tight_gated_horizon__positive_heading|rapier_parry__tight_gated_horizon__negative_heading|mujoco__tight_gated_horizon__reference_zero|mujoco__tight_gated_horizon__positive_heading|mujoco__tight_gated_horizon__negative_heading" -and
    [bool]$contract.supervisor.all_cells_serial_without_outcome_early_stop -and
    [bool]$contract.supervisor.matrix_authorization_immutable_before_first_world -and
    -not [bool]$contract.supervisor.parallel_execution_permitted
) "QSDK-R23D14 physical implementation contract changed"
Assert-R23D14Implementation (
    [string]$preregistration.schema_version -ceq
        "sporespore_qsdk_r23d14_tight_gated_horizon_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [int]$preregistration.finite_three_engine_confirmation.declared_world_count -eq 9 -and
    (@($preregistration.finite_three_engine_confirmation.ordered_engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    (@($preregistration.finite_three_engine_confirmation.ordered_arm_ids) -join "|") -ceq
        "reference_zero|positive_heading|negative_heading" -and
    [string]$preregistration.terminal_policy_contract.policy_id -ceq
        "sporespore_tight_gated_acquisition_active600_v1" -and
    [int]$preregistration.terminal_policy_contract.terminal_step_count -eq 960 -and
    [int]$preregistration.terminal_policy_contract.maximum_active_step_count -eq 600 -and
    [bool]$preregistration.terminal_policy_contract.tight_pose_loss_resets_to_full_acquisition -and
    -not [bool]$preregistration.stage_zero_authority.physical_execution_authorized -and
    -not [bool]$preregistration.claim_boundary.physical_acceptance_authority
) "QSDK-R23D14 preregistration identity changed"

$exactPaths = @($contract.source_binding_policy.exact_paths)
Assert-R23D14Implementation (
    $exactPaths.Count -gt 0 -and
    @($exactPaths | Group-Object -CaseSensitive | Where-Object Count -gt 1).Count -eq 0 -and
    @($exactPaths | Where-Object {
        [IO.Path]::IsPathRooted([string]$_) -or
        ([string]$_).Contains("\") -or
        ([string]$_).Contains("*") -or
        ([string]$_).Contains("?") -or
        -not (Test-Path -LiteralPath (Join-Path $repoRoot ([string]$_)) -PathType Leaf)
    }).Count -eq 0
) "QSDK-R23D14 source-binding policy is not exact and complete"

. $dependencyPath
$manifest = Get-R23D14DependencyManifest -RepoRoot $repoRoot
$pathSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($path in $exactPaths) { [void]$pathSet.Add([string]$path) }
Assert-R23D14Implementation (
    [string]$manifest.schema_version -ceq
        "sporespore_qsdk_r23d14_worker_dependency_manifest_v1" -and
    @($manifest.ordered_worker_ids).Count -eq 3 -and
    [int]$manifest.unique_dependency_count -eq 70 -and
    @($manifest.union_paths | Where-Object {
        -not $pathSet.Contains([string]$_)
    }).Count -eq 0
) "QSDK-R23D14 dependency closure changed or escaped the source binding set"

Assert-R23D14ImplementationSourceContains `
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d14_physical.py" `
    @(
        "def _load_private_worker_core(",
        "def physical_authorization(",
        "def authorization_preflight(",
        "def run_physical(",
        '"qsdk_r23d13_residual_pose_authority_physical.py"',
        '"physical_authorization": physical_authorization',
        "_core.run_physical(stage_id, arm_id, source_commit)"
    )
$mujocoSource = Get-R23D14ImplementationSource (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d13_residual_pose_authority_physical.py"
)
Assert-R23D14Implementation (
    $mujocoSource.IndexOf("physical_authorization(cell, source_commit)") -lt
        $mujocoSource.IndexOf("MujocoBw19vRobot(")
) "QSDK-R23D14 MuJoCo model construction precedes authorization"
Assert-R23D14ImplementationSourceExcludes `
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d14_physical.py" `
    @(
        'sporespore_qsdk_r23d13_engine_cell_report_v1',
        'SPORESPORE_QSDK_R23D13_FREEZE'
    )

Assert-R23D14ImplementationSourceContains `
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d14_physical.rs" `
    @(
        "fn r23d14_physical_authorization(",
        "run_qsdk_r23d14_rapier_authorization_preflight_impl(",
        "run_qsdk_r23d14_rapier_physical_impl(",
        "QSDK_R23D14_RAP_PHYSICAL_AUTHORIZATION_REQUIRED",
        'R23D14_TRACE_RETENTION_MARKER: &str = "QSDK_R23D14_TRACE_RETENTION "',
        '"command_time_feedback_trace_step"',
        '"pose_authority_floor_numerator"',
        '"minimum_dynamic_support_margin_availability"'
    )
$rapierFixtureSource = Get-R23D14ImplementationSource (
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d14_physical.rs"
)
$rapierR23D14Start = $rapierFixtureSource.IndexOf(
    "const R23D14_PREREGISTRATION_RAW",
    [StringComparison]::Ordinal
)
Assert-R23D14Implementation ($rapierR23D14Start -ge 0) (
    "QSDK-R23D14 Rapier production section is missing"
)
$rapierR23D14Source = $rapierFixtureSource.Substring($rapierR23D14Start)
Assert-R23D14Implementation (
    $rapierR23D14Source.Contains(
        "let prefix = R23D14_TRACE_RETENTION_MARKER;",
        [StringComparison]::Ordinal
    ) -and
    -not $rapierR23D14Source.Contains(
        'QSDK_R23D14_EVALUATION ',
        [StringComparison]::Ordinal
    )
) "QSDK-R23D14 Rapier trace-retention consumer marker drifted"
Assert-R23D14ImplementationSourceContains `
    "sdk/adapters/rapier/src/lib.rs" `
    @(
        "run_qsdk_r23d14_rapier_authorization_preflight_impl as run_qsdk_r23d14_rapier_authorization_preflight",
        "run_qsdk_r23d14_rapier_physical_impl as run_qsdk_r23d14_rapier_physical"
    )

Assert-R23D14ImplementationSourceContains `
    "tests/test_sdk_qsdk_r23d14_tight_gated_horizon_godot_jolt_physical_worker.gd" `
    @(
        "func _r23d14_run_physical(",
        "_r23d14_physical_authorization(cell, source_commit)",
        "_r23d14_retain_trace(",
        'var marker := "QSDK_R23D14_TRACE_RETENTION "',
        "_r23d14_source_bindings_exact(",
        "production_trace_constructor_canary_count",
        '"minimum_dynamic_support_margin_availability"'
    )
Assert-R23D14ImplementationSourceContains `
    "scripts/lab/gait/physical_wave_gait_quadruped.gd" `
    @(
        '"command_time_feedback_trace_step"',
        '"pose_authority_floor_numerator"',
        "apply_residual_pose_authority("
    )
$godotSource = Get-R23D14ImplementationSource (
    "tests/test_sdk_qsdk_r23d14_tight_gated_horizon_godot_jolt_physical_worker.gd"
)
Assert-R23D14Implementation (
    $godotSource.IndexOf("_r23d14_physical_authorization(cell, source_commit)") -lt
        $godotSource.IndexOf("var summary: Dictionary = await _r8_run_wave(prepared, false)")
) "QSDK-R23D14 Godot/Jolt world route precedes authorization"

$physicalWorkerPaths = @(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d13_residual_pose_authority_physical.py",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d14_physical.rs",
    "tests/test_sdk_qsdk_r23d14_tight_gated_horizon_godot_jolt_physical_worker.gd"
)
foreach ($path in $physicalWorkerPaths) {
    Assert-R23D14ImplementationSourceContains $path @(
        '"terminal_quiescent_taper_step_count"',
        '"quiescent_taper_step_count"',
        '"quiescent_taper_gate_passed"'
    )
}

Assert-R23D14ImplementationSourceContains "sdk/run_qsdk_r23d14_supervisor.ps1" @(
    '$matrixStageId = "finite_three_engine_confirmation"',
    '"$engineId`__tight_gated_horizon__$armId"',
    'matrix_authorization_immutable_before_first_world = $true',
    'foreach ($cellId in $matrixCellIds)',
    '"physical",',
    '"sporespore_mujoco_adapter.qsdk_r23d14_physical"',
    'Get-R23D14TerminalMarkerClassification',
    'Publish-SporeSporeContentAddressedArtifact',
    '"--expected-source-commit", $ExpectedSourceCommit',
    '-ExpectedSourceCommit ([string]$Source.commit)',
    'evaluator exited nonzero after retention',
    'evaluator emitted the forbidden generic marker',
    'parallel_execution_permitted = $false'
)

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d14_physical_implementation_audit_v1"
    campaign_id = $campaignId
    gate_id = "QSDK-R23D14"
    implementation_contract_raw_sha256 = Get-R23D14ImplementationRawSha256 $contractPath
    worker_implementation_count = 3
    native_diagnostic_route_count = 3
    complete_trace_retention_path_count = 3
    declared_worker_dependency_count = 70
    single_supervisor_count = 1
    physical_process_launch_count = 0
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
}
Write-Host (
    "QSDK_R23D14_IMPLEMENTATION_AUDIT " +
    ($receipt | ConvertTo-Json -Depth 40 -Compress)
)
Write-Host (
    "QSDK_R23D14_IMPLEMENTATION_PASS workers=3 native_diagnostic_routes=3 " +
    "trace_retention_paths=3 dependencies=70 supervisor=1 models=0 worlds=0 " +
    "physical_authority=False"
)
