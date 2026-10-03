extends SceneTree
# gdlint: disable=max-line-length

## Reusable zero-world contract for Godot/Jolt runtime-limit provenance and the
## complete ordered body angular-velocity invariant. No Node, RID, model, world,
## or solver step is created.

const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_JOLT_NATIVE_ENGINE_HEALTH_ZERO_WORLD "
const SEMANTIC_STEP := 1


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JsonTransportScript.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)


static func _run() -> Dictionary:
	var runtime := WorldScript.jolt_angular_velocity_limit_runtime_projection_v1()
	if not bool(runtime.get("ok", false)):
		return _failure("RUNTIME_PROJECTION_FAILED", runtime)
	var maximum := float(runtime.get("effective_max_angular_velocity_rad_s", NAN))
	if (
		String(runtime.get("schema_version", ""))
		!= WorldScript.JOLT_ANGULAR_VELOCITY_RUNTIME_PROJECTION_SCHEMA
		or String(runtime.get("setting_path", ""))
		!= WorldScript.JOLT_MAX_ANGULAR_VELOCITY_SETTING_PATH
		or not bool(runtime.get("setting_present", false))
		or not bool(runtime.get("source_measurement", false))
		or not is_finite(maximum)
		or maximum <= 0.0
	):
		return _failure("RUNTIME_PROJECTION_INVALID", runtime)

	var ordinary_rows := _rows(maximum, false)
	var ordinary := WorldScript.body_angular_velocity_limit_receipt_v1(
		runtime, ordinary_rows, SEMANTIC_STEP
	)
	var boundary_rows := _rows(maximum, true)
	var boundary := WorldScript.body_angular_velocity_limit_receipt_v1(
		runtime, boundary_rows, SEMANTIC_STEP
	)
	if not _positive_receipt_valid(ordinary, maximum, false):
		return _failure("ORDINARY_POSITIVE_INVALID", ordinary)
	if not _positive_receipt_valid(boundary, maximum, true):
		return _failure("EXACT_BOUNDARY_POSITIVE_INVALID", boundary)

	var rejected_failure_codes: Array = []
	var bad_runtime := runtime.duplicate(true)
	bad_runtime["schema_version"] = "mutated"
	if not _record_rejection(
		WorldScript.body_angular_velocity_limit_receipt_v1(
			bad_runtime, ordinary_rows, SEMANTIC_STEP
		),
		"QSDK_R24D93_ANGULAR_LIMIT_RUNTIME_PROJECTION_INVALID",
		rejected_failure_codes,
	):
		return _failure("BAD_RUNTIME_NOT_REJECTED")
	if not _record_rejection(
		WorldScript.body_angular_velocity_limit_receipt_v1(
			runtime, null, SEMANTIC_STEP
		),
		"QSDK_R24D93_ANGULAR_LIMIT_BODY_POPULATION_MISSING",
		rejected_failure_codes,
	):
		return _failure("MISSING_POPULATION_NOT_REJECTED")
	var truncated := ordinary_rows.duplicate(true)
	truncated.pop_back()
	if not _record_rejection(
		WorldScript.body_angular_velocity_limit_receipt_v1(
			runtime, truncated, SEMANTIC_STEP
		),
		"QSDK_R24D93_ANGULAR_LIMIT_BODY_POPULATION_INVALID",
		rejected_failure_codes,
	):
		return _failure("TRUNCATED_POPULATION_NOT_REJECTED")
	var reordered := ordinary_rows.duplicate(true)
	var first: Variant = reordered[0]
	reordered[0] = reordered[1]
	reordered[1] = first
	if not _record_rejection(
		WorldScript.body_angular_velocity_limit_receipt_v1(
			runtime, reordered, SEMANTIC_STEP
		),
		"QSDK_R24D93_ANGULAR_LIMIT_BODY_MEASUREMENT_INVALID:",
		rejected_failure_codes,
	):
		return _failure("REORDERED_POPULATION_NOT_REJECTED")
	var stale := ordinary_rows.duplicate(true)
	(stale[0] as Dictionary)["callback_sequence"] = SEMANTIC_STEP + 1
	if not _record_rejection(
		WorldScript.body_angular_velocity_limit_receipt_v1(
			runtime, stale, SEMANTIC_STEP
		),
		"QSDK_R24D93_ANGULAR_LIMIT_BODY_MEASUREMENT_INVALID:",
		rejected_failure_codes,
	):
		return _failure("STALE_CALLBACK_NOT_REJECTED")
	var unmeasured := ordinary_rows.duplicate(true)
	(unmeasured[0] as Dictionary)["source_measurement"] = false
	if not _record_rejection(
		WorldScript.body_angular_velocity_limit_receipt_v1(
			runtime, unmeasured, SEMANTIC_STEP
		),
		"QSDK_R24D93_ANGULAR_LIMIT_BODY_MEASUREMENT_INVALID:",
		rejected_failure_codes,
	):
		return _failure("UNMEASURED_BODY_NOT_REJECTED")
	var nonfinite := ordinary_rows.duplicate(true)
	(nonfinite[0] as Dictionary)["angular_velocity_world_rad_s"] = Vector3(INF, 0.0, 0.0)
	if not _record_rejection(
		WorldScript.body_angular_velocity_limit_receipt_v1(
			runtime, nonfinite, SEMANTIC_STEP
		),
		"QSDK_R24D93_ANGULAR_LIMIT_BODY_NONFINITE:",
		rejected_failure_codes,
	):
		return _failure("NONFINITE_BODY_NOT_REJECTED")
	var exceeded := ordinary_rows.duplicate(true)
	(exceeded[0] as Dictionary)["angular_velocity_world_rad_s"] = Vector3(
		maximum * 1.01, 0.0, 0.0
	)
	if not _record_rejection(
		WorldScript.body_angular_velocity_limit_receipt_v1(
			runtime, exceeded, SEMANTIC_STEP
		),
		"QSDK_R24D93_ANGULAR_VELOCITY_LIMIT_EXCEEDED",
		rejected_failure_codes,
	):
		return _failure("OVER_LIMIT_BODY_NOT_REJECTED")

	return {
		"schema_version": "sporespore_godot_jolt_native_engine_health_zero_world_v1",
		"gate_id": "QSDK-R24D93",
		"ok": rejected_failure_codes.size() == 8,
		"runtime_projection": runtime,
		"effective_max_angular_velocity_rad_s": maximum,
		"positive_case_count": 2,
		"forced_failure_case_count": rejected_failure_codes.size(),
		"ordered_rejected_failure_codes": rejected_failure_codes,
		"ordered_body_count": WorldScript.ORDERED_BODY_IDS.size(),
		"retained_body_measurement_count": int(ordinary["body_measurement_count"]),
		"exact_limit_equality_passed": true,
		"over_limit_mutation_rejected": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _rows(maximum: float, exact_boundary: bool) -> Array:
	var rows: Array = []
	for index in WorldScript.ORDERED_BODY_IDS.size():
		var speed := maximum if exact_boundary and index == 0 else maximum * float(index) / 20.0
		rows.append(
			{
				"body_id": String(WorldScript.ORDERED_BODY_IDS[index]),
				"callback_sequence": SEMANTIC_STEP,
				"angular_velocity_world_rad_s": Vector3(speed, 0.0, 0.0),
				"source_measurement": true,
			}
		)
	return rows


static func _positive_receipt_valid(
	receipt: Dictionary,
	maximum: float,
	exact_boundary: bool,
) -> bool:
	var rows: Array = receipt.get("ordered_body_measurements", [])
	return (
		String(receipt.get("schema_version", ""))
		== WorldScript.BODY_ANGULAR_VELOCITY_LIMIT_RECEIPT_SCHEMA
		and bool(receipt.get("ok", false))
		and int(receipt.get("semantic_step", -1)) == SEMANTIC_STEP
		and int(receipt.get("body_measurement_count", -1))
		== WorldScript.ORDERED_BODY_IDS.size()
		and int(receipt.get("within_limit_count", -1))
		== WorldScript.ORDERED_BODY_IDS.size()
		and rows.size() == WorldScript.ORDERED_BODY_IDS.size()
		and bool(receipt.get("native_engine_health_passed", false))
		and bool(receipt.get("source_measurement", false))
		and float(receipt.get("effective_max_angular_velocity_rad_s", NAN)) == maximum
		and (
			not exact_boundary
			or float((rows[0] as Dictionary).get("angular_speed_rad_s", NAN)) == maximum
		)
	)


static func _record_rejection(
	receipt: Dictionary,
	expected_failure_prefix: String,
	rejected_failure_codes: Array,
) -> bool:
	var failure_code := String(receipt.get("failure_code", ""))
	if bool(receipt.get("ok", true)) or not failure_code.begins_with(expected_failure_prefix):
		return false
	rejected_failure_codes.append(failure_code)
	return true


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_godot_jolt_native_engine_health_zero_world_failure_v1",
		"gate_id": "QSDK-R24D93",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
