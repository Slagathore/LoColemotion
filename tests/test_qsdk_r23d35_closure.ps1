#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d35_godot_trace_recovery_closure_v1.json"
)
$artifactRoot = Join-Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) "artifacts\sha256"
$sourceCommit = "0649041bf0696c8e879d0238f379edca617eddb4"

function Assert-R23D35([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D35 CLOSURE: $Message" }
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-Artifact($Record) {
    $path = [string]$Record.path
    Assert-R23D35 (Test-Path -LiteralPath $path -PathType Leaf) (
        "retained artifact missing: $path"
    )
    Assert-R23D35 ((Get-Item -LiteralPath $path).Length -eq [long]$Record.byte_length) (
        "retained artifact length changed: $path"
    )
    Assert-R23D35 ((Get-Sha256 $path) -ceq [string]$Record.sha256) (
        "retained artifact digest changed: $path"
    )
}

function Get-CasPayload([string]$Sha256) {
    Assert-R23D35 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    return Join-Path (
        Join-Path $artifactRoot $Sha256.Substring(7)
    ) "payload.bin"
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    $path = Get-CasPayload $Sha256
    Assert-R23D35 (Test-Path -LiteralPath $path -PathType Leaf) (
        "CAS payload missing: $Sha256"
    )
    Assert-R23D35 ((Get-Item -LiteralPath $path).Length -eq $ByteLength) (
        "CAS payload length changed: $Sha256"
    )
    Assert-R23D35 ((Get-Sha256 $path) -ceq $Sha256) (
        "CAS payload digest changed: $Sha256"
    )
    return $path
}

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100

Assert-R23D35 (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d35_godot_trace_recovery_closure_v1" -and
    [string]$closure.status -ceq
        "closed_valid_complete_positive_finite_godot_jolt_r23d29_turning" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D35-GODOT-R23D29-TRACE-RECOVERY" -and
    [string]$closure.gate_id -ceq "QSDK-R23D35" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$closure.attempt_id -ceq "75215456798a49dea56670b9c25a1a0f" -and
    [int]$closure.campaign_seed -eq 21507 -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed
) "closure identity changed"

foreach ($binding in @(
    [pscustomobject]@{
        path = [string]$closure.prospective_inputs.preregistration_path
        sha256 = [string]$closure.prospective_inputs.preregistration_raw_sha256
    },
    [pscustomobject]@{
        path = [string]$closure.prospective_inputs.implementation_path
        sha256 = [string]$closure.prospective_inputs.implementation_raw_sha256
    },
    [pscustomobject]@{
        path = [string]$closure.prospective_inputs.campaign_attestation_manifest_path
        sha256 = [string]$closure.prospective_inputs.campaign_attestation_manifest_raw_sha256
    }
)) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-R23D35 ((Get-Sha256 $path) -ceq [string]$binding.sha256) (
        "prospective input changed: $($binding.path)"
    )
}
Assert-R23D35 (
    -not [bool]$closure.prospective_inputs.controller_fixture_seed_actuation_schedule_measurement_and_thresholds_changed_from_r23d34 -and
    -not [bool]$closure.prospective_inputs.mujoco_r23d34_result_rerun_or_reinterpreted
) "the repair-only estimand changed"

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
foreach ($name in @(
    "physical_freeze", "attempt_authorization", "terminal_manifest",
    "complete_evaluation", "report", "completion"
)) {
    Assert-Artifact $closure.physical_evidence.$name
}

$attestation = Get-Content -Raw -LiteralPath (
    [string]$closure.qualification.attestation_path
) | ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath (
    [string]$closure.qualification.adoption_path
) | ConvertFrom-Json -Depth 100
Assert-R23D35 (
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
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification receipt changed"

$freeze = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.physical_freeze.path
) | ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.attempt_authorization.path
) | ConvertFrom-Json -Depth 100
$terminalManifest = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.terminal_manifest.path
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

Assert-R23D35 (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d35_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq [string]$closure.source_tree_git_oid -and
    [int]$freeze.declared_world_count -eq 3 -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.all_cells_run_regardless_of_intermediate_outcome -and
    -not [bool]$freeze.terminal_restoration_or_taper_invoked -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [int]$freeze.zero_world_receipt.world_attempt_count -eq 0 -and
    [int]$freeze.zero_world_receipt.world_build_count -eq 0 -and
    [bool]$freeze.zero_world_receipt.exact_live_trace_composition_gate_passed -and
    @($freeze.source_bindings).Count -eq 74 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 74 -and
    @($freeze.runtime_artifacts).Count -eq 1 -and
    @($freeze.content_addressed_inputs.runtime_bindings).Count -eq 4 -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority
) "physical freeze changed"

for ($index = 0; $index -lt 74; $index++) {
    $binding = $freeze.source_bindings[$index]
    $retained = $freeze.content_addressed_inputs.source_bindings[$index]
    $relative = [string]$binding.path
    $gitOid = (git -C $repoRoot rev-parse "${sourceCommit}:$relative").Trim()
    Assert-R23D35 (
        $LASTEXITCODE -eq 0 -and
        [string]$binding.git_blob_oid -ceq $gitOid -and
        [bool]$binding.raw_checkout_equals_git_blob -and
        [string]$retained.sha256 -ceq [string]$binding.raw_sha256
    ) "source binding changed: $relative"
    [void](Assert-Cas ([string]$retained.sha256) ([long]$retained.byte_length))
}

$godotRuntime = @($freeze.runtime_artifacts | Where-Object {
    [string]$_.name -ceq "godot_adapter_debug"
})
Assert-R23D35 (
    $godotRuntime.Count -eq 1 -and
    [string]$godotRuntime[0].raw_sha256 -ceq
        [string]$closure.physical_evidence.godot_adapter_debug_sha256 -and
    [bool]$godotRuntime[0].build_receipt.msvc_brepro -and
    [bool]$godotRuntime[0].build_receipt.pdb_alt_path_bare_name -and
    -not [bool]$godotRuntime[0].build_receipt.codegen_units_forced
) "reproducible Godot runtime binding changed"
foreach ($runtime in @($freeze.content_addressed_inputs.runtime_bindings)) {
    [void](Assert-Cas ([string]$runtime.sha256) ([long]$runtime.byte_length))
}

Assert-R23D35 (
    [string]$attempt.schema_version -ceq "sporespore_qsdk_r23d35_attempt_v1" -and
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    @($attempt.ordered_matrix_cell_ids).Count -eq 3 -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.operation_lock_held -and
    [bool]$attempt.campaign_attestation_adoption_valid -and
    [bool]$attempt.content_addressed_inputs_retained -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    [bool]$attempt.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$attempt.physical_execution_authorized -and
    -not [bool]$attempt.physical_acceptance_authority
) "attempt authorization changed"

Assert-R23D35 (
    @($terminalManifest).Count -eq 3 -and
    @($report.ordered_cells).Count -eq 3 -and
    @($evaluation.cell_evaluations).Count -eq 3 -and
    [string]$report.result_classification -ceq
        "valid_complete_positive_godot_trace_recovery" -and
    [string]$evaluation.classification -ceq
        "valid_complete_positive_godot_trace_recovery" -and
    [bool]$evaluation.all_cells_run_regardless_of_intermediate_outcome -and
    -not [bool]$evaluation.terminal_restoration_or_taper_invoked -and
    [string]$completion.status -ceq
        "valid_complete_positive_godot_trace_recovery" -and
    [int]$completion.cell_count -eq 3 -and
    [int]$completion.world_count -eq 3 -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    -not [bool]$completion.physical_acceptance_authority -and
    [string]$completion.report_cas.sha256 -ceq
        [string]$closure.physical_evidence.report.sha256 -and
    [string]$completion.complete_evaluation_cas.sha256 -ceq
        [string]$closure.physical_evidence.complete_evaluation.sha256
) "complete evaluation changed"

$expectedTerminalPaths = @($closure.ordered_cells | ForEach-Object {
    Get-CasPayload ([string]$_.terminal_sha256)
}) | Sort-Object
$observedTerminalPaths = @($terminalManifest | ForEach-Object {
    [IO.Path]::GetFullPath([string]$_)
}) | Sort-Object
Assert-R23D35 (
    ($expectedTerminalPaths -join '|') -ceq ($observedTerminalPaths -join '|')
) "terminal manifest changed"

$worldAttempts = 0
$worldBuilds = 0
$controllerSteps = 0
$validatedCommands = 0
$nativeApplications = 0
$traceRows = 0
foreach ($expected in @($closure.ordered_cells)) {
    $reportCell = @($report.ordered_cells | Where-Object {
        [string]$_.cell_id -ceq [string]$expected.cell_id
    })
    $evaluatedCell = @($evaluation.cell_evaluations | Where-Object {
        [string]$_.cell_id -ceq [string]$expected.cell_id
    })
    Assert-R23D35 ($reportCell.Count -eq 1 -and $evaluatedCell.Count -eq 1) (
        "cell missing or duplicated: $($expected.cell_id)"
    )
    Assert-R23D35 (
        [string]$reportCell[0].terminal_entry_cas.sha256 -ceq
            [string]$expected.terminal_sha256 -and
        [long]$reportCell[0].terminal_entry_cas.byte_length -eq
            [long]$expected.terminal_byte_length -and
        [bool]$evaluatedCell[0].execution_valid -and
        [bool]$evaluatedCell[0].common_physical_gate_passed -and
        @($evaluatedCell[0].failed_gate_ids).Count -eq 0 -and
        [int]$evaluatedCell[0].world_attempt_count -eq 1 -and
        [int]$evaluatedCell[0].world_build_count -eq 1
    ) "cell evaluation changed: $($expected.cell_id)"

    $terminalPath = Assert-Cas `
        ([string]$expected.terminal_sha256) `
        ([long]$expected.terminal_byte_length)
    $terminal = Get-Content -Raw -LiteralPath $terminalPath |
        ConvertFrom-Json -Depth 100
    Assert-R23D35 (
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d35_engine_cell_report_v1" -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.campaign_id -ceq [string]$closure.campaign_id -and
        [string]$terminal.cell_id -ceq [string]$expected.cell_id -and
        [string]$terminal.engine_id -ceq "godot_jolt" -and
        [string]$terminal.arm_id -ceq [string]$expected.arm_id -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
        [int]$terminal.execution.validated_portable_command_count -eq 23936 -and
        [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
        [bool]$terminal.execution.trace_retained_before_terminal_entry -and
        [string]$terminal.execution.worker_failure_code -ceq "" -and
        [bool]$terminal.godot_execution_predicates.ok -and
        @($terminal.godot_execution_predicates.failed_predicate_ids).Count -eq 0 -and
        [int]$terminal.measurements.actuator_application_mismatch_count -eq 0 -and
        [int]$terminal.measurements.safe_no_actuation_count -eq 0 -and
        [int]$terminal.measurements.controller_error_count -eq 0 -and
        [int]$terminal.measurements.nonfinite_observation_count -eq 0 -and
        [double]$terminal.measurements.final_forward_displacement_m -eq
            [double]$expected.final_forward_displacement_m -and
        [double]$terminal.measurements.maximum_tilt_rad -eq
            [double]$expected.maximum_tilt_rad -and
        [double]$terminal.measurements.minimum_torso_height_m -eq
            [double]$expected.minimum_torso_height_m -and
        [int]$terminal.measurements.torso_ground_contact_step_count -eq 0 -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.front_left -eq
            [int]$expected.contact_cycle_count_by_limb.front_left -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.front_right -eq
            [int]$expected.contact_cycle_count_by_limb.front_right -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.rear_left -eq
            [int]$expected.contact_cycle_count_by_limb.rear_left -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.rear_right -eq
            [int]$expected.contact_cycle_count_by_limb.rear_right -and
        [bool]$terminal.trace_summary.ok -and
        [int]$terminal.trace_summary.row_count -eq 2992 -and
        @($terminal.trace_summary.failure_codes).Count -eq 0 -and
        [string]$terminal.trace_summary.raw_sha256 -ceq
            [string]$expected.trace_sha256 -and
        [string]$terminal.trace_artifact.sha256 -ceq
            [string]$expected.trace_sha256 -and
        -not [bool]$terminal.claims.physical_acceptance_authority
    ) "terminal or walking evidence changed: $($expected.arm_id)"

    Assert-R23D35 (
        [double]$terminal.measurements.final_forward_displacement_m -ge
            0.030123046875 -and
        [double]$terminal.measurements.maximum_tilt_rad -le 0.6 -and
        [double]$terminal.measurements.minimum_torso_height_m -ge
            0.2499708652072946 -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.front_left -ge 2 -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.front_right -ge 2 -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.rear_left -ge 2 -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.rear_right -ge 2
    ) "frozen common physical gate no longer passes: $($expected.arm_id)"

    $tracePath = Assert-Cas `
        ([string]$expected.trace_sha256) `
        ([long]$expected.trace_byte_length)
    $lines = @(Get-Content -LiteralPath $tracePath)
    Assert-R23D35 ($lines.Count -eq 2992) (
        "trace row count changed: $($expected.arm_id)"
    )
    for ($rowIndex = 0; $rowIndex -lt $lines.Count; $rowIndex++) {
        $row = $lines[$rowIndex] | ConvertFrom-Json -Depth 30
        Assert-R23D35 (
            [string]$row.schema_version -ceq
                "sporespore_qsdk_r23d3_turn_diagnostic_trace_row_v1" -and
            [string]$row.cell_id -ceq [string]$expected.cell_id -and
            [int]$row.semantic_step -eq $rowIndex
        ) "trace continuity changed: $($expected.arm_id)/$rowIndex"
    }

    $worldAttempts += [int]$terminal.execution.world_attempt_count
    $worldBuilds += [int]$terminal.execution.world_build_count
    $controllerSteps += [int]$terminal.execution.controller_semantic_step_count
    $validatedCommands += [int]$terminal.execution.validated_portable_command_count
    $nativeApplications += [int]$terminal.execution.native_actuation_application_count
    $traceRows += $lines.Count
}

$measurement = $evaluation.engine_results.godot_jolt.cycle_integrated_measurement
$closedMeasurement = $closure.cycle_integrated_evaluation
Assert-R23D35 (
    [bool]$evaluation.engine_results.godot_jolt.passed -and
    @($evaluation.engine_results.godot_jolt.measurement_failure_codes).Count -eq 0 -and
    [bool]$measurement.passed -and
    [bool]$measurement.gates.raw_signed_cycle_shift -and
    [bool]$measurement.gates.reference_conditioned_cycle_shift -and
    [double]$measurement.arms.reference_zero.cycle_shift_rad -eq
        [double]$closedMeasurement.cycle_shift_rad_by_arm.reference_zero -and
    [double]$measurement.arms.positive_heading.cycle_shift_rad -eq
        [double]$closedMeasurement.cycle_shift_rad_by_arm.positive_heading -and
    [double]$measurement.arms.negative_heading.cycle_shift_rad -eq
        [double]$closedMeasurement.cycle_shift_rad_by_arm.negative_heading -and
    [double]$measurement.positive_reference_conditioned_cycle_shift_rad -eq
        [double]$closedMeasurement.positive_reference_conditioned_cycle_shift_rad -and
    [double]$measurement.negative_reference_conditioned_cycle_shift_rad -eq
        [double]$closedMeasurement.negative_reference_conditioned_cycle_shift_rad -and
    [double]$measurement.bilateral_reference_conditioned_cycle_separation_rad -eq
        [double]$closedMeasurement.bilateral_reference_conditioned_cycle_separation_rad -and
    [double]$measurement.arms.positive_heading.cycle_shift_rad -ge 0.01 -and
    [double]$measurement.arms.negative_heading.cycle_shift_rad -le -0.01 -and
    [double]$measurement.positive_reference_conditioned_cycle_shift_rad -ge 0.01 -and
    [double]$measurement.negative_reference_conditioned_cycle_shift_rad -ge 0.01 -and
    -not [bool]$measurement.nonselecting_diagnostics.every_terminal_swing_raw_direction -and
    -not [bool]$measurement.nonselecting_diagnostics.every_terminal_swing_reference_conditioned_direction
) "cycle-integrated result changed"

Assert-R23D35 (
    $worldAttempts -eq 3 -and
    $worldBuilds -eq 3 -and
    $controllerSteps -eq 8976 -and
    $validatedCommands -eq 71808 -and
    $nativeApplications -eq 71808 -and
    $traceRows -eq 8976 -and
    [bool]$closure.implementation_repair_findings.complete_trace_retained_before_each_terminal -and
    -not [bool]$closure.implementation_repair_findings.r23d34_trace_projection_failure_recurred -and
    -not [bool]$closure.implementation_repair_findings.incomplete_diagnostic_path_invoked -and
    [bool]$closure.bounded_interpretation.finite_godot_jolt_r23d29_turning_confirmed -and
    [bool]$closure.bounded_interpretation.r23d34_mujoco_baseline_walking_negative_remains_accepted -and
    -not [bool]$closure.bounded_interpretation.native_mujoco_r23d29_turning_validated -and
    -not [bool]$closure.bounded_interpretation.portable_or_three_engine_turning_validated -and
    [bool]$closure.claims.native_godot_jolt_r23d29_walking -and
    [bool]$closure.claims.native_godot_jolt_r23d29_turning -and
    [bool]$closure.claims.finite_godot_jolt_turning -and
    -not [bool]$closure.claims.native_mujoco_r23d29_walking -and
    -not [bool]$closure.claims.native_mujoco_r23d29_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority -and
    [bool]$evaluation.claims.godot_jolt_r23d29_turning -and
    -not [bool]$evaluation.claims.finite_three_engine_turning -and
    -not [bool]$evaluation.claims.cross_engine_equivalence
) "bounded interpretation or claim boundary changed"

Write-Output (
    "QSDK_R23D35_CLOSURE_PASS cells=3 worlds=3 rows=$traceRows " +
    "commands=$validatedCommands native_applications=$nativeApplications " +
    "positive_conditioned=$($measurement.positive_reference_conditioned_cycle_shift_rad) " +
    "negative_conditioned=$($measurement.negative_reference_conditioned_cycle_shift_rad) " +
    "bilateral_separation=$($measurement.bilateral_reference_conditioned_cycle_separation_rad) " +
    "finite_godot_jolt_turning=True portable_three_engine=False"
)
