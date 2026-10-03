param([Parameter(Mandatory)][string]$Fixture,[Parameter(Mandatory)][string]$OutputRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $repoRoot 'sdk/qsdk_r10f_l15_launch_relationship.ps1')
. (Join-Path $repoRoot 'sdk/qsdk_r10f_l14_runtime_binding.ps1')
. (Join-Path $repoRoot 'sdk/exact_json_transport.ps1')
. (Join-Path $repoRoot 'sdk/godot_receipt_terminated_process.ps1')
. (Join-Path $repoRoot 'sdk/locomotion_operation_lock.ps1')
. (Join-Path $repoRoot 'sdk/r10v_compact_child_retention.ps1')
$tokens=$null;$errors=$null
$tree=[Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'sdk/run_qsdk_r10f_continuous_passive_recovery.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'R10V_RETENTION_SOURCE_PARSE'}
foreach($name in @('Assert-R10f','Get-PrefixedSha256','Write-Utf8CreateNew','Write-JsonCreateNew','Get-R10fRetainedFileBinding','Get-OptionalSingleMarkerJson','New-QsdkR10fL9ChildEnvironment', 'Invoke-L9ChildProcess')) {
    $nodes=@($tree.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name},$false))
    if($nodes.Count -ne 1){throw ('R10V_RETENTION_SOURCE_FUNCTION:'+ $name)}
    . ([scriptblock]::Create($nodes[0].Extent.Text))
}
$fixtureValue=Get-Content -LiteralPath $Fixture -Raw | ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
$script:RepoRoot=$repoRoot
$script:RepairId='QSDK-R10F-L14'
$script:WorkerResource='res://sdk/adapters/godot/gdscript/r10aj_development_worker_v1.gd'
$script:GateId='R10V-ZERO-WORLD-COMPONENT';$script:GateToken='R10V';$script:RawSchema='synthetic_payload_fixture'
$script:WorkId='R10V-RETENTION-CONTROL';$script:RawMarker='R10V_SYNTHETIC_REPORT '
$script:ReadyMarker=$fixtureValue.context.ready_marker_prefix
$script:DevelopmentSeed=68248;$script:DevelopmentSeedLabel='synthetic';$script:DevelopmentSeedSha256='sha256:'+('a'*64)
$script:ActuatorMode='synthetic';$script:ControllerId='synthetic';$script:EnergyRouteId='synthetic';$script:EnvironmentNames=@()
$script:PhysicalAttemptId=$fixtureValue.context.parent_attempt_id
$TimeoutSeconds=30
$script:NativeExecutorCalls=0
# The sole execution seam supplies synthetic data. The actual child launcher,
# writers, file hashing, launch validation and compact-retention helper execute.
function Invoke-SporeSporeGodotReceiptTerminatedProcess {
    param($R10fL15LaunchContext,$FileName,$Arguments,$WorkingDirectory,$ReadyMarkerPrefix,$ExpectedNonce,$Environment,$ScrubEnvironmentNames,$TimeoutSeconds,[switch]$R10xNativeProcessObservation)
    Assert-R10f ($R10xNativeProcessObservation -and $null -ne $R10fL15LaunchContext) 'R10AJ_NATIVE_SELECTION_MISSING'
    Assert-R10f (Test-QsdkR10fL15ExactValue $R10fL15LaunchContext.root_image $fixtureValue.runtime.images.godot_console) 'R10AJ_RETENTION_ROOT_IMAGE'
    Assert-R10f (Test-QsdkR10fL15ExactValue $R10fL15LaunchContext.worker_image $fixtureValue.runtime.images.godot_engine) 'R10AJ_RETENTION_WORKER_IMAGE'
    Assert-R10f ($FileName -ceq $fixtureValue.runtime.images.godot_console.path) 'R10AJ_RETENTION_SELECTED_IMAGE'
    $script:NativeExecutorCalls++
    return $script:FakeRun
}
function New-FixtureEnvelope([string]$Case,[int]$PayloadLength=1024) {
    $directory=Join-Path $OutputRoot $Case
    $null=New-Item -ItemType Directory -Path $directory
    $value=ConvertFrom-QsdkR10fL15ExactJson (ConvertTo-SporeSporeExactJson $fixtureValue.envelope)
    $value.evidence_path=$directory
    $value.report=@{schema_version='synthetic_retention_payload';payload=[string]::new([char]'x',$PayloadLength);world_build_count=0;solver_step_count=0}
    $value.retained_artifact_bindings=[ordered]@{}
    Write-JsonCreateNew (Join-Path $directory 'child_attempt_identity.json') @{role=$value.role;child_attempt_id=$value.child_attempt_id;termination_nonce=$value.termination_nonce;evidence_path=$directory}
    Write-Utf8CreateNew (Join-Path $directory 'worker.stdout.txt') 'synthetic zero-world fixture'
    Write-Utf8CreateNew (Join-Path $directory 'worker.stderr.txt') ''
    Write-JsonCreateNew (Join-Path $directory 'termination_receipt.json') @{synthetic=$true}
    Write-JsonCreateNew (Join-Path $directory 'engine_health.json') @{passed=$true}
    Write-JsonCreateNew (Join-Path $directory 'worker_report.json') $value.report
    $names=@{child_attempt_identity='child_attempt_identity.json';worker_stdout='worker.stdout.txt';worker_stderr='worker.stderr.txt';termination_receipt='termination_receipt.json';engine_health='engine_health.json';worker_report='worker_report.json'}
    foreach($name in $names.Keys){$value.retained_artifact_bindings[$name]=Get-R10fRetainedFileBinding (Join-Path $directory $names[$name])}
    return $value
}
# No native process is started: the enclosing gate owns serialization.
$results=[Collections.Generic.List[object]]::new()
try {
    foreach($case in @('compact_large','corrupt_artifact','missing_artifact','crossed_launch','invalid_health','duplicate_envelope','integrated_child','missing_selector','wrong_route','ambiguous_selector','crossed_runtime')) {
        $expectedFailure=$case -notin @('compact_large','integrated_child')
        $caught='';$compact=$null;$beforeCalls=$script:NativeExecutorCalls
        try {
            if($case -in @('integrated_child','missing_selector','wrong_route','ambiguous_selector','crossed_runtime')) {
                $childRoot=Join-Path $OutputRoot $case;$null=New-Item -ItemType Directory -Path $childRoot
                $descriptor=@{role=$fixtureValue.envelope.role;child_attempt_id=$fixtureValue.envelope.child_attempt_id;termination_nonce=$fixtureValue.envelope.termination_nonce;evidence_path=$childRoot}
                Write-JsonCreateNew (Join-Path $childRoot 'child_attempt_identity.json') $descriptor
                $script:FakeRun=[ordered]@{}
                foreach($key in @('started_utc','completed_utc','process_id','worker_process_id','exit_code','termination_protocol_valid','r10f_l15_launch_relationship','termination_ready_receipt')) {$script:FakeRun[$key]=$fixtureValue.envelope[$key]}
                $script:FakeRun.stdout=$script:RawMarker+(ConvertTo-SporeSporeExactJson @{schema_version='synthetic_retention_payload';payload=[string]::new([char]'z',4194304);world_build_count=0;solver_step_count=0})+"`n"
                $script:FakeRun.stderr=''
                $script:ObservedChildEnvelopes=[Collections.Generic.List[object]]::new()
                $binding=@{authority=@{source_commit=$fixtureValue.context.source_commit};authority_sha256=$fixtureValue.context.authority_sha256;l14_exact_runtime_images=$fixtureValue.runtime}
                if($case -eq 'crossed_runtime'){$binding.l14_exact_runtime_images=@{schema_version='crossed_runtime'}}
                if($case -eq 'wrong_route'){$script:WorkerResource='res://sdk/adapters/godot/gdscript/r10u_recovery_worker_v1.gd'}
                if($case -eq 'missing_selector') {
                    $null=Invoke-L9ChildProcess -Descriptor $descriptor -Binding $binding -GodotPath $fixtureValue.runtime.images.godot_console.path -RequireL15LaunchRelationship
                    throw 'R10AJ_MISSING_SELECTOR_ACCEPTED'
                }
                if($case -eq 'ambiguous_selector') {
                    $null=Invoke-L9ChildProcess -Descriptor $descriptor -Binding $binding -GodotPath $fixtureValue.runtime.images.godot_console.path -RequireL15LaunchRelationship -RetainR10ajCompactEnvelope -RetainR10abCompactEnvelope
                    throw 'R10AJ_AMBIGUOUS_SELECTOR_ACCEPTED'
                }
                $compact=Invoke-L9ChildProcess -Descriptor $descriptor -Binding $binding -GodotPath $fixtureValue.runtime.images.godot_console.path -RequireL15LaunchRelationship -RetainR10ajCompactEnvelope
                Assert-R10f ($script:ObservedChildEnvelopes.Count -eq 1 -and -not $script:ObservedChildEnvelopes[0].Contains('report')) 'R10V_OBSERVED_LIST_RETAINS_PAYLOAD'
            } else {
                $size=if($case -eq 'compact_large'){16777216}else{1024}
                $full=New-FixtureEnvelope $case $size
                if($case -eq 'corrupt_artifact'){[IO.File]::AppendAllText((Join-Path $full.evidence_path 'worker_report.json'),'corruption')}
                if($case -eq 'missing_artifact'){[IO.File]::Delete((Join-Path $full.evidence_path 'worker_report.json'))}
                if($case -eq 'crossed_launch'){$full.child_attempt_id='0'*32}
                if($case -eq 'invalid_health'){$full.engine_health_passed=$false}
                if($case -eq 'duplicate_envelope'){Write-Utf8CreateNew (Join-Path $full.evidence_path 'child_envelope.json') 'original duplicate-control marker'}
                $compact=Write-R10vCompactChildEnvelope $full $fixtureValue.context
            }
            Assert-R10f (-not $compact.Contains('report')) 'R10V_COMPACT_REPORT_PRESENT'
            $null=Assert-QsdkR10fL15ChildLaunchRelationship $compact $fixtureValue.context
            $bound=Get-R10fRetainedFileBinding (Join-Path $compact.evidence_path 'child_envelope.json')
            Assert-R10f (Test-QsdkR10fL15ExactValue $bound $compact.retained_envelope_binding) 'R10V_COMPACT_BINDING_CHANGED'
            Write-JsonCreateNew (Join-Path $compact.evidence_path 'compact_result.json') $compact
        } catch {$caught=$_.Exception.Message}
        $script:WorkerResource='res://sdk/adapters/godot/gdscript/r10aj_development_worker_v1.gd'
        $releasePath=Join-Path (Join-Path $OutputRoot $case) 'payload_release_receipt.json'
        $passed=if($expectedFailure){$caught -ne '' -and -not (Test-Path -LiteralPath $releasePath)}else{$caught -eq ''}
        if($case -eq 'missing_selector'){$passed=$passed -and $script:NativeExecutorCalls -eq $beforeCalls -and $caught.Contains('R10AJ_NATIVE_OBSERVER_REQUIRED')}
        if($case -eq 'wrong_route'){$passed=$passed -and $script:NativeExecutorCalls -eq $beforeCalls -and $caught.Contains('R10AJ_COMPACT_ROUTE_REQUIRED')}
        if($case -eq 'crossed_runtime'){$passed=$passed -and $script:NativeExecutorCalls -eq $beforeCalls -and $caught.Contains('R10AJ_HOST_BINDING_NOT_EXACT')}
        if($case -eq 'ambiguous_selector'){$passed=$passed -and $script:NativeExecutorCalls -eq $beforeCalls -and $caught.Contains('COMPACT_ROUTE_AMBIGUOUS')}
        if($case -eq 'integrated_child'){$passed=$passed -and $script:NativeExecutorCalls -eq $beforeCalls+1}
        $results.Add(@{case=$case;passed=$passed;expected_refusal=$expectedFailure;failure_code=$caught;native_executor_calls=$script:NativeExecutorCalls-$beforeCalls})
        $full=$null;$compact=$null;$script:FakeRun=$null
        [GC]::Collect();[GC]::WaitForPendingFinalizers();[GC]::Collect()
    }
} finally { $script:FakeRun=$null }
$result=@{ok=@($results | Where-Object {-not $_.passed}).Count -eq 0;cases=@($results);world_build_count=0;solver_step_count=0;physical_acceptance_authority=$false;release_authority=$false}
Write-JsonCreateNew (Join-Path $OutputRoot 'result.json') $result
$result | ConvertTo-Json -Depth 20 -Compress
if(-not $result.ok){exit 1}
