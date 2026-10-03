extends SceneTree
# gdlint: disable=max-line-length

## Pure R61 control of the exact identity projection used by the physical
## contact sampler. No extension object, Node, RID, model, world, or step exists.

const WorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "QSDK_R24D61_GODOT_CONTACT_IDENTITY_PROJECTION_ZERO_WORLD "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var empty := WorldScript.native_contact_identity_projection_v1([])
	var unique := WorldScript.native_contact_identity_projection_v1(["shape_a:0|floor:0"])
	var duplicate := WorldScript.native_contact_identity_projection_v1(
		["shape_a:0|floor:0", "shape_a:0|floor:0"]
	)
	var stable := WorldScript.native_contact_identity_projection_v1(
		[
			"shape_a:0|floor:0",
			"shape_b:1|floor:0",
			"shape_a:0|floor:0",
			"shape_b:1|floor:0",
		]
	)
	var positives := [empty, unique, duplicate, stable]
	var positive_control_count := 0
	for result_value in positives:
		positive_control_count += int(bool((result_value as Dictionary).get("ok", false)))

	var mutations := [
		{"id": "non_string_identity", "raw": [7]},
		{"id": "empty_identity", "raw": [""]},
		{"id": "whitespace_identity", "raw": ["   "]},
	]
	var mutation_ids: Array = []
	var mutation_rejection_count := 0
	for mutation_value in mutations:
		var mutation: Dictionary = mutation_value
		var result := WorldScript.native_contact_identity_projection_v1(mutation["raw"])
		mutation_ids.append(String(mutation["id"]))
		mutation_rejection_count += int(not bool(result.get("ok", false)))

	var exact: bool = (
		positive_control_count == 4
		and String(duplicate.get("schema_version", ""))
		== "sporespore_qsdk_r24d61_godot_contact_identity_projection_v1"
		and int(duplicate.get("raw_contact_point_identity_count", -1)) == 2
		and int(duplicate.get("unique_shape_pair_identity_count", -1)) == 1
		and int(duplicate.get("duplicate_shape_pair_identity_count", -1)) == 1
		and duplicate.get("engine_contact_ids", []) == ["shape_a:0|floor:0"]
		and int(stable.get("raw_contact_point_identity_count", -1)) == 4
		and int(stable.get("unique_shape_pair_identity_count", -1)) == 2
		and int(stable.get("duplicate_shape_pair_identity_count", -1)) == 2
		and stable.get("engine_contact_ids", [])
		== ["shape_a:0|floor:0", "shape_b:1|floor:0"]
		and bool(stable.get("stable_first_observation_order_preserved", false))
		and not bool(stable.get("point_samples_modified", true))
		and not bool(stable.get("impulse_aggregation_modified", true))
		and mutation_rejection_count == mutations.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d61_godot_contact_identity_projection_zero_world_v1",
		"gate_id": "QSDK-R24D61",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D61_CONTACT_IDENTITY_PROJECTION_CONJUNCTION_INVALID",
		"positive_control_count": positive_control_count,
		"duplicate_consolidation_control_count": int(bool(duplicate.get("ok", false))),
		"stable_order_control_count": int(bool(stable.get("ok", false))),
		"raw_point_identity_count_preserved": int(stable.get("raw_contact_point_identity_count", -1)) == 4,
		"unique_shape_pair_identity_count": int(stable.get("unique_shape_pair_identity_count", -1)),
		"duplicate_shape_pair_identity_count": int(stable.get("duplicate_shape_pair_identity_count", -1)),
		"mutation_ids": mutation_ids,
		"mutation_rejection_count": mutation_rejection_count,
		"native_runtime_observation_collection_executed": false,
		"held_out_cell_access_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
