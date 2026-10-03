#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CompletedRunRoot,
    [Parameter(Mandatory)]
    [string]$PhysicsSourceCommit,
    [Parameter(Mandatory)]
    [string]$Output,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$runRoot = [System.IO.Path]::GetFullPath($CompletedRunRoot)
$outputPath = [System.IO.Path]::GetFullPath($Output)
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$receiptPrefix = "BALANCED_WAVE_BW5C_MATERIAL_CHARACTERIZATION_RECEIPT "
$expectedSchema = (
    "sporespore_balanced_wave_bw5c_material_characterization_receipt_v1"
)

if (-not (Test-Path -LiteralPath $runRoot -PathType Container)) {
    throw "Completed BW5C run root is missing: $runRoot"
}
if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
    throw "The retained BW5C report filename must be exactly report.json"
}
if (Test-Path -LiteralPath $outputPath) {
    throw "Refusing to overwrite a retained BW5C report: $outputPath"
}
if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if ($PhysicsSourceCommit -cnotmatch "^[0-9a-f]{40}$") {
    throw "PhysicsSourceCommit must be a full lowercase Git object ID"
}

$engineLogPath = Join-Path $runRoot "engine.log"
$partialTranscriptPath = Join-Path $runRoot "transcript.log"
if (-not (Test-Path -LiteralPath $engineLogPath -PathType Leaf)) {
    throw "Completed BW5C engine log is missing: $engineLogPath"
}
if (-not (Test-Path -LiteralPath $partialTranscriptPath -PathType Leaf)) {
    throw "Original command-host transcript is missing: $partialTranscriptPath"
}

$activeRunProcesses = @(
    Get-CimInstance Win32_Process |
        Where-Object {
            [string]$_.CommandLine -like "*$runRoot*" -and
            [int]$_.ProcessId -ne $PID
        }
)
if ($activeRunProcesses.Count -ne 0) {
    throw "Refusing to finalize BW5C while its physics process is still active"
}

$receiptLines = @(
    Get-Content -LiteralPath $engineLogPath |
        Where-Object { $_.StartsWith($receiptPrefix) }
)
if ($receiptLines.Count -ne 1) {
    throw (
        "Expected exactly one completed BW5C receipt in engine.log, found " +
        "$($receiptLines.Count)"
    )
}
$partialReceiptLines = @(
    Get-Content -LiteralPath $partialTranscriptPath |
        Where-Object { $_.StartsWith($receiptPrefix) }
)
if ($partialReceiptLines.Count -ne 0) {
    throw (
        "Recovery is defined only for a command-host transcript interrupted " +
        "before receipt packaging"
    )
}
$receipt = (
    $receiptLines[0].Substring($receiptPrefix.Length) |
        ConvertFrom-Json -AsHashtable
)
$authoredValues = @($receipt.fixture.authored_friction_values)
$positiveValues = @($receipt.fixture.positive_friction_values)
$receiptPassed = (
    [string]$receipt.schema_version -ceq $expectedSchema -and
    [bool]$receipt.ok -and
    [int]$receipt.passed_gate_count -eq 23 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_gate_count -eq 23 -and
    [int]$receipt.expected_world_count -eq 13 -and
    [int]$receipt.observed_world_count -eq 13 -and
    [string]$receipt.fixture.fixture_id -ceq
        "SDK.BW5C.godot_jolt_material_sled.v1" -and
    $authoredValues.Count -eq 5 -and
    [double]$authoredValues[0] -eq 0.0 -and
    [double]$authoredValues[1] -eq 0.12 -and
    [double]$authoredValues[2] -eq 0.48 -and
    [double]$authoredValues[3] -eq 0.95 -and
    [double]$authoredValues[4] -eq 1.5 -and
    $positiveValues.Count -eq 4 -and
    [double]$positiveValues[0] -eq 0.12 -and
    [double]$positiveValues[1] -eq 0.48 -and
    [double]$positiveValues[2] -eq 0.95 -and
    [double]$positiveValues[3] -eq 1.5 -and
    [bool]$receipt.frictionless_control.ok -and
    [int]$receipt.positive_cells.Count -eq 4 -and
    [bool]$receipt.monotonicity.ok -and
    [bool]$receipt.cold_characterization -and
    -not [bool]$receipt.development_data_only -and
    -not [bool]$receipt.adapter_actuation_applied -and
    -not [bool]$receipt.physics_transform_or_velocity_written -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.balance_improvement -and
    -not [bool]$receipt.physical_balance_recovery -and
    -not [bool]$receipt.friction_material_locomotion_robustness -and
    -not [bool]$receipt.continuous_friction_coverage -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.rough_terrain_robustness -and
    -not [bool]$receipt.external_push_recovery -and
    -not [bool]$receipt.sensor_fault_robustness -and
    -not [bool]$receipt.fresh_morphology_validation -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.completed_engine_neutral_sdk
)
foreach ($cell in $receipt.positive_cells) {
    $coefficient = [double]$cell.coefficient_derivation.controller_mu
    $receiptPassed = (
        $receiptPassed -and
        [bool]$cell.ok -and
        [int]$cell.replicates.Count -eq 3 -and
        [bool]$cell.coefficient_derivation.ok -and
        [double]::IsFinite($coefficient) -and
        $coefficient -ge 0.0 -and
        $coefficient -le 1.0 -and
        -not [bool]$cell.coefficient_derivation.cross_engine_equivalent -and
        -not [bool]$cell.coefficient_derivation.locomotion_robustness
    )
}
if (-not $receiptPassed) {
    throw "The completed BW5C engine receipt fails the frozen 23-gate contract"
}

& git -C $repoRoot cat-file -e "$PhysicsSourceCommit`^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Physics source commit is not available in this repository"
}
$packagingCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
$worktreeStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
if ($worktreeStatus.Count -ne 0) {
    throw "Refusing recovered retention from a dirty packaging worktree"
}
if ($packagingCommit -cne $originMain) {
    throw "Packaging HEAD must equal the locally verified origin/main"
}
& git -C $repoRoot merge-base --is-ancestor $PhysicsSourceCommit origin/main
if ($LASTEXITCODE -ne 0) {
    throw "Physics source commit is not retained in origin/main history"
}

$physicsSourcePaths = [ordered]@{
    bootstrap = "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"
    test = "tests/test_sdk_godot_jolt_friction_ladder_characterization.gd"
    runner = "sdk/run_godot_jolt_friction_ladder_characterization.ps1"
    campaign_runner =
        "sdk/run_balanced_wave_bw5c_material_characterization.ps1"
    preregistration = "sdk/balanced_wave_bw5c_preregistration.json"
    selected_policy = "sdk/balanced_wave_selected_policy.json"
    reservation_preregistration =
        "sdk/balanced_wave_bw5v_preregistration.json"
    reservation_validation_manifest =
        "sdk/balanced_wave_bw5v_validation_manifest.json"
    rig = "scripts/lab/rigs/sdk_friction_ladder_sled_rig.gd"
    base_rig = "scripts/lab/rigs/friction_sled_rig.gd"
    canonicalizer = "scripts/lab/mechanics/contact_canonicalizer.gd"
    slip_observer = "scripts/lab/mechanics/contact_slip_observer.gd"
    breakaway_analyzer =
        "scripts/lab/mechanics/friction_breakaway_analyzer.gd"
}
foreach ($path in $physicsSourcePaths.Values) {
    & git -C $repoRoot diff --quiet $PhysicsSourceCommit -- $path
    if ($LASTEXITCODE -ne 0) {
        throw "Physics source changed after the completed run: $path"
    }
}

$preregistrationPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw5c_preregistration.json"
)
$preregistration = (
    Get-Content -LiteralPath $preregistrationPath -Raw |
        ConvertFrom-Json -AsHashtable
)
$validationEvidence = (
    $preregistration.prerequisite_evidence.bw5v_validation
)
$validationPath = [string]$validationEvidence.path
$validationHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $validationPath
).Hash.ToLowerInvariant()
if (
    [string]$preregistration.schema_version -cne
        "sporespore_balanced_wave_bw5c_preregistration_v1" -or
    [string]$preregistration.status -cne
        "frozen_before_first_bw5c_characterization_world" -or
    [string]$preregistration.freeze_parent_commit -cne
        "7fce71042a6ca5f60275ac072cef9a070c5412ce" -or
    $validationHash -cne [string]$validationEvidence.sha256 -or
    [string]$validationEvidence.source_commit -cne
        "7d8b046f752974b8d9498db91b0d46ae99ac1729"
) {
    throw "BW5C preregistration or accepted BW5V prerequisite changed"
}

$outputDirectory = Split-Path -Parent $outputPath
[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$retainedEngineLogPath = Join-Path $outputDirectory "engine.log"
$retainedPartialTranscriptPath = Join-Path (
    $outputDirectory
) "command-host-transcript.partial.log"
[System.IO.File]::Copy($engineLogPath, $retainedEngineLogPath, $false)
[System.IO.File]::Copy(
    $partialTranscriptPath,
    $retainedPartialTranscriptPath,
    $false
)

$sources = [ordered]@{}
foreach ($entry in $physicsSourcePaths.GetEnumerator()) {
    $absolutePath = Join-Path $repoRoot $entry.Value
    $sources[$entry.Key] = [ordered]@{
        path = $entry.Value
        sha256 = (
            Get-FileHash -Algorithm SHA256 -LiteralPath $absolutePath
        ).Hash.ToLowerInvariant()
    }
}
$finalizerPath = "sdk/finalize_balanced_wave_bw5c_completed_run.ps1"
$sources["recovery_finalizer"] = [ordered]@{
    path = $finalizerPath
    sha256 = (
        Get-FileHash -Algorithm SHA256 `
            -LiteralPath (Join-Path $repoRoot $finalizerPath)
    ).Hash.ToLowerInvariant()
    source_commit = $packagingCommit
}

$report = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw5c_material_characterization_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $PhysicsSourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    source_tree_matches_completed_run = $true
    source_retained_in_origin_main = $true
    packaging_commit = $packagingCommit
    packaging_worktree_clean = $true
    packaging_matches_origin_main = $true
    campaign = "BW5C"
    development_data_only = $false
    cold_characterization = $true
    prerequisite_evidence = [ordered]@{
        bw5v_validation = [ordered]@{
            path = [string]$validationEvidence.path
            sha256 = [string]$validationEvidence.sha256
            source_commit = [string]$validationEvidence.source_commit
        }
    }
    accepted = $true
    result_status = "passed"
    godot_exit_code = $null
    stopping_rule =
        "no_selective_replicate_rerun_or_post_result_gate_edit"
    recovery = [ordered]@{
        recovered_from_completed_engine_log = $true
        physics_rerun = $false
        physics_process_naturally_completed = $true
        complete_receipt_count = 1
        receipt_source = "engine.log"
        command_host_interrupted_after_physics_spawn = $true
        original_command_host_transcript_complete = $false
        original_command_host_transcript_receipt_count = 0
        godot_exit_code_observed_by_command_host = $false
        recovered_fields_are_packaging_metadata_only = $true
    }
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
        path = "engine.log"
        sha256 = (
            Get-FileHash -Algorithm SHA256 `
                -LiteralPath $retainedEngineLogPath
        ).Hash.ToLowerInvariant()
        complete = $true
        receipt_count = 1
        recovered_from_engine_log = $true
    }
    command_host_transcript = [ordered]@{
        path = "command-host-transcript.partial.log"
        sha256 = (
            Get-FileHash -Algorithm SHA256 `
                -LiteralPath $retainedPartialTranscriptPath
        ).Hash.ToLowerInvariant()
        complete = $false
        receipt_count = 0
    }
    engine_log = [ordered]@{
        path = "engine.log"
        sha256 = (
            Get-FileHash -Algorithm SHA256 `
                -LiteralPath $retainedEngineLogPath
        ).Hash.ToLowerInvariant()
        complete = $true
        receipt_count = 1
    }
    receipt = $receipt
}
$temporaryPath = "$outputPath.tmp"
$json = $report | ConvertTo-Json -Depth 32
[System.IO.File]::WriteAllText(
    $temporaryPath,
    "$json`n",
    [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::Move($temporaryPath, $outputPath, $false)
Write-Host "Recovered completed BW5C report without rerunning physics: $outputPath"
