#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "C6-RAPIER-BW19V-VELOCITY-ONLY-TERMINAL-STANCE-COMMISSIONING-TS1"
$gateId = "C6-RAP-BW19V-V4-TS1"
$implementationParentCommit = "7ffd75c0b8f418dad1317c0a748ed4fd1e6e5f9b"
$preregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_terminal_stance_commissioning_ts1_preregistration.json"
$evaluatorPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bw19v_velocity_only_terminal_stance_ts1.rs"
$binaryPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bin\bw19v_velocity_only_terminal_stance_ts1.rs"
$runnerPath = Join-Path (
    $sdkRoot
) "run_rapier_c6_bw19v_velocity_only_terminal_stance_ts1.ps1"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_terminal_stance_commissioning_ts1_closure.json"
$expectedPreregistrationSha256 = (
    "749e873c5ee4652d59a266f046de638c36b656dc8a783ad43fadf67b8e2c1948"
)
$expectedEvaluatorSha256 = (
    "38b2459a68199e66fe3446015f3184b8ca44d4173df64fb116eccec82d7e5244"
)
$expectedBinarySha256 = (
    "17928f36e7ab81635370cdf6419965513407cc556fd78c1fc0537494104906f0"
)
$expectedRunnerSha256 = (
    "732e8573dec2b743d34b09c348e525a5cf2536aff911dce37c5a708d55d0a1f7"
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
    ) "TS1 frozen artifact missing or changed: $($entry[0])"
}
Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "TS1 already has a closure and is no longer a prospective freeze"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json
Assert-Exact (
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_bw19v_v4_ts1_physics_world" -and
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
    [int]$preregistration.physical_horizon.terminal_phase.frozen_evidence_limit_gait_step -eq 1912 -and
    [int]$preregistration.physical_horizon.terminal_phase.frozen_evidence_endpoint_global_cycle_step -eq 112 -and
    [int]$preregistration.physical_horizon.terminal_phase.target_gait_step -eq 1970 -and
    [int]$preregistration.physical_horizon.terminal_phase.target_global_cycle_step -eq 170 -and
    [int]$preregistration.physical_horizon.terminal_phase.active_contact_gated_gait_advance_steps -eq 58 -and
    [int]$preregistration.physical_horizon.terminal_phase.maximum_terminal_acquisition_steps_after_evidence_completion -eq 180 -and
    [int]$preregistration.physical_horizon.terminal_phase.terminal_completion_deadline_step_exclusive -eq 2812 -and
    [bool]$preregistration.physical_horizon.terminal_phase.all_target_local_phase_steps_are_stance -and
    -not [bool]$preregistration.physical_horizon.terminal_phase.outcome_dependent_target_selection -and
    [int]$preregistration.physical_horizon.required_post_terminal_steps -eq 360 -and
    [int]$preregistration.physical_horizon.terminal_zero_target_settle_steps -eq 0 -and
    [bool]$preregistration.physical_horizon.fixed_horizon_no_outcome_dependent_stop -and
    [string]$preregistration.walking_thresholds.provenance -clike
        "All numeric physical performance thresholds are inherited byte-for-value*" -and
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
        0.01194880859375
) "TS1 study class, fixed horizon, or inherited walking threshold changed"

foreach ($authorityName in @(
    "live_integration",
    "active_configuration_v2",
    "canonical_velocity_profile",
    "velocity_only_host_characterization",
    "pre_v4_long_horizon_predecessor",
    "early_v4_predecessor",
    "immediate_v4_predecessor"
)) {
    $authority = $preregistration.bound_authorities.$authorityName
    $authorityPath = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$authority.path))
    )
    Assert-Exact (
        (Test-Path -LiteralPath $authorityPath -PathType Leaf) -and
        (Get-RawSha256 -Path $authorityPath) -ceq [string]$authority.raw_sha256
    ) "TS1 pinned authority changed: $authorityPath"
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
    "TERMINAL_TARGET_GAIT_STEP",
    "terminal_schedule_is_analytically_all_stance",
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
    ) "TS1 evaluator lost required production or integrity surface: $needle"
}
foreach ($needle in @(
    '[bool]$PreflightOnly -xor [bool]$RunPhysical',
    'status --porcelain=v1 --untracked-files=all',
    'ls-remote origin refs/heads/main',
    'physical_process_launch_reserved_identity_consumed',
    'same_identity_rerun_allowed = $false',
    '-WindowStyle Hidden',
    'SporeSpore_Evidence'
)) {
    Assert-Exact (
        $runnerSource.Contains($needle, [StringComparison]::Ordinal)
    ) "TS1 runner lost fail-closed launch surface: $needle"
}
foreach ($needle in @(
    "evaluate_bw19v_velocity_only_terminal_stance_ts1_report",
    "run_bw19v_velocity_only_terminal_stance_ts1",
    "run_bw19v_velocity_only_terminal_stance_ts1_preflight"
)) {
    Assert-Exact (
        $libSource.Contains($needle, [StringComparison]::Ordinal)
    ) "TS1 library export missing: $needle"
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
) "TS1 already has a retained physical attempt"

& $runnerPath -PreflightOnly
Assert-Exact (
    $LASTEXITCODE -eq 0
) "TS1 complete zero-world supervisor preflight failed"

Write-Host (
    "C6_RAP_V4_TS1_FREEZE_PASS class=finite_decision worlds=0 " +
    "trace_steps=3172 commands_per_layer=25376 canaries=23 " +
    "identity_order=True terminal_target=1970 terminal_phase=170 " +
    "physical_authority=False"
)
