#requires -Version 7.5
# Source-only composition: actual envelope writer, full post-allocation caller,
# pair validation and supervisor publication; only process execution/lock are seams.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($root -cne 'C:\Users\Cole\CodeStuff\games\SporeSpore') { throw 'L15_ENCLOSING_TEST_ROOT' }
. (Join-Path $root 'sdk/godot_receipt_terminated_process.ps1')
. (Join-Path $root 'sdk/qsdk_r10f_l14_runtime_binding.ps1')
. (Join-Path $root 'sdk/qsdk_r10f_l15_launch_relationship.ps1')
. (Join-Path $root 'sdk/qsdk_r10f_process_isolated_pair_evaluator.ps1')
. (Join-Path $root 'sdk/exact_json_transport.ps1')
$fixture = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
$omitActive = $false
if ($fixture.Contains('omit_active_child_for_missing_peer_test')) {
    if ($fixture.omit_active_child_for_missing_peer_test -isnot [bool]) { throw 'L15_MISSING_PEER_FLAG_KIND' }
    $omitActive = $fixture.omit_active_child_for_missing_peer_test
}
if ($omitActive -and ($fixture.runs.Count -ne 1 -or $fixture.report.child_envelopes.Count -ne 1)) {
    throw 'L15_MISSING_PEER_FIXTURE_SOURCE_COUNT'
}
$tokens = $null
$parseErrors = $null
$tree = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $root 'sdk/run_qsdk_r10f_continuous_passive_recovery.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'L15_ENCLOSING_SOURCE_PARSE' }
function Find-ActualFunction([string]$Name) {
    $nodes = @($tree.FindAll({ param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $Name
    }, $false))
    if ($nodes.Count -ne 1) { throw ('L15_ENCLOSING_SOURCE_FUNCTION:' + $Name) }
    return $nodes[0]
}
foreach ($name in @(
    'Assert-R10f', 'Get-R10fLedgerScope', 'Get-PrefixedSha256', 'Test-ExactInteger',
    'Write-Utf8CreateNew', 'Write-JsonCreateNew', 'Get-R10fRetainedFileBinding',
    'Get-OptionalSingleMarkerJson', 'Get-L9ObservedCounterProjection',
    'Get-L9ChildLaunchValidation', 'New-QsdkR10fL9ChildEnvironment', 'Invoke-L9ChildProcess',
    'Write-L9SupervisorResult', 'Publish-L15SupervisorResult', 'Select-L15ProductionFamily'
)) { . ([scriptblock]::Create((Find-ActualFunction $name).Extent.Text)) }
foreach ($name in @(
    'GateId', 'GateToken', 'CampaignId', 'RawSchema', 'RawMarker', 'ReadyMarker',
    'PhysicalMarker', 'WorkerResource', 'WorkId', 'DevelopmentSeed',
    'DevelopmentSeedLabel', 'DevelopmentSeedSha256', 'ActuatorMode', 'ControllerId',
    'EnergyRouteId', 'MaximumWorldCount', 'MaximumChildWorldCount',
    'MaximumSolverStepCount', 'MaximumChildSolverStepCount'
)) {
    $assignments = @($tree.EndBlock.Statements | Where-Object {
        $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $_.Left.Extent.Text -ceq ('$script:' + $name)
    })
    if ($assignments.Count -ne 1) { throw ('L15_ENCLOSING_SOURCE_ASSIGNMENT:' + $name) }
    . ([scriptblock]::Create($assignments[0].Extent.Text))
}
$script:RepoRoot = $root
# Exercise actual family selection; the process/authority seams below still forbid physics.
Select-L15ProductionFamily
$script:PhysicalAttemptId = $fixture.report.attempt_id
$script:PhysicalAttemptRoot = [IO.Path]::GetFullPath($fixture.fixture_root)
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $root '../SporeSpore_Evidence'))
if ([IO.Path]::GetDirectoryName($script:PhysicalAttemptRoot) -cne $evidenceRoot -or
    -not [IO.Path]::GetFileName($script:PhysicalAttemptRoot).StartsWith('qsdk-r10f-l15-enclosing-')) {
    throw 'L15_ENCLOSING_DISPOSABLE_ROOT'
}
$script:ObservedChildEnvelopes = [Collections.Generic.List[object]]::new()
$script:L15PrimaryReportWriteCompleted = $false
$script:L15PrimaryReportBinding = $null
$script:L15PrimaryMarkerPublished = $false
$script:EnvironmentNames = @()
$script:ProcessFixtureCallCount = 0
$TimeoutSeconds = 3600
$lock = $null
function Get-SporeSporeLocomotionOperationLockPublicReceipt {
    param($Receipt)
    return @{ source_only_nonphysics_lock_fixture = $true }
}
function Invoke-SporeSporeGodotReceiptTerminatedProcess {
    param($FileName, $Arguments, $WorkingDirectory, $ReadyMarkerPrefix,
        $ExpectedNonce, $Environment, $ScrubEnvironmentNames, $TimeoutSeconds,
        $R10fL15LaunchContext)
    # Return the named source-shaped termination fixture. Do not start anything.
    $index = $script:ProcessFixtureCallCount
    if ($index -ge $fixture.runs.Count) { throw 'L15_ENCLOSING_UNEXPECTED_PROCESS_CALL' }
    $run = $fixture.runs[$index]
    if ($WorkingDirectory -cne $root -or $ExpectedNonce -cne $run.termination_ready_receipt.termination_nonce) {
        throw 'L15_ENCLOSING_LAUNCH_INPUT'
    }
    $payload = $run.r10f_l15_launch_relationship.payload_json | ConvertFrom-Json -AsHashtable -DateKind String
    if (-not (Test-QsdkR10fL15ExactValue $R10fL15LaunchContext $payload.context)) {
        throw 'L15_ENCLOSING_EXPECTED_LAUNCH_CONTEXT'
    }
    $script:ProcessFixtureCallCount += 1
    return $run
}
if ((Get-Command Invoke-SporeSporeGodotReceiptTerminatedProcess).ScriptBlock.File -cne $PSCommandPath) {
    throw 'L15_ENCLOSING_NONPHYSICS_EXECUTOR_REQUIRED'
}
$parentAttemptId = $fixture.report.attempt_id
$childDescriptors = [Collections.Generic.List[object]]::new()
foreach ($descriptor in $fixture.report.ordered_child_manifest) {
    $childDescriptors.Add($descriptor)
    $childRoot = [IO.Path]::GetFullPath($descriptor.evidence_path)
    if (-not $childRoot.StartsWith($script:PhysicalAttemptRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::Ordinal)) {
        throw 'L15_ENCLOSING_CHILD_ROOT'
    }
    $null = [IO.Directory]::CreateDirectory($childRoot)
    # Fixed synthetic identifiers, not the real prospective reservation method.
    $identity = @{}
    foreach ($key in $descriptor.Keys) { $identity[$key] = $descriptor[$key] }
    $identity.schema_version = 'sporespore_qsdk_r10f_l9_child_attempt_identity_v1'
    $identity.gate_id = $script:GateId
    $identity.repair_id = $script:RepairId
    $identity.status = 'reserved_and_retained_before_first_child_start'
    $identity.parent_attempt_id = $parentAttemptId
    $identity.source_commit = $fixture.report.source_commit
    $identity.authority_sha256 = $fixture.report.authority_sha256
    $identity.physical_acceptance_authority = $false
    $identity.release_authority = $false
    Write-JsonCreateNew (Join-Path $childRoot 'child_attempt_identity.json') $identity
}
$attempt = @{ ordered_child_manifest = @($childDescriptors) }
$binding = @{
    authority = @{ source_commit = $fixture.report.source_commit }
    authority_sha256 = $fixture.report.authority_sha256
    repair_design_sha256 = $fixture.report.repair_design_sha256
    branch_completeness_addendum_sha256 = $fixture.report.branch_completeness_addendum_sha256
    consumed_predecessor_physical_closure_sha256 = $fixture.report.consumed_predecessor_physical_closure_sha256
    l14_exact_runtime_images = Get-QsdkR10fL14ExpectedRuntimeBinding
    l15_prepared_context_expectation = @{
        # Supplied by an independent preparation in the calling test, not by a
        # worker's report. This is not an official qualification-origin receipt.
        raw_capture_binding = $fixture.expected_context_binding
        collection_identity = $fixture.expected_collection_identity
    }
}
$godotPath = $binding.l14_exact_runtime_images.images.godot_console.path
$caught = ''
try {
    $function = Find-ActualFunction 'Invoke-Physical'
    $statements = @($function.Body.EndBlock.Statements)
    $starts = @(0..($statements.Count - 1) | Where-Object {
        $statements[$_].Extent.Text.StartsWith('$baseline = Invoke-L9ChildProcess')
    })
    if ($starts.Count -ne 1) { throw 'L15_ENCLOSING_CALLER_BOUNDARY' }
    # No authorization check, identity reservation or physical executor runs.
    # Everything after that boundary is complete production source, including exits.
    $selected = @($statements[$starts[0]..($statements.Count - 1)])
    if ($omitActive) {
        # Named source-only absence fault: omit exactly the active invocation.
        # The real baseline call, complete pair reader, writer and publisher run.
        # This does not emulate an OS launch failure or the supervisor catch.
        $activeCalls = @($selected | Where-Object { $_.Extent.Text.StartsWith('$active = Invoke-L9ChildProcess') })
        if ($activeCalls.Count -ne 1) { throw 'L15_MISSING_PEER_CALL_BOUNDARY' }
        $selected = @($selected | Where-Object { $_ -ne $activeCalls[0] })
    }
    . ([scriptblock]::Create(($selected.Extent.Text) -join "`n"))
} catch { $caught = $_.Exception.Message }
finally {
    Write-JsonCreateNew (Join-Path $script:PhysicalAttemptRoot 'test_control.json') ([ordered]@{
        process_fixture_call_count = $script:ProcessFixtureCallCount
        actual_envelope_writer_and_supervisor_caller_executed = $true
        actual_runtime_image_checks_executed = $true
        source_only_fixture_not_physical_identity = $true
        active_invocation_omitted_for_missing_peer_test = $omitActive
        physical_marker = $script:PhysicalMarker
        caught_failure = $caught
        model_construction_count = 0; world_build_count = 0
        native_physics_read_count = 0; solver_step_count = 0
    })
}
