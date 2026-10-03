#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_balanced_wave_bw4_validation"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly,
    [ValidateSet(
        "BW2R-C", "BW4R-A", "BW4R-B",
        "BW5R-A", "BW5R-B", "BW5R-C"
    )]
    [string]$Candidate = "BW2R-C"
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$manifestPath = Join-Path $sdkRoot "balanced_wave_bw4_validation_manifest.json"
$validationTestPath = "tests/test_sdk_balanced_wave_bw4_validation.gd"
$isBw4rCandidate = $Candidate.StartsWith(
    "BW4R-",
    [System.StringComparison]::Ordinal
)
$isBw5rCandidate = $Candidate.StartsWith(
    "BW5R-",
    [System.StringComparison]::Ordinal
)
$openedDevelopmentReplay = $isBw4rCandidate -or $isBw5rCandidate
$candidateSpecs = @{
    "BW2R-C" = @{
        policy_id = "sporespore_balanced_wave_bw2r_c_v1"
        policy_digest =
            "sha256:709aacc898e62a0c1902a04a201006f5501934562cabec4b68c1613811ae0ad0"
        argument = ""
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
$expectedPolicyId = [string]$candidateSpec.policy_id
$expectedPolicyDigest = [string]$candidateSpec.policy_digest
$candidateArgument = [string]$candidateSpec.argument
$contractTestPath = if ($isBw5rCandidate) {
    "tests/test_sdk_balanced_wave_bw5r_authority_contract.gd"
} elseif ($isBw4rCandidate) {
    "tests/test_sdk_balanced_wave_bw4r_authority_contract.gd"
} else {
    "tests/test_sdk_balanced_wave_bw2r_authority_contract.gd"
}
$frozenSelectedPolicyId = "sporespore_balanced_wave_bw2r_c_v1"
$frozenSelectedPolicyDigest =
    "sha256:709aacc898e62a0c1902a04a201006f5501934562cabec4b68c1613811ae0ad0"
$expectedCellIds = @(
    "validation_mu015_s18001_treatment",
    "validation_mu015_s18001_control",
    "validation_mu015_s18002_treatment",
    "validation_mu015_s18003_treatment",
    "validation_mu050_s18001_treatment",
    "validation_mu050_s18001_control",
    "validation_mu050_s18002_treatment",
    "validation_mu050_s18003_treatment",
    "validation_mu090_s18001_treatment",
    "validation_mu090_s18001_control",
    "validation_mu090_s18002_treatment",
    "validation_mu090_s18003_treatment",
    "validation_mu140_s18001_treatment",
    "validation_mu140_s18001_control",
    "validation_mu140_s18002_treatment",
    "validation_mu140_s18003_treatment",
    "negative_mu000_s18001_control"
)
$expectedProfileIds = @(
    "godot_jolt_bw4_mu015_v1",
    "godot_jolt_bw4_mu050_v1",
    "godot_jolt_bw4_mu090_v1",
    "godot_jolt_bw4_mu140_v1"
)
$expectedProfileDigests = @(
    "sha256:5ce384234368bb6b64d3bb820da22ed47faa7ffbe274c9e3c9c3cd4b88c4fa6e",
    "sha256:dbfc36e296682aec6b580319dd38ffae4c094e7a6cf66af2018a4f9bafc1e6dd",
    "sha256:44dca6e33a70a939599affb091049a4fd478a35f3f3fe154c922f39e917ea240",
    "sha256:b882df0698d2785d3512c935c46e1eb79092e29b5fadc86f5d28669369469384"
)
$expectedZeroProfileId = "godot_jolt_p5m1r1_mu000_v1"
$expectedZeroProfileDigest =
    "sha256:b70b71e4aa16f877d1ddaf45ffc233a23300196eeb3240f4fefbe666b915b070"

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "BW4 validation manifest not found: $manifestPath"
}
if ($PreflightOnly -and -not [string]::IsNullOrWhiteSpace($Output)) {
    throw "BW4 validation preflight cannot retain a physics report"
}
if (-not $PreflightOnly -and [string]::IsNullOrWhiteSpace($Output)) {
    throw "The full BW4 validation requires a durable -Output report.json path"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable
$bw3r = $manifest.prerequisite_evidence.bw3r_validation
$characterization = $manifest.prerequisite_evidence.material_characterization
$publication = $manifest.prerequisite_evidence.material_profile_publication
$bw3rPath = [string]$bw3r.path
$characterizationPath = [string]$characterization.path
$publicationPath = [string]$publication.path
foreach ($evidencePath in @(
    $bw3rPath,
    $characterizationPath,
    $publicationPath
)) {
    if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
        throw "BW4 prerequisite evidence is missing: $evidencePath"
    }
}
$bw3rHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $bw3rPath
).Hash.ToLowerInvariant()
$characterizationHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $characterizationPath
).Hash.ToLowerInvariant()
$publicationHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $publicationPath
).Hash.ToLowerInvariant()
$bw3rReport = Get-Content -Raw -LiteralPath $bw3rPath |
    ConvertFrom-Json -AsHashtable
$characterizationReport = Get-Content -Raw -LiteralPath $characterizationPath |
    ConvertFrom-Json -AsHashtable
$publicationReport = Get-Content -Raw -LiteralPath $publicationPath |
    ConvertFrom-Json -AsHashtable

$manifestProfileIds = @(
    $manifest.profiles | ForEach-Object { [string]$_.profile_id }
)
$manifestProfileDigests = @(
    $manifest.profiles | ForEach-Object { [string]$_.profile_digest }
)
$manifestCellIds = @(
    $manifest.matrix.ordered_cell_ids | ForEach-Object { [string]$_ }
)
$manifestSeeds = @($manifest.matrix.seeds | ForEach-Object { [int]$_ })
$manifestFrictionValues = @(
    $manifest.claims_if_accepted.scope.authored_friction_values |
        ForEach-Object { [double]$_ }
)
$manifestContractPassed = (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw4_validation_manifest_v1" -and
    [string]$manifest.status -ceq
        "frozen_before_first_bw4_validation_world" -and
    [string]$manifest.freeze_parent_commit -ceq
        "36739aa9e50c7330f9e6f230daaca58445fd8bba" -and
    [string]$manifest.campaign_partition -ceq "cold_acceptance" -and
    -not [bool]$manifest.development_data_only -and
    -not [bool]$manifest.locomotion_outcome_exposed -and
    [string]$manifest.selected_policy.candidate_id -ceq "BW2R-C" -and
    [string]$manifest.selected_policy.policy_id -ceq $frozenSelectedPolicyId -and
    [string]$manifest.selected_policy.policy_digest -ceq
        $frozenSelectedPolicyDigest -and
    $bw3rHash -ceq [string]$bw3r.sha256 -and
    $characterizationHash -ceq [string]$characterization.sha256 -and
    $publicationHash -ceq [string]$publication.sha256 -and
    ($manifestProfileIds -join ",") -ceq ($expectedProfileIds -join ",") -and
    ($manifestProfileDigests -join ",") -ceq
        ($expectedProfileDigests -join ",") -and
    [string]$manifest.zero_friction_safety_profile.profile_id -ceq
        $expectedZeroProfileId -and
    [string]$manifest.zero_friction_safety_profile.profile_digest -ceq
        $expectedZeroProfileDigest -and
    ($manifestCellIds -join ",") -ceq ($expectedCellIds -join ",") -and
    ($manifestSeeds -join ",") -ceq "18001,18002,18003" -and
    ($manifestFrictionValues -join ",") -ceq "0.15,0.5,0.9,1.4" -and
    [int]$manifest.matrix.expected_treatment_world_count -eq 12 -and
    [int]$manifest.matrix.expected_control_world_count -eq 4 -and
    [int]$manifest.matrix.expected_zero_friction_safety_world_count -eq 1 -and
    [int]$manifest.matrix.expected_causal_pair_count -eq 4 -and
    [int]$manifest.matrix.expected_world_count -eq 17 -and
    [int]$manifest.matrix.zero_friction_native_motor_write_count -eq 0 -and
    [int]$manifest.gate_contract.expected_gate_count -eq 28 -and
    [int]$manifest.gate_contract.preflight_gate_count -eq 3 -and
    [int]$manifest.gate_contract.per_world_execution_integrity_gate_count -eq
        17 -and
    [int]$manifest.gate_contract.aggregate_gate_count -eq 8 -and
    [bool]$manifest.gate_contract.first_result_is_final_for_this_source_identity -and
    [bool]$manifest.gate_contract.failed_cell_replacement_forbidden -and
    [bool]$manifest.gate_contract.post_result_gate_edit_forbidden -and
    [bool]$manifest.claims_if_accepted.bw4_cold_acceptance_authority -and
    [bool]$manifest.claims_if_accepted.walking_acceptance -and
    [bool]$manifest.claims_if_accepted.bounded_discrete_material_robustness -and
    [bool]$manifest.claims_if_accepted.material_robustness
)
if (-not $manifestContractPassed) {
    throw "BW4 validation manifest or prerequisite identity is invalid"
}

$bw3rEvidencePassed = (
    [string]$bw3rReport.schema_version -ceq
        "sporespore_balanced_wave_bw3r_validation_report_v1" -and
    [bool]$bw3rReport.accepted -and
    [string]$bw3rReport.result_status -ceq "validation_passed" -and
    [bool]$bw3rReport.development_data_only -and
    [int]$bw3rReport.receipt.passed_gate_count -eq 22 -and
    [int]$bw3rReport.receipt.failed_gate_count -eq 0 -and
    [int]$bw3rReport.receipt.observed_world_count -eq 12
)
$characterizationEvidencePassed = (
    [string]$characterizationReport.schema_version -ceq
        "sporespore_balanced_wave_bw4_material_characterization_report_v1" -and
    [bool]$characterizationReport.accepted -and
    [string]$characterizationReport.campaign -ceq "BW4" -and
    [bool]$characterizationReport.cold_characterization -and
    -not [bool]$characterizationReport.development_data_only -and
    [int]$characterizationReport.receipt.passed_gate_count -eq 23 -and
    [int]$characterizationReport.receipt.failed_gate_count -eq 0 -and
    [int]$characterizationReport.receipt.observed_world_count -eq 13
)
$publicationEvidencePassed = (
    [string]$publicationReport.schema_version -ceq
        "sporespore_godot_jolt_material_profile_report_v1" -and
    [bool]$publicationReport.accepted -and
    [string]$publicationReport.result_status -ceq "passed" -and
    [int]$publicationReport.receipt.passed_gate_count -eq 29 -and
    [int]$publicationReport.receipt.failed_gate_count -eq 0 -and
    [int]$publicationReport.receipt.observed_world_count -eq 0 -and
    [int]$publicationReport.receipt.observed_profile_count -eq 18 -and
    [int]$publicationReport.receipt.bw4_profile_count -eq 4
)
if (-not (
    $bw3rEvidencePassed -and
    $characterizationEvidencePassed -and
    $publicationEvidencePassed
)) {
    throw "One or more pinned BW4 prerequisite reports failed acceptance checks"
}

$sourceCommit = ""
$outputPath = ""
$outputDirectory = ""
if (-not $PreflightOnly) {
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the BW4 source worktree"
    }
    if ($sourceStatus.Count -ne 0) {
        throw "Refusing to open BW4 validation worlds from dirty source"
    }
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($sourceCommit) -or
        $sourceCommit -cne $originMain
    ) {
        throw "Refusing BW4 validation because HEAD does not match origin/main"
    }
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained BW4 validation report filename must be exactly report.json"
    }
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to overwrite an existing BW4 validation report: $outputPath"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        $existing = @(Get-ChildItem -LiteralPath $outputDirectory -Force)
        if ($existing.Count -ne 0) {
            throw "Refusing a nonempty retained BW4 validation directory: $outputDirectory"
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
; Isolated SporeSpore balanced-wave BW4 cold material acceptance.

config_version=5

[application]

config/name="sporespore-balanced-wave-bw4-validation"
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
            "Selected BW2R-C no-world contract failed before BW4 opened. " +
            "Transcript: $contractTranscriptPath"
        )
    }
    $validationArguments = @(
        "--headless",
        "--path", $projectRoot,
        "--log-file", $engineLogPath,
        "--script", "res://$validationTestPath"
    )
    if ($PreflightOnly) {
        $validationArguments += @("--", "--preflight-only")
        if (-not [string]::IsNullOrWhiteSpace($candidateArgument)) {
            $validationArguments += $candidateArgument
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($candidateArgument)) {
        $validationArguments += @("--", $candidateArgument)
    }
    & $godotPath @validationArguments 2>&1 |
        Tee-Object -FilePath $validationTranscriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

if ($PreflightOnly) {
    $receiptPrefix = "BALANCED_WAVE_BW4_VALIDATION_PREFLIGHT_RECEIPT "
    $expectedSchema =
        "sporespore_balanced_wave_bw4_validation_preflight_receipt_v1"
} else {
    $receiptPrefix = "BALANCED_WAVE_BW4_VALIDATION_RECEIPT "
    $expectedSchema = "sporespore_balanced_wave_bw4_validation_receipt_v1"
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
        failure_code = "BW4_VALIDATION_RECEIPT_CARDINALITY_INVALID"
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
        [string]$receipt.policy_id -ceq $expectedPolicyId -and
        [string]$receipt.candidate_policy_digest -ceq $expectedPolicyDigest -and
        [string]$receipt.campaign_partition -ceq $(if ($openedDevelopmentReplay) {
            "opened_bw4_development_replay"
        } else {
            "cold_acceptance"
        }) -and
        [int]$receipt.expected_world_count -eq 17 -and
        [int]$receipt.observed_world_count -eq 0 -and
        [int]$receipt.cell_ids.Count -eq 17 -and
        [int]$receipt.seed_receipts.Count -eq 3 -and
        [int]$receipt.profile_receipts.Count -eq 5 -and
        [bool]$receipt.validation_manifest.ok -and
        [bool]$receipt.validation_manifest.selected_policy_manifest_exact -and
        [bool]$receipt.validation_manifest.bw3r_validation_report_hash_exact -and
        [bool]$receipt.validation_manifest.characterization_report_hash_exact -and
        [bool]$receipt.validation_manifest.profile_publication_report_hash_exact -and
        [bool]$receipt.bridge_conformance.ok -and
        -not [bool]$receipt.locomotion_outcome_exposed -and
        -not [bool]$receipt.adapter_actuation_applied -and
        [bool]$receipt.development_data_only -eq $openedDevelopmentReplay -and
        [bool]$receipt.cold_acceptance_partition -eq (-not $openedDevelopmentReplay) -and
        -not [bool]$receipt.cold_acceptance -and
        -not [bool]$receipt.walking_acceptance -and
        -not [bool]$receipt.bounded_discrete_material_robustness -and
        -not [bool]$receipt.material_robustness -and
        -not [bool]$receipt.continuous_friction_coverage -and
        -not [bool]$receipt.cross_engine_c6 -and
        -not [bool]$receipt.completed_engine_neutral_sdk
    )
    if (-not $preflightAccepted) {
        throw (
            "BW4 validation zero-world preflight failed. Godot exit code: " +
            "$godotExitCode. Transcript: $validationTranscriptPath"
        )
    }
    Write-Host "BW4 validation zero-world preflight passed."
    Write-Host "Transcript: $validationTranscriptPath"
    exit 0
}

$expectedPartition = if ($openedDevelopmentReplay) {
    "opened_bw4_development_replay"
} else {
    "cold_acceptance"
}
$validationAccepted = (
    $godotExitCode -eq 0 -and
    [string]$receipt.schema_version -ceq $expectedSchema -and
    [bool]$receipt.ok -and
    [bool]$receipt.validation_passed -eq (-not $openedDevelopmentReplay) -and
    [bool]$receipt.development_matrix_passed -eq $openedDevelopmentReplay -and
    [string]$receipt.candidate_id -ceq $Candidate -and
    [string]$receipt.policy_id -ceq $expectedPolicyId -and
    [string]$receipt.candidate_policy_digest -ceq $expectedPolicyDigest -and
    [string]$receipt.campaign_partition -ceq $expectedPartition -and
    [int]$receipt.passed_gate_count -eq 28 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_gate_count -eq 28 -and
    [int]$receipt.expected_world_count -eq 17 -and
    [int]$receipt.observed_world_count -eq 17 -and
    [int]$receipt.cells.Count -eq 17 -and
    [int]$receipt.expected_treatment_count -eq 12 -and
    [int]$receipt.observed_treatment_count -eq 12 -and
    [int]$receipt.observed_treatment_pass_count -eq 12 -and
    [int]$receipt.treatment_with_nonzero_stability_count -eq 12 -and
    [int]$receipt.expected_control_count -eq 4 -and
    [int]$receipt.observed_control_count -eq 4 -and
    [int]$receipt.observed_control_pass_count -eq 4 -and
    [int]$receipt.expected_pair_count -eq 4 -and
    [int]$receipt.observed_pair_pass_count -eq 4 -and
    [int]$receipt.expected_zero_friction_safety_count -eq 1 -and
    [int]$receipt.observed_zero_friction_safety_count -eq 1 -and
    [int]$receipt.observed_zero_friction_safety_pass_count -eq 1 -and
    [int]$receipt.integrity_failure_count -eq 0 -and
    [bool]$receipt.validation_manifest.ok -and
    [bool]$receipt.development_data_only -eq $openedDevelopmentReplay -and
    [bool]$receipt.cold_acceptance_partition -eq (-not $openedDevelopmentReplay) -and
    [bool]$receipt.cold_acceptance -eq (-not $openedDevelopmentReplay) -and
    [bool]$receipt.bw4_cold_acceptance_authority -eq (-not $openedDevelopmentReplay) -and
    [bool]$receipt.walking_acceptance -eq (-not $openedDevelopmentReplay) -and
    [bool]$receipt.bounded_discrete_material_robustness -eq
        (-not $openedDevelopmentReplay) -and
    [bool]$receipt.material_robustness -eq (-not $openedDevelopmentReplay) -and
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
    throw "BW4 source changed or became dirty while validation ran"
}

[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$retainedContractTranscript = Join-Path $outputDirectory "contract-transcript.log"
$retainedValidationTranscript = Join-Path $outputDirectory "validation-transcript.log"
$retainedEngineLog = Join-Path $outputDirectory "engine.log"
[System.IO.File]::Copy($contractTranscriptPath, $retainedContractTranscript, $false)
[System.IO.File]::Copy($validationTranscriptPath, $retainedValidationTranscript, $false)
[System.IO.File]::Copy($engineLogPath, $retainedEngineLog, $false)

$activePreregistrationPath = if ($openedDevelopmentReplay) {
    if ($isBw5rCandidate) {
        "sdk/balanced_wave_bw5r_preregistration.json"
    } else {
        "sdk/balanced_wave_bw4r_preregistration.json"
    }
} else {
    "sdk/balanced_wave_bw4_preregistration.json"
}
$sourcePaths = [ordered]@{
    bootstrap = "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"
    friction_bootstrap = (
        "docs/SDK_GODOT_JOLT_FRICTION_MATERIAL_ROBUSTNESS_BOOTSTRAP.md"
    )
    preregistration = $activePreregistrationPath
    validation_manifest = "sdk/balanced_wave_bw4_validation_manifest.json"
    selected_policy = "sdk/balanced_wave_selected_policy.json"
    runner = "sdk/run_balanced_wave_bw4_validation.ps1"
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
    schema_version = $(if ($openedDevelopmentReplay) {
        if ($isBw5rCandidate) {
            "sporespore_balanced_wave_bw5r_opened_bw4_replay_report_v1"
        } else {
            "sporespore_balanced_wave_bw4r_opened_bw4_replay_report_v1"
        }
    } else {
        "sporespore_balanced_wave_bw4_validation_report_v1"
    })
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    accepted = $validationAccepted
    result_status = $(if ($validationAccepted) {
        $(if ($openedDevelopmentReplay) {
            "development_matrix_passed"
        } else {
            "cold_acceptance_passed"
        })
    } else {
        "rejected"
    })
    campaign_partition = $expectedPartition
    development_data_only = $openedDevelopmentReplay
    candidate_id = $Candidate
    policy_id = $expectedPolicyId
    candidate_policy_digest = $expectedPolicyDigest
    godot_exit_code = $godotExitCode
    prerequisite_evidence = [ordered]@{
        bw3r_validation = [ordered]@{
            path = $bw3rPath
            sha256 = $bw3rHash
        }
        material_characterization = [ordered]@{
            path = $characterizationPath
            sha256 = $characterizationHash
        }
        material_profile_publication = [ordered]@{
            path = $publicationPath
            sha256 = $publicationHash
        }
    }
    cold_acceptance = $validationAccepted -and -not $openedDevelopmentReplay
    walking_acceptance = $validationAccepted -and -not $openedDevelopmentReplay
    bounded_discrete_material_robustness =
        $validationAccepted -and -not $openedDevelopmentReplay
    material_robustness = $validationAccepted -and -not $openedDevelopmentReplay
    material_robustness_scope = $receipt.material_robustness_scope
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
Write-Host "Retained BW4 validation report: $outputPath"

if (-not $validationAccepted) {
    throw (
        "The frozen BW4 matrix result was rejected. Godot exit code: " +
        "$godotExitCode. Report: $outputPath"
    )
}

Write-Host (
    "BALANCED_WAVE_BW4_VALIDATION=true " +
    "GATES=$([int]$receipt.passed_gate_count)/28 " +
    "WORLDS=$([int]$receipt.observed_world_count) " +
    "TREATMENTS=$([int]$receipt.observed_treatment_pass_count)/12 " +
    "CONTROLS=$([int]$receipt.observed_control_pass_count)/4 " +
    "PAIRS=$([int]$receipt.observed_pair_pass_count)/4 " +
    "ZERO=$([int]$receipt.observed_zero_friction_safety_pass_count)/1"
)
