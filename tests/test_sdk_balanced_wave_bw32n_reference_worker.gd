extends "res://tests/test_sdk_balanced_wave_bw6n_validation.gd"

const Bw32Common := preload("res://scripts/lab/gait/sdk_bw32n_worker_common.gd")
const BW32N_CANDIDATE_ID := "BW32N-A"
const BW32N_CANDIDATE_DIGEST := (
	"sha256:794b42e64e1a89f371b0113ad1c3cf14c0a3d87abfed876323eda9e4aaeed1e6"
)
const BW32N_RAW_CELL_SCHEMA := "sporespore_balanced_wave_bw32n_dynamic_receipt_recovery_raw_cell_v1"
const BW32N_PREFLIGHT_SCHEMA := (
	"sporespore_balanced_wave_bw32n_dynamic_receipt_recovery_worker_preflight_v1"
)
const BW32N_RAW_PREFIX := "BW32N_DYNAMIC_RECEIPT_RECOVERY_RAW_CELL "
const BW32N_PREFLIGHT_PREFIX := "BW32N_DYNAMIC_RECEIPT_RECOVERY_WORKER_PREFLIGHT "
const BW32N_REAL_SHAPED_PREFIX := "BW32N_DYNAMIC_RECEIPT_RECOVERY_REAL_SHAPED_RECEIPTS "


func _run() -> void:
	print("\n=== BW32N historical BW6N-stack reference worker ===")
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
	var cell := Bw32Common.find_cell(cell_id, BW32N_CANDIDATE_ID)
	var static_exact: bool = Bw32Common.static_contract_exact(BW32N_CANDIDATE_ID)
	if mode not in ["preflight", "authorization-preflight", "physical"] or cell.is_empty():
		push_error("BW32N-A requires preflight, authorization-preflight, or physical plus one exact cell")
		quit(1)
		return
	if not static_exact:
		push_error("BW32N-A declaration or stage-one freeze identity changed")
		quit(1)
		return
	var prepared := _prepare_bw32n_cell(cell)
	if not bool(prepared.get("ok", false)):
		push_error("BW32N-A exact input compilation failed")
		quit(1)
		return
	if mode == "preflight":
		_emit_preflight(cell, prepared, true, false)
		return
	if mode == "authorization-preflight":
		var authorization_exact: bool = Bw32Common.physical_authorization_exact(
			cell_id,
			BW32N_CANDIDATE_ID,
			true,
		)
		_emit_preflight(cell, prepared, true, authorization_exact)
		return
	if not Bw32Common.physical_authorization_exact(cell_id, BW32N_CANDIDATE_ID, false):
		push_error("BW32N-A physical entry requires exact retained supervisor authorization")
		quit(1)
		return
	var summary: Dictionary = await _run_bw32n_reference_cell(prepared)
	var receipt := _bw32n_reference_receipt(cell, prepared, summary)
	print(BW32N_RAW_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(receipt.get("role_gate_passed", false)) else 1)


func _run_all_preflight() -> void:
	var receipts: Array = []
	var all_exact: bool = Bw32Common.static_contract_exact(BW32N_CANDIDATE_ID)
	for cell_id in Bw32Common.ordered_cell_ids():
		var cell := Bw32Common.find_cell(String(cell_id), BW32N_CANDIDATE_ID)
		if cell.is_empty():
			continue
		var prepared := _prepare_bw32n_cell(cell)
		var exact := bool(prepared.get("ok", false))
		all_exact = all_exact and exact
		receipts.append({
			"cell_id": String(cell["cell_id"]),
			"candidate_id": BW32N_CANDIDATE_ID,
			"ok": exact,
			"actual_world_build_count": 0,
			"scene_tree_insertion_count": 0,
			"physics_state_modified": false,
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
		})
	var aggregate := {
		"schema_version": BW32N_PREFLIGHT_SCHEMA,
		"ok": all_exact and receipts.size() == 12 and root.get_child_count() == 0,
		"campaign_id": Bw32Common.CAMPAIGN_ID,
		"gate_id": Bw32Common.GATE_ID,
		"candidate_id": BW32N_CANDIDATE_ID,
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
	print(BW32N_PREFLIGHT_PREFIX, JSON.stringify(aggregate, "", true, true))
	quit(0 if bool(aggregate["ok"]) else 1)


func _configure_reference_policy() -> void:
	_bw2_mode = true
	_bw2_candidate_id = BW5C_CANDIDATE_ID
	_bw2_policy_id = BW5C_POLICY_ID
	_bw2_policy_digest = BW5C_POLICY_DIGEST
	_opened_development_replay = false


func _run_real_shaped_receipt_preflight_all() -> void:
	var receipts: Array = []
	var all_exact := Bw32Common.static_contract_exact(BW32N_CANDIDATE_ID)
	for cell_id in Bw32Common.ordered_cell_ids():
		var cell := Bw32Common.find_cell(String(cell_id), BW32N_CANDIDATE_ID)
		if cell.is_empty():
			continue
		var compiled := WaveGaitScript.compile_environment_challenge_options(
			Bw32Common.challenge_profile(String(cell["challenge_profile_id"]))
		)
		var profile_id := String(cell["challenge_profile_id"])
		var noise_count := 3232 if profile_id == "bw6n_sensor_noise_v1" else 0
		var walking := not (
			profile_id == "bw6n_sensor_noise_v1" and int(cell["campaign_seed"]) == 21003
		)
		var walking_receipts := {}
		for key in Bw32Common.Drp1Common.walking_receipt_keys(
			Bw32Common.Drp1Common.REFERENCE_ROUTE_ID
		):
			walking_receipts[key] = true
		if not walking:
			walking_receipts["bounded_lateral_drift"] = false
		var receipt := Bw32Common.compose_final_receipt({
			"route_id": Bw32Common.Drp1Common.REFERENCE_ROUTE_ID,
			"dynamic_parent_summary_gate_passed": true,
			"cell_id": String(cell["cell_id"]),
			"campaign_seed": int(cell["campaign_seed"]),
			"challenge_profile_id": profile_id,
			"candidate_id": BW32N_CANDIDATE_ID,
			"candidate_base_composition_digest": BW32N_CANDIDATE_DIGEST,
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
			"walking_gate_receipts": walking_receipts,
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
			"candidate_authority_observation_count": 3232,
			"first_candidate_authority_observation_index": 0,
			"last_candidate_authority_observation_index": 3231,
			"pre_authority_world_tick_count": 712,
			"candidate_specific_horizon_extension_count": 0,
		})
		all_exact = all_exact and bool(compiled.get("ok", false)) and not receipt.is_empty()
		receipts.append(receipt)
	var aggregate := {
		"schema_version": "sporespore_balanced_wave_bw32n_real_shaped_receipt_preflight_v1",
		"ok": all_exact and receipts.size() == 12 and root.get_child_count() == 0,
		"candidate_id": BW32N_CANDIDATE_ID,
		"entrypoint_count": receipts.size(),
		"cell_receipts": receipts,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count(),
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(BW32N_REAL_SHAPED_PREFIX, JSON.stringify(aggregate, "", true, true))
	quit(0 if bool(aggregate["ok"]) else 1)


func _prepare_bw32n_cell(cell: Dictionary) -> Dictionary:
	var preflight := _compile_preflight()
	var profile := Bw32Common.challenge_profile(String(cell["challenge_profile_id"]))
	var challenge_compile := WaveGaitScript.compile_environment_challenge_options(profile)
	var acquisition_compile := WaveGaitScript.compile_evidence_acquisition_options(
		Bw32Common.ACQUISITION_OPTIONS,
		12,
		3,
	)
	var horizon_compile := WaveGaitScript.compile_candidate_authority_horizon_options(
		Bw32Common.AUTHORITY_HORIZON_OPTIONS
	)
	var seed_key := str(int(cell["campaign_seed"]))
	var input_by_profile: Dictionary = preflight.get("input_by_profile", {})
	var input: Dictionary = input_by_profile.get(BW6N_PROFILE_ID, {})
	var perturbations: Dictionary = preflight.get("perturbation_by_seed", {})
	var exact: bool = (
		bool(preflight.get("ok", false))
		and bool(challenge_compile.get("ok", false))
		and bool(acquisition_compile.get("ok", false))
		and bool(horizon_compile.get("ok", false))
		and bool(
			(
				horizon_compile.get("candidate_authority_horizon_options", {}) as Dictionary
			).get("enabled", false)
		)
		and String(acquisition_compile.get("evidence_acquisition_configuration_sha256", ""))
		== Bw32Common.ACQUISITION_SHA256
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
		"failure_code": "" if exact else "BW32N_A_INPUT_INVALID",
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


func _run_bw32n_reference_cell(prepared: Dictionary) -> Dictionary:
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
			Bw32Common.ACQUISITION_OPTIONS,
			false,
			Bw32Common.AUTHORITY_HORIZON_OPTIONS,
		)
	)


func _bw32n_reference_receipt(
	manifest_cell: Dictionary,
	prepared: Dictionary,
	summary: Dictionary,
) -> Dictionary:
	var local_cell: Dictionary = prepared["cell"]
	var input: Dictionary = prepared["input"]
	var perturbation: Dictionary = prepared["perturbation"]
	var parent := _analyze_cell(local_cell, summary, perturbation, input, true)
	parent = _enrich_bw6n_receipt(local_cell, summary, parent)
	var direct_primitives := {
		"terrain_shape_count": int(parent.get("terrain_shape_count", -1)),
		"external_push_application_count": int(
			parent.get("external_push_application_count", -1)
		),
		"observation_fault_application_count": int(
			parent.get("observation_fault_application_count", -1)
		),
		"observation_fault_base_and_stability_count": int(
			parent.get("observation_fault_base_and_stability_count", -1)
		),
		"maximum_observation_fault_component": float(
			parent.get("maximum_observation_fault_component", NAN)
		),
		"stability_overlay": (
			parent.get("stability_overlay", {}) as Dictionary
		).duplicate(true),
	}
	return Bw32Common.compose_dynamic_final_receipt(
		Bw32Common.Drp1Common.REFERENCE_ROUTE_ID,
		manifest_cell,
		summary,
		direct_primitives,
	)


func _emit_preflight(
	cell: Dictionary,
	prepared: Dictionary,
	entrypoint_exact: bool,
	authorization_exact: bool,
) -> void:
	var authorization_requested := OS.get_cmdline_user_args()[0] == "authorization-preflight"
	var receipt := {
		"schema_version": BW32N_PREFLIGHT_SCHEMA,
		"ok": (
			entrypoint_exact
			and bool(prepared.get("ok", false))
			and (authorization_exact if authorization_requested else true)
			and root.get_child_count() == 0
		),
		"campaign_id": Bw32Common.CAMPAIGN_ID,
		"gate_id": Bw32Common.GATE_ID,
		"candidate_id": BW32N_CANDIDATE_ID,
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
	print(BW32N_PREFLIGHT_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(receipt["ok"]) else 1)
