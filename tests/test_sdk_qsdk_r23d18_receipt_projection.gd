extends SceneTree

const Worker := preload("res://tests/test_sdk_qsdk_r23d18_godot_jolt_physical_worker.gd")
const MARKER := "QSDK_R23D18_GODOT_RECEIPT_PROJECTION "


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--receipt-path":
		print(MARKER, JSON.stringify({"ok": false, "failure_code": "ARGUMENTS_INVALID"}))
		quit(1)
		return
	var raw := FileAccess.get_file_as_string(String(args[1]))
	var parsed: Variant = JSON.parse_string(raw)
	var projection := Worker._r23d18_integer_receipt_projection(parsed)
	print(MARKER, JSON.stringify(projection))
	quit(0 if bool(projection.get("ok", false)) else 1)
