extends SceneTree
# gdlint: disable=max-line-length

## A fresh consumer process: no producer or worker is imported by this script.
const Replay := preload("res://sdk/adapters/godot/gdscript/r10r_recovery_replay_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_profile_resource_v1()))
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	var checks := {}
	if GDExtensionManager.is_extension_loaded(old): checks["unload"] = GDExtensionManager.unload_extension(old) == GDExtensionManager.LOAD_STATUS_OK
	checks["load"] = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixture: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	checks["producer_completed"] = fixture.ok == true and fixture.synthetic_measurements_only == true
	var selected: Dictionary = fixture.selection
	var input: Dictionary = fixture.input
	var result := Replay.replay_v1(sdk, input, fixture.expected_runtime_binding, selected.post_kick_controller_id, selected)
	checks["actual_retained_worker_replayed"] = result.get("ok") == true
	# Preflight mutations are deliberately cheap. Deeper command/epoch mutations
	# below exercise the same source validators used on every replayed packet.
	var changed := input.duplicate(false)
	changed["retention"] = input.retention.duplicate(false)
	changed.retention["energy_epoch_reset_permitted_at_handoff"] = true
	checks["energy_reset_permission_refused"] = Replay.replay_v1(sdk, changed, fixture.expected_runtime_binding, selected.post_kick_controller_id, selected).get("failure_code") == "R10R_RECOVERY_REPLAY_FORBIDDEN_PERMISSION:energy_epoch_reset_permitted_at_handoff"
	if fixture.branch != "legacy":
		changed = input.duplicate(false)
		changed["upright_retention"] = input.upright_retention.duplicate(false)
		changed.upright_retention["canonical_supervisor_synthesized"] = true
		checks["fabricated_prone_history_permission_refused"] = Replay.replay_v1(sdk, changed, fixture.expected_runtime_binding, selected.post_kick_controller_id, selected).get("failure_code") == "R10R_RECOVERY_REPLAY_UPRIGHT_RETENTION_SHAPE_OR_AUTHORITY"
		changed.upright_retention = input.upright_retention.duplicate(false)
		changed.upright_retention.partial_supervisor_synthesized = true
		checks["fabricated_partial_history_refused"] = not Replay._upright_retention_valid_v1(changed.upright_retention)
		changed.upright_retention = input.upright_retention.duplicate(false)
		changed.upright_retention.erase("final_memory")
		checks["missing_upright_final_memory_refused"] = Replay.replay_v1(sdk, changed, fixture.expected_runtime_binding, selected.post_kick_controller_id, selected).get("failure_code") == "R10R_RECOVERY_REPLAY_UPRIGHT_RETENTION_SHAPE_OR_AUTHORITY"
	if fixture.branch == "upright":
		# A retained prefix is a valid segment diagnostic. Mutations of its first
		# packet reach the real native replay without repeating the long tail.
		var prefix := input.duplicate(false)
		prefix.retention = input.retention.duplicate(false)
		prefix.retention.orchestrator_transitions = input.retention.orchestrator_transitions.slice(0, 2)
		prefix.retention.entry_packets = [input.retention.entry_packets[0]]
		prefix.final_state = prefix.retention.orchestrator_transitions[-1].advance.state_after
		prefix.upright_retention = input.upright_retention.duplicate(false)
		prefix.partial_retention = input.partial_retention.duplicate(false)
		prefix.partial_retention.entry_kind = "waiting"
		prefix.upright_retention.merge({"entry_kind": "waiting", "declaration": {}, "final_memory": {}, "first_upright_application": {}, "step_packets": []}, true)
		checks["retained_waiting_prefix_replays"] = Replay.replay_v1(sdk, prefix, fixture.expected_runtime_binding, selected.post_kick_controller_id, selected).get("ok") == true
		for field in ["request", "response"]:
			changed = prefix.duplicate(false)
			changed.retention = prefix.retention.duplicate(false)
			changed.retention.entry_packets = [prefix.retention.entry_packets[0].duplicate(true)]
			changed.retention.entry_packets[0].call[field].utf8_text = "{}"
			checks["altered_native_" + field + "_refused"] = Replay.replay_v1(sdk, changed, fixture.expected_runtime_binding, selected.post_kick_controller_id, selected).get("failure_code") == "R10R_RECOVERY_REPLAY_ENTRY_REPLAY_OR_BYTES_MISMATCH"
		changed = prefix.duplicate(false)
		changed.retention = prefix.retention.duplicate(false)
		changed.retention.entry_packets = [input.retention.entry_packets[1]]
		checks["reordered_entry_packet_refused"] = Replay.replay_v1(sdk, changed, fixture.expected_runtime_binding, selected.post_kick_controller_id, selected).get("failure_code") == "R10R_RECOVERY_REPLAY_APPLICATION_GLOBAL_STEP"
		changed = prefix.duplicate(false)
		changed.upright_retention = prefix.upright_retention.duplicate(false)
		changed.upright_retention.step_packets = [input.upright_retention.step_packets[0]]
		checks["unconsumed_upright_packet_refused"] = Replay.replay_v1(sdk, changed, fixture.expected_runtime_binding, selected.post_kick_controller_id, selected).get("failure_code") == "R10R_RECOVERY_REPLAY_UNCONSUMED_UPRIGHT_PACKET_OR_FINAL_MEMORY"
		var packets: Array = input.upright_retention.step_packets
		var packet: Dictionary = packets[0]
		var source: Dictionary = input.retention.entry_packets[-1].native_receipt
		var state: Dictionary = input.retention.orchestrator_transitions[241].state_before
		checks["first_upright_source_links_valid"] = Replay._application_link(sdk, state, packet.source_application,
			packet.bound_observations, packet.prior_memory, {}, selected.post_kick_controller_id, 3512, {}, source) == ""
		var application: Dictionary = packet.source_application.duplicate(true)
		application[Replay.UprightBridge.Source.KEY].memory_sha256 = "sha256:" + "0".repeat(64)
		checks["transplanted_upright_memory_refused"] = Replay._application_link(sdk, state, application,
			packet.bound_observations, packet.prior_memory, {}, selected.post_kick_controller_id, 3512, {}, source) != ""
		application = packet.source_application.duplicate(true)
		application.command_sha256 = "sha256:" + "0".repeat(64)
		checks["crossed_upright_command_refused"] = Replay._application_link(sdk, state, application,
			packet.bound_observations, packet.prior_memory, {}, selected.post_kick_controller_id, 3512, {}, source) != ""
		var raised: Dictionary = packets[1]
		var raised_state: Dictionary = input.retention.orchestrator_transitions[242].state_before
		var v12 := Replay.UprightBridge.Source.recovery_controller_for_phase_v1("raise_body")
		checks["raise_actual_v12_owner_links"] = Replay._application_link(sdk, raised_state, raised.source_application,
			raised.bound_observations, raised.prior_memory, {}, v12, 3512, {}, packets[0].native_receipt) == ""
		checks["raise_old_v20_owner_refused"] = Replay._application_link(sdk, raised_state, raised.source_application,
			raised.bound_observations, raised.prior_memory, {}, selected.post_kick_controller_id, 3512, {}, packets[0].native_receipt) != ""
		var old_source: Dictionary = packets[0].native_receipt.duplicate(true)
		old_source.schema_version = "sporespore_r10q_upright_step_control_receipt_v1"
		checks["raise_old_q_step_source_refused"] = Replay._application_link(sdk, raised_state, raised.source_application,
			raised.bound_observations, raised.prior_memory, {}, v12, 3512, {}, old_source) != ""
		var previous: Dictionary = input.retention.entry_packets[-1].bound_observations
		checks["continuous_kick_energy_epoch_valid"] = Replay._epoch_link(sdk, state, packet.bound_observations, previous) == ""
		var bound: Dictionary = packet.bound_observations.duplicate(true)
		bound.source_component_receipts.epoch_initializer.epoch_start_global_step += 1
		checks["reset_energy_epoch_refused"] = Replay._epoch_link(sdk, state, bound, previous) != ""
	var output := {"ok": not checks.values().has(false), "checks": checks, "replay": result,
		"branch": fixture.branch, "world_build_count": 0, "solver_step_count": 0,
		"complete_report_exercised": false, "physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(Transport.stringify(output) + "\n")
	file.close()
	sdk = null
	print("R10R_RECOVERY_READER ", JSON.stringify(output))
	quit(0 if output.ok else 1)

func _profile_resource_v1() -> String:
	return "res://sdk/development/recovery_candidates/r10r-v55-upright-integrated-v3.json"
