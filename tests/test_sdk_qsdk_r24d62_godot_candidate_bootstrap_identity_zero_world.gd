extends SceneTree
# gdlint: disable=max-line-length

## Pure R62 controls of the bootstrap-arm identity projection used by the
## physical Godot initializer. No extension object, Node, RID, model, world,
## solver step, or physics mutation exists.

const WorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "QSDK_R24D62_GODOT_CANDIDATE_BOOTSTRAP_IDENTITY_ZERO_WORLD "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var candidate := WorldScript.native_bootstrap_arm_identity_v1(
		"candidate_command"
	)
	var matched_zero := WorldScript.native_bootstrap_arm_identity_v1(
		"matched_zero_command"
	)
	var mutation_ids := ["empty_arm", "abbreviated_candidate", "case_mutation"]
	var mutation_values := ["", "candidate", "Candidate_Command"]
	var mutation_rejection_count := 0
	for arm_kind in mutation_values:
		var receipt := WorldScript.native_bootstrap_arm_identity_v1(arm_kind)
		mutation_rejection_count += int(not bool(receipt.get("ok", false)))

	var candidate_exact := (
		bool(candidate.get("ok", false))
		and String(candidate.get("arm_kind", "")) == "candidate_command"
		and not bool(candidate.get("zero_command", true))
		and bool(candidate.get("no_actuation_requested", false))
		and String(candidate.get("controller_owner", "")) == "recovery"
		and String(candidate.get("recovery_controller_id", ""))
		== "sporespore_exact_s169_prone_to_standing_controller_v1"
		and candidate.get("stance_controller_id", "unexpected") == null
		and String(candidate.get("command_schema_version", ""))
		== "sporespore_qsdk_r24d62_godot_initializer_candidate_bootstrap_v1"
		and String(candidate.get("command_id", ""))
		== "r24d62_godot_initializer_candidate_bootstrap_step_1"
	)
	var matched_zero_exact := (
		bool(matched_zero.get("ok", false))
		and String(matched_zero.get("arm_kind", "")) == "matched_zero_command"
		and bool(matched_zero.get("zero_command", false))
		and bool(matched_zero.get("no_actuation_requested", false))
		and String(matched_zero.get("controller_owner", "")) == "none"
		and matched_zero.get("recovery_controller_id", "unexpected") == null
		and matched_zero.get("stance_controller_id", "unexpected") == null
		and String(matched_zero.get("command_schema_version", ""))
		== "sporespore_qsdk_r24d62_godot_initializer_matched_zero_v1"
		and String(matched_zero.get("command_id", ""))
		== "r24d62_godot_initializer_matched_zero_step_1"
	)
	var exact := (
		candidate_exact
		and matched_zero_exact
		and candidate != matched_zero
		and mutation_rejection_count == mutation_values.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d62_godot_candidate_bootstrap_identity_zero_world_v1",
		"gate_id": "QSDK-R24D62",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D62_BOOTSTRAP_IDENTITY_CONJUNCTION_INVALID",
		"positive_control_count": int(candidate_exact) + int(matched_zero_exact),
		"candidate_control_count": int(candidate_exact),
		"matched_zero_control_count": int(matched_zero_exact),
		"candidate_zero_command": bool(candidate.get("zero_command", true)),
		"candidate_no_actuation_requested": bool(
			candidate.get("no_actuation_requested", false)
		),
		"matched_zero_zero_command": bool(matched_zero.get("zero_command", false)),
		"matched_zero_no_actuation_requested": bool(
			matched_zero.get("no_actuation_requested", false)
		),
		"arm_identities_distinct": candidate != matched_zero,
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
