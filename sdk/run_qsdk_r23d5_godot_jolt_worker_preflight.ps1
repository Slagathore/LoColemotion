#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$workerPath = Join-Path $repoRoot "tests\test_sdk_qsdk_r23d5_godot_jolt_worker.gd"
$runnerPath = Join-Path $repoRoot "scripts\lab\gait\physical_wave_gait_quadruped.gd"
$restorerPath = Join-Path $repoRoot (
    "scripts\lab\gait\sdk_godot_jolt_terminal_restoration.gd"
)
$preregistrationPath = Join-Path $sdkRoot (
    "turning\r23d5_dependency_closed_preregistration_v1.json"
)
$workerResource = "res://tests/test_sdk_qsdk_r23d5_godot_jolt_worker.gd"
$preflightPrefix = "QSDK_R23D5_GODOT_JOLT_PREFLIGHT "
$failurePrefix = "QSDK_R23D5_GODOT_JOLT_FAILURE "
$campaignId = "QSDK-R23D5-DEPENDENCY-CLOSED-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D5"
$engineId = "godot_jolt"
$arms = [ordered]@{
    reference_zero = 0.0
    positive_heading = 0.2
    negative_heading = -0.2
}

function Assert-QsdkR23d5Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-QsdkR23d5GodotJolt {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$UserArguments,
        [Parameter(Mandatory)][string]$Label
    )
    $runRoot = Join-Path $sdkRoot (
        "target\qsdk-r23d5-godot-jolt-preflight\" +
        [guid]::NewGuid().ToString("N")
    )
    $appData = Join-Path $runRoot "appdata"
    $localAppData = Join-Path $runRoot "localappdata"
    $logPath = Join-Path $runRoot "$Label-godot.log"
    [void][IO.Directory]::CreateDirectory($appData)
    [void][IO.Directory]::CreateDirectory($localAppData)

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Godot
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    foreach ($name in @(
        "SPORESPORE_QSDK_R23D5_FREEZE",
        "SPORESPORE_QSDK_R23D5_ATTEMPT",
        "SPORESPORE_QSDK_R23D5_TOKEN",
        "SPORESPORE_QSDK_R23D5_STAGE",
        "SPORESPORE_QSDK_R23D5_CELL",
        "SPORESPORE_QSDK_R23D5_ENGINE",
        "SPORESPORE_QSDK_R23D5_ATTEMPT_ROOT",
        "SPORESPORE_QSDK_R23D5_PYTHON",
        "SPORESPORE_QSDK_R23D5_POWERSHELL"
    )) {
        $start.Environment[$name] = ""
    }
    foreach ($argument in @(
        "--headless",
        "--path", $repoRoot,
        "--log-file", $logPath,
        "--script", $workerResource,
        "--"
    ) + $UserArguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-QsdkR23d5Exact $process.Start() (
        "QSDK-R23D5 failed to start Godot/Jolt worker: $Label"
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
        log_path = $logPath
    }
}

function Assert-QsdkR23d5CleanGodotExecution {
    param([Parameter(Mandatory)][Collections.IDictionary]$Execution)
    $combined = [string]$Execution.stdout + [Environment]::NewLine +
        [string]$Execution.stderr
    Assert-QsdkR23d5Exact (-not [bool]$Execution.timed_out) (
        "QSDK-R23D5 Godot/Jolt worker timed out: $($Execution.label)"
    )
    Assert-QsdkR23d5Exact (
        $combined -cnotmatch "(?m)SCRIPT ERROR|Parse Error|ERROR:"
    ) (
        "QSDK-R23D5 Godot/Jolt worker emitted an engine error: " +
        "$($Execution.label); log=$($Execution.log_path); output=$combined"
    )
}

function Get-QsdkR23d5MarkerReceipt {
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @(([string]$Execution.stdout -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-QsdkR23d5Exact ($lines.Count -eq 1) (
        "QSDK-R23D5 expected one '$Prefix' marker from " +
        "$($Execution.label), found $($lines.Count); stdout=$($Execution.stdout)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

Assert-QsdkR23d5Exact ([IO.File]::Exists($Godot)) (
    "QSDK-R23D5 Godot executable missing: $Godot"
)
foreach ($path in @(
    $workerPath,
    $runnerPath,
    $restorerPath,
    $preregistrationPath
)) {
    Assert-QsdkR23d5Exact ([IO.File]::Exists($path)) (
        "QSDK-R23D5 required path missing: $path"
    )
}
$contract = Get-Content -LiteralPath $preregistrationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-QsdkR23d5Exact (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d5_dependency_closed_preregistration_v1" -and
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq $gateId -and
    [bool]$contract.authorization.physical_execution_authorized -eq $false -and
    [int]$contract.frozen_schedule_and_gate_snapshot.turning_controller_semantic_step_count -eq 2992 -and
    [int]$contract.frozen_schedule_and_gate_snapshot.terminal_restoration_step_count -eq 540 -and
    [int]$contract.frozen_schedule_and_gate_snapshot.passive_settle_step_count -eq 240 -and
    [int]$contract.frozen_schedule_and_gate_snapshot.total_traced_step_count -eq 3772
) "QSDK-R23D5 preregistration identity is not exact"

$workerSource = [IO.File]::ReadAllText($workerPath)
$runnerSource = [IO.File]::ReadAllText($runnerPath)
$restorerSource = [IO.File]::ReadAllText($restorerPath)
Assert-QsdkR23d5Exact (
    $workerSource.Contains("_r5_source_bindings_exact(freeze)") -and
    $workerSource.Contains("var summary: Dictionary = await _r5_run_wave(prepared, false)") -and
    $workerSource.Contains("var retention := _r5_retain_trace(") -and
    $runnerSource.Contains("requested_sdk_terminal_restoration_options") -and
    $runnerSource.Contains("QSDK_R23D4_TOTAL_TRACE_STEP_COUNT := 3772") -and
    $restorerSource.Contains("static func validate_receipt(") -and
    $restorerSource.Contains("HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY")
) "QSDK-R23D5 Godot/Jolt source ordering or production seam is incomplete"

$identityCount = 0
$horizonProofCount = 0
$traceCanaryCount = 0
$restorationGateCount = 0
$restorationNegativeControlCount = 0
$predicateControlCount = 0
foreach ($arm in $arms.GetEnumerator()) {
    $label = [string]$arm.Key
    $execution = Invoke-QsdkR23d5GodotJolt -Label $label -UserArguments @(
        "--stage", "three_engine_confirmation",
        "--arm", [string]$arm.Key,
        "--preflight-only"
    )
    Assert-QsdkR23d5CleanGodotExecution $execution
    Assert-QsdkR23d5Exact ([int]$execution.exit_code -eq 0) (
        "QSDK-R23D5 Godot/Jolt preflight failed: $label; " +
        "stdout=$($execution.stdout); stderr=$($execution.stderr)"
    )
    $receipt = Get-QsdkR23d5MarkerReceipt $execution $preflightPrefix
    $expectedCell = "$engineId`__onset_600__$($arm.Key)"
    Assert-QsdkR23d5Exact (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d5_godot_jolt_worker_preflight_v1" -and
        [bool]$receipt.ok -eq $true -and
        [string]$receipt.failure_code -ceq "" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.gate_id -ceq $gateId -and
        [string]$receipt.engine_id -ceq $engineId -and
        [string]$receipt.stage_id -ceq "three_engine_confirmation" -and
        [string]$receipt.cell_id -ceq $expectedCell -and
        [string]$receipt.arm_id -ceq [string]$arm.Key -and
        [double]$receipt.turn_heading_offset_rad -eq [double]$arm.Value -and
        [int]$receipt.fixed_controller_horizon_step_count -eq 2992 -and
        [int]$receipt.fixed_restoration_step_count -eq 540 -and
        [int]$receipt.fixed_passive_settle_step_count -eq 240 -and
        [int]$receipt.fixed_total_trace_step_count -eq 3772 -and
        [bool]$receipt.fixed_horizon_configuration_proved_before_fixture_insertion -and
        [bool]$receipt.trace_row_canary.ok -and
        [int]$receipt.trace_row_canary.representative_trace_row_count -eq 14 -and
        [bool]$receipt.trace_row_canary.oracle_mutation_rejected -and
        [bool]$receipt.terminal_restoration_canary.ok -and
        [int]$receipt.terminal_restoration_canary.real_shaped_actuator_count -eq 8 -and
        [int]$receipt.terminal_restoration_canary.negative_control_count -eq 5 -and
        [bool]$receipt.terminal_restoration_canary.all_negative_controls_rejected -and
        [int]$receipt.godot_predicate_negative_control_count -eq 12 -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        [bool]$receipt.physical_execution_authorized -eq $false -and
        [bool]$receipt.physical_acceptance_authority -eq $false
    ) "QSDK-R23D5 Godot/Jolt receipt mismatch: $label"
    Assert-QsdkR23d5Exact (
        [bool]$receipt.entrypoint_preflight.sdk_terminal_restoration_enabled -and
        [bool]$receipt.entrypoint_preflight.sdk_physical_trace_enabled -eq $false -and
        [int]$receipt.entrypoint_preflight.actual_world_build_count -eq 0 -and
        [int]$receipt.entrypoint_preflight.scene_tree_insertion_count -eq 0 -and
        [bool]$receipt.entrypoint_preflight.physics_state_modified -eq $false
    ) "QSDK-R23D5 Godot/Jolt entrypoint preflight mismatch: $label"
    $identityCount += 1
    $horizonProofCount += 1
    $traceCanaryCount += 1
    $restorationGateCount += 1
    $restorationNegativeControlCount += 5
    $predicateControlCount += 12
}

$refusal = Invoke-QsdkR23d5GodotJolt -Label "authorization-refusal" -UserArguments @(
    "--stage", "three_engine_confirmation",
    "--arm", "positive_heading",
    "--source-commit", ("0" * 40)
)
Assert-QsdkR23d5CleanGodotExecution $refusal
Assert-QsdkR23d5Exact ([int]$refusal.exit_code -ne 0) (
    "QSDK-R23D5 unauthorized Godot/Jolt execution unexpectedly succeeded"
)
$failure = Get-QsdkR23d5MarkerReceipt $refusal $failurePrefix
Assert-QsdkR23d5Exact (
    [string]$failure.schema_version -ceq "sporespore_qsdk_r23d5_worker_failure_v1" -and
    [string]$failure.failure_stage -ceq "before_world" -and
    [string]$failure.failure_code -ceq "QSDK_R23D5_GJT_PHYSICAL_AUTHORIZATION_REQUIRED" -and
    [int]$failure.world_attempt_count -eq 0 -and
    [int]$failure.world_build_count -eq 0
) "QSDK-R23D5 direct physical authorization refusal mismatch"

Write-Output (
    "QSDK_R23D5_GODOT_JOLT_WORKER_PASS " +
    "identities=$identityCount " +
    "fixed_horizon_proofs=$horizonProofCount " +
    "trace_canaries=$traceCanaryCount " +
    "restoration_gate_executions=$restorationGateCount " +
    "restoration_negative_controls=$restorationNegativeControlCount " +
    "predicate_controls=$predicateControlCount " +
    "authorization_refusals=1 model_constructions=0 worlds=0 " +
    "physical_authority=False"
)
