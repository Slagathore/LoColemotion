extends SceneTree
# gdlint: disable=max-line-length

## Zero-world numeric controls for the QSDK-R10E native impulse receipt.

const HistoricalValidationScript := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10e_native_impulse_scalar_receipt_validation_v1.gd"
)

const ValidationScript := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10e_native_impulse_scalar_receipt_validation_v2.gd"
)

const PASS_MARKER := "QSDK_R10E_NATIVE_IMPULSE_SCALAR_RECEIPT_ZERO_WORLD_PASS"

var _failures: Array[String] = []
var _within_allowance_acceptance_count := 0
var _outside_allowance_refusal_count := 0
var _nonfinite_or_wrong_shape_refusal_count := 0
var _missing_or_extra_field_refusal_count := 0
var _material_impulse_mutation_refusal_count := 0
var _retained_l2_regression_acceptance_count := 0
var _retained_l2_historical_refusal_count := 0
var _retained_l2_material_mutation_refusal_count := 0


func _init() -> void:
	_within_allowance_positive_controls()
	_outside_allowance_refusal_controls()
	_nonfinite_and_wrong_shape_refusal_controls()
	_missing_and_extra_field_refusal_controls()
	_material_impulse_mutation_refusal_controls()
	_retained_l2_operation_replay_regression()
	_check(_within_allowance_acceptance_count >= 8, "at least eight within-allowance controls")
	_check(_outside_allowance_refusal_count >= 8, "at least eight outside-allowance controls")
	_check(
		_nonfinite_or_wrong_shape_refusal_count >= 8,
		"at least eight nonfinite or wrong-shape controls",
	)
	_check(
		_missing_or_extra_field_refusal_count >= 2,
		"at least two missing or extra field controls",
	)
	_check(
		_material_impulse_mutation_refusal_count >= 4,
		"at least four material impulse mutation controls",
	)
	_check(
		_retained_l2_regression_acceptance_count == 1,
		"retained L2 receipt accepted by operation-equivalent replay",
	)
	_check(
		_retained_l2_historical_refusal_count == 1,
		"retained L2 receipt reproduces the historical sole-predicate refusal",
	)
	_check(
		_retained_l2_material_mutation_refusal_count == 3,
		"three material retained-receipt mutations refused",
	)
	if _failures.is_empty():
		print(PASS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _within_allowance_positive_controls() -> void:
	var cases := [
		[1.0, 1.0],
		[1.0 + 1.0e-7, 1.0],
		[1.0 - 1.0e-7, 1.0],
		[1.0, 1.0 + 1.0e-7],
		[1.0, 1.0 - 1.0e-7],
		[1.0 + 5.0e-7, 1.0 + 5.0e-7],
		[1.0 - 5.0e-7, 1.0 - 5.0e-7],
		[1.0 + 1.0e-6, 1.0 - 1.0e-6],
	]
	for case_index in range(cases.size()):
		var scales: Array = cases[case_index]
		var result := _validate(
			_valid_receipt(float(scales[0]), float(scales[1])),
			[1.0, 0.0, 0.0],
			[0.0, 0.0, 1.0],
		)
		if bool(result.get("ok", false)):
			_within_allowance_acceptance_count += 1
		else:
			_failures.append("within-allowance case %d refused" % case_index)


func _outside_allowance_refusal_controls() -> void:
	var mutations: Array[Dictionary] = []
	var world_link := _valid_receipt()
	world_link["impulse_world_n_s"] = [0.0, 0.0, 0.25000001]
	mutations.append({"receipt": world_link})
	var raw_norm := _valid_receipt()
	raw_norm["initial_task_frame_lateral_axis_world_host_real"] = [0.0, 0.0, 1.000003]
	raw_norm["impulse_world_n_s"] = [0.0, 0.0, 0.25000075]
	mutations.append({"receipt": raw_norm})
	var task_impulse := _valid_receipt()
	task_impulse["impulse_task_n_s"] = [0.0, 0.0, 0.249]
	mutations.append({"receipt": task_impulse})
	var observed_link := _valid_receipt()
	observed_link["observed_next_tick_velocity_delta_magnitude_m_s"] = 0.081
	mutations.append({"receipt": observed_link})
	var schema := _valid_receipt()
	schema["schema_version"] = "sporespore_qsdk_r10d_native_impulse_application_receipt_v1"
	mutations.append({"receipt": schema})
	var application_count := _valid_receipt()
	application_count["application_count"] = 2
	mutations.append({"receipt": application_count})
	var precision := _valid_receipt()
	precision["impulse_composition_numeric_precision"] = "binary64"
	mutations.append({"receipt": precision})
	(
		mutations
		. append(
			{
				"receipt": _valid_receipt(),
				"marker_lateral": [0.0, 0.0, 1.0 + 1.0e-8],
			}
		)
	)
	for case_index in range(mutations.size()):
		var mutation: Dictionary = mutations[case_index]
		var result := _validate(
			mutation["receipt"],
			mutation.get("marker_forward", [1.0, 0.0, 0.0]),
			mutation.get("marker_lateral", [0.0, 0.0, 1.0]),
		)
		if not bool(result.get("ok", false)):
			_outside_allowance_refusal_count += 1
		else:
			_failures.append("outside-allowance case %d accepted" % case_index)


func _nonfinite_and_wrong_shape_refusal_controls() -> void:
	var mutations: Array[Dictionary] = []
	for field in [
		"impulse_task_n_s",
		"impulse_world_n_s",
		"initial_task_frame_forward_axis_world_host_real",
		"initial_task_frame_lateral_axis_world_host_real",
		"observed_next_tick_velocity_delta_world_m_s",
	]:
		var wrong_shape := _valid_receipt()
		wrong_shape[String(field)] = [0.0, 0.0]
		mutations.append({"receipt": wrong_shape})
	var nonfinite_world := _valid_receipt()
	nonfinite_world["impulse_world_n_s"] = [0.0, NAN, 0.25]
	mutations.append({"receipt": nonfinite_world})
	var nonfinite_effect := _valid_receipt()
	nonfinite_effect["observed_next_tick_velocity_delta_magnitude_m_s"] = INF
	mutations.append({"receipt": nonfinite_effect})
	(
		mutations
		. append(
			{
				"receipt": _valid_receipt(),
				"marker_forward": [NAN, 0.0, 0.0],
			}
		)
	)
	for case_index in range(mutations.size()):
		var mutation: Dictionary = mutations[case_index]
		var result := _validate(
			mutation["receipt"],
			mutation.get("marker_forward", [1.0, 0.0, 0.0]),
			mutation.get("marker_lateral", [0.0, 0.0, 1.0]),
		)
		if not bool(result.get("ok", false)):
			_nonfinite_or_wrong_shape_refusal_count += 1
		else:
			_failures.append("nonfinite or wrong-shape case %d accepted" % case_index)


func _missing_and_extra_field_refusal_controls() -> void:
	var missing := _valid_receipt()
	missing.erase("impulse_world_n_s")
	var extra := _valid_receipt()
	extra["undeclared"] = true
	for receipt in [missing, extra]:
		var result := _validate(receipt, [1.0, 0.0, 0.0], [0.0, 0.0, 1.0])
		if (
			not bool(result.get("ok", false))
			and String(result.get("failure_code", "")) == "QSDK_R10E_PUSH_RECEIPT_KEY_SET_MISMATCH"
		):
			_missing_or_extra_field_refusal_count += 1
		else:
			_failures.append("missing or extra field accepted")


func _material_impulse_mutation_refusal_controls() -> void:
	var mutations: Array[Dictionary] = []
	var magnitude := _valid_receipt()
	magnitude["impulse_task_n_s"] = [0.0, 0.0, 0.30]
	mutations.append(magnitude)
	var direction := _valid_receipt()
	direction["impulse_task_n_s"] = [0.25, 0.0, 0.0]
	mutations.append(direction)
	var step := _valid_receipt()
	step["step_from_sdk_start"] = 899
	mutations.append(step)
	var profile := _valid_receipt()
	profile["profile_id"] = "none"
	mutations.append(profile)
	for case_index in range(mutations.size()):
		var result := _validate(
			mutations[case_index],
			[1.0, 0.0, 0.0],
			[0.0, 0.0, 1.0],
		)
		if not bool(result.get("ok", false)):
			_material_impulse_mutation_refusal_count += 1
		else:
			_failures.append("material impulse mutation %d accepted" % case_index)


func _retained_l2_operation_replay_regression() -> void:
	var receipt := _retained_l2_push_receipt()
	var marker_forward := [0.9999899726356972, 0.0, 0.004478239392600431]
	var marker_lateral := [-0.004478239392600431, 0.0, 0.9999899726356972]
	var historical := (
		HistoricalValidationScript
		. validate_push_receipt(
			receipt,
			1,
			marker_forward,
			marker_lateral,
		)
	)
	if (
		not bool(historical.get("ok", false))
		and (
			String(historical.get("failure_code", ""))
			== "QSDK_R10E_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH"
		)
		and (
			historical.get("failed_predicates", [])
			== ["observed_delta_vector_links_to_stored_magnitude"]
		)
	):
		_retained_l2_historical_refusal_count += 1
	else:
		_failures.append("retained L2 receipt did not reproduce historical refusal")

	var repaired := (
		ValidationScript
		. validate_push_receipt(
			receipt,
			1,
			marker_forward,
			marker_lateral,
		)
	)
	var allowance_receipt: Dictionary = repaired.get("allowance_receipt", {})
	if (
		bool(repaired.get("ok", false))
		and int(repaired.get("predicate_count", 0)) == 20
		and repaired.get("failed_predicates", []) == []
		and (
			String(repaired.get("observed_delta_magnitude_replay_operation", ""))
			== "Vector3(exported_components).length()"
		)
		and (
			float(repaired.get("observed_delta_host_real_replay_magnitude_m_s", NAN))
			== float(receipt["observed_next_tick_velocity_delta_magnitude_m_s"])
		)
		and (
			String(allowance_receipt.get("observed_delta_magnitude_link_allowance_mode", ""))
			== "binary64_transport_only"
		)
		and int(allowance_receipt.get("observed_delta_host_real_vector_construction_count", 0)) == 1
		and bool(allowance_receipt.get("axis_and_impulse_links_remain_scalar_only", false))
		and not bool(allowance_receipt.get("observed_l2_outcome_used_to_select_allowance", true))
		and not bool(allowance_receipt.get("effect_floor_changed", true))
		and not bool(allowance_receipt.get("behavior_threshold_changed", true))
		and int(repaired.get("world_attempt_count", -1)) == 0
		and int(repaired.get("world_build_count", -1)) == 0
		and int(repaired.get("solver_step_count", -1)) == 0
	):
		_retained_l2_regression_acceptance_count += 1
	else:
		_failures.append("retained L2 receipt not accepted by declared host-real replay")

	var stored_magnitude_high := receipt.duplicate(true)
	stored_magnitude_high["observed_next_tick_velocity_delta_magnitude_m_s"] = (
		float(receipt["observed_next_tick_velocity_delta_magnitude_m_s"]) + 1.0e-7
	)
	var stored_magnitude_low := receipt.duplicate(true)
	stored_magnitude_low["observed_next_tick_velocity_delta_magnitude_m_s"] = (
		float(receipt["observed_next_tick_velocity_delta_magnitude_m_s"]) - 1.0e-7
	)
	var component_mutation := receipt.duplicate(true)
	var mutated_delta: Array = (
		(component_mutation["observed_next_tick_velocity_delta_world_m_s"] as Array).duplicate()
	)
	mutated_delta[0] = float(mutated_delta[0]) + 1.0e-5
	component_mutation["observed_next_tick_velocity_delta_world_m_s"] = mutated_delta
	for mutation in [stored_magnitude_high, stored_magnitude_low, component_mutation]:
		var refusal := (
			ValidationScript
			. validate_push_receipt(
				mutation,
				1,
				marker_forward,
				marker_lateral,
			)
		)
		if (
			not bool(refusal.get("ok", false))
			and (
				refusal.get("failed_predicates", [])
				== ["observed_delta_vector_links_to_stored_magnitude"]
			)
		):
			_retained_l2_material_mutation_refusal_count += 1
		else:
			_failures.append("material retained L2 magnitude-link mutation accepted")


static func _valid_receipt(forward_scale := 1.0, lateral_scale := 1.0) -> Dictionary:
	var observed_delta := Vector3(0.0, 0.0, 0.08)
	return {
		"schema_version": ValidationScript.RECEIPT_SCHEMA,
		"profile_id": ValidationScript.PROFILE_ID,
		"target_body_id": ValidationScript.TARGET_BODY_ID,
		"application_method": ValidationScript.APPLICATION_METHOD,
		"tick": 1620,
		"step_from_sdk_start": ValidationScript.PUSH_MARKER_SEMANTIC_STEP,
		"impulse_task_n_s": [0.0, 0.0, 0.25],
		"impulse_world_n_s": [0.0, 0.0, 0.25 * lateral_scale],
		"application_count": 1,
		"controller_command": false,
		"effect_sampled": true,
		"observed_next_tick_velocity_delta_world_m_s":
		[observed_delta.x, observed_delta.y, observed_delta.z],
		"observed_next_tick_velocity_delta_magnitude_m_s": observed_delta.length(),
		"initial_task_frame_forward_axis_world_host_real": [forward_scale, 0.0, 0.0],
		"initial_task_frame_lateral_axis_world_host_real": [0.0, 0.0, lateral_scale],
		"impulse_composition_numeric_precision":
		ValidationScript.IMPULSE_COMPOSITION_NUMERIC_PRECISION,
	}


static func _retained_l2_push_receipt() -> Dictionary:
	return {
		"schema_version": ValidationScript.RECEIPT_SCHEMA,
		"profile_id": ValidationScript.PROFILE_ID,
		"target_body_id": ValidationScript.TARGET_BODY_ID,
		"application_method": ValidationScript.APPLICATION_METHOD,
		"tick": 1140,
		"step_from_sdk_start": ValidationScript.PUSH_MARKER_SEMANTIC_STEP,
		"impulse_task_n_s": [0.0, 0.0, 0.25],
		"impulse_world_n_s": [-0.0011195598635822535, 0.0, 0.24999749660491943],
		"application_count": 1,
		"controller_command": false,
		"effect_sampled": true,
		"observed_next_tick_velocity_delta_world_m_s":
		[-0.008176282048225403, 0.0009064096957445145, 0.06388828158378601],
		"observed_next_tick_velocity_delta_magnitude_m_s": 0.06441572308540344,
		"initial_task_frame_forward_axis_world_host_real":
		[0.9999899864196777, 0.0, 0.004478239454329014],
		"initial_task_frame_lateral_axis_world_host_real":
		[-0.004478239454329014, 0.0, 0.9999899864196777],
		"impulse_composition_numeric_precision":
		ValidationScript.IMPULSE_COMPOSITION_NUMERIC_PRECISION,
	}


static func _validate(
	receipt: Dictionary,
	marker_forward: Variant,
	marker_lateral: Variant,
) -> Dictionary:
	return (
		ValidationScript
		. validate_push_receipt(
			receipt,
			1,
			marker_forward,
			marker_lateral,
		)
	)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
