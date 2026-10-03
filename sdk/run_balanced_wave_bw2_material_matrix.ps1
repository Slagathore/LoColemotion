#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_balanced_wave_bw2_material"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly,
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
$expectedCandidateOrder = if ($isBw5r) {
    "BW5R-A,BW5R-B,BW5R-C"
} elseif ($isBw4r) {
    "BW4R-A,BW4R-B"
} elseif ($isBw2r) {
    "BW2R-A,BW2R-B,BW2R-C"
} else {
    "BW2-A,BW2-B,BW2-C"
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
$testPath = "tests/test_sdk_godot_jolt_material_robustness.gd"

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $preregistrationPath -PathType Leaf)) {
    throw "BW2 preregistration not found: $preregistrationPath"
}
if ($PreflightOnly -and -not [string]::IsNullOrWhiteSpace($Output)) {
    throw "BW2 material preflight cannot retain a physics report"
}
if (-not $PreflightOnly -and [string]::IsNullOrWhiteSpace($Output)) {
    throw "The full BW2 material matrix requires a durable -Output report.json path"
}

$preregistration = Get-Content -LiteralPath $preregistrationPath -Raw |
    ConvertFrom-Json -AsHashtable
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
$digestByCandidate = @{
    "BW2-A" = "sha256:d1ce56ba1a74f843700559e1b240c3a5a4ea33c31d7a14d874fdd2c6ebfb2fd9"
    "BW2-B" = "sha256:0ab4fa4c4e37441b26bdd00d23926e4511892201150bf61554c5b1362edf7913"
    "BW2-C" = "sha256:367e944b33384d8685d746dca0a864cfa33ca013846636236512641456d51ad3"
    "BW2R-A" = "sha256:4ffb7abd947f60287b81c9105fb99b2964355d0e16e13b64bc8b18d9fcec6343"
    "BW2R-B" = "sha256:44e8bfd0e4e1227db56ace8c58fc62fa6dd6bfc0d1cb993367510214272da144"
    "BW2R-C" = "sha256:709aacc898e62a0c1902a04a201006f5501934562cabec4b68c1613811ae0ad0"
    "BW4R-A" = "sha256:40dc551e99fea518df68c35d49e3d7d9605484e25cb385f938b3568ddcab2cf4"
    "BW4R-B" = "sha256:2496dc6da6dea17cfc7ffee0027234fa7a2a0f4eea8bc463a68db9a9d105bae7"
    "BW5R-A" = "sha256:6001dd2b5926908a1bad16d17e49e233cbfb1dfa7eb360bdfe8e4df147b245ac"
    "BW5R-B" = "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
    "BW5R-C" = "sha256:c067ece936a53edb9cc9d667a68274451e4db67b762ab262bf42e8efe88d742d"
}
$policyId = [string]$policyByCandidate[$Candidate]
$candidateArgument = [string]$argumentByCandidate[$Candidate]
$candidateDigest = [string]$digestByCandidate[$Candidate]
$matrix = if ($isSuccessor) {
    $preregistration.development_matrix
} else {
    $preregistration.physics_matrix
}
$materialWorldCount = if ($isSuccessor) {
    [int]$matrix.opened_bw2_material_world_count
} else {
    [int]$matrix.material_world_count
}
$matrixWorldCount = if ($isSuccessor) {
    [int]$matrix.expected_world_count_per_candidate
} else {
    [int]$matrix.total_world_count_per_opened_candidate
}
if (
    [string]$preregistration.schema_version -cne $expectedPreregistrationSchema -or
    [string]$preregistration.status -cne $expectedPreregistrationStatus -or
    $materialWorldCount -ne 23 -or
    $matrixWorldCount -ne $expectedTotalWorldCount -or
    (($preregistration.candidate_order | ForEach-Object { [string]$_ }) -join ",") -cne
        $expectedCandidateOrder -or
    [string]$preregistration.candidate_policy_digests[$Candidate] -cne $candidateDigest
) {
    throw "BW2 preregistration identity, candidate order, or material matrix is invalid"
}

$sourceCommit = ""
$outputPath = ""
$outputDirectory = ""
if (-not $PreflightOnly) {
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the BW2 source worktree"
    }
    if ($sourceStatus.Count -ne 0) {
        throw "Refusing to open the BW2 material matrix from dirty source"
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
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained BW2 material report filename must be exactly report.json"
    }
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to overwrite an existing BW2 material report: $outputPath"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        $existing = @(Get-ChildItem -LiteralPath $outputDirectory -Force)
        if ($existing.Count -ne 0) {
            throw "Refusing a nonempty retained BW2 material directory: $outputDirectory"
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
; Isolated SporeSpore balanced-wave BW2 material matrix.

config_version=5

[application]

config/name="sporespore-balanced-wave-bw2-material"
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
$materialTranscriptPath = Join-Path $runRoot "material-transcript.log"
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
    $contractExitCode = $LASTEXITCODE
    if ($contractExitCode -ne 0) {
        throw (
            "BW2 no-world contract failed before the material matrix opened. " +
            "Transcript: $contractTranscriptPath"
        )
    }

    $materialArguments = @(
        "--headless",
        "--path", $projectRoot,
        "--log-file", $engineLogPath,
        "--script", "res://$testPath",
        "--", $candidateArgument
    )
    if ($PreflightOnly) {
        $materialArguments += "--preflight-only"
    }
    & $godotPath @materialArguments 2>&1 |
        Tee-Object -FilePath $materialTranscriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

if ($PreflightOnly) {
    $receiptPrefix = "BALANCED_WAVE_BW2_MATERIAL_PREFLIGHT_RECEIPT "
    $expectedSchema =
        "sporespore_balanced_wave_bw2_material_preflight_receipt_v1"
} else {
    $receiptPrefix = "BALANCED_WAVE_BW2_MATERIAL_RECEIPT "
    $expectedSchema = "sporespore_balanced_wave_bw2_material_receipt_v1"
}
$receiptLines = @(
    Get-Content -LiteralPath $materialTranscriptPath |
        Where-Object { $_.StartsWith($receiptPrefix) }
)
if ($receiptLines.Count -eq 1) {
    $receipt = $receiptLines[0].Substring($receiptPrefix.Length) |
        ConvertFrom-Json -AsHashtable
} elseif ($PreflightOnly) {
    throw (
        "Expected exactly one $receiptPrefix line, found $($receiptLines.Count). " +
        "Transcript: $materialTranscriptPath"
    )
} else {
    $receipt = [ordered]@{
        schema_version = $expectedSchema
        ok = $false
        failure_code = "MATERIAL_RECEIPT_CARDINALITY_INVALID"
        observed_receipt_line_count = $receiptLines.Count
        partial_outcome_retained = $true
    }
}

if ($PreflightOnly) {
    $preflightAccepted = (
        $godotExitCode -eq 0 -and
        [string]$receipt.schema_version -ceq $expectedSchema -and
        [bool]$receipt.ok -and
        [string]$receipt.candidate_id -ceq $Candidate -and
        [string]$receipt.policy_id -ceq $policyId -and
        [int]$receipt.expected_world_count -eq 23 -and
        [int]$receipt.observed_world_count -eq 0 -and
        [int]$receipt.cell_ids.Count -eq 23 -and
        [int]$receipt.seed_receipts.Count -eq 3 -and
        [int]$receipt.profile_receipts.Count -eq 7 -and
        [bool]$receipt.bridge_conformance.ok -and
        -not [bool]$receipt.locomotion_outcome_exposed -and
        -not [bool]$receipt.adapter_actuation_applied -and
        -not [bool]$receipt.walking_acceptance -and
        -not [bool]$receipt.material_robustness -and
        -not [bool]$receipt.cross_engine_c6 -and
        -not [bool]$receipt.completed_engine_neutral_sdk
    )
    if (-not $preflightAccepted) {
        throw (
            "BW2 material zero-world preflight failed. Godot exit code: " +
            "$godotExitCode. Transcript: $materialTranscriptPath"
        )
    }
    Write-Host "$Candidate material zero-world preflight passed."
    Write-Host "Transcript: $materialTranscriptPath"
    exit 0
}

$integrityAccepted = (
    $godotExitCode -eq 0 -and
    [string]$receipt.schema_version -ceq $expectedSchema -and
    [bool]$receipt.ok -and
    [string]$receipt.candidate_id -ceq $Candidate -and
    [string]$receipt.policy_id -ceq $policyId -and
    [int]$receipt.passed_gate_count -eq 30 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_gate_count -eq 30 -and
    [int]$receipt.expected_world_count -eq 23 -and
    [int]$receipt.observed_world_count -eq 23 -and
    [int]$receipt.cells.Count -eq 23 -and
    [int]$receipt.integrity_failure_count -eq 0 -and
    [int]$receipt.eligible_nonzero_treatment_count -eq 18 -and
    [int]$receipt.eligible_nonzero_treatment_with_nonzero_stability_count -eq 18 -and
    [int]$receipt.control_integrity_count -eq 4 -and
    [int]$receipt.zero_friction_exact_fallback_count -eq 1 -and
    -not [bool]$receipt.walking_acceptance -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.arbitrary_material_robustness -and
    -not [bool]$receipt.continuous_friction_coverage -and
    -not [bool]$receipt.cross_engine_c6 -and
    -not [bool]$receipt.rough_terrain_robustness -and
    -not [bool]$receipt.external_push_recovery -and
    -not [bool]$receipt.sensor_fault_robustness -and
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
    throw "BW2 source changed or became dirty while the material matrix ran"
}

[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$retainedContractTranscript = Join-Path $outputDirectory "contract-transcript.log"
$retainedMaterialTranscript = Join-Path $outputDirectory "material-transcript.log"
$retainedEngineLog = Join-Path $outputDirectory "engine.log"
[System.IO.File]::Copy($contractTranscriptPath, $retainedContractTranscript, $false)
[System.IO.File]::Copy($materialTranscriptPath, $retainedMaterialTranscript, $false)
[System.IO.File]::Copy($engineLogPath, $retainedEngineLog, $false)

$sourcePaths = [ordered]@{
    bootstrap = "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"
    preregistration = "sdk/$preregistrationName"
    runner = "sdk/run_balanced_wave_bw2_material_matrix.ps1"
    contract_test = $contractTestPath
    material_test = $testPath
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
    schema_version = "sporespore_balanced_wave_bw2_material_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    accepted = $integrityAccepted
    result_status = $(if ($integrityAccepted) { "integrity_accepted" } else { "rejected" })
    development_data_only = $true
    candidate_id = $Candidate
    candidate_policy_digest = $candidateDigest
    godot_exit_code = $godotExitCode
    stopping_rule = [string]$preregistration.selection.early_stop_rule
    eligible_nonzero_treatment_nonwalk_count =
        [int]$receipt.eligible_nonzero_treatment_nonwalk_count
    walking_acceptance = $false
    material_robustness = $false
    arbitrary_material_robustness = $false
    continuous_friction_coverage = $false
    arbitrary_quadruped_coverage = $false
    continuous_full_volume_coverage = $false
    cross_engine_c6 = $false
    rough_terrain_robustness = $false
    external_push_recovery = $false
    sensor_fault_robustness = $false
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
        material = [ordered]@{
            path = "material-transcript.log"
            sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $retainedMaterialTranscript
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
Write-Host "Retained BW2 material report: $outputPath"

if (-not $integrityAccepted) {
    throw (
        "The BW2 material matrix failed execution integrity. Godot exit code: " +
        "$godotExitCode. Report: $outputPath"
    )
}

Write-Host (
    "BALANCED_WAVE_BW2_MATERIAL_INTEGRITY=true " +
    "WORLDS=$([int]$receipt.observed_world_count) " +
    "NONZERO_NONWALKS=$([int]$receipt.eligible_nonzero_treatment_nonwalk_count) " +
    "WALKING_GATE_FAILURES=$([int]$receipt.aggregate_walking_gate_failure_count)"
)
