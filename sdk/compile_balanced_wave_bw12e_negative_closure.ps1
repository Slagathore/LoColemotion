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
$evidenceRootPath = [System.IO.Path]::GetFullPath($EvidenceRoot)
$outputPath = [System.IO.Path]::GetFullPath($Output)
$experimentSourceCommit = "0ed8aebae1645a799bc539b3a8727456f34f8f1e"
$baseControllerPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$preregistrationPath = Join-Path $sdkRoot "balanced_wave_bw12e_preregistration.json"
$familyLogRelativePath = "balanced-wave-bw12e-family-run-0ed8aeb.log"
$familyLogSha256 =
    "f6d7ca1694d1a1c1240302df1f26ad7417c902adb6f07dc6567981da29004fe1"
$selectorLogRelativePath =
    "balanced-wave-bw12e-selector-contract-refusal-0ed8aeb.log"
$selectorLogSha256 =
    "5f2b5aa349804ccf974c85973de877f230915be7590ad142658ce698ddf2d43a"
$selectorError =
    "BW12E-A report is incomplete or source/identity mismatched"
$frozenSources = [ordered]@{
    "sdk\balanced_wave_bw12e_preregistration.json" =
        "3fc97006639568511e6a86687176d28216e1024fac4902325c90064d455f156a"
    "sdk\run_balanced_wave_bw12e_development.ps1" =
        "2460700e20e0a7baf3bdca3d2766ea58208dbefbf545fca1b25a6e3bf1935a45"
    "sdk\compile_balanced_wave_bw12e_selection.ps1" =
        "66a84cee245ec3b1949bf6e7d263413dc974ede5861d8d0c1fd88b10193c0f1f"
    "tests\test_sdk_balanced_wave_bw12e_development.gd" =
        "efdb09c22436f9b542b5114be00f0af4764c4827c5865ea99b0fbc7fda85d7da"
    "tests\test_sdk_full_integrity_gate_satisfiability.gd" =
        "5aef2f72c57b336abec6214bee7b72c448abcba82fdb1812e832dbc51a6844bb"
    "scripts\lab\gait\physical_wave_gait_quadruped.gd" =
        "b6298005dbcb1174da0c724ef7a4339a5884f38bb39c1944f10b9c618ec7845c"
    "scripts\lab\gait\sdk_godot_jolt_adapter.gd" =
        "eb85683014b96b9edd535f441dabc1213768a04e6df7a25ddfd7ab7b13733fc6"
    "sdk\core\src\stability.rs" =
        "cd17942771869965547624bca2c0863353702508d76ff9253727842e7565e78e"
}
$expectedCellIds = @(
    "fresh_baseline_s27001",
    "fresh_baseline_s27002",
    "fresh_baseline_s27003",
    "fresh_baseline_s27004",
    "fresh_baseline_s27005",
    "fresh_baseline_s27006",
    "fresh_rough_s27001",
    "fresh_rough_s27002",
    "fresh_rough_s27003",
    "fresh_rough_s27004",
    "fresh_rough_s27005",
    "fresh_rough_s27006"
)
$expected = [ordered]@{
    "BW12E-A" = [ordered]@{
        relative_path = "balanced-wave-bw12e-a-0ed8aeb\report.json"
        report_sha256 =
            "d8432e8e89f9e87ded7f61b1902815f4c75fd0c8239b44207a50b10037434973"
        policy_id = "sporespore_scheduled_load_transfer_bw11r_a_v3"
        policy_digest =
            "sha256:f726befa2326e46f3e086f7612a572a253af4b2633b788ea603f433e0b3df8ed"
        complete = $false
        top_status = "incomplete"
        receipt_status = "candidate_incomplete"
        development_selectable = $false
        godot_exit_code = 1
        passed_gate_count = 9
        failed_gate_count = 14
        integrity_failure_count = 12
        nonzero_stability_world_count = 12
        ordinary_nonwalk_count = 5
        rough_ordinary_nonwalk_count = 5
        walking_observed_world_count = 7
        release_timeout_count = 8
        active_step_count = 0
        preferred_normal_step_count = 0
        remaining_centroid_step_count = 0
        available_receipt_count = 16503
        observation_unavailable_receipt_count = 127
        upstream_infeasible_receipt_count = 1538
        fail_zero_receipt_count = 1665
        nonzero_effective_application_count = 112374
        feedback_nonzero_attempt_count = 16503
        nonzero_active_command_count = 119188
    }
    "BW12E-B" = [ordered]@{
        relative_path = "balanced-wave-bw12e-b-0ed8aeb\report.json"
        report_sha256 =
            "dcd94ad6f9f5e86e6f004be72c1b96f1663e1359cb68e6a1caa54b6f089e3f71"
        policy_id = "sporespore_scheduled_load_transfer_bw11r_b_v3"
        policy_digest =
            "sha256:832fb5d5e26085ba4e79db9dcc875e354e5b52ebbc74a77f263f5cfb51fb598e"
        complete = $true
        top_status = "treatment_development_selectable"
        receipt_status = "treatment_development_selectable"
        development_selectable = $true
        godot_exit_code = 0
        passed_gate_count = 23
        failed_gate_count = 0
        integrity_failure_count = 0
        nonzero_stability_world_count = 12
        ordinary_nonwalk_count = 7
        rough_ordinary_nonwalk_count = 6
        walking_observed_world_count = 5
        release_timeout_count = 15
        active_step_count = 8990
        preferred_normal_step_count = 8990
        remaining_centroid_step_count = 0
        available_receipt_count = 16551
        observation_unavailable_receipt_count = 282
        upstream_infeasible_receipt_count = 1335
        fail_zero_receipt_count = 1617
        nonzero_effective_application_count = 110081
        feedback_nonzero_attempt_count = 16551
        nonzero_active_command_count = 118592
    }
    "BW12E-C" = [ordered]@{
        relative_path = "balanced-wave-bw12e-c-0ed8aeb\report.json"
        report_sha256 =
            "64f3733bc42eb9611760bd76f96f13907a31cb3ca12a88e2966fe8edfc830118"
        policy_id = "sporespore_scheduled_load_transfer_bw11r_c_v3"
        policy_digest =
            "sha256:d6f89d01b3b73fe4749317a6efc3b1c2c8a6c45576a290d1a6989f73b7f7ed07"
        complete = $true
        top_status = "treatment_development_selectable"
        receipt_status = "treatment_development_selectable"
        development_selectable = $true
        godot_exit_code = 0
        passed_gate_count = 23
        failed_gate_count = 0
        integrity_failure_count = 0
        nonzero_stability_world_count = 12
        ordinary_nonwalk_count = 3
        rough_ordinary_nonwalk_count = 3
        walking_observed_world_count = 9
        release_timeout_count = 4
        active_step_count = 8709
        preferred_normal_step_count = 0
        remaining_centroid_step_count = 8709
        available_receipt_count = 16446
        observation_unavailable_receipt_count = 144
        upstream_infeasible_receipt_count = 1578
        fail_zero_receipt_count = 1722
        nonzero_effective_application_count = 110957
        feedback_nonzero_attempt_count = 16446
        nonzero_active_command_count = 117548
    }
    "BW12E-D" = [ordered]@{
        relative_path = "balanced-wave-bw12e-d-0ed8aeb\report.json"
        report_sha256 =
            "ade440c7727cd0a71d35243a83d1eb333d9fa137fe4c9b1cb7d8d3d8070fcb73"
        policy_id = "sporespore_scheduled_load_transfer_bw11r_d_v3"
        policy_digest =
            "sha256:38977d8a366e67271b6403d1aa18d17b6ebd09d66863a71cf032d96e196818db"
        complete = $true
        top_status = "treatment_development_selectable"
        receipt_status = "treatment_development_selectable"
        development_selectable = $true
        godot_exit_code = 0
        passed_gate_count = 23
        failed_gate_count = 0
        integrity_failure_count = 0
        nonzero_stability_world_count = 12
        ordinary_nonwalk_count = 4
        rough_ordinary_nonwalk_count = 4
        walking_observed_world_count = 8
        release_timeout_count = 5
        active_step_count = 9015
        preferred_normal_step_count = 9015
        remaining_centroid_step_count = 9015
        available_receipt_count = 16702
        observation_unavailable_receipt_count = 176
        upstream_infeasible_receipt_count = 1290
        fail_zero_receipt_count = 1466
        nonzero_effective_application_count = 112059
        feedback_nonzero_attempt_count = 16702
        nonzero_active_command_count = 119694
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
) "The retained BW12E closure filename must be exactly report.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite a BW12E closure report: $outputPath"
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW12E closure directory: $outputDirectory"
}

$sourceStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $sourceStatus.Count -eq 0
) "BW12E negative closure requires a clean worktree"
$compilerCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $compilerCommit -ceq $originMain
) "BW12E negative closure requires HEAD exactly matching origin/main"
& git -C $repoRoot merge-base --is-ancestor `
    $experimentSourceCommit $compilerCommit
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The closure compiler must descend from the BW12E experiment source"

foreach ($relativePath in $frozenSources.Keys) {
    $path = Join-Path $repoRoot $relativePath
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Sha256 $path) -ceq [string]$frozenSources[$relativePath]
    ) "Frozen BW12E source bytes changed: $relativePath"
}

$familyLogPath = Join-Path $evidenceRootPath $familyLogRelativePath
$selectorLogPath = Join-Path $evidenceRootPath $selectorLogRelativePath
Assert-Exact (
    (Test-Path -LiteralPath $familyLogPath -PathType Leaf) -and
    (Get-Sha256 $familyLogPath) -ceq $familyLogSha256
) "The retained BW12E family log is missing or byte-mismatched"
Assert-Exact (
    (Test-Path -LiteralPath $selectorLogPath -PathType Leaf) -and
    (Get-Sha256 $selectorLogPath) -ceq $selectorLogSha256
) "The retained BW12E selector-refusal log is missing or byte-mismatched"
$familyLogText = Get-Content -LiteralPath $familyLogPath -Raw
$selectorLogText = Get-Content -LiteralPath $selectorLogPath -Raw
Assert-Exact (
    ([regex]::Matches($familyLogText, "(?m)^START candidate=")).Count -eq 4 -and
    ([regex]::Matches($familyLogText, "(?m)^END candidate=")).Count -eq 4 -and
    $familyLogText.Contains("END candidate=BW12E-A exit=1") -and
    $familyLogText.Contains("END candidate=BW12E-B exit=0") -and
    $familyLogText.Contains("END candidate=BW12E-C exit=0") -and
    $familyLogText.Contains("END candidate=BW12E-D exit=0") -and
    $familyLogText.Contains("BW12E family finished failures=1")
) "The retained BW12E family orchestration contract is not exact"
Assert-Exact (
    $selectorLogText.Contains($selectorError)
) "The retained selector log does not contain the exact refusal"

$candidateReceipts = @()
$inputs = @()
$totalWorldBuildCount = 0
$totalStepCount = 0
$totalWalkingObservedCount = 0
$totalIntegrityFailureCount = 0
$totalMechanismFailureCount = 0
$totalAcquisitionFailureCount = 0
$totalReleaseTimeoutCount = 0
$totalNonzeroStabilityWorldCount = 0
$totalActiveStepCount = 0
$totalPreferredStepCount = 0
$totalCentroidStepCount = 0
$totalAvailableReceiptCount = 0
$totalUnavailableReceiptCount = 0
$totalInfeasibleReceiptCount = 0
$totalFailZeroReceiptCount = 0
$totalNonzeroEffectiveApplicationCount = 0
$totalFeedbackNonzeroAttemptCount = 0
$totalNonzeroActiveCommandCount = 0
$completeCandidateCount = 0

foreach ($candidateId in $expected.Keys) {
    $identity = $expected[$candidateId]
    $path = Join-Path $evidenceRootPath ([string]$identity.relative_path)
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Missing retained $candidateId report: $path"
    Assert-Exact (
        (Get-Sha256 $path) -ceq [string]$identity.report_sha256
    ) "$candidateId report bytes do not match the frozen result"
    $report = Get-Content -LiteralPath $path -Raw |
        ConvertFrom-Json -AsHashtable
    $receipt = $report.receipt
    $cells = @($receipt.cells)
    $observedCellIds = @()
    $candidateWorlds = 0
    $candidateSteps = 0
    $candidateWalkingObserved = 0
    $candidateActiveSteps = 0
    $candidatePreferredSteps = 0
    $candidateCentroidSteps = 0
    $candidateAvailable = 0
    $candidateUnavailable = 0
    $candidateInfeasible = 0
    $candidateFailZero = 0
    $candidateNonzeroEffective = 0
    $candidateFeedbackNonzero = 0
    $candidateNonzeroActive = 0
    $candidateReleaseTimeouts = 0
    foreach ($cell in $cells) {
        $observedCellIds += [string]$cell.cell_id
        $candidateWorlds += [int]$cell.world_build_count
        $candidateSteps += [int]$cell.step_count
        $candidateWalkingObserved += [int][bool]$cell.walking_observed
        $candidateReleaseTimeouts += [int]$cell.release_timeout_count
        $loadTransfer = $cell.scheduled_load_transfer_summary
        $contribution = $cell.stability_contribution_shadow
        $overlay = $cell.stability_overlay
        $candidateActiveSteps += [int]$loadTransfer.active_step_count
        $candidatePreferredSteps += [int]$loadTransfer.preferred_normal_step_count
        $candidateCentroidSteps += [int]$loadTransfer.remaining_centroid_step_count
        $candidateAvailable += [int]$loadTransfer.available_receipt_count
        $candidateUnavailable += [int]$loadTransfer.observation_unavailable_receipt_count
        $candidateInfeasible += [int]$loadTransfer.upstream_infeasible_receipt_count
        $candidateFailZero += [int]$loadTransfer.fail_zero_receipt_count
        $candidateNonzeroEffective +=
            [int]$overlay.nonzero_effective_application_count
        $candidateFeedbackNonzero +=
            [int]$contribution.feedback_nonzero_attempt_count
        $candidateNonzeroActive +=
            [int]$contribution.nonzero_active_command_count
        $expectedCampaignGate = $candidateId -cne "BW12E-A"
        Assert-Exact (
            [string]$cell.candidate_id -ceq $candidateId -and
            [string]$cell.stability_policy_id -ceq
                [string]$identity.policy_id -and
            [string]$cell.base_controller_policy_id -ceq
                $baseControllerPolicyId -and
            [string]$cell.candidate_policy_digest -ceq
                [string]$identity.policy_digest -and
            [int]$cell.world_build_count -eq 1 -and
            [int]$cell.step_count -eq 1514 -and
            [int]$cell.balanced_wave_step_receipt_count -eq 1514 -and
            [int]$cell.validated_balanced_wave_command_count -eq 12112 -and
            [int]$cell.native_actuation_application_count -eq 12112 -and
            [int]$cell.direct_body_write_count -eq 0 -and
            [bool]$cell.common_execution_integrity -and
            [bool]$cell.evidence_acquisition_gate_passed -and
            [bool]$cell.scheduled_load_transfer_gate_passed -and
            [bool]$cell.specialized_axis_gate_passed -and
            [bool]$cell.campaign_execution_gate_passed -eq
                $expectedCampaignGate -and
            [bool]$cell.bw12e_execution_gate_passed -eq
                $expectedCampaignGate -and
            [string]$cell.sdk_failure_code -ceq "" -and
            [bool]$overlay.ok -and
            [bool]$overlay.physical_influence -and
            [int]$overlay.nonzero_effective_application_count -gt 0 -and
            -not [bool]$cell.walking_claim_authorized
        ) "$candidateId $([string]$cell.cell_id) is not the exact retained result"
    }
    $expectedComplete = [bool]$identity.complete
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_balanced_wave_bw12e_development_report_v1" -and
        [string]$report.source_commit -ceq $experimentSourceCommit -and
        [bool]$report.source_worktree_clean -and
        [bool]$report.source_matches_origin_main -and
        [bool]$report.development_data_only -and
        [bool]$report.complete -eq $expectedComplete -and
        [string]$report.result_status -ceq [string]$identity.top_status -and
        [string]$report.candidate_id -ceq $candidateId -and
        [string]$report.policy_id -ceq [string]$identity.policy_id -and
        [string]$report.base_controller_policy_id -ceq
            $baseControllerPolicyId -and
        [string]$report.candidate_policy_digest -ceq
            [string]$identity.policy_digest -and
        [bool]$report.development_selectable -eq
            [bool]$identity.development_selectable -and
        [int]$report.godot_exit_code -eq
            [int]$identity.godot_exit_code -and
        [bool]$report.all_preflight_processes_passed -and
        [int]$report.preflight_actual_world_count -eq 0 -and
        [bool]$report.full_gate_satisfiability_receipt.passed -and
        [int]$report.full_gate_satisfiability_receipt.actual_world_build_count -eq 0 -and
        [string]$receipt.schema_version -ceq
            "sporespore_balanced_wave_bw12e_development_receipt_v1" -and
        [bool]$receipt.ok -eq $expectedComplete -and
        [string]$receipt.result_status -ceq
            [string]$identity.receipt_status -and
        [int]$receipt.expected_world_count -eq 12 -and
        [int]$receipt.observed_world_count -eq 12 -and
        $cells.Count -eq 12 -and
        ($observedCellIds -join ",") -ceq ($expectedCellIds -join ",") -and
        [int]$receipt.passed_gate_count -eq
            [int]$identity.passed_gate_count -and
        [int]$receipt.failed_gate_count -eq
            [int]$identity.failed_gate_count -and
        [int]$receipt.integrity_failure_count -eq
            [int]$identity.integrity_failure_count -and
        [int]$receipt.acquisition_failure_count -eq 0 -and
        [int]$receipt.mechanism_receipt_failure_count -eq 0 -and
        [int]$receipt.nonzero_stability_world_count -eq
            [int]$identity.nonzero_stability_world_count -and
        [int]$receipt.ordinary_nonwalk_count -eq
            [int]$identity.ordinary_nonwalk_count -and
        [int]$receipt.rough_ordinary_nonwalk_count -eq
            [int]$identity.rough_ordinary_nonwalk_count -and
        [int]$receipt.release_timeout_count -eq
            [int]$identity.release_timeout_count -and
        $candidateWorlds -eq 12 -and
        $candidateSteps -eq 18168 -and
        $candidateWalkingObserved -eq
            [int]$identity.walking_observed_world_count -and
        $candidateActiveSteps -eq [int]$identity.active_step_count -and
        $candidatePreferredSteps -eq
            [int]$identity.preferred_normal_step_count -and
        $candidateCentroidSteps -eq
            [int]$identity.remaining_centroid_step_count -and
        $candidateAvailable -eq [int]$identity.available_receipt_count -and
        $candidateUnavailable -eq
            [int]$identity.observation_unavailable_receipt_count -and
        $candidateInfeasible -eq
            [int]$identity.upstream_infeasible_receipt_count -and
        $candidateFailZero -eq [int]$identity.fail_zero_receipt_count -and
        $candidateFailZero -eq $candidateUnavailable + $candidateInfeasible -and
        $candidateNonzeroEffective -eq
            [int]$identity.nonzero_effective_application_count -and
        $candidateFeedbackNonzero -eq
            [int]$identity.feedback_nonzero_attempt_count -and
        $candidateNonzeroActive -eq
            [int]$identity.nonzero_active_command_count -and
        -not [bool]$report.walking_acceptance -and
        -not [bool]$report.material_robustness -and
        -not [bool]$report.rough_terrain_robustness -and
        -not [bool]$report.physical_balance_recovery -and
        -not [bool]$report.fresh_morphology_validation -and
        -not [bool]$report.cross_engine_c6 -and
        -not [bool]$report.completed_engine_neutral_sdk -and
        -not [bool]$report.physical_acceptance_authority
    ) "$candidateId does not match the exact retained BW12E result"
    foreach ($transcriptRole in $report.transcripts.Keys) {
        $transcript = $report.transcripts[$transcriptRole]
        $transcriptPath = Join-Path (
            Split-Path -Parent $path
        ) ([string]$transcript.path)
        Assert-Exact (
            (Test-Path -LiteralPath $transcriptPath -PathType Leaf) -and
            (Get-Sha256 $transcriptPath) -ceq [string]$transcript.sha256
        ) "$candidateId transcript is missing or byte-mismatched: $transcriptRole"
    }
    $candidateReceipts += [ordered]@{
        candidate_id = $candidateId
        policy_id = [string]$identity.policy_id
        candidate_policy_digest = [string]$identity.policy_digest
        observed_world_count = $candidateWorlds
        complete = $expectedComplete
        development_selectable = [bool]$identity.development_selectable
        passed_gate_count = [int]$identity.passed_gate_count
        failed_gate_count = [int]$identity.failed_gate_count
        integrity_failure_count = [int]$identity.integrity_failure_count
        acquisition_failure_count = 0
        mechanism_receipt_failure_count = 0
        nonzero_stability_world_count =
            [int]$identity.nonzero_stability_world_count
        raw_physical_walking_observed_world_count =
            $candidateWalkingObserved
        ordinary_nonwalk_count = [int]$identity.ordinary_nonwalk_count
        rough_ordinary_nonwalk_count =
            [int]$identity.rough_ordinary_nonwalk_count
        release_timeout_count = [int]$identity.release_timeout_count
        active_step_count = $candidateActiveSteps
        preferred_normal_step_count = $candidatePreferredSteps
        remaining_centroid_step_count = $candidateCentroidSteps
        available_receipt_count = $candidateAvailable
        observation_unavailable_receipt_count = $candidateUnavailable
        upstream_infeasible_receipt_count = $candidateInfeasible
        fail_zero_receipt_count = $candidateFailZero
        nonzero_effective_application_count = $candidateNonzeroEffective
    }
    $inputs += [ordered]@{
        candidate_id = $candidateId
        path = $path
        sha256 = [string]$identity.report_sha256
    }
    $totalWorldBuildCount += $candidateWorlds
    $totalStepCount += $candidateSteps
    $totalWalkingObservedCount += $candidateWalkingObserved
    $totalIntegrityFailureCount += [int]$identity.integrity_failure_count
    $totalMechanismFailureCount += [int]$receipt.mechanism_receipt_failure_count
    $totalAcquisitionFailureCount += [int]$receipt.acquisition_failure_count
    $totalReleaseTimeoutCount += $candidateReleaseTimeouts
    $totalNonzeroStabilityWorldCount +=
        [int]$identity.nonzero_stability_world_count
    $totalActiveStepCount += $candidateActiveSteps
    $totalPreferredStepCount += $candidatePreferredSteps
    $totalCentroidStepCount += $candidateCentroidSteps
    $totalAvailableReceiptCount += $candidateAvailable
    $totalUnavailableReceiptCount += $candidateUnavailable
    $totalInfeasibleReceiptCount += $candidateInfeasible
    $totalFailZeroReceiptCount += $candidateFailZero
    $totalNonzeroEffectiveApplicationCount += $candidateNonzeroEffective
    $totalFeedbackNonzeroAttemptCount += $candidateFeedbackNonzero
    $totalNonzeroActiveCommandCount += $candidateNonzeroActive
    if ($expectedComplete) {
        $completeCandidateCount += 1
    }
}

Assert-Exact (
    $totalWorldBuildCount -eq 48 -and
    $totalStepCount -eq 72672 -and
    $totalWalkingObservedCount -eq 29 -and
    $totalIntegrityFailureCount -eq 12 -and
    $totalMechanismFailureCount -eq 0 -and
    $totalAcquisitionFailureCount -eq 0 -and
    $totalReleaseTimeoutCount -eq 32 -and
    $totalNonzeroStabilityWorldCount -eq 48 -and
    $totalActiveStepCount -eq 26714 -and
    $totalPreferredStepCount -eq 18005 -and
    $totalCentroidStepCount -eq 17724 -and
    $totalAvailableReceiptCount -eq 66202 -and
    $totalUnavailableReceiptCount -eq 729 -and
    $totalInfeasibleReceiptCount -eq 5741 -and
    $totalFailZeroReceiptCount -eq 6470 -and
    $totalFailZeroReceiptCount -eq
        $totalUnavailableReceiptCount + $totalInfeasibleReceiptCount -and
    $totalNonzeroEffectiveApplicationCount -eq 445471 -and
    $totalFeedbackNonzeroAttemptCount -eq 66202 -and
    $totalNonzeroActiveCommandCount -eq 475022 -and
    $completeCandidateCount -eq 3
) "BW12E aggregate negative-closure counts are not exact"

$reportObject = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw12e_negative_closure_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    experiment_source_commit = $experimentSourceCommit
    compiler_commit = $compilerCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    development_data_only = $true
    result_status =
        "candidate_family_invalidated_by_control_semantics_mismatch"
    attempted_candidate_count = 4
    complete_candidate_count = $completeCandidateCount
    observed_world_count = $totalWorldBuildCount
    physical_outcome_count = $totalWorldBuildCount
    sdk_step_receipt_count = $totalStepCount
    raw_physical_walking_observed_world_count =
        $totalWalkingObservedCount
    integrity_failure_count = $totalIntegrityFailureCount
    acquisition_failure_count = $totalAcquisitionFailureCount
    mechanism_receipt_failure_count = $totalMechanismFailureCount
    release_timeout_count = $totalReleaseTimeoutCount
    actual_nonzero_stability_world_count =
        $totalNonzeroStabilityWorldCount
    preregistered_nonzero_stability_world_count = 36
    control_nonzero_stability_world_count = 12
    active_step_count = $totalActiveStepCount
    preferred_normal_step_count = $totalPreferredStepCount
    remaining_centroid_step_count = $totalCentroidStepCount
    available_receipt_count = $totalAvailableReceiptCount
    observation_unavailable_receipt_count =
        $totalUnavailableReceiptCount
    upstream_infeasible_receipt_count = $totalInfeasibleReceiptCount
    fail_zero_receipt_count = $totalFailZeroReceiptCount
    nonzero_effective_application_count =
        $totalNonzeroEffectiveApplicationCount
    root_cause = [ordered]@{
        classification =
            "preregistered_control_semantics_conflicted_with_real_policy_and_adapter_semantics"
        failure =
            "BW12E-A was preregistered as an exact-zero stability control, but its v3 control policy disables only the two scheduled load-transfer factors. On available observations it still carries the baseline centroidal command, and the Godot adapter applies that contribution without requiring the scheduled-load-transfer active flag."
        physical_evidence =
            "All 12 BW12E-A worlds retained active_step_count=0 and zero preferred/centroid factor steps, yet all 12 had nonzero stability influence and 112374 nonzero effective motor applications."
        preflight_limitation =
            "The frozen preflight executed the real pre-world entrypoint and the exact production integrity analyzer, but its perfect receipt was constructed rather than produced by the declared policy. It proved gate satisfiability, not policy-semantic satisfiability."
        required_successor_boundary =
            "Before a world or durable campaign directory opens, execute each declared policy over deterministic synthetic available and unavailable observations, derive the full synthetic result from those real receipts, and require the entire production gate plus candidate-specific control/treatment mechanism contract to pass."
    }
    frozen_selector_invoked = $true
    frozen_selector_refused_input = $true
    frozen_selector_error = $selectorError
    selection_performed = $false
    family_selected = $false
    selected_candidate_id = $null
    selected_policy_id = $null
    physical_observations_ranked = $false
    candidate_receipts = $candidateReceipts
    inputs = $inputs
    retained_logs = @(
        [ordered]@{
            role = "family_run"
            path = $familyLogPath
            sha256 = $familyLogSha256
        },
        [ordered]@{
            role = "selector_contract_refusal"
            path = $selectorLogPath
            sha256 = $selectorLogSha256
            exact_error = $selectorError
        }
    )
    frozen_sources = @(
        $frozenSources.Keys |
            ForEach-Object {
                [ordered]@{
                    path = $_.Replace("\", "/")
                    sha256 = [string]$frozenSources[$_]
                }
            }
    )
    immutability = [ordered]@{
        bw12e_repair_or_rerun_forbidden = $true
        failed_control_relabeling_forbidden = $true
        failed_cell_deletion_replacement_or_averaging_forbidden = $true
        threshold_relaxation_or_gate_deletion_forbidden = $true
        post_hoc_ranking_forbidden = $true
        new_successor_identity_required = $true
    }
    independent_validation_reservation_opened = $false
    cold_unbiased_friction_reservation_opened = $false
    development_selection_authority = $false
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
Write-Host "Retained BW12E negative closure: $outputPath"
Write-Host (
    "BALANCED_WAVE_BW12E_SELECTION_PERFORMED=false " +
    "FAMILY_INVALIDATED=true WORLDS=$totalWorldBuildCount/48 " +
    "CONTROL_NONZERO_WORLDS=12/12"
)
