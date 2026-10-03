extends SceneTree
# gdlint: disable=max-line-length
const Shared := preload("res://tests/test_development_v32_walking_policy.gd")
const Failure := preload("res://sdk/adapters/godot/gdscript/development_native_step_failure_v1.gd")
const Worker := preload("res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd")
const PROFILE := "res://sdk/development/recovery_candidates/v43-support-progression-integrated-v1.json"
const POLICY := "sporespore_balanced_wave_recovery_support_progression_v1"
const RECEIPT := "sporespore_recovery_support_progression_controller_step_receipt_v1"

func _initialize() -> void:
	var probe := Shared.RuntimeProbe.new()
	# Only the resource selector is read with the ordinary parser; numerical
	# retained inputs are decoded exactly after loading the bound runtime.
	var input_text := FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0])
	var selection: Dictionary = JSON.parse_string(input_text)
	var runtime_profile: String = selection.get("runtime_profile", PROFILE)
	probe.profile_path = runtime_profile
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(runtime_profile))
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(profile.runtime_binding))
	var checks := {"exact_native_runtime": probe._load_runtime_extension_v1()}
	if not checks.exact_native_runtime:
		probe.free()
		_finish(checks, {})
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var input: Dictionary = sdk.decode_exact_json_v1(input_text)
	var facade := Shared.Facade.new()
	var floor: StaticBody3D = Shared.Facade.RecoveryWorld.create_floor_v1()
	facade._binding = {"floor": floor, "model_instance_id": "development-safe-refusal-zero-world"}
	var frame := Shared.Facade.DevelopmentWalkingFrame.frame_v1(Basis.IDENTITY, "walking_resume", "anatomical_plus_x_horizontal_resume_v1")
	var material: Dictionary = Shared.Facade.MaterialProfiles.resolve(Shared.Facade.MATERIAL_PROFILE_ID).profile
	var phases := {"front_left": 90, "front_right": 90, "rear_left": 90, "rear_right": 90}
	var started: Dictionary = facade._start_adapter_from_frame_v1(frame, Vector3.ZERO, phases, material, true, POLICY)
	checks.actual_facade_start = started.get("ok") == true
	if not checks.actual_facade_start:
		floor.free()
		probe.free()
		_finish(checks, {"start": started})
		return
	var adapter: RefCounted = facade._adapter
	checks.facade_enables_only_development_path = adapter._development_native_step_failure_retention_enabled
	var default_adapter := Shared.Facade.SdkAdapterScript.new()
	checks.adapter_default_disabled = not default_adapter._development_native_step_failure_retention_enabled
	var legacy_facade := Shared.Facade.new()
	var legacy_started: Dictionary = legacy_facade._start_adapter_from_frame_v1(frame, Vector3.ZERO, phases, material, true)
	checks.actual_legacy_facade_disables_retention = legacy_started.get("ok") == true and not legacy_facade._adapter._development_native_step_failure_retention_enabled
	checks.legacy_shutdown = legacy_facade._adapter.shutdown().get("ok") == true
	legacy_facade._adapter = null
	var morphology: Dictionary = adapter._compiled.morphology
	var normal_count := 0
	var exact_normal := true
	for row in input.rows:
		adapter._development_native_step_failure_retention_enabled = false
		var old: Dictionary = adapter._call_balanced_wave_session_step_with_transport_verification(row.request, int(row.request.state.semantic_step))
		adapter._development_native_step_failure_retention_enabled = true
		var current: Dictionary = adapter._call_balanced_wave_session_step_with_transport_verification(row.request, int(row.request.state.semantic_step))
		exact_normal = exact_normal and Shared.Transport.stringify(old) == Shared.Transport.stringify(current) and current.get("ok") == true
		if current.get("ok") == true:
			exact_normal = exact_normal and current.native_step_transport_verification.raw_native_response_sha256 == row.raw_native_response_sha256
		normal_count += 1
	checks.all_176_normal_commands_unchanged = exact_normal and normal_count == 176
	var request: Dictionary = input.rows[-1].request.duplicate(true)
	request.memory.support_progression.held_steps = 120
	var request_raw := Shared.Transport.stringify(request)
	var response_raw: String = adapter._api.balanced_wave_policy_session_step_json(request_raw)
	var verification_raw: String = adapter._api.balanced_wave_native_step_transport_verification_json(response_raw, POLICY, RECEIPT, 176)
	adapter._memory = request.memory.duplicate(true)
	var memory_before: Dictionary = adapter._memory.duplicate(true)
	var clock_before := int(adapter._step_count)
	var failed: Dictionary = adapter.step({"ok": true, "request": request}, 176, {}, phases, 0.0, {}, true)
	var record: Dictionary = failed.get("development_native_step_failure", {})
	checks.actual_step_returns_verified_failure = failed.get("ok") == false and failed.get("detail") == Failure.contract.verified_refusal_failure_code and record.get("verified_zero_actuation_refusal") == true
	checks.failed_step_does_not_advance = adapter._step_count == clock_before and Failure.same_json_v1(adapter._memory, memory_before)
	checks.failed_step_contains_no_actuation_value = not failed.has("native_output") and not failed.has("value")
	checks.exact_request_and_response_retained = record.get("request") == Failure.bytes_v1(request_raw) and record.get("response") == Failure.bytes_v1(response_raw)
	checks.native_reason_preserved = record.get("reported_native_controller_error") == "CAPABILITY_UNSUPPORTED:support_progression_hold_timeout"
	var portable := Shared.Facade.portable_step_failure_v1(failed)
	var partial := Worker.partial_arm_failure_retention_projection_l15_v1({"last_walking_step_failure": portable}, "kick_passive_recovery_resume")
	var published: Dictionary = sdk.decode_exact_json_v1(Shared.Transport.stringify(partial))
	var retained: Dictionary = published.last_walking_step_failure.portable_step_receipt.development_native_step_failure
	checks.real_facade_worker_projection_preserves_raw = retained.request.utf8_text == request_raw and retained.response.utf8_text == response_raw
	checks.cold_retention_verifies = Failure.retained_valid_v1(sdk, retained, POLICY, RECEIPT, 176, morphology)
	var mutations := _native_mutations(sdk, response_raw)
	var negatives := {}
	for name in mutations:
		var case_request := request.duplicate(true)
		var case_morphology := morphology.duplicate(true)
		if name == "missing_morphology_both": case_morphology.erase("morphology_spec_sha256")
		elif name == "empty_capability_both": case_request.state.adapter_capability_sha256 = ""
		elif name == "missing_command_both": case_request.command.erase("command_id")
		var capture := Failure.capture_v1(sdk, Shared.Transport.stringify(case_request), mutations[name], verification_raw, POLICY, RECEIPT, 176, case_morphology)
		var invalid: Dictionary = capture.development_native_step_failure
		negatives[name] = capture.ok == false and invalid.verified_zero_actuation_refusal == false and invalid.response.utf8_text == mutations[name] and not invalid.motor_application_permitted and Failure.retained_valid_v1(sdk, invalid, POLICY, RECEIPT, 176, case_morphology)
	var crossed := request.duplicate(true)
	crossed.memory.support_progression.held_steps = 119
	var crossed_capture := Failure.capture_v1(sdk, Shared.Transport.stringify(crossed), response_raw, verification_raw, POLICY, RECEIPT, 176, morphology)
	negatives.changed_request_memory_refuses = not crossed_capture.development_native_step_failure.verified_zero_actuation_refusal
	var forged := {}
	for name in ["missing_request", "changed_raw", "false_classification", "changed_step", "authority", "invented_memory_advance"]:
		var changed := retained.duplicate(true)
		if name == "missing_request": changed.erase("request")
		elif name == "changed_raw": changed.response.utf8_text += " "
		elif name == "false_classification": changed.classification = "success"
		elif name == "changed_step": changed.semantic_step += 1
		elif name == "authority": changed.physical_acceptance_authority = true
		else: changed.adapter_memory_advanced = true
		forged[name] = not Failure.retained_valid_v1(sdk, changed, POLICY, RECEIPT, 176, morphology)
	checks.native_corruptions_refuse_and_retain = not negatives.values().has(false)
	checks.forged_retention_refuses = not forged.values().has(false)
	checks.exact_numeric_leaf_rules = Failure.same_json_v1({"x": [0, 1]}, {"x": [0.0, 1.0]}) and not Failure.same_json_v1(true, 1) and not Failure.same_json_v1(1.0, 1.0000000000000002) and not Failure.same_json_v1(9007199254740993, 9007199254740992.0)
	checks.shutdown = adapter.shutdown().get("ok") == true
	facade._adapter = null
	floor.free()
	probe.free()
	_finish(checks, {"normal_commands": normal_count, "failed_adapter_result": failed,
		"selected_runtime_profile": runtime_profile, "selected_runtime_sha256": profile.runtime_sha256,
		"published_partial_arm": published, "native_negative_controls": negatives,
		"forged_retention_controls": forged, "synthetic_boundary_input": true,
		"original_physical_failed_command_reconstructed": false})

func _native_mutations(sdk: Object, raw: String) -> Dictionary:
	var original: Dictionary = sdk.decode_exact_json_v1(raw)
	var cases := {"malformed_json": "{not-json", "unsuccessful_envelope": "{\"ok\":false}"}
	for name in ["safe_flag", "nonzero_velocity", "nonzero_residual", "nonzero_safety", "missing_motor", "duplicate_motor", "stale_motor", "next_memory", "empty_error", "inconsistent_code", "wrong_morphology", "wrong_command", "wrong_capability", "wrong_policy", "wrong_step", "authority", "wrong_receipt_digest", "missing_morphology_both", "empty_capability_both", "missing_command_both"]:
		var changed := original.duplicate(true)
		var act: Dictionary = changed.value.actuation
		if name == "safe_flag": act.safe_no_actuation = false
		elif name == "nonzero_velocity": act.ordered_commands[0].target_velocity_rad_s = 0.1
		elif name == "nonzero_residual": act.ordered_commands[0].residual_contribution_rad_s = 0.1
		elif name == "nonzero_safety": act.ordered_commands[0].safety_contribution_rad_s = 0.1
		elif name == "missing_motor": act.ordered_commands.pop_back()
		elif name == "duplicate_motor": act.ordered_commands[0].actuator_id = act.ordered_commands[1].actuator_id
		elif name == "stale_motor": act.ordered_commands[0].valid_through_step = 175
		elif name == "next_memory": changed.value.next_memory.support_progression.held_steps = 0
		elif name == "empty_error": act.receipt.controller_error = ""
		elif name == "inconsistent_code": act.failure_codes = ["CROSSED_CODE"]
		elif name == "wrong_morphology": act.receipt.morphology_spec_sha256 = "sha256:" + "0".repeat(64)
		elif name == "wrong_command": act.receipt.command_id = "crossed-command"
		elif name == "wrong_capability": act.receipt.adapter_capability_sha256 = "sha256:" + "0".repeat(64)
		elif name == "wrong_policy": act.receipt.policy_id = "crossed-policy"
		elif name == "wrong_step": act.receipt.semantic_step = 175
		elif name == "authority": act.physical_acceptance_authority = true
		elif name == "missing_morphology_both": act.receipt.erase("morphology_spec_sha256")
		elif name == "empty_capability_both": act.receipt.adapter_capability_sha256 = ""
		elif name == "missing_command_both": act.receipt.erase("command_id")
		if name == "wrong_receipt_digest":
			act.receipt_sha256 = "sha256:" + "0".repeat(64)
		else:
			var digest: Dictionary = sdk.decode_exact_json_v1(sdk.canonicalize_json(Shared.Transport.stringify({"schema_version": "sporespore_canonical_json_request_v1", "value": act.receipt})))
			act.receipt_sha256 = digest.value.sha256
		cases[name] = Shared.Transport.stringify(changed)
	return cases

func _finish(checks: Dictionary, result: Dictionary) -> void:
	print("DEVELOPMENT_NATIVE_STEP_FAILURE ", Shared.Transport.stringify({"ok": not checks.values().has(false), "checks": checks, "result": result,
		"world_build_count": 0, "solver_step_count": 0, "native_physics_read_count": 0,
		"detached_floor_body_count": 1, "scene_tree_insertion_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}))
	quit(0 if not checks.values().has(false) else 1)
