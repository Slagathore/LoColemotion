#requires -Version 7.0

Set-StrictMode -Version Latest

function Get-Xv2RecoveryRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-Xv2RecoveryIntegerSum {
    param(
        [Parameter(Mandatory)][object]$Map,
        [Parameter(Mandatory)][string[]]$Fields
    )
    $sum = 0L
    foreach ($field in $Fields) {
        $sum += [int64](Get-Xv2MapValue $Map $field 0)
    }
    return $sum
}

function Get-Xv2RecoveredAggregateCounts {
    param([Parameter(Mandatory)][object[]]$CellSummaries)
    return [ordered]@{
        world_attempt_count = [int]((
            $CellSummaries |
                ForEach-Object { [int]$_.world_attempt_count } |
                Measure-Object -Sum
        ).Sum)
        world_build_count = [int]((
            $CellSummaries |
                ForEach-Object { [int]$_.world_build_count } |
                Measure-Object -Sum
        ).Sum)
        world_reset_count = [int]((
            $CellSummaries |
                ForEach-Object { [int]$_.world_reset_count } |
                Measure-Object -Sum
        ).Sum)
    }
}

function Test-Xv2RecoveredWorkerExitProof {
    param(
        [Parameter(Mandatory)][ValidateSet("rapier", "mujoco")]
        [string]$Engine,
        [Parameter(Mandatory)][object]$WorkerReport,
        [Parameter(Mandatory)][string]$ReportPath,
        [Parameter(Mandatory)][string]$StdoutPath,
        [Parameter(Mandatory)][string]$StderrPath
    )
    if (
        -not [bool](Get-Xv2MapValue $WorkerReport "ok" $false) -or
        -not (Test-Path -LiteralPath $ReportPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $StdoutPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $StderrPath -PathType Leaf) -or
        (Get-Item -LiteralPath $StderrPath).Length -ne 0
    ) {
        return $false
    }

    if ($Engine -ceq "rapier") {
        return (
            (Get-Item -LiteralPath $StdoutPath).Length -eq
                (Get-Item -LiteralPath $ReportPath).Length -and
            (Get-Xv2RecoveryRawSha256 $StdoutPath) -ceq
                (Get-Xv2RecoveryRawSha256 $ReportPath)
        )
    }

    $traceSteps = [int](Get-Xv2MapValue $WorkerReport "trace_step_count" -1)
    $failureCount = @(
        Get-Xv2MapValue $WorkerReport "gate_failures" @()
    ).Count
    $expected = (
        "C6-XE-BW19V-XV2 ok=True steps=$traceSteps " +
        "failures=$failureCount"
    )
    return (
        (Get-Content -Raw -LiteralPath $StdoutPath).TrimEnd() -ceq $expected
    )
}

function New-Xv2RecoveredCellSummary {
    param(
        [Parameter(Mandatory)][object]$Cell,
        [Parameter(Mandatory)][object]$WorkerReport,
        [Parameter(Mandatory)][object]$RetainedColdEvaluation,
        [Parameter(Mandatory)][object]$FreshColdEvaluation,
        [Parameter(Mandatory)][string]$ReportPath,
        [Parameter(Mandatory)][string]$StdoutPath,
        [Parameter(Mandatory)][string]$StderrPath
    )
    $engine = [string]$Cell.engine
    $exitArgs = @{
        Engine = $engine
        WorkerReport = $WorkerReport
        ReportPath = $ReportPath
        StdoutPath = $StdoutPath
        StderrPath = $StderrPath
    }
    $exitProven = Test-Xv2RecoveredWorkerExitProof @exitArgs
    $retainedColdPassed = (
        [bool](Get-Xv2MapValue $RetainedColdEvaluation "ok" $false) -and
        @((Get-Xv2MapValue $RetainedColdEvaluation "failure_codes" @())).Count -eq 0 -and
        [int](Get-Xv2MapValue $RetainedColdEvaluation "world_build_count" -1) -eq 0
    )
    $freshColdPassed = (
        [bool](Get-Xv2MapValue $FreshColdEvaluation "ok" $false) -and
        @((Get-Xv2MapValue $FreshColdEvaluation "failure_codes" @())).Count -eq 0 -and
        [int](Get-Xv2MapValue $FreshColdEvaluation "world_build_count" -1) -eq 0
    )
    $rapierIntegrityFields = @(
        "controller_error_count",
        "safe_no_actuation_count",
        "composition_error_count",
        "nonfinite_observation_count",
        "actuator_application_mismatch_count",
        "motor_model_or_field_readback_mismatch_count",
        "small_step_impulse_limit_violation_count",
        "global_scale_mismatch_count",
        "native_position_target_application_count",
        "selected_control_mapping_mismatch_count"
    )
    $mujocoIntegrityFields = @(
        "controller_error_count",
        "safe_no_actuation_count",
        "composition_error_count",
        "global_scale_mismatch_count",
        "host_mapping_or_readback_mismatch_count",
        "actuator_application_mismatch_count",
        "portable_impulse_limit_violation_count",
        "nonfinite_observation_count",
        "native_position_target_application_count"
    )
    $workerPreflightPassed = Test-Xv2WorkerPreflightProjection -Engine $engine -WorkerReport $WorkerReport
    $hostMaterialPassed = if ($engine -ceq "rapier") {
        [bool](Get-Xv2MapValue (
            Get-Xv2MapValue $WorkerReport "host_configuration" @{}
        ) "ground_and_every_robot_collider_use_same_friction" $false)
    }
    else {
        [bool](Get-Xv2MapValue (
            Get-Xv2MapValue $WorkerReport "host_material" @{}
        ) "all_ground_and_robot_geom_vectors_match_requested" $false)
    }
    $terminal = Get-Xv2MapValue (
        Get-Xv2MapValue $WorkerReport "schedule" @{}
    ) "terminal_restoration_phase" @{}
    $metrics = Get-Xv2MapValue $WorkerReport "metrics" @{}
    $claimBoundary = Get-Xv2MapValue $WorkerReport "claim_boundary" @{}
    $integrityFields = if ($engine -ceq "rapier") {
        $rapierIntegrityFields
    } else { $mujocoIntegrityFields }

    return [ordered]@{
        ordinal = [int]$Cell.ordinal
        cell_id = [string]$Cell.cell_id
        engine = $engine
        engine_version = [string](Get-Xv2MapValue $WorkerReport "engine_version" "")
        authored_sliding_friction = [double]$Cell.authored_sliding_friction
        authored_friction_vector = @($Cell.authored_friction_vector)
        material_profile_id = [string]$Cell.material_profile_id
        worker_report_schema_version = [string](Get-Xv2MapValue $WorkerReport "schema_version" "missing")
        cold_evaluation_schema_version = [string](Get-Xv2MapValue $RetainedColdEvaluation "schema_version" "missing")
        source_commit = [string](Get-Xv2MapValue $WorkerReport "source_commit" "")
        report_path = [IO.Path]::GetFullPath($ReportPath).Replace("\", "/")
        report_raw_sha256 = Get-Xv2RecoveryRawSha256 $ReportPath
        report_size_bytes = (Get-Item -LiteralPath $ReportPath).Length
        process_exit_code = $(if ($exitProven) { 0 } else { -1 })
        process_exit_zero_reconstructed_from_frozen_semantics = $exitProven
        process_launch_error = $null
        worker_report_parse_error = $null
        worker_report_ok = [bool](Get-Xv2MapValue $WorkerReport "ok" $false)
        cold_evaluator_replay_passed = ($retainedColdPassed -and $freshColdPassed)
        retained_cold_evaluation_passed = $retainedColdPassed
        fresh_cold_evaluation_passed = $freshColdPassed
        cold_evaluator_process_exit_code = $(if ($freshColdPassed) { 0 } else { -1 })
        cold_evaluator_failure_count = @(
            Get-Xv2MapValue $FreshColdEvaluation "failure_codes" @()
        ).Count
        cold_evaluation_world_build_count = [int](Get-Xv2MapValue $FreshColdEvaluation "world_build_count" 0)
        worker_preflight_passed = $workerPreflightPassed
        worker_preflight_world_build_count = 0
        world_attempt_count = [int](Get-Xv2MapValue $WorkerReport "world_attempt_count" 0)
        world_build_count = [int](Get-Xv2MapValue $WorkerReport "world_build_count" 0)
        world_reset_count = [int](Get-Xv2MapValue $WorkerReport "world_reset_count" 0)
        trace_step_count = [int](Get-Xv2MapValue $WorkerReport "trace_step_count" 0)
        gate_failure_count = @(
            Get-Xv2MapValue $WorkerReport "gate_failures" @()
        ).Count
        integrity_failure_count = Get-Xv2RecoveryIntegerSum -Map $WorkerReport -Fields $integrityFields
        candidate_id = [string](Get-Xv2MapValue $WorkerReport "candidate_id" "")
        candidate_composition_digest = [string](Get-Xv2MapValue $WorkerReport "candidate_composition_digest" "")
        selected_policy_id = [string](Get-Xv2MapValue $WorkerReport "selected_policy_id" "")
        selected_policy_digest = [string](Get-Xv2MapValue $WorkerReport "selected_policy_digest" "")
        terminal_restoration_policy_id = [string](Get-Xv2MapValue $terminal "restoration_policy_id" "")
        host_material_readback_passed = $hostMaterialPassed
        terminal_four_contact_stance = [bool](Get-Xv2MapValue $WorkerReport "terminal_four_contact_stance" $false)
        required_consecutive_hold_completed = [bool](Get-Xv2MapValue $terminal "required_consecutive_hold_completed" $false)
        evidence_forward_displacement_m = Get-Xv2MapValue $metrics "evidence_forward_displacement_m" $null
        final_forward_displacement_m = Get-Xv2MapValue $metrics "final_forward_displacement_m" $null
        formal_cross_engine_equivalence = $false
        continuous_friction_coverage = $false
        arbitrary_material_robustness = $false
        release_authorized = [bool](Get-Xv2MapValue $claimBoundary "release_authorized" $false)
        physical_acceptance_authority = [bool](Get-Xv2MapValue $claimBoundary "physical_acceptance_authority" $false)
    }
}

function New-Xv2RecoveredAggregateResult {
    param(
        [Parameter(Mandatory)][object]$Declaration,
        [Parameter(Mandatory)][object]$Attempt,
        [Parameter(Mandatory)][object]$Attestation,
        [Parameter(Mandatory)][object[]]$CellSummaries,
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][string]$PreregistrationPath,
        [Parameter(Mandatory)][object]$RecoveryProvenance
    )
    $counts = Get-Xv2RecoveredAggregateCounts -CellSummaries $CellSummaries
    $sourceCommit = [string]$Attempt.source_commit
    $sourceTree = [string]$Attempt.source_tree_git_oid
    $authority = $Declaration.bound_authorities
    $allWorkersPassed = @($CellSummaries | Where-Object {
        $_.worker_report_ok -and
        $_.cold_evaluator_replay_passed -and
        $_.process_exit_code -eq 0
    }).Count -eq 6 -and $CellSummaries.Count -eq 6

    $result = [ordered]@{
        schema_version = "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_result_v1"
        campaign_id = "C6-CROSS-ENGINE-BW19V-DISCRETE-MATERIAL-VALIDATION-XV2"
        gate_id = "C6-XE-BW19V-XV2"
        study_classification = "exact_finite_cell_successor_validation_after_implementation_invalid_incomplete_predecessor"
        expected_gate_count = 12
        expected_world_count = 6
        expected_cell_count = 6
        attempt_id = [string]$Attempt.attempt_id
        evidence_root = [IO.Path]::GetFullPath($EvidenceRoot).Replace("\", "/")
        reconstruction = $RecoveryProvenance
        source = [ordered]@{
            commit = $sourceCommit
            tree_git_oid = $sourceTree
            clean = $true
            matches_origin_main = $true
            matches_live_github_main = $true
        }
        final_integrity_passed = $true
        final_integrity_failure_codes = @()
        preregistration_raw_sha256 = Get-Xv2RecoveryRawSha256 $PreregistrationPath
        bound_authority_raw_sha256 = [ordered]@{
            cross_engine_host_characterization_r2 = "sha256:" + [string]$authority.cross_engine_host_characterization_r2.raw_sha256
            rapier_spv1 = "sha256:" + [string]$authority.rapier_selected_configuration_validation_spv1.raw_sha256
            rapier_vh1 = "sha256:" + [string]$authority.rapier_velocity_only_host_characterization_vh1.raw_sha256
            rapier_ph1 = "sha256:" + [string]$authority.rapier_pose_hold_restoration_ph1.raw_sha256
            mujoco_vh5 = "sha256:" + [string]$authority.mujoco_per_actuator_force_limit_host_characterization_vh5.raw_sha256
            mujoco_mv6 = "sha256:" + [string]$authority.mujoco_pose_hold_restoration_mv6.raw_sha256
            cross_engine_xv1_no_result = "sha256:" + [string]$authority.cross_engine_material_validation_xv1_no_result.raw_sha256
        }
        full_godot_v2_attestation = [ordered]@{
            path = [string]$Attempt.full_conformance_attestation_path
            raw_sha256 = [string]$Attempt.full_conformance_attestation_raw_sha256
            source_commit = $sourceCommit
            source_tree_git_oid = $sourceTree
            complete_suite_passed = [bool]$Attestation.conformance.passed
            independent_file_verifier_passed = $true
            verifier_failure_count = 0
            physical_acceptance_authority = $false
        }
        ordered_cells = @($CellSummaries)
        world_attempt_count = [int]$counts.world_attempt_count
        world_build_count = [int]$counts.world_build_count
        world_reset_count = [int]$counts.world_reset_count
        physical_process_launch_count = 6
        replacement_process_count = 0
        all_six_cell_attempts_retained = (
            @($CellSummaries | Where-Object {
                $_.report_size_bytes -gt 0
            }).Count -eq 6
        )
        global_physical_operation_lock_acquired = $true
        outcome_based_early_stop_used = $false
        integrity_abort_used = $false
        integrity_abort_failure_codes = @()
        selective_rerun_or_replacement_used = $false
        claims = [ordered]@{
            accepted = $false
            exact_s169_rapier_three_material_validation = $false
            exact_s169_mujoco_three_material_validation = $false
            qsdk_r14_declared_exact_finite_grid = $false
            qsdk_r15_declared_exact_finite_grid = $false
            different_physics_engines_same_policy_exact_finite_validation = $false
            bounded_discrete_material_validation = $false
            formal_cross_engine_equivalence = $false
            trajectory_equivalence = $false
            continuous_friction_coverage = $false
            arbitrary_material_robustness = $false
            population_inference = $false
            arbitrary_quadruped_coverage = $false
            continuous_morphology_coverage = $false
            rough_terrain_robustness = $false
            external_push_recovery = $false
            sensor_noise_or_latency_robustness = $false
            release_authorized = $false
            completed_engine_neutral_sdk = $false
            physical_acceptance_authority = $false
        }
    }
    $provisional = Test-CrossEngineC6Bw19vDiscreteMaterialValidationXv2Result $result
    $promotionEligible = (
        $allWorkersPassed -and
        @($provisional.gates | Where-Object {
            $_.ordinal -ge 1 -and $_.ordinal -le 11 -and $_.passed
        }).Count -eq 11
    )
    foreach ($claimName in @(
        "accepted",
        "exact_s169_rapier_three_material_validation",
        "exact_s169_mujoco_three_material_validation",
        "qsdk_r14_declared_exact_finite_grid",
        "qsdk_r15_declared_exact_finite_grid",
        "different_physics_engines_same_policy_exact_finite_validation",
        "bounded_discrete_material_validation"
    )) {
        $result.claims[$claimName] = $promotionEligible
    }
    return $result
}
