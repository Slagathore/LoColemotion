#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$gatePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw28y_yaw_development_gate.ps1"
. $gatePath

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-Bw28yValue {
    param([Parameter(Mandatory)][object]$Value)
    return $Value | ConvertTo-Json -Depth 64 |
        ConvertFrom-Json -AsHashtable -Depth 64
}

$fullWalkingGateKeys = @(
    "bounded_anchor_error",
    "bounded_hinge_axis_error",
    "bounded_joint_only_lateral_stride_steering",
    "bounded_lateral_drift",
    "bounded_tilt",
    "bounded_torso_height",
    "bounded_yaw_drift",
    "contact_gated_evidence_horizon_completed",
    "contact_gating_completed_without_timeout",
    "every_contact_observer_executed",
    "every_limb_completed_evidence_gait_horizon",
    "every_limb_forward_relocation",
    "every_limb_two_contact_cycles",
    "evidence_four_contact_stance",
    "fixture_spec_compiled_before_world_creation",
    "initial_four_contact_stance",
    "initial_perturbation_within_declared_envelope",
    "minimum_evidence_forward_translation",
    "minimum_final_forward_translation",
    "native_sdk_exclusive_post_settle_actuation",
    "no_torso_force_or_impulse_or_velocity_or_transform_command",
    "no_world_reset",
    "one_continuous_world",
    "pinned_jolt_solver_settings",
    "terminal_four_contact_recovery",
    "zero_torso_contact"
)

function New-Bw28yRawShapedCell {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$FinalCell,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Expected
    )
    $raw = Copy-Bw28yValue $FinalCell
    foreach ($field in @(
        "schema_version",
        "campaign_id",
        "gate_id",
        "cell_id",
        "role",
        "campaign_seed",
        "authored_friction",
        "controller_coefficient",
        "material_profile_id",
        "material_profile_sha256",
        "candidate_id",
        "candidate_composition_digest",
        "declared_controller_policy_id",
        "proportional_factor",
        "velocity_factor",
        "yaw_error_stride_gain_per_rad",
        "global_requested_correction_scale",
        "walking_observed",
        "failed_production_walking_gate_count"
    )) {
        $raw.Remove($field)
    }
    if ([string]$Expected.role -ceq "safety") {
        foreach ($field in @(
            "controller_policy_id",
            "controller_runtime_profile_sha256",
            "policy_branch_surface_count",
            "material_condition_count",
            "seed_condition_count",
            "failure_identity_condition_count",
            "outcome_condition_count",
            "walking_gate_receipts"
        )) {
            $raw.Remove($field)
        }
        return $raw
    }

    $decisionGates = $FinalCell.walking_gate_receipts
    $fullWalking = [ordered]@{}
    foreach ($key in $fullWalkingGateKeys) {
        $fullWalking[$key] = if ($decisionGates.Contains($key)) {
            [bool]$decisionGates[$key]
        } else { $true }
    }
    $raw.walking_gate_receipts = $fullWalking
    return $raw
}

$perfect = New-Bw28yPerfectSyntheticYawDevelopmentResult
$expectedCells = @(Get-Bw28yExpectedCells)
$rawCells = [Collections.Generic.List[object]]::new()
$composedCells = [Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
    $raw = New-Bw28yRawShapedCell `
        -FinalCell $perfect.cells[$index] `
        -Expected $expectedCells[$index]
    $rawCells.Add($raw)
    $composedCells.Add((
        ConvertTo-Bw28yFinalCellReceipt `
            -RawCell $raw `
            -Expected $expectedCells[$index]
    ))
}

$composed = Copy-Bw28yValue $perfect
$composed.cells = @($composedCells)
$composedEvaluation = Invoke-Bw28yYawDevelopmentEvaluation -Result $composed
$nonSafety = @($composed.cells | Where-Object role -CNE "safety")
$safety = @($composed.cells | Where-Object role -CEQ "safety") |
    Select-Object -First 1
Assert-Exact (
    [bool]$composedEvaluation.ok -and
    [int]$composedEvaluation.reconstructed_passed_gate_count -eq 50 -and
    @($composed.cells).Count -eq 28 -and
    $nonSafety.Count -eq 27 -and
    @($nonSafety | Where-Object {
        [int]$_.walking_gate_receipts.Count -ne 4 -or
        -not $_.Contains("controller_coefficient") -or
        -not $_.Contains("declared_controller_policy_id") -or
        -not $_.Contains("controller_runtime_profile_sha256") -or
        -not $_.Contains("yaw_error_stride_gain_per_rad") -or
        -not $_.Contains("failed_production_walking_gate_count")
    }).Count -eq 0 -and
    [int]$safety.walking_gate_receipts.Count -eq 0 -and
    [double]$safety.controller_coefficient -eq 0.0 -and
    [string]$safety.declared_controller_policy_id -ceq "NONE" -and
    [string]$safety.controller_runtime_profile_sha256 -ceq "NONE" -and
    [int]$safety.failed_production_walking_gate_count -eq 0
) "BW28Y real-shaped final composition did not pass the complete evaluator"

# BW25Y defect family 1: bypassing the sole composer with the inherited
# full walking dictionary
# must fail the production evaluator.
$fullDictionaryBypass = Copy-Bw28yValue $composed
$fullDictionaryBypass.cells[1].walking_gate_receipts =
    (Copy-Bw28yValue $rawCells[1].walking_gate_receipts)
$fullDictionaryEvaluation = Invoke-Bw28yYawDevelopmentEvaluation `
    -Result $fullDictionaryBypass
Assert-Exact (
    -not [bool]$fullDictionaryEvaluation.ok -and
    @($fullDictionaryEvaluation.failure_codes) -contains "BW28Y_CELL_GATE"
) "BW28Y unprojected inherited walking dictionary bypass did not fail"

# BW25Y defect family 2: a missing characterized controller coefficient must fail.
$coefficientBypass = Copy-Bw28yValue $composed
$coefficientBypass.cells[1].Remove("controller_coefficient")
$coefficientEvaluation = Invoke-Bw28yYawDevelopmentEvaluation `
    -Result $coefficientBypass
Assert-Exact (
    -not [bool]$coefficientEvaluation.ok -and
    @($coefficientEvaluation.failure_codes) -contains "BW28Y_CELL_GATE"
) "BW28Y missing-controller-coefficient bypass did not fail"

# BW25Y defect family 3: an incomplete safety receipt must fail before aggregation.
$safetyBypass = Copy-Bw28yValue $composed
foreach ($field in @(
    "controller_coefficient",
    "declared_controller_policy_id",
    "controller_runtime_profile_sha256",
    "proportional_factor",
    "velocity_factor",
    "yaw_error_stride_gain_per_rad",
    "seed_condition_count",
    "failure_identity_condition_count",
    "outcome_condition_count",
    "failed_production_walking_gate_count"
)) {
    $safetyBypass.cells[27].Remove($field)
}
$safetyEvaluation = Invoke-Bw28yYawDevelopmentEvaluation -Result $safetyBypass
Assert-Exact (
    -not [bool]$safetyEvaluation.ok -and
    @($safetyEvaluation.failure_codes) -contains "BW28Y_CELL_GATE"
) "BW28Y incomplete-safety-schema bypass did not fail"

# The composer itself must reject a raw non-safety receipt lacking a declared
# decision key; it may not silently manufacture an observed walking outcome.
$missingDecisionKey = Copy-Bw28yValue $rawCells[1]
$missingDecisionKey.walking_gate_receipts.Remove("bounded_tilt")
$missingDecisionRejected = $false
try {
    [void](ConvertTo-Bw28yFinalCellReceipt `
        -RawCell $missingDecisionKey `
        -Expected $expectedCells[1])
} catch {
    $missingDecisionRejected = $_.Exception.Message -like
        "*missing decision walking key: bounded_tilt*"
}
Assert-Exact (
    $missingDecisionRejected
) "BW28Y final composer did not reject a missing decision walking key"

# The composer supplies declarations but preserves observed policy identity.
# Therefore it cannot hide a runtime-policy mismatch.
$wrongObservedPolicy = Copy-Bw28yValue $rawCells[1]
$wrongObservedPolicy.controller_policy_id =
    "sporespore_balanced_wave_bw15f_b_v1"
$wrongPolicyComposed = ConvertTo-Bw28yFinalCellReceipt `
    -RawCell $wrongObservedPolicy `
    -Expected $expectedCells[1]
$wrongPolicyResult = Copy-Bw28yValue $composed
$wrongPolicyResult.cells[1] = $wrongPolicyComposed
$wrongPolicyEvaluation = Invoke-Bw28yYawDevelopmentEvaluation `
    -Result $wrongPolicyResult
Assert-Exact (
    -not [bool]$wrongPolicyEvaluation.ok -and
    @($wrongPolicyEvaluation.failure_codes) -contains
        "BW28Y_POLICY_RELATIVE_IDENTITY"
) "BW28Y final composer masked an observed runtime-policy mismatch"

# A negative physical outcome with complete mechanism and execution integrity
# is valid evidence, not infrastructure failure.
$negativeRaw = Copy-Bw28yValue $rawCells[1]
$negativeRaw.walking_gate_receipts.bounded_tilt = $false
$negativeFinal = ConvertTo-Bw28yFinalCellReceipt `
    -RawCell $negativeRaw `
    -Expected $expectedCells[1]
$negativeResult = Copy-Bw28yValue $composed
$negativeResult.cells[1] = $negativeFinal
$negativeEvaluation = Invoke-Bw28yYawDevelopmentEvaluation -Result $negativeResult
Assert-Exact (
    [bool]$negativeEvaluation.ok -and
    [bool]$negativeFinal.common_execution_integrity -and
    [bool]$negativeFinal.outcome_complete -and
    -not [bool]$negativeFinal.walking_observed -and
    [int]$negativeFinal.failed_production_walking_gate_count -eq 1 -and
    -not [bool]$negativeEvaluation.claims_if_valid.walking_acceptance -and
    -not [bool]$negativeEvaluation.physical_acceptance_authority
) "BW28Y valid negative walk was confused with infrastructure failure"

Write-Host (
    "BW28Y_RECEIPT_PARITY_PASS raw_cells=28 composed_cells=28 " +
    "decision_keys=4 defect_canaries=5 negative_walking_integrity=True " +
    "synthetic_world_receipts=28 actual_worlds=0 outcomes_exposed=False " +
    "physical_authority=False"
)
