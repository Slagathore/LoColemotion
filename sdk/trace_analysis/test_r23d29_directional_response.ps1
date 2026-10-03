#requires -Version 7.0

# Focused zero-world response-measurement diagnosis over immutable R23D29 CAS traces.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$contractPath = Join-Path $PSScriptRoot "retained_trace_lineage_contract_v1.json"
$manifestPath = Join-Path $PSScriptRoot (
    "r23d29_directional_response_analysis_manifest_v1.json"
)
$analyzerPath = Join-Path $PSScriptRoot "analyze_retained_trace_lineage.py"
$evidenceRoot = Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"

function Assert-R23D29Directional([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D29_DIRECTIONAL_RESPONSE: $Message" }
}

function Assert-R23D29Close(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D29Directional ([Math]::Abs($Actual - $Expected) -le $Tolerance) (
        "$Message actual=$Actual expected=$Expected tolerance=$Tolerance"
    )
}

function Get-R23D29GitBlobSha256([string]$Commit, [string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D29Directional $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D29Directional ($process.ExitCode -eq 0) (
            "Git blob read failed for ${RelativePath}: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Invoke-R23D29DirectionalAnalyzer(
    [string]$Python,
    [string]$InputManifest,
    [string]$OutputPath
) {
    $output = & $Python $analyzerPath `
        --manifest $InputManifest `
        --evidence-root $evidenceRoot `
        --analyzer-source-commit ((git -C $repoRoot rev-parse HEAD).Trim()) `
        --output $OutputPath 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    return [ordered]@{ output = $output; exit_code = $exitCode }
}

Assert-R23D29Directional (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @($contractPath, $manifestPath, $analyzerPath, $evidenceRoot)) {
    Assert-R23D29Directional (Test-Path -LiteralPath $path) "missing path: $path"
}

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$boundary = $contract.directional_response_measurement_diagnosis_boundary
$sourceClosure = $manifest.source_closure
$projection = $manifest.trace_contract.directional_response_measurement
$closureCommit = [string]$sourceClosure.source_commit
$closureRelative = [string]$sourceClosure.path
Assert-R23D29Directional (
    [string]$contract.schema_version -ceq
        "sporespore_retained_trace_lineage_contract_v1" -and
    [bool]$boundary.frozen_single_endpoint_must_be_replayed_as_the_one_step_window -and
    [bool]$boundary.whole_swing_terminal_windows_through_one_complete_scheduler_cycle_must_be_reported_simultaneously -and
    [bool]$boundary.trajectory_baseline_must_use_one_complete_precommand_scheduler_cycle -and
    [bool]$boundary.transient_threshold_crossing_cannot_change_a_frozen_endpoint_verdict -and
    [bool]$boundary.postclosure_window_results_cannot_select_a_successor_estimator_or_controller -and
    [string]$manifest.analysis_id -ceq
        "QSDK-R23D29-DIRECTIONAL-RESPONSE-MEASUREMENT-D1" -and
    [string]$manifest.question_class -ceq "postclosure_development_diagnosis" -and
    [bool]$manifest.data_exposure_boundary.r23d29_outcomes_already_observed -and
    [bool]$manifest.data_exposure_boundary.frozen_endpoint_verdict_remains_negative -and
    -not [bool]$manifest.data_exposure_boundary.future_terminal_estimator_selected_by_this_analysis -and
    -not [bool]$manifest.data_exposure_boundary.future_controller_change_selected_by_this_analysis -and
    [bool]$projection.enabled -and
    [int]$projection.scheduler_swing_steps -eq 72 -and
    [int]$projection.scheduler_cycle_steps -eq 360 -and
    (@($projection.terminal_mean_window_steps) -join ',') -ceq
        "1,72,144,216,288,360" -and
    [int]$projection.trajectory_baseline_window_steps -eq 360 -and
    [int]$projection.expected_steering_sign_by_command_sign.'1' -eq -1 -and
    [int]$projection.expected_steering_sign_by_command_sign.'-1' -eq 1 -and
    [double]$manifest.replayed_thresholds.minimum_command_conditioned_yaw_separation_rad -eq 0.01 -and
    @($manifest.cells).Count -eq 3 -and
    (git -C $repoRoot rev-parse "${closureCommit}:${closureRelative}").Trim() -ceq
        [string]$sourceClosure.git_blob_oid -and
    (Get-R23D29GitBlobSha256 $closureCommit $closureRelative) -ceq
        [string]$sourceClosure.raw_sha256
) "contract, manifest, or immutable closure binding changed"

foreach ($cell in $manifest.cells) {
    $digest = [string]$cell.trace_sha256
    $payload = Join-Path $evidenceRoot (
        "artifacts\sha256\" + $digest.Substring(7) + "\payload.bin"
    )
    Assert-R23D29Directional (
        $digest -match '^sha256:[0-9a-f]{64}$' -and
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq [long]$cell.trace_byte_length -and
        ("sha256:" + (
            Get-FileHash -LiteralPath $payload -Algorithm SHA256
        ).Hash.ToLowerInvariant()) -ceq $digest
    ) "CAS trace identity changed for $($cell.cell_id)"
}

$pythonMatches = @(Get-Command python.exe -CommandType Application -ErrorAction Stop)
Assert-R23D29Directional ($pythonMatches.Count -ge 1) "python.exe unavailable"
$python = [IO.Path]::GetFullPath([string]$pythonMatches[0].Source)
$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "sporespore-r23d29-directional-" + [guid]::NewGuid().ToString("N")
)
$resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$resolvedTest = [IO.Path]::GetFullPath($testRoot)
Assert-R23D29Directional (
    $resolvedTest.StartsWith(
        $resolvedTemp + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Split-Path -Leaf $resolvedTest).StartsWith(
        "sporespore-r23d29-directional-",
        [StringComparison]::Ordinal
    )
) "temporary mutation root escaped the system temp directory"
[void][IO.Directory]::CreateDirectory($resolvedTest)

try {
    $reportPath = Join-Path $resolvedTest "report.json"
    $run = Invoke-R23D29DirectionalAnalyzer $python $manifestPath $reportPath
    Assert-R23D29Directional ($run.exit_code -eq 0) (
        "real CAS analysis failed: $($run.output)"
    )
    $prefix = "RETAINED_TRACE_LINEAGE_PASS "
    $markers = @(($run.output -split '\r?\n') | Where-Object {
        $_.StartsWith($prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D29Directional ($markers.Count -eq 1) "analysis marker count changed"
    $report = $markers[0].Substring($prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
    $comparison = $report.comparisons[0]
    $measurement = $comparison.directional_response_measurement
    $positive = $measurement.response_trajectories.positive_heading
    $negative = $measurement.response_trajectories.negative_heading
    $positiveDelivery = $measurement.command_delivery.positive_heading
    $negativeDelivery = $measurement.command_delivery.negative_heading

    Assert-R23D29Directional (
        [string]$report.schema_version -ceq
            "sporespore_retained_trace_lineage_report_v1" -and
        [int]$report.input_summary.cell_count -eq 3 -and
        [long]$report.input_summary.total_trace_byte_length -eq 36479155 -and
        [int]$report.input_summary.total_trace_row_count -eq 8976 -and
        (@($measurement.windows | ForEach-Object { [int]$_.window_steps }) -join ',') -ceq
            "1,72,144,216,288,360" -and
        (@($measurement.windows | ForEach-Object { [bool]$_.both_thresholds_met }) -join ',') -ceq
            "False,False,False,False,True,True" -and
        [int]$positive.first_threshold_met_step -eq 1249 -and
        [int]$positive.peak_conditioned_response_step -eq 1719 -and
        [int]$positive.threshold_met_row_count -eq 454 -and
        [int]$positive.threshold_met_episode_count -eq 3 -and
        [int]$negative.first_threshold_met_step -eq 1070 -and
        [int]$negative.peak_conditioned_response_step -eq 1555 -and
        [int]$negative.threshold_met_row_count -eq 424 -and
        [int]$negative.threshold_met_episode_count -eq 4 -and
        [int]$positiveDelivery.requested_sign_consistent_row_count -eq 1200 -and
        [int]$positiveDelivery.held_sign_consistent_row_count -eq 1199 -and
        [int]$positiveDelivery.guard_floor_hold_trigger_row_count -eq 66 -and
        [int]$positiveDelivery.guard_floor_hold_active_row_count -eq 635 -and
        [int]$positiveDelivery.steering_saturation_row_count -eq 642 -and
        [int]$negativeDelivery.requested_sign_consistent_row_count -eq 1200 -and
        [int]$negativeDelivery.held_sign_consistent_row_count -eq 1200 -and
        [int]$negativeDelivery.guard_floor_hold_trigger_row_count -eq 112 -and
        [int]$negativeDelivery.guard_floor_hold_active_row_count -eq 820 -and
        [int]$negativeDelivery.steering_saturation_row_count -eq 831 -and
        [bool]$measurement.direct_observations.both_commanded_arms_reached_threshold_during_phase -and
        [bool]$measurement.direct_observations.both_commanded_arms_requested_sign_consistent_every_row -and
        -not [bool]$measurement.direct_observations.frozen_endpoint_both_thresholds_met -and
        [bool]$measurement.direct_observations.full_cycle_terminal_mean_both_thresholds_met -and
        [bool]$measurement.direct_observations.negative_arm_reached_threshold_then_ended_below -and
        $null -eq $measurement.terminal_estimator_selected_for_successor -and
        $null -eq $measurement.controller_change_selected -and
        -not [bool]$measurement.closed_endpoint_verdict_changed -and
        -not [bool]$measurement.counterfactual_physical_outcome_claimed -and
        [int]$report.model_construction_count -eq 0 -and
        [int]$report.world_attempt_count -eq 0 -and
        [int]$report.world_build_count -eq 0 -and
        -not [bool]$report.turning_validation -and
        -not [bool]$report.physical_acceptance_authority
    ) "directional-response projection or claim boundary changed"

    Assert-R23D29Close `
        ([double]$comparison.positive_reference_conditioned_yaw_delta_rad) `
        0.015467562771277548 1.0e-15 "frozen positive endpoint changed"
    Assert-R23D29Close `
        ([double]$comparison.negative_reference_conditioned_yaw_delta_rad) `
        0.00029444164763040275 1.0e-15 "frozen negative endpoint changed"
    Assert-R23D29Close `
        ([double]$positive.peak_conditioned_response_rad) `
        0.04020062811303697 1.0e-15 "positive response peak changed"
    Assert-R23D29Close `
        ([double]$negative.peak_conditioned_response_rad) `
        0.039542539075027736 1.0e-15 "negative response peak changed"
    Assert-R23D29Close `
        ([double]$negative.peak_to_endpoint_regression_rad) `
        0.039248097427397335 1.0e-15 "negative response regression changed"
    Assert-R23D29Close `
        ([double]$measurement.windows[-1].positive_reference_conditioned_mean_yaw_shift_rad) `
        0.014151062658812923 1.0e-15 "full-cycle positive mean changed"
    Assert-R23D29Close `
        ([double]$measurement.windows[-1].negative_reference_conditioned_mean_yaw_shift_rad) `
        0.016851528700347392 1.0e-15 "full-cycle negative mean changed"

    $mutations = @(
        [ordered]@{
            name = "window_grid"
            expected = "TRACE_LINEAGE_DIRECTIONAL_RESPONSE_WINDOWS"
            mutate = { param($copy)
                $copy.trace_contract.directional_response_measurement.
                    terminal_mean_window_steps = @(1, 72, 144, 216, 288)
            }
        },
        [ordered]@{
            name = "trajectory_baseline"
            expected = "TRACE_LINEAGE_DIRECTIONAL_RESPONSE_TRAJECTORY_BASELINE"
            mutate = { param($copy)
                $copy.trace_contract.directional_response_measurement.
                    trajectory_baseline_window_steps = 288
            }
        },
        [ordered]@{
            name = "guard_mode"
            expected = "TRACE_LINEAGE_DIRECTIONAL_RESPONSE_GUARD_IDENTITY"
            mutate = { param($copy)
                $copy.trace_contract.directional_response_measurement.
                    required_guard_mode_id = "mutated_guard"
            }
        },
        [ordered]@{
            name = "missing_cas"
            expected = "TRACE_LINEAGE_CAS_OBJECT_MISSING"
            mutate = { param($copy)
                $copy.cells[0].trace_sha256 = "sha256:" + ("0" * 64)
            }
        },
        [ordered]@{
            name = "claim_escalation"
            expected = "TRACE_LINEAGE_CLAIM_LIMITS"
            mutate = { param($copy)
                $copy.claim_limits.turning_validation = $true
            }
        }
    )
    foreach ($mutation in $mutations) {
        $copy = Get-Content -LiteralPath $manifestPath -Raw |
            ConvertFrom-Json -AsHashtable -Depth 100
        & $mutation.mutate $copy
        $mutatedPath = Join-Path $resolvedTest "$($mutation.name).json"
        [IO.File]::WriteAllText(
            $mutatedPath,
            ($copy | ConvertTo-Json -Depth 100) + "`n",
            [Text.UTF8Encoding]::new($false)
        )
        $mutatedOutput = Join-Path $resolvedTest "$($mutation.name)-report.json"
        $mutatedRun = Invoke-R23D29DirectionalAnalyzer `
            $python $mutatedPath $mutatedOutput
        Assert-R23D29Directional (
            $mutatedRun.exit_code -ne 0 -and
            $mutatedRun.output.Contains([string]$mutation.expected)
        ) "mutation did not fail closed: $($mutation.name): $($mutatedRun.output)"
    }

    $rerun = Invoke-R23D29DirectionalAnalyzer $python $manifestPath $reportPath
    Assert-R23D29Directional (
        $rerun.exit_code -ne 0 -and
        $rerun.output.Contains("TRACE_LINEAGE_OUTPUT_EXISTS")
    ) "create-only output refusal changed"
} finally {
    if (Test-Path -LiteralPath $resolvedTest) {
        $rechecked = [IO.Path]::GetFullPath($resolvedTest)
        Assert-R23D29Directional (
            $rechecked.StartsWith(
                $resolvedTemp + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Split-Path -Leaf $rechecked).StartsWith(
                "sporespore-r23d29-directional-",
                [StringComparison]::Ordinal
            )
        ) "refusing unsafe temporary cleanup"
        Remove-Item -LiteralPath $rechecked -Recurse -Force
    }
}

Write-Host (
    "R23D29_DIRECTIONAL_RESPONSE_PASS cells=3 rows=8976 windows=6 " +
    "endpoint_bilateral=False full_cycle_bilateral=True " +
    "positive_peak=0.04020062811303697 negative_peak=0.039542539075027736 " +
    "negative_endpoint=0.00029444164763040275 requested_sign_rows=2400/2400 " +
    "mutations=5 models=0 worlds=0 selection=False turning=False physical=False"
)
