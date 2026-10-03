extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"
## Counterfactual native commands on frozen observations. No creature or solver step.
const EntrySource := preload("res://sdk/adapters/godot/gdscript/recovery_walking_entry_source_v1.gd")
const EntryReplay := preload("res://sdk/adapters/godot/gdscript/recovery_stance_entry_replay_v1.gd")
const Facade := EntryReplay.Facade
const Route := EntryReplay.Route

static func same_json_value_v1(a: Variant, b: Variant) -> bool:
	# V50's legacy host parser retains some zero counters as 0.0; Rust writes 0.
	# JSON numeric value equality is exact here; no tolerance or field is omitted.
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return float(a) == float(b) and absf(float(a)) <= 9007199254740991.0
	if typeof(a) != typeof(b): return false
	if a is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same_json_value_v1(a[key], b[key]): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not same_json_value_v1(a[index], b[index]): return false
		return true
	return a == b

func _dispatch(sdk: Object, input: Dictionary, _binding: Dictionary) -> Dictionary:
	if (input.get("schema_version") != "sporespore_post_completion_hold_probe_input_v1"
		or input.get("commands_per_terminal") != 240 or input.get("cases", []).size() != 4):
		return {"ok": false, "failure_code": "HOLD_PROBE_INPUT"}
	var before := Transport.stringify(input)
	var path: String = OS.get_cmdline_user_args()[0].get_base_dir().path_join("native_calls.jsonl")
	if FileAccess.file_exists(path): return {"ok": false, "failure_code": "HOLD_PROBE_OUTPUT_EXISTS"}
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null: return {"ok": false, "failure_code": "HOLD_PROBE_OUTPUT"}
	var results := []
	for item in input.cases:
		results.append(_terminal_v1(sdk, item, input.command_template, output))
	output.close()
	return {"ok": results.all(func(r): return r.get("ok") == true) and before == Transport.stringify(input),
		"cases": results, "input_unmodified": before == Transport.stringify(input),
		"native_calls_sha256": "sha256:" + FileAccess.get_sha256(path),
		"counterfactual_frozen_measurements": true, "predicted_settling": false,
		"complete_route_proven": false, "held_out_population_declared": false,
		"world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}

func _terminal_v1(sdk: Object, item: Dictionary, template: Dictionary, output: FileAccess) -> Dictionary:
	var source: Dictionary = item.source
	var projected := EntrySource.project_v1(sdk, source.packet, item.global_semantic_step,
		item.model_instance_id, item.body_population_instance_sha256)
	var checks := {"retained_projection_reproduced": projected.get("ok") == true and EntryReplay._same(projected, source.projection)}
	if not checks.retained_projection_reproduced:
		return {"ok": false, "case_id": item.case_id, "checks": checks, "failure_code": projected.get("failure_code", "PROJECTED_VALUE")}
	var crossed: Dictionary = source.packet.duplicate(true)
	crossed.direct_state_source.semantic_step += 1
	checks.crossed_source_clock_refused = EntrySource.project_v1(sdk, crossed, item.global_semantic_step,
		item.model_instance_id, item.body_population_instance_sha256).get("ok") != true
	var native_torso: Dictionary = source.packet.direct_state_source.ordered_body_states[0]
	var q: Dictionary = native_torso.orientation_xyzw
	# Use the actual existing hold's frame selection and fresh-start helper.
	var frame_id := CandidateProfile.walking_frame_id_v1(_candidate_selection, Route.HOLD_SEGMENT)
	var frame := Facade.DevelopmentWalkingFrame.frame_v1(Basis(Quaternion(q.x, q.y, q.z, q.w)), "walking_resume", frame_id)
	if frame.get("ok") != true: return {"ok": false, "case_id": item.case_id, "failure_code": "FRAME"}
	var facade := Facade.new()
	var floor: StaticBody3D = Facade.RecoveryWorld.create_floor_v1()
	facade._binding = {"floor": floor, "model_instance_id": "post-completion-probe-" + item.case_id}
	var p: Dictionary = native_torso.position_world_m
	var started := facade._start_adapter_from_frame_v1(frame, Vector3(p.x, p.y, p.z),
		{"front_left": 6, "front_right": 6, "rear_left": 6, "rear_right": 6},
		Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID).profile, true, Route.R10S.HOLD_ALIAS, "walking_resume")
	checks.actual_adapter_started = started.get("ok") == true
	checks.stationary_from_first_command = checks.actual_adapter_started and facade._adapter._development_stationary_hold
	var count := 0
	var first_error := 0.0
	var last_error := 0.0
	var max_error := 0.0
	var max_target_change := 0.0
	var previous_targets := []
	var failure := {}
	if checks.actual_adapter_started:
		var adapter: RefCounted = facade._adapter
		var memory: Dictionary = adapter._memory.duplicate(true)
		for index in range(240):
			var request: Dictionary = source.projection.request.duplicate(true)
			request.schema_version = "sporespore_balanced_wave_policy_session_step_request_v3"
			request.memory = memory
			request.command = template.duplicate(true)
			request.command.gait_amplitude = 0.0
			request.command.desired_planar_velocity_task_m_s = {"x": 0.0, "y": 0.0, "z": 0.0}
			request.command.valid_from_step = index + 1
			request.command.valid_through_step = index + 1
			# Only session clock, capability and frame are rebased; physical values stay frozen.
			request.state.semantic_step = index + 1
			request.state.sample_time_s = source.projection.request.state.sample_time_s + float(index) / 120.0
			request.state.adapter_capability_sha256 = adapter._adapter_capability_sha256
			request.state.task_frame = {
				"origin_world_m": adapter._vector(adapter._initial_origin_world_m),
				"forward_axis_world_unit": adapter._unit_vector_dictionary_binary64(adapter._initial_forward_axis_world),
				"lateral_axis_world_unit": adapter._unit_vector_dictionary_binary64(adapter._initial_lateral_axis_world),
				"up_axis_world_unit": adapter._unit_vector_dictionary_binary64(Vector3.UP),
				"reference_yaw_rad": adapter._canonical_initial_heading_rad}
			for key in ["semantic_step", "sample_time_s", "adapter_capability_sha256"]:
				request.measured_body_frame[key] = request.state[key]
			var pure: Dictionary = request.duplicate(true)
			pure.schema_version = "sporespore_balanced_wave_policy_step_request_v3"
			pure.descriptor = adapter._descriptor
			pure.policy_id = Facade.DevelopmentWalkingPolicy.STARTUP_VELOCITY_POLICY_ID
			if index == 0:
				for kind in ["missing_floor", "missing_body_frame", "crossed_body_clock"]:
					var bad: Dictionary = pure.duplicate(true)
					if kind == "missing_floor": bad.erase("floor_reference")
					elif kind == "missing_body_frame": bad.erase("measured_body_frame")
					else: bad.measured_body_frame.semantic_step += 1
					var refused: String = sdk.balanced_wave_policy_step_json(Transport.stringify(bad))
					# Compare original native numbers without the legacy V50 host parser's rounding.
					var decoded: Variant = sdk.decode_exact_json_v1(refused)
					# Transport/schema errors and safe controller refusals are distinct ABI results.
					checks[kind + "_refused"] = (decoded is Dictionary and (decoded.get("ok") == false
						or decoded.get("ok") == true and decoded.get("value", {}).get("actuation", {}).get("safe_no_actuation") == true
						and decoded.value.actuation.get("failure_codes") == ["FRAME_INVALID"]
						and same_json_value_v1(decoded.value.next_memory, pure.memory)))
					output.store_line(Transport.stringify({"case_id": item.case_id, "negative": kind, "request": bad, "raw_response": refused}))
			var native: Dictionary = adapter._call_balanced_wave_session_step_with_transport_verification(request, index + 1)
			var raw: String = sdk.balanced_wave_policy_step_json(Transport.stringify(pure))
			var host_decoded: Variant = JSON.parse_string(raw)
			output.store_line(Transport.stringify({"case_id": item.case_id, "command": index + 1, "session_request": request,
				"session_result": native, "stateless_request": pure, "stateless_raw_response": raw,
				"stateless_host_value": host_decoded.get("value", {}) if host_decoded is Dictionary else {}}))
			if native.get("ok") != true or native.get("value", {}).get("actuation", {}).get("safe_no_actuation") != false:
				failure = {"command": index + 1, "failure_code": native.get("failure_code", "NATIVE_REFUSAL")}
				break
			if "sha256:" + raw.sha256_text() != native.native_step_transport_verification.raw_native_response_sha256:
				failure = {"command": index + 1, "failure_code": "STATELESS_BYTES_DIFFER"}
				break
			if not (host_decoded is Dictionary) or not EntryReplay._same(host_decoded.get("value"), native.value):
				failure = {"command": index + 1, "failure_code": "STATELESS_HOST_VALUE_DIFFERS"}
				break
			var error := 0.0
			var targets := []
			for joint in range(8):
				var target: float = native.value.actuation.ordered_commands[joint].clamped_target_position_rad
				targets.append(target)
				error = maxf(error, absf(target - request.state.ordered_joint_observations[joint].position_rad))
				if not previous_targets.is_empty(): max_target_change = maxf(max_target_change, absf(target - previous_targets[joint]))
			if count == 0: first_error = error
			last_error = error
			max_error = maxf(max_error, error)
			previous_targets = targets
			memory = native.value.next_memory
			count += 1
		checks.adapter_shutdown = adapter.shutdown().get("ok") == true
	floor.free()
	checks.all_commands_and_stateless_bytes = count == 240 and failure.is_empty()
	return {"ok": not checks.values().has(false), "case_id": item.case_id, "checks": checks,
		"native_commands": count, "first_target_error_rad": first_error, "last_target_error_rad": last_error,
		"maximum_target_error_rad": max_error, "maximum_between_command_target_change_rad": max_target_change,
		"original_readiness": source.readiness.ready, "original_horizontal_com_speed_m_s": source.readiness.horizontal_com_speed_m_s,
		"hold_frame_id": frame_id, "failure": failure}
