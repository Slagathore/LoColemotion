# Pure adapter geometry calls under the shared native-operation lock.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Godot,
      [Parameter(Mandatory)][string]$InputPath,
      [Parameter(Mandatory)][string]$OutputPath,
      [Parameter(Mandatory)][string]$LockReceipt)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
. (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
if ((Test-Path -LiteralPath $OutputPath) -or (Test-Path -LiteralPath $LockReceipt)) {
    throw 'R10DB_FRESH_OUTPUT_REQUIRED'
}
$operation = Enter-SporeSporeLocomotionOperationLock -Role conformance -TimeoutMilliseconds 0
try {
    Get-SporeSporeLocomotionOperationLockPublicReceipt $operation |
        ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $LockReceipt -Encoding utf8
    if (-not $operation.acquired) { throw 'R10DB_NATIVE_OPERATION_BUSY' }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Godot
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    foreach ($argument in @('--headless', '--path', $repoRoot, '--script',
            'res://tests/test_r10db_native_reference_angles.gd', '--', $InputPath, $OutputPath)) {
        $start.ArgumentList.Add($argument)
    }
    $nativeProcess = [Diagnostics.Process]::Start($start)
    try {
        if (-not $nativeProcess.WaitForExit(150000)) {
            $nativeProcess.Kill($true)
            $nativeProcess.WaitForExit()
            throw 'R10DB_NATIVE_TIMEOUT'
        }
        if ($nativeProcess.ExitCode -ne 0) { throw "R10DB_ANGLE_AUDIT_EXIT_$($nativeProcess.ExitCode)" }
    } finally {
        if (-not $nativeProcess.HasExited) { $nativeProcess.Kill($true); $nativeProcess.WaitForExit() }
        $nativeProcess.Dispose()
    }
} finally {
    Exit-SporeSporeLocomotionOperationLock $operation
}
