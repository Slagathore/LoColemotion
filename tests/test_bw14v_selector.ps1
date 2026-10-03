#requires -Version 7.0

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
. (Join-Path $sdkRoot "experiment_result_integrity.ps1")
$selector = Join-Path $sdkRoot "compile_balanced_wave_bw14v_selection.ps1"
$tempRoot = Join-Path (
    [System.IO.Path]::GetTempPath()
) "sporespore_bw14v_selector_$([Guid]::NewGuid().ToString('N'))"

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Write-Json {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [object]$Value
    )
    [void][System.IO.Directory]::CreateDirectory(
        (Split-Path -Parent $Path)
    )
    [System.IO.File]::WriteAllText(
        $Path,
        (
            $Value |
                ConvertTo-Json -Depth 100 |
                ForEach-Object { $_ + [Environment]::NewLine }
        ),
        [System.Text.UTF8Encoding]::new($false)
    )
}

function New-Results {
    param([int]$WalkingFailureCount)
    $results = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt 36; $index += 1) {
        $walking = $index -ge $WalkingFailureCount
        $results.Add(
            [ordered]@{
                morphology_id = "synthetic_$index"
                generator_index = 181 + ($index / 3)
                campaign_seed = 21601 + ($index % 3)
                process_exit_code = 0
                timed_out = $false
                killed_process_tree = $false
                duration_seconds = 0.0
                receipt_parsed = $true
                receipt_parse_error = ""
                harness_passed = $true
                walking_observed = $walking
                common_execution_integrity = $true
                mechanism_gate_passed = $true
                combined_application_gate_passed = $true
                failed_production_walking_gate_count = $(if ($walking) {
                    0
                } else {
                    1
                })
                release_timeout_count = 0
                normalized_absolute_task_frame_lateral_displacement = 0.25
                cumulative_absolute_cross_track_error_m_s = 0.50
                receipt = [ordered]@{}
                transcript_path = "synthetic"
                transcript_sha256 = "sha256:synthetic"
                stderr_path = "synthetic"
                stderr_sha256 = "sha256:synthetic"
                engine_log_path = "synthetic"
                engine_log_sha256 = "sha256:synthetic"
            }
        )
    }
    return @($results)
}

function New-Report {
    param(
        [string]$CandidateId,
        [string]$PolicyId,
        [string]$PolicyDigest,
        [int]$WalkingFailureCount
    )
    $results = New-Results -WalkingFailureCount $WalkingFailureCount
    $metrics = Measure-SporeExperimentResults `
        -Results $results `
        -ExpectedCount 36
    return [ordered]@{
        schema_version = "sporespore_bw14v_morphology_development_report_v1"
        campaign_id = "BW14V-MORPHOLOGY-DEVELOPMENT"
        gate_id = "BW14V"
        campaign_role = (
            "paired_outcome_exposed_base_controller_hypothesis_selection"
        )
        selected_candidate_id = $CandidateId
        selected_policy_id = $PolicyId
        selected_policy_digest = $PolicyDigest
        development_complete = $true
        development_data_only = $true
        same_selected_policy_independent_morphology_evidence = $false
        expected_world_count = 36
        source = [ordered]@{
            commit = "synthetic_bw14v_source"
            origin_main_commit = "synthetic_bw14v_source"
            clean = $true
            matches_origin_main = $true
        }
        preregistration = [ordered]@{
            sha256 = (
                "sha256:5030239a59fa477f0dab6cf749572edf7c9040569fff93d42d40c18da3dedd33"
            )
            status = "frozen_before_first_bw14v_physics_world"
        }
        metrics = $metrics
        results = $results
        observed_world_count = 36
        complete_receipt_count = 36
        harness_pass_count = 36
        integrity_pass_count = 36
        material_profile_id = "godot_jolt_bw5c_mu095_v1"
        authored_friction = 0.95
        full_integrity_preflight = [ordered]@{
            passed = $true
            scope = "baseline_regression_all_declared_bw13p_policies"
        }
        experiment_result_integrity_preflight = [ordered]@{
            passed = $true
            perfect_all_zero_36_cell_matrix_passed = $true
            perfect_observed_world_count = 36
            perfect_failed_production_walking_gate_count = 0
            perfect_release_timeout_count = 0
            nonzero_ordered_dictionary_canary_passed = $true
            nonzero_canary_failed_production_walking_gate_count = 3
            nonzero_canary_release_timeout_count = 2
            nonzero_canary_maximum_normalized_lateral_displacement = 1.25
            nonzero_canary_aggregate_normalized_lateral_displacement = 1.75
            nonzero_canary_aggregate_cross_track_error_m_s = 1.0
        }
        candidate_mechanism_preflight = [ordered]@{
            required = $true
            passed = $true
            candidate_id = $CandidateId
            controller_policy_id = $PolicyId
        }
        bw14v_entrypoint_preflight = [ordered]@{
            passed = $true
            candidate_id = $CandidateId
            controller_policy_id = $PolicyId
            cell_count = 36
            exact_candidate_full_authority_start_count = 36
            exact_candidate_declared_policy_runtime_boundary_count = 36
        }
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
}

try {
    [void][System.IO.Directory]::CreateDirectory($tempRoot)
    $controlPath = Join-Path $tempRoot "control.json"
    $treatmentPath = Join-Path $tempRoot "treatment.json"
    Write-Json -Path $controlPath -Value (
        New-Report `
            -CandidateId "BW14V-A" `
            -PolicyId "sporespore_balanced_wave_bw5r_b_v1" `
            -PolicyDigest (
                "sha256:288012fe4af5e93f1ecd2f007821a03e95c316c27cda196317617b8130017292"
            ) `
            -WalkingFailureCount 1
    )
    Write-Json -Path $treatmentPath -Value (
        New-Report `
            -CandidateId "BW14V-B" `
            -PolicyId "sporespore_balanced_wave_bw14v_b_v1" `
            -PolicyDigest (
                "sha256:3404217d991b8eaf6b9c0d74e84768ffd36264b6d664a7c02fc14f57b176713b"
            ) `
            -WalkingFailureCount 0
    )
    $winOutput = Join-Path $tempRoot "win\selection.json"
    & $selector `
        -ReportA $controlPath `
        -ReportB $treatmentPath `
        -Output $winOutput `
        -SyntheticTestOnly
    $win = (
        Get-Content -Raw -LiteralPath $winOutput |
            ConvertFrom-Json -AsHashtable
    )
    Assert-Exact (
        [bool]$win.family_selected -and
        [string]$win.selected_candidate_id -ceq "BW14V-B" -and
        [string]$win.result_status -ceq
            "development_candidate_selected_requires_independent_validation" -and
        [bool]$win.requires_new_prospectively_frozen_independent_validation -and
        [bool]$win.reserved_qsdk_r05c_remains_unopened -and
        [bool]$win.synthetic_selector_test -and
        -not [bool]$win.walking_acceptance -and
        -not [bool]$win.independent_morphology_validation -and
        -not [bool]$win.physical_acceptance_authority
    ) "A strict treatment win did not retain the exact no-claim boundary"

    Write-Json -Path $controlPath -Value (
        New-Report `
            -CandidateId "BW14V-A" `
            -PolicyId "sporespore_balanced_wave_bw5r_b_v1" `
            -PolicyDigest (
                "sha256:288012fe4af5e93f1ecd2f007821a03e95c316c27cda196317617b8130017292"
            ) `
            -WalkingFailureCount 0
    )
    $tieOutput = Join-Path $tempRoot "tie\selection.json"
    & $selector `
        -ReportA $controlPath `
        -ReportB $treatmentPath `
        -Output $tieOutput `
        -SyntheticTestOnly
    $tie = (
        Get-Content -Raw -LiteralPath $tieOutput |
            ConvertFrom-Json -AsHashtable
    )
    Assert-Exact (
        -not [bool]$tie.family_selected -and
        [string]$tie.selected_candidate_id -ceq "" -and
        [string]$tie.result_status -ceq
            "bw14v_family_rejected_treatment_did_not_strictly_beat_control"
    ) "A tie did not reject the treatment"

    Write-Host (
        "BW14V_SELECTOR_TEST_PASS strict_treatment_win=true " +
        "tie_rejects_treatment=true"
    )
} finally {
    if (
        (Test-Path -LiteralPath $tempRoot) -and
        $tempRoot.StartsWith(
            [System.IO.Path]::GetTempPath(),
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
