#requires -Version 7.0

<#
.SYNOPSIS
Internal containment host for Invoke-ProcessWithTimeout.

.DESCRIPTION
The host deliberately stays alive after the requested native process exits.
That gives the owner one still-live ancestor whose entire process tree can be
closed after the real exit code has been recorded. Without this boundary, a
short-lived process can spawn a descendant that inherits stdout/stderr, exit,
and leave ReadToEndAsync waiting forever on the descendant's open handles.

This file is an implementation detail. Call scripts/process_runner.ps1 rather
than invoking it directly.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$FilePath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ArgumentsBase64,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ExitMarkerPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ReadyMarkerPath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-f0-9]{64}$')]
    [string]$ControlNonce
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"


function Write-ExitMarker {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Started,

        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [long]$TargetProcessId,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$TargetStartedUtc,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$TargetEndedUtc,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$StartError
    )

    $payload = [ordered]@{
        schema = "sporespore.process_runner_exit.v1"
        host_process_id = [int64]$PID
        target_process_id = [int64]$TargetProcessId
        # The prefix prevents PowerShell 7.5 ConvertFrom-Json from silently
        # coercing ISO text to local DateTime and discarding its original
        # offset/fractional identity. The owner strips and parses it explicitly.
        target_started_utc = if ([string]::IsNullOrWhiteSpace(
            $TargetStartedUtc
        )) { "" } else { "utc:$TargetStartedUtc" }
        target_ended_utc = if ([string]::IsNullOrWhiteSpace(
            $TargetEndedUtc
        )) { "" } else { "utc:$TargetEndedUtc" }
        control_nonce = $ControlNonce
        target_started = $Started
        target_exit_code = $ExitCode
        target_start_error = $StartError
    }
    $json = $payload | ConvertTo-Json -Compress -Depth 4
    $temporaryPath = (
        $ExitMarkerPath + "." + $PID.ToString() + ".tmp"
    )
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($temporaryPath, $json, $utf8NoBom)
    [System.IO.File]::Move($temporaryPath, $ExitMarkerPath)
}


$target = $null
$targetStartedUtc = ""
$targetEndedUtc = ""
try {
    $readyDeadline = [DateTime]::UtcNow.AddSeconds(30)
    while (
        -not (Test-Path -LiteralPath $ReadyMarkerPath -PathType Leaf) -and
        [DateTime]::UtcNow -lt $readyDeadline
    ) {
        Start-Sleep -Milliseconds 10
    }
    if (-not (Test-Path -LiteralPath $ReadyMarkerPath -PathType Leaf)) {
        throw "Containment owner did not publish the job-ready marker."
    }
    $readyNonce = (
        Get-Content -LiteralPath $ReadyMarkerPath -Raw -ErrorAction Stop
    ).Trim()
    if ($readyNonce -cne $ControlNonce) {
        throw "Containment job-ready marker authentication failed."
    }

    $argumentJson = [System.Text.Encoding]::UTF8.GetString(
        [System.Convert]::FromBase64String($ArgumentsBase64)
    )
    $decodedArguments = ConvertFrom-Json -InputObject $argumentJson
    $targetArguments = @($decodedArguments | ForEach-Object { [string]$_ })

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $targetArguments) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $target = [System.Diagnostics.Process]::new()
    $target.StartInfo = $startInfo
    if (-not $target.Start()) {
        throw "System.Diagnostics.Process.Start returned false."
    }
    $targetStartedUtc = $target.StartTime.ToUniversalTime().ToString("o")
    # Copy bytes as they arrive. These tasks intentionally do not gate target
    # exit publication: a descendant can inherit the target-side pipe and keep
    # it open. Closing the enclosing Windows Job Object terminates that
    # descendant and completes the copies.
    $stdoutCopy = $target.StandardOutput.BaseStream.CopyToAsync(
        [Console]::OpenStandardOutput())
    $stderrCopy = $target.StandardError.BaseStream.CopyToAsync(
        [Console]::OpenStandardError())
    while (-not $target.WaitForExit(100)) {
        # The owner enforces the actual deadline and closes the job on timeout.
    }
    $targetExitCode = [int]$target.ExitCode
    $targetEndedUtc = $target.ExitTime.ToUniversalTime().ToString("o")
    [void][System.Threading.Tasks.Task]::WaitAll(
        [System.Threading.Tasks.Task[]]@($stdoutCopy, $stderrCopy),
        250
    )
    Write-ExitMarker `
        -Started $true `
        -ExitCode $targetExitCode `
        -TargetProcessId ([int64]$target.Id) `
        -TargetStartedUtc $targetStartedUtc `
        -TargetEndedUtc $targetEndedUtc `
        -StartError ""
} catch {
    $failedTargetProcessId = if ($null -ne $target) {
        [int64]$target.Id
    } else {
        [int64]0
    }
    Write-ExitMarker `
        -Started $false `
        -ExitCode ([int]::MinValue) `
        -TargetProcessId $failedTargetProcessId `
        -TargetStartedUtc $targetStartedUtc `
        -TargetEndedUtc $targetEndedUtc `
        -StartError $_.Exception.ToString()
} finally {
    if ($null -ne $target) {
        $target.Dispose()
    }
}

# The owner kills this host with entireProcessTree=true after consuming the
# marker. Remaining alive is intentional: it preserves an ancestor handle for
# any inherited-output descendant that survived the requested process.
[System.Threading.Thread]::Sleep([System.Threading.Timeout]::Infinite)
