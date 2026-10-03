#requires -Version 7.0

Set-StrictMode -Version Latest

function Test-SporeSporeProcessResultProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ProcessResult,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if ($ProcessResult -is [Collections.IDictionary]) {
        return [bool]$ProcessResult.Contains($Name)
    }
    if ($ProcessResult -is [PSCustomObject]) {
        return $null -ne $ProcessResult.PSObject.Properties[$Name]
    }
    throw (
        "SPORESPORE_PROCESS_RESULT_SHAPE_UNSUPPORTED:" +
        $ProcessResult.GetType().FullName
    )
}

function Get-SporeSporeProcessResultValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ProcessResult,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [AllowNull()]
        [object]$Fallback = $null
    )

    if (Test-SporeSporeProcessResultProperty -ProcessResult $ProcessResult -Name $Name) {
        if ($ProcessResult -is [Collections.IDictionary]) {
            return $ProcessResult[$Name]
        }
        return $ProcessResult.PSObject.Properties[$Name].Value
    }
    return $Fallback
}

function Get-SporeSporeProcessExecutionProjection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ProcessResult,

        [Parameter(Mandatory)]
        [bool]$GodotProcess
    )

    foreach ($requiredName in @(
        "exit_code",
        "timed_out",
        "started_utc",
        "completed_utc"
    )) {
        if (-not (Test-SporeSporeProcessResultProperty `
            -ProcessResult $ProcessResult -Name $requiredName)) {
            throw "SPORESPORE_PROCESS_RESULT_REQUIRED_PROPERTY_MISSING:$requiredName"
        }
    }

    $exitCode = [int](Get-SporeSporeProcessResultValue `
        -ProcessResult $ProcessResult -Name "exit_code")
    return [ordered]@{
        exit_code = $exitCode
        host_exit_code = [int](Get-SporeSporeProcessResultValue `
            -ProcessResult $ProcessResult -Name "host_exit_code" `
            -Fallback $exitCode)
        timed_out = [bool](Get-SporeSporeProcessResultValue `
            -ProcessResult $ProcessResult -Name "timed_out")
        supervisor_terminated = [bool](Get-SporeSporeProcessResultValue `
            -ProcessResult $ProcessResult -Name "supervisor_terminated" `
            -Fallback $false)
        termination_protocol_valid = [bool](Get-SporeSporeProcessResultValue `
            -ProcessResult $ProcessResult -Name "termination_protocol_valid" `
            -Fallback (-not $GodotProcess))
        started_utc = [string](Get-SporeSporeProcessResultValue `
            -ProcessResult $ProcessResult -Name "started_utc")
        completed_utc = [string](Get-SporeSporeProcessResultValue `
            -ProcessResult $ProcessResult -Name "completed_utc")
    }
}
