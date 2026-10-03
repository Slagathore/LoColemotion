[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "C6-RAPIER-BW19V-VELOCITY-ONLY-LONG-HORIZON-COMMISSIONING-LC1"
$gateId = "C6-RAP-BW19V-V4-LC1"
$implementationParentCommit = "81fd7edbcf0c646aef339961a9ee83feb4d862f3"
$preregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_preregistration.json"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_closure.json"
$evaluatorPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bw19v_velocity_only_long_horizon_lc1.rs"
$binaryPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bin\bw19v_velocity_only_long_horizon_lc1.rs"
$expectedPreregistrationRawSha256 = (
    "a5e88d5e0f69772c7dec67cc0d8bd83aa903ab2fe642a301fbf8ed3f09b47d0b"
)
$expectedEvaluatorRawSha256 = (
    "3504748b69b33f102f7e38146e811e9d4f243e5e19ef16bac58d20308f75b070"
)
$expectedBinaryRawSha256 = (
    "dc3aee8a3c8f9d2154c76ba4f586b3b642e0d08e82a1a1685cf6e847c46c2676"
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

function Write-NewJsonArtifact {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    Assert-Exact (
        -not (Test-Path -LiteralPath $Path)
    ) "Refusing to overwrite a $gateId artifact: $Path"
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $temporary = $Path + ".tmp"
    Assert-Exact (
        -not (Test-Path -LiteralPath $temporary)
    ) "Refusing stale $gateId temporary artifact: $temporary"
    [System.IO.File]::WriteAllText(
        $temporary,
        (($Value | ConvertTo-Json -Depth 30) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporary -Destination $Path
}

Assert-Exact (
    [bool]$PreflightOnly -xor [bool]$RunPhysical
) "Specify exactly one of -PreflightOnly or -RunPhysical"
if ($RunPhysical) {
    Assert-Exact (
        -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
    ) "$gateId is already closed and may not open another world"
}
Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Get-RawSha256 $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256
) "$gateId preregistration is missing or changed"
Assert-Exact (
    (Test-Path -LiteralPath $evaluatorPath -PathType Leaf) -and
    (Get-RawSha256 $evaluatorPath) -ceq $expectedEvaluatorRawSha256
) "$gateId evaluator is missing or changed"
Assert-Exact (
    (Test-Path -LiteralPath $binaryPath -PathType Leaf) -and
    (Get-RawSha256 $binaryPath) -ceq $expectedBinaryRawSha256
) "$gateId binary is missing or changed"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json
Assert-Exact (
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_bw19v_v4_lc1_physics_world" -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [string]$preregistration.study_class.classification -ceq
        "outcome_exposed_single_body_finite_technical_commissioning_decision" -and
    [bool]$preregistration.study_class.finite_decision -and
    -not [bool]$preregistration.study_class.population_inference -and
    -not [bool]$preregistration.study_class.superiority_study -and
    -not [bool]$preregistration.study_class.noninferiority_or_equivalence_study -and
    [int]$preregistration.initialization_contract.zero_target_settle_steps -eq 0 -and
    [int]$preregistration.physical_horizon.expected_world_count -eq 1 -and
    [int]$preregistration.physical_horizon.total_controller_semantic_steps -eq 2992 -and
    [int]$preregistration.physical_horizon.terminal_zero_target_settle_steps -eq 0 -and
    [double]$preregistration.frozen_portable_identity.global_requested_correction_scale -eq 0.5 -and
    [string]$preregistration.frozen_host_identity.motor_profile_id -ceq
        "rapier_force_based_velocity_only_v1" -and
    [string]$preregistration.frozen_host_identity.motor_model -ceq "ForceBased" -and
    [string]$preregistration.frozen_host_identity.motor_mode -ceq "velocity_only" -and
    [double]$preregistration.frozen_host_identity.native_position_stiffness_nm_per_rad -eq 0.0 -and
    [int]$preregistration.preflight_contract.world_build_count -eq 0 -and
    -not [bool]$preregistration.preflight_contract.physical_acceptance_authority -and
    -not [bool]$preregistration.claims_if_passed.independent_validation -and
    -not [bool]$preregistration.claims_if_passed.release_authorized -and
    -not [bool]$preregistration.claims_if_passed.physical_acceptance_authority
) "$gateId frozen study, horizon, motor contract, or claim boundary changed"

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
        (Get-RawSha256 $authorityPath) -ceq [string]$authority.raw_sha256
    ) "$gateId pinned authority changed: $authorityPath"
}

Push-Location -LiteralPath $sdkRoot
try {
    $preflightLines = @(
        & cargo run `
            --quiet `
            --package sporespore-rapier-adapter `
            --bin bw19v_velocity_only_long_horizon_lc1 `
            --offline `
            -- `
            --preflight-only
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId zero-world complete synthetic gate failed"
} finally {
    Pop-Location
}
$preflight = ($preflightLines -join [Environment]::NewLine) |
    ConvertFrom-Json
Assert-Exact (
    [bool]$preflight.ok -and
    [string]$preflight.campaign_id -ceq $campaignId -and
    [string]$preflight.gate_id -ceq $gateId -and
    [string]$preflight.preregistration_raw_sha256 -ceq
        ("sha256:" + $expectedPreregistrationRawSha256) -and
    [string]$preflight.production_motor_profile_id -ceq
        "rapier_force_based_velocity_only_v1" -and
    [bool]$preflight.production_profile_identity_imported_from_real_mapper -and
    [bool]$preflight.perfect_synthetic_whole_gate_passed -and
    [bool]$preflight.positive_saturated_residual_case_passed -and
    [int]$preflight.synthetic_trace_step_count -eq 2992 -and
    [int]$preflight.synthetic_command_count_per_layer -eq 23936 -and
    [int]$preflight.synthetic_nonzero_bounded_residual_count -eq 2992 -and
    [int]$preflight.synthetic_nonzero_effective_host_residual_count -eq 2991 -and
    [int]$preflight.negative_control_count -eq 17 -and
    [bool]$preflight.all_negative_controls_rejected -and
    [bool]$preflight.serialization_round_trip_passed -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_insertion_count -eq 0 -and
    [int]$preflight.physics_state_mutation_count -eq 0 -and
    -not [bool]$preflight.locomotion_outcome_exposed -and
    -not [bool]$preflight.physical_acceptance_authority
) "$gateId zero-world receipt is incomplete or changed"
if ($PreflightOnly) {
    Write-Host (
        "$gateId PREFLIGHT_PASS trace_steps=2992 commands_per_layer=23936 " +
        "bounded=2992 effective=2991 canaries=17 worlds=0 " +
        "physical_authority=False"
    )
    return
}

if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorAttempts = @(
        Get-ChildItem `
            -LiteralPath $evidenceRoot `
            -Recurse `
            -File `
            -Filter "attempt.json" |
        Where-Object {
            try {
                $receipt = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$receipt.campaign_id -ceq $campaignId
            } catch {
                $false
            }
        }
    )
    Assert-Exact (
        $priorAttempts.Count -eq 0
    ) "$gateId already has a retained physical attempt and may not rerun"
}

$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMainCommit = (& git -C $repoRoot rev-parse origin/main).Trim()
$remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$remoteCommit = ($remoteLine -split "\s+")[0]
$sourceStatus = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all)
Assert-Exact (
    $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
    $sourceCommit -cne $implementationParentCommit -and
    $sourceCommit -ceq $originMainCommit -and
    $sourceCommit -ceq $remoteCommit -and
    $sourceStatus.Count -eq 0
) "$gateId requires clean, pushed source distinct from its implementation parent"

$shortCommit = $sourceCommit.Substring(0, 7)
$resolvedOutputRoot = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    Join-Path $evidenceRoot (
        "c6-rapier-bw19v-velocity-only-lc1-$shortCommit"
    )
} else {
    [System.IO.Path]::GetFullPath($OutputRoot)
}
$evidencePrefix = $evidenceRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
Assert-Exact (
    $resolvedOutputRoot.StartsWith(
        $evidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId evidence must live beneath SporeSpore_Evidence"
$reportPath = Join-Path $resolvedOutputRoot "report.json"
$stdoutPath = Join-Path $resolvedOutputRoot "stdout.log"
$stderrPath = Join-Path $resolvedOutputRoot "stderr.log"
$attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
$completionPath = Join-Path $resolvedOutputRoot "completion.json"
foreach ($path in @(
    $reportPath,
    $stdoutPath,
    $stderrPath,
    $attemptPath,
    $completionPath
)) {
    Assert-Exact (
        -not (Test-Path -LiteralPath $path)
    ) "Refusing to overwrite $gateId evidence: $path"
}

Write-NewJsonArtifact -Path $attemptPath -Value ([ordered]@{
    schema_version = "sporespore_rapier_c6_bw19v_velocity_only_lc1_attempt_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    status = "physical_process_launch_reserved_identity_consumed"
    recorded_utc = (Get-Date).ToUniversalTime().ToString("o")
    source_commit = $sourceCommit
    preregistration_raw_sha256 = "sha256:" + $expectedPreregistrationRawSha256
    evaluator_raw_sha256 = "sha256:" + $expectedEvaluatorRawSha256
    binary_raw_sha256 = "sha256:" + $expectedBinaryRawSha256
    declared_world_count = 1
    declared_controller_steps = 2992
    finite_decision = $true
    process_launch_consumes_identity = $true
    same_identity_rerun_allowed = $false
})

[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)
$cargo = (Get-Command cargo -ErrorAction Stop).Source
$process = Start-Process `
    -FilePath $cargo `
    -ArgumentList @(
        "run",
        "--quiet",
        "--package",
        "sporespore-rapier-adapter",
        "--bin",
        "bw19v_velocity_only_long_horizon_lc1",
        "--offline",
        "--",
        "--source-commit",
        $sourceCommit,
        "--output",
        $reportPath
    ) `
    -WorkingDirectory $sdkRoot `
    -WindowStyle Hidden `
    -Wait `
    -PassThru `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath
$reportRetained = Test-Path -LiteralPath $reportPath -PathType Leaf
Write-NewJsonArtifact -Path $completionPath -Value ([ordered]@{
    schema_version = "sporespore_rapier_c6_bw19v_velocity_only_lc1_completion_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    status = if ($reportRetained) {
        "physical_process_exited_with_report"
    } else {
        "physical_process_exited_without_report_abnormal_attempt"
    }
    recorded_utc = (Get-Date).ToUniversalTime().ToString("o")
    source_commit = $sourceCommit
    process_exit_code = $process.ExitCode
    physical_process_launched = $true
    report_retained = [bool]$reportRetained
    report_raw_sha256 = if ($reportRetained) {
        "sha256:" + (Get-RawSha256 $reportPath)
    } else {
        $null
    }
    same_identity_rerun_allowed = $false
})
Assert-Exact (
    $reportRetained
) "$gateId consumed its identity without retaining a report; immutable abnormal closure required"
$report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
Assert-Exact (
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.ok -and
    [int]$report.world_build_count -eq 1 -and
    [int]$report.trace_step_count -eq 2992 -and
    [int]$report.host_command_count -eq 23936 -and
    [bool]$report.claim_boundary.exact_s169_rapier_v4_long_horizon_technical_commissioning -and
    [bool]$report.claim_boundary.finite_single_body_walking_contract -and
    -not [bool]$report.claim_boundary.independent_validation -and
    -not [bool]$report.claim_boundary.physical_acceptance_authority -and
    $process.ExitCode -eq 0
) "$gateId retained a negative or invalid finite commissioning report"
Write-Host (
    "$gateId RETAINED report=$reportPath " +
    "sha256=$(Get-RawSha256 $reportPath) technical_commissioning=True"
)
