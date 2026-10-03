#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_sdk_godot_jolt_stability_influence"
    ),
    [string]$Output = ""
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
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
    $linkPath = Join-Path $projectRoot $directory
    $targetPath = Join-Path $repoRoot $directory
    [void](New-Item -ItemType Junction -Path $linkPath -Target $targetPath)
}

$projectText = @'
; Isolated SporeSpore P5I.3C paired Godot/Jolt physical influence.

config_version=5

[application]

config/name="sporespore-sdk-godot-jolt-stability-influence"
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
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $appData
    $env:LOCALAPPDATA = $localAppData
    & $godotPath `
        --headless `
        --path $projectRoot `
        --script "res://tests/test_sdk_godot_jolt_stability_physical_influence.gd" `
        2>&1 | Tee-Object -FilePath $transcriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

$receiptLines = @(
    Get-Content -LiteralPath $transcriptPath |
        Where-Object {
            $_.StartsWith("SDK_STABILITY_PHYSICAL_INFLUENCE_RECEIPT ")
        }
)
if ($receiptLines.Count -ne 1) {
    throw (
        "Expected exactly one SDK_STABILITY_PHYSICAL_INFLUENCE_RECEIPT line, " +
        "found $($receiptLines.Count). Transcript: $transcriptPath"
    )
}
$receiptJson = $receiptLines[0].Substring(
    "SDK_STABILITY_PHYSICAL_INFLUENCE_RECEIPT ".Length
)
$receipt = $receiptJson | ConvertFrom-Json -AsHashtable
$receiptPassed = (
    $godotExitCode -eq 0 -and
    [string]$receipt.schema_version -ceq
        "sporespore_godot_jolt_stability_physical_influence_receipt_v1" -and
    [bool]$receipt.ok -and
    [int]$receipt.passed_gate_count -eq 24 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_gate_count -eq 24 -and
    [string]$receipt.policy_id -ceq
        "p5i3c_support_centroid_tilt_feedback_v1" -and
    [string]$receipt.runtime_id -ceq
        "sporespore_godot_jolt_stability_overlay_runtime_v1" -and
    [string]$receipt.memory_id -ceq
        "sporespore_stability_overlay_memory_v1" -and
    [bool]$receipt.physical_influence -and
    -not [bool]$receipt.physical_balance_recovery -and
    -not [bool]$receipt.balance_improvement -and
    -not [bool]$receipt.locomotion_robustness -and
    -not [bool]$receipt.friction_material_robustness -and
    -not [bool]$receipt.rough_terrain_robustness -and
    -not [bool]$receipt.external_push_recovery -and
    -not [bool]$receipt.sensor_fault_robustness -and
    -not [bool]$receipt.cross_engine_locomotion -and
    -not [bool]$receipt.fresh_morphology_validation -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.completed_sdk
)

if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $worktreeStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the source worktree"
    }
    if ($worktreeStatus.Count -ne 0) {
        throw (
            "Refusing to retain evidence from a dirty worktree. " +
            "Commit the implementation and rerun."
        )
    }
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourceCommit)) {
        throw "Unable to resolve the source commit"
    }
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    if ($LASTEXITCODE -ne 0 -or $originMain -cne $sourceCommit) {
        throw (
            "Refusing retained evidence because HEAD is not the locally " +
            "verified origin/main revision"
        )
    }
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained P5I.3C report filename must be exactly report.json"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    $retainedTranscriptPath = Join-Path $outputDirectory "transcript.log"
    [System.IO.File]::Copy($transcriptPath, $retainedTranscriptPath, $true)
    $sourcePaths = [ordered]@{
        bootstrap = "docs/SDK_GODOT_JOLT_STABILITY_INFLUENCE_BOOTSTRAP.md"
        test = "tests/test_sdk_godot_jolt_stability_physical_influence.gd"
        runner = "sdk/run_godot_jolt_stability_physical_influence.ps1"
        physical_rig = "scripts/lab/gait/physical_wave_gait_quadruped.gd"
        adapter = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
        fixture = "scripts/lab/gait/physical_quadruped_fixture_spec.gd"
        portable_core = "sdk/core/src/stability.rs"
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
            "sporespore_godot_jolt_stability_physical_influence_report_v1"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $sourceCommit
        source_worktree_clean = $true
        source_matches_origin_main = $true
        accepted = $receiptPassed
        result_status = $(if ($receiptPassed) { "passed" } else { "rejected" })
        godot_exit_code = $godotExitCode
        stopping_rule = "no_selective_cell_rerun_or_post_result_gate_edit"
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
        transcript = [ordered]@{
            path = "transcript.log"
            sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $retainedTranscriptPath
            ).Hash.ToLowerInvariant()
        }
        receipt = $receipt
    }
    $temporaryPath = "$outputPath.tmp"
    $json = $report | ConvertTo-Json -Depth 24
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        "$json`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::Move($temporaryPath, $outputPath, $true)
    Write-Host "Retained P5I.3C physical-influence report: $outputPath"
}

if (-not $receiptPassed) {
    throw (
        "The P5I.3C paired physical-influence result was rejected. " +
        "Godot exit code: $godotExitCode. Transcript: $transcriptPath"
    )
}

Write-Host "Godot/Jolt P5I.3C paired physical influence passed."
Write-Host "Transcript: $transcriptPath"
