#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$gatePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw25y_yaw_development_gate.ps1"
. $gatePath

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-Bw25yResult {
    param([Parameter(Mandatory)][object]$Value)
    return (
        $Value | ConvertTo-Json -Depth 64 |
            ConvertFrom-Json -AsHashtable
    )
}

function Assert-Bw25yCanaryFails {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Result,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $evaluation = Invoke-Bw25yYawDevelopmentEvaluation -Result $Result
    Assert-Exact (
        -not [bool]$evaluation.ok -and
        @($evaluation.failure_codes) -contains $FailureCode -and
        -not [bool]$evaluation.claims_if_valid.material_robustness -and
        -not [bool]$evaluation.independent_validation_authority -and
        -not [bool]$evaluation.physical_acceptance_authority
    ) "BW25Y $Label canary did not fail closed"
}

$perfect = New-Bw25yPerfectSyntheticYawDevelopmentResult
$perfectEvaluation = Invoke-Bw25yYawDevelopmentEvaluation -Result $perfect
$roundTrip = Copy-Bw25yResult $perfect
$roundTripEvaluation = Invoke-Bw25yYawDevelopmentEvaluation -Result $roundTrip
Assert-Exact (
    [bool]$perfectEvaluation.ok -and
    [bool]$roundTripEvaluation.ok -and
    [int]$perfectEvaluation.reconstructed_passed_gate_count -eq 50 -and
    [int]$perfectEvaluation.reconstructed_failed_gate_count -eq 0 -and
    @($perfectEvaluation.gates).Count -eq 50 -and
    [int]$perfectEvaluation.observed_world_count -eq 28 -and
    [int]$perfectEvaluation.candidate_count -eq 24 -and
    [int]$perfectEvaluation.control_count -eq 3 -and
    [int]$perfectEvaluation.safety_count -eq 1 -and
    [string]$perfectEvaluation.selected_candidate_id -ceq "BW25Y-B" -and
    [bool]$perfectEvaluation.selected_candidate_strictly_better_than_baseline -and
    [int]$perfectEvaluation.selected_candidate_paired_regression_count -eq 0 -and
    [bool]$perfectEvaluation.development_selection_authority -and
    -not [bool]$perfectEvaluation.independent_validation_authority -and
    -not [bool]$perfectEvaluation.claims_if_valid.walking_acceptance -and
    -not [bool]$perfectEvaluation.claims_if_valid.material_robustness -and
    -not [bool]$perfectEvaluation.claims_if_valid.superiority -and
    -not [bool]$perfectEvaluation.claims_if_valid.cross_engine_equivalence -and
    -not [bool]$perfectEvaluation.physical_acceptance_authority
) "BW25Y perfect synthetic result did not pass all 50 production gates"

$tie = Copy-Bw25yResult $perfect
foreach ($cell in $tie.cells) {
    if ([string]$cell.role -ceq "candidate") {
        $cell.walking_observed = $true
        foreach ($key in @($cell.walking_gate_receipts.Keys)) {
            $cell.walking_gate_receipts[$key] = $true
        }
        $cell.failed_production_walking_gate_count = 0
        $cell.maximum_absolute_cross_track_error_m = 0.10
        $cell.cumulative_absolute_cross_track_error_m_s = 0.40
    }
}
$tieEvaluation = Invoke-Bw25yYawDevelopmentEvaluation -Result $tie
Assert-Exact (
    [bool]$tieEvaluation.ok -and
    [string]$tieEvaluation.selected_candidate_id -ceq "NONE" -and
    -not [bool]$tieEvaluation.development_selection_authority -and
    -not [bool]$tieEvaluation.independent_validation_authority
) "BW25Y all-tie valid negative did not select NONE"

$pairedRegression = Copy-Bw25yResult $perfect
$bRegression = $pairedRegression.cells | Where-Object {
    [string]$_.cell_id -ceq "development_mu059_s26011_bw25y_b"
} | Select-Object -First 1
$bRegression.walking_observed = $false
$bRegression.walking_gate_receipts.bounded_tilt = $false
$bRegression.failed_production_walking_gate_count = 1
$pairedRegressionEvaluation = Invoke-Bw25yYawDevelopmentEvaluation `
    -Result $pairedRegression
Assert-Exact (
    [bool]$pairedRegressionEvaluation.ok -and
    [string]$pairedRegressionEvaluation.selected_candidate_id -ceq "NONE" -and
    [int]$pairedRegressionEvaluation.selected_candidate_paired_regression_count -eq 1 -and
    -not [bool]$pairedRegressionEvaluation.development_selection_authority -and
    -not [bool]$pairedRegressionEvaluation.independent_validation_authority
) "BW25Y paired-regression result did not remain a valid no-selection result"

$wrongHost = Copy-Bw25yResult $perfect
$wrongHost.engine.godot_executable_sha256 = "0" * 64
Assert-Bw25yCanaryFails $wrongHost "BW25Y_HOST_SOURCE" "wrong host"

$wrongPrerequisite = Copy-Bw25yResult $perfect
$wrongPrerequisite.prerequisites.bw24p_profile_closure_raw_sha256 = "0" * 64
Assert-Bw25yCanaryFails $wrongPrerequisite `
    "BW25Y_PREREQUISITES" "wrong prerequisite"

$wrongDeclaration = Copy-Bw25yResult $perfect
$wrongDeclaration.declarations.candidates_raw_sha256 = "0" * 64
Assert-Bw25yCanaryFails $wrongDeclaration `
    "BW25Y_DECLARATIONS" "wrong candidate declaration"

$wrongPreregistration = Copy-Bw25yResult $perfect
$wrongPreregistration.declarations.preregistration_raw_sha256 = "0" * 64
Assert-Bw25yCanaryFails $wrongPreregistration `
    "BW25Y_DECLARATIONS" "wrong preregistration declaration"

$missingCell = Copy-Bw25yResult $perfect
$missingCell.cells = @($missingCell.cells | Select-Object -Skip 1)
Assert-Bw25yCanaryFails $missingCell `
    "BW25Y_MATRIX_CARDINALITY" "missing cell"

$wrongOrder = Copy-Bw25yResult $perfect
$temporary = $wrongOrder.cells[0]
$wrongOrder.cells[0] = $wrongOrder.cells[1]
$wrongOrder.cells[1] = $temporary
Assert-Bw25yCanaryFails $wrongOrder "BW25Y_CELL_GATE" "cell order"

$wrongPolicy = Copy-Bw25yResult $perfect
$wrongPolicy.cells[1].controller_policy_id =
    "sporespore_balanced_wave_bw15f_b_v1"
Assert-Bw25yCanaryFails $wrongPolicy `
    "BW25Y_POLICY_RELATIVE_IDENTITY" "candidate policy"

$failedPolicyRelativeReceipt = Copy-Bw25yResult $perfect
$failedPolicyRelativeReceipt.cells[1].policy_relative_common_execution.ok = $false
Assert-Bw25yCanaryFails $failedPolicyRelativeReceipt `
    "BW25Y_POLICY_RELATIVE_IDENTITY" "failed policy-relative receipt"

$wrongGain = Copy-Bw25yResult $perfect
$wrongGain.cells[1].yaw_error_stride_gain_per_rad = 1.3
Assert-Bw25yCanaryFails $wrongGain "BW25Y_CELL_GATE" "candidate yaw gain"

$branchConditioned = Copy-Bw25yResult $perfect
$branchConditioned.cells[0].policy_branch_surface_count = 1
Assert-Bw25yCanaryFails $branchConditioned `
    "BW25Y_OUTCOME_CONDITIONING" "branch conditioning"

$candidateNoResidual = Copy-Bw25yResult $perfect
$candidateNoResidual.cells[0].residual_application_observed = $false
$candidateNoResidual.cells[0].sdk_effective_application_count = 0
$candidateNoResidual.cells[0].maximum_absolute_applied_velocity_rad_s = 0.0
Assert-Bw25yCanaryFails $candidateNoResidual `
    "BW25Y_CANDIDATE_APPLICATION" "candidate residual application"

$controlApplied = Copy-Bw25yResult $perfect
$controlApplied.cells[2].residual_application_observed = $true
$controlApplied.cells[2].sdk_effective_application_count = 1
$controlApplied.cells[2].maximum_absolute_applied_velocity_rad_s = 0.01
Assert-Bw25yCanaryFails $controlApplied `
    "BW25Y_CONTROL_RESIDUAL_SEMANTICS" "control residual application"

$controlCombined = Copy-Bw25yResult $perfect
$controlCombined.cells[2].combined_application_gate_passed = $true
Assert-Bw25yCanaryFails $controlCombined `
    "BW25Y_CONTROL_RESIDUAL_SEMANTICS" "control combined gate"

$controlBaseMissing = Copy-Bw25yResult $perfect
$controlBaseMissing.cells[2].sdk_native_motor_write_count = 0
$controlBaseMissing.cells[2].base_controller_application_observed = $false
$controlBaseMissing.cells[2].broad_base_controller_physical_influence_observed = $false
$controlBaseMissing.cells[2].physical_influence = $false
Assert-Bw25yCanaryFails $controlBaseMissing `
    "BW25Y_CONTROL_BASE_INFLUENCE" "control base influence"

$walkingReceiptMismatch = Copy-Bw25yResult $perfect
$walkingReceiptMismatch.cells[1].walking_gate_receipts.bounded_tilt = $false
Assert-Bw25yCanaryFails $walkingReceiptMismatch `
    "BW25Y_CELL_GATE" "walking receipt consistency"

# Reproduce the first BW22L final-composition defect: a physically produced
# full inherited walking dictionary must not be accepted where the evaluator
# declares the exact four-key projection.
$fullWalkingDictionary = Copy-Bw25yResult $perfect
$fullWalkingDictionary.cells[1].walking_gate_receipts.bounded_anchor_error = $true
Assert-Bw25yCanaryFails $fullWalkingDictionary `
    "BW25Y_CELL_GATE" "unprojected full walking dictionary"

# Reproduce the second BW22L final-composition defect explicitly.
$missingControllerCoefficient = Copy-Bw25yResult $perfect
$missingControllerCoefficient.cells[1].Remove("controller_coefficient")
Assert-Bw25yCanaryFails $missingControllerCoefficient `
    "BW25Y_CELL_GATE" "missing controller coefficient"

# Reproduce the third BW22L defect on the real safety role, rather than only
# constructing a separate perfect synthetic safety receipt.
$incompleteSafetySchema = Copy-Bw25yResult $perfect
$incompleteSafetySchema.cells[27].Remove("declared_controller_policy_id")
Assert-Bw25yCanaryFails $incompleteSafetySchema `
    "BW25Y_CELL_GATE" "incomplete zero-friction safety schema"

# A physical walking failure is not an infrastructure failure. This result has
# a real four-key failure, consistent derived fields, and valid execution
# integrity; the production evaluator must accept it as a complete development
# observation while retaining walking_acceptance=False.
$negativeWalking = Copy-Bw25yResult $perfect
$negativeCell = $negativeWalking.cells | Where-Object {
    [string]$_.cell_id -ceq "development_mu059_s26011_bw25y_b"
} | Select-Object -First 1
$negativeCell.walking_gate_receipts.bounded_lateral_drift = $false
$negativeCell.walking_observed = $false
$negativeCell.failed_production_walking_gate_count = 1
$negativeWalkingEvaluation = Invoke-Bw25yYawDevelopmentEvaluation `
    -Result $negativeWalking
Assert-Exact (
    [bool]$negativeWalkingEvaluation.ok -and
    [bool]$negativeCell.common_execution_integrity -and
    [bool]$negativeCell.outcome_complete -and
    -not [bool]$negativeCell.walking_observed -and
    -not [bool]$negativeWalkingEvaluation.claims_if_valid.walking_acceptance
) "BW25Y negative walking outcome was confused with infrastructure failure"

$nonfiniteSteering = Copy-Bw25yResult $perfect
$nonfiniteSteering.cells[1].maximum_absolute_filtered_steering_fraction = "NaN"
Assert-Bw25yCanaryFails $nonfiniteSteering `
    "BW25Y_STEERING_DIAGNOSTICS" "nonfinite steering"

$overboundSteering = Copy-Bw25yResult $perfect
$overboundSteering.cells[1].maximum_absolute_requested_steering_fraction = 0.41
Assert-Bw25yCanaryFails $overboundSteering `
    "BW25Y_STEERING_DIAGNOSTICS" "overbound steering"

$missingFilterApplications = Copy-Bw25yResult $perfect
$missingFilterApplications.cells[1].steering_filter_application_count = 0
Assert-Bw25yCanaryFails $missingFilterApplications `
    "BW25Y_STEERING_DIAGNOSTICS" "missing steering filter applications"

$wrongProfileBinding = Copy-Bw25yResult $perfect
$wrongProfileBinding.cells[1].profile_binding_exact = $false
Assert-Bw25yCanaryFails $wrongProfileBinding `
    "BW25Y_CELL_GATE" "profile binding"

$pairMismatch = Copy-Bw25yResult $perfect
$pairMismatch.cells[1].fixture_spec_sha256 = "sha256:" + ("e" * 64)
Assert-Bw25yCanaryFails $pairMismatch "BW25Y_PAIR_IDENTITY" "paired identity"

$perturbationMismatch = Copy-Bw25yResult $perfect
$perturbationMismatch.cells[1].initial_perturbation.gait_phase_offset_ticks = 99
Assert-Bw25yCanaryFails $perturbationMismatch `
    "BW25Y_PAIRED_PERTURBATION" "paired perturbation"

$zeroActuated = Copy-Bw25yResult $perfect
$zeroActuated.cells[27].sdk_native_motor_write_count = 1
$zeroActuated.cells[27].base_controller_application_observed = $true
Assert-Bw25yCanaryFails $zeroActuated `
    "BW25Y_ZERO_SAFETY" "zero-friction native actuation"

$selectorMutation = Copy-Bw25yResult $perfect
$selectorMutation.selector.selection_vector[0] = "maximum_tilt_rad"
Assert-Bw25yCanaryFails $selectorMutation `
    "BW25Y_SELECTOR_DECLARATION" "selector mutation"

$preinvokedSelector = Copy-Bw25yResult $perfect
$preinvokedSelector.selector_invocation_count_before_evaluation = 1
$preinvokedSelector.pre_evaluation_selected_candidate_id = "BW25Y-B"
Assert-Bw25yCanaryFails $preinvokedSelector `
    "BW25Y_SELECTOR_PREINVOCATION" "pre-invoked selector"

$claimInflation = Copy-Bw25yResult $perfect
$claimInflation.declared_claims.material_robustness = $true
Assert-Bw25yCanaryFails $claimInflation `
    "BW25Y_CLAIM_INFLATION" "claim inflation"

Write-Host (
    "BW25Y_YAW_DEVELOPMENT_GATE_PASS gates=50 cells=28 " +
    "candidates=24 controls=3 safety=1 canaries=28 roundtrip=True " +
    "negative_walking_integrity=True tie_selects_none=True " +
    "paired_regression_selects_none=True worlds=0 " +
    "development_only=True validation_authority=False physical_authority=False"
)
