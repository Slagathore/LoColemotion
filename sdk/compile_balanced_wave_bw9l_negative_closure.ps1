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
$experimentSourceCommit = "f4d25081132d5e6cdecf2ca0c4a55e657a9e92d4"
$baseControllerPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$expected = [ordered]@{
    "BW9L-A" = [ordered]@{
        relative_path =
            "balanced-wave-bw9l-a-development-f4d2508\report.json"
        report_sha256 =
            "ab34879af86f27a23fabd772eeb5f9fcf2e0bfea953171ecfc4f29ac97f2cbe0"
        policy_id = "sporespore_scheduled_load_transfer_bw9l_a_v1"
        policy_digest =
            "sha256:36fff9ffbf953e121e3ea1e3f25ad66d6358be4c9e4bcba383231b9977d98320"
        mechanism_receipt_failure_count = 9
        physical_walking_observed_world_count = 7
        release_timeout_count = 15
        total_plan_receipts = 17789
        minimum_world_plan_receipts = 1253
        maximum_world_plan_receipts = 1514
        active_step_count = 0
        preferred_normal_step_count = 0
        remaining_centroid_step_count = 0
    }
    "BW9L-B" = [ordered]@{
        relative_path =
            "balanced-wave-bw9l-b-development-f4d2508\report.json"
        report_sha256 =
            "43bcfe82e998d8bf5d44a2af8da506344068fd9c6865c304b09b56d8a9b30c22"
        policy_id = "sporespore_scheduled_load_transfer_bw9l_b_v1"
        policy_digest =
            "sha256:ee964cfc22b19ce2aa5fb198c0d646a3bbaa562cd1916e7edd704033998210ff"
        mechanism_receipt_failure_count = 10
        physical_walking_observed_world_count = 7
        release_timeout_count = 32
        total_plan_receipts = 16782
        minimum_world_plan_receipts = 912
        maximum_world_plan_receipts = 1514
        active_step_count = 8531
        preferred_normal_step_count = 8531
        remaining_centroid_step_count = 0
    }
    "BW9L-C" = [ordered]@{
        relative_path =
            "balanced-wave-bw9l-c-development-f4d2508\report.json"
        report_sha256 =
            "3100a6598a7d7ad7028d3d259d0c5aeca4fac64883347455362e553ee6989bd9"
        policy_id = "sporespore_scheduled_load_transfer_bw9l_c_v1"
        policy_digest =
            "sha256:efb7d388369692731a20c8b0670ad08e7f5fe1a3363ca2e0659969e40cdbe7dd"
        mechanism_receipt_failure_count = 10
        physical_walking_observed_world_count = 10
        release_timeout_count = 8
        total_plan_receipts = 17389
        minimum_world_plan_receipts = 902
        maximum_world_plan_receipts = 1514
        active_step_count = 8807
        preferred_normal_step_count = 0
        remaining_centroid_step_count = 8807
    }
    "BW9L-D" = [ordered]@{
        relative_path =
            "balanced-wave-bw9l-d-development-f4d2508\report.json"
        report_sha256 =
            "ec0dd411142af9fe8a0f3a9998a37b7f32c42c900fd9b9b934a7f3b30e770dd7"
        policy_id = "sporespore_scheduled_load_transfer_bw9l_d_v1"
        policy_digest =
            "sha256:e3f3074fc39d4aee5f58a8c10cb8e680c802524df21f36ea0a1e5389b227067f"
        mechanism_receipt_failure_count = 10
        physical_walking_observed_world_count = 5
        release_timeout_count = 22
        total_plan_receipts = 16832
        minimum_world_plan_receipts = 874
        maximum_world_plan_receipts = 1514
        active_step_count = 8620
        preferred_normal_step_count = 8620
        remaining_centroid_step_count = 8620
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
) "The retained BW9L closure filename must be exactly report.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite a BW9L closure report: $outputPath"
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW9L closure directory: $outputDirectory"
}

$sourceStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $sourceStatus.Count -eq 0
) "BW9L negative closure requires a clean worktree"
$compilerCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $compilerCommit -ceq $originMain
) "BW9L negative closure requires HEAD exactly matching origin/main"
& git -C $repoRoot merge-base --is-ancestor `
    $experimentSourceCommit $compilerCommit
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The closure compiler must descend from the BW9L experiment source"

$candidateReceipts = @()
$inputs = @()
$totalObservedWorldCount = 0
$totalIntegrityFailureCount = 0
$totalMechanismReceiptFailureCount = 0
$totalExpectedSteps = 0
$totalPlanReceipts = 0
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
    $candidateExpectedSteps = 0
    $candidatePlanReceipts = 0
    $minimumWorldPlanReceipts = [int]::MaxValue
    $maximumWorldPlanReceipts = 0
    $activeStepCount = 0
    $preferredNormalStepCount = 0
    $remainingCentroidStepCount = 0
    foreach ($cell in $cells) {
        $loadTransfer = $cell.scheduled_load_transfer_summary
        if ([bool]$cell.walking_observed) {
            $physicalWalkingObservedWorldCount += 1
        }
        if ([bool]$cell.scheduled_load_transfer_gate_passed) {
            $mechanismPassWorldCount += 1
        }
        if ([bool]$cell.campaign_execution_gate_passed) {
            $campaignExecutionPassWorldCount += 1
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
    }
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_balanced_wave_bw9l_development_report_v1" -and
        [string]$report.source_commit -ceq $experimentSourceCommit -and
        [bool]$report.source_worktree_clean -and
        [bool]$report.source_matches_origin_main -and
        [bool]$report.development_data_only -and
        -not [bool]$report.complete -and
        -not [bool]$report.candidate_eligible -and
        [string]$report.result_status -ceq "incomplete" -and
        [string]$report.candidate_id -ceq $candidateId -and
        [string]$report.policy_id -ceq [string]$identity.policy_id -and
        [string]$report.base_controller_policy_id -ceq
            $baseControllerPolicyId -and
        [string]$report.candidate_policy_digest -ceq
            [string]$identity.policy_digest -and
        [int]$report.receipt.observed_world_count -eq 12 -and
        $cells.Count -eq 12 -and
        [int]$report.receipt.passed_gate_count -eq 8 -and
        [int]$report.receipt.failed_gate_count -eq 14 -and
        [int]$report.receipt.integrity_failure_count -eq 12 -and
        [int]$report.receipt.mechanism_receipt_failure_count -eq
            [int]$identity.mechanism_receipt_failure_count -and
        [int]$report.receipt.ordinary_nonwalk_count -eq 12 -and
        [int]$report.receipt.release_timeout_count -eq
            [int]$identity.release_timeout_count -and
        [int]$report.receipt.nonzero_stability_world_count -eq 12 -and
        $physicalWalkingObservedWorldCount -eq
            [int]$identity.physical_walking_observed_world_count -and
        $campaignExecutionPassWorldCount -eq 0 -and
        $candidateExpectedSteps -eq 18168 -and
        $candidatePlanReceipts -eq [int]$identity.total_plan_receipts -and
        $candidatePlanReceipts -lt $candidateExpectedSteps -and
        $minimumWorldPlanReceipts -eq
            [int]$identity.minimum_world_plan_receipts -and
        $maximumWorldPlanReceipts -eq
            [int]$identity.maximum_world_plan_receipts -and
        $activeStepCount -eq [int]$identity.active_step_count -and
        $preferredNormalStepCount -eq
            [int]$identity.preferred_normal_step_count -and
        $remainingCentroidStepCount -eq
            [int]$identity.remaining_centroid_step_count -and
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
        candidate_eligible = $false
        passed_gate_count = 8
        failed_gate_count = 14
        integrity_failure_count = 12
        mechanism_receipt_failure_count =
            [int]$identity.mechanism_receipt_failure_count
        mechanism_pass_world_count = $mechanismPassWorldCount
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
}

Assert-Exact (
    $totalObservedWorldCount -eq 48 -and
    $totalIntegrityFailureCount -eq 48 -and
    $totalMechanismReceiptFailureCount -eq 39 -and
    $totalExpectedSteps -eq 72672 -and
    $totalPlanReceipts -eq 68792
) "BW9L family aggregate closure counts are not exact"

$reportObject = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw9l_negative_closure_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    experiment_source_commit = $experimentSourceCommit
    compiler_commit = $compilerCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    development_data_only = $true
    result_status = "candidate_family_invalidated_by_integrity_failure"
    attempted_candidate_count = 4
    complete_candidate_count = 0
    observed_world_count = $totalObservedWorldCount
    total_integrity_failure_count = $totalIntegrityFailureCount
    total_mechanism_receipt_failure_count =
        $totalMechanismReceiptFailureCount
    expected_plan_receipt_count = $totalExpectedSteps
    retained_plan_receipt_count = $totalPlanReceipts
    missing_plan_receipt_count = $totalExpectedSteps - $totalPlanReceipts
    root_cause =
        "The portable planner returned an FFI error instead of a typed fail-zero receipt when partial or rank-deficient qualified support could not produce a centroidal command."
    frozen_selector_invoked = $true
    frozen_selector_refused_input = $true
    frozen_selector_error =
        "BW9L-A report is not a complete 12-world attempt or is source/identity mismatched"
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
Write-Host "Retained BW9L negative closure report: $outputPath"
Write-Host (
    "BALANCED_WAVE_BW9L_SELECTION_PERFORMED=false " +
    "FAMILY_INVALIDATED_BY_INTEGRITY_FAILURE=true " +
    "WORLDS=$totalObservedWorldCount/48 " +
    "MISSING_PLAN_RECEIPTS=$($totalExpectedSteps - $totalPlanReceipts)"
)
