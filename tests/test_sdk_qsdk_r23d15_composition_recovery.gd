extends SceneTree

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")


func _init() -> void:
	var receipt := WaveGaitScript.run_sdk_terminal_handoff_reason_canary()
	print("QSDK_R23D15_GODOT_COMPOSITION_RECOVERY ", JSON.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)
