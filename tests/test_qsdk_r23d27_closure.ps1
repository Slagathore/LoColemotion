#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot (
    "turning\r23d27_stability_guarded_steering_closure_v1.json"
)
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d27_supervisor.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$artifactRoot = Join-Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) "artifacts\sha256"
$sourceCommit = "0020a4856f39f01bfb8b1c5a1a01768b1f0457ab"
$tolerance = 1.0e-12

. $artifactStorePath

function Assert-R23D27Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D27 closure: $Message" }
}

function Get-R23D27GitBlobSha256([string]$Commit, [string]$RelativePath) {
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
        Assert-R23D27Closure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D27Closure ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Test-R23D27Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D27Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    return Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $artifactRoot $Sha256.Substring(7)) `
        -ExpectedSha256 $Sha256.Substring(7) `
        -ExpectedByteLength $ByteLength
}

function Read-R23D27CasJson([string]$Sha256, [long]$ByteLength) {
    Assert-R23D27Closure (Test-R23D27Cas $Sha256 $ByteLength) (
        "CAS object failed verification: $Sha256"
    )
    return Get-Content -Raw -LiteralPath (
        Join-Path (Join-Path $artifactRoot $Sha256.Substring(7)) "payload.bin"
    ) | ConvertFrom-Json -AsHashtable -Depth 100
}

Assert-R23D27Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Test-Path -LiteralPath $supervisorPath -PathType Leaf)
) "repository or closure identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D27Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d27_stability_guarded_steering_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_negative_no_validated_candidate" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D27-RAPIER-STABILITY-GUARDED-STEERING-VALIDATION" -and
    [string]$closure.gate_id -ceq "QSDK-R23D27" -and
    [string]$closure.physical_source.commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        [string]$closure.physical_source.tree_git_oid -and
    [string]$closure.physical_source.source_materialization_kind -ceq
        "git_archive_blob_exact_v1" -and
    [int]$closure.physical_source.source_binding_count -eq 206 -and
    [int]$closure.physical_source.source_cas_count -eq 206 -and
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
    [int]$closure.attempt.world_attempt_count -eq 3 -and
    [int]$closure.attempt.world_build_count -eq 3 -and
    [int]$closure.attempt.process_exit_zero_count -eq 3 -and
    [int]$closure.attempt.execution_valid_cell_count -eq 3 -and
    [int]$closure.attempt.outcome_positive_cell_count -eq 1 -and
    [int]$closure.attempt.outcome_negative_cell_count -eq 2 -and
    [int]$closure.attempt.worker_failure_count -eq 0 -and
    [int]$closure.attempt.eligible_candidate_count -eq 0 -and
    $null -eq $closure.attempt.selected_candidate_id -and
    [string]$closure.attempt.result_classification -ceq "valid_complete_negative"
) "closure summary changed"

$aggregate = $closure.retained_aggregate_artifacts
$freeze = Read-R23D27CasJson `
    ([string]$aggregate.physical_freeze.sha256) `
    ([long]$aggregate.physical_freeze.byte_length)
$attempt = Read-R23D27CasJson `
    ([string]$aggregate.attempt_authorization.sha256) `
    ([long]$aggregate.attempt_authorization.byte_length)
$report = Read-R23D27CasJson `
    ([string]$aggregate.report.sha256) `
    ([long]$aggregate.report.byte_length)
$completion = Read-R23D27CasJson `
    ([string]$aggregate.completion.sha256) `
    ([long]$aggregate.completion.byte_length)

Assert-R23D27Closure (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$attempt.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$report.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$completion.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    @($freeze.source_bindings).Count -eq 206 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 206 -and
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
    (Test-R23D27Cas `
        ([string]$closure.physical_source.source_archive_sha256) `
        ([long]$closure.physical_source.source_archive_byte_length)) -and
    (Test-R23D27Cas `
        ([string]$closure.physical_source.runtime_sha256) `
        ([long]$closure.physical_source.runtime_byte_length))
) "retained source, runtime, freeze, or attempt identity changed"

$mismatchPaths = [Collections.Generic.List[string]]::new()
for ($index = 0; $index -lt 206; $index++) {
    $binding = $freeze.source_bindings[$index]
    $retained = $freeze.content_addressed_inputs.source_bindings[$index]
    $relative = [string]$binding.path
    if (-not [bool]$binding.ambient_checkout_equals_git_blob) {
        $mismatchPaths.Add($relative)
    }
    Assert-R23D27Closure (
        [string]$binding.source_kind -ceq "git_archive_blob_exact_v1" -and
        [bool]$binding.materialized_bytes_equal_git_blob -and
        [string]$binding.git_blob_oid -ceq
            (git -C $repoRoot rev-parse "${sourceCommit}:$relative").Trim() -and
        [string]$binding.raw_sha256 -ceq
            (Get-R23D27GitBlobSha256 $sourceCommit $relative) -and
        [string]$retained.sha256 -ceq [string]$binding.raw_sha256 -and
        (Test-R23D27Cas ([string]$retained.sha256) ([long]$retained.byte_length))
    ) "pinned or retained source binding changed: $relative"
}
Assert-R23D27Closure (
    ($mismatchPaths -join '|') -ceq
        (@($closure.physical_source.ambient_checkout_blob_mismatch_paths) -join '|')
) "ambient checkout mismatch inventory changed"

Assert-R23D27Closure (
    [string]$report.complete_evaluation.classification -ceq
        "valid_complete_negative" -and
    @($report.ordered_matrix_cells).Count -eq 3 -and
    @($report.complete_evaluation.cell_evaluations).Count -eq 3 -and
    @($report.complete_evaluation.candidate_summaries).Count -eq 1 -and
    @($report.complete_evaluation.eligible_candidate_ids).Count -eq 0 -and
    $null -eq $report.complete_evaluation.selected_candidate_id -and
    [string]$completion.status -ceq "valid_complete_negative_first_attempt" -and
    [int]$completion.terminal_entry_count -eq 3 -and
    [string]$completion.report_cas.sha256 -ceq [string]$aggregate.report.sha256 -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed
) "retained report or completion classification changed"

$expectedCandidate = $closure.candidate_summary
$observedCandidate = $report.complete_evaluation.candidate_summaries[0]
Assert-R23D27Closure (
    [string]$observedCandidate.candidate_id -ceq
        [string]$expectedCandidate.candidate_id -and
    [double]$observedCandidate.maximum_steering_fraction -eq
        [double]$expectedCandidate.maximum_steering_fraction -and
    [bool]$observedCandidate.all_three_cells_passed -eq
        [bool]$expectedCandidate.all_three_cells_passed -and
    [double]$observedCandidate.positive_reference_conditioned_yaw_delta_rad -eq
        [double]$expectedCandidate.positive_reference_conditioned_yaw_delta_rad -and
    [double]$observedCandidate.negative_reference_conditioned_yaw_delta_rad -eq
        [double]$expectedCandidate.negative_reference_conditioned_yaw_delta_rad -and
    [double]$observedCandidate.bilateral_yaw_separation_rad -eq
        [double]$expectedCandidate.bilateral_yaw_separation_rad -and
    [bool]$observedCandidate.eligible -eq [bool]$expectedCandidate.eligible
) "candidate summary changed"

$guardByArm = [ordered]@{
    reference_zero = $closure.guard_observability.reference_zero
    positive_heading = $closure.guard_observability.positive_heading
    negative_heading = $closure.guard_observability.negative_heading
}
$expectedActuatorIds = @(
    "front_left_hip_motor", "front_left_knee_motor",
    "front_right_hip_motor", "front_right_knee_motor",
    "rear_left_hip_motor", "rear_left_knee_motor",
    "rear_right_hip_motor", "rear_right_knee_motor"
)
Assert-R23D27Closure (
    (@($closure.guard_observability.ordered_actuator_ids) -join '|') -ceq
        ($expectedActuatorIds -join '|')
) "actuator order changed"

foreach ($expected in @($closure.cells)) {
    $matrixCell = @($report.ordered_matrix_cells | Where-Object {
        [string]$_.cell_id -ceq [string]$expected.cell_id
    })
    $evaluation = @($report.complete_evaluation.cell_evaluations | Where-Object {
        [string]$_.cell_id -ceq [string]$expected.cell_id
    })
    Assert-R23D27Closure ($matrixCell.Count -eq 1 -and $evaluation.Count -eq 1) (
        "cell projection is missing or duplicated: $([string]$expected.cell_id)"
    )
    $terminal = Read-R23D27CasJson `
        ([string]$expected.terminal_cas_sha256) `
        ([long]$expected.terminal_byte_length)
    Assert-R23D27Closure (
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
        (Test-R23D27Cas `
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
        [double]$terminal.measurements.maximum_absolute_requested_steering_fraction -eq
            [double]$expected.maximum_absolute_requested_steering_fraction -and
        [double]$terminal.measurements.maximum_absolute_held_steering_fraction -eq
            [double]$expected.maximum_absolute_held_steering_fraction -and
        [int]$terminal.measurements.torso_ground_contact_step_count -eq
            [int]$expected.torso_ground_contact_step_count -and
        [bool]$evaluation[0].execution_valid -and
        [bool]$evaluation[0].gate_passed -eq [bool]$expected.gate_passed -and
        (@($evaluation[0].failure_codes) -join '|') -ceq
            (@($expected.failure_codes) -join '|')
    ) "retained cell evidence changed: $([string]$expected.cell_id)"

    $tracePath = Join-Path (
        Join-Path $artifactRoot ([string]$expected.trace_cas_sha256).Substring(7)
    ) "payload.bin"
    $observed = [ordered]@{
        rows = 0
        full = 0
        blend = 0
        floor = 0
        first_reduced = $null
        first_floor = $null
        first_gate_tilt = $null
        first_torso = $null
        saturated = 0
        limit_rows = @(0, 0, 0, 0, 0, 0, 0, 0)
    }
    foreach ($line in [IO.File]::ReadLines($tracePath)) {
        $row = $line | ConvertFrom-Json -AsHashtable -Depth 30
        $step = [int]$observed.rows
        $guard = $row.steering_authority_guard
        $commands = @($row.ordered_final_canonical_velocities_rad_s)
        $limits = @($row.ordered_actuator_velocity_limits_rad_s)
        $effective = [double]$guard.effective_maximum_steering_fraction
        Assert-R23D27Closure (
            [string]$row.schema_version -ceq
                "sporespore_qsdk_r23d27_physical_trace_row_v1" -and
            [string]$row.cell_id -ceq [string]$expected.cell_id -and
            [int]$row.trace_step -eq $step -and
            [string]$guard.schema_version -ceq
                "sporespore_steering_authority_guard_receipt_v1" -and
            [string]$guard.mode_id -ceq
                "tilt_and_contact_steering_authority_guard_v1" -and
            [bool]$guard.direction_neutral -and
            [int]$guard.engine_identity_input_count -eq 0 -and
            [int]$guard.minimum_support_contact_count -eq 2 -and
            [double]$guard.baseline_maximum_steering_fraction -eq 0.20 -and
            [double]$guard.expanded_maximum_steering_fraction -eq 0.28 -and
            $effective -ge 0.20 -and $effective -le 0.28 -and
            $commands.Count -eq 8 -and $limits.Count -eq 8
        ) "trace identity changed: $([string]$expected.cell_id) step=$step"
        if ([Math]::Abs($effective - 0.28) -le $tolerance) {
            $observed.full++
        } elseif ([Math]::Abs($effective - 0.20) -le $tolerance) {
            $observed.floor++
        } else {
            $observed.blend++
        }
        if ($null -eq $observed.first_reduced -and $effective -lt 0.28 - $tolerance) {
            $observed.first_reduced = $step
        }
        if ($null -eq $observed.first_floor -and
            [Math]::Abs($effective - 0.20) -le $tolerance) {
            $observed.first_floor = $step
        }
        if ($null -eq $observed.first_gate_tilt -and [double]$row.torso_tilt_rad -gt 0.6) {
            $observed.first_gate_tilt = $step
        }
        if ($null -eq $observed.first_torso -and [bool]$row.torso_ground_contact) {
            $observed.first_torso = $step
        }
        if ([bool]$row.steering_saturated) { $observed.saturated++ }
        for ($index = 0; $index -lt 8; $index++) {
            $command = [double]$commands[$index]
            $limit = [double]$limits[$index]
            Assert-R23D27Closure (
                [double]::IsFinite($command) -and [double]::IsFinite($limit) -and
                $limit -gt 0.0 -and [Math]::Abs($command) -le $limit + $tolerance
            ) "actuator command or limit changed: $([string]$expected.cell_id) step=$step index=$index"
            if ([Math]::Abs([Math]::Abs($command) - $limit) -le $tolerance) {
                $observed.limit_rows[$index]++
            }
        }
        $observed.rows++
    }
    $guardExpected = $guardByArm[[string]$expected.arm_id]
    Assert-R23D27Closure (
        [int]$observed.rows -eq [int]$expected.trace_row_count -and
        [int]$observed.full -eq [int]$guardExpected.full_authority_rows -and
        [int]$observed.blend -eq [int]$guardExpected.blended_authority_rows -and
        [int]$observed.floor -eq [int]$guardExpected.floor_authority_rows -and
        $observed.first_reduced -eq $guardExpected.first_reduced_step -and
        $observed.first_floor -eq $guardExpected.first_floor_step -and
        $observed.first_torso -eq $guardExpected.first_torso_contact_step -and
        [int]$observed.saturated -eq [int]$guardExpected.steering_saturated_rows -and
        (@($observed.limit_rows) -join '|') -ceq
            (@($guardExpected.actuator_limit_rows_by_order) -join '|')
    ) "guard or actuator trace projection changed: $([string]$expected.cell_id)"
    if ([string]$expected.arm_id -cne "reference_zero") {
        Assert-R23D27Closure (
            $observed.first_gate_tilt -eq $guardExpected.first_gate_tilt_failure_step
        ) "first tilt failure changed: $([string]$expected.cell_id)"
    } else {
        Assert-R23D27Closure ($null -eq $observed.first_gate_tilt) (
            "reference unexpectedly crossed tilt gate"
        )
    }
}

$qualification = $closure.campaign_local_qualification
Assert-R23D27Closure (
    (Get-R23D27GitBlobSha256 $sourceCommit `
        "sdk/turning/r23d27_stability_guarded_steering_preregistration_v1.json") -ceq
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
    [string]$qualification.commissioned_executor_raw_sha256 -ceq
        (Get-R23D27GitBlobSha256 $sourceCommit "sdk/run_conformance.ps1") -and
    [bool]$qualification.commissioned_executor_verified -and
    [bool]$qualification.physical_launch_prerequisite_satisfied -and
    -not [bool]$qualification.physical_acceptance_authority
) "campaign-local qualification receipt changed"

Assert-R23D27Closure (
    @($closure.pre_world_incidents).Count -eq 2 -and
    (@($closure.pre_world_incidents.world_attempt_count) | Measure-Object -Sum).Sum -eq 0 -and
    (@($closure.pre_world_incidents.world_build_count) | Measure-Object -Sum).Sum -eq 0 -and
    @($closure.pre_world_incidents | Where-Object { [bool]$_.identity_consumed }).Count -eq 0 -and
    [bool]$closure.guard_observability.all_rows_have_guard_receipt_and_eight_commands_and_limits -and
    [bool]$closure.guard_observability.all_commands_within_declared_actuator_limits -and
    -not [bool]$closure.guard_observability.single_limiting_actuator_inferred -and
    -not [bool]$closure.mechanism.threshold_change_authorized -and
    -not [bool]$closure.mechanism.same_identity_rerun_authorized -and
    -not [bool]$closure.claims.finite_rapier_turning_validation -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.turning_validation -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "incident, mechanism, observability, or claim boundary changed"

$refusal = & pwsh -NoLogo -NoProfile -File $supervisorPath -RunPhysical 2>&1 |
    Out-String
Assert-R23D27Closure (
    $LASTEXITCODE -eq 0 -and
    $refusal.Contains("QSDK_R23D27_PHYSICAL_REFUSAL") -and
    $refusal.Contains('"reason":"r23d27_identity_closed"') -and
    $refusal.Contains('"world_attempt_count":0') -and
    $refusal.Contains('"world_build_count":0')
) "same-identity physical refusal changed: $refusal"

Write-Host (
    "QSDK_R23D27_CLOSURE_PASS candidates=1 cells=3 worlds=3 valid=3 " +
    "positive=1 negative=2 selected=NONE blob_bindings=206 " +
    "guard_rows=8976 actuator_vectors=8976 preworld_incidents=2 " +
    "rerun=False three_engine=False equivalence=False release=False"
)
