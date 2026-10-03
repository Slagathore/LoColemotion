#requires -Version 7.0

# Zero-world diagnosis over immutable R48/R52 Godot/Jolt CAS traces.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$manifestPath = Join-Path $PSScriptRoot (
    "r23d52_godot_origin_timing_analysis_manifest_v1.json"
)
$analyzerPath = Join-Path $PSScriptRoot "analyze_r23d52_godot_origin_timing.py"
$evidenceRoot = Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"

function Assert-R23D52OriginTiming([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D52_ORIGIN_TIMING: $Message" }
}

function Assert-R23D52Near(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D52OriginTiming ([Math]::Abs($Actual - $Expected) -le $Tolerance) (
        "$Message actual=$Actual expected=$Expected tolerance=$Tolerance"
    )
}

function Get-GitBlobSha256([string]$Commit, [string]$RelativePath) {
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
        Assert-R23D52OriginTiming $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D52OriginTiming ($process.ExitCode -eq 0) (
            "Git blob read failed for ${RelativePath}: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Invoke-OriginTimingAnalyzer(
    [string]$Python,
    [string]$InputManifest,
    [string]$OutputPath
) {
    $output = & $Python $analyzerPath `
        --manifest $InputManifest `
        --evidence-root $evidenceRoot `
        --output $OutputPath 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    return [ordered]@{ output = $output; exit_code = $exitCode }
}

Assert-R23D52OriginTiming (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @($manifestPath, $analyzerPath, $evidenceRoot)) {
    Assert-R23D52OriginTiming (Test-Path -LiteralPath $path) "missing path: $path"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D52OriginTiming (
    [string]$manifest.schema_version -ceq
        "sporespore_r23d52_godot_origin_timing_analysis_manifest_v1" -and
    [string]$manifest.analysis_id -ceq
        "QSDK-R23D52-GODOT-ORIGIN-TIMING-D1" -and
    [string]$manifest.status -ceq
        "postclosure_outcome_exposed_descriptive_diagnosis" -and
    [bool]$manifest.data_exposure_boundary.r23d48_and_r23d52_outcomes_already_observed -and
    [bool]$manifest.data_exposure_boundary.projection_is_descriptive_not_confirmatory -and
    [bool]$manifest.data_exposure_boundary.r23d48_verdict_unchanged -and
    [bool]$manifest.data_exposure_boundary.r23d52_verdict_unchanged -and
    [bool]$manifest.data_exposure_boundary.r23d52_exact_policy_rejected -and
    -not [bool]$manifest.data_exposure_boundary.future_successor_physical_outcome_known -and
    @($manifest.source_closures).Count -eq 2 -and
    @($manifest.pairs).Count -eq 3 -and
    [int]$manifest.trace_contract.expected_trace_row_count -eq 2992 -and
    [int]$manifest.trace_contract.turn_start_semantic_step -eq 600 -and
    [int]$manifest.trace_contract.turn_end_semantic_step_exclusive -eq 1800 -and
    [int]$manifest.trace_contract.gait_cycle_steps -eq 360 -and
    (@($manifest.trace_contract.r23d52_expected_reanchor_steps) -join ',') -ceq
        "0,600,1800,2400" -and
    [string]$manifest.successor_constraint.supported_mechanism_question -ceq
        "warmup_preserving_command_onset_origin_reanchor" -and
    [int]$manifest.successor_constraint.fixed_initial_origin_required_through_semantic_step -eq 599 -and
    [int]$manifest.successor_constraint.earliest_permitted_reanchor_semantic_step -eq 600 -and
    [bool]$manifest.successor_constraint.fresh_held_out_validation_required_after_selection -and
    -not [bool]$manifest.successor_constraint.engine_identity_branch_permitted -and
    -not [bool]$manifest.successor_constraint.arm_identity_branch_permitted -and
    @($manifest.claim_limits.Values | Where-Object { [bool]$_ }).Count -eq 0
) "manifest boundary changed"

foreach ($closure in $manifest.source_closures) {
    $commit = [string]$closure.addition_commit
    $relativePath = [string]$closure.path
    Assert-R23D52OriginTiming (
        (git -C $repoRoot rev-parse "${commit}:${relativePath}").Trim() -ceq
            [string]$closure.git_blob_oid -and
        (Get-GitBlobSha256 $commit $relativePath) -ceq
            [string]$closure.raw_sha256
    ) "immutable closure binding changed: $relativePath"
}

foreach ($pair in $manifest.pairs) {
    foreach ($lineage in @("r23d48", "r23d52")) {
        $binding = $pair[$lineage]
        $digest = [string]$binding.trace_sha256
        $payload = Join-Path $evidenceRoot (
            "artifacts\sha256\" + $digest.Substring(7) + "\payload.bin"
        )
        Assert-R23D52OriginTiming (
            $digest -match '^sha256:[0-9a-f]{64}$' -and
            (Test-Path -LiteralPath $payload -PathType Leaf) -and
            (Get-Item -LiteralPath $payload).Length -eq
                [long]$binding.trace_byte_length -and
            ("sha256:" + (
                Get-FileHash -LiteralPath $payload -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -ceq $digest
        ) "CAS trace identity changed: $($binding.cell_id)"
    }
}

$pythonMatches = @(Get-Command python.exe -CommandType Application -ErrorAction Stop)
Assert-R23D52OriginTiming ($pythonMatches.Count -ge 1) "python.exe unavailable"
$python = [IO.Path]::GetFullPath([string]$pythonMatches[0].Source)
$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "sporespore-r23d52-origin-timing-" + [guid]::NewGuid().ToString("N")
)
$resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$resolvedTest = [IO.Path]::GetFullPath($testRoot)
Assert-R23D52OriginTiming (
    $resolvedTest.StartsWith(
        $resolvedTemp + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Split-Path -Leaf $resolvedTest).StartsWith(
        "sporespore-r23d52-origin-timing-",
        [StringComparison]::Ordinal
    )
) "temporary test root escaped system temp"
[void][IO.Directory]::CreateDirectory($resolvedTest)

try {
    $reportPath = Join-Path $resolvedTest "report.json"
    $run = Invoke-OriginTimingAnalyzer $python $manifestPath $reportPath
    Assert-R23D52OriginTiming ($run.exit_code -eq 0) (
        "real retained-trace diagnosis failed: $($run.output)"
    )
    $markers = @(($run.output -split '\r?\n') | Where-Object {
        $_.StartsWith(
            "R23D52_ORIGIN_TIMING_DIAGNOSIS_PASS ",
            [StringComparison]::Ordinal
        )
    })
    Assert-R23D52OriginTiming ($markers.Count -eq 1) "success marker count changed"
    $report = Get-Content -LiteralPath $reportPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    $findings = $report.aggregate_findings
    Assert-R23D52OriginTiming (
        [string]$report.schema_version -ceq
            "sporespore_r23d52_godot_origin_timing_analysis_report_v1" -and
        [string]$report.analysis_id -ceq
            "QSDK-R23D52-GODOT-ORIGIN-TIMING-D1" -and
        [int]$report.source_trace_count -eq 6 -and
        [int]$report.source_trace_row_count -eq 17952 -and
        @($report.pairs).Count -eq 3 -and
        [bool]$findings.all_step_zero_physical_observations_equal -and
        [bool]$findings.all_pairs_controller_changed_at_step_zero -and
        [bool]$findings.all_r23d52_initial_segments_reanchored -and
        -not [bool]$findings.warmup_trajectory_isolated_from_origin_policy -and
        [bool]$findings.both_commanded_arms_first_cycle_direction_correct -and
        [bool]$findings.both_commanded_arms_later_cycles_reverse_direction -and
        [bool]$findings.negative_arm_requested_sign_consistent_every_turn_row -and
        [bool]$findings.r52_exact_policy_rejected_by_closed_result -and
        -not [bool]$findings.turn_onset_only_reanchor_result_observed -and
        [int]$report.model_construction_count -eq 0 -and
        [int]$report.world_attempt_count -eq 0 -and
        [int]$report.world_build_count -eq 0 -and
        -not [bool]$report.historical_result_reinterpreted -and
        -not [bool]$report.physical_execution_authorized -and
        -not [bool]$report.physical_acceptance_authority
    ) "report boundary changed"

    $byArm = @{}
    foreach ($pair in $report.pairs) { $byArm[[string]$pair.arm_id] = $pair }
    foreach ($arm in @("reference_zero", "positive_heading", "negative_heading")) {
        $pair = $byArm[$arm]
        Assert-R23D52OriginTiming (
            [int]$pair.first_controller_projection_difference_step -eq 0 -and
            [int]$pair.first_torso_position_difference_step -eq 5 -and
            [int]$pair.first_measured_yaw_difference_step -eq 14 -and
            (@($pair.r23d52_reanchor_steps) -join ',') -ceq "0,600,1800,2400"
        ) "same-seed divergence boundary changed: $arm"
        Assert-R23D52Near (
            [double]$pair.r48_step_zero_cross_track_error_m
        ) 0.00002473049687269 1.0e-15 "R48 step-zero cross-track changed: $arm"
        Assert-R23D52Near (
            [double]$pair.r52_step_zero_cross_track_error_m
        ) 0.0 1.0e-15 "R52 step-zero cross-track changed: $arm"
    }
    $positive = $byArm.positive_heading
    $negative = $byArm.negative_heading
    Assert-R23D52OriginTiming (
        [int]$negative.r23d52_requested_expected_sign_row_count -eq 1200 -and
        [int]$negative.r23d52_turn_command_row_count -eq 1200 -and
        [bool]$positive.r23d52_first_cycle_command_direction_correct -and
        [bool]$negative.r23d52_first_cycle_command_direction_correct -and
        [bool]$positive.r23d52_later_cycles_both_command_direction_wrong -and
        [bool]$negative.r23d52_later_cycles_both_command_direction_wrong
    ) "commanded-cycle mechanism changed"

    $mutated = $manifest.Clone()
    $mutated.pairs = @($manifest.pairs | ForEach-Object { $_.Clone() })
    $mutated.pairs[0].r23d52 = $manifest.pairs[0].r23d52.Clone()
    $mutated.pairs[0].r23d52.trace_sha256 = (
        $manifest.pairs[1].r23d52.trace_sha256
    )
    $mutated.pairs[0].r23d52.trace_byte_length = (
        $manifest.pairs[1].r23d52.trace_byte_length
    )
    $wrongCellPath = Join-Path $resolvedTest "wrong-cell.json"
    $mutated | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $wrongCellPath
    $wrongCell = Invoke-OriginTimingAnalyzer $python $wrongCellPath (
        Join-Path $resolvedTest "wrong-cell-report.json"
    )
    Assert-R23D52OriginTiming (
        $wrongCell.exit_code -ne 0 -and
        $wrongCell.output.Contains("R23D52_ORIGIN_TIMING_TRACE_IDENTITY")
    ) "wrong-cell mutation survived"

    $wrongSchedule = $manifest.Clone()
    $wrongSchedule.trace_contract = $manifest.trace_contract.Clone()
    $wrongSchedule.trace_contract.turn_start_semantic_step = 601
    $wrongSchedulePath = Join-Path $resolvedTest "wrong-schedule.json"
    $wrongSchedule | ConvertTo-Json -Depth 100 |
        Set-Content -LiteralPath $wrongSchedulePath
    $wrongScheduleRun = Invoke-OriginTimingAnalyzer $python $wrongSchedulePath (
        Join-Path $resolvedTest "wrong-schedule-report.json"
    )
    Assert-R23D52OriginTiming (
        $wrongScheduleRun.exit_code -ne 0 -and
        $wrongScheduleRun.output.Contains("R23D52_ORIGIN_TIMING_INHERITED_SCHEDULE")
    ) "turn-window mutation survived"
} finally {
    if (Test-Path -LiteralPath $resolvedTest) {
        Remove-Item -LiteralPath $resolvedTest -Recurse -Force
    }
}

Write-Host (
    "R23D52_ORIGIN_TIMING_TEST_PASS traces=6 rows=17952 controller_step=0 " +
    "position_step=5 yaw_step=14 warmup_isolated=False first_cycle_correct=True " +
    "later_cycles_reverse=True models=0 worlds=0 turning=False physical=False"
)
