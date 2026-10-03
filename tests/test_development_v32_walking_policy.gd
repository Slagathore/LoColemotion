extends SceneTree
# gdlint: disable=max-line-length

const Facade := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd")
const Entry := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_entry_v1.gd")
const Prior := preload("res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const Policy := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_policy_v1.gd")
const COMPONENT := "res://sdk/development/recovery_candidates/v32-swing-end-recontact-v1.json"
var selected_policy_id: String = Policy.POLICY_ID
var test_label: String = "V32"

class RuntimeProbe:
	extends "res://sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd"
	var profile_path: String = ""
	func _initialize() -> void:
		pass
	func _entry_selection_v1() -> Dictionary:
		var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
		return {"binding": profile["runtime_binding"], "extension": profile["extension"]}

func _initialize() -> void:
	var component_path := COMPONENT
	var args: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--component-profile="):
			component_path = argument.trim_prefix("--component-profile=")
		elif argument.begins_with("--walking-policy="):
			selected_policy_id = argument.trim_prefix("--walking-policy=")
		elif argument.begins_with("--test-label="):
			test_label = argument.trim_prefix("--test-label=")
		else:
			args.append(argument)
	var component: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(component_path))
	var probe := RuntimeProbe.new()
	probe.profile_path = component_path
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(component["runtime_binding"]))
	var checks := {"bound_runtime_and_legacy_prefix_preflight": probe._load_runtime_extension_v1()}
	if not checks["bound_runtime_and_legacy_prefix_preflight"]:
		probe.free()
		_finish(checks, {})
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	if args.size() == 1:
		var input: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
		var results := {}
		for name in input:
			results[name] = Entry.validate_report_v1(sdk, input[name]["report"], Entry._contract["profile_id"], "", input[name]["policy_id"])
		print(test_label + "_WALKING_POLICY_READER ", Transport.stringify(results))
		probe.free()
		quit(0)
		return
	var binding := Policy.binding_v1(selected_policy_id, "walking_resume")
	checks["new_identity_distinct"] = binding.get("policy_id") == selected_policy_id and binding.get("policy_digest") != Facade.SELECTED_POLICY_DIGEST
	for segment in ["", "walking_prefix", "matched_continuation"]:
		checks["new_policy_refuses_" + segment] = Policy.binding_v1(selected_policy_id, segment).is_empty()
	checks["unknown_refuses"] = Policy.binding_v1("unknown", "walking_resume").is_empty()
	var fixtures := {}
	for id in ["", selected_policy_id]:
		var name := "legacy" if id.is_empty() else "new"
		var fixture := Prior._walking_ledger_production_fixture_v2(sdk, 900, "walking_resume", "walking_resume", "walking_resume", test_label.to_lower() + "-zero-world-" + name, id, true)
		fixtures[name] = fixture
		checks[name + "_real_motor_application_and_ledger"] = fixture.get("ok") == true
		if fixture.get("ok") != true:
			continue
		var handoff: Dictionary = fixture["walking_actuation_handoff_receipt"]
		checks[name + "_correct_handoff_reader"] = Facade.walking_actuation_handoff_receipt_valid_v1(sdk, handoff, id)
		checks[name + "_crossed_handoff_reader_refuses"] = not Facade.walking_actuation_handoff_receipt_valid_v1(sdk, handoff, selected_policy_id if id.is_empty() else "")
		for field in ["selected_policy_id", "selected_policy_digest", "evaluation_segment_id"]:
			var changed := handoff.duplicate(true)
			changed[field] = "walking_prefix" if field == "evaluation_segment_id" else "crossed"
			changed["payload_sha256"] = ""
			changed["payload_sha256"] = Facade._sha256_v1(sdk, changed)
			checks[name + "_refuses_rehashed_" + field] = not Facade.walking_actuation_handoff_receipt_valid_v1(sdk, changed, id)
		var crossed := Facade.walking_ledger_application_intent_v2(sdk, 900, "walking_resume", fixture["session_id"], 1,
			fixture["portable_step_receipt"], fixture["authority_application_receipt"], fixture["motor_population_readback"], handoff, selected_policy_id if id.is_empty() else "")
		checks[name + "_crossed_ledger_refuses"] = crossed.get("ok") == false
		# Rehash the transport metadata so rejection must enforce the selected
		# policy's receipt format, not merely detect a stale payload checksum.
		var changed_portable: Dictionary = fixture["portable_step_receipt"].duplicate(true)
		var changed_transport: Dictionary = changed_portable["native_step_transport_verification"]
		changed_transport["controller_receipt_schema_version"] = (
			Facade.SELECTED_CONTROLLER_RECEIPT_SCHEMA if id == Policy.SUPPORT_POLICY_ID
			else Facade.SdkAdapterScript.DEVELOPMENT_BOUNDED_SUPPORT_RECEIPT_SCHEMA)
		changed_transport["payload_sha256"] = ""
		changed_transport["payload_sha256"] = Facade.SdkAdapterScript.CanonicalJsonScript.sha256(changed_transport)
		var crossed_transport := Facade.walking_ledger_application_intent_v2(sdk, 900, "walking_resume", fixture["session_id"], 1,
			changed_portable, fixture["authority_application_receipt"], fixture["motor_population_readback"], handoff, id)
		checks[name + "_rehashed_wrong_native_receipt_format_refuses"] = crossed_transport.get("ok") == false and "identity.native_transport_verification_valid" in crossed_transport.get("failed_predicate_ids", [])
		checks[name + "_no_world_or_bodies"] = fixture["world_build_count"] == 0 and fixture["body_construction_count"] == 0 and fixture["solver_step_count"] == 0
	var facade := Facade.new()
	var frame := Facade.DevelopmentWalkingFrame.frame_v1(Basis.IDENTITY, "walking_resume", "anatomical_plus_x_horizontal_resume_v1")
	var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID)["profile"]
	var phases := {"front_left": 90, "front_right": 90, "rear_left": 90, "rear_right": 90}
	checks["facade_rejects_prefix_before_adapter_creation"] = facade._start_adapter_from_frame_v1(frame, Vector3.ZERO, phases, material, true, selected_policy_id, "walking_prefix").get("ok") == false and facade._adapter == null
	checks["default_extension_cannot_select_new_policy"] = facade._start_adapter_from_frame_v1(frame, Vector3.ZERO, phases, material, false, selected_policy_id).get("failure_code") == "ADAPTER_DEVELOPMENT_POLICY_RUNTIME_REQUIRED"
	var started := facade._start_adapter_from_frame_v1(frame, Vector3.ZERO, phases, material, true, selected_policy_id)
	checks["actual_facade_starts_new_native_session"] = started.get("ok") == true
	var report := {}
	if started.get("ok") == true:
		var adapter: RefCounted = facade._adapter
		if selected_policy_id == Policy.SUPPORT_POLICY_ID:
			checks["support_memory_schema_accepted"] = adapter.preflight_balanced_wave_memory_schema_receipt(adapter._memory).get("ok") == true
			checks["support_reference_initialized"] = adapter._memory.get("support_reference", {}).get("ordered_target_positions_rad", []).size() == 8
			var crossed_memory: Dictionary = adapter._memory.duplicate(true)
			crossed_memory["schema_version"] = adapter.BALANCED_WAVE_MEMORY_VERSION
			checks["legacy_memory_schema_refused"] = adapter.preflight_balanced_wave_memory_schema_receipt(crossed_memory).get("ok") == false
		var session := {"session_id": test_label.to_lower() + "-pure-sequence", "evaluation_segment_id": "walking_resume", "step_receipt_sha256s": [],
			"start_receipt": {"development_walking_policy_id": selected_policy_id, "selected_policy_id": selected_policy_id, "selected_policy_digest": binding["policy_digest"]}}
		var trace := []
		var rows := []
		var held := false
		for step in range(1, 201):
			var state: Dictionary = adapter._perfect_synthetic_controller_state_frame(step, adapter._compiled["morphology"])
			for contact in state["ordered_contact_observations"]:
				contact["presence"] = false
				contact["bears_support"] = false
				contact["provenance"]["engine_contact_ids"] = []
			var command: Dictionary = adapter._perfect_synthetic_motion_command(step, "contact_gated")
			# Exercise the existing base entry reader independently of the not-yet
			# runnable V32 candidate. This is synthetic interface coverage only.
			command["gait_amplitude"] = Entry.amplitude_v1(step, Entry._contract["profile_id"])
			var request: Dictionary = adapter._controller_step_request(adapter._memory.duplicate(true), state, command)
			var response: Dictionary = adapter._call_balanced_wave_session_step_with_transport_verification(request, step)
			if response.get("ok") != true:
				checks["native_sequence_valid"] = false
				break
			var output: Dictionary = response["value"]
			adapter._memory = output["next_memory"].duplicate(true)
			for limb in adapter._memory["ordered_limb_memory"]:
				if limb["limb_id"] == "front_left" and limb["gait_step"] == 162 and limb["recontact_hold_step_count"] > 0:
					held = true
			var pure := request.duplicate(true)
			pure["schema_version"] = "sporespore_balanced_wave_policy_step_request_v1"
			pure["descriptor"] = Facade.RecoveryRoute.exact_base_descriptor_v1()
			pure["policy_id"] = selected_policy_id
			var raw: String = sdk.balanced_wave_policy_step_json(Transport.stringify(pure))
			var raw_sha: String = response["native_step_transport_verification"]["raw_native_response_sha256"]
			if raw_sha != "sha256:" + raw.sha256_text():
				checks["actual_session_equals_pure_native_bytes"] = false
			var digest := "sha256:" + Transport.stringify({"step": step, "request": request, "output": output}).sha256_text()
			var applications := []
			for motor in output["actuation"]["ordered_commands"]:
				applications.append({"actuator_id": motor["actuator_id"], "host_applied_target_velocity_rad_s": motor["target_velocity_rad_s"]})
			rows.append({"schema_version": Entry._contract["step_schema"], "session_id": session["session_id"], "commanded_global_step": 900 + step,
				"measured_global_step": 899 + step, "session_local_step": step, "request": request, "native_output": output,
				"ordered_body_states": [{}, {}, {}, {}, {}, {}, {}, {}, {}], "ordered_motor_applications": applications,
				"full_step_receipt_sha256": digest, "raw_native_response_sha256": raw_sha})
			session["step_receipt_sha256s"].append(digest)
			trace.append({"walking_segment_id": "walking_resume", "walking_session_local_step": step, "walking_session_id": session["session_id"], "global_semantic_step": 900 + step})
		report = {"configuration": {"base_descriptor": Facade.RecoveryRoute.exact_base_descriptor_v1()}, "retained_arm": {"walking_sessions": [session], "trace_rows": trace},
			"development_walking_entry": Entry.retention_v1(rows, Entry._contract["profile_id"])}
		checks["200_consecutive_new_policy_commands"] = rows.size() == 200
		checks["real_adapter_recontact_at_swing_end"] = held
		checks["same_process_native_reader"] = Entry.validate_report_v1(sdk, report, Entry._contract["profile_id"], "", selected_policy_id).get("ok") == true
		checks["new_profile_cannot_masquerade_as_legacy"] = not Policy.native_profile_valid_v1(adapter._controller_profile, adapter._controller_profile, selected_policy_id)
		checks["session_shutdown"] = adapter.shutdown().get("ok") == true
		facade._adapter = null
	probe.free()
	_finish(checks, {"fixtures": fixtures, "report": report, "adapter_start": started})

func _finish(checks: Dictionary, result: Dictionary) -> void:
	print(test_label + "_WALKING_POLICY_PRODUCER ", Transport.stringify({"ok": not checks.values().has(false), "checks": checks, "result": result,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	quit(0 if not checks.values().has(false) else 1)
