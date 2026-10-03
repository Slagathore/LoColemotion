#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_velocity_only_active_configuration_v2.json"
$declarationPath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_velocity_only_live_integration_v1.json"
$vh1ClosurePath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.json"
$v1Path = Join-Path (
    $repoRoot
) "sdk\rapier_c6_force_based_active_configuration.json"

$expectedDeclarationSha256 = (
    "7c4c7435ca02f30073d5a33fce162fef67a461340ae609225b096abe59f88507"
)
$expectedVh1ClosureSha256 = (
    "d94b20ef4767479172408c1dfbd0b7f66e18e3f4bc8b9d8d84193fc157d284aa"
)
$expectedV1Sha256 = (
    "dc1eb57df75a41cb5ab80c45e537e7bd0974df0ac9cc7d738e24f08daaf60737"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)

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

function Read-RepoText {
    param([Parameter(Mandatory)][string]$RelativePath)

    $path = Join-Path $repoRoot $RelativePath
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Missing Rapier v4 active surface: $RelativePath"
    return Get-Content -Raw -LiteralPath $path
}

foreach ($path in @(
    $manifestPath,
    $declarationPath,
    $vh1ClosurePath,
    $v1Path
)) {
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Missing Rapier v4 authority: $path"
}
Assert-Exact (
    (Get-Sha256 -Path $declarationPath) -ceq $expectedDeclarationSha256 -and
    (Get-Sha256 -Path $vh1ClosurePath) -ceq $expectedVh1ClosureSha256 -and
    (Get-Sha256 -Path $v1Path) -ceq $expectedV1Sha256
) "A Rapier v4 predecessor or live declaration changed"

$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)
$declaration = (
    Get-Content -Raw -LiteralPath $declarationPath |
        ConvertFrom-Json -AsHashtable
)
$vh1Closure = (
    Get-Content -Raw -LiteralPath $vh1ClosurePath |
        ConvertFrom-Json -AsHashtable
)

Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_rapier_c6_velocity_only_active_configuration_v2" -and
    [string]$manifest.status -ceq
        "active_semantic_integration_after_positive_vh1_and_zero_world_live_gate" -and
    [string]$manifest.adapter_id -ceq "sporespore_rapier3d_adapter" -and
    [string]$manifest.predecessor_configuration.raw_sha256 -ceq
        $expectedV1Sha256 -and
    [string]$manifest.authorities.velocity_only_host_characterization.
        raw_sha256 -ceq $expectedVh1ClosureSha256 -and
    [string]$manifest.authorities.live_integration.raw_sha256 -ceq
        $expectedDeclarationSha256 -and
    [bool]$manifest.authorities.velocity_only_host_characterization.
        exact_finite_velocity_only_host_characterization_passed -and
    [int]$manifest.authorities.live_integration.world_build_count -eq 0 -and
    -not [bool]$manifest.authorities.live_integration.
        physical_acceptance_authority
) "The Rapier v4 authority chain changed"

Assert-Exact (
    [string]$vh1Closure.status -ceq
        "closed_positive_exact_finite_velocity_only_host_characterization" -and
    [bool]$vh1Closure.technical_disposition.
        exact_finite_velocity_only_host_characterization_passed -and
    -not [bool]$vh1Closure.technical_disposition.
        live_v4_adapter_integration_performed -and
    [bool]$vh1Closure.next_allowed_work.
        integrate_the_exact_v4_velocity_only_profile_into_all_active_rapier_motor_write_paths -and
    -not [bool]$vh1Closure.claims.rapier_selected_policy_physical_authority
) "The VH1 disposition or integration authorization changed"

Assert-Exact (
    [string]$manifest.host.engine -ceq "rapier3d" -and
    [string]$manifest.host.engine_version -ceq "0.34.0" -and
    [int]$manifest.host.solver_iterations -eq 16 -and
    [int]$manifest.host.num_internal_pgs_iterations -eq 3 -and
    [int]$manifest.host.num_internal_stabilization_iterations -eq 5 -and
    [string]$manifest.active_v4_profile.canonical_semantics_version -ceq
        "sporespore_locomotion_semantics_v4" -and
    [string]$manifest.active_v4_profile.host_profile_id -ceq
        "rapier_force_based_velocity_only_v1" -and
    [string]$manifest.active_v4_profile.portable_controller_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [double]$manifest.active_v4_profile.
        bw19v_global_requested_correction_scale -eq 0.5 -and
    [string]$manifest.active_v4_profile.motor_model -ceq "ForceBased" -and
    [string]$manifest.active_v4_profile.native_mode -ceq "velocity_only" -and
    [double]$manifest.active_v4_profile.
        native_position_stiffness_nm_per_rad -eq 0.0 -and
    [double]$manifest.active_v4_profile.damping_nm_s_per_rad -eq 10.0 -and
    [bool]$manifest.active_v4_profile.maximum_force_has_no_hidden_margin -and
    [bool]$manifest.active_v4_profile.small_step_impulse_limit_checked
) "The active Rapier v4 motor profile changed"

$expectedSurfaces = @(
    "sdk/adapters/rapier/src/velocity_only_live_integration.rs",
    "sdk/adapters/rapier/src/bw19v_composition.rs",
    "sdk/adapters/rapier/src/locomotion.rs",
    "sdk/adapters/rapier/src/lib.rs",
    "sdk/run_rapier_c6_velocity_only_live_integration_preflight.ps1"
)
$actualSurfaces = @(
    $manifest.active_v4_surfaces |
        ForEach-Object { [string]$_.path }
)
Assert-Exact (
    $actualSurfaces.Count -eq $expectedSurfaces.Count -and
    -not (Compare-Object $expectedSurfaces $actualSurfaces)
) "The active Rapier v4 surface inventory changed"

$integrationSource = Read-RepoText (
    "sdk\adapters\rapier\src\velocity_only_live_integration.rs"
)
$compositionSource = Read-RepoText (
    "sdk\adapters\rapier\src\bw19v_composition.rs"
)
$locomotionSource = Read-RepoText (
    "sdk\adapters\rapier\src\locomotion.rs"
)
$libSource = Read-RepoText "sdk\adapters\rapier\src\lib.rs"

foreach ($needle in @(
    "build_velocity_only_joint_v1",
    ".motor_velocity(",
    ".motor_model(MotorModel::ForceBased)",
    "update_velocity_only_motor_v1",
    ".set_motor_velocity(",
    ".set_motor_model(MotorModel::ForceBased)",
    "velocity_only_small_step_impulse_limit_v1",
    "run_velocity_only_live_integration_preflight"
)) {
    Assert-Exact (
        $integrationSource.Contains($needle, [StringComparison]::Ordinal)
    ) "The shared Rapier v4 motor contract lost: $needle"
}

foreach ($needle in @(
    "compose_bw19v_step_v4",
    "map_bw19v_velocity_only_v4",
    "canonicalize_and_compose_legacy_velocity_v1",
    "map_canonical_velocity_to_host_v1",
    "retained_historical_mixed_space_projection"
)) {
    Assert-Exact (
        $compositionSource.Contains($needle, [StringComparison]::Ordinal)
    ) "The Rapier v4 canonical composition lost: $needle"
}

foreach ($needle in @(
    "build_bw19v_velocity_only_v4_robot",
    "HostMotorProfile::CanonicalVelocityOnlyV4",
    "apply_bw19v_velocity_only_v4_actuation",
    "hold_velocity_only_v4_zero_and_step",
    "build_velocity_only_joint_v1(builder, 0.0, maximum_force)",
    "update_velocity_only_motor_v1("
)) {
    Assert-Exact (
        $locomotionSource.Contains($needle, [StringComparison]::Ordinal)
    ) "The prospective Rapier v4 locomotion path lost: $needle"
}
Assert-Exact (
    ([regex]::Matches(
        $locomotionSource,
        [regex]::Escape("new_active_world(")
    )).Count -eq 1 -and
    -not $locomotionSource.Contains(
        "PhysicsWorld::new()",
        [StringComparison]::Ordinal
    )
) "The versioned Rapier locomotion paths bypassed shared world configuration"

foreach ($needle in @(
    'sporespore_rapier_adapter_manifest_v2',
    '"canonical_velocity_semantics_version"',
    '"velocity_only_live_profile_id"',
    '"velocity_only_host_characterization_closure_sha256"',
    '"velocity_only_live_semantic_integration_preflight"',
    '"velocity_only_selected_policy_physical_evaluation": false'
)) {
    Assert-Exact (
        $libSource.Contains($needle, [StringComparison]::Ordinal)
    ) "The Rapier v2 capability receipt lost: $needle"
}

Assert-Exact (
    [bool]$declaration.claim_boundary.
        rapier_v4_live_adapter_semantic_integration -and
    -not [bool]$declaration.claim_boundary.
        rapier_v4_selected_policy_world_executed -and
    [bool]$declaration.retained_historical_boundary.
        no_frozen_campaign_was_rerun_rethresholded_or_reclassified -and
    [bool]$manifest.entrypoint_contract.
        old_mixed_space_projection_may_be_applied -eq $false -and
    [bool]$manifest.entrypoint_contract.
        old_combined_pd_application_may_be_called_by_a_v4_campaign -eq $false -and
    [bool]$manifest.generic_conformance_boundary.
        c4_position_velocity_motor_fixture_is_not_reclassified_as_v4_locomotion -and
    [bool]$manifest.next_allowed_work.
        complete_prospectively_frozen_synthetic_gate_required_before_any_world
) "The v4 historical, generic-conformance, or next-work boundary changed"

foreach ($claim in @(
    "rapier_v4_selected_policy_world_executed",
    "rapier_selected_policy_physical_authority",
    "rapier_locomotion_acceptance",
    "walking_acceptance",
    "cross_engine_selected_policy_equivalence",
    "friction_or_material_robustness",
    "arbitrary_quadruped_coverage",
    "continuous_full_volume_coverage",
    "release_authorized",
    "physical_acceptance_authority",
    "completed_engine_neutral_sdk"
)) {
    Assert-Exact (
        -not [bool]$manifest.claim_boundary[$claim]
    ) "The zero-world Rapier v4 integration may not authorize $claim"
}
Assert-Exact (
    [bool]$manifest.claim_boundary.
        rapier_v4_live_adapter_semantic_integration
) "The active v2 manifest must declare its bounded semantic integration"

Write-Output (
    "C6_RAP_V4_ACTIVE_CONFIGURATION_PASS " +
    "profile=velocity_only policy=BW15F-B scale=0.5 worlds=0 " +
    "physical_authority=False"
)
