#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $PSScriptRoot "target\bw27p-material-profile-conformance"
    ),
    [string]$Output = "",
    [switch]$PublicationAuthorized,
    [string]$PublicationAttempt = "",
    [switch]$ValidateAttemptOnly,
    [string]$HistoricalSourceCommit = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
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
    $repoRoot
) "tests\test_bw27m_material_characterization_closure.ps1"
$priorProfileClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24p_material_profile_publication_closure.json"
$priorProfileClosureAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw24p_material_profile_publication_closure.ps1"
$profilesPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_material_profiles.gd"
$profileTestPath = Join-Path (
    $repoRoot
) "tests\test_sdk_godot_jolt_material_profiles.gd"
$characterizationReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw27m-material-characterization-a219ba8\report.json"
)
$priorProfileReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw24p-material-profiles-65cc27b\report.json"
)
$expectedProfileIds = @(
    "godot_jolt_bw27m_mu062_v1",
    "godot_jolt_bw27m_mu074_v1",
    "godot_jolt_bw27m_mu086_v1"
)
$expectedProfileSha256 = @(
    "sha256:62bd8b2543c7c3cdb9b389029e5ae3de777cbcc29c5a5ba5b769863442c854c3",
    "sha256:6a8128171b87ad824b3675cbf731927681b55c0f529d179e3dbb32c842752857",
    "sha256:29735973a8334064f1a1a1fb8c8d679c335e68b4a97a396c550f68b76321863d"
)
$expectedCells = @(
    [ordered]@{
        authored_friction = 0.62
        controller_mu = 0.61
        minimum_lower_ratio = 0.6119398367698766
        lower_force_n = 24.0
        upper_force_n = 25.0
    },
    [ordered]@{
        authored_friction = 0.74
        controller_mu = 0.73
        minimum_lower_ratio = 0.739513920992915
        lower_force_n = 29.0
        upper_force_n = 30.0
    },
    [ordered]@{
        authored_friction = 0.86
        controller_mu = 0.84
        minimum_lower_ratio = 0.8415623682133044
        lower_force_n = 33.0
        upper_force_n = 35.0
    }
)

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

function Assert-AttemptRecord {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Attempt,
        [Parameter(Mandatory)][bool]$Synthetic,
        [bool]$HistoricalSourceReceipt = $false
    )
    $expectedKeys = @(
        "schema_version", "campaign_id", "gate_id", "launched_at_utc",
        "source_commit", "origin_main_commit", "remote_main_commit",
        "source_worktree_clean", "source_matches_live_github_main",
        "godot_version", "godot_executable_sha256",
        "full_conformance_attestation_path",
        "full_conformance_attestation_raw_sha256",
        "full_conformance_attestation_source_commit",
        "full_conformance_attestation_validated",
        "preregistration_raw_sha256",
        "characterization_closure_raw_sha256",
        "characterization_closure_audit_raw_sha256",
        "prior_profile_closure_raw_sha256",
        "prior_profile_closure_audit_raw_sha256",
        "profile_registry_raw_sha256", "profile_test_raw_sha256",
        "successor_conformance_runner_raw_sha256",
        "publication_supervisor_raw_sha256",
        "operation_lock",
        "complete_zero_world_gate_passed", "attempt_contract_preflight_passed",
        "expected_profile_count", "expected_adapter_start_count",
        "expected_gate_count", "expected_world_count",
        "expected_sample_count", "expected_command_count",
        "locomotion_seed_world_count", "synthetic_contract_preflight",
        "publication_identity_consumed", "same_identity_rerun_allowed",
        "physical_acceptance_authority"
    ) | Sort-Object
    $actualKeys = @(
        $Attempt.Keys | ForEach-Object { [string]$_ }
    ) | Sort-Object
    $sourceReceiptBindingsValid = if ($HistoricalSourceReceipt) {
        -not $Synthetic -and
        [string]$Attempt.preregistration_raw_sha256 -cmatch "^[0-9a-f]{64}$" -and
        [string]$Attempt.profile_registry_raw_sha256 -cmatch "^[0-9a-f]{64}$" -and
        [string]$Attempt.profile_test_raw_sha256 -cmatch "^[0-9a-f]{64}$" -and
        [string]$Attempt.successor_conformance_runner_raw_sha256 -cmatch "^[0-9a-f]{64}$" -and
        [string]$Attempt.publication_supervisor_raw_sha256 -cmatch "^[0-9a-f]{64}$"
    } else {
        [string]$Attempt.preregistration_raw_sha256 -ceq
            (Get-RawSha256 -Path $preregistrationPath) -and
        [string]$Attempt.profile_registry_raw_sha256 -ceq
            (Get-RawSha256 -Path $profilesPath) -and
        [string]$Attempt.profile_test_raw_sha256 -ceq
            (Get-RawSha256 -Path $profileTestPath) -and
        [string]$Attempt.successor_conformance_runner_raw_sha256 -ceq
            (Get-RawSha256 -Path $runnerPath) -and
        [string]$Attempt.publication_supervisor_raw_sha256 -ceq
            (Get-RawSha256 -Path $supervisorPath)
    }
    Assert-Exact (
        ($actualKeys -join "|") -ceq ($expectedKeys -join "|")
    ) "$gateId publication attempt key set is invalid"
    Assert-Exact (
        [string]$Attempt.schema_version -ceq
            "sporespore_balanced_wave_bw27p_material_profile_publication_attempt_v1" -and
        [string]$Attempt.campaign_id -ceq $campaignId -and
        [string]$Attempt.gate_id -ceq $gateId -and
        -not [string]::IsNullOrWhiteSpace([string]$Attempt.launched_at_utc) -and
        [string]$Attempt.godot_version -ceq
            "4.7.stable.mono.official.5b4e0cb0f" -and
        [string]$Attempt.godot_executable_sha256 -ceq
            "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
        $sourceReceiptBindingsValid -and
        [string]$Attempt.characterization_closure_raw_sha256 -ceq
            "5960c5d7f5b70f4d98356de884bb4d0c6fbc55f14d7060780efe07d6b278d519" -and
        [string]$Attempt.characterization_closure_audit_raw_sha256 -ceq
            "843e8deaa4f696600252cf691633a30264f47682f209e5dce0475c1ee90baeb6" -and
        [string]$Attempt.prior_profile_closure_raw_sha256 -ceq
            "c8a0b9d64740a79562e2f07c85f366921cc585b5429e938a360a3489a1585cfa" -and
        [string]$Attempt.prior_profile_closure_audit_raw_sha256 -ceq
            "bf9eea36d58acf8b8cbd5c6812256b3314c91a571f113b07660d523da6bf253d" -and
        [string]$Attempt.operation_lock.schema_version -ceq
            "sporespore_locomotion_operation_lock_receipt_v1" -and
        [bool]$Attempt.operation_lock.acquired -and
        [string]$Attempt.operation_lock.role -ceq "physical" -and
        -not [bool]$Attempt.operation_lock.abandoned_owner_recovered -and
        [bool]$Attempt.operation_lock.test_only -eq $Synthetic -and
        -not [bool]$Attempt.operation_lock.physical_acceptance_authority -and
        [bool]$Attempt.complete_zero_world_gate_passed -and
        [bool]$Attempt.attempt_contract_preflight_passed -and
        [int]$Attempt.expected_profile_count -eq 38 -and
        [int]$Attempt.expected_adapter_start_count -eq 39 -and
        [int]$Attempt.expected_gate_count -eq 49 -and
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
            [string]::IsNullOrEmpty([string]$Attempt.full_conformance_attestation_path) -and
            [string]::IsNullOrEmpty([string]$Attempt.full_conformance_attestation_raw_sha256) -and
            [string]::IsNullOrEmpty([string]$Attempt.full_conformance_attestation_source_commit) -and
            -not [bool]$Attempt.full_conformance_attestation_validated -and
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
            -not [string]::IsNullOrWhiteSpace(
                [string]$Attempt.full_conformance_attestation_path
            ) -and
            [string]$Attempt.full_conformance_attestation_raw_sha256 -cmatch
                "^[0-9a-f]{64}$" -and
            [string]$Attempt.full_conformance_attestation_source_commit -ceq
                [string]$Attempt.source_commit -and
            [bool]$Attempt.full_conformance_attestation_validated -and
            [bool]$Attempt.source_worktree_clean -and
            [bool]$Attempt.source_matches_live_github_main
        ) "$gateId retained attempt source identity is invalid"
    }
}

# Historical attempt validation is deliberately source-commit based. It parses
# the retained receipt without treating today's checkout or filter state as the
# historical world-state. The calling closure audit independently verifies each
# declared blob through this exact commit before entering this mode.
if (-not [string]::IsNullOrWhiteSpace($HistoricalSourceCommit)) {
    Assert-Exact (
        $ValidateAttemptOnly -and
        -not [string]::IsNullOrWhiteSpace($PublicationAttempt) -and
        (Test-Path -LiteralPath $PublicationAttempt -PathType Leaf) -and
        [string]::IsNullOrWhiteSpace($Output) -and
        -not $PublicationAuthorized -and
        $HistoricalSourceCommit -cmatch "^[0-9a-f]{40}$"
    ) "$gateId historical attempt-validation parameters are invalid"
    & git -C $repoRoot cat-file -e "$HistoricalSourceCommit`^{commit}"
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId historical source commit is unavailable"
    $historicalAttempt = Get-Content -Raw -LiteralPath $PublicationAttempt |
        ConvertFrom-Json -AsHashtable -Depth 32
    Assert-Exact (
        -not [bool]$historicalAttempt.synthetic_contract_preflight -and
        [string]$historicalAttempt.source_commit -ceq $HistoricalSourceCommit
    ) "$gateId historical attempt source identity is invalid"
    Assert-AttemptRecord `
        -Attempt $historicalAttempt `
        -Synthetic $false `
        -HistoricalSourceReceipt $true
    Write-Host (
        "$gateId HISTORICAL_ATTEMPT_CONTRACT_PASS source=$HistoricalSourceCommit " +
        "profiles=38 adapter_starts=39 gates=49 worlds=0 physical_authority=False"
    )
    return
}

foreach ($requiredPath in @(
    $preregistrationPath,
    $runnerPath,
    $supervisorPath,
    $characterizationClosurePath,
    $characterizationClosureAuditPath,
    $priorProfileClosurePath,
    $priorProfileClosureAuditPath,
    $profilesPath,
    $profileTestPath,
    $characterizationReportPath,
    $priorProfileReportPath
)) {
    Assert-Exact (
        Test-Path -LiteralPath $requiredPath -PathType Leaf
    ) "$gateId prerequisite is missing: $requiredPath"
}

Assert-Exact (
    (Get-RawSha256 -Path $characterizationClosurePath) -ceq
        "5960c5d7f5b70f4d98356de884bb4d0c6fbc55f14d7060780efe07d6b278d519" -and
    (Get-RawSha256 -Path $characterizationClosureAuditPath) -ceq
        "843e8deaa4f696600252cf691633a30264f47682f209e5dce0475c1ee90baeb6" -and
    (Get-RawSha256 -Path $characterizationReportPath) -ceq
        "eb44e73c8494becd7d5bfc777f08630b3442cade64971a203079aadad29ccae3" -and
    (Get-RawSha256 -Path $priorProfileClosurePath) -ceq
        "c8a0b9d64740a79562e2f07c85f366921cc585b5429e938a360a3489a1585cfa" -and
    (Get-RawSha256 -Path $priorProfileClosureAuditPath) -ceq
        "bf9eea36d58acf8b8cbd5c6812256b3314c91a571f113b07660d523da6bf253d" -and
    (Get-RawSha256 -Path $priorProfileReportPath) -ceq
        "c0c5cc0df46b19222eb74a9d92c7165a76a56332fd611bea49a9c39450b1873f"
) "$gateId immutable prerequisite changed"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$profiles = @($preregistration.profiles)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw27p_material_profile_publication_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw27p_profile_publication_receipt" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.implementation_parent_commit -ceq
        "03b0f5c85d66f512017be5843f00adc0bedb85d3" -and
    $profiles.Count -eq 3 -and
    (@($profiles | ForEach-Object { [string]$_.profile_id }) -join "|") -ceq
        ($expectedProfileIds -join "|") -and
    (@($profiles | ForEach-Object { [string]$_.expected_profile_sha256 }) -join "|") -ceq
        ($expectedProfileSha256 -join "|") -and
    [int]$preregistration.expected_conformance.prior_profile_count -eq 35 -and
    [int]$preregistration.expected_conformance.total_profile_count -eq 38 -and
    [int]$preregistration.expected_conformance.adapter_start_count -eq 39 -and
    [int]$preregistration.expected_conformance.passed_gate_count -eq 49 -and
    [int]$preregistration.expected_conformance.failed_gate_count -eq 0 -and
    [int]$preregistration.attempt_contract_preflight.independent_negative_canary_count -eq 10 -and
    (@($preregistration.staged_interlocks.sealed_future_locomotion_seeds) -join ",") -ceq
        "27011,27012,27013,27014" -and
    -not [bool]$preregistration.claims.profile_published -and
    -not [bool]$preregistration.claims.walking_acceptance -and
    -not [bool]$preregistration.claims.turning_acceptance -and
    -not [bool]$preregistration.claims.physical_acceptance_authority
) "$gateId preregistration identity, payload, or claims changed"

if ($ValidateAttemptOnly) {
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($PublicationAttempt) -and
        (Test-Path -LiteralPath $PublicationAttempt -PathType Leaf) -and
        [string]::IsNullOrWhiteSpace($Output) -and
        -not $PublicationAuthorized
    ) "$gateId attempt-only validation parameters are invalid"
    $attemptOnly = Get-Content -Raw -LiteralPath $PublicationAttempt |
        ConvertFrom-Json -AsHashtable -Depth 32
    Assert-AttemptRecord `
        -Attempt $attemptOnly `
        -Synthetic ([bool]$attemptOnly.synthetic_contract_preflight)
    Write-Host (
        "$gateId ATTEMPT_CONTRACT_PASS synthetic=" +
        ([bool]$attemptOnly.synthetic_contract_preflight).ToString().ToLowerInvariant() +
        " profiles=38 adapter_starts=39 gates=49 worlds=0 physical_authority=False"
    )
    return
}

& pwsh -NoLogo -NoProfile -File $characterizationClosureAuditPath -Godot $Godot
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId characterization closure audit failed"
& pwsh -NoLogo -NoProfile -File $priorProfileClosureAuditPath
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId prior profile closure audit failed"

$characterization = Get-Content -Raw -LiteralPath $characterizationReportPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$characterizationReceipt = $characterization.receipt
Assert-Exact (
    [string]$characterization.schema_version -ceq
        "sporespore_balanced_wave_bw27m_material_characterization_report_v1" -and
    [string]$characterization.source_commit -ceq
        "a219ba86f8033971c6025edb4e45d04d651a73ee" -and
    [bool]$characterization.accepted -and
    [bool]$characterizationReceipt.ok -and
    [int]$characterizationReceipt.passed_gate_count -eq 19 -and
    [int]$characterizationReceipt.failed_gate_count -eq 0 -and
    [int]$characterizationReceipt.observed_world_count -eq 10 -and
    @($characterizationReceipt.positive_cells).Count -eq 3 -and
    -not [bool]$characterizationReceipt.material_robustness -and
    -not [bool]$characterizationReceipt.physical_acceptance_authority
) "$gateId characterization report failed its publication contract"
for ($index = 0; $index -lt $expectedCells.Count; $index++) {
    $expected = $expectedCells[$index]
    $observed = $characterizationReceipt.positive_cells[$index]
    $derivation = $observed.coefficient_derivation
    Assert-Exact (
        [bool]$observed.ok -and
        [bool]$derivation.ok -and
        [double]$observed.authored_friction -eq [double]$expected.authored_friction -and
        [double]$derivation.controller_mu -eq [double]$expected.controller_mu -and
        [double]$derivation.minimum_lower_ratio -eq [double]$expected.minimum_lower_ratio -and
        @($observed.replicates).Count -eq 3
    ) "$gateId characterization cell $index changed"
    foreach ($replicate in @($observed.replicates)) {
        Assert-Exact (
            [double]$replicate.breakaway_analysis.breakaway_force_lower_n -eq
                [double]$expected.lower_force_n -and
            [double]$replicate.breakaway_analysis.breakaway_force_upper_n -eq
                [double]$expected.upper_force_n
        ) "$gateId characterization bracket changed for cell $index"
    }
}

$priorProfileReport = Get-Content -Raw -LiteralPath $priorProfileReportPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$priorReceipt = $priorProfileReport.receipt
Assert-Exact (
    [bool]$priorProfileReport.accepted -and
    [bool]$priorReceipt.ok -and
    [int]$priorReceipt.observed_profile_count -eq 35 -and
    [int]$priorReceipt.observed_adapter_start_count -eq 36 -and
    [int]$priorReceipt.passed_gate_count -eq 46 -and
    [int]$priorReceipt.failed_gate_count -eq 0 -and
    @($priorReceipt.profile_ids).Count -eq 35 -and
    @($priorReceipt.profile_sha256).Count -eq 35
) "$gateId prior profile publication changed"

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

Push-Location -LiteralPath $sdkRoot
try {
    & cargo build -p sporespore-godot-adapter --offline
    Assert-Exact ($LASTEXITCODE -eq 0) "$gateId Godot adapter build failed"
} finally {
    Pop-Location
}

$timestamp = Get-Date -Format "yyyyMMddTHHmmssfff"
$runRoot = Join-Path ([System.IO.Path]::GetFullPath($LogRoot)) $timestamp
$projectRoot = Join-Path $runRoot "project"
[void][System.IO.Directory]::CreateDirectory($projectRoot)
foreach ($directory in @("scripts", "tests", "sdk")) {
    [void](New-Item -ItemType Junction -Path (
        Join-Path $projectRoot $directory
    ) -Target (Join-Path $repoRoot $directory))
}
$projectText = @'
; Isolated BW27P zero-world immutable material-profile conformance.

config_version=5

[application]

config/name="sporespore-bw27p-material-profiles"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
'@
[System.IO.File]::WriteAllText(
    (Join-Path $projectRoot "project.godot"),
    $projectText,
    [System.Text.UTF8Encoding]::new($false)
)

$appData = Join-Path $runRoot "worker\appdata"
$localAppData = Join-Path $runRoot "worker\localappdata"
[void][System.IO.Directory]::CreateDirectory($appData)
[void][System.IO.Directory]::CreateDirectory($localAppData)
$transcriptPath = Join-Path $runRoot "transcript.log"
$engineLogPath = Join-Path $runRoot "engine.log"
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $appData
    $env:LOCALAPPDATA = $localAppData
    & $godotPath `
        --headless `
        --path $projectRoot `
        --log-file $engineLogPath `
        --script "res://tests/test_sdk_godot_jolt_material_profiles.gd" `
        2>&1 | Tee-Object -FilePath $transcriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

$receiptLines = @(
    Get-Content -LiteralPath $transcriptPath |
        Where-Object { $_.StartsWith("SDK_MATERIAL_PROFILE_RECEIPT ") }
)
Assert-Exact (
    $receiptLines.Count -eq 1
) "$gateId expected exactly one material-profile receipt"
$receipt = $receiptLines[0].Substring(
    "SDK_MATERIAL_PROFILE_RECEIPT ".Length
) | ConvertFrom-Json -AsHashtable -Depth 64
$priorIds = @($receipt.profile_ids | Select-Object -First 35)
$priorDigests = @($receipt.profile_sha256 | Select-Object -First 35)
$newIds = @($receipt.profile_ids | Select-Object -Last 3)
$newDigests = @($receipt.profile_sha256 | Select-Object -Last 3)
$receiptPassed = (
    $godotExitCode -eq 0 -and
    [string]$receipt.schema_version -ceq
        "sporespore_godot_jolt_material_profile_receipt_v1" -and
    [bool]$receipt.ok -and
    [int]$receipt.passed_gate_count -eq 49 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_gate_count -eq 49 -and
    [int]$receipt.expected_profile_count -eq 38 -and
    [int]$receipt.observed_profile_count -eq 38 -and
    [int]$receipt.expected_adapter_start_count -eq 39 -and
    [int]$receipt.observed_adapter_start_count -eq 39 -and
    [int]$receipt.expected_world_count -eq 0 -and
    [int]$receipt.observed_world_count -eq 0 -and
    [int]$receipt.observed_sample_count -eq 0 -and
    [int]$receipt.observed_command_count -eq 0 -and
    ($priorIds -join "|") -ceq (@($priorReceipt.profile_ids) -join "|") -and
    ($priorDigests -join "|") -ceq (@($priorReceipt.profile_sha256) -join "|") -and
    ($newIds -join "|") -ceq ($expectedProfileIds -join "|") -and
    ($newDigests -join "|") -ceq ($expectedProfileSha256 -join "|") -and
    @($receipt.profile_sha256 | Select-Object -Unique).Count -eq 38 -and
    [int]$receipt.bw27m_profile_count -eq 3 -and
    [bool]$receipt.bw27m_fresh_material_profile_publication -and
    [string]$receipt.physics_engine -ceq "Jolt Physics" -and
    [int]$receipt.physics_hz -eq 120 -and
    [int]$receipt.solver_velocity_steps -eq 20 -and
    [int]$receipt.solver_position_steps -eq 7 -and
    -not [bool]$receipt.adapter_actuation_applied -and
    -not [bool]$receipt.physics_transform_or_velocity_written -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.locomotion_robustness -and
    -not [bool]$receipt.continuous_friction_coverage -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.completed_engine_neutral_sdk
)
Assert-Exact $receiptPassed "$gateId complete zero-world receipt failed"

if ([string]::IsNullOrWhiteSpace($Output)) {
    Assert-Exact (
        -not $PublicationAuthorized -and
        [string]::IsNullOrWhiteSpace($PublicationAttempt)
    ) "$gateId publication authorization is valid only with -Output"
    Write-Host (
        "$gateId CONFORMANCE_PASS profiles=38 prior_profiles=35 " +
        "bw27m_profiles=3 gates=49 adapter_starts=39 worlds=0 samples=0 " +
        "commands=0 locomotion_seeds_opened=0 physical_authority=False"
    )
    return
}

$outputPath = [System.IO.Path]::GetFullPath($Output)
$outputDirectory = Split-Path -Parent $outputPath
$expectedAttemptPath = Join-Path $outputDirectory "attempt.json"
$resolvedAttemptPath = if ([string]::IsNullOrWhiteSpace($PublicationAttempt)) {
    ""
} else {
    [System.IO.Path]::GetFullPath($PublicationAttempt)
}
Assert-Exact (
    $PublicationAuthorized -and
    $resolvedAttemptPath -ceq $expectedAttemptPath -and
    (Test-Path -LiteralPath $resolvedAttemptPath -PathType Leaf)
) "$gateId retained publication requires the supervisor's sibling attempt receipt"
$attempt = Get-Content -Raw -LiteralPath $resolvedAttemptPath |
    ConvertFrom-Json -AsHashtable -Depth 32
Assert-AttemptRecord -Attempt $attempt -Synthetic $false

$status = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all)
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
$remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$remoteMain = ($remoteLine -split "\s+")[0]
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $status.Count -eq 0 -and
    $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
    $sourceCommit -ceq $originMain -and
    $sourceCommit -ceq $remoteMain -and
    [string]$attempt.source_commit -ceq $sourceCommit
) "$gateId retained evidence requires clean source matching live GitHub main"
Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "report.json" -and
    -not (Test-Path -LiteralPath $outputPath)
) "$gateId refuses an invalid or existing report path"

[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$retainedTranscriptPath = Join-Path $outputDirectory "transcript.log"
$retainedEngineLogPath = Join-Path $outputDirectory "engine.log"
[System.IO.File]::Copy($transcriptPath, $retainedTranscriptPath, $false)
[System.IO.File]::Copy($engineLogPath, $retainedEngineLogPath, $false)
$sourcePaths = [ordered]@{
    preregistration = "sdk/balanced_wave_bw27p_material_profile_publication_preregistration.json"
    characterization_closure = "sdk/balanced_wave_bw27m_material_characterization_closure.json"
    characterization_closure_audit = "tests/test_bw27m_material_characterization_closure.ps1"
    prior_profile_closure = "sdk/balanced_wave_bw24p_material_profile_publication_closure.json"
    prior_profile_closure_audit = "tests/test_bw24p_material_profile_publication_closure.ps1"
    profiles = "scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
    adapter = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
    canonical_json = "scripts/lab/canonical_json.gd"
    test = "tests/test_sdk_godot_jolt_material_profiles.gd"
    runner = "sdk/run_godot_jolt_bw27p_material_profile_conformance.ps1"
    supervisor = "sdk/run_balanced_wave_bw27p_material_profile_publication.ps1"
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
    schema_version = "sporespore_godot_jolt_bw27p_material_profile_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    campaign_id = $campaignId
    gate_id = $gateId
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    source_matches_live_github_main = $true
    accepted = $true
    result_status = "passed"
    godot_exit_code = $godotExitCode
    stopping_rule =
        "zero_world_profile_conformance_after_bw27m_characterization_closure_before_bw28y_locomotion"
    attempt_contract = [ordered]@{
        path = "attempt.json"
        sha256 = Get-RawSha256 -Path $resolvedAttemptPath
        preflight_passed = $true
        expected_profile_count = 38
        expected_adapter_start_count = 39
        expected_gate_count = 49
        publication_identity_consumed = $true
    }
    prerequisite_evidence = [ordered]@{
        bw27m_material_characterization = [ordered]@{
            path = $characterizationReportPath
            sha256 = Get-RawSha256 -Path $characterizationReportPath
            source_commit = [string]$characterization.source_commit
            closure_path = $characterizationClosurePath
            closure_sha256 = Get-RawSha256 -Path $characterizationClosurePath
            profile_publication_authorized = $true
        }
        prior_material_profile_publication = [ordered]@{
            path = $priorProfileReportPath
            sha256 = Get-RawSha256 -Path $priorProfileReportPath
            closure_path = $priorProfileClosurePath
            closure_sha256 = Get-RawSha256 -Path $priorProfileClosurePath
            prior_profile_count = 35
            identities_unchanged = $true
        }
    }
    godot = [ordered]@{
        executable_path = $godotPath
        executable_sha256 = Get-RawSha256 -Path $godotPath
        version = $godotVersion
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
    receipt = $receipt
}
$temporaryOutputPath = $outputPath + ".tmp"
Assert-Exact (
    -not (Test-Path -LiteralPath $temporaryOutputPath)
) "$gateId refuses a stale temporary report"
[System.IO.File]::WriteAllText(
    $temporaryOutputPath,
    (($report | ConvertTo-Json -Depth 64) + [Environment]::NewLine),
    [System.Text.UTF8Encoding]::new($false)
)
Move-Item -LiteralPath $temporaryOutputPath -Destination $outputPath
Write-Host (
    "$gateId RETAINED_REPORT_PASS profiles=38 prior_profiles=35 " +
    "bw27m_profiles=3 gates=49 worlds=0 samples=0 commands=0 report=$outputPath"
)
