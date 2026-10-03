#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageZeroCommit = "6116fcef7c28c3bc91d2ad115dca61b9a97bfb0a"
$stageZeroParent = "7093082481bfa6d82484b9d86d48ea09e1b4847e"
$attributeParent = "a873b54ec60e3435c09714c09c78ba848cfa47d8"
$fixedBlobs = [ordered]@{
    ".gitattributes" =
        "0f2b3e6b2a658e06f3bb8d724d3f5d0ff36853d8ce1d35ff5fac295a0095286b"
    "sdk/run_qsdk_r23d12_stage_zero_gate.ps1" =
        "01c6ba98c9bcc90ba831ba190918cfcce9855a4b5fb3d476b2f219b076ce690c"
    "sdk/turning/r23d12_measurement_semantics.py" =
        "9a9d5e4b9cb5198ee3e17fed664d3e515049bae3f48081e249882ed24d53971a"
    "sdk/turning/r23d12_measurement_semantics_preregistration_v1.json" =
        "423386cb4ff89e2718f58ace31fd29405f7ca4301aca4028f40eb5d8e7e8870c"
    "sdk/turning/test_r23d12_measurement_semantics.py" =
        "714aaadbcf321cfedc777784a918252979d7767cceaa771c9704a7f16a053b58"
    "tests/test_qsdk_r23d12_declaration.ps1" =
        "1d5939822dab8392c2d1bf135e7fff9863e0aec6f0e43b5a8eb381e928b3034a"
}
$futurePaths = @(
    "sdk/turning/r23d12_native_route_contract_v1.json",
    "sdk/turning/r23d12_physical_trace.py",
    "sdk/turning/r23d12_physical_evaluator.py",
    "sdk/turning/r23d12_physical_implementation_contract_v1.json",
    "sdk/run_qsdk_r23d12_supervisor.ps1",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d12_physical.py",
    "sdk/adapters/rapier/src/qsdk_r23d12_physical.rs",
    "scripts/lab/gait/sdk_godot_jolt_r23d12_physical.gd",
    "sdk/turning/r23d12_physical_closure_v1.json"
)

function Assert-R23D12StageZero([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D12BlobHash([string]$Commit, [string]$Path) {
    $blob = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D12StageZero ($LASTEXITCODE -eq 0) (
        "QSDK-R23D12 stage-zero blob unavailable: $Path"
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
        Assert-R23D12StageZero ($process.ExitCode -eq 0) (
            "QSDK-R23D12 stage-zero blob read failed: $Path"
        )
        return (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

Assert-R23D12StageZero (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D12 stage-zero repository identity changed"
Assert-R23D12StageZero (
    (git -C $repoRoot rev-parse "$stageZeroCommit^{commit}").Trim() -ceq
        $stageZeroCommit -and
    (git -C $repoRoot rev-parse "$stageZeroCommit^").Trim() -ceq $stageZeroParent -and
    (git -C $repoRoot rev-parse "$stageZeroParent^").Trim() -ceq $attributeParent
) "QSDK-R23D12 stage-zero commit boundary changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageZeroCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D12StageZero ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D12 stage-zero tree already contained future path: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D12StageZero (
        (Get-R23D12BlobHash $stageZeroCommit $entry.Key) -ceq [string]$entry.Value
    ) "QSDK-R23D12 stage-zero blob changed: $($entry.Key)"
}

$attributeDiff = @(
    git -C $repoRoot diff --unified=0 $attributeParent $stageZeroParent -- .gitattributes
) -join "`n"
Assert-R23D12StageZero (
    $attributeDiff.Contains("+sdk/turning/r23d12_* text eol=lf") -and
    $attributeDiff.Contains("+sdk/adapters/mujoco/test_qsdk_r23d12_*.py text eol=lf") -and
    -not $attributeDiff.Contains("+* text=auto") -and
    -not $attributeDiff.Contains("+* -text")
) "QSDK-R23D12 source-family checkout rule changed"

$declaration = (
    git -C $repoRoot show (
        "$stageZeroCommit`:sdk/turning/r23d12_measurement_semantics_preregistration_v1.json"
    ) | Out-String
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D12StageZero (
    [string]$declaration.status -ceq
        "prospectively_frozen_stage_zero_zero_world_only" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D12" -and
    [bool]$declaration.distinct_successor_boundary.new_campaign_identity -and
    [bool]$declaration.distinct_successor_boundary.fresh_worlds_required -and
    -not [bool]$declaration.distinct_successor_boundary.physical_policy_changed -and
    [bool]$declaration.distinct_successor_boundary.trace_schema_changed -and
    [bool]$declaration.distinct_successor_boundary.diagnostic_validation_semantics_changed -and
    [bool]$declaration.prospective_diagnostic_schema.observation_unavailable_with_measured_finite_margin_is_valid -and
    [int]$declaration.pure_measurement_semantics_oracle.declared_valid_canary_count -eq 7 -and
    [int]$declaration.pure_measurement_semantics_oracle.declared_active_cross_product_count -eq 6 -and
    [int]$declaration.pure_measurement_semantics_oracle.declared_mutation_control_count -eq 14 -and
    [int]$declaration.stage_zero_authority.native_engine_route_count -eq 0 -and
    [int]$declaration.stage_zero_authority.physical_worker_count -eq 0 -and
    [int]$declaration.stage_zero_authority.model_construction_count -eq 0 -and
    [int]$declaration.stage_zero_authority.world_build_count -eq 0 -and
    -not [bool]$declaration.stage_zero_authority.physical_execution_authorized -and
    -not [bool]$declaration.claim_boundary.command_conditioned_turning -and
    -not [bool]$declaration.claim_boundary.cross_engine_equivalence -and
    -not [bool]$declaration.claim_boundary.release_authorized
) "QSDK-R23D12 stage-zero authority changed"

Write-Host (
    "QSDK_R23D12_STAGE_ZERO_CLOSURE_PASS commit=$stageZeroCommit " +
    "blobs=$($fixedBlobs.Count) canaries=7 cross_product=6 mutations=14 " +
    "future_routes=0 workers=0 models=0 worlds=0 turning=False " +
    "equivalence=False physical_authority=False"
)
