extends SceneTree
# gdlint: disable=max-line-length

const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Contact := preload("res://sdk/adapters/godot/gdscript/development_recovery_native_walking_contacts_v1.gd")
const ShapeContact := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_contacts_v1.gd")
const Facade := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd")
const Body := preload("res://scripts/lab/mechanics/semantic_contact_rigid_body.gd")
const Adapter := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

class Probe:
	extends "res://sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd"
	func _initialize() -> void:
		pass

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var selection := Profile.load_v1({"resource": args[0], "raw_sha256": args[1]})
	var id := Profile.walking_contact_id_v1(selection, "walking_resume")
	var probe := Probe.new()
	probe._candidate_selection = selection
	if probe._r10k_selected_v1(): probe._seed = 40741 if probe._r10o_selected_v1() else 40641 if probe._r10n_selected_v1() else 40541 if probe._r10m_selected_v1() else 40441 if probe._r10l_selected_v1() else 40341 # Explicit zero-world prefix preflight.
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(selection["worker_selection"]["binding"]))
	if not probe._load_runtime_extension_v1():
		probe.free()
		quit(1)
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	probe._sdk = sdk
	var fixture: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[2]))
	if args.size() > 3:
		var results := {}
		for key in fixture:
			results[key] = Contact.validate_report_v1(sdk, fixture[key])
		print("DEVELOPMENT_NATIVE_WALKING_CONTACT_READER ", Transport.stringify(results))
		probe._sdk = null
		sdk = null
		probe.free()
		quit(0)
		return
	var checks := {"selected_native_profile": Contact.selected_v1(id), "retained_not_reconstructed": fixture.get("synthetic_bridge") == true and fixture.get("original_global_request_reconstructed") == false}
	var floor := StaticBody3D.new()
	floor.set_meta("lab_body_id", "floor")
	var limbs := []
	for limb_id in Contact._contract["ordered_limb_ids"]:
		var body := Body.new()
		var shape_id: String = limb_id + "_distal"
		body.name = shape_id
		body.set_meta("lab_body_id", shape_id)
		var shape: Dictionary = Facade.RecoveryWorld._body_shape({"collision": {"kind": "capsule", "radius_m": 0.03, "length_m": 0.15}}, shape_id)
		body.add_child(shape["shape_node"])
		body.semantic_contact_callback_count = 1
		limbs.append({"limb_id": limb_id, "foot": body})
	var population := "sha256:" + "1".repeat(64)
	var binding := {"model_instance_id": "synthetic_bridge_model", "limbs": limbs, "floor": floor}
	checks["actual_shape_binding"] = ShapeContact.bind_v1(binding, ShapeContact._contract["profile_id"]).get("ok") == true
	var adapter := Adapter.new()
	var arm := {"model_instance_id": binding["model_instance_id"], "body_population_instance_sha256": population, "trace_rows": [], "walking_sessions": []}
	var report := {"retained_arm": arm}
	var observed_native_absence := false
	for segment in ["walking_prefix", "walking_resume"]:
		var facade := Facade.new()
		var frame := Facade.DevelopmentWalkingFrame.frame_v1(Basis.IDENTITY, segment, probe._walking_frame_id_v1(segment))
		var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID)["profile"]
		checks["starts_" + segment] = facade._start_adapter_from_frame_v1(frame, Vector3.ZERO, Facade.initial_gait_steps_v1(40200, segment), material, true).get("ok") == true
		var native: RefCounted = facade._adapter
		report["configuration"] = {"base_descriptor": native._descriptor.duplicate(true)}
		var digests := []
		for local_step in [1, 2]:
			var measured: int = (380 if segment == "walking_prefix" else 840) + local_step - 1
			var bound: Dictionary = sdk.decode_exact_json_v1(fixture["bounds"][str(measured)])
			var observation: Dictionary = bound["observation_v3"]
			var components: Dictionary = bound["source_component_receipts"]["rotation_aware_source_component_receipts"]
			var contact_source: Dictionary = components["contact_source_receipt"]
			# Retained epoch observation in a SYNTHETIC global bridge container.
			# The real global walking input was not retained in V20.
			arm["last_collection"] = {"global_result": {"bound": {"observation_v3": observation}, "measurement": {"source_component_receipts": components}}}
			var pre := {"global_semantic_step": measured, "body_population_instance_sha256": population,
				"observation_sha256": probe._canonical_sha256_v1(observation), "contact_by_limb": {}}
			for index in range(4):
				pre["contact_by_limb"][Contact._contract["ordered_limb_ids"][index]] = observation["state"]["ordered_contact_observations"][index]["bears_support"]
			if local_step == 1:
				arm["trace_rows"].append(pre)
			else:
				pre.merge({"walking_segment_id": segment, "walking_session_id": segment, "walking_session_local_step": local_step - 1})
				arm["trace_rows"][-1] = pre
			var source: Dictionary = probe._walking_native_contact_source_v1(arm, segment)
			checks["actual_source_hook_%s_%d" % [segment, local_step]] = Contact.source_valid_v1(sdk, source, measured + 1, binding["model_instance_id"], population)
			for limb in limbs:
				var foot: RigidBody3D = limb["foot"]
				var shape_id: String = limb["limb_id"] + "_distal"
				foot.set("semantic_contact_callback_count", measured)
				foot.set("latest_semantic_contacts", {shape_id + "|floor": true})
				var samples: Array[Dictionary] = []
				for point in contact_source["ordered_contact_samples"]:
					if point["body_id"] == shape_id:
						var position: Dictionary = point["position_world_m"]
						samples.append(_sample(shape_id, point["engine_contact_id"], Vector3(position["x"], position["y"], position["z"])))
				# An extra geometrical contact must not acquire native foot support.
				samples.append(_sample(shape_id, "synthetic_unloaded_contact", Vector3.ZERO))
				foot.set("latest_semantic_contact_samples", samples)
				limb.erase("native_qualified_contact")
				limb.erase("native_qualified_contact_samples")
			if segment == "walking_prefix" and local_step == 1:
				for mode in ["stale_step", "future_step", "crossed_model", "crossed_population", "source_hash", "missing_native_point", "stale_callback"]:
					var bad: Dictionary = source.duplicate(true)
					var commanded := measured + 1
					var first: RigidBody3D = limbs[0]["foot"]
					var saved: Array = first.get("latest_semantic_contact_samples").duplicate(true)
					if mode == "stale_step": commanded += 1
					if mode == "future_step": commanded -= 1
					if mode == "crossed_model": bad["model_instance_id"] = "crossed"
					if mode == "crossed_population": bad["body_population_instance_sha256"] = "crossed"
					if mode == "source_hash": bad["contact_source_sha256"] = "crossed"
					if mode == "missing_native_point": first.set("latest_semantic_contact_samples", [] as Array[Dictionary])
					if mode == "stale_callback": first.set("semantic_contact_callback_count", measured - 1)
					checks["refuses_atomically_" + mode] = Contact.prepare_v1(sdk, bad, binding, commanded, population).get("ok") == false and limbs.all(func(limb: Dictionary): return not limb.has("native_qualified_contact"))
					first.set("latest_semantic_contact_samples", saved)
					first.set("semantic_contact_callback_count", measured)
			checks["prepare_%s_%d" % [segment, local_step]] = Contact.prepare_v1(sdk, source, binding, measured + 1, population).get("ok") == true
			var state: Dictionary = native._perfect_synthetic_controller_state_frame(local_step, native._compiled["morphology"])
			var supports := []
			state["ordered_contact_observations"] = []
			for index in range(4):
				var limb: Dictionary = limbs[index]
				var site: String = limb["limb_id"] + "_foot"
				var contact := Adapter._walking_contact_observation(site, limb, floor)
				var stability: Dictionary = adapter._stability_contact_state(site, limb, floor)
				checks["native_contact_%s_%d_%s" % [segment, local_step, site]] = Transport.stringify(contact) == Transport.stringify(observation["state"]["ordered_contact_observations"][index]) and stability["contact"]["presence"] == contact["presence"] and stability["contact"]["engine_contact_ids"] == contact["provenance"]["engine_contact_ids"] and stability["contact"]["bears_support"] == contact["bears_support"]
				observed_native_absence = observed_native_absence or (not contact["bears_support"] and limb["foot"].get("latest_semantic_contacts").size() > 0)
				state["ordered_contact_observations"].append(contact)
				supports.append(stability["contact"])
			var command: Dictionary = native._perfect_synthetic_motion_command(local_step, probe._walking_phase_progression_mode_v1(segment, local_step))
			command["gait_amplitude"] = probe._walking_gait_amplitude_v1(segment, local_step)
			var request: Dictionary = native._controller_step_request(native._memory.duplicate(true), state, command)
			var response: Dictionary = native._call_balanced_wave_session_step_with_transport_verification(request, local_step)
			checks["native_step_%s_%d" % [segment, local_step]] = response.get("ok") == true
			if response.get("ok") != true:
				print("DEVELOPMENT_NATIVE_CONTACT_RESPONSE_FAILURE ", Transport.stringify(response))
				break
			native._memory = response["value"]["next_memory"].duplicate(true)
			var stability_state: Dictionary = native._perfect_synthetic_stability_state(local_step, native._compiled["morphology"])
			stability_state["ordered_support_contacts"] = supports
			var applications := []
			for output_command in response["value"]["actuation"]["ordered_commands"]:
				applications.append({"actuator_id": output_command["actuator_id"], "host_applied_target_velocity_rad_s": output_command["target_velocity_rad_s"]})
			var step := {"ok": true, "session_id": segment, "global_semantic_step": measured + 1, "session_local_step": local_step,
				"sample_receipt": {"request": request, "stability_shadow": {"stability_state": stability_state}, "development_native_contact_source": source},
				"portable_step_receipt": {"native_output": response["value"], "native_step_transport_verification": response["native_step_transport_verification"]},
				"authority_application_receipt": {"ordered_applications": applications}}
			var digest: String = probe._canonical_sha256_v1(step)
			digests.append(digest)
			checks["worker_retains_%s_%d" % [segment, local_step]] = probe._retain_development_walking_source_v1(segment, step, digest).get("ok") == true
			arm["trace_rows"].append({"walking_segment_id": segment, "walking_session_id": segment, "walking_session_local_step": local_step, "global_semantic_step": measured + 1})
		arm["walking_sessions"].append({"session_id": segment, "step_receipt_sha256s": digests, "start_receipt": {"development_walking_contact_profile_id": id}})
		native.shutdown()
		facade._adapter = null
	arm.erase("last_collection")
	probe._attach_entry_retention_v1(report)
	checks["geometric_contact_does_not_invent_support"] = observed_native_absence
	var reader := Contact.validate_report_v1(sdk, report)
	checks["actual_native_contact_reader"] = reader.get("ok") == true
	checks["actual_resume_command_reader"] = Profile.WalkingEntry.validate_report_v1(sdk, report, Profile.walking_entry_id_v1(selection, "walking_resume")).get("ok") == true
	probe._sdk = null
	sdk = null
	probe.free()
	for limb in limbs:
		limb["foot"].free()
	floor.free()
	var ok := not checks.values().has(false)
	print("DEVELOPMENT_NATIVE_WALKING_CONTACT_CHECKS ", Transport.stringify({"ok": ok, "checks": checks, "reader": reader, "report": report,
		"synthetic_bridge_and_callback_geometry": true, "original_global_request_reconstructed": false,
		"uninserted_component_body_count": 4, "model_construction_count": 0, "world_build_count": 0,
		"solver_step_count": 0, "additional_native_physics_read_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	quit(0 if ok else 1)

func _sample(shape_id: String, engine_id: String, point: Vector3) -> Dictionary:
	return {"local_shape_id": shape_id, "counterparty_id": "floor", "engine_contact_id": engine_id,
		"local_shape_index": 0, "collider_shape_index": 0, "local_position_world_m": point,
		"local_normal_world_unit": Vector3.UP, "relative_velocity_world_m_s": Vector3.ZERO}
