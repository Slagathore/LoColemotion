extends "res://tests/test_sdk_qsdk_r23d48_godot_jolt_physical_worker.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Full-precision outcome-exposed actuator/phase worker for QSDK-R23D57.
##
## R23D57 preserves R23D56's real Jolt fixture, seed, R23D29 controller,
## support-loss startup transform, schedule, horizon, task-origin policy,
## live cap route, actuator/phase observation, evaluator predicates, and
## contextual physical gates. Its sole declared change is exact trace
## transport through Godot 4.7 JSON full_precision.

const R23D57BaseWorkerScript := preload(
	"res://tests/test_sdk_qsdk_r23d3_godot_jolt_worker.gd"
)
const R23D48WorkerScript := preload(
	"res://tests/test_sdk_qsdk_r23d48_godot_jolt_physical_worker.gd"
)
const R23D57AdapterScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_adapter.gd"
)
const R23D57WaveGaitScript := preload(
	"res://scripts/lab/gait/physical_wave_gait_quadruped.gd"
)

const R23D57_PREREGISTRATION_PATH := (
	"res://sdk/turning/r23d57_godot_full_precision_trace_actuator_phase_characterization_preregistration_v1.json"
)
const R23D57_IMPLEMENTATION_PATH := (
	"res://sdk/turning/r23d57_godot_full_precision_trace_actuator_phase_characterization_implementation_v1.json"
)
const R23D57_EVALUATOR_PATH := (
	"res://sdk/turning/r23d57_godot_full_precision_trace_actuator_phase_characterization_evaluator.py"
)
const R23D57_CLOSURE_PATH := (
	"res://sdk/turning/r23d57_godot_full_precision_trace_actuator_phase_characterization_closure_v1.json"
)

const R23D57_CAMPAIGN_ID := (
	"QSDK-R23D57-GODOT-FULL-PRECISION-TRACE-ACTUATOR-PHASE-CHARACTERIZATION-DEVELOPMENT"
)
const R23D57_GATE_ID := "QSDK-R23D57"
const R23D57_STAGE_ID := "godot_full_precision_trace_actuator_phase_characterization_development"
const R23D57_ENGINE_ID := "godot_jolt"
const R23D57_CANDIDATE_ID := "r23d29_r23d53_condition_post_r23d55_valid_route_full_precision_trace_actuator_phase_characterization_development"
const R23D57_ONSET_ID := "onset_600"
const R23D57_POLICY_ID := (
	"sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
	+ "stability_guarded_steering_v1"
)
const R23D57_MEMORY_SCHEMA := (
	"sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
)
const R23D57_TASK_ORIGIN_POLICY_ID := "warmup_preserving_command_onset_origin_reanchor_v1"
const R23D57_SCHEDULE_ID := "qsdk_r23d3_selected_onset_turn_return_v1"
const R23D57_SEED := 21512
const R23D57_TURN_START_STEP := 600
const R23D57_INITIAL_SCHEDULE_BIND_STEP := 0
const R23D57_FIXED_ORIGIN_LAST_STEP := 599
const R23D57_EXPECTED_REANCHOR_STEPS := [600, 1800, 2400]
const R23D57_ACTUATOR_PHASE_OBSERVATION_SCHEMA := (
	"sporespore_godot_jolt_actuator_phase_observation_v1"
)
const R23D57_LIVE_FIXTURE_CAP_BINDING_POLICY_ID := (
	"sporespore_godot_jolt_live_fixture_compiled_actuator_cap_binding_v1"
)
const R23D57_LIVE_FIXTURE_CAP_BINDING_RECEIPT_SCHEMA := (
	"sporespore_godot_jolt_live_fixture_actuator_cap_binding_receipt_v1"
)
const R23D57_LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS := 2.5e-7
const R23D57_TRACE_TRANSPORT_ID := (
	"godot_4_7_json_stringify_full_precision_binary64_v1"
)
const R23D57_GODOT_RUNTIME_VERSION := "4.7-stable (official)"
const R23D57_TRACE_TRANSPORT_INVOCATION := "JSON.stringify(rows, \"\", true, true)"
const R23D57_EXIT_DRAIN_PROCESS_FRAME_COUNT := 2
const R23D57_SUPERVISED_TERMINATION_ENV := (
	"SPORESPORE_QSDK_R23D57_SUPERVISED_TERMINATION"
)
const R23D57_TERMINATION_NONCE_ENV := "SPORESPORE_QSDK_R23D57_TERMINATION_NONCE"
const R23D57_TERMINATION_PROTOCOL_ID := (
	"godot_4_7_gdscript_shutdown_containment_v1"
)

var _r23d57_exit_scheduled := false
var _r23d57_pending_exit_code := 0
var _r23d57_pending_exit_process_frames := 0
var _r23d57_pending_receipt_kind := ""

const R23D57_PREFLIGHT_SCHEMA := (
	"sporespore_qsdk_r23d57_godot_jolt_worker_preflight_v1"
)
const R23D57_REPORT_SCHEMA := "sporespore_qsdk_r23d57_engine_cell_report_v1"
const R23D57_FAILURE_SCHEMA := "sporespore_qsdk_r23d57_worker_failure_v1"
const R23D57_TRACE_RETENTION_SCHEMA := "sporespore_qsdk_r23d57_trace_retention_v1"
const R23D57_FREEZE_SCHEMA := "sporespore_qsdk_r23d57_physical_freeze_v1"
const R23D57_ATTEMPT_SCHEMA := "sporespore_qsdk_r23d57_attempt_v1"

const R23D57_FREEZE_PATH_ENV := "SPORESPORE_QSDK_R23D57_FREEZE"
const R23D57_ATTEMPT_PATH_ENV := "SPORESPORE_QSDK_R23D57_ATTEMPT"
const R23D57_TOKEN_ENV := "SPORESPORE_QSDK_R23D57_TOKEN"
const R23D57_STAGE_ENV := "SPORESPORE_QSDK_R23D57_STAGE"
const R23D57_CELL_ENV := "SPORESPORE_QSDK_R23D57_CELL"
const R23D57_ENGINE_ENV := "SPORESPORE_QSDK_R23D57_ENGINE"
const R23D57_ATTEMPT_ROOT_ENV := "SPORESPORE_QSDK_R23D57_ATTEMPT_ROOT"
const R23D57_PYTHON_ENV := "SPORESPORE_QSDK_R23D57_PYTHON"
const R23D57_POWERSHELL_ENV := "SPORESPORE_QSDK_R23D57_POWERSHELL"

const R23D57_ARM_OFFSETS := {
	"reference_zero": 0.0,
	"positive_heading": 0.2,
	"negative_heading": -0.2,
}
const R23D57_FALSE_CLAIMS := {
	"live_fixture_actuator_cap_binding_verified": false,
	"actuator_phase_characterization_complete": false,
	"turning_mechanism_selected": false,
	"godot_jolt_r23d29_turning": false,
	"finite_three_engine_turning": false,
	"portable_basic_turning": false,
	"q_sdk_r23_satisfied": false,
	"cross_engine_equivalence": false,
	"population_robustness": false,
	"prone_to_standing": false,
	"release_authorized": false,
	"physical_acceptance_authority": false,
}


func _run() -> void:
	var parsed := _r23d48_parse_arguments(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		print("QSDK_R23D57_GODOT_JOLT_FAILURE ", JSON.stringify(parsed))
		parsed.clear()
		_r23d57_schedule_quit(1, "failure")
		return
	var cell := _r23d57_cell(
		String(parsed["stage_id"]),
		String(parsed["onset_id"]),
		String(parsed["arm_id"]),
	)
	if not bool(cell.get("ok", false)):
		print("QSDK_R23D57_GODOT_JOLT_FAILURE ", JSON.stringify(cell))
		cell.clear()
		parsed.clear()
		_r23d57_schedule_quit(1, "failure")
		return
	if bool(parsed["preflight_only"]):
		var preflight: Dictionary = await _r23d57_run_preflight(cell)
		if not bool(preflight.get("ok", false)):
			print("QSDK_R23D57_GODOT_JOLT_FAILURE ", JSON.stringify(preflight))
			preflight.clear()
			cell.clear()
			parsed.clear()
			_r23d57_schedule_quit(1, "failure")
			return
		preflight["orderly_exit_drain_process_frame_count"] = (
			R23D57_EXIT_DRAIN_PROCESS_FRAME_COUNT
		)
		print("QSDK_R23D57_GODOT_JOLT_PREFLIGHT ", JSON.stringify(preflight))
		preflight.clear()
		cell.clear()
		parsed.clear()
		_r23d57_schedule_quit(0, "preflight")
		return
	if bool(parsed["authorization_preflight_only"]):
		var authorization := _r23d57_physical_authorization(
			cell,
			String(parsed["source_commit"]),
		)
		if not bool(authorization.get("ok", false)):
			print("QSDK_R23D57_GODOT_JOLT_FAILURE ", JSON.stringify(authorization))
			authorization.clear()
			cell.clear()
			parsed.clear()
			_r23d57_schedule_quit(1, "failure")
			return
		print(
			"QSDK_R23D57_GODOT_JOLT_AUTHORIZATION_PREFLIGHT ",
			JSON.stringify(
				{
					"schema_version": "sporespore_qsdk_r23d57_godot_jolt_production_authorization_preflight_v1",
					"campaign_id": R23D57_CAMPAIGN_ID,
					"gate_id": R23D57_GATE_ID,
					"engine_id": R23D57_ENGINE_ID,
					"stage_id": String(cell["stage_id"]),
					"cell_id": String(cell["cell_id"]),
					"actual_production_authorization_function": "_r23d57_physical_authorization",
					"authorization_passed": true,
					"returned_before_model": true,
					"model_construction_count": 0,
					"world_attempt_count": 0,
					"world_build_count": 0,
					"physical_acceptance_authority": false,
				}
			)
		)
		authorization.clear()
		cell.clear()
		parsed.clear()
		_r23d57_schedule_quit(0, "authorization_preflight")
		return
	var terminal: Dictionary = await _r23d48_run_physical(
		cell,
		String(parsed["source_commit"]),
	)
	terminal = _r23d57_rebrand_terminal(terminal)
	var terminal_exit_code := 0 if String(terminal.get("schema_version", "")) == R23D57_REPORT_SCHEMA else 1
	print("QSDK_R23D57_GODOT_JOLT_TERMINAL ", JSON.stringify(terminal))
	terminal.clear()
	cell.clear()
	parsed.clear()
	_r23d57_schedule_quit(terminal_exit_code, "terminal")


func _r23d57_schedule_quit(exit_code: int, receipt_kind: String) -> void:
	# Godot 4.7 can intermittently raise 0xC0000005 in
	# GDScriptLanguage::finish after a complete worker receipt, as diagnosed in
	# R51. Return from _run() and consume a small zero-physics drain before either
	# ordinary self-exit or the nonce-bound containment used by this campaign.
	if _r23d57_exit_scheduled:
		push_error("QSDK-R23D57 duplicate orderly-exit schedule")
		return
	_r23d57_exit_scheduled = true
	_r23d57_pending_exit_code = exit_code
	_r23d57_pending_receipt_kind = receipt_kind
	_r23d57_pending_exit_process_frames = R23D57_EXIT_DRAIN_PROCESS_FRAME_COUNT
	process_frame.connect(_r23d57_orderly_exit_process_frame, CONNECT_ONE_SHOT)


func _r23d57_orderly_exit_process_frame() -> void:
	_r23d57_pending_exit_process_frames -= 1
	if _r23d57_pending_exit_process_frames > 0:
		process_frame.connect(_r23d57_orderly_exit_process_frame, CONNECT_ONE_SHOT)
		return
	if OS.get_environment(R23D57_SUPERVISED_TERMINATION_ENV) == "1":
		var nonce := OS.get_environment(R23D57_TERMINATION_NONCE_ENV)
		if nonce.is_empty():
			push_error("QSDK-R23D57 supervised termination nonce is missing")
			quit(1)
			return
		print(
			"QSDK_R23D57_GODOT_SUPERVISOR_TERMINATION_READY ",
			JSON.stringify(
				{
					"schema_version": "sporespore_godot_supervised_termination_ready_v1",
					"termination_protocol_id": R23D57_TERMINATION_PROTOCOL_ID,
					"termination_nonce": nonce,
					"process_id": OS.get_process_id(),
					"requested_exit_code": _r23d57_pending_exit_code,
					"worker_receipt_kind": _r23d57_pending_receipt_kind,
					"worker_receipt_emitted": true,
					"drained_process_frame_count": R23D57_EXIT_DRAIN_PROCESS_FRAME_COUNT,
					"physics_evidence_authority": false,
				}
			)
		)
		return
	quit(_r23d57_pending_exit_code)


func _r23d57_run_preflight(cell: Dictionary) -> Dictionary:
	var prepared := _campaign_prepare(cell)
	if not bool(prepared.get("ok", false)):
		return _r23d57_rebrand_failure(prepared)
	var inherited: Dictionary = await super._r23d48_run_preflight(cell)
	if not bool(inherited.get("ok", false)):
		return _r23d57_rebrand_failure(inherited)
	var authority: Dictionary = prepared.get("authority_options", {})
	var entrypoint: Dictionary = inherited.get("entrypoint_preflight", {})
	var trace_options: Dictionary = entrypoint.get("sdk_physical_trace_options", {})
	var origin_canary := _r23d57_origin_transition_canary(
		cell,
		prepared.get("schedule", {}),
	)
	if (
		String(authority.get("task_frame_origin_policy_id", ""))
		!= R23D57_TASK_ORIGIN_POLICY_ID
		or String(authority.get("live_fixture_actuator_cap_binding_policy_id", ""))
		!= R23D57_LIVE_FIXTURE_CAP_BINDING_POLICY_ID
		or not bool(entrypoint.get("sdk_live_fixture_actuator_cap_binding_enabled", false))
		or String(entrypoint.get("sdk_live_fixture_actuator_cap_binding_policy_id", ""))
		!= R23D57_LIVE_FIXTURE_CAP_BINDING_POLICY_ID
		or bool(entrypoint.get("sdk_live_fixture_actuator_cap_binding_executed", true))
		or String(trace_options.get("actuator_phase_observation_schema_version", ""))
		!= R23D57_ACTUATOR_PHASE_OBSERVATION_SCHEMA
		or not bool(origin_canary.get("ok", false))
	):
		return _r23d57_failure(
			"QSDK_R23D57_GJT_PREFLIGHT_INVALID",
			{
				"inherited": inherited,
				"authority_options": authority,
				"trace_options": trace_options,
				"origin_canary": origin_canary,
			},
		)
	var result := inherited.duplicate(true)
	result["schema_version"] = R23D57_PREFLIGHT_SCHEMA
	result["campaign_id"] = R23D57_CAMPAIGN_ID
	result["gate_id"] = R23D57_GATE_ID
	result["stage_id"] = R23D57_STAGE_ID
	result["cell_id"] = String(cell["cell_id"])
	result["arm_id"] = String(cell["arm_id"])
	result["controller_policy_id"] = R23D57_POLICY_ID
	result["controller_memory_schema"] = R23D57_MEMORY_SCHEMA
	result["preregistration_raw_sha256"] = R23D57BaseWorkerScript._raw_file_sha256(
		R23D57_PREREGISTRATION_PATH
	)
	result["task_frame_origin_policy_id"] = R23D57_TASK_ORIGIN_POLICY_ID
	result["task_frame_origin_transition_canary"] = origin_canary
	result["actuator_phase_observation_schema_version"] = (
		R23D57_ACTUATOR_PHASE_OBSERVATION_SCHEMA
	)
	result["actuator_phase_observation_required_on_every_trace_row"] = true
	result["live_fixture_actuator_cap_binding_policy_id"] = (
		R23D57_LIVE_FIXTURE_CAP_BINDING_POLICY_ID
	)
	result["live_fixture_actuator_cap_binding_required"] = true
	result["live_fixture_actuator_cap_binding_executed"] = false
	result["live_fixture_actuator_cap_binding_execution_deferred_until_after_world_build"] = true
	result["trace_transport_id"] = R23D57_TRACE_TRANSPORT_ID
	result["godot_runtime_version"] = String(
		Engine.get_version_info().get("string", "")
	)
	result["godot_json_full_precision"] = true
	return result


func _campaign_physical_authorization(
	cell: Dictionary,
	source_commit: String,
) -> Dictionary:
	return _r23d57_physical_authorization(cell, source_commit)


func _campaign_run_preflight(cell: Dictionary) -> Dictionary:
	return await _r23d57_run_preflight(cell)


func _campaign_prepare(cell: Dictionary) -> Dictionary:
	var declaration := R23D57BaseWorkerScript._read_json(R23D57_PREREGISTRATION_PATH)
	var matrix: Dictionary = declaration.get("frozen_matrix", {})
	var cap_binding: Dictionary = declaration.get("required_live_fixture_cap_binding", {})
	var trace_transport: Dictionary = declaration.get("required_trace_transport", {})
	if (
		String(declaration.get("status", "")) != "prospective_zero_world_only"
		or String(declaration.get("campaign_id", "")) != R23D57_CAMPAIGN_ID
		or String(declaration.get("gate_id", "")) != R23D57_GATE_ID
		or String(declaration.get("question_class", "")) != "development"
		or not bool(declaration.get("physical_question_declared", false))
		or bool(declaration.get("physical_campaign_opened", true))
		or String(matrix.get("stage_id", "")) != R23D57_STAGE_ID
		or int(matrix.get("seed", -1)) != R23D57_SEED
		or int(matrix.get("controller_step_count", -1)) != CONTROLLER_STEPS
		or String(matrix.get("controller_policy_id", "")) != R23D57_POLICY_ID
		or String(matrix.get("controller_memory_schema", "")) != R23D57_MEMORY_SCHEMA
		or String(matrix.get("task_frame_origin_policy_id", ""))
		!= R23D57_TASK_ORIGIN_POLICY_ID
		or int(matrix.get("initial_schedule_bind_semantic_step", -1))
		!= R23D57_INITIAL_SCHEDULE_BIND_STEP
		or int(matrix.get("fixed_origin_last_semantic_step", -1))
		!= R23D57_FIXED_ORIGIN_LAST_STEP
		or not _r23d57_expected_reanchor_steps_exact(
			matrix.get("expected_reanchor_semantic_steps", null)
		)
		or bool(matrix.get("terminal_restoration_or_taper_invoked", true))
		or String(cap_binding.get("policy_id", ""))
		!= R23D57_LIVE_FIXTURE_CAP_BINDING_POLICY_ID
		or not bool(
			cap_binding.get("required_before_first_authoritative_controller_step", false)
		)
		or int(cap_binding.get("expected_actuator_count", -1)) != 8
		or int(cap_binding.get("exact_write_count", -1)) != 8
		or int(cap_binding.get("exact_readback_count", -1)) != 8
		or float(cap_binding.get("maximum_readback_error_nms", -1.0))
		!= R23D57_LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
		or String(trace_transport.get("transport_id", ""))
		!= R23D57_TRACE_TRANSPORT_ID
		or String(trace_transport.get("godot_runtime_version", ""))
		!= R23D57_GODOT_RUNTIME_VERSION
		or String(Engine.get_version_info().get("string", ""))
		!= R23D57_GODOT_RUNTIME_VERSION
		or String(trace_transport.get("selected_godot_invocation", ""))
		!= R23D57_TRACE_TRANSPORT_INVOCATION
		or not bool(trace_transport.get("sorted_keys_required", false))
		or not bool(trace_transport.get("full_precision_required", false))
		or float(trace_transport.get("reported_error_recomputation_consistency_tolerance", -1.0))
		!= 1.0e-15
	):
		return _r23d57_failure(
			"QSDK_R23D57_GJT_DECLARATION_INVALID",
			{
				"status": declaration.get("status"),
				"campaign_id": declaration.get("campaign_id"),
				"gate_id": declaration.get("gate_id"),
				"stage_id": matrix.get("stage_id"),
				"seed": matrix.get("seed"),
				"controller_step_count": matrix.get("controller_step_count"),
				"controller_policy_id": matrix.get("controller_policy_id"),
				"controller_memory_schema": matrix.get("controller_memory_schema"),
				"task_frame_origin_policy_id": matrix.get("task_frame_origin_policy_id"),
				"initial_schedule_bind_semantic_step": matrix.get(
					"initial_schedule_bind_semantic_step"
				),
				"fixed_origin_last_semantic_step": matrix.get(
					"fixed_origin_last_semantic_step"
				),
				"expected_reanchor_semantic_steps": matrix.get(
					"expected_reanchor_semantic_steps"
				),
				"terminal_restoration_or_taper_invoked": matrix.get(
					"terminal_restoration_or_taper_invoked"
				),
			},
		)
	var prepared := R23D48WorkerScript._r23d48_prepare(cell)
	if not bool(prepared.get("ok", false)):
		return _r23d57_rebrand_failure(prepared)
	var authority: Dictionary = (prepared["authority_options"] as Dictionary).duplicate(true)
	authority["task_frame_origin_policy_id"] = R23D57_TASK_ORIGIN_POLICY_ID
	authority["live_fixture_actuator_cap_binding_policy_id"] = (
		R23D57_LIVE_FIXTURE_CAP_BINDING_POLICY_ID
	)
	prepared["authority_options"] = authority
	return prepared


func _campaign_retain_trace(
	cell: Dictionary,
	rows: Array,
	attempt_root: String,
) -> Dictionary:
	return _r23d57_retain_trace(cell, rows, attempt_root)


func _campaign_trace_diagnostic(
	cell: Dictionary,
	trace_container: Dictionary,
) -> Dictionary:
	var diagnostic := R23D48WorkerScript._r23d48_trace_diagnostic(
		cell,
		trace_container,
	)
	diagnostic["schema_version"] = "sporespore_qsdk_r23d57_trace_diagnostic_v1"
	diagnostic["campaign_id"] = R23D57_CAMPAIGN_ID
	diagnostic["gate_id"] = R23D57_GATE_ID
	diagnostic["stage_id"] = R23D57_STAGE_ID
	return diagnostic


func _campaign_retain_trace_diagnostic(
	cell: Dictionary,
	diagnostic: Dictionary,
	attempt_root: String,
) -> Dictionary:
	return R23D48WorkerScript._r23d48_retain_trace_diagnostic(
		cell,
		diagnostic,
		attempt_root,
		R23D57_POWERSHELL_ENV,
	)


func _campaign_trace_diagnostic_summary(diagnostic: Dictionary) -> Dictionary:
	return R23D48WorkerScript._r23d48_trace_diagnostic_summary(diagnostic)


func _run_wave(prepared: Dictionary, preflight_before_world: bool) -> Dictionary:
	var configured := prepared.duplicate(true)
	var authority: Dictionary = (
		(configured.get("authority_options", {}) as Dictionary).duplicate(true)
	)
	authority["task_frame_origin_policy_id"] = R23D57_TASK_ORIGIN_POLICY_ID
	authority["live_fixture_actuator_cap_binding_policy_id"] = (
		R23D57_LIVE_FIXTURE_CAP_BINDING_POLICY_ID
	)
	configured["authority_options"] = authority
	var trace_options: Dictionary = (
		(configured.get("trace_options", {}) as Dictionary).duplicate(true)
	)
	trace_options["actuator_phase_observation_schema_version"] = (
		R23D57_ACTUATOR_PHASE_OBSERVATION_SCHEMA
	)
	var trace_result := R23D57WaveGaitScript.compile_sdk_physical_trace_options(
		trace_options
	)
	if not bool(trace_result.get("ok", false)):
		return _r23d57_rebrand_failure(trace_result)
	configured["trace_options"] = trace_options
	configured["trace_configuration_sha256"] = String(
		trace_result.get("sdk_physical_trace_configuration_sha256", "")
	)
	var result: Dictionary = await super._run_wave(configured, preflight_before_world)
	if preflight_before_world:
		return result
	# The shared R48 report projects only sdk_authority_summary. Preserve the
	# R55 one-time binding receipt inside that projected object so the frozen
	# R56 evaluator can prove the policy, eight writes, and eight readbacks from
	# every successful physical terminal instead of inferring them from source.
	var cap_receipt: Dictionary = result.get(
		"sdk_live_fixture_actuator_cap_binding_receipt",
		{},
	)
	var sdk_summary: Dictionary = (
		(result.get("sdk_authority_summary", {}) as Dictionary).duplicate(true)
	)
	var cap_receipt_exact := _r23d57_cap_binding_receipt_exact(cap_receipt)
	sdk_summary["r23d57_live_fixture_actuator_cap_binding_policy_id"] = (
		R23D57_LIVE_FIXTURE_CAP_BINDING_POLICY_ID
	)
	sdk_summary["r23d57_live_fixture_actuator_cap_binding_receipt"] = (
		cap_receipt.duplicate(true)
	)
	sdk_summary["r23d57_live_fixture_actuator_cap_binding_integrity_passed"] = (
		cap_receipt_exact
	)
	if not cap_receipt_exact:
		sdk_summary["ok"] = false
		sdk_summary["failure_code"] = "QSDK_R23D57_GJT_LIVE_FIXTURE_CAP_BINDING_INVALID"
	result["sdk_authority_summary"] = sdk_summary
	return result


static func _r23d57_cap_binding_receipt_exact(receipt: Dictionary) -> bool:
	return (
		String(receipt.get("schema_version", ""))
		== R23D57_LIVE_FIXTURE_CAP_BINDING_RECEIPT_SCHEMA
		and bool(receipt.get("ok", false))
		and String(receipt.get("failure_code", "")) == ""
		and String(receipt.get("policy_id", ""))
		== R23D57_LIVE_FIXTURE_CAP_BINDING_POLICY_ID
		and int(receipt.get("validated_actuator_count", -1)) == 8
		and int(receipt.get("validated_limb_count", -1)) == 4
		and int(receipt.get("unique_host_joint_object_count", -1)) == 8
		and int(receipt.get("write_count", -1)) == 8
		and int(receipt.get("readback_count", -1)) == 8
		and float(receipt.get("maximum_postbinding_readback_error_nms", INF))
		<= R23D57_LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
		and bool(receipt.get("all_fixture_composition_markers_valid", false))
		and bool(receipt.get("all_host_joint_names_valid", false))
		and bool(receipt.get("all_postbinding_readbacks_match", false))
		and bool(receipt.get("configured_parameter_readback_only", false))
		and not bool(receipt.get("measured_motor_torque_available", true))
		and not bool(receipt.get("measured_motor_impulse_available", true))
		and int(receipt.get("world_attempt_count", -1)) == 0
		and int(receipt.get("world_build_count", -1)) == 0
		and not bool(receipt.get("physics_state_modified", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
	)


static func _r23d57_origin_transition_canary(
	cell: Dictionary,
	requested_schedule: Dictionary,
) -> Dictionary:
	var schedule_result := R23D57WaveGaitScript.compile_sdk_heading_schedule_options(
		requested_schedule
	)
	if not bool(schedule_result.get("ok", false)):
		return _r23d57_failure(
			"QSDK_R23D57_GJT_ORIGIN_SCHEDULE_COMPILE_INVALID",
			schedule_result,
		)
	var compiled_schedule: Dictionary = schedule_result.get(
		"sdk_heading_schedule_options",
		{},
	)
	if String(compiled_schedule.get("schedule_id", "")) != R23D57_SCHEDULE_ID:
		return _r23d57_failure(
			"QSDK_R23D57_GJT_ORIGIN_SCHEDULE_IDENTITY_INVALID",
			compiled_schedule,
		)
	var active_origin := Vector3(0.0, 0.4, 0.0)
	var active_schedule := ""
	var active_segment := ""
	var reanchor_count := 0
	var transition_count := 0
	var initial_schedule_binding_count := 0
	var held_count := 0
	var schedule_boundary_steps := [0, 600, 1800, 2400]
	var expected_segment_ids := [
		"reference_warmup",
		"commanded_turn",
		"reference_recovery",
		"reference_continuation",
	]
	var expected_roles := [
		"reference_heading",
		"turn_heading",
		"reference_heading",
		"reference_heading",
	]
	var expected_offsets := [
		0.0,
		float(cell["turn_heading_offset_rad"]),
		0.0,
		0.0,
	]
	var observed_positions := [
		Vector3(0.25, 0.41, 0.25),
		Vector3(1.0, 0.41, 0.1),
		Vector3(2.0, 0.42, 0.2),
		Vector3(3.0, 0.43, 0.3),
	]
	var production_command_segment_ids: Array[String] = []
	var first_command: Dictionary = {}
	for index in range(schedule_boundary_steps.size()):
		var semantic_step := int(schedule_boundary_steps[index])
		var command_result := R23D57WaveGaitScript.resolve_sdk_heading_command_options(
			compiled_schedule,
			semantic_step,
		)
		var command: Dictionary = (
			(command_result.get("heading_command_options", {}) as Dictionary).duplicate(true)
		)
		if (
			not bool(command_result.get("ok", false))
			or String(command.get("segment_id", ""))
			!= String(expected_segment_ids[index])
			or String(command.get("command_role", "")) != String(expected_roles[index])
			or absf(
				float(command.get("heading_offset_rad", NAN))
				- float(expected_offsets[index])
			) > 1.0e-15
		):
			return _r23d57_failure(
				"QSDK_R23D57_GJT_ORIGIN_PRODUCTION_COMMAND_INVALID",
				{
					"semantic_step": semantic_step,
					"command_result": command_result,
					"expected_segment_id": expected_segment_ids[index],
					"expected_command_role": expected_roles[index],
					"expected_heading_offset_rad": expected_offsets[index],
				},
			)
		if index == 0:
			first_command = command.duplicate(true)
		production_command_segment_ids.append(String(command["segment_id"]))
		var observed: Vector3 = observed_positions[index]
		var origin_before: Vector3 = active_origin
		var should_reanchor := semantic_step in R23D57_EXPECTED_REANCHOR_STEPS
		var transition := R23D57AdapterScript.resolve_task_frame_origin_policy_step(
			R23D57_TASK_ORIGIN_POLICY_ID,
			active_origin,
			active_schedule,
			active_segment,
			reanchor_count,
			observed,
			command,
		)
		if (
			not bool(transition.get("ok", false))
			or bool(transition.get("reanchored_this_step", not should_reanchor))
			!= should_reanchor
			or int(transition.get("reanchor_count", -1))
			!= reanchor_count + (1 if should_reanchor else 0)
			or (transition.get("origin_world_m", Vector3.INF) as Vector3)
			!= (observed if should_reanchor else origin_before)
		):
			return _r23d57_failure(
				"QSDK_R23D57_GJT_ORIGIN_TRANSITION_CANARY_INVALID",
				transition,
			)
		active_origin = transition["origin_world_m"]
		active_schedule = String(transition["active_schedule_id"])
		active_segment = String(transition["active_segment_id"])
		reanchor_count = int(transition["reanchor_count"])
		if should_reanchor:
			transition_count += 1
		else:
			initial_schedule_binding_count += 1
		var hold_command_result := (
			R23D57WaveGaitScript.resolve_sdk_heading_command_options(
				compiled_schedule,
				semantic_step + 1,
			)
		)
		var hold_command: Dictionary = (
			(
				hold_command_result.get("heading_command_options", {}) as Dictionary
			).duplicate(true)
		)
		if (
			not bool(hold_command_result.get("ok", false))
			or String(hold_command.get("segment_id", "")) != active_segment
		):
			return _r23d57_failure(
				"QSDK_R23D57_GJT_ORIGIN_PRODUCTION_HOLD_COMMAND_INVALID",
				hold_command_result,
			)
		var held := R23D57AdapterScript.resolve_task_frame_origin_policy_step(
			R23D57_TASK_ORIGIN_POLICY_ID,
			active_origin,
			active_schedule,
			active_segment,
			reanchor_count,
			observed + Vector3(0.1, 0.0, 0.1),
			hold_command,
		)
		if (
			not bool(held.get("ok", false))
			or bool(held.get("reanchored_this_step", true))
			or int(held.get("reanchor_count", -1)) != reanchor_count
			or (held.get("origin_world_m", Vector3.INF) as Vector3) != active_origin
		):
			return _r23d57_failure(
				"QSDK_R23D57_GJT_ORIGIN_HOLD_CANARY_INVALID",
				held,
			)
		held_count += 1
	var missing := R23D57AdapterScript.resolve_task_frame_origin_policy_step(
		R23D57_TASK_ORIGIN_POLICY_ID,
		active_origin,
		active_schedule,
		active_segment,
		reanchor_count,
		Vector3.ZERO,
		{},
	)
	var invalid_command := first_command.duplicate(true)
	invalid_command["schema_version"] = "mutated"
	var invalid := R23D57AdapterScript.resolve_task_frame_origin_policy_step(
		R23D57_TASK_ORIGIN_POLICY_ID,
		active_origin,
		active_schedule,
		active_segment,
		reanchor_count,
		Vector3.ZERO,
		invalid_command,
	)
	if bool(missing.get("ok", true)) or bool(invalid.get("ok", true)):
		return _r23d57_failure(
			"QSDK_R23D57_GJT_ORIGIN_MUTATION_CANARY_INVALID",
			{"missing": missing, "invalid": invalid},
		)
	return {
		"ok": true,
		"failure_code": "",
		"policy_id": R23D57_TASK_ORIGIN_POLICY_ID,
		"transition_count": transition_count,
		"initial_schedule_binding_count": initial_schedule_binding_count,
		"initial_origin_preserved": true,
		"same_segment_hold_count": held_count,
		"rejected_mutation_count": 2,
		"fixed_origin_last_semantic_step": R23D57_FIXED_ORIGIN_LAST_STEP,
		"expected_transition_steps": R23D57_EXPECTED_REANCHOR_STEPS.duplicate(),
		"production_command_segment_ids": production_command_segment_ids,
		"schedule_sha256": String(
			schedule_result.get("sdk_heading_schedule_sha256", "")
		),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}

static func _r23d57_expected_reanchor_steps_exact(value: Variant) -> bool:
	if (
		typeof(value) != TYPE_ARRAY
		or (value as Array).size() != R23D57_EXPECTED_REANCHOR_STEPS.size()
	):
		return false
	for index in range(R23D57_EXPECTED_REANCHOR_STEPS.size()):
		var observed: Variant = (value as Array)[index]
		if (
			(typeof(observed) != TYPE_INT and typeof(observed) != TYPE_FLOAT)
			or not is_finite(float(observed))
			or float(observed) != float(R23D57_EXPECTED_REANCHOR_STEPS[index])
		):
			return false
	return true


static func _r23d57_retain_trace(
	cell: Dictionary,
	rows: Array,
	attempt_root: String,
) -> Dictionary:
	var pending_root := attempt_root.path_join("pending-traces")
	if DirAccess.make_dir_recursive_absolute(pending_root) != OK:
		return _r23d57_failure("QSDK_R23D57_GJT_TRACE_ROOT_CREATE_FAILED")
	var rows_path := pending_root.path_join("%s.rows.json" % String(cell["cell_id"]))
	if FileAccess.file_exists(rows_path):
		return _r23d57_failure("QSDK_R23D57_GJT_TRACE_ROWS_ALREADY_EXIST")
	var file := FileAccess.open(rows_path, FileAccess.WRITE)
	if file == null:
		return _r23d57_failure("QSDK_R23D57_GJT_TRACE_ROWS_CREATE_FAILED")
	file.store_string(JSON.stringify(rows, "", true, true))
	file.store_string("\n")
	file.flush()
	file = null
	var python := OS.get_environment(R23D57_PYTHON_ENV)
	if python.is_empty():
		python = "python"
	var powershell := OS.get_environment(R23D57_POWERSHELL_ENV)
	if powershell.is_empty():
		powershell = "pwsh"
	var output: Array = []
	var exit_code := OS.execute(
		python,
		PackedStringArray(
			[
				ProjectSettings.globalize_path(R23D57_EVALUATOR_PATH),
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
	var marker := "QSDK_R23D57_TRACE_RETAINED "
	var matches: Array[String] = []
	for output_value in output:
		for line_value in String(output_value).split("\n"):
			var line := String(line_value).strip_edges()
			if line.begins_with(marker):
				matches.append(line.trim_prefix(marker))
	if exit_code != 0 or matches.size() != 1:
		return _r23d57_failure(
			"QSDK_R23D57_GJT_TRACE_RETENTION_FAILED:%d" % exit_code,
			{"output": output},
		)
	var parsed: Variant = JSON.parse_string(matches[0])
	if typeof(parsed) != TYPE_DICTIONARY:
		return _r23d57_failure("QSDK_R23D57_GJT_TRACE_RETENTION_RECEIPT_INVALID")
	var receipt: Dictionary = parsed
	if (
		String(receipt.get("schema_version", "")) != R23D57_TRACE_RETENTION_SCHEMA
		or String(receipt.get("stage_id", "")) != String(cell["stage_id"])
		or String(receipt.get("cell_id", "")) != String(cell["cell_id"])
		or not bool(receipt.get("retained_before_terminal_entry", false))
	):
		return _r23d57_failure(
			"QSDK_R23D57_GJT_TRACE_RETENTION_RECEIPT_INVALID",
			receipt,
		)
	var trace_artifact: Dictionary = (
		(receipt.get("trace_artifact", {}) as Dictionary).duplicate(true)
	)
	trace_artifact["trace_transport_id"] = R23D57_TRACE_TRANSPORT_ID
	trace_artifact["godot_runtime_version"] = String(
		Engine.get_version_info().get("string", "")
	)
	trace_artifact["selected_godot_invocation"] = R23D57_TRACE_TRANSPORT_INVOCATION
	trace_artifact["godot_json_sorted_keys"] = true
	trace_artifact["godot_json_full_precision"] = true
	trace_artifact["reported_error_recomputation_consistency_tolerance"] = 1.0e-15
	receipt["trace_artifact"] = trace_artifact
	receipt["ok"] = true
	receipt["failure_code"] = ""
	receipt["trace_transport_id"] = R23D57_TRACE_TRANSPORT_ID
	receipt["godot_runtime_version"] = String(
		Engine.get_version_info().get("string", "")
	)
	receipt["godot_json_full_precision"] = true
	return receipt


static func _r23d57_physical_authorization(
	cell: Dictionary,
	source_commit: String,
) -> Dictionary:
	if FileAccess.file_exists(R23D57_CLOSURE_PATH):
		return _r23d57_failure("QSDK_R23D57_GJT_CLOSED")
	var freeze_path := OS.get_environment(R23D57_FREEZE_PATH_ENV)
	var attempt_path := OS.get_environment(R23D57_ATTEMPT_PATH_ENV)
	var token := OS.get_environment(R23D57_TOKEN_ENV)
	var attempt_root := OS.get_environment(R23D57_ATTEMPT_ROOT_ENV)
	if (
		freeze_path.is_empty()
		or attempt_path.is_empty()
		or attempt_root.is_empty()
		or not FileAccess.file_exists(freeze_path)
		or not FileAccess.file_exists(attempt_path)
		or not DirAccess.dir_exists_absolute(attempt_root)
		or not R23D57BaseWorkerScript._valid_lower_hex(token, 32)
	):
		return _r23d57_failure("QSDK_R23D57_GJT_PHYSICAL_AUTHORIZATION_REQUIRED")
	var freeze := R23D57BaseWorkerScript._read_json(freeze_path)
	var attempt := R23D57BaseWorkerScript._read_json(attempt_path)
	var production_root := (
		ProjectSettings.globalize_path("res://../SporeSpore_Evidence")
		.simplify_path()
		.replace("\\", "/")
		.trim_suffix("/")
	)
	var normalized_attempt_root := attempt_root.simplify_path().replace("\\", "/").trim_suffix("/")
	var durable := (
		normalized_attempt_root == production_root
		or normalized_attempt_root.begins_with(production_root + "/")
	)
	var expected_cells: Array[String] = []
	for arm_id in R23D57_ARM_OFFSETS:
		expected_cells.append(
			"%s__%s__%s" % [R23D57_ENGINE_ID, R23D57_CANDIDATE_ID, arm_id]
		)
	var exact: bool = (
		durable
		and String(freeze.get("schema_version", "")) == R23D57_FREEZE_SCHEMA
		and String(freeze.get("campaign_id", "")) == R23D57_CAMPAIGN_ID
		and String(freeze.get("gate_id", "")) == R23D57_GATE_ID
		and String(freeze.get("status", "")) == "frozen_supervisor_only_physical_authorized"
		and String(freeze.get("preregistration_raw_sha256", ""))
		== R23D57BaseWorkerScript._raw_file_sha256(R23D57_PREREGISTRATION_PATH)
		and String(freeze.get("implementation_contract_raw_sha256", ""))
		== R23D57BaseWorkerScript._raw_file_sha256(R23D57_IMPLEMENTATION_PATH)
		and String(freeze.get("source_commit", "")) == source_commit
		and bool(freeze.get("physical_execution_authorized", false))
		and _r23d57_source_bindings_exact(freeze)
		and String(attempt.get("schema_version", "")) == R23D57_ATTEMPT_SCHEMA
		and String(attempt.get("campaign_id", "")) == R23D57_CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == R23D57_GATE_ID
		and String(attempt.get("freeze_raw_sha256", ""))
		== R23D57BaseWorkerScript._raw_file_sha256(freeze_path)
		and String(attempt.get("source_commit", "")) == source_commit
		and String(attempt.get("authorization_token", "")) == token
		and R23D57BaseWorkerScript._valid_lower_hex(String(attempt.get("attempt_id", "")), 32)
		and bool(attempt.get("physical_execution_authorized", false))
		and bool(attempt.get("single_use_supervisor_authorization", false))
		and bool(attempt.get("matrix_authorization_immutable_before_first_world", false))
		and bool(attempt.get("source_worktree_clean", false))
		and bool(attempt.get("source_matches_live_github_main", false))
		and bool(attempt.get("operation_lock_held", false))
		and bool(attempt.get("campaign_attestation_adoption_valid", false))
		and bool(attempt.get("content_addressed_inputs_retained", false))
		and bool(attempt.get("one_shot_attempt_unconsumed", false))
		and bool(attempt.get("all_cells_run_regardless_of_intermediate_outcome", false))
		and String(attempt.get("attempt_root", "")).simplify_path()
		== normalized_attempt_root
		and attempt.get("ordered_matrix_cell_ids", []) == expected_cells
		and OS.get_environment(R23D57_STAGE_ENV) == String(cell["stage_id"])
		and OS.get_environment(R23D57_CELL_ENV) == String(cell["cell_id"])
		and OS.get_environment(R23D57_ENGINE_ENV) == R23D57_ENGINE_ID
	)
	if not exact:
		return _r23d57_failure("QSDK_R23D57_GJT_PHYSICAL_AUTHORIZATION_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"attempt_root": normalized_attempt_root,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d57_source_bindings_exact(freeze: Dictionary) -> bool:
	var implementation := R23D57BaseWorkerScript._read_json(R23D57_IMPLEMENTATION_PATH)
	var policy: Dictionary = implementation.get("source_binding_policy", {})
	var paths_value: Variant = policy.get("exact_paths", null)
	var bindings_value: Variant = freeze.get("source_bindings", null)
	if typeof(paths_value) != TYPE_ARRAY or typeof(bindings_value) != TYPE_ARRAY:
		return false
	var observed := {}
	for item_value in bindings_value:
		if typeof(item_value) != TYPE_DICTIONARY:
			return false
		var item: Dictionary = item_value
		var path := String(item.get("path", ""))
		if path.is_empty() or observed.has(path):
			return false
		observed[path] = String(item.get("raw_sha256", ""))
	for path_value in paths_value:
		if typeof(path_value) != TYPE_STRING:
			return false
		var path := String(path_value)
		var resource_path := "res://%s" % path
		if (
			path.is_empty()
			or not FileAccess.file_exists(resource_path)
			or String(observed.get(path, ""))
			!= R23D57BaseWorkerScript._raw_file_sha256(resource_path)
		):
			return false
	return true


static func _r23d57_cell(
	stage_id: String,
	onset_id: String,
	arm_id: String,
) -> Dictionary:
	if (
		stage_id != R23D57_STAGE_ID
		or onset_id != R23D57_ONSET_ID
		or not R23D57_ARM_OFFSETS.has(arm_id)
	):
		return _r23d57_failure("QSDK_R23D57_GJT_CELL_IDENTITY_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": stage_id,
		"cell_id": "%s__%s__%s" % [R23D57_ENGINE_ID, R23D57_CANDIDATE_ID, arm_id],
		"engine_id": R23D57_ENGINE_ID,
		"onset_id": onset_id,
		"turn_start_semantic_step": R23D57_TURN_START_STEP,
		"arm_id": arm_id,
		"turn_heading_offset_rad": float(R23D57_ARM_OFFSETS[arm_id]),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d57_rebrand_terminal(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	var success := String(result.get("schema_version", "")) == R23D48_REPORT_SCHEMA
	result["schema_version"] = R23D57_REPORT_SCHEMA if success else R23D57_FAILURE_SCHEMA
	result["campaign_id"] = R23D57_CAMPAIGN_ID
	result["gate_id"] = R23D57_GATE_ID
	result["stage_id"] = R23D57_STAGE_ID
	result["engine_id"] = R23D57_ENGINE_ID
	result["task_frame_origin_policy_id"] = R23D57_TASK_ORIGIN_POLICY_ID
	result["claims"] = R23D57_FALSE_CLAIMS.duplicate(true)
	if result.has("failure_code"):
		result["failure_code"] = String(result["failure_code"]).replace(
			"QSDK_R23D48",
			"QSDK_R23D57",
		)
	return result


static func _r23d57_rebrand_failure(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	result["ok"] = false
	result["failure_code"] = String(
		result.get("failure_code", "QSDK_R23D57_GJT_INHERITED_FAILURE")
	).replace("QSDK_R23D48", "QSDK_R23D57")
	return result


static func _r23d57_failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
