[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReadyPath, [Parameter(Mandatory)][string]$StopPath,
      [Parameter(Mandatory)][string]$StartPermit)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$deadline = [DateTime]::UtcNow.AddSeconds(20)
while (-not (Test-Path -LiteralPath $StartPermit)) {
    if ([DateTime]::UtcNow -gt $deadline) { throw 'NESTED_FIXTURE_JOB_PERMISSION_MISSING' }
    Start-Sleep -Milliseconds 20
}
$permission = Get-Content -LiteralPath $StartPermit -Raw | ConvertFrom-Json
if ($permission.leaf_pid -ne $PID) { throw 'NESTED_FIXTURE_JOB_PERMISSION_CROSSED' }
$code = @'
import sys,time
from pathlib import Path
sys.path.insert(0,str(Path.cwd()/'sdk/discovery'))
import recovery_discovery as D
import recovery_discovery_host_v2 as H
D.write_new(Path(sys.argv[1]),dict(identity=H.W.current_identity(),in_job=H.W.current_in_job()))
end=time.monotonic()+30
while not Path(sys.argv[2]).exists() and time.monotonic()<end:time.sleep(.02)
D.require(Path(sys.argv[2]).exists(),'NESTED_FIXTURE_STOP_MISSING')
'@
& 'C:/Program Files/Python311/python.exe' -B -X utf8 -c $code $ReadyPath $StopPath
exit $LASTEXITCODE
