#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd(
    '\', '/'
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$contractPath = Join-Path $repoRoot (
    "sdk\turning\" +
    "r23d57_godot_full_precision_trace_transport_contract_v1.json"
)
$validatorPath = Join-Path $repoRoot (
    "sdk\turning\r23d57_godot_full_precision_trace_transport.py"
)
$godotCanaryPath = Join-Path $repoRoot (
    "tests\test_sdk_qsdk_r23d57_godot_full_precision_trace_transport.gd"
)
$parentClosurePath = Join-Path $repoRoot (
    "sdk\turning\" +
    "r23d56_godot_valid_route_actuator_phase_characterization_closure_v1.json"
)
$attributesPath = Join-Path $repoRoot ".gitattributes"
$provenancePath = Join-Path $repoRoot (
    "sdk\closure_evidence_provenance_contract.json"
)
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$catalogPath = Join-Path $repoRoot "sdk\workbench\experiment_catalog.json"
$contractId = "QSDK-R23D57-GODOT-FULL-PRECISION-TRACE-TRANSPORT"
$passMarker = "QSDK_R23D57_FULL_PRECISION_TRACE_TRANSPORT_PASS "

function Assert-R23D57Transport([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D57 FULL-PRECISION TRANSPORT: $Message"
    }
}

function Get-R23D57RawSha256([string]$Path) {
    return (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D57Json([string]$Path) {
    Assert-R23D57Transport (Test-Path -LiteralPath $Path -PathType Leaf) (
        "required JSON is missing: $Path"
    )
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Find-R23D57ContainersWithKey([object]$Value, [string]$Key) {
    $matches = [Collections.Generic.List[object]]::new()
    function Visit-R23D57Container([object]$Current) {
        if ($Current -is [Collections.IDictionary]) {
            if ($Current.Contains($Key)) { $matches.Add($Current) }
            foreach ($child in $Current.Values) {
                Visit-R23D57Container $child
            }
        } elseif (
            $Current -is [Collections.IEnumerable] -and
            $Current -isnot [string]
        ) {
            foreach ($child in $Current) { Visit-R23D57Container $child }
        }
    }
    Visit-R23D57Container $Value
    return @($matches)
}

$actualRoot = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-R23D57Transport ($LASTEXITCODE -eq 0) "repository root cannot be resolved"
$actualRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D57Transport ($LASTEXITCODE -eq 0) "origin cannot be resolved"
Assert-R23D57Transport (
    [IO.Path]::GetFullPath($actualRoot).TrimEnd('\', '/') -ceq $repoRoot -and
    $actualRemote -ceq $expectedRemote
) "repository identity changed"

foreach ($path in @(
    $contractPath,
    $validatorPath,
    $godotCanaryPath,
    $parentClosurePath,
    $attributesPath,
    $provenancePath,
    $releasePath,
    $supportPath,
    $catalogPath,
    $Godot
)) {
    Assert-R23D57Transport (Test-Path -LiteralPath $path -PathType Leaf) (
        "required source or runtime is missing: $path"
    )
}

$contract = Get-R23D57Json $contractPath
$parent = $contract["immutable_parent"]
$successor = $contract["scientifically_distinct_successor"]
$api = $contract["godot_api_authority"]
$numeric = $contract["numeric_semantics"]
$canary = $contract["zero_world_canary"]
$incident = $contract["zero_world_gate_development_incident"]
$harnessIncident = $contract["zero_world_audit_harness_incident"]
$workbenchIncident = $contract["workbench_catalog_registration_incident"]
$adequacy = $contract["adequacy"]
$implementation = $contract["implementation_boundary"]
$claims = $contract["claims"]

Assert-R23D57Transport (
    [string]$contract["schema_version"] -ceq
        "sporespore_qsdk_r23d57_godot_full_precision_trace_transport_contract_v1" -and
    [string]$contract["status"] -ceq "prospective_zero_world_transport_gate_only" -and
    [string]$contract["campaign_id"] -ceq (
        "QSDK-R23D57-GODOT-FULL-PRECISION-TRACE-ACTUATOR-PHASE-" +
        "CHARACTERIZATION-DEVELOPMENT"
    ) -and
    [string]$contract["gate_id"] -ceq "QSDK-R23D57" -and
    [string]$contract["contract_id"] -ceq $contractId -and
    [string]$contract["question_class"] -ceq "development" -and
    [bool]$contract["physical_question_declared"] -and
    -not [bool]$contract["physical_campaign_opened"]
) "contract identity, status, or question class changed"

Assert-R23D57Transport (
    [string]$parent["r23d56_closure_path"] -ceq
        "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization_closure_v1.json" -and
    [string]$parent["r23d56_closure_raw_sha256"] -ceq
        "sha256:34d165fb8aaad4321e2c28e992cd66221179fe2d791aae977528c23227013531" -and
    ("sha256:" + (Get-R23D57RawSha256 $parentClosurePath)) -ceq
        [string]$parent["r23d56_closure_raw_sha256"] -and
    [bool]$parent["r23d56_identity_consumed"] -and
    -not [bool]$parent["r23d56_rerun_allowed"] -and
    -not [bool]$parent["r23d56_result_reinterpreted"] -and
    [string]$parent["r23d56_root_failure_code"] -ceq
        "QSDK_R23D56_GJT_TRACE_RETENTION_FAILED:1" -and
    [int]$parent["r23d56_raw_trace_row_count"] -eq 8976 -and
    [int]$parent["r23d56_raw_actuator_application_count"] -eq 71808 -and
    [int]$parent["r23d56_target_report_consistency_failure_count"] -eq 2203 -and
    [int]$parent["r23d56_target_report_consistency_affected_row_count"] -eq 2051 -and
    [int]$parent["r23d56_other_primitive_actuator_link_failure_count"] -eq 0 -and
    [bool]$parent["r23d56_maximum_observed_consistency_residual_is_not_a_threshold_input"] -and
    -not [bool]$parent["retained_r23d56_rows_may_be_promoted_to_r23d57_evidence"]
) "immutable R23D56 parent result changed or was reopened"

Assert-R23D57Transport (
    [string]$successor["comparator_campaign_id"] -ceq
        "QSDK-R23D56-GODOT-VALID-ROUTE-ACTUATOR-PHASE-CHARACTERIZATION-DEVELOPMENT" -and
    [bool]$successor[
        "same_physics_model_controller_morphology_seed_material_solver_schedule_horizon_task_origin_policy_live_cap_route_observation_schema_and_contextual_gates_required"
    ] -and
    [int]$successor["declared_physics_model_change_count"] -eq 0 -and
    [int]$successor["declared_controller_change_count"] -eq 0 -and
    [int]$successor["declared_measurement_change_count"] -eq 0 -and
    [int]$successor["declared_threshold_change_count"] -eq 0 -and
    [int]$successor["declared_evidence_transport_change_count"] -eq 1 -and
    [string]$successor["only_declared_transport_change"] -clike
        '*JSON.stringify(rows, "", true, true)*' -and
    -not [bool]$successor["historical_world_reused_as_r23d57_cell"] -and
    -not [bool]$successor["r23d56_terminal_or_trace_reused_as_r23d57_cell"] -and
    [bool]$successor["fresh_worlds_required_for_any_r23d57_physical_result"] -and
    -not [bool]$successor["outcome_branching_permitted"] -and
    -not [bool]$successor["fresh_held_out_condition_consumed"]
) "scientifically distinct successor declaration changed"

Assert-R23D57Transport (
    [string]$api["product"] -ceq "Godot Engine" -and
    [string]$api["version"] -ceq "4.7-stable" -and
    [string]$api["class"] -ceq "JSON" -and
    [string]$api["method_signature"] -ceq (
        'String stringify(data: Variant, indent: String = "", ' +
        'sort_keys: bool = true, full_precision: bool = false) static'
    ) -and
    [string]$api["selected_invocation"] -ceq
        'JSON.stringify(data, "", true, true)' -and
    [string]$api["official_documentation_url"] -ceq
        "https://docs.godotengine.org/en/4.7/classes/class_json.html#class-json-method-stringify" -and
    [string]$api["context7_library_id"] -ceq "/websites/godotengine_en_4_7"
) "Godot JSON.stringify API authority changed"

Assert-R23D57Transport (
    [double]$numeric["configured_readback_tolerance"] -eq 2.5e-7 -and
    [string]$numeric["configured_readback_tolerance_role"] -ceq
        "physical configured-parameter comparison" -and
    [double]$numeric["reported_error_recomputation_consistency_tolerance"] -eq
        1.0e-15 -and
    [string]$numeric[
        "reported_error_recomputation_consistency_tolerance_role"
    ] -ceq "non-physical cross-runtime evidence self-consistency check" -and
    [bool]$numeric[
        "configured_readback_and_transport_consistency_tolerances_are_distinct"
    ] -and
    [int]$numeric["new_empirical_threshold_count"] -eq 0 -and
    [int]$numeric["threshold_change_count"] -eq 0 -and
    -not [bool]$numeric["r23d56_observed_maximum_used_to_set_tolerance"] -and
    -not [bool]$numeric["population_margin"] -and
    -not [bool]$numeric["cross_engine_equivalence_margin"]
) "numeric role, threshold provenance, or margin boundary changed"

Assert-R23D57Transport (
    [string]$canary["godot_path"] -ceq
        "tests/test_sdk_qsdk_r23d57_godot_full_precision_trace_transport.gd" -and
    [string]$canary["python_path"] -ceq
        "sdk/turning/r23d57_godot_full_precision_trace_transport.py" -and
    [string]$canary["powershell_audit_path"] -ceq
        "tests/test_qsdk_r23d57_godot_full_precision_trace_transport.ps1" -and
    [int]$canary["fixture_count"] -eq 35 -and
    [int]$canary["retained_failure_shape_fixture_count"] -eq 1 -and
    [int]$canary["independent_literal_fixture_count"] -eq 2 -and
    [int]$canary["deterministic_cancellation_fixture_count"] -eq 32 -and
    [int]$canary["default_serialization_expected_target_failure_count"] -eq 14 -and
    [int]$canary["default_serialization_expected_impulse_failure_count"] -eq 0 -and
    [int]$canary["full_precision_expected_target_failure_count"] -eq 0 -and
    [int]$canary["full_precision_expected_impulse_failure_count"] -eq 0 -and
    [int]$canary["full_precision_binary64_operand_roundtrip_mismatch_count"] -eq 0 -and
    [int]$canary["required_mutation_rejection_count"] -eq 12 -and
    [int]$canary["required_boundary_control_count"] -eq 2 -and
    [bool]$canary["must_include_default_serialization_values_exceeding_1e_15"] -and
    [bool]$canary["must_prove_full_precision_values_at_or_below_1e_15"] -and
    [bool]$canary["must_prove_below_boundary_acceptance_and_above_boundary_rejection"] -and
    [int]$canary["scene_tree_insertion_count"] -eq 0 -and
    [int]$canary["model_construction_count"] -eq 0 -and
    [int]$canary["controller_step_count"] -eq 0 -and
    [int]$canary["world_attempt_count"] -eq 0 -and
    [int]$canary["world_build_count"] -eq 0
) "zero-world canary cohort, controls, or world boundary changed"

Assert-R23D57Transport (
    [bool]$incident["observed"] -and
    $null -eq $incident["observed_utc"] -and
    [bool]$incident["exact_observation_time_not_retained"] -and
    [string]$incident["status"] -ceq
        "validator_redundant_cross_runtime_default_recomputation_comparison_rejected_before_gate" -and
    [string]$incident["trigger_fixture_id"] -ceq
        "retained_r23d56_first_failure_shape" -and
    [double]$incident["godot_default_parse_recomputation_residual"] -eq
        5.527505403210049e-18 -and
    [double]$incident["cpython_default_parse_recomputation_residual"] -eq 0.0 -and
    -not [bool]$incident["fixture_identity_or_value_changed"] -and
    -not [bool]$incident["godot_writer_invocation_changed"] -and
    -not [bool]$incident["python_evaluator_predicate_changed"] -and
    [int]$incident["threshold_change_count"] -eq 0 -and
    [int]$incident["zero_world_godot_process_launch_count"] -eq 1 -and
    [int]$incident["world_attempt_count"] -eq 0 -and
    [int]$incident["world_build_count"] -eq 0 -and
    -not [bool]$incident["physical_campaign_opened"] -and
    -not [bool]$incident["physical_acceptance_authority"]
) "pre-gate development negative was lost or reinterpreted"

Assert-R23D57Transport (
    [bool]$harnessIncident["observed"] -and
    $null -eq $harnessIncident["observed_utc"] -and
    [bool]$harnessIncident["exact_observation_time_not_retained"] -and
    [string]$harnessIncident["status"] -ceq
        "powershell_multiple_python_command_candidates_rejected_before_validator_launch" -and
    -not [bool]$harnessIncident["contract_changed_to_fit_result"] -and
    -not [bool]$harnessIncident["canary_fixture_or_numeric_semantics_changed"] -and
    [int]$harnessIncident["threshold_change_count"] -eq 0 -and
    [int]$harnessIncident["python_validator_launch_count"] -eq 0 -and
    [int]$harnessIncident["godot_process_launch_count"] -eq 0 -and
    [int]$harnessIncident["world_attempt_count"] -eq 0 -and
    [int]$harnessIncident["world_build_count"] -eq 0 -and
    -not [bool]$harnessIncident["physical_campaign_opened"] -and
    -not [bool]$harnessIncident["physical_acceptance_authority"]
) "pre-validator audit-harness negative was lost or reinterpreted"

Assert-R23D57Transport (
    [bool]$workbenchIncident["observed"] -and
    $null -eq $workbenchIncident["observed_utc"] -and
    [bool]$workbenchIncident["exact_observation_time_not_retained"] -and
    [string]$workbenchIncident["status"] -ceq
        "workbench_catalog_count_refused_after_r23d57_run_registration" -and
    [string]$workbenchIncident["failure_message"] -ceq
        "LOCOMOTION_EXPERIMENT_WORKBENCH catalog counts changed" -and
    [int]$workbenchIncident["pre_registration_run_count"] -eq 54 -and
    [int]$workbenchIncident["post_registration_run_count"] -eq 55 -and
    [string]$workbenchIncident["intended_added_run_id"] -ceq
        "qsdk_r23d57_full_precision_trace_transport" -and
    [int]$workbenchIncident["semantic_count_literal_change_count"] -eq 3 -and
    -not [bool]$workbenchIncident["proof_digest_verification_reached"] -and
    -not [bool]$workbenchIncident["transport_result_changed"] -and
    [int]$workbenchIncident["threshold_change_count"] -eq 0 -and
    [int]$workbenchIncident["world_attempt_count"] -eq 0 -and
    [int]$workbenchIncident["world_build_count"] -eq 0 -and
    -not [bool]$workbenchIncident["physical_campaign_opened"] -and
    -not [bool]$workbenchIncident["physical_acceptance_authority"]
) "WorkBench catalog-registration negative was lost or reinterpreted"

Assert-R23D57Transport (
    [bool]$adequacy["production_shaped_target_and_impulse_fields_exercised"] -and
    [bool]$adequacy["godot_writer_and_python_reader_both_exercised"] -and
    [bool]$adequacy["default_and_full_precision_paths_both_exercised"] -and
    [bool]$adequacy["deterministic_cancellation_family_exercised"] -and
    [bool]$adequacy["mutations_cover_flag_omission_identity_cardinality_operand_error_tolerance_physical_bound_and_world_count"] -and
    [bool]$adequacy["adequate_for_current_godot_4_7_python_binary64_transport_contract"] -and
    -not [bool]$adequacy["adequate_for_arbitrary_json_implementations"] -and
    -not [bool]$adequacy["adequate_for_physical_characterization"] -and
    -not [bool]$adequacy["adequate_for_turning_acceptance"] -and
    -not [bool]$adequacy["adequate_for_population_inference"] -and
    -not [bool]$adequacy["adequate_for_cross_engine_equivalence"] -and
    -not [bool]$adequacy[
        "adequate_to_open_physical_worlds_without_complete_campaign_implementation_qualification_and_adoption"
    ]
) "transport adequacy was broadened"

Assert-R23D57Transport (
    @($implementation.Values | Where-Object { [bool]$_ }).Count -eq 0 -and
    [bool]$claims["zero_world_transport_contract_declared"] -and
    -not [bool]$claims["zero_world_transport_gate_passed"] -and
    -not [bool]$claims["r23d57_implementation_complete"] -and
    -not [bool]$claims["physical_world_opened"] -and
    -not [bool]$claims["turning_mechanism_selected"] -and
    -not [bool]$claims["godot_jolt_turning_validation"] -and
    -not [bool]$claims["finite_three_engine_turning"] -and
    -not [bool]$claims["portable_basic_turning"] -and
    -not [bool]$claims["prone_to_standing"] -and
    -not [bool]$claims["release_authorized"] -and
    -not [bool]$claims["physical_acceptance_authority"]
) "implementation or claim boundary opened before qualification"

$attributes = Get-Content -Raw -LiteralPath $attributesPath
$provenance = Get-R23D57Json $provenancePath
$extension = $provenance["checkout_filter_migration"][
    "r23d57_non_migration_rule_extension"
]
$attributesBlob = (& git -C $repoRoot hash-object -- .gitattributes).Trim()
Assert-R23D57Transport ($LASTEXITCODE -eq 0) ".gitattributes blob cannot be computed"
Assert-R23D57Transport (
    $attributes.Contains("sdk/turning/r23d57_* text eol=lf") -and
    $attributes.Contains("sdk/run_qsdk_r23d57_* text eol=lf") -and
    $attributes.Contains("tests/test_qsdk_r23d57_* text eol=lf") -and
    $attributes.Contains("tests/test_sdk_qsdk_r23d57_* text eol=lf") -and
    [string]$provenance["checkout_filter_migration"][
        "current_gitattributes_raw_sha256"
    ] -ceq (Get-R23D57RawSha256 $attributesPath) -and
    [string]$provenance["checkout_filter_migration"][
        "current_gitattributes_git_blob_oid"
    ] -ceq $attributesBlob -and
    [string]$extension["declared_from_parent_commit"] -ceq
        "5008c44a418eed3f3e1a56d8ef005394d84b68e1" -and
    [string]$extension["scope"] -ceq
        "prospective_r23d57_full_precision_trace_transport_and_physical_source_family_only" -and
    [int]$extension["added_rule_count"] -eq 4 -and
    -not [bool]$extension["ambient_rule_changed"] -and
    -not [bool]$extension["historical_path_rule_changed"] -and
    [int]$extension["historical_tracked_file_renormalization_count"] -eq 0 -and
    -not [bool]$extension["renormalization_executed"] -and
    -not [bool]$extension["checkout_filter_migration_executed"] -and
    -not [bool]$extension["initial_provenance_failure_observed"] -and
    [string]$extension["declaration_mode"] -ceq
        "proactive_before_first_r23d57_source_file_creation" -and
    [int]$extension["physical_world_count"] -eq 0 -and
    -not [bool]$extension["physical_acceptance_authority"]
) "R23D57 checkout-filter provenance boundary changed"

$release = Get-R23D57Json $releasePath
$support = Get-R23D57Json $supportPath
$catalog = Get-R23D57Json $catalogPath
$releaseBlocks = @(
    Find-R23D57ContainersWithKey $release (
        "prospective_r23d57_full_precision_trace_transport"
    )
)
$supportBlocks = @(
    Find-R23D57ContainersWithKey $support (
        "prospective_r23d57_full_precision_trace_transport"
    )
)
Assert-R23D57Transport (
    $releaseBlocks.Count -eq 1 -and $supportBlocks.Count -eq 1
) "release/support R23D57 block cardinality changed"
$releaseBlock = $releaseBlocks[0][
    "prospective_r23d57_full_precision_trace_transport"
]
$supportBlock = $supportBlocks[0][
    "prospective_r23d57_full_precision_trace_transport"
]
$expectedCurrentStatus = (
    "r23d57_full_precision_zero_world_transport_gate_passed_locally_" +
    "clean_push_and_physical_implementation_pending_no_world_open"
)
$releaseCurrent = @(
    Find-R23D57ContainersWithKey $release "current_successor_status" |
        Where-Object {
            [string]$_["current_successor_status"] -ceq
                "r23d56_closed_consumed_invalid_trace_retention_roundtrip_consistency"
        }
)
$supportCurrent = @(
    Find-R23D57ContainersWithKey $support "current_successor_status" |
        Where-Object {
            [string]$_["current_successor_status"] -ceq
                "r23d56_closed_consumed_invalid_trace_retention_roundtrip_consistency"
        }
)
Assert-R23D57Transport (
    $releaseCurrent.Count -eq 1 -and
    $supportCurrent.Count -eq 1 -and
    [string]$releaseCurrent[0]["current_prospective_successor_status"] -ceq
        $expectedCurrentStatus -and
    [string]$supportCurrent[0]["current_prospective_successor_status"] -ceq
        $expectedCurrentStatus -and
    [string]$releaseCurrent[0]["current_successor_reason"] -ceq
        [string]$supportCurrent[0]["current_successor_reason"]
) "current turning pointer or release/support reason diverged"

foreach ($block in @($releaseBlock, $supportBlock)) {
    Assert-R23D57Transport (
        [string]$block["gate_id"] -ceq "QSDK-R23D57" -and
        [string]$block["campaign_id"] -ceq
            [string]$contract["campaign_id"] -and
        [string]$block["contract_id"] -ceq $contractId -and
        [string]$block["status"] -ceq
            "local_zero_world_transport_gate_passed_clean_push_closure_and_physical_implementation_pending" -and
        [string]$block["question_class"] -ceq "development" -and
        [bool]$block["physical_question_declared"] -and
        -not [bool]$block["physical_campaign_opened"] -and
        [string]$block["development_parent_commit"] -ceq
            "5008c44a418eed3f3e1a56d8ef005394d84b68e1" -and
        [int]$block["declared_physics_model_change_count"] -eq 0 -and
        [int]$block["declared_controller_change_count"] -eq 0 -and
        [int]$block["declared_measurement_change_count"] -eq 0 -and
        [int]$block["declared_threshold_change_count"] -eq 0 -and
        [int]$block["declared_evidence_transport_change_count"] -eq 1 -and
        [double]$block["configured_readback_tolerance"] -eq 2.5e-7 -and
        [double]$block[
            "reported_error_recomputation_consistency_tolerance"
        ] -eq 1.0e-15 -and
        [int]$block["new_empirical_threshold_count"] -eq 0 -and
        [int]$block["fixture_count"] -eq 35 -and
        [int]$block[
            "default_serialization_target_consistency_failure_count"
        ] -eq 14 -and
        [int]$block["full_precision_target_consistency_failure_count"] -eq 0 -and
        [int]$block["full_precision_impulse_consistency_failure_count"] -eq 0 -and
        [int]$block["full_precision_binary64_roundtrip_mismatch_count"] -eq 0 -and
        [int]$block["mutation_rejection_count"] -eq 12 -and
        [int]$block["boundary_control_count"] -eq 2 -and
        [bool]$block["local_zero_world_transport_gate_passed"] -and
        -not [bool]$block["clean_pushed_zero_world_closure_exists"] -and
        -not [bool]$block["physical_worker_complete"] -and
        -not [bool]$block["physical_evaluator_complete"] -and
        -not [bool]$block["physical_supervisor_complete"] -and
        -not [bool]$block["campaign_attestation_manifest_complete"] -and
        -not [bool]$block["complete_zero_world_campaign_gate_passed"] -and
        -not [bool]$block["scoped_qualification_passed"] -and
        -not [bool]$block["adoption_passed"] -and
        [bool]$block["fresh_worlds_required_for_any_physical_result"] -and
        -not [bool]$block["physical_execution_authorized"] -and
        -not [bool]$block["turning_acceptance"] -and
        -not [bool]$block["godot_jolt_turning_validation"] -and
        -not [bool]$block["finite_three_engine_turning"] -and
        -not [bool]$block["portable_basic_turning"] -and
        -not [bool]$block["prone_to_standing"] -and
        -not [bool]$block["release_authorized"] -and
        -not [bool]$block["physical_acceptance_authority"]
    ) "release/support R23D57 boundary changed"
}
Assert-R23D57Transport (
    [string]$releaseBlock["contract_raw_sha256"] -ceq
        ("sha256:" + (Get-R23D57RawSha256 $contractPath)) -and
    [string]$supportBlock["contract_sha256"] -ceq
        [string]$releaseBlock["contract_raw_sha256"] -and
    [string]$releaseBlock["validator_raw_sha256"] -ceq
        ("sha256:" + (Get-R23D57RawSha256 $validatorPath)) -and
    [string]$supportBlock["validator_sha256"] -ceq
        [string]$releaseBlock["validator_raw_sha256"] -and
    [string]$releaseBlock["godot_canary_raw_sha256"] -ceq
        ("sha256:" + (Get-R23D57RawSha256 $godotCanaryPath)) -and
    [string]$supportBlock["godot_canary_sha256"] -ceq
        [string]$releaseBlock["godot_canary_raw_sha256"] -and
    [string]$releaseBlock["audit_raw_sha256"] -ceq
        ("sha256:" + (Get-R23D57RawSha256 $PSCommandPath)) -and
    [string]$supportBlock["audit_sha256"] -ceq
        [string]$releaseBlock["audit_raw_sha256"]
) "release/support R23D57 source binding changed"

$catalogRuns = @($catalog["runs"])
$catalogEntry = @(
    $catalogRuns | Where-Object {
        [string]$_["id"] -ceq "qsdk_r23d57_full_precision_trace_transport"
    }
)
Assert-R23D57Transport (
    $catalogEntry.Count -eq 1 -and
    [string]$catalogEntry[0]["kind"] -ceq "zero_world_conformance_gate" -and
    [string]$catalogEntry[0]["status"] -ceq
        "local_pass_clean_push_closure_pending" -and
    [string]$catalogEntry[0]["world_policy"] -ceq "zero_world_only" -and
    [string]$catalogEntry[0]["risk"] -ceq "safe" -and
    [string]$catalogEntry[0]["runner_path"] -ceq
        "tests/test_qsdk_r23d57_godot_full_precision_trace_transport.ps1"
) "workbench R23D57 entry changed"
$catalogProofs = @{}
foreach ($proof in @($catalogEntry[0]["proofs"])) {
    $catalogProofs[[string]$proof["path"]] = [string]$proof["expected_sha256"]
}
foreach ($binding in @{
    "sdk/turning/r23d57_godot_full_precision_trace_transport_contract_v1.json" =
        $contractPath
    "sdk/turning/r23d57_godot_full_precision_trace_transport.py" =
        $validatorPath
    "tests/test_sdk_qsdk_r23d57_godot_full_precision_trace_transport.gd" =
        $godotCanaryPath
    "tests/test_qsdk_r23d57_godot_full_precision_trace_transport.ps1" =
        $PSCommandPath
}.GetEnumerator()) {
    Assert-R23D57Transport (
        $catalogProofs.ContainsKey([string]$binding.Key) -and
        [string]$catalogProofs[[string]$binding.Key] -ceq
            (Get-R23D57RawSha256 ([string]$binding.Value))
    ) "workbench R23D57 proof binding changed: $([string]$binding.Key)"
}

$godotSource = Get-Content -Raw -LiteralPath $godotCanaryPath
foreach ($requiredFragment in @(
    'var default_json := JSON.stringify(application)',
    'var full_precision_json := JSON.stringify(application, "", true, true)',
    'JSON.stringify(receipt, "", true, true)',
    '"scene_tree_insertion_count": 0',
    '"model_construction_count": 0',
    '"world_attempt_count": 0',
    '"world_build_count": 0'
)) {
    Assert-R23D57Transport ($godotSource.Contains($requiredFragment)) (
        "Godot canary is missing required behavior: $requiredFragment"
    )
}
foreach ($forbiddenFragment in @(
    "JSON.parse_string",
    "PhysicsServer3D",
    "JoltPhysicsServer3D",
    "move_and_slide",
    "apply_force"
)) {
    Assert-R23D57Transport (-not $godotSource.Contains($forbiddenFragment)) (
        "Godot canary crossed its zero-world boundary: $forbiddenFragment"
    )
}

$validatorSource = Get-Content -Raw -LiteralPath $validatorPath
foreach ($requiredFragment in @(
    'struct.pack(">d"',
    'default_target_consistency_failure_count',
    'full_precision_binary64_roundtrip_mismatch_count',
    'full_precision_flag_false',
    'default_negative_control_replaced',
    'below_boundary_accepted',
    'above_boundary_rejected'
)) {
    Assert-R23D57Transport ($validatorSource.Contains($requiredFragment)) (
        "Python validator is missing required behavior: $requiredFragment"
    )
}

$pythonCandidates = @(
    Get-Command python -All -CommandType Application -ErrorAction Stop |
        Where-Object { Test-Path -LiteralPath $_.Source -PathType Leaf }
)
Assert-R23D57Transport ($pythonCandidates.Count -gt 0) (
    "no concrete Python application is available"
)
$pythonCommand = $pythonCandidates[0]
$priorNoBytecode = $env:PYTHONDONTWRITEBYTECODE
try {
    $env:PYTHONDONTWRITEBYTECODE = "1"
    $output = @(
        & $pythonCommand.Source -B $validatorPath `
            --godot $Godot `
            --source-root $repoRoot 2>&1 |
            ForEach-Object { [string]$_ }
    )
    $pythonExit = $LASTEXITCODE
} finally {
    $env:PYTHONDONTWRITEBYTECODE = $priorNoBytecode
}
Assert-R23D57Transport ($pythonExit -eq 0) (
    "cross-runtime validator failed: $($output -join ' | ')"
)
$markers = @($output | Where-Object { $_.StartsWith($passMarker) })
Assert-R23D57Transport ($markers.Count -eq 1) (
    "expected one Python pass receipt, found $($markers.Count)"
)
$result = $markers[0].Substring($passMarker.Length) |
    ConvertFrom-Json -AsHashtable -Depth 64
$expectedMutations = @(
    "full_precision_flag_false",
    "missing_fixture",
    "duplicate_fixture_id",
    "full_precision_replaced_by_default",
    "missing_full_precision_json",
    "reported_target_error_perturbed",
    "readback_operand_perturbed",
    "wrong_contract_id",
    "consistency_tolerance_changed",
    "world_attempt_opened",
    "physical_readback_bound_exceeded",
    "default_negative_control_replaced"
)
Assert-R23D57Transport (
    [string]$result["schema_version"] -ceq
        "sporespore_qsdk_r23d57_full_precision_trace_transport_result_v1" -and
    [string]$result["contract_id"] -ceq $contractId -and
    [int]$result["godot_version"]["major"] -eq 4 -and
    [int]$result["godot_version"]["minor"] -eq 7 -and
    [string]$result["godot_version"]["status"] -ceq "stable" -and
    [string]$result["godot_version"]["build"] -ceq "official" -and
    [int]$result["fixture_count"] -eq 35 -and
    [int]$result["default_target_consistency_failure_count"] -eq 14 -and
    [int]$result["default_impulse_consistency_failure_count"] -eq 0 -and
    [int]$result["full_precision_target_consistency_failure_count"] -eq 0 -and
    [int]$result["full_precision_impulse_consistency_failure_count"] -eq 0 -and
    [int]$result["full_precision_binary64_roundtrip_mismatch_count"] -eq 0 -and
    [double]$result["maximum_residuals"]["default_target"] -gt 1.0e-15 -and
    [double]$result["maximum_residuals"]["full_target"] -le 1.0e-15 -and
    [double]$result["maximum_residuals"]["full_impulse"] -le 1.0e-15 -and
    [int]$result["mutation_rejection_count"] -eq 12 -and
    (@($result["mutation_rejections"]) -join "|") -ceq
        ($expectedMutations -join "|") -and
    [int]$result["boundary_control_count"] -eq 2 -and
    [bool]$result["boundary_controls"]["below_boundary_accepted"] -and
    [bool]$result["boundary_controls"]["above_boundary_rejected"] -and
    [double]$result["boundary_controls"]["below_boundary_residual"] -le
        1.0e-15 -and
    [double]$result["boundary_controls"]["above_boundary_residual"] -gt
        1.0e-15 -and
    [int]$result["godot_process_launch_count"] -eq 1 -and
    [int]$result["scene_tree_insertion_count"] -eq 0 -and
    [int]$result["model_construction_count"] -eq 0 -and
    [int]$result["controller_step_count"] -eq 0 -and
    [int]$result["world_attempt_count"] -eq 0 -and
    [int]$result["world_build_count"] -eq 0 -and
    -not [bool]$result["physical_campaign_opened"] -and
    -not [bool]$result["turning_claimed"] -and
    -not [bool]$result["prone_to_standing_claimed"] -and
    -not [bool]$result["physical_acceptance_authority"]
) "cross-runtime result, negative controls, or claim boundary changed"

Write-Host (
    "QSDK_R23D57_FULL_PRECISION_TRACE_TRANSPORT_AUDIT_PASS " +
    "fixtures=35 default_target_failures=14 default_impulse_failures=0 " +
    "full_target_failures=0 full_impulse_failures=0 full_binary64_mismatches=0 " +
    "mutations=12 boundary_controls=2 godot_processes=1 models=0 worlds=0 " +
    "threshold_changes=0 physical_authority=False " +
    "contract_sha256=$(Get-R23D57RawSha256 $contractPath) " +
    "validator_sha256=$(Get-R23D57RawSha256 $validatorPath) " +
    "godot_sha256=$(Get-R23D57RawSha256 $godotCanaryPath)"
)
