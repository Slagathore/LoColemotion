extends "res://tests/test_development_v56_walking_adapter.gd"
## Synthetic deadline packets through the real adapter, plus independent
## production readers. No world insertion, stepping or acceptance claim.
var boundary_results: Array = []
var reader_results: Dictionary = {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var component: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	var probe := Shared.RuntimeProbe.new()
	probe.profile_path = PROFILE
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(component.runtime_binding))
	checks["bound_runtime"] = probe._load_runtime_extension_v1()
	if checks.bound_runtime:
		var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
		var inputs: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
		for fixture in inputs.boundaries:
			_check_boundary(sdk, fixture)
		_check_readers(sdk, inputs.walking_fixture)
		sdk = null
	probe.free()
	var ok := checks.values().all(func(v): return v == true)
	var out := FileAccess.open(args[1], FileAccess.WRITE)
	out.store_string(Transport.stringify({"ok": ok, "checks": checks,
		"boundaries": boundary_results, "readers": reader_results,
		"world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}))
	out.close()
	print("V56_ADAPTER_BOUNDARIES ", checks.size(), " checks; ok=", ok)
	quit(0 if ok else 1)

func _check_boundary(sdk: Object, fixture: Dictionary) -> void:
	var label: String = fixture.case
	var original: Dictionary = fixture.request
	var expected: Dictionary = sdk.decode_exact_json_v1(fixture.raw_response_utf8)
	var frame: Dictionary = original.state.task_frame
	var adapter := Adapter.new()
	var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID).profile
	var lateral := Vector3(frame.lateral_axis_world_unit.x, frame.lateral_axis_world_unit.y, frame.lateral_axis_world_unit.z)
	var started := adapter.start(Facade.RecoveryRoute.exact_base_descriptor_v1(),
		{"front_left": 90, "front_right": 90, "rear_left": 90, "rear_right": 90}, 0.0,
		Vector3.ZERO, lateral, frame.reference_yaw_rad, Facade.PHYSICS_HZ, Facade.SOLVER_POLICY.duplicate(true),
		Adapter.DEFAULT_TOLERANCE, "contact_gated", true, 0, -1, "post_settle_full",
		Adapter.P5I3B_WEIGHT_SUPPORT_POLICY_ID, material, POLICY, -1.0, false,
		Adapter.FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID, true)
	checks[label + "_start"] = started.get("ok") == true
	if started.get("ok") != true:
		return
	adapter._development_native_step_failure_retention_enabled = true
	var floor := Facade.RecoveryWorld.create_floor_v1()
	var model := "v56-boundary-" + label
	var source := Adapter.DevelopmentFloor.capture_v1(sdk, floor, model)
	checks[label + "_floor"] = adapter.bind_development_floor_source_v1(source, model).get("ok") == true
	var request := original.duplicate(true)
	request.erase("descriptor")
	request.erase("policy_id")
	request.schema_version = "sporespore_balanced_wave_policy_session_step_request_v3"
	request.state.adapter_capability_sha256 = adapter._adapter_capability_sha256
	if request.has("measured_body_frame"):
		request.measured_body_frame.adapter_capability_sha256 = adapter._adapter_capability_sha256
	# Preserve malformed fields deliberately; the native ABI must refuse them.
	# Only the fresh detached floor and host identities replace copied inputs.
	var projected := adapter._controller_step_request(adapter._memory, request.state, request.command)
	request.floor_reference = projected.floor_reference
	if request.memory.get("floor_reference_sha256") != null:
		var digest: Dictionary = sdk.decode_exact_json_v1(sdk.canonicalize_json(Transport.stringify({"schema_version": "sporespore_canonical_json_request_v1", "value": request.floor_reference})))
		request.memory.floor_reference_sha256 = digest.value.sha256
	var memory_before: Dictionary = adapter._memory.duplicate(true)
	var step := int(request.state.semantic_step)
	var response := adapter._call_balanced_wave_session_step_with_transport_verification(request, step)
	var retained := {"case": label, "request_raw": JSON.stringify(request, "", true, true),
		"descriptor": adapter._descriptor.duplicate(true), "response": response}
	boundary_results.append(retained)
	var success: bool = expected.get("ok") == true and expected.value.actuation.safe_no_actuation == false
	checks[label + "_expected_adapter_result"] = response.get("ok") == success
	checks[label + "_adapter_memory_not_advanced"] = adapter._memory == memory_before
	if success and response.get("ok") == true:
		var value: Dictionary = response.value
		checks[label + "_unchanged_component_commands"] = value.actuation.ordered_commands == expected.value.actuation.ordered_commands
		checks[label + "_explicit_limit"] = value.actuation.receipt.recovery_support_plane.measured_support_transfer.maximum_preparation_commands == 360
		checks[label + "_transport_identity"] = response.native_step_transport_verification.controller_receipt_schema_version == Adapter.DEVELOPMENT_EXTENDED_PREPARATION_RECEIPT_SCHEMA
	else:
		var failure: Dictionary = response.get("development_native_step_failure", {})
		var native: Dictionary = sdk.decode_exact_json_v1(failure.get("response", {}).get("utf8_text", "{}"))
		checks[label + "_retained_failure_reader"] = Adapter.DevelopmentNativeFailure.retained_valid_v1(sdk, failure, POLICY, Adapter.DEVELOPMENT_EXTENDED_PREPARATION_RECEIPT_SCHEMA, step, adapter._compiled.morphology)
		checks[label + "_native_result_kind"] = native.get("ok") == expected.get("ok")
		checks[label + "_no_actuation_permission"] = failure.get("motor_application_permitted") == false and not response.has("value")
		if expected.get("ok") == true:
			checks[label + "_verified_zero_refusal"] = failure.get("verified_zero_actuation_refusal") == true and native.value.actuation.receipt.controller_error == expected.value.actuation.receipt.controller_error
		else:
			checks[label + "_typed_abi_refusal"] = native.get("failure_code") == expected.get("failure_code") and failure.get("verified_zero_actuation_refusal") == false
	checks[label + "_shutdown"] = adapter.shutdown().get("ok") == true
	floor.free()

func _check_readers(sdk: Object, fixture: Dictionary) -> void:
	var floor := Facade.RecoveryWorld.create_floor_v1()
	var source := Adapter.DevelopmentFloor.capture_v1(sdk, floor, "r10f-l13-zero-world-walking_resume")
	var ledger := Shared.Prior._walking_ledger_production_fixture_v2(sdk, 900,
		"walking_resume", "walking_resume", "walking_resume", "v56-reader-fixture", POLICY, true, source, fixture)
	reader_results["original"] = ledger
	checks["reader_original_motor_ledger"] = ledger.get("ok") == true
	if ledger.get("ok") != true:
		floor.free()
		return
	var handoff: Dictionary = ledger.walking_actuation_handoff_receipt
	checks["reader_original_handoff"] = Facade.walking_actuation_handoff_receipt_valid_v1(sdk, handoff, POLICY)
	for field in ["selected_policy_id", "selected_policy_digest", "evaluation_segment_id"]:
		var changed := handoff.duplicate(true)
		changed[field] = "walking_prefix" if field == "evaluation_segment_id" else "crossed"
		changed.payload_sha256 = ""
		changed.payload_sha256 = Facade._sha256_v1(sdk, changed)
		checks["reader_rehashed_handoff_" + field] = not Facade.walking_actuation_handoff_receipt_valid_v1(sdk, changed, POLICY)
		reader_results["handoff_" + field] = changed
	for mutation in ["policy", "receipt_schema", "limit_240", "limit_361", "limit_missing", "limit_string"]:
		var portable: Dictionary = ledger.portable_step_receipt.duplicate(true)
		if mutation in ["policy", "receipt_schema"]:
			var transport: Dictionary = portable.native_step_transport_verification
			transport["policy_id" if mutation == "policy" else "controller_receipt_schema_version"] = Adapter.DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID if mutation == "policy" else Adapter.DEVELOPMENT_INITIALIZED_ZERO_BRAKE_RECEIPT_SCHEMA
			transport.payload_sha256 = ""
			transport.payload_sha256 = Adapter.CanonicalJsonScript.sha256(transport)
		else:
			var transfer: Dictionary = portable.native_output.actuation.receipt.recovery_support_plane.measured_support_transfer
			match mutation:
				"limit_240": transfer.maximum_preparation_commands = 240
				"limit_361": transfer.maximum_preparation_commands = 361
				"limit_missing": transfer.erase("maximum_preparation_commands")
				"limit_string": transfer.maximum_preparation_commands = "360"
		var result := Facade.walking_ledger_application_intent_v2(sdk, 900, "walking_resume", ledger.session_id, 1,
			portable, ledger.authority_application_receipt, ledger.motor_population_readback, handoff, POLICY)
		checks["reader_refuses_" + mutation] = result.get("ok") == false and ("identity.native_transport_verification_valid" if mutation in ["policy", "receipt_schema"] else "identity.v56_preparation_limit") in result.get("failed_predicate_ids", [])
		reader_results[mutation] = result
	var fixed := Shared.Policy.contract_for_v1(POLICY)
	var binding := Shared.Policy.binding_v1(POLICY, "walking_resume")
	var report := {"retained_arm": {"walking_sessions": [{"evaluation_segment_id": "walking_resume",
		"start_receipt": {"schema_version": Shared.Policy.schema_v1("", "session", binding),
			"development_walking_policy_id": POLICY, "selected_policy_id": POLICY,
			"selected_policy_digest": binding.policy_digest, "controller_profile_sha256": fixed.native_profile_sha256},
		"completion_receipt": {"adapter_summary": {"controller_policy_id": POLICY}}}]}}
	checks["reader_original_session_identity"] = Shared.Policy.validate_report_v1(report, POLICY).get("ok") == true
	for mutation in ["start_policy", "profile", "finalization", "publication"]:
		var changed := report.duplicate(true)
		var session: Dictionary = changed.retained_arm.walking_sessions[0]
		match mutation:
			"start_policy": session.start_receipt.selected_policy_id = Adapter.DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID
			"profile": session.start_receipt.controller_profile_sha256 = "crossed"
			"finalization": session.completion_receipt.adapter_summary.controller_policy_id = Adapter.DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID
			"publication": session.start_receipt.schema_version = "crossed"
		var result := Shared.Policy.validate_report_v1(changed, POLICY)
		checks["reader_refuses_session_" + mutation] = result.get("ok") == false
		reader_results["session_" + mutation] = result
	floor.free()
