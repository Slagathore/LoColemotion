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
        Join-Path $env:TEMP "sporespore_bw20f_profile_publication_preflight"
    ),
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
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
$characterizationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_characterization_closure.json"
$characterizationClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw20f_material_characterization_closure.ps1"
$adapterPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_adapter.gd"
$canonicalJsonPath = Join-Path $repoRoot "scripts\lab\canonical_json.gd"
$publicationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_profile_publication_closure.json"
$characterizationReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw20f-material-characterization-476aa4e\report.json"
)
$expectedHashes = [ordered]@{
    $preregistrationPath = "07eef222b7aba50b1963db54f6ef80710359be2c4e4a38fd7af0c62c8d791372"
    $profilesPath = "6344363c1218a85ffd5bed79b00e9615a74456f31787c2a8e5c48272e044255d"
    $profileTestPath = "cdb8548fd6da8b176b292bf614fdf89eafcf6557a6e3b1991a405b73c9e6c12e"
    $genericRunnerPath = "f179b9fdabcd367ccf137f88ffe311dc399868ff650e8bf63ec91797dccb4683"
    $characterizationClosurePath = "68d1ba699d1dcfd9b190423fd542b18843823374cdd8f69029c4e05548e3bf2a"
    $characterizationClosureAuditPath = "6d2d18a916052a3199dbdc753476fe9742852963ef892789ba956cee7418c2b6"
    $adapterPath = "5cf58a7d89a385b3cf9e37c62a6d27f2e13f6f644a0bcbe9d972ce70d274d2b1"
    $canonicalJsonPath = "b1f0f4df813663008824d223165577e281bffb97e81080d33d77c1ffb031501f"
    $characterizationReportPath = "f0a279fb9660554a0d4997c6b8adb5c767bc3f92f2497694448429f142155030"
}
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
$declaredProfiles = @($preregistration.profiles)
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
    [int]$preregistration.expected_conformance.total_profile_count -eq 29 -and
    [int]$preregistration.expected_conformance.bw20f_profile_count -eq 4 -and
    [int]$preregistration.expected_conformance.passed_gate_count -eq 40 -and
    [int]$preregistration.expected_conformance.failed_gate_count -eq 0 -and
    $declaredProfiles.Count -eq 4 -and
    (@($declaredProfiles | ForEach-Object {
        [string]$_.profile_id
    }) -join "|") -ceq ($expectedProfileIds -join "|") -and
    (@($declaredProfiles | ForEach-Object {
        [string]$_.expected_profile_sha256
    }) -join "|") -ceq ($expectedProfileSha256 -join "|") -and
    -not [bool]$preregistration.claims.profile_published -and
    -not [bool]$preregistration.claims.walking_acceptance -and
    -not [bool]$preregistration.claims.friction_or_material_locomotion_robustness -and
    -not [bool]$preregistration.claims.continuous_friction_coverage -and
    -not [bool]$preregistration.claims.portable_material_coefficient -and
    -not [bool]$preregistration.claims.cross_engine_equivalence -and
    -not [bool]$preregistration.claims.release_authorized -and
    -not [bool]$preregistration.claims.physical_acceptance_authority
) "$gateId preregistration identity, matrix, or claim boundary changed"

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

# The generic runner's complete 40-gate path is executed before any retained
# publication attempt. It constructs no physics world and writes no source.
& $genericRunnerPath `
    -Godot $godotPath `
    -Bw20fCharacterization $characterizationReportPath `
    -LogRoot $LogRoot
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId complete zero-world profile gate failed"

if ($PreflightOnly) {
    Write-Host (
        "$gateId PREFLIGHT_PASS profiles=29 bw20f_profiles=4 gates=40 " +
        "adapter_starts=30 worlds=0 samples=0 commands=0 " +
        "locomotion_seeds_opened=0 physical_authority=False"
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
$expectedLeaf = "balanced-wave-bw20f-material-profiles-" +
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

[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)
$attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
$attempt = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw20f_material_profile_publication_attempt_v1"
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
    complete_zero_world_gate_passed = $true
    expected_profile_count = 29
    expected_gate_count = 40
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
& $genericRunnerPath `
    -Godot $godotPath `
    -Bw20fCharacterization $characterizationReportPath `
    -LogRoot $publicationLogRoot `
    -Output $reportPath `
    -Bw20fPublicationAuthorized `
    -Bw20fPublicationAttempt $attemptPath
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    (Test-Path -LiteralPath $reportPath -PathType Leaf)
) "$gateId publication did not produce its retained report"

$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable
$receipt = $report.receipt
Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_godot_jolt_material_profile_report_v1" -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.source_worktree_clean -and
    [bool]$report.source_matches_origin_main -and
    [bool]$report.accepted -and
    [string]$report.result_status -ceq "passed" -and
    [int]$report.godot_exit_code -eq 0 -and
    [bool]$receipt.ok -and
    [int]$receipt.passed_gate_count -eq 40 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.observed_profile_count -eq 29 -and
    [int]$receipt.bw20f_profile_count -eq 4 -and
    [int]$receipt.observed_adapter_start_count -eq 30 -and
    [int]$receipt.observed_world_count -eq 0 -and
    [int]$receipt.observed_sample_count -eq 0 -and
    [int]$receipt.observed_command_count -eq 0 -and
    (@($receipt.profile_ids | Select-Object -Last 4) -join "|") -ceq
        ($expectedProfileIds -join "|") -and
    (@($receipt.profile_sha256 | Select-Object -Last 4) -join "|") -ceq
        ($expectedProfileSha256 -join "|") -and
    [bool]$receipt.bw20f_cold_successor_profile_publication -and
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
        "sporespore_balanced_wave_bw20f_material_profile_publication_completion_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    completed_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    report_path = "report.json"
    report_raw_sha256 = "sha256:" + (Get-RawSha256 -Path $reportPath)
    accepted = $true
    profile_count = 29
    bw20f_profile_count = 4
    passed_gate_count = 40
    failed_gate_count = 0
    world_build_count = 0
    locomotion_seed_world_count = 0
    same_identity_rerun_allowed = $false
    physical_acceptance_authority = $false
}
Write-NewJsonArtifact -Value $completion -Path $completionPath

Write-Host (
    "$gateId PUBLICATION_COMPLETE profiles=29 bw20f_profiles=4 gates=40 " +
    "worlds=0 samples=0 commands=0 stage3_manifest_next=True " +
    "material_robustness=False physical_authority=False report=$reportPath"
)
