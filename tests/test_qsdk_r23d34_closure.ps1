#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d34_native_r23d29_transfer_closure_v1.json"
)
$artifactRoot = Join-Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) "artifacts\sha256"
$sourceCommit = "7c76df6f4b77c5feac082cf9f5be48af69613565"
$expectedMuJoCoFailedGates = @(
    "R23D34_FORWARD_DISPLACEMENT",
    "R23D34_MAXIMUM_TILT",
    "R23D34_CONTACT_CYCLES",
    "R23D34_TORSO_GROUND_CONTACT"
)

function Assert-R23D34([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D34 CLOSURE: $Message" }
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-Artifact($Record) {
    $path = [string]$Record.path
    Assert-R23D34 (Test-Path -LiteralPath $path -PathType Leaf) (
        "retained artifact missing: $path"
    )
    Assert-R23D34 ((Get-Item -LiteralPath $path).Length -eq [long]$Record.byte_length) (
        "retained artifact length changed: $path"
    )
    Assert-R23D34 ((Get-Sha256 $path) -ceq [string]$Record.sha256) (
        "retained artifact digest changed: $path"
    )
}

function Get-CasPayload([string]$Sha256) {
    Assert-R23D34 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    return Join-Path (
        Join-Path $artifactRoot $Sha256.Substring(7)
    ) "payload.bin"
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    $path = Get-CasPayload $Sha256
    Assert-R23D34 (Test-Path -LiteralPath $path -PathType Leaf) (
        "CAS payload missing: $Sha256"
    )
    Assert-R23D34 ((Get-Item -LiteralPath $path).Length -eq $ByteLength) (
        "CAS payload length changed: $Sha256"
    )
    Assert-R23D34 ((Get-Sha256 $path) -ceq $Sha256) (
        "CAS payload digest changed: $Sha256"
    )
    return $path
}

function Read-CasJson([string]$Sha256, [long]$ByteLength) {
    $path = Assert-Cas $Sha256 $ByteLength
    return Get-Content -Raw -LiteralPath $path |
        ConvertFrom-Json -Depth 100
}

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100

Assert-R23D34 (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d34_native_r23d29_transfer_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_complete_with_valid_mujoco_locomotion_negative" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D34-NATIVE-R23D29-IMPLEMENTATION-REPAIR-TRANSFER" -and
    [string]$closure.gate_id -ceq "QSDK-R23D34" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$closure.attempt_id -ceq "8df7c56fdc94459d93391d184199ab21" -and
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
    Assert-R23D34 ((Get-Sha256 $path) -ceq [string]$binding.sha256) (
        "prospective input changed: $($binding.path)"
    )
}
Assert-R23D34 (
    -not [bool]$closure.prospective_inputs.controller_fixture_seed_schedule_measurement_and_thresholds_changed_from_r23d33
) "R23D33 estimand was changed"

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
Assert-R23D34 (
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq
        [string]$closure.source_tree_git_oid -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 3 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 18 -and
    [bool]$attestation.all_gates_executed -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [int]$adoption.executed_gate_count -eq 18 -and
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

Assert-R23D34 (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq [string]$closure.source_tree_git_oid -and
    [int]$freeze.declared_world_count -eq 6 -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.all_cells_run_regardless_of_intermediate_outcome -and
    -not [bool]$freeze.terminal_restoration_or_taper_invoked -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [int]$freeze.zero_world_receipt.world_attempt_count -eq 0 -and
    [int]$freeze.zero_world_receipt.world_build_count -eq 0 -and
    @($freeze.source_bindings).Count -eq 99 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 99 -and
    @($freeze.runtime_artifacts).Count -eq 2 -and
    @($freeze.content_addressed_inputs.runtime_bindings).Count -eq 5 -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority
) "physical freeze changed"

for ($index = 0; $index -lt 99; $index++) {
    $binding = $freeze.source_bindings[$index]
    $retained = $freeze.content_addressed_inputs.source_bindings[$index]
    $relative = [string]$binding.path
    $gitOid = (git -C $repoRoot rev-parse "${sourceCommit}:$relative").Trim()
    Assert-R23D34 (
        $LASTEXITCODE -eq 0 -and
        [string]$binding.git_blob_oid -ceq $gitOid -and
        [bool]$binding.raw_checkout_equals_git_blob -and
        [string]$retained.sha256 -ceq [string]$binding.raw_sha256
    ) "source binding changed: $relative"
    [void](Assert-Cas ([string]$retained.sha256) ([long]$retained.byte_length))
}

$coreRuntime = @($freeze.runtime_artifacts | Where-Object {
    [string]$_.name -ceq "locomotion_core_release"
})
$godotRuntime = @($freeze.runtime_artifacts | Where-Object {
    [string]$_.name -ceq "godot_adapter_debug"
})
Assert-R23D34 (
    $coreRuntime.Count -eq 1 -and
    [string]$coreRuntime[0].raw_sha256 -ceq
        [string]$closure.physical_evidence.locomotion_core_release_sha256 -and
    $godotRuntime.Count -eq 1 -and
    [string]$godotRuntime[0].raw_sha256 -ceq
        [string]$closure.physical_evidence.godot_adapter_debug_sha256
) "runtime binding changed"
foreach ($runtime in @($freeze.content_addressed_inputs.runtime_bindings)) {
    [void](Assert-Cas ([string]$runtime.sha256) ([long]$runtime.byte_length))
}

Assert-R23D34 (
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    @($attempt.ordered_matrix_cell_ids).Count -eq 6 -and
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

Assert-R23D34 (
    @($terminalManifest).Count -eq 6 -and
    @($report.ordered_cells).Count -eq 6 -and
    @($evaluation.cell_evaluations).Count -eq 6 -and
    [string]$report.result_classification -ceq
        "invalid_complete_native_two_engine_transfer" -and
    [string]$evaluation.classification -ceq
        "invalid_complete_native_two_engine_transfer" -and
    [bool]$evaluation.all_cells_run_regardless_of_intermediate_outcome -and
    -not [bool]$evaluation.terminal_restoration_or_taper_invoked -and
    [string]$completion.status -ceq
        "invalid_complete_native_two_engine_transfer" -and
    [int]$completion.cell_count -eq 6 -and
    [int]$completion.world_count -eq 6 -and
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
Assert-R23D34 (
    ($expectedTerminalPaths -join '|') -ceq ($observedTerminalPaths -join '|')
) "terminal manifest changed"

$observedWorldAttempts = 0
$observedWorldBuilds = 0
$godotNativeApplications = 0
$mujocoValidNegativeCells = 0
foreach ($expected in @($closure.ordered_cells)) {
    $reportCell = @($report.ordered_cells | Where-Object {
        [string]$_.cell_id -ceq [string]$expected.cell_id
    })
    $evaluatedCell = @($evaluation.cell_evaluations | Where-Object {
        [string]$_.cell_id -ceq [string]$expected.cell_id
    })
    Assert-R23D34 ($reportCell.Count -eq 1 -and $evaluatedCell.Count -eq 1) (
        "cell missing or duplicated: $($expected.cell_id)"
    )
    Assert-R23D34 (
        [string]$reportCell[0].terminal_entry_cas.sha256 -ceq
            [string]$expected.terminal_sha256 -and
        [long]$reportCell[0].terminal_entry_cas.byte_length -eq
            [long]$expected.terminal_byte_length -and
        [string]$evaluatedCell[0].entry_kind -ceq [string]$expected.entry_kind -and
        [int]$evaluatedCell[0].world_attempt_count -eq
            [int]$expected.world_attempt_count -and
        [int]$evaluatedCell[0].world_build_count -eq
            [int]$expected.world_build_count
    ) "cell receipt changed: $($expected.cell_id)"

    $terminal = Read-CasJson `
        ([string]$expected.terminal_sha256) `
        ([long]$expected.terminal_byte_length)
    Assert-R23D34 (
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.campaign_id -ceq [string]$closure.campaign_id -and
        [string]$terminal.cell_id -ceq [string]$expected.cell_id -and
        [string]$terminal.engine_id -ceq [string]$expected.engine_id -and
        [string]$terminal.arm_id -ceq [string]$expected.arm_id -and
        -not [bool]$terminal.claims.physical_acceptance_authority
    ) "terminal identity changed: $($expected.cell_id)"

    if ([string]$expected.engine_id -ceq "godot_jolt") {
        $summary = $terminal.raw_sdk_authority_summary
        $terminalFields = @($terminal.PSObject.Properties.Name)
        Assert-R23D34 (
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d34_worker_failure_v1" -and
            [string]$terminal.failure_code -ceq [string]$expected.failure_code -and
            [string]$terminal.failure_stage -ceq "controller_horizon_complete" -and
            $null -eq $terminal.trace_artifact -and
            -not ($terminalFields -ccontains "row_count") -and
            -not ($terminalFields -ccontains "failure_codes") -and
            [bool]$terminal.godot_execution_predicates.ok -and
            @($terminal.godot_execution_predicates.failed_predicate_ids).Count -eq 0 -and
            @($terminal.godot_execution_predicates.ordered_predicates).Count -eq 7 -and
            [bool]$summary.ok -and
            [int]$summary.step_count -eq 2992 -and
            [int]$summary.validated_balanced_wave_command_count -eq 23936 -and
            [int]$summary.mismatch_count -eq 0 -and
            [int]$summary.native_actuation_application_count -eq 23936 -and
            [int]$summary.native_safe_disable_application_count -eq 0 -and
            @($summary.failure_codes).Count -eq 0 -and
            -not [bool]$evaluatedCell[0].execution_valid -and
            -not [bool]$evaluatedCell[0].common_physical_gate_passed -and
            (@($evaluatedCell[0].failed_gate_ids) -join '|') -ceq
                "QSDK_R23D34_GJT_TRACE_INCOMPLETE"
        ) "Godot trace invalidation changed: $($expected.arm_id)"
        $godotNativeApplications += [int]$summary.native_actuation_application_count
        $observedWorldAttempts += [int]$terminal.world_attempt_count
        $observedWorldBuilds += [int]$terminal.world_build_count
    } else {
        Assert-R23D34 (
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d34_engine_cell_report_v1" -and
            [bool]$terminal.execution.integrity_passed -and
            [int]$terminal.execution.world_attempt_count -eq 1 -and
            [int]$terminal.execution.world_build_count -eq 1 -and
            [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
            [int]$terminal.execution.validated_portable_command_count -eq 23936 -and
            [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
            [string]$terminal.execution.worker_failure_code -ceq "" -and
            [int]$terminal.measurements.actuator_application_mismatch_count -eq 0 -and
            [int]$terminal.measurements.safe_no_actuation_count -eq 0 -and
            [double]$terminal.measurements.final_forward_displacement_m -eq
                [double]$expected.final_forward_displacement_m -and
            [double]$terminal.measurements.maximum_tilt_rad -eq
                [double]$expected.maximum_tilt_rad -and
            [double]$terminal.measurements.minimum_torso_height_m -eq
                [double]$expected.minimum_torso_height_m -and
            [int]$terminal.measurements.torso_ground_contact_step_count -eq
                [int]$expected.torso_ground_contact_step_count -and
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
            [bool]$evaluatedCell[0].execution_valid -and
            -not [bool]$evaluatedCell[0].common_physical_gate_passed -and
            (@($evaluatedCell[0].failed_gate_ids) -join '|') -ceq
                ($expectedMuJoCoFailedGates -join '|')
        ) "MuJoCo finite negative changed: $($expected.arm_id)"

        $tracePath = Assert-Cas `
            ([string]$terminal.trace_artifact.sha256) `
            ([long]$terminal.trace_artifact.byte_length)
        $traceLines = @(Get-Content -LiteralPath $tracePath)
        Assert-R23D34 ($traceLines.Count -eq 2992) (
            "MuJoCo trace row count changed: $($expected.arm_id)"
        )
        $firstTorsoContactStep = $null
        $firstTurnStep = $null
        for ($rowIndex = 0; $rowIndex -lt $traceLines.Count; $rowIndex++) {
            $row = $traceLines[$rowIndex] | ConvertFrom-Json -Depth 30
            Assert-R23D34 (
                [string]$row.schema_version -ceq
                    "sporespore_qsdk_r23d3_turn_diagnostic_trace_row_v1" -and
                [string]$row.cell_id -ceq [string]$expected.cell_id -and
                [int]$row.semantic_step -eq $rowIndex
            ) "MuJoCo trace row changed: $($expected.arm_id)/$rowIndex"
            if ($null -eq $firstTorsoContactStep -and [bool]$row.torso_ground_contact) {
                $firstTorsoContactStep = [int]$row.semantic_step
            }
            if ($null -eq $firstTurnStep -and
                [string]$row.segment_id -ceq "commanded_turn") {
                $firstTurnStep = [int]$row.semantic_step
            }
        }
        Assert-R23D34 (
            [int]$firstTorsoContactStep -eq [int]$expected.first_torso_contact_step -and
            [int]$firstTorsoContactStep -eq 194 -and
            [int]$firstTurnStep -eq 600 -and
            [int]$firstTorsoContactStep -lt [int]$firstTurnStep
        ) "MuJoCo fall timing changed: $($expected.arm_id)"
        $mujocoValidNegativeCells += 1
        $observedWorldAttempts += [int]$terminal.execution.world_attempt_count
        $observedWorldBuilds += [int]$terminal.execution.world_build_count
    }
}

Assert-R23D34 (
    $observedWorldAttempts -eq 6 -and
    $observedWorldBuilds -eq 6 -and
    $godotNativeApplications -eq 71808 -and
    $mujocoValidNegativeCells -eq 3 -and
    [int]$closure.attempt_summary.declared_cell_count -eq 6 -and
    [int]$closure.attempt_summary.terminal_cell_count -eq 6 -and
    [int]$closure.attempt_summary.execution_valid_cell_count -eq 3 -and
    [int]$closure.attempt_summary.common_physical_gate_pass_count -eq 0 -and
    [int]$closure.attempt_summary.worker_failure_count -eq 3 -and
    [bool]$closure.physical_findings.closed_repairs_held.godot_policy_specific_v8_and_persistent_memory_validator_passed_all_steps -and
    [bool]$closure.physical_findings.closed_repairs_held.mujoco_wrapper_preflight_reached_all_physical_worlds -and
    [bool]$closure.physical_findings.godot_jolt.observed_on_all_three_arms -and
    -not [bool]$closure.physical_findings.godot_jolt.trace_rows_retained -and
    [bool]$closure.physical_findings.mujoco.observed_on_all_three_arms -and
    [bool]$closure.physical_findings.mujoco.fall_preceded_turn_command -and
    -not [bool]$closure.bounded_interpretation.aggregate_campaign_valid_complete -and
    -not [bool]$closure.bounded_interpretation.aggregate_campaign_scientific_locomotion_negative -and
    -not [bool]$closure.bounded_interpretation.godot_jolt_walking_outcome_observed -and
    -not [bool]$closure.bounded_interpretation.godot_jolt_turning_outcome_observed -and
    [bool]$closure.bounded_interpretation.mujoco_execution_valid_finite_negative -and
    [bool]$closure.bounded_interpretation.mujoco_baseline_walking_transfer_failed_on_declared_fixture -and
    -not [bool]$closure.bounded_interpretation.mujoco_turning_test_reached_from_valid_walking_baseline -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "bounded interpretation changed"

Write-Output (
    "QSDK_R23D34_CLOSURE_PASS cells=6 worlds=6 " +
    "godot_native_applications=71808 mujoco_valid_negative_cells=3 " +
    "same_identity_rerun=false"
)
