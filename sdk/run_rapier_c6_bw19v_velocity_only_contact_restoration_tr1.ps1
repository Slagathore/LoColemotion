[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$OutputRoot = "",
    [string]$FullConformanceAttestation = "",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "C6-RAPIER-BW19V-VELOCITY-ONLY-CONTACT-RESTORATION-COMMISSIONING-TR1"
$gateId = "C6-RAP-BW19V-V4-TR1"
$implementationParentCommit = "f9a61fcb624864c8772960948118bcbe1b948ec0"
$preregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_contact_restoration_commissioning_tr1_preregistration.json"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_contact_restoration_commissioning_tr1_closure.json"
$evaluatorPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bw19v_velocity_only_contact_restoration_tr1.rs"
$binaryPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bin\bw19v_velocity_only_contact_restoration_tr1.rs"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$attestationVerifierPath = Join-Path $sdkRoot (
    "locomotion_full_conformance_attestation.ps1"
)
$expectedPreregistrationRawSha256 = (
    "4e1a3f402a7bce27fad8c5d9eac403e75cf9b4f7a8983260beb2cc8b4b2e7ee2"
)
$expectedEvaluatorRawSha256 = (
    "4646a708545029a1bdc37885d567272fe4da13cef5cab5773b5651e18634e46a"
)
$expectedBinaryRawSha256 = (
    "bfb506434ad6e3742ea666cd0dc92f7d2dccb4fece96f6fb2bad282e70eba7eb"
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
Assert-Exact (
    $RunPhysical.IsPresent -or
    ([string]::IsNullOrWhiteSpace($OutputRoot) -and
        [string]::IsNullOrWhiteSpace($FullConformanceAttestation))
) "-OutputRoot and -FullConformanceAttestation are valid only with -RunPhysical"
Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/")
) "$gateId repository identity mismatch"
Assert-Exact (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "$gateId origin identity mismatch"
foreach ($requiredPath in @($operationLockPath, $attestationVerifierPath)) {
    Assert-Exact (Test-Path -LiteralPath $requiredPath -PathType Leaf) (
        "$gateId required safety source is missing: $requiredPath"
    )
}
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
        "frozen_before_first_c6_rap_bw19v_v4_tr1_physics_world" -and
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
    [int]$preregistration.physical_horizon.total_controller_semantic_steps -eq 3172 -and
    [int]$preregistration.physical_horizon.evidence_deadline_step_exclusive -eq 2632 -and
    [int]$preregistration.physical_horizon.terminal_restoration_phase.frozen_evidence_limit_gait_step -eq 1912 -and
    [bool]$preregistration.physical_horizon.terminal_restoration_phase.gait_memory_frozen_at_evidence_limit -and
    [string]$preregistration.physical_horizon.terminal_restoration_phase.restoration_policy_id -ceq
        "sporespore_contact_state_gated_damped_jacobian_vertical_search_v1" -and
    [double]$preregistration.physical_horizon.terminal_restoration_phase.missing_limb_desired_foot_velocity_world_m_s[1] -eq -0.02 -and
    [double]$preregistration.physical_horizon.terminal_restoration_phase.damped_least_squares_lambda_m -eq 0.04 -and
    [double]$preregistration.physical_horizon.terminal_restoration_phase.maximum_absolute_search_joint_velocity_rad_s -eq 0.35 -and
    [int]$preregistration.physical_horizon.terminal_restoration_phase.maximum_four_contact_acquisition_steps_after_evidence_completion -eq 180 -and
    [int]$preregistration.physical_horizon.terminal_restoration_phase.terminal_acquisition_deadline_step_exclusive -eq 2812 -and
    [int]$preregistration.physical_horizon.terminal_restoration_phase.required_consecutive_all_four_contact_steps -eq 360 -and
    [bool]$preregistration.physical_horizon.terminal_restoration_phase.hold_counter_resets_on_any_contact_loss -and
    [int]$preregistration.physical_horizon.required_post_terminal_steps -eq 360 -and
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
    [bool]$preregistration.claims_if_passed.exact_s169_rapier_v4_contact_restoration_technical_commissioning -and
    -not [bool]$preregistration.claims_if_passed.release_authorized -and
    -not [bool]$preregistration.claims_if_passed.physical_acceptance_authority
) "$gateId frozen study, horizon, motor contract, or claim boundary changed"

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
        (Get-RawSha256 $authorityPath) -ceq [string]$authority.raw_sha256
    ) "$gateId pinned authority changed: $authorityPath"
}

Push-Location -LiteralPath $sdkRoot
try {
    $preflightLines = @(
        & cargo run `
            --quiet `
            --package sporespore-rapier-adapter `
            --bin bw19v_velocity_only_contact_restoration_tr1 `
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
    [bool]$preflight.production_scheduler_order_memory_witness_passed -and
    [bool]$preflight.limb_memory_matched_by_explicit_limb_id -and
    [bool]$preflight.evidence_schedule_identity_is_exact -and
    [int]$preflight.synthetic_trace_step_count -eq 3172 -and
    [int]$preflight.synthetic_command_count_per_layer -eq 25376 -and
    [int]$preflight.synthetic_nonzero_bounded_residual_count -eq 11985 -and
    [int]$preflight.synthetic_nonzero_effective_host_residual_count -eq 11984 -and
    [int]$preflight.negative_control_count -eq 29 -and
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
        "$gateId PREFLIGHT_PASS trace_steps=3172 commands_per_layer=25376 " +
        "bounded=11985 effective=11984 canaries=29 identity_order=True " +
        "restorer=dls_vertical_0.02 lambda=0.04 max_qdot=0.35 worlds=0 " +
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

Assert-Exact (
    -not [string]::IsNullOrWhiteSpace($FullConformanceAttestation)
) "$gateId -RunPhysical requires an exact full-Godot V2 attestation"
. $operationLockPath
. $attestationVerifierPath
$operationLockReceipt = $null
$operationLockReceipt = Enter-SporeSporeLocomotionOperationLock -Role physical
Assert-Exact (
    [bool]$operationLockReceipt.acquired -and
    [string]$operationLockReceipt.role -ceq "physical" -and
    -not [bool]$operationLockReceipt.test_only
) "$gateId could not acquire the global locomotion physical-operation lock"

try {
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

$resolvedAttestationPath = [System.IO.Path]::GetFullPath(
    $FullConformanceAttestation
)
$attestationVerification = Test-SporeSporeFullConformanceAttestationFile `
    -RepoRoot $repoRoot `
    -Godot ([System.IO.Path]::GetFullPath($Godot)) `
    -AttestationPath $resolvedAttestationPath
Assert-Exact (
    [bool]$attestationVerification.ok -and
    @($attestationVerification.failure_codes).Count -eq 0
) (
    "$gateId exact full-conformance attestation failed: " +
    (@($attestationVerification.failure_codes) -join ",")
)
$attestation = Get-Content -Raw -LiteralPath $resolvedAttestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.origin_main -ceq $sourceCommit -and
    [string]$attestation.source.live_github_main -ceq $sourceCommit -and
    [bool]$attestation.source.clean_pushed_live -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed
) "$gateId full-conformance attestation source or campaign boundary changed"
foreach ($claimName in @($attestation.claims.Keys)) {
    Assert-Exact (-not [bool]$attestation.claims[$claimName]) (
        "$gateId full-conformance attestation inflated claim: $claimName"
    )
}

$shortCommit = $sourceCommit.Substring(0, 7)
$resolvedOutputRoot = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    Join-Path $evidenceRoot (
        "c6-rapier-bw19v-velocity-only-contact-restoration-tr1-$shortCommit"
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
    ) -and
    [System.IO.Path]::GetFileName($resolvedOutputRoot) -ceq
        "c6-rapier-bw19v-velocity-only-contact-restoration-tr1-$shortCommit" -and
    -not (Test-Path -LiteralPath $resolvedOutputRoot)
) "$gateId output root must be new, exact, and beneath SporeSpore_Evidence"
$preflightPath = Join-Path $resolvedOutputRoot "preflight.json"
$reportPath = Join-Path $resolvedOutputRoot "report.json"
$stdoutPath = Join-Path $resolvedOutputRoot "stdout.log"
$stderrPath = Join-Path $resolvedOutputRoot "stderr.log"
$attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
$completionPath = Join-Path $resolvedOutputRoot "completion.json"
foreach ($path in @(
    $preflightPath,
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
Write-NewJsonArtifact -Path $preflightPath -Value $preflight

$attemptId = [Guid]::NewGuid().ToString("N")
$operationLockPublic = Get-SporeSporeLocomotionOperationLockPublicReceipt `
    -Receipt $operationLockReceipt
$attestationRawSha256 = Get-RawSha256 $resolvedAttestationPath
$runnerRawSha256 = Get-RawSha256 $PSCommandPath

Write-NewJsonArtifact -Path $attemptPath -Value ([ordered]@{
    schema_version = "sporespore_physical_attempt_reservation_v1"
    attempt_id = $attemptId
    campaign_id = $campaignId
    gate_id = $gateId
    status = "physical_process_launch_reserved_identity_consumed"
    recorded_utc = (Get-Date).ToUniversalTime().ToString("o")
    source_commit = $sourceCommit
    source_origin_main = $originMainCommit
    source_live_github_main = $remoteCommit
    preregistration_raw_sha256 = "sha256:" + $expectedPreregistrationRawSha256
    evaluator_raw_sha256 = "sha256:" + $expectedEvaluatorRawSha256
    binary_raw_sha256 = "sha256:" + $expectedBinaryRawSha256
    runner_raw_sha256 = "sha256:" + $runnerRawSha256
    preflight_path = $preflightPath.Replace("\", "/")
    preflight_raw_sha256 = "sha256:" + (Get-RawSha256 $preflightPath)
    full_conformance_attestation_path = $resolvedAttestationPath.Replace("\", "/")
    full_conformance_attestation_raw_sha256 = "sha256:" + $attestationRawSha256
    full_conformance_attestation_source_commit = [string]$attestation.source.commit
    operation_lock = $operationLockPublic
    declared_world_count = 1
    declared_controller_steps = 3172
    declared_restoration_policy_id =
        "sporespore_contact_state_gated_damped_jacobian_vertical_search_v1"
    declared_required_consecutive_all_four_contact_steps = 360
    finite_decision = $true
    process_launch_consumes_identity = $true
    same_identity_rerun_allowed = $false
})

Assert-Exact (
    @(git -C $repoRoot status --porcelain=v1 --untracked-files=all).Count -eq 0 -and
    (git -C $repoRoot rev-parse HEAD).Trim() -ceq $sourceCommit -and
    (Get-RawSha256 $preregistrationPath) -ceq $expectedPreregistrationRawSha256 -and
    (Get-RawSha256 $evaluatorPath) -ceq $expectedEvaluatorRawSha256 -and
    (Get-RawSha256 $binaryPath) -ceq $expectedBinaryRawSha256 -and
    (Get-RawSha256 $PSCommandPath) -ceq $runnerRawSha256 -and
    (Get-RawSha256 $resolvedAttestationPath) -ceq $attestationRawSha256
) "$gateId source changed after attempt reservation; physical launch refused"

[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)
$cargo = (Get-Command cargo -ErrorAction Stop).Source
$process = $null
$launchError = $null
try {
    $process = Start-Process `
        -FilePath $cargo `
        -ArgumentList @(
            "run",
            "--quiet",
            "--package",
            "sporespore-rapier-adapter",
            "--bin",
            "bw19v_velocity_only_contact_restoration_tr1",
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
} catch {
    $launchError = $_.Exception.Message
}
$reportRetained = Test-Path -LiteralPath $reportPath -PathType Leaf
Write-NewJsonArtifact -Path $completionPath -Value ([ordered]@{
    schema_version = "sporespore_rapier_c6_bw19v_velocity_only_contact_restoration_tr1_completion_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    status = if ($reportRetained) {
        "physical_process_exited_with_report"
    } else {
        "physical_process_exited_without_report_abnormal_attempt"
    }
    recorded_utc = (Get-Date).ToUniversalTime().ToString("o")
    source_commit = $sourceCommit
    process_exit_code = if ($null -ne $process) { $process.ExitCode } else { $null }
    launch_error = $launchError
    physical_process_launched = $null -ne $process
    report_retained = [bool]$reportRetained
    report_raw_sha256 = if ($reportRetained) {
        "sha256:" + (Get-RawSha256 $reportPath)
    } else {
        $null
    }
    same_identity_rerun_allowed = $false
    operation_lock = $operationLockPublic
})
Assert-Exact ($null -ne $process) (
    "$gateId process launch failed after attempt reservation: $launchError"
)
Assert-Exact (
    $reportRetained
) "$gateId consumed its identity without retaining a report; immutable abnormal closure required"
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [int]$report.world_build_count -eq 1 -and
    [int]$report.trace_step_count -eq 3172 -and
    [int]$report.ordered_trace.Count -eq 3172 -and
    [int]$report.host_command_count -eq 25376 -and
    [string]$report.schedule.terminal_restoration_phase.restoration_policy_id -ceq
        "sporespore_contact_state_gated_damped_jacobian_vertical_search_v1" -and
    [int]$report.schedule.terminal_restoration_phase.required_consecutive_all_four_contact_steps -eq 360 -and
    [int]$report.schedule.required_post_terminal_steps -eq 360 -and
    [bool]$report.claim_boundary.exact_s169_rapier_v4_contact_restoration_technical_commissioning -eq
        [bool]$report.ok -and
    [bool]$report.claim_boundary.finite_single_body_walking_contract -eq [bool]$report.ok -and
    -not [bool]$report.claim_boundary.independent_validation -and
    -not [bool]$report.claim_boundary.cross_engine_selected_policy_equivalence -and
    -not [bool]$report.claim_boundary.release_authorized -and
    -not [bool]$report.claim_boundary.physical_acceptance_authority
) "$gateId retained report identity, integrity, or claim boundary is invalid"
Write-Host (
    "$gateId RETAINED report=$reportPath " +
    "sha256=$(Get-RawSha256 $reportPath) ok=$($report.ok)"
)
if ($process.ExitCode -ne 0 -or -not [bool]$report.ok) {
    throw (
        "$gateId retained a complete negative report. Close it without " +
        "rerun, rethresholding, or world replacement."
    )
}
} finally {
    if ($null -ne $operationLockReceipt) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLockReceipt
    }
}
