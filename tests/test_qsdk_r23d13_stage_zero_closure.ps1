#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageZeroCommit = "7ba47f7df2fe0965235f2ecc0e4a522278bd6b92"
$stageZeroParent = "a0872c6da7758528325320ed9596c498c30be864"
$attributeParent = "e93ac8a42407926ff55fcde876402e68bfdf8038"
$expectedTree = "5ef0d46be69884738a2995e4981c450c74891c3b"
$fixedBlobs = [ordered]@{
    ".gitattributes" =
        "7c2d28406c8c2c46a8533c0aca19391e3a9652b754d7e19cbdbdfc2f1411e571"
    "sdk/run_qsdk_r23d13_stage_zero_gate.ps1" =
        "dd8eceeb52cda1ff2c37f3f0864c9e4b2eafc0fd3d47769043b86184f707a972"
    "sdk/turning/r23d13_residual_pose_authority.py" =
        "88896fa6582ca90f828b7d090bfc040ca04d9554bd0cdfcc01b469a7e409433d"
    "sdk/turning/r23d13_residual_pose_authority_preregistration_v1.json" =
        "aa0c82848550c86251d8841dc8daefed9b2b6111cb4a551efbbadc9fd3bee7a8"
    "sdk/turning/test_r23d13_residual_pose_authority.py" =
        "d642221286157042f0fc75da677453e2c3bfa0b8b9780c5c79578adecc1eb0a2"
    "tests/test_qsdk_r23d13_declaration.ps1" =
        "7a8d64da4515a204c893bc6658ede9b28020af38d4459da503891c8151cc8267"
}
$futurePaths = @(
    "sdk/turning/r23d13_native_route_contract_v1.json",
    "sdk/run_qsdk_r23d13_stage_one_gate.ps1",
    "tests/test_qsdk_r23d13_native_routes.ps1",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d13_residual_pose_authority.py",
    "sdk/adapters/rapier/src/qsdk_r23d13_residual_pose_authority.rs",
    "scripts/lab/gait/sdk_godot_jolt_r23d13_residual_pose_authority.gd",
    "sdk/turning/r23d13_physical_trace.py",
    "sdk/turning/r23d13_physical_evaluator.py",
    "sdk/turning/r23d13_physical_implementation_contract_v1.json",
    "sdk/run_qsdk_r23d13_supervisor.ps1",
    "sdk/turning/r23d13_physical_closure_v1.json"
)

function Assert-R23D13StageZero([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D13BlobHash([string]$Commit, [string]$Path) {
    $blob = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D13StageZero ($LASTEXITCODE -eq 0) (
        "QSDK-R23D13 stage-zero blob unavailable: $Path"
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
        Assert-R23D13StageZero ($process.ExitCode -eq 0) (
            "QSDK-R23D13 stage-zero blob read failed: $Path"
        )
        return (
            Get-FileHash -LiteralPath $temporary -Algorithm SHA256
        ).Hash.ToLowerInvariant()
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

Assert-R23D13StageZero (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D13 stage-zero repository identity changed"
Assert-R23D13StageZero (
    (git -C $repoRoot rev-parse "$stageZeroCommit^{commit}").Trim() -ceq
        $stageZeroCommit -and
    (git -C $repoRoot rev-parse "$stageZeroCommit^{tree}").Trim() -ceq
        $expectedTree -and
    (git -C $repoRoot rev-parse "$stageZeroCommit^").Trim() -ceq
        $stageZeroParent -and
    (git -C $repoRoot rev-parse "$stageZeroParent^").Trim() -ceq
        $attributeParent
) "QSDK-R23D13 stage-zero commit boundary changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageZeroCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D13StageZero ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D13 stage-zero tree already contained future path: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D13StageZero (
        (Get-R23D13BlobHash $stageZeroCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D13 stage-zero blob changed: $($entry.Key)"
}

$attributeDiff = @(
    git -C $repoRoot diff --unified=0 $attributeParent $stageZeroParent -- .gitattributes
) -join "`n"
$requiredRules = @(
    "sdk/turning/r23d13_* text eol=lf",
    "sdk/turning/test_r23d13_* text eol=lf",
    "sdk/run_qsdk_r23d13_*.ps1 text eol=lf",
    "sdk/r23d13_*.ps1 text eol=lf",
    "sdk/publish_qsdk_r23d13_*.ps1 text eol=lf",
    "tests/test_qsdk_r23d13_*.ps1 text eol=lf",
    "tests/test_sdk_qsdk_r23d13_*.gd text eol=lf",
    "scripts/lab/gait/sdk_godot_jolt_r23d13_*.gd text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d13_*.rs text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d13_*.rs text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d13_*.rs text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d13_*.py text eol=lf",
    "sdk/adapters/mujoco/test_qsdk_r23d13_*.py text eol=lf"
)
foreach ($rule in $requiredRules) {
    Assert-R23D13StageZero $attributeDiff.Contains("+$rule") (
        "QSDK-R23D13 source-family checkout rule missing: $rule"
    )
}
Assert-R23D13StageZero (
    -not $attributeDiff.Contains("+* text=auto") -and
    -not $attributeDiff.Contains("+* -text")
) "QSDK-R23D13 attribute extension changed the ambient filter"

$declaration = (
    git -C $repoRoot show (
        "$stageZeroCommit`:sdk/turning/" +
        "r23d13_residual_pose_authority_preregistration_v1.json"
    ) | Out-String
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D13StageZero (
    [string]$declaration.status -ceq
        "prospectively_frozen_stage_zero_zero_world_only" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D13" -and
    [bool]$declaration.scientifically_distinct_successor.new_campaign_identity -and
    [bool]$declaration.scientifically_distinct_successor.fresh_worlds_required -and
    [bool]$declaration.scientifically_distinct_successor.final_active_authority_scalar_changed -and
    [int]$declaration.scientifically_distinct_successor.new_tunable_gain_count -eq 0 -and
    [int]$declaration.pure_zero_world_oracle.declared_canary_count -eq 10 -and
    [int]$declaration.pure_zero_world_oracle.declared_mutation_control_count -eq 20 -and
    [int]$declaration.stage_zero_authority.native_engine_route_count -eq 0 -and
    [int]$declaration.stage_zero_authority.physical_worker_count -eq 0 -and
    [int]$declaration.stage_zero_authority.model_construction_count -eq 0 -and
    [int]$declaration.stage_zero_authority.world_build_count -eq 0 -and
    -not [bool]$declaration.stage_zero_authority.physical_execution_authorized -and
    -not [bool]$declaration.claim_boundary.command_conditioned_turning -and
    -not [bool]$declaration.claim_boundary.cross_engine_equivalence -and
    -not [bool]$declaration.claim_boundary.release_authorized
) "QSDK-R23D13 stage-zero authority changed"

Write-Host (
    "QSDK_R23D13_STAGE_ZERO_CLOSURE_PASS commit=$stageZeroCommit " +
    "tree=$expectedTree blobs=$($fixedBlobs.Count) rules=$($requiredRules.Count) " +
    "canaries=10 mutations=20 future_routes=0 workers=0 models=0 worlds=0 " +
    "turning=False equivalence=False physical_authority=False"
)
