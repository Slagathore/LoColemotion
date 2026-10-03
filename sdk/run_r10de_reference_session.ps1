[CmdletBinding()]
param([Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
$resolvedRunRoot = [IO.Path]::GetFullPath($RunRoot)
if (-not $resolvedRunRoot.StartsWith('C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\', [StringComparison]::OrdinalIgnoreCase)) { throw 'R10DE_DURABLE_EVIDENCE_REQUIRED' }
$receipt = Join-Path $resolvedRunRoot 'operation-lock.json'
if (Test-Path -LiteralPath $receipt) { throw 'R10DE_FRESH_RUN_REQUIRED' }
$operation = Enter-SporeSporeLocomotionOperationLock -Role conformance -TimeoutMilliseconds 0
try {
    Get-SporeSporeLocomotionOperationLockPublicReceipt $operation | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $receipt -Encoding utf8
    if (-not $operation.acquired) { throw 'R10DE_OPERATION_BUSY' }
    & 'C:\Program Files\Python311\python.exe' -B -X utf8 (Join-Path $PSScriptRoot 'conformance/r10de_reference_session.py') --run $resolvedRunRoot
    if ($LASTEXITCODE -ne 0) { throw "R10DE_SESSION_EXIT_$LASTEXITCODE" }
} finally { Exit-SporeSporeLocomotionOperationLock $operation }
