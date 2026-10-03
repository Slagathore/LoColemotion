#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvaluationInputPath = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw29n-nuisance-transfer-61f4c1e\evaluation-input.json"
    ),
    [string]$AttemptPath = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw29n-nuisance-transfer-61f4c1e\attempt.json"
    ),
    [string]$OutputPath = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw29n-nuisance-transfer-61f4c1e\" +
        "posthoc-receipt-alias-diagnostic.json"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evaluatorPath = Join-Path $sdkRoot (
    "balanced_wave_bw29n_nuisance_transfer_gate.ps1"
)
$referenceWorkerPath = Join-Path $repoRoot (
    "tests\test_sdk_balanced_wave_bw29n_reference_worker.gd"
)
$successorWorkerPath = Join-Path $repoRoot (
    "tests\test_sdk_balanced_wave_bw29n_successor_worker.gd"
)
$supervisorPath = Join-Path $sdkRoot (
    "run_balanced_wave_bw29n_nuisance_transfer.ps1"
)
$freezePath = Join-Path $sdkRoot (
    "balanced_wave_bw29n_nuisance_transfer_freeze.json"
)

$campaignId = "BW29N-BW19V-NUISANCE-TRANSFER-DEVELOPMENT"
$sourceCommit = "61f4c1e8d275d3553443fbe48755c11dbf7ce9a5"
$attemptId = "b65fd5a35f0a49e79a89986ea897fe6a"
$materialProfileDigest = (
    "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
)
$expectedEvaluationInputSha256 = (
    "db5098745844427becfed08cf61c0658874d4cdac9d98f433c828a08d76e3426"
)
$expectedAttemptSha256 = (
    "be9ec4d5352a5afb128a6837098a9a9f42d9097fdccbf8515ebc8f96c8889594"
)
$expectedEvaluatorSha256 = (
    "0209cf04c7474ec359fd4de5d19ca1f8136afeb5bb86dfa15e7aa43e6af4deec"
)
$expectedReferenceWorkerSha256 = (
    "3e357150578b5ea70f2d9bb9ec155aa9b4100110f262408ccbe337adb6460e4f"
)
$expectedSuccessorWorkerSha256 = (
    "7116295b6130bc12eda955a12f3ff1a09dbf141f4da0afe4f19fdb6febd0df17"
)
$expectedSupervisorSha256 = (
    "b6c6e92afaeb3703697406230835b3ac099d0a5ebb6b90212b079ccfae039e84"
)
$expectedFreezeSha256 = (
    "baf921182f40219f91591b38028f36ecb1dfc8ca7fcb354ad7d06b11e298e1d6"
)
$expectedInvalidCells = [ordered]@{
    sensor_noise_s21001_bw29n_b = 2778
    sensor_noise_s21002_bw29n_b = 2762
    sensor_noise_s21003_bw29n_b = 2748
}

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Copy-JsonValue {
    param([Parameter(Mandatory)][object]$Value)
    return (
        $Value | ConvertTo-Json -Depth 100 |
            ConvertFrom-Json -AsHashtable -Depth 100
    )
}

function Write-NewUtf8Json {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    Assert-Exact (-not (Test-Path -LiteralPath $Path)) (
        "Refusing to overwrite the BW29N posthoc diagnostic: $Path"
    )
    $parent = Split-Path -Parent $Path
    Assert-Exact (
        Test-Path -LiteralPath $parent -PathType Container
    ) "BW29N posthoc diagnostic parent does not exist: $parent"
    $temporaryPath = $Path + ".tmp"
    Assert-Exact (-not (Test-Path -LiteralPath $temporaryPath)) (
        "Refusing stale BW29N diagnostic temporary path: $temporaryPath"
    )
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporaryPath -Destination $Path
}

function Test-SequenceEqual {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Actual,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Expected
    )
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index += 1) {
        if ([string]$Actual[$index] -cne [string]$Expected[$index]) {
            return $false
        }
    }
    return $true
}

function Get-CandidateSummary {
    param(
        [Parameter(Mandatory)][object[]]$Summaries,
        [Parameter(Mandatory)][string]$CandidateId
    )
    $match = @($Summaries | Where-Object {
        [string]$_.candidate_id -ceq $CandidateId
    })
    Assert-Exact ($match.Count -eq 1) (
        "Expected one BW29N candidate summary for $CandidateId"
    )
    return [System.Collections.IDictionary]$match[0]
}

$resolvedEvaluationInputPath = [System.IO.Path]::GetFullPath(
    $EvaluationInputPath
)
$resolvedAttemptPath = [System.IO.Path]::GetFullPath($AttemptPath)
$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $resolvedEvaluationInputPath)
)
Assert-Exact (
    [System.IO.Path]::GetFullPath((Split-Path -Parent $resolvedAttemptPath)) -ceq
        $evidenceRoot
) "BW29N evaluation input and attempt must share one evidence root"

foreach ($binding in @(
    @($resolvedEvaluationInputPath, $expectedEvaluationInputSha256),
    @($resolvedAttemptPath, $expectedAttemptSha256),
    @($evaluatorPath, $expectedEvaluatorSha256),
    @($referenceWorkerPath, $expectedReferenceWorkerSha256),
    @($successorWorkerPath, $expectedSuccessorWorkerSha256),
    @($supervisorPath, $expectedSupervisorSha256),
    @($freezePath, $expectedFreezeSha256)
)) {
    Assert-Exact (
        (Test-Path -LiteralPath $binding[0] -PathType Leaf) -and
        (Get-RawSha256 -Path $binding[0]) -ceq $binding[1]
    ) "BW29N posthoc input or frozen source drifted: $($binding[0])"
}

foreach ($forbiddenName in @(
    "evaluation.json",
    "report.json",
    "completion.json"
)) {
    Assert-Exact (
        -not (Test-Path -LiteralPath (Join-Path $evidenceRoot $forbiddenName))
    ) "Unexpected original BW29N aggregate artifact exists: $forbiddenName"
}

$attempt = Get-Content -Raw -LiteralPath $resolvedAttemptPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$input = Get-Content -Raw -LiteralPath $resolvedEvaluationInputPath |
    ConvertFrom-Json -AsHashtable -Depth 100

. $evaluatorPath

$expectedCellIds = @(Get-Bw29nExpectedCells | ForEach-Object {
    [string]$_.cell_id
})
$attemptCellIds = @($attempt.ordered_cell_ids | ForEach-Object { [string]$_ })
Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw29n_nuisance_transfer_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq "BW29N" -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [string]$attempt.attempt_id -ceq $attemptId -and
    [bool]$attempt.physical_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [bool]$attempt.locomotion_outcome_exposed_at_attempt -and
    -not [bool]$attempt.physical_acceptance_authority -and
    [int]$attempt.expected_world_count -eq 24 -and
    (Test-SequenceEqual -Actual $attemptCellIds -Expected $expectedCellIds)
) "BW29N retained attempt identity or one-shot state is invalid"

$receipts = @($input.cell_receipts)
Assert-Exact (
    [string]$input.schema_version -ceq
        "sporespore_balanced_wave_bw29n_nuisance_transfer_evaluation_input_v1" -and
    [string]$input.attempt_id -ceq $attemptId -and
    [string]$input.source.commit -ceq $sourceCommit -and
    [bool]$input.source.worktree_clean -and
    [bool]$input.source.matches_live_github_main -and
    $receipts.Count -eq 24
) "BW29N retained evaluation input identity or cardinality is invalid"

$receiptCellIds = @($receipts | ForEach-Object { [string]$_.cell_id })
Assert-Exact (
    (Test-SequenceEqual -Actual $receiptCellIds -Expected $expectedCellIds) -and
    @($receiptCellIds | Sort-Object -Unique).Count -eq 24
) "BW29N retained receipts are missing, duplicated, unexpected, or reordered"

$originalExceptionType = ""
$originalExceptionMessage = ""
try {
    Invoke-Bw29nNuisanceTransferEvaluation `
        -CellReceipts $receipts `
        -Source ([System.Collections.IDictionary]$input.source) `
        -AttemptId ([string]$input.attempt_id) | Out-Null
} catch {
    $originalExceptionType = $_.Exception.GetType().FullName
    $originalExceptionMessage = $_.Exception.Message
}
Assert-Exact (
    $originalExceptionType -ceq
        "System.Management.Automation.PropertyNotFoundException" -and
    $originalExceptionMessage -clike
        "The property 'material_profile_digest' cannot be found on this object.*"
) "BW29N original frozen evaluator failure did not reproduce exactly"

$candidateA = @($receipts | Where-Object {
    [string]$_.candidate_id -ceq "BW29N-A"
})
$candidateB = @($receipts | Where-Object {
    [string]$_.candidate_id -ceq "BW29N-B"
})
$aDigestPresent = @($candidateA | Where-Object {
    $_.Contains("material_profile_digest")
})
$aShaPresent = @($candidateA | Where-Object {
    $_.Contains("material_profile_sha256")
})
$bDigestPresent = @($candidateB | Where-Object {
    $_.Contains("material_profile_digest")
})
$bShaPresent = @($candidateB | Where-Object {
    $_.Contains("material_profile_sha256")
})
Assert-Exact (
    $candidateA.Count -eq 12 -and
    $candidateB.Count -eq 12 -and
    $aDigestPresent.Count -eq 12 -and
    $aShaPresent.Count -eq 0 -and
    $bDigestPresent.Count -eq 0 -and
    $bShaPresent.Count -eq 12 -and
    @($aDigestPresent | Where-Object {
        [string]$_.material_profile_digest -cne $materialProfileDigest
    }).Count -eq 0 -and
    @($bShaPresent | Where-Object {
        [string]$_.material_profile_sha256 -cne $materialProfileDigest
    }).Count -eq 0
) "BW29N observed material-profile receipt split did not reproduce exactly"

$measurementPassCount = @($receipts | Where-Object {
    [bool]$_.measurement_gate_passed
}).Count
$applicationPassCount = @($receipts | Where-Object {
    [bool]$_.application_gate_passed
}).Count
$outcomeCompleteCount = @($receipts | Where-Object {
    [bool]$_.outcome_complete
}).Count
$rolePassCount = @($receipts | Where-Object {
    [bool]$_.role_gate_passed
}).Count
$challengePassCount = @($receipts | Where-Object {
    [bool]$_.challenge_gate_passed
}).Count
$commonIntegrityPassCount = @($receipts | Where-Object {
    [bool]$_.common_execution_integrity
}).Count
Assert-Exact (
    $measurementPassCount -eq 24 -and
    $applicationPassCount -eq 24 -and
    $outcomeCompleteCount -eq 24 -and
    $rolePassCount -eq 21 -and
    $challengePassCount -eq 21 -and
    $commonIntegrityPassCount -eq 21
) "BW29N retained receipt gate counts did not reproduce exactly"

$invalidChallengeCells = @($candidateB | Where-Object {
    [string]$_.challenge_profile_id -ceq "bw6n_sensor_noise_v1" -and
    (-not [bool]$_.challenge_gate_passed)
} | Sort-Object { [string]$_.cell_id })
Assert-Exact (
    $invalidChallengeCells.Count -eq 3 -and
    (Test-SequenceEqual `
        -Actual @($invalidChallengeCells | ForEach-Object { [string]$_.cell_id }) `
        -Expected @($expectedInvalidCells.Keys))
) "BW29N invalid challenge cell identities did not reproduce exactly"

foreach ($cell in $invalidChallengeCells) {
    $cellId = [string]$cell.cell_id
    $expectedCount = [int]$expectedInvalidCells[$cellId]
    Assert-Exact (
        [int]$cell.observation_fault_application_count -eq $expectedCount -and
        [int]$cell.observation_fault_base_and_stability_count -eq
            $expectedCount -and
        [double]$cell.maximum_observation_fault_component -eq 0.02 -and
        -not [bool]$cell.challenge_gate_passed -and
        -not [bool]$cell.role_gate_passed -and
        -not [bool]$cell.common_execution_integrity -and
        [bool]$cell.measurement_gate_passed -and
        [bool]$cell.application_gate_passed -and
        [bool]$cell.outcome_complete -and
        [bool]$cell.walking_observed
    ) "BW29N invalid challenge receipt drifted: $cellId"
}

$projectedInput = Copy-JsonValue -Value $input
$aliasAdditionCount = 0
foreach ($cell in @($projectedInput.cell_receipts)) {
    if ([string]$cell.candidate_id -ceq "BW29N-B") {
        Assert-Exact (
            -not $cell.Contains("material_profile_digest") -and
            $cell.Contains("material_profile_sha256")
        ) "BW29N B-side alias projection precondition failed"
        $cell.material_profile_digest = [string]$cell.material_profile_sha256
        $aliasAdditionCount += 1
    }
}
Assert-Exact ($aliasAdditionCount -eq 12) (
    "BW29N posthoc projection did not add exactly twelve receipt aliases"
)

$projectedEvaluation = Invoke-Bw29nNuisanceTransferEvaluation `
    -CellReceipts @($projectedInput.cell_receipts) `
    -Source ([System.Collections.IDictionary]$projectedInput.source) `
    -AttemptId ([string]$projectedInput.attempt_id)
$summaryA = Get-CandidateSummary `
    -Summaries @($projectedEvaluation.candidate_summaries) `
    -CandidateId "BW29N-A"
$summaryB = Get-CandidateSummary `
    -Summaries @($projectedEvaluation.candidate_summaries) `
    -CandidateId "BW29N-B"
Assert-Exact (
    -not [bool]$projectedEvaluation.ok -and
    [string]$projectedEvaluation.status -ceq "invalid_or_incomplete" -and
    [int]$projectedEvaluation.passed_gate_count -eq 10 -and
    [int]$projectedEvaluation.failed_gate_count -eq 2 -and
    @($projectedEvaluation.failure_codes).Count -eq 2 -and
    [string]$projectedEvaluation.failure_codes[0] -ceq
        "BW29N_CHALLENGE_INVALID" -and
    [string]$projectedEvaluation.failure_codes[1] -ceq
        "BW29N_DEVELOPMENT_RESULT_INVALID" -and
    [bool]$projectedEvaluation.strict_total_improvement_passed -and
    [bool]$projectedEvaluation.per_axis_non_regression_passed -and
    [string]$projectedEvaluation.selected_candidate_id -ceq "NONE" -and
    -not [bool]$projectedEvaluation.fresh_nuisance_validation_ready -and
    -not [bool]$projectedEvaluation.walking_acceptance -and
    -not [bool]$projectedEvaluation.nuisance_acceptance -and
    -not [bool]$projectedEvaluation.release_authorized -and
    -not [bool]$projectedEvaluation.physical_acceptance_authority
) "BW29N projected frozen evaluation did not reproduce as 10/12 invalid"

Assert-Exact (
    [int]$summaryA.cell_count -eq 12 -and
    [int]$summaryA.integrity_pass_count -eq 12 -and
    [int]$summaryA.walking_pass_count -eq 9 -and
    [int]$summaryA.walking_failure_count -eq 3 -and
    [int]$summaryA.failures_by_axis.bw6n_baseline_v1 -eq 0 -and
    [int]$summaryA.failures_by_axis.bw6n_rough_v1 -eq 2 -and
    [int]$summaryA.failures_by_axis.bw6n_push_v1 -eq 1 -and
    [int]$summaryA.failures_by_axis.bw6n_sensor_noise_v1 -eq 0 -and
    [int]$summaryB.cell_count -eq 12 -and
    [int]$summaryB.integrity_pass_count -eq 9 -and
    [int]$summaryB.walking_pass_count -eq 10 -and
    [int]$summaryB.walking_failure_count -eq 2 -and
    [int]$summaryB.failures_by_axis.bw6n_baseline_v1 -eq 0 -and
    [int]$summaryB.failures_by_axis.bw6n_rough_v1 -eq 2 -and
    [int]$summaryB.failures_by_axis.bw6n_push_v1 -eq 0 -and
    [int]$summaryB.failures_by_axis.bw6n_sensor_noise_v1 -eq 0
) "BW29N projected descriptive candidate summaries did not reproduce exactly"

$invalidCellDiagnostics = @(
    foreach ($cell in $invalidChallengeCells) {
        [ordered]@{
            cell_id = [string]$cell.cell_id
            campaign_seed = [int]$cell.campaign_seed
            candidate_id = [string]$cell.candidate_id
            challenge_profile_id = [string]$cell.challenge_profile_id
            observation_fault_application_count =
                [int]$cell.observation_fault_application_count
            frozen_expected_observation_fault_application_count = 1514
            observation_fault_base_and_stability_count =
                [int]$cell.observation_fault_base_and_stability_count
            maximum_observation_fault_component =
                [double]$cell.maximum_observation_fault_component
            challenge_gate_passed = $false
            role_gate_passed = $false
            common_execution_integrity = $false
            measurement_gate_passed = $true
            application_gate_passed = $true
            outcome_complete = $true
            walking_observed_descriptive_only = $true
        }
    }
)

$diagnostic = [ordered]@{
    schema_version = (
        "sporespore_balanced_wave_bw29n_nuisance_transfer_" +
        "posthoc_receipt_alias_diagnostic_v1"
    )
    campaign_id = $campaignId
    source_commit = $sourceCommit
    attempt_id = $attemptId
    classification = (
        "posthoc_diagnostic_only_not_a_reclassification_or_selection"
    )
    retained_physical_evidence = [ordered]@{
        evidence_root = $evidenceRoot.Replace("\", "/")
        evaluation_input_path = $resolvedEvaluationInputPath.Replace("\", "/")
        evaluation_input_raw_sha256 = $expectedEvaluationInputSha256
        attempt_path = $resolvedAttemptPath.Replace("\", "/")
        attempt_raw_sha256 = $expectedAttemptSha256
        expected_world_count = 24
        parsed_receipt_count = 24
        candidate_a_receipt_count = 12
        candidate_b_receipt_count = 12
        original_evaluation_exists = $false
        original_report_exists = $false
        original_completion_exists = $false
    }
    frozen_source_bindings = [ordered]@{
        production_evaluator_raw_sha256 = $expectedEvaluatorSha256
        reference_worker_raw_sha256 = $expectedReferenceWorkerSha256
        successor_worker_raw_sha256 = $expectedSuccessorWorkerSha256
        one_shot_supervisor_raw_sha256 = $expectedSupervisorSha256
        stage_one_freeze_raw_sha256 = $expectedFreezeSha256
    }
    original_supervisor_aggregation_failure = [ordered]@{
        evaluator_exception_type = $originalExceptionType
        evaluator_exception_message = $originalExceptionMessage
        cause = (
            "Candidate A emitted material_profile_digest while candidate B " +
            "emitted material_profile_sha256; the frozen evaluator required " +
            "material_profile_digest for every receipt."
        )
        evaluator_completed = $false
        development_result_valid = $false
        selected_candidate_id = "NONE"
        development_selection_authority = $false
    }
    observed_receipt_contract_defect = [ordered]@{
        candidate_a_material_profile_digest_count = 12
        candidate_a_material_profile_sha256_count = 0
        candidate_b_material_profile_digest_count = 0
        candidate_b_material_profile_sha256_count = 12
        both_real_fields_carry_expected_profile_digest = $true
        synthetic_to_real_final_receipt_parity_defect = $true
        controller_or_adapter_outcome_reclassified = $false
    }
    observed_challenge_realization_defect = [ordered]@{
        measurement_gate_pass_count = $measurementPassCount
        application_gate_pass_count = $applicationPassCount
        outcome_complete_count = $outcomeCompleteCount
        role_gate_pass_count = $rolePassCount
        challenge_gate_pass_count = $challengePassCount
        common_execution_integrity_pass_count = $commonIntegrityPassCount
        frozen_sensor_noise_application_count = 1514
        invalid_cell_count = 3
        invalid_cells = $invalidCellDiagnostics
        candidate_independent_challenge_horizon_satisfied = $false
    }
    in_memory_alias_projection = [ordered]@{
        classification = "non_authoritative_in_memory_posthoc"
        retained_artifacts_modified = $false
        projected_field = "material_profile_digest"
        projected_from_field = "material_profile_sha256"
        projected_candidate_id = "BW29N-B"
        projected_receipt_count = $aliasAdditionCount
        any_measured_value_changed = $false
        any_walking_outcome_changed = $false
        production_evaluator_changed = $false
    }
    projected_frozen_evaluator_diagnostic = [ordered]@{
        ok = $false
        status = "invalid_or_incomplete"
        passed_gate_count = 10
        failed_gate_count = 2
        expected_gate_count = 12
        failure_codes = @(
            "BW29N_CHALLENGE_INVALID",
            "BW29N_DEVELOPMENT_RESULT_INVALID"
        )
        strict_total_improvement_passed_descriptive_only = $true
        per_axis_non_regression_passed_descriptive_only = $true
        selected_candidate_id = "NONE"
        fresh_nuisance_validation_ready = $false
        candidate_summaries_descriptive_only = @(
            [ordered]@{
                candidate_id = "BW29N-A"
                cell_count = 12
                integrity_pass_count = 12
                walking_pass_count = 9
                walking_failure_count = 3
                failures_by_axis = [ordered]@{
                    bw6n_baseline_v1 = 0
                    bw6n_rough_v1 = 2
                    bw6n_push_v1 = 1
                    bw6n_sensor_noise_v1 = 0
                }
            },
            [ordered]@{
                candidate_id = "BW29N-B"
                cell_count = 12
                integrity_pass_count = 9
                walking_pass_count = 10
                walking_failure_count = 2
                failures_by_axis = [ordered]@{
                    bw6n_baseline_v1 = 0
                    bw6n_rough_v1 = 2
                    bw6n_push_v1 = 0
                    bw6n_sensor_noise_v1 = 0
                }
            }
        )
        development_selection_authority = $false
        fresh_validation_authority = $false
        physical_acceptance_authority = $false
    }
    immutability = [ordered]@{
        status_remains_implementation_invalid = $true
        campaign_reclassified = $false
        candidate_selected = $false
        posthoc_selection_forbidden = $true
        same_identity_repair_or_rerun_forbidden = $true
        physical_identity_consumed = $true
        retained_artifacts_modified = $false
        successor_requires_distinct_campaign_source_and_evidence_identity = $true
    }
    claim_boundary = [ordered]@{
        development_result_complete = $false
        development_candidate_selected = $false
        walking_acceptance = $false
        nuisance_acceptance = $false
        rough_terrain_robustness = $false
        external_push_recovery = $false
        sensor_noise_robustness = $false
        sensor_latency_robustness = $false
        arbitrary_quadruped_coverage = $false
        continuous_full_volume_coverage = $false
        cross_engine_equivalence = $false
        release_authorized = $false
        completed_engine_neutral_sdk = $false
        physical_acceptance_authority = $false
    }
}

Write-NewUtf8Json -Value $diagnostic -Path $resolvedOutputPath
Write-Host (
    "BW29N_POSTHOC_RECEIPT_DIAGNOSTIC_PASS original=exception " +
    "projected=10/12 status=invalid_or_incomplete selector=NONE " +
    "invalid_challenge_cells=3 selection_authority=False " +
    "reclassified=False output=$resolvedOutputPath"
)
