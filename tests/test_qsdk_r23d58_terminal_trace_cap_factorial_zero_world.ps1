#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipGodot,
    [string]$Godot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\', '/')
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$contractRelativePath = "sdk/turning/r23d58_godot_terminal_trace_cap_factorial_zero_world_v1.json"
$contractPath = Join-Path $repoRoot $contractRelativePath
$releasePath = Join-Path $repoRoot "sdk/release/quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk/release/quadruped_support_matrix.json"
$ledgerBlockKey = "prospective_r23d58_terminal_trace_cap_factorial_zero_world"
$runtimeTestRelativePath = "tests/test_sdk_qsdk_r23d58_godot_terminal_trace_cap_factorial_zero_world.gd"
$runtimeTestPath = Join-Path $repoRoot $runtimeTestRelativePath
$runtimeMarker = "QSDK_R23D58_GODOT_TERMINAL_TRACE_CAP_FACTORIAL_ZERO_WORLD "
$productionRouteRuntimeTestRelativePath = "tests/test_sdk_qsdk_r23d58_godot_physical_route_cap_factorial_zero_world.gd"
$productionRouteRuntimeTestPath = Join-Path $repoRoot $productionRouteRuntimeTestRelativePath
$productionRouteRuntimeMarker = "QSDK_R23D58_GODOT_PHYSICAL_ROUTE_CAP_FACTORIAL_ZERO_WORLD "
$ordinaryRegressionTestRelativePath = "tests/test_sdk_godot_jolt_full_authority.gd"
$ordinaryRegressionTestPath = Join-Path $repoRoot $ordinaryRegressionTestRelativePath

function Assert-R23D58([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D58 ZERO-WORLD: $Message" }
}

function Get-R23D58RawSha256([string]$Path) {
    return "sha256:" + (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Copy-R23D58Document($Value) {
    return ($Value | ConvertTo-Json -Depth 100 -Compress | ConvertFrom-Json -AsHashtable -Depth 100)
}

function Find-R23D58ObjectsWithKey {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string]$Key
    )

    $found = @()
    if ($null -eq $Value) { return $found }
    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Contains($Key)) { $found += ,$Value }
        foreach ($child in $Value.Values) {
            $found += @(Find-R23D58ObjectsWithKey -Value $child -Key $Key)
        }
    } elseif ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found += @(Find-R23D58ObjectsWithKey -Value $child -Key $Key)
        }
    }
    return $found
}

function Test-R23D58ContractShape($Candidate) {
    try {
        $parent = $Candidate["immutable_parent"]
        $successor = $Candidate["scientifically_distinct_successor"]
        $hostProvenance = $Candidate["godot_jolt_host_semantics_provenance"]
        $transport = $Candidate["authoritative_json_transport"]
        $design = $Candidate["frozen_future_physical_design"]
        $adequacy = $Candidate["factor_level_provenance_and_adequacy"]
        $thresholds = $Candidate["threshold_provenance"]
        $observed = $Candidate["observed_local_zero_world_result"]
        $productionRoute = $Candidate["production_route_zero_world_integration"]
        $regression = $Candidate["ordinary_candidate35_full_authority_regression_observation"]
        $controls = $Candidate["required_negative_controls"]
        $preflightHistory = @($Candidate["prospective_campaign_preflight_history"])
        $claims = $Candidate["claims"]
        $campaign = $Candidate["prospective_campaign_execution_boundary"]
        $next = $Candidate["next_boundary"]
        return (
            [string]$Candidate["schema_version"] -ceq
                "sporespore_qsdk_r23d58_godot_terminal_trace_cap_factorial_zero_world_contract_v1" -and
            [string]$Candidate["status"] -ceq
                "prospective_campaign_machinery_implemented_complete_zero_world_gates_passed_physical_campaign_not_opened" -and
            [string]$Candidate["gate_id"] -ceq "QSDK-R23D58" -and
            [string]$Candidate["question_class"] -ceq "development" -and
            [bool]$Candidate["physical_question_declared"] -and
            -not [bool]$Candidate["physical_campaign_opened"] -and
            [string]$parent["gate_id"] -ceq "QSDK-R23D57" -and
            [string]$parent["source_commit"] -ceq
                "f0993e7e4886ff51254fb4de47f22a1bf0cc7ebe" -and
            [string]$parent["closure_raw_sha256"] -ceq
                "sha256:9270332e7d1f852c7ebe66e8c7db39d39da09c4220a22e8edc3c62ec82b31f18" -and
            [string]$parent["closure_audit_raw_sha256"] -ceq
                "sha256:679b16191c210b68419501f22c8b8db433a60faf58b577e3bdcba0e1a7ce67cf" -and
            [int]$parent["parent_world_count"] -eq 3 -and
            [int]$parent["parent_execution_valid_cell_count"] -eq 0 -and
            [int]$parent["parent_declared_cap_exact_mismatch_count"] -eq 24 -and
            [int]$parent["parent_rear_contact_cycle_count"] -eq 0 -and
            -not [bool]$parent["parent_rerun_allowed"] -and
            -not [bool]$parent["parent_result_reinterpreted"] -and
            [bool]$successor["distinct_campaign_identity_required"] -and
            [bool]$successor["r23d57_rerun_forbidden"] -and
            [int]$successor["terminal_transport_change_count"] -eq 1 -and
            [int]$successor["cap_source_factor_count"] -eq 2 -and
            [int]$successor["cap_source_level_count_per_factor"] -eq 2 -and
            [int]$successor["controller_change_count"] -eq 0 -and
            [int]$successor["morphology_change_count"] -eq 0 -and
            [int]$successor["contact_cycle_threshold_change_count"] -eq 0 -and
            [int]$successor["configured_readback_tolerance_change_count"] -eq 0 -and
            -not [bool]$successor["physical_result_exists"] -and
            [string]$hostProvenance["runtime_version"] -ceq "4.7-stable (official)" -and
            [string]$hostProvenance["upstream_tag_commit"] -ceq
                "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88" -and
            [string]$hostProvenance["source_raw_sha256"] -ceq
                "sha256:7b6c964458b4c5b9d4862f13a0cced958a240c05589aa06e14c42dc158550da7" -and
            [int]$hostProvenance["source_byte_length"] -eq 15720 -and
            -not [bool]$hostProvenance["solver_iteration_multiplier_present"] -and
            [string]$transport["transport_id"] -ceq
                "godot_4_7_sorted_full_precision_authoritative_json_v1" -and
            [string]$transport["selected_godot_invocation"] -ceq
                'JSON.stringify(value, "", true, true)' -and
            [bool]$transport["sorted_keys_required"] -and
            [bool]$transport["full_precision_required"] -and
            [bool]$transport["terminal_and_trace_must_use_same_helper"] -and
            [double]$transport["numeric_identity_margin"] -eq 0.0 -and
            [double]$transport["configured_readback_tolerance_nms"] -eq 2.5e-7 -and
            -not [bool]$transport["configured_readback_tolerance_changed"] -and
            -not [bool]$transport["r23d57_observed_deltas_used_to_set_margin"] -and
            [bool]$transport["default_precision_negative_control_required"] -and
            [bool]$transport["nextafter_up_and_down_controls_required"] -and
            [string]$design["engine_id"] -ceq "godot_jolt" -and
            [string]$design["heading_arm_id"] -ceq "reference_zero" -and
            [double]$design["heading_offset_rad"] -eq 0.0 -and
            [int]$design["seed"] -eq 21512 -and
            [int]$design["controller_step_count"] -eq 2992 -and
            [int]$design["declared_cell_count"] -eq 4 -and
            [int]$design["declared_world_count"] -eq 4 -and
            [bool]$design["serial_execution_required"] -and
            [bool]$design["all_cells_run_regardless_of_intermediate_outcome"] -and
            [bool]$design["fresh_world_required_per_cell"] -and
            [bool]$design["same_terminal_and_trace_transport_required_in_every_cell"] -and
            -not [bool]$design["turning_evaluator_invoked"] -and
            -not [bool]$design["turning_acceptance_authority"] -and
            -not [bool]$design["mechanism_selection_rule_declared"] -and
            -not [bool]$design["physical_execution_authorized"] -and
            [string]$adequacy["fixture_realized_prebinding"]["role"] -ceq
                "legacy_fixture_comparator_only" -and
            -not [bool]$adequacy["held_out_validation_performed"] -and
            -not [bool]$adequacy["population_sampling_performed"] -and
            [double]$thresholds["configured_readback_tolerance_nms"] -eq 2.5e-7 -and
            [int]$thresholds["contact_cycle_minimum_per_limb"] -eq 2 -and
            [double]$thresholds["binary64_identity_margin"] -eq 0.0 -and
            [int]$thresholds["new_outcome_threshold_count"] -eq 0 -and
            -not [bool]$thresholds["superiority_margin_declared"] -and
            -not [bool]$thresholds["equivalence_or_non_inferiority_margin_declared"] -and
            [int]$observed["ordered_profile_count"] -eq 4 -and
            [int]$observed["validated_actuator_count_per_profile"] -eq 8 -and
            [int]$observed["host_object_creation_count"] -eq 32 -and
            [int]$observed["scene_tree_insertion_count"] -eq 0 -and
            [int]$observed["write_count"] -eq 32 -and
            [int]$observed["readback_count"] -eq 32 -and
            [double]$observed["maximum_postbinding_readback_error_nms"] -le 2.5e-7 -and
            [int]$observed["binder_mutation_rejection_count"] -eq 12 -and
            [int]$observed["terminal_trace_binary64_comparison_count"] -eq 96 -and
            [int]$observed["terminal_trace_binary64_mismatch_count"] -eq 0 -and
            [int]$observed["default_precision_binary64_mismatch_count"] -eq 80 -and
            [int]$observed["transport_mutation_rejection_count"] -eq 32 -and
            [bool]$observed["transport_nextafter_up_rejected"] -and
            [bool]$observed["transport_nextafter_down_rejected"] -and
            [int]$observed["model_construction_count"] -eq 0 -and
            [int]$observed["world_attempt_count"] -eq 0 -and
            [int]$observed["world_build_count"] -eq 0 -and
            -not [bool]$observed["physical_acceptance_authority"] -and
            [string]$productionRoute["runtime_test_path"] -ceq
                "tests/test_sdk_qsdk_r23d58_godot_physical_route_cap_factorial_zero_world.gd" -and
            [string]$productionRoute["runtime_api_version"] -ceq "4.7-stable (official)" -and
            [string]$productionRoute["question_class"] -ceq "development" -and
            [int]$productionRoute["ordered_profile_count"] -eq 4 -and
            [bool]$productionRoute["physical_runner_option_normalization_exercised"] -and
            [bool]$productionRoute["physical_runner_binding_dispatch_exercised"] -and
            [bool]$productionRoute["adapter_cap_resolution_exercised"] -and
            [bool]$productionRoute["adapter_apply_authority_exercised"] -and
            [int]$productionRoute["positive_profile_host_object_creation_count"] -eq 32 -and
            [int]$productionRoute["negative_control_host_object_creation_count"] -eq 57 -and
            [int]$productionRoute["total_host_object_creation_count"] -eq 89 -and
            [int]$productionRoute["binding_write_count"] -eq 32 -and
            [int]$productionRoute["binding_readback_count"] -eq 32 -and
            [int]$productionRoute["authority_application_count"] -eq 32 -and
            [double]$productionRoute["maximum_cap_readback_error_nms"] -le 2.5e-7 -and
            [int]$productionRoute["normalization_mutation_rejection_count"] -eq 7 -and
            [int]$productionRoute["binding_route_mutation_rejection_count"] -eq 7 -and
            [int]$productionRoute["cap_resolution_mutation_rejection_count"] -eq 6 -and
            [int]$productionRoute["total_production_route_mutation_rejection_count"] -eq 20 -and
            [bool]$productionRoute["empty_override_preserves_inherited_compiled_cap_route"] -and
            [bool]$productionRoute["selected_profile_cap_vector_exposed_in_authority_receipt"] -and
            [bool]$productionRoute["configured_motor_parameters_only"] -and
            -not [bool]$productionRoute["measured_motor_torque_available"] -and
            -not [bool]$productionRoute["measured_motor_impulse_available"] -and
            [int]$productionRoute["scene_tree_insertion_count"] -eq 0 -and
            [int]$productionRoute["model_construction_count"] -eq 0 -and
            [int]$productionRoute["world_attempt_count"] -eq 0 -and
            [int]$productionRoute["world_build_count"] -eq 0 -and
            -not [bool]$productionRoute["physics_state_modified"] -and
            -not [bool]$productionRoute["physical_campaign_opened"] -and
            -not [bool]$productionRoute["physical_acceptance_authority"] -and
            [string]$regression["test_path"] -ceq
                "tests/test_sdk_godot_jolt_full_authority.gd" -and
            [string]$regression["question_class"] -ceq "development" -and
            -not [bool]$regression["campaign_identity_assigned"] -and
            -not [bool]$regression["r23d58_factorial_profile_route_exercised"] -and
            [string]$regression["controller_policy_id"] -ceq "g4_gq15_candidate35_v5" -and
            [string]$regression["runtime_api_version"] -ceq "4.7-stable (official)" -and
            [int]$regression["serialized_execution_count"] -eq 3 -and
            [int]$regression["structured_receipt_capture_count"] -eq 2 -and
            [int]$regression["world_attempt_count"] -eq 3 -and
            [int]$regression["world_build_count"] -eq 3 -and
            [string]$regression["walking_result"] -ceq "negative" -and
            [string]$regression["failure_code"] -ceq
                "PHYSICAL_WAVE_GAIT_WALKING_NOT_ESTABLISHED" -and
            [string]$regression["sole_failed_walking_gate"] -ceq
                "bounded_anchor_error" -and
            [double]$regression["inherited_maximum_anchor_error_threshold_m"] -eq 0.025 -and
            [double]$regression["observed_maximum_anchor_error_m"] -eq
                0.0318053551018238 -and
            [double]$regression["observed_to_threshold_ratio"] -eq
                1.27221420407295 -and
            -not [bool]$regression["threshold_changed_after_observation"] -and
            -not [bool]$regression["threshold_reinterpreted_after_observation"] -and
            [int]$regression["executed_tick_count_per_world"] -eq 2846 -and
            [int]$regression["native_authority_step_count_per_world"] -eq 2606 -and
            [int]$regression["native_actuation_application_count_per_world"] -eq 20848 -and
            [int]$regression["native_command_mismatch_count_per_world"] -eq 0 -and
            [string]$regression["native_authority_failure_code"] -ceq "" -and
            [int]$regression["non_outcome_test_check_pass_count"] -eq 13 -and
            [int]$regression["outcome_test_check_failure_count"] -eq 1 -and
            [int]$regression["legacy_empty_override_path_bypass_recheck_count"] -eq 1 -and
            [bool]$regression["legacy_empty_override_path_bypass_recheck_same_failure"] -and
            -not [bool]$regression["causality_attributed_to_r23d58_factorial_route"] -and
            -not [bool]$regression["turning_evaluator_invoked"] -and
            -not [bool]$regression["turning_claimed"] -and
            -not [bool]$regression["prone_to_standing_claimed"] -and
            -not [bool]$regression["physical_acceptance_authority"] -and
            -not [bool]$regression["release_authority"] -and
            @($controls["binder"]).Count -eq 12 -and
            @($controls["terminal_trace"]).Count -eq 32 -and
            @($controls["production_route_normalization"]).Count -eq 7 -and
            @($controls["production_route_binding"]).Count -eq 7 -and
            @($controls["production_route_resolution"]).Count -eq 6 -and
            $preflightHistory.Count -eq 1 -and
            [int]$preflightHistory[0]["ordinal"] -eq 1 -and
            [string]$preflightHistory[0]["source_commit"] -ceq
                "655194bfdee6f8e2e3bc3fea715d4de1aa71e292" -and
            [string]$preflightHistory[0]["status"] -ceq
                "failed_closed_zero_world_receipt_projection_mismatch" -and
            [string]$preflightHistory[0]["failure_stage"] -ceq
                "r23d55_live_fixture_cap_source_audit_receipt_projection" -and
            [int]$preflightHistory[0]["declared_total_binding_count"] -eq 19 -and
            [int]$preflightHistory[0]["observed_historical_git_binding_count"] -eq 7 -and
            [int]$preflightHistory[0]["observed_live_checkout_binding_count"] -eq 12 -and
            [int]$preflightHistory[0]["observed_successor_moved_binding_count"] -eq 2 -and
            [int]$preflightHistory[0]["stale_expected_historical_git_binding_count"] -eq 5 -and
            [int]$preflightHistory[0]["stale_expected_live_checkout_binding_count"] -eq 14 -and
            [bool]$preflightHistory[0]["underlying_r23d55_audit_passed"] -and
            [bool]$preflightHistory[0]["failure_was_supervisor_receipt_projection_only"] -and
            -not [bool]$preflightHistory[0]["output_root_created"] -and
            [int]$preflightHistory[0]["world_attempt_count"] -eq 0 -and
            [int]$preflightHistory[0]["world_build_count"] -eq 0 -and
            -not [bool]$preflightHistory[0]["physical_attempt_identity_consumed"] -and
            -not [bool]$preflightHistory[0]["same_source_preflight_rerun_allowed"] -and
            -not [bool]$preflightHistory[0]["result_reinterpreted"] -and
            [bool]$preflightHistory[0]["repair_implemented_in_distinct_source"] -and
            [bool]$claims["implementation_complete_for_local_zero_world_gate"] -and
            [bool]$claims["local_zero_world_gate_passed"] -and
            [bool]$claims["terminal_and_trace_full_precision_transport_shared"] -and
            [bool]$claims["cap_source_factorial_surface_reachable_without_world"] -and
            [bool]$claims["declared_factorial_profiles_integrated_into_production_physical_route"] -and
            [bool]$claims["production_physical_route_zero_world_gate_passed"] -and
            [bool]$claims["ordinary_candidate35_full_authority_regression_negative_retained"] -and
            -not [bool]$claims["ordinary_candidate35_full_authority_regression_passed"] -and
            -not [bool]$claims["r23d57_result_changed"] -and
            -not [bool]$claims["r23d57_rerun_authorized"] -and
            [bool]$claims["prospective_campaign_identity_reserved"] -and
            [bool]$claims["prospective_campaign_machinery_implemented"] -and
            [bool]$claims["complete_campaign_zero_world_gate_passed"] -and
            -not [bool]$claims["fresh_clean_pushed_source_qualification_passed"] -and
            -not [bool]$claims["campaign_attestation_adoption_passed"] -and
            -not [bool]$claims["physical_campaign_opened"] -and
            -not [bool]$claims["physical_world_opened"] -and
            -not [bool]$claims["rear_contact_mechanism_selected"] -and
            -not [bool]$claims["compiled_cap_causality_established"] -and
            -not [bool]$claims["godot_jolt_turning"] -and
            -not [bool]$claims["portable_basic_turning"] -and
            -not [bool]$claims["prone_to_standing"] -and
            -not [bool]$claims["physical_acceptance_authority"] -and
            -not [bool]$claims["release_authority"] -and
            [string]$campaign["declaration_authority_path"] -ceq
                "sdk/turning/r23d58_godot_terminal_trace_cap_factorial_zero_world_v1.json" -and
            [string]$campaign["design_module_path"] -ceq
                "sdk/turning/r23d58_godot_cap_source_factorial.py" -and
            [string]$campaign["implementation_contract_path"] -ceq
                "sdk/turning/r23d58_godot_cap_source_factorial_implementation_v1.json" -and
            [string]$campaign["worker_path"] -ceq
                "tests/test_sdk_qsdk_r23d58_godot_jolt_physical_worker.gd" -and
            [string]$campaign["evaluator_path"] -ceq
                "sdk/turning/r23d58_godot_cap_source_factorial_evaluator.py" -and
            [string]$campaign["supervisor_path"] -ceq
                "sdk/run_qsdk_r23d58_supervisor.ps1" -and
            [string]$campaign["attestation_manifest_path"] -ceq
                "sdk/turning/r23d58_campaign_attestation_manifest_v1.json" -and
            [string]$campaign["campaign_id"] -ceq
                "QSDK-R23D58-GODOT-CAP-SOURCE-FACTORIAL-REAR-CONTACT-MECHANISM-DEVELOPMENT" -and
            [string]$campaign["question_class"] -ceq "development" -and
            [int]$campaign["declared_cell_count"] -eq 4 -and
            [int]$campaign["declared_world_count"] -eq 4 -and
            [bool]$campaign["serial_execution_required"] -and
            [bool]$campaign["fresh_world_required_per_cell"] -and
            [bool]$campaign["all_cells_run_regardless_of_intermediate_outcome"] -and
            -not [bool]$campaign["turning_evaluator_invoked"] -and
            -not [bool]$campaign["mechanism_selection_rule_declared"] -and
            -not [bool]$campaign["physical_execution_authorized"] -and
            [bool]$next["prospective_physical_campaign_id_reserved"] -and
            -not [bool]$next["future_worker_evaluator_supervisor_and_manifest_required"] -and
            [bool]$next["complete_zero_world_campaign_gate_and_negative_controls_passed"] -and
            -not [bool]$next["r23d58_physical_execution_authorized"] -and
            [bool]$next["future_worker_must_use_integrated_production_profile_route"] -and
            [bool]$next["candidate35_regression_does_not_authorize_rethreshold_or_profile_selection"] -and
            -not [bool]$next["turning_successor_authorized"] -and
            -not [bool]$next["prone_to_standing_successor_authorized"]
        )
    } catch {
        return $false
    }
}

foreach ($path in @(
    $contractPath,
    $releasePath,
    $supportPath,
    $runtimeTestPath,
    $productionRouteRuntimeTestPath,
    $ordinaryRegressionTestPath
)) {
    Assert-R23D58 (Test-Path -LiteralPath $path -PathType Leaf) "Missing authority: $path"
}

$observedRoot = [IO.Path]::GetFullPath((& git -C $repoRoot rev-parse --show-toplevel).Trim()).TrimEnd('\', '/')
Assert-R23D58 ($LASTEXITCODE -eq 0) "Unable to resolve repository root."
$observedRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D58 ($LASTEXITCODE -eq 0) "Unable to resolve origin remote."
Assert-R23D58 ($observedRoot -ceq $repoRoot) "Repository root changed: $observedRoot"
Assert-R23D58 ($observedRemote -ceq $expectedRemote) "Origin remote changed: $observedRemote"

$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$release = Get-Content -LiteralPath $releasePath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$support = Get-Content -LiteralPath $supportPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D58 (Test-R23D58ContractShape $contract) "Contract identity, design, threshold, or claim boundary changed."

$bindings = @($contract["source_binding_policy"]["bindings"])
Assert-R23D58 (
    [int]$contract["source_binding_policy"]["binding_count"] -eq 15 -and
    $bindings.Count -eq 15 -and
    @($bindings.path | Sort-Object -Unique).Count -eq 15
) "Source binding cardinality or uniqueness changed."
foreach ($binding in $bindings) {
    $relativePath = [string]$binding["path"]
    $path = Join-Path $repoRoot $relativePath
    Assert-R23D58 (Test-Path -LiteralPath $path -PathType Leaf) "Bound source missing: $relativePath"
    Assert-R23D58 (
        (Get-R23D58RawSha256 $path) -ceq [string]$binding["raw_sha256"]
    ) "Bound source digest changed: $relativePath"
}

$attributes = Get-Content -LiteralPath (Join-Path $repoRoot ".gitattributes") -Raw
foreach ($rule in @(
    "sdk/turning/r23d58_* text eol=lf",
    "sdk/run_qsdk_r23d58_* text eol=lf",
    "tests/test_qsdk_r23d58_* text eol=lf",
    "tests/test_sdk_qsdk_r23d58_* text eol=lf",
    "scripts/lab/gait/sdk_godot_jolt_live_fixture_actuator_cap_factorial_binding.gd text eol=lf"
)) {
    Assert-R23D58 ($attributes.Contains($rule)) "Missing R23D58 checkout rule: $rule"
}

$transportSource = Get-Content -LiteralPath (
    Join-Path $repoRoot "sdk/trace_analysis/godot_authoritative_json_transport.gd"
) -Raw
$binderSource = Get-Content -LiteralPath (
    Join-Path $repoRoot "scripts/lab/gait/sdk_godot_jolt_live_fixture_actuator_cap_factorial_binding.gd"
) -Raw
$validatorSource = Get-Content -LiteralPath (
    Join-Path $repoRoot "sdk/turning/r23d58_terminal_trace_cap_factorial_zero_world.py"
) -Raw
$runtimeSource = Get-Content -LiteralPath $runtimeTestPath -Raw
$productionRouteRuntimeSource = Get-Content -LiteralPath $productionRouteRuntimeTestPath -Raw
$physicalRunnerSource = Get-Content -LiteralPath (
    Join-Path $repoRoot "scripts/lab/gait/physical_wave_gait_quadruped.gd"
) -Raw
$adapterSource = Get-Content -LiteralPath (
    Join-Path $repoRoot "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
) -Raw
foreach ($token in @(
    'JSON.stringify(value, "", true, true)',
    "godot_4_7_sorted_full_precision_authoritative_json_v1"
)) {
    Assert-R23D58 ($transportSource.Contains($token)) "Transport helper missing token: $token"
}
foreach ($token in @(
    "two_by_two_hip_source_x_knee_source",
    "portable_hip__portable_knee",
    "portable_hip__fixture_knee",
    "fixture_hip__portable_knee",
    "fixture_hip__fixture_knee",
    "complete_surface_validated_before_first_write"
)) {
    Assert-R23D58 ($binderSource.Contains($token)) "Factorial binder missing token: $token"
}
foreach ($token in @(
    "exact IEEE-754 binary64 identity",
    "default_terminal_precision_rejected",
    "terminal_cap_nextafter_up_rejected",
    "terminal_cap_nextafter_down_rejected"
)) {
    Assert-R23D58 ($validatorSource.Contains($token)) "Python validator missing token: $token"
}
foreach ($control in @($contract["required_negative_controls"]["binder"])) {
    Assert-R23D58 ($runtimeSource.Contains([string]$control)) "Runtime gate missing binder control: $control"
}
foreach ($control in @($contract["required_negative_controls"]["terminal_trace"])) {
    Assert-R23D58 ($validatorSource.Contains([string]$control)) "Validator missing transport control: $control"
}
foreach ($controlGroup in @(
    "production_route_normalization",
    "production_route_binding",
    "production_route_resolution"
)) {
    foreach ($control in @($contract["required_negative_controls"][$controlGroup])) {
        Assert-R23D58 (
            $productionRouteRuntimeSource.Contains([string]$control)
        ) "Production-route runtime gate missing $controlGroup control: $control"
    }
}
foreach ($token in @(
    "bind_sdk_live_fixture_actuator_cap_route",
    "resolve_authorized_maximum_impulse_by_actuator_id",
    "adapter.apply_authority",
    "maximum_impulse_override_applied",
    "scene_tree_insertion_count"
)) {
    Assert-R23D58 (
        $productionRouteRuntimeSource.Contains($token)
    ) "Production-route runtime gate missing route token: $token"
}
foreach ($token in @(
    "SDK_AUTHORITY_CONTROLLER_MATERIAL_ORIGIN_CAP_FACTORIAL_BINDING_OPTION_KEYS",
    "bind_sdk_live_fixture_actuator_cap_route(",
    "sdk_live_fixture_actuator_cap_override_by_actuator_id",
    '"live_fixture_actuator_cap_binding_profile_id"'
)) {
    Assert-R23D58 (
        $physicalRunnerSource.Contains($token)
    ) "Production physical runner missing factorial route token: $token"
}
foreach ($token in @(
    "resolve_authorized_maximum_impulse_by_actuator_id(",
    "maximum_impulse_override_by_actuator_id: Dictionary = {}",
    'result["maximum_impulse_override_applied"]',
    'result["authorized_maximum_impulse_by_actuator_id"]'
)) {
    Assert-R23D58 (
        $adapterSource.Contains($token)
    ) "Godot/Jolt adapter missing profile-cap authority token: $token"
}

$mutationSpecs = @(
    @{ name = "status"; mutate = { param($d) $d["status"] = "mutated" } },
    @{ name = "question_class"; mutate = { param($d) $d["question_class"] = "superiority" } },
    @{ name = "physical_open"; mutate = { param($d) $d["physical_campaign_opened"] = $true } },
    @{ name = "parent_rerun"; mutate = { param($d) $d["immutable_parent"]["parent_rerun_allowed"] = $true } },
    @{ name = "parent_reinterpret"; mutate = { param($d) $d["immutable_parent"]["parent_result_reinterpreted"] = $true } },
    @{ name = "transport_margin"; mutate = { param($d) $d["authoritative_json_transport"]["numeric_identity_margin"] = 1e-15 } },
    @{ name = "full_precision"; mutate = { param($d) $d["authoritative_json_transport"]["full_precision_required"] = $false } },
    @{ name = "profile_count"; mutate = { param($d) $d["frozen_future_physical_design"]["declared_cell_count"] = 3 } },
    @{ name = "world_count"; mutate = { param($d) $d["frozen_future_physical_design"]["declared_world_count"] = 3 } },
    @{ name = "turning_gate"; mutate = { param($d) $d["frozen_future_physical_design"]["turning_evaluator_invoked"] = $true } },
    @{ name = "readback_tolerance"; mutate = { param($d) $d["threshold_provenance"]["configured_readback_tolerance_nms"] = 5e-7 } },
    @{ name = "contact_threshold"; mutate = { param($d) $d["threshold_provenance"]["contact_cycle_minimum_per_limb"] = 1 } },
    @{ name = "new_threshold"; mutate = { param($d) $d["threshold_provenance"]["new_outcome_threshold_count"] = 1 } },
    @{ name = "observed_world"; mutate = { param($d) $d["observed_local_zero_world_result"]["world_build_count"] = 1 } },
    @{ name = "binary_mismatch"; mutate = { param($d) $d["observed_local_zero_world_result"]["terminal_trace_binary64_mismatch_count"] = 1 } },
    @{ name = "production_route_world"; mutate = { param($d) $d["production_route_zero_world_integration"]["world_build_count"] = 1 } },
    @{ name = "production_route_applications"; mutate = { param($d) $d["production_route_zero_world_integration"]["authority_application_count"] = 31 } },
    @{ name = "production_route_mutations"; mutate = { param($d) $d["production_route_zero_world_integration"]["total_production_route_mutation_rejection_count"] = 19 } },
    @{ name = "regression_world_count"; mutate = { param($d) $d["ordinary_candidate35_full_authority_regression_observation"]["world_build_count"] = 2 } },
    @{ name = "regression_threshold_changed"; mutate = { param($d) $d["ordinary_candidate35_full_authority_regression_observation"]["threshold_changed_after_observation"] = $true } },
    @{ name = "regression_factorial_route"; mutate = { param($d) $d["ordinary_candidate35_full_authority_regression_observation"]["r23d58_factorial_profile_route_exercised"] = $true } },
    @{ name = "regression_passed"; mutate = { param($d) $d["claims"]["ordinary_candidate35_full_authority_regression_passed"] = $true } },
    @{ name = "mechanism"; mutate = { param($d) $d["claims"]["rear_contact_mechanism_selected"] = $true } },
    @{ name = "production_route_gate"; mutate = { param($d) $d["claims"]["production_physical_route_zero_world_gate_passed"] = $false } },
    @{ name = "campaign_worker_path"; mutate = { param($d) $d["prospective_campaign_execution_boundary"]["worker_path"] = "mutated" } },
    @{ name = "campaign_zero_world_claim"; mutate = { param($d) $d["claims"]["complete_campaign_zero_world_gate_passed"] = $false } },
    @{ name = "preflight_history_rerun"; mutate = { param($d) $d["prospective_campaign_preflight_history"][0]["same_source_preflight_rerun_allowed"] = $true } },
    @{ name = "turning"; mutate = { param($d) $d["claims"]["godot_jolt_turning"] = $true } },
    @{ name = "prone"; mutate = { param($d) $d["claims"]["prone_to_standing"] = $true } },
    @{ name = "release"; mutate = { param($d) $d["claims"]["release_authority"] = $true } },
    @{ name = "physical_authority"; mutate = { param($d) $d["next_boundary"]["r23d58_physical_execution_authorized"] = $true } }
)
foreach ($mutation in $mutationSpecs) {
    $candidate = Copy-R23D58Document $contract
    & $mutation.mutate $candidate
    Assert-R23D58 (-not (Test-R23D58ContractShape $candidate)) (
        "Contract mutation was accepted: $($mutation.name)"
    )
}

$releaseParents = @(Find-R23D58ObjectsWithKey -Value $release -Key $ledgerBlockKey)
$supportParents = @(Find-R23D58ObjectsWithKey -Value $support -Key $ledgerBlockKey)
Assert-R23D58 ($releaseParents.Count -eq 1) "Release ledger must expose exactly one R23D58 block."
Assert-R23D58 ($supportParents.Count -eq 1) "Support ledger must expose exactly one R23D58 block."
$releaseBlock = $releaseParents[0][$ledgerBlockKey]
$supportBlock = $supportParents[0][$ledgerBlockKey]
$mirroredKeys = @(
    "gate_id", "work_id", "campaign_id", "status", "question_class", "contract_path",
    "contract_raw_sha256", "audit_path", "audit_raw_sha256", "runtime_test_path",
    "runtime_test_raw_sha256", "production_route_runtime_test_path",
    "production_route_runtime_test_raw_sha256", "ordinary_full_authority_regression_test_path",
    "ordinary_full_authority_regression_test_raw_sha256", "transport_helper_path", "transport_helper_raw_sha256",
    "factorial_binder_path", "factorial_binder_raw_sha256", "python_validator_path",
    "python_validator_raw_sha256", "physical_design_path", "physical_design_raw_sha256",
    "physical_implementation_path", "physical_implementation_raw_sha256",
    "physical_evaluator_path", "physical_evaluator_raw_sha256",
    "physical_worker_path", "physical_worker_raw_sha256",
    "physical_lineage_audit_path", "physical_lineage_audit_raw_sha256",
    "physical_campaign_roles_audit_path", "physical_campaign_roles_audit_raw_sha256",
    "physical_supervisor_path", "physical_supervisor_raw_sha256",
    "physical_campaign_attestation_manifest_path",
    "physical_question_declared", "physical_campaign_opened",
    "ordered_profile_count", "declared_future_world_count", "observed_world_count",
    "write_count", "readback_count", "terminal_trace_binary64_comparison_count",
    "terminal_trace_binary64_mismatch_count", "default_precision_binary64_mismatch_count",
    "binder_mutation_rejection_count", "transport_mutation_rejection_count",
    "production_route_binding_write_count", "production_route_binding_readback_count",
    "production_route_authority_application_count",
    "production_route_mutation_rejection_count", "production_route_observed_world_count",
    "production_route_zero_world_gate_passed",
    "ordinary_full_authority_regression_execution_count",
    "ordinary_full_authority_regression_world_count",
    "ordinary_full_authority_regression_passed",
    "ordinary_full_authority_regression_failure_gate",
    "ordinary_full_authority_regression_observed_anchor_error_m",
    "ordinary_full_authority_regression_threshold_m",
    "ordinary_full_authority_factorial_route_exercised",
    "physical_implementation_complete", "physical_worker_complete",
    "physical_evaluator_complete", "physical_supervisor_complete",
    "campaign_attestation_manifest_complete",
    "complete_zero_world_campaign_gate_passed", "scoped_qualification_passed",
    "adoption_passed", "physical_execution_authorized",
    "first_clean_pushed_campaign_preflight_source_commit",
    "first_clean_pushed_campaign_preflight_passed",
    "first_clean_pushed_campaign_preflight_failure_stage",
    "first_clean_pushed_campaign_preflight_failure_message",
    "first_clean_pushed_campaign_preflight_declared_binding_count",
    "first_clean_pushed_campaign_preflight_observed_historical_git_binding_count",
    "first_clean_pushed_campaign_preflight_observed_live_checkout_binding_count",
    "first_clean_pushed_campaign_preflight_observed_successor_moved_binding_count",
    "first_clean_pushed_campaign_preflight_stale_expected_historical_git_binding_count",
    "first_clean_pushed_campaign_preflight_stale_expected_live_checkout_binding_count",
    "first_clean_pushed_campaign_preflight_output_root_created",
    "first_clean_pushed_campaign_preflight_world_attempt_count",
    "first_clean_pushed_campaign_preflight_world_build_count",
    "first_clean_pushed_campaign_preflight_physical_attempt_identity_consumed",
    "first_clean_pushed_campaign_preflight_same_source_rerun_allowed",
    "cap_source_audit_receipt_projection_repair_implemented",
    "repair_clean_pushed_preflight_pending",
    "configured_readback_tolerance_nms", "contact_cycle_threshold_changed",
    "mechanism_selected", "turning_acceptance", "prone_to_standing",
    "physical_acceptance_authority", "release_authority"
)
foreach ($key in $mirroredKeys) {
    Assert-R23D58 ($releaseBlock.Contains($key)) "Release R23D58 block missing $key."
    Assert-R23D58 ($supportBlock.Contains($key)) "Support R23D58 block missing $key."
    Assert-R23D58 (
        [string]$releaseBlock[$key] -ceq [string]$supportBlock[$key]
    ) "Release/support R23D58 value differs: $key"
}
foreach ($bindingPair in @(
    @("contract_path", "contract_raw_sha256"),
    @("audit_path", "audit_raw_sha256"),
    @("runtime_test_path", "runtime_test_raw_sha256"),
    @("production_route_runtime_test_path", "production_route_runtime_test_raw_sha256"),
    @("ordinary_full_authority_regression_test_path", "ordinary_full_authority_regression_test_raw_sha256"),
    @("transport_helper_path", "transport_helper_raw_sha256"),
    @("factorial_binder_path", "factorial_binder_raw_sha256"),
    @("python_validator_path", "python_validator_raw_sha256"),
    @("physical_design_path", "physical_design_raw_sha256"),
    @("physical_implementation_path", "physical_implementation_raw_sha256"),
    @("physical_evaluator_path", "physical_evaluator_raw_sha256"),
    @("physical_worker_path", "physical_worker_raw_sha256"),
    @("physical_lineage_audit_path", "physical_lineage_audit_raw_sha256"),
    @("physical_campaign_roles_audit_path", "physical_campaign_roles_audit_raw_sha256"),
    @("physical_supervisor_path", "physical_supervisor_raw_sha256")
)) {
    $path = Join-Path $repoRoot ([string]$releaseBlock[$bindingPair[0]])
    Assert-R23D58 (Test-Path -LiteralPath $path -PathType Leaf) "Mirrored path missing: $path"
    Assert-R23D58 (
        (Get-R23D58RawSha256 $path) -ceq [string]$releaseBlock[$bindingPair[1]]
    ) "Mirrored digest changed: $path"
}
Assert-R23D58 (
    [string]$releaseBlock["gate_id"] -ceq "QSDK-R23D58" -and
    [string]$releaseBlock["campaign_id"] -ceq
        "QSDK-R23D58-GODOT-CAP-SOURCE-FACTORIAL-REAR-CONTACT-MECHANISM-DEVELOPMENT" -and
    [string]$releaseBlock["status"] -ceq
        "prospective_campaign_machinery_implemented_complete_zero_world_gates_passed_physical_campaign_not_opened" -and
    [string]$releaseBlock["question_class"] -ceq "development" -and
    [bool]$releaseBlock["physical_question_declared"] -and
    -not [bool]$releaseBlock["physical_campaign_opened"] -and
    [int]$releaseBlock["ordered_profile_count"] -eq 4 -and
    [int]$releaseBlock["declared_future_world_count"] -eq 4 -and
    [int]$releaseBlock["observed_world_count"] -eq 0 -and
    [int]$releaseBlock["write_count"] -eq 32 -and
    [int]$releaseBlock["readback_count"] -eq 32 -and
    [int]$releaseBlock["terminal_trace_binary64_comparison_count"] -eq 96 -and
    [int]$releaseBlock["terminal_trace_binary64_mismatch_count"] -eq 0 -and
    [int]$releaseBlock["default_precision_binary64_mismatch_count"] -eq 80 -and
    [int]$releaseBlock["binder_mutation_rejection_count"] -eq 12 -and
    [int]$releaseBlock["transport_mutation_rejection_count"] -eq 32 -and
    [int]$releaseBlock["production_route_binding_write_count"] -eq 32 -and
    [int]$releaseBlock["production_route_binding_readback_count"] -eq 32 -and
    [int]$releaseBlock["production_route_authority_application_count"] -eq 32 -and
    [int]$releaseBlock["production_route_mutation_rejection_count"] -eq 20 -and
    [int]$releaseBlock["production_route_observed_world_count"] -eq 0 -and
    [bool]$releaseBlock["production_route_zero_world_gate_passed"] -and
    [int]$releaseBlock["ordinary_full_authority_regression_execution_count"] -eq 3 -and
    [int]$releaseBlock["ordinary_full_authority_regression_world_count"] -eq 3 -and
    -not [bool]$releaseBlock["ordinary_full_authority_regression_passed"] -and
    [string]$releaseBlock["ordinary_full_authority_regression_failure_gate"] -ceq
        "bounded_anchor_error" -and
    [double]$releaseBlock["ordinary_full_authority_regression_observed_anchor_error_m"] -eq
        0.0318053551018238 -and
    [double]$releaseBlock["ordinary_full_authority_regression_threshold_m"] -eq 0.025 -and
    -not [bool]$releaseBlock["ordinary_full_authority_factorial_route_exercised"] -and
    [bool]$releaseBlock["physical_implementation_complete"] -and
    [bool]$releaseBlock["physical_worker_complete"] -and
    [bool]$releaseBlock["physical_evaluator_complete"] -and
    [bool]$releaseBlock["physical_supervisor_complete"] -and
    [bool]$releaseBlock["campaign_attestation_manifest_complete"] -and
    [bool]$releaseBlock["complete_zero_world_campaign_gate_passed"] -and
    -not [bool]$releaseBlock["scoped_qualification_passed"] -and
    -not [bool]$releaseBlock["adoption_passed"] -and
    -not [bool]$releaseBlock["physical_execution_authorized"] -and
    [string]$releaseBlock["first_clean_pushed_campaign_preflight_source_commit"] -ceq
        "655194bfdee6f8e2e3bc3fea715d4de1aa71e292" -and
    -not [bool]$releaseBlock["first_clean_pushed_campaign_preflight_passed"] -and
    [string]$releaseBlock["first_clean_pushed_campaign_preflight_failure_stage"] -ceq
        "r23d55_live_fixture_cap_source_audit_receipt_projection" -and
    [string]$releaseBlock["first_clean_pushed_campaign_preflight_failure_message"] -ceq
        "QSDK-R23D58: R23D55 cap source-audit receipt changed" -and
    [int]$releaseBlock["first_clean_pushed_campaign_preflight_declared_binding_count"] -eq 19 -and
    [int]$releaseBlock["first_clean_pushed_campaign_preflight_observed_historical_git_binding_count"] -eq 7 -and
    [int]$releaseBlock["first_clean_pushed_campaign_preflight_observed_live_checkout_binding_count"] -eq 12 -and
    [int]$releaseBlock["first_clean_pushed_campaign_preflight_observed_successor_moved_binding_count"] -eq 2 -and
    [int]$releaseBlock["first_clean_pushed_campaign_preflight_stale_expected_historical_git_binding_count"] -eq 5 -and
    [int]$releaseBlock["first_clean_pushed_campaign_preflight_stale_expected_live_checkout_binding_count"] -eq 14 -and
    -not [bool]$releaseBlock["first_clean_pushed_campaign_preflight_output_root_created"] -and
    [int]$releaseBlock["first_clean_pushed_campaign_preflight_world_attempt_count"] -eq 0 -and
    [int]$releaseBlock["first_clean_pushed_campaign_preflight_world_build_count"] -eq 0 -and
    -not [bool]$releaseBlock["first_clean_pushed_campaign_preflight_physical_attempt_identity_consumed"] -and
    -not [bool]$releaseBlock["first_clean_pushed_campaign_preflight_same_source_rerun_allowed"] -and
    [bool]$releaseBlock["cap_source_audit_receipt_projection_repair_implemented"] -and
    [bool]$releaseBlock["repair_clean_pushed_preflight_pending"] -and
    [double]$releaseBlock["configured_readback_tolerance_nms"] -eq 2.5e-7 -and
    -not [bool]$releaseBlock["contact_cycle_threshold_changed"] -and
    -not [bool]$releaseBlock["mechanism_selected"] -and
    -not [bool]$releaseBlock["turning_acceptance"] -and
    -not [bool]$releaseBlock["prone_to_standing"] -and
    -not [bool]$releaseBlock["physical_acceptance_authority"] -and
    -not [bool]$releaseBlock["release_authority"]
) "R23D58 ledger claims broadened."

$runtimeExecuted = $false
$productionRouteRuntimeExecuted = $false
if (-not $SkipGodot) {
    if ([string]::IsNullOrWhiteSpace($Godot)) {
        $command = Get-Command "Godot_v4.7-stable_win64_console.exe" -ErrorAction SilentlyContinue
        if ($null -eq $command) { $command = Get-Command "godot" -ErrorAction SilentlyContinue }
        Assert-R23D58 ($null -ne $command) "Godot 4.7 executable is unavailable."
        $Godot = $command.Source
    }
    Assert-R23D58 (Test-Path -LiteralPath $Godot -PathType Leaf) "Godot executable missing: $Godot"
    $pythonCommand = Get-Command "python" -ErrorAction Stop
    $priorPython = [Environment]::GetEnvironmentVariable(
        "SPORESPORE_QSDK_R23D58_PYTHON_PATH",
        [EnvironmentVariableTarget]::Process
    )
    try {
        [Environment]::SetEnvironmentVariable(
            "SPORESPORE_QSDK_R23D58_PYTHON_PATH",
            $pythonCommand.Source,
            [EnvironmentVariableTarget]::Process
        )
        $output = @(& $Godot --headless --path $repoRoot --script (
            "res://" + $runtimeTestRelativePath.Replace('\', '/')
        ) 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        [Environment]::SetEnvironmentVariable(
            "SPORESPORE_QSDK_R23D58_PYTHON_PATH",
            $priorPython,
            [EnvironmentVariableTarget]::Process
        )
    }
    Assert-R23D58 ($exitCode -eq 0) "Godot runtime gate failed: $($output -join [Environment]::NewLine)"
    $markers = @(
        $output |
            ForEach-Object { [string]$_ } |
            Where-Object { $_.StartsWith($runtimeMarker, [StringComparison]::Ordinal) }
    )
    Assert-R23D58 ($markers.Count -eq 1) "Godot runtime gate emitted $($markers.Count) markers."
    $runtime = $markers[0].Substring($runtimeMarker.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
    $observed = $contract["observed_local_zero_world_result"]
    Assert-R23D58 (
        [bool]$runtime["ok"] -and
        [string]$runtime["runtime_api_version"] -ceq [string]$observed["runtime_api_version"] -and
        [int]$runtime["profile_count"] -eq [int]$observed["ordered_profile_count"] -and
        [int]$runtime["write_count"] -eq [int]$observed["write_count"] -and
        [int]$runtime["readback_count"] -eq [int]$observed["readback_count"] -and
        [double]$runtime["maximum_postbinding_readback_error_nms"] -eq
            [double]$observed["maximum_postbinding_readback_error_nms"] -and
        [double]$runtime["maximum_portable_fixture_absolute_delta_nms"] -eq
            [double]$observed["maximum_portable_fixture_absolute_delta_nms"] -and
        [int]$runtime["binder_mutation_rejection_count"] -eq
            [int]$observed["binder_mutation_rejection_count"] -and
        [int]$runtime["terminal_trace_binary64_comparison_count"] -eq
            [int]$observed["terminal_trace_binary64_comparison_count"] -and
        [int]$runtime["terminal_trace_binary64_mismatch_count"] -eq 0 -and
        [int]$runtime["default_precision_binary64_mismatch_count"] -eq
            [int]$observed["default_precision_binary64_mismatch_count"] -and
        [int]$runtime["transport_mutation_rejection_count"] -eq
            [int]$observed["transport_mutation_rejection_count"] -and
        [int]$runtime["model_construction_count"] -eq 0 -and
        [int]$runtime["world_attempt_count"] -eq 0 -and
        [int]$runtime["world_build_count"] -eq 0 -and
        -not [bool]$runtime["physical_campaign_opened"] -and
        -not [bool]$runtime["turning_claimed"] -and
        -not [bool]$runtime["prone_to_standing_claimed"] -and
        -not [bool]$runtime["physical_acceptance_authority"] -and
        -not [bool]$runtime["release_authority"]
    ) "Godot runtime receipt differs from the bounded zero-world observation."
    $runtimeExecuted = $true

    $productionRouteOutput = @(& $Godot --headless --path $repoRoot --script (
        "res://" + $productionRouteRuntimeTestRelativePath.Replace('\', '/')
    ) 2>&1)
    $productionRouteExitCode = $LASTEXITCODE
    Assert-R23D58 ($productionRouteExitCode -eq 0) (
        "Godot production-route runtime gate failed: " +
        ($productionRouteOutput -join [Environment]::NewLine)
    )
    $productionRouteMarkers = @(
        $productionRouteOutput |
            ForEach-Object { [string]$_ } |
            Where-Object {
                $_.StartsWith($productionRouteRuntimeMarker, [StringComparison]::Ordinal)
            }
    )
    Assert-R23D58 ($productionRouteMarkers.Count -eq 1) (
        "Godot production-route runtime gate emitted $($productionRouteMarkers.Count) markers."
    )
    $productionRouteRuntime = $productionRouteMarkers[0].Substring(
        $productionRouteRuntimeMarker.Length
    ) | ConvertFrom-Json -AsHashtable -Depth 100
    $productionRouteObserved = $contract["production_route_zero_world_integration"]
    Assert-R23D58 (
        [bool]$productionRouteRuntime["ok"] -and
        [string]$productionRouteRuntime["runtime_api_version"] -ceq
            [string]$productionRouteObserved["runtime_api_version"] -and
        [int]$productionRouteRuntime["profile_count"] -eq
            [int]$productionRouteObserved["ordered_profile_count"] -and
        [bool]$productionRouteRuntime["physical_runner_option_normalization_exercised"] -and
        [bool]$productionRouteRuntime["physical_runner_binding_dispatch_exercised"] -and
        [bool]$productionRouteRuntime["adapter_cap_resolution_exercised"] -and
        [bool]$productionRouteRuntime["adapter_apply_authority_exercised"] -and
        [int]$productionRouteRuntime["positive_profile_host_object_creation_count"] -eq
            [int]$productionRouteObserved["positive_profile_host_object_creation_count"] -and
        [int]$productionRouteRuntime["negative_control_host_object_creation_count"] -eq
            [int]$productionRouteObserved["negative_control_host_object_creation_count"] -and
        [int]$productionRouteRuntime["total_host_object_creation_count"] -eq
            [int]$productionRouteObserved["total_host_object_creation_count"] -and
        [int]$productionRouteRuntime["write_count"] -eq
            [int]$productionRouteObserved["binding_write_count"] -and
        [int]$productionRouteRuntime["binding_readback_count"] -eq
            [int]$productionRouteObserved["binding_readback_count"] -and
        [int]$productionRouteRuntime["authority_application_count"] -eq
            [int]$productionRouteObserved["authority_application_count"] -and
        [double]$productionRouteRuntime["maximum_cap_readback_error_nms"] -eq
            [double]$productionRouteObserved["maximum_cap_readback_error_nms"] -and
        [int]$productionRouteRuntime["normalization_mutation_rejection_count"] -eq
            [int]$productionRouteObserved["normalization_mutation_rejection_count"] -and
        [int]$productionRouteRuntime["route_mutation_rejection_count"] -eq
            [int]$productionRouteObserved["binding_route_mutation_rejection_count"] -and
        [int]$productionRouteRuntime["resolution_mutation_rejection_count"] -eq
            [int]$productionRouteObserved["cap_resolution_mutation_rejection_count"] -and
        [bool]$productionRouteRuntime["empty_override_preserves_compiled_caps"] -and
        [int]$productionRouteRuntime["scene_tree_insertion_count"] -eq 0 -and
        [int]$productionRouteRuntime["model_construction_count"] -eq 0 -and
        [int]$productionRouteRuntime["world_attempt_count"] -eq 0 -and
        [int]$productionRouteRuntime["world_build_count"] -eq 0 -and
        -not [bool]$productionRouteRuntime["physics_state_modified"] -and
        -not [bool]$productionRouteRuntime["physical_campaign_opened"] -and
        -not [bool]$productionRouteRuntime["turning_claimed"] -and
        -not [bool]$productionRouteRuntime["prone_to_standing_claimed"] -and
        -not [bool]$productionRouteRuntime["physical_acceptance_authority"] -and
        -not [bool]$productionRouteRuntime["release_authority"]
    ) "Godot production-route receipt differs from the bounded zero-world integration."
    $productionRouteRuntimeExecuted = $true
}

$contractHash = Get-R23D58RawSha256 $contractPath
$auditHash = Get-R23D58RawSha256 $PSCommandPath
Write-Host (
    "QSDK_R23D58_ZERO_WORLD_PASS question=development profiles=4 future_worlds=4 " +
    "observed_worlds=0 writes=32 readbacks=32 binary64=96 mismatches=0 " +
    "default_mismatches=80 binder_mutations=12 transport_mutations=32 " +
    "route_writes=32 route_readbacks=32 route_applications=32 route_mutations=20 " +
    "campaign_worlds=0 regression_worlds=3 regression_passed=False " +
    "contract_mutations=$($mutationSpecs.Count) runtime=$runtimeExecuted " +
    "route_runtime=$productionRouteRuntimeExecuted turning=False prone=False " +
    "r23d58_campaign_physical=False release=False contract_sha256=$contractHash audit_sha256=$auditHash"
)
