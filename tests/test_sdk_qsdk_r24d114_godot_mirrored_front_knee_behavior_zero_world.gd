extends SceneTree

## R114 reuses the complete R113 native zero-world mechanics and changes only
## the gate identity and declaration boundary. No model or world is built.

const R113Test := preload(
	"res://tests/test_sdk_qsdk_r24d113_godot_mirrored_front_knee_controller_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_R24D114_MIRRORED_FRONT_KNEE_BEHAVIOR_ZERO_WORLD "


func _initialize() -> void:
	var result := R113Test._evaluate().duplicate(true)
	result["schema_version"] = (
		"sporespore_qsdk_r24d114_godot_mirrored_front_knee_behavior_zero_world_v1"
	)
	result["gate_id"] = "QSDK-R24D114"
	result["ledger_scope"] = {
		"subsystem": "recovery",
		"engine_scope": "godot_jolt",
		"authority_mode": "prospective_finite_behavior_declaration_zero_world",
		"question_class": "development",
	}
	result["physical_question_declared"] = true
	result["physical_execution_authorized"] = false
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)
