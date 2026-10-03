#requires -Version 7.0

[CmdletBinding(DefaultParameterSetName = "Evaluate")]
param(
    [Parameter(Mandatory, ParameterSetName = "Evaluate")]
    [string]$InputPath,
    [Parameter(Mandatory, ParameterSetName = "Evaluate")]
    [string]$OutputPath,
    [Parameter(Mandatory, ParameterSetName = "SelfTest")]
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$regressionId = "BW31N-DYNAMIC-RECEIPT-PROJECTION-REGRESSION-DRP1"
$gateId = "DRP1"
$receiptSchema = "sporespore_balanced_wave_dynamic_receipt_projection_drp1_cell_v1"
$composerId = "drp1_dynamic_parent_summary_composer_v1"
$authorityPolicyId = "fixed_candidate_authority_exposure_horizon_v1"
$materialProfileId = "godot_jolt_bw5c_mu095_v1"
$materialProfileSha256 = (
    "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
)
$referenceRouteId = "DRP1-REFERENCE-ROUTE"
$successorRouteId = "DRP1-SUCCESSOR-ROUTE"
$routeIds = @($referenceRouteId, $successorRouteId)
$profileIds = @(
    "bw6n_baseline_v1",
    "bw6n_rough_v1",
    "bw6n_push_v1",
    "bw6n_sensor_noise_v1"
)
$profilePrefixes = [ordered]@{
    bw6n_baseline_v1 = "baseline"
    bw6n_rough_v1 = "rough"
    bw6n_push_v1 = "push"
    bw6n_sensor_noise_v1 = "sensor_noise"
}
$regressionSeeds = @(22001, 22002, 22003)
$commonWalkingReceiptKeys = @(
    "bounded_anchor_error",
    "bounded_hinge_axis_error",
    "bounded_joint_only_lateral_stride_steering",
    "bounded_lateral_drift",
    "bounded_tilt",
    "bounded_torso_height",
    "bounded_yaw_drift",
    "contact_gated_evidence_horizon_completed",
    "contact_gating_completed_without_timeout",
    "every_contact_observer_executed",
    "every_limb_completed_evidence_gait_horizon",
    "every_limb_forward_relocation",
    "every_limb_two_contact_cycles",
    "evidence_support_acquisition",
    "fixture_spec_compiled_before_world_creation",
    "initial_four_contact_stance",
    "initial_perturbation_within_declared_envelope",
    "minimum_evidence_forward_translation",
    "minimum_final_forward_translation",
    "no_torso_force_or_impulse_or_velocity_or_transform_command",
    "no_world_reset",
    "one_continuous_world",
    "pinned_jolt_solver_settings",
    "terminal_four_contact_recovery",
    "zero_torso_contact"
)
$routeWalkingActuationKeys = [ordered]@{
    $referenceRouteId = "sdk_stability_overlay_evidence_actuation"
    $successorRouteId = "native_sdk_exclusive_post_settle_actuation"
}
$receiptKeys = @(
    "schema_version",
    "final_receipt_composer_id",
    "shared_receipt_composer_passed",
    "regression_id",
    "gate_id",
    "cell_id",
    "route_id",
    "regression_seed",
    "challenge_profile_id",
    "controller_policy_id",
    "controller_policy_digest",
    "stability_policy_id",
    "authority_scope",
    "execution_mode",
    "material_profile_id",
    "material_profile_sha256",
    "authority_horizon_policy_id",
    "candidate_authority_observation_count",
    "first_candidate_authority_observation_index",
    "last_candidate_authority_observation_index",
    "pre_authority_world_tick_count",
    "candidate_specific_horizon_extension_count",
    "challenge_configuration_sha256",
    "terrain_shape_count",
    "external_push_application_count",
    "observation_fault_application_count",
    "observation_fault_base_and_stability_count",
    "maximum_observation_fault_component",
    "world_build_count",
    "world_reset_count",
    "physics_engine",
    "physics_hz",
    "solver_velocity_steps",
    "solver_position_steps",
    "physical_influence",
    "walking_observed",
    "walking_gate_receipts",
    "route_identity_gate_passed",
    "candidate_authority_horizon_gate_passed",
    "pre_authority_exclusion_gate_passed",
    "challenge_gate_passed",
    "measurement_gate_passed",
    "application_gate_passed",
    "outcome_complete",
    "engine_integrity_gate_passed",
    "common_execution_integrity",
    "route_integrity_passed",
    "development_only",
    "candidate_or_policy_selection_authorized",
    "walking_claim_authorized",
    "nuisance_acceptance_claim_authorized",
    "turning_claim_authorized",
    "self_righting_claim_authorized",
    "arbitrary_morphology_claim_authorized",
    "cross_engine_equivalence_claim_authorized",
    "release_authorized",
    "completed_engine_neutral_sdk",
    "physical_acceptance_authority"
)
$claimKeys = @(
    "candidate_or_policy_selection_authorized",
    "walking_claim_authorized",
    "nuisance_acceptance_claim_authorized",
    "turning_claim_authorized",
    "self_righting_claim_authorized",
    "arbitrary_morphology_claim_authorized",
    "cross_engine_equivalence_claim_authorized",
    "release_authorized",
    "completed_engine_neutral_sdk",
    "physical_acceptance_authority"
)
$routeContracts = [ordered]@{
    $referenceRouteId = [ordered]@{
        controller_policy_id = "sporespore_balanced_wave_bw5r_b_v1"
        controller_policy_digest = (
            "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
        )
        stability_policy_id = "p5i3c_support_centroid_tilt_feedback_v1"
        authority_scope = "stability_contribution_overlay"
        execution_mode = (
            "portable_balanced_wave_base_with_godot_host_stability_overlay"
        )
        pre_authority_world_tick_count = 712
    }
    $successorRouteId = [ordered]@{
        controller_policy_id = "sporespore_balanced_wave_bw15f_b_v1"
        controller_policy_digest = (
            "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
        )
        stability_policy_id = "sporespore_scheduled_load_transfer_bw13p_a_v3"
        authority_scope = "post_settle_full"
        execution_mode = "native_balanced_wave_base_with_stability_contribution"
        pre_authority_world_tick_count = 240
    }
}

function Assert-Drp1 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Test-ExactKeys {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Map,
        [Parameter(Mandatory)][string[]]$Expected
    )
    $actual = @($Map.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $wanted = @($Expected | Sort-Object)
    return (
        $actual.Count -eq $wanted.Count -and
        @(Compare-Object -CaseSensitive $actual $wanted).Count -eq 0
    )
}

function Copy-Drp1Value {
    param([Parameter(Mandatory)][object]$Value)
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Drp1OrderedCells {
    $cells = [System.Collections.Generic.List[object]]::new()
    foreach ($profileId in $profileIds) {
        foreach ($seed in $regressionSeeds) {
            foreach ($routeId in $routeIds) {
                $suffix = if ($routeId -ceq $referenceRouteId) {
                    "reference"
                } else {
                    "successor"
                }
                $cells.Add([ordered]@{
                    cell_id = "$($profilePrefixes[$profileId])_s${seed}_drp1_$suffix"
                    route_id = $routeId
                    regression_seed = $seed
                    challenge_profile_id = $profileId
                })
            }
        }
    }
    return @($cells)
}

function Get-Drp1WalkingReceiptKeys {
    param([Parameter(Mandatory)][string]$ReceiptRouteId)
    if (-not $routeWalkingActuationKeys.Contains($ReceiptRouteId)) { return @() }
    return @(
        $commonWalkingReceiptKeys +
            @([string]$routeWalkingActuationKeys[$ReceiptRouteId])
    )
}

function Test-Drp1WalkingReceipt {
    param(
        [object]$Value,
        [Parameter(Mandatory)][string]$ReceiptRouteId
    )
    if ($Value -isnot [System.Collections.IDictionary]) { return $false }
    $expectedKeys = @(Get-Drp1WalkingReceiptKeys -ReceiptRouteId $ReceiptRouteId)
    if (
        $expectedKeys.Count -ne 26 -or
        -not (Test-ExactKeys -Map $Value -Expected $expectedKeys)
    ) {
        return $false
    }
    foreach ($key in $expectedKeys) {
        if ($Value[$key] -isnot [bool]) { return $false }
    }
    return $true
}

function Test-Drp1RouteIdentity {
    param([System.Collections.IDictionary]$Receipt)
    $routeId = [string]$Receipt.route_id
    if (-not $routeContracts.Contains($routeId)) { return $false }
    $route = $routeContracts[$routeId]
    return (
        [string]$Receipt.controller_policy_id -ceq
            [string]$route.controller_policy_id -and
        [string]$Receipt.controller_policy_digest -ceq
            [string]$route.controller_policy_digest -and
        [string]$Receipt.stability_policy_id -ceq
            [string]$route.stability_policy_id -and
        [string]$Receipt.authority_scope -ceq
            [string]$route.authority_scope -and
        [string]$Receipt.execution_mode -ceq
            [string]$route.execution_mode -and
        [bool]$Receipt.route_identity_gate_passed
    )
}

function Test-Drp1Challenge {
    param([System.Collections.IDictionary]$Receipt)
    if (-not [bool]$Receipt.challenge_gate_passed) { return $false }
    if (
        -not ([string]$Receipt.challenge_configuration_sha256).
            StartsWith("sha256:", [StringComparison]::Ordinal)
    ) { return $false }
    switch ([string]$Receipt.challenge_profile_id) {
        "bw6n_baseline_v1" {
            return (
                [int]$Receipt.terrain_shape_count -eq 1 -and
                [int]$Receipt.external_push_application_count -eq 0 -and
                [int]$Receipt.observation_fault_application_count -eq 0 -and
                [int]$Receipt.observation_fault_base_and_stability_count -eq 0
            )
        }
        "bw6n_rough_v1" {
            return (
                [int]$Receipt.terrain_shape_count -eq 64 -and
                [int]$Receipt.external_push_application_count -eq 0 -and
                [int]$Receipt.observation_fault_application_count -eq 0 -and
                [int]$Receipt.observation_fault_base_and_stability_count -eq 0
            )
        }
        "bw6n_push_v1" {
            return (
                [int]$Receipt.terrain_shape_count -eq 1 -and
                [int]$Receipt.external_push_application_count -eq 1 -and
                [int]$Receipt.observation_fault_application_count -eq 0 -and
                [int]$Receipt.observation_fault_base_and_stability_count -eq 0
            )
        }
        "bw6n_sensor_noise_v1" {
            return (
                [int]$Receipt.terrain_shape_count -eq 1 -and
                [int]$Receipt.external_push_application_count -eq 0 -and
                [int]$Receipt.observation_fault_application_count -eq 3232 -and
                [int]$Receipt.observation_fault_base_and_stability_count -eq 3232 -and
                [double]$Receipt.maximum_observation_fault_component -gt 0.0
            )
        }
    }
    return $false
}

function Invoke-Drp1Evaluation {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$EvaluationInput
    )

    $expectedInputKeys = @(
        "schema_version",
        "regression_id",
        "gate_id",
        "test_fixture_only",
        "complete_matrix_execution_requested",
        "receipts",
        "worker_exit_codes",
        "world_build_count",
        "scientific_evidence_retained",
        "one_shot_identity_consumed",
        "candidate_or_policy_selection_authorized",
        "walking_claim_authorized",
        "nuisance_acceptance_claim_authorized",
        "release_authorized",
        "physical_acceptance_authority"
    )
    $inputExact = Test-ExactKeys -Map $EvaluationInput -Expected $expectedInputKeys
    $receipts = @($EvaluationInput.receipts)
    $exitCodes = @($EvaluationInput.worker_exit_codes)
    $expectedCells = @(Get-Drp1OrderedCells)
    $receiptMaps = @(
        $receipts |
            Where-Object { $_ -is [System.Collections.IDictionary] }
    )
    $allReceiptsAreMaps = $receiptMaps.Count -eq $receipts.Count

    $identityPassed = (
        $inputExact -and
        [string]$EvaluationInput.schema_version -ceq "sporespore_drp1_regression_input_v1" -and
        [string]$EvaluationInput.regression_id -ceq $regressionId -and
        [string]$EvaluationInput.gate_id -ceq $gateId -and
        [bool]$EvaluationInput.complete_matrix_execution_requested
    )
    foreach ($receipt in $receipts) {
        $identityPassed = (
            $identityPassed -and
            $receipt -is [System.Collections.IDictionary] -and
            [string]$receipt.regression_id -ceq $regressionId -and
            [string]$receipt.gate_id -ceq $gateId -and
            [bool]$receipt.development_only
        )
    }

    $matrixPassed = (
        $allReceiptsAreMaps -and
        $receipts.Count -eq 24 -and
        $exitCodes.Count -eq 24 -and
        (
            ([bool]$EvaluationInput.test_fixture_only -and [int]$EvaluationInput.world_build_count -eq 0) -or
            (-not [bool]$EvaluationInput.test_fixture_only -and [int]$EvaluationInput.world_build_count -eq 24)
        )
    )
    if ($matrixPassed) {
        for ($index = 0; $index -lt 24; $index++) {
            $actual = $receipts[$index]
            $expected = $expectedCells[$index]
            $matrixPassed = (
                $matrixPassed -and
                [string]$actual.cell_id -ceq [string]$expected.cell_id -and
                [string]$actual.route_id -ceq [string]$expected.route_id -and
                [int]$actual.regression_seed -eq [int]$expected.regression_seed -and
                [string]$actual.challenge_profile_id -ceq
                    [string]$expected.challenge_profile_id
            )
        }
    }

    $schemaPassed = $receipts.Count -eq 24
    foreach ($receipt in $receipts) {
        if ($receipt -isnot [System.Collections.IDictionary]) {
            $schemaPassed = $false
            continue
        }
        $schemaPassed = (
            $schemaPassed -and
            (Test-ExactKeys -Map $receipt -Expected $receiptKeys) -and
            [string]$receipt.schema_version -ceq $receiptSchema -and
            [string]$receipt.final_receipt_composer_id -ceq $composerId -and
            [bool]$receipt.shared_receipt_composer_passed -and
            (Test-Drp1WalkingReceipt `
                -Value $receipt.walking_gate_receipts `
                -ReceiptRouteId ([string]$receipt.route_id))
        )
    }

    $routeIdentityPassed = $receipts.Count -eq 24
    $horizonPassed = $receipts.Count -eq 24
    $preAuthorityPassed = $receipts.Count -eq 24
    $challengePassed = $receipts.Count -eq 24
    $measurementPassed = $receipts.Count -eq 24
    $applicationPassed = $receipts.Count -eq 24
    $outcomePassed = $receipts.Count -eq 24
    $commonIntegrityPassed = $receipts.Count -eq 24
    $claimsPassed = (
        -not [bool]$EvaluationInput.scientific_evidence_retained -and
        -not [bool]$EvaluationInput.one_shot_identity_consumed -and
        -not [bool]$EvaluationInput.candidate_or_policy_selection_authorized -and
        -not [bool]$EvaluationInput.walking_claim_authorized -and
        -not [bool]$EvaluationInput.nuisance_acceptance_claim_authorized -and
        -not [bool]$EvaluationInput.release_authorized -and
        -not [bool]$EvaluationInput.physical_acceptance_authority
    )
    foreach ($receipt in $receipts) {
        if ($receipt -isnot [System.Collections.IDictionary]) {
            $routeIdentityPassed = $false
            $horizonPassed = $false
            $preAuthorityPassed = $false
            $challengePassed = $false
            $measurementPassed = $false
            $applicationPassed = $false
            $outcomePassed = $false
            $commonIntegrityPassed = $false
            $claimsPassed = $false
            continue
        }
        $routeIdentityPassed = (
            $routeIdentityPassed -and (Test-Drp1RouteIdentity -Receipt $receipt)
        )
        $horizonPassed = (
            $horizonPassed -and
            [string]$receipt.authority_horizon_policy_id -ceq $authorityPolicyId -and
            [int]$receipt.candidate_authority_observation_count -eq 3232 -and
            [int]$receipt.first_candidate_authority_observation_index -eq 0 -and
            [int]$receipt.last_candidate_authority_observation_index -eq 3231 -and
            [int]$receipt.candidate_specific_horizon_extension_count -eq 0 -and
            [bool]$receipt.candidate_authority_horizon_gate_passed
        )
        $route = $routeContracts[[string]$receipt.route_id]
        $preAuthorityPassed = (
            $preAuthorityPassed -and
            $null -ne $route -and
            [int]$receipt.pre_authority_world_tick_count -eq
                [int]$route.pre_authority_world_tick_count -and
            [bool]$receipt.pre_authority_exclusion_gate_passed
        )
        $challengePassed = (
            $challengePassed -and (Test-Drp1Challenge -Receipt $receipt)
        )
        $measurementPassed = (
            $measurementPassed -and [bool]$receipt.measurement_gate_passed
        )
        $applicationPassed = (
            $applicationPassed -and
            [bool]$receipt.application_gate_passed -and
            [bool]$receipt.physical_influence
        )
        $outcomePassed = (
            $outcomePassed -and
            [bool]$receipt.outcome_complete -and
            (Test-Drp1WalkingReceipt `
                -Value $receipt.walking_gate_receipts `
                -ReceiptRouteId ([string]$receipt.route_id))
        )
        $commonIntegrityPassed = (
            $commonIntegrityPassed -and
            [bool]$receipt.engine_integrity_gate_passed -and
            [bool]$receipt.common_execution_integrity -and
            [bool]$receipt.route_integrity_passed -and
            [int]$receipt.world_build_count -eq 1 -and
            [int]$receipt.world_reset_count -eq 0 -and
            [string]$receipt.physics_engine -ceq "Jolt Physics" -and
            [int]$receipt.physics_hz -eq 120 -and
            [int]$receipt.solver_velocity_steps -eq 20 -and
            [int]$receipt.solver_position_steps -eq 7 -and
            [string]$receipt.material_profile_id -ceq $materialProfileId -and
            [string]$receipt.material_profile_sha256 -ceq $materialProfileSha256
        )
        foreach ($claimKey in $claimKeys) {
            $claimsPassed = $claimsPassed -and -not [bool]$receipt[$claimKey]
        }
    }
    foreach ($exitCode in $exitCodes) {
        $commonIntegrityPassed = $commonIntegrityPassed -and [int]$exitCode -eq 0
    }

    # The two routes in each profile/seed pair must bind the same compiled
    # challenge, and every seed under one profile must bind the same digest.
    if ($challengePassed) {
        foreach ($profileId in $profileIds) {
            $digests = @(
                $receipts |
                    Where-Object { [string]$_.challenge_profile_id -ceq $profileId } |
                    ForEach-Object { [string]$_.challenge_configuration_sha256 } |
                    Sort-Object -Unique
            )
            $challengePassed = $challengePassed -and $digests.Count -eq 1
        }
    }

    $gates = @(
        [ordered]@{ gate_id = "exact_noncampaign_identity"; passed = $identityPassed },
        [ordered]@{ gate_id = "exact_matrix_cardinality_and_order"; passed = $matrixPassed },
        [ordered]@{ gate_id = "shared_final_receipt_schema"; passed = $schemaPassed },
        [ordered]@{ gate_id = "route_identity_projection"; passed = $routeIdentityPassed },
        [ordered]@{ gate_id = "candidate_authority_horizon"; passed = $horizonPassed },
        [ordered]@{ gate_id = "pre_authority_exclusion"; passed = $preAuthorityPassed },
        [ordered]@{ gate_id = "challenge_realization"; passed = $challengePassed },
        [ordered]@{ gate_id = "measurement_acquisition"; passed = $measurementPassed },
        [ordered]@{ gate_id = "candidate_application"; passed = $applicationPassed },
        [ordered]@{ gate_id = "outcome_complete"; passed = $outcomePassed },
        [ordered]@{ gate_id = "common_execution_integrity"; passed = $commonIntegrityPassed },
        [ordered]@{ gate_id = "all_scientific_and_release_claims_false"; passed = $claimsPassed }
    )
    $failed = @($gates | Where-Object { -not [bool]$_.passed })
    $walkingCount = @(
        $receiptMaps | Where-Object { [bool]$_.walking_observed }
    ).Count
    $allPassed = $failed.Count -eq 0
    return [ordered]@{
        schema_version = "sporespore_drp1_regression_evaluation_v1"
        ok = $allPassed
        status = if ($allPassed) { "pass" } else { "invalid" }
        regression_id = $regressionId
        gate_id = $gateId
        test_fixture_only = [bool]$EvaluationInput.test_fixture_only
        expected_gate_count = 12
        passed_gate_count = 12 - $failed.Count
        failed_gate_count = $failed.Count
        failed_gate_ids = @($failed | ForEach-Object { [string]$_.gate_id })
        gates = $gates
        receipt_count = $receipts.Count
        worker_exit_code_count = $exitCodes.Count
        world_build_count = [int]$EvaluationInput.world_build_count
        walking_observed_count_descriptive_only = $walkingCount
        walking_count_used_by_evaluator = $false
        complete_regression_passed = (
            $allPassed -and
            -not [bool]$EvaluationInput.test_fixture_only -and
            [int]$EvaluationInput.world_build_count -eq 24
        )
        candidate_or_policy_selection_authorized = $false
        walking_claim_authorized = $false
        nuisance_acceptance_claim_authorized = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
}

function New-Drp1PerfectInput {
    $receipts = [System.Collections.Generic.List[object]]::new()
    $profileIndex = 0
    foreach ($cell in Get-Drp1OrderedCells) {
        $route = $routeContracts[[string]$cell.route_id]
        $walking = [ordered]@{}
        foreach ($key in Get-Drp1WalkingReceiptKeys -ReceiptRouteId ([string]$cell.route_id)) {
            $walking[$key] = $true
        }
        $profileId = [string]$cell.challenge_profile_id
        $terrainCount = if ($profileId -ceq "bw6n_rough_v1") { 64 } else { 1 }
        $pushCount = if ($profileId -ceq "bw6n_push_v1") { 1 } else { 0 }
        $noiseCount = if ($profileId -ceq "bw6n_sensor_noise_v1") { 3232 } else { 0 }
        $profileIndex = [Array]::IndexOf($profileIds, $profileId) + 1
        $receipt = [ordered]@{
            schema_version = $receiptSchema
            final_receipt_composer_id = $composerId
            shared_receipt_composer_passed = $true
            regression_id = $regressionId
            gate_id = $gateId
            cell_id = [string]$cell.cell_id
            route_id = [string]$cell.route_id
            regression_seed = [int]$cell.regression_seed
            challenge_profile_id = $profileId
            controller_policy_id = [string]$route.controller_policy_id
            controller_policy_digest = [string]$route.controller_policy_digest
            stability_policy_id = [string]$route.stability_policy_id
            authority_scope = [string]$route.authority_scope
            execution_mode = [string]$route.execution_mode
            material_profile_id = $materialProfileId
            material_profile_sha256 = $materialProfileSha256
            authority_horizon_policy_id = $authorityPolicyId
            candidate_authority_observation_count = 3232
            first_candidate_authority_observation_index = 0
            last_candidate_authority_observation_index = 3231
            pre_authority_world_tick_count = [int]$route.pre_authority_world_tick_count
            candidate_specific_horizon_extension_count = 0
            challenge_configuration_sha256 = "sha256:$(([string]$profileIndex) * 64)"
            terrain_shape_count = $terrainCount
            external_push_application_count = $pushCount
            observation_fault_application_count = $noiseCount
            observation_fault_base_and_stability_count = $noiseCount
            maximum_observation_fault_component = if ($noiseCount -gt 0) { 0.02 } else { 0.0 }
            world_build_count = 1
            world_reset_count = 0
            physics_engine = "Jolt Physics"
            physics_hz = 120
            solver_velocity_steps = 20
            solver_position_steps = 7
            physical_influence = $true
            walking_observed = $true
            walking_gate_receipts = $walking
            route_identity_gate_passed = $true
            candidate_authority_horizon_gate_passed = $true
            pre_authority_exclusion_gate_passed = $true
            challenge_gate_passed = $true
            measurement_gate_passed = $true
            application_gate_passed = $true
            outcome_complete = $true
            engine_integrity_gate_passed = $true
            common_execution_integrity = $true
            route_integrity_passed = $true
            development_only = $true
            candidate_or_policy_selection_authorized = $false
            walking_claim_authorized = $false
            nuisance_acceptance_claim_authorized = $false
            turning_claim_authorized = $false
            self_righting_claim_authorized = $false
            arbitrary_morphology_claim_authorized = $false
            cross_engine_equivalence_claim_authorized = $false
            release_authorized = $false
            completed_engine_neutral_sdk = $false
            physical_acceptance_authority = $false
        }
        $receipts.Add($receipt)
    }
    return [ordered]@{
        schema_version = "sporespore_drp1_regression_input_v1"
        regression_id = $regressionId
        gate_id = $gateId
        test_fixture_only = $true
        complete_matrix_execution_requested = $true
        receipts = @($receipts)
        worker_exit_codes = @(0..23 | ForEach-Object { 0 })
        world_build_count = 0
        scientific_evidence_retained = $false
        one_shot_identity_consumed = $false
        candidate_or_policy_selection_authorized = $false
        walking_claim_authorized = $false
        nuisance_acceptance_claim_authorized = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
}

function Invoke-Drp1SelfTest {
    $perfect = New-Drp1PerfectInput
    $perfectEvaluation = Invoke-Drp1Evaluation -EvaluationInput $perfect
    Assert-Drp1 (
        [bool]$perfectEvaluation.ok -and
        [int]$perfectEvaluation.passed_gate_count -eq 12 -and
        -not [bool]$perfectEvaluation.complete_regression_passed -and
        -not [bool]$perfectEvaluation.physical_acceptance_authority
    ) "DRP1 perfect evaluator fixture failed"

    $canaries = @(
        @{ gate = "exact_noncampaign_identity"; mutate = { param($x) $x.receipts[0].regression_id = "WRONG" } },
        @{ gate = "exact_matrix_cardinality_and_order"; mutate = { param($x) $x.receipts = @($x.receipts | Select-Object -SkipLast 1) } },
        @{ gate = "shared_final_receipt_schema"; mutate = { param($x) $x.receipts[0].unexpected = $true } },
        @{ gate = "route_identity_projection"; mutate = { param($x) $x.receipts[0].controller_policy_id = "" } },
        @{ gate = "candidate_authority_horizon"; mutate = { param($x) $x.receipts[0].candidate_authority_observation_count = 3231 } },
        @{ gate = "pre_authority_exclusion"; mutate = { param($x) $x.receipts[0].pre_authority_world_tick_count = 711 } },
        @{ gate = "challenge_realization"; mutate = { param($x) $x.receipts[0].challenge_gate_passed = $false } },
        @{ gate = "measurement_acquisition"; mutate = { param($x) $x.receipts[0].measurement_gate_passed = $false } },
        @{ gate = "candidate_application"; mutate = { param($x) $x.receipts[0].application_gate_passed = $false } },
        @{ gate = "outcome_complete"; mutate = { param($x) $x.receipts[0].outcome_complete = $false } },
        @{ gate = "common_execution_integrity"; mutate = { param($x) $x.receipts[0].common_execution_integrity = $false } },
        @{ gate = "all_scientific_and_release_claims_false"; mutate = { param($x) $x.receipts[0].walking_claim_authorized = $true } }
    )
    foreach ($canary in $canaries) {
        $caseInput = Copy-Drp1Value -Value $perfect
        & $canary.mutate $caseInput
        $evaluation = Invoke-Drp1Evaluation -EvaluationInput $caseInput
        Assert-Drp1 (
            -not [bool]$evaluation.ok -and
            [string]$canary.gate -cin @($evaluation.failed_gate_ids)
        ) "DRP1 evaluator did not reject canary for $($canary.gate)"
    }

    $malformedReceipt = Copy-Drp1Value -Value $perfect
    $malformedReceipt.receipts[0] = "not-a-receipt-map"
    $malformedEvaluation = Invoke-Drp1Evaluation -EvaluationInput $malformedReceipt
    Assert-Drp1 (
        -not [bool]$malformedEvaluation.ok -and
        "exact_matrix_cardinality_and_order" -cin @($malformedEvaluation.failed_gate_ids) -and
        "shared_final_receipt_schema" -cin @($malformedEvaluation.failed_gate_ids)
    ) "DRP1 malformed receipt did not fail closed"

    $crossRouteSchemaCanaries = 0
    foreach ($receiptIndex in @(0, 1)) {
        $crossRouteSchema = Copy-Drp1Value -Value $perfect
        $receipt = $crossRouteSchema.receipts[$receiptIndex]
        $routeId = [string]$receipt.route_id
        $otherRouteId = if ($routeId -ceq $referenceRouteId) {
            $successorRouteId
        } else {
            $referenceRouteId
        }
        $receipt.walking_gate_receipts.Remove(
            [string]$routeWalkingActuationKeys[$routeId]
        )
        $receipt.walking_gate_receipts[
            [string]$routeWalkingActuationKeys[$otherRouteId]
        ] = $true
        $crossRouteEvaluation = Invoke-Drp1Evaluation -EvaluationInput $crossRouteSchema
        Assert-Drp1 (
            -not [bool]$crossRouteEvaluation.ok -and
            "shared_final_receipt_schema" -cin @($crossRouteEvaluation.failed_gate_ids) -and
            "outcome_complete" -cin @($crossRouteEvaluation.failed_gate_ids)
        ) "DRP1 cross-route nested walking schema was not rejected"
        $crossRouteSchemaCanaries++
    }

    $walkingNegative = Copy-Drp1Value -Value $perfect
    $walkingNegative.receipts[0].walking_observed = $false
    $walkingNegative.receipts[0].walking_gate_receipts.minimum_final_forward_translation = $false
    $walkingNegativeEvaluation = Invoke-Drp1Evaluation -EvaluationInput $walkingNegative
    Assert-Drp1 (
        [bool]$walkingNegativeEvaluation.ok -and
        [int]$walkingNegativeEvaluation.walking_observed_count_descriptive_only -eq 23 -and
        -not [bool]$walkingNegativeEvaluation.walking_count_used_by_evaluator
    ) "DRP1 structurally complete walking-negative receipt was not accepted"

    Write-Host (
        "DRP1_EVALUATOR_SELF_TEST_PASS gates=12 canaries=12 " +
        "malformed_receipt_canary=True cross_route_schema_canaries=$crossRouteSchemaCanaries " +
        "walking_negative_complete=True test_worlds=0 " +
        "selection_authority=False " +
        "walking_authority=False physical_authority=False"
    )
}

if ($SelfTest.IsPresent) {
    Invoke-Drp1SelfTest
    exit 0
}

$resolvedInput = [IO.Path]::GetFullPath($InputPath)
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
Assert-Drp1 (
    (Test-Path -LiteralPath $resolvedInput -PathType Leaf) -and
    -not (Test-Path -LiteralPath $resolvedOutput)
) "DRP1 evaluator input must exist and output must not already exist"
$evaluationInput = Get-Content -Raw -LiteralPath $resolvedInput |
    ConvertFrom-Json -AsHashtable -Depth 100
$evaluation = Invoke-Drp1Evaluation -EvaluationInput $evaluationInput
$json = ($evaluation | ConvertTo-Json -Depth 100) + [Environment]::NewLine
[IO.File]::WriteAllText(
    $resolvedOutput,
    $json,
    [Text.UTF8Encoding]::new($false)
)
Write-Output ($evaluation | ConvertTo-Json -Depth 100)
if ([bool]$evaluation.complete_regression_passed) {
    exit 0
}
exit 1
