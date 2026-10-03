#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly,
    [ValidateSet(
        "QSDK-R05",
        "QSDK-R05B",
        "BW14V-MORPHOLOGY-DEVELOPMENT",
        "BW15F-MORPHOLOGY-DEVELOPMENT"
    )]
    [string]$CampaignId = "QSDK-R05",
    [string]$Candidate = "",
    [ValidateRange(30, 600)]
    [int]$CellTimeoutSeconds = 240
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$fullGateTest = "tests/test_sdk_full_integrity_gate_satisfiability.gd"
$experimentResultIntegrityPath = Join-Path $sdkRoot (
    "experiment_result_integrity.ps1"
)
$campaignConfig = if (
    $CampaignId -ceq "BW14V-MORPHOLOGY-DEVELOPMENT"
) {
    if ($Candidate -cnotin @("BW14V-A", "BW14V-B")) {
        throw "BW14V requires -Candidate BW14V-A or BW14V-B"
    }
    $bw14vTreatment = $Candidate -ceq "BW14V-B"
    [ordered]@{
        id = "BW14V-MORPHOLOGY-DEVELOPMENT"
        gate_id = "BW14V"
        slug = "bw14v_morphology_development_$($Candidate.ToLowerInvariant())"
        preregistration_file = (
            "balanced_wave_bw14v_morphology_development_preregistration.json"
        )
        preregistration_schema = (
            "sporespore_balanced_wave_bw14v_morphology_development_preregistration_v1"
        )
        preregistration_status = "frozen_before_first_bw14v_physics_world"
        preregistration_sha256 = (
            "5030239a59fa477f0dab6cf749572edf7c9040569fff93d42d40c18da3dedd33"
        )
        test = "tests/test_sdk_balanced_wave_bw14v_morphology_development.gd"
        indices_csv = "181,182,183,184,185,186,187,188,189,190,191,192"
        seeds_csv = "21601,21602,21603"
        entrypoint_prefix = "BW14V_DEVELOPMENT_ENTRYPOINT_PREFLIGHT "
        entrypoint_schema = (
            "sporespore_bw14v_development_entrypoint_preflight_v1"
        )
        cell_prefix = "BW14V_DEVELOPMENT_CELL "
        runner_preflight_schema = (
            "sporespore_bw14v_runner_preflight_v1"
        )
        preflight_bundle_prefix = "BW14V_PREFLIGHT_BUNDLE "
        preflight_bundle_schema = "sporespore_bw14v_preflight_bundle_v1"
        report_schema = (
            "sporespore_bw14v_morphology_development_report_v1"
        )
        pass_field = "development_complete"
        entrypoint_report_field = "bw14v_entrypoint_preflight"
        wrapper_source = (
            "sdk/run_balanced_wave_bw14v_morphology_development.ps1"
        )
        candidate_id = $Candidate
        policy_id = $(if ($bw14vTreatment) {
            "sporespore_balanced_wave_bw14v_b_v1"
        } else {
            "sporespore_balanced_wave_bw5r_b_v1"
        })
        policy_digest = $(if ($bw14vTreatment) {
            "sha256:3404217d991b8eaf6b9c0d74e84768ffd36264b6d664a7c02fc14f57b176713b"
        } else {
            "sha256:288012fe4af5e93f1ecd2f007821a03e95c316c27cda196317617b8130017292"
        })
        candidate_environment_variable = "SPORESPORE_BW14V_CANDIDATE"
        walking_required = $false
        campaign_role = (
            "paired_outcome_exposed_base_controller_hypothesis_selection"
        )
        include_selected_policy_source = $false
        paired_candidate_contract = $true
        mechanism_authority_test = (
            "tests/test_sdk_balanced_wave_bw14v_authority_contract.gd"
        )
        mechanism_authority_summary = (
            "SDK BW14V authority summary: 11 passed, 0 failed"
        )
        selector_regression_test = "tests/test_bw14v_selector.ps1"
        paired_source_files = @(
            "tests/test_sdk_balanced_wave_bw14v_authority_contract.gd",
            "sdk/compile_balanced_wave_bw14v_selection.ps1",
            "tests/test_bw14v_selector.ps1",
            "tests/test_bw13p_r3_closure.ps1",
            "sdk/balanced_wave_bw13p_r3_closure_manifest.json"
        )
    }
} elseif ($CampaignId -ceq "BW15F-MORPHOLOGY-DEVELOPMENT") {
    $bw15fPolicyIds = [ordered]@{
        "BW15F-A" = "sporespore_balanced_wave_bw5r_b_v1"
        "BW15F-B" = "sporespore_balanced_wave_bw15f_b_v1"
        "BW15F-C" = "sporespore_balanced_wave_bw15f_c_v1"
        "BW15F-D" = "sporespore_balanced_wave_bw15f_d_v1"
    }
    $bw15fPolicyDigests = [ordered]@{
        "BW15F-A" = (
            "sha256:ac9fe7e62493ed2d21d3c95f0eb51cde45d7a53e7e22365ce422c68ad031a423"
        )
        "BW15F-B" = (
            "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
        )
        "BW15F-C" = (
            "sha256:7ba445b2756a8fc43e245334f3215fc77dd5c68142dd0be33a3dfeaf2c75433f"
        )
        "BW15F-D" = (
            "sha256:f26320a4019a86f1ec700f297af12156a61ea41a026d489b69d1b649fafdcf60"
        )
    }
    if (-not $bw15fPolicyIds.Contains($Candidate)) {
        throw "BW15F requires -Candidate BW15F-A, BW15F-B, BW15F-C, or BW15F-D"
    }
    [ordered]@{
        id = "BW15F-MORPHOLOGY-DEVELOPMENT"
        gate_id = "BW15F"
        slug = "bw15f_morphology_development_$($Candidate.ToLowerInvariant())"
        preregistration_file = (
            "balanced_wave_bw15f_morphology_development_preregistration.json"
        )
        preregistration_schema = (
            "sporespore_balanced_wave_bw15f_morphology_development_preregistration_v1"
        )
        preregistration_status = "frozen_before_first_bw15f_physics_world"
        preregistration_sha256 = (
            "722a65c741d3bd41c5374225c5d7b0d611ce87cf5ac5ede1d3eda9142c362e29"
        )
        test = "tests/test_sdk_balanced_wave_bw15f_morphology_development.gd"
        indices_csv = "181,182,183,184,185,186,187,188,189,190,191,192"
        seeds_csv = "21601,21602,21603"
        entrypoint_prefix = "BW15F_DEVELOPMENT_ENTRYPOINT_PREFLIGHT "
        entrypoint_schema = (
            "sporespore_bw15f_development_entrypoint_preflight_v1"
        )
        cell_prefix = "BW15F_DEVELOPMENT_CELL "
        runner_preflight_schema = "sporespore_bw15f_runner_preflight_v1"
        preflight_bundle_prefix = "BW15F_PREFLIGHT_BUNDLE "
        preflight_bundle_schema = "sporespore_bw15f_preflight_bundle_v1"
        report_schema = (
            "sporespore_bw15f_morphology_development_report_v1"
        )
        pass_field = "development_complete"
        entrypoint_report_field = "bw15f_entrypoint_preflight"
        wrapper_source = (
            "sdk/run_balanced_wave_bw15f_morphology_development.ps1"
        )
        candidate_id = $Candidate
        policy_id = [string]$bw15fPolicyIds[$Candidate]
        policy_digest = [string]$bw15fPolicyDigests[$Candidate]
        candidate_environment_variable = "SPORESPORE_BW15F_CANDIDATE"
        walking_required = $false
        campaign_role = (
            "paired_outcome_exposed_global_sign_gain_hypothesis_selection"
        )
        include_selected_policy_source = $false
        paired_candidate_contract = $true
        mechanism_authority_test = (
            "tests/test_sdk_balanced_wave_bw15f_authority_contract.gd"
        )
        mechanism_authority_summary = (
            "SDK BW15F authority summary: 8 passed, 0 failed"
        )
        selector_regression_test = "tests/test_bw15f_selector.ps1"
        paired_source_files = @(
            "tests/test_sdk_balanced_wave_bw15f_authority_contract.gd",
            "sdk/compile_balanced_wave_bw15f_selection.ps1",
            "tests/test_bw15f_selector.ps1",
            "tests/test_bw14v_closure.ps1",
            "sdk/balanced_wave_bw14v_closure_manifest.json",
            "tests/test_bw14v_posthoc_diagnostic.ps1",
            "sdk/balanced_wave_bw14v_posthoc_diagnostic.json"
        )
    }
} elseif ($CampaignId -ceq "QSDK-R05B") {
    [ordered]@{
        id = "QSDK-R05B"
        gate_id = "QSDK-R05B"
        slug = "qsdk_r05b"
        preregistration_file = (
            "qsdk_r05b_independent_morphology_preregistration.json"
        )
        preregistration_schema = (
            "sporespore_qsdk_r05b_independent_morphology_preregistration_v1"
        )
        preregistration_status = (
            "frozen_before_first_qsdk_r05b_physics_world"
        )
        test = "tests/test_sdk_qsdk_r05b_independent_morphology.gd"
        indices_csv = "181,182,183,184,185,186,187,188,189,190,191,192"
        seeds_csv = "21601,21602,21603"
        entrypoint_prefix = "QSDK_R05B_ENTRYPOINT_PREFLIGHT "
        entrypoint_schema = (
            "sporespore_qsdk_r05b_entrypoint_preflight_receipt_v1"
        )
        cell_prefix = "QSDK_R05B_CELL "
        runner_preflight_schema = (
            "sporespore_qsdk_r05b_runner_preflight_v1"
        )
        preflight_bundle_prefix = "QSDK_R05B_PREFLIGHT_BUNDLE "
        preflight_bundle_schema = (
            "sporespore_qsdk_r05b_preflight_bundle_v1"
        )
        report_schema = (
            "sporespore_qsdk_r05b_independent_morphology_report_v1"
        )
        pass_field = "r05b_passed"
        entrypoint_report_field = "r05b_entrypoint_preflight"
        wrapper_source = "sdk/run_qsdk_r05b_independent_morphology.ps1"
        candidate_id = "BW5R-B"
        policy_id = "sporespore_balanced_wave_bw5r_b_v1"
        policy_digest = (
            "sha256:" +
            "9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
        )
        candidate_environment_variable = ""
        walking_required = $true
        campaign_role = "independent_validation"
        include_selected_policy_source = $true
        paired_candidate_contract = $false
    }
} else {
    if (-not [string]::IsNullOrWhiteSpace($Candidate)) {
        throw "-Candidate is only valid for BW14V or BW15F"
    }
    [ordered]@{
        id = "QSDK-R05"
        gate_id = "QSDK-R05"
        slug = "qsdk_r05"
        preregistration_file = (
            "qsdk_r05_independent_morphology_preregistration.json"
        )
        preregistration_schema = (
            "sporespore_qsdk_r05_independent_morphology_preregistration_v1"
        )
        preregistration_status = (
            "frozen_before_first_qsdk_r05_physics_world"
        )
        test = "tests/test_sdk_qsdk_r05_independent_morphology.gd"
        indices_csv = "169,170,171,172,173,174,175,176,177,178,179,180"
        seeds_csv = "21501,21502,21503"
        entrypoint_prefix = "QSDK_R05_ENTRYPOINT_PREFLIGHT "
        entrypoint_schema = (
            "sporespore_qsdk_r05_entrypoint_preflight_receipt_v1"
        )
        cell_prefix = "QSDK_R05_CELL "
        runner_preflight_schema = (
            "sporespore_qsdk_r05_runner_preflight_v1"
        )
        preflight_bundle_prefix = "QSDK_R05_PREFLIGHT_BUNDLE "
        preflight_bundle_schema = (
            "sporespore_qsdk_r05_preflight_bundle_v1"
        )
        report_schema = (
            "sporespore_qsdk_r05_independent_morphology_report_v1"
        )
        pass_field = "r05_passed"
        entrypoint_report_field = "r05_entrypoint_preflight"
        wrapper_source = ""
        candidate_id = "BW5R-B"
        policy_id = "sporespore_balanced_wave_bw5r_b_v1"
        policy_digest = (
            "sha256:" +
            "9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
        )
        candidate_environment_variable = ""
        walking_required = $true
        campaign_role = "independent_validation"
        include_selected_policy_source = $true
        paired_candidate_contract = $false
    }
}
$expectedPolicyId = [string]$campaignConfig.policy_id
$expectedPolicyDigest = [string]$campaignConfig.policy_digest
$preregistrationPath = Join-Path $sdkRoot (
    [string]$campaignConfig.preregistration_file
)
$campaignTest = [string]$campaignConfig.test

if (
    -not (
        Test-Path -LiteralPath $experimentResultIntegrityPath -PathType Leaf
    )
) {
    throw "The fail-closed experiment result aggregator is missing"
}
. $experimentResultIntegrityPath

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-PrefixedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:$(Get-Sha256 -Path $Path)"
}

function Get-ReceiptFromOutput {
    param(
        [Parameter(Mandatory)]
        [string]$OutputText,
        [Parameter(Mandatory)]
        [string]$Prefix
    )
    $lines = @(
        $OutputText -split "\r?\n" |
            Where-Object { $_.StartsWith($Prefix) }
    )
    if ($lines.Count -ne 1) {
        throw "Expected one '$Prefix' receipt, found $($lines.Count)"
    }
    return (
        $lines[0].Substring($Prefix.Length) |
            ConvertFrom-Json -AsHashtable
    )
}

function Invoke-GodotCaptured {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [Parameter(Mandatory)]
        [string]$WorkerRoot,
        [Parameter(Mandatory)]
        [int]$TimeoutSeconds
    )
    $appData = Join-Path $WorkerRoot "appdata"
    $localAppData = Join-Path $WorkerRoot "localappdata"
    [void][System.IO.Directory]::CreateDirectory($appData)
    [void][System.IO.Directory]::CreateDirectory($localAppData)
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $godotPath
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    if (-not [string]::IsNullOrWhiteSpace(
        [string]$campaignConfig.candidate_environment_variable
    )) {
        $start.Environment[
            [string]$campaignConfig.candidate_environment_variable
        ] = [string]$campaignConfig.candidate_id
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    if (-not $process.Start()) {
        throw "Failed to start Godot"
    }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    $killedTree = $false
    if ($timedOut) {
        try {
            $process.Kill($true)
            $killedTree = $true
        } catch {
            $killedTree = $false
        }
        [void]$process.WaitForExit(10000)
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
    $durationSeconds = (
        [DateTime]::UtcNow - $startedUtc
    ).TotalSeconds
    $process.Dispose()
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        killed_process_tree = $killedTree
        duration_seconds = $durationSeconds
        stdout = $stdout
        stderr = $stderr
    }
}

function New-R05CellResult {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Cell,
        [Parameter(Mandatory)]
        [string]$MorphologyId,
        [Parameter(Mandatory)]
        [int]$Seed,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Execution,
        [AllowNull()]
        [object]$Receipt,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ReceiptError,
        [Parameter(Mandatory)]
        [string]$TranscriptPath,
        [Parameter(Mandatory)]
        [string]$StderrPath,
        [Parameter(Mandatory)]
        [string]$EngineLogPath
    )
    $parsed = $null -ne $Receipt
    $harnessPassed = (
        $parsed -and
        [int]$Execution.exit_code -eq 0 -and
        -not [bool]$Execution.timed_out -and
        [bool]$Receipt.harness_passed -and
        [int]$Receipt.assertions_failed -eq 0
    )
    $engineLogSha256 = ""
    if (Test-Path -LiteralPath $EngineLogPath) {
        $engineLogSha256 = Get-PrefixedSha256 $EngineLogPath
    }
    return [ordered]@{
        morphology_id = $MorphologyId
        generator_index = [int]$Cell.generator_index
        campaign_seed = $Seed
        process_exit_code = [int]$Execution.exit_code
        timed_out = [bool]$Execution.timed_out
        killed_process_tree = [bool]$Execution.killed_process_tree
        duration_seconds = [double]$Execution.duration_seconds
        receipt_parsed = $parsed
        receipt_parse_error = $ReceiptError
        harness_passed = $harnessPassed
        walking_observed = (
            $parsed -and [bool]$Receipt.walking_observed
        )
        common_execution_integrity = (
            $parsed -and [bool]$Receipt.common_execution_integrity
        )
        mechanism_gate_passed = $(if (
            $parsed -and $Receipt.Contains("mechanism_gate_passed")
        ) {
            [bool]$Receipt.mechanism_gate_passed
        } else {
            $parsed -and [bool]$Receipt.common_execution_integrity
        })
        combined_application_gate_passed = $(if (
            $parsed -and $Receipt.Contains("combined_application_gate_passed")
        ) {
            [bool]$Receipt.combined_application_gate_passed
        } else {
            $parsed -and [bool]$Receipt.common_execution_integrity
        })
        failed_production_walking_gate_count = $(if (
            $parsed -and
            $Receipt.Contains(
                "failed_production_walking_gate_count"
            )
        ) {
            [int]$Receipt.failed_production_walking_gate_count
        } elseif ($parsed -and [bool]$Receipt.walking_observed) {
            0
        } else {
            1
        })
        release_timeout_count = $(if (
            $parsed -and $Receipt.Contains("release_timeout_count")
        ) {
            [int]$Receipt.release_timeout_count
        } else {
            0
        })
        normalized_absolute_task_frame_lateral_displacement = $(if (
            $parsed -and
            $Receipt.Contains(
                "normalized_absolute_task_frame_lateral_displacement"
            )
        ) {
            $Receipt.normalized_absolute_task_frame_lateral_displacement
        } else {
            0.0
        })
        cumulative_absolute_cross_track_error_m_s = $(if (
            $parsed -and
            $Receipt.Contains(
                "cumulative_absolute_cross_track_error_m_s"
            )
        ) {
            $Receipt.cumulative_absolute_cross_track_error_m_s
        } else {
            0.0
        })
        receipt = $Receipt
        transcript_path = $TranscriptPath
        transcript_sha256 = Get-PrefixedSha256 $TranscriptPath
        stderr_path = $StderrPath
        stderr_sha256 = Get-PrefixedSha256 $StderrPath
        engine_log_path = $EngineLogPath
        engine_log_sha256 = $engineLogSha256
    }
}

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $preregistrationPath -PathType Leaf)) {
    throw "$CampaignId preregistration not found: $preregistrationPath"
}
if (
    $campaignConfig.Contains("preregistration_sha256") -and
    (Get-Sha256 -Path $preregistrationPath) -cne
        [string]$campaignConfig.preregistration_sha256
) {
    throw "$CampaignId preregistration bytes do not match the frozen SHA-256"
}
if ($PreflightOnly -and -not [string]::IsNullOrWhiteSpace($Output)) {
    throw "Preflight-only mode cannot create a retained physics report"
}
if (-not $PreflightOnly -and [string]::IsNullOrWhiteSpace($Output)) {
    throw "The physical campaign requires a durable -Output report.json path"
}

$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)
$indices = @(
    $preregistration.morphology_generator.generator_indices |
        ForEach-Object { [int]$_ }
)
$cells = @($preregistration.morphology_generator.cells)
$seeds = @(
    $preregistration.repetitions.campaign_seeds |
        ForEach-Object { [int]$_ }
)
$candidateContractExact = $true
if ([bool]$campaignConfig.paired_candidate_contract) {
    $candidateDeclaration = @(
        $preregistration.candidates |
            Where-Object {
                [string]$_.candidate_id -ceq
                    [string]$campaignConfig.candidate_id
            }
    )
    $candidateContractExact = (
        $candidateDeclaration.Count -eq 1 -and
        [string]$candidateDeclaration[0].controller_policy_id -ceq
            $expectedPolicyId -and
        [string]$preregistration.candidate_policy_digests[
            [string]$campaignConfig.candidate_id
        ] -ceq $expectedPolicyDigest -and
        @($candidateDeclaration[0].branch_surfaces).Count -eq 0
    )
} else {
    $candidateContractExact = (
        [string]$preregistration.selected_candidate_id -ceq
            [string]$campaignConfig.candidate_id -and
        [string]$preregistration.selected_policy_id -ceq
            $expectedPolicyId -and
        [string]$preregistration.selected_policy_digest -ceq
            $expectedPolicyDigest
    )
}
$firstCompleteFinal = if (
    [bool]$campaignConfig.paired_candidate_contract
) {
    [bool]$preregistration.repetitions.first_complete_result_is_final_for_each_candidate_source_identity
} else {
    [bool]$preregistration.repetitions.first_complete_result_is_final_for_this_source_identity
}
$freezeParentCommit = if (
    [bool]$campaignConfig.paired_candidate_contract
) {
    [string]$preregistration.implementation_parent_commit
} else {
    [string]$preregistration.freeze_parent_commit
}
$contractExact = (
    [string]$preregistration.schema_version -ceq
        [string]$campaignConfig.preregistration_schema -and
    [string]$preregistration.status -ceq
        [string]$campaignConfig.preregistration_status -and
    [string]$preregistration.gate_id -ceq
        [string]$campaignConfig.gate_id -and
    [string]$preregistration.campaign_id -ceq
        [string]$campaignConfig.id -and
    $candidateContractExact -and
    ($indices -join ",") -ceq [string]$campaignConfig.indices_csv -and
    $cells.Count -eq 12 -and
    ($seeds -join ",") -ceq [string]$campaignConfig.seeds_csv -and
    [int]$preregistration.repetitions.expected_world_count -eq 36 -and
    -not [string]::IsNullOrWhiteSpace($freezeParentCommit) -and
    [string]$preregistration.material.profile_id -ceq
        "godot_jolt_bw5c_mu095_v1" -and
    [bool]$preregistration.repetitions.early_stop_for_outcome_forbidden -and
    $firstCompleteFinal -and
    -not [bool]$preregistration.claim_boundary.arbitrary_quadruped_coverage -and
    -not [bool]$preregistration.claim_boundary.continuous_full_volume_coverage -and
    -not [bool]$preregistration.claim_boundary.completed_engine_neutral_sdk -and
    -not [bool]$preregistration.claim_boundary.release_authorized
)
if (-not $contractExact) {
    throw "$CampaignId preregistration failed strict reconciliation"
}

$outputPath = ""
$outputDirectory = ""
$sourceCommit = ""
$originMain = ""
if (-not $PreflightOnly) {
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    if ($LASTEXITCODE -ne 0 -or $sourceStatus.Count -ne 0) {
        throw "Refusing to open $CampaignId worlds from dirty source"
    }
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($sourceCommit) -or
        $sourceCommit -cne $originMain
    ) {
        throw "Refusing $CampaignId because HEAD does not match origin/main"
    }
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained $CampaignId report filename must be exactly report.json"
    }
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to overwrite an existing $CampaignId report: $outputPath"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        $existing = @(Get-ChildItem -LiteralPath $outputDirectory -Force)
        if ($existing.Count -ne 0) {
            throw "Refusing a nonempty $CampaignId evidence directory: $outputDirectory"
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

& (Join-Path $repoRoot "tests\test_experiment_result_integrity_preflight.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "The exact all-zero and nonzero result-integrity preflight failed " +
        "before $CampaignId"
    )
}

$tempBase = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()
)
$tempRoot = Join-Path $tempBase (
    "sporespore_$([string]$campaignConfig.slug)_" +
        [Guid]::NewGuid().ToString("N")
)
$projectRoot = Join-Path $tempRoot "project"
[void][System.IO.Directory]::CreateDirectory($projectRoot)
foreach ($directory in @("scripts", "tests", "sdk")) {
    [void](New-Item `
        -ItemType Junction `
        -Path (Join-Path $projectRoot $directory) `
        -Target (Join-Path $repoRoot $directory))
}
$projectText = @"
; Isolated SporeSpore $CampaignId independent morphology campaign.

config_version=5

[application]

config/name="sporespore-$([string]$campaignConfig.slug)-independent-morphology"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
"@
Write-Utf8NoBom -Path (Join-Path $projectRoot "project.godot") -Text $projectText

try {
    # These two checks deliberately run before any durable evidence directory
    # is created and before any physical world can open.
    $fullPreflight = Invoke-GodotCaptured `
        -Arguments @(
            "--headless",
            "--path", $projectRoot,
            "--script", "res://$fullGateTest"
        ) `
        -WorkerRoot (Join-Path $tempRoot "preflight-full") `
        -TimeoutSeconds 300
    if ($fullPreflight.exit_code -ne 0 -or $fullPreflight.timed_out) {
        throw "The full synthetic integrity gate failed before $CampaignId"
    }
    $fullReceipt = Get-ReceiptFromOutput `
        -OutputText $fullPreflight.stdout `
        -Prefix "FULL_INTEGRITY_GATE_SATISFIABILITY "
    $runtimeBoundaryWitnesses = @(
        $fullReceipt.policy_runtime_boundary_witnesses
    )
    $runtimeBoundaryFailures = @(
        $runtimeBoundaryWitnesses |
            Where-Object {
                -not [bool]$_.ok -or
                [string]$_.schema_version -cne
                    "sporespore_declared_policy_runtime_boundary_preflight_v1" -or
                [int]$_.native_controller_command_count -ne 8 -or
                -not [bool]$_.native_controller_command_order_exact -or
                -not [bool]$_.execution_mode_plan_passed -or
                -not [bool]$_.gait_memory_nonnegative -or
                -not [bool]$_.native_next_memory_nonnegative -or
                [int]$_.actual_world_build_count -ne 0 -or
                [int]$_.scene_tree_insertion_count -ne 0 -or
                [bool]$_.physics_state_modified -or
                [bool]$_.locomotion_outcome_exposed -or
                [bool]$_.physical_acceptance_authority
            }
    )
    $runtimeBoundaryKeys = @(
        $runtimeBoundaryWitnesses |
            ForEach-Object {
                "{0}|{1}" -f @(
                    [string]$_.stability_policy_id,
                    [int]$_.requested_phase_offset_ticks
                )
            } |
            Sort-Object -Unique
    )
    $declaredSignedOffsetsExact = (
        (
            @(
                $fullReceipt.declared_signed_phase_offsets |
                    ForEach-Object { [int]$_ }
            ) -join ","
        ) -ceq "-3,-2"
    )
    $worstCaseRuntimeHorizon = $fullReceipt.worst_case_runtime_horizon_witness
    $worstCaseRuntimeHorizonExact = (
        [bool]$fullReceipt.worst_case_runtime_horizon_passed -and
        [bool]$worstCaseRuntimeHorizon.ok -and
        [string]$worstCaseRuntimeHorizon.schema_version -ceq
            "sporespore_declared_policy_runtime_horizon_preflight_v1" -and
        [int]$worstCaseRuntimeHorizon.declared_step_count -gt 0 -and
        [int]$worstCaseRuntimeHorizon.native_controller_step_count -eq
            [int]$worstCaseRuntimeHorizon.declared_step_count -and
        [int]$worstCaseRuntimeHorizon.native_controller_command_count -eq
            (8 * [int]$worstCaseRuntimeHorizon.declared_step_count) -and
        [int]$worstCaseRuntimeHorizon.portable_scheduled_plan_count -eq
            [int]$worstCaseRuntimeHorizon.declared_step_count -and
        [bool]$worstCaseRuntimeHorizon.execution_mode_plan_passed -and
        [int]$worstCaseRuntimeHorizon.actual_world_build_count -eq 0 -and
        [int]$worstCaseRuntimeHorizon.scene_tree_insertion_count -eq 0 -and
        -not [bool]$worstCaseRuntimeHorizon.physics_state_modified -and
        -not [bool]$worstCaseRuntimeHorizon.locomotion_outcome_exposed -and
        -not [bool]$worstCaseRuntimeHorizon.physical_acceptance_authority
    )
    $fullPreflightExact = (
        [bool]$fullReceipt.passed -and
        [string]$fullReceipt.schema_version -ceq
            "sporespore_full_integrity_gate_satisfiability_receipt_v5" -and
        [bool]$fullReceipt.exact_declared_policy_runtime_boundaries_called -and
        [bool]$fullReceipt.exact_worst_case_declared_policy_runtime_horizon_called -and
        [int]$fullReceipt.declared_policy_runtime_boundary_count -eq 8 -and
        [bool]$fullReceipt.declared_policy_runtime_boundaries_passed -and
        [bool]$fullReceipt.production_execution_mode_resolver_called -and
        [bool]$fullReceipt.perfect_zero_error_runtime_boundary_on_every_declared_policy -and
        [bool]$fullReceipt.perfect_zero_error_full_runtime_horizon_on_worst_signed_offset -and
        [bool]$fullReceipt.perfect_synthetic_full_integrity_gate_passed -and
        [bool]$fullReceipt.r1_misroute_detected_before_world -and
        $worstCaseRuntimeHorizonExact -and
        $declaredSignedOffsetsExact -and
        $runtimeBoundaryWitnesses.Count -eq 8 -and
        $runtimeBoundaryFailures.Count -eq 0 -and
        $runtimeBoundaryKeys.Count -eq 8 -and
        [bool]$fullReceipt.exact_pre_world_entrypoint_called -and
        [bool]$fullReceipt.exact_selected_policy_full_authority_start_called -and
        [bool]$fullReceipt.selected_policy_full_authority_start_passed -and
        [bool]$fullReceipt.real_portable_policy_semantics_called -and
        [bool]$fullReceipt.exact_post_physics_gate_called -and
        [bool]$fullReceipt.perfect_zero_error_mismatch_failure_and_violation_counts -and
        [bool]$fullReceipt.mechanism_activity_counts_derived_from_real_policy_receipts -and
        [bool]$fullReceipt.bw12e_exact_zero_control_mismatch_detected -and
        [bool]$fullReceipt.missing_policy_semantic_witness_rejected -and
        [int]$fullReceipt.actual_world_build_count -eq 0 -and
        [int]$fullReceipt.scene_tree_insertion_count -eq 0 -and
        -not [bool]$fullReceipt.physics_state_modified -and
        -not [bool]$fullReceipt.locomotion_outcome_exposed -and
        -not [bool]$fullReceipt.physical_acceptance_authority
    )
    if (-not $fullPreflightExact) {
        throw "The full synthetic integrity receipt failed strict reconciliation"
    }

    $candidateMechanismPreflightExact = $true
    $candidateMechanismPreflight = $null
    if ([bool]$campaignConfig.paired_candidate_contract) {
        $candidateMechanismPreflight = Invoke-GodotCaptured `
            -Arguments @(
                "--headless",
                "--path", $projectRoot,
                "--script",
                "res://$([string]$campaignConfig.mechanism_authority_test)"
            ) `
            -WorkerRoot (Join-Path $tempRoot "preflight-mechanism") `
            -TimeoutSeconds 120
        $candidateMechanismPreflightExact = (
            [int]$candidateMechanismPreflight.exit_code -eq 0 -and
            -not [bool]$candidateMechanismPreflight.timed_out -and
            [string]$candidateMechanismPreflight.stdout -match
                [regex]::Escape(
                    [string]$campaignConfig.mechanism_authority_summary
                )
        )
        if (-not $candidateMechanismPreflightExact) {
            throw (
                "The $CampaignId zero-world mechanism authority contract failed"
            )
        }
    }

    $candidateSelectorPreflightExact = $true
    if ([bool]$campaignConfig.paired_candidate_contract) {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File (
                Join-Path $repoRoot (
                    [string]$campaignConfig.selector_regression_test
                )
            )
        $candidateSelectorPreflightExact = $LASTEXITCODE -eq 0
        if (-not $candidateSelectorPreflightExact) {
            throw (
                "The $CampaignId synthetic selector regression failed before world"
            )
        }
    }

    $entrypointPreflight = Invoke-GodotCaptured `
        -Arguments @(
            "--headless",
            "--path", $projectRoot,
            "--script", "res://$campaignTest",
            "--", "preflight"
        ) `
        -WorkerRoot (Join-Path $tempRoot "preflight-campaign") `
        -TimeoutSeconds 120
    if (
        $entrypointPreflight.exit_code -ne 0 -or
        $entrypointPreflight.timed_out
    ) {
        throw "The $CampaignId 36-cell entrypoint preflight failed"
    }
    $entrypointReceipt = Get-ReceiptFromOutput `
        -OutputText $entrypointPreflight.stdout `
        -Prefix ([string]$campaignConfig.entrypoint_prefix)
    $entrypointPreflightExact = (
        [bool]$entrypointReceipt.ok -and
        [string]$entrypointReceipt.schema_version -ceq
            [string]$campaignConfig.entrypoint_schema -and
        [string]$entrypointReceipt.campaign_id -ceq $CampaignId -and
        [string]$entrypointReceipt.selected_policy_id -ceq
            $expectedPolicyId -and
        [int]$entrypointReceipt.cell_count -eq 36 -and
        [int]$entrypointReceipt.actual_world_build_count -eq 0 -and
        [int]$entrypointReceipt.scene_tree_insertion_count -eq 0 -and
        -not [bool]$entrypointReceipt.physics_state_modified -and
        [int]$entrypointReceipt.exact_selected_policy_full_authority_start_count -eq 36 -and
        [bool]$entrypointReceipt.selected_policy_full_authority_start_passed -and
        [int]$entrypointReceipt.exact_declared_policy_runtime_boundary_count -eq 36 -and
        [bool]$entrypointReceipt.declared_policy_runtime_boundary_preflight_passed -and
        -not [bool]$entrypointReceipt.locomotion_outcome_exposed -and
        -not [bool]$entrypointReceipt.physical_acceptance_authority
    )
    if (-not $entrypointPreflightExact) {
        throw "The $CampaignId entrypoint receipt failed strict reconciliation"
    }

    # Resolve and hash every source that the final report will retain before
    # any world. A missing wrapper, campaign specialization, or preregistration
    # is therefore a launch failure, not an end-of-campaign surprise.
    $sourceFiles = [System.Collections.Generic.List[string]]::new()
    $baseSourceFiles = @(
        "sdk/$([string]$campaignConfig.preregistration_file)",
        "sdk/run_qsdk_r05_independent_morphology.ps1",
        "sdk/experiment_result_integrity.ps1",
        "tests/test_sdk_qsdk_r05_independent_morphology.gd",
        "tests/test_experiment_result_integrity_preflight.ps1",
        "tests/test_sdk_full_integrity_gate_satisfiability.gd",
        "scripts/lab/gait/physical_quadruped_proportion_spec.gd",
        "scripts/lab/gait/physical_wave_gait_quadruped.gd",
        "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
    )
    if ([bool]$campaignConfig.include_selected_policy_source) {
        $baseSourceFiles += "sdk/balanced_wave_selected_policy.json"
    }
    if ([bool]$campaignConfig.paired_candidate_contract) {
        $baseSourceFiles += @($campaignConfig.paired_source_files)
        $baseSourceFiles += @(
            "sdk/Cargo.toml",
            "sdk/Cargo.lock",
            "sdk/core/Cargo.toml",
            "sdk/core/src/controller.rs",
            "sdk/core/src/lib.rs",
            "sdk/core/src/protocol.rs",
            "sdk/core/src/runtime.rs",
            "sdk/adapters/godot/Cargo.toml",
            "sdk/adapters/godot/src/lib.rs",
            "docs/research/LOCOMOTION_RESEARCH_SOURCES.md",
            "DReCon.pdf",
            "2604.08780v1.pdf",
            "2507.22653v2.pdf"
        )
    }
    foreach ($relativePath in $baseSourceFiles) {
        $sourceFiles.Add($relativePath)
    }
    if (
        [string]$campaignConfig.test -cne
            "tests/test_sdk_qsdk_r05_independent_morphology.gd"
    ) {
        $sourceFiles.Add([string]$campaignConfig.test)
    }
    if (-not [string]::IsNullOrWhiteSpace(
        [string]$campaignConfig.wrapper_source
    )) {
        $sourceFiles.Add([string]$campaignConfig.wrapper_source)
    }
    $sourceFileReceipts = @(
        foreach ($relativePath in $sourceFiles) {
            $absolutePath = Join-Path $repoRoot $relativePath
            if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
                throw "$CampaignId source file not found: $relativePath"
            }
            [ordered]@{
                path = $relativePath
                sha256 = Get-PrefixedSha256 $absolutePath
            }
        }
    )

    # Exercise the entire retained 36-cell aggregate/report path with perfect
    # synthetic input before the first physical world. This is deliberately
    # separate from the Godot policy-semantic gate: it catches launcher,
    # dynamic-field, source-inventory, and report defects that would otherwise
    # appear only after an expensive complete campaign.
    $runnerProbeRoot = Join-Path $tempRoot "preflight-runner-report"
    [void][System.IO.Directory]::CreateDirectory($runnerProbeRoot)
    $runnerProbeTranscript = Join-Path $runnerProbeRoot "transcript.log"
    $runnerProbeStderr = Join-Path $runnerProbeRoot "stderr.log"
    $runnerProbeMissingEngineLog = Join-Path $runnerProbeRoot "engine.log"
    $runnerProbeReport = Join-Path $runnerProbeRoot "report.json"
    Write-Utf8NoBom -Path $runnerProbeTranscript -Text "synthetic-perfect"
    Write-Utf8NoBom -Path $runnerProbeStderr -Text ""
    $runnerProbeExecution = [ordered]@{
        exit_code = 0
        timed_out = $false
        killed_process_tree = $false
        duration_seconds = 0.0
    }
    $runnerProbeReceipt = [ordered]@{
        harness_passed = $true
        assertions_failed = 0
        walking_observed = $true
        common_execution_integrity = $true
    }
    $runnerProbeResults = [System.Collections.Generic.List[object]]::new()
    foreach ($cell in $cells) {
        foreach ($seed in $seeds) {
            $runnerProbeResults.Add(
                (
                    New-R05CellResult `
                        -Cell $cell `
                        -MorphologyId ([string]$cell.morphology_id) `
                        -Seed ([int]$seed) `
                        -Execution $runnerProbeExecution `
                        -Receipt $runnerProbeReceipt `
                        -ReceiptError "" `
                        -TranscriptPath $runnerProbeTranscript `
                        -StderrPath $runnerProbeStderr `
                        -EngineLogPath $runnerProbeMissingEngineLog
                )
            )
        }
    }
    $syntheticMetrics = Measure-SporeExperimentResults `
        -Results @($runnerProbeResults) `
        -ExpectedCount 36
    $syntheticPerfectExact = (
        [bool]$syntheticMetrics.integrity_and_mechanism_complete -and
        [int]$syntheticMetrics.observed_world_count -eq 36 -and
        [int]$syntheticMetrics.complete_receipt_count -eq 36 -and
        [int]$syntheticMetrics.harness_pass_count -eq 36 -and
        [int]$syntheticMetrics.integrity_pass_count -eq 36 -and
        [int]$syntheticMetrics.mechanism_pass_count -eq 36 -and
        [int]$syntheticMetrics.combined_application_pass_count -eq 36 -and
        [int]$syntheticMetrics.walking_conjunction_pass_count -eq 36 -and
        [int]$syntheticMetrics.aggregate_failed_production_walking_gate_count -eq 0 -and
        [int]$syntheticMetrics.aggregate_release_timeout_count -eq 0 -and
        [double]$syntheticMetrics.maximum_normalized_absolute_task_frame_lateral_displacement -eq 0.0 -and
        [double]$syntheticMetrics.aggregate_normalized_absolute_task_frame_lateral_displacement -eq 0.0 -and
        [double]$syntheticMetrics.aggregate_cumulative_absolute_cross_track_error_m_s -eq 0.0
    )
    if (-not $syntheticPerfectExact) {
        throw (
            "The exact production aggregate cannot accept a perfect " +
            "synthetic $CampaignId result"
        )
    }
    $canaryResults = @(
        foreach ($probeResult in $runnerProbeResults) {
            (
                $probeResult |
                    ConvertTo-Json -Depth 40 |
                    ConvertFrom-Json -AsHashtable
            )
        }
    )
    $canaryResults[6]["failed_production_walking_gate_count"] = 3
    $canaryResults[6]["release_timeout_count"] = 2
    $canaryResults[6][
        "normalized_absolute_task_frame_lateral_displacement"
    ] = 1.25
    $canaryResults[6]["cumulative_absolute_cross_track_error_m_s"] = 0.75
    $canaryResults[19][
        "normalized_absolute_task_frame_lateral_displacement"
    ] = 0.50
    $canaryResults[19]["cumulative_absolute_cross_track_error_m_s"] = 0.25
    $canaryResults[35]["walking_observed"] = $false
    $canaryMetrics = Measure-SporeExperimentResults `
        -Results $canaryResults `
        -ExpectedCount 36
    $nonzeroCanaryExact = (
        [bool]$canaryMetrics.integrity_and_mechanism_complete -and
        [int]$canaryMetrics.walking_conjunction_pass_count -eq 35 -and
        [int]$canaryMetrics.walking_conjunction_failure_count -eq 1 -and
        [int]$canaryMetrics.aggregate_failed_production_walking_gate_count -eq 3 -and
        [int]$canaryMetrics.aggregate_release_timeout_count -eq 2 -and
        [double]$canaryMetrics.maximum_normalized_absolute_task_frame_lateral_displacement -eq 1.25 -and
        [double]$canaryMetrics.aggregate_normalized_absolute_task_frame_lateral_displacement -eq 1.75 -and
        [double]$canaryMetrics.aggregate_cumulative_absolute_cross_track_error_m_s -eq 1.0
    )
    if (-not $nonzeroCanaryExact) {
        throw "$CampaignId nonzero ordered-dictionary aggregation canary failed"
    }
    $runnerProbeDocument = [ordered]@{
        schema_version = [string]$campaignConfig.report_schema
        synthetic_preflight_schema = (
            [string]$campaignConfig.runner_preflight_schema
        )
        perfect_zero_error_input = $true
        source = [ordered]@{
            commit = "synthetic-zero-world"
            remote = "origin/main"
            clean = $true
            matches_origin_main = $true
            source_files = $sourceFileReceipts
        }
        campaign_id = $CampaignId
        gate_id = [string]$campaignConfig.gate_id
        campaign_role = [string]$campaignConfig.campaign_role
        selected_candidate_id = [string]$campaignConfig.candidate_id
        selected_policy_id = $expectedPolicyId
        selected_policy_digest = $expectedPolicyDigest
        expected_world_count = 36
        observed_world_count = $runnerProbeResults.Count
        complete_receipt_count = $runnerProbeResults.Count
        harness_pass_count = $runnerProbeResults.Count
        walking_pass_count = $runnerProbeResults.Count
        integrity_pass_count = $runnerProbeResults.Count
        failure_count = 0
        metrics = $syntheticMetrics
        nonzero_canary_metrics = $canaryMetrics
        full_integrity_preflight = [ordered]@{
            passed = $fullPreflightExact
            actual_world_build_count = 0
        }
        candidate_selector_preflight = [ordered]@{
            required = [bool]$campaignConfig.paired_candidate_contract
            passed = $candidateSelectorPreflightExact
            actual_world_build_count = 0
            physical_acceptance_authority = $false
        }
        results = @($runnerProbeResults)
        same_selected_policy_independent_morphology_evidence = (
            -not [bool]$campaignConfig.paired_candidate_contract
        )
        development_data_only = (
            [bool]$campaignConfig.paired_candidate_contract
        )
        physical_world_build_count = 0
        physical_acceptance_authority = $false
    }
    $runnerProbeDocument[
        [string]$campaignConfig.entrypoint_report_field
    ] = [ordered]@{
        passed = $entrypointPreflightExact
        cell_count = 36
        actual_world_build_count = 0
    }
    $runnerProbeDocument[[string]$campaignConfig.pass_field] = $true
    Write-Utf8NoBom `
        -Path $runnerProbeReport `
        -Text (
            $runnerProbeDocument |
                ConvertTo-Json -Depth 20 |
                ForEach-Object { $_ + [Environment]::NewLine }
        )
    $runnerProbeRoundTrip = (
        Get-Content -Raw -LiteralPath $runnerProbeReport |
            ConvertFrom-Json -AsHashtable
    )
    $runnerPreflightExact = (
        [string]$runnerProbeRoundTrip.schema_version -ceq
            [string]$campaignConfig.report_schema -and
        [string]$runnerProbeRoundTrip.synthetic_preflight_schema -ceq
            [string]$campaignConfig.runner_preflight_schema -and
        [bool]$runnerProbeRoundTrip.perfect_zero_error_input -and
        [string]$runnerProbeRoundTrip.campaign_id -ceq $CampaignId -and
        [int]$runnerProbeRoundTrip.source.source_files.Count -eq
            $sourceFileReceipts.Count -and
        [int]$runnerProbeRoundTrip.expected_world_count -eq 36 -and
        [int]$runnerProbeRoundTrip.observed_world_count -eq 36 -and
        [int]$runnerProbeRoundTrip.complete_receipt_count -eq 36 -and
        [int]$runnerProbeRoundTrip.harness_pass_count -eq 36 -and
        [int]$runnerProbeRoundTrip.walking_pass_count -eq 36 -and
        [int]$runnerProbeRoundTrip.integrity_pass_count -eq 36 -and
        [int]$runnerProbeRoundTrip.failure_count -eq 0 -and
        [int]$runnerProbeRoundTrip.results.Count -eq 36 -and
        [bool]$runnerProbeRoundTrip.metrics.integrity_and_mechanism_complete -and
        [int]$runnerProbeRoundTrip.metrics.aggregate_failed_production_walking_gate_count -eq 0 -and
        [int]$runnerProbeRoundTrip.metrics.aggregate_release_timeout_count -eq 0 -and
        [int]$runnerProbeRoundTrip.nonzero_canary_metrics.aggregate_failed_production_walking_gate_count -eq 3 -and
        [int]$runnerProbeRoundTrip.nonzero_canary_metrics.aggregate_release_timeout_count -eq 2 -and
        [double]$runnerProbeRoundTrip.nonzero_canary_metrics.maximum_normalized_absolute_task_frame_lateral_displacement -eq 1.25 -and
        [double]$runnerProbeRoundTrip.nonzero_canary_metrics.aggregate_normalized_absolute_task_frame_lateral_displacement -eq 1.75 -and
        [double]$runnerProbeRoundTrip.nonzero_canary_metrics.aggregate_cumulative_absolute_cross_track_error_m_s -eq 1.0 -and
        (
            [bool]$runnerProbeRoundTrip.candidate_selector_preflight.passed -eq
                $candidateSelectorPreflightExact
        ) -and
        -not [bool]$runnerProbeRoundTrip.candidate_selector_preflight.physical_acceptance_authority -and
        [bool]$runnerProbeRoundTrip[
            [string]$campaignConfig.entrypoint_report_field
        ].passed -and
        [bool]$runnerProbeRoundTrip[
            [string]$campaignConfig.pass_field
        ] -and
        (
            [bool]$runnerProbeRoundTrip.same_selected_policy_independent_morphology_evidence -eq
                (-not [bool]$campaignConfig.paired_candidate_contract)
        ) -and
        (
            [bool]$runnerProbeRoundTrip.development_data_only -eq
                [bool]$campaignConfig.paired_candidate_contract
        ) -and
        [int]$runnerProbeRoundTrip.physical_world_build_count -eq 0 -and
        -not [bool]$runnerProbeRoundTrip.physical_acceptance_authority
    )
    if (-not $runnerPreflightExact) {
        throw "The $CampaignId runner/report synthetic preflight failed"
    }

    if ($PreflightOnly) {
        $preflightBundle = [ordered]@{
            schema_version = [string]$campaignConfig.preflight_bundle_schema
            campaign_id = $CampaignId
            gate_id = [string]$campaignConfig.gate_id
            candidate_id = [string]$campaignConfig.candidate_id
            controller_policy_id = $expectedPolicyId
            candidate_policy_digest = $expectedPolicyDigest
            full_integrity_receipt_schema = (
                [string]$fullReceipt.schema_version
            )
            full_integrity_passed = [bool]$fullReceipt.passed
            exact_declared_policy_runtime_boundaries_called = (
                [bool]$fullReceipt.exact_declared_policy_runtime_boundaries_called
            )
            declared_policy_runtime_boundary_count = (
                [int]$fullReceipt.declared_policy_runtime_boundary_count
            )
            declared_policy_runtime_boundaries_passed = (
                [bool]$fullReceipt.declared_policy_runtime_boundaries_passed
            )
            exact_worst_case_declared_policy_runtime_horizon_called = (
                [bool]$fullReceipt.exact_worst_case_declared_policy_runtime_horizon_called
            )
            worst_case_declared_policy_runtime_horizon_passed = (
                [bool]$fullReceipt.worst_case_runtime_horizon_passed
            )
            worst_case_declared_policy_runtime_horizon_step_count = (
                [int]$fullReceipt.worst_case_runtime_horizon_witness.declared_step_count
            )
            worst_case_declared_policy_runtime_horizon_command_count = (
                [int]$fullReceipt.worst_case_runtime_horizon_witness.native_controller_command_count
            )
            production_execution_mode_resolver_called = (
                [bool]$fullReceipt.production_execution_mode_resolver_called
            )
            perfect_zero_error_runtime_boundary_on_every_declared_policy = (
                [bool]$fullReceipt.perfect_zero_error_runtime_boundary_on_every_declared_policy
            )
            perfect_zero_error_full_runtime_horizon_on_worst_signed_offset = (
                [bool]$fullReceipt.perfect_zero_error_full_runtime_horizon_on_worst_signed_offset
            )
            perfect_synthetic_full_integrity_gate_passed = (
                [bool]$fullReceipt.perfect_synthetic_full_integrity_gate_passed
            )
            r1_misroute_detected_before_world = (
                [bool]$fullReceipt.r1_misroute_detected_before_world
            )
            baseline_regression_full_authority_start_called = (
                [bool]$fullReceipt.exact_selected_policy_full_authority_start_called
            )
            baseline_regression_full_authority_start_passed = (
                [bool]$fullReceipt.selected_policy_full_authority_start_passed
            )
            baseline_regression_full_authority_start_receipt = (
                $fullReceipt.selected_policy_full_authority_start
            )
            candidate_mechanism_authority_preflight_passed = (
                $candidateMechanismPreflightExact
            )
            candidate_selector_regression_preflight_passed = (
                $candidateSelectorPreflightExact
            )
            entrypoint_receipt_schema = (
                [string]$entrypointReceipt.schema_version
            )
            entrypoint_cell_count = [int]$entrypointReceipt.cell_count
            exact_candidate_full_authority_start_count = (
                [int]$entrypointReceipt.exact_selected_policy_full_authority_start_count
            )
            candidate_full_authority_start_passed = (
                [bool]$entrypointReceipt.selected_policy_full_authority_start_passed
            )
            exact_candidate_declared_policy_runtime_boundary_count = (
                [int]$entrypointReceipt.exact_declared_policy_runtime_boundary_count
            )
            candidate_declared_policy_runtime_boundary_preflight_passed = (
                [bool]$entrypointReceipt.declared_policy_runtime_boundary_preflight_passed
            )
            runner_report_serialization_passed = $runnerPreflightExact
            runner_report_synthetic_cell_count = $runnerProbeResults.Count
            runner_report_source_file_count = $sourceFileReceipts.Count
            perfect_all_zero_production_aggregate_gate_passed = (
                $syntheticPerfectExact
            )
            nonzero_ordered_dictionary_canary_passed = $nonzeroCanaryExact
            nonzero_canary_failed_production_walking_gate_count = (
                [int]$canaryMetrics.aggregate_failed_production_walking_gate_count
            )
            nonzero_canary_release_timeout_count = (
                [int]$canaryMetrics.aggregate_release_timeout_count
            )
            actual_world_build_count = 0
            scene_tree_insertion_count = 0
            physics_state_modified = $false
            locomotion_outcome_exposed = $false
            physical_acceptance_authority = $false
        }
        if (-not [bool]$campaignConfig.paired_candidate_contract) {
            # Preserve the frozen R05/R05B receipt vocabulary for historical
            # consumers. BW14V uses the explicit baseline/candidate names
            # above so its treatment proof cannot be confused with the shared
            # selected-policy regression.
            $preflightBundle[
                "exact_selected_policy_full_authority_start_called"
            ] = [bool]$fullReceipt.exact_selected_policy_full_authority_start_called
            $preflightBundle[
                "selected_policy_full_authority_start_passed"
            ] = [bool]$fullReceipt.selected_policy_full_authority_start_passed
            $preflightBundle["selected_policy_full_authority_start"] = (
                $fullReceipt.selected_policy_full_authority_start
            )
            $preflightBundle[
                "exact_selected_policy_full_authority_start_count"
            ] = [int]$entrypointReceipt.exact_selected_policy_full_authority_start_count
            $preflightBundle["entrypoint_full_authority_start_passed"] = (
                [bool]$entrypointReceipt.selected_policy_full_authority_start_passed
            )
            $preflightBundle[
                "exact_entrypoint_declared_policy_runtime_boundary_count"
            ] = [int]$entrypointReceipt.exact_declared_policy_runtime_boundary_count
            $preflightBundle[
                "entrypoint_declared_policy_runtime_boundary_preflight_passed"
            ] = [bool]$entrypointReceipt.declared_policy_runtime_boundary_preflight_passed
        }
        Write-Host (
            [string]$campaignConfig.preflight_bundle_prefix +
            (
                $preflightBundle |
                    ConvertTo-Json -Compress -Depth 50
            )
        )
        Write-Host (
            "$CampaignId preflight passed: full synthetic gate plus " +
            "36/36 real entrypoint cells plus runner/report serialization, " +
            "zero worlds."
        )
        return
    }

    # Only now may retained campaign state exist.
    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
    $fullPreflightPath = Join-Path $outputDirectory (
        "full-integrity-preflight.log"
    )
    $entrypointPreflightPath = Join-Path $outputDirectory (
        "$([string]$campaignConfig.slug)-entrypoint-preflight.log"
    )
    Write-Utf8NoBom `
        -Path $fullPreflightPath `
        -Text ($fullPreflight.stdout + $fullPreflight.stderr)
    Write-Utf8NoBom `
        -Path $entrypointPreflightPath `
        -Text ($entrypointPreflight.stdout + $entrypointPreflight.stderr)
    $runnerResultIntegrityPreflightPath = Join-Path $outputDirectory (
        "$([string]$campaignConfig.slug)-result-integrity-preflight.json"
    )
    Write-Utf8NoBom `
        -Path $runnerResultIntegrityPreflightPath `
        -Text (Get-Content -Raw -LiteralPath $runnerProbeReport)
    $candidateMechanismPreflightPath = ""
    if ([bool]$campaignConfig.paired_candidate_contract) {
        $candidateMechanismPreflightPath = Join-Path $outputDirectory (
            "$([string]$campaignConfig.slug)-mechanism-preflight.log"
        )
        Write-Utf8NoBom `
            -Path $candidateMechanismPreflightPath `
            -Text (
                $candidateMechanismPreflight.stdout +
                $candidateMechanismPreflight.stderr
            )
    }

    $results = [System.Collections.Generic.List[object]]::new()
    $worldOrdinal = 0
    foreach ($cell in $cells) {
        $morphologyId = [string]$cell.morphology_id
        foreach ($seed in $seeds) {
            $worldOrdinal += 1
            Write-Host (
                "$CampaignId world $worldOrdinal/36: " +
                "$morphologyId seed=$seed"
            )
            $cellRoot = Join-Path $outputDirectory (
                "{0}-s{1}" -f $morphologyId, $seed
            )
            [void][System.IO.Directory]::CreateDirectory($cellRoot)
            $engineLogPath = Join-Path $cellRoot "engine.log"
            $workerRoot = Join-Path $tempRoot (
                "worker-{0:D2}" -f $worldOrdinal
            )
            $execution = Invoke-GodotCaptured `
                -Arguments @(
                    "--headless",
                    "--path", $projectRoot,
                    "--log-file", $engineLogPath,
                    "--script", "res://$campaignTest",
                    "--", "physical", $morphologyId, ([string]$seed)
                ) `
                -WorkerRoot $workerRoot `
                -TimeoutSeconds $CellTimeoutSeconds
            $transcriptPath = Join-Path $cellRoot "transcript.log"
            $stderrPath = Join-Path $cellRoot "stderr.log"
            Write-Utf8NoBom -Path $transcriptPath -Text $execution.stdout
            Write-Utf8NoBom -Path $stderrPath -Text $execution.stderr

            $receipt = $null
            $receiptError = ""
            try {
                $receipt = Get-ReceiptFromOutput `
                    -OutputText $execution.stdout `
                    -Prefix ([string]$campaignConfig.cell_prefix)
            } catch {
                $receiptError = $_.Exception.Message
            }
            $cellResult = New-R05CellResult `
                -Cell $cell `
                -MorphologyId $morphologyId `
                -Seed $seed `
                -Execution $execution `
                -Receipt $receipt `
                -ReceiptError $receiptError `
                -TranscriptPath $transcriptPath `
                -StderrPath $stderrPath `
                -EngineLogPath $engineLogPath
            $results.Add($cellResult)
        }
    }

    $metrics = Measure-SporeExperimentResults `
        -Results @($results) `
        -ExpectedCount 36
    $harnessPassCount = [int]$metrics.harness_pass_count
    $walkingPassCount = [int]$metrics.walking_conjunction_pass_count
    $integrityPassCount = [int]$metrics.integrity_pass_count
    $completedCount = [int]$metrics.complete_receipt_count
    $campaignPassed = (
        [bool]$metrics.integrity_and_mechanism_complete -and
        (
            -not [bool]$campaignConfig.walking_required -or
            $walkingPassCount -eq 36
        )
    )

    $report = [ordered]@{
        schema_version = [string]$campaignConfig.report_schema
        generated_utc = [DateTime]::UtcNow.ToString("o")
        source = [ordered]@{
            commit = $sourceCommit
            remote = "origin/main"
            origin_main_commit = $originMain
            clean = $true
            matches_origin_main = $true
            source_files = $sourceFileReceipts
        }
        preregistration = [ordered]@{
            path = $preregistrationPath
            sha256 = Get-PrefixedSha256 $preregistrationPath
            status = [string]$preregistration.status
            freeze_parent_commit = $freezeParentCommit
        }
        campaign_id = $CampaignId
        gate_id = [string]$campaignConfig.gate_id
        campaign_role = [string]$campaignConfig.campaign_role
        selected_candidate_id = [string]$campaignConfig.candidate_id
        selected_policy_id = $expectedPolicyId
        selected_policy_digest = $expectedPolicyDigest
        morphology_ids = @(
            $cells | ForEach-Object { [string]$_.morphology_id }
        )
        generator_indices = $indices
        campaign_seeds = $seeds
        expected_world_count = 36
        observed_world_count = $results.Count
        complete_receipt_count = $completedCount
        harness_pass_count = $harnessPassCount
        walking_pass_count = $walkingPassCount
        integrity_pass_count = $integrityPassCount
        failure_count = 36 - $harnessPassCount
        metrics = $metrics
        material_profile_id = "godot_jolt_bw5c_mu095_v1"
        authored_friction = 0.95
        full_integrity_preflight = [ordered]@{
            passed = $fullPreflightExact
            scope = "baseline_regression_all_declared_bw13p_policies"
            actual_world_build_count = 0
            transcript_path = $fullPreflightPath
            transcript_sha256 = Get-PrefixedSha256 $fullPreflightPath
            bw12e_exact_zero_control_mismatch_detected = (
                [bool]$fullReceipt.bw12e_exact_zero_control_mismatch_detected
            )
        }
        experiment_result_integrity_preflight = [ordered]@{
            passed = (
                $runnerPreflightExact -and
                $syntheticPerfectExact -and
                $nonzeroCanaryExact
            )
            perfect_all_zero_36_cell_matrix_passed = $syntheticPerfectExact
            perfect_observed_world_count = (
                [int]$syntheticMetrics.observed_world_count
            )
            perfect_failed_production_walking_gate_count = (
                [int]$syntheticMetrics.aggregate_failed_production_walking_gate_count
            )
            perfect_release_timeout_count = (
                [int]$syntheticMetrics.aggregate_release_timeout_count
            )
            nonzero_ordered_dictionary_canary_passed = $nonzeroCanaryExact
            nonzero_canary_failed_production_walking_gate_count = (
                [int]$canaryMetrics.aggregate_failed_production_walking_gate_count
            )
            nonzero_canary_release_timeout_count = (
                [int]$canaryMetrics.aggregate_release_timeout_count
            )
            nonzero_canary_maximum_normalized_lateral_displacement = (
                [double]$canaryMetrics.maximum_normalized_absolute_task_frame_lateral_displacement
            )
            nonzero_canary_aggregate_normalized_lateral_displacement = (
                [double]$canaryMetrics.aggregate_normalized_absolute_task_frame_lateral_displacement
            )
            nonzero_canary_aggregate_cross_track_error_m_s = (
                [double]$canaryMetrics.aggregate_cumulative_absolute_cross_track_error_m_s
            )
            actual_world_build_count = 0
            artifact_path = $runnerResultIntegrityPreflightPath
            artifact_sha256 = (
                Get-PrefixedSha256 $runnerResultIntegrityPreflightPath
            )
        }
        candidate_mechanism_preflight = [ordered]@{
            required = [bool]$campaignConfig.paired_candidate_contract
            passed = $candidateMechanismPreflightExact
            candidate_id = [string]$campaignConfig.candidate_id
            controller_policy_id = $expectedPolicyId
            transcript_path = $candidateMechanismPreflightPath
            transcript_sha256 = $(if (
                -not [string]::IsNullOrWhiteSpace(
                    $candidateMechanismPreflightPath
                )
            ) {
                Get-PrefixedSha256 $candidateMechanismPreflightPath
            } else {
                ""
            })
            actual_world_build_count = 0
        }
        candidate_selector_preflight = [ordered]@{
            required = [bool]$campaignConfig.paired_candidate_contract
            passed = $candidateSelectorPreflightExact
            test_path = $(
                if ([bool]$campaignConfig.paired_candidate_contract) {
                    [string]$campaignConfig.selector_regression_test
                } else {
                    ""
                }
            )
            actual_world_build_count = 0
            physical_acceptance_authority = $false
        }
        results = @($results)
        same_selected_policy_independent_morphology_evidence = (
            $campaignPassed -and
            -not [bool]$campaignConfig.paired_candidate_contract
        )
        development_data_only = (
            [bool]$campaignConfig.paired_candidate_contract
        )
        finite_population_only = $true
        arbitrary_quadruped_coverage = $false
        continuous_full_volume_coverage = $false
        material_robustness = $false
        rough_terrain_robustness = $false
        external_push_recovery = $false
        sensor_noise_or_latency_robustness = $false
        running = $false
        cross_engine_c6 = $false
        completed_engine_neutral_sdk = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
    $report[[string]$campaignConfig.entrypoint_report_field] = [ordered]@{
        passed = $entrypointPreflightExact
        candidate_id = [string]$campaignConfig.candidate_id
        controller_policy_id = $expectedPolicyId
        cell_count = 36
        exact_candidate_full_authority_start_count = (
            [int]$entrypointReceipt.exact_selected_policy_full_authority_start_count
        )
        exact_candidate_declared_policy_runtime_boundary_count = (
            [int]$entrypointReceipt.exact_declared_policy_runtime_boundary_count
        )
        actual_world_build_count = 0
        transcript_path = $entrypointPreflightPath
        transcript_sha256 = (
            Get-PrefixedSha256 $entrypointPreflightPath
        )
    }
    $report[[string]$campaignConfig.pass_field] = $campaignPassed
    Write-Utf8NoBom `
        -Path $outputPath `
        -Text (
            $report |
                ConvertTo-Json -Depth 100 |
                ForEach-Object { $_ + [Environment]::NewLine }
        )
    $reportHash = Get-PrefixedSha256 $outputPath
    Write-Host "REPORT=$outputPath"
    Write-Host "REPORT_SHA256=$reportHash"
    Write-Host (
        "$($CampaignId.Replace('-', '_'))=$campaignPassed " +
        "WALKING=$walkingPassCount/36 INTEGRITY=$integrityPassCount/36"
    )
    if (-not $campaignPassed) {
        throw (
            "$CampaignId first complete result did not pass. " +
            "The retained report is final for source $sourceCommit."
        )
    }
} finally {
    if (
        (Test-Path -LiteralPath $tempRoot) -and
        $tempRoot.StartsWith(
            $tempBase,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and
        $tempRoot.Length -gt ($tempBase.Length + 20)
    ) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
