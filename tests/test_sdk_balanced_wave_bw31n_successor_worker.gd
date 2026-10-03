extends "res://tests/test_sdk_balanced_wave_bw20f_material_locomotion.gd"

const Bw31Common := preload("res://scripts/lab/gait/sdk_bw31n_worker_common.gd")
const BW31N_CANDIDATE_ID := "BW31N-B"
const BW31N_CANDIDATE_DIGEST := (
	"sha256:3490c1934bb018ef68a54b5d5415c7d19dddf7696ee0ac7fca4ab27951957e4d"
)
const BW31N_RAW_CELL_SCHEMA := "sporespore_balanced_wave_bw31n_authority_horizon_raw_cell_v1"
const BW31N_PREFLIGHT_SCHEMA := (
	"sporespore_balanced_wave_bw31n_authority_horizon_worker_preflight_v1"
)
const BW31N_RAW_PREFIX := "BW31N_AUTHORITY_HORIZON_RAW_CELL "
const BW31N_PREFLIGHT_PREFIX := "BW31N_AUTHORITY_HORIZON_WORKER_PREFLIGHT "
const BW31N_REAL_SHAPED_PREFIX := "BW31N_AUTHORITY_HORIZON_REAL_SHAPED_RECEIPTS "
const BW31N_EXPECTED_STEP_COUNT := 3232

var _bw31n_manifest_cell: Dictionary = {}
var _bw31n_challenge_options: Dictionary = {}


func _run() -> void:
	print("\n=== BW31N BW19V-B portable successor worker ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() == 1 and String(user_args[0]) == "preflight-all":
		await _run_all_preflight()
		return
	if user_args.size() == 1 and String(user_args[0]) == "receipt-preflight-all":
		_run_real_shaped_receipt_preflight_all()
		return
	var mode := String(user_args[0]) if user_args.size() == 2 else ""
	var cell_id := String(user_args[1]) if user_args.size() == 2 else ""
	var cell := Bw31Common.find_cell(cell_id, BW31N_CANDIDATE_ID)
	if mode not in ["preflight", "authorization-preflight", "physical"] or cell.is_empty():
		push_error("BW31N-B requires preflight, authorization-preflight, or physical plus one exact cell")
		quit(1)
		return
	if not Bw31Common.static_contract_exact(BW31N_CANDIDATE_ID):
		push_error("BW31N-B declaration or stage-one freeze identity changed")
		quit(1)
		return
	var configured_exact: bool = _configure_bw31n_cell(cell)
	if not configured_exact:
		_clear_bw31n_cell()
		push_error("BW31N-B exact challenge or material input failed")
		quit(1)
		return
	if mode == "authorization-preflight":
		var authorization_exact: bool = Bw31Common.physical_authorization_exact(
			cell_id,
			BW31N_CANDIDATE_ID,
			true,
		)
		var receipt := await _run_bw31n_preflight(cell, authorization_exact, true)
		_clear_bw31n_cell()
		print(BW31N_PREFLIGHT_PREFIX, JSON.stringify(receipt, "", true, true))
		quit(0 if bool(receipt.get("ok", false)) else 1)
		return
	if mode == "preflight":
		var receipt := await _run_bw31n_preflight(cell, true, false)
		_clear_bw31n_cell()
		print(BW31N_PREFLIGHT_PREFIX, JSON.stringify(receipt, "", true, true))
		quit(0 if bool(receipt.get("ok", false)) else 1)
		return
	if not Bw31Common.physical_authorization_exact(cell_id, BW31N_CANDIDATE_ID, false):
		_clear_bw31n_cell()
		push_error("BW31N-B physical entry requires exact retained supervisor authorization")
		quit(1)
		return
	var summary := await _run_cell(0, int(cell["campaign_seed"]), false)
	var receipt := _bw31n_successor_receipt(cell, summary)
	_clear_bw31n_cell()
	print(BW31N_RAW_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(receipt.get("role_gate_passed", false)) else 1)


func _run_all_preflight() -> void:
	var receipts: Array = []
	var all_exact: bool = Bw31Common.static_contract_exact(BW31N_CANDIDATE_ID)
	var adapter_start_count := 0
	for cell_id in Bw31Common.ordered_cell_ids():
		var cell := Bw31Common.find_cell(String(cell_id), BW31N_CANDIDATE_ID)
		if cell.is_empty():
			continue
		var configured := _configure_bw31n_cell(cell)
		var receipt: Dictionary = {}
		if configured:
			receipt = await _run_cell(0, int(cell["campaign_seed"]), true)
			adapter_start_count += 1
		_clear_bw31n_cell()
		var exact: bool = (
			configured
			and bool(receipt.get("ok", false))
			and bool(receipt.get("entrypoint_control_flow_complete", false))
			and int(receipt.get("actual_world_build_count", -1)) == 0
			and int(receipt.get("scene_tree_insertion_count", -1)) == 0
			and not bool(receipt.get("physics_state_modified", true))
			and bool(receipt.get("selected_policy_full_authority_start_passed", false))
			and not bool(receipt.get("locomotion_outcome_exposed", true))
			and not bool(receipt.get("physical_acceptance_authority", true))
		)
		all_exact = all_exact and exact
		receipts.append({
			"cell_id": String(cell["cell_id"]),
			"candidate_id": BW31N_CANDIDATE_ID,
			"ok": exact,
			"actual_world_build_count": 0,
			"scene_tree_insertion_count": int(receipt.get("scene_tree_insertion_count", -1)),
			"physics_state_modified": bool(receipt.get("physics_state_modified", true)),
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
		})
	var aggregate := {
		"schema_version": BW31N_PREFLIGHT_SCHEMA,
		"ok": (
			all_exact
			and receipts.size() == 12
			and adapter_start_count == 12
			and root.get_child_count() == 0
		),
		"campaign_id": Bw31Common.CAMPAIGN_ID,
		"gate_id": Bw31Common.GATE_ID,
		"candidate_id": BW31N_CANDIDATE_ID,
		"cell_id": "ALL",
		"entrypoint_control_flow_complete": all_exact,
		"authorization_requested": false,
		"authorization_exact": false,
		"entrypoint_count": receipts.size(),
		"adapter_start_count": adapter_start_count,
		"entrypoint_receipts": receipts,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count(),
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(BW31N_PREFLIGHT_PREFIX, JSON.stringify(aggregate, "", true, true))
	quit(0 if bool(aggregate["ok"]) else 1)


func _configure_bw31n_cell(cell: Dictionary) -> bool:
	var requested := Bw31Common.challenge_profile(String(cell["challenge_profile_id"]))
	var compiled := WaveGaitScript.compile_environment_challenge_options(requested)
	if not bool(compiled.get("ok", false)):
		return false
	_bw31n_manifest_cell = cell.duplicate(true)
	_bw31n_challenge_options = (
		compiled.get("environment_challenge_options", {}) as Dictionary
	).duplicate(true)
	_bw20f_profile_id = Bw31Common.MATERIAL_PROFILE_ID
	OS.set_environment(BW19V_CANDIDATE_ENVIRONMENT_VARIABLE, "BW19V-B")
	return (
		not _bw31n_challenge_options.is_empty()
		and _candidate_index() == 1
		and _candidate_global_scale() == 0.5
	)


func _run_real_shaped_receipt_preflight_all() -> void:
	var receipts: Array = []
	var all_exact := Bw31Common.static_contract_exact(BW31N_CANDIDATE_ID)
	for cell_id in Bw31Common.ordered_cell_ids():
		var cell := Bw31Common.find_cell(String(cell_id), BW31N_CANDIDATE_ID)
		if cell.is_empty():
			continue
		var compiled := WaveGaitScript.compile_environment_challenge_options(
			Bw31Common.challenge_profile(String(cell["challenge_profile_id"]))
		)
		var profile_id := String(cell["challenge_profile_id"])
		var noise_count := 3232 if profile_id == "bw6n_sensor_noise_v1" else 0
		var walking := not (
			profile_id == "bw6n_sensor_noise_v1" and int(cell["campaign_seed"]) == 21003
		)
		var receipt := Bw31Common.compose_final_receipt({
			"cell_id": String(cell["cell_id"]),
			"campaign_seed": int(cell["campaign_seed"]),
			"challenge_profile_id": profile_id,
			"candidate_id": BW31N_CANDIDATE_ID,
			"candidate_base_composition_digest": BW31N_CANDIDATE_DIGEST,
			"controller_policy_id": BW15F_CONTROLLER_POLICY_ID,
			"controller_policy_digest": BW15F_CONTROLLER_POLICY_DIGEST,
			"stability_policy_id": BW19V_STABILITY_POLICY_ID,
			"authority_scope": "post_settle_full",
			"execution_mode": BW19V_EXECUTION_MODE,
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
			"candidate_authority_observation_count": 3232,
			"first_candidate_authority_observation_index": 0,
			"last_candidate_authority_observation_index": 3231,
			"pre_authority_world_tick_count": 240,
			"candidate_specific_horizon_extension_count": 0,
		})
		all_exact = all_exact and bool(compiled.get("ok", false)) and not receipt.is_empty()
		receipts.append(receipt)
	var aggregate := {
		"schema_version": "sporespore_balanced_wave_bw31n_real_shaped_receipt_preflight_v1",
		"ok": all_exact and receipts.size() == 12 and root.get_child_count() == 0,
		"candidate_id": BW31N_CANDIDATE_ID,
		"entrypoint_count": receipts.size(),
		"cell_receipts": receipts,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count(),
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(BW31N_REAL_SHAPED_PREFIX, JSON.stringify(aggregate, "", true, true))
	quit(0 if bool(aggregate["ok"]) else 1)


func _clear_bw31n_cell() -> void:
	_bw31n_manifest_cell = {}
	_bw31n_challenge_options = {}
	_bw20f_profile_id = ""
	OS.unset_environment(BW19V_CANDIDATE_ENVIRONMENT_VARIABLE)


func _run_cell(
	_generator_index: int,
	seed: int,
	preflight_before_world: bool,
) -> Dictionary:
	var prepared := _prepare_cell(0)
	if not bool(prepared.get("ok", false)):
		return prepared
	var perturbation_result := WaveGaitScript.compile_seeded_initial_perturbation(seed)
	var clock_result := ClockSpecScript.compile(ClockSpecScript.gq15_clock())
	var acquisition_result := WaveGaitScript.compile_evidence_acquisition_options(
		Bw31Common.ACQUISITION_OPTIONS,
		12,
		3,
	)
	var horizon_result := WaveGaitScript.compile_candidate_authority_horizon_options(
		Bw31Common.AUTHORITY_HORIZON_OPTIONS
	)
	if (
		not bool(perturbation_result.get("ok", false))
		or not bool(clock_result.get("ok", false))
		or not bool(acquisition_result.get("ok", false))
		or not bool(horizon_result.get("ok", false))
		or not bool(
			(
				horizon_result.get("candidate_authority_horizon_options", {}) as Dictionary
			).get("enabled", false)
		)
		or String(acquisition_result.get("evidence_acquisition_configuration_sha256", ""))
		!= Bw31Common.ACQUISITION_SHA256
	):
		return {"ok": false, "failure_code": "BW31N_B_INPUT_INVALID"}
	var selected_policy_start: Dictionary = {}
	if preflight_before_world:
		selected_policy_start = _preflight_selected_policy_full_authority_start(
			prepared,
			perturbation_result["initial_perturbation"],
		)
		if not bool(selected_policy_start.get("ok", false)):
			return selected_policy_start
	var root_children_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var summary: Dictionary = await (
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
			perturbation_result["initial_perturbation"],
			ROBUSTNESS_OPTIONS,
			prepared["fixture_spec"],
			HOST_OBSERVER_PATH_OPTIONS,
			ACTUATOR_IMPULSE_OPTIONS,
			HOST_PREAUTHORITY_MOTOR_OPTIONS,
			prepared["evidence_threshold_options"],
			clock_result["gait_clock_options"],
			SOLVER_POLICY_OPTIONS,
			{},
			{},
			prepared["authority_options"],
			_bw31n_challenge_options,
			Bw31Common.ACQUISITION_OPTIONS,
			preflight_before_world,
			Bw31Common.AUTHORITY_HORIZON_OPTIONS,
		)
	)
	if preflight_before_world:
		summary["selected_policy_full_authority_start"] = selected_policy_start.duplicate(true)
		summary["selected_policy_full_authority_start_passed"] = true
		summary["scene_tree_insertion_count"] = root.get_child_count() - root_children_before
		summary["physics_state_modified"] = Engine.physics_ticks_per_second != physics_hz_before
	return summary


func _run_bw31n_preflight(
	cell: Dictionary,
	authorization_exact: bool,
	authorization_requested: bool,
) -> Dictionary:
	var receipt := await _run_cell(0, int(cell["campaign_seed"]), true)
	var exact: bool = (
		bool(receipt.get("ok", false))
		and bool(receipt.get("entrypoint_control_flow_complete", false))
		and int(receipt.get("actual_world_build_count", -1)) == 0
		and int(receipt.get("scene_tree_insertion_count", -1)) == 0
		and not bool(receipt.get("physics_state_modified", true))
		and bool(receipt.get("selected_policy_full_authority_start_passed", false))
		and not bool(receipt.get("locomotion_outcome_exposed", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
		and (authorization_exact if authorization_requested else true)
	)
	return {
		"schema_version": BW31N_PREFLIGHT_SCHEMA,
		"ok": exact,
		"campaign_id": Bw31Common.CAMPAIGN_ID,
		"gate_id": Bw31Common.GATE_ID,
		"candidate_id": BW31N_CANDIDATE_ID,
		"cell_id": String(cell["cell_id"]),
		"entrypoint_control_flow_complete": bool(
			receipt.get("entrypoint_control_flow_complete", false)
		),
		"authorization_requested": authorization_requested,
		"authorization_exact": authorization_exact,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": int(receipt.get("scene_tree_insertion_count", -1)),
		"physics_state_modified": bool(receipt.get("physics_state_modified", true)),
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _bw31n_successor_receipt(cell: Dictionary, summary: Dictionary) -> Dictionary:
	var local_cell := {
		"cell_id": String(cell["cell_id"]),
		"cohort": "paired_outcome_exposed_recovery",
		"role": "treatment",
		"campaign_seed": int(cell["campaign_seed"]),
		"authored_friction": 0.95,
		"profile_id": Bw31Common.MATERIAL_PROFILE_ID,
		"profile_digest": Bw31Common.MATERIAL_PROFILE_SHA256,
		"candidate_id": BW31N_CANDIDATE_ID,
		"candidate_base_composition_digest": BW31N_CANDIDATE_DIGEST,
		"global_requested_correction_scale": 0.5,
	}
	var parent := _bw20f_physical_cell_receipt(local_cell, summary)
	var expected_compile := WaveGaitScript.compile_environment_challenge_options(
		Bw31Common.challenge_profile(String(cell["challenge_profile_id"]))
	)
	var expected_digest := String(
		expected_compile.get("environment_challenge_configuration_sha256", "")
	)
	var options_exact: bool = (
		bool(expected_compile.get("ok", false))
		and summary.get("environment_challenge_options", {}) == _bw31n_challenge_options
		and String(summary.get("environment_challenge_configuration_sha256", ""))
		== expected_digest
	)
	var challenge_gate: bool = _challenge_gate_exact(
		String(cell["challenge_profile_id"]),
		summary,
		options_exact,
	)
	var acquisition: Dictionary = summary.get("evidence_support_acquisition_receipt", {})
	var acquisition_exact: bool = (
		summary.get("evidence_acquisition_options", {}) == Bw31Common.ACQUISITION_OPTIONS
		and String(summary.get("evidence_acquisition_configuration_sha256", ""))
		== Bw31Common.ACQUISITION_SHA256
		and bool(acquisition.get("acquired", false))
		and not bool(acquisition.get("timed_out", true))
		and not bool(acquisition.get("controller_parameter", true))
		and not bool(acquisition.get("walking_claim_authorized", true))
	)
	var authority_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var horizon_exact: bool = (
		bool(summary.get("candidate_authority_horizon_enabled", false))
		and String(summary.get("authority_horizon_policy_id", ""))
		== String(Bw31Common.AUTHORITY_HORIZON_OPTIONS["policy_id"])
		and String(summary.get("authority_horizon_policy_sha256", ""))
		== String(Bw31Common.AUTHORITY_HORIZON_OPTIONS["policy_sha256"])
		and int(summary.get("candidate_authority_observation_count", -1)) == 3232
		and int(summary.get("first_candidate_authority_observation_index", -1)) == 0
		and int(summary.get("last_candidate_authority_observation_index", -1)) == 3231
		and int(summary.get("pre_authority_world_tick_count", -1)) == 240
		and int(summary.get("sdk_adapter_start_tick", -1)) == 240
		and int(summary.get("executed_ticks", -1)) == 3472
		and int(summary.get("candidate_specific_horizon_extension_count", -1)) == 0
	)
	var application_exact: bool = (
		bool(parent.get("mechanism_gate_passed", false))
		and bool(parent.get("combined_application_gate_passed", false))
		and int(parent.get("sdk_effective_application_count", 0)) > 0
		and int(parent.get("sdk_native_motor_write_count", -1)) == 25856
		and int(authority_summary.get("step_count", -1)) == 3232
		and int(authority_summary.get("native_actuation_application_count", -1)) == 25856
		and bool(parent.get("physical_influence", false))
	)
	var integrity_exact: bool = (
		bool(parent.get("common_execution_integrity", false))
		and bool(parent.get("profile_binding_exact", false))
		and challenge_gate
		and acquisition_exact
		and horizon_exact
		and application_exact
		and bool(parent.get("outcome_complete", false))
	)
	return Bw31Common.compose_final_receipt({
		"cell_id": String(cell["cell_id"]),
		"campaign_seed": int(cell["campaign_seed"]),
		"challenge_profile_id": String(cell["challenge_profile_id"]),
		"candidate_id": BW31N_CANDIDATE_ID,
		"candidate_base_composition_digest": BW31N_CANDIDATE_DIGEST,
		"controller_policy_id": String(parent.get("controller_policy_id", "")),
		"controller_policy_digest": String(parent.get("controller_policy_digest", "")),
		"stability_policy_id": String(parent.get("stability_policy_id", "")),
		"authority_scope": String(parent.get("authority_scope", "")),
		"execution_mode": String(parent.get("execution_mode", "")),
		"challenge_configuration_sha256": expected_digest,
		"measurement_gate_passed": acquisition_exact,
		"challenge_gate_passed": challenge_gate,
		"application_gate_passed": application_exact,
		"common_execution_integrity": integrity_exact,
		"outcome_complete": bool(parent.get("outcome_complete", false)),
		"walking_observed": bool(parent.get("walking_observed", false)),
		"walking_gate_receipts": (
			summary.get("walking_gate_receipts", {}) as Dictionary
		).duplicate(true),
		"world_build_count": int(summary.get("world_build_count", -1)),
		"world_reset_count": int(summary.get("world_reset_count", -1)),
		"physics_engine": String(summary.get("physics_engine", "")),
		"physics_hz": int(summary.get("physics_hz", -1)),
		"solver_velocity_steps": int(summary.get("solver_velocity_steps", -1)),
		"solver_position_steps": int(summary.get("solver_position_steps", -1)),
		"terrain_shape_count": int(summary.get("terrain_shape_count", -1)),
		"external_push_application_count": int(
			summary.get("external_push_application_count", -1)
		),
		"observation_fault_application_count": int(
			summary.get("observation_fault_application_count", -1)
		),
		"observation_fault_base_and_stability_count": int(
			summary.get("observation_fault_base_and_stability_count", -1)
		),
		"maximum_observation_fault_component": float(
			summary.get("maximum_observation_fault_component", NAN)
		),
		"physical_influence": bool(parent.get("physical_influence", false)),
		"candidate_authority_observation_count": int(summary.get("candidate_authority_observation_count", -1)),
		"first_candidate_authority_observation_index": int(
			summary.get("first_candidate_authority_observation_index", -1)
		),
		"last_candidate_authority_observation_index": int(
			summary.get("last_candidate_authority_observation_index", -1)
		),
		"pre_authority_world_tick_count": int(
			summary.get("pre_authority_world_tick_count", -1)
		),
		"candidate_specific_horizon_extension_count": int(
			summary.get("candidate_specific_horizon_extension_count", -1)
		),
	})


static func _challenge_gate_exact(
	profile_id: String,
	summary: Dictionary,
	options_exact: bool,
) -> bool:
	match profile_id:
		"bw6n_baseline_v1":
			return (
				options_exact
				and int(summary.get("terrain_shape_count", -1)) == 1
				and int(summary.get("external_push_application_count", -1)) == 0
				and int(summary.get("observation_fault_application_count", -1)) == 0
			)
		"bw6n_rough_v1":
			return (
				options_exact
				and int(summary.get("terrain_shape_count", -1)) == 64
				and int(summary.get("external_push_application_count", -1)) == 0
				and int(summary.get("observation_fault_application_count", -1)) == 0
			)
		"bw6n_push_v1":
			var push: Dictionary = summary.get("external_push_receipt", {})
			return (
				options_exact
				and int(summary.get("terrain_shape_count", -1)) == 1
				and int(summary.get("external_push_application_count", -1)) == 1
				and bool(push.get("effect_sampled", false))
				and float(push.get("observed_next_tick_velocity_delta_magnitude_m_s", 0.0))
				> 1.0e-4
				and not bool(push.get("controller_command", true))
			)
		"bw6n_sensor_noise_v1":
			return (
				options_exact
				and int(summary.get("terrain_shape_count", -1)) == 1
				and int(summary.get("external_push_application_count", -1)) == 0
				and int(summary.get("observation_fault_application_count", -1))
				== BW31N_EXPECTED_STEP_COUNT
				and int(summary.get("observation_fault_base_and_stability_count", -1))
				== BW31N_EXPECTED_STEP_COUNT
				and float(summary.get("maximum_observation_fault_component", 0.0)) > 0.0
			)
	return false
