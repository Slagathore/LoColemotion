[CmdletBinding()]
param([Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
$resolvedRunRoot = [IO.Path]::GetFullPath($RunRoot)
if (-not $resolvedRunRoot.StartsWith('C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\', [StringComparison]::OrdinalIgnoreCase)) { throw 'R10DG_DURABLE_EVIDENCE_REQUIRED' }
$receipt = Join-Path $resolvedRunRoot 'operation-lock.json'
if (Test-Path -LiteralPath $receipt) { throw 'R10DG_FRESH_RUN_REQUIRED' }
$operation = Enter-SporeSporeLocomotionOperationLock -Role conformance -TimeoutMilliseconds 0
try {
    Get-SporeSporeLocomotionOperationLockPublicReceipt $operation | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $receipt -Encoding utf8
    if (-not $operation.acquired) { throw 'R10DG_OPERATION_BUSY' }
    & 'C:\Program Files\Python311\python.exe' -B -X utf8 (Join-Path $PSScriptRoot 'conformance/r10dg_safety.py') --run $resolvedRunRoot
    if ($LASTEXITCODE -ne 0) { throw "R10DG_SESSION_EXIT_$LASTEXITCODE" }
} finally { Exit-SporeSporeLocomotionOperationLock $operation }
