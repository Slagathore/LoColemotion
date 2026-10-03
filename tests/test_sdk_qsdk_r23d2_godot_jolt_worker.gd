extends SceneTree
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Retained physical QSDK-R23D2 Godot/Jolt heading-response worker.
##
## The consumed attempt and loop remain inspectable for closure audit. Physical
## mode now refuses before fixture/world construction under every invocation;
## no supervisor token can reopen this identity. New work belongs to R23D3.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const ProportionSpecScript := preload(
	"res://scripts/lab/gait/physical_quadruped_proportion_spec.gd"
)
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const ClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)

const ORACLE_PATH := "res://sdk/turning/r23d2_oracle_preregistration.json"
const WORKER_CONTRACT_PATH := "res://sdk/turning/r23d2_godot_jolt_worker_contract_v1.json"
const DEVELOPMENT_CONTRACT_PATH := "res://sdk/turning/r23d2_development_contract_v1.json"
const CAMPAIGN_ID := "QSDK-R23D2-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
const GATE_ID := "QSDK-R23D2-GJT"
const PARENT_GATE_ID := "QSDK-R23D2"
const ENGINE_ID := "godot_jolt"
const POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const POLICY_DIGEST := "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
const MORPHOLOGY_ID := "qsdk_r05_generated_s169"
const GENERATOR_INDEX := 169
const CAMPAIGN_SEED := 21501
const MATERIAL_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const STABILITY_POLICY_ID := "p5i3b_weight_support_shadow_v1"
const PHYSICS_HZ := 120
const SDK_COMPARISON_TOLERANCE := 2.5e-7
const ORACLE_TOLERANCE := 1.0e-12
const CONTROLLER_STEPS := 2992
const PREFLIGHT_SCHEMA := "sporespore_qsdk_r23d2_godot_jolt_worker_preflight_v1"
const REPORT_SCHEMA := "sporespore_qsdk_r23d2_engine_cell_report_v1"
const WORKER_FAILURE_SCHEMA := "sporespore_qsdk_r23d2_worker_failure_v1"
const COMMAND_VALIDATION_SCHEMA := "sporespore_qsdk_r23d2_command_validation_v1"
const EXECUTION_STAGE_SCHEMA := "sporespore_qsdk_r23d2_execution_stage_v1"
const NORMALIZED_VALIDATION_MODE := (
	"native_adapter_structure_receipts_and_independent_heading_oracle_v1"
)
const SOURCE_VALIDATION_MODE := "native_balanced_wave_structure_and_receipts_v1"
const SCHEDULE_ID := "qsdk_r23d1_step_turn_return_v1"
const ATTEMPT_PATH_ENVIRONMENT_VARIABLE := "SPORESPORE_QSDK_R23D2_ATTEMPT"
const AUTHORIZATION_TOKEN_ENVIRONMENT_VARIABLE := "SPORESPORE_QSDK_R23D2_TOKEN"
const CELL_ID_ENVIRONMENT_VARIABLE := "SPORESPORE_QSDK_R23D2_CELL"
const ENGINE_ID_ENVIRONMENT_VARIABLE := "SPORESPORE_QSDK_R23D2_ENGINE"
const ORACLE_TRACE_ENVIRONMENT_VARIABLE := (
	"SPORESPORE_QSDK_R23D2_GODOT_JOLT_ORACLE_TRACE"
)
const ORACLE_TRACE_ENABLE_VALUE := "sporespore_qsdk_r23d2_oracle_trace_v1"
const RECEIPT_FIELDS := [
	"cross_track_error_m",
	"cross_track_velocity_m_s",
	"measured_yaw_error_rad",
	"desired_heading_error_rad",
	"yaw_tracking_error_rad",
]
const GAIT_STEPS := {
	"front_left": 0,
	"front_right": 0,
	"rear_left": 0,
	"rear_right": 0,
}
const ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const HOST_OBSERVER_PATH_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.25,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const ACTUATOR_IMPULSE_OPTIONS := {
	"mass_adaptive_actuator_enabled": true,
	"actuator_policy_id": "g3_gp3_global_actuator_margin_v1",
	"actuator_impulse_scale": 1.015,
}
const HOST_PREAUTHORITY_MOTOR_OPTIONS := {
	"mass_adaptive_motor_velocity_enabled": true,
	"motor_velocity_policy_id": "qsdk_r05_non_authoritative_host_preauthority_v1",
	"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s": 3.0,
	"anchor_error_guard_enabled": true,
	"morphology_interaction_score": 0.0,
	"anchor_error_guard_activation_fraction": 0.8,
	"anchor_error_guard_maximum_motor_target_speed_rad_s": 2.0,
}
const SOLVER_POLICY_OPTIONS := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": PHYSICS_HZ,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
# R23D2 consumed its sole shared aggregate identity.
const PHYSICAL_IDENTITY_CLOSED := true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 and args.size() != 3:
		_emit_worker_failure("", "", "before_world", 0, 0, "QSDK_R23D2_GJT_ARGUMENTS_INVALID")
		return
	var mode := String(args[0])
	if mode == "physical" and PHYSICAL_IDENTITY_CLOSED:
		_emit_worker_failure(
			String(args[1]),
			String(args[2]) if args.size() == 3 else "",
			"before_world",
			0,
			0,
			"QSDK_R23D2_GJT_PHYSICAL_IDENTITY_CLOSED",
		)
		return
	var arm_id := String(args[1])
	var arm_heading_offset_rad := _arm_offset(arm_id)
	if not is_finite(arm_heading_offset_rad):
		_emit_worker_failure(
			arm_id,
			"",
			"before_world",
			0,
			0,
			"QSDK_R23D2_GJT_ARM_UNKNOWN:%s" % arm_id,
		)
		return
	if mode == "preflight":
		if args.size() != 2:
			_emit_worker_failure(
				arm_id,
				"",
				"before_world",
				0,
				0,
				"QSDK_R23D2_GJT_PREFLIGHT_ARGUMENTS_INVALID",
			)
			return
		var preflight_report: Dictionary = await _run_preflight(
			arm_id,
			arm_heading_offset_rad,
		)
		if not bool(preflight_report.get("ok", false)):
			_emit_worker_failure(
				arm_id,
				"",
				"before_world",
				0,
				0,
				String(
					preflight_report.get(
						"failure_code",
						"QSDK_R23D2_GJT_PREFLIGHT_INVALID",
					)
				),
			)
			return
		print("QSDK_R23D2_GODOT_JOLT_PREFLIGHT ", JSON.stringify(preflight_report))
		quit(0)
		return
	if mode != "physical" or args.size() != 3:
		_emit_worker_failure(
			arm_id,
			"",
			"before_world",
			0,
			0,
			"QSDK_R23D2_GJT_MODE_INVALID",
		)
		return
	var source_commit := String(args[2])
	if not _valid_lower_hex(source_commit, 40):
		_emit_worker_failure(
			arm_id,
			source_commit,
			"before_world",
			0,
			0,
			"QSDK_R23D2_GJT_SOURCE_COMMIT_INVALID",
		)
		return
	var development_contract := _read_json(DEVELOPMENT_CONTRACT_PATH)
	if not _physical_authorization_exact(development_contract, arm_id, source_commit):
		_emit_worker_failure(
			arm_id,
			source_commit,
			"before_world",
			0,
			0,
			"QSDK_R23D2_GJT_PHYSICAL_AUTHORIZATION_REQUIRED",
		)
		return
	var physical_preflight: Dictionary = await _run_preflight(
		arm_id,
		arm_heading_offset_rad,
	)
	if not bool(physical_preflight.get("ok", false)):
		_emit_worker_failure(
			arm_id,
			source_commit,
			"before_world",
			0,
			0,
			String(
				physical_preflight.get(
					"failure_code",
					"QSDK_R23D2_GJT_PREFLIGHT_INVALID",
				)
			),
		)
		return
	var prepared := _prepare_physical(development_contract, arm_id)
	if not bool(prepared.get("ok", false)):
		_emit_worker_failure(
			arm_id,
			source_commit,
			"before_world",
			0,
			0,
			String(prepared.get("failure_code", "QSDK_R23D2_GJT_PREPARE_FAILED")),
		)
		return
	var previous_trace_request := OS.get_environment(ORACLE_TRACE_ENVIRONMENT_VARIABLE)
	if not previous_trace_request.is_empty():
		_emit_worker_failure(
			arm_id,
			source_commit,
			"before_world",
			0,
			0,
			"QSDK_R23D2_GJT_ORACLE_TRACE_ENVIRONMENT_NOT_CLEAN",
		)
		return
	OS.set_environment(ORACLE_TRACE_ENVIRONMENT_VARIABLE, ORACLE_TRACE_ENABLE_VALUE)
	var summary: Dictionary = await _run_wave(prepared, false)
	OS.set_environment(ORACLE_TRACE_ENVIRONMENT_VARIABLE, previous_trace_request)
	var world_build_count := int(summary.get("world_build_count", 0))
	if world_build_count != 1:
		_emit_worker_failure(
			arm_id,
			source_commit,
			"world_construction_failed",
			1,
			0,
			String(summary.get("failure_code", "QSDK_R23D2_GJT_WORLD_CONSTRUCTION_FAILED")),
		)
		return
	var oracle_validation := _validate_physical_oracle_trace(
		summary,
		physical_preflight.get("selected_profile_oracle", {}),
	)
	if not bool(oracle_validation.get("ok", false)):
		if bool(oracle_validation.get("controller_receipt_rejected", false)):
			_emit_worker_failure(
				arm_id,
				source_commit,
				"controller_validation_failed",
				1,
				1,
				String(oracle_validation["failure_code"]),
				oracle_validation.get("rejected_controller_projection", {}),
				oracle_validation.get("oracle_input", {}),
				oracle_validation.get("oracle_evaluation", {}),
			)
		else:
			_emit_worker_failure(
				arm_id,
				source_commit,
				"settlement_complete",
				1,
				1,
				String(oracle_validation["failure_code"]),
			)
		return
	var report := _compose_physical_report(
		prepared,
		summary,
		source_commit,
		oracle_validation,
	)
	if not _physical_report_shape_exact(report):
		_emit_worker_failure(
			arm_id,
			source_commit,
			"cell_report_complete",
			1,
			1,
			"QSDK_R23D2_GJT_REPORT_COMPOSITION_INVALID",
		)
		return
	print("QSDK_R23D2_GODOT_JOLT_CELL ", JSON.stringify(report))
	quit(0)


func _run_preflight(arm_id: String, arm_heading_offset_rad: float) -> Dictionary:
	var oracle_contract := _read_json(ORACLE_PATH)
	var worker_contract := _read_json(WORKER_CONTRACT_PATH)
	var development_contract := _read_json(DEVELOPMENT_CONTRACT_PATH)
	if not _contracts_exact(oracle_contract, worker_contract, development_contract):
		return _failure("QSDK_R23D2_GJT_CONTRACT_IDENTITY_INVALID")
	var solver_receipt := _apply_solver_configuration()
	if not bool(solver_receipt.get("ok", false)):
		return solver_receipt
	var descriptor_result := _descriptor()
	if not bool(descriptor_result.get("ok", false)):
		return descriptor_result
	var material_result := MaterialProfilesScript.resolve(MATERIAL_PROFILE_ID)
	if not bool(material_result.get("ok", false)):
		return material_result
	var descriptor: Dictionary = descriptor_result["descriptor"]
	var material_profile: Dictionary = material_result["profile"]
	var results: Array[Dictionary] = []
	var nonzero_count := 0
	var legacy_rejection_count := 0
	var predicate_negative_control_count := 0
	var native_controller_step_count := 0
	var native_command_count := 0
	var host_mapping_validation_count := 0
	var host_parameter_write_count := 0
	var host_object_creation_count := 0
	var scene_tree_insertion_count := 0
	var controller_profile_sha256 := ""
	var adapter_capability_sha256 := ""
	var oracle_trace_canary: Dictionary = {}

	for canary_value in oracle_contract.get("oracle_canaries", []):
		var canary: Dictionary = canary_value
		var trace_case := results.is_empty()
		var previous_trace_request := ""
		if trace_case:
			previous_trace_request = OS.get_environment(ORACLE_TRACE_ENVIRONMENT_VARIABLE)
			if not previous_trace_request.is_empty():
				return _failure("QSDK_R23D2_GJT_ORACLE_TRACE_ENVIRONMENT_NOT_CLEAN")
			OS.set_environment(ORACLE_TRACE_ENVIRONMENT_VARIABLE, ORACLE_TRACE_ENABLE_VALUE)
		var case_result := _execute_case(
			descriptor,
			material_profile,
			canary,
			float(canary["desired_heading_rad"]),
			"qsdk_r23d2_oracle_%s" % String(canary["canary_id"]),
			oracle_contract,
		)
		if trace_case:
			OS.set_environment(ORACLE_TRACE_ENVIRONMENT_VARIABLE, previous_trace_request)
		if not bool(case_result.get("ok", false)):
			return case_result
		if trace_case:
			oracle_trace_canary = _validate_preflight_oracle_trace(
				case_result,
				oracle_contract["selected_profile_oracle"],
			)
			if not bool(oracle_trace_canary.get("ok", false)):
				return oracle_trace_canary
		if controller_profile_sha256.is_empty():
			controller_profile_sha256 = String(case_result["controller_profile_sha256"])
			adapter_capability_sha256 = String(case_result["adapter_capability_sha256"])
		elif (
			String(case_result["controller_profile_sha256"]) != controller_profile_sha256
			or String(case_result["adapter_capability_sha256"]) != adapter_capability_sha256
		):
			return _failure("QSDK_R23D2_GJT_ADAPTER_IDENTITY_DRIFT")
		var expected: Dictionary = case_result["expected_receipt"]
		var nonzero := (
			float(expected["cross_track_error_m"]) != 0.0
			or float(expected["cross_track_velocity_m_s"]) != 0.0
		)
		if nonzero:
			nonzero_count += 1
			var legacy := expected.duplicate(true)
			var raw_heading := _wrap_angle(
				float(canary["desired_heading_rad"]) - float(canary["reference_yaw_rad"])
			)
			legacy["desired_heading_error_rad"] = raw_heading
			legacy["yaw_tracking_error_rad"] = _wrap_angle(
				float(expected["measured_yaw_error_rad"]) - raw_heading
			)
			if _predicate_failures(expected, legacy).is_empty():
				return _failure(
					"QSDK_R23D2_GJT_LEGACY_ORACLE_ACCEPTED:%s" % String(canary["canary_id"])
				)
			legacy_rejection_count += 1
		for field_value in RECEIPT_FIELDS:
			var field := String(field_value)
			var mutated := expected.duplicate(true)
			mutated[field] = float(mutated[field]) + 1.0e-6
			if _predicate_failures(expected, mutated) != ["%s:mismatch" % field]:
				return _failure(
					(
						"QSDK_R23D2_GJT_NEGATIVE_CONTROL_INVALID:%s:%s"
						% [String(canary["canary_id"]), field]
					)
				)
			predicate_negative_control_count += 1
		native_controller_step_count += 1
		native_command_count += int(case_result["native_command_count"])
		host_mapping_validation_count += 1
		host_parameter_write_count += int(case_result["host_parameter_write_count"])
		host_object_creation_count += int(case_result["host_object_creation_count"])
		scene_tree_insertion_count += int(case_result["scene_tree_insertion_count"])
		(
			results
			. append(
				{
					"canary_id": String(canary["canary_id"]),
					"nonzero_cross_track": nonzero,
					"expected_receipt": expected.duplicate(true),
					"observed_receipt":
					(case_result["observed_receipt"] as Dictionary).duplicate(true),
					"failed_predicates": [],
					"host_mapping_sha256": String(case_result["host_mapping_sha256"]),
					"world_attempt_count": 0,
					"world_build_count": 0,
					"physical_acceptance_authority": false,
				}
			)
		)

	var first_canary: Dictionary = oracle_contract["oracle_canaries"][0]
	var arm_case := _execute_case(
		descriptor,
		material_profile,
		first_canary,
		float(first_canary["reference_yaw_rad"]) + arm_heading_offset_rad,
		"qsdk_r23d2_arm_boundary_%s" % arm_id,
		oracle_contract,
	)
	if not bool(arm_case.get("ok", false)):
		return arm_case
	var arm_expected: Dictionary = arm_case["expected_receipt"]
	if (
		absf(float(arm_expected["desired_heading_error_rad"]) - arm_heading_offset_rad)
		> ORACLE_TOLERANCE
	):
		return _failure("QSDK_R23D2_GJT_ARM_COMMAND_BOUNDARY_INVALID:%s" % arm_id)
	native_controller_step_count += 1
	native_command_count += int(arm_case["native_command_count"])
	host_mapping_validation_count += 1
	host_parameter_write_count += int(arm_case["host_parameter_write_count"])
	host_object_creation_count += int(arm_case["host_object_creation_count"])
	scene_tree_insertion_count += int(arm_case["scene_tree_insertion_count"])
	var prepared := _prepare_physical(development_contract, arm_id)
	if not bool(prepared.get("ok", false)):
		return prepared
	var entrypoint_preflight: Dictionary = await _run_wave(prepared, true)
	var root_child_count := root.get_child_count()
	if (
		not bool(entrypoint_preflight.get("ok", false))
		or int(entrypoint_preflight.get("actual_world_build_count", -1)) != 0
		or not bool(entrypoint_preflight.get("entrypoint_control_flow_complete", false))
		or not bool(entrypoint_preflight.get("sdk_heading_schedule_enabled", false))
		or String(entrypoint_preflight.get("sdk_heading_schedule_sha256", ""))
		!= String(prepared["schedule_sha256"])
		or root_child_count != 0
	):
		return _failure("QSDK_R23D2_GJT_PHYSICAL_ENTRYPOINT_PREFLIGHT_INVALID")
	var synthetic_physical_report := _synthetic_physical_report(prepared)
	var synthetic_failure_receipts := _synthetic_failure_receipts(
		arm_id,
		oracle_contract,
	)
	if synthetic_failure_receipts.size() != 6:
		return _failure("QSDK_R23D2_GJT_SYNTHETIC_FAILURE_COUNT_INVALID")
	if (
		nonzero_count != 6
		or legacy_rejection_count != 6
		or predicate_negative_control_count != 35
		or native_controller_step_count != 8
		or native_command_count != 64
		or host_mapping_validation_count != 8
		or host_parameter_write_count != 64
		or host_object_creation_count != 64
		or scene_tree_insertion_count != 0
	):
		return _failure("QSDK_R23D2_GJT_PREFLIGHT_COUNTS_INVALID")
	return {
		"schema_version": PREFLIGHT_SCHEMA,
		"ok": true,
		"failure_code": "",
		"campaign_id": CAMPAIGN_ID,
		"gate_id": GATE_ID,
		"engine_id": ENGINE_ID,
		"engine_version": Engine.get_version_info(),
		"physics_engine": String(ProjectSettings.get_setting("physics/3d/physics_engine", "")),
		"arm_id": arm_id,
		"arm_heading_offset_rad": arm_heading_offset_rad,
		"selected_policy_id": POLICY_ID,
		"morphology_id": MORPHOLOGY_ID,
		"material_profile_id": MATERIAL_PROFILE_ID,
		"solver_policy_id": String(SOLVER_POLICY_OPTIONS["solver_policy_id"]),
		"solver_receipt": solver_receipt.duplicate(true),
		"controller_profile_sha256": controller_profile_sha256,
		"adapter_capability_sha256": adapter_capability_sha256,
		"oracle_contract_sha256": _raw_file_sha256(ORACLE_PATH),
		"worker_contract_sha256": _raw_file_sha256(WORKER_CONTRACT_PATH),
		"development_contract_sha256": _raw_file_sha256(DEVELOPMENT_CONTRACT_PATH),
		"worker_contract_status": String(worker_contract["status"]),
		"development_contract_status": String(development_contract["status"]),
		"selected_profile_oracle":
		(oracle_contract["selected_profile_oracle"] as Dictionary).duplicate(true),
		"canary_count": results.size(),
		"nonzero_cross_track_canary_count": nonzero_count,
		"legacy_raw_offset_oracle_rejection_count": legacy_rejection_count,
		"predicate_negative_control_count": predicate_negative_control_count,
		"canaries": results,
		"arm_command_boundary":
		{
			"desired_heading_error_rad": float(arm_expected["desired_heading_error_rad"]),
			"observed_heading_error_rad":
			float((arm_case["observed_receipt"] as Dictionary)["desired_heading_error_rad"]),
			"failed_predicates": [],
			"host_mapping_sha256": String(arm_case["host_mapping_sha256"]),
			"native_command_count": int(arm_case["native_command_count"]),
			"host_parameter_write_count": int(arm_case["host_parameter_write_count"]),
			"scene_tree_insertion_count": int(arm_case["scene_tree_insertion_count"]),
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		},
		"adapter_start_count": native_controller_step_count,
		"native_controller_step_count": native_controller_step_count,
		"native_command_count": native_command_count,
		"host_mapping_validation_count": host_mapping_validation_count,
		"host_parameter_write_count": host_parameter_write_count,
		"host_object_creation_count": host_object_creation_count,
		"scene_tree_insertion_count": scene_tree_insertion_count,
		"oracle_trace_canary": oracle_trace_canary.duplicate(true),
		"physical_entrypoint_preflight": entrypoint_preflight.duplicate(true),
		"synthetic_physical_report": synthetic_physical_report.duplicate(true),
		"synthetic_failure_receipts": synthetic_failure_receipts.duplicate(true),
		"physical_worker_implementation_present": true,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_execution_authorized": true,
		"q_sdk_r23_satisfied": false,
		"physical_acceptance_authority": false,
	}


func _execute_case(
	descriptor: Dictionary,
	material_profile: Dictionary,
	canary: Dictionary,
	desired_heading_rad: float,
	command_id: String,
	oracle_contract: Dictionary,
) -> Dictionary:
	var adapter: RefCounted = AdapterScript.new()
	var start: Dictionary = (
		adapter
		. start(
			descriptor,
			GAIT_STEPS,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			PI * 0.5,
			PHYSICS_HZ,
			SOLVER_POLICY_OPTIONS,
			SDK_COMPARISON_TOLERANCE,
			"clocked",
			true,
			0,
			-1,
			"post_settle_full",
			STABILITY_POLICY_ID,
			material_profile,
			POLICY_ID,
		)
	)
	if not bool(start.get("ok", false)):
		return _failure(
			"QSDK_R23D2_GJT_ADAPTER_START:%s" % String(start.get("failure_code", "UNKNOWN"))
		)
	var manifest: Dictionary = start.get("adapter_manifest", {})
	var profile: Dictionary = manifest.get("controller_profile", {})
	var declared_profile: Dictionary = oracle_contract["selected_profile_oracle"]
	if (
		String(manifest.get("adapter_id", "")) != "godot_jolt_gdextension_v1"
		or String(manifest.get("physics_engine", "")) != "Jolt Physics"
		or String(start.get("controller_policy_id", "")) != POLICY_ID
		or (
			absf(
				(
					float(profile.get("cross_track_heading_gain_rad_per_m", NAN))
					- float(declared_profile["cross_track_heading_gain_rad_per_m"])
				)
			)
			> 1.0e-15
		)
		or (
			absf(
				(
					float(profile.get("cross_track_velocity_heading_gain_rad_per_m_s", NAN))
					- float(declared_profile["cross_track_velocity_heading_gain_rad_per_m_s"])
				)
			)
			> 1.0e-15
		)
	):
		return _failure("QSDK_R23D2_GJT_PROFILE_OR_ADAPTER_IDENTITY_INVALID")
	var morphology_receipt: Dictionary = adapter.preflight_compiled_morphology_boundary()
	if not bool(morphology_receipt.get("ok", false)):
		return _failure("QSDK_R23D2_GJT_MORPHOLOGY_BOUNDARY_INVALID")
	var morphology: Dictionary = morphology_receipt["morphology"]
	var state := _state_for_canary(
		morphology,
		canary,
		String(start["adapter_capability_sha256"]),
	)
	var command := _command(command_id, desired_heading_rad)
	var expected := _independent_oracle(state, command, profile)
	if (
		(
			absf(
				(
					float(expected["desired_heading_error_rad"])
					- float(canary.get("expected_desired_heading_error_rad", NAN))
				)
			)
			> ORACLE_TOLERANCE
		)
		and command_id.begins_with("qsdk_r23d2_oracle_")
	):
		return _failure("QSDK_R23D2_GJT_CANARY_EXPECTATION_INVALID")
	var runtime: Dictionary = (
		adapter
		. preflight_explicit_balanced_wave_heading_runtime_boundary(
			state,
			command,
		)
	)
	if not bool(runtime.get("ok", false)):
		return _failure(
			"QSDK_R23D2_GJT_NATIVE_BOUNDARY:%s" % String(runtime.get("failure_code", "UNKNOWN")),
			runtime,
		)
	var receipt: Dictionary = runtime["controller_receipt"]
	var failures := _predicate_failures(expected, receipt)
	if not failures.is_empty():
		return _failure(
			"QSDK_R23D2_GJT_ORACLE_MISMATCH:%s" % ",".join(failures),
			runtime,
		)
	var host_mappings: Array = runtime.get("ordered_host_mappings", [])
	if (
		int(runtime.get("native_controller_command_count", -1)) != 8
		or host_mappings.size() != 8
		or int(runtime.get("host_parameter_write_count", -1)) != 8
		or int(runtime.get("host_object_creation_count", -1)) != 8
		or int(runtime.get("scene_tree_insertion_count", -1)) != 0
		or int(runtime.get("world_attempt_count", -1)) != 0
		or int(runtime.get("world_build_count", -1)) != 0
		or bool(runtime.get("physics_state_modified", true))
	):
		return _failure("QSDK_R23D2_GJT_HOST_MAPPING_INVALID", runtime)
	var observed_receipt: Dictionary = {}
	for field_value in RECEIPT_FIELDS:
		var field := String(field_value)
		observed_receipt[field] = receipt[field]
	var adapter_summary: Dictionary = adapter.summary()
	if not bool(adapter_summary.get("ok", false)):
		return _failure("QSDK_R23D2_GJT_ADAPTER_SUMMARY_INVALID", adapter_summary)
	adapter = null
	return {
		"ok": true,
		"failure_code": "",
		"expected_receipt": expected,
		"observed_receipt": observed_receipt,
		"adapter_summary": adapter_summary,
		"controller_profile_sha256": String(start["controller_profile_sha256"]),
		"adapter_capability_sha256": String(start["adapter_capability_sha256"]),
		"native_command_count": 8,
		"host_mapping_sha256": CanonicalJsonScript.sha256(host_mappings),
		"host_parameter_write_count": 8,
		"host_object_creation_count": 8,
		"scene_tree_insertion_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _validate_preflight_oracle_trace(
	case_result: Dictionary,
	profile: Dictionary,
) -> Dictionary:
	var adapter_summary: Dictionary = case_result.get("adapter_summary", {})
	var trace: Dictionary = adapter_summary.get("r23d2_oracle_trace", {})
	var rows: Array = trace.get("rows", [])
	if (
		String(trace.get("schema_version", ""))
		!= "sporespore_qsdk_r23d2_godot_jolt_oracle_trace_v1"
		or not bool(trace.get("enabled", false))
		or String(trace.get("controller_profile_sha256", ""))
		!= String(case_result.get("controller_profile_sha256", ""))
		or int(trace.get("step_count", -1)) != 1
		or rows.size() != 1
		or bool(trace.get("physical_acceptance_authority", true))
	):
		return _failure("QSDK_R23D2_GJT_ORACLE_TRACE_CANARY_HEADER_INVALID")
	var row_value: Variant = rows[0]
	if typeof(row_value) != TYPE_DICTIONARY:
		return _failure("QSDK_R23D2_GJT_ORACLE_TRACE_CANARY_ROW_TYPE_INVALID")
	var row: Dictionary = row_value
	if (
		not _keys_exact(
			row,
			[
				"schema_version",
				"semantic_step",
				"state_frame_sha256",
				"motion_command_sha256",
				"controller_receipt_sha256",
				"controller_profile_sha256",
				"oracle_state_projection",
				"oracle_command_projection",
				"controller_receipt_projection",
				"physical_acceptance_authority",
			],
		)
		or String(row.get("schema_version", ""))
		!= "sporespore_qsdk_r23d2_godot_jolt_oracle_trace_row_v1"
		or int(row.get("semantic_step", -1)) != 0
		or not _valid_prefixed_sha256(String(row.get("state_frame_sha256", "")))
		or not _valid_prefixed_sha256(String(row.get("motion_command_sha256", "")))
		or not _valid_prefixed_sha256(String(row.get("controller_receipt_sha256", "")))
		or String(row.get("controller_profile_sha256", ""))
		!= String(trace.get("controller_profile_sha256", ""))
		or bool(row.get("physical_acceptance_authority", true))
	):
		return _failure("QSDK_R23D2_GJT_ORACLE_TRACE_CANARY_ROW_INVALID")
	var oracle_input := _trace_oracle_input(row, profile)
	var recomputation := _projected_oracle(oracle_input)
	if not bool(recomputation.get("ok", false)):
		return _failure(
			"QSDK_R23D2_GJT_ORACLE_TRACE_CANARY_INPUT_INVALID:%s"
			% String(recomputation.get("failure_code", "UNKNOWN")),
		)
	var observed: Dictionary = row.get("controller_receipt_projection", {})
	if not _keys_exact(observed, RECEIPT_FIELDS):
		return _failure("QSDK_R23D2_GJT_ORACLE_TRACE_CANARY_PROJECTION_INVALID")
	var failures := _predicate_failures(recomputation["expected_receipt"], observed)
	if not failures.is_empty():
		return _failure(
			"QSDK_R23D2_GJT_ORACLE_TRACE_CANARY_RECOMPUTATION_INVALID:%s"
			% ",".join(failures),
		)
	return {
		"schema_version": "sporespore_qsdk_r23d2_godot_jolt_oracle_trace_canary_v1",
		"ok": true,
		"failure_code": "",
		"step_count": 1,
		"full_state_frame_sha256_bound": true,
		"full_motion_command_sha256_bound": true,
		"controller_receipt_sha256_bound": true,
		"controller_profile_sha256_bound": true,
		"independent_oracle_recomputed": true,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _contracts_exact(
	oracle: Dictionary,
	worker: Dictionary,
	development: Dictionary,
) -> bool:
	return (
		(
			String(oracle.get("schema_version", ""))
			== "sporespore_qsdk_r23d2_oracle_preregistration_v1"
		)
		and String(oracle.get("campaign_id", "")) == CAMPAIGN_ID
		and String(oracle.get("gate_id", "")) == "QSDK-R23D2"
		and not bool(
			(
				(oracle.get("authorization", {}) as Dictionary)
				. get(
					"physical_execution_authorized",
					true,
				)
			)
		)
		and (oracle.get("oracle_canaries", []) as Array).size() == 7
		and (
			String(worker.get("schema_version", ""))
			== "sporespore_qsdk_r23d2_godot_jolt_worker_contract_v1"
		)
		and (
			String(worker.get("status", ""))
			== "godot_jolt_supervisor_only_physical_authorized"
		)
		and String(worker.get("campaign_id", "")) == CAMPAIGN_ID
		and String(worker.get("gate_id", "")) == GATE_ID
		and (
			String(
				(
					(worker.get("stage_zero_oracle", {}) as Dictionary)
					. get(
						"sha256",
						"",
					)
				)
			)
			== _raw_file_sha256(ORACLE_PATH)
		)
		and bool(
			(
				(worker.get("authorization", {}) as Dictionary)
				. get(
					"physical_execution_authorized",
					true,
				)
			)
		)
		and (
			int(
				(
					(worker.get("authorization", {}) as Dictionary)
					. get(
						"world_attempt_count",
						-1,
					)
				)
			)
			== 0
		)
		and (
			int(
				(
					(worker.get("authorization", {}) as Dictionary)
					. get(
						"world_build_count",
						-1,
					)
				)
			)
			== 0
		)
		and (
			String(development.get("schema_version", ""))
			== "sporespore_qsdk_r23d2_development_contract_v1"
		)
		and String(development.get("campaign_id", "")) == CAMPAIGN_ID
		and String(development.get("gate_id", "")) == PARENT_GATE_ID
		and (
			String(development.get("status", ""))
			== "frozen_supervisor_only_physical_authorized_pending_exact_source_attestation"
		)
		and bool(
			(
				(development.get("authorization", {}) as Dictionary)
				. get("physical_execution_authorized", true)
			)
		)
		and int(
			(
				(development.get("claim_boundary", {}) as Dictionary)
				. get("physical_worker_implementation_count", -1)
			)
		) == 3
		and bool(
			(
				(worker.get("future_physical_requirements", {}) as Dictionary)
				. get("physical_implementation_present", false)
			)
		)
	)


static func _descriptor() -> Dictionary:
	var generation := ProportionSpecScript.compile_qsdk_r05_generation(GENERATOR_INDEX)
	if not bool(generation.get("ok", false)):
		return generation
	var proportion: Dictionary = generation["proportion_spec"]
	var descriptor := {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": String(proportion["morphology_id"]),
		"torso_length_scale": float(proportion["torso_length_scale"]),
		"torso_width_scale": float(proportion["torso_width_scale"]),
		"upper_length_fraction": float(proportion["upper_length_fraction"]),
		"hip_span_scale": float(proportion["hip_span_scale"]),
		"foot_radius_scale": float(proportion["foot_radius_scale"]),
		"front_limb_mass_scale": float(proportion["front_limb_mass_scale"]),
	}
	if String(descriptor["morphology_id"]) != MORPHOLOGY_ID:
		return _failure("QSDK_R23D2_GJT_MORPHOLOGY_ID_INVALID")
	return {"ok": true, "failure_code": "", "descriptor": descriptor}


static func _prepare_physical(contract: Dictionary, arm_id: String) -> Dictionary:
	if (
		String(contract.get("schema_version", ""))
		!= "sporespore_qsdk_r23d2_development_contract_v1"
		or String(contract.get("campaign_id", "")) != CAMPAIGN_ID
		or String(contract.get("gate_id", "")) != PARENT_GATE_ID
	):
		return _failure("QSDK_R23D2_GJT_DEVELOPMENT_CONTRACT_INVALID")
	var fixture_contract: Dictionary = contract.get("fixture", {})
	if (
		String(fixture_contract.get("morphology_id", "")) != MORPHOLOGY_ID
		or int(fixture_contract.get("initial_condition_seed", -1)) != CAMPAIGN_SEED
		or int(fixture_contract.get("physics_hz", -1)) != PHYSICS_HZ
		or absf(float(fixture_contract.get("authored_sliding_friction", NAN)) - 0.95)
		> 1.0e-15
	):
		return _failure("QSDK_R23D2_GJT_FIXTURE_CONTRACT_INVALID")
	var arm: Dictionary = {}
	for arm_value in contract.get("arms", []):
		var candidate: Dictionary = arm_value
		if String(candidate.get("arm_id", "")) == arm_id:
			arm = candidate
			break
	if arm.is_empty():
		return _failure("QSDK_R23D2_GJT_ARM_UNKNOWN")
	var generation := ProportionSpecScript.compile_qsdk_r05_generation(GENERATOR_INDEX)
	if not bool(generation.get("ok", false)):
		return generation
	var proportion_spec: Dictionary = generation["proportion_spec"]
	var descriptor := {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": String(proportion_spec["morphology_id"]),
		"torso_length_scale": float(proportion_spec["torso_length_scale"]),
		"torso_width_scale": float(proportion_spec["torso_width_scale"]),
		"upper_length_fraction": float(proportion_spec["upper_length_fraction"]),
		"hip_span_scale": float(proportion_spec["hip_span_scale"]),
		"foot_radius_scale": float(proportion_spec["foot_radius_scale"]),
		"front_limb_mass_scale": float(proportion_spec["front_limb_mass_scale"]),
	}
	if CanonicalJsonScript.encode(descriptor) != CanonicalJsonScript.encode(
		fixture_contract.get("descriptor", {})
	):
		return _failure("QSDK_R23D2_GJT_DESCRIPTOR_MISMATCH")
	var proportion_compilation := ProportionSpecScript.compile(proportion_spec)
	if not bool(proportion_compilation.get("ok", false)):
		return proportion_compilation
	var material_result := MaterialProfilesScript.resolve(MATERIAL_PROFILE_ID)
	if not bool(material_result.get("ok", false)):
		return material_result
	var fixture_candidate: Dictionary = (
		(proportion_compilation["fixture_spec"] as Dictionary).duplicate(true)
	)
	fixture_candidate["contact_material"] = (
		(material_result["profile"] as Dictionary)["body_material"] as Dictionary
	).duplicate(true)
	var fixture_result := FixtureSpecScript.compile(fixture_candidate)
	if not bool(fixture_result.get("ok", false)):
		return fixture_result
	var fixture: Dictionary = fixture_result["fixture_spec"]
	var perturbation_result := WaveGaitScript.compile_seeded_initial_perturbation(CAMPAIGN_SEED)
	if not bool(perturbation_result.get("ok", false)):
		return perturbation_result
	var initial_perturbation: Dictionary = perturbation_result["initial_perturbation"]
	if CanonicalJsonScript.encode(_json_initial_perturbation(initial_perturbation)) != (
		CanonicalJsonScript.encode(fixture_contract.get("initial_perturbation", {}))
	):
		return _failure("QSDK_R23D2_GJT_INITIAL_PERTURBATION_MISMATCH")
	var clock_result := ClockSpecScript.compile(ClockSpecScript.gq15_clock())
	if not bool(clock_result.get("ok", false)):
		return clock_result
	var schedule := _schedule_from_contract(
		contract.get("command_schedule", {}),
		float(arm["turn_heading_offset_rad"]),
	)
	var schedule_result := WaveGaitScript.compile_sdk_heading_schedule_options(schedule)
	if not bool(schedule_result.get("ok", false)):
		return schedule_result
	return {
		"ok": true,
		"failure_code": "",
		"contract_sha256": _raw_file_sha256(DEVELOPMENT_CONTRACT_PATH),
		"arm_id": arm_id,
		"turn_heading_offset_rad": float(arm["turn_heading_offset_rad"]),
		"descriptor": descriptor,
		"fixture_spec": fixture,
		"initial_perturbation": initial_perturbation,
		"gait_clock_options": clock_result["gait_clock_options"],
		"material_profile": material_result["profile"],
		"evidence_threshold_options": _evidence_thresholds(fixture),
		"authority_options":
		{
			"enabled": true,
			"descriptor": descriptor,
			"comparison_tolerance": SDK_COMPARISON_TOLERANCE,
			"authority_scope": "post_settle_full",
			"stability_policy_id": STABILITY_POLICY_ID,
			"material_profile_id": MATERIAL_PROFILE_ID,
			"controller_policy_id": POLICY_ID,
		},
		"schedule": schedule,
		"schedule_sha256": String(schedule_result["sdk_heading_schedule_sha256"]),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _run_wave(prepared: Dictionary, preflight_before_world: bool) -> Dictionary:
	return await (
		WaveGaitScript
		. new()
		. run(
			self,
			-1.0,
			10.0,
			1.75,
			"lateral",
			72,
			0.40,
			"all",
			112,
			false,
			prepared["initial_perturbation"],
			ROBUSTNESS_OPTIONS,
			prepared["fixture_spec"],
			HOST_OBSERVER_PATH_OPTIONS,
			ACTUATOR_IMPULSE_OPTIONS,
			HOST_PREAUTHORITY_MOTOR_OPTIONS,
			prepared["evidence_threshold_options"],
			prepared["gait_clock_options"],
			SOLVER_POLICY_OPTIONS,
			{},
			{},
			prepared["authority_options"],
			{},
			{},
			preflight_before_world,
			{},
			prepared["schedule"],
		)
	)


static func _physical_authorization_exact(
	contract: Dictionary,
	arm_id: String,
	source_commit: String,
) -> bool:
	var authorization: Dictionary = contract.get("authorization", {})
	if not bool(authorization.get("physical_execution_authorized", false)):
		return false
	var attempt_path := OS.get_environment(ATTEMPT_PATH_ENVIRONMENT_VARIABLE)
	var authorization_token := OS.get_environment(AUTHORIZATION_TOKEN_ENVIRONMENT_VARIABLE)
	var cell_id := "%s__%s" % [ENGINE_ID, arm_id]
	if (
		attempt_path.is_empty()
		or not FileAccess.file_exists(attempt_path)
		or OS.get_environment(CELL_ID_ENVIRONMENT_VARIABLE) != cell_id
		or OS.get_environment(ENGINE_ID_ENVIRONMENT_VARIABLE) != ENGINE_ID
		or not _valid_lower_hex(authorization_token, 32)
	):
		return false
	var attempt := _read_json(attempt_path)
	return (
		String(attempt.get("schema_version", ""))
		== "sporespore_qsdk_r23d2_attempt_v1"
		and String(attempt.get("campaign_id", "")) == CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == PARENT_GATE_ID
		and String(attempt.get("contract_sha256", ""))
		== _raw_file_sha256(DEVELOPMENT_CONTRACT_PATH)
		and String(attempt.get("source_commit", "")) == source_commit
		and String(attempt.get("origin_main_commit", "")) == source_commit
		and String(attempt.get("live_main_commit", "")) == source_commit
		and String(attempt.get("authorization_token", "")) == authorization_token
		and _valid_lower_hex(String(attempt.get("attempt_id", "")), 32)
		and bool(attempt.get("physical_execution_authorized", false))
		and bool(attempt.get("single_use_supervisor_authorization", false))
		and bool(attempt.get("source_worktree_clean", false))
		and bool(attempt.get("source_matches_live_github_main", false))
		and bool(attempt.get("operation_lock_held", false))
		and bool(attempt.get("full_godot_attestation_valid", false))
		and bool(attempt.get("content_addressed_inputs_retained", false))
		and bool(attempt.get("one_shot_attempt_unconsumed", false))
		and attempt.get("ordered_cell_ids", [])
		== [
			"godot_jolt__reference_zero",
			"godot_jolt__positive_heading",
			"godot_jolt__negative_heading",
			"rapier_parry__reference_zero",
			"rapier_parry__positive_heading",
			"rapier_parry__negative_heading",
			"mujoco__reference_zero",
			"mujoco__positive_heading",
			"mujoco__negative_heading",
		]
		and cell_id in (attempt.get("ordered_cell_ids", []) as Array)
	)


static func _apply_solver_configuration() -> Dictionary:
	Engine.physics_ticks_per_second = PHYSICS_HZ
	(
		ProjectSettings
		. set_setting(
			"physics/jolt_physics_3d/simulation/velocity_steps",
			20,
		)
	)
	(
		ProjectSettings
		. set_setting(
			"physics/jolt_physics_3d/simulation/position_steps",
			7,
		)
	)
	var realized := {
		"solver_policy_id": String(SOLVER_POLICY_OPTIONS["solver_policy_id"]),
		"physics_engine": String(ProjectSettings.get_setting("physics/3d/physics_engine", "")),
		"physics_hz": Engine.physics_ticks_per_second,
		"solver_velocity_steps":
		int(
			(
				ProjectSettings
				. get_setting(
					"physics/jolt_physics_3d/simulation/velocity_steps",
					-1,
				)
			)
		),
		"solver_position_steps":
		int(
			(
				ProjectSettings
				. get_setting(
					"physics/jolt_physics_3d/simulation/position_steps",
					-1,
				)
			)
		),
	}
	var exact := realized == SOLVER_POLICY_OPTIONS
	return {
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R23D2_GJT_SOLVER_POLICY_INVALID",
		"realized_solver_policy": realized,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _state_for_canary(
	morphology: Dictionary,
	canary: Dictionary,
	adapter_capability_sha256: String,
) -> Dictionary:
	var lateral := _vec3(canary["task_lateral_axis_world_unit"])
	var forward := {"x": lateral["z"], "y": 0.0, "z": -float(lateral["x"])}
	var heading := float(canary["measured_heading_world_rad"])
	var joint_observations: Array[Dictionary] = []
	for joint_id_value in morphology["ordered_joint_ids"]:
		(
			joint_observations
			. append(
				{
					"joint_id": String(joint_id_value),
					"position_rad": 0.0,
					"velocity_rad_s": 0.0,
					"anchor_error_m": 0.0,
					"validity":
					{
						"position": true,
						"velocity": true,
						"anchor_error": true,
					},
				}
			)
		)
	var contact_observations: Array[Dictionary] = []
	for contact_id_value in morphology["ordered_contact_site_ids"]:
		var contact_id := String(contact_id_value)
		(
			contact_observations
			. append(
				{
					"contact_site_id": contact_id,
					"presence": true,
					"bears_support": true,
					"normal_load_n": null,
					"provenance":
					{
						"adapter_id": "godot_jolt_gdextension_v1",
						"engine_contact_ids": ["%s_r23d2_zero_world" % contact_id],
						"aggregation_rule_id": "qualified_bearing_only",
						"quality": "qualified_bearing",
					},
				}
			)
		)
	return {
		"schema_version": "sporespore_state_frame_v1",
		"semantic_step": 0,
		"sample_time_s": 0.0,
		"base_pose_world":
		{
			"position_m": _vec3(canary["base_position_world_m"]),
			"orientation_xyzw":
			{
				"x": 0.0,
				"y": -sin(heading / 2.0),
				"z": 0.0,
				"w": cos(heading / 2.0),
			},
		},
		"base_twist_world":
		{
			"linear_velocity_m_s": _vec3(canary["base_linear_velocity_world_m_s"]),
			"angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
		},
		"ordered_joint_observations": joint_observations,
		"ordered_contact_observations": contact_observations,
		"previous_applied_actuation": null,
		"gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
		"task_frame":
		{
			"origin_world_m": _vec3(canary["task_origin_world_m"]),
			"forward_axis_world_unit": forward,
			"lateral_axis_world_unit": lateral,
			"up_axis_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
			"reference_yaw_rad": float(canary["reference_yaw_rad"]),
		},
		"adapter_capability_sha256": adapter_capability_sha256,
	}


static func _command(command_id: String, desired_heading_rad: float) -> Dictionary:
	return {
		"schema_version": "sporespore_motion_command_v2",
		"command_id": command_id,
		"desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
		"desired_heading_rad": desired_heading_rad,
		"desired_yaw_rate_rad_s": null,
		"gait_family_id": "lateral_wave",
		"speed_class": "walk",
		"gait_amplitude": 1.0,
		"phase_progression_mode": "clocked",
		"valid_from_step": 0,
		"valid_through_step": 0,
		"authority": "test_fixture",
	}


static func _independent_oracle(
	state: Dictionary,
	command: Dictionary,
	profile: Dictionary,
) -> Dictionary:
	var position: Dictionary = state["base_pose_world"]["position_m"]
	var origin: Dictionary = state["task_frame"]["origin_world_m"]
	var displacement := {
		"x": float(position["x"]) - float(origin["x"]),
		"y": float(position["y"]) - float(origin["y"]),
		"z": float(position["z"]) - float(origin["z"]),
	}
	var lateral: Dictionary = state["task_frame"]["lateral_axis_world_unit"]
	var cross_track_error := _dot(displacement, lateral)
	var cross_track_velocity := _dot(
		state["base_twist_world"]["linear_velocity_m_s"],
		lateral,
	)
	var quaternion: Dictionary = state["base_pose_world"]["orientation_xyzw"]
	var forward_x := (
		1.0
		- (
			2.0
			* (
				float(quaternion["y"]) * float(quaternion["y"])
				+ float(quaternion["z"]) * float(quaternion["z"])
			)
		)
	)
	var forward_z := (
		2.0
		* (
			float(quaternion["x"]) * float(quaternion["z"])
			- float(quaternion["w"]) * float(quaternion["y"])
		)
	)
	var measured_heading := atan2(forward_z, forward_x)
	var reference_yaw := float(state["task_frame"]["reference_yaw_rad"])
	var measured_error := _wrap_angle(measured_heading - reference_yaw)
	var requested_error := _wrap_angle(float(command["desired_heading_rad"]) - reference_yaw)
	var desired_error := clampf(
		(
			requested_error
			- float(profile["cross_track_heading_gain_rad_per_m"]) * cross_track_error
			- float(profile["cross_track_velocity_heading_gain_rad_per_m_s"]) * cross_track_velocity
		),
		-0.25,
		0.25,
	)
	return {
		"cross_track_error_m": cross_track_error,
		"cross_track_velocity_m_s": cross_track_velocity,
		"measured_yaw_error_rad": measured_error,
		"desired_heading_error_rad": desired_error,
		"yaw_tracking_error_rad": _wrap_angle(measured_error - desired_error),
	}


static func _claims() -> Dictionary:
	return {
		"development_screen_only": true,
		"q_sdk_r23_satisfied": false,
		"command_conditioned_turning": false,
		"cross_engine_equivalence": false,
		"release_authorized": false,
		"physical_acceptance_authority": false,
	}


static func _physical_execution_failure(summary: Dictionary) -> String:
	var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var heading: Dictionary = summary.get("sdk_heading_schedule_receipt", {})
	var validation: Dictionary = sdk_summary.get(
		"balanced_wave_command_validation_summary",
		{},
	)
	var direct_body_write_count := (
		int(summary.get("direct_torso_force_command_count", -1))
		+ int(summary.get("direct_torso_impulse_command_count", -1))
		+ int(summary.get("direct_torso_velocity_command_count", -1))
		+ int(summary.get("direct_torso_transform_command_count", -1))
	)
	if int(summary.get("world_build_count", -1)) != 1:
		return "QSDK_R23D2_GJT_WORLD_BUILD_COUNT_INVALID"
	if int(summary.get("world_reset_count", -1)) != 0:
		return "QSDK_R23D2_GJT_WORLD_RESET_COUNT_INVALID"
	if direct_body_write_count != 0:
		return "QSDK_R23D2_GJT_DIRECT_BODY_WRITE_INVALID"
	if (
		not bool(sdk_summary.get("ok", false))
		or not (sdk_summary.get("failure_codes", []) as Array).is_empty()
		or int(sdk_summary.get("step_count", -1)) != CONTROLLER_STEPS
		or int(sdk_summary.get("safe_no_actuation_count", -1)) != 0
		or int(sdk_summary.get("mismatch_count", -1)) != 0
		or int(sdk_summary.get("validated_balanced_wave_command_count", -1))
		!= CONTROLLER_STEPS * 8
		or int(sdk_summary.get("native_actuation_application_count", -1))
		!= CONTROLLER_STEPS * 8
	):
		return "QSDK_R23D2_GJT_SDK_EXECUTION_INVALID"
	if (
		not bool(validation.get("ok", false))
		or String(validation.get("validation_mode", "")) != SOURCE_VALIDATION_MODE
		or int(validation.get("native_validation_step_count", -1)) != CONTROLLER_STEPS
		or int(validation.get("heading_command_conditioned_step_count", -1))
		!= CONTROLLER_STEPS
		or int(validation.get("unconditioned_step_count", -1)) != 0
	):
		return "QSDK_R23D2_GJT_SOURCE_VALIDATION_INVALID"
	if (
		String(heading.get("command_failure_code", "")) != ""
		or heading.get("observed_segment_sample_counts", {})
		!= {"reference_warmup": 600, "commanded_turn": 1200, "reference_recovery": 600}
		or int(heading.get("reference_heading_sample_count", -1)) != 1200
		or int(heading.get("turn_heading_sample_count", -1)) != 1200
	):
		return "QSDK_R23D2_GJT_HEADING_SCHEDULE_INVALID"
	return ""


static func _validate_physical_oracle_trace(
	summary: Dictionary,
	profile: Dictionary,
) -> Dictionary:
	var execution_failure := _physical_execution_failure(summary)
	if not execution_failure.is_empty():
		return {
			"ok": false,
			"failure_code": execution_failure,
			"controller_receipt_rejected": false,
		}
	var sdk_summary: Dictionary = summary["sdk_authority_summary"]
	var trace: Dictionary = sdk_summary.get("r23d2_oracle_trace", {})
	var rows: Array = trace.get("rows", [])
	if (
		String(trace.get("schema_version", ""))
		!= "sporespore_qsdk_r23d2_godot_jolt_oracle_trace_v1"
		or not bool(trace.get("enabled", false))
		or String(trace.get("controller_profile_sha256", ""))
		!= String(sdk_summary.get("controller_profile_sha256", ""))
		or int(trace.get("step_count", -1)) != CONTROLLER_STEPS
		or rows.size() != CONTROLLER_STEPS
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R23D2_GJT_ORACLE_TRACE_HEADER_INVALID",
			"controller_receipt_rejected": false,
		}
	for semantic_step in range(rows.size()):
		var row_value: Variant = rows[semantic_step]
		if typeof(row_value) != TYPE_DICTIONARY:
			return {
				"ok": false,
				"failure_code": "QSDK_R23D2_GJT_ORACLE_TRACE_ROW_TYPE_INVALID",
				"controller_receipt_rejected": false,
			}
		var row: Dictionary = row_value
		if (
			not _keys_exact(
				row,
				[
					"schema_version",
					"semantic_step",
					"state_frame_sha256",
					"motion_command_sha256",
					"controller_receipt_sha256",
					"controller_profile_sha256",
					"oracle_state_projection",
					"oracle_command_projection",
					"controller_receipt_projection",
					"physical_acceptance_authority",
				],
			)
			or String(row.get("schema_version", ""))
			!= "sporespore_qsdk_r23d2_godot_jolt_oracle_trace_row_v1"
			or int(row.get("semantic_step", -1)) != semantic_step
			or not _valid_prefixed_sha256(String(row.get("state_frame_sha256", "")))
			or not _valid_prefixed_sha256(String(row.get("motion_command_sha256", "")))
			or not _valid_prefixed_sha256(String(row.get("controller_receipt_sha256", "")))
			or String(row.get("controller_profile_sha256", ""))
			!= String(trace["controller_profile_sha256"])
			or bool(row.get("physical_acceptance_authority", true))
		):
			return {
				"ok": false,
				"failure_code": "QSDK_R23D2_GJT_ORACLE_TRACE_ROW_INVALID:%d" % semantic_step,
				"controller_receipt_rejected": false,
			}
		var oracle_input := _trace_oracle_input(row, profile)
		var recomputation := _projected_oracle(oracle_input)
		if not bool(recomputation.get("ok", false)):
			return {
				"ok": false,
				"failure_code": (
					"QSDK_R23D2_GJT_ORACLE_INPUT_INVALID:%d:%s"
					% [semantic_step, String(recomputation.get("failure_code", "UNKNOWN"))]
				),
				"controller_receipt_rejected": false,
			}
		var expected: Dictionary = recomputation["expected_receipt"]
		var observed: Dictionary = row.get("controller_receipt_projection", {})
		if not _keys_exact(observed, RECEIPT_FIELDS):
			return {
				"ok": false,
				"failure_code": "QSDK_R23D2_GJT_RECEIPT_PROJECTION_INVALID:%d" % semantic_step,
				"controller_receipt_rejected": false,
			}
		var failures := _predicate_failures(expected, observed)
		if not failures.is_empty():
			return {
				"ok": false,
				"failure_code": (
					"QSDK_R23D2_GJT_CONTROLLER_RECEIPT_INVALID:%d:%s"
					% [semantic_step, ",".join(failures)]
				),
				"controller_receipt_rejected": true,
				"rejected_controller_projection": observed.duplicate(true),
				"oracle_input": oracle_input.duplicate(true),
				"oracle_evaluation": _oracle_evaluation(expected, observed),
			}
	return {
		"ok": true,
		"failure_code": "",
		"controller_receipt_rejected": false,
		"independent_oracle_validation_step_count": CONTROLLER_STEPS,
		"accepted_receipt_count": CONTROLLER_STEPS,
		"rejected_receipt_count": 0,
		"predicate_failure_count": 0,
		"raw_heading_offset_equality_used": false,
	}


static func _trace_oracle_input(row: Dictionary, profile: Dictionary) -> Dictionary:
	var state_projection: Dictionary = row.get("oracle_state_projection", {})
	var command_projection: Dictionary = row.get("oracle_command_projection", {})
	var orientation: Dictionary = state_projection.get("base_orientation_xyzw", {})
	var quaternion_x := float(orientation.get("x", NAN))
	var quaternion_y := float(orientation.get("y", NAN))
	var quaternion_z := float(orientation.get("z", NAN))
	var quaternion_w := float(orientation.get("w", NAN))
	var measured_heading := atan2(
		2.0 * (quaternion_x * quaternion_z - quaternion_w * quaternion_y),
		1.0 - 2.0 * (quaternion_y * quaternion_y + quaternion_z * quaternion_z),
	)
	return {
		"state":
		{
			"reference_yaw_rad": state_projection.get("reference_yaw_rad", null),
			"measured_heading_world_rad": measured_heading,
			"task_origin_world_m": _vector_dictionary_to_array(
				state_projection.get("task_origin_world_m", {}),
			),
			"task_lateral_axis_world_unit": _vector_dictionary_to_array(
				state_projection.get("task_lateral_axis_world_unit", {}),
			),
			"base_position_world_m": _vector_dictionary_to_array(
				state_projection.get("base_position_world_m", {}),
			),
			"base_linear_velocity_world_m_s": _vector_dictionary_to_array(
				state_projection.get("base_linear_velocity_world_m_s", {}),
			),
		},
		"command":
		{
			"desired_heading_rad": command_projection.get("desired_heading_rad", null),
		},
		"profile": profile.duplicate(true),
	}


static func _projected_oracle(oracle_input: Dictionary) -> Dictionary:
	var state: Dictionary = oracle_input.get("state", {})
	var command: Dictionary = oracle_input.get("command", {})
	var profile: Dictionary = oracle_input.get("profile", {})
	if (
		not _keys_exact(
			state,
			[
				"reference_yaw_rad",
				"measured_heading_world_rad",
				"task_origin_world_m",
				"task_lateral_axis_world_unit",
				"base_position_world_m",
				"base_linear_velocity_world_m_s",
			],
		)
		or not _keys_exact(command, ["desired_heading_rad"])
	):
		return {"ok": false, "failure_code": "ORACLE_KEYS_INVALID"}
	var reference_yaw := float(state.get("reference_yaw_rad", NAN))
	var measured_heading := float(state.get("measured_heading_world_rad", NAN))
	var desired_heading := float(command.get("desired_heading_rad", NAN))
	var heading_gain := float(profile.get("cross_track_heading_gain_rad_per_m", NAN))
	var velocity_gain := float(
		profile.get("cross_track_velocity_heading_gain_rad_per_m_s", NAN),
	)
	var maximum_heading_error := float(profile.get("maximum_desired_heading_error_rad", NAN))
	var origin: Array = state.get("task_origin_world_m", [])
	var lateral: Array = state.get("task_lateral_axis_world_unit", [])
	var position: Array = state.get("base_position_world_m", [])
	var velocity: Array = state.get("base_linear_velocity_world_m_s", [])
	if (
		not _finite_array(origin, 3)
		or not _finite_array(lateral, 3)
		or not _finite_array(position, 3)
		or not _finite_array(velocity, 3)
		or not is_finite(reference_yaw)
		or not is_finite(measured_heading)
		or not is_finite(desired_heading)
		or not is_finite(heading_gain)
		or not is_finite(velocity_gain)
		or not is_finite(maximum_heading_error)
		or maximum_heading_error <= 0.0
	):
		return {"ok": false, "failure_code": "ORACLE_NONFINITE"}
	var lateral_norm := sqrt(
		float(lateral[0]) * float(lateral[0])
		+ float(lateral[1]) * float(lateral[1])
		+ float(lateral[2]) * float(lateral[2])
	)
	if absf(lateral_norm - 1.0) > ORACLE_TOLERANCE:
		return {"ok": false, "failure_code": "ORACLE_LATERAL_NOT_UNIT"}
	var displacement := [
		float(position[0]) - float(origin[0]),
		float(position[1]) - float(origin[1]),
		float(position[2]) - float(origin[2]),
	]
	var cross_track_error := _dot_arrays(displacement, lateral)
	var cross_track_velocity := _dot_arrays(velocity, lateral)
	var requested_error := _wrap_angle(desired_heading - reference_yaw)
	var measured_error := _wrap_angle(measured_heading - reference_yaw)
	var desired_error := clampf(
		requested_error - heading_gain * cross_track_error - velocity_gain * cross_track_velocity,
		-maximum_heading_error,
		maximum_heading_error,
	)
	return {
		"ok": true,
		"failure_code": "",
		"expected_receipt":
		{
			"cross_track_error_m": cross_track_error,
			"cross_track_velocity_m_s": cross_track_velocity,
			"measured_yaw_error_rad": measured_error,
			"desired_heading_error_rad": desired_error,
			"yaw_tracking_error_rad": _wrap_angle(measured_error - desired_error),
		},
	}


static func _oracle_evaluation(expected: Dictionary, observed: Dictionary) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r23d2_oracle_evaluation_v1",
		"ok": _predicate_failures(expected, observed).is_empty(),
		"failed_predicates": _predicate_failures(expected, observed),
		"expected_receipt": expected.duplicate(true),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _compose_physical_report(
	prepared: Dictionary,
	summary: Dictionary,
	source_commit: String,
	oracle_validation: Dictionary,
) -> Dictionary:
	var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var heading: Dictionary = summary.get("sdk_heading_schedule_receipt", {})
	var source_command_validation: Dictionary = sdk_summary.get(
		"balanced_wave_command_validation_summary",
		{},
	)
	var direct_body_write_count := (
		int(summary.get("direct_torso_force_command_count", -1))
		+ int(summary.get("direct_torso_impulse_command_count", -1))
		+ int(summary.get("direct_torso_velocity_command_count", -1))
		+ int(summary.get("direct_torso_transform_command_count", -1))
	)
	var failure_codes: Array = sdk_summary.get("failure_codes", [])
	var nonfinite_observation_count := 0
	for failure_code_value in failure_codes:
		if String(failure_code_value).contains("NONFINITE"):
			nonfinite_observation_count += 1
	var step_count := int(sdk_summary.get("step_count", -1))
	return {
		"schema_version": REPORT_SCHEMA,
		"campaign_id": CAMPAIGN_ID,
		"gate_id": PARENT_GATE_ID,
		"cell_id": "%s__%s" % [ENGINE_ID, String(prepared["arm_id"])],
		"engine_id": ENGINE_ID,
		"arm_id": String(prepared["arm_id"]),
		"source_commit": source_commit,
		"contract_sha256": String(prepared["contract_sha256"]),
		"selected_policy_id": POLICY_ID,
		"selected_policy_digest": POLICY_DIGEST,
		"morphology_id": MORPHOLOGY_ID,
		"campaign_seed": CAMPAIGN_SEED,
		"execution":
		{
			"world_attempt_count": 1,
			"world_build_count": int(summary.get("world_build_count", -1)),
			"world_reset_count": int(summary.get("world_reset_count", -1)),
			"direct_body_write_count": direct_body_write_count,
			"controller_error_count": failure_codes.size(),
			"safe_no_actuation_count": int(sdk_summary.get("safe_no_actuation_count", -1)),
			"nonfinite_observation_count": nonfinite_observation_count,
			"actuator_application_mismatch_count": int(sdk_summary.get("mismatch_count", -1)),
			"controller_semantic_step_count": step_count,
			"validated_portable_command_count":
			int(sdk_summary.get("validated_balanced_wave_command_count", -1)),
			"native_actuation_application_count":
			int(sdk_summary.get("native_actuation_application_count", -1)),
		},
		"execution_stage":
		{
			"schema_version": EXECUTION_STAGE_SCHEMA,
			"stage_id": "cell_report_complete",
			"world_attempt_count": 1,
			"world_build_count": 1,
		},
		"command_validation":
		{
			"schema_version": COMMAND_VALIDATION_SCHEMA,
			"normalized_validation_mode": NORMALIZED_VALIDATION_MODE,
			"source_validation_mode": String(source_command_validation.get("validation_mode", "")),
			"native_validation_step_count":
			int(source_command_validation.get("native_validation_step_count", -1)),
			"heading_command_conditioned_step_count":
			int(source_command_validation.get("heading_command_conditioned_step_count", -1)),
			"unconditioned_step_count":
			int(source_command_validation.get("unconditioned_step_count", -1)),
			"legacy_command_parity_applicable": false,
			"legacy_command_parity_checked_step_count": 0,
			"legacy_command_parity_waived_step_count": 0,
			"oracle_contract_sha256": _raw_file_sha256(ORACLE_PATH),
			"independent_oracle_validation_step_count":
			int(oracle_validation["independent_oracle_validation_step_count"]),
			"accepted_receipt_count": int(oracle_validation["accepted_receipt_count"]),
			"rejected_receipt_count": int(oracle_validation["rejected_receipt_count"]),
			"predicate_failure_count": int(oracle_validation["predicate_failure_count"]),
			"raw_heading_offset_equality_used": false,
		},
		"schedule":
		{
			"schedule_id": SCHEDULE_ID,
			"turn_heading_offset_rad": float(prepared["turn_heading_offset_rad"]),
			"observed_segment_sample_counts":
			(heading.get("observed_segment_sample_counts", {}) as Dictionary).duplicate(true),
			"reference_heading_sample_count": int(heading.get("reference_heading_sample_count", -1)),
			"turn_heading_sample_count": int(heading.get("turn_heading_sample_count", -1)),
		},
		"controller":
		{
			"maximum_absolute_requested_steering_fraction":
			float(heading.get("maximum_absolute_requested_steering_fraction", NAN)),
			"maximum_absolute_held_steering_fraction":
			float(heading.get("maximum_absolute_held_steering_fraction", NAN)),
			"mean_turn_held_steering_fraction":
			float(heading.get("mean_turn_held_steering_fraction", NAN)),
		},
		"physics":
		{
			"turn_phase_yaw_delta_rad": float(heading.get("turn_phase_yaw_delta_rad", NAN)),
			"final_reference_heading_error_rad":
			float(heading.get("final_reference_heading_error_rad", NAN)),
			"final_forward_displacement_m":
			float(summary.get("final_task_frame_forward_displacement_m", NAN)),
			"maximum_tilt_rad": float(summary.get("maximum_tilt_rad", NAN)),
			"minimum_torso_height_m": float(summary.get("minimum_torso_height_m", NAN)),
			"torso_ground_contact_step_count": int(summary.get("torso_contact_ticks", -1)),
			"contact_cycles_by_limb":
			(summary.get("contact_cycle_count_by_limb", {}) as Dictionary).duplicate(true),
			"engine_production_straight_walking_gate_passed":
			bool(summary.get("physical_wave_gait_walking_observed", false)),
			"commanded_turn_walk_gate_passed":
			bool(summary.get("physical_wave_gait_walking_observed", false)),
		},
		"claims": _claims(),
	}


static func _synthetic_physical_report(prepared: Dictionary) -> Dictionary:
	var offset := float(prepared["turn_heading_offset_rad"])
	var mean_turn_steering := 0.0
	var turn_yaw_delta := 0.0
	if offset > 0.0:
		mean_turn_steering = -0.1
		turn_yaw_delta = 0.1
	elif offset < 0.0:
		mean_turn_steering = 0.1
		turn_yaw_delta = -0.1
	var synthetic_summary := {
		"world_build_count": 1,
		"world_reset_count": 0,
		"direct_torso_force_command_count": 0,
		"direct_torso_impulse_command_count": 0,
		"direct_torso_velocity_command_count": 0,
		"direct_torso_transform_command_count": 0,
		"sdk_authority_summary":
		{
			"ok": true,
			"failure_codes": [],
			"safe_no_actuation_count": 0,
			"mismatch_count": 0,
			"step_count": CONTROLLER_STEPS,
			"validated_balanced_wave_command_count": CONTROLLER_STEPS * 8,
			"native_actuation_application_count": CONTROLLER_STEPS * 8,
			"balanced_wave_command_validation_summary":
			{
				"validation_mode": SOURCE_VALIDATION_MODE,
				"native_validation_step_count": CONTROLLER_STEPS,
				"heading_command_conditioned_step_count": CONTROLLER_STEPS,
				"unconditioned_step_count": 0,
			},
		},
		"sdk_heading_schedule_receipt":
		{
			"observed_segment_sample_counts":
			{"reference_warmup": 600, "commanded_turn": 1200, "reference_recovery": 600},
			"reference_heading_sample_count": 1200,
			"turn_heading_sample_count": 1200,
			"maximum_absolute_requested_steering_fraction": 0.3,
			"maximum_absolute_held_steering_fraction": 0.25,
			"mean_turn_held_steering_fraction": mean_turn_steering,
			"turn_phase_yaw_delta_rad": turn_yaw_delta,
			"final_reference_heading_error_rad": 0.02,
		},
		"final_task_frame_forward_displacement_m": 0.5,
		"maximum_tilt_rad": 0.2,
		"minimum_torso_height_m": 0.4,
		"torso_contact_ticks": 0,
		"contact_cycle_count_by_limb":
		{
			"front_left": 3,
			"front_right": 3,
			"rear_left": 3,
			"rear_right": 3,
		},
		"physical_wave_gait_walking_observed": true,
	}
	return _compose_physical_report(
		prepared,
		synthetic_summary,
		"a".repeat(40),
		{
			"independent_oracle_validation_step_count": CONTROLLER_STEPS,
			"accepted_receipt_count": CONTROLLER_STEPS,
			"rejected_receipt_count": 0,
			"predicate_failure_count": 0,
		},
	)


static func _synthetic_failure_receipts(
	arm_id: String,
	oracle_contract: Dictionary,
) -> Array[Dictionary]:
	var receipts: Array[Dictionary] = []
	var source_commit := "a".repeat(40)
	for stage_value in [
		["before_world", 0, 0],
		["world_construction_failed", 1, 0],
		["world_constructed", 1, 1],
		["settlement_complete", 1, 1],
		["cell_report_complete", 1, 1],
	]:
		var stage: Array = stage_value
		receipts.append(
			_worker_failure(
				arm_id,
				source_commit,
				String(stage[0]),
				int(stage[1]),
				int(stage[2]),
				"QSDK_R23D2_GJT_SYNTHETIC_%s" % String(stage[0]).to_upper(),
			)
		)
	var canary: Dictionary = oracle_contract["oracle_canaries"][1]
	var oracle_input := {
		"state":
		{
			"reference_yaw_rad": float(canary["reference_yaw_rad"]),
			"measured_heading_world_rad": float(canary["measured_heading_world_rad"]),
			"task_origin_world_m": (canary["task_origin_world_m"] as Array).duplicate(true),
			"task_lateral_axis_world_unit":
			(canary["task_lateral_axis_world_unit"] as Array).duplicate(true),
			"base_position_world_m":
			(canary["base_position_world_m"] as Array).duplicate(true),
			"base_linear_velocity_world_m_s":
			(canary["base_linear_velocity_world_m_s"] as Array).duplicate(true),
		},
		"command": {"desired_heading_rad": float(canary["desired_heading_rad"])},
		"profile":
		(oracle_contract["selected_profile_oracle"] as Dictionary).duplicate(true),
	}
	var recomputation := _projected_oracle(oracle_input)
	var expected: Dictionary = recomputation["expected_receipt"]
	var rejected := expected.duplicate(true)
	rejected["desired_heading_error_rad"] = (
		float(rejected["desired_heading_error_rad"]) + 1.0e-6
	)
	receipts.append(
		_worker_failure(
			arm_id,
			source_commit,
			"controller_validation_failed",
			1,
			1,
			"QSDK_R23D2_GJT_SYNTHETIC_CONTROLLER_VALIDATION_FAILED",
			rejected,
			oracle_input,
			_oracle_evaluation(expected, rejected),
		)
	)
	return receipts


static func _worker_failure(
	arm_id: String,
	source_commit: String,
	stage_id: String,
	world_attempt_count: int,
	world_build_count: int,
	process_failure_code: String,
	rejected_controller_projection: Variant = null,
	oracle_input: Variant = null,
	oracle_evaluation: Variant = null,
) -> Dictionary:
	var projection_retained := typeof(rejected_controller_projection) == TYPE_DICTIONARY
	var retained_projection: Variant = null
	if projection_retained:
		retained_projection = CanonicalJsonScript.normalize(rejected_controller_projection)
	var normalized_source_commit := source_commit
	if not _valid_lower_hex(normalized_source_commit, 40):
		normalized_source_commit = "0".repeat(40)
	return {
		"schema_version": WORKER_FAILURE_SCHEMA,
		"campaign_id": CAMPAIGN_ID,
		"gate_id": PARENT_GATE_ID,
		"cell_id": "%s__%s" % [ENGINE_ID, arm_id],
		"engine_id": ENGINE_ID,
		"arm_id": arm_id,
		"source_commit": normalized_source_commit,
		"contract_sha256": _raw_file_sha256(DEVELOPMENT_CONTRACT_PATH),
		"stage_id": stage_id,
		"world_attempt_count": world_attempt_count,
		"world_build_count": world_build_count,
		"process_failure_code": process_failure_code,
		"rejected_controller_projection":
		(retained_projection as Dictionary).duplicate(true)
		if projection_retained
		else null,
		"oracle_input":
		(oracle_input as Dictionary).duplicate(true)
		if typeof(oracle_input) == TYPE_DICTIONARY
		else null,
		"oracle_evaluation":
		(oracle_evaluation as Dictionary).duplicate(true)
		if typeof(oracle_evaluation) == TYPE_DICTIONARY
		else null,
		"rejected_projection_retention":
		{
			"schema_version": "sporespore_qsdk_r23d2_rejected_projection_retention_v1",
			"embedded_before_exit": projection_retained,
			"payload_sha256":
			CanonicalJsonScript.sha256(retained_projection)
			if projection_retained
			else null,
			"content_addressed_by_supervisor_before_aggregation_required": true,
		},
		"claims": _claims(),
	}


static func _physical_report_shape_exact(report: Dictionary) -> bool:
	return (
		_keys_exact(
			report,
			[
				"schema_version",
				"campaign_id",
				"gate_id",
				"cell_id",
				"engine_id",
				"arm_id",
				"source_commit",
				"contract_sha256",
				"selected_policy_id",
				"selected_policy_digest",
				"morphology_id",
				"campaign_seed",
				"execution",
				"execution_stage",
				"command_validation",
				"schedule",
				"controller",
				"physics",
				"claims",
			],
		)
		and String(report.get("schema_version", "")) == REPORT_SCHEMA
		and String(report.get("contract_sha256", ""))
		== _raw_file_sha256(DEVELOPMENT_CONTRACT_PATH)
		and not JSON.stringify(report).contains("null")
	)


static func _predicate_failures(
	expected: Dictionary,
	observed: Dictionary,
) -> Array[String]:
	var failures: Array[String] = []
	for field_value in RECEIPT_FIELDS:
		var field := String(field_value)
		var value: Variant = observed.get(field, null)
		if (
			(typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT)
			or not is_finite(float(value))
			or absf(float(value) - float(expected[field])) > ORACLE_TOLERANCE
		):
			failures.append("%s:mismatch" % field)
	return failures


static func _keys_exact(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key_value in expected_keys:
		if not value.has(String(key_value)):
			return false
	return true


static func _valid_prefixed_sha256(value: String) -> bool:
	return value.begins_with("sha256:") and _valid_lower_hex(value.trim_prefix("sha256:"), 64)


static func _vector_dictionary_to_array(value: Variant) -> Array:
	if typeof(value) != TYPE_DICTIONARY:
		return []
	var vector: Dictionary = value
	return [vector.get("x", null), vector.get("y", null), vector.get("z", null)]


static func _finite_array(value: Array, expected_size: int) -> bool:
	if value.size() != expected_size:
		return false
	for component in value:
		if (
			(typeof(component) != TYPE_FLOAT and typeof(component) != TYPE_INT)
			or not is_finite(float(component))
		):
			return false
	return true


static func _dot_arrays(first: Array, second: Array) -> float:
	return (
		float(first[0]) * float(second[0])
		+ float(first[1]) * float(second[1])
		+ float(first[2]) * float(second[2])
	)


static func _schedule_from_contract(
	schedule_contract: Dictionary,
	turn_offset_rad: float,
) -> Dictionary:
	var segments: Array = []
	for segment_value in schedule_contract.get("segments", []):
		var source: Dictionary = segment_value
		var turn_segment := (
			String(source.get("heading_offset_source", ""))
			== "arm.turn_heading_offset_rad"
		)
		segments.append(
			{
				"segment_id": String(source["segment_id"]),
				"start_step_inclusive": int(source["start_step_inclusive"]),
				"end_step_exclusive": int(source["end_step_exclusive"]),
				"heading_offset_rad": turn_offset_rad if turn_segment else 0.0,
				"command_role": "turn_heading" if turn_segment else "reference_heading",
			}
		)
	return {
		"schema_version": String(schedule_contract["schema_version"]),
		"schedule_id": String(schedule_contract["schedule_id"]),
		"domain": String(schedule_contract["domain"]),
		"reference_heading_source": String(schedule_contract["reference_heading_source"]),
		"segments": segments,
		"after_last_segment": String(schedule_contract["after_last_segment"]),
	}


static func _evidence_thresholds(fixture: Dictionary) -> Dictionary:
	var torso: Dictionary = fixture["torso"]
	var torso_size: Array = torso["size_m"]
	var initial_center: Array = torso["initial_center_m"]
	var first_limb: Dictionary = (fixture["limbs"] as Array)[0]
	return {
		"evidence_threshold_policy_id": "nonuniform_dimensionless_thresholds_v1",
		"minimum_foot_relocation_m": 0.0238 * float(torso_size[0]),
		"minimum_evidence_torso_advance_m": 0.080 * float(torso_size[0]),
		"minimum_final_torso_advance_m": 0.060 * float(torso_size[0]),
		"maximum_lateral_drift_m": 0.3125 * float(torso_size[2]),
		"maximum_yaw_drift_rad": 0.45,
		"maximum_tilt_rad": 0.60,
		"minimum_torso_height_m": (25.0 / 44.0) * float(initial_center[1]),
		"maximum_anchor_error_m": 0.14 * float(first_limb["upper_length_m"]),
		"maximum_hinge_axis_error_rad": 0.20,
	}


static func _json_initial_perturbation(value: Dictionary) -> Dictionary:
	var linear: Vector3 = value["initial_linear_velocity_world_m_s"]
	var angular: Vector3 = value["initial_torso_angular_velocity_world_rad_s"]
	return {
		"campaign_seed": int(value["campaign_seed"]),
		"fixture_vertical_clearance_m": float(value["fixture_vertical_clearance_m"]),
		"fixture_yaw_rad": float(value["fixture_yaw_rad"]),
		"initial_linear_velocity_world_m_s": [linear.x, linear.y, linear.z],
		"initial_torso_angular_velocity_world_rad_s": [angular.x, angular.y, angular.z],
		"gait_phase_offset_ticks": int(value["gait_phase_offset_ticks"]),
	}


static func _arm_offset(arm_id: String) -> float:
	match arm_id:
		"reference_zero":
			return 0.0
		"positive_heading":
			return 0.2
		"negative_heading":
			return -0.2
	return NAN


static func _vec3(value: Array) -> Dictionary:
	return {"x": float(value[0]), "y": float(value[1]), "z": float(value[2])}


static func _dot(first: Dictionary, second: Dictionary) -> float:
	return (
		float(first["x"]) * float(second["x"])
		+ float(first["y"]) * float(second["y"])
		+ float(first["z"]) * float(second["z"])
	)


static func _wrap_angle(value: float) -> float:
	return fposmod(value + PI, TAU) - PI


static func _raw_file_sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return "sha256:%s" % context.finish().hex_encode()


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _valid_lower_hex(value: String, expected_length: int) -> bool:
	if value.length() != expected_length:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _emit_worker_failure(
	arm_id: String,
	source_commit: String,
	stage_id: String,
	world_attempt_count: int,
	world_build_count: int,
	process_failure_code: String,
	rejected_controller_projection: Variant = null,
	oracle_input: Variant = null,
	oracle_evaluation: Variant = null,
) -> void:
	print(
		"QSDK_R23D2_GODOT_JOLT_FAILURE ",
		JSON.stringify(
			_worker_failure(
				arm_id,
				source_commit,
				stage_id,
				world_attempt_count,
				world_build_count,
				process_failure_code,
				rejected_controller_projection,
				oracle_input,
				oracle_evaluation,
			)
		),
	)
	quit(1)
