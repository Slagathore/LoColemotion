extends SceneTree

## R128 binds the complete qualified R127 V6 controller/realization proof to
## one distinct finite physical development declaration. No model or world is
## built here.

const R127Test := preload(
	"res://tests/test_sdk_qsdk_r24d127_godot_solver_coupled_controller_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_R24D128_SOLVER_COUPLED_BEHAVIOR_ZERO_WORLD "


func _initialize() -> void:
	var result := R127Test._evaluate().duplicate(true)
	result["schema_version"] = (
		"sporespore_qsdk_r24d128_godot_solver_coupled_recovery_behavior_zero_world_v1"
	)
	result["gate_id"] = "QSDK-R24D128"
	result["ledger_scope"] = {
		"subsystem": "recovery",
		"engine_scope": "godot_jolt",
		"authority_mode": "prospective_bounded_solver_coupled_recovery_behavior_zero_world",
		"question_class": "development",
	}
	result["positive_case_count"] = 6
	result["forced_failure_case_count"] = 11
	result["physical_question_declared"] = true
	result["physical_execution_authorized"] = false
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)
