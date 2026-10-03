#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $PSScriptRoot "target\bw24p-material-profile-conformance"
    ),
    [string]$Output = "",
    [switch]$PublicationAuthorized,
    [string]$PublicationAttempt = "",
    [switch]$ValidateAttemptOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$gateId = "BW24P-PROFILE"
$campaignId = "BW24P-BW24M-PROFILE-PUBLICATION-SUCCESSOR"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24p_material_profile_publication_preregistration.json"
$runnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_bw24p_material_profile_conformance.ps1"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw24p_material_profile_publication.ps1"
$freezeAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw24p_material_profile_publication_freeze.ps1"
$predecessorClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24m_material_profile_publication_closure.json"
$predecessorClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw24m_material_profile_publication_closure.ps1"
$baseRunnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_bw24m_material_profile_conformance.ps1"
$profilesPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_material_profiles.gd"
$profileTestPath = Join-Path (
    $repoRoot
) "tests\test_sdk_godot_jolt_material_profiles.gd"
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

function Assert-AttemptRecord {
    param(
        [Parameter(Mandatory)][hashtable]$Attempt,
        [Parameter(Mandatory)][bool]$Synthetic
    )
    $expectedKeys = @(
        "schema_version",
        "campaign_id",
        "gate_id",
        "launched_at_utc",
        "source_commit",
        "origin_main_commit",
        "remote_main_commit",
        "source_worktree_clean",
        "source_matches_live_github_main",
        "godot_version",
        "godot_executable_sha256",
        "preregistration_raw_sha256",
        "predecessor_closure_raw_sha256",
        "predecessor_closure_audit_raw_sha256",
        "base_conformance_runner_raw_sha256",
        "successor_conformance_runner_raw_sha256",
        "publication_supervisor_raw_sha256",
        "complete_zero_world_gate_passed",
        "attempt_contract_preflight_passed",
        "expected_profile_count",
        "expected_adapter_start_count",
        "expected_gate_count",
        "expected_world_count",
        "expected_sample_count",
        "expected_command_count",
        "locomotion_seed_world_count",
        "synthetic_contract_preflight",
        "publication_identity_consumed",
        "same_identity_rerun_allowed",
        "physical_acceptance_authority"
    ) | Sort-Object
    $actualKeys = @(
        $Attempt.Keys | ForEach-Object { [string]$_ }
    ) | Sort-Object
    Assert-Exact (
        ($actualKeys -join "|") -ceq ($expectedKeys -join "|")
    ) "$gateId publication attempt key set is invalid"
    Assert-Exact (
        [string]$Attempt.schema_version -ceq
            "sporespore_balanced_wave_bw24p_material_profile_publication_attempt_v1" -and
        [string]$Attempt.campaign_id -ceq $campaignId -and
        [string]$Attempt.gate_id -ceq $gateId -and
        [string]$Attempt.godot_version -ceq
            "4.7.stable.mono.official.5b4e0cb0f" -and
        [string]$Attempt.godot_executable_sha256 -ceq
            "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
        [string]$Attempt.preregistration_raw_sha256 -ceq
            (Get-RawSha256 -Path $preregistrationPath) -and
        [string]$Attempt.predecessor_closure_raw_sha256 -ceq
            "f2921cb510b8283316f7c00bef4ff17492806f5d671c459efdde87b4a79eb0f0" -and
        [string]$Attempt.predecessor_closure_audit_raw_sha256 -ceq
            "8cefa67e1578f2168d050f8cbbbc0a4119c45a3eeccbec271528c43ef7e9ef19" -and
        [string]$Attempt.base_conformance_runner_raw_sha256 -ceq
            "09374a9afdfad8603cb84b63ff40aaa7d59bcd457cbd83c2f7c0fa9ed5a2e131" -and
        [string]$Attempt.successor_conformance_runner_raw_sha256 -ceq
            (Get-RawSha256 -Path $runnerPath) -and
        [string]$Attempt.publication_supervisor_raw_sha256 -ceq
            (Get-RawSha256 -Path $supervisorPath) -and
        -not [string]::IsNullOrWhiteSpace([string]$Attempt.launched_at_utc) -and
        [bool]$Attempt.complete_zero_world_gate_passed -and
        [bool]$Attempt.attempt_contract_preflight_passed -and
        [int]$Attempt.expected_profile_count -eq 35 -and
        [int]$Attempt.expected_adapter_start_count -eq 36 -and
        [int]$Attempt.expected_gate_count -eq 46 -and
        [int]$Attempt.expected_world_count -eq 0 -and
        [int]$Attempt.expected_sample_count -eq 0 -and
        [int]$Attempt.expected_command_count -eq 0 -and
        [int]$Attempt.locomotion_seed_world_count -eq 0 -and
        [bool]$Attempt.synthetic_contract_preflight -eq $Synthetic -and
        [bool]$Attempt.publication_identity_consumed -eq (-not $Synthetic) -and
        -not [bool]$Attempt.same_identity_rerun_allowed -and
        -not [bool]$Attempt.physical_acceptance_authority
    ) "$gateId publication attempt receipt is invalid"
    if ($Synthetic) {
        Assert-Exact (
            [string]$Attempt.source_commit -ceq
                "synthetic_preflight_no_source_identity" -and
            [string]::IsNullOrEmpty([string]$Attempt.origin_main_commit) -and
            [string]::IsNullOrEmpty([string]$Attempt.remote_main_commit) -and
            -not [bool]$Attempt.source_worktree_clean -and
            -not [bool]$Attempt.source_matches_live_github_main
        ) "$gateId synthetic attempt identity is invalid"
    } else {
        Assert-Exact (
            [string]$Attempt.source_commit -cmatch "^[0-9a-f]{40}$" -and
            [string]$Attempt.origin_main_commit -ceq
                [string]$Attempt.source_commit -and
            [string]$Attempt.remote_main_commit -ceq
                [string]$Attempt.source_commit -and
            [bool]$Attempt.source_worktree_clean -and
            [bool]$Attempt.source_matches_live_github_main
        ) "$gateId retained attempt source identity is invalid"
    }
}

Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Test-Path -LiteralPath $predecessorClosurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $predecessorClosurePath) -ceq
        "f2921cb510b8283316f7c00bef4ff17492806f5d671c459efdde87b4a79eb0f0" -and
    (Test-Path -LiteralPath $baseRunnerPath -PathType Leaf) -and
    (Get-RawSha256 -Path $baseRunnerPath) -ceq
        "09374a9afdfad8603cb84b63ff40aaa7d59bcd457cbd83c2f7c0fa9ed5a2e131"
) "$gateId prerequisite source is missing or changed"
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$predecessorClosure = Get-Content -Raw -LiteralPath $predecessorClosurePath |
    ConvertFrom-Json -AsHashtable
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw24p_material_profile_publication_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw24p_profile_publication_receipt" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.implementation_parent_commit -ceq
        "4eb763aa673f7e21462ef4ef32c63a21f290f36e" -and
    [int]$preregistration.expected_conformance.total_profile_count -eq 35 -and
    [int]$preregistration.expected_conformance.adapter_start_count -eq 36 -and
    [int]$preregistration.expected_conformance.passed_gate_count -eq 46 -and
    [int]$preregistration.expected_conformance.failed_gate_count -eq 0 -and
    [int]$preregistration.expected_conformance.world_build_count -eq 0 -and
    [int]$preregistration.attempt_contract_preflight.correct_profile_count -eq 35 -and
    [int]$preregistration.attempt_contract_preflight.correct_adapter_start_count -eq 36 -and
    [int]$preregistration.attempt_contract_preflight.correct_gate_count -eq 46 -and
    [int]$preregistration.attempt_contract_preflight.wrong_profile_count_canary -eq 32 -and
    [bool]$preregistration.attempt_contract_preflight.missing_adapter_start_count_canary -and
    [int]$preregistration.attempt_contract_preflight.wrong_adapter_start_count_canary -eq 33 -and
    [int]$preregistration.attempt_contract_preflight.wrong_gate_count_canary -eq 43 -and
    [bool]$preregistration.attempt_contract_preflight.production_parser_requires_exact_key_set -and
    [bool]$preregistration.attempt_contract_preflight.each_cardinality_and_identity_canary_mutates_one_field_only -and
    -not [bool]$preregistration.claims.profile_published -and
    -not [bool]$preregistration.claims.walking_acceptance -and
    -not [bool]$preregistration.claims.physical_acceptance_authority -and
    [string]$predecessorClosure.status -ceq
        "closed_incomplete_invalid_publication_attempt_contract_mismatch" -and
    -not [bool]$predecessorClosure.same_identity_rerun_allowed -and
    [bool]$predecessorClosure.next_allowed_work.scientifically_distinct_zero_world_publication_successor_required -and
    [bool]$predecessorClosure.next_allowed_work.successor_may_reuse_exact_unchanged_profile_payloads
) "$gateId preregistration or predecessor authorization changed"

if ($ValidateAttemptOnly) {
    Assert-Exact (
        [string]::IsNullOrWhiteSpace($Output) -and
        -not $PublicationAuthorized -and
        -not [string]::IsNullOrWhiteSpace($PublicationAttempt)
    ) "$gateId attempt-only validation parameters are invalid"
    $attemptPath = [System.IO.Path]::GetFullPath($PublicationAttempt)
    Assert-Exact (
        Test-Path -LiteralPath $attemptPath -PathType Leaf
    ) "$gateId synthetic attempt receipt is missing"
    $attempt = Get-Content -Raw -LiteralPath $attemptPath |
        ConvertFrom-Json -AsHashtable
    Assert-AttemptRecord -Attempt $attempt -Synthetic $true
    Write-Host (
        "$gateId ATTEMPT_CONTRACT_PREFLIGHT_PASS profiles=35 " +
        "adapter_starts=36 gates=46 worlds=0 identity_consumed=False"
    )
    return
}

Assert-Exact (
    [string]::IsNullOrWhiteSpace($PublicationAttempt) -eq
        [string]::IsNullOrWhiteSpace($Output)
) "$gateId publication attempt and output must be supplied together"

$godotPath = [System.IO.Path]::GetFullPath($Godot)
Assert-Exact (
    (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
    (Get-RawSha256 -Path $godotPath) -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
) "$gateId pinned Godot executable is missing or changed"

$timestamp = Get-Date -Format "yyyyMMddTHHmmssfff"
$runRoot = Join-Path ([System.IO.Path]::GetFullPath($LogRoot)) $timestamp
[void][System.IO.Directory]::CreateDirectory($runRoot)
$baseLogRoot = Join-Path $runRoot "base"
$transcriptPath = Join-Path $runRoot "base-conformance.log"
& pwsh -NoProfile -File $baseRunnerPath `
    -Godot $godotPath `
    -LogRoot $baseLogRoot `
    2>&1 | Tee-Object -FilePath $transcriptPath
$baseExitCode = $LASTEXITCODE
Assert-Exact (
    $baseExitCode -eq 0
) "$gateId complete inherited zero-world conformance failed"
$receiptLines = @(
    Get-Content -LiteralPath $transcriptPath |
        Where-Object { $_.StartsWith("SDK_MATERIAL_PROFILE_RECEIPT ") }
)
Assert-Exact (
    $receiptLines.Count -eq 1
) "$gateId expected exactly one material-profile receipt"
$receipt = $receiptLines[0].Substring(
    "SDK_MATERIAL_PROFILE_RECEIPT ".Length
) | ConvertFrom-Json -AsHashtable
Assert-Exact (
    [bool]$receipt.ok -and
    [int]$receipt.expected_profile_count -eq 35 -and
    [int]$receipt.observed_profile_count -eq 35 -and
    [int]$receipt.expected_adapter_start_count -eq 36 -and
    [int]$receipt.observed_adapter_start_count -eq 36 -and
    [int]$receipt.expected_gate_count -eq 46 -and
    [int]$receipt.passed_gate_count -eq 46 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.observed_world_count -eq 0 -and
    [int]$receipt.observed_sample_count -eq 0 -and
    [int]$receipt.observed_command_count -eq 0 -and
    (@($receipt.profile_ids | Select-Object -Last 3) -join "|") -ceq
        ($expectedProfileIds -join "|") -and
    (@($receipt.profile_sha256 | Select-Object -Last 3) -join "|") -ceq
        ($expectedProfileSha256 -join "|") -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.physical_acceptance_authority
) "$gateId complete zero-world receipt failed"

if ([string]::IsNullOrWhiteSpace($Output)) {
    Assert-Exact (
        -not $PublicationAuthorized
    ) "$gateId publication authorization is valid only with -Output"
    Write-Host (
        "$gateId CONFORMANCE_PASS profiles=35 prior_profiles=32 " +
        "bw24m_profiles=3 gates=46 adapter_starts=36 worlds=0 samples=0 " +
        "commands=0 locomotion_seeds_opened=0 physical_authority=False"
    )
    return
}

$outputPath = [System.IO.Path]::GetFullPath($Output)
$outputDirectory = Split-Path -Parent $outputPath
$attemptPath = [System.IO.Path]::GetFullPath($PublicationAttempt)
Assert-Exact (
    $PublicationAuthorized -and
    $attemptPath -ceq (Join-Path $outputDirectory "attempt.json") -and
    (Test-Path -LiteralPath $attemptPath -PathType Leaf)
) "$gateId retained publication requires the supervisor's sibling attempt receipt"
$attempt = Get-Content -Raw -LiteralPath $attemptPath |
    ConvertFrom-Json -AsHashtable
Assert-AttemptRecord -Attempt $attempt -Synthetic $false

$status = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all)
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
$remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$remoteMain = ($remoteLine -split "\s+")[0]
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $status.Count -eq 0 -and
    $sourceCommit -ceq $originMain -and
    $sourceCommit -ceq $remoteMain -and
    [string]$attempt.source_commit -ceq $sourceCommit
) "$gateId retained evidence requires clean source matching live GitHub main"
Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "report.json" -and
    -not (Test-Path -LiteralPath $outputPath)
) "$gateId refuses an invalid or existing report path"

$retainedTranscriptPath = Join-Path $outputDirectory "transcript.log"
$retainedEngineLogPath = Join-Path $outputDirectory "engine.log"
Assert-Exact (
    -not (Test-Path -LiteralPath $retainedTranscriptPath) -and
    -not (Test-Path -LiteralPath $retainedEngineLogPath)
) "$gateId refuses existing retained logs"
[System.IO.File]::Copy($transcriptPath, $retainedTranscriptPath, $false)
$engineLogs = @(
    Get-ChildItem -LiteralPath $baseLogRoot -Recurse -File -Filter "engine.log"
)
Assert-Exact (
    $engineLogs.Count -eq 1
) "$gateId expected one inherited worker engine log"
[System.IO.File]::Copy(
    $engineLogs[0].FullName,
    $retainedEngineLogPath,
    $false
)

$sourcePaths = [ordered]@{
    preregistration =
        "sdk/balanced_wave_bw24p_material_profile_publication_preregistration.json"
    predecessor_closure =
        "sdk/balanced_wave_bw24m_material_profile_publication_closure.json"
    predecessor_closure_audit =
        "tests/test_bw24m_material_profile_publication_closure.ps1"
    base_zero_world_runner =
        "sdk/run_godot_jolt_bw24m_material_profile_conformance.ps1"
    successor_zero_world_runner =
        "sdk/run_godot_jolt_bw24p_material_profile_conformance.ps1"
    publication_supervisor =
        "sdk/run_balanced_wave_bw24p_material_profile_publication.ps1"
    prospective_freeze_audit =
        "tests/test_bw24p_material_profile_publication_freeze.ps1"
    profiles = "scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
    test = "tests/test_sdk_godot_jolt_material_profiles.gd"
}
$sources = [ordered]@{}
foreach ($entry in $sourcePaths.GetEnumerator()) {
    $path = Join-Path $repoRoot $entry.Value
    $sources[$entry.Key] = [ordered]@{
        path = $entry.Value
        sha256 = Get-RawSha256 -Path $path
    }
}
$report = [ordered]@{
    schema_version =
        "sporespore_godot_jolt_bw24p_material_profile_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    campaign_id = $campaignId
    gate_id = $gateId
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    source_matches_live_github_main = $true
    accepted = $true
    result_status = "passed"
    godot_exit_code = $baseExitCode
    stopping_rule =
        "zero_world_infrastructure_successor_after_bw24m_profile_publication_closed_incomplete_before_bw25y_locomotion"
    predecessor = [ordered]@{
        campaign_id =
            "BW24M-BW23Y-FRESH-MATERIAL-PROFILE-PUBLICATION"
        closure_path = $predecessorClosurePath
        closure_sha256 = Get-RawSha256 -Path $predecessorClosurePath
        profile_published = $false
        failure_class =
            "publication_supervisor_attempt_cardinality_defect"
        profile_payload_changed = $false
    }
    godot = [ordered]@{
        executable_path = $godotPath
        executable_sha256 = Get-RawSha256 -Path $godotPath
        version = (& $godotPath --version).Trim()
        physics_engine = "Jolt Physics"
        physics_hz = 120
        solver_velocity_steps = 20
        solver_position_steps = 7
    }
    sources = $sources
    transcript = [ordered]@{
        path = "transcript.log"
        sha256 = Get-RawSha256 -Path $retainedTranscriptPath
    }
    engine_log = [ordered]@{
        path = "engine.log"
        sha256 = Get-RawSha256 -Path $retainedEngineLogPath
    }
    attempt_contract = [ordered]@{
        preflight_passed = $true
        expected_profile_count = 35
        expected_adapter_start_count = 36
        expected_gate_count = 46
        predecessor_cardinality_rejected = $true
    }
    receipt = $receipt
}
$temporaryOutputPath = $outputPath + ".tmp"
Assert-Exact (
    -not (Test-Path -LiteralPath $temporaryOutputPath)
) "$gateId refuses a stale temporary report"
[System.IO.File]::WriteAllText(
    $temporaryOutputPath,
    (($report | ConvertTo-Json -Depth 40) + [Environment]::NewLine),
    [System.Text.UTF8Encoding]::new($false)
)
Move-Item -LiteralPath $temporaryOutputPath -Destination $outputPath
Write-Host (
    "$gateId RETAINED_REPORT_PASS profiles=35 bw24m_profiles=3 gates=46 " +
    "worlds=0 samples=0 commands=0 report=$outputPath"
)
