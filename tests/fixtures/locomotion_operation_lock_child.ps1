#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("conformance", "physical", "physical_development")]
    [string]$Role,
    [Parameter(Mandatory)][ValidateSet("once", "hold", "abandon")][string]$Action,
    [Parameter(Mandatory)][string]$MutexName,
    [string]$ReadyPath = "",
    [string]$ReleasePath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
. (Join-Path $repoRoot "sdk\locomotion_operation_lock.ps1")

$receipt = Enter-SporeSporeLocomotionOperationLock `
    -Role $Role `
    -MutexName $MutexName `
    -TestOnly
$public = Get-SporeSporeLocomotionOperationLockPublicReceipt $receipt
Write-Output (
    "LOCOMOTION_OPERATION_LOCK_CHILD " +
    ($public | ConvertTo-Json -Compress -Depth 16)
)
if (-not [bool]$receipt.acquired) { exit 3 }

if (-not [string]::IsNullOrWhiteSpace($ReadyPath)) {
    [System.IO.File]::WriteAllText($ReadyPath, "ready")
}
if ($Action -ceq "abandon") {
    [Environment]::Exit(0)
}
if ($Action -ceq "hold") {
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path -LiteralPath $ReleasePath)) {
        if ([DateTime]::UtcNow -ge $deadline) {
            Exit-SporeSporeLocomotionOperationLock $receipt
            throw "Timed out waiting for operation-lock release signal."
        }
        Start-Sleep -Milliseconds 25
    }
}
Exit-SporeSporeLocomotionOperationLock $receipt
