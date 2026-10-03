extends SceneTree

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const GateEvaluatorScript := preload("res://scripts/lab/gate_evaluator.gd")
const RecomputerScript := preload(
	"res://scripts/lab/l0_metric_recomputer.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab independent L0 unary metric recomputation ===")
	print("- every currently emitted L0.0/L0.1/L0.2 unary metric")
	var stationary := _case("L0_0_STATIONARY_GRAVITY_OFF")
	var stationary_result := _verify_case(stationary)
	if not bool(stationary_result.get("ok", false)):
		print("  L0.0 diagnostic errors: ", stationary_result.get("errors", []))
	_check(
		bool(stationary_result.get("ok", false))
		and int(stationary_result.get("metric_checks", []).size()) == 5
		and is_equal_approx(
			float(stationary_result.get(
				"value_absolute_tolerance", 0.0)),
			1.0e-7)
		and bool(stationary_result.get(
			"external_work_proof", {}).get("available", false))
		and is_zero_approx(float(stationary_result[
			"recomputed_metrics"]["external_work_j"]))
		and bool(stationary_result.get(
			"recomputed_physical_gate", {}).get("pass", false)),
		"L0.0 rebuilds five unary metrics and proves zero work from raw absence")
	_assert_metric(
		stationary_result, "max_position_error_m", 0.125,
		"L0.0 position residual is independently rebuilt")
	_assert_metric(
		stationary_result, "max_velocity_error_m_s", 0.25,
		"L0.0 velocity residual is independently rebuilt")
	_assert_metric(
		stationary_result, "max_kinetic_energy_j", 0.0625,
		"L0.0 kinetic-energy maximum is independently rebuilt")
	var stationary_round_trip: Variant = JSON.parse_string(
		CanonicalJsonScript.stringify(stationary))
	var round_trip_result := (
		_verify_case(stationary_round_trip as Dictionary)
		if stationary_round_trip is Dictionary
		else {"ok": false})
	if not bool(round_trip_result.get("ok", false)):
		printerr(
			"  JSON round-trip diagnostic errors: ",
			round_trip_result.get("errors", []))
	_check(
		bool(round_trip_result.get("ok", false)),
		"unary verifier accepts exact integer identities after sealed JSON round-trip")

	var free_fall := _case("L0_1_FREE_FALL")
	var free_fall_result := _verify_case(free_fall)
	if not bool(free_fall_result.get("ok", false)):
		print("  L0.1 diagnostic errors: ", free_fall_result.get("errors", []))
	_check(
		bool(free_fall_result.get("ok", false))
		and int(free_fall_result.get("metric_checks", []).size()) == 5
		and bool(free_fall_result.get(
			"recomputed_physical_gate", {}).get("pass", false)),
		"L0.1 rebuilds all five emitted unary metrics and its physical gate")
	_assert_metric(
		free_fall_result, "max_position_error_m", 0.25,
		"L0.1 position residual is independently rebuilt")
	_assert_metric(
		free_fall_result, "max_velocity_error_m_s", 0.25,
		"L0.1 velocity residual is independently rebuilt")
	_assert_metric(
		free_fall_result, "max_acceleration_error_m_s2", 0.25,
		"L0.1 acceleration residual is independently rebuilt")
	_assert_metric(
		free_fall_result, "max_momentum_error_kg_m_s", 0.5,
		"L0.1 momentum residual uses sealed mass and velocity")

	var ballistic := _case("L0_2_BALLISTIC_ZERO_G")
	var ballistic_result := _verify_case(ballistic)
	if not bool(ballistic_result.get("ok", false)):
		print("  L0.2 diagnostic errors: ", ballistic_result.get("errors", []))
	_check(
		bool(ballistic_result.get("ok", false))
		and int(ballistic_result.get("metric_checks", []).size()) == 5
		and bool(ballistic_result.get(
			"recomputed_physical_gate", {}).get("pass", false)),
		"L0.2 rebuilds all five emitted unary metrics and its physical gate")
	_assert_metric(
		ballistic_result, "max_position_error_m", 0.5,
		"L0.2 ballistic position residual is independently rebuilt")
	_assert_metric(
		ballistic_result, "max_velocity_error_m_s", 0.25,
		"L0.2 ballistic velocity residual is independently rebuilt")
	_assert_metric(
		ballistic_result, "max_acceleration_error_m_s2", 0.25,
		"L0.2 acceleration residual is independently rebuilt")
	_assert_metric(
		ballistic_result, "max_momentum_error_kg_m_s", 0.5,
		"L0.2 momentum residual uses sealed 2 kg mass")

	print("- forged metric values and unary provenance")
	var forged_value := _clone_case(free_fall)
	_metric(forged_value["summary"], "max_position_error_m")["value"] = 0.0
	_check(
		_has_error(_verify_case(forged_value), "METRIC_VALUE_MISMATCH"),
		"forged stored metric value is rejected")
	var forged_range := _clone_case(free_fall)
	_metric(forged_range["summary"], "max_position_error_m")[
		"source_frame_range"] = [1, 2]
	_check(
		_has_error(
			_verify_case(forged_range), "METRIC_SOURCE_RANGE_MISMATCH"),
		"forged source frame range is rejected")
	var forged_stream := _clone_case(free_fall)
	_metric(forged_stream["summary"], "max_position_error_m")[
		"source_stream"] = "mechanics.jsonl"
	_check(
		_has_error(
			_verify_case(forged_stream), "METRIC_CONTRACT_MISMATCH"),
		"forged source stream is rejected")
	var forged_field := _clone_case(free_fall)
	_metric(forged_field["summary"], "max_position_error_m")[
		"source_field"] = "/bodies/body_0/linear_velocity"
	_check(
		_has_error(
			_verify_case(forged_field), "METRIC_CONTRACT_MISMATCH"),
		"forged source field is rejected")
	var forged_aggregation := _clone_case(free_fall)
	_metric(forged_aggregation["summary"], "max_position_error_m")[
		"aggregation_id"] = "sum"
	_check(
		_has_error(
			_verify_case(forged_aggregation), "METRIC_CONTRACT_MISMATCH"),
		"forged aggregation is rejected")

	print("- forged frame state and command sealing")
	var forged_frame := _clone_case(ballistic)
	forged_frame["streams"]["frames.jsonl"][1]["finite"] = false
	_check(
		_has_error(_verify_case(forged_frame), "FRAME_MARKED_NONFINITE"),
		"frame marked non-finite cannot support a recomputed metric")
	var active_command := _clone_case(stationary)
	var active_payload: Dictionary = active_command[
		"streams"]["commands.jsonl"][0]["payload"]
	active_payload["mode"] = "ACTIVE"
	active_command["streams"]["commands.jsonl"][0][
		"command_payload_sha256"] = CanonicalJsonScript.sha256(active_payload)
	var active_result := _verify_case(active_command)
	_check(
		_has_error(active_result, "EXTERNAL_WORK_COMMANDS_NOT_NONE")
		and not bool(active_result.get(
			"external_work_proof", {}).get("available", true)),
		"validly rehashed non-NONE command defeats the zero-work proof")
	var forged_command_hash := _clone_case(stationary)
	forged_command_hash["streams"]["commands.jsonl"][0][
		"command_payload_sha256"] = (
			"sha256:"
			+ "0".repeat(64))
	_check(
		_has_error(
			_verify_case(forged_command_hash),
			"COMMAND_PAYLOAD_HASH_MISMATCH"),
		"command payload hash forgery is rejected")

	print("- every zero-external-work precondition is independently necessary")
	var with_application := _clone_case(stationary)
	with_application["streams"]["applications.jsonl"].append({
		"application_sequence": 0,
	})
	_check(
		_has_error(
			_verify_case(with_application),
			"EXTERNAL_WORK_APPLICATIONS_PRESENT"),
		"any application receipt defeats the zero-work proof")
	var with_intervention := _clone_case(stationary)
	with_intervention["streams"]["interventions.jsonl"].append({
		"intervention_payload_sha256": "present",
	})
	_check(
		_has_error(
			_verify_case(with_intervention),
			"EXTERNAL_WORK_INTERVENTIONS_PRESENT"),
		"any intervention record defeats the zero-work proof")
	var with_contact := _clone_case(stationary)
	with_contact["streams"]["frames.jsonl"][1]["contacts"].append({
		"contact_key": "body_0:2:0",
	})
	with_contact["streams"]["frames.jsonl"][1][
		"availability"]["contact_count"] = 1
	_check(
		_has_error(
			_verify_case(with_contact),
			"EXTERNAL_WORK_CONTACTS_PRESENT"),
		"any contact record defeats the zero-work proof")
	var with_gravity := _clone_case(stationary)
	for frame in with_gravity["streams"]["frames.jsonl"]:
		frame["bodies"]["body_0"]["total_gravity_world"] = [
			0.0, -0.125, 0.0,
		]
	_check(
		_has_error(
			_verify_case(with_gravity),
			"EXTERNAL_WORK_GRAVITY_PRESENT"),
		"nonzero measured gravity defeats the zero-work proof")

	print("- gate and promotion conclusions must follow recomputed values")
	var tolerated_gate_roundtrip := _clone_case(ballistic)
	tolerated_gate_roundtrip["summary"]["gate_results"]["physical"][
		"checks"][0]["observed"] = (
			float(tolerated_gate_roundtrip["summary"]["gate_results"][
				"physical"]["checks"][0]["observed"]) + 5.0e-8)
	_check(
		bool(_verify_case(tolerated_gate_roundtrip).get("ok", false)),
		"gate numeric round-trip drift inside declared 1e-7 tolerance is accepted")
	var forged_gate := _clone_case(ballistic)
	forged_gate["summary"]["gate_results"]["physical"]["pass"] = false
	_check(
		_has_error(
			_verify_case(forged_gate),
			"PHYSICAL_GATE_RESULT_MISMATCH"),
		"forged stored physical-gate result is rejected")
	var forged_promotion := _clone_case(ballistic)
	forged_promotion["summary"]["promotion"] = "pass"
	_check(
		_has_error(
			_verify_case(forged_promotion),
			"SUMMARY_PROMOTION_MISMATCH"),
		"forged promotion cannot override the recomputed/source gates")
	var missing_gate_parameter := _clone_case(ballistic)
	missing_gate_parameter["manifest"]["expanded_parameters"][
		"gate_parameters"].erase("max_velocity_error_m_s")
	_check(
		_has_error(
			_verify_case(missing_gate_parameter),
			"GATE_PARAMETER_MISSING"),
		"missing manifest gate tolerance is rejected instead of defaulted")

	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _case(experiment_id: String) -> Dictionary:
	var run_id := "recompute-%s" % experiment_id.to_lower()
	var frames := _frames(experiment_id, run_id)
	var expected := _expected_metrics(experiment_id)
	var gate_parameters := _gate_parameters(experiment_id)
	var gate_inputs := _gate_inputs(experiment_id, expected)
	var physical_gate: Dictionary = GateEvaluatorScript.evaluate_l0(
		experiment_id, gate_inputs, gate_parameters)
	var streams := {
		"frames.jsonl": frames,
	}
	if experiment_id == "L0_0_STATIONARY_GRAVITY_OFF":
		streams["commands.jsonl"] = _none_commands(
			run_id, frames.size() - 1)
		streams["applications.jsonl"] = []
		streams["interventions.jsonl"] = []
		streams["runtime_notes.jsonl"] = _runtime_notes(run_id)
	var summary := {
		"schema": "sporespore.lab.summary.v1",
		"run_id": run_id,
		"termination": "completed",
		"evidence_validity": "valid",
		"hypothesis_result": "supported",
		"promotion": "not_evaluated",
		"frame_count": frames.size(),
		"runtime_note_count": (
			2 if experiment_id == "L0_0_STATIONARY_GRAVITY_OFF" else 0),
		"first_frame_id": 0,
		"last_frame_id": frames.size() - 1,
		"metrics": _summary_metrics(
			experiment_id, expected, frames.size()),
		"gate_results": {
			"configuration": {
				"gate_id": "G0_CONFIGURATION_INTEGRITY",
				"pass": true,
			},
			"physical": physical_gate,
			"source_state": {
				"gate_id": "G14_SOURCE_STATE",
				"pass": false,
			},
		},
	}
	var manifest := {
		"schema": "sporespore.lab.manifest.v1",
		"run_id": run_id,
		"status": "COMPLETE",
		"experiment_id": experiment_id,
		"physics_ticks_per_second": 1,
		"expanded_parameters": {
			"body_parameters": {
				"gravity_scale": (
					1.0
						if experiment_id == "L0_1_FREE_FALL"
						else 0.0),
			},
			"gate_parameters": gate_parameters,
		},
	}
	return {
		"manifest": manifest,
		"summary": summary,
		"streams": streams,
	}


func _frames(experiment_id: String, run_id: String) -> Array:
	match experiment_id:
		"L0_0_STATIONARY_GRAVITY_OFF":
			return [
				_frame(run_id, 0, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO),
				_frame(
					run_id, 1, Vector3(0.125, 0.0, 0.0),
					Vector3(0.25, 0.0, 0.0), Vector3.ZERO),
				_frame(
					run_id, 2, Vector3(-0.0625, 0.0, 0.0),
					Vector3(-0.125, 0.0, 0.0), Vector3.ZERO),
			]
		"L0_1_FREE_FALL":
			var gravity := Vector3(0.0, -1.0, 0.0)
			return [
				_frame(run_id, 0, Vector3.ZERO, Vector3.ZERO, gravity),
				_frame(
					run_id, 1, Vector3(0.0, -0.5, 0.0),
					Vector3(0.0, -1.0, 0.0), gravity),
				_frame(
					run_id, 2, Vector3(0.25, -2.0, 0.0),
					Vector3(0.25, -2.0, 0.0), gravity),
			]
		"L0_2_BALLISTIC_ZERO_G":
			return [
				_frame(
					run_id, 0, Vector3.ZERO,
					Vector3(1.0, 0.0, 0.0), Vector3.ZERO),
				_frame(
					run_id, 1, Vector3(1.0, 0.0, 0.0),
					Vector3(1.0, 0.0, 0.0), Vector3.ZERO),
				_frame(
					run_id, 2, Vector3(2.0, 0.5, 0.0),
					Vector3(1.0, 0.25, 0.0), Vector3.ZERO),
			]
	return []


func _frame(
		run_id: String,
		frame_id: int,
		position: Vector3,
		velocity: Vector3,
		gravity: Vector3) -> Dictionary:
	return {
		"schema": "sporespore.lab.frame.v1",
		"run_id": run_id,
		"schema_version": "frame_v1",
		"frame_id": frame_id,
		"physics_step_id": frame_id,
		"capture_epoch": frame_id,
		"physics_time_s": float(frame_id),
		"sample_phase": "integrate_callback",
		"experiment_phase": "MEASURE",
		"release_frame_id": 0,
		"bodies": {
			"body_0": {
				"physics_step_id": frame_id,
				"body_callback_sequence": frame_id + 1,
				"capture_epoch": frame_id,
				"sample_phase": "integrate_callback",
				"body_id": "body_0",
				"part_index": 0,
				"transform": {
					"basis": [
						[1.0, 0.0, 0.0],
						[0.0, 1.0, 0.0],
						[0.0, 0.0, 1.0],
					],
					"origin": _array3(position),
				},
				"center_of_mass_world": _array3(position),
				"linear_velocity": _array3(velocity),
				"angular_velocity": [0.0, 0.0, 0.0],
				"mass_kg": 2.0,
				"inverse_inertia_tensor_world": {
					"x": [1.0, 0.0, 0.0],
					"y": [0.0, 1.0, 0.0],
					"z": [0.0, 0.0, 1.0],
				},
				"sleeping": false,
				"finite": true,
				"step_s": 1.0,
				"total_gravity_world": _array3(gravity),
				"com_frame_oracle_error_m": 0.0,
				"observer_profile_id": "full_contacts_v1",
				"observer_adapter_id": "rigid_body_integrate_forces_v1",
			},
		},
		"contacts": [],
		"availability": {
			"required_body_ids": ["body_0"],
			"captured_body_count": 1,
			"contact_count": 0,
			"invalid_reasons": [],
		},
		"finite": true,
	}


func _expected_metrics(experiment_id: String) -> Dictionary:
	match experiment_id:
		"L0_0_STATIONARY_GRAVITY_OFF":
			return {
				"external_work_j": 0.0,
				"max_position_error_m": 0.125,
				"max_velocity_error_m_s": 0.25,
				"max_kinetic_energy_j": 0.0625,
				"total_contact_count": 0,
			}
		"L0_1_FREE_FALL":
			return {
				"max_position_error_m": 0.25,
				"max_velocity_error_m_s": 0.25,
				"max_acceleration_error_m_s2": 0.25,
				"max_momentum_error_kg_m_s": 0.5,
				"total_contact_count": 0,
			}
		"L0_2_BALLISTIC_ZERO_G":
			return {
				"max_position_error_m": 0.5,
				"max_velocity_error_m_s": 0.25,
				"max_acceleration_error_m_s2": 0.25,
				"max_momentum_error_kg_m_s": 0.5,
				"total_contact_count": 0,
			}
	return {}


func _summary_metrics(
		experiment_id: String,
		expected: Dictionary,
		frame_count: int) -> Array:
	var result: Array = []
	if experiment_id == "L0_0_STATIONARY_GRAVITY_OFF":
		result.append(_metric_record(
			"external_work_j",
			expected["external_work_j"],
			"J",
			"runtime_notes.jsonl",
			"/1/evidence/external_work_derivation/value_j",
			"zero_external_work_from_sealed_absence_v1",
			frame_count))
		for definition in [
			[
				"max_position_error_m", "m",
				"/bodies/body_0/transform/origin",
			],
			[
				"max_velocity_error_m_s", "m/s",
				"/bodies/body_0/linear_velocity",
			],
			[
				"max_kinetic_energy_j", "J",
				"/bodies/body_0/linear_velocity",
			],
			["total_contact_count", "count", "/contacts"],
		]:
			result.append(_metric_record(
				definition[0],
				expected[definition[0]],
				definition[1],
				"frames.jsonl",
				definition[2],
				(
					"max_analytic_residual"
						if String(definition[0]).begins_with("max_")
						else "sum"),
				frame_count))
		return result
	for definition in [
		[
			"max_position_error_m", "m",
			"/bodies/body_0/transform/origin",
		],
		[
			"max_velocity_error_m_s", "m/s",
			"/bodies/body_0/linear_velocity",
		],
		[
			"max_acceleration_error_m_s2", "m/s^2",
			"/bodies/body_0/linear_velocity",
		],
		[
			"max_momentum_error_kg_m_s", "kg*m/s",
			"/bodies/body_0/linear_velocity",
		],
		["total_contact_count", "count", "/contacts"],
	]:
		result.append(_metric_record(
			definition[0],
			expected[definition[0]],
			definition[1],
			"frames.jsonl",
			definition[2],
			(
				"max_analytic_residual"
					if String(definition[0]).begins_with("max_")
					else "sum"),
			frame_count))
	return result


func _metric_record(
		metric_id: String,
		value: Variant,
		unit: String,
		source_stream: String,
		source_field: String,
		aggregation_id: String,
		frame_count: int) -> Dictionary:
	return {
		"metric_id": metric_id,
		"value": value,
		"unit": unit,
		"availability": "derived",
		"source_stream": source_stream,
		"source_frame_range": [0, frame_count - 1],
		"source_field": source_field,
		"aggregation_id": aggregation_id,
		"aggregation_version": 1,
		"target_value": 0.0,
	}


func _gate_parameters(experiment_id: String) -> Dictionary:
	match experiment_id:
		"L0_0_STATIONARY_GRAVITY_OFF":
			return {
				"max_position_error_m": 1.0,
				"max_velocity_error_m_s": 1.0,
				"total_contact_count": 0,
				"external_work_j": 0.0,
			}
		"L0_1_FREE_FALL":
			return {
				"max_acceleration_error_m_s2": 1.0,
				"max_velocity_error_m_s": 1.0,
				"max_position_error_m": 1.0,
			}
		"L0_2_BALLISTIC_ZERO_G":
			return {
				"max_position_error_m": 1.0,
				"max_velocity_error_m_s": 1.0,
				"max_momentum_error_kg_m_s": 1.0,
			}
	return {}


func _gate_inputs(
		experiment_id: String,
		metrics: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for metric_id in _gate_parameters(experiment_id):
		result[metric_id] = metrics[metric_id]
	return result


func _none_commands(run_id: String, count: int) -> Array:
	var commands: Array = []
	for index in count:
		var payload := {
			"schema": "sporespore.lab.command.v1",
			"run_id": run_id,
			"command_id": index,
			"source_frame_id": index,
			"applied_transition": [index, index + 1],
			"mode": "NONE",
			"joint_commands": [],
			"intervention_operation_ids": [],
		}
		commands.append({
			"command_payload_sha256":
				CanonicalJsonScript.sha256(payload),
			"payload": payload,
		})
	return commands


func _runtime_notes(run_id: String) -> Array:
	return [
		{
			"schema": "sporespore.lab.runtime_note.v1",
			"run_id": run_id,
			"note_sequence": 0,
			"frame_id": null,
			"source": "test",
			"severity": "info",
			"code": "RUN_START",
			"message": "test",
			"evidence": {},
		},
		{
			"schema": "sporespore.lab.runtime_note.v1",
			"run_id": run_id,
			"note_sequence": 1,
			"frame_id": null,
			"source": "test",
			"severity": "info",
			"code": "RUN_RESULT",
			"message": "test",
			"evidence": {
				"external_work_derivation": {
					"available": true,
					"value_j": 0.0,
					"method":
						"zero_external_work_from_sealed_absence_v1",
				},
			},
		},
	]


func _verify_case(value: Dictionary) -> Dictionary:
	return RecomputerScript.verify(
		value["manifest"],
		value["summary"],
		value["streams"])


func _clone_case(value: Dictionary) -> Dictionary:
	return value.duplicate(true)


func _metric(summary: Dictionary, metric_id: String) -> Dictionary:
	for metric_value in summary["metrics"]:
		var metric: Dictionary = metric_value
		if String(metric["metric_id"]) == metric_id:
			return metric
	return {}


func _has_error(result: Dictionary, code: String) -> bool:
	for error_value in result.get("errors", []):
		var error: Dictionary = error_value
		if String(error.get("code", "")) == code:
			return true
	return false


func _assert_metric(
		result: Dictionary,
		metric_id: String,
		expected: float,
		label: String) -> void:
	var actual := float(
		result.get("recomputed_metrics", {}).get(metric_id, NAN))
	_check(
		is_finite(actual) and absf(actual - expected) <= 1.0e-9,
		label)


func _array3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)
