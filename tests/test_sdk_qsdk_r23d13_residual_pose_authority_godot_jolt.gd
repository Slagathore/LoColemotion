extends SceneTree

const Policy := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_r23d13_residual_pose_authority.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not ["preflight", "physical"].has(String(args[0])):
		print("QSDK_R23D13_GODOT_JOLT_AUTHORITY_FAILURE ", JSON.stringify({
			"schema_version": "sporespore_qsdk_r23d13_native_authority_failure_v1",
			"engine_id": "godot_jolt",
			"failure_stage": "before_model",
			"failure_code": "QSDK_R23D13_GJT_ARGUMENTS_INVALID",
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}))
		quit(1)
		return
	if String(args[0]) == "physical":
		print("QSDK_R23D13_GODOT_JOLT_AUTHORITY_FAILURE ", JSON.stringify({
			"schema_version": "sporespore_qsdk_r23d13_native_authority_failure_v1",
			"engine_id": "godot_jolt",
			"failure_stage": "before_model",
			"failure_code": "QSDK_R23D13_GJT_PHYSICAL_ROUTE_NOT_IMPLEMENTED",
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}))
		quit(1)
		return
	var receipt := Policy.preflight()
	if not bool(receipt.get("ok", false)):
		print("QSDK_R23D13_GODOT_JOLT_AUTHORITY_FAILURE ", JSON.stringify(receipt))
		quit(1)
		return
	print("QSDK_R23D13_GODOT_JOLT_AUTHORITY_PREFLIGHT ", JSON.stringify(receipt))
	quit(0)
