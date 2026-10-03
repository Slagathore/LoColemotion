#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d38_mujoco_startup_ramp_stabilization_closure_v1.json"
)
$artifactRoot = Join-Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) "artifacts\sha256"
$sourceCommit = "6035f09deae3b5418c54fdeba458b6a8b7e30190"
$cellId = "mujoco__r23d29_startup_ramp_stabilization__reference_zero"

function Assert-R23D38([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D38 CLOSURE: $Message" }
}

function Assert-Close(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D38 ([Math]::Abs($Actual - $Expected) -le $Tolerance) $Message
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D38 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D38 (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D38 (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-Artifact($Record) {
    $path = [string]$Record.path
    Assert-R23D38 (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$Record.byte_length -and
        (Get-Sha256 $path) -ceq [string]$Record.sha256
    ) "retained artifact changed: $path"
    $payload = Assert-Cas ([string]$Record.sha256) ([long]$Record.byte_length)
    Assert-R23D38 ((Get-Sha256 $payload) -ceq (Get-Sha256 $path)) (
        "retained artifact and CAS differ: $path"
    )
}

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D38 (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d38_mujoco_startup_ramp_stabilization_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_positive_startup_ramp_stabilization" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D38-MUJOCO-R23D29-STARTUP-RAMP-STABILIZATION" -and
    [string]$closure.gate_id -ceq "QSDK-R23D38" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$($sourceCommit)^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$closure.attempt_id -ceq "dfa9d90ce1ee4b1c9d4555674b96f137" -and
    [int]$closure.campaign_seed -eq 21507 -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    -not [bool]$closure.successor_campaign_opened
) "closure identity changed"

Assert-R23D38 (
    [string]$closure.preworld_incident.status -ceq
        "closed_preworld_qualification_failure" -and
    [int]$closure.preworld_incident.physical_world_count -eq 0 -and
    -not [bool]$closure.preworld_incident.physical_identity_consumed -and
    -not [bool]$closure.preworld_incident.scientific_result
) "retained preworld incident changed"

$freeze = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.physical_freeze.path
) | ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.attempt_authorization.path
) | ConvertFrom-Json -Depth 100

$prospectiveNames = @(
    "preregistration", "implementation", "campaign_attestation_manifest",
    "worker", "design", "evaluator", "supervisor", "lineage_gate",
    "strict_array_writer"
)
foreach ($name in $prospectiveNames) {
    $relative = [string]$closure.prospective_inputs."$($name)_path"
    $expectedRaw = [string]$closure.prospective_inputs."$($name)_raw_sha256"
    $indices = @(
        for ($index = 0; $index -lt @($freeze.source_bindings).Count; $index++) {
            if ([string]$freeze.source_bindings[$index].path -ceq $relative) {
                $index
            }
        }
    )
    Assert-R23D38 ($indices.Count -eq 1) "source binding missing: $relative"
    $binding = $freeze.source_bindings[$indices[0]]
    $retained = $freeze.content_addressed_inputs.source_bindings[$indices[0]]
    Assert-R23D38 (
        [string]$binding.raw_sha256 -ceq $expectedRaw -and
        [string]$retained.sha256 -ceq $expectedRaw -and
        (git -C $repoRoot rev-parse "$($sourceCommit):$relative").Trim() -ceq
            [string]$binding.git_blob_oid -and
        [bool]$binding.raw_checkout_equals_git_blob
    ) "frozen prospective source changed: $relative"
    [void](Assert-Cas ([string]$retained.sha256) ([long]$retained.byte_length))
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
Assert-R23D38 (
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
Assert-R23D38 (
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq
        [string]$closure.source_tree_git_oid -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 5 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 20 -and
    [bool]$attestation.all_gates_executed -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [int]$adoption.executed_gate_count -eq 20 -and
    [int]$adoption.gate_cas_object_count -eq 60 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification or adoption changed"

Assert-R23D38 (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d38_physical_freeze_v1" -and
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
Assert-R23D38 (
    @($freeze.source_bindings).Count -eq 66 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 66 -and
    @($freeze.runtime_artifacts).Count -eq 1 -and
    @($freeze.external_runtime_bindings).Count -eq 3 -and
    @($freeze.content_addressed_inputs.runtime_bindings).Count -eq 4 -and
    [string]$freeze.runtime_artifacts[0].raw_sha256 -ceq
        "sha256:304da183803c061964412540d02e2df15defbb7dda525d5724a42017690422cd" -and
    [bool]$freeze.runtime_artifacts[0].build_receipt.msvc_brepro -and
    [bool]$freeze.runtime_artifacts[0].build_receipt.pdb_alt_path_bare_name
) "source or reproducible runtime freeze changed"
for ($index = 0; $index -lt @($freeze.source_bindings).Count; $index++) {
    $binding = $freeze.source_bindings[$index]
    $retained = $freeze.content_addressed_inputs.source_bindings[$index]
    $relative = [string]$binding.path
    $payload = Assert-Cas ([string]$retained.sha256) ([long]$retained.byte_length)
    Assert-R23D38 (
        [bool]$binding.raw_checkout_equals_git_blob -and
        [string]$retained.sha256 -ceq [string]$binding.raw_sha256 -and
        (git -C $repoRoot rev-parse "$($sourceCommit):$relative").Trim() -ceq
            [string]$binding.git_blob_oid -and
        (git -C $repoRoot hash-object --no-filters -- $payload).Trim() -ceq
            [string]$binding.git_blob_oid
    ) "source commit, checkout, and CAS differ: $relative"
}
foreach ($runtime in @($freeze.content_addressed_inputs.runtime_bindings)) {
    [void](Assert-Cas ([string]$runtime.sha256) ([long]$runtime.byte_length))
}

$manifest = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.terminal_manifest.path
) | ConvertFrom-Json -NoEnumerate -Depth 20
Assert-R23D38 (
    $manifest -is [Array] -and @($manifest).Count -eq 1 -and
    [string]$manifest[0] -ceq
        [string]$closure.physical_evidence.terminal.cas_payload_path -and
    [string]$closure.official_result.terminal_manifest_json_type -ceq "array" -and
    [int]$closure.official_result.terminal_manifest_element_count -eq 1 -and
    [bool]$closure.official_result.strict_array_boundary_physically_held
) "strict one-element terminal manifest changed"

$terminal = Get-Content -Raw -LiteralPath ([string]$manifest[0]) |
    ConvertFrom-Json -Depth 100
$evaluation = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.complete_evaluation.path
) | ConvertFrom-Json -Depth 100
$report = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.report.path
) | ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.completion.path
) | ConvertFrom-Json -Depth 100
Assert-R23D38 (
    [string]$terminal.schema_version -ceq
        "sporespore_qsdk_r23d38_engine_cell_report_v1" -and
    [string]$terminal.source_commit -ceq $sourceCommit -and
    [string]$terminal.cell_id -ceq $cellId -and
    [bool]$terminal.execution.integrity_passed -and
    [int]$terminal.execution.world_attempt_count -eq 1 -and
    [int]$terminal.execution.world_build_count -eq 1 -and
    [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
    [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
    [bool]$terminal.execution.trace_retained_before_terminal_entry -and
    [string]$evaluation.classification -ceq
        "valid_complete_positive_startup_ramp_stabilization" -and
    [bool]$evaluation.cell_evaluations[0].execution_valid -and
    [bool]$evaluation.cell_evaluations[0].common_physical_gate_passed -and
    @($evaluation.cell_evaluations[0].failed_gate_ids).Count -eq 0 -and
    [string]$report.result_classification -ceq [string]$evaluation.classification -and
    [string]$completion.status -ceq [string]$evaluation.classification -and
    [int]$completion.world_count -eq 1 -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted
) "terminal, evaluation, or completion changed"

$tracePath = Assert-Cas (
    [string]$closure.physical_evidence.trace.sha256
) ([long]$closure.physical_evidence.trace.byte_length)
$traceLines = @(Get-Content -LiteralPath $tracePath)
Assert-R23D38 ($traceLines.Count -eq 2992) "trace row count changed"

$maximumTilt = 0.0
$minimumHeight = [double]::PositiveInfinity
$maximumRequested = 0.0
$maximumHeld = 0.0
$maximumResidual = 0.0
$torsoContactRows = 0
$activeRampRows = 0
$zeroScaleRows = 0
$unityScaleRows = 0
$firstX = 0.0
$lastX = 0.0
$cycles = @{ front_left = 0; front_right = 0; rear_left = 0; rear_right = 0 }
$previous = @{ front_left = $true; front_right = $true; rear_left = $true; rear_right = $true }

for ($index = 0; $index -lt $traceLines.Count; $index++) {
    $row = $traceLines[$index] | ConvertFrom-Json -Depth 30
    $expectedScale = if ($index -ge 359) { 1.0 } else {
        $progress = $index / 359.0
        $progress * $progress * (3.0 - 2.0 * $progress)
    }
    Assert-R23D38 (
        [string]$row.schema_version -ceq
            "sporespore_qsdk_r23d3_turn_diagnostic_trace_row_v1" -and
        [string]$row.cell_id -ceq $cellId -and
        [int]$row.semantic_step -eq $index -and
        [string]$row.segment_id -ceq "reference_walk" -and
        [double]$row.desired_heading_offset_rad -eq 0.0 -and
        [int]$row.validated_portable_command_count -eq 8 -and
        [int]$row.native_actuation_application_count -eq 8 -and
        [bool]$row.oracle_passed -and
        [string]$row.startup_ramp_id -ceq
            "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
        [Math]::Abs([double]$row.startup_velocity_scale - $expectedScale) -le
            1.0e-15 -and
        [bool]$row.startup_ramp_active -eq ($expectedScale -lt 1.0) -and
        [int]$row.startup_ramp_residual_count -eq 8 -and
        [double]$row.startup_ramp_maximum_absolute_residual_rad_s -ge 0.0
    ) "trace or ramp integrity changed at step $index"
    if ($index -eq 0) { $firstX = [double]$row.torso_position_world_m[0] }
    if ($index -eq 2991) { $lastX = [double]$row.torso_position_world_m[0] }
    $maximumTilt = [Math]::Max($maximumTilt, [double]$row.torso_tilt_rad)
    $minimumHeight = [Math]::Min($minimumHeight, [double]$row.torso_height_m)
    $maximumRequested = [Math]::Max(
        $maximumRequested, [Math]::Abs([double]$row.requested_steering_fraction)
    )
    $maximumHeld = [Math]::Max(
        $maximumHeld, [Math]::Abs([double]$row.held_steering_fraction)
    )
    $maximumResidual = [Math]::Max(
        $maximumResidual,
        [double]$row.startup_ramp_maximum_absolute_residual_rad_s
    )
    $torsoContactRows += [int][bool]$row.torso_ground_contact
    $activeRampRows += [int]($expectedScale -lt 1.0)
    $zeroScaleRows += [int]($expectedScale -eq 0.0)
    $unityScaleRows += [int]($expectedScale -eq 1.0)
    if ($index -ge 472) {
        foreach ($limb in @("front_left", "front_right", "rear_left", "rear_right")) {
            $present = [bool]$row.ordered_foot_contacts_after.$limb
            if (-not $previous[$limb] -and $present) { $cycles[$limb]++ }
            $previous[$limb] = $present
        }
    }
}

$measurements = $terminal.measurements
Assert-Close $firstX 0.00009633700047213353 1.0e-15 (
    "first retained torso position changed"
)
Assert-Close $lastX 1.6546335794294478 1.0e-12 (
    "last retained torso position changed"
)
Assert-Close ([double]$measurements.final_forward_displacement_m) (
    1.6546781589105957
) 1.0e-12 "task-origin final displacement changed"
Assert-Close $maximumTilt 0.07943305657545596 1.0e-12 (
    "trace-derived maximum tilt changed"
)
Assert-Close $minimumHeight 0.42452487260337624 1.0e-12 (
    "trace-derived minimum height changed"
)
Assert-Close $maximumRequested 0.09896958493486618 1.0e-12 (
    "maximum requested steering changed"
)
Assert-Close $maximumHeld 0.06777125189842469 1.0e-12 (
    "maximum held steering changed"
)
Assert-Close $maximumResidual 3.0 1.0e-12 "maximum ramp residual changed"
Assert-R23D38 (
    $torsoContactRows -eq 0 -and
    $activeRampRows -eq 359 -and
    $zeroScaleRows -eq 1 -and
    $unityScaleRows -eq 2633 -and
    $cycles.front_left -eq 28 -and
    $cycles.front_right -eq 33 -and
    $cycles.rear_left -eq 16 -and
    $cycles.rear_right -eq 18 -and
    [int]$measurements.controller_error_count -eq 0 -and
    [int]$measurements.safe_no_actuation_count -eq 0 -and
    [int]$measurements.nonfinite_observation_count -eq 0 -and
    [int]$measurements.actuator_application_mismatch_count -eq 0 -and
    [bool]$measurements.startup_ramp_composition_integrity_passed
) "trace-derived gate or ramp counts changed"

Assert-R23D38 (
    [string]$closure.official_result.classification -ceq
        "valid_complete_positive_startup_ramp_stabilization" -and
    [bool]$closure.official_result.execution_valid -and
    [bool]$closure.official_result.common_physical_gate_passed -and
    [bool]$closure.official_result.scientific_selector_legally_completed -and
    [bool]$closure.claims.finite_mujoco_r23d29_seed_21507_startup_ramp_walking -and
    -not [bool]$closure.claims.mujoco_r23d29_walking_restored -and
    -not [bool]$closure.claims.mujoco_r23d29_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.population_robustness -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "bounded interpretation or claims changed"

$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$savedPythonPath = $env:PYTHONPATH
$savedLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
try {
    $env:PYTHONPATH = (@(
        (Join-Path $sdkRoot "python"),
        $mujocoRoot,
        (Join-Path $mujocoRoot ".venv\Lib\site-packages"),
        (Join-Path $sdkRoot "turning")
    ) -join [IO.Path]::PathSeparator)
    $env:SPORESPORE_LOCOMOTION_LIBRARY = Join-Path (
        $sdkRoot
    ) "target\debug\sporespore_locomotion_core.dll"
    $refusal = @(
        & python -m sporespore_mujoco_adapter.qsdk_r23d38_startup_ramp_stabilization preflight --stage "mujoco_r23d29_startup_ramp_stabilization" --onset "onset_600" --arm "reference_zero" 2>&1
    ) | Out-String
    $refusalExitCode = $LASTEXITCODE
} finally {
    $env:PYTHONPATH = $savedPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $savedLibrary
}
Assert-R23D38 (
    $refusalExitCode -ne 0 -and
    $refusal.Contains('"failure_code":"QSDK_R23D38_MJC_CLOSED"')
) "closed R23D38 worker refusal changed: $refusal"

Write-Host (
    "QSDK_R23D38_CLOSURE_PASS classification=valid_complete_positive " +
    "cells=1 worlds=1 trace_rows=2992 displacement_m=1.6546781589105957 " +
    "max_tilt_rad=0.07943305657545596 torso_contacts=0 " +
    "startup_ramp=True turning=False rerun=False successor_open=False"
)
