#requires -Version 7.0

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw13p_r1_closure_manifest.json"
)
$expectedSourceCommit = "06a4ea6efecb91abbcbf73457375b51a1512f59b"
. (Join-Path $PSScriptRoot "closed_experiment_source_audit.ps1")
$expectedCandidatePolicies = [ordered]@{
    "BW13P-A" = "sporespore_scheduled_load_transfer_bw13p_a_v3"
    "BW13P-B" = "sporespore_scheduled_load_transfer_bw13p_b_v3"
    "BW13P-C" = "sporespore_scheduled_load_transfer_bw13p_c_v3"
    "BW13P-D" = "sporespore_scheduled_load_transfer_bw13p_d_v3"
}

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
) "The BW13P-R1 closure manifest is missing"
$manifest = (
    Get-Content -LiteralPath $manifestPath -Raw |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw13p_r1_closure_manifest_v1" -and
    [string]$manifest.status -ceq
        "complete_candidate_family_invalidated_by_execution_mode_routing_and_phase_schema_failures" -and
    [string]$manifest.experiment_source_commit -ceq $expectedSourceCommit -and
    [bool]$manifest.development_data_only -and
    [bool]$manifest.immutability.r1_repair_or_rerun_forbidden -and
    [bool]$manifest.immutability.candidate_selection_from_r1_forbidden -and
    [bool]$manifest.immutability.new_successor_source_and_preregistration_identity_required -and
    -not [bool]$manifest.claims.development_selection_authority -and
    -not [bool]$manifest.claims.walking_acceptance -and
    -not [bool]$manifest.claims.physical_acceptance_authority
) "The BW13P-R1 closure identity or fail-closed boundary changed"

$preregistrationPath = Join-Path $repoRoot (
    [string]$manifest.preregistration.path
)
Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Get-Sha256 -Path $preregistrationPath) -ceq
        [string]$manifest.preregistration.raw_sha256 -and
    [string]$manifest.preregistration.status -ceq
        "frozen_before_first_bw13p_r1_physics_world" -and
    [string]$manifest.preregistration.implementation_parent_commit -ceq
        "e798e21e97ed95d5627ae0974d30a26feb0560a1"
) "The frozen BW13P-R1 preregistration is missing or byte-mismatched"

$reports = @($manifest.complete_attempt.candidate_reports)
Assert-Exact (
    [int]$manifest.complete_attempt.observed_world_count -eq 144 -and
    [int]$manifest.complete_attempt.complete_receipt_count -eq 144 -and
    [int]$manifest.complete_attempt.integrity_pass_count -eq 0 -and
    [int]$manifest.complete_attempt.mechanism_pass_count -eq 144 -and
    [int]$manifest.complete_attempt.combined_application_pass_count -eq 0 -and
    [int]$manifest.complete_attempt.walking_conjunction_pass_count -eq 0 -and
    $reports.Count -eq 4
) "The retained BW13P-R1 family totals changed"

$observedCandidateIds = @(
    $reports |
        ForEach-Object { [string]$_.candidate_id } |
        Sort-Object -Unique
)
Assert-Exact (
    ($observedCandidateIds -join ",") -ceq
        (($expectedCandidatePolicies.Keys | Sort-Object) -join ",")
) "The retained BW13P-R1 candidate set changed"

$validatedResultCount = 0
foreach ($entry in $reports) {
    $candidateId = [string]$entry.candidate_id
    $reportPath = [System.IO.Path]::GetFullPath([string]$entry.path)
    Assert-Exact (
        $expectedCandidatePolicies.Contains($candidateId) -and
        [string]$entry.stability_policy_id -ceq
            [string]$expectedCandidatePolicies[$candidateId] -and
        (Test-Path -LiteralPath $reportPath -PathType Leaf) -and
        (Get-Sha256 -Path $reportPath) -ceq [string]$entry.sha256
    ) "$candidateId report is missing, byte-mismatched, or identity-mismatched"

    $report = (
        Get-Content -LiteralPath $reportPath -Raw |
            ConvertFrom-Json -AsHashtable
    )
    $results = @($report.results)
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_bw13p_r1_morphology_development_report_v1" -and
        [string]$report.campaign_id -ceq
            "BW13P-R1-MORPHOLOGY-DEVELOPMENT" -and
        [string]$report.candidate_id -ceq $candidateId -and
        [string]$report.stability_policy_id -ceq
            [string]$expectedCandidatePolicies[$candidateId] -and
        [string]$report.source.commit -ceq $expectedSourceCommit -and
        [string]$report.source.origin_main_commit -ceq $expectedSourceCommit -and
        [bool]$report.source.clean -and
        [bool]$report.source.matches_origin_main -and
        [int]$report.expected_world_count -eq 36 -and
        $results.Count -eq 36 -and
        -not [bool]$report.complete -and
        -not [bool]$report.candidate_mechanism_eligible -and
        -not [bool]$report.walking_acceptance -and
        -not [bool]$report.physical_acceptance_authority -and
        [int]$report.metrics.observed_world_count -eq 36 -and
        [int]$report.metrics.complete_receipt_count -eq 36 -and
        [int]$report.metrics.integrity_pass_count -eq 0 -and
        [int]$report.metrics.mechanism_pass_count -eq 36 -and
        [int]$report.metrics.combined_application_pass_count -eq 0 -and
        [int]$report.metrics.walking_conjunction_pass_count -eq 0
    ) "$candidateId retained report semantics changed"

    foreach ($result in $results) {
        $receipt = $result.receipt
        Assert-Exact (
            [int]$result.process_exit_code -eq 1 -and
            -not [bool]$result.timed_out -and
            [bool]$result.receipt_parsed -and
            -not [bool]$result.harness_passed -and
            -not [bool]$result.common_execution_integrity -and
            [bool]$result.mechanism_gate_passed -and
            -not [bool]$result.combined_application_gate_passed -and
            -not [bool]$result.walking_observed -and
            [int]$receipt.sdk_step_count -eq 1154 -and
            [int]$receipt.sdk_safe_disable_count -eq 2880 -and
            [string]$receipt.sdk_authority_failure_code -ceq
                "STABILITY_OVERLAY_STEP_INVALID:ADAPTER_NATIVE_STEP_FAILED" -and
            -not [bool]$receipt.common_execution_integrity -and
            -not [bool]$receipt.combined_full_authority_application_gate_passed -and
            -not [bool]$receipt.walking_observed
        ) "$candidateId contains a result outside the common invalid R1 signature"
        $validatedResultCount += 1
    }
}
Assert-Exact (
    $validatedResultCount -eq 144
) "The BW13P-R1 closure did not validate all 144 retained results"

$interruptedRoot = [System.IO.Path]::GetFullPath(
    [string]$manifest.interrupted_infrastructure_attempt.root
)
Assert-Exact (
    (Test-Path -LiteralPath $interruptedRoot -PathType Container) -and
    @(Get-ChildItem -LiteralPath $interruptedRoot -Directory).Count -eq 3 -and
    @(
        Get-ChildItem `
            -LiteralPath $interruptedRoot `
            -Recurse `
            -Filter "transcript.log" `
            -File
    ).Count -eq 2 -and
    @(
        Get-ChildItem `
            -LiteralPath $interruptedRoot `
            -Recurse `
            -Filter "report.json" `
            -File
    ).Count -eq 0 -and
    [bool]$manifest.interrupted_infrastructure_attempt.excluded_from_candidate_reports -and
    [bool]$manifest.interrupted_infrastructure_attempt.deletion_replacement_or_reuse_forbidden
) "The retained interrupted R1 attempt inventory changed"

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
    "BW13P_R1_CLOSURE_TEST_PASS reports=4 results=144 " +
    "integrity=0 mechanism=144 combined=0 walking=0 " +
    "selection_authority=false"
)
