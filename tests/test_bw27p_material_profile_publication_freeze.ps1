#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipGodotExecution,
    [switch]$SkipSupervisorPreflight
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "BW27P-BW27M-MATERIAL-PROFILE-PUBLICATION"
$gateId = "BW27P-PROFILE"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw27p_material_profile_publication_preregistration.json"
$runnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_bw27p_material_profile_conformance.ps1"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw27p_material_profile_publication.ps1"
$characterizationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw27m_material_characterization_closure.json"
$characterizationClosureAuditPath = Join-Path (
    $PSScriptRoot
) "test_bw27m_material_characterization_closure.ps1"
$priorProfileClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24p_material_profile_publication_closure.json"
$priorProfileClosureAuditPath = Join-Path (
    $PSScriptRoot
) "test_bw24p_material_profile_publication_closure.ps1"
$profileRegistryPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_material_profiles.gd"
$profileTestPath = Join-Path (
    $PSScriptRoot
) "test_sdk_godot_jolt_material_profiles.gd"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$attestationHelperPath = Join-Path (
    $sdkRoot
) "locomotion_full_conformance_attestation.ps1"
$publicationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw27p_material_profile_publication_closure.json"
$expectedHashes = [ordered]@{
    $preregistrationPath =
        "c1d17fea278eccaf558e3a03013b088d1d4e63cafac2353f16b95a4906d2b4cb"
    $runnerPath =
        "d5ab360d1e94a8964b83f0143ba70ec8d45ef013fe5e28150bd2489fd8355ae7"
    $supervisorPath =
        "2ac4e191b305bf62fa647335036037ab6d63d9e23297f71f164d0abfc0188148"
    $characterizationClosurePath =
        "5960c5d7f5b70f4d98356de884bb4d0c6fbc55f14d7060780efe07d6b278d519"
    $characterizationClosureAuditPath =
        "843e8deaa4f696600252cf691633a30264f47682f209e5dce0475c1ee90baeb6"
    $priorProfileClosurePath =
        "c8a0b9d64740a79562e2f07c85f366921cc585b5429e938a360a3489a1585cfa"
    $priorProfileClosureAuditPath =
        "bf9eea36d58acf8b8cbd5c6812256b3314c91a571f113b07660d523da6bf253d"
    $profileRegistryPath =
        "f465fa15c079d74574e3e401cbcce1b912bd50bd25b483a7f374842eec841de5"
    $profileTestPath =
        "68c546d05eaeb1d40d6132b94f6ec21e166a334b19f64ffb295f882b64a560a6"
    $operationLockPath =
        "105964dfcd3fdf0a4aca27cb369e2714d7ec0cc8bf7e0204e559f85567fa3e31"
    $attestationHelperPath =
        "b70d00f9b77f46676520d3c39c63882313449376383758484a74690bd389a267"
}

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
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
    ConvertFrom-Json -AsHashtable -Depth 64
$profiles = @($preregistration.profiles)
$profileIds = @($profiles | ForEach-Object { [string]$_.profile_id })
$profileDigests = @(
    $profiles | ForEach-Object { [string]$_.expected_profile_sha256 }
)
$claimValues = @($preregistration.claims.Values | ForEach-Object { [bool]$_ })
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw27p_material_profile_publication_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw27p_profile_publication_receipt" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.implementation_parent_commit -ceq
        "03b0f5c85d66f512017be5843f00adc0bedb85d3" -and
    [string]$preregistration.study_classification -ceq
        "deterministic_zero_world_exact_adapter_profile_publication" -and
    [int]$preregistration.world_build_count -eq 0 -and
    [int]$preregistration.locomotion_seed_world_count -eq 0 -and
    [string]$preregistration.publication_rationale.material_characterization_campaign -ceq
        "BW27M-BW25Y-FRESH-MATERIAL-CHARACTERIZATION" -and
    [bool]$preregistration.publication_rationale.material_characterization_profile_publication_authorized -and
    [bool]$preregistration.publication_rationale.profile_payload_is_deterministically_derived_from_retained_characterization -and
    -not [bool]$preregistration.publication_rationale.outcome_dependent_threshold_or_payload_change -and
    -not [bool]$preregistration.publication_rationale.new_physical_outcome_exposed -and
    $profiles.Count -eq 3 -and
    ($profileIds -join "|") -ceq (
        "godot_jolt_bw27m_mu062_v1|" +
        "godot_jolt_bw27m_mu074_v1|" +
        "godot_jolt_bw27m_mu086_v1"
    ) -and
    ($profileDigests -join "|") -ceq (
        "sha256:62bd8b2543c7c3cdb9b389029e5ae3de777cbcc29c5a5ba5b769863442c854c3|" +
        "sha256:6a8128171b87ad824b3675cbf731927681b55c0f529d179e3dbb32c842752857|" +
        "sha256:29735973a8334064f1a1a1fb8c8d679c335e68b4a97a396c550f68b76321863d"
    ) -and
    [int]$preregistration.expected_conformance.prior_profile_count -eq 35 -and
    [int]$preregistration.expected_conformance.total_profile_count -eq 38 -and
    [int]$preregistration.expected_conformance.bw27m_profile_count -eq 3 -and
    [int]$preregistration.expected_conformance.adapter_start_count -eq 39 -and
    [int]$preregistration.expected_conformance.passed_gate_count -eq 49 -and
    [int]$preregistration.expected_conformance.failed_gate_count -eq 0 -and
    [int]$preregistration.expected_conformance.world_build_count -eq 0 -and
    [int]$preregistration.expected_conformance.sample_count -eq 0 -and
    [int]$preregistration.expected_conformance.command_count -eq 0 -and
    [int]$preregistration.attempt_contract_preflight.correct_profile_count -eq 38 -and
    [int]$preregistration.attempt_contract_preflight.correct_adapter_start_count -eq 39 -and
    [int]$preregistration.attempt_contract_preflight.correct_gate_count -eq 49 -and
    [int]$preregistration.attempt_contract_preflight.independent_negative_canary_count -eq 10 -and
    [bool]$preregistration.attempt_contract_preflight.same_attempt_record_constructor_used_for_synthetic_and_real_records -and
    [bool]$preregistration.attempt_contract_preflight.serialized_synthetic_attempt_must_pass_the_production_parser -and
    [bool]$preregistration.attempt_contract_preflight.production_parser_requires_exact_key_set -and
    [bool]$preregistration.staged_interlocks.publication_requires_clean_pushed_source_matching_live_github_main -and
    [bool]$preregistration.staged_interlocks.publication_requires_repository_wide_prepublication_conformance_from_exact_source -and
    [bool]$preregistration.staged_interlocks.publication_requires_matching_durable_v2_full_godot_conformance_attestation -and
    [bool]$preregistration.staged_interlocks.publication_attempt_written_before_report_generation -and
    [bool]$preregistration.staged_interlocks.publication_serialized_by_shared_global_operation_lock -and
    -not [bool]$preregistration.staged_interlocks.same_identity_rerun_allowed -and
    (@($preregistration.staged_interlocks.sealed_future_locomotion_seeds) -join "|") -ceq
        "27011|27012|27013|27014" -and
    $claimValues.Count -eq 12 -and
    @($claimValues | Where-Object { $_ }).Count -eq 0
) "$gateId preregistration, payload, interlock, or claim boundary changed"

$supervisorText = Get-Content -Raw -LiteralPath $supervisorPath
$runnerText = Get-Content -Raw -LiteralPath $runnerPath
Assert-Exact (
    $supervisorText.Contains("function New-AttemptRecord") -and
    $supervisorText.Contains("expected_profile_count = 38") -and
    $supervisorText.Contains("expected_adapter_start_count = 39") -and
    $supervisorText.Contains("expected_gate_count = 49") -and
    $supervisorText.Contains("independent_negative_canary_count -eq 10") -and
    $supervisorText.Contains("Test-SporeSporeFullConformanceAttestationFile") -and
    $supervisorText.Contains("Enter-SporeSporeLocomotionOperationLock -Role physical") -and
    $supervisorText.Contains("Write-NewJsonArtifact -Value `$attempt -Path `$attemptPath") -and
    $runnerText.Contains("function Assert-AttemptRecord") -and
    $runnerText.Contains("[int]`$Attempt.expected_profile_count -eq 38") -and
    $runnerText.Contains("[int]`$Attempt.expected_adapter_start_count -eq 39") -and
    $runnerText.Contains("[int]`$Attempt.expected_gate_count -eq 49") -and
    $runnerText.Contains("[int]`$Attempt.expected_world_count -eq 0") -and
    $runnerText.Contains("[int]`$Attempt.expected_sample_count -eq 0") -and
    $runnerText.Contains("[int]`$Attempt.expected_command_count -eq 0")
) "$gateId attempt constructor, parser, attestation, or lock route changed"

$attemptFiles = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $attemptFiles = @(
        Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File -Filter "attempt.json" |
            Where-Object {
                try {
                    $candidate = Get-Content -Raw -LiteralPath $_.FullName |
                        ConvertFrom-Json
                    [string]$candidate.campaign_id -ceq $campaignId
                } catch { $false }
            }
    )
}
Assert-Exact (
    $attemptFiles.Count -eq 0
) "$gateId publication identity was already consumed"

Invoke-ExpectedFailure `
    -Label "incomplete-publication interlock" `
    -Needle "$gateId -Publish requires an explicit durable OutputRoot" `
    -Action {
        & pwsh -NoProfile -File $supervisorPath -Publish
    }

if (-not $SkipSupervisorPreflight) {
    & pwsh `
        -NoProfile `
        -File $supervisorPath `
        -PreflightOnly `
        -Godot $Godot
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId complete supervisor preflight failed"
}

if (-not $SkipGodotExecution -and $SkipSupervisorPreflight) {
    & pwsh -NoProfile -File $runnerPath -Godot $Godot
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId direct zero-world conformance failed"
}

Write-Host (
    "BW27P_PROFILE_FREEZE_PASS profiles=38 prior_profiles=35 " +
    "bw27m_profiles=3 gates=49 adapter_starts=39 canaries=10 worlds=0 " +
    "samples=0 commands=0 attestation_required=True operation_lock=True " +
    "supervisor_preflight=" + (-not $SkipSupervisorPreflight) +
    " profile_published=False locomotion_seeds_opened=0 " +
    "material_robustness=False physical_authority=False"
)
