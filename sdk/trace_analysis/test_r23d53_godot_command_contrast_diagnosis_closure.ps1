#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$closurePath = Join-Path $PSScriptRoot "r23d53_godot_command_contrast_diagnosis_closure_v1.json"
$diagnosisTestPath = Join-Path $PSScriptRoot "test_r23d53_godot_command_contrast.ps1"

function Assert-R23D53ContrastClosure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D53_COMMAND_CONTRAST_CLOSURE: $Message" }
}

function Get-GitBlobSha256([string]$Commit, [string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @("-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath")) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D53ContrastClosure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D53ContrastClosure ($process.ExitCode -eq 0) "Git blob read failed: $stderr"
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Assert-FileIdentity([string]$Path, [string]$Sha256, [long]$Length, [string]$Label) {
    Assert-R23D53ContrastClosure (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $Length -and
        ("sha256:" + (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()) -ceq $Sha256
    ) "$Label identity changed"
}

Assert-R23D53ContrastClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$closure = Get-Content -LiteralPath $closurePath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$source = $closure.source
$parent = $closure.immutable_parent
$retained = $closure.retained_evidence
$findings = $closure.findings
Assert-R23D53ContrastClosure (
    [string]$closure.schema_version -ceq "sporespore_r23d53_godot_command_contrast_diagnosis_closure_v1" -and
    [string]$closure.analysis_id -ceq "QSDK-R23D53-GODOT-COMMAND-CONTRAST-D1" -and
    [string]$closure.status -ceq "closed_complete_postoutcome_godot_command_contrast_diagnosis" -and
    [string]$source.commit -ceq "d44a603a91bac15803605e0b48cc1745771cb283" -and
    (git -C $repoRoot rev-parse "$($source.commit)^{tree}").Trim() -ceq [string]$source.tree_git_oid -and
    [bool]$source.clean_pushed_live_main_verified -and
    @($source.source_bindings).Count -eq 5 -and
    [int]$retained.source_trace_count -eq 3 -and
    [int]$retained.source_trace_row_count -eq 8976 -and
    [int]$retained.content_addressed_input_count -eq 3 -and
    [int]$retained.live_attempt_path_input_count -eq 0 -and
    @($closure.claim_limits.Values | Where-Object { [bool]$_ }).Count -eq 0
) "closure boundary changed"

foreach ($binding in $source.source_bindings) {
    $relative = [string]$binding.path
    Assert-R23D53ContrastClosure (
        (git -C $repoRoot rev-parse "$($source.commit):${relative}").Trim() -ceq [string]$binding.git_blob_oid -and
        (Get-GitBlobSha256 ([string]$source.commit) $relative) -ceq [string]$binding.raw_sha256
    ) "source binding changed: $relative"
}
Assert-R23D53ContrastClosure (
    (git -C $repoRoot rev-parse "$($parent.closure_addition_commit):$($parent.closure_path)").Trim() -ceq [string]$parent.closure_git_blob_oid -and
    (Get-GitBlobSha256 ([string]$parent.closure_addition_commit) ([string]$parent.closure_path)) -ceq [string]$parent.closure_raw_sha256 -and
    -not [bool]$parent.parent_reinterpreted -and
    -not [bool]$parent.parent_rerun
) "immutable R23D53 parent changed"

Assert-FileIdentity ([string]$retained.report.path) ([string]$retained.report.sha256) ([long]$retained.report.byte_length) "report"
Assert-FileIdentity ([string]$retained.report.cas_payload_path) ([string]$retained.report.sha256) ([long]$retained.report.byte_length) "CAS report"
Assert-FileIdentity ([string]$retained.report.cas_manifest_path) ([string]$retained.report.cas_manifest_sha256) ([long]$retained.report.cas_manifest_byte_length) "CAS manifest"
Assert-FileIdentity ([string]$retained.receipt.path) ([string]$retained.receipt.sha256) ([long]$retained.receipt.byte_length) "receipt"

$report = Get-Content -LiteralPath ([string]$retained.report.cas_payload_path) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$receipt = Get-Content -LiteralPath ([string]$retained.receipt.path) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D53ContrastClosure (
    [string]$report.schema_version -ceq "sporespore_r23d53_godot_command_contrast_analysis_report_v1" -and
    [string]$receipt.schema_version -ceq "sporespore_r23d53_godot_command_contrast_analysis_receipt_v1" -and
    [string]$receipt.analyzer_source_commit -ceq [string]$source.commit -and
    [string]$receipt.report_sha256 -ceq [string]$retained.report.sha256 -and
    [long]$receipt.report_byte_length -eq [long]$retained.report.byte_length -and
    [int]$report.source_trace_count -eq 3 -and
    [int]$report.source_trace_row_count -eq 8976 -and
    [int]$report.model_construction_count -eq 0 -and
    [int]$report.world_attempt_count -eq 0 -and
    [int]$report.world_build_count -eq 0 -and
    [int]$closure.counts.model_construction_count -eq 0 -and
    [int]$closure.counts.world_attempt_count -eq 0 -and
    [int]$closure.counts.world_build_count -eq 0
) "retained report or receipt changed"

$reportFindings = $report.aggregate_findings
Assert-R23D53ContrastClosure (
    [bool]$findings.all_600_warmup_rows_identical_across_arms -and
    [bool]$findings.origin_timing_confound_removed -and
    [bool]$findings.both_desired_heading_contrasts_correct_all_turn_rows -and
    [bool]$findings.all_turn_rows_report_steering_unsaturated -and
    [int]$findings.positive_held_contrast_correct_row_count -eq 825 -and
    [int]$findings.positive_yaw_effect_correct_row_count -eq 823 -and
    [int]$findings.negative_requested_contrast_correct_row_count -eq 764 -and
    [int]$findings.negative_requested_contrast_zero_row_count -eq 395 -and
    [int]$findings.negative_requested_contrast_wrong_row_count -eq 41 -and
    [int]$findings.negative_held_contrast_correct_row_count -eq 974 -and
    [int]$findings.negative_held_contrast_zero_row_count -eq 185 -and
    [int]$findings.negative_held_contrast_wrong_row_count -eq 41 -and
    [int]$findings.negative_yaw_effect_correct_row_count -eq 556 -and
    [int]$findings.negative_yaw_effect_zero_row_count -eq 1 -and
    [int]$findings.negative_yaw_effect_wrong_row_count -eq 643 -and
    [bool]$findings.negative_held_contrast_majority_correct -and
    -not [bool]$findings.negative_yaw_effect_majority_correct -and
    -not [bool]$findings.negative_terminal_yaw_effect_direction_correct -and
    -not [bool]$findings.actuator_level_attribution_available -and
    -not [bool]$findings.physical_successor_selected -and
    [int]$reportFindings.negative_held_contrast_correct_row_count -eq 974 -and
    [int]$reportFindings.negative_yaw_effect_correct_row_count -eq 556
) "finding boundary changed"
Assert-R23D53ContrastClosure (
    -not [bool]$closure.interpretation.origin_timing_only_explanation_supported -and
    -not [bool]$closure.interpretation.missing_or_inverted_negative_command_explanation_supported -and
    -not [bool]$closure.interpretation.reported_steering_saturation_explanation_supported -and
    [bool]$closure.interpretation.controller_to_physics_directional_conversion_requires_further_attribution -and
    -not [bool]$closure.interpretation.current_trace_can_choose_actuator_or_contact_phase_mechanism -and
    [bool]$closure.interpretation.next_zero_world_boundary_is_actuator_and_contact_phase_trace_schema_plus_evaluator_controls -and
    -not [bool]$closure.interpretation.r23d53_exact_policy_selected -and
    -not [bool]$closure.interpretation.r23d53_verdict_changed
) "interpretation exceeded retained evidence"

$diagnosisOutput = & pwsh -NoLogo -NoProfile -File $diagnosisTestPath 2>&1 | Out-String
$diagnosisExit = $LASTEXITCODE
$global:LASTEXITCODE = 0
Assert-R23D53ContrastClosure ($diagnosisExit -eq 0 -and $diagnosisOutput.Contains("R23D53_COMMAND_CONTRAST_TEST_PASS")) "independent CAS recomputation failed: $diagnosisOutput"

$requiredDocumentation = @(
    "docs\README.md",
    "docs\ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
    "docs\SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
    "docs\LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md",
    "docs\SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md",
    "sdk\trace_analysis\README.md",
    "sdk\turning\README.md"
)
foreach ($relativePath in $requiredDocumentation) {
    $text = Get-Content -LiteralPath (Join-Path $repoRoot $relativePath) -Raw
    Assert-R23D53ContrastClosure (
        $text.Contains("sha256:550a7750d529abcdd19c12a0d00d9fa069b808a20d4c69d3532ba6535199db67") -and
        $text.Contains("974") -and
        $text.Contains("556") -and
        $text.Contains("actuator")
    ) "documentation closure boundary missing: $relativePath"
}

Write-Host "R23D53_COMMAND_CONTRAST_CLOSURE_PASS traces=3 rows=8976 warmup_equal=600 desired=1200/1200 negative_held=974 negative_yaw=556 actuator_attribution=False models=0 worlds=0 physical=False"
