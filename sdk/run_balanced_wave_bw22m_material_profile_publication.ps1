#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$Publish,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_bw22m_profile_publication_preflight"
    ),
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "BW22M-BW21L-FRESH-MATERIAL-PROFILE-PUBLICATION"
$gateId = "BW22M-PROFILE"
$implementationParentCommit = "de92b10a275c682dd9a6fc18be6408a24acf2c50"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw22m_material_profile_publication_preregistration.json"
$profilesPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_material_profiles.gd"
$profileTestPath = Join-Path (
    $repoRoot
) "tests\test_sdk_godot_jolt_material_profiles.gd"
$runnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_bw22m_material_profile_conformance.ps1"
$characterizationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw22m_material_characterization_closure.json"
$characterizationClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw22m_material_characterization_closure.ps1"
$priorProfileClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_profile_publication_closure.json"
$priorProfileClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw20f_material_profile_publication_closure.ps1"
$adapterPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_adapter.gd"
$canonicalJsonPath = Join-Path $repoRoot "scripts\lab\canonical_json.gd"
$publicationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw22m_material_profile_publication_closure.json"
$characterizationReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw22m-material-characterization-ff9a2cc\report.json"
)
$priorProfileReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw20f-material-profiles-cf9431e\report.json"
)
$expectedHashes = [ordered]@{
    $preregistrationPath = "8eb4a3c0cf77388c7592cb91219a9556653e26ba44d7432eb61f32b105019f72"
    $profilesPath = "fb82020d55798f62c8e9d0d30bcca4b60f0fa3688bd5410edc930df95eaaac1f"
    $profileTestPath = "8c2691823a440deaaf2550cba64e9298e2034da4bfffa3ab8466682aecc4c64f"
    $runnerPath = "d5933ca3fbc2218a524309149a23432a033a2b1334b9ed052549ba78e8038a2e"
    $characterizationClosurePath = "86e309bf68098338b570884429d608ac659916690c21b00f2c6077c4a35b09e6"
    $characterizationClosureAuditPath = "ad9e6f3dae4012536b00bf2cb9428f9cfaac17750550aabaa586e4d6d7fba3ac"
    $priorProfileClosurePath = "d5e08e0602f745e78b1c34cc10a95f1399a969f9ccab0fd62ff68f6a53e25f1e"
    $priorProfileClosureAuditPath = "9a874751b36a49da594ee1b10eea400ecfc5f91ca53350b566400ffa784417fc"
    $adapterPath = "3cf17ad6acaf791cc7bcc9c80d1e5d0f9e55749676f637da708080354241c0b3"
    $canonicalJsonPath = "b1f0f4df813663008824d223165577e281bffb97e81080d33d77c1ffb031501f"
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

function Write-NewJsonArtifact {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    Assert-Exact (
        -not (Test-Path -LiteralPath $Path)
    ) "Refusing to overwrite a $gateId artifact: $Path"
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $temporaryPath = $Path + ".tmp"
    Assert-Exact (
        -not (Test-Path -LiteralPath $temporaryPath)
    ) "Refusing stale $gateId temporary artifact: $temporaryPath"
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        (($Value | ConvertTo-Json -Depth 40) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporaryPath -Destination $Path
}

Assert-Exact (
    [bool]$PreflightOnly -xor [bool]$Publish
) "Specify exactly one of -PreflightOnly or -Publish"
if ($Publish) {
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($OutputRoot)
    ) "$gateId -Publish requires an explicit durable OutputRoot"
    Assert-Exact (
        -not (Test-Path -LiteralPath $publicationClosurePath -PathType Leaf)
    ) "$gateId publication is already closed and may not rerun"
}

foreach ($entry in $expectedHashes.GetEnumerator()) {
    Assert-Exact (
        (Test-Path -LiteralPath $entry.Key -PathType Leaf) -and
        (Get-RawSha256 -Path $entry.Key) -ceq [string]$entry.Value
    ) "$gateId frozen source or evidence changed: $($entry.Key)"
}

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$profiles = @($preregistration.profiles)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw22m_material_profile_publication_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw22m_profile_publication_receipt" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [int]$preregistration.world_build_count -eq 0 -and
    [int]$preregistration.locomotion_seed_world_count -eq 0 -and
    [int]$preregistration.expected_conformance.prior_profile_count -eq 29 -and
    [int]$preregistration.expected_conformance.bw22m_profile_count -eq 3 -and
    [int]$preregistration.expected_conformance.total_profile_count -eq 32 -and
    [int]$preregistration.expected_conformance.adapter_start_count -eq 33 -and
    [int]$preregistration.expected_conformance.passed_gate_count -eq 43 -and
    [int]$preregistration.expected_conformance.failed_gate_count -eq 0 -and
    $profiles.Count -eq 3 -and
    (@($profiles | ForEach-Object { [string]$_.profile_id }) -join "|") -ceq
        ($expectedProfileIds -join "|") -and
    (@($profiles | ForEach-Object {
        [string]$_.expected_profile_sha256
    }) -join "|") -ceq ($expectedProfileSha256 -join "|") -and
    [bool]$preregistration.staged_interlocks.sealed_locomotion_seeds_may_not_open_during_profile_publication -and
    (@($preregistration.staged_interlocks.sealed_future_locomotion_seeds) -join ",") -ceq
        "24011,24012,24013,24014" -and
    [bool]$preregistration.prerequisite_evidence.material_characterization_closure.post_closure_full_conformance_passed -and
    [string]$preregistration.prerequisite_evidence.material_characterization_closure.post_closure_full_conformance_source_commit -ceq
        "607eee4b0d88374c89678b8425870de02756fee3" -and
    -not [bool]$preregistration.claims.profile_published -and
    -not [bool]$preregistration.claims.walking_acceptance -and
    -not [bool]$preregistration.claims.friction_or_material_locomotion_robustness -and
    -not [bool]$preregistration.claims.continuous_friction_coverage -and
    -not [bool]$preregistration.claims.cross_engine_equivalence -and
    -not [bool]$preregistration.claims.physical_acceptance_authority
) "$gateId preregistration or claim boundary changed"

& pwsh -NoProfile -File $characterizationClosureAuditPath
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId characterization closure audit failed"
& pwsh -NoProfile -File $priorProfileClosureAuditPath
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId prior profile closure audit failed"

$godotPath = [System.IO.Path]::GetFullPath($Godot)
Assert-Exact (
    (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
    (Get-RawSha256 -Path $godotPath) -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
) "$gateId pinned Godot executable is missing or changed"
$godotVersion = (& $godotPath --version).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $godotVersion -ceq "4.7.stable.mono.official.5b4e0cb0f"
) "$gateId pinned Godot version changed"

# This complete path compiles and validates all 32 immutable profiles. Its
# receipt must prove zero worlds, samples, commands, and locomotion seeds.
& $runnerPath `
    -Godot $godotPath `
    -Bw22mCharacterization $characterizationReportPath `
    -PriorProfileReport $priorProfileReportPath `
    -LogRoot $LogRoot
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId complete zero-world gate failed"

if ($PreflightOnly) {
    Write-Host (
        "$gateId PREFLIGHT_PASS profiles=32 prior_profiles=29 " +
        "bw22m_profiles=3 gates=43 adapter_starts=33 worlds=0 samples=0 " +
        "commands=0 locomotion_seeds_opened=0 physical_authority=False"
    )
    return
}

$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$evidencePrefix = $evidenceRoot.TrimEnd("\") + "\"
Assert-Exact (
    $resolvedOutputRoot.StartsWith(
        $evidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId OutputRoot must be inside $evidenceRoot"
Assert-Exact (
    -not $resolvedOutputRoot.StartsWith(
        "C:\tmp\",
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId retained evidence may not use C:\tmp"
Assert-Exact (
    -not (Test-Path -LiteralPath $resolvedOutputRoot)
) "$gateId OutputRoot already exists: $resolvedOutputRoot"

$sourceStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMainCommit = (& git -C $repoRoot rev-parse origin/main).Trim()
$remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$remoteMainCommit = ($remoteLine -split "\s+")[0]
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $sourceStatus.Count -eq 0 -and
    $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
    $sourceCommit -cne $implementationParentCommit -and
    $sourceCommit -ceq $originMainCommit -and
    $sourceCommit -ceq $remoteMainCommit
) "$gateId requires clean source with HEAD equal to live GitHub main"
$expectedLeaf = "balanced-wave-bw22m-material-profiles-" +
    $sourceCommit.Substring(0, 7)
Assert-Exact (
    (Split-Path -Leaf $resolvedOutputRoot) -ceq $expectedLeaf
) "$gateId OutputRoot must be named $expectedLeaf"

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
                $candidate = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$candidate.campaign_id -ceq $campaignId
            } catch {
                $false
            }
        }
    )
}
Assert-Exact (
    $priorAttempts.Count -eq 0
) "$gateId already has a retained publication attempt and may not rerun"

[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)
$attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
$attempt = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw22m_material_profile_publication_attempt_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    launched_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    origin_main_commit = $originMainCommit
    remote_main_commit = $remoteMainCommit
    source_worktree_clean = $true
    source_matches_live_github_main = $true
    godot_version = $godotVersion
    godot_executable_sha256 = Get-RawSha256 -Path $godotPath
    preregistration_raw_sha256 = Get-RawSha256 -Path $preregistrationPath
    characterization_closure_raw_sha256 =
        Get-RawSha256 -Path $characterizationClosurePath
    characterization_report_raw_sha256 =
        Get-RawSha256 -Path $characterizationReportPath
    prior_profile_closure_raw_sha256 =
        Get-RawSha256 -Path $priorProfileClosurePath
    prior_profile_report_raw_sha256 =
        Get-RawSha256 -Path $priorProfileReportPath
    complete_zero_world_gate_passed = $true
    expected_profile_count = 32
    expected_gate_count = 43
    expected_world_count = 0
    expected_sample_count = 0
    expected_command_count = 0
    locomotion_seed_world_count = 0
    publication_identity_consumed = $true
    same_identity_rerun_allowed = $false
    physical_acceptance_authority = $false
}
Write-NewJsonArtifact -Value $attempt -Path $attemptPath

$reportPath = Join-Path $resolvedOutputRoot "report.json"
$publicationLogRoot = Join-Path $resolvedOutputRoot "worker"
& $runnerPath `
    -Godot $godotPath `
    -Bw22mCharacterization $characterizationReportPath `
    -PriorProfileReport $priorProfileReportPath `
    -LogRoot $publicationLogRoot `
    -Output $reportPath `
    -PublicationAuthorized `
    -PublicationAttempt $attemptPath
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    (Test-Path -LiteralPath $reportPath -PathType Leaf)
) "$gateId publication did not produce its retained report"

$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable
$receipt = $report.receipt
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
    [bool]$receipt.ok -and
    [int]$receipt.passed_gate_count -eq 43 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.observed_profile_count -eq 32 -and
    [int]$receipt.bw22m_profile_count -eq 3 -and
    [int]$receipt.observed_adapter_start_count -eq 33 -and
    [int]$receipt.observed_world_count -eq 0 -and
    [int]$receipt.observed_sample_count -eq 0 -and
    [int]$receipt.observed_command_count -eq 0 -and
    (@($receipt.profile_ids | Select-Object -Last 3) -join "|") -ceq
        ($expectedProfileIds -join "|") -and
    (@($receipt.profile_sha256 | Select-Object -Last 3) -join "|") -ceq
        ($expectedProfileSha256 -join "|") -and
    [bool]$receipt.bw22m_fresh_material_profile_publication -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.locomotion_robustness -and
    -not [bool]$receipt.continuous_friction_coverage -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.completed_engine_neutral_sdk
) "$gateId retained report failed exact reconciliation"

$completionPath = Join-Path $resolvedOutputRoot "completion.json"
$completion = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw22m_material_profile_publication_completion_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    completed_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    report_path = "report.json"
    report_raw_sha256 = "sha256:" + (Get-RawSha256 -Path $reportPath)
    accepted = $true
    profile_count = 32
    prior_profile_count = 29
    bw22m_profile_count = 3
    passed_gate_count = 43
    failed_gate_count = 0
    world_build_count = 0
    locomotion_seed_world_count = 0
    same_identity_rerun_allowed = $false
    physical_acceptance_authority = $false
}
Write-NewJsonArtifact -Value $completion -Path $completionPath

Write-Host (
    "$gateId PUBLICATION_COMPLETE profiles=32 prior_profiles=29 " +
    "bw22m_profiles=3 gates=43 worlds=0 samples=0 commands=0 " +
    "bw22l_manifest_next=True material_robustness=False " +
    "physical_authority=False report=$reportPath"
)
