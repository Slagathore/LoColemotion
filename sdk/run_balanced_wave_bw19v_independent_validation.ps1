#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("BW19V-A", "BW19V-B")]
    [string]$Candidate,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly,
    [ValidateRange(30, 600)]
    [int]$CellTimeoutSeconds = 240
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$campaignId = "BW19V-INDEPENDENT-MORPHOLOGY-VALIDATION"
$gateId = "BW19V"
$campaignRole = "two_arm_prospective_independent_morphology_validation"
$campaignTest = (
    "tests/test_sdk_balanced_wave_bw19v_independent_validation.gd"
)
$authorityTest = "tests/test_sdk_balanced_wave_bw19v_scale_contract.gd"
$selectorTest = "tests/test_bw19v_selector.ps1"
$fullGateTest = "tests/test_sdk_full_integrity_gate_satisfiability.gd"
$preregistrationPath = Join-Path $sdkRoot (
    "balanced_wave_bw19v_independent_validation_preregistration.json"
)
$candidateDeclarationsPath = Join-Path $sdkRoot (
    "balanced_wave_bw19v_validation_candidates.json"
)
$experimentResultIntegrityPath = Join-Path $sdkRoot (
    "experiment_result_integrity.ps1"
)
$expectedPreregistrationSha256 = (
    "sha256:134b8eb4ddd9a7854f363379f6eb6d30e6721e1303f027f8eb1b0347ff74d3dc"
)
$expectedCandidateDeclarationsSha256 = (
    "sha256:02124811891638efaad30fc6e04b3a10b600a5eab913984c1d4c8abbd1a963a3"
)
$expectedBw18gClosureSha256 = (
    "sha256:bd5f63f01daac4ddc3f666b15bc4e8743fea770c090af54b6611cc409c0e6104"
)
$controllerCandidateId = "BW15F-B"
$controllerPolicyId = "sporespore_balanced_wave_bw15f_b_v1"
$controllerPolicyDigest = (
    "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
)
$BW19VImplementationParentCommit = (
    "7024efdddde6c1ad889987f43c2018f4a6ac7069"
)
$candidateIndex = @{
    "BW19V-A" = 0
    "BW19V-B" = 1
}[$Candidate]
$candidateCompositionDigest = @(
    "sha256:2eb8621882b4ae4047821aca415ab1b67de3399d0ab272a91f57fb0fc2ada7a4",
    "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77"
)[$candidateIndex]
$stabilityPolicyId = "sporespore_scheduled_load_transfer_bw13p_a_v3"
$authorityScope = "post_settle_full"
$executionMode = "native_balanced_wave_base_with_stability_contribution"
$globalRequestedCorrectionScale = @(0.0, 0.5)[$candidateIndex]
$expectedApplicationPassCount = @(0, 36)[$candidateIndex]
$entrypointPrefix = "BW19V_VALIDATION_ENTRYPOINT_PREFLIGHT "
$cellPrefix = "BW19V_VALIDATION_CELL "

if (-not (Test-Path -LiteralPath $experimentResultIntegrityPath -PathType Leaf)) {
    throw "The fail-closed experiment result aggregator is missing"
}
. $experimentResultIntegrityPath

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

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

function Get-PrefixedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:$(
        (
            Get-FileHash -Algorithm SHA256 -LiteralPath $Path
        ).Hash.ToLowerInvariant()
    )"
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
        [int]$TimeoutSeconds,
        [switch]$SetCandidate
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
    if ($SetCandidate) {
        $start.Environment["SPORESPORE_BW19V_CANDIDATE"] = $Candidate
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    if (-not $process.Start()) {
        throw "Failed to start isolated Godot"
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

function New-Bw19gCellResult {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Cell,
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
    if ($parsed) {
        foreach ($requiredField in @(
            "walking_observed",
            "common_execution_integrity",
            "mechanism_gate_passed",
            "combined_application_gate_passed",
            "scale_contract_passed",
            "global_requested_correction_scale",
            "failed_production_walking_gate_count",
            "release_timeout_count",
            "normalized_absolute_task_frame_lateral_displacement",
            "cumulative_absolute_cross_track_error_m_s"
        )) {
            if (-not $Receipt.Contains($requiredField)) {
                throw "Parsed BW19V receipt is missing '$requiredField'"
            }
        }
    }
    $harnessPassed = (
        $parsed -and
        [int]$Execution.exit_code -eq 0 -and
        -not [bool]$Execution.timed_out -and
        [bool]$Receipt.harness_passed -and
        [int]$Receipt.assertions_failed -eq 0
    )
    $engineLogSha256 = ""
    if (Test-Path -LiteralPath $EngineLogPath -PathType Leaf) {
        $engineLogSha256 = Get-PrefixedSha256 $EngineLogPath
    }
    return [ordered]@{
        morphology_id = [string]$Cell.morphology_id
        generator_index = [int]$Cell.generator_index
        seed = $Seed
        campaign_seed = $Seed
        process_exit_code = [int]$Execution.exit_code
        timed_out = [bool]$Execution.timed_out
        killed_process_tree = [bool]$Execution.killed_process_tree
        duration_seconds = [double]$Execution.duration_seconds
        receipt_parsed = $parsed
        receipt_parse_error = $ReceiptError
        harness_passed = $harnessPassed
        walking_observed = $(if ($parsed) {
            [bool]$Receipt.walking_observed
        } else {
            $false
        })
        common_execution_integrity = $(if ($parsed) {
            [bool]$Receipt.common_execution_integrity
        } else {
            $false
        })
        mechanism_gate_passed = $(if ($parsed) {
            [bool]$Receipt.mechanism_gate_passed
        } else {
            $false
        })
        combined_application_gate_passed = $(if ($parsed) {
            [bool]$Receipt.combined_application_gate_passed
        } else {
            $false
        })
        scale_contract_passed = $(if ($parsed) {
            [bool]$Receipt.scale_contract_passed
        } else {
            $false
        })
        global_requested_correction_scale = $(if ($parsed) {
            [double]$Receipt.global_requested_correction_scale
        } else {
            $null
        })
        failed_production_walking_gate_count = $(if ($parsed) {
            [int]$Receipt.failed_production_walking_gate_count
        } else {
            1
        })
        release_timeout_count = $(if ($parsed) {
            [int]$Receipt.release_timeout_count
        } else {
            0
        })
        normalized_absolute_task_frame_lateral_displacement = $(if ($parsed) {
            $Receipt.normalized_absolute_task_frame_lateral_displacement
        } else {
            0.0
        })
        cumulative_absolute_cross_track_error_m_s = $(if ($parsed) {
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

function New-Bw19gReport {
    param(
        [Parameter(Mandatory)]
        [object[]]$Results,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Metrics,
        [Parameter(Mandatory)]
        [string]$SourceCommit,
        [Parameter(Mandatory)]
        [string]$OriginMainCommit,
        [Parameter(Mandatory)]
        [object[]]$SourceFiles,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$PreflightArtifacts,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$SyntheticMetrics,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$CanaryMetrics,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$EntrypointReceipt,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Preregistration,
        [bool]$Synthetic = $false
    )
    $validationExecutionComplete = (
        Test-SporePolicyRelativeExecutionComplete `
            -Metrics $Metrics `
            -ExpectedCount 36 `
            -ExpectedApplicationPassCount $expectedApplicationPassCount
    )
    return [ordered]@{
        schema_version = "sporespore_bw19v_independent_validation_report_v1"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        synthetic_preflight = $Synthetic
        source = [ordered]@{
            commit = $SourceCommit
            remote = "origin/main"
            origin_main_commit = $OriginMainCommit
            clean = $true
            matches_origin_main = $true
            source_files = $SourceFiles
        }
        preregistration = [ordered]@{
            path = $preregistrationPath
            sha256 = Get-PrefixedSha256 $preregistrationPath
            status = [string]$Preregistration.status
            implementation_parent_commit = (
                [string]$Preregistration.implementation_parent_commit
            )
        }
        campaign_id = $campaignId
        gate_id = $gateId
        campaign_role = $campaignRole
        candidate_id = $Candidate
        candidate_composition_digest = $candidateCompositionDigest
        selected_candidate_id = $controllerCandidateId
        controller_policy_id = $controllerPolicyId
        controller_policy_digest = $controllerPolicyDigest
        stability_policy_id = $stabilityPolicyId
        authority_scope = $authorityScope
        execution_mode = $executionMode
        global_requested_correction_scale = (
            [double]$globalRequestedCorrectionScale
        )
        expected_application_pass_count = $expectedApplicationPassCount
        stability_influence_operation = "bound_stability_influence_v3_json"
        morphology_ids = @(
            $Preregistration.morphology_generator.cells |
                ForEach-Object { [string]$_.morphology_id }
        )
        generator_indices = @(
            $Preregistration.morphology_generator.generator_indices |
                ForEach-Object { [int]$_ }
        )
        campaign_seeds = @(
            $Preregistration.repetitions.campaign_seeds |
                ForEach-Object { [int]$_ }
        )
        expected_world_count = 36
        observed_world_count = [int]$Metrics.observed_world_count
        complete_receipt_count = [int]$Metrics.complete_receipt_count
        harness_pass_count = [int]$Metrics.harness_pass_count
        walking_pass_count = [int]$Metrics.walking_conjunction_pass_count
        integrity_pass_count = [int]$Metrics.integrity_pass_count
        mechanism_pass_count = [int]$Metrics.mechanism_pass_count
        combined_application_pass_count = (
            [int]$Metrics.combined_application_pass_count
        )
        failure_count = 36 - [int]$Metrics.harness_pass_count
        metrics = $Metrics
        material_profile_id = "godot_jolt_bw5c_mu095_v1"
        authored_friction = 0.95
        bw18g_closure_preflight = [ordered]@{
            passed = [bool]$PreflightArtifacts.bw18g_closure_passed
            closure_manifest_path = (
                "sdk/balanced_wave_bw18g_closure_manifest.json"
            )
            closure_manifest_sha256 = $expectedBw18gClosureSha256
            source_family_valid_selection = $false
            hypothesis_generation_only = $true
            actual_world_build_count = 0
        }
        full_integrity_preflight = [ordered]@{
            passed = [bool]$PreflightArtifacts.full_integrity_passed
            receipt_schema = (
                "sporespore_full_integrity_gate_satisfiability_receipt_v5"
            )
            actual_world_build_count = 0
            artifact_path = [string]$PreflightArtifacts.full_integrity_path
            artifact_sha256 = (
                [string]$PreflightArtifacts.full_integrity_sha256
            )
        }
        experiment_result_integrity_preflight = [ordered]@{
            passed = (
                [bool]$PreflightArtifacts.result_integrity_passed -and
                [bool]$PreflightArtifacts.runner_roundtrip_passed
            )
            policy_relative_perfect_synthetic_gate_passed = (
                [bool]$SyntheticMetrics.policy_relative_execution_complete
            )
            expected_application_pass_count = (
                $expectedApplicationPassCount
            )
            perfect_observed_world_count = (
                [int]$SyntheticMetrics.observed_world_count
            )
            perfect_application_pass_count = (
                [int]$SyntheticMetrics.combined_application_pass_count
            )
            perfect_failed_production_walking_gate_count = (
                [int]$SyntheticMetrics.aggregate_failed_production_walking_gate_count
            )
            perfect_release_timeout_count = (
                [int]$SyntheticMetrics.aggregate_release_timeout_count
            )
            nonzero_ordered_dictionary_canary_passed = $true
            nonzero_canary_failed_production_walking_gate_count = (
                [int]$CanaryMetrics.aggregate_failed_production_walking_gate_count
            )
            nonzero_canary_release_timeout_count = (
                [int]$CanaryMetrics.aggregate_release_timeout_count
            )
            nonzero_canary_maximum_normalized_lateral_displacement = (
                [double]$CanaryMetrics.maximum_normalized_absolute_task_frame_lateral_displacement
            )
            nonzero_canary_aggregate_normalized_lateral_displacement = (
                [double]$CanaryMetrics.aggregate_normalized_absolute_task_frame_lateral_displacement
            )
            nonzero_canary_aggregate_cross_track_error_m_s = (
                [double]$CanaryMetrics.aggregate_cumulative_absolute_cross_track_error_m_s
            )
            actual_world_build_count = 0
            artifact_path = (
                [string]$PreflightArtifacts.result_integrity_path
            )
            artifact_sha256 = (
                [string]$PreflightArtifacts.result_integrity_sha256
            )
        }
        candidate_authority_preflight = [ordered]@{
            passed = [bool]$PreflightArtifacts.candidate_authority_passed
            candidate_id = $Candidate
            controller_policy_id = $controllerPolicyId
            stability_policy_id = $stabilityPolicyId
            authority_scope = $authorityScope
            actual_world_build_count = 0
            artifact_path = (
                [string]$PreflightArtifacts.candidate_authority_path
            )
            artifact_sha256 = (
                [string]$PreflightArtifacts.candidate_authority_sha256
            )
        }
        selector_preflight = [ordered]@{
            passed = [bool]$PreflightArtifacts.selector_passed
            test_path = $selectorTest
            actual_world_build_count = 0
            physical_acceptance_authority = $false
        }
        bw19v_entrypoint_preflight = [ordered]@{
            passed = [bool]$PreflightArtifacts.entrypoint_passed
            candidate_id = $Candidate
            controller_policy_id = $controllerPolicyId
            stability_policy_id = $stabilityPolicyId
            authority_scope = $authorityScope
            cell_count = [int]$EntrypointReceipt.cell_count
            exact_candidate_adapter_start_count = (
                [int]$EntrypointReceipt.exact_selected_policy_full_authority_start_count
            )
            exact_declared_policy_runtime_boundary_count = (
                [int]$EntrypointReceipt.exact_declared_policy_runtime_boundary_count
            )
            actual_world_build_count = 0
            artifact_path = [string]$PreflightArtifacts.entrypoint_path
            artifact_sha256 = (
                [string]$PreflightArtifacts.entrypoint_sha256
            )
        }
        results = $Results
        validation_execution_complete = $validationExecutionComplete
        cohort_outcome_exposed_before_preregistration = $false
        prospective_independent_validation_data = $true
        finite_population_only = $true
        walking_acceptance = $false
        balance_improvement = $false
        independent_morphology_validation = $false
        arbitrary_quadruped_coverage = $false
        continuous_full_volume_coverage = $false
        material_robustness = $false
        rough_terrain_robustness = $false
        external_push_recovery = $false
        sensor_noise_or_latency_robustness = $false
        different_physics_engines = $false
        running = $false
        completed_engine_neutral_sdk = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
}

Assert-Exact (
    Test-Path -LiteralPath $godotPath -PathType Leaf
) "Godot executable not found: $godotPath"
Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "The frozen BW19V preregistration is missing"
Assert-Exact (
    Test-Path -LiteralPath $candidateDeclarationsPath -PathType Leaf
) "The frozen BW19V candidate declarations are missing"
Assert-Exact (
    (Get-PrefixedSha256 $preregistrationPath) -ceq
        $expectedPreregistrationSha256
) "BW19V preregistration bytes do not match the frozen SHA-256"
Assert-Exact (
    (Get-PrefixedSha256 $candidateDeclarationsPath) -ceq
        $expectedCandidateDeclarationsSha256
) "BW19V candidate declaration bytes do not match the frozen SHA-256"
if ($PreflightOnly -and -not [string]::IsNullOrWhiteSpace($Output)) {
    throw "Preflight-only mode cannot create a retained physics report"
}
if (-not $PreflightOnly -and [string]::IsNullOrWhiteSpace($Output)) {
    throw "The physical BW19V campaign requires a durable -Output report.json path"
}

$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)
$declarations = (
    Get-Content -Raw -LiteralPath $candidateDeclarationsPath |
        ConvertFrom-Json -AsHashtable
)
$cells = @($preregistration.morphology_generator.cells)
$seeds = @(
    $preregistration.repetitions.campaign_seeds |
        ForEach-Object { [int]$_ }
)
$candidateDeclaration = @(
    $declarations.candidates |
        Where-Object { [string]$_.candidate_id -ceq $Candidate }
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw19v_independent_validation_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw19v_physics_world" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.campaign_role -ceq $campaignRole -and
    [string]$preregistration.implementation_parent_commit -ceq
        $BW19VImplementationParentCommit -and
    (@($preregistration.candidate_order) -join ",") -ceq
        "BW19V-A,BW19V-B" -and
    [string]$declarations.schema_version -ceq
        "sporespore_balanced_wave_bw19v_validation_candidates_v1" -and
    [string]$declarations.status -ceq
        "frozen_before_first_bw19v_physics_world" -and
    [string]$declarations.implementation_parent_commit -ceq
        $BW19VImplementationParentCommit -and
    [string]$preregistration.candidate_declarations.path -ceq
        "sdk/balanced_wave_bw19v_validation_candidates.json" -and
    [string]$preregistration.candidate_declarations.raw_sha256 -ceq
        $expectedCandidateDeclarationsSha256 -and
    $candidateDeclaration.Count -eq 1 -and
    [string]$candidateDeclaration[0].controller_policy_id -ceq
        $controllerPolicyId -and
    [string]$candidateDeclaration[0].controller_policy_digest -ceq
        $controllerPolicyDigest -and
    [string]$candidateDeclaration[0].stability_policy_id -ceq
        $stabilityPolicyId -and
    [string]$candidateDeclaration[0].authority_scope -ceq
        $authorityScope -and
    [string]$candidateDeclaration[0].execution_mode -ceq
        $executionMode -and
    [string]$candidateDeclaration[0].stability_influence_operation -ceq
        "bound_stability_influence_v3_json" -and
    [double]$candidateDeclaration[0].global_requested_correction_scale -eq
        [double]$globalRequestedCorrectionScale -and
    [int]$candidateDeclaration[0].expected_application_pass_count -eq
        $expectedApplicationPassCount -and
    [string]$declarations.candidate_composition_digests[$Candidate] -ceq
        $candidateCompositionDigest -and
    [string]$preregistration.candidate_composition_digests[$Candidate] -ceq
        $candidateCompositionDigest -and
    $cells.Count -eq 12 -and
    (
        @($preregistration.morphology_generator.generator_indices) -join ","
    ) -ceq "205,206,207,208,209,210,211,212,213,214,215,216" -and
    -not [bool]$preregistration.morphology_generator.cohort_was_outcome_exposed_before_this_freeze -and
    [string]$preregistration.morphology_generator.cohort_role -ceq
        "prospective_independent_validation" -and
    ($seeds -join ",") -ceq "39101,39102,39103" -and
    [int]$preregistration.repetitions.expected_world_count_per_candidate -eq 36 -and
    [int]$preregistration.repetitions.expected_complete_world_count -eq 72 -and
    [bool]$preregistration.repetitions.early_stop_for_outcome_forbidden -and
    [bool]$preregistration.repetitions.first_complete_result_is_final_for_each_candidate_source_identity -and
    -not [bool]$preregistration.predecessor_interlocks.bw18g_valid_selection -and
    [bool]$preregistration.predecessor_interlocks.bw18g_hypothesis_generation_only -and
    [int]$preregistration.integrity_policy.control_expected_application_pass_count -eq 0 -and
    [int]$preregistration.integrity_policy.treatment_expected_application_pass_count -eq 36 -and
    [bool]$preregistration.integrity_policy.perfect_synthetic_input_must_be_policy_relative -and
    -not [bool]$preregistration.claim_boundary.walking_acceptance -and
    -not [bool]$preregistration.claim_boundary.balance_improvement -and
    -not [bool]$preregistration.claim_boundary.independent_morphology_validation -and
    -not [bool]$preregistration.claim_boundary.release_authorized
) "BW19V preregistration failed strict runner reconciliation"

$bw18gClosurePath = Join-Path $repoRoot (
    [string]$preregistration.predecessor_interlocks.bw18g_closure_manifest_path
)
Assert-Exact (
    (Test-Path -LiteralPath $bw18gClosurePath -PathType Leaf) -and
    (Get-PrefixedSha256 $bw18gClosurePath) -ceq
        $expectedBw18gClosureSha256
) "The closed BW18G family manifest is missing or hash-invalid"

$sourceCommit = "synthetic-zero-world"
$originMain = "synthetic-zero-world"
$outputPath = ""
$outputDirectory = ""
if (-not $PreflightOnly) {
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and $sourceStatus.Count -eq 0
    ) "Refusing to open BW19V worlds from dirty source"
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($sourceCommit) -and
        $sourceCommit -ceq $originMain
    ) "Refusing BW19V because HEAD does not match origin/main"
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    Assert-Exact (
        [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
    ) "The retained BW19V report filename must be exactly report.json"
    Assert-Exact (
        -not (Test-Path -LiteralPath $outputPath)
    ) "Refusing to overwrite an existing BW19V report: $outputPath"
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        Assert-Exact (
            @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
        ) "Refusing a nonempty BW19V evidence directory: $outputDirectory"
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

# The predecessor closure tests also assert that today's live source files are
# byte-identical to their historical experiment source. A successor must
# change some of those files, so rerunning those source-equality assertions
# would reject every legitimate successor. The strict manifest/report/selection
# SHA-256 checks above preserve the sealed predecessor results without
# conflating historical source identity with the new BW19V source.
& (Join-Path $repoRoot "tests\test_experiment_result_integrity_preflight.ps1")
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The all-zero/nonzero result-integrity preflight failed before BW19V"

$tempBase = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()
)
$tempRoot = Join-Path $tempBase (
    "sporespore_bw19v_$($Candidate.ToLowerInvariant())_" +
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
; Isolated SporeSpore BW19V independent validation campaign.

config_version=5

[application]

config/name="sporespore-bw19v-$($Candidate.ToLowerInvariant())"
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
    $fullPreflight = Invoke-GodotCaptured `
        -Arguments @(
            "--headless",
            "--path", $projectRoot,
            "--script", "res://$fullGateTest"
        ) `
        -WorkerRoot (Join-Path $tempRoot "preflight-full") `
        -TimeoutSeconds 300
    Assert-Exact (
        [int]$fullPreflight.exit_code -eq 0 -and
        -not [bool]$fullPreflight.timed_out
    ) "The full synthetic integrity gate failed before BW19V"
    $fullReceipt = Get-ReceiptFromOutput `
        -OutputText ([string]$fullPreflight.stdout) `
        -Prefix "FULL_INTEGRITY_GATE_SATISFIABILITY "
    Assert-Exact (
        [bool]$fullReceipt.passed -and
        [string]$fullReceipt.schema_version -ceq
            "sporespore_full_integrity_gate_satisfiability_receipt_v5" -and
        [bool]$fullReceipt.exact_declared_policy_runtime_boundaries_called -and
        [int]$fullReceipt.declared_policy_runtime_boundary_count -eq 8 -and
        [bool]$fullReceipt.declared_policy_runtime_boundaries_passed -and
        [bool]$fullReceipt.exact_worst_case_declared_policy_runtime_horizon_called -and
        [bool]$fullReceipt.worst_case_runtime_horizon_passed -and
        [bool]$fullReceipt.perfect_synthetic_full_integrity_gate_passed -and
        [int]$fullReceipt.actual_world_build_count -eq 0 -and
        [int]$fullReceipt.scene_tree_insertion_count -eq 0 -and
        -not [bool]$fullReceipt.physics_state_modified -and
        -not [bool]$fullReceipt.locomotion_outcome_exposed -and
        -not [bool]$fullReceipt.physical_acceptance_authority
    ) "The full synthetic integrity receipt failed strict reconciliation"

    $authorityPreflight = Invoke-GodotCaptured `
        -Arguments @(
            "--headless",
            "--path", $projectRoot,
            "--script", "res://$authorityTest"
        ) `
        -WorkerRoot (Join-Path $tempRoot "preflight-authority") `
        -TimeoutSeconds 120
    Assert-Exact (
        [int]$authorityPreflight.exit_code -eq 0 -and
        -not [bool]$authorityPreflight.timed_out -and
        [string]$authorityPreflight.stdout -match
            [regex]::Escape(
                "SDK BW19V global-scale summary: 8 passed, 0 failed"
            )
    ) "The BW19V zero-world authority contract failed"

    & pwsh `
        -NoLogo `
        -NoProfile `
        -File (Join-Path $repoRoot $selectorTest)
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "The BW19V synthetic selector regression failed before any world"

    $entrypointPreflight = Invoke-GodotCaptured `
        -Arguments @(
            "--headless",
            "--path", $projectRoot,
            "--script", "res://$campaignTest",
            "--", "preflight"
        ) `
        -WorkerRoot (Join-Path $tempRoot "preflight-entrypoint") `
        -TimeoutSeconds 180 `
        -SetCandidate
    Assert-Exact (
        [int]$entrypointPreflight.exit_code -eq 0 -and
        -not [bool]$entrypointPreflight.timed_out
    ) "The BW19V 36-cell entrypoint preflight failed"
    $entrypointReceipt = Get-ReceiptFromOutput `
        -OutputText ([string]$entrypointPreflight.stdout) `
        -Prefix $entrypointPrefix
    Assert-Exact (
        [bool]$entrypointReceipt.ok -and
        [string]$entrypointReceipt.schema_version -ceq
            "sporespore_bw19v_independent_validation_entrypoint_preflight_v1" -and
        [string]$entrypointReceipt.campaign_id -ceq $campaignId -and
        [string]$entrypointReceipt.selected_policy_id -ceq
            $controllerPolicyId -and
        [string]$entrypointReceipt.stability_policy_id -ceq
            $stabilityPolicyId -and
        [int]$entrypointReceipt.cell_count -eq 36 -and
        [int]$entrypointReceipt.exact_selected_policy_full_authority_start_count -eq 36 -and
        [bool]$entrypointReceipt.selected_policy_full_authority_start_passed -and
        [int]$entrypointReceipt.exact_declared_policy_runtime_boundary_count -eq 36 -and
        [bool]$entrypointReceipt.declared_policy_runtime_boundary_preflight_passed -and
        [int]$entrypointReceipt.actual_world_build_count -eq 0 -and
        [int]$entrypointReceipt.scene_tree_insertion_count -eq 0 -and
        -not [bool]$entrypointReceipt.physics_state_modified -and
        -not [bool]$entrypointReceipt.locomotion_outcome_exposed -and
        -not [bool]$entrypointReceipt.physical_acceptance_authority
    ) "The BW19V entrypoint receipt failed strict reconciliation"

    $sourceRelativePaths = @(
        ".gitattributes",
        "sdk/balanced_wave_bw19v_independent_validation_preregistration.json",
        "sdk/balanced_wave_bw19v_validation_candidates.json",
        "sdk/run_balanced_wave_bw19v_independent_validation.ps1",
        "sdk/compile_balanced_wave_bw19v_selection.ps1",
        "sdk/experiment_result_integrity.ps1",
        "sdk/balanced_wave_bw18g_closure_manifest.json",
        "sdk/balanced_wave_bw15f_selected_policy.json",
        "tests/test_sdk_balanced_wave_bw19v_independent_validation.gd",
        "tests/test_sdk_balanced_wave_bw19v_scale_contract.gd",
        "tests/test_sdk_balanced_wave_bw19v_generator_contract.gd",
        "tests/test_bw19v_selector.ps1",
        "tests/test_bw18g_closure.ps1",
        "tests/test_experiment_result_integrity_preflight.ps1",
        "tests/test_sdk_full_integrity_gate_satisfiability.gd",
        "tests/test_sdk_qsdk_independent_morphology_v2.gd",
        "scripts/lab/gait/physical_quadruped_proportion_spec_v2.gd",
        "scripts/lab/gait/physical_wave_gait_quadruped.gd",
        "scripts/lab/gait/sdk_godot_jolt_adapter.gd",
        "sdk/Cargo.toml",
        "sdk/Cargo.lock",
        "sdk/core/Cargo.toml",
        "sdk/core/src/controller.rs",
        "sdk/core/src/stability.rs",
        "sdk/core/src/runtime.rs",
        "sdk/adapters/godot/Cargo.toml",
        "sdk/adapters/godot/src/lib.rs",
        "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
        "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
        "docs/research/LOCOMOTION_RESEARCH_SOURCES.md",
        "DReCon.pdf",
        "2604.08780v1.pdf",
        "2507.22653v2.pdf"
    )
    $sourceFileReceipts = @(
        foreach ($relativePath in $sourceRelativePaths) {
            $absolutePath = Join-Path $repoRoot $relativePath
            Assert-Exact (
                Test-Path -LiteralPath $absolutePath -PathType Leaf
            ) "BW19V source file not found: $relativePath"
            [ordered]@{
                path = $relativePath
                sha256 = Get-PrefixedSha256 $absolutePath
            }
        }
    )
    $sourceHashes = @{}
    foreach ($sourceReceipt in $sourceFileReceipts) {
        $sourceHashes[[string]$sourceReceipt.path] = (
            [string]$sourceReceipt.sha256
        )
    }
    Assert-Exact (
        [string]$sourceHashes["DReCon.pdf"] -ceq
            "sha256:aee8a67b3532ca3cd3cc80b51248b2db94dfb175fcae0d653f90c9b3c70c2a54" -and
        [string]$sourceHashes["2604.08780v1.pdf"] -ceq
            "sha256:ae0ecb7fa7b16659b6a9ae5561176fa5c4d76788528b2ba8fc4bc533792824ae" -and
        [string]$sourceHashes["2507.22653v2.pdf"] -ceq
            "sha256:6734394082dac95355277f477f01ea9e0ee90cb03e28cc20508632f7d11ddb31" -and
        [string]$sourceHashes[
            "docs/research/LOCOMOTION_RESEARCH_SOURCES.md"
        ] -ceq
            "sha256:b86aaaf47c62d514759b3912340a61c0213aec79d725e5d5e02a252d57dacd63"
    ) "The BW19V research PDF or source-ledger hashes changed"

    $runnerProbeRoot = Join-Path $tempRoot "preflight-runner-report"
    [void][System.IO.Directory]::CreateDirectory($runnerProbeRoot)
    $probeTranscript = Join-Path $runnerProbeRoot "transcript.log"
    $probeStderr = Join-Path $runnerProbeRoot "stderr.log"
    $probeMissingEngineLog = Join-Path $runnerProbeRoot "engine.log"
    Write-Utf8NoBom -Path $probeTranscript -Text "synthetic-perfect"
    Write-Utf8NoBom -Path $probeStderr -Text ""
    $probeExecution = [ordered]@{
        exit_code = 0
        timed_out = $false
        killed_process_tree = $false
        duration_seconds = 0.0
    }
    $probeReceipt = [ordered]@{
        harness_passed = $true
        assertions_failed = 0
        walking_observed = $true
        common_execution_integrity = $true
        mechanism_gate_passed = $true
        combined_application_gate_passed = (
            $expectedApplicationPassCount -eq 36
        )
        scale_contract_passed = $true
        global_requested_correction_scale = (
            [double]$globalRequestedCorrectionScale
        )
        failed_production_walking_gate_count = 0
        release_timeout_count = 0
        normalized_absolute_task_frame_lateral_displacement = 0.0
        cumulative_absolute_cross_track_error_m_s = 0.0
    }
    $probeResults = [System.Collections.Generic.List[object]]::new()
    foreach ($cell in $cells) {
        foreach ($seed in $seeds) {
            $probeResults.Add(
                (
            New-Bw19gCellResult `
                        -Cell $cell `
                        -Seed $seed `
                        -Execution $probeExecution `
                        -Receipt $probeReceipt `
                        -ReceiptError "" `
                        -TranscriptPath $probeTranscript `
                        -StderrPath $probeStderr `
                        -EngineLogPath $probeMissingEngineLog
                )
            )
        }
    }
    $syntheticMetrics = Measure-SporePolicyRelativeExperimentResults `
        -Results @($probeResults) `
        -ExpectedCount 36 `
        -ExpectedApplicationPassCount $expectedApplicationPassCount
    Assert-Exact (
        [bool]$syntheticMetrics.policy_relative_execution_complete -and
        [int]$syntheticMetrics.observed_world_count -eq 36 -and
        [int]$syntheticMetrics.complete_receipt_count -eq 36 -and
        [int]$syntheticMetrics.harness_pass_count -eq 36 -and
        [int]$syntheticMetrics.integrity_pass_count -eq 36 -and
        [int]$syntheticMetrics.mechanism_pass_count -eq 36 -and
        [int]$syntheticMetrics.combined_application_pass_count -eq
            $expectedApplicationPassCount -and
        [int]$syntheticMetrics.expected_application_pass_count -eq
            $expectedApplicationPassCount -and
        [int]$syntheticMetrics.walking_conjunction_pass_count -eq 36 -and
        [int]$syntheticMetrics.aggregate_failed_production_walking_gate_count -eq 0 -and
        [int]$syntheticMetrics.aggregate_release_timeout_count -eq 0 -and
        [double]$syntheticMetrics.maximum_normalized_absolute_task_frame_lateral_displacement -eq 0.0 -and
        [double]$syntheticMetrics.aggregate_normalized_absolute_task_frame_lateral_displacement -eq 0.0 -and
        [double]$syntheticMetrics.aggregate_cumulative_absolute_cross_track_error_m_s -eq 0.0
    ) "The BW19V production aggregate cannot accept perfect synthetic input"

    $canaryResults = @(
        foreach ($probeResult in $probeResults) {
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
    $canaryMetrics = Measure-SporePolicyRelativeExperimentResults `
        -Results $canaryResults `
        -ExpectedCount 36 `
        -ExpectedApplicationPassCount $expectedApplicationPassCount
    Assert-Exact (
        [bool]$canaryMetrics.policy_relative_execution_complete -and
        [int]$canaryMetrics.walking_conjunction_pass_count -eq 35 -and
        [int]$canaryMetrics.walking_conjunction_failure_count -eq 1 -and
        [int]$canaryMetrics.aggregate_failed_production_walking_gate_count -eq 3 -and
        [int]$canaryMetrics.aggregate_release_timeout_count -eq 2 -and
        [double]$canaryMetrics.maximum_normalized_absolute_task_frame_lateral_displacement -eq 1.25 -and
        [double]$canaryMetrics.aggregate_normalized_absolute_task_frame_lateral_displacement -eq 1.75 -and
        [double]$canaryMetrics.aggregate_cumulative_absolute_cross_track_error_m_s -eq 1.0
    ) "The BW19V nonzero ordered-dictionary aggregation canary failed"

    $preflightArtifacts = [ordered]@{
        bw18g_closure_passed = $true
        full_integrity_passed = $true
        full_integrity_path = "synthetic-zero-world"
        full_integrity_sha256 = "sha256:synthetic"
        result_integrity_passed = $true
        runner_roundtrip_passed = $true
        result_integrity_path = "synthetic-zero-world"
        result_integrity_sha256 = "sha256:synthetic"
        candidate_authority_passed = $true
        candidate_authority_path = "synthetic-zero-world"
        candidate_authority_sha256 = "sha256:synthetic"
        selector_passed = $true
        entrypoint_passed = $true
        entrypoint_path = "synthetic-zero-world"
        entrypoint_sha256 = "sha256:synthetic"
    }
    $probeReport = New-Bw19gReport `
        -Results @($probeResults) `
        -Metrics $syntheticMetrics `
        -SourceCommit "synthetic-zero-world" `
        -OriginMainCommit "synthetic-zero-world" `
        -SourceFiles $sourceFileReceipts `
        -PreflightArtifacts $preflightArtifacts `
        -SyntheticMetrics $syntheticMetrics `
        -CanaryMetrics $canaryMetrics `
        -EntrypointReceipt $entrypointReceipt `
        -Preregistration $preregistration `
        -Synthetic $true
    $probeReportPath = Join-Path $runnerProbeRoot "report.json"
    Write-Utf8NoBom `
        -Path $probeReportPath `
        -Text (
            $probeReport |
                ConvertTo-Json -Depth 100 |
                ForEach-Object { $_ + [Environment]::NewLine }
        )
    $probeRoundTrip = (
        Get-Content -Raw -LiteralPath $probeReportPath |
            ConvertFrom-Json -AsHashtable
    )
    $roundTripMetrics = Measure-SporePolicyRelativeExperimentResults `
        -Results @($probeRoundTrip.results) `
        -ExpectedCount 36 `
        -ExpectedApplicationPassCount $expectedApplicationPassCount
    Assert-Exact (
        [string]$probeRoundTrip.schema_version -ceq
            "sporespore_bw19v_independent_validation_report_v1" -and
        [bool]$probeRoundTrip.synthetic_preflight -and
        [string]$probeRoundTrip.campaign_id -ceq $campaignId -and
        [string]$probeRoundTrip.candidate_id -ceq $Candidate -and
        [string]$probeRoundTrip.candidate_composition_digest -ceq
            $candidateCompositionDigest -and
        [string]$probeRoundTrip.stability_policy_id -ceq
            $stabilityPolicyId -and
        [string]$probeRoundTrip.authority_scope -ceq $authorityScope -and
        [double]$probeRoundTrip.global_requested_correction_scale -eq
            [double]$globalRequestedCorrectionScale -and
        [int]$probeRoundTrip.source.source_files.Count -eq
            $sourceFileReceipts.Count -and
        [int]$probeRoundTrip.results.Count -eq 36 -and
        [bool]$probeRoundTrip.validation_execution_complete -and
        [bool]$roundTripMetrics.policy_relative_execution_complete -and
        [int]$roundTripMetrics.aggregate_failed_production_walking_gate_count -eq 0 -and
        [int]$roundTripMetrics.aggregate_release_timeout_count -eq 0 -and
        [int]$probeRoundTrip.experiment_result_integrity_preflight.nonzero_canary_failed_production_walking_gate_count -eq 3 -and
        [int]$probeRoundTrip.experiment_result_integrity_preflight.nonzero_canary_release_timeout_count -eq 2 -and
        -not [bool]$probeRoundTrip.walking_acceptance -and
        -not [bool]$probeRoundTrip.balance_improvement -and
        -not [bool]$probeRoundTrip.independent_morphology_validation -and
        -not [bool]$probeRoundTrip.physical_acceptance_authority
    ) "The BW19V runner/report synthetic round-trip failed"

    if ($PreflightOnly) {
        $bundle = [ordered]@{
            schema_version = "sporespore_bw19v_preflight_bundle_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            candidate_id = $Candidate
            candidate_composition_digest = $candidateCompositionDigest
            controller_policy_id = $controllerPolicyId
            stability_policy_id = $stabilityPolicyId
            authority_scope = $authorityScope
            expected_application_pass_count = $expectedApplicationPassCount
            bw18g_closure_passed = $true
            full_integrity_passed = $true
            candidate_authority_passed = $true
            selector_regression_passed = $true
            entrypoint_cell_count = [int]$entrypointReceipt.cell_count
            exact_candidate_adapter_start_count = (
                [int]$entrypointReceipt.exact_selected_policy_full_authority_start_count
            )
            exact_declared_policy_runtime_boundary_count = (
                [int]$entrypointReceipt.exact_declared_policy_runtime_boundary_count
            )
            policy_relative_perfect_production_aggregate_gate_passed = $true
            nonzero_ordered_dictionary_canary_passed = $true
            runner_report_roundtrip_passed = $true
            source_file_count = $sourceFileReceipts.Count
            actual_world_build_count = 0
            scene_tree_insertion_count = 0
            physics_state_modified = $false
            locomotion_outcome_exposed = $false
            physical_acceptance_authority = $false
        }
        Write-Host (
            "BW19V_PREFLIGHT_BUNDLE " +
            ($bundle | ConvertTo-Json -Compress -Depth 30)
        )
        Write-Host (
            "$Candidate BW19V preflight passed: sealed BW18G closure, " +
            "full integrity, authority, selector, 36/36 entrypoints, " +
            "policy-relative synthetic/nonzero aggregation, and report " +
            "round-trip; zero worlds."
        )
        return
    }

    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
    $fullPreflightPath = Join-Path $outputDirectory (
        "full-integrity-preflight.log"
    )
    $authorityPreflightPath = Join-Path $outputDirectory (
        "bw19v-authority-preflight.log"
    )
    $entrypointPreflightPath = Join-Path $outputDirectory (
        "bw19v-entrypoint-preflight.log"
    )
    $resultIntegrityPath = Join-Path $outputDirectory (
        "bw19v-result-integrity-preflight.json"
    )
    Write-Utf8NoBom `
        -Path $fullPreflightPath `
        -Text ([string]$fullPreflight.stdout + [string]$fullPreflight.stderr)
    Write-Utf8NoBom `
        -Path $authorityPreflightPath `
        -Text (
            [string]$authorityPreflight.stdout +
            [string]$authorityPreflight.stderr
        )
    Write-Utf8NoBom `
        -Path $entrypointPreflightPath `
        -Text (
            [string]$entrypointPreflight.stdout +
            [string]$entrypointPreflight.stderr
        )
    Write-Utf8NoBom `
        -Path $resultIntegrityPath `
        -Text (Get-Content -Raw -LiteralPath $probeReportPath)

    $results = [System.Collections.Generic.List[object]]::new()
    $worldOrdinal = 0
    foreach ($cell in $cells) {
        foreach ($seed in $seeds) {
            $worldOrdinal += 1
            $morphologyId = [string]$cell.morphology_id
            Write-Host (
                "$Candidate BW19V world $worldOrdinal/36: " +
                "$morphologyId seed=$seed"
            )
            $cellRoot = Join-Path $outputDirectory (
                "{0}-s{1}" -f $morphologyId, $seed
            )
            [void][System.IO.Directory]::CreateDirectory($cellRoot)
            $engineLogPath = Join-Path $cellRoot "engine.log"
            $execution = Invoke-GodotCaptured `
                -Arguments @(
                    "--headless",
                    "--path", $projectRoot,
                    "--log-file", $engineLogPath,
                    "--script", "res://$campaignTest",
                    "--", "physical", $morphologyId, ([string]$seed)
                ) `
                -WorkerRoot (
                    Join-Path $tempRoot ("worker-{0:D2}" -f $worldOrdinal)
                ) `
                -TimeoutSeconds $CellTimeoutSeconds `
                -SetCandidate
            $transcriptPath = Join-Path $cellRoot "transcript.log"
            $stderrPath = Join-Path $cellRoot "stderr.log"
            Write-Utf8NoBom `
                -Path $transcriptPath `
                -Text ([string]$execution.stdout)
            Write-Utf8NoBom `
                -Path $stderrPath `
                -Text ([string]$execution.stderr)
            $receipt = $null
            $receiptError = ""
            try {
                $receipt = Get-ReceiptFromOutput `
                    -OutputText ([string]$execution.stdout) `
                    -Prefix $cellPrefix
            } catch {
                $receiptError = $_.Exception.Message
            }
            $results.Add(
                (
                    New-Bw19gCellResult `
                        -Cell $cell `
                        -Seed $seed `
                        -Execution $execution `
                        -Receipt $receipt `
                        -ReceiptError $receiptError `
                        -TranscriptPath $transcriptPath `
                        -StderrPath $stderrPath `
                        -EngineLogPath $engineLogPath
                )
            )
        }
    }

    $metrics = Measure-SporePolicyRelativeExperimentResults `
        -Results @($results) `
        -ExpectedCount 36 `
        -ExpectedApplicationPassCount $expectedApplicationPassCount
    $retainedPreflightArtifacts = [ordered]@{
        bw18g_closure_passed = $true
        full_integrity_passed = $true
        full_integrity_path = $fullPreflightPath
        full_integrity_sha256 = Get-PrefixedSha256 $fullPreflightPath
        result_integrity_passed = $true
        runner_roundtrip_passed = $true
        result_integrity_path = $resultIntegrityPath
        result_integrity_sha256 = Get-PrefixedSha256 $resultIntegrityPath
        candidate_authority_passed = $true
        candidate_authority_path = $authorityPreflightPath
        candidate_authority_sha256 = (
            Get-PrefixedSha256 $authorityPreflightPath
        )
        selector_passed = $true
        entrypoint_passed = $true
        entrypoint_path = $entrypointPreflightPath
        entrypoint_sha256 = Get-PrefixedSha256 $entrypointPreflightPath
    }
    $report = New-Bw19gReport `
        -Results @($results) `
        -Metrics $metrics `
        -SourceCommit $sourceCommit `
        -OriginMainCommit $originMain `
        -SourceFiles $sourceFileReceipts `
        -PreflightArtifacts $retainedPreflightArtifacts `
        -SyntheticMetrics $syntheticMetrics `
        -CanaryMetrics $canaryMetrics `
        -EntrypointReceipt $entrypointReceipt `
        -Preregistration $preregistration
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
        "$Candidate VALIDATION_EXECUTION_COMPLETE=$([bool]$report.validation_execution_complete) " +
        "WALKING=$([int]$metrics.walking_conjunction_pass_count)/36 " +
        "INTEGRITY=$([int]$metrics.integrity_pass_count)/36 " +
        "MECHANISM=$([int]$metrics.mechanism_pass_count)/36 " +
        "APPLICATION=$([int]$metrics.combined_application_pass_count)/36 " +
        "RAW_FALSE_GATES=$([int]$metrics.aggregate_failed_production_walking_gate_count) " +
        "RELEASE_TIMEOUTS=$([int]$metrics.aggregate_release_timeout_count)"
    )
    if (-not [bool]$report.validation_execution_complete) {
        throw (
            "$Candidate first complete BW19V result is policy-relative " +
            "mechanism/integrity/application " +
            "incomplete and remains final for source $sourceCommit."
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
