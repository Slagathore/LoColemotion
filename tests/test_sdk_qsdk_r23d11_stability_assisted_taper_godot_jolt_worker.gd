extends SceneTree

const Policy := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_stability_assisted_taper.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var parsed := _parse(args)
	if not bool(parsed.get("ok", false)):
		print("QSDK_R23D11_GODOT_JOLT_FAILURE ", JSON.stringify(parsed))
		quit(1)
		return
	if String(parsed["command"]) == "physical":
		var failure := {
			"schema_version": "sporespore_qsdk_r23d11_worker_failure_v1",
			"failure_stage": "before_model",
			"failure_code": "QSDK_R23D11_GJT_PHYSICAL_ROUTE_NOT_IMPLEMENTED",
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
		print("QSDK_R23D11_GODOT_JOLT_FAILURE ", JSON.stringify(failure))
		quit(1)
		return
	var receipt := Policy.preflight(String(parsed["stage_id"]), String(parsed["arm_id"]))
	if not bool(receipt.get("ok", false)):
		print("QSDK_R23D11_GODOT_JOLT_FAILURE ", JSON.stringify(receipt))
		quit(1)
		return
	print("QSDK_R23D11_GODOT_JOLT_PREFLIGHT ", JSON.stringify(receipt))
	quit(0)


func _parse(args: PackedStringArray) -> Dictionary:
	if args.size() != 5 or not ["preflight", "physical"].has(String(args[0])):
		return {"ok": false, "failure_code": "R23D11_GJT_ARGUMENTS_INVALID"}
	var stage_id := ""
	var arm_id := ""
	var index := 1
	while index < args.size():
		match String(args[index]):
			"--stage":
				stage_id = String(args[index + 1])
			"--arm":
				arm_id = String(args[index + 1])
			_:
				return {"ok": false, "failure_code": "R23D11_GJT_ARGUMENTS_INVALID"}
		index += 2
	if stage_id.is_empty() or arm_id.is_empty():
		return {"ok": false, "failure_code": "R23D11_GJT_ARGUMENTS_INVALID"}
	return {
		"ok": true,
		"command": String(args[0]),
		"stage_id": stage_id,
		"arm_id": arm_id,
	}
