#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageTwoCommit = "b45432d7f5db4968e2b0aaac331d9e8e63e98238"
$stageTwoParent = "0c91c212ca982963952e53ba4619922232d38448"
$stageTwoTree = "8b8e4ebd385c68f717d6d3f338b5d85aee3db89a"
$fixedBlobs = [ordered]@{
    "tests/test_qsdk_r23d14_stage_one_closure.ps1" =
        "5f301fe0d8737f392ebcb481628d2d681c236b9cdc78eb245101a24d9a555563"
    "sdk/publish_qsdk_r23d14_trace.ps1" =
        "b463b74129b4fe2c81ab312aca3028858142df412523e2aae223144b54cea156"
    "sdk/run_qsdk_r23d14_stage_two_gate.ps1" =
        "6d0ea32a4dd0c91c23af7cb01d94bd711eaac6ebe83160d66007887c5a98879a"
    "sdk/turning/r23d14_physical_evaluator.py" =
        "2cda4705799c3604781e800593a174dcd8bf75aefb3cb4e9e4e3a1cbb33639d0"
    "sdk/turning/r23d14_physical_trace.py" =
        "75664700dca8dd6216e2be231050bab01378ea1e4c7deea211f121bf4e81679a"
    "sdk/turning/r23d14_stage_two_evidence_contract_v1.json" =
        "9e4dac98bbd139c5cedce01ef15907315cc14eac35a844ea0b7dc14cc8f3b5a4"
    "sdk/turning/test_r23d14_physical_evaluator.py" =
        "b46a991150121c133bfb80688f216ddaeacecf0c2a82a097dab3fc76bf6e0b26"
    "sdk/turning/test_r23d14_physical_trace.py" =
        "c8b653a15284cec7c62afe67fbeabd9c8b53d52325ef9383ea74b417b6b00edd"
    "tests/test_qsdk_r23d14_stage_two_evidence.ps1" =
        "496f29dd31c82f5bbca9027e4e2377065aeb7ba20cc45fff3ee1bbcc519658cb"
}
$futurePaths = @(
    "sdk/turning/r23d14_physical_implementation_contract_v1.json",
    "sdk/turning/r23d14_dependency_closure.ps1",
    "sdk/turning/r23d14_terminal_marker_classifier.ps1",
    "sdk/run_qsdk_r23d14_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d14_supervisor.ps1",
    "sdk/run_qsdk_r23d14_zero_world_gate.ps1",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d14_physical.py",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d14_physical.rs",
    "tests/test_sdk_qsdk_r23d14_godot_jolt_physical_worker.gd"
)

function Assert-R23D14StageTwoClosure(
    [bool]$Condition,
    [string]$Message
) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D14StageTwoBlobHash([string]$Commit, [string]$Path) {
    $blobOid = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D14StageTwoClosure ($LASTEXITCODE -eq 0) (
        "QSDK-R23D14 stage-two blob unavailable: $Path"
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
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($process.StandardOutput.BaseStream)
        $process.WaitForExit()
        Assert-R23D14StageTwoClosure ($process.ExitCode -eq 0) (
            "QSDK-R23D14 stage-two blob read failed: $Path"
        )
        return [Convert]::ToHexString($hash).ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
        $process.Dispose()
    }
}

Assert-R23D14StageTwoClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D14 stage-two repository identity changed"

$resolvedCommit = (git -C $repoRoot rev-parse "$stageTwoCommit^{commit}").Trim()
$resolvedParent = (git -C $repoRoot rev-parse "$stageTwoCommit^").Trim()
$resolvedTree = (git -C $repoRoot rev-parse "$stageTwoCommit^{tree}").Trim()
$originMain = (git -C $repoRoot rev-parse origin/main).Trim()
$liveMain = @(
    git -C $repoRoot ls-remote origin refs/heads/main
)[0].Split("`t")[0].Trim()
git -C $repoRoot merge-base --is-ancestor $stageTwoCommit $originMain
$publishedAncestor = $LASTEXITCODE -eq 0
Assert-R23D14StageTwoClosure (
    $resolvedCommit -ceq $stageTwoCommit -and
    $resolvedParent -ceq $stageTwoParent -and
    $resolvedTree -ceq $stageTwoTree -and
    $publishedAncestor -and
    $originMain -ceq $liveMain
) "QSDK-R23D14 stage-two publication boundary changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageTwoCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D14StageTwoClosure ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D14 stage-two tree already contained future route: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D14StageTwoClosure (
        (Get-R23D14StageTwoBlobHash $stageTwoCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D14 stage-two fixed blob changed: $($entry.Key)"
}

$contractSpec = (
    $stageTwoCommit + ":sdk/turning/r23d14_stage_two_evidence_contract_v1.json"
)
$contract = (git -C $repoRoot show $contractSpec | Out-String) |
    ConvertFrom-Json -AsHashtable -Depth 100
$bindings = [Collections.Generic.List[object]]::new()
$bindings.Add([pscustomobject]@{
    path = [string]$contract.stage_one_boundary.historical_closure_audit_path
    hash = [string]$contract.stage_one_boundary.historical_closure_audit_raw_sha256
})
foreach ($pair in @(
    @("preregistration_path", "preregistration_raw_sha256"),
    @("temporal_oracle_path", "temporal_oracle_raw_sha256"),
    @("residual_pose_authority_path", "residual_pose_authority_raw_sha256"),
    @("diagnostic_semantics_path", "diagnostic_semantics_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$contract.temporal_and_inherited_semantics[$pair[0]]
        hash = [string]$contract.temporal_and_inherited_semantics[$pair[1]]
    })
}
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
            hash = [string]$section[$pair[1]]
        })
    }
}
$bindings.Add([pscustomobject]@{
    path = [string]$contract.production_trace_contract.inherited_core_path
    hash = [string]$contract.production_trace_contract.inherited_core_raw_sha256
})
$bindings.Add([pscustomobject]@{
    path = [string]$contract.production_evaluator_contract.inherited_cell_evaluator_core_path
    hash = [string]$contract.production_evaluator_contract.inherited_cell_evaluator_core_raw_sha256
})
foreach ($pair in @(
    @("publisher_path", "publisher_raw_sha256"),
    @("store_path", "store_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$contract.content_addressed_retention[$pair[0]]
        hash = [string]$contract.content_addressed_retention[$pair[1]]
    })
}
Assert-R23D14StageTwoClosure ($bindings.Count -eq 13) (
    "QSDK-R23D14 stage-two source binding count changed"
)
foreach ($binding in $bindings) {
    Assert-R23D14StageTwoClosure (
        (Get-R23D14StageTwoBlobHash $stageTwoCommit $binding.path) -ceq
            ([string]$binding.hash).Substring(7)
    ) "QSDK-R23D14 stage-two source binding changed: $($binding.path)"
}

Assert-R23D14StageTwoClosure (
    [string]$contract.status -ceq
        "stage_two_zero_world_direct_matrix_trace_retention_and_production_evaluator_complete_no_physical_workers_or_authorization" -and
    [int]$contract.production_trace_contract.complete_trace_rows_per_cell -eq 3952 -and
    [int]$contract.production_trace_contract.declared_trace_identity_count -eq 9 -and
    [int]$contract.production_evaluator_contract.actual_evaluator_cli_subprocess_command_count -eq 1 -and
    [bool]$contract.production_evaluator_contract.forbidden_stage_a_route -and
    [int]$contract.next_implementation_boundary.production_physical_worker_count -eq 0 -and
    -not [bool]$contract.next_implementation_boundary.serialized_direct_matrix_supervisor_implemented -and
    -not [bool]$contract.next_implementation_boundary.physical_execution_authorized -and
    -not [bool]$contract.claim_boundary.command_conditioned_turning -and
    -not [bool]$contract.claim_boundary.cross_engine_equivalence -and
    -not [bool]$contract.claim_boundary.physical_acceptance_authority
) "QSDK-R23D14 stage-two authority changed"

Write-Host (
    "QSDK_R23D14_STAGE_TWO_CLOSURE_PASS commit=$stageTwoCommit " +
    "tree=$stageTwoTree fixed_blobs=$($fixedBlobs.Count) " +
    "source_bindings=$($bindings.Count) traces=9 rows_per_trace=3952 " +
    "stage_a_routes=0 workers=0 supervisors=0 models=0 worlds=0 " +
    "physical_authority=False turning=False equivalence=False"
)

