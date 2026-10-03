#requires -Version 7.5
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$l15Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($l15Root -cne 'C:\Users\Cole\CodeStuff\games\SporeSpore') { throw 'L15_CONSUMER_TEST_ROOT' }
. (Join-Path $l15Root 'sdk/qsdk_r10f_l14_runtime_binding.ps1')
. (Join-Path $l15Root 'sdk/qsdk_r10f_l15_launch_relationship.ps1')
. (Join-Path $l15Root 'sdk/qsdk_r10f_process_isolated_pair_evaluator.ps1')

# Load the complete early caller, not its predicate or a substituted validator.
# Do not execute the supervisor's top-level preflight/physical dispatch.
$tokens = $null
$parseErrors = $null
$tree = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $l15Root 'sdk/run_qsdk_r10f_continuous_passive_recovery.ps1'),
    [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'L15_SUPERVISOR_PARSE' }
foreach ($name in @('Test-ExactInteger', 'Get-L9ChildLaunchValidation')) {
    $nodes = @($tree.FindAll({ param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name
    }, $false))
    if ($nodes.Count -ne 1) { throw ('L15_FUNCTION_COUNT:' + $name) }
    . ([scriptblock]::Create($nodes[0].Extent.Text))
}
$script:RepairId = 'QSDK-R10F-L14'
$fixture = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
$results = [Collections.Generic.List[object]]::new()
foreach ($case in $fixture.cases) {
    $report = $case.report
    $script:PhysicalAttemptId = $report.attempt_id
    $binding = @{
        authority = @{ source_commit = $report.source_commit }
        authority_sha256 = $report.authority_sha256
        l14_exact_runtime_images = Get-QsdkR10fL14ExpectedRuntimeBinding
    }
    $early = Get-L9ChildLaunchValidation `
        -Envelope $report.child_envelopes[0] -Descriptor $report.ordered_child_manifest[0] `
        -Binding $binding -RequireL15LaunchRelationship
    $pair = Invoke-QsdkR10fL9ProcessPopulationEvaluation `
        -ChildEnvelopes $report.child_envelopes -ExpectedParentAttemptId $report.attempt_id `
        -ExpectedSourceCommit $report.source_commit -ExpectedAuthoritySha256 $report.authority_sha256 `
        -ExpectedRuntimeBinding $binding.l14_exact_runtime_images `
        -ExpectedChildManifest $report.ordered_child_manifest -RequireL15LaunchRelationship
    $results.Add([ordered]@{
        name = $case.name
        early_ok = $early.ok
        early_launch_error = $early.l15_launch_relationship_failure
        pair_ok = $pair.ok
        pair_route_valid = $pair.route_execution_valid
        evaluator_invocation_count = $pair.evaluator_invocation_count
        pair_errors = $pair.population_validation_errors
    })
}
[ordered]@{ results = @($results); model_construction_count = 0; world_build_count = 0;
    native_physics_read_count = 0; solver_step_count = 0 } | ConvertTo-Json -Compress -Depth 100
