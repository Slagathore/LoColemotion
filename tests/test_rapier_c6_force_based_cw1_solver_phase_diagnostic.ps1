#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$diagnosticPath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_force_based_cw1_solver_phase_diagnostic.json"
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

function Assert-InOrder {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string[]]$Tokens,
        [Parameter(Mandatory)][string]$Message
    )

    $previous = -1
    foreach ($token in $Tokens) {
        $index = $Text.IndexOf(
            $token,
            $previous + 1,
            [StringComparison]::Ordinal
        )
        Assert-Exact ($index -gt $previous) $Message
        $previous = $index
    }
}

Assert-Exact (
    Test-Path -LiteralPath $diagnosticPath -PathType Leaf
) "The C6-RAP-HC-CW1 solver-phase diagnostic is missing"
$diagnostic = (
    Get-Content -Raw -LiteralPath $diagnosticPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$diagnostic.schema_version -ceq
        "sporespore_rapier_c6_force_based_cw1_solver_phase_diagnostic_v1" -and
    [string]$diagnostic.status -ceq
        "retained_zero_world_source_diagnostic_not_acceptance" -and
    [string]$diagnostic.diagnostic_id -ceq "C6-RAP-HC-CW1-SP-D1" -and
    [string]$diagnostic.predecessor_campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-CONVERGENCE-WINDOW" -and
    [string]$diagnostic.predecessor_gate_id -ceq "C6-RAP-HC-CW1" -and
    [int]$diagnostic.world_build_count -eq 0 -and
    -not [bool]$diagnostic.physics_state_modified
) "The C6-RAP-HC-CW1 solver-phase diagnostic identity changed"

foreach ($key in @(
    "cargo_lock",
    "cw1_preregistration",
    "cw1_closure"
)) {
    Assert-HashedFile `
        -Path (
            Join-Path $repoRoot (
                [string]$diagnostic.source_artifacts["${key}_path"]
            )
        ) `
        -ExpectedSha256 (
            [string]$diagnostic.source_artifacts["${key}_sha256"]
        ) `
        -Message "The retained $key artifact changed"
}
Assert-HashedFile `
    -Path ([string]$diagnostic.source_artifacts.cw1_report_path) `
    -ExpectedSha256 ([string]$diagnostic.source_artifacts.cw1_report_sha256) `
    -Message "The retained C6-RAP-HC-CW1 report changed"

$sdkRoot = Join-Path $repoRoot "sdk"
Push-Location -LiteralPath $sdkRoot
try {
    $metadataRaw = (& cargo metadata --format-version 1 --offline)
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Cargo metadata failed during the CW1 solver-phase audit"
} finally {
    Pop-Location
}
$metadata = $metadataRaw | ConvertFrom-Json -AsHashtable
$rapierPackages = @(
    $metadata.packages | Where-Object {
        [string]$_.name -ceq
            [string]$diagnostic.source_artifacts.rapier_package -and
        [string]$_.version -ceq
            [string]$diagnostic.source_artifacts.rapier_version
    }
)
Assert-Exact (
    $rapierPackages.Count -eq 1
) "The solver-phase diagnostic requires exactly one pinned Rapier package"
$rapierRoot = Split-Path -Parent (
    [System.IO.Path]::GetFullPath(
        [string]$rapierPackages[0].manifest_path
    )
)
$rapierPrefix = $rapierRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
$sources = @{}
foreach ($source in @($diagnostic.source_artifacts.rapier_sources)) {
    $path = [System.IO.Path]::GetFullPath(
        (Join-Path $rapierRoot ([string]$source.path))
    )
    Assert-Exact (
        $path.StartsWith(
            $rapierPrefix,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) "A pinned Rapier source path escaped its package"
    Assert-HashedFile `
        -Path $path `
        -ExpectedSha256 ([string]$source.sha256) `
        -Message "Pinned Rapier source changed: $($source.path)"
    $sources[[string]$source.path] = Get-Content -Raw -LiteralPath $path
}
Assert-Exact (
    $sources.Count -eq 8
) "The solver-phase source set must contain exactly eight files"

$parameters = $sources["src/dynamics/integration_parameters.rs"]
foreach ($token in @(
    "pub num_solver_iterations: usize",
    "pub num_internal_pgs_iterations: usize",
    "pub num_internal_stabilization_iterations: usize",
    "num_internal_pgs_iterations: 1",
    "num_internal_stabilization_iterations: 1",
    "num_solver_iterations: 4"
)) {
    Assert-Exact (
        $parameters.Contains($token, [StringComparison]::Ordinal)
    ) "Pinned Rapier integration-parameter semantics changed"
}

$islandSolver = $sources["src/dynamics/solver/island_solver.rs"]
Assert-InOrder `
    -Text $islandSolver `
    -Tokens @(
        "params.dt /= num_solver_iterations as Real;",
        "self.velocity_solver.solve_constraints(",
        "self.joint_constraints.writeback_impulses(impulse_joints);"
    ) `
    -Message "Pinned Rapier outer small-step/writeback order changed"

$velocitySolver = $sources["src/dynamics/solver/velocity_solver.rs"]
Assert-InOrder `
    -Text $velocitySolver `
    -Tokens @(
        "joint_constraints.update(params",
        "for _ in 0..params.num_internal_pgs_iterations",
        "self.integrate_positions(params",
        "for _ in 0..params.num_internal_stabilization_iterations",
        ".solve_wo_bias("
    ) `
    -Message "Pinned Rapier pre/post-integration solver order changed"

$constraintSet = $sources[
    "src/dynamics/solver/joint_constraint/joint_constraints_set.rs"
]
Assert-InOrder `
    -Text $constraintSet `
    -Tokens @(
        "pub fn solve_wo_bias(",
        "c.remove_bias();",
        "c.solve("
    ) `
    -Message "Pinned Rapier stabilization solve semantics changed"

$constraint = $sources[
    "src/dynamics/solver/joint_constraint/joint_velocity_constraint.rs"
]
foreach ($token in @(
    "self.rhs = self.rhs_wo_bias;",
    "WritebackId::Motor(i) => joint.data.motors[i].impulse = self.impulse"
)) {
    Assert-Exact (
        $constraint.Contains($token, [StringComparison]::Ordinal)
    ) "Pinned Rapier motor bias/writeback semantics changed"
}

$builder = $sources[
    "src/dynamics/solver/joint_constraint/joint_constraint_builder.rs"
]
$motorStart = $builder.IndexOf(
    "pub fn motor_angular<const LANES: usize>",
    [StringComparison]::Ordinal
)
$motorEnd = $builder.IndexOf(
    "pub fn lock_angular<const LANES: usize>",
    $motorStart,
    [StringComparison]::Ordinal
)
Assert-Exact (
    $motorStart -ge 0 -and $motorEnd -gt $motorStart
) "Pinned Rapier angular-motor builder could not be isolated"
$motorBuilder = $builder.Substring($motorStart, $motorEnd - $motorStart)
Assert-InOrder `
    -Text $motorBuilder `
    -Tokens @(
        "rhs_wo_bias +=",
        "rhs_wo_bias += -motor_params.target_vel;",
        "rhs: rhs_wo_bias,",
        "rhs_wo_bias,"
    ) `
    -Message "Pinned Rapier angular-motor rhs semantics changed"

$motorModel = $sources["src/dynamics/joint/motor_model.rs"]
foreach ($token in @(
    "MotorModel::ForceBased =>",
    "let erp_inv_dt = stiffness",
    "let cfm_gain = crate::utils::inv(dt * dt * stiffness + dt * damping);"
)) {
    Assert-Exact (
        $motorModel.Contains($token, [StringComparison]::Ordinal)
    ) "Pinned Rapier ForceBased coefficient semantics changed"
}
$genericJoint = $sources["src/dynamics/joint/generic_joint.rs"]
Assert-Exact (
    $genericJoint.Contains(
        "max_impulse: self.max_force * dt",
        [StringComparison]::Ordinal
    )
) "Pinned Rapier motor force-to-small-step-impulse mapping changed"

$legacy = $diagnostic.legacy_adapter_configuration
Assert-Exact (
    [int]$legacy.num_internal_pgs_iterations -eq 1 -and
    [int]$legacy.num_internal_stabilization_iterations -eq 7 -and
    [int]$legacy.total_joint_constraint_passes_per_small_step -eq 8 -and
    [int]$legacy.pre_integration_passes -eq 1 -and
    [int]$legacy.post_integration_passes -eq 7 -and
    [math]::Abs([double]$legacy.post_integration_pass_fraction - 0.875) -le
        1.0e-15 -and
    -not [bool]$legacy.matches_rapier_default_phase_allocation
) "The retained legacy solver-phase reconstruction changed"

$report = (
    Get-Content -Raw -LiteralPath (
        [string]$diagnostic.source_artifacts.cw1_report_path
    ) |
        ConvertFrom-Json -AsHashtable
)
$solver12 = @(
    $report.cells | Where-Object {
        [int]$_.solver_iterations -eq 12
    }
)
$solver36 = @(
    $report.cells | Where-Object {
        [int]$_.solver_iterations -eq 36
    }
)
Assert-Exact (
    $solver12.Count -eq 4 -and
    @($solver12 | Where-Object { [bool]$_.ok }).Count -eq 0 -and
    @(
        $solver12 | Where-Object {
            [int]$_.observation_steps_executed -eq 1440
        }
    ).Count -eq 4 -and
    [int](
        $solver12.longest_consecutive_converged_steps |
            Measure-Object -Maximum
    ).Maximum -eq 42 -and
    [math]::Abs(
        [double](
            $solver12.damping_load_fraction |
                Measure-Object -Maximum
        ).Maximum -
        [double]$diagnostic.retained_cw1_observation.solver_12.
            maximum_terminal_damping_load_fraction
    ) -le 1.0e-15
) "The retained CW1 solver-12 partition changed"
Assert-Exact (
    $solver36.Count -eq 4 -and
    @($solver36 | Where-Object { [bool]$_.ok }).Count -eq 4 -and
    [int](
        $solver36.convergence_window_end_step |
            Measure-Object -Minimum
    ).Minimum -eq 203 -and
    [int](
        $solver36.convergence_window_end_step |
            Measure-Object -Maximum
    ).Maximum -eq 204 -and
    -not [bool]$report.ok -and
    -not [bool]$report.rapier_force_based_host_characterization
) "The retained CW1 solver-36 partition or negative boundary changed"

Assert-Exact (
    -not [bool]$diagnostic.interpretation.architecture_killed -and
    -not [bool]$diagnostic.interpretation.force_based_selection_disproved -and
    -not [bool]$diagnostic.interpretation.cw1_reclassified_positive -and
    -not [bool]$diagnostic.interpretation.host_characterization_authorized -and
    [string]$diagnostic.successor_hypothesis.classification -ceq
        "prospective_development_screen_hypothesis_not_validation" -and
    [bool]$diagnostic.successor_hypothesis.equal_total_pass_count_required -and
    [bool]$diagnostic.successor_hypothesis.legacy_one_plus_seven_control_required -and
    [bool]$diagnostic.successor_hypothesis.
        complete_zero_world_trace_and_selector_preflight_required -and
    [bool]$diagnostic.successor_hypothesis.
        selected_configuration_requires_fresh_independent_validation -and
    [bool]$diagnostic.successor_hypothesis.
        development_screen_may_not_authorize_host_or_selected_policy_claims
) "The solver-phase interpretation or successor boundary changed"
foreach ($claim in $falseClaims) {
    Assert-Exact (
        -not [bool]$diagnostic.claims[$claim]
    ) "The solver-phase diagnostic may not authorize $claim"
}

Write-Output (
    "C6_RAP_HC_CW1_SOLVER_PHASE_DIAGNOSTIC_PASS sources=8 worlds=0 " +
    "pre_integration_passes=1 post_integration_passes=7 " +
    "cw1_solver12_passed=0/4 cw1_solver36_passed=4/4 " +
    "causal_mechanism_confirmed=False physical_authority=False"
)
