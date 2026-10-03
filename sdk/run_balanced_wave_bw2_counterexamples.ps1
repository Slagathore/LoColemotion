#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_balanced_wave_bw2_counterexamples"
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
$testPath =
    "tests/test_experimental_br14a_11_physical_wave_gait_nonuniform_proportion_probe.gd"
$receiptPrefix = "BALANCED_WAVE_BW2_COUNTEREXAMPLE_CELL_RECEIPT "
$cells = @(
    [ordered]@{
        morphology_id = "gq15_generated_s160"
        role = "selection"
        repetition = 0
    },
    [ordered]@{
        morphology_id = "gq15_generated_s167"
        role = "selection"
        repetition = 0
    },
    [ordered]@{
        morphology_id = "gq15_generated_s1404"
        role = "heldout"
        repetition = 1
    },
    [ordered]@{
        morphology_id = "gq15_generated_s1408"
        role = "heldout"
        repetition = 1
    }
)

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $preregistrationPath -PathType Leaf)) {
    throw "BW2 preregistration not found: $preregistrationPath"
}
if ($PreflightOnly -and -not [string]::IsNullOrWhiteSpace($Output)) {
    throw "BW2 counterexample preflight cannot retain a physics report"
}
if (-not $PreflightOnly -and [string]::IsNullOrWhiteSpace($Output)) {
    throw "The full BW2 counterexample matrix requires a durable -Output report.json"
}

$preregistration = Get-Content -LiteralPath $preregistrationPath -Raw |
    ConvertFrom-Json -AsHashtable
$argumentByCandidate = @{
    "BW2-A" = "balanced-wave-bw2-a"
    "BW2-B" = "balanced-wave-bw2-b"
    "BW2-C" = "balanced-wave-bw2-c"
    "BW2R-A" = "balanced-wave-bw2r-a"
    "BW2R-B" = "balanced-wave-bw2r-b"
    "BW2R-C" = "balanced-wave-bw2r-c"
    "BW4R-A" = "balanced-wave-bw4r-a"
    "BW4R-B" = "balanced-wave-bw4r-b"
    "BW5R-A" = "balanced-wave-bw5r-a"
    "BW5R-B" = "balanced-wave-bw5r-b"
    "BW5R-C" = "balanced-wave-bw5r-c"
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
$candidateArgument = [string]$argumentByCandidate[$Candidate]
$policyId = [string]$policyByCandidate[$Candidate]
$candidateDigest = [string]$digestByCandidate[$Candidate]
$expectedMorphologies = @($cells | ForEach-Object { $_.morphology_id })
$matrix = if ($isSuccessor) {
    $preregistration.development_matrix
} else {
    $preregistration.physics_matrix
}
$preregisteredMorphologies =
    @($matrix.opened_counterexample_morphology_ids)
$counterexampleWorldCount = if ($isSuccessor) {
    [int]$matrix.opened_counterexample_world_count
} else {
    [int]$matrix.counterexample_world_count
}
$matrixWorldCount = if ($isSuccessor) {
    [int]$matrix.expected_world_count_per_candidate
} else {
    [int]$matrix.total_world_count_per_opened_candidate
}
if (
    [string]$preregistration.schema_version -cne $expectedPreregistrationSchema -or
    [string]$preregistration.status -cne $expectedPreregistrationStatus -or
    $counterexampleWorldCount -ne 4 -or
    $matrixWorldCount -ne $expectedTotalWorldCount -or
    (($preregistration.candidate_order | ForEach-Object { [string]$_ }) -join ",") -cne
        $expectedCandidateOrder -or
    [string]$preregistration.candidate_policy_digests[$Candidate] -cne $candidateDigest -or
    [string]::Join("`n", $preregisteredMorphologies) -cne
        [string]::Join("`n", $expectedMorphologies)
) {
    throw "BW2 preregistration identity, candidate, or counterexample matrix is invalid"
}

$sourceCommit = ""
$outputPath = ""
$outputDirectory = ""
if (-not $PreflightOnly) {
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    if ($LASTEXITCODE -ne 0 -or $sourceStatus.Count -ne 0) {
        throw "Refusing to open BW2 counterexamples from dirty or unreadable source"
    }
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($sourceCommit) -or
        $sourceCommit -cne $originMain
    ) {
        throw "Refusing BW2 counterexamples because HEAD does not match origin/main"
    }
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained BW2 counterexample report filename must be report.json"
    }
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to overwrite a BW2 counterexample report: $outputPath"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        $existing = @(Get-ChildItem -LiteralPath $outputDirectory -Force)
        if ($existing.Count -ne 0) {
            throw "Refusing a nonempty BW2 counterexample directory: $outputDirectory"
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
; Isolated SporeSpore balanced-wave BW2 opened counterexample matrix.

config_version=5

[application]

config/name="sporespore-balanced-wave-bw2-counterexamples"
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
$preflightTranscriptPath = Join-Path $runRoot "preflight-transcript.log"
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
    if ($LASTEXITCODE -ne 0) {
        throw "BW2 no-world contract failed before a counterexample opened"
    }

    & $godotPath `
        --headless `
        --path $projectRoot `
        --script "res://$testPath" `
        2>&1 | Tee-Object -FilePath $preflightTranscriptPath
    if ($LASTEXITCODE -ne 0) {
        throw "BW2 counterexample no-world parse/preflight failed"
    }

    if ($PreflightOnly) {
        Write-Host (
            "BALANCED_WAVE_BW2_COUNTEREXAMPLE_PREFLIGHT=true " +
            "WORLDS=0 CELLS=$($cells.Count)"
        )
        exit 0
    }

    $cellResults = @()
    $cellTranscripts = [ordered]@{}
    $cellEngineLogs = [ordered]@{}
    foreach ($cell in $cells) {
        $cellId = [string]$cell.morphology_id
        $transcriptPath = Join-Path $runRoot "$cellId-transcript.log"
        $engineLogPath = Join-Path $runRoot "$cellId-engine.log"
        Write-Host (
            "BW2_COUNTEREXAMPLE_CELL_START $cellId " +
            "role=$($cell.role) repetition=$($cell.repetition)"
        )
        & $godotPath `
            --headless `
            --path $projectRoot `
            --log-file $engineLogPath `
            --script "res://$testPath" `
            -- `
            "G4-GQ15" `
            $cellId `
            ([string]$cell.role) `
            ([string]$cell.repetition) `
            $candidateArgument `
            2>&1 | Tee-Object -FilePath $transcriptPath
        $cellExitCode = $LASTEXITCODE
        $receiptLines = @(
            Get-Content -LiteralPath $transcriptPath |
                Where-Object { $_.StartsWith($receiptPrefix) }
        )
        if ($receiptLines.Count -eq 1) {
            $cellReceipt = $receiptLines[0].Substring($receiptPrefix.Length) |
                ConvertFrom-Json -AsHashtable
        } else {
            $cellReceipt = [ordered]@{
                schema_version =
                    "sporespore_balanced_wave_bw2_counterexample_cell_receipt_v1"
                ok = $false
                morphology_id = $cellId
                failure_code = "CELL_RECEIPT_CARDINALITY_INVALID"
                observed_receipt_line_count = $receiptLines.Count
                partial_outcome_retained = $true
            }
        }
        $cellResults += [ordered]@{
            godot_exit_code = $cellExitCode
            receipt = $cellReceipt
        }
        $cellTranscripts[$cellId] = $transcriptPath
        $cellEngineLogs[$cellId] = $engineLogPath
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

$integrityFailureCount = @(
    $cellResults |
        Where-Object {
            [int]$_.godot_exit_code -ne 0 -or
            -not [bool]$_.receipt.ok -or
            [string]$_.receipt.schema_version -cne
                "sporespore_balanced_wave_bw2_counterexample_cell_receipt_v1" -or
            [string]$_.receipt.candidate_id -cne $Candidate -or
            [string]$_.receipt.policy_id -cne $policyId -or
            [int]$_.receipt.world_build_count -ne 1 -or
            [int]$_.receipt.step_count -ne 1514 -or
            [int]$_.receipt.validated_balanced_wave_command_count -ne 12112 -or
            [int]$_.receipt.native_motor_write_count -ne 12112 -or
            [int]$_.receipt.portable_controller_base_application_count -ne 12112 -or
            [string]$_.receipt.base_command_source -cne
                "portable_controller_ordered_commands" -or
            [int]$_.receipt.nonzero_stability_application_count -le 0 -or
            [int]$_.receipt.direct_body_write_count -ne 0
        }
).Count
$counterexampleNonwalkCount = @(
    $cellResults | Where-Object { -not [bool]$_.receipt.walking_observed }
).Count
$integrityAccepted = (
    $cellResults.Count -eq 4 -and
    $integrityFailureCount -eq 0
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
    throw "BW2 source changed or became dirty while counterexamples ran"
}

[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$retainedContract = Join-Path $outputDirectory "contract-transcript.log"
$retainedPreflight = Join-Path $outputDirectory "preflight-transcript.log"
[System.IO.File]::Copy($contractTranscriptPath, $retainedContract, $false)
[System.IO.File]::Copy($preflightTranscriptPath, $retainedPreflight, $false)
$transcripts = [ordered]@{
    contract = [ordered]@{
        path = "contract-transcript.log"
        sha256 = (
            Get-FileHash -Algorithm SHA256 -LiteralPath $retainedContract
        ).Hash.ToLowerInvariant()
    }
    preflight = [ordered]@{
        path = "preflight-transcript.log"
        sha256 = (
            Get-FileHash -Algorithm SHA256 -LiteralPath $retainedPreflight
        ).Hash.ToLowerInvariant()
    }
}
foreach ($cell in $cells) {
    $cellId = [string]$cell.morphology_id
    $transcriptName = "$cellId-transcript.log"
    $engineName = "$cellId-engine.log"
    $retainedTranscript = Join-Path $outputDirectory $transcriptName
    $retainedEngine = Join-Path $outputDirectory $engineName
    [System.IO.File]::Copy(
        [string]$cellTranscripts[$cellId],
        $retainedTranscript,
        $false
    )
    [System.IO.File]::Copy(
        [string]$cellEngineLogs[$cellId],
        $retainedEngine,
        $false
    )
    $transcripts[$cellId] = [ordered]@{
        transcript = [ordered]@{
            path = $transcriptName
            sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $retainedTranscript
            ).Hash.ToLowerInvariant()
        }
        engine = [ordered]@{
            path = $engineName
            sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $retainedEngine
            ).Hash.ToLowerInvariant()
        }
    }
}

$sourcePaths = [ordered]@{
    bootstrap = "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"
    preregistration = "sdk/$preregistrationName"
    runner = "sdk/run_balanced_wave_bw2_counterexamples.ps1"
    contract_test = $contractTestPath
    counterexample_test = $testPath
    proportion_spec = "scripts/lab/gait/physical_quadruped_proportion_spec.gd"
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
    schema_version = "sporespore_balanced_wave_bw2_counterexample_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    accepted = $integrityAccepted
    result_status = $(if ($integrityAccepted) { "integrity_accepted" } else { "rejected" })
    development_data_only = $true
    candidate_id = $Candidate
    policy_id = $policyId
    candidate_policy_digest = $candidateDigest
    expected_world_count = 4
    observed_world_count = $cellResults.Count
    integrity_failure_count = $integrityFailureCount
    counterexample_nonwalk_count = $counterexampleNonwalkCount
    cells = $cellResults
    walking_acceptance = $false
    arbitrary_quadruped_coverage = $false
    continuous_full_volume_coverage = $false
    material_robustness = $false
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
    transcripts = $transcripts
}
$temporaryPath = "$outputPath.tmp"
$json = $report | ConvertTo-Json -Depth 64
[System.IO.File]::WriteAllText(
    $temporaryPath,
    "$json`n",
    [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::Move($temporaryPath, $outputPath, $false)
Write-Host "Retained BW2 counterexample report: $outputPath"

if (-not $integrityAccepted) {
    throw "The BW2 counterexample matrix failed integrity. Report: $outputPath"
}
Write-Host (
    "BALANCED_WAVE_BW2_COUNTEREXAMPLE_INTEGRITY=true " +
    "WORLDS=$($cellResults.Count) NONWALKS=$counterexampleNonwalkCount"
)
