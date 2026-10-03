extends SceneTree
# gdlint: disable=max-line-length
const Session := preload("res://sdk/adapters/godot/gdscript/r10de_reference_session_v1.gd")
const Source := Session.Source
const Bridge := Session.Bridge
const Transport := Session.Transport
const BINDING := "res://sdk/development/recovery_candidates/r10dd-native-reference-core-v1.runtime.json"
const EXTENSION := "res://sdk/adapters/godot/development_candidate_runtimes/r10dd-native-reference-core-v1.gdextension"
var checks := {}
var packets: Array = []
var outcome_packets: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3 or FileAccess.file_exists(args[2]): quit(1); return
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BINDING))
	checks.runtime = "sha256:" + FileAccess.get_sha256(binding.runtime.path) == binding.runtime.raw_sha256
	checks.local_runtime = "sha256:" + FileAccess.get_sha256("res://" + binding.local_build_path) == binding.runtime.raw_sha256
	checks.fixtures = "sha256:" + FileAccess.get_sha256(args[0]) == binding.compiled_fixtures.raw_sha256
	var input_binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/core/contracts/r10dd_native_reference_inputs_v1.json"))
	checks.original_inputs = "sha256:" + FileAccess.get_sha256(args[1]) == input_binding.fixture.raw_sha256
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old): checks.unload = GDExtensionManager.unload_extension(old) == GDExtensionManager.LOAD_STATUS_OK
	checks.load = GDExtensionManager.load_extension(EXTENSION) == GDExtensionManager.LOAD_STATUS_OK
	if checks.values().has(false): _finish(args[2]); return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixtures := {}
	for line in FileAccess.get_file_as_string(args[0]).split("\n"):
		var offset := line.find("R10DD_NATIVE_FIXTURE ")
		if offset >= 0:
			var row: Dictionary = sdk.decode_exact_json_v1(line.substr(offset + "R10DD_NATIVE_FIXTURE ".length()))
			fixtures[row.id] = row
	var inputs: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[1]))
	checks.population = fixtures.size() == 5 and inputs.step_requests.size() == 237
	if not checks.population: _finish(args[2]); return
	var prior := Session.execute_v1(sdk, fixtures.partial_entry.request)
	checks.entry = prior.ok and prior.action == "command" and Session._same(prior.native_receipt, fixtures.partial_entry.expected)
	if not checks.entry: _finish(args[2]); return
	packets.append(prior)
	var template: Dictionary = fixtures.reference_observation_1.request.collection
	for index in range(237):
		# In-memory synthetic copies only: owner, command, supervisor memory and
		# binding are generated here. Original physical reports remain immutable.
		var request: Dictionary = inputs.step_requests[index].duplicate(true)
		request.schema_version = Session.STEP
		request.step.memory = prior.task_memory.duplicate(true)
		request.reference_memory = prior.reference_memory
		request.step.observation.controller_ownership.recovery_controller_id = Source.RECOVERY
		request.step.observation.applied_actuation.command_sha256 = prior.next_control.command_sha256
		request.collection = template.duplicate(true)
		request.collection.phase = request.step.memory.phase
		request.collection.observation = request.step.observation.duplicate(true)
		var v2: Dictionary = request.collection.observation
		v2.schema_version = template.observation.schema_version
		for key in ["schema_version", "equation_id", "component_partition_id"]:
			v2.energy_balance[key] = template.observation.energy_balance[key]
		v2.energy_balance.erase("cumulative_signed_discrete_staging_exchange_j")
		var base := v2.duplicate(true)
		base.erase("schema_version")
		base.erase("energy_balance")
		var source_binding: Dictionary = request.collection.observation_source_binding
		source_binding.observation_base_sha256 = Source._sha(sdk, base)
		source_binding.ledger_sha256 = Source._sha(sdk, v2.energy_balance)
		source_binding.portable_observation_sha256 = Source._sha(sdk, v2)
		source_binding.erase("source_chain_sha256")
		source_binding.source_chain_sha256 = Source._sha(sdk, source_binding)
		var context := {"morphology_context": request.collection.morphology_context, "capability": request.collection.adapter_capability, "runtime_binding": request.collection.runtime_binding}
		var bound := {"observation_v2": v2, "observation_v3": request.step.observation, "source_binding": source_binding}
		var energy := {"energy_increment": request.step.energy_increment, "global_totals": request.step.native_global_energy}
		var before := Transport.stringify(bound)
		var assembled := Bridge.step_request_v1(context, bound, request.step.declaration, request.step.memory, energy, prior.reference_memory)
		checks["request_" + str(index)] = Session._same(assembled, request) and before == Transport.stringify(bound)
		if index == 0:
			var refused := Bridge.step_v1(sdk, context, "missing-synthetic-energy-source", bound, request.step.declaration, request.step.memory)
			checks.missing_source = refused.get("ok") == false and refused.get("call") == null
		if index == 1:
			for defect in ["memory", "reference", "clock", "command"]:
				var bad := request.duplicate(true)
				match defect:
					"memory": bad.step.memory.phase_steps_observed += 1
					"reference": bad.reference_memory.last_planned_reference_tick += 1
					"clock": bad.step.observation.semantic_step += 1
					"command": bad.step.observation.applied_actuation.command_sha256 = "sha256:" + "0".repeat(64)
				var refused := Session.execute_v1(sdk, bad, prior)
				checks["chain_refusal_" + defect] = refused.get("ok") == false and refused.get("call") == null
		var result := Session.execute_v1(sdk, assembled, prior)
		checks["native_" + str(index)] = result.ok
		if not result.ok:
			print("R10DE_FAILED_PACKET ", Transport.stringify(result))
			_finish(args[2]); return
		var id := "reference_observation_" + str(index + 1)
		if fixtures.has(id): checks[id] = Session._same(result.native_receipt, fixtures[id].expected)
		if index < 236:
			checks["command_" + str(index)] = result.action == "command" and result.reference_memory.last_planned_reference_tick == index + 1
			var application := {"ok": true, "semantic_step": int(result.next_control.semantic_step) + 1,
				"phase": result.next_control.phase, "command_sha256": result.next_control.command_sha256,
				"controller_owner": "recovery", "recovery_controller_id": Source.RECOVERY, "stance_controller_id": null,
				"fallback_controller_active": false, "zero_command": false, "physical_acceptance_authority": false, "release_authority": false}
			var tagged := Source.bind_application_v1(sdk, result.native_receipt, application)
			checks["bind_" + str(index)] = tagged.get("ok") == true
			if tagged.get("ok") == true:
				var selected := Source.select_v1(sdk, {Source.KEY: tagged.model_binding}, tagged.application, application.semantic_step)
				checks["select_" + str(index)] = selected.get("ok") == true and selected.get("partial_task_selected") == true
			if index == 1:
				for defect in ["tick", "finished", "target", "owner", "authority"]:
					var bad: Dictionary = result.native_receipt.duplicate(true)
					match defect:
						"tick": bad.reference_memory.last_planned_reference_tick += 1
						"finished": bad.reference_memory.finished = true
						"target": bad.next_reference.ordered_target_positions_rad[0] += 0.001
						"owner": bad.next_control.controller_id = "crossed"
						"authority": bad.physical_acceptance_authority = true
					checks["source_refusal_" + defect] = Source.control_context_v1(sdk, bad).get("ok") == false
		else:
			checks.stop = result.action == "stop" and result.next_control == null and result.task_memory.phase == "raise_body"
			checks.stop_cannot_apply = Source.control_context_v1(sdk, result.native_receipt).get("ok") == false
			checks.stop_cannot_restart = Session.execute_v1(sdk, assembled, result).get("call") == null
		packets.append(result)
		prior = result
	var transcript_path: String = args[2] + ".packets.jsonl"
	var transcript := FileAccess.open(transcript_path, FileAccess.WRITE)
	if transcript == null: quit(1); return
	for packet in packets:
		transcript.store_line(Transport.stringify(packet))
	transcript.close()
	var decoded_packets: Array = []
	for line in FileAccess.get_file_as_string(transcript_path).split("\n", false):
		decoded_packets.append(sdk.decode_exact_json_v1(line))
	checks.serialized_packets_exact = Session._same(decoded_packets, packets)
	checks.full_replay = Session.replay_v1(sdk, decoded_packets).get("ok") == true
	checks.missing_final_refused = Session.replay_v1(sdk, packets.slice(0, -1)).get("ok") == false
	var damaged: Array = packets.duplicate(true)
	damaged[-1].diagnostic_stop_reason = "recovery_success"
	checks.relabelled_stop_refused = Session.replay_v1(sdk, damaged).get("ok") == false
	damaged = packets.slice(0, 2).duplicate(true)
	damaged[1].call.response.utf8_text += " "
	checks.response_bytes_refused = Session.replay_v1(sdk, damaged, false).get("ok") == false
	var early_request: Dictionary = fixtures.reference_observation_2.request.duplicate(true)
	var observed: Dictionary = early_request.step.observation
	observed.state.base_pose_world.position_m.y = 0.8
	observed.state.base_pose_world.orientation_xyzw = {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0}
	observed.center_of_mass.position_world_m.y = 0.8
	for body in observed.ordered_body_clearance_observations:
		body.minimum_nonfoot_clearance_m = 0.1
		body.accumulated_nonfoot_normal_impulse_ns = 0.0
		body.nonfoot_contact_present = false
		body.ventral_surface_contact = false
		body.engine_contact_ids = []
	_rebind_synthetic_v2(sdk, early_request.collection, observed)
	var early := Session.execute_v1(sdk, early_request, packets[1])
	checks.early_transition_stops = early.get("ok") == true and early.get("action") == "stop" and early.get("diagnostic_stop_reason") == "original_supervisor_phase_transition"
	checks.early_transition_no_command = early.get("next_control") == null and early.get("task_memory", {}).get("phase") == "stance_handoff"
	checks.early_transition_replays = Session.replay_v1(sdk, packets.slice(0, 2) + [early]).get("ok") == true
	var rejected_request: Dictionary = fixtures.partial_entry.request.duplicate(true)
	var entry_observed: Dictionary = rejected_request.entry.original_request.passive_request.observation
	entry_observed.state.ordered_joint_observations[0].position_rad += 0.0001
	_rebind_synthetic_v2(sdk, rejected_request.collection, entry_observed)
	var rejected := Session.execute_v1(sdk, rejected_request)
	outcome_packets = [early, rejected]
	checks.entry_mismatch_no_command = rejected.get("ok") == false and rejected.get("action") == "refuse" and rejected.get("next_control") == null and rejected.get("call", {}).get("compiled_call_count") == 1
	checks.native_refusal_replays = Session.replay_v1(sdk, [rejected]).get("ok") == true
	_finish(args[2])

func _rebind_synthetic_v2(sdk: Object, collection: Dictionary, observed: Dictionary) -> void:
	var original: Dictionary = collection.observation
	var v2 := observed.duplicate(true)
	v2.schema_version = original.schema_version
	for key in ["schema_version", "equation_id", "component_partition_id"]:
		v2.energy_balance[key] = original.energy_balance[key]
	v2.energy_balance.erase("cumulative_signed_discrete_staging_exchange_j")
	collection.observation = v2
	var base := v2.duplicate(true)
	base.erase("schema_version")
	base.erase("energy_balance")
	var binding: Dictionary = collection.observation_source_binding
	binding.observation_base_sha256 = Source._sha(sdk, base)
	binding.ledger_sha256 = Source._sha(sdk, v2.energy_balance)
	binding.portable_observation_sha256 = Source._sha(sdk, v2)
	binding.erase("source_chain_sha256")
	binding.source_chain_sha256 = Source._sha(sdk, binding)

func _finish(output: String) -> void:
	var result := {"ok": not checks.is_empty() and not checks.values().has(false), "checks": checks,
		"outcome_packets": outcome_packets,
		"packet_count": packets.size(), "fixture_kind": "synthetic_original_numeric_inputs_with_explicit_source_rebinding",
		"world_build_count": 0, "solver_step_count": 0, "physical_worker_integrated": false,
		"physical_acceptance_authority": false, "release_authority": false}
	var stream := FileAccess.open(output, FileAccess.WRITE)
	if stream == null: quit(1); return
	stream.store_string(Transport.stringify(result))
	stream.close()
	print("R10DE_SESSION ", JSON.stringify({"ok": result.ok, "checks": checks.size(), "packets": packets.size()}))
	quit(0 if result.ok else 1)
