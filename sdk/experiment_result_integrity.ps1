#requires -Version 7.0

<#
.SYNOPSIS
Fail-closed aggregation for retained physical-experiment result objects.

.DESCRIPTION
PowerShell's property adapter does not expose OrderedDictionary keys to
Measure-Object -Property. Physical runners intentionally use ordered
dictionaries for deterministic JSON field order, so aggregating those objects
through Measure-Object -Property can return $null and then silently become zero
after an [int] cast.

These helpers resolve every required field explicitly and reject missing,
null, nonnumeric, NaN, or infinite values before constructing aggregate
metrics. Future physical runners should exercise this exact code with both a
perfect all-zero synthetic matrix and a deliberately nonzero canary before
opening a world.
#>

function Get-SporeRequiredResultField {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Result,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if ($Result -is [System.Collections.IDictionary]) {
        if (-not $Result.Contains($Name)) {
            throw "Experiment result is missing required field '$Name'"
        }
        return $Result[$Name]
    }

    $property = $Result.PSObject.Properties[$Name]
    if ($null -eq $property) {
        throw "Experiment result is missing required field '$Name'"
    }
    return $property.Value
}

function Get-SporeRequiredFiniteDouble {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Result,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $value = Get-SporeRequiredResultField -Result $Result -Name $Name
    if ($null -eq $value) {
        throw "Experiment result field '$Name' is null"
    }
    try {
        $number = [double]$value
    } catch {
        throw "Experiment result field '$Name' is not numeric"
    }
    if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) {
        throw "Experiment result field '$Name' is not finite"
    }
    return $number
}

function Get-SporeRequiredNonnegativeInt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Result,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $value = Get-SporeRequiredResultField -Result $Result -Name $Name
    if ($null -eq $value) {
        throw "Experiment result field '$Name' is null"
    }
    try {
        $numericValue = [double]$value
    } catch {
        throw "Experiment result field '$Name' is not an integer"
    }
    if (
        [double]::IsNaN($numericValue) -or
        [double]::IsInfinity($numericValue) -or
        $numericValue -ne [math]::Truncate($numericValue)
    ) {
        throw "Experiment result field '$Name' is not an integer"
    }
    if ($numericValue -lt 0 -or $numericValue -gt [int]::MaxValue) {
        throw "Experiment result field '$Name' is outside the nonnegative Int32 range"
    }
    return [int]$numericValue
}

function Get-SporeRequiredBool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Result,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $value = Get-SporeRequiredResultField -Result $Result -Name $Name
    if ($value -isnot [bool]) {
        throw "Experiment result field '$Name' is not a Boolean"
    }
    return [bool]$value
}

function Measure-SporeExperimentResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Results,
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ExpectedCount
    )

    $completeCount = 0
    $harnessPassCount = 0
    $integrityPassCount = 0
    $mechanismPassCount = 0
    $applicationPassCount = 0
    $walkingPassCount = 0
    [long]$failedWalkingGateTotal = 0
    [long]$releaseTimeoutTotal = 0
    [double]$maximumLateral = [double]::NegativeInfinity
    [double]$aggregateLateral = 0.0
    [double]$aggregateCrossTrack = 0.0

    foreach ($result in $Results) {
        $timedOut = Get-SporeRequiredBool -Result $result -Name "timed_out"
        $receiptParsed = (
            Get-SporeRequiredBool -Result $result -Name "receipt_parsed"
        )
        if (-not $timedOut -and $receiptParsed) {
            $completeCount += 1
        }
        if (Get-SporeRequiredBool -Result $result -Name "harness_passed") {
            $harnessPassCount += 1
        }
        if (
            Get-SporeRequiredBool `
                -Result $result `
                -Name "common_execution_integrity"
        ) {
            $integrityPassCount += 1
        }
        if (
            Get-SporeRequiredBool `
                -Result $result `
                -Name "mechanism_gate_passed"
        ) {
            $mechanismPassCount += 1
        }
        if (
            Get-SporeRequiredBool `
                -Result $result `
                -Name "combined_application_gate_passed"
        ) {
            $applicationPassCount += 1
        }
        if (Get-SporeRequiredBool -Result $result -Name "walking_observed") {
            $walkingPassCount += 1
        }

        $failedWalkingGateTotal += (
            Get-SporeRequiredNonnegativeInt `
                -Result $result `
                -Name "failed_production_walking_gate_count"
        )
        $releaseTimeoutTotal += (
            Get-SporeRequiredNonnegativeInt `
                -Result $result `
                -Name "release_timeout_count"
        )
        if (
            $failedWalkingGateTotal -gt [int]::MaxValue -or
            $releaseTimeoutTotal -gt [int]::MaxValue
        ) {
            throw "Experiment aggregate counter exceeded the Int32 report range"
        }

        $lateral = Get-SporeRequiredFiniteDouble `
            -Result $result `
            -Name "normalized_absolute_task_frame_lateral_displacement"
        $crossTrack = Get-SporeRequiredFiniteDouble `
            -Result $result `
            -Name "cumulative_absolute_cross_track_error_m_s"
        if ($lateral -gt $maximumLateral) {
            $maximumLateral = $lateral
        }
        $aggregateLateral += $lateral
        $aggregateCrossTrack += $crossTrack
        if (
            [double]::IsNaN($aggregateLateral) -or
            [double]::IsInfinity($aggregateLateral) -or
            [double]::IsNaN($aggregateCrossTrack) -or
            [double]::IsInfinity($aggregateCrossTrack)
        ) {
            throw "Experiment floating-point aggregate is not finite"
        }
    }

    $observedCount = $Results.Count
    return [ordered]@{
        observed_world_count = $observedCount
        complete_receipt_count = $completeCount
        harness_pass_count = $harnessPassCount
        integrity_pass_count = $integrityPassCount
        mechanism_pass_count = $mechanismPassCount
        combined_application_pass_count = $applicationPassCount
        walking_conjunction_pass_count = $walkingPassCount
        walking_conjunction_failure_count = $observedCount - $walkingPassCount
        aggregate_failed_production_walking_gate_count = (
            [int]$failedWalkingGateTotal
        )
        aggregate_release_timeout_count = [int]$releaseTimeoutTotal
        maximum_normalized_absolute_task_frame_lateral_displacement = $(
            if ($observedCount -gt 0) { $maximumLateral } else { $null }
        )
        aggregate_normalized_absolute_task_frame_lateral_displacement = (
            $aggregateLateral
        )
        aggregate_cumulative_absolute_cross_track_error_m_s = (
            $aggregateCrossTrack
        )
        integrity_and_mechanism_complete = (
            $observedCount -eq $ExpectedCount -and
            $completeCount -eq $ExpectedCount -and
            $harnessPassCount -eq $ExpectedCount -and
            $integrityPassCount -eq $ExpectedCount -and
            $mechanismPassCount -eq $ExpectedCount -and
            $applicationPassCount -eq $ExpectedCount
        )
    }
}

function Test-SporePolicyRelativeExecutionComplete {
    <#
    .SYNOPSIS
    Evaluate the complete execution gate using the application count declared
    by a specific policy.

    .DESCRIPTION
    A safe-zero control and an active treatment do not have the same correct
    application count. The control must prove exact non-application while the
    treatment must prove application. Requiring every policy to report
    ExpectedCount applications makes a declared zero-influence control
    structurally ineligible even when every other integrity gate passes.

    Physical runners must call this function on synthetic perfect results
    derived from each declared policy before constructing a world, then call
    the same function on retained physical results.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Metrics,
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ExpectedCount,
        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$ExpectedApplicationPassCount
    )

    if ($ExpectedApplicationPassCount -gt $ExpectedCount) {
        throw (
            "Expected application pass count exceeds the expected result " +
            "count"
        )
    }

    foreach (
        $fieldName in @(
            "observed_world_count",
            "complete_receipt_count",
            "harness_pass_count",
            "integrity_pass_count",
            "mechanism_pass_count",
            "combined_application_pass_count"
        )
    ) {
        [void](
            Get-SporeRequiredNonnegativeInt `
                -Result $Metrics `
                -Name $fieldName
        )
    }

    return (
        [int](
            Get-SporeRequiredResultField `
                -Result $Metrics `
                -Name "observed_world_count"
        ) -eq $ExpectedCount -and
        [int](
            Get-SporeRequiredResultField `
                -Result $Metrics `
                -Name "complete_receipt_count"
        ) -eq $ExpectedCount -and
        [int](
            Get-SporeRequiredResultField `
                -Result $Metrics `
                -Name "harness_pass_count"
        ) -eq $ExpectedCount -and
        [int](
            Get-SporeRequiredResultField `
                -Result $Metrics `
                -Name "integrity_pass_count"
        ) -eq $ExpectedCount -and
        [int](
            Get-SporeRequiredResultField `
                -Result $Metrics `
                -Name "mechanism_pass_count"
        ) -eq $ExpectedCount -and
        [int](
            Get-SporeRequiredResultField `
                -Result $Metrics `
                -Name "combined_application_pass_count"
        ) -eq $ExpectedApplicationPassCount
    )
}

function Measure-SporePolicyRelativeExperimentResults {
    <#
    .SYNOPSIS
    Aggregate results and append the candidate-relative eligibility contract.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Results,
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ExpectedCount,
        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$ExpectedApplicationPassCount
    )

    $metrics = Measure-SporeExperimentResults `
        -Results $Results `
        -ExpectedCount $ExpectedCount
    $policyRelativeComplete = Test-SporePolicyRelativeExecutionComplete `
        -Metrics $metrics `
        -ExpectedCount $ExpectedCount `
        -ExpectedApplicationPassCount $ExpectedApplicationPassCount
    $metrics["expected_application_pass_count"] = (
        $ExpectedApplicationPassCount
    )
    $metrics["policy_relative_execution_complete"] = (
        $policyRelativeComplete
    )
    return $metrics
}
