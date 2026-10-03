class_name LabSdkDrp1WorkerCommon
extends RefCounted

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")

const REGRESSION_ID := "BW31N-DYNAMIC-RECEIPT-PROJECTION-REGRESSION-DRP1"
const GATE_ID := "DRP1"
const REFERENCE_ROUTE_ID := "DRP1-REFERENCE-ROUTE"
const SUCCESSOR_ROUTE_ID := "DRP1-SUCCESSOR-ROUTE"
const DECLARATION_PATH := (
	"res://sdk/balanced_wave_dynamic_receipt_projection_drp1_preregistration.json"
)
const DECLARATION_RAW_SHA256 := (
	"7356b162cfd75f55ab2f75436cf827c05815b6473d84ba0653f96c2433792626"
)
const BW31N_CLOSURE_PATH := "res://sdk/balanced_wave_bw31n_authority_horizon_closure.json"
const BW31N_CLOSURE_RAW_SHA256 := (
	"b92320e3122257829cebab3ae08c6dacc0aa2def055a649c1345e78b0a51e65f"
)
const BW6N_MANIFEST_PATH := "res://sdk/balanced_wave_bw6n_validation_manifest.json"
const BW6N_MANIFEST_RAW_SHA256 := (
	"83886d8c893a4a6e5a960b06b3398d907a203a865e1ac66ed1870ea09dc3d38e"
)
const FREEZE_PATH := (
	"res://sdk/balanced_wave_dynamic_receipt_projection_drp1_freeze_v2.json"
)
const AUTHORIZATION_SCHEMA := "sporespore_drp1_conformance_authorization_v1"
const AUTHORIZATION_PATH_ENV := "SPORESPORE_DRP1_AUTHORIZATION_PATH"
const CONFORMANCE_TOKEN_ENV := "SPORESPORE_DRP1_CONFORMANCE_TOKEN"
const FULL_CONFORMANCE_ENV := "SPORESPORE_DRP1_FULL_GODOT_CONFORMANCE"
const SOURCE_COMMIT_ENV := "SPORESPORE_DRP1_SOURCE_COMMIT"
const FINAL_RECEIPT_SCHEMA := (
	"sporespore_balanced_wave_dynamic_receipt_projection_drp1_cell_v1"
)
const FINAL_RECEIPT_COMPOSER_ID := "drp1_dynamic_parent_summary_composer_v1"
const AUTHORITY_HORIZON_POLICY_ID := "fixed_candidate_authority_exposure_horizon_v1"
const ACQUISITION_POLICY_ID := "bounded_all_support_acquisition_v1"
const ACQUISITION_POLICY_SHA256 := (
	"sha256:4a49770e35b67b2186a5a64ad3dcbf7d1d637e9ffc6ea2a9365615731eb2e748"
)
const MATERIAL_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const MATERIAL_PROFILE_SHA256 := (
	"sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
)
const EXPECTED_AUTHORITY_STEPS := 3232
const EXPECTED_NATIVE_WRITES := 25856
const REGRESSION_SEEDS := [22001, 22002, 22003]
const PROFILE_IDS := [
	"bw6n_baseline_v1",
	"bw6n_rough_v1",
	"bw6n_push_v1",
	"bw6n_sensor_noise_v1",
]
const ROUTE_IDS := [REFERENCE_ROUTE_ID, SUCCESSOR_ROUTE_ID]
const PROFILE_PREFIXES := {
	"bw6n_baseline_v1": "baseline",
	"bw6n_rough_v1": "rough",
	"bw6n_push_v1": "push",
	"bw6n_sensor_noise_v1": "sensor_noise",
}
const COMMON_WALKING_RECEIPT_KEYS := [
	"bounded_anchor_error",
	"bounded_hinge_axis_error",
	"bounded_joint_only_lateral_stride_steering",
	"bounded_lateral_drift",
	"bounded_tilt",
	"bounded_torso_height",
	"bounded_yaw_drift",
	"contact_gated_evidence_horizon_completed",
	"contact_gating_completed_without_timeout",
	"every_contact_observer_executed",
	"every_limb_completed_evidence_gait_horizon",
	"every_limb_forward_relocation",
	"every_limb_two_contact_cycles",
	"evidence_support_acquisition",
	"fixture_spec_compiled_before_world_creation",
	"initial_four_contact_stance",
	"initial_perturbation_within_declared_envelope",
	"minimum_evidence_forward_translation",
	"minimum_final_forward_translation",
	"no_torso_force_or_impulse_or_velocity_or_transform_command",
	"no_world_reset",
	"one_continuous_world",
	"pinned_jolt_solver_settings",
	"terminal_four_contact_recovery",
	"zero_torso_contact",
]
const ROUTE_WALKING_ACTUATION_KEYS := {
	REFERENCE_ROUTE_ID: "sdk_stability_overlay_evidence_actuation",
	SUCCESSOR_ROUTE_ID: "native_sdk_exclusive_post_settle_actuation",
}
const FINAL_RECEIPT_KEYS := [
	"schema_version",
	"final_receipt_composer_id",
	"shared_receipt_composer_passed",
	"regression_id",
	"gate_id",
	"cell_id",
	"route_id",
	"regression_seed",
	"challenge_profile_id",
	"controller_policy_id",
	"controller_policy_digest",
	"stability_policy_id",
	"authority_scope",
	"execution_mode",
	"material_profile_id",
	"material_profile_sha256",
	"authority_horizon_policy_id",
	"candidate_authority_observation_count",
	"first_candidate_authority_observation_index",
	"last_candidate_authority_observation_index",
	"pre_authority_world_tick_count",
	"candidate_specific_horizon_extension_count",
	"challenge_configuration_sha256",
	"terrain_shape_count",
	"external_push_application_count",
	"observation_fault_application_count",
	"observation_fault_base_and_stability_count",
	"maximum_observation_fault_component",
	"world_build_count",
	"world_reset_count",
	"physics_engine",
	"physics_hz",
	"solver_velocity_steps",
	"solver_position_steps",
	"physical_influence",
	"walking_observed",
	"walking_gate_receipts",
	"route_identity_gate_passed",
	"candidate_authority_horizon_gate_passed",
	"pre_authority_exclusion_gate_passed",
	"challenge_gate_passed",
	"measurement_gate_passed",
	"application_gate_passed",
	"outcome_complete",
	"engine_integrity_gate_passed",
	"common_execution_integrity",
	"route_integrity_passed",
	"development_only",
	"candidate_or_policy_selection_authorized",
	"walking_claim_authorized",
	"nuisance_acceptance_claim_authorized",
	"turning_claim_authorized",
	"self_righting_claim_authorized",
	"arbitrary_morphology_claim_authorized",
	"cross_engine_equivalence_claim_authorized",
	"release_authorized",
	"completed_engine_neutral_sdk",
	"physical_acceptance_authority",
]


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func raw_sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_sha256(path).to_lower()


static func declaration_exact() -> bool:
	var declaration := read_json(DECLARATION_PATH)
	var closure := read_json(BW31N_CLOSURE_PATH)
	return (
		raw_sha256(DECLARATION_PATH) == DECLARATION_RAW_SHA256
		and raw_sha256(BW31N_CLOSURE_PATH) == BW31N_CLOSURE_RAW_SHA256
		and raw_sha256(BW6N_MANIFEST_PATH) == BW6N_MANIFEST_RAW_SHA256
		and String(declaration.get("regression_id", "")) == REGRESSION_ID
		and String(declaration.get("gate_id", "")) == GATE_ID
		and String(closure.get("status", ""))
		== "closed_implementation_invalid_after_complete_physical_matrix_and_frozen_evaluation"
		and bool((closure.get("immutability", {}) as Dictionary).get("physical_identity_consumed", false))
		and bool((closure.get("immutability", {}) as Dictionary).get("same_identity_rerun_forbidden", false))
	)


static func ordered_cells() -> Array:
	var cells: Array = []
	for profile_id in PROFILE_IDS:
		for seed in REGRESSION_SEEDS:
			for route_id in ROUTE_IDS:
				var route_suffix := "reference" if route_id == REFERENCE_ROUTE_ID else "successor"
				cells.append({
					"cell_id": "%s_s%d_drp1_%s" % [
						String(PROFILE_PREFIXES[profile_id]),
						int(seed),
						route_suffix,
					],
					"route_id": route_id,
					"regression_seed": int(seed),
					"campaign_seed": int(seed),
					"challenge_profile_id": profile_id,
				})
	return cells


static func find_cell(cell_id: String, route_id: String = "") -> Dictionary:
	for cell_value in ordered_cells():
		var cell: Dictionary = cell_value
		if (
			String(cell.get("cell_id", "")) == cell_id
			and (route_id.is_empty() or String(cell.get("route_id", "")) == route_id)
		):
			return cell.duplicate(true)
	return {}


static func challenge_profile(profile_id: String) -> Dictionary:
	var manifest := read_json(BW6N_MANIFEST_PATH)
	for profile_value in manifest.get("challenge_profiles", []):
		var profile: Dictionary = profile_value
		if String(profile.get("challenge_profile_id", "")) == profile_id:
			return profile.duplicate(true)
	return {}


static func route_declaration(route_id: String) -> Dictionary:
	var declaration := read_json(DECLARATION_PATH)
	var routes: Dictionary = declaration.get("route_contracts", {})
	return (routes.get(route_id, {}) as Dictionary).duplicate(true)


static func regression_authorization_exact(cell_id: String, route_id: String) -> bool:
	# DRP1 physics is ordinary and repeatable, but it is still load-bearing
	# regression physics. Require the full-conformance supervisor's ephemeral
	# authorization record in addition to the per-process token and cell binding.
	# This prevents a casual direct worker launch from opening a world merely by
	# supplying the three worker-local environment variables.
	var worker_token := OS.get_environment("SPORESPORE_DRP1_REGRESSION_TOKEN")
	var conformance_token := OS.get_environment(CONFORMANCE_TOKEN_ENV)
	var source_commit := OS.get_environment(SOURCE_COMMIT_ENV)
	var authorization_path := OS.get_environment(AUTHORIZATION_PATH_ENV)
	if (
		worker_token.is_empty()
		or conformance_token.is_empty()
		or worker_token != conformance_token
		or OS.get_environment(FULL_CONFORMANCE_ENV) != "1"
		or not source_commit.is_valid_hex_number(false)
		or source_commit.length() != 40
		or OS.get_environment("SPORESPORE_DRP1_CELL") != cell_id
		or OS.get_environment("SPORESPORE_DRP1_ROUTE") != route_id
		or authorization_path.is_empty()
		or not FileAccess.file_exists(authorization_path)
		or not FileAccess.file_exists(FREEZE_PATH)
	):
		return false
	var authorization := read_json(authorization_path)
	var freeze := read_json(FREEZE_PATH)
	var expected_keys := [
		"schema_version",
		"regression_id",
		"gate_id",
		"source_commit",
		"authorization_token",
		"created_by",
		"full_godot_conformance",
		"authorized_cells",
		"scientific_evidence_retained",
		"one_shot_identity_consumed",
		"physical_acceptance_authority",
	]
	var actual_keys: Array = authorization.keys()
	actual_keys.sort()
	expected_keys.sort()
	if actual_keys != expected_keys:
		return false
	var authorized_cells: Array = authorization.get("authorized_cells", [])
	var expected_cells: Array = []
	for expected_value in ordered_cells():
		var expected: Dictionary = expected_value
		expected_cells.append({
			"cell_id": String(expected["cell_id"]),
			"route_id": String(expected["route_id"]),
		})
	return (
		String(authorization.get("schema_version", "")) == AUTHORIZATION_SCHEMA
		and String(authorization.get("regression_id", "")) == REGRESSION_ID
		and String(authorization.get("gate_id", "")) == GATE_ID
		and String(authorization.get("source_commit", "")) == source_commit
		and String(authorization.get("authorization_token", "")) == worker_token
		and String(authorization.get("created_by", ""))
		== "sdk/run_balanced_wave_dynamic_receipt_projection_drp1.ps1"
		and bool(authorization.get("full_godot_conformance", false))
		and authorized_cells == expected_cells
		and not bool(authorization.get("scientific_evidence_retained", true))
		and not bool(authorization.get("one_shot_identity_consumed", true))
		and not bool(authorization.get("physical_acceptance_authority", true))
	)


static func walking_receipt_keys(route_id: String) -> Array:
	if not ROUTE_WALKING_ACTUATION_KEYS.has(route_id):
		return []
	var keys: Array = COMMON_WALKING_RECEIPT_KEYS.duplicate()
	keys.append(String(ROUTE_WALKING_ACTUATION_KEYS[route_id]))
	return keys


static func walking_receipt_structurally_complete(
	receipt: Dictionary,
	route_id: String,
) -> bool:
	var actual_keys: Array = receipt.keys()
	actual_keys.sort()
	var expected_keys := walking_receipt_keys(route_id)
	expected_keys.sort()
	if actual_keys != expected_keys:
		return false
	for key in expected_keys:
		if typeof(receipt.get(key)) != TYPE_BOOL:
			return false
	return true


static func walking_receipt_schema_preflight(route_id: String) -> Dictionary:
	var expected_keys := walking_receipt_keys(route_id)
	if expected_keys.is_empty():
		return {"ok": false}
	var fixture := {}
	for key in expected_keys:
		fixture[key] = true
	var alternate_route := (
		SUCCESSOR_ROUTE_ID if route_id == REFERENCE_ROUTE_ID else REFERENCE_ROUTE_ID
	)
	var cross_route_fixture := fixture.duplicate(true)
	cross_route_fixture.erase(String(ROUTE_WALKING_ACTUATION_KEYS[route_id]))
	cross_route_fixture[String(ROUTE_WALKING_ACTUATION_KEYS[alternate_route])] = true
	return {
		"ok": (
			expected_keys.size() == 26
			and walking_receipt_structurally_complete(fixture, route_id)
			and not walking_receipt_structurally_complete(cross_route_fixture, route_id)
		),
		"expected_key_count": expected_keys.size(),
		"route_actuation_key": String(ROUTE_WALKING_ACTUATION_KEYS[route_id]),
		"cross_route_schema_rejected": not walking_receipt_structurally_complete(
			cross_route_fixture,
			route_id,
		),
	}


static func _primitive(source: Dictionary, fallback: Dictionary, key: String, default: Variant) -> Variant:
	return source.get(key, fallback.get(key, default))


static func _challenge_gate(
	profile_id: String,
	summary: Dictionary,
	primitives: Dictionary,
	options_exact: bool,
) -> bool:
	var terrain_count := int(_primitive(primitives, summary, "terrain_shape_count", -1))
	var push_count := int(_primitive(primitives, summary, "external_push_application_count", -1))
	var fault_count := int(_primitive(primitives, summary, "observation_fault_application_count", -1))
	var base_and_stability_count := int(
		_primitive(primitives, summary, "observation_fault_base_and_stability_count", -1)
	)
	var maximum_fault := float(
		_primitive(primitives, summary, "maximum_observation_fault_component", NAN)
	)
	match profile_id:
		"bw6n_baseline_v1":
			return options_exact and terrain_count == 1 and push_count == 0 and fault_count == 0
		"bw6n_rough_v1":
			return options_exact and terrain_count == 64 and push_count == 0 and fault_count == 0
		"bw6n_push_v1":
			var push: Dictionary = summary.get("external_push_receipt", {})
			return (
				options_exact
				and terrain_count == 1
				and push_count == 1
				and fault_count == 0
				and bool(push.get("effect_sampled", false))
				and float(push.get("observed_next_tick_velocity_delta_magnitude_m_s", 0.0)) > 1.0e-4
				and not bool(push.get("controller_command", true))
			)
		"bw6n_sensor_noise_v1":
			return (
				options_exact
				and terrain_count == 1
				and push_count == 0
				and fault_count == EXPECTED_AUTHORITY_STEPS
				and base_and_stability_count == EXPECTED_AUTHORITY_STEPS
				and is_finite(maximum_fault)
				and maximum_fault > 0.0
			)
	return false


static func compose_final_receipt(
	route_id: String,
	cell: Dictionary,
	summary: Dictionary,
	direct_primitives: Dictionary,
) -> Dictionary:
	# A final DRP1 receipt is definitionally dynamic. Synthetic or pre-world
	# summaries cannot pass through this compositor and cannot be padded into a
	# real-shaped substitute.
	if (
		not declaration_exact()
		or int(summary.get("world_build_count", -1)) != 1
		or String(cell.get("route_id", "")) != route_id
		or find_cell(String(cell.get("cell_id", "")), route_id).is_empty()
	):
		return {}
	var route := route_declaration(route_id)
	if route.is_empty():
		return {}
	var profile_id := String(cell.get("challenge_profile_id", ""))
	var expected_challenge := WaveGaitScript.compile_environment_challenge_options(
		challenge_profile(profile_id)
	)
	var expected_challenge_digest := String(
		expected_challenge.get("environment_challenge_configuration_sha256", "")
	)
	var options_exact: bool = (
		bool(expected_challenge.get("ok", false))
		and summary.get("environment_challenge_options", {})
		== expected_challenge.get("environment_challenge_options", {})
		and String(summary.get("environment_challenge_configuration_sha256", ""))
		== expected_challenge_digest
	)
	var expected_pre_authority := int(route.get("expected_pre_authority_world_tick_count", -1))
	var authority_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var horizon_gate: bool = (
		bool(summary.get("candidate_authority_horizon_enabled", false))
		and String(summary.get("authority_horizon_policy_id", ""))
		== AUTHORITY_HORIZON_POLICY_ID
		and int(summary.get("candidate_authority_observation_count", -1))
		== EXPECTED_AUTHORITY_STEPS
		and int(summary.get("first_candidate_authority_observation_index", -1)) == 0
		and int(summary.get("last_candidate_authority_observation_index", -1))
		== EXPECTED_AUTHORITY_STEPS - 1
		and int(summary.get("candidate_specific_horizon_extension_count", -1)) == 0
		and int(authority_summary.get("step_count", -1)) == EXPECTED_AUTHORITY_STEPS
	)
	var pre_authority_gate: bool = (
		int(summary.get("pre_authority_world_tick_count", -1)) == expected_pre_authority
		and int(summary.get("sdk_adapter_start_tick", -1)) == expected_pre_authority
		and int(summary.get("executed_ticks", -1))
		== expected_pre_authority + EXPECTED_AUTHORITY_STEPS
	)
	var acquisition: Dictionary = summary.get("evidence_support_acquisition_receipt", {})
	var measurement_gate: bool = (
		String(summary.get("evidence_acquisition_configuration_sha256", ""))
		== ACQUISITION_POLICY_SHA256
		and bool(acquisition.get("acquired", false))
		and not bool(acquisition.get("timed_out", true))
		and not bool(acquisition.get("controller_parameter", true))
		and not bool(acquisition.get("walking_claim_authorized", true))
	)
	var physical_influence := false
	if route_id == REFERENCE_ROUTE_ID:
		var overlay: Dictionary = direct_primitives.get("stability_overlay", {})
		var authority_overlay: Dictionary = authority_summary.get("stability_overlay_summary", {})
		physical_influence = bool(overlay.get("physical_influence", false))
		physical_influence = (
			physical_influence
			and int(authority_overlay.get("application_step_count", -1))
			== EXPECTED_AUTHORITY_STEPS
			and int(authority_overlay.get("motor_write_count", -1)) == EXPECTED_NATIVE_WRITES
		)
	else:
		physical_influence = (
			int(authority_summary.get("step_count", -1)) == EXPECTED_AUTHORITY_STEPS
			and int(authority_summary.get("native_actuation_application_count", -1))
			== EXPECTED_NATIVE_WRITES
		)
	var application_gate: bool = (
		int(authority_summary.get("native_actuation_application_count", -1))
		== EXPECTED_NATIVE_WRITES
		and physical_influence
	)
	var challenge_gate: bool = _challenge_gate(
		profile_id,
		summary,
		direct_primitives,
		options_exact,
	)
	var walking_receipts: Dictionary = summary.get("walking_gate_receipts", {})
	var outcome_complete: bool = (
		walking_receipt_structurally_complete(walking_receipts, route_id)
		and typeof(summary.get("failure_code", "")) == TYPE_STRING
		and int(summary.get("world_reset_count", -1)) == 0
	)
	var engine_gate: bool = (
		int(summary.get("world_build_count", -1)) == 1
		and int(summary.get("world_reset_count", -1)) == 0
		and String(summary.get("physics_engine", "")) == "Jolt Physics"
		and int(summary.get("physics_hz", -1)) == 120
		and int(summary.get("solver_velocity_steps", -1)) == 20
		and int(summary.get("solver_position_steps", -1)) == 7
	)
	var route_identity_gate: bool = (
		not String(route.get("controller_policy_id", "")).is_empty()
		and String(route.get("controller_policy_digest", "")).begins_with("sha256:")
		and not String(route.get("stability_policy_id", "")).is_empty()
		and not String(route.get("authority_scope", "")).is_empty()
		and not String(route.get("execution_mode", "")).is_empty()
	)
	var common_integrity: bool = (
		route_identity_gate
		and horizon_gate
		and pre_authority_gate
		and challenge_gate
		and measurement_gate
		and application_gate
		and outcome_complete
		and engine_gate
	)
	var walking_observed: bool = outcome_complete
	for key in walking_receipt_keys(route_id):
		walking_observed = walking_observed and bool(walking_receipts.get(key, false))
	var receipt := {
		"schema_version": FINAL_RECEIPT_SCHEMA,
		"final_receipt_composer_id": FINAL_RECEIPT_COMPOSER_ID,
		"shared_receipt_composer_passed": true,
		"regression_id": REGRESSION_ID,
		"gate_id": GATE_ID,
		"cell_id": String(cell["cell_id"]),
		"route_id": route_id,
		"regression_seed": int(cell["regression_seed"]),
		"challenge_profile_id": profile_id,
		"controller_policy_id": String(route["controller_policy_id"]),
		"controller_policy_digest": String(route["controller_policy_digest"]),
		"stability_policy_id": String(route["stability_policy_id"]),
		"authority_scope": String(route["authority_scope"]),
		"execution_mode": String(route["execution_mode"]),
		"material_profile_id": MATERIAL_PROFILE_ID,
		"material_profile_sha256": MATERIAL_PROFILE_SHA256,
		"authority_horizon_policy_id": AUTHORITY_HORIZON_POLICY_ID,
		"candidate_authority_observation_count": int(
			summary.get("candidate_authority_observation_count", -1)
		),
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
		"challenge_configuration_sha256": expected_challenge_digest,
		"terrain_shape_count": int(
			_primitive(direct_primitives, summary, "terrain_shape_count", -1)
		),
		"external_push_application_count": int(
			_primitive(direct_primitives, summary, "external_push_application_count", -1)
		),
		"observation_fault_application_count": int(
			_primitive(direct_primitives, summary, "observation_fault_application_count", -1)
		),
		"observation_fault_base_and_stability_count": int(
			_primitive(
				direct_primitives,
				summary,
				"observation_fault_base_and_stability_count",
				-1,
			)
		),
		"maximum_observation_fault_component": float(
			_primitive(direct_primitives, summary, "maximum_observation_fault_component", NAN)
		),
		"world_build_count": int(summary.get("world_build_count", -1)),
		"world_reset_count": int(summary.get("world_reset_count", -1)),
		"physics_engine": String(summary.get("physics_engine", "")),
		"physics_hz": int(summary.get("physics_hz", -1)),
		"solver_velocity_steps": int(summary.get("solver_velocity_steps", -1)),
		"solver_position_steps": int(summary.get("solver_position_steps", -1)),
		"physical_influence": physical_influence,
		"walking_observed": walking_observed,
		"walking_gate_receipts": walking_receipts.duplicate(true),
		"route_identity_gate_passed": route_identity_gate,
		"candidate_authority_horizon_gate_passed": horizon_gate,
		"pre_authority_exclusion_gate_passed": pre_authority_gate,
		"challenge_gate_passed": challenge_gate,
		"measurement_gate_passed": measurement_gate,
		"application_gate_passed": application_gate,
		"outcome_complete": outcome_complete,
		"engine_integrity_gate_passed": engine_gate,
		"common_execution_integrity": common_integrity,
		"route_integrity_passed": common_integrity,
		"development_only": true,
		"candidate_or_policy_selection_authorized": false,
		"walking_claim_authorized": false,
		"nuisance_acceptance_claim_authorized": false,
		"turning_claim_authorized": false,
		"self_righting_claim_authorized": false,
		"arbitrary_morphology_claim_authorized": false,
		"cross_engine_equivalence_claim_authorized": false,
		"release_authorized": false,
		"completed_engine_neutral_sdk": false,
		"physical_acceptance_authority": false,
	}
	var actual_keys: Array = receipt.keys()
	actual_keys.sort()
	var expected_keys: Array = FINAL_RECEIPT_KEYS.duplicate()
	expected_keys.sort()
	if actual_keys != expected_keys:
		return {}
	return receipt
