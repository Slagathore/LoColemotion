#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closurePath = Join-Path $repoRoot (
    "sdk\trace_analysis\r23d27_predictive_tilt_diagnosis_closure_v1.json"
)
$evidenceRoot = Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"

function Assert-R23D27TiltClosure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D27_TILT_DIAGNOSIS_CLOSURE: $Message" }
}

function Get-R23D27TiltClosureGitBlobSha256(
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
        Assert-R23D27TiltClosure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D27TiltClosure ($process.ExitCode -eq 0) (
            "Git blob read failed for ${RelativePath}: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Get-R23D27TiltClosureFileSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D27TiltClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Test-Path -LiteralPath $evidenceRoot -PathType Container)
) "repository, closure, or durable evidence identity changed"

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$sourceCommit = [string]$closure.source.commit
Assert-R23D27TiltClosure (
    [string]$closure.schema_version -ceq
        "sporespore_r23d27_predictive_tilt_diagnosis_closure_v1" -and
    [string]$closure.analysis_id -ceq
        "QSDK-R23D27-PREDICTIVE-TILT-PRECURSOR-D1" -and
    [string]$closure.status -ceq
        "closed_complete_postoutcome_development_diagnosis" -and
    $sourceCommit -ceq "f0f9084daf7a57d33289c1529ec7914336bdd58b" -and
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        [string]$closure.source.tree_git_oid -and
    [bool]$closure.source.clean_pushed_live_main_verified
) "closure or clean pushed source identity changed"

$sourceBindings = @($closure.source.source_bindings)
Assert-R23D27TiltClosure ($sourceBindings.Count -eq 5) "source binding count changed"
foreach ($binding in $sourceBindings) {
    $relative = [string]$binding.path
    Assert-R23D27TiltClosure (
        (git -C $repoRoot rev-parse "${sourceCommit}:${relative}").Trim() -ceq
            [string]$binding.git_blob_oid -and
        (Get-R23D27TiltClosureGitBlobSha256 $sourceCommit $relative) -ceq
            [string]$binding.raw_sha256
    ) "pinned source binding changed: $relative"
}

$parent = $closure.immutable_parent
Assert-R23D27TiltClosure (
    (git -C $repoRoot rev-parse (
        "$($parent.closure_source_commit):$($parent.closure_path)"
    )).Trim() -ceq [string]$parent.closure_git_blob_oid -and
    (Get-R23D27TiltClosureGitBlobSha256 `
        ([string]$parent.closure_source_commit) `
        ([string]$parent.closure_path)) -ceq
        [string]$parent.closure_raw_sha256 -and
    [string]$parent.parent_status -ceq
        "closed_consumed_valid_complete_negative_no_validated_candidate" -and
    -not [bool]$parent.parent_reinterpreted -and
    -not [bool]$parent.parent_rerun
) "immutable R23D27 parent binding changed"

$reportPath = [string]$closure.retained_evidence.report.path
$receiptPath = [string]$closure.retained_evidence.receipt.path
$reportCasPath = [string]$closure.retained_evidence.report.cas_payload_path
$reportCasManifestPath = [string]$closure.retained_evidence.report.cas_manifest_path
foreach ($path in @($reportPath, $receiptPath, $reportCasPath, $reportCasManifestPath)) {
    Assert-R23D27TiltClosure (Test-Path -LiteralPath $path -PathType Leaf) (
        "retained evidence object missing: $path"
    )
}
$reportSha = Get-R23D27TiltClosureFileSha256 $reportPath
$receiptSha = Get-R23D27TiltClosureFileSha256 $receiptPath
$casSha = Get-R23D27TiltClosureFileSha256 $reportCasPath
Assert-R23D27TiltClosure (
    $reportSha -ceq [string]$closure.retained_evidence.report.sha256 -and
    $casSha -ceq $reportSha -and
    (Get-Item -LiteralPath $reportPath).Length -eq
        [long]$closure.retained_evidence.report.byte_length -and
    (Get-Item -LiteralPath $reportCasPath).Length -eq
        [long]$closure.retained_evidence.report.byte_length -and
    $receiptSha -ceq [string]$closure.retained_evidence.receipt.sha256 -and
    (Get-Item -LiteralPath $receiptPath).Length -eq
        [long]$closure.retained_evidence.receipt.byte_length
) "retained report, receipt, or CAS identity changed"

$report = Get-Content -LiteralPath $reportPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$receipt = Get-Content -LiteralPath $receiptPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$casManifest = Get-Content -LiteralPath $reportCasManifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D27TiltClosure (
    [string]$receipt.report_sha256 -ceq $reportSha -and
    [long]$receipt.report_byte_length -eq
        [long]$closure.retained_evidence.report.byte_length -and
    [string]$receipt.analyzer_source_commit -ceq $sourceCommit -and
    [int]$receipt.model_construction_count -eq 0 -and
    [int]$receipt.world_attempt_count -eq 0 -and
    [int]$receipt.world_build_count -eq 0 -and
    -not [bool]$receipt.physical_execution_authorized -and
    -not [bool]$receipt.physical_acceptance_authority -and
    [string]$casManifest.schema_version -ceq
        "sporespore_content_addressed_artifact_manifest_v1" -and
    [string]$casManifest.sha256 -ceq $reportSha -and
    [long]$casManifest.byte_length -eq
        [long]$closure.retained_evidence.report.byte_length
) "receipt or report CAS manifest changed"

Assert-R23D27TiltClosure (
    [string]$report.schema_version -ceq
        "sporespore_retained_trace_lineage_report_v1" -and
    [string]$report.analysis_id -ceq [string]$closure.analysis_id -and
    [string]$report.analyzer_source_commit -ceq $sourceCommit -and
    [int]$report.input_summary.cell_count -eq 3 -and
    [int]$report.input_summary.trace_count -eq 3 -and
    [long]$report.input_summary.total_trace_byte_length -eq 29252801 -and
    [int]$report.input_summary.total_trace_row_count -eq 8976 -and
    [int]$report.input_summary.content_addressed_input_count -eq 3 -and
    [int]$report.input_summary.live_attempt_path_input_count -eq 0 -and
    @($report.cells).Count -eq 3 -and
    @($report.comparisons).Count -eq 1 -and
    [int]$report.observability.complete_limiting_actuator_cell_count -eq 3
) "retained report shape or observability changed"

foreach ($cell in $report.cells) {
    $digest = [string]$cell.trace_sha256
    $payload = Join-Path $evidenceRoot (
        "artifacts\sha256\" + $digest.Substring(7) + "\payload.bin"
    )
    Assert-R23D27TiltClosure (
        $digest -match '^sha256:[0-9a-f]{64}$' -and
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Get-R23D27TiltClosureFileSha256 $payload) -ceq $digest -and
        (Get-Item -LiteralPath $payload).Length -eq [long]$cell.trace_byte_length
    ) "input trace CAS binding changed: $($cell.cell_id)"
}

$reference = @($report.cells | Where-Object {
    [string]$_.arm_id -ceq "reference_zero"
})
$positive = @($report.cells | Where-Object {
    [string]$_.arm_id -ceq "positive_heading"
})
$negative = @($report.cells | Where-Object {
    [string]$_.arm_id -ceq "negative_heading"
})
Assert-R23D27TiltClosure (
    $reference.Count -eq 1 -and
    $positive.Count -eq 1 -and
    $negative.Count -eq 1 -and
    $null -eq $reference[0].tilt_precursor.observed_first_guard_reduction_step -and
    @($reference[0].tilt_precursor.windows | Where-Object {
        $null -ne $_.first_projected_minimum_authority_tilt_reached_step
    }).Count -eq 0 -and
    [int]$positive[0].tilt_precursor.observed_first_guard_reduction_step -eq 976 -and
    (@($positive[0].tilt_precursor.windows | ForEach-Object {
        [int]$_.first_projected_minimum_authority_tilt_reached_step
    }) -join ',') -ceq "840,952,954,959,966,978,982" -and
    (@($positive[0].tilt_precursor.windows | ForEach-Object {
        [int]$_.projected_floor_lead_over_observed_guard_reduction_steps
    }) -join ',') -ceq "136,24,22,17,10,-2,-6" -and
    [int]$negative[0].tilt_precursor.observed_first_guard_reduction_step -eq 786 -and
    (@($negative[0].tilt_precursor.windows | ForEach-Object {
        [int]$_.first_projected_minimum_authority_tilt_reached_step
    }) -join ',') -ceq "646,763,765,771,777,787,791" -and
    (@($negative[0].tilt_precursor.windows | ForEach-Object {
        [int]$_.projected_floor_lead_over_observed_guard_reduction_steps
    }) -join ',') -ceq "140,23,21,15,9,-1,-5"
) "retained predictive precursor findings changed"

$middleIndices = @(1, 2, 3, 4)
foreach ($cell in @($positive[0], $negative[0])) {
    foreach ($index in $middleIndices) {
        Assert-R23D27TiltClosure (
            [int]$cell.tilt_precursor.windows[$index].
                projected_floor_lead_over_observed_guard_reduction_steps -gt 0
        ) "middle-window precursor lead disappeared: $($cell.arm_id):$index"
    }
}
Assert-R23D27TiltClosure (
    (@($closure.projection_contract.finite_difference_window_steps) -join ',') -ceq
        "4,8,12,24,36,60,72" -and
    [double]$closure.projection_contract.prediction_horizon_s -eq 0.6 -and
    -not [bool]$closure.projection_contract.thresholds_changed -and
    -not [bool]$closure.projection_contract.finite_difference_window_selected -and
    -not [bool]$closure.projection_contract.counterfactual_physical_outcome_claimed -and
    [bool]$closure.findings.both_failed_arms_have_positive_middle_window_lead -and
    [bool]$closure.findings.reference_has_no_projected_floor_crossing -and
    [bool]$closure.interpretation.distinct_successor_design_supported -and
    -not [bool]$closure.interpretation.distinct_successor_physical_execution_authorized -and
    [bool]$closure.successor_constraints.portable_state_frame_tilt_rate_required -and
    [bool]$closure.successor_constraints.direction_neutral_rule_required -and
    [bool]$closure.successor_constraints.engine_identity_branch_forbidden -and
    [bool]$closure.successor_constraints.command_sign_branch_forbidden -and
    [bool]$closure.successor_constraints.own_zero_world_gate_required -and
    [int]$closure.counts.model_construction_count -eq 0 -and
    [int]$closure.counts.world_attempt_count -eq 0 -and
    [int]$closure.counts.world_build_count -eq 0
) "closure interpretation, successor constraints, or world counts changed"

foreach ($claim in $closure.claim_limits.GetEnumerator()) {
    Assert-R23D27TiltClosure (-not [bool]$claim.Value) (
        "diagnosis claim became true: $($claim.Key)"
    )
}
foreach ($claim in @(
    "closed_campaign_reinterpreted",
    "candidate_selection_authorized",
    "threshold_change_authorized",
    "physical_campaign_opened",
    "physical_execution_authorized",
    "turning_validation",
    "cross_engine_equivalence",
    "release_authorized",
    "physical_acceptance_authority"
)) {
    Assert-R23D27TiltClosure (-not [bool]$report[$claim]) (
        "retained report claim became true: $claim"
    )
}

Write-Host (
    "R23D27_PREDICTIVE_TILT_DIAGNOSIS_CLOSURE_PASS sources=5 traces=3 " +
    "cells=3 rows=8976 windows=7 middle_precursors=8 reference_floor=0 " +
    "models=0 worlds=0 design_supported=True physical=False turning=False " +
    "equivalence=False release=False"
)
