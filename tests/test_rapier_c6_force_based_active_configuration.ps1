#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_force_based_active_configuration.json"
$closurePath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_force_based_selected_configuration_validation_spv1_closure.json"
$expectedClosureSha256 = (
    "7830f66de49f1d7c2d5b88d151c0c2d5077782903457837d7ecd0da2fb724203"
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

function Read-RepoText {
    param([Parameter(Mandatory)][string]$RelativePath)

    $path = Join-Path $repoRoot $RelativePath
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "The active Rapier configuration surface is missing: $RelativePath"
    return Get-Content -Raw -LiteralPath $path
}

function Assert-TextContains {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Needle,
        [Parameter(Mandatory)][string]$Message
    )

    Assert-Exact $Text.Contains($Needle, [System.StringComparison]::Ordinal) (
        $Message
    )
}

Assert-Exact (
    Test-Path -LiteralPath $manifestPath -PathType Leaf
) "The active Rapier configuration manifest is missing"
Assert-Exact (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "The C6-RAP-HC-SPV1 closure is missing"
Assert-Exact (
    (Get-Sha256 -Path $closurePath) -ceq $expectedClosureSha256
) "The C6-RAP-HC-SPV1 closure changed"

$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)
$closure = (
    Get-Content -Raw -LiteralPath $closurePath |
        ConvertFrom-Json -AsHashtable
)

Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_rapier_c6_force_based_active_configuration_v1" -and
    [string]$manifest.status -ceq
        "active_after_positive_spv1_exact_finite_host_validation" -and
    [string]$manifest.adapter_id -ceq "sporespore_rapier3d_adapter" -and
    [string]$manifest.authority.path -ceq
        "sdk/rapier_c6_force_based_selected_configuration_validation_spv1_closure.json" -and
    [string]$manifest.authority.raw_sha256 -ceq $expectedClosureSha256 -and
    [string]$manifest.authority.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-SELECTED-CONFIGURATION-VALIDATION" -and
    [string]$manifest.authority.gate_id -ceq "C6-RAP-HC-SPV1" -and
    [string]$manifest.authority.experiment_source_commit -ceq
        "b8e3442d88ff3e6340117bcc70e1f109ad532068" -and
    [bool]$manifest.authority.exact_finite_selected_configuration_validation_passed -and
    [bool]$manifest.authority.adapter_configuration_change_explicitly_authorized
) "The active Rapier configuration authority changed"

Assert-Exact (
    [string]$closure.status -ceq
        "closed_positive_exact_finite_host_validation" -and
    [bool]$closure.technical_disposition.exact_finite_selected_configuration_validation_passed -and
    -not [bool]$closure.technical_disposition.adapter_default_change_automatically_performed -and
    [bool]$closure.technical_disposition.adapter_configuration_change_requires_separate_commit_and_conformance -and
    [bool]$closure.next_allowed_work.distinct_adapter_configuration_update_to_validated_3_5_may_proceed -and
    [bool]$closure.next_allowed_work.adapter_capability_manifest_and_all_active_rapier_paths_must_change_together -and
    [bool]$closure.next_allowed_work.complete_zero_world_and_full_conformance_required_after_adapter_change -and
    -not [bool]$closure.claims.rapier_selected_policy_physical_authority -and
    -not [bool]$closure.claims.rapier_locomotion_acceptance -and
    -not [bool]$closure.claims.release_authorized
) "The SPV1 authorization or claim boundary changed"

Assert-Exact (
    [string]$manifest.host.engine -ceq "rapier3d" -and
    [string]$manifest.host.engine_version -ceq "0.34.0" -and
    [string]$manifest.host.motor_model -ceq "ForceBased" -and
    [math]::Abs(
        [double]$manifest.host.outer_timestep_s -
        [double]$closure.validated_configuration.outer_timestep_s
    ) -le 1.0e-15 -and
    [int]$manifest.host.solver_iterations -eq 16 -and
    [int]$manifest.host.num_internal_pgs_iterations -eq 3 -and
    [int]$manifest.host.num_internal_stabilization_iterations -eq 5 -and
    [int]$manifest.host.total_constraint_passes_per_small_step -eq 8 -and
    [int]$manifest.host.solver_iterations -eq
        [int]$closure.validated_configuration.solver_iterations -and
    [int]$manifest.host.num_internal_pgs_iterations -eq
        [int]$closure.validated_configuration.num_internal_pgs_iterations -and
    [int]$manifest.host.num_internal_stabilization_iterations -eq
        [int]$closure.validated_configuration.num_internal_stabilization_iterations
) "The active Rapier configuration differs from the SPV1-validated values"

$expectedActiveSurfaces = @(
    "sdk/adapters/rapier/src/active_configuration.rs",
    "sdk/adapters/rapier/src/lib.rs",
    "sdk/adapters/rapier/src/conformance.rs",
    "sdk/adapters/rapier/src/locomotion.rs"
)
$actualActiveSurfaces = @(
    $manifest.active_surfaces |
        ForEach-Object { [string]$_.path }
)
Assert-Exact (
    $actualActiveSurfaces.Count -eq $expectedActiveSurfaces.Count -and
    -not (Compare-Object $expectedActiveSurfaces $actualActiveSurfaces)
) "The declared active Rapier configuration surfaces changed"

$activeConfigurationSource = Read-RepoText (
    "sdk\adapters\rapier\src\active_configuration.rs"
)
$libSource = Read-RepoText "sdk\adapters\rapier\src\lib.rs"
$conformanceSource = Read-RepoText "sdk\adapters\rapier\src\conformance.rs"
$locomotionSource = Read-RepoText "sdk\adapters\rapier\src\locomotion.rs"

foreach ($binding in @(
    @("RAPIER_ACTIVE_SOLVER_ITERATIONS: usize = 16;", "solver iteration"),
    @("RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS: usize = 3;", "PGS iteration"),
    @(
        "RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS: usize = 5;",
        "stabilization iteration"
    )
)) {
    Assert-TextContains -Text $activeConfigurationSource -Needle $binding[0] `
        -Message "The active Rapier $($binding[1]) binding changed"
}
Assert-Exact (
    ([regex]::Matches(
        $activeConfigurationSource,
        [regex]::Escape("PhysicsWorld::new()")
    )).Count -eq 1
) "The active Rapier world constructor count changed"

foreach ($bindingName in @(
    "RAPIER_ACTIVE_SOLVER_ITERATIONS",
    "RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS",
    "RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS"
)) {
    Assert-TextContains -Text $libSource -Needle $bindingName -Message (
        "The capability manifest no longer consumes $bindingName"
    )
}

foreach ($surface in @(
    @("conformance", $conformanceSource),
    @("locomotion", $locomotionSource)
)) {
    Assert-Exact (
        ([regex]::Matches(
            $surface[1],
            [regex]::Escape("new_active_world(")
        )).Count -eq 1 -and
        -not $surface[1].Contains(
            "PhysicsWorld::new()",
            [System.StringComparison]::Ordinal
        )
    ) "The active Rapier $($surface[0]) world path bypassed its shared configuration"
}

foreach ($needle in @(
    ".motor_model(MotorModel::ForceBased)",
    ".set_motor_model(MotorModel::ForceBased)",
    "Some(MotorModel::ForceBased)"
)) {
    Assert-TextContains -Text $locomotionSource -Needle $needle -Message (
        "The active locomotion ForceBased selection/readback contract changed"
    )
}

foreach ($historicalModule in @(
    $manifest.historical_exclusions.modules |
        ForEach-Object { [string]$_ }
)) {
    $historicalSource = Read-RepoText (
        $historicalModule.Replace("/", "\")
    )
    Assert-Exact (
        -not $historicalSource.Contains(
            "new_active_world",
            [System.StringComparison]::Ordinal
        ) -and
        -not $historicalSource.Contains(
            "RAPIER_ACTIVE_",
            [System.StringComparison]::Ordinal
        )
    ) "A frozen Rapier campaign was coupled to mutable active configuration: $historicalModule"
}

foreach ($claim in @(
    "selected_policy_locomotion_evaluated_by_this_change",
    "rapier_locomotion_acceptance",
    "cross_engine_c6",
    "friction_or_material_robustness",
    "walking_acceptance",
    "release_authorized",
    "physical_acceptance_authority",
    "completed_engine_neutral_sdk"
)) {
    Assert-Exact (
        -not [bool]$manifest.claim_boundary[$claim]
    ) "The active Rapier configuration may not authorize $claim"
}

Assert-Exact (
    [bool]$manifest.claim_boundary.adapter_configuration_is_active -and
    [bool]$manifest.claim_boundary.active_c2_c5_and_locomotion_worlds_share_the_validated_configuration -and
    [bool]$manifest.claim_boundary.force_based_builder_and_mutable_readback_remain_required -and
    [bool]$manifest.next_allowed_work.distinct_selected_policy_rapier_campaign_may_be_preregistered -and
    [bool]$manifest.next_allowed_work.selected_policy_campaign_must_use_exact_bw19v_scale_0_5 -and
    [bool]$manifest.next_allowed_work.selected_policy_campaign_must_use_current_portable_support_contribution -and
    [bool]$manifest.next_allowed_work.complete_zero_world_synthetic_gate_required_before_any_world -and
    [bool]$manifest.next_allowed_work.spv1_must_not_be_rerun_or_reinterpreted
) "The active Rapier configuration disposition changed"

Write-Output (
    "C6_RAP_ACTIVE_CONFIGURATION_PASS " +
    "solver=16 internal_pgs=3 internal_stabilization=5 " +
    "force_based=True selected_policy_authority=False"
)
