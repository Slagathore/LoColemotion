#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$ScratchRoot = (
        Join-Path $env:TEMP "sporespore_process_runner_self_test"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$runnerPath = Join-Path $PSScriptRoot "process_runner.ps1"
if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
    throw "Process runner not found: $runnerPath"
}
. $runnerPath

$runRoot = Join-Path $ScratchRoot (
    (Get-Date -Format "yyyyMMddTHHmmssfff") + "-pid-$PID"
)
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$powerShellExecutable = if ($PSVersionTable.PSEdition -eq "Core") {
    Join-Path $PSHOME "pwsh.exe"
} else {
    Join-Path $PSHOME "powershell.exe"
}

$success = Invoke-ProcessWithTimeout `
    -FilePath $powerShellExecutable `
    -ArgumentList @(
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        "Write-Output PROCESS_RUNNER_CHILD_OK"
    ) `
    -TimeoutSeconds 10 `
    -TranscriptPath (Join-Path $runRoot "success.transcript.log")
if (
    $success.ExitCode -ne 0 -or
    $success.TimedOut -or
    -not $success.ExitMarkerObserved -or
    -not $success.ContainmentTreeClosed -or
    [int64]$success.HostProcessId -lt 1 -or
    [int64]$success.TargetProcessId -lt 1 -or
    [int64]$success.HostProcessId -eq [int64]$success.TargetProcessId -or
    [string]::IsNullOrWhiteSpace($success.TargetStartedUtc) -or
    [string]::IsNullOrWhiteSpace($success.TargetEndedUtc) -or
    -not $success.TargetStartedUtc.EndsWith("Z") -or
    -not $success.TargetEndedUtc.EndsWith("Z") -or
    [DateTimeOffset]::Parse($success.TargetEndedUtc) -lt
        [DateTimeOffset]::Parse($success.TargetStartedUtc) -or
    -not [string]::IsNullOrWhiteSpace($success.StartError) -or
    -not [string]::IsNullOrWhiteSpace($success.TerminationError) -or
    $success.Text -notmatch '(?m)^PROCESS_RUNNER_CHILD_OK\s*$'
) {
    throw "Process-runner success control failed."
}

$nonzero = Invoke-ProcessWithTimeout `
    -FilePath $powerShellExecutable `
    -ArgumentList @(
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        "exit 37"
    ) `
    -TimeoutSeconds 10 `
    -TranscriptPath (Join-Path $runRoot "nonzero.transcript.log")
if (
    $nonzero.ExitCode -ne 37 -or
    $nonzero.TimedOut -or
    -not $nonzero.ExitMarkerObserved -or
    -not $nonzero.ContainmentTreeClosed -or
    [int64]$nonzero.HostProcessId -lt 1 -or
    [int64]$nonzero.TargetProcessId -lt 1 -or
    [int64]$nonzero.HostProcessId -eq [int64]$nonzero.TargetProcessId -or
    [string]::IsNullOrWhiteSpace($nonzero.TargetStartedUtc) -or
    [string]::IsNullOrWhiteSpace($nonzero.TargetEndedUtc) -or
    -not $nonzero.TargetStartedUtc.EndsWith("Z") -or
    -not $nonzero.TargetEndedUtc.EndsWith("Z") -or
    [DateTimeOffset]::Parse($nonzero.TargetEndedUtc) -lt
        [DateTimeOffset]::Parse($nonzero.TargetStartedUtc) -or
    -not [string]::IsNullOrWhiteSpace($nonzero.StartError) -or
    -not [string]::IsNullOrWhiteSpace($nonzero.TerminationError)
) {
    throw "Process-runner native nonzero propagation control failed."
}

$descendantStartedPath = Join-Path $runRoot "descendant.started"
$descendantCompletedPath = Join-Path $runRoot "descendant.completed"
$escapedStartedPath = $descendantStartedPath.Replace("'", "''")
$escapedCompletedPath = $descendantCompletedPath.Replace("'", "''")
$descendantCommand = (
    "[System.IO.File]::WriteAllText('$escapedStartedPath'," +
    "[string]`$PID);" +
    "Start-Sleep -Seconds 30;" +
    "[System.IO.File]::WriteAllText('$escapedCompletedPath','escaped')"
)
$descendantEncoded = [System.Convert]::ToBase64String(
    [System.Text.Encoding]::Unicode.GetBytes($descendantCommand)
)
$escapedPowerShell = $powerShellExecutable.Replace("'", "''")
$escapedProbePath = $descendantStartedPath.Replace("'", "''")
$parentCommand = (
    "`$child=Start-Process -FilePath '$escapedPowerShell' " +
    "-ArgumentList @('-NoLogo','-NoProfile','-NonInteractive'," +
    "'-EncodedCommand','$descendantEncoded') -NoNewWindow -PassThru;" +
    "`$deadline=[DateTime]::UtcNow.AddSeconds(5);" +
    "while(-not (Test-Path -LiteralPath '$escapedProbePath') -and " +
    "[DateTime]::UtcNow -lt `$deadline){Start-Sleep -Milliseconds 10};" +
    "if(-not (Test-Path -LiteralPath '$escapedProbePath')){exit 38};" +
    "exit 0"
)
$inherited = Invoke-ProcessWithTimeout `
    -FilePath $powerShellExecutable `
    -ArgumentList @(
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        $parentCommand
    ) `
    -TimeoutSeconds 10 `
    -TranscriptPath (Join-Path $runRoot "inherited.transcript.log")
if (-not (Test-Path -LiteralPath $descendantStartedPath -PathType Leaf)) {
    throw "Inherited-output descendant never published its PID."
}
$descendantPid = [int](
    Get-Content -LiteralPath $descendantStartedPath -Raw
)
$descendantStillAlive = $null -ne (
    Get-Process -Id $descendantPid -ErrorAction SilentlyContinue
)
if (
    $inherited.ExitCode -ne 0 -or
    $inherited.TimedOut -or
    -not $inherited.ExitMarkerObserved -or
    -not $inherited.ContainmentTreeClosed -or
    [int64]$inherited.HostProcessId -lt 1 -or
    [int64]$inherited.TargetProcessId -lt 1 -or
    [int64]$inherited.HostProcessId -eq [int64]$inherited.TargetProcessId -or
    [string]::IsNullOrWhiteSpace($inherited.TargetStartedUtc) -or
    [string]::IsNullOrWhiteSpace($inherited.TargetEndedUtc) -or
    -not $inherited.TargetStartedUtc.EndsWith("Z") -or
    -not $inherited.TargetEndedUtc.EndsWith("Z") -or
    [DateTimeOffset]::Parse($inherited.TargetEndedUtc) -lt
        [DateTimeOffset]::Parse($inherited.TargetStartedUtc) -or
    -not [string]::IsNullOrWhiteSpace($inherited.StartError) -or
    -not [string]::IsNullOrWhiteSpace($inherited.TerminationError) -or
    $descendantStillAlive -or
    (Test-Path -LiteralPath $descendantCompletedPath -PathType Leaf) -or
    $inherited.DurationMs -ge 10000
) {
    throw (
        "Process-runner inherited-output descendant containment " +
        "control failed."
    )
}

$timeout = Invoke-ProcessWithTimeout `
    -FilePath $powerShellExecutable `
    -ArgumentList @(
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        "Start-Sleep -Seconds 3"
    ) `
    -TimeoutSeconds 1 `
    -TranscriptPath (Join-Path $runRoot "timeout.transcript.log")
if (
    -not $timeout.TimedOut -or
    -not $timeout.KilledProcessTree -or
    -not $timeout.ContainmentTreeClosed -or
    $timeout.Text -notmatch (
        '(?m)^HARNESS_TIMEOUT seconds=1 process_tree_killed=True\s*$'
    )
) {
    throw "Process-runner timeout/kill-tree control failed."
}

Write-Host (
    "PROCESS_RUNNER_SELF_TEST pass=true " +
    "success_exit=$($success.ExitCode) " +
    "success_target_pid=$($success.TargetProcessId) " +
    "timeout_detected=$($timeout.TimedOut) " +
    "process_tree_killed=$($timeout.KilledProcessTree)"
)
Write-Host (
    "PROCESS_RUNNER_SELF_TEST nonzero_exit=$($nonzero.ExitCode) " +
    "inherited_descendant_terminated=$(-not $descendantStillAlive) " +
    "containment_tree_closed=$($inherited.ContainmentTreeClosed)"
)
Write-Host "PROCESS_RUNNER_SELF_TEST artifacts=$runRoot"
exit 0
