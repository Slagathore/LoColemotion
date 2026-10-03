#requires -Version 7.0

$script:SporeSporeLocomotionOperationMutexName =
    "Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"

function Get-SporeSporeLocomotionOperationMutexName {
    return $script:SporeSporeLocomotionOperationMutexName
}

function Enter-SporeSporeLocomotionOperationLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            "conformance", "qualification", "physical", "physical_development"
        )]
        [string]$Role,
        [ValidateRange(0, 600000)]
        [int]$TimeoutMilliseconds = 0,
        [string]$MutexName = $script:SporeSporeLocomotionOperationMutexName,
        [switch]$TestOnly
    )

    if ($MutexName -cne $script:SporeSporeLocomotionOperationMutexName) {
        if (-not $TestOnly -or $MutexName -cnotmatch
            '^Global\\SporeSpore\.Locomotion\.Test\.[A-Za-z0-9_-]+$') {
            throw "Custom locomotion operation mutex names are test-only."
        }
    }

    $createdNew = $false
    $mutex = [System.Threading.Mutex]::new($false, $MutexName, [ref]$createdNew)
    $acquired = $false
    $wasAbandoned = $false
    try {
        try {
            $acquired = $mutex.WaitOne($TimeoutMilliseconds)
        } catch [System.Threading.AbandonedMutexException] {
            $acquired = $true
            $wasAbandoned = $true
        }
        if (-not $acquired) {
            $mutex.Dispose()
            $mutex = $null
        }
        return [pscustomobject]@{
            schema_version = "sporespore_locomotion_operation_lock_receipt_v1"
            acquired = $acquired
            role = $Role
            mutex_name = $MutexName
            created_new = $createdNew
            abandoned_owner_recovered = $wasAbandoned
            owner_process_id = $PID
            owner_session_id = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
            acquired_utc = if ($acquired) {
                [DateTime]::UtcNow.ToString("o")
            } else { $null }
            released = $false
            test_only = [bool]$TestOnly
            physical_acceptance_authority = $false
            _mutex_handle = $mutex
        }
    } catch {
        if ($null -ne $mutex) { $mutex.Dispose() }
        throw
    }
}

function Exit-SporeSporeLocomotionOperationLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Receipt
    )
    if (-not [bool]$Receipt.acquired -or [bool]$Receipt.released) { return }
    $mutex = $Receipt._mutex_handle
    if ($null -eq $mutex) {
        throw "An acquired locomotion operation lock has no mutex handle."
    }
    try {
        $mutex.ReleaseMutex()
        $Receipt.released = $true
    } finally {
        $mutex.Dispose()
        $Receipt._mutex_handle = $null
    }
}

function Get-SporeSporeLocomotionOperationLockPublicReceipt {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Receipt)
    return [ordered]@{
        schema_version = [string]$Receipt.schema_version
        acquired = [bool]$Receipt.acquired
        role = [string]$Receipt.role
        mutex_name = [string]$Receipt.mutex_name
        created_new = [bool]$Receipt.created_new
        abandoned_owner_recovered = [bool]$Receipt.abandoned_owner_recovered
        owner_process_id = [int]$Receipt.owner_process_id
        owner_session_id = [int]$Receipt.owner_session_id
        acquired_utc = [string]$Receipt.acquired_utc
        test_only = [bool]$Receipt.test_only
        physical_acceptance_authority = $false
    }
}
