#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageTwoCommit = "7d71a4d5b39bab8756e639247e70216ca104269a"
$stageTwoParent = "b793070f219ad52dfe6a0edfaa1781a683c1fdae"
$fixedBlobs = [ordered]@{
    "sdk/turning/r23d12_stage_two_evidence_contract_v1.json" =
        "179aecb4420cbb2df00099d7dea0d9ae5e6437854938423ef7491a47a60e7bef"
    "tests/test_qsdk_r23d12_stage_two_evidence.ps1" =
        "e3b07899cde8b029510f9ba1d8ef5cc60641f95bec9d1368da0a434da0c0c6ce"
    ".gitattributes" =
        "0f2b3e6b2a658e06f3bb8d724d3f5d0ff36853d8ce1d35ff5fac295a0095286b"
    "docs/README.md" =
        "8efbe8a77c9a31066c4fd4e6a2c437203ee9fdb21b698f97d735494a1b68e51e"
}
$expectedChangedPaths = @(
    "sdk/publish_qsdk_r23d12_trace.ps1",
    "sdk/turning/r23d12_physical_evaluator.py",
    "sdk/turning/r23d12_physical_trace.py",
    "sdk/turning/r23d12_stage_two_evidence_contract_v1.json",
    "sdk/turning/test_r23d12_physical_evaluator.py",
    "sdk/turning/test_r23d12_physical_trace.py",
    "tests/test_qsdk_r23d12_stage_two_evidence.ps1"
)
$futurePaths = @(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d12_stability_assisted_taper_physical.py",
    "sdk/adapters/mujoco/test_qsdk_r23d12_stability_assisted_taper_physical.py",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d12_physical.rs",
    "tests/test_sdk_qsdk_r23d12_stability_assisted_taper_godot_jolt_worker.gd",
    "tests/test_sdk_qsdk_r23d12_stability_assisted_taper_godot_jolt_physical_worker.gd",
    "sdk/turning/r23d12_physical_implementation_contract_v1.json",
    "sdk/turning/r23d12_dependency_closure.ps1",
    "sdk/turning/r23d12_terminal_marker_classifier.ps1",
    "sdk/run_qsdk_r23d12_mujoco_worker_preflight.ps1",
    "sdk/run_qsdk_r23d12_rapier_worker_preflight.ps1",
    "sdk/run_qsdk_r23d12_godot_jolt_worker_preflight.ps1",
    "sdk/run_qsdk_r23d12_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d12_supervisor.ps1",
    "sdk/run_qsdk_r23d12_zero_world_gate.ps1",
    "tests/test_qsdk_r23d12_dependency_and_marker_contract.ps1",
    "tests/test_qsdk_r23d12_implementation.ps1"
)

function Assert-R23D12StageTwoClosure(
    [bool]$Condition,
    [string]$Message
) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D12StageTwoBlobHash([string]$Commit, [string]$Path) {
    $blobOid = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D12StageTwoClosure ($LASTEXITCODE -eq 0) (
        "QSDK-R23D12 stage-two blob unavailable: $Path"
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    [void]$start.ArgumentList.Add("cat-file")
    [void]$start.ArgumentList.Add("blob")
    [void]$start.ArgumentList.Add($blobOid)
    $process = [Diagnostics.Process]::Start($start)
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $process.WaitForExit()
        Assert-R23D12StageTwoClosure ($process.ExitCode -eq 0) (
            "QSDK-R23D12 stage-two blob read failed: $Path"
        )
        $digest = [Security.Cryptography.SHA256]::HashData($memory.ToArray())
        return [Convert]::ToHexString($digest).ToLowerInvariant()
    }
    finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

Assert-R23D12StageTwoClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D12 stage-two closure repository identity changed"

$resolvedCommit = (git -C $repoRoot rev-parse "$stageTwoCommit^{commit}").Trim()
$resolvedParent = (git -C $repoRoot rev-parse "$stageTwoCommit^").Trim()
Assert-R23D12StageTwoClosure (
    $resolvedCommit -ceq $stageTwoCommit -and
    $resolvedParent -ceq $stageTwoParent
) "QSDK-R23D12 stage-two commit boundary changed"

$actualChangedPaths = @(
    git -C $repoRoot diff --name-only $stageTwoParent $stageTwoCommit
)
Assert-R23D12StageTwoClosure (
    (@($actualChangedPaths | Sort-Object) -join "`n") -ceq
        (@($expectedChangedPaths | Sort-Object) -join "`n")
) "QSDK-R23D12 stage-two changed-path set moved"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageTwoCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D12StageTwoClosure ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D12 stage-two tree already contained future route: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D12StageTwoClosure (
        (Get-R23D12StageTwoBlobHash $stageTwoCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D12 stage-two fixed blob changed: $($entry.Key)"
}

$contractSpec = (
    $stageTwoCommit +
    ":sdk/turning/r23d12_stage_two_evidence_contract_v1.json"
)
$contract = (git -C $repoRoot show $contractSpec | Out-String) |
    ConvertFrom-Json -AsHashtable -Depth 100
$bindings = [Collections.Generic.List[object]]::new()
$bindings.Add([pscustomobject]@{
    path = [string]$contract.stage_one_boundary.historical_closure_audit_path
    hash = ([string]$contract.stage_one_boundary.historical_closure_audit_raw_sha256).
        Substring(7)
})
foreach ($sectionName in @(
    "production_trace_contract",
    "production_evaluator_contract"
)) {
    $section = $contract[$sectionName]
    foreach ($pair in @(
        @("implementation_path", "implementation_raw_sha256"),
        @("test_path", "test_raw_sha256")
    )) {
        $bindings.Add([pscustomobject]@{
            path = [string]$section[$pair[0]]
            hash = ([string]$section[$pair[1]]).Substring(7)
        })
    }
}
foreach ($pair in @(
    @("publisher_path", "publisher_raw_sha256"),
    @("store_path", "store_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$contract.content_addressed_retention[$pair[0]]
        hash = ([string]$contract.content_addressed_retention[$pair[1]]).
            Substring(7)
    })
}
$bindings.Add([pscustomobject]@{
    path = [string]$contract.diagnostic_trace_contract.semantics_path
    hash = ([string]$contract.diagnostic_trace_contract.semantics_raw_sha256).
        Substring(7)
})

Assert-R23D12StageTwoClosure (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d12_stage_two_evidence_contract_v1" -and
    [string]$contract.status -ceq
        "stage_two_zero_world_independent_diagnostic_trace_retention_and_production_evaluator_complete_no_physical_workers_or_authorization" -and
    [string]$contract.stage_one_boundary.commit -ceq
        "f5c686e94c4702cac9a8aadcbcc3e42e2bb83bbb" -and
    [string]$contract.stage_one_boundary.closure_commit -ceq $stageTwoParent -and
    [int]$contract.stage_one_boundary.historical_native_semantics_route_count -eq
        3 -and
    [int]$contract.stage_one_boundary.historical_valid_canary_count -eq 21 -and
    [int]$contract.stage_one_boundary.historical_active_cross_product_count -eq
        18 -and
    [int]$contract.stage_one_boundary.historical_mutation_refusal_count -eq 42 -and
    [string]$contract.production_trace_contract.trace_schema -ceq
        "sporespore_qsdk_r23d12_physical_trace_v1" -and
    [string]$contract.production_trace_contract.row_schema -ceq
        "sporespore_qsdk_r23d12_physical_trace_row_v1" -and
    [int]$contract.production_trace_contract.trace_row_field_count -eq 35 -and
    [int]$contract.production_trace_contract.complete_trace_rows_per_cell -eq
        3892 -and
    [int]$contract.production_trace_contract.declared_trace_identity_count -eq
        11 -and
    [int]$contract.production_trace_contract.trace_test_count -eq 9 -and
    [int]$contract.diagnostic_trace_contract.field_count -eq 7 -and
    [bool]$contract.diagnostic_trace_contract.planner_availability_controls_only_stability_fallback -and
    [bool]$contract.diagnostic_trace_contract.support_margin_availability_controls_only_margin_nullability -and
    [bool]$contract.diagnostic_trace_contract.planner_and_support_margin_availability_are_independent -and
    [bool]$contract.diagnostic_trace_contract.all_six_active_cross_product_states_valid -and
    [bool]$contract.diagnostic_trace_contract.both_passive_margin_states_valid -and
    [bool]$contract.diagnostic_trace_contract.r23d11_observation_unavailable_with_measured_finite_margin_shape_valid -and
    [int]$contract.diagnostic_trace_contract.direct_diagnostic_mutation_refusal_count -eq
        11 -and
    [int]$contract.diagnostic_trace_contract.cas_retention_new_field_rewrite_refusal_count -eq
        1 -and
    [int]$contract.diagnostic_trace_contract.new_decision_threshold_count -eq 0 -and
    -not [bool]$contract.diagnostic_trace_contract.fields_grant_outcome_or_acceptance_authority -and
    [bool]$contract.content_addressed_retention.attempt_trace_staging_uses_exclusive_creation -and
    [bool]$contract.content_addressed_retention.digest_derived_cas_path_shape_revalidated -and
    [bool]$contract.production_evaluator_contract.exact_expected_source_commit_required_by_both_evaluator_commands -and
    [bool]$contract.production_evaluator_contract.all_report_source_commits_must_match_expected_source_commit -and
    [int]$contract.next_implementation_boundary.production_physical_worker_count -eq
        0 -and
    -not [bool]$contract.next_implementation_boundary.serialized_supervisor_implemented -and
    -not [bool]$contract.next_implementation_boundary.physical_execution_authorized -and
    -not [bool]$contract.claim_boundary.command_conditioned_turning -and
    -not [bool]$contract.claim_boundary.cross_engine_equivalence -and
    -not [bool]$contract.claim_boundary.physical_acceptance_authority -and
    $bindings.Count -eq 8
) "QSDK-R23D12 stage-two claim boundary changed"

foreach ($binding in $bindings) {
    Assert-R23D12StageTwoClosure (
        (Get-R23D12StageTwoBlobHash $stageTwoCommit $binding.path) -ceq
            $binding.hash
    ) "QSDK-R23D12 stage-two source binding changed: $($binding.path)"
}

Write-Host (
    "QSDK_R23D12_STAGE_TWO_CLOSURE_PASS commit=$stageTwoCommit " +
    "changed_paths=$($expectedChangedPaths.Count) fixed_blobs=$($fixedBlobs.Count) " +
    "source_bindings=$($bindings.Count) future_routes=0 workers=0 models=0 " +
    "worlds=0 physical_authority=False"
)
