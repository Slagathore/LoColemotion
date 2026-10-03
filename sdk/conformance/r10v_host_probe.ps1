param([Parameter(Mandatory)][string]$Request)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$probeRoot = Split-Path -Parent $Request
$probeRequest = Get-Content -LiteralPath $Request -Raw | ConvertFrom-Json
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $repoRoot 'sdk/locomotion_operation_lock.ps1')
$probeLock = Enter-SporeSporeLocomotionOperationLock -Role conformance -TimeoutMilliseconds 0
if (-not $probeLock.acquired -or $probeLock.abandoned_owner_recovered) {
    if ($probeLock.acquired) { Exit-SporeSporeLocomotionOperationLock -Receipt $probeLock }
    throw 'R10V_PROBE_LOCK_REFUSED'
}
$probeDescendant = $null
try {
    $probeLock | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $probeRoot 'probe_lock.json') -Encoding utf8
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $probeRequest.python_runtime.path
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.ArgumentList.Add('-c')
    $startInfo.ArgumentList.Add('import time; time.sleep(90)')
    $probeDescendant = [Diagnostics.Process]::Start($startInfo)
    @{supervisor_pid=$PID;descendant_pid=$probeDescendant.Id;invocation_id=$probeRequest.invocation_id} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $probeRoot 'probe_ready.json') -Encoding utf8
    if ($probeRequest.probe_case -eq 'hang') { Start-Sleep -Seconds 90 }
    else { Start-Sleep -Milliseconds ([int]($probeRequest.hold_seconds*1000)) }
    if ($probeRequest.probe_case -eq 'malformed_terminal') {
        [IO.File]::WriteAllText((Join-Path $probeRoot 'probe_terminal.json'),'{broken')
    } elseif ($probeRequest.probe_case -notin @('missing_terminal','nonzero')) {
        @{invocation_id=$probeRequest.invocation_id;ok=$true;world_build_count=0;solver_step_count=0} |
            ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $probeRoot 'probe_terminal.json') -Encoding utf8
    }
    Write-Output 'R10V_ZERO_WORLD_PROBE_FINISHED'
} finally {
    if ($null -ne $probeDescendant) {
        if (-not $probeDescendant.HasExited) { $probeDescendant.Kill() }
        $probeDescendant.WaitForExit()
        $probeDescendant.Dispose()
    }
    Exit-SporeSporeLocomotionOperationLock -Receipt $probeLock
}
if ($probeRequest.probe_case -eq 'nonzero') { exit 7 }
