#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    ),
    [Parameter(Mandatory = $true)]
    [string]$Output
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$outputPath = [System.IO.Path]::GetFullPath($Output)
$experimentSourceCommit = "80388bf995addd657cf29b1c801de66211464259"
$baseControllerPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$rejectedInheritedPolicyId = "p5i3c_support_centroid_tilt_feedback_v1"
$expected = [ordered]@{
    "BW10F-A" = [ordered]@{
        relative_path = "balanced-wave-bw10f-a-80388bf\report.json"
        report_sha256 =
            "8f405fcecf25f8575a01a38d8715bd48eb0979741cd31b59c07d039c820f9e9d"
        policy_id = "sporespore_scheduled_load_transfer_bw10f_a_v2"
        policy_digest =
            "sha256:d7f3dd32eaea8d6bac411bb541216eb70f9b291ee88276f46209a15ee0360bce"
        passed_gate_count = 8
        failed_gate_count = 14
        mechanism_receipt_failure_count = 1
        mechanism_failed_cell_id = "fresh_rough_s25004"
        physical_walking_observed_world_count = 6
        release_timeout_count = 14
        retained_plan_receipt_count = 18122
        minimum_world_plan_receipts = 1468
        active_step_count = 0
        preferred_normal_step_count = 0
        remaining_centroid_step_count = 0
        available_receipt_count = 16229
        observation_unavailable_receipt_count = 378
        upstream_infeasible_receipt_count = 1515
        fail_zero_receipt_count = 1893
    }
    "BW10F-B" = [ordered]@{
        relative_path = "balanced-wave-bw10f-b-80388bf\report.json"
        report_sha256 =
            "c62e7ae157e9e67b19b826cae941db0b366d95bf7abe0d6853e29eca9f8e1d4a"
        policy_id = "sporespore_scheduled_load_transfer_bw10f_b_v2"
        policy_digest =
            "sha256:c3c9239e7c044b893cb362e4bec33ccca75eec358b956406739ebf38d3bb9751"
        passed_gate_count = 8
        failed_gate_count = 14
        mechanism_receipt_failure_count = 1
        mechanism_failed_cell_id = "fresh_rough_s25002"
        physical_walking_observed_world_count = 7
        release_timeout_count = 14
        retained_plan_receipt_count = 18130
        minimum_world_plan_receipts = 1476
        active_step_count = 9153
        preferred_normal_step_count = 9153
        remaining_centroid_step_count = 0
        available_receipt_count = 16363
        observation_unavailable_receipt_count = 547
        upstream_infeasible_receipt_count = 1220
        fail_zero_receipt_count = 1767
    }
    "BW10F-C" = [ordered]@{
        relative_path = "balanced-wave-bw10f-c-80388bf\report.json"
        report_sha256 =
            "fc690fc9abbbee6d89e2bf48bcaa34954765e3ad514b4dd45c167cb704864def"
        policy_id = "sporespore_scheduled_load_transfer_bw10f_c_v2"
        policy_digest =
            "sha256:43bbf227b85acb15749a3e54cdb9e00e098a1d843e9ad516a4cfdd4f68ba1c03"
        passed_gate_count = 8
        failed_gate_count = 14
        mechanism_receipt_failure_count = 1
        mechanism_failed_cell_id = "fresh_rough_s25003"
        physical_walking_observed_world_count = 9
        release_timeout_count = 9
        retained_plan_receipt_count = 18114
        minimum_world_plan_receipts = 1460
        active_step_count = 8949
        preferred_normal_step_count = 0
        remaining_centroid_step_count = 8949
        available_receipt_count = 16133
        observation_unavailable_receipt_count = 564
        upstream_infeasible_receipt_count = 1417
        fail_zero_receipt_count = 1981
    }
    "BW10F-D" = [ordered]@{
        relative_path = "balanced-wave-bw10f-d-80388bf\report.json"
        report_sha256 =
            "cc37e71601998c990e1984e6bc0cdd8f0951dfd0731b4d667a76e3e5c8c2b312"
        policy_id = "sporespore_scheduled_load_transfer_bw10f_d_v2"
        policy_digest =
            "sha256:1395551e5f7f4feafe78f3bdcb0be21c57c925a381735812156b0181dc5224a8"
        passed_gate_count = 9
        failed_gate_count = 13
        mechanism_receipt_failure_count = 0
        mechanism_failed_cell_id = ""
        physical_walking_observed_world_count = 9
        release_timeout_count = 3
        retained_plan_receipt_count = 18168
        minimum_world_plan_receipts = 1514
        active_step_count = 9285
        preferred_normal_step_count = 9285
        remaining_centroid_step_count = 9285
        available_receipt_count = 16661
        observation_unavailable_receipt_count = 225
        upstream_infeasible_receipt_count = 1282
        fail_zero_receipt_count = 1507
    }
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
    param([string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
) "The retained BW10F closure filename must be exactly report.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite a BW10F closure report: $outputPath"
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW10F closure directory: $outputDirectory"
}

$sourceStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $sourceStatus.Count -eq 0
) "BW10F negative closure requires a clean worktree"
$compilerCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $compilerCommit -ceq $originMain
) "BW10F negative closure requires HEAD exactly matching origin/main"
& git -C $repoRoot merge-base --is-ancestor `
    $experimentSourceCommit $compilerCommit
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The closure compiler must descend from the BW10F experiment source"

$candidateReceipts = @()
$inputs = @()
$totalObservedWorldCount = 0
$totalIntegrityFailureCount = 0
$totalMechanismReceiptFailureCount = 0
$totalExpectedSteps = 0
$totalPlanReceipts = 0
$totalAvailableReceipts = 0
$totalObservationUnavailableReceipts = 0
$totalUpstreamInfeasibleReceipts = 0
$totalFailZeroReceipts = 0
foreach ($candidateId in $expected.Keys) {
    $identity = $expected[$candidateId]
    $path = Join-Path (
        [System.IO.Path]::GetFullPath($EvidenceRoot)
    ) ([string]$identity.relative_path)
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Missing retained $candidateId report: $path"
    Assert-Exact (
        (Get-Sha256 $path) -ceq [string]$identity.report_sha256
    ) "$candidateId report bytes do not match the frozen negative closure"
    $report = Get-Content -LiteralPath $path -Raw |
        ConvertFrom-Json -AsHashtable
    $cells = @($report.receipt.cells)
    $physicalWalkingObservedWorldCount = 0
    $mechanismPassWorldCount = 0
    $campaignExecutionPassWorldCount = 0
    $commonExecutionPassWorldCount = 0
    $candidateExpectedSteps = 0
    $candidatePlanReceipts = 0
    $minimumWorldPlanReceipts = [int]::MaxValue
    $maximumWorldPlanReceipts = 0
    $activeStepCount = 0
    $preferredNormalStepCount = 0
    $remainingCentroidStepCount = 0
    $availableReceiptCount = 0
    $observationUnavailableReceiptCount = 0
    $upstreamInfeasibleReceiptCount = 0
    $failZeroReceiptCount = 0
    $mechanismFailedCellIds = @()
    foreach ($cell in $cells) {
        $loadTransfer = $cell.scheduled_load_transfer_summary
        if ([bool]$cell.walking_observed) {
            $physicalWalkingObservedWorldCount += 1
        }
        if ([bool]$cell.scheduled_load_transfer_gate_passed) {
            $mechanismPassWorldCount += 1
        } else {
            $mechanismFailedCellIds += [string]$cell.cell_id
            Assert-Exact (
                -not [bool]$cell.candidate35_adapter_ok -and
                @($cell.candidate35_adapter_failure_codes).Count -eq 1 -and
                [string]$cell.candidate35_adapter_failure_codes[0] -ceq
                    "STABILITY_OVERLAY_CONTRIBUTION_INVALID:"
            ) "$candidateId mechanism-failed cell has an unexpected host failure"
        }
        if ([bool]$cell.campaign_execution_gate_passed) {
            $campaignExecutionPassWorldCount += 1
        }
        if ([bool]$cell.common_execution_integrity) {
            $commonExecutionPassWorldCount += 1
        }
        $candidateExpectedSteps += [int]$cell.step_count
        $candidatePlanReceipts += [int]$loadTransfer.receipt_count
        $minimumWorldPlanReceipts = [Math]::Min(
            $minimumWorldPlanReceipts,
            [int]$loadTransfer.receipt_count
        )
        $maximumWorldPlanReceipts = [Math]::Max(
            $maximumWorldPlanReceipts,
            [int]$loadTransfer.receipt_count
        )
        $activeStepCount += [int]$loadTransfer.active_step_count
        $preferredNormalStepCount +=
            [int]$loadTransfer.preferred_normal_step_count
        $remainingCentroidStepCount +=
            [int]$loadTransfer.remaining_centroid_step_count
        $availableReceiptCount +=
            [int]$loadTransfer.available_receipt_count
        $observationUnavailableReceiptCount +=
            [int]$loadTransfer.observation_unavailable_receipt_count
        $upstreamInfeasibleReceiptCount +=
            [int]$loadTransfer.upstream_infeasible_receipt_count
        $failZeroReceiptCount +=
            [int]$loadTransfer.fail_zero_receipt_count
    }
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_balanced_wave_bw10f_development_report_v1" -and
        [string]$report.source_commit -ceq $experimentSourceCommit -and
        [bool]$report.source_worktree_clean -and
        [bool]$report.source_matches_origin_main -and
        [bool]$report.development_data_only -and
        -not [bool]$report.complete -and
        -not [bool]$report.development_selectable -and
        [string]$report.result_status -ceq "incomplete" -and
        [string]$report.candidate_id -ceq $candidateId -and
        [string]$report.policy_id -ceq [string]$identity.policy_id -and
        [string]$report.base_controller_policy_id -ceq
            $baseControllerPolicyId -and
        [string]$report.candidate_policy_digest -ceq
            [string]$identity.policy_digest -and
        [int]$report.receipt.observed_world_count -eq 12 -and
        $cells.Count -eq 12 -and
        [int]$report.receipt.passed_gate_count -eq
            [int]$identity.passed_gate_count -and
        [int]$report.receipt.failed_gate_count -eq
            [int]$identity.failed_gate_count -and
        [int]$report.receipt.integrity_failure_count -eq 12 -and
        [int]$report.receipt.acquisition_failure_count -eq 0 -and
        [int]$report.receipt.mechanism_receipt_failure_count -eq
            [int]$identity.mechanism_receipt_failure_count -and
        [int]$report.receipt.ordinary_nonwalk_count -eq 12 -and
        [int]$report.receipt.release_timeout_count -eq
            [int]$identity.release_timeout_count -and
        [int]$report.receipt.nonzero_stability_world_count -eq 12 -and
        $physicalWalkingObservedWorldCount -eq
            [int]$identity.physical_walking_observed_world_count -and
        $campaignExecutionPassWorldCount -eq 0 -and
        $commonExecutionPassWorldCount -eq 0 -and
        $candidateExpectedSteps -eq 18168 -and
        $candidatePlanReceipts -eq
            [int]$identity.retained_plan_receipt_count -and
        $minimumWorldPlanReceipts -eq
            [int]$identity.minimum_world_plan_receipts -and
        $maximumWorldPlanReceipts -eq 1514 -and
        $activeStepCount -eq [int]$identity.active_step_count -and
        $preferredNormalStepCount -eq
            [int]$identity.preferred_normal_step_count -and
        $remainingCentroidStepCount -eq
            [int]$identity.remaining_centroid_step_count -and
        $availableReceiptCount -eq
            [int]$identity.available_receipt_count -and
        $observationUnavailableReceiptCount -eq
            [int]$identity.observation_unavailable_receipt_count -and
        $upstreamInfeasibleReceiptCount -eq
            [int]$identity.upstream_infeasible_receipt_count -and
        $failZeroReceiptCount -eq
            [int]$identity.fail_zero_receipt_count -and
        $failZeroReceiptCount -eq
            $observationUnavailableReceiptCount + $upstreamInfeasibleReceiptCount -and
        ($mechanismFailedCellIds -join ",") -ceq
            [string]$identity.mechanism_failed_cell_id -and
        -not [bool]$report.walking_acceptance -and
        -not [bool]$report.material_robustness -and
        -not [bool]$report.rough_terrain_robustness -and
        -not [bool]$report.physical_balance_recovery -and
        -not [bool]$report.fresh_morphology_validation -and
        -not [bool]$report.cross_engine_c6 -and
        -not [bool]$report.completed_engine_neutral_sdk -and
        -not [bool]$report.physical_acceptance_authority
    ) "$candidateId does not match the exact retained negative result"
    $candidateReceipts += [ordered]@{
        candidate_id = $candidateId
        policy_id = [string]$identity.policy_id
        candidate_policy_digest = [string]$identity.policy_digest
        observed_world_count = 12
        complete = $false
        development_selectable = $false
        passed_gate_count = [int]$identity.passed_gate_count
        failed_gate_count = [int]$identity.failed_gate_count
        integrity_failure_count = 12
        common_execution_pass_world_count = 0
        mechanism_receipt_failure_count =
            [int]$identity.mechanism_receipt_failure_count
        mechanism_pass_world_count = $mechanismPassWorldCount
        mechanism_failed_cell_ids = $mechanismFailedCellIds
        ordinary_nonwalk_count = 12
        physical_walking_observed_world_count =
            $physicalWalkingObservedWorldCount
        release_timeout_count = [int]$identity.release_timeout_count
        expected_step_count = $candidateExpectedSteps
        retained_plan_receipt_count = $candidatePlanReceipts
        missing_plan_receipt_count =
            $candidateExpectedSteps - $candidatePlanReceipts
        minimum_world_plan_receipts = $minimumWorldPlanReceipts
        maximum_world_plan_receipts = $maximumWorldPlanReceipts
        available_receipt_count = $availableReceiptCount
        observation_unavailable_receipt_count =
            $observationUnavailableReceiptCount
        upstream_infeasible_receipt_count =
            $upstreamInfeasibleReceiptCount
        fail_zero_receipt_count = $failZeroReceiptCount
        active_step_count = $activeStepCount
        preferred_normal_step_count = $preferredNormalStepCount
        remaining_centroid_step_count = $remainingCentroidStepCount
    }
    $inputs += [ordered]@{
        candidate_id = $candidateId
        path = $path
        sha256 = [string]$identity.report_sha256
    }
    $totalObservedWorldCount += 12
    $totalIntegrityFailureCount += 12
    $totalMechanismReceiptFailureCount +=
        [int]$identity.mechanism_receipt_failure_count
    $totalExpectedSteps += $candidateExpectedSteps
    $totalPlanReceipts += $candidatePlanReceipts
    $totalAvailableReceipts += $availableReceiptCount
    $totalObservationUnavailableReceipts +=
        $observationUnavailableReceiptCount
    $totalUpstreamInfeasibleReceipts +=
        $upstreamInfeasibleReceiptCount
    $totalFailZeroReceipts += $failZeroReceiptCount
}

Assert-Exact (
    $totalObservedWorldCount -eq 48 -and
    $totalIntegrityFailureCount -eq 48 -and
    $totalMechanismReceiptFailureCount -eq 3 -and
    $totalExpectedSteps -eq 72672 -and
    $totalPlanReceipts -eq 72534 -and
    $totalAvailableReceipts -eq 65386 -and
    $totalObservationUnavailableReceipts -eq 1714 -and
    $totalUpstreamInfeasibleReceipts -eq 5434 -and
    $totalFailZeroReceipts -eq 7148 -and
    $totalFailZeroReceipts -eq
        $totalObservationUnavailableReceipts + $totalUpstreamInfeasibleReceipts
) "BW10F family aggregate closure counts are not exact"

$reportObject = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw10f_negative_closure_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    experiment_source_commit = $experimentSourceCommit
    compiler_commit = $compilerCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    development_data_only = $true
    result_status =
        "candidate_family_invalidated_by_harness_identity_and_mechanism_failures"
    attempted_candidate_count = 4
    complete_candidate_count = 0
    observed_world_count = $totalObservedWorldCount
    total_integrity_failure_count = $totalIntegrityFailureCount
    total_mechanism_receipt_failure_count =
        $totalMechanismReceiptFailureCount
    expected_plan_receipt_count = $totalExpectedSteps
    retained_plan_receipt_count = $totalPlanReceipts
    missing_plan_receipt_count = $totalExpectedSteps - $totalPlanReceipts
    available_receipt_count = $totalAvailableReceipts
    observation_unavailable_receipt_count =
        $totalObservationUnavailableReceipts
    upstream_infeasible_receipt_count =
        $totalUpstreamInfeasibleReceipts
    fail_zero_receipt_count = $totalFailZeroReceipts
    root_causes = @(
        [ordered]@{
            scope = "all_48_worlds"
            failure =
                "The inherited common-execution checker required the legacy stability policy ID instead of the candidate's frozen v2 stability policy ID, making every BW10F candidate structurally ineligible."
            rejected_legacy_policy_id = $rejectedInheritedPolicyId
            required_successor_boundary =
                "A new test identity must compare the realized stability policy to the prospectively selected candidate identity while preserving every other common-execution predicate."
        },
        [ordered]@{
            scope = "three_rough_worlds"
            failure =
                "BW10F-A rough seed 25004, BW10F-B rough seed 25002, and BW10F-C rough seed 25003 stopped recording load-transfer receipts after STABILITY_OVERLAY_CONTRIBUTION_INVALID, leaving 138 SDK steps without retained plan receipts."
            required_successor_boundary =
                "Every SDK step must retain the planner receipt before downstream overlay validation, including steps that subsequently fail zero or reject actuation."
        }
    )
    frozen_selector_invoked = $true
    frozen_selector_refused_input = $true
    frozen_selector_error =
        "BW10F-A report is incomplete or source/identity mismatched"
    selection_performed = $false
    family_selected = $false
    selected_candidate_id = $null
    selected_policy_id = $null
    eligible_candidate_count = 0
    physical_observations_ranked = $false
    candidate_receipts = $candidateReceipts
    inputs = $inputs
    independent_validation_reservation_opened = $false
    cold_unbiased_friction_reservation_opened = $false
    walking_acceptance = $false
    balance_improvement = $false
    material_robustness = $false
    rough_terrain_robustness = $false
    physical_balance_recovery = $false
    fresh_morphology_validation = $false
    cross_engine_c6 = $false
    completed_engine_neutral_sdk = $false
    physical_acceptance_authority = $false
}
[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$temporaryPath = "$outputPath.tmp"
$json = $reportObject | ConvertTo-Json -Depth 64
[System.IO.File]::WriteAllText(
    $temporaryPath,
    "$json`n",
    [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::Move($temporaryPath, $outputPath, $false)
Write-Host "Retained BW10F negative closure report: $outputPath"
Write-Host (
    "BALANCED_WAVE_BW10F_SELECTION_PERFORMED=false " +
    "FAMILY_INVALIDATED=true WORLDS=$totalObservedWorldCount/48 " +
    "MISSING_PLAN_RECEIPTS=$($totalExpectedSteps - $totalPlanReceipts)"
)
