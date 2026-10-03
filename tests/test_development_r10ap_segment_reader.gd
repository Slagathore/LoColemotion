extends SceneTree
# gdlint: disable=max-line-length
const Reader := preload("res://sdk/adapters/godot/gdscript/r10ap_recovery_replay_v1.gd")
const Original := preload("res://sdk/adapters/godot/gdscript/r10am_recovery_replay_v1.gd")
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
var checks := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not preload("res://tests/r10ap_gate_runtime.gd").select_v1(): quit(3); return
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var profile := {"extension": "res://sdk/adapters/godot/development_candidate_runtimes/r10ap-progressive-headroom-core-v1.gdextension", "runtime_binding": "res://sdk/development/recovery_candidates/r10ap-progressive-headroom-core-v1.runtime.json"}
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old):
		checks["unload"] = GDExtensionManager.unload_extension(old) == GDExtensionManager.LOAD_STATUS_OK
	checks["load"] = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixture: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	var binding: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(profile.runtime_binding))
	var context := Route.prepare_complete_energy_context_v18(sdk, Route.RECOVERY_CONTROLLER_V6_ID)
	checks["context"] = context.get("ok") == true
	var selection := {"post_kick_controller_id": Reader.R10AP.CONTROLLER,
		"diagnostic_schedule": {"walking_policy_id": Reader.R10AP.ROUTE,
			"limits": {"after_interaction_steps": 3400, "maximum_steps_per_child": 3752}}}
	var retention := {"schema_version": "sporespore_r10ap_recovery_entry_retention_v1",
		"runtime_binding": binding, "candidate_profile": null,
		"canonical_initialization_permitted_before_prone": false, "energy_epoch_reset_permitted_at_handoff": false,
		"physical_acceptance_authority": false, "release_authority": false,
		"entry_packets": fixture.entry_packets, "canonical_packets": [],
		"orchestrator_transitions": fixture.transitions.slice(1), "first_recovery_owned_application": {},
		"maximum_passive_descent_steps": 240, "after_interaction_steps": 3400,
		"setup_controller_id": Route.RECOVERY_CONTROLLER_V6_ID,
		"post_kick_controller_id": Reader.R10AP.CONTROLLER, "post_kick_controller_context": {}}
	var partial := {"schema_version": "sporespore_r10ap_partial_recovery_retention_v1",
		"control_composition_id": Reader.PartialBridge.Source.COMPOSITION,
		"entry_kind": "partial", "declaration": fixture.entry_packets[-1].original_control_receipt.entry.partial_declaration,
		"final_memory": fixture.final_partial_memory, "step_packets": fixture.partial_packets,
		"first_partial_application": fixture.first_partial_application, "canonical_supervisor_synthesized": false,
		"source_observation_rewritten": false, "energy_epoch_reset": false,
		"physical_acceptance_authority": false, "release_authority": false}
	var upright := {"schema_version": "sporespore_r10v_upright_recovery_retention_v1", "entry_kind": "partial",
		"declaration": {}, "final_memory": {}, "step_packets": [], "first_upright_application": {},
		"partial_supervisor_synthesized": false, "canonical_supervisor_synthesized": false,
		"source_observation_rewritten": false, "energy_epoch_reset": false,
		"physical_acceptance_authority": false, "release_authority": false}
	var input := {"schema_version": "sporespore_r10ap_recovery_replay_input_v1", "retention": retention,
		"context": context, "initial_state": fixture.transitions[1].state_before, "final_state": fixture.final_state,
		"partial_retention": partial, "upright_retention": upright, "post_recovery_settling": {}}
	var replay := Reader.replay_v1(sdk, input, binding, Reader.R10AP.CONTROLLER, selection)
	checks["full_serialized_partial_segment"] = replay.get("ok") == true
	checks["all_entry_and_partial_sources"] = replay.get("entry_observation_count") == 240 and replay.get("partial_observation_count") == 63
	checks["all_transitions"] = replay.get("transition_count") == 303
	checks["no_canonical_history"] = replay.get("canonical_initialization_count") == 0 and replay.get("canonical_observation_count") == 0
	checks["segment_never_grants_full_route"] = replay.get("complete_route_proven") == false
	checks["legacy_reader_refuses_successor"] = Original.replay_v1(sdk, input, binding, Reader.R10AP.CONTROLLER, selection).get("ok") != true
	var original_schema: String = input.partial_retention.schema_version
	input.partial_retention.schema_version = "sporespore_r10v_partial_recovery_retention_v1"
	checks["old_partial_retention_refused"] = Reader.replay_v1(sdk, input, binding, Reader.R10AP.CONTROLLER, selection).get("failure_code") == "R10AP_RECOVERY_REPLAY_PARTIAL_RETENTION_SHAPE_OR_AUTHORITY"
	input.partial_retention.schema_version = original_schema
	var source: Dictionary = fixture.entry_packets[-1].native_receipt
	var packet: Dictionary = fixture.partial_packets[0]
	var state: Dictionary = fixture.transitions[241].state_before
	checks["actual_application_link"] = Reader._application_link(sdk, state, packet.source_application, packet.bound_observations,
		packet.prior_memory, {}, Reader.R10AP.CONTROLLER, 3752, source) == ""
	var crossed: Dictionary = packet.source_application.duplicate(true)
	crossed.recovery_controller_id = "sporespore_exact_s169_partial_support_anchored_controller_v27"
	checks["old_controller_application_refused"] = Reader._application_link(sdk, state, crossed, packet.bound_observations,
		packet.prior_memory, {}, Reader.R10AP.CONTROLLER, 3752, source) != ""
	crossed = packet.prior_memory.duplicate(true)
	crossed.last_semantic_step += 1
	checks["crossed_partial_memory_refused"] = Reader._application_link(sdk, state, packet.source_application, packet.bound_observations,
		crossed, {}, Reader.R10AP.CONTROLLER, 3752, source) != ""
	var result := {"ok": not checks.values().has(false), "checks": checks, "replay": replay,
		"synthetic_measurements_only": true, "full_report_checked": false,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(result) + "\n")
	file.close()
	sdk = null
	print("R10AP_SEGMENT_READER ", JSON.stringify(result))
	quit(0 if result.ok else 1)
