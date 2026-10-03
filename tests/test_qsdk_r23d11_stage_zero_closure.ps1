#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageZeroCommit = "40ebd67d3a1936be23a9ee6d1a6761e931dfb5d8"
$stageZeroParent = "71da97b50731d995bbf79c945736a6d5129b2404"
$fixedBlobs = [ordered]@{
    ".gitattributes" =
        "f76c52e79daf7f13fc45c265604259238ef2acce0e3a69a6c5f31132cb88f1fc"
    "sdk/turning/r23d11_stability_assisted_taper_preregistration_v1.json" =
        "4eae08c30fdd6af9ebdc7a43da4b277a05c404ce49bdd239ce4d895dd99d23e7"
    "sdk/turning/r23d11_stability_assisted_taper.py" =
        "2580f8a4dc489de387c93ed427c70e06541058d7b30ccae592fac7e511f47678"
    "sdk/turning/test_r23d11_stability_assisted_taper.py" =
        "5c93c6a5454c090813c1b03fcea68411c0c94202e5762655f388f44eec450ae6"
    "tests/test_qsdk_r23d11_declaration.ps1" =
        "b4e0e02376d35bf2e581ffe5bd65218b159dcc7a581cf42a4e03099544289ad6"
}
$futurePaths = @(
    "sdk/turning/r23d11_native_route_contract_v1.json",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d11_stability_assisted_taper.py",
    "sdk/adapters/rapier/src/qsdk_r23d11_stability_assisted_taper.rs",
    "scripts/lab/gait/sdk_godot_jolt_stability_assisted_taper.gd",
    "sdk/run_qsdk_r23d11_supervisor.ps1"
)

function Assert-R23D11StageZero([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D11BlobHash([string]$Commit, [string]$Path) {
    $blob = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D11StageZero ($LASTEXITCODE -eq 0) (
        "QSDK-R23D11 stage-zero blob unavailable: $Path"
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
        Assert-R23D11StageZero ($process.ExitCode -eq 0) (
            "QSDK-R23D11 stage-zero blob read failed: $Path"
        )
        return (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

Assert-R23D11StageZero (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D11 stage-zero repository identity changed"
Assert-R23D11StageZero (
    (git -C $repoRoot rev-parse "$stageZeroCommit^{commit}").Trim() -ceq
        $stageZeroCommit -and
    (git -C $repoRoot rev-parse "$stageZeroCommit^").Trim() -ceq $stageZeroParent
) "QSDK-R23D11 stage-zero commit boundary changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageZeroCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D11StageZero ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D11 stage-zero tree already contained future path: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D11StageZero (
        (Get-R23D11BlobHash $stageZeroCommit $entry.Key) -ceq [string]$entry.Value
    ) "QSDK-R23D11 stage-zero blob changed: $($entry.Key)"
}

$declaration = (
    git -C $repoRoot show (
        "$stageZeroCommit`:sdk/turning/r23d11_stability_assisted_taper_preregistration_v1.json"
    ) | Out-String
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D11StageZero (
    [string]$declaration.status -ceq
        "prospectively_frozen_stage_zero_zero_world_only" -and
    [int]$declaration.stage_zero_authority.native_engine_route_count -eq 0 -and
    [int]$declaration.stage_zero_authority.physical_worker_count -eq 0 -and
    [int]$declaration.stage_zero_authority.model_construction_count -eq 0 -and
    [int]$declaration.stage_zero_authority.world_build_count -eq 0 -and
    -not [bool]$declaration.stage_zero_authority.physical_execution_authorized -and
    -not [bool]$declaration.claim_boundary.command_conditioned_turning -and
    -not [bool]$declaration.claim_boundary.cross_engine_equivalence
) "QSDK-R23D11 stage-zero authority changed"

Write-Host (
    "QSDK_R23D11_STAGE_ZERO_CLOSURE_PASS commit=$stageZeroCommit " +
    "blobs=$($fixedBlobs.Count) future_routes=0 workers=0 models=0 worlds=0 " +
    "physical_authority=False"
)
