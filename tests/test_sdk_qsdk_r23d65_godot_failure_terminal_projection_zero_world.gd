extends SceneTree

const WorkerScript := preload(
	"res://tests/test_sdk_qsdk_r23d65_godot_jolt_physical_worker.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)


func _initialize() -> void:
	var cell := WorkerScript._r23d65_cell(
		WorkerScript.R23D65_STAGE_ID,
		WorkerScript.R23D65_ONSET_ID,
		WorkerScript.R23D65_CAMPAIGN_SEED,
		WorkerScript.R23D65_PROFILE_ID,
		"positive_heading",
	)
	var receipt := WorkerScript._r23d65_complete_terminal_identity(
		{
			"schema_version": WorkerScript.R23D65_FAILURE_SCHEMA,
			"failure_code": "QSDK_R23D48_SYNTHETIC_AFTER_WORLD_FAILURE",
			"failure_stage": "settlement_complete",
			"model_construction_count": 1,
			"world_attempt_count": 1,
			"world_build_count": 1,
		},
		cell,
		"1111111111111111111111111111111111111111",
	)
	var exact := (
		bool(cell.get("ok", false))
		and String(receipt.get("schema_version", ""))
		== WorkerScript.R23D65_FAILURE_SCHEMA
		and String(receipt.get("campaign_id", ""))
		== WorkerScript.R23D65_CAMPAIGN_ID
		and String(receipt.get("gate_id", "")) == WorkerScript.R23D65_GATE_ID
		and String(receipt.get("stage_id", "")) == WorkerScript.R23D65_STAGE_ID
		and String(receipt.get("cell_id", "")) == String(cell["cell_id"])
		and String(receipt.get("engine_id", "")) == WorkerScript.R23D65_ENGINE_ID
		and int(receipt.get("campaign_seed", -1))
		== WorkerScript.R23D65_CAMPAIGN_SEED
		and String(receipt.get("profile_id", "")) == WorkerScript.R23D65_PROFILE_ID
		and String(receipt.get("host_mapping_id", ""))
		== WorkerScript.R23D65_HOST_MAPPING_ID
		and String(receipt.get("arm_id", "")) == "positive_heading"
		and float(receipt.get("turn_heading_offset_rad", INF)) == 0.2
		and String(receipt.get("source_commit", ""))
		== "1111111111111111111111111111111111111111"
		and String(receipt.get("failure_code", ""))
		== "QSDK_R23D65_SYNTHETIC_AFTER_WORLD_FAILURE"
		and int(receipt.get("model_construction_count", -1)) == 1
		and int(receipt.get("world_attempt_count", -1)) == 1
		and int(receipt.get("world_build_count", -1)) == 1
		and not bool(receipt.get("physical_acceptance_authority", true))
	)
	if not exact:
		push_error("QSDK-R23D65 Godot failure terminal projection changed")
		quit(1)
		return
	print(
		"QSDK_R23D65_GODOT_FAILURE_TERMINAL_PROJECTION_ZERO_WORLD ",
		JsonTransportScript.stringify(
			{
				"schema_version": (
					"sporespore_qsdk_r23d65_godot_failure_terminal_"
					+ "projection_zero_world_v1"
				),
				"campaign_id": WorkerScript.R23D65_CAMPAIGN_ID,
				"gate_id": WorkerScript.R23D65_GATE_ID,
				"engine_id": WorkerScript.R23D65_ENGINE_ID,
				"complete_identity_projection_canary_count": 1,
				"world_count_preservation_canary_count": 1,
				"observed_model_construction_count_preserved": 1,
				"observed_world_attempt_count_preserved": 1,
				"observed_world_build_count_preserved": 1,
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		),
	)
	quit(0)
