#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot (
    "turning\r23d26_rapier_steering_cap_closure_v1.json"
)
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d26_supervisor.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$artifactRoot = Join-Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) "artifacts\sha256"
$sourceCommit = "0a1241d35d764ab59e0b7b09dea480ffbe2aa978"

. $artifactStorePath

function Assert-R23D26Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D26 closure: $Message" }
}

function Get-R23D26GitBlobSha256([string]$Commit, [string]$RelativePath) {
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
        Assert-R23D26Closure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D26Closure ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Test-R23D26Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D26Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    return Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $artifactRoot $Sha256.Substring(7)) `
        -ExpectedSha256 $Sha256.Substring(7) `
        -ExpectedByteLength $ByteLength
}

function Read-R23D26CasJson([string]$Sha256, [long]$ByteLength) {
    Assert-R23D26Closure (Test-R23D26Cas $Sha256 $ByteLength) (
        "CAS object failed verification: $Sha256"
    )
    return Get-Content -Raw -LiteralPath (
        Join-Path (Join-Path $artifactRoot $Sha256.Substring(7)) "payload.bin"
    ) | ConvertFrom-Json -AsHashtable -Depth 100
}

Assert-R23D26Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Test-Path -LiteralPath $supervisorPath -PathType Leaf)
) "repository or closure identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D26Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d26_rapier_steering_cap_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_negative_no_selected_cap" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D26-RAPIER-STEERING-CAP-DEVELOPMENT" -and
    [string]$closure.gate_id -ceq "QSDK-R23D26" -and
    [string]$closure.physical_source.commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        [string]$closure.physical_source.tree_git_oid -and
    [string]$closure.physical_source.source_materialization_kind -ceq
        "git_archive_blob_exact_v1" -and
    [int]$closure.physical_source.source_binding_count -eq 201 -and
    [int]$closure.physical_source.source_cas_count -eq 201 -and
    [bool]$closure.physical_source.source_bytes_consumed_by_build_equal_git_blobs -and
    -not [bool]$closure.physical_source.ambient_checkout_is_build_authority -and
    [int]$closure.physical_source.ambient_checkout_blob_mismatch_count -eq 4 -and
    (@($closure.physical_source.ambient_checkout_blob_mismatch_paths) -join '|') -ceq
        ('sdk/adapters/rapier/src/bin/conformance.rs|' +
         'sdk/adapters/rapier/src/conformance.rs|' +
         'sdk/balanced_wave_selected_policy.json|' +
         'sdk/include/sporespore_locomotion.h') -and
    [bool]$closure.attempt.single_use_identity_consumed -and
    -not [bool]$closure.attempt.same_identity_rerun_allowed -and
    [int]$closure.attempt.world_attempt_count -eq 9 -and
    [int]$closure.attempt.world_build_count -eq 9 -and
    [int]$closure.attempt.process_exit_zero_count -eq 9 -and
    [int]$closure.attempt.execution_valid_cell_count -eq 9 -and
    [int]$closure.attempt.outcome_positive_cell_count -eq 5 -and
    [int]$closure.attempt.outcome_negative_cell_count -eq 4 -and
    [int]$closure.attempt.worker_failure_count -eq 0 -and
    [int]$closure.attempt.eligible_candidate_count -eq 0 -and
    $null -eq $closure.attempt.selected_candidate_id -and
    [string]$closure.attempt.result_classification -ceq "valid_complete_negative"
) "closure summary changed"

$aggregate = $closure.retained_aggregate_artifacts
$freeze = Read-R23D26CasJson `
    ([string]$aggregate.physical_freeze.sha256) `
    ([long]$aggregate.physical_freeze.byte_length)
$attempt = Read-R23D26CasJson `
    ([string]$aggregate.attempt_authorization.sha256) `
    ([long]$aggregate.attempt_authorization.byte_length)
$report = Read-R23D26CasJson `
    ([string]$aggregate.report.sha256) `
    ([long]$aggregate.report.byte_length)
$completion = Read-R23D26CasJson `
    ([string]$aggregate.completion.sha256) `
    ([long]$aggregate.completion.byte_length)

Assert-R23D26Closure (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$attempt.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$report.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$completion.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    @($freeze.source_bindings).Count -eq 201 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 201 -and
    [string]$freeze.source_materialization.kind -ceq "git_archive_blob_exact_v1" -and
    -not [bool]$freeze.source_materialization.ambient_checkout_is_build_authority -and
    [bool]$freeze.source_materialization.materialized_git_blobs_are_build_authority -and
    [bool]$freeze.source_bytes_consumed_by_build_equal_git_blobs -and
    [bool]$freeze.ambient_checkout_is_not_build_authority -and
    [string]$freeze.content_addressed_inputs.source_archive.sha256 -ceq
        [string]$closure.physical_source.source_archive_sha256 -and
    [long]$freeze.content_addressed_inputs.source_archive.byte_length -eq
        [long]$closure.physical_source.source_archive_byte_length -and
    [string]$freeze.runtime_artifact.raw_sha256 -ceq
        [string]$closure.physical_source.runtime_sha256 -and
    [string]$freeze.content_addressed_inputs.rapier_worker.sha256 -ceq
        [string]$closure.physical_source.runtime_sha256 -and
    [long]$freeze.content_addressed_inputs.rapier_worker.byte_length -eq
        [long]$closure.physical_source.runtime_byte_length -and
    (Test-R23D26Cas `
        ([string]$closure.physical_source.source_archive_sha256) `
        ([long]$closure.physical_source.source_archive_byte_length)) -and
    (Test-R23D26Cas `
        ([string]$closure.physical_source.runtime_sha256) `
        ([long]$closure.physical_source.runtime_byte_length))
) "retained source, runtime, freeze, or attempt identity changed"

$mismatchPaths = [Collections.Generic.List[string]]::new()
for ($index = 0; $index -lt 201; $index++) {
    $binding = $freeze.source_bindings[$index]
    $retained = $freeze.content_addressed_inputs.source_bindings[$index]
    $relative = [string]$binding.path
    if (-not [bool]$binding.ambient_checkout_equals_git_blob) {
        $mismatchPaths.Add($relative)
    }
    Assert-R23D26Closure (
        [string]$binding.source_kind -ceq "git_archive_blob_exact_v1" -and
        [bool]$binding.materialized_bytes_equal_git_blob -and
        [string]$binding.git_blob_oid -ceq
            (git -C $repoRoot rev-parse "${sourceCommit}:$relative").Trim() -and
        [string]$binding.raw_sha256 -ceq
            (Get-R23D26GitBlobSha256 $sourceCommit $relative) -and
        [string]$retained.sha256 -ceq [string]$binding.raw_sha256 -and
        (Test-R23D26Cas ([string]$retained.sha256) ([long]$retained.byte_length))
    ) "pinned or retained source binding changed: $relative"
}
Assert-R23D26Closure (
    ($mismatchPaths -join '|') -ceq
        (@($closure.physical_source.ambient_checkout_blob_mismatch_paths) -join '|')
) "ambient checkout mismatch inventory changed"

Assert-R23D26Closure (
    [string]$report.complete_evaluation.classification -ceq
        "valid_complete_negative" -and
    @($report.ordered_matrix_cells).Count -eq 9 -and
    @($report.complete_evaluation.cell_evaluations).Count -eq 9 -and
    @($report.complete_evaluation.candidate_summaries).Count -eq 3 -and
    @($report.complete_evaluation.eligible_candidate_ids).Count -eq 0 -and
    $null -eq $report.complete_evaluation.selected_candidate_id -and
    [string]$completion.status -ceq "valid_complete_negative_first_attempt" -and
    [int]$completion.terminal_entry_count -eq 9 -and
    [string]$completion.report_cas.sha256 -ceq [string]$aggregate.report.sha256 -and
    -not [bool]$completion.same_identity_rerun_allowed
) "retained report or completion classification changed"

for ($index = 0; $index -lt 3; $index++) {
    $expected = $closure.candidate_summaries[$index]
    $observed = $report.complete_evaluation.candidate_summaries[$index]
    Assert-R23D26Closure (
        [string]$observed.candidate_id -ceq [string]$expected.candidate_id -and
        [double]$observed.maximum_steering_fraction -eq
            [double]$expected.maximum_steering_fraction -and
        [bool]$observed.all_three_cells_passed -eq
            [bool]$expected.all_three_cells_passed -and
        [double]$observed.positive_reference_conditioned_yaw_delta_rad -eq
            [double]$expected.positive_reference_conditioned_yaw_delta_rad -and
        [double]$observed.negative_reference_conditioned_yaw_delta_rad -eq
            [double]$expected.negative_reference_conditioned_yaw_delta_rad -and
        [double]$observed.bilateral_yaw_separation_rad -eq
            [double]$expected.bilateral_yaw_separation_rad -and
        [bool]$observed.eligible -eq [bool]$expected.eligible
    ) "candidate summary changed: $([string]$expected.candidate_id)"
}

foreach ($expected in @($closure.cells)) {
    $matrixCell = @($report.ordered_matrix_cells | Where-Object {
        [string]$_.cell_id -ceq [string]$expected.cell_id
    })
    $evaluation = @($report.complete_evaluation.cell_evaluations | Where-Object {
        [string]$_.cell_id -ceq [string]$expected.cell_id
    })
    Assert-R23D26Closure ($matrixCell.Count -eq 1 -and $evaluation.Count -eq 1) (
        "cell projection is missing or duplicated: $([string]$expected.cell_id)"
    )
    $terminal = Read-R23D26CasJson `
        ([string]$expected.terminal_cas_sha256) `
        ([long]$expected.terminal_byte_length)
    Assert-R23D26Closure (
        [int]$matrixCell[0].process_exit_code -eq 0 -and
        [string]$matrixCell[0].terminal_entry_cas.sha256 -ceq
            [string]$expected.terminal_cas_sha256 -and
        [string]$terminal.cell_id -ceq [string]$expected.cell_id -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.trace_summary.row_count -eq [int]$expected.trace_row_count -and
        [string]$terminal.trace_artifact.sha256 -ceq
            [string]$expected.trace_cas_sha256 -and
        [long]$terminal.trace_artifact.byte_length -eq
            [long]$expected.trace_byte_length -and
        (Test-R23D26Cas `
            ([string]$expected.trace_cas_sha256) `
            ([long]$expected.trace_byte_length)) -and
        [double]$evaluation[0].final_forward_displacement_m -eq
            [double]$expected.final_forward_displacement_m -and
        [double]$evaluation[0].turn_phase_yaw_delta_rad -eq
            [double]$expected.turn_phase_yaw_delta_rad -and
        [double]$evaluation[0].minimum_torso_height_m -eq
            [double]$expected.minimum_torso_height_m -and
        [double]$evaluation[0].maximum_tilt_rad -eq
            [double]$expected.maximum_tilt_rad -and
        [bool]$evaluation[0].execution_valid -and
        [bool]$evaluation[0].gate_passed -eq [bool]$expected.gate_passed -and
        (@($evaluation[0].failure_codes) -join '|') -ceq
            (@($expected.failure_codes) -join '|')
    ) "retained cell evidence changed: $([string]$expected.cell_id)"
}

$qualification = $closure.campaign_local_qualification
Assert-R23D26Closure (
    (Get-R23D26GitBlobSha256 $sourceCommit `
        "sdk/turning/r23d26_rapier_steering_cap_preregistration_v1.json") -ceq
        [string]$freeze.preregistration_raw_sha256 -and
    (Test-Path -LiteralPath ([string]$qualification.scoped_attestation_path) -PathType Leaf) -and
    ("sha256:" + (Get-FileHash -LiteralPath (
        [string]$qualification.scoped_attestation_path
    ) -Algorithm SHA256).Hash.ToLowerInvariant()) -ceq
        [string]$qualification.scoped_attestation_sha256 -and
    (Get-Item -LiteralPath ([string]$qualification.scoped_attestation_path)).Length -eq
        [long]$qualification.scoped_attestation_byte_length -and
    (Test-Path -LiteralPath ([string]$qualification.adoption_path) -PathType Leaf) -and
    ("sha256:" + (Get-FileHash -LiteralPath (
        [string]$qualification.adoption_path
    ) -Algorithm SHA256).Hash.ToLowerInvariant()) -ceq
        [string]$qualification.adoption_sha256 -and
    (Get-Item -LiteralPath ([string]$qualification.adoption_path)).Length -eq
        [long]$qualification.adoption_byte_length -and
    [int]$qualification.executed_gate_count -eq 17 -and
    [bool]$qualification.commissioned_executor_verified -and
    [bool]$qualification.physical_launch_prerequisite_satisfied -and
    -not [bool]$qualification.physical_acceptance_authority
) "campaign-local qualification receipt changed"

Assert-R23D26Closure (
    @($closure.pre_world_incidents).Count -eq 3 -and
    (@($closure.pre_world_incidents.world_attempt_count) | Measure-Object -Sum).Sum -eq 0 -and
    (@($closure.pre_world_incidents.world_build_count) | Measure-Object -Sum).Sum -eq 0 -and
    @($closure.pre_world_incidents | Where-Object { [bool]$_.identity_consumed }).Count -eq 0 -and
    -not [bool]$closure.mechanism.threshold_change_authorized -and
    -not [bool]$closure.mechanism.same_identity_rerun_authorized -and
    -not [bool]$closure.claims.finite_rapier_development_candidate -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning_candidate -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.turning_validation -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "incident, mechanism, or claim boundary changed"

$refusal = & pwsh -NoLogo -NoProfile -File $supervisorPath -RunPhysical 2>&1 |
    Out-String
Assert-R23D26Closure (
    $LASTEXITCODE -eq 0 -and
    $refusal.Contains("QSDK_R23D26_PHYSICAL_REFUSAL") -and
    $refusal.Contains('"reason":"r23d26_identity_closed"') -and
    $refusal.Contains('"world_attempt_count":0') -and
    $refusal.Contains('"world_build_count":0')
) "same-identity physical refusal changed: $refusal"

Write-Host (
    "QSDK_R23D26_CLOSURE_PASS candidates=3 cells=9 worlds=9 valid=9 " +
    "positive=5 negative=4 selected=NONE blob_bindings=201 " +
    "checkout_mismatches=4 preworld_incidents=3 rerun=False " +
    "three_engine=False equivalence=False release=False"
)
