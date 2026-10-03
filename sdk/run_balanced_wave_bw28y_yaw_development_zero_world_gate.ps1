[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipGodotActualPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$gatePath = Join-Path $sdkRoot "balanced_wave_bw28y_yaw_development_gate.ps1"
$actualPathGate = Join-Path $sdkRoot "balanced_wave_bw28y_actual_path_gate.ps1"
$actualPathTest = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw28y_actual_receipt_path.gd"
$expectedGodotSha256 =
    "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
$actualPrefix = "BW28Y_ACTUAL_RECEIPT_PATH "

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-Deep {
    param([Parameter(Mandatory)][object]$Value)
    return $Value | ConvertTo-Json -Depth 80 |
        ConvertFrom-Json -AsHashtable -Depth 80
}

function Assert-EvaluationFailure {
    param(
        [Parameter(Mandatory)][object]$Result,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $evaluation = Invoke-Bw28yYawDevelopmentEvaluation -Result $Result
    Assert-Exact (
        -not [bool]$evaluation.ok -and
        @($evaluation.failure_codes) -ccontains $FailureCode
    ) "BW28Y canary failed open: $Label"
}

Assert-Exact (Test-Path -LiteralPath $gatePath -PathType Leaf) `
    "BW28Y production gate is missing"
Assert-Exact (Test-Path -LiteralPath $actualPathGate -PathType Leaf) `
    "BW28Y actual-path authority gate is missing"
. $gatePath
. $actualPathGate

$expectedCells = @(Get-Bw28yExpectedCells)
Assert-Exact ($expectedCells.Count -eq 28) `
    "BW28Y production gate did not reconstruct 28 cells"

$perfect = New-Bw28yPerfectSyntheticYawDevelopmentResult
$perfectEvaluation = Invoke-Bw28yYawDevelopmentEvaluation -Result $perfect
Assert-Exact (
    [bool]$perfectEvaluation.ok -and
    [int]$perfectEvaluation.reconstructed_passed_gate_count -eq 50 -and
    [int]$perfectEvaluation.reconstructed_failed_gate_count -eq 0 -and
    [string]$perfectEvaluation.selected_candidate_id -ceq "NONE" -and
    -not [bool]$perfectEvaluation.development_selection_authority -and
    -not [bool]$perfectEvaluation.physical_acceptance_authority
) "BW28Y neutral perfect production result did not pass 50/50 and select NONE"

$actualAggregate = $null
$actualPathOutput = ""
$composedResult = Copy-Deep $perfect
$actualConstructorCount = 0
$actualComposerCount = 0
if (-not $SkipGodotActualPath) {
    $godotPath = [System.IO.Path]::GetFullPath($Godot)
    Assert-Exact (
        (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
        (Get-FileHash -LiteralPath $godotPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq
            $expectedGodotSha256
    ) "BW28Y pinned Godot executable is missing or changed: $godotPath"
    Assert-Exact (Test-Path -LiteralPath $actualPathTest -PathType Leaf) `
        "BW28Y actual receipt-path Godot test is missing"

    $actualPathOutput = (& $godotPath `
        --headless `
        --path $repoRoot `
        --script res://tests/test_sdk_balanced_wave_bw28y_actual_receipt_path.gd `
        2>&1 | Out-String)
    $godotExitCode = $LASTEXITCODE
    # The aggregate marker carries all 28 real-shaped synthetic receipts and is
    # parsed below. Keep it out of routine console output so conformance remains
    # readable while the complete in-memory receipt still reaches every gate.
    $humanOutput = @($actualPathOutput -split "\r?\n" | Where-Object {
        -not ([string]$_).StartsWith($actualPrefix, [StringComparison]::Ordinal)
    }) -join [Environment]::NewLine
    if (-not [string]::IsNullOrWhiteSpace($humanOutput)) {
        Write-Host $humanOutput.TrimEnd()
    }
    Assert-Exact (
        $godotExitCode -eq 0 -and
        -not [regex]::IsMatch(
            $actualPathOutput,
            '(?im)^\s*(?:ERROR:|SCRIPT ERROR:)'
        )
    ) "BW28Y actual receipt-path Godot process failed with exit code $godotExitCode"
    $match = [regex]::Match(
        $actualPathOutput,
        '(?m)^BW28Y_ACTUAL_RECEIPT_PATH (?<json>\{.*\})\r?$'
    )
    Assert-Exact $match.Success "BW28Y actual receipt-path JSON marker is missing"
    $actualAggregate = $match.Groups['json'].Value |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-Exact (
        [bool]$actualAggregate.ok -and
        [int]$actualAggregate.raw_receipt_count -eq 28 -and
        [int]$actualAggregate.candidate_receipt_count -eq 24 -and
        [int]$actualAggregate.control_receipt_count -eq 3 -and
        [int]$actualAggregate.safety_receipt_count -eq 1 -and
        [int]$actualAggregate.actual_inherited_constructor_call_count -eq 28 -and
        [bool]$actualAggregate.missing_declared_cohort_rejected -and
        [bool]$actualAggregate.negative_walking_raw_receipt_complete -and
        [bool]$actualAggregate.control_overlay_and_base_semantics_exact -and
        [int]$actualAggregate.actual_world_build_count -eq 0 -and
        [int]$actualAggregate.scene_tree_insertion_count -eq 0 -and
        -not [bool]$actualAggregate.physics_state_modified -and
        -not [bool]$actualAggregate.locomotion_outcome_exposed -and
        -not [bool]$actualAggregate.physical_acceptance_authority
    ) "BW28Y actual inherited receipt-path aggregate failed closed"

    $rawReceipts = @($actualAggregate.raw_receipts)
    $actualPathEvaluation = Invoke-Bw28yActualPathEvaluation `
        -RawCells $rawReceipts `
        -WorkerStderr $actualPathOutput
    Assert-Exact (
        [bool]$actualPathEvaluation.ok -and
        [bool]$actualPathEvaluation.infrastructure_valid -and
        [int]$actualPathEvaluation.raw_receipt_count -eq 28 -and
        [int]$actualPathEvaluation.structurally_complete_raw_receipt_count -eq 28 -and
        [int]$actualPathEvaluation.final_receipt_count -eq 28 -and
        [bool]$actualPathEvaluation.production_evaluator_invoked -and
        -not [bool]$actualPathEvaluation.production_evaluator_threw -and
        [bool]$actualPathEvaluation.production_evaluator_ok -and
        [int]$actualPathEvaluation.reconstructed_passed_gate_count -eq 50 -and
        [int]$actualPathEvaluation.reconstructed_failed_gate_count -eq 0 -and
        [string]$actualPathEvaluation.production_selected_candidate_id -ceq "NONE" -and
        [string]$actualPathEvaluation.selected_candidate_id -ceq "NONE" -and
        -not [bool]$actualPathEvaluation.development_selection_authority -and
        -not [bool]$actualPathEvaluation.physical_acceptance_authority
    ) "BW28Y complete actual path did not pass its outer authority firewall"

    $finalCells = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
        $raw = $rawReceipts[$index]
        $expected = $expectedCells[$index]
        Assert-Exact (
            Test-Bw28yRawWorkerReceipt `
                -RawCell $raw `
                -Expected $expected `
                -ProcessExitCode 0 `
                -ProcessOutput "BW28Y zero-world synthetic worker completed"
        ) "BW28Y actual raw receipt $index failed production completeness"
        $finalCells.Add((ConvertTo-Bw28yFinalCellReceipt `
            -RawCell $raw `
            -Expected $expected))
    }
    $actualConstructorCount = [int]$actualAggregate.actual_inherited_constructor_call_count
    $actualComposerCount = $finalCells.Count
    $composedResult.cells = @($finalCells)
    $composedEvaluation = Invoke-Bw28yYawDevelopmentEvaluation -Result $composedResult
    Assert-Exact (
        [bool]$composedEvaluation.ok -and
        [int]$composedEvaluation.reconstructed_passed_gate_count -eq 50 -and
        [string]$composedEvaluation.selected_candidate_id -ceq "NONE"
    ) "BW28Y actual constructor -> production composer -> evaluator path failed"

    $negativeRaw = $actualAggregate.negative_walking_raw_receipt
    $negativeExpected = $expectedCells[1]
    Assert-Exact (
        Test-Bw28yRawWorkerReceipt `
            -RawCell $negativeRaw `
            -Expected $negativeExpected `
            -ProcessExitCode 0 `
            -ProcessOutput "BW28Y valid walking-negative worker completed"
    ) "BW28Y walking-negative raw receipt was incorrectly treated as incomplete"
    $negativeFinal = ConvertTo-Bw28yFinalCellReceipt `
        -RawCell $negativeRaw `
        -Expected $negativeExpected
    Assert-Exact (
        -not [bool]$negativeFinal.walking_observed -and
        [int]$negativeFinal.failed_production_walking_gate_count -eq 1 -and
        (Test-Bw28yCell -Cell $negativeFinal -Expected $negativeExpected)
    ) "BW28Y valid walking-negative did not survive the production composer"

    $scriptErrorRejected = -not (Test-Bw28yRawWorkerReceipt `
        -RawCell $rawReceipts[0] `
        -Expected $expectedCells[0] `
        -ProcessExitCode 0 `
        -ProcessOutput "SCRIPT ERROR: synthetic worker defect")
    Assert-Exact $scriptErrorRejected `
        "BW28Y worker script-error canary did not make the receipt incomplete"

    $bypass = Copy-Deep $perfect
    $bypass.cells = @($rawReceipts)
    Assert-EvaluationFailure `
        -Result $bypass `
        -FailureCode "BW28Y_CELL_GATE" `
        -Label "full walking dictionary bypassed the sole final composer"

    $wrongAttemptCells = @(Copy-Bw28yValue $rawReceipts)
    $wrongAttemptCells[0].world_attempt_id = "BW28Y-ZW::wrong-world"
    $wrongAttempt = Invoke-Bw28yActualPathEvaluation -RawCells $wrongAttemptCells
    Assert-Exact (
        -not [bool]$wrongAttempt.ok -and
        @($wrongAttempt.failure_codes | Where-Object {
            [string]$_ -clike "IDENTITY_MISMATCH::world_attempt_id::*"
        }).Count -gt 0 -and
        -not [bool]$wrongAttempt.production_evaluator_invoked -and
        [string]$wrongAttempt.selected_candidate_id -ceq "NONE"
    ) "BW28Y outer actual-path gate accepted a wrong world-attempt identity"

    $selectionLeakCells = @(Copy-Bw28yValue $rawReceipts)
    foreach ($cell in @($selectionLeakCells | Where-Object {
        [string]$_.candidate_id -ceq "BW28Y-B"
    })) {
        $cell.final_task_frame_lateral_displacement_m = 0.005
        $cell.minimum_cross_track_error_m = -0.04
        $cell.maximum_cross_track_error_m = 0.04
        $cell.maximum_absolute_cross_track_error_m = 0.04
        $cell.cumulative_absolute_cross_track_error_m_s = 0.20
    }
    $selectionLeak = Invoke-Bw28yActualPathEvaluation -RawCells $selectionLeakCells
    Assert-Exact (
        -not [bool]$selectionLeak.ok -and
        [string]$selectionLeak.production_selected_candidate_id -ceq "BW28Y-B" -and
        [string]$selectionLeak.selected_candidate_id -ceq "NONE" -and
        -not [bool]$selectionLeak.development_selection_authority -and
        @($selectionLeak.failure_codes) -ccontains "BW28Y_SYNTHETIC_SELECTION_AUTHORITY"
    ) "BW28Y synthetic result escaped the outer selection-authority firewall"
}

# Production-evaluator canaries. Each mutation begins from a result that passed
# the exact gate, mutates one declared trust surface, and must fail closed.
$canaryCount = 0
function Invoke-Canary {
    param(
        [Parameter(Mandatory)][scriptblock]$Mutation,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $candidate = Copy-Deep $composedResult
    & $Mutation $candidate
    Assert-EvaluationFailure -Result $candidate -FailureCode $FailureCode -Label $Label
    $script:canaryCount += 1
}

Invoke-Canary { param($r) $swap=$r.cells[0]; $r.cells[0]=$r.cells[1]; $r.cells[1]=$swap } `
    "BW28Y_CELL_GATE" "reordered cells"
Invoke-Canary { param($r) $r.cells[0].controller_policy_id="wrong" } `
    "BW28Y_CELL_GATE" "candidate policy identity"
Invoke-Canary { param($r) $r.cells[0].yaw_error_stride_gain_per_rad=9.0 } `
    "BW28Y_CELL_GATE" "candidate yaw gain"
Invoke-Canary { param($r) $r.cells[0].candidate_composition_digest="sha256:$('0'*64)" } `
    "BW28Y_CELL_GATE" "candidate composition digest"
Invoke-Canary { param($r) $r.cells[0].policy_branch_surface_count=1 } `
    "BW28Y_CELL_GATE" "candidate branch count"
Invoke-Canary { param($r) $r.cells[0].residual_application_observed=$false } `
    "BW28Y_CELL_GATE" "candidate residual application"
$controlIndex = [array]::FindIndex([object[]]$composedResult.cells, [Predicate[object]]{
    param($cell) [string]$cell.role -ceq "control"
})
$safetyIndex = [array]::FindIndex([object[]]$composedResult.cells, [Predicate[object]]{
    param($cell) [string]$cell.role -ceq "safety"
})
Assert-Exact ($controlIndex -ge 0 -and $safetyIndex -ge 0) `
    "BW28Y synthetic result is missing control or safety roles"
Invoke-Canary { param($r) $r.cells[$controlIndex].residual_application_observed=$true } `
    "BW28Y_CELL_GATE" "control residual application"
Invoke-Canary { param($r) $r.cells[$controlIndex].base_controller_application_observed=$false } `
    "BW28Y_CELL_GATE" "control base influence"
Invoke-Canary { param($r) $r.cells[$controlIndex].combined_application_gate_passed=$true } `
    "BW28Y_CELL_GATE" "control combined application"
Invoke-Canary { param($r) $r.cells[0].Remove('controller_coefficient') } `
    "BW28Y_CELL_GATE" "missing controller coefficient"
Invoke-Canary { param($r) $r.cells[$safetyIndex].Remove('receipt_route_schema') } `
    "BW28Y_CELL_GATE" "incomplete safety schema"
Invoke-Canary { param($r) $r.cells[0].maximum_absolute_cross_track_error_m=[double]::NaN } `
    "BW28Y_CELL_GATE" "nonfinite steering diagnostic"
Invoke-Canary { param($r) $r.cells[0].material_profile_sha256="sha256:$('f'*64)" } `
    "BW28Y_CELL_GATE" "profile binding"
Invoke-Canary { param($r) $r.cells[0].initial_perturbation_sha256="sha256:$('9'*64)" } `
    "BW28Y_PAIR_IDENTITY" "paired identity"
Invoke-Canary { param($r) $r.cells[0].sdk_native_motor_write_count=0 } `
    "BW28Y_CELL_GATE" "zero native actuation"
Invoke-Canary { param($r) $r.engine.godot_version="wrong" } `
    "BW28Y_HOST_SOURCE" "wrong host"
Invoke-Canary { param($r) $r.prerequisites.bw27p_profile_closure_raw_sha256=('0'*64) } `
    "BW28Y_PREREQUISITES" "wrong prerequisite"
Invoke-Canary { param($r) $r.declared_claims.turning_acceptance=$true } `
    "BW28Y_CLAIM_INFLATION" "claim inflation"

$emptyCandidateResult = Copy-Deep $composedResult
$emptyCandidateResult.cells = @($emptyCandidateResult.cells | Where-Object {
    [string]$_.role -cne "candidate"
})
$emptyDidThrow = $false
try {
    $emptyEvaluation = Invoke-Bw28yYawDevelopmentEvaluation -Result $emptyCandidateResult
} catch {
    $emptyDidThrow = $true
}
Assert-Exact (
    -not $emptyDidThrow -and
    -not [bool]$emptyEvaluation.ok -and
    [string]$emptyEvaluation.selected_candidate_id -ceq "NONE"
) "BW28Y empty-candidate set did not fail closed without throwing"
$canaryCount += 1

Write-Host (
    "BW28Y_ZERO_WORLD_GATE_PASS gates=50 neutral_selection=NONE " +
    "constructors=$actualConstructorCount composers=$actualComposerCount " +
    "canaries=$canaryCount actual_path_identity_veto=True " +
    "selection_authority_veto=True worlds=0 outcomes_exposed=False " +
    "physical_authority=False"
)
