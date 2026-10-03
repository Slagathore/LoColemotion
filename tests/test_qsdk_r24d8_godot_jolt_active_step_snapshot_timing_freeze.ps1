#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python",
    [string]$GodotSourceRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedGodotRemote = "https://github.com/godotengine/godot.git"
$expectedEvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$expectedGodotCommit = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
$expectedPatchHash = (
    "9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
)
$contractRelative = (
    "sdk/recovery/" +
    "r24d8_godot_jolt_active_step_snapshot_timing_preregistration_v1.json"
)
$manifestRelative = (
    "sdk/recovery/" +
    "r24d8_godot_jolt_active_step_snapshot_timing_validation_manifest.json"
)
$precommitDiagnosticsRelative = (
    "sdk/recovery/r24d8_precommit_zero_world_diagnostics_v1.json"
)
$firstOfficialFailureRelative = (
    "sdk/recovery/r24d8_first_official_zero_world_qualification_failure_v1.json"
)
$maintenanceDiagnosticsRelative = (
    "sdk/recovery/r24d8_maintenance_precommit_diagnostics_v1.json"
)
$basePatchRelative = (
    "sdk/adapters/godot/engine_patches/" +
    "godot_4_7_jolt_motor_telemetry.patch"
)
$patchRelative = (
    "sdk/adapters/godot/engine_patches/" +
    "godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
)
$rigRelative = (
    "scripts/lab/rigs/" +
    "r24d8_godot_jolt_active_step_snapshot_timing_rig.gd"
)
$workerRelative = (
    "tests/" +
    "test_sdk_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_worker.gd"
)
$evaluatorRelative = (
    "sdk/recovery/" +
    "r24d8_godot_jolt_active_step_snapshot_timing_evaluator.py"
)
$supervisorRelative = "sdk/run_qsdk_r24d8_active_step_snapshot_timing.ps1"
$auditRelative = (
    "tests/test_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_freeze.ps1"
)
$predecessorClosureRelative = (
    "sdk/recovery/" +
    "r24d7_godot_jolt_one_hinge_telemetry_physical_failure_closure_v1.json"
)
$predecessorClosureAuditRelative = (
    "tests/test_qsdk_r24d7_one_hinge_telemetry_physical_failure_closure.ps1"
)
$predecessorCompatibilityAuditRelative = (
    "tests/test_qsdk_r24d8_predecessor_evidence_compatibility.ps1"
)
$expectedPatchedPaths = @(
    "modules/jolt_physics/joints/jolt_hinge_joint_3d.cpp",
    "modules/jolt_physics/joints/jolt_hinge_joint_3d.h",
    "modules/jolt_physics/joints/jolt_joint_3d.h",
    "modules/jolt_physics/jolt_physics_server_3d.cpp",
    "modules/jolt_physics/jolt_physics_server_3d.h",
    "modules/jolt_physics/register_types.cpp",
    "modules/jolt_physics/spaces/jolt_space_3d.cpp",
    "modules/jolt_physics/spaces/jolt_space_3d.h",
    "thirdparty/jolt_physics/Jolt/Physics/Constraints/HingeConstraint.cpp",
    "thirdparty/jolt_physics/Jolt/Physics/Constraints/HingeConstraint.h"
)
$expectedManifestPaths = @(
    ".gitattributes",
    $basePatchRelative,
    $patchRelative,
    $contractRelative,
    $precommitDiagnosticsRelative,
    $firstOfficialFailureRelative,
    $maintenanceDiagnosticsRelative,
    $predecessorClosureRelative,
    $predecessorClosureAuditRelative,
    $rigRelative,
    $workerRelative,
    $evaluatorRelative,
    $supervisorRelative,
    $predecessorCompatibilityAuditRelative,
    $auditRelative
)

function Assert-R24D8 {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "QSDK-R24D8 freeze: $Code" }
}

function Get-R24D8Path {
    param([Parameter(Mandatory)][string]$Relative)
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
}

function Get-R24D8Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

function Get-R24D8Git {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D8 ($LASTEXITCODE -eq 0) (
        "git_$($Arguments -join '_'):$($output -join '|')"
    )
    return ($output -join "`n").Trim()
}

function Copy-R24D8Value {
    param([Parameter(Mandatory)]$Value)
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-R24D8Contract {
    param([Parameter(Mandatory)][hashtable]$Contract)
    Assert-R24D8 (
        [string]$Contract.schema_version -ceq
        "sporespore_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_preregistration_v1"
    ) "schema_version"
    Assert-R24D8 ([string]$Contract.gate_id -ceq "QSDK-R24D8") "gate_id"
    Assert-R24D8 ([string]$Contract.question_class -ceq "development") (
        "question_class"
    )
    Assert-R24D8 (
        [string]$Contract.status -ceq
        "prospectively_declared_active_step_snapshot_successor_zero_world_gate_pending_physical_execution_forbidden"
    ) "status"
    Assert-R24D8 (
        -not [string]::IsNullOrWhiteSpace([string]$Contract.question) -and
        -not [string]::IsNullOrWhiteSpace([string]$Contract.purpose)
    ) "question_and_purpose"

    $predecessor = [hashtable]$Contract.predecessor_boundary
    Assert-R24D8 (
        [string]$predecessor.gate_id -ceq "QSDK-R24D7" -and
        [string]$predecessor.closure_id -ceq "QSDK-R24D7-PH1-CLOSURE" -and
        [string]$predecessor.closure_path -ceq $predecessorClosureRelative -and
        [string]$predecessor.closure_raw_sha256 -ceq
            "sha256:6a71d1051bea9d1b47cb6b4b9ecc5550ef38e0f49cde2495f1815e5f83b27702" -and
        [string]$predecessor.closure_audit_path -ceq
            $predecessorClosureAuditRelative -and
        [string]$predecessor.closure_audit_raw_sha256 -ceq
            "sha256:f715f3a9e44abcd660db4fb0900c921c39b7de6bac5e0fd3d3b3167cff288cb3" -and
        [string]$predecessor.result_class -ceq
            "invalid_development_result_no_characterization" -and
        [int]$predecessor.world_attempt_count -eq 1 -and
        [int]$predecessor.world_build_count -eq 1 -and
        [int]$predecessor.physics_step_count -eq 20 -and
        [int]$predecessor.retained_raw_sample_count -eq 68 -and
        [bool]$predecessor.same_source_repair_or_rerun_forbidden -and
        -not [bool]$predecessor.raw_numerical_telemetry_promotable -and
        -not [bool]$predecessor.source_control_evaluator_worker_result_or_interpretation_rewritten
    ) "predecessor_boundary"

    $parent = [hashtable]$Contract.parent_measurement_source
    Assert-R24D8 (
        [string]$parent.gate_id -ceq "QSDK-R24D3" -and
        [string]$parent.base_patch_path -ceq $basePatchRelative -and
        [string]$parent.base_patch_raw_sha256 -ceq
            "sha256:f067543bc6237a38c0c0935a56b3bbebcd318dc6d82cec1321ea5d52e45dae2f" -and
        -not [bool]$parent.signed_impulse_and_work_semantics_changed -and
        -not [bool]$parent.parent_profile_promoted -and
        -not [bool]$parent.parent_result_reuse_authority_imported
    ) "parent_measurement_source"

    $runtime = [hashtable]$Contract.prospective_runtime_source
    $sourceFiles = @($runtime.source_files)
    Assert-R24D8 (
        [string]$runtime.godot_source_commit -ceq $expectedGodotCommit -and
        [string]$runtime.combined_patch_path -ceq $patchRelative -and
        [string]$runtime.combined_patch_raw_sha256 -ceq
            "sha256:$expectedPatchHash" -and
        [long]$runtime.combined_patch_byte_length -eq 18593 -and
        [int]$runtime.patched_file_count -eq 10 -and
        $sourceFiles.Count -eq 10 -and
        (@($sourceFiles | ForEach-Object { [string]$_.path }) -join "|") -ceq
            ($expectedPatchedPaths -join "|") -and
        [bool]$runtime.base_measurement_patch_preserved_inside_combined_patch -and
        -not [bool]$runtime.actuator_semantics_changed -and
        -not [bool]$runtime.solver_order_changed -and
        -not [bool]$runtime.body_contact_or_limit_semantics_changed -and
        -not [bool]$runtime.configured_limit_relabelled_as_applied_effort -and
        -not [bool]$runtime.source_tree_substitution_allowed -and
        -not [bool]$runtime.runtime_binary_substitution_allowed
    ) "prospective_runtime_source"

    $timing = [hashtable]$Contract.active_step_snapshot_semantics
    Assert-R24D8 (
        [string]$timing.receipt_schema -ceq
            "sporespore.godot_jolt_hinge_motor_telemetry.v2" -and
        [int]$timing.receipt_field_count -eq 15 -and
        (@($timing.new_fields) -join "|") -ceq (
            "capture_space_step_sequence|read_space_step_sequence|" +
            "captured_during_active_step|snapshot_is_current_space_step"
        ) -and
        -not [bool]$timing.invalid_read_synthesizes_zero -and
        -not [bool]$timing.stale_read_synthesizes_fresh_data
    ) "active_step_snapshot_semantics"

    $sources = [hashtable]$Contract.prospective_sources
    $expectedSources = [ordered]@{
        rig_path = $rigRelative
        worker_path = $workerRelative
        evaluator_path = $evaluatorRelative
        freeze_audit_path = $auditRelative
        supervisor_path = $supervisorRelative
        validation_manifest_path = $manifestRelative
        precommit_diagnostics_path = $precommitDiagnosticsRelative
    }
    foreach ($entry in $expectedSources.GetEnumerator()) {
        Assert-R24D8 (
            [string]$sources[$entry.Key] -ceq [string]$entry.Value
        ) "source_path_$($entry.Key)"
    }
    Assert-R24D8 (
        [bool]$sources.all_sources_must_be_committed_pushed_and_git_blob_bound_before_physics -and
        [bool]$sources.complete_zero_world_gate_required_before_physics -and
        [bool]$sources.single_global_operation_lock_required -and
        -not [bool]$sources.same_source_physical_rerun_allowed
    ) "source_guards"

    $fixture = [hashtable]$Contract.finite_physical_question
    Assert-R24D8 (
        [string]$fixture.fixture_id -ceq
            "QSDK.R24D8.godot_jolt_active_step_snapshot_timing.v1" -and
        [int]$fixture.world_count -eq 1 -and
        [int]$fixture.isolated_hinge_count -eq 1 -and
        [int]$fixture.dynamic_body_count -eq 1 -and
        [int]$fixture.static_parent_count -eq 1 -and
        [int]$fixture.maximum_physics_step_count -eq 8 -and
        [int]$fixture.fresh_active_sample_count -eq 4 -and
        [int]$fixture.sleeping_stale_sample_count -eq 4 -and
        [int]$fixture.retained_sample_count -eq 8 -and
        [int]$fixture.contact_count -eq 0 -and
        [int]$fixture.direct_force_write_count -eq 0 -and
        [int]$fixture.direct_torque_write_count -eq 0 -and
        [int]$fixture.direct_impulse_write_count -eq 0 -and
        [int]$fixture.post_activation_transform_write_count -eq 0 -and
        [int]$fixture.declared_sleep_input_write_count -eq 1 -and
        [int]$fixture.pre_sample_physics_frame_count -eq 1 -and
        -not [string]::IsNullOrWhiteSpace([string]$fixture.sample_read_timing) -and
        [int]$fixture.terminal_physics_server_deactivation_count -eq 1 -and
        -not [string]::IsNullOrWhiteSpace(
            [string]$fixture.terminal_deactivation_timing
        ) -and
        [int]$fixture.outcome_dependent_early_stop_count -eq 0 -and
        [int]$fixture.same_source_repeat_count -eq 0 -and
        -not [bool]$fixture.selection_or_threshold_tuning_from_r24d7_raw_values
    ) "finite_physical_question"

    $evaluation = [hashtable]$Contract.exact_structural_evaluation
    Assert-R24D8 (
        [int]$evaluation.empirical_acceptance_threshold_count -eq 0 -and
        [int]$evaluation.superiority_margin_count -eq 0 -and
        [int]$evaluation.equivalence_or_non_inferiority_margin_count -eq 0 -and
        [int]$evaluation.validation_cohort_identity_count -eq 0 -and
        [int]$evaluation.population_claim_count -eq 0 -and
        @($evaluation.fresh_invariants).Count -eq 6 -and
        @($evaluation.sleeping_stale_invariants).Count -eq 6 -and
        -not [string]::IsNullOrWhiteSpace([string]$evaluation.adequacy_argument)
    ) "evaluation_adequacy"

    $zero = [hashtable]$Contract.complete_zero_world_gate
    Assert-R24D8 (
        @($zero.required_stages).Count -eq 7 -and
        [bool]$zero.synthetic_report_declares_physical_counts_for_shape_only -and
        -not [bool]$zero.synthetic_report_is_physical_evidence -and
        [int]$zero.required_actual_world_attempt_count -eq 0 -and
        [int]$zero.required_actual_world_build_count -eq 0 -and
        [int]$zero.required_actual_solver_step_count -eq 0 -and
        [bool]$zero.negative_controls_must_run_before_physics -and
        -not [bool]$zero.physical_execution_authorized_before_gate_pass
    ) "complete_zero_world_gate"

    $claims = [hashtable]$Contract.claims
    Assert-R24D8 (
        [bool]$claims.active_step_snapshot_source_implemented -and
        [bool]$claims.development_incremental_compile_observed -and
        -not [bool]$claims.complete_zero_world_gate_passed -and
        -not [bool]$claims.physical_timing_question_executed -and
        -not [bool]$claims.active_step_capture_observed_physically -and
        -not [bool]$claims.sleeping_stale_preservation_observed_physically -and
        -not [bool]$claims.native_numerical_telemetry_characterized -and
        -not [bool]$claims.instrumented_profile_promoted -and
        -not [bool]$claims.recovery_world_opened -and
        -not [bool]$claims.prone_to_standing_world_opened -and
        -not [bool]$claims.turning_claim_changed -and
        -not [bool]$claims.cross_engine_equivalence_claimed -and
        -not [bool]$claims.physical_acceptance_authority -and
        -not [bool]$claims.release_authority
    ) "claims"
}

function Test-R24D8PatchSemantics {
    param([Parameter(Mandatory)][string]$Text)
    $required = @(
        "GetMotorTelemetrySequence() const",
        "GetTotalLambdaMotor()",
        "mPositiveMotorWork += work;",
        "mAbsorbedMotorWork -= work;",
        "virtual void capture_post_step_telemetry(uint64_t p_space_step_sequence, float p_space_step_s) {}",
        "LocalVector<JoltJoint3D *> joints;",
        "uint64_t step_sequence = 0;",
        "joint->capture_post_step_telemetry(step_sequence, p_step);",
        "if (unlikely(++step_sequence == 0))",
        "joints.push_back(p_joint);",
        "joints.erase(p_joint);",
        "MotorTelemetry motor_telemetry_snapshot;",
        "bool motor_telemetry_snapshot_valid = false;",
        "space != nullptr && space->is_stepping()",
        "p_space_step_sequence == 0",
        "solver_step_s != p_space_step_s",
        "sequence == motor_telemetry_snapshot.sequence",
        "motor_telemetry_snapshot.capture_space_step_sequence = p_space_step_sequence;",
        "motor_telemetry_snapshot.captured_during_active_step = captured_during_active_step;",
        "r_telemetry = motor_telemetry_snapshot;",
        "r_telemetry.read_space_step_sequence = space->get_step_sequence();",
        "motor_telemetry_snapshot = MotorTelemetry();",
        "space == nullptr || space->is_stepping()",
        'result["schema"] = "sporespore.godot_jolt_hinge_motor_telemetry.v2";',
        'result["capture_space_step_sequence"]',
        'result["read_space_step_sequence"]',
        'result["captured_during_active_step"]',
        'result["snapshot_is_current_space_step"]'
    )
    foreach ($marker in $required) {
        if (-not $Text.Contains($marker, [StringComparison]::Ordinal)) {
            return $false
        }
    }
    $stepStart = $Text.IndexOf(
        "void JoltSpace3D::step(float p_step)",
        [StringComparison]::Ordinal
    )
    if ($stepStart -lt 0) { return $false }
    $steppingTrue = $Text.IndexOf("stepping = true;", $stepStart)
    $capture = $Text.IndexOf("_capture_joint_telemetry(p_step);", $stepStart)
    $post = $Text.IndexOf("_post_step(p_step);", $stepStart)
    $steppingFalse = $Text.IndexOf("stepping = false;", $stepStart)
    return (
        $stepStart -lt $steppingTrue -and
        $steppingTrue -lt $capture -and
        $capture -lt $post -and
        $post -lt $steppingFalse
    )
}

function Test-R24D8FirstOfficialFailure {
    param([Parameter(Mandatory)][hashtable]$Record)
    try {
        $source = [hashtable]$Record.source
        $external = [hashtable]$Record.external_source
        $attempt = [hashtable]$Record.attempt
        $failure = [hashtable]$Record.failure
        $artifacts = @($Record.retained_artifacts)
        $claims = [hashtable]$Record.claims
        return (
            [string]$Record.schema_version -ceq
                "sporespore_qsdk_r24d8_first_official_zero_world_qualification_failure_v1" -and
            [string]$Record.record_id -ceq
                "QSDK-R24D8-ZW1-INCOMPLETE-CLOSURE" -and
            [string]$Record.gate_id -ceq "QSDK-R24D8" -and
            [string]$Record.question_class -ceq
                "non_physical_source_conformance_incomplete" -and
            [string]$Record.status -ceq
                "closed_incomplete_predecessor_live_source_audit_mismatch_before_cold_build_or_worker" -and
            [string]$source.commit -ceq
                "49c643dec947088bffbec4703c3fe076b9768a9f" -and
            [string]$source.tree_git_oid -ceq
                "9e3c0a6fa1934bd26a027ec5ee2e77c3039c4d51" -and
            [bool]$source.clean_pushed_and_live_remote_equal_before_attempt -and
            [string]$source.validation_manifest_raw_sha256 -ceq
                "sha256:bdd228d75515f3fc771b9af5068d55484cbe110a41fad63f981b6edcabbddefd" -and
            [string]$source.validation_manifest_git_blob_oid -ceq
                "de92299e5bed930a6bd0e1a9129830de0d3d5f8e" -and
            -not [bool]$source.same_source_official_zero_world_rerun_allowed -and
            [string]$external.commit -ceq $expectedGodotCommit -and
            [string]$external.combined_patch_raw_sha256 -ceq
                "sha256:$expectedPatchHash" -and
            [int]$external.patched_file_count -eq 10 -and
            -not [bool]$external.changed_by_attempt -and
            [string]$attempt.mode -ceq "ZeroWorld" -and
            [string]$attempt.run_root -ceq
                "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d8-active-step-snapshot/zero-world/20260816T191446058Z-49c643de-9629982deb74" -and
            [int]$attempt.declared_stage_count -eq 5 -and
            [int]$attempt.attempted_stage_count -eq 1 -and
            [int]$attempt.passed_stage_count -eq 0 -and
            [int]$attempt.failed_stage_count -eq 1 -and
            [int]$attempt.first_failed_stage_index -eq 1 -and
            [string]$attempt.first_failed_stage -ceq
                "immutable_r24d7_closure" -and
            [string]$attempt.first_failed_gate_id -ceq
                "patched_server_live_source" -and
            [int]$attempt.predecessor_closure_audit_launch_count -eq 1 -and
            [int]$attempt.r24d8_freeze_audit_launch_count -eq 0 -and
            [int]$attempt.cold_cleanup_launch_count -eq 0 -and
            [int]$attempt.cold_build_launch_count -eq 0 -and
            [int]$attempt.godot_process_launch_count -eq 0 -and
            [int]$attempt.worker_launch_count -eq 0 -and
            [int]$attempt.serializer_call_count -eq 0 -and
            -not [bool]$attempt.physical_attempt_created -and
            [int]$attempt.world_attempt_count -eq 0 -and
            [int]$attempt.world_build_count -eq 0 -and
            [int]$attempt.solver_step_count -eq 0 -and
            [string]$failure.classification -ceq
                "incomplete_static_dependency_invocation_failure" -and
            -not [bool]$failure.r24d7_closure_or_audit_changed -and
            -not [bool]$failure.r24d8_patch_or_runtime_rejected_by_its_own_audit -and
            -not [bool]$failure.r24d8_timing_mechanism_exercised -and
            -not [bool]$failure.r24d8_binding_or_serializer_result_exists -and
            -not [bool]$failure.native_telemetry_result_exists -and
            [bool]$failure.maintenance_successor_required -and
            $artifacts.Count -eq 2 -and
            [string]$artifacts[0].role -ceq
                "failed_predecessor_closure_stage_log" -and
            [string]$artifacts[0].raw_sha256 -ceq
                "sha256:0fc615d4b1c71eea523a69e9801725ff540720be37b4ea37840964a1af41400c" -and
            [long]$artifacts[0].byte_length -eq 350 -and
            [string]$artifacts[1].role -ceq "supervisor_failure_record" -and
            [string]$artifacts[1].raw_sha256 -ceq
                "sha256:1e6cd61ae84a4f89b94720cc273f47bea96645877b60fe28eaf9a3786bf1661e" -and
            [long]$artifacts[1].byte_length -eq 1142 -and
            [int]$Record.retained_file_count -eq 2 -and
            [int]$Record.retained_unique_digest_count -eq 2 -and
            [int]$Record.content_addressed_file_count -eq 2 -and
            -not [bool]$claims.complete_zero_world_gate_passed -and
            -not [bool]$claims.physical_timing_question_executed -and
            -not [bool]$claims.active_step_capture_observed_physically -and
            -not [bool]$claims.sleeping_stale_preservation_observed_physically -and
            -not [bool]$claims.native_numerical_telemetry_characterized -and
            -not [bool]$claims.instrumented_profile_promoted -and
            -not [bool]$claims.recovery_world_opened -and
            -not [bool]$claims.prone_to_standing_world_opened -and
            -not [bool]$claims.turning_claim_changed -and
            -not [bool]$claims.cross_engine_equivalence_claimed -and
            -not [bool]$claims.physical_acceptance_authority -and
            -not [bool]$claims.release_authority
        )
    } catch {
        return $false
    }
}

function Test-R24D8MaintenanceDiagnostics {
    param([Parameter(Mandatory)][hashtable]$Record)
    try {
        $attempts = @($Record.attempts)
        $fourth = [hashtable]$attempts[3]
        $fifth = [hashtable]$attempts[4]
        $sixth = [hashtable]$attempts[5]
        $adequacy = [hashtable]$Record.adequacy
        $counts = [hashtable]$Record.actual_counts
        $claims = [hashtable]$Record.claims
        return (
            [string]$Record.schema_version -ceq
                "sporespore_qsdk_r24d8_maintenance_precommit_diagnostics_v1" -and
            [string]$Record.gate_id -ceq "QSDK-R24D8" -and
            [string]$Record.question_class -ceq
                "non_physical_source_conformance_development_diagnostics" -and
            [string]$Record.status -ceq
                "complete_local_precommit_compatibility_pass_after_five_diagnostic_negatives" -and
            [int]$Record.attempt_count -eq 6 -and
            [int]$Record.negative_attempt_count -eq 5 -and
            [int]$Record.passing_attempt_count -eq 1 -and
            $attempts.Count -eq 6 -and
            (@($attempts | ForEach-Object { [int]$_.attempt_index }) -join "|") -ceq
                "1|2|3|4|5|6" -and
            (@($attempts | Where-Object { [bool]$_.passed }).Count -eq 1) -and
            [string]$fourth.first_failed_gate -ceq "patched_server_live_source" -and
            [bool]$fourth.historical_r24d7_audit_invoked -and
            -not [bool]$fourth.historical_r24d7_audit_passed -and
            [bool]$fourth.historical_source_view_removed -and
            [string]$fifth.first_failed_gate -ceq
                "historical_patched_server_identity" -and
            [int]$fifth.historical_raw_lf_projection_file_count -eq 7 -and
            [bool]$sixth.passed -and
            [string]$sixth.result -ceq
                "immutable_r24d7_audit_passed_in_exact_historical_source_view" -and
            [int]$sixth.historical_patch_file_count -eq 7 -and
            [int]$sixth.historical_raw_lf_projection_file_count -eq 7 -and
            [int]$sixth.historical_source_view_file_count -eq 10 -and
            [bool]$sixth.historical_r24d7_audit_passed -and
            [bool]$sixth.historical_source_view_removed -and
            [int]$sixth.godot_worktree_count_before -eq 1 -and
            [int]$sixth.godot_worktree_count_after -eq 1 -and
            -not [bool]$adequacy.immutable_r24d7_closure_or_audit_changed -and
            -not [bool]$adequacy.live_r24d8_external_source_temporarily_rewritten -and
            [bool]$adequacy.historical_source_view_derived_only_from_pinned_upstream_commit_and_frozen_r24d7_patch -and
            [bool]$adequacy.historical_r24d7_audit_executed_unchanged_on_passing_attempt -and
            [bool]$adequacy.live_r24d8_source_remains_owned_by_r24d8_freeze_audit -and
            -not [bool]$adequacy.threshold_selector_evaluator_worker_rig_patch_or_physical_question_changed -and
            [int]$counts.world_attempt_count -eq 0 -and
            [int]$counts.world_build_count -eq 0 -and
            [int]$counts.solver_step_count -eq 0 -and
            [int]$counts.physical_world_count -eq 0 -and
            -not [bool]$claims.complete_zero_world_gate_passed -and
            -not [bool]$claims.physical_timing_question_executed -and
            -not [bool]$claims.native_numerical_telemetry_characterized -and
            -not [bool]$claims.instrumented_profile_promoted -and
            -not [bool]$claims.recovery_world_opened -and
            -not [bool]$claims.prone_to_standing_world_opened -and
            -not [bool]$claims.turning_claim_changed -and
            -not [bool]$claims.cross_engine_equivalence_claimed -and
            -not [bool]$claims.physical_acceptance_authority -and
            -not [bool]$claims.release_authority
        )
    } catch {
        return $false
    }
}

function Test-R24D8CompatibilityAuditSemantics {
    param([Parameter(Mandatory)][string]$Text)
    $required = @(
        "6a71d1051bea9d1b47cb6b4b9ecc5550ef38e0f49cde2495f1815e5f83b27702",
        "f715f3a9e44abcd660db4fb0900c921c39b7de6bac5e0fd3d3b3167cff288cb3",
        '"worktree", "add", "--detach", "--no-checkout"',
        '"sparse-checkout", "set", "--no-cone"',
        '"apply", "--whitespace=nowarn", "--", $patchPath',
        '$generatedText.Replace("`r`n", "`n")',
        '$normalizedCrLfFileCount -eq 7',
        '-GodotSourceRoot $historicalSourceRoot',
        'worktree remove --force -- $historicalSourceRoot',
        'QSDK_R24D8_PREDECESSOR_EVIDENCE_COMPATIBILITY_PASS',
        'historical_source_view_removed = $true',
        'world_attempt_count = 0',
        'world_build_count = 0',
        'solver_step_count = 0'
    )
    foreach ($marker in $required) {
        if (-not $Text.Contains($marker, [StringComparison]::Ordinal)) {
            return $false
        }
    }
    return $true
}

foreach ($relative in @(
    $contractRelative,
    $manifestRelative,
    $precommitDiagnosticsRelative,
    $firstOfficialFailureRelative,
    $maintenanceDiagnosticsRelative,
    $basePatchRelative,
    $patchRelative,
    $rigRelative,
    $workerRelative,
    $evaluatorRelative,
    $supervisorRelative,
    $predecessorCompatibilityAuditRelative,
    $auditRelative,
    $predecessorClosureRelative,
    $predecessorClosureAuditRelative,
    ".gitattributes"
)) {
    Assert-R24D8 (Test-Path -LiteralPath (Get-R24D8Path $relative) -PathType Leaf) (
        "missing_source:$relative"
    )
}

$root = Get-R24D8Git -Root $repoRoot -Arguments @("rev-parse", "--show-toplevel")
$remote = Get-R24D8Git -Root $repoRoot -Arguments @("remote", "get-url", "origin")
Assert-R24D8 ([IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot) "repo_root"
Assert-R24D8 ($repoRoot -ceq $expectedRepoRoot) "script_root"
Assert-R24D8 ($remote -ceq $expectedRemote) "repo_remote"

$contract = Get-Content -Raw -LiteralPath (Get-R24D8Path $contractRelative) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D8Contract $contract

$contractMutations = @(
    [ordered]@{ name = "schema"; apply = { param($v) $v.schema_version = "bad" } },
    [ordered]@{ name = "gate"; apply = { param($v) $v.gate_id = "QSDK-R24D7" } },
    [ordered]@{ name = "class"; apply = { param($v) $v.question_class = "finite_decision" } },
    [ordered]@{ name = "status"; apply = { param($v) $v.status = "physical_open" } },
    [ordered]@{ name = "predecessor"; apply = { param($v) $v.predecessor_boundary.closure_id = "bad" } },
    [ordered]@{ name = "parent_patch"; apply = { param($v) $v.parent_measurement_source.base_patch_raw_sha256 = "sha256:bad" } },
    [ordered]@{ name = "combined_patch"; apply = { param($v) $v.prospective_runtime_source.combined_patch_raw_sha256 = "sha256:bad" } },
    [ordered]@{ name = "actuator_change"; apply = { param($v) $v.prospective_runtime_source.actuator_semantics_changed = $true } },
    [ordered]@{ name = "schema_fields"; apply = { param($v) $v.active_step_snapshot_semantics.receipt_field_count = 14 } },
    [ordered]@{ name = "rerun"; apply = { param($v) $v.prospective_sources.same_source_physical_rerun_allowed = $true } },
    [ordered]@{ name = "diagnostics"; apply = { param($v) $v.prospective_sources.precommit_diagnostics_path = "bad" } },
    [ordered]@{ name = "worlds"; apply = { param($v) $v.finite_physical_question.world_count = 2 } },
    [ordered]@{ name = "samples"; apply = { param($v) $v.finite_physical_question.retained_sample_count = 7 } },
    [ordered]@{ name = "terminal_step"; apply = { param($v) $v.finite_physical_question.terminal_physics_server_deactivation_count = 0 } },
    [ordered]@{ name = "threshold"; apply = { param($v) $v.exact_structural_evaluation.empirical_acceptance_threshold_count = 1 } },
    [ordered]@{ name = "cohort"; apply = { param($v) $v.exact_structural_evaluation.validation_cohort_identity_count = 1 } },
    [ordered]@{ name = "zero_world"; apply = { param($v) $v.complete_zero_world_gate.required_actual_world_build_count = 1 } },
    [ordered]@{ name = "promotion"; apply = { param($v) $v.claims.instrumented_profile_promoted = $true } }
)
$contractMutationPasses = 0
foreach ($case in $contractMutations) {
    $mutated = Copy-R24D8Value $contract
    & $case.apply $mutated
    try {
        Assert-R24D8Contract $mutated
    } catch {
        $contractMutationPasses += 1
        continue
    }
    throw "QSDK-R24D8 freeze: contract mutation passed: $($case.name)"
}
Assert-R24D8 ($contractMutationPasses -eq $contractMutations.Count) (
    "contract_mutation_count"
)

$firstOfficialFailure = Get-Content -Raw -LiteralPath (
    Get-R24D8Path $firstOfficialFailureRelative
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D8 (Test-R24D8FirstOfficialFailure $firstOfficialFailure) (
    "first_official_zero_world_failure_identity"
)
$failedSourceCommit = [string]$firstOfficialFailure.source.commit
$failedSourceTree = Get-R24D8Git -Root $repoRoot -Arguments @(
    "rev-parse", "$failedSourceCommit`^{tree}"
)
$failedManifestBlob = Get-R24D8Git -Root $repoRoot -Arguments @(
    "rev-parse", "$failedSourceCommit`:$manifestRelative"
)
Assert-R24D8 (
    $failedSourceTree -ceq [string]$firstOfficialFailure.source.tree_git_oid -and
    $failedManifestBlob -ceq
        [string]$firstOfficialFailure.source.validation_manifest_git_blob_oid
) "first_official_zero_world_failure_git_identity"

$failedRunRoot = [IO.Path]::GetFullPath(
    [string]$firstOfficialFailure.attempt.run_root
)
Assert-R24D8 (
    $failedRunRoot.StartsWith(
        $expectedEvidenceRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Test-Path -LiteralPath $failedRunRoot -PathType Container) -and
    @(Get-ChildItem -LiteralPath $failedRunRoot -File).Count -eq 2
) "first_official_zero_world_failure_run_root"
$expectedFailureArtifactRoles = @(
    "failed_predecessor_closure_stage_log",
    "supervisor_failure_record"
)
$failureArtifacts = @($firstOfficialFailure.retained_artifacts)
Assert-R24D8 (
    (@($failureArtifacts | ForEach-Object { [string]$_.role }) -join "|") -ceq
        ($expectedFailureArtifactRoles -join "|")
) "first_official_zero_world_failure_artifact_roles"
foreach ($artifactValue in $failureArtifacts) {
    $artifact = [hashtable]$artifactValue
    $artifactPath = [IO.Path]::GetFullPath([string]$artifact.path)
    $casPath = [IO.Path]::GetFullPath([string]$artifact.cas_payload_path)
    $digest = ([string]$artifact.raw_sha256).Substring(7)
    $expectedCasPath = [IO.Path]::GetFullPath((Join-Path (
        Join-Path $expectedEvidenceRoot "artifacts\sha256\$digest"
    ) "payload.bin"))
    Assert-R24D8 (
        $artifactPath.StartsWith(
            $failedRunRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        $casPath -ceq $expectedCasPath -and
        (Test-Path -LiteralPath $artifactPath -PathType Leaf) -and
        (Test-Path -LiteralPath $casPath -PathType Leaf) -and
        (Get-R24D8Sha256 $artifactPath) -ceq $digest -and
        (Get-R24D8Sha256 $casPath) -ceq $digest -and
        (Get-Item -LiteralPath $artifactPath).Length -eq
            [long]$artifact.byte_length -and
        (Get-Item -LiteralPath $casPath).Length -eq
            [long]$artifact.byte_length
    ) "first_official_zero_world_failure_artifact:$([string]$artifact.role)"
}

$firstFailureMutations = @(
    { param($v) $v.source.same_source_official_zero_world_rerun_allowed = $true },
    { param($v) $v.attempt.passed_stage_count = 1 },
    { param($v) $v.attempt.worker_launch_count = 1 },
    { param($v) $v.attempt.world_attempt_count = 1 },
    { param($v) $v.failure.classification = "complete_zero_world_negative" },
    { param($v) $v.failure.maintenance_successor_required = $false },
    { param($v) $v.retained_artifacts[0].raw_sha256 = "sha256:bad" },
    { param($v) $v.claims.complete_zero_world_gate_passed = $true }
)
$firstFailureMutationPasses = 0
foreach ($mutation in $firstFailureMutations) {
    $candidate = Copy-R24D8Value $firstOfficialFailure
    & $mutation $candidate
    if (-not (Test-R24D8FirstOfficialFailure $candidate)) {
        $firstFailureMutationPasses += 1
    }
}
Assert-R24D8 (
    $firstFailureMutationPasses -eq $firstFailureMutations.Count
) "first_official_zero_world_failure_mutation_count"

$maintenanceDiagnostics = Get-Content -Raw -LiteralPath (
    Get-R24D8Path $maintenanceDiagnosticsRelative
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D8 (Test-R24D8MaintenanceDiagnostics $maintenanceDiagnostics) (
    "maintenance_diagnostics_identity"
)
$maintenanceMutations = @(
    { param($v) $v.attempt_count = 5 },
    { param($v) $v.negative_attempt_count = 4 },
    { param($v) $v.attempts[3].historical_r24d7_audit_passed = $true },
    { param($v) $v.attempts[5].passed = $false },
    { param($v) $v.adequacy.live_r24d8_external_source_temporarily_rewritten = $true },
    { param($v) $v.actual_counts.world_attempt_count = 1 },
    { param($v) $v.claims.complete_zero_world_gate_passed = $true }
)
$maintenanceMutationPasses = 0
foreach ($mutation in $maintenanceMutations) {
    $candidate = Copy-R24D8Value $maintenanceDiagnostics
    & $mutation $candidate
    if (-not (Test-R24D8MaintenanceDiagnostics $candidate)) {
        $maintenanceMutationPasses += 1
    }
}
Assert-R24D8 (
    $maintenanceMutationPasses -eq $maintenanceMutations.Count
) "maintenance_diagnostics_mutation_count"

$compatibilityAuditText = [IO.File]::ReadAllText(
    (Get-R24D8Path $predecessorCompatibilityAuditRelative)
)
Assert-R24D8 (
    Test-R24D8CompatibilityAuditSemantics $compatibilityAuditText
) "predecessor_compatibility_audit_semantics"
$compatibilityMarkers = @(
    "6a71d1051bea9d1b47cb6b4b9ecc5550ef38e0f49cde2495f1815e5f83b27702",
    "f715f3a9e44abcd660db4fb0900c921c39b7de6bac5e0fd3d3b3167cff288cb3",
    '"worktree", "add", "--detach", "--no-checkout"',
    '"sparse-checkout", "set", "--no-cone"',
    '"apply", "--whitespace=nowarn", "--", $patchPath',
    '$generatedText.Replace("`r`n", "`n")',
    '$normalizedCrLfFileCount -eq 7',
    '-GodotSourceRoot $historicalSourceRoot',
    'worktree remove --force -- $historicalSourceRoot',
    'QSDK_R24D8_PREDECESSOR_EVIDENCE_COMPATIBILITY_PASS',
    'historical_source_view_removed = $true',
    'world_attempt_count = 0',
    'world_build_count = 0',
    'solver_step_count = 0'
)
$compatibilityMutationPasses = 0
foreach ($marker in $compatibilityMarkers) {
    Assert-R24D8 (
        $compatibilityAuditText.Contains($marker, [StringComparison]::Ordinal)
    ) "compatibility_marker_missing:$marker"
    $mutated = $compatibilityAuditText.Replace(
        $marker,
        "R24D8_MUTATED_COMPATIBILITY_MARKER"
    )
    Assert-R24D8 (-not (Test-R24D8CompatibilityAuditSemantics $mutated)) (
        "compatibility_source_mutation_passed:$marker"
    )
    $compatibilityMutationPasses += 1
}

$diagnostics = Get-Content -Raw -LiteralPath (
    Get-R24D8Path $precommitDiagnosticsRelative
) | ConvertFrom-Json -AsHashtable -Depth 100
$diagnosticAttempts = @($diagnostics.attempts)
$diagnosticCounts = [hashtable]$diagnostics.finite_counts
Assert-R24D8 (
    [string]$diagnostics.schema_version -ceq
        "sporespore_qsdk_r24d8_precommit_zero_world_diagnostics_v1" -and
    [string]$diagnostics.record_id -ceq
        "QSDK-R24D8-PRECOMMIT-ZERO-WORLD-DIAGNOSTICS" -and
    [string]$diagnostics.question_class -ceq
        "non_physical_development_diagnostic" -and
    $diagnosticAttempts.Count -eq 3 -and
    [int]$diagnosticCounts.diagnostic_attempt_count -eq 3 -and
    [int]$diagnosticCounts.runtime_freeze_negative_count -eq 1 -and
    [int]$diagnosticCounts.synthetic_zero_world_pass_count -eq 1 -and
    [int]$diagnosticCounts.parser_attempt_count -eq 1 -and
    [int]$diagnosticCounts.parser_pass_count -eq 1 -and
    [int]$diagnosticCounts.official_zero_world_qualification_count -eq 0 -and
    [int]$diagnosticCounts.retained_file_count -eq 6 -and
    [int]$diagnosticCounts.active_physics_object_observation_count -eq 0 -and
    [int]$diagnosticCounts.world_attempt_count -eq 0 -and
    [int]$diagnosticCounts.world_build_count -eq 0 -and
    [int]$diagnosticCounts.solver_step_count -eq 0 -and
    -not [bool]$diagnostics.claims.complete_zero_world_gate_passed -and
    -not [bool]$diagnostics.claims.physical_timing_question_executed -and
    -not [bool]$diagnostics.claims.native_numerical_telemetry_characterized -and
    -not [bool]$diagnostics.claims.turning_claim_changed -and
    -not [bool]$diagnostics.claims.physical_acceptance_authority -and
    -not [bool]$diagnostics.claims.release_authority
) "precommit_diagnostics_identity"

$firstDiagnostic = [hashtable]$diagnosticAttempts[0]
$firstDiagnosticRoot = [IO.Path]::GetFullPath([string]$firstDiagnostic.run_root)
Assert-R24D8 (
    [int]$firstDiagnostic.attempt_index -eq 1 -and
    [string]$firstDiagnostic.classification -ceq
        "valid_precommit_runtime_freeze_negative_wrong_project_position_steps" -and
    [int]$firstDiagnostic.expected_position_steps -eq 7 -and
    [int]$firstDiagnostic.observed_position_steps -eq 4 -and
    -not [bool]$firstDiagnostic.runtime_freeze_passed -and
    [bool]$firstDiagnostic.binding_probe_passed -and
    -not [bool]$firstDiagnostic.invalid_rid_probe_executed -and
    -not [bool]$firstDiagnostic.synthetic_report_written -and
    -not [bool]$firstDiagnostic.evaluator_invoked -and
    [int]$firstDiagnostic.retained_file_count -eq 0 -and
    [int]$firstDiagnostic.world_attempt_count -eq 0 -and
    [int]$firstDiagnostic.world_build_count -eq 0 -and
    [int]$firstDiagnostic.solver_step_count -eq 0 -and
    (Test-Path -LiteralPath $firstDiagnosticRoot -PathType Container) -and
    @(Get-ChildItem -LiteralPath $firstDiagnosticRoot -Recurse -File).Count -eq 0
) "precommit_diagnostics_first_attempt"

$secondDiagnostic = [hashtable]$diagnosticAttempts[1]
$secondDiagnosticRoot = [IO.Path]::GetFullPath([string]$secondDiagnostic.run_root)
$diagnosticFiles = @($secondDiagnostic.retained_files)
Assert-R24D8 (
    [int]$secondDiagnostic.attempt_index -eq 2 -and
    [string]$secondDiagnostic.classification -ceq
        "valid_precommit_isolated_synthetic_zero_world_pass" -and
    [int]$secondDiagnostic.expected_position_steps -eq 7 -and
    [int]$secondDiagnostic.observed_position_steps -eq 7 -and
    [bool]$secondDiagnostic.runtime_freeze_passed -and
    [bool]$secondDiagnostic.binding_probe_passed -and
    [bool]$secondDiagnostic.invalid_rid_probe_executed -and
    [bool]$secondDiagnostic.invalid_rid_refusal_passed -and
    [bool]$secondDiagnostic.synthetic_report_written -and
    [bool]$secondDiagnostic.evaluator_invoked -and
    [bool]$secondDiagnostic.synthetic_evaluator_passed -and
    $diagnosticFiles.Count -eq 5 -and
    [int]$secondDiagnostic.retained_file_count -eq 5 -and
    [int]$secondDiagnostic.world_attempt_count -eq 0 -and
    [int]$secondDiagnostic.world_build_count -eq 0 -and
    [int]$secondDiagnostic.solver_step_count -eq 0 -and
    (Test-Path -LiteralPath $secondDiagnosticRoot -PathType Container)
) "precommit_diagnostics_second_attempt"
foreach ($diagnosticFileValue in $diagnosticFiles) {
    $diagnosticFile = [hashtable]$diagnosticFileValue
    $diagnosticPath = [IO.Path]::GetFullPath((Join-Path (
        $secondDiagnosticRoot
    ) ([string]$diagnosticFile.relative_path)))
    Assert-R24D8 (
        $diagnosticPath.StartsWith(
            $secondDiagnosticRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $diagnosticPath -PathType Leaf) -and
        [string]$diagnosticFile.raw_sha256 -ceq
            "sha256:$(Get-R24D8Sha256 $diagnosticPath)" -and
        [long]$diagnosticFile.byte_length -eq
            (Get-Item -LiteralPath $diagnosticPath).Length
    ) "precommit_diagnostic_file:$([string]$diagnosticFile.relative_path)"
}

$thirdDiagnostic = [hashtable]$diagnosticAttempts[2]
$thirdDiagnosticRoot = [IO.Path]::GetFullPath([string]$thirdDiagnostic.run_root)
$thirdDiagnosticFiles = @($thirdDiagnostic.retained_files)
Assert-R24D8 (
    [int]$thirdDiagnostic.attempt_index -eq 3 -and
    [string]$thirdDiagnostic.classification -ceq
        "valid_precommit_parser_pass_current_prospective_source" -and
    [bool]$thirdDiagnostic.check_only -and
    -not [bool]$thirdDiagnostic.worker_mode_supplied -and
    -not [bool]$thirdDiagnostic.worker_initialize_or_run_executed -and
    [string]$thirdDiagnostic.worker_raw_sha256 -ceq
        "sha256:$(Get-R24D8Sha256 (Get-R24D8Path $workerRelative))" -and
    [long]$thirdDiagnostic.worker_byte_length -eq
        (Get-Item -LiteralPath (Get-R24D8Path $workerRelative)).Length -and
    [string]$thirdDiagnostic.worker_git_blob_oid -ceq
        (Get-R24D8Git -Root $repoRoot -Arguments @(
            "hash-object", (Get-R24D8Path $workerRelative)
        )) -and
    [int]$thirdDiagnostic.semantic_exit_code -eq 0 -and
    $thirdDiagnosticFiles.Count -eq 1 -and
    [int]$thirdDiagnostic.retained_file_count -eq 1 -and
    [int]$thirdDiagnostic.world_attempt_count -eq 0 -and
    [int]$thirdDiagnostic.world_build_count -eq 0 -and
    [int]$thirdDiagnostic.solver_step_count -eq 0 -and
    (Test-Path -LiteralPath $thirdDiagnosticRoot -PathType Container)
) "precommit_diagnostics_third_attempt"
foreach ($diagnosticFileValue in $thirdDiagnosticFiles) {
    $diagnosticFile = [hashtable]$diagnosticFileValue
    $diagnosticPath = [IO.Path]::GetFullPath((Join-Path (
        $thirdDiagnosticRoot
    ) ([string]$diagnosticFile.relative_path)))
    Assert-R24D8 (
        $diagnosticPath.StartsWith(
            $thirdDiagnosticRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $diagnosticPath -PathType Leaf) -and
        [string]$diagnosticFile.raw_sha256 -ceq
            "sha256:$(Get-R24D8Sha256 $diagnosticPath)" -and
        [long]$diagnosticFile.byte_length -eq
            (Get-Item -LiteralPath $diagnosticPath).Length
    ) "precommit_parser_file:$([string]$diagnosticFile.relative_path)"
}

$patchPath = Get-R24D8Path $patchRelative
$patchText = [IO.File]::ReadAllText($patchPath).Replace("`r`n", "`n")
Assert-R24D8 ((Get-R24D8Sha256 $patchPath) -ceq $expectedPatchHash) "patch_hash"
Assert-R24D8 ((Get-Item -LiteralPath $patchPath).Length -eq 18593L) "patch_bytes"
Assert-R24D8 (
    [regex]::Matches($patchText, "(?m)^diff --git ").Count -eq 10
) "patch_file_count"
Assert-R24D8 (Test-R24D8PatchSemantics $patchText) "patch_semantics"

$sourceMarkers = @(
    "GetMotorTelemetrySequence() const",
    "GetTotalLambdaMotor()",
    "mPositiveMotorWork += work;",
    "virtual void capture_post_step_telemetry(uint64_t p_space_step_sequence, float p_space_step_s) {}",
    "LocalVector<JoltJoint3D *> joints;",
    "joint->capture_post_step_telemetry(step_sequence, p_step);",
    "space != nullptr && space->is_stepping()",
    "sequence == motor_telemetry_snapshot.sequence",
    "r_telemetry = motor_telemetry_snapshot;",
    "r_telemetry.read_space_step_sequence = space->get_step_sequence();",
    "motor_telemetry_snapshot = MotorTelemetry();",
    "space == nullptr || space->is_stepping()",
    'result["schema"] = "sporespore.godot_jolt_hinge_motor_telemetry.v2";',
    'result["capture_space_step_sequence"]',
    'result["read_space_step_sequence"]',
    'result["captured_during_active_step"]',
    'result["snapshot_is_current_space_step"]'
)
$sourceMutationPasses = 0
foreach ($marker in $sourceMarkers) {
    Assert-R24D8 ($patchText.Contains($marker, [StringComparison]::Ordinal)) (
        "source_marker_missing:$marker"
    )
    $mutated = $patchText.Replace($marker, "R24D8_MUTATED_MARKER")
    Assert-R24D8 (-not (Test-R24D8PatchSemantics $mutated)) (
        "source_mutation_passed:$marker"
    )
    $sourceMutationPasses += 1
}

$rigText = [IO.File]::ReadAllText((Get-R24D8Path $rigRelative))
foreach ($marker in @(
    'const FIXTURE_ID := "QSDK.R24D8.godot_jolt_active_step_snapshot_timing.v1"',
    "const FRESH_ACTIVE_SAMPLE_COUNT := 4",
    "const SLEEPING_STALE_SAMPLE_COUNT := 4",
    "const MAXIMUM_PHYSICS_STEP_COUNT := 8",
    "child.can_sleep = false",
    "child.sleeping = true",
    "HingeJoint3D.FLAG_ENABLE_MOTOR, true",
    '"world_attempt_count": 1',
    '"world_build_count": 1'
)) {
    Assert-R24D8 ($rigText.Contains($marker, [StringComparison]::Ordinal)) (
        "rig_marker:$marker"
    )
}
$workerText = [IO.File]::ReadAllText((Get-R24D8Path $workerRelative))
foreach ($marker in @(
    'const TELEMETRY_SCHEMA := "sporespore.godot_jolt_hinge_motor_telemetry.v2"',
    "TELEMETRY_FIELDS.size() == 15",
    '"captured_during_active_step": true',
    '"snapshot_is_current_space_step": is_current',
    '"synthetic_shape_only": evidence_kind == "synthetic_zero_world"',
    '"native_physical_observation": evidence_kind == "native_physical"',
    '"world_attempt_count": 0',
    '"world_build_count": 0',
    '"solver_step_count": 0',
    "RigScript.force_declared_sleep(rig)",
    "await physics_frame",
    "pre_sample_physics_frame_count += 1",
    "PhysicsServer3D.set_active(false)",
    '"terminal_physics_server_deactivation_count": 1',
    "QSDK_R24D8_GODOT_SUPERVISOR_TERMINATION_READY"
)) {
    Assert-R24D8 ($workerText.Contains($marker, [StringComparison]::Ordinal)) (
        "worker_marker:$marker"
    )
}
$supervisorText = [IO.File]::ReadAllText((Get-R24D8Path $supervisorRelative))
foreach ($marker in @(
    'Enter-SporeSporeLocomotionOperationLock -Role $lockRole',
    '"ls-remote", "--heads", "origin", "refs/heads/main"',
    '"-m", "SCons", "--clean"',
    'status = "consumed_before_worker_launch"',
    'same_source_rerun_allowed = $false',
    '-EvidenceKind "synthetic_zero_world"',
    '-EvidenceKind "native_physical"',
    'tests/test_qsdk_r24d8_predecessor_evidence_compatibility.ps1',
    '"-GodotRepositoryRoot", $godotRoot',
    'Test-SporeSporeStoredArtifact'
)) {
    Assert-R24D8 ($supervisorText.Contains($marker, [StringComparison]::Ordinal)) (
        "supervisor_marker:$marker"
    )
}

$pythonOutput = @(
    & $Python (Get-R24D8Path $evaluatorRelative) --self-test 2>&1
)
Assert-R24D8 ($LASTEXITCODE -eq 0) (
    "evaluator_self_test:$($pythonOutput -join '|')"
)
$evaluatorMarker = @($pythonOutput | Where-Object {
    ([string]$_).StartsWith(
        "QSDK_R24D8_EVALUATOR_SELF_TEST ",
        [StringComparison]::Ordinal
    )
})
Assert-R24D8 ($evaluatorMarker.Count -eq 1) "evaluator_marker_count"
$evaluatorReceipt = ([string]$evaluatorMarker[0]).Substring(
    "QSDK_R24D8_EVALUATOR_SELF_TEST ".Length
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D8 (
    [bool]$evaluatorReceipt.ok -and
    [int]$evaluatorReceipt.rejected_mutation_count -eq 25 -and
    [int]$evaluatorReceipt.accepted_surprising_outcome_count -eq 2 -and
    [int]$evaluatorReceipt.empirical_acceptance_threshold_count -eq 0 -and
    [int]$evaluatorReceipt.world_attempt_count -eq 0 -and
    [int]$evaluatorReceipt.world_build_count -eq 0 -and
    [int]$evaluatorReceipt.solver_step_count -eq 0 -and
    -not [bool]$evaluatorReceipt.physical_acceptance_authority -and
    -not [bool]$evaluatorReceipt.release_authority
) "evaluator_self_test_receipt"

$manifest = Get-Content -Raw -LiteralPath (Get-R24D8Path $manifestRelative) |
    ConvertFrom-Json -AsHashtable -Depth 100
$bindings = @($manifest.source_bindings)
Assert-R24D8 (
    [string]$manifest.schema_version -ceq
        "sporespore_qsdk_r24d8_active_step_snapshot_timing_validation_manifest_v1" -and
    [string]$manifest.gate_id -ceq "QSDK-R24D8" -and
    [string]$manifest.status -ceq
        "prospective_maintenance_source_bytes_bound_after_one_incomplete_official_zero_world_attempt_official_zero_world_pending" -and
    [string]$manifest.godot_source_commit -ceq $expectedGodotCommit -and
    [string]$manifest.combined_patch_raw_sha256 -ceq "sha256:$expectedPatchHash" -and
    [int]$manifest.first_official_zero_world_attempt_count -eq 1 -and
    [int]$manifest.first_official_zero_world_incomplete_count -eq 1 -and
    [string]$manifest.first_official_zero_world_source_commit -ceq
        "49c643dec947088bffbec4703c3fe076b9768a9f" -and
    -not [bool]$manifest.same_source_official_zero_world_rerun_allowed -and
    [int]$manifest.maintenance_precommit_attempt_count -eq 6 -and
    [int]$manifest.maintenance_precommit_negative_count -eq 5 -and
    [int]$manifest.maintenance_precommit_pass_count -eq 1 -and
    [int]$manifest.source_binding_count -eq $expectedManifestPaths.Count -and
    $bindings.Count -eq $expectedManifestPaths.Count -and
    (@($bindings | ForEach-Object { [string]$_.path }) -join "|") -ceq
        ($expectedManifestPaths -join "|") -and
    -not [bool]$manifest.includes_self -and
    [int]$manifest.official_zero_world_qualification_count -eq 0 -and
    [int]$manifest.world_attempt_count -eq 0 -and
    [int]$manifest.world_build_count -eq 0 -and
    [int]$manifest.solver_step_count -eq 0 -and
    -not [bool]$manifest.physical_acceptance_authority -and
    -not [bool]$manifest.release_authority
) "manifest_identity"
foreach ($bindingValue in $bindings) {
    $binding = [hashtable]$bindingValue
    $relative = [string]$binding.path
    $absolute = Get-R24D8Path $relative
    $bytes = Get-Item -LiteralPath $absolute
    $blob = Get-R24D8Git -Root $repoRoot -Arguments @("hash-object", $absolute)
    Assert-R24D8 (
        [string]$binding.raw_sha256 -ceq "sha256:$(Get-R24D8Sha256 $absolute)" -and
        [long]$binding.byte_length -eq [long]$bytes.Length -and
        [string]$binding.git_blob_oid -ceq $blob
    ) "manifest_binding:$relative"
}

$attributesText = [IO.File]::ReadAllText((Get-R24D8Path ".gitattributes"))
foreach ($rule in @(
    "sdk/recovery/r24d8_* text eol=lf",
    "sdk/run_qsdk_r24d8_* text eol=lf",
    "scripts/lab/rigs/r24d8_* text eol=lf",
    "tests/test_qsdk_r24d8_* text eol=lf",
    "tests/test_sdk_qsdk_r24d8_* text eol=lf",
    "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch text eol=lf"
)) {
    Assert-R24D8 ($attributesText.Contains($rule, [StringComparison]::Ordinal)) (
        "attributes_rule:$rule"
    )
}

$externalVerified = $false
if (-not [string]::IsNullOrWhiteSpace($GodotSourceRoot)) {
    $godotRoot = [IO.Path]::GetFullPath($GodotSourceRoot)
    $godotRemote = Get-R24D8Git -Root $godotRoot -Arguments @(
        "remote", "get-url", "origin"
    )
    $godotHead = Get-R24D8Git -Root $godotRoot -Arguments @("rev-parse", "HEAD")
    Assert-R24D8 ($godotRemote -ceq $expectedGodotRemote) "godot_remote"
    Assert-R24D8 ($godotHead -ceq $expectedGodotCommit) "godot_commit"
    $statusOutput = @(& git -C $godotRoot status --short 2>&1)
    Assert-R24D8 ($LASTEXITCODE -eq 0) "godot_status"
    $statusPaths = @($statusOutput | ForEach-Object {
        ([string]$_).Substring(3).Replace("\", "/")
    })
    Assert-R24D8 (
        (($statusPaths | Sort-Object) -join "|") -ceq
        (($expectedPatchedPaths | Sort-Object) -join "|")
    ) "godot_status_paths"
    $diffLines = @(& git -C $godotRoot diff --no-ext-diff 2>&1)
    Assert-R24D8 ($LASTEXITCODE -eq 0) "godot_diff"
    $diffText = (($diffLines -join "`n") + "`n").Replace("`r`n", "`n")
    $normalizedPatch = $patchText.TrimEnd("`n") + "`n"
    Assert-R24D8 ($diffText -ceq $normalizedPatch) "godot_diff_patch"

    # The Update call is unchanged upstream context and therefore need not be
    # present in the serialized patch hunk. Prove the load-bearing timing order
    # against the complete patched source instead of inferring it from a diff.
    $spaceSourcePath = Join-Path $godotRoot (
        "modules/jolt_physics/spaces/jolt_space_3d.cpp"
    )
    $spaceSourceText = [IO.File]::ReadAllText($spaceSourcePath).Replace("`r`n", "`n")
    $spaceStepStart = $spaceSourceText.IndexOf(
        "void JoltSpace3D::step(float p_step)",
        [StringComparison]::Ordinal
    )
    $spaceSteppingTrue = $spaceSourceText.IndexOf(
        "stepping = true;",
        $spaceStepStart
    )
    $spaceUpdate = $spaceSourceText.IndexOf(
        "physics_system->Update",
        $spaceStepStart
    )
    $spaceCapture = $spaceSourceText.IndexOf(
        "_capture_joint_telemetry(p_step);",
        $spaceStepStart
    )
    $spacePost = $spaceSourceText.IndexOf(
        "_post_step(p_step);",
        $spaceStepStart
    )
    $spaceSteppingFalse = $spaceSourceText.IndexOf(
        "stepping = false;",
        $spaceStepStart
    )
    Assert-R24D8 (
        $spaceStepStart -ge 0 -and
        $spaceStepStart -lt $spaceSteppingTrue -and
        $spaceSteppingTrue -lt $spaceUpdate -and
        $spaceUpdate -lt $spaceCapture -and
        $spaceCapture -lt $spacePost -and
        $spacePost -lt $spaceSteppingFalse
    ) "godot_active_step_capture_order"

    $reverse = @(
        & git -C $godotRoot apply --reverse --check --whitespace=error-all $patchPath 2>&1
    )
    Assert-R24D8 ($LASTEXITCODE -eq 0) (
        "godot_reverse_check:$($reverse -join '|')"
    )
    foreach ($sourceFileValue in @($contract.prospective_runtime_source.source_files)) {
        $sourceFile = [hashtable]$sourceFileValue
        $blob = Get-R24D8Git -Root $godotRoot -Arguments @(
            "rev-parse", "HEAD:$([string]$sourceFile.path)"
        )
        Assert-R24D8 (
            $blob -ceq [string]$sourceFile.base_git_blob_oid
        ) "godot_base_blob:$([string]$sourceFile.path)"
    }
    $externalVerified = $true
}

$receipt = [ordered]@{
    schema_version = (
        "sporespore_qsdk_r24d8_active_step_snapshot_timing_freeze_audit_v1"
    )
    ok = $true
    gate_id = "QSDK-R24D8"
    question_class = "development"
    result = "prospective_maintenance_timing_source_frozen_after_one_incomplete_official_zero_world_attempt"
    source_binding_count = $expectedManifestPaths.Count
    contract_mutation_count = $contractMutations.Count
    contract_mutations_rejected = $contractMutationPasses
    first_official_zero_world_attempt_count = 1
    first_official_zero_world_incomplete_count = 1
    first_official_failure_mutation_count = $firstFailureMutations.Count
    first_official_failure_mutations_rejected = $firstFailureMutationPasses
    maintenance_precommit_attempt_count = 6
    maintenance_precommit_negative_count = 5
    maintenance_precommit_pass_count = 1
    maintenance_diagnostic_mutation_count = $maintenanceMutations.Count
    maintenance_diagnostic_mutations_rejected = $maintenanceMutationPasses
    predecessor_compatibility_source_mutation_count = $compatibilityMarkers.Count
    predecessor_compatibility_source_mutations_rejected = $compatibilityMutationPasses
    source_mutation_count = $sourceMarkers.Count
    source_mutations_rejected = $sourceMutationPasses
    evaluator_mutation_count = 25
    evaluator_mutations_rejected = 25
    evaluator_surprising_outcome_count = 2
    evaluator_surprising_outcomes_accepted = 2
    patched_file_count = 10
    receipt_field_count = 15
    empirical_acceptance_threshold_count = 0
    superiority_margin_count = 0
    equivalence_or_non_inferiority_margin_count = 0
    validation_cohort_identity_count = 0
    population_claim_count = 0
    external_pinned_source_verified = $externalVerified
    complete_zero_world_gate_passed = $false
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physical_timing_question_executed = $false
    native_numerical_telemetry_characterized = $false
    instrumented_profile_promoted = $false
    recovery_world_opened = $false
    prone_to_standing_world_opened = $false
    turning_claim_changed = $false
    cross_engine_equivalence_claimed = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
Write-Output (
    "QSDK_R24D8_ACTIVE_STEP_SNAPSHOT_TIMING_FREEZE_PASS " +
    ($receipt | ConvertTo-Json -Depth 30 -Compress)
)
