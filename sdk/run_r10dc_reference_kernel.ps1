[CmdletBinding()]
param([Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
. (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
$resolvedRunRoot = [IO.Path]::GetFullPath($RunRoot)
if (-not $resolvedRunRoot.StartsWith('C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'R10DC_DURABLE_EVIDENCE_REQUIRED'
}
$receipt = Join-Path $resolvedRunRoot 'operation-lock.json'
if (Test-Path -LiteralPath $receipt) { throw 'R10DC_FRESH_RUN_REQUIRED' }
$operation = Enter-SporeSporeLocomotionOperationLock -Role conformance -TimeoutMilliseconds 0
try {
    Get-SporeSporeLocomotionOperationLockPublicReceipt $operation |
        ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $receipt -Encoding utf8
    if (-not $operation.acquired) { throw 'R10DC_OPERATION_BUSY' }
    & 'C:\Program Files\Python311\python.exe' -B -X utf8 (Join-Path $PSScriptRoot 'conformance/r10dc_native_reference_kernel.py') --run-tests $resolvedRunRoot
    if ($LASTEXITCODE -ne 0) { throw "R10DC_TEST_EXIT_$LASTEXITCODE" }
} finally {
    Exit-SporeSporeLocomotionOperationLock $operation
}
