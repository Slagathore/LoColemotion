#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$profilePath = Join-Path $sdkRoot "canonical_velocity_actuation_profile_v1.json"
$implementationPath = Join-Path $sdkRoot "core\src\canonical_actuation.rs"
$libPath = Join-Path $sdkRoot "core\src\lib.rs"
$runtimePath = Join-Path $sdkRoot "core\src\runtime.rs"
$semanticsPath = Join-Path $repoRoot "docs\LOCOMOTION_SEMANTICS_V4.md"
$diagnosticPath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_actuation_semantics_diagnostic.json"
$expectedProfileRawSha256 = (
    "1240ad4bba89bc8d1c22fa270fa718c57ab5ee227d777434b3870b859001e6a3"
)
$expectedDiagnosticRawSha256 = (
    "a42888f04c9a42af78ab3796dee9cc98365592470f81d0153bc55ab2a375ca57"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-ContainsExact {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Needle,
        [Parameter(Mandatory)][string]$Message
    )
    Assert-Exact ($Text.Contains($Needle)) $Message
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Copy-JsonObject {
    param([Parameter(Mandatory)][object]$Value)
    return $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json
}

function Get-ProfileGateFailures {
    param([Parameter(Mandatory)][object]$Candidate)
    $failures = [System.Collections.Generic.List[string]]::new()

    if (
        [string]$Candidate.schema_version -cne
            "sporespore_canonical_velocity_actuation_profile_declaration_v1" -or
        [string]$Candidate.profile_id -cne
            "sporespore_complete_closed_loop_canonical_velocity_v1" -or
        [string]$Candidate.status -cne
            "implemented_zero_world_semantic_successor_not_live_adapter_physical_or_release_authority" -or
        [string]$Candidate.semantic_contract_path -cne
            "docs/LOCOMOTION_SEMANTICS_V4.md" -or
        [string]$Candidate.implementation_path -cne
            "sdk/core/src/canonical_actuation.rs"
    ) {
        $failures.Add("identity")
    }

    if (
        [string]$Candidate.predecessor_diagnostic.diagnostic_id -cne
            "C6-RAP-BW19V-ASD1" -or
        [string]$Candidate.predecessor_diagnostic.path -cne
            "sdk/rapier_c6_bw19v_actuation_semantics_diagnostic.json" -or
        [string]$Candidate.predecessor_diagnostic.raw_sha256 -cne
            $expectedDiagnosticRawSha256 -or
        [string]$Candidate.predecessor_diagnostic.classification -cne
            "confirmed_cross_host_actuation_semantics_defect_with_unresolved_whole_body_causal_effect"
    ) {
        $failures.Add("predecessor")
    }

    $compatibility = $Candidate.compatibility_boundary
    if (
        [bool]$compatibility.frozen_v1_v2_v3_outputs_rewritten -or
        [double]$compatibility.legacy_runtime_motor_direction_sign -ne -1.0 -or
        [bool]$compatibility.legacy_runtime_sign_changed_by_this_profile -or
        -not [bool]$compatibility.new_versioned_overlay -or
        [bool]$compatibility.public_adapter_contract_v1_changed -or
        [bool]$compatibility.public_c_abi_changed
    ) {
        $failures.Add("compatibility")
    }

    $bridge = $Candidate.source_bridge
    if (
        [string]$bridge.source_policy_id -cne
            "sporespore_balanced_wave_bw15f_b_v1" -or
        [string]$bridge.source_velocity_convention_id -cne
            "legacy_godot_host_target_velocity_v1" -or
        [double]$bridge.legacy_host_to_canonical_velocity_sign -ne -1.0 -or
        -not [bool]$bridge.source_actuation_frame_must_validate -or
        [bool]$bridge.source_actuation_frame_mutated -or
        [string]$bridge.canonical_frame_schema -cne
            "sporespore_canonical_velocity_actuation_frame_v1" -or
        [string]$bridge.residual_schema -cne
            "sporespore_canonical_velocity_residual_v1"
    ) {
        $failures.Add("source_bridge")
    }

    $ownership = $Candidate.actuation_ownership
    if (
        [string]$ownership.load_bearing_actuation -cne
            "complete_closed_loop_canonical_target_velocity" -or
        [string]$ownership.position_target_role -cne
            "provenance_and_bounds_only" -or
        -not [bool]$ownership.canonical_to_host_mapping_owned_by_adapter -or
        -not [bool]$ownership.base_and_stability_residual_compose_before_host_conversion -or
        -not [bool]$ownership.one_final_canonical_speed_clamp -or
        -not [bool]$ownership.stability_residual_is_command_not_measurement -or
        [bool]$ownership.adapter_may_add_independent_native_position_feedback -or
        [bool]$ownership.native_target_position_emitted -or
        [double]$ownership.native_position_stiffness -ne 0.0
    ) {
        $failures.Add("ownership")
    }

    $godot = $Candidate.host_profiles.godot_jolt
    if (
        [string]$godot.profile_id -cne
            "godot_jolt_velocity_only_equivalence_v1" -or
        [string]$godot.adapter_id -cne "sporespore_godot_jolt_adapter" -or
        [string]$godot.engine_id -cne "godot_jolt" -or
        [double]$godot.canonical_to_host_velocity_sign -ne -1.0 -or
        [string]$godot.native_motor_model_id -cne
            "hinge_target_velocity_with_impulse_cap" -or
        -not [bool]$godot.retained_host_behavior_equivalence_target -or
        -not [bool]$godot.zero_residual_legacy_host_command_bit_equivalence_proved -or
        [int]$godot.ordered_actuator_count -ne 8 -or
        [bool]$godot.native_position_feedback_applied -or
        [double]$godot.native_position_stiffness -ne 0.0 -or
        [bool]$godot.live_adapter_v4_integration_complete -or
        [bool]$godot.host_response_characterized_for_this_profile
    ) {
        $failures.Add("godot_profile")
    }

    $rapier = $Candidate.host_profiles.rapier
    if (
        [string]$rapier.profile_id -cne
            "rapier_force_based_velocity_only_v1" -or
        [string]$rapier.adapter_id -cne "sporespore_rapier3d_adapter" -or
        [string]$rapier.engine_id -cne "rapier3d" -or
        [double]$rapier.canonical_to_host_velocity_sign -ne 1.0 -or
        [string]$rapier.native_motor_model_id -cne
            "force_based_velocity_only" -or
        [bool]$rapier.retained_host_behavior_equivalence_target -or
        -not [bool]$rapier.canonical_composition_before_host_mapping_proved -or
        [int]$rapier.nonzero_legacy_command_mixed_space_counterexample_count -ne 5 -or
        [int]$rapier.nonzero_legacy_command_count -ne 5 -or
        [bool]$rapier.native_position_feedback_applied -or
        [double]$rapier.native_position_stiffness -ne 0.0 -or
        [bool]$rapier.live_adapter_v4_integration_complete -or
        [bool]$rapier.host_response_characterized_for_this_profile
    ) {
        $failures.Add("rapier_profile")
    }

    $gate = $Candidate.zero_world_gate
    if (
        [int]$gate.focused_rust_test_count -ne 4 -or
        -not [bool]$gate.godot_bit_exact_equivalence_test -or
        -not [bool]$gate.rapier_canonical_composition_test -or
        -not [bool]$gate.malformed_input_and_authority_negative_test -or
        -not [bool]$gate.safe_frame_residual_negative_test -or
        -not [bool]$gate.json_float_roundtrip_enabled -or
        [int]$gate.world_build_count -ne 0 -or
        [int]$gate.scene_insertion_count -ne 0 -or
        [int]$gate.physics_state_mutation_count -ne 0 -or
        [int]$gate.new_physical_observation_count -ne 0 -or
        [bool]$gate.physical_acceptance_authority
    ) {
        $failures.Add("zero_world_gate")
    }

    $negativeProperties = @($Candidate.negative_controls.PSObject.Properties)
    if (
        $negativeProperties.Count -ne 12 -or
        @($negativeProperties | Where-Object { -not [bool]$_.Value }).Count -ne 0
    ) {
        $failures.Add("negative_controls")
    }

    $next = $Candidate.next_gate
    if (
        [bool]$next.additional_rapier_physical_world_allowed_before_prospective_host_characterization_freeze -or
        -not [bool]$next.distinct_campaign_identity_required -or
        -not [bool]$next.force_based_velocity_only_builder_and_mutable_readback_required -or
        -not [bool]$next.zero_position_stiffness_required -or
        -not [bool]$next.damping_force_and_limit_mapping_must_be_frozen -or
        -not [bool]$next.multiple_declared_loads_or_lever_arms_required -or
        -not [bool]$next.signed_pairs_required -or
        -not [bool]$next.complete_synthetic_integrity_preflight_required -or
        -not [bool]$next.paired_early_horizon_screen_required_after_characterization -or
        -not [bool]$next.fresh_selected_policy_validation_required_before_c6
    ) {
        $failures.Add("next_gate")
    }

    $claimProperties = @($Candidate.claims.PSObject.Properties)
    if (
        $claimProperties.Count -ne 14 -or
        @($claimProperties | Where-Object { [bool]$_.Value }).Count -ne 0
    ) {
        $failures.Add("claims")
    }

    return @($failures)
}

foreach ($path in @(
    $profilePath,
    $implementationPath,
    $libPath,
    $runtimePath,
    $semanticsPath,
    $diagnosticPath
)) {
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Required v4 semantics artifact is missing: $path"
}

Assert-Exact (
    (Get-RawSha256 $profilePath) -ceq $expectedProfileRawSha256
) "The v4 profile declaration raw bytes changed"
Assert-Exact (
    (Get-RawSha256 $diagnosticPath) -ceq $expectedDiagnosticRawSha256
) "The predecessor ASD1 diagnostic raw bytes changed"

$profile = Get-Content -Raw -LiteralPath $profilePath | ConvertFrom-Json
$diagnostic = Get-Content -Raw -LiteralPath $diagnosticPath | ConvertFrom-Json
Assert-Exact (
    [string]$diagnostic.diagnostic_id -ceq
        [string]$profile.predecessor_diagnostic.diagnostic_id -and
    [string]$diagnostic.diagnosis.classification -ceq
        [string]$profile.predecessor_diagnostic.classification
) "The v4 profile no longer binds the retained ASD1 diagnosis"

$baseFailures = @(Get-ProfileGateFailures $profile)
Assert-Exact (
    $baseFailures.Count -eq 0
) "The v4 profile failed its declared gate: $($baseFailures -join ',')"

$implementation = Get-Content -Raw -LiteralPath $implementationPath
foreach ($token in @(
    "pub struct CanonicalVelocityActuationFrameV1",
    "pub struct VelocityOnlyHostProfileV1",
    "pub struct VelocityOnlyHostMappingReceiptV1",
    "pub fn canonicalize_and_compose_legacy_velocity_v1",
    "pub fn map_canonical_velocity_to_host_v1",
    "PositionTargetRoleV1::ProvenanceAndBoundsOnly",
    "native_target_position_rad: None",
    "independent_native_position_feedback_applied: false",
    "native_position_stiffness: 0.0",
    "world_build_count: 0",
    "physics_state_modified: false",
    "physical_acceptance_authority: false",
    "godot_mapping_is_bit_exact_legacy_command_equivalence",
    "rapier_mapping_composes_residual_in_canonical_space_before_host_conversion",
    "malformed_residuals_and_host_profiles_fail_closed",
    "safe_frame_rejects_nonzero_stability_residual"
)) {
    Assert-ContainsExact $implementation $token (
        "The v4 implementation token is missing: $token"
    )
}

$libSource = Get-Content -Raw -LiteralPath $libPath
Assert-ContainsExact (
    $libSource
) 'pub mod canonical_actuation;' "The v4 module is not public"
Assert-ContainsExact (
    $libSource
) 'pub const LOCOMOTION_SEMANTICS_V4_VERSION: &str = "sporespore_locomotion_semantics_v4";' (
    "The v4 semantic version constant changed"
)

$runtimeSource = Get-Content -Raw -LiteralPath $runtimePath
Assert-ContainsExact (
    $runtimeSource
) 'const MOTOR_DIRECTION_SIGN: f64 = -1.0;' (
    "The frozen predecessor runtime sign was rewritten"
)

$semanticsSource = Get-Content -Raw -LiteralPath $semanticsPath
foreach ($token in @(
    "implemented zero-world semantic successor",
    "provenance_and_bounds_only",
    "native_target_position_rad = null",
    "native_position_stiffness = 0",
    'Godot/Jolt adapter-owned canonical-to-host velocity sign is `-1`',
    'Rapier adapter-owned canonical-to-host velocity sign is `+1`',
    "grants no live-adapter integration",
    "Before another Rapier world"
)) {
    Assert-ContainsExact $semanticsSource $token (
        "The v4 semantics boundary token is missing: $token"
    )
}

$negativeMutations = @(
    @{
        name = "predecessor_rewrite"
        mutate = { param($copy) $copy.compatibility_boundary.frozen_v1_v2_v3_outputs_rewritten = $true }
    },
    @{
        name = "position_load_bearing"
        mutate = { param($copy) $copy.actuation_ownership.position_target_role = "load_bearing" }
    },
    @{
        name = "godot_sign"
        mutate = { param($copy) $copy.host_profiles.godot_jolt.canonical_to_host_velocity_sign = 1.0 }
    },
    @{
        name = "rapier_native_position_feedback"
        mutate = { param($copy) $copy.host_profiles.rapier.native_position_feedback_applied = $true }
    },
    @{
        name = "rapier_position_stiffness"
        mutate = { param($copy) $copy.host_profiles.rapier.native_position_stiffness = 40.0 }
    },
    @{
        name = "world_count"
        mutate = { param($copy) $copy.zero_world_gate.world_build_count = 1 }
    },
    @{
        name = "live_adapter_completion"
        mutate = { param($copy) $copy.host_profiles.rapier.live_adapter_v4_integration_complete = $true }
    },
    @{
        name = "host_characterization"
        mutate = { param($copy) $copy.host_profiles.rapier.host_response_characterized_for_this_profile = $true }
    },
    @{
        name = "cross_engine_claim"
        mutate = { param($copy) $copy.claims.cross_engine_selected_policy_equivalence = $true }
    },
    @{
        name = "physical_authority"
        mutate = { param($copy) $copy.zero_world_gate.physical_acceptance_authority = $true }
    }
)

$rejectedNegativeControls = 0
foreach ($negative in $negativeMutations) {
    $copy = Copy-JsonObject $profile
    & $negative.mutate $copy
    $failures = @(Get-ProfileGateFailures $copy)
    Assert-Exact (
        $failures.Count -gt 0
    ) "The v4 negative control escaped: $($negative.name)"
    $rejectedNegativeControls++
}

Push-Location -LiteralPath $sdkRoot
try {
    & cargo test `
        -p sporespore-locomotion-core `
        canonical_actuation `
        --offline `
        -- `
        --test-threads=1
    if ($LASTEXITCODE -ne 0) {
        throw "The focused v4 Rust proof failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

Write-Output "ACTUATION_SEMANTICS_V4_PASS"
Write-Output "worlds=0"
Write-Output "rust_tests=4"
Write-Output "ordered_actuators=8"
Write-Output "godot_bit_exact=True"
Write-Output "rapier_mixed_space_nonzero_witnesses=5/5"
Write-Output "native_position_feedback=False"
Write-Output "negative_controls=$rejectedNegativeControls"
Write-Output "live_adapter_authority=False"
Write-Output "physical_authority=False"
