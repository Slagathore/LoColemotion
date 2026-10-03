extends "res://tests/test_sdk_qsdk_r23d74_godot_jolt_worker.gd"

## Zero-world exercise of the actual Godot/Jolt R23D74 terminal normalizer.


func _initialize() -> void:
	call_deferred("_run_success_terminal_ghost")


func _fail_ghost(message: String) -> void:
	printerr("QSDK_R23D74_GODOT_SUCCESS_TERMINAL_GHOST_FAILURE ", message)
	quit(1)


func _run_success_terminal_ghost() -> void:
	var cell := {
		"cell_id": "r23d74__godot_jolt__s23193__reference_zero",
		"engine_id": "godot_jolt",
		"campaign_seed": 23193,
		"profile_id": R23D74_PROFILE_ID,
		"host_mapping_id": R23D74_HOST_MAPPING_ID,
		"arm_id": "reference_zero",
		"turn_heading_offset_rad": 0.0,
	}
	var terminal := _r23d74_terminal(
		{
			"schema_version": R23D48_REPORT_SCHEMA,
			"trace_artifact": {
				"trace_transport_id": R23D74_TRACE_TRANSPORT_ID,
				"trace_transport_engine_id": R23D74_ENGINE_ID,
				"canonical_ndjson": true,
				"full_precision": true,
				"byte_length": 0,
			},
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
		String(terminal.get("schema_version", "")) != R23D74_REPORT_SCHEMA
		or String(terminal.get("question_class", "")) != "finite_decision"
		or typeof(terminal.get("execution")) != TYPE_DICTIONARY
		or int(terminal["execution"].get("world_attempt_count", -1)) != 1
		or int(terminal["execution"].get("world_build_count", -1)) != 1
		or typeof(terminal.get("trace_artifact", {}).get("byte_length")) != TYPE_INT
		or terminal.has("model_construction_count")
		or terminal.has("world_attempt_count")
		or terminal.has("world_build_count")
	):
		_fail_ghost("SUCCESS_TERMINAL_SHAPE_INVALID")
		return
	print(
		"QSDK_R23D74_GODOT_SUCCESS_TERMINAL_GHOST ",
		R23D74JsonTransportScript.stringify(
			{
				"terminal": terminal,
				"actual_producer_function": "_r23d74_terminal",
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		),
	)
	quit(0)
