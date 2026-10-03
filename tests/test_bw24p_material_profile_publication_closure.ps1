#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$evidenceBase = Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"
$campaignId = "BW24P-BW24M-PROFILE-PUBLICATION-SUCCESSOR"
$gateId = "BW24P-PROFILE"
$sourceCommit = "65cc27b47f09960a466332961346ad06b81307fe"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24p_material_profile_publication_closure.json"
$expectedClosureSha256 =
    "c8a0b9d64740a79562e2f07c85f366921cc585b5429e938a360a3489a1585cfa"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw24p_material_profile_publication.ps1"
$predecessorClosureAuditPath = Join-Path (
    $PSScriptRoot
) "test_bw24m_material_profile_publication_closure.ps1"
$characterizationClosureAuditPath = Join-Path (
    $PSScriptRoot
) "test_bw24m_material_characterization_closure.ps1"
$expectedProfileIds = @(
    "godot_jolt_bw24m_mu059_v1",
    "godot_jolt_bw24m_mu071_v1",
    "godot_jolt_bw24m_mu083_v1"
)
$expectedProfileSha256 = @(
    "sha256:2d8a2571c129dbe7b2b894bae1aa28f5650fdbea27fcb65a149566c54a536173",
    "sha256:a8efdd111b740391931219d720079beffeea8181e5c46fd00ea7acb6108ab8ee",
    "sha256:e5916d9e17f87120e5cc04ff03e8688c4dea3919715a68854a8dce29e4d9c2a0"
)
$expectedAuthoredFriction = @(0.59, 0.71, 0.83)
$expectedControllerCoefficient = @(0.58, 0.68, 0.81)
$expectedMinimumLowerRatio = @(
    0.5864476091642263,
    0.688520883045167,
    0.816026345341562
)
$expectedBrackets = @(
    "23|24;23|24;23|24",
    "27|29;27|29;27|29",
    "32|33;32|33;32|33"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
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
    ConvertFrom-Json -AsHashtable

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw24p_material_profile_publication_closure_v1" -and
    [string]$closure.status -ceq
        "closed_complete_valid_positive_deterministic_zero_world_profile_publication" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.study_classification -ceq
        "deterministic_zero_world_profile_publication_infrastructure_successor" -and
    [string]$closure.publication_source_commit -ceq $sourceCommit -and
    [string]$closure.implementation_parent_commit -ceq
        "4eb763aa673f7e21462ef4ef32c63a21f290f36e" -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.profile_record_or_retained_evidence_rewrite_allowed
) "$gateId closure identity or immutability changed"

$lifecycle = $closure.publication_lifecycle
Assert-Exact (
    [int]$lifecycle.supervisor_invocation_count -eq 1 -and
    [int]$lifecycle.identity_consuming_attempt_count -eq 1 -and
    [bool]$lifecycle.complete_pre_attempt_zero_world_gate_passed -and
    [bool]$lifecycle.attempt_contract_preflight_passed -and
    [int]$lifecycle.pre_attempt_profile_count -eq 35 -and
    [int]$lifecycle.pre_attempt_adapter_start_count -eq 36 -and
    [int]$lifecycle.pre_attempt_passed_gate_count -eq 46 -and
    [int]$lifecycle.pre_attempt_failed_gate_count -eq 0 -and
    [bool]$lifecycle.retained_report_zero_world_gate_passed -and
    [int]$lifecycle.retained_report_profile_count -eq 35 -and
    [int]$lifecycle.retained_report_adapter_start_count -eq 36 -and
    [int]$lifecycle.retained_report_passed_gate_count -eq 46 -and
    [int]$lifecycle.retained_report_failed_gate_count -eq 0 -and
    [int]$lifecycle.publication_supervisor_profile_conformance_execution_count -eq 2 -and
    [bool]$lifecycle.report_retained -and
    [bool]$lifecycle.completion_receipt_retained -and
    [bool]$lifecycle.source_worktree_clean -and
    [bool]$lifecycle.source_matches_origin_main -and
    [bool]$lifecycle.source_matches_live_github_main -and
    [bool]$lifecycle.repository_wide_prepublication_conformance_passed -and
    [string]$lifecycle.repository_wide_prepublication_conformance_source_commit -ceq
        $sourceCommit -and
    [int]$lifecycle.world_build_count -eq 0 -and
    [int]$lifecycle.sample_count -eq 0 -and
    [int]$lifecycle.command_count -eq 0 -and
    [int]$lifecycle.locomotion_seed_world_count -eq 0 -and
    [bool]$lifecycle.accepted
) "$gateId publication lifecycle or gate cardinality changed"

$successor = $closure.successor_contract
Assert-Exact (
    [string]$successor.predecessor_campaign_id -ceq
        "BW24M-BW23Y-FRESH-MATERIAL-PROFILE-PUBLICATION" -and
    [string]$successor.predecessor_gate_id -ceq "BW24M-PROFILE" -and
    [string]$successor.predecessor_status -ceq
        "closed_incomplete_invalid_publication_attempt_contract_mismatch" -and
    -not [bool]$successor.predecessor_profile_published -and
    [string]$successor.predecessor_failure_class -ceq
        "publication_supervisor_attempt_cardinality_defect" -and
    -not [bool]$successor.profile_payload_changed -and
    -not [bool]$successor.outcome_dependent_threshold_or_payload_change -and
    [bool]$successor.shared_synthetic_and_real_attempt_constructor -and
    [bool]$successor.production_parser_requires_exact_key_set -and
    [int]$successor.declared_profile_count -eq 35 -and
    [int]$successor.declared_adapter_start_count -eq 36 -and
    [int]$successor.declared_gate_count -eq 46 -and
    [int]$successor.independent_prospective_negative_canary_count -eq 10 -and
    [bool]$successor.predecessor_cardinality_rejected
) "$gateId scientifically distinct successor contract changed"

Assert-Exact (
    $closure.frozen_source_blobs.Count -eq 17
) "$gateId frozen source binding count changed"
& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is unavailable"
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

    # The publication commit is permanent source authority. The historical raw
    # checkout receipt is not revalidated against today's filter-dependent path.
}

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
Assert-Exact (
    $evidenceRoot -ceq
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw24p-material-profiles-65cc27b"
) "$gateId retained evidence root changed"
$artifactBindings = @(
    $closure.retained_evidence.GetEnumerator() |
        Where-Object { $_.Key -cne "root" }
)
Assert-Exact (
    $artifactBindings.Count -eq 13
) "$gateId retained evidence binding count changed"
Assert-Exact (
    @(Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File).Count -eq 13
) "$gateId retained evidence file inventory changed"
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
    ConvertFrom-Json -AsHashtable
$completion = Get-Content -Raw -LiteralPath $completionPath |
    ConvertFrom-Json -AsHashtable
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable
$receipt = $report.receipt

Assert-Exact (
    $attempt.Count -eq 30 -and
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw24p_material_profile_publication_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [string]$attempt.godot_version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [string]$attempt.godot_executable_sha256 -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$attempt.preregistration_raw_sha256 -ceq
        [string]$closure.frozen_source_blobs.preregistration.raw_sha256 -and
    [string]$attempt.predecessor_closure_raw_sha256 -ceq
        [string]$closure.frozen_source_blobs.predecessor_profile_closure.raw_sha256 -and
    [string]$attempt.predecessor_closure_audit_raw_sha256 -ceq
        [string]$closure.frozen_source_blobs.predecessor_profile_closure_audit.raw_sha256 -and
    [string]$attempt.base_conformance_runner_raw_sha256 -ceq
        [string]$closure.frozen_source_blobs.base_zero_world_runner.raw_sha256 -and
    [string]$attempt.successor_conformance_runner_raw_sha256 -ceq
        [string]$closure.frozen_source_blobs.successor_zero_world_runner.raw_sha256 -and
    [string]$attempt.publication_supervisor_raw_sha256 -ceq
        [string]$closure.frozen_source_blobs.publication_supervisor.raw_sha256 -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [bool]$attempt.attempt_contract_preflight_passed -and
    [int]$attempt.expected_profile_count -eq 35 -and
    [int]$attempt.expected_adapter_start_count -eq 36 -and
    [int]$attempt.expected_gate_count -eq 46 -and
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
        "sporespore_godot_jolt_bw24p_material_profile_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.source_worktree_clean -and
    [bool]$report.source_matches_origin_main -and
    [bool]$report.source_matches_live_github_main -and
    [bool]$report.accepted -and
    [string]$report.result_status -ceq "passed" -and
    [int]$report.godot_exit_code -eq 0 -and
    [bool]$report.attempt_contract.preflight_passed -and
    [int]$report.attempt_contract.expected_profile_count -eq 35 -and
    [int]$report.attempt_contract.expected_adapter_start_count -eq 36 -and
    [int]$report.attempt_contract.expected_gate_count -eq 46 -and
    [bool]$report.attempt_contract.predecessor_cardinality_rejected
) "$gateId retained report identity or attempt contract changed"

Assert-Exact (
    [string]$receipt.schema_version -ceq
        "sporespore_godot_jolt_material_profile_receipt_v1" -and
    [bool]$receipt.ok -and
    [int]$receipt.expected_profile_count -eq 35 -and
    [int]$receipt.observed_profile_count -eq 35 -and
    [int]$receipt.expected_adapter_start_count -eq 36 -and
    [int]$receipt.observed_adapter_start_count -eq 36 -and
    [int]$receipt.expected_gate_count -eq 46 -and
    [int]$receipt.passed_gate_count -eq 46 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_world_count -eq 0 -and
    [int]$receipt.observed_world_count -eq 0 -and
    [int]$receipt.observed_sample_count -eq 0 -and
    [int]$receipt.observed_command_count -eq 0 -and
    [bool]$receipt.bw24m_fresh_material_profile_publication -and
    [int]$receipt.bw24m_profile_count -eq 3 -and
    @($receipt.profile_ids).Count -eq 35 -and
    @($receipt.profile_sha256).Count -eq 35 -and
    @($receipt.profile_sha256 | Select-Object -Unique).Count -eq 35 -and
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
        "sporespore_balanced_wave_bw24p_material_profile_publication_completion_v1" -and
    [string]$completion.campaign_id -ceq $campaignId -and
    [string]$completion.gate_id -ceq $gateId -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.report_path -ceq "report.json" -and
    [string]$completion.report_raw_sha256 -ceq
        "sha256:c0c5cc0df46b19222eb74a9d92c7165a76a56332fd611bea49a9c39450b1873f" -and
    [bool]$completion.accepted -and
    [int]$completion.profile_count -eq 35 -and
    [int]$completion.prior_profile_count -eq 32 -and
    [int]$completion.bw24m_profile_count -eq 3 -and
    [int]$completion.adapter_start_count -eq 36 -and
    [int]$completion.passed_gate_count -eq 46 -and
    [int]$completion.failed_gate_count -eq 0 -and
    [int]$completion.world_build_count -eq 0 -and
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
    [int]$result.total_profile_count -eq 35 -and
    [int]$result.prior_profile_count -eq 32 -and
    [int]$result.bw24m_profile_count -eq 3 -and
    [int]$result.adapter_start_count -eq 36 -and
    [int]$result.passed_gate_count -eq 46 -and
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
        [string]$profile.profile_sha256 -ceq
            $expectedProfileSha256[$index]
    ) "$gateId published profile payload changed at index $index"
}

$disposition = $closure.scientific_disposition
Assert-Exact (
    [bool]$disposition.complete_valid_positive_deterministic_zero_world_profile_publication -and
    [bool]$disposition.profile_published -and
    [bool]$disposition.bw25y_manifest_freeze_authorized -and
    -not [bool]$disposition.bw25y_physical_launch_authorized -and
    -not [bool]$disposition.locomotion_outcome_observed -and
    -not [bool]$disposition.future_locomotion_seeds_opened -and
    -not [bool]$disposition.walking_acceptance -and
    -not [bool]$disposition.friction_or_material_locomotion_robustness -and
    -not [bool]$disposition.continuous_friction_coverage -and
    -not [bool]$disposition.portable_material_coefficient -and
    -not [bool]$disposition.cross_engine_equivalence -and
    -not [bool]$disposition.turning_acceptance -and
    -not [bool]$disposition.release_authorized -and
    -not [bool]$disposition.physical_acceptance_authority -and
    -not [bool]$disposition.completed_engine_neutral_sdk
) "$gateId scientific disposition changed"
Assert-Exact (
    [bool]$closure.immutability.publication_attempt_report_completion_and_logs_may_not_be_rewritten -and
    [bool]$closure.immutability.profile_ids_values_coefficients_provenance_and_digests_may_not_change -and
    [bool]$closure.immutability.same_campaign_identity_may_not_publish_again -and
    [bool]$closure.immutability.bw25y_requires_a_new_source_preregistration_gate_and_evidence_identity -and
    [bool]$closure.next_allowed_work.bw24p_profile_publication_is_closed_positive -and
    [bool]$closure.next_allowed_work.distinct_bw25y_manifest_may_now_freeze -and
    (Join-ExactValues -Values @(
        $closure.next_allowed_work.sealed_future_locomotion_seeds
    )) -ceq "26011|26012|26013|26014" -and
    [int]$closure.next_allowed_work.bw25y_expected_world_count -eq 28 -and
    [bool]$closure.next_allowed_work.bw25y_physical_locomotion_may_not_open_before_distinct_manifest_and_complete_policy_relative_zero_world_gate -and
    [bool]$closure.next_allowed_work.release_selected_policy_unchanged -and
    [bool]$closure.next_allowed_work.release_not_authorized
) "$gateId immutable next-work boundary changed"

$engineLogPath = Join-Path $evidenceRoot "engine.log"
$transcriptPath = Join-Path $evidenceRoot "transcript.log"
$prepublicationStdoutPath = Join-Path (
    $evidenceRoot
) "verification\prepublication-conformance.stdout.log"
$publicationStdoutPath = Join-Path (
    $evidenceRoot
) "verification\publication-supervisor.stdout.log"
$publicationStderrPath = Join-Path (
    $evidenceRoot
) "verification\publication-supervisor.stderr.log"
Assert-Exact (
    @(Select-String -LiteralPath $engineLogPath `
        -Pattern '^SDK_MATERIAL_PROFILE_RECEIPT ').Count -eq 1 -and
    @(Select-String -LiteralPath $engineLogPath `
        -Pattern '^SDK Godot/Jolt P5M\.2 material-profile summary: 46 passed, 0 failed$').Count -eq 1 -and
    @(Select-String -LiteralPath $transcriptPath `
        -Pattern '^SDK_MATERIAL_PROFILE_RECEIPT ').Count -eq 1 -and
    @(Select-String -LiteralPath $prepublicationStdoutPath `
        -Pattern '^SDK C0/C1 conformance passed\.$').Count -eq 1 -and
    @(Select-String -LiteralPath $publicationStdoutPath `
        -Pattern '^BW24P-PROFILE RETAINED_REPORT_PASS profiles=35 bw24m_profiles=3 gates=46 worlds=0 samples=0 commands=0 ').Count -eq 1 -and
    @(Select-String -LiteralPath $publicationStdoutPath `
        -Pattern '^BW24P-PROFILE PUBLICATION_COMPLETE profiles=35 prior_profiles=32 bw24m_profiles=3 gates=46 worlds=0 samples=0 commands=0 attempt_contract=True bw25y_manifest_next=True material_robustness=False physical_authority=False ').Count -eq 1 -and
    (Get-Item -LiteralPath $publicationStderrPath).Length -eq 0
) "$gateId retained terminal markers changed"

$attemptFiles = @(
    Get-ChildItem -LiteralPath $evidenceBase -Recurse -File -Filter "attempt.json" |
        Where-Object {
            try {
                $candidate = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$candidate.campaign_id -ceq $campaignId
            } catch {
                $false
            }
        }
)
Assert-Exact (
    $attemptFiles.Count -eq 1 -and
    [System.IO.Path]::GetFullPath($attemptFiles[0].FullName) -ceq $attemptPath
) "$gateId retained publication attempt cardinality changed"

& pwsh -NoProfile -File $predecessorClosureAuditPath
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId predecessor publication closure audit failed"
& pwsh -NoProfile -File $characterizationClosureAuditPath
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId material characterization closure audit failed"

$rerunRoot = Join-Path (
    $sdkRoot
) ("target\bw24p-closure-rerun-canary-" + [Guid]::NewGuid().ToString("N"))
$rerunOutput = (& pwsh -NoProfile -File $supervisorPath `
    -Publish -OutputRoot $rerunRoot 2>&1 | Out-String)
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
    "BW24P_PROFILE_CLOSURE_PASS status=positive profiles=35 " +
    "prior_profiles=32 bw24m_profiles=3 adapter_starts=36 gates=46 " +
    "worlds=0 samples=0 commands=0 artifacts=13 rerun_refused=True " +
    "profile_published=True bw25y_manifest=True " +
    "material_robustness=False physical_authority=False"
)
