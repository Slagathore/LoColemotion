#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$freezePath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze_v2.json"
$declarationAuditPath = Join-Path $repoRoot `
    "tests\test_drp1_dynamic_receipt_projection_declaration.ps1"
$run1AuditPath = Join-Path $repoRoot `
    "tests\test_drp1_dynamic_receipt_projection_run1_result.ps1"
$evaluatorPath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_gate.ps1"
$runnerPath = Join-Path $repoRoot `
    "sdk\run_balanced_wave_dynamic_receipt_projection_drp1.ps1"
$zeroWorldGatePath = Join-Path $repoRoot `
    "sdk\run_balanced_wave_dynamic_receipt_projection_drp1_zero_world_gate.ps1"
$regressionId = "BW31N-DYNAMIC-RECEIPT-PROJECTION-REGRESSION-DRP1"
$gateId = "DRP1"

function Assert-Drp1FreezeV2 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Drp1FreezeV2RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

Assert-Drp1FreezeV2 (Test-Path -LiteralPath $freezePath -PathType Leaf) (
    "$gateId revision-two freeze is missing"
)
$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$predecessor = [System.Collections.IDictionary]$freeze.predecessor_run
$revision = [System.Collections.IDictionary]$freeze.revision_scope
$witness = [System.Collections.IDictionary]$freeze.stage_two_zero_world_witness
$classification = [System.Collections.IDictionary]$freeze.classification
$matrix = [System.Collections.IDictionary]$freeze.regression_matrix
$evaluator = [System.Collections.IDictionary]$freeze.complete_evaluator_contract
$execution = [System.Collections.IDictionary]$freeze.full_conformance_execution_contract

Assert-Drp1FreezeV2 (
    [string]$freeze.schema_version -ceq
        "sporespore_balanced_wave_dynamic_receipt_projection_drp1_freeze_v2" -and
    [string]$freeze.status -ceq
        "frozen_after_run1_nested_schema_failure_and_complete_v2_zero_world_gate_before_rerun" -and
    [string]$freeze.regression_id -ceq $regressionId -and
    [string]$freeze.gate_id -ceq $gateId -and
    [string]$freeze.freeze_parent_commit -ceq
        "5a7d576a47e3e9232928fdbd07c2c359959edaff" -and
    [int]$freeze.freeze_revision -eq 2 -and
    [bool]$freeze.full_godot_conformance_regression_ready_after_clean_push -and
    -not [bool]$freeze.standalone_regression_physics_authorized
) "$gateId revision-two freeze identity or authority changed"

Assert-Drp1FreezeV2 (
    [string]$predecessor.result_raw_sha256 -ceq
        "790647a8a2be5894ea782b8c46884243bf287c99a533a915dd13bfac5d448b26" -and
    [string]$predecessor.source_commit -ceq
        "5a7d576a47e3e9232928fdbd07c2c359959edaff" -and
    [string]$predecessor.stage_one_freeze_raw_sha256 -ceq
        "19d46d3ac1237f7f483f14d8e4f70de7375fa0919232b6900d91f1e46de2f4e2" -and
    [int]$predecessor.world_build_count -eq 24 -and
    [int]$predecessor.dynamic_receipt_count -eq 24 -and
    [int]$predecessor.passed_gate_count -eq 9 -and
    (@($predecessor.failed_gate_ids) -join "|") -ceq
        "shared_final_receipt_schema|outcome_complete|common_execution_integrity" -and
    -not [bool]$predecessor.attestation_published -and
    -not [bool]$predecessor.scientific_result -and
    -not [bool]$predecessor.locomotion_negative -and
    [bool]$predecessor.same_repeatable_regression_id_may_rerun
) "$gateId run-one predecessor boundary changed"

Assert-Drp1FreezeV2 (
    -not [bool]$revision.outer_shared_final_receipt_schema_changed -and
    -not [bool]$revision.regression_matrix_changed -and
    -not [bool]$revision.route_identity_changed -and
    -not [bool]$revision.authority_horizon_changed -and
    -not [bool]$revision.challenge_contract_changed -and
    -not [bool]$revision.application_contract_changed -and
    -not [bool]$revision.evaluator_gate_ids_changed -and
    [bool]$revision.nested_walking_receipt_schema_became_route_specific -and
    [string]$revision.reference_route_actuation_key -ceq
        "sdk_stability_overlay_evidence_actuation" -and
    [string]$revision.successor_route_actuation_key -ceq
        "native_sdk_exclusive_post_settle_actuation" -and
    [int]$revision.common_nested_key_count -eq 25 -and
    [int]$revision.route_specific_actuation_key_count -eq 1 -and
    [int]$revision.exact_nested_key_count_per_route -eq 26 -and
    [bool]$revision.exactly_one_route_actuation_key_required -and
    [bool]$revision.cross_route_nested_schema_substitution_forbidden
) "$gateId revision-two scope inflated or changed"

Assert-Drp1FreezeV2 (
    [bool]$witness.actual_godot_worker_zero_world_gate_passed -and
    [bool]$witness.godot_skipped_zero_world_gate_passed -and
    [int]$witness.worker_entrypoint_count -eq 24 -and
    [int]$witness.constructed_final_receipt_rejection_count -eq 24 -and
    [int]$witness.route_specific_nested_schema_preflight_count -eq 24 -and
    [int]$witness.cross_route_nested_schema_rejection_count -eq 24 -and
    [int]$witness.authorization_refusal_canary_count -eq 2 -and
    [int]$witness.evaluator_gate_count -eq 12 -and
    [int]$witness.evaluator_gate_canary_count -eq 12 -and
    [int]$witness.malformed_receipt_fail_closed_canary_count -eq 1 -and
    [int]$witness.cross_route_evaluator_schema_canary_count -eq 2 -and
    [int]$witness.regression_world_build_count -eq 0 -and
    [int]$witness.regression_physical_process_launch_count -eq 0 -and
    -not [bool]$witness.locomotion_outcome_exposed
) "$gateId revision-two zero-world witness changed"

Assert-Drp1FreezeV2 (
    [bool]$classification.ordinary_repeatable_regression_test_physics -and
    -not [bool]$classification.scientific_campaign -and
    -not [bool]$classification.one_shot_identity -and
    -not [bool]$classification.candidate_or_policy_selection_permitted -and
    -not [bool]$classification.walking_or_nuisance_acceptance_permitted -and
    [bool]$classification.rerunnable_after_implementation_freeze -and
    -not [bool]$classification.scientific_evidence_retained -and
    -not [bool]$classification.new_scientific_outcome_consumed
) "$gateId repeatable noncampaign classification changed"

Assert-Drp1FreezeV2 (
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
Assert-Drp1FreezeV2 (
    [int]$evaluator.expected_gate_count -eq 12 -and
    (@($evaluator.required_gates) -join "|") -ceq ($expectedGates -join "|") -and
    [bool]$evaluator.all_12_gates_must_pass -and
    [bool]$evaluator.all_24_dynamic_receipts_must_pass_route_integrity -and
    [bool]$evaluator.all_24_worker_exit_codes_must_be_zero -and
    [bool]$evaluator.malformed_or_missing_receipt_fails_closed -and
    [bool]$evaluator.cross_route_nested_schema_fails_closed -and
    [bool]$evaluator.structurally_complete_walking_negative_is_valid -and
    [bool]$evaluator.walking_count_is_not_an_evaluator_input -and
    [bool]$evaluator.no_route_or_policy_is_selected
) "$gateId revision-two evaluator contract changed"

Assert-Drp1FreezeV2 (
    [string]$execution.only_authorized_entrypoint -ceq
        "sdk/run_conformance.ps1 with Godot enabled" -and
    [bool]$execution.global_locomotion_operation_lock_required -and
    [bool]$execution.clean_pushed_head_equal_to_origin_main_and_live_github_main_required -and
    [bool]$execution.exact_source_bindings_required -and
    [bool]$execution.actual_clean_pushed_head_captured_in_ephemeral_authorization -and
    [bool]$execution.random_conformance_token_required -and
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
) "$gateId revision-two execution contract changed"

foreach ($entry in $freeze.claim_boundary.GetEnumerator()) {
    Assert-Drp1FreezeV2 (-not [bool]$entry.Value) (
        "$gateId claim inflated at revision-two freeze: $($entry.Key)"
    )
}

$bindings = [System.Collections.IDictionary]$freeze.source_bindings
Assert-Drp1FreezeV2 ($bindings.Count -ge 32) "$gateId v2 source binding surface is incomplete"
foreach ($entry in $bindings.GetEnumerator()) {
    $binding = [System.Collections.IDictionary]$entry.Value
    $relativePath = [string]$binding.path
    $expectedHash = [string]$binding.raw_sha256
    $absolutePath = [IO.Path]::GetFullPath((Join-Path $repoRoot $relativePath))
    $repoPrefix = $repoRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-Drp1FreezeV2 (
        $absolutePath.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        $expectedHash -cmatch "^[0-9a-f]{64}$" -and
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-Drp1FreezeV2RawSha256 -Path $absolutePath) -ceq $expectedHash
    ) "$gateId v2 frozen source is missing or changed: $relativePath"
}

& pwsh -NoLogo -NoProfile -File $declarationAuditPath
Assert-Drp1FreezeV2 ($LASTEXITCODE -eq 0) "$gateId declaration audit failed"

& pwsh -NoLogo -NoProfile -File $run1AuditPath
Assert-Drp1FreezeV2 ($LASTEXITCODE -eq 0) "$gateId run-one result audit failed"

& pwsh -NoLogo -NoProfile -File $evaluatorPath -SelfTest
Assert-Drp1FreezeV2 ($LASTEXITCODE -eq 0) "$gateId evaluator self-test failed"

& pwsh -NoLogo -NoProfile -File $runnerPath -PreflightOnly
Assert-Drp1FreezeV2 ($LASTEXITCODE -eq 0) "$gateId runner preflight failed"

$commonSource = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "scripts\lab\gait\sdk_drp1_worker_common.gd"
)
$evaluatorSource = Get-Content -Raw -LiteralPath $evaluatorPath
foreach ($marker in @(
    "ROUTE_WALKING_ACTUATION_KEYS",
    'REFERENCE_ROUTE_ID: "sdk_stability_overlay_evidence_actuation"',
    'SUCCESSOR_ROUTE_ID: "native_sdk_exclusive_post_settle_actuation"',
    "walking_receipt_structurally_complete(walking_receipts, route_id)",
    "cross_route_schema_rejected"
)) {
    Assert-Drp1FreezeV2 (
        $commonSource.Contains($marker, [StringComparison]::Ordinal)
    ) "$gateId v2 shared-composer marker is missing: $marker"
}
foreach ($marker in @(
    "routeWalkingActuationKeys",
    "Get-Drp1WalkingReceiptKeys",
    "cross_route_schema_canaries",
    "walking_count_used_by_evaluator = `$false"
)) {
    Assert-Drp1FreezeV2 (
        $evaluatorSource.Contains($marker, [StringComparison]::Ordinal)
    ) "$gateId v2 evaluator marker is missing: $marker"
}

foreach ($path in @($evaluatorPath, $runnerPath, $zeroWorldGatePath)) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $path,
        [ref]$tokens,
        [ref]$parseErrors
    )
    Assert-Drp1FreezeV2 ($parseErrors.Count -eq 0) (
        "$gateId v2 PowerShell source no longer parses: $path"
    )
}

Write-Host (
    "DRP1_STAGE_TWO_FREEZE_PASS revision=2 predecessor_worlds=24 " +
    "predecessor_gates=9/12 worlds=0 cells=24 gates=12 source_bindings=$($bindings.Count) " +
    "entrypoints=24 evaluator_canaries=12 malformed_receipt_canary=1 " +
    "cross_route_evaluator_canaries=2 nested_walking_schemas=24 " +
    "cross_route_schema_rejections=24 authorization_canaries=2 " +
    "shared_outer_schema=True route_specific_nested_schema=True " +
    "regression_ready_after_clean_push=True one_shot=False selection_authority=False " +
    "walking_authority=False physical_authority=False " +
    "freeze_sha256=$(Get-Drp1FreezeV2RawSha256 -Path $freezePath)"
)
