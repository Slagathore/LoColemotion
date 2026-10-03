#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw13p_r2_closure_manifest.json"
)
$expectedSourceCommit = "35348c76cf063af08961a16d8f636fa4aa9278d7"
. (Join-Path $PSScriptRoot "closed_experiment_source_audit.ps1")
$expectedCandidatePolicies = [ordered]@{
    "BW13P-A" = "sporespore_scheduled_load_transfer_bw13p_a_v3"
    "BW13P-B" = "sporespore_scheduled_load_transfer_bw13p_b_v3"
    "BW13P-C" = "sporespore_scheduled_load_transfer_bw13p_c_v3"
    "BW13P-D" = "sporespore_scheduled_load_transfer_bw13p_d_v3"
}

. (Join-Path $repoRoot "sdk\experiment_result_integrity.ps1")

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
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

Assert-Exact (
    Test-Path -LiteralPath $manifestPath -PathType Leaf
) "The BW13P-R2 closure manifest is missing"
$manifest = (
    Get-Content -LiteralPath $manifestPath -Raw |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw13p_r2_closure_manifest_v1" -and
    [string]$manifest.status -ceq
        "stopped_after_control_by_live_report_aggregation_integrity_failure" -and
    [string]$manifest.experiment_source_commit -ceq $expectedSourceCommit -and
    [bool]$manifest.development_data_only -and
    [bool]$manifest.immutability.r2_repair_or_resume_forbidden -and
    [bool]$manifest.immutability.r2_report_rewrite_forbidden -and
    [bool]$manifest.immutability.r2_candidate_selection_forbidden -and
    [bool]$manifest.immutability.r2_unopened_candidate_launch_forbidden -and
    [bool]$manifest.immutability.new_successor_source_and_preregistration_identity_required -and
    -not [bool]$manifest.claims.development_selection_authority -and
    -not [bool]$manifest.claims.walking_acceptance -and
    -not [bool]$manifest.claims.physical_acceptance_authority
) "The BW13P-R2 closure identity or fail-closed boundary changed"

$preregistrationPath = Join-Path $repoRoot (
    [string]$manifest.preregistration.path
)
Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Get-Sha256 -Path $preregistrationPath) -ceq
        [string]$manifest.preregistration.raw_sha256 -and
    [string]$manifest.preregistration.status -ceq
        "frozen_before_first_bw13p_r2_physics_world" -and
    [string]$manifest.preregistration.implementation_parent_commit -ceq
        "acf97c87d54fdf8d51cbd1a31bae5c8fbba1d95e"
) "The frozen BW13P-R2 preregistration is missing or byte-mismatched"

$opened = $manifest.opened_candidate
$reportPath = [System.IO.Path]::GetFullPath([string]$opened.report_path)
Assert-Exact (
    [string]$opened.candidate_id -ceq "BW13P-A" -and
    [string]$opened.stability_policy_id -ceq
        [string]$expectedCandidatePolicies["BW13P-A"] -and
    (Test-Path -LiteralPath $reportPath -PathType Leaf) -and
    (Get-Sha256 -Path $reportPath) -ceq [string]$opened.report_sha256
) "The retained BW13P-R2 control report is missing or byte-mismatched"

$report = (
    Get-Content -LiteralPath $reportPath -Raw |
        ConvertFrom-Json -AsHashtable
)
$results = @($report.results)
Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_bw13p_r2_morphology_development_report_v1" -and
    [string]$report.campaign_id -ceq
        "BW13P-R2-MORPHOLOGY-DEVELOPMENT" -and
    [string]$report.candidate_id -ceq "BW13P-A" -and
    [string]$report.stability_policy_id -ceq
        [string]$expectedCandidatePolicies["BW13P-A"] -and
    [string]$report.source.commit -ceq $expectedSourceCommit -and
    [string]$report.source.origin_main_commit -ceq $expectedSourceCommit -and
    [bool]$report.source.clean -and
    [bool]$report.source.matches_origin_main -and
    $results.Count -eq 36 -and
    [bool]$report.complete -and
    [bool]$report.candidate_mechanism_eligible -and
    -not [bool]$report.walking_acceptance -and
    -not [bool]$report.physical_acceptance_authority
) "The retained BW13P-R2 control report identity changed"

$metrics = Measure-SporeExperimentResults -Results $results -ExpectedCount 36
Assert-Exact (
    [int]$metrics.observed_world_count -eq 36 -and
    [int]$metrics.complete_receipt_count -eq 36 -and
    [int]$metrics.harness_pass_count -eq 36 -and
    [int]$metrics.integrity_pass_count -eq 36 -and
    [int]$metrics.mechanism_pass_count -eq 36 -and
    [int]$metrics.combined_application_pass_count -eq 36 -and
    [int]$metrics.walking_conjunction_pass_count -eq 35 -and
    [int]$metrics.walking_conjunction_failure_count -eq 1 -and
    [int]$metrics.aggregate_failed_production_walking_gate_count -eq 1 -and
    [int]$metrics.aggregate_release_timeout_count -eq 0 -and
    [double]$metrics.maximum_normalized_absolute_task_frame_lateral_displacement -eq
        1.5042360732234015 -and
    [double]$metrics.aggregate_normalized_absolute_task_frame_lateral_displacement -eq
        13.087811089741336 -and
    [double]$metrics.aggregate_cumulative_absolute_cross_track_error_m_s -eq
        30.55782672740262 -and
    [bool]$metrics.integrity_and_mechanism_complete -and
    [int]$report.metrics.aggregate_failed_production_walking_gate_count -eq 0
) "The retained report no longer exhibits the exact pinned aggregate mismatch"

$failed = @(
    $results |
        Where-Object {
            [int]$_['failed_production_walking_gate_count'] -ne 0
        }
)
Assert-Exact (
    $failed.Count -eq 1 -and
    [string]$failed[0].morphology_id -ceq "qsdk_r05b_generated_s191" -and
    [int]$failed[0].campaign_seed -eq 21601 -and
    [int]$failed[0].failed_production_walking_gate_count -eq 1 -and
    [int]$failed[0].receipt.failed_production_walking_gate_count -eq 1 -and
    -not [bool]$failed[0].walking_observed -and
    -not [bool]$failed[0].receipt.walking_observed
) "The exact BW13P-R2 control failure cell changed"

$artifactCount = 0
foreach ($result in $results) {
    foreach ($kind in @("transcript", "stderr", "engine_log")) {
        $pathKey = "${kind}_path"
        $hashKey = "${kind}_sha256"
        $artifactPath = [System.IO.Path]::GetFullPath(
            [string]$result[$pathKey]
        )
        $expectedHash = ([string]$result[$hashKey]).Replace("sha256:", "")
        Assert-Exact (
            (Test-Path -LiteralPath $artifactPath -PathType Leaf) -and
            (Get-Sha256 -Path $artifactPath) -ceq $expectedHash
        ) "A retained BW13P-R2 cell artifact is missing or byte-mismatched"
        $artifactCount += 1
    }
}
Assert-Exact (
    $artifactCount -eq 108
) "The closure did not validate all retained cell artifacts"

$campaignRoot = Split-Path -Parent ([string]$opened.root)
foreach ($candidateId in @("BW13P-B", "BW13P-C", "BW13P-D")) {
    $entry = @(
        $manifest.unopened_candidates |
            Where-Object { [string]$_.candidate_id -ceq $candidateId }
    )
    Assert-Exact (
        $entry.Count -eq 1 -and
        [string]$entry[0].stability_policy_id -ceq
            [string]$expectedCandidatePolicies[$candidateId] -and
        -not [bool]$entry[0].durable_candidate_directory_exists -and
        [int]$entry[0].physics_world_count -eq 0 -and
        -not (
            Test-Path `
                -LiteralPath (Join-Path $campaignRoot $candidateId)
        )
    ) "$candidateId is no longer an unopened BW13P-R2 candidate"
}

$orderedCanary = @(
    [ordered]@{ failed_production_walking_gate_count = 0 },
    [ordered]@{ failed_production_walking_gate_count = 1 }
)
function Invoke-LegacyOrderedDictionarySum {
    param([Parameter(Mandatory)][object[]]$Results)
    Set-StrictMode -Off
    return (
        $Results |
            Measure-Object `
                -Property failed_production_walking_gate_count `
                -Sum `
                -ErrorAction SilentlyContinue
    ).Sum
}
$legacyPropertySum = Invoke-LegacyOrderedDictionarySum -Results $orderedCanary
Assert-Exact (
    $null -eq $legacyPropertySum -and
    [int]$legacyPropertySum -eq 0 -and
    [bool]$manifest.report_integrity_failure.reproduced_without_world -and
    [int]$manifest.report_integrity_failure.retained_report_value -eq 0 -and
    [int]$manifest.report_integrity_failure.exact_reconstruction_from_36_top_level_results -eq 1 -and
    [int]$manifest.report_integrity_failure.exact_reconstruction_from_36_nested_receipts -eq 1
) "The BW13P-R2 live aggregation root cause no longer reproduces"

foreach ($source in @($manifest.research_sources)) {
    if (-not $source.Contains("sha256")) {
        continue
    }
    Assert-Exact (
        (Test-Path -LiteralPath (
            Join-Path $repoRoot ([string]$source.path)
        ) -PathType Leaf) -and
        (Test-SporeWorkingOrHistoricalSourceSha256 `
            -RepositoryRoot $repoRoot `
            -Commit $expectedSourceCommit `
            -Path ([string]$source.path) `
            -ExpectedSha256 ([string]$source.sha256))
    ) "A pinned locomotion research source is missing or byte-mismatched"
}

Write-Host (
    "BW13P_R2_CLOSURE_TEST_PASS control_worlds=36 " +
    "walking=35 failed_gate_reported=0 failed_gate_reconstructed=1 " +
    "unopened_candidates=3 retained_artifacts=108 selection_authority=false"
)
