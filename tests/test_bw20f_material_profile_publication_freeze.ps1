#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipGodotExecution,
    [switch]$SkipSupervisorPreflight,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_bw20f_profile_freeze_audit"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "BW20F-BW19V-COLD-MATERIAL-PROFILE-PUBLICATION"
$gateId = "BW20F-PROFILE"
$implementationParentCommit = "78c11e7abe3c33e95aa11398ce28632ff6b450f7"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_profile_publication_preregistration.json"
$profilesPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_material_profiles.gd"
$profileTestPath = Join-Path (
    $repoRoot
) "tests\test_sdk_godot_jolt_material_profiles.gd"
$genericRunnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_material_profile_conformance.ps1"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw20f_material_profile_publication.ps1"
$characterizationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_characterization_closure.json"
$characterizationClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw20f_material_characterization_closure.ps1"
$publicationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_profile_publication_closure.json"
$characterizationReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw20f-material-characterization-476aa4e\report.json"
)

$frozenFiles = [ordered]@{
    "sdk/balanced_wave_bw20f_material_profile_publication_preregistration.json" =
        "07eef222b7aba50b1963db54f6ef80710359be2c4e4a38fd7af0c62c8d791372"
    "scripts/lab/gait/sdk_godot_jolt_material_profiles.gd" =
        "6344363c1218a85ffd5bed79b00e9615a74456f31787c2a8e5c48272e044255d"
    "tests/test_sdk_godot_jolt_material_profiles.gd" =
        "cdb8548fd6da8b176b292bf614fdf89eafcf6557a6e3b1991a405b73c9e6c12e"
    "sdk/run_godot_jolt_material_profile_conformance.ps1" =
        "f179b9fdabcd367ccf137f88ffe311dc399868ff650e8bf63ec91797dccb4683"
    "sdk/run_balanced_wave_bw20f_material_profile_publication.ps1" =
        "80fbdc7fa54be64b3da594479568e9a4dfb1549b17ee13977f169f08cf5e74f9"
    "sdk/balanced_wave_bw20f_material_characterization_closure.json" =
        "68d1ba699d1dcfd9b190423fd542b18843823374cdd8f69029c4e05548e3bf2a"
    "tests/test_bw20f_material_characterization_closure.ps1" =
        "6d2d18a916052a3199dbdc753476fe9742852963ef892789ba956cee7418c2b6"
    "scripts/lab/gait/sdk_godot_jolt_adapter.gd" =
        "5cf58a7d89a385b3cf9e37c62a6d27f2e13f6f644a0bcbe9d972ce70d274d2b1"
    "scripts/lab/canonical_json.gd" =
        "b1f0f4df813663008824d223165577e281bffb97e81080d33d77c1ffb031501f"
}
$expectedReportSha256 =
    "f0a279fb9660554a0d4997c6b8adb5c767bc3f92f2497694448429f142155030"
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
$expectedMinimumLowerRatio = @(
    0.07647180229187284,
    0.35691676077326845,
    0.7395363279264746,
    1.1730118440718895
)
$expectedBrackets = @(
    "3,4|3,4|3,4",
    "14,15|14,15|14,15",
    "29,31|29,31|29,31",
    "46,47|46,47|46,47"
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
    $output = (& pwsh @Arguments 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
    Assert-Exact (
        $exitCode -ne 0 -and
        $output.Contains($ExpectedText, [StringComparison]::Ordinal)
    ) "$gateId $Label negative control did not fail closed"
}

function Convert-BracketsToKey {
    param([Parameter(Mandatory)][object[]]$Brackets)
    return (@(
        $Brackets | ForEach-Object {
            (@($_) | ForEach-Object { [double]$_ }) -join ","
        }
    ) -join "|")
}

Assert-Exact (
    -not ($SkipGodotExecution -and -not $SkipSupervisorPreflight)
) "$gateId -SkipGodotExecution requires -SkipSupervisorPreflight"

foreach ($entry in $frozenFiles.GetEnumerator()) {
    $path = Join-Path $repoRoot $entry.Key
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 -Path $path) -ceq [string]$entry.Value
    ) "$gateId frozen source or prerequisite changed: $($entry.Key)"
}
Assert-Exact (
    (Test-Path -LiteralPath $characterizationReportPath -PathType Leaf) -and
    (Get-RawSha256 -Path $characterizationReportPath) -ceq
        $expectedReportSha256
) "$gateId retained characterization report is missing or changed"
Assert-Exact (
    -not (Test-Path -LiteralPath $publicationClosurePath -PathType Leaf)
) "$gateId publication is already closed and is no longer prospective"

foreach ($scriptPath in @($genericRunnerPath, $supervisorPath)) {
    [void][scriptblock]::Create(
        (Get-Content -Raw -LiteralPath $scriptPath)
    )
}

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$profiles = @($preregistration.profiles)
$conformance = $preregistration.expected_conformance
$interlocks = $preregistration.staged_interlocks
$claims = $preregistration.claims
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_profile_publication_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw20f_profile_publication_receipt" -and
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
    $profiles.Count -eq 4
) "$gateId preregistration identity or zero-world boundary changed"

Assert-Exact (
    [int]$conformance.legacy_and_prior_profile_count -eq 25 -and
    [int]$conformance.bw20f_profile_count -eq 4 -and
    [int]$conformance.total_profile_count -eq 29 -and
    [int]$conformance.adapter_start_count -eq 30 -and
    [int]$conformance.passed_gate_count -eq 40 -and
    [int]$conformance.failed_gate_count -eq 0 -and
    [int]$conformance.world_build_count -eq 0 -and
    [int]$conformance.sample_count -eq 0 -and
    [int]$conformance.command_count -eq 0 -and
    [bool]$conformance.every_profile_digest_unique -and
    [bool]$conformance.legacy_default_unchanged -and
    [bool]$conformance.unknown_profile_rejected -and
    [bool]$conformance.fixture_mismatch_rejected -and
    [bool]$conformance.solver_mismatch_rejected -and
    [bool]$conformance.record_tamper_rejected
) "$gateId declared conformance cardinality or negative controls changed"

for ($index = 0; $index -lt $profiles.Count; $index++) {
    $profile = $profiles[$index]
    Assert-Exact (
        [string]$profile.profile_id -ceq $expectedProfileIds[$index] -and
        [double]$profile.authored_friction -eq
            $expectedAuthoredFriction[$index] -and
        [double]$profile.characterized_friction_coefficient -eq
            $expectedControllerCoefficient[$index] -and
        [double]$profile.minimum_lower_empirical_ratio -eq
            $expectedMinimumLowerRatio[$index] -and
        (Convert-BracketsToKey @(
            $profile.replicate_breakaway_brackets_n
        )) -ceq $expectedBrackets[$index] -and
        [string]$profile.expected_profile_sha256 -ceq
            $expectedProfileSha256[$index]
    ) "$gateId profile row $index changed"
}

$closure = Get-Content -Raw -LiteralPath $characterizationClosurePath |
    ConvertFrom-Json -AsHashtable
$closureCells = @($closure.result.cells)
Assert-Exact (
    [string]$closure.status -ceq
        "closed_complete_valid_positive_exact_finite_adapter_material_characterization" -and
    [string]$closure.campaign_id -ceq "BW20F-BW19V-COLD-MATERIAL" -and
    [string]$closure.physical_source_commit -ceq
        "476aa4ea521a519a6cd91ef12f265cdb26245839" -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    [bool]$closure.scientific_disposition.complete_valid_positive_exact_finite_characterization -and
    [bool]$closure.scientific_disposition.adapter_profile_publication_authorized -and
    -not [bool]$closure.scientific_disposition.locomotion_outcome_observed -and
    -not [bool]$closure.scientific_disposition.future_locomotion_seeds_opened -and
    -not [bool]$closure.scientific_disposition.material_robustness_established -and
    [int]$closure.physical_attempt.observed_world_count -eq 13 -and
    [int]$closure.physical_attempt.locomotion_world_count -eq 0 -and
    [int]$closure.physical_attempt.passed_gate_count -eq 23 -and
    [int]$closure.physical_attempt.failed_gate_count -eq 0 -and
    $closureCells.Count -eq 4
) "$gateId prerequisite characterization closure changed"
for ($index = 0; $index -lt $closureCells.Count; $index++) {
    $cell = $closureCells[$index]
    Assert-Exact (
        [double]$cell.authored_friction -eq
            $expectedAuthoredFriction[$index] -and
        [double]$cell.controller_mu -eq
            $expectedControllerCoefficient[$index] -and
        [double]$cell.minimum_lower_empirical_ratio -eq
            $expectedMinimumLowerRatio[$index] -and
        (Convert-BracketsToKey @(
            $cell.replicate_breakaway_brackets_n
        )) -ceq $expectedBrackets[$index] -and
        [bool]$cell.passed
    ) "$gateId prerequisite characterization cell $index changed"
}

Assert-Exact (
    [bool]$interlocks.publication_requires_clean_pushed_source_matching_live_github_main -and
    [bool]$interlocks.publication_requires_unused_source_named_durable_evidence_root -and
    [bool]$interlocks.publication_attempt_written_before_report_generation -and
    -not [bool]$interlocks.same_identity_rerun_allowed -and
    [bool]$interlocks.stage_3_manifest_may_not_freeze_until_profile_publication_closes_positive -and
    [bool]$interlocks.stage_3_physical_world_may_not_open_until_distinct_complete_synthetic_gate_passes
) "$gateId publication or stage-3 interlock changed"
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

$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
$genericRunnerSource = Get-Content -Raw -LiteralPath $genericRunnerPath
$profilesSource = Get-Content -Raw -LiteralPath $profilesPath
$profileTestSource = Get-Content -Raw -LiteralPath $profileTestPath
Assert-SourceContains $supervisorSource @(
    '[bool]$PreflightOnly -xor [bool]$Publish',
    '$gateId -Publish requires an explicit durable OutputRoot',
    'status --porcelain=v1 --untracked-files=all',
    'ls-remote origin refs/heads/main',
    'requires clean source with HEAD equal to live GitHub main',
    'SporeSpore_Evidence',
    'C:\tmp\',
    'publication_identity_consumed = $true',
    'same_identity_rerun_allowed = $false',
    'complete_zero_world_gate_passed = $true',
    '-Bw20fPublicationAuthorized',
    '-Bw20fPublicationAttempt $attemptPath',
    'world_build_count = 0',
    'locomotion_seed_world_count = 0'
) "supervisor"
Assert-SourceContains $genericRunnerSource @(
    'Retained BW20F material-profile publication requires the',
    "supervisor's exact sibling attempt receipt",
    'BW20F material-profile publication attempt receipt is invalid',
    'Refusing to retain evidence from a dirty worktree',
    'BW20F publication attempt/source commit mismatch',
    '[int]$receipt.observed_world_count -eq 0',
    '[int]$receipt.observed_sample_count -eq 0',
    '[int]$receipt.observed_command_count -eq 0',
    '-not [bool]$receipt.material_robustness',
    '-not [bool]$receipt.physical_acceptance_authority'
) "generic runner"
Assert-SourceContains $profilesSource @(
    'const BW20F_PROFILE_IDS := [',
    '"godot_jolt_bw20f_mu009_v1"',
    '"godot_jolt_bw20f_mu037_v1"',
    '"godot_jolt_bw20f_mu076_v1"',
    '"godot_jolt_bw20f_mu118_v1"',
    'result.append_array(BW20F_PROFILE_IDS)'
) "profile registry"
Assert-SourceContains $profileTestSource @(
    'const EXPECTED_GATE_COUNT := 40',
    'unique_digests.size() == EXPECTED_PROFILE_IDS.size()',
    'the adapter fails closed on an unknown profile before extension startup',
    'a selected profile fails closed when fixture material differs',
    'a selected profile fails closed when the realized solver policy differs',
    'a caller cannot alter an immutable resolved profile record',
    'var observed_world_count := 0',
    'var observed_sample_count := 0',
    'var observed_command_count := 0'
) "profile conformance"

$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$priorAttempts = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorAttempts = @(
        Get-ChildItem `
            -LiteralPath $evidenceRoot `
            -Recurse `
            -File `
            -Filter "attempt.json" |
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
) "$gateId already has a retained publication attempt and may not rerun"

$bypassCanariesExecuted = 0
$supervisorPreflightExecuted = $false
if (-not $SkipGodotExecution) {
    $godotPath = [System.IO.Path]::GetFullPath($Godot)
    Assert-Exact (
        (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
        (Get-RawSha256 -Path $godotPath) -ceq
            "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
    ) "$gateId pinned Godot executable is missing or changed"

    $canaryRoot = Join-Path (
        $env:TEMP
    ) ("sporespore_bw20f_profile_bypass_" + [Guid]::NewGuid().ToString("N"))
    $canaryReportPath = Join-Path $canaryRoot "report.json"
    $canaryAttemptPath = Join-Path $canaryRoot "attempt.json"

    Invoke-ExpectedFailure @(
        "-NoProfile",
        "-File", $supervisorPath,
        "-Publish"
    ) "$gateId -Publish requires an explicit durable OutputRoot" `
        "missing-output-root"
    $bypassCanariesExecuted++

    Invoke-ExpectedFailure @(
        "-NoProfile",
        "-File", $genericRunnerPath,
        "-Godot", $godotPath,
        "-Bw20fCharacterization", $characterizationReportPath,
        "-LogRoot", (Join-Path $LogRoot "direct-output"),
        "-Output", $canaryReportPath
    ) "supervisor's exact sibling attempt receipt" `
        "direct-output-bypass"
    $bypassCanariesExecuted++

    Invoke-ExpectedFailure @(
        "-NoProfile",
        "-File", $genericRunnerPath,
        "-Godot", $godotPath,
        "-Bw20fCharacterization", $characterizationReportPath,
        "-LogRoot", (Join-Path $LogRoot "forged-authorization"),
        "-Output", $canaryReportPath,
        "-Bw20fPublicationAuthorized",
        "-Bw20fPublicationAttempt", $canaryAttemptPath
    ) "supervisor's exact sibling attempt receipt" `
        "forged-authorization"
    $bypassCanariesExecuted++

    Assert-Exact (
        -not (Test-Path -LiteralPath $canaryRoot)
    ) "$gateId output bypass unexpectedly created a retained artifact root"

    if (-not $SkipSupervisorPreflight) {
        & pwsh `
            -NoProfile `
            -File $supervisorPath `
            -Godot $godotPath `
            -LogRoot (Join-Path $LogRoot "supervisor") `
            -PreflightOnly
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "$gateId complete zero-world supervisor preflight failed"
        $supervisorPreflightExecuted = $true
    }
}

Write-Host (
    "$gateId`_FREEZE_PASS profiles=29 bw20f_profiles=4 gates=40 " +
    "worlds=0 samples=0 commands=0 canaries=4 " +
    "profile_canaries_executed=$(-not $SkipGodotExecution) " +
    "bypass_canaries_declared=3 bypass_canaries_executed=" +
    "$bypassCanariesExecuted supervisor_preflight_executed=" +
    "$supervisorPreflightExecuted profile_published=False " +
    "material_robustness=False physical_authority=False"
)
