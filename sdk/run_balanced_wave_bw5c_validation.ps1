#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_balanced_wave_bw5c_validation"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$manifestPath = Join-Path $sdkRoot "balanced_wave_bw5c_validation_manifest.json"
$validationTestPath = "tests/test_sdk_balanced_wave_bw5c_validation.gd"
$Candidate = "BW5R-B"
$expectedPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$expectedPolicyDigest =
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
$candidateArgument = "--bw5r-b"
$contractTestPath = "tests/test_sdk_balanced_wave_bw5r_authority_contract.gd"
$openedDevelopmentReplay = $false
$frozenSelectedPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$frozenSelectedPolicyDigest =
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
$expectedCellIds = @(
    "validation_mu012_s20001_treatment",
    "validation_mu012_s20001_control",
    "validation_mu012_s20002_treatment",
    "validation_mu012_s20003_treatment",
    "validation_mu048_s20001_treatment",
    "validation_mu048_s20001_control",
    "validation_mu048_s20002_treatment",
    "validation_mu048_s20003_treatment",
    "validation_mu095_s20001_treatment",
    "validation_mu095_s20001_control",
    "validation_mu095_s20002_treatment",
    "validation_mu095_s20003_treatment",
    "validation_mu150_s20001_treatment",
    "validation_mu150_s20001_control",
    "validation_mu150_s20002_treatment",
    "validation_mu150_s20003_treatment",
    "negative_mu000_s20001_control"
)
$expectedProfileIds = @(
    "godot_jolt_bw5c_mu012_v1",
    "godot_jolt_bw5c_mu048_v1",
    "godot_jolt_bw5c_mu095_v1",
    "godot_jolt_bw5c_mu150_v1"
)
$expectedProfileDigests = @(
    "sha256:5725972ac4c66b4b61968f93fe347b07c6bf1e0307d99924357784061c086839",
    "sha256:ae1a96af3c9535b9ab33da064975cc480246ee8c7d142ebca0c56f2959ede593",
    "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993",
    "sha256:e5114df3c2e560486fac5cbbc8f2e2ae222223b43a13477324d7fa0a1531ea3f"
)
$expectedZeroProfileId = "godot_jolt_p5m1r1_mu000_v1"
$expectedZeroProfileDigest =
    "sha256:b70b71e4aa16f877d1ddaf45ffc233a23300196eeb3240f4fefbe666b915b070"

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "BW5C validation manifest not found: $manifestPath"
}
if ($PreflightOnly -and -not [string]::IsNullOrWhiteSpace($Output)) {
    throw "BW5C validation preflight cannot retain a physics report"
}
if (-not $PreflightOnly -and [string]::IsNullOrWhiteSpace($Output)) {
    throw "The full BW5C validation requires a durable -Output report.json path"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable
$bw5v = $manifest.prerequisite_evidence.bw5v_validation
$characterization = $manifest.prerequisite_evidence.material_characterization
$publication = $manifest.prerequisite_evidence.material_profile_publication
$bw5vPath = [string]$bw5v.path
$characterizationPath = [string]$characterization.path
$publicationPath = [string]$publication.path
foreach ($evidencePath in @(
    $bw5vPath,
    $characterizationPath,
    $publicationPath
)) {
    if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
        throw "BW5C prerequisite evidence is missing: $evidencePath"
    }
}
$bw5vHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $bw5vPath
).Hash.ToLowerInvariant()
$characterizationHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $characterizationPath
).Hash.ToLowerInvariant()
$publicationHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $publicationPath
).Hash.ToLowerInvariant()
$bw5vReport = Get-Content -Raw -LiteralPath $bw5vPath |
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
        "sporespore_balanced_wave_bw5c_validation_manifest_v1" -and
    [string]$manifest.status -ceq
        "frozen_before_first_bw5c_validation_world" -and
    [string]$manifest.freeze_parent_commit -ceq
        "677e97e140e2408fe56612896d794cc13aae1c64" -and
    [string]$manifest.campaign_partition -ceq "cold_acceptance" -and
    -not [bool]$manifest.development_data_only -and
    -not [bool]$manifest.locomotion_outcome_exposed -and
    [string]$manifest.selected_policy.candidate_id -ceq "BW5R-B" -and
    [string]$manifest.selected_policy.policy_id -ceq $frozenSelectedPolicyId -and
    [string]$manifest.selected_policy.policy_digest -ceq
        $frozenSelectedPolicyDigest -and
    $bw5vHash -ceq [string]$bw5v.sha256 -and
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
    ($manifestSeeds -join ",") -ceq "20001,20002,20003" -and
    ($manifestFrictionValues -join ",") -ceq "0.12,0.48,0.95,1.5" -and
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
    [bool]$manifest.claims_if_accepted.bw5c_cold_acceptance_authority -and
    [bool]$manifest.claims_if_accepted.walking_acceptance -and
    [bool]$manifest.claims_if_accepted.bounded_discrete_material_robustness -and
    [bool]$manifest.claims_if_accepted.material_robustness
)
if (-not $manifestContractPassed) {
    throw "BW5C validation manifest or prerequisite identity is invalid"
}

$bw5vEvidencePassed = (
    [string]$bw5vReport.schema_version -ceq
        "sporespore_balanced_wave_bw5v_validation_report_v1" -and
    [bool]$bw5vReport.accepted -and
    [string]$bw5vReport.result_status -ceq "validation_passed" -and
    [bool]$bw5vReport.development_data_only -and
    [bool]$bw5vReport.validation_data_only -and
    -not [bool]$bw5vReport.cold_acceptance -and
    [int]$bw5vReport.receipt.passed_gate_count -eq 22 -and
    [int]$bw5vReport.receipt.failed_gate_count -eq 0 -and
    [int]$bw5vReport.receipt.observed_world_count -eq 12
)
$characterizationEvidencePassed = (
    [string]$characterizationReport.schema_version -ceq
        "sporespore_balanced_wave_bw5c_material_characterization_report_v1" -and
    [bool]$characterizationReport.accepted -and
    [string]$characterizationReport.result_status -ceq "passed" -and
    [string]$characterizationReport.campaign -ceq "BW5C" -and
    [bool]$characterizationReport.cold_characterization -and
    -not [bool]$characterizationReport.development_data_only -and
    [bool]$characterizationReport.recovery.recovered_from_completed_engine_log -and
    -not [bool]$characterizationReport.recovery.physics_rerun -and
    [int]$characterizationReport.receipt.passed_gate_count -eq 23 -and
    [int]$characterizationReport.receipt.failed_gate_count -eq 0 -and
    [int]$characterizationReport.receipt.observed_world_count -eq 13
)
$publicationEvidencePassed = (
    [string]$publicationReport.schema_version -ceq
        "sporespore_godot_jolt_material_profile_report_v1" -and
    [bool]$publicationReport.accepted -and
    [string]$publicationReport.result_status -ceq "passed" -and
    [int]$publicationReport.receipt.passed_gate_count -eq 36 -and
    [int]$publicationReport.receipt.failed_gate_count -eq 0 -and
    [int]$publicationReport.receipt.observed_world_count -eq 0 -and
    [int]$publicationReport.receipt.observed_profile_count -eq 25 -and
    [int]$publicationReport.receipt.bw5c_profile_count -eq 4
)
if (-not (
    $bw5vEvidencePassed -and
    $characterizationEvidencePassed -and
    $publicationEvidencePassed
)) {
    throw "One or more pinned BW5C prerequisite reports failed acceptance checks"
}

$sourceCommit = ""
$outputPath = ""
$outputDirectory = ""
if (-not $PreflightOnly) {
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the BW5C source worktree"
    }
    if ($sourceStatus.Count -ne 0) {
        throw "Refusing to open BW5C validation worlds from dirty source"
    }
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($sourceCommit) -or
        $sourceCommit -cne $originMain
    ) {
        throw "Refusing BW5C validation because HEAD does not match origin/main"
    }
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained BW5C validation report filename must be exactly report.json"
    }
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to overwrite an existing BW5C validation report: $outputPath"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        $existing = @(Get-ChildItem -LiteralPath $outputDirectory -Force)
        if ($existing.Count -ne 0) {
            throw "Refusing a nonempty retained BW5C validation directory: $outputDirectory"
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
; Isolated SporeSpore balanced-wave BW5C cold material acceptance.

config_version=5

[application]

config/name="sporespore-balanced-wave-bw5c-validation"
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
            "Selected BW5R-B no-world contract failed before BW5C opened. " +
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
    $receiptPrefix = "BALANCED_WAVE_BW5C_VALIDATION_PREFLIGHT_RECEIPT "
    $expectedSchema =
        "sporespore_balanced_wave_bw5c_validation_preflight_receipt_v1"
} else {
    $receiptPrefix = "BALANCED_WAVE_BW5C_VALIDATION_RECEIPT "
    $expectedSchema = "sporespore_balanced_wave_bw5c_validation_receipt_v1"
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
        failure_code = "BW5C_VALIDATION_RECEIPT_CARDINALITY_INVALID"
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
            "opened_bw5c_development_replay"
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
        [bool]$receipt.validation_manifest.bw5v_validation_report_hash_exact -and
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
            "BW5C validation zero-world preflight failed. Godot exit code: " +
            "$godotExitCode. Transcript: $validationTranscriptPath"
        )
    }
    Write-Host "BW5C validation zero-world preflight passed."
    Write-Host "Transcript: $validationTranscriptPath"
    exit 0
}

$expectedPartition = if ($openedDevelopmentReplay) {
    "opened_bw5c_development_replay"
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
    [bool]$receipt.bw5c_cold_acceptance_authority -eq (-not $openedDevelopmentReplay) -and
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
    throw "BW5C source changed or became dirty while validation ran"
}

[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$retainedContractTranscript = Join-Path $outputDirectory "contract-transcript.log"
$retainedValidationTranscript = Join-Path $outputDirectory "validation-transcript.log"
$retainedEngineLog = Join-Path $outputDirectory "engine.log"
[System.IO.File]::Copy($contractTranscriptPath, $retainedContractTranscript, $false)
[System.IO.File]::Copy($validationTranscriptPath, $retainedValidationTranscript, $false)
[System.IO.File]::Copy($engineLogPath, $retainedEngineLog, $false)

$activePreregistrationPath = "sdk/balanced_wave_bw5c_preregistration.json"
$sourcePaths = [ordered]@{
    bootstrap = "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"
    friction_bootstrap = (
        "docs/SDK_GODOT_JOLT_FRICTION_MATERIAL_ROBUSTNESS_BOOTSTRAP.md"
    )
    preregistration = $activePreregistrationPath
    validation_manifest = "sdk/balanced_wave_bw5c_validation_manifest.json"
    selected_policy = "sdk/balanced_wave_selected_policy.json"
    runner = "sdk/run_balanced_wave_bw5c_validation.ps1"
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
    schema_version = "sporespore_balanced_wave_bw5c_validation_report_v1"
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
        bw5v_validation = [ordered]@{
            path = $bw5vPath
            sha256 = $bw5vHash
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
Write-Host "Retained BW5C validation report: $outputPath"

if (-not $validationAccepted) {
    throw (
        "The frozen BW5C matrix result was rejected. Godot exit code: " +
        "$godotExitCode. Report: $outputPath"
    )
}

Write-Host (
    "BALANCED_WAVE_BW5C_VALIDATION=true " +
    "GATES=$([int]$receipt.passed_gate_count)/28 " +
    "WORLDS=$([int]$receipt.observed_world_count) " +
    "TREATMENTS=$([int]$receipt.observed_treatment_pass_count)/12 " +
    "CONTROLS=$([int]$receipt.observed_control_pass_count)/4 " +
    "PAIRS=$([int]$receipt.observed_pair_pass_count)/4 " +
    "ZERO=$([int]$receipt.observed_zero_friction_safety_pass_count)/1"
)
