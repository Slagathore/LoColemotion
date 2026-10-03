#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_force_based_convergence_window_cw1_closure.json"
$expectedSourceCommit = "de2af8876d76b248b83d7bc0c3a2ef15e5830656"
. (Join-Path $PSScriptRoot "closed_experiment_source_audit.ps1")
$falseClaims = @(
    "rapier_force_based_static_convergence_characterization",
    "rapier_force_based_host_characterization",
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

Assert-Exact (
    Test-Path -LiteralPath $manifestPath -PathType Leaf
) "The C6-RAP-HC-CW1 closure is missing"
$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_rapier_c6_force_based_convergence_window_closure_v1" -and
    [string]$manifest.status -ceq
        "closed_negative_low_iteration_convergence_window" -and
    [string]$manifest.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-CONVERGENCE-WINDOW" -and
    [string]$manifest.gate_id -ceq "C6-RAP-HC-CW1" -and
    [string]$manifest.experiment_source_commit -ceq
        $expectedSourceCommit -and
    [bool]$manifest.source_was_clean_and_equal_to_origin_main -and
    [bool]$manifest.predecessor_artifacts.fb1_and_lr1_remain_closed_negative -and
    [bool]$manifest.predecessor_artifacts.no_predecessor_was_rerun_rethresholded_or_reclassified -and
    [bool]$manifest.immutability.same_identity_rerun_forbidden -and
    [bool]$manifest.immutability.report_rewrite_forbidden -and
    [bool]$manifest.immutability.threshold_change_forbidden -and
    [bool]$manifest.immutability.failed_cell_deletion_replacement_or_averaging_forbidden -and
    [bool]$manifest.immutability.posthoc_pass_reclassification_forbidden
) "The C6-RAP-HC-CW1 closure identity or immutability boundary changed"

& git -C $repoRoot cat-file -e "${expectedSourceCommit}^{commit}"
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-CW1 experiment commit is not retained"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-CW1 experiment commit is not an ancestor of HEAD"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0
) "origin/main could not be resolved while auditing C6-RAP-HC-CW1"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $originMain
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-CW1 experiment commit is not retained on origin/main"

Assert-HashedFile `
    -Path (Join-Path $repoRoot ([string]$manifest.preregistration.path)) `
    -ExpectedSha256 ([string]$manifest.preregistration.raw_sha256) `
    -Message "The frozen C6-RAP-HC-CW1 preregistration changed"
Assert-HashedFile `
    -Path (
        Join-Path $repoRoot (
            [string]$manifest.predecessor_artifacts.lr1_closure_path
        )
    ) `
    -ExpectedSha256 (
        [string]$manifest.predecessor_artifacts.lr1_closure_sha256
    ) `
    -Message "The frozen C6-RAP-HC-LR1 closure changed"
Assert-HashedFile `
    -Path (
        Join-Path $repoRoot (
            [string]$manifest.predecessor_artifacts.lr1_posthoc_diagnostic_path
        )
    ) `
    -ExpectedSha256 (
        [string]$manifest.predecessor_artifacts.lr1_posthoc_diagnostic_sha256
    ) `
    -Message "The frozen C6-RAP-HC-LR1 diagnostic changed"
foreach ($artifactName in @("report", "stdout", "stderr")) {
    Assert-HashedFile `
        -Path ([string]$manifest.complete_attempt["${artifactName}_path"]) `
        -ExpectedSha256 (
            [string]$manifest.complete_attempt["${artifactName}_sha256"]
        ) `
        -Message "The retained C6-RAP-HC-CW1 $artifactName changed"
}

$report = (
    Get-Content -Raw -LiteralPath (
        [string]$manifest.complete_attempt.report_path
    ) |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_force_based_convergence_window_report_v1" -and
    -not [bool]$report.ok -and
    [string]$report.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-CONVERGENCE-WINDOW" -and
    [string]$report.gate_id -ceq "C6-RAP-HC-CW1" -and
    [string]$report.estimand_class -ceq
        "exact_finite_cell_host_characterization" -and
    [string]$report.source.commit -ceq $expectedSourceCommit -and
    [string]$report.source.origin_main_commit -ceq
        $expectedSourceCommit -and
    [bool]$report.source.clean -and
    [bool]$report.source.matches_origin_main -and
    [bool]$report.preflight.ok -and
    [int]$report.preflight.world_build_count -eq 0 -and
    [string]$report.motor_model -ceq "ForceBased" -and
    [int]$report.minimum_acceptance_step -eq 120 -and
    [int]$report.required_consecutive_converged_steps -eq 60 -and
    [int]$report.maximum_observation_steps -eq 1440
) "The retained C6-RAP-HC-CW1 report identity changed"

$cells = @($report.cells)
$expectedCellIds = @(
    "arm_0.20_negative_solver_12",
    "arm_0.20_positive_solver_12",
    "arm_0.40_negative_solver_12",
    "arm_0.40_positive_solver_12",
    "arm_0.20_negative_solver_36",
    "arm_0.20_positive_solver_36",
    "arm_0.40_negative_solver_36",
    "arm_0.40_positive_solver_36"
)
Assert-Exact (
    $cells.Count -eq 8 -and
    (@($cells.cell_id) -join "`n") -ceq
        ($expectedCellIds -join "`n")
) "The C6-RAP-HC-CW1 ordered cell grid changed"

$worldAttempts = 0
$worldBuilds = 0
$modelReadbacks = 0
$modelMismatches = 0
$nonfinite = 0
$impulseViolations = 0
foreach ($cell in $cells) {
    Assert-Exact (
        [string]$cell.schema_version -ceq
            "sporespore_rapier_force_based_convergence_window_cell_v1" -and
        [string]$cell.cell_kind -ceq "gravity_static_convergence" -and
        [string]$cell.motor_model_readback -ceq "ForceBased" -and
        [int]$cell.motor_model_mismatch_count -eq 0 -and
        [int]$cell.nonfinite_value_count -eq 0 -and
        [int]$cell.step_impulse_limit_violation_count -eq 0 -and
        [int]$cell.world_attempt_count -eq 1 -and
        [int]$cell.world_build_count -eq 1 -and
        [bool]$cell.response_passed -and
        [bool]$cell.full_pd_residual_passed -and
        [bool]$cell.signed_geometry_passed -and
        [bool]$cell.anchor_passed -and
        [bool]$cell.force_limit_passed -and
        [bool]$cell.finite_terminal_values -and
        [double]$cell.normalized_terminal_impulse_response -ge 0.98 -and
        [double]$cell.normalized_terminal_impulse_response -le 1.02 -and
        -not [bool]$cell.physical_acceptance_authority
    ) "A retained C6-RAP-HC-CW1 cell changed its integrity boundary"
    $worldAttempts += [int]$cell.world_attempt_count
    $worldBuilds += [int]$cell.world_build_count
    $modelReadbacks += [int]$cell.motor_model_readback_count
    $modelMismatches += [int]$cell.motor_model_mismatch_count
    $nonfinite += [int]$cell.nonfinite_value_count
    $impulseViolations += [int]$cell.step_impulse_limit_violation_count
}

$solver12 = @($cells | Where-Object { [int]$_.solver_iterations -eq 12 })
$solver36 = @($cells | Where-Object { [int]$_.solver_iterations -eq 36 })
Assert-Exact (
    $solver12.Count -eq 4 -and
    @($solver12 | Where-Object { [bool]$_.ok }).Count -eq 0 -and
    @($solver12 | Where-Object {
        [bool]$_.convergence_window_reached -or
        [int]$_.observation_steps_executed -ne 1440
    }).Count -eq 0 -and
    (@($solver12.longest_consecutive_converged_steps) -join ",") -ceq
        "2,2,42,42" -and
    $solver36.Count -eq 4 -and
    @($solver36 | Where-Object { -not [bool]$_.ok }).Count -eq 0 -and
    @($solver36 | Where-Object {
        -not [bool]$_.convergence_window_reached -or
        [int]$_.longest_consecutive_converged_steps -ne 60
    }).Count -eq 0 -and
    (@($solver36.convergence_window_start_step) -join ",") -ceq
        "144,144,145,145" -and
    (@($solver36.convergence_window_end_step) -join ",") -ceq
        "203,203,204,204"
) "The C6-RAP-HC-CW1 solver-iteration pass partition changed"

$solver12SmallArm = @(
    $solver12 | Where-Object {
        [math]::Abs([double]$_.signed_lever_arm_z_m) -lt 0.3
    }
)
$solver12LargeArm = @(
    $solver12 | Where-Object {
        [math]::Abs([double]$_.signed_lever_arm_z_m) -gt 0.3
    }
)
Assert-Exact (
    @($solver12SmallArm | Where-Object {
        [bool]$_.static_residual_passed -or
        [bool]$_.damping_fraction_passed
    }).Count -eq 0 -and
    @($solver12LargeArm | Where-Object {
        -not [bool]$_.static_residual_passed -or
        [bool]$_.damping_fraction_passed
    }).Count -eq 0
) "The C6-RAP-HC-CW1 low-iteration terminal mechanism changed"

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
    [int]$aggregate.passed_cell_count -eq 4 -and
    [int]$aggregate.failed_cell_count -eq 4 -and
    [int]$aggregate.convergence_window_reached_count -eq 4 -and
    -not [bool]$aggregate.load_relative_static_convergence_grid_passed -and
    [bool]$aggregate.signed_pair_symmetry_passed -and
    [double]$aggregate.maximum_signed_pair_relative_asymmetry -le 0.005 -and
    [bool]$aggregate.arm_magnitude_ordering_passed -and
    [bool]$aggregate.solver_iteration_inverse_scaling_passed -and
    [double]$aggregate.maximum_solver_scaling_relative_error -le 0.02
) "The C6-RAP-HC-CW1 aggregate did not independently reconstruct"

$expectedFailureCodes = @(
    "C6_RAP_HC_CW1_passed_cell_count_INVALID",
    "C6_RAP_HC_CW1_failed_cell_count_INVALID",
    "C6_RAP_HC_CW1_convergence_window_reached_count_INVALID",
    "C6_RAP_HC_CW1_load_relative_static_convergence_grid_passed_INVALID"
)
Assert-Exact (
    (@($report.failure_codes) -join "`n") -ceq
        ($expectedFailureCodes -join "`n")
) "The C6-RAP-HC-CW1 frozen failure vector changed"

Assert-Exact (
    [bool]$manifest.technical_disposition.explicit_force_based_selection_observed_in_every_cell -and
    [bool]$manifest.technical_disposition.source_derived_small_step_impulse_response_worked_for_all_declared_cells -and
    [bool]$manifest.technical_disposition.signed_pair_symmetry_worked -and
    [bool]$manifest.technical_disposition.arm_magnitude_ordering_worked -and
    [bool]$manifest.technical_disposition.inverse_solver_iteration_scaling_worked -and
    [bool]$manifest.technical_disposition.solver_36_complete_convergence_window_worked_for_all_declared_arms -and
    -not [bool]$manifest.technical_disposition.solver_12_complete_convergence_window_worked_for_all_declared_arms -and
    -not [bool]$manifest.technical_disposition.frozen_success_contract_passed -and
    -not [bool]$manifest.technical_disposition.force_based_static_convergence_characterization_authorized -and
    -not [bool]$manifest.technical_disposition.force_based_host_characterization_authorized -and
    [bool]$manifest.technical_disposition.result_is_not_a_selected_policy_verdict
) "The C6-RAP-HC-CW1 technical disposition changed"
foreach ($claim in $falseClaims) {
    Assert-Exact (
        -not [bool]$manifest.claims[$claim] -and
        -not [bool]$report[$claim]
    ) "C6-RAP-HC-CW1 may not authorize $claim"
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
    ) "A C6-RAP-HC-CW1 research source changed"
}

Write-Output (
    "C6_RAP_HC_CW1_CLOSURE_PASS worlds=8 passed=4 failed=4 " +
    "solver12=0/4 solver36=4/4 windows=4/8 readback=8 " +
    "model_mismatches=0 impulse_violations=0 response=True " +
    "full_pd=True convergence_all=False physical_authority=False"
)
