#requires -Version 7.0

[CmdletBinding()]
param([string]$Python = "python")

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

function Assert-R23D64Evaluator([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D64 evaluator audit failed: $Message"
    }
}

function Resolve-R23D64EvaluatorApplication([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D64Evaluator (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application missing: $resolved"
        )
        return $resolved
    }
    return [IO.Path]::GetFullPath([string](
        Get-Command $Command -CommandType Application -ErrorAction Stop |
            Select-Object -First 1 -ExpandProperty Source
    ))
}

function Invoke-R23D64EvaluatorProcess(
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

function Get-R23D64EvaluatorMarker([string]$Text, [string]$Prefix) {
    $matches = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D64Evaluator ($matches.Count -eq 1) (
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
    "r23d64_selected_profile_three_engine_turning_validation_evaluator.py"
)
$declarationPath = Join-Path $turningRoot (
    "r23d64_selected_profile_three_engine_turning_validation_" +
    "preregistration_v1.json"
)

Assert-R23D64Evaluator ($repoRoot.TrimEnd("\") -ceq $expectedRoot) (
    "repository root changed"
)
Assert-R23D64Evaluator (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $expectedRoot
) "Git top-level changed"
Assert-R23D64Evaluator (
    (& git -C $repoRoot remote get-url origin).Trim() -ceq $expectedRemote
) "origin remote changed"
foreach ($path in @($evaluatorPath, $declarationPath)) {
    Assert-R23D64Evaluator (Test-Path -LiteralPath $path -PathType Leaf) (
        "required source missing: $path"
    )
}

$pythonHost = Resolve-R23D64EvaluatorApplication $Python
$pythonPath = @(
    (Join-Path $repoRoot "sdk\python"),
    $turningRoot
) -join [IO.Path]::PathSeparator
$result = Invoke-R23D64EvaluatorProcess -FileName $pythonHost `
    -Arguments @($evaluatorPath, "preflight") `
    -Environment @{ "PYTHONPATH" = $pythonPath }
Assert-R23D64Evaluator (
    [int]$result.exit_code -eq 0 -and -not [bool]$result.timed_out
) "evaluator preflight failed: $($result.stderr) $($result.stdout)"

$receipt = Get-R23D64EvaluatorMarker $result.stdout (
    "QSDK_R23D64_EVALUATOR_PREFLIGHT "
)
Assert-R23D64Evaluator (
    [string]$receipt.schema_version -ceq
        "sporespore_qsdk_r23d64_evaluator_preflight_v1" -and
    [string]$receipt.campaign_id -ceq
        "QSDK-R23D64-RAPIER-LAUNCH-CONTRACT-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION" -and
    [string]$receipt.gate_id -ceq "QSDK-R23D64" -and
    [string]$receipt.question_class -ceq "finite_decision" -and
    [int]$receipt.declared_cell_count -eq 9 -and
    [int]$receipt.engine_count -eq 3 -and
    [int]$receipt.valid_trace_canary_count -eq 9 -and
    [int]$receipt.task_origin_and_schedule_mutation_rejection_count -eq 30 -and
    [int]$receipt.actuator_observation_mutation_rejection_count -eq 60 -and
    [int]$receipt.public_profile_projection_positive_control_count -eq 3 -and
    [int]$receipt.public_profile_projection_mutation_rejection_count -eq 48 -and
    [int]$receipt.per_engine_trace_cap_mutation_rejection_count -eq 3 -and
    [int]$receipt.cycle_integrated_positive_control_count -eq 1 -and
    [int]$receipt.turning_decision_mutation_rejection_count -eq 8 -and
    [int]$receipt.complete_matrix_order_mutation_rejection_count -eq 9 -and
    [int]$receipt.observation_row_count_per_trace -eq 2992 -and
    [int]$receipt.observation_application_count_per_trace -eq 23936 -and
    [double]$receipt.minimum_raw_signed_cycle_shift_rad -eq 0.01 -and
    [double]$receipt.minimum_reference_conditioned_cycle_shift_rad -eq 0.01 -and
    [bool]$receipt.turning_gate_invoked -and
    -not [bool]$receipt.superiority_test_invoked -and
    -not [bool]$receipt.equivalence_or_non_inferiority_test_invoked -and
    -not [bool]$receipt.population_inference_attempted -and
    [int]$receipt.model_construction_count -eq 0 -and
    [int]$receipt.world_attempt_count -eq 0 -and
    [int]$receipt.world_build_count -eq 0 -and
    -not [bool]$receipt.physical_execution_authorized -and
    -not [bool]$receipt.physical_acceptance_authority
) "evaluator preflight receipt changed"

$source = Get-Content -Raw -LiteralPath $evaluatorPath
Assert-R23D64Evaluator (
    $source.Contains("strict_nine_cell_conjunction_used") -and
    $source.Contains('"cross_engine_equivalence": False') -and
    $source.Contains("cross_engine_equivalence_test_invoked") -and
    $source.Contains("actuator_cap_profile_physical_binding_receipt") -and
    $source.Contains("completed_before_first_solver_step") -and
    $source.Contains("TRACE_TRANSPORT_ID")
) "evaluator source boundary changed"

Write-Output (
    "QSDK_R23D64_EVALUATOR_PASS cells=9 engines=3 valid_traces=9 " +
    "task_origin_mutations=30 observation_mutations=60 " +
    "profile_mapping_mutations=48 trace_cap_mutations=3 " +
    "decision_mutations=8 order_mutations=9 applications_per_trace=23936 " +
    "models=0 worlds=0 physical=False equivalence=False"
)
