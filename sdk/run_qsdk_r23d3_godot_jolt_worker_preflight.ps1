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
$workerPath = Join-Path $repoRoot "tests\test_sdk_qsdk_r23d3_godot_jolt_worker.gd"
$runnerPath = Join-Path $repoRoot "scripts\lab\gait\physical_wave_gait_quadruped.gd"
$preregistrationPath = Join-Path $sdkRoot (
    "turning\r23d3_phase_balanced_preregistration_v1.json"
)
$workerResource = "res://tests/test_sdk_qsdk_r23d3_godot_jolt_worker.gd"
$preflightPrefix = "QSDK_R23D3_GODOT_JOLT_PREFLIGHT "
$failurePrefix = "QSDK_R23D3_GODOT_JOLT_FAILURE "
$campaignId = "QSDK-R23D3-PHASE-BALANCED-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D3"
$engineId = "godot_jolt"
$onsets = [ordered]@{
    onset_600 = 600
    onset_690 = 690
    onset_780 = 780
    onset_870 = 870
}
$arms = [ordered]@{
    reference_zero = 0.0
    positive_heading = 0.2
    negative_heading = -0.2
}

function Assert-QsdkR23d3Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-QsdkR23d3GodotJolt {
    param(
        [Parameter(Mandatory)][string[]]$UserArguments,
        [Parameter(Mandatory)][string]$Label
    )
    $runRoot = Join-Path $sdkRoot (
        "target\qsdk-r23d3-godot-jolt-preflight\" +
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
        "SPORESPORE_QSDK_R23D3_FREEZE",
        "SPORESPORE_QSDK_R23D3_ATTEMPT",
        "SPORESPORE_QSDK_R23D3_TOKEN",
        "SPORESPORE_QSDK_R23D3_STAGE",
        "SPORESPORE_QSDK_R23D3_CELL",
        "SPORESPORE_QSDK_R23D3_ENGINE",
        "SPORESPORE_QSDK_R23D3_ATTEMPT_ROOT",
        "SPORESPORE_QSDK_R23D3_PYTHON",
        "SPORESPORE_QSDK_R23D3_POWERSHELL"
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
    Assert-QsdkR23d3Exact $process.Start() (
        "QSDK-R23D3 failed to start Godot/Jolt worker: $Label"
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

function Assert-QsdkR23d3CleanGodotExecution {
    param([Parameter(Mandatory)][Collections.IDictionary]$Execution)
    $combined = [string]$Execution.stdout + [Environment]::NewLine +
        [string]$Execution.stderr
    Assert-QsdkR23d3Exact (-not [bool]$Execution.timed_out) (
        "QSDK-R23D3 Godot/Jolt worker timed out: $($Execution.label)"
    )
    Assert-QsdkR23d3Exact (
        $combined -cnotmatch "(?m)SCRIPT ERROR|Parse Error|ERROR:"
    ) (
        "QSDK-R23D3 Godot/Jolt worker emitted an engine error: " +
        "$($Execution.label); log=$($Execution.log_path)"
    )
}

function Get-QsdkR23d3MarkerReceipt {
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @(([string]$Execution.stdout -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-QsdkR23d3Exact ($lines.Count -eq 1) (
        "QSDK-R23D3 expected one '$Prefix' marker from " +
        "$($Execution.label), found $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

Assert-QsdkR23d3Exact ([IO.File]::Exists($Godot)) (
    "QSDK-R23D3 Godot executable missing: $Godot"
)
foreach ($path in @($workerPath, $runnerPath, $preregistrationPath)) {
    Assert-QsdkR23d3Exact ([IO.File]::Exists($path)) (
        "QSDK-R23D3 required path missing: $path"
    )
}
$contract = Get-Content -LiteralPath $preregistrationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-QsdkR23d3Exact (
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq $gateId -and
    [bool]$contract.authorization.physical_execution_authorized -eq $false -and
    [int]$contract.command_schedule.controller_semantic_step_count -eq 2992
) "QSDK-R23D3 preregistration identity is not exact"

$workerSource = [IO.File]::ReadAllText($workerPath)
$runnerSource = [IO.File]::ReadAllText($runnerPath)
$waveIndex = $workerSource.IndexOf(
    "var summary: Dictionary = await _run_wave(prepared, false)",
    [StringComparison]::Ordinal
)
$retainIndex = $workerSource.IndexOf(
    "var retention := _retain_trace(",
    [StringComparison]::Ordinal
)
$reportIndex = $workerSource.IndexOf(
    '"schema_version": REPORT_SCHEMA,',
    $retainIndex,
    [StringComparison]::Ordinal
)
Assert-QsdkR23d3Exact (
    $waveIndex -ge 0 -and $retainIndex -gt $waveIndex -and
    $reportIndex -gt $retainIndex -and
    $workerSource.Contains("_source_bindings_exact(freeze)") -and
    $workerSource.Contains("fixed_horizon_configuration_proved_before_fixture_insertion") -and
    $workerSource.Contains("raw_sdk_authority_summary") -and
    $workerSource.Contains("godot_execution_predicates") -and
    $runnerSource.Contains("QSDK_R23D3_AUTHORITY_HORIZON_OBSERVATION_COUNT := 2992") -and
    $runnerSource.Contains("_compose_sdk_physical_trace_row(")
) "QSDK-R23D3 Godot/Jolt source ordering or fixed-horizon surface is incomplete"

$identityCount = 0
$horizonProofCount = 0
$traceCanaryCount = 0
$predicateControlCount = 0
foreach ($onset in $onsets.GetEnumerator()) {
    foreach ($arm in $arms.GetEnumerator()) {
        $label = "$($onset.Key)-$($arm.Key)"
        $execution = Invoke-QsdkR23d3GodotJolt -Label $label -UserArguments @(
            "--stage", "three_engine_confirmation",
            "--onset", [string]$onset.Key,
            "--arm", [string]$arm.Key,
            "--preflight-only"
        )
        Assert-QsdkR23d3CleanGodotExecution $execution
        Assert-QsdkR23d3Exact ([int]$execution.exit_code -eq 0) (
            "QSDK-R23D3 Godot/Jolt preflight failed: $label"
        )
        $receipt = Get-QsdkR23d3MarkerReceipt $execution $preflightPrefix
        $expectedCell = "$engineId`__$($onset.Key)__$($arm.Key)"
        Assert-QsdkR23d3Exact (
            [string]$receipt.schema_version -ceq
                "sporespore_qsdk_r23d3_godot_jolt_worker_preflight_v1" -and
            [bool]$receipt.ok -eq $true -and
            [string]$receipt.failure_code -ceq "" -and
            [string]$receipt.campaign_id -ceq $campaignId -and
            [string]$receipt.gate_id -ceq $gateId -and
            [string]$receipt.engine_id -ceq $engineId -and
            [string]$receipt.stage_id -ceq "three_engine_confirmation" -and
            [string]$receipt.cell_id -ceq $expectedCell -and
            [string]$receipt.onset_id -ceq [string]$onset.Key -and
            [int]$receipt.turn_start_semantic_step -eq [int]$onset.Value -and
            [string]$receipt.arm_id -ceq [string]$arm.Key -and
            [double]$receipt.turn_heading_offset_rad -eq [double]$arm.Value -and
            [int]$receipt.fixed_controller_horizon_step_count -eq 2992 -and
            [bool]$receipt.fixed_horizon_configuration_proved_before_fixture_insertion -eq
                $true -and
            [bool]$receipt.trace_row_canary.ok -eq $true -and
            [bool]$receipt.trace_row_canary.oracle_mutation_rejected -eq $true -and
            [int]$receipt.godot_predicate_negative_control_count -eq 7 -and
            [int]$receipt.model_construction_count -eq 0 -and
            [int]$receipt.world_attempt_count -eq 0 -and
            [int]$receipt.world_build_count -eq 0 -and
            [bool]$receipt.physical_execution_authorized -eq $false -and
            [bool]$receipt.physical_acceptance_authority -eq $false
        ) "QSDK-R23D3 Godot/Jolt receipt mismatch: $label"
        $expectedAfter = 2992 - [int]$onset.Value - 1200 - 600
        Assert-QsdkR23d3Exact (
            [int]$receipt.segment_counts.reference_warmup -eq [int]$onset.Value -and
            [int]$receipt.segment_counts.commanded_turn -eq 1200 -and
            [int]$receipt.segment_counts.reference_recovery -eq 600 -and
            [int]$receipt.segment_counts.after_declared_schedule -eq $expectedAfter -and
            [int]$receipt.entrypoint_preflight.actual_world_build_count -eq 0 -and
            [bool]$receipt.entrypoint_preflight.candidate_authority_horizon_enabled -eq
                $true -and
            [int]$receipt.entrypoint_preflight.candidate_authority_observation_count -eq
                2992 -and
            [bool]$receipt.entrypoint_preflight.sdk_physical_trace_enabled -eq $true
        ) "QSDK-R23D3 Godot/Jolt horizon/segment mismatch: $label"
        $identityCount += 1
        $horizonProofCount += 1
        $traceCanaryCount += 1
        $predicateControlCount += 7
    }
}

$stageA = Invoke-QsdkR23d3GodotJolt -Label "stage-a-refusal" -UserArguments @(
    "--stage", "mujoco_onset_screen",
    "--onset", "onset_600",
    "--arm", "positive_heading",
    "--preflight-only"
)
Assert-QsdkR23d3CleanGodotExecution $stageA
$stageAFailure = Get-QsdkR23d3MarkerReceipt $stageA $failurePrefix
Assert-QsdkR23d3Exact (
    [int]$stageA.exit_code -ne 0 -and
    [string]$stageAFailure.failure_code -ceq "QSDK_R23D3_GJT_CELL_IDENTITY_INVALID" -and
    [int]$stageAFailure.world_attempt_count -eq 0 -and
    [int]$stageAFailure.world_build_count -eq 0
) "QSDK-R23D3 Godot/Jolt Stage-A misuse did not fail before world"

$bypass = Invoke-QsdkR23d3GodotJolt -Label "physical-bypass" -UserArguments @(
    "--stage", "three_engine_confirmation",
    "--onset", "onset_600",
    "--arm", "reference_zero",
    "--source-commit", ("0" * 40)
)
Assert-QsdkR23d3CleanGodotExecution $bypass
$bypassFailure = Get-QsdkR23d3MarkerReceipt $bypass $failurePrefix
Assert-QsdkR23d3Exact (
    [int]$bypass.exit_code -ne 0 -and
    [string]$bypassFailure.failure_stage -ceq "before_world" -and
    [string]$bypassFailure.failure_code -ceq
        "QSDK_R23D3_GJT_CLOSED" -and
    [int]$bypassFailure.world_attempt_count -eq 0 -and
    [int]$bypassFailure.world_build_count -eq 0
) "QSDK-R23D3 Godot/Jolt direct physical bypass did not fail before world"

Assert-QsdkR23d3Exact (
    $identityCount -eq 12 -and
    $horizonProofCount -eq 12 -and
    $traceCanaryCount -eq 12 -and
    $predicateControlCount -eq 84
) "QSDK-R23D3 Godot/Jolt aggregate preflight counts are invalid"

Write-Output (
    "QSDK_R23D3_GODOT_JOLT_WORKER_PASS " +
    "identities=$identityCount fixed_horizon_proofs=$horizonProofCount " +
    "trace_row_canaries=$traceCanaryCount " +
    "godot_predicate_controls=$predicateControlCount " +
    "negative_controls=2 worlds=0 physical_authority=False"
)
