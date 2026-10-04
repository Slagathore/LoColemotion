#requires -Version 7.5
param([Parameter(Mandatory)][string]$Case)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($root -cne 'C:\Users\Cole\CodeStuff\games\LoColemotion') { throw 'L15_PUBLICATION_TEST_ROOT' }
. (Join-Path $root 'sdk/qsdk_r10f_l15_launch_relationship.ps1')
. (Join-Path $root 'sdk/qsdk_r10f_process_isolated_pair_evaluator.ps1')
. (Join-Path $root 'sdk/exact_json_transport.ps1')
$fixture = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
$tokens = $null
$parseErrors = $null
$tree = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $root 'sdk/run_qsdk_r10f_continuous_passive_recovery.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'L15_PUBLICATION_SOURCE_PARSE' }
function Find-ActualFunction([string]$Name) {
    $nodes = @($tree.FindAll({ param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $Name
    }, $false))
    if ($nodes.Count -ne 1) { throw ('L15_PUBLICATION_SOURCE_FUNCTION:' + $Name) }
    return $nodes[0]
}
foreach ($name in @(
    'Assert-R10f', 'Get-R10fLedgerScope', 'Get-PrefixedSha256', 'Test-ExactInteger',
    'Write-Utf8CreateNew', 'Write-JsonCreateNew', 'Get-R10fRetainedFileBinding',
    'Get-L9ObservedCounterProjection', 'Get-L9ChildLaunchValidation',
    'Write-L9SupervisorResult', 'Publish-L15SupervisorResult', 'Get-L15PrimaryReportFailureRetention'
)) { . ([scriptblock]::Create((Find-ActualFunction $name).Extent.Text)) }

# Only the lock projection and physical child executor are fixture seams.
# All report construction, early/pair validation, writing, publication, return,
# branching, failure retention and explicit exits execute production source.
function Get-SporeSporeLocomotionOperationLockPublicReceipt { param($Receipt) return @{} }
function Invoke-L9ChildProcess {
    param($Descriptor, $Binding, $GodotPath, [switch]$RequireL15LaunchRelationship)
    $script:ChildFixtureCallCount += 1
    $index = if ($Descriptor.role -ceq 'matched_no_kick_continuation') { 0 } else { 1 }
    $envelope = $fixture.report.child_envelopes[$index]
    $script:ObservedChildEnvelopes.Add($envelope)
    return $envelope
}
if ((Get-Command Invoke-L9ChildProcess).ScriptBlock.File -cne $PSCommandPath) {
    throw 'L15_NONPHYSICS_CHILD_STUB_REQUIRED'
}
$script:GateId = 'QSDK-R10F'
$script:RepairId = $fixture.report.repair_id
$script:CampaignId = $fixture.report.campaign_id
$script:PhysicalMarker = 'QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_PHYSICAL '
$script:RefusalMarker = 'QSDK_R10F_SUPERVISOR_REFUSAL '
# Load these two literal marker assignments from source, not assumed spelling.
foreach ($name in @('PhysicalMarker', 'RefusalMarker')) {
    $assignments = @($tree.EndBlock.Statements | Where-Object {
        $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $_.Left.Extent.Text -ceq ('$script:' + $name)
    })
    if ($assignments.Count -ne 1) { throw 'L15_MARKER_ASSIGNMENT_COUNT' }
    . ([scriptblock]::Create($assignments[0].Extent.Text))
}
$script:MaximumChildWorldCount = 1
$script:MaximumWorldCount = 2
$script:MaximumChildSolverStepCount = 3842
$script:MaximumSolverStepCount = 7684
$script:PhysicalAttemptId = $fixture.report.attempt_id
$script:PhysicalAttemptIdentityConsumed = $true # synthetic enclosing source only
$script:PhysicalAttemptRoot = [IO.Path]::GetFullPath($fixture.fixture_root)
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $root '../SporeSpore_Evidence'))
if ([IO.Path]::GetDirectoryName($script:PhysicalAttemptRoot) -cne $evidenceRoot -or
    -not [IO.Path]::GetFileName($script:PhysicalAttemptRoot).StartsWith('qsdk-r10f-l15-publication-')) {
    throw 'L15_DISPOSABLE_FIXTURE_ROOT'
}
$script:ObservedChildEnvelopes = [Collections.Generic.List[object]]::new()
$script:L15PrimaryReportWriteCompleted = $false
$script:L15PrimaryReportBinding = $null
$script:L15PrimaryMarkerPublished = $false
$script:ChildFixtureCallCount = 0
$lock = $null
$Mode = 'Physical' # The top-level dispatch/reservation is never invoked.
$RunPhysical = $true
$parentAttemptId = $fixture.report.attempt_id
$childDescriptors = [Collections.Generic.List[object]]::new()
foreach ($descriptor in $fixture.report.ordered_child_manifest) { $childDescriptors.Add($descriptor) }
$attempt = @{ ordered_child_manifest = @($childDescriptors) }
$binding = @{
    authority = @{ source_commit = $fixture.report.source_commit }
    authority_sha256 = $fixture.report.authority_sha256
    repair_design_sha256 = $fixture.report.repair_design_sha256
    branch_completeness_addendum_sha256 = $fixture.report.branch_completeness_addendum_sha256
    consumed_predecessor_physical_closure_sha256 = $fixture.report.consumed_predecessor_physical_closure_sha256
    l14_exact_runtime_images = @{} # legacy launch fixtures; no runtime checker or process runs
}
$godotPath = 'unused-nonphysics-fixture'
$caught = ''
$typedOutputCount = -1
$typedDictionary = $false
$originalPrimaryBinding = $null
function Invoke-ActualTerminalCatch {
    $script:RepairId = 'QSDK-R10F-L15'
    $topTry = @($tree.EndBlock.Statements | Where-Object {
        $_ -is [System.Management.Automation.Language.TryStatementAst]
    })[-1]
    if ($topTry.CatchClauses.Count -ne 1) { throw 'L15_ACTUAL_CATCH_COUNT' }
    $actualCatch = ($topTry.CatchClauses[0].Body.Statements.Extent.Text) -join "`n"
    try { throw ('L15_DECLARED_TEST_EXCEPTION:' + $Case) }
    catch { . ([scriptblock]::Create($actualCatch)) }
}
try {
    if ($Case -in @('before_primary_exception', 'partial_primary_exception')) {
        if ($Case -ceq 'partial_primary_exception') {
            # Deliberately incomplete fixture bytes, not a simulated complete
            # report and not a real disk-failure/stream-interruption test.
            Write-Utf8CreateNew (Join-Path $script:PhysicalAttemptRoot 'supervisor_result.json') '{"incomplete":'
        }
        Invoke-ActualTerminalCatch
    } elseif ($Case.StartsWith('caller_') -or $Case.StartsWith('post_publish_')) {
        $function = Find-ActualFunction 'Invoke-Physical'
        $statements = @($function.Body.EndBlock.Statements)
        $starts = @(0..($statements.Count - 1) | Where-Object {
            $statements[$_].Extent.Text.StartsWith('$baseline = Invoke-L9ChildProcess')
        })
        if ($starts.Count -ne 1) { throw 'L15_POST_ALLOCATION_CALLER_BOUNDARY' }
        $completeCaller = ($statements[$starts[0]..($statements.Count - 1)].Extent.Text) -join "`n"
        # This executes both complete child/pair/publication branches, but not
        # physical authorization, Guid reservation, directory allocation or physics.
        . ([scriptblock]::Create($completeCaller))
        if ($Case.StartsWith('post_publish_')) {
            $originalPrimaryBinding = Get-R10fRetainedFileBinding (Join-Path $script:PhysicalAttemptRoot 'supervisor_result.json')
            if ($Case -ceq 'post_publish_changed_primary_exception') {
                [IO.File]::AppendAllText((Join-Path $script:PhysicalAttemptRoot 'supervisor_result.json'), ' ')
            }
            Invoke-ActualTerminalCatch
        }
    } else {
        foreach ($envelope in $fixture.report.child_envelopes) { $script:ObservedChildEnvelopes.Add($envelope) }
        $output = @(Write-L9SupervisorResult $fixture.report.process_population_evaluation $binding $attempt)
        $typedOutputCount = $output.Count
        $typedDictionary = $output.Count -eq 1 -and $output[0] -is [System.Collections.IDictionary]
        if (-not $typedDictionary) { throw 'L15_MIXED_WRITER_RETURN' }
        $supervisor = $output[0]
        $originalPrimaryBinding = Get-R10fRetainedFileBinding (Join-Path $script:PhysicalAttemptRoot 'supervisor_result.json')
        if ($Case -ceq 'post_write_exception') { Invoke-ActualTerminalCatch }
        if ($Case -ceq 'changed_dictionary') { $supervisor.ok = -not $supervisor.ok }
        if ($Case -ceq 'changed_file') {
            [IO.File]::AppendAllText((Join-Path $script:PhysicalAttemptRoot 'supervisor_result.json'), ' ')
        }
        if ($Case -ceq 'writer_already_exists') {
            $null = Write-L9SupervisorResult $fixture.report.process_population_evaluation $binding $attempt
        } else {
            Publish-L15SupervisorResult $supervisor
            if ($Case -ceq 'duplicate') { Publish-L15SupervisorResult $supervisor }
        }
    }
} catch {
    $caught = $_.Exception.Message
} finally {
    $control = [ordered]@{
        case = $Case; child_fixture_call_count = $script:ChildFixtureCallCount
        physical_marker = $script:PhysicalMarker
        typed_output_count = $typedOutputCount; typed_dictionary = $typedDictionary
        caught_failure = $caught; primary_original_binding = $originalPrimaryBinding
        primary_retention = Get-L15PrimaryReportFailureRetention
        model_construction_count = 0; world_build_count = 0
        native_physics_read_count = 0; solver_step_count = 0
        source_only_fixture_not_physical_identity = $true
    }
    Write-JsonCreateNew (Join-Path $script:PhysicalAttemptRoot 'test_control.json') $control
}
