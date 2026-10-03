#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("BW9L-A", "BW9L-B", "BW9L-C", "BW9L-D")]
    [string]$Candidate,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_balanced_wave_bw9l_development"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$preregistrationPath = Join-Path $sdkRoot "balanced_wave_bw9l_preregistration.json"
$authorityTestPath = "tests/test_sdk_balanced_wave_bw9l_authority_contract.gd"
$developmentTestPath = "tests/test_sdk_balanced_wave_bw9l_development.gd"
$expectedRawPreregistrationHash =
    "da66fd10e7596b69858631eda41cdba7661b638610dbd788c7bd3269452bf85b"
$baseControllerPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$candidateIndex = [ordered]@{
    "BW9L-A" = [ordered]@{
        argument = "--bw9l-a"
        stability_policy_id =
            "sporespore_scheduled_load_transfer_bw9l_a_v1"
        policy_digest =
            "sha256:36fff9ffbf953e121e3ea1e3f25ad66d6358be4c9e4bcba383231b9977d98320"
    }
    "BW9L-B" = [ordered]@{
        argument = "--bw9l-b"
        stability_policy_id =
            "sporespore_scheduled_load_transfer_bw9l_b_v1"
        policy_digest =
            "sha256:ee964cfc22b19ce2aa5fb198c0d646a3bbaa562cd1916e7edd704033998210ff"
    }
    "BW9L-C" = [ordered]@{
        argument = "--bw9l-c"
        stability_policy_id =
            "sporespore_scheduled_load_transfer_bw9l_c_v1"
        policy_digest =
            "sha256:efb7d388369692731a20c8b0670ad08e7f5fe1a3363ca2e0659969e40cdbe7dd"
    }
    "BW9L-D" = [ordered]@{
        argument = "--bw9l-d"
        stability_policy_id =
            "sporespore_scheduled_load_transfer_bw9l_d_v1"
        policy_digest =
            "sha256:e3f3074fc39d4aee5f58a8c10cb8e680c802524df21f36ea0a1e5389b227067f"
    }
}
$selected = $candidateIndex[$Candidate]

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

Assert-Exact (
    Test-Path -LiteralPath $godotPath -PathType Leaf
) "Godot executable not found: $godotPath"
Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "BW9L preregistration is missing"
Assert-Exact (
    (Get-Sha256 $preregistrationPath) -ceq $expectedRawPreregistrationHash
) "BW9L preregistration raw bytes do not match the frozen runner identity"
if ($PreflightOnly) {
    Assert-Exact (
        [string]::IsNullOrWhiteSpace($Output)
    ) "BW9L preflight cannot retain a physics report"
} else {
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($Output)
    ) "A full BW9L candidate run requires a durable -Output report.json path"
}

$sourceCommit = ""
$outputPath = ""
$outputDirectory = ""
if (-not $PreflightOnly) {
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and $sourceStatus.Count -eq 0
    ) "Refusing to open BW9L worlds from dirty source"
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($sourceCommit) -and
        $sourceCommit -ceq $originMain
    ) "Refusing BW9L because HEAD does not exactly match origin/main"
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    Assert-Exact (
        [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
    ) "The retained BW9L report filename must be exactly report.json"
    Assert-Exact (
        -not (Test-Path -LiteralPath $outputPath)
    ) "Refusing to overwrite an existing BW9L report: $outputPath"
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        Assert-Exact (
            @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
        ) "Refusing a nonempty BW9L evidence directory: $outputDirectory"
    }
}

Push-Location -LiteralPath $sdkRoot
try {
    & cargo build -p sporespore-godot-adapter --offline
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Godot adapter build failed"
} finally {
    Pop-Location
}

$timestamp = Get-Date -Format "yyyyMMddTHHmmssfff"
$runRoot = Join-Path ([System.IO.Path]::GetFullPath($LogRoot)) (
    "$($Candidate.ToLowerInvariant())-$timestamp"
)
$projectRoot = Join-Path $runRoot "project"
[void][System.IO.Directory]::CreateDirectory($projectRoot)
foreach ($directory in @("scripts", "tests", "sdk")) {
    [void](New-Item `
        -ItemType Junction `
        -Path (Join-Path $projectRoot $directory) `
        -Target (Join-Path $repoRoot $directory))
}
$projectText = @'
; Isolated SporeSpore balanced-wave BW9L development campaign.

config_version=5

[application]

config/name="sporespore-balanced-wave-bw9l-development"
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
$authorityTranscriptPath = Join-Path $runRoot "authority-transcript.log"
$developmentTranscriptPath = Join-Path $runRoot "development-transcript.log"
$engineLogPath = Join-Path $runRoot "engine.log"
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $appData
    $env:LOCALAPPDATA = $localAppData
    & $godotPath `
        --headless `
        --path $projectRoot `
        --script "res://$authorityTestPath" `
        2>&1 | Tee-Object -FilePath $authorityTranscriptPath
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "BW9L zero-world authority contract failed"

    $developmentArguments = @(
        "--headless",
        "--path", $projectRoot,
        "--log-file", $engineLogPath,
        "--script", "res://$developmentTestPath",
        "--"
    )
    if ($PreflightOnly) {
        $developmentArguments += "--preflight-only"
    }
    $developmentArguments += [string]$selected.argument
    & $godotPath @developmentArguments 2>&1 |
        Tee-Object -FilePath $developmentTranscriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

if ($PreflightOnly) {
    $receiptPrefix = "BALANCED_WAVE_BW9L_DEVELOPMENT_PREFLIGHT "
    $expectedSchema = "sporespore_balanced_wave_bw9l_development_preflight_v1"
} else {
    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
    foreach ($name in @(
        "authority-transcript.log",
        "development-transcript.log",
        "engine.log"
    )) {
        $source = switch ($name) {
            "authority-transcript.log" { $authorityTranscriptPath; break }
            "development-transcript.log" { $developmentTranscriptPath; break }
            default { $engineLogPath; break }
        }
        [System.IO.File]::Copy(
            $source,
            (Join-Path $outputDirectory $name),
            $false
        )
    }
    $receiptPrefix = "BALANCED_WAVE_BW9L_DEVELOPMENT_RECEIPT "
    $expectedSchema = "sporespore_balanced_wave_bw9l_development_receipt_v1"
}
$receiptLines = @(
    Get-Content -LiteralPath $developmentTranscriptPath |
        Where-Object { $_.StartsWith($receiptPrefix) }
)
Assert-Exact (
    $receiptLines.Count -eq 1
) "Expected exactly one BW9L receipt, found $($receiptLines.Count)"
$receipt = $receiptLines[0].Substring($receiptPrefix.Length) |
    ConvertFrom-Json -AsHashtable
Assert-Exact (
    [string]$receipt.schema_version -ceq $expectedSchema -and
    [string]$receipt.candidate_id -ceq $Candidate -and
    [string]$receipt.policy_id -ceq [string]$selected.stability_policy_id -and
    [string]$receipt.base_controller_policy_id -ceq
        $baseControllerPolicyId -and
    [string]$receipt.candidate_policy_digest -ceq
        [string]$selected.policy_digest
) "BW9L receipt candidate identity is invalid"

if ($PreflightOnly) {
    Assert-Exact (
        $godotExitCode -eq 0 -and
        [bool]$receipt.ok -and
        [bool]$receipt.clock_ok -and
        [bool]$receipt.matrix_ok -and
        [bool]$receipt.inputs_ok -and
        [int]$receipt.expected_world_count -eq 12 -and
        [int]$receipt.observed_world_count -eq 0 -and
        -not [bool]$receipt.locomotion_outcome_exposed -and
        -not [bool]$receipt.physics_state_modified -and
        -not [bool]$receipt.walking_acceptance -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "BW9L zero-world preflight failed"
    Write-Host "BW9L $Candidate zero-world preflight passed."
    Write-Host "Transcript: $developmentTranscriptPath"
    exit 0
}

$complete = (
    $godotExitCode -eq 0 -and
    [bool]$receipt.ok -and
    [int]$receipt.passed_gate_count -eq 22 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_world_count -eq 12 -and
    [int]$receipt.observed_world_count -eq 12 -and
    [int]$receipt.integrity_failure_count -eq 0 -and
    [int]$receipt.acquisition_failure_count -eq 0 -and
    [int]$receipt.mechanism_receipt_failure_count -eq 0 -and
    [int]$receipt.nonzero_stability_world_count -eq 12 -and
    @($receipt.cells).Count -eq 12 -and
    -not [bool]$receipt.walking_acceptance -and
    -not [bool]$receipt.cross_engine_c6 -and
    -not [bool]$receipt.completed_engine_neutral_sdk -and
    -not [bool]$receipt.physical_acceptance_authority
)

$sourcePaths = [ordered]@{
    preregistration = "sdk/balanced_wave_bw9l_preregistration.json"
    runner = "sdk/run_balanced_wave_bw9l_development.ps1"
    authority_test = $authorityTestPath
    development_test = $developmentTestPath
    challenge_source = "sdk/balanced_wave_bw6n_validation_manifest.json"
    research_ledger = "docs/research/LOCOMOTION_RESEARCH_SOURCES.md"
    drecon_pdf = "DReCon.pdf"
    qwm_pdf = "2604.08780v1.pdf"
    unilegs_pdf = "2507.22653v2.pdf"
    physical_rig = "scripts/lab/gait/physical_wave_gait_quadruped.gd"
    fixture = "scripts/lab/gait/physical_quadruped_fixture_spec.gd"
    gait_clock = "scripts/lab/gait/physical_gait_clock_spec.gd"
    material_profiles = "scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
    godot_adapter = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
    portable_controller = "sdk/core/src/controller.rs"
    portable_runtime = "sdk/core/src/runtime.rs"
    portable_stability = "sdk/core/src/stability.rs"
    portable_ffi = "sdk/core/src/ffi.rs"
}
$sources = [ordered]@{}
foreach ($entry in $sourcePaths.GetEnumerator()) {
    $absolutePath = Join-Path $repoRoot $entry.Value
    $sources[$entry.Key] = [ordered]@{
        path = $entry.Value
        sha256 = Get-Sha256 $absolutePath
    }
}
$report = [ordered]@{
    schema_version = "sporespore_balanced_wave_bw9l_development_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    development_data_only = $true
    complete = $complete
    result_status = $(if ($complete) {
        [string]$receipt.result_status
    } else {
        "incomplete"
    })
    candidate_id = $Candidate
    policy_id = [string]$selected.stability_policy_id
    base_controller_policy_id = $baseControllerPolicyId
    candidate_policy_digest = [string]$selected.policy_digest
    candidate_eligible = [bool]$receipt.candidate_eligible
    godot_exit_code = $godotExitCode
    walking_acceptance = $false
    material_robustness = $false
    rough_terrain_robustness = $false
    physical_balance_recovery = $false
    fresh_morphology_validation = $false
    cross_engine_c6 = $false
    completed_engine_neutral_sdk = $false
    physical_acceptance_authority = $false
    sources = $sources
    transcripts = [ordered]@{
        authority = [ordered]@{
            path = "authority-transcript.log"
            sha256 = Get-Sha256 (
                Join-Path $outputDirectory "authority-transcript.log"
            )
        }
        development = [ordered]@{
            path = "development-transcript.log"
            sha256 = Get-Sha256 (
                Join-Path $outputDirectory "development-transcript.log"
            )
        }
        engine = [ordered]@{
            path = "engine.log"
            sha256 = Get-Sha256 (
                Join-Path $outputDirectory "engine.log"
            )
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
Write-Host "Retained BW9L $Candidate development report: $outputPath"
Assert-Exact (
    $complete
) "BW9L $Candidate did not retain a complete development matrix"
Write-Host (
    "BALANCED_WAVE_BW9L_DEVELOPMENT_COMPLETE=true " +
    "CANDIDATE=$Candidate ELIGIBLE=$([bool]$receipt.candidate_eligible) " +
    "WORLDS=$([int]$receipt.observed_world_count)/12"
)
