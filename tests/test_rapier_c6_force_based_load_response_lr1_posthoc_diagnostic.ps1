#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$diagnosticPath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_force_based_load_response_lr1_posthoc_diagnostic.json"
$falseClaims = @(
    "rapier_force_based_load_response_characterization",
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
    Test-Path -LiteralPath $diagnosticPath -PathType Leaf
) "The C6-RAP-HC-LR1 post-hoc diagnostic is missing"
$diagnostic = (
    Get-Content -Raw -LiteralPath $diagnosticPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$diagnostic.schema_version -ceq
        "sporespore_rapier_c6_force_based_load_response_posthoc_diagnostic_v1" -and
    [string]$diagnostic.status -ceq
        "retained_zero_world_posthoc_mechanism_diagnostic_not_acceptance" -and
    [string]$diagnostic.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-LOAD-RESPONSE" -and
    [string]$diagnostic.gate_id -ceq "C6-RAP-HC-LR1" -and
    [string]$diagnostic.diagnostic_id -ceq "C6-RAP-HC-LR1-PD-D1" -and
    [int]$diagnostic.world_build_count -eq 0 -and
    -not [bool]$diagnostic.physics_state_modified
) "The C6-RAP-HC-LR1 post-hoc diagnostic identity changed"

Assert-HashedFile `
    -Path ([string]$diagnostic.source_artifacts.report_path) `
    -ExpectedSha256 ([string]$diagnostic.source_artifacts.report_sha256) `
    -Message "The retained C6-RAP-HC-LR1 report changed"
Assert-HashedFile `
    -Path (
        Join-Path $repoRoot ([string]$diagnostic.source_artifacts.closure_path)
    ) `
    -ExpectedSha256 ([string]$diagnostic.source_artifacts.closure_sha256) `
    -Message "The C6-RAP-HC-LR1 closure changed"
Assert-HashedFile `
    -Path (
        Join-Path $repoRoot (
            [string]$diagnostic.source_artifacts.preregistration_path
        )
    ) `
    -ExpectedSha256 (
        [string]$diagnostic.source_artifacts.preregistration_sha256
    ) `
    -Message "The C6-RAP-HC-LR1 preregistration changed"

$sdkRoot = Join-Path $repoRoot "sdk"
Push-Location -LiteralPath $sdkRoot
try {
    $metadataRaw = (& cargo metadata --format-version 1 --offline)
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Cargo metadata failed during the LR1 post-hoc source audit"
} finally {
    Pop-Location
}
$metadata = $metadataRaw | ConvertFrom-Json -AsHashtable
$rapierPackages = @(
    $metadata.packages | Where-Object {
        [string]$_.name -ceq "rapier3d" -and
        [string]$_.version -ceq "0.34.0"
    }
)
Assert-Exact (
    $rapierPackages.Count -eq 1
) "The LR1 post-hoc diagnostic requires exactly one Rapier 0.34.0 package"
$rapierRoot = Split-Path -Parent (
    [System.IO.Path]::GetFullPath(
        [string]$rapierPackages[0].manifest_path
    )
)
$motorModelSourcePath = [System.IO.Path]::GetFullPath(
    (
        Join-Path $rapierRoot (
            [string]$diagnostic.source_artifacts.rapier_motor_model_source_path
        )
    )
)
$rapierPrefix = $rapierRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
Assert-Exact (
    $motorModelSourcePath.StartsWith(
        $rapierPrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
) "The LR1 post-hoc motor-model source escaped the Rapier package"
Assert-HashedFile `
    -Path $motorModelSourcePath `
    -ExpectedSha256 (
        [string]$diagnostic.source_artifacts.rapier_motor_model_source_sha256
    ) `
    -Message "The pinned Rapier ForceBased PD equation source changed"

$report = (
    Get-Content -Raw -LiteralPath (
        [string]$diagnostic.source_artifacts.report_path
    ) |
        ConvertFrom-Json -AsHashtable
)
$reportedCells = @($report.cells)
$diagnosticCells = @($diagnostic.cells)
Assert-Exact (
    $reportedCells.Count -eq 8 -and
    $diagnosticCells.Count -eq 8 -and
    (@($reportedCells.cell_id) -join "`n") -ceq
        (@($diagnosticCells.cell_id) -join "`n")
) "The C6-RAP-HC-LR1 post-hoc diagnostic cell identity changed"

$maximumStaticResidual = 0.0
$maximumDampingFraction = 0.0
$maximumFullPdResidual = 0.0
for ($index = 0; $index -lt $reportedCells.Count; $index++) {
    $reported = $reportedCells[$index]
    $retained = $diagnosticCells[$index]
    $angle = [double]$reported.final_angle_rad
    $angularVelocity = [double]$reported.terminal_angular_velocity_rad_s
    $armMagnitude = [math]::Abs([double]$reported.signed_lever_arm_z_m)
    $gravityTorque = (
        9.8 *
        $armMagnitude *
        [math]::Cos([math]::Abs($angle))
    )
    $fullPdTorque = [math]::Abs(
        40.0 * $angle +
        10.0 * $angularVelocity
    )
    $dampingFraction = (
        10.0 *
        [math]::Abs($angularVelocity) /
        $gravityTorque
    )
    $fullPdResidual = (
        [math]::Abs($fullPdTorque - $gravityTorque) /
        $gravityTorque
    )
    $staticResidual = [double]$reported.normalized_static_torque_residual
    Assert-Exact (
        [math]::Abs(
            [double]$retained.frozen_static_residual - $staticResidual
        ) -le 1.0e-12 -and
        [math]::Abs(
            [double]$retained.gravity_torque_nm - $gravityTorque
        ) -le 1.0e-12 -and
        [math]::Abs(
            [double]$retained.reconstructed_full_pd_torque_nm - $fullPdTorque
        ) -le 1.0e-12 -and
        [math]::Abs(
            [double]$retained.damping_load_fraction - $dampingFraction
        ) -le 1.0e-12 -and
        [math]::Abs(
            [double]$retained.full_pd_gravity_residual - $fullPdResidual
        ) -le 1.0e-12
    ) "A C6-RAP-HC-LR1 post-hoc cell did not independently reconstruct"
    $maximumStaticResidual = [math]::Max(
        $maximumStaticResidual,
        $staticResidual
    )
    $maximumDampingFraction = [math]::Max(
        $maximumDampingFraction,
        $dampingFraction
    )
    $maximumFullPdResidual = [math]::Max(
        $maximumFullPdResidual,
        $fullPdResidual
    )
}

Assert-Exact (
    [math]::Abs(
        [double]$diagnostic.aggregate.maximum_frozen_static_residual -
        $maximumStaticResidual
    ) -le 1.0e-12 -and
    [math]::Abs(
        [double]$diagnostic.aggregate.maximum_damping_load_fraction -
        $maximumDampingFraction
    ) -le 1.0e-12 -and
    [math]::Abs(
        [double]$diagnostic.aggregate.maximum_full_pd_gravity_residual -
        $maximumFullPdResidual
    ) -le 1.0e-12 -and
    $maximumStaticResidual -gt 0.02 -and
    $maximumDampingFraction -gt 0.02 -and
    $maximumFullPdResidual -lt 0.00015 -and
    [bool]$diagnostic.aggregate.frozen_static_failures_explained_by_nonzero_damping_contribution -and
    [bool]$diagnostic.aggregate.source_derived_small_step_impulse_result_unchanged -and
    [bool]$diagnostic.aggregate.lr1_frozen_result_unchanged -and
    [bool]$diagnostic.aggregate.lr1_remains_closed_negative
) "The C6-RAP-HC-LR1 post-hoc aggregate changed"

Assert-Exact (
    -not [bool]$diagnostic.interpretation.architecture_killed -and
    -not [bool]$diagnostic.interpretation.force_based_selection_disproved -and
    -not [bool]$diagnostic.interpretation.joint_motor_impulse_small_step_semantics_disproved -and
    -not [bool]$diagnostic.interpretation.lr1_passed -and
    [bool]$diagnostic.interpretation.posthoc_result_may_not_satisfy_lr1_gate -and
    [bool]$diagnostic.interpretation.posthoc_result_may_inform_only_a_distinct_successor -and
    [bool]$diagnostic.successor_hypothesis.fresh_physical_cells_required -and
    [bool]$diagnostic.successor_hypothesis.new_campaign_gate_source_and_preregistration_required -and
    [bool]$diagnostic.successor_hypothesis.complete_zero_world_preflight_required
) "The C6-RAP-HC-LR1 post-hoc interpretation boundary changed"
foreach ($claim in $falseClaims) {
    Assert-Exact (
        -not [bool]$diagnostic.claims[$claim]
    ) "The C6-RAP-HC-LR1 post-hoc diagnostic may not authorize $claim"
}

Write-Output (
    "C6_RAP_HC_LR1_POSTHOC_DIAGNOSTIC_PASS cells=8 worlds=0 " +
    "maximum_static_residual=$maximumStaticResidual " +
    "maximum_damping_fraction=$maximumDampingFraction " +
    "maximum_full_pd_residual=$maximumFullPdResidual " +
    "lr1_remains_negative=True physical_authority=False"
)
