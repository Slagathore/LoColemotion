extends SceneTree

## R124 binds the complete R123 V5 controller and route proof to a distinct
## bounded physical development declaration. No model or world is built here.

const R123Test := preload(
	"res://tests/test_sdk_qsdk_r24d123_godot_raise_body_speed_controller_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_R24D124_RAISE_BODY_SPEED_BEHAVIOR_ZERO_WORLD "


func _initialize() -> void:
	var result := R123Test._evaluate().duplicate(true)
	result["schema_version"] = (
		"sporespore_qsdk_r24d124_godot_raise_body_speed_behavior_zero_world_v1"
	)
	result["gate_id"] = "QSDK-R24D124"
	result["ledger_scope"] = {
		"subsystem": "recovery",
		"engine_scope": "godot_jolt",
		"authority_mode": "prospective_bounded_raise_body_speed_behavior_zero_world",
		"question_class": "development",
	}
	result["positive_case_count"] = 5
	result["forced_failure_case_count"] = 7
	result["physical_question_declared"] = true
	result["physical_execution_authorized"] = false
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)
