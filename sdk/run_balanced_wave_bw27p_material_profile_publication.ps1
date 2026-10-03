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
        Join-Path $PSScriptRoot "target\bw27p-profile-publication-preflight"
    ),
    [string]$OutputRoot = "",
    [string]$FullConformanceAttestation = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1")

$campaignId = "BW27P-BW27M-MATERIAL-PROFILE-PUBLICATION"
$gateId = "BW27P-PROFILE"
$implementationParentCommit = "03b0f5c85d66f512017be5843f00adc0bedb85d3"
$supervisorPath = $PSCommandPath
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw27p_material_profile_publication_preregistration.json"
$runnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_bw27p_material_profile_conformance.ps1"
$characterizationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw27m_material_characterization_closure.json"
$characterizationClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw27m_material_characterization_closure.ps1"
$priorProfileClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24p_material_profile_publication_closure.json"
$priorProfileClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw24p_material_profile_publication_closure.ps1"
$profileRegistryPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_material_profiles.gd"
$profileTestPath = Join-Path (
    $repoRoot
) "tests\test_sdk_godot_jolt_material_profiles.gd"
$publicationClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw27p_material_profile_publication_closure.json"
$expectedHashes = [ordered]@{
    $preregistrationPath = "c1d17fea278eccaf558e3a03013b088d1d4e63cafac2353f16b95a4906d2b4cb"
    $runnerPath = "d5ab360d1e94a8964b83f0143ba70ec8d45ef013fe5e28150bd2489fd8355ae7"
    $characterizationClosurePath = "5960c5d7f5b70f4d98356de884bb4d0c6fbc55f14d7060780efe07d6b278d519"
    $characterizationClosureAuditPath = "843e8deaa4f696600252cf691633a30264f47682f209e5dce0475c1ee90baeb6"
    $priorProfileClosurePath = "c8a0b9d64740a79562e2f07c85f366921cc585b5429e938a360a3489a1585cfa"
    $priorProfileClosureAuditPath = "bf9eea36d58acf8b8cbd5c6812256b3314c91a571f113b07660d523da6bf253d"
    $profileRegistryPath = "f465fa15c079d74574e3e401cbcce1b912bd50bd25b483a7f374842eec841de5"
    $profileTestPath = "68c546d05eaeb1d40d6132b94f6ec21e166a334b19f64ffb295f882b64a560a6"
    (Join-Path $sdkRoot "locomotion_operation_lock.ps1") =
        "105964dfcd3fdf0a4aca27cb369e2714d7ec0cc8bf7e0204e559f85567fa3e31"
    (Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1") =
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

function Write-NewJsonArtifact {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    Assert-Exact (-not (Test-Path -LiteralPath $Path)) (
        "Refusing to overwrite a $gateId artifact: $Path"
    )
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $temporaryPath = $Path + ".tmp"
    Assert-Exact (-not (Test-Path -LiteralPath $temporaryPath)) (
        "Refusing stale $gateId temporary artifact: $temporaryPath"
    )
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        (($Value | ConvertTo-Json -Depth 64) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporaryPath -Destination $Path
}

function Copy-JsonDocument {
    param([Parameter(Mandatory)][object]$Value)
    return (
        $Value | ConvertTo-Json -Depth 64 -Compress |
            ConvertFrom-Json -AsHashtable -Depth 64
    )
}

function Get-SyntheticOperationLockReceipt {
    $testMutexName = (
        "Global\SporeSpore.Locomotion.Test.BW27P_" +
        [Guid]::NewGuid().ToString("N")
    )
    $receipt = Enter-SporeSporeLocomotionOperationLock `
        -Role physical `
        -MutexName $testMutexName `
        -TestOnly
    try {
        Assert-Exact ([bool]$receipt.acquired) (
            "$gateId could not acquire its isolated synthetic lock"
        )
        return Get-SporeSporeLocomotionOperationLockPublicReceipt `
            -Receipt $receipt
    } finally {
        Exit-SporeSporeLocomotionOperationLock -Receipt $receipt
    }
}

function New-AttemptRecord {
    param(
        [Parameter(Mandatory)][bool]$Synthetic,
        [Parameter(Mandatory)][System.Collections.IDictionary]$OperationLock,
        [string]$SourceCommit = "",
        [string]$AttestationPath = "",
        [string]$AttestationSha256 = "",
        [string]$AttestationSourceCommit = "",
        [bool]$AttestationValidated = $false,
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
            "sporespore_balanced_wave_bw27p_material_profile_publication_attempt_v1"
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
        full_conformance_attestation_path = $AttestationPath
        full_conformance_attestation_raw_sha256 = $AttestationSha256
        full_conformance_attestation_source_commit = $AttestationSourceCommit
        full_conformance_attestation_validated = $AttestationValidated
        preregistration_raw_sha256 = Get-RawSha256 -Path $preregistrationPath
        characterization_closure_raw_sha256 =
            Get-RawSha256 -Path $characterizationClosurePath
        characterization_closure_audit_raw_sha256 =
            Get-RawSha256 -Path $characterizationClosureAuditPath
        prior_profile_closure_raw_sha256 =
            Get-RawSha256 -Path $priorProfileClosurePath
        prior_profile_closure_audit_raw_sha256 =
            Get-RawSha256 -Path $priorProfileClosureAuditPath
        profile_registry_raw_sha256 = Get-RawSha256 -Path $profileRegistryPath
        profile_test_raw_sha256 = Get-RawSha256 -Path $profileTestPath
        successor_conformance_runner_raw_sha256 = Get-RawSha256 -Path $runnerPath
        publication_supervisor_raw_sha256 = Get-RawSha256 -Path $supervisorPath
        operation_lock = $OperationLock
        complete_zero_world_gate_passed = $true
        attempt_contract_preflight_passed = $true
        expected_profile_count = 38
        expected_adapter_start_count = 39
        expected_gate_count = 49
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

function Invoke-AttemptValidation {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Attempt,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][bool]$ShouldPass,
        [Parameter(Mandatory)][string]$Root
    )
    $path = Join-Path $Root ("attempt-" + $Label + ".json")
    try {
        Write-NewJsonArtifact -Value $Attempt -Path $path
        $output = @(
            & pwsh `
                -NoLogo `
                -NoProfile `
                -File $runnerPath `
                -ValidateAttemptOnly `
                -PublicationAttempt $path 2>&1
        )
        $exitCode = $LASTEXITCODE
        if ($ShouldPass) {
            Assert-Exact (
                $exitCode -eq 0 -and
                (($output | Out-String) -match "ATTEMPT_CONTRACT_PASS")
            ) "$gateId perfect attempt contract failed: $Label"
        } else {
            Assert-Exact ($exitCode -ne 0) (
                "$gateId attempt canary did not fail closed: $Label"
            )
        }
    } finally {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}

function Assert-NoPriorAttempt {
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
                } catch { $false }
            }
        )
    }
    Assert-Exact ($priorAttempts.Count -eq 0) (
        "$gateId already has a retained publication attempt and may not rerun"
    )
}

Assert-Exact (
    [bool]$PreflightOnly -xor [bool]$Publish
) "Specify exactly one of -PreflightOnly or -Publish"
if ($Publish) {
    Assert-Exact (-not [string]::IsNullOrWhiteSpace($OutputRoot)) (
        "$gateId -Publish requires an explicit durable OutputRoot"
    )
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($FullConformanceAttestation)
    ) "$gateId -Publish requires an exact full-conformance attestation"
    Assert-Exact (
        -not (Test-Path -LiteralPath $publicationClosurePath -PathType Leaf)
    ) "$gateId publication is already closed and may not rerun"
}

$productionLock = $null
try {
if ($Publish) {
    $productionLock = Enter-SporeSporeLocomotionOperationLock -Role physical
    Assert-Exact ([bool]$productionLock.acquired) (
        "$gateId could not acquire the machine-wide publication/conformance mutex"
    )
}

foreach ($entry in $expectedHashes.GetEnumerator()) {
    Assert-Exact (
        (Test-Path -LiteralPath $entry.Key -PathType Leaf) -and
        (Get-RawSha256 -Path $entry.Key) -ceq [string]$entry.Value
    ) "$gateId frozen source or prerequisite changed: $($entry.Key)"
}
Assert-NoPriorAttempt

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw27p_material_profile_publication_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw27p_profile_publication_receipt" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [int]$preregistration.expected_conformance.total_profile_count -eq 38 -and
    [int]$preregistration.expected_conformance.adapter_start_count -eq 39 -and
    [int]$preregistration.expected_conformance.passed_gate_count -eq 49 -and
    [int]$preregistration.expected_conformance.failed_gate_count -eq 0 -and
    [int]$preregistration.attempt_contract_preflight.independent_negative_canary_count -eq 10 -and
    -not [bool]$preregistration.claims.profile_published -and
    -not [bool]$preregistration.claims.turning_acceptance -and
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

# Exercise the complete profile receipt and then the exact production parser.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -Godot $godotPath `
    -LogRoot (Join-Path $LogRoot "complete-gate")
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId complete zero-world gate failed"

$attemptRoot = Join-Path (
    [System.IO.Path]::GetFullPath($LogRoot)
) ("attempt-contract-" + [Guid]::NewGuid().ToString("N"))
[void][System.IO.Directory]::CreateDirectory($attemptRoot)
$syntheticLock = Get-SyntheticOperationLockReceipt
$perfectAttempt = New-AttemptRecord `
    -Synthetic $true `
    -OperationLock $syntheticLock
Invoke-AttemptValidation `
    -Attempt $perfectAttempt `
    -Label "perfect" `
    -ShouldPass $true `
    -Root $attemptRoot

$canaries = [ordered]@{
    wrong_profile_count = {
        param($value) $value.expected_profile_count = 35
    }
    missing_adapter_start_count = {
        param($value) [void]$value.Remove("expected_adapter_start_count")
    }
    wrong_adapter_start_count = {
        param($value) $value.expected_adapter_start_count = 36
    }
    wrong_gate_count = {
        param($value) $value.expected_gate_count = 46
    }
    wrong_campaign = {
        param($value) $value.campaign_id = "BW24P-BW24M-PROFILE-PUBLICATION-SUCCESSOR"
    }
    wrong_gate = {
        param($value) $value.gate_id = "BW24P-PROFILE"
    }
    preregistration_digest = {
        param($value) $value.preregistration_raw_sha256 = "0" * 64
    }
    characterization_closure_digest = {
        param($value) $value.characterization_closure_raw_sha256 = "0" * 64
    }
    prior_profile_closure_digest = {
        param($value) $value.prior_profile_closure_raw_sha256 = "0" * 64
    }
    unexpected_field = {
        param($value) $value["unexpected_publication_field"] = $true
    }
}
foreach ($entry in $canaries.GetEnumerator()) {
    $canary = Copy-JsonDocument -Value $perfectAttempt
    & $entry.Value $canary
    Invoke-AttemptValidation `
        -Attempt $canary `
        -Label ([string]$entry.Key) `
        -ShouldPass $false `
        -Root $attemptRoot
}
Assert-Exact ($canaries.Count -eq 10) (
    "$gateId independent canary cardinality changed"
)

if ($PreflightOnly) {
    Write-Host (
        "$gateId PREFLIGHT_PASS profiles=38 prior_profiles=35 " +
        "bw27m_profiles=3 gates=49 adapter_starts=39 canaries=10 " +
        "worlds=0 samples=0 commands=0 attempt_contract=True " +
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
    ) -and
    [System.IO.Path]::GetFullPath(
        (Split-Path -Parent $resolvedOutputRoot)
    ) -ceq $evidenceRoot -and
    -not $resolvedOutputRoot.StartsWith(
        "C:\tmp\",
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    -not (Test-Path -LiteralPath $resolvedOutputRoot)
) "$gateId OutputRoot must be new and inside $evidenceRoot"

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
$expectedLeaf = "balanced-wave-bw27p-material-profiles-" +
    $sourceCommit.Substring(0, 7)
Assert-Exact (
    (Split-Path -Leaf $resolvedOutputRoot) -ceq $expectedLeaf
) "$gateId OutputRoot must be named $expectedLeaf"

$resolvedAttestationPath = [System.IO.Path]::GetFullPath(
    $FullConformanceAttestation
)
$attestationVerification = Test-SporeSporeFullConformanceAttestationFile `
    -RepoRoot $repoRoot `
    -Godot $godotPath `
    -AttestationPath $resolvedAttestationPath
Assert-Exact (
    [bool]$attestationVerification.ok -and
    @($attestationVerification.failure_codes).Count -eq 0
) (
    "$gateId exact full-conformance attestation failed: " +
    (@($attestationVerification.failure_codes) -join ",")
)
$attestation = Get-Content -Raw -LiteralPath $resolvedAttestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.origin_main -ceq $sourceCommit -and
    [string]$attestation.source.live_github_main -ceq $sourceCommit -and
    [bool]$attestation.source.clean_pushed_live -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed
) "$gateId conformance attestation source or campaign boundary changed"
foreach ($claimName in $attestation.claims.Keys) {
    Assert-Exact (-not [bool]$attestation.claims[$claimName]) (
        "$gateId conformance attestation inflated claim: $claimName"
    )
}

$operationLockPublic = Get-SporeSporeLocomotionOperationLockPublicReceipt `
    -Receipt $productionLock
Assert-Exact (
    [bool]$operationLockPublic.acquired -and
    [string]$operationLockPublic.role -ceq "physical" -and
    -not [bool]$operationLockPublic.test_only -and
    -not [bool]$operationLockPublic.abandoned_owner_recovered
) "$gateId production operation-lock receipt is not clean"
Assert-NoPriorAttempt

[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)
$attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
$attempt = New-AttemptRecord `
    -Synthetic $false `
    -OperationLock $operationLockPublic `
    -SourceCommit $sourceCommit `
    -AttestationPath $resolvedAttestationPath `
    -AttestationSha256 (Get-RawSha256 -Path $resolvedAttestationPath) `
    -AttestationSourceCommit ([string]$attestation.source.commit) `
    -AttestationValidated $true `
    -GodotVersion $godotVersion `
    -GodotSha256 (Get-RawSha256 -Path $godotPath)
Write-NewJsonArtifact -Value $attempt -Path $attemptPath

$reportPath = Join-Path $resolvedOutputRoot "report.json"
& pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -Godot $godotPath `
    -LogRoot (Join-Path $resolvedOutputRoot "worker") `
    -Output $reportPath `
    -PublicationAuthorized `
    -PublicationAttempt $attemptPath
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    (Test-Path -LiteralPath $reportPath -PathType Leaf)
) "$gateId publication did not produce its retained report"

$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$receipt = $report.receipt
Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_godot_jolt_bw27p_material_profile_report_v1" -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.accepted -and
    [string]$report.result_status -ceq "passed" -and
    [bool]$receipt.ok -and
    [int]$receipt.observed_profile_count -eq 38 -and
    [int]$receipt.observed_adapter_start_count -eq 39 -and
    [int]$receipt.passed_gate_count -eq 49 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.observed_world_count -eq 0 -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.physical_acceptance_authority
) "$gateId retained report failed exact reconciliation"

$completionPath = Join-Path $resolvedOutputRoot "completion.json"
$completion = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw27p_material_profile_publication_completion_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    completed_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    report_path = "report.json"
    report_raw_sha256 = "sha256:" + (Get-RawSha256 -Path $reportPath)
    accepted = $true
    profile_count = 38
    prior_profile_count = 35
    bw27m_profile_count = 3
    adapter_start_count = 39
    passed_gate_count = 49
    failed_gate_count = 0
    world_build_count = 0
    sample_count = 0
    command_count = 0
    locomotion_seed_world_count = 0
    attempt_contract_preflight_passed = $true
    same_identity_rerun_allowed = $false
    physical_acceptance_authority = $false
}
Write-NewJsonArtifact -Value $completion -Path $completionPath

Write-Host (
    "$gateId PUBLICATION_COMPLETE profiles=38 prior_profiles=35 " +
    "bw27m_profiles=3 gates=49 worlds=0 samples=0 commands=0 " +
    "attempt_contract=True bw28y_manifest_next=True " +
    "material_robustness=False physical_authority=False report=$reportPath"
)
} finally {
    if ($null -ne $productionLock) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $productionLock
    }
}
