#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$manifestPath = Join-Path $PSScriptRoot "r23d53_godot_command_contrast_analysis_manifest_v1.json"
$analyzerPath = Join-Path $PSScriptRoot "analyze_r23d53_godot_command_contrast.py"
$evidenceRoot = Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"

function Assert-R23D53Contrast([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D53_COMMAND_CONTRAST_TEST: $Message" }
}

function Get-GitBlobSha256([string]$Commit, [string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @("-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath")) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D53Contrast $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D53Contrast ($process.ExitCode -eq 0) "Git blob read failed: $stderr"
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Invoke-ContrastAnalyzer([string]$Python, [string]$InputManifest, [string]$OutputPath) {
    $output = & $Python $analyzerPath --manifest $InputManifest --evidence-root $evidenceRoot --output $OutputPath 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    return [ordered]@{ output = $output; exit_code = $exitCode }
}

Assert-R23D53Contrast (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @($manifestPath, $analyzerPath, $evidenceRoot)) {
    Assert-R23D53Contrast (Test-Path -LiteralPath $path) "missing path: $path"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$source = $manifest.source_closure
Assert-R23D53Contrast (
    [string]$manifest.schema_version -ceq "sporespore_r23d53_godot_command_contrast_analysis_manifest_v1" -and
    [string]$manifest.analysis_id -ceq "QSDK-R23D53-GODOT-COMMAND-CONTRAST-D1" -and
    [string]$manifest.status -ceq "postclosure_outcome_exposed_descriptive_zero_world_diagnosis" -and
    [string]$manifest.question_class -ceq "development_diagnosis" -and
    [string]$source.addition_commit -ceq "f9467d140c5b88556afa4c7f38e61b2ff8cbdeda" -and
    (git -C $repoRoot rev-parse "$($source.addition_commit):$($source.path)").Trim() -ceq [string]$source.git_blob_oid -and
    (Get-GitBlobSha256 ([string]$source.addition_commit) ([string]$source.path)) -ceq [string]$source.raw_sha256 -and
    @($manifest.ordered_arms).Count -eq 3 -and
    @($manifest.claim_limits.Values | Where-Object { [bool]$_ }).Count -eq 0 -and
    -not [bool]$manifest.attribution_boundary.physical_successor_selected
) "manifest or immutable parent boundary changed"

foreach ($arm in $manifest.ordered_arms) {
    $digest = [string]$arm.trace_sha256
    $directory = Join-Path $evidenceRoot ("artifacts\sha256\" + $digest.Substring(7))
    $payload = Join-Path $directory "payload.bin"
    Assert-R23D53Contrast (
        $digest -match '^sha256:[0-9a-f]{64}$' -and
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq [long]$arm.trace_byte_length -and
        ("sha256:" + (Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash.ToLowerInvariant()) -ceq $digest
    ) "CAS trace identity changed: $($arm.arm_id)"
}

$python = [IO.Path]::GetFullPath([string](@(Get-Command python.exe -CommandType Application -ErrorAction Stop)[0].Source))
$testRoot = Join-Path $repoRoot ("sdk\target\r23d53-command-contrast-test-" + [guid]::NewGuid().ToString("N"))
[void][IO.Directory]::CreateDirectory($testRoot)
try {
    $reportPath = Join-Path $testRoot "report.json"
    $run = Invoke-ContrastAnalyzer $python $manifestPath $reportPath
    Assert-R23D53Contrast ($run.exit_code -eq 0 -and $run.output.Contains("R23D53_COMMAND_CONTRAST_DIAGNOSIS_PASS ")) "retained-trace analysis failed: $($run.output)"
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $findings = $report.aggregate_findings
    $byArm = @{}
    foreach ($arm in $report.arm_contrasts) { $byArm[[string]$arm.arm_id] = $arm }
    Assert-R23D53Contrast (
        [string]$report.schema_version -ceq "sporespore_r23d53_godot_command_contrast_analysis_report_v1" -and
        [int]$report.source_trace_count -eq 3 -and
        [int]$report.source_trace_row_count -eq 8976 -and
        [bool]$findings.all_600_warmup_rows_identical_across_arms -and
        [bool]$findings.origin_timing_confound_removed -and
        [bool]$findings.both_desired_heading_contrasts_correct_all_turn_rows -and
        [bool]$findings.all_turn_rows_report_steering_unsaturated -and
        [int]$findings.positive_held_contrast_correct_row_count -eq 825 -and
        [int]$findings.positive_yaw_effect_correct_row_count -eq 823 -and
        [int]$findings.negative_held_contrast_correct_row_count -eq 974 -and
        [int]$findings.negative_yaw_effect_correct_row_count -eq 556 -and
        [bool]$findings.negative_held_contrast_majority_correct -and
        -not [bool]$findings.negative_yaw_effect_majority_correct -and
        -not [bool]$findings.negative_terminal_yaw_effect_direction_correct -and
        -not [bool]$findings.actuator_level_attribution_available -and
        -not [bool]$findings.physical_successor_selected -and
        [int]$byArm.negative_heading.requested_steering_contrast.counts.correct -eq 764 -and
        [int]$byArm.negative_heading.requested_steering_contrast.counts.zero -eq 395 -and
        [int]$byArm.negative_heading.requested_steering_contrast.counts.wrong -eq 41 -and
        [int]$byArm.negative_heading.held_steering_contrast.counts.zero -eq 185 -and
        [int]$byArm.negative_heading.held_steering_contrast.counts.wrong -eq 41 -and
        [int]$report.model_construction_count -eq 0 -and
        [int]$report.world_attempt_count -eq 0 -and
        [int]$report.world_build_count -eq 0 -and
        -not [bool]$report.historical_result_reinterpreted -and
        -not [bool]$report.physical_execution_authorized -and
        -not [bool]$report.physical_acceptance_authority
    ) "computed diagnosis boundary changed"
    Assert-R23D53Contrast (
        -not [bool]$report.supported_interpretation.origin_timing_only_explanation_supported -and
        -not [bool]$report.supported_interpretation.missing_or_inverted_negative_command_explanation_supported -and
        -not [bool]$report.supported_interpretation.reported_steering_saturation_explanation_supported -and
        [bool]$report.supported_interpretation.controller_to_physics_directional_conversion_requires_further_attribution -and
        -not [bool]$report.supported_interpretation.current_trace_can_choose_actuator_or_contact_phase_mechanism -and
        [bool]$report.supported_interpretation.next_zero_world_boundary_is_actuator_and_contact_phase_trace_schema_plus_evaluator_controls
    ) "interpretation exceeded retained evidence"

    $wrongSchedule = $manifest.Clone()
    $wrongSchedule.trace_contract = $manifest.trace_contract.Clone()
    $wrongSchedule.trace_contract.turn_start_semantic_step = 601
    $wrongSchedulePath = Join-Path $testRoot "wrong-schedule.json"
    $wrongSchedule | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $wrongSchedulePath
    $wrongScheduleRun = Invoke-ContrastAnalyzer $python $wrongSchedulePath (Join-Path $testRoot "wrong-schedule-report.json")
    Assert-R23D53Contrast ($wrongScheduleRun.exit_code -ne 0 -and $wrongScheduleRun.output.Contains("R23D53_COMMAND_CONTRAST_INHERITED_SCHEDULE")) "schedule mutation survived"

    $wrongCell = $manifest.Clone()
    $wrongCell.ordered_arms = @($manifest.ordered_arms | ForEach-Object { $_.Clone() })
    $wrongCell.ordered_arms[0].trace_sha256 = [string]$manifest.ordered_arms[1].trace_sha256
    $wrongCell.ordered_arms[0].trace_byte_length = [long]$manifest.ordered_arms[1].trace_byte_length
    $wrongCellPath = Join-Path $testRoot "wrong-cell.json"
    $wrongCell | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $wrongCellPath
    $wrongCellRun = Invoke-ContrastAnalyzer $python $wrongCellPath (Join-Path $testRoot "wrong-cell-report.json")
    Assert-R23D53Contrast ($wrongCellRun.exit_code -ne 0 -and $wrongCellRun.output.Contains("R23D53_COMMAND_CONTRAST_TRACE_IDENTITY")) "wrong-cell mutation survived"

    $inflated = $manifest.Clone()
    $inflated.claim_limits = $manifest.claim_limits.Clone()
    $inflated.claim_limits.physical_execution_authorized = $true
    $inflatedPath = Join-Path $testRoot "inflated.json"
    $inflated | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $inflatedPath
    $inflatedRun = Invoke-ContrastAnalyzer $python $inflatedPath (Join-Path $testRoot "inflated-report.json")
    Assert-R23D53Contrast ($inflatedRun.exit_code -ne 0 -and $inflatedRun.output.Contains("R23D53_COMMAND_CONTRAST_CLAIM_INFLATION")) "claim inflation survived"
} finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}

Write-Host "R23D53_COMMAND_CONTRAST_TEST_PASS traces=3 rows=8976 warmup_equal=600 desired_contrast=1200/1200 positive_held=825 positive_yaw=823 negative_held=974 negative_yaw=556 saturation=0 actuator_attribution=False models=0 worlds=0 physical=False"
