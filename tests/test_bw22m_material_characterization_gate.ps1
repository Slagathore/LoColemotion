#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$gatePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw22m_material_characterization_gate.ps1"
. $gatePath

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-Bw22mReceipt {
    param([Parameter(Mandatory)][object]$Value)
    return (
        $Value | ConvertTo-Json -Depth 40 |
            ConvertFrom-Json -AsHashtable
    )
}

function Assert-Bw22mFailure {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Receipt,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $evaluation = Test-Bw22mMaterialCharacterizationReceipt -Receipt $Receipt
    Assert-Exact (
        -not [bool]$evaluation.ok -and
        @($evaluation.failure_codes) -contains $FailureCode -and
        -not [bool]$evaluation.physical_acceptance_authority
    ) "BW22M $Label canary did not fail closed with $FailureCode"
}

$perfect = New-Bw22mPerfectSyntheticCharacterizationReceipt
$perfectEvaluation = Test-Bw22mMaterialCharacterizationReceipt -Receipt $perfect
$roundTrip = Copy-Bw22mReceipt $perfect
$roundTripEvaluation = Test-Bw22mMaterialCharacterizationReceipt `
    -Receipt $roundTrip
Assert-Exact (
    [bool]$perfectEvaluation.ok -and
    [bool]$roundTripEvaluation.ok -and
    [int]$perfectEvaluation.reconstructed_passed_gate_count -eq 19 -and
    [int]$perfectEvaluation.reconstructed_failed_gate_count -eq 0 -and
    @($perfectEvaluation.gates).Count -eq 19 -and
    @($perfectEvaluation.cells).Count -eq 3 -and
    @($perfectEvaluation.failure_codes).Count -eq 0 -and
    [bool]$perfectEvaluation.receipt_meta_integrity_passed -and
    [bool]$perfectEvaluation.fixture_identity_and_matrix_passed -and
    [bool]$perfectEvaluation.claims_remain_bounded -and
    -not [bool]$perfectEvaluation.physical_acceptance_authority
) "BW22M perfect synthetic report did not pass the complete production gate"

$wrongLauncher = Copy-Bw22mReceipt $perfect
$wrongLauncher.engine.godot_launcher_executable_sha256 = "0" * 64
Assert-Bw22mFailure $wrongLauncher "BW22M_ENGINE_IDENTITY" "wrong launcher"

$wrongRuntime = Copy-Bw22mReceipt $perfect
$wrongRuntime.engine.godot_runtime_executable_sha256 = "0" * 64
Assert-Bw22mFailure $wrongRuntime "BW22M_ENGINE_IDENTITY" "wrong runtime"

$wrongOrder = Copy-Bw22mReceipt $perfect
$wrongOrder.fixture.positive_friction_values[0] = 0.69
$wrongOrder.fixture.positive_friction_values[1] = 0.57
Assert-Bw22mFailure $wrongOrder "BW22M_RECEIPT_META_INTEGRITY" `
    "authored-value order"

$missingReplicate = Copy-Bw22mReceipt $perfect
$missingReplicate.positive_cells[0].replicates = @(
    $missingReplicate.positive_cells[0].replicates | Select-Object -First 2
)
Assert-Bw22mFailure $missingReplicate "BW22M_REPLICATE_GATE" `
    "missing replicate"

$wideBracket = Copy-Bw22mReceipt $perfect
$wideBracket.positive_cells[0].replicates[0].breakaway_force_upper_n = 25.1
Assert-Bw22mFailure $wideBracket "BW22M_REPLICATE_GATE" "wide bracket"

$coefficientMismatch = Copy-Bw22mReceipt $perfect
$coefficientMismatch.positive_cells[1].coefficient_derivation.controller_mu = 0.67
$coefficientEvaluation = Test-Bw22mMaterialCharacterizationReceipt `
    -Receipt $coefficientMismatch
Assert-Exact (
    -not [bool]$coefficientEvaluation.ok -and
    @($coefficientEvaluation.failure_codes) -contains "BW22M_CELL_GATE" -and
    @($coefficientEvaluation.failure_codes) -contains
        "BW22M_COEFFICIENT_DERIVATION"
) "BW22M coefficient-derivation canary did not fail closed"

$monotonicityViolation = Copy-Bw22mReceipt $perfect
foreach ($replicate in $monotonicityViolation.positive_cells[2].replicates) {
    $replicate.breakaway_force_lower_n = 5.0
    $replicate.breakaway_force_upper_n = 6.0
    $replicate.empirical_static_ratio_lower = 0.1
    $replicate.empirical_static_ratio_upper = 0.12
}
$monotonicityViolation.positive_cells[2].minimum_lower_breakaway_force_n = 5.0
$monotonicityViolation.positive_cells[2].minimum_lower_empirical_ratio = 0.1
$monotonicityViolation.positive_cells[2].coefficient_derivation.minimum_lower_ratio = 0.1
$monotonicityViolation.positive_cells[2].coefficient_derivation.controller_mu = 0.1
Assert-Bw22mFailure $monotonicityViolation "BW22M_MONOTONICITY" `
    "operational monotonicity"

$claimInflation = Copy-Bw22mReceipt $perfect
$claimInflation.material_robustness = $true
Assert-Bw22mFailure $claimInflation "BW22M_CLAIM_INFLATION" "claim inflation"

$worldCountMismatch = Copy-Bw22mReceipt $perfect
$worldCountMismatch.observed_world_count = 9
Assert-Bw22mFailure $worldCountMismatch "BW22M_RECEIPT_META_INTEGRITY" `
    "world count"

$fixtureMismatch = Copy-Bw22mReceipt $perfect
$fixtureMismatch.fixture.fixture_id = "SDK.BW20F.godot_jolt_material_sled.v1"
Assert-Bw22mFailure $fixtureMismatch "BW22M_RECEIPT_META_INTEGRITY" `
    "fixture identity"

Write-Host (
    "BW22M_MATERIAL_GATE_PASS gates=19 cells=3 canaries=10 " +
    "roundtrip=True worlds=0 physical_authority=False"
)
