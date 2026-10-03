#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$RawResultPath = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw22l-lateral-development-0b18830\raw-result.json"
    ),
    [string]$OutputPath = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw22l-lateral-development-0b18830\" +
        "posthoc-receipt-shape-diagnostic.json"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$gatePath = Join-Path $sdkRoot "balanced_wave_bw22l_lateral_development_gate.ps1"
$workerPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw22l_lateral_development.gd"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw22l_lateral_development_preregistration.json"
$expectedRawResultSha256 =
    "f4146b04b8cf282116d3b80650715d1d069e99d28c08b36150b20daefcfba983"
$expectedGateSha256 =
    "26ba0536bb8583af171f8c0b8126fdeaabf8889d5eaa94597a17bf69e1159d65"
$expectedWorkerSha256 =
    "626776241e337d3fd22f7df3922f75b5b398742342a3c9f05ff8a9c237762460"
$expectedPreregistrationSha256 =
    "2688945b7953c52ae049990868ef15c1e0efce06dd32f78ba6526e7459ab8d4b"
$campaignId = "BW22L-FRESH-MATERIAL-LATERAL-DEVELOPMENT"
$sourceCommit = "0b1883070d05c235609284ab07460233b91a208b"
$decisionWalkingKeys = @(
    "bounded_lateral_drift",
    "bounded_tilt",
    "minimum_final_forward_translation",
    "native_sdk_exclusive_post_settle_actuation"
)

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
        "Refusing to overwrite the BW22L posthoc diagnostic: $Path"
    )
    $parent = Split-Path -Parent $Path
    Assert-Exact (
        Test-Path -LiteralPath $parent -PathType Container
    ) "BW22L posthoc diagnostic parent does not exist: $parent"
    $temporaryPath = $Path + ".tmp"
    Assert-Exact (-not (Test-Path -LiteralPath $temporaryPath)) (
        "Refusing stale BW22L diagnostic temporary path: $temporaryPath"
    )
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporaryPath -Destination $Path
}

$resolvedRawResultPath = [System.IO.Path]::GetFullPath($RawResultPath)
$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
foreach ($binding in @(
    @($resolvedRawResultPath, $expectedRawResultSha256),
    @($gatePath, $expectedGateSha256),
    @($workerPath, $expectedWorkerSha256),
    @($preregistrationPath, $expectedPreregistrationSha256)
)) {
    Assert-Exact (
        (Test-Path -LiteralPath $binding[0] -PathType Leaf) -and
        (Get-RawSha256 -Path $binding[0]) -ceq $binding[1]
    ) "BW22L posthoc input drifted: $($binding[0])"
}

. $gatePath

$rawResult = Get-Content -Raw -LiteralPath $resolvedRawResultPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$rawResult.campaign_id -ceq $campaignId -and
    [string]$rawResult.source.commit -ceq $sourceCommit -and
    [int]$rawResult.expected_world_count -eq 28 -and
    [int]$rawResult.observed_world_count -eq 28 -and
    [int]$rawResult.integrity_failure_count -eq 0 -and
    @($rawResult.cells).Count -eq 28
) "BW22L retained raw result identity or cardinality is invalid"

$originalEvaluation = Invoke-Bw22lLateralDevelopmentEvaluation -Result $rawResult
Assert-Exact (
    -not [bool]$originalEvaluation.ok -and
    [int]$originalEvaluation.reconstructed_passed_gate_count -eq 21 -and
    [int]$originalEvaluation.reconstructed_failed_gate_count -eq 29 -and
    @($originalEvaluation.failure_codes) -join "," -ceq
        "BW22L_CELL_GATE,BW22L_CANDIDATE_OUTCOME_METRICS" -and
    [string]$originalEvaluation.selected_candidate_id -ceq "NONE" -and
    -not [bool]$originalEvaluation.development_selection_authority
) "BW22L frozen invalid evaluation did not reproduce exactly"

$nonSafetyCells = @($rawResult.cells | Where-Object {
    [string]$_.role -cne "safety"
})
$fullWalkingReceiptKeyCounts = @(
    $nonSafetyCells |
        ForEach-Object { [int]$_.walking_gate_receipts.Count } |
        Sort-Object -Unique
)
$missingControllerCoefficientCount = @($rawResult.cells | Where-Object {
    -not $_.Contains("controller_coefficient")
}).Count
$safetyCell = @($rawResult.cells | Where-Object {
    [string]$_.role -ceq "safety"
}) | Select-Object -First 1
$missingSafetyFields = @(
    "controller_coefficient",
    "declared_controller_policy_id",
    "controller_runtime_profile_sha256",
    "proportional_factor",
    "velocity_factor",
    "seed_condition_count",
    "failure_identity_condition_count",
    "outcome_condition_count",
    "failed_production_walking_gate_count"
) | Where-Object { -not $safetyCell.Contains($_) }

Assert-Exact (
    $nonSafetyCells.Count -eq 27 -and
    $fullWalkingReceiptKeyCounts.Count -eq 1 -and
    [int]$fullWalkingReceiptKeyCounts[0] -eq 26 -and
    $missingControllerCoefficientCount -eq 28 -and
    $missingSafetyFields.Count -eq 9 -and
    [string]$safetyCell.material_profile_id -ceq
        "godot_jolt_p5m1r1_mu000_v1" -and
    [string]$safetyCell.candidate_id -ceq "NONE"
) "BW22L observed receipt-shape defects did not reproduce exactly"

$reconstructedResult = Copy-JsonValue -Value $rawResult
$expectedCells = @(Get-Bw22lExpectedCells)
for ($index = 0; $index -lt $reconstructedResult.cells.Count; $index += 1) {
    $cell = $reconstructedResult.cells[$index]
    $expected = $expectedCells[$index]
    $cell.controller_coefficient = [double]$expected.controller_coefficient
    if ([string]$cell.role -cne "safety") {
        $projected = [ordered]@{}
        foreach ($key in $decisionWalkingKeys) {
            $projected[$key] = [bool]$cell.walking_gate_receipts[$key]
        }
        $failedCount = @($decisionWalkingKeys | Where-Object {
            -not [bool]$projected[$_]
        }).Count
        $cell.walking_gate_receipts = $projected
        $cell.failed_production_walking_gate_count = $failedCount
        $cell.walking_observed = $failedCount -eq 0
        continue
    }
    $cell.material_profile_id = [string]$expected.profile_id
    $cell.material_profile_sha256 = [string]$expected.profile_digest
    $cell.candidate_id = [string]$expected.candidate_id
    $cell.candidate_composition_digest = [string]$expected.composition_digest
    $cell.controller_policy_id = [string]$expected.policy_id
    $cell.declared_controller_policy_id = [string]$expected.policy_id
    $cell.controller_runtime_profile_sha256 =
        [string]$expected.runtime_profile_sha256
    $cell.proportional_factor = [double]$expected.proportional_factor
    $cell.velocity_factor = [double]$expected.velocity_factor
    $cell.seed_condition_count = 0
    $cell.failure_identity_condition_count = 0
    $cell.outcome_condition_count = 0
    $cell.failed_production_walking_gate_count = 0
}

$reconstructedEvaluation = Invoke-Bw22lLateralDevelopmentEvaluation `
    -Result $reconstructedResult
Assert-Exact (
    [bool]$reconstructedEvaluation.ok -and
    [int]$reconstructedEvaluation.reconstructed_passed_gate_count -eq 50 -and
    [int]$reconstructedEvaluation.reconstructed_failed_gate_count -eq 0 -and
    @($reconstructedEvaluation.failure_codes).Count -eq 0 -and
    [string]$reconstructedEvaluation.selected_candidate_id -ceq "NONE" -and
    -not [bool]$reconstructedEvaluation.selected_candidate_strictly_better_than_baseline -and
    [int]$reconstructedEvaluation.selected_candidate_paired_regression_count -eq 4 -and
    -not [bool]$reconstructedEvaluation.development_selection_authority -and
    -not [bool]$reconstructedEvaluation.independent_validation_authority -and
    -not [bool]$reconstructedEvaluation.physical_acceptance_authority
) "BW22L posthoc receipt reconstruction did not produce the expected no-selection diagnostic"

$candidateDiagnostics = @(
    foreach ($summary in $reconstructedEvaluation.candidate_summaries) {
        [ordered]@{
            candidate_id = [string]$summary.candidate_id
            observed_world_count = [int]$summary.observed_world_count
            declared_four_gate_walking_pass_count = (
                [int]$summary.observed_world_count -
                [int]$summary.walking_conjunction_failure_count
            )
            declared_four_gate_walking_failure_count =
                [int]$summary.walking_conjunction_failure_count
            aggregate_failed_declared_walking_gate_count =
                [int]$summary.aggregate_failed_production_walking_gate_count
            maximum_absolute_cross_track_error_m =
                [double]$summary.maximum_absolute_cross_track_error_m
            aggregate_cumulative_absolute_cross_track_error_m_s =
                [double]$summary.aggregate_cumulative_absolute_cross_track_error_m_s
            paired_walking_gate_regression_count =
                [int]$summary.paired_walking_gate_regression_count
        }
    }
)

$diagnostic = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw22l_posthoc_receipt_shape_diagnostic_v1"
    campaign_id = $campaignId
    source_commit = $sourceCommit
    classification =
        "posthoc_diagnostic_only_not_a_reclassification_or_selection"
    retained_raw_result = [ordered]@{
        path = $resolvedRawResultPath.Replace("\", "/")
        raw_sha256 = $expectedRawResultSha256
        expected_world_count = 28
        observed_world_count = 28
        parsed_receipt_count = 28
        supervisor_integrity_failure_count = 0
    }
    frozen_source_bindings = [ordered]@{
        production_evaluator_raw_sha256 = $expectedGateSha256
        physical_worker_raw_sha256 = $expectedWorkerSha256
        preregistration_raw_sha256 = $expectedPreregistrationSha256
    }
    original_frozen_evaluation = [ordered]@{
        ok = $false
        passed_gate_count = 21
        failed_gate_count = 29
        failure_codes = @(
            "BW22L_CELL_GATE",
            "BW22L_CANDIDATE_OUTCOME_METRICS"
        )
        selected_candidate_id = "NONE"
        development_selection_authority = $false
        result_remains_invalid = $true
    }
    observed_receipt_composition_defects = [ordered]@{
        non_safety_cell_count = 27
        real_non_safety_walking_receipt_key_count = 26
        frozen_evaluator_decision_walking_receipt_key_count = 4
        frozen_decision_walking_receipt_keys = $decisionWalkingKeys
        worker_forwarded_full_inherited_walking_receipt_dictionary = $true
        worker_computed_walking_observed_and_failure_count_from_full_dictionary =
            $true
        every_cell_missing_controller_coefficient_count =
            $missingControllerCoefficientCount
        safety_receipt_missing_required_common_field_count =
            $missingSafetyFields.Count
        safety_receipt_missing_required_common_fields = $missingSafetyFields
        safety_real_material_profile_id = [string]$safetyCell.material_profile_id
        safety_frozen_evaluator_profile_id = "NONE"
        safety_real_candidate_id = [string]$safetyCell.candidate_id
        safety_frozen_evaluator_candidate_id = "BW22L-SAFETY"
        production_controller_or_adapter_defect = $false
        world_transport_or_process_defect = $false
        synthetic_to_real_final_receipt_parity_defect = $true
    }
    reconstructed_prospective_schema_diagnostic = [ordered]@{
        ok_under_in_memory_receipt_shape_reconstruction = $true
        passed_gate_count = 50
        failed_gate_count = 0
        selector_output = "NONE"
        successor_strictly_better_than_baseline = $false
        successor_paired_walking_gate_regression_count = 4
        candidate_diagnostics = $candidateDiagnostics
        interpretation = (
            "The retained physical values are internally sufficient to show " +
            "that the stronger proportional treatment would not win the frozen " +
            "decision rule after the prospectively expected receipt projection."
        )
        development_selection_authority = $false
        independent_validation_authority = $false
        physical_acceptance_authority = $false
    }
    immutability = [ordered]@{
        bw22l_status_remains_invalid_development_execution = $true
        bw22l_reclassified = $false
        posthoc_selection_forbidden = $true
        same_identity_repair_or_rerun_forbidden = $true
        retained_artifacts_modified = $false
        successor_requires_new_campaign_source_preregistration_and_evidence_identity =
            $true
    }
    claim_boundary = [ordered]@{
        walking_acceptance = $false
        development_candidate_selected = $false
        material_robustness = $false
        superiority = $false
        noninferiority_or_equivalence = $false
        arbitrary_quadruped_coverage = $false
        cross_engine_equivalence = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
}

Write-NewUtf8Json -Value $diagnostic -Path $resolvedOutputPath
Write-Host (
    "BW22L_POSTHOC_RECEIPT_DIAGNOSTIC_PASS original=21/50 " +
    "reconstructed=50/50 selector=NONE paired_regressions=4 " +
    "selection_authority=False reclassified=False output=$resolvedOutputPath"
)
