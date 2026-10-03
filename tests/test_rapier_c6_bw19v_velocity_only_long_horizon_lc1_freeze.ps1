#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "C6-RAPIER-BW19V-VELOCITY-ONLY-LONG-HORIZON-COMMISSIONING-LC1"
$gateId = "C6-RAP-BW19V-V4-LC1"
$implementationParentCommit = "81fd7edbcf0c646aef339961a9ee83feb4d862f3"
$preregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_preregistration.json"
$evaluatorPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bw19v_velocity_only_long_horizon_lc1.rs"
$binaryPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bin\bw19v_velocity_only_long_horizon_lc1.rs"
$runnerPath = Join-Path (
    $sdkRoot
) "run_rapier_c6_bw19v_velocity_only_long_horizon_lc1.ps1"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_closure.json"
$expectedPreregistrationSha256 = (
    "a5e88d5e0f69772c7dec67cc0d8bd83aa903ab2fe642a301fbf8ed3f09b47d0b"
)
$expectedEvaluatorSha256 = (
    "3504748b69b33f102f7e38146e811e9d4f243e5e19ef16bac58d20308f75b070"
)
$expectedBinarySha256 = (
    "dc3aee8a3c8f9d2154c76ba4f586b3b642e0d08e82a1a1685cf6e847c46c2676"
)
$expectedRunnerSha256 = (
    "733d974159b7a97364618b17b8da6fbff0ef6774fde793c2d7ce9115124160c9"
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
    ) "LC1 frozen artifact missing or changed: $($entry[0])"
}
Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "LC1 already has a closure and is no longer a prospective freeze"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json
Assert-Exact (
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_bw19v_v4_lc1_physics_world" -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [bool]$preregistration.study_class.finite_decision -and
    -not [bool]$preregistration.study_class.development_screen -and
    -not [bool]$preregistration.study_class.population_inference -and
    -not [bool]$preregistration.study_class.superiority_study -and
    -not [bool]$preregistration.study_class.noninferiority_or_equivalence_study -and
    [int]$preregistration.study_class.world_count -eq 1 -and
    [int]$preregistration.physical_horizon.total_controller_semantic_steps -eq 2992 -and
    [int]$preregistration.physical_horizon.clocked_steps -eq 472 -and
    [int]$preregistration.physical_horizon.evidence_deadline_step_exclusive -eq 2632 -and
    [int]$preregistration.physical_horizon.required_post_evidence_steps -eq 360 -and
    [int]$preregistration.physical_horizon.terminal_zero_target_settle_steps -eq 0 -and
    [bool]$preregistration.physical_horizon.fixed_horizon_no_outcome_dependent_stop -and
    [string]$preregistration.walking_thresholds.provenance -clike
        "Inherited byte-for-value from the prospectively frozen C2/ED1 family*" -and
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
) "LC1 study class, fixed horizon, or inherited walking threshold changed"

foreach ($authorityName in @(
    "live_integration",
    "active_configuration_v2",
    "canonical_velocity_profile",
    "velocity_only_host_characterization",
    "pre_v4_long_horizon_predecessor",
    "immediate_v4_predecessor"
)) {
    $authority = $preregistration.bound_authorities.$authorityName
    $authorityPath = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$authority.path))
    )
    Assert-Exact (
        (Test-Path -LiteralPath $authorityPath -PathType Leaf) -and
        (Get-RawSha256 -Path $authorityPath) -ceq [string]$authority.raw_sha256
    ) "LC1 pinned authority changed: $authorityPath"
}

$evaluatorSource = Get-Content -Raw -LiteralPath $evaluatorPath
$runnerSource = Get-Content -Raw -LiteralPath $runnerPath
$libSource = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "adapters\rapier\src\lib.rs"
)
foreach ($needle in @(
    "VELOCITY_ONLY_LIVE_PROFILE_ID",
    "positive_saturated_residual_case_passed",
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
    ) "LC1 evaluator lost required production or integrity surface: $needle"
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
    ) "LC1 runner lost fail-closed launch surface: $needle"
}
foreach ($needle in @(
    "evaluate_bw19v_velocity_only_long_horizon_lc1_report",
    "run_bw19v_velocity_only_long_horizon_lc1",
    "run_bw19v_velocity_only_long_horizon_lc1_preflight"
)) {
    Assert-Exact (
        $libSource.Contains($needle, [StringComparison]::Ordinal)
    ) "LC1 library export missing: $needle"
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
) "LC1 already has a retained physical attempt"

& $runnerPath -PreflightOnly
Assert-Exact (
    $LASTEXITCODE -eq 0
) "LC1 complete zero-world supervisor preflight failed"

Write-Host (
    "C6_RAP_V4_LC1_FREEZE_PASS class=finite_decision worlds=0 " +
    "trace_steps=2992 commands_per_layer=23936 canaries=17 " +
    "physical_authority=False"
)
