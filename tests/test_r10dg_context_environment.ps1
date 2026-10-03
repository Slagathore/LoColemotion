#requires -Version 7.5
param([ValidateSet('Project', 'Launch')][string]$Mode = 'Project')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($root -cne 'C:\Users\Cole\CodeStuff\games\SporeSpore') { throw 'L15_ENVIRONMENT_TEST_ROOT' }
. (Join-Path $root 'sdk/qsdk_r10f_l15_context_source.ps1')
. (Join-Path $root 'sdk/exact_json_transport.ps1')
$fixture = ConvertFrom-QsdkR10fL15ContextJson ([Console]::In.ReadToEnd())
if ($Mode -ceq 'Project') {
    $results = [Collections.Generic.List[object]]::new()
    foreach ($case in $fixture.cases) {
        $environment = $null
        $failure = ''
        try {
            $value = ConvertFrom-QsdkR10fL15ContextJson $case.raw
            $environment = Get-QsdkR10fL15ContextEnvironment $value
        } catch { $failure = $_.Exception.Message }
        $results.Add(@{ name = $case.name; environment = $environment; failure = $failure })
    }
    @{ results = @($results) } | ConvertTo-Json -Compress -Depth 100
    exit 0
}

. (Join-Path $root 'sdk/godot_receipt_terminated_process.ps1')
. (Join-Path $root 'sdk/qsdk_r10f_l14_runtime_binding.ps1')
$script:ActualBoundedLauncher = (Get-Command Invoke-SporeSporeGodotReceiptTerminatedProcess).ScriptBlock
$tokens = $null
$parseErrors = $null
$tree = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $root 'sdk/run_qsdk_r10f_continuous_passive_recovery.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'L15_ENVIRONMENT_SOURCE_PARSE' }
foreach ($name in @('Assert-R10f', 'Get-PrefixedSha256', 'Write-Utf8CreateNew',
    'Write-JsonCreateNew', 'Get-R10fRetainedFileBinding', 'Get-OptionalSingleMarkerJson', 'New-QsdkR10fL9ChildEnvironment', 'Invoke-L9ChildProcess')) {
    $nodes = @($tree.FindAll({ param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name
    }, $false))
    if ($nodes.Count -ne 1) { throw ('L15_ENVIRONMENT_SOURCE_FUNCTION:' + $name) }
    . ([scriptblock]::Create($nodes[0].Extent.Text))
}
foreach ($name in @('GateId', 'GateToken', 'RawSchema', 'RawMarker', 'ReadyMarker',
    'WorkerResource', 'WorkId', 'DevelopmentSeed', 'DevelopmentSeedLabel',
    'DevelopmentSeedSha256', 'ActuatorMode', 'ControllerId', 'EnergyRouteId', 'EnvironmentNames')) {
    $nodes = @($tree.EndBlock.Statements | Where-Object {
        $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $_.Left.Extent.Text -ceq ('$script:' + $name)
    })
    if ($nodes.Count -ne 1) { throw ('L15_ENVIRONMENT_SOURCE_ASSIGNMENT:' + $name) }
    . ([scriptblock]::Create($nodes[0].Extent.Text))
}
$script:RepoRoot = $root
$script:RepairId = $fixture.repair_id
if ($script:RepairId -cnotin @('QSDK-R10F-L15', 'QSDK-R10F-L14')) { throw 'L15_ENVIRONMENT_TEST_REPAIR' }
$script:PhysicalAttemptId = $fixture.parent_attempt_id # Fixed source-fixture label, not reservation.
$script:ObservedChildEnvelopes = [Collections.Generic.List[object]]::new()
$script:LauncherCallCount = 0
$script:OfferedEnvironment = $null
$script:OfferedScrubNames = $null
$script:OriginalWorkerArguments = $null
$TimeoutSeconds = 30
$originalScrubNames = @($script:EnvironmentNames)
$directory = [IO.Path]::GetFullPath($fixture.fixture_root)
$evidence = [IO.Path]::GetFullPath((Join-Path $root '../SporeSpore_Evidence'))
if ([IO.Path]::GetDirectoryName($directory) -cne $evidence -or
    -not [IO.Path]::GetFileName($directory).StartsWith('qsdk-r10f-l15-environment-')) {
    throw 'L15_ENVIRONMENT_DISPOSABLE_ROOT'
}
$descriptor = $fixture.descriptor
$descriptor.evidence_path = Join-Path $directory 'child'
$null = [IO.Directory]::CreateDirectory($descriptor.evidence_path)
Write-JsonCreateNew (Join-Path $descriptor.evidence_path 'child_attempt_identity.json') @{
    source_only_not_prospective_identity = $true; descriptor = $descriptor
}
$binding = @{
    authority = @{ source_commit = $fixture.source_commit }
    authority_sha256 = $fixture.authority_sha256
    l14_exact_runtime_images = Get-QsdkR10fL14ExpectedRuntimeBinding
    l15_prepared_context_expectation = $fixture.expectation
}
function Invoke-SporeSporeGodotReceiptTerminatedProcess {
    param($FileName, $Arguments, $WorkingDirectory, $ReadyMarkerPrefix,
        $ExpectedNonce, $Environment, $ScrubEnvironmentNames, $TimeoutSeconds,
        $R10fL15LaunchContext)
    # The sole launch seam substitutes a declared ZERO-WORLD receiver resource.
    # The complete sender, runtime checks, environment and actual launcher run.
    $wanted = @('--headless', '--path', $root, '--script', $script:WorkerResource)
    if (-not (Test-QsdkR10fL15ExactValue $Arguments $wanted)) { throw 'L15_ENVIRONMENT_WORKER_ARGUMENTS' }
    $script:OriginalWorkerArguments = @($Arguments)
    $script:OfferedEnvironment = $Environment.Clone()
    $script:OfferedScrubNames = @($ScrubEnvironmentNames)
    $parameters = @{} + $PSBoundParameters
    $parameters.Arguments = @('--headless', '--path', $root, '--script',
        'res://tests/test_sdk_qsdk_r10f_l15_context_environment_receiver_zero_world.gd',
        '--', $script:RepairId)
    $script:LauncherCallCount += 1
    # Exercise the handle-based observer selected by the R10DG production launcher.
    if ($parameters.ContainsKey('R10fL15LaunchContext') -and $null -ne $parameters.R10fL15LaunchContext) {
        $parameters.R10xNativeProcessObservation = $true
    }
    return (& $script:ActualBoundedLauncher @parameters)
}
$names = @('SPORESPORE_GODOT_RECOVERY_L15_CONTEXT_UTF8_BYTE_LENGTH',
    'SPORESPORE_GODOT_RECOVERY_L15_CONTEXT_RAW_SHA256')
$before = @{}
foreach ($name in $names) { $before[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$caught = ''
$envelope = $null
try {
    $envelope = Invoke-L9ChildProcess $descriptor $binding $binding.l14_exact_runtime_images.images.godot_console.path
} catch { $caught = $_.Exception.Message }
$after = @{}
foreach ($name in $names) { $after[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
@{
    schema_version = 'sporespore_qsdk_r10f_l15_context_environment_caller_zero_world_v1'
    ledger_scope = @{
        subsystem = 'recovery'; engine_scope = 'godot_jolt'
        authority_mode = 'source_only_actual_caller_and_launch_receiver'; question_class = 'development'
    }
    caught_failure = $caught; envelope = $envelope; descriptor = $descriptor
    launcher_call_count = $script:LauncherCallCount
    offered_environment = $script:OfferedEnvironment; offered_scrub_names = $script:OfferedScrubNames
    original_worker_arguments = $script:OriginalWorkerArguments
    parent_environment_before = $before; parent_environment_after = $after
    original_script_scrub_names = $originalScrubNames; final_script_scrub_names = @($script:EnvironmentNames)
    actual_runtime_image_checks_executed = $true
    complete_physical_worker_run_executed = $false
    supervisor_outer_catch_executed = $false
    official_qualification_origin_used = $false
    model_construction_count = 0; world_build_count = 0; native_physics_read_count = 0; solver_step_count = 0
    physical_execution_authorized = $false; physical_acceptance_authority = $false; release_authority = $false
} | ConvertTo-Json -Compress -Depth 100
