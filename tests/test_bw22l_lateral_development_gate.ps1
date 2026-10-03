#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$gatePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw22l_lateral_development_gate.ps1"
. $gatePath

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-Bw22lResult {
    param([Parameter(Mandatory)][object]$Value)
    return (
        $Value | ConvertTo-Json -Depth 64 |
            ConvertFrom-Json -AsHashtable
    )
}

function Assert-Bw22lCanaryFails {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Result,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $evaluation = Invoke-Bw22lLateralDevelopmentEvaluation -Result $Result
    Assert-Exact (
        -not [bool]$evaluation.ok -and
        @($evaluation.failure_codes) -contains $FailureCode -and
        -not [bool]$evaluation.claims_if_valid.material_robustness -and
        -not [bool]$evaluation.independent_validation_authority -and
        -not [bool]$evaluation.physical_acceptance_authority
    ) "BW22L $Label canary did not fail closed"
}

$perfect = New-Bw22lPerfectSyntheticLateralDevelopmentResult
$perfectEvaluation = Invoke-Bw22lLateralDevelopmentEvaluation -Result $perfect
$roundTrip = Copy-Bw22lResult $perfect
$roundTripEvaluation = Invoke-Bw22lLateralDevelopmentEvaluation -Result $roundTrip
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
    [string]$perfectEvaluation.selected_candidate_id -ceq "BW22L-B" -and
    [bool]$perfectEvaluation.selected_candidate_strictly_better_than_baseline -and
    [int]$perfectEvaluation.selected_candidate_paired_regression_count -eq 0 -and
    [bool]$perfectEvaluation.development_selection_authority -and
    -not [bool]$perfectEvaluation.independent_validation_authority -and
    -not [bool]$perfectEvaluation.claims_if_valid.walking_acceptance -and
    -not [bool]$perfectEvaluation.claims_if_valid.material_robustness -and
    -not [bool]$perfectEvaluation.claims_if_valid.superiority -and
    -not [bool]$perfectEvaluation.claims_if_valid.cross_engine_equivalence -and
    -not [bool]$perfectEvaluation.physical_acceptance_authority
) "BW22L perfect synthetic result did not pass all 50 production gates"

$tie = Copy-Bw22lResult $perfect
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
$tieEvaluation = Invoke-Bw22lLateralDevelopmentEvaluation -Result $tie
Assert-Exact (
    [bool]$tieEvaluation.ok -and
    [string]$tieEvaluation.selected_candidate_id -ceq "NONE" -and
    -not [bool]$tieEvaluation.development_selection_authority -and
    -not [bool]$tieEvaluation.independent_validation_authority
) "BW22L all-tie valid negative did not select NONE"

$pairedRegression = Copy-Bw22lResult $perfect
$bRegression = $pairedRegression.cells | Where-Object {
    [string]$_.cell_id -ceq "development_mu057_s24011_bw22l_b"
} | Select-Object -First 1
$bRegression.walking_observed = $false
$bRegression.walking_gate_receipts.bounded_tilt = $false
$bRegression.failed_production_walking_gate_count = 1
$pairedRegressionEvaluation = Invoke-Bw22lLateralDevelopmentEvaluation `
    -Result $pairedRegression
Assert-Exact (
    [bool]$pairedRegressionEvaluation.ok -and
    [string]$pairedRegressionEvaluation.selected_candidate_id -ceq "NONE" -and
    [int]$pairedRegressionEvaluation.selected_candidate_paired_regression_count -eq 1 -and
    -not [bool]$pairedRegressionEvaluation.development_selection_authority -and
    -not [bool]$pairedRegressionEvaluation.independent_validation_authority
) "BW22L paired-regression result did not remain a valid no-selection result"

$wrongHost = Copy-Bw22lResult $perfect
$wrongHost.engine.godot_executable_sha256 = "0" * 64
Assert-Bw22lCanaryFails $wrongHost "BW22L_HOST_SOURCE" "wrong host"

$wrongPrerequisite = Copy-Bw22lResult $perfect
$wrongPrerequisite.prerequisites.bw22m_profile_closure_raw_sha256 = "0" * 64
Assert-Bw22lCanaryFails $wrongPrerequisite `
    "BW22L_PREREQUISITES" "wrong prerequisite"

$wrongDeclaration = Copy-Bw22lResult $perfect
$wrongDeclaration.declarations.candidates_raw_sha256 = "0" * 64
Assert-Bw22lCanaryFails $wrongDeclaration `
    "BW22L_DECLARATIONS" "wrong candidate declaration"

$missingCell = Copy-Bw22lResult $perfect
$missingCell.cells = @($missingCell.cells | Select-Object -Skip 1)
Assert-Bw22lCanaryFails $missingCell `
    "BW22L_MATRIX_CARDINALITY" "missing cell"

$wrongOrder = Copy-Bw22lResult $perfect
$temporary = $wrongOrder.cells[0]
$wrongOrder.cells[0] = $wrongOrder.cells[1]
$wrongOrder.cells[1] = $temporary
Assert-Bw22lCanaryFails $wrongOrder "BW22L_CELL_GATE" "cell order"

$wrongPolicy = Copy-Bw22lResult $perfect
$wrongPolicy.cells[1].controller_policy_id =
    "sporespore_balanced_wave_bw15f_b_v1"
Assert-Bw22lCanaryFails $wrongPolicy `
    "BW22L_POLICY_RELATIVE_IDENTITY" "candidate policy"

$failedPolicyRelativeReceipt = Copy-Bw22lResult $perfect
$failedPolicyRelativeReceipt.cells[1].policy_relative_common_execution.ok = $false
Assert-Bw22lCanaryFails $failedPolicyRelativeReceipt `
    "BW22L_POLICY_RELATIVE_IDENTITY" "failed policy-relative receipt"

$wrongGain = Copy-Bw22lResult $perfect
$wrongGain.cells[1].proportional_factor = 1.0
Assert-Bw22lCanaryFails $wrongGain "BW22L_CELL_GATE" "candidate gain"

$branchConditioned = Copy-Bw22lResult $perfect
$branchConditioned.cells[0].policy_branch_surface_count = 1
Assert-Bw22lCanaryFails $branchConditioned `
    "BW22L_OUTCOME_CONDITIONING" "branch conditioning"

$candidateNoResidual = Copy-Bw22lResult $perfect
$candidateNoResidual.cells[0].residual_application_observed = $false
$candidateNoResidual.cells[0].sdk_effective_application_count = 0
$candidateNoResidual.cells[0].maximum_absolute_applied_velocity_rad_s = 0.0
Assert-Bw22lCanaryFails $candidateNoResidual `
    "BW22L_CANDIDATE_APPLICATION" "candidate residual application"

$controlApplied = Copy-Bw22lResult $perfect
$controlApplied.cells[2].residual_application_observed = $true
$controlApplied.cells[2].sdk_effective_application_count = 1
$controlApplied.cells[2].maximum_absolute_applied_velocity_rad_s = 0.01
Assert-Bw22lCanaryFails $controlApplied `
    "BW22L_CONTROL_RESIDUAL_SEMANTICS" "control residual application"

$controlCombined = Copy-Bw22lResult $perfect
$controlCombined.cells[2].combined_application_gate_passed = $true
Assert-Bw22lCanaryFails $controlCombined `
    "BW22L_CONTROL_RESIDUAL_SEMANTICS" "control combined gate"

$controlBaseMissing = Copy-Bw22lResult $perfect
$controlBaseMissing.cells[2].sdk_native_motor_write_count = 0
$controlBaseMissing.cells[2].base_controller_application_observed = $false
$controlBaseMissing.cells[2].broad_base_controller_physical_influence_observed = $false
$controlBaseMissing.cells[2].physical_influence = $false
Assert-Bw22lCanaryFails $controlBaseMissing `
    "BW22L_CONTROL_BASE_INFLUENCE" "control base influence"

$walkingReceiptMismatch = Copy-Bw22lResult $perfect
$walkingReceiptMismatch.cells[1].walking_gate_receipts.bounded_tilt = $false
Assert-Bw22lCanaryFails $walkingReceiptMismatch `
    "BW22L_CELL_GATE" "walking receipt consistency"

$nonfiniteSteering = Copy-Bw22lResult $perfect
$nonfiniteSteering.cells[1].maximum_absolute_filtered_steering_fraction = "NaN"
Assert-Bw22lCanaryFails $nonfiniteSteering `
    "BW22L_STEERING_DIAGNOSTICS" "nonfinite steering"

$overboundSteering = Copy-Bw22lResult $perfect
$overboundSteering.cells[1].maximum_absolute_requested_steering_fraction = 0.41
Assert-Bw22lCanaryFails $overboundSteering `
    "BW22L_STEERING_DIAGNOSTICS" "overbound steering"

$missingFilterApplications = Copy-Bw22lResult $perfect
$missingFilterApplications.cells[1].steering_filter_application_count = 0
Assert-Bw22lCanaryFails $missingFilterApplications `
    "BW22L_STEERING_DIAGNOSTICS" "missing steering filter applications"

$wrongProfileBinding = Copy-Bw22lResult $perfect
$wrongProfileBinding.cells[1].profile_binding_exact = $false
Assert-Bw22lCanaryFails $wrongProfileBinding `
    "BW22L_CELL_GATE" "profile binding"

$pairMismatch = Copy-Bw22lResult $perfect
$pairMismatch.cells[1].fixture_spec_sha256 = "sha256:" + ("e" * 64)
Assert-Bw22lCanaryFails $pairMismatch "BW22L_PAIR_IDENTITY" "paired identity"

$perturbationMismatch = Copy-Bw22lResult $perfect
$perturbationMismatch.cells[1].initial_perturbation.gait_phase_offset_ticks = 99
Assert-Bw22lCanaryFails $perturbationMismatch `
    "BW22L_PAIRED_PERTURBATION" "paired perturbation"

$zeroActuated = Copy-Bw22lResult $perfect
$zeroActuated.cells[27].sdk_native_motor_write_count = 1
$zeroActuated.cells[27].base_controller_application_observed = $true
Assert-Bw22lCanaryFails $zeroActuated `
    "BW22L_ZERO_SAFETY" "zero-friction native actuation"

$selectorMutation = Copy-Bw22lResult $perfect
$selectorMutation.selector.selection_vector[0] = "maximum_tilt_rad"
Assert-Bw22lCanaryFails $selectorMutation `
    "BW22L_SELECTOR_DECLARATION" "selector mutation"

$preinvokedSelector = Copy-Bw22lResult $perfect
$preinvokedSelector.selector_invocation_count_before_evaluation = 1
$preinvokedSelector.pre_evaluation_selected_candidate_id = "BW22L-B"
Assert-Bw22lCanaryFails $preinvokedSelector `
    "BW22L_SELECTOR_PREINVOCATION" "pre-invoked selector"

$claimInflation = Copy-Bw22lResult $perfect
$claimInflation.declared_claims.material_robustness = $true
Assert-Bw22lCanaryFails $claimInflation `
    "BW22L_CLAIM_INFLATION" "claim inflation"

Write-Host (
    "BW22L_LATERAL_DEVELOPMENT_GATE_PASS gates=50 cells=28 " +
    "candidates=24 controls=3 safety=1 canaries=23 roundtrip=True " +
    "tie_selects_none=True paired_regression_selects_none=True worlds=0 " +
    "development_only=True validation_authority=False physical_authority=False"
)
