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
$campaignId = "BW20F-BW19V-COLD-MATERIAL-PROFILE-PUBLICATION"
$gateId = "BW20F-PROFILE"
$sourceCommit = "cf9431e7b45fdbff50af8d8f386c19bb85b4fc5f"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_profile_publication_closure.json"
$expectedClosureSha256 =
    "d5e08e0602f745e78b1c34cc10a95f1399a969f9ccab0fd62ff68f6a53e25f1e"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw20f_material_profile_publication.ps1"
$expectedProfileIds = @(
    "godot_jolt_bw20f_mu009_v1",
    "godot_jolt_bw20f_mu037_v1",
    "godot_jolt_bw20f_mu076_v1",
    "godot_jolt_bw20f_mu118_v1"
)
$expectedProfileSha256 = @(
    "sha256:92891cfbed2b30c5d6c72fa02a30770fcf75880416a92fe2f69d9ece8246ee55",
    "sha256:690e5c2f035a7a3efc32fa31c86cfab03299f8c539500e110b5ddf9e35b6dfb9",
    "sha256:76f42bc89da95e09d081d17d5e3aa520de25fa6a352067dd8c30ace3834667b0",
    "sha256:e0c6a6d78ae63a129e7ae44088aeb86da44941dba8cfcfd5680f73a236c9b297"
)
$expectedAuthoredFriction = @(0.09, 0.37, 0.76, 1.18)
$expectedControllerCoefficient = @(0.07, 0.35, 0.73, 1.0)

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
        "sporespore_balanced_wave_bw20f_material_profile_publication_closure_v1" -and
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

$publicationAttempt = $closure.publication_attempt
Assert-Exact (
    [int]$publicationAttempt.supervisor_invocation_count -eq 1 -and
    [int]$publicationAttempt.pre_attempt_zero_world_gate_count -eq 1 -and
    [int]$publicationAttempt.retained_report_zero_world_gate_count -eq 1 -and
    [int]$publicationAttempt.total_profile_conformance_execution_count -eq 2 -and
    [bool]$publicationAttempt.report_retained -and
    [int]$publicationAttempt.expected_profile_count -eq 29 -and
    [int]$publicationAttempt.observed_profile_count -eq 29 -and
    [int]$publicationAttempt.bw20f_profile_count -eq 4 -and
    [int]$publicationAttempt.expected_adapter_start_count -eq 30 -and
    [int]$publicationAttempt.observed_adapter_start_count -eq 30 -and
    [int]$publicationAttempt.expected_gate_count -eq 40 -and
    [int]$publicationAttempt.passed_gate_count -eq 40 -and
    [int]$publicationAttempt.failed_gate_count -eq 0 -and
    [int]$publicationAttempt.world_build_count -eq 0 -and
    [int]$publicationAttempt.sample_count -eq 0 -and
    [int]$publicationAttempt.command_count -eq 0 -and
    [int]$publicationAttempt.locomotion_seed_world_count -eq 0 -and
    [bool]$publicationAttempt.accepted
) "$gateId publication attempt cardinality changed"

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
    # raw_sha256 records the historical Windows checkout receipt. It is not
    # reinterpreted through today's checkout filters; the pinned blob above is
    # the retained source identity.
}

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
Assert-Exact (
    $evidenceRoot -ceq
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw20f-material-profiles-cf9431e"
) "$gateId retained evidence root changed"
foreach ($artifact in @($closure.retained_evidence.Values)) {
    if ($artifact -is [string]) {
        continue
    }
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
        "sporespore_balanced_wave_bw20f_material_profile_publication_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [int]$attempt.expected_profile_count -eq 29 -and
    [int]$attempt.expected_gate_count -eq 40 -and
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
        "sporespore_balanced_wave_bw20f_material_profile_publication_completion_v1" -and
    [string]$completion.campaign_id -ceq $campaignId -and
    [string]$completion.gate_id -ceq $gateId -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.report_path -ceq "report.json" -and
    [string]$completion.report_raw_sha256 -ceq
        "sha256:96ef9fd50da7e92b668d9552ebf821d8fe02fa8ab0a2247b93cda0a48115968f" -and
    [bool]$completion.accepted -and
    [int]$completion.profile_count -eq 29 -and
    [int]$completion.bw20f_profile_count -eq 4 -and
    [int]$completion.passed_gate_count -eq 40 -and
    [int]$completion.failed_gate_count -eq 0 -and
    [int]$completion.world_build_count -eq 0 -and
    [int]$completion.locomotion_seed_world_count -eq 0 -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId retained completion receipt changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_godot_jolt_material_profile_report_v1" -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.source_worktree_clean -and
    [bool]$report.source_matches_origin_main -and
    [bool]$report.accepted -and
    [string]$report.result_status -ceq "passed" -and
    [int]$report.godot_exit_code -eq 0 -and
    [string]$report.stopping_rule -ceq
        "zero_world_profile_conformance_after_bw20f_characterization_closure_before_stage3_locomotion" -and
    [string]$report.godot.version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [string]$report.godot.executable_sha256 -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$report.godot.physics_engine -ceq "Jolt Physics" -and
    [int]$report.godot.physics_hz -eq 120 -and
    [int]$report.godot.solver_velocity_steps -eq 20 -and
    [int]$report.godot.solver_position_steps -eq 7
) "$gateId retained report identity or host changed"

Assert-Exact (
    [bool]$receipt.ok -and
    [int]$receipt.expected_profile_count -eq 29 -and
    [int]$receipt.observed_profile_count -eq 29 -and
    [int]$receipt.bw20f_profile_count -eq 4 -and
    [int]$receipt.expected_adapter_start_count -eq 30 -and
    [int]$receipt.observed_adapter_start_count -eq 30 -and
    [int]$receipt.expected_gate_count -eq 40 -and
    [int]$receipt.passed_gate_count -eq 40 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_world_count -eq 0 -and
    [int]$receipt.observed_world_count -eq 0 -and
    [int]$receipt.observed_sample_count -eq 0 -and
    [int]$receipt.observed_command_count -eq 0 -and
    [bool]$receipt.bw20f_cold_successor_profile_publication -and
    -not [bool]$receipt.adapter_actuation_applied -and
    -not [bool]$receipt.physics_transform_or_velocity_written -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.locomotion_robustness -and
    -not [bool]$receipt.continuous_friction_coverage -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.completed_engine_neutral_sdk
) "$gateId retained profile receipt or claim boundary changed"
Assert-Exact (
    (@($receipt.profile_ids | Select-Object -Last 4) -join "|") -ceq
        ($expectedProfileIds -join "|") -and
    (@($receipt.profile_sha256 | Select-Object -Last 4) -join "|") -ceq
        ($expectedProfileSha256 -join "|") -and
    @($receipt.profile_ids | Select-Object -Unique).Count -eq 29 -and
    @($receipt.profile_sha256 | Select-Object -Unique).Count -eq 29
) "$gateId retained profile identities or canonical digests changed"

$closureProfiles = @($closure.result.profiles)
Assert-Exact ($closureProfiles.Count -eq 4) "$gateId closure profile count changed"
for ($index = 0; $index -lt $closureProfiles.Count; $index++) {
    $profile = $closureProfiles[$index]
    Assert-Exact (
        [string]$profile.profile_id -ceq $expectedProfileIds[$index] -and
        [double]$profile.authored_friction -eq
            $expectedAuthoredFriction[$index] -and
        [double]$profile.characterized_friction_coefficient -eq
            $expectedControllerCoefficient[$index] -and
        [string]$profile.profile_sha256 -ceq
            $expectedProfileSha256[$index]
    ) "$gateId closed profile row $index changed"
}

$disposition = $closure.scientific_disposition
Assert-Exact (
    [bool]$disposition.complete_valid_positive_deterministic_zero_world_profile_publication -and
    [bool]$disposition.profile_published -and
    [bool]$disposition.stage_3_manifest_freeze_authorized -and
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

$attemptFiles = @(
    Get-ChildItem `
        -LiteralPath (Split-Path -Parent $repoRoot) `
        -Recurse `
        -File `
        -Filter "attempt.json" |
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
) "$gateId must retain exactly one publication attempt"

$rerunCanaryRoot = Join-Path (
    (Split-Path -Parent $repoRoot)
) "SporeSpore_Evidence\balanced-wave-bw20f-material-profiles-rerun-canary"
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
    "BW20F_PROFILE_CLOSURE_PASS status=positive profiles=29 " +
    "bw20f_profiles=4 gates=40 worlds=0 samples=0 commands=0 " +
    "rerun_refused=True stage3_manifest=True " +
    "material_robustness=False physical_authority=False"
)
