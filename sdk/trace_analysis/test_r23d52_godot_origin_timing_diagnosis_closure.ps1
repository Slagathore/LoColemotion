#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$closurePath = Join-Path $PSScriptRoot (
    "r23d52_godot_origin_timing_diagnosis_closure_v1.json"
)
$diagnosisTestPath = Join-Path $PSScriptRoot (
    "test_r23d52_godot_origin_timing.ps1"
)

function Assert-R23D52OriginClosure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D52_ORIGIN_CLOSURE: $Message" }
}

function Assert-R23D52OriginNear(
    [double]$Actual,
    [double]$Expected,
    [string]$Message
) {
    Assert-R23D52OriginClosure ([Math]::Abs($Actual - $Expected) -le 1.0e-15) (
        "$Message actual=$Actual expected=$Expected"
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
        Assert-R23D52OriginClosure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D52OriginClosure ($process.ExitCode -eq 0) (
            "Git blob read failed for ${RelativePath}: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Assert-FileIdentity(
    [string]$Path,
    [string]$Sha256,
    [long]$Length,
    [string]$Label
) {
    Assert-R23D52OriginClosure (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $Length -and
        ("sha256:" + (
            Get-FileHash -LiteralPath $Path -Algorithm SHA256
        ).Hash.ToLowerInvariant()) -ceq $Sha256
    ) "$Label identity changed"
}

Assert-R23D52OriginClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$source = $closure.source
$findings = $closure.findings
$constraints = $closure.successor_constraints
Assert-R23D52OriginClosure (
    [string]$closure.schema_version -ceq
        "sporespore_r23d52_godot_origin_timing_diagnosis_closure_v1" -and
    [string]$closure.analysis_id -ceq
        "QSDK-R23D52-GODOT-ORIGIN-TIMING-D1" -and
    [string]$closure.status -ceq
        "closed_complete_postoutcome_same_seed_godot_origin_timing_diagnosis" -and
    [string]$source.commit -ceq
        "0e0551741187e8b4d629e0369e9dbfc8ce22e096" -and
    (git -C $repoRoot rev-parse "$($source.commit)^{tree}").Trim() -ceq
        [string]$source.tree_git_oid -and
    [bool]$source.clean_pushed_live_main_verified -and
    @($source.source_bindings).Count -eq 5 -and
    @($closure.immutable_parents).Count -eq 2 -and
    [int]$closure.retained_evidence.source_trace_count -eq 6 -and
    [int]$closure.retained_evidence.source_trace_row_count -eq 17952 -and
    [int]$closure.retained_evidence.content_addressed_input_count -eq 6 -and
    [int]$closure.retained_evidence.live_attempt_path_input_count -eq 0 -and
    @($closure.claim_limits.Values | Where-Object { [bool]$_ }).Count -eq 0
) "closure boundary changed"

foreach ($binding in $source.source_bindings) {
    $relativePath = [string]$binding.path
    Assert-R23D52OriginClosure (
        (git -C $repoRoot rev-parse "$($source.commit):${relativePath}").Trim() -ceq
            [string]$binding.git_blob_oid -and
        (Get-GitBlobSha256 ([string]$source.commit) $relativePath) -ceq
            [string]$binding.raw_sha256
    ) "source binding changed: $relativePath"
}
foreach ($parent in $closure.immutable_parents) {
    $commit = [string]$parent.closure_addition_commit
    $relativePath = [string]$parent.closure_path
    Assert-R23D52OriginClosure (
        (git -C $repoRoot rev-parse "${commit}:${relativePath}").Trim() -ceq
            [string]$parent.closure_git_blob_oid -and
        (Get-GitBlobSha256 $commit $relativePath) -ceq
            [string]$parent.closure_raw_sha256 -and
        -not [bool]$parent.parent_reinterpreted -and
        -not [bool]$parent.parent_rerun
    ) "immutable parent changed: $($parent.gate_id)"
}

$retained = $closure.retained_evidence
Assert-FileIdentity (
    [string]$retained.report.path
) ([string]$retained.report.sha256) ([long]$retained.report.byte_length) "report"
Assert-FileIdentity (
    [string]$retained.report.cas_payload_path
) ([string]$retained.report.sha256) ([long]$retained.report.byte_length) "CAS report"
Assert-FileIdentity (
    [string]$retained.report.cas_manifest_path
) ([string]$retained.report.cas_manifest_sha256) (
    [long]$retained.report.cas_manifest_byte_length
) "CAS manifest"
Assert-FileIdentity (
    [string]$retained.receipt.path
) ([string]$retained.receipt.sha256) ([long]$retained.receipt.byte_length) "receipt"

$report = Get-Content -LiteralPath ([string]$retained.report.cas_payload_path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$receipt = Get-Content -LiteralPath ([string]$retained.receipt.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D52OriginClosure (
    [string]$report.schema_version -ceq
        "sporespore_r23d52_godot_origin_timing_analysis_report_v1" -and
    [string]$receipt.schema_version -ceq
        "sporespore_r23d52_godot_origin_timing_analysis_receipt_v1" -and
    [string]$receipt.analyzer_source_commit -ceq [string]$source.commit -and
    [string]$receipt.report_sha256 -ceq [string]$retained.report.sha256 -and
    [long]$receipt.report_byte_length -eq [long]$retained.report.byte_length -and
    [int]$report.source_trace_count -eq 6 -and
    [int]$report.source_trace_row_count -eq 17952 -and
    [int]$report.model_construction_count -eq 0 -and
    [int]$report.world_attempt_count -eq 0 -and
    [int]$report.world_build_count -eq 0 -and
    [int]$closure.counts.model_construction_count -eq 0 -and
    [int]$closure.counts.world_attempt_count -eq 0 -and
    [int]$closure.counts.world_build_count -eq 0
) "retained report or receipt boundary changed"

$aggregate = $report.aggregate_findings
Assert-R23D52OriginClosure (
    [bool]$findings.same_seed_and_same_initial_physical_observation_per_arm -and
    [bool]$findings.r23d52_initial_segment_reanchored_at_step_zero_per_arm -and
    [int]$findings.first_controller_projection_difference_step -eq 0 -and
    [int]$findings.first_torso_position_difference_step -eq 5 -and
    [int]$findings.first_measured_yaw_difference_step -eq 14 -and
    -not [bool]$findings.r23d52_warmup_trajectory_isolated_from_origin_policy -and
    [bool]$findings.both_commanded_arms_first_cycle_direction_correct -and
    [bool]$findings.both_commanded_arms_later_cycles_reverse_direction -and
    [int]$findings.negative_arm_requested_expected_sign_row_count -eq 1200 -and
    [int]$findings.negative_arm_turn_command_row_count -eq 1200 -and
    [int]$findings.negative_arm_held_expected_sign_row_count -eq 1200 -and
    [bool]$aggregate.all_step_zero_physical_observations_equal -and
    [bool]$aggregate.all_pairs_controller_changed_at_step_zero -and
    [int]$aggregate.earliest_torso_position_difference_step -eq 5 -and
    [int]$aggregate.earliest_measured_yaw_difference_step -eq 14 -and
    -not [bool]$aggregate.warmup_trajectory_isolated_from_origin_policy -and
    [bool]$aggregate.negative_arm_requested_sign_consistent_every_turn_row
) "finding boundary changed"
Assert-R23D52OriginNear (
    [double]$findings.r48_step_zero_cross_track_error_m
) 0.00002473049687269 "R48 step-zero cross-track changed"
Assert-R23D52OriginNear (
    [double]$findings.warmup_terminal_position_distance_m
) 0.019740483829196527 "warmup terminal position difference changed"
Assert-R23D52OriginNear (
    [double]$findings.warmup_terminal_absolute_yaw_difference_rad
) 0.005034472073419893 "warmup terminal yaw difference changed"

Assert-R23D52OriginClosure (
    [string]$constraints.question_class -ceq
        "outcome_exposed_same_seed_godot_jolt_development_screen" -and
    [int]$constraints.fixed_initial_origin_required_through_semantic_step -eq 599 -and
    [int]$constraints.first_reanchor_permitted_at_commanded_turn_onset_step -eq 600 -and
    [bool]$constraints.initial_schedule_binding_must_not_change_task_origin -and
    [bool]$constraints.zero_world_fixed_policy_warmup_projection_equivalence_required -and
    [bool]$constraints.all_three_reference_positive_negative_arms_required -and
    [bool]$constraints.fresh_held_out_validation_required_if_selected -and
    [bool]$constraints.same_identity_rerun_forbidden -and
    -not [bool]$constraints.threshold_change_supported -and
    -not [bool]$constraints.physical_execution_authorized_by_diagnosis -and
    -not [bool]$closure.interpretation.missing_or_wrong_negative_command_explanation_supported -and
    [bool]$closure.interpretation.warmup_preserving_command_onset_reanchor_is_distinct_testable_question -and
    -not [bool]$closure.interpretation.r23d52_exact_policy_selected
) "interpretation or successor constraint changed"

$diagnosisOutput = & 'C:\Program Files\PowerShell\7-preview\pwsh.exe' `
    -NoLogo -NoProfile -File $diagnosisTestPath 2>&1 | Out-String
$diagnosisExit = $LASTEXITCODE
$global:LASTEXITCODE = 0
Assert-R23D52OriginClosure (
    $diagnosisExit -eq 0 -and
    $diagnosisOutput.Contains("R23D52_ORIGIN_TIMING_TEST_PASS")
) "independent CAS recomputation failed: $diagnosisOutput"

$requiredDocumentation = @(
    "docs\README.md",
    "docs\ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
    "docs\SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
    "docs\LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md",
    "sdk\trace_analysis\README.md",
    "sdk\turning\README.md"
)
foreach ($relativePath in $requiredDocumentation) {
    $text = Get-Content -LiteralPath (Join-Path $repoRoot $relativePath) -Raw
    Assert-R23D52OriginClosure (
        $text.Contains(
            "sha256:2ef06418f3a15c206a456f2e8abf13407ff820d58100ccf29822e8e0b203dbdc"
        ) -and
        $text.Contains("17,952") -and
        $text.Contains('`14`') -and
        $text.Contains("warm-up-preserving")
    ) "documentation closure boundary missing: $relativePath"
}

Write-Host (
    "R23D52_ORIGIN_TIMING_CLOSURE_PASS traces=6 rows=17952 " +
    "controller_step=0 position_step=5 yaw_step=14 warmup_isolated=False " +
    "next=warmup_preserving models=0 worlds=0 turning=False physical=False"
)
