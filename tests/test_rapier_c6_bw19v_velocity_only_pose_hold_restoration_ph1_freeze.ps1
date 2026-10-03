#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "C6-RAPIER-BW19V-VELOCITY-ONLY-POSE-HOLD-RESTORATION-PH1"
$gateId = "C6-RAP-BW19V-V4-PH1"
$implementationParentCommit = "d50199e2d43a3de7b73c4a0351685abc119f4c02"
$preregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_preregistration.json"
$evaluatorPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bw19v_velocity_only_pose_hold_restoration_ph1.rs"
$binaryPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bin\bw19v_velocity_only_pose_hold_restoration_ph1.rs"
$runnerPath = Join-Path (
    $sdkRoot
) "run_rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1.ps1"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json"
$expectedPreregistrationSha256 = (
    "dd0c7b741fa785d517e88a13921703880c0de7f1e9d0ae28755a307661b016a4"
)
$expectedEvaluatorSha256 = (
    "f194436d576dbc67217d9dac26615a4d866a48e26eefa27c5aa31bf93a8381f9"
)
$expectedBinarySha256 = (
    "1e44dec36ee88de96072dff39c1280e124d1b181528b2609474b25e7372a690c"
)
$expectedRunnerSha256 = (
    "67f746ef4b272a50c97c291dc7caaaf946b323e52d9277d64aeda19524d7aeb4"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

foreach ($entry in @(
    @($preregistrationPath, $expectedPreregistrationSha256),
    @($evaluatorPath, $expectedEvaluatorSha256),
    @($binaryPath, $expectedBinarySha256),
    @($runnerPath, $expectedRunnerSha256)
)) {
    Assert-Exact (
        (Test-Path -LiteralPath $entry[0] -PathType Leaf) -and
        (Get-RawSha256 -Path $entry[0]) -ceq $entry[1]
    ) "PH1 frozen artifact missing or changed: $($entry[0])"
}
Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "PH1 already has a closure and is no longer a prospective freeze"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json
Assert-Exact (
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_bw19v_v4_ph1_physics_world" -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [bool]$preregistration.study_class.finite_decision -and
    -not [bool]$preregistration.study_class.development_screen -and
    -not [bool]$preregistration.study_class.population_inference -and
    -not [bool]$preregistration.study_class.superiority_study -and
    -not [bool]$preregistration.study_class.noninferiority_or_equivalence_study -and
    [int]$preregistration.study_class.world_count -eq 1 -and
    [int]$preregistration.physical_horizon.total_controller_semantic_steps -eq 3172 -and
    [int]$preregistration.physical_horizon.clocked_steps -eq 472 -and
    [int]$preregistration.physical_horizon.evidence_deadline_step_exclusive -eq 2632 -and
    [int]$preregistration.physical_horizon.terminal_restoration_phase.frozen_evidence_limit_gait_step -eq 1912 -and
    [int]$preregistration.physical_horizon.terminal_restoration_phase.frozen_evidence_endpoint_global_cycle_step -eq 112 -and
    [bool]$preregistration.physical_horizon.terminal_restoration_phase.gait_memory_frozen_at_evidence_limit -and
    [string]$preregistration.physical_horizon.terminal_restoration_phase.restoration_policy_id -ceq
        "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_v1" -and
    [string]$preregistration.physical_horizon.terminal_restoration_phase.contacting_limb_target_joint_velocity_mode -ceq
        "captured_pose_proportional_derivative_velocity_v1" -and
    [double]$preregistration.physical_horizon.terminal_restoration_phase.pose_position_gain_per_s -eq 8.0 -and
    [double]$preregistration.physical_horizon.terminal_restoration_phase.pose_rate_damping -eq 0.65 -and
    [double]$preregistration.physical_horizon.terminal_restoration_phase.maximum_absolute_pose_hold_joint_velocity_rad_s -eq 0.35 -and
    [string]$preregistration.physical_horizon.terminal_restoration_phase.heading_correction_mode -ceq
        "registered_portable_yaw_only_hip_target_delta_from_activation_v1" -and
    -not [bool]$preregistration.physical_horizon.terminal_restoration_phase.heading_gain_or_filter_changed -and
    [double]$preregistration.physical_horizon.terminal_restoration_phase.missing_limb_desired_foot_velocity_world_m_s[1] -eq -0.02 -and
    [double]$preregistration.physical_horizon.terminal_restoration_phase.damped_least_squares_lambda_m -eq 0.04 -and
    [double]$preregistration.physical_horizon.terminal_restoration_phase.maximum_absolute_search_joint_velocity_rad_s -eq 0.35 -and
    [int]$preregistration.physical_horizon.terminal_restoration_phase.maximum_four_contact_acquisition_steps_after_evidence_completion -eq 180 -and
    [int]$preregistration.physical_horizon.terminal_restoration_phase.terminal_acquisition_deadline_step_exclusive -eq 2812 -and
    [int]$preregistration.physical_horizon.terminal_restoration_phase.required_consecutive_all_four_contact_steps -eq 360 -and
    [bool]$preregistration.physical_horizon.terminal_restoration_phase.hold_counter_resets_on_any_contact_loss -and
    [int]$preregistration.physical_horizon.required_post_terminal_steps -eq 360 -and
    [int]$preregistration.physical_horizon.terminal_zero_target_settle_steps -eq 0 -and
    [bool]$preregistration.physical_horizon.fixed_horizon_no_outcome_dependent_stop -and
    [string]$preregistration.walking_thresholds.provenance -clike
        "All walking performance thresholds are inherited byte-for-value*" -and
    [double]$preregistration.walking_thresholds.minimum_evidence_forward_displacement_m -eq
        0.0401640625 -and
    [double]$preregistration.walking_thresholds.minimum_final_forward_displacement_m -eq
        0.030123046875 -and
    [double]$preregistration.walking_thresholds.maximum_absolute_final_lateral_displacement_m -eq
        0.10031893004115228 -and
    [double]$preregistration.walking_thresholds.maximum_absolute_final_yaw_drift_rad -eq 0.45 -and
    [double]$preregistration.walking_thresholds.maximum_tilt_rad -eq 0.6 -and
    [double]$preregistration.walking_thresholds.minimum_torso_height_m -eq
        0.2499708652072946 -and
    [int]$preregistration.walking_thresholds.minimum_contact_cycles_per_limb -eq 2 -and
    [int]$preregistration.walking_thresholds.minimum_airborne_dwell_steps_per_limb -eq 3 -and
    [double]$preregistration.walking_thresholds.minimum_foot_relocation_m_per_limb -eq
        0.01194880859375 -and
    [int]$preregistration.preflight_contract.negative_controls.Count -eq 33 -and
    [bool]$preregistration.claims_if_passed.exact_s169_rapier_v4_pose_hold_restoration_technical_commissioning -and
    -not [bool]$preregistration.claims_if_passed.physical_acceptance_authority
) "PH1 study class, fixed horizon, or inherited walking threshold changed"

foreach ($authorityName in @(
    "live_integration",
    "active_configuration_v2",
    "canonical_velocity_profile",
    "velocity_only_host_characterization",
    "pre_v4_long_horizon_predecessor",
    "early_v4_predecessor",
    "terminal_stance_predecessor",
    "immediate_restoration_predecessor"
)) {
    $authority = $preregistration.bound_authorities.$authorityName
    $authorityPath = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$authority.path))
    )
    Assert-Exact (
        (Test-Path -LiteralPath $authorityPath -PathType Leaf) -and
        (Get-RawSha256 -Path $authorityPath) -ceq [string]$authority.raw_sha256
    ) "PH1 pinned authority changed: $authorityPath"
}

$evaluatorSource = Get-Content -Raw -LiteralPath $evaluatorPath
$runnerSource = Get-Content -Raw -LiteralPath $runnerPath
$libSource = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "adapters\rapier\src\lib.rs"
)
foreach ($needle in @(
    "VELOCITY_ONLY_LIVE_PROFILE_ID",
    "positive_saturated_residual_case_passed",
    "production_scheduler_order_memory_witness_passed",
    "memory_has_exact_identity_set",
    "CONTACT_RESTORATION_POLICY_ID",
    "contact_restoration_composition",
    "PoseHoldRestorationMemory",
    "portable_heading_target_delta",
    "POSE_HOLD_POSITION_GAIN_PER_S",
    "POSE_HOLD_RATE_DAMPING",
    "restoration_receipt_is_reconstructible",
    "ordered_pre_step_joint_position_velocity_observations",
    "REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS",
    "nonzero_bounded_residual_count",
    "nonzero_effective_host_residual_count",
    "PhaseProgressionMode::Clocked",
    "PhaseProgressionMode::ContactGated",
    "build_bw19v_velocity_only_v4_robot",
    "compose_bw19v_step_v4",
    "apply_bw19v_velocity_only_v4_actuation",
    "full_gate_failures"
)) {
    Assert-Exact (
        $evaluatorSource.Contains($needle, [StringComparison]::Ordinal)
    ) "PH1 evaluator lost required production or integrity surface: $needle"
}
foreach ($needle in @(
    '[bool]$PreflightOnly -xor [bool]$RunPhysical',
    'status --porcelain=v1 --untracked-files=all',
    'ls-remote origin refs/heads/main',
    'physical_process_launch_reserved_identity_consumed',
    'same_identity_rerun_allowed = $false',
    'Enter-SporeSporeLocomotionOperationLock -Role physical',
    'Test-SporeSporeFullConformanceAttestationFile',
    'sporespore_full_godot_conformance_attestation_v2',
    '-WindowStyle Hidden',
    'SporeSpore_Evidence'
)) {
    Assert-Exact (
        $runnerSource.Contains($needle, [StringComparison]::Ordinal)
    ) "PH1 runner lost fail-closed launch surface: $needle"
}
foreach ($needle in @(
    "evaluate_bw19v_velocity_only_pose_hold_restoration_ph1_report",
    "run_bw19v_velocity_only_pose_hold_restoration_ph1",
    "run_bw19v_velocity_only_pose_hold_restoration_ph1_preflight"
)) {
    Assert-Exact (
        $libSource.Contains($needle, [StringComparison]::Ordinal)
    ) "PH1 library export missing: $needle"
}

$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$priorAttempts = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorAttempts = @(
        Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File -Filter "attempt.json" |
        Where-Object {
            try {
                $attempt = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$attempt.campaign_id -ceq $campaignId
            } catch {
                $false
            }
        }
    )
}
Assert-Exact (
    $priorAttempts.Count -eq 0
) "PH1 already has a retained physical attempt"

& $runnerPath -PreflightOnly
Assert-Exact (
    $LASTEXITCODE -eq 0
) "PH1 complete zero-world supervisor preflight failed"

Write-Host (
    "C6_RAP_V4_PH1_FREEZE_PASS class=finite_decision worlds=0 " +
    "trace_steps=3172 commands_per_layer=25376 canaries=33 " +
    "identity_order=True restorer=pose_hold_heading_plus_dls_vertical " +
    "gain=8.0 damping=0.65 search=0.02 lambda=0.04 max_qdot=0.35 " +
    "physical_authority=False"
)
