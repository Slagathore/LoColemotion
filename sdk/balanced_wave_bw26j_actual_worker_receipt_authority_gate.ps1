#requires -Version 7.0

Set-StrictMode -Version Latest

$script:Bw26jCampaignId = "BW26J-ACTUAL-WORKER-RECEIPT-AUTHORITY-COMMISSIONING"
$script:Bw26jGateId = "BW26J"
$script:Bw26jCampaignAttemptId = "BW26J-ZERO-WORLD-AUTHORITY-COMMISSIONING"
$script:Bw26jContractPath = Join-Path (
    [System.IO.Path]::GetFullPath($PSScriptRoot)
) "balanced_wave_bw26j_actual_worker_receipt_authority_contract.json"
$script:Bw26iGatePath = Join-Path (
    [System.IO.Path]::GetFullPath($PSScriptRoot)
) "balanced_wave_bw26i_actual_worker_receipt_route_gate.ps1"

. $script:Bw26iGatePath

function Get-Bw26jActualWorkerReceiptAuthorityContract {
    return Get-Content -Raw -LiteralPath $script:Bw26jContractPath |
        ConvertFrom-Json -AsHashtable -Depth 64
}

function Copy-Bw26jValue {
    param([Parameter(Mandatory)][object]$Value)
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function New-Bw26jActualWorkerReceiptAuthorityTerminalFailure {
    param(
        [Parameter(Mandatory)][string[]]$FailureCodes,
        [int]$RawReceiptCount = 0,
        [int]$StructurallyCompleteRawReceiptCount = 0,
        [bool]$ProductionEvaluatorInvoked = $false,
        [bool]$ProductionEvaluatorThrew = $false,
        [object[]]$FinalCells = @(),
        [object]$ProductionEvaluation = $null
    )
    $productionSelected = if ($null -ne $ProductionEvaluation) {
        [string](Get-Bw25yMapValue $ProductionEvaluation "selected_candidate_id" "NONE")
    } else { "NONE" }
    $productionAuthority = if ($null -ne $ProductionEvaluation) {
        [bool](Get-Bw25yMapValue $ProductionEvaluation "development_selection_authority" $false)
    } else { $false }
    return [ordered]@{
        schema_version =
            "sporespore_balanced_wave_bw26j_actual_worker_receipt_authority_evaluation_v1"
        ok = $false
        campaign_id = $script:Bw26jCampaignId
        gate_id = $script:Bw26jGateId
        infrastructure_valid = $false
        raw_receipt_count = $RawReceiptCount
        structurally_complete_raw_receipt_count = $StructurallyCompleteRawReceiptCount
        final_receipt_count = $FinalCells.Count
        production_evaluator_invoked = $ProductionEvaluatorInvoked
        production_evaluator_threw = $ProductionEvaluatorThrew
        production_evaluator_ok = if ($null -ne $ProductionEvaluation) {
            [bool](Get-Bw25yMapValue $ProductionEvaluation "ok" $false)
        } else { $false }
        reconstructed_passed_gate_count = if ($null -ne $ProductionEvaluation) {
            [int](Get-Bw25yMapValue $ProductionEvaluation "reconstructed_passed_gate_count" 0)
        } else { 0 }
        reconstructed_failed_gate_count = if ($null -ne $ProductionEvaluation) {
            [int](Get-Bw25yMapValue $ProductionEvaluation "reconstructed_failed_gate_count" 50)
        } else { 50 }
        selected_candidate_id = "NONE"
        development_selection_authority = $false
        production_selected_candidate_id = $productionSelected
        production_development_selection_authority = $productionAuthority
        final_cells = @($FinalCells)
        production_evaluation = $ProductionEvaluation
        failure_codes = @($FailureCodes | Sort-Object -Unique)
        walking_acceptance = $false
        turning_acceptance = $false
        material_robustness = $false
        candidate_selected = $false
        validation_authority = $false
        physical_acceptance_authority = $false
    }
}

function Test-Bw26jActualWorkerRawReceipt {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$RawCell,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Expected,
        [Parameter(Mandatory)][System.Collections.IDictionary]$PredecessorContract,
        [Parameter(Mandatory)][string]$CampaignAttemptId,
        [AllowEmptyString()][string]$WorkerStderr = ""
    )
    $failures = [System.Collections.Generic.List[string]]::new()
    $rawContract = $PredecessorContract.raw_receipt_contract
    $requiredKeys = @($rawContract.required_common_keys)
    if ([string]$Expected.role -cin @("candidate", "control")) {
        $requiredKeys += @($rawContract.required_candidate_and_control_keys)
    }
    $requiredKeys = @($requiredKeys | Select-Object -Unique)
    foreach ($keyValue in $requiredKeys) {
        $key = [string]$keyValue
        if (-not $RawCell.Contains($key)) { $failures.Add("MISSING_KEY::$key") }
    }

    $expectedCohort = "bw26j_$([string]$Expected.role)_route_fixture"
    if ([string](Get-Bw25yMapValue $RawCell "cohort" "") -cne $expectedCohort) {
        $failures.Add("COHORT_MISMATCH")
    }
    if ([string](Get-Bw25yMapValue $RawCell "campaign_attempt_id" "") -cne
        $CampaignAttemptId) {
        $failures.Add("CAMPAIGN_ATTEMPT_ID_MISMATCH")
    }
    $expectedWorldAttemptId = "BW26J-ZW::$([string]$Expected.cell_id)"
    if ([string](Get-Bw25yMapValue $RawCell "world_attempt_id" "") -cne
        $expectedWorldAttemptId) {
        $failures.Add("WORLD_ATTEMPT_ID_MISMATCH")
    }

    # Reuse the immutable BW26I structural validator only after explicitly
    # validating BW26J's own identity. Normalization is validation plumbing; it
    # is never passed to the final composer or production evaluator.
    $normalized = Copy-Bw26jValue $RawCell
    $normalized["cohort"] = "bw26i_$([string]$Expected.role)_route_fixture"
    $normalized["campaign_attempt_id"] = $script:Bw26iCampaignAttemptId
    $normalized["world_attempt_id"] = "BW26I-ZW::$([string]$Expected.cell_id)"
    $predecessorValidation = Test-Bw26iActualWorkerRawReceipt `
        -RawCell $normalized `
        -Expected $Expected `
        -Contract $PredecessorContract `
        -CampaignAttemptId $script:Bw26iCampaignAttemptId `
        -WorkerStderr $WorkerStderr
    foreach ($failureCode in @($predecessorValidation.failure_codes)) {
        if ([string]$failureCode -notin @(
            "FORGED_RAW_COMPLETENESS",
            "FALSE_RAW_INCOMPLETENESS"
        )) {
            $failures.Add([string]$failureCode)
        }
    }

    $computedComplete = $failures.Count -eq 0
    $declaredValue = Get-Bw25yMapValue $RawCell "raw_receipt_complete" $null
    $declaredIsBoolean = $declaredValue -is [bool]
    $declaredComplete = if ($declaredIsBoolean) { [bool]$declaredValue } else { $false }
    if (-not $declaredIsBoolean) {
        $failures.Add("RAW_COMPLETENESS_FLAG_NOT_BOOLEAN")
    } elseif ($declaredComplete -ne $computedComplete) {
        $failures.Add($(if ($declaredComplete) {
            "FORGED_RAW_COMPLETENESS"
        } else {
            "FALSE_RAW_INCOMPLETENESS"
        }))
    }

    return [ordered]@{
        schema_version = "sporespore_bw26j_raw_receipt_validation_v1"
        ok = $failures.Count -eq 0
        computed_raw_receipt_complete = $computedComplete
        declared_raw_receipt_complete = $declaredComplete
        required_key_count = $requiredKeys.Count
        failure_codes = @($failures | Sort-Object -Unique)
        predecessor_validation = $predecessorValidation
        physical_acceptance_authority = $false
    }
}

function Invoke-Bw26jActualWorkerReceiptAuthorityEvaluation {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$RawCells,
        [AllowEmptyString()][string]$WorkerStderr = "",
        [string]$CampaignAttemptId = $script:Bw26jCampaignAttemptId
    )
    $contract = Get-Bw26jActualWorkerReceiptAuthorityContract
    $predecessorContract = Get-Bw26iActualWorkerReceiptRouteContract
    $expectedCells = @(Get-Bw25yExpectedCells)
    $candidateRawCells = @($RawCells | Where-Object {
        $_ -is [System.Collections.IDictionary] -and
        [string](Get-Bw25yMapValue $_ "role" "") -ceq "candidate"
    })
    if ($candidateRawCells.Count -eq 0) {
        return New-Bw26jActualWorkerReceiptAuthorityTerminalFailure `
            -FailureCodes @("BW26J_EMPTY_CANDIDATE_MATRIX") `
            -RawReceiptCount $RawCells.Count
    }
    if ($RawCells.Count -ne $expectedCells.Count) {
        return New-Bw26jActualWorkerReceiptAuthorityTerminalFailure `
            -FailureCodes @("BW26J_RAW_MATRIX_CARDINALITY") `
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
        $validation = Test-Bw26jActualWorkerRawReceipt `
            -RawCell $rawCell `
            -Expected $expectedCells[$index] `
            -PredecessorContract $predecessorContract `
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
        return New-Bw26jActualWorkerReceiptAuthorityTerminalFailure `
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
        return New-Bw26jActualWorkerReceiptAuthorityTerminalFailure `
            -FailureCodes @("BW26J_FINAL_COMPOSITION_EXCEPTION") `
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
        return New-Bw26jActualWorkerReceiptAuthorityTerminalFailure `
            -FailureCodes @("BW26J_PRODUCTION_EVALUATOR_EXCEPTION") `
            -RawReceiptCount $RawCells.Count `
            -StructurallyCompleteRawReceiptCount $structurallyCompleteCount `
            -ProductionEvaluatorInvoked $true `
            -ProductionEvaluatorThrew $true `
            -FinalCells @($finalCells)
    }
    if (-not [bool]$productionEvaluation.ok) {
        return New-Bw26jActualWorkerReceiptAuthorityTerminalFailure `
            -FailureCodes @(
                "BW26J_PRODUCTION_EVALUATOR_REJECTED",
                @($productionEvaluation.failure_codes)
            ) `
            -RawReceiptCount $RawCells.Count `
            -StructurallyCompleteRawReceiptCount $structurallyCompleteCount `
            -ProductionEvaluatorInvoked $true `
            -FinalCells @($finalCells) `
            -ProductionEvaluation $productionEvaluation
    }

    $productionSelected = [string]$productionEvaluation.selected_candidate_id
    $productionAuthority = [bool]$productionEvaluation.development_selection_authority
    if ($productionSelected -cne "NONE" -or $productionAuthority) {
        return New-Bw26jActualWorkerReceiptAuthorityTerminalFailure `
            -FailureCodes @("BW26J_SYNTHETIC_SELECTION_AUTHORITY") `
            -RawReceiptCount $RawCells.Count `
            -StructurallyCompleteRawReceiptCount $structurallyCompleteCount `
            -ProductionEvaluatorInvoked $true `
            -FinalCells @($finalCells) `
            -ProductionEvaluation $productionEvaluation
    }

    return [ordered]@{
        schema_version =
            "sporespore_balanced_wave_bw26j_actual_worker_receipt_authority_evaluation_v1"
        ok = $true
        campaign_id = $script:Bw26jCampaignId
        gate_id = $script:Bw26jGateId
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
        selected_candidate_id = "NONE"
        development_selection_authority = $false
        production_selected_candidate_id = $productionSelected
        production_development_selection_authority = $productionAuthority
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
