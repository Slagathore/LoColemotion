#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$evidenceBase = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "BW27P-BW27M-MATERIAL-PROFILE-PUBLICATION"
$gateId = "BW27P-PROFILE"
$sourceCommit = "e3a3c0b7ce8e7a6346b751458d92ac3b19acc33f"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw27p_material_profile_publication_closure.json"
$expectedClosureSha256 =
    "1709a79a2929159cca075c43e516bdfaa7dd1f87806dde648f6629e6069f41de"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw27p_material_profile_publication.ps1"
$runnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_bw27p_material_profile_conformance.ps1"
$characterizationClosureAuditPath = Join-Path (
    $PSScriptRoot
) "test_bw27m_material_characterization_closure.ps1"
$priorProfileClosureAuditPath = Join-Path (
    $PSScriptRoot
) "test_bw24p_material_profile_publication_closure.ps1"
$attestationPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-e3a3c0b7-20260802T170031Z\" +
    "attestation.json"
)
$expectedProfileIds = @(
    "godot_jolt_bw27m_mu062_v1",
    "godot_jolt_bw27m_mu074_v1",
    "godot_jolt_bw27m_mu086_v1"
)
$expectedProfileSha256 = @(
    "sha256:62bd8b2543c7c3cdb9b389029e5ae3de777cbcc29c5a5ba5b769863442c854c3",
    "sha256:6a8128171b87ad824b3675cbf731927681b55c0f529d179e3dbb32c842752857",
    "sha256:29735973a8334064f1a1a1fb8c8d679c335e68b4a97a396c550f68b76321863d"
)
$expectedAuthoredFriction = @(0.62, 0.74, 0.86)
$expectedControllerCoefficient = @(0.61, 0.73, 0.84)
$expectedMinimumLowerRatio = @(
    0.6119398367698766,
    0.739513920992915,
    0.8415623682133044
)
$expectedBrackets = @(
    "24|25;24|25;24|25",
    "29|30;29|30;29|30",
    "33|35;33|35;33|35"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Join-ExactValues {
    param([Parameter(Mandatory)][object[]]$Values)
    return (@($Values | ForEach-Object { [string]$_ }) -join "|")
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 64

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw27p_material_profile_publication_closure_v1" -and
    [string]$closure.status -ceq
        "closed_complete_valid_positive_deterministic_zero_world_profile_publication" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.study_classification -ceq
        "deterministic_zero_world_profile_publication_infrastructure" -and
    [string]$closure.publication_source_commit -ceq $sourceCommit -and
    [string]$closure.implementation_parent_commit -ceq
        "03b0f5c85d66f512017be5843f00adc0bedb85d3" -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.profile_record_or_retained_evidence_rewrite_allowed
) "$gateId closure identity or immutability changed"

$lifecycle = $closure.publication_lifecycle
Assert-Exact (
    [int]$lifecycle.successful_supervisor_invocation_count -eq 1 -and
    [bool]$lifecycle.pre_attempt_duplicate_invocation_refused_by_global_mutex -and
    -not [bool]$lifecycle.pre_attempt_mutex_refusal_consumed_identity -and
    [int]$lifecycle.identity_consuming_attempt_count -eq 1 -and
    [bool]$lifecycle.complete_pre_attempt_zero_world_gate_passed -and
    [bool]$lifecycle.attempt_contract_preflight_passed -and
    [int]$lifecycle.independent_negative_canary_count -eq 10 -and
    [int]$lifecycle.pre_attempt_profile_count -eq 38 -and
    [int]$lifecycle.pre_attempt_adapter_start_count -eq 39 -and
    [int]$lifecycle.pre_attempt_passed_gate_count -eq 49 -and
    [int]$lifecycle.pre_attempt_failed_gate_count -eq 0 -and
    [bool]$lifecycle.retained_report_zero_world_gate_passed -and
    [int]$lifecycle.retained_report_profile_count -eq 38 -and
    [int]$lifecycle.retained_report_adapter_start_count -eq 39 -and
    [int]$lifecycle.retained_report_passed_gate_count -eq 49 -and
    [int]$lifecycle.retained_report_failed_gate_count -eq 0 -and
    [int]$lifecycle.publication_supervisor_profile_conformance_execution_count -eq 2 -and
    [bool]$lifecycle.report_retained -and
    [bool]$lifecycle.completion_receipt_retained -and
    [bool]$lifecycle.source_worktree_clean -and
    [bool]$lifecycle.source_matches_origin_main -and
    [bool]$lifecycle.source_matches_live_github_main -and
    [int]$lifecycle.world_build_count -eq 0 -and
    [int]$lifecycle.sample_count -eq 0 -and
    [int]$lifecycle.command_count -eq 0 -and
    [int]$lifecycle.locomotion_seed_world_count -eq 0 -and
    [bool]$lifecycle.accepted
) "$gateId publication lifecycle or gate cardinality changed"

$qualification = $closure.prepublication_qualification
Assert-Exact (
    [bool]$qualification.full_godot_conformance_passed -and
    [string]$qualification.conformance_source_commit -ceq $sourceCommit -and
    [string]$qualification.conformance_source_tree_git_oid -ceq
        "e1877e4630ff75539614d84c25bae93ae9053ff0" -and
    [System.IO.Path]::GetFullPath([string]$qualification.attestation_path) -ceq
        $attestationPath -and
    [long]$qualification.attestation_byte_length -eq 3564 -and
    [string]$qualification.attestation_raw_sha256 -ceq
        "333616fff706cb4809abe7f4fa727ccc78482a32792aa1140906638efa2ca34d" -and
    [string]$qualification.attestation_schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [bool]$qualification.production_file_verifier_ok -and
    @($qualification.production_file_verifier_failure_codes).Count -eq 0 -and
    -not [bool]$qualification.attestation_one_shot_physical_campaign_executed -and
    [int]$qualification.attestation_true_claim_count -eq 0 -and
    [bool]$qualification.conformance_and_publication_serialized_by_global_mutex -and
    -not [bool]$qualification.publication_lock_abandoned_owner_recovered -and
    -not [bool]$qualification.physical_acceptance_authority
) "$gateId prepublication qualification changed"

Assert-Exact (
    $closure.frozen_source_blobs.Count -eq 16
) "$gateId frozen source binding count changed"
& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId publication source commit is unavailable"
foreach ($binding in @($closure.frozen_source_blobs.Values)) {
    $relativePath = [string]$binding.path
    $observedBlobOid = (& git -C $repoRoot rev-parse (
        "$sourceCommit`:$relativePath"
    )).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $observedBlobOid -ceq [string]$binding.git_blob_oid -and
        [string]$binding.raw_sha256 -cmatch "^[0-9a-f]{64}$"
    ) "$gateId frozen Git blob changed: $relativePath"

    # raw_sha256 is the immutable historical checkout receipt. The retained
    # source identity is the exact commit-pinned Git blob, never today's path.
}

Assert-Exact (
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    (Get-Item -LiteralPath $attestationPath).Length -eq 3564 -and
    (Get-RawSha256 -Path $attestationPath) -ceq
        "333616fff706cb4809abe7f4fa727ccc78482a32792aa1140906638efa2ca34d"
) "$gateId prepublication attestation is missing or changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$attestationTrueClaims = @(
    $attestation.claims.GetEnumerator() | Where-Object { [bool]$_.Value }
)
Assert-Exact (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    -not [bool]$attestation.test_only -and
    [bool]$attestation.conformance.passed -and
    [bool]$attestation.conformance.godot_including -and
    -not [bool]$attestation.conformance.skip_godot -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.origin_main -ceq $sourceCommit -and
    [string]$attestation.source.live_github_main -ceq $sourceCommit -and
    [bool]$attestation.source.clean_pushed_live -and
    [string]$attestation.source.tree_git_oid -ceq
        "e1877e4630ff75539614d84c25bae93ae9053ff0" -and
    [string]$attestation.godot.executable_sha256 -ceq
        "sha256:c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$attestation.godot.version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [bool]$attestation.operation_lock.acquired -and
    [string]$attestation.operation_lock.role -ceq "conformance" -and
    -not [bool]$attestation.operation_lock.abandoned_owner_recovered -and
    -not [bool]$attestation.operation_lock.test_only -and
    $attestationTrueClaims.Count -eq 0
) "$gateId attestation source, host, lock, or claim boundary changed"

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
Assert-Exact (
    $evidenceRoot -ceq
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw27p-material-profiles-e3a3c0b"
) "$gateId retained evidence root changed"
$artifactBindings = @(
    $closure.retained_evidence.GetEnumerator() |
        Where-Object { $_.Key -cne "root" }
)
Assert-Exact (
    $artifactBindings.Count -eq 8 -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File).Count -eq 8
) "$gateId retained evidence inventory changed"
foreach ($entry in $artifactBindings) {
    $artifact = $entry.Value
    $path = Join-Path $evidenceRoot ([string]$artifact.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$artifact.byte_length -and
        (Get-RawSha256 -Path $path) -ceq [string]$artifact.raw_sha256
    ) "$gateId retained artifact is missing or changed: $($artifact.path)"
}

$attemptPath = Join-Path $evidenceRoot "attempt.json"
$completionPath = Join-Path $evidenceRoot "completion.json"
$reportPath = Join-Path $evidenceRoot "report.json"
$attempt = Get-Content -Raw -LiteralPath $attemptPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$completion = Get-Content -Raw -LiteralPath $completionPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$receipt = $report.receipt

Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw27p_material_profile_publication_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [string]$attempt.full_conformance_attestation_path -ceq $attestationPath -and
    [string]$attempt.full_conformance_attestation_raw_sha256 -ceq
        "333616fff706cb4809abe7f4fa727ccc78482a32792aa1140906638efa2ca34d" -and
    [string]$attempt.full_conformance_attestation_source_commit -ceq
        $sourceCommit -and
    [bool]$attempt.full_conformance_attestation_validated -and
    [string]$attempt.preregistration_raw_sha256 -ceq
        [string]$closure.frozen_source_blobs.preregistration.raw_sha256 -and
    [string]$attempt.characterization_closure_raw_sha256 -ceq
        [string]$closure.frozen_source_blobs.material_characterization_closure.raw_sha256 -and
    [string]$attempt.prior_profile_closure_raw_sha256 -ceq
        [string]$closure.frozen_source_blobs.prior_profile_closure.raw_sha256 -and
    [string]$attempt.successor_conformance_runner_raw_sha256 -ceq
        [string]$closure.frozen_source_blobs.successor_zero_world_runner.raw_sha256 -and
    [string]$attempt.publication_supervisor_raw_sha256 -ceq
        [string]$closure.frozen_source_blobs.publication_supervisor.raw_sha256 -and
    [bool]$attempt.operation_lock.acquired -and
    [string]$attempt.operation_lock.role -ceq "physical" -and
    -not [bool]$attempt.operation_lock.abandoned_owner_recovered -and
    -not [bool]$attempt.operation_lock.test_only -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [bool]$attempt.attempt_contract_preflight_passed -and
    [int]$attempt.expected_profile_count -eq 38 -and
    [int]$attempt.expected_adapter_start_count -eq 39 -and
    [int]$attempt.expected_gate_count -eq 49 -and
    [int]$attempt.expected_world_count -eq 0 -and
    [int]$attempt.expected_sample_count -eq 0 -and
    [int]$attempt.expected_command_count -eq 0 -and
    [int]$attempt.locomotion_seed_world_count -eq 0 -and
    -not [bool]$attempt.synthetic_contract_preflight -and
    [bool]$attempt.publication_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    -not [bool]$attempt.physical_acceptance_authority
) "$gateId retained attempt authorization contract changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_godot_jolt_bw27p_material_profile_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.source_worktree_clean -and
    [bool]$report.source_matches_origin_main -and
    [bool]$report.source_matches_live_github_main -and
    [bool]$report.accepted -and
    [string]$report.result_status -ceq "passed" -and
    [int]$report.godot_exit_code -eq 0 -and
    [string]$report.attempt_contract.sha256 -ceq
        [string]$closure.retained_evidence.attempt.raw_sha256 -and
    [bool]$report.attempt_contract.preflight_passed -and
    [int]$report.attempt_contract.expected_profile_count -eq 38 -and
    [int]$report.attempt_contract.expected_adapter_start_count -eq 39 -and
    [int]$report.attempt_contract.expected_gate_count -eq 49 -and
    [bool]$report.attempt_contract.publication_identity_consumed
) "$gateId retained report identity or attempt contract changed"

Assert-Exact (
    [string]$receipt.schema_version -ceq
        "sporespore_godot_jolt_material_profile_receipt_v1" -and
    [bool]$receipt.ok -and
    [int]$receipt.expected_profile_count -eq 38 -and
    [int]$receipt.observed_profile_count -eq 38 -and
    [int]$receipt.expected_adapter_start_count -eq 39 -and
    [int]$receipt.observed_adapter_start_count -eq 39 -and
    [int]$receipt.expected_gate_count -eq 49 -and
    [int]$receipt.passed_gate_count -eq 49 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_world_count -eq 0 -and
    [int]$receipt.observed_world_count -eq 0 -and
    [int]$receipt.observed_sample_count -eq 0 -and
    [int]$receipt.observed_command_count -eq 0 -and
    [bool]$receipt.bw27m_fresh_material_profile_publication -and
    [int]$receipt.bw27m_profile_count -eq 3 -and
    @($receipt.profile_ids).Count -eq 38 -and
    @($receipt.profile_sha256).Count -eq 38 -and
    @($receipt.profile_sha256 | Select-Object -Unique).Count -eq 38 -and
    (Join-ExactValues -Values @(
        $receipt.profile_ids | Select-Object -Last 3
    )) -ceq (Join-ExactValues -Values $expectedProfileIds) -and
    (Join-ExactValues -Values @(
        $receipt.profile_sha256 | Select-Object -Last 3
    )) -ceq (Join-ExactValues -Values $expectedProfileSha256) -and
    -not [bool]$receipt.adapter_actuation_applied -and
    -not [bool]$receipt.physics_transform_or_velocity_written -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.continuous_friction_coverage -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.completed_engine_neutral_sdk
) "$gateId retained receipt cardinality, payload, or claim boundary changed"

Assert-Exact (
    [string]$completion.schema_version -ceq
        "sporespore_balanced_wave_bw27p_material_profile_publication_completion_v1" -and
    [string]$completion.campaign_id -ceq $campaignId -and
    [string]$completion.gate_id -ceq $gateId -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.report_path -ceq "report.json" -and
    [string]$completion.report_raw_sha256 -ceq
        "sha256:7cf2485149f3ca97a23f3ec0d7bc9ad352bbe3fad8ba3ffdd3e45948b6587b80" -and
    [bool]$completion.accepted -and
    [int]$completion.profile_count -eq 38 -and
    [int]$completion.prior_profile_count -eq 35 -and
    [int]$completion.bw27m_profile_count -eq 3 -and
    [int]$completion.adapter_start_count -eq 39 -and
    [int]$completion.passed_gate_count -eq 49 -and
    [int]$completion.failed_gate_count -eq 0 -and
    [int]$completion.world_build_count -eq 0 -and
    [int]$completion.sample_count -eq 0 -and
    [int]$completion.command_count -eq 0 -and
    [int]$completion.locomotion_seed_world_count -eq 0 -and
    [bool]$completion.attempt_contract_preflight_passed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId completion receipt changed"

$result = $closure.result
$profiles = @($result.profiles)
Assert-Exact (
    [bool]$result.accepted -and
    [string]$result.result_status -ceq "passed" -and
    [string]$result.profile_schema_version -ceq
        "sporespore_adapter_material_profile_v1" -and
    [int]$result.total_profile_count -eq 38 -and
    [int]$result.prior_profile_count -eq 35 -and
    [int]$result.bw27m_profile_count -eq 3 -and
    [int]$result.adapter_start_count -eq 39 -and
    [int]$result.passed_gate_count -eq 49 -and
    [int]$result.failed_gate_count -eq 0 -and
    [int]$result.world_build_count -eq 0 -and
    [int]$result.sample_count -eq 0 -and
    [int]$result.command_count -eq 0 -and
    $profiles.Count -eq 3
) "$gateId closure result changed"
for ($index = 0; $index -lt $profiles.Count; $index++) {
    $profile = $profiles[$index]
    $brackets = @($profile.replicate_breakaway_brackets_n | ForEach-Object {
        (@($_ | ForEach-Object { [string]$_ }) -join "|")
    }) -join ";"
    Assert-Exact (
        [string]$profile.profile_id -ceq $expectedProfileIds[$index] -and
        [double]$profile.authored_friction -eq
            $expectedAuthoredFriction[$index] -and
        [double]$profile.characterized_friction_coefficient -eq
            $expectedControllerCoefficient[$index] -and
        [double]$profile.minimum_lower_empirical_ratio -eq
            $expectedMinimumLowerRatio[$index] -and
        $brackets -ceq $expectedBrackets[$index] -and
        [string]$profile.profile_sha256 -ceq $expectedProfileSha256[$index]
    ) "$gateId published profile payload changed at index $index"
}

$disposition = $closure.scientific_disposition
Assert-Exact (
    [bool]$disposition.complete_valid_positive_deterministic_zero_world_profile_publication -and
    [bool]$disposition.profile_published -and
    [bool]$disposition.bw28y_manifest_freeze_authorized -and
    -not [bool]$disposition.bw28y_physical_launch_authorized -and
    -not [bool]$disposition.locomotion_outcome_observed -and
    -not [bool]$disposition.future_locomotion_seeds_opened -and
    -not [bool]$disposition.walking_acceptance -and
    -not [bool]$disposition.turning_acceptance -and
    -not [bool]$disposition.friction_or_material_locomotion_robustness -and
    -not [bool]$disposition.continuous_friction_coverage -and
    -not [bool]$disposition.portable_material_coefficient -and
    -not [bool]$disposition.cross_engine_equivalence -and
    -not [bool]$disposition.arbitrary_quadruped_coverage -and
    -not [bool]$disposition.release_authorized -and
    -not [bool]$disposition.physical_acceptance_authority -and
    -not [bool]$disposition.completed_engine_neutral_sdk
) "$gateId scientific disposition changed"
Assert-Exact (
    [bool]$closure.immutability.publication_attempt_report_completion_and_logs_may_not_be_rewritten -and
    [bool]$closure.immutability.profile_ids_values_coefficients_provenance_and_digests_may_not_change -and
    [bool]$closure.immutability.same_campaign_identity_may_not_publish_again -and
    [bool]$closure.immutability.bw28y_requires_a_new_source_preregistration_gate_and_evidence_identity -and
    [bool]$closure.next_allowed_work.bw27p_profile_publication_is_closed_positive -and
    [bool]$closure.next_allowed_work.distinct_bw28y_manifest_may_now_freeze -and
    (Join-ExactValues -Values @(
        $closure.next_allowed_work.sealed_future_locomotion_seeds
    )) -ceq "27011|27012|27013|27014" -and
    [int]$closure.next_allowed_work.bw28y_expected_world_count -eq 28 -and
    [bool]$closure.next_allowed_work.bw28y_physical_locomotion_may_not_open_before_distinct_manifest_and_complete_policy_relative_zero_world_gate -and
    [bool]$closure.next_allowed_work.release_selected_policy_unchanged -and
    [bool]$closure.next_allowed_work.release_not_authorized
) "$gateId immutable next-work boundary changed"

$engineLogPath = Join-Path $evidenceRoot "engine.log"
$transcriptPath = Join-Path $evidenceRoot "transcript.log"
Assert-Exact (
    @(Select-String -LiteralPath $engineLogPath `
        -Pattern '^SDK_MATERIAL_PROFILE_RECEIPT ').Count -eq 1 -and
    @(Select-String -LiteralPath $engineLogPath `
        -Pattern '^SDK Godot/Jolt P5M\.2 material-profile summary: 49 passed, 0 failed$').Count -eq 1 -and
    @(Select-String -LiteralPath $transcriptPath `
        -Pattern '^SDK_MATERIAL_PROFILE_RECEIPT ').Count -eq 1 -and
    @(Select-String -LiteralPath $transcriptPath `
        -Pattern '^SDK Godot/Jolt P5M\.2 material-profile summary: 49 passed, 0 failed$').Count -eq 1
) "$gateId retained terminal markers changed"

$attemptFiles = @(
    Get-ChildItem -LiteralPath $evidenceBase -Recurse -File -Filter "attempt.json" |
        Where-Object {
            try {
                $candidate = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$candidate.campaign_id -ceq $campaignId
            } catch { $false }
        }
)
Assert-Exact (
    $attemptFiles.Count -eq 1 -and
    [System.IO.Path]::GetFullPath($attemptFiles[0].FullName) -ceq $attemptPath
) "$gateId retained publication attempt cardinality changed"

& pwsh -NoProfile -File $runnerPath `
    -ValidateAttemptOnly `
    -PublicationAttempt $attemptPath `
    -HistoricalSourceCommit $sourceCommit
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId retained attempt no longer passes the production parser"
$wrongHistoricalCommit = "0" * 40
$wrongHistoricalOutput = (& pwsh -NoProfile -File $runnerPath `
    -ValidateAttemptOnly `
    -PublicationAttempt $attemptPath `
    -HistoricalSourceCommit $wrongHistoricalCommit 2>&1 | Out-String)
Assert-Exact (
    $LASTEXITCODE -ne 0 -and
    $wrongHistoricalOutput.Contains(
        "$gateId historical source commit is unavailable",
        [StringComparison]::Ordinal
    )
) "$gateId wrong historical source commit was not rejected"
$missingHistoricalOutput = (& pwsh -NoProfile -File $runnerPath `
    -ValidateAttemptOnly `
    -PublicationAttempt $attemptPath 2>&1 | Out-String)
Assert-Exact (
    $LASTEXITCODE -ne 0 -and
    $missingHistoricalOutput.Contains(
        "$gateId immutable prerequisite changed",
        [StringComparison]::Ordinal
    )
) "$gateId live-checkout parser unexpectedly accepted the historical attempt"
& pwsh -NoProfile -File $characterizationClosureAuditPath
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId BW27M characterization closure audit failed"
& pwsh -NoProfile -File $priorProfileClosureAuditPath
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId prior profile-publication closure audit failed"

$rerunRoot = Join-Path (
    $evidenceBase
) ("bw27p-closure-rerun-canary-" + [Guid]::NewGuid().ToString("N"))
$rerunOutput = (& pwsh -NoProfile -File $supervisorPath `
    -Publish `
    -OutputRoot $rerunRoot `
    -FullConformanceAttestation $attestationPath 2>&1 | Out-String)
$rerunExitCode = $LASTEXITCODE
Assert-Exact (
    $rerunExitCode -ne 0 -and
    $rerunOutput.Contains(
        "$gateId publication is already closed and may not rerun",
        [StringComparison]::Ordinal
    ) -and
    -not (Test-Path -LiteralPath $rerunRoot)
) "$gateId closed-state rerun interlock changed"

Write-Host (
    "BW27P_PROFILE_CLOSURE_PASS status=positive profiles=38 " +
    "prior_profiles=35 bw27m_profiles=3 adapter_starts=39 gates=49 " +
    "worlds=0 samples=0 commands=0 artifacts=8 attestation=True " +
    "operation_lock=True historical_parser_canaries=2 rerun_refused=True profile_published=True " +
    "bw28y_manifest=True material_robustness=False physical_authority=False"
)
