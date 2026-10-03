extends SceneTree
# gdlint: disable=max-line-length

## Source-only diagnosis of real orchestrator terminal branches, not physics.
## No worker, controller, facade, model or body is instantiated or stepped.
const Energy := preload("res://sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd")
const O := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1.gd"
)
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const MARKER := "QSDK_R10F_L14_NO_RESUME_BRANCH_DIAGNOSIS "
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var receipt := evaluate_v1()
	print(MARKER, Transport.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)


static func advance_v1(sdk: Object, state: Dictionary, fields: Dictionary) -> Dictionary:
	var projected := fields.duplicate(true)
	projected["global_semantic_step"] = int(state["previous_global_semantic_step"]) + 1
	projected["application_intent_sha256"] = "sha256:" + "9".repeat(64)
	var built := O.build_event_v1(sdk, state, projected)
	if built.get("ok") != true:
		return built
	return O.advance_v1(sdk, state, built["event"])


static func route_to_prone_confirmation_v1(sdk: Object) -> Dictionary:
	var initialized := (
		O
		. initialize_v1(
			sdk,
			"2".repeat(32),
			Energy.ACTIVE_ARM_ID,
			"synthetic-model-kick_passive_recovery_resume",
			"sha256:" + "f".repeat(64),
			"sha256:" + "b".repeat(64),
			0,
		)
	)
	if initialized.get("ok") != true:
		return initialized
	var state: Dictionary = initialized["state"]
	var events := [
		{
			"event_kind": "precondition_pair_ready",
			"control_owner": "recovery_v6",
			"actuation_owner": "recovery_v6",
			"recovery_actuation_applied": true,
			"stable_four_foot_stance": true,
			"recovery_controller_terminal_phase": "complete"
		},
		{
			"event_kind": "precondition_pair_release_step",
			"control_owner": "none",
			"actuation_owner": "none",
			"no_actuation_requested": true
		},
	]
	for fields in events:
		var advanced := advance_v1(sdk, state, fields)
		if advanced.get("ok") != true:
			return advanced
		state = advanced["state_after"]
	for local_step in range(1, O.WALKING_PREFIX_STEPS + 1):
		var advanced := advance_v1(
			sdk,
			state,
			{
				"event_kind": "walking_policy_step",
				"control_owner": "walking_bw5r_b",
				"actuation_owner": "walking_bw5r_b",
				"walking_actuation_applied": true,
				"walking_session_id": "synthetic-kick_passive_recovery_resume-walking_prefix",
				"walking_session_local_step": local_step,
			}
		)
		if advanced.get("ok") != true:
			return advanced
		state = advanced["state_after"]
	return advance_v1(
		sdk,
		state,
		{
			"event_kind": "kick_effect_step",
			"control_owner": "none",
			"actuation_owner": "none",
			"no_actuation_requested": true,
			"interaction_receipt_sha256": "sha256:" + "2".repeat(64),
			"energy_initializer_sha256": "sha256:" + "3".repeat(64),
			"kick_application_count": 1,
			"walking_motors_disabled_in_same_pre_solver_event": true,
		}
	)


static func evaluate_v1() -> Dictionary:
	if load(EXTENSION_PATH) == null or not ClassDB.class_exists(CLASS_NAME):
		return {"ok": false, "failure_code": "L14_DIAGNOSIS_CANONICALIZER_UNAVAILABLE"}
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	var entry := route_to_prone_confirmation_v1(sdk)
	if entry.get("ok") != true:
		return entry
	var confirm: Dictionary = entry["state_after"]
	var recovery := confirm.duplicate(true)
	for _index in range(O.REQUIRED_CONSECUTIVE_PRONE_SAMPLES):
		var advanced := advance_v1(
			sdk,
			recovery,
			{
				"event_kind": "passive_prone_observation",
				"control_owner": "recovery_v6",
				"actuation_owner": "none",
				"no_actuation_requested": true,
				"prone_sample": true,
				"energy_initializer_sha256": "sha256:" + "3".repeat(64),
				"recovery_epoch_local_step": int(recovery["recovery_epoch_step_count"]) + 1,
			}
		)
		if advanced.get("ok") != true:
			return advanced
		recovery = advanced["state_after"]
	var cases := []
	for case_id in [
		"confirm_prone_failed", "post_kick_recovery_failed", "post_kick_recovery_refused"
	]:
		var in_confirmation: bool = case_id == "confirm_prone_failed"
		var before := confirm.duplicate(true) if in_confirmation else recovery.duplicate(true)
		var terminal_kind := "refused" if case_id.ends_with("refused") else "failed"
		var terminal := advance_v1(
			sdk,
			before,
			{
				"event_kind":
				"passive_prone_observation" if in_confirmation else "recovery_controller_step",
				"control_owner": "recovery_v6",
				"actuation_owner": "none",
				"no_actuation_requested": true,
				"energy_initializer_sha256": "sha256:" + "3".repeat(64),
				"recovery_epoch_local_step": int(before["recovery_epoch_step_count"]) + 1,
				"recovery_controller_terminal_phase": terminal_kind,
				"recovery_controller_terminal_reason": "synthetic_declared_%s" % case_id,
			}
		)
		if terminal.get("ok") != true:
			return terminal
		var state: Dictionary = terminal["state_after"]
		var valid: bool = (
			O.state_valid_v1(sdk, state)
			and state["phase"] == O.PHASE_FAILED
			and state["terminal_outcome"] == "failed"
			and state["walking_resume_step_count"] == 0
			and state["resume_or_continuation_session_id"] == ""
			and state["walking_prefix_step_count"] == 720
			and state["interaction_effect_step_count"] == 1
			and state["precondition_pair_ready"] == true
			and state["precondition_pair_release_step_count"] == 1
		)
		cases.append(
			{
				"case_id": case_id,
				"ok": valid,
				"source_phase": before["phase"],
				"terminal_controller_kind": terminal_kind,
				"terminal_state": state,
				"required_completed_walking_sessions": ["walking_prefix"],
				"required_walking_actuation_handoffs": ["walking_prefix"],
				"resume_source_existed": false,
				"semantic_advance_receipt": terminal
			}
		)
	var passed := cases.size() == 3
	for case in cases:
		passed = passed and bool(case["ok"])
	sdk = null
	return {
		"schema_version": "sporespore_qsdk_r10f_l14_no_resume_branch_diagnosis_v1",
		"gate_id": "QSDK-R10F",
		"repair_id": "QSDK-R10F-L14",
		"ok": passed,
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_actual_orchestrator_branch_diagnosis",
			"question_class": "development"
		},
		"source_only_branch_count": cases.size(),
		"cases": cases,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
