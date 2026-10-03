#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d29_two_swing_persistent_predictive_stability_guarded_steering_closure_v1.json"
)
$supervisorPath = Join-Path $repoRoot "sdk\run_qsdk_r23d29_supervisor.ps1"

function Assert-R23D29([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D29 CLOSURE: $Message" }
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-Artifact($Record) {
    $path = [string]$Record.path
    Assert-R23D29 (Test-Path -LiteralPath $path -PathType Leaf) (
        "retained artifact missing: $path"
    )
    Assert-R23D29 ((Get-Item -LiteralPath $path).Length -eq [long]$Record.byte_length) (
        "retained artifact length changed: $path"
    )
    Assert-R23D29 ((Get-Sha256 $path) -ceq [string]$Record.sha256) (
        "retained artifact digest changed: $path"
    )
}

function Get-CasPayload([string]$EvidenceRoot, [string]$Sha256) {
    Assert-R23D29 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') "invalid CAS digest"
    return Join-Path $EvidenceRoot (
        "artifacts\sha256\{0}\payload.bin" -f $Sha256.Substring(7)
    )
}

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D29 (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d29_two_swing_persistent_predictive_stability_guarded_steering_closure_v1" -and
    [string]$closure.status -ceq
        "closed_valid_complete_negative_no_development_candidate" -and
    [string]$closure.source_commit -ceq
        "1d884df7dad03fb4b45f002e3278c91051ed2b27" -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed
) "closure identity changed"

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
Assert-R23D29 (
    [string]$attestation.source.commit -ceq [string]$closure.source_commit -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 2 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 17 -and
    [bool]$attestation.all_gates_executed -and
    -not [bool]$attestation.claims.physical_acceptance_authority -and
    [string]$adoption.source_commit -ceq [string]$closure.source_commit -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification receipt changed"

$freeze = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.physical_freeze.path
) | ConvertFrom-Json -Depth 100
$report = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.report.path
) | ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.completion.path
) | ConvertFrom-Json -Depth 100
$sourceCommit = [string]$closure.source_commit
$preregistrationRelative =
    "sdk/turning/r23d29_two_swing_persistent_predictive_stability_guarded_steering_preregistration_v1.json"
$implementationRelative =
    "sdk/turning/r23d29_two_swing_persistent_predictive_stability_guarded_steering_implementation_v1.json"
$preregistrationBlobOid = (
    & git -C $repoRoot rev-parse "${sourceCommit}:$preregistrationRelative"
).Trim()
Assert-R23D29 ($LASTEXITCODE -eq 0) "preregistration Git blob is unavailable"
$implementationBlobOid = (
    & git -C $repoRoot rev-parse "${sourceCommit}:$implementationRelative"
).Trim()
Assert-R23D29 ($LASTEXITCODE -eq 0) "implementation Git blob is unavailable"
$preregistrationBinding = @($freeze.source_bindings | Where-Object {
    [string]$_.path -ceq $preregistrationRelative
})
$implementationBinding = @($freeze.source_bindings | Where-Object {
    [string]$_.path -ceq $implementationRelative
})
Assert-R23D29 (
    [string]$freeze.source_commit -ceq [string]$closure.source_commit -and
    [string]$freeze.source_tree_git_oid -ceq [string]$closure.source_tree_git_oid -and
    [string]$freeze.runtime_artifact.raw_sha256 -ceq
        [string]$closure.physical_evidence.runtime_sha256 -and
    @($freeze.source_bindings).Count -eq 212 -and
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
    [string]$report.result_classification -ceq
        "valid_complete_negative_no_development_candidate" -and
    [string]$completion.result_classification -ceq
        "valid_complete_negative_no_development_candidate" -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed
) "physical freeze or complete report changed"

$evidenceRoot = Split-Path -Parent ([string]$closure.physical_evidence.attempt_root)
$reportCells = @($report.complete_evaluation.cell_evaluations)
$totalRows = 0
$totalTriggers = 0
$totalHoldRows = 0
$totalActiveTurnHoldRows = 0
$totalSaturationRows = 0
foreach ($cell in @($closure.ordered_cells)) {
    $reportCell = @($reportCells | Where-Object {
        [string]$_.arm_id -ceq [string]$cell.arm_id
    })
    Assert-R23D29 ($reportCell.Count -eq 1) "report cell missing"
    $reportCell = $reportCell[0]
    Assert-R23D29 (
        [string]$reportCell.cell_id -ceq [string]$cell.cell_id -and
        [bool]$reportCell.execution_valid -eq [bool]$cell.execution_valid -and
        [bool]$reportCell.gate_passed -eq [bool]$cell.gate_passed -and
        (@($reportCell.failure_codes) | ConvertTo-Json -Compress) -ceq
            (@($cell.failure_codes) | ConvertTo-Json -Compress) -and
        [double]$reportCell.final_forward_displacement_m -eq
            [double]$cell.final_forward_displacement_m -and
        [double]$reportCell.turn_phase_yaw_delta_rad -eq
            [double]$cell.turn_phase_yaw_delta_rad -and
        [double]$reportCell.maximum_tilt_rad -eq [double]$cell.maximum_tilt_rad -and
        [double]$reportCell.minimum_torso_height_m -eq
            [double]$cell.minimum_torso_height_m
    ) "report cell measurements changed: $($cell.arm_id)"

    $terminalPath = Get-CasPayload $evidenceRoot ([string]$cell.terminal_sha256)
    Assert-R23D29 (
        (Test-Path -LiteralPath $terminalPath -PathType Leaf) -and
        (Get-Sha256 $terminalPath) -ceq [string]$cell.terminal_sha256 -and
        (Get-Item -LiteralPath $terminalPath).Length -eq
            [long]$cell.terminal_byte_length
    ) "terminal CAS changed: $($cell.arm_id)"
    $terminal = Get-Content -Raw -LiteralPath $terminalPath |
        ConvertFrom-Json -Depth 100
    $tracePath = Get-CasPayload $evidenceRoot ([string]$cell.trace_sha256)
    Assert-R23D29 (
        [string]$terminal.trace_artifact.payload_path -ceq $tracePath -and
        [string]$terminal.trace_artifact.sha256 -ceq [string]$cell.trace_sha256 -and
        (Test-Path -LiteralPath $tracePath -PathType Leaf) -and
        (Get-Sha256 $tracePath) -ceq [string]$cell.trace_sha256 -and
        (Get-Item -LiteralPath $tracePath).Length -eq [long]$cell.trace_byte_length -and
        [int]$terminal.trace_summary.row_count -eq 2992 -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.measurements.torso_ground_contact_step_count -eq 0
    ) "terminal or trace receipt changed: $($cell.arm_id)"

    $cycles = @(
        [int]$terminal.measurements.contact_cycle_count_by_limb.front_left,
        [int]$terminal.measurements.contact_cycle_count_by_limb.front_right,
        [int]$terminal.measurements.contact_cycle_count_by_limb.rear_left,
        [int]$terminal.measurements.contact_cycle_count_by_limb.rear_right
    )
    Assert-R23D29 (
        ($cycles | ConvertTo-Json -Compress) -ceq
            (@($cell.contact_cycles_by_limb) | ConvertTo-Json -Compress)
    ) "contact-cycle receipt changed: $($cell.arm_id)"

    $expectedStep = 0
    $remaining = 0
    $triggerCount = 0
    $holdCount = 0
    $activeTurnTriggerCount = 0
    $activeTurnHoldCount = 0
    $segmentCount = 0
    $currentSegment = 0
    $longestSegment = 0
    $firstTrigger = $null
    $lastTrigger = $null
    $saturationCount = 0
    Get-Content -LiteralPath $tracePath | ForEach-Object {
        $row = $_ | ConvertFrom-Json -Depth 30
        $guard = $row.steering_authority_guard
        $instantaneous = [double]$guard.instantaneous_effective_maximum_steering_fraction
        $triggered = $instantaneous -le (0.20 + 1.0e-12)
        $refreshed = if ($triggered) { 144 } else { $remaining }
        $active = $refreshed -gt 0
        $expectedAfter = if ($active) { $refreshed - 1 } else { 0 }
        $expectedEffective = if ($active) { 0.20 } else { $instantaneous }
        Assert-R23D29 (
            [int]$row.trace_step -eq $expectedStep -and
            [string]$row.cell_id -ceq [string]$cell.cell_id -and
            [string]$row.schema_version -ceq
                "sporespore_qsdk_r23d29_physical_trace_row_v1" -and
            [string]$guard.schema_version -ceq
                "sporespore_steering_authority_guard_receipt_v3" -and
            [string]$guard.mode_id -ceq
                "persistent_predicted_tilt_and_contact_steering_authority_guard_v1" -and
            [double]$guard.prediction_horizon_s -eq 0.6 -and
            [int]$guard.prediction_horizon_scheduler_swing_steps -eq 72 -and
            [int]$guard.floor_hold_duration_steps -eq 144 -and
            [int]$guard.floor_hold_scheduler_swing_count -eq 2 -and
            [string]$guard.floor_hold_basis_id -ceq
                "two_balanced_wave_scheduler_swings_v1" -and
            [int]$guard.floor_hold_steps_remaining_before_step -eq $remaining -and
            [int]$guard.floor_hold_steps_remaining_after_step -eq $expectedAfter -and
            [bool]$guard.floor_hold_triggered_this_step -eq $triggered -and
            [bool]$guard.floor_hold_active_this_step -eq $active -and
            [Math]::Abs(
                [double]$guard.effective_maximum_steering_fraction - $expectedEffective
            ) -le 1.0e-12 -and
            [string]$guard.tilt_rate_source_id -ceq
                "state_frame_base_twist_world_angular_velocity_v1" -and
            [string]$guard.prediction_horizon_basis_id -ceq
                "one_balanced_wave_scheduler_swing_v1" -and
            [bool]$guard.direction_neutral -and
            [int]$guard.engine_identity_input_count -eq 0 -and
            [Math]::Abs([double]$row.held_steering_fraction) -le
                ([double]$guard.effective_maximum_steering_fraction + 1.0e-12) -and
            [Math]::Abs([double]$row.requested_steering_fraction) -le
                ([double]$guard.effective_maximum_steering_fraction + 1.0e-12) -and
            @($row.ordered_final_canonical_velocities_rad_s).Count -eq 8 -and
            @($row.ordered_actuator_velocity_limits_rad_s).Count -eq 8
        ) "persistent transition receipt changed: $($cell.arm_id)/$expectedStep"

        if ($triggered) {
            $triggerCount++
            if ($null -eq $firstTrigger) { $firstTrigger = $expectedStep }
            $lastTrigger = $expectedStep
            if ($expectedStep -ge 600 -and $expectedStep -lt 1800) {
                $activeTurnTriggerCount++
            }
        }
        if ($active) {
            $holdCount++
            if ($currentSegment -eq 0) { $segmentCount++ }
            $currentSegment++
            $longestSegment = [Math]::Max($longestSegment, $currentSegment)
            if ($expectedStep -ge 600 -and $expectedStep -lt 1800) {
                $activeTurnHoldCount++
            }
        } else {
            $currentSegment = 0
        }
        if ([bool]$row.steering_saturated) { $saturationCount++ }
        $remaining = $expectedAfter
        $expectedStep++
    }

    Assert-R23D29 (
        $expectedStep -eq [int]$cell.trace_row_count -and
        $triggerCount -eq [int]$cell.floor_hold_trigger_step_count -and
        $holdCount -eq [int]$cell.floor_hold_active_step_count -and
        $activeTurnTriggerCount -eq
            [int]$cell.active_turn_floor_hold_trigger_step_count -and
        $activeTurnHoldCount -eq [int]$cell.active_turn_floor_hold_active_step_count -and
        $segmentCount -eq [int]$cell.floor_hold_segment_count -and
        $longestSegment -eq [int]$cell.longest_floor_hold_segment_steps -and
        [int]$firstTrigger -eq [int]$cell.first_floor_hold_trigger_step -and
        [int]$lastTrigger -eq [int]$cell.last_floor_hold_trigger_step -and
        $saturationCount -eq [int]$cell.steering_saturation_step_count -and
        $remaining -eq 0 -and
        [int]$terminal.trace_summary.floor_hold_trigger_step_count -eq $triggerCount -and
        [int]$terminal.trace_summary.floor_hold_active_step_count -eq $holdCount -and
        [int]$terminal.trace_summary.floor_hold_steps_remaining_after_trace -eq 0
    ) "persistent summary changed: $($cell.arm_id)"
    $totalRows += $expectedStep
    $totalTriggers += $triggerCount
    $totalHoldRows += $holdCount
    $totalActiveTurnHoldRows += $activeTurnHoldCount
    $totalSaturationRows += $saturationCount
}

Assert-R23D29 (
    $totalRows -eq 8976 -and
    $totalTriggers -eq 193 -and
    $totalHoldRows -eq 2067 -and
    $totalActiveTurnHoldRows -eq 1455 -and
    $totalSaturationRows -eq 1473 -and
    [string]$report.complete_evaluation.classification -ceq
        "valid_complete_negative_no_development_candidate" -and
    $null -eq $report.complete_evaluation.selected_candidate_id -and
    @($report.complete_evaluation.eligible_candidate_ids).Count -eq 0 -and
    [Math]::Abs(
        [double]$report.complete_evaluation.candidate_summaries[0].positive_reference_conditioned_yaw_delta_rad -
        [double]$closure.complete_evaluation.positive_reference_conditioned_yaw_delta_rad
    ) -le 1.0e-15 -and
    [Math]::Abs(
        [double]$report.complete_evaluation.candidate_summaries[0].negative_reference_conditioned_yaw_delta_rad -
        [double]$closure.complete_evaluation.negative_reference_conditioned_yaw_delta_rad
    ) -le 1.0e-15 -and
    -not [bool]$closure.claims.finite_rapier_development_candidate -and
    -not [bool]$closure.claims.finite_rapier_turning_validation -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized
) "complete negative interpretation changed"

$refusalOutput = @(
    & pwsh -NoLogo -NoProfile -File $supervisorPath -RunPhysical `
        -CampaignAttestationAdoption ([string]$closure.qualification.adoption_path) 2>&1
)
Assert-R23D29 (
    $LASTEXITCODE -eq 0 -and
    @($refusalOutput | Where-Object {
        ([string]$_).StartsWith(
            "QSDK_R23D29_PHYSICAL_REFUSAL ",
            [StringComparison]::Ordinal
        )
    }).Count -eq 1
) "same-identity physical refusal changed: $($refusalOutput -join ' ')"

Write-Host (
    "QSDK_R23D29_CLOSURE_PASS cells=3 worlds=3 valid=3 passed=2 " +
    "negative=1 selected=NONE rows=8976 triggers=193 hold_rows=2067 " +
    "active_turn_hold_rows=1455 source_bindings=212 stable_cells=3 " +
    "rerun=False turning=False three_engine=False equivalence=False release=False"
)
