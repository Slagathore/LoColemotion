#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_sdk_godot_jolt_contribution_shadow"
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
; Isolated SporeSpore engine-neutral SDK Godot/Jolt shadow conformance.

config_version=5

[application]

config/name="sporespore-sdk-godot-jolt-shadow"
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
        --script "res://tests/test_sdk_godot_jolt_shadow_parity.gd" `
        2>&1 | Tee-Object -FilePath $transcriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

if ($godotExitCode -ne 0) {
    throw (
        "Godot/Jolt SDK shadow conformance failed with exit code " +
        "$godotExitCode. Transcript: $transcriptPath"
    )
}

$receiptLines = @(
    Get-Content -LiteralPath $transcriptPath |
        Where-Object { $_.StartsWith("SDK_STABILITY_SHADOW_RECEIPT ") }
)
if ($receiptLines.Count -ne 1) {
    throw (
        "Expected exactly one SDK_STABILITY_SHADOW_RECEIPT line, found " +
        "$($receiptLines.Count). Transcript: $transcriptPath"
    )
}
$receiptJson = $receiptLines[0].Substring(
    "SDK_STABILITY_SHADOW_RECEIPT ".Length
)
$receipt = $receiptJson | ConvertFrom-Json -AsHashtable
if (-not [bool]$receipt.ok) {
    throw "The machine stability-shadow receipt did not pass"
}
if (
    [string]$receipt.schema_version -cne
        "sporespore_godot_jolt_stability_contribution_shadow_receipt_v1" -or
    -not [bool]$receipt.joint_mapping_shadow.ok -or
    [int]$receipt.joint_mapping_shadow.available_count -le 0 -or
    [int]$receipt.joint_mapping_shadow.mismatch_count -ne 0 -or
    [bool]$receipt.joint_mapping_shadow.adapter_actuation_applied -or
    [bool]$receipt.joint_mapping_shadow.physics_state_modified -or
    [bool]$receipt.joint_mapping_shadow.physical_acceptance_authority
) {
    throw "The machine joint-mapping shadow receipt did not pass its v2 boundary"
}
if (
    -not [bool]$receipt.stability_contribution_shadow.ok -or
    [int]$receipt.stability_contribution_shadow.attempt_count -ne 1514 -or
    [int]$receipt.stability_contribution_shadow.available_count -ne 1448 -or
    [int]$receipt.stability_contribution_shadow.upstream_infeasible_count -ne 66 -or
    [int]$receipt.stability_contribution_shadow.ordered_v3_command_count -ne 11584 -or
    [int]$receipt.stability_contribution_shadow.influence_output_count -ne 12112 -or
    [int]$receipt.stability_contribution_shadow.profile_input_clamped_count -le 0 -or
    [int]$receipt.stability_contribution_shadow.profile_conversion_failure_count -ne 0 -or
    [int]$receipt.stability_contribution_shadow.mismatch_count -ne 0 -or
    [bool]$receipt.stability_contribution_shadow.adapter_actuation_applied -or
    [bool]$receipt.stability_contribution_shadow.physics_state_modified -or
    [bool]$receipt.stability_contribution_shadow.physical_acceptance_authority
) {
    throw "The machine stability-contribution shadow receipt did not pass"
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
        throw "The retained stability-shadow report filename must be exactly report.json"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    $retainedTranscriptPath = Join-Path $outputDirectory "transcript.log"
    [System.IO.File]::Copy($transcriptPath, $retainedTranscriptPath, $true)
    $report = [ordered]@{
        schema_version = "sporespore_godot_jolt_stability_contribution_shadow_report_v1"
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
            test_path = "tests/test_sdk_godot_jolt_shadow_parity.gd"
            test_sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath (
                    Join-Path $repoRoot "tests\test_sdk_godot_jolt_shadow_parity.gd"
                )
            ).Hash.ToLowerInvariant()
            adapter_path = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
            adapter_sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath (
                    Join-Path $repoRoot "scripts\lab\gait\sdk_godot_jolt_adapter.gd"
                )
            ).Hash.ToLowerInvariant()
            portable_core_path = "sdk/core/src/stability.rs"
            portable_core_sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath (
                    Join-Path $repoRoot "sdk\core\src\stability.rs"
                )
            ).Hash.ToLowerInvariant()
        }
        transcript = [ordered]@{
            path = "transcript.log"
            sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $retainedTranscriptPath
            ).Hash.ToLowerInvariant()
        }
        receipt = $receipt
    }
    $temporaryPath = "$outputPath.tmp"
    $json = $report | ConvertTo-Json -Depth 16
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        "$json`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::Move($temporaryPath, $outputPath, $true)
    Write-Host "Retained stability-shadow conformance report: $outputPath"
}

Write-Host "Godot/Jolt SDK physical shadow conformance passed."
Write-Host "Transcript: $transcriptPath"
