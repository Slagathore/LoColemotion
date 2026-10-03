#requires -Version 7.0
<#
Zero-world diagnostic replay only. The Python auditor supplies hash-checked
historical source text. We execute only the named PID predicate and publication
tail, not the launcher, physics, file writer, or complete historical supervisor.
All changed PID values are in-memory one-predicate controls, never adopted data.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$l15Input = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 100
$l15ExpectedRoot = 'C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r10f-development-route-ghost-a66bbba5d4213f9f'
if ([IO.Path]::GetFullPath([string]$l15Input.evidence_root) -cne $l15ExpectedRoot) {
    throw 'L15_REPLAY_EVIDENCE_ROOT'
}

function Get-L15ParsedSource {
    param([string]$Text)
    $tokens = $null
    $parseErrors = $null
    $parsed = [Management.Automation.Language.Parser]::ParseInput(
        $Text, [ref]$tokens, [ref]$parseErrors
    )
    if ($parseErrors.Count -ne 0) { throw 'L15_FROZEN_SOURCE_PARSE' }
    return $parsed
}

function Get-L15Function {
    param($SourceAst, [string]$Name)
    $found = @($SourceAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -ceq $Name
    }, $true))
    if ($found.Count -ne 1) { throw ('L15_FROZEN_FUNCTION:' + $Name) }
    return $found[0]
}

$l15SupervisorAst = Get-L15ParsedSource $l15Input.supervisor_source
$l15PairAst = Get-L15ParsedSource $l15Input.pair_source
$l15Publisher = Get-L15Function $l15SupervisorAst 'Write-L9SupervisorResult'
$l15Caller = Get-L15Function $l15SupervisorAst 'Invoke-Physical'
$l15Marker = @($l15SupervisorAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left.Extent.Text -ceq '$script:PhysicalMarker'
}, $true))
if ($l15Marker.Count -ne 1) { throw 'L15_FROZEN_MARKER' }
. ([scriptblock]::Create($l15Marker[0].Extent.Text))

function Read-L15BoundReport {
    param([string]$Name)
    if ($Name -notin @('supervisor_result.json', 'terminal_supervisor_failure.json')) {
        throw 'L15_REPLAY_REPORT_NAME'
    }
    $binding = $l15Input.report_bindings[$Name]
    $raw = [IO.File]::ReadAllBytes((Join-Path $l15ExpectedRoot $Name))
    $digest = 'sha256:' + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($raw)
    ).ToLowerInvariant()
    if ($raw.Length -ne $binding.byte_length -or $digest -cne $binding.raw_sha256) {
        throw ('L15_REPLAY_REPORT_CONTENT_ADDRESS:' + $Name)
    }
    return [Text.Encoding]::UTF8.GetString($raw) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

$l15Report = Read-L15BoundReport 'supervisor_result.json'
$l15Failure = Read-L15BoundReport 'terminal_supervisor_failure.json'
$l15Tail = (@($l15Publisher.Body.EndBlock.Statements |
    Select-Object -Last 2 | ForEach-Object { $_.Extent.Text })) -join "`n"
$l15Return = @($l15Publisher.Body.EndBlock.Statements | Select-Object -Last 1)[0].Extent.Text
$l15If = @($l15Caller.Body.EndBlock.Statements | Where-Object {
    $_ -is [Management.Automation.Language.IfStatementAst]
} | Select-Object -Last 1)[0]
$l15Condition = $l15If.Clauses[0].Item1.Extent.Text

# These are the unchanged historical statements and the actual retained result.
$supervisor = $l15Report
$l15Mixed = @(& ([scriptblock]::Create($l15Tail)))
$supervisor = $l15Mixed
$l15Exception = $null
try { $null = & ([scriptblock]::Create($l15Condition)) }
catch { $l15Exception = $_.Exception.Message }
$supervisor = $l15Report
$l15Single = @(& ([scriptblock]::Create($l15Return)))
$supervisor = $l15Single[0]
$l15InvalidExit = & ([scriptblock]::Create($l15Condition))
if ($l15Mixed.Count -ne 2 -or $l15Single.Count -ne 1 -or
    $l15Exception -cne $l15Failure.failure_code -or $l15InvalidExit -ne $true) {
    throw 'L15_PUBLICATION_REPRODUCTION'
}

$l15Integer = Get-L15Function $l15PairAst 'Test-QsdkR10fL9ExactInteger'
. ([scriptblock]::Create($l15Integer.Extent.Text))
$l15PidCall = @($l15PairAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -ceq 'Add-QsdkR10fL9ValidationError' -and
    $node.CommandElements[-1].Extent.Text -like '*CHILD_PROCESS_RECEIPT_INVALID:*'
}, $true))
if ($l15PidCall.Count -ne 1) { throw 'L15_FROZEN_PID_PREDICATE' }
$l15PidPredicate = $l15PidCall[0].CommandElements[2].Extent.Text
$l15PidResults = @()
foreach ($l15Observed in $l15Report.child_envelopes) {
    $envelope = $l15Observed
    $l15Original = & ([scriptblock]::Create($l15PidPredicate))
    $l15Alias = [ordered]@{}
    foreach ($l15Key in $l15Observed.Keys) { $l15Alias[$l15Key] = $l15Observed[$l15Key] }
    $l15Alias['process_id'] = $l15Alias['worker_process_id']
    $envelope = $l15Alias
    $l15Aliased = & ([scriptblock]::Create($l15PidPredicate))
    if ($l15Original -ne $false -or $l15Aliased -ne $true) {
        throw 'L15_PID_REPRODUCTION'
    }
    $l15PidResults += [ordered]@{
        role = $l15Observed.role
        process_id = $l15Observed.process_id
        worker_process_id = $l15Observed.worker_process_id
        original_predicate = $l15Original
        one_field_same_pid_fixture_predicate = $l15Aliased
    }
}

[ordered]@{
    publication_tail = $l15Tail
    caller_condition = $l15Condition
    mixed_output_count = $l15Mixed.Count
    mixed_output_types = @($l15Mixed | ForEach-Object { $_.GetType().FullName })
    reproduced_failure = $l15Exception
    return_only_output_count = $l15Single.Count
    return_only_invalid_exit_condition = $l15InvalidExit
    frozen_pair_predicate = $l15PidPredicate
    pid_results = $l15PidResults
    complete_supervisor_or_file_writer_invoked = $false
    whole_child_acceptance_inferred = $false
    historical_data_modified = $false
    model_construction_count = 0
    world_build_count = 0
    native_physics_read_count = 0
    solver_step_count = 0
    physical_acceptance_authority = $false
    release_authority = $false
} | ConvertTo-Json -Depth 10 -Compress
