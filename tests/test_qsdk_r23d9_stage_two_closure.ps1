#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageTwoCommit = "d2e36a1fac783fad3ca6ac38ee835d940f1845b3"
$stageTwoParent = "ddb8f962a93daa65f812204e56c2e1bdd78233d7"
$fixedBlobs = [ordered]@{
    "sdk/turning/r23d9_support_handoff.py" =
        "9f326d40a250ceccd2ffbd143364d7e721576c9da3ad09b97b4b9b7a2aa86935"
    "sdk/turning/r23d9_physical_evaluator.py" =
        "c46462f7e9f52dd0d30b76f786b53c6645988a4770f2e2f7d7689ef195cd0bc5"
    "sdk/publish_qsdk_r23d9_trace.ps1" =
        "a77f245456bb817c0cc8528d1c6aa5d8c434978006dd4cf1ecb5f62b416e3016"
    "sdk/turning/r23d9_dependency_closure.ps1" =
        "4cc169e3f6d7900ddb133292a48ee6e99a434429850cf9605d5517f2c3db7c04"
    "sdk/turning/r23d9_terminal_marker_classifier.ps1" =
        "0be59af4751227b1938c588acba05e891b0031c8c6eb25839a69b0aa306ecfff"
    "sdk/turning/test_r23d9_physical_trace.py" =
        "600617857d549a7d2c31e63ab5c50a1b8100cacce273b0290607c6f53fe3821a"
    "sdk/turning/test_r23d9_physical_evaluator.py" =
        "77e53ebf17eabb2f259e45ce9c8618185eb56078fc7996c45db4060cbfd75388"
    "tests/test_qsdk_r23d9_dependency_and_marker_contract.ps1" =
        "d90d0c1abae02be7338e0a018b2dde092e84a3eec2445450642d5836c0e1d252"
    "tests/test_qsdk_r23d9_stage_two_evidence.ps1" =
        "2c5d5ef24b1b5f34d6ed643c480bbc2989475cabb3c2f8846e931810e61b8486"
    "tests/test_qsdk_r23d9_stage_one_closure.ps1" =
        "b460a67e90af1a162d1377611f0f386e24f9e94c047af01778dc7811d1f777e0"
    "sdk/release/quadruped_release_contract.json" =
        "f2d07821d2e7fce0c86fb16e1e1fff34285dfdbb066210fd07e52439752c5f05"
    "sdk/release/quadruped_support_matrix.json" =
        "cccea4e1958eaeac01a03e221dde7331baf371d542867900b708c76ac3d939ae"
    "sdk/workbench/experiment_catalog.json" =
        "921cd50d5a0fe50c821e130eba842f6457c839077756f3b1a7f30427adc7b3e8"
    "sdk/closure_evidence_mode_inventory.json" =
        "d21c8a4d41f46f7751992962985d4da2bec7cbec7a45e9942ede7446c04c7ef1"
    "sdk/closure_evidence_provenance_contract.json" =
        "0b35a2913af7cd6492062d6fa1e7aa3b81ca6d5d6d0bb9d47249eb5a72a22e57"
    "tests/test_closure_evidence_provenance_contract.ps1" =
        "9aedc6ae4d70b1190d1bf6103dbbb746a3325033196791908823fff360e88a20"
    "tests/test_locomotion_experiment_workbench.ps1" =
        "dc5c21a5889253bff1a6491edda2ffe9447f295c4796cc3f627dd68a47a30237"
}
$futurePaths = @(
    "sdk/turning/r23d9_physical_implementation_contract_v1.json",
    "sdk/run_qsdk_r23d9_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d9_supervisor.ps1",
    "sdk/run_qsdk_r23d9_zero_world_gate.ps1"
)

function Assert-R23D9StageTwo([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D9StageTwoBlobHash([string]$Commit, [string]$Path) {
    $blobOid = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D9StageTwo ($LASTEXITCODE -eq 0) (
        "QSDK-R23D9 stage-two blob unavailable: $Path"
    )
    $temporary = [IO.Path]::GetTempFileName()
    try {
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = "git"
        $start.WorkingDirectory = $repoRoot
        $start.UseShellExecute = $false
        $start.RedirectStandardOutput = $true
        [void]$start.ArgumentList.Add("cat-file")
        [void]$start.ArgumentList.Add("blob")
        [void]$start.ArgumentList.Add($blobOid)
        $process = [Diagnostics.Process]::Start($start)
        $stream = [IO.File]::Open(
            $temporary,
            [IO.FileMode]::Create,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None
        )
        try { $process.StandardOutput.BaseStream.CopyTo($stream) }
        finally { $stream.Dispose() }
        $process.WaitForExit()
        Assert-R23D9StageTwo ($process.ExitCode -eq 0) (
            "QSDK-R23D9 stage-two blob read failed: $Path"
        )
        return (
            Get-FileHash -LiteralPath $temporary -Algorithm SHA256
        ).Hash.ToLowerInvariant()
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

function Get-R23D9StageTwoJson([string]$Path) {
    $spec = $stageTwoCommit + ":" + $Path
    return (git -C $repoRoot show $spec | Out-String) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

Assert-R23D9StageTwo (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D9 stage-two repository identity changed"

$resolvedCommit = (git -C $repoRoot rev-parse "$stageTwoCommit^{commit}").Trim()
$resolvedParent = (git -C $repoRoot rev-parse "$stageTwoCommit^").Trim()
Assert-R23D9StageTwo (
    $resolvedCommit -ceq $stageTwoCommit -and
    $resolvedParent -ceq $stageTwoParent
) "QSDK-R23D9 stage-two commit boundary changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageTwoCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D9StageTwo ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D9 stage-two tree already contained future route: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D9StageTwo (
        (Get-R23D9StageTwoBlobHash $stageTwoCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D9 stage-two fixed blob changed: $($entry.Key)"
}

$release = Get-R23D9StageTwoJson "sdk/release/quadruped_release_contract.json"
$turningGate = @($release.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
Assert-R23D9StageTwo ($turningGate.Count -eq 1) (
    "QSDK-R23D9 stage-two release gate identity changed"
)
$successor = $turningGate[0].proof.prospective_successor
Assert-R23D9StageTwo (
    [string]$successor.gate_id -ceq "QSDK-R23D9" -and
    [string]$successor.status -ceq
        "stage_two_zero_world_trace_evaluator_retention_and_marker_contract_physical_workers_and_supervisor_not_implemented_no_physical_authorization" -and
    [int]$successor.complete_trace_rows_per_cell -eq 3772 -and
    [int]$successor.declared_trace_identity_count -eq 11 -and
    [int]$successor.production_trace_test_count -eq 5 -and
    [int]$successor.production_evaluator_test_count -eq 8 -and
    [int]$successor.terminal_marker_case_count -eq 15 -and
    [bool]$successor.trace_retained_before_terminal_entry_required -and
    -not [bool]$successor.terminal_marker_interpretation_before_process_retention_permitted -and
    -not [bool]$successor.supervisor_implemented -and
    [int]$successor.physical_worker_implementation_count -eq 0 -and
    [int]$successor.physical_process_launch_count -eq 0 -and
    [int]$successor.model_construction_count -eq 0 -and
    [int]$successor.world_attempt_count -eq 0 -and
    [int]$successor.world_build_count -eq 0 -and
    -not [bool]$successor.physical_execution_authorized -and
    -not [bool]$successor.command_conditioned_turning -and
    -not [bool]$successor.cross_engine_equivalence -and
    -not [bool]$successor.q_sdk_r23_satisfied
) "QSDK-R23D9 stage-two claim boundary changed"

$catalog = Get-R23D9StageTwoJson "sdk/workbench/experiment_catalog.json"
$stageTwoRun = @($catalog.runs | Where-Object {
    [string]$_.id -ceq "qsdk_r23d9_stage_two_evidence"
})
Assert-R23D9StageTwo (
    @($catalog.runs).Count -eq 37 -and
    $stageTwoRun.Count -eq 1 -and
    [string]$stageTwoRun[0].world_policy -ceq "zero_world_only" -and
    [string]$stageTwoRun[0].risk -ceq "safe" -and
    [string]$stageTwoRun[0].runner_path -ceq
        "tests/test_qsdk_r23d9_stage_two_evidence.ps1"
) "QSDK-R23D9 stage-two workbench boundary changed"

Write-Host (
    "QSDK_R23D9_STAGE_TWO_CLOSURE_PASS commit=$stageTwoCommit " +
    "fixed_blobs=$($fixedBlobs.Count) trace_tests=5 evaluator_tests=8 " +
    "dependencies=4 marker_cases=15 workers=0 supervisors=0 models=0 " +
    "worlds=0 physical_authority=False"
)
