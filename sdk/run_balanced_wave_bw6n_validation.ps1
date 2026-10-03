#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_balanced_wave_bw6n_validation"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$manifestPath = Join-Path $sdkRoot "balanced_wave_bw6n_validation_manifest.json"
$contractTestPath = "tests/test_sdk_balanced_wave_bw5r_authority_contract.gd"
$validationTestPath = "tests/test_sdk_balanced_wave_bw6n_validation.gd"
$expectedManifestHash =
    "83886d8c893a4a6e5a960b06b3398d907a203a865e1ac66ed1870ea09dc3d38e"
$expectedPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$expectedPolicyDigest =
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
$expectedCellIds = @(
    "baseline_s21001",
    "baseline_s21002",
    "baseline_s21003",
    "rough_s21001",
    "rough_s21002",
    "rough_s21003",
    "push_s21001",
    "push_s21002",
    "push_s21003",
    "sensor_noise_s21001",
    "sensor_noise_s21002",
    "sensor_noise_s21003"
)

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "BW6N validation manifest not found: $manifestPath"
}
if ($PreflightOnly -and -not [string]::IsNullOrWhiteSpace($Output)) {
    throw "BW6N preflight cannot retain a physics report"
}
if (-not $PreflightOnly -and [string]::IsNullOrWhiteSpace($Output)) {
    throw "The full BW6N run requires a durable -Output report.json path"
}

$manifestHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $manifestPath
).Hash.ToLowerInvariant()
if ($manifestHash -cne $expectedManifestHash) {
    throw "BW6N manifest hash does not match the frozen test/runner identity"
}
$manifest = Get-Content -Raw -LiteralPath $manifestPath |
    ConvertFrom-Json -AsHashtable
$prerequisite = $manifest.prerequisite_evidence.bw5c_cold_acceptance
$prerequisitePath = [System.IO.Path]::GetFullPath([string]$prerequisite.path)
if (-not (Test-Path -LiteralPath $prerequisitePath -PathType Leaf)) {
    throw "BW6N prerequisite report is missing: $prerequisitePath"
}
$prerequisiteHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $prerequisitePath
).Hash.ToLowerInvariant()
$manifestCellIds = @(
    $manifest.matrix.ordered_cell_ids | ForEach-Object { [string]$_ }
)
$manifestSeeds = @($manifest.matrix.seeds | ForEach-Object { [int]$_ })
$manifestProfileIds = @(
    $manifest.challenge_profiles |
        ForEach-Object { [string]$_.challenge_profile_id }
)
$manifestContractPassed = (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw6n_validation_manifest_v1" -and
    [string]$manifest.status -ceq "frozen_before_first_bw6n_world" -and
    [string]$manifest.freeze_parent_commit -ceq
        "24ddd46db1ae86f7d2303cda76cd01fbdbb30f3f" -and
    -not [bool]$manifest.locomotion_outcome_exposed -and
    [string]$manifest.selected_policy.candidate_id -ceq "BW5R-B" -and
    [string]$manifest.selected_policy.policy_id -ceq $expectedPolicyId -and
    [string]$manifest.selected_policy.policy_digest -ceq
        $expectedPolicyDigest -and
    $prerequisiteHash -ceq [string]$prerequisite.sha256 -and
    [bool]$prerequisite.accepted -and
    [string]$manifest.material_profile.profile_id -ceq
        "godot_jolt_bw5c_mu095_v1" -and
    ($manifestProfileIds -join ",") -ceq
        "bw6n_baseline_v1,bw6n_rough_v1,bw6n_push_v1,bw6n_sensor_noise_v1" -and
    ($manifestCellIds -join ",") -ceq ($expectedCellIds -join ",") -and
    ($manifestSeeds -join ",") -ceq "21001,21002,21003" -and
    [int]$manifest.matrix.expected_world_count -eq 12 -and
    [int]$manifest.matrix.expected_sdk_exposure_steps -eq 1514 -and
    [int]$manifest.gate_contract.expected_gate_count -eq 24 -and
    [int]$manifest.gate_contract.preflight_gate_count -eq 3 -and
    [int]$manifest.gate_contract.per_world_execution_integrity_gate_count -eq 12 -and
    [int]$manifest.gate_contract.aggregate_gate_count -eq 9 -and
    [bool]$manifest.matrix.averaging_forbidden -and
    [bool]$manifest.matrix.failed_cell_replacement_forbidden -and
    [bool]$manifest.matrix.post_result_gate_edit_forbidden -and
    [bool]$manifest.matrix.first_result_is_final_for_this_source_identity
)
if (-not $manifestContractPassed) {
    throw "BW6N manifest or prerequisite identity failed strict reconciliation"
}

$prerequisiteReport = Get-Content -Raw -LiteralPath $prerequisitePath |
    ConvertFrom-Json -AsHashtable
$prerequisiteAccepted = (
    [string]$prerequisiteReport.schema_version -ceq
        "sporespore_balanced_wave_bw5c_validation_report_v1" -and
    [bool]$prerequisiteReport.accepted -and
    [string]$prerequisiteReport.result_status -ceq "cold_acceptance_passed" -and
    [int]$prerequisiteReport.receipt.passed_gate_count -eq 28 -and
    [int]$prerequisiteReport.receipt.failed_gate_count -eq 0 -and
    [int]$prerequisiteReport.receipt.observed_world_count -eq 17
)
if (-not $prerequisiteAccepted) {
    throw "The pinned BW5C prerequisite is not an accepted cold report"
}

$sourceCommit = ""
$outputPath = ""
$outputDirectory = ""
if (-not $PreflightOnly) {
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    if ($LASTEXITCODE -ne 0 -or $sourceStatus.Count -ne 0) {
        throw "Refusing to open BW6N worlds from dirty source"
    }
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($sourceCommit) -or
        $sourceCommit -cne $originMain
    ) {
        throw "Refusing BW6N because HEAD does not match origin/main"
    }
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained BW6N report filename must be exactly report.json"
    }
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to overwrite an existing BW6N report: $outputPath"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        $existing = @(Get-ChildItem -LiteralPath $outputDirectory -Force)
        if ($existing.Count -ne 0) {
            throw "Refusing a nonempty BW6N evidence directory: $outputDirectory"
        }
    }
}

Push-Location -LiteralPath $sdkRoot
try {
    & cargo build -p sporespore-godot-adapter --offline
    if ($LASTEXITCODE -ne 0) {
        throw "Godot adapter build failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

$timestamp = Get-Date -Format "yyyyMMddTHHmmssfff"
$runRoot = Join-Path ([System.IO.Path]::GetFullPath($LogRoot)) $timestamp
$projectRoot = Join-Path $runRoot "project"
[void][System.IO.Directory]::CreateDirectory($projectRoot)
foreach ($directory in @("scripts", "tests", "sdk")) {
    [void](New-Item `
        -ItemType Junction `
        -Path (Join-Path $projectRoot $directory) `
        -Target (Join-Path $repoRoot $directory))
}
$projectText = @'
; Isolated SporeSpore balanced-wave BW6N nuisance acceptance.

config_version=5

[application]

config/name="sporespore-balanced-wave-bw6n-validation"
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
$contractTranscriptPath = Join-Path $runRoot "contract-transcript.log"
$validationTranscriptPath = Join-Path $runRoot "validation-transcript.log"
$engineLogPath = Join-Path $runRoot "engine.log"
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $appData
    $env:LOCALAPPDATA = $localAppData
    & $godotPath `
        --headless `
        --path $projectRoot `
        --script "res://$contractTestPath" `
        2>&1 | Tee-Object -FilePath $contractTranscriptPath
    if ($LASTEXITCODE -ne 0) {
        throw "BW5R-B no-world contract failed before BW6N"
    }
    $validationArguments = @(
        "--headless",
        "--path", $projectRoot,
        "--log-file", $engineLogPath,
        "--script", "res://$validationTestPath",
        "--"
    )
    if ($PreflightOnly) {
        $validationArguments += "--preflight-only"
    }
    $validationArguments += "--bw5r-b"
    & $godotPath @validationArguments 2>&1 |
        Tee-Object -FilePath $validationTranscriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

$retainedContractTranscript = ""
$retainedValidationTranscript = ""
$retainedEngineLog = ""
if (-not $PreflightOnly) {
    # Preserve the first physical attempt before parsing its receipt. If Godot
    # exits abnormally or emits a malformed receipt, the raw evidence still
    # survives in the durable output directory and must be audited, not rerun.
    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
    $retainedContractTranscript = Join-Path $outputDirectory "contract-transcript.log"
    $retainedValidationTranscript = Join-Path $outputDirectory "validation-transcript.log"
    $retainedEngineLog = Join-Path $outputDirectory "engine.log"
    [System.IO.File]::Copy($contractTranscriptPath, $retainedContractTranscript, $false)
    [System.IO.File]::Copy(
        $validationTranscriptPath,
        $retainedValidationTranscript,
        $false
    )
    [System.IO.File]::Copy($engineLogPath, $retainedEngineLog, $false)
}

if ($PreflightOnly) {
    $receiptPrefix = "BALANCED_WAVE_BW6N_VALIDATION_PREFLIGHT_RECEIPT "
    $expectedSchema =
        "sporespore_balanced_wave_bw6n_validation_preflight_receipt_v1"
} else {
    $receiptPrefix = "BALANCED_WAVE_BW6N_VALIDATION_RECEIPT "
    $expectedSchema = "sporespore_balanced_wave_bw6n_validation_receipt_v1"
}
$receiptLines = @(
    Get-Content -LiteralPath $validationTranscriptPath |
        Where-Object { $_.StartsWith($receiptPrefix) }
)
if ($receiptLines.Count -ne 1) {
    throw (
        "Expected exactly one BW6N receipt, found $($receiptLines.Count). " +
        "The first-attempt transcripts were retained at $outputDirectory"
    )
}
$receipt = $receiptLines[0].Substring($receiptPrefix.Length) |
    ConvertFrom-Json -AsHashtable
if ([string]$receipt.schema_version -cne $expectedSchema) {
    throw "BW6N receipt schema mismatch"
}

if ($PreflightOnly) {
    $preflightPassed = (
        $godotExitCode -eq 0 -and
        [bool]$receipt.ok -and
        [bool]$receipt.clock_ok -and
        [bool]$receipt.matrix_ok -and
        [bool]$receipt.inputs_ok -and
        [int]$receipt.expected_world_count -eq 12 -and
        [int]$receipt.observed_world_count -eq 0 -and
        -not [bool]$receipt.locomotion_outcome_exposed -and
        -not [bool]$receipt.adapter_actuation_applied -and
        -not [bool]$receipt.physics_state_modified -and
        -not [bool]$receipt.godot_jolt_nuisance_acceptance -and
        -not [bool]$receipt.physical_acceptance_authority
    )
    if (-not $preflightPassed) {
        throw "BW6N zero-world preflight failed"
    }
    Write-Host "BW6N validation zero-world preflight passed."
    Write-Host "Transcript: $validationTranscriptPath"
    exit 0
}

$validationAccepted = (
    $godotExitCode -eq 0 -and
    [bool]$receipt.ok -and
    [bool]$receipt.accepted -and
    [string]$receipt.result -ceq "nuisance_acceptance_passed" -and
    [int]$receipt.passed_gate_count -eq 24 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_world_count -eq 12 -and
    [int]$receipt.observed_world_count -eq 12 -and
    [int]$receipt.integrity_failure_count -eq 0 -and
    [int]$receipt.nonzero_stability_world_count -eq 12 -and
    [int]$receipt.count_by_cohort.baseline -eq 3 -and
    [int]$receipt.count_by_cohort.rough -eq 3 -and
    [int]$receipt.count_by_cohort.push -eq 3 -and
    [int]$receipt.count_by_cohort.sensor_noise -eq 3 -and
    [int]$receipt.pass_by_cohort.baseline -eq 3 -and
    [int]$receipt.pass_by_cohort.rough -eq 3 -and
    [int]$receipt.pass_by_cohort.push -eq 3 -and
    [int]$receipt.pass_by_cohort.sensor_noise -eq 3 -and
    @($receipt.matched_pairs).Count -eq 9 -and
    @($receipt.cells).Count -eq 12 -and
    [bool]$receipt.godot_jolt_nuisance_acceptance -and
    [bool]$receipt.rough_terrain_robustness -and
    [bool]$receipt.external_push_recovery -and
    [bool]$receipt.sensor_noise_robustness -and
    [bool]$receipt.physical_balance_recovery -and
    -not [bool]$receipt.cross_engine_c6 -and
    -not [bool]$receipt.completed_engine_neutral_sdk -and
    -not [bool]$receipt.physical_acceptance_authority
)

$sourcePaths = [ordered]@{
    manifest = "sdk/balanced_wave_bw6n_validation_manifest.json"
    selected_policy = "sdk/balanced_wave_selected_policy.json"
    runner = "sdk/run_balanced_wave_bw6n_validation.ps1"
    contract_test = $contractTestPath
    challenge_contract_test = "tests/test_sdk_environment_challenge_contract.gd"
    validation_test = $validationTestPath
    inherited_material_test = "tests/test_sdk_godot_jolt_material_robustness.gd"
    physical_rig = "scripts/lab/gait/physical_wave_gait_quadruped.gd"
    fixture = "scripts/lab/gait/physical_quadruped_fixture_spec.gd"
    gait_clock = "scripts/lab/gait/physical_gait_clock_spec.gd"
    material_profiles = "scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
    adapter = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
    portable_controller = "sdk/core/src/controller.rs"
    portable_runtime = "sdk/core/src/runtime.rs"
    portable_stability = "sdk/core/src/stability.rs"
}
$sources = [ordered]@{}
foreach ($entry in $sourcePaths.GetEnumerator()) {
    $absolutePath = Join-Path $repoRoot $entry.Value
    $sources[$entry.Key] = [ordered]@{
        path = $entry.Value
        sha256 = (
            Get-FileHash -Algorithm SHA256 -LiteralPath $absolutePath
        ).Hash.ToLowerInvariant()
    }
}
$report = [ordered]@{
    schema_version = "sporespore_balanced_wave_bw6n_validation_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    accepted = $validationAccepted
    result_status = $(if ($validationAccepted) {
        "nuisance_acceptance_passed"
    } else {
        "rejected"
    })
    campaign_partition = "prospective_nuisance_acceptance"
    candidate_id = "BW5R-B"
    policy_id = $expectedPolicyId
    candidate_policy_digest = $expectedPolicyDigest
    godot_exit_code = $godotExitCode
    prerequisite_evidence = [ordered]@{
        bw5c_cold_acceptance = [ordered]@{
            path = $prerequisitePath
            sha256 = $prerequisiteHash
        }
    }
    godot_jolt_nuisance_acceptance = $validationAccepted
    rough_terrain_robustness = $validationAccepted
    external_push_recovery = $validationAccepted
    sensor_noise_robustness = $validationAccepted
    physical_balance_recovery = $validationAccepted
    arbitrary_terrain_robustness = $false
    continuous_terrain_coverage = $false
    arbitrary_push_recovery = $false
    arbitrary_sensor_fault_robustness = $false
    sensor_latency_robustness = $false
    combined_nuisance_robustness = $false
    fresh_morphology_validation = $false
    cross_engine_c6 = $false
    completed_engine_neutral_sdk = $false
    physical_acceptance_authority = $false
    godot = [ordered]@{
        executable_path = $godotPath
        executable_sha256 = (
            Get-FileHash -Algorithm SHA256 -LiteralPath $godotPath
        ).Hash.ToLowerInvariant()
        version = (& $godotPath --version).Trim()
        physics_engine = "Jolt Physics"
        physics_hz = 120
        solver_velocity_steps = 20
        solver_position_steps = 7
    }
    sources = $sources
    transcripts = [ordered]@{
        contract = [ordered]@{
            path = "contract-transcript.log"
            sha256 = (
                Get-FileHash -Algorithm SHA256 `
                    -LiteralPath $retainedContractTranscript
            ).Hash.ToLowerInvariant()
        }
        validation = [ordered]@{
            path = "validation-transcript.log"
            sha256 = (
                Get-FileHash -Algorithm SHA256 `
                    -LiteralPath $retainedValidationTranscript
            ).Hash.ToLowerInvariant()
        }
        engine = [ordered]@{
            path = "engine.log"
            sha256 = (
                Get-FileHash -Algorithm SHA256 `
                    -LiteralPath $retainedEngineLog
            ).Hash.ToLowerInvariant()
        }
    }
    receipt = $receipt
}
$temporaryPath = "$outputPath.tmp"
$json = $report | ConvertTo-Json -Depth 64
[System.IO.File]::WriteAllText(
    $temporaryPath,
    "$json`n",
    [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::Move($temporaryPath, $outputPath, $false)
Write-Host "Retained BW6N validation report: $outputPath"
if (-not $validationAccepted) {
    throw "The frozen BW6N result was rejected. Report: $outputPath"
}
Write-Host (
    "BALANCED_WAVE_BW6N_VALIDATION=true " +
    "GATES=$([int]$receipt.passed_gate_count)/24 " +
    "WORLDS=$([int]$receipt.observed_world_count)/12"
)
