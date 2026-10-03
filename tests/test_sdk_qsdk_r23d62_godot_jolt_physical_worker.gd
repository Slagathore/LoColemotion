extends "res://tests/test_sdk_qsdk_r23d60_godot_jolt_physical_worker.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Prospective Godot/Jolt worker for the nine-cell QSDK-R23D62 finite decision.
##
## The accepted R23D60 physical schedule and policy are preserved, while the
## R23D61 public actuator-cap profile is resolved and bound through the real
## production route before each world. This worker owns exactly the three
## Godot/Jolt cells at reserved seed 23167. Physical execution remains
## impossible without the future exact clean-pushed nine-cell freeze, complete
## dependency inventory, and one-shot supervisor authorization.

const R23D62BaseWorkerScript := preload(
	"res://tests/test_sdk_qsdk_r23d3_godot_jolt_worker.gd"
)
const R23D62R48WorkerScript := preload(
	"res://tests/test_sdk_qsdk_r23d48_godot_jolt_physical_worker.gd"
)
const R23D62WaveGaitScript := preload(
	"res://scripts/lab/gait/physical_wave_gait_quadruped.gd"
)
const R23D62JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const R23D62_PREREGISTRATION_PATH := (
	"res://sdk/turning/r23d62_selected_profile_three_engine_turning_validation_preregistration_v1.json"
)
const R23D62_IMPLEMENTATION_PATH := (
	"res://sdk/turning/r23d62_selected_profile_three_engine_turning_validation_implementation_v1.json"
)
const R23D62_EVALUATOR_PATH := (
	"res://sdk/turning/r23d62_selected_profile_three_engine_turning_validation_evaluator_v2.py"
)
const R23D62_CLOSURE_PATH := (
	"res://sdk/turning/r23d62_selected_profile_three_engine_turning_validation_closure_v1.json"
)

const R23D62_CAMPAIGN_ID := (
	"QSDK-R23D62-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION"
)
const R23D62_GATE_ID := "QSDK-R23D62"
const R23D62_STAGE_ID := "selected_profile_matched_three_engine_turning_validation"
const R23D62_ENGINE_ID := "godot_jolt"
const R23D62_ONSET_ID := "onset_600"
const R23D62_POLICY_ID := (
	"sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
	+ "stability_guarded_steering_v1"
)
const R23D62_MEMORY_SCHEMA := (
	"sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
)
const R23D62_TASK_ORIGIN_POLICY_ID := "warmup_preserving_command_onset_origin_reanchor_v1"
const R23D62_LIVE_FIXTURE_CAP_BINDING_POLICY_ID := (
	"sporespore_godot_jolt_public_actuator_cap_profile_binding_v1"
)
const R23D62_TRACE_TRANSPORT_ID := (
	"godot_4_7_sorted_full_precision_authoritative_json_v1"
)
const R23D62_TRACE_TRANSPORT_INVOCATION := "JSON.stringify(value, \"\", true, true)"
const R23D62_GODOT_RUNTIME_VERSION := "4.7-stable (official)"
const R23D62_TURN_START_STEP := 600
const R23D62_CONTROLLER_STEPS := 2992
const R23D62_CAMPAIGN_SEED := 23167
const R23D62_PROFILE_ID := (
	"sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
)
const R23D62_PROFILE_SHA256 := (
	"sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
)
const R23D62_PROFILE_CELL_TAG := "selected_profile"
const R23D62_HOST_MAPPING_ID := (
	"sporespore_godot_hinge_maximum_impulse_cap_mapping_v1"
)
const R23D62_ORDERED_ARM_IDS := [
	"reference_zero",
	"positive_heading",
	"negative_heading",
]
const R23D62_ORDERED_ENGINE_IDS := ["godot_jolt", "rapier_parry", "mujoco"]
const R23D62_ARM_OFFSETS := {
	"reference_zero": 0.0,
	"positive_heading": 0.2,
	"negative_heading": -0.2,
}
const R23D62_PREFLIGHT_SCHEMA := (
	"sporespore_qsdk_r23d62_godot_jolt_worker_preflight_v1"
)
const R23D62_REPORT_SCHEMA := "sporespore_qsdk_r23d62_engine_cell_report_v1"
const R23D62_FAILURE_SCHEMA := "sporespore_qsdk_r23d62_worker_failure_v1"
const R23D62_TRACE_RETENTION_SCHEMA := "sporespore_qsdk_r23d62_trace_retention_v1"
const R23D62_FREEZE_SCHEMA := "sporespore_qsdk_r23d62_physical_freeze_v1"
const R23D62_ATTEMPT_SCHEMA := "sporespore_qsdk_r23d62_attempt_v1"
const R23D62_DEPENDENCY_INVENTORY_SCHEMA := (
	"sporespore_qsdk_r23d62_dependency_inventory_v1"
)
const R23D62_DEPENDENCY_POLICY_ID := (
	"r23d62_declared_roots_recursive_local_language_closure_v1"
)

const R23D62_FREEZE_PATH_ENV := "SPORESPORE_QSDK_R23D62_FREEZE"
const R23D62_ATTEMPT_PATH_ENV := "SPORESPORE_QSDK_R23D62_ATTEMPT"
const R23D62_TOKEN_ENV := "SPORESPORE_QSDK_R23D62_TOKEN"
const R23D62_STAGE_ENV := "SPORESPORE_QSDK_R23D62_STAGE"
const R23D62_CELL_ENV := "SPORESPORE_QSDK_R23D62_CELL"
const R23D62_ENGINE_ENV := "SPORESPORE_QSDK_R23D62_ENGINE"
const R23D62_ATTEMPT_ROOT_ENV := "SPORESPORE_QSDK_R23D62_ATTEMPT_ROOT"
const R23D62_PYTHON_ENV := "SPORESPORE_QSDK_R23D62_PYTHON"
const R23D62_POWERSHELL_ENV := "SPORESPORE_QSDK_R23D62_POWERSHELL"
const R23D62_SUPERVISED_TERMINATION_ENV := (
	"SPORESPORE_QSDK_R23D62_SUPERVISED_TERMINATION"
)
const R23D62_TERMINATION_NONCE_ENV := "SPORESPORE_QSDK_R23D62_TERMINATION_NONCE"
const R23D62_TERMINATION_PROTOCOL_ID := (
	"godot_4_7_gdscript_shutdown_containment_v1"
)
const R23D62_EXIT_DRAIN_PROCESS_FRAME_COUNT := 2

const R23D62_FALSE_CLAIMS := {
	"r23d62_complete_zero_world_gate_passed": false,
	"r23d62_physical_campaign_opened": false,
	"godot_jolt_turning_extended_to_seed_23167": false,
	"fresh_rapier_turning_replication": false,
	"fresh_mujoco_turning_replication": false,
	"finite_three_engine_turning": false,
	"portable_basic_turning": false,
	"cross_engine_equivalence": false,
	"population_robustness": false,
	"arbitrary_quadruped_coverage": false,
	"prone_to_standing": false,
	"q_sdk_r23_satisfied": false,
	"release_authorized": false,
	"physical_acceptance_authority": false,
}

var _r23d62_exit_scheduled := false
var _r23d62_pending_exit_code := 0
var _r23d62_pending_exit_process_frames := 0
var _r23d62_pending_receipt_kind := ""
var _r23d62_last_resolution_receipt: Dictionary = {}
var _r23d62_last_host_mapping_receipt: Dictionary = {}
var _r23d62_last_physical_binding_receipt: Dictionary = {}


func _run() -> void:
	var parsed := _r23d62_parse_arguments(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		print("QSDK_R23D62_GODOT_JOLT_FAILURE ", R23D62JsonTransportScript.stringify(parsed))
		_r23d62_schedule_quit(1, "failure")
		return
	var cell := _r23d62_cell(
		String(parsed["stage_id"]),
		String(parsed["onset_id"]),
		int(parsed["campaign_seed"]),
		String(parsed["profile_id"]),
		String(parsed["arm_id"]),
	)
	if not bool(cell.get("ok", false)):
		print("QSDK_R23D62_GODOT_JOLT_FAILURE ", R23D62JsonTransportScript.stringify(cell))
		_r23d62_schedule_quit(1, "failure")
		return
	if bool(parsed["preflight_only"]):
		var preflight: Dictionary = await _r23d62_run_preflight(cell)
		if not bool(preflight.get("ok", false)):
			print("QSDK_R23D62_GODOT_JOLT_FAILURE ", R23D62JsonTransportScript.stringify(preflight))
			_r23d62_schedule_quit(1, "failure")
			return
		preflight["orderly_exit_drain_process_frame_count"] = (
			R23D62_EXIT_DRAIN_PROCESS_FRAME_COUNT
		)
		print("QSDK_R23D62_GODOT_JOLT_PREFLIGHT ", R23D62JsonTransportScript.stringify(preflight))
		_r23d62_schedule_quit(0, "preflight")
		return
	if bool(parsed["authorization_preflight_only"]):
		var authorization := _r23d62_physical_authorization(
			cell,
			String(parsed["source_commit"]),
		)
		if not bool(authorization.get("ok", false)):
			print("QSDK_R23D62_GODOT_JOLT_FAILURE ", R23D62JsonTransportScript.stringify(authorization))
			_r23d62_schedule_quit(1, "failure")
			return
		print(
			"QSDK_R23D62_GODOT_JOLT_AUTHORIZATION_PREFLIGHT ",
			R23D62JsonTransportScript.stringify(
				{
					"schema_version": "sporespore_qsdk_r23d62_godot_jolt_production_authorization_preflight_v1",
					"campaign_id": R23D62_CAMPAIGN_ID,
					"gate_id": R23D62_GATE_ID,
					"engine_id": R23D62_ENGINE_ID,
					"stage_id": String(cell["stage_id"]),
					"cell_id": String(cell["cell_id"]),
					"campaign_seed": int(cell["campaign_seed"]),
					"profile_id": String(cell["profile_id"]),
					"arm_id": String(cell["arm_id"]),
					"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
					"actual_production_authorization_function": "_r23d62_physical_authorization",
					"authorization_passed": true,
					"returned_before_model": true,
					"model_construction_count": 0,
					"world_attempt_count": 0,
					"world_build_count": 0,
					"physical_acceptance_authority": false,
				}
			)
		)
		_r23d62_schedule_quit(0, "authorization_preflight")
		return
	var terminal: Dictionary = await _r23d48_run_physical(
		cell,
		String(parsed["source_commit"]),
	)
	terminal = _r23d62_rebrand_terminal(terminal, cell)
	var exit_code := 0 if String(terminal.get("schema_version", "")) == R23D62_REPORT_SCHEMA else 1
	print("QSDK_R23D62_GODOT_JOLT_TERMINAL ", R23D62JsonTransportScript.stringify(terminal))
	_r23d62_schedule_quit(exit_code, "terminal")


func _r23d62_schedule_quit(exit_code: int, receipt_kind: String) -> void:
	if _r23d62_exit_scheduled:
		push_error("QSDK-R23D62 duplicate orderly-exit schedule")
		return
	_r23d62_exit_scheduled = true
	_r23d62_pending_exit_code = exit_code
	_r23d62_pending_receipt_kind = receipt_kind
	_r23d62_pending_exit_process_frames = R23D62_EXIT_DRAIN_PROCESS_FRAME_COUNT
	process_frame.connect(_r23d62_orderly_exit_process_frame, CONNECT_ONE_SHOT)


func _r23d62_orderly_exit_process_frame() -> void:
	_r23d62_pending_exit_process_frames -= 1
	if _r23d62_pending_exit_process_frames > 0:
		process_frame.connect(_r23d62_orderly_exit_process_frame, CONNECT_ONE_SHOT)
		return
	if OS.get_environment(R23D62_SUPERVISED_TERMINATION_ENV) == "1":
		var nonce := OS.get_environment(R23D62_TERMINATION_NONCE_ENV)
		if nonce.is_empty():
			push_error("QSDK-R23D62 supervised termination nonce is missing")
			quit(1)
			return
		print(
			"QSDK_R23D62_GODOT_SUPERVISOR_TERMINATION_READY ",
			R23D62JsonTransportScript.stringify(
				{
					"schema_version": "sporespore_godot_supervised_termination_ready_v1",
					"termination_protocol_id": R23D62_TERMINATION_PROTOCOL_ID,
					"termination_nonce": nonce,
					"process_id": OS.get_process_id(),
					"requested_exit_code": _r23d62_pending_exit_code,
					"worker_receipt_kind": _r23d62_pending_receipt_kind,
					"worker_receipt_emitted": true,
					"drained_process_frame_count": R23D62_EXIT_DRAIN_PROCESS_FRAME_COUNT,
					"physics_evidence_authority": false,
				}
			)
		)
		return
	quit(_r23d62_pending_exit_code)


func _r23d62_run_preflight(cell: Dictionary) -> Dictionary:
	var solver_receipt := R23D62BaseWorkerScript._apply_solver_configuration()
	if not bool(solver_receipt.get("ok", false)):
		return _r23d62_rebrand_failure(solver_receipt)
	var prepared := _campaign_prepare(cell)
	if not bool(prepared.get("ok", false)):
		return _r23d62_rebrand_failure(prepared)
	var entrypoint: Dictionary = await _run_wave(prepared, true)
	var adapter_boundary := R23D62R48WorkerScript._r23d48_adapter_boundary(
		prepared,
		cell,
	)
	var trace_canary := R23D62R48WorkerScript._r23d48_trace_row_canary(
		prepared,
		cell,
		adapter_boundary,
	)
	var trace_diagnostic_canary := _campaign_trace_diagnostic(
		cell,
		{
			"schema_version": "sporespore_sdk_physical_trace_v1",
			"row_count": 2,
			"failure_codes": ["SDK_PHYSICAL_TRACE_CANARY"],
			"rows": [{"semantic_step": 0}, {"semantic_step": 1}],
		},
	)
	var trace_diagnostic_summary := _campaign_trace_diagnostic_summary(
		trace_diagnostic_canary
	)
	var predicate_controls := R23D62BaseWorkerScript._predicate_negative_controls()
	var trace_options: Dictionary = entrypoint.get("sdk_physical_trace_options", {})
	var ramp_preflight: Dictionary = entrypoint.get(
		"sdk_startup_velocity_ramp_preflight",
		{},
	)
	var perturbation: Dictionary = prepared.get("initial_perturbation", {})
	var declaration := R23D62BaseWorkerScript._read_json(
		R23D62_PREREGISTRATION_PATH
	)
	var expected: Dictionary = declaration.get("frozen_matrix", {}).get(
		"initial_perturbation",
		{},
	)
	var authority: Dictionary = prepared.get("authority_options", {})
	var exact := (
		bool(entrypoint.get("ok", false))
		and int(entrypoint.get("actual_world_build_count", -1)) == 0
		and int(entrypoint.get("scene_tree_insertion_count", -1)) == 0
		and not bool(entrypoint.get("physics_state_modified", true))
		and bool(entrypoint.get("candidate_authority_horizon_enabled", false))
		and int(entrypoint.get("candidate_authority_observation_count", -1))
		== R23D62_CONTROLLER_STEPS
		and bool(entrypoint.get("sdk_physical_trace_enabled", false))
		and int(trace_options.get("exact_controller_step_count", -1))
		== R23D62_CONTROLLER_STEPS
		and String(trace_options.get("cell_id", "")) == String(cell["cell_id"])
		and String(trace_options.get("trace_row_schema_version", ""))
		== R23D48_TRACE_ROW_SCHEMA
		and bool(entrypoint.get("sdk_startup_velocity_ramp_enabled", false))
		and bool(ramp_preflight.get("ok", false))
		and bool(adapter_boundary.get("ok", false))
		and bool(trace_canary.get("ok", false))
		and not bool(trace_diagnostic_canary.get("complete", true))
		and int(trace_diagnostic_canary.get("declared_row_count", -1))
		== R23D62_CONTROLLER_STEPS
		and int(trace_diagnostic_canary.get("reported_row_count", -1)) == 2
		and int(trace_diagnostic_canary.get("actual_row_count", -1)) == 2
		and int(trace_diagnostic_canary.get("first_missing_semantic_step", -1))
		== 2
		and not trace_diagnostic_summary.has("rows")
		and bool(predicate_controls.get("ok", false))
		and String(
			authority.get("live_fixture_actuator_cap_binding_policy_id", "")
		)
		== R23D62_LIVE_FIXTURE_CAP_BINDING_POLICY_ID
		and String(
			authority.get("live_fixture_actuator_cap_binding_profile_id", "")
		)
		== R23D62_PROFILE_ID
		and bool(
			entrypoint.get(
				"sdk_live_fixture_actuator_cap_binding_enabled",
				false,
			)
		)
		and String(
			entrypoint.get(
				"sdk_live_fixture_actuator_cap_binding_policy_id",
				"",
			)
		)
		== R23D62_LIVE_FIXTURE_CAP_BINDING_POLICY_ID
		and String(
			entrypoint.get(
				"sdk_live_fixture_actuator_cap_binding_profile_id",
				"",
			)
		)
		== R23D62_PROFILE_ID
		and not bool(
			entrypoint.get(
				"sdk_live_fixture_actuator_cap_binding_executed",
				true,
			)
		)
		and R23D62R48WorkerScript._r23d48_perturbation_exact(
			perturbation,
			expected,
		)
	)
	if not exact:
		return _r23d62_failure(
			"QSDK_R23D62_GJT_PREFLIGHT_INVALID",
			{
				"entrypoint": entrypoint,
				"adapter_boundary": adapter_boundary,
				"trace_canary": trace_canary,
				"trace_diagnostic_canary": trace_diagnostic_summary,
				"predicate_controls": predicate_controls,
				"authority_options": authority,
			},
		)
	return {
		"schema_version": R23D62_PREFLIGHT_SCHEMA,
		"ok": true,
		"failure_code": "",
		"campaign_id": R23D62_CAMPAIGN_ID,
		"gate_id": R23D62_GATE_ID,
		"engine_id": R23D62_ENGINE_ID,
		"stage_id": R23D62_STAGE_ID,
		"cell_id": String(cell["cell_id"]),
		"campaign_seed": int(cell["campaign_seed"]),
		"profile_id": String(cell["profile_id"]),
		"profile_sha256": R23D62_PROFILE_SHA256,
		"host_mapping_id": String(cell["host_mapping_id"]),
		"arm_id": String(cell["arm_id"]),
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
		"controller_policy_id": R23D62_POLICY_ID,
		"controller_memory_schema": R23D62_MEMORY_SCHEMA,
		"task_frame_origin_policy_id": R23D62_TASK_ORIGIN_POLICY_ID,
		"public_profile_binding_policy_id": (
			R23D62_LIVE_FIXTURE_CAP_BINDING_POLICY_ID
		),
		"preregistration_raw_sha256": (
			R23D62BaseWorkerScript._raw_file_sha256(
				R23D62_PREREGISTRATION_PATH
			)
		),
		"implementation_contract_raw_sha256": (
			R23D62BaseWorkerScript._raw_file_sha256(
				R23D62_IMPLEMENTATION_PATH
			)
		),
		"compiled_initial_perturbation": (
			R23D62BaseWorkerScript._json_initial_perturbation(perturbation)
		),
		"compiled_initial_perturbation_matches_declaration": true,
		"entrypoint_preflight": entrypoint,
		"solver_receipt": solver_receipt,
		"adapter_boundary": adapter_boundary,
		"trace_row_canary": trace_canary,
		"trace_diagnostic_canary": trace_diagnostic_summary,
		"godot_predicate_negative_control_count": int(
			predicate_controls["rejected_mutation_count"]
		),
		"question_class": "finite_decision",
		"turning_gate_invoked": true,
		"superiority_or_equivalence_evaluator_invoked": false,
		"expected_matrix_cell_ids": _r23d62_expected_matrix_cell_ids(),
		"expected_matrix_cell_count": 9,
		"authorization_validates_complete_nine_cell_matrix": true,
		"public_profile_resolution_deferred_to_exact_preworld_host_route": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
	}

func _campaign_physical_authorization(
	cell: Dictionary,
	source_commit: String,
) -> Dictionary:
	return _r23d62_physical_authorization(cell, source_commit)


func _campaign_run_preflight(cell: Dictionary) -> Dictionary:
	return await _r23d62_run_preflight(cell)


func _campaign_prepare(cell: Dictionary) -> Dictionary:
	var declaration := R23D62BaseWorkerScript._read_json(R23D62_PREREGISTRATION_PATH)
	var implementation := R23D62BaseWorkerScript._read_json(R23D62_IMPLEMENTATION_PATH)
	var matrix: Dictionary = declaration.get("frozen_matrix", {})
	var profile: Dictionary = declaration.get("published_profile_binding", {})
	var rules: Dictionary = declaration.get("finite_decision_rule", {})
	var claims: Dictionary = declaration.get("claims", {})
	var workers: Dictionary = implementation.get("workers", {})
	var godot_worker: Dictionary = workers.get(R23D62_ENGINE_ID, {})
	var implementation_claims: Dictionary = implementation.get("claims", {})
	var declared_cell := _r23d62_declared_cell(
		matrix,
		String(cell.get("cell_id", "")),
	)
	var declaration_exact: bool = (
		String(declaration.get("schema_version", ""))
		== "sporespore_qsdk_r23d62_selected_profile_three_engine_turning_validation_preregistration_v1"
		and String(declaration.get("status", ""))
		== "prospective_zero_world_only_physical_not_opened"
		and String(declaration.get("campaign_id", "")) == R23D62_CAMPAIGN_ID
		and String(declaration.get("gate_id", "")) == R23D62_GATE_ID
		and String(declaration.get("question_class", "")) == "finite_decision"
		and not bool(declaration.get("physical_campaign_opened", true))
		and String(matrix.get("stage_id", "")) == R23D62_STAGE_ID
		and matrix.get("ordered_engine_ids", [])
		== ["godot_jolt", "rapier_parry", "mujoco"]
		and matrix.get("ordered_arm_ids", []) == R23D62_ORDERED_ARM_IDS
		and _r23d62_arm_offsets_exact(
			matrix.get("ordered_heading_offsets_rad", [])
		)
		and int(matrix.get("seed", -1)) == R23D62_CAMPAIGN_SEED
		and int(matrix.get("declared_cell_count", -1)) == 9
		and int(matrix.get("declared_world_count", -1)) == 9
		and int(matrix.get("controller_step_count", -1))
		== R23D62_CONTROLLER_STEPS
		and int(matrix.get("turn_start_step", -1)) == R23D62_TURN_START_STEP
		and String(matrix.get("controller_policy_id", "")) == R23D62_POLICY_ID
		and String(matrix.get("task_frame_origin_policy_id", ""))
		== R23D62_TASK_ORIGIN_POLICY_ID
		and _r23d62_reanchor_steps_exact(
			matrix.get("expected_reanchor_semantic_steps", [])
		)
		and bool(matrix.get("serial_execution_required", false))
		and bool(matrix.get("fresh_world_required_per_cell", false))
		and bool(
			matrix.get(
				"all_cells_run_regardless_of_intermediate_outcome",
				false,
			)
		)
		and not bool(matrix.get("terminal_restoration_or_taper_invoked", true))
		and declared_cell == cell
		and String(profile.get("profile_id", "")) == R23D62_PROFILE_ID
		and String(profile.get("profile_sha256", "")) == R23D62_PROFILE_SHA256
		and bool(profile.get("public_resolution_required_in_each_worker", false))
		and bool(profile.get("host_mapping_receipt_required_before_each_world", false))
		and not bool(profile.get("legacy_fixture_override_permitted", true))
		and bool(
			rules.get(
				"complete_execution_valid_nine_cell_matrix_required",
				false,
			)
		)
		and bool(
			rules.get(
				"all_nine_cells_must_pass_every_common_physical_gate",
				false,
			)
		)
		and bool(
			rules.get(
				"each_engine_must_independently_pass_both_turning_gates",
				false,
			)
		)
		and not bool(rules.get("early_stop_or_selective_rerun_permitted", true))
		and not bool(claims.get("r23d62_complete_zero_world_gate_passed", true))
		and not bool(claims.get("r23d62_physical_campaign_opened", true))
		and not bool(
			claims.get("godot_jolt_turning_extended_to_seed_23167", true)
		)
	)
	var implementation_exact: bool = (
		String(implementation.get("schema_version", ""))
		== "sporespore_qsdk_r23d62_selected_profile_three_engine_turning_validation_implementation_v1"
		and String(implementation.get("campaign_id", "")) == R23D62_CAMPAIGN_ID
		and String(implementation.get("gate_id", "")) == R23D62_GATE_ID
		and String(implementation.get("question_class", "")) == "finite_decision"
		and not bool(implementation.get("physical_campaign_opened", true))
		and int(implementation.get("declared_world_count", -1)) == 9
		and String(implementation.get("profile_id", "")) == R23D62_PROFILE_ID
		and String(implementation.get("profile_sha256", ""))
		== R23D62_PROFILE_SHA256
		and String(godot_worker.get("path", ""))
		== "tests/test_sdk_qsdk_r23d62_godot_jolt_physical_worker.gd"
		and bool(godot_worker.get("implementation_complete", false))
		and String(godot_worker.get("production_public_profile_route_path", ""))
		== "scripts/lab/gait/sdk_godot_jolt_public_actuator_cap_profile_binding.gd"
		and String(godot_worker.get("production_physical_runner_path", ""))
		== "scripts/lab/gait/physical_wave_gait_quadruped.gd"
		and not bool(godot_worker.get("physical_execution_authorized", true))
		and bool(
			implementation_claims.get(
				"godot_worker_implementation_complete",
				false,
			)
		)
		and bool(implementation_claims.get("implementation_complete", false))
		and bool(
			implementation_claims.get("complete_zero_world_gate_passed", false)
		)
		and not bool(implementation_claims.get("physical_world_opened", true))
		and not bool(
			implementation_claims.get(
				"godot_jolt_turning_extended_to_seed_23167",
				true,
			)
		)
		and not bool(
			implementation_claims.get("physical_acceptance_authority", true)
		)
		and String(Engine.get_version_info().get("string", ""))
		== R23D62_GODOT_RUNTIME_VERSION
	)
	if not declaration_exact or not implementation_exact:
		return _r23d62_failure(
			"QSDK_R23D62_GJT_DECLARATION_OR_IMPLEMENTATION_INVALID",
			{
				"declaration_exact": declaration_exact,
				"implementation_exact": implementation_exact,
				"declared_cell": declared_cell,
				"live_cell": cell,
				"runtime": Engine.get_version_info().get("string", ""),
			},
		)

	# Reuse only the accepted generic fixture/schedule compiler. Replace its
	# historical seed and trace identity before any model or world can exist.
	var prepared := R23D62BaseWorkerScript._prepare(cell)
	if not bool(prepared.get("ok", false)):
		return _r23d62_rebrand_failure(prepared)
	var trace_options: Dictionary = (
		(prepared.get("trace_options", {}) as Dictionary).duplicate(true)
	)
	trace_options["trace_row_schema_version"] = R23D48_TRACE_ROW_SCHEMA
	var trace_result := R23D62WaveGaitScript.compile_sdk_physical_trace_options(
		trace_options
	)
	if not bool(trace_result.get("ok", false)):
		return _r23d62_rebrand_failure(trace_result)
	prepared["trace_options"] = trace_options
	prepared["trace_configuration_sha256"] = String(
		trace_result["sdk_physical_trace_configuration_sha256"]
	)
	var perturbation_result := R23D62WaveGaitScript.compile_seeded_initial_perturbation(
		R23D62_CAMPAIGN_SEED
	)
	if not bool(perturbation_result.get("ok", false)):
		return _r23d62_rebrand_failure(perturbation_result)
	var perturbation: Dictionary = perturbation_result["initial_perturbation"]
	var expected: Dictionary = matrix.get("initial_perturbation", {})
	if not R23D62R48WorkerScript._r23d48_perturbation_exact(
		perturbation,
		expected,
	):
		return _r23d62_failure(
			"QSDK_R23D62_GJT_INITIAL_PERTURBATION_MISMATCH",
			{
				"compiled": R23D62BaseWorkerScript._json_initial_perturbation(
					perturbation
				),
				"declared": expected,
			},
		)
	prepared["initial_perturbation"] = perturbation
	var authority: Dictionary = (
		(prepared["authority_options"] as Dictionary).duplicate(true)
	)
	authority["controller_policy_id"] = R23D62_POLICY_ID
	authority["task_frame_origin_policy_id"] = R23D62_TASK_ORIGIN_POLICY_ID
	authority["live_fixture_actuator_cap_binding_policy_id"] = (
		R23D62_LIVE_FIXTURE_CAP_BINDING_POLICY_ID
	)
	authority["live_fixture_actuator_cap_binding_profile_id"] = R23D62_PROFILE_ID
	authority["descriptor"] = (
		(prepared["descriptor"] as Dictionary).duplicate(true)
	)
	prepared["authority_options"] = authority
	prepared["profile_id"] = R23D62_PROFILE_ID
	prepared["profile_sha256"] = R23D62_PROFILE_SHA256
	prepared["host_mapping_id"] = R23D62_HOST_MAPPING_ID
	prepared["campaign_seed"] = R23D62_CAMPAIGN_SEED
	prepared["expected_matrix_cell_ids"] = _r23d62_expected_matrix_cell_ids()
	prepared["expected_matrix_cell_count"] = 9
	prepared["authorization_validates_complete_nine_cell_matrix"] = true
	return prepared
func _campaign_retain_trace(
	cell: Dictionary,
	rows: Array,
	attempt_root: String,
) -> Dictionary:
	return _r23d62_retain_trace(cell, rows, attempt_root)


func _campaign_trace_diagnostic(
	cell: Dictionary,
	trace_container: Dictionary,
) -> Dictionary:
	var diagnostic := R23D62R48WorkerScript._r23d48_trace_diagnostic(
		cell,
		trace_container,
	)
	diagnostic["schema_version"] = "sporespore_qsdk_r23d62_trace_diagnostic_v1"
	diagnostic["campaign_id"] = R23D62_CAMPAIGN_ID
	diagnostic["gate_id"] = R23D62_GATE_ID
	diagnostic["stage_id"] = R23D62_STAGE_ID
	diagnostic["campaign_seed"] = int(cell["campaign_seed"])
	diagnostic["profile_id"] = String(cell["profile_id"])
	diagnostic["host_mapping_id"] = String(cell["host_mapping_id"])
	return diagnostic


func _campaign_retain_trace_diagnostic(
	cell: Dictionary,
	diagnostic: Dictionary,
	attempt_root: String,
) -> Dictionary:
	return R23D62R48WorkerScript._r23d48_retain_trace_diagnostic(
		cell,
		diagnostic,
		attempt_root,
		R23D62_POWERSHELL_ENV,
	)

func _campaign_trace_diagnostic_summary(diagnostic: Dictionary) -> Dictionary:
	return R23D62R48WorkerScript._r23d48_trace_diagnostic_summary(diagnostic)


func _run_wave(prepared: Dictionary, preflight_before_world: bool) -> Dictionary:
	var configured := prepared.duplicate(true)
	var authority: Dictionary = (
		(configured.get("authority_options", {}) as Dictionary).duplicate(true)
	)
	authority["controller_policy_id"] = R23D62_POLICY_ID
	authority["task_frame_origin_policy_id"] = R23D62_TASK_ORIGIN_POLICY_ID
	authority["live_fixture_actuator_cap_binding_policy_id"] = (
		R23D62_LIVE_FIXTURE_CAP_BINDING_POLICY_ID
	)
	authority["live_fixture_actuator_cap_binding_profile_id"] = R23D62_PROFILE_ID
	authority["descriptor"] = (
		(configured["descriptor"] as Dictionary).duplicate(true)
	)
	configured["authority_options"] = authority
	var result: Dictionary = await (
		R23D62WaveGaitScript
		. new()
		. run(
			self,
			-1.0,
			10.0,
			1.75,
			"lateral",
			72,
			0.40,
			"all",
			112,
			false,
			configured["initial_perturbation"],
			ROBUSTNESS_OPTIONS,
			configured["fixture_spec"],
			HOST_OBSERVER_PATH_OPTIONS,
			ACTUATOR_IMPULSE_OPTIONS,
			HOST_PREAUTHORITY_MOTOR_OPTIONS,
			configured["evidence_threshold_options"],
			configured["gait_clock_options"],
			R23D48_SOLVER_OPTIONS,
			{},
			{},
			configured["authority_options"],
			{},
			{},
			preflight_before_world,
			configured["fixed_horizon_options"],
			configured["schedule"],
			configured["trace_options"],
			{},
			R23D48_STARTUP_RAMP_OPTIONS,
		)
	)
	if preflight_before_world:
		return result
	_r23d62_last_resolution_receipt = (
		(
			result.get(
				"sdk_actuator_cap_profile_resolution_receipt",
				{},
			) as Dictionary
		).duplicate(true)
	)
	_r23d62_last_host_mapping_receipt = (
		(
			result.get(
				"sdk_live_fixture_actuator_cap_binding_receipt",
				{},
			) as Dictionary
		).duplicate(true)
	)
	_r23d62_last_physical_binding_receipt = (
		(
			result.get(
				"sdk_actuator_cap_profile_physical_binding_receipt",
				{},
			) as Dictionary
		).duplicate(true)
	)
	var receipts_exact := _r23d62_public_binding_receipts_exact(
		_r23d62_last_resolution_receipt,
		_r23d62_last_host_mapping_receipt,
		_r23d62_last_physical_binding_receipt,
	)
	var summary: Dictionary = (
		(result.get("sdk_authority_summary", {}) as Dictionary).duplicate(true)
	)
	summary["r23d62_actuator_cap_profile_resolution_receipt"] = (
		_r23d62_last_resolution_receipt.duplicate(true)
	)
	summary["r23d62_actuator_cap_profile_host_mapping_receipt"] = (
		_r23d62_last_host_mapping_receipt.duplicate(true)
	)
	summary["r23d62_actuator_cap_profile_physical_binding_receipt"] = (
		_r23d62_last_physical_binding_receipt.duplicate(true)
	)
	summary["r23d62_public_profile_binding_integrity_passed"] = receipts_exact
	if not receipts_exact:
		summary["ok"] = false
		summary["failure_code"] = "QSDK_R23D62_GJT_PUBLIC_PROFILE_BINDING_INVALID"
	result["sdk_authority_summary"] = summary
	return result


static func _r23d62_public_binding_receipts_exact(
	resolution: Dictionary,
	host_mapping: Dictionary,
	physical_binding: Dictionary,
) -> bool:
	var resolution_profile: Dictionary = resolution.get("profile", {})
	var host_bindings_value: Variant = host_mapping.get("ordered_bindings")
	var physical_bindings_value: Variant = physical_binding.get("ordered_bindings")
	if not (host_bindings_value is Array) or not (physical_bindings_value is Array):
		return false
	var host_bindings: Array = host_bindings_value
	var physical_bindings: Array = physical_bindings_value
	var host_sha256 := (
		"sha256:" + R23D62JsonTransportScript.stringify(host_mapping).sha256_text()
	)
	return (
		String(resolution.get("schema_version", ""))
		== "sporespore_actuator_cap_profile_receipt_v1"
		and String(resolution.get("requested_profile_id", ""))
		== R23D62_PROFILE_ID
		and String(resolution.get("support_status", "")) == "supported_exact"
		and resolution.get("refusal_reason", "unexpected") == null
		and String(resolution.get("profile_sha256", ""))
		== R23D62_PROFILE_SHA256
		and String(resolution_profile.get("profile_id", ""))
		== R23D62_PROFILE_ID
		and int(resolution.get("world_build_count", -1)) == 0
		and not bool(resolution.get("physics_state_modified", true))
		and String(host_mapping.get("schema_version", ""))
		== "sporespore_godot_actuator_cap_profile_binding_receipt_v1"
		and bool(host_mapping.get("ok", false))
		and String(host_mapping.get("profile_id", "")) == R23D62_PROFILE_ID
		and String(host_mapping.get("profile_sha256", ""))
		== R23D62_PROFILE_SHA256
		and String(host_mapping.get("host_mapping_id", ""))
		== R23D62_HOST_MAPPING_ID
		and bool(host_mapping.get("all_postbinding_readbacks_match", false))
		and int(host_mapping.get("validated_actuator_count", -1)) == 8
		and int(host_mapping.get("write_count", -1)) == 8
		and int(host_mapping.get("readback_count", -1)) == 8
		and host_bindings.size() == 8
		and int(host_mapping.get("world_build_count", -1)) == 0
		and not bool(host_mapping.get("physics_state_modified", true))
		and String(physical_binding.get("schema_version", ""))
		== "sporespore_qsdk_r23d62_physical_actuator_cap_binding_v1"
		and bool(physical_binding.get("ok", false))
		and String(physical_binding.get("engine_id", "")) == R23D62_ENGINE_ID
		and String(physical_binding.get("profile_id", "")) == R23D62_PROFILE_ID
		and String(physical_binding.get("profile_sha256", ""))
		== R23D62_PROFILE_SHA256
		and String(physical_binding.get("host_mapping_id", ""))
		== R23D62_HOST_MAPPING_ID
		and String(physical_binding.get("host_mapping_receipt_sha256", ""))
		== host_sha256
		and bool(
			physical_binding.get("completed_before_first_solver_step", false)
		)
		and int(physical_binding.get("solver_step_count_at_binding", -1)) == 0
		and int(physical_binding.get("validated_actuator_count", -1)) == 8
		and int(physical_binding.get("write_count", -1)) == 8
		and int(physical_binding.get("readback_count", -1)) == 8
		and bool(physical_binding.get("all_readbacks_match", false))
		and physical_bindings.size() == 8
	)


static func _r23d62_retain_trace(
	cell: Dictionary,
	rows: Array,
	attempt_root: String,
) -> Dictionary:
	var pending_root := attempt_root.path_join("pending-traces")
	if DirAccess.make_dir_recursive_absolute(pending_root) != OK:
		return _r23d62_failure("QSDK_R23D62_GJT_TRACE_ROOT_CREATE_FAILED")
	var rows_path := pending_root.path_join("%s.rows.json" % String(cell["cell_id"]))
	if FileAccess.file_exists(rows_path):
		return _r23d62_failure("QSDK_R23D62_GJT_TRACE_ROWS_ALREADY_EXIST")
	var file := FileAccess.open(rows_path, FileAccess.WRITE)
	if file == null:
		return _r23d62_failure("QSDK_R23D62_GJT_TRACE_ROWS_CREATE_FAILED")
	file.store_string(R23D62JsonTransportScript.stringify(rows))
	file.store_string("\n")
	file.flush()
	file = null
	var python := OS.get_environment(R23D62_PYTHON_ENV)
	if python.is_empty():
		python = "python"
	var powershell := OS.get_environment(R23D62_POWERSHELL_ENV)
	if powershell.is_empty():
		powershell = "pwsh"
	var output: Array = []
	var exit_code := OS.execute(
		python,
		PackedStringArray(
			[
				ProjectSettings.globalize_path(R23D62_EVALUATOR_PATH),
				"retain-trace",
				"--stage-id",
				String(cell["stage_id"]),
				"--cell-id",
				String(cell["cell_id"]),
				"--rows-json",
				rows_path,
				"--repo-root",
				ProjectSettings.globalize_path("res://"),
				"--attempt-root",
				attempt_root,
				"--powershell",
				powershell,
			]
		),
		output,
		true,
	)
	var marker := "QSDK_R23D62_TRACE_RETAINED "
	var matches: Array[String] = []
	for output_value in output:
		for line_value in String(output_value).split("\n"):
			var line := String(line_value).strip_edges()
			if line.begins_with(marker):
				matches.append(line.trim_prefix(marker))
	if exit_code != 0 or matches.size() != 1:
		return _r23d62_failure(
			"QSDK_R23D62_GJT_TRACE_RETENTION_FAILED:%d" % exit_code,
			{"output": output},
		)
	var parsed: Variant = JSON.parse_string(matches[0])
	if typeof(parsed) != TYPE_DICTIONARY:
		return _r23d62_failure("QSDK_R23D62_GJT_TRACE_RETENTION_RECEIPT_INVALID")
	var receipt: Dictionary = parsed
	if (
		String(receipt.get("schema_version", "")) != R23D62_TRACE_RETENTION_SCHEMA
		or String(receipt.get("stage_id", "")) != String(cell["stage_id"])
		or String(receipt.get("cell_id", "")) != String(cell["cell_id"])
		or int(receipt.get("campaign_seed", -1)) != int(cell["campaign_seed"])
		or not bool(receipt.get("retained_before_terminal_entry", false))
	):
		return _r23d62_failure(
			"QSDK_R23D62_GJT_TRACE_RETENTION_RECEIPT_INVALID",
			receipt,
		)
	var trace_artifact: Dictionary = (
		(receipt.get("trace_artifact", {}) as Dictionary).duplicate(true)
	)
	trace_artifact["trace_transport_id"] = R23D62_TRACE_TRANSPORT_ID
	trace_artifact["godot_runtime_version"] = String(
		Engine.get_version_info().get("string", "")
	)
	trace_artifact["selected_godot_invocation"] = R23D62_TRACE_TRANSPORT_INVOCATION
	trace_artifact["godot_json_sorted_keys"] = true
	trace_artifact["godot_json_full_precision"] = true
	trace_artifact["reported_error_recomputation_consistency_tolerance"] = 1.0e-15
	receipt["trace_artifact"] = trace_artifact
	receipt["ok"] = true
	receipt["failure_code"] = ""
	receipt["trace_transport_id"] = R23D62_TRACE_TRANSPORT_ID
	receipt["godot_runtime_version"] = String(
		Engine.get_version_info().get("string", "")
	)
	receipt["godot_json_full_precision"] = true
	return receipt


static func _r23d62_physical_authorization(
	cell: Dictionary,
	source_commit: String,
) -> Dictionary:
	if FileAccess.file_exists(R23D62_CLOSURE_PATH):
		return _r23d62_failure("QSDK_R23D62_GJT_CLOSED")
	var freeze_path := OS.get_environment(R23D62_FREEZE_PATH_ENV)
	var attempt_path := OS.get_environment(R23D62_ATTEMPT_PATH_ENV)
	var token := OS.get_environment(R23D62_TOKEN_ENV)
	var attempt_root := OS.get_environment(R23D62_ATTEMPT_ROOT_ENV)
	if (
		freeze_path.is_empty()
		or attempt_path.is_empty()
		or attempt_root.is_empty()
		or not FileAccess.file_exists(freeze_path)
		or not FileAccess.file_exists(attempt_path)
		or not DirAccess.dir_exists_absolute(attempt_root)
		or not R23D62BaseWorkerScript._valid_lower_hex(token, 32)
	):
		return _r23d62_failure("QSDK_R23D62_GJT_PHYSICAL_AUTHORIZATION_REQUIRED")
	var freeze := R23D62BaseWorkerScript._read_json(freeze_path)
	var attempt := R23D62BaseWorkerScript._read_json(attempt_path)
	var implementation := R23D62BaseWorkerScript._read_json(R23D62_IMPLEMENTATION_PATH)
	var dependency_policy: Dictionary = implementation.get("dependency_closure", {})
	var inventory: Dictionary = freeze.get("dependency_inventory", {})
	var zero_world: Dictionary = freeze.get("zero_world_receipt", {})
	var frozen_inputs: Dictionary = freeze.get("content_addressed_inputs", {})
	var adoption_input: Dictionary = frozen_inputs.get(
		"campaign_attestation_adoption",
		{},
	)
	var production_root := (
		ProjectSettings.globalize_path("res://../SporeSpore_Evidence")
		.simplify_path()
		.replace("\\", "/")
		.trim_suffix("/")
	)
	var normalized_attempt_root := attempt_root.simplify_path().replace("\\", "/").trim_suffix("/")
	var expected_cells := _r23d62_expected_matrix_cell_ids()
	var exact: bool = (
		(normalized_attempt_root == production_root or normalized_attempt_root.begins_with(production_root + "/"))
		and String(freeze.get("schema_version", "")) == R23D62_FREEZE_SCHEMA
		and String(freeze.get("campaign_id", "")) == R23D62_CAMPAIGN_ID
		and String(freeze.get("gate_id", "")) == R23D62_GATE_ID
		and String(freeze.get("status", "")) == "frozen_supervisor_only_physical_authorized"
		and String(freeze.get("preregistration_raw_sha256", ""))
		== R23D62BaseWorkerScript._raw_file_sha256(R23D62_PREREGISTRATION_PATH)
		and String(freeze.get("implementation_contract_raw_sha256", ""))
		== R23D62BaseWorkerScript._raw_file_sha256(R23D62_IMPLEMENTATION_PATH)
		and String(freeze.get("source_commit", "")) == source_commit
		and String(freeze.get("origin_main_commit", "")) == source_commit
		and String(freeze.get("live_github_main_commit", "")) == source_commit
		and R23D62BaseWorkerScript._valid_lower_hex(
			String(freeze.get("source_tree_git_oid", "")),
			40,
		)
		and bool(freeze.get("complete_zero_world_gate_passed", false))
		and String(zero_world.get("campaign_id", "")) == R23D62_CAMPAIGN_ID
		and String(zero_world.get("gate_id", "")) == R23D62_GATE_ID
		and int(zero_world.get("model_construction_count", -1)) == 0
		and int(zero_world.get("world_attempt_count", -1)) == 0
		and int(zero_world.get("world_build_count", -1)) == 0
		and not bool(zero_world.get("physical_execution_authorized", true))
		and not bool(zero_world.get("physical_acceptance_authority", true))
		and bool(freeze.get("dependency_inventory_complete", false))
		and String(inventory.get("schema_version", "")) == R23D62_DEPENDENCY_INVENTORY_SCHEMA
		and String(inventory.get("policy_id", "")) == R23D62_DEPENDENCY_POLICY_ID
		and String(inventory.get("inventory_projection_sha256", ""))
		== String(dependency_policy.get("expected_inventory_projection_sha256", ""))
		and bool(inventory.get("expected_transitive_path_set_exact", false))
		and bool(inventory.get("all_paths_tracked_with_exact_case", false))
		and bool(inventory.get("checkout_bytes_equal_git_blobs", false))
		and int(inventory.get("model_construction_count", -1)) == 0
		and int(inventory.get("world_attempt_count", -1)) == 0
		and int(inventory.get("world_build_count", -1)) == 0
		and freeze.get("source_bindings", []) == inventory.get("source_receipts", [])
		and int(freeze.get("declared_world_count", -1)) == expected_cells.size()
		and freeze.get("ordered_matrix_cell_ids", []) == expected_cells
		and bool(freeze.get("serial_execution_required", false))
		and bool(freeze.get("all_cells_run_regardless_of_intermediate_outcome", false))
		and not bool(freeze.get("terminal_restoration_or_taper_invoked", true))
		and bool(freeze.get("source_checkout_bytes_equal_git_blobs", false))
		and bool(freeze.get("reproducible_runtime_materialization_passed", false))
		and String(freeze.get("campaign_attestation_adoption_sha256", ""))
		== String(adoption_input.get("sha256", ""))
		and bool(freeze.get("physical_execution_authorized", false))
		and _r23d62_source_bindings_exact(freeze, implementation)
		and String(attempt.get("schema_version", "")) == R23D62_ATTEMPT_SCHEMA
		and String(attempt.get("campaign_id", "")) == R23D62_CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == R23D62_GATE_ID
		and String(attempt.get("freeze_raw_sha256", ""))
		== R23D62BaseWorkerScript._raw_file_sha256(freeze_path)
		and String(attempt.get("source_commit", "")) == source_commit
		and String(attempt.get("authorization_token", "")) == token
		and R23D62BaseWorkerScript._valid_lower_hex(String(attempt.get("attempt_id", "")), 32)
		and bool(attempt.get("physical_execution_authorized", false))
		and bool(attempt.get("single_use_supervisor_authorization", false))
		and bool(attempt.get("matrix_authorization_immutable_before_first_world", false))
		and bool(attempt.get("source_worktree_clean", false))
		and bool(attempt.get("source_matches_live_github_main", false))
		and bool(attempt.get("operation_lock_held", false))
		and bool(attempt.get("campaign_attestation_adoption_valid", false))
		and bool(attempt.get("content_addressed_inputs_retained", false))
		and attempt.get("content_addressed_inputs", {}) == frozen_inputs
		and bool(attempt.get("one_shot_attempt_unconsumed", false))
		and bool(attempt.get("all_cells_run_regardless_of_intermediate_outcome", false))
		and String(attempt.get("attempt_root", "")).simplify_path() == normalized_attempt_root
		and attempt.get("ordered_matrix_cell_ids", []) == expected_cells
		and OS.get_environment(R23D62_STAGE_ENV) == String(cell["stage_id"])
		and OS.get_environment(R23D62_CELL_ENV) == String(cell["cell_id"])
		and OS.get_environment(R23D62_ENGINE_ENV) == R23D62_ENGINE_ID
	)
	if not exact:
		return _r23d62_failure("QSDK_R23D62_GJT_PHYSICAL_AUTHORIZATION_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"attempt_root": normalized_attempt_root,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d62_expected_matrix_cell_ids() -> Array[String]:
	var expected_cells: Array[String] = []
	for engine_id in R23D62_ORDERED_ENGINE_IDS:
		for arm_id in R23D62_ORDERED_ARM_IDS:
			expected_cells.append(
				"%s__s%d__%s__%s"
				% [
					engine_id,
					R23D62_CAMPAIGN_SEED,
					R23D62_PROFILE_CELL_TAG,
					arm_id,
				]
			)
	return expected_cells


static func _r23d62_source_bindings_exact(
	freeze: Dictionary,
	implementation: Dictionary,
) -> bool:
	var policy: Dictionary = implementation.get("dependency_closure", {})
	var expected_value: Variant = policy.get("expected_transitive_paths", null)
	var bindings_value: Variant = freeze.get("source_bindings", null)
	var inventory: Dictionary = freeze.get("dependency_inventory", {})
	if typeof(expected_value) != TYPE_ARRAY or typeof(bindings_value) != TYPE_ARRAY:
		return false
	var expected: Array = expected_value
	var bindings: Array = bindings_value
	if (
		expected.is_empty()
		or bindings.size() != expected.size()
		or inventory.get("ordered_paths", []) != expected
		or int(inventory.get("transitive_path_count", -1)) != expected.size()
	):
		return false
	var observed := {}
	for item_value in bindings:
		if typeof(item_value) != TYPE_DICTIONARY:
			return false
		var item: Dictionary = item_value
		var path := String(item.get("path", ""))
		if path.is_empty() or observed.has(path):
			return false
		observed[path] = String(item.get("raw_sha256", ""))
	for path_value in expected:
		if typeof(path_value) != TYPE_STRING:
			return false
		var path := String(path_value)
		var resource_path := "res://%s" % path
		if (
			path.is_empty()
			or not FileAccess.file_exists(resource_path)
			or String(observed.get(path, ""))
			!= R23D62BaseWorkerScript._raw_file_sha256(resource_path)
		):
			return false
	return true


static func _r23d62_declared_cell(matrix: Dictionary, cell_id: String) -> Dictionary:
	for value in matrix.get("cells", []):
		if typeof(value) == TYPE_DICTIONARY and String(value.get("cell_id", "")) == cell_id:
			var item: Dictionary = (value as Dictionary).duplicate(true)
			var seed_value: Variant = item.get("campaign_seed", null)
			if typeof(seed_value) != TYPE_INT and typeof(seed_value) != TYPE_FLOAT:
				return {}
			var normalized_seed := int(seed_value)
			if float(seed_value) != float(normalized_seed):
				return {}
			item["campaign_seed"] = normalized_seed
			item["onset_id"] = R23D62_ONSET_ID
			item["turn_start_semantic_step"] = R23D62_TURN_START_STEP
			item["ok"] = true
			item["failure_code"] = ""
			item["world_attempt_count"] = 0
			item["world_build_count"] = 0
			item["physical_acceptance_authority"] = false
			return item
	return {}


static func _r23d62_arm_offsets_exact(values: Variant) -> bool:
	if typeof(values) != TYPE_ARRAY or (values as Array).size() != 3:
		return false
	for index in range(R23D62_ORDERED_ARM_IDS.size()):
		var value: Variant = (values as Array)[index]
		if (
			(typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT)
			or not is_finite(float(value))
			or float(value)
			!= float(R23D62_ARM_OFFSETS[R23D62_ORDERED_ARM_IDS[index]])
		):
			return false
	return true


static func _r23d62_reanchor_steps_exact(values: Variant) -> bool:
	var expected := [600, 1800, 2400]
	if typeof(values) != TYPE_ARRAY or (values as Array).size() != expected.size():
		return false
	for index in range(expected.size()):
		var value: Variant = (values as Array)[index]
		if (
			(typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT)
			or float(value) != float(expected[index])
		):
			return false
	return true


static func _r23d62_profile_id_from_cell_id(cell_id: String) -> String:
	var marker := "__%s__" % R23D62_PROFILE_CELL_TAG
	return R23D62_PROFILE_ID if marker in cell_id else ""


static func _r23d62_parse_arguments(args: PackedStringArray) -> Dictionary:
	var values := {}
	var preflight_only := false
	var authorization_preflight_only := false
	var index := 0
	while index < args.size():
		var argument := String(args[index])
		if argument == "--preflight-only" and not preflight_only:
			preflight_only = true
			index += 1
			continue
		if argument == "--authorization-preflight-only" and not authorization_preflight_only:
			authorization_preflight_only = true
			index += 1
			continue
		if ["--stage", "--onset", "--seed", "--profile", "--arm", "--source-commit"].has(argument):
			if values.has(argument) or index + 1 >= args.size():
				return _r23d62_failure("QSDK_R23D62_GJT_ARGUMENT_DUPLICATE_OR_MISSING")
			values[argument] = String(args[index + 1])
			index += 2
			continue
		return _r23d62_failure("QSDK_R23D62_GJT_ARGUMENT_UNKNOWN:%s" % argument)
	var source_required := not preflight_only
	var seed_text := String(values.get("--seed", ""))
	if (
		not values.has("--stage")
		or not values.has("--onset")
		or not values.has("--seed")
		or not values.has("--profile")
		or not values.has("--arm")
		or not seed_text.is_valid_int()
		or (preflight_only and authorization_preflight_only)
		or source_required != values.has("--source-commit")
	):
		return _r23d62_failure("QSDK_R23D62_GJT_ARGUMENTS_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": String(values["--stage"]),
		"onset_id": String(values["--onset"]),
		"campaign_seed": seed_text.to_int(),
		"profile_id": String(values["--profile"]),
		"arm_id": String(values["--arm"]),
		"preflight_only": preflight_only,
		"authorization_preflight_only": authorization_preflight_only,
		"source_commit": String(values.get("--source-commit", "")),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d62_cell(
	stage_id: String,
	onset_id: String,
	campaign_seed: int,
	profile_id: String,
	arm_id: String,
) -> Dictionary:
	if (
		stage_id != R23D62_STAGE_ID
		or onset_id != R23D62_ONSET_ID
		or campaign_seed != R23D62_CAMPAIGN_SEED
		or profile_id != R23D62_PROFILE_ID
		or not R23D62_ARM_OFFSETS.has(arm_id)
	):
		return _r23d62_failure("QSDK_R23D62_GJT_CELL_IDENTITY_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": stage_id,
		"cell_id": (
			"%s__s%d__%s__%s"
			% [R23D62_ENGINE_ID, campaign_seed, R23D62_PROFILE_CELL_TAG, arm_id]
		),
		"engine_id": R23D62_ENGINE_ID,
		"campaign_seed": campaign_seed,
		"profile_id": profile_id,
		"host_mapping_id": R23D62_HOST_MAPPING_ID,
		"onset_id": onset_id,
		"turn_start_semantic_step": R23D62_TURN_START_STEP,
		"arm_id": arm_id,
		"turn_heading_offset_rad": float(R23D62_ARM_OFFSETS[arm_id]),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _r23d62_rebrand_terminal(
	value: Dictionary,
	cell: Dictionary,
) -> Dictionary:
	var result := value.duplicate(true)
	var success := String(result.get("schema_version", "")) == R23D48_REPORT_SCHEMA
	result["schema_version"] = R23D62_REPORT_SCHEMA if success else R23D62_FAILURE_SCHEMA
	result["campaign_id"] = R23D62_CAMPAIGN_ID
	result["gate_id"] = R23D62_GATE_ID
	result["stage_id"] = R23D62_STAGE_ID
	result["engine_id"] = R23D62_ENGINE_ID
	result["cell_id"] = String(cell["cell_id"])
	result["campaign_seed"] = int(cell["campaign_seed"])
	result["profile_id"] = String(cell["profile_id"])
	result["host_mapping_id"] = String(cell["host_mapping_id"])
	result["actuator_cap_profile_resolution_receipt"] = (
		_r23d62_last_resolution_receipt.duplicate(true)
	)
	result["actuator_cap_profile_host_mapping_receipt"] = (
		_r23d62_last_host_mapping_receipt.duplicate(true)
	)
	result["actuator_cap_profile_physical_binding_receipt"] = (
		_r23d62_last_physical_binding_receipt.duplicate(true)
	)
	result["task_frame_origin_policy_id"] = R23D62_TASK_ORIGIN_POLICY_ID
	result["claims"] = R23D62_FALSE_CLAIMS.duplicate(true)
	if result.has("failure_code"):
		result["failure_code"] = String(result["failure_code"]).replace(
			"QSDK_R23D48",
			"QSDK_R23D62",
		).replace("QSDK_R23D58", "QSDK_R23D62").replace(
			"QSDK_R23D59",
			"QSDK_R23D62",
		).replace(
			"QSDK_R23D60",
			"QSDK_R23D62",
		)
	return result


static func _r23d62_rebrand_failure(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	result["ok"] = false
	result["failure_code"] = String(
		result.get("failure_code", "QSDK_R23D62_GJT_INHERITED_FAILURE")
	).replace("QSDK_R23D3", "QSDK_R23D62").replace(
		"QSDK_R23D48",
		"QSDK_R23D62",
	).replace(
		"QSDK_R23D58",
		"QSDK_R23D62",
	).replace("QSDK_R23D59", "QSDK_R23D62").replace(
		"QSDK_R23D60",
		"QSDK_R23D62",
	)
	return result


static func _r23d62_failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
