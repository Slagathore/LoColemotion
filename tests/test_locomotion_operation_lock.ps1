#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$ExpectProductionConformanceLockHeld
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$modulePath = Join-Path $repoRoot "sdk\locomotion_operation_lock.ps1"
$childPath = Join-Path $PSScriptRoot "fixtures\locomotion_operation_lock_child.ps1"
. $modulePath

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Wait-Ready([string]$Path, [System.Diagnostics.Process]$Process) {
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    while (-not (Test-Path -LiteralPath $Path)) {
        if ($Process.HasExited) { throw "Lock holder exited before ready." }
        if ([DateTime]::UtcNow -ge $deadline) { throw "Lock holder readiness timed out." }
        Start-Sleep -Milliseconds 25
    }
}

function Start-Holder(
    [string]$Role,
    [string]$MutexName,
    [string]$ReadyPath,
    [string]$ReleasePath,
    [string]$Action = "hold"
) {
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "pwsh"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-NoProfile", "-File", $childPath, "-Role", $Role, "-Action", $Action,
        "-MutexName", $MutexName, "-ReadyPath", $ReadyPath,
        "-ReleasePath", $ReleasePath
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-Exact $process.Start() "Failed to start operation-lock holder."
    return $process
}

$testRoot = Join-Path $repoRoot (
    "sdk\target\operation-lock-test-" + [guid]::NewGuid().ToString("N")
)
[void][System.IO.Directory]::CreateDirectory($testRoot)
$mutexName = "Global\SporeSpore.Locomotion.Test." + [guid]::NewGuid().ToString("N")
Assert-Exact (
    (Get-SporeSporeLocomotionOperationMutexName) -ceq
        "Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"
) "Production locomotion operation mutex identity changed."

$conformanceBlocksPhysical = $false
$physicalBlocksConformance = $false
$physicalDevelopmentAccepted = $false
$acquiresAfterRelease = $false
$abandonedRecovered = $false
$productionConformanceBlocksPhysical = $false
$physicalBlocksConformanceEntrypoint = $false

$ready1 = Join-Path $testRoot "ready1"
$release1 = Join-Path $testRoot "release1"
$holder1 = Start-Holder "conformance" $mutexName $ready1 $release1
try {
    Wait-Ready $ready1 $holder1
    $blocked = Enter-SporeSporeLocomotionOperationLock `
        -Role physical -MutexName $mutexName -TestOnly
    $conformanceBlocksPhysical = -not [bool]$blocked.acquired
    [System.IO.File]::WriteAllText($release1, "release")
    $holder1.WaitForExit(10000) | Out-Null
    Assert-Exact $holder1.HasExited "Conformance holder did not exit."
    Assert-Exact ($holder1.ExitCode -eq 0) "Conformance holder failed."
} finally {
    if (-not $holder1.HasExited) { $holder1.Kill($true) }
}

$ready2 = Join-Path $testRoot "ready2"
$release2 = Join-Path $testRoot "release2"
$holder2 = Start-Holder "physical" $mutexName $ready2 $release2
try {
    Wait-Ready $ready2 $holder2
    $blocked = Enter-SporeSporeLocomotionOperationLock `
        -Role conformance -MutexName $mutexName -TestOnly
    $physicalBlocksConformance = -not [bool]$blocked.acquired
    [System.IO.File]::WriteAllText($release2, "release")
    $holder2.WaitForExit(10000) | Out-Null
    Assert-Exact $holder2.HasExited "Physical holder did not exit."
    Assert-Exact ($holder2.ExitCode -eq 0) "Physical holder failed."
} finally {
    if (-not $holder2.HasExited) { $holder2.Kill($true) }
}

$after = Enter-SporeSporeLocomotionOperationLock `
    -Role physical -MutexName $mutexName -TestOnly
$acquiresAfterRelease = [bool]$after.acquired -and
    -not [bool]$after.abandoned_owner_recovered
Exit-SporeSporeLocomotionOperationLock $after

$development = Enter-SporeSporeLocomotionOperationLock `
    -Role physical_development -MutexName $mutexName -TestOnly
$developmentPublic = Get-SporeSporeLocomotionOperationLockPublicReceipt $development
$physicalDevelopmentAccepted = [bool]$development.acquired -and
    -not [bool]$development.abandoned_owner_recovered -and
    [string]$developmentPublic.role -ceq "physical_development" -and
    [string]$developmentPublic.mutex_name -ceq $mutexName
Exit-SporeSporeLocomotionOperationLock $development

$ready3 = Join-Path $testRoot "ready3"
$abandonRelease = Join-Path $testRoot "abandon-release-never-written"
$observerCreatedNew = $false
$observer = [System.Threading.Mutex]::new($false, $mutexName, [ref]$observerCreatedNew)
try {
    $abandoner = Start-Holder "physical" $mutexName $ready3 $abandonRelease "hold"
    Wait-Ready $ready3 $abandoner
    $abandoner.Kill($true)
    $abandoner.WaitForExit(10000) | Out-Null
    Assert-Exact $abandoner.HasExited "Abandonment child did not exit."
    $recovered = Enter-SporeSporeLocomotionOperationLock `
        -Role conformance -MutexName $mutexName -TestOnly
    $abandonedRecovered = [bool]$recovered.acquired -and
        [bool]$recovered.abandoned_owner_recovered
    Exit-SporeSporeLocomotionOperationLock $recovered
} finally {
    $observer.Dispose()
}

Assert-Exact $conformanceBlocksPhysical "Conformance did not block physical."
Assert-Exact $physicalBlocksConformance "Physical did not block conformance."
Assert-Exact $physicalDevelopmentAccepted `
    "Physical-development role did not acquire the shared serialized lock."
Assert-Exact $acquiresAfterRelease "Lock was not available after release."
Assert-Exact $abandonedRecovered "Abandoned operation lock was not recovered visibly."

if ($ExpectProductionConformanceLockHeld) {
    $productionAttempt = Enter-SporeSporeLocomotionOperationLock -Role physical
    $productionConformanceBlocksPhysical = -not [bool]$productionAttempt.acquired
    if ([bool]$productionAttempt.acquired) {
        Exit-SporeSporeLocomotionOperationLock $productionAttempt
    }
    Assert-Exact $productionConformanceBlocksPhysical `
        "The active conformance process does not hold the production lock."
} else {
    $physicalOwner = Enter-SporeSporeLocomotionOperationLock -Role physical
    Assert-Exact ([bool]$physicalOwner.acquired) `
        "Could not acquire the production physical lock for entrypoint canary."
    try {
        $start = [System.Diagnostics.ProcessStartInfo]::new()
        $start.FileName = "pwsh"
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        foreach ($argument in @(
            "-NoProfile", "-File", (Join-Path $repoRoot "sdk\run_conformance.ps1"),
            "-SkipGodot"
        )) { [void]$start.ArgumentList.Add($argument) }
        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $start
        Assert-Exact $process.Start() "Failed to start conformance entrypoint canary."
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit(10000) | Out-Null
        if (-not $process.HasExited) { $process.Kill($true) }
        $combined = $stdoutTask.GetAwaiter().GetResult() +
            [Environment]::NewLine + $stderrTask.GetAwaiter().GetResult()
        $physicalBlocksConformanceEntrypoint = (
            $process.HasExited -and $process.ExitCode -ne 0 -and
            $combined -match [regex]::Escape(
                (Get-SporeSporeLocomotionOperationMutexName)
            )
        )
    } finally {
        Exit-SporeSporeLocomotionOperationLock $physicalOwner
    }
    Assert-Exact $physicalBlocksConformanceEntrypoint `
        "The real conformance entrypoint did not refuse a held physical lock."
}

Write-Host (
    "LOCOMOTION_OPERATION_LOCK_PASS mutex=Global roles=3 " +
    "conformance_blocks_physical=True physical_blocks_conformance=True " +
    "physical_development_accepted=$physicalDevelopmentAccepted " +
    "acquires_after_release=True abandoned_recovered=True " +
    "production_conformance_blocks_physical=$productionConformanceBlocksPhysical " +
    "physical_blocks_conformance_entrypoint=$physicalBlocksConformanceEntrypoint " +
    "physical_authority=False"
)
