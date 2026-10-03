#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot (
    "turning\r23d25_mujoco_terminal_zero_forward_closure_v1.json"
)
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d25_supervisor.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$sourceCommit = "8059a9b2810650022f8eaae48fb80a9bb51e6e03"

. $artifactStorePath

function Assert-R23D25Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D25 closure: $Message" }
}

function Get-R23D25GitBlobSha256(
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
        Assert-R23D25Closure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D25Closure ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Test-R23D25Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D25Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    return Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $artifactRoot $Sha256.Substring(7)) `
        -ExpectedSha256 $Sha256.Substring(7) `
        -ExpectedByteLength $ByteLength
}

function Read-R23D25CasJson([string]$Sha256, [long]$ByteLength) {
    Assert-R23D25Closure (Test-R23D25Cas $Sha256 $ByteLength) (
        "CAS object failed verification: $Sha256"
    )
    return Get-Content -Raw -LiteralPath (
        Join-Path (Join-Path $artifactRoot $Sha256.Substring(7)) "payload.bin"
    ) | ConvertFrom-Json -AsHashtable -Depth 100
}

Assert-R23D25Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Test-Path -LiteralPath $supervisorPath -PathType Leaf)
) "repository or closure identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D25Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d25_mujoco_terminal_zero_forward_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_negative_terminal_zero_forward_causally_insufficient" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D25-MUJOCO-TERMINAL-ZERO-FORWARD" -and
    [string]$closure.gate_id -ceq "QSDK-R23D25" -and
    [string]$closure.physical_source.commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        [string]$closure.physical_source.tree_git_oid -and
    [int]$closure.physical_source.source_binding_count -eq 82 -and
    [int]$closure.physical_source.source_cas_count -eq 82 -and
    [bool]$closure.physical_source.checkout_bytes_equal_git_blobs -and
    [bool]$closure.attempt.single_use_identity_consumed -and
    -not [bool]$closure.attempt.same_identity_rerun_allowed -and
    [int]$closure.attempt.world_attempt_count -eq 3 -and
    [int]$closure.attempt.world_build_count -eq 3 -and
    [int]$closure.attempt.execution_valid_cell_count -eq 3 -and
    [int]$closure.attempt.outcome_positive_cell_count -eq 2 -and
    [int]$closure.attempt.outcome_negative_cell_count -eq 1 -and
    [int]$closure.attempt.worker_failure_count -eq 0 -and
    [string]$closure.attempt.result_classification -ceq "valid_complete_negative"
) "closure summary changed"

$aggregate = $closure.retained_aggregate_artifacts
$freeze = Read-R23D25CasJson `
    ([string]$aggregate.physical_freeze.sha256) `
    ([long]$aggregate.physical_freeze.byte_length)
$attempt = Read-R23D25CasJson `
    ([string]$aggregate.attempt_authorization.sha256) `
    ([long]$aggregate.attempt_authorization.byte_length)
$manifest = Read-R23D25CasJson `
    ([string]$aggregate.terminal_manifest.sha256) `
    ([long]$aggregate.terminal_manifest.byte_length)
$report = Read-R23D25CasJson `
    ([string]$aggregate.report.sha256) `
    ([long]$aggregate.report.byte_length)
$completion = Read-R23D25CasJson `
    ([string]$aggregate.completion.sha256) `
    ([long]$aggregate.completion.byte_length)

Assert-R23D25Closure (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$attempt.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$report.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$completion.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    @($manifest).Count -eq 3 -and
    @($freeze.source_bindings).Count -eq 82 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 82 -and
    [string]$freeze.runtime_artifact.raw_sha256 -ceq
        [string]$closure.physical_source.reproducible_runtime_sha256 -and
    (Test-R23D25Cas `
        ([string]$freeze.content_addressed_inputs.locomotion_core.sha256) `
        ([long]$freeze.content_addressed_inputs.locomotion_core.byte_length))
) "retained freeze or attempt identity changed"

for ($index = 0; $index -lt 82; $index++) {
    $binding = $freeze.source_bindings[$index]
    $retained = $freeze.content_addressed_inputs.source_bindings[$index]
    $relative = [string]$binding.path
    Assert-R23D25Closure (
        [string]$binding.git_blob_oid -ceq
            (git -C $repoRoot rev-parse "${sourceCommit}:$relative").Trim() -and
        [string]$binding.raw_sha256 -ceq
            (Get-R23D25GitBlobSha256 $sourceCommit $relative) -and
        [string]$retained.sha256 -ceq [string]$binding.raw_sha256 -and
        (Test-R23D25Cas ([string]$retained.sha256) ([long]$retained.byte_length))
    ) "pinned or retained source binding changed: $relative"
}

$expectedIds = @($closure.attempt.ordered_cell_ids)
$reportCells = @($report.ordered_matrix_cells)
$evaluations = @($report.complete_evaluation.cell_evaluations)
Assert-R23D25Closure (
    (@($reportCells.cell_id) -join '|') -ceq ($expectedIds -join '|') -and
    (@($evaluations.cell_id) -join '|') -ceq ($expectedIds -join '|') -and
    [string]$report.complete_evaluation.classification -ceq
        "valid_complete_negative" -and
    [bool]$report.complete_evaluation.matrix_valid -and
    [int]$report.complete_evaluation.outcome_failure_count -eq 1 -and
    [int]$report.complete_evaluation.world_attempt_count -eq 3 -and
    [int]$report.complete_evaluation.world_build_count -eq 3 -and
    [int]$report.complete_evaluation.composite_engine_count -eq 3 -and
    [int]$report.complete_evaluation.composite_cell_count -eq 9
) "retained report matrix changed"

foreach ($expected in @($closure.cells)) {
    $terminal = Read-R23D25CasJson `
        ([string]$expected.terminal_cas_sha256) `
        ([long]$expected.terminal_byte_length)
    Assert-R23D25Closure (
        (Test-R23D25Cas `
            ([string]$expected.trace_cas_sha256) `
            ([long]$expected.trace_byte_length)) -and
        [string]$terminal.cell_id -ceq [string]$expected.cell_id -and
        [string]$terminal.trace_artifact.sha256 -ceq
            [string]$expected.trace_cas_sha256 -and
        [long]$terminal.trace_artifact.byte_length -eq
            [long]$expected.trace_byte_length -and
        [double]$terminal.measurements.final_forward_displacement_m -eq
            [double]$expected.final_forward_displacement_m -and
        [double]$terminal.measurements.turn_phase_yaw_delta_rad -eq
            [double]$expected.turn_phase_yaw_delta_rad -and
        [bool]$terminal.measurements.confirmation_satisfied -eq
            [bool]$expected.confirmation_satisfied -and
        [int]$terminal.measurements.handoff_after_active_step -eq
            [int]$expected.handoff_after_active_step -and
        [int]$terminal.measurements.post_handoff_contact_loss_step_count -eq
            [int]$expected.post_handoff_contact_loss_step_count -and
        [int]$terminal.measurements.terminal_receipt_validation_failure_count -eq 0 -and
        [int]$terminal.measurements.terminal_zero_forward_command_count -eq
            [int]$expected.terminal_zero_forward_command_count -and
        [int]$terminal.measurements.terminal_zero_forward_receipt_count -eq
            [int]$expected.terminal_zero_forward_receipt_count -and
        [int]$terminal.measurements.terminal_nonzero_forward_command_count -eq 0 -and
        [int]$terminal.measurements.terminal_forward_receipt_violation_count -eq 0 -and
        [double]$terminal.measurements.maximum_absolute_terminal_desired_forward_velocity_m_s -eq 0.0 -and
        [double]$terminal.measurements.maximum_absolute_terminal_normalized_forward_velocity_error -eq 0.0 -and
        [double]$terminal.measurements.maximum_absolute_terminal_forward_hip_correction_rad -eq 0.0
    ) "retained terminal projection changed: $([string]$expected.cell_id)"
    $evaluation = @($evaluations | Where-Object {
        [string]$_.cell_id -ceq [string]$expected.cell_id
    })
    Assert-R23D25Closure (
        $evaluation.Count -eq 1 -and
        [bool]$evaluation[0].entry_valid -and
        [bool]$evaluation[0].execution_integrity_passed -and
        [bool]$evaluation[0].outcome.walking_and_taper_gate_passed -eq
            [bool]$expected.walking_and_taper_gate_passed -and
        [bool]$evaluation[0].outcome.outcome_gate_passed -eq
            [bool]$expected.outcome_gate_passed -and
        (@($evaluation[0].outcome.failed_gate_ids) -join '|') -ceq
            (@($expected.failed_gate_ids) -join '|')
    ) "retained evaluation projection changed: $([string]$expected.cell_id)"
}

$conditioned = $report.complete_evaluation.same_engine_command_conditioned_response.mujoco
Assert-R23D25Closure (
    [double]$conditioned.positive_minus_reference_rad -eq
        [double]$closure.conditioned_response.positive_minus_reference_rad -and
    [double]$conditioned.negative_minus_reference_rad -eq
        [double]$closure.conditioned_response.negative_minus_reference_rad -and
    [bool]$conditioned.conditioned_response_gate_passed -and
    [bool]$closure.mechanism.terminal_zero_forward_command_semantic_succeeded -and
    [bool]$closure.mechanism.every_active_terminal_receipt_proved_zero_forward_intent -and
    [bool]$closure.mechanism.all_terminal_nonzero_forward_command_counts_zero -and
    [bool]$closure.mechanism.all_terminal_forward_receipt_violation_counts_zero -and
    [bool]$closure.mechanism.all_three_worlds_execution_valid -and
    [bool]$closure.mechanism.common_r23d24_measurement_projection_changed_only_by_floating_roundoff -and
    (@($closure.mechanism.reference_contact_loss_recurred_at_same_global_trace_steps_as_r23d24) -join '|') -ceq
        '3914|3917|3920|3926|3929|3930|3939' -and
    -not [bool]$closure.mechanism.threshold_change_authorized -and
    -not [bool]$closure.claims.finite_mujoco_turning_candidate -and
    -not [bool]$closure.claims.finite_three_engine_turning_candidate -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "mechanism or claim boundary changed"

$refusal = & pwsh -NoLogo -NoProfile -File $supervisorPath -RunPhysical 2>&1 |
    Out-String
Assert-R23D25Closure (
    $LASTEXITCODE -eq 0 -and
    $refusal.Contains("QSDK_R23D25_PHYSICAL_REFUSAL") -and
    $refusal.Contains('"reason":"r23d25_identity_closed"') -and
    $refusal.Contains('"world_attempt_count":0') -and
    $refusal.Contains('"world_build_count":0')
) "same-identity physical refusal changed: $refusal"

Write-Host (
    "QSDK_R23D25_CLOSURE_PASS cells=3 worlds=3 valid=3 positive=2 negative=1 " +
    "zero_forward_receipts=1510 receipt_failures=0 reference_contact_loss_steps=7 " +
    "causally_sufficient=False rerun=False " +
    "three_engine=False equivalence=False release=False"
)
