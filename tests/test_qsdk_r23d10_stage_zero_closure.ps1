#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageZeroCommit = "6b39e1df77a403d474924d203ab706f8fa495687"
$stageZeroParent = "29f3204763b475a0803c107deb760d87b3120608"
$fixedBlobs = [ordered]@{
    "sdk/turning/r23d10_quiescent_taper_preregistration_v1.json" =
        "8a367a311b1133737037900bb0922f14a3c31d0e3f063fc39bb2fc554f263b3b"
    "sdk/turning/r23d10_quiescent_taper.py" =
        "0d9929ae30df8000d9685d4cdfea3b102c46a0d1586b14981ad6e5cbdb176eb0"
    "sdk/turning/test_r23d10_quiescent_taper.py" =
        "74ffcbd930821140bafc4889f56030432a5c8e86f6f56399412fb3acc810672b"
    "tests/test_qsdk_r23d10_declaration.ps1" =
        "7fe2ec9219cb9eb253d74c75304fe95609db9e7a541f2cc2c4b11435ef6bd5cd"
}
$futurePaths = @(
    "sdk/turning/r23d10_native_route_contract_v1.json",
    "sdk/turning/r23d10_evaluator_cli.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d10_quiescent_taper.py",
    "sdk/adapters/rapier/src/qsdk_r23d10_quiescent_taper.rs",
    "scripts/lab/gait/sdk_godot_jolt_quiescent_taper.gd",
    "sdk/run_qsdk_r23d10_supervisor.ps1"
)

function Assert-R23D10StageZero([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D10BlobHash([string]$Commit, [string]$Path) {
    $blob = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D10StageZero ($LASTEXITCODE -eq 0) (
        "QSDK-R23D10 stage-zero blob unavailable: $Path"
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
        [void]$start.ArgumentList.Add($blob)
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
        Assert-R23D10StageZero ($process.ExitCode -eq 0) (
            "QSDK-R23D10 stage-zero blob read failed: $Path"
        )
        return (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

Assert-R23D10StageZero (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D10 stage-zero repository identity changed"
Assert-R23D10StageZero (
    (git -C $repoRoot rev-parse "$stageZeroCommit^{commit}").Trim() -ceq
        $stageZeroCommit -and
    (git -C $repoRoot rev-parse "$stageZeroCommit^").Trim() -ceq $stageZeroParent
) "QSDK-R23D10 stage-zero commit boundary changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageZeroCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D10StageZero ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D10 stage-zero tree already contained future path: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D10StageZero (
        (Get-R23D10BlobHash $stageZeroCommit $entry.Key) -ceq [string]$entry.Value
    ) "QSDK-R23D10 stage-zero blob changed: $($entry.Key)"
}

$declaration = (
    git -C $repoRoot show (
        "$stageZeroCommit`:sdk/turning/r23d10_quiescent_taper_preregistration_v1.json"
    ) | Out-String
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D10StageZero (
    [string]$declaration.status -ceq
        "prospectively_frozen_stage_zero_zero_world_only" -and
    [int]$declaration.stage_zero_authority.native_engine_route_count -eq 0 -and
    [int]$declaration.stage_zero_authority.physical_worker_count -eq 0 -and
    [int]$declaration.stage_zero_authority.model_construction_count -eq 0 -and
    [int]$declaration.stage_zero_authority.world_build_count -eq 0 -and
    -not [bool]$declaration.stage_zero_authority.physical_execution_authorized -and
    -not [bool]$declaration.claim_boundary.command_conditioned_turning -and
    -not [bool]$declaration.claim_boundary.cross_engine_equivalence
) "QSDK-R23D10 stage-zero authority changed"

Write-Host (
    "QSDK_R23D10_STAGE_ZERO_CLOSURE_PASS commit=$stageZeroCommit " +
    "blobs=$($fixedBlobs.Count) future_routes=0 workers=0 models=0 worlds=0 " +
    "physical_authority=False"
)
