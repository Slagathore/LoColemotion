#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipGodotExecution,
    [switch]$SkipSupervisorPreflight
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$gateId = "BW22M-PROFILE"
$campaignId = "BW22M-BW21L-FRESH-MATERIAL-PROFILE-PUBLICATION"
$implementationParentCommit = "de92b10a275c682dd9a6fc18be6408a24acf2c50"
$preregistrationPath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw22m_material_profile_publication_preregistration.json"
$profilesPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_material_profiles.gd"
$profileTestPath = Join-Path (
    $repoRoot
) "tests\test_sdk_godot_jolt_material_profiles.gd"
$genericRunnerPath = Join-Path (
    $repoRoot
) "sdk\run_godot_jolt_material_profile_conformance.ps1"
$successorRunnerPath = Join-Path (
    $repoRoot
) "sdk\run_godot_jolt_bw22m_material_profile_conformance.ps1"
$supervisorPath = Join-Path (
    $repoRoot
) "sdk\run_balanced_wave_bw22m_material_profile_publication.ps1"
$characterizationClosurePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw22m_material_characterization_closure.json"
$characterizationClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw22m_material_characterization_closure.ps1"
$priorProfileClosurePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw20f_material_profile_publication_closure.json"
$priorProfileClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw20f_material_profile_publication_closure.ps1"
$publicationClosurePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw22m_material_profile_publication_closure.json"
$characterizationReportPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw22m-material-characterization-ff9a2cc\report.json"
)
$priorProfileReportPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw20f-material-profiles-cf9431e\report.json"
)
$expectedHashes = [ordered]@{
    $preregistrationPath = "8eb4a3c0cf77388c7592cb91219a9556653e26ba44d7432eb61f32b105019f72"
    $profilesPath = "fb82020d55798f62c8e9d0d30bcca4b60f0fa3688bd5410edc930df95eaaac1f"
    $profileTestPath = "8c2691823a440deaaf2550cba64e9298e2034da4bfffa3ab8466682aecc4c64f"
    $genericRunnerPath = "b1f829cc6a84275bc94cd7d7ed931ed194ef18f37c026e136d61308bb3beff16"
    $successorRunnerPath = "d5933ca3fbc2218a524309149a23432a033a2b1334b9ed052549ba78e8038a2e"
    $supervisorPath = "6050415931bb97197c2d0e09f9f61747527e78a93f414e8fe459cd77fd607cdf"
    $characterizationClosurePath = "86e309bf68098338b570884429d608ac659916690c21b00f2c6077c4a35b09e6"
    $characterizationClosureAuditPath = "ad9e6f3dae4012536b00bf2cb9428f9cfaac17750550aabaa586e4d6d7fba3ac"
    $priorProfileClosurePath = "d5e08e0602f745e78b1c34cc10a95f1399a969f9ccab0fd62ff68f6a53e25f1e"
    $priorProfileClosureAuditPath = "9a874751b36a49da594ee1b10eea400ecfc5f91ca53350b566400ffa784417fc"
    $characterizationReportPath = "cfce09d78192aaf280f44e4ec310e0c5760c687892b5f8b3d346cbaa13a1c03c"
    $priorProfileReportPath = "96ef9fd50da7e92b668d9552ebf821d8fe02fa8ab0a2247b93cda0a48115968f"
}
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

function Assert-SourceContains {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string[]]$Needles,
        [Parameter(Mandatory)][string]$Label
    )
    foreach ($needle in $Needles) {
        Assert-Exact (
            $Source.Contains($needle, [StringComparison]::Ordinal)
        ) "$gateId $Label lost required surface: $needle"
    }
}

function Invoke-ExpectedFailure {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$ExpectedText,
        [Parameter(Mandatory)][string]$Label
    )
    $output = @(& pwsh @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    Assert-Exact ($exitCode -ne 0) "$gateId $Label unexpectedly passed"
    Assert-Exact (
        ($output -join "`n").Contains(
            $ExpectedText,
            [StringComparison]::Ordinal
        )
    ) "$gateId $Label failed for the wrong reason"
}

Assert-Exact (
    -not ($SkipGodotExecution -and -not $SkipSupervisorPreflight)
) "$gateId -SkipGodotExecution requires -SkipSupervisorPreflight"
foreach ($entry in $expectedHashes.GetEnumerator()) {
    Assert-Exact (
        (Test-Path -LiteralPath $entry.Key -PathType Leaf) -and
        (Get-RawSha256 -Path $entry.Key) -ceq [string]$entry.Value
    ) "$gateId frozen source or prerequisite changed: $($entry.Key)"
}
Assert-Exact (
    -not (Test-Path -LiteralPath $publicationClosurePath -PathType Leaf)
) "$gateId publication is already closed and is no longer prospective"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$profiles = @($preregistration.profiles)
$conformance = $preregistration.expected_conformance
$interlocks = $preregistration.staged_interlocks
$claims = $preregistration.claims
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw22m_material_profile_publication_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw22m_profile_publication_receipt" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [string]$preregistration.study_classification -ceq
        "deterministic_zero_world_adapter_profile_publication" -and
    [int]$preregistration.world_build_count -eq 0 -and
    [int]$preregistration.locomotion_seed_world_count -eq 0 -and
    [string]$preregistration.profile_schema_version -ceq
        "sporespore_adapter_material_profile_v1" -and
    [bool]$preregistration.prerequisite_evidence.material_characterization_closure.profile_publication_authorized -and
    [bool]$preregistration.prerequisite_evidence.material_characterization_closure.post_closure_full_conformance_passed -and
    [string]$preregistration.prerequisite_evidence.material_characterization_closure.post_closure_full_conformance_source_commit -ceq
        "607eee4b0d88374c89678b8425870de02756fee3"
) "$gateId preregistration identity or prerequisite boundary changed"
Assert-Exact (
    [int]$conformance.prior_profile_count -eq 29 -and
    [int]$conformance.bw22m_profile_count -eq 3 -and
    [int]$conformance.total_profile_count -eq 32 -and
    [int]$conformance.adapter_start_count -eq 33 -and
    [int]$conformance.passed_gate_count -eq 43 -and
    [int]$conformance.failed_gate_count -eq 0 -and
    [int]$conformance.world_build_count -eq 0 -and
    [int]$conformance.sample_count -eq 0 -and
    [int]$conformance.command_count -eq 0 -and
    [bool]$conformance.every_profile_digest_unique -and
    [bool]$conformance.all_prior_profile_ids_and_digests_unchanged -and
    [bool]$conformance.legacy_default_unchanged -and
    [bool]$conformance.unknown_profile_rejected -and
    [bool]$conformance.fixture_mismatch_rejected -and
    [bool]$conformance.solver_mismatch_rejected -and
    [bool]$conformance.record_tamper_rejected
) "$gateId conformance cardinality or negative controls changed"
Assert-Exact ($profiles.Count -eq 3) "$gateId profile count changed"
for ($index = 0; $index -lt $profiles.Count; $index++) {
    $profile = $profiles[$index]
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
        [string]$profile.expected_profile_sha256 -ceq
            $expectedProfileSha256[$index]
    ) "$gateId profile row $index changed"
}
Assert-Exact (
    [bool]$interlocks.publication_requires_clean_pushed_source_matching_live_github_main -and
    [bool]$interlocks.publication_requires_unused_source_named_durable_evidence_root -and
    [bool]$interlocks.publication_attempt_written_before_report_generation -and
    -not [bool]$interlocks.same_identity_rerun_allowed -and
    [bool]$interlocks.bw22l_manifest_may_not_freeze_until_profile_publication_closes_positive -and
    [bool]$interlocks.bw22l_physical_world_may_not_open_until_distinct_complete_policy_relative_synthetic_gate_passes -and
    [bool]$interlocks.sealed_locomotion_seeds_may_not_open_during_profile_publication
) "$gateId staged interlock changed"
foreach ($claimName in @(
    "deterministic_zero_world_profile_publication",
    "profile_published",
    "walking_acceptance",
    "friction_or_material_locomotion_robustness",
    "continuous_friction_coverage",
    "portable_material_coefficient",
    "cross_engine_equivalence",
    "release_authorized",
    "physical_acceptance_authority",
    "completed_engine_neutral_sdk"
)) {
    Assert-Exact (
        -not [bool]$claims[$claimName]
    ) "$gateId prospective claim inflated: $claimName"
}

$profilesSource = Get-Content -Raw -LiteralPath $profilesPath
$testSource = Get-Content -Raw -LiteralPath $profileTestPath
$genericSource = Get-Content -Raw -LiteralPath $genericRunnerPath
$successorSource = Get-Content -Raw -LiteralPath $successorRunnerPath
$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
Assert-SourceContains $profilesSource @(
    'const BW22M_PROFILE_IDS := [',
    '"godot_jolt_bw22m_mu057_v1"',
    '"godot_jolt_bw22m_mu069_v1"',
    '"godot_jolt_bw22m_mu081_v1"',
    'result.append_array(BW22M_PROFILE_IDS)'
) "profile registry"
Assert-SourceContains $testSource @(
    'const EXPECTED_GATE_COUNT := 43',
    'var observed_world_count := 0',
    'var observed_sample_count := 0',
    'var observed_command_count := 0',
    '"bw22m_profile_count": MaterialProfilesScript.BW22M_PROFILE_IDS.size()',
    '"physical_acceptance_authority": false'
) "profile test"
Assert-SourceContains $genericSource @(
    '[int]$receipt.observed_profile_count -eq 32',
    '[int]$receipt.observed_world_count -eq 0',
    'BW22M retained publication requires the distinct',
    'run_godot_jolt_bw22m_material_profile_conformance.ps1 route'
) "generic conformance"
Assert-SourceContains $successorSource @(
    '($priorIds -join "|") -ceq (@($priorReceipt.profile_ids) -join "|")',
    '($priorDigests -join "|") -ceq (@($priorReceipt.profile_sha256) -join "|")',
    '[int]$receipt.observed_world_count -eq 0',
    '[int]$receipt.observed_sample_count -eq 0',
    '[int]$receipt.observed_command_count -eq 0',
    'retained publication requires the supervisor''s sibling attempt receipt'
) "successor conformance"
Assert-SourceContains $supervisorSource @(
    '[bool]$PreflightOnly -xor [bool]$Publish',
    '$gateId -Publish requires an explicit durable OutputRoot',
    'complete_zero_world_gate_passed = $true',
    'locomotion_seed_world_count = 0',
    'publication_identity_consumed = $true',
    'same_identity_rerun_allowed = $false'
) "publication supervisor"

& pwsh -NoProfile -File $characterizationClosureAuditPath
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId characterization closure audit failed"
& pwsh -NoProfile -File $priorProfileClosureAuditPath
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId prior profile closure audit failed"

Invoke-ExpectedFailure @(
    "-NoProfile",
    "-File", $supervisorPath
) "Specify exactly one of -PreflightOnly or -Publish" "missing-mode"
Invoke-ExpectedFailure @(
    "-NoProfile",
    "-File", $supervisorPath,
    "-Publish"
) "$gateId -Publish requires an explicit durable OutputRoot" "missing-output"

$canaryRoot = Join-Path (
    (Split-Path -Parent $repoRoot)
) "SporeSpore_Evidence\balanced-wave-bw22m-material-profiles-freeze-canary"
Assert-Exact (
    -not (Test-Path -LiteralPath $canaryRoot)
) "$gateId canary root already exists"
if (-not $SkipGodotExecution) {
    Invoke-ExpectedFailure @(
        "-NoProfile",
        "-File", $genericRunnerPath,
        "-Output", (Join-Path $canaryRoot "report.json"),
        "-Bw22mPublicationAuthorized"
    ) "BW22M retained publication requires the distinct" "generic-bypass"
    Assert-Exact (
        -not (Test-Path -LiteralPath $canaryRoot)
    ) "$gateId generic bypass created retained evidence"
    Invoke-ExpectedFailure @(
        "-NoProfile",
        "-File", $successorRunnerPath,
        "-Output", (Join-Path $canaryRoot "report.json"),
        "-PublicationAuthorized"
    ) "retained publication requires the supervisor's sibling attempt receipt" `
        "missing-attempt-authority"
    Assert-Exact (
        -not (Test-Path -LiteralPath $canaryRoot)
    ) "$gateId successor bypass created retained evidence"
}

$supervisorPreflightExecuted = $false
if (-not $SkipSupervisorPreflight) {
    & pwsh -NoProfile -File $supervisorPath -PreflightOnly
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId complete supervisor preflight failed"
    $supervisorPreflightExecuted = $true
}

Write-Host (
    "BW22M_PROFILE_FREEZE_PASS profiles=32 prior_profiles=29 " +
    "bw22m_profiles=3 gates=43 worlds=0 samples=0 commands=0 " +
    "canaries=4 supervisor_preflight=$supervisorPreflightExecuted " +
    "profile_published=False locomotion_seeds_opened=0 " +
    "material_robustness=False physical_authority=False"
)
