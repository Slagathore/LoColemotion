[CmdletBinding()]
param([string]$Qualification = '', [switch]$Library)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
. (Join-Path $PSScriptRoot 'godot_receipt_terminated_process.ps1')
. (Join-Path $PSScriptRoot 'qsdk_r10f_l15_launch_relationship.ps1')
. (Join-Path $PSScriptRoot 'exact_json_transport.ps1')
function New-R10dgLaunchContext {
    param([System.Collections.IDictionary]$Declaration, [string]$DeclarationPath)
    $selected = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'development/r10dg_host_runtime_contract_v1.json') | ConvertFrom-Json -AsHashtable -Depth 100
    if (-not (Test-QsdkR10fL15ExactValue $selected $Declaration.runtime)) { throw 'R10DG_CONTEXT_HOST' }
    foreach ($image in $selected.images.Values) {
        if ((Get-Item -LiteralPath $image.path).Length -ne $image.byte_length -or
            ('sha256:' + (Get-FileHash -LiteralPath $image.path -Algorithm SHA256).Hash.ToLowerInvariant()) -cne $image.raw_sha256) { throw 'R10DG_CONTEXT_IMAGE' }
    }
    $contract = Get-SporeRecoveryProcessContractV1
    $child = $Declaration.children[0]
    $context = [ordered]@{
        schema_version=$contract.context_schema; parent_attempt_id=$Declaration.attempt_id
        child_attempt_id=$child.child_attempt_id; role=$child.role; source_commit=$Declaration.source_snapshot.head
        authority_sha256=('sha256:' + (Get-FileHash -LiteralPath $DeclarationPath -Algorithm SHA256).Hash.ToLowerInvariant())
        termination_nonce=$child.termination_nonce; ready_marker_prefix=$contract.ready_marker_prefix
        root_image=$selected.images.godot_console; worker_image=$selected.images.godot_engine
    }
    Assert-QsdkR10fL15LaunchContext $context
    return $context
}
function Write-R10dgNew {
    param([string]$Path, [string]$Text)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
        $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true)
    } finally { $stream.Dispose() }
}
if ($Library) { return }
if ([string]::IsNullOrWhiteSpace($Qualification)) { throw 'R10DG_QUALIFICATION_REQUIRED' }
$repo = 'C:\Users\Cole\CodeStuff\games\SporeSpore'
if ((& git -C $repo rev-parse --show-toplevel).Replace('\','/') -cne $repo.Replace('\','/') -or
    (& git -C $repo remote get-url origin) -cne 'https://github.com/Slagathore/sporespore.git') { throw 'R10DG_REPOSITORY' }
$python = 'C:\Program Files\Python311\python.exe'
$operation = Enter-SporeSporeLocomotionOperationLock -Role physical_development -TimeoutMilliseconds 0
try {
    if (-not $operation.acquired) { throw 'R10DG_OPERATION_BUSY' }
    $prepared = & $python -B -X utf8 (Join-Path $PSScriptRoot 'conformance/r10dg_launch.py') --qualification $Qualification
    if ($LASTEXITCODE -ne 0) { throw 'R10DG_PREPARE_REFUSED' }
    $receipt = $prepared | ConvertFrom-Json -AsHashtable -Depth 100
    $path = $receipt.declaration.path
    $folder = Split-Path -Parent $path
    Write-R10dgNew (Join-Path $folder 'operation-lock.json') (ConvertTo-SporeSporeExactJson (Get-SporeSporeLocomotionOperationLockPublicReceipt $operation))
    $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $context = New-R10dgLaunchContext $value $path
    Write-R10dgNew (Join-Path $folder 'launch-context.json') (ConvertTo-SporeSporeExactJson $context)
    $environment = Get-Content -LiteralPath (Join-Path $folder 'child-environment.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $authorized = & $python -B -X utf8 (Join-Path $PSScriptRoot 'conformance/r10dg_native_world_authority.py') --authorize $path
    Write-R10dgNew (Join-Path $folder 'authorization-output.txt') ($authorized -join "`n")
    if ($LASTEXITCODE -ne 0) { throw 'R10DG_AUTHORIZATION_REFUSED' }
    Write-Output "R10DG_PHYSICAL_ROOT $folder"
    $child = $value.children[0]
    # One invocation only. Every outcome is retained before independent auditing.
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
    & $python -B -X utf8 (Join-Path $PSScriptRoot 'conformance/r10dg_result.py') --declaration $path
    if ($LASTEXITCODE -ne 0) { throw 'R10DG_RESULT_RETAINED_AUDIT_NEGATIVE' }
} finally { Exit-SporeSporeLocomotionOperationLock $operation }

