#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$freezePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw25y_yaw_development_freeze.json"
$preregistrationPath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw25y_yaw_development_preregistration.json"
$supervisorPath = Join-Path (
    $repoRoot
) "sdk\run_balanced_wave_bw25y_yaw_development.ps1"
$workerPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw25y_yaw_development.gd"

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

Assert-Exact (
    Test-Path -LiteralPath $freezePath -PathType Leaf
) "BW25Y stage-one freeze is missing"
$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable -Depth 64
$study = $freeze.study_class
$matrix = $freeze.physical_matrix
$gate = $freeze.gate_contract
$preflight = $freeze.zero_world_authorization_preflight
$execution = $freeze.one_shot_execution_contract
Assert-Exact (
    [string]$freeze.schema_version -ceq
        "sporespore_balanced_wave_bw25y_yaw_development_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_before_first_bw25y_physical_world" -and
    [string]$freeze.campaign_id -ceq "BW25Y-FRESH-MATERIAL-YAW-DEVELOPMENT" -and
    [string]$freeze.gate_id -ceq "BW25Y" -and
    [string]$freeze.freeze_parent_commit -ceq
        "589b13258064e0d2d0b093495948f01822b4ff45" -and
    [string]$study.classification -ceq
        "paired_outcome_unexposed_finite_controller_development_screen" -and
    [int]$study.candidate_count -eq 2 -and
    [bool]$study.development_screen -and
    -not [bool]$study.finite_acceptance_decision -and
    -not [bool]$study.population_inference
) "BW25Y freeze identity or study class changed"

Assert-Exact (
    (@($matrix.authored_friction_values) -join "|") -ceq "0.59|0.71|0.83" -and
    (@($matrix.controller_coefficients) -join "|") -ceq "0.58|0.68|0.81" -and
    (@($matrix.campaign_seeds) -join "|") -ceq "26011|26012|26013|26014" -and
    [int]$matrix.candidate_world_count -eq 24 -and
    [int]$matrix.control_world_count -eq 3 -and
    [int]$matrix.safety_world_count -eq 1 -and
    [int]$matrix.expected_world_count -eq 28 -and
    [int]$matrix.physical_world_count_at_freeze -eq 0 -and
    [int]$matrix.selector_invocation_count_at_freeze -eq 0 -and
    [int]$matrix.candidate_outcome_count_at_freeze -eq 0
) "BW25Y frozen physical matrix changed"

Assert-Exact (
    [int]$gate.expected_gate_count -eq 50 -and
    [int]$gate.pre_matrix_gate_count -eq 4 -and
    [int]$gate.per_world_gate_count -eq 28 -and
    [int]$gate.aggregate_gate_count -eq 18 -and
    [bool]$gate.perfect_serialized_result_passes -and
    [bool]$gate.valid_result_may_select_none -and
    [bool]$gate.valid_negative_walking_cell_remains_a_complete_scientific_result -and
    [bool]$gate.complete_mechanism_application_numeric_or_integrity_failure_is_final_not_retryable -and
    [bool]$gate.outcome_based_early_stop_forbidden -and
    [bool]$gate.outcome_based_retry_or_replacement_forbidden -and
    [bool]$gate.complete_cell_replacement_forbidden -and
    [bool]$gate.one_replacement_for_absent_complete_receipt_only -and
    [bool]$gate.post_result_gate_edit_forbidden
) "BW25Y production-gate or negative-result contract changed"

Assert-Exact (
    [int]$preflight.production_gate_count -eq 50 -and
    [int]$preflight.production_evaluator_negative_canary_count -eq 28 -and
    [int]$preflight.candidate_authority_check_count -eq 13 -and
    [int]$preflight.worker_entrypoint_count -eq 28 -and
    [int]$preflight.adapter_start_count -eq 27 -and
    [int]$preflight.real_shaped_receipt_count -eq 28 -and
    [int]$preflight.receipt_composition_defect_canary_count -eq 5 -and
    [int]$preflight.attempt_record_canary_count -eq 12 -and
    [int]$preflight.authorization_and_bypass_canary_count -eq 5 -and
    [int]$preflight.outcome_blind_recovery_decision_canary_count -eq 9 -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_tree_insertion_count -eq 0 -and
    [int]$preflight.physics_state_mutation_count -eq 0 -and
    -not [bool]$preflight.locomotion_outcome_exposed -and
    -not [bool]$preflight.physical_acceptance_authority
) "BW25Y complete zero-world preflight declaration changed"

Assert-Exact (
    [bool]$execution.only_complete_supervisor_may_open_physical_worlds -and
    [bool]$execution.worker_requires_exact_retained_attempt_and_matching_authorization_token -and
    [bool]$execution.output_root_must_be_new_durable_and_inside_sporespore_evidence -and
    [bool]$execution.head_must_equal_origin_main_and_live_github_main -and
    [bool]$execution.worktree_must_be_clean -and
    [bool]$execution.prior_attempt_count_must_be_zero -and
    [bool]$execution.attempt_receipt_written_and_identity_consumed_before_first_world -and
    [bool]$execution.attempt_receipt_remains_immutable_after_first_world -and
    [bool]$execution.all_twenty_eight_cells_attempted_even_after_cell_failure -and
    [bool]$execution.valid_negative_cell_is_final_and_does_not_fail_process -and
    [bool]$execution.complete_mechanism_application_numeric_or_integrity_failure_is_final_and_not_replaceable -and
    [bool]$execution.one_automatic_replacement_only_for_incomplete_receipt -and
    [bool]$execution.replacement_never_depends_on_locomotion_outcome -and
    [bool]$execution.replacement_never_depends_on_mechanism_application_numeric_or_integrity_outcome -and
    [bool]$execution.replacement_eligibility_inputs_are_limited_to_timeout_exit_parse_identity_declared_completeness_and_composition -and
    [bool]$execution.primary_and_replacement_logs_are_both_retained -and
    [bool]$execution.first_complete_result_final_for_source_identity -and
    -not [bool]$execution.same_identity_rerun_allowed
) "BW25Y one-shot execution or interruption contract changed"

foreach ($claimSetName in @(
    "claims_before_physical_execution",
    "claim_ceiling_after_valid_complete_development_result"
)) {
    $claimSet = $freeze[$claimSetName]
    foreach ($claimName in @($claimSet.Keys)) {
        if (
            $claimSetName -ceq "claim_ceiling_after_valid_complete_development_result" -and
            $claimName -in @(
                "exact_finite_development_result_complete",
                "development_hypothesis_selected_only_if_selector_returns_non_none"
            )
        ) {
            Assert-Exact ([bool]$claimSet[$claimName]) (
                "BW25Y valid-development ceiling lost: $claimName"
            )
            continue
        }
        Assert-Exact (-not [bool]$claimSet[$claimName]) (
            "BW25Y claim inflated in ${claimSetName}: $claimName"
        )
    }
}

$bindings = $freeze.source_bindings
Assert-Exact ($bindings.Count -ge 22) "BW25Y source binding surface is incomplete"
foreach ($bindingEntry in $bindings.GetEnumerator()) {
    $binding = $bindingEntry.Value
    $relativePath = [string]$binding.path
    $expectedHash = [string]$binding.raw_sha256
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        $expectedHash -cmatch "^[0-9a-f]{64}$" -and
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-RawSha256 -Path $absolutePath) -ceq $expectedHash
    ) "BW25Y frozen source is missing or changed: $relativePath"
}

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$orderedCells = @($preregistration.matrix.ordered_cells)
Assert-Exact (
    $orderedCells.Count -eq 28 -and
    @($orderedCells | Where-Object role -CEQ "candidate").Count -eq 24 -and
    @($orderedCells | Where-Object role -CEQ "control").Count -eq 3 -and
    @($orderedCells | Where-Object role -CEQ "safety").Count -eq 1 -and
    @($orderedCells | Where-Object {
        [int]$_.campaign_seed -notin @(26011, 26012, 26013, 26014)
    }).Count -eq 0
) "BW25Y preregistration no longer matches the frozen 28-cell matrix"

$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
$workerSource = Get-Content -Raw -LiteralPath $workerPath
foreach ($marker in @(
    "New-Bw25yAttemptRecord",
    "Test-Bw25yAttemptRecord",
    "Get-Bw25yReceiptDisposition",
    "BW25Y-P1::",
    "BW25Y-R1::",
    "ConvertTo-Bw25yFinalCellReceipt",
    "Test-Bw25yCell",
    "attemptRawSha256AtLaunch",
    "locomotion_outcome_triggered_replacement = `$false",
    "complete_negative_mechanism_primary",
    "close_cell_incomplete_recovery_exhausted",
    "locomotion_outcome_consulted = `$false",
    "complete physical execution was retained but failed its",
    "Invoke-Bw25yYawDevelopmentEvaluation"
)) {
    Assert-Exact (
        $supervisorSource.Contains($marker, [StringComparison]::Ordinal)
    ) "BW25Y supervisor contract marker is missing: $marker"
}
foreach ($marker in @(
    "_walking_required_for_cell_success() -> bool:",
    "walking_result_controls_process_exit",
    "receipt[`"raw_receipt_complete`"] = true",
    "receipt[`"role_gate_passed`"] = role_gate_passed",
    "quit(0)",
    "BW25Y_RAW_CELL_PREFIX",
    "_bw25y_physical_authorization_exact",
    "SPORESPORE_BW25Y_WORLD_ATTEMPT_ID",
    "SPORESPORE_BW25Y_CAMPAIGN_ATTEMPT_ID"
)) {
    Assert-Exact (
        $workerSource.Contains($marker, [StringComparison]::Ordinal)
    ) "BW25Y worker contract marker is missing: $marker"
}

$tokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $supervisorPath,
    [ref]$tokens,
    [ref]$parseErrors
)
Assert-Exact ($parseErrors.Count -eq 0) "BW25Y supervisor no longer parses"

Write-Host (
    "BW25Y_STAGE_ONE_FREEZE_PASS worlds=0 cells=28 gates=50 " +
    "source_bindings=$($bindings.Count) attempt_canaries=12 " +
    "authorization_canaries=5 recovery_canaries=9 " +
    "incomplete_replacement_budget=1 " +
    "negative_walking_integrity=True outcomes_exposed=False " +
    "physical_authority=False freeze_sha256=$(Get-RawSha256 -Path $freezePath)"
)
