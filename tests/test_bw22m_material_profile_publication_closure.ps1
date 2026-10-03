#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$evidenceBase = Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"
$campaignId = "BW22M-BW21L-FRESH-MATERIAL-PROFILE-PUBLICATION"
$gateId = "BW22M-PROFILE"
$sourceCommit = "7776dc8f14efa4ee29c2c3ca75b71744d99a4147"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw22m_material_profile_publication_closure.json"
$expectedClosureSha256 =
    "09a7f017a85f9bfe53c6f707985bd9b87083cee564168bf0311d8b57d8b787e9"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw22m_material_profile_publication.ps1"
$characterizationClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw22m_material_characterization_closure.ps1"
$priorProfileClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw20f_material_profile_publication_closure.ps1"
$priorProfileReportPath = Join-Path (
    $evidenceBase
) "balanced-wave-bw20f-material-profiles-cf9431e\report.json"
$expectedPriorProfileReportSha256 =
    "96ef9fd50da7e92b668d9552ebf821d8fe02fa8ab0a2247b93cda0a48115968f"
$expectedProfileIds = @(
    "godot_jolt_bw22m_mu057_v1",
    "godot_jolt_bw22m_mu069_v1",
    "godot_jolt_bw22m_mu081_v1"
)
$expectedProfileSha256 = @(
    "sha256:754c2f45b19dea315bd3527db8b8b87041be57cb7e4999412710d82c7c57903f",
    "sha256:a66f00fb0836a0838ab20e3f54c531ee5e9a6ea50180780e81e4f6106aad5ff3",
    "sha256:9446ba227a7a80f7592ffb7e358b8903a4e7afeb7297d5ba94dab87be8e33cbd"
)
$expectedAuthoredFriction = @(0.57, 0.69, 0.81)
$expectedControllerCoefficient = @(0.56, 0.68, 0.79)
$expectedMinimumLowerRatio = @(
    0.5609241215877279,
    0.6884900746592023,
    0.7905503689593908
)
$expectedBrackets = @(
    "22|23;22|23;22|23",
    "27|28;27|28;27|28",
    "31|33;31|33;31|33"
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

function Invoke-ExpectedFailure {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$ExpectedText,
        [Parameter(Mandatory)][string]$Label
    )
    $output = (& pwsh @Arguments 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
    Assert-Exact (
        $exitCode -ne 0 -and
        $output.Contains($ExpectedText, [StringComparison]::Ordinal)
    ) "$gateId $Label did not fail at the closed-state interlock"
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw22m_material_profile_publication_closure_v1" -and
    [string]$closure.status -ceq
        "closed_complete_valid_positive_deterministic_zero_world_profile_publication" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.study_classification -ceq
        "deterministic_zero_world_adapter_profile_publication" -and
    [string]$closure.publication_source_commit -ceq $sourceCommit -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.profile_record_or_retained_report_rewrite_allowed
) "$gateId closure identity or immutability changed"

$lifecycle = $closure.publication_lifecycle
Assert-Exact (
    [int]$lifecycle.supervisor_invocation_count -eq 2 -and
    [int]$lifecycle.pre_attempt_source_drift_refusal_count -eq 1 -and
    [int]$lifecycle.identity_consuming_attempt_count -eq 1 -and
    [int]$lifecycle.pre_attempt_zero_world_gate_count -eq 2 -and
    [int]$lifecycle.retained_report_zero_world_gate_count -eq 1 -and
    [int]$lifecycle.total_profile_conformance_execution_count -eq 3 -and
    [bool]$lifecycle.report_retained -and
    [int]$lifecycle.expected_profile_count -eq 32 -and
    [int]$lifecycle.observed_profile_count -eq 32 -and
    [int]$lifecycle.prior_profile_count -eq 29 -and
    [int]$lifecycle.bw22m_profile_count -eq 3 -and
    [int]$lifecycle.expected_adapter_start_count -eq 33 -and
    [int]$lifecycle.observed_adapter_start_count -eq 33 -and
    [int]$lifecycle.expected_gate_count -eq 43 -and
    [int]$lifecycle.passed_gate_count -eq 43 -and
    [int]$lifecycle.failed_gate_count -eq 0 -and
    [int]$lifecycle.world_build_count -eq 0 -and
    [int]$lifecycle.sample_count -eq 0 -and
    [int]$lifecycle.command_count -eq 0 -and
    [int]$lifecycle.locomotion_seed_world_count -eq 0 -and
    [bool]$lifecycle.accepted
) "$gateId publication lifecycle cardinality changed"

$refusals = @($closure.pre_attempt_refusals)
Assert-Exact ($refusals.Count -eq 1) "$gateId pre-attempt refusal count changed"
$refusal = $refusals[0]
Assert-Exact (
    [string]$refusal.source_commit -ceq
        "16d82b942ac84c7c33edc6c4a960ad3fd04c9f0f" -and
    [string]$refusal.stage_reached -ceq
        "complete_zero_world_preflight_before_clean_live_source_interlock" -and
    [string]$refusal.reason -ceq
        "worktree_became_dirty_from_concurrent_bootstrap_edits" -and
    -not [bool]$refusal.source_worktree_clean_at_interlock -and
    -not [bool]$refusal.evidence_root_created -and
    -not [bool]$refusal.attempt_artifact_created -and
    -not [bool]$refusal.report_created -and
    [int]$refusal.world_build_count -eq 0 -and
    -not [bool]$refusal.publication_identity_consumed -and
    [bool]$refusal.retry_from_new_clean_pushed_source_permitted
) "$gateId pre-attempt source-drift refusal changed"

Assert-Exact (
    $closure.frozen_source_blobs.Count -eq 14
) "$gateId frozen source binding count changed"
& git -C $repoRoot cat-file -e "$sourceCommit^{commit}"
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

    # The source-commit blob is permanent authority. raw_sha256 remains the
    # historical checkout receipt and is not compared with today's filtered path.
}

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
Assert-Exact (
    $evidenceRoot -ceq
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw22m-material-profiles-7776dc8"
) "$gateId retained evidence root changed"
$artifactBindings = @(
    $closure.retained_evidence.GetEnumerator() |
    Where-Object { $_.Key -cne "root" }
)
Assert-Exact (
    $artifactBindings.Count -eq 8
) "$gateId retained evidence binding count changed"
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
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw22m_material_profile_publication_attempt_v1" -and
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
        "8eb4a3c0cf77388c7592cb91219a9556653e26ba44d7432eb61f32b105019f72" -and
    [string]$attempt.characterization_closure_raw_sha256 -ceq
        "86e309bf68098338b570884429d608ac659916690c21b00f2c6077c4a35b09e6" -and
    [string]$attempt.characterization_report_raw_sha256 -ceq
        "cfce09d78192aaf280f44e4ec310e0c5760c687892b5f8b3d346cbaa13a1c03c" -and
    [string]$attempt.prior_profile_closure_raw_sha256 -ceq
        "d5e08e0602f745e78b1c34cc10a95f1399a969f9ccab0fd62ff68f6a53e25f1e" -and
    [string]$attempt.prior_profile_report_raw_sha256 -ceq
        $expectedPriorProfileReportSha256 -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [int]$attempt.expected_profile_count -eq 32 -and
    [int]$attempt.expected_gate_count -eq 43 -and
    [int]$attempt.expected_world_count -eq 0 -and
    [int]$attempt.expected_sample_count -eq 0 -and
    [int]$attempt.expected_command_count -eq 0 -and
    [int]$attempt.locomotion_seed_world_count -eq 0 -and
    [bool]$attempt.publication_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    -not [bool]$attempt.physical_acceptance_authority
) "$gateId retained attempt receipt changed"

Assert-Exact (
    [string]$completion.schema_version -ceq
        "sporespore_balanced_wave_bw22m_material_profile_publication_completion_v1" -and
    [string]$completion.campaign_id -ceq $campaignId -and
    [string]$completion.gate_id -ceq $gateId -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.report_path -ceq "report.json" -and
    [string]$completion.report_raw_sha256 -ceq
        "sha256:35cfe781bfdd87744b31dee20ce1102f16434d483e14e769d84571969e7010b0" -and
    [bool]$completion.accepted -and
    [int]$completion.profile_count -eq 32 -and
    [int]$completion.prior_profile_count -eq 29 -and
    [int]$completion.bw22m_profile_count -eq 3 -and
    [int]$completion.passed_gate_count -eq 43 -and
    [int]$completion.failed_gate_count -eq 0 -and
    [int]$completion.world_build_count -eq 0 -and
    [int]$completion.locomotion_seed_world_count -eq 0 -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId retained completion receipt changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_godot_jolt_bw22m_material_profile_report_v1" -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.source_worktree_clean -and
    [bool]$report.source_matches_origin_main -and
    [bool]$report.source_matches_live_github_main -and
    [bool]$report.accepted -and
    [string]$report.result_status -ceq "passed" -and
    [int]$report.godot_exit_code -eq 0 -and
    [string]$report.stopping_rule -ceq
        "zero_world_profile_conformance_after_bw22m_characterization_closure_before_bw22l_locomotion" -and
    [string]$report.godot.version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [string]$report.godot.executable_sha256 -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$report.godot.physics_engine -ceq "Jolt Physics" -and
    [int]$report.godot.physics_hz -eq 120 -and
    [int]$report.godot.solver_velocity_steps -eq 20 -and
    [int]$report.godot.solver_position_steps -eq 7
) "$gateId retained report identity or host changed"

$characterizationEvidence =
    $report.prerequisite_evidence.bw22m_material_characterization
$priorEvidence =
    $report.prerequisite_evidence.prior_material_profile_publication
Assert-Exact (
    [string]$characterizationEvidence.sha256 -ceq
        "cfce09d78192aaf280f44e4ec310e0c5760c687892b5f8b3d346cbaa13a1c03c" -and
    [string]$characterizationEvidence.source_commit -ceq
        "ff9a2cca466984e863ffb4c9063267231186618f" -and
    [string]$characterizationEvidence.closure_sha256 -ceq
        "86e309bf68098338b570884429d608ac659916690c21b00f2c6077c4a35b09e6" -and
    [bool]$characterizationEvidence.profile_publication_authorized -and
    [string]$priorEvidence.sha256 -ceq $expectedPriorProfileReportSha256 -and
    [string]$priorEvidence.closure_sha256 -ceq
        "d5e08e0602f745e78b1c34cc10a95f1399a969f9ccab0fd62ff68f6a53e25f1e" -and
    [int]$priorEvidence.prior_profile_count -eq 29 -and
    [bool]$priorEvidence.identities_unchanged
) "$gateId prerequisite evidence binding changed"

$expectedReportSources = [ordered]@{
    preregistration = "8eb4a3c0cf77388c7592cb91219a9556653e26ba44d7432eb61f32b105019f72"
    characterization_closure = "86e309bf68098338b570884429d608ac659916690c21b00f2c6077c4a35b09e6"
    characterization_closure_audit = "ad9e6f3dae4012536b00bf2cb9428f9cfaac17750550aabaa586e4d6d7fba3ac"
    prior_profile_closure = "d5e08e0602f745e78b1c34cc10a95f1399a969f9ccab0fd62ff68f6a53e25f1e"
    prior_profile_closure_audit = "9a874751b36a49da594ee1b10eea400ecfc5f91ca53350b566400ffa784417fc"
    profiles = "fb82020d55798f62c8e9d0d30bcca4b60f0fa3688bd5410edc930df95eaaac1f"
    adapter = "3cf17ad6acaf791cc7bcc9c80d1e5d0f9e55749676f637da708080354241c0b3"
    canonical_json = "b1f0f4df813663008824d223165577e281bffb97e81080d33d77c1ffb031501f"
    test = "8c2691823a440deaaf2550cba64e9298e2034da4bfffa3ab8466682aecc4c64f"
    runner = "d5933ca3fbc2218a524309149a23432a033a2b1334b9ed052549ba78e8038a2e"
}
Assert-Exact (
    $report.sources.Count -eq $expectedReportSources.Count
) "$gateId retained report source count changed"
foreach ($entry in $expectedReportSources.GetEnumerator()) {
    Assert-Exact (
        [string]$report.sources[$entry.Key].sha256 -ceq [string]$entry.Value
    ) "$gateId retained report source changed: $($entry.Key)"
}
Assert-Exact (
    [string]$report.transcript.path -ceq "transcript.log" -and
    [string]$report.transcript.sha256 -ceq
        "0cf7fe8dfba73e4eab93da812cf47c1c759e86f20df216687bafb325bda2891c" -and
    [string]$report.engine_log.path -ceq "engine.log" -and
    [string]$report.engine_log.sha256 -ceq
        "36156a609d7bcc443c51293639154e0ff6fcb04af5cfdfb5b04c5af5b8fc23f6"
) "$gateId retained report log binding changed"

Assert-Exact (
    [bool]$receipt.ok -and
    [int]$receipt.expected_profile_count -eq 32 -and
    [int]$receipt.observed_profile_count -eq 32 -and
    [int]$receipt.bw20f_profile_count -eq 4 -and
    [int]$receipt.bw22m_profile_count -eq 3 -and
    [int]$receipt.expected_adapter_start_count -eq 33 -and
    [int]$receipt.observed_adapter_start_count -eq 33 -and
    [int]$receipt.expected_gate_count -eq 43 -and
    [int]$receipt.passed_gate_count -eq 43 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_world_count -eq 0 -and
    [int]$receipt.observed_world_count -eq 0 -and
    [int]$receipt.observed_sample_count -eq 0 -and
    [int]$receipt.observed_command_count -eq 0 -and
    [bool]$receipt.bw22m_fresh_material_profile_publication -and
    -not [bool]$receipt.adapter_actuation_applied -and
    -not [bool]$receipt.physics_transform_or_velocity_written -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.locomotion_robustness -and
    -not [bool]$receipt.continuous_friction_coverage -and
    -not [bool]$receipt.rough_terrain_robustness -and
    -not [bool]$receipt.external_push_recovery -and
    -not [bool]$receipt.sensor_fault_robustness -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.completed_engine_neutral_sdk
) "$gateId retained profile receipt or claim boundary changed"

$allProfileIds = @($receipt.profile_ids)
$allProfileDigests = @($receipt.profile_sha256)
Assert-Exact (
    $allProfileIds.Count -eq 32 -and
    $allProfileDigests.Count -eq 32 -and
    @($allProfileIds | Select-Object -Unique).Count -eq 32 -and
    @($allProfileDigests | Select-Object -Unique).Count -eq 32 -and
    (@($allProfileIds | Select-Object -Last 3) -join "|") -ceq
        ($expectedProfileIds -join "|") -and
    (@($allProfileDigests | Select-Object -Last 3) -join "|") -ceq
        ($expectedProfileSha256 -join "|")
) "$gateId retained profile identities or canonical digests changed"

Assert-Exact (
    (Test-Path -LiteralPath $priorProfileReportPath -PathType Leaf) -and
    (Get-RawSha256 -Path $priorProfileReportPath) -ceq
        $expectedPriorProfileReportSha256
) "$gateId prior profile report is missing or changed"
$priorReport = Get-Content -Raw -LiteralPath $priorProfileReportPath |
    ConvertFrom-Json -AsHashtable
$priorReceipt = $priorReport.receipt
Assert-Exact (
    [bool]$priorReport.accepted -and
    [bool]$priorReceipt.ok -and
    [int]$priorReceipt.observed_profile_count -eq 29 -and
    (@($allProfileIds | Select-Object -First 29) -join "|") -ceq
        (@($priorReceipt.profile_ids) -join "|") -and
    (@($allProfileDigests | Select-Object -First 29) -join "|") -ceq
        (@($priorReceipt.profile_sha256) -join "|")
) "$gateId first 29 profile identities diverged from the closed predecessor"

$closedResult = $closure.result
Assert-Exact (
    [bool]$closedResult.accepted -and
    [string]$closedResult.result_status -ceq "passed" -and
    [string]$closedResult.profile_schema_version -ceq
        "sporespore_adapter_material_profile_v1" -and
    [int]$closedResult.total_profile_count -eq 32 -and
    [int]$closedResult.prior_profile_count -eq 29 -and
    [int]$closedResult.bw22m_profile_count -eq 3 -and
    [int]$closedResult.adapter_start_count -eq 33 -and
    [int]$closedResult.passed_gate_count -eq 43 -and
    [int]$closedResult.failed_gate_count -eq 0 -and
    [int]$closedResult.world_build_count -eq 0 -and
    [int]$closedResult.sample_count -eq 0 -and
    [int]$closedResult.command_count -eq 0
) "$gateId closed result cardinality changed"
$closureProfiles = @($closedResult.profiles)
Assert-Exact ($closureProfiles.Count -eq 3) "$gateId closure profile count changed"
for ($index = 0; $index -lt $closureProfiles.Count; $index++) {
    $profile = $closureProfiles[$index]
    $brackets = @($profile.replicate_breakaway_brackets_n | ForEach-Object {
        (@($_) -join "|")
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
    ) "$gateId closed profile row $index changed"
}

$disposition = $closure.scientific_disposition
Assert-Exact (
    [bool]$disposition.complete_valid_positive_deterministic_zero_world_profile_publication -and
    [bool]$disposition.profile_published -and
    [bool]$disposition.bw22l_manifest_freeze_authorized -and
    -not [bool]$disposition.locomotion_outcome_observed -and
    -not [bool]$disposition.future_locomotion_seeds_opened -and
    -not [bool]$disposition.walking_acceptance -and
    -not [bool]$disposition.friction_or_material_locomotion_robustness -and
    -not [bool]$disposition.continuous_friction_coverage -and
    -not [bool]$disposition.portable_material_coefficient -and
    -not [bool]$disposition.cross_engine_equivalence -and
    -not [bool]$disposition.release_authorized -and
    -not [bool]$disposition.physical_acceptance_authority -and
    -not [bool]$disposition.completed_engine_neutral_sdk
) "$gateId closed scientific disposition changed"
Assert-Exact (
    [bool]$closure.immutability.publication_attempt_report_and_logs_may_not_be_rewritten -and
    [bool]$closure.immutability.profile_ids_values_coefficients_provenance_and_digests_may_not_change -and
    [bool]$closure.immutability.same_campaign_identity_may_not_publish_again -and
    [bool]$closure.immutability.bw22l_requires_a_new_source_preregistration_gate_and_evidence_identity -and
    [bool]$closure.next_allowed_work.bw22m_stage_2_is_closed -and
    [bool]$closure.next_allowed_work.distinct_bw22l_manifest_may_now_freeze -and
    (@($closure.next_allowed_work.sealed_future_locomotion_seeds) -join ",") -ceq
        "24011,24012,24013,24014" -and
    [int]$closure.next_allowed_work.bw22l_expected_world_count -eq 28 -and
    [bool]$closure.next_allowed_work.bw22l_physical_locomotion_may_not_open_before_distinct_manifest_and_complete_policy_relative_zero_world_gate -and
    [bool]$closure.next_allowed_work.release_selected_policy_unchanged -and
    [bool]$closure.next_allowed_work.release_not_authorized
) "$gateId immutability or next-stage boundary changed"

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
) "$gateId must retain exactly one identity-consuming publication attempt"

& pwsh -NoProfile -File $characterizationClosureAuditPath
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId characterization closure audit failed"
& pwsh -NoProfile -File $priorProfileClosureAuditPath
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId prior profile closure audit failed"

$rerunCanaryRoot = Join-Path (
    $evidenceBase
) "balanced-wave-bw22m-material-profiles-rerun-canary"
Assert-Exact (
    -not (Test-Path -LiteralPath $rerunCanaryRoot)
) "$gateId rerun canary root already exists"
Invoke-ExpectedFailure @(
    "-NoProfile",
    "-File", $supervisorPath,
    "-Publish",
    "-OutputRoot", $rerunCanaryRoot
) "$gateId publication is already closed and may not rerun" `
    "same-identity-rerun"
Assert-Exact (
    -not (Test-Path -LiteralPath $rerunCanaryRoot)
) "$gateId closed-state canary unexpectedly created an artifact root"

Write-Host (
    "BW22M_PROFILE_CLOSURE_PASS status=positive profiles=32 " +
    "prior_profiles=29 bw22m_profiles=3 gates=43 worlds=0 samples=0 " +
    "commands=0 pre_attempt_refusals=1 rerun_refused=True " +
    "bw22l_manifest=True material_robustness=False " +
    "physical_authority=False"
)
