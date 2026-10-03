extends SceneTree

## R115 reuses the complete R113 controller test under a publication-stable
## successor declaration. No model or world is built.

const R113Test := preload(
	"res://tests/test_sdk_qsdk_r24d113_godot_mirrored_front_knee_controller_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := (
	"SPORESPORE_GODOT_R24D115_PUBLICATION_STABLE_MIRRORED_FRONT_KNEE_ZERO_WORLD "
)


func _initialize() -> void:
	var result := R113Test._evaluate().duplicate(true)
	result["schema_version"] = (
		"sporespore_qsdk_r24d115_godot_publication_stable_mirrored_front_knee_zero_world_v1"
	)
	result["gate_id"] = "QSDK-R24D115"
	result["ledger_scope"] = {
		"subsystem": "recovery",
		"engine_scope": "godot_jolt",
		"authority_mode": "prospective_publication_stable_finite_behavior_zero_world",
		"question_class": "development",
	}
	result["physical_question_declared"] = true
	result["physical_execution_authorized"] = false
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)
