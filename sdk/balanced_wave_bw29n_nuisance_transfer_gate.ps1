[CmdletBinding()]
param(
    [string]$InputPath = "",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-Bw29nMapValue {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Map,
        [Parameter(Mandatory)][string]$Key,
        $Default = $null
    )
    if ($Map.Contains($Key)) { return $Map[$Key] }
    return $Default
}

function Test-Bw29nFinite {
    param($Value)
    try { $number = [double]$Value } catch { return $false }
    return -not [double]::IsNaN($number) -and -not [double]::IsInfinity($number)
}

function Get-Bw29nExpectedCells {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $manifestPath = Join-Path $repoRoot "sdk\balanced_wave_bw29n_nuisance_transfer_manifest.json"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    return @($manifest.ordered_cells)
}

function Add-Bw29nGate {
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

function Test-Bw29nCell {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Receipt,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Expected
    )
    $candidateId = [string]$Expected.candidate_id
    $expectedDigest = if ($candidateId -ceq "BW29N-A") {
        "sha256:794b42e64e1a89f371b0113ad1c3cf14c0a3d87abfed876323eda9e4aaeed1e6"
    } else {
        "sha256:3490c1934bb018ef68a54b5d5415c7d19dddf7696ee0ac7fca4ab27951957e4d"
    }
    $identityExact = (
        [string]$Receipt.schema_version -ceq "sporespore_balanced_wave_bw29n_nuisance_transfer_raw_cell_v1" -and
        [string]$Receipt.campaign_id -ceq "BW29N-BW19V-NUISANCE-TRANSFER-DEVELOPMENT" -and
        [string]$Receipt.gate_id -ceq "BW29N" -and
        [string]$Receipt.cell_id -ceq [string]$Expected.cell_id -and
        [string]$Receipt.cohort -ceq "paired_outcome_exposed_nuisance_transfer" -and
        [string]$Receipt.role -ceq "candidate" -and
        [int]$Receipt.campaign_seed -eq [int]$Expected.campaign_seed -and
        [string]$Receipt.challenge_profile_id -ceq [string]$Expected.challenge_profile_id -and
        [string]$Receipt.candidate_id -ceq $candidateId -and
        [string]$Receipt.candidate_composition_digest -ceq $expectedDigest -and
        [string]$Receipt.material_profile_id -ceq "godot_jolt_bw5c_mu095_v1" -and
        [string]$Receipt.material_profile_digest -ceq "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993" -and
        [string]$Receipt.measurement_policy_id -ceq "bounded_all_support_acquisition_v1" -and
        [string]$Receipt.measurement_policy_digest -ceq "sha256:4a49770e35b67b2186a5a64ad3dcbf7d1d637e9ffc6ea2a9365615731eb2e748"
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
            (Test-Bw29nFinite $Receipt.maximum_observation_fault_component) -and
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
        engine_exact = $engineExact
        challenge_exact = [bool]$challengeCountsExact -and [bool]$Receipt.challenge_gate_passed
        measurement_exact = [bool]$Receipt.measurement_gate_passed
        application_exact = [bool]$Receipt.application_gate_passed
        outcome_complete = [bool]$Receipt.outcome_complete
        walking_observed = [bool]$Receipt.walking_observed
        claims_exact = $claimsExact
        integrity_exact = $integrityExact
        cell_gate_passed = (
            $identityExact -and $engineExact -and [bool]$challengeCountsExact -and
            $integrityExact -and $claimsExact
        )
    }
}

function Get-Bw29nCandidateSummary {
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

function Invoke-Bw29nNuisanceTransferEvaluation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$CellReceipts,
        [System.Collections.IDictionary]$Source = ([ordered]@{}),
        [string]$AttemptId = "synthetic_zero_world_evaluation"
    )
    $expected = @(Get-Bw29nExpectedCells)
    $receiptById = @{}
    $duplicateIds = [System.Collections.Generic.List[string]]::new()
    foreach ($receiptValue in $CellReceipts) {
        if ($receiptValue -isnot [System.Collections.IDictionary]) { continue }
        $receipt = [System.Collections.IDictionary]$receiptValue
        $cellId = [string](Get-Bw29nMapValue $receipt "cell_id" "")
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
        [void]$evaluated.Add((Test-Bw29nCell -Receipt $receiptById[$cellId] -Expected $expectedCell))
    }
    $unexpected = @($receiptById.Keys | Where-Object { $_ -notin @($expected.cell_id) })
    $cardinalityExact = (
        $CellReceipts.Count -eq 24 -and $receiptById.Count -eq 24 -and
        $missing.Count -eq 0 -and $duplicateIds.Count -eq 0 -and $unexpected.Count -eq 0
    )
    $a = Get-Bw29nCandidateSummary -Cells @($evaluated) -CandidateId "BW29N-A"
    $b = Get-Bw29nCandidateSummary -Cells @($evaluated) -CandidateId "BW29N-B"
    $allCellsExact = $cardinalityExact -and @($evaluated | Where-Object { -not [bool]$_.cell_gate_passed }).Count -eq 0
    $perAxisNonRegression = $true
    foreach ($axis in @("bw6n_baseline_v1", "bw6n_rough_v1", "bw6n_push_v1", "bw6n_sensor_noise_v1")) {
        $perAxisNonRegression = $perAxisNonRegression -and (
            [int]$b.failures_by_axis[$axis] -le [int]$a.failures_by_axis[$axis]
        )
    }
    $strictTotalImprovement = [int]$b.walking_failure_count -lt [int]$a.walking_failure_count
    $selected = if ($allCellsExact -and $strictTotalImprovement -and $perAxisNonRegression) {
        "BW29N-B"
    } else { "NONE" }
    $freshReady = (
        $selected -ceq "BW29N-B" -and [int]$b.walking_pass_count -eq 12 -and
        [int]$b.walking_failure_count -eq 0
    )
    $gates = [System.Collections.Generic.List[object]]::new()
    Add-Bw29nGate $gates "exact_cardinality" $cardinalityExact "BW29N_CARDINALITY_INVALID"
    Add-Bw29nGate $gates "exact_identities" (@($evaluated | Where-Object { -not [bool]$_.identity_exact }).Count -eq 0 -and $cardinalityExact) "BW29N_IDENTITY_INVALID"
    Add-Bw29nGate $gates "engine_integrity" (@($evaluated | Where-Object { -not [bool]$_.engine_exact }).Count -eq 0 -and $cardinalityExact) "BW29N_ENGINE_INVALID"
    Add-Bw29nGate $gates "challenge_realization" (@($evaluated | Where-Object { -not [bool]$_.challenge_exact }).Count -eq 0 -and $cardinalityExact) "BW29N_CHALLENGE_INVALID"
    Add-Bw29nGate $gates "measurement_acquisition" (@($evaluated | Where-Object { -not [bool]$_.measurement_exact }).Count -eq 0 -and $cardinalityExact) "BW29N_MEASUREMENT_INVALID"
    Add-Bw29nGate $gates "candidate_application" (@($evaluated | Where-Object { -not [bool]$_.application_exact }).Count -eq 0 -and $cardinalityExact) "BW29N_APPLICATION_INVALID"
    Add-Bw29nGate $gates "outcome_complete" (@($evaluated | Where-Object { -not [bool]$_.outcome_complete }).Count -eq 0 -and $cardinalityExact) "BW29N_OUTCOME_INCOMPLETE"
    Add-Bw29nGate $gates "claims_bounded" (@($evaluated | Where-Object { -not [bool]$_.claims_exact }).Count -eq 0 -and $cardinalityExact) "BW29N_CLAIM_INFLATION"
    Add-Bw29nGate $gates "paired_matrix_complete" ($a.cell_count -eq 12 -and $b.cell_count -eq 12) "BW29N_PAIRING_INVALID"
    Add-Bw29nGate $gates "selection_rule_defined" ($selected -in @("BW29N-B", "NONE")) "BW29N_SELECTION_INVALID"
    Add-Bw29nGate $gates "fresh_validation_not_promoted" (-not $freshReady -or $selected -ceq "BW29N-B") "BW29N_FRESH_READY_INVALID"
    Add-Bw29nGate $gates "complete_development_result" $allCellsExact "BW29N_DEVELOPMENT_RESULT_INVALID"
    $failureCodes = @($gates | Where-Object { -not [bool]$_.passed } | ForEach-Object { [string]$_.failure_code })
    return [ordered]@{
        schema_version = "sporespore_balanced_wave_bw29n_nuisance_transfer_evaluation_v1"
        ok = $failureCodes.Count -eq 0
        status = if ($failureCodes.Count -eq 0) { "complete_valid_development_result" } else { "invalid_or_incomplete" }
        campaign_id = "BW29N-BW19V-NUISANCE-TRANSFER-DEVELOPMENT"
        gate_id = "BW29N"
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
        expected_gate_count = 12
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

function New-Bw29nPerfectSyntheticReceiptSet {
    $receipts = [System.Collections.Generic.List[object]]::new()
    foreach ($cell in @(Get-Bw29nExpectedCells)) {
        $profile = [string]$cell.challenge_profile_id
        $candidate = [string]$cell.candidate_id
        $digest = if ($candidate -ceq "BW29N-A") {
            "sha256:794b42e64e1a89f371b0113ad1c3cf14c0a3d87abfed876323eda9e4aaeed1e6"
        } else {
            "sha256:3490c1934bb018ef68a54b5d5415c7d19dddf7696ee0ac7fca4ab27951957e4d"
        }
        $terrain = if ($profile -ceq "bw6n_rough_v1") { 64 } else { 1 }
        $push = if ($profile -ceq "bw6n_push_v1") { 1 } else { 0 }
        $noise = if ($profile -ceq "bw6n_sensor_noise_v1") { 1514 } else { 0 }
        [void]$receipts.Add([ordered]@{
            schema_version = "sporespore_balanced_wave_bw29n_nuisance_transfer_raw_cell_v1"
            campaign_id = "BW29N-BW19V-NUISANCE-TRANSFER-DEVELOPMENT"
            gate_id = "BW29N"
            cell_id = [string]$cell.cell_id
            cohort = "paired_outcome_exposed_nuisance_transfer"
            role = "candidate"
            campaign_seed = [int]$cell.campaign_seed
            challenge_profile_id = $profile
            candidate_id = $candidate
            candidate_composition_digest = $digest
            material_profile_id = "godot_jolt_bw5c_mu095_v1"
            material_profile_digest = "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
            measurement_policy_id = "bounded_all_support_acquisition_v1"
            measurement_policy_digest = "sha256:4a49770e35b67b2186a5a64ad3dcbf7d1d637e9ffc6ea2a9365615731eb2e748"
            measurement_gate_passed = $true
            challenge_gate_passed = $true
            application_gate_passed = $true
            common_execution_integrity = $true
            outcome_complete = $true
            walking_observed = $true
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
        throw "-InputPath is required when the BW29N evaluator is executed directly"
    }
    $input = Get-Content -Raw -LiteralPath $InputPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    $evaluation = Invoke-Bw29nNuisanceTransferEvaluation `
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
