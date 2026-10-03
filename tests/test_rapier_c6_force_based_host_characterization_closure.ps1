#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_force_based_host_characterization_closure.json"
$expectedSourceCommit = "331ebe36e609fa387869fefcb70e62f63e9817a9"
. (Join-Path $PSScriptRoot "closed_experiment_source_audit.ps1")
$falseClaims = @(
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
) "The C6-RAP-HC-FB1 closure is missing"
$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_rapier_c6_force_based_host_characterization_closure_v1" -and
    [string]$manifest.status -ceq
        "closed_negative_loaded_support_terminal_impulse_threshold" -and
    [string]$manifest.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-HOST-CHARACTERIZATION" -and
    [string]$manifest.gate_id -ceq "C6-RAP-HC-FB1" -and
    [string]$manifest.experiment_source_commit -ceq
        $expectedSourceCommit -and
    [bool]$manifest.source_was_clean_and_equal_to_origin_main -and
    [bool]$manifest.immutability.same_identity_rerun_forbidden -and
    [bool]$manifest.immutability.report_rewrite_forbidden -and
    [bool]$manifest.immutability.threshold_change_forbidden -and
    [bool]$manifest.immutability.posthoc_pass_reclassification_forbidden
) "The C6-RAP-HC-FB1 closure identity or immutability boundary changed"

& git -C $repoRoot cat-file -e "${expectedSourceCommit}^{commit}"
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-FB1 experiment commit is not retained"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-FB1 experiment commit is not an ancestor of HEAD"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0
) "origin/main could not be resolved while auditing C6-RAP-HC-FB1"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $originMain
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-FB1 experiment commit is not retained on origin/main"

Assert-HashedFile `
    -Path (Join-Path $repoRoot ([string]$manifest.preregistration.path)) `
    -ExpectedSha256 ([string]$manifest.preregistration.raw_sha256) `
    -Message "The frozen C6-RAP-HC-FB1 preregistration changed"
foreach ($artifactName in @("report", "stdout", "stderr")) {
    Assert-HashedFile `
        -Path ([string]$manifest.complete_attempt["${artifactName}_path"]) `
        -ExpectedSha256 (
            [string]$manifest.complete_attempt["${artifactName}_sha256"]
        ) `
        -Message "The retained C6-RAP-HC-FB1 $artifactName changed"
}

$report = (
    Get-Content -Raw -LiteralPath (
        [string]$manifest.complete_attempt.report_path
    ) |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_force_based_host_characterization_report_v1" -and
    -not [bool]$report.ok -and
    [string]$report.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-HOST-CHARACTERIZATION" -and
    [string]$report.gate_id -ceq "C6-RAP-HC-FB1" -and
    [string]$report.source.commit -ceq $expectedSourceCommit -and
    [string]$report.source.origin_main_commit -ceq
        $expectedSourceCommit -and
    [bool]$report.source.clean -and
    [bool]$report.source.matches_origin_main -and
    [bool]$report.preflight.ok -and
    [int]$report.preflight.world_build_count -eq 0 -and
    [string]$report.motor_model -ceq "ForceBased"
) "The retained C6-RAP-HC-FB1 report identity changed"

$cells = @($report.cells)
Assert-Exact (
    $cells.Count -eq 8
) "C6-RAP-HC-FB1 must retain exactly eight ordered cells"
$positionCells = @(
    $cells | Where-Object {
        [string]$_.cell_kind -ceq "unloaded_position_tracking"
    }
)
$velocityCells = @(
    $cells | Where-Object {
        [string]$_.cell_kind -ceq "signed_velocity"
    }
)
$loadedCells = @(
    $cells | Where-Object {
        [string]$_.cell_kind -ceq "gravity_loaded_support"
    }
)
Assert-Exact (
    $positionCells.Count -eq 4 -and
    @($positionCells | Where-Object { [bool]$_.ok }).Count -eq 4 -and
    $velocityCells.Count -eq 2 -and
    @($velocityCells | Where-Object { [bool]$_.ok }).Count -eq 2 -and
    $loadedCells.Count -eq 2 -and
    @($loadedCells | Where-Object { [bool]$_.ok }).Count -eq 0
) "The C6-RAP-HC-FB1 cell partition or pass vector changed"

$worldAttempts = 0
$worldBuilds = 0
$modelReadbacks = 0
$modelMismatches = 0
$nonfinite = 0
$impulseViolations = 0
foreach ($cell in $cells) {
    Assert-Exact (
        [string]$cell.motor_model_readback -ceq "ForceBased" -and
        [int]$cell.motor_model_mismatch_count -eq 0 -and
        [int]$cell.nonfinite_value_count -eq 0 -and
        [int]$cell.step_impulse_limit_violation_count -eq 0 -and
        [int]$cell.world_attempt_count -eq 1 -and
        [int]$cell.world_build_count -eq 1 -and
        -not [bool]$cell.physical_acceptance_authority
    ) "A retained C6-RAP-HC-FB1 cell changed its integrity boundary"
    $worldAttempts += [int]$cell.world_attempt_count
    $worldBuilds += [int]$cell.world_build_count
    $modelReadbacks += [int]$cell.motor_model_readback_count
    $modelMismatches += [int]$cell.motor_model_mismatch_count
    $nonfinite += [int]$cell.nonfinite_value_count
    $impulseViolations += [int]$cell.step_impulse_limit_violation_count
}

$negativeLoaded = $loadedCells[0]
$positiveLoaded = $loadedCells[1]
Assert-Exact (
    [double]$negativeLoaded.center_of_mass_offset_z_m -lt 0.0 -and
    [double]$positiveLoaded.center_of_mass_offset_z_m -gt 0.0 -and
    [double]$negativeLoaded.final_position_rad -lt 0.0 -and
    [double]$positiveLoaded.final_position_rad -gt 0.0 -and
    [double]$negativeLoaded.terminal_motor_impulse_nms -lt 0.0 -and
    [double]$positiveLoaded.terminal_motor_impulse_nms -gt 0.0 -and
    [math]::Abs([double]$negativeLoaded.final_position_rad) -le 0.1 -and
    [math]::Abs([double]$positiveLoaded.final_position_rad) -le 0.1 -and
    [math]::Abs(
        [double]$negativeLoaded.terminal_motor_impulse_nms
    ) -lt 0.005 -and
    [math]::Abs(
        [double]$positiveLoaded.terminal_motor_impulse_nms
    ) -lt 0.005
) "The frozen loaded-support observations or failing threshold changed"

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
    [int]$aggregate.passed_cell_count -eq 6 -and
    [int]$aggregate.failed_cell_count -eq 2 -and
    [bool]$aggregate.unloaded_position_grid_passed -and
    [bool]$aggregate.signed_velocity_pair_passed -and
    -not [bool]$aggregate.gravity_loaded_support_pair_passed -and
    [bool]$aggregate.paired_loaded_final_angle_signs_opposite -and
    [bool]$aggregate.paired_loaded_terminal_motor_impulse_signs_opposite
) "The C6-RAP-HC-FB1 aggregate did not independently reconstruct"

$expectedFailureCodes = @(
    "C6_RAP_HC_FB1_passed_cell_count_INVALID",
    "C6_RAP_HC_FB1_failed_cell_count_INVALID",
    "C6_RAP_HC_FB1_gravity_loaded_support_pair_passed_INVALID"
)
Assert-Exact (
    (@($report.failure_codes) -join "`n") -ceq
        ($expectedFailureCodes -join "`n")
) "The C6-RAP-HC-FB1 frozen failure vector changed"

Assert-Exact (
    [bool]$manifest.technical_disposition.explicit_force_based_selection_observed_in_every_cell -and
    [bool]$manifest.technical_disposition.unloaded_position_tracking_worked_for_declared_grid -and
    [bool]$manifest.technical_disposition.signed_velocity_mapping_worked_for_declared_pair -and
    [bool]$manifest.technical_disposition.gravity_loaded_angle_bound_worked_for_declared_pair -and
    -not [bool]$manifest.technical_disposition.joint_motor_impulse_minimum_assumption_worked -and
    -not [bool]$manifest.technical_disposition.frozen_success_contract_passed -and
    [bool]$manifest.technical_disposition.result_is_not_a_selected_policy_verdict
) "The C6-RAP-HC-FB1 technical disposition changed"
foreach ($claim in $falseClaims) {
    Assert-Exact (
        -not [bool]$manifest.claims[$claim]
    ) "C6-RAP-HC-FB1 may not authorize $claim"
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
    ) "A C6-RAP-HC-FB1 research source changed"
}

Write-Output (
    "C6_RAP_HC_FB1_CLOSURE_PASS worlds=8 passed=6 failed=2 " +
    "force_based_readback=8 model_mismatches=0 impulse_violations=0 " +
    "loaded_angle_and_sign_gates=True terminal_impulse_minimum=False " +
    "physical_authority=False"
)
