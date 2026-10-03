extends SceneTree

## R71 binding probe only. It creates no Node, RID-backed space, body, model,
## world, or solver step.

const CLASS_NAME := &"JoltPhysicsServer3D"
const METHOD_NAME := &"space_get_solved_contact_telemetry"
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "QSDK_R24D71_GODOT_SOLVED_CONTACT_BINDING_ZERO_WORLD "
const RECEIPT_SCHEMA := "sporespore.godot_jolt_solved_contact_telemetry.v1"
const PROFILE_ID := "godot_4_7_jolt_sporespore_solved_contact_telemetry_v1"
const RECEIPT_FIELDS := [
	"schema",
	"profile_id",
	"capture_space_step_sequence",
	"read_space_step_sequence",
	"captured_during_active_step",
	"snapshot_is_current_space_step",
	"reported_manifold_count",
	"reported_contact_point_count",
	"exact_manifold_count",
	"exact_contact_point_count",
	"missing_manifold_count",
	"ccd_only_manifold_count",
	"point_count_mismatch_count",
	"nonfinite_impulse_count",
	"complete",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_check(ClassDB.class_exists(CLASS_NAME), "instrumented Jolt class is registered")
	_check(
		ClassDB.class_has_method(CLASS_NAME, METHOD_NAME),
		"solved-contact telemetry method is bound",
	)
	var invalid_readback: Variant = (
		JoltPhysicsServer3D.space_get_solved_contact_telemetry(RID())
	)
	_check(invalid_readback == null, "invalid space RID refuses instead of synthesizing zero")
	_check(RECEIPT_SCHEMA.ends_with(".v1"), "receipt schema is explicitly versioned")
	_check(PROFILE_ID.ends_with("_v1"), "runtime profile is explicitly versioned")
	_check(RECEIPT_FIELDS.size() == 15, "receipt field population is frozen")
	_check(
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS) == 0.0,
		"no physics object exists",
	)
	var receipt := {
		"schema_version": "sporespore_qsdk_r24d71_godot_solved_contact_binding_zero_world_v1",
		"gate_id": "QSDK-R24D71",
		"ok": _failed == 0,
		"assertion_count": _passed + _failed,
		"passed_assertion_count": _passed,
		"failed_assertion_count": _failed,
		"receipt_field_count": RECEIPT_FIELDS.size(),
		"invalid_rid_refusal_count": int(invalid_readback == null),
		"native_runtime_observation_collection_executed": false,
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
	print(MARKER, JsonTransportScript.stringify(receipt))
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)
