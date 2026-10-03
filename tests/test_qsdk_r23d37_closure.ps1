#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d37_mujoco_policy_seed_isolation_closure_v1.json"
)
$artifactRoot = Join-Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) "artifacts\sha256"
$sourceCommit = "1235008d7da676e619e17b50f98735965c5a44e7"
$cellId = "mujoco__r23d21_same_seed_policy_isolation__reference_zero"

function Assert-R23D37([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D37 CLOSURE: $Message" }
}

function Assert-Close(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D37 ([Math]::Abs($Actual - $Expected) -le $Tolerance) $Message
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-CasPayload([string]$Sha256) {
    Assert-R23D37 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    return Join-Path (Join-Path $artifactRoot $Sha256.Substring(7)) "payload.bin"
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    $payload = Get-CasPayload $Sha256
    $manifest = Join-Path (Split-Path -Parent $payload) "manifest.json"
    Assert-R23D37 (Test-Path -LiteralPath $payload -PathType Leaf) (
        "CAS payload missing: $Sha256"
    )
    Assert-R23D37 (Test-Path -LiteralPath $manifest -PathType Leaf) (
        "CAS manifest missing: $Sha256"
    )
    Assert-R23D37 ((Get-Item -LiteralPath $payload).Length -eq $ByteLength) (
        "CAS payload length changed: $Sha256"
    )
    Assert-R23D37 ((Get-Sha256 $payload) -ceq $Sha256) (
        "CAS payload digest changed: $Sha256"
    )
    $record = Get-Content -Raw -LiteralPath $manifest | ConvertFrom-Json -Depth 20
    Assert-R23D37 (
        [string]$record.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$record.sha256 -ceq $Sha256 -and
        [long]$record.byte_length -eq $ByteLength -and
        [string]$record.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-Artifact($Record) {
    $path = [string]$Record.path
    Assert-R23D37 (Test-Path -LiteralPath $path -PathType Leaf) (
        "retained artifact missing: $path"
    )
    Assert-R23D37 ((Get-Item -LiteralPath $path).Length -eq [long]$Record.byte_length) (
        "retained artifact length changed: $path"
    )
    Assert-R23D37 ((Get-Sha256 $path) -ceq [string]$Record.sha256) (
        "retained artifact digest changed: $path"
    )
    $payload = Assert-Cas ([string]$Record.sha256) ([long]$Record.byte_length)
    Assert-R23D37 ((Get-Sha256 $payload) -ceq (Get-Sha256 $path)) (
        "retained artifact and CAS diverged: $path"
    )
}

$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json -Depth 100
Assert-R23D37 (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d37_mujoco_policy_seed_isolation_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_negative_policy_seed_isolation" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D37-MUJOCO-R23D21-POLICY-SEED-ISOLATION" -and
    [string]$closure.gate_id -ceq "QSDK-R23D37" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$closure.attempt_id -ceq "fe75493747d544559be7db1356972b0c" -and
    [int]$closure.campaign_seed -eq 21507 -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    -not [bool]$closure.successor_campaign_opened
) "closure identity changed"

foreach ($property in @(
    "preregistration", "implementation", "campaign_attestation_manifest",
    "worker", "design", "evaluator", "supervisor", "strict_array_writer"
)) {
    $pathProperty = "${property}_path"
    $hashProperty = "${property}_raw_sha256"
    $relative = [string]$closure.prospective_inputs.$pathProperty
    Assert-R23D37 (
        (Get-Sha256 (Join-Path $repoRoot $relative)) -ceq
            [string]$closure.prospective_inputs.$hashProperty
    ) "prospective input changed: $relative"
}

$evidenceRecords = @(
    $closure.physical_evidence.physical_freeze,
    $closure.physical_evidence.attempt_authorization,
    $closure.physical_evidence.terminal_manifest,
    $closure.physical_evidence.complete_evaluation,
    $closure.physical_evidence.report,
    $closure.physical_evidence.completion,
    $closure.physical_evidence.stdout,
    $closure.physical_evidence.stderr,
    $closure.physical_evidence.terminal,
    $closure.physical_evidence.pending_rows,
    $closure.physical_evidence.trace
)
foreach ($record in $evidenceRecords) { Assert-Artifact $record }
Assert-Artifact ([pscustomobject]@{
    path = $closure.qualification.attestation_path
    sha256 = $closure.qualification.attestation_sha256
    byte_length = $closure.qualification.attestation_byte_length
})
Assert-Artifact ([pscustomobject]@{
    path = $closure.qualification.adoption_path
    sha256 = $closure.qualification.adoption_sha256
    byte_length = $closure.qualification.adoption_byte_length
})

$attemptFiles = @(Get-ChildItem -LiteralPath (
    [string]$closure.physical_evidence.attempt_root
) -Recurse -File)
Assert-R23D37 (
    $attemptFiles.Count -eq 11 -and
    [int]$closure.physical_evidence.complete_attempt_file_count -eq 11 -and
    [bool]$closure.physical_evidence.complete_attempt_files_content_addressed -and
    [bool]$closure.physical_evidence.pending_rows.content_addressed_during_closure_without_byte_change
) "complete attempt inventory changed"
foreach ($file in $attemptFiles) {
    [void](Assert-Cas (Get-Sha256 $file.FullName) ([long]$file.Length))
}

$attestation = Get-Content -Raw -LiteralPath (
    [string]$closure.qualification.attestation_path
) | ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath (
    [string]$closure.qualification.adoption_path
) | ConvertFrom-Json -Depth 100
Assert-R23D37 (
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq
        [string]$closure.source_tree_git_oid -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 4 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 19 -and
    [bool]$attestation.all_gates_executed -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [int]$adoption.executed_gate_count -eq 19 -and
    [int]$adoption.gate_cas_object_count -eq 57 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification or adoption changed"

$freeze = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.physical_freeze.path
) | ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.attempt_authorization.path
) | ConvertFrom-Json -Depth 100
$evaluation = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.complete_evaluation.path
) | ConvertFrom-Json -Depth 100
$report = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.report.path
) | ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.completion.path
) | ConvertFrom-Json -Depth 100

Assert-R23D37 (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d37_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq [string]$closure.source_tree_git_oid -and
    [string]$freeze.origin_main_commit -ceq $sourceCommit -and
    [string]$freeze.live_github_main_commit -ceq $sourceCommit -and
    [int]$freeze.declared_world_count -eq 1 -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority -and
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.operation_lock_held -and
    [bool]$attempt.campaign_attestation_adoption_valid -and
    [bool]$attempt.content_addressed_inputs_retained -and
    [bool]$attempt.one_shot_attempt_unconsumed
) "freeze or authorization changed"

Assert-R23D37 (
    @($freeze.source_bindings).Count -eq 63 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 63
) "source binding count changed"
for ($index = 0; $index -lt @($freeze.source_bindings).Count; $index++) {
    $binding = $freeze.source_bindings[$index]
    $retained = $freeze.content_addressed_inputs.source_bindings[$index]
    $relative = [string]$binding.path
    $payload = Assert-Cas ([string]$retained.sha256) ([long]$retained.byte_length)
    Assert-R23D37 (
        [bool]$binding.raw_checkout_equals_git_blob -and
        [string]$retained.sha256 -ceq [string]$binding.raw_sha256 -and
        (git -C $repoRoot rev-parse "${sourceCommit}:$relative").Trim() -ceq
            [string]$binding.git_blob_oid -and
        (git -C $repoRoot hash-object --no-filters -- $payload).Trim() -ceq
            [string]$binding.git_blob_oid
    ) "source commit, checkout, and CAS diverged: $relative"
}
Assert-R23D37 (
    @($freeze.runtime_artifacts).Count -eq 1 -and
    @($freeze.external_runtime_bindings).Count -eq 3 -and
    @($freeze.content_addressed_inputs.runtime_bindings).Count -eq 4 -and
    [string]$freeze.runtime_artifacts[0].raw_sha256 -ceq
        "sha256:304da183803c061964412540d02e2df15defbb7dda525d5724a42017690422cd" -and
    [bool]$freeze.runtime_artifacts[0].build_receipt.msvc_brepro -and
    [bool]$freeze.runtime_artifacts[0].build_receipt.pdb_alt_path_bare_name
) "runtime freeze changed"
foreach ($runtime in @($freeze.content_addressed_inputs.runtime_bindings)) {
    [void](Assert-Cas ([string]$runtime.sha256) ([long]$runtime.byte_length))
}

$manifest = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.terminal_manifest.path
) | ConvertFrom-Json -NoEnumerate -Depth 20
Assert-R23D37 (
    $manifest -is [Array] -and @($manifest).Count -eq 1 -and
    [string]$manifest[0] -ceq
        [string]$closure.physical_evidence.terminal.cas_payload_path -and
    [string]$closure.official_result.terminal_manifest_json_type -ceq "array" -and
    [int]$closure.official_result.terminal_manifest_element_count -eq 1 -and
    [bool]$closure.official_result.strict_array_boundary_physically_held
) "strict one-element terminal manifest changed"

$terminal = Get-Content -Raw -LiteralPath ([string]$manifest[0]) |
    ConvertFrom-Json -Depth 100
Assert-R23D37 (
    [string]$terminal.schema_version -ceq
        "sporespore_qsdk_r23d37_engine_cell_report_v1" -and
    [string]$terminal.campaign_id -ceq [string]$closure.campaign_id -and
    [string]$terminal.gate_id -ceq "QSDK-R23D37" -and
    [string]$terminal.source_commit -ceq $sourceCommit -and
    [string]$terminal.cell_id -ceq $cellId -and
    [string]$terminal.engine_id -ceq "mujoco" -and
    [string]$terminal.arm_id -ceq "reference_zero" -and
    [bool]$terminal.execution.integrity_passed -and
    [int]$terminal.execution.world_attempt_count -eq 1 -and
    [int]$terminal.execution.world_build_count -eq 1 -and
    [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
    [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
    [bool]$terminal.execution.trace_retained_before_terminal_entry -and
    -not [bool]$terminal.claims.finite_mujoco_r23d21_seed_21507_walking -and
    -not [bool]$terminal.claims.mujoco_r23d29_turning -and
    -not [bool]$terminal.claims.cross_engine_equivalence -and
    -not [bool]$terminal.claims.release_authorized -and
    -not [bool]$terminal.claims.physical_acceptance_authority
) "terminal identity, execution, or claims changed"

$failed = @($evaluation.cell_evaluations[0].failed_gate_ids)
Assert-R23D37 (
    [string]$evaluation.classification -ceq
        "valid_complete_negative_policy_seed_isolation" -and
    [bool]$evaluation.cell_evaluations[0].execution_valid -and
    -not [bool]$evaluation.cell_evaluations[0].common_physical_gate_passed -and
    ($failed -join ',') -ceq
        "R23D34_FORWARD_DISPLACEMENT,R23D34_MAXIMUM_TILT,R23D34_CONTACT_CYCLES,R23D34_TORSO_GROUND_CONTACT" -and
    [bool]$evaluation.outcome_exposed_development_screen -and
    -not [bool]$evaluation.fresh_held_out_condition_consumed -and
    -not [bool]$evaluation.turning_tested -and
    [string]$report.result_classification -ceq [string]$evaluation.classification -and
    [string]$completion.status -ceq [string]$evaluation.classification -and
    [int]$completion.world_count -eq 1 -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted
) "complete evaluation or one-shot completion changed"

$tracePath = Assert-Cas (
    [string]$closure.physical_evidence.trace.sha256
) ([long]$closure.physical_evidence.trace.byte_length)
$comparatorPath = Assert-Cas (
    [string]$closure.same_seed_comparator.comparator_trace_sha256
) 4157684
$rows = @(Get-Content -LiteralPath $tracePath)
$comparatorRows = @(Get-Content -LiteralPath $comparatorPath)
Assert-R23D37 ($rows.Count -eq 2992 -and $comparatorRows.Count -eq 2992) (
    "trace row count changed"
)

$firstRequested = -1
$firstHeld = -1
$firstState = -1
$firstContactsBefore = -1
$firstContactsAfter = -1
$limbPhaseDifference = $false
$firstTilt = -1
$firstContact = -1
$traceContactRows = 0
$maxTilt = 0.0
$minHeight = [double]::PositiveInfinity
$maxRequested = 0.0
$maxHeld = 0.0
$saturatedRows = 0
$maximumRequestedDifference = 0.0
$maximumHeldDifference = 0.0
$maximumTiltDifference = 0.0
$cycles = @{ front_left = 0; front_right = 0; rear_left = 0; rear_right = 0 }
$previous = @{ front_left = $true; front_right = $true; rear_left = $true; rear_right = $true }
$step133 = $null
$comparator133 = $null
$step175 = $null
$comparator175 = $null

for ($index = 0; $index -lt $rows.Count; $index++) {
    $row = $rows[$index] | ConvertFrom-Json -Depth 30
    $comparator = $comparatorRows[$index] | ConvertFrom-Json -Depth 30
    Assert-R23D37 (
        [string]$row.schema_version -ceq
            "sporespore_qsdk_r23d3_turn_diagnostic_trace_row_v1" -and
        [string]$row.cell_id -ceq $cellId -and
        [int]$row.semantic_step -eq $index -and
        [string]$row.segment_id -ceq "reference_walk" -and
        [double]$row.desired_heading_offset_rad -eq 0.0 -and
        [int]$row.validated_portable_command_count -eq 8 -and
        [int]$row.native_actuation_application_count -eq 8 -and
        [bool]$row.oracle_passed
    ) "trace integrity changed at step $index"

    $requestedDifference = [Math]::Abs(
        [double]$row.requested_steering_fraction -
        [double]$comparator.requested_steering_fraction
    )
    $heldDifference = [Math]::Abs(
        [double]$row.held_steering_fraction -
        [double]$comparator.held_steering_fraction
    )
    $tiltDifference = [Math]::Abs(
        [double]$row.torso_tilt_rad - [double]$comparator.torso_tilt_rad
    )
    if ($firstRequested -lt 0 -and $requestedDifference -gt 1.0e-15) {
        $firstRequested = $index
    }
    if ($firstHeld -lt 0 -and $heldDifference -gt 1.0e-15) {
        $firstHeld = $index
    }
    if ($firstState -lt 0 -and (
        $tiltDifference -gt 1.0e-15 -or
        [Math]::Abs([double]$row.torso_height_m - [double]$comparator.torso_height_m) -gt
            1.0e-15
    )) { $firstState = $index }
    if ($firstContactsBefore -lt 0 -and
        ($row.ordered_foot_contacts_before | ConvertTo-Json -Compress) -cne
        ($comparator.ordered_foot_contacts_before | ConvertTo-Json -Compress)) {
        $firstContactsBefore = $index
    }
    if ($firstContactsAfter -lt 0 -and
        ($row.ordered_foot_contacts_after | ConvertTo-Json -Compress) -cne
        ($comparator.ordered_foot_contacts_after | ConvertTo-Json -Compress)) {
        $firstContactsAfter = $index
    }
    if (($row.ordered_limb_phase_before | ConvertTo-Json -Depth 10 -Compress) -cne
        ($comparator.ordered_limb_phase_before | ConvertTo-Json -Depth 10 -Compress)) {
        $limbPhaseDifference = $true
    }
    $maximumRequestedDifference = [Math]::Max(
        $maximumRequestedDifference, $requestedDifference
    )
    $maximumHeldDifference = [Math]::Max($maximumHeldDifference, $heldDifference)
    $maximumTiltDifference = [Math]::Max($maximumTiltDifference, $tiltDifference)

    $tilt = [double]$row.torso_tilt_rad
    $height = [double]$row.torso_height_m
    $maxTilt = [Math]::Max($maxTilt, $tilt)
    $minHeight = [Math]::Min($minHeight, $height)
    $maxRequested = [Math]::Max(
        $maxRequested, [Math]::Abs([double]$row.requested_steering_fraction)
    )
    $maxHeld = [Math]::Max(
        $maxHeld, [Math]::Abs([double]$row.held_steering_fraction)
    )
    if ($firstTilt -lt 0 -and $tilt -gt 0.6) { $firstTilt = $index }
    if ([bool]$row.torso_ground_contact) {
        $traceContactRows++
        if ($firstContact -lt 0) { $firstContact = $index }
    }
    if ([bool]$row.steering_saturated) { $saturatedRows++ }
    if ($index -ge 472) {
        foreach ($limb in @("front_left", "front_right", "rear_left", "rear_right")) {
            $present = [bool]$row.ordered_foot_contacts_after.$limb
            if (-not $previous[$limb] -and $present) { $cycles[$limb]++ }
            $previous[$limb] = $present
        }
    }
    if ($index -eq 133) { $step133 = $row; $comparator133 = $comparator }
    if ($index -eq 175) { $step175 = $row; $comparator175 = $comparator }
}

$measurements = $terminal.measurements
Assert-R23D37 (
    $firstTilt -eq 153 -and $firstContact -eq 193 -and
    $traceContactRows -eq 2784 -and $saturatedRows -eq 1993 -and
    $cycles.front_left -eq 0 -and $cycles.front_right -eq 0 -and
    $cycles.rear_left -eq 18 -and $cycles.rear_right -eq 25 -and
    [int]$measurements.torso_ground_contact_step_count -eq 2785 -and
    [int]$measurements.controller_error_count -eq 0 -and
    [int]$measurements.safe_no_actuation_count -eq 0 -and
    [int]$measurements.nonfinite_observation_count -eq 0 -and
    [int]$measurements.actuator_application_mismatch_count -eq 0
) "trace-derived walking result changed"
Assert-Close $maxTilt 1.8316205777362669 1.0e-12 "maximum tilt changed"
Assert-Close $minHeight 0.2507483361149111 1.0e-12 "minimum height changed"
Assert-Close $maxRequested 0.4 1.0e-12 "maximum requested steering changed"
Assert-Close $maxHeld 0.3999965685122699 1.0e-12 "maximum held steering changed"
Assert-Close ([double]$measurements.final_forward_displacement_m) (
    -0.5908297647386241
) 1.0e-12 "final displacement changed"

$comparison = $closure.same_seed_comparator
Assert-R23D37 (
    $firstRequested -eq 134 -and $firstHeld -eq 134 -and
    $firstState -eq 135 -and $firstContactsAfter -eq 272 -and
    $firstContactsBefore -eq 273 -and -not $limbPhaseDifference -and
    [double]$step133.requested_steering_fraction -eq
        [double]$comparator133.requested_steering_fraction -and
    [double]$step133.held_steering_fraction -eq
        [double]$comparator133.held_steering_fraction -and
    [double]$step133.torso_tilt_rad -eq [double]$comparator133.torso_tilt_rad -and
    [double]$comparator175.requested_steering_fraction -eq -0.2 -and
    [double]$step175.requested_steering_fraction -eq -0.4 -and
    [int]$comparison.first_requested_and_held_steering_difference_semantic_step -eq 134 -and
    [int]$comparison.first_torso_state_difference_semantic_step -eq 135 -and
    -not [bool]$comparison.limb_phase_sequence_difference_observed -and
    [bool]$comparison.both_policies_fell_before_turn_onset_step_600
) "same-seed comparator mechanism changed"
Assert-Close $maximumRequestedDifference 0.6000000000000001 1.0e-12 (
    "maximum requested-steering difference changed"
)
Assert-Close $maximumHeldDifference 0.33185663890396 1.0e-12 (
    "maximum held-steering difference changed"
)
Assert-Close $maximumTiltDifference 0.21605658305159925 1.0e-12 (
    "maximum tilt difference changed"
)

Assert-R23D37 (
    [string]$closure.official_result.classification -ceq
        "valid_complete_negative_policy_seed_isolation" -and
    [bool]$closure.official_result.execution_valid -and
    -not [bool]$closure.official_result.common_physical_gate_passed -and
    [bool]$closure.official_result.scientific_selector_legally_completed -and
    [bool]$closure.bounded_interpretation.fixture_sensitive_baseline_stabilization_required_before_turning -and
    -not [bool]$closure.bounded_interpretation.finite_mujoco_r23d21_seed_21507_walking -and
    -not [bool]$closure.bounded_interpretation.policy_isolation_restored_this_fixture -and
    -not [bool]$closure.bounded_interpretation.r23d21_to_r23d29_policy_change_is_sufficient_cause_of_failure -and
    -not [bool]$closure.bounded_interpretation.mujoco_turning_exposed -and
    -not [bool]$closure.claims.finite_mujoco_r23d21_seed_21507_walking -and
    -not [bool]$closure.claims.mujoco_r23d29_unassisted_walking -and
    -not [bool]$closure.claims.mujoco_r23d29_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "bounded interpretation or claims changed"

$refusalRoot = Join-Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) "qsdk-r23d37-rerun-refusal"
Assert-R23D37 (-not (Test-Path -LiteralPath $refusalRoot)) (
    "rerun-refusal output unexpectedly exists before the negative control"
)

$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$workerModule = (
    "sporespore_mujoco_adapter.qsdk_r23d37_policy_seed_isolation"
)
$originalPythonPath = [Environment]::GetEnvironmentVariable(
    "PYTHONPATH", "Process"
)
try {
    [Environment]::SetEnvironmentVariable(
        "PYTHONPATH",
        (@(
            (Join-Path $sdkRoot "python"),
            $mujocoRoot,
            (Join-Path $mujocoRoot ".venv\Lib\site-packages"),
            (Join-Path $sdkRoot "turning")
        ) -join [IO.Path]::PathSeparator),
        "Process"
    )
    $workerRefusal = @(
        & python -m $workerModule preflight `
            --stage "mujoco_r23d21_same_seed_policy_isolation" `
            --onset "onset_600" --arm "reference_zero" 2>&1
    ) | Out-String
    $workerExitCode = $LASTEXITCODE
} finally {
    [Environment]::SetEnvironmentVariable(
        "PYTHONPATH", $originalPythonPath, "Process"
    )
}
Assert-R23D37 (
    $workerExitCode -ne 0 -and
    $workerRefusal.Contains('"failure_code":"QSDK_R23D37_MJC_CLOSED"') -and
    -not (Test-Path -LiteralPath $refusalRoot)
) "closed worker identity refusal changed: $workerRefusal"

$supervisor = Join-Path $repoRoot "sdk\run_qsdk_r23d37_supervisor.ps1"
$refusal = @(
    & pwsh -NoLogo -NoProfile -File $supervisor -RunPhysical `
        -CampaignAttestationAdoption ([string]$closure.qualification.adoption_path) `
        -OutputRoot $refusalRoot -Python python 2>&1
) | Out-String
Assert-R23D37 (
    $LASTEXITCODE -ne 0 -and
    $refusal.Contains("campaign-attestation adoption failed") -and
    $refusal.Contains("SOURCE_COMMIT") -and
    $refusal.Contains("SOURCE_TREE_GIT_OID") -and
    -not (Test-Path -LiteralPath $refusalRoot)
) "closed-source supervisor refusal changed: $refusal"

Write-Host (
    "QSDK_R23D37_CLOSURE_PASS classification=valid_complete_negative " +
    "cells=1 worlds=1 trace_rows=2992 manifest_array=1 " +
    "first_torso_contact=193 policy_difference_step=134 " +
    "turning=False rerun=False successor_open=False"
)
