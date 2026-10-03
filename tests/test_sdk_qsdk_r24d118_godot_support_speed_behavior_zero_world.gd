extends SceneTree

## R118 binds the complete R117 controller/route proof to a distinct finite
## physical development declaration. No model or world is built here.

const R117Test := preload(
	"res://tests/test_sdk_qsdk_r24d117_godot_support_speed_controller_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_R24D118_SUPPORT_SPEED_BEHAVIOR_ZERO_WORLD "


func _initialize() -> void:
	var result := R117Test._evaluate().duplicate(true)
	result["schema_version"] = (
		"sporespore_qsdk_r24d118_godot_support_speed_behavior_zero_world_v1"
	)
	result["gate_id"] = "QSDK-R24D118"
	result["ledger_scope"] = {
		"subsystem": "recovery",
		"engine_scope": "godot_jolt",
		"authority_mode": "prospective_finite_support_speed_behavior_zero_world",
		"question_class": "development",
	}
	result["positive_case_count"] = 2
	result["forced_failure_case_count"] = 5
	result["physical_question_declared"] = true
	result["physical_execution_authorized"] = false
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)
