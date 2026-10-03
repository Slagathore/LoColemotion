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
$runtimeMaterializationPath = Join-Path `
    $sdkRoot `
    "r23d3_reproducible_runtime_materialization.ps1"
$releaseLibraryPath = Join-Path `
    $sdkRoot `
    "target\release\sporespore_locomotion_core.dll"
$contractPath = Join-Path `
    $sdkRoot `
    "turning\r23d3_phase_balanced_preregistration_v1.json"
$workerPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\qsdk_r23d3_phase_balanced.py"
)
$testPath = Join-Path $mujocoRoot "test_qsdk_r23d3_phase_balanced.py"
$module = "sporespore_mujoco_adapter.qsdk_r23d3_phase_balanced"
$preflightPrefix = "QSDK_R23D3_MUJOCO_PREFLIGHT "
$failurePrefix = "QSDK_R23D3_MUJOCO_FAILURE "
$cellPrefix = "QSDK_R23D3_MUJOCO_CELL "
$campaignId = "QSDK-R23D3-PHASE-BALANCED-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D3"

function Assert-R23D3MujocoExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D3MujocoWorker {
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
        "SPORESPORE_QSDK_R23D3_FREEZE",
        "SPORESPORE_QSDK_R23D3_ATTEMPT",
        "SPORESPORE_QSDK_R23D3_TOKEN",
        "SPORESPORE_QSDK_R23D3_STAGE",
        "SPORESPORE_QSDK_R23D3_CELL",
        "SPORESPORE_QSDK_R23D3_ENGINE",
        "SPORESPORE_QSDK_R23D3_ATTEMPT_ROOT"
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
    Assert-R23D3MujocoExact $process.Start() (
        "QSDK-R23D3 failed to start MuJoCo $Label"
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

function Get-R23D3MujocoMarker {
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    $markers = @(([string]$Execution.stdout -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D3MujocoExact ($markers.Count -eq 1) (
        "QSDK-R23D3 expected one '$Prefix' marker from " +
        "$($Execution.label), found $($markers.Count)"
    )
    return $markers[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $python,
    $pythonCoreRoot,
    $manifestPath,
    $runtimeMaterializationPath,
    $contractPath,
    $workerPath,
    $testPath
)) {
    Assert-R23D3MujocoExact (Test-Path -LiteralPath $path) (
        "QSDK-R23D3 MuJoCo preflight input missing: $path"
    )
}
Assert-R23D3MujocoExact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D3 MuJoCo repository identity mismatch"

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D3MujocoExact (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d3_phase_balanced_preregistration_v1" -and
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq $gateId -and
    [int]$contract.command_schedule.controller_semantic_step_count -eq 2992 -and
    [bool]$contract.command_schedule.all_engine_physical_workers_must_execute_exact_fixed_controller_horizon -and
    -not [bool]$contract.authorization.physical_execution_authorized
) "QSDK-R23D3 MuJoCo frozen declaration changed"

. $runtimeMaterializationPath
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
Assert-R23D3MujocoExact (
    [int]$coreBuild.exit_code -eq 0 -and
    [bool]$coreBuild.cargo_target_root_remapped_to_constant_virtual_prefix -and
    (Test-Path -LiteralPath $releaseLibraryPath -PathType Leaf)
) "QSDK-R23D3 MuJoCo pinned public-core build failed"

$oldLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
$oldPythonPath = $env:PYTHONPATH
try {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $releaseLibraryPath
    $env:PYTHONPATH = $mujocoRoot + [IO.Path]::PathSeparator + $pythonCoreRoot
    $testOutput = & $python -m unittest -v test_qsdk_r23d3_phase_balanced `
        2>&1 | Out-String
    Assert-R23D3MujocoExact ($LASTEXITCODE -eq 0) (
        "QSDK-R23D3 MuJoCo unit tests failed:`n$testOutput"
    )
} finally {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $oldLibrary
    $env:PYTHONPATH = $oldPythonPath
}

$cells = [Collections.Generic.List[object]]::new()
foreach ($onset in @($contract.stage_a_mujoco_onset_screen.onset_candidates)) {
    foreach ($arm in @($contract.stage_a_mujoco_onset_screen.signed_arms)) {
        $cells.Add([ordered]@{
            stage = "mujoco_onset_screen"
            onset = [string]$onset.onset_id
            onset_step = [int]$onset.turn_start_semantic_step
            arm = [string]$arm.arm_id
            offset = [double]$arm.turn_heading_offset_rad
        })
    }
}
foreach ($onset in @($contract.stage_a_mujoco_onset_screen.onset_candidates)) {
    foreach ($armId in @($contract.stage_b_three_engine_confirmation.ordered_arm_ids)) {
        $cells.Add([ordered]@{
            stage = "three_engine_confirmation"
            onset = [string]$onset.onset_id
            onset_step = [int]$onset.turn_start_semantic_step
            arm = [string]$armId
            offset = [double]$contract.stage_b_three_engine_confirmation.arm_heading_offsets_rad[$armId]
        })
    }
}
Assert-R23D3MujocoExact ($cells.Count -eq 20) (
    "QSDK-R23D3 MuJoCo projected worker identity count changed"
)

$fixedHorizonProofs = 0
foreach ($cell in $cells) {
    $execution = Invoke-R23D3MujocoWorker -Label (
        "$($cell.stage):$($cell.onset):$($cell.arm)"
    ) -Arguments @(
        "--stage", [string]$cell.stage,
        "--onset", [string]$cell.onset,
        "--arm", [string]$cell.arm,
        "--preflight-only"
    )
    Assert-R23D3MujocoExact (
        -not [bool]$execution.timed_out -and [int]$execution.exit_code -eq 0
    ) "QSDK-R23D3 MuJoCo identity preflight failed: $($execution.label)"
    $receipt = Get-R23D3MujocoMarker $execution $preflightPrefix
    $expectedWarmup = [int]$cell.onset_step
    $expectedAfter = 2992 - $expectedWarmup - 1200 - 600
    Assert-R23D3MujocoExact (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d3_mujoco_worker_preflight_v1" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.gate_id -ceq $gateId -and
        [string]$receipt.engine_id -ceq "mujoco" -and
        [string]$receipt.stage_id -ceq [string]$cell.stage -and
        [string]$receipt.onset_id -ceq [string]$cell.onset -and
        [int]$receipt.turn_start_semantic_step -eq [int]$cell.onset_step -and
        [string]$receipt.arm_id -ceq [string]$cell.arm -and
        [Math]::Abs([double]$receipt.turn_heading_offset_rad - [double]$cell.offset) -le 1.0e-15 -and
        [int]$receipt.segment_counts.reference_warmup -eq $expectedWarmup -and
        [int]$receipt.segment_counts.commanded_turn -eq 1200 -and
        [int]$receipt.segment_counts.reference_recovery -eq 600 -and
        [int]$receipt.segment_counts.after_declared_schedule -eq $expectedAfter -and
        [int]$receipt.fixed_controller_horizon_step_count -eq 2992 -and
        [bool]$receipt.fixed_horizon_configuration_proved_before_fixture_insertion -and
        [bool]$receipt.trace_retained_before_terminal_entry_required -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        -not [bool]$receipt.physical_execution_authorized -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "QSDK-R23D3 MuJoCo preflight receipt changed: $($execution.label)"
    $fixedHorizonProofs += 1
}

$unknownExecution = Invoke-R23D3MujocoWorker `
    -Label "unknown-stage" `
    -Arguments @(
        "--stage", "unknown_stage", "--onset", "onset_600",
        "--arm", "positive_heading", "--preflight-only"
    )
Assert-R23D3MujocoExact (
    -not [bool]$unknownExecution.timed_out -and
    [int]$unknownExecution.exit_code -ne 0
) "QSDK-R23D3 unknown MuJoCo identity did not fail closed"
[void](Get-R23D3MujocoMarker $unknownExecution $failurePrefix)

$bypassExecution = Invoke-R23D3MujocoWorker `
    -Label "physical-bypass" `
    -Arguments @(
        "--stage", "mujoco_onset_screen", "--onset", "onset_600",
        "--arm", "positive_heading", "--source-commit", ("0" * 40)
    )
Assert-R23D3MujocoExact (
    -not [bool]$bypassExecution.timed_out -and
    [int]$bypassExecution.exit_code -ne 0
) "QSDK-R23D3 direct MuJoCo physical bypass did not fail closed"
$bypass = Get-R23D3MujocoMarker $bypassExecution $failurePrefix
$cellMarkers = @(([string]$bypassExecution.stdout -split "`r?`n") | Where-Object {
    $_.StartsWith($cellPrefix, [StringComparison]::Ordinal)
})
Assert-R23D3MujocoExact (
    [string]$bypass.schema_version -ceq
        "sporespore_qsdk_r23d3_worker_failure_v1" -and
    [string]$bypass.failure_code -ceq
        "QSDK_R23D3_MJC_CLOSED" -and
    [string]$bypass.failure_stage -ceq "before_world" -and
    [int]$bypass.world_attempt_count -eq 0 -and
    [int]$bypass.world_build_count -eq 0 -and
    $null -eq $bypass.trace_artifact -and
    $cellMarkers.Count -eq 0 -and
    -not [bool]$bypass.claims.physical_acceptance_authority
) "QSDK-R23D3 MuJoCo physical-bypass receipt changed"

Write-Host (
    "QSDK_R23D3_MUJOCO_WORKER_PASS identities=20 " +
    "fixed_horizon_proofs=$fixedHorizonProofs inherited_canaries=140 " +
    "inherited_predicate_controls=700 negative_controls=2 " +
    "model_constructions=0 worlds=0 physical_authority=False"
)
