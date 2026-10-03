extends "res://tests/test_sdk_balanced_wave_bw19v_independent_validation.gd"
# gdlint: disable=max-line-length
# gdlint: disable=max-returns
# gdlint: disable=max-file-lines

## BW20F stage-three exact finite cold-material locomotion worker.
##
## Preflight traverses all 17 declared entrypoints without constructing a
## world. Physical mode opens exactly one requested cell so the PowerShell
## supervisor can isolate, time-bound, and retain every attempt independently.

const BW20F_LOCOMOTION_MANIFEST_PATH := (
	"res://sdk/balanced_wave_bw20f_material_locomotion_preregistration.json"
)
const BW20F_LOCOMOTION_SCHEMA := (
	"sporespore_balanced_wave_bw20f_material_locomotion_preregistration_v1"
)
const BW20F_LOCOMOTION_STATUS := (
	"frozen_before_first_bw20f_material_locomotion_world"
)
const BW20F_LOCOMOTION_CAMPAIGN_ID := "BW20F-BW19V-COLD-MATERIAL-LOCOMOTION"
const BW20F_LOCOMOTION_GATE_ID := "BW20F-LOCOMOTION"
const BW20F_LOCOMOTION_CELL_SCHEMA := (
	"sporespore_balanced_wave_bw20f_material_locomotion_cell_v1"
)
const BW20F_LOCOMOTION_PREFLIGHT_SCHEMA := (
	"sporespore_balanced_wave_bw20f_material_locomotion_entrypoint_preflight_v1"
)
const BW20F_LOCOMOTION_CELL_PREFIX := "BW20F_MATERIAL_LOCOMOTION_CELL "
const BW20F_LOCOMOTION_PREFLIGHT_PREFIX := "BW20F_MATERIAL_LOCOMOTION_PREFLIGHT "
const BW20F_AUTHORIZATION_PATH_ENV := "SPORESPORE_BW20F_LOCOMOTION_ATTEMPT"
const BW20F_AUTHORIZATION_TOKEN_ENV := "SPORESPORE_BW20F_LOCOMOTION_TOKEN"
const BW20F_AUTHORIZED_CELL_ENV := "SPORESPORE_BW20F_LOCOMOTION_CELL"
const BW20F_REFERENCE_MORPHOLOGY_ID := (
	"godot_jolt_stability_physical_influence_reference"
)
const BW20F_ZERO_PROFILE_ID := "godot_jolt_p5m1r1_mu000_v1"
const BW20F_ZERO_PROFILE_DIGEST := (
	"sha256:b70b71e4aa16f877d1ddaf45ffc233a23300196eeb3240f4fefbe666b915b070"
)
const BW20F_EXPECTED_CELL_IDS := [
	"validation_mu009_s23001_treatment",
	"validation_mu009_s23001_control",
	"validation_mu009_s23002_treatment",
	"validation_mu009_s23003_treatment",
	"validation_mu037_s23001_treatment",
	"validation_mu037_s23001_control",
	"validation_mu037_s23002_treatment",
	"validation_mu037_s23003_treatment",
	"validation_mu076_s23001_treatment",
	"validation_mu076_s23001_control",
	"validation_mu076_s23002_treatment",
	"validation_mu076_s23003_treatment",
	"validation_mu118_s23001_treatment",
	"validation_mu118_s23001_control",
	"validation_mu118_s23002_treatment",
	"validation_mu118_s23003_treatment",
	"negative_mu000_s23001_safety",
]
const BW20F_REFERENCE_DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": BW20F_REFERENCE_MORPHOLOGY_ID,
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 18.0 / 35.0,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}

var _bw20f_profile_id := ""


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": BW20F_LOCOMOTION_MANIFEST_PATH,
		"preregistration_schema": BW20F_LOCOMOTION_SCHEMA,
		"preregistration_status": BW20F_LOCOMOTION_STATUS,
		"campaign_id": BW20F_LOCOMOTION_CAMPAIGN_ID,
		"gate_id": BW20F_LOCOMOTION_GATE_ID,
		"campaign_seeds": [23001, 23002, 23003],
		"entrypoint_receipt_schema": BW20F_LOCOMOTION_PREFLIGHT_SCHEMA,
		"cell_receipt_schema": BW20F_LOCOMOTION_CELL_SCHEMA,
		"entrypoint_prefix": BW20F_LOCOMOTION_PREFLIGHT_PREFIX,
		"cell_prefix": BW20F_LOCOMOTION_CELL_PREFIX,
		"display_name": "BW20F exact finite cold-material locomotion",
	}


func _material_profile_id() -> String:
	return _bw20f_profile_id


func _compile_campaign_generation(_generator_index: int) -> Dictionary:
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt_sha256":
		"sha256:4cd1159650bcb7ae240674fafd451e19687067f3361b10f86201a6807db540d6",
		"proportion_spec_sha256":
		"sha256:572f053ec07b01b59f109009b7007c97278c6bc1da1b0a40e01c2d80f327d8d6",
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _run() -> void:
	print("\n=== BW20F exact finite cold-material locomotion ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var manifest := _read_json(BW20F_LOCOMOTION_MANIFEST_PATH)
	var manifest_exact := _validate_bw20f_manifest(manifest)
	if not manifest_exact:
		push_error("BW20F-LOCOMOTION frozen manifest or prerequisite identity changed")
		quit(1)
		return
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() == 1 and String(user_args[0]) == "preflight":
		await _run_bw20f_entrypoint_preflight(manifest)
		return
	if user_args.size() != 2 or String(user_args[0]) != "physical":
		push_error("BW20F-LOCOMOTION accepts exactly 'preflight' or 'physical <cell_id>'")
		quit(1)
		return
	var cell := _find_manifest_cell(manifest, String(user_args[1]))
	if cell.is_empty():
		push_error("BW20F-LOCOMOTION physical cell is not in the frozen matrix")
		quit(1)
		return
	if not _physical_authorization_exact(String(cell["cell_id"])):
		push_error(
			"BW20F-LOCOMOTION physical entry requires the supervisor's exact retained attempt authorization",
		)
		quit(1)
		return
	_configure_cell(cell)
	var receipt: Dictionary
	if String(cell["role"]) == "safety":
		var summary := await _run_zero_safety_cell(cell, false)
		receipt = _zero_safety_receipt(cell, summary)
	else:
		var summary := await _run_cell(0, int(cell["campaign_seed"]), false)
		receipt = _bw20f_physical_cell_receipt(cell, summary)
	_clear_cell_configuration()
	var role_passed := bool(receipt.get("common_execution_integrity", false))
	if String(cell["role"]) == "treatment":
		role_passed = (
			role_passed
			and bool(receipt.get("mechanism_gate_passed", false))
			and bool(receipt.get("combined_application_gate_passed", false))
			and int(receipt.get("sdk_effective_application_count", 0)) > 0
			and bool(receipt.get("physical_influence", false))
			and bool(receipt.get("walking_observed", false))
		)
	elif String(cell["role"]) == "control":
		role_passed = (
			role_passed
			and bool(receipt.get("mechanism_gate_passed", false))
			and bool(receipt.get("combined_application_gate_passed", false))
			and int(receipt.get("sdk_effective_application_count", -1)) == 0
			and not bool(receipt.get("physical_influence", true))
		)
	else:
		role_passed = (
			role_passed
			and int(receipt.get("sdk_native_motor_write_count", -1)) == 0
			and int(receipt.get("sdk_effective_application_count", -1)) == 0
			and not bool(receipt.get("walking_claim_authorized", true))
		)
	receipt["role_gate_passed"] = role_passed
	receipt["harness_passed"] = role_passed
	print(BW20F_LOCOMOTION_CELL_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if role_passed else 1)


func _run_bw20f_entrypoint_preflight(manifest: Dictionary) -> void:
	var root_children_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var receipts: Array = []
	var all_exact := true
	var treatment_count := 0
	var control_count := 0
	var safety_count := 0
	var adapter_start_count := 0
	for cell_value in manifest["matrix"]["ordered_cells"]:
		var cell: Dictionary = cell_value
		_configure_cell(cell)
		var receipt: Dictionary
		if String(cell["role"]) == "safety":
			receipt = await _run_zero_safety_cell(cell, true)
			safety_count += 1
		else:
			receipt = await _run_cell(0, int(cell["campaign_seed"]), true)
			adapter_start_count += 1
			if String(cell["role"]) == "treatment":
				treatment_count += 1
			else:
				control_count += 1
		_clear_cell_configuration()
		receipts.append(receipt.duplicate(true))
		all_exact = (
			all_exact
			and bool(receipt.get("ok", false))
			and int(receipt.get("actual_world_build_count", -1)) == 0
			and int(receipt.get("scene_tree_insertion_count", -1)) == 0
			and not bool(receipt.get("physics_state_modified", true))
			and not bool(receipt.get("locomotion_outcome_exposed", true))
			and not bool(receipt.get("physical_acceptance_authority", true))
		)
	var aggregate := {
		"schema_version": BW20F_LOCOMOTION_PREFLIGHT_SCHEMA,
		"ok": (
			all_exact
			and receipts.size() == 17
			and treatment_count == 12
			and control_count == 4
			and safety_count == 1
			and adapter_start_count == 16
			and root.get_child_count() == root_children_before
			and Engine.physics_ticks_per_second == physics_hz_before
		),
		"campaign_id": BW20F_LOCOMOTION_CAMPAIGN_ID,
		"gate_id": BW20F_LOCOMOTION_GATE_ID,
		"cell_ids": BW20F_EXPECTED_CELL_IDS.duplicate(),
		"entrypoint_receipts": receipts,
		"entrypoint_count": receipts.size(),
		"treatment_entrypoint_count": treatment_count,
		"control_entrypoint_count": control_count,
		"safety_entrypoint_count": safety_count,
		"adapter_start_count": adapter_start_count,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count() - root_children_before,
		"physics_state_modified": Engine.physics_ticks_per_second != physics_hz_before,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(BW20F_LOCOMOTION_PREFLIGHT_PREFIX, JSON.stringify(aggregate, "", true, true))
	quit(0 if bool(aggregate["ok"]) else 1)


func _prepare_cell(_generator_index: int) -> Dictionary:
	var profile_result := MaterialProfilesScript.resolve(_material_profile_id())
	if not bool(profile_result.get("ok", false)):
		return profile_result
	var profile: Dictionary = profile_result["profile"]
	var fixture_candidate := FixtureSpecScript.reference_spec()
	fixture_candidate["contact_material"] = (
		(profile["body_material"] as Dictionary).duplicate(true)
	)
	var fixture_result := FixtureSpecScript.compile(fixture_candidate)
	if not bool(fixture_result.get("ok", false)):
		return fixture_result
	var fixture: Dictionary = fixture_result["fixture_spec"]
	var profile_validation := MaterialProfilesScript.validate_for_fixture(
		_material_profile_id(),
		fixture["contact_material"],
		SOLVER_POLICY_OPTIONS,
	)
	if not bool(profile_validation.get("ok", false)):
		return profile_validation
	var authority_options := {
		"enabled": true,
		"descriptor": BW20F_REFERENCE_DESCRIPTOR.duplicate(true),
		"comparison_tolerance": SDK_COMPARISON_TOLERANCE,
		"authority_scope": "post_settle_full",
		"stability_policy_id": _stability_policy_id(),
		"material_profile_id": _material_profile_id(),
		"controller_policy_id": _controller_policy_id(),
		"stability_influence_global_scale": _candidate_global_scale(),
	}
	return {
		"ok": true,
		"failure_code": "",
		"fixture_spec": fixture,
		"fixture_spec_sha256": String(fixture_result["fixture_spec_sha256"]),
		"material_profile": profile,
		"material_profile_sha256": String(profile_result["profile_sha256"]),
		"evidence_threshold_options": _evidence_thresholds(fixture),
		"authority_options": authority_options,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _run_zero_safety_cell(cell: Dictionary, preflight_only: bool) -> Dictionary:
	var prepared := _prepare_zero_safety(cell)
	if not bool(prepared.get("ok", false)):
		return prepared
	var perturbation_result := WaveGaitScript.compile_seeded_initial_perturbation(
		int(cell["campaign_seed"]),
	)
	var clock_result := ClockSpecScript.compile(ClockSpecScript.gq15_clock())
	if (
		not bool(perturbation_result.get("ok", false))
		or not bool(clock_result.get("ok", false))
	):
		return {"ok": false, "failure_code": "BW20F_ZERO_INPUT_INVALID"}
	if preflight_only:
		return {
			"schema_version": "sporespore_bw20f_zero_safety_entrypoint_v1",
			"ok": true,
			"profile_id": String(cell["profile_id"]),
			"profile_digest": String(cell["profile_digest"]),
			"actual_world_build_count": 0,
			"scene_tree_insertion_count": 0,
			"physics_state_modified": false,
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
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
			{},
		)
	)


func _prepare_zero_safety(cell: Dictionary) -> Dictionary:
	var profile_result := MaterialProfilesScript.resolve(String(cell["profile_id"]))
	if (
		not bool(profile_result.get("ok", false))
		or String(profile_result.get("profile_sha256", "")) != String(cell["profile_digest"])
	):
		return {"ok": false, "failure_code": "BW20F_ZERO_PROFILE_INVALID"}
	var profile: Dictionary = profile_result["profile"]
	var fixture_candidate := FixtureSpecScript.reference_spec()
	fixture_candidate["contact_material"] = (
		(profile["body_material"] as Dictionary).duplicate(true)
	)
	var fixture_result := FixtureSpecScript.compile(fixture_candidate)
	if not bool(fixture_result.get("ok", false)):
		return fixture_result
	var fixture: Dictionary = fixture_result["fixture_spec"]
	return {
		"ok": true,
		"failure_code": "",
		"fixture_spec": fixture,
		"fixture_spec_sha256": String(fixture_result["fixture_spec_sha256"]),
		"material_profile": profile,
		"material_profile_sha256": String(profile_result["profile_sha256"]),
		"evidence_threshold_options": _evidence_thresholds(fixture),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _bw20f_physical_cell_receipt(cell: Dictionary, summary: Dictionary) -> Dictionary:
	var parent_cell := cell.duplicate(true)
	parent_cell["morphology_id"] = BW20F_REFERENCE_MORPHOLOGY_ID
	parent_cell["generator_index"] = 0
	var receipt := super._physical_cell_receipt(
		parent_cell,
		int(cell["campaign_seed"]),
		summary,
	)
	var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var contribution: Dictionary = sdk_summary.get(
		"stability_contribution_shadow_summary",
		{},
	)
	var overlay: Dictionary = sdk_summary.get("stability_overlay_summary", {})
	var start_result: Dictionary = summary.get("sdk_authority_start_result", {})
	var manifest: Dictionary = start_result.get("adapter_manifest", {})
	var profile_result := MaterialProfilesScript.resolve(String(cell["profile_id"]))
	var profile_binding_exact: bool = (
		bool(profile_result.get("ok", false))
		and String(profile_result.get("profile_sha256", "")) == String(cell["profile_digest"])
		and String(summary.get("sdk_material_profile_sha256", "")) == String(cell["profile_digest"])
		and summary.get("sdk_material_profile", {}) == profile_result.get("profile", {})
		and (
			(summary.get("fixture_spec", {}) as Dictionary).get("contact_material", {})
			== (profile_result.get("profile", {}) as Dictionary).get("body_material", {})
		)
	)
	var failure_codes: Array = sdk_summary.get("failure_codes", [])
	var initial_pose := {
		"position": _vector_dictionary(
			summary.get("initial_torso_position_world_m", Vector3.INF),
		),
		"orientation":
		(summary.get("initial_torso_orientation_xyzw", {}) as Dictionary).duplicate(true),
	}
	return {
		"schema_version": BW20F_LOCOMOTION_CELL_SCHEMA,
		"campaign_id": BW20F_LOCOMOTION_CAMPAIGN_ID,
		"gate_id": BW20F_LOCOMOTION_GATE_ID,
		"cell_id": String(cell["cell_id"]),
		"cohort": String(cell["cohort"]),
		"role": String(cell["role"]),
		"campaign_seed": int(cell["campaign_seed"]),
		"authored_friction": float(cell["authored_friction"]),
		"material_profile_id": String(cell["profile_id"]),
		"material_profile_sha256": String(summary.get("sdk_material_profile_sha256", "")),
		"candidate_id": String(cell["candidate_id"]),
		"candidate_composition_digest": String(cell["candidate_composition_digest"]),
		"global_requested_correction_scale": float(cell["global_requested_correction_scale"]),
		"controller_policy_id": String(sdk_summary.get("controller_policy_id", "")),
		"controller_policy_digest": _controller_policy_digest(),
		"stability_policy_id": _stability_policy_id(),
		"authority_scope": String(sdk_summary.get("authority_scope", "")),
		"execution_mode": String(manifest.get("execution_mode", "")),
		"policy_branch_surface_count": 0,
		"material_condition_count": 0,
		"world_build_count": int(summary.get("world_build_count", -1)),
		"world_reset_count": int(summary.get("world_reset_count", -1)),
		"physics_engine": String(summary.get("physics_engine", "")),
		"physics_hz": int(summary.get("physics_hz", -1)),
		"solver_velocity_steps": int(summary.get("solver_velocity_steps", -1)),
		"solver_position_steps": int(summary.get("solver_position_steps", -1)),
		"fixture_spec_sha256": String(summary.get("fixture_spec_sha256", "")),
		"evidence_threshold_configuration_sha256":
		String(summary.get("evidence_threshold_configuration_sha256", "")),
		"solver_policy_configuration_sha256":
		String(summary.get("solver_policy_configuration_sha256", "")),
		"controller_configuration_sha256":
		String(summary.get("controller_configuration_sha256", "")),
		"initial_perturbation_sha256": Bw19CanonicalJsonScript.sha256(
			summary.get("initial_perturbation", {}),
		),
		"initial_pose_sha256": Bw19CanonicalJsonScript.sha256(initial_pose),
		"profile_binding_exact": profile_binding_exact,
		"common_execution_integrity": bool(receipt.get("common_execution_integrity", false)),
		"outcome_complete": _outcome_complete(summary),
		"direct_body_write_count": int(receipt.get("direct_body_write_count", -1)),
		"sdk_mismatch_count": int(receipt.get("sdk_mismatch_count", -1)),
		"sdk_failure_count": (
			failure_codes.size()
			+ int(overlay.get("failure_count", -1))
			+ int(contribution.get("mismatch_count", -1))
			+ int(contribution.get("limiter_mismatch_count", -1))
			+ int(contribution.get("profile_conversion_failure_count", -1))
		),
		"sdk_native_motor_write_count": int(receipt.get("native_motor_write_count", -1)),
		"sdk_effective_application_count":
		int(overlay.get("nonzero_effective_application_count", -1)),
		"maximum_absolute_proposed_velocity_rad_s":
		float(contribution.get("maximum_absolute_proposed_velocity_rad_s", NAN)),
		"maximum_absolute_applied_velocity_rad_s":
		float(contribution.get("maximum_absolute_applied_velocity_rad_s", NAN)),
		"physical_influence": bool(overlay.get("physical_influence", false)),
		"mechanism_gate_passed": bool(receipt.get("mechanism_gate_passed", false)),
		"combined_application_gate_passed":
		bool(receipt.get("combined_application_gate_passed", false)),
		"walking_observed": bool(receipt.get("walking_observed", false)),
		"walking_gate_receipts":
		(summary.get("walking_gate_receipts", {}) as Dictionary).duplicate(true),
		"walking_claim_authorized": false,
		"material_acceptance_claim_authorized": false,
		"maximum_tilt_rad": float(summary.get("maximum_tilt_rad", NAN)),
		"minimum_torso_height_m": float(summary.get("minimum_torso_height_m", NAN)),
		"maximum_anchor_error_m": float(summary.get("maximum_anchor_error_m", NAN)),
		"maximum_hinge_axis_error_rad":
		float(summary.get("maximum_hinge_axis_error_rad", NAN)),
	}


func _zero_safety_receipt(cell: Dictionary, summary: Dictionary) -> Dictionary:
	var prepared := _prepare_zero_safety(cell)
	var direct_body_write_count := (
		int(summary.get("direct_torso_force_command_count", -1))
		+ int(summary.get("direct_torso_impulse_command_count", -1))
		+ int(summary.get("direct_torso_velocity_command_count", -1))
		+ int(summary.get("direct_torso_transform_command_count", -1))
	)
	var initial_pose := {
		"position": _vector_dictionary(
			summary.get("initial_torso_position_world_m", Vector3.INF),
		),
		"orientation":
		(summary.get("initial_torso_orientation_xyzw", {}) as Dictionary).duplicate(true),
	}
	var profile_binding_exact: bool = (
		bool(prepared.get("ok", false))
		and String(prepared.get("material_profile_sha256", "")) == BW20F_ZERO_PROFILE_DIGEST
		and String(summary.get("fixture_spec_sha256", ""))
		== String(prepared.get("fixture_spec_sha256", ""))
		and (
			(summary.get("fixture_spec", {}) as Dictionary).get("contact_material", {})
			== (prepared.get("material_profile", {}) as Dictionary).get("body_material", {})
		)
	)
	var common_exact: bool = (
		int(summary.get("world_build_count", -1)) == 1
		and String(summary.get("physics_engine", "")) == "Jolt Physics"
		and int(summary.get("physics_hz", -1)) == 120
		and int(summary.get("solver_velocity_steps", -1)) == 20
		and int(summary.get("solver_position_steps", -1)) == 7
		and int(summary.get("world_reset_count", -1)) == 0
		and int(summary.get("body_count", -1)) == 9
		and int(summary.get("limb_count", -1)) == 4
		and direct_body_write_count == 0
		and profile_binding_exact
		and _outcome_complete(summary)
		and is_finite(float(summary.get("maximum_tilt_rad", NAN)))
		and is_finite(float(summary.get("minimum_torso_height_m", NAN)))
		and is_finite(float(summary.get("maximum_anchor_error_m", NAN)))
		and is_finite(float(summary.get("maximum_hinge_axis_error_rad", NAN)))
	)
	return {
		"schema_version": BW20F_LOCOMOTION_CELL_SCHEMA,
		"campaign_id": BW20F_LOCOMOTION_CAMPAIGN_ID,
		"gate_id": BW20F_LOCOMOTION_GATE_ID,
		"cell_id": String(cell["cell_id"]),
		"cohort": String(cell["cohort"]),
		"role": "safety",
		"campaign_seed": int(cell["campaign_seed"]),
		"authored_friction": 0.0,
		"material_profile_id": BW20F_ZERO_PROFILE_ID,
		"material_profile_sha256": BW20F_ZERO_PROFILE_DIGEST,
		"candidate_id": "NONE",
		"candidate_composition_digest": "NONE",
		"global_requested_correction_scale": 0.0,
		"controller_policy_id": "NONE",
		"controller_policy_digest": "NONE",
		"stability_policy_id": "NONE",
		"authority_scope": "none",
		"execution_mode": "shadow_only_no_sdk_native_actuation",
		"policy_branch_surface_count": 0,
		"material_condition_count": 0,
		"world_build_count": int(summary.get("world_build_count", -1)),
		"world_reset_count": int(summary.get("world_reset_count", -1)),
		"physics_engine": String(summary.get("physics_engine", "")),
		"physics_hz": int(summary.get("physics_hz", -1)),
		"solver_velocity_steps": int(summary.get("solver_velocity_steps", -1)),
		"solver_position_steps": int(summary.get("solver_position_steps", -1)),
		"fixture_spec_sha256": String(summary.get("fixture_spec_sha256", "")),
		"evidence_threshold_configuration_sha256":
		String(summary.get("evidence_threshold_configuration_sha256", "")),
		"solver_policy_configuration_sha256":
		String(summary.get("solver_policy_configuration_sha256", "")),
		"controller_configuration_sha256":
		String(summary.get("controller_configuration_sha256", "")),
		"initial_perturbation_sha256": Bw19CanonicalJsonScript.sha256(
			summary.get("initial_perturbation", {}),
		),
		"initial_pose_sha256": Bw19CanonicalJsonScript.sha256(initial_pose),
		"profile_binding_exact": profile_binding_exact,
		"common_execution_integrity": common_exact,
		"outcome_complete": _outcome_complete(summary),
		"direct_body_write_count": direct_body_write_count,
		"sdk_mismatch_count": 0,
		"sdk_failure_count": 0,
		"sdk_native_motor_write_count": 0,
		"sdk_effective_application_count": 0,
		"maximum_absolute_proposed_velocity_rad_s": 0.0,
		"maximum_absolute_applied_velocity_rad_s": 0.0,
		"physical_influence": false,
		"mechanism_gate_passed": false,
		"combined_application_gate_passed": false,
		"walking_observed": bool(summary.get("physical_wave_gait_walking_observed", false)),
		"walking_gate_receipts": {},
		"walking_claim_authorized": false,
		"material_acceptance_claim_authorized": false,
		"maximum_tilt_rad": float(summary.get("maximum_tilt_rad", NAN)),
		"minimum_torso_height_m": float(summary.get("minimum_torso_height_m", NAN)),
		"maximum_anchor_error_m": float(summary.get("maximum_anchor_error_m", NAN)),
		"maximum_hinge_axis_error_rad":
		float(summary.get("maximum_hinge_axis_error_rad", NAN)),
	}


func _validate_bw20f_manifest(manifest: Dictionary) -> bool:
	if manifest.is_empty():
		return false
	var study: Dictionary = manifest.get("study_class", {})
	var matrix: Dictionary = manifest.get("matrix", {})
	var cells: Array = matrix.get("ordered_cells", [])
	var gate: Dictionary = manifest.get("gate_contract", {})
	var claims: Dictionary = manifest.get("claims_before_result", {})
	var cell_ids: Array = []
	for cell_value in cells:
		cell_ids.append(String((cell_value as Dictionary).get("cell_id", "")))
	return (
		String(manifest.get("schema_version", "")) == BW20F_LOCOMOTION_SCHEMA
		and String(manifest.get("status", "")) == BW20F_LOCOMOTION_STATUS
		and String(manifest.get("campaign_id", "")) == BW20F_LOCOMOTION_CAMPAIGN_ID
		and String(manifest.get("gate_id", "")) == BW20F_LOCOMOTION_GATE_ID
		and String(manifest.get("implementation_parent_commit", ""))
		== "283a868e24dbbe87661289560fd3a06cba31f8e6"
		and String(study.get("classification", ""))
		== "exact_finite_cell_material_acceptance_decision"
		and bool(study.get("finite_decision", false))
		and not bool(study.get("population_inference", true))
		and not bool(study.get("superiority_study", true))
		and not bool(study.get("noninferiority_or_equivalence_study", true))
		and bool(study.get("treatment_need_not_outperform_control", false))
		and not bool(study.get("terminal_outcome_separation_gate", true))
		and cells.size() == 17
		and cell_ids == BW20F_EXPECTED_CELL_IDS
		and int(matrix.get("treatment_world_count", -1)) == 12
		and int(matrix.get("control_world_count", -1)) == 4
		and int(matrix.get("zero_friction_safety_world_count", -1)) == 1
		and int(matrix.get("expected_world_count", -1)) == 17
		and int(gate.get("expected_gate_count", -1)) == 28
		and int(gate.get("per_world_execution_integrity_gate_count", -1)) == 17
		and int(gate.get("aggregate_gate_count", -1)) == 8
		and not bool(gate.get("treatment_outcome_superiority_required", true))
		and not bool(gate.get("terminal_position_separation_required", true))
		and _all_claims_false(claims)
		and _file_hash_exact(
			"res://sdk/balanced_wave_bw19v_closure_manifest.json",
			"ea8df6a574e1b9be1050afa8ed57982a102982ada0f0d5babccf3c937c7067f7",
		)
		and _file_hash_exact(
			"res://sdk/balanced_wave_bw20f_material_characterization_closure.json",
			"68d1ba699d1dcfd9b190423fd542b18843823374cdd8f69029c4e05548e3bf2a",
		)
		and _file_hash_exact(
			"res://sdk/balanced_wave_bw20f_material_profile_publication_closure.json",
			"d5e08e0602f745e78b1c34cc10a95f1399a969f9ccab0fd62ff68f6a53e25f1e",
		)
	)


func _configure_cell(cell: Dictionary) -> void:
	_bw20f_profile_id = String(cell["profile_id"])
	var role := String(cell["role"])
	if role == "treatment":
		OS.set_environment(BW19V_CANDIDATE_ENVIRONMENT_VARIABLE, "BW19V-B")
	elif role == "control":
		OS.set_environment(BW19V_CANDIDATE_ENVIRONMENT_VARIABLE, "BW19V-A")
	else:
		OS.unset_environment(BW19V_CANDIDATE_ENVIRONMENT_VARIABLE)


func _clear_cell_configuration() -> void:
	_bw20f_profile_id = ""
	OS.unset_environment(BW19V_CANDIDATE_ENVIRONMENT_VARIABLE)


func _find_manifest_cell(manifest: Dictionary, cell_id: String) -> Dictionary:
	for cell_value in manifest["matrix"]["ordered_cells"]:
		var cell: Dictionary = cell_value
		if String(cell.get("cell_id", "")) == cell_id:
			return cell
	return {}


func _physical_authorization_exact(cell_id: String) -> bool:
	var attempt_path := OS.get_environment(BW20F_AUTHORIZATION_PATH_ENV)
	var authorization_token := OS.get_environment(BW20F_AUTHORIZATION_TOKEN_ENV)
	var authorized_cell := OS.get_environment(BW20F_AUTHORIZED_CELL_ENV)
	if (
		attempt_path.is_empty()
		or authorization_token.is_empty()
		or authorized_cell != cell_id
		or not FileAccess.file_exists(attempt_path)
		or attempt_path.replace("/", "\\").begins_with("C:\\tmp\\")
	):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(attempt_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var attempt: Dictionary = parsed
	return (
		String(attempt.get("schema_version", ""))
		== "sporespore_balanced_wave_bw20f_material_locomotion_attempt_v1"
		and String(attempt.get("campaign_id", "")) == BW20F_LOCOMOTION_CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == BW20F_LOCOMOTION_GATE_ID
		and String(attempt.get("authorization_token", "")) == authorization_token
		and String(attempt.get("source_commit", "")).length() == 40
		and bool(attempt.get("source_worktree_clean", false))
		and bool(attempt.get("source_matches_live_github_main", false))
		and bool(attempt.get("complete_zero_world_gate_passed", false))
		and bool(attempt.get("physical_identity_consumed", false))
		and not bool(attempt.get("same_identity_rerun_allowed", true))
		and int(attempt.get("expected_world_count", -1)) == 17
		and (attempt.get("ordered_cell_ids", []) as Array) == BW20F_EXPECTED_CELL_IDS
	)


static func _outcome_complete(summary: Dictionary) -> bool:
	return (
		summary.has("physical_wave_gait_walking_observed")
		and typeof(summary.get("physical_wave_gait_walking_observed")) == TYPE_BOOL
		and typeof(summary.get("failure_code", "")) == TYPE_STRING
	)


static func _all_claims_false(claims: Dictionary) -> bool:
	if claims.is_empty():
		return false
	for value in claims.values():
		if typeof(value) != TYPE_BOOL or bool(value):
			return false
	return true


static func _file_hash_exact(path: String, expected_sha256: String) -> bool:
	return (
		FileAccess.file_exists(path)
		and FileAccess.get_sha256(path).to_lower() == expected_sha256
	)
