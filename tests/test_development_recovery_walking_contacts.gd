extends SceneTree
# gdlint: disable=max-line-length

const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Contact := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_contacts_v1.gd")
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
	var selected_id := Profile.walking_contact_id_v1(selection, "walking_resume")
	var checks := {"profile_loaded": not selection.is_empty() and not selected_id.is_empty()}
	if not checks["profile_loaded"]:
		quit(1)
		return
	# Explicit synthetic branch fixture, like the synthetic callback contacts
	# below. Keep the exact selected controller/runtime, but exercise the legacy
	# shape-contact path independently of the selected native-contact suite.
	# Probe._initialize never launches; no on-disk profile or schedule is edited.
	var id: String = Contact._contract["profile_id"]
	selection["diagnostic_schedule"]["walking_contact_profile_id"] = id
	if args.size() > 2:
		# The production retained-report reader uses this exact decoder, not
		# JSON.parse_string (which changes integer receipt fields to binary64).
		var reader_probe := Probe.new()
		reader_probe._candidate_selection = selection
		if reader_probe._r10k_selected_v1(): reader_probe._seed = 40741 if reader_probe._r10o_selected_v1() else 40641 if reader_probe._r10n_selected_v1() else 40541 if reader_probe._r10m_selected_v1() else 40441 if reader_probe._r10l_selected_v1() else 40341 # Explicit zero-world prefix preflight.
		reader_probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(selection["worker_selection"]["binding"]))
		if not reader_probe._load_runtime_extension_v1():
			reader_probe.free()
			quit(1)
			return
		var reader_sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
		var cases: Dictionary = reader_sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[2]))
		var results := {}
		for key in cases:
			results[key] = Contact.validate_report_v1(cases[key], id)
		print("DEVELOPMENT_WALKING_CONTACT_READER ", Transport.stringify(results))
		reader_sdk = null
		reader_probe.free()
		quit(0)
		return
	var floor := StaticBody3D.new()
	floor.set_meta("lab_body_id", "floor")
	var limbs := []
	# Uninserted component objects only: the real recovery shape constructor
	# and real semantic observer, with explicitly synthetic callback samples.
	for limb_id in Contact._contract["ordered_limb_ids"]:
		var body := Body.new()
		var shape_id: String = limb_id + "_distal"
		body.name = shape_id
		body.set_meta("lab_body_id", shape_id)
		var shape: Dictionary = Facade.RecoveryWorld._body_shape({"collision": {"kind": "capsule", "radius_m": 0.03, "length_m": 0.15}}, shape_id)
		body.add_child(shape["shape_node"])
		body.semantic_contact_callback_count = 1
		body.latest_semantic_contacts[shape_id + "|floor"] = true
		body.latest_semantic_contact_samples.append({"local_shape_id": shape_id, "counterparty_id": "floor",
			"local_shape_index": 0, "collider_shape_index": 0, "local_position_world_m": Vector3.ZERO,
			"local_normal_world_unit": Vector3.UP, "relative_velocity_world_m_s": Vector3.ZERO})
		limbs.append({"limb_id": limb_id, "foot": body})
	var binding := {"limbs": limbs, "floor": floor}
	var adapter := Adapter.new()
	checks["reproduces_historical_false_contact"] = not Adapter._walking_contact_observation("front_left_foot", limbs[0], floor)["presence"] and not adapter._stability_contact_state("front_left_foot", limbs[0], floor)["contact"]["presence"]
	checks["real_shape_binding"] = Contact.bind_v1(binding, id).get("ok") == true
	for limb in limbs:
		var site: String = limb["limb_id"] + "_foot"
		var request := Adapter._walking_contact_observation(site, limb, floor)
		var stability: Dictionary = adapter._stability_contact_state(site, limb, floor)
		checks["all_three_consumers_" + site] = request["presence"] and request["bears_support"] and request["provenance"]["engine_contact_ids"].size() == 1 and stability["qualified"] and stability["contact"]["engine_contact_ids"] == request["provenance"]["engine_contact_ids"]
	var fourth: RigidBody3D = limbs[3]["foot"]
	var collision: CollisionShape3D = fourth.get_child(0)
	for mode in ["crossed_shape", "disabled_shape", "missing_callback", "crossed_body", "crossed_floor"]:
		for limb in limbs:
			limb.erase("contact_shape_id")
		if mode == "crossed_shape": collision.set_meta("lab_shape_id", "front_left_distal")
		if mode == "disabled_shape": collision.disabled = true
		if mode == "missing_callback": fourth.set("semantic_contact_callback_count", 0)
		if mode == "crossed_body": fourth.set_meta("lab_body_id", "front_left_distal")
		if mode == "crossed_floor": floor.set_meta("lab_body_id", "other")
		checks["refuses_" + mode] = Contact.bind_v1(binding, id).get("ok") == false and limbs.all(func(limb: Dictionary): return not limb.has("contact_shape_id"))
		collision.set_meta("lab_shape_id", "rear_right_distal")
		collision.disabled = false
		fourth.set("semantic_contact_callback_count", 1)
		fourth.set_meta("lab_body_id", "rear_right_distal")
		floor.set_meta("lab_body_id", "floor")
	checks["rebind_after_negative_controls"] = Contact.bind_v1(binding, id).get("ok") == true
	var first: RigidBody3D = limbs[0]["foot"]
	first.set("latest_semantic_contacts", {})
	first.set("latest_semantic_contact_samples", [] as Array[Dictionary])
	checks["actual_absence_stays_absent"] = not Adapter._walking_contact_observation("front_left_foot", limbs[0], floor)["presence"] and not adapter._stability_contact_state("front_left_foot", limbs[0], floor)["contact"]["presence"]
	first.set("latest_semantic_contacts", {"foot|floor": true})
	checks["historical_default_stays_foot"] = Adapter._foot_bears_floor({"foot": first}, floor) and not Adapter._foot_bears_floor(limbs[0], floor)
	first.set("latest_semantic_contacts", {}) # Keep one real absence in retained synthetic inputs.
	var probe := Probe.new()
	probe._candidate_selection = selection
	if probe._r10k_selected_v1(): probe._seed = 40741 if probe._r10o_selected_v1() else 40641 if probe._r10n_selected_v1() else 40541 if probe._r10m_selected_v1() else 40441 if probe._r10l_selected_v1() else 40341 # Explicit zero-world prefix preflight.
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(selection["worker_selection"]["binding"]))
	checks["runtime_loaded"] = probe._load_runtime_extension_v1()
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk") if checks["runtime_loaded"] else null
	var report := {"retained_arm": {"trace_rows": [], "walking_sessions": []}}
	if sdk != null:
		probe._sdk = sdk
		for segment in ["walking_prefix", "walking_resume"]:
			checks["worker_selects_" + segment] = probe._walking_contact_profile_id_v1(segment) == id
			var facade := Facade.new()
			var frame := Facade.DevelopmentWalkingFrame.frame_v1(Basis.IDENTITY, segment, probe._walking_frame_id_v1(segment))
			var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID)["profile"]
			checks["starts_" + segment] = facade._start_adapter_from_frame_v1(frame, Vector3.ZERO, Facade.initial_gait_steps_v1(40200, segment), material, true).get("ok") == true
			var native: RefCounted = facade._adapter
			report["configuration"] = {"base_descriptor": native._descriptor.duplicate(true)}
			var state: Dictionary = native._perfect_synthetic_controller_state_frame(1, native._compiled["morphology"])
			var supports := []
			state["ordered_contact_observations"] = []
			for limb in limbs:
				var site: String = limb["limb_id"] + "_foot"
				state["ordered_contact_observations"].append(Adapter._walking_contact_observation(site, limb, floor))
				supports.append(adapter._stability_contact_state(site, limb, floor)["contact"])
			var command: Dictionary = native._perfect_synthetic_motion_command(1, probe._walking_phase_progression_mode_v1(segment, 1))
			command["gait_amplitude"] = probe._walking_gait_amplitude_v1(segment, 1)
			var request: Dictionary = native._controller_step_request(native._memory.duplicate(true), state, command)
			var response: Dictionary = native._call_balanced_wave_session_step_with_transport_verification(request, 1)
			checks["native_step_" + segment] = response.get("ok") == true
			if response.get("ok") != true:
				print("DEVELOPMENT_CONTACT_NATIVE_FAILURE ", Transport.stringify(response))
				break
			var stability: Dictionary = native._perfect_synthetic_stability_state(1, native._compiled["morphology"])
			stability["ordered_support_contacts"] = supports
			var applications := []
			for output_command in response["value"]["actuation"]["ordered_commands"]:
				applications.append({"actuator_id": output_command["actuator_id"], "host_applied_target_velocity_rad_s": output_command["target_velocity_rad_s"]})
			var global_step := 1 if segment == "walking_prefix" else 806
			var step := {"ok": true, "session_id": segment, "global_semantic_step": global_step, "session_local_step": 1,
				"sample_receipt": {"request": request, "stability_shadow": {"stability_state": stability}, "development_contact_sources": Contact.sources_v1(limbs)},
				"portable_step_receipt": {"native_output": response["value"], "native_step_transport_verification": response["native_step_transport_verification"]},
				"authority_application_receipt": {"ordered_applications": applications}}
			var digest: String = probe._canonical_sha256_v1(step)
			var retained: Dictionary = probe._retain_development_walking_source_v1(segment, step, digest)
			checks["worker_retains_" + segment] = retained.get("ok") == true
			if retained.get("ok") != true:
				print("DEVELOPMENT_CONTACT_REJECTED_STEP ", Transport.stringify({"failure": retained, "step": step}))
			report["retained_arm"]["trace_rows"].append({"walking_segment_id": segment, "walking_session_id": segment, "walking_session_local_step": 1, "global_semantic_step": global_step})
			report["retained_arm"]["walking_sessions"].append({"session_id": segment, "step_receipt_sha256s": [digest], "start_receipt": {"development_walking_contact_profile_id": id}})
			native.shutdown()
			facade._adapter = null
		probe._attach_entry_retention_v1(report)
		checks["contact_reader"] = Contact.validate_report_v1(report, id).get("ok") == true
		checks["native_resume_replay"] = Profile.WalkingEntry.validate_report_v1(sdk, report, Profile.walking_entry_id_v1(selection, "walking_resume")).get("ok") == true
		checks["old_profile_rejects_new_retention"] = Contact.validate_report_v1(report, "").get("ok") == false
		var timed: Array = report["development_walking_contacts"]["rows"].duplicate(true)
		checks["nonzero_timeout_never_labeled_zero"] = false
		if not timed.is_empty():
			timed[-1]["native_limb_memory"][0]["gate_timeout_count"] = 2
			var diagnosis: Dictionary = Contact.retention_v1(timed, id)["terminal_timeout_diagnostics_by_session"]["walking_resume"]
			checks["nonzero_timeout_never_labeled_zero"] = diagnosis["actual_native_gate_timeout_total"] == 2 and diagnosis["actual_native_contact_gating_without_timeout"] == false and diagnosis["original_evaluator_replaced"] == false
	probe._sdk = null
	sdk = null
	probe.free()
	for limb in limbs:
		limb["foot"].free()
	floor.free()
	var ok := not checks.values().has(false)
	print("DEVELOPMENT_WALKING_CONTACT_CHECKS ", Transport.stringify({"ok": ok, "checks": checks, "report": report,
		"selected_contact_profile_id": selected_id, "synthetic_contact_profile_id": id,
		"selected_runtime_binding": selection["candidate"]["runtime_binding"],
		"synthetic_legacy_contact_branch": true, "on_disk_candidate_profile_modified": false,
		"synthetic_callback_samples": true, "uninserted_component_body_count": 4, "model_construction_count": 0,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	quit(0 if ok else 1)
