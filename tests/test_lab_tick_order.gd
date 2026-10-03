extends SceneTree

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrameAssemblerScript := preload("res://scripts/lab/frame_assembler.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab tick-order contract ===")
	var assembler = FrameAssemblerScript.new("tick_order_run", 0)
	var body := {
		"body_id": "root",
		"position_m": Vector3.ZERO,
		"rotation_world": Quaternion.IDENTITY,
		"linear_velocity_m_s": Vector3.ZERO,
		"angular_velocity_rad_s": Vector3.ZERO,
		"mass_kg": 1.0,
		"finite": true,
		"sleeping": false,
	}
	var frame_0: Dictionary = assembler.assemble(
		0, 0.0, "post_step", "MEASURE", [body])
	var ledger = CommandLedgerScript.new()
	_check(ledger.begin_tick(0), "command ledger opens tick 0")
	var command: Dictionary = ledger.seal({
		"run_id": "tick_order_run",
		"command_id": 0,
		"source_frame_id": 0,
		"applied_transition": FrameAssemblerScript.transition_for_frame(0),
		"mode": "NONE",
	})
	body["position_m"] = Vector3(0.1, 0.0, 0.0)
	var frame_1: Dictionary = assembler.assemble(
		1, 1.0 / 60.0, "post_step", "MEASURE", [body])
	_check(int(frame_0["frame_id"]) == 0, "source frame is explicitly frame 0")
	_check(int(command["payload"]["source_frame_id"]) == 0, "command names source frame 0")
	_check(
		command["payload"]["applied_transition"] == [0, 1],
		"command 0 explicitly maps frame 0 to frame 1")
	_check(int(frame_1["frame_id"]) == 1, "post-step result is explicitly frame 1")
	_check(
		CanonicalJsonScript.sha256(command["payload"])
			== command["command_payload_sha256"],
		"command envelope hashes exactly its payload")
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
