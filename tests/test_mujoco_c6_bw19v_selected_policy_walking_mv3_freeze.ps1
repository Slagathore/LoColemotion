#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$preregistrationPath = Join-Path $sdkRoot (
    "mujoco_c6_bw19v_selected_policy_walking_mv3_preregistration.json"
)
$implementationPath = Join-Path $sdkRoot (
    "adapters\mujoco\sporespore_mujoco_adapter\selected_policy_walking_mv3.py"
)
$bridgePath = Join-Path $sdkRoot (
    "adapters\mujoco\sporespore_mujoco_adapter\selected_policy_development.py"
)
$runnerPath = Join-Path $sdkRoot (
    "run_mujoco_c6_bw19v_selected_policy_walking_mv3.ps1"
)
$expectedParent = "04145c9cf0e24c3510da8936a1013c908fbcb3b5"
$campaignId = "C6-MUJOCO-BW19V-SELECTED-POLICY-WALKING-MV3"
$gateId = "C6-MJC-BW19V-MV3"
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
    "sdk/mujoco_c6_bw19v_selected_policy_walking_mv3_preregistration.json" = "77aa6696024af4b0bb8e289b798a4460773ff9f85940776bc24503cb88d18726"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_walking_mv3.py" = "a01cc11c5cb89d90b006b2bf05cee66d119722f0bbc7e1749c22671c8be24078"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py" = "306669481601cc91c8146e84a202a57228672e23c3f9daa0c531d2eb9d077e46"
    "sdk/mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.json" = "fbb8441fb8a3907c56155db777de00ce8b6e2f293ef67e77a2a30d2eeeb0f34f"
    "sdk/rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_preregistration.json" = "a5e88d5e0f69772c7dec67cc0d8bd83aa903ab2fe642a301fbf8ed3f09b47d0b"
    "sdk/balanced_wave_bw19v_closure_manifest.json" = "ea8df6a574e1b9be1050afa8ed57982a102982ada0f0d5babccf3c937c7067f7"
    "sdk/mujoco_c6_bw19v_selected_policy_walking_mv2_closure.json" = "0ef035bf76ebfc2c2ded74912cd5219f51304ae13086407324a5fbc491fec51c"
    "sdk/core/src/canonical_actuation.rs" = "e2d7e27edaf7caa218d95a5ed7966f5c6d317ff8c5990c5cd0e2876e1d485d05"
    "sdk/python/sporespore_locomotion.py" = "53e9be5f192f1424bd2d6c22aeecb563b8d7ed0ae3931901c2dcd576ee1160f7"
    "sdk/adapters/mujoco/requirements-lock.txt" = "38e97a013ec5e7c5bd88cd4dc1c2c54dd151936aa7f24c1f87abac19853b77b9"
    "sdk/run_mujoco_c6_bw19v_selected_policy_walking_mv3.ps1" = "9df058a96e99aa1af4989bce410edca89eaee08a47d06c16f397ac9114615d3e"
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
        "frozen_before_first_c6_mjc_bw19v_mv3_physics_world" -and
    [string]$declaration.implementation_parent_commit -ceq $expectedParent -and
    [bool]$declaration.study_class.development_outcome_exposed -and
    [bool]$declaration.outcome_exposure_disclosure.
        same_mujoco_body_policy_host_schedule_development_trajectory_observed -and
    -not [bool]$declaration.outcome_exposure_disclosure.
        numeric_walking_thresholds_tuned_from_mujoco_development_outcome -and
    [int]$declaration.physical_horizon.expected_world_count -eq 1 -and
    [int]$declaration.physical_horizon.total_controller_semantic_steps -eq 2992 -and
    [int]$declaration.physical_horizon.expected_commands_per_layer -eq 23936 -and
    [bool]$declaration.successor_distinction.implementation_only_successor_after_no_scientific_result -and
    -not [bool]$declaration.successor_distinction.predecessor_scientific_positive -and
    -not [bool]$declaration.successor_distinction.predecessor_scientific_negative -and
    -not [bool]$declaration.successor_distinction.predecessor_walking_evaluated -and
    [bool]$declaration.successor_distinction.predecessor_control_flow_horizon_completed -and
    [bool]$declaration.successor_distinction.predecessor_native_actuation_applied -and
    -not [bool]$declaration.successor_distinction.predecessor_complete_report_constructed -and
    -not [bool]$declaration.successor_distinction.predecessor_report_evaluated -and
    -not [bool]$declaration.successor_distinction.predecessor_report_serialized -and
    [int]$declaration.preflight_contract.negative_control_count -eq 31 -and
    [int]$declaration.preflight_contract.synthetic_report_negative_control_count -eq 27 -and
    [int]$declaration.preflight_contract.real_dynamic_library_negative_control_count -eq 2 -and
    [int]$declaration.preflight_contract.
        compiled_morphology_report_assembly_negative_control_count -eq 2 -and
    [int]$declaration.pre_freeze_implementation_qualification.
        ordinary_non_campaign_physics_world_count_after_mv3_design -eq 0
) "$gateId declaration identity, exposure, or finite horizon changed"

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
    [bool]$thresholds.terminal_four_contact_stance
) "$gateId frozen walking thresholds changed"

foreach ($claim in @(
    "independent_validation",
    "population_inference",
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

# Structural mechanism audit: the torso must be a free body under normal
# gravity, and the only mutable engine command path is the eight actuator ctrl
# targets inside the five-substep application routine.
$bridgeText = Get-Content -Raw -LiteralPath $bridgePath
$implementationText = Get-Content -Raw -LiteralPath $implementationPath
$canaryStart = $implementationText.IndexOf(
    "def _real_dynamic_library_profile_canary()",
    [StringComparison]::Ordinal
)
$canaryEnd = $implementationText.IndexOf(
    "def _preworld_dynamic_canary_failures(",
    [StringComparison]::Ordinal
)
$reportCanaryStart = $implementationText.IndexOf(
    "def _compiled_morphology_report_assembly_canary()",
    [StringComparison]::Ordinal
)
$reportCanaryEnd = $implementationText.IndexOf(
    "def _authorities()",
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
$reportCanaryText = if (
    $reportCanaryStart -ge 0 -and $reportCanaryEnd -gt $reportCanaryStart
) {
    $implementationText.Substring(
        $reportCanaryStart,
        $reportCanaryEnd - $reportCanaryStart
    )
} else { "" }
Assert-Exact (
    $bridgeText.Contains('ET.SubElement(element, "freejoint", {"name": "torso_free"})') -and
    $bridgeText.Contains('"gravity": "0 0 -9.8"') -and
    $bridgeText.Contains('self.data.ctrl[:] = targets') -and
    -not $bridgeText.Contains('self.data.qpos[:] =') -and
    -not $bridgeText.Contains('self.data.qvel[:] =') -and
    -not $bridgeText.Contains('mj_resetData') -and
    -not $bridgeText.Contains('qfrc_applied[') -and
    $implementationText.Contains('robot.apply_host_mapping(mapping)') -and
    -not $implementationText.Contains('run_development_probe(') -and
    $canaryStart -ge 0 -and
    $canaryEnd -gt $canaryStart -and
    $canaryText.Contains("core.canonical_velocity_host_map_v1(mapping_request)") -and
    $canaryText.Contains('"false_characterization"') -and
    $canaryText.Contains('"wrong_native_motor_model"') -and
    -not $canaryText.Contains("MujocoBw19vRobot") -and
    -not $canaryText.Contains("mujoco.MjModel") -and
    -not $canaryText.Contains("mujoco.MjData") -and
    $reportCanaryStart -ge 0 -and
    $reportCanaryEnd -gt $reportCanaryStart -and
    $reportCanaryText.Contains("_compiled_morphology_report_identity(fixture)") -and
    $reportCanaryText.Contains('"missing_compiled_morphology_id"') -and
    $reportCanaryText.Contains('"wrong_compiled_morphology_id"') -and
    $reportCanaryText.Contains('"morphology_id" not in fixture.morphology') -and
    -not $reportCanaryText.Contains("MujocoBw19vRobot") -and
    -not $reportCanaryText.Contains("mujoco.MjModel") -and
    -not $reportCanaryText.Contains("mujoco.MjData") -and
    $implementationText.Contains("**_compiled_morphology_report_identity(robot)") -and
    -not $implementationText.Contains('robot.morphology["morphology_id"]') -and
    $campaignPreflight -gt $campaignStart -and
    $campaignModel -gt $campaignPreflight
) "$gateId root freedom, pre-world ABI qualification, or self-actuation structure changed"

& git -C $repoRoot cat-file -e "$expectedParent`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId implementation parent is not retained"
& git -C $repoRoot merge-base --is-ancestor $expectedParent HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId implementation parent is not an ancestor"

$rootsBefore = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory `
        -Filter "c6-mujoco-bw19v-mv3-*" `
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
        "C6_MJC_BW19V_MV3_FREEZE_PASS worlds=0 steps=2992 commands=23936 " +
        "canaries=31 synthetic=27 dynamic=2 report=2 physical_authority=False"
    )
) "$gateId supervisor did not pass the complete zero-world freeze gate"
$rootsAfter = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory `
        -Filter "c6-mujoco-bw19v-mv3-*" `
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
        -Filter "c6-mujoco-bw19v-mv3-*" `
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
    $runnerText.Contains("same-identity rerun is forbidden") -and
    $runnerText.Contains("is closed and may not open another world") -and
    $runnerText.Contains("replacement_processes_allowed = 0") -and
    $runnerText.Contains(
        "physical execution requires distinct clean HEAD == origin/main == live GitHub main"
    ) -and
    $runnerText.Contains("retained a complete negative report")
) "$gateId physical lifecycle no longer fails closed"

Write-Host (
    "C6_MJC_BW19V_MV3_FREEZE_AUDIT_PASS worlds=0 steps=2992 " +
    "commands=23936 canaries=31 synthetic=27 dynamic=2 report=2 physical_authority=False"
)
