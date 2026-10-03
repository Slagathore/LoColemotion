#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_force_based_solver_phase_development_spd1_closure.json"
$expectedSourceCommit = "4bd4c925a51fe09eb260a6fdb56f3616e36cd036"
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
) "The C6-RAP-HC-SPD1 closure is missing"
$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_rapier_c6_force_based_solver_phase_development_closure_v1" -and
    [string]$manifest.status -ceq
        "closed_positive_development_configuration_selected_requires_fresh_validation" -and
    [string]$manifest.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-SOLVER-PHASE-DEVELOPMENT" -and
    [string]$manifest.gate_id -ceq "C6-RAP-HC-SPD1" -and
    [string]$manifest.study_class -ceq
        "exact_finite_cell_configuration_development_screen" -and
    [string]$manifest.experiment_source_commit -ceq
        $expectedSourceCommit -and
    [bool]$manifest.source_was_clean_and_equal_to_origin_main -and
    [bool]$manifest.predecessor_artifacts.fb1_lr1_and_cw1_remain_closed_negative -and
    [bool]$manifest.predecessor_artifacts.no_predecessor_was_rerun_rethresholded_or_reclassified -and
    [bool]$manifest.immutability.same_identity_rerun_forbidden -and
    [bool]$manifest.immutability.report_rewrite_forbidden -and
    [bool]$manifest.immutability.threshold_change_forbidden -and
    [bool]$manifest.immutability.candidate_grid_change_forbidden -and
    [bool]$manifest.immutability.failed_cell_deletion_replacement_or_averaging_forbidden -and
    [bool]$manifest.immutability.selector_reinvocation_forbidden -and
    [bool]$manifest.immutability.posthoc_candidate_reclassification_forbidden -and
    [bool]$manifest.immutability.successor_requires_new_identity
) "The C6-RAP-HC-SPD1 closure identity or immutability boundary changed"

& git -C $repoRoot cat-file -e "${expectedSourceCommit}^{commit}"
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-SPD1 experiment commit is not retained"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-SPD1 experiment commit is not an ancestor of HEAD"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0
) "origin/main could not be resolved while auditing C6-RAP-HC-SPD1"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $originMain
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-SPD1 experiment commit is not retained on origin/main"

Assert-HashedFile `
    -Path (Join-Path $repoRoot ([string]$manifest.preregistration.path)) `
    -ExpectedSha256 ([string]$manifest.preregistration.raw_sha256) `
    -Message "The frozen C6-RAP-HC-SPD1 preregistration changed"
Assert-HashedFile `
    -Path (
        Join-Path $repoRoot (
            [string]$manifest.predecessor_artifacts.cw1_closure_path
        )
    ) `
    -ExpectedSha256 (
        [string]$manifest.predecessor_artifacts.cw1_closure_sha256
    ) `
    -Message "The frozen C6-RAP-HC-CW1 closure changed"
Assert-HashedFile `
    -Path (
        Join-Path $repoRoot (
            [string]$manifest.predecessor_artifacts.solver_phase_diagnostic_path
        )
    ) `
    -ExpectedSha256 (
        [string]$manifest.predecessor_artifacts.solver_phase_diagnostic_sha256
    ) `
    -Message "The frozen C6-RAP-HC-CW1 solver-phase diagnostic changed"
foreach ($artifactName in @("report", "stdout", "stderr")) {
    Assert-HashedFile `
        -Path ([string]$manifest.complete_attempt["${artifactName}_path"]) `
        -ExpectedSha256 (
            [string]$manifest.complete_attempt["${artifactName}_sha256"]
        ) `
        -Message "The retained C6-RAP-HC-SPD1 $artifactName changed"
}

$report = (
    Get-Content -Raw -LiteralPath (
        [string]$manifest.complete_attempt.report_path
    ) |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_force_based_solver_phase_development_report_v1" -and
    [bool]$report.ok -and
    [string]$report.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-SOLVER-PHASE-DEVELOPMENT" -and
    [string]$report.gate_id -ceq "C6-RAP-HC-SPD1" -and
    [string]$report.study_class -ceq
        "exact_finite_cell_configuration_development_screen" -and
    [string]$report.source.commit -ceq $expectedSourceCommit -and
    [string]$report.source.origin_main_commit -ceq
        $expectedSourceCommit -and
    [bool]$report.source.clean -and
    [bool]$report.source.matches_origin_main -and
    [bool]$report.preflight.ok -and
    [int]$report.preflight.world_build_count -eq 0 -and
    [bool]$report.preflight.perfect_sixteen_cell_traces_passed_entire_gate -and
    [bool]$report.preflight.no_eligible_candidate_canary_selected_none -and
    [bool]$report.preflight.missing_cell_canary_rejected -and
    [bool]$report.preflight.window_gap_canary_rejected -and
    [bool]$report.preflight.unequal_total_pass_canary_rejected -and
    [bool]$report.preflight.tie_break_canary_selected_spd1_a -and
    [string]$report.motor_model -ceq "ForceBased" -and
    [int]$report.solver_iterations -eq 16 -and
    [int]$report.total_constraint_passes_per_small_step -eq 8 -and
    [int]$report.minimum_acceptance_step -eq 120 -and
    [int]$report.required_consecutive_converged_steps -eq 60 -and
    [int]$report.maximum_observation_steps -eq 1440 -and
    [bool]$report.development_configuration_selected -and
    [bool]$report.selected_configuration_requires_fresh_independent_validation -and
    -not [bool]$report.validation_authority -and
    -not [bool]$report.physical_acceptance_authority
) "The retained C6-RAP-HC-SPD1 report identity changed"

$cells = @($report.cells)
$expectedCellIds = @(
    "SPD1-A_arm_0.25_negative_solver_16",
    "SPD1-A_arm_0.25_positive_solver_16",
    "SPD1-A_arm_0.45_negative_solver_16",
    "SPD1-A_arm_0.45_positive_solver_16",
    "SPD1-B_arm_0.25_negative_solver_16",
    "SPD1-B_arm_0.25_positive_solver_16",
    "SPD1-B_arm_0.45_negative_solver_16",
    "SPD1-B_arm_0.45_positive_solver_16",
    "SPD1-C_arm_0.25_negative_solver_16",
    "SPD1-C_arm_0.25_positive_solver_16",
    "SPD1-C_arm_0.45_negative_solver_16",
    "SPD1-C_arm_0.45_positive_solver_16",
    "SPD1-D_arm_0.25_negative_solver_16",
    "SPD1-D_arm_0.25_positive_solver_16",
    "SPD1-D_arm_0.45_negative_solver_16",
    "SPD1-D_arm_0.45_positive_solver_16"
)
Assert-Exact (
    $cells.Count -eq 16 -and
    (@($cells.cell_id) -join "`n") -ceq
        ($expectedCellIds -join "`n")
) "The C6-RAP-HC-SPD1 ordered cell grid changed"

$worldAttempts = 0
$worldBuilds = 0
$modelReadbacks = 0
$modelMismatches = 0
$nonfinite = 0
$impulseViolations = 0
foreach ($cell in $cells) {
    Assert-Exact (
        [string]$cell.schema_version -ceq
            "sporespore_rapier_force_based_solver_phase_development_cell_v1" -and
        [string]$cell.cell_kind -ceq
            "gravity_static_convergence_development" -and
        [string]$cell.motor_model_readback -ceq "ForceBased" -and
        [int]$cell.motor_model_mismatch_count -eq 0 -and
        [int]$cell.nonfinite_value_count -eq 0 -and
        [int]$cell.step_impulse_limit_violation_count -eq 0 -and
        [int]$cell.world_attempt_count -eq 1 -and
        [int]$cell.world_build_count -eq 1 -and
        [int]$cell.solver_iterations -eq 16 -and
        [int]$cell.total_constraint_passes_per_small_step -eq 8 -and
        (
            [int]$cell.num_internal_pgs_iterations +
            [int]$cell.num_internal_stabilization_iterations
        ) -eq 8 -and
        [bool]$cell.equal_total_pass_contract_passed -and
        [bool]$cell.response_passed -and
        [bool]$cell.static_residual_passed -and
        [bool]$cell.full_pd_residual_passed -and
        [bool]$cell.signed_geometry_passed -and
        [bool]$cell.anchor_passed -and
        [bool]$cell.force_limit_passed -and
        [bool]$cell.finite_terminal_values -and
        [bool]$cell.development_screen_evidence -and
        -not [bool]$cell.validation_authority -and
        -not [bool]$cell.physical_acceptance_authority -and
        [double]$cell.normalized_terminal_impulse_response -ge 0.98 -and
        [double]$cell.normalized_terminal_impulse_response -le 1.02
    ) "A retained C6-RAP-HC-SPD1 cell changed its integrity boundary"
    $worldAttempts += [int]$cell.world_attempt_count
    $worldBuilds += [int]$cell.world_build_count
    $modelReadbacks += [int]$cell.motor_model_readback_count
    $modelMismatches += [int]$cell.motor_model_mismatch_count
    $nonfinite += [int]$cell.nonfinite_value_count
    $impulseViolations += [int]$cell.step_impulse_limit_violation_count
}

$cellsByCandidate = @{}
foreach ($candidateId in @("SPD1-A", "SPD1-B", "SPD1-C", "SPD1-D")) {
    $cellsByCandidate[$candidateId] = @(
        $cells | Where-Object {
            [string]$_.candidate_id -ceq $candidateId
        }
    )
    Assert-Exact (
        $cellsByCandidate[$candidateId].Count -eq 4
    ) "The C6-RAP-HC-SPD1 $candidateId cell partition changed"
}

$candidateA = $cellsByCandidate["SPD1-A"]
$candidateASmall = @(
    $candidateA | Where-Object {
        [math]::Abs([double]$_.signed_lever_arm_z_m) -lt 0.3
    }
)
$candidateALarge = @(
    $candidateA | Where-Object {
        [math]::Abs([double]$_.signed_lever_arm_z_m) -gt 0.3
    }
)
Assert-Exact (
    @($candidateASmall | Where-Object { [bool]$_.ok }).Count -eq 0 -and
    @($candidateASmall | Where-Object {
        [bool]$_.convergence_window_reached -or
        [int]$_.observation_steps_executed -ne 1440 -or
        [int]$_.longest_consecutive_converged_steps -ne 33
    }).Count -eq 0 -and
    @($candidateALarge | Where-Object { -not [bool]$_.ok }).Count -eq 0 -and
    (@($candidateALarge.convergence_window_end_step) -join ",") -ceq
        "192,192"
) "The C6-RAP-HC-SPD1 legacy 1/7 outcome changed"

foreach ($candidateId in @("SPD1-B", "SPD1-C", "SPD1-D")) {
    Assert-Exact (
        @($cellsByCandidate[$candidateId] | Where-Object {
            -not [bool]$_.ok -or
            -not [bool]$_.convergence_window_reached -or
            [int]$_.longest_consecutive_converged_steps -ne 60
        }).Count -eq 0
    ) "The C6-RAP-HC-SPD1 $candidateId complete-cell result changed"
}
Assert-Exact (
    (@($cellsByCandidate["SPD1-B"].convergence_window_end_step) -join ",") -ceq
        "214,214,207,207" -and
    (@($cellsByCandidate["SPD1-C"].convergence_window_end_step) -join ",") -ceq
        "215,215,207,207" -and
    (@($cellsByCandidate["SPD1-D"].convergence_window_end_step) -join ",") -ceq
        "214,215,207,207"
) "The C6-RAP-HC-SPD1 convergence timing vectors changed"

$summaries = @($report.candidate_summaries)
Assert-Exact (
    $summaries.Count -eq 4 -and
    (@($summaries.candidate_id) -join ",") -ceq
        "SPD1-A,SPD1-B,SPD1-C,SPD1-D"
) "The C6-RAP-HC-SPD1 candidate summary order changed"
$summaryById = @{}
foreach ($summary in $summaries) {
    $summaryById[[string]$summary.candidate_id] = $summary
    Assert-Exact (
        [string]$summary.schema_version -ceq
            "sporespore_rapier_force_based_solver_phase_candidate_summary_v1" -and
        [bool]$summary.identity_valid -and
        [int]$summary.cell_count -eq 4 -and
        [int]$summary.world_attempt_count -eq 4 -and
        [int]$summary.world_build_count -eq 4 -and
        [int]$summary.motor_model_readback_count -eq 4 -and
        [int]$summary.motor_model_mismatch_count -eq 0 -and
        [int]$summary.nonfinite_value_count -eq 0 -and
        [int]$summary.step_impulse_limit_violation_count -eq 0 -and
        [int]$summary.total_constraint_passes_per_small_step -eq 8 -and
        -not [bool]$summary.validation_authority -and
        -not [bool]$summary.physical_acceptance_authority
    ) "A C6-RAP-HC-SPD1 candidate summary integrity field changed"
}
Assert-Exact (
    [int]$summaryById["SPD1-A"].num_internal_pgs_iterations -eq 1 -and
    [int]$summaryById["SPD1-A"].num_internal_stabilization_iterations -eq 7 -and
    [int]$summaryById["SPD1-A"].passed_cell_count -eq 2 -and
    [int]$summaryById["SPD1-A"].failed_cell_count -eq 2 -and
    -not [bool]$summaryById["SPD1-A"].eligible_for_development_selection -and
    [int]$summaryById["SPD1-B"].num_internal_pgs_iterations -eq 3 -and
    [int]$summaryById["SPD1-B"].num_internal_stabilization_iterations -eq 5 -and
    [int]$summaryById["SPD1-B"].passed_cell_count -eq 4 -and
    [bool]$summaryById["SPD1-B"].signed_pair_symmetry_passed -and
    [bool]$summaryById["SPD1-B"].eligible_for_development_selection -and
    [int]$summaryById["SPD1-B"].maximum_convergence_window_end_step -eq 214 -and
    [int]$summaryById["SPD1-B"].sum_convergence_window_end_steps -eq 842 -and
    [int]$summaryById["SPD1-C"].num_internal_pgs_iterations -eq 5 -and
    [int]$summaryById["SPD1-C"].num_internal_stabilization_iterations -eq 3 -and
    [int]$summaryById["SPD1-C"].passed_cell_count -eq 4 -and
    [bool]$summaryById["SPD1-C"].signed_pair_symmetry_passed -and
    [bool]$summaryById["SPD1-C"].eligible_for_development_selection -and
    [int]$summaryById["SPD1-C"].maximum_convergence_window_end_step -eq 215 -and
    [int]$summaryById["SPD1-C"].sum_convergence_window_end_steps -eq 844 -and
    [int]$summaryById["SPD1-D"].num_internal_pgs_iterations -eq 7 -and
    [int]$summaryById["SPD1-D"].num_internal_stabilization_iterations -eq 1 -and
    [int]$summaryById["SPD1-D"].passed_cell_count -eq 4 -and
    -not [bool]$summaryById["SPD1-D"].signed_pair_symmetry_passed -and
    -not [bool]$summaryById["SPD1-D"].eligible_for_development_selection
) "The C6-RAP-HC-SPD1 candidate eligibility partition changed"

$aggregate = $report.aggregate
Assert-Exact (
    $worldAttempts -eq 16 -and
    $worldBuilds -eq 16 -and
    $modelReadbacks -eq 16 -and
    $modelMismatches -eq 0 -and
    $nonfinite -eq 0 -and
    $impulseViolations -eq 0 -and
    [int]$aggregate.world_attempt_count -eq 16 -and
    [int]$aggregate.world_build_count -eq 16 -and
    [int]$aggregate.cell_count -eq 16 -and
    [int]$aggregate.passed_cell_count -eq 14 -and
    [int]$aggregate.failed_cell_count -eq 2 -and
    [int]$aggregate.candidate_count -eq 4 -and
    [int]$aggregate.eligible_candidate_count -eq 2 -and
    [int]$aggregate.selected_candidate_count -eq 1 -and
    [int]$aggregate.selector_invocation_count -eq 1 -and
    [int]$aggregate.motor_model_readback_count -eq 16 -and
    [int]$aggregate.motor_model_mismatch_count -eq 0 -and
    [int]$aggregate.nonfinite_value_count -eq 0 -and
    [int]$aggregate.step_impulse_limit_violation_count -eq 0 -and
    [bool]$aggregate.complete_sixteen_cell_screen
) "The C6-RAP-HC-SPD1 aggregate did not independently reconstruct"

$selection = $report.selection
Assert-Exact (
    [string]$selection.schema_version -ceq
        "sporespore_rapier_force_based_solver_phase_development_selection_v1" -and
    [string]$selection.status -ceq
        "development_configuration_selected_requires_fresh_independent_validation" -and
    [int]$selection.selector_invocation_count -eq 1 -and
    [int]$selection.eligible_candidate_count -eq 2 -and
    (@($selection.eligible_candidate_ids) -join ",") -ceq
        "SPD1-B,SPD1-C" -and
    [string]$selection.selected_candidate_id -ceq "SPD1-B" -and
    [int]$selection.selected_num_internal_pgs_iterations -eq 3 -and
    [int]$selection.selected_num_internal_stabilization_iterations -eq 5 -and
    [int]$selection.selected_maximum_convergence_window_end_step -eq 214 -and
    [int]$selection.selected_sum_convergence_window_end_steps -eq 842 -and
    [bool]$selection.selection_is_development_only -and
    [bool]$selection.fresh_independent_validation_required -and
    -not [bool]$selection.validation_authority -and
    -not [bool]$selection.physical_acceptance_authority -and
    @($report.boundary_failure_codes).Count -eq 0
) "The C6-RAP-HC-SPD1 frozen selection changed"

Assert-Exact (
    [int]$manifest.complete_attempt.process_exit_code -eq 0 -and
    [bool]$manifest.complete_attempt.complete_sixteen_cell_screen -and
    [int]$manifest.complete_attempt.passed_cell_count -eq 14 -and
    [int]$manifest.complete_attempt.failed_cell_count -eq 2 -and
    [int]$manifest.complete_attempt.eligible_candidate_count -eq 2 -and
    [int]$manifest.complete_attempt.selected_candidate_count -eq 1 -and
    @($manifest.complete_attempt.boundary_failure_codes).Count -eq 0 -and
    [bool]$manifest.technical_disposition.complete_finite_development_screen_passed -and
    [bool]$manifest.technical_disposition.development_configuration_selected -and
    [bool]$manifest.technical_disposition.explicit_force_based_selection_observed_in_every_cell -and
    [bool]$manifest.technical_disposition.source_derived_small_step_impulse_response_worked_for_all_declared_cells -and
    [bool]$manifest.technical_disposition.full_pd_gravity_balance_worked_for_all_declared_cells -and
    -not [bool]$manifest.technical_disposition.legacy_1_7_complete_grid_worked -and
    [bool]$manifest.technical_disposition.selected_3_5_complete_grid_worked -and
    -not [bool]$manifest.technical_disposition.selected_configuration_independently_validated -and
    -not [bool]$manifest.technical_disposition.adapter_default_change_authorized -and
    -not [bool]$manifest.technical_disposition.force_based_host_characterization_authorized -and
    [bool]$manifest.technical_disposition.result_is_not_a_selected_policy_verdict
) "The C6-RAP-HC-SPD1 technical disposition changed"

Assert-Exact (
    [bool]$manifest.claims.rapier_force_based_solver_phase_development_complete -and
    [bool]$report.rapier_force_based_solver_phase_development_complete
) "C6-RAP-HC-SPD1 must retain its narrow completed-development-screen claim"
foreach ($claim in $falseClaims) {
    Assert-Exact (
        -not [bool]$manifest.claims[$claim] -and
        -not [bool]$report[$claim]
    ) "C6-RAP-HC-SPD1 may not authorize $claim"
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
    ) "A C6-RAP-HC-SPD1 research source changed"
}

Write-Output (
    "C6_RAP_HC_SPD1_CLOSURE_PASS worlds=16 cells=14/16 " +
    "eligible=2/4 selected=SPD1-B allocation=3/5 " +
    "legacy=2/4 candidate_c=4/4 candidate_d_cells=4/4 " +
    "candidate_d_pair_gate=False readback=16 model_mismatches=0 " +
    "impulse_violations=0 validation_authority=False"
)
