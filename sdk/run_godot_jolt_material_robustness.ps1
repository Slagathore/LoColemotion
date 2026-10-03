#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_sdk_godot_jolt_material_robustness"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if ($PreflightOnly -and -not [string]::IsNullOrWhiteSpace($Output)) {
    throw "Preflight-only mode cannot retain an acceptance report"
}
if (-not $PreflightOnly -and [string]::IsNullOrWhiteSpace($Output)) {
    throw (
        "The full P5M.3-R1 first-result matrix requires a durable -Output " +
        "report.json path. Use -PreflightOnly before the source is clean/pushed."
    )
}
$preRunSourceCommit = ""
$preRunOutputPath = ""
if (-not $PreflightOnly) {
    $preRunStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the source worktree before P5M.3-R1"
    }
    if ($preRunStatus.Count -ne 0) {
        throw (
            "Refusing to open the full P5M.3-R1 outcome from a dirty worktree. " +
            "Use -PreflightOnly until the implementation is committed."
        )
    }
    $preRunSourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $preRunOriginMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($preRunSourceCommit) -or
        $preRunOriginMain -cne $preRunSourceCommit
    ) {
        throw (
            "Refusing to open the full P5M.3-R1 outcome because HEAD does not " +
            "match the locally verified origin/main revision"
        )
    }
    $preRunOutputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($preRunOutputPath) -cne "report.json") {
        throw "The retained P5M.3-R1 report filename must be exactly report.json"
    }
    if (Test-Path -LiteralPath $preRunOutputPath) {
        throw (
            "Refusing to open or overwrite an existing P5M.3-R1 result: " +
            $preRunOutputPath
        )
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
    $linkPath = Join-Path $projectRoot $directory
    $targetPath = Join-Path $repoRoot $directory
    [void](New-Item -ItemType Junction -Path $linkPath -Target $targetPath)
}

$projectText = @'
; Isolated P5M.3-R1 Godot/Jolt cold material-robustness matrix.

config_version=5

[application]

config/name="sporespore-sdk-godot-jolt-material-robustness"
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
$godotArguments = @(
    "--headless",
    "--path", $projectRoot,
    "--log-file", $engineLogPath,
    "--script", "res://tests/test_sdk_godot_jolt_material_robustness.gd"
)
if ($PreflightOnly) {
    $godotArguments += @("--", "--preflight-only")
}
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $appData
    $env:LOCALAPPDATA = $localAppData
    & $godotPath @godotArguments 2>&1 |
        Tee-Object -FilePath $transcriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

if ($PreflightOnly) {
    $receiptPrefix = "SDK_MATERIAL_ROBUSTNESS_PREFLIGHT_RECEIPT "
    $expectedSchema = (
        "sporespore_godot_jolt_material_robustness_r1_preflight_receipt_v1"
    )
} else {
    $receiptPrefix = "SDK_MATERIAL_ROBUSTNESS_RECEIPT "
    $expectedSchema = "sporespore_godot_jolt_material_robustness_r1_receipt_v1"
}
$receiptLines = @(
    Get-Content -LiteralPath $transcriptPath |
        Where-Object { $_.StartsWith($receiptPrefix) }
)
if ($receiptLines.Count -ne 1) {
    if ($PreflightOnly) {
        throw (
            "Expected exactly one $receiptPrefix line, found " +
            "$($receiptLines.Count). Transcript: $transcriptPath"
        )
    }
    $receipt = [ordered]@{
        schema_version = $expectedSchema
        ok = $false
        failure_code = "FULL_RECEIPT_CARDINALITY_INVALID"
        observed_receipt_line_count = $receiptLines.Count
        partial_outcome_retained = $true
    }
} else {
    $receiptJson = $receiptLines[0].Substring($receiptPrefix.Length)
    try {
        $receipt = $receiptJson | ConvertFrom-Json -AsHashtable
    } catch {
        if ($PreflightOnly) {
            throw
        }
        $receipt = [ordered]@{
            schema_version = $expectedSchema
            ok = $false
            failure_code = "FULL_RECEIPT_JSON_INVALID"
            json_parse_error = $_.Exception.Message
            partial_outcome_retained = $true
        }
    }
}

if ($PreflightOnly) {
    $receiptPassed = (
        $godotExitCode -eq 0 -and
        [string]$receipt.schema_version -ceq $expectedSchema -and
        [bool]$receipt.ok -and
        [bool]$receipt.clock_ok -and
        [bool]$receipt.matrix_ok -and
        [bool]$receipt.inputs_ok -and
        [int]$receipt.expected_world_count -eq 23 -and
        [int]$receipt.observed_world_count -eq 0 -and
        [int]$receipt.cell_ids.Count -eq 23 -and
        [int]$receipt.seed_receipts.Count -eq 3 -and
        [int]$receipt.task_frame_receipts.Count -eq 3 -and
        @($receipt.task_frame_receipts |
            Where-Object { -not [bool]$_.ok }).Count -eq 0 -and
        [bool]$receipt.bridge_conformance.ok -and
        [int]$receipt.bridge_conformance.available_nonzero_output_count -eq 8 -and
        [int]$receipt.bridge_conformance.unavailable_exact_zero_output_count -eq 8 -and
        [int]$receipt.bridge_conformance.unavailable_influence_output_count -eq 8 -and
        [int]$receipt.bridge_conformance.unavailable_fallback_zero_output_count -eq 8 -and
        [int]$receipt.profile_receipts.Count -eq 7 -and
        -not [bool]$receipt.locomotion_outcome_exposed -and
        -not [bool]$receipt.adapter_actuation_applied -and
        -not [bool]$receipt.physics_transform_or_velocity_written -and
        -not [bool]$receipt.formal_milestone_acceptance_authorized -and
        -not [bool]$receipt.encyclopedia_admission_authorized
    )
    if (-not $receiptPassed) {
        throw (
            "The P5M.3-R1 zero-world preflight failed. Godot exit code: " +
            "$godotExitCode. Transcript: $transcriptPath"
        )
    }
    Write-Host "Godot/Jolt P5M.3-R1 zero-world preflight passed."
    Write-Host "Transcript: $transcriptPath"
    exit 0
}

$receiptPassed = (
    $godotExitCode -eq 0 -and
    [string]$receipt.schema_version -ceq $expectedSchema -and
    [bool]$receipt.ok -and
    [int]$receipt.passed_gate_count -eq 32 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_gate_count -eq 32 -and
    [int]$receipt.expected_world_count -eq 23 -and
    [int]$receipt.observed_world_count -eq 23 -and
    [int]$receipt.expected_primary_treatment_count -eq 12 -and
    [int]$receipt.observed_primary_treatment_pass_count -eq 12 -and
    [int]$receipt.expected_control_count -eq 4 -and
    [int]$receipt.observed_control_pass_count -eq 4 -and
    [int]$receipt.expected_diagnostic_count -eq 6 -and
    [int]$receipt.observed_diagnostic_execution_count -eq 6 -and
    [int]$receipt.expected_zero_control_count -eq 1 -and
    [int]$receipt.observed_zero_control_pass_count -eq 1 -and
    [int]$receipt.expected_paired_causal_count -eq 4 -and
    [int]$receipt.observed_paired_causal_pass_count -eq 4 -and
    [int]$receipt.cells.Count -eq 23 -and
    [int]$receipt.paired_controls.Count -eq 4 -and
    [bool]$receipt.primary_discrete_material_cohort_passed -and
    [bool]$receipt.zero_friction_fail_safe_passed -and
    -not [bool]$receipt.candidate35_branch_topology_changed -and
    -not [bool]$receipt.p5i3c_gain_or_bound_changed -and
    -not [bool]$receipt.post_result_cell_seed_or_threshold_changed -and
    -not [bool]$receipt.continuous_friction_coverage -and
    -not [bool]$receipt.arbitrary_material_robustness -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.rough_terrain_robustness -and
    -not [bool]$receipt.external_push_recovery -and
    -not [bool]$receipt.sensor_fault_robustness -and
    -not [bool]$receipt.balance_improvement -and
    -not [bool]$receipt.physical_balance_recovery -and
    -not [bool]$receipt.fresh_morphology_validation -and
    -not [bool]$receipt.physical_full_volume_coverage -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.completed_engine_neutral_sdk -and
    -not [bool]$receipt.formal_milestone_acceptance_authorized -and
    -not [bool]$receipt.encyclopedia_admission_authorized
)

$worktreeStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect the source worktree"
}
if ($worktreeStatus.Count -ne 0) {
    throw (
        "Refusing to retain P5M.3-R1 evidence from a dirty worktree. " +
        "The full matrix is eligible only from a committed source."
    )
}
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourceCommit)) {
    throw "Unable to resolve the source commit"
}
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
if ($LASTEXITCODE -ne 0 -or $originMain -cne $sourceCommit) {
    throw (
        "Refusing retained P5M.3-R1 evidence because HEAD is not the locally " +
        "verified origin/main revision"
    )
}
if ($sourceCommit -cne $preRunSourceCommit) {
    throw "The P5M.3-R1 source revision changed while the cold matrix was running"
}
$outputPath = [System.IO.Path]::GetFullPath($Output)
if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
    throw "The retained P5M.3-R1 report filename must be exactly report.json"
}
if (Test-Path -LiteralPath $outputPath) {
    throw "Refusing to overwrite an existing P5M.3-R1 report: $outputPath"
}
if ($outputPath -cne $preRunOutputPath) {
    throw "The P5M.3-R1 output path changed while the cold matrix was running"
}
$outputDirectory = Split-Path -Parent $outputPath
[System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
$retainedTranscriptPath = Join-Path $outputDirectory "transcript.log"
$retainedEngineLogPath = Join-Path $outputDirectory "engine.log"
[System.IO.File]::Copy($transcriptPath, $retainedTranscriptPath, $false)
[System.IO.File]::Copy($engineLogPath, $retainedEngineLogPath, $false)

$sourcePaths = [ordered]@{
    bootstrap = (
        "docs/SDK_GODOT_JOLT_FRICTION_MATERIAL_ROBUSTNESS_BOOTSTRAP.md"
    )
    profiles = "scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
    adapter = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
    walker = "scripts/lab/gait/physical_wave_gait_quadruped.gd"
    fixture = "scripts/lab/gait/physical_quadruped_fixture_spec.gd"
    gait_clock = "scripts/lab/gait/physical_gait_clock_spec.gd"
    test = "tests/test_sdk_godot_jolt_material_robustness.gd"
    runner = "sdk/run_godot_jolt_material_robustness.ps1"
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
        "sporespore_godot_jolt_material_robustness_r1_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    accepted = $receiptPassed
    result_status = $(if ($receiptPassed) { "passed" } else { "rejected" })
    godot_exit_code = $godotExitCode
    stopping_rule =
        "first_clean_pushed_complete_r1_23_world_matrix_only_no_selective_rerun"
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
$json = $report | ConvertTo-Json -Depth 64
[System.IO.File]::WriteAllText(
    $temporaryPath,
    "$json`n",
    [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::Move($temporaryPath, $outputPath, $false)
Write-Host "Retained P5M.3-R1 material-robustness report: $outputPath"

if (-not $receiptPassed) {
    throw (
        "The P5M.3-R1 cold matrix was rejected and retained. Godot exit code: " +
        "$godotExitCode. Report: $outputPath"
    )
}

Write-Host "Godot/Jolt P5M.3-R1 cold material-robustness matrix passed."
Write-Host "Transcript: $transcriptPath"
