class_name LabSdkBw29nWorkerCommon
extends RefCounted

const CAMPAIGN_ID := "BW29N-BW19V-NUISANCE-TRANSFER-DEVELOPMENT"
const GATE_ID := "BW29N"
const ATTEMPT_SCHEMA := "sporespore_balanced_wave_bw29n_nuisance_transfer_attempt_v1"
const FREEZE_SCHEMA := "sporespore_balanced_wave_bw29n_nuisance_transfer_freeze_v1"
const FREEZE_STATUS := "frozen_before_first_bw29n_physical_world"
const PREREGISTRATION_PATH := (
	"res://sdk/balanced_wave_bw29n_nuisance_transfer_preregistration.json"
)
const CANDIDATES_PATH := "res://sdk/balanced_wave_bw29n_nuisance_transfer_candidates.json"
const MANIFEST_PATH := "res://sdk/balanced_wave_bw29n_nuisance_transfer_manifest.json"
const BW6N_MANIFEST_PATH := "res://sdk/balanced_wave_bw6n_validation_manifest.json"
const FREEZE_PATH := "res://sdk/balanced_wave_bw29n_nuisance_transfer_freeze.json"
const DECLARATION_AUDIT_PATH := "res://tests/test_bw29n_nuisance_transfer_declaration.ps1"
const REFERENCE_WORKER_PATH := "res://tests/test_sdk_balanced_wave_bw29n_reference_worker.gd"
const SUCCESSOR_WORKER_PATH := "res://tests/test_sdk_balanced_wave_bw29n_successor_worker.gd"
const COMMON_WORKER_PATH := "res://scripts/lab/gait/sdk_bw29n_worker_common.gd"
const EVALUATOR_PATH := "res://sdk/balanced_wave_bw29n_nuisance_transfer_gate.ps1"
const SUPERVISOR_PATH := "res://sdk/run_balanced_wave_bw29n_nuisance_transfer.ps1"
const ZERO_WORLD_GATE_PATH := (
	"res://sdk/run_balanced_wave_bw29n_nuisance_transfer_zero_world_gate.ps1"
)
const ADAPTER_ARTIFACT_PATH := "res://sdk/target/debug/sporespore_godot_adapter.dll"
const PREREGISTRATION_RAW_SHA256 := "c36135a3533e4dfacffc68a530867fc5a39efe19deee62f75a981023a97fec33"
const CANDIDATES_RAW_SHA256 := "320a719cbf378766eecb4f82e83753f7d9dfa0f4e231477c839609f53b450570"
const MANIFEST_RAW_SHA256 := "c7b77f376566b19b25485984b0d72c3b1b43ea6ae3948beb551acfef2ce35ba7"
const BW6N_MANIFEST_RAW_SHA256 := "83886d8c893a4a6e5a960b06b3398d907a203a865e1ac66ed1870ea09dc3d38e"
const GODOT_VERSION := "4.7.stable.mono.official.5b4e0cb0f"
const GODOT_EXECUTABLE_SHA256 := "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
const GODOT_RUNTIME_SHA256 := "baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4"
const MATERIAL_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const MATERIAL_PROFILE_DIGEST := (
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
const AUTHORIZATION_PATH_ENV := "SPORESPORE_BW29N_ATTEMPT"
const AUTHORIZATION_TOKEN_ENV := "SPORESPORE_BW29N_TOKEN"
const AUTHORIZED_CELL_ENV := "SPORESPORE_BW29N_CELL"
const AUTHORIZED_CANDIDATE_ENV := "SPORESPORE_BW29N_CANDIDATE"
const WORLD_ATTEMPT_ID_ENV := "SPORESPORE_BW29N_WORLD_ATTEMPT_ID"
const CAMPAIGN_ATTEMPT_ID_ENV := "SPORESPORE_BW29N_CAMPAIGN_ATTEMPT_ID"
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
	"declaration_audit_raw_sha256",
	"common_worker_raw_sha256",
	"reference_worker_raw_sha256",
	"successor_worker_raw_sha256",
	"evaluator_raw_sha256",
	"supervisor_raw_sha256",
	"zero_world_gate_raw_sha256",
	"stage_one_freeze_raw_sha256",
	"complete_zero_world_gate_passed",
	"declaration_audit_passed",
	"worker_entrypoint_preflight_passed",
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
		ids.append("BW29N-P1::" + String(cell_id))
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
		and raw_sha256(BW6N_MANIFEST_PATH) == BW6N_MANIFEST_RAW_SHA256
		and String(preregistration.get("campaign_id", "")) == CAMPAIGN_ID
		and String(preregistration.get("gate_id", "")) == GATE_ID
		and String(candidates.get("campaign_id", "")) == CAMPAIGN_ID
		and (candidates.get("candidate_order", []) as Array) == ["BW29N-A", "BW29N-B"]
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
		and world_attempt_id == "BW29N-P1::" + cell_id
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
		and String(attempt.get("declaration_audit_raw_sha256", ""))
		== raw_sha256(DECLARATION_AUDIT_PATH)
		and String(attempt.get("common_worker_raw_sha256", "")) == raw_sha256(COMMON_WORKER_PATH)
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
