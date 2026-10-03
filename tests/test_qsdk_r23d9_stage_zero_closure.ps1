#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageZeroCommit = "53df1481aa03e1d638a46222c51f0d40fdb457ed"
$stageZeroParent = "5869318963a07c6572d1fa3ee2faa9c751e78abc"
$paths = [ordered]@{
    "sdk/turning/r23d9_support_handoff_preregistration_v1.json" =
        "17f37bf5434d019dd32a7dd4e4657fa23b8016b7fdec977f1839044e17195696"
    "sdk/turning/r23d9_support_handoff.py" =
        "0c6b1e03bc76d610314657ee9847025a7a554e2617e8bc523c730b7161f3d9ec"
    "sdk/turning/test_r23d9_support_handoff.py" =
        "c0a87f89306d590694375df76495b872fa5247eb709355f9b1fa0af310e0daab"
    "tests/test_qsdk_r23d9_declaration.ps1" =
        "e41f9423fab1833ea70d75f94953afe185d15e230e79266dcc402ccbd7e4eb45"
}
$futureWorkerPaths = @(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d9_support_handoff.py",
    "sdk/adapters/rapier/src/bin/qsdk_r23d9_support_handoff.rs",
    "tests/test_sdk_qsdk_r23d9_support_handoff_godot_jolt_worker.gd",
    "sdk/run_qsdk_r23d9_supervisor.ps1"
)

function Assert-R23D9StageZero([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

Assert-R23D9StageZero (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D9 stage-zero repository identity changed"

$resolvedCommit = (git -C $repoRoot rev-parse "$stageZeroCommit^{commit}").Trim()
$resolvedParent = (git -C $repoRoot rev-parse "$stageZeroCommit^").Trim()
Assert-R23D9StageZero (
    $resolvedCommit -ceq $stageZeroCommit -and
    $resolvedParent -ceq $stageZeroParent
) "QSDK-R23D9 stage-zero commit boundary changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageZeroCommit)
foreach ($futurePath in $futureWorkerPaths) {
    Assert-R23D9StageZero ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D9 stage-zero tree already contained future worker: $futurePath"
    )
}

foreach ($entry in $paths.GetEnumerator()) {
    $objectSpec = $stageZeroCommit + ":" + $entry.Key
    $blobOid = (git -C $repoRoot rev-parse $objectSpec).Trim()
    Assert-R23D9StageZero ($LASTEXITCODE -eq 0) (
        "QSDK-R23D9 stage-zero blob unavailable: $($entry.Key)"
    )
    $temporary = [IO.Path]::GetTempFileName()
    try {
        $process = [Diagnostics.ProcessStartInfo]::new()
        $process.FileName = "git"
        $process.WorkingDirectory = $repoRoot
        $process.UseShellExecute = $false
        $process.RedirectStandardOutput = $true
        [void]$process.ArgumentList.Add("cat-file")
        [void]$process.ArgumentList.Add("blob")
        [void]$process.ArgumentList.Add($blobOid)
        $running = [Diagnostics.Process]::Start($process)
        $stream = [IO.File]::Open(
            $temporary,
            [IO.FileMode]::Create,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None
        )
        try {
            $running.StandardOutput.BaseStream.CopyTo($stream)
        } finally {
            $stream.Dispose()
        }
        $running.WaitForExit()
        Assert-R23D9StageZero ($running.ExitCode -eq 0) (
            "QSDK-R23D9 stage-zero blob read failed: $($entry.Key)"
        )
        $rawHash = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert-R23D9StageZero ($rawHash -ceq [string]$entry.Value) (
            "QSDK-R23D9 stage-zero blob hash changed: $($entry.Key)"
        )
    } finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

$declarationSpec = (
    $stageZeroCommit +
    ":sdk/turning/r23d9_support_handoff_preregistration_v1.json"
)
$declarationText = git -C $repoRoot show $declarationSpec | Out-String
$declaration = $declarationText | ConvertFrom-Json -AsHashtable -Depth 100
$preflight = $declaration.production_shaped_zero_world_preflight_contract
Assert-R23D9StageZero (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d9_support_handoff_preregistration_v1" -and
    [string]$declaration.status -ceq
        "stage_zero_preregistered_support_confirmed_irreversible_handoff_successor_no_workers_no_physical_authorization" -and
    [int]$preflight.physical_process_launch_count -eq 0 -and
    [int]$preflight.model_construction_count -eq 0 -and
    [int]$preflight.world_build_count -eq 0 -and
    -not [bool]$declaration.authorization.physical_execution_authorized -and
    [bool]$declaration.authorization.worker_implementation_authorized -and
    -not [bool]$declaration.claim_boundary.command_conditioned_turning -and
    -not [bool]$declaration.claim_boundary.physical_acceptance_authority
) "QSDK-R23D9 stage-zero declaration claim boundary changed"

Write-Host (
    "QSDK_R23D9_STAGE_ZERO_CLOSURE_PASS commit=$stageZeroCommit " +
    "blobs=$($paths.Count) future_workers=0 worlds=0 physical_authority=False"
)
