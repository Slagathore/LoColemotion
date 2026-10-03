#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$preregistrationPath = Join-Path $sdkRoot (
    "mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv4_preregistration.json"
)
$implementationPath = Join-Path $sdkRoot (
    "adapters\mujoco\sporespore_mujoco_adapter\selected_policy_pose_hold_restoration_mv4.py"
)
$bridgePath = Join-Path $sdkRoot (
    "adapters\mujoco\sporespore_mujoco_adapter\selected_policy_development.py"
)
$runnerPath = Join-Path $sdkRoot (
    "run_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv4.ps1"
)
$expectedParent = "9dda4b3a632f0c2e5e4b369a7522718b8cff572b"
$campaignId = "C6-MUJOCO-BW19V-SELECTED-POLICY-POSE-HOLD-RESTORATION-MV4"
$gateId = "C6-MJC-BW19V-MV4"
$evidenceRoot = [IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

$expectedFiles = [ordered]@{
    "sdk/mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv4_preregistration.json" = "2214745eea87c08df4b64f4d091eccc66a2aa5fad10f20d047ae5b98b38bbcb7"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_pose_hold_restoration_mv4.py" = "2483424a03966f57a1b720adee0766e14fd00e5ec2bd81e80a1072b0ea8a1a7a"
    "sdk/run_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv4.ps1" = "c57bf7c3d7136f6f08d419da1c8d1f248b8299a27ee52d70cfd05603b5538397"
    "sdk/mujoco_c6_bw19v_selected_policy_walking_mv3_closure.json" = "96e9947628794b9ffdcb1d42f5cfc42b44d89f5f53f7c04007dedf694c8fbf8c"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_walking_mv3.py" = "a01cc11c5cb89d90b006b2bf05cee66d119722f0bbc7e1749c22671c8be24078"
    "sdk/rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json" = "e2fd42545d59908db69f9fe34a18453afafe4273a02618be0b531f6443e040db"
    "sdk/rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_preregistration.json" = "dd0c7b741fa785d517e88a13921703880c0de7f1e9d0ae28755a307661b016a4"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py" = "306669481601cc91c8146e84a202a57228672e23c3f9daa0c531d2eb9d077e46"
    "sdk/mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.json" = "fbb8441fb8a3907c56155db777de00ce8b6e2f293ef67e77a2a30d2eeeb0f34f"
    "sdk/rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_preregistration.json" = "a5e88d5e0f69772c7dec67cc0d8bd83aa903ab2fe642a301fbf8ed3f09b47d0b"
    "sdk/mujoco_c6_bw19v_selected_policy_walking_mv2_closure.json" = "0ef035bf76ebfc2c2ded74912cd5219f51304ae13086407324a5fbc491fec51c"
    "sdk/balanced_wave_bw19v_closure_manifest.json" = "ea8df6a574e1b9be1050afa8ed57982a102982ada0f0d5babccf3c937c7067f7"
    "sdk/core/src/canonical_actuation.rs" = "e2d7e27edaf7caa218d95a5ed7966f5c6d317ff8c5990c5cd0e2876e1d485d05"
    "sdk/python/sporespore_locomotion.py" = "53e9be5f192f1424bd2d6c22aeecb563b8d7ed0ae3931901c2dcd576ee1160f7"
    "sdk/adapters/mujoco/requirements-lock.txt" = "38e97a013ec5e7c5bd88cd4dc1c2c54dd151936aa7f24c1f87abac19853b77b9"
}
foreach ($entry in $expectedFiles.GetEnumerator()) {
    $path = [IO.Path]::GetFullPath((Join-Path $repoRoot ([string]$entry.Key)))
    $prefix = $repoRoot.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    Assert-Exact (
        $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 -Path $path) -ceq [string]$entry.Value
    ) "$gateId frozen source changed: $($entry.Key)"
}

$declaration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$declaration.campaign_id -ceq $campaignId -and
    [string]$declaration.gate_id -ceq $gateId -and
    [string]$declaration.status -ceq
        "frozen_before_first_c6_mjc_bw19v_mv4_physics_world" -and
    [string]$declaration.implementation_parent_commit -ceq $expectedParent -and
    [string]$declaration.study_class.classification -ceq
        "outcome_exposed_single_body_finite_technical_commissioning_decision" -and
    [bool]$declaration.study_class.finite_decision -and
    -not [bool]$declaration.study_class.population_inference -and
    [bool]$declaration.outcome_exposure_disclosure.mv3_complete_physical_outcome_observed -and
    [bool]$declaration.outcome_exposure_disclosure.mv3_forward_locomotion_observed -and
    [bool]$declaration.outcome_exposure_disclosure.mv3_terminal_front_left_contact_failure_observed -and
    [bool]$declaration.outcome_exposure_disclosure.restoration_policy_and_numeric_parameters_predate_mv3_outcome -and
    -not [bool]$declaration.outcome_exposure_disclosure.mujoco_specific_parameter_tuning_from_mv3_outcome -and
    [bool]$declaration.successor_distinction.predecessor_valid_negative_preserved -and
    [bool]$declaration.successor_distinction.predecessor_same_identity_rerun_forbidden -and
    [bool]$declaration.successor_distinction.physical_hypothesis_changed -and
    -not [bool]$declaration.successor_distinction.instrumentation_only_rerun -and
    [int]$declaration.physical_horizon.expected_world_count -eq 1 -and
    [int]$declaration.physical_horizon.total_controller_semantic_steps -eq 2992 -and
    [int]$declaration.physical_horizon.clocked_steps -eq 472 -and
    [int]$declaration.physical_horizon.evidence_gait_steps_per_limb -eq 1440 -and
    [int]$declaration.physical_horizon.evidence_deadline_step_exclusive -eq 2632 -and
    [int]$declaration.physical_horizon.maximum_four_contact_acquisition_steps_after_evidence_completion -eq 180 -and
    [int]$declaration.physical_horizon.required_consecutive_all_four_contact_steps -eq 360 -and
    [int]$declaration.physical_horizon.expected_commands_per_layer -eq 23936 -and
    [int]$declaration.preflight_contract.negative_control_count -eq 31 -and
    [int]$declaration.preflight_contract.synthetic_report_negative_control_count -eq 17 -and
    [int]$declaration.preflight_contract.real_dynamic_library_negative_control_count -eq 2 -and
    [int]$declaration.preflight_contract.compiled_morphology_report_assembly_negative_control_count -eq 2 -and
    [int]$declaration.preflight_contract.real_controller_trace_projection_negative_control_count -eq 5 -and
    [int]$declaration.preflight_contract.engine_neutral_terminal_restoration_negative_control_count -eq 5 -and
    [bool]$declaration.preflight_contract.missing_limb_dls_solution_independently_recomputed -and
    [bool]$declaration.preflight_contract.portable_heading_delta_independently_recomputed -and
    [bool]$declaration.preflight_contract.contacting_limb_pose_hold_independently_recomputed -and
    [bool]$declaration.preflight_contract.terminal_pose_memory_capture_clear_and_recontact_transitions_replayed -and
    [bool]$declaration.preflight_contract.terminal_gait_memory_frozen_at_evidence_limit -and
    [bool]$declaration.pre_freeze_zero_world_qualification.completed -and
    [bool]$declaration.pre_freeze_zero_world_qualification.all_31_negative_controls_rejected -and
    [int]$declaration.pre_freeze_zero_world_qualification.world_build_count -eq 0 -and
    -not [bool]$declaration.pre_freeze_zero_world_qualification.locomotion_outcome_exposed
) "$gateId declaration identity, exposure, finite horizon, or qualification changed"

$restoration = $declaration.terminal_restoration_policy
Assert-Exact (
    [string]$restoration.policy_id -ceq
        "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_v1" -and
    [double]$restoration.pose_position_gain_per_s -eq 8.0 -and
    [double]$restoration.pose_rate_damping -eq 0.65 -and
    [double]$restoration.maximum_absolute_pose_hold_joint_velocity_rad_s -eq 0.35 -and
    [string]$restoration.heading_correction_mode -ceq
        "registered_portable_yaw_only_hip_target_delta_from_activation_v1" -and
    [double]$restoration.registered_maximum_absolute_steering_fraction -eq 0.4 -and
    [double]$restoration.missing_limb_desired_foot_velocity_world_m_s[1] -eq -0.02 -and
    [double]$restoration.damped_least_squares_lambda_m -eq 0.04 -and
    [double]$restoration.maximum_absolute_search_joint_velocity_rad_s -eq 0.35 -and
    [bool]$restoration.native_position_target_forbidden -and
    -not [bool]$restoration.outcome_dependent_parameter_selection
) "$gateId terminal restoration law changed"

$thresholds = $declaration.walking_thresholds
Assert-Exact (
    [double]$thresholds.minimum_evidence_forward_displacement_m -eq 0.0401640625 -and
    [double]$thresholds.minimum_final_forward_displacement_m -eq 0.030123046875 -and
    [double]$thresholds.maximum_absolute_final_lateral_displacement_m -eq 0.10031893004115228 -and
    [double]$thresholds.maximum_absolute_final_yaw_drift_rad -eq 0.45 -and
    [double]$thresholds.maximum_tilt_rad -eq 0.6 -and
    [double]$thresholds.minimum_torso_height_m -eq 0.2499708652072946 -and
    [int]$thresholds.minimum_contact_cycles_per_limb -eq 2 -and
    [int]$thresholds.minimum_airborne_dwell_steps_per_limb -eq 3 -and
    [double]$thresholds.minimum_foot_relocation_m_per_limb -eq 0.01194880859375 -and
    [bool]$thresholds.terminal_four_contact_stance -and
    [bool]$thresholds.all_four_contacts_acquired_within_180_steps_of_evidence_completion -and
    [bool]$thresholds.required_360_consecutive_all_four_contact_steps_completed
) "$gateId inherited walking or terminal thresholds changed"

foreach ($claim in @(
    "independent_validation",
    "population_inference",
    "mujoco_release_selected_policy_physical_c6",
    "cross_engine_selected_policy_equivalence",
    "arbitrary_quadruped_coverage",
    "continuous_morphology_coverage",
    "friction_material_or_terrain_robustness",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_or_latency_robustness",
    "release_authorized",
    "completed_engine_neutral_sdk",
    "physical_acceptance_authority"
)) {
    Assert-Exact (-not [bool]$declaration.claims_if_passed[$claim]) (
        "$gateId declaration inflated claim: $claim"
    )
}

$mv3Closure = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "mujoco_c6_bw19v_selected_policy_walking_mv3_closure.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$ph1Closure = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$mv3Closure.status -ceq
        "closed_consumed_complete_valid_negative_combined_walking_and_integrity_contract" -and
    [bool]$mv3Closure.frozen_primary_result.scientific_negative_for_declared_combined_contract -and
    [string]$ph1Closure.status -ceq
        "closed_complete_valid_positive_exact_s169_pose_hold_restoration_and_finite_walking_contract"
) "$gateId predecessor closure semantics changed"

# Structural audit: the unchanged walking path remains self-actuated under
# gravity; preflight runs before any physical model; the restoration output is
# produced through independently recomputed pose/DLS receipts and the existing
# canonical host mapper.
$bridgeText = Get-Content -Raw -LiteralPath $bridgePath
$implementationText = Get-Content -Raw -LiteralPath $implementationPath
$canaryStart = $implementationText.IndexOf(
    "def _zero_world_terminal_restoration_canary()",
    [StringComparison]::Ordinal
)
$canaryEnd = $implementationText.IndexOf(
    "def _synthetic_terminal_receipt(",
    [StringComparison]::Ordinal
)
$campaignStart = $implementationText.IndexOf(
    "def run_campaign(source_commit: str)",
    [StringComparison]::Ordinal
)
$campaignPreflight = $implementationText.IndexOf(
    "preflight = run_preflight()",
    $campaignStart,
    [StringComparison]::Ordinal
)
$campaignModel = $implementationText.IndexOf(
    "robot = bridge.MujocoBw19vRobot(core, PROFILE_ID)",
    $campaignStart,
    [StringComparison]::Ordinal
)
$canaryText = if ($canaryStart -ge 0 -and $canaryEnd -gt $canaryStart) {
    $implementationText.Substring($canaryStart, $canaryEnd - $canaryStart)
} else { "" }
Assert-Exact (
    $bridgeText.Contains('ET.SubElement(element, "freejoint", {"name": "torso_free"})') -and
    $bridgeText.Contains('"gravity": "0 0 -9.8"') -and
    $bridgeText.Contains('self.data.ctrl[:] = targets') -and
    -not $bridgeText.Contains('self.data.qpos[:] =') -and
    -not $bridgeText.Contains('self.data.qvel[:] =') -and
    -not $bridgeText.Contains('qfrc_applied[') -and
    $implementationText.Contains("normal = jacobian.T @ jacobian + (DLS_LAMBDA_M**2) * np.eye(2)") -and
    $implementationText.Contains("expected_raw = np.linalg.solve(normal, rhs)") -and
    $implementationText.Contains(
        'f"C6_MJC_BW19V_MV4_TERMINAL_MEMORY_NOT_FROZEN:{limb_id}"'
    ) -and
    $implementationText.Contains("robot.core.canonical_velocity_compose_v1") -and
    $implementationText.Contains("robot.core.canonical_velocity_host_map_v1") -and
    $implementationText.Contains("robot.apply_host_mapping(mapping)") -and
    $canaryStart -ge 0 -and
    $canaryEnd -gt $canaryStart -and
    $canaryText.Contains('contacts["front_left_foot"] = False') -and
    $canaryText.Contains('"wrong_dls_solution"') -and
    $canaryText.Contains('"wrong_heading_delta"') -and
    $canaryText.Contains('"wrong_pose_memory_transition"') -and
    -not $canaryText.Contains("MujocoBw19vRobot") -and
    -not $canaryText.Contains("mujoco.MjModel") -and
    -not $canaryText.Contains("mujoco.MjData") -and
    $campaignPreflight -gt $campaignStart -and
    $campaignModel -gt $campaignPreflight
) "$gateId self-actuation, zero-world, or restoration structure changed"

& git -C $repoRoot cat-file -e "$expectedParent`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId implementation parent is not retained"
& git -C $repoRoot merge-base --is-ancestor $expectedParent HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId implementation parent is not an ancestor"

$rootsBefore = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory `
        -Filter "c6-mujoco-bw19v-mv4-*" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
Assert-Exact ($rootsBefore.Count -eq 0) (
    "$gateId campaign evidence already exists; prospective freeze is consumed"
)
$output = & pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -PreflightOnly 2>&1 | Out-String
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $output.Contains(
        "C6_MJC_BW19V_MV4_FREEZE_PASS worlds=0 steps=2992 commands=23936 " +
        "canaries=31 synthetic=17 dynamic=2 morphology=2 trace=5 " +
        "restoration=5 physical_authority=False"
    )
) "$gateId supervisor did not pass the complete zero-world freeze gate"
$rootsAfter = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory `
        -Filter "c6-mujoco-bw19v-mv4-*" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
Assert-Exact (
    ($rootsAfter -join "`n") -ceq ($rootsBefore -join "`n")
) "$gateId freeze audit created or changed campaign evidence"

$physicalRefusalOutput = & pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -RunPhysical 2>&1 | Out-String
$physicalRefusalExitCode = $LASTEXITCODE
$rootsAfterRefusal = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory `
        -Filter "c6-mujoco-bw19v-mv4-*" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
Assert-Exact (
    $physicalRefusalExitCode -ne 0 -and
    $physicalRefusalOutput.Contains(
        "$gateId -RunPhysical requires an exact full-Godot V2 attestation"
    ) -and
    ($rootsAfterRefusal -join "`n") -ceq ($rootsBefore -join "`n")
) "$gateId unqualified physical execution was not refused before evidence creation"

$runnerText = Get-Content -Raw -LiteralPath $runnerPath
Assert-Exact (
    $runnerText.Contains("already has a retained physical attempt and may not rerun") -and
    $runnerText.Contains("is closed and may not open another world") -and
    $runnerText.Contains("physical_process_launch_consumes_identity = `$true") -and
    $runnerText.Contains("same_identity_rerun_allowed = `$false") -and
    $runnerText.Contains(
        "physical execution requires distinct clean HEAD == origin/main == live GitHub main"
    ) -and
    $runnerText.Contains("retained a complete negative report")
) "$gateId physical lifecycle no longer fails closed"

Write-Host (
    "C6_MJC_BW19V_MV4_FREEZE_AUDIT_PASS worlds=0 steps=2992 " +
    "commands=23936 canaries=31 synthetic=17 dynamic=2 morphology=2 " +
    "trace=5 restoration=5 physical_authority=False"
)
