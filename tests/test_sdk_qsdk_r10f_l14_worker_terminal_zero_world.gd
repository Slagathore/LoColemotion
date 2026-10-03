extends SceneTree
# gdlint: disable=max-line-length

## Calls the worker's real post-shutdown source projection and terminalization.
## The worker is never instantiated. No facade, model, world or native read runs.
const Worker := preload("res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd")
const PriorGate := preload(
	"res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd"
)
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const RetainedGate := preload("res://tests/test_sdk_qsdk_r10f_l14_walking_terminal_zero_world.gd")
const MARKER := "QSDK_R10F_L14_WORKER_TERMINAL_ZERO_WORLD "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := evaluate_v1("--emit-fixtures" in OS.get_cmdline_user_args())
	print(MARKER, Transport.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func arm_fixture_v1(evidence: Dictionary) -> Dictionary:
	var arm := {
		"arm_id": evidence["arm_id"],
		"active_walking_session":
		{
			"evaluation_segment_id": evidence["segment_id"],
			"facade_segment_id": "walking_prefix",
			"session_id": evidence["session_id"],
			"start_receipt": evidence["start_receipt"].duplicate(true),
			"walking_actuation_handoff_receipt": {"fixture_source": "no_native_world"},
			"initial_contact_by_limb": evidence["initial_contact_by_limb"].duplicate(true),
			"trace_start_index": 0,
			"scheduled_step_count": evidence["expected_step_count"],
			"step_receipt_sha256s": [],
		},
		"trace_rows": evidence["rows"].duplicate(true),
		"walking_sessions": [],
		"walking_session_completion_attempted": true,
		"last_walking_step_failure": {},
		"last_walking_evaluation_failure": {},
		"solver_reset_count": evidence["world_reset_count"],
	}
	for key in [
		"body_population_rebuild_count",
		"direct_torso_force_command_count",
		"direct_torso_impulse_command_count",
		"direct_torso_velocity_command_count",
		"direct_torso_transform_command_count"
	]:
		arm[key] = evidence[key]
	return arm


static func evaluate_v1(emit_fixtures: bool = false) -> Dictionary:
	if load(Worker.EXTENSION_PATH) == null or not ClassDB.class_exists(Worker.CLASS_NAME):
		return {"ok": false, "failure_code": "L14_EXTENSION_UNAVAILABLE"}
	var sdk: Object = ClassDB.instantiate(Worker.CLASS_NAME)
	var base := PriorGate._walking_evaluation_fixture_v1()
	var arm_id: String = base["arm_id"]
	var controls := {}
	var positive_arm := arm_fixture_v1(base)
	var shutdown_arm := positive_arm.duplicate(true)
	shutdown_arm["walking_session_completion_attempted"] = false
	controls["only_unattempted_open_session_needs_shutdown"] = (
		Worker.walking_session_needs_shutdown_v2(shutdown_arm)
	)
	controls["attempted_shutdown_never_repeated"] = not Worker.walking_session_needs_shutdown_v2(
		positive_arm
	)
	shutdown_arm["walking_session_completion_attempted"] = 0
	controls["malformed_shutdown_flag_fails_closed"] = not Worker.walking_session_needs_shutdown_v2(
		shutdown_arm
	)
	var projection := Worker.walking_terminal_input_v2(
		arm_id, positive_arm, base["completion_receipt"]
	)
	controls["production_projection_preserves_complete_input"] = _same_v1(
		sdk, projection["evidence"], base
	)
	var positive := Worker.close_walking_session_sources_v2(
		sdk, arm_id, positive_arm, base["completion_receipt"]
	)
	controls["complete_positive_retains_v2_session"] = (
		positive.get("ok") == true
		and positive_arm["walking_sessions"].size() == 1
		and (
			positive_arm["walking_sessions"][0]["evaluation"]["schema_version"]
			== Worker.WalkingEvaluator.EVALUATION_SCHEMA
		)
		and positive_arm["walking_sessions"][0]["evaluation"]["behavior_passed"] == true
		and positive_arm["active_walking_session"].is_empty()
		and positive_arm["last_walking_evaluation_failure"].is_empty()
	)
	var negative_arm := arm_fixture_v1(base)
	for row in negative_arm["trace_rows"]:
		for limb in Worker.WalkingEvaluator.LIMB_ORDER:
			row["contact_by_limb"][limb] = true
	var negative := Worker.close_walking_session_sources_v2(
		sdk, arm_id, negative_arm, base["completion_receipt"]
	)
	controls["valid_behavior_negative_is_complete_not_infrastructure_failure"] = (
		negative.get("ok") == true
		and negative_arm["walking_sessions"].size() == 1
		and negative_arm["walking_sessions"][0]["evaluation"]["behavior_passed"] == false
		and negative_arm["walking_sessions"][0]["evaluation"]["outcome_complete"] == true
		and negative_arm["last_walking_evaluation_failure"].is_empty()
	)
	var cases := {}
	var changed := arm_fixture_v1(base)
	changed["trace_rows"][10]["foot_position_world_m_by_limb"]["rear_left"] = []
	cases["malformed_observed_vector"] = {
		"arm": changed,
		"completion": base["completion_receipt"],
		"code": "QSDK_R10F_WALKING_EVALUATION_INVALID"
	}
	changed = arm_fixture_v1(base)
	changed["trace_rows"][10] = "not_a_row"
	cases["non_dictionary_row"] = {
		"arm": changed,
		"completion": base["completion_receipt"],
		"code": "QSDK_R10F_WALKING_EVALUATION_INVALID"
	}
	changed = arm_fixture_v1(base)
	changed["trace_rows"].pop_back()
	cases["missing_row_keeps_all_observed_rows"] = {
		"arm": changed,
		"completion": base["completion_receipt"],
		"code": "QSDK_R10F_WALKING_TRACE_SLICE_INVALID"
	}
	changed = arm_fixture_v1(base)
	changed["active_walking_session"]["trace_start_index"] = -1
	cases["negative_slice_start"] = {
		"arm": changed,
		"completion": base["completion_receipt"],
		"code": "QSDK_R10F_WALKING_TRACE_SLICE_INVALID"
	}
	changed = arm_fixture_v1(base)
	changed["active_walking_session"]["scheduled_step_count"] = 720.0
	cases["host_count_float_not_coerced"] = {
		"arm": changed,
		"completion": base["completion_receipt"],
		"code": "QSDK_R10F_WALKING_TRACE_SLICE_INVALID"
	}
	for key in ["adapter_summary", "adapter_shutdown_receipt"]:
		var completion: Dictionary = base["completion_receipt"].duplicate(true)
		completion.erase(key)
		cases["missing_%s" % key] = {
			"arm": arm_fixture_v1(base),
			"completion": completion,
			"code": "QSDK_R10F_WALKING_COMPLETION_RECEIPT_INVALID"
		}
	var failures := []
	var fixture_exports := []
	for name in cases:
		var case: Dictionary = cases[name]
		var arm: Dictionary = case["arm"]
		var before := arm.duplicate(true)
		var result := Worker.close_walking_session_sources_v2(sdk, arm_id, arm, case["completion"])
		var partial := Worker.partial_arm_failure_retention_projection_v1(arm, arm_id)
		if emit_fixtures:
			fixture_exports.append({"name": name, "partial_arm": partial})
		var retained: Dictionary = partial["last_walking_evaluation_failure"]
		var body := retained.duplicate(true)
		body.erase("payload_sha256")
		controls[name] = (
			result.get("ok") == false
			and result.get("failure_code") == case["code"]
			and arm["walking_sessions"].is_empty()
			and retained.get("measurement_complete") == false
			and partial.get("walking_session_completion_attempted") == true
			and _same_v1(sdk, retained["all_observed_trace_rows"], before["trace_rows"])
			and _same_v1(sdk, retained["active_walking_session"], before["active_walking_session"])
			and _same_v1(sdk, retained["completion_receipt"], case["completion"])
			and _same_v1(
				sdk,
				retained["walking_evaluation_input"],
				Worker.walking_terminal_input_v2(arm_id, before, case["completion"])["evidence"]
			)
			and retained.get("payload_sha256") == Runtime.canonicalize(sdk, body).get("sha256")
			and retained.get("physical_acceptance_authority") == false
			and retained.get("release_authority") == false
			and (
				case["code"] != "QSDK_R10F_WALKING_EVALUATION_INVALID"
				or not String(retained.get("evaluator_failure_code", "")).is_empty()
			)
		)
	var interaction_fixtures := interaction_fixtures_v1(sdk)
	controls["both_actual_interaction_producers_accept_complete_start_shape"] = (
		interaction_fixtures.get("ok") == true
	)
	for name in controls:
		if controls[name] != true:
			failures.append(name)
	sdk = null
	var receipt := {
		"schema_version": "sporespore_qsdk_r10f_l14_worker_terminal_zero_world_v1",
		"gate_id": "QSDK-R10F",
		"repair_id": "QSDK-R10F-L14",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_production_terminal_source_controls",
			"question_class": "development"
		},
		"ok": failures.is_empty(),
		"controls": controls,
		"failed_controls": failures,
		"control_count": controls.size(),
		"invalid_terminal_source_case_count": cases.size(),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if emit_fixtures:
		receipt["production_failure_fixtures"] = fixture_exports
		receipt["production_complete_sessions"] = [
			positive_arm["walking_sessions"][0], negative_arm["walking_sessions"][0]
		]
		receipt["production_interaction_fixtures"] = interaction_fixtures
	return receipt


static func interaction_fixtures_v1(sdk: Object) -> Dictionary:
	if FileAccess.get_sha256(RetainedGate.REPORT_PATH) != RetainedGate.REPORT_SHA256:
		return {"ok": false, "failure_code": "L14_RETAINED_START_SOURCE_IDENTITY"}
	var report: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(RetainedGate.REPORT_PATH)
	)
	var historical: Dictionary = report["arm_result"]["walking_sessions"][0]
	var results := []
	for role in Worker.ARM_ORDER:
		var active: bool = role == Worker.EnergyInitializer.ACTIVE_ARM_ID
		# Explicit synthetic identities/clock replace only the fixture's labels.
		# No replacement is written to, or claimed for, the historical record.
		var session := historical.duplicate(true)
		var session_id := "synthetic-%s-walking_prefix" % role
		var model_id := "synthetic-model-%s" % role
		var child_id := "2".repeat(32) if active else "1".repeat(32)
		session["session_id"] = session_id
		session["start_receipt"]["session_id"] = session_id
		session["start_receipt"]["model_instance_id"] = model_id
		session["start_receipt"]["global_start_step"] = 2
		# Godot's generic JSON parser represents every parsed number as float.
		# These synthetic counters are emitted as int by the actual GDS producer;
		# declare them as such instead of weakening the independent host check.
		for counter in [
			"body_transform_write_count",
			"body_velocity_write_count",
			"solver_reset_count",
			"model_construction_count",
			"world_attempt_count",
			"world_build_count",
			"solver_step_count"
		]:
			session["start_receipt"][counter] = 0
		session["start_receipt"]["task_frame_forward_axis_world_host_real"] = [1.0, 0.0, 0.0]
		session["start_receipt"]["task_frame_lateral_axis_world_host_real"] = [0.0, 0.0, 1.0]
		var built := (
			Worker
			. ProcessIsolatedChildContract
			. build_interaction_source_v1(
				sdk,
				"0123456789abcdef0123456789abcdef",
				child_id,
				role,
				model_id,
				4,
				session["start_receipt"],
				(
					[0.0, 0.0, Worker.EnergyInitializer.KICK_IMPULSE_MAGNITUDE_N_S]
					if active
					else [0.0, 0.0, 0.0]
				),
				[0.10, 0.0, -0.01],
				[0.10, 0.0, 0.01] if active else [0.10, 0.0, -0.009],
				1 if active else 0,
			)
		)
		if built.get("ok") != true:
			return {
				"ok": false, "failure_code": "L14_PRODUCTION_INTERACTION_FIXTURE", "detail": built
			}
		results.append({"role": role, "prefix_session": session, "interaction_build": built})
	return {
		"ok": true,
		"fixtures": results,
		"fixture_only": true,
		"retained_result_modified_or_promoted": false
	}


static func _same_v1(sdk: Object, left: Variant, right: Variant) -> bool:
	var left_digest: String = Runtime.canonicalize(sdk, left).get("sha256", "")
	return (
		left_digest.begins_with("sha256:")
		and left_digest == Runtime.canonicalize(sdk, right).get("sha256")
	)
