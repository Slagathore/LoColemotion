$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..")
)
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_selected_policy_commissioning_c2_closure.json"
$preregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_selected_policy_commissioning_c2_preregistration.json"
$c1ClosurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_selected_policy_commissioning_c1_closure.json"
$runnerPath = Join-Path (
    $sdkRoot
) "run_rapier_c6_bw19v_selected_policy_commissioning_c2.ps1"
$expectedClosureRawSha256 = (
    "sha256:" +
    "3047c2d9712a7d9b70c7423dab7df19bc8de96b1c39663b2bf0fb6e278fe5590"
)
$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "c2f4c071c7b55e20dd77f32b72370f6891c3b1b2426baa2fca2ac0e23730da27"
)
$expectedC1ClosureRawSha256 = (
    "sha256:" +
    "e2919cc899df78aebe5d2486bb7250a1388044f2f040f53f23f581d113aa8fae"
)
$campaignId = "C6-RAPIER-BW19V-SELECTED-POLICY-COMMISSIONING-C2"
$gateId = "C6-RAP-BW19V-C2"

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-CompactJson {
    param([AllowNull()][object]$Value)
    return $Value | ConvertTo-Json -Depth 50 -Compress
}

function Assert-TextContains {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Needle,
        [Parameter(Mandatory)][string]$Message
    )
    Assert-Exact ($Text.Contains($Needle)) $Message
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 $closurePath) -ceq $expectedClosureRawSha256
) "The C2 closure manifest is missing or byte-changed"
Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Get-RawSha256 $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256
) "The C2 preregistration changed after execution"
Assert-Exact (
    (Test-Path -LiteralPath $c1ClosurePath -PathType Leaf) -and
    (Get-RawSha256 $c1ClosurePath) -ceq $expectedC1ClosureRawSha256
) "The C1 predecessor closure changed"

$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json
$c1Closure = Get-Content -Raw -LiteralPath $c1ClosurePath |
    ConvertFrom-Json
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c2_closure_v1" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.status -ceq
        "closed_negative_corrected_composition_complete_physical_walking_gate_failed" -and
    [string]$closure.study_class -ceq
        "outcome_exposed_single_body_technical_commissioning" -and
    [string]$closure.source.commit -ceq
        "a956c3ebbd5d08892d19da8912e0357e3b08ebd5" -and
    [bool]$closure.source.clean -and
    [bool]$closure.source.matches_origin_main -and
    [bool]$closure.source.matches_live_remote_main -and
    [bool]$closure.source.full_skip_godot_conformance_passed_before_freeze_commit -and
    [bool]$closure.source.full_skip_godot_conformance_passed_from_clean_pushed_freeze_commit -and
    [int]$closure.source.physical_attempt_count -eq 1
) "C2 closure identity, status, or source boundary changed"
Assert-Exact (
    [string]$closure.preregistration.raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [string]$closure.predecessor.closure_raw_sha256 -ceq
        $expectedC1ClosureRawSha256 -and
    [string]$closure.predecessor.status -ceq [string]$c1Closure.status -and
    -not [bool]$closure.predecessor.same_identity_rerun -and
    -not [bool]$closure.predecessor.result_reinterpreted_or_rethresholded
) "C2 predecessor or preregistration chain changed"

$sourceCommit = [string]$closure.source.commit
& git -C $repoRoot cat-file -e "$sourceCommit^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "The frozen C2 source commit is missing"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "Current HEAD is not descended from C2 source"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit origin/main
Assert-Exact ($LASTEXITCODE -eq 0) "origin/main lost the C2 source commit"
$remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$remoteCommit = ($remoteLine -split "\s+")[0]
& git -C $repoRoot merge-base --is-ancestor $sourceCommit $remoteCommit
Assert-Exact ($LASTEXITCODE -eq 0) "The live remote lost the C2 source commit"

foreach ($artifactProperty in $closure.artifacts.PSObject.Properties) {
    $artifact = $artifactProperty.Value
    Assert-Exact (
        (Test-Path -LiteralPath ([string]$artifact.path) -PathType Leaf) -and
        (Get-Item -LiteralPath ([string]$artifact.path)).Length -eq
            [long]$artifact.bytes -and
        (Get-RawSha256 ([string]$artifact.path)) -ceq
            [string]$artifact.sha256
    ) "A retained C2 artifact changed: $($artifactProperty.Name)"
}
Assert-Exact (
    [string]$closure.artifacts.attempt.sha256 -ceq
        "sha256:da35675b6d95b8f74c7797bd8c8ba5641caac3a3920d05c7ae28e951d3f201d8" -and
    [long]$closure.artifacts.attempt.bytes -eq 1222 -and
    [string]$closure.artifacts.completion.sha256 -ceq
        "sha256:b9b849bed1c6bd283f046bfbb313c4fd92015f0dc440b44e8953440706945730" -and
    [long]$closure.artifacts.completion.bytes -eq 671 -and
    [string]$closure.artifacts.report.sha256 -ceq
        "sha256:f51224e35e34afd8cb53941d49f253d468092bd7e0ea6faba36a6db6b9b98b14" -and
    [long]$closure.artifacts.report.bytes -eq 17972 -and
    [string]$closure.artifacts.stdout.sha256 -ceq
        [string]$closure.artifacts.report.sha256 -and
    [long]$closure.artifacts.stdout.bytes -eq
        [long]$closure.artifacts.report.bytes -and
    [string]$closure.artifacts.stderr.sha256 -ceq
        "sha256:66c607ff4acdbb46e806856dcec62477b3a0e7abea99143a8181b37135d05002" -and
    [long]$closure.artifacts.stderr.bytes -eq 190
) "C2 artifact hashes or byte counts changed"

$attempt = Get-Content -Raw -LiteralPath ([string]$closure.artifacts.attempt.path) |
    ConvertFrom-Json
$completion = Get-Content -Raw -LiteralPath ([string]$closure.artifacts.completion.path) |
    ConvertFrom-Json
$report = Get-Content -Raw -LiteralPath ([string]$closure.artifacts.report.path) |
    ConvertFrom-Json
Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c2_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.status -ceq
        "physical_process_launch_reserved_identity_consumed" -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.live_remote_main_commit -ceq $sourceCommit -and
    [string]$attempt.preregistration_raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [string]$attempt.c1_closure_raw_sha256 -ceq
        $expectedC1ClosureRawSha256 -and
    [bool]$attempt.process_launch_consumes_identity -and
    -not [bool]$attempt.same_identity_rerun_allowed
) "C2 attempt supervision receipt changed"
Assert-Exact (
    [string]$completion.schema_version -ceq
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c2_process_completion_v1" -and
    [string]$completion.campaign_id -ceq $campaignId -and
    [string]$completion.gate_id -ceq $gateId -and
    [string]$completion.status -ceq "physical_process_exited_with_report" -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [int]$completion.process_exit_code -eq 1 -and
    [bool]$completion.physical_process_launched -and
    [bool]$completion.report_retained -and
    [string]$completion.report_raw_sha256 -ceq
        [string]$closure.artifacts.report.sha256 -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.abnormal_attempt_is_not_a_scientific_result -and
    [bool]$closure.attempt_supervision.report_and_stdout_bytes_identical -and
    -not [bool]$closure.attempt_supervision.abnormal_attempt
) "C2 process completion was reclassified or changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c2_report_v1" -and
    -not [bool]$report.ok -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [string]$report.preregistration_raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [string]$report.c1_closure_raw_sha256 -ceq
        $expectedC1ClosureRawSha256 -and
    [string]$report.candidate_id -ceq "BW19V-B" -and
    [string]$report.candidate_composition_digest -ceq
        "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77" -and
    [string]$report.selected_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [string]$report.selected_policy_digest -ceq
        "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
) "C2 physical report identity changed"

$preflight = $report.preflight
Assert-Exact (
    [bool]$preflight.ok -and
    [int]$preflight.complete_declared_horizon_steps -eq 3232 -and
    [bool]$preflight.complete_declared_horizon_passed -and
    [int]$preflight.synthetic_available_plan_count -eq 1920 -and
    [int]$preflight.synthetic_observation_unavailable_plan_count -eq 1312 -and
    [int]$preflight.synthetic_explicit_host_observation_unavailable_plan_count -eq 360 -and
    [int]$preflight.synthetic_observed_planning_unavailable_plan_count -eq 952 -and
    [int]$preflight.synthetic_upstream_infeasible_plan_count -eq 0 -and
    [int]$preflight.synthetic_fail_zero_count -eq 1312 -and
    [int]$preflight.synthetic_partial_support_mapping_count -eq 960 -and
    [int]$preflight.synthetic_influence_output_count -eq 25856 -and
    [int]$preflight.synthetic_explicit_host_unavailable_base_application_count -eq 2880 -and
    [int]$preflight.synthetic_explicit_host_unavailable_exact_zero_stability_output_count -eq 2880 -and
    [bool]$preflight.available_receipt_before_zero_support_segment -and
    [bool]$preflight.available_receipt_after_zero_support_segment -and
    [bool]$preflight.perfect_synthetic_whole_gate_passed -and
    [bool]$preflight.wrong_scale_canary_rejected -and
    [bool]$preflight.composition_count_canary_rejected -and
    [bool]$preflight.motor_model_canary_rejected -and
    [bool]$preflight.missing_nonzero_application_canary_rejected -and
    [bool]$preflight.observation_unavailable_route_canary_rejected -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_insertion_count -eq 0 -and
    [int]$preflight.physics_state_mutation_count -eq 0
) "The physical report lost the complete C2 zero-world gate"

Assert-Exact (
    [int]$report.world_attempt_count -eq 1 -and
    [int]$report.world_build_count -eq 1 -and
    [int]$report.world_reset_count -eq 0 -and
    [int]$report.body_count -eq 9 -and
    [int]$report.joint_count -eq 8 -and
    [int]$report.actuator_count -eq 8 -and
    [int]$report.direct_body_write_count -eq 0 -and
    [int]$report.controller_error_count -eq 0 -and
    [int]$report.safe_no_actuation_count -eq 0 -and
    [int]$report.nonfinite_observation_count -eq 0 -and
    [int]$report.motor_impulse_limit_violation_count -eq 0 -and
    [int]$report.controller_semantic_step_count -eq 2992 -and
    [int]$report.validated_portable_command_count -eq 23936 -and
    [int]$report.native_motor_application_count -eq 23936 -and
    [int]$report.actuator_application_mismatch_count -eq 0 -and
    [bool]$report.initial_four_contact_stance -and
    -not [bool]$report.terminal_four_contact_recovery -and
    [int]$report.torso_ground_contact_step_count -eq 208 -and
    [int]$report.observability.first_torso_ground_contact_semantic_step -eq 117 -and
    -not [bool]$report.schedule.evidence_limits_reached -and
    -not [bool]$report.schedule.cooldown_completed -and
    [bool]$report.schedule.terminal_settle_completed -and
    [int]$report.schedule.contact_gated_start_step -eq 472
) "C2 physical execution or schedule accounting changed"

$expectedGateFailures = @(
    "C6_RAP_BW19V_C2_evidence_limits_not_reached",
    "C6_RAP_BW19V_C2_cooldown_incomplete",
    "C6_RAP_BW19V_C2_terminal_stance",
    "C6_RAP_BW19V_C2_torso_ground_contact",
    "C6_RAP_BW19V_C2_evidence_advance_GATE_FAILED",
    "C6_RAP_BW19V_C2_final_advance_GATE_FAILED",
    "C6_RAP_BW19V_C2_lateral_drift_GATE_FAILED",
    "C6_RAP_BW19V_C2_tilt_GATE_FAILED",
    "C6_RAP_BW19V_C2_CONTACT_CYCLES_rear_left",
    "C6_RAP_BW19V_C2_FOOT_RELOCATION_rear_left",
    "C6_RAP_BW19V_C2_AIRBORNE_DWELL_rear_left",
    "C6_RAP_BW19V_C2_CONTACT_CYCLES_rear_right",
    "C6_RAP_BW19V_C2_FOOT_RELOCATION_rear_right",
    "C6_RAP_BW19V_C2_AIRBORNE_DWELL_rear_right"
)
Assert-Exact (
    @($report.gate_failures).Count -eq 14 -and
    (Get-CompactJson @($report.gate_failures)) -ceq
        (Get-CompactJson $expectedGateFailures) -and
    (Get-CompactJson @($closure.physical_result.gate_failures)) -ceq
        (Get-CompactJson $expectedGateFailures)
) "C2's exact 14 walking failures changed"

$composition = $report.composition
Assert-Exact (
    [int]$composition.attempt_count -eq 2992 -and
    [int]$composition.composition_error_count -eq 0 -and
    @($composition.composition_error_codes.PSObject.Properties).Count -eq 0 -and
    $null -eq $composition.first_composition_error_semantic_step -and
    $null -eq $composition.first_composition_error_code -and
    [int]$composition.scheduled_plan_receipt_count -eq 2992 -and
    [int]$composition.stability_influence_receipt_count -eq 2992 -and
    [int]$composition.influence_output_count -eq 23936 -and
    [int]$composition.mapping_receipt_count -eq 1748 -and
    [int]$composition.available_plan_count -eq 1748 -and
    [int]$composition.observation_unavailable_plan_count -eq 259 -and
    [int]$composition.explicit_host_observation_unavailable_plan_count -eq 32 -and
    [int]$composition.observed_planning_unavailable_plan_count -eq 227 -and
    [int]$composition.upstream_infeasible_plan_count -eq 985 -and
    [int]$composition.fail_zero_receipt_count -eq 1244 -and
    [int]$composition.observation_unavailable_base_command_application_count -eq 2072 -and
    [int]$composition.observation_unavailable_base_command_mismatch_count -eq 0 -and
    [int]$composition.observation_unavailable_exact_zero_stability_output_count -eq 2072 -and
    [int]$composition.observation_unavailable_stability_zero_mismatch_count -eq 0 -and
    [int]$composition.observation_unavailable_reason_mismatch_count -eq 0 -and
    [int]$composition.nonzero_raw_request_count -eq 10586 -and
    [int]$composition.nonzero_scaled_request_count -eq 10586 -and
    [int]$composition.nonzero_applied_contribution_count -eq 10586 -and
    [int]$composition.nonzero_effective_host_application_count -eq 6374 -and
    [int]$composition.host_speed_saturation_count -eq 4230 -and
    [int]$composition.inactive_contact_exact_zero_count -eq 3398 -and
    [int]$composition.global_scale_mismatch_count -eq 0 -and
    [double]$composition.response_reconstruction_maximum_error_nm -eq
        8.881784197001252e-16 -and
    [int]$composition.host_response_conversion_failure_count -eq 0 -and
    [int]$composition.inactive_contact_zero_mismatch_count -eq 0 -and
    [int]$composition.motor_model_readback_mismatch_count -eq 0 -and
    [string]$composition.first_composition_receipt_sha256 -ceq
        "sha256:ead451e2dffc35bd20d859a6e868a59bf00672603ca57980c3ae5e1ad5d4c863" -and
    [string]$composition.last_composition_receipt_sha256 -ceq
        "sha256:11cdc7e3fa9a85c4edceb14f97763192dadcc198068a6ebb9bb533421c42f24a"
) "C2 corrected composition accounting changed"
Assert-Exact (
    [int]$composition.available_plan_count +
        [int]$composition.observation_unavailable_plan_count +
        [int]$composition.upstream_infeasible_plan_count -eq
        [int]$composition.attempt_count -and
    [int]$composition.explicit_host_observation_unavailable_plan_count +
        [int]$composition.observed_planning_unavailable_plan_count -eq
        [int]$composition.observation_unavailable_plan_count -and
    [int]$composition.observation_unavailable_plan_count +
        [int]$composition.upstream_infeasible_plan_count -eq
        [int]$composition.fail_zero_receipt_count -and
    [int]$composition.observation_unavailable_base_command_application_count -eq
        [int]$composition.observation_unavailable_plan_count * 8 -and
    [int]$composition.observation_unavailable_exact_zero_stability_output_count -eq
        [int]$composition.observation_unavailable_plan_count * 8
) "C2 composition partitions or unavailable-base accounting do not close"

$thresholds = $preregistration.walking_and_integrity_gate
$metrics = $report.metrics
Assert-Exact (
    $null -eq $metrics.evidence_forward_displacement_m -and
    [double]$metrics.final_forward_displacement_m -eq -0.5488250851631165 -and
    [double]$metrics.final_lateral_displacement_m -eq -0.11961005628108978 -and
    [double]$metrics.final_yaw_drift_rad -eq 0.19562848678199035 -and
    [double]$metrics.maximum_tilt_rad -eq 1.604911208152771 -and
    [double]$metrics.minimum_torso_height_m -eq 0.25265759229660034 -and
    [double]$metrics.maximum_anchor_error_m -eq 0.0002086837193928659 -and
    [double]$metrics.maximum_hinge_axis_error_rad -eq 0.00402647303417325 -and
    [math]::Abs([double]$metrics.final_lateral_displacement_m) -gt
        [double]$thresholds.maximum_absolute_final_lateral_displacement_m -and
    [double]$metrics.maximum_tilt_rad -gt
        [double]$thresholds.maximum_tilt_rad -and
    [math]::Abs([double]$metrics.final_yaw_drift_rad) -le
        [double]$thresholds.maximum_absolute_final_yaw_drift_rad -and
    [double]$metrics.minimum_torso_height_m -ge
        [double]$thresholds.minimum_torso_height_m -and
    [double]$metrics.maximum_anchor_error_m -le
        [double]$thresholds.maximum_anchor_error_m -and
    [double]$metrics.maximum_hinge_axis_error_rad -le
        [double]$thresholds.maximum_hinge_axis_error_rad
) "C2 physical metrics or their pass/fail interpretation changed"
foreach ($front in @("front_left", "front_right")) {
    $limb = $report.limb_evidence.$front
    Assert-Exact (
        [int]$limb.contact_cycles -ge
            [int]$thresholds.minimum_contact_cycles_per_limb -and
        [int]$limb.maximum_airborne_dwell_steps -ge
            [int]$thresholds.minimum_airborne_dwell_steps_per_limb -and
        [double]$limb.maximum_foot_relocation_m -ge
            [double]$thresholds.minimum_foot_relocation_m_per_limb
    ) "A C2 front-limb accepted evidence gate changed: $front"
}
foreach ($rear in @("rear_left", "rear_right")) {
    $limb = $report.limb_evidence.$rear
    Assert-Exact (
        [int]$limb.contact_cycles -eq 0 -and
        [int]$limb.maximum_airborne_dwell_steps -eq 0 -and
        [double]$limb.maximum_foot_relocation_m -eq 0.0
    ) "A C2 rear-limb negative evidence gate changed: $rear"
}

Assert-Exact (
    [bool]$closure.accepted_narrow_evidence.corrected_observation_unavailable_route_executed -and
    [bool]$closure.accepted_narrow_evidence.complete_plan_influence_and_final_application_accounting -and
    [bool]$closure.accepted_narrow_evidence.final_yaw_gate_passed -and
    [bool]$closure.accepted_narrow_evidence.minimum_torso_height_gate_passed -and
    [bool]$closure.accepted_narrow_evidence.anchor_and_hinge_axis_gates_passed -and
    [bool]$closure.accepted_narrow_evidence.front_limb_evidence_gates_passed -and
    -not [bool]$closure.accepted_narrow_evidence.technical_commissioning_accepted -and
    -not [bool]$closure.accepted_narrow_evidence.walking_acceptance -and
    [bool]$closure.mechanism_interpretation.c1_availability_routing_hypothesis_confirmed_as_real_integration_defect -and
    [bool]$closure.mechanism_interpretation.c1_availability_routing_correction_sufficient_for_complete_composition_accounting -and
    -not [bool]$closure.mechanism_interpretation.c1_availability_routing_correction_sufficient_for_physical_walking_gate -and
    -not [bool]$closure.mechanism_interpretation.physical_failure_cause_identified -and
    -not [bool]$closure.mechanism_interpretation.base_controller_failure_identified -and
    -not [bool]$closure.mechanism_interpretation.stability_residual_failure_identified -and
    -not [bool]$closure.mechanism_interpretation.base_residual_interaction_failure_identified -and
    [bool]$closure.mechanism_interpretation.descriptive_c1_comparison_is_not_formal_inference
) "C2's accepted evidence or causal restraint changed"
Assert-Exact (
    [bool]$closure.disposition.complete_negative_report_retained -and
    [bool]$closure.disposition.integration_correction_accepted -and
    -not [bool]$closure.disposition.technical_commissioning_accepted -and
    -not [bool]$closure.disposition.rapier_selected_policy_physical_c6 -and
    -not [bool]$closure.disposition.same_identity_rerun_allowed -and
    -not [bool]$closure.disposition.threshold_change_allowed -and
    -not [bool]$closure.disposition.report_rewrite_allowed -and
    -not [bool]$closure.disposition.posthoc_reclassification_allowed -and
    [bool]$closure.disposition.scientifically_distinct_successor_allowed -and
    [bool]$closure.disposition.successor_must_use_new_campaign_source_and_preregistration_identity -and
    [bool]$closure.disposition.recommended_early_horizon_must_cover_first_472_semantic_steps -and
    [bool]$closure.disposition.recommended_paired_base_only_and_full_composition_arms -and
    [bool]$closure.disposition.recommended_development_screen_has_no_locomotion_acceptance_authority -and
    [bool]$closure.disposition.independent_bw19v_b_cold_friction_track_remains_open
) "C2 negative disposition changed"
Assert-Exact (
    [bool]$closure.claim_boundary.rapier_bw19v_b_composition_integration_contract_passed -and
    -not [bool]$closure.claim_boundary.single_body_bw19v_b_rapier_technical_commissioning -and
    -not [bool]$closure.claim_boundary.rapier_selected_policy_technical_integration -and
    -not [bool]$closure.claim_boundary.rapier_selected_policy_physical_c6 -and
    -not [bool]$closure.claim_boundary.walking_acceptance -and
    -not [bool]$closure.claim_boundary.independent_validation -and
    -not [bool]$closure.claim_boundary.arbitrary_quadruped_coverage -and
    -not [bool]$closure.claim_boundary.continuous_full_volume_coverage -and
    -not [bool]$closure.claim_boundary.material_robustness -and
    -not [bool]$closure.claim_boundary.cross_engine_c6 -and
    -not [bool]$closure.claim_boundary.release_authorized -and
    -not [bool]$closure.claim_boundary.physical_acceptance_authority -and
    -not [bool]$closure.claim_boundary.completed_engine_neutral_sdk -and
    -not [bool]$report.rapier_selected_policy_physical_c6 -and
    -not [bool]$report.rapier_bw19v_single_body_technical_commissioning_passed
) "C2 closure or report inflated its claims"

$frozenCompositionSource = (& git -C $repoRoot show (
    "$sourceCommit`:sdk/adapters/rapier/src/bw19v_composition.rs"
)) -join "`n"
$frozenCommissioningSource = (& git -C $repoRoot show (
    "$sourceCommit`:sdk/adapters/rapier/src/bw19v_commissioning.rs"
)) -join "`n"
$frozenPreregistration = (& git -C $repoRoot show (
    "$sourceCommit`:sdk/rapier_c6_bw19v_selected_policy_commissioning_c2_preregistration.json"
)) -join "`n"
Assert-Exact (
    $LASTEXITCODE -eq 0
) "Unable to read the frozen C2 experiment source"
foreach ($binding in @(
    'any(|contact| contact.bears_support == Some(true))',
    'BW19V_NO_QUALIFIED_SUPPORT_CONTACT_REASON',
    'observation_unavailable_reason'
)) {
    Assert-TextContains `
        -Text $frozenCompositionSource `
        -Needle $binding `
        -Message "Frozen C2 availability source lost binding: $binding"
}
foreach ($binding in @(
    'first_composition_error_semantic_step',
    'explicit_host_observation_unavailable_plan_count',
    'observation_unavailable_base_command_mismatch_count',
    'observation_unavailable_stability_zero_mismatch_count',
    'C2_ZERO_SUPPORT_START_STEP: u64 = 1440',
    'C2_ZERO_SUPPORT_END_STEP_EXCLUSIVE: u64 = 1800'
)) {
    Assert-TextContains `
        -Text $frozenCommissioningSource `
        -Needle $binding `
        -Message "Frozen C2 receipt/preflight source lost binding: $binding"
}
$temporaryPreregistration = Join-Path (
    [System.IO.Path]::GetTempPath()
) ("sporespore-c2-prereg-" + [guid]::NewGuid().ToString("N") + ".json")
try {
    [System.IO.File]::WriteAllText(
        $temporaryPreregistration,
        $frozenPreregistration + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    Assert-Exact (
        (Get-RawSha256 $temporaryPreregistration) -ceq
            $expectedPreregistrationRawSha256
    ) "The preregistration at the frozen C2 source commit changed"
} finally {
    Remove-Item -LiteralPath $temporaryPreregistration -Force -ErrorAction SilentlyContinue
}

$attemptMatches = @()
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent ([string]$closure.evidence_root))
)
foreach ($candidate in @(
    Get-ChildItem `
        -LiteralPath $evidenceRoot `
        -Recurse `
        -File `
        -Filter "attempt.json" `
        -ErrorAction Stop
)) {
    try {
        $candidateReceipt = Get-Content -Raw -LiteralPath $candidate.FullName |
            ConvertFrom-Json
        if ([string]$candidateReceipt.campaign_id -ceq $campaignId) {
            $attemptMatches += $candidate.FullName
        }
    } catch {
        continue
    }
}
Assert-Exact (
    $attemptMatches.Count -eq 1 -and
    [System.IO.Path]::GetFullPath($attemptMatches[0]) -ceq
        [System.IO.Path]::GetFullPath([string]$closure.artifacts.attempt.path)
) "C2 has more than its one permitted physical attempt"

$previousErrorPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$runnerOutput = (& pwsh -NoLogo -NoProfile -File $runnerPath 2>&1) |
    Out-String
$runnerExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorPreference
Assert-Exact (
    $runnerExitCode -ne 0 -and
    $runnerOutput.Contains("$gateId is already closed and may not open another world")
) "The C2 runner no longer refuses a same-identity physical rerun"
$global:LASTEXITCODE = 0

Write-Output (
    "C6_RAP_BW19V_C2_CLOSURE_PASS worlds=1 receipts=2992 " +
    "composition_errors=0 applications=23936 explicit_unavailable=32 " +
    "torso_contact_first=117 gate_failures=14 technical_commissioning=False " +
    "same_identity_rerun=False"
)
