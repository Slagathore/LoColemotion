extends SceneTree

const Semantics := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_r23d12_measurement_semantics.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not ["preflight", "physical"].has(String(args[0])):
		print("QSDK_R23D12_GODOT_JOLT_SEMANTICS_FAILURE ", JSON.stringify({
			"schema_version": "sporespore_qsdk_r23d12_native_semantics_failure_v1",
			"engine_id": "godot_jolt",
			"failure_stage": "before_model",
			"failure_code": "QSDK_R23D12_GJT_ARGUMENTS_INVALID",
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}))
		quit(1)
		return
	if String(args[0]) == "physical":
		print("QSDK_R23D12_GODOT_JOLT_SEMANTICS_FAILURE ", JSON.stringify({
			"schema_version": "sporespore_qsdk_r23d12_native_semantics_failure_v1",
			"engine_id": "godot_jolt",
			"failure_stage": "before_model",
			"failure_code": "QSDK_R23D12_GJT_PHYSICAL_ROUTE_NOT_IMPLEMENTED",
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}))
		quit(1)
		return
	var receipt := Semantics.preflight()
	if not bool(receipt.get("ok", false)):
		print("QSDK_R23D12_GODOT_JOLT_SEMANTICS_FAILURE ", JSON.stringify(receipt))
		quit(1)
		return
	print("QSDK_R23D12_GODOT_JOLT_SEMANTICS_PREFLIGHT ", JSON.stringify(receipt))
	quit(0)
