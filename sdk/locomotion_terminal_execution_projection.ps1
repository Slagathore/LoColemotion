#requires -Version 7.0

Set-StrictMode -Version Latest

function Test-SporeSporeNonNegativeTerminalCount {
    param([Parameter(Mandatory)]$Value)

    if ($Value -is [bool] -or $null -eq $Value) { return $false }
    $typeCode = [Type]::GetTypeCode($Value.GetType())
    if ($typeCode -notin @(
        [TypeCode]::Byte,
        [TypeCode]::SByte,
        [TypeCode]::Int16,
        [TypeCode]::UInt16,
        [TypeCode]::Int32,
        [TypeCode]::UInt32,
        [TypeCode]::Int64,
        [TypeCode]::UInt64
    )) {
        return $false
    }
    try {
        $count = [decimal]$Value
        return $count -ge 0 -and $count -le [int]::MaxValue
    } catch {
        return $false
    }
}

function Get-SporeSporeTerminalExecutionProjection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Terminal,
        [Parameter(Mandatory)][string[]]$SuccessSchemas,
        [Parameter(Mandatory)][string[]]$FailureSchemas
    )

    $schema = if ($Terminal.Contains("schema_version")) {
        [string]$Terminal["schema_version"]
    } else { "" }
    $isSuccess = @($SuccessSchemas | Where-Object { $_ -ceq $schema }).Count -eq 1
    $isFailure = @($FailureSchemas | Where-Object { $_ -ceq $schema }).Count -eq 1
    if ($isSuccess -eq $isFailure) {
        throw "TERMINAL_EXECUTION_PROJECTION_SCHEMA_INVALID:$schema"
    }

    $rootCountKeys = @(
        "world_attempt_count",
        "world_build_count",
        "world_build_count_exact",
        "world_build_count_lower_bound",
        "world_build_count_upper_bound"
    )
    $presentRootKeys = @($rootCountKeys | Where-Object { $Terminal.Contains($_) })
    $hasExecution = $Terminal.Contains("execution")

    if ($isSuccess) {
        if (-not $hasExecution -or $presentRootKeys.Count -ne 0) {
            throw "TERMINAL_EXECUTION_PROJECTION_SUCCESS_SHAPE_INVALID:$schema"
        }
        $source = $Terminal["execution"]
        if ($source -isnot [Collections.IDictionary]) {
            throw "TERMINAL_EXECUTION_PROJECTION_EXECUTION_OBJECT_INVALID:$schema"
        }
        $projectionSource = "execution"
        $exact = $true
    } else {
        if ($hasExecution -or
            -not $Terminal.Contains("world_attempt_count") -or
            -not $Terminal.Contains("world_build_count")) {
            throw "TERMINAL_EXECUTION_PROJECTION_FAILURE_SHAPE_INVALID:$schema"
        }
        $source = $Terminal
        $projectionSource = "terminal_root_failure"
        $exact = if ($source.Contains("world_build_count_exact")) {
            if ($source["world_build_count_exact"] -isnot [bool]) {
                throw "TERMINAL_EXECUTION_PROJECTION_EXACT_FLAG_INVALID:$schema"
            }
            [bool]$source["world_build_count_exact"]
        } else { $true }
    }

    foreach ($key in @("world_attempt_count", "world_build_count")) {
        if (-not $source.Contains($key) -or
            -not (Test-SporeSporeNonNegativeTerminalCount $source[$key])) {
            throw "TERMINAL_EXECUTION_PROJECTION_COUNT_INVALID:$schema`:$key"
        }
    }
    $attemptCount = [int]$source["world_attempt_count"]
    $buildCount = [int]$source["world_build_count"]
    if ($buildCount -gt $attemptCount) {
        throw "TERMINAL_EXECUTION_PROJECTION_COUNT_ORDER_INVALID:$schema"
    }

    $lowerBound = if ($source.Contains("world_build_count_lower_bound")) {
        if (-not (Test-SporeSporeNonNegativeTerminalCount (
            $source["world_build_count_lower_bound"]
        ))) {
            throw "TERMINAL_EXECUTION_PROJECTION_LOWER_BOUND_INVALID:$schema"
        }
        [int]$source["world_build_count_lower_bound"]
    } else { $buildCount }
    $upperBound = if ($source.Contains("world_build_count_upper_bound")) {
        if (-not (Test-SporeSporeNonNegativeTerminalCount (
            $source["world_build_count_upper_bound"]
        ))) {
            throw "TERMINAL_EXECUTION_PROJECTION_UPPER_BOUND_INVALID:$schema"
        }
        [int]$source["world_build_count_upper_bound"]
    } else { $buildCount }

    if ($lowerBound -ne $buildCount -or
        $upperBound -lt $lowerBound -or
        $upperBound -gt $attemptCount -or
        ($exact -and $upperBound -ne $buildCount)) {
        throw "TERMINAL_EXECUTION_PROJECTION_BOUNDS_INVALID:$schema"
    }

    return [ordered]@{
        terminal_schema = $schema
        projection_source = $projectionSource
        world_attempt_count = $attemptCount
        world_build_count = $buildCount
        world_build_count_exact = $exact
        world_build_count_lower_bound = $lowerBound
        world_build_count_upper_bound = $upperBound
    }
}
