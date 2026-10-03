extends SceneTree
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Godot/Jolt worker for the finite QSDK-R23D1 heading-response screen.
##
## `preflight <arm_id>` reaches the exact physical entrypoint, compiles the
## fixture and schedule, and crosses a real BW5R-B native controller step while
## returning before fixture construction. `physical <arm_id> <source_commit>`
## is the only mode that may build one world. The campaign supervisor must
## remain the sole caller of physical mode after the full freeze is complete.

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

const CONTRACT_PATH := "res://sdk/turning/physical_development_contract_v1.json"
const CAMPAIGN_ID := "QSDK-R23D1-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
const GATE_ID := "QSDK-R23D1"
const ENGINE_ID := "godot_jolt"
const POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const POLICY_DIGEST := "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
const MORPHOLOGY_ID := "qsdk_r05_generated_s169"
const GENERATOR_INDEX := 169
const CAMPAIGN_SEED := 21501
const MATERIAL_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const STABILITY_POLICY_ID := "p5i3b_weight_support_shadow_v1"
const ATTEMPT_SCHEMA_VERSION := "sporespore_qsdk_r23d1_attempt_v1"
const ATTEMPT_PATH_ENVIRONMENT_VARIABLE := "SPORESPORE_QSDK_R23D1_ATTEMPT"
const AUTHORIZATION_TOKEN_ENVIRONMENT_VARIABLE := "SPORESPORE_QSDK_R23D1_TOKEN"
const CELL_ID_ENVIRONMENT_VARIABLE := "SPORESPORE_QSDK_R23D1_CELL"
const ENGINE_ID_ENVIRONMENT_VARIABLE := "SPORESPORE_QSDK_R23D1_ENGINE"
const PHYSICAL_IDENTITY_CLOSED := true
const SDK_COMPARISON_TOLERANCE := 2.5e-7
const PHYSICS_HZ := 120
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
const GAIT_STEPS := {
	"front_left": 0,
	"front_right": 0,
	"rear_left": 0,
	"rear_right": 0,
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 and args.size() != 3:
		_emit_failure("QSDK_R23D1_GODOT_JOLT_ARGUMENTS_INVALID")
		return
	var mode := String(args[0])
	var arm_id := String(args[1])
	if mode != "preflight" and mode != "physical":
		_emit_failure("QSDK_R23D1_GODOT_JOLT_MODE_INVALID")
		return
	if mode == "preflight" and args.size() != 2:
		_emit_failure("QSDK_R23D1_GODOT_JOLT_PREFLIGHT_ARGUMENTS_INVALID")
		return
	if mode == "physical" and args.size() != 3:
		_emit_failure("QSDK_R23D1_GODOT_JOLT_PHYSICAL_ARGUMENTS_INVALID")
		return
	var source_commit := ""
	if mode == "physical":
		source_commit = String(args[2])
		if not _valid_commit(source_commit):
			_emit_failure("QSDK_R23D1_GODOT_JOLT_SOURCE_COMMIT_INVALID")
			return
		if PHYSICAL_IDENTITY_CLOSED:
			_emit_failure("QSDK_R23D1_GODOT_JOLT_PHYSICAL_IDENTITY_CLOSED")
			return
	var solver_configuration := _apply_solver_configuration()
	if not bool(solver_configuration.get("ok", false)):
		_emit_failure(
			"QSDK_R23D1_GODOT_JOLT_SOLVER_CONFIGURATION_INVALID",
			solver_configuration,
		)
		return
	var contract := _read_json(CONTRACT_PATH)
	if mode == "physical" and not _physical_authorization_exact(
		contract,
		arm_id,
		source_commit,
	):
		_emit_failure("QSDK_R23D1_GODOT_JOLT_PHYSICAL_AUTHORIZATION_REQUIRED")
		return
	var prepared := _prepare(contract, arm_id)
	if not bool(prepared.get("ok", false)):
		_emit_failure(
			String(prepared.get("failure_code", "QSDK_R23D1_GODOT_JOLT_PREPARE_FAILED")),
			prepared,
		)
		return
	var entrypoint_preflight: Dictionary = await _run_wave(prepared, true)
	var native_preflight := _native_heading_preflight(prepared)
	var command_validation: Dictionary = native_preflight.get(
		"balanced_wave_command_validation_receipt",
		{},
	)
	var production_normalized_report := _normalized_report(
		prepared,
		_perfect_real_shaped_summary(prepared),
		"0000000000000000000000000000000000000000",
	)
	var root_child_count := root.get_child_count()
	var preflight_passed := (
		bool(entrypoint_preflight.get("ok", false))
		and int(entrypoint_preflight.get("actual_world_build_count", -1)) == 0
		and bool(entrypoint_preflight.get("entrypoint_control_flow_complete", false))
		and bool(entrypoint_preflight.get("sdk_heading_schedule_enabled", false))
		and String(entrypoint_preflight.get("sdk_heading_schedule_sha256", ""))
		== String(prepared["schedule_sha256"])
		and bool(native_preflight.get("ok", false))
		and int(native_preflight.get("actual_world_build_count", -1)) == 0
		and String(command_validation.get("schema_version", ""))
		== "sporespore_balanced_wave_command_validation_receipt_v1"
		and bool(command_validation.get("ok", false))
		and bool(command_validation.get("enabled", false))
		and String(command_validation.get("validation_mode", ""))
		== "native_balanced_wave_structure_and_receipts_v1"
		and bool(command_validation.get("heading_command_conditioned", false))
		and not bool(command_validation.get("legacy_command_parity_applicable", true))
		and not bool(command_validation.get("legacy_command_parity_checked", true))
		and not bool(command_validation.get("legacy_command_parity_waived", true))
		and bool(solver_configuration.get("applied_before_entrypoint", false))
		and String(production_normalized_report.get("schema_version", ""))
		== "sporespore_qsdk_r23d1_engine_cell_report_v2"
		and int(
			(production_normalized_report.get("execution", {}) as Dictionary).get(
				"world_build_count",
				-1,
			)
		) == 1
		and root_child_count == 0
	)
	var preflight_receipt := {
		"schema_version": "sporespore_qsdk_r23d1_godot_jolt_worker_preflight_v1",
		"ok": preflight_passed,
		"failure_code": "" if preflight_passed else "QSDK_R23D1_GODOT_JOLT_PREFLIGHT_INVALID",
		"campaign_id": CAMPAIGN_ID,
		"gate_id": GATE_ID,
		"engine_id": ENGINE_ID,
		"arm_id": arm_id,
		"cell_id": "%s__%s" % [ENGINE_ID, arm_id],
		"campaign_seed": CAMPAIGN_SEED,
		"selected_policy_id": POLICY_ID,
		"selected_policy_digest": POLICY_DIGEST,
		"morphology_id": MORPHOLOGY_ID,
		"contract_sha256": String(prepared["contract_sha256"]),
		"initial_perturbation": _json_initial_perturbation(
			prepared["initial_perturbation"],
		),
		"turn_heading_offset_rad": float(prepared["turn_heading_offset_rad"]),
		"schedule_sha256": String(prepared["schedule_sha256"]),
		"solver_configuration": solver_configuration.duplicate(true),
		"entrypoint_preflight": entrypoint_preflight.duplicate(true),
		"native_heading_preflight": native_preflight.duplicate(true),
		"synthetic_contract_preflight": true,
		"production_normalized_report": production_normalized_report.duplicate(true),
		"entrypoint_control_flow_complete": true,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root_child_count,
		"locomotion_outcome_exposed": false,
		"physical_execution_authorized": false,
		"q_sdk_r23_satisfied": false,
		"physical_acceptance_authority": false,
	}
	if mode == "preflight":
		print("QSDK_R23D1_GODOT_JOLT_PREFLIGHT ", JSON.stringify(preflight_receipt))
		quit(0 if preflight_passed else 1)
		return
	if not preflight_passed:
		_emit_failure("QSDK_R23D1_GODOT_JOLT_PREFLIGHT_INVALID", preflight_receipt)
		return
	var summary: Dictionary = await _run_wave(prepared, false)
	var report := _normalized_report(prepared, summary, source_commit)
	print("QSDK_R23D1_GODOT_JOLT_CELL ", JSON.stringify(report))
	quit(0)


func _prepare(contract: Dictionary, arm_id: String) -> Dictionary:
	if (
		String(contract.get("schema_version", ""))
		!= "sporespore_qsdk_r23d1_physical_development_contract_v1"
		or String(contract.get("campaign_id", "")) != CAMPAIGN_ID
		or String(contract.get("gate_id", "")) != GATE_ID
	):
		return _failure("QSDK_R23D1_GODOT_JOLT_CONTRACT_INVALID")
	var fixture_contract: Dictionary = contract.get("fixture", {})
	if (
		String(fixture_contract.get("morphology_id", "")) != MORPHOLOGY_ID
		or int(fixture_contract.get("initial_condition_seed", -1)) != CAMPAIGN_SEED
		or int(fixture_contract.get("physics_hz", -1)) != PHYSICS_HZ
	):
		return _failure("QSDK_R23D1_GODOT_JOLT_FIXTURE_CONTRACT_INVALID")
	var arm: Dictionary = {}
	for arm_value in contract.get("arms", []):
		var candidate: Dictionary = arm_value
		if String(candidate.get("arm_id", "")) == arm_id:
			arm = candidate
			break
	if arm.is_empty():
		return _failure("QSDK_R23D1_GODOT_JOLT_ARM_UNKNOWN")
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
		return _failure("QSDK_R23D1_GODOT_JOLT_DESCRIPTOR_MISMATCH")
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
		return _failure("QSDK_R23D1_GODOT_JOLT_INITIAL_PERTURBATION_MISMATCH")
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
		"contract_sha256": _raw_file_sha256(CONTRACT_PATH),
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


static func _apply_solver_configuration() -> Dictionary:
	Engine.physics_ticks_per_second = PHYSICS_HZ
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var realized := {
		"solver_policy_id": String(SOLVER_POLICY_OPTIONS["solver_policy_id"]),
		"physics_engine": String(ProjectSettings.get_setting("physics/3d/physics_engine", "")),
		"physics_hz": Engine.physics_ticks_per_second,
		"solver_velocity_steps": int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/velocity_steps",
				-1,
			)
		),
		"solver_position_steps": int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/position_steps",
				-1,
			)
		),
	}
	var exact := realized == SOLVER_POLICY_OPTIONS
	return {
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R23D1_GODOT_JOLT_SOLVER_POLICY_MISMATCH",
		"declared_solver_policy": SOLVER_POLICY_OPTIONS.duplicate(true),
		"realized_solver_policy": realized.duplicate(true),
		"applied_before_entrypoint": exact,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


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
	if (
		String(attempt.get("schema_version", "")) != ATTEMPT_SCHEMA_VERSION
		or String(attempt.get("campaign_id", "")) != CAMPAIGN_ID
		or String(attempt.get("gate_id", "")) != GATE_ID
		or String(attempt.get("source_commit", "")) != source_commit
		or String(attempt.get("origin_main_commit", "")) != source_commit
		or String(attempt.get("live_main_commit", "")) != source_commit
		or String(attempt.get("authorization_token", "")) != authorization_token
		or not _valid_lower_hex(String(attempt.get("attempt_id", "")), 32)
		or not bool(attempt.get("physical_execution_authorized", false))
		or not bool(attempt.get("single_use_supervisor_authorization", false))
		or not bool(attempt.get("source_worktree_clean", false))
		or not bool(attempt.get("source_matches_live_github_main", false))
		or not bool(attempt.get("operation_lock_held", false))
		or not bool(attempt.get("full_godot_attestation_valid", false))
		or not bool(attempt.get("content_addressed_inputs_retained", false))
		or not bool(attempt.get("one_shot_attempt_unconsumed", false))
	):
		return false
	var expected_cell_ids: Array = []
	for engine_value in contract.get("engines", []):
		var engine: Dictionary = engine_value
		for arm_value in contract.get("arms", []):
			var declared_arm: Dictionary = arm_value
			expected_cell_ids.append(
				"%s__%s" % [String(engine.get("engine_id", "")), String(declared_arm.get("arm_id", ""))]
			)
	var declared_cell_ids: Array = attempt.get("ordered_cell_ids", [])
	return declared_cell_ids == expected_cell_ids and cell_id in declared_cell_ids


func _native_heading_preflight(prepared: Dictionary) -> Dictionary:
	var adapter: RefCounted = AdapterScript.new()
	var start: Dictionary = adapter.start(
		prepared["descriptor"],
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
		0,
		"post_settle_full",
		STABILITY_POLICY_ID,
		prepared["material_profile"],
		POLICY_ID,
	)
	if not bool(start.get("ok", false)):
		return start
	var command := {
		"schema_version": "sporespore_heading_offset_command_v1",
		"schedule_id": "qsdk_r23d1_step_turn_return_v1",
		"segment_id": "commanded_turn",
		"command_role": "turn_heading",
		"heading_offset_rad": float(prepared["turn_heading_offset_rad"]),
	}
	if float(prepared["turn_heading_offset_rad"]) == 0.0:
		command["segment_id"] = "reference_warmup"
		command["command_role"] = "reference_heading"
	return adapter.preflight_perfect_declared_policy_runtime_boundary(command)


func _normalized_report(
	prepared: Dictionary,
	summary: Dictionary,
	source_commit: String,
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
	var adapter_failure_codes: Array = sdk_summary.get("failure_codes", [])
	var controller_error_count := adapter_failure_codes.size()
	var nonfinite_observation_count := 0
	for failure_code_value in adapter_failure_codes:
		if String(failure_code_value).contains("NONFINITE"):
			nonfinite_observation_count += 1
	var arm_id := String(prepared["arm_id"])
	return {
		"schema_version": "sporespore_qsdk_r23d1_engine_cell_report_v2",
		"campaign_id": CAMPAIGN_ID,
		"gate_id": GATE_ID,
		"cell_id": "%s__%s" % [ENGINE_ID, arm_id],
		"engine_id": ENGINE_ID,
		"arm_id": arm_id,
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
			"controller_error_count": controller_error_count,
			"safe_no_actuation_count": int(sdk_summary.get("safe_no_actuation_count", -1)),
			"nonfinite_observation_count": nonfinite_observation_count,
			"actuator_application_mismatch_count": int(sdk_summary.get("mismatch_count", -1)),
			"controller_semantic_step_count": int(sdk_summary.get("step_count", -1)),
			"validated_portable_command_count":
			int(sdk_summary.get("validated_balanced_wave_command_count", -1)),
			"native_actuation_application_count":
			int(sdk_summary.get("native_actuation_application_count", -1)),
		},
		"command_validation":
		{
			"schema_version": "sporespore_qsdk_r23d1_command_validation_v1",
			"normalized_validation_mode": "native_adapter_structure_and_receipts_v1",
			"source_validation_mode": String(
				source_command_validation.get("validation_mode", "")
			),
			"native_validation_step_count": int(
				source_command_validation.get("native_validation_step_count", -1)
			),
			"heading_command_conditioned_step_count": int(
				source_command_validation.get("heading_command_conditioned_step_count", -1)
			),
			"unconditioned_step_count": int(
				source_command_validation.get("unconditioned_step_count", -1)
			),
			"legacy_command_parity_applicable": bool(
				source_command_validation.get("legacy_command_parity_applicable", true)
			),
			"legacy_command_parity_checked_step_count": int(
				source_command_validation.get("legacy_command_parity_checked_step_count", -1)
			),
			"legacy_command_parity_waived_step_count": int(
				source_command_validation.get("legacy_command_parity_waived_step_count", -1)
			),
		},
		"schedule":
		{
			"schedule_id": "qsdk_r23d1_step_turn_return_v1",
			"observed_segment_sample_counts":
			(heading.get("observed_segment_sample_counts", {}) as Dictionary).duplicate(true),
			"turn_heading_offset_rad": float(prepared["turn_heading_offset_rad"]),
			"reference_heading_sample_count": int(
				heading.get("reference_heading_sample_count", -1)
			),
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
		"claims":
		{
			"development_screen_only": true,
			"q_sdk_r23_satisfied": false,
			"command_conditioned_turning": false,
			"cross_engine_equivalence": false,
			"release_authorized": false,
			"physical_acceptance_authority": false,
		},
	}


static func _perfect_real_shaped_summary(prepared: Dictionary) -> Dictionary:
	var offset := float(prepared["turn_heading_offset_rad"])
	var mean_turn_steering := 0.0
	if offset > 0.0:
		mean_turn_steering = -0.1
	elif offset < 0.0:
		mean_turn_steering = 0.1
	return {
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
			"step_count": 2400,
			"validated_balanced_wave_command_count": 19200,
			"native_actuation_application_count": 19200,
			"balanced_wave_command_validation_summary":
			{
				"validation_mode": "native_balanced_wave_structure_and_receipts_v1",
				"native_validation_step_count": 2400,
				"heading_command_conditioned_step_count": 2400,
				"unconditioned_step_count": 0,
				"legacy_command_parity_applicable": false,
				"legacy_command_parity_checked_step_count": 0,
				"legacy_command_parity_waived_step_count": 0,
			},
		},
		"sdk_heading_schedule_receipt":
		{
			"observed_segment_sample_counts":
			{
				"reference_warmup": 600,
				"commanded_turn": 1200,
				"reference_recovery": 600,
			},
			"reference_heading_sample_count": 1200,
			"turn_heading_sample_count": 1200,
			"maximum_absolute_requested_steering_fraction": absf(offset * 1.3),
			"maximum_absolute_held_steering_fraction": absf(mean_turn_steering),
			"mean_turn_held_steering_fraction": mean_turn_steering,
			"turn_phase_yaw_delta_rad": offset * 0.1,
			"final_reference_heading_error_rad": 0.0,
		},
		"final_task_frame_forward_displacement_m": 0.1,
		"maximum_tilt_rad": 0.1,
		"minimum_torso_height_m": 0.3,
		"torso_contact_ticks": 0,
		"contact_cycle_count_by_limb":
		{
			"front_left": 2,
			"front_right": 2,
			"rear_left": 2,
			"rear_right": 2,
		},
		"physical_wave_gait_walking_observed": true,
	}


static func _schedule_from_contract(schedule_contract: Dictionary, turn_offset_rad: float) -> Dictionary:
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


static func _valid_commit(value: String) -> bool:
	return _valid_lower_hex(value, 40)


static func _valid_lower_hex(value: String, expected_length: int) -> bool:
	if value.length() != expected_length:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _emit_failure(code: String, detail: Dictionary = {}) -> void:
	print(
		"QSDK_R23D1_GODOT_JOLT_FAILURE ",
		JSON.stringify(
			{
				"schema_version": "sporespore_qsdk_r23d1_godot_jolt_worker_failure_v1",
				"ok": false,
				"failure_code": code,
				"detail": detail.duplicate(true),
				"actual_world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		),
	)
	quit(1)
