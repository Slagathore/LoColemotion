#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python",
    [string]$HistoricalGodotTrace = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d60-physical-20260816T000359Z\traces\" +
        "godot_jolt__s21516__portable_hip__fixture_knee__reference_zero.ndjson"
    ),
    [switch]$RequireHistoricalGodotTrace
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

function Assert-R23D64EvaluatorV2([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D64 evaluator-v2 audit failed: $Message"
    }
}

function Resolve-R23D64EvaluatorV2Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D64EvaluatorV2 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application missing: $resolved"
        )
        return $resolved
    }
    return [IO.Path]::GetFullPath([string](
        Get-Command $Command -CommandType Application -ErrorAction Stop |
            Select-Object -First 1 -ExpandProperty Source
    ))
}

function Invoke-R23D64EvaluatorV2Process(
    [string]$FileName,
    [string[]]$Arguments,
    [hashtable]$Environment
) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit(300000)
    if ($timedOut) {
        try { $process.Kill($true) } catch {}
        [void]$process.WaitForExit(10000)
    } else {
        $process.WaitForExit()
    }
    $result = [ordered]@{
        exit_code = if ($timedOut) { 124 } else { $process.ExitCode }
        timed_out = $timedOut
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
    $process.Dispose()
    return $result
}

function Get-R23D64EvaluatorV2Marker([string]$Text, [string]$Prefix) {
    $matches = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D64EvaluatorV2 ($matches.Count -eq 1) (
        "expected one $Prefix marker, observed $($matches.Count)"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$turningRoot = Join-Path $repoRoot "sdk\turning"
$evaluatorPath = Join-Path $turningRoot (
    "r23d64_selected_profile_three_engine_turning_validation_evaluator_v2.py"
)
$rejectionPath = Join-Path $turningRoot (
    "r23d64_evaluator_v1_zero_world_rejection_v1.json"
)
$legacyEvaluatorPath = Join-Path $turningRoot (
    "r23d64_selected_profile_three_engine_turning_validation_evaluator.py"
)
$legacyGatePath = Join-Path $PSScriptRoot "test_qsdk_r23d64_evaluator.ps1"
$legacyEvaluatorSha256 = (
    "f79d1c988a5ebfbc810e048957fbdd4cc96d30b15d4591a2be6bbe4f23befa7a"
)
$legacyGateSha256 = (
    "426d4f64a2f23524f49747060c21b615a68fa37ec7404d8d3f7a2f65f94d2ecf"
)
$historicalTraceSha256 = (
    "sha256:5a90a4b11d9cab5f49513752a0cd2beb3da7346672db3f0747a1b071cab3ccbc"
)

Assert-R23D64EvaluatorV2 ($repoRoot.TrimEnd("\") -ceq $expectedRoot) (
    "repository root changed"
)
Assert-R23D64EvaluatorV2 (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $expectedRoot
) "Git top-level changed"
Assert-R23D64EvaluatorV2 (
    (& git -C $repoRoot remote get-url origin).Trim() -ceq $expectedRemote
) "origin remote changed"
foreach ($path in @(
    $evaluatorPath,
    $rejectionPath,
    $legacyEvaluatorPath,
    $legacyGatePath
)) {
    Assert-R23D64EvaluatorV2 (Test-Path -LiteralPath $path -PathType Leaf) (
        "required source missing: $path"
    )
}
Assert-R23D64EvaluatorV2 (
    (Get-FileHash -Algorithm SHA256 -LiteralPath $legacyEvaluatorPath).Hash.ToLowerInvariant() `
        -ceq $legacyEvaluatorSha256
) "rejected evaluator bytes changed"
Assert-R23D64EvaluatorV2 (
    (Get-FileHash -Algorithm SHA256 -LiteralPath $legacyGatePath).Hash.ToLowerInvariant() `
        -ceq $legacyGateSha256
) "rejected evaluator gate bytes changed"

$rejection = Get-Content -Raw -LiteralPath $rejectionPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D64EvaluatorV2 (
    [string]$rejection.status -ceq
        "rejected_before_physical_qualification_or_world_opening" -and
    [string]$rejection.rejected_implementation.raw_sha256 -ceq
        "sha256:$legacyEvaluatorSha256" -and
    [string]$rejection.rejected_implementation.zero_world_gate_raw_sha256 -ceq
        "sha256:$legacyGateSha256" -and
    @($rejection.rejected_implementation.observed_failure_codes).Count -eq 1 -and
    [string]$rejection.rejected_implementation.observed_failure_codes[0] -ceq
        "R23D64_TRACE_CAP_ORDER_INVALID:0" -and
    -not [bool]$rejection.claims.r23d64_complete_zero_world_gate_passed -and
    -not [bool]$rejection.claims.r23d64_physical_campaign_opened -and
    -not [bool]$rejection.claims.r23d64_seed_consumed -and
    -not [bool]$rejection.claims.q_sdk_r23_satisfied
) "rejected evaluator record changed"

$pythonHost = Resolve-R23D64EvaluatorV2Application $Python
$pythonPath = @(
    (Join-Path $repoRoot "sdk\python"),
    $turningRoot
) -join [IO.Path]::PathSeparator
$result = Invoke-R23D64EvaluatorV2Process -FileName $pythonHost `
    -Arguments @($evaluatorPath, "preflight") `
    -Environment @{ "PYTHONPATH" = $pythonPath }
Assert-R23D64EvaluatorV2 (
    [int]$result.exit_code -eq 0 -and -not [bool]$result.timed_out
) "evaluator-v2 preflight failed: $($result.stderr) $($result.stdout)"
$receipt = Get-R23D64EvaluatorV2Marker $result.stdout (
    "QSDK_R23D64_EVALUATOR_V2_PREFLIGHT "
)
Assert-R23D64EvaluatorV2 (
    [string]$receipt.schema_version -ceq
        "sporespore_qsdk_r23d64_evaluator_preflight_v2" -and
    [string]$receipt.evaluator_implementation_id -ceq
        "sporespore_qsdk_r23d64_retained_evidence_evaluator_v2" -and
    [int]$receipt.declared_cell_count -eq 9 -and
    [int]$receipt.valid_trace_canary_count -eq 9 -and
    [int]$receipt.task_origin_and_schedule_mutation_rejection_count -eq 30 -and
    [int]$receipt.actuator_observation_mutation_rejection_count -eq 60 -and
    [int]$receipt.public_profile_projection_mutation_rejection_count -eq 48 -and
    [int]$receipt.per_engine_trace_cap_mutation_rejection_count -eq 3 -and
    [int]$receipt.turning_decision_mutation_rejection_count -eq 8 -and
    [int]$receipt.complete_matrix_order_mutation_rejection_count -eq 9 -and
    @($receipt.public_trace_actuator_ids).Count -eq 8 -and
    [string]$receipt.public_trace_actuator_ids[0] -ceq "front_left_hip_motor" -and
    [string]$receipt.public_trace_actuator_ids[7] -ceq "rear_right_knee_motor" -and
    -not [bool]$receipt.placeholder_trace_actuator_identity_permitted -and
    [bool]$receipt.genuine_godot_trace_cold_baseline_passed -and
    [string]$receipt.genuine_godot_trace_cold_baseline_sha256 -ceq
        $historicalTraceSha256 -and
    [int]$receipt.genuine_godot_trace_cold_baseline_row_count -eq 2992 -and
    -not [bool]$receipt.historical_world_reused_as_r23d64_cell -and
    [int]$receipt.model_construction_count -eq 0 -and
    [int]$receipt.world_attempt_count -eq 0 -and
    [int]$receipt.world_build_count -eq 0 -and
    -not [bool]$receipt.physical_execution_authorized -and
    -not [bool]$receipt.physical_acceptance_authority
) "evaluator-v2 preflight receipt changed"

$coldBaselineRan = $false
if (Test-Path -LiteralPath $HistoricalGodotTrace -PathType Leaf) {
    $cold = Invoke-R23D64EvaluatorV2Process -FileName $pythonHost `
        -Arguments @(
            $evaluatorPath,
            "cold-godot-trace",
            "--trace", [IO.Path]::GetFullPath($HistoricalGodotTrace),
            "--expected-sha256", $historicalTraceSha256
        ) `
        -Environment @{ "PYTHONPATH" = $pythonPath }
    Assert-R23D64EvaluatorV2 (
        [int]$cold.exit_code -eq 0 -and -not [bool]$cold.timed_out
    ) "genuine Godot trace cold baseline failed: $($cold.stderr) $($cold.stdout)"
    $coldReceipt = Get-R23D64EvaluatorV2Marker $cold.stdout (
        "QSDK_R23D64_EVALUATOR_V2_COLD_GODOT_TRACE "
    )
    Assert-R23D64EvaluatorV2 (
        [string]$coldReceipt.trace_raw_sha256 -ceq $historicalTraceSha256 -and
        [int]$coldReceipt.trace_row_count -eq 2992 -and
        @($coldReceipt.legacy_failure_codes).Count -eq 1 -and
        [string]$coldReceipt.legacy_failure_codes[0] -ceq
            "R23D64_TRACE_CAP_ORDER_INVALID:0" -and
        @($coldReceipt.corrected_failure_codes).Count -eq 0 -and
        -not [bool]$coldReceipt.historical_result_reinterpreted -and
        -not [bool]$coldReceipt.historical_world_reused_as_r23d64_cell -and
        [int]$coldReceipt.model_construction_count -eq 0 -and
        [int]$coldReceipt.world_attempt_count -eq 0 -and
        [int]$coldReceipt.world_build_count -eq 0
    ) "genuine Godot trace cold-baseline receipt changed"
    $coldBaselineRan = $true
} elseif ($RequireHistoricalGodotTrace) {
    throw "QSDK-R23D64 evaluator-v2 historical trace is required but missing: $HistoricalGodotTrace"
}

Write-Output (
    "QSDK_R23D64_EVALUATOR_V2_PASS cells=9 valid_traces=9 " +
    "task_origin_mutations=30 observation_mutations=60 " +
    "profile_mapping_mutations=48 trace_cap_mutations=3 " +
    "decision_mutations=8 order_mutations=9 public_actuator_ids=8 " +
    "genuine_godot_trace_cold_baseline=$coldBaselineRan models=0 worlds=0 " +
    "physical=False equivalence=False"
)
