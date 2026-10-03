#requires -Version 7.5
[CmdletBinding()]
param([switch]$RequireCleanSuccess)
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ((& git -C $repoRoot rev-parse --show-toplevel) -cne $repoRoot.Replace('\','/') -or
    (& git -C $repoRoot remote get-url origin) -cne 'https://github.com/Slagathore/sporespore.git') {throw 'R10AD_REPOSITORY'}
. (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
$operation=Enter-SporeSporeLocomotionOperationLock -Role conformance
if (-not $operation.acquired -or $operation.abandoned_owner_recovered) {throw 'R10AD_OPERATION_LOCK_BUSY'}
$out=Join-Path (Split-Path $repoRoot -Parent) ('SporeSpore_Evidence/r10ad-startup-preflight-'+[Guid]::NewGuid().ToString('N'))
try {
    $null=New-Item -ItemType Directory -Path $out
    Write-Output ('R10AD_STARTUP_PREFLIGHT_ROOT '+$out)
    $arguments=@('-B',(Join-Path $PSScriptRoot 'conformance/r10ad_startup_check.py'),$out)
    if ($RequireCleanSuccess) {$arguments+='--require-clean-success'}
    & 'C:/Program Files/Python311/python.exe' @arguments 1> (Join-Path $out 'driver.stdout.log') 2> (Join-Path $out 'driver.stderr.log')
    $code=$LASTEXITCODE
    Get-Content -LiteralPath (Join-Path $out 'driver.stdout.log')
    if ($code -ne 0) {Get-Content -LiteralPath (Join-Path $out 'driver.stderr.log');throw 'R10AD_STARTUP_CHECK_FAILED'}
} finally {
    Exit-SporeSporeLocomotionOperationLock -Receipt $operation
    if (Test-Path -LiteralPath $out) {
        $operation | Select-Object * -ExcludeProperty _mutex_handle | ConvertTo-Json -Depth 20 |
            Set-Content -LiteralPath (Join-Path $out 'operation-lock.json') -Encoding utf8NoBOM
    }
}
