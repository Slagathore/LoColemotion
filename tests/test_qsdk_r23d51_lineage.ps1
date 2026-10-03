#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$preregistrationPath = Join-Path $turningRoot (
    "r23d51_godot_segment_origin_reanchor_preregistration_v1.json"
)
$r48Path = Join-Path $turningRoot (
    "r23d48_support_loss_conditioned_three_engine_turning_closure_v1.json"
)
$r50Path = Join-Path $turningRoot (
    "r23d50_rapier_cas_path_identity_replay_closure_v1.json"
)
$r31Path = Join-Path $turningRoot (
    "r23d31_cycle_integrated_directional_response_closure_v1.json"
)
$r32Path = Join-Path $turningRoot (
    "r23d32_finite_rapier_turning_replication_closure_v1.json"
)
$implementationPath = Join-Path $turningRoot (
    "r23d51_godot_segment_origin_reanchor_implementation_v1.json"
)
$manifestPath = Join-Path $turningRoot (
    "r23d51_campaign_attestation_manifest_v1.json"
)
$shutdownDiagnosticPath = Join-Path $turningRoot (
    "r23d51_godot_47_shutdown_diagnostic_v1.json"
)
$releaseContractPath = Join-Path $repoRoot (
    "sdk\release\quadruped_release_contract.json"
)
$supportMatrixPath = Join-Path $repoRoot (
    "sdk\release\quadruped_support_matrix.json"
)
$terminationHelperPath = Join-Path $repoRoot (
    "sdk\godot_receipt_terminated_process.ps1"
)

$expectedHashes = [ordered]@{
    r48 = "sha256:5b2ce3553a78836035c6a7b6ff11ee585cb615f0ebcc70341902e7bca58b7063"
    r50 = "sha256:47bee3d69965e2ffc79fae820223be3bfdfb001fa9fa2d2bc7ee7620ca0e9f48"
    r31 = "sha256:364f44e3a974d81e6b98073e02e4c46abf927cbabed933d0d1aae706e5890b4c"
    r32 = "sha256:40c7f4797916a5780d331f2676b2956875a35f28f79ef2043db30fef0eb09c93"
}

function Assert-R23D51Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D51 LINEAGE: $Message" }
}

function Get-R23D51Hash([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Read-R23D51Json([string]$Path) {
    Assert-R23D51Lineage (Test-Path -LiteralPath $Path -PathType Leaf) (
        "missing retained declaration or closure: $Path"
    )
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Find-R23D51ProspectiveRecord($Value) {
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains("prospective_r23d51_attempt")) {
            return $Value["prospective_r23d51_attempt"]
        }
        foreach ($child in $Value.Values) {
            $found = Find-R23D51ProspectiveRecord $child
            if ($null -ne $found) { return $found }
        }
    } elseif ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found = Find-R23D51ProspectiveRecord $child
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

Assert-R23D51Lineage (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$preregistration = Read-R23D51Json $preregistrationPath
$implementation = Read-R23D51Json $implementationPath
$shutdownDiagnostic = Read-R23D51Json $shutdownDiagnosticPath
$r48 = Read-R23D51Json $r48Path
$r50 = Read-R23D51Json $r50Path
$r31 = Read-R23D51Json $r31Path
$r32 = Read-R23D51Json $r32Path
$releaseContract = Read-R23D51Json $releaseContractPath
$supportMatrix = Read-R23D51Json $supportMatrixPath
$lineage = $preregistration.immutable_lineage
$successor = $preregistration.scientifically_distinct_successor
$matrix = $preregistration.frozen_matrix
$measurement = $preregistration.cycle_integrated_measurement
$evidenceIntegrity = $preregistration.evidence_integrity
$declaredHostLifecycle = $preregistration.godot_host_lifecycle
$claims = $preregistration.claims
$hostContainment = $implementation.godot_host_lifecycle_containment
$godotSessionFreeze = $implementation.godot_transport_and_session_freeze
$terminationHelper = Get-Content -Raw -LiteralPath $terminationHelperPath

Assert-R23D51Lineage (
    (Get-R23D51Hash $r48Path) -ceq $expectedHashes.r48 -and
    (Get-R23D51Hash $r50Path) -ceq $expectedHashes.r50 -and
    (Get-R23D51Hash $r31Path) -ceq $expectedHashes.r31 -and
    (Get-R23D51Hash $r32Path) -ceq $expectedHashes.r32 -and
    [string]$lineage.r23d48_closure_raw_sha256 -ceq $expectedHashes.r48 -and
    [string]$lineage.r23d50_closure_raw_sha256 -ceq $expectedHashes.r50 -and
    [string]$lineage.r23d31_closure_raw_sha256 -ceq $expectedHashes.r31 -and
    [string]$lineage.r23d32_closure_raw_sha256 -ceq $expectedHashes.r32
) "immutable closure hashes changed"

Assert-R23D51Lineage (
    [bool]$r48.identity_consumed -and
    -not [bool]$r48.same_identity_rerun_allowed -and
    [string]$r48.official_disposition.classification -ceq
        "invalid_or_incomplete_three_engine_portable_turning_validation" -and
    [int]$r48.physical_evidence.observed_world_build_count -eq 9 -and
    [int]$r48.official_disposition.godot_jolt_execution_valid_cell_count -eq 3 -and
    [bool]$r48.engine_results.godot_jolt.all_cells_execution_valid -and
    [bool]$r48.engine_results.godot_jolt.all_common_physical_gates_passed -and
    -not [bool]$r48.engine_results.godot_jolt.raw_signed_cycle_shift_gate_passed -and
    [bool]$r48.engine_results.godot_jolt.reference_conditioned_cycle_shift_gate_passed -and
    -not [bool]$r48.engine_results.godot_jolt.full_three_arm_turning_gate_passed -and
    [bool]$r48.engine_results.mujoco.full_three_arm_turning_gate_passed -and
    [bool]$r48.claims.godot_jolt_seed_21512_all_three_common_walking_gates_passed -and
    -not [bool]$r48.claims.godot_jolt_seed_21512_finite_turning -and
    -not [bool]$r48.claims.finite_three_engine_turning
) "R48 walking-positive and turning-negative Godot boundary changed"

Assert-R23D51Lineage (
    [bool]$r50.identity_consumed -and
    -not [bool]$r50.same_identity_rerun_allowed -and
    [string]$r50.official_result.classification -ceq
        "valid_complete_positive_outcome_exposed_rapier_cas_path_identity_replay" -and
    [bool]$r50.official_result.all_cells_execution_valid -and
    [bool]$r50.official_result.all_cells_common_physical_gates_passed -and
    [bool]$r50.official_result.turning_measurement_passed -and
    [bool]$r50.official_result.outcome_exposed_replay -and
    -not [bool]$r50.official_result.fresh_held_out_condition -and
    -not [bool]$r50.claims.fresh_rapier_turning_replication -and
    -not [bool]$r50.claims.finite_three_engine_turning
) "R50 outcome-exposed Rapier boundary changed"

Assert-R23D51Lineage (
    [bool]$r31.identity_consumed -and
    -not [bool]$r31.same_identity_rerun_allowed -and
    [double]$r31.cycle_integrated_evaluation.minimum_cycle_shift_rad -eq 0.01 -and
    [bool]$r31.cycle_integrated_evaluation.selecting_gates.raw_signed_cycle_shift -and
    [bool]$r31.cycle_integrated_evaluation.selecting_gates.reference_conditioned_cycle_shift -and
    [bool]$r32.identity_consumed -and
    -not [bool]$r32.same_identity_rerun_allowed -and
    [double]$r32.cycle_integrated_evaluation.minimum_cycle_shift_rad -eq 0.01 -and
    [bool]$r32.claims.finite_rapier_turning_validation -and
    -not [bool]$r32.claims.finite_three_engine_turning
) "R31 measurement or R32 finite validation lineage changed"

Assert-R23D51Lineage (
    [string]$preregistration.status -ceq "prospective_zero_world_only" -and
    [string]$preregistration.campaign_id -ceq
        "QSDK-R23D51-GODOT-SEGMENT-ORIGIN-REANCHOR-DEVELOPMENT" -and
    [string]$preregistration.study_classification -ceq
        "exact_outcome_exposed_same_seed_godot_jolt_implementation_development_screen" -and
    [bool]$successor.same_outcome_exposed_seed_as_comparator -and
    [bool]$successor.same_initial_perturbation_as_comparator -and
    [string]$successor.only_declared_physical_change -ceq
        "task_frame_origin_policy_id=fixed_initial_origin_v1 becomes heading_segment_origin_reanchor_v1" -and
    -not [bool]$successor.reference_yaw_rebased -and
    -not [bool]$successor.task_axes_rebased -and
    -not [bool]$successor.controller_source_or_gain_changed -and
    -not [bool]$successor.engine_identity_input_permitted -and
    -not [bool]$successor.arm_identity_input_permitted -and
    -not [bool]$successor.outcome_branching_permitted -and
    -not [bool]$successor.threshold_changed -and
    -not [bool]$successor.fresh_held_out_condition_consumed
) "single-change outcome-exposed successor boundary changed"

Assert-R23D51Lineage (
    [int]$matrix.declared_cell_count -eq 3 -and
    [int]$matrix.declared_world_count -eq 3 -and
    [int]$matrix.seed -eq 21512 -and
    [string]$matrix.task_frame_origin_policy_id -ceq
        "heading_segment_origin_reanchor_v1" -and
    (@($matrix.expected_reanchor_semantic_steps) -join ',') -ceq
        "0,600,1800,2400" -and
    [int]$matrix.controller_step_count -eq 2992 -and
    [bool]$matrix.serial_execution_required -and
    [bool]$matrix.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$measurement.inherited_unchanged_from_r23d31 -and
    [double]$measurement.minimum_raw_signed_cycle_shift_rad -eq 0.01 -and
    [double]$measurement.minimum_reference_conditioned_cycle_shift_rad -eq 0.01 -and
    [bool]$evidenceIntegrity.r23d50_existing_file_identity_verifier_inherited -and
    [bool]$evidenceIntegrity.ordinary_and_windows_extended_path_spellings_equivalent -and
    [bool]$evidenceIntegrity.wrong_existing_file_rejected -and
    [bool]$evidenceIntegrity.authority_repo_root_required_for_complete_evaluation -and
    [bool]$evidenceIntegrity.recorded_path_spelling_is_not_file_identity_authority -and
    [string]$declaredHostLifecycle.diagnostic_path -ceq
        "sdk/turning/r23d51_godot_47_shutdown_diagnostic_v1.json" -and
    [string]$declaredHostLifecycle.termination_protocol_id -ceq
        "godot_4_7_gdscript_shutdown_containment_v1" -and
    [bool]$declaredHostLifecycle.applies_after_complete_semantic_worker_receipt -and
    [bool]$declaredHostLifecycle.per_process_nonce_and_process_lineage_binding_required -and
    [bool]$declaredHostLifecycle.exact_launched_process_tree_only -and
    [bool]$declaredHostLifecycle.semantic_exit_retained_separately_from_forced_host_exit -and
    -not [bool]$declaredHostLifecycle.physics_or_controller_change -and
    [int]$declaredHostLifecycle.world_build_count -eq 0 -and
    -not [bool]$declaredHostLifecycle.physical_acceptance_authority -and
    -not [bool]$claims.physical_world_opened -and
    -not [bool]$claims.godot_jolt_turning_validation -and
    -not [bool]$claims.finite_three_engine_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized
) "finite three-world declaration or false-claim boundary changed"

Assert-R23D51Lineage (
    [string]$godotSessionFreeze.session_execution_version -ceq
        "sporespore_godot_balanced_wave_persistent_session_v1" -and
    [string]$godotSessionFreeze.session_runtime_contract_schema_version -ceq
        "sporespore_godot_controller_session_execution_contract_v1" -and
    [string]$godotSessionFreeze.policy_initial_memory_request_schema_version -ceq
        "sporespore_balanced_wave_policy_initial_memory_request_v1" -and
    [string]$godotSessionFreeze.policy_initial_memory_symbol -ceq
        "ss_balanced_wave_policy_initial_memory_json" -and
    [string]$godotSessionFreeze.transport_execution_contract_raw_sha256 -ceq
        (Get-R23D51Hash (Join-Path $repoRoot ([string]$godotSessionFreeze.transport_execution_contract_path))) -and
    [string]$godotSessionFreeze.persistent_session_contract_raw_sha256 -ceq
        (Get-R23D51Hash (Join-Path $repoRoot ([string]$godotSessionFreeze.persistent_session_contract_path))) -and
    [string]$godotSessionFreeze.c_abi_manifest_raw_sha256 -ceq
        (Get-R23D51Hash (Join-Path $repoRoot ([string]$godotSessionFreeze.c_abi_manifest_path))) -and
    [string]$godotSessionFreeze.schema_registry_raw_sha256 -ceq
        (Get-R23D51Hash (Join-Path $repoRoot ([string]$godotSessionFreeze.schema_registry_path))) -and
    [string]$godotSessionFreeze.portable_core_ffi_raw_sha256 -ceq
        (Get-R23D51Hash (Join-Path $repoRoot ([string]$godotSessionFreeze.portable_core_ffi_path))) -and
    [string]$godotSessionFreeze.godot_adapter_rust_raw_sha256 -ceq
        (Get-R23D51Hash (Join-Path $repoRoot ([string]$godotSessionFreeze.godot_adapter_rust_path))) -and
    [string]$godotSessionFreeze.godot_adapter_gdscript_raw_sha256 -ceq
        (Get-R23D51Hash (Join-Path $repoRoot ([string]$godotSessionFreeze.godot_adapter_gdscript_path))) -and
    [string]$godotSessionFreeze.selected_physical_runner_raw_sha256 -ceq
        (Get-R23D51Hash (Join-Path $repoRoot ([string]$godotSessionFreeze.selected_physical_runner_path))) -and
    [bool]$godotSessionFreeze.built_gdextension_sha256_frozen_by_one_shot_supervisor_before_world -and
    [bool]$godotSessionFreeze.worker_preflight_requires_exact_transport_session_and_shutdown_receipts -and
    [int]$godotSessionFreeze.world_build_count -eq 0 -and
    -not [bool]$godotSessionFreeze.physical_acceptance_authority
) "Godot transport or persistent-session physical freeze drifted"

Assert-R23D51Lineage (
    [string]$hostContainment.scope -ceq "r23d51_worker_process_exit_only" -and
    [string]$hostContainment.termination_protocol_id -ceq
        "godot_4_7_gdscript_shutdown_containment_v1" -and
    [string]$hostContainment.helper_path -ceq
        "sdk/godot_receipt_terminated_process.ps1" -and
    [string]$hostContainment.diagnostic_path -ceq
        "sdk/turning/r23d51_godot_47_shutdown_diagnostic_v1.json" -and
    -not [bool]$hostContainment.physics_or_controller_change -and
    [bool]$hostContainment.worker_receipt_emitted_before_ready_receipt -and
    [bool]$hostContainment.explicit_controller_session_shutdown_before_ready_receipt -and
    [bool]$hostContainment.ready_receipt_requires_two_zero_physics_process_frames -and
    [bool]$hostContainment.per_process_nonce_required -and
    [bool]$hostContainment.ready_schema_protocol_nonce_and_process_lineage_validation_required -and
    [bool]$hostContainment.supervisor_terminates_only_the_exact_launcher_process_tree -and
    [bool]$hostContainment.raw_host_exit_code_is_retained_separately -and
    [bool]$hostContainment.wrong_nonce_negative_control_required -and
    [bool]$implementation.supervisor.transport_failure_world_build_count_uncertainty_retained_as_bounds -and
    [int]$hostContainment.world_build_count -eq 0 -and
    -not [bool]$hostContainment.physical_acceptance_authority -and
    [bool]$implementation.claims.godot_host_lifecycle_containment_qualified_zero_world -and
    @($implementation.source_binding_policy.exact_paths | Where-Object {
        [string]$_ -ceq "sdk/godot_receipt_terminated_process.ps1"
    }).Count -eq 1 -and
    $terminationHelper.Contains("Test-SporeSporeProcessIsSelfOrDescendant") -and
    $terminationHelper.Contains("GODOT_READY_MARKER_BINDING_INVALID") -and
    $terminationHelper.Contains("`$process.Kill(`$true)")
) "Godot 4.7 host-lifecycle containment contract changed"

Assert-R23D51Lineage (
    [string]$shutdownDiagnostic.status -ceq
        "diagnosed_zero_world_host_fault_with_scoped_containment" -and
    [string]$shutdownDiagnostic.retained_crash_artifact.raw_sha256 -ceq
        "sha256:241d7facca119a50b799bb39e3a3335b2a338dab55946dffc37568737aeab2bd" -and
    [string]$shutdownDiagnostic.retained_crash_artifact.exception_code -ceq
        "0xC0000005" -and
    [string]$shutdownDiagnostic.diagnosis.mapped_function -ceq
        "GDScriptLanguage::finish" -and
    -not [bool]$shutdownDiagnostic.diagnosis.adapter_dll_was_faulting_module -and
    [string]$shutdownDiagnostic.selected_containment.termination_protocol_id -ceq
        "godot_4_7_gdscript_shutdown_containment_v1" -and
    [int]$shutdownDiagnostic.development_validation.selected_containment_trial_count -eq 30 -and
    [int]$shutdownDiagnostic.development_validation.valid_semantic_receipt_count -eq 30 -and
    [int]$shutdownDiagnostic.development_validation.observed_access_violation_count -eq 0 -and
    [bool]$shutdownDiagnostic.development_validation.wrong_nonce_rejected -and
    [int]$shutdownDiagnostic.development_validation.world_build_count -eq 0 -and
    -not [bool]$shutdownDiagnostic.claims.physics_result -and
    -not [bool]$shutdownDiagnostic.claims.physical_acceptance_authority
) "retained Godot 4.7 shutdown diagnosis or claim boundary changed"

$turningGate = @($releaseContract.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
Assert-R23D51Lineage ($turningGate.Count -eq 1) (
    "release contract must contain exactly one QSDK-R23 gate"
)
$releaseRecord = $turningGate[0].proof.prospective_r23d51_attempt
$matrixRecord = Find-R23D51ProspectiveRecord $supportMatrix
$implementationHash = Get-R23D51Hash $implementationPath
$manifestHash = Get-R23D51Hash $manifestPath
Assert-R23D51Lineage (
    $null -ne $releaseRecord -and
    $null -ne $matrixRecord -and
    [string]$releaseRecord.status -ceq "prospective_zero_world_only" -and
    [string]$matrixRecord.status -ceq "prospective_zero_world_only" -and
    [string]$releaseRecord.preregistration_raw_sha256 -ceq
        (Get-R23D51Hash $preregistrationPath) -and
    [string]$matrixRecord.preregistration_sha256 -ceq
        (Get-R23D51Hash $preregistrationPath) -and
    [string]$releaseRecord.implementation_raw_sha256 -ceq $implementationHash -and
    [string]$matrixRecord.implementation_sha256 -ceq $implementationHash -and
    [string]$releaseRecord.campaign_attestation_manifest_raw_sha256 -ceq
        $manifestHash -and
    [string]$matrixRecord.campaign_attestation_manifest_sha256 -ceq
        $manifestHash -and
    [int]$releaseRecord.declared_world_count -eq 3 -and
    [int]$matrixRecord.declared_world_count -eq 3 -and
    [int]$releaseRecord.local_world_build_count -eq 0 -and
    [int]$matrixRecord.local_world_build_count -eq 0 -and
    [bool]$releaseRecord.r23d50_existing_file_identity_verifier_inherited -and
    [bool]$matrixRecord.r23d50_existing_file_identity_verifier_inherited -and
    [bool]$releaseRecord.authority_repo_root_required_for_complete_evaluation -and
    [bool]$matrixRecord.authority_repo_root_required_for_complete_evaluation -and
    [string]$releaseRecord.godot_4_7_shutdown_diagnostic_path -ceq
        "sdk/turning/r23d51_godot_47_shutdown_diagnostic_v1.json" -and
    [string]$matrixRecord.godot_4_7_shutdown_diagnostic_path -ceq
        "sdk/turning/r23d51_godot_47_shutdown_diagnostic_v1.json" -and
    [string]$releaseRecord.godot_worker_termination_protocol_id -ceq
        "godot_4_7_gdscript_shutdown_containment_v1" -and
    [string]$matrixRecord.godot_worker_termination_protocol_id -ceq
        "godot_4_7_gdscript_shutdown_containment_v1" -and
    [int]$releaseRecord.local_host_containment_stress_trial_count -eq 30 -and
    [int]$matrixRecord.local_host_containment_stress_trial_count -eq 30 -and
    [int]$releaseRecord.local_host_containment_observed_access_violation_count -eq 0 -and
    [int]$matrixRecord.local_host_containment_observed_access_violation_count -eq 0 -and
    [bool]$releaseRecord.local_host_containment_wrong_nonce_rejection_passed -and
    [bool]$matrixRecord.local_host_containment_wrong_nonce_rejection_passed -and
    -not [bool]$releaseRecord.host_lifecycle_physics_or_controller_change -and
    -not [bool]$matrixRecord.host_lifecycle_physics_or_controller_change -and
    [bool]$releaseRecord.clean_pushed_scoped_qualification_pending -and
    [bool]$matrixRecord.clean_pushed_scoped_qualification_pending -and
    -not [bool]$releaseRecord.physical_world_opened -and
    -not [bool]$matrixRecord.physical_world_opened -and
    -not [bool]$releaseRecord.finite_three_engine_turning -and
    -not [bool]$matrixRecord.finite_three_engine_turning -and
    -not [bool]$releaseRecord.prone_to_standing -and
    -not [bool]$matrixRecord.prone_to_standing
) "release contract and support matrix prospective R51 records diverged"

Write-Host (
    "QSDK_R23D51_LINEAGE_PASS predecessors=R23D31,R23D32,R23D48,R23D50 " +
    "seed=21512 worlds=3 physical_change_count=1 threshold_changes=0 " +
    "held_out=False physical=False"
)
