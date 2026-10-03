#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
. (Join-Path $repoRoot "sdk\experiment_result_integrity.ps1")

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function New-SyntheticResult {
    param([Parameter(Mandatory)][int]$Ordinal)
    return [ordered]@{
        ordinal = $Ordinal
        timed_out = $false
        receipt_parsed = $true
        harness_passed = $true
        common_execution_integrity = $true
        mechanism_gate_passed = $true
        combined_application_gate_passed = $true
        walking_observed = $true
        failed_production_walking_gate_count = 0
        release_timeout_count = 0
        normalized_absolute_task_frame_lateral_displacement = 0.0
        cumulative_absolute_cross_track_error_m_s = 0.0
    }
}

$perfect = @(
    foreach ($ordinal in 1..36) {
        New-SyntheticResult -Ordinal $ordinal
    }
)
Assert-Exact (
    $perfect[0] -is [System.Collections.Specialized.OrderedDictionary]
) "Synthetic preflight did not exercise the live runner's ordered object type"

$perfectMetrics = Measure-SporeExperimentResults `
    -Results $perfect `
    -ExpectedCount 36
Assert-Exact (
    [int]$perfectMetrics.observed_world_count -eq 36 -and
    [int]$perfectMetrics.complete_receipt_count -eq 36 -and
    [int]$perfectMetrics.harness_pass_count -eq 36 -and
    [int]$perfectMetrics.integrity_pass_count -eq 36 -and
    [int]$perfectMetrics.mechanism_pass_count -eq 36 -and
    [int]$perfectMetrics.combined_application_pass_count -eq 36 -and
    [int]$perfectMetrics.walking_conjunction_pass_count -eq 36 -and
    [int]$perfectMetrics.walking_conjunction_failure_count -eq 0 -and
    [int]$perfectMetrics.aggregate_failed_production_walking_gate_count -eq 0 -and
    [int]$perfectMetrics.aggregate_release_timeout_count -eq 0 -and
    [double]$perfectMetrics.maximum_normalized_absolute_task_frame_lateral_displacement -eq 0.0 -and
    [double]$perfectMetrics.aggregate_normalized_absolute_task_frame_lateral_displacement -eq 0.0 -and
    [double]$perfectMetrics.aggregate_cumulative_absolute_cross_track_error_m_s -eq 0.0 -and
    [bool]$perfectMetrics.integrity_and_mechanism_complete
) "A perfect synthetic matrix could not pass the exact aggregate gate"

# This is deliberately unlike an acceptable physical result. It proves that
# nonzero values propagate instead of becoming false zeroes through a missing
# property-adapter sum.
$canary = @(
    foreach ($ordinal in 1..36) {
        New-SyntheticResult -Ordinal $ordinal
    }
)
$canary[6]["walking_observed"] = $false
$canary[6]["failed_production_walking_gate_count"] = 3
$canary[6]["release_timeout_count"] = 2
$canary[6]["normalized_absolute_task_frame_lateral_displacement"] = 1.25
$canary[6]["cumulative_absolute_cross_track_error_m_s"] = 0.75
$canary[11]["normalized_absolute_task_frame_lateral_displacement"] = 0.5
$canary[11]["cumulative_absolute_cross_track_error_m_s"] = 0.25

function Invoke-LegacyOrderedDictionarySum {
    param([Parameter(Mandatory)][object[]]$Results)
    Set-StrictMode -Off
    return (
        $Results |
            Measure-Object `
                -Property failed_production_walking_gate_count `
                -Sum `
                -ErrorAction SilentlyContinue
    ).Sum
}
$legacyPropertySum = Invoke-LegacyOrderedDictionarySum -Results $canary
Assert-Exact (
    $null -eq $legacyPropertySum
) "The retained ordered-dictionary negative control no longer reproduces"

$canaryMetrics = Measure-SporeExperimentResults `
    -Results $canary `
    -ExpectedCount 36
Assert-Exact (
    [int]$canaryMetrics.walking_conjunction_pass_count -eq 35 -and
    [int]$canaryMetrics.walking_conjunction_failure_count -eq 1 -and
    [int]$canaryMetrics.aggregate_failed_production_walking_gate_count -eq 3 -and
    [int]$canaryMetrics.aggregate_release_timeout_count -eq 2 -and
    [double]$canaryMetrics.maximum_normalized_absolute_task_frame_lateral_displacement -eq 1.25 -and
    [double]$canaryMetrics.aggregate_normalized_absolute_task_frame_lateral_displacement -eq 1.75 -and
    [double]$canaryMetrics.aggregate_cumulative_absolute_cross_track_error_m_s -eq 1.0 -and
    [bool]$canaryMetrics.integrity_and_mechanism_complete
) "The nonzero aggregate sentinel did not propagate exact values"

$roundTrip = (
    $canary |
        ConvertTo-Json -Depth 5 -Compress |
        ConvertFrom-Json -AsHashtable
)
$roundTripMetrics = Measure-SporeExperimentResults `
    -Results @($roundTrip) `
    -ExpectedCount 36
Assert-Exact (
    (
        $roundTripMetrics |
            ConvertTo-Json -Depth 5 -Compress
    ) -ceq (
        $canaryMetrics |
            ConvertTo-Json -Depth 5 -Compress
    )
) "Serialized report objects produced different aggregate metrics"

$missingField = New-SyntheticResult -Ordinal 1
$missingField.Remove("release_timeout_count")
$missingFieldRejected = $false
try {
    [void](
        Measure-SporeExperimentResults `
            -Results @($missingField) `
            -ExpectedCount 1
    )
} catch {
    $missingFieldRejected = (
        $_.Exception.Message -like
            "*missing required field 'release_timeout_count'*"
    )
}
Assert-Exact (
    $missingFieldRejected
) "A result with a missing aggregate field did not fail closed"

$fractionalCounter = New-SyntheticResult -Ordinal 1
$fractionalCounter["release_timeout_count"] = 0.5
$fractionalCounterRejected = $false
try {
    [void](
        Measure-SporeExperimentResults `
            -Results @($fractionalCounter) `
            -ExpectedCount 1
    )
} catch {
    $fractionalCounterRejected = (
        $_.Exception.Message -like
            "*field 'release_timeout_count' is not an integer*"
    )
}
Assert-Exact (
    $fractionalCounterRejected
) "A fractional aggregate counter did not fail closed"

# Exercise the complete gate using results emitted from the declared policy,
# not a generic result that always claims physical application. A zero-output
# control is perfect only when all application gates remain false. An active
# treatment is perfect only when every application gate is true.
$safeZeroControl = @(
    foreach ($ordinal in 1..36) {
        $result = New-SyntheticResult -Ordinal $ordinal
        $result["combined_application_gate_passed"] = $false
        $result
    }
)
$safeZeroControlMetrics = Measure-SporePolicyRelativeExperimentResults `
    -Results $safeZeroControl `
    -ExpectedCount 36 `
    -ExpectedApplicationPassCount 0
Assert-Exact (
    [int]$safeZeroControlMetrics.combined_application_pass_count -eq 0 -and
    [int]$safeZeroControlMetrics.expected_application_pass_count -eq 0 -and
    [bool]$safeZeroControlMetrics.policy_relative_execution_complete -and
    -not [bool]$safeZeroControlMetrics.integrity_and_mechanism_complete -and
    -not (
        Test-SporePolicyRelativeExecutionComplete `
            -Metrics $safeZeroControlMetrics `
            -ExpectedCount 36 `
            -ExpectedApplicationPassCount 36
    )
) "The policy-relative safe-zero control gate is not satisfiable and exact"

$activeTreatmentMetrics = Measure-SporePolicyRelativeExperimentResults `
    -Results $perfect `
    -ExpectedCount 36 `
    -ExpectedApplicationPassCount 36
Assert-Exact (
    [int]$activeTreatmentMetrics.combined_application_pass_count -eq 36 -and
    [int]$activeTreatmentMetrics.expected_application_pass_count -eq 36 -and
    [bool]$activeTreatmentMetrics.policy_relative_execution_complete
) "The policy-relative active-treatment gate is not satisfiable and exact"

$impossibleApplicationExpectationRejected = $false
try {
    [void](
        Measure-SporePolicyRelativeExperimentResults `
            -Results $perfect `
            -ExpectedCount 36 `
            -ExpectedApplicationPassCount 37
    )
} catch {
    $impossibleApplicationExpectationRejected = (
        $_.Exception.Message -like
            "*exceeds the expected result count*"
    )
}
Assert-Exact (
    $impossibleApplicationExpectationRejected
) "An impossible policy-relative application count did not fail closed"

Write-Host (
    "EXPERIMENT_RESULT_INTEGRITY_PREFLIGHT_PASS " +
    "perfect=36 canary_failed_gates=3 canary_timeouts=2 " +
    "ordered_dictionary_negative_control=true missing_field_rejected=true " +
    "fractional_counter_rejected=true policy_relative_control=true " +
    "policy_relative_treatment=true impossible_application_rejected=true"
)
