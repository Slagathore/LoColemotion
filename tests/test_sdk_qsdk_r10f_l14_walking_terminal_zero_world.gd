extends SceneTree
# gdlint: disable=max-line-length

## Pure evaluator commissioning: synthetic cases and immutable retained rows.
## No Node, model, world, native sample, controller step, or solver is created.
## Fixture fields describing an old/synthetic world are not activity counters.

const Evaluator := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v2.gd"
)
const LegacyEvaluator := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v1.gd"
)
const PriorGate := preload(
	"res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd"
)
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const REPORT_PATH := "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r10f-development-route-ghost-30427ba7f22cd306/children/01-matched_no_kick_continuation/worker_report.json"
const REPORT_SHA256 := "1038e6df65338b15de7a83b10456633f6ccf9b8778942f3135ae1f2ff52a7aa6"
const MARKER := "QSDK_R10F_L14_WALKING_TERMINAL_ZERO_WORLD "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := evaluate_v1()
	print(MARKER, Transport.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func evaluate_v1() -> Dictionary:
	if load(EXTENSION_PATH) == null or not ClassDB.class_exists("SporeLocomotionSdk"):
		return {"ok": false, "failure_code": "L14_EXTENSION_UNAVAILABLE"}
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var cases := {}
	var base := PriorGate._walking_evaluation_fixture_v1()
	var legacy := LegacyEvaluator.evaluate_segment_v1(sdk, base)
	var ordinary := Evaluator.evaluate_segment_v2(sdk, base)
	cases["grounded_complete_positive"] = (
		_valid_v1(ordinary) and bool(ordinary.get("behavior_passed", false))
	)
	cases["all_27_receipt_names_unchanged"] = (
		Evaluator.RECEIPT_KEYS == LegacyEvaluator.RECEIPT_KEYS
		and int(ordinary.get("walking_receipt_count", -1)) == 27
	)
	cases["fixed_thresholds_unchanged"] = (
		ordinary.get("fixed_thresholds") == legacy.get("fixed_thresholds")
	)
	cases["ordinary_observed_quantities_unchanged"] = _common_quantities_equal_v1(
		sdk, ordinary, legacy
	)

	for dwell in [1, 10]:
		var partial := base.duplicate(true)
		(partial["initial_contact_by_limb"] as Dictionary)["rear_left"] = false
		_airborne_rows_v1(partial, "rear_left", 0, dwell)
		var evaluated := Evaluator.evaluate_segment_v2(sdk, partial)
		cases["initial_partial_flight_%d_recorded_not_counted" % dwell] = (
			_valid_v1(evaluated)
			and int(evaluated["initial_partial_flight_censored_count_by_limb"]["rear_left"]) == 1
			and int(evaluated["contact_cycle_count_by_limb"]["rear_left"]) == 2
			and not bool(evaluated["walking_gate_receipts"]["initial_four_contact_stance"])
			and not bool(evaluated["walking_gate_receipts"]["evidence_four_contact_stance"])
			and not bool(evaluated["behavior_passed"])
		)

	for dwell in [2, 3]:
		var first_row := base.duplicate(true)
		_airborne_rows_v1(first_row, "rear_left", 0, dwell)
		var evaluated := Evaluator.evaluate_segment_v2(sdk, first_row)
		cases["first_row_liftoff_fixed_dwell_%d" % dwell] = (
			_valid_v1(evaluated)
			and (
				int(evaluated["contact_cycle_count_by_limb"]["rear_left"])
				== (3 if dwell == 3 else 2)
			)
			and int(evaluated["initial_partial_flight_censored_count_by_limb"]["rear_left"]) == 0
		)

	var no_cycles := base.duplicate(true)
	for row in no_cycles["rows"]:
		for limb in Evaluator.LIMB_ORDER:
			row["contact_by_limb"][limb] = true
	var none := Evaluator.evaluate_segment_v2(sdk, no_cycles)
	var absent_minima := _valid_v1(none)
	for limb in Evaluator.LIMB_ORDER:
		absent_minima = (
			absent_minima
			and (
				none.get("minimum_cycle_forward_relocation_by_limb_m", {}).get(limb, "missing")
				== null
			)
		)
	cases["no_completed_cycles_is_valid_negative_with_null_measurements"] = (
		absent_minima
		and not bool(
			none.get("walking_gate_receipts", {}).get("every_limb_two_contact_cycles", true)
		)
		and not bool(none.get("behavior_passed", true))
	)
	var initial_open := no_cycles.duplicate(true)
	for limb in Evaluator.LIMB_ORDER:
		initial_open["initial_contact_by_limb"][limb] = false
		_airborne_rows_v1(initial_open, limb, 0, 720)
	var still_initial := Evaluator.evaluate_segment_v2(sdk, initial_open)
	cases["initial_flight_open_at_end_not_a_cycle"] = (
		_valid_v1(still_initial)
		and bool(still_initial["initial_partial_flight_open_at_end_by_limb"]["rear_left"])
		and not bool(still_initial["observed_flight_open_at_end_by_limb"]["rear_left"])
		and int(still_initial["contact_cycle_count_by_limb"]["rear_left"]) == 0
	)
	var terminal_open := base.duplicate(true)
	_airborne_rows_v1(terminal_open, "rear_left", 716, 4)
	var open_result := Evaluator.evaluate_segment_v2(sdk, terminal_open)
	cases["observed_flight_open_at_end_not_a_completed_cycle"] = (
		_valid_v1(open_result)
		and bool(open_result["observed_flight_open_at_end_by_limb"]["rear_left"])
		and int(open_result["contact_cycle_count_by_limb"]["rear_left"]) == 2
		and not bool(open_result["walking_gate_receipts"]["terminal_four_contact_recovery"])
	)

	var invalid := {}
	var changed := base.duplicate(true)
	changed["maximum_anchor_error_m"] = 1.0
	invalid["threshold_override"] = changed
	changed = base.duplicate(true)
	(changed["rows"] as Array).pop_back()
	invalid["incomplete_rows"] = changed
	changed = base.duplicate(true)
	changed.erase("initial_contact_by_limb")
	invalid["missing_initial_contacts"] = changed
	changed = base.duplicate(true)
	changed["initial_contact_by_limb"]["rear_left"] = "false"
	invalid["non_boolean_initial_contact"] = changed
	changed = base.duplicate(true)
	changed["rows"][0]["contact_by_limb"]["rear_left"] = 1
	invalid["non_boolean_row_contact"] = changed
	changed = base.duplicate(true)
	changed["rows"][49]["foot_position_world_m_by_limb"]["rear_left"] = []
	invalid["missing_observed_liftoff_vector"] = changed
	changed = base.duplicate(true)
	changed["rows"][52]["foot_position_world_m_by_limb"]["rear_left"] = [NAN, 0.0, 0.0]
	invalid["nonfinite_touchdown_vector"] = changed
	changed = base.duplicate(true)
	changed["rows"][0]["walking_session_local_step"] = 1.5
	invalid["fractional_local_step"] = changed
	changed = base.duplicate(true)
	changed["rows"][0]["walking_session_id"] = "wrong-session"
	invalid["wrong_session"] = changed
	changed = base.duplicate(true)
	changed["rows"][0]["observation_sha256"] = "missing"
	invalid["missing_observation_digest"] = changed
	changed = base.duplicate(true)
	changed["rows"][0]["maximum_anchor_error_m"] = []
	invalid["malformed_scalar"] = changed
	changed = base.duplicate(true)
	changed["completion_receipt"]["adapter_summary"] = []
	invalid["malformed_completion"] = changed
	changed = base.duplicate(true)
	changed["world_build_count"] = []
	invalid["malformed_counter"] = changed
	changed = base.duplicate(true)
	changed["expected_step_count"] = 720.0
	invalid["wrong_host_counter_kind"] = changed
	changed = base.duplicate(true)
	changed["expected_step_count"] = []
	invalid["malformed_expected_count_before_cast"] = changed
	changed = base.duplicate(true)
	changed["completion_receipt"]["adapter_summary"]["ok"] = 1
	invalid["non_boolean_summary_ok"] = changed
	changed = base.duplicate(true)
	changed["completion_receipt"]["adapter_shutdown_receipt"]["explicit_shutdown_completed"] = "false"
	invalid["non_boolean_shutdown"] = changed
	changed = base.duplicate(true)
	changed["completion_receipt"]["adapter_summary"]["mismatch_count"] = []
	invalid["malformed_summary_counter"] = changed
	changed = base.duplicate(true)
	changed["source_measurement"] = 1
	invalid["non_boolean_source_measurement"] = changed
	changed = base.duplicate(true)
	changed["rows"][0]["torso_contact"] = 0
	invalid["non_boolean_torso_contact"] = changed
	for name in invalid:
		var refused := Evaluator.evaluate_segment_v2(sdk, invalid[name])
		cases["refused_" + name] = (
			refused.get("ok") == false
			and String(refused.get("failure_code", "")).begins_with("QSDK_R10F_WALKING_")
		)

	var retained := _retained_replay_v1(sdk)
	cases["two_retained_segments_replayed_without_reclassification"] = bool(
		retained.get("ok", false)
	)
	sdk = null
	var failed := []
	for name in cases:
		if not bool(cases[name]):
			failed.append(name)
	return {
		"schema_version": "sporespore_qsdk_r10f_l14_walking_terminal_zero_world_v1",
		"gate_id": "QSDK-R10F",
		"repair_id": "QSDK-R10F-L14",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_evaluator_boundary_controls",
			"question_class": "development"
		},
		"ok": failed.is_empty(),
		"control_count": cases.size(),
		"mutation_rejection_count": invalid.size(),
		"controls": cases,
		"failed_controls": failed,
		"retained_replay": retained,
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


static func _airborne_rows_v1(
	evidence: Dictionary, limb: String, first_index: int, count: int
) -> void:
	for index in range(first_index, first_index + count):
		evidence["rows"][index]["contact_by_limb"][limb] = false


static func _valid_v1(value: Dictionary) -> bool:
	return (
		value.get("ok") == true
		and value.get("evidence_valid") == true
		and value.get("outcome_complete") == true
		and value.get("schema_version") == Evaluator.EVALUATION_SCHEMA
	)


static func _common_quantities_equal_v1(sdk: Object, left: Dictionary, right: Dictionary) -> bool:
	var omitted := [
		"schema_version", "evaluator_id", "payload_sha256", "contact_cycle_count_by_limb"
	]
	var selected_left := {}
	var selected_right := {}
	for key in right:
		if key not in omitted:
			if not left.has(key):
				return false
			selected_left[key] = left[key]
			selected_right[key] = right[key]
	# This is the existing canonical-number identity, not a fitted tolerance.
	var left_digest := Runtime.canonicalize(sdk, selected_left)
	var right_digest := Runtime.canonicalize(sdk, selected_right)
	return (
		Evaluator._digest_valid_v1(String(left_digest.get("sha256", "")))
		and Evaluator._digest_valid_v1(String(right_digest.get("sha256", "")))
		and left_digest.get("sha256") == right_digest.get("sha256")
	)


static func _retained_replay_v1(sdk: Object) -> Dictionary:
	if FileAccess.get_sha256(REPORT_PATH) != REPORT_SHA256:
		return {"ok": false, "failure_code": "L14_RETAINED_REPORT_DIGEST"}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH))
	if not (parsed is Dictionary):
		return {"ok": false, "failure_code": "L14_RETAINED_REPORT_SHAPE"}
	var arm: Dictionary = parsed["arm_result"]
	var all_rows: Array = arm["trace"]["rows"]
	var summaries := []
	var passed := true
	for session in arm["walking_sessions"]:
		var evidence := PriorGate._walking_evaluation_fixture_v1()
		var start: Dictionary = session["start_receipt"]
		var start_step := int(start["global_start_step"])
		var rows := []
		for row in all_rows:
			if String(row["walking_session_id"]) == String(session["session_id"]):
				rows.append(row.duplicate(true))
		evidence["arm_id"] = String(arm["arm_id"])
		evidence["segment_id"] = String(session["evaluation_segment_id"])
		evidence["session_id"] = String(session["session_id"])
		evidence["expected_step_count"] = rows.size()
		evidence["start_receipt"] = start.duplicate(true)
		evidence["completion_receipt"] = session["completion_receipt"].duplicate(true)
		evidence["initial_contact_by_limb"] = all_rows[start_step - 1]["contact_by_limb"].duplicate(
			true
		)
		evidence["rows"] = rows
		var evaluated := Evaluator.evaluate_segment_v2(sdk, evidence)
		var prefix := String(session["evaluation_segment_id"]) == "walking_prefix"
		var expected_counts := (
			{"front_left": 3, "front_right": 5, "rear_left": 4, "rear_right": 5}
			if prefix
			else {"front_left": 5, "front_right": 11, "rear_left": 13, "rear_right": 13}
		)
		var case_passed: bool = (
			_valid_v1(evaluated)
			and evaluated.get("contact_cycle_count_by_limb") == expected_counts
			and rows.size() == (720 if prefix else 1920)
			and _common_quantities_equal_v1(sdk, evaluated, session["evaluation"])
		)
		passed = passed and case_passed
		(
			summaries
			. append(
				{
					"segment_id": session["evaluation_segment_id"],
					"ok": case_passed,
					"trace_row_count": rows.size(),
					"contact_cycle_count_by_limb": evaluated.get("contact_cycle_count_by_limb"),
					"initial_partial_flight_censored_count_by_limb":
					evaluated.get("initial_partial_flight_censored_count_by_limb"),
					"non_cycle_quantities_match_existing_canonical_identity":
					_common_quantities_equal_v1(sdk, evaluated, session["evaluation"]),
					"failure_code": evaluated.get("failure_code", ""),
				}
			)
		)
	return {
		"ok": passed and summaries.size() == 2,
		"report_raw_sha256": "sha256:" + REPORT_SHA256,
		"segments": summaries,
		"retained_result_reclassified": false,
		"retained_bytes_modified": false,
		"comparison_is_development_only": true
	}
