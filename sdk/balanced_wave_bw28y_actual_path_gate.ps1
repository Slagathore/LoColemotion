#requires -Version 7.0

Set-StrictMode -Version Latest

$script:Bw28ySdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$script:Bw28yRepoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $script:Bw28ySdkRoot)
)
$script:Bw28yManifestPath = Join-Path $script:Bw28ySdkRoot `
    "balanced_wave_bw28y_yaw_development_manifest.json"
$script:Bw28yRouteContractPath = Join-Path $script:Bw28ySdkRoot `
    "balanced_wave_bw26i_actual_worker_receipt_route_contract.json"
$script:Bw28yEvaluatorPath = Join-Path $script:Bw28ySdkRoot `
    "balanced_wave_bw28y_yaw_development_gate.ps1"
$script:Bw28yRawCellSchema =
    "sporespore_balanced_wave_bw28y_yaw_development_raw_cell_v1"
$script:Bw28yPreflightCampaignAttemptId =
    "BW28Y-ZERO-WORLD-ACTUAL-PATH-PREFLIGHT"

. $script:Bw28yEvaluatorPath

function Copy-Bw28yValue {
    param([Parameter(Mandatory)][object]$Value)
    return $Value | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Bw28yRawReceiptValidation {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$RawCell,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Expected,
        [Parameter(Mandatory)]
        [string]$CampaignAttemptId,
        [Parameter(Mandatory)]
        [string]$WorldAttemptId,
        [Parameter(Mandatory)]
        [string[]]$RequiredKeys
    )
    $failures = [System.Collections.Generic.List[string]]::new()
    foreach ($key in $RequiredKeys) {
        if (-not $RawCell.Contains($key)) { $failures.Add("MISSING_KEY::$key") }
    }
    $identity = [ordered]@{
        schema_version = $script:Bw28yRawCellSchema
        campaign_id = $script:Bw28yCampaignId
        gate_id = $script:Bw28yGateId
        cell_id = [string]$Expected.cell_id
        cohort = [string]$Expected.cohort
        role = [string]$Expected.role
        campaign_attempt_id = $CampaignAttemptId
        world_attempt_id = $WorldAttemptId
    }
    foreach ($entry in $identity.GetEnumerator()) {
        if ([string](Get-Bw28yMapValue $RawCell $entry.Key "") -cne
            [string]$entry.Value) {
            $failures.Add("IDENTITY_MISMATCH::$($entry.Key)")
        }
    }
    foreach ($entry in @(
        [ordered]@{ key = "authored_friction"; value = [double]$Expected.authored_friction },
        [ordered]@{ key = "global_requested_correction_scale"; value = [double]$Expected.global_scale }
    )) {
        if (-not (Test-Bw28yNear (
            Get-Bw28yMapValue $RawCell ([string]$entry.key)
        ) ([double]$entry.value))) {
            $failures.Add("NUMERIC_IDENTITY_MISMATCH::$($entry.key)")
        }
    }
    foreach ($entry in @(
        [ordered]@{ key = "material_profile_id"; value = [string]$Expected.profile_id },
        [ordered]@{ key = "material_profile_sha256"; value = [string]$Expected.profile_digest }
    )) {
        if ([string](Get-Bw28yMapValue $RawCell $entry.key "") -cne
            [string]$entry.value) {
            $failures.Add("DECLARATION_MISMATCH::$($entry.key)")
        }
    }
    $rawCandidateId = if ([string]$Expected.role -ceq "safety") {
        "NONE"
    } else { [string]$Expected.candidate_id }
    $rawCompositionDigest = if ([string]$Expected.role -ceq "safety") {
        "NONE"
    } else { [string]$Expected.composition_digest }
    $rawPolicyId = if ([string]$Expected.role -ceq "safety") {
        "NONE"
    } else { [string]$Expected.policy_id }
    foreach ($entry in @(
        [ordered]@{ key = "candidate_id"; value = $rawCandidateId },
        [ordered]@{ key = "candidate_composition_digest"; value = $rawCompositionDigest },
        [ordered]@{ key = "controller_policy_id"; value = $rawPolicyId }
    )) {
        if ([string](Get-Bw28yMapValue $RawCell $entry.key "") -cne
            [string]$entry.value) {
            $failures.Add("POLICY_IDENTITY_MISMATCH::$($entry.key)")
        }
    }
    if ([int](Get-Bw28yMapValue $RawCell "campaign_seed" -1) -ne
        [int]$Expected.campaign_seed) {
        $failures.Add("CAMPAIGN_SEED_MISMATCH")
    }
    if (-not [bool](Get-Bw28yMapValue $RawCell "raw_receipt_complete" $false)) {
        $failures.Add("RAW_RECEIPT_NOT_COMPLETE")
    }
    if (@((Get-Bw28yMapValue $RawCell "receipt_route_failure_codes" @())).Count -ne 0) {
        $failures.Add("RAW_ROUTE_REPORTED_FAILURE")
    }
    if ([bool](Get-Bw28yMapValue $RawCell "walking_result_controls_process_exit" $true)) {
        $failures.Add("WALKING_OUTCOME_CONTROLS_PROCESS_EXIT")
    }
    if ([bool](Get-Bw28yMapValue $RawCell "physical_acceptance_authority" $true)) {
        $failures.Add("RAW_RECEIPT_CLAIM_INFLATION")
    }
    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures | Sort-Object -Unique)
    }
}

function New-Bw28yActualPathTerminalResult {
    param(
        [Parameter(Mandatory)][string[]]$FailureCodes,
        [int]$RawReceiptCount = 0,
        [int]$StructurallyCompleteCount = 0,
        [int]$FinalReceiptCount = 0,
        [bool]$ProductionEvaluatorInvoked = $false,
        [bool]$ProductionEvaluatorThrew = $false,
        [string]$ProductionSelectedCandidateId = "NONE"
    )
    return [ordered]@{
        schema_version = "sporespore_balanced_wave_bw28y_actual_path_evaluation_v1"
        ok = $false
        infrastructure_valid = $false
        raw_receipt_count = $RawReceiptCount
        structurally_complete_raw_receipt_count = $StructurallyCompleteCount
        final_receipt_count = $FinalReceiptCount
        production_evaluator_invoked = $ProductionEvaluatorInvoked
        production_evaluator_threw = $ProductionEvaluatorThrew
        production_evaluator_ok = $false
        reconstructed_passed_gate_count = 0
        reconstructed_failed_gate_count = 50
        production_selected_candidate_id = $ProductionSelectedCandidateId
        selected_candidate_id = "NONE"
        development_selection_authority = $false
        candidate_selected = $false
        walking_acceptance = $false
        turning_acceptance = $false
        material_robustness = $false
        physical_acceptance_authority = $false
        failure_codes = @($FailureCodes | Sort-Object -Unique)
    }
}

function Invoke-Bw28yActualPathEvaluation {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$RawCells,
        [string]$WorkerStderr = "",
        [string]$CampaignAttemptId = $script:Bw28yPreflightCampaignAttemptId,
        [string]$WorldAttemptIdPrefix = "BW28Y-ZW::"
    )
    $rawCellsArray = @($RawCells)
    if ($WorkerStderr -cmatch "(?m)SCRIPT ERROR") {
        return New-Bw28yActualPathTerminalResult `
            -FailureCodes @("BW28Y_WORKER_SCRIPT_ERROR") `
            -RawReceiptCount $rawCellsArray.Count
    }
    if ($rawCellsArray.Count -ne 28) {
        return New-Bw28yActualPathTerminalResult `
            -FailureCodes @("BW28Y_RAW_RECEIPT_CARDINALITY") `
            -RawReceiptCount $rawCellsArray.Count
    }
    $routeContract = Get-Content -Raw -LiteralPath $script:Bw28yRouteContractPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    $commonKeys = @($routeContract.raw_receipt_contract.required_common_keys)
    $roleKeys = @($routeContract.raw_receipt_contract.required_candidate_and_control_keys)
    $expectedCells = @(Get-Bw28yExpectedCells)
    $rawFailures = [System.Collections.Generic.List[string]]::new()
    $completeCount = 0
    for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
        $raw = $rawCellsArray[$index]
        if ($raw -isnot [System.Collections.IDictionary]) {
            $rawFailures.Add("RAW_RECEIPT_NOT_MAP::$index")
            continue
        }
        $expected = $expectedCells[$index]
        $required = @($commonKeys)
        if ([string]$expected.role -cne "safety") { $required += @($roleKeys) }
        $validation = Get-Bw28yRawReceiptValidation `
            -RawCell $raw `
            -Expected $expected `
            -CampaignAttemptId $CampaignAttemptId `
            -WorldAttemptId ($WorldAttemptIdPrefix + [string]$expected.cell_id) `
            -RequiredKeys $required
        if ([bool]$validation.ok) {
            $completeCount += 1
        } else {
            foreach ($failure in @($validation.failure_codes)) {
                $rawFailures.Add("${failure}::$([string]$expected.cell_id)")
            }
        }
    }
    if ($rawFailures.Count -ne 0) {
        return New-Bw28yActualPathTerminalResult `
            -FailureCodes @($rawFailures) `
            -RawReceiptCount $rawCellsArray.Count `
            -StructurallyCompleteCount $completeCount
    }

    $finalCells = [System.Collections.Generic.List[object]]::new()
    try {
        for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
            $finalCells.Add((ConvertTo-Bw28yFinalCellReceipt `
                -RawCell $rawCellsArray[$index] `
                -Expected $expectedCells[$index]))
        }
    } catch {
        return New-Bw28yActualPathTerminalResult `
            -FailureCodes @("BW28Y_FINAL_COMPOSER_EXCEPTION") `
            -RawReceiptCount 28 `
            -StructurallyCompleteCount 28 `
            -FinalReceiptCount $finalCells.Count
    }
    $result = New-Bw28yPerfectSyntheticYawDevelopmentResult
    $result.cells = @($finalCells)
    $evaluation = $null
    try {
        $evaluation = Invoke-Bw28yYawDevelopmentEvaluation -Result $result
    } catch {
        return New-Bw28yActualPathTerminalResult `
            -FailureCodes @("BW28Y_PRODUCTION_EVALUATOR_EXCEPTION") `
            -RawReceiptCount 28 `
            -StructurallyCompleteCount 28 `
            -FinalReceiptCount 28 `
            -ProductionEvaluatorInvoked $true `
            -ProductionEvaluatorThrew $true
    }
    if (-not [bool]$evaluation.ok) {
        return New-Bw28yActualPathTerminalResult `
            -FailureCodes @($evaluation.failure_codes) `
            -RawReceiptCount 28 `
            -StructurallyCompleteCount 28 `
            -FinalReceiptCount 28 `
            -ProductionEvaluatorInvoked $true `
            -ProductionSelectedCandidateId ([string]$evaluation.selected_candidate_id)
    }
    if ([string]$evaluation.selected_candidate_id -cne "NONE" -or
        [bool]$evaluation.development_selection_authority) {
        return New-Bw28yActualPathTerminalResult `
            -FailureCodes @("BW28Y_SYNTHETIC_SELECTION_AUTHORITY") `
            -RawReceiptCount 28 `
            -StructurallyCompleteCount 28 `
            -FinalReceiptCount 28 `
            -ProductionEvaluatorInvoked $true `
            -ProductionSelectedCandidateId ([string]$evaluation.selected_candidate_id)
    }
    return [ordered]@{
        schema_version = "sporespore_balanced_wave_bw28y_actual_path_evaluation_v1"
        ok = $true
        infrastructure_valid = $true
        raw_receipt_count = 28
        structurally_complete_raw_receipt_count = 28
        final_receipt_count = 28
        production_evaluator_invoked = $true
        production_evaluator_threw = $false
        production_evaluator_ok = $true
        reconstructed_passed_gate_count = [int]$evaluation.reconstructed_passed_gate_count
        reconstructed_failed_gate_count = [int]$evaluation.reconstructed_failed_gate_count
        production_selected_candidate_id = "NONE"
        selected_candidate_id = "NONE"
        development_selection_authority = $false
        candidate_selected = $false
        walking_acceptance = $false
        turning_acceptance = $false
        material_robustness = $false
        physical_acceptance_authority = $false
        failure_codes = @()
        final_cells = @($finalCells)
        production_evaluation = $evaluation
    }
}
