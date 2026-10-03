extends "res://tests/test_sdk_qsdk_r23d71_godot_jolt_worker.gd"

## Compact zero-world exercise of the actual R23D71 Godot success-terminal
## rebranding function. This overrides the physical worker entrypoint and feeds
## one synthetic production-shaped completed terminal directly to the real
## post-physics function.


func _initialize() -> void:
	call_deferred("_run_success_terminal_ghost")


func _fail_ghost(message: String) -> void:
	printerr("QSDK_R23D71_GODOT_SUCCESS_TERMINAL_GHOST_FAILURE ", message)
	quit(1)


func _run_success_terminal_ghost() -> void:
	var cell := {
		"cell_id": "r23d71__godot_jolt__s23191__reference_zero",
		"engine_id": "godot_jolt",
		"campaign_seed": 23191,
		"profile_id": R23D71_PROFILE_ID,
		"host_mapping_id": R23D71_HOST_MAPPING_ID,
		"arm_id": "reference_zero",
		"turn_heading_offset_rad": 0.0,
	}
	var terminal := _r23d71_terminal(
		{
			"schema_version": R23D48_REPORT_SCHEMA,
			"execution": {
				"world_attempt_count": 1,
				"world_build_count": 1,
			},
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
		},
		cell,
		"1111111111111111111111111111111111111111",
	)
	if (
		String(terminal.get("schema_version", "")) != R23D71_REPORT_SCHEMA
		or typeof(terminal.get("execution")) != TYPE_DICTIONARY
		or int(terminal["execution"].get("world_attempt_count", -1)) != 1
		or int(terminal["execution"].get("world_build_count", -1)) != 1
		or terminal.has("model_construction_count")
		or terminal.has("world_attempt_count")
		or terminal.has("world_build_count")
	):
		_fail_ghost("SUCCESS_TERMINAL_SHAPE_INVALID")
		return
	print(
		"QSDK_R23D71_GODOT_SUCCESS_TERMINAL_GHOST ",
		R23D71JsonTransportScript.stringify(
			{
				"terminal": terminal,
				"actual_producer_function": "_r23d71_terminal",
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		),
	)
	quit(0)
