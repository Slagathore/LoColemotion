#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$freezePath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw28y_yaw_development_freeze.json"
$preregistrationPath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw28y_yaw_development_preregistration.json"
$manifestPath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw28y_yaw_development_manifest.json"
$supervisorPath = Join-Path (
    $repoRoot
) "sdk\run_balanced_wave_bw28y_yaw_development.ps1"
$workerPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw28y_yaw_development.gd"
$actualRoutePath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_actual_worker_receipt_route.gd"

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
) "BW28Y stage-one freeze is missing"
$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable -Depth 64
$study = $freeze.study_class
$matrix = $freeze.physical_matrix
$gate = $freeze.gate_contract
$preflight = $freeze.zero_world_authorization_preflight
$execution = $freeze.one_shot_execution_contract
Assert-Exact (
    [string]$freeze.schema_version -ceq
        "sporespore_balanced_wave_bw28y_yaw_development_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_before_first_bw28y_physical_world" -and
    [string]$freeze.campaign_id -ceq "BW28Y-FRESH-MATERIAL-YAW-DEVELOPMENT" -and
    [string]$freeze.gate_id -ceq "BW28Y" -and
    [string]$freeze.freeze_parent_commit -ceq
        "96835e39a68f4c0ae4931338a44d7c72008c8c9a" -and
    [string]$study.classification -ceq
        "paired_outcome_unexposed_finite_controller_development_screen" -and
    [int]$study.candidate_count -eq 2 -and
    [bool]$study.development_screen -and
    -not [bool]$study.finite_acceptance_decision -and
    -not [bool]$study.population_inference
) "BW28Y freeze identity or study class changed"

Assert-Exact (
    (@($matrix.authored_friction_values) -join "|") -ceq "0.62|0.74|0.86" -and
    (@($matrix.controller_coefficients) -join "|") -ceq "0.61|0.73|0.84" -and
    (@($matrix.campaign_seeds) -join "|") -ceq "27011|27012|27013|27014" -and
    [int]$matrix.candidate_world_count -eq 24 -and
    [int]$matrix.control_world_count -eq 3 -and
    [int]$matrix.safety_world_count -eq 1 -and
    [int]$matrix.expected_world_count -eq 28 -and
    [int]$matrix.physical_world_count_at_freeze -eq 0 -and
    [int]$matrix.selector_invocation_count_at_freeze -eq 0 -and
    [int]$matrix.candidate_outcome_count_at_freeze -eq 0
) "BW28Y frozen physical matrix changed"

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
) "BW28Y production-gate or negative-result contract changed"

Assert-Exact (
    [int]$preflight.production_gate_count -eq 50 -and
    [int]$preflight.production_evaluator_negative_canary_count -eq 19 -and
    [int]$preflight.candidate_authority_check_count -eq 13 -and
    [int]$preflight.worker_entrypoint_count -eq 28 -and
    [int]$preflight.adapter_start_count -eq 27 -and
    [int]$preflight.real_shaped_receipt_count -eq 28 -and
    [int]$preflight.receipt_composition_defect_canary_count -eq 5 -and
    [int]$preflight.attempt_record_canary_count -eq 16 -and
    [int]$preflight.authorization_and_bypass_canary_count -eq 5 -and
    [int]$preflight.outcome_blind_recovery_decision_canary_count -eq 9 -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_tree_insertion_count -eq 0 -and
    [int]$preflight.physics_state_mutation_count -eq 0 -and
    -not [bool]$preflight.locomotion_outcome_exposed -and
    -not [bool]$preflight.physical_acceptance_authority
) "BW28Y complete zero-world preflight declaration changed"

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
) "BW28Y one-shot execution or interruption contract changed"

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
                "BW28Y valid-development ceiling lost: $claimName"
            )
            continue
        }
        Assert-Exact (-not [bool]$claimSet[$claimName]) (
            "BW28Y claim inflated in ${claimSetName}: $claimName"
        )
    }
}

$bindings = $freeze.source_bindings
Assert-Exact ($bindings.Count -ge 25) "BW28Y source binding surface is incomplete"
foreach ($bindingEntry in $bindings.GetEnumerator()) {
    $binding = $bindingEntry.Value
    $relativePath = [string]$binding.path
    $expectedHash = [string]$binding.raw_sha256
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        $expectedHash -cmatch "^[0-9a-f]{64}$" -and
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-RawSha256 -Path $absolutePath) -ceq $expectedHash
    ) "BW28Y frozen source is missing or changed: $relativePath"
}

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$manifest = Get-Content -Raw -LiteralPath $manifestPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$orderedCells = @($manifest.ordered_cells)
Assert-Exact (
    [string]$preregistration.campaign_id -ceq
        "BW28Y-FRESH-MATERIAL-YAW-DEVELOPMENT" -and
    [string]$manifest.campaign_id -ceq
        "BW28Y-FRESH-MATERIAL-YAW-DEVELOPMENT" -and
    $orderedCells.Count -eq 28 -and
    @($orderedCells | Where-Object role -CEQ "candidate").Count -eq 24 -and
    @($orderedCells | Where-Object role -CEQ "control").Count -eq 3 -and
    @($orderedCells | Where-Object role -CEQ "safety").Count -eq 1 -and
    @($orderedCells | Where-Object {
        [int]$_.campaign_seed -notin @(27011, 27012, 27013, 27014)
    }).Count -eq 0
) "BW28Y declarations no longer match the frozen 28-cell matrix"

$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
$workerSource = Get-Content -Raw -LiteralPath $workerPath
$actualRouteSource = Get-Content -Raw -LiteralPath $actualRoutePath
foreach ($marker in @(
    "New-Bw28yAttemptRecord",
    "Test-Bw28yAttemptRecord",
    "Get-Bw28yReceiptDisposition",
    "BW28Y-P1::",
    "BW28Y-R1::",
    "ConvertTo-Bw28yFinalCellReceipt",
    "Test-Bw28yCell",
    "attemptRawSha256AtLaunch",
    "locomotion_outcome_triggered_replacement = `$false",
    "complete_negative_mechanism_primary",
    "close_cell_incomplete_recovery_exhausted",
    "locomotion_outcome_consulted = `$false",
    "complete physical execution was retained but failed its",
    "Invoke-Bw28yYawDevelopmentEvaluation"
)) {
    Assert-Exact (
        $supervisorSource.Contains($marker, [StringComparison]::Ordinal)
    ) "BW28Y supervisor contract marker is missing: $marker"
}
foreach ($marker in @(
    "_walking_required_for_cell_success() -> bool:",
    "ActualWorkerReceiptRouteScript.compose(",
    "_role_gate_passed(receipt: Dictionary)",
    "quit(0 if bool(receipt.get(`"raw_receipt_complete`", false)) else 2)",
    "BW28Y_RAW_CELL_PREFIX",
    "_bw28y_physical_authorization_exact",
    "SPORESPORE_BW28Y_WORLD_ATTEMPT_ID",
    "SPORESPORE_BW28Y_CAMPAIGN_ATTEMPT_ID"
)) {
    Assert-Exact (
        $workerSource.Contains($marker, [StringComparison]::Ordinal)
    ) "BW28Y worker contract marker is missing: $marker"
}
foreach ($marker in @(
    'receipt["walking_result_controls_process_exit"] = false',
    'receipt["raw_receipt_complete"] = bool(validation["ok"])',
    'receipt["role_gate_passed"] = bool(owner.call("_role_gate_passed", receipt))'
)) {
    Assert-Exact (
        $actualRouteSource.Contains($marker, [StringComparison]::Ordinal)
    ) "BW28Y actual receipt-route marker is missing: $marker"
}

$tokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $supervisorPath,
    [ref]$tokens,
    [ref]$parseErrors
)
Assert-Exact ($parseErrors.Count -eq 0) "BW28Y supervisor no longer parses"

Write-Host (
    "BW28Y_STAGE_ONE_FREEZE_PASS worlds=0 cells=28 gates=50 " +
    "source_bindings=$($bindings.Count) attempt_canaries=16 " +
    "authorization_canaries=5 recovery_canaries=9 " +
    "incomplete_replacement_budget=1 " +
    "negative_walking_integrity=True outcomes_exposed=False " +
    "physical_authority=False freeze_sha256=$(Get-RawSha256 -Path $freezePath)"
)
