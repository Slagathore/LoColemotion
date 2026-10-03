#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_balanced_wave_bw6n_opened_diagnostic"
    ),
    [Parameter(Mandatory = $true)]
    [string]$Output
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$testPath = "tests/test_sdk_balanced_wave_bw6n_opened_diagnostic.gd"
$expectedReceiptSchema =
    "sporespore_balanced_wave_bw6n_opened_diagnostic_receipt_v1"
$expectedCellIds = @(
    "baseline_s21001",
    "baseline_s21002",
    "baseline_s21003",
    "rough_s21001",
    "rough_s21002",
    "rough_s21003"
)

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}

$sourceStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
if ($LASTEXITCODE -ne 0 -or $sourceStatus.Count -ne 0) {
    throw "Refusing the opened BW6N diagnostic from dirty source"
}
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
if (
    $LASTEXITCODE -ne 0 -or
    [string]::IsNullOrWhiteSpace($sourceCommit) -or
    $sourceCommit -cne $originMain
) {
    throw "Refusing the opened BW6N diagnostic because HEAD does not match origin/main"
}

$outputPath = [System.IO.Path]::GetFullPath($Output)
if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
    throw "The retained diagnostic report filename must be exactly report.json"
}
if (Test-Path -LiteralPath $outputPath) {
    throw "Refusing to overwrite an existing diagnostic report: $outputPath"
}
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    $existing = @(Get-ChildItem -LiteralPath $outputDirectory -Force)
    if ($existing.Count -ne 0) {
        throw "Refusing a nonempty diagnostic evidence directory: $outputDirectory"
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
; Isolated SporeSpore opened-BW6N causal diagnostic.

config_version=5

[application]

config/name="sporespore-balanced-wave-bw6n-opened-diagnostic"
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
$transcriptPath = Join-Path $runRoot "diagnostic-transcript.log"
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
        --script "res://$testPath" `
        -- `
        --opened-bw6n-diagnostic `
        2>&1 | Tee-Object -FilePath $transcriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

# Retain the raw first attempt before receipt parsing. The opened worlds may be
# replayed for development, but this source-bound diagnostic remains immutable.
[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$retainedTranscript = Join-Path $outputDirectory "diagnostic-transcript.log"
$retainedEngineLog = Join-Path $outputDirectory "engine.log"
[System.IO.File]::Copy($transcriptPath, $retainedTranscript, $false)
[System.IO.File]::Copy($engineLogPath, $retainedEngineLog, $false)

$receiptPrefix = "BALANCED_WAVE_BW6N_OPENED_DIAGNOSTIC_RECEIPT "
$receiptLines = @(
    Get-Content -LiteralPath $transcriptPath |
        Where-Object { $_.StartsWith($receiptPrefix) }
)
if ($receiptLines.Count -ne 1) {
    throw (
        "Expected exactly one opened BW6N diagnostic receipt, found " +
        "$($receiptLines.Count). Raw evidence: $outputDirectory"
    )
}
$receipt = $receiptLines[0].Substring($receiptPrefix.Length) |
    ConvertFrom-Json -AsHashtable
$observedCellIds = @(
    $receipt.observed_cell_ids | ForEach-Object { [string]$_ }
)
$diagnosticComplete = (
    $godotExitCode -eq 0 -and
    [string]$receipt.schema_version -ceq $expectedReceiptSchema -and
    [bool]$receipt.ok -and
    [string]$receipt.result -ceq "development_diagnostic_complete" -and
    [string]$receipt.campaign_partition -ceq "opened_bw6n_development_replay" -and
    [bool]$receipt.opened_seed_replay -and
    -not [bool]$receipt.source_campaign_rerun -and
    -not [bool]$receipt.controller_changed -and
    -not [bool]$receipt.thresholds_changed -and
    ($observedCellIds -join ",") -ceq ($expectedCellIds -join ",") -and
    [int]$receipt.observed_world_count -eq 6 -and
    @($receipt.cells).Count -eq 6 -and
    -not [bool]$receipt.acceptance_authority -and
    -not [bool]$receipt.walking_claim_authorized -and
    -not [bool]$receipt.rough_terrain_robustness -and
    -not [bool]$receipt.physical_balance_recovery -and
    -not [bool]$receipt.cross_engine_c6 -and
    -not [bool]$receipt.completed_engine_neutral_sdk -and
    -not [bool]$receipt.formal_milestone_acceptance_authorized
)

$sourcePaths = [ordered]@{
    runner = "sdk/run_balanced_wave_bw6n_opened_diagnostic.ps1"
    diagnostic_test = $testPath
    rejected_manifest = "sdk/balanced_wave_bw6n_validation_manifest.json"
    rejected_validation_test = "tests/test_sdk_balanced_wave_bw6n_validation.gd"
    physical_rig = "scripts/lab/gait/physical_wave_gait_quadruped.gd"
    adapter = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
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
    schema_version =
        "sporespore_balanced_wave_bw6n_opened_diagnostic_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    diagnostic_complete = $diagnosticComplete
    result_status = $(if ($diagnosticComplete) {
        "development_diagnostic_complete"
    } else {
        "diagnostic_failed"
    })
    campaign_partition = "opened_bw6n_development_replay"
    source_campaign = "BW6N"
    source_campaign_result = "rejected"
    accepted = $false
    acceptance_authority = $false
    walking_claim_authorized = $false
    rough_terrain_robustness = $false
    physical_balance_recovery = $false
    cross_engine_c6 = $false
    completed_engine_neutral_sdk = $false
    godot_exit_code = $godotExitCode
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
        diagnostic = [ordered]@{
            path = "diagnostic-transcript.log"
            sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $retainedTranscript
            ).Hash.ToLowerInvariant()
        }
        engine = [ordered]@{
            path = "engine.log"
            sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $retainedEngineLog
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
Write-Host "Retained opened BW6N diagnostic report: $outputPath"
if (-not $diagnosticComplete) {
    throw "Opened BW6N diagnostic failed. Report: $outputPath"
}
Write-Host (
    "BALANCED_WAVE_BW6N_OPENED_DIAGNOSTIC=true " +
    "WORLDS=$([int]$receipt.observed_world_count)/6 " +
    "ACCEPTANCE_AUTHORITY=false"
)
