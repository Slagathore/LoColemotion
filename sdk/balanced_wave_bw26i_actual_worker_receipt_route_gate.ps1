#requires -Version 7.0

Set-StrictMode -Version Latest

$script:Bw26iCampaignId = "BW26I-ACTUAL-WORKER-RECEIPT-ROUTE-COMMISSIONING"
$script:Bw26iGateId = "BW26I"
$script:Bw26iCampaignAttemptId = "BW26I-ZERO-WORLD-COMMISSIONING"
$script:Bw26iRouteSchema = "sporespore_actual_worker_receipt_route_v1"
$script:Bw26iContractPath = Join-Path (
    [System.IO.Path]::GetFullPath($PSScriptRoot)
) "balanced_wave_bw26i_actual_worker_receipt_route_contract.json"
$script:Bw25yGatePath = Join-Path (
    [System.IO.Path]::GetFullPath($PSScriptRoot)
) "balanced_wave_bw25y_yaw_development_gate.ps1"

. $script:Bw25yGatePath

function Get-Bw26iActualWorkerReceiptRouteContract {
    return Get-Content -Raw -LiteralPath $script:Bw26iContractPath |
        ConvertFrom-Json -AsHashtable -Depth 64
}

function New-Bw26iActualWorkerReceiptRouteTerminalFailure {
    param(
        [Parameter(Mandatory)][string[]]$FailureCodes,
        [int]$RawReceiptCount = 0,
        [int]$StructurallyCompleteRawReceiptCount = 0,
        [bool]$ProductionEvaluatorInvoked = $false,
        [bool]$ProductionEvaluatorThrew = $false
    )
    return [ordered]@{
        schema_version =
            "sporespore_balanced_wave_bw26i_actual_worker_receipt_route_evaluation_v1"
        ok = $false
        campaign_id = $script:Bw26iCampaignId
        gate_id = $script:Bw26iGateId
        infrastructure_valid = $false
        raw_receipt_count = $RawReceiptCount
        structurally_complete_raw_receipt_count =
            $StructurallyCompleteRawReceiptCount
        final_receipt_count = 0
        production_evaluator_invoked = $ProductionEvaluatorInvoked
        production_evaluator_threw = $ProductionEvaluatorThrew
        production_evaluator_ok = $false
        reconstructed_passed_gate_count = 0
        reconstructed_failed_gate_count = 50
        failure_codes = @($FailureCodes | Sort-Object -Unique)
        walking_acceptance = $false
        turning_acceptance = $false
        material_robustness = $false
        candidate_selected = $false
        validation_authority = $false
        physical_acceptance_authority = $false
    }
}

function Test-Bw26iActualWorkerRawReceipt {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$RawCell,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Expected,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Contract,
        [Parameter(Mandatory)][string]$CampaignAttemptId,
        [AllowEmptyString()][string]$WorkerStderr = ""
    )

    $failures = [System.Collections.Generic.List[string]]::new()
    $rawContract = $Contract.raw_receipt_contract
    $requiredKeys = @($rawContract.required_common_keys)
    if ([string]$Expected.role -cin @("candidate", "control")) {
        $requiredKeys += @($rawContract.required_candidate_and_control_keys)
    }
    $requiredKeys = @($requiredKeys | Select-Object -Unique)
    foreach ($keyValue in $requiredKeys) {
        $key = [string]$keyValue
        if (-not $RawCell.Contains($key)) {
            $failures.Add("MISSING_KEY::$key")
        }
    }

    if ($WorkerStderr -cmatch "(?m)SCRIPT ERROR") {
        $failures.Add("WORKER_SCRIPT_ERROR")
    }
    if ([string](Get-Bw25yMapValue $RawCell "receipt_route_schema" "") -cne
        $script:Bw26iRouteSchema) {
        $failures.Add("ROUTE_SCHEMA_MISMATCH")
    }
    if (@((Get-Bw25yMapValue $RawCell "receipt_route_failure_codes" @())).Count -ne 0) {
        $failures.Add("ROUTE_REPORTED_FAILURE")
    }
    if ([string](Get-Bw25yMapValue $RawCell "cell_id" "") -cne
        [string]$Expected.cell_id) {
        $failures.Add("CELL_ID_MISMATCH")
    }
    if ([string](Get-Bw25yMapValue $RawCell "role" "") -cne
        [string]$Expected.role) {
        $failures.Add("ROLE_MISMATCH")
    }
    $expectedCohort = "bw26i_$([string]$Expected.role)_route_fixture"
    if ([string](Get-Bw25yMapValue $RawCell "cohort" "") -cne $expectedCohort) {
        $failures.Add("COHORT_MISMATCH")
    }
    if ([int](Get-Bw25yMapValue $RawCell "campaign_seed" -1) -ne
        [int]$Expected.campaign_seed) {
        $failures.Add("CAMPAIGN_SEED_MISMATCH")
    }
    if ([string](Get-Bw25yMapValue $RawCell "campaign_attempt_id" "") -cne
        $CampaignAttemptId) {
        $failures.Add("CAMPAIGN_ATTEMPT_ID_MISMATCH")
    }
    $expectedWorldAttemptId = "BW26I-ZW::$([string]$Expected.cell_id)"
    if ([string](Get-Bw25yMapValue $RawCell "world_attempt_id" "") -cne
        $expectedWorldAttemptId) {
        $failures.Add("WORLD_ATTEMPT_ID_MISMATCH")
    }
    if ((Get-Bw25yMapValue $RawCell "walking_gate_receipts" $null) -isnot
        [System.Collections.IDictionary]) {
        $failures.Add("WALKING_RECEIPT_NOT_DICTIONARY")
    }
    if ((Get-Bw25yMapValue $RawCell "walking_result_controls_process_exit" $null) -isnot
        [bool] -or
        [bool](Get-Bw25yMapValue $RawCell "walking_result_controls_process_exit" $true)) {
        $failures.Add("WALKING_RESULT_CONTROLLED_PROCESS_EXIT")
    }
    if ((Get-Bw25yMapValue $RawCell "physical_acceptance_authority" $null) -isnot
        [bool] -or
        [bool](Get-Bw25yMapValue $RawCell "physical_acceptance_authority" $true)) {
        $failures.Add("RAW_PHYSICAL_AUTHORITY_INFLATION")
    }

    $computedComplete = $failures.Count -eq 0
    $declaredCompleteIsBoolean = (
        (Get-Bw25yMapValue $RawCell "raw_receipt_complete" $null) -is [bool]
    )
    $declaredComplete = if ($declaredCompleteIsBoolean) {
        [bool]$RawCell.raw_receipt_complete
    } else { $false }
    if (-not $declaredCompleteIsBoolean) {
        $failures.Add("RAW_COMPLETENESS_FLAG_NOT_BOOLEAN")
    } elseif ($declaredComplete -ne $computedComplete) {
        $failures.Add($(if ($declaredComplete) {
            "FORGED_RAW_COMPLETENESS"
        } else {
            "FALSE_RAW_INCOMPLETENESS"
        }))
    }

    return [ordered]@{
        schema_version = "sporespore_bw26i_raw_receipt_validation_v1"
        ok = $failures.Count -eq 0
        computed_raw_receipt_complete = $computedComplete
        declared_raw_receipt_complete = $declaredComplete
        required_key_count = $requiredKeys.Count
        failure_codes = @($failures | Sort-Object -Unique)
        physical_acceptance_authority = $false
    }
}

function Invoke-Bw26iActualWorkerReceiptRouteEvaluation {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$RawCells,
        [AllowEmptyString()][string]$WorkerStderr = "",
        [string]$CampaignAttemptId = $script:Bw26iCampaignAttemptId
    )

    $contract = Get-Bw26iActualWorkerReceiptRouteContract
    $expectedCells = @(Get-Bw25yExpectedCells)
    $candidateRawCells = @($RawCells | Where-Object {
        $_ -is [System.Collections.IDictionary] -and
        [string](Get-Bw25yMapValue $_ "role" "") -ceq "candidate"
    })
    if ($candidateRawCells.Count -eq 0) {
        return New-Bw26iActualWorkerReceiptRouteTerminalFailure `
            -FailureCodes @("BW26I_EMPTY_CANDIDATE_MATRIX") `
            -RawReceiptCount $RawCells.Count
    }
    if ($RawCells.Count -ne $expectedCells.Count) {
        return New-Bw26iActualWorkerReceiptRouteTerminalFailure `
            -FailureCodes @("BW26I_RAW_MATRIX_CARDINALITY") `
            -RawReceiptCount $RawCells.Count
    }

    $rawFailures = [System.Collections.Generic.List[string]]::new()
    $rawValidations = [System.Collections.Generic.List[object]]::new()
    $structurallyCompleteCount = 0
    for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
        $rawCell = $RawCells[$index]
        if ($rawCell -isnot [System.Collections.IDictionary]) {
            $rawFailures.Add("RAW_CELL_NOT_DICTIONARY::$index")
            continue
        }
        $validation = Test-Bw26iActualWorkerRawReceipt `
            -RawCell $rawCell `
            -Expected $expectedCells[$index] `
            -Contract $contract `
            -CampaignAttemptId $CampaignAttemptId `
            -WorkerStderr $WorkerStderr
        $rawValidations.Add($validation)
        if ([bool]$validation.computed_raw_receipt_complete) {
            $structurallyCompleteCount += 1
        }
        if (-not [bool]$validation.ok) {
            foreach ($failureCode in @($validation.failure_codes)) {
                $rawFailures.Add("$failureCode::$index")
            }
        }
    }
    if ($rawFailures.Count -ne 0) {
        return New-Bw26iActualWorkerReceiptRouteTerminalFailure `
            -FailureCodes @($rawFailures) `
            -RawReceiptCount $RawCells.Count `
            -StructurallyCompleteRawReceiptCount $structurallyCompleteCount
    }

    $finalCells = [System.Collections.Generic.List[object]]::new()
    try {
        for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
            $finalCells.Add((ConvertTo-Bw25yFinalCellReceipt `
                -RawCell $RawCells[$index] `
                -Expected $expectedCells[$index]))
        }
    } catch {
        return New-Bw26iActualWorkerReceiptRouteTerminalFailure `
            -FailureCodes @("BW26I_FINAL_COMPOSITION_EXCEPTION") `
            -RawReceiptCount $RawCells.Count `
            -StructurallyCompleteRawReceiptCount $structurallyCompleteCount
    }

    $productionInput = New-Bw25yPerfectSyntheticYawDevelopmentResult
    $productionInput.cells = @($finalCells)
    $productionInput.observed_world_count = 28
    try {
        $productionEvaluation = Invoke-Bw25yYawDevelopmentEvaluation `
            -Result $productionInput
    } catch {
        return New-Bw26iActualWorkerReceiptRouteTerminalFailure `
            -FailureCodes @("BW26I_PRODUCTION_EVALUATOR_EXCEPTION") `
            -RawReceiptCount $RawCells.Count `
            -StructurallyCompleteRawReceiptCount $structurallyCompleteCount `
            -ProductionEvaluatorInvoked $true `
            -ProductionEvaluatorThrew $true
    }
    if (-not [bool]$productionEvaluation.ok) {
        return New-Bw26iActualWorkerReceiptRouteTerminalFailure `
            -FailureCodes @(
                "BW26I_PRODUCTION_EVALUATOR_REJECTED",
                @($productionEvaluation.failure_codes)
            ) `
            -RawReceiptCount $RawCells.Count `
            -StructurallyCompleteRawReceiptCount $structurallyCompleteCount `
            -ProductionEvaluatorInvoked $true
    }

    return [ordered]@{
        schema_version =
            "sporespore_balanced_wave_bw26i_actual_worker_receipt_route_evaluation_v1"
        ok = $true
        campaign_id = $script:Bw26iCampaignId
        gate_id = $script:Bw26iGateId
        infrastructure_valid = $true
        raw_receipt_count = $RawCells.Count
        structurally_complete_raw_receipt_count = $structurallyCompleteCount
        final_receipt_count = $finalCells.Count
        candidate_count = $candidateRawCells.Count
        control_count = @($RawCells | Where-Object role -CEQ "control").Count
        safety_count = @($RawCells | Where-Object role -CEQ "safety").Count
        production_evaluator_invoked = $true
        production_evaluator_threw = $false
        production_evaluator_ok = $true
        reconstructed_passed_gate_count =
            [int]$productionEvaluation.reconstructed_passed_gate_count
        reconstructed_failed_gate_count =
            [int]$productionEvaluation.reconstructed_failed_gate_count
        selected_candidate_id = [string]$productionEvaluation.selected_candidate_id
        development_selection_authority =
            [bool]$productionEvaluation.development_selection_authority
        final_cells = @($finalCells)
        raw_validations = @($rawValidations)
        production_evaluation = $productionEvaluation
        failure_codes = @()
        walking_acceptance = $false
        turning_acceptance = $false
        material_robustness = $false
        candidate_selected = $false
        validation_authority = $false
        physical_acceptance_authority = $false
    }
}
