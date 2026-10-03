#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\trace_analysis\r23d29_directional_response_diagnosis_closure_v1.json"
)

function Assert-R23D29DirectionalClosure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D29_DIRECTIONAL_CLOSURE: $Message" }
}

function Assert-R23D29DirectionalClose(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D29DirectionalClosure (
        [Math]::Abs($Actual - $Expected) -le $Tolerance
    ) "$Message actual=$Actual expected=$Expected tolerance=$Tolerance"
}

function Get-R23D29DirectionalGitBlobSha256(
    [string]$Commit,
    [string]$RelativePath
) {
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
        Assert-R23D29DirectionalClosure $process.Start() (
            "could not start Git blob reader"
        )
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D29DirectionalClosure ($process.ExitCode -eq 0) (
            "Git blob read failed for ${RelativePath}: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Get-R23D29DirectionalFileSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D29DirectionalClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "repository or closure identity changed"

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$sourceCommit = [string]$closure.source.commit
Assert-R23D29DirectionalClosure (
    [string]$closure.schema_version -ceq
        "sporespore_r23d29_directional_response_diagnosis_closure_v1" -and
    [string]$closure.analysis_id -ceq
        "QSDK-R23D29-DIRECTIONAL-RESPONSE-MEASUREMENT-D1" -and
    [string]$closure.status -ceq
        "closed_complete_postoutcome_development_diagnosis" -and
    $sourceCommit -ceq "3100b26d945bb37f1cb9a88202f8a607ed1daaca" -and
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        [string]$closure.source.tree_git_oid -and
    [bool]$closure.source.clean_pushed_live_main_verified
) "closure or source identity changed"

$sourceBindings = @($closure.source.source_bindings)
Assert-R23D29DirectionalClosure ($sourceBindings.Count -eq 5) (
    "source binding count changed"
)
foreach ($binding in $sourceBindings) {
    $relative = [string]$binding.path
    Assert-R23D29DirectionalClosure (
        (git -C $repoRoot rev-parse "${sourceCommit}:${relative}").Trim() -ceq
            [string]$binding.git_blob_oid -and
        (Get-R23D29DirectionalGitBlobSha256 $sourceCommit $relative) -ceq
            [string]$binding.raw_sha256 -and
        (git -C $repoRoot cat-file -s "${sourceCommit}:${relative}").Trim() -eq
            [long]$binding.byte_length
    ) "pinned source binding changed: $relative"
}

$parent = $closure.immutable_parent
Assert-R23D29DirectionalClosure (
    (git -C $repoRoot rev-parse (
        "$($parent.closure_source_commit):$($parent.closure_path)"
    )).Trim() -ceq [string]$parent.closure_git_blob_oid -and
    (Get-R23D29DirectionalGitBlobSha256 `
        ([string]$parent.closure_source_commit) `
        ([string]$parent.closure_path)) -ceq
        [string]$parent.closure_raw_sha256 -and
    [string]$parent.parent_status -ceq
        "closed_valid_complete_negative_no_development_candidate" -and
    -not [bool]$parent.parent_reinterpreted -and
    -not [bool]$parent.parent_rerun
) "immutable R23D29 parent binding changed"

$reportPath = [string]$closure.retained_evidence.report.path
$receiptPath = [string]$closure.retained_evidence.receipt.path
$casPayloadPath = [string]$closure.retained_evidence.report.cas_payload_path
$casManifestPath = [string]$closure.retained_evidence.report.cas_manifest_path
foreach ($path in @($reportPath, $receiptPath, $casPayloadPath, $casManifestPath)) {
    Assert-R23D29DirectionalClosure (Test-Path -LiteralPath $path -PathType Leaf) (
        "retained evidence object missing: $path"
    )
}
Assert-R23D29DirectionalClosure (
    (Get-R23D29DirectionalFileSha256 $reportPath) -ceq
        [string]$closure.retained_evidence.report.sha256 -and
    (Get-R23D29DirectionalFileSha256 $casPayloadPath) -ceq
        [string]$closure.retained_evidence.report.sha256 -and
    (Get-Item -LiteralPath $reportPath).Length -eq
        [long]$closure.retained_evidence.report.byte_length -and
    (Get-Item -LiteralPath $casPayloadPath).Length -eq
        [long]$closure.retained_evidence.report.byte_length -and
    (Get-R23D29DirectionalFileSha256 $receiptPath) -ceq
        [string]$closure.retained_evidence.receipt.sha256 -and
    (Get-Item -LiteralPath $receiptPath).Length -eq
        [long]$closure.retained_evidence.receipt.byte_length -and
    (Get-R23D29DirectionalFileSha256 $casManifestPath) -ceq
        [string]$closure.retained_evidence.report.cas_manifest_sha256 -and
    (Get-Item -LiteralPath $casManifestPath).Length -eq
        [long]$closure.retained_evidence.report.cas_manifest_byte_length
) "retained report, receipt, or CAS identity changed"

$report = Get-Content -LiteralPath $reportPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$receipt = Get-Content -LiteralPath $receiptPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$casManifest = Get-Content -LiteralPath $casManifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D29DirectionalClosure (
    [string]$receipt.analysis_id -ceq [string]$closure.analysis_id -and
    [string]$receipt.analyzer_source_commit -ceq $sourceCommit -and
    [string]$receipt.report_sha256 -ceq
        [string]$closure.retained_evidence.report.sha256 -and
    [long]$receipt.report_byte_length -eq
        [long]$closure.retained_evidence.report.byte_length -and
    [string]$casManifest.sha256 -ceq
        [string]$closure.retained_evidence.report.sha256 -and
    [long]$casManifest.byte_length -eq
        [long]$closure.retained_evidence.report.byte_length -and
    [int]$receipt.model_construction_count -eq 0 -and
    [int]$receipt.world_attempt_count -eq 0 -and
    [int]$receipt.world_build_count -eq 0 -and
    -not [bool]$receipt.physical_execution_authorized -and
    -not [bool]$receipt.physical_acceptance_authority
) "retention receipt or CAS manifest changed"

$comparison = $report.comparisons[0]
$measurement = $comparison.directional_response_measurement
$positive = $measurement.response_trajectories.positive_heading
$negative = $measurement.response_trajectories.negative_heading
$positiveDelivery = $measurement.command_delivery.positive_heading
$negativeDelivery = $measurement.command_delivery.negative_heading
Assert-R23D29DirectionalClosure (
    [int]$report.input_summary.cell_count -eq 3 -and
    [int]$report.input_summary.total_trace_row_count -eq 8976 -and
    [long]$report.input_summary.total_trace_byte_length -eq 36479155 -and
    [int]$report.input_summary.content_addressed_input_count -eq 3 -and
    [int]$report.input_summary.live_attempt_path_input_count -eq 0 -and
    (@($measurement.windows | ForEach-Object { [int]$_.window_steps }) -join ',') -ceq
        "1,72,144,216,288,360" -and
    (@($measurement.windows | ForEach-Object { [bool]$_.both_thresholds_met }) -join ',') -ceq
        "False,False,False,False,True,True" -and
    [int]$positive.first_threshold_met_step -eq 1249 -and
    [int]$positive.peak_conditioned_response_step -eq 1719 -and
    [int]$positive.threshold_met_row_count -eq 454 -and
    [int]$negative.first_threshold_met_step -eq 1070 -and
    [int]$negative.peak_conditioned_response_step -eq 1555 -and
    [int]$negative.threshold_met_row_count -eq 424 -and
    [int]$positiveDelivery.requested_sign_consistent_row_count -eq 1200 -and
    [int]$positiveDelivery.held_sign_consistent_row_count -eq 1199 -and
    [int]$positiveDelivery.guard_floor_hold_active_row_count -eq 635 -and
    [int]$negativeDelivery.requested_sign_consistent_row_count -eq 1200 -and
    [int]$negativeDelivery.held_sign_consistent_row_count -eq 1200 -and
    [int]$negativeDelivery.guard_floor_hold_active_row_count -eq 820 -and
    [bool]$measurement.direct_observations.both_commanded_arms_reached_threshold_during_phase -and
    [bool]$measurement.direct_observations.both_commanded_arms_requested_sign_consistent_every_row -and
    -not [bool]$measurement.direct_observations.frozen_endpoint_both_thresholds_met -and
    [bool]$measurement.direct_observations.full_cycle_terminal_mean_both_thresholds_met -and
    [bool]$measurement.direct_observations.negative_arm_reached_threshold_then_ended_below -and
    $null -eq $measurement.terminal_estimator_selected_for_successor -and
    $null -eq $measurement.controller_change_selected -and
    -not [bool]$measurement.closed_endpoint_verdict_changed
) "retained directional-response findings changed"

Assert-R23D29DirectionalClose `
    ([double]$comparison.positive_reference_conditioned_yaw_delta_rad) `
    0.015467562771277548 1.0e-15 "frozen positive endpoint changed"
Assert-R23D29DirectionalClose `
    ([double]$comparison.negative_reference_conditioned_yaw_delta_rad) `
    0.00029444164763040275 1.0e-15 "frozen negative endpoint changed"
Assert-R23D29DirectionalClose `
    ([double]$positive.peak_conditioned_response_rad) `
    0.04020062811303697 1.0e-15 "positive peak changed"
Assert-R23D29DirectionalClose `
    ([double]$negative.peak_conditioned_response_rad) `
    0.039542539075027736 1.0e-15 "negative peak changed"
Assert-R23D29DirectionalClose `
    ([double]$negative.peak_to_endpoint_regression_rad) `
    0.039248097427397335 1.0e-15 "negative regression changed"
Assert-R23D29DirectionalClose `
    ([double]$measurement.windows[-1].positive_reference_conditioned_mean_yaw_shift_rad) `
    0.014151062658812923 1.0e-15 "full-cycle positive mean changed"
Assert-R23D29DirectionalClose `
    ([double]$measurement.windows[-1].negative_reference_conditioned_mean_yaw_shift_rad) `
    0.016851528700347392 1.0e-15 "full-cycle negative mean changed"

Assert-R23D29DirectionalClosure (
    -not [bool]$closure.interpretation.missing_or_wrong_signed_requested_authority_explanation_supported -and
    -not [bool]$closure.interpretation.no_negative_response_onset_explanation_supported -and
    [bool]$closure.interpretation.phase_coherent_measurement_successor_design_supported -and
    -not [bool]$closure.interpretation.distinct_successor_physical_execution_authorized -and
    [bool]$closure.successor_constraints.fresh_measurement_contract_and_campaign_identity_required -and
    [bool]$closure.successor_constraints.r23d29_same_identity_rerun_forbidden -and
    $null -eq $closure.successor_constraints.specific_terminal_window_selected -and
    $null -eq $closure.successor_constraints.specific_controller_change_selected -and
    [bool]$closure.successor_constraints.independent_scheduler_basis_for_any_terminal_window_required -and
    [bool]$closure.successor_constraints.fresh_held_out_physical_conditions_required -and
    [int]$closure.counts.model_construction_count -eq 0 -and
    [int]$closure.counts.world_attempt_count -eq 0 -and
    [int]$closure.counts.world_build_count -eq 0 -and
    @($closure.claim_limits.Values | Where-Object { [bool]$_ }).Count -eq 0 -and
    -not [bool]$report.closed_campaign_reinterpreted -and
    -not [bool]$report.candidate_selection_authorized -and
    -not [bool]$report.physical_execution_authorized -and
    -not [bool]$report.turning_validation -and
    -not [bool]$report.physical_acceptance_authority
) "successor or claim boundary changed"

Write-Host (
    "R23D29_DIRECTIONAL_RESPONSE_CLOSURE_PASS source=3100b26 " +
    "bindings=5 traces=3 rows=8976 bytes=36479155 windows=6 " +
    "endpoint_bilateral=False full_cycle_bilateral=True " +
    "report=sha256:bb516e8b6748 models=0 worlds=0 physical=False turning=False"
)
