#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_force_based_selected_configuration_validation_spv1_closure.json"
$expectedSourceCommit = "b8e3442d88ff3e6340117bcc70e1f109ad532068"
. (Join-Path $PSScriptRoot "closed_experiment_source_audit.ps1")
$positiveClaims = @(
    "rapier_force_based_selected_configuration_validation",
    "rapier_force_based_static_convergence_characterization",
    "rapier_force_based_host_characterization",
    "validation_authority"
)
$falseClaims = @(
    "rapier_selected_policy_physical_authority",
    "rapier_locomotion_acceptance",
    "different_physics_engines",
    "cross_engine_c6",
    "friction_or_material_robustness",
    "walking_acceptance",
    "release_authorized",
    "physical_acceptance_authority",
    "completed_engine_neutral_sdk"
)

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Close {
    param(
        [double]$Actual,
        [double]$Expected,
        [double]$Tolerance,
        [string]$Message
    )

    Assert-Exact (
        [double]::IsFinite($Actual) -and
        [math]::Abs($Actual - $Expected) -le $Tolerance
    ) $Message
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)

    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Assert-HashedFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Message
    )

    Assert-Exact (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Sha256 -Path $Path) -ceq
            $ExpectedSha256.Replace("sha256:", "")
    ) $Message
}

function Get-RelativeDifference {
    param(
        [double]$First,
        [double]$Second
    )

    $scale = [math]::Max(
        ([math]::Abs($First) + [math]::Abs($Second)) * 0.5,
        [double]::Epsilon
    )
    return [math]::Abs(
        [math]::Abs($First) - [math]::Abs($Second)
    ) / $scale
}

Assert-Exact (
    Test-Path -LiteralPath $manifestPath -PathType Leaf
) "The C6-RAP-HC-SPV1 closure is missing"
$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_rapier_c6_force_based_selected_configuration_validation_closure_v1" -and
    [string]$manifest.status -ceq
        "closed_positive_exact_finite_host_validation" -and
    [string]$manifest.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-SELECTED-CONFIGURATION-VALIDATION" -and
    [string]$manifest.gate_id -ceq "C6-RAP-HC-SPV1" -and
    [string]$manifest.study_class -ceq
        "exact_finite_cell_independent_host_validation" -and
    [string]$manifest.experiment_source_commit -ceq
        $expectedSourceCommit -and
    [bool]$manifest.source_was_clean_and_equal_to_origin_main -and
    [string]$manifest.predecessor.spd1_selected_candidate_id -ceq
        "SPD1-B" -and
    -not [bool]$manifest.predecessor.spd1_selector_reinvoked -and
    [bool]$manifest.predecessor.fb1_lr1_and_cw1_remain_closed_negative -and
    [bool]$manifest.predecessor.spd1_remains_closed_positive_development -and
    [bool]$manifest.predecessor.no_predecessor_was_rerun_rethresholded_or_reclassified -and
    [bool]$manifest.immutability.same_identity_rerun_forbidden -and
    [bool]$manifest.immutability.report_rewrite_forbidden -and
    [bool]$manifest.immutability.threshold_change_forbidden -and
    [bool]$manifest.immutability.cell_grid_change_forbidden -and
    [bool]$manifest.immutability.failed_or_marginal_cell_deletion_replacement_or_averaging_forbidden -and
    [bool]$manifest.immutability.posthoc_scope_expansion_forbidden -and
    [bool]$manifest.immutability.successor_requires_new_identity
) "The C6-RAP-HC-SPV1 closure identity or immutability boundary changed"

& git -C $repoRoot cat-file -e "${expectedSourceCommit}^{commit}"
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-SPV1 experiment commit is not retained"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-SPV1 experiment commit is not an ancestor of HEAD"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0
) "origin/main could not be resolved while auditing C6-RAP-HC-SPV1"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $originMain
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-SPV1 experiment commit is not retained on origin/main"

Assert-HashedFile `
    -Path (Join-Path $repoRoot ([string]$manifest.preregistration.path)) `
    -ExpectedSha256 ([string]$manifest.preregistration.raw_sha256) `
    -Message "The frozen C6-RAP-HC-SPV1 preregistration changed"
Assert-HashedFile `
    -Path (
        Join-Path $repoRoot (
            [string]$manifest.predecessor.spd1_closure_path
        )
    ) `
    -ExpectedSha256 (
        [string]$manifest.predecessor.spd1_closure_sha256
    ) `
    -Message "The frozen C6-RAP-HC-SPD1 closure changed"
foreach ($artifactName in @("report", "stdout", "stderr")) {
    Assert-HashedFile `
        -Path ([string]$manifest.complete_attempt["${artifactName}_path"]) `
        -ExpectedSha256 (
            [string]$manifest.complete_attempt["${artifactName}_sha256"]
        ) `
        -Message "The retained C6-RAP-HC-SPV1 $artifactName changed"
}

$report = (
    Get-Content -Raw -LiteralPath (
        [string]$manifest.complete_attempt.report_path
    ) |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_force_based_selected_configuration_validation_report_v1" -and
    [bool]$report.ok -and
    [string]$report.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-SELECTED-CONFIGURATION-VALIDATION" -and
    [string]$report.gate_id -ceq "C6-RAP-HC-SPV1" -and
    [string]$report.study_class -ceq
        "exact_finite_cell_independent_host_validation" -and
    [string]$report.source.commit -ceq $expectedSourceCommit -and
    [string]$report.source.origin_main_commit -ceq
        $expectedSourceCommit -and
    [bool]$report.source.clean -and
    [bool]$report.source.matches_origin_main -and
    [string]$report.preregistration.raw_sha256 -ceq (
        "sha256:" + [string]$manifest.preregistration.raw_sha256
    ) -and
    [string]$report.predecessor.spd1_closure_raw_sha256 -ceq (
        "sha256:" + [string]$manifest.predecessor.spd1_closure_sha256
    ) -and
    [string]$report.predecessor.selected_candidate_id -ceq "SPD1-B" -and
    -not [bool]$report.predecessor.selector_reinvoked -and
    [bool]$report.preflight.ok -and
    [int]$report.preflight.world_build_count -eq 0 -and
    [bool]$report.preflight.perfect_eight_cell_result_passed_entire_gate -and
    [bool]$report.preflight.missing_cell_canary_rejected -and
    [bool]$report.preflight.wrong_allocation_canary_rejected -and
    [bool]$report.preflight.position_error_canary_rejected -and
    [bool]$report.preflight.velocity_response_canary_rejected -and
    [bool]$report.preflight.loaded_window_gap_canary_rejected -and
    [bool]$report.preflight.motor_model_mismatch_canary_rejected -and
    [string]$report.motor_model -ceq "ForceBased" -and
    [int]$report.solver_iterations -eq 16 -and
    [int]$report.num_internal_pgs_iterations -eq 3 -and
    [int]$report.num_internal_stabilization_iterations -eq 5 -and
    [int]$report.total_constraint_passes_per_small_step -eq 8
) "The retained C6-RAP-HC-SPV1 report identity changed"

$cells = @($report.cells)
$expectedCellIds = @(
    "position_target_0.55_negative",
    "position_target_0.55_positive",
    "velocity_target_1.25_negative",
    "velocity_target_1.25_positive",
    "loaded_arm_0.10_negative",
    "loaded_arm_0.10_positive",
    "loaded_arm_0.50_negative",
    "loaded_arm_0.50_positive"
)
Assert-Exact (
    $cells.Count -eq 8 -and
    (@($cells.cell_id) -join "`n") -ceq
        ($expectedCellIds -join "`n")
) "The C6-RAP-HC-SPV1 ordered cell grid changed"

$worldAttempts = 0
$worldBuilds = 0
$modelReadbacks = 0
$modelMismatches = 0
$nonfinite = 0
$impulseViolations = 0
foreach ($cell in $cells) {
    Assert-Exact (
        [bool]$cell.ok -and
        [int]$cell.solver_iterations -eq 16 -and
        [int]$cell.num_internal_pgs_iterations -eq 3 -and
        [int]$cell.num_internal_stabilization_iterations -eq 5 -and
        [int]$cell.total_constraint_passes_per_small_step -eq 8 -and
        [bool]$cell.fixed_selected_allocation_readback_passed -and
        [string]$cell.motor_model_readback -ceq "ForceBased" -and
        [int]$cell.motor_model_readback_count -eq 1 -and
        [int]$cell.motor_model_mismatch_count -eq 0 -and
        [int]$cell.nonfinite_value_count -eq 0 -and
        [int]$cell.step_impulse_limit_violation_count -eq 0 -and
        [bool]$cell.force_limit_passed -and
        [bool]$cell.finite_terminal_values -and
        [int]$cell.world_attempt_count -eq 1 -and
        [int]$cell.world_build_count -eq 1 -and
        [bool]$cell.independent_validation_evidence -and
        [bool]$cell.validation_authority -and
        -not [bool]$cell.physical_acceptance_authority
    ) "A retained C6-RAP-HC-SPV1 cell changed its shared integrity boundary"
    $worldAttempts += [int]$cell.world_attempt_count
    $worldBuilds += [int]$cell.world_build_count
    $modelReadbacks += [int]$cell.motor_model_readback_count
    $modelMismatches += [int]$cell.motor_model_mismatch_count
    $nonfinite += [int]$cell.nonfinite_value_count
    $impulseViolations += [int]$cell.step_impulse_limit_violation_count
}

$positionCells = @(
    $cells | Where-Object {
        [string]$_.cell_kind -ceq "unloaded_position_validation"
    }
)
Assert-Exact (
    $positionCells.Count -eq 2 -and
    (@($positionCells.target_position_rad) -join ",") -ceq
        "-0.550000011920929,0.550000011920929" -and
    @($positionCells | Where-Object {
        [string]$_.schema_version -cne
            "sporespore_rapier_force_based_selected_configuration_position_validation_cell_v1" -or
        -not [bool]$_.position_response_passed -or
        -not [bool]$_.target_and_final_position_sign_match -or
        [double]$_.absolute_relative_position_error -gt 0.01 -or
        [int]$_.observation_outer_steps -ne 240
    }).Count -eq 0
) "The C6-RAP-HC-SPV1 position validation changed"
Assert-Close `
    -Actual ([double]$positionCells[0].absolute_relative_position_error) `
    -Expected 0.0003149292606394738 `
    -Tolerance 1.0e-15 `
    -Message "The negative SPV1 position error changed"
Assert-Close `
    -Actual ([double]$positionCells[1].absolute_relative_position_error) `
    -Expected 0.0003149292606394738 `
    -Tolerance 1.0e-15 `
    -Message "The positive SPV1 position error changed"

$velocityCells = @(
    $cells | Where-Object {
        [string]$_.cell_kind -ceq "signed_velocity_validation"
    }
)
Assert-Exact (
    $velocityCells.Count -eq 2 -and
    (@($velocityCells.target_velocity_rad_s) -join ",") -ceq
        "-1.25,1.25" -and
    @($velocityCells | Where-Object {
        [string]$_.schema_version -cne
            "sporespore_rapier_force_based_selected_configuration_velocity_validation_cell_v1" -or
        -not [bool]$_.velocity_response_passed -or
        -not [bool]$_.final_position_and_velocity_signs_match_target -or
        [double]$_.normalized_final_velocity_response -lt 0.98 -or
        [double]$_.normalized_final_velocity_response -gt 1.02 -or
        [int]$_.observation_outer_steps -ne 120
    }).Count -eq 0
) "The C6-RAP-HC-SPV1 velocity validation changed"
foreach ($cell in $velocityCells) {
    Assert-Close `
        -Actual ([double]$cell.normalized_final_velocity_response) `
        -Expected 0.9999997019767761 `
        -Tolerance 1.0e-15 `
        -Message "An SPV1 velocity response changed"
}

$loadedCells = @(
    $cells | Where-Object {
        [string]$_.cell_kind -ceq
            "gravity_loaded_convergence_validation"
    }
)
Assert-Exact (
    $loadedCells.Count -eq 4 -and
    (@($loadedCells.signed_lever_arm_z_m) -join ",") -ceq
        "-0.100000001490116,0.100000001490116,-0.5,0.5" -and
    (@($loadedCells.convergence_window_start_outer_step) -join ",") -ceq
        "158,158,145,145" -and
    (@($loadedCells.convergence_window_end_outer_step) -join ",") -ceq
        "217,217,204,204" -and
    @($loadedCells | Where-Object {
        [string]$_.schema_version -cne
            "sporespore_rapier_force_based_selected_configuration_loaded_validation_cell_v1" -or
        -not [bool]$_.convergence_window_reached -or
        [int]$_.longest_consecutive_converged_outer_steps -ne 60 -or
        -not [bool]$_.response_passed -or
        -not [bool]$_.static_residual_passed -or
        -not [bool]$_.damping_fraction_passed -or
        -not [bool]$_.full_pd_residual_passed -or
        -not [bool]$_.signed_geometry_passed -or
        -not [bool]$_.anchor_passed -or
        -not [bool]$_.convergence_predicates_passed_at_terminal
    }).Count -eq 0
) "The C6-RAP-HC-SPV1 loaded convergence validation changed"

$maximumLoadedAsymmetry = 0.0
foreach ($armMagnitude in @(0.1, 0.5)) {
    $negative = @(
        $loadedCells | Where-Object {
            [math]::Abs(
                [double]$_.signed_lever_arm_z_m + $armMagnitude
            ) -le 1.0e-6
        }
    )
    $positive = @(
        $loadedCells | Where-Object {
            [math]::Abs(
                [double]$_.signed_lever_arm_z_m - $armMagnitude
            ) -le 1.0e-6
        }
    )
    Assert-Exact (
        $negative.Count -eq 1 -and
        $positive.Count -eq 1 -and
        [int]$negative[0].convergence_window_end_outer_step -eq
            [int]$positive[0].convergence_window_end_outer_step
    ) "An SPV1 loaded signed pair changed its exact window timing"
    foreach (
        $field in @(
            "final_angle_rad",
            "terminal_motor_impulse_nms",
            "normalized_terminal_impulse_response",
            "spring_only_static_residual",
            "damping_load_fraction",
            "full_pd_gravity_residual"
        )
    ) {
        $asymmetry = Get-RelativeDifference `
            -First ([double]$negative[0][$field]) `
            -Second ([double]$positive[0][$field])
        $maximumLoadedAsymmetry = [math]::Max(
            $maximumLoadedAsymmetry,
            $asymmetry
        )
    }
}
Assert-Close `
    -Actual $maximumLoadedAsymmetry `
    -Expected 0.004987567986872796 `
    -Tolerance 1.0e-15 `
    -Message "The SPV1 maximum loaded signed-pair asymmetry changed"
Assert-Exact (
    $maximumLoadedAsymmetry -le 0.005
) "The SPV1 loaded signed-pair asymmetry no longer passes"

$aggregate = $report.aggregate
Assert-Exact (
    $worldAttempts -eq 8 -and
    $worldBuilds -eq 8 -and
    $modelReadbacks -eq 8 -and
    $modelMismatches -eq 0 -and
    $nonfinite -eq 0 -and
    $impulseViolations -eq 0 -and
    [int]$aggregate.world_attempt_count -eq 8 -and
    [int]$aggregate.world_build_count -eq 8 -and
    [int]$aggregate.cell_count -eq 8 -and
    [int]$aggregate.passed_cell_count -eq 8 -and
    [int]$aggregate.failed_cell_count -eq 0 -and
    [int]$aggregate.motor_model_readback_count -eq 8 -and
    [int]$aggregate.motor_model_mismatch_count -eq 0 -and
    [int]$aggregate.nonfinite_value_count -eq 0 -and
    [int]$aggregate.step_impulse_limit_violation_count -eq 0 -and
    [bool]$aggregate.ordered_cell_identity_passed -and
    [bool]$aggregate.unloaded_position_pair_passed -and
    [bool]$aggregate.signed_velocity_pair_passed -and
    [bool]$aggregate.gravity_loaded_signed_pair_symmetry_passed -and
    [bool]$aggregate.gravity_loaded_arm_magnitude_ordering_passed -and
    [bool]$aggregate.gravity_loaded_convergence_grid_passed -and
    [bool]$aggregate.complete_eight_cell_validation_passed -and
    @($report.boundary_failure_codes).Count -eq 0
) "The C6-RAP-HC-SPV1 aggregate did not independently reconstruct"
Assert-Close `
    -Actual (
        [double]$aggregate.maximum_gravity_loaded_signed_pair_relative_asymmetry
    ) `
    -Expected $maximumLoadedAsymmetry `
    -Tolerance 1.0e-15 `
    -Message "The SPV1 aggregate signed-pair asymmetry changed"

Assert-Exact (
    [int]$manifest.complete_attempt.process_exit_code -eq 0 -and
    [int]$manifest.complete_attempt.world_build_count -eq 8 -and
    [int]$manifest.complete_attempt.passed_cell_count -eq 8 -and
    [int]$manifest.complete_attempt.failed_cell_count -eq 0 -and
    [bool]$manifest.complete_attempt.complete_eight_cell_validation_passed -and
    @($manifest.complete_attempt.boundary_failure_codes).Count -eq 0 -and
    [int]$manifest.validated_configuration.solver_iterations -eq 16 -and
    [int]$manifest.validated_configuration.num_internal_pgs_iterations -eq 3 -and
    [int]$manifest.validated_configuration.num_internal_stabilization_iterations -eq 5 -and
    [bool]$manifest.technical_disposition.exact_finite_selected_configuration_validation_passed -and
    [bool]$manifest.technical_disposition.exact_finite_static_convergence_characterization_passed -and
    [bool]$manifest.technical_disposition.exact_finite_force_based_host_characterization_passed -and
    [bool]$manifest.technical_disposition.fixed_3_5_allocation_observed_in_every_cell -and
    -not [bool]$manifest.technical_disposition.adapter_default_change_automatically_performed -and
    [bool]$manifest.technical_disposition.adapter_configuration_change_requires_separate_commit_and_conformance -and
    [bool]$manifest.technical_disposition.selected_policy_campaign_may_be_preregistered_after_adapter_configuration_change -and
    -not [bool]$manifest.technical_disposition.selected_policy_locomotion_evaluated -and
    [bool]$manifest.technical_disposition.result_is_not_a_selected_policy_verdict -and
    -not [bool]$manifest.technical_disposition.population_or_solver_band_claim_authorized
) "The C6-RAP-HC-SPV1 technical disposition changed"

foreach ($claim in $positiveClaims) {
    Assert-Exact (
        [bool]$manifest.claims[$claim] -and
        [bool]$report[$claim]
    ) "C6-RAP-HC-SPV1 must retain its positive $claim claim"
}
foreach ($claim in $falseClaims) {
    Assert-Exact (
        -not [bool]$manifest.claims[$claim] -and
        -not [bool]$report[$claim]
    ) "C6-RAP-HC-SPV1 may not authorize $claim"
}
foreach ($source in @($manifest.research_sources)) {
    Assert-Exact (
        (Test-Path -LiteralPath (
            Join-Path $repoRoot ([string]$source.path)
        ) -PathType Leaf) -and
        (Test-SporeWorkingOrHistoricalSourceSha256 `
            -RepositoryRoot $repoRoot `
            -Commit $expectedSourceCommit `
            -Path ([string]$source.path) `
            -ExpectedSha256 ([string]$source.sha256))
    ) "A C6-RAP-HC-SPV1 research source changed"
}

Write-Output (
    "C6_RAP_HC_SPV1_CLOSURE_PASS worlds=8 passed=8 failed=0 " +
    "position=2/2 velocity=2/2 loaded=4/4 allocation=3/5 " +
    "windows=217,217,204,204 max_pair_asymmetry=" +
    "$maximumLoadedAsymmetry readback=8 model_mismatches=0 " +
    "impulse_violations=0 finite_host_validation=True " +
    "locomotion_authority=False"
)
