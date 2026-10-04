#requires -Version 7.5
param([ValidateSet('Live', 'Validate', 'ProducerReject')][string]$Mode = 'Validate')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$l15Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($l15Root -cne 'C:\Users\Cole\CodeStuff\games\LoColemotion') { throw 'L15_TEST_ROOT' }
. (Join-Path $l15Root 'sdk/qsdk_r10f_l15_launch_relationship.ps1')
. (Join-Path $l15Root 'sdk/godot_receipt_terminated_process.ps1')
$fixture = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String

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
            -R10fL15LaunchContext $context
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
