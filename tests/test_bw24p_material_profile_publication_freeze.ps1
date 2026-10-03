#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipGodotExecution,
    [switch]$SkipSupervisorPreflight
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$evidenceBase = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "BW24P-BW24M-PROFILE-PUBLICATION-SUCCESSOR"
$gateId = "BW24P-PROFILE"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24p_material_profile_publication_preregistration.json"
$runnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_bw24p_material_profile_conformance.ps1"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw24p_material_profile_publication.ps1"
$predecessorClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24m_material_profile_publication_closure.json"
$predecessorAuditPath = Join-Path (
    $PSScriptRoot
) "test_bw24m_material_profile_publication_closure.ps1"
$baseRunnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_bw24m_material_profile_conformance.ps1"
$publicationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24p_material_profile_publication_closure.json"
$expectedHashes = [ordered]@{
    $preregistrationPath = "f4cda32a4f996b0df234a1f398f08f45e74fef8f362acdb2c2641ddf3d2de67a"
    $runnerPath = "65dc4c92372653529870180afd35fa7f4344b0d05ed6ed1f86e1de69c6a022a9"
    $supervisorPath = "53304e612ee3beadf2ea082df6ec7ea9e8b6553316bf02c302d8fdd1d45140a4"
    $predecessorClosurePath = "f2921cb510b8283316f7c00bef4ff17492806f5d671c459efdde87b4a79eb0f0"
    $predecessorAuditPath = "8cefa67e1578f2168d050f8cbbbc0a4119c45a3eeccbec271528c43ef7e9ef19"
    $baseRunnerPath = "09374a9afdfad8603cb84b63ff40aaa7d59bcd457cbd83c2f7c0fa9ed5a2e131"
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

function Write-Json {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    [System.IO.File]::WriteAllText(
        $Path,
        (($Value | ConvertTo-Json -Depth 40) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Invoke-ExpectedFailure {
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][string]$Needle,
        [Parameter(Mandatory)][string]$Label
    )
    $output = @(& $Action 2>&1 | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
    Assert-Exact (
        $exitCode -ne 0 -and
        ($output -join [Environment]::NewLine).Contains($Needle)
    ) "$gateId $Label did not fail closed with '$Needle'"
}

function Invoke-AttemptMutationCanary {
    param(
        [Parameter(Mandatory)][hashtable]$BaseAttempt,
        [Parameter(Mandatory)][scriptblock]$Mutation,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Needle,
        [Parameter(Mandatory)][string]$Label
    )
    $mutated = ($BaseAttempt | ConvertTo-Json -Depth 40) |
        ConvertFrom-Json -AsHashtable
    & $Mutation $mutated
    Write-Json -Value $mutated -Path $Path
    Invoke-ExpectedFailure -Label $Label -Needle $Needle -Action {
        & pwsh -NoProfile -File $runnerPath `
            -ValidateAttemptOnly `
            -PublicationAttempt $Path
    }
}

foreach ($entry in $expectedHashes.GetEnumerator()) {
    Assert-Exact (
        (Test-Path -LiteralPath $entry.Key -PathType Leaf) -and
        (Get-RawSha256 -Path $entry.Key) -ceq [string]$entry.Value
    ) "$gateId frozen artifact changed: $($entry.Key)"
}
Assert-Exact (
    -not (Test-Path -LiteralPath $publicationClosurePath -PathType Leaf)
) "$gateId prospective freeze must be replaced by its closure audit"

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
        "4eb763aa673f7e21462ef4ef32c63a21f290f36e" -and
    [string]$preregistration.study_classification -ceq
        "deterministic_zero_world_profile_publication_infrastructure_successor" -and
    [int]$preregistration.world_build_count -eq 0 -and
    [int]$preregistration.locomotion_seed_world_count -eq 0 -and
    [string]$preregistration.successor_rationale.predecessor_status -ceq
        "closed_incomplete_invalid_publication_attempt_contract_mismatch" -and
    [bool]$preregistration.successor_rationale.predecessor_worker_profile_conformance_passed -and
    -not [bool]$preregistration.successor_rationale.predecessor_profile_published -and
    -not [bool]$preregistration.successor_rationale.profile_payload_changed -and
    -not [bool]$preregistration.successor_rationale.outcome_dependent_threshold_or_payload_change -and
    $profiles.Count -eq 3 -and
    (@($profiles | ForEach-Object { [string]$_.profile_id }) -join "|") -ceq
        "godot_jolt_bw24m_mu059_v1|godot_jolt_bw24m_mu071_v1|godot_jolt_bw24m_mu083_v1" -and
    (@($profiles | ForEach-Object {
        [string]$_.expected_profile_sha256
    }) -join "|") -ceq
        "sha256:2d8a2571c129dbe7b2b894bae1aa28f5650fdbea27fcb65a149566c54a536173|sha256:a8efdd111b740391931219d720079beffeea8181e5c46fd00ea7acb6108ab8ee|sha256:e5916d9e17f87120e5cc04ff03e8688c4dea3919715a68854a8dce29e4d9c2a0" -and
    [int]$preregistration.expected_conformance.prior_profile_count -eq 32 -and
    [int]$preregistration.expected_conformance.total_profile_count -eq 35 -and
    [int]$preregistration.expected_conformance.adapter_start_count -eq 36 -and
    [int]$preregistration.expected_conformance.passed_gate_count -eq 46 -and
    [int]$preregistration.expected_conformance.failed_gate_count -eq 0 -and
    [int]$preregistration.attempt_contract_preflight.wrong_profile_count_canary -eq 32 -and
    [bool]$preregistration.attempt_contract_preflight.missing_adapter_start_count_canary -and
    [int]$preregistration.attempt_contract_preflight.wrong_adapter_start_count_canary -eq 33 -and
    [int]$preregistration.attempt_contract_preflight.wrong_gate_count_canary -eq 43 -and
    [string]$preregistration.attempt_contract_preflight.predecessor_campaign_identity_canary -ceq
        "BW24M-BW23Y-FRESH-MATERIAL-PROFILE-PUBLICATION" -and
    [string]$preregistration.attempt_contract_preflight.predecessor_gate_identity_canary -ceq
        "BW24M-PROFILE" -and
    [bool]$preregistration.attempt_contract_preflight.preregistration_digest_tamper_canary -and
    [bool]$preregistration.attempt_contract_preflight.predecessor_closure_digest_tamper_canary -and
    [int]$preregistration.attempt_contract_preflight.correct_profile_count -eq 35 -and
    [int]$preregistration.attempt_contract_preflight.correct_adapter_start_count -eq 36 -and
    [int]$preregistration.attempt_contract_preflight.correct_gate_count -eq 46 -and
    [bool]$preregistration.attempt_contract_preflight.same_attempt_record_constructor_used_for_synthetic_and_real_records -and
    [bool]$preregistration.attempt_contract_preflight.serialized_synthetic_attempt_must_pass_the_production_parser -and
    [bool]$preregistration.attempt_contract_preflight.production_parser_requires_exact_key_set -and
    [bool]$preregistration.attempt_contract_preflight.each_cardinality_and_identity_canary_mutates_one_field_only -and
    -not [bool]$preregistration.claims.profile_published -and
    -not [bool]$preregistration.claims.walking_acceptance -and
    -not [bool]$preregistration.claims.friction_or_material_locomotion_robustness -and
    -not [bool]$preregistration.claims.cross_engine_equivalence -and
    -not [bool]$preregistration.claims.physical_acceptance_authority
) "$gateId preregistration, payload, or claim boundary changed"

$supervisorText = Get-Content -Raw -LiteralPath $supervisorPath
$runnerText = Get-Content -Raw -LiteralPath $runnerPath
Assert-Exact (
    $supervisorText.Contains("function New-AttemptRecord") -and
    $supervisorText.Contains("expected_profile_count = 35") -and
    $supervisorText.Contains("expected_adapter_start_count = 36") -and
    $supervisorText.Contains("expected_gate_count = 46") -and
    $supervisorText.Contains("New-AttemptRecord -Synthetic `$true") -and
    [regex]::IsMatch(
        $supervisorText,
        'New-AttemptRecord\s+`?\s*-Synthetic \$false'
    ) -and
    $runnerText.Contains("function Assert-AttemptRecord") -and
    $runnerText.Contains("[int]`$Attempt.expected_profile_count -eq 35") -and
    $runnerText.Contains("[int]`$Attempt.expected_gate_count -eq 46")
) "$gateId shared attempt constructor or production parser changed"

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
    $attemptFiles.Count -eq 0
) "$gateId publication identity was already consumed"

$canaryRoot = Join-Path (
    $sdkRoot
) ("target\bw24p-freeze-canary-" + [Guid]::NewGuid().ToString("N"))
[void][System.IO.Directory]::CreateDirectory($canaryRoot)
$correctAttemptPath = Join-Path $canaryRoot "correct-attempt.json"
$wrongAttemptPath = Join-Path $canaryRoot "wrong-attempt.json"
try {
    $attempt = [ordered]@{
        schema_version =
            "sporespore_balanced_wave_bw24p_material_profile_publication_attempt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        launched_at_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = "synthetic_preflight_no_source_identity"
        origin_main_commit = ""
        remote_main_commit = ""
        source_worktree_clean = $false
        source_matches_live_github_main = $false
        godot_version = "4.7.stable.mono.official.5b4e0cb0f"
        godot_executable_sha256 =
            "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
        preregistration_raw_sha256 = Get-RawSha256 -Path $preregistrationPath
        predecessor_closure_raw_sha256 =
            Get-RawSha256 -Path $predecessorClosurePath
        predecessor_closure_audit_raw_sha256 =
            Get-RawSha256 -Path $predecessorAuditPath
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
        synthetic_contract_preflight = $true
        publication_identity_consumed = $false
        same_identity_rerun_allowed = $false
        physical_acceptance_authority = $false
    }
    Write-Json -Value $attempt -Path $correctAttemptPath
    & pwsh -NoProfile -File $runnerPath `
        -ValidateAttemptOnly `
        -PublicationAttempt $correctAttemptPath
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId correct synthetic attempt did not pass production parser"

    $baseAttempt = Get-Content -Raw -LiteralPath $correctAttemptPath |
        ConvertFrom-Json -AsHashtable
    Invoke-AttemptMutationCanary -BaseAttempt $baseAttempt `
        -Path $wrongAttemptPath `
        -Label "wrong-profile-count canary" `
        -Needle "$gateId publication attempt receipt is invalid" `
        -Mutation { param($value) $value.expected_profile_count = 32 }
    Invoke-AttemptMutationCanary -BaseAttempt $baseAttempt `
        -Path $wrongAttemptPath `
        -Label "missing-adapter-start-count canary" `
        -Needle "$gateId publication attempt key set is invalid" `
        -Mutation {
            param($value)
            [void]$value.Remove("expected_adapter_start_count")
        }
    Invoke-AttemptMutationCanary -BaseAttempt $baseAttempt `
        -Path $wrongAttemptPath `
        -Label "wrong-adapter-start-count canary" `
        -Needle "$gateId publication attempt receipt is invalid" `
        -Mutation { param($value) $value.expected_adapter_start_count = 33 }
    Invoke-AttemptMutationCanary -BaseAttempt $baseAttempt `
        -Path $wrongAttemptPath `
        -Label "wrong-gate-count canary" `
        -Needle "$gateId publication attempt receipt is invalid" `
        -Mutation { param($value) $value.expected_gate_count = 43 }
    Invoke-AttemptMutationCanary -BaseAttempt $baseAttempt `
        -Path $wrongAttemptPath `
        -Label "predecessor-campaign-identity canary" `
        -Needle "$gateId publication attempt receipt is invalid" `
        -Mutation {
            param($value)
            $value.campaign_id =
                "BW24M-BW23Y-FRESH-MATERIAL-PROFILE-PUBLICATION"
        }
    Invoke-AttemptMutationCanary -BaseAttempt $baseAttempt `
        -Path $wrongAttemptPath `
        -Label "predecessor-gate-identity canary" `
        -Needle "$gateId publication attempt receipt is invalid" `
        -Mutation { param($value) $value.gate_id = "BW24M-PROFILE" }
    Invoke-AttemptMutationCanary -BaseAttempt $baseAttempt `
        -Path $wrongAttemptPath `
        -Label "preregistration-digest-tamper canary" `
        -Needle "$gateId publication attempt receipt is invalid" `
        -Mutation {
            param($value)
            $value.preregistration_raw_sha256 = "0" * 64
        }
    Invoke-AttemptMutationCanary -BaseAttempt $baseAttempt `
        -Path $wrongAttemptPath `
        -Label "predecessor-closure-digest-tamper canary" `
        -Needle "$gateId publication attempt receipt is invalid" `
        -Mutation {
            param($value)
            $value.predecessor_closure_raw_sha256 = "0" * 64
        }
    Invoke-ExpectedFailure -Label "missing-attempt canary" `
        -Needle "$gateId attempt-only validation parameters are invalid" `
        -Action {
            & pwsh -NoProfile -File $runnerPath -ValidateAttemptOnly
        }
    Invoke-ExpectedFailure -Label "missing-mode canary" `
        -Needle "Specify exactly one of -PreflightOnly or -Publish" `
        -Action {
            & pwsh -NoProfile -File $supervisorPath
        }
} finally {
    foreach ($path in @($correctAttemptPath, $wrongAttemptPath)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Remove-Item -LiteralPath $path -Force
        }
    }
    if (Test-Path -LiteralPath $canaryRoot -PathType Container) {
        Remove-Item -LiteralPath $canaryRoot -Force
    }
}

if (-not $SkipSupervisorPreflight) {
    & pwsh -NoProfile -File $supervisorPath -PreflightOnly
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId complete supervisor preflight failed"
}

if (-not $SkipGodotExecution -and $SkipSupervisorPreflight) {
    & pwsh -NoProfile -File $runnerPath
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId direct zero-world conformance failed"
}

Write-Host (
    "BW24P_PROFILE_FREEZE_PASS profiles=35 prior_profiles=32 " +
    "bw24m_profiles=3 gates=46 worlds=0 samples=0 commands=0 " +
    "attempt_contract=True canaries=10 supervisor_preflight=" +
    (-not $SkipSupervisorPreflight) +
    " profile_published=False locomotion_seeds_opened=0 " +
    "material_robustness=False physical_authority=False"
)
