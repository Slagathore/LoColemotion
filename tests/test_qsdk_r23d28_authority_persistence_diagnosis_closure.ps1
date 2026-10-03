#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\trace_analysis\r23d28_authority_persistence_diagnosis_closure_v1.json"
)

function Assert-R23D28PersistenceClosure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D28_AUTHORITY_PERSISTENCE_CLOSURE: $Message" }
}

function Get-R23D28PersistenceGitBlobSha256(
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
        Assert-R23D28PersistenceClosure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D28PersistenceClosure ($process.ExitCode -eq 0) (
            "Git blob read failed for ${RelativePath}: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Get-R23D28PersistenceFileSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D28PersistenceClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "repository or closure identity changed"

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$sourceCommit = [string]$closure.source.commit
Assert-R23D28PersistenceClosure (
    [string]$closure.schema_version -ceq
        "sporespore_r23d28_authority_persistence_diagnosis_closure_v1" -and
    [string]$closure.analysis_id -ceq
        "QSDK-R23D28-AUTHORITY-PERSISTENCE-D1" -and
    [string]$closure.status -ceq
        "closed_complete_postoutcome_development_diagnosis" -and
    $sourceCommit -ceq "1ccd13f97e8aba16779c34a7c91f6463fd18623d" -and
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        [string]$closure.source.tree_git_oid -and
    [bool]$closure.source.clean_pushed_live_main_verified
) "closure or source identity changed"

$sourceBindings = @($closure.source.source_bindings)
Assert-R23D28PersistenceClosure ($sourceBindings.Count -eq 5) (
    "source binding count changed"
)
foreach ($binding in $sourceBindings) {
    $relative = [string]$binding.path
    Assert-R23D28PersistenceClosure (
        (git -C $repoRoot rev-parse "${sourceCommit}:${relative}").Trim() -ceq
            [string]$binding.git_blob_oid -and
        (Get-R23D28PersistenceGitBlobSha256 $sourceCommit $relative) -ceq
            [string]$binding.raw_sha256 -and
        (git -C $repoRoot cat-file -s "${sourceCommit}:${relative}").Trim() -eq
            [long]$binding.byte_length
    ) "pinned source binding changed: $relative"
}

$parent = $closure.immutable_parent
Assert-R23D28PersistenceClosure (
    (git -C $repoRoot rev-parse (
        "$($parent.closure_source_commit):$($parent.closure_path)"
    )).Trim() -ceq [string]$parent.closure_git_blob_oid -and
    (Get-R23D28PersistenceGitBlobSha256 `
        ([string]$parent.closure_source_commit) `
        ([string]$parent.closure_path)) -ceq
        [string]$parent.closure_raw_sha256 -and
    [string]$parent.parent_status -ceq
        "closed_valid_complete_negative_no_development_candidate" -and
    -not [bool]$parent.parent_reinterpreted -and
    -not [bool]$parent.parent_rerun
) "immutable R23D28 parent binding changed"

$reportPath = [string]$closure.retained_evidence.report.path
$receiptPath = [string]$closure.retained_evidence.receipt.path
$casPayloadPath = [string]$closure.retained_evidence.report.cas_payload_path
$casManifestPath = [string]$closure.retained_evidence.report.cas_manifest_path
foreach ($path in @($reportPath, $receiptPath, $casPayloadPath, $casManifestPath)) {
    Assert-R23D28PersistenceClosure (Test-Path -LiteralPath $path -PathType Leaf) (
        "retained evidence object missing: $path"
    )
}
Assert-R23D28PersistenceClosure (
    (Get-R23D28PersistenceFileSha256 $reportPath) -ceq
        [string]$closure.retained_evidence.report.sha256 -and
    (Get-R23D28PersistenceFileSha256 $casPayloadPath) -ceq
        [string]$closure.retained_evidence.report.sha256 -and
    (Get-Item -LiteralPath $reportPath).Length -eq
        [long]$closure.retained_evidence.report.byte_length -and
    (Get-Item -LiteralPath $casPayloadPath).Length -eq
        [long]$closure.retained_evidence.report.byte_length -and
    (Get-R23D28PersistenceFileSha256 $receiptPath) -ceq
        [string]$closure.retained_evidence.receipt.sha256 -and
    (Get-Item -LiteralPath $receiptPath).Length -eq
        [long]$closure.retained_evidence.receipt.byte_length -and
    (Get-R23D28PersistenceFileSha256 $casManifestPath) -ceq
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
Assert-R23D28PersistenceClosure (
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

$reference = @($report.cells | Where-Object arm_id -eq "reference_zero")[0]
$positive = @($report.cells | Where-Object arm_id -eq "positive_heading")[0]
$negative = @($report.cells | Where-Object arm_id -eq "negative_heading")[0]
$summary = $report.steering_floor_hold_summary
Assert-R23D28PersistenceClosure (
    [int]$report.input_summary.cell_count -eq 3 -and
    [int]$report.input_summary.total_trace_row_count -eq 8976 -and
    [long]$report.input_summary.total_trace_byte_length -eq 32640009 -and
    [int]$report.input_summary.content_addressed_input_count -eq 3 -and
    [int]$report.input_summary.live_attempt_path_input_count -eq 0 -and
    [int]$reference.steering_floor_hold.observed_floor_row_count -eq 0 -and
    [int]$positive.steering_floor_hold.observed_floor_row_count -eq 853 -and
    [int]$positive.steering_floor_hold.first_observed_floor_step -eq 839 -and
    [int]$positive.steering_floor_hold.first_actual_full_authority_tilt_exceeded_step -eq 975 -and
    [int]$negative.steering_floor_hold.observed_floor_row_count -eq 1042 -and
    [int]$negative.steering_floor_hold.first_observed_floor_step -eq 646 -and
    [int]$negative.steering_floor_hold.first_actual_full_authority_tilt_exceeded_step -eq 784 -and
    (@($positive.steering_floor_hold.durations | ForEach-Object {
        [int]$_.expanded_authority_reopened_row_count_after_first_floor_before_actual_full_tilt_exceeded
    }) -join ',') -ceq "25,0,0,0,0" -and
    (@($negative.steering_floor_hold.durations | ForEach-Object {
        [int]$_.expanded_authority_reopened_row_count_after_first_floor_before_actual_full_tilt_exceeded
    }) -join ',') -ceq "32,0,0,0,0" -and
    [int]$summary.smallest_declared_duration_satisfying_replay_property_steps -eq 144 -and
    (@($summary.durations | ForEach-Object {
        [int]$_.commanded_expanded_authority_reopened_row_count_before_actual_full_tilt_exceeded
    }) -join ',') -ceq "57,0,0,0,0"
) "retained persistence findings changed"

Assert-R23D28PersistenceClosure (
    [bool]$closure.interpretation.distinct_stateful_successor_design_supported -and
    -not [bool]$closure.interpretation.distinct_successor_physical_execution_authorized -and
    [int]$closure.successor_constraints.floor_hold_steps -eq 144 -and
    [int]$closure.successor_constraints.floor_hold_scheduler_swing_count -eq 2 -and
    [bool]$closure.successor_constraints.versioned_controller_memory_required -and
    [bool]$closure.successor_constraints.versioned_guard_receipt_required -and
    [bool]$closure.successor_constraints.independent_state_transition_oracle_required -and
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
    "R23D28_AUTHORITY_PERSISTENCE_CLOSURE_PASS source=1ccd13f " +
    "bindings=5 traces=3 rows=8976 bytes=32640009 durations=5 " +
    "smallest_descriptive_hold_steps=144 report=sha256:6ed95b4d2095 " +
    "models=0 worlds=0 physical=False turning=False"
)
