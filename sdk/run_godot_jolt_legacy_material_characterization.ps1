#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_sdk_godot_jolt_material"
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

$timestamp = Get-Date -Format "yyyyMMddTHHmmssfff"
$runRoot = Join-Path ([System.IO.Path]::GetFullPath($LogRoot)) $timestamp
$projectRoot = Join-Path $runRoot "project"
[void][System.IO.Directory]::CreateDirectory($projectRoot)

foreach ($directory in @("scripts", "tests")) {
    $linkPath = Join-Path $projectRoot $directory
    $targetPath = Join-Path $repoRoot $directory
    [void](New-Item -ItemType Junction -Path $linkPath -Target $targetPath)
}

$projectText = @'
; Isolated SporeSpore SDK Godot/Jolt legacy-material characterization.

config_version=5

[application]

config/name="sporespore-sdk-godot-jolt-legacy-material"
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
        --script (
            "res://tests/" +
            "test_sdk_godot_jolt_legacy_material_characterization.gd"
        ) `
        2>&1 | Tee-Object -FilePath $transcriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

if ($godotExitCode -ne 0) {
    throw (
        "Godot/Jolt legacy-material characterization failed with exit code " +
        "$godotExitCode. Transcript: $transcriptPath"
    )
}

$receiptLines = @(
    Get-Content -LiteralPath $transcriptPath |
        Where-Object { $_.StartsWith("SDK_LEGACY_MATERIAL_RECEIPT ") }
)
if ($receiptLines.Count -ne 1) {
    throw (
        "Expected exactly one SDK_LEGACY_MATERIAL_RECEIPT line, found " +
        "$($receiptLines.Count). Transcript: $transcriptPath"
    )
}
$receiptJson = $receiptLines[0].Substring(
    "SDK_LEGACY_MATERIAL_RECEIPT ".Length
)
$receipt = $receiptJson | ConvertFrom-Json -AsHashtable
if (-not [bool]$receipt.ok) {
    throw "The machine legacy-material receipt did not pass"
}

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
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained legacy-material report filename must be exactly report.json"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    $retainedTranscriptPath = Join-Path $outputDirectory "transcript.log"
    $retainedEngineLogPath = Join-Path $outputDirectory "engine.log"
    [System.IO.File]::Copy($transcriptPath, $retainedTranscriptPath, $true)
    [System.IO.File]::Copy($engineLogPath, $retainedEngineLogPath, $true)
    $testPath = Join-Path $repoRoot (
        "tests\test_sdk_godot_jolt_legacy_material_characterization.gd"
    )
    $rigPath = Join-Path $repoRoot (
        "scripts\lab\rigs\sdk_legacy_material_sled_rig.gd"
    )
    $runnerPath = Join-Path $sdkRoot (
        "run_godot_jolt_legacy_material_characterization.ps1"
    )
    $bootstrapPath = Join-Path $repoRoot (
        "docs\SDK_GODOT_JOLT_MATERIAL_CHARACTERIZATION_BOOTSTRAP.md"
    )
    $report = [ordered]@{
        schema_version = (
            "sporespore_godot_jolt_legacy_material_conformance_report_v1"
        )
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $sourceCommit
        source_worktree_clean = $true
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
        sources = [ordered]@{
            bootstrap_path = (
                "docs/SDK_GODOT_JOLT_MATERIAL_CHARACTERIZATION_BOOTSTRAP.md"
            )
            bootstrap_sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $bootstrapPath
            ).Hash.ToLowerInvariant()
            test_path = (
                "tests/test_sdk_godot_jolt_legacy_material_characterization.gd"
            )
            test_sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $testPath
            ).Hash.ToLowerInvariant()
            rig_path = "scripts/lab/rigs/sdk_legacy_material_sled_rig.gd"
            rig_sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $rigPath
            ).Hash.ToLowerInvariant()
            runner_path = (
                "sdk/run_godot_jolt_legacy_material_characterization.ps1"
            )
            runner_sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $runnerPath
            ).Hash.ToLowerInvariant()
        }
        transcript = [ordered]@{
            path = "transcript.log"
            sha256 = (
                Get-FileHash -Algorithm SHA256 `
                    -LiteralPath $retainedTranscriptPath
            ).Hash.ToLowerInvariant()
        }
        engine_log = [ordered]@{
            path = "engine.log"
            sha256 = (
                Get-FileHash -Algorithm SHA256 `
                    -LiteralPath $retainedEngineLogPath
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
    Write-Host "Retained legacy-material report: $outputPath"
}

Write-Host "Godot/Jolt legacy-material characterization passed."
Write-Host "Transcript: $transcriptPath"
