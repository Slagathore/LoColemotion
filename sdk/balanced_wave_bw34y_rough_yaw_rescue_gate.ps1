[CmdletBinding()]
param(
    [string]$InputPath = "",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Read-Bw34yJsonMap {
    param([Parameter(Mandatory)][string]$Path)
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 64
}

function Get-Bw34yFinalReceiptKeys {
    return @(
        "schema_version", "final_receipt_composer_id", "shared_receipt_composer_passed",
        "campaign_id", "gate_id", "route_id", "dynamic_parent_summary_gate_passed",
        "cell_id", "cohort", "role", "campaign_seed", "challenge_profile_id",
        "candidate_id", "candidate_composition_digest", "controller_policy_id",
        "controller_runtime_profile_sha256", "yaw_error_stride_gain_per_rad",
        "global_requested_correction_scale", "treatment_factor_count",
        "selection_eligible", "policy_branch_surface_count", "stability_policy_id",
        "authority_scope", "execution_mode", "material_profile_id",
        "material_profile_sha256", "measurement_policy_id", "measurement_policy_digest",
        "authority_horizon_policy_id", "authority_horizon_policy_sha256",
        "candidate_authority_observation_count", "first_candidate_authority_observation_index",
        "last_candidate_authority_observation_index", "pre_authority_world_tick_count",
        "candidate_specific_horizon_extension_count", "challenge_configuration_sha256",
        "identity_profile_scale_gate_passed", "measurement_gate_passed", "material_gate_passed",
        "challenge_gate_passed", "application_gate_passed", "mechanism_gate_passed",
        "common_execution_integrity", "outcome_complete", "failure_code",
        "walking_observed", "walking_gate_receipts", "failed_walking_gate_count",
        "world_build_count", "world_reset_count", "physics_engine", "physics_hz",
        "solver_velocity_steps", "solver_position_steps", "terrain_shape_count",
        "external_push_application_count", "observation_fault_application_count",
        "observation_fault_base_and_stability_count", "maximum_observation_fault_component",
        "physical_influence", "role_gate_passed", "development_only",
        "walking_claim_authorized", "nuisance_acceptance_claim_authorized",
        "rough_terrain_acceptance", "release_authorized", "physical_acceptance_authority"
    )
}

function Get-Bw34yWalkingReceiptKeys {
    return @(
        "bounded_anchor_error", "bounded_hinge_axis_error",
        "bounded_joint_only_lateral_stride_steering", "bounded_lateral_drift",
        "bounded_tilt", "bounded_torso_height", "bounded_yaw_drift",
        "contact_gated_evidence_horizon_completed",
        "contact_gating_completed_without_timeout", "every_contact_observer_executed",
        "every_limb_completed_evidence_gait_horizon", "every_limb_forward_relocation",
        "every_limb_two_contact_cycles", "evidence_support_acquisition",
        "fixture_spec_compiled_before_world_creation", "initial_four_contact_stance",
        "initial_perturbation_within_declared_envelope",
        "minimum_evidence_forward_translation", "minimum_final_forward_translation",
        "no_torso_force_or_impulse_or_velocity_or_transform_command", "no_world_reset",
        "one_continuous_world", "pinned_jolt_solver_settings",
        "terminal_four_contact_recovery", "zero_torso_contact",
        "native_sdk_exclusive_post_settle_actuation"
    )
}

function Get-Bw34yAuthorities {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $manifest = Read-Bw34yJsonMap (
        Join-Path $repoRoot "sdk\balanced_wave_bw34y_rough_yaw_rescue_manifest.json"
    )
    $candidates = Read-Bw34yJsonMap (
        Join-Path $repoRoot "sdk\balanced_wave_bw34y_rough_yaw_rescue_candidates.json"
    )
    $bindings = Read-Bw34yJsonMap (
        Join-Path $repoRoot "sdk\balanced_wave_bw34y_native_candidate_bindings.json"
    )
    $candidateById = @{}
    foreach ($candidate in @($candidates.candidates)) {
        $candidateById[[string]$candidate.candidate_id] = $candidate
    }
    $bindingById = @{}
    foreach ($binding in @($bindings.candidate_bindings)) {
        $bindingById[[string]$binding.candidate_id] = $binding
    }
    return [ordered]@{
        cells = @($manifest.ordered_cells)
        candidates = $candidateById
        bindings = $bindingById
    }
}

function Test-Bw34ySequenceEqual {
    param([object[]]$Actual, [object[]]$Expected)
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Actual.Count; $index += 1) {
        if ([string]$Actual[$index] -cne [string]$Expected[$index]) { return $false }
    }
    return $true
}

function Test-Bw34yCellReceipt {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Receipt,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ExpectedCell,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Candidate,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Binding
    )
    $actualKeys = @($Receipt.Keys | Sort-Object)
    $expectedKeys = @(Get-Bw34yFinalReceiptKeys | Sort-Object)
    $receiptKeysExact = Test-Bw34ySequenceEqual $actualKeys $expectedKeys
    $walking = [System.Collections.IDictionary]$Receipt.walking_gate_receipts
    $walkingKeys = @($walking.Keys | Sort-Object)
    $expectedWalkingKeys = @(Get-Bw34yWalkingReceiptKeys | Sort-Object)
    $walkingKeysExact = Test-Bw34ySequenceEqual $walkingKeys $expectedWalkingKeys
    $failedWalking = @($expectedWalkingKeys | Where-Object { -not [bool]$walking[$_] }).Count
    $walkingObserved = $walkingKeysExact -and $failedWalking -eq 0
    $expectedRole = "treatment"
    $claimsExact = (
        [bool]$Receipt.development_only -and
        -not [bool]$Receipt.walking_claim_authorized -and
        -not [bool]$Receipt.nuisance_acceptance_claim_authorized -and
        -not [bool]$Receipt.rough_terrain_acceptance -and
        -not [bool]$Receipt.release_authorized -and
        -not [bool]$Receipt.physical_acceptance_authority
    )
    $identityExact = (
        $receiptKeysExact -and
        [string]$Receipt.schema_version -ceq
            "sporespore_balanced_wave_bw34y_rough_yaw_rescue_raw_cell_v1" -and
        [string]$Receipt.final_receipt_composer_id -ceq
            "bw34y_actual_dynamic_parent_summary_composer_v1" -and
        [bool]$Receipt.shared_receipt_composer_passed -and
        [string]$Receipt.campaign_id -ceq "BW34Y-BW33N-ROUGH-YAW-RESCUE-DEVELOPMENT" -and
        [string]$Receipt.gate_id -ceq "BW34Y" -and
        [string]$Receipt.route_id -ceq "DRP1-SUCCESSOR-ROUTE" -and
        [bool]$Receipt.dynamic_parent_summary_gate_passed -and
        [string]$Receipt.cell_id -ceq [string]$ExpectedCell.cell_id -and
        [string]$Receipt.cohort -ceq "single_arm_outcome_exposed_rough_yaw_rescue" -and
        [string]$Receipt.role -ceq $expectedRole -and
        [int]$Receipt.campaign_seed -eq [int]$ExpectedCell.campaign_seed -and
        [string]$Receipt.challenge_profile_id -ceq "bw6n_rough_v1" -and
        [string]$Receipt.candidate_id -ceq [string]$ExpectedCell.candidate_id -and
        [string]$Receipt.candidate_composition_digest -ceq
            [string]$Binding.candidate_composition_digest -and
        [string]$Receipt.controller_policy_id -ceq [string]$Candidate.controller_policy_id -and
        [string]$Receipt.controller_runtime_profile_sha256 -ceq
            [string]$Candidate.runtime_profile_sha256 -and
        [math]::Abs(
            [double]$Receipt.yaw_error_stride_gain_per_rad -
            [double]$Candidate.yaw_error_stride_gain_per_rad
        ) -le 1.0e-12 -and
        [math]::Abs(
            [double]$Receipt.global_requested_correction_scale -
            [double]$Candidate.global_requested_correction_scale
        ) -le 1.0e-12 -and
        [int]$Receipt.treatment_factor_count -eq 1 -and
        [bool]$Receipt.selection_eligible -and
        [int]$Receipt.policy_branch_surface_count -eq 0 -and
        [string]$Receipt.stability_policy_id -ceq
            "sporespore_scheduled_load_transfer_bw13p_a_v3" -and
        [string]$Receipt.authority_scope -ceq "post_settle_full" -and
        [string]$Receipt.execution_mode -ceq
            "native_balanced_wave_base_with_stability_contribution"
    )
    $runtimeExact = (
        [string]$Receipt.material_profile_id -ceq "godot_jolt_bw5c_mu095_v1" -and
        [string]$Receipt.material_profile_sha256 -ceq
            "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993" -and
        [string]$Receipt.measurement_policy_id -ceq "bounded_all_support_acquisition_v1" -and
        [string]$Receipt.measurement_policy_digest -ceq
            "sha256:4a49770e35b67b2186a5a64ad3dcbf7d1d637e9ffc6ea2a9365615731eb2e748" -and
        [string]$Receipt.authority_horizon_policy_id -ceq
            "fixed_candidate_authority_exposure_horizon_v1" -and
        [string]$Receipt.authority_horizon_policy_sha256 -ceq
            "sha256:ec8291ecd54dbc8299d79d6b3adf176bf67fe851e4bacffc3df253c9a0a605df" -and
        [int]$Receipt.candidate_authority_observation_count -eq 3232 -and
        [int]$Receipt.first_candidate_authority_observation_index -eq 0 -and
        [int]$Receipt.last_candidate_authority_observation_index -eq 3231 -and
        [int]$Receipt.pre_authority_world_tick_count -eq 240 -and
        [int]$Receipt.candidate_specific_horizon_extension_count -eq 0 -and
        [string]$Receipt.challenge_configuration_sha256 -ceq
            "sha256:da97bf60b8ed83c80b9ab3c00c188b8d8b874b3c1ca9b180a4940873cef8ec7e" -and
        [bool]$Receipt.identity_profile_scale_gate_passed -and
        [bool]$Receipt.measurement_gate_passed -and
        [bool]$Receipt.material_gate_passed -and
        [bool]$Receipt.challenge_gate_passed -and
        [bool]$Receipt.application_gate_passed -and
        [bool]$Receipt.mechanism_gate_passed -and
        [bool]$Receipt.common_execution_integrity -and
        [bool]$Receipt.outcome_complete -and
        $Receipt.failure_code -is [string] -and
        [int]$Receipt.failed_walking_gate_count -eq $failedWalking -and
        [bool]$Receipt.walking_observed -eq $walkingObserved -and
        [int]$Receipt.world_build_count -eq 1 -and
        [int]$Receipt.world_reset_count -eq 0 -and
        [string]$Receipt.physics_engine -ceq "Jolt Physics" -and
        [int]$Receipt.physics_hz -eq 120 -and
        [int]$Receipt.solver_velocity_steps -eq 20 -and
        [int]$Receipt.solver_position_steps -eq 7 -and
        [int]$Receipt.terrain_shape_count -eq 64 -and
        [int]$Receipt.external_push_application_count -eq 0 -and
        [int]$Receipt.observation_fault_application_count -eq 0 -and
        [int]$Receipt.observation_fault_base_and_stability_count -eq 0 -and
        [double]$Receipt.maximum_observation_fault_component -eq 0.0 -and
        [bool]$Receipt.physical_influence -and
        [bool]$Receipt.role_gate_passed -and
        $claimsExact -and $walkingKeysExact
    )
    return [ordered]@{
        cell_id = [string]$ExpectedCell.cell_id
        candidate_id = [string]$ExpectedCell.candidate_id
        campaign_seed = [int]$ExpectedCell.campaign_seed
        passed = $identityExact -and $runtimeExact
        identity_exact = $identityExact
        runtime_integrity_exact = $runtimeExact
        walking_observed = $walkingObserved
        failed_walking_gate_count = $failedWalking
        valid_walking_negative = (
            $identityExact -and $runtimeExact -and -not $walkingObserved -and $failedWalking -gt 0
        )
    }
}

function Invoke-Bw34yRoughYawRescueEvaluation {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$CellReceipts,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Source,
        [Parameter(Mandatory)][string]$AttemptId
    )
    $authorities = Get-Bw34yAuthorities
    $expectedCells = @($authorities.cells)
    $receiptById = @{}
    $duplicateIds = [System.Collections.Generic.List[string]]::new()
    foreach ($receipt in $CellReceipts) {
        $map = [System.Collections.IDictionary]$receipt
        $cellId = [string]$map.cell_id
        if ($receiptById.ContainsKey($cellId)) { [void]$duplicateIds.Add($cellId) }
        else { $receiptById[$cellId] = $map }
    }
    $cellResults = [System.Collections.Generic.List[object]]::new()
    foreach ($cell in $expectedCells) {
        $candidateId = [string]$cell.candidate_id
        if (-not $receiptById.ContainsKey([string]$cell.cell_id)) {
            [void]$cellResults.Add([ordered]@{
                cell_id = [string]$cell.cell_id
                candidate_id = $candidateId
                campaign_seed = [int]$cell.campaign_seed
                passed = $false
                identity_exact = $false
                runtime_integrity_exact = $false
                walking_observed = $false
                failed_walking_gate_count = -1
                valid_walking_negative = $false
            })
            continue
        }
        [void]$cellResults.Add((Test-Bw34yCellReceipt `
            -Receipt $receiptById[[string]$cell.cell_id] `
            -ExpectedCell $cell `
            -Candidate $authorities.candidates[$candidateId] `
            -Binding $authorities.bindings[$candidateId]))
    }
    $candidateSummaries = [ordered]@{}
    $candidateId = "BW34Y-A"
    $candidateCells = @($cellResults | Where-Object { $_.candidate_id -ceq $candidateId })
    $passingSeeds = @($candidateCells | Where-Object { $_.walking_observed } |
        ForEach-Object { [int]$_.campaign_seed })
    $failedGateTotal = @($candidateCells |
        ForEach-Object { [int]$_.failed_walking_gate_count } |
        Where-Object { $_ -gt 0 } | Measure-Object -Sum).Sum
    $preservesRetainedPassingSeed = $passingSeeds -contains 21001
    $eligible = (
        @($candidateCells | Where-Object { $_.passed }).Count -eq 3 -and
        $passingSeeds.Count -eq 3 -and
        [int]$failedGateTotal -eq 0 -and
        $preservesRetainedPassingSeed
    )
    $candidateSummaries[$candidateId] = [ordered]@{
        expected_cell_count = 3
        integrity_pass_count = @($candidateCells | Where-Object { $_.passed }).Count
        walking_pass_count = $passingSeeds.Count
        failed_walking_gate_count = [int]$failedGateTotal
        walking_passing_seed_ids = $passingSeeds
        retained_comparator_passing_seed_21001_preserved = $preservesRetainedPassingSeed
        eligible_for_selection = $eligible
    }
    $selected = if ($eligible) { "BW34Y-A" } else { "NONE" }
    $complete = (
        $CellReceipts.Count -eq 3 -and
        $receiptById.Count -eq 3 -and
        $duplicateIds.Count -eq 0 -and
        @($cellResults | Where-Object { -not $_.passed }).Count -eq 0
    )
    return [ordered]@{
        schema_version = "sporespore_balanced_wave_bw34y_rough_yaw_rescue_evaluation_v1"
        ok = $complete
        campaign_id = "BW34Y-BW33N-ROUGH-YAW-RESCUE-DEVELOPMENT"
        gate_id = "BW34Y"
        attempt_id = $AttemptId
        source = $Source
        expected_world_count = 3
        observed_receipt_count = $CellReceipts.Count
        unique_receipt_count = $receiptById.Count
        duplicate_cell_ids = @($duplicateIds)
        invalid_cell_count = @($cellResults | Where-Object { -not $_.passed }).Count
        valid_walking_negative_count = @($cellResults | Where-Object {
            $_.valid_walking_negative
        }).Count
        cell_results = @($cellResults)
        candidate_summaries = $candidateSummaries
        retained_comparator_candidate_id = "BW33N-C"
        retained_comparator_walking_passing_seed_ids = @(21001)
        required_preserved_seed_ids = @(21001)
        prospective_selector_order = @("BW34Y-A")
        selected_candidate_id = if ($complete) { $selected } else { "INVALID" }
        selection_valid = $complete
        development_only = $true
        walking_claim_authorized = $false
        nuisance_acceptance_claim_authorized = $false
        rough_terrain_acceptance = $false
        independent_validation_authority = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        throw "-InputPath is required when the BW34Y evaluator is executed directly"
    }
    $input = Read-Bw34yJsonMap $InputPath
    $evaluation = Invoke-Bw34yRoughYawRescueEvaluation `
        -CellReceipts @($input.cell_receipts) `
        -Source ([System.Collections.IDictionary]$input.source) `
        -AttemptId ([string]$input.attempt_id)
    $json = $evaluation | ConvertTo-Json -Depth 64
    if ([string]::IsNullOrWhiteSpace($OutputPath)) { $json }
    else {
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::GetFullPath($OutputPath),
            $json + [Environment]::NewLine,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    if (-not [bool]$evaluation.ok) { exit 1 }
}
