[CmdletBinding()]
param([Parameter(Mandatory)][string]$RunRoot,[switch]$Build)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
$resolvedRunRoot = [IO.Path]::GetFullPath($RunRoot)
if (-not $resolvedRunRoot.StartsWith('C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\', [StringComparison]::OrdinalIgnoreCase)) { throw 'R10DD_DURABLE_EVIDENCE_REQUIRED' }
$receipt = Join-Path $resolvedRunRoot 'operation-lock.json'
if (Test-Path -LiteralPath $receipt) { throw 'R10DD_FRESH_RUN_REQUIRED' }
$operation = Enter-SporeSporeLocomotionOperationLock -Role conformance -TimeoutMilliseconds 0
try {
    Get-SporeSporeLocomotionOperationLockPublicReceipt $operation | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $receipt -Encoding utf8
    if (-not $operation.acquired) { throw 'R10DD_OPERATION_BUSY' }
    [string[]]$interfaceArguments = if ($Build) { @('--build') } else { @('--run', $resolvedRunRoot) }
    & 'C:\Program Files\Python311\python.exe' -B -X utf8 (Join-Path $PSScriptRoot 'conformance/r10dd_native_interfaces.py') @interfaceArguments
    if ($LASTEXITCODE -ne 0) { throw "R10DD_NATIVE_INTERFACE_EXIT_$LASTEXITCODE" }
} finally { Exit-SporeSporeLocomotionOperationLock $operation }
