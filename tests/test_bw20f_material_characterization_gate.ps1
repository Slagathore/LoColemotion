#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$gatePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw20f_material_characterization_gate.ps1"
. $gatePath

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Copy-Bw20fReceipt {
    param([Parameter(Mandatory)][object]$Value)
    return (
        $Value | ConvertTo-Json -Depth 40 |
            ConvertFrom-Json -AsHashtable
    )
}

$perfect = New-Bw20fPerfectSyntheticCharacterizationReceipt
$perfectEvaluation = Test-Bw20fMaterialCharacterizationReceipt -Receipt $perfect
$roundTrip = Copy-Bw20fReceipt $perfect
$roundTripEvaluation = Test-Bw20fMaterialCharacterizationReceipt `
    -Receipt $roundTrip
Assert-Exact (
    [bool]$perfectEvaluation.ok -and
    [bool]$roundTripEvaluation.ok -and
    [int]$perfectEvaluation.reconstructed_passed_gate_count -eq 23 -and
    [int]$perfectEvaluation.reconstructed_failed_gate_count -eq 0 -and
    @($perfectEvaluation.gates).Count -eq 23 -and
    @($perfectEvaluation.cells).Count -eq 4 -and
    @($perfectEvaluation.failure_codes).Count -eq 0 -and
    [bool]$perfectEvaluation.receipt_meta_integrity_passed -and
    [bool]$perfectEvaluation.fixture_identity_and_matrix_passed -and
    [bool]$perfectEvaluation.claims_remain_bounded -and
    -not [bool]$perfectEvaluation.physical_acceptance_authority
) "BW20F perfect synthetic production receipt did not pass the complete gate"

$wrongHost = Copy-Bw20fReceipt $perfect
$wrongHost.engine.godot_executable_sha256 = "0" * 64
$wrongHostEvaluation = Test-Bw20fMaterialCharacterizationReceipt `
    -Receipt $wrongHost
Assert-Exact (
    -not [bool]$wrongHostEvaluation.ok -and
    @($wrongHostEvaluation.failure_codes) -contains "BW20F_ENGINE_IDENTITY"
) "BW20F wrong-host-identity canary did not fail closed"

$wrongOrder = Copy-Bw20fReceipt $perfect
$wrongOrder.fixture.positive_friction_values[0] = 0.37
$wrongOrder.fixture.positive_friction_values[1] = 0.09
$wrongOrderEvaluation = Test-Bw20fMaterialCharacterizationReceipt `
    -Receipt $wrongOrder
Assert-Exact (
    -not [bool]$wrongOrderEvaluation.ok -and
    @($wrongOrderEvaluation.failure_codes) -contains
        "BW20F_RECEIPT_META_INTEGRITY"
) "BW20F authored-value ordering canary did not fail closed"

$wideBracket = Copy-Bw20fReceipt $perfect
$wideBracket.positive_cells[0].replicates[0].breakaway_force_upper_n = 6.1
$wideBracketEvaluation = Test-Bw20fMaterialCharacterizationReceipt `
    -Receipt $wideBracket
Assert-Exact (
    -not [bool]$wideBracketEvaluation.ok -and
    @($wideBracketEvaluation.failure_codes) -contains "BW20F_REPLICATE_GATE"
) "BW20F wide-bracket canary did not fail closed"

$coefficientMismatch = Copy-Bw20fReceipt $perfect
$coefficientMismatch.positive_cells[1].coefficient_derivation.controller_mu = 0.35
$coefficientEvaluation = Test-Bw20fMaterialCharacterizationReceipt `
    -Receipt $coefficientMismatch
Assert-Exact (
    -not [bool]$coefficientEvaluation.ok -and
    @($coefficientEvaluation.failure_codes) -contains "BW20F_CELL_GATE" -and
    @($coefficientEvaluation.failure_codes) -contains
        "BW20F_COEFFICIENT_DERIVATION"
) "BW20F coefficient-derivation canary did not fail closed"

$monotonicityViolation = Copy-Bw20fReceipt $perfect
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
$monotonicityEvaluation = Test-Bw20fMaterialCharacterizationReceipt `
    -Receipt $monotonicityViolation
Assert-Exact (
    -not [bool]$monotonicityEvaluation.ok -and
    @($monotonicityEvaluation.failure_codes) -contains "BW20F_MONOTONICITY"
) "BW20F operational-monotonicity canary did not fail closed"

$claimInflation = Copy-Bw20fReceipt $perfect
$claimInflation.walking = $true
$claimEvaluation = Test-Bw20fMaterialCharacterizationReceipt `
    -Receipt $claimInflation
Assert-Exact (
    -not [bool]$claimEvaluation.ok -and
    @($claimEvaluation.failure_codes) -contains "BW20F_CLAIM_INFLATION"
) "BW20F claim-inflation canary did not fail closed"

Write-Host (
    "BW20F_MATERIAL_GATE_PASS gates=23 cells=4 canaries=6 " +
    "roundtrip=True worlds=0 physical_authority=False"
)
