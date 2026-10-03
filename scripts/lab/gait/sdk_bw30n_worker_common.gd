class_name LabSdkBw30nWorkerCommon
extends RefCounted

const CAMPAIGN_ID := "BW30N-BW29N-IMPLEMENTATION-RECOVERY-DEVELOPMENT"
const GATE_ID := "BW30N"
const ATTEMPT_SCHEMA := "sporespore_balanced_wave_bw30n_recovery_attempt_v1"
const FREEZE_SCHEMA := "sporespore_balanced_wave_bw30n_recovery_freeze_v1"
const FREEZE_STATUS := "frozen_before_first_bw30n_physical_world"
const PREREGISTRATION_PATH := (
	"res://sdk/balanced_wave_bw30n_recovery_preregistration.json"
)
const CANDIDATES_PATH := "res://sdk/balanced_wave_bw30n_recovery_candidates.json"
const MANIFEST_PATH := "res://sdk/balanced_wave_bw30n_recovery_manifest.json"
const FIXED_HORIZON_PATH := "res://sdk/balanced_wave_bw30n_fixed_observation_horizon.json"
const BW6N_MANIFEST_PATH := "res://sdk/balanced_wave_bw6n_validation_manifest.json"
const FREEZE_PATH := "res://sdk/balanced_wave_bw30n_recovery_freeze.json"
const DECLARATION_AUDIT_PATH := "res://tests/test_bw30n_recovery_declaration.ps1"
const REFERENCE_WORKER_PATH := "res://tests/test_sdk_balanced_wave_bw30n_reference_worker.gd"
const SUCCESSOR_WORKER_PATH := "res://tests/test_sdk_balanced_wave_bw30n_successor_worker.gd"
const COMMON_WORKER_PATH := "res://scripts/lab/gait/sdk_bw30n_worker_common.gd"
const EVALUATOR_PATH := "res://sdk/balanced_wave_bw30n_recovery_gate.ps1"
const SUPERVISOR_PATH := "res://sdk/run_balanced_wave_bw30n_recovery.ps1"
const ZERO_WORLD_GATE_PATH := (
	"res://sdk/run_balanced_wave_bw30n_recovery_zero_world_gate.ps1"
)
const ADAPTER_ARTIFACT_PATH := "res://sdk/target/debug/sporespore_godot_adapter.dll"
const PREREGISTRATION_RAW_SHA256 := "d4ea40c06241a96eb1854392ad86cc8dc0ba2632e502bd39725fb587abe9aea8"
const CANDIDATES_RAW_SHA256 := "7725baa0fcc0693da289987d81975513b02fe1f2afee634b08ccd7161805f1dd"
const MANIFEST_RAW_SHA256 := "f9c265cc5e9a1b147edcf07e0076e8405140b217454d9cb3bc14c2ebfacf8c8d"
const FIXED_HORIZON_RAW_SHA256 := "3b76314d6d0726746644f4c66ae67da01364a353d199562f3ed9843be349d912"
const BW6N_MANIFEST_RAW_SHA256 := "83886d8c893a4a6e5a960b06b3398d907a203a865e1ac66ed1870ea09dc3d38e"
const GODOT_VERSION := "4.7.stable.mono.official.5b4e0cb0f"
const GODOT_EXECUTABLE_SHA256 := "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
const GODOT_RUNTIME_SHA256 := "baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4"
const MATERIAL_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const MATERIAL_PROFILE_SHA256 := (
	"sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
)
const ACQUISITION_OPTIONS := {
	"policy_id": "bounded_all_support_acquisition_v1",
	"enabled": true,
	"maximum_acquisition_ticks": 15,
	"minimum_all_support_dwell_ticks": 3,
}
const ACQUISITION_SHA256 := (
	"sha256:4a49770e35b67b2186a5a64ad3dcbf7d1d637e9ffc6ea2a9365615731eb2e748"
)
const FIXED_HORIZON_OPTIONS := {
	"policy_id": "fixed_post_sdk_observation_horizon_v1",
	"policy_sha256": "sha256:" + FIXED_HORIZON_RAW_SHA256,
	"first_post_sdk_observation_index": 0,
	"last_post_sdk_observation_index": 1513,
	"exact_post_sdk_observation_count": 1514,
	"candidate_specific_horizon_extension_count": 0,
}
const FINAL_RECEIPT_SCHEMA := "sporespore_balanced_wave_bw30n_recovery_raw_cell_v1"
const FINAL_RECEIPT_COMPOSER_ID := "bw30n_shared_final_receipt_composer_v1"
const FINAL_RECEIPT_INPUT_KEYS := [
	"cell_id",
	"campaign_seed",
	"challenge_profile_id",
	"candidate_id",
	"candidate_composition_digest",
	"controller_policy_id",
	"controller_policy_digest",
	"stability_policy_id",
	"authority_scope",
	"execution_mode",
	"challenge_configuration_sha256",
	"measurement_gate_passed",
	"challenge_gate_passed",
	"application_gate_passed",
	"common_execution_integrity",
	"outcome_complete",
	"walking_observed",
	"walking_gate_receipts",
	"world_build_count",
	"world_reset_count",
	"physics_engine",
	"physics_hz",
	"solver_velocity_steps",
	"solver_position_steps",
	"terrain_shape_count",
	"external_push_application_count",
	"observation_fault_application_count",
	"observation_fault_base_and_stability_count",
	"maximum_observation_fault_component",
	"physical_influence",
	"post_sdk_observation_count",
	"first_post_sdk_observation_index",
	"last_post_sdk_observation_index",
	"candidate_specific_horizon_extension_count",
]
const FINAL_RECEIPT_KEYS := [
	"schema_version",
	"final_receipt_composer_id",
	"shared_receipt_composer_passed",
	"campaign_id",
	"gate_id",
	"cell_id",
	"cohort",
	"role",
	"campaign_seed",
	"challenge_profile_id",
	"candidate_id",
	"candidate_composition_digest",
	"controller_policy_id",
	"controller_policy_digest",
	"stability_policy_id",
	"authority_scope",
	"execution_mode",
	"material_profile_id",
	"material_profile_sha256",
	"measurement_policy_id",
	"measurement_policy_digest",
	"terminal_horizon_policy_id",
	"terminal_horizon_policy_sha256",
	"post_sdk_observation_count",
	"first_post_sdk_observation_index",
	"last_post_sdk_observation_index",
	"candidate_specific_horizon_extension_count",
	"challenge_configuration_sha256",
	"measurement_gate_passed",
	"challenge_gate_passed",
	"application_gate_passed",
	"common_execution_integrity",
	"outcome_complete",
	"walking_observed",
	"walking_gate_receipts",
	"world_build_count",
	"world_reset_count",
	"physics_engine",
	"physics_hz",
	"solver_velocity_steps",
	"solver_position_steps",
	"terrain_shape_count",
	"external_push_application_count",
	"observation_fault_application_count",
	"observation_fault_base_and_stability_count",
	"maximum_observation_fault_component",
	"physical_influence",
	"role_gate_passed",
	"development_only",
	"walking_claim_authorized",
	"nuisance_acceptance_claim_authorized",
	"release_authorized",
	"physical_acceptance_authority",
]
const AUTHORIZATION_PATH_ENV := "SPORESPORE_BW30N_ATTEMPT"
const AUTHORIZATION_TOKEN_ENV := "SPORESPORE_BW30N_TOKEN"
const AUTHORIZED_CELL_ENV := "SPORESPORE_BW30N_CELL"
const AUTHORIZED_CANDIDATE_ENV := "SPORESPORE_BW30N_CANDIDATE"
const WORLD_ATTEMPT_ID_ENV := "SPORESPORE_BW30N_WORLD_ATTEMPT_ID"
const CAMPAIGN_ATTEMPT_ID_ENV := "SPORESPORE_BW30N_CAMPAIGN_ATTEMPT_ID"
const ATTEMPT_KEYS := [
	"schema_version",
	"campaign_id",
	"gate_id",
	"synthetic_contract_preflight",
	"source_commit",
	"origin_main_commit",
	"remote_main_commit",
	"source_worktree_clean",
	"source_matches_live_github_main",
	"attempt_id",
	"launched_at_utc",
	"authorization_token",
	"godot_version",
	"godot_executable_sha256",
	"godot_runtime_executable_sha256",
	"godot_adapter_artifact_sha256",
	"preregistration_raw_sha256",
	"candidates_raw_sha256",
	"manifest_raw_sha256",
	"fixed_horizon_raw_sha256",
	"declaration_audit_raw_sha256",
	"common_worker_raw_sha256",
	"fixed_horizon_runner_raw_sha256",
	"reference_worker_raw_sha256",
	"successor_worker_raw_sha256",
	"evaluator_raw_sha256",
	"supervisor_raw_sha256",
	"zero_world_gate_raw_sha256",
	"stage_one_freeze_raw_sha256",
	"complete_zero_world_gate_passed",
	"declaration_audit_passed",
	"worker_entrypoint_preflight_passed",
	"real_shaped_receipt_preflight_passed",
	"shared_receipt_composer_passed",
	"fixed_observation_horizon_preflight_passed",
	"evaluator_negative_controls_passed",
	"attempt_contract_preflight_passed",
	"stage_one_freeze_verified",
	"full_godot_v2_attestation_path",
	"full_godot_v2_attestation_sha256",
	"physical_identity_consumed",
	"same_identity_rerun_allowed",
	"locomotion_outcome_exposed_at_attempt",
	"physical_acceptance_authority",
	"retained_physical_execution_serialized",
	"expected_world_count",
	"ordered_cell_ids",
	"primary_world_attempt_ids",
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


static func ordered_cell_ids() -> Array:
	var ids: Array = []
	var manifest := read_json(MANIFEST_PATH)
	for cell_value in manifest.get("ordered_cells", []):
		ids.append(String((cell_value as Dictionary).get("cell_id", "")))
	return ids


static func primary_world_attempt_ids() -> Array:
	var ids: Array = []
	for cell_id in ordered_cell_ids():
		ids.append("BW30N-P1::" + String(cell_id))
	return ids


static func find_cell(cell_id: String, candidate_id: String = "") -> Dictionary:
	var manifest := read_json(MANIFEST_PATH)
	for cell_value in manifest.get("ordered_cells", []):
		var cell: Dictionary = cell_value
		if (
			String(cell.get("cell_id", "")) == cell_id
			and (candidate_id.is_empty() or String(cell.get("candidate_id", "")) == candidate_id)
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


static func static_contract_exact(candidate_id: String) -> bool:
	var preregistration := read_json(PREREGISTRATION_PATH)
	var candidates := read_json(CANDIDATES_PATH)
	var manifest := read_json(MANIFEST_PATH)
	var freeze := read_json(FREEZE_PATH)
	var candidate_count := 0
	for cell_value in manifest.get("ordered_cells", []):
		if String((cell_value as Dictionary).get("candidate_id", "")) == candidate_id:
			candidate_count += 1
	var bindings: Dictionary = freeze.get("source_bindings", {})
	var bindings_exact: bool = not bindings.is_empty()
	for binding_value in bindings.values():
		var binding: Dictionary = binding_value
		var path := "res://" + String(binding.get("path", ""))
		bindings_exact = (
			bindings_exact
			and FileAccess.file_exists(path)
			and raw_sha256(path) == String(binding.get("raw_sha256", ""))
		)
	return (
		raw_sha256(PREREGISTRATION_PATH) == PREREGISTRATION_RAW_SHA256
		and raw_sha256(CANDIDATES_PATH) == CANDIDATES_RAW_SHA256
		and raw_sha256(MANIFEST_PATH) == MANIFEST_RAW_SHA256
		and raw_sha256(FIXED_HORIZON_PATH) == FIXED_HORIZON_RAW_SHA256
		and raw_sha256(BW6N_MANIFEST_PATH) == BW6N_MANIFEST_RAW_SHA256
		and String(preregistration.get("campaign_id", "")) == CAMPAIGN_ID
		and String(preregistration.get("gate_id", "")) == GATE_ID
		and String(candidates.get("campaign_id", "")) == CAMPAIGN_ID
		and (candidates.get("candidate_order", []) as Array) == ["BW30N-A", "BW30N-B"]
		and String(manifest.get("campaign_id", "")) == CAMPAIGN_ID
		and String(manifest.get("gate_id", "")) == GATE_ID
		and (manifest.get("ordered_cells", []) as Array).size() == 24
		and candidate_count == 12
		and not bool(manifest.get("physical_execution_authorized", true))
		and String(freeze.get("schema_version", "")) == FREEZE_SCHEMA
		and String(freeze.get("status", "")) == FREEZE_STATUS
		and String(freeze.get("campaign_id", "")) == CAMPAIGN_ID
		and String(freeze.get("gate_id", "")) == GATE_ID
		and int((freeze.get("physical_matrix", {}) as Dictionary).get("expected_world_count", -1))
		== 24
		and not bool(freeze.get("physical_execution_authorized_by_freeze", true))
		and bindings_exact
	)


static func compose_final_receipt(source: Dictionary) -> Dictionary:
	if not dictionary_keys_exact(source, FINAL_RECEIPT_INPUT_KEYS):
		return {}
	var candidate_id := String(source.get("candidate_id", ""))
	var expected_digest := (
		"sha256:794b42e64e1a89f371b0113ad1c3cf14c0a3d87abfed876323eda9e4aaeed1e6"
		if candidate_id == "BW30N-A"
		else (
			"sha256:3490c1934bb018ef68a54b5d5415c7d19dddf7696ee0ac7fca4ab27951957e4d"
			if candidate_id == "BW30N-B"
			else ""
		)
	)
	var horizon_exact := (
		int(source.get("post_sdk_observation_count", -1)) == 1514
		and int(source.get("first_post_sdk_observation_index", -1)) == 0
		and int(source.get("last_post_sdk_observation_index", -1)) == 1513
		and int(source.get("candidate_specific_horizon_extension_count", -1)) == 0
	)
	var identity_exact := (
		not String(source.get("cell_id", "")).is_empty()
		and int(source.get("campaign_seed", -1)) in [21001, 21002, 21003]
		and String(source.get("challenge_profile_id", "")) in [
			"bw6n_baseline_v1",
			"bw6n_rough_v1",
			"bw6n_push_v1",
			"bw6n_sensor_noise_v1",
		]
		and not expected_digest.is_empty()
		and String(source.get("candidate_composition_digest", "")) == expected_digest
	)
	if not identity_exact:
		return {}
	var common_integrity := bool(source.get("common_execution_integrity", false)) and horizon_exact
	var receipt := {
		"schema_version": FINAL_RECEIPT_SCHEMA,
		"final_receipt_composer_id": FINAL_RECEIPT_COMPOSER_ID,
		"shared_receipt_composer_passed": true,
		"campaign_id": CAMPAIGN_ID,
		"gate_id": GATE_ID,
		"cell_id": String(source["cell_id"]),
		"cohort": "paired_outcome_exposed_implementation_recovery",
		"role": "candidate",
		"campaign_seed": int(source["campaign_seed"]),
		"challenge_profile_id": String(source["challenge_profile_id"]),
		"candidate_id": candidate_id,
		"candidate_composition_digest": expected_digest,
		"controller_policy_id": String(source["controller_policy_id"]),
		"controller_policy_digest": String(source["controller_policy_digest"]),
		"stability_policy_id": String(source["stability_policy_id"]),
		"authority_scope": String(source["authority_scope"]),
		"execution_mode": String(source["execution_mode"]),
		"material_profile_id": MATERIAL_PROFILE_ID,
		"material_profile_sha256": MATERIAL_PROFILE_SHA256,
		"measurement_policy_id": String(ACQUISITION_OPTIONS["policy_id"]),
		"measurement_policy_digest": ACQUISITION_SHA256,
		"terminal_horizon_policy_id": String(FIXED_HORIZON_OPTIONS["policy_id"]),
		"terminal_horizon_policy_sha256": String(FIXED_HORIZON_OPTIONS["policy_sha256"]),
		"post_sdk_observation_count": int(source["post_sdk_observation_count"]),
		"first_post_sdk_observation_index": int(source["first_post_sdk_observation_index"]),
		"last_post_sdk_observation_index": int(source["last_post_sdk_observation_index"]),
		"candidate_specific_horizon_extension_count": int(
			source["candidate_specific_horizon_extension_count"]
		),
		"challenge_configuration_sha256": String(source["challenge_configuration_sha256"]),
		"measurement_gate_passed": bool(source["measurement_gate_passed"]),
		"challenge_gate_passed": bool(source["challenge_gate_passed"]),
		"application_gate_passed": bool(source["application_gate_passed"]),
		"common_execution_integrity": common_integrity,
		"outcome_complete": bool(source["outcome_complete"]),
		"walking_observed": bool(source["walking_observed"]),
		"walking_gate_receipts": (source["walking_gate_receipts"] as Dictionary).duplicate(true),
		"world_build_count": int(source["world_build_count"]),
		"world_reset_count": int(source["world_reset_count"]),
		"physics_engine": String(source["physics_engine"]),
		"physics_hz": int(source["physics_hz"]),
		"solver_velocity_steps": int(source["solver_velocity_steps"]),
		"solver_position_steps": int(source["solver_position_steps"]),
		"terrain_shape_count": int(source["terrain_shape_count"]),
		"external_push_application_count": int(source["external_push_application_count"]),
		"observation_fault_application_count": int(source["observation_fault_application_count"]),
		"observation_fault_base_and_stability_count": int(
			source["observation_fault_base_and_stability_count"]
		),
		"maximum_observation_fault_component": float(
			source["maximum_observation_fault_component"]
		),
		"physical_influence": bool(source["physical_influence"]),
		"role_gate_passed": common_integrity,
		"development_only": true,
		"walking_claim_authorized": false,
		"nuisance_acceptance_claim_authorized": false,
		"release_authorized": false,
		"physical_acceptance_authority": false,
	}
	return receipt if dictionary_keys_exact(receipt, FINAL_RECEIPT_KEYS) else {}


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
		or world_attempt_id.is_empty()
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
			and String(attempt.get("origin_main_commit", ""))
			== String(attempt.get("source_commit", ""))
			and String(attempt.get("remote_main_commit", ""))
			== String(attempt.get("source_commit", ""))
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
			String(attempt.get("full_godot_v2_attestation_path", "")).contains(
				"SporeSpore_Evidence"
			)
			and String(attempt.get("full_godot_v2_attestation_sha256", "")).length() == 64
			and String(attempt.get("full_godot_v2_attestation_sha256", "")).is_valid_hex_number()
		)
	)
	return (
		dictionary_keys_exact(attempt, ATTEMPT_KEYS)
		and String(attempt.get("schema_version", "")) == ATTEMPT_SCHEMA
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
		and world_attempt_id == "BW30N-P1::" + cell_id
		and world_attempt_id in primary_world_attempt_ids()
		and String(attempt.get("godot_version", "")) == GODOT_VERSION
		and String(attempt.get("godot_executable_sha256", "")) == GODOT_EXECUTABLE_SHA256
		and String(attempt.get("godot_runtime_executable_sha256", ""))
		== GODOT_RUNTIME_SHA256
		and String(attempt.get("godot_adapter_artifact_sha256", ""))
		== raw_sha256(ADAPTER_ARTIFACT_PATH)
		and String(attempt.get("preregistration_raw_sha256", ""))
		== raw_sha256(PREREGISTRATION_PATH)
		and String(attempt.get("candidates_raw_sha256", "")) == raw_sha256(CANDIDATES_PATH)
		and String(attempt.get("manifest_raw_sha256", "")) == raw_sha256(MANIFEST_PATH)
		and String(attempt.get("fixed_horizon_raw_sha256", ""))
		== raw_sha256(FIXED_HORIZON_PATH)
		and String(attempt.get("declaration_audit_raw_sha256", ""))
		== raw_sha256(DECLARATION_AUDIT_PATH)
		and String(attempt.get("common_worker_raw_sha256", "")) == raw_sha256(COMMON_WORKER_PATH)
		and String(attempt.get("fixed_horizon_runner_raw_sha256", ""))
		== raw_sha256(
			"res://scripts/lab/gait/physical_wave_gait_quadruped_bw30n_fixed_horizon.gd"
		)
		and String(attempt.get("reference_worker_raw_sha256", ""))
		== raw_sha256(REFERENCE_WORKER_PATH)
		and String(attempt.get("successor_worker_raw_sha256", ""))
		== raw_sha256(SUCCESSOR_WORKER_PATH)
		and String(attempt.get("evaluator_raw_sha256", "")) == raw_sha256(EVALUATOR_PATH)
		and String(attempt.get("supervisor_raw_sha256", "")) == raw_sha256(SUPERVISOR_PATH)
		and String(attempt.get("zero_world_gate_raw_sha256", ""))
		== raw_sha256(ZERO_WORLD_GATE_PATH)
		and String(attempt.get("stage_one_freeze_raw_sha256", "")) == raw_sha256(FREEZE_PATH)
		and bool(attempt.get("complete_zero_world_gate_passed", false))
		and bool(attempt.get("declaration_audit_passed", false))
		and bool(attempt.get("worker_entrypoint_preflight_passed", false))
		and bool(attempt.get("real_shaped_receipt_preflight_passed", false))
		and bool(attempt.get("shared_receipt_composer_passed", false))
		and bool(attempt.get("fixed_observation_horizon_preflight_passed", false))
		and bool(attempt.get("evaluator_negative_controls_passed", false))
		and bool(attempt.get("attempt_contract_preflight_passed", false))
		and bool(attempt.get("stage_one_freeze_verified", false))
		and attestation_exact
		and bool(attempt.get("physical_identity_consumed", false)) == (not synthetic)
		and not bool(attempt.get("same_identity_rerun_allowed", true))
		and bool(attempt.get("locomotion_outcome_exposed_at_attempt", false))
		and not bool(attempt.get("physical_acceptance_authority", true))
		and bool(attempt.get("retained_physical_execution_serialized", false))
		and int(attempt.get("expected_world_count", -1)) == 24
		and (attempt.get("ordered_cell_ids", []) as Array) == ordered_cell_ids()
		and (attempt.get("primary_world_attempt_ids", []) as Array) == primary_world_attempt_ids()
	)


static func dictionary_keys_exact(value: Dictionary, expected: Array) -> bool:
	var actual_keys: Array = []
	for key in value.keys():
		actual_keys.append(String(key))
	actual_keys.sort()
	var expected_keys := expected.duplicate()
	expected_keys.sort()
	return actual_keys == expected_keys
