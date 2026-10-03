#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$regressionId = "BW31N-DYNAMIC-RECEIPT-PROJECTION-REGRESSION-DRP1"
$gateId = "DRP1"
$implementationParent = "924ab2cb989d34b2295315529280322bc95f869e"
$preregistrationPath = Join-Path $sdkRoot (
    "balanced_wave_dynamic_receipt_projection_drp1_preregistration.json"
)
$bw31nClosurePath = Join-Path $sdkRoot (
    "balanced_wave_bw31n_authority_horizon_closure.json"
)
$expectedPreregistrationSha256 = (
    "7356b162cfd75f55ab2f75436cf827c05815b6473d84ba0653f96c2433792626"
)
$expectedBw31nClosureSha256 = (
    "b92320e3122257829cebab3ae08c6dacc0aa2def055a649c1345e78b0a51e65f"
)

function Assert-Exact {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Read-JsonMap {
    param([Parameter(Mandatory)][string]$Path)
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Test-SequenceEqual {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Actual,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Expected
    )
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index += 1) {
        if ([string]$Actual[$index] -cne [string]$Expected[$index]) {
            return $false
        }
    }
    return $true
}

$currentHead = (git -C $repoRoot rev-parse HEAD).Trim()
git -C $repoRoot merge-base --is-ancestor $implementationParent $currentHead
$implementationParentIsAncestor = $LASTEXITCODE -eq 0
Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    $implementationParentIsAncestor
) "$gateId repository or implementation-parent ancestry changed"

Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Get-RawSha256 -Path $preregistrationPath) -ceq
        $expectedPreregistrationSha256 -and
    (Test-Path -LiteralPath $bw31nClosurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $bw31nClosurePath) -ceq $expectedBw31nClosureSha256
) "$gateId declaration or BW31N closure binding changed"

$declaration = Read-JsonMap -Path $preregistrationPath
$closure = Read-JsonMap -Path $bw31nClosurePath

Assert-Exact (
    [string]$declaration.schema_version -ceq
        "sporespore_balanced_wave_dynamic_receipt_projection_drp1_preregistration_v1" -and
    [string]$declaration.status -ceq
        "prospective_noncampaign_regression_stage_zero_zero_world_physics_implementation_blocked" -and
    [string]$declaration.regression_id -ceq $regressionId -and
    [string]$declaration.gate_id -ceq $gateId -and
    [string]$declaration.implementation_parent_commit -ceq $implementationParent -and
    [string]$closure.status -ceq
        "closed_implementation_invalid_after_complete_physical_matrix_and_frozen_evaluation" -and
    [string]$closure.campaign_id -ceq
        "BW31N-BW30N-AUTHORITY-HORIZON-RECOVERY-DEVELOPMENT" -and
    [string]$closure.gate_id -ceq "BW31N" -and
    [bool]$closure.immutability.physical_identity_consumed -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.successor_requirements.repeatable_noncampaign_regression_physics_must_exercise_the_long_horizon_parent_summary_projection_after_zero_world_gates -and
    [bool]$closure.successor_requirements.regression_fixture_must_use_noncampaign_identity_and_expose_no_selection_or_acceptance_outcome
) "$gateId predecessor closure or required successor mechanism changed"

Assert-Exact (
    [string]$declaration.predecessor_boundary.path -ceq
        "sdk/balanced_wave_bw31n_authority_horizon_closure.json" -and
    [string]$declaration.predecessor_boundary.raw_sha256 -ceq
        $expectedBw31nClosureSha256 -and
    [bool]$declaration.predecessor_boundary.bw31n_identity_remains_consumed -and
    [bool]$declaration.predecessor_boundary.bw31n_repair_reanalysis_or_rerun_forbidden -and
    [bool]$declaration.predecessor_boundary.bw31n_b_remains_unselected_and_unpromoted -and
    [bool]$declaration.predecessor_boundary.bw31n_raw_observations_inform_implementation_design_only
) "$gateId immutable predecessor boundary changed"

Assert-Exact (
    [bool]$declaration.classification.ordinary_repeatable_regression_test_physics -and
    -not [bool]$declaration.classification.scientific_campaign -and
    -not [bool]$declaration.classification.one_shot_identity -and
    -not [bool]$declaration.classification.finite_development_screen -and
    -not [bool]$declaration.classification.superiority_study -and
    -not [bool]$declaration.classification.noninferiority_or_equivalence_study -and
    -not [bool]$declaration.classification.population_study -and
    -not [bool]$declaration.classification.candidate_selection_permitted -and
    -not [bool]$declaration.classification.walking_or_nuisance_acceptance_permitted -and
    [bool]$declaration.classification.rerunnable_after_implementation_freeze -and
    -not [bool]$declaration.classification.new_scientific_outcome_consumed
) "$gateId noncampaign regression classification changed"

$expectedRoutes = @("DRP1-REFERENCE-ROUTE", "DRP1-SUCCESSOR-ROUTE")
$expectedProfiles = @(
    "bw6n_baseline_v1",
    "bw6n_rough_v1",
    "bw6n_push_v1",
    "bw6n_sensor_noise_v1"
)
$expectedRegressionSeeds = @(22001, 22002, 22003)
$reservedValidationSeeds = @(49101, 49102, 49103)
Assert-Exact (
    (Test-SequenceEqual `
        -Actual @($declaration.regression_matrix.route_order) `
        -Expected $expectedRoutes) -and
    (Test-SequenceEqual `
        -Actual @($declaration.regression_matrix.challenge_profile_order) `
        -Expected $expectedProfiles) -and
    (Test-SequenceEqual `
        -Actual @($declaration.regression_matrix.regression_seed_order) `
        -Expected $expectedRegressionSeeds) -and
    (Test-SequenceEqual `
        -Actual @($declaration.regression_matrix.fresh_validation_seed_ids_absent) `
        -Expected $reservedValidationSeeds) -and
    [int]$declaration.regression_matrix.expected_world_count -eq 24 -and
    [int]$declaration.regression_matrix.expected_world_count -eq
        ($expectedRoutes.Count * $expectedProfiles.Count * $expectedRegressionSeeds.Count) -and
    [bool]$declaration.regression_matrix.all_worlds_required_per_complete_regression_run -and
    [bool]$declaration.regression_matrix.partial_matrix_pass_forbidden -and
    [bool]$declaration.regression_matrix.walking_result_comparison_forbidden -and
    [bool]$declaration.regression_matrix.route_selection_forbidden -and
    @($expectedRegressionSeeds | Where-Object { $_ -in $reservedValidationSeeds }).Count -eq 0
) "$gateId complete matrix or seed separation changed"

$reference = $declaration.route_contracts["DRP1-REFERENCE-ROUTE"]
$successor = $declaration.route_contracts["DRP1-SUCCESSOR-ROUTE"]
Assert-Exact (
    [string]$reference.controller_policy_id -ceq
        "sporespore_balanced_wave_bw5r_b_v1" -and
    [string]$reference.controller_policy_digest -ceq
        "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f" -and
    [string]$reference.stability_policy_id -ceq
        "p5i3c_support_centroid_tilt_feedback_v1" -and
    [string]$reference.authority_scope -ceq "stability_contribution_overlay" -and
    [string]$reference.execution_mode -ceq
        "portable_balanced_wave_base_with_godot_host_stability_overlay" -and
    [int]$reference.expected_pre_authority_world_tick_count -eq 712 -and
    [string]$successor.controller_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [string]$successor.controller_policy_digest -ceq
        "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd" -and
    [string]$successor.stability_policy_id -ceq
        "sporespore_scheduled_load_transfer_bw13p_a_v3" -and
    [string]$successor.authority_scope -ceq "post_settle_full" -and
    [string]$successor.execution_mode -ceq
        "native_balanced_wave_base_with_stability_contribution" -and
    [int]$successor.expected_pre_authority_world_tick_count -eq 240
) "$gateId frozen route identity declarations changed"

Assert-Exact (
    [string]$declaration.environment_contract.adapter_id -ceq
        "godot_jolt_gdextension_v1" -and
    [string]$declaration.environment_contract.physics_engine -ceq "Jolt Physics" -and
    [int]$declaration.environment_contract.physics_hz -eq 120 -and
    [int]$declaration.environment_contract.solver_velocity_steps -eq 20 -and
    [int]$declaration.environment_contract.solver_position_steps -eq 7 -and
    [string]$declaration.environment_contract.material_profile_sha256 -ceq
        "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993" -and
    [string]$declaration.authority_horizon_contract.policy_id -ceq
        "fixed_candidate_authority_exposure_horizon_v1" -and
    [int]$declaration.authority_horizon_contract.first_candidate_authority_observation_index -eq 0 -and
    [int]$declaration.authority_horizon_contract.last_candidate_authority_observation_index -eq 3231 -and
    [int]$declaration.authority_horizon_contract.exact_candidate_authority_observation_count -eq 3232 -and
    [int]$declaration.authority_horizon_contract.expected_native_motor_write_count -eq 25856 -and
    [int]$declaration.authority_horizon_contract.candidate_specific_horizon_extension_count -eq 0 -and
    -not [bool]$declaration.authority_horizon_contract.pre_authority_world_ticks_count_toward_exposure -and
    [int]$declaration.authority_horizon_contract.sensor_noise_application_count_when_enabled -eq 3232 -and
    [int]$declaration.authority_horizon_contract.sensor_noise_base_and_stability_count_when_enabled -eq 3232
) "$gateId host or candidate-authority horizon changed"

$dynamicContract = $declaration.dynamic_receipt_contract
Assert-Exact (
    [bool]$dynamicContract.actual_world_and_real_parent_summary_required_for_every_receipt -and
    [bool]$dynamicContract.constructed_real_shaped_receipt_substitution_forbidden -and
    [bool]$dynamicContract.one_shared_final_receipt_composer_required_for_both_routes -and
    [bool]$dynamicContract.one_complete_regression_evaluator_required -and
    [bool]$dynamicContract.route_identity_fields_must_come_from_frozen_route_declarations_not_optional_parent_metadata -and
    [bool]$dynamicContract.challenge_gate_must_be_recomputed_from_direct_terrain_push_and_observation_fault_primitives -and
    [bool]$dynamicContract.application_gate_must_be_recomputed_from_3232_authority_step_and_25856_native_write_primitives -and
    [bool]$dynamicContract.outcome_completeness_must_be_derived_without_legacy_fixed_world_horizon_aggregate -and
    [bool]$dynamicContract.common_execution_integrity_must_be_recomputed_without_legacy_parent_campaign_boolean -and
    [bool]$dynamicContract.walking_boolean_may_be_true_or_false_when_integrity_and_outcome_completeness_pass -and
    [bool]$dynamicContract.walking_subreceipts_must_remain_structurally_complete -and
    [bool]$dynamicContract.worker_fail_closed_exit_must_not_prevent_receipt_parsing
) "$gateId dynamic projection mechanism contract changed"

$expectedGates = @(
    "exact_noncampaign_identity",
    "exact_matrix_cardinality_and_order",
    "shared_final_receipt_schema",
    "route_identity_projection",
    "candidate_authority_horizon",
    "pre_authority_exclusion",
    "challenge_realization",
    "measurement_acquisition",
    "candidate_application",
    "outcome_complete",
    "common_execution_integrity",
    "all_scientific_and_release_claims_false"
)
Assert-Exact (
    [int]$declaration.complete_regression_pass_rule.expected_gate_count -eq 12 -and
    (Test-SequenceEqual `
        -Actual @($declaration.complete_regression_pass_rule.required_gates) `
        -Expected $expectedGates) -and
    [bool]$declaration.complete_regression_pass_rule.all_12_gates_must_pass -and
    [bool]$declaration.complete_regression_pass_rule.all_24_dynamic_receipts_must_pass_route_integrity -and
    [bool]$declaration.complete_regression_pass_rule.walking_pass_count_is_not_an_evaluator_input -and
    [bool]$declaration.complete_regression_pass_rule.no_route_or_policy_is_selected
) "$gateId complete evaluator contract changed"

Assert-Exact (
    [string]$declaration.execution_stages.stage_0_declaration.status -ceq
        "complete_only_when_declaration_audit_passes" -and
    [int]$declaration.execution_stages.stage_0_declaration.world_build_count -eq 0 -and
    -not [bool]$declaration.execution_stages.stage_0_declaration.regression_physics_authorized -and
    [string]$declaration.execution_stages.stage_1_implementation_and_zero_world_gate.status -ceq
        "not_started" -and
    [int]$declaration.execution_stages.stage_1_implementation_and_zero_world_gate.world_build_count -eq 0 -and
    -not [bool]$declaration.execution_stages.stage_1_implementation_and_zero_world_gate.regression_physics_authorized -and
    [string]$declaration.execution_stages.stage_2_full_conformance_regression_physics.status -ceq
        "blocked_until_stage_1_clean_push" -and
    [bool]$declaration.execution_stages.stage_2_full_conformance_regression_physics.must_execute_inside_full_godot_conformance_under_global_conformance_lock -and
    [int]$declaration.execution_stages.stage_2_full_conformance_regression_physics.expected_world_count -eq 24 -and
    -not [bool]$declaration.execution_stages.stage_2_full_conformance_regression_physics.one_shot_campaign_identity_consumed -and
    -not [bool]$declaration.execution_stages.stage_2_full_conformance_regression_physics.scientific_evidence_retained -and
    [bool]$declaration.execution_stages.stage_2_full_conformance_regression_physics.scientific_outcome_interpretation_forbidden -and
    [string]$declaration.execution_stages.stage_3_distinct_development_campaign.status -ceq
        "blocked_until_a_complete_stage_2_pass_and_new_campaign_preregistration"
) "$gateId staged execution interlock changed"

Assert-Exact (
    @($declaration.claim_boundary.GetEnumerator() | Where-Object { [bool]$_.Value }).Count -eq 0 -and
    [int]$declaration.stage_zero_interlocks.world_build_count -eq 0 -and
    [int]$declaration.stage_zero_interlocks.physical_process_launch_count -eq 0 -and
    [bool]$declaration.stage_zero_interlocks.regression_physics_blocked -and
    [bool]$declaration.stage_zero_interlocks.one_shot_physics_blocked -and
    [bool]$declaration.stage_zero_interlocks.bw31n_artifact_rewrite_forbidden -and
    [bool]$declaration.stage_zero_interlocks.future_campaign_declaration_before_drp1_pass_forbidden -and
    [bool]$declaration.stage_zero_interlocks.fresh_validation_seed_use_forbidden -and
    [bool]$declaration.stage_zero_interlocks.broader_claim_promotion_forbidden
) "$gateId stage-zero claim boundary changed"

$priorAttemptFiles = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorAttemptFiles = @(
        Get-ChildItem -LiteralPath $evidenceRoot -Filter attempt.json -File -Recurse |
            Where-Object {
                try {
                    $attempt = Read-JsonMap -Path $_.FullName
                    [string]$attempt.regression_id -ceq $regressionId -or
                        [string]$attempt.campaign_id -ceq $regressionId
                } catch { $false }
            }
    )
}
Assert-Exact ($priorAttemptFiles.Count -eq 0) (
    "$gateId stage-zero declaration unexpectedly found a retained physical attempt"
)

Write-Host (
    "DRP1_DECLARATION_PASS routes=2 profiles=4 seeds=3 cells=24 " +
    "authority_horizon=3232 dynamic_parent_summary=True shared_composer=True " +
    "complete_evaluator=True regression_physics=False one_shot=False worlds=0 " +
    "selection_authority=False walking_authority=False physical_authority=False"
)
