#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageZeroCommit = "ad34a258c101361a67f50becb2e3d3ed02c3e3b8"
$stageZeroParent = "01b62a2ffe4c1d95cccb4af80d7617d9fc54ae25"
$expectedTree = "b4379a5604138ba7400fe55247cd620a51453386"
$fixedBlobs = [ordered]@{
    "sdk/run_qsdk_r23d14_stage_zero_gate.ps1" =
        "0f02ca0db5f73b311d7d43ae8a61f0d369ff1045654699e4b1fe87f44eb40c3a"
    "sdk/turning/r23d14_tight_gated_horizon.py" =
        "5964ca4a481b8649007c10e4eda61b7f74fc11b772211b12fa89bb18a54a882e"
    "sdk/turning/r23d14_tight_gated_horizon_preregistration_v1.json" =
        "ac92e92792df60d47080a1b7592fd289d3bcda9a4515da6eb3334407c1e452e8"
    "sdk/turning/test_r23d14_tight_gated_horizon.py" =
        "ad94f941bcae62e62aad1c231523e3b9bcb72d01bdd94c69979dd25fd88dd4f0"
    "tests/test_qsdk_r23d14_declaration.ps1" =
        "73af14eb7cc27fbdb21754f93396332a943214673cd0495d884a1de737094ea5"
}
$futurePaths = @(
    "sdk/turning/r23d14_native_route_contract_v1.json",
    "sdk/run_qsdk_r23d14_stage_one_gate.ps1",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d14_tight_gated_horizon.py",
    "sdk/adapters/rapier/src/qsdk_r23d14_tight_gated_horizon.rs",
    "scripts/lab/gait/sdk_godot_jolt_r23d14_tight_gated_horizon.gd",
    "sdk/turning/r23d14_physical_trace.py",
    "sdk/turning/r23d14_physical_evaluator.py",
    "sdk/turning/r23d14_physical_implementation_contract_v1.json",
    "sdk/run_qsdk_r23d14_supervisor.ps1",
    "sdk/turning/r23d14_physical_closure_v1.json"
)

function Assert-R23D14StageZero([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D14BlobHash([string]$Commit, [string]$Path) {
    $blob = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D14StageZero ($LASTEXITCODE -eq 0) (
        "QSDK-R23D14 stage-zero blob unavailable: $Path"
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
        Assert-R23D14StageZero ($process.ExitCode -eq 0) (
            "QSDK-R23D14 stage-zero blob read failed: $Path"
        )
        return (
            Get-FileHash -LiteralPath $temporary -Algorithm SHA256
        ).Hash.ToLowerInvariant()
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

Assert-R23D14StageZero (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D14 stage-zero repository identity changed"
Assert-R23D14StageZero (
    (git -C $repoRoot rev-parse "$stageZeroCommit^{commit}").Trim() -ceq
        $stageZeroCommit -and
    (git -C $repoRoot rev-parse "$stageZeroCommit^{tree}").Trim() -ceq
        $expectedTree -and
    (git -C $repoRoot rev-parse "$stageZeroCommit^").Trim() -ceq
        $stageZeroParent
) "QSDK-R23D14 stage-zero commit boundary changed"
$originMain = (git -C $repoRoot rev-parse origin/main).Trim()
$liveMain = ((git -C $repoRoot ls-remote origin refs/heads/main) -split "\s+")[0]
& git -C $repoRoot merge-base --is-ancestor $stageZeroCommit $originMain
$originContains = $LASTEXITCODE -eq 0
& git -C $repoRoot merge-base --is-ancestor $stageZeroCommit $liveMain
$liveContains = $LASTEXITCODE -eq 0
Assert-R23D14StageZero ($originContains -and $liveContains) (
    "QSDK-R23D14 stage-zero commit is not published on origin/live main"
)

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageZeroCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D14StageZero ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D14 stage-zero tree already contained future path: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D14StageZero (
        (Get-R23D14BlobHash $stageZeroCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D14 stage-zero blob changed: $($entry.Key)"
}

$requiredRules = @(
    "sdk/turning/terminal_tight_first_* text eol=lf",
    "sdk/run_qsdk_turning_tight_first_development.ps1 text eol=lf",
    "tests/test_terminal_tight_first_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_turning_tight_first_*.py text eol=lf",
    "sdk/adapters/mujoco/test_qsdk_turning_tight_first_*.py text eol=lf",
    "sdk/turning/r23d14_* text eol=lf",
    "sdk/turning/test_r23d14_* text eol=lf",
    "sdk/run_qsdk_r23d14_*.ps1 text eol=lf",
    "sdk/publish_qsdk_r23d14_*.ps1 text eol=lf",
    "tests/test_qsdk_r23d14_*.ps1 text eol=lf",
    "tests/test_sdk_qsdk_r23d14_*.gd text eol=lf",
    "scripts/lab/gait/sdk_godot_jolt_r23d14_*.gd text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d14_*.rs text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d14_*.rs text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d14_*.rs text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d14_*.py text eol=lf",
    "sdk/adapters/mujoco/test_qsdk_r23d14_*.py text eol=lf"
)
$attributes = Get-Content -Raw -LiteralPath (Join-Path $repoRoot ".gitattributes")
foreach ($rule in $requiredRules) {
    Assert-R23D14StageZero $attributes.Contains($rule) (
        "QSDK-R23D14 source-family checkout rule missing: $rule"
    )
}
foreach ($path in $fixedBlobs.Keys) {
    $attributeOutput = @(
        git -C $repoRoot check-attr eol -- $path
    ) -join "`n"
    Assert-R23D14StageZero ($attributeOutput.EndsWith("eol: lf")) (
        "QSDK-R23D14 source checkout is not LF-pinned: $path"
    )
}

$declaration = (
    git -C $repoRoot show (
        "$stageZeroCommit`:sdk/turning/" +
        "r23d14_tight_gated_horizon_preregistration_v1.json"
    ) | Out-String
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D14StageZero (
    [string]$declaration.status -ceq
        "prospectively_frozen_stage_zero_zero_world_only" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D14" -and
    [bool]$declaration.scientifically_distinct_successor.new_campaign_identity -and
    [bool]$declaration.scientifically_distinct_successor.fresh_worlds_required -and
    [bool]$declaration.scientifically_distinct_successor.tight_pose_gates_taper_entry_and_continuation -and
    [int]$declaration.scientifically_distinct_successor.maximum_active_step_count_changed_to -eq 600 -and
    [int]$declaration.terminal_policy_contract.terminal_step_count -eq 960 -and
    [int]$declaration.pure_zero_world_oracle.declared_canary_count -eq 12 -and
    [int]$declaration.pure_zero_world_oracle.declared_mutation_control_count -eq 14 -and
    [int]$declaration.finite_three_engine_confirmation.declared_cell_count -eq 9 -and
    [int]$declaration.stage_zero_authority.native_engine_route_count -eq 0 -and
    [int]$declaration.stage_zero_authority.physical_worker_count -eq 0 -and
    [int]$declaration.stage_zero_authority.model_construction_count -eq 0 -and
    [int]$declaration.stage_zero_authority.world_build_count -eq 0 -and
    -not [bool]$declaration.stage_zero_authority.physical_execution_authorized -and
    -not [bool]$declaration.claim_boundary.command_conditioned_turning -and
    -not [bool]$declaration.claim_boundary.cross_engine_equivalence -and
    -not [bool]$declaration.claim_boundary.release_authorized
) "QSDK-R23D14 stage-zero authority changed"

Write-Host (
    "QSDK_R23D14_STAGE_ZERO_CLOSURE_PASS commit=$stageZeroCommit " +
    "tree=$expectedTree blobs=$($fixedBlobs.Count) rules=$($requiredRules.Count) " +
    "canaries=12 mutations=14 confirmation_cells=9 future_routes=0 " +
    "workers=0 models=0 worlds=0 turning=False equivalence=False " +
    "physical_authority=False"
)
