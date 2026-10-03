#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$gatePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw21l_lateral_development_gate.ps1"
. $gatePath

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-Bw21lResult {
    param([Parameter(Mandatory)][object]$Value)
    return (
        $Value | ConvertTo-Json -Depth 64 |
            ConvertFrom-Json -AsHashtable
    )
}

function Assert-Bw21lCanaryFails {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Result,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $evaluation = Test-Bw21lLateralDevelopmentResult -Result $Result
    Assert-Exact (
        -not [bool]$evaluation.ok -and
        @($evaluation.failure_codes) -contains $FailureCode -and
        -not [bool]$evaluation.claims_if_valid.material_robustness -and
        -not [bool]$evaluation.independent_validation_authority -and
        -not [bool]$evaluation.physical_acceptance_authority
    ) "BW21L $Label canary did not fail closed"
}

$perfect = New-Bw21lPerfectSyntheticLateralDevelopmentResult
$perfectEvaluation = Test-Bw21lLateralDevelopmentResult -Result $perfect
$roundTrip = Copy-Bw21lResult $perfect
$roundTripEvaluation = Test-Bw21lLateralDevelopmentResult -Result $roundTrip
Assert-Exact (
    [bool]$perfectEvaluation.ok -and
    [bool]$roundTripEvaluation.ok -and
    [int]$perfectEvaluation.reconstructed_passed_gate_count -eq 73 -and
    [int]$perfectEvaluation.reconstructed_failed_gate_count -eq 0 -and
    @($perfectEvaluation.gates).Count -eq 73 -and
    [int]$perfectEvaluation.observed_world_count -eq 53 -and
    [int]$perfectEvaluation.candidate_count -eq 48 -and
    [int]$perfectEvaluation.control_count -eq 4 -and
    [int]$perfectEvaluation.safety_count -eq 1 -and
    [int]$perfectEvaluation.cell_pass_count -eq 53 -and
    [string]$perfectEvaluation.selected_candidate_id -ceq "BW21L-B" -and
    [bool]$perfectEvaluation.selected_candidate_strictly_better_than_baseline -and
    [int]$perfectEvaluation.selected_candidate_paired_regression_count -eq 0 -and
    [bool]$perfectEvaluation.development_selection_authority -and
    -not [bool]$perfectEvaluation.independent_validation_authority -and
    -not [bool]$perfectEvaluation.claims_if_valid.walking_acceptance -and
    -not [bool]$perfectEvaluation.claims_if_valid.material_robustness -and
    -not [bool]$perfectEvaluation.claims_if_valid.superiority -and
    -not [bool]$perfectEvaluation.claims_if_valid.cross_engine_equivalence -and
    -not [bool]$perfectEvaluation.physical_acceptance_authority
) "BW21L perfect synthetic result did not pass all 73 production gates"

$tie = Copy-Bw21lResult $perfect
foreach ($cell in $tie.cells) {
    if ([string]$cell.role -ceq "candidate") {
        $cell.walking_observed = $true
        foreach ($key in @($cell.walking_gate_receipts.Keys)) {
            $cell.walking_gate_receipts[$key] = $true
        }
        $cell.failed_production_walking_gate_count = 0
        $cell.maximum_absolute_cross_track_error_m = 0.05
        $cell.maximum_cross_track_error_m = 0.05
        $cell.cumulative_absolute_cross_track_error_m_s = 0.5
    }
}
$tieEvaluation = Test-Bw21lLateralDevelopmentResult -Result $tie
Assert-Exact (
    [bool]$tieEvaluation.ok -and
    [string]$tieEvaluation.selected_candidate_id -ceq "NONE" -and
    -not [bool]$tieEvaluation.development_selection_authority -and
    -not [bool]$tieEvaluation.independent_validation_authority
) "BW21L all-tie valid negative did not select NONE"

$pairedRegression = Copy-Bw21lResult $perfect
$bRegression = $pairedRegression.cells | Where-Object {
    [string]$_.cell_id -ceq "development_mu009_s23001_bw21l_b"
} | Select-Object -First 1
$bRegression.walking_gate_receipts.bounded_tilt = $false
$bRegression.failed_production_walking_gate_count = 1
foreach ($candidateId in @("BW21L-C", "BW21L-D")) {
    $candidateCell = $pairedRegression.cells | Where-Object {
        [string]$_.candidate_id -ceq $candidateId
    } | Select-Object -First 1
    $candidateCell.walking_observed = $false
    $candidateCell.walking_gate_receipts.bounded_lateral_drift = $false
    $candidateCell.failed_production_walking_gate_count = 1
}
$pairedRegressionEvaluation = Test-Bw21lLateralDevelopmentResult `
    -Result $pairedRegression
Assert-Exact (
    [bool]$pairedRegressionEvaluation.ok -and
    [string]$pairedRegressionEvaluation.selected_candidate_id -ceq "NONE" -and
    -not [bool]$pairedRegressionEvaluation.development_selection_authority -and
    -not [bool]$pairedRegressionEvaluation.independent_validation_authority
) "BW21L paired-regression result did not remain a valid no-selection result"

$wrongHost = Copy-Bw21lResult $perfect
$wrongHost.engine.godot_executable_sha256 = "0" * 64
Assert-Bw21lCanaryFails $wrongHost "BW21L_HOST_SOURCE" "wrong host"

$wrongPrerequisite = Copy-Bw21lResult $perfect
$wrongPrerequisite.prerequisites.bw20f_report_raw_sha256 = "0" * 64
Assert-Bw21lCanaryFails $wrongPrerequisite `
    "BW21L_PREREQUISITES" "wrong prerequisite"

$wrongDeclaration = Copy-Bw21lResult $perfect
$wrongDeclaration.declarations.candidates_raw_sha256 = "0" * 64
Assert-Bw21lCanaryFails $wrongDeclaration `
    "BW21L_DECLARATIONS" "wrong candidate declaration"

$missingCell = Copy-Bw21lResult $perfect
$missingCell.cells = @($missingCell.cells | Select-Object -Skip 1)
Assert-Bw21lCanaryFails $missingCell `
    "BW21L_MATRIX_CARDINALITY" "missing cell"

$wrongOrder = Copy-Bw21lResult $perfect
$temporary = $wrongOrder.cells[0]
$wrongOrder.cells[0] = $wrongOrder.cells[1]
$wrongOrder.cells[1] = $temporary
Assert-Bw21lCanaryFails $wrongOrder "BW21L_CELL_GATE" "cell order"

$wrongPolicy = Copy-Bw21lResult $perfect
$wrongPolicy.cells[1].controller_policy_id = "sporespore_balanced_wave_bw15f_b_v1"
Assert-Bw21lCanaryFails $wrongPolicy `
    "BW21L_CANDIDATE_PROFILE" "candidate policy"

$wrongGain = Copy-Bw21lResult $perfect
$wrongGain.cells[2].velocity_factor = 1.0
Assert-Bw21lCanaryFails $wrongGain "BW21L_CELL_GATE" "candidate gain"

$branchConditioned = Copy-Bw21lResult $perfect
$branchConditioned.cells[3].policy_branch_surface_count = 1
Assert-Bw21lCanaryFails $branchConditioned `
    "BW21L_OUTCOME_CONDITIONING" "branch conditioning"

$candidateNoResidual = Copy-Bw21lResult $perfect
$candidateNoResidual.cells[0].residual_application_observed = $false
$candidateNoResidual.cells[0].sdk_effective_application_count = 0
$candidateNoResidual.cells[0].maximum_absolute_applied_velocity_rad_s = 0.0
Assert-Bw21lCanaryFails $candidateNoResidual `
    "BW21L_CANDIDATE_APPLICATION" "candidate residual application"

$controlApplied = Copy-Bw21lResult $perfect
$controlApplied.cells[4].residual_application_observed = $true
$controlApplied.cells[4].sdk_effective_application_count = 1
$controlApplied.cells[4].maximum_absolute_applied_velocity_rad_s = 0.01
Assert-Bw21lCanaryFails $controlApplied `
    "BW21L_CONTROL_RESIDUAL_SEMANTICS" "control residual application"

$controlCombined = Copy-Bw21lResult $perfect
$controlCombined.cells[4].combined_application_gate_passed = $true
Assert-Bw21lCanaryFails $controlCombined `
    "BW21L_CONTROL_RESIDUAL_SEMANTICS" "control combined gate"

$controlBaseMissing = Copy-Bw21lResult $perfect
$controlBaseMissing.cells[4].sdk_native_motor_write_count = 0
$controlBaseMissing.cells[4].base_controller_application_observed = $false
$controlBaseMissing.cells[4].broad_base_controller_physical_influence_observed = $false
$controlBaseMissing.cells[4].physical_influence = $false
Assert-Bw21lCanaryFails $controlBaseMissing `
    "BW21L_CONTROL_BASE_INFLUENCE" "control base influence"

$walkingReceiptMismatch = Copy-Bw21lResult $perfect
$walkingReceiptMismatch.cells[5].walking_gate_receipts.bounded_tilt = $false
Assert-Bw21lCanaryFails $walkingReceiptMismatch `
    "BW21L_CANDIDATE_OUTCOME_METRICS" "walking receipt consistency"

$nonfiniteSteering = Copy-Bw21lResult $perfect
$nonfiniteSteering.cells[6].maximum_absolute_filtered_steering_fraction = "NaN"
Assert-Bw21lCanaryFails $nonfiniteSteering `
    "BW21L_STEERING_DIAGNOSTICS" "nonfinite steering"

$wrongProfileBinding = Copy-Bw21lResult $perfect
$wrongProfileBinding.cells[7].profile_binding_exact = $false
Assert-Bw21lCanaryFails $wrongProfileBinding `
    "BW21L_CELL_GATE" "profile binding"

$pairMismatch = Copy-Bw21lResult $perfect
$pairMismatch.cells[8].fixture_spec_sha256 = "sha256:" + ("e" * 64)
Assert-Bw21lCanaryFails $pairMismatch "BW21L_PAIR_IDENTITY" "paired identity"

$perturbationMismatch = Copy-Bw21lResult $perfect
$perturbationMismatch.cells[9].initial_perturbation.gait_phase_offset_ticks = 99
Assert-Bw21lCanaryFails $perturbationMismatch `
    "BW21L_PAIR_PERTURBATION" "paired perturbation"

$zeroActuated = Copy-Bw21lResult $perfect
$zeroActuated.cells[52].sdk_native_motor_write_count = 1
$zeroActuated.cells[52].base_controller_application_observed = $true
Assert-Bw21lCanaryFails $zeroActuated `
    "BW21L_ZERO_SAFETY" "zero-friction native actuation"

$selectorMutation = Copy-Bw21lResult $perfect
$selectorMutation.selector_declaration.selection_vector[0] = "maximum_tilt_rad"
Assert-Bw21lCanaryFails $selectorMutation `
    "BW21L_SELECTOR_DECLARATION" "selector mutation"

$claimInflation = Copy-Bw21lResult $perfect
$claimInflation.declared_claims.material_robustness = $true
Assert-Bw21lCanaryFails $claimInflation `
    "BW21L_CLAIM_INFLATION" "claim inflation"

Write-Host (
    "BW21L_LATERAL_DEVELOPMENT_GATE_PASS gates=73 cells=53 " +
    "candidates=48 controls=4 safety=1 canaries=18 roundtrip=True " +
    "tie_selects_none=True paired_regression_selects_none=True worlds=0 " +
    "development_only=True validation_authority=False physical_authority=False"
)
