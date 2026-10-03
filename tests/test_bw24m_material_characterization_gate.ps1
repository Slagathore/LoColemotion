#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$gatePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw24m_material_characterization_gate.ps1"
. $gatePath

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-Bw24mReceipt {
    param([Parameter(Mandatory)][object]$Value)
    return (
        $Value | ConvertTo-Json -Depth 40 |
            ConvertFrom-Json -AsHashtable
    )
}

function Assert-Bw24mFailure {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Receipt,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $evaluation = Test-Bw24mMaterialCharacterizationReceipt -Receipt $Receipt
    Assert-Exact (
        -not [bool]$evaluation.ok -and
        @($evaluation.failure_codes) -contains $FailureCode -and
        -not [bool]$evaluation.physical_acceptance_authority
    ) "BW24M $Label canary did not fail closed with $FailureCode"
}

$perfect = New-Bw24mPerfectSyntheticCharacterizationReceipt
$perfectEvaluation = Test-Bw24mMaterialCharacterizationReceipt -Receipt $perfect
$roundTrip = Copy-Bw24mReceipt $perfect
$roundTripEvaluation = Test-Bw24mMaterialCharacterizationReceipt `
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
) "BW24M perfect synthetic report did not pass the complete production gate"

$wrongLauncher = Copy-Bw24mReceipt $perfect
$wrongLauncher.engine.godot_launcher_executable_sha256 = "0" * 64
Assert-Bw24mFailure $wrongLauncher "BW24M_ENGINE_IDENTITY" "wrong launcher"

$wrongRuntime = Copy-Bw24mReceipt $perfect
$wrongRuntime.engine.godot_runtime_executable_sha256 = "0" * 64
Assert-Bw24mFailure $wrongRuntime "BW24M_ENGINE_IDENTITY" "wrong runtime"

$wrongOrder = Copy-Bw24mReceipt $perfect
$wrongOrder.fixture.positive_friction_values[0] = 0.71
$wrongOrder.fixture.positive_friction_values[1] = 0.59
Assert-Bw24mFailure $wrongOrder "BW24M_RECEIPT_META_INTEGRITY" `
    "authored-value order"

$missingReplicate = Copy-Bw24mReceipt $perfect
$missingReplicate.positive_cells[0].replicates = @(
    $missingReplicate.positive_cells[0].replicates | Select-Object -First 2
)
Assert-Bw24mFailure $missingReplicate "BW24M_REPLICATE_GATE" `
    "missing replicate"

$wideBracket = Copy-Bw24mReceipt $perfect
$wideBracket.positive_cells[0].replicates[0].breakaway_force_upper_n = 25.1
Assert-Bw24mFailure $wideBracket "BW24M_REPLICATE_GATE" "wide bracket"

$coefficientMismatch = Copy-Bw24mReceipt $perfect
$coefficientMismatch.positive_cells[1].coefficient_derivation.controller_mu = 0.67
$coefficientEvaluation = Test-Bw24mMaterialCharacterizationReceipt `
    -Receipt $coefficientMismatch
Assert-Exact (
    -not [bool]$coefficientEvaluation.ok -and
    @($coefficientEvaluation.failure_codes) -contains "BW24M_CELL_GATE" -and
    @($coefficientEvaluation.failure_codes) -contains
        "BW24M_COEFFICIENT_DERIVATION"
) "BW24M coefficient-derivation canary did not fail closed"

$monotonicityViolation = Copy-Bw24mReceipt $perfect
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
Assert-Bw24mFailure $monotonicityViolation "BW24M_MONOTONICITY" `
    "operational monotonicity"

$claimInflation = Copy-Bw24mReceipt $perfect
$claimInflation.material_robustness = $true
Assert-Bw24mFailure $claimInflation "BW24M_CLAIM_INFLATION" "claim inflation"

$worldCountMismatch = Copy-Bw24mReceipt $perfect
$worldCountMismatch.observed_world_count = 9
Assert-Bw24mFailure $worldCountMismatch "BW24M_RECEIPT_META_INTEGRITY" `
    "world count"

$fixtureMismatch = Copy-Bw24mReceipt $perfect
$fixtureMismatch.fixture.fixture_id = "SDK.BW20F.godot_jolt_material_sled.v1"
Assert-Bw24mFailure $fixtureMismatch "BW24M_RECEIPT_META_INTEGRITY" `
    "fixture identity"

Write-Host (
    "BW24M_MATERIAL_GATE_PASS gates=19 cells=3 canaries=10 " +
    "roundtrip=True worlds=0 physical_authority=False"
)
