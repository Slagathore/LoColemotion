#requires -Version 7.5
param([ValidateSet('Live', 'Validate', 'ProducerReject', 'Observe', 'RejectMissingContext', 'Guard')][string]$Mode = 'Validate')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$l15Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($l15Root -cne 'C:\Users\Cole\CodeStuff\games\SporeSpore') { throw 'L15_TEST_ROOT' }
. (Join-Path $l15Root 'sdk/qsdk_r10f_l15_launch_relationship.ps1')
. (Join-Path $l15Root 'sdk/godot_receipt_terminated_process.ps1')
# Explicit successor fixture: both production ancestry entrypoints use native observation.
if ($Mode -notin @('Live','RejectMissingContext')) {
    . (Join-Path $l15Root 'sdk/process/r10x_native_process_observation_v1.ps1')
}
function Get-CimInstance { throw 'R10X_CIM_FORBIDDEN_IN_COMPONENT_TEST' }
$fixture = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String

if ($Mode -ceq 'RejectMissingContext') {
    $failure = ''
    try {
        $null = Invoke-SporeSporeGodotReceiptTerminatedProcess -FileName $fixture.python `
            -Arguments @('-B','-c','raise SystemExit(99)') -WorkingDirectory $l15Root `
            -ReadyMarkerPrefix 'R10X_UNREACHABLE ' -ExpectedNonce ('f'*32) -TimeoutSeconds 1 `
            -R10xNativeProcessObservation
    } catch { $failure = $_.Exception.Message }
    @{refused=($failure -ceq 'R10X_NATIVE_OBSERVER_REQUIRES_L15_CONTEXT');failure=$failure} | ConvertTo-Json -Compress
    exit 0
}

if ($Mode -ceq 'Guard') {
    $real = [ordered]@{
        self=(Test-SporeSporeProcessIsSelfOrDescendant -RootProcessId $PID -CandidateProcessId $PID)
        parent=(Test-SporeSporeProcessIsSelfOrDescendant -RootProcessId $fixture.parent -CandidateProcessId $PID)
        reversed=(Test-SporeSporeProcessIsSelfOrDescendant -RootProcessId $PID -CandidateProcessId $fixture.parent)
        zero_root=(Test-SporeSporeProcessIsSelfOrDescendant -RootProcessId 0 -CandidateProcessId $PID)
        zero_candidate=(Test-SporeSporeProcessIsSelfOrDescendant -RootProcessId $PID -CandidateProcessId 0)
        unavailable=(Test-SporeSporeProcessIsSelfOrDescendant -RootProcessId 2147483647 -CandidateProcessId 2147483647)
        exited=(Test-SporeSporeProcessIsSelfOrDescendant -RootProcessId $fixture.exited -CandidateProcessId $fixture.exited)
    }
    $originalObserver = (Get-Command Get-SporeSporeNativeProcessNodeV1).ScriptBlock
    try {
        $script:r10xGuardMap = @{}
        for ($index = 100; $index -le 116; $index++) {
            $script:r10xGuardMap[$index] = @{process_id=$index;parent_process_id=($index+1);created_utc='2026-01-01T00:00:00.0000000Z'}
        }
        function Get-SporeSporeNativeProcessNodeV1 {
            param([int]$ProcessId)
            if (-not $script:r10xGuardMap.ContainsKey($ProcessId)) { throw 'R10X_SYNTHETIC_PROCESS_UNAVAILABLE' }
            return $script:r10xGuardMap[$ProcessId]
        }
        $synthetic = [ordered]@{
            sixteen_nodes=(Test-SporeSporeProcessIsSelfOrDescendant -RootProcessId 115 -CandidateProcessId 100)
            seventeen_nodes=(Test-SporeSporeProcessIsSelfOrDescendant -RootProcessId 116 -CandidateProcessId 100)
        }
        $script:r10xGuardMap[101].parent_process_id=100
        $synthetic.cycle=Test-SporeSporeProcessIsSelfOrDescendant -RootProcessId 116 -CandidateProcessId 100
        $script:r10xGuardMap[101].created_utc='2026-01-02T00:00:00.0000000Z'
        $synthetic.newer_parent=Test-SporeSporeProcessIsSelfOrDescendant -RootProcessId 101 -CandidateProcessId 100
    } finally { Set-Item -Path Function:Get-SporeSporeNativeProcessNodeV1 -Value $originalObserver }
    @{real=$real;synthetic=$synthetic;world_build_count=0;solver_step_count=0} | ConvertTo-Json -Compress -Depth 10
    exit 0
}

if ($Mode -ceq 'Observe') {
    if ($fixture.repeat -lt 1 -or $fixture.repeat -gt 32 -or $fixture.pids.Count -gt 3) { throw 'R10X_DIAGNOSTIC_BOUND' }
    for ($warm = 0; $warm -lt 5; $warm++) { $null = Get-SporeSporeNativeProcessNodeV1 -ProcessId $PID }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers(); [GC]::Collect()
    $before = [SporeSpore.R10X.ProcessObservationV1]::CurrentHandleCount()
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $rows = [Collections.Generic.List[object]]::new()
    $successfulReads = 0
    foreach ($candidatePid in $fixture.pids) {
        try {
            for ($iteration = 0; $iteration -lt 1; $iteration++) {
                $node = Get-SporeSporeNativeProcessNodeV1 -ProcessId $candidatePid
                $successfulReads++
            }
            $rows.Add(@{accepted=$true;pid=$candidatePid;node=$node})
        } catch { $rows.Add(@{accepted=$false;pid=$candidatePid;failure=$_.Exception.Message}) }
    }
    $timer.Stop()
    [GC]::Collect(); [GC]::WaitForPendingFinalizers(); [GC]::Collect()
    $after = [SporeSpore.R10X.ProcessObservationV1]::CurrentHandleCount()
    $nativeBatch = $null
    if ($fixture.repeat -gt 1 -and $successfulReads -eq 1 -and $fixture.pids.Count -eq 1) {
        Add-Type -Path (Join-Path $l15Root 'tests/fixtures/r10x_native_observer_handle_probe.cs')
        $nativeBatch = [R10XNativeHandleProbe]::Run([int]$fixture.pids[0], [int]$fixture.repeat)
    }
    @{observations=@($rows);successful_reads=$successfulReads;
      powershell_handles_before=$before;powershell_handles_after=$after;native_batch=$nativeBatch;
      lookup_seconds=$timer.Elapsed.TotalSeconds;world_build_count=0;solver_step_count=0;
      physical_acceptance_authority=$false;release_authority=$false} | ConvertTo-Json -Compress -Depth 20
    exit 0
}

if ($Mode -ceq 'ProducerReject') {
    $results = [Collections.Generic.List[object]]::new()
    foreach ($case in $fixture.cases) {
        $accepted = $false
        $failure = ''
        try {
            $null = Get-QsdkR10fL15LaunchRelationshipReceipt `
                $case.context $case.root_process_id $case.worker_process_id `
                $case.started_utc $case.ready_line $case.ready_receipt
            $accepted = $true
        } catch { $failure = $_.Exception.Message }
        $results.Add([ordered]@{ name = $case.name; accepted = $accepted; failure = $failure })
    }
    [ordered]@{ results = @($results) } | ConvertTo-Json -Compress -Depth 100
    exit 0
}

if ($Mode -ceq 'Live') {
    $runs = [Collections.Generic.List[object]]::new()
    foreach ($kind in @('self', 'descendant')) {
        $context = $fixture.context
        $run = Invoke-SporeSporeGodotReceiptTerminatedProcess `
            -FileName $context.root_image.path `
            -Arguments @('-B', (Join-Path $l15Root 'tests/fixtures/qsdk_r10f_l15_nonphysics_process.py'),
                '--mode', $kind, '--nonce', $context.termination_nonce,
                '--marker', $context.ready_marker_prefix) `
            -WorkingDirectory $l15Root -ReadyMarkerPrefix $context.ready_marker_prefix `
            -ExpectedNonce $context.termination_nonce -TimeoutSeconds 30 `
            -R10fL15LaunchContext $context -R10xNativeProcessObservation
        $validationError = ''
        try {
            $null = Assert-QsdkR10fL15LaunchRelationshipReceipt `
                $run.r10f_l15_launch_relationship $context $run.process_id `
                $run.worker_process_id $run.started_utc $run.termination_ready_receipt
        } catch { $validationError = $_.Exception.Message }
        $runs.Add([ordered]@{ kind = $kind; context = $context; run = $run; validation_error = $validationError })
    }
    # The same real production launcher must preserve its old output shape
    # when a legacy caller does not opt in to the new relationship contract.
    $context = $fixture.context
    $legacy = Invoke-SporeSporeGodotReceiptTerminatedProcess `
        -FileName $context.root_image.path `
        -Arguments @('-B', (Join-Path $l15Root 'tests/fixtures/qsdk_r10f_l15_nonphysics_process.py'),
            '--mode', 'self', '--nonce', $context.termination_nonce,
            '--marker', $context.ready_marker_prefix) `
        -WorkingDirectory $l15Root -ReadyMarkerPrefix $context.ready_marker_prefix `
        -ExpectedNonce $context.termination_nonce -TimeoutSeconds 30
    [ordered]@{
        runs = @($runs)
        legacy_run = $legacy
        legacy_contains_l15_field = @($legacy.PSObject.Properties.Name) -ccontains 'r10f_l15_launch_relationship'
        model_construction_count = 0
        world_build_count = 0
        native_physics_read_count = 0
        solver_step_count = 0
    } | ConvertTo-Json -Compress -Depth 100
    exit 0
}

$results = [Collections.Generic.List[object]]::new()
foreach ($case in $fixture.cases) {
    $accepted = $false
    $failure = ''
    try {
        $null = Assert-QsdkR10fL15LaunchRelationshipReceipt `
            $case.receipt $case.context $case.root_process_id $case.worker_process_id `
            $case.started_utc $case.ready_receipt
        $accepted = $true
    } catch { $failure = $_.Exception.Message }
    $results.Add([ordered]@{ name = $case.name; accepted = $accepted; failure = $failure })
}
[ordered]@{ results = @($results) } | ConvertTo-Json -Compress -Depth 100
