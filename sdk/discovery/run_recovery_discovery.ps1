[CmdletBinding()]
param([Parameter(Mandatory)][string]$Batch, [int]$MaximumCells = 1, [int]$Workers = 1,
    [string]$CellId = '', [string]$OperationReceipt = '', [string]$StartPermit = '', [switch]$QualificationOnly)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '../run_r10dg_physical.ps1') -Library
$repo = 'C:/Users/Cole/CodeStuff/games/SporeSpore'
$python = 'C:/Program Files/Python311/python.exe'
if ($MaximumCells -lt 1 -or $MaximumCells -gt 24) { throw 'DISCOVERY_CELL_LIMIT' }
$ownsOperation = [string]::IsNullOrWhiteSpace($CellId)
if ($ownsOperation) {
    $operation = Enter-SporeSporeLocomotionOperationLock -Role physical_development -TimeoutMilliseconds 0
} else {
    $permitDeadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path -LiteralPath $StartPermit)) {
        if ([DateTime]::UtcNow -gt $permitDeadline) { throw 'DISCOVERY_JOB_CONTAINMENT_NOT_GRANTED' }
        Start-Sleep -Milliseconds 100
    }
    $permit = Get-Content -LiteralPath $StartPermit -Raw | ConvertFrom-Json -AsHashtable
    if ($permit.leaf_pid -ne $PID -or $permit.job_bound -ne $true) { throw 'DISCOVERY_JOB_PERMIT_CROSSED' }
    $operation = Get-Content -LiteralPath $OperationReceipt -Raw | ConvertFrom-Json -AsHashtable
    if (-not (Get-Process -Id $operation.owner_process_id -ErrorAction SilentlyContinue)) { throw 'DISCOVERY_COORDINATOR_GONE' }
}
try {
    if (-not $operation.acquired) { throw 'DISCOVERY_OPERATION_BUSY' }
    if ($ownsOperation) {
        $operationPath = Join-Path $Batch ('pool-operation-' + [Guid]::NewGuid().ToString('N') + '.json')
        Write-R10dgNew $operationPath (ConvertTo-SporeSporeExactJson (Get-SporeSporeLocomotionOperationLockPublicReceipt $operation))
        & $python -B -X utf8 (Join-Path $PSScriptRoot 'recovery_discovery_pool.py') $Batch --workers $Workers --maximum $MaximumCells --operation $operationPath
        if ($LASTEXITCODE -ne 0) { throw 'DISCOVERY_POOL_RETAINED_FAILURE' }
        return
    }
    $rows = Get-Content -LiteralPath (Join-Path $Batch 'cells.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $launched = 0
    foreach ($row in $rows) {
        if ($row.cell.cell_id -cne $CellId) { continue }
        $path = Join-Path $row.folder 'declaration.json'
        $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $child = $value.children[0]
        if (Test-Path -LiteralPath (Join-Path $child.evidence_path 'launch-reservation.json')) { continue }
        $verifyArguments = @('-B','-X','utf8',(Join-Path $PSScriptRoot 'recovery_discovery.py'),'verify-cell',$path)
        if ($QualificationOnly) { $verifyArguments += '--qualification-only' }
        & $python @verifyArguments
        if ($LASTEXITCODE -ne 0) { throw 'DISCOVERY_SOURCE_OR_GATE_CHANGED' }
        $contract = Get-SporeRecoveryProcessContractV1
        $context = [ordered]@{
            schema_version=$contract.context_schema; parent_attempt_id=$value.attempt_id
            child_attempt_id=$child.child_attempt_id; role=$child.role; source_commit=$value.source_snapshot.head
            authority_sha256=('sha256:' + (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant())
            termination_nonce=$child.termination_nonce; ready_marker_prefix=$contract.ready_marker_prefix
            root_image=$value.runtime.images.godot_console; worker_image=$value.runtime.images.godot_engine
        }
        Assert-QsdkR10fL15LaunchContext $context
        $environment = Get-Content -LiteralPath (Join-Path $row.folder 'environment.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        if ($permit.child_attempt_id -cne $child.child_attempt_id) { throw 'DISCOVERY_JOB_CHILD_CROSSED' }
        # Preserve the original wire bytes. ConvertFrom-Json can materialize ISO
        # dates as DateTime, which the exact JSON serializer correctly refuses.
        $operationName = if ($QualificationOnly) { 'preflight-operation.json' } else { 'operation-lock.json' }
        Write-R10dgNew (Join-Path $child.evidence_path $operationName) ([IO.File]::ReadAllText($OperationReceipt))
        if ($QualificationOnly) {
            Write-R10dgNew (Join-Path $child.evidence_path 'launcher-preflight.json') (ConvertTo-SporeSporeExactJson @{ok=$true;context=$context;world_build_count=0;solver_step_count=0})
            return
        }
        Write-R10dgNew (Join-Path $child.evidence_path 'launch-reservation.json') (ConvertTo-SporeSporeExactJson $context)
        Write-Output ('DISCOVERY_PHYSICAL ' + $row.cell.cell_id + ' ' + $row.folder)
        $result = Invoke-SporeSporeGodotReceiptTerminatedProcess -FileName $context.root_image.path `
            -Arguments @('--headless','--path',$repo,'--script',$value.worker_resource) -WorkingDirectory $repo `
            -ReadyMarkerPrefix $context.ready_marker_prefix -ExpectedNonce $child.termination_nonce `
            -Environment $environment.environment -ScrubEnvironmentNames $environment.scrub_names `
            -TimeoutSeconds $value.timeout_seconds_per_child -R10fL15LaunchContext $context -R10xNativeProcessObservation
        Write-R10dgNew (Join-Path $child.evidence_path 'stdout.log') $result.stdout
        Write-R10dgNew (Join-Path $child.evidence_path 'stderr.log') $result.stderr
        $envelope = [ordered]@{role=$child.role;child_attempt_id=$child.child_attempt_id;termination_nonce=$child.termination_nonce}
        foreach ($property in $result.PSObject.Properties) {
            if ($property.Name -notin @('stdout','stderr')) { $envelope[$property.Name] = $property.Value }
        }
        Write-R10dgNew (Join-Path $child.evidence_path 'process.json') (ConvertTo-SporeSporeExactJson $envelope)
        try {
            $null = Assert-QsdkR10fL15ChildLaunchRelationship $envelope $context
            Write-R10dgNew (Join-Path $child.evidence_path 'relationship-audit.json') '{"ok":true}'
        } catch {
            Write-R10dgNew (Join-Path $child.evidence_path 'relationship-audit.json') (ConvertTo-SporeSporeExactJson @{ok=$false;failure=$_.Exception.Message})
        }
        $result = $null
        # The full legacy report can leave multi-gigabyte temporary strings in
        # the launcher heap. Release them before the independent native reader.
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        [GC]::Collect()
        & $python -B -X utf8 (Join-Path $PSScriptRoot 'recovery_discovery.py') audit $Batch --cell-id $CellId
        if ($LASTEXITCODE -ne 0) { throw 'DISCOVERY_CELL_INVALID_RETAINED' }
        $launched++
        if ($launched -ge $MaximumCells) { break }
    }
} finally { if ($ownsOperation) { Exit-SporeSporeLocomotionOperationLock $operation } }
