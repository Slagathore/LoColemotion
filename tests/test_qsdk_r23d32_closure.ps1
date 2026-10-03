#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d32_finite_rapier_turning_replication_closure_v1.json"
)
$supervisorPath = Join-Path $repoRoot "sdk\run_qsdk_r23d32_supervisor.ps1"
$twoPi = 2.0 * [Math]::PI
$tolerance = 1.0e-12

function Assert-R23D32([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D32 CLOSURE: $Message" }
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-Artifact($Record) {
    $path = [string]$Record.path
    Assert-R23D32 (Test-Path -LiteralPath $path -PathType Leaf) (
        "retained artifact missing: $path"
    )
    Assert-R23D32 ((Get-Item -LiteralPath $path).Length -eq [long]$Record.byte_length) (
        "retained artifact length changed: $path"
    )
    Assert-R23D32 ((Get-Sha256 $path) -ceq [string]$Record.sha256) (
        "retained artifact digest changed: $path"
    )
}

function Get-CasPayload([string]$EvidenceRoot, [string]$Sha256) {
    Assert-R23D32 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') "invalid CAS digest"
    return Join-Path $EvidenceRoot (
        "artifacts\sha256\{0}\payload.bin" -f $Sha256.Substring(7)
    )
}

function Assert-Near(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D32 (
        [double]::IsFinite($Actual) -and
        [double]::IsFinite($Expected) -and
        [Math]::Abs($Actual - $Expected) -le $Tolerance
    ) $Message
}

function Assert-ArrayNear($Actual, $Expected, [double]$Tolerance, [string]$Message) {
    $actualValues = @($Actual)
    $expectedValues = @($Expected)
    Assert-R23D32 ($actualValues.Count -eq $expectedValues.Count) "$Message count"
    for ($index = 0; $index -lt $actualValues.Count; $index++) {
        Assert-Near `
            ([double]$actualValues[$index]) `
            ([double]$expectedValues[$index]) `
            $Tolerance `
            "$Message index=$index"
    }
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
Assert-R23D32 (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d32_finite_rapier_turning_replication_closure_v1" -and
    [string]$closure.status -ceq
        "closed_valid_complete_positive_finite_rapier_turning_validation" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D32-RAPIER-FINITE-TURNING-REPLICATION-VALIDATION" -and
    [string]$closure.source_commit -ceq
        "d92ef53681071bb4f25c393dff69004b151901d2" -and
    [string]$closure.source_tree_git_oid -ceq
        "06bb99d0b7e5b3c1635c7b2c9f4c8e56caad249c" -and
    [string]$closure.attempt_id -ceq "4cbefc628ded4863ab712d9d56fff189" -and
    [int]$closure.campaign_seed -eq 21506 -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed
) "closure identity changed"

$gitTree = (& git -C $repoRoot rev-parse "$($closure.source_commit)^{tree}").Trim()
Assert-R23D32 ($LASTEXITCODE -eq 0 -and $gitTree -ceq [string]$closure.source_tree_git_oid) (
    "source commit or tree is unavailable"
)
$predecessorPath = Join-Path $repoRoot (
    [string]$closure.replication_lineage.predecessor_closure_path
)
Assert-R23D32 (
    (Test-Path -LiteralPath $predecessorPath -PathType Leaf) -and
    (Get-Sha256 $predecessorPath) -ceq
        [string]$closure.replication_lineage.predecessor_closure_sha256 -and
    [int]$closure.replication_lineage.predecessor_seed -eq 21505 -and
    -not [bool]$closure.replication_lineage.predecessor_identity_rerun -and
    -not [bool]$closure.replication_lineage.controller_behavior_changed -and
    -not [bool]$closure.replication_lineage.measurement_changed -and
    -not [bool]$closure.replication_lineage.threshold_changed -and
    [int]$closure.replication_lineage.fresh_fixture_seed -eq 21506 -and
    [int]$closure.replication_lineage.combined_independently_held_out_positive_fixture_count -eq 2
) "replication lineage changed"

Assert-Artifact ([pscustomobject]@{
    path = $closure.qualification.scoped_attestation_path
    sha256 = $closure.qualification.scoped_attestation_sha256
    byte_length = $closure.qualification.scoped_attestation_byte_length
})
Assert-Artifact ([pscustomobject]@{
    path = $closure.qualification.adoption_path
    sha256 = $closure.qualification.adoption_sha256
    byte_length = $closure.qualification.adoption_byte_length
})
foreach ($name in @(
    "physical_freeze", "attempt", "terminal_manifest", "report",
    "completion", "source_archive"
)) { Assert-Artifact $closure.physical_evidence.$name }

$attestation = Get-Content -Raw -LiteralPath (
    [string]$closure.qualification.scoped_attestation_path
) | ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath (
    [string]$closure.qualification.adoption_path
) | ConvertFrom-Json -Depth 100
Assert-R23D32 (
    [string]$attestation.source.commit -ceq [string]$closure.source_commit -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 3 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 18 -and
    [bool]$attestation.all_gates_executed -and
    -not [bool]$attestation.claims.physical_campaign_executed -and
    -not [bool]$attestation.claims.physical_acceptance_authority -and
    [string]$adoption.source_commit -ceq [string]$closure.source_commit -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification receipt changed"

$freeze = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.physical_freeze.path
) | ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.attempt.path
) | ConvertFrom-Json -Depth 100
$report = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.report.path
) | ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.completion.path
) | ConvertFrom-Json -Depth 100
$terminalManifest = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.terminal_manifest.path
) | ConvertFrom-Json -Depth 100
$sourceCommit = [string]$closure.source_commit
$preregistrationRelative =
    "sdk/turning/r23d32_finite_rapier_turning_replication_preregistration_v1.json"
$implementationRelative =
    "sdk/turning/r23d32_finite_rapier_turning_replication_implementation_v1.json"
$preregistrationBlobOid = (
    & git -C $repoRoot rev-parse "${sourceCommit}:$preregistrationRelative"
).Trim()
Assert-R23D32 ($LASTEXITCODE -eq 0) "preregistration Git blob is unavailable"
$implementationBlobOid = (
    & git -C $repoRoot rev-parse "${sourceCommit}:$implementationRelative"
).Trim()
Assert-R23D32 ($LASTEXITCODE -eq 0) "implementation Git blob is unavailable"
$preregistrationBinding = @($freeze.source_bindings | Where-Object {
    [string]$_.path -ceq $preregistrationRelative
})
$implementationBinding = @($freeze.source_bindings | Where-Object {
    [string]$_.path -ceq $implementationRelative
})
Assert-R23D32 (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq [string]$closure.source_tree_git_oid -and
    [string]$freeze.runtime_artifact.raw_sha256 -ceq
        [string]$closure.physical_evidence.runtime_sha256 -and
    @($freeze.source_bindings).Count -eq 222 -and
    @($freeze.source_bindings | Where-Object {
        -not [bool]$_.materialized_bytes_equal_git_blob
    }).Count -eq 0 -and
    $preregistrationBinding.Count -eq 1 -and
    [string]$preregistrationBinding[0].git_blob_oid -ceq $preregistrationBlobOid -and
    [string]$preregistrationBinding[0].raw_sha256 -ceq
        [string]$freeze.preregistration_raw_sha256 -and
    $implementationBinding.Count -eq 1 -and
    [string]$implementationBinding[0].git_blob_oid -ceq $implementationBlobOid -and
    [string]$implementationBinding[0].raw_sha256 -ceq
        [string]$freeze.implementation_contract_raw_sha256 -and
    [bool]$freeze.source_bytes_consumed_by_build_equal_git_blobs -and
    [bool]$freeze.ambient_checkout_is_not_build_authority -and
    [int]$freeze.declared_matrix_world_count -eq 3 -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.physical_execution_authorized -and
    [string]$attempt.campaign_attestation_adoption_sha256 -ceq
        [string]$closure.qualification.adoption_sha256 -and
    @($terminalManifest).Count -eq 3 -and
    [string]$report.result_classification -ceq
        "valid_complete_positive_finite_rapier_turning_validation" -and
    [string]$completion.status -ceq
        "valid_complete_positive_finite_rapier_turning_validation_first_attempt" -and
    [string]$completion.result_classification -ceq
        "valid_complete_positive_finite_rapier_turning_validation" -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed
) "physical freeze or complete report changed"

$evidenceRoot = Split-Path -Parent ([string]$closure.physical_evidence.attempt_root)
$reportCells = @($report.complete_evaluation.cell_evaluations)
$matrixCells = @($report.ordered_matrix_cells)
$measurementsByArm = @{}
$totalRows = 0
$totalTriggers = 0
$totalHoldRows = 0
$totalSaturationRows = 0
foreach ($cell in @($closure.ordered_cells)) {
    $reportCell = @($reportCells | Where-Object {
        [string]$_.arm_id -ceq [string]$cell.arm_id
    })
    $matrixCell = @($matrixCells | Where-Object {
        [string]$_.arm_id -ceq [string]$cell.arm_id
    })
    Assert-R23D32 ($reportCell.Count -eq 1 -and $matrixCell.Count -eq 1) (
        "report cell missing: $($cell.arm_id)"
    )
    $reportCell = $reportCell[0]
    $matrixCell = $matrixCell[0]
    Assert-R23D32 (
        [string]$reportCell.cell_id -ceq [string]$cell.cell_id -and
        [bool]$reportCell.execution_valid -and
        [bool]$reportCell.common_physical_gate_passed -and
        [bool]$reportCell.gate_passed -and
        @($reportCell.failure_codes).Count -eq 0 -and
        [double]$reportCell.final_forward_displacement_m -eq
            [double]$cell.final_forward_displacement_m -and
        [double]$reportCell.turn_phase_yaw_delta_rad -eq
            [double]$cell.turn_phase_yaw_delta_rad -and
        [double]$reportCell.maximum_tilt_rad -eq [double]$cell.maximum_tilt_rad -and
        [double]$reportCell.minimum_torso_height_m -eq
            [double]$cell.minimum_torso_height_m -and
        [string]$matrixCell.terminal_entry_cas.sha256 -ceq
            [string]$cell.terminal_sha256 -and
        [long]$matrixCell.terminal_entry_cas.byte_length -eq
            [long]$cell.terminal_byte_length
    ) "report cell changed: $($cell.arm_id)"

    $terminalPath = Get-CasPayload $evidenceRoot ([string]$cell.terminal_sha256)
    Assert-R23D32 (
        (Test-Path -LiteralPath $terminalPath -PathType Leaf) -and
        (Get-Sha256 $terminalPath) -ceq [string]$cell.terminal_sha256 -and
        (Get-Item -LiteralPath $terminalPath).Length -eq
            [long]$cell.terminal_byte_length
    ) "terminal CAS changed: $($cell.arm_id)"
    $terminal = Get-Content -Raw -LiteralPath $terminalPath |
        ConvertFrom-Json -Depth 100
    $tracePath = Get-CasPayload $evidenceRoot ([string]$cell.trace_sha256)
    Assert-R23D32 (
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d32_engine_cell_report_v1" -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.campaign_id -ceq [string]$closure.campaign_id -and
        [int]$terminal.campaign_seed -eq 21506 -and
        [string]$terminal.controller_policy_id -ceq
            "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1" -and
        [string]$terminal.trace_artifact.payload_path -ceq $tracePath -and
        [string]$terminal.trace_artifact.sha256 -ceq [string]$cell.trace_sha256 -and
        (Test-Path -LiteralPath $tracePath -PathType Leaf) -and
        (Get-Sha256 $tracePath) -ceq [string]$cell.trace_sha256 -and
        (Get-Item -LiteralPath $tracePath).Length -eq [long]$cell.trace_byte_length -and
        [int]$terminal.trace_summary.row_count -eq 2992 -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.measurements.torso_ground_contact_step_count -eq 0 -and
        [int]$terminal.measurements.controller_error_count -eq 0 -and
        [int]$terminal.measurements.nonfinite_observation_count -eq 0 -and
        [int]$terminal.measurements.actuator_application_mismatch_count -eq 0 -and
        [double]$terminal.measurements.final_forward_displacement_m -ge 0.030123046875 -and
        [double]$terminal.measurements.maximum_tilt_rad -le 0.6 -and
        [double]$terminal.measurements.minimum_torso_height_m -ge 0.2499708652072946
    ) "terminal or physical receipt changed: $($cell.arm_id)"
    $cycles = @(
        [int]$terminal.measurements.contact_cycle_count_by_limb.front_left,
        [int]$terminal.measurements.contact_cycle_count_by_limb.front_right,
        [int]$terminal.measurements.contact_cycle_count_by_limb.rear_left,
        [int]$terminal.measurements.contact_cycle_count_by_limb.rear_right
    )
    Assert-R23D32 (
        ($cycles | ConvertTo-Json -Compress) -ceq
            (@($cell.contact_cycles_by_limb) | ConvertTo-Json -Compress) -and
        @($cycles | Where-Object { $_ -lt 2 }).Count -eq 0
    ) "contact-cycle receipt changed: $($cell.arm_id)"

    $expectedStep = 0
    $triggerCount = 0
    $holdCount = 0
    $saturationCount = 0
    $unwrappedYaw = [Collections.Generic.List[double]]::new()
    $previousRawYaw = 0.0
    $previousUnwrappedYaw = 0.0
    Get-Content -LiteralPath $tracePath | ForEach-Object {
        $row = $_ | ConvertFrom-Json -Depth 30
        $expectedPhase = if ($expectedStep -lt 600) {
            "reference_warmup"
        } elseif ($expectedStep -lt 1800) {
            "commanded_turn"
        } elseif ($expectedStep -lt 2400) {
            "reference_recovery"
        } else {
            "reference_continuation"
        }
        $yaw = [double]$row.measured_yaw_rad
        Assert-R23D32 (
            [int]$row.trace_step -eq $expectedStep -and
            [string]$row.cell_id -ceq [string]$cell.cell_id -and
            [int]$row.campaign_seed -eq 21506 -and
            [string]$row.phase_id -ceq $expectedPhase -and
            [string]$row.schema_version -ceq
                "sporespore_qsdk_r23d32_physical_trace_row_v1" -and
            [double]::IsFinite($yaw) -and
            @($row.ordered_final_canonical_velocities_rad_s).Count -eq 8 -and
            @($row.ordered_actuator_velocity_limits_rad_s).Count -eq 8
        ) "trace changed: $($cell.arm_id)/$expectedStep"
        if ($expectedStep -eq 0) {
            $previousRawYaw = $yaw
            $previousUnwrappedYaw = $yaw
            $unwrappedYaw.Add($yaw)
        } else {
            $delta = [Math]::IEEERemainder($yaw - $previousRawYaw, $twoPi)
            Assert-R23D32 (
                [double]::IsFinite($delta) -and
                [Math]::Abs([Math]::Abs($delta) - [Math]::PI) -gt $tolerance
            ) "ambiguous yaw unwrap: $($cell.arm_id)/$expectedStep"
            $previousUnwrappedYaw += $delta
            $unwrappedYaw.Add($previousUnwrappedYaw)
            $previousRawYaw = $yaw
        }
        if ([bool]$row.steering_authority_guard.floor_hold_triggered_this_step) {
            $triggerCount++
        }
        if ([bool]$row.steering_authority_guard.floor_hold_active_this_step) {
            $holdCount++
        }
        if ([bool]$row.steering_saturated) { $saturationCount++ }
        $expectedStep++
    }
    Assert-R23D32 (
        $expectedStep -eq [int]$cell.trace_row_count -and
        $triggerCount -eq [int]$cell.floor_hold_trigger_step_count -and
        $holdCount -eq [int]$cell.floor_hold_active_step_count -and
        $saturationCount -eq [int]$cell.steering_saturation_step_count -and
        [int]$terminal.trace_summary.floor_hold_trigger_step_count -eq $triggerCount -and
        [int]$terminal.trace_summary.floor_hold_active_step_count -eq $holdCount -and
        [int]$terminal.trace_summary.floor_hold_steps_remaining_after_trace -eq 0
    ) "trace summary changed: $($cell.arm_id)"

    $baselineMean = Get-WindowMean $unwrappedYaw 240 600
    $terminalMean = Get-WindowMean $unwrappedYaw 1440 1800
    $swingShifts = [Collections.Generic.List[double]]::new()
    for ($swing = 0; $swing -lt 5; $swing++) {
        $start = 1440 + $swing * 72
        $swingShifts.Add((Get-WindowMean $unwrappedYaw $start ($start + 72)) - $baselineMean)
    }
    $measurementsByArm[[string]$cell.arm_id] = [ordered]@{
        cycle_shift_rad = $terminalMean - $baselineMean
        terminal_swing_shift_rad = @($swingShifts)
    }
    $totalRows += $expectedStep
    $totalTriggers += $triggerCount
    $totalHoldRows += $holdCount
    $totalSaturationRows += $saturationCount
}

$reference = $measurementsByArm.reference_zero
$positive = $measurementsByArm.positive_heading
$negative = $measurementsByArm.negative_heading
$positiveConditioned = [double]$positive.cycle_shift_rad -
    [double]$reference.cycle_shift_rad
$negativeConditioned = [double]$reference.cycle_shift_rad -
    [double]$negative.cycle_shift_rad
$positiveSwingConditioned = @()
$negativeSwingConditioned = @()
for ($index = 0; $index -lt 5; $index++) {
    $positiveSwingConditioned += (
        [double]$positive.terminal_swing_shift_rad[$index] -
        [double]$reference.terminal_swing_shift_rad[$index]
    )
    $negativeSwingConditioned += (
        [double]$reference.terminal_swing_shift_rad[$index] -
        [double]$negative.terminal_swing_shift_rad[$index]
    )
}
$reportedMeasurement = $report.complete_evaluation.cycle_integrated_measurement
$closedMeasurement = $closure.cycle_integrated_evaluation
foreach ($armId in @("reference_zero", "positive_heading", "negative_heading")) {
    Assert-Near `
        ([double]$measurementsByArm[$armId].cycle_shift_rad) `
        ([double]$reportedMeasurement.arms.$armId.cycle_shift_rad) `
        $tolerance `
        "reported cycle shift changed: $armId"
    Assert-Near `
        ([double]$measurementsByArm[$armId].cycle_shift_rad) `
        ([double]$closedMeasurement.cycle_shift_rad_by_arm.$armId) `
        $tolerance `
        "closed cycle shift changed: $armId"
    Assert-ArrayNear `
        $measurementsByArm[$armId].terminal_swing_shift_rad `
        $closedMeasurement.terminal_swing_shift_rad_by_arm.$armId `
        $tolerance `
        "closed swing shifts changed: $armId"
}
Assert-Near $positiveConditioned (
    [double]$closedMeasurement.positive_reference_conditioned_cycle_shift_rad
) $tolerance "positive conditioned cycle shift changed"
Assert-Near $negativeConditioned (
    [double]$closedMeasurement.negative_reference_conditioned_cycle_shift_rad
) $tolerance "negative conditioned cycle shift changed"
Assert-Near ($positiveConditioned + $negativeConditioned) (
    [double]$closedMeasurement.bilateral_reference_conditioned_cycle_separation_rad
) $tolerance "bilateral conditioned separation changed"
Assert-ArrayNear $positiveSwingConditioned (
    $closedMeasurement.positive_terminal_swing_conditioned_shift_rad
) $tolerance "positive conditioned swing shifts changed"
Assert-ArrayNear $negativeSwingConditioned (
    $closedMeasurement.negative_terminal_swing_conditioned_shift_rad
) $tolerance "negative conditioned swing shifts changed"

$rawCycleGate = (
    [double]$positive.cycle_shift_rad -ge 0.01 -and
    [double]$negative.cycle_shift_rad -le -0.01
)
$conditionedCycleGate = (
    $positiveConditioned -ge 0.01 -and $negativeConditioned -ge 0.01
)
$rawSwingDiagnostic = (
    @($positive.terminal_swing_shift_rad | Where-Object { [double]$_ -le 1.0e-12 }).Count -eq 0 -and
    @($negative.terminal_swing_shift_rad | Where-Object { [double]$_ -ge -1.0e-12 }).Count -eq 0
)
$conditionedSwingDiagnostic = (
    @($positiveSwingConditioned | Where-Object { [double]$_ -le 1.0e-12 }).Count -eq 0 -and
    @($negativeSwingConditioned | Where-Object { [double]$_ -le 1.0e-12 }).Count -eq 0
)
Assert-R23D32 (
    $totalRows -eq 8976 -and
    $totalTriggers -eq 194 -and
    $totalHoldRows -eq 2067 -and
    $totalSaturationRows -eq 1465 -and
    $rawCycleGate -and
    $conditionedCycleGate -and
    $rawSwingDiagnostic -and
    $conditionedSwingDiagnostic -and
    [bool]$report.complete_evaluation.all_common_physical_gates_passed -and
    [bool]$report.complete_evaluation.common_physical_verdict_computed_before_measurement -and
    [string]$report.complete_evaluation.classification -ceq
        "valid_complete_positive_finite_rapier_turning_validation" -and
    [string]$report.complete_evaluation.selected_candidate_id -ceq
        "two_swing_persistent_predictive_stability_guarded_0p20_to_0p28" -and
    @($report.complete_evaluation.eligible_candidate_ids).Count -eq 1 -and
    [bool]$report.complete_evaluation.selection_is_controller_validation -and
    -not [bool]$report.complete_evaluation.selection_is_measurement_validation -and
    [bool]$report.complete_evaluation.replicates_r23d31_selected_measurement -and
    [int]$report.complete_evaluation.combined_independently_held_out_positive_fixture_count -eq 2 -and
    (@($report.complete_evaluation.finite_scope.validated_seed_ids_if_positive) -join ',') -ceq
        "21505,21506" -and
    -not [bool]$report.complete_evaluation.finite_scope.population_inference -and
    -not [bool]$report.complete_evaluation.finite_scope.portable_inference -and
    [bool]$reportedMeasurement.gates.raw_signed_cycle_shift -and
    [bool]$reportedMeasurement.gates.reference_conditioned_cycle_shift -and
    [bool]$reportedMeasurement.nonselecting_diagnostics.every_terminal_swing_raw_direction -and
    [bool]$reportedMeasurement.nonselecting_diagnostics.every_terminal_swing_reference_conditioned_direction -and
    [bool]$reportedMeasurement.passed -and
    [bool]$closure.claims.finite_rapier_cycle_integrated_measurement_validation -and
    [bool]$closure.claims.finite_rapier_turning_validation -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "complete positive bounded interpretation changed"

$refusalOutput = @(
    & pwsh -NoLogo -NoProfile -File $supervisorPath -RunPhysical `
        -CampaignAttestationAdoption ([string]$closure.qualification.adoption_path) 2>&1
)
Assert-R23D32 (
    $LASTEXITCODE -eq 0 -and
    @($refusalOutput | Where-Object {
        ([string]$_).StartsWith(
            "QSDK_R23D32_PHYSICAL_REFUSAL ",
            [StringComparison]::Ordinal
        )
    }).Count -eq 1
) "same-identity physical refusal changed: $($refusalOutput -join ' ')"

Write-Host (
    "QSDK_R23D32_CLOSURE_PASS cells=3 worlds=3 valid=3 physical_pass=3 " +
    "turning_pass=3 selected=CONTROLLER rows=8976 triggers=194 hold_rows=2067 " +
    "saturation_rows=1465 source_bindings=222 held_out_fixtures=2 rerun=False " +
    "rapier_turning=True three_engine=False equivalence=False release=False"
)
