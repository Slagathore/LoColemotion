#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$gatePath = Join-Path $sdkRoot `
    "balanced_wave_bw26i_actual_worker_receipt_route_gate.ps1"
$contractPath = Join-Path $sdkRoot `
    "balanced_wave_bw26i_actual_worker_receipt_route_contract.json"
$workerPath = Join-Path $repoRoot `
    "tests\test_sdk_balanced_wave_bw26i_actual_worker_receipt_route.gd"
$closurePath = Join-Path $sdkRoot `
    "balanced_wave_bw25y_yaw_development_closure.json"
$prefix = "BW26I_ACTUAL_WORKER_RECEIPT_ROUTE "

. $gatePath

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-Bw26iValue {
    param([Parameter(Mandatory)][object]$Value)
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Test-Bw26iFailureCodeLike {
    param(
        [Parameter(Mandatory)][object]$Evaluation,
        [Parameter(Mandatory)][string]$Pattern
    )
    return @($Evaluation.failure_codes | Where-Object { [string]$_ -like $Pattern }).Count -gt 0
}

function Invoke-Bw26iGodotRoute {
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Godot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "--headless",
        "--path", $repoRoot,
        "--script",
        "res://tests/test_sdk_balanced_wave_bw26i_actual_worker_receipt_route.gd"
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-Exact $process.Start() "BW26I failed to start the pinned Godot process"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    return [ordered]@{
        exit_code = $process.ExitCode
        stdout = $stdout
        stderr = $stderr
    }
}

foreach ($path in @($Godot, $gatePath, $contractPath, $workerPath, $closurePath)) {
    Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) `
        "BW26I required file is missing: $path"
}

$contract = Get-Bw26iActualWorkerReceiptRouteContract
$closureHash = (Get-FileHash -LiteralPath $closurePath -Algorithm SHA256).Hash.ToLowerInvariant()
Assert-Exact (
    [string]$contract.schema_version -ceq
        "sporespore_balanced_wave_bw26i_actual_worker_receipt_route_contract_v1" -and
    [string]$contract.status -ceq
        "prospective_zero_world_infrastructure_commissioning_no_physical_authority" -and
    [int]$contract.commissioning_matrix.expected_cell_count -eq 28 -and
    [int]$contract.commissioning_matrix.actual_world_build_count -eq 0 -and
    [string]$contract.predecessor.closure_raw_sha256 -ceq $closureHash -and
    -not [bool]$contract.claim_boundary.physical_world_executed -and
    -not [bool]$contract.claim_boundary.physical_acceptance_authority
) "BW26I contract or immutable BW25Y predecessor binding changed"

$godotRun = Invoke-Bw26iGodotRoute
$combinedWorkerOutput = [string]$godotRun.stdout + [Environment]::NewLine +
    [string]$godotRun.stderr
Assert-Exact ([int]$godotRun.exit_code -eq 0) `
    "BW26I Godot route failed with exit code $($godotRun.exit_code)"
Assert-Exact ($combinedWorkerOutput -cnotmatch "(?m)SCRIPT ERROR") `
    "BW26I perfect route emitted a worker SCRIPT ERROR"
$receiptLines = @(([string]$godotRun.stdout -split "`r?`n") | Where-Object {
    $_.StartsWith($prefix, [System.StringComparison]::Ordinal)
})
Assert-Exact ($receiptLines.Count -eq 1) `
    "BW26I Godot route did not emit exactly one aggregate receipt"
$godotReceipt = $receiptLines[0].Substring($prefix.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [bool]$godotReceipt.ok -and
    [int]$godotReceipt.raw_receipt_count -eq 28 -and
    [int]$godotReceipt.actual_inherited_constructor_call_count -eq 28 -and
    [int]$godotReceipt.candidate_receipt_count -eq 24 -and
    [int]$godotReceipt.control_receipt_count -eq 3 -and
    [int]$godotReceipt.safety_receipt_count -eq 1 -and
    [bool]$godotReceipt.missing_declared_cohort_rejected -and
    [bool]$godotReceipt.negative_walking_raw_receipt_complete -and
    [int]$godotReceipt.actual_world_build_count -eq 0 -and
    [int]$godotReceipt.scene_tree_insertion_count -eq 0 -and
    -not [bool]$godotReceipt.physics_state_modified -and
    -not [bool]$godotReceipt.locomotion_outcome_exposed -and
    -not [bool]$godotReceipt.physical_acceptance_authority
) "BW26I Godot constructor-route receipt failed its declared boundary"

$rawCells = @($godotReceipt.raw_receipts)
$perfect = Invoke-Bw26iActualWorkerReceiptRouteEvaluation `
    -RawCells $rawCells `
    -WorkerStderr ([string]$godotRun.stderr)
Assert-Exact (
    [bool]$perfect.ok -and
    [bool]$perfect.infrastructure_valid -and
    [int]$perfect.raw_receipt_count -eq 28 -and
    [int]$perfect.structurally_complete_raw_receipt_count -eq 28 -and
    [int]$perfect.final_receipt_count -eq 28 -and
    [bool]$perfect.production_evaluator_invoked -and
    -not [bool]$perfect.production_evaluator_threw -and
    [bool]$perfect.production_evaluator_ok -and
    [int]$perfect.reconstructed_passed_gate_count -eq 50 -and
    [int]$perfect.reconstructed_failed_gate_count -eq 0 -and
    -not [bool]$perfect.walking_acceptance -and
    -not [bool]$perfect.material_robustness -and
    -not [bool]$perfect.physical_acceptance_authority
) "BW26I actual route did not pass the exact final composer and 50-gate evaluator"

$missingKeyCells = @(Copy-Bw26iValue $rawCells)
$missingKeyCells[0].Remove("cohort")
$missingKeyCells[0].raw_receipt_complete = $false
$missingKey = Invoke-Bw26iActualWorkerReceiptRouteEvaluation -RawCells $missingKeyCells
Assert-Exact (
    -not [bool]$missingKey.ok -and
    -not [bool]$missingKey.production_evaluator_invoked -and
    (Test-Bw26iFailureCodeLike $missingKey "MISSING_KEY::cohort::*")
) "BW26I missing-required-key canary did not fail before composition"

$forgedCells = @(Copy-Bw26iValue $rawCells)
$forgedCells[0].Remove("cohort")
$forgedCells[0].raw_receipt_complete = $true
$forged = Invoke-Bw26iActualWorkerReceiptRouteEvaluation -RawCells $forgedCells
Assert-Exact (
    -not [bool]$forged.ok -and
    (Test-Bw26iFailureCodeLike $forged "FORGED_RAW_COMPLETENESS::*")
) "BW26I forged-completeness canary did not fail closed"

$scriptError = Invoke-Bw26iActualWorkerReceiptRouteEvaluation `
    -RawCells $rawCells `
    -WorkerStderr "SCRIPT ERROR: synthetic zero-world stderr canary"
Assert-Exact (
    -not [bool]$scriptError.ok -and
    -not [bool]$scriptError.production_evaluator_invoked -and
    (Test-Bw26iFailureCodeLike $scriptError "WORKER_SCRIPT_ERROR::*")
) "BW26I worker SCRIPT ERROR canary did not veto raw completeness"

$wrongAttemptCells = @(Copy-Bw26iValue $rawCells)
$wrongAttemptCells[0].world_attempt_id = "BW26I-ZW::wrong-world"
$wrongAttempt = Invoke-Bw26iActualWorkerReceiptRouteEvaluation `
    -RawCells $wrongAttemptCells
Assert-Exact (
    -not [bool]$wrongAttempt.ok -and
    (Test-Bw26iFailureCodeLike $wrongAttempt "WORLD_ATTEMPT_ID_MISMATCH::*")
) "BW26I world-attempt identity canary did not fail closed"

$negativeCells = @(Copy-Bw26iValue $rawCells)
$negativeCanary = Copy-Bw26iValue $godotReceipt.negative_walking_raw_receipt
$negativeIndex = [array]::FindIndex($negativeCells, [Predicate[object]]{
    param($cell)
    [string]$cell.cell_id -ceq [string]$negativeCanary.cell_id
})
Assert-Exact ($negativeIndex -ge 0) "BW26I negative canary identity is absent"
$negativeCells[$negativeIndex] = $negativeCanary
$negative = Invoke-Bw26iActualWorkerReceiptRouteEvaluation -RawCells $negativeCells
$negativeFinal = @($negative.final_cells | Where-Object {
    [string]$_.cell_id -ceq [string]$negativeCanary.cell_id
}) | Select-Object -First 1
Assert-Exact (
    [bool]$negative.ok -and
    [bool]$negative.infrastructure_valid -and
    -not [bool]$negativeFinal.walking_observed -and
    [int]$negativeFinal.failed_production_walking_gate_count -eq 1 -and
    -not [bool]$negative.walking_acceptance -and
    -not [bool]$negative.physical_acceptance_authority
) "BW26I valid negative walking canary was confused with infrastructure failure"

$noCandidates = @($rawCells | Where-Object { [string]$_.role -cne "candidate" })
$emptyReturned = $false
try {
    $emptyCandidateEvaluation = Invoke-Bw26iActualWorkerReceiptRouteEvaluation `
        -RawCells $noCandidates
    $emptyReturned = $true
} catch {
    $emptyReturned = $false
}
Assert-Exact (
    $emptyReturned -and
    -not [bool]$emptyCandidateEvaluation.ok -and
    -not [bool]$emptyCandidateEvaluation.production_evaluator_invoked -and
    -not [bool]$emptyCandidateEvaluation.production_evaluator_threw -and
    @($emptyCandidateEvaluation.failure_codes) -contains "BW26I_EMPTY_CANDIDATE_MATRIX" -and
    -not [bool]$emptyCandidateEvaluation.physical_acceptance_authority
) "BW26I empty candidate matrix did not return a structured terminal failure"

Write-Host (
    "BW26I_ACTUAL_WORKER_RECEIPT_ROUTE_PASS raw=28 final=28 " +
    "constructors=28 gates=50/50 negative_walking_valid=True " +
    "missing_key=True forged_complete=True script_error_veto=True " +
    "attempt_identity=True empty_matrix_structured=True worlds=0 " +
    "physical_authority=False"
)
