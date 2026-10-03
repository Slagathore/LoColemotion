#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Bw22mCharacterization = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw22m-material-characterization-ff9a2cc\report.json"
    ),
    [string]$PriorProfileReport = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw20f-material-profiles-cf9431e\report.json"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_bw22m_material_profiles"
    ),
    [string]$Output = "",
    [switch]$PublicationAuthorized,
    [string]$PublicationAttempt = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$gateId = "BW22M-PROFILE"
$campaignId = "BW22M-BW21L-FRESH-MATERIAL-PROFILE-PUBLICATION"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw22m_material_profile_publication_preregistration.json"
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
$profilesPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_material_profiles.gd"
$profileTestPath = Join-Path (
    $repoRoot
) "tests\test_sdk_godot_jolt_material_profiles.gd"
$adapterPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_adapter.gd"
$canonicalJsonPath = Join-Path $repoRoot "scripts\lab\canonical_json.gd"
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

function Wait-ForNonLspGodotDrain {
    param([int]$TimeoutSeconds = 30)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($true) {
        $blocking = @(
            Get-CimInstance Win32_Process |
                Where-Object {
                    $_.Name -match "^Godot.*\.exe$" -and
                    $_.CommandLine -like "*$repoRoot*" -and
                    $_.CommandLine -notlike "*--lsp-port*"
                }
        )
        if ($blocking.Count -eq 0) {
            return
        }
        if ([DateTime]::UtcNow -ge $deadline) {
            throw (
                "$gateId timed out waiting for prior non-LSP Godot workers: " +
                (($blocking.ProcessId | Sort-Object) -join ",")
            )
        }
        Start-Sleep -Milliseconds 250
    }
}

Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf)
) "$gateId preregistration is missing"
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$declaredProfiles = @($preregistration.profiles)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw22m_material_profile_publication_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw22m_profile_publication_receipt" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.implementation_parent_commit -ceq
        "de92b10a275c682dd9a6fc18be6408a24acf2c50" -and
    [string]$preregistration.study_classification -ceq
        "deterministic_zero_world_adapter_profile_publication" -and
    [int]$preregistration.world_build_count -eq 0 -and
    [int]$preregistration.locomotion_seed_world_count -eq 0 -and
    [int]$preregistration.expected_conformance.prior_profile_count -eq 29 -and
    [int]$preregistration.expected_conformance.bw22m_profile_count -eq 3 -and
    [int]$preregistration.expected_conformance.total_profile_count -eq 32 -and
    [int]$preregistration.expected_conformance.adapter_start_count -eq 33 -and
    [int]$preregistration.expected_conformance.passed_gate_count -eq 43 -and
    [int]$preregistration.expected_conformance.failed_gate_count -eq 0 -and
    $declaredProfiles.Count -eq 3 -and
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

Assert-Exact (
    (Test-Path -LiteralPath $characterizationClosurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $characterizationClosurePath) -ceq
        "86e309bf68098338b570884429d608ac659916690c21b00f2c6077c4a35b09e6"
) "$gateId characterization closure is missing or changed"
& pwsh -NoProfile -File $characterizationClosureAuditPath
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId characterization closure audit failed"
$characterizationClosure = Get-Content -Raw -LiteralPath (
    $characterizationClosurePath
) | ConvertFrom-Json -AsHashtable
Assert-Exact (
    [string]$characterizationClosure.status -ceq
        "closed_complete_valid_positive_exact_finite_adapter_material_characterization" -and
    [string]$characterizationClosure.physical_source_commit -ceq
        "ff9a2cca466984e863ffb4c9063267231186618f" -and
    [bool]$characterizationClosure.scientific_disposition.adapter_profile_publication_authorized -and
    -not [bool]$characterizationClosure.same_identity_rerun_allowed -and
    -not [bool]$characterizationClosure.scientific_disposition.material_robustness_established -and
    -not [bool]$characterizationClosure.scientific_disposition.physical_acceptance_authority
) "$gateId characterization closure does not authorize bounded publication"

$characterizationPath = [System.IO.Path]::GetFullPath($Bw22mCharacterization)
Assert-Exact (
    (Test-Path -LiteralPath $characterizationPath -PathType Leaf) -and
    (Get-RawSha256 -Path $characterizationPath) -ceq
        "cfce09d78192aaf280f44e4ec310e0c5760c687892b5f8b3d346cbaa13a1c03c"
) "$gateId characterization report is missing or changed"
$characterization = Get-Content -Raw -LiteralPath $characterizationPath |
    ConvertFrom-Json -AsHashtable
$characterizationReceipt = $characterization.receipt
$expectedCells = @(
    [ordered]@{
        authored_friction = 0.57
        controller_mu = 0.56
        minimum_lower_ratio = 0.5609241215877279
        lower_force_n = 22.0
        upper_force_n = 23.0
    },
    [ordered]@{
        authored_friction = 0.69
        controller_mu = 0.68
        minimum_lower_ratio = 0.6884900746592023
        lower_force_n = 27.0
        upper_force_n = 28.0
    },
    [ordered]@{
        authored_friction = 0.81
        controller_mu = 0.79
        minimum_lower_ratio = 0.7905503689593908
        lower_force_n = 31.0
        upper_force_n = 33.0
    }
)
Assert-Exact (
    [string]$characterization.schema_version -ceq
        "sporespore_balanced_wave_bw22m_material_characterization_report_v1" -and
    [string]$characterization.source_commit -ceq
        "ff9a2cca466984e863ffb4c9063267231186618f" -and
    [bool]$characterization.source_worktree_clean -and
    [bool]$characterization.source_matches_origin_main -and
    [bool]$characterization.accepted -and
    [string]$characterization.result_status -ceq "passed" -and
    [string]$characterizationReceipt.schema_version -ceq
        "sporespore_balanced_wave_bw22m_material_characterization_receipt_v1" -and
    [bool]$characterizationReceipt.ok -and
    [int]$characterizationReceipt.passed_gate_count -eq 19 -and
    [int]$characterizationReceipt.failed_gate_count -eq 0 -and
    [int]$characterizationReceipt.expected_gate_count -eq 19 -and
    [int]$characterizationReceipt.observed_world_count -eq 10 -and
    [bool]$characterizationReceipt.cold_characterization -and
    -not [bool]$characterizationReceipt.development_data_only -and
    -not [bool]$characterizationReceipt.material_robustness -and
    -not [bool]$characterizationReceipt.continuous_friction_coverage -and
    -not [bool]$characterizationReceipt.cross_engine_equivalence -and
    -not [bool]$characterizationReceipt.physical_acceptance_authority -and
    @($characterizationReceipt.positive_cells).Count -eq 3
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
        @($observed.replicates).Count -eq 3 -and
        -not [bool]$derivation.cross_engine_equivalent -and
        -not [bool]$derivation.locomotion_robustness
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

Assert-Exact (
    (Test-Path -LiteralPath $priorProfileClosurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $priorProfileClosurePath) -ceq
        "d5e08e0602f745e78b1c34cc10a95f1399a969f9ccab0fd62ff68f6a53e25f1e"
) "$gateId prior profile closure is missing or changed"
& pwsh -NoProfile -File $priorProfileClosureAuditPath
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId prior profile closure audit failed"
$priorProfilePath = [System.IO.Path]::GetFullPath($PriorProfileReport)
Assert-Exact (
    (Test-Path -LiteralPath $priorProfilePath -PathType Leaf) -and
    (Get-RawSha256 -Path $priorProfilePath) -ceq
        "96ef9fd50da7e92b668d9552ebf821d8fe02fa8ab0a2247b93cda0a48115968f"
) "$gateId prior profile report is missing or changed"
$priorProfileReportValue = Get-Content -Raw -LiteralPath $priorProfilePath |
    ConvertFrom-Json -AsHashtable
$priorReceipt = $priorProfileReportValue.receipt
Assert-Exact (
    [bool]$priorProfileReportValue.accepted -and
    [string]$priorProfileReportValue.result_status -ceq "passed" -and
    [bool]$priorReceipt.ok -and
    [int]$priorReceipt.observed_profile_count -eq 29 -and
    [int]$priorReceipt.passed_gate_count -eq 40 -and
    [int]$priorReceipt.failed_gate_count -eq 0 -and
    @($priorReceipt.profile_ids).Count -eq 29 -and
    @($priorReceipt.profile_sha256).Count -eq 29
) "$gateId prior profile receipt changed"

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

Wait-ForNonLspGodotDrain
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
; Isolated BW22M zero-world immutable material-profile conformance.

config_version=5

[application]

config/name="sporespore-bw22m-material-profiles"
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
) | ConvertFrom-Json -AsHashtable
$priorIds = @($receipt.profile_ids | Select-Object -First 29)
$priorDigests = @($receipt.profile_sha256 | Select-Object -First 29)
$newIds = @($receipt.profile_ids | Select-Object -Last 3)
$newDigests = @($receipt.profile_sha256 | Select-Object -Last 3)
$receiptPassed = (
    $godotExitCode -eq 0 -and
    [string]$receipt.schema_version -ceq
        "sporespore_godot_jolt_material_profile_receipt_v1" -and
    [bool]$receipt.ok -and
    [int]$receipt.passed_gate_count -eq 43 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_gate_count -eq 43 -and
    [int]$receipt.expected_profile_count -eq 32 -and
    [int]$receipt.observed_profile_count -eq 32 -and
    [int]$receipt.expected_adapter_start_count -eq 33 -and
    [int]$receipt.observed_adapter_start_count -eq 33 -and
    [int]$receipt.expected_world_count -eq 0 -and
    [int]$receipt.observed_world_count -eq 0 -and
    [int]$receipt.observed_sample_count -eq 0 -and
    [int]$receipt.observed_command_count -eq 0 -and
    @($receipt.profile_ids).Count -eq 32 -and
    @($receipt.profile_sha256).Count -eq 32 -and
    ($priorIds -join "|") -ceq (@($priorReceipt.profile_ids) -join "|") -and
    ($priorDigests -join "|") -ceq (@($priorReceipt.profile_sha256) -join "|") -and
    ($newIds -join "|") -ceq ($expectedProfileIds -join "|") -and
    ($newDigests -join "|") -ceq ($expectedProfileSha256 -join "|") -and
    @($receipt.profile_sha256 | Select-Object -Unique).Count -eq 32 -and
    [int]$receipt.bw20f_profile_count -eq 4 -and
    [int]$receipt.bw22m_profile_count -eq 3 -and
    [bool]$receipt.bw20f_cold_successor_profile_publication -and
    [bool]$receipt.bw22m_fresh_material_profile_publication -and
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
    -not [bool]$receipt.rough_terrain_robustness -and
    -not [bool]$receipt.external_push_recovery -and
    -not [bool]$receipt.sensor_fault_robustness -and
    -not [bool]$receipt.fresh_morphology_validation -and
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
        "$gateId CONFORMANCE_PASS profiles=32 prior_profiles=29 " +
        "bw22m_profiles=3 gates=43 adapter_starts=33 worlds=0 " +
        "samples=0 commands=0 locomotion_seeds_opened=0 " +
        "physical_authority=False"
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
    ConvertFrom-Json -AsHashtable
Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw22m_material_profile_publication_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [int]$attempt.expected_profile_count -eq 32 -and
    [int]$attempt.expected_gate_count -eq 43 -and
    [int]$attempt.expected_world_count -eq 0 -and
    [int]$attempt.locomotion_seed_world_count -eq 0 -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.publication_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    -not [bool]$attempt.physical_acceptance_authority
) "$gateId publication attempt receipt is invalid"

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
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit
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
    preregistration = "sdk/balanced_wave_bw22m_material_profile_publication_preregistration.json"
    characterization_closure = "sdk/balanced_wave_bw22m_material_characterization_closure.json"
    characterization_closure_audit = "tests/test_bw22m_material_characterization_closure.ps1"
    prior_profile_closure = "sdk/balanced_wave_bw20f_material_profile_publication_closure.json"
    prior_profile_closure_audit = "tests/test_bw20f_material_profile_publication_closure.ps1"
    profiles = "scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
    adapter = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
    canonical_json = "scripts/lab/canonical_json.gd"
    test = "tests/test_sdk_godot_jolt_material_profiles.gd"
    runner = "sdk/run_godot_jolt_bw22m_material_profile_conformance.ps1"
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
    schema_version = "sporespore_godot_jolt_bw22m_material_profile_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    source_matches_live_github_main = $true
    accepted = $true
    result_status = "passed"
    godot_exit_code = $godotExitCode
    stopping_rule =
        "zero_world_profile_conformance_after_bw22m_characterization_closure_before_bw22l_locomotion"
    prerequisite_evidence = [ordered]@{
        bw22m_material_characterization = [ordered]@{
            path = $characterizationPath
            sha256 = Get-RawSha256 -Path $characterizationPath
            source_commit = [string]$characterization.source_commit
            closure_path = $characterizationClosurePath
            closure_sha256 = Get-RawSha256 -Path $characterizationClosurePath
            profile_publication_authorized = $true
        }
        prior_material_profile_publication = [ordered]@{
            path = $priorProfilePath
            sha256 = Get-RawSha256 -Path $priorProfilePath
            closure_path = $priorProfileClosurePath
            closure_sha256 = Get-RawSha256 -Path $priorProfileClosurePath
            prior_profile_count = 29
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
    (($report | ConvertTo-Json -Depth 40) + [Environment]::NewLine),
    [System.Text.UTF8Encoding]::new($false)
)
Move-Item -LiteralPath $temporaryOutputPath -Destination $outputPath
Write-Host (
    "$gateId RETAINED_REPORT_PASS profiles=32 bw22m_profiles=3 gates=43 " +
    "worlds=0 samples=0 commands=0 report=$outputPath"
)
