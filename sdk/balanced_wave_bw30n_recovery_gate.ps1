[CmdletBinding()]
param(
    [string]$InputPath = "",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-Bw30nMapValue {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Map,
        [Parameter(Mandatory)][string]$Key,
        $Default = $null
    )
    if ($Map.Contains($Key)) { return $Map[$Key] }
    return $Default
}

function Test-Bw30nFinite {
    param($Value)
    try { $number = [double]$Value } catch { return $false }
    return -not [double]::IsNaN($number) -and -not [double]::IsInfinity($number)
}

function Get-Bw30nFinalReceiptKeys {
    return @(
        "schema_version", "final_receipt_composer_id",
        "shared_receipt_composer_passed", "campaign_id", "gate_id", "cell_id",
        "cohort", "role", "campaign_seed", "challenge_profile_id", "candidate_id",
        "candidate_composition_digest", "controller_policy_id",
        "controller_policy_digest", "stability_policy_id", "authority_scope",
        "execution_mode", "material_profile_id", "material_profile_sha256",
        "measurement_policy_id", "measurement_policy_digest",
        "terminal_horizon_policy_id", "terminal_horizon_policy_sha256",
        "post_sdk_observation_count", "first_post_sdk_observation_index",
        "last_post_sdk_observation_index", "candidate_specific_horizon_extension_count",
        "challenge_configuration_sha256", "measurement_gate_passed",
        "challenge_gate_passed", "application_gate_passed",
        "common_execution_integrity", "outcome_complete", "walking_observed",
        "walking_gate_receipts", "world_build_count", "world_reset_count",
        "physics_engine", "physics_hz", "solver_velocity_steps",
        "solver_position_steps", "terrain_shape_count",
        "external_push_application_count", "observation_fault_application_count",
        "observation_fault_base_and_stability_count",
        "maximum_observation_fault_component", "physical_influence",
        "role_gate_passed", "development_only", "walking_claim_authorized",
        "nuisance_acceptance_claim_authorized", "release_authorized",
        "physical_acceptance_authority"
    )
}

function Get-Bw30nExpectedCells {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $manifestPath = Join-Path $repoRoot "sdk\balanced_wave_bw30n_recovery_manifest.json"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    return @($manifest.ordered_cells)
}

function Add-Bw30nGate {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Gates,
        [Parameter(Mandatory)][string]$GateId,
        [Parameter(Mandatory)][bool]$Passed,
        [Parameter(Mandatory)][string]$FailureCode
    )
    [void]$Gates.Add([ordered]@{
        gate_id = $GateId
        passed = $Passed
        failure_code = if ($Passed) { "" } else { $FailureCode }
    })
}

function Test-Bw30nCell {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Receipt,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Expected
    )
    $candidateId = [string]$Expected.candidate_id
    $expectedDigest = if ($candidateId -ceq "BW30N-A") {
        "sha256:794b42e64e1a89f371b0113ad1c3cf14c0a3d87abfed876323eda9e4aaeed1e6"
    } else {
        "sha256:3490c1934bb018ef68a54b5d5415c7d19dddf7696ee0ac7fca4ab27951957e4d"
    }
    $actualKeys = @($Receipt.Keys | Sort-Object)
    $expectedKeys = @(Get-Bw30nFinalReceiptKeys | Sort-Object)
    $receiptKeysExact = (
        $actualKeys.Count -eq $expectedKeys.Count -and
        @(Compare-Object -ReferenceObject $expectedKeys -DifferenceObject $actualKeys).Count -eq 0
    )
    $identityExact = (
        $receiptKeysExact -and
        [string]$Receipt.schema_version -ceq "sporespore_balanced_wave_bw30n_recovery_raw_cell_v1" -and
        [string]$Receipt.final_receipt_composer_id -ceq "bw30n_shared_final_receipt_composer_v1" -and
        [bool]$Receipt.shared_receipt_composer_passed -and
        [string]$Receipt.campaign_id -ceq "BW30N-BW29N-IMPLEMENTATION-RECOVERY-DEVELOPMENT" -and
        [string]$Receipt.gate_id -ceq "BW30N" -and
        [string]$Receipt.cell_id -ceq [string]$Expected.cell_id -and
        [string]$Receipt.cohort -ceq "paired_outcome_exposed_implementation_recovery" -and
        [string]$Receipt.role -ceq "candidate" -and
        [int]$Receipt.campaign_seed -eq [int]$Expected.campaign_seed -and
        [string]$Receipt.challenge_profile_id -ceq [string]$Expected.challenge_profile_id -and
        [string]$Receipt.candidate_id -ceq $candidateId -and
        [string]$Receipt.candidate_composition_digest -ceq $expectedDigest -and
        [string]$Receipt.material_profile_id -ceq "godot_jolt_bw5c_mu095_v1" -and
        [string]$Receipt.material_profile_sha256 -ceq "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993" -and
        [string]$Receipt.measurement_policy_id -ceq "bounded_all_support_acquisition_v1" -and
        [string]$Receipt.measurement_policy_digest -ceq "sha256:4a49770e35b67b2186a5a64ad3dcbf7d1d637e9ffc6ea2a9365615731eb2e748" -and
        -not [string]::IsNullOrWhiteSpace([string]$Receipt.controller_policy_id) -and
        -not [string]::IsNullOrWhiteSpace([string]$Receipt.controller_policy_digest) -and
        -not [string]::IsNullOrWhiteSpace([string]$Receipt.stability_policy_id) -and
        -not [string]::IsNullOrWhiteSpace([string]$Receipt.authority_scope) -and
        -not [string]::IsNullOrWhiteSpace([string]$Receipt.execution_mode) -and
        -not [string]::IsNullOrWhiteSpace([string]$Receipt.challenge_configuration_sha256)
    )
    $horizonExact = (
        [string]$Receipt.terminal_horizon_policy_id -ceq "fixed_post_sdk_observation_horizon_v1" -and
        [string]$Receipt.terminal_horizon_policy_sha256 -ceq "sha256:3b76314d6d0726746644f4c66ae67da01364a353d199562f3ed9843be349d912" -and
        [int]$Receipt.post_sdk_observation_count -eq 1514 -and
        [int]$Receipt.first_post_sdk_observation_index -eq 0 -and
        [int]$Receipt.last_post_sdk_observation_index -eq 1513 -and
        [int]$Receipt.candidate_specific_horizon_extension_count -eq 0
    )
    $engineExact = (
        [int]$Receipt.world_build_count -eq 1 -and
        [int]$Receipt.world_reset_count -eq 0 -and
        [string]$Receipt.physics_engine -ceq "Jolt Physics" -and
        [int]$Receipt.physics_hz -eq 120 -and
        [int]$Receipt.solver_velocity_steps -eq 20 -and
        [int]$Receipt.solver_position_steps -eq 7
    )
    $profile = [string]$Expected.challenge_profile_id
    $challengeCountsExact = switch ($profile) {
        "bw6n_baseline_v1" {
            [int]$Receipt.terrain_shape_count -eq 1 -and
            [int]$Receipt.external_push_application_count -eq 0 -and
            [int]$Receipt.observation_fault_application_count -eq 0
        }
        "bw6n_rough_v1" {
            [int]$Receipt.terrain_shape_count -eq 64 -and
            [int]$Receipt.external_push_application_count -eq 0 -and
            [int]$Receipt.observation_fault_application_count -eq 0
        }
        "bw6n_push_v1" {
            [int]$Receipt.terrain_shape_count -eq 1 -and
            [int]$Receipt.external_push_application_count -eq 1 -and
            [int]$Receipt.observation_fault_application_count -eq 0
        }
        "bw6n_sensor_noise_v1" {
            [int]$Receipt.terrain_shape_count -eq 1 -and
            [int]$Receipt.external_push_application_count -eq 0 -and
            [int]$Receipt.observation_fault_application_count -eq 1514 -and
            [int]$Receipt.observation_fault_base_and_stability_count -eq 1514 -and
            (Test-Bw30nFinite $Receipt.maximum_observation_fault_component) -and
            [double]$Receipt.maximum_observation_fault_component -gt 0.0
        }
        default { $false }
    }
    $claimsExact = (
        [bool]$Receipt.development_only -and
        -not [bool]$Receipt.walking_claim_authorized -and
        -not [bool]$Receipt.nuisance_acceptance_claim_authorized -and
        -not [bool]$Receipt.release_authorized -and
        -not [bool]$Receipt.physical_acceptance_authority
    )
    $integrityExact = (
        $horizonExact -and [bool]$Receipt.shared_receipt_composer_passed -and
        [bool]$Receipt.common_execution_integrity -and
        [bool]$Receipt.challenge_gate_passed -and
        [bool]$Receipt.measurement_gate_passed -and
        [bool]$Receipt.application_gate_passed -and
        [bool]$Receipt.outcome_complete -and
        [bool]$Receipt.role_gate_passed
    )
    return [ordered]@{
        cell_id = [string]$Expected.cell_id
        candidate_id = $candidateId
        challenge_profile_id = $profile
        campaign_seed = [int]$Expected.campaign_seed
        identity_exact = $identityExact
        receipt_keys_exact = $receiptKeysExact
        horizon_exact = $horizonExact
        engine_exact = $engineExact
        challenge_exact = [bool]$challengeCountsExact -and [bool]$Receipt.challenge_gate_passed
        measurement_exact = [bool]$Receipt.measurement_gate_passed
        application_exact = [bool]$Receipt.application_gate_passed
        outcome_complete = [bool]$Receipt.outcome_complete
        walking_observed = [bool]$Receipt.walking_observed
        claims_exact = $claimsExact
        integrity_exact = $integrityExact
        cell_gate_passed = (
            $identityExact -and $horizonExact -and $engineExact -and [bool]$challengeCountsExact -and
            $integrityExact -and $claimsExact
        )
    }
}

function Get-Bw30nCandidateSummary {
    param(
        [Parameter(Mandatory)][object[]]$Cells,
        [Parameter(Mandatory)][string]$CandidateId
    )
    $candidateCells = @($Cells | Where-Object { [string]$_.candidate_id -ceq $CandidateId })
    $failuresByAxis = [ordered]@{}
    foreach ($axis in @("bw6n_baseline_v1", "bw6n_rough_v1", "bw6n_push_v1", "bw6n_sensor_noise_v1")) {
        $axisCells = @($candidateCells | Where-Object { [string]$_.challenge_profile_id -ceq $axis })
        $failuresByAxis[$axis] = @($axisCells | Where-Object { -not [bool]$_.walking_observed }).Count
    }
    return [ordered]@{
        candidate_id = $CandidateId
        cell_count = $candidateCells.Count
        integrity_pass_count = @($candidateCells | Where-Object { [bool]$_.cell_gate_passed }).Count
        walking_pass_count = @($candidateCells | Where-Object { [bool]$_.walking_observed }).Count
        walking_failure_count = @($candidateCells | Where-Object { -not [bool]$_.walking_observed }).Count
        failures_by_axis = $failuresByAxis
    }
}

function Invoke-Bw30nRecoveryEvaluation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$CellReceipts,
        [System.Collections.IDictionary]$Source = ([ordered]@{}),
        [string]$AttemptId = "synthetic_zero_world_evaluation"
    )
    $expected = @(Get-Bw30nExpectedCells)
    $receiptById = @{}
    $duplicateIds = [System.Collections.Generic.List[string]]::new()
    foreach ($receiptValue in $CellReceipts) {
        if ($receiptValue -isnot [System.Collections.IDictionary]) { continue }
        $receipt = [System.Collections.IDictionary]$receiptValue
        $cellId = [string](Get-Bw30nMapValue $receipt "cell_id" "")
        if ($receiptById.ContainsKey($cellId)) { [void]$duplicateIds.Add($cellId) } else { $receiptById[$cellId] = $receipt }
    }
    $evaluated = [System.Collections.Generic.List[object]]::new()
    $missing = [System.Collections.Generic.List[string]]::new()
    foreach ($expectedCell in $expected) {
        $cellId = [string]$expectedCell.cell_id
        if (-not $receiptById.ContainsKey($cellId)) {
            [void]$missing.Add($cellId)
            continue
        }
        [void]$evaluated.Add((Test-Bw30nCell -Receipt $receiptById[$cellId] -Expected $expectedCell))
    }
    $unexpected = @($receiptById.Keys | Where-Object { $_ -notin @($expected.cell_id) })
    $cardinalityExact = (
        $CellReceipts.Count -eq 24 -and $receiptById.Count -eq 24 -and
        $missing.Count -eq 0 -and $duplicateIds.Count -eq 0 -and $unexpected.Count -eq 0
    )
    $a = Get-Bw30nCandidateSummary -Cells @($evaluated) -CandidateId "BW30N-A"
    $b = Get-Bw30nCandidateSummary -Cells @($evaluated) -CandidateId "BW30N-B"
    $allCellsExact = $cardinalityExact -and @($evaluated | Where-Object { -not [bool]$_.cell_gate_passed }).Count -eq 0
    $perAxisNonRegression = $true
    foreach ($axis in @("bw6n_baseline_v1", "bw6n_rough_v1", "bw6n_push_v1", "bw6n_sensor_noise_v1")) {
        $perAxisNonRegression = $perAxisNonRegression -and (
            [int]$b.failures_by_axis[$axis] -le [int]$a.failures_by_axis[$axis]
        )
    }
    $strictTotalImprovement = [int]$b.walking_failure_count -lt [int]$a.walking_failure_count
    $selected = if ($allCellsExact -and $strictTotalImprovement -and $perAxisNonRegression) {
        "BW30N-B"
    } else { "NONE" }
    $freshReady = (
        $selected -ceq "BW30N-B" -and [int]$b.walking_pass_count -eq 12 -and
        [int]$b.walking_failure_count -eq 0
    )
    $gates = [System.Collections.Generic.List[object]]::new()
    Add-Bw30nGate $gates "exact_cardinality" $cardinalityExact "BW30N_CARDINALITY_INVALID"
    Add-Bw30nGate $gates "exact_identities" (@($evaluated | Where-Object { -not [bool]$_.identity_exact }).Count -eq 0 -and $cardinalityExact) "BW30N_IDENTITY_INVALID"
    Add-Bw30nGate $gates "shared_final_receipt_schema" (@($evaluated | Where-Object { -not [bool]$_.receipt_keys_exact }).Count -eq 0 -and $cardinalityExact) "BW30N_RECEIPT_SCHEMA_INVALID"
    Add-Bw30nGate $gates "fixed_observation_horizon" (@($evaluated | Where-Object { -not [bool]$_.horizon_exact }).Count -eq 0 -and $cardinalityExact) "BW30N_HORIZON_INVALID"
    Add-Bw30nGate $gates "engine_integrity" (@($evaluated | Where-Object { -not [bool]$_.engine_exact }).Count -eq 0 -and $cardinalityExact) "BW30N_ENGINE_INVALID"
    Add-Bw30nGate $gates "challenge_realization" (@($evaluated | Where-Object { -not [bool]$_.challenge_exact }).Count -eq 0 -and $cardinalityExact) "BW30N_CHALLENGE_INVALID"
    Add-Bw30nGate $gates "measurement_acquisition" (@($evaluated | Where-Object { -not [bool]$_.measurement_exact }).Count -eq 0 -and $cardinalityExact) "BW30N_MEASUREMENT_INVALID"
    Add-Bw30nGate $gates "candidate_application" (@($evaluated | Where-Object { -not [bool]$_.application_exact }).Count -eq 0 -and $cardinalityExact) "BW30N_APPLICATION_INVALID"
    Add-Bw30nGate $gates "outcome_complete" (@($evaluated | Where-Object { -not [bool]$_.outcome_complete }).Count -eq 0 -and $cardinalityExact) "BW30N_OUTCOME_INCOMPLETE"
    Add-Bw30nGate $gates "claims_bounded" (@($evaluated | Where-Object { -not [bool]$_.claims_exact }).Count -eq 0 -and $cardinalityExact) "BW30N_CLAIM_INFLATION"
    Add-Bw30nGate $gates "paired_matrix_complete" ($a.cell_count -eq 12 -and $b.cell_count -eq 12) "BW30N_PAIRING_INVALID"
    Add-Bw30nGate $gates "selection_rule_defined" ($selected -in @("BW30N-B", "NONE")) "BW30N_SELECTION_INVALID"
    Add-Bw30nGate $gates "fresh_validation_not_promoted" (-not $freshReady -or $selected -ceq "BW30N-B") "BW30N_FRESH_READY_INVALID"
    Add-Bw30nGate $gates "complete_development_result" $allCellsExact "BW30N_DEVELOPMENT_RESULT_INVALID"
    $failureCodes = @($gates | Where-Object { -not [bool]$_.passed } | ForEach-Object { [string]$_.failure_code })
    return [ordered]@{
        schema_version = "sporespore_balanced_wave_bw30n_recovery_evaluation_v1"
        ok = $failureCodes.Count -eq 0
        status = if ($failureCodes.Count -eq 0) { "complete_valid_development_result" } else { "invalid_or_incomplete" }
        campaign_id = "BW30N-BW29N-IMPLEMENTATION-RECOVERY-DEVELOPMENT"
        gate_id = "BW30N"
        attempt_id = $AttemptId
        source = $Source
        expected_world_count = 24
        observed_world_count = $CellReceipts.Count
        evaluated_cell_count = $evaluated.Count
        missing_cell_ids = @($missing)
        duplicate_cell_ids = @($duplicateIds)
        unexpected_cell_ids = @($unexpected)
        candidate_summaries = @($a, $b)
        strict_total_improvement_passed = $strictTotalImprovement
        per_axis_non_regression_passed = $perAxisNonRegression
        selected_candidate_id = $selected
        fresh_nuisance_validation_ready = $freshReady
        selection_is_development_only = $true
        independent_validation_required = $true
        gates = @($gates)
        passed_gate_count = @($gates | Where-Object { [bool]$_.passed }).Count
        failed_gate_count = $failureCodes.Count
        expected_gate_count = 14
        failure_codes = $failureCodes
        cell_evaluations = @($evaluated)
        walking_acceptance = $false
        nuisance_acceptance = $false
        rough_terrain_robustness = $false
        external_push_recovery = $false
        sensor_noise_robustness = $false
        sensor_latency_robustness = $false
        qsdk_r09_promoted = $false
        qsdk_r10_promoted = $false
        qsdk_r11_promoted = $false
        qsdk_r12_promoted = $false
        qsdk_r13_promoted = $false
        completed_engine_neutral_sdk = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
}

function New-Bw30nPerfectSyntheticReceiptSet {
    $receipts = [System.Collections.Generic.List[object]]::new()
    foreach ($cell in @(Get-Bw30nExpectedCells)) {
        $profile = [string]$cell.challenge_profile_id
        $candidate = [string]$cell.candidate_id
        $digest = if ($candidate -ceq "BW30N-A") {
            "sha256:794b42e64e1a89f371b0113ad1c3cf14c0a3d87abfed876323eda9e4aaeed1e6"
        } else {
            "sha256:3490c1934bb018ef68a54b5d5415c7d19dddf7696ee0ac7fca4ab27951957e4d"
        }
        $terrain = if ($profile -ceq "bw6n_rough_v1") { 64 } else { 1 }
        $push = if ($profile -ceq "bw6n_push_v1") { 1 } else { 0 }
        $noise = if ($profile -ceq "bw6n_sensor_noise_v1") { 1514 } else { 0 }
        [void]$receipts.Add([ordered]@{
            schema_version = "sporespore_balanced_wave_bw30n_recovery_raw_cell_v1"
            final_receipt_composer_id = "bw30n_shared_final_receipt_composer_v1"
            shared_receipt_composer_passed = $true
            campaign_id = "BW30N-BW29N-IMPLEMENTATION-RECOVERY-DEVELOPMENT"
            gate_id = "BW30N"
            cell_id = [string]$cell.cell_id
            cohort = "paired_outcome_exposed_implementation_recovery"
            role = "candidate"
            campaign_seed = [int]$cell.campaign_seed
            challenge_profile_id = $profile
            candidate_id = $candidate
            candidate_composition_digest = $digest
            controller_policy_id = if ($candidate -ceq "BW30N-A") { "sporespore_balanced_wave_bw5r_b_v1" } else { "sporespore_balanced_wave_bw15f_b_v1" }
            controller_policy_digest = if ($candidate -ceq "BW30N-A") { "sha256:reference" } else { "sha256:successor" }
            stability_policy_id = if ($candidate -ceq "BW30N-A") { "p5i3c_support_centroid_tilt_feedback_v1" } else { "scheduled_load_transfer_v3" }
            authority_scope = if ($candidate -ceq "BW30N-A") { "stability_contribution_overlay" } else { "post_settle_full" }
            execution_mode = if ($candidate -ceq "BW30N-A") { "portable_balanced_wave_base_with_godot_host_stability_overlay" } else { "native_sdk_full_post_settle_authority" }
            material_profile_id = "godot_jolt_bw5c_mu095_v1"
            material_profile_sha256 = "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
            measurement_policy_id = "bounded_all_support_acquisition_v1"
            measurement_policy_digest = "sha256:4a49770e35b67b2186a5a64ad3dcbf7d1d637e9ffc6ea2a9365615731eb2e748"
            terminal_horizon_policy_id = "fixed_post_sdk_observation_horizon_v1"
            terminal_horizon_policy_sha256 = "sha256:3b76314d6d0726746644f4c66ae67da01364a353d199562f3ed9843be349d912"
            post_sdk_observation_count = 1514
            first_post_sdk_observation_index = 0
            last_post_sdk_observation_index = 1513
            candidate_specific_horizon_extension_count = 0
            challenge_configuration_sha256 = "sha256:$('a' * 64)"
            measurement_gate_passed = $true
            challenge_gate_passed = $true
            application_gate_passed = $true
            common_execution_integrity = $true
            outcome_complete = $true
            walking_observed = $true
            walking_gate_receipts = [ordered]@{}
            world_build_count = 1
            world_reset_count = 0
            physics_engine = "Jolt Physics"
            physics_hz = 120
            solver_velocity_steps = 20
            solver_position_steps = 7
            terrain_shape_count = $terrain
            external_push_application_count = $push
            observation_fault_application_count = $noise
            observation_fault_base_and_stability_count = $noise
            maximum_observation_fault_component = if ($noise -gt 0) { 0.002 } else { 0.0 }
            physical_influence = $true
            role_gate_passed = $true
            development_only = $true
            walking_claim_authorized = $false
            nuisance_acceptance_claim_authorized = $false
            release_authorized = $false
            physical_acceptance_authority = $false
        })
    }
    return @($receipts)
}

if ($MyInvocation.InvocationName -ne ".") {
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        throw "-InputPath is required when the BW30N evaluator is executed directly"
    }
    $input = Get-Content -Raw -LiteralPath $InputPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    $evaluation = Invoke-Bw30nRecoveryEvaluation `
        -CellReceipts @($input["cell_receipts"]) `
        -Source ([System.Collections.IDictionary]$input["source"]) `
        -AttemptId ([string]$input["attempt_id"])
    $json = $evaluation | ConvertTo-Json -Depth 64
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $json
    } else {
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::GetFullPath($OutputPath),
            $json + [Environment]::NewLine,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    if (-not [bool]$evaluation["ok"]) { exit 1 }
}
