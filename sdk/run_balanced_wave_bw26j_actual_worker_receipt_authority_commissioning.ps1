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
    "balanced_wave_bw26j_actual_worker_receipt_authority_gate.ps1"
$contractPath = Join-Path $sdkRoot `
    "balanced_wave_bw26j_actual_worker_receipt_authority_contract.json"
$workerPath = Join-Path $repoRoot `
    "tests\test_sdk_balanced_wave_bw26j_actual_worker_receipt_authority.gd"
$predecessorClosurePath = Join-Path $sdkRoot `
    "balanced_wave_bw26i_actual_worker_receipt_route_closure.json"
$prefix = "BW26J_ACTUAL_WORKER_RECEIPT_AUTHORITY "

. $gatePath

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Test-Bw26jFailureCodeLike {
    param(
        [Parameter(Mandatory)][object]$Evaluation,
        [Parameter(Mandatory)][string]$Pattern
    )
    return @($Evaluation.failure_codes | Where-Object {
        [string]$_ -like $Pattern
    }).Count -gt 0
}

function Invoke-Bw26jGodotRoute {
    $runRoot = Join-Path $sdkRoot (
        "target\bw26j-zero-world-" + [guid]::NewGuid().ToString("N")
    )
    $appData = Join-Path $runRoot "appdata"
    $localAppData = Join-Path $runRoot "localappdata"
    $logPath = Join-Path $runRoot "godot.log"
    [void][System.IO.Directory]::CreateDirectory($appData)
    [void][System.IO.Directory]::CreateDirectory($localAppData)
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Godot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    foreach ($argument in @(
        "--headless",
        "--path", $repoRoot,
        "--log-file", $logPath,
        "--script",
        "res://tests/test_sdk_balanced_wave_bw26j_actual_worker_receipt_authority.gd"
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-Exact $process.Start() "BW26J failed to start the pinned Godot process"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    return [ordered]@{
        exit_code = $process.ExitCode
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
        log_path = $logPath
        run_root = $runRoot
    }
}

foreach ($path in @(
    $Godot,
    $gatePath,
    $contractPath,
    $workerPath,
    $predecessorClosurePath
)) {
    Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) `
        "BW26J required file is missing: $path"
}

$contract = Get-Bw26jActualWorkerReceiptAuthorityContract
$closureHash = (
    Get-FileHash -LiteralPath $predecessorClosurePath -Algorithm SHA256
).Hash.ToLowerInvariant()
Assert-Exact (
    [string]$contract.schema_version -ceq
        "sporespore_balanced_wave_bw26j_actual_worker_receipt_authority_contract_v1" -and
    [string]$contract.status -ceq
        "prospective_zero_world_authority_firewall_commissioning_no_physical_authority" -and
    [string]$contract.predecessor.closure_raw_sha256 -ceq $closureHash -and
    [int]$contract.commissioning_matrix.expected_cell_count -eq 28 -and
    [int]$contract.commissioning_matrix.actual_world_build_count -eq 0 -and
    [string]$contract.neutral_fixture_contract.candidate_selection_result -ceq "NONE" -and
    -not [bool]$contract.neutral_fixture_contract.development_selection_authority -and
    -not [bool]$contract.claim_boundary.physical_world_executed -and
    -not [bool]$contract.claim_boundary.physical_acceptance_authority
) "BW26J contract or immutable BW26I predecessor binding changed"
foreach ($binding in @($contract.immutable_route_bindings)) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-Exact ($hash -ceq [string]$binding.raw_sha256) `
        "BW26J immutable route binding changed: $([string]$binding.path)"
}
foreach ($claimName in @($contract.claim_boundary.Keys)) {
    Assert-Exact (-not [bool]$contract.claim_boundary[$claimName]) `
        "BW26J claim boundary inflated: $claimName"
}

$godotRun = Invoke-Bw26jGodotRoute
$combinedWorkerOutput = [string]$godotRun.stdout + [Environment]::NewLine +
    [string]$godotRun.stderr
Assert-Exact ([int]$godotRun.exit_code -eq 0) `
    "BW26J Godot route failed with exit code $($godotRun.exit_code); log=$($godotRun.log_path)"
Assert-Exact ($combinedWorkerOutput -cnotmatch "(?m)SCRIPT ERROR") `
    "BW26J perfect route emitted a worker SCRIPT ERROR; log=$($godotRun.log_path)"
$receiptLines = @(([string]$godotRun.stdout -split "`r?`n") | Where-Object {
    $_.StartsWith($prefix, [System.StringComparison]::Ordinal)
})
Assert-Exact ($receiptLines.Count -eq 1) `
    "BW26J Godot route did not emit exactly one aggregate receipt"
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
    [int]$godotReceipt.candidate_overlay_physical_influence_count -eq 24 -and
    [int]$godotReceipt.control_overlay_physical_influence_count -eq 0 -and
    [int]$godotReceipt.control_base_controller_observed_count -eq 3 -and
    [int]$godotReceipt.control_residual_semantics_count -eq 3 -and
    [bool]$godotReceipt.control_overlay_and_base_semantics_exact -and
    [int]$godotReceipt.actual_world_build_count -eq 0 -and
    [int]$godotReceipt.scene_tree_insertion_count -eq 0 -and
    -not [bool]$godotReceipt.physics_state_modified -and
    -not [bool]$godotReceipt.locomotion_outcome_exposed -and
    -not [bool]$godotReceipt.candidate_selected -and
    -not [bool]$godotReceipt.development_selection_authority -and
    -not [bool]$godotReceipt.physical_acceptance_authority
) "BW26J Godot constructor-route receipt failed its declared boundary"

$rawCells = @($godotReceipt.raw_receipts)
$perfect = Invoke-Bw26jActualWorkerReceiptAuthorityEvaluation `
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
    [string]$perfect.selected_candidate_id -ceq "NONE" -and
    -not [bool]$perfect.development_selection_authority -and
    [string]$perfect.production_selected_candidate_id -ceq "NONE" -and
    -not [bool]$perfect.production_development_selection_authority -and
    -not [bool]$perfect.candidate_selected -and
    -not [bool]$perfect.walking_acceptance -and
    -not [bool]$perfect.material_robustness -and
    -not [bool]$perfect.physical_acceptance_authority
) "BW26J neutral route did not pass the exact final composer and 50-gate evaluator"

$missingKeyCells = @(Copy-Bw26jValue $rawCells)
$missingKeyCells[0].Remove("cohort")
$missingKeyCells[0].raw_receipt_complete = $false
$missingKey = Invoke-Bw26jActualWorkerReceiptAuthorityEvaluation `
    -RawCells $missingKeyCells
Assert-Exact (
    -not [bool]$missingKey.ok -and
    -not [bool]$missingKey.production_evaluator_invoked -and
    (Test-Bw26jFailureCodeLike $missingKey "MISSING_KEY::cohort::*")
) "BW26J missing-required-key canary did not fail before composition"

$forgedCells = @(Copy-Bw26jValue $rawCells)
$forgedCells[0].Remove("cohort")
$forgedCells[0].raw_receipt_complete = $true
$forged = Invoke-Bw26jActualWorkerReceiptAuthorityEvaluation -RawCells $forgedCells
Assert-Exact (
    -not [bool]$forged.ok -and
    (Test-Bw26jFailureCodeLike $forged "FORGED_RAW_COMPLETENESS::*")
) "BW26J forged-completeness canary did not fail closed"

$scriptError = Invoke-Bw26jActualWorkerReceiptAuthorityEvaluation `
    -RawCells $rawCells `
    -WorkerStderr "SCRIPT ERROR: synthetic zero-world stderr canary"
Assert-Exact (
    -not [bool]$scriptError.ok -and
    -not [bool]$scriptError.production_evaluator_invoked -and
    (Test-Bw26jFailureCodeLike $scriptError "WORKER_SCRIPT_ERROR::*")
) "BW26J worker SCRIPT ERROR canary did not veto raw completeness"

$wrongAttemptCells = @(Copy-Bw26jValue $rawCells)
$wrongAttemptCells[0].world_attempt_id = "BW26J-ZW::wrong-world"
$wrongAttempt = Invoke-Bw26jActualWorkerReceiptAuthorityEvaluation `
    -RawCells $wrongAttemptCells
Assert-Exact (
    -not [bool]$wrongAttempt.ok -and
    (Test-Bw26jFailureCodeLike $wrongAttempt "WORLD_ATTEMPT_ID_MISMATCH::*")
) "BW26J world-attempt identity canary did not fail closed"

$negativeCells = @(Copy-Bw26jValue $rawCells)
$negativeCanary = Copy-Bw26jValue $godotReceipt.negative_walking_raw_receipt
$negativeIndex = [array]::FindIndex($negativeCells, [Predicate[object]]{
    param($cell)
    [string]$cell.cell_id -ceq [string]$negativeCanary.cell_id
})
Assert-Exact ($negativeIndex -ge 0) "BW26J negative canary identity is absent"
$negativeCells[$negativeIndex] = $negativeCanary
$negative = Invoke-Bw26jActualWorkerReceiptAuthorityEvaluation -RawCells $negativeCells
$negativeFinal = @($negative.final_cells | Where-Object {
    [string]$_.cell_id -ceq [string]$negativeCanary.cell_id
}) | Select-Object -First 1
Assert-Exact (
    [bool]$negative.ok -and
    [bool]$negative.infrastructure_valid -and
    -not [bool]$negativeFinal.walking_observed -and
    [int]$negativeFinal.failed_production_walking_gate_count -eq 1 -and
    [string]$negative.selected_candidate_id -ceq "NONE" -and
    -not [bool]$negative.development_selection_authority -and
    -not [bool]$negative.walking_acceptance -and
    -not [bool]$negative.physical_acceptance_authority
) "BW26J valid negative walking canary was confused with infrastructure failure"

$selectionCells = @(Copy-Bw26jValue $rawCells)
foreach ($cell in @($selectionCells | Where-Object {
    [string]$_.role -ceq "candidate" -and
    [string]$_.candidate_id -ceq "BW25Y-A"
})) {
    $cell.walking_gate_receipts.bounded_lateral_drift = $false
}
$selectionLeak = Invoke-Bw26jActualWorkerReceiptAuthorityEvaluation `
    -RawCells $selectionCells
Assert-Exact (
    -not [bool]$selectionLeak.ok -and
    -not [bool]$selectionLeak.infrastructure_valid -and
    [bool]$selectionLeak.production_evaluator_invoked -and
    [bool]$selectionLeak.production_evaluator_ok -and
    [string]$selectionLeak.production_selected_candidate_id -ceq "BW25Y-B" -and
    [bool]$selectionLeak.production_development_selection_authority -and
    [string]$selectionLeak.selected_candidate_id -ceq "NONE" -and
    -not [bool]$selectionLeak.development_selection_authority -and
    -not [bool]$selectionLeak.candidate_selected -and
    @($selectionLeak.failure_codes) -contains "BW26J_SYNTHETIC_SELECTION_AUTHORITY" -and
    -not [bool]$selectionLeak.physical_acceptance_authority
) "BW26J synthetic selection-authority firewall did not fail closed"

$noCandidates = @($rawCells | Where-Object { [string]$_.role -cne "candidate" })
$emptyReturned = $false
try {
    $emptyCandidateEvaluation = Invoke-Bw26jActualWorkerReceiptAuthorityEvaluation `
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
    @($emptyCandidateEvaluation.failure_codes) -contains "BW26J_EMPTY_CANDIDATE_MATRIX" -and
    -not [bool]$emptyCandidateEvaluation.physical_acceptance_authority
) "BW26J empty candidate matrix did not return a structured terminal failure"

Write-Host (
    "BW26J_ACTUAL_WORKER_RECEIPT_AUTHORITY_PASS raw=28 final=28 " +
    "constructors=28 gates=50/50 selected=NONE authority=False " +
    "negative_walking_valid=True missing_key=True forged_complete=True " +
    "script_error_veto=True attempt_identity=True empty_matrix_structured=True " +
    "selection_authority_veto=True control_overlay_semantics=True worlds=0 " +
    "physical_authority=False"
)
