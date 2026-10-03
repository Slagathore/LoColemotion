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
        Join-Path $env:TEMP "sporespore_bw24m_profile_publication_preflight"
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
$campaignId = "BW24M-BW23Y-FRESH-MATERIAL-PROFILE-PUBLICATION"
$gateId = "BW24M-PROFILE"
$implementationParentCommit = "4867738514d0426b97ba60ec1ffb9a524f396d62"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24m_material_profile_publication_preregistration.json"
$profilesPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_material_profiles.gd"
$profileTestPath = Join-Path (
    $repoRoot
) "tests\test_sdk_godot_jolt_material_profiles.gd"
$runnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_bw24m_material_profile_conformance.ps1"
$characterizationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24m_material_characterization_closure.json"
$characterizationClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw24m_material_characterization_closure.ps1"
$priorProfileClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw22m_material_profile_publication_closure.json"
$priorProfileClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw22m_material_profile_publication_closure.ps1"
$adapterPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_adapter.gd"
$canonicalJsonPath = Join-Path $repoRoot "scripts\lab\canonical_json.gd"
$publicationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24m_material_profile_publication_closure.json"
$characterizationReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw24m-material-characterization-730fa10\report.json"
)
$priorProfileReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw22m-material-profiles-7776dc8\report.json"
)
$expectedHashes = [ordered]@{
    $preregistrationPath = "1c1b7b1197f2ab452d3d35b64cdd121c3d2e0f271ae49d18cd650759d15bce20"
    $profilesPath = "1f83f1941984506f48782caa3564506ea3e88b5a84d283f740b34585ae72dc8a"
    $profileTestPath = "a1e21cffc556d74077412960fbed5875286c0daf0a03a3b6df8e58c6d283a784"
    $runnerPath = "09374a9afdfad8603cb84b63ff40aaa7d59bcd457cbd83c2f7c0fa9ed5a2e131"
    $characterizationClosurePath = "92a5aa2498e1260139f5ab36dd63663628084f3a8b83d1588250d20299ebbee2"
    $characterizationClosureAuditPath = "b41e2431d8c8af82017a2c0805ef1115cf5072beef6079e8a5760e8572ca6a2e"
    $priorProfileClosurePath = "09a7f017a85f9bfe53c6f707985bd9b87083cee564168bf0311d8b57d8b787e9"
    $priorProfileClosureAuditPath = "b7e5ee4bc814ff23fd598fb548dd1003e2b5dbe7fddc6653c41552285c20ce1d"
    $adapterPath = "f9221b3872af64809266525a182db9ac52c373f4e9dc894d8c1ad165b73b31bc"
    $canonicalJsonPath = "b1f0f4df813663008824d223165577e281bffb97e81080d33d77c1ffb031501f"
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
        "sporespore_balanced_wave_bw24m_material_profile_publication_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw24m_profile_publication_receipt" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [int]$preregistration.world_build_count -eq 0 -and
    [int]$preregistration.locomotion_seed_world_count -eq 0 -and
    [int]$preregistration.expected_conformance.prior_profile_count -eq 32 -and
    [int]$preregistration.expected_conformance.bw24m_profile_count -eq 3 -and
    [int]$preregistration.expected_conformance.total_profile_count -eq 35 -and
    [int]$preregistration.expected_conformance.adapter_start_count -eq 36 -and
    [int]$preregistration.expected_conformance.passed_gate_count -eq 46 -and
    [int]$preregistration.expected_conformance.failed_gate_count -eq 0 -and
    $profiles.Count -eq 3 -and
    (@($profiles | ForEach-Object { [string]$_.profile_id }) -join "|") -ceq
        ($expectedProfileIds -join "|") -and
    (@($profiles | ForEach-Object {
        [string]$_.expected_profile_sha256
    }) -join "|") -ceq ($expectedProfileSha256 -join "|") -and
    [bool]$preregistration.staged_interlocks.sealed_locomotion_seeds_may_not_open_during_profile_publication -and
    (@($preregistration.staged_interlocks.sealed_future_locomotion_seeds) -join ",") -ceq
        "26011,26012,26013,26014" -and
    [bool]$preregistration.prerequisite_evidence.material_characterization_closure.post_closure_full_conformance_passed -and
    [string]$preregistration.prerequisite_evidence.material_characterization_closure.post_closure_full_conformance_source_commit -ceq
        "4867738514d0426b97ba60ec1ffb9a524f396d62" -and
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

# This complete path compiles and validates all 35 immutable profiles. Its
# receipt must prove zero worlds, samples, commands, and locomotion seeds.
& $runnerPath `
    -Godot $godotPath `
    -Bw24mCharacterization $characterizationReportPath `
    -PriorProfileReport $priorProfileReportPath `
    -LogRoot $LogRoot
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId complete zero-world gate failed"

if ($PreflightOnly) {
    Write-Host (
        "$gateId PREFLIGHT_PASS profiles=35 prior_profiles=32 " +
        "bw24m_profiles=3 gates=46 adapter_starts=36 worlds=0 samples=0 " +
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
$expectedLeaf = "balanced-wave-bw24m-material-profiles-" +
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
        "sporespore_balanced_wave_bw24m_material_profile_publication_attempt_v1"
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
    -Bw24mCharacterization $characterizationReportPath `
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
        "sporespore_godot_jolt_bw24m_material_profile_report_v1" -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.source_worktree_clean -and
    [bool]$report.source_matches_origin_main -and
    [bool]$report.source_matches_live_github_main -and
    [bool]$report.accepted -and
    [string]$report.result_status -ceq "passed" -and
    [int]$report.godot_exit_code -eq 0 -and
    [bool]$receipt.ok -and
    [int]$receipt.passed_gate_count -eq 46 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.observed_profile_count -eq 35 -and
    [int]$receipt.bw24m_profile_count -eq 3 -and
    [int]$receipt.observed_adapter_start_count -eq 36 -and
    [int]$receipt.observed_world_count -eq 0 -and
    [int]$receipt.observed_sample_count -eq 0 -and
    [int]$receipt.observed_command_count -eq 0 -and
    (@($receipt.profile_ids | Select-Object -Last 3) -join "|") -ceq
        ($expectedProfileIds -join "|") -and
    (@($receipt.profile_sha256 | Select-Object -Last 3) -join "|") -ceq
        ($expectedProfileSha256 -join "|") -and
    [bool]$receipt.bw24m_fresh_material_profile_publication -and
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
        "sporespore_balanced_wave_bw24m_material_profile_publication_completion_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    completed_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    report_path = "report.json"
    report_raw_sha256 = "sha256:" + (Get-RawSha256 -Path $reportPath)
    accepted = $true
    profile_count = 35
    prior_profile_count = 32
    bw24m_profile_count = 3
    passed_gate_count = 46
    failed_gate_count = 0
    world_build_count = 0
    locomotion_seed_world_count = 0
    same_identity_rerun_allowed = $false
    physical_acceptance_authority = $false
}
Write-NewJsonArtifact -Value $completion -Path $completionPath

Write-Host (
    "$gateId PUBLICATION_COMPLETE profiles=35 prior_profiles=32 " +
    "bw24m_profiles=3 gates=46 worlds=0 samples=0 commands=0 " +
    "bw25y_manifest_next=True material_robustness=False " +
    "physical_authority=False report=$reportPath"
)
