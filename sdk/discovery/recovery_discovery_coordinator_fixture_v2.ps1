[CmdletBinding()]
param([Parameter(Mandatory)][string]$RequestPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# Match the production outer PowerShell -> Python -> leaf PowerShell topology.
# The durable owner's proxy has already obtained its containing-job permit.
& 'C:/Program Files/Python311/python.exe' -B (Join-Path $PSScriptRoot 'recovery_discovery_host_fixture_v2.py') $RequestPath
exit $LASTEXITCODE
