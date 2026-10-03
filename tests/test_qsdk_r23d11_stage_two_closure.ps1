#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageTwoCommit = "166845a67ed0a166cff789b691c76173d85e796b"
$stageTwoParent = "9686045903c3e6ccaf237276526c52c7862e67d2"
$fixedBlobs = [ordered]@{
    "sdk/turning/r23d11_stage_two_evidence_contract_v1.json" =
        "bfa463cb8d6a0d7a43e73fa3d47133c22d1ee3e20b137a454606a85d09ebdc30"
    "tests/test_qsdk_r23d11_stage_two_evidence.ps1" =
        "e1b824cd8f9cfe37ab29ff49ea57e4abe3e81c8fafa8dc0813c89bb6067773c0"
    ".gitattributes" =
        "91f581f766136d4b89cf827bc1a3227c1634a2c58fa1b4b8d9c55a50b86004d9"
    "docs/README.md" =
        "9456a02721d6c241db9299b4be299ff0e40266ec58b87e49e75c4b5bb39929b3"
}
$expectedChangedPaths = @(
    ".gitattributes",
    "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
    "docs/LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md",
    "docs/README.md",
    "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
    "sdk/publish_qsdk_r23d11_trace.ps1",
    "sdk/turning/r23d11_physical_evaluator.py",
    "sdk/turning/r23d11_physical_trace.py",
    "sdk/turning/r23d11_stage_two_evidence_contract_v1.json",
    "sdk/turning/test_r23d11_physical_evaluator.py",
    "sdk/turning/test_r23d11_physical_trace.py",
    "tests/test_qsdk_r23d11_stage_one_closure.ps1",
    "tests/test_qsdk_r23d11_stage_two_evidence.ps1"
)
$futurePaths = @(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d11_stability_assisted_taper_physical.py",
    "sdk/adapters/mujoco/test_qsdk_r23d11_stability_assisted_taper_physical.py",
    "tests/test_sdk_qsdk_r23d11_stability_assisted_taper_godot_jolt_physical_worker.gd",
    "sdk/turning/r23d11_physical_implementation_contract_v1.json",
    "sdk/turning/r23d11_dependency_closure.ps1",
    "sdk/turning/r23d11_terminal_marker_classifier.ps1",
    "sdk/run_qsdk_r23d11_mujoco_worker_preflight.ps1",
    "sdk/run_qsdk_r23d11_rapier_worker_preflight.ps1",
    "sdk/run_qsdk_r23d11_godot_jolt_worker_preflight.ps1",
    "sdk/run_qsdk_r23d11_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d11_supervisor.ps1",
    "sdk/run_qsdk_r23d11_zero_world_gate.ps1"
)

function Assert-R23D11StageTwoClosure(
    [bool]$Condition,
    [string]$Message
) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D11StageTwoBlobHash([string]$Commit, [string]$Path) {
    $blobOid = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D11StageTwoClosure ($LASTEXITCODE -eq 0) (
        "QSDK-R23D11 stage-two blob unavailable: $Path"
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
        Assert-R23D11StageTwoClosure ($process.ExitCode -eq 0) (
            "QSDK-R23D11 stage-two blob read failed: $Path"
        )
        $digest = [Security.Cryptography.SHA256]::HashData($memory.ToArray())
        return [Convert]::ToHexString($digest).ToLowerInvariant()
    }
    finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

Assert-R23D11StageTwoClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D11 stage-two closure repository identity changed"

$resolvedCommit = (git -C $repoRoot rev-parse "$stageTwoCommit^{commit}").Trim()
$resolvedParent = (git -C $repoRoot rev-parse "$stageTwoCommit^").Trim()
Assert-R23D11StageTwoClosure (
    $resolvedCommit -ceq $stageTwoCommit -and
    $resolvedParent -ceq $stageTwoParent
) "QSDK-R23D11 stage-two commit boundary changed"

$actualChangedPaths = @(
    git -C $repoRoot diff --name-only $stageTwoParent $stageTwoCommit
)
Assert-R23D11StageTwoClosure (
    (@($actualChangedPaths | Sort-Object) -join "`n") -ceq
        (@($expectedChangedPaths | Sort-Object) -join "`n")
) "QSDK-R23D11 stage-two changed-path set moved"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageTwoCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D11StageTwoClosure ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D11 stage-two tree already contained future route: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D11StageTwoClosure (
        (Get-R23D11StageTwoBlobHash $stageTwoCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D11 stage-two fixed blob changed: $($entry.Key)"
}

$contractSpec = (
    $stageTwoCommit +
    ":sdk/turning/r23d11_stage_two_evidence_contract_v1.json"
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

Assert-R23D11StageTwoClosure (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d11_stage_two_evidence_contract_v1" -and
    [string]$contract.status -ceq
        "stage_two_zero_world_trace_retention_diagnostics_and_production_evaluator_complete_no_physical_workers_or_authorization" -and
    [string]$contract.stage_one_boundary.commit -ceq $stageTwoParent -and
    [int]$contract.production_trace_contract.complete_trace_rows_per_cell -eq
        3892 -and
    [int]$contract.production_trace_contract.declared_trace_identity_count -eq
        11 -and
    [int]$contract.diagnostic_trace_contract.field_count -eq 6 -and
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
    $bindings.Count -eq 7
) "QSDK-R23D11 stage-two claim boundary changed"

foreach ($binding in $bindings) {
    Assert-R23D11StageTwoClosure (
        (Get-R23D11StageTwoBlobHash $stageTwoCommit $binding.path) -ceq
            $binding.hash
    ) "QSDK-R23D11 stage-two source binding changed: $($binding.path)"
}

Write-Host (
    "QSDK_R23D11_STAGE_TWO_CLOSURE_PASS commit=$stageTwoCommit " +
    "changed_paths=$($expectedChangedPaths.Count) fixed_blobs=$($fixedBlobs.Count) " +
    "source_bindings=$($bindings.Count) future_routes=0 workers=0 models=0 " +
    "worlds=0 physical_authority=False"
)
