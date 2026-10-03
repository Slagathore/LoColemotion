[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$declarationPath = Join-Path (
    $sdkRoot
) "rapier_c6_velocity_only_live_integration_v1.json"
$expectedDeclarationSha256 = (
    "7c4c7435ca02f30073d5a33fce162fef67a461340ae609225b096abe59f88507"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)

    if (-not $Condition) {
        throw $Message
    }
}

Assert-Exact (
    (Test-Path -LiteralPath $declarationPath -PathType Leaf) -and
    (Get-FileHash -Algorithm SHA256 -LiteralPath $declarationPath).
        Hash.ToLowerInvariant() -ceq $expectedDeclarationSha256
) "The Rapier v4 live-integration declaration changed"

$declaration = (
    Get-Content -Raw -LiteralPath $declarationPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$declaration.schema_version -ceq
        "sporespore_rapier_c6_velocity_only_live_integration_v1" -and
    [string]$declaration.status -ceq
        "implemented_and_zero_world_integrity_gated" -and
    [string]$declaration.selected_portable_composition.controller_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [double]$declaration.selected_portable_composition.
        global_requested_correction_scale -eq 0.5 -and
    [string]$declaration.actuation_contract.rapier_host_profile_id -ceq
        "rapier_force_based_velocity_only_v1" -and
    [string]$declaration.actuation_contract.motor_model -ceq "ForceBased" -and
    [double]$declaration.actuation_contract.
        native_position_stiffness_nm_per_rad -eq 0.0 -and
    [double]$declaration.actuation_contract.damping_nm_s_per_rad -eq 10.0 -and
    [int]$declaration.zero_world_gate.world_build_count -eq 0 -and
    [int]$declaration.zero_world_gate.scene_insertion_count -eq 0 -and
    -not [bool]$declaration.zero_world_gate.physics_state_modified -and
    -not [bool]$declaration.zero_world_gate.locomotion_outcome_exposed -and
    -not [bool]$declaration.zero_world_gate.physical_acceptance_authority
) "The Rapier v4 live-integration declaration contract changed"

Push-Location -LiteralPath $sdkRoot
try {
    $preflightLines = @(
        & cargo run `
            --quiet `
            --package sporespore-rapier-adapter `
            --bin velocity_only_live_integration_preflight `
            --offline
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "The Rapier v4 live-integration preflight failed"
} finally {
    Pop-Location
}

$preflight = (
    ($preflightLines -join [Environment]::NewLine) |
        ConvertFrom-Json -AsHashtable
)
$selectedReadbackFailures = @(
    $preflight.ordered_maximum_force_receipts |
        Where-Object {
            [string]$_.builder_readback.model -cne "ForceBased" -or
            [double]$_.builder_readback.stiffness_nm_per_rad -ne 0.0 -or
            [double]$_.builder_readback.damping_nm_s_per_rad -ne 10.0 -or
            [double]$_.builder_readback.maximum_force_nm -ne
                [double]$_.rapier_maximum_force_nm -or
            [string]$_.mutable_update_readback.model -cne "ForceBased" -or
            [double]$_.mutable_update_readback.stiffness_nm_per_rad -ne 0.0 -or
            [double]$_.mutable_update_readback.damping_nm_s_per_rad -ne 10.0 -or
            [double]$_.mutable_update_readback.maximum_force_nm -ne
                [double]$_.rapier_maximum_force_nm -or
            [double]$_.builder_readback.target_velocity_rad_s -ne
                [double]$_.host_target_velocity_rad_s -or
            [double]$_.mutable_update_readback.target_velocity_rad_s -ne
                [double]$_.host_target_velocity_rad_s
        }
)
Assert-Exact (
    [bool]$preflight.ok -and
    [bool]$preflight.vh1_positive_authority_valid -and
    [string]$preflight.selected_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [int]$preflight.selected_policy_branch_surface_count -eq 0 -and
    [double]$preflight.bw19v_global_requested_correction_scale -eq 0.5 -and
    [int]$preflight.synthetic_actuator_count -eq 8 -and
    [bool]$preflight.canonical_mapping_formula_passed -and
    [int]$preflight.native_position_target_count -eq 0 -and
    [int]$preflight.mixed_space_negative_witness_count -gt 0 -and
    [string]$preflight.default_model_canary.readback.model -ceq
        "AccelerationBased" -and
    [bool]$preflight.default_model_canary.passed -and
    [string]$preflight.explicit_builder_readback.model -ceq "ForceBased" -and
    [double]$preflight.explicit_builder_readback.stiffness_nm_per_rad -eq 0.0 -and
    [string]$preflight.mutable_update_readback.model -ceq "ForceBased" -and
    [double]$preflight.mutable_update_readback.stiffness_nm_per_rad -eq 0.0 -and
    [bool]$preflight.exact_force_mapping_passed -and
    [bool]$preflight.all_selected_actuator_builder_readbacks_passed -and
    [bool]$preflight.all_selected_actuator_mutable_readbacks_passed -and
    @($preflight.ordered_maximum_force_receipts).Count -eq 8 -and
    $selectedReadbackFailures.Count -eq 0 -and
    [bool]$preflight.reordered_residual_canary_rejected -and
    [bool]$preflight.missing_residual_canary_rejected -and
    [bool]$preflight.wrong_sign_profile_canary_rejected -and
    [bool]$preflight.wrong_model_canary_rejected -and
    [bool]$preflight.nonzero_stiffness_canary_rejected -and
    [bool]$preflight.wrong_target_velocity_canary_rejected -and
    [bool]$preflight.wrong_maximum_force_canary_rejected -and
    [bool]$preflight.serialization_round_trip_passed -and
    [bool]$preflight.world_and_authority_inflation_canary_rejected -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_insertion_count -eq 0 -and
    -not [bool]$preflight.physics_state_modified -and
    -not [bool]$preflight.locomotion_outcome_exposed -and
    -not [bool]$preflight.selected_policy_physical_authority -and
    -not [bool]$preflight.walking_acceptance -and
    -not [bool]$preflight.release_authorized -and
    -not [bool]$preflight.physical_acceptance_authority
) "The Rapier v4 live-integration preflight receipt is incomplete or inflated"

Write-Output (
    "C6_RAP_V4_LIVE_INTEGRATION_PREFLIGHT_PASS " +
    "policy=BW15F-B scale=0.5 actuators=8 mixed_space_witnesses=" +
    "$($preflight.mixed_space_negative_witness_count) worlds=0 " +
    "physical_authority=False"
)
