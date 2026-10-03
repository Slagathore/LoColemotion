#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_balanced_wave_bw3_validation"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly,
    [ValidateSet("BW3", "BW3R", "BW5V")]
    [string]$Campaign = "BW3",
    [ValidateSet(
        "BW2-C", "BW2R-A", "BW2R-B", "BW2R-C",
        "BW4R-A", "BW4R-B",
        "BW5R-A", "BW5R-B", "BW5R-C"
    )]
    [string]$Candidate = "BW2-C"
)

$ErrorActionPreference = "Stop"
$isBw3r = $Campaign -ceq "BW3R"
$isBw5v = $Campaign -ceq "BW5V"
$isBw4rCandidate = $Candidate.StartsWith(
    "BW4R-",
    [System.StringComparison]::Ordinal
)
$isBw5rCandidate = $Candidate.StartsWith(
    "BW5R-",
    [System.StringComparison]::Ordinal
)
$isSuccessorCandidate = $isBw4rCandidate -or $isBw5rCandidate
if ($isBw3r -and $Candidate -cne "BW2R-C" -and -not $isSuccessorCandidate) {
    throw "BW3R is frozen to BW2R-C except explicit opened successor development replay"
}
if ($isBw5v -and $Candidate -cne "BW5R-B") {
    throw "BW5V independent validation is frozen to BW5R-B"
}
$campaignLabel = if ($isBw5v) {
    "BW5V"
} elseif ($isBw3r) {
    "BW3R"
} else {
    "BW3"
}
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$manifestPath = Join-Path $sdkRoot $(if ($isBw5v) {
    "balanced_wave_bw5v_validation_manifest.json"
} elseif ($isBw3r) {
    "balanced_wave_bw3r_validation_manifest.json"
} else {
    "balanced_wave_bw3_validation_manifest.json"
})
$validationTestPath = "tests/test_sdk_balanced_wave_bw3_validation.gd"
$candidateSpecs = @{
    "BW2-C" = @{
        policy_id = "sporespore_balanced_wave_bw2_c_v1"
        policy_digest =
            "sha256:367e944b33384d8685d746dca0a864cfa33ca013846636236512641456d51ad3"
        argument = ""
    }
    "BW2R-A" = @{
        policy_id = "sporespore_balanced_wave_bw2r_a_v1"
        policy_digest =
            "sha256:4ffb7abd947f60287b81c9105fb99b2964355d0e16e13b64bc8b18d9fcec6343"
        argument = "--bw2r-a"
    }
    "BW2R-B" = @{
        policy_id = "sporespore_balanced_wave_bw2r_b_v1"
        policy_digest =
            "sha256:44e8bfd0e4e1227db56ace8c58fc62fa6dd6bfc0d1cb993367510214272da144"
        argument = "--bw2r-b"
    }
    "BW2R-C" = @{
        policy_id = "sporespore_balanced_wave_bw2r_c_v1"
        policy_digest =
            "sha256:709aacc898e62a0c1902a04a201006f5501934562cabec4b68c1613811ae0ad0"
        argument = "--bw2r-c"
    }
    "BW4R-A" = @{
        policy_id = "sporespore_balanced_wave_bw4r_a_v1"
        policy_digest =
            "sha256:40dc551e99fea518df68c35d49e3d7d9605484e25cb385f938b3568ddcab2cf4"
        argument = "--bw4r-a"
    }
    "BW4R-B" = @{
        policy_id = "sporespore_balanced_wave_bw4r_b_v1"
        policy_digest =
            "sha256:2496dc6da6dea17cfc7ffee0027234fa7a2a0f4eea8bc463a68db9a9d105bae7"
        argument = "--bw4r-b"
    }
    "BW5R-A" = @{
        policy_id = "sporespore_balanced_wave_bw5r_a_v1"
        policy_digest =
            "sha256:6001dd2b5926908a1bad16d17e49e233cbfb1dfa7eb360bdfe8e4df147b245ac"
        argument = "--bw5r-a"
    }
    "BW5R-B" = @{
        policy_id = "sporespore_balanced_wave_bw5r_b_v1"
        policy_digest =
            "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
        argument = "--bw5r-b"
    }
    "BW5R-C" = @{
        policy_id = "sporespore_balanced_wave_bw5r_c_v1"
        policy_digest =
            "sha256:c067ece936a53edb9cc9d667a68274451e4db67b762ab262bf42e8efe88d742d"
        argument = "--bw5r-c"
    }
}
$candidateSpec = $candidateSpecs[$Candidate]
$policyId = [string]$candidateSpec.policy_id
$policyDigest = [string]$candidateSpec.policy_digest
$candidateArgument = [string]$candidateSpec.argument
$openedDevelopmentReplay = -not $isBw5v -and (
    $isSuccessorCandidate -or (-not $isBw3r -and $Candidate -cne "BW2-C")
)
$contractTestPath = if ($isBw5rCandidate) {
    "tests/test_sdk_balanced_wave_bw5r_authority_contract.gd"
} elseif ($isBw4rCandidate) {
    "tests/test_sdk_balanced_wave_bw4r_authority_contract.gd"
} elseif ($isBw3r -or $openedDevelopmentReplay) {
    "tests/test_sdk_balanced_wave_bw2r_authority_contract.gd"
} else {
    "tests/test_sdk_balanced_wave_bw2_authority_contract.gd"
}

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "$campaignLabel validation manifest not found: $manifestPath"
}
if ($PreflightOnly -and -not [string]::IsNullOrWhiteSpace($Output)) {
    throw "$campaignLabel validation preflight cannot retain a physics report"
}
if (-not $PreflightOnly -and [string]::IsNullOrWhiteSpace($Output)) {
    throw "The full $campaignLabel validation requires a durable -Output report.json path"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable
$characterization = $manifest.prerequisite_evidence.material_characterization
$publication = $manifest.prerequisite_evidence.material_profile_publication
$characterizationPath = [string]$characterization.path
$publicationPath = [string]$publication.path
if (-not (Test-Path -LiteralPath $characterizationPath -PathType Leaf)) {
    throw "$campaignLabel characterization evidence is missing: $characterizationPath"
}
if (-not (Test-Path -LiteralPath $publicationPath -PathType Leaf)) {
    throw "$campaignLabel profile-publication evidence is missing: $publicationPath"
}
$characterizationHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $characterizationPath
).Hash.ToLowerInvariant()
$publicationHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $publicationPath
).Hash.ToLowerInvariant()
$manifestProfileIds = @(
    $manifest.profiles | ForEach-Object { [string]$_.profile_id }
)
$manifestCellIds = @(
    $manifest.matrix.ordered_cell_ids | ForEach-Object { [string]$_ }
)
$expectedCellIds = if ($isBw5v) {
    @(
        "validation_mu005_s19501_treatment",
        "validation_mu005_s19501_control",
        "validation_mu005_s19502_treatment",
        "validation_mu005_s19503_treatment",
        "validation_mu065_s19501_treatment",
        "validation_mu065_s19501_control",
        "validation_mu065_s19502_treatment",
        "validation_mu065_s19503_treatment",
        "validation_mu130_s19501_treatment",
        "validation_mu130_s19501_control",
        "validation_mu130_s19502_treatment",
        "validation_mu130_s19503_treatment"
    )
} elseif ($isBw3r) {
    @(
        "validation_mu025_s17501_treatment",
        "validation_mu025_s17501_control",
        "validation_mu025_s17502_treatment",
        "validation_mu025_s17503_treatment",
        "validation_mu055_s17501_treatment",
        "validation_mu055_s17501_control",
        "validation_mu055_s17502_treatment",
        "validation_mu055_s17503_treatment",
        "validation_mu110_s17501_treatment",
        "validation_mu110_s17501_control",
        "validation_mu110_s17502_treatment",
        "validation_mu110_s17503_treatment"
    )
} else {
    @(
        "validation_mu030_s17001_treatment",
        "validation_mu030_s17001_control",
        "validation_mu030_s17002_treatment",
        "validation_mu030_s17003_treatment",
        "validation_mu070_s17001_treatment",
        "validation_mu070_s17001_control",
        "validation_mu070_s17002_treatment",
        "validation_mu070_s17003_treatment",
        "validation_mu120_s17001_treatment",
        "validation_mu120_s17001_control",
        "validation_mu120_s17002_treatment",
        "validation_mu120_s17003_treatment"
    )
}
$expectedManifestSchema = if ($isBw5v) {
    "sporespore_balanced_wave_bw5v_validation_manifest_v1"
} elseif ($isBw3r) {
    "sporespore_balanced_wave_bw3r_validation_manifest_v1"
} else {
    "sporespore_balanced_wave_bw3_validation_manifest_v1"
}
$expectedManifestStatus = if ($isBw5v) {
    "frozen_before_first_bw5v_validation_world"
} elseif ($isBw3r) {
    "frozen_before_first_bw3r_validation_world"
} else {
    "frozen_before_first_bw3_validation_world"
}
$expectedFreezeParent = if ($isBw5v) {
    "e76477be61d90829dab0eb70a89505d521e7f8a5"
} elseif ($isBw3r) {
    "2997ea65e6c0a2dce0d3b06ad5ceeb1c50df0beb"
} else {
    "03f36ec58be6c10fdd451db9c278142d54a5f5d0"
}
$expectedSelectedCandidate = if ($isBw5v) {
    "BW5R-B"
} elseif ($isBw3r) {
    "BW2R-C"
} else {
    "BW2-C"
}
$expectedSelectedPolicy = if ($isBw5v) {
    "sporespore_balanced_wave_bw5r_b_v1"
} elseif ($isBw3r) {
    "sporespore_balanced_wave_bw2r_c_v1"
} else {
    "sporespore_balanced_wave_bw2_c_v1"
}
$expectedSelectedDigest = if ($isBw5v) {
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
} elseif ($isBw3r) {
    "sha256:709aacc898e62a0c1902a04a201006f5501934562cabec4b68c1613811ae0ad0"
} else {
    "sha256:367e944b33384d8685d746dca0a864cfa33ca013846636236512641456d51ad3"
}
$expectedProfileIds = if ($isBw5v) {
    "godot_jolt_bw5v_mu005_v1,godot_jolt_bw5v_mu065_v1,godot_jolt_bw5v_mu130_v1"
} elseif ($isBw3r) {
    "godot_jolt_bw3r_mu025_v1,godot_jolt_bw3r_mu055_v1,godot_jolt_bw3r_mu110_v1"
} else {
    "godot_jolt_bw3_mu030_v1,godot_jolt_bw3_mu070_v1,godot_jolt_bw3_mu120_v1"
}
if (
    [string]$manifest.schema_version -cne $expectedManifestSchema -or
    [string]$manifest.status -cne $expectedManifestStatus -or
    [string]$manifest.freeze_parent_commit -cne $expectedFreezeParent -or
    [string]$manifest.selected_policy.candidate_id -cne
        $expectedSelectedCandidate -or
    [string]$manifest.selected_policy.policy_id -cne
        $expectedSelectedPolicy -or
    [string]$manifest.selected_policy.policy_digest -cne
        $expectedSelectedDigest -or
    (
        $isBw5v -and
        [string]$manifest.selected_policy.runtime_profile_digest -cne
            "sha256:e02fa9c7599cffe8b331f7d8c10b6cc4dbffe7408e319169c09cbcb7d9b3890e"
    ) -or
    $characterizationHash -cne [string]$characterization.sha256 -or
    $publicationHash -cne [string]$publication.sha256 -or
    (
        $isBw5v -and (
            -not [bool]$manifest.independent_validation -or
            [string]$characterization.schema_version -cne
                "sporespore_balanced_wave_bw5v_material_characterization_report_v1" -or
            [string]$characterization.source_commit -cne
                "2a5eb94dca81a8c638e31a0d7c9692c270b44ca6" -or
            [int]$characterization.observed_world_count -ne 10 -or
            [int]$characterization.passed_gate_count -ne 19 -or
            [string]$publication.schema_version -cne
                "sporespore_godot_jolt_material_profile_report_v1" -or
            [string]$publication.source_commit -cne
                "e76477be61d90829dab0eb70a89505d521e7f8a5" -or
            [int]$publication.observed_world_count -ne 0 -or
            [int]$publication.passed_gate_count -ne 32
        )
    ) -or
    ($manifestProfileIds -join ",") -cne $expectedProfileIds -or
    ($manifestCellIds -join ",") -cne ($expectedCellIds -join ",") -or
    [int]$manifest.matrix.expected_treatment_world_count -ne 9 -or
    [int]$manifest.matrix.expected_control_world_count -ne 3 -or
    [int]$manifest.matrix.expected_causal_pair_count -ne 3 -or
    [int]$manifest.matrix.expected_world_count -ne 12 -or
    [int]$manifest.gate_contract.expected_gate_count -ne 22 -or
    -not [bool]$manifest.gate_contract.first_result_is_final_for_this_source_identity -or
    -not [bool]$manifest.gate_contract.failed_cell_replacement_forbidden -or
    -not [bool]$manifest.gate_contract.post_result_gate_edit_forbidden
) {
    throw "$campaignLabel validation manifest or prerequisite evidence identity is invalid"
}

$sourceCommit = ""
$outputPath = ""
$outputDirectory = ""
if (-not $PreflightOnly) {
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the BW3 source worktree"
    }
    if ($sourceStatus.Count -ne 0) {
        throw "Refusing to open BW3 validation worlds from dirty source"
    }
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($sourceCommit) -or
        $sourceCommit -cne $originMain
    ) {
        throw "Refusing BW3 validation because HEAD does not match origin/main"
    }
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained BW3 validation report filename must be exactly report.json"
    }
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to overwrite an existing BW3 validation report: $outputPath"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        $existing = @(Get-ChildItem -LiteralPath $outputDirectory -Force)
        if ($existing.Count -ne 0) {
            throw "Refusing a nonempty retained BW3 validation directory: $outputDirectory"
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
; Isolated SporeSpore balanced-wave BW3 material validation.

config_version=5

[application]

config/name="sporespore-balanced-wave-bw3-validation"
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
$validationTranscriptPath = Join-Path $runRoot "validation-transcript.log"
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
            "Selected policy no-world contract failed before $campaignLabel validation opened. " +
            "Transcript: $contractTranscriptPath"
        )
    }

    $validationArguments = @(
        "--headless",
        "--path", $projectRoot,
        "--log-file", $engineLogPath,
        "--script", "res://$validationTestPath"
    )
    $testUserArguments = @()
    if ($PreflightOnly) {
        $testUserArguments += "--preflight-only"
    }
    if ($isBw5v) {
        $testUserArguments += @("--bw5v", $candidateArgument)
    } elseif ($isBw3r) {
        $testUserArguments += @("--bw3r", $candidateArgument)
    } elseif ($openedDevelopmentReplay) {
        $testUserArguments += $candidateArgument
    }
    if ($testUserArguments.Count -gt 0) {
        $validationArguments += "--"
        $validationArguments += $testUserArguments
    }
    & $godotPath @validationArguments 2>&1 |
        Tee-Object -FilePath $validationTranscriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

if ($PreflightOnly) {
    $receiptPrefix = if ($isBw5v) {
        "BALANCED_WAVE_BW5V_VALIDATION_PREFLIGHT_RECEIPT "
    } elseif ($isBw3r) {
        "BALANCED_WAVE_BW3R_VALIDATION_PREFLIGHT_RECEIPT "
    } else {
        "BALANCED_WAVE_BW3_VALIDATION_PREFLIGHT_RECEIPT "
    }
    $expectedSchema = if ($isBw5v) {
        "sporespore_balanced_wave_bw5v_validation_preflight_receipt_v1"
    } elseif ($isBw3r) {
        "sporespore_balanced_wave_bw3r_validation_preflight_receipt_v1"
    } else {
        "sporespore_balanced_wave_bw3_validation_preflight_receipt_v1"
    }
} else {
    $receiptPrefix = if ($isBw5v) {
        "BALANCED_WAVE_BW5V_VALIDATION_RECEIPT "
    } elseif ($isBw3r) {
        "BALANCED_WAVE_BW3R_VALIDATION_RECEIPT "
    } else {
        "BALANCED_WAVE_BW3_VALIDATION_RECEIPT "
    }
    $expectedSchema = if ($isBw5v) {
        "sporespore_balanced_wave_bw5v_validation_receipt_v1"
    } elseif ($isBw3r) {
        "sporespore_balanced_wave_bw3r_validation_receipt_v1"
    } else {
        "sporespore_balanced_wave_bw3_validation_receipt_v1"
    }
}
$receiptLines = @(
    Get-Content -LiteralPath $validationTranscriptPath |
        Where-Object { $_.StartsWith($receiptPrefix) }
)
if ($receiptLines.Count -eq 1) {
    $receipt = $receiptLines[0].Substring($receiptPrefix.Length) |
        ConvertFrom-Json -AsHashtable
} elseif ($PreflightOnly) {
    throw (
        "Expected exactly one $receiptPrefix line, found $($receiptLines.Count). " +
        "Transcript: $validationTranscriptPath"
    )
} else {
    $receipt = [ordered]@{
        schema_version = $expectedSchema
        ok = $false
        validation_passed = $false
        failure_code = "$($campaignLabel.ToUpperInvariant())_VALIDATION_RECEIPT_CARDINALITY_INVALID"
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
        [string]$receipt.candidate_policy_digest -ceq $policyDigest -and
        [int]$receipt.expected_world_count -eq 12 -and
        [int]$receipt.observed_world_count -eq 0 -and
        [int]$receipt.cell_ids.Count -eq 12 -and
        [int]$receipt.seed_receipts.Count -eq 3 -and
        [int]$receipt.profile_receipts.Count -eq 3 -and
        [bool]$receipt.validation_manifest.ok -and
        [bool]$receipt.validation_manifest.replay_policy_exact -and
        [bool]$receipt.opened_validation_replay -eq $openedDevelopmentReplay -and
        [bool]$receipt.validation_data_only -eq (-not $openedDevelopmentReplay) -and
        [bool]$receipt.validation_manifest.characterization_report_hash_exact -and
        [bool]$receipt.validation_manifest.profile_publication_report_hash_exact -and
        [bool]$receipt.bridge_conformance.ok -and
        -not [bool]$receipt.locomotion_outcome_exposed -and
        -not [bool]$receipt.adapter_actuation_applied -and
        -not [bool]$receipt.cold_acceptance -and
        -not [bool]$receipt.walking_acceptance -and
        -not [bool]$receipt.material_robustness -and
        -not [bool]$receipt.cross_engine_c6 -and
        -not [bool]$receipt.completed_engine_neutral_sdk
    )
    if (-not $preflightAccepted) {
        throw (
            "$campaignLabel validation zero-world preflight failed. Godot exit code: " +
            "$godotExitCode. Transcript: $validationTranscriptPath"
        )
    }
    Write-Host "$campaignLabel validation zero-world preflight passed."
    Write-Host "Transcript: $validationTranscriptPath"
    exit 0
}

$validationAccepted = (
    $godotExitCode -eq 0 -and
    [string]$receipt.schema_version -ceq $expectedSchema -and
    [bool]$receipt.ok -and
    [bool]$receipt.validation_passed -and
    [string]$receipt.candidate_id -ceq $Candidate -and
    [string]$receipt.policy_id -ceq $policyId -and
    [string]$receipt.candidate_policy_digest -ceq $policyDigest -and
    [int]$receipt.passed_gate_count -eq 22 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_gate_count -eq 22 -and
    [int]$receipt.expected_world_count -eq 12 -and
    [int]$receipt.observed_world_count -eq 12 -and
    [int]$receipt.cells.Count -eq 12 -and
    [int]$receipt.expected_treatment_count -eq 9 -and
    [int]$receipt.observed_treatment_count -eq 9 -and
    [int]$receipt.observed_treatment_pass_count -eq 9 -and
    [int]$receipt.treatment_with_nonzero_stability_count -eq 9 -and
    [int]$receipt.expected_control_count -eq 3 -and
    [int]$receipt.observed_control_count -eq 3 -and
    [int]$receipt.observed_control_pass_count -eq 3 -and
    [int]$receipt.expected_pair_count -eq 3 -and
    [int]$receipt.observed_pair_pass_count -eq 3 -and
    [int]$receipt.integrity_failure_count -eq 0 -and
    [bool]$receipt.validation_manifest.ok -and
    [bool]$receipt.validation_manifest.replay_policy_exact -and
    [bool]$receipt.opened_validation_replay -eq $openedDevelopmentReplay -and
    [bool]$receipt.validation_data_only -eq (-not $openedDevelopmentReplay) -and
    -not [bool]$receipt.cold_acceptance -and
    -not [bool]$receipt.walking_acceptance -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.arbitrary_material_robustness -and
    -not [bool]$receipt.continuous_friction_coverage -and
    -not [bool]$receipt.balance_improvement -and
    -not [bool]$receipt.physical_balance_recovery -and
    -not [bool]$receipt.rough_terrain_robustness -and
    -not [bool]$receipt.external_push_recovery -and
    -not [bool]$receipt.sensor_fault_robustness -and
    -not [bool]$receipt.arbitrary_quadruped_coverage -and
    -not [bool]$receipt.continuous_full_volume_coverage -and
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
    throw "BW3 source changed or became dirty while validation ran"
}

[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$retainedContractTranscript = Join-Path $outputDirectory "contract-transcript.log"
$retainedValidationTranscript = Join-Path $outputDirectory "validation-transcript.log"
$retainedEngineLog = Join-Path $outputDirectory "engine.log"
[System.IO.File]::Copy($contractTranscriptPath, $retainedContractTranscript, $false)
[System.IO.File]::Copy($validationTranscriptPath, $retainedValidationTranscript, $false)
[System.IO.File]::Copy($engineLogPath, $retainedEngineLog, $false)

$sourcePaths = [ordered]@{
    bootstrap = "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"
    preregistration = $(
        if ($isBw5v) {
            "sdk/balanced_wave_bw5v_preregistration.json"
        } elseif ($isBw5rCandidate) {
            "sdk/balanced_wave_bw5r_preregistration.json"
        } elseif ($isBw4rCandidate) {
            "sdk/balanced_wave_bw4r_preregistration.json"
        } elseif ($isBw3r) {
            "sdk/balanced_wave_bw3r_preregistration.json"
        } elseif ($openedDevelopmentReplay) {
            "sdk/balanced_wave_bw2r_preregistration.json"
        } else {
            "sdk/balanced_wave_bw3_preregistration.json"
        }
    )
    validation_manifest = $(if ($isBw5v) {
        "sdk/balanced_wave_bw5v_validation_manifest.json"
    } elseif ($isBw3r) {
        "sdk/balanced_wave_bw3r_validation_manifest.json"
    } else {
        "sdk/balanced_wave_bw3_validation_manifest.json"
    })
    selected_policy = "sdk/balanced_wave_selected_policy.json"
    runner = "sdk/run_balanced_wave_bw3_validation.ps1"
    campaign_runner = $(if ($isBw5v) {
        "sdk/run_balanced_wave_bw5v_validation.ps1"
    } elseif ($isBw3r) {
        "sdk/run_balanced_wave_bw3r_validation.ps1"
    } else {
        "sdk/run_balanced_wave_bw3_validation.ps1"
    })
    contract_test = $contractTestPath
    validation_test = $validationTestPath
    inherited_material_test = "tests/test_sdk_godot_jolt_material_robustness.gd"
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
    schema_version = $(
        if ($isBw5v) {
            "sporespore_balanced_wave_bw5v_validation_report_v1"
        } elseif ($isSuccessorCandidate) {
            $familyToken = if ($isBw5rCandidate) { "bw5r" } else { "bw4r" }
            if ($isBw3r) {
                "sporespore_balanced_wave_${familyToken}_opened_bw3r_replay_report_v1"
            } else {
                "sporespore_balanced_wave_${familyToken}_opened_bw3_replay_report_v1"
            }
        } elseif ($isBw3r) {
            "sporespore_balanced_wave_bw3r_validation_report_v1"
        } elseif ($openedDevelopmentReplay) {
            "sporespore_balanced_wave_bw2r_opened_bw3_replay_report_v1"
        } else {
            "sporespore_balanced_wave_bw3_validation_report_v1"
        }
    )
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    accepted = $validationAccepted
    result_status = $(
        if ($isBw5v) {
            if ($validationAccepted) {
                "validation_passed"
            } else {
                "rejected"
            }
        } elseif ($isSuccessorCandidate) {
            if ($validationAccepted) {
                "opened_development_replay_passed"
            } else {
                "opened_development_replay_rejected"
            }
        } elseif ($isBw3r) {
            if ($validationAccepted) {
                "validation_passed"
            } else {
                "rejected"
            }
        } elseif ($openedDevelopmentReplay) {
            if ($validationAccepted) {
                "opened_development_replay_passed"
            } else {
                "opened_development_replay_rejected"
            }
        } elseif ($validationAccepted) {
            "validation_passed"
        } else {
            "rejected"
        }
    )
    development_data_only = $true
    campaign_partition = $(if ($isBw5v) {
        "independent_bw5v_validation"
    } elseif ($isSuccessorCandidate) {
        if ($isBw3r) {
            "opened_bw3r_development_replay"
        } else {
            "opened_bw3_development_replay"
        }
    } elseif ($isBw3r) {
        "independent_bw3r_validation"
    } else {
        "bw3_validation_or_opened_replay"
    })
    validation_data_only = -not $openedDevelopmentReplay
    opened_validation_replay = $openedDevelopmentReplay
    cold_acceptance = $false
    candidate_id = $Candidate
    policy_id = $policyId
    candidate_policy_digest = $policyDigest
    godot_exit_code = $godotExitCode
    prerequisite_evidence = [ordered]@{
        material_characterization = [ordered]@{
            path = $characterizationPath
            sha256 = $characterizationHash
        }
        material_profile_publication = [ordered]@{
            path = $publicationPath
            sha256 = $publicationHash
        }
    }
    walking_acceptance = $false
    material_robustness = $false
    arbitrary_material_robustness = $false
    continuous_friction_coverage = $false
    arbitrary_quadruped_coverage = $false
    continuous_full_volume_coverage = $false
    balance_improvement = $false
    physical_balance_recovery = $false
    rough_terrain_robustness = $false
    external_push_recovery = $false
    sensor_fault_robustness = $false
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
        validation = [ordered]@{
            path = "validation-transcript.log"
            sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $retainedValidationTranscript
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
Write-Host "Retained $campaignLabel validation report: $outputPath"

if (-not $validationAccepted) {
    throw (
        "The frozen $campaignLabel matrix result was rejected. Godot exit code: " +
        "$godotExitCode. Report: $outputPath"
    )
}

Write-Host (
    "BALANCED_WAVE_$($campaignLabel.ToUpperInvariant())_VALIDATION=true " +
    "GATES=$([int]$receipt.passed_gate_count)/$([int]$receipt.expected_gate_count) " +
    "WORLDS=$([int]$receipt.observed_world_count) " +
    "TREATMENTS=$([int]$receipt.observed_treatment_pass_count)/9 " +
    "CONTROLS=$([int]$receipt.observed_control_pass_count)/3 " +
    "PAIRS=$([int]$receipt.observed_pair_pass_count)/3"
)
