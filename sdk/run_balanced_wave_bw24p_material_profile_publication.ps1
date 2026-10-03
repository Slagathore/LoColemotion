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
        Join-Path $PSScriptRoot "target\bw24p-profile-publication-preflight"
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
$campaignId = "BW24P-BW24M-PROFILE-PUBLICATION-SUCCESSOR"
$gateId = "BW24P-PROFILE"
$implementationParentCommit = "4eb763aa673f7e21462ef4ef32c63a21f290f36e"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw24p_material_profile_publication.ps1"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24p_material_profile_publication_preregistration.json"
$runnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_bw24p_material_profile_conformance.ps1"
$baseRunnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_bw24m_material_profile_conformance.ps1"
$predecessorClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24m_material_profile_publication_closure.json"
$predecessorClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw24m_material_profile_publication_closure.ps1"
$profileRegistryPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_material_profiles.gd"
$profileTestPath = Join-Path (
    $repoRoot
) "tests\test_sdk_godot_jolt_material_profiles.gd"
$publicationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24p_material_profile_publication_closure.json"
$expectedHashes = [ordered]@{
    $preregistrationPath = "f4cda32a4f996b0df234a1f398f08f45e74fef8f362acdb2c2641ddf3d2de67a"
    $runnerPath = "65dc4c92372653529870180afd35fa7f4344b0d05ed6ed1f86e1de69c6a022a9"
    $baseRunnerPath = "09374a9afdfad8603cb84b63ff40aaa7d59bcd457cbd83c2f7c0fa9ed5a2e131"
    $predecessorClosurePath = "f2921cb510b8283316f7c00bef4ff17492806f5d671c459efdde87b4a79eb0f0"
    $predecessorClosureAuditPath = "8cefa67e1578f2168d050f8cbbbc0a4119c45a3eeccbec271528c43ef7e9ef19"
    $profileRegistryPath = "1f83f1941984506f48782caa3564506ea3e88b5a84d283f740b34585ae72dc8a"
    $profileTestPath = "a1e21cffc556d74077412960fbed5875286c0daf0a03a3b6df8e58c6d283a784"
}

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

function New-AttemptRecord {
    param(
        [Parameter(Mandatory)][bool]$Synthetic,
        [string]$SourceCommit = "",
        [string]$GodotVersion = "4.7.stable.mono.official.5b4e0cb0f",
        [string]$GodotSha256 =
            "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
    )
    $resolvedSource = if ($Synthetic) {
        "synthetic_preflight_no_source_identity"
    } else {
        $SourceCommit
    }
    return [ordered]@{
        schema_version =
            "sporespore_balanced_wave_bw24p_material_profile_publication_attempt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        launched_at_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $resolvedSource
        origin_main_commit = if ($Synthetic) { "" } else { $SourceCommit }
        remote_main_commit = if ($Synthetic) { "" } else { $SourceCommit }
        source_worktree_clean = -not $Synthetic
        source_matches_live_github_main = -not $Synthetic
        godot_version = $GodotVersion
        godot_executable_sha256 = $GodotSha256
        preregistration_raw_sha256 = Get-RawSha256 -Path $preregistrationPath
        predecessor_closure_raw_sha256 =
            Get-RawSha256 -Path $predecessorClosurePath
        predecessor_closure_audit_raw_sha256 =
            Get-RawSha256 -Path $predecessorClosureAuditPath
        base_conformance_runner_raw_sha256 =
            Get-RawSha256 -Path $baseRunnerPath
        successor_conformance_runner_raw_sha256 =
            Get-RawSha256 -Path $runnerPath
        publication_supervisor_raw_sha256 =
            Get-RawSha256 -Path $supervisorPath
        complete_zero_world_gate_passed = $true
        attempt_contract_preflight_passed = $true
        expected_profile_count = 35
        expected_adapter_start_count = 36
        expected_gate_count = 46
        expected_world_count = 0
        expected_sample_count = 0
        expected_command_count = 0
        locomotion_seed_world_count = 0
        synthetic_contract_preflight = $Synthetic
        publication_identity_consumed = -not $Synthetic
        same_identity_rerun_allowed = $false
        physical_acceptance_authority = $false
    }
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
    ) "$gateId frozen source or prerequisite changed: $($entry.Key)"
}

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$profiles = @($preregistration.profiles)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw24p_material_profile_publication_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw24p_profile_publication_receipt" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [int]$preregistration.expected_conformance.total_profile_count -eq 35 -and
    [int]$preregistration.expected_conformance.adapter_start_count -eq 36 -and
    [int]$preregistration.expected_conformance.passed_gate_count -eq 46 -and
    [int]$preregistration.expected_conformance.failed_gate_count -eq 0 -and
    [int]$preregistration.attempt_contract_preflight.correct_profile_count -eq 35 -and
    [int]$preregistration.attempt_contract_preflight.correct_adapter_start_count -eq 36 -and
    [int]$preregistration.attempt_contract_preflight.correct_gate_count -eq 46 -and
    [bool]$preregistration.attempt_contract_preflight.production_parser_requires_exact_key_set -and
    [bool]$preregistration.attempt_contract_preflight.each_cardinality_and_identity_canary_mutates_one_field_only -and
    $profiles.Count -eq 3 -and
    (@($profiles | ForEach-Object { [string]$_.profile_id }) -join "|") -ceq
        "godot_jolt_bw24m_mu059_v1|godot_jolt_bw24m_mu071_v1|godot_jolt_bw24m_mu083_v1" -and
    -not [bool]$preregistration.successor_rationale.profile_payload_changed -and
    -not [bool]$preregistration.successor_rationale.outcome_dependent_threshold_or_payload_change -and
    -not [bool]$preregistration.claims.profile_published -and
    -not [bool]$preregistration.claims.walking_acceptance -and
    -not [bool]$preregistration.claims.physical_acceptance_authority
) "$gateId preregistration or claim boundary changed"

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

# Prove the complete profile gate and then the real serialized attempt parser.
& pwsh -NoProfile -File $runnerPath `
    -Godot $godotPath `
    -LogRoot (Join-Path $LogRoot "complete-gate")
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId complete zero-world gate failed"

[void][System.IO.Directory]::CreateDirectory(
    [System.IO.Path]::GetFullPath($LogRoot)
)
$syntheticAttemptPath = Join-Path (
    [System.IO.Path]::GetFullPath($LogRoot)
) ("synthetic-attempt-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
    $syntheticAttempt = New-AttemptRecord -Synthetic $true
    Write-NewJsonArtifact -Value $syntheticAttempt -Path $syntheticAttemptPath
    & pwsh -NoProfile -File $runnerPath `
        -ValidateAttemptOnly `
        -PublicationAttempt $syntheticAttemptPath
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId production attempt-contract preflight failed"
} finally {
    if (Test-Path -LiteralPath $syntheticAttemptPath -PathType Leaf) {
        Remove-Item -LiteralPath $syntheticAttemptPath -Force
    }
}

if ($PreflightOnly) {
    Write-Host (
        "$gateId PREFLIGHT_PASS profiles=35 prior_profiles=32 " +
        "bw24m_profiles=3 gates=46 adapter_starts=36 worlds=0 samples=0 " +
        "commands=0 attempt_contract=True locomotion_seeds_opened=0 " +
        "physical_authority=False"
    )
    return
}

$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$evidencePrefix = $evidenceRoot.TrimEnd("\") + "\"
Assert-Exact (
    $resolvedOutputRoot.StartsWith(
        $evidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    -not (Test-Path -LiteralPath $resolvedOutputRoot)
) "$gateId OutputRoot must be a new directory inside $evidenceRoot"

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
$expectedLeaf = "balanced-wave-bw24p-material-profiles-" +
    $sourceCommit.Substring(0, 7)
Assert-Exact (
    (Split-Path -Leaf $resolvedOutputRoot) -ceq $expectedLeaf
) "$gateId OutputRoot must be named $expectedLeaf"

$priorAttempts = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorAttempts = @(
        Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File -Filter "attempt.json" |
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
$attempt = New-AttemptRecord `
    -Synthetic $false `
    -SourceCommit $sourceCommit `
    -GodotVersion $godotVersion `
    -GodotSha256 (Get-RawSha256 -Path $godotPath)
Write-NewJsonArtifact -Value $attempt -Path $attemptPath

$reportPath = Join-Path $resolvedOutputRoot "report.json"
$publicationLogRoot = Join-Path $resolvedOutputRoot "worker"
& pwsh -NoProfile -File $runnerPath `
    -Godot $godotPath `
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
        "sporespore_godot_jolt_bw24p_material_profile_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.accepted -and
    [string]$report.result_status -ceq "passed" -and
    [bool]$report.attempt_contract.preflight_passed -and
    [int]$report.attempt_contract.expected_profile_count -eq 35 -and
    [int]$report.attempt_contract.expected_gate_count -eq 46 -and
    [bool]$receipt.ok -and
    [int]$receipt.observed_profile_count -eq 35 -and
    [int]$receipt.observed_adapter_start_count -eq 36 -and
    [int]$receipt.passed_gate_count -eq 46 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.observed_world_count -eq 0 -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.physical_acceptance_authority
) "$gateId retained report failed exact reconciliation"

$completionPath = Join-Path $resolvedOutputRoot "completion.json"
$completion = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw24p_material_profile_publication_completion_v1"
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
    adapter_start_count = 36
    passed_gate_count = 46
    failed_gate_count = 0
    world_build_count = 0
    locomotion_seed_world_count = 0
    attempt_contract_preflight_passed = $true
    same_identity_rerun_allowed = $false
    physical_acceptance_authority = $false
}
Write-NewJsonArtifact -Value $completion -Path $completionPath

Write-Host (
    "$gateId PUBLICATION_COMPLETE profiles=35 prior_profiles=32 " +
    "bw24m_profiles=3 gates=46 worlds=0 samples=0 commands=0 " +
    "attempt_contract=True bw25y_manifest_next=True " +
    "material_robustness=False physical_authority=False report=$reportPath"
)
