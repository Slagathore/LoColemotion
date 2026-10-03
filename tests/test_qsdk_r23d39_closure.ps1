#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d39_mujoco_startup_ramp_turning_closure_v1.json"
)
$artifactRoot = Join-Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) "artifacts\sha256"
$sourceCommit = "3bc7b735155dedbe6657161a62537669396536f4"
$twoPi = 2.0 * [Math]::PI
$tolerance = 1.0e-12

function Assert-R23D39([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D39 CLOSURE: $Message" }
}

function Assert-Near(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D39 (
        [double]::IsFinite($Actual) -and
        [double]::IsFinite($Expected) -and
        [Math]::Abs($Actual - $Expected) -le $Tolerance
    ) $Message
}

function Assert-ArrayNear($Actual, $Expected, [double]$Tolerance, [string]$Message) {
    $actualValues = @($Actual)
    $expectedValues = @($Expected)
    Assert-R23D39 ($actualValues.Count -eq $expectedValues.Count) "$Message count"
    for ($index = 0; $index -lt $actualValues.Count; $index++) {
        Assert-Near (
            [double]$actualValues[$index]
        ) ([double]$expectedValues[$index]) $Tolerance "$Message index=$index"
    }
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D39 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D39 (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D39 (
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
    Assert-R23D39 (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$Record.byte_length -and
        (Get-Sha256 $path) -ceq [string]$Record.sha256
    ) "retained artifact changed: $path"
    $payload = Assert-Cas ([string]$Record.sha256) ([long]$Record.byte_length)
    Assert-R23D39 ((Get-Sha256 $payload) -ceq (Get-Sha256 $path)) (
        "retained artifact and CAS differ: $path"
    )
    return $payload
}

function Get-WindowMean($Values, [int]$Start, [int]$End) {
    $sum = 0.0
    for ($index = $Start; $index -lt $End; $index++) {
        $sum += [double]$Values[$index]
    }
    return $sum / [double]($End - $Start)
}

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D39 (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d39_mujoco_startup_ramp_turning_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_positive_mujoco_startup_ramp_turning_development" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D39-MUJOCO-R23D29-STARTUP-RAMP-TURNING-DEVELOPMENT" -and
    [string]$closure.gate_id -ceq "QSDK-R23D39" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$($sourceCommit)^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$closure.attempt_id -ceq "4db8fe11de69444e81efada5f06fe0a5" -and
    [int]$closure.campaign_seed -eq 21507 -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    -not [bool]$closure.successor_campaign_opened
) "closure identity changed"

foreach ($lineage in @("r23d31", "r23d32", "r23d35", "r23d38")) {
    $relative = [string]$closure.immutable_lineage."$($lineage)_closure_path"
    $expected = [string]$closure.immutable_lineage."$($lineage)_closure_raw_sha256"
    Assert-R23D39 ((Get-Sha256 (Join-Path $repoRoot $relative)) -ceq $expected) (
        "immutable lineage changed: $lineage"
    )
}
Assert-R23D39 (
    -not [bool]$closure.immutable_lineage.historical_result_reinterpreted -and
    -not [bool]$closure.immutable_lineage.historical_world_reused_as_r23d39_cell
) "lineage interpretation changed"

$freeze = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.physical_freeze.path
) | ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.attempt_authorization.path
) | ConvertFrom-Json -Depth 100

$prospectiveNames = @(
    "preregistration", "implementation", "campaign_attestation_manifest",
    "worker", "design", "evaluator", "supervisor", "lineage_gate",
    "cep1_gate", "strict_array_writer"
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
    Assert-R23D39 ($indices.Count -eq 1) "source binding missing: $relative"
    $binding = $freeze.source_bindings[$indices[0]]
    $retained = $freeze.content_addressed_inputs.source_bindings[$indices[0]]
    Assert-R23D39 (
        [string]$binding.raw_sha256 -ceq $expectedRaw -and
        [string]$retained.sha256 -ceq $expectedRaw -and
        (git -C $repoRoot rev-parse "$($sourceCommit):$relative").Trim() -ceq
            [string]$binding.git_blob_oid -and
        [bool]$binding.raw_checkout_equals_git_blob
    ) "frozen prospective source changed: $relative"
    [void](Assert-Cas ([string]$retained.sha256) ([long]$retained.byte_length))
}

$rootEvidence = @(
    $closure.physical_evidence.physical_freeze,
    $closure.physical_evidence.attempt_authorization,
    $closure.physical_evidence.terminal_manifest,
    $closure.physical_evidence.complete_evaluation,
    $closure.physical_evidence.report,
    $closure.physical_evidence.completion
)
foreach ($record in $rootEvidence) { [void](Assert-Artifact $record) }
foreach ($cell in @($closure.physical_evidence.cells)) {
    foreach ($name in @("stdout", "stderr", "terminal", "pending_rows", "trace")) {
        [void](Assert-Artifact $cell.$name)
    }
    Assert-R23D39 (
        [bool]$cell.pending_rows.content_addressed_during_closure_without_byte_change
    ) "pending-row retention flag changed: $($cell.arm_id)"
}
foreach ($qualificationRecord in @(
    [pscustomobject]@{
        path = $closure.qualification.attestation_path
        sha256 = $closure.qualification.attestation_sha256
        byte_length = $closure.qualification.attestation_byte_length
    },
    [pscustomobject]@{
        path = $closure.qualification.adoption_path
        sha256 = $closure.qualification.adoption_sha256
        byte_length = $closure.qualification.adoption_byte_length
    }
)) { [void](Assert-Artifact $qualificationRecord) }

$attemptFiles = @(Get-ChildItem -LiteralPath (
    [string]$closure.physical_evidence.attempt_root
) -Recurse -File)
Assert-R23D39 (
    $attemptFiles.Count -eq 21 -and
    [int]$closure.physical_evidence.complete_attempt_file_count -eq 21 -and
    [bool]$closure.physical_evidence.complete_attempt_files_content_addressed
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
Assert-R23D39 (
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq
        [string]$closure.source_tree_git_oid -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 2 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 17 -and
    [bool]$attestation.all_gates_executed -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [int]$adoption.executed_gate_count -eq 17 -and
    [int]$adoption.gate_cas_object_count -eq 51 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification or adoption changed"

Assert-R23D39 (
    [string]$freeze.schema_version -ceq "sporespore_qsdk_r23d39_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq [string]$closure.source_tree_git_oid -and
    [string]$freeze.origin_main_commit -ceq $sourceCommit -and
    [string]$freeze.live_github_main_commit -ceq $sourceCommit -and
    [int]$freeze.declared_world_count -eq 3 -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority -and
    [int]$freeze.zero_world_receipt.world_attempt_count -eq 0 -and
    [int]$freeze.zero_world_receipt.world_build_count -eq 0 -and
    [int]$freeze.zero_world_receipt.worker_preflight_count -eq 3 -and
    [string]$attempt.schema_version -ceq "sporespore_qsdk_r23d39_attempt_v1" -and
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.operation_lock_held -and
    [bool]$attempt.campaign_attestation_adoption_valid -and
    [bool]$attempt.content_addressed_inputs_retained -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    @($attempt.ordered_matrix_cell_ids).Count -eq 3
) "freeze or authorization changed"
Assert-R23D39 (
    @($freeze.source_bindings).Count -eq 71 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 71 -and
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
    Assert-R23D39 (
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
$evaluation = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.complete_evaluation.path
) | ConvertFrom-Json -Depth 100
$report = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.report.path
) | ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.completion.path
) | ConvertFrom-Json -Depth 100
$expectedManifest = @($closure.physical_evidence.cells | ForEach-Object {
    Join-Path (Join-Path $artifactRoot ([string]$_.terminal.sha256).Substring(7)) "payload.bin"
})
Assert-R23D39 (
    $manifest -is [Array] -and @($manifest).Count -eq 3 -and
    (@($manifest) -join '|') -ceq ($expectedManifest -join '|') -and
    [string]$closure.official_result.terminal_manifest_json_type -ceq "array" -and
    [int]$closure.official_result.terminal_manifest_element_count -eq 3 -and
    [bool]$closure.official_result.strict_array_boundary_physically_held
) "strict three-element terminal manifest changed"
Assert-R23D39 (
    [string]$evaluation.schema_version -ceq
        "sporespore_qsdk_r23d39_complete_evaluation_v1" -and
    [string]$evaluation.classification -ceq
        "valid_complete_positive_mujoco_startup_ramp_turning_development" -and
    [bool]$evaluation.all_cells_execution_valid -and
    [bool]$evaluation.all_common_physical_gates_passed -and
    [bool]$evaluation.turning_measurement_passed -and
    [bool]$evaluation.turning_tested -and
    [bool]$evaluation.outcome_exposed_development_screen -and
    [bool]$evaluation.distinct_same_policy_three_engine_validation_required -and
    -not [bool]$evaluation.fresh_held_out_condition_consumed -and
    @($evaluation.measurement_failure_codes).Count -eq 0 -and
    @($evaluation.cell_evaluations).Count -eq 3 -and
    @($report.ordered_cells).Count -eq 3 -and
    [string]$report.result_classification -ceq [string]$evaluation.classification -and
    [string]$completion.status -ceq [string]$evaluation.classification -and
    [int]$completion.cell_count -eq 3 -and
    [int]$completion.world_count -eq 3 -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted
) "evaluation, report, or completion changed"

$measurementsByArm = @{}
$totalRows = 0
$totalCommands = 0
$totalApplications = 0
foreach ($expected in @($closure.physical_evidence.cells)) {
    $armId = [string]$expected.arm_id
    $cellId = [string]$expected.cell_id
    $reportCell = @($report.ordered_cells | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })
    $evaluatedCell = @($evaluation.cell_evaluations | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })
    Assert-R23D39 ($reportCell.Count -eq 1 -and $evaluatedCell.Count -eq 1) (
        "cell missing or duplicated: $cellId"
    )
    $terminalPath = Assert-Cas (
        [string]$expected.terminal.sha256
    ) ([long]$expected.terminal.byte_length)
    $terminal = Get-Content -Raw -LiteralPath $terminalPath |
        ConvertFrom-Json -Depth 100
    Assert-R23D39 (
        [string]$reportCell[0].terminal_entry_cas.sha256 -ceq
            [string]$expected.terminal.sha256 -and
        [bool]$evaluatedCell[0].execution_valid -and
        [bool]$evaluatedCell[0].common_physical_gate_passed -and
        @($evaluatedCell[0].failed_gate_ids).Count -eq 0 -and
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d39_engine_cell_report_v1" -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.campaign_id -ceq [string]$closure.campaign_id -and
        [string]$terminal.cell_id -ceq $cellId -and
        [string]$terminal.arm_id -ceq $armId -and
        [string]$terminal.engine_id -ceq "mujoco" -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
        [int]$terminal.execution.validated_portable_command_count -eq 23936 -and
        [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
        [bool]$terminal.execution.trace_retained_before_terminal_entry -and
        [bool]$terminal.execution.startup_ramp_composition_integrity_passed -and
        [string]$terminal.execution.worker_failure_code -ceq "" -and
        [int]$terminal.measurements.controller_error_count -eq 0 -and
        [int]$terminal.measurements.safe_no_actuation_count -eq 0 -and
        [int]$terminal.measurements.nonfinite_observation_count -eq 0 -and
        [int]$terminal.measurements.actuator_application_mismatch_count -eq 0 -and
        [bool]$terminal.trace_summary.ok -and
        [int]$terminal.trace_summary.row_count -eq 2992 -and
        [string]$terminal.trace_summary.raw_sha256 -ceq [string]$expected.trace.sha256 -and
        [string]$terminal.trace_artifact.sha256 -ceq [string]$expected.trace.sha256
    ) "terminal or execution changed: $armId"
    Assert-R23D39 (
        [double]$terminal.measurements.final_forward_displacement_m -ge 0.030123046875 -and
        [double]$terminal.measurements.maximum_tilt_rad -le 0.6 -and
        [double]$terminal.measurements.minimum_torso_height_m -ge 0.2499708652072946 -and
        [int]$terminal.measurements.torso_ground_contact_step_count -eq 0 -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.front_left -ge 2 -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.front_right -ge 2 -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.rear_left -ge 2 -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.rear_right -ge 2
    ) "frozen walking gate no longer passes: $armId"

    $tracePath = Assert-Cas (
        [string]$expected.trace.sha256
    ) ([long]$expected.trace.byte_length)
    $traceLines = @(Get-Content -LiteralPath $tracePath)
    Assert-R23D39 ($traceLines.Count -eq 2992) "trace row count changed: $armId"
    $unwrappedYaw = [Collections.Generic.List[double]]::new()
    $previousRawYaw = 0.0
    $previousUnwrappedYaw = 0.0
    $maximumTilt = 0.0
    $minimumHeight = [double]::PositiveInfinity
    $torsoContactRows = 0
    $activeRampRows = 0
    $cycles = @{ front_left = 0; front_right = 0; rear_left = 0; rear_right = 0 }
    $previous = @{ front_left = $true; front_right = $true; rear_left = $true; rear_right = $true }
    $turnOffset = [double]$terminal.turn_heading_offset_rad
    for ($rowIndex = 0; $rowIndex -lt $traceLines.Count; $rowIndex++) {
        $row = $traceLines[$rowIndex] | ConvertFrom-Json -Depth 30
        $expectedSegment = if ($rowIndex -lt 600) {
            "reference_warmup"
        } elseif ($rowIndex -lt 1800) {
            "commanded_turn"
        } elseif ($rowIndex -lt 2400) {
            "reference_recovery"
        } else {
            "after_declared_schedule"
        }
        $expectedOffset = if ($expectedSegment -ceq "commanded_turn") {
            $turnOffset
        } else { 0.0 }
        $expectedScale = if ($rowIndex -ge 359) { 1.0 } else {
            $progress = $rowIndex / 359.0
            $progress * $progress * (3.0 - 2.0 * $progress)
        }
        $yaw = [double]$row.measured_yaw_rad
        Assert-R23D39 (
            [string]$row.schema_version -ceq
                "sporespore_qsdk_r23d3_turn_diagnostic_trace_row_v1" -and
            [string]$row.cell_id -ceq $cellId -and
            [int]$row.semantic_step -eq $rowIndex -and
            [string]$row.segment_id -ceq $expectedSegment -and
            [double]$row.desired_heading_offset_rad -eq $expectedOffset -and
            [int]$row.validated_portable_command_count -eq 8 -and
            [int]$row.native_actuation_application_count -eq 8 -and
            [bool]$row.oracle_passed -and
            [string]$row.startup_ramp_id -ceq
                "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
            [Math]::Abs([double]$row.startup_velocity_scale - $expectedScale) -le 1.0e-15 -and
            [bool]$row.startup_ramp_active -eq ($expectedScale -lt 1.0) -and
            [int]$row.startup_ramp_residual_count -eq 8 -and
            [double]::IsFinite($yaw)
        ) "trace, schedule, or ramp changed: $armId/$rowIndex"
        if ($rowIndex -eq 0) {
            $previousRawYaw = $yaw
            $previousUnwrappedYaw = $yaw
            $unwrappedYaw.Add($yaw)
        } else {
            $delta = [Math]::IEEERemainder($yaw - $previousRawYaw, $twoPi)
            Assert-R23D39 (
                [double]::IsFinite($delta) -and
                [Math]::Abs([Math]::Abs($delta) - [Math]::PI) -gt $tolerance
            ) "ambiguous yaw unwrap: $armId/$rowIndex"
            $previousUnwrappedYaw += $delta
            $unwrappedYaw.Add($previousUnwrappedYaw)
            $previousRawYaw = $yaw
        }
        $maximumTilt = [Math]::Max($maximumTilt, [double]$row.torso_tilt_rad)
        $minimumHeight = [Math]::Min($minimumHeight, [double]$row.torso_height_m)
        $torsoContactRows += [int][bool]$row.torso_ground_contact
        $activeRampRows += [int]($expectedScale -lt 1.0)
        if ($rowIndex -ge 472) {
            foreach ($limb in @("front_left", "front_right", "rear_left", "rear_right")) {
                $present = [bool]$row.ordered_foot_contacts_after.$limb
                if (-not $previous[$limb] -and $present) { $cycles[$limb]++ }
                $previous[$limb] = $present
            }
        }
    }
    Assert-R23D39 (
        [double]$terminal.measurements.maximum_tilt_rad -ge $maximumTilt -and
        [double]$terminal.measurements.maximum_tilt_rad - $maximumTilt -le 1.0e-5 -and
        [double]$terminal.measurements.minimum_torso_height_m -le $minimumHeight -and
        $minimumHeight - [double]$terminal.measurements.minimum_torso_height_m -le 1.0e-5 -and
        $torsoContactRows -eq 0 -and $activeRampRows -eq 359 -and
        $cycles.front_left -eq [int]$terminal.measurements.contact_cycle_count_by_limb.front_left -and
        $cycles.front_right -eq [int]$terminal.measurements.contact_cycle_count_by_limb.front_right -and
        $cycles.rear_left -eq [int]$terminal.measurements.contact_cycle_count_by_limb.rear_left -and
        $cycles.rear_right -eq [int]$terminal.measurements.contact_cycle_count_by_limb.rear_right
    ) "trace-derived physical envelope, contact, or ramp counts changed: $armId"
    $baselineMean = Get-WindowMean $unwrappedYaw 240 600
    $terminalMean = Get-WindowMean $unwrappedYaw 1440 1800
    $swingShifts = [Collections.Generic.List[double]]::new()
    for ($swing = 0; $swing -lt 5; $swing++) {
        $start = 1440 + $swing * 72
        $swingShifts.Add((Get-WindowMean $unwrappedYaw $start ($start + 72)) - $baselineMean)
    }
    $measurementsByArm[$armId] = [ordered]@{
        cycle_shift_rad = $terminalMean - $baselineMean
        terminal_swing_shift_rad = @($swingShifts)
    }
    $totalRows += $traceLines.Count
    $totalCommands += [int]$terminal.execution.validated_portable_command_count
    $totalApplications += [int]$terminal.execution.native_actuation_application_count
}

$reported = $evaluation.cycle_integrated_measurement
$reference = $measurementsByArm.reference_zero
$positive = $measurementsByArm.positive_heading
$negative = $measurementsByArm.negative_heading
$positiveConditioned = [double]$positive.cycle_shift_rad - [double]$reference.cycle_shift_rad
$negativeConditioned = [double]$reference.cycle_shift_rad - [double]$negative.cycle_shift_rad
$positiveSwingConditioned = @()
$negativeSwingConditioned = @()
for ($index = 0; $index -lt 5; $index++) {
    $positiveSwingConditioned += [double]$positive.terminal_swing_shift_rad[$index] -
        [double]$reference.terminal_swing_shift_rad[$index]
    $negativeSwingConditioned += [double]$reference.terminal_swing_shift_rad[$index] -
        [double]$negative.terminal_swing_shift_rad[$index]
}
foreach ($armId in @("reference_zero", "positive_heading", "negative_heading")) {
    Assert-Near (
        [double]$measurementsByArm[$armId].cycle_shift_rad
    ) ([double]$reported.arms.$armId.cycle_shift_rad) $tolerance (
        "reported cycle shift changed: $armId"
    )
    Assert-ArrayNear (
        $measurementsByArm[$armId].terminal_swing_shift_rad
    ) $reported.arms.$armId.terminal_swing_shift_rad $tolerance (
        "reported swing shifts changed: $armId"
    )
}
Assert-Near $positiveConditioned (
    [double]$reported.positive_reference_conditioned_cycle_shift_rad
) $tolerance "positive conditioned shift changed"
Assert-Near $negativeConditioned (
    [double]$reported.negative_reference_conditioned_cycle_shift_rad
) $tolerance "negative conditioned shift changed"
Assert-Near ($positiveConditioned + $negativeConditioned) (
    [double]$reported.bilateral_reference_conditioned_cycle_separation_rad
) $tolerance "bilateral separation changed"
Assert-ArrayNear $positiveSwingConditioned (
    $reported.positive_terminal_swing_conditioned_shift_rad
) $tolerance "positive conditioned swings changed"
Assert-ArrayNear $negativeSwingConditioned (
    $reported.negative_terminal_swing_conditioned_shift_rad
) $tolerance "negative conditioned swings changed"
Assert-R23D39 (
    [double]$positive.cycle_shift_rad -ge 0.01 -and
    [double]$negative.cycle_shift_rad -le -0.01 -and
    $positiveConditioned -ge 0.01 -and $negativeConditioned -ge 0.01 -and
    [bool]$reported.gates.raw_signed_cycle_shift -and
    [bool]$reported.gates.reference_conditioned_cycle_shift -and
    [bool]$reported.nonselecting_diagnostics.every_terminal_swing_raw_direction -and
    [bool]$reported.nonselecting_diagnostics.every_terminal_swing_reference_conditioned_direction -and
    [bool]$reported.passed -and
    $totalRows -eq 8976 -and $totalCommands -eq 71808 -and
    $totalApplications -eq 71808
) "independent measurement or totals changed"

$closedMeasurement = $closure.measurements.cycle_integrated_measurement
Assert-Near ([double]$reference.cycle_shift_rad) (
    [double]$closedMeasurement.reference_cycle_shift_rad
) $tolerance "closed reference shift changed"
Assert-Near ([double]$positive.cycle_shift_rad) (
    [double]$closedMeasurement.positive_cycle_shift_rad
) $tolerance "closed positive shift changed"
Assert-Near ([double]$negative.cycle_shift_rad) (
    [double]$closedMeasurement.negative_cycle_shift_rad
) $tolerance "closed negative shift changed"
Assert-R23D39 (
    [string]$closure.official_result.classification -ceq
        "valid_complete_positive_mujoco_startup_ramp_turning_development" -and
    [bool]$closure.official_result.all_cells_execution_valid -and
    [bool]$closure.official_result.all_common_physical_gates_passed -and
    [bool]$closure.official_result.cycle_integrated_turning_measurement_passed -and
    [bool]$closure.official_result.scientific_selector_legally_completed -and
    [bool]$closure.claims.finite_mujoco_r23d29_seed_21507_startup_ramp_walking -and
    [bool]$closure.claims.finite_mujoco_r23d29_seed_21507_startup_ramp_turning -and
    [bool]$closure.claims.mujoco_r23d29_turning -and
    [bool]$closure.claims.separate_finite_turning_positives_on_all_three_engines -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
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
        & python -m sporespore_mujoco_adapter.qsdk_r23d39_startup_ramp_turning preflight --stage "mujoco_r23d29_startup_ramp_turning_development" --onset "onset_600" --arm "reference_zero" 2>&1
    ) | Out-String
    $refusalExitCode = $LASTEXITCODE
} finally {
    $env:PYTHONPATH = $savedPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $savedLibrary
}
Assert-R23D39 (
    $refusalExitCode -ne 0 -and
    $refusal.Contains('"failure_code":"QSDK_R23D39_MJC_CLOSED"')
) "closed R23D39 worker refusal changed: $refusal"

Write-Output (
    "QSDK_R23D39_CLOSURE_PASS classification=valid_complete_positive " +
    "cells=3 worlds=3 rows=$totalRows commands=$totalCommands " +
    "positive_conditioned=$positiveConditioned negative_conditioned=$negativeConditioned " +
    "bilateral_separation=$($positiveConditioned + $negativeConditioned) " +
    "finite_mujoco_turning=True separate_three_engine_positives=True " +
    "unified_three_engine_validation=False rerun=False successor_open=False"
)
