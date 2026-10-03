#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$ReferenceReport,
    [Parameter(Mandatory = $true)]
    [string[]]$MaterialReport,
    [Parameter(Mandatory = $true)]
    [string[]]$CounterexampleReport,
    [Parameter(Mandatory = $true)]
    [string[]]$OpenedBw3rReplayReport,
    [Parameter(Mandatory = $true)]
    [string[]]$OpenedBw4ReplayReport,
    [Parameter(Mandatory = $true)]
    [string]$Output
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$preregistrationPath = Join-Path $sdkRoot "balanced_wave_bw5r_preregistration.json"
$outputPath = [System.IO.Path]::GetFullPath($Output)

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
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-SourceState {
    $status = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    Assert-Exact ($LASTEXITCODE -eq 0) "Unable to read the BW5R source worktree"
    $head = (& git -C $repoRoot rev-parse HEAD).Trim()
    Assert-Exact ($LASTEXITCODE -eq 0) "Unable to resolve BW5R source HEAD"
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    Assert-Exact ($LASTEXITCODE -eq 0) "Unable to resolve origin/main"
    return [ordered]@{
        commit = $head
        clean = $status.Count -eq 0
        matches_origin_main = $head -ceq $originMain
    }
}

function Read-BoundReport {
    param(
        [string]$Path,
        [string]$CandidateId,
        [string]$PolicyId,
        [string]$PolicyDigest,
        [string]$Role,
        [string]$SourceCommit
    )
    $resolved = [System.IO.Path]::GetFullPath($Path)
    Assert-Exact (
        Test-Path -LiteralPath $resolved -PathType Leaf
    ) "Missing $CandidateId $Role report: $resolved"
    $report = Get-Content -LiteralPath $resolved -Raw |
        ConvertFrom-Json -AsHashtable
    Assert-Exact (
        [string]$report.source_commit -ceq $SourceCommit -and
        [bool]$report.source_worktree_clean -and
        [bool]$report.source_matches_origin_main -and
        [bool]$report.development_data_only -and
        [string]$report.candidate_id -ceq $CandidateId -and
        [string]$report.candidate_policy_digest -ceq $PolicyDigest
    ) "$CandidateId $Role source or candidate identity is invalid"
    if ($report.Contains("policy_id")) {
        Assert-Exact (
            [string]$report.policy_id -ceq $PolicyId
        ) "$CandidateId $Role policy identity is invalid"
    }
    return [ordered]@{
        path = $resolved
        sha256 = Get-Sha256 $resolved
        report = $report
    }
}

function Get-FalseGateCount {
    param([System.Collections.IDictionary]$Gates)
    Assert-Exact ($null -ne $Gates) "Walking-gate receipt is missing"
    return @(
        $Gates.GetEnumerator() |
            Where-Object { -not [bool]$_.Value }
    ).Count
}

function Get-TaskFrameLateralDisplacement {
    param([System.Collections.IDictionary]$Cell)
    if ($Cell.Contains("final_task_frame_lateral_displacement_m")) {
        $reported = [double]$Cell.final_task_frame_lateral_displacement_m
        Assert-Exact (
            [double]::IsFinite($reported)
        ) "A reported task-frame lateral displacement is nonfinite"
        return $reported
    }
    $displacement = $Cell.final_torso_displacement_world_m
    Assert-Exact (
        $null -ne $displacement
    ) "A treatment is missing final torso displacement"
    $yaw = 0.0
    if ($Cell.Contains("initial_perturbation")) {
        $yaw = [double]$Cell.initial_perturbation.fixture_yaw_rad
    }
    $x = [double]$displacement.x
    $z = [double]$displacement.z
    $lateral = $x * [Math]::Sin($yaw) + $z * [Math]::Cos($yaw)
    Assert-Exact (
        [double]::IsFinite($lateral)
    ) "A derived task-frame lateral displacement is nonfinite"
    return $lateral
}

function Get-TreatmentMetrics {
    param([object[]]$Cells)
    $nonwalkCount = 0
    $walkingGateFailureCount = 0
    $maximumAbsoluteTaskFrameLateralDisplacement = 0.0
    $cumulativeAbsoluteCrossTrackError = 0.0
    foreach ($cell in $Cells) {
        if (-not [bool]$cell.walking_observed) {
            $nonwalkCount += 1
        }
        $walkingGateFailureCount += Get-FalseGateCount (
            $cell.walking_gate_receipts
        )
        $absoluteLateral = [Math]::Abs(
            (Get-TaskFrameLateralDisplacement $cell)
        )
        $maximumAbsoluteTaskFrameLateralDisplacement = [Math]::Max(
            $maximumAbsoluteTaskFrameLateralDisplacement,
            $absoluteLateral
        )
        $cellIntegral = [double]$cell.cumulative_absolute_cross_track_error_m_s
        $minimumCrossTrack = [double]$cell.minimum_cross_track_error_m
        $maximumCrossTrack = [double]$cell.maximum_cross_track_error_m
        Assert-Exact (
            [double]::IsFinite($cellIntegral) -and
            $cellIntegral -ge 0.0 -and
            [double]::IsFinite($minimumCrossTrack) -and
            [double]::IsFinite($maximumCrossTrack) -and
            $minimumCrossTrack -le $maximumCrossTrack -and
            [int]$cell.steering_feedback_update_count -eq [int]$cell.step_count -and
            [int]$cell.steering_filter_application_count -eq [int]$cell.step_count -and
            [int]$cell.steering_slew_limited_count -eq 0 -and
            [double]$cell.maximum_absolute_requested_steering_fraction -le 0.4 -and
            [double]$cell.maximum_absolute_filtered_steering_fraction -le 0.4
        ) "A BW5R treatment is missing exact filtered-feedback diagnostics"
        $cumulativeAbsoluteCrossTrackError += $cellIntegral
    }
    return [ordered]@{
        treatment_count = $Cells.Count
        nonwalk_count = $nonwalkCount
        walking_gate_failure_count = $walkingGateFailureCount
        maximum_absolute_task_frame_lateral_displacement_m =
            $maximumAbsoluteTaskFrameLateralDisplacement
        cumulative_absolute_cross_track_error_m_s =
            $cumulativeAbsoluteCrossTrackError
    }
}

Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "BW5R preregistration is missing"
Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
) "The retained BW5R selection filename must be report.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite a BW5R selection report: $outputPath"
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW5R selection directory: $outputDirectory"
}

$sourceBefore = Get-SourceState
Assert-Exact (
    [bool]$sourceBefore.clean -and [bool]$sourceBefore.matches_origin_main
) "BW5R selection requires clean source exactly matching origin/main"

$preregistration = Get-Content -LiteralPath $preregistrationPath -Raw |
    ConvertFrom-Json -AsHashtable
$expectedMetricOrder = @(
    "infrastructure_and_integrity_failure_count:ascending",
    "opened_bw4_treatment_nonwalk_count:ascending",
    "all_opened_nonzero_material_treatment_nonwalk_count:ascending",
    "opened_validation_treatment_nonwalk_count:ascending",
    "opened_counterexample_nonwalk_count:ascending",
    "aggregate_cumulative_absolute_cross_track_error_m_s:ascending",
    "maximum_absolute_task_frame_lateral_displacement_m:ascending",
    "aggregate_walking_gate_failure_count:ascending"
)
$observedMetricOrder = @(
    $preregistration.selection.lexicographic_metrics |
        ForEach-Object {
            "$([string]$_['metric']):$([string]$_['direction'])"
        }
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw5r_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw5r_physics_world" -and
    [string]::Join(",", @($preregistration.candidate_order)) -ceq
        "BW5R-A,BW5R-B,BW5R-C" -and
    [string]::Join(",", $observedMetricOrder) -ceq
        [string]::Join(",", $expectedMetricOrder) -and
    [string]$preregistration.selection.tie_rule -ceq
        "candidate_order_ascending" -and
    [string]$preregistration.selection.early_stop_rule -ceq
        "forbidden; all three candidates must complete all 58 worlds" -and
    [bool]$preregistration.selection.all_candidates_must_complete_before_selection -and
    [bool]$preregistration.selection.selection_requires_zero_opened_bw4_treatment_nonwalks -and
    [int]$preregistration.development_matrix.expected_world_count_per_candidate -eq 58 -and
    [int]$preregistration.development_matrix.expected_complete_world_count -eq 174
) "Frozen BW5R preregistration or selection order is invalid"

$candidateCount = $ReferenceReport.Count
Assert-Exact (
    $candidateCount -eq 3 -and
    $MaterialReport.Count -eq 3 -and
    $CounterexampleReport.Count -eq 3 -and
    $OpenedBw3rReplayReport.Count -eq 3 -and
    $OpenedBw4ReplayReport.Count -eq 3
) "BW5R requires exactly three complete five-report candidate sets"

$candidateScores = @()
$retainedInputs = @()
for ($index = 0; $index -lt $candidateCount; $index += 1) {
    $candidateId = [string]$preregistration.candidate_order[$index]
    $candidate = @(
        $preregistration.candidates |
            Where-Object { [string]$_['candidate_id'] -ceq $candidateId }
    )
    Assert-Exact (
        $candidate.Count -eq 1
    ) "Missing or duplicate preregistered candidate $candidateId"
    $policyId = [string]$candidate[0].policy_id
    $policyDigest =
        [string]$preregistration.candidate_policy_digests[$candidateId]

    $referenceInput = Read-BoundReport `
        -Path $ReferenceReport[$index] `
        -CandidateId $candidateId `
        -PolicyId $policyId `
        -PolicyDigest $policyDigest `
        -Role "reference" `
        -SourceCommit ([string]$sourceBefore.commit)
    $materialInput = Read-BoundReport `
        -Path $MaterialReport[$index] `
        -CandidateId $candidateId `
        -PolicyId $policyId `
        -PolicyDigest $policyDigest `
        -Role "opened_bw2_material" `
        -SourceCommit ([string]$sourceBefore.commit)
    $counterexampleInput = Read-BoundReport `
        -Path $CounterexampleReport[$index] `
        -CandidateId $candidateId `
        -PolicyId $policyId `
        -PolicyDigest $policyDigest `
        -Role "opened_counterexamples" `
        -SourceCommit ([string]$sourceBefore.commit)
    $bw3rInput = Read-BoundReport `
        -Path $OpenedBw3rReplayReport[$index] `
        -CandidateId $candidateId `
        -PolicyId $policyId `
        -PolicyDigest $policyDigest `
        -Role "opened_bw3r_replay" `
        -SourceCommit ([string]$sourceBefore.commit)
    $bw4Input = Read-BoundReport `
        -Path $OpenedBw4ReplayReport[$index] `
        -CandidateId $candidateId `
        -PolicyId $policyId `
        -PolicyDigest $policyDigest `
        -Role "opened_bw4_replay" `
        -SourceCommit ([string]$sourceBefore.commit)

    $reference = $referenceInput.report
    $material = $materialInput.report
    $counterexamples = $counterexampleInput.report
    $bw3r = $bw3rInput.report
    $bw4 = $bw4Input.report

    Assert-Exact (
        [string]$reference.schema_version -ceq
            "sporespore_balanced_wave_bw2_reference_report_v2" -and
        [string]$reference.receipt.candidate_id -ceq $candidateId -and
        [string]$reference.receipt.policy_id -ceq $policyId -and
        [int]$reference.receipt.world_count -eq 2 -and
        [int]$reference.receipt.control.step_count -eq 1514 -and
        [int]$reference.receipt.treatment.step_count -eq 1514 -and
        [int]$reference.receipt.control.native_motor_write_count -eq 0 -and
        [int]$reference.receipt.treatment.native_motor_write_count -eq 12112 -and
        [int]$reference.receipt.treatment.validated_balanced_wave_command_count -eq 12112 -and
        [int]$reference.receipt.treatment.direct_body_write_count -eq 0
    ) "$candidateId reference report contract is invalid"
    Assert-Exact (
        [string]$material.schema_version -ceq
            "sporespore_balanced_wave_bw2_material_report_v1" -and
        [string]$material.receipt.policy_id -ceq $policyId -and
        [int]$material.receipt.expected_world_count -eq 23 -and
        [int]$material.receipt.observed_world_count -eq 23 -and
        [int]$material.receipt.integrity_failure_count -eq 0 -and
        [int]$material.receipt.eligible_nonzero_treatment_count -eq 18 -and
        [int]$material.receipt.eligible_nonzero_treatment_with_nonzero_stability_count -eq 18 -and
        [int]$material.receipt.zero_friction_exact_fallback_count -eq 1 -and
        @($material.receipt.cells).Count -eq 23
    ) "$candidateId opened material report contract is invalid"
    Assert-Exact (
        [string]$counterexamples.schema_version -ceq
            "sporespore_balanced_wave_bw2_counterexample_report_v1" -and
        [string]$counterexamples.policy_id -ceq $policyId -and
        [int]$counterexamples.expected_world_count -eq 4 -and
        [int]$counterexamples.observed_world_count -eq 4 -and
        [int]$counterexamples.integrity_failure_count -eq 0 -and
        @($counterexamples.cells).Count -eq 4
    ) "$candidateId opened counterexample report contract is invalid"
    Assert-Exact (
        [string]$bw3r.schema_version -ceq
            "sporespore_balanced_wave_bw5r_opened_bw3r_replay_report_v1" -and
        [string]$bw3r.campaign_partition -ceq
            "opened_bw3r_development_replay" -and
        [bool]$bw3r.opened_validation_replay -and
        -not [bool]$bw3r.validation_data_only -and
        -not [bool]$bw3r.cold_acceptance -and
        [string]$bw3r.receipt.policy_id -ceq $policyId -and
        [string]$bw3r.receipt.candidate_policy_digest -ceq $policyDigest -and
        [bool]$bw3r.receipt.opened_validation_replay -and
        [int]$bw3r.receipt.expected_world_count -eq 12 -and
        [int]$bw3r.receipt.observed_world_count -eq 12 -and
        [int]$bw3r.receipt.expected_treatment_count -eq 9 -and
        [int]$bw3r.receipt.observed_treatment_count -eq 9 -and
        [int]$bw3r.receipt.expected_control_count -eq 3 -and
        [int]$bw3r.receipt.observed_control_count -eq 3 -and
        [int]$bw3r.receipt.expected_pair_count -eq 3 -and
        [int]$bw3r.receipt.treatment_with_nonzero_stability_count -eq 9 -and
        [int]$bw3r.receipt.integrity_failure_count -eq 0 -and
        @($bw3r.receipt.cells).Count -eq 12 -and
        [bool]$bw3r.receipt.validation_manifest.ok -and
        [bool]$bw3r.receipt.validation_manifest.replay_policy_exact -and
        -not [bool]$bw3r.walking_acceptance -and
        -not [bool]$bw3r.material_robustness
    ) "$candidateId opened BW3R replay report contract is invalid"
    Assert-Exact (
        [string]$bw4.schema_version -ceq
            "sporespore_balanced_wave_bw5r_opened_bw4_replay_report_v1" -and
        [string]$bw4.campaign_partition -ceq
            "opened_bw4_development_replay" -and
        [bool]$bw4.development_data_only -and
        -not [bool]$bw4.cold_acceptance -and
        [string]$bw4.receipt.policy_id -ceq $policyId -and
        [string]$bw4.receipt.candidate_policy_digest -ceq $policyDigest -and
        [int]$bw4.receipt.expected_world_count -eq 17 -and
        [int]$bw4.receipt.observed_world_count -eq 17 -and
        [int]$bw4.receipt.expected_treatment_count -eq 12 -and
        [int]$bw4.receipt.observed_treatment_count -eq 12 -and
        [int]$bw4.receipt.treatment_with_nonzero_stability_count -eq 12 -and
        [int]$bw4.receipt.expected_control_count -eq 4 -and
        [int]$bw4.receipt.observed_control_count -eq 4 -and
        [int]$bw4.receipt.expected_pair_count -eq 4 -and
        [int]$bw4.receipt.expected_zero_friction_safety_count -eq 1 -and
        [int]$bw4.receipt.observed_zero_friction_safety_count -eq 1 -and
        [int]$bw4.receipt.integrity_failure_count -eq 0 -and
        @($bw4.receipt.cells).Count -eq 17 -and
        [bool]$bw4.receipt.validation_manifest.ok -and
        -not [bool]$bw4.walking_acceptance -and
        -not [bool]$bw4.material_robustness
    ) "$candidateId opened BW4 replay report contract is invalid"

    $referenceTreatments = @($reference.receipt.treatment)
    $materialTreatments = @(
        $material.receipt.cells |
            Where-Object {
                [string]$_['mode'] -ceq "treatment" -and
                [double]$_['authored_friction'] -gt 0.0
            }
    )
    $counterexampleTreatments = @(
        $counterexamples.cells | ForEach-Object { $_.receipt }
    )
    $bw3rTreatments = @(
        $bw3r.receipt.cells |
            Where-Object { [string]$_['mode'] -ceq "treatment" }
    )
    $bw4Treatments = @(
        $bw4.receipt.cells |
            Where-Object {
                [string]$_['mode'] -ceq "treatment" -and
                [double]$_['authored_friction'] -gt 0.0
            }
    )
    Assert-Exact (
        $referenceTreatments.Count -eq 1 -and
        $materialTreatments.Count -eq 18 -and
        $counterexampleTreatments.Count -eq 4 -and
        $bw3rTreatments.Count -eq 9 -and
        $bw4Treatments.Count -eq 12
    ) "$candidateId treatment partitions are incomplete"

    foreach ($cell in @(
        $materialTreatments + $bw3rTreatments + $bw4Treatments
    )) {
        Assert-Exact (
            [bool]$cell.campaign_execution_gate_passed -and
            [int]$cell.direct_body_write_count -eq 0
        ) "$candidateId material treatment execution integrity is invalid"
    }
    foreach ($cell in $counterexampleTreatments) {
        Assert-Exact (
            [string]$cell.candidate_id -ceq $candidateId -and
            [string]$cell.policy_id -ceq $policyId -and
            [string]$cell.candidate_policy_digest -ceq $policyDigest -and
            [int]$cell.world_build_count -eq 1 -and
            [int]$cell.step_count -eq 1514 -and
            [int]$cell.validated_balanced_wave_command_count -eq 12112 -and
            [int]$cell.native_motor_write_count -eq 12112 -and
            [int]$cell.direct_body_write_count -eq 0
        ) "$candidateId counterexample treatment execution integrity is invalid"
    }

    $referenceMetrics = Get-TreatmentMetrics $referenceTreatments
    $materialMetrics = Get-TreatmentMetrics $materialTreatments
    $counterexampleMetrics = Get-TreatmentMetrics $counterexampleTreatments
    $bw3rMetrics = Get-TreatmentMetrics $bw3rTreatments
    $bw4Metrics = Get-TreatmentMetrics $bw4Treatments
    Assert-Exact (
        [int]$materialMetrics.nonwalk_count -eq
            [int]$material.receipt.eligible_nonzero_treatment_nonwalk_count -and
        [int]$counterexampleMetrics.nonwalk_count -eq
            [int]$counterexamples.counterexample_nonwalk_count -and
        [int]$bw3rMetrics.nonwalk_count -eq
            (9 - [int]$bw3r.receipt.observed_treatment_pass_count) -and
        [int]$bw4Metrics.nonwalk_count -eq
            (12 - [int]$bw4.receipt.observed_treatment_pass_count)
    ) "$candidateId published outcome counts do not recompute"

    $integrityFailureCount = (
        [int]$material.receipt.integrity_failure_count +
        [int]$counterexamples.integrity_failure_count +
        [int]$bw3r.receipt.integrity_failure_count +
        [int]$bw4.receipt.integrity_failure_count +
        (3 - [int]$bw3r.receipt.observed_control_pass_count) +
        (3 - [int]$bw3r.receipt.observed_pair_pass_count) +
        (4 - [int]$bw4.receipt.observed_control_pass_count) +
        (4 - [int]$bw4.receipt.observed_pair_pass_count) +
        (1 - [int]$bw4.receipt.observed_zero_friction_safety_pass_count)
    )
    $allOpenedNonzeroMaterialNonwalkCount = (
        [int]$materialMetrics.nonwalk_count +
        [int]$bw3rMetrics.nonwalk_count +
        [int]$bw4Metrics.nonwalk_count
    )
    $aggregateWalkingGateFailureCount = (
        [int]$referenceMetrics.walking_gate_failure_count +
        [int]$materialMetrics.walking_gate_failure_count +
        [int]$counterexampleMetrics.walking_gate_failure_count +
        [int]$bw3rMetrics.walking_gate_failure_count +
        [int]$bw4Metrics.walking_gate_failure_count
    )
    $aggregateCumulativeAbsoluteCrossTrackError = (
        [double]$referenceMetrics.cumulative_absolute_cross_track_error_m_s +
        [double]$materialMetrics.cumulative_absolute_cross_track_error_m_s +
        [double]$counterexampleMetrics.cumulative_absolute_cross_track_error_m_s +
        [double]$bw3rMetrics.cumulative_absolute_cross_track_error_m_s +
        [double]$bw4Metrics.cumulative_absolute_cross_track_error_m_s
    )
    $maximumAbsoluteTaskFrameLateralDisplacement = @(
        [double]$referenceMetrics.maximum_absolute_task_frame_lateral_displacement_m
        [double]$materialMetrics.maximum_absolute_task_frame_lateral_displacement_m
        [double]$counterexampleMetrics.maximum_absolute_task_frame_lateral_displacement_m
        [double]$bw3rMetrics.maximum_absolute_task_frame_lateral_displacement_m
        [double]$bw4Metrics.maximum_absolute_task_frame_lateral_displacement_m
    ) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

    $candidateScores += [PSCustomObject][ordered]@{
        candidate_id = $candidateId
        policy_id = $policyId
        candidate_policy_digest = $policyDigest
        complete_matrix = $true
        eligible = $integrityFailureCount -eq 0
        observed_world_count = 58
        scored_treatment_world_count = 44
        infrastructure_and_integrity_failure_count = $integrityFailureCount
        opened_bw4_treatment_nonwalk_count = [int]$bw4Metrics.nonwalk_count
        all_opened_nonzero_material_treatment_nonwalk_count =
            $allOpenedNonzeroMaterialNonwalkCount
        opened_validation_treatment_nonwalk_count =
            [int]$bw3rMetrics.nonwalk_count
        opened_counterexample_nonwalk_count =
            [int]$counterexampleMetrics.nonwalk_count
        reference_treatment_nonwalk_count =
            [int]$referenceMetrics.nonwalk_count
        aggregate_cumulative_absolute_cross_track_error_m_s =
            $aggregateCumulativeAbsoluteCrossTrackError
        maximum_absolute_task_frame_lateral_displacement_m =
            [double]$maximumAbsoluteTaskFrameLateralDisplacement
        aggregate_walking_gate_failure_count =
            $aggregateWalkingGateFailureCount
        opened_bw4_zero_nonwalk_requirement_passed =
            [int]$bw4Metrics.nonwalk_count -eq 0
    }

    $roleInputs = [ordered]@{
        reference = $referenceInput
        opened_bw2_material = $materialInput
        opened_counterexamples = $counterexampleInput
        opened_bw3r_replay = $bw3rInput
        opened_bw4_replay = $bw4Input
    }
    foreach ($roleInput in $roleInputs.GetEnumerator()) {
        $retainedInputs += [ordered]@{
            candidate_id = $candidateId
            role = [string]$roleInput.Key
            path = [string]$roleInput.Value.path
            sha256 = [string]$roleInput.Value.sha256
            schema_version = [string]$roleInput.Value.report.schema_version
            source_commit = [string]$roleInput.Value.report.source_commit
        }
    }
}

$contenders = @(
    $candidateScores |
        Where-Object {
            [bool]$_.eligible -and
            [bool]$_.opened_bw4_zero_nonwalk_requirement_passed
        }
)
$familyRejected = $contenders.Count -eq 0
$selectedCandidate = $null
$decidingMetric = ""
if (-not $familyRejected) {
    foreach ($metric in @(
        "infrastructure_and_integrity_failure_count",
        "opened_bw4_treatment_nonwalk_count",
        "all_opened_nonzero_material_treatment_nonwalk_count",
        "opened_validation_treatment_nonwalk_count",
        "opened_counterexample_nonwalk_count",
        "aggregate_cumulative_absolute_cross_track_error_m_s",
        "maximum_absolute_task_frame_lateral_displacement_m",
        "aggregate_walking_gate_failure_count"
    )) {
        $minimum = (
            $contenders |
                Measure-Object -Property $metric -Minimum
        ).Minimum
        $next = @(
            $contenders |
                Where-Object { [double]($_.$metric) -eq [double]$minimum }
        )
        if ($next.Count -lt $contenders.Count) {
            $decidingMetric = $metric
        }
        $contenders = $next
        if ($contenders.Count -eq 1) {
            break
        }
    }
    $selectedCandidate = $contenders[0]
    if ([string]::IsNullOrWhiteSpace($decidingMetric)) {
        $decidingMetric = "candidate_order_ascending"
    }
}

$sourceAfter = Get-SourceState
Assert-Exact (
    [bool]$sourceAfter.clean -and
    [bool]$sourceAfter.matches_origin_main -and
    [string]$sourceAfter.commit -ceq [string]$sourceBefore.commit
) "Source changed while compiling BW5R selection"

[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$sourcePaths = [ordered]@{
    preregistration = "sdk/balanced_wave_bw5r_preregistration.json"
    compiler = "sdk/compile_balanced_wave_bw5r_selection.ps1"
    orchestrator = "sdk/run_balanced_wave_bw5r_development.ps1"
    controller = "sdk/core/src/controller.rs"
    runtime = "sdk/core/src/runtime.rs"
    protocol = "sdk/core/src/protocol.rs"
    physical_rig = "scripts/lab/gait/physical_wave_gait_quadruped.gd"
    godot_adapter = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
    authority_contract = "tests/test_sdk_balanced_wave_bw5r_authority_contract.gd"
    material_test = "tests/test_sdk_godot_jolt_material_robustness.gd"
}
$sources = [ordered]@{}
foreach ($entry in $sourcePaths.GetEnumerator()) {
    $absolutePath = Join-Path $repoRoot $entry.Value
    $sources[$entry.Key] = [ordered]@{
        path = $entry.Value
        sha256 = Get-Sha256 $absolutePath
    }
}
$report = [ordered]@{
    schema_version = "sporespore_balanced_wave_bw5r_selection_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = [string]$sourceBefore.commit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    accepted = $true
    result_status = $(if ($familyRejected) {
        "candidate_family_rejected"
    } else {
        "selection_integrity_accepted"
    })
    development_data_only = $true
    preregistration_sha256 = Get-Sha256 $preregistrationPath
    input_report_count = $retainedInputs.Count
    candidate_count = $candidateScores.Count
    expected_world_count = 174
    observed_world_count = (
        $candidateScores |
            Measure-Object -Property observed_world_count -Sum
    ).Sum
    complete_matrix_per_candidate = $true
    early_stop_forbidden = $true
    early_stop_triggered = $false
    candidate_order = @($preregistration.candidate_order)
    candidate_scores = $candidateScores
    task_frame_lateral_metric = (
        "Each scored treatment uses the retained task-frame lateral value; " +
        "legacy receipts without the explicit field are reconstructed as " +
        "dx*sin(fixture_yaw)+dz*cos(fixture_yaw)."
    )
    all_opened_nonzero_material_metric = (
        "Sum of nonwalks in the 18 opened BW2 material treatments, " +
        "9 opened BW3R treatments, and 12 opened BW4 treatments."
    )
    aggregate_cumulative_absolute_cross_track_error_metric = (
        "Sum of per-world integral(abs(task-frame cross-track error), dt) " +
        "over all 44 scored treatment worlds."
    )
    family_rejected = $familyRejected
    family_rejection_reason = $(if ($familyRejected) {
        "No complete integrity-eligible candidate had zero opened-BW4 treatment nonwalks."
    } else {
        ""
    })
    selection_mode = $(if ($familyRejected) {
        "reject_family"
    } else {
        "complete_preregistered_lexicographic_selection"
    })
    deciding_metric = $decidingMetric
    selected_candidate_id = $(if ($familyRejected) {
        $null
    } else {
        [string]$selectedCandidate.candidate_id
    })
    selected_policy_id = $(if ($familyRejected) {
        $null
    } else {
        [string]$selectedCandidate.policy_id
    })
    selected_candidate_policy_digest = $(if ($familyRejected) {
        $null
    } else {
        [string]$selectedCandidate.candidate_policy_digest
    })
    selected_implementation_must_be_committed_before_new_characterization_or_validation =
        $true
    genuinely_new_validation_required = $true
    new_cold_material_acceptance_required = $true
    development_selection_authority = -not $familyRejected
    walking_acceptance = $false
    material_robustness = $false
    arbitrary_material_robustness = $false
    continuous_friction_coverage = $false
    balance_improvement = $false
    physical_balance_recovery = $false
    rough_terrain_robustness = $false
    external_push_recovery = $false
    sensor_fault_robustness = $false
    arbitrary_quadruped_coverage = $false
    continuous_full_volume_coverage = $false
    cross_engine_c6 = $false
    completed_engine_neutral_sdk = $false
    physical_acceptance_authority = $false
    inputs = $retainedInputs
    sources = $sources
}
$temporaryPath = "$outputPath.tmp"
$json = $report | ConvertTo-Json -Depth 64
[System.IO.File]::WriteAllText(
    $temporaryPath,
    "$json`n",
    [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::Move($temporaryPath, $outputPath, $false)

Write-Host "Retained BW5R selection report: $outputPath"
if ($familyRejected) {
    Write-Host (
        "BALANCED_WAVE_BW5R_SELECTION_INTEGRITY=true " +
        "WORLDS=$($report.observed_world_count) FAMILY_REJECTED=true"
    )
} else {
    Write-Host (
        "BALANCED_WAVE_BW5R_SELECTION_INTEGRITY=true " +
        "WORLDS=$($report.observed_world_count) " +
        "SELECTED=$($report.selected_candidate_id) " +
        "DECIDING_METRIC=$($report.deciding_metric)"
    )
}
