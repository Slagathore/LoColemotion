#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$freezePath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze.json"
$declarationAuditPath = Join-Path $repoRoot `
    "tests\test_drp1_dynamic_receipt_projection_declaration.ps1"
$evaluatorPath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_gate.ps1"
$runnerPath = Join-Path $repoRoot `
    "sdk\run_balanced_wave_dynamic_receipt_projection_drp1.ps1"
$zeroWorldGatePath = Join-Path $repoRoot `
    "sdk\run_balanced_wave_dynamic_receipt_projection_drp1_zero_world_gate.ps1"
$regressionId = "BW31N-DYNAMIC-RECEIPT-PROJECTION-REGRESSION-DRP1"
$gateId = "DRP1"

function Assert-Drp1Freeze {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Drp1FreezeRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

Assert-Drp1Freeze (Test-Path -LiteralPath $freezePath -PathType Leaf) (
    "$gateId stage-one freeze is missing"
)
$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$witness = [System.Collections.IDictionary]$freeze.stage_one_witness
$classification = [System.Collections.IDictionary]$freeze.classification
$matrix = [System.Collections.IDictionary]$freeze.regression_matrix
$projection = [System.Collections.IDictionary]$freeze.dynamic_projection_contract
$evaluator = [System.Collections.IDictionary]$freeze.complete_evaluator_contract
$execution = [System.Collections.IDictionary]$freeze.full_conformance_execution_contract

Assert-Drp1Freeze (
    [string]$freeze.schema_version -ceq
        "sporespore_balanced_wave_dynamic_receipt_projection_drp1_freeze_v1" -and
    [string]$freeze.status -ceq
        "frozen_after_complete_zero_world_gate_before_first_regression_world" -and
    [string]$freeze.regression_id -ceq $regressionId -and
    [string]$freeze.gate_id -ceq $gateId -and
    [string]$freeze.freeze_parent_commit -ceq
        "23d0d8ca3c779f6681c98774e4dbe642ffbf352c" -and
    [bool]$freeze.full_godot_conformance_regression_ready_after_clean_push -and
    -not [bool]$freeze.standalone_regression_physics_authorized
) "$gateId stage-one freeze identity or authority changed"

Assert-Drp1Freeze (
    [string]$witness.declaration_commit -ceq
        "23d0d8ca3c779f6681c98774e4dbe642ffbf352c" -and
    [bool]$witness.head_equaled_origin_main_and_live_github_main_before_stage_one_authoring -and
    [bool]$witness.worktree_was_clean_before_stage_one_authoring -and
    [bool]$witness.actual_godot_worker_zero_world_gate_passed -and
    [bool]$witness.godot_skipped_zero_world_gate_passed -and
    [int]$witness.worker_entrypoint_count -eq 24 -and
    [int]$witness.constructed_final_receipt_rejection_count -eq 24 -and
    [int]$witness.authorization_refusal_canary_count -eq 2 -and
    [int]$witness.evaluator_gate_count -eq 12 -and
    [int]$witness.evaluator_gate_canary_count -eq 12 -and
    [int]$witness.malformed_receipt_fail_closed_canary_count -eq 1 -and
    [int]$witness.regression_world_build_count -eq 0 -and
    [int]$witness.regression_physical_process_launch_count -eq 0 -and
    -not [bool]$witness.locomotion_outcome_exposed
) "$gateId zero-world stage-one witness changed"

Assert-Drp1Freeze (
    [bool]$classification.ordinary_repeatable_regression_test_physics -and
    -not [bool]$classification.scientific_campaign -and
    -not [bool]$classification.one_shot_identity -and
    -not [bool]$classification.finite_development_screen -and
    -not [bool]$classification.superiority_study -and
    -not [bool]$classification.noninferiority_or_equivalence_study -and
    -not [bool]$classification.population_study -and
    -not [bool]$classification.candidate_or_policy_selection_permitted -and
    -not [bool]$classification.walking_or_nuisance_acceptance_permitted -and
    [bool]$classification.rerunnable_after_implementation_freeze -and
    -not [bool]$classification.scientific_evidence_retained -and
    -not [bool]$classification.new_scientific_outcome_consumed
) "$gateId repeatable noncampaign classification changed"

Assert-Drp1Freeze (
    (@($matrix.route_order) -join "|") -ceq
        "DRP1-REFERENCE-ROUTE|DRP1-SUCCESSOR-ROUTE" -and
    (@($matrix.challenge_profile_order) -join "|") -ceq
        "bw6n_baseline_v1|bw6n_rough_v1|bw6n_push_v1|bw6n_sensor_noise_v1" -and
    (@($matrix.regression_seed_order) -join "|") -ceq "22001|22002|22003" -and
    [int]$matrix.expected_world_count -eq 24 -and
    [bool]$matrix.all_worlds_required_per_complete_regression_run -and
    [bool]$matrix.partial_matrix_pass_forbidden -and
    [bool]$matrix.walking_result_comparison_forbidden -and
    [bool]$matrix.route_selection_forbidden -and
    (@($matrix.reserved_fresh_independent_validation_seed_ids) -join "|") -ceq
        "49101|49102|49103" -and
    [bool]$matrix.reserved_fresh_seeds_remain_unopened
) "$gateId frozen matrix or fresh-seed boundary changed"

Assert-Drp1Freeze (
    [string]$projection.shared_final_receipt_schema_version -ceq
        "sporespore_balanced_wave_dynamic_receipt_projection_drp1_cell_v1" -and
    [string]$projection.shared_final_receipt_composer_id -ceq
        "drp1_dynamic_parent_summary_composer_v1" -and
    [bool]$projection.one_shared_composer_for_both_real_routes -and
    [bool]$projection.actual_world_and_real_parent_summary_required_for_every_receipt -and
    [bool]$projection.constructed_real_shaped_receipt_substitution_forbidden -and
    [bool]$projection.route_identity_projected_from_frozen_declaration -and
    [bool]$projection.challenge_recomputed_from_direct_primitives -and
    [int]$projection.candidate_authority_observation_count -eq 3232 -and
    [int]$projection.expected_native_motor_write_count -eq 25856 -and
    [int]$projection.candidate_specific_horizon_extension_count -eq 0 -and
    [int]$projection.reference_pre_authority_world_tick_count -eq 712 -and
    [int]$projection.successor_pre_authority_world_tick_count -eq 240 -and
    [bool]$projection.pre_authority_ticks_excluded_from_candidate_exposure -and
    [bool]$projection.outcome_completeness_independent_of_legacy_fixed_world_horizon_aggregate -and
    [bool]$projection.common_integrity_independent_of_legacy_parent_campaign_boolean -and
    [bool]$projection.walking_boolean_may_be_true_or_false_when_structurally_complete -and
    [bool]$projection.walking_count_is_not_an_evaluator_input
) "$gateId dynamic projection contract changed"

$expectedGates = @(
    "exact_noncampaign_identity",
    "exact_matrix_cardinality_and_order",
    "shared_final_receipt_schema",
    "route_identity_projection",
    "candidate_authority_horizon",
    "pre_authority_exclusion",
    "challenge_realization",
    "measurement_acquisition",
    "candidate_application",
    "outcome_complete",
    "common_execution_integrity",
    "all_scientific_and_release_claims_false"
)
Assert-Drp1Freeze (
    [int]$evaluator.expected_gate_count -eq 12 -and
    (@($evaluator.required_gates) -join "|") -ceq ($expectedGates -join "|") -and
    [bool]$evaluator.all_12_gates_must_pass -and
    [bool]$evaluator.all_24_dynamic_receipts_must_pass_route_integrity -and
    [bool]$evaluator.all_24_worker_exit_codes_must_be_zero -and
    [bool]$evaluator.malformed_or_missing_receipt_fails_closed -and
    [bool]$evaluator.structurally_complete_walking_negative_is_valid -and
    [bool]$evaluator.no_route_or_policy_is_selected
) "$gateId complete evaluator contract changed"

Assert-Drp1Freeze (
    [string]$execution.only_authorized_entrypoint -ceq
        "sdk/run_conformance.ps1 with Godot enabled" -and
    [bool]$execution.global_locomotion_operation_lock_required -and
    [bool]$execution.clean_pushed_head_equal_to_origin_main_and_live_github_main_required -and
    [bool]$execution.exact_source_bindings_required -and
    [bool]$execution.actual_clean_pushed_head_captured_in_ephemeral_authorization -and
    [bool]$execution.random_conformance_token_required -and
    [bool]$execution.per_worker_cell_and_route_binding_required -and
    [bool]$execution.all_twenty_four_workers_execute_sequentially -and
    [bool]$execution.all_twenty_four_cells_attempted_after_individual_cell_failure -and
    [bool]$execution.each_worker_runs_in_a_fresh_process -and
    [bool]$execution.evaluation_requires_exactly_twenty_four_receipts -and
    [bool]$execution.evaluation_requires_exactly_twenty_four_world_builds -and
    [bool]$execution.ephemeral_input_and_evaluation_are_deleted_after_run -and
    [bool]$execution.retained_scientific_evidence_forbidden -and
    [bool]$execution.standalone_runner_invocation_forbidden -and
    -not [bool]$execution.one_shot_identity_consumed -and
    [bool]$execution.fresh_validation_seed_use_forbidden
) "$gateId full-conformance-only execution contract changed"

foreach ($entry in $freeze.claim_boundary.GetEnumerator()) {
    Assert-Drp1Freeze (-not [bool]$entry.Value) (
        "$gateId claim inflated at freeze: $($entry.Key)"
    )
}

$bindings = [System.Collections.IDictionary]$freeze.source_bindings
Assert-Drp1Freeze ($bindings.Count -ge 28) "$gateId source binding surface is incomplete"
foreach ($entry in $bindings.GetEnumerator()) {
    $binding = [System.Collections.IDictionary]$entry.Value
    $relativePath = [string]$binding.path
    $expectedHash = [string]$binding.raw_sha256
    $absolutePath = [IO.Path]::GetFullPath((Join-Path $repoRoot $relativePath))
    $repoPrefix = $repoRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-Drp1Freeze (
        $absolutePath.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        $expectedHash -cmatch "^[0-9a-f]{64}$" -and
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-Drp1FreezeRawSha256 -Path $absolutePath) -ceq $expectedHash
    ) "$gateId frozen source is missing or changed: $relativePath"
}

& pwsh -NoLogo -NoProfile -File $declarationAuditPath
Assert-Drp1Freeze ($LASTEXITCODE -eq 0) "$gateId declaration audit failed"

& pwsh -NoLogo -NoProfile -File $evaluatorPath -SelfTest
Assert-Drp1Freeze ($LASTEXITCODE -eq 0) "$gateId evaluator self-test failed"

& pwsh -NoLogo -NoProfile -File $runnerPath -PreflightOnly
Assert-Drp1Freeze ($LASTEXITCODE -eq 0) "$gateId runner preflight failed"

foreach ($path in @($evaluatorPath, $runnerPath, $zeroWorldGatePath)) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $path,
        [ref]$tokens,
        [ref]$parseErrors
    )
    Assert-Drp1Freeze ($parseErrors.Count -eq 0) (
        "$gateId PowerShell source no longer parses: $path"
    )
}

$runnerSource = Get-Content -Raw -LiteralPath $runnerPath
foreach ($marker in @(
    "SPORESPORE_DRP1_SOURCE_COMMIT",
    "Test-Drp1CleanPushedLiveSource",
    "foreach (`$cell in Get-Drp1OrderedCells)",
    "DRP1_FULL_GODOT_REGRESSION_PASS",
    "scientific_evidence_retained = `$false",
    "one_shot_identity_consumed = `$false",
    "Remove-Item -LiteralPath `$tempRoot -Recurse -Force"
)) {
    Assert-Drp1Freeze (
        $runnerSource.Contains($marker, [StringComparison]::Ordinal)
    ) "$gateId regression-runner contract marker is missing: $marker"
}

Write-Host (
    "DRP1_STAGE_ONE_FREEZE_PASS worlds=0 cells=24 gates=12 source_bindings=$($bindings.Count) " +
    "entrypoints=24 evaluator_canaries=12 malformed_receipt_canary=1 " +
    "authorization_canaries=2 constructed_receipts_rejected=24 " +
    "shared_composer=True regression_ready_after_clean_push=True one_shot=False " +
    "selection_authority=False walking_authority=False physical_authority=False " +
    "freeze_sha256=$(Get-Drp1FreezeRawSha256 -Path $freezePath)"
)
