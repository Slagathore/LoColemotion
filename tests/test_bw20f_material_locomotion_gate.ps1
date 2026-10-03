#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$gatePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw20f_material_locomotion_gate.ps1"
. $gatePath

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Copy-Bw20fLocomotionResult {
    param([Parameter(Mandatory)][object]$Value)
    return (
        $Value | ConvertTo-Json -Depth 64 |
            ConvertFrom-Json -AsHashtable
    )
}

function Assert-Bw20fCanaryFails {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Result,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $evaluation = Test-Bw20fMaterialLocomotionResult -Result $Result
    Assert-Exact (
        -not [bool]$evaluation.ok -and
        @($evaluation.failure_codes) -contains $FailureCode -and
        -not [bool]$evaluation.claims_if_accepted.material_robustness
    ) "BW20F-LOCOMOTION $Label canary did not fail closed"
}

$perfect = New-Bw20fPerfectSyntheticMaterialLocomotionResult
$perfectEvaluation = Test-Bw20fMaterialLocomotionResult -Result $perfect
$roundTrip = Copy-Bw20fLocomotionResult $perfect
$roundTripEvaluation = Test-Bw20fMaterialLocomotionResult -Result $roundTrip
Assert-Exact (
    [bool]$perfectEvaluation.ok -and
    [bool]$roundTripEvaluation.ok -and
    [int]$perfectEvaluation.reconstructed_passed_gate_count -eq 28 -and
    [int]$perfectEvaluation.reconstructed_failed_gate_count -eq 0 -and
    @($perfectEvaluation.gates).Count -eq 28 -and
    [int]$perfectEvaluation.observed_world_count -eq 17 -and
    [int]$perfectEvaluation.treatment_count -eq 12 -and
    [int]$perfectEvaluation.control_count -eq 4 -and
    [int]$perfectEvaluation.safety_count -eq 1 -and
    [int]$perfectEvaluation.cell_pass_count -eq 17 -and
    [int]$perfectEvaluation.pair_identity_pass_count -eq 4 -and
    [bool]$perfectEvaluation.claims_if_accepted.material_robustness -and
    -not [bool]$perfectEvaluation.claims_if_accepted.continuous_friction_coverage -and
    -not [bool]$perfectEvaluation.claims_if_accepted.superiority -and
    -not [bool]$perfectEvaluation.claims_if_accepted.cross_engine_equivalence -and
    -not [bool]$perfectEvaluation.physical_acceptance_authority
) "BW20F-LOCOMOTION perfect synthetic result did not pass all 28 production gates"

$wrongHost = Copy-Bw20fLocomotionResult $perfect
$wrongHost.engine.godot_executable_sha256 = "0" * 64
Assert-Bw20fCanaryFails $wrongHost "BW20F_LOCOMOTION_HOST_SOURCE" "wrong host"

$missingCell = Copy-Bw20fLocomotionResult $perfect
$missingCell.cells = @($missingCell.cells | Select-Object -Skip 1)
Assert-Bw20fCanaryFails $missingCell `
    "BW20F_LOCOMOTION_MATRIX_CARDINALITY" "missing cell"

$wrongOrder = Copy-Bw20fLocomotionResult $perfect
$temporary = $wrongOrder.cells[0]
$wrongOrder.cells[0] = $wrongOrder.cells[1]
$wrongOrder.cells[1] = $temporary
Assert-Bw20fCanaryFails $wrongOrder "BW20F_LOCOMOTION_CELL_GATE" "role ordering"

$treatmentNoApplication = Copy-Bw20fLocomotionResult $perfect
$treatmentNoApplication.cells[0].sdk_effective_application_count = 0
$treatmentNoApplication.cells[0].physical_influence = $false
Assert-Bw20fCanaryFails $treatmentNoApplication `
    "BW20F_LOCOMOTION_TREATMENT_APPLICATION" "treatment application"

$controlApplied = Copy-Bw20fLocomotionResult $perfect
$controlApplied.cells[1].sdk_effective_application_count = 1
$controlApplied.cells[1].physical_influence = $true
Assert-Bw20fCanaryFails $controlApplied `
    "BW20F_LOCOMOTION_CONTROL_MECHANISM" "control application"

$walkingFailure = Copy-Bw20fLocomotionResult $perfect
$walkingFailure.cells[2].walking_gate_receipts.forward_progress = $false
$walkingFailure.cells[2].walking_observed = $false
Assert-Bw20fCanaryFails $walkingFailure `
    "BW20F_LOCOMOTION_TREATMENT_WALKING" "ordinary walking"

$zeroActuated = Copy-Bw20fLocomotionResult $perfect
$zeroActuated.cells[16].sdk_native_motor_write_count = 1
Assert-Bw20fCanaryFails $zeroActuated `
    "BW20F_LOCOMOTION_ZERO_SAFETY" "zero-friction native actuation"

$wrongProfile = Copy-Bw20fLocomotionResult $perfect
$wrongProfile.cells[4].material_profile_sha256 = "sha256:" + ("f" * 64)
Assert-Bw20fCanaryFails $wrongProfile "BW20F_LOCOMOTION_CELL_GATE" "profile binding"

$nonfinite = Copy-Bw20fLocomotionResult $perfect
$nonfinite.cells[8].maximum_tilt_rad = "NaN"
Assert-Bw20fCanaryFails $nonfinite "BW20F_LOCOMOTION_CELL_GATE" "nonfinite receipt"

$pairMismatch = Copy-Bw20fLocomotionResult $perfect
$pairMismatch.cells[13].fixture_spec_sha256 = "sha256:" + ("e" * 64)
Assert-Bw20fCanaryFails $pairMismatch `
    "BW20F_LOCOMOTION_PAIR_IDENTITY" "paired identity"

$claimInflation = Copy-Bw20fLocomotionResult $perfect
$claimInflation.declared_claims.superiority = $true
Assert-Bw20fCanaryFails $claimInflation `
    "BW20F_LOCOMOTION_CLAIM_INFLATION" "claim inflation"

$wrongPrerequisite = Copy-Bw20fLocomotionResult $perfect
$wrongPrerequisite.prerequisites.stage_2_closure_raw_sha256 = "0" * 64
Assert-Bw20fCanaryFails $wrongPrerequisite `
    "BW20F_LOCOMOTION_PREREQUISITES" "prerequisite evidence"

Write-Host (
    "BW20F_MATERIAL_LOCOMOTION_GATE_PASS gates=28 cells=17 " +
    "treatments=12 controls=4 safety=1 pairs=4 canaries=12 " +
    "roundtrip=True worlds=0 terminal_separation_gate=False " +
    "superiority=False physical_authority=False"
)
