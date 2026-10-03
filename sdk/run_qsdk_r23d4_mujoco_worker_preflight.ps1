#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$pythonCoreRoot = Join-Path $sdkRoot "python"
$manifestPath = Join-Path $sdkRoot "Cargo.toml"
$materializerPath = Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1"
$releaseLibraryPath = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$contractPath = Join-Path $sdkRoot "turning\r23d4_terminal_stabilization_preregistration_v1.json"
$workerPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\qsdk_r23d4_terminal_stabilization.py"
)
$testPath = Join-Path $mujocoRoot "test_qsdk_r23d4_terminal_stabilization.py"
$module = "sporespore_mujoco_adapter.qsdk_r23d4_terminal_stabilization"
$preflightPrefix = "QSDK_R23D4_MUJOCO_PREFLIGHT "
$terminalPrefix = "QSDK_R23D4_TERMINAL "
$campaignId = "QSDK-R23D4-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D4"

function Assert-R23D4MujocoExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D4MujocoWorker {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $python
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["SPORESPORE_LOCOMOTION_LIBRARY"] = $releaseLibraryPath
    $start.Environment["PYTHONPATH"] = (
        $mujocoRoot + [IO.Path]::PathSeparator + $pythonCoreRoot
    )
    foreach ($name in @(
        "SPORESPORE_QSDK_R23D4_FREEZE",
        "SPORESPORE_QSDK_R23D4_ATTEMPT",
        "SPORESPORE_QSDK_R23D4_TOKEN",
        "SPORESPORE_QSDK_R23D4_STAGE",
        "SPORESPORE_QSDK_R23D4_CELL",
        "SPORESPORE_QSDK_R23D4_ENGINE",
        "SPORESPORE_QSDK_R23D4_ATTEMPT_ROOT"
    )) {
        [void]$start.Environment.Remove($name)
    }
    [void]$start.ArgumentList.Add("-m")
    [void]$start.ArgumentList.Add($module)
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D4MujocoExact $process.Start() (
        "QSDK-R23D4 failed to start MuJoCo $Label"
    )
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit(60000)
    if ($timedOut) {
        $process.Kill($true)
        $process.WaitForExit()
    }
    return [ordered]@{
        label = $Label
        exit_code = $process.ExitCode
        timed_out = $timedOut
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
}

function Get-R23D4MujocoMarker {
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    $markers = @(([string]$Execution.stdout -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D4MujocoExact ($markers.Count -eq 1) (
        "QSDK-R23D4 expected one '$Prefix' marker from " +
        "$($Execution.label), found $($markers.Count)"
    )
    return $markers[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $python,
    $pythonCoreRoot,
    $manifestPath,
    $materializerPath,
    $contractPath,
    $workerPath,
    $testPath
)) {
    Assert-R23D4MujocoExact (Test-Path -LiteralPath $path) (
        "QSDK-R23D4 MuJoCo preflight input missing: $path"
    )
}
Assert-R23D4MujocoExact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D4 MuJoCo repository identity mismatch"

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D4MujocoExact (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d4_terminal_stabilization_preregistration_v1" -and
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq $gateId -and
    [int]$contract.command_and_terminal_schedule.turning_controller_semantic_step_count -eq 2992 -and
    [int]$contract.command_and_terminal_schedule.terminal_restoration_step_count -eq 540 -and
    [int]$contract.command_and_terminal_schedule.passive_settle_step_count -eq 240 -and
    [int]$contract.command_and_terminal_schedule.total_traced_step_count -eq 3772 -and
    -not [bool]$contract.authorization.physical_execution_authorized
) "QSDK-R23D4 MuJoCo frozen declaration changed"

. $materializerPath
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
$coreBuild = Invoke-SporeSporeR23D3PinnedCargo `
    -RepoRoot $repoRoot `
    -SourceCommit $sourceCommit `
    -TargetRoot (Join-Path $sdkRoot "target") `
    -CargoArguments @(
        "build", "--quiet", "--release", "--locked", "--offline",
        "--manifest-path", $manifestPath,
        "--package", "sporespore-locomotion-core"
    )
Assert-R23D4MujocoExact (
    [int]$coreBuild.exit_code -eq 0 -and
    [bool]$coreBuild.cargo_target_root_remapped_to_constant_virtual_prefix -and
    (Test-Path -LiteralPath $releaseLibraryPath -PathType Leaf)
) "QSDK-R23D4 MuJoCo pinned public-core build failed"

$oldLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
$oldPythonPath = $env:PYTHONPATH
try {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $releaseLibraryPath
    $env:PYTHONPATH = $mujocoRoot + [IO.Path]::PathSeparator + $pythonCoreRoot
    $testOutput = & $python -m unittest -v test_qsdk_r23d4_terminal_stabilization `
        2>&1 | Out-String
    Assert-R23D4MujocoExact ($LASTEXITCODE -eq 0) (
        "QSDK-R23D4 MuJoCo unit tests failed:`n$testOutput"
    )
} finally {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $oldLibrary
    $env:PYTHONPATH = $oldPythonPath
}

$cells = @(
    @{ stage = "mujoco_terminal_restoration_screen"; arm = "positive_heading"; offset = 0.2 },
    @{ stage = "mujoco_terminal_restoration_screen"; arm = "negative_heading"; offset = -0.2 },
    @{ stage = "three_engine_confirmation"; arm = "reference_zero"; offset = 0.0 },
    @{ stage = "three_engine_confirmation"; arm = "positive_heading"; offset = 0.2 },
    @{ stage = "three_engine_confirmation"; arm = "negative_heading"; offset = -0.2 }
)
$fixedHorizonProofs = 0
foreach ($cell in $cells) {
    $execution = Invoke-R23D4MujocoWorker -Label (
        "$($cell.stage):$($cell.arm)"
    ) -Arguments @(
        "preflight", "--stage-id", [string]$cell.stage,
        "--arm-id", [string]$cell.arm
    )
    Assert-R23D4MujocoExact (
        -not [bool]$execution.timed_out -and [int]$execution.exit_code -eq 0
    ) "QSDK-R23D4 MuJoCo identity preflight failed: $($execution.label)"
    $receipt = Get-R23D4MujocoMarker $execution $preflightPrefix
    Assert-R23D4MujocoExact (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d4_mujoco_worker_preflight_v1" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.gate_id -ceq $gateId -and
        [string]$receipt.engine_id -ceq "mujoco" -and
        [string]$receipt.stage_id -ceq [string]$cell.stage -and
        [string]$receipt.arm_id -ceq [string]$cell.arm -and
        [Math]::Abs([double]$receipt.turn_heading_offset_rad - [double]$cell.offset) -le 1.0e-15 -and
        [int]$receipt.fixed_controller_horizon_step_count -eq 2992 -and
        [int]$receipt.fixed_terminal_restoration_step_count -eq 540 -and
        [int]$receipt.fixed_passive_settle_step_count -eq 240 -and
        [int]$receipt.fixed_total_trace_step_count -eq 3772 -and
        [int]$receipt.terminal_restoration_negative_control_count -eq 5 -and
        [int]$receipt.kinematic_vector_negative_control_count -eq 5 -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        -not [bool]$receipt.physical_execution_authorized -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "QSDK-R23D4 MuJoCo preflight receipt changed: $($execution.label)"
    $fixedHorizonProofs += 1
}

$unknown = Invoke-R23D4MujocoWorker -Label "unknown-stage" -Arguments @(
    "preflight", "--stage-id", "unknown_stage", "--arm-id", "positive_heading"
)
Assert-R23D4MujocoExact (
    -not [bool]$unknown.timed_out -and [int]$unknown.exit_code -ne 0
) "QSDK-R23D4 unknown MuJoCo identity did not fail closed"

$bypass = Invoke-R23D4MujocoWorker -Label "physical-bypass" -Arguments @(
    "physical", "--stage-id", "mujoco_terminal_restoration_screen",
    "--arm-id", "positive_heading", "--source-commit", ("0" * 40)
)
Assert-R23D4MujocoExact (
    -not [bool]$bypass.timed_out -and [int]$bypass.exit_code -ne 0
) "QSDK-R23D4 direct MuJoCo physical bypass did not fail closed"
$terminal = Get-R23D4MujocoMarker $bypass $terminalPrefix
Assert-R23D4MujocoExact (
    [string]$terminal.schema_version -ceq
        "sporespore_qsdk_r23d4_worker_failure_v1" -and
    [string]$terminal.failure_code -ceq
        "QSDK_R23D4_MJC_PHYSICAL_AUTHORIZATION_REQUIRED" -and
    [string]$terminal.failure_stage -ceq "before_world" -and
    [int]$terminal.world_attempt_count -eq 0 -and
    [int]$terminal.world_build_count -eq 0 -and
    $null -eq $terminal.trace_artifact -and
    -not [bool]$terminal.claims.physical_acceptance_authority
) "QSDK-R23D4 MuJoCo physical-bypass receipt changed"

Write-Host (
    "QSDK_R23D4_MUJOCO_WORKER_PASS identities=5 " +
    "fixed_horizon_proofs=$fixedHorizonProofs inherited_canaries=35 " +
    "inherited_predicate_controls=175 restoration_controls=25 " +
    "vector_controls=25 negative_controls=2 model_constructions=0 " +
    "worlds=0 physical_authority=False"
)
