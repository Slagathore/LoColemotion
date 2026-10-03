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
$gateId = "BW24M-PROFILE"
$campaignId = "BW24M-BW23Y-FRESH-MATERIAL-PROFILE-PUBLICATION"
$implementationParentCommit = "4867738514d0426b97ba60ec1ffb9a524f396d62"
$preregistrationPath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw24m_material_profile_publication_preregistration.json"
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
) "sdk\run_godot_jolt_bw24m_material_profile_conformance.ps1"
$supervisorPath = Join-Path (
    $repoRoot
) "sdk\run_balanced_wave_bw24m_material_profile_publication.ps1"
$characterizationClosurePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw24m_material_characterization_closure.json"
$characterizationClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw24m_material_characterization_closure.ps1"
$priorProfileClosurePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw22m_material_profile_publication_closure.json"
$priorProfileClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw22m_material_profile_publication_closure.ps1"
$publicationClosurePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw24m_material_profile_publication_closure.json"
$characterizationReportPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw24m-material-characterization-730fa10\report.json"
)
$priorProfileReportPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw22m-material-profiles-7776dc8\report.json"
)
$expectedHashes = [ordered]@{
    $preregistrationPath = "1c1b7b1197f2ab452d3d35b64cdd121c3d2e0f271ae49d18cd650759d15bce20"
    $profilesPath = "1f83f1941984506f48782caa3564506ea3e88b5a84d283f740b34585ae72dc8a"
    $profileTestPath = "a1e21cffc556d74077412960fbed5875286c0daf0a03a3b6df8e58c6d283a784"
    $genericRunnerPath = "bfa13dcb0e4bb89560a8b604a42b0541ab4b85eddf4c2a1698926799965d2bce"
    $successorRunnerPath = "09374a9afdfad8603cb84b63ff40aaa7d59bcd457cbd83c2f7c0fa9ed5a2e131"
    $supervisorPath = "11ae6ba0863460c90ac6ee4b8721568b438b064fc148e60568594ee5443f24d2"
    $characterizationClosurePath = "92a5aa2498e1260139f5ab36dd63663628084f3a8b83d1588250d20299ebbee2"
    $characterizationClosureAuditPath = "b41e2431d8c8af82017a2c0805ef1115cf5072beef6079e8a5760e8572ca6a2e"
    $priorProfileClosurePath = "09a7f017a85f9bfe53c6f707985bd9b87083cee564168bf0311d8b57d8b787e9"
    $priorProfileClosureAuditPath = "b7e5ee4bc814ff23fd598fb548dd1003e2b5dbe7fddc6653c41552285c20ce1d"
    $characterizationReportPath = "141d31074e1422228e7e4b91a1f25c80c7a076e99d59cc2aad83c499d86ece9b"
    $priorProfileReportPath = "35cfe781bfdd87744b31dee20ce1102f16434d483e14e769d84571969e7010b0"
}
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
        "sporespore_balanced_wave_bw24m_material_profile_publication_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw24m_profile_publication_receipt" -and
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
        "4867738514d0426b97ba60ec1ffb9a524f396d62"
) "$gateId preregistration identity or prerequisite boundary changed"
Assert-Exact (
    [int]$conformance.prior_profile_count -eq 32 -and
    [int]$conformance.bw24m_profile_count -eq 3 -and
    [int]$conformance.total_profile_count -eq 35 -and
    [int]$conformance.adapter_start_count -eq 36 -and
    [int]$conformance.passed_gate_count -eq 46 -and
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
    [bool]$interlocks.bw25y_manifest_may_not_freeze_until_profile_publication_closes_positive -and
    [bool]$interlocks.bw25y_physical_world_may_not_open_until_distinct_complete_policy_relative_synthetic_gate_passes -and
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
    'const BW24M_PROFILE_IDS := [',
    '"godot_jolt_bw24m_mu059_v1"',
    '"godot_jolt_bw24m_mu071_v1"',
    '"godot_jolt_bw24m_mu083_v1"',
    'result.append_array(BW24M_PROFILE_IDS)'
) "profile registry"
Assert-SourceContains $testSource @(
    'const EXPECTED_GATE_COUNT := 46',
    'var observed_world_count := 0',
    'var observed_sample_count := 0',
    'var observed_command_count := 0',
    '"bw24m_profile_count": MaterialProfilesScript.BW24M_PROFILE_IDS.size()',
    '"physical_acceptance_authority": false'
) "profile test"
Assert-SourceContains $genericSource @(
    '[int]$receipt.observed_profile_count -eq 35',
    '[int]$receipt.observed_world_count -eq 0',
    'BW24M retained publication requires the distinct',
    'run_godot_jolt_bw24m_material_profile_conformance.ps1 route'
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

if ($SkipSupervisorPreflight) {
    # The supervisor runs these same prerequisite audits itself. Only execute
    # them here when the caller explicitly skips that complete preflight.
    & pwsh -NoProfile -File $characterizationClosureAuditPath
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId characterization closure audit failed"
    & pwsh -NoProfile -File $priorProfileClosureAuditPath
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId prior profile closure audit failed"
}

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
) "SporeSpore_Evidence\balanced-wave-bw24m-material-profiles-freeze-canary"
Assert-Exact (
    -not (Test-Path -LiteralPath $canaryRoot)
) "$gateId canary root already exists"
if (-not $SkipGodotExecution) {
    Invoke-ExpectedFailure @(
        "-NoProfile",
        "-File", $genericRunnerPath,
        "-Output", (Join-Path $canaryRoot "report.json"),
        "-Bw24mPublicationAuthorized"
    ) "BW24M retained publication requires the distinct" "generic-bypass"
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
    "BW24M_PROFILE_FREEZE_PASS profiles=35 prior_profiles=32 " +
    "bw24m_profiles=3 gates=46 worlds=0 samples=0 commands=0 " +
    "canaries=4 supervisor_preflight=$supervisorPreflightExecuted " +
    "profile_published=False locomotion_seeds_opened=0 " +
    "material_robustness=False physical_authority=False"
)
