#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("BW11R-A", "BW11R-B", "BW11R-C", "BW11R-D")]
    [string]$Candidate,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_balanced_wave_bw11r_development"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$preregistrationPath = Join-Path $sdkRoot "balanced_wave_bw11r_preregistration.json"
$v3AuthorityTestPath =
    "tests/test_sdk_scheduled_load_transfer_v3_authority_contract.gd"
$fullGateTestPath = "tests/test_sdk_full_integrity_gate_satisfiability.gd"
$developmentTestPath = "tests/test_sdk_balanced_wave_bw11r_development.gd"
$expectedRawPreregistrationHash =
    "b52ac012e67668b050342746fc2415f0c81eff19f027deb6b1d09e476023ec5d"
$baseControllerPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$candidateIndex = [ordered]@{
    "BW11R-A" = [ordered]@{
        argument = "--bw11r-a"
        stability_policy_id =
            "sporespore_scheduled_load_transfer_bw11r_a_v3"
        policy_digest =
            "sha256:673814d0d90499bac22c05b98af99097dfcc121cb0fcce896b9a9d0b419fcc58"
        expected_nonzero_stability_world_count = 0
    }
    "BW11R-B" = [ordered]@{
        argument = "--bw11r-b"
        stability_policy_id =
            "sporespore_scheduled_load_transfer_bw11r_b_v3"
        policy_digest =
            "sha256:38301e919b9a81cac8e75ba571b6941440539f25be3d3964f45236e47448c0d2"
        expected_nonzero_stability_world_count = 12
    }
    "BW11R-C" = [ordered]@{
        argument = "--bw11r-c"
        stability_policy_id =
            "sporespore_scheduled_load_transfer_bw11r_c_v3"
        policy_digest =
            "sha256:7ed6d5a0a15dc6547655760878a5f5e3d0cc7b4b1a04946db77c0694394f9d85"
        expected_nonzero_stability_world_count = 12
    }
    "BW11R-D" = [ordered]@{
        argument = "--bw11r-d"
        stability_policy_id =
            "sporespore_scheduled_load_transfer_bw11r_d_v3"
        policy_digest =
            "sha256:edb4469fcd961c86374fb987a6fd7046acc14fd2d575a9c8d9a18d85dcb9c533"
        expected_nonzero_stability_world_count = 12
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

function Read-SingleReceipt {
    param(
        [string]$TranscriptPath,
        [string]$Prefix,
        [string]$Label
    )
    $lines = @(
        Get-Content -LiteralPath $TranscriptPath |
            Where-Object { $_.StartsWith($Prefix) }
    )
    Assert-Exact (
        $lines.Count -eq 1
    ) "Expected exactly one $Label receipt, found $($lines.Count)"
    return (
        $lines[0].Substring($Prefix.Length) |
            ConvertFrom-Json -AsHashtable
    )
}

Assert-Exact (
    Test-Path -LiteralPath $godotPath -PathType Leaf
) "Godot executable not found: $godotPath"
Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "BW11R preregistration is missing"
Assert-Exact (
    (Get-Sha256 $preregistrationPath) -ceq $expectedRawPreregistrationHash
) "BW11R preregistration raw bytes do not match the frozen runner identity"
if ($PreflightOnly) {
    Assert-Exact (
        [string]::IsNullOrWhiteSpace($Output)
    ) "BW11R preflight cannot retain a physics report"
} else {
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($Output)
    ) "A full BW11R candidate run requires a durable -Output report.json path"
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
    ) "Refusing to open BW11R worlds from dirty source"
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($sourceCommit) -and
        $sourceCommit -ceq $originMain
    ) "Refusing BW11R because HEAD does not exactly match origin/main"
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    Assert-Exact (
        [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
    ) "The retained BW11R report filename must be exactly report.json"
    Assert-Exact (
        -not (Test-Path -LiteralPath $outputPath)
    ) "Refusing to overwrite an existing BW11R report: $outputPath"
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        Assert-Exact (
            @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
        ) "Refusing a nonempty BW11R evidence directory: $outputDirectory"
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
; Isolated SporeSpore balanced-wave BW11R development campaign.

config_version=5

[application]

config/name="sporespore-balanced-wave-bw11r-development"
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
$v3AuthorityTranscriptPath = Join-Path $runRoot "v3-authority-transcript.log"
$fullGateTranscriptPath = Join-Path $runRoot "full-gate-transcript.log"
$candidatePreflightTranscriptPath = Join-Path $runRoot "candidate-preflight-transcript.log"
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
        --script "res://$v3AuthorityTestPath" `
        2>&1 | Tee-Object -FilePath $v3AuthorityTranscriptPath
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "BW11R portable v3 zero-world authority contract failed"
    $v3AuthorityReceipt = Read-SingleReceipt `
        -TranscriptPath $v3AuthorityTranscriptPath `
        -Prefix "SCHEDULED_LOAD_TRANSFER_V3_AUTHORITY_CONTRACT " `
        -Label "portable v3 authority"
    Assert-Exact (
        [bool]$v3AuthorityReceipt.passed -and
        [int]$v3AuthorityReceipt.world_build_count -eq 0 -and
        -not [bool]$v3AuthorityReceipt.physics_state_modified -and
        -not [bool]$v3AuthorityReceipt.physical_acceptance_authority
    ) "BW11R portable v3 authority receipt failed"

    & $godotPath `
        --headless `
        --path $projectRoot `
        --script "res://$fullGateTestPath" `
        2>&1 | Tee-Object -FilePath $fullGateTranscriptPath
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "BW11R all-policy full-gate satisfiability contract failed"
    $fullGateReceipt = Read-SingleReceipt `
        -TranscriptPath $fullGateTranscriptPath `
        -Prefix "FULL_INTEGRITY_GATE_SATISFIABILITY " `
        -Label "full-gate satisfiability"
    Assert-Exact (
        [bool]$fullGateReceipt.passed -and
        [bool]$fullGateReceipt.exact_post_physics_gate_called -and
        [int]$fullGateReceipt.observed_world_count -eq 0 -and
        -not [bool]$fullGateReceipt.physics_state_modified -and
        -not [bool]$fullGateReceipt.physical_acceptance_authority
    ) "BW11R full-gate satisfiability receipt failed"

    $candidatePreflightArguments = @(
        "--headless",
        "--path", $projectRoot,
        "--script", "res://$developmentTestPath",
        "--",
        "--preflight-only",
        [string]$selected.argument
    )
    & $godotPath @candidatePreflightArguments 2>&1 |
        Tee-Object -FilePath $candidatePreflightTranscriptPath
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "BW11R candidate exact-gate preflight process failed"
    $candidatePreflightReceipt = Read-SingleReceipt `
        -TranscriptPath $candidatePreflightTranscriptPath `
        -Prefix "BALANCED_WAVE_BW11R_DEVELOPMENT_PREFLIGHT " `
        -Label "candidate preflight"
    Assert-Exact (
        [bool]$candidatePreflightReceipt.ok -and
        [bool]$candidatePreflightReceipt.clock_ok -and
        [bool]$candidatePreflightReceipt.matrix_ok -and
        [bool]$candidatePreflightReceipt.inputs_ok -and
        [bool]$candidatePreflightReceipt.full_gate_satisfiability_ok -and
        [int]$candidatePreflightReceipt.expected_world_count -eq 12 -and
        [int]$candidatePreflightReceipt.observed_world_count -eq 0 -and
        -not [bool]$candidatePreflightReceipt.locomotion_outcome_exposed -and
        -not [bool]$candidatePreflightReceipt.physics_state_modified -and
        -not [bool]$candidatePreflightReceipt.walking_acceptance -and
        -not [bool]$candidatePreflightReceipt.physical_acceptance_authority
    ) "BW11R candidate zero-world preflight receipt failed"

    $godotExitCode = 0
    if (-not $PreflightOnly) {
        $developmentArguments = @(
            "--headless",
            "--path", $projectRoot,
            "--log-file", $engineLogPath,
            "--script", "res://$developmentTestPath",
            "--",
            [string]$selected.argument
        )
        & $godotPath @developmentArguments 2>&1 |
            Tee-Object -FilePath $developmentTranscriptPath
        $godotExitCode = $LASTEXITCODE
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

if ($PreflightOnly) {
    Write-Host (
        "BW11R $Candidate zero-world preflight passed: " +
        "portable v3, all-policy full gate, and candidate exact gate."
    )
    Write-Host "Run root: $runRoot"
    exit 0
}

[void][System.IO.Directory]::CreateDirectory($outputDirectory)
foreach ($name in @(
    "v3-authority-transcript.log",
    "full-gate-transcript.log",
    "candidate-preflight-transcript.log",
    "development-transcript.log",
    "engine.log"
)) {
    $source = switch ($name) {
        "v3-authority-transcript.log" {
            $v3AuthorityTranscriptPath
            break
        }
        "full-gate-transcript.log" {
            $fullGateTranscriptPath
            break
        }
        "candidate-preflight-transcript.log" {
            $candidatePreflightTranscriptPath
            break
        }
        "development-transcript.log" {
            $developmentTranscriptPath
            break
        }
        default {
            $engineLogPath
            break
        }
    }
    [System.IO.File]::Copy(
        $source,
        (Join-Path $outputDirectory $name),
        $false
    )
}

$receipt = Read-SingleReceipt `
    -TranscriptPath $developmentTranscriptPath `
    -Prefix "BALANCED_WAVE_BW11R_DEVELOPMENT_RECEIPT " `
    -Label "BW11R development"
Assert-Exact (
    [string]$receipt.schema_version -ceq
        "sporespore_balanced_wave_bw11r_development_receipt_v1" -and
    [string]$receipt.candidate_id -ceq $Candidate -and
    [string]$receipt.policy_id -ceq [string]$selected.stability_policy_id -and
    [string]$receipt.base_controller_policy_id -ceq
        $baseControllerPolicyId -and
    [string]$receipt.candidate_policy_digest -ceq
        [string]$selected.policy_digest
) "BW11R receipt candidate identity is invalid"

$complete = (
    $godotExitCode -eq 0 -and
    [bool]$receipt.ok -and
    [bool]$receipt.full_gate_satisfiability_ok -and
    [int]$receipt.passed_gate_count -eq 23 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_world_count -eq 12 -and
    [int]$receipt.observed_world_count -eq 12 -and
    [int]$receipt.integrity_failure_count -eq 0 -and
    [int]$receipt.acquisition_failure_count -eq 0 -and
    [int]$receipt.mechanism_receipt_failure_count -eq 0 -and
    [int]$receipt.nonzero_stability_world_count -eq
        [int]$selected.expected_nonzero_stability_world_count -and
    @($receipt.cells).Count -eq 12 -and
    -not [bool]$receipt.walking_acceptance -and
    -not [bool]$receipt.cross_engine_c6 -and
    -not [bool]$receipt.completed_engine_neutral_sdk -and
    -not [bool]$receipt.physical_acceptance_authority
)
$expectedSelectable = $Candidate -cne "BW11R-A"
Assert-Exact (
    [bool]$receipt.development_selectable -eq
        ($complete -and $expectedSelectable)
) "BW11R treatment/control development-selectability is inconsistent"

$sourcePaths = [ordered]@{
    preregistration = "sdk/balanced_wave_bw11r_preregistration.json"
    runner = "sdk/run_balanced_wave_bw11r_development.ps1"
    selector = "sdk/compile_balanced_wave_bw11r_selection.ps1"
    development_test = $developmentTestPath
    v3_authority_test = $v3AuthorityTestPath
    full_gate_test = $fullGateTestPath
    shared_physical_gate = "tests/test_sdk_godot_jolt_material_robustness.gd"
    challenge_source = "sdk/balanced_wave_bw6n_validation_manifest.json"
    prior_closure_manifest = "sdk/balanced_wave_bw10f_closure_manifest.json"
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
    Assert-Exact (
        Test-Path -LiteralPath $absolutePath -PathType Leaf
    ) "Missing BW11R retained source: $($entry.Value)"
    $sources[$entry.Key] = [ordered]@{
        path = $entry.Value
        sha256 = Get-Sha256 $absolutePath
    }
}
$transcriptPaths = [ordered]@{
    v3_authority = "v3-authority-transcript.log"
    full_gate = "full-gate-transcript.log"
    candidate_preflight = "candidate-preflight-transcript.log"
    development = "development-transcript.log"
    engine = "engine.log"
}
$transcripts = [ordered]@{}
foreach ($entry in $transcriptPaths.GetEnumerator()) {
    $transcripts[$entry.Key] = [ordered]@{
        path = $entry.Value
        sha256 = Get-Sha256 (
            Join-Path $outputDirectory $entry.Value
        )
    }
}
$report = [ordered]@{
    schema_version = "sporespore_balanced_wave_bw11r_development_report_v1"
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
    development_selectable = [bool]$receipt.development_selectable
    godot_exit_code = $godotExitCode
    all_preflight_processes_passed = $true
    preflight_actual_world_count = 0
    walking_acceptance = $false
    material_robustness = $false
    rough_terrain_robustness = $false
    physical_balance_recovery = $false
    fresh_morphology_validation = $false
    cross_engine_c6 = $false
    completed_engine_neutral_sdk = $false
    physical_acceptance_authority = $false
    sources = $sources
    transcripts = $transcripts
    v3_authority_receipt = $v3AuthorityReceipt
    full_gate_satisfiability_receipt = $fullGateReceipt
    candidate_preflight_receipt = $candidatePreflightReceipt
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
Write-Host "Retained BW11R $Candidate development report: $outputPath"
Assert-Exact (
    $complete
) "BW11R $Candidate did not retain a complete development matrix"
Write-Host (
    "BALANCED_WAVE_BW11R_DEVELOPMENT_COMPLETE=true " +
    "CANDIDATE=$Candidate " +
    "DEVELOPMENT_SELECTABLE=$([bool]$receipt.development_selectable) " +
    "WORLDS=$([int]$receipt.observed_world_count)/12"
)
