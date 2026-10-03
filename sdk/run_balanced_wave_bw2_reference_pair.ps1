#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_balanced_wave_bw2_reference"
    ),
    [string]$Output = "",
    [ValidateSet(
        "BW2-A", "BW2-B", "BW2-C",
        "BW2R-A", "BW2R-B", "BW2R-C",
        "BW4R-A", "BW4R-B",
        "BW5R-A", "BW5R-B", "BW5R-C"
    )]
    [string]$Candidate = "BW2-A"
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$isBw2r = $Candidate.StartsWith("BW2R-", [System.StringComparison]::Ordinal)
$isBw4r = $Candidate.StartsWith("BW4R-", [System.StringComparison]::Ordinal)
$isBw5r = $Candidate.StartsWith("BW5R-", [System.StringComparison]::Ordinal)
$isSuccessor = $isBw4r -or $isBw5r
$preregistrationName = if ($isBw5r) {
    "balanced_wave_bw5r_preregistration.json"
} elseif ($isBw4r) {
    "balanced_wave_bw4r_preregistration.json"
} elseif ($isBw2r) {
    "balanced_wave_bw2r_preregistration.json"
} else {
    "balanced_wave_bw2_preregistration.json"
}
$preregistrationPath = Join-Path $sdkRoot $preregistrationName
$expectedPreregistrationSchema = if ($isBw5r) {
    "sporespore_balanced_wave_bw5r_preregistration_v1"
} elseif ($isBw4r) {
    "sporespore_balanced_wave_bw4r_preregistration_v1"
} elseif ($isBw2r) {
    "sporespore_balanced_wave_bw2r_preregistration_v1"
} else {
    "sporespore_balanced_wave_bw2_preregistration_v1"
}
$expectedPreregistrationStatus = if ($isBw5r) {
    "frozen_before_first_bw5r_physics_world"
} elseif ($isBw4r) {
    "frozen_before_first_bw4r_physics_world"
} elseif ($isBw2r) {
    "frozen_before_first_bw2r_physics_world"
} else {
    "frozen_before_first_bw2_physics_world"
}
$expectedTotalWorldCount = if ($isSuccessor) { 58 } elseif ($isBw2r) { 41 } else { 29 }
$contractTestPath = if ($isBw5r) {
    "tests/test_sdk_balanced_wave_bw5r_authority_contract.gd"
} elseif ($isBw4r) {
    "tests/test_sdk_balanced_wave_bw4r_authority_contract.gd"
} elseif ($isBw2r) {
    "tests/test_sdk_balanced_wave_bw2r_authority_contract.gd"
} else {
    "tests/test_sdk_balanced_wave_bw2_authority_contract.gd"
}

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $preregistrationPath -PathType Leaf)) {
    throw "BW2 preregistration not found: $preregistrationPath"
}

$preregistration = Get-Content -LiteralPath $preregistrationPath -Raw |
    ConvertFrom-Json -AsHashtable
$matrix = if ($isSuccessor) {
    $preregistration.development_matrix
} else {
    $preregistration.physics_matrix
}
$matrixWorldCount = if ($isSuccessor) {
    [int]$matrix.expected_world_count_per_candidate
} else {
    [int]$matrix.total_world_count_per_opened_candidate
}
if (
    [string]$preregistration.schema_version -cne $expectedPreregistrationSchema -or
    [string]$preregistration.status -cne $expectedPreregistrationStatus -or
    $matrixWorldCount -ne $expectedTotalWorldCount
) {
    throw "BW2 preregistration identity or matrix is invalid"
}
$policyByCandidate = @{
    "BW2-A" = "sporespore_balanced_wave_v1"
    "BW2-B" = "sporespore_balanced_wave_bw2_b_v1"
    "BW2-C" = "sporespore_balanced_wave_bw2_c_v1"
    "BW2R-A" = "sporespore_balanced_wave_bw2r_a_v1"
    "BW2R-B" = "sporespore_balanced_wave_bw2r_b_v1"
    "BW2R-C" = "sporespore_balanced_wave_bw2r_c_v1"
    "BW4R-A" = "sporespore_balanced_wave_bw4r_a_v1"
    "BW4R-B" = "sporespore_balanced_wave_bw4r_b_v1"
    "BW5R-A" = "sporespore_balanced_wave_bw5r_a_v1"
    "BW5R-B" = "sporespore_balanced_wave_bw5r_b_v1"
    "BW5R-C" = "sporespore_balanced_wave_bw5r_c_v1"
}
$argumentByCandidate = @{
    "BW2-A" = "--bw2-a"
    "BW2-B" = "--bw2-b"
    "BW2-C" = "--bw2-c"
    "BW2R-A" = "--bw2r-a"
    "BW2R-B" = "--bw2r-b"
    "BW2R-C" = "--bw2r-c"
    "BW4R-A" = "--bw4r-a"
    "BW4R-B" = "--bw4r-b"
    "BW5R-A" = "--bw5r-a"
    "BW5R-B" = "--bw5r-b"
    "BW5R-C" = "--bw5r-c"
}
$policyId = [string]$policyByCandidate[$Candidate]
$candidateArgument = [string]$argumentByCandidate[$Candidate]

$sourceStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect the BW2 source worktree"
}
if ($sourceStatus.Count -ne 0) {
    throw (
        "Refusing to open a BW2 physics world from dirty source. " +
        "Commit the implementation first."
    )
}
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
if (
    $LASTEXITCODE -ne 0 -or
    [string]::IsNullOrWhiteSpace($sourceCommit) -or
    $sourceCommit -cne $originMain
) {
    throw "Refusing BW2 because HEAD does not match origin/main"
}

$outputPath = ""
$outputDirectory = ""
if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained BW2 reference report filename must be exactly report.json"
    }
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to overwrite an existing BW2 reference report: $outputPath"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        $existing = @(Get-ChildItem -LiteralPath $outputDirectory -Force)
        if ($existing.Count -ne 0) {
            throw "Refusing a nonempty retained BW2 reference directory: $outputDirectory"
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
    $linkPath = Join-Path $projectRoot $directory
    $targetPath = Join-Path $repoRoot $directory
    [void](New-Item -ItemType Junction -Path $linkPath -Target $targetPath)
}

$projectText = @'
; Isolated SporeSpore balanced-wave BW2 opened reference pair.

config_version=5

[application]

config/name="sporespore-balanced-wave-bw2-reference"
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
$referenceTranscriptPath = Join-Path $runRoot "reference-transcript.log"
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
    $contractExitCode = $LASTEXITCODE
    if ($contractExitCode -ne 0) {
        throw (
            "BW2 no-world contract failed before the reference world opened. " +
            "Transcript: $contractTranscriptPath"
        )
    }

    & $godotPath `
        --headless `
        --path $projectRoot `
        --script "res://tests/test_sdk_balanced_wave_bw2_reference_pair.gd" `
        -- `
        $candidateArgument `
        2>&1 | Tee-Object -FilePath $referenceTranscriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

$receiptLines = @(
    Get-Content -LiteralPath $referenceTranscriptPath |
        Where-Object {
            $_.StartsWith("BALANCED_WAVE_BW2_REFERENCE_RECEIPT ")
        }
)
if ($receiptLines.Count -ne 1) {
    throw (
        "Expected exactly one BALANCED_WAVE_BW2_REFERENCE_RECEIPT line, found " +
        "$($receiptLines.Count). Transcript: $referenceTranscriptPath"
    )
}
$receipt = $receiptLines[0].Substring(
    "BALANCED_WAVE_BW2_REFERENCE_RECEIPT ".Length
) | ConvertFrom-Json -AsHashtable

$integrityAccepted = (
    $godotExitCode -eq 0 -and
    [string]$receipt.schema_version -ceq
        "sporespore_balanced_wave_bw2_reference_pair_receipt_v2" -and
    [bool]$receipt.ok -and
    [string]$receipt.candidate_id -ceq $Candidate -and
    [string]$receipt.policy_id -ceq $policyId -and
    [int]$receipt.passed_gate_count -eq 20 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_gate_count -eq 20 -and
    [int]$receipt.world_count -eq 2 -and
    [int]$receipt.control.step_count -eq 1514 -and
    [int]$receipt.treatment.step_count -eq 1514 -and
    [int]$receipt.control.validated_balanced_wave_command_count -eq 12112 -and
    [int]$receipt.treatment.validated_balanced_wave_command_count -eq 12112 -and
    [int]$receipt.control.native_motor_write_count -eq 0 -and
    [int]$receipt.treatment.native_motor_write_count -eq 12112 -and
    [int]$receipt.treatment.portable_controller_base_application_count -eq 12112 -and
    [string]$receipt.treatment.base_command_source -ceq
        "portable_controller_ordered_commands" -and
    [int]$receipt.control.direct_body_write_count -eq 0 -and
    [int]$receipt.treatment.direct_body_write_count -eq 0 -and
    -not [bool]$receipt.walking_acceptance -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.cross_engine_c6 -and
    -not [bool]$receipt.completed_engine_neutral_sdk -and
    -not [bool]$receipt.physical_acceptance_authority
)

$postStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
$postCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$postOriginMain = (& git -C $repoRoot rev-parse origin/main).Trim()
if (
    $LASTEXITCODE -ne 0 -or
    $postStatus.Count -ne 0 -or
    $postCommit -cne $sourceCommit -or
    $postOriginMain -cne $sourceCommit
) {
    throw "BW2 source changed or became dirty while the reference pair ran"
}

if (-not [string]::IsNullOrWhiteSpace($outputPath)) {
    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
    $retainedContractTranscript = Join-Path $outputDirectory "contract-transcript.log"
    $retainedReferenceTranscript = Join-Path $outputDirectory "reference-transcript.log"
    [System.IO.File]::Copy(
        $contractTranscriptPath,
        $retainedContractTranscript,
        $false
    )
    [System.IO.File]::Copy(
        $referenceTranscriptPath,
        $retainedReferenceTranscript,
        $false
    )
    $sourcePaths = [ordered]@{
        bootstrap = "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"
        preregistration = "sdk/$preregistrationName"
        runner = "sdk/run_balanced_wave_bw2_reference_pair.ps1"
        contract_test = $contractTestPath
        reference_test = "tests/test_sdk_balanced_wave_bw2_reference_pair.gd"
        physical_rig = "scripts/lab/gait/physical_wave_gait_quadruped.gd"
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
        schema_version = "sporespore_balanced_wave_bw2_reference_report_v2"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $sourceCommit
        source_worktree_clean = $true
        source_matches_origin_main = $true
        accepted = $integrityAccepted
        result_status = $(if ($integrityAccepted) { "integrity_accepted" } else { "rejected" })
        development_data_only = $true
        candidate_id = $Candidate
        candidate_policy_digest =
            [string]$preregistration.candidate_policy_digests[$Candidate]
        godot_exit_code = $godotExitCode
        stopping_rule = [string]$preregistration.selection.early_stop_rule
        reference_treatment_walking_observed =
            [bool]$receipt.treatment.walking_observed
        walking_acceptance = $false
        material_robustness = $false
        arbitrary_quadruped_coverage = $false
        continuous_full_volume_coverage = $false
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
                    Get-FileHash -Algorithm SHA256 -LiteralPath $retainedContractTranscript
                ).Hash.ToLowerInvariant()
            }
            reference = [ordered]@{
                path = "reference-transcript.log"
                sha256 = (
                    Get-FileHash -Algorithm SHA256 -LiteralPath $retainedReferenceTranscript
                ).Hash.ToLowerInvariant()
            }
        }
        receipt = $receipt
    }
    $temporaryPath = "$outputPath.tmp"
    $json = $report | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        "$json`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::Move($temporaryPath, $outputPath, $false)
    Write-Host "Retained BW2 reference report: $outputPath"
}

if (-not $integrityAccepted) {
    throw (
        "The BW2 reference pair failed execution integrity. Godot exit code: " +
        "$godotExitCode. Transcript: $referenceTranscriptPath"
    )
}

Write-Host (
    "BALANCED_WAVE_BW2_REFERENCE_INTEGRITY=true " +
    "TREATMENT_WALKING=$([bool]$receipt.treatment.walking_observed) " +
    "WORLDS=$([int]$receipt.world_count) " +
    "STEPS=$([int]$receipt.treatment.step_count) " +
    "COMMANDS=$([int]$receipt.treatment.validated_balanced_wave_command_count)"
)
Write-Host "Reference transcript: $referenceTranscriptPath"
