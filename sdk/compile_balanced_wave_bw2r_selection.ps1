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
    [string[]]$OpenedBw3ReplayReport,
    [Parameter(Mandatory = $true)]
    [string]$Output
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$preregistrationPath = Join-Path $sdkRoot "balanced_wave_bw2r_preregistration.json"
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

function Get-FalseGateCount {
    param([System.Collections.IDictionary]$Gates)
    Assert-Exact ($null -ne $Gates) "Walking-gate receipt is missing"
    return @(
        $Gates.GetEnumerator() |
            Where-Object { -not [bool]$_.Value }
    ).Count
}

function Get-SourceState {
    $status = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    Assert-Exact ($LASTEXITCODE -eq 0) "Unable to read the source worktree"
    $head = (& git -C $repoRoot rev-parse HEAD).Trim()
    Assert-Exact ($LASTEXITCODE -eq 0) "Unable to resolve HEAD"
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

Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "BW2R preregistration is missing"
Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
) "The retained BW2R selection filename must be report.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite a BW2R selection report: $outputPath"
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW2R selection directory: $outputDirectory"
}

$sourceBefore = Get-SourceState
Assert-Exact (
    [bool]$sourceBefore.clean -and [bool]$sourceBefore.matches_origin_main
) "BW2R selection requires clean source exactly matching origin/main"

$preregistration = Get-Content -LiteralPath $preregistrationPath -Raw |
    ConvertFrom-Json -AsHashtable
$expectedMetricOrder = @(
    "infrastructure_and_integrity_failure_count:ascending",
    "opened_bw3_treatment_nonwalk_count:ascending",
    "eligible_nonzero_material_treatment_nonwalk_count:ascending",
    "opened_counterexample_nonwalk_count:ascending",
    "reference_treatment_nonwalk_count:ascending",
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
        "sporespore_balanced_wave_bw2r_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw2r_physics_world" -and
    [string]::Join(",", @($preregistration.candidate_order)) -ceq
        "BW2R-A,BW2R-B,BW2R-C" -and
    [string]::Join(",", $observedMetricOrder) -ceq
        [string]::Join(",", $expectedMetricOrder) -and
    [string]$preregistration.selection.tie_rule -ceq
        "candidate_order_ascending" -and
    [bool]$preregistration.selection.selected_implementation_must_be_committed_before_new_validation -and
    [int]$preregistration.physics_matrix.total_world_count_per_opened_candidate -eq 41
) "Frozen BW2R preregistration or selection order is invalid"

$candidateCount = $ReferenceReport.Count
Assert-Exact (
    $candidateCount -ge 1 -and
    $candidateCount -le 3 -and
    $MaterialReport.Count -eq $candidateCount -and
    $CounterexampleReport.Count -eq $candidateCount -and
    $OpenedBw3ReplayReport.Count -eq $candidateCount
) "BW2R requires one to three complete candidate report quartets"

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
        -Role "material" `
        -SourceCommit ([string]$sourceBefore.commit)
    $counterexampleInput = Read-BoundReport `
        -Path $CounterexampleReport[$index] `
        -CandidateId $candidateId `
        -PolicyId $policyId `
        -PolicyDigest $policyDigest `
        -Role "counterexamples" `
        -SourceCommit ([string]$sourceBefore.commit)
    $replayInput = Read-BoundReport `
        -Path $OpenedBw3ReplayReport[$index] `
        -CandidateId $candidateId `
        -PolicyId $policyId `
        -PolicyDigest $policyDigest `
        -Role "opened_bw3_replay" `
        -SourceCommit ([string]$sourceBefore.commit)

    $reference = $referenceInput.report
    $material = $materialInput.report
    $counterexamples = $counterexampleInput.report
    $replay = $replayInput.report
    Assert-Exact (
        [string]$reference.schema_version -ceq
            "sporespore_balanced_wave_bw2_reference_report_v2" -and
        [bool]$reference.accepted -and
        [string]$reference.result_status -ceq "integrity_accepted" -and
        [string]$reference.receipt.policy_id -ceq $policyId -and
        [int]$reference.receipt.world_count -eq 2 -and
        [int]$reference.receipt.passed_gate_count -eq 20 -and
        [int]$reference.receipt.failed_gate_count -eq 0 -and
        [int]$reference.receipt.treatment.step_count -eq 1514 -and
        [int]$reference.receipt.treatment.validated_balanced_wave_command_count -eq 12112 -and
        [int]$reference.receipt.treatment.native_motor_write_count -eq 12112 -and
        [int]$reference.receipt.treatment.direct_body_write_count -eq 0
    ) "$candidateId reference report contract is invalid"
    Assert-Exact (
        [string]$material.schema_version -ceq
            "sporespore_balanced_wave_bw2_material_report_v1" -and
        [bool]$material.accepted -and
        [string]$material.result_status -ceq "integrity_accepted" -and
        [string]$material.receipt.policy_id -ceq $policyId -and
        [int]$material.receipt.expected_world_count -eq 23 -and
        [int]$material.receipt.observed_world_count -eq 23 -and
        [int]$material.receipt.passed_gate_count -eq 30 -and
        [int]$material.receipt.failed_gate_count -eq 0 -and
        [int]$material.receipt.integrity_failure_count -eq 0 -and
        [int]$material.receipt.eligible_nonzero_treatment_count -eq 18 -and
        [int]$material.receipt.eligible_nonzero_treatment_with_nonzero_stability_count -eq 18 -and
        [int]$material.receipt.zero_friction_exact_fallback_count -eq 1 -and
        @($material.receipt.cells).Count -eq 23
    ) "$candidateId material report contract is invalid"
    Assert-Exact (
        [string]$counterexamples.schema_version -ceq
            "sporespore_balanced_wave_bw2_counterexample_report_v1" -and
        [bool]$counterexamples.accepted -and
        [string]$counterexamples.result_status -ceq "integrity_accepted" -and
        [string]$counterexamples.policy_id -ceq $policyId -and
        [int]$counterexamples.expected_world_count -eq 4 -and
        [int]$counterexamples.observed_world_count -eq 4 -and
        [int]$counterexamples.integrity_failure_count -eq 0 -and
        @($counterexamples.cells).Count -eq 4
    ) "$candidateId counterexample report contract is invalid"
    Assert-Exact (
        [string]$replay.schema_version -ceq
            "sporespore_balanced_wave_bw2r_opened_bw3_replay_report_v1" -and
        [bool]$replay.opened_validation_replay -and
        -not [bool]$replay.validation_data_only -and
        -not [bool]$replay.cold_acceptance -and
        [string]$replay.receipt.policy_id -ceq $policyId -and
        [string]$replay.receipt.candidate_policy_digest -ceq $policyDigest -and
        [bool]$replay.receipt.opened_validation_replay -and
        -not [bool]$replay.receipt.validation_data_only -and
        [int]$replay.receipt.expected_world_count -eq 12 -and
        [int]$replay.receipt.observed_world_count -eq 12 -and
        [int]$replay.receipt.expected_treatment_count -eq 9 -and
        [int]$replay.receipt.observed_treatment_count -eq 9 -and
        [int]$replay.receipt.expected_control_count -eq 3 -and
        [int]$replay.receipt.observed_control_count -eq 3 -and
        [int]$replay.receipt.observed_control_pass_count -eq 3 -and
        [int]$replay.receipt.expected_pair_count -eq 3 -and
        [int]$replay.receipt.observed_pair_pass_count -eq 3 -and
        [int]$replay.receipt.treatment_with_nonzero_stability_count -eq 9 -and
        [int]$replay.receipt.integrity_failure_count -eq 0 -and
        @($replay.receipt.cells).Count -eq 12 -and
        [bool]$replay.receipt.validation_manifest.ok -and
        [bool]$replay.receipt.validation_manifest.replay_policy_exact
    ) "$candidateId opened BW3 replay report contract is invalid"

    $eligibleMaterialCells = @(
        $material.receipt.cells |
            Where-Object {
                [string]$_['mode'] -ceq "treatment" -and
                [double]$_['authored_friction'] -gt 0.0
            }
    )
    $materialNonwalkCount = @(
        $eligibleMaterialCells |
            Where-Object { -not [bool]$_['walking_observed'] }
    ).Count
    $materialWalkingGateFailureCount = 0
    foreach ($cell in $eligibleMaterialCells) {
        Assert-Exact (
            [bool]$cell.campaign_execution_gate_passed -and
            [int]$cell.direct_body_write_count -eq 0
        ) "$candidateId material-cell execution integrity is invalid"
        $materialWalkingGateFailureCount += Get-FalseGateCount (
            $cell.walking_gate_receipts
        )
    }
    Assert-Exact (
        $materialNonwalkCount -eq
            [int]$material.receipt.eligible_nonzero_treatment_nonwalk_count
    ) "$candidateId material score does not recompute"

    $counterexampleNonwalkCount = 0
    $counterexampleWalkingGateFailureCount = 0
    foreach ($cellResult in @($counterexamples.cells)) {
        $receipt = $cellResult.receipt
        Assert-Exact (
            [bool]$receipt.ok -and
            [string]$receipt.candidate_id -ceq $candidateId -and
            [string]$receipt.policy_id -ceq $policyId -and
            [string]$receipt.candidate_policy_digest -ceq $policyDigest -and
            [int]$receipt.world_build_count -eq 1 -and
            [int]$receipt.step_count -eq 1514 -and
            [int]$receipt.validated_balanced_wave_command_count -eq 12112 -and
            [int]$receipt.native_motor_write_count -eq 12112 -and
            [int]$receipt.direct_body_write_count -eq 0
        ) "$candidateId counterexample-cell integrity is invalid"
        if (-not [bool]$receipt.walking_observed) {
            $counterexampleNonwalkCount += 1
        }
        $counterexampleWalkingGateFailureCount += Get-FalseGateCount (
            $receipt.walking_gate_receipts
        )
    }
    Assert-Exact (
        $counterexampleNonwalkCount -eq
            [int]$counterexamples.counterexample_nonwalk_count
    ) "$candidateId counterexample score does not recompute"

    $replayTreatmentCells = @(
        $replay.receipt.cells |
            Where-Object { [string]$_['mode'] -ceq "treatment" }
    )
    $openedBw3TreatmentNonwalkCount = @(
        $replayTreatmentCells |
            Where-Object { -not [bool]$_['walking_observed'] }
    ).Count
    $replayWalkingGateFailureCount = 0
    foreach ($cell in $replayTreatmentCells) {
        Assert-Exact (
            [bool]$cell.campaign_execution_gate_passed -and
            [int]$cell.direct_body_write_count -eq 0
        ) "$candidateId opened-BW3 treatment execution integrity is invalid"
        $replayWalkingGateFailureCount += Get-FalseGateCount (
            $cell.walking_gate_receipts
        )
    }
    Assert-Exact (
        $openedBw3TreatmentNonwalkCount -eq
            (9 - [int]$replay.receipt.observed_treatment_pass_count)
    ) "$candidateId opened-BW3 replay score does not recompute"

    $referenceNonwalkCount = if (
        [bool]$reference.receipt.treatment.walking_observed
    ) { 0 } else { 1 }
    $referenceWalkingGateFailureCount = Get-FalseGateCount (
        $reference.receipt.treatment.walking_gate_receipts
    )
    $integrityFailureCount = (
        [int]$reference.receipt.failed_gate_count +
        [int]$material.receipt.integrity_failure_count +
        [int]$counterexamples.integrity_failure_count +
        [int]$replay.receipt.integrity_failure_count
    )
    $aggregateWalkingGateFailureCount = (
        $referenceWalkingGateFailureCount +
        $materialWalkingGateFailureCount +
        $counterexampleWalkingGateFailureCount +
        $replayWalkingGateFailureCount
    )
    $earlyStopEligible = (
        $integrityFailureCount -eq 0 -and
        $openedBw3TreatmentNonwalkCount -eq 0 -and
        $materialNonwalkCount -le 1 -and
        $counterexampleNonwalkCount -eq 0 -and
        $referenceNonwalkCount -eq 0
    )
    $candidateScores += [PSCustomObject][ordered]@{
        candidate_id = $candidateId
        policy_id = $policyId
        candidate_policy_digest = $policyDigest
        eligible = $integrityFailureCount -eq 0
        observed_world_count = 41
        infrastructure_and_integrity_failure_count = $integrityFailureCount
        opened_bw3_treatment_nonwalk_count =
            $openedBw3TreatmentNonwalkCount
        eligible_nonzero_material_treatment_nonwalk_count =
            $materialNonwalkCount
        opened_counterexample_nonwalk_count = $counterexampleNonwalkCount
        reference_treatment_nonwalk_count = $referenceNonwalkCount
        aggregate_walking_gate_failure_count =
            $aggregateWalkingGateFailureCount
        early_stop_eligible = $earlyStopEligible
    }

    $roleInputs = [ordered]@{
        reference = $referenceInput
        material = $materialInput
        counterexamples = $counterexampleInput
        opened_bw3_replay = $replayInput
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

$earlyStopCandidate = @(
    $candidateScores |
        Where-Object { [bool]$_.early_stop_eligible } |
        Select-Object -First 1
)
$selectedCandidate = $null
$selectionMode = ""
$decidingMetric = ""
if ($earlyStopCandidate.Count -eq 1) {
    $selectedCandidate = $earlyStopCandidate[0]
    $selectionMode = "early_stop"
    $decidingMetric = "early_stop_rule"
} else {
    Assert-Exact (
        $candidateCount -eq 3
    ) "NEXT_BW2R_CANDIDATE_REQUIRED"
    $contenders = @(
        $candidateScores | Where-Object { [bool]$_.eligible }
    )
    Assert-Exact (
        $contenders.Count -gt 0
    ) "No BW2R candidate retained execution integrity"
    foreach ($metric in @(
        "infrastructure_and_integrity_failure_count",
        "opened_bw3_treatment_nonwalk_count",
        "eligible_nonzero_material_treatment_nonwalk_count",
        "opened_counterexample_nonwalk_count",
        "reference_treatment_nonwalk_count",
        "aggregate_walking_gate_failure_count"
    )) {
        $minimum = (
            $contenders |
                Measure-Object -Property $metric -Minimum
        ).Minimum
        $next = @(
            $contenders |
                Where-Object { [int]($_.$metric) -eq [int]$minimum }
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
    $selectionMode = "best_eligible_after_bw2r_c"
}

$sourceAfter = Get-SourceState
Assert-Exact (
    [bool]$sourceAfter.clean -and
    [bool]$sourceAfter.matches_origin_main -and
    [string]$sourceAfter.commit -ceq [string]$sourceBefore.commit
) "Source changed while compiling BW2R selection"

[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$sourcePaths = [ordered]@{
    preregistration = "sdk/balanced_wave_bw2r_preregistration.json"
    compiler = "sdk/compile_balanced_wave_bw2r_selection.ps1"
    controller = "sdk/core/src/controller.rs"
    runtime = "sdk/core/src/runtime.rs"
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
    schema_version = "sporespore_balanced_wave_bw2r_selection_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = [string]$sourceBefore.commit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    accepted = $true
    result_status = "selection_integrity_accepted"
    development_data_only = $true
    preregistration_sha256 = Get-Sha256 $preregistrationPath
    input_report_count = $retainedInputs.Count
    candidate_count = $candidateScores.Count
    expected_world_count = 41 * $candidateScores.Count
    observed_world_count = (
        $candidateScores |
            Measure-Object -Property observed_world_count -Sum
    ).Sum
    candidate_order = @(
        $preregistration.candidate_order |
            Select-Object -First $candidateScores.Count
    )
    candidate_scores = $candidateScores
    early_stop_triggered = $selectionMode -ceq "early_stop"
    selection_mode = $selectionMode
    deciding_metric = $decidingMetric
    selected_candidate_id = [string]$selectedCandidate.candidate_id
    selected_policy_id = [string]$selectedCandidate.policy_id
    selected_candidate_policy_digest =
        [string]$selectedCandidate.candidate_policy_digest
    selected_implementation_must_be_committed_before_new_validation = $true
    old_bw3_reclassified_as_development = $true
    genuinely_new_validation_required = $true
    development_selection_authority = $true
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

Write-Host "Retained BW2R selection report: $outputPath"
Write-Host (
    "BALANCED_WAVE_BW2R_SELECTION_INTEGRITY=true " +
    "WORLDS=$($report.observed_world_count) " +
    "SELECTED=$($report.selected_candidate_id) " +
    "DECIDING_METRIC=$($report.deciding_metric)"
)
