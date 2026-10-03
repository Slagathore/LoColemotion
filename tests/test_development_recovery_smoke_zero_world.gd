extends SceneTree
# gdlint: disable=max-line-length

const Prior := preload("res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd")
const Smoke := preload("res://sdk/adapters/godot/gdscript/development_recovery_smoke_worker_v1.gd")
const Orchestrator := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1.gd"
)
const Evaluator := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v2.gd"
)
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const MARKER := "DEVELOPMENT_SMOKE_ZERO_WORLD "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var native := Prior._evaluate_v1(true)
	if native.get("ok") != true:
		print(MARKER, Transport.stringify({"ok": false, "native": native}))
		quit(1)
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var checks := {}
	var state: Dictionary = (
		Orchestrator
		. initialize_v1(
			sdk,
			"synthetic-smoke-schedule",
			"kick_passive_recovery_resume",
			"synthetic-model",
			"sha256:" + "a".repeat(64),
			"sha256:" + "b".repeat(64)
		)["state"]
	)
	for fields in [
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
	]:
		fields["global_semantic_step"] = int(state["previous_global_semantic_step"]) + 1
		fields["application_intent_sha256"] = "sha256:" + "c".repeat(64)
		var event := Orchestrator.build_event_v1(sdk, state, fields)
		state = Orchestrator.advance_v1(sdk, state, event["event"])["state_after"]
	var official := state.duplicate(true)
	var before: Dictionary = {}
	var last_event: Dictionary = {}
	for step in range(1, 31):
		var fields := {
			"event_kind": "walking_policy_step",
			"global_semantic_step": step + 2,
			"control_owner": "walking_bw5r_b",
			"actuation_owner": "walking_bw5r_b",
			"walking_actuation_applied": true,
			"walking_session_id": "synthetic-prefix",
			"walking_session_local_step": step,
			"application_intent_sha256": "sha256:" + "d".repeat(64)
		}
		before = state.duplicate(true)
		last_event = Orchestrator.build_event_v1(sdk, state, fields)["event"]
		state = Orchestrator.advance_development_smoke_v1(sdk, state, last_event)["state_after"]
		official = Orchestrator.advance_v1(sdk, official, last_event)["state_after"]
	checks["smoke_interaction_after_30"] = state["phase"] == Orchestrator.PHASE_INTERACTION
	checks["official_still_walking_at_30"] = official["phase"] == Orchestrator.PHASE_WALKING_PREFIX
	checks["official_prefix_stays_720"] = Orchestrator.WALKING_PREFIX_STEPS == 720
	var bad := last_event.duplicate(true)
	bad["global_semantic_step"] = 99
	checks["smoke_preserves_corruption_refusal"] = (
		Orchestrator.advance_development_smoke_v1(sdk, before, bad).get("ok") == false
	)
	checks["official_preserves_corruption_refusal"] = (
		Orchestrator.advance_v1(sdk, before, bad).get("ok") == false
	)
	var limit := {
		"phase": Orchestrator.PHASE_PRECONDITION_RECOVERY,
		"precondition_recovery_step_count": 319,
		"precondition_pair_ready": false,
		"epoch_start_global_step": null
	}
	checks["setup_319_continues"] = Smoke.diagnostic_stop_reason_v1(limit, 319).is_empty()
	limit["precondition_recovery_step_count"] = 320
	checks["setup_320_stops"] = not Smoke.diagnostic_stop_reason_v1(limit, 320).is_empty()
	limit["precondition_pair_ready"] = true
	checks["ready_at_320_may_release"] = Smoke.diagnostic_stop_reason_v1(limit, 320).is_empty()
	checks["total_cap_stops"] = not Smoke.diagnostic_stop_reason_v1(limit, 382).is_empty()
	limit["epoch_start_global_step"] = 100
	checks["after_29_continues"] = Smoke.diagnostic_stop_reason_v1(limit, 129).is_empty()
	checks["after_30_stops"] = not Smoke.diagnostic_stop_reason_v1(limit, 130).is_empty()
	var evidence := Prior._walking_evaluation_fixture_v1()
	evidence["expected_step_count"] = 30
	evidence["rows"] = (evidence["rows"] as Array).slice(0, 30)
	evidence["completion_receipt"]["adapter_summary"]["step_count"] = 30
	evidence["completion_receipt"]["adapter_summary"]["validated_balanced_wave_command_count"] = 240
	evidence["completion_receipt"]["adapter_summary"]["native_actuation_application_count"] = 240
	var diagnostic := Evaluator.evaluate_development_smoke_segment_v1(sdk, evidence)
	checks["short_diagnostic_valid"] = diagnostic.get("ok") == true
	checks["short_diagnostic_no_conclusion"] = (
		diagnostic.get("behavioral_conclusion") == "none"
		and diagnostic.get("development_smoke_only") == true
	)
	var unhashed := diagnostic.duplicate(true)
	unhashed["payload_sha256"] = ""
	checks["diagnostic_digest_covers_final_label"] = (
		diagnostic["payload_sha256"] == Evaluator._sha256_v1(sdk, unhashed)
	)
	checks["official_rejects_short_walking"] = (
		Evaluator.evaluate_segment_v2(sdk, evidence).get("ok") == false
	)
	evidence["completion_receipt"]["adapter_shutdown_receipt"]["explicit_shutdown_completed"] = "true"
	checks["diagnostic_rejects_bad_shutdown"] = (
		Evaluator.evaluate_development_smoke_segment_v1(sdk, evidence).get("ok") == false
	)
	var ok := not checks.values().has(false)
	print(
		MARKER,
		Transport.stringify(
			{
				"ok": ok,
				"checks": checks,
				"native": native,
				"diagnostic_evaluation": diagnostic,
				"model_construction_count": 0,
				"world_build_count": 0,
				"solver_step_count": 0,
				"physical_acceptance_authority": false,
				"release_authority": false
			}
		)
	)
	quit(0 if ok else 1)
