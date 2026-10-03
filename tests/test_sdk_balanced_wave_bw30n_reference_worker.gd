extends "res://tests/test_sdk_balanced_wave_bw6n_validation.gd"

const Bw29Common := preload("res://scripts/lab/gait/sdk_bw30n_worker_common.gd")
const Bw30FixedWaveGaitScript := preload(
	"res://scripts/lab/gait/physical_wave_gait_quadruped_bw30n_fixed_horizon.gd"
)
const BW30N_CANDIDATE_ID := "BW30N-A"
const BW30N_CANDIDATE_DIGEST := (
	"sha256:794b42e64e1a89f371b0113ad1c3cf14c0a3d87abfed876323eda9e4aaeed1e6"
)
const BW30N_RAW_CELL_SCHEMA := "sporespore_balanced_wave_bw30n_recovery_raw_cell_v1"
const BW30N_PREFLIGHT_SCHEMA := (
	"sporespore_balanced_wave_bw30n_recovery_worker_preflight_v1"
)
const BW30N_RAW_PREFIX := "BW30N_RECOVERY_RAW_CELL "
const BW30N_PREFLIGHT_PREFIX := "BW30N_RECOVERY_WORKER_PREFLIGHT "
const BW30N_REAL_SHAPED_PREFIX := "BW30N_RECOVERY_REAL_SHAPED_RECEIPTS "


func _run() -> void:
	print("\n=== BW30N historical BW6N-stack reference worker ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	_configure_reference_policy()
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() == 1 and String(user_args[0]) == "preflight-all":
		await _run_all_preflight()
		return
	if user_args.size() == 1 and String(user_args[0]) == "receipt-preflight-all":
		_run_real_shaped_receipt_preflight_all()
		return
	var mode := String(user_args[0]) if user_args.size() == 2 else ""
	var cell_id := String(user_args[1]) if user_args.size() == 2 else ""
	var cell := Bw29Common.find_cell(cell_id, BW30N_CANDIDATE_ID)
	var static_exact: bool = Bw29Common.static_contract_exact(BW30N_CANDIDATE_ID)
	if mode not in ["preflight", "authorization-preflight", "physical"] or cell.is_empty():
		push_error("BW30N-A requires preflight, authorization-preflight, or physical plus one exact cell")
		quit(1)
		return
	if not static_exact:
		push_error("BW30N-A declaration or stage-one freeze identity changed")
		quit(1)
		return
	var prepared := _prepare_bw30n_cell(cell)
	if not bool(prepared.get("ok", false)):
		push_error("BW30N-A exact input compilation failed")
		quit(1)
		return
	if mode == "preflight":
		_emit_preflight(cell, prepared, true, false)
		return
	if mode == "authorization-preflight":
		var authorization_exact: bool = Bw29Common.physical_authorization_exact(
			cell_id,
			BW30N_CANDIDATE_ID,
			true,
		)
		_emit_preflight(cell, prepared, true, authorization_exact)
		return
	if not Bw29Common.physical_authorization_exact(cell_id, BW30N_CANDIDATE_ID, false):
		push_error("BW30N-A physical entry requires exact retained supervisor authorization")
		quit(1)
		return
	var summary: Dictionary = await _run_bw30n_reference_cell(prepared)
	var receipt := _bw30n_reference_receipt(cell, prepared, summary)
	print(BW30N_RAW_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(receipt.get("role_gate_passed", false)) else 1)


func _run_all_preflight() -> void:
	var receipts: Array = []
	var all_exact: bool = Bw29Common.static_contract_exact(BW30N_CANDIDATE_ID)
	for cell_id in Bw29Common.ordered_cell_ids():
		var cell := Bw29Common.find_cell(String(cell_id), BW30N_CANDIDATE_ID)
		if cell.is_empty():
			continue
		var prepared := _prepare_bw30n_cell(cell)
		var exact := bool(prepared.get("ok", false))
		all_exact = all_exact and exact
		receipts.append({
			"cell_id": String(cell["cell_id"]),
			"candidate_id": BW30N_CANDIDATE_ID,
			"ok": exact,
			"actual_world_build_count": 0,
			"scene_tree_insertion_count": 0,
			"physics_state_modified": false,
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
		})
	var aggregate := {
		"schema_version": BW30N_PREFLIGHT_SCHEMA,
		"ok": all_exact and receipts.size() == 12 and root.get_child_count() == 0,
		"campaign_id": Bw29Common.CAMPAIGN_ID,
		"gate_id": Bw29Common.GATE_ID,
		"candidate_id": BW30N_CANDIDATE_ID,
		"cell_id": "ALL",
		"entrypoint_control_flow_complete": all_exact,
		"authorization_requested": false,
		"authorization_exact": false,
		"entrypoint_count": receipts.size(),
		"adapter_start_count": 0,
		"entrypoint_receipts": receipts,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count(),
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(BW30N_PREFLIGHT_PREFIX, JSON.stringify(aggregate, "", true, true))
	quit(0 if bool(aggregate["ok"]) else 1)


func _configure_reference_policy() -> void:
	_bw2_mode = true
	_bw2_candidate_id = BW5C_CANDIDATE_ID
	_bw2_policy_id = BW5C_POLICY_ID
	_bw2_policy_digest = BW5C_POLICY_DIGEST
	_opened_development_replay = false


func _run_real_shaped_receipt_preflight_all() -> void:
	var receipts: Array = []
	var all_exact := Bw29Common.static_contract_exact(BW30N_CANDIDATE_ID)
	for cell_id in Bw29Common.ordered_cell_ids():
		var cell := Bw29Common.find_cell(String(cell_id), BW30N_CANDIDATE_ID)
		if cell.is_empty():
			continue
		var compiled := WaveGaitScript.compile_environment_challenge_options(
			Bw29Common.challenge_profile(String(cell["challenge_profile_id"]))
		)
		var profile_id := String(cell["challenge_profile_id"])
		var noise_count := 1514 if profile_id == "bw6n_sensor_noise_v1" else 0
		var walking := not (
			profile_id == "bw6n_sensor_noise_v1" and int(cell["campaign_seed"]) == 21003
		)
		var receipt := Bw29Common.compose_final_receipt({
			"cell_id": String(cell["cell_id"]),
			"campaign_seed": int(cell["campaign_seed"]),
			"challenge_profile_id": profile_id,
			"candidate_id": BW30N_CANDIDATE_ID,
			"candidate_composition_digest": BW30N_CANDIDATE_DIGEST,
			"controller_policy_id": BW5C_POLICY_ID,
			"controller_policy_digest": BW5C_POLICY_DIGEST,
			"stability_policy_id": FEEDBACK_POLICY_ID,
			"authority_scope": "stability_contribution_overlay",
			"execution_mode": "portable_balanced_wave_base_with_godot_host_stability_overlay",
			"challenge_configuration_sha256": String(
				compiled.get("environment_challenge_configuration_sha256", "")
			),
			"measurement_gate_passed": true,
			"challenge_gate_passed": true,
			"application_gate_passed": true,
			"common_execution_integrity": true,
			"outcome_complete": true,
			"walking_observed": walking,
			"walking_gate_receipts": {
				"synthetic_real_shaped_preflight": true,
				"walking_conjunction_passed": walking,
			},
			"world_build_count": 1,
			"world_reset_count": 0,
			"physics_engine": "Jolt Physics",
			"physics_hz": 120,
			"solver_velocity_steps": 20,
			"solver_position_steps": 7,
			"terrain_shape_count": 64 if profile_id == "bw6n_rough_v1" else 1,
			"external_push_application_count": 1 if profile_id == "bw6n_push_v1" else 0,
			"observation_fault_application_count": noise_count,
			"observation_fault_base_and_stability_count": noise_count,
			"maximum_observation_fault_component": 0.002 if noise_count > 0 else 0.0,
			"physical_influence": true,
			"post_sdk_observation_count": 1514,
			"first_post_sdk_observation_index": 0,
			"last_post_sdk_observation_index": 1513,
			"candidate_specific_horizon_extension_count": 0,
		})
		all_exact = all_exact and bool(compiled.get("ok", false)) and not receipt.is_empty()
		receipts.append(receipt)
	var aggregate := {
		"schema_version": "sporespore_balanced_wave_bw30n_real_shaped_receipt_preflight_v1",
		"ok": all_exact and receipts.size() == 12 and root.get_child_count() == 0,
		"candidate_id": BW30N_CANDIDATE_ID,
		"entrypoint_count": receipts.size(),
		"cell_receipts": receipts,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count(),
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(BW30N_REAL_SHAPED_PREFIX, JSON.stringify(aggregate, "", true, true))
	quit(0 if bool(aggregate["ok"]) else 1)


func _prepare_bw30n_cell(cell: Dictionary) -> Dictionary:
	var preflight := _compile_preflight()
	var profile := Bw29Common.challenge_profile(String(cell["challenge_profile_id"]))
	var challenge_compile := WaveGaitScript.compile_environment_challenge_options(profile)
	var acquisition_compile := WaveGaitScript.compile_evidence_acquisition_options(
		Bw29Common.ACQUISITION_OPTIONS,
		12,
		3,
	)
	var seed_key := str(int(cell["campaign_seed"]))
	var input_by_profile: Dictionary = preflight.get("input_by_profile", {})
	var input: Dictionary = input_by_profile.get(BW6N_PROFILE_ID, {})
	var perturbations: Dictionary = preflight.get("perturbation_by_seed", {})
	var exact: bool = (
		bool(preflight.get("ok", false))
		and bool(challenge_compile.get("ok", false))
		and bool(acquisition_compile.get("ok", false))
		and String(acquisition_compile.get("evidence_acquisition_configuration_sha256", ""))
		== Bw29Common.ACQUISITION_SHA256
		and not input.is_empty()
		and perturbations.has(seed_key)
	)
	var local_cell := {
		"cell_id": String(cell["cell_id"]),
		"cohort": String(cell["challenge_profile_id"]).trim_prefix("bw6n_").trim_suffix("_v1"),
		"mode": "treatment",
		"campaign_seed": int(cell["campaign_seed"]),
		"mu_token": "095",
		"authored_friction": 0.95,
		"profile_id": BW6N_PROFILE_ID,
		"profile_digest": BW6N_PROFILE_DIGEST,
		"challenge_profile_id": String(cell["challenge_profile_id"]),
		"challenge_options": (
			challenge_compile.get("environment_challenge_options", {}) as Dictionary
		).duplicate(true),
	}
	return {
		"ok": exact,
		"failure_code": "" if exact else "BW30N_A_INPUT_INVALID",
		"preflight": preflight,
		"cell": local_cell,
		"gait_clock_options": (
			preflight.get("gait_clock_options", {}) as Dictionary
		).duplicate(true),
		"perturbation": (
			perturbations.get(seed_key, {}) as Dictionary
		).duplicate(true),
		"input": input.duplicate(true),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _run_bw30n_reference_cell(prepared: Dictionary) -> Dictionary:
	var cell: Dictionary = prepared["cell"]
	var authority_options := {
		"enabled": true,
		"descriptor": DESCRIPTOR,
		"comparison_tolerance": GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
		"authority_scope": "stability_contribution_overlay",
		"stability_policy_id": FEEDBACK_POLICY_ID,
		"material_profile_id": BW6N_PROFILE_ID,
		"controller_policy_id": BW5C_POLICY_ID,
	}
	return await (
		Bw30FixedWaveGaitScript
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
			prepared["perturbation"],
			ROBUSTNESS_OPTIONS,
			(prepared["input"] as Dictionary)["fixture_spec"],
			PATH_STEERING_OPTIONS,
			ACTUATOR_IMPULSE_OPTIONS,
			MOTOR_VELOCITY_OPTIONS,
			{},
			prepared["gait_clock_options"],
			SOLVER_POLICY_OPTIONS,
			{},
			{},
			authority_options,
			cell["challenge_options"],
			Bw29Common.ACQUISITION_OPTIONS,
			false,
			Bw29Common.FIXED_HORIZON_OPTIONS,
		)
	)


func _bw30n_reference_receipt(
	manifest_cell: Dictionary,
	prepared: Dictionary,
	summary: Dictionary,
) -> Dictionary:
	var local_cell: Dictionary = prepared["cell"]
	var input: Dictionary = prepared["input"]
	var perturbation: Dictionary = prepared["perturbation"]
	var receipt := _analyze_cell(local_cell, summary, perturbation, input, true)
	receipt = _enrich_bw6n_receipt(local_cell, summary, receipt)
	var acquisition: Dictionary = summary.get("evidence_support_acquisition_receipt", {})
	var acquisition_exact: bool = (
		summary.get("evidence_acquisition_options", {}) == Bw29Common.ACQUISITION_OPTIONS
		and String(summary.get("evidence_acquisition_configuration_sha256", ""))
		== Bw29Common.ACQUISITION_SHA256
		and bool(acquisition.get("acquired", false))
		and not bool(acquisition.get("timed_out", true))
		and not bool(acquisition.get("controller_parameter", true))
		and not bool(acquisition.get("walking_claim_authorized", true))
	)
	var contribution: Dictionary = receipt.get("stability_contribution_shadow", {})
	var overlay: Dictionary = receipt.get("stability_overlay", {})
	var application_exact: bool = (
		int(contribution.get("nonzero_active_command_count", 0)) > 0
		and int(overlay.get("nonzero_effective_application_count", 0)) > 0
	)
	var outcome_complete: bool = (
		typeof(receipt.get("ordinary_walking_gate_passed")) == TYPE_BOOL
		and typeof(summary.get("failure_code", "")) == TYPE_STRING
	)
	var integrity_exact: bool = (
		bool(receipt.get("campaign_execution_gate_passed", false))
		and bool(receipt.get("specialized_axis_gate_passed", false))
		and acquisition_exact
		and application_exact
		and outcome_complete
	)
	return Bw29Common.compose_final_receipt({
		"cell_id": String(manifest_cell["cell_id"]),
		"campaign_seed": int(manifest_cell["campaign_seed"]),
		"challenge_profile_id": String(manifest_cell["challenge_profile_id"]),
		"candidate_id": BW30N_CANDIDATE_ID,
		"candidate_composition_digest": BW30N_CANDIDATE_DIGEST,
		"controller_policy_id": BW5C_POLICY_ID,
		"controller_policy_digest": BW5C_POLICY_DIGEST,
		"stability_policy_id": FEEDBACK_POLICY_ID,
		"authority_scope": "stability_contribution_overlay",
		"execution_mode": "portable_balanced_wave_base_with_godot_host_stability_overlay",
		"challenge_configuration_sha256": String(
			summary.get("environment_challenge_configuration_sha256", "")
		),
		"measurement_gate_passed": acquisition_exact,
		"challenge_gate_passed": bool(receipt.get("specialized_axis_gate_passed", false)),
		"application_gate_passed": application_exact,
		"common_execution_integrity": integrity_exact,
		"outcome_complete": outcome_complete,
		"walking_observed": bool(receipt.get("ordinary_walking_gate_passed", false)),
		"walking_gate_receipts": (
			summary.get("walking_gate_receipts", {}) as Dictionary
		).duplicate(true),
		"world_build_count": int(summary.get("world_build_count", -1)),
		"world_reset_count": int(summary.get("world_reset_count", -1)),
		"physics_engine": String(summary.get("physics_engine", "")),
		"physics_hz": int(summary.get("physics_hz", -1)),
		"solver_velocity_steps": int(summary.get("solver_velocity_steps", -1)),
		"solver_position_steps": int(summary.get("solver_position_steps", -1)),
		"terrain_shape_count": int(receipt.get("terrain_shape_count", -1)),
		"external_push_application_count": int(
			receipt.get("external_push_application_count", -1)
		),
		"observation_fault_application_count": int(
			receipt.get("observation_fault_application_count", -1)
		),
		"observation_fault_base_and_stability_count": int(
			receipt.get("observation_fault_base_and_stability_count", -1)
		),
		"maximum_observation_fault_component": float(
			receipt.get("maximum_observation_fault_component", NAN)
		),
		"physical_influence": bool(overlay.get("physical_influence", false)),
		"post_sdk_observation_count": int(summary.get("post_sdk_observation_count", -1)),
		"first_post_sdk_observation_index": int(
			summary.get("first_post_sdk_observation_index", -1)
		),
		"last_post_sdk_observation_index": int(
			summary.get("last_post_sdk_observation_index", -1)
		),
		"candidate_specific_horizon_extension_count": int(
			summary.get("candidate_specific_horizon_extension_count", -1)
		),
	})


func _emit_preflight(
	cell: Dictionary,
	prepared: Dictionary,
	entrypoint_exact: bool,
	authorization_exact: bool,
) -> void:
	var authorization_requested := OS.get_cmdline_user_args()[0] == "authorization-preflight"
	var receipt := {
		"schema_version": BW30N_PREFLIGHT_SCHEMA,
		"ok": (
			entrypoint_exact
			and bool(prepared.get("ok", false))
			and (authorization_exact if authorization_requested else true)
			and root.get_child_count() == 0
		),
		"campaign_id": Bw29Common.CAMPAIGN_ID,
		"gate_id": Bw29Common.GATE_ID,
		"candidate_id": BW30N_CANDIDATE_ID,
		"cell_id": String(cell["cell_id"]),
		"entrypoint_control_flow_complete": entrypoint_exact,
		"authorization_requested": authorization_requested,
		"authorization_exact": authorization_exact,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count(),
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(BW30N_PREFLIGHT_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(receipt["ok"]) else 1)
