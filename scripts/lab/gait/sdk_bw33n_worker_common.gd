class_name LabSdkBw33nWorkerCommon
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=max-file-lines

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const Drp1Common := preload("res://scripts/lab/gait/sdk_drp1_worker_common.gd")

const CAMPAIGN_ID := "BW33N-BW32N-ROUGH-FACTORIAL-DEVELOPMENT"
const GATE_ID := "BW33N"
const ATTEMPT_SCHEMA := "sporespore_balanced_wave_bw33n_rough_factorial_attempt_v1"
const FREEZE_SCHEMA := "sporespore_balanced_wave_bw33n_rough_factorial_freeze_v1"
const FREEZE_STATUS := "frozen_before_first_bw33n_physical_world"
const PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw33n_rough_factorial_preregistration.json"
const CANDIDATES_PATH := "res://sdk/balanced_wave_bw33n_rough_factorial_candidates.json"
const MANIFEST_PATH := "res://sdk/balanced_wave_bw33n_rough_factorial_manifest.json"
const NATIVE_BINDINGS_PATH := "res://sdk/balanced_wave_bw33n_native_candidate_bindings.json"
const AUTHORITY_HORIZON_PATH := "res://sdk/balanced_wave_bw32n_candidate_authority_exposure_horizon.json"
const BW6N_MANIFEST_PATH := "res://sdk/balanced_wave_bw6n_validation_manifest.json"
const FREEZE_PATH := "res://sdk/balanced_wave_bw33n_rough_factorial_freeze.json"
const DECLARATION_AUDIT_PATH := "res://tests/test_bw33n_rough_factorial_declaration.ps1"
const WORKER_PATH := "res://tests/test_sdk_balanced_wave_bw33n_rough_factorial_worker.gd"
const COMMON_WORKER_PATH := "res://scripts/lab/gait/sdk_bw33n_worker_common.gd"
const EVALUATOR_PATH := "res://sdk/balanced_wave_bw33n_rough_factorial_gate.ps1"
const SUPERVISOR_PATH := "res://sdk/run_balanced_wave_bw33n_rough_factorial.ps1"
const ZERO_WORLD_GATE_PATH := "res://sdk/run_balanced_wave_bw33n_rough_factorial_zero_world_gate.ps1"
const ADAPTER_ARTIFACT_PATH := "res://sdk/target/debug/sporespore_godot_adapter.dll"

const PREREGISTRATION_RAW_SHA256 := "5e3c1d1d0e9e1796c42168c66829453e1fce00a6e0bfe6c9a22b9ee48c616271"
const CANDIDATES_RAW_SHA256 := "670976d998edd4419950b6edb0e4ed8923c05213f0838d267e110aa349ba25a3"
const MANIFEST_RAW_SHA256 := "4e98d4719d118992d85f0cba8adb13c4b9e396ea89e82818a5eeb236ac79f494"
const NATIVE_BINDINGS_RAW_SHA256 := "a861ade8b7d46b05ddef5a08630063740ad4d8d81b6b706a217cefdb342ae852"
const AUTHORITY_HORIZON_RAW_SHA256 := "ec8291ecd54dbc8299d79d6b3adf176bf67fe851e4bacffc3df253c9a0a605df"
const BW6N_MANIFEST_RAW_SHA256 := "83886d8c893a4a6e5a960b06b3398d907a203a865e1ac66ed1870ea09dc3d38e"

const GODOT_VERSION := "4.7.stable.mono.official.5b4e0cb0f"
const GODOT_EXECUTABLE_SHA256 := "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
const GODOT_RUNTIME_SHA256 := "baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4"
const MATERIAL_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const MATERIAL_PROFILE_SHA256 := "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
const ACQUISITION_OPTIONS := {
	"policy_id": "bounded_all_support_acquisition_v1",
	"enabled": true,
	"maximum_acquisition_ticks": 15,
	"minimum_all_support_dwell_ticks": 3,
}
const ACQUISITION_SHA256 := "sha256:4a49770e35b67b2186a5a64ad3dcbf7d1d637e9ffc6ea2a9365615731eb2e748"
const AUTHORITY_HORIZON_OPTIONS := {
	"policy_id": "fixed_candidate_authority_exposure_horizon_v1",
	"policy_sha256": "sha256:" + AUTHORITY_HORIZON_RAW_SHA256,
	"first_candidate_authority_observation_index": 0,
	"last_candidate_authority_observation_index": 3231,
	"exact_candidate_authority_observation_count": 3232,
	"candidate_specific_horizon_extension_count": 0,
}
const ROUTE_ID := Drp1Common.SUCCESSOR_ROUTE_ID
const FINAL_RECEIPT_SCHEMA := "sporespore_balanced_wave_bw33n_rough_factorial_raw_cell_v1"
const FINAL_RECEIPT_COMPOSER_ID := "bw33n_actual_dynamic_parent_summary_composer_v1"

const AUTHORIZATION_PATH_ENV := "SPORESPORE_BW33N_ATTEMPT"
const AUTHORIZATION_TOKEN_ENV := "SPORESPORE_BW33N_TOKEN"
const AUTHORIZED_CELL_ENV := "SPORESPORE_BW33N_CELL"
const AUTHORIZED_CANDIDATE_ENV := "SPORESPORE_BW33N_CANDIDATE"
const WORLD_ATTEMPT_ID_ENV := "SPORESPORE_BW33N_WORLD_ATTEMPT_ID"
const CAMPAIGN_ATTEMPT_ID_ENV := "SPORESPORE_BW33N_CAMPAIGN_ATTEMPT_ID"

const CANDIDATE_ORDER := ["BW33N-A", "BW33N-B", "BW33N-C", "BW33N-D"]
const SEED_ORDER := [21001, 21002, 21003]
const EXPECTED_BINDING_DIGESTS := {
	"BW33N-A": "sha256:4d10129d115e05b90d016f17852550f01a2ae1f55ef0b6c4b76e7b3f502104d4",
	"BW33N-B": "sha256:63256c50af72be8ca9f0ce8b8a5e0ccaddea65e0c57c47ac8a7a5653a856b1fb",
	"BW33N-C": "sha256:0598d4c57ae37fab2beb9268c2f90412e1f04a7db58d76c1bfe8e228074bcdb8",
	"BW33N-D": "sha256:f48dae75095a7c2b2e192203a4ce12bfd88b56a1d716977ca04d94ffb7b7ff59",
}

const FINAL_RECEIPT_KEYS := [
	"schema_version", "final_receipt_composer_id", "shared_receipt_composer_passed",
	"campaign_id", "gate_id", "route_id", "dynamic_parent_summary_gate_passed",
	"cell_id", "cohort", "role", "campaign_seed", "challenge_profile_id",
	"candidate_id", "candidate_composition_digest", "controller_policy_id",
	"controller_runtime_profile_sha256", "yaw_error_stride_gain_per_rad",
	"global_requested_correction_scale", "treatment_factor_count",
	"selection_eligible", "policy_branch_surface_count", "stability_policy_id",
	"authority_scope", "execution_mode", "material_profile_id",
	"material_profile_sha256", "measurement_policy_id", "measurement_policy_digest",
	"authority_horizon_policy_id", "authority_horizon_policy_sha256",
	"candidate_authority_observation_count", "first_candidate_authority_observation_index",
	"last_candidate_authority_observation_index", "pre_authority_world_tick_count",
	"candidate_specific_horizon_extension_count", "challenge_configuration_sha256",
	"identity_profile_scale_gate_passed", "measurement_gate_passed", "material_gate_passed",
	"challenge_gate_passed", "application_gate_passed", "mechanism_gate_passed",
	"common_execution_integrity", "outcome_complete", "failure_code",
	"walking_observed", "walking_gate_receipts", "failed_walking_gate_count",
	"world_build_count", "world_reset_count", "physics_engine", "physics_hz",
	"solver_velocity_steps", "solver_position_steps", "terrain_shape_count",
	"external_push_application_count", "observation_fault_application_count",
	"observation_fault_base_and_stability_count", "maximum_observation_fault_component",
	"physical_influence", "role_gate_passed", "development_only",
	"walking_claim_authorized", "nuisance_acceptance_claim_authorized",
	"rough_terrain_acceptance", "release_authorized", "physical_acceptance_authority",
]


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func raw_sha256(path: String) -> String:
	return FileAccess.get_sha256(path).to_lower() if FileAccess.file_exists(path) else ""


static func sha256_utf8(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return "sha256:" + context.finish().hex_encode()


static func dictionary_keys_exact(value: Dictionary, expected: Array) -> bool:
	var actual_keys: Array = []
	for key in value.keys():
		actual_keys.append(String(key))
	actual_keys.sort()
	var expected_keys := expected.duplicate()
	expected_keys.sort()
	return actual_keys == expected_keys


static func ordered_cell_ids() -> Array:
	var ids: Array = []
	for cell_value in read_json(MANIFEST_PATH).get("ordered_cells", []):
		ids.append(String((cell_value as Dictionary).get("cell_id", "")))
	return ids


static func primary_world_attempt_ids() -> Array:
	var ids: Array = []
	for cell_id in ordered_cell_ids():
		ids.append("BW33N-P1::" + String(cell_id))
	return ids


static func find_cell(cell_id: String, candidate_id: String = "") -> Dictionary:
	for cell_value in read_json(MANIFEST_PATH).get("ordered_cells", []):
		var cell: Dictionary = cell_value
		if (
			String(cell.get("cell_id", "")) == cell_id
			and (candidate_id.is_empty() or String(cell.get("candidate_id", "")) == candidate_id)
		):
			return cell.duplicate(true)
	return {}


static func candidate_declaration(candidate_id: String) -> Dictionary:
	for candidate_value in read_json(CANDIDATES_PATH).get("candidates", []):
		var candidate: Dictionary = candidate_value
		if String(candidate.get("candidate_id", "")) == candidate_id:
			return candidate.duplicate(true)
	return {}


static func candidate_binding(candidate_id: String) -> Dictionary:
	for binding_value in read_json(NATIVE_BINDINGS_PATH).get("candidate_bindings", []):
		var binding: Dictionary = binding_value
		if String(binding.get("candidate_id", "")) == candidate_id:
			return binding.duplicate(true)
	return {}


static func candidate_composition_digest(candidate_id: String) -> String:
	return String(candidate_binding(candidate_id).get("candidate_composition_digest", ""))


static func challenge_profile(profile_id: String) -> Dictionary:
	for profile_value in read_json(BW6N_MANIFEST_PATH).get("challenge_profiles", []):
		var profile: Dictionary = profile_value
		if String(profile.get("challenge_profile_id", "")) == profile_id:
			return profile.duplicate(true)
	return {}


static func candidate_binding_exact(candidate_id: String) -> bool:
	var candidate := candidate_declaration(candidate_id)
	var binding := candidate_binding(candidate_id)
	if candidate.is_empty() or binding.is_empty():
		return false
	var expected_digest := String(EXPECTED_BINDING_DIGESTS.get(candidate_id, ""))
	return (
		candidate_id in CANDIDATE_ORDER
		and String(binding.get("candidate_id", "")) == candidate_id
		and not String(binding.get("exact_binding_string", "")).is_empty()
		and sha256_utf8(String(binding.get("exact_binding_string", ""))) == expected_digest
		and String(binding.get("candidate_composition_digest", "")) == expected_digest
		and String(candidate.get("schema_version", ""))
		== "sporespore_bw33n_rough_factorial_candidate_v1"
		and String(candidate.get("controller_policy_id", "")) in [
			"sporespore_balanced_wave_bw15f_b_v1",
			"sporespore_balanced_wave_bw23y_b_v1",
		]
		and String(candidate.get("runtime_profile_sha256", "")).begins_with("sha256:")
		and float(candidate.get("yaw_error_stride_gain_per_rad", NAN)) in [1.3, 1.0]
		and float(candidate.get("global_requested_correction_scale", NAN)) in [0.5, 0.75]
		and String(candidate.get("stability_policy_id", ""))
		== "sporespore_scheduled_load_transfer_bw13p_a_v3"
		and String(candidate.get("authority_scope", "")) == "post_settle_full"
		and String(candidate.get("execution_mode", ""))
		== "native_balanced_wave_base_with_stability_contribution"
		and String(candidate.get("authority_horizon_policy_sha256", ""))
		== String(AUTHORITY_HORIZON_OPTIONS["policy_sha256"])
		and int(candidate.get("exact_candidate_authority_observation_count", -1)) == 3232
		and int(candidate.get("expected_native_motor_write_count", -1)) == 25856
		and (candidate.get("branch_surfaces", []) as Array).is_empty()
		and not bool(candidate.get("physical_acceptance_authority", true))
	)


static func _freeze_bindings_exact(freeze: Dictionary) -> bool:
	var bindings: Dictionary = freeze.get("source_bindings", {})
	if bindings.is_empty():
		return false
	for binding_value in bindings.values():
		var binding: Dictionary = binding_value
		var relative_path := String(binding.get("path", ""))
		if (
			relative_path.is_empty()
			or not FileAccess.file_exists("res://" + relative_path)
			or raw_sha256("res://" + relative_path) != String(binding.get("raw_sha256", ""))
		):
			return false
	return true


static func static_contract_exact(candidate_id: String = "") -> bool:
	var preregistration := read_json(PREREGISTRATION_PATH)
	var candidates := read_json(CANDIDATES_PATH)
	var manifest := read_json(MANIFEST_PATH)
	var bindings := read_json(NATIVE_BINDINGS_PATH)
	var freeze := read_json(FREEZE_PATH)
	var candidates_exact := true
	for declared_candidate_id in CANDIDATE_ORDER:
		candidates_exact = candidates_exact and candidate_binding_exact(String(declared_candidate_id))
	return (
		raw_sha256(PREREGISTRATION_PATH) == PREREGISTRATION_RAW_SHA256
		and raw_sha256(CANDIDATES_PATH) == CANDIDATES_RAW_SHA256
		and raw_sha256(MANIFEST_PATH) == MANIFEST_RAW_SHA256
		and raw_sha256(NATIVE_BINDINGS_PATH) == NATIVE_BINDINGS_RAW_SHA256
		and raw_sha256(AUTHORITY_HORIZON_PATH) == AUTHORITY_HORIZON_RAW_SHA256
		and raw_sha256(BW6N_MANIFEST_PATH) == BW6N_MANIFEST_RAW_SHA256
		and String(preregistration.get("campaign_id", "")) == CAMPAIGN_ID
		and String(preregistration.get("gate_id", "")) == GATE_ID
		and String(candidates.get("campaign_id", "")) == CAMPAIGN_ID
		and (candidates.get("candidate_order", []) as Array) == CANDIDATE_ORDER
		and String(manifest.get("campaign_id", "")) == CAMPAIGN_ID
		and String(manifest.get("gate_id", "")) == GATE_ID
		and (manifest.get("ordered_cells", []) as Array).size() == 12
		and String(bindings.get("schema_version", ""))
		== "sporespore_balanced_wave_bw33n_native_candidate_bindings_v1"
		and int(bindings.get("candidate_count", -1)) == 4
		and int(bindings.get("branch_surface_count", -1)) == 0
		and not bool(bindings.get("physical_execution_authorized", true))
		and candidates_exact
		and (candidate_id.is_empty() or candidate_binding_exact(candidate_id))
		and String(freeze.get("schema_version", "")) == FREEZE_SCHEMA
		and String(freeze.get("status", "")) == FREEZE_STATUS
		and String(freeze.get("campaign_id", "")) == CAMPAIGN_ID
		and String(freeze.get("gate_id", "")) == GATE_ID
		and int((freeze.get("physical_matrix", {}) as Dictionary).get("expected_world_count", -1)) == 12
		and not bool(freeze.get("physical_execution_authorized_by_freeze", true))
		and _freeze_bindings_exact(freeze)
	)


static func _primitive(
	direct_primitives: Dictionary,
	summary: Dictionary,
	key: String,
	fallback: Variant,
) -> Variant:
	return direct_primitives.get(key, summary.get(key, fallback))


static func _rough_challenge_gate(
	summary: Dictionary,
	direct_primitives: Dictionary,
	options_exact: bool,
) -> bool:
	return (
		options_exact
		and int(_primitive(direct_primitives, summary, "terrain_shape_count", -1)) == 64
		and int(_primitive(direct_primitives, summary, "external_push_application_count", -1)) == 0
		and int(_primitive(direct_primitives, summary, "observation_fault_application_count", -1)) == 0
		and int(_primitive(direct_primitives, summary, "observation_fault_base_and_stability_count", -1)) == 0
		and is_zero_approx(float(_primitive(direct_primitives, summary, "maximum_observation_fault_component", NAN)))
	)


static func _failed_walking_gate_count(walking_receipts: Dictionary) -> int:
	var count := 0
	for key in Drp1Common.walking_receipt_keys(ROUTE_ID):
		if not bool(walking_receipts.get(key, false)):
			count += 1
	return count


static func compose_dynamic_final_receipt(
	cell: Dictionary,
	summary: Dictionary,
	direct_primitives: Dictionary = {},
) -> Dictionary:
	# This is the sole physical receipt constructor. It consumes the actual
	# inherited world summary and derives every decision-bearing gate again.
	var candidate_id := String(cell.get("candidate_id", ""))
	var cell_id := String(cell.get("cell_id", ""))
	if (
		not static_contract_exact(candidate_id)
		or int(summary.get("world_build_count", -1)) != 1
		or find_cell(cell_id, candidate_id).is_empty()
		or String(cell.get("challenge_profile_id", "")) != "bw6n_rough_v1"
	):
		return {}
	var candidate := candidate_declaration(candidate_id)
	var binding := candidate_binding(candidate_id)
	if candidate.is_empty() or binding.is_empty():
		return {}

	var expected_challenge := WaveGaitScript.compile_environment_challenge_options(
		challenge_profile("bw6n_rough_v1")
	)
	var expected_challenge_digest := String(
		expected_challenge.get("environment_challenge_configuration_sha256", "")
	)
	var challenge_options_exact: bool = (
		bool(expected_challenge.get("ok", false))
		and summary.get("environment_challenge_options", {})
		== expected_challenge.get("environment_challenge_options", {})
		and String(summary.get("environment_challenge_configuration_sha256", ""))
		== expected_challenge_digest
	)

	var authority_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var start_result: Dictionary = summary.get("sdk_authority_start_result", {})
	var adapter_manifest: Dictionary = start_result.get("adapter_manifest", {})
	var controller_profile: Dictionary = adapter_manifest.get("controller_profile", {})
	var expected_policy := String(candidate.get("controller_policy_id", ""))
	var expected_profile := String(candidate.get("runtime_profile_sha256", ""))
	var expected_yaw := float(candidate.get("yaw_error_stride_gain_per_rad", NAN))
	var expected_scale := float(candidate.get("global_requested_correction_scale", NAN))
	var identity_profile_scale_gate: bool = (
		candidate_binding_exact(candidate_id)
		and String(cell.get("controller_policy_id", "")) == expected_policy
		and String(cell.get("runtime_profile_sha256", "")) == expected_profile
		and absf(float(cell.get("yaw_error_stride_gain_per_rad", NAN)) - expected_yaw) <= 1.0e-12
		and absf(float(cell.get("global_requested_correction_scale", NAN)) - expected_scale) <= 1.0e-12
		and int(cell.get("expected_candidate_authority_observation_count", -1)) == 3232
		and bool(start_result.get("ok", false))
		and String(start_result.get("controller_policy_id", "")) == expected_policy
		and String(start_result.get("controller_profile_sha256", "")) == expected_profile
		and String(start_result.get("authority_scope", "")) == "post_settle_full"
		and String(start_result.get("stability_policy_id", ""))
		== "sporespore_scheduled_load_transfer_bw13p_a_v3"
		and String(adapter_manifest.get("execution_mode", ""))
		== "native_balanced_wave_base_with_stability_contribution"
		and String(adapter_manifest.get("stability_influence_scale_authority", ""))
		== "portable_core_v3"
		and absf(float(adapter_manifest.get("stability_influence_global_scale", NAN)) - expected_scale) <= 1.0e-12
		and absf(float(controller_profile.get("yaw_error_stride_gain_per_rad", NAN)) - expected_yaw) <= 1.0e-12
		and String(authority_summary.get("controller_policy_id", "")) == expected_policy
		and String(authority_summary.get("controller_profile_sha256", "")) == expected_profile
		and String(authority_summary.get("authority_scope", "")) == "post_settle_full"
		and String(authority_summary.get("stability_policy_id", ""))
		== "sporespore_scheduled_load_transfer_bw13p_a_v3"
		and absf(float(authority_summary.get("stability_influence_global_scale", NAN)) - expected_scale) <= 1.0e-12
	)

	var horizon_gate: bool = (
		bool(summary.get("candidate_authority_horizon_enabled", false))
		and String(summary.get("authority_horizon_policy_id", ""))
		== String(AUTHORITY_HORIZON_OPTIONS["policy_id"])
		and String(summary.get("authority_horizon_policy_sha256", ""))
		== String(AUTHORITY_HORIZON_OPTIONS["policy_sha256"])
		and int(summary.get("candidate_authority_observation_count", -1)) == 3232
		and int(summary.get("first_candidate_authority_observation_index", -1)) == 0
		and int(summary.get("last_candidate_authority_observation_index", -1)) == 3231
		and int(summary.get("candidate_specific_horizon_extension_count", -1)) == 0
		and int(summary.get("pre_authority_world_tick_count", -1)) == 240
		and int(summary.get("sdk_adapter_start_tick", -1)) == 240
		and int(summary.get("executed_ticks", -1)) == 3472
		and int(authority_summary.get("step_count", -1)) == 3232
	)

	var acquisition: Dictionary = summary.get("evidence_support_acquisition_receipt", {})
	var measurement_gate: bool = (
		summary.get("evidence_acquisition_options", {}) == ACQUISITION_OPTIONS
		and String(summary.get("evidence_acquisition_configuration_sha256", ""))
		== ACQUISITION_SHA256
		and bool(acquisition.get("acquired", false))
		and not bool(acquisition.get("timed_out", true))
		and not bool(acquisition.get("controller_parameter", true))
		and not bool(acquisition.get("walking_claim_authorized", true))
	)
	var actual_material: Dictionary = summary.get("sdk_material_profile", {})
	var fixture_spec: Dictionary = summary.get("fixture_spec", {})
	var material_gate: bool = (
		String(summary.get("sdk_material_profile_sha256", "")) == MATERIAL_PROFILE_SHA256
		and not actual_material.is_empty()
		and (fixture_spec.get("contact_material", {}) as Dictionary)
		== (actual_material.get("body_material", {}) as Dictionary)
	)
	var challenge_gate := _rough_challenge_gate(
		summary,
		direct_primitives,
		challenge_options_exact,
	)
	var application_count := int(authority_summary.get("native_actuation_application_count", -1))
	var application_gate := application_count == 25856
	var physical_influence := application_gate and int(authority_summary.get("step_count", -1)) == 3232
	var mechanism_gate: bool = (
		bool(start_result.get("ok", false))
		and bool(authority_summary.get("actuation_authority", false))
		and bool(authority_summary.get("balanced_wave_shadow_valid", false))
		and bool(authority_summary.get("stability_overlay_runtime_ok", false))
		and int(authority_summary.get("mismatch_count", -1)) == 0
		and int(authority_summary.get("safe_no_actuation_count", -1)) == 0
		and (authority_summary.get("failure_codes", []) as Array).is_empty()
	)
	var walking_receipts: Dictionary = summary.get("walking_gate_receipts", {})
	var outcome_complete: bool = (
		Drp1Common.walking_receipt_structurally_complete(walking_receipts, ROUTE_ID)
		and typeof(summary.get("failure_code", "")) == TYPE_STRING
		and int(summary.get("world_reset_count", -1)) == 0
	)
	var failed_walking_gate_count := _failed_walking_gate_count(walking_receipts)
	var walking_observed := outcome_complete and failed_walking_gate_count == 0
	var engine_gate: bool = (
		int(summary.get("world_build_count", -1)) == 1
		and int(summary.get("world_reset_count", -1)) == 0
		and String(summary.get("physics_engine", "")) == "Jolt Physics"
		and int(summary.get("physics_hz", -1)) == 120
		and int(summary.get("solver_velocity_steps", -1)) == 20
		and int(summary.get("solver_position_steps", -1)) == 7
	)
	var common_integrity := (
		identity_profile_scale_gate
		and horizon_gate
		and measurement_gate
		and material_gate
		and challenge_gate
		and application_gate
		and mechanism_gate
		and outcome_complete
		and engine_gate
	)
	var receipt := {
		"schema_version": FINAL_RECEIPT_SCHEMA,
		"final_receipt_composer_id": FINAL_RECEIPT_COMPOSER_ID,
		"shared_receipt_composer_passed": true,
		"campaign_id": CAMPAIGN_ID,
		"gate_id": GATE_ID,
		"route_id": ROUTE_ID,
		"dynamic_parent_summary_gate_passed": true,
		"cell_id": cell_id,
		"cohort": String(cell.get("cohort", "")),
		"role": String(cell.get("role", "")),
		"campaign_seed": int(cell.get("campaign_seed", -1)),
		"challenge_profile_id": "bw6n_rough_v1",
		"candidate_id": candidate_id,
		"candidate_composition_digest": String(binding["candidate_composition_digest"]),
		"controller_policy_id": expected_policy,
		"controller_runtime_profile_sha256": expected_profile,
		"yaw_error_stride_gain_per_rad": expected_yaw,
		"global_requested_correction_scale": expected_scale,
		"treatment_factor_count": int(candidate.get("treatment_factor_count", -1)),
		"selection_eligible": bool(candidate.get("selection_eligible", false)),
		"policy_branch_surface_count": (candidate.get("branch_surfaces", []) as Array).size(),
		"stability_policy_id": String(candidate.get("stability_policy_id", "")),
		"authority_scope": String(candidate.get("authority_scope", "")),
		"execution_mode": String(candidate.get("execution_mode", "")),
		"material_profile_id": MATERIAL_PROFILE_ID,
		"material_profile_sha256": MATERIAL_PROFILE_SHA256,
		"measurement_policy_id": String(ACQUISITION_OPTIONS["policy_id"]),
		"measurement_policy_digest": ACQUISITION_SHA256,
		"authority_horizon_policy_id": String(AUTHORITY_HORIZON_OPTIONS["policy_id"]),
		"authority_horizon_policy_sha256": String(AUTHORITY_HORIZON_OPTIONS["policy_sha256"]),
		"candidate_authority_observation_count": int(summary.get("candidate_authority_observation_count", -1)),
		"first_candidate_authority_observation_index": int(summary.get("first_candidate_authority_observation_index", -1)),
		"last_candidate_authority_observation_index": int(summary.get("last_candidate_authority_observation_index", -1)),
		"pre_authority_world_tick_count": int(summary.get("pre_authority_world_tick_count", -1)),
		"candidate_specific_horizon_extension_count": int(summary.get("candidate_specific_horizon_extension_count", -1)),
		"challenge_configuration_sha256": expected_challenge_digest,
		"identity_profile_scale_gate_passed": identity_profile_scale_gate,
		"measurement_gate_passed": measurement_gate,
		"material_gate_passed": material_gate,
		"challenge_gate_passed": challenge_gate,
		"application_gate_passed": application_gate,
		"mechanism_gate_passed": mechanism_gate,
		"common_execution_integrity": common_integrity,
		"outcome_complete": outcome_complete,
		"failure_code": String(summary.get("failure_code", "")),
		"walking_observed": walking_observed,
		"walking_gate_receipts": walking_receipts.duplicate(true),
		"failed_walking_gate_count": failed_walking_gate_count,
		"world_build_count": int(summary.get("world_build_count", -1)),
		"world_reset_count": int(summary.get("world_reset_count", -1)),
		"physics_engine": String(summary.get("physics_engine", "")),
		"physics_hz": int(summary.get("physics_hz", -1)),
		"solver_velocity_steps": int(summary.get("solver_velocity_steps", -1)),
		"solver_position_steps": int(summary.get("solver_position_steps", -1)),
		"terrain_shape_count": int(_primitive(direct_primitives, summary, "terrain_shape_count", -1)),
		"external_push_application_count": int(_primitive(direct_primitives, summary, "external_push_application_count", -1)),
		"observation_fault_application_count": int(_primitive(direct_primitives, summary, "observation_fault_application_count", -1)),
		"observation_fault_base_and_stability_count": int(_primitive(direct_primitives, summary, "observation_fault_base_and_stability_count", -1)),
		"maximum_observation_fault_component": float(_primitive(direct_primitives, summary, "maximum_observation_fault_component", NAN)),
		"physical_influence": physical_influence,
		"role_gate_passed": common_integrity,
		"development_only": true,
		"walking_claim_authorized": false,
		"nuisance_acceptance_claim_authorized": false,
		"rough_terrain_acceptance": false,
		"release_authorized": false,
		"physical_acceptance_authority": false,
	}
	return receipt if dictionary_keys_exact(receipt, FINAL_RECEIPT_KEYS) else {}


static func synthetic_parent_summary(cell: Dictionary, walking: bool) -> Dictionary:
	# This constructs the exact shape expected from the inherited physical path,
	# but callers use it only in a zero-world process and report world_build_count
	# as zero at the surrounding preflight layer.
	var candidate := candidate_declaration(String(cell.get("candidate_id", "")))
	var expected_challenge := WaveGaitScript.compile_environment_challenge_options(
		challenge_profile("bw6n_rough_v1")
	)
	if candidate.is_empty() or not bool(expected_challenge.get("ok", false)):
		return {}
	var walking_receipts: Dictionary = {}
	for key in Drp1Common.walking_receipt_keys(ROUTE_ID):
		walking_receipts[key] = true
	if not walking:
		walking_receipts[Drp1Common.walking_receipt_keys(ROUTE_ID)[0]] = false
	var profile := {
		"policy_id": String(candidate["controller_policy_id"]),
		"yaw_error_stride_gain_per_rad": float(candidate["yaw_error_stride_gain_per_rad"]),
	}
	var material_profile := {
		"profile_id": MATERIAL_PROFILE_ID,
		"body_material": {
			"friction": 0.95,
			"rough": false,
		},
	}
	var adapter_manifest := {
		"execution_mode": "native_balanced_wave_base_with_stability_contribution",
		"stability_influence_scale_authority": "portable_core_v3",
		"stability_influence_global_scale": float(candidate["global_requested_correction_scale"]),
		"controller_policy_id": String(candidate["controller_policy_id"]),
		"controller_profile_sha256": String(candidate["runtime_profile_sha256"]),
		"controller_profile": profile,
	}
	return {
		"world_build_count": 1,
		"world_reset_count": 0,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 7,
		"terrain_shape_count": 64,
		"external_push_application_count": 0,
		"observation_fault_application_count": 0,
		"observation_fault_base_and_stability_count": 0,
		"maximum_observation_fault_component": 0.0,
		"sdk_material_profile_sha256": MATERIAL_PROFILE_SHA256,
		"sdk_material_profile": material_profile,
		"fixture_spec": {
			"contact_material": (
				material_profile["body_material"] as Dictionary
			).duplicate(true),
		},
		"environment_challenge_options": (
			expected_challenge.get("environment_challenge_options", {}) as Dictionary
		).duplicate(true),
		"environment_challenge_configuration_sha256": String(
			expected_challenge["environment_challenge_configuration_sha256"]
		),
		"candidate_authority_horizon_enabled": true,
		"authority_horizon_policy_id": String(AUTHORITY_HORIZON_OPTIONS["policy_id"]),
		"authority_horizon_policy_sha256": String(AUTHORITY_HORIZON_OPTIONS["policy_sha256"]),
		"candidate_authority_observation_count": 3232,
		"first_candidate_authority_observation_index": 0,
		"last_candidate_authority_observation_index": 3231,
		"candidate_specific_horizon_extension_count": 0,
		"pre_authority_world_tick_count": 240,
		"sdk_adapter_start_tick": 240,
		"executed_ticks": 3472,
		"evidence_acquisition_options": ACQUISITION_OPTIONS.duplicate(true),
		"evidence_acquisition_configuration_sha256": ACQUISITION_SHA256,
		"evidence_support_acquisition_receipt": {
			"acquired": true,
			"timed_out": false,
			"controller_parameter": false,
			"walking_claim_authorized": false,
		},
		"sdk_authority_start_result": {
			"ok": true,
			"failure_code": "",
			"controller_policy_id": String(candidate["controller_policy_id"]),
			"controller_profile_sha256": String(candidate["runtime_profile_sha256"]),
			"authority_scope": "post_settle_full",
			"stability_policy_id": "sporespore_scheduled_load_transfer_bw13p_a_v3",
			"adapter_manifest": adapter_manifest,
		},
		"sdk_authority_summary": {
			"step_count": 3232,
			"native_actuation_application_count": 25856,
			"controller_policy_id": String(candidate["controller_policy_id"]),
			"controller_profile_sha256": String(candidate["runtime_profile_sha256"]),
			"authority_scope": "post_settle_full",
			"stability_policy_id": "sporespore_scheduled_load_transfer_bw13p_a_v3",
			"stability_influence_global_scale": float(candidate["global_requested_correction_scale"]),
			"actuation_authority": true,
			"balanced_wave_shadow_valid": true,
			"stability_overlay_runtime_ok": true,
			"mismatch_count": 0,
			"safe_no_actuation_count": 0,
			"failure_codes": [],
		},
		"walking_gate_receipts": walking_receipts,
		"failure_code": "" if walking else "WALKING_CONJUNCTION_INCOMPLETE_AT_FIXED_HORIZON",
	}


static func _attempt_source_bindings_exact(attempt: Dictionary) -> bool:
	var freeze := read_json(FREEZE_PATH)
	var expected: Dictionary = freeze.get("source_bindings", {})
	var actual: Dictionary = attempt.get("source_bindings", {})
	if expected.is_empty() or actual != expected:
		return false
	return _freeze_bindings_exact(freeze)


static func _content_addressed_inputs_exact(attempt: Dictionary, synthetic: bool) -> bool:
	var inputs: Dictionary = attempt.get("content_addressed_inputs", {})
	if synthetic:
		return inputs.is_empty()
	for required_key in [
		"godot_console",
		"godot_runtime",
		"godot_adapter",
		"full_godot_v2_attestation",
		"stage_one_freeze",
	]:
		if not inputs.has(required_key):
			return false
	for receipt_value in inputs.values():
		var receipt: Dictionary = receipt_value
		var payload_path := String(receipt.get("payload_path", ""))
		var digest := String(receipt.get("sha256", ""))
		if (
			String(receipt.get("schema_version", ""))
			!= "sporespore_content_addressed_artifact_receipt_v1"
			or payload_path.is_empty()
			or not FileAccess.file_exists(payload_path)
			or not digest.begins_with("sha256:")
			or "sha256:" + raw_sha256(payload_path) != digest
			or bool(receipt.get("test_only", true))
			or bool(receipt.get("physical_acceptance_authority", true))
		):
			return false
	if (
		String((inputs["godot_console"] as Dictionary).get("sha256", ""))
		!= "sha256:" + String(attempt.get("godot_executable_sha256", ""))
		or String((inputs["godot_runtime"] as Dictionary).get("sha256", ""))
		!= "sha256:" + String(attempt.get("godot_runtime_executable_sha256", ""))
		or String((inputs["godot_adapter"] as Dictionary).get("sha256", ""))
		!= "sha256:" + String(attempt.get("godot_adapter_artifact_sha256", ""))
		or String((inputs["full_godot_v2_attestation"] as Dictionary).get("sha256", ""))
		!= "sha256:" + String(attempt.get("full_godot_v2_attestation_sha256", ""))
		or String((inputs["stage_one_freeze"] as Dictionary).get("sha256", ""))
		!= "sha256:" + raw_sha256(FREEZE_PATH)
	):
		return false
	for binding_key in (read_json(FREEZE_PATH).get("source_bindings", {}) as Dictionary).keys():
		var source_key := "source_" + String(binding_key)
		var binding: Dictionary = (
			read_json(FREEZE_PATH).get("source_bindings", {}) as Dictionary
		).get(binding_key, {})
		if (
			not inputs.has(source_key)
			or String((inputs[source_key] as Dictionary).get("sha256", ""))
			!= "sha256:" + String(binding.get("raw_sha256", ""))
		):
			return false
	return true


static func physical_authorization_exact(
	cell_id: String,
	candidate_id: String,
	allow_synthetic: bool,
) -> bool:
	var attempt_path := OS.get_environment(AUTHORIZATION_PATH_ENV)
	var token := OS.get_environment(AUTHORIZATION_TOKEN_ENV)
	var authorized_cell := OS.get_environment(AUTHORIZED_CELL_ENV)
	var authorized_candidate := OS.get_environment(AUTHORIZED_CANDIDATE_ENV)
	var world_attempt_id := OS.get_environment(WORLD_ATTEMPT_ID_ENV)
	var campaign_attempt_id := OS.get_environment(CAMPAIGN_ATTEMPT_ID_ENV)
	if (
		attempt_path.is_empty()
		or token.is_empty()
		or authorized_cell != cell_id
		or authorized_candidate != candidate_id
		or world_attempt_id != "BW33N-P1::" + cell_id
		or not world_attempt_id in primary_world_attempt_ids()
		or campaign_attempt_id.is_empty()
		or not FileAccess.file_exists(attempt_path)
	):
		return false
	var attempt := read_json(attempt_path)
	var synthetic := bool(attempt.get("synthetic_contract_preflight", false))
	var source_exact: bool = (
		(
			String(attempt.get("source_commit", "")) == "synthetic_preflight_no_source_identity"
			and String(attempt.get("origin_main_commit", "")).is_empty()
			and String(attempt.get("remote_main_commit", "")).is_empty()
			and not bool(attempt.get("source_worktree_clean", true))
			and not bool(attempt.get("source_matches_live_github_main", true))
		)
		if synthetic
		else (
			String(attempt.get("source_commit", "")).length() == 40
			and String(attempt.get("source_commit", "")).is_valid_hex_number()
			and String(attempt.get("origin_main_commit", "")) == String(attempt.get("source_commit", ""))
			and String(attempt.get("remote_main_commit", "")) == String(attempt.get("source_commit", ""))
			and bool(attempt.get("source_worktree_clean", false))
			and bool(attempt.get("source_matches_live_github_main", false))
			and attempt_path.replace("/", "\\").contains("\\SporeSpore_Evidence\\")
		)
	)
	var attestation_exact: bool = (
		(
			String(attempt.get("full_godot_v2_attestation_path", ""))
			== "synthetic_preflight_no_attestation"
			and String(attempt.get("full_godot_v2_attestation_sha256", ""))
			== "synthetic_preflight_no_attestation"
		)
		if synthetic
		else (
			String(attempt.get("full_godot_v2_attestation_path", "")).contains("SporeSpore_Evidence")
			and String(attempt.get("full_godot_v2_attestation_sha256", "")).length() == 64
			and String(attempt.get("full_godot_v2_attestation_sha256", "")).is_valid_hex_number()
		)
	)
	return (
		String(attempt.get("schema_version", "")) == ATTEMPT_SCHEMA
		and String(attempt.get("campaign_id", "")) == CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == GATE_ID
		and synthetic == allow_synthetic
		and source_exact
		and String(attempt.get("attempt_id", "")) == campaign_attempt_id
		and campaign_attempt_id.length() == 32
		and campaign_attempt_id.is_valid_hex_number()
		and not String(attempt.get("launched_at_utc", "")).is_empty()
		and String(attempt.get("authorization_token", "")) == token
		and token.length() == 32
		and token.is_valid_hex_number()
		and String(attempt.get("godot_version", "")) == GODOT_VERSION
		and String(attempt.get("godot_executable_sha256", "")) == GODOT_EXECUTABLE_SHA256
		and String(attempt.get("godot_runtime_executable_sha256", "")) == GODOT_RUNTIME_SHA256
		and String(attempt.get("godot_adapter_artifact_sha256", "")) == raw_sha256(ADAPTER_ARTIFACT_PATH)
		and _attempt_source_bindings_exact(attempt)
		and _content_addressed_inputs_exact(attempt, synthetic)
		and bool(attempt.get("complete_zero_world_gate_passed", false))
		and bool(attempt.get("stage_one_freeze_verified", false))
		and attestation_exact
		and bool(attempt.get("physical_identity_consumed", false)) == (not synthetic)
		and not bool(attempt.get("same_identity_rerun_allowed", true))
		and not bool(attempt.get("locomotion_outcome_exposed_at_attempt", true))
		and bool(attempt.get("retained_physical_execution_serialized", false))
		and int(attempt.get("expected_world_count", -1)) == 12
		and (attempt.get("ordered_cell_ids", []) as Array) == ordered_cell_ids()
		and (attempt.get("primary_world_attempt_ids", []) as Array) == primary_world_attempt_ids()
		and not bool(attempt.get("physical_acceptance_authority", true))
	)
