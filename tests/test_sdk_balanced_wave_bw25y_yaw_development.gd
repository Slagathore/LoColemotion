extends "res://tests/test_sdk_balanced_wave_bw20f_material_locomotion.gd"
# gdlint: disable=max-line-length
# gdlint: disable=max-returns
# gdlint: disable=max-file-lines

## BW25Y outcome-unexposed finite yaw-gain development worker.
##
## This is a distinct successor to the immutable infrastructure-invalid BW22L
## result. Its preflight traverses all 28 declared entrypoints without building
## a world. Physical mode remains unreachable until a hash-bound stage-one
## freeze and an exact durable supervisor attempt authorize one cell. The
## worker emits a raw physical receipt; the PowerShell production composer is
## the sole owner of the final four-key decision receipt.

const Bw25CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const Bw25PolicyRelativeIntegrityScript := preload(
	"res://scripts/lab/gait/sdk_policy_relative_execution_integrity.gd"
)
const BW25Y_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw25y_yaw_development_preregistration.json"
const BW25Y_CANDIDATES_PATH := "res://sdk/balanced_wave_bw25y_yaw_development_candidates.json"
const BW25Y_FREEZE_PATH := "res://sdk/balanced_wave_bw25y_yaw_development_freeze.json"
const BW25Y_SCHEMA := "sporespore_balanced_wave_bw25y_yaw_development_preregistration_v1"
const BW25Y_STATUS := "prospective_stage_zero_zero_world_only_physical_execution_blocked"
const BW25Y_FREEZE_SCHEMA := "sporespore_balanced_wave_bw25y_yaw_development_freeze_v1"
const BW25Y_FREEZE_STATUS := "frozen_before_first_bw25y_physical_world"
const BW25Y_CAMPAIGN_ID := "BW25Y-FRESH-MATERIAL-YAW-DEVELOPMENT"
const BW25Y_GATE_ID := "BW25Y"
const BW25Y_RAW_CELL_SCHEMA := "sporespore_balanced_wave_bw25y_yaw_development_raw_cell_v1"
const BW25Y_PREFLIGHT_SCHEMA := "sporespore_balanced_wave_bw25y_yaw_development_entrypoint_preflight_v1"
const BW25Y_RAW_CELL_PREFIX := "BW25Y_YAW_DEVELOPMENT_RAW_CELL "
const BW25Y_PREFLIGHT_PREFIX := "BW25Y_YAW_DEVELOPMENT_PREFLIGHT "
const BW25Y_AUTHORIZATION_PREFLIGHT_PREFIX := "BW25Y_YAW_DEVELOPMENT_AUTHORIZATION_PREFLIGHT "
const BW25Y_AUTHORIZATION_PATH_ENV := "SPORESPORE_BW25Y_ATTEMPT"
const BW25Y_AUTHORIZATION_TOKEN_ENV := "SPORESPORE_BW25Y_TOKEN"
const BW25Y_AUTHORIZED_CELL_ENV := "SPORESPORE_BW25Y_CELL"
const BW25Y_WORLD_ATTEMPT_ID_ENV := "SPORESPORE_BW25Y_WORLD_ATTEMPT_ID"
const BW25Y_CAMPAIGN_ATTEMPT_ID_ENV := "SPORESPORE_BW25Y_CAMPAIGN_ATTEMPT_ID"
const BW25Y_ADAPTER_ARTIFACT_PATH := "res://sdk/target/debug/sporespore_godot_adapter.dll"
const BW25Y_ATTEMPT_SCHEMA := "sporespore_balanced_wave_bw25y_yaw_development_attempt_v1"
const BW25Y_EVALUATOR_PATH := "res://sdk/balanced_wave_bw25y_yaw_development_gate.ps1"
const BW25Y_WORKER_PATH := "res://tests/test_sdk_balanced_wave_bw25y_yaw_development.gd"
const BW25Y_SUPERVISOR_PATH := "res://sdk/run_balanced_wave_bw25y_yaw_development.ps1"
const BW25Y_GODOT_VERSION := "4.7.stable.mono.official.5b4e0cb0f"
const BW25Y_GODOT_EXECUTABLE_SHA256 := "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
const BW25Y_GODOT_RUNTIME_SHA256 := "baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4"
const BW25Y_ATTEMPT_KEYS := [
	"schema_version",
	"campaign_id",
	"gate_id",
	"synthetic_contract_preflight",
	"attempt_id",
	"launched_at_utc",
	"source_commit",
	"origin_main_commit",
	"remote_main_commit",
	"source_worktree_clean",
	"source_matches_live_github_main",
	"godot_version",
	"godot_executable_sha256",
	"godot_runtime_executable_sha256",
	"godot_adapter_artifact_sha256",
	"preregistration_raw_sha256",
	"candidates_raw_sha256",
	"evaluator_raw_sha256",
	"physical_worker_raw_sha256",
	"physical_supervisor_raw_sha256",
	"stage_one_freeze_raw_sha256",
	"complete_zero_world_gate_passed",
	"authority_contract_passed",
	"receipt_parity_passed",
	"worker_entrypoint_preflight_passed",
	"attempt_contract_preflight_passed",
	"stage_one_freeze_verified",
	"expected_gate_count",
	"expected_world_count",
	"expected_adapter_start_count",
	"ordered_cell_ids",
	"primary_world_attempt_ids",
	"replacement_world_attempt_ids",
	"replacement_budget_per_incomplete_cell",
	"authorization_token",
	"physical_identity_consumed",
	"same_identity_rerun_allowed",
	"locomotion_outcome_exposed_at_attempt",
	"physical_acceptance_authority",
	"retained_physical_execution_serialized",
]
const BW25Y_REFERENCE_MORPHOLOGY_ID := "godot_jolt_stability_physical_influence_reference"
const BW25Y_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_a_v3"
const BW25Y_EXECUTION_MODE := "native_balanced_wave_base_with_stability_contribution"
const BW25Y_CANDIDATE_IDS := ["BW25Y-A", "BW25Y-B"]
const BW25Y_POLICY_IDS := [
	"sporespore_balanced_wave_bw15f_b_v1",
	"sporespore_balanced_wave_bw23y_b_v1",
]
const BW25Y_RUNTIME_PROFILE_SHA256 := [
	"sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413",
	"sha256:d345d9607bed545ee6c58a20055cd6258f38ed581dd3d9f6490a9ae7f1a57570",
]
const BW25Y_COMPOSITION_DIGESTS := [
	"sha256:3a2e04cfa76c63f829d9828b125a8de2e0c0fe35e75b29d8caf87866ce1ea913",
	"sha256:cba24c1ac86b4cc629723d86609af58a17e88b23c041c4e8bca5deb766704a57",
]
const BW25Y_CONTROL_ID := "BW25Y-CONTROL"
const BW25Y_CONTROL_DIGEST := "sha256:06383da3e7d5701b1547f32193f4989cc38cabbbd49e5eef5a56c33120a62f12"
const BW25Y_CANDIDATES_RAW_SHA256 := "02e7b3de50e9ca108f0c8e1508c10422361b3be6d5aa3d86e1db67348e0afb50"
const BW25Y_BW22L_CLOSURE_RAW_SHA256 := "e35a93c19613a302e72800d1be9222970ef127fd0028baf8e7440e620e2929e5"
const BW25Y_BW24P_PROFILE_CLOSURE_RAW_SHA256 := "c8a0b9d64740a79562e2f07c85f366921cc585b5429e938a360a3489a1585cfa"
const BW25Y_PROFILE_TOKENS := ["059", "071", "083"]
const BW25Y_PROFILE_IDS := [
	"godot_jolt_bw24m_mu059_v1",
	"godot_jolt_bw24m_mu071_v1",
	"godot_jolt_bw24m_mu083_v1",
]
const BW25Y_PROFILE_DIGESTS := [
	"sha256:2d8a2571c129dbe7b2b894bae1aa28f5650fdbea27fcb65a149566c54a536173",
	"sha256:a8efdd111b740391931219d720079beffeea8181e5c46fd00ea7acb6108ab8ee",
	"sha256:e5916d9e17f87120e5cc04ff03e8688c4dea3919715a68854a8dce29e4d9c2a0",
]
const BW25Y_CONTROLLER_COEFFICIENTS := [0.58, 0.68, 0.81]
const BW25Y_AUTHORED_FRICTIONS := [0.59, 0.71, 0.83]
const BW25Y_SEEDS := [26011, 26012, 26013, 26014]
const BW25Y_REFERENCE_DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": BW25Y_REFERENCE_MORPHOLOGY_ID,
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 18.0 / 35.0,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}

var _bw25y_cell: Dictionary = {}
var _bw25y_profile_id := ""


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": BW25Y_PREREGISTRATION_PATH,
		"preregistration_schema": BW25Y_SCHEMA,
		"preregistration_status": BW25Y_STATUS,
		"campaign_id": BW25Y_CAMPAIGN_ID,
		"gate_id": BW25Y_GATE_ID,
		"campaign_seeds": BW25Y_SEEDS.duplicate(),
		"entrypoint_receipt_schema": BW25Y_PREFLIGHT_SCHEMA,
		"cell_receipt_schema": BW25Y_RAW_CELL_SCHEMA,
		"entrypoint_prefix": BW25Y_PREFLIGHT_PREFIX,
		"cell_prefix": BW25Y_RAW_CELL_PREFIX,
		"display_name": "BW25Y material yaw-gain development",
	}


func _candidate_index() -> int:
	return 1 if not _bw25y_cell.is_empty() else -1


func _bw19v_candidate_index() -> int:
	if _bw25y_cell.is_empty():
		return -1
	return 0 if String(_bw25y_cell.get("role", "")) == "control" else 1


func _candidate_id() -> String:
	return String(_bw25y_cell.get("candidate_id", ""))


func _candidate_composition_digest() -> String:
	return String(_bw25y_cell.get("candidate_composition_digest", ""))


func _candidate_global_scale() -> float:
	return float(_bw25y_cell.get("global_requested_correction_scale", NAN))


func _candidate_authority_scope() -> String:
	return "post_settle_full" if not _bw25y_cell.is_empty() else ""


func _controller_candidate_id() -> String:
	return _candidate_id()


func _controller_policy_id() -> String:
	return String(_bw25y_cell.get("controller_policy_id", ""))


func _controller_policy_digest() -> String:
	return String(_bw25y_cell.get("runtime_profile_sha256", ""))


func _stability_policy_id() -> String:
	return BW25Y_STABILITY_POLICY_ID if not _bw25y_cell.is_empty() else ""


func _expected_full_authority_execution_mode() -> String:
	return BW25Y_EXECUTION_MODE if not _bw25y_cell.is_empty() else ""


func _walking_required_for_cell_success() -> bool:
	return false


func _material_profile_id() -> String:
	return _bw25y_profile_id


func _run() -> void:
	print("\n=== BW25Y material yaw-gain development ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var manifest := _read_json(BW25Y_PREREGISTRATION_PATH)
	if not _validate_bw25y_manifest(manifest):
		push_error("BW25Y frozen manifest, candidate, or prerequisite identity changed")
		quit(1)
		return
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() == 1 and String(user_args[0]) == "preflight":
		await _run_bw25y_entrypoint_preflight(manifest)
		return
	if user_args.size() == 2 and String(user_args[0]) == "authorization_preflight":
		_run_bw25y_authorization_preflight(manifest, String(user_args[1]))
		return
	if user_args.size() != 2 or String(user_args[0]) != "physical":
		push_error(
			(
				"BW25Y accepts exactly 'preflight', "
				+ "'authorization_preflight <cell_id>', or 'physical <cell_id>'"
			)
		)
		quit(1)
		return
	var cell := _find_manifest_cell(manifest, String(user_args[1]))
	if cell.is_empty():
		push_error("BW25Y physical cell is not in the frozen matrix")
		quit(1)
		return
	if not _bw25y_physical_authorization_exact(String(cell["cell_id"]), false):
		push_error("BW25Y physical entry requires exact retained supervisor authorization")
		quit(1)
		return
	_configure_cell(cell)
	var receipt: Dictionary
	if String(cell["role"]) == "safety":
		var summary := await _run_zero_safety_cell(cell, false)
		receipt = _bw25y_zero_safety_receipt(cell, summary)
	else:
		var summary := await _run_cell(0, int(cell["campaign_seed"]), false)
		receipt = _bw25y_physical_cell_receipt(cell, summary)
	_clear_cell_configuration()
	# Reaching this point means the declared world finished and emitted its full,
	# identity-bound observation.  Scientific/integrity failure is deliberately
	# separate from structural receipt completeness: a mechanism failure, a
	# non-walking outcome, or another complete negative must become the final
	# observation for this cell and must never buy a replacement world.
	var role_gate_passed := _role_gate_passed(receipt)
	receipt["raw_receipt_complete"] = true
	receipt["role_gate_passed"] = role_gate_passed
	receipt["walking_result_controls_process_exit"] = false
	receipt["world_attempt_id"] = OS.get_environment(BW25Y_WORLD_ATTEMPT_ID_ENV)
	receipt["campaign_attempt_id"] = OS.get_environment(BW25Y_CAMPAIGN_ATTEMPT_ID_ENV)
	print(BW25Y_RAW_CELL_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0)


func _run_bw25y_authorization_preflight(manifest: Dictionary, cell_id: String) -> void:
	var root_children_before := root.get_child_count()
	var cell := _find_manifest_cell(manifest, cell_id)
	var authorization_exact := (
		not cell.is_empty() and _bw25y_physical_authorization_exact(cell_id, true)
	)
	var receipt := {
		"schema_version":
		"sporespore_balanced_wave_bw25y_yaw_development_" + "authorization_preflight_v1",
		"campaign_id": BW25Y_CAMPAIGN_ID,
		"gate_id": BW25Y_GATE_ID,
		"cell_id": cell_id,
		"cell_declared": not cell.is_empty(),
		"authorization_exact": authorization_exact,
		"world_attempt_id": OS.get_environment(BW25Y_WORLD_ATTEMPT_ID_ENV),
		"campaign_attempt_id": OS.get_environment(BW25Y_CAMPAIGN_ATTEMPT_ID_ENV),
		"adapter_artifact_sha256": _raw_sha256(BW25Y_ADAPTER_ARTIFACT_PATH),
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count() - root_children_before,
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(BW25Y_AUTHORIZATION_PREFLIGHT_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if authorization_exact else 1)


func _run_bw25y_entrypoint_preflight(manifest: Dictionary) -> void:
	var root_children_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var receipts: Array = []
	var all_exact := true
	var candidate_count := 0
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
			if String(cell["role"]) == "candidate":
				candidate_count += 1
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
		"schema_version": BW25Y_PREFLIGHT_SCHEMA,
		"ok":
		(
			all_exact
			and receipts.size() == 28
			and candidate_count == 24
			and control_count == 3
			and safety_count == 1
			and adapter_start_count == 27
			and root.get_child_count() == root_children_before
			and Engine.physics_ticks_per_second == physics_hz_before
		),
		"campaign_id": BW25Y_CAMPAIGN_ID,
		"gate_id": BW25Y_GATE_ID,
		"cell_ids": _expected_cell_ids(),
		"entrypoint_receipts": receipts,
		"entrypoint_count": receipts.size(),
		"candidate_entrypoint_count": candidate_count,
		"control_entrypoint_count": control_count,
		"safety_entrypoint_count": safety_count,
		"adapter_start_count": adapter_start_count,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count() - root_children_before,
		"physics_state_modified": Engine.physics_ticks_per_second != physics_hz_before,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(BW25Y_PREFLIGHT_PREFIX, JSON.stringify(aggregate, "", true, true))
	quit(0 if bool(aggregate["ok"]) else 1)


func _configure_cell(cell: Dictionary) -> void:
	_bw25y_cell = cell.duplicate(true)
	_bw25y_profile_id = String(cell.get("profile_id", ""))


func _clear_cell_configuration() -> void:
	_bw25y_cell = {}
	_bw25y_profile_id = ""
	OS.unset_environment(BW19V_CANDIDATE_ENVIRONMENT_VARIABLE)


func _validate_controller_policy_contract(
	preregistration: Dictionary,
	_selected_policy: Dictionary,
) -> bool:
	if _bw25y_cell.is_empty():
		return false
	var declarations := _read_json(BW25Y_CANDIDATES_PATH)
	var candidates: Array = declarations.get("candidates", [])
	var candidate: Dictionary = {}
	if String(_bw25y_cell.get("role", "")) == "control":
		candidate = declarations.get("policy_relative_control", {})
	else:
		for candidate_value in candidates:
			var possible: Dictionary = candidate_value
			if String(possible.get("candidate_id", "")) == _candidate_id():
				candidate = possible
				break
	if candidate.is_empty():
		return false
	var digest := Bw25CanonicalJsonScript.sha256(candidate)
	var role := String(_bw25y_cell.get("role", ""))
	var expected_yaw_gain := float(_bw25y_cell.get("yaw_error_stride_gain_per_rad", NAN))
	var candidate_yaw_exact := true
	if role == "candidate":
		candidate_yaw_exact = (
			is_equal_approx(
				float(candidate.get("cross_track_proportional_factor", NAN)),
				1.0,
			)
			and is_equal_approx(
				float(candidate.get("cross_track_velocity_factor", NAN)),
				1.0,
			)
			and is_equal_approx(
				float(candidate.get("yaw_error_stride_gain_per_rad", NAN)),
				expected_yaw_gain,
			)
		)
	else:
		candidate_yaw_exact = (
			String(candidate.get("controller_gain_cell", "")) == "BW25Y-A"
			and is_equal_approx(expected_yaw_gain, 1.3)
		)
	return (
		(
			String(declarations.get("schema_version", ""))
			== "sporespore_balanced_wave_bw25y_yaw_development_candidates_v1"
		)
		and (declarations.get("candidate_order", []) as Array) == BW25Y_CANDIDATE_IDS
		and _raw_sha256(BW25Y_CANDIDATES_PATH) == "sha256:" + BW25Y_CANDIDATES_RAW_SHA256
		and String(candidate.get("candidate_id", "")) == _candidate_id()
		and String(candidate.get("controller_policy_id", "")) == _controller_policy_id()
		and String(candidate.get("runtime_profile_sha256", "")) == _controller_policy_digest()
		and String(candidate.get("stability_policy_id", "")) == BW25Y_STABILITY_POLICY_ID
		and String(candidate.get("authority_scope", "")) == "post_settle_full"
		and candidate_yaw_exact
		and is_equal_approx(
			float(candidate.get("global_requested_correction_scale", NAN)),
			_candidate_global_scale(),
		)
		and int(candidate.get("morphology_condition_count", -1)) == 0
		and int(candidate.get("material_condition_count", -1)) == 0
		and int(candidate.get("seed_condition_count", -1)) == 0
		and int(candidate.get("failure_identity_condition_count", -1)) == 0
		and int(candidate.get("outcome_condition_count", -1)) == 0
		and (candidate.get("branch_surfaces", []) as Array).is_empty()
		and not bool(candidate.get("physical_acceptance_authority", true))
		and digest == _candidate_composition_digest()
		and (
			(
				String(
					(
						(declarations.get("candidate_composition_digests", {}) as Dictionary)
						. get(
							_candidate_id(),
							"",
						)
					)
				)
				== digest
			)
			if String(_bw25y_cell.get("role", "")) == "candidate"
			else (
				String(declarations.get("policy_relative_control_composition_digest", "")) == digest
			)
		)
		and String(_bw25y_cell.get("runtime_profile_sha256", "")) == _controller_policy_digest()
		and String(_bw25y_cell.get("candidate_composition_digest", "")) == digest
		and String(preregistration.get("campaign_id", "")) == BW25Y_CAMPAIGN_ID
	)


func _validate_contract(
	preregistration: Dictionary,
	selected_policy: Dictionary,
) -> bool:
	if preregistration.is_empty() or selected_policy.is_empty():
		return false
	var study: Dictionary = preregistration.get("study_class", {})
	var matrix: Dictionary = preregistration.get("matrix", {})
	var gate: Dictionary = preregistration.get("gate_contract", {})
	var receipt_contract: Dictionary = preregistration.get("receipt_schema_contract", {})
	var claims: Dictionary = preregistration.get("claims_before_and_after_development", {})
	var provenance: Dictionary = preregistration.get("successor_provenance", {})
	var bindings: Dictionary = provenance.get("source_bindings", {})
	var bw22l: Dictionary = bindings.get("bw22l_closure", {})
	var bw24p: Dictionary = bindings.get("bw24p_profile_closure", {})
	var cells: Array = matrix.get("ordered_cells", [])
	var ids: Array = []
	for cell_value in cells:
		ids.append(String((cell_value as Dictionary).get("cell_id", "")))
	return (
		String(preregistration.get("schema_version", "")) == BW25Y_SCHEMA
		and String(preregistration.get("status", "")) == BW25Y_STATUS
		and String(preregistration.get("campaign_id", "")) == BW25Y_CAMPAIGN_ID
		and String(preregistration.get("gate_id", "")) == BW25Y_GATE_ID
		and (
			String(preregistration.get("implementation_parent_commit", ""))
			== "970fcc1a8de69ac833633c68a4696d71e17741dc"
		)
		and (
			String(study.get("classification", ""))
			== "paired_outcome_unexposed_finite_controller_development_screen"
		)
		and bool(study.get("development_screen", false))
		and bool(study.get("finite_decision", false))
		and not bool(study.get("population_inference", true))
		and not bool(study.get("superiority_study", true))
		and not bool(study.get("noninferiority_or_equivalence_study", true))
		and int(study.get("expected_world_count", -1)) == 28
		and cells.size() == 28
		and ids == _expected_cell_ids()
		and int(matrix.get("candidate_world_count", -1)) == 24
		and int(matrix.get("control_world_count", -1)) == 3
		and int(matrix.get("safety_world_count", -1)) == 1
		and not bool(gate.get("walking_success_required_for_every_candidate_cell", true))
		and bool(gate.get("development_result_may_validly_select_none", false))
		and bool(gate.get("outcome_based_early_stop_forbidden", false))
		and bool(gate.get("selective_cell_rerun_forbidden", false))
		and int(receipt_contract.get("decision_walking_key_count", -1)) == 4
		and bool(
			receipt_contract.get(
				"negative_walking_outcome_must_pass_execution_integrity_while_remaining_a_physical_failure",
				false,
			)
		)
		and _all_claims_false(claims)
		and String(bw22l.get("raw_sha256", "")) == BW25Y_BW22L_CLOSURE_RAW_SHA256
		and String(bw24p.get("raw_sha256", "")) == BW25Y_BW24P_PROFILE_CLOSURE_RAW_SHA256
		and String(provenance.get("bw22l_disposition", ""))
		== "closed_invalid_final_receipt_composition_mismatch"
		and not bool(provenance.get("bw22l_was_a_controller_comparison_result", true))
		and not bool(provenance.get("bw23y_selected", true))
		and bool(provenance.get("fresh_material_values", false))
		and bool(provenance.get("fresh_unopened_locomotion_seeds", false))
		and _file_hash_exact(
			"res://sdk/balanced_wave_bw22l_lateral_development_closure.json",
			BW25Y_BW22L_CLOSURE_RAW_SHA256,
		)
		and _file_hash_exact(
			"res://sdk/balanced_wave_bw24p_material_profile_publication_closure.json",
			BW25Y_BW24P_PROFILE_CLOSURE_RAW_SHA256,
		)
		and _validate_controller_policy_contract(preregistration, selected_policy)
	)


func _preflight_selected_policy_full_authority_start(
	prepared: Dictionary,
	initial_perturbation: Dictionary,
) -> Dictionary:
	var root_child_count_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var requested_phase_offset_ticks := int(initial_perturbation["gait_phase_offset_ticks"])
	var execution_mode_plan := (
		WaveGaitScript
		. compile_sdk_execution_mode_plan(
			true,
			true,
			"post_settle_full",
			BW25Y_STABILITY_POLICY_ID,
			requested_phase_offset_ticks,
		)
	)
	if not bool(execution_mode_plan.get("ok", false)):
		return execution_mode_plan
	var adapter: RefCounted = AdapterScript.new()
	var start: Dictionary = (
		adapter
		. start(
			(prepared["authority_options"] as Dictionary)["descriptor"],
			execution_mode_plan.get("zero_base_initial_gait_steps", {}) as Dictionary,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			float(initial_perturbation["fixture_yaw_rad"]),
			120,
			SOLVER_POLICY_OPTIONS,
			SDK_COMPARISON_TOLERANCE,
			"clocked",
			true,
			requested_phase_offset_ticks,
			360,
			"post_settle_full",
			BW25Y_STABILITY_POLICY_ID,
			prepared["material_profile"],
			_controller_policy_id(),
			_candidate_global_scale(),
		)
	)
	var boundary: Dictionary = {}
	if bool(start.get("ok", false)):
		boundary = adapter.preflight_perfect_declared_policy_runtime_boundary()
	var manifest: Dictionary = start.get("adapter_manifest", {})
	var stability: Dictionary = manifest.get("stability_v3", {})
	var contribution: Dictionary = stability.get("contribution_shadow", {})
	var influence: Dictionary = boundary.get("portable_stability_influence_receipt", {})
	var controller_profile: Dictionary = manifest.get("controller_profile", {})
	var exact := (
		not _bw25y_cell.is_empty()
		and bool(start.get("ok", false))
		and String(start.get("controller_policy_id", "")) == _controller_policy_id()
		and String(start.get("controller_profile_sha256", "")) == _controller_policy_digest()
		and is_equal_approx(
			float(controller_profile.get("yaw_error_stride_gain_per_rad", NAN)),
			float(_bw25y_cell.get("yaw_error_stride_gain_per_rad", NAN)),
		)
		and String(start.get("authority_scope", "")) == "post_settle_full"
		and String(start.get("stability_policy_id", "")) == BW25Y_STABILITY_POLICY_ID
		and String(manifest.get("execution_mode", "")) == BW25Y_EXECUTION_MODE
		and String(manifest.get("stability_influence_scale_authority", "")) == "portable_core_v3"
		and _near_scale(
			float(manifest.get("stability_influence_global_scale", NAN)),
			_candidate_global_scale(),
		)
		and (
			String(contribution.get("influence_operation", ""))
			== "bound_stability_influence_v3_json"
		)
		and bool(boundary.get("ok", false))
		and bool(boundary.get("portable_stability_influence_required", false))
		and bool(boundary.get("portable_stability_influence_passed", false))
		and (
			String(influence.get("stability_influence_operation", ""))
			== "bound_stability_influence_v3_json"
		)
		and _near_scale(
			float(influence.get("global_requested_correction_scale", NAN)),
			_candidate_global_scale(),
		)
		and int(start.get("world_build_count", -1)) == 0
		and int(boundary.get("actual_world_build_count", -1)) == 0
		and root.get_child_count() == root_child_count_before
		and Engine.physics_ticks_per_second == physics_hz_before
		and not bool(start.get("physical_acceptance_authority", true))
	)
	return {
		"schema_version": "sporespore_bw25y_candidate_adapter_start_preflight_v1",
		"ok": exact,
		"failure_code": "" if exact else "BW25Y_CANDIDATE_ADAPTER_START_INVALID",
		"candidate_id": _candidate_id(),
		"candidate_composition_digest": _candidate_composition_digest(),
		"controller_policy_id": String(start.get("controller_policy_id", "")),
		"controller_runtime_profile_sha256": String(
			start.get("controller_profile_sha256", "")
		),
		"yaw_error_stride_gain_per_rad": float(
			controller_profile.get("yaw_error_stride_gain_per_rad", NAN)
		),
		"authority_scope": String(start.get("authority_scope", "")),
		"actuation_authority": bool(start.get("actuation_authority", false)),
		"stability_policy_id": String(start.get("stability_policy_id", "")),
		"global_requested_correction_scale": _candidate_global_scale(),
		"adapter_capability_sha256": String(start.get("adapter_capability_sha256", "")),
		"requested_phase_offset_ticks": requested_phase_offset_ticks,
		"sdk_execution_mode_plan": execution_mode_plan.duplicate(true),
		"sdk_execution_mode_plan_passed": bool(execution_mode_plan.get("ok", false)),
		"declared_policy_runtime_boundary_preflight": boundary.duplicate(true),
		"declared_policy_runtime_boundary_preflight_passed": bool(boundary.get("ok", false)),
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count() - root_child_count_before,
		"physics_state_modified": Engine.physics_ticks_per_second != physics_hz_before,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _bw25y_physical_cell_receipt(cell: Dictionary, summary: Dictionary) -> Dictionary:
	var inherited_receipt := _bw20f_physical_cell_receipt(cell, summary)
	var receipt := (
		Bw25PolicyRelativeIntegrityScript
		. bind_physical_receipt(
			inherited_receipt,
			summary,
			_policy_relative_expected_integrity(cell),
		)
	)
	var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var start_result: Dictionary = summary.get("sdk_authority_start_result", {})
	var adapter_manifest: Dictionary = start_result.get("adapter_manifest", {})
	var controller_profile: Dictionary = adapter_manifest.get("controller_profile", {})
	var minimum_cross_track := float(sdk_summary.get("minimum_cross_track_error_m", NAN))
	var maximum_cross_track := float(sdk_summary.get("maximum_cross_track_error_m", NAN))
	var maximum_absolute_cross_track := maxf(
		absf(minimum_cross_track),
		absf(maximum_cross_track),
	)
	var initial_perturbation: Dictionary = (
		(summary.get("initial_perturbation", {}) as Dictionary).duplicate(true)
	)
	var residual_application_observed := (
		int(receipt.get("sdk_effective_application_count", 0)) > 0
		or float(receipt.get("maximum_absolute_applied_velocity_rad_s", 0.0)) > 0.0
	)
	var base_controller_application_observed := (
		int(receipt.get("sdk_native_motor_write_count", 0)) > 0
	)
	receipt["schema_version"] = BW25Y_RAW_CELL_SCHEMA
	receipt["campaign_id"] = BW25Y_CAMPAIGN_ID
	receipt["gate_id"] = BW25Y_GATE_ID
	receipt["controller_runtime_profile_sha256"] = String(
		sdk_summary.get("controller_profile_sha256", "")
	)
	receipt["proportional_factor"] = 1.0
	receipt["velocity_factor"] = 1.0
	receipt["yaw_error_stride_gain_per_rad"] = float(
		controller_profile.get("yaw_error_stride_gain_per_rad", NAN)
	)
	receipt["policy_branch_surface_count"] = 0
	receipt["material_condition_count"] = 0
	receipt["seed_condition_count"] = 0
	receipt["failure_identity_condition_count"] = 0
	receipt["outcome_condition_count"] = 0
	receipt["residual_application_expected"] = String(cell["role"]) == "candidate"
	receipt["residual_application_observed"] = residual_application_observed
	receipt["base_controller_application_observed"] = base_controller_application_observed
	receipt["broad_base_controller_physical_influence_observed"] = bool(
		receipt.get("physical_influence", false)
	)
	receipt["final_task_frame_lateral_displacement_m"] = float(
		summary.get("final_task_frame_lateral_displacement_m", NAN)
	)
	receipt["minimum_cross_track_error_m"] = minimum_cross_track
	receipt["maximum_cross_track_error_m"] = maximum_cross_track
	receipt["maximum_absolute_cross_track_error_m"] = maximum_absolute_cross_track
	receipt["cumulative_absolute_cross_track_error_m_s"] = float(
		sdk_summary.get("cumulative_absolute_cross_track_error_m_s", NAN)
	)
	receipt["steering_feedback_update_count"] = int(
		sdk_summary.get("steering_feedback_update_count", -1)
	)
	receipt["steering_filter_application_count"] = int(
		sdk_summary.get("steering_filter_application_count", -1)
	)
	receipt["steering_saturation_count"] = int(sdk_summary.get("steering_saturation_count", -1))
	receipt["steering_slew_limited_count"] = int(sdk_summary.get("steering_slew_limited_count", -1))
	receipt["maximum_absolute_requested_steering_fraction"] = float(
		sdk_summary.get("maximum_absolute_requested_steering_fraction", NAN)
	)
	receipt["maximum_absolute_filtered_steering_fraction"] = float(
		sdk_summary.get("maximum_absolute_filtered_steering_fraction", NAN)
	)
	receipt["maximum_absolute_steering_delta_per_step"] = float(
		sdk_summary.get("maximum_absolute_steering_delta_per_step", NAN)
	)
	receipt["initial_perturbation"] = initial_perturbation
	receipt["initial_perturbation_sha256"] = Bw25CanonicalJsonScript.sha256(initial_perturbation)
	receipt.erase("failed_production_walking_gate_count")
	receipt["development_only"] = true
	receipt["walking_claim_authorized"] = false
	receipt["material_acceptance_claim_authorized"] = false
	receipt["physical_acceptance_authority"] = false
	return receipt


func _policy_relative_expected_integrity(cell: Dictionary) -> Dictionary:
	return {
		"controller_policy_id": String(cell["controller_policy_id"]),
		"stability_policy_id": BW25Y_STABILITY_POLICY_ID,
		"authority_scope": "post_settle_full",
		"execution_mode": BW25Y_EXECUTION_MODE,
		"actuator_count": EXPECTED_ACTUATOR_COUNT_BW17P,
		"world_build_count": 1,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 7,
		"body_count": 9,
		"limb_count": 4,
	}


func _bw25y_zero_safety_receipt(cell: Dictionary, summary: Dictionary) -> Dictionary:
	var receipt := _zero_safety_receipt(cell, summary)
	receipt["schema_version"] = BW25Y_RAW_CELL_SCHEMA
	receipt["campaign_id"] = BW25Y_CAMPAIGN_ID
	receipt["gate_id"] = BW25Y_GATE_ID
	receipt["residual_application_expected"] = false
	receipt["residual_application_observed"] = false
	receipt["base_controller_application_observed"] = false
	receipt["broad_base_controller_physical_influence_observed"] = false
	receipt["development_only"] = true
	receipt["physical_acceptance_authority"] = false
	return receipt


func _role_gate_passed(receipt: Dictionary) -> bool:
	var role := String(receipt.get("role", ""))
	if role == "candidate":
		return (
			bool(receipt.get("common_execution_integrity", false))
			and bool(receipt.get("mechanism_gate_passed", false))
			and bool(receipt.get("combined_application_gate_passed", false))
			and bool(receipt.get("residual_application_expected", false))
			and bool(receipt.get("residual_application_observed", false))
			and int(receipt.get("sdk_effective_application_count", 0)) > 0
			and bool(receipt.get("base_controller_application_observed", false))
			and bool(receipt.get("broad_base_controller_physical_influence_observed", false))
			and _candidate_diagnostics_finite(receipt)
			and bool(receipt.get("outcome_complete", false))
		)
	if role == "control":
		return (
			bool(receipt.get("common_execution_integrity", false))
			and bool(receipt.get("mechanism_gate_passed", false))
			and not bool(receipt.get("combined_application_gate_passed", true))
			and not bool(receipt.get("residual_application_expected", true))
			and not bool(receipt.get("residual_application_observed", true))
			and int(receipt.get("sdk_effective_application_count", -1)) == 0
			and is_zero_approx(float(receipt.get("maximum_absolute_applied_velocity_rad_s", NAN)))
			and bool(receipt.get("base_controller_application_observed", false))
			and bool(receipt.get("broad_base_controller_physical_influence_observed", false))
			and _candidate_diagnostics_finite(receipt)
			and bool(receipt.get("outcome_complete", false))
		)
	return (
		role == "safety"
		and bool(receipt.get("common_execution_integrity", false))
		and int(receipt.get("sdk_native_motor_write_count", -1)) == 0
		and int(receipt.get("sdk_effective_application_count", -1)) == 0
		and not bool(receipt.get("physical_influence", true))
		and not bool(receipt.get("walking_claim_authorized", true))
	)


func _candidate_diagnostics_finite(receipt: Dictionary) -> bool:
	for field in [
		"final_task_frame_lateral_displacement_m",
		"minimum_cross_track_error_m",
		"maximum_cross_track_error_m",
		"maximum_absolute_cross_track_error_m",
		"cumulative_absolute_cross_track_error_m_s",
		"maximum_absolute_requested_steering_fraction",
		"maximum_absolute_filtered_steering_fraction",
		"maximum_absolute_steering_delta_per_step",
	]:
		if not is_finite(float(receipt.get(field, NAN))):
			return false
	return (
		int(receipt.get("steering_feedback_update_count", -1)) > 0
		and int(receipt.get("steering_filter_application_count", -1)) > 0
		and int(receipt.get("steering_saturation_count", -1)) >= 0
		and int(receipt.get("steering_slew_limited_count", -1)) >= 0
		and float(receipt.get("maximum_absolute_requested_steering_fraction", INF)) <= 0.4 + 1.0e-12
		and float(receipt.get("maximum_absolute_filtered_steering_fraction", INF)) <= 0.4 + 1.0e-12
	)


func _validate_bw25y_manifest(manifest: Dictionary) -> bool:
	if manifest.is_empty():
		return false
	var matrix: Dictionary = manifest.get("matrix", {})
	var cells: Array = matrix.get("ordered_cells", [])
	var ids: Array = []
	for cell_value in cells:
		ids.append(String((cell_value as Dictionary).get("cell_id", "")))
	return (
		String(manifest.get("schema_version", "")) == BW25Y_SCHEMA
		and String(manifest.get("status", "")) == BW25Y_STATUS
		and String(manifest.get("campaign_id", "")) == BW25Y_CAMPAIGN_ID
		and String(manifest.get("gate_id", "")) == BW25Y_GATE_ID
		and cells.size() == 28
		and ids == _expected_cell_ids()
		and int(matrix.get("candidate_world_count", -1)) == 24
		and int(matrix.get("control_world_count", -1)) == 3
		and int(matrix.get("safety_world_count", -1)) == 1
		and _raw_sha256(BW25Y_CANDIDATES_PATH) == "sha256:" + BW25Y_CANDIDATES_RAW_SHA256
		and _file_hash_exact(
			"res://sdk/balanced_wave_bw22l_lateral_development_closure.json",
			BW25Y_BW22L_CLOSURE_RAW_SHA256,
		)
		and _file_hash_exact(
			"res://sdk/balanced_wave_bw24p_material_profile_publication_closure.json",
			BW25Y_BW24P_PROFILE_CLOSURE_RAW_SHA256,
		)
		and _validate_matrix_cells(cells)
		and _validate_stage_one_freeze()
	)


func _validate_matrix_cells(cells: Array) -> bool:
	if cells.size() != 28:
		return false
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var role := String(cell.get("role", ""))
		if role == "safety":
			if not (
				String(cell.get("cell_id", "")) == "negative_mu000_s26011_safety"
				and int(cell.get("campaign_seed", -1)) == 26011
				and is_zero_approx(float(cell.get("authored_friction", NAN)))
				and is_zero_approx(float(cell.get("controller_coefficient", NAN)))
				and String(cell.get("profile_id", "")) == "godot_jolt_p5m1r1_mu000_v1"
				and String(cell.get("candidate_id", "")) == "BW25Y-SAFETY"
				and String(cell.get("controller_policy_id", "")) == "NONE"
				and is_zero_approx(float(cell.get("global_requested_correction_scale", NAN)))
			):
				return false
			continue
		var profile_index := BW25Y_PROFILE_IDS.find(String(cell.get("profile_id", "")))
		if profile_index < 0:
			return false
		if not (
			is_equal_approx(
				float(cell.get("authored_friction", NAN)),
				float(BW25Y_AUTHORED_FRICTIONS[profile_index]),
			)
			and is_equal_approx(
				float(cell.get("controller_coefficient", NAN)),
				float(BW25Y_CONTROLLER_COEFFICIENTS[profile_index]),
			)
			and String(cell.get("profile_digest", ""))
			== String(BW25Y_PROFILE_DIGESTS[profile_index])
			and BW25Y_SEEDS.has(int(cell.get("campaign_seed", -1)))
		):
			return false
		if role == "control":
			if not (
				int(cell.get("campaign_seed", -1)) == 26011
				and String(cell.get("candidate_id", "")) == BW25Y_CONTROL_ID
				and String(cell.get("candidate_composition_digest", ""))
				== BW25Y_CONTROL_DIGEST
				and String(cell.get("controller_policy_id", "")) == BW25Y_POLICY_IDS[0]
				and String(cell.get("runtime_profile_sha256", ""))
				== BW25Y_RUNTIME_PROFILE_SHA256[0]
				and is_equal_approx(
					float(cell.get("yaw_error_stride_gain_per_rad", NAN)),
					1.3,
				)
				and is_zero_approx(float(cell.get("global_requested_correction_scale", NAN)))
			):
				return false
			continue
		if role != "candidate":
			return false
		var candidate_index := BW25Y_CANDIDATE_IDS.find(String(cell.get("candidate_id", "")))
		if candidate_index < 0:
			return false
		var expected_yaw_gain := 1.3 if candidate_index == 0 else 1.0
		if not (
			String(cell.get("candidate_composition_digest", ""))
			== String(BW25Y_COMPOSITION_DIGESTS[candidate_index])
			and String(cell.get("controller_policy_id", ""))
			== String(BW25Y_POLICY_IDS[candidate_index])
			and String(cell.get("runtime_profile_sha256", ""))
			== String(BW25Y_RUNTIME_PROFILE_SHA256[candidate_index])
			and is_equal_approx(
				float(cell.get("yaw_error_stride_gain_per_rad", NAN)),
				expected_yaw_gain,
			)
			and is_equal_approx(
				float(cell.get("global_requested_correction_scale", NAN)),
				0.5,
			)
		):
			return false
	return true


func _validate_stage_one_freeze() -> bool:
	var freeze := _read_json(BW25Y_FREEZE_PATH)
	if freeze.is_empty():
		return false
	var study: Dictionary = freeze.get("study_class", {})
	var matrix: Dictionary = freeze.get("physical_matrix", {})
	var gate: Dictionary = freeze.get("gate_contract", {})
	var preflight: Dictionary = freeze.get("zero_world_authorization_preflight", {})
	var execution: Dictionary = freeze.get("one_shot_execution_contract", {})
	var bindings: Dictionary = freeze.get("source_bindings", {})
	var harness_binding: Dictionary = bindings.get("physical_harness", {})
	var supervisor_binding: Dictionary = bindings.get("supervisor", {})
	var evaluator_binding: Dictionary = bindings.get("production_gate", {})
	var preregistration_binding: Dictionary = bindings.get("preregistration", {})
	var candidates_binding: Dictionary = bindings.get("candidate_declaration", {})
	return (
		String(freeze.get("schema_version", "")) == BW25Y_FREEZE_SCHEMA
		and String(freeze.get("status", "")) == BW25Y_FREEZE_STATUS
		and String(freeze.get("campaign_id", "")) == BW25Y_CAMPAIGN_ID
		and String(freeze.get("gate_id", "")) == BW25Y_GATE_ID
		and String(freeze.get("freeze_parent_commit", ""))
		== "589b13258064e0d2d0b093495948f01822b4ff45"
		and String(study.get("classification", ""))
		== "paired_outcome_unexposed_finite_controller_development_screen"
		and int(matrix.get("expected_world_count", -1)) == 28
		and int(matrix.get("candidate_world_count", -1)) == 24
		and int(matrix.get("control_world_count", -1)) == 3
		and int(matrix.get("safety_world_count", -1)) == 1
		and int(gate.get("expected_gate_count", -1)) == 50
		and bool(gate.get("valid_negative_walking_cell_remains_a_complete_scientific_result", false))
		and bool(gate.get("one_replacement_for_absent_complete_receipt_only", false))
		and int(preflight.get("worker_entrypoint_count", -1)) == 28
		and int(preflight.get("adapter_start_count", -1)) == 27
		and int(preflight.get("world_build_count", -1)) == 0
		and int(preflight.get("scene_tree_insertion_count", -1)) == 0
		and int(preflight.get("physics_state_mutation_count", -1)) == 0
		and not bool(preflight.get("locomotion_outcome_exposed", true))
		and not bool(preflight.get("physical_acceptance_authority", true))
		and bool(execution.get("attempt_receipt_written_and_identity_consumed_before_first_world", false))
		and bool(execution.get("attempt_receipt_remains_immutable_after_first_world", false))
		and bool(execution.get("valid_negative_cell_is_final_and_does_not_fail_process", false))
		and bool(execution.get("one_automatic_replacement_only_for_incomplete_receipt", false))
		and bool(execution.get("replacement_never_depends_on_locomotion_outcome", false))
		and not bool(execution.get("same_identity_rerun_allowed", true))
		and (
			String(harness_binding.get("path", ""))
			== "tests/test_sdk_balanced_wave_bw25y_yaw_development.gd"
		)
		and (
			_raw_sha256("res://tests/test_sdk_balanced_wave_bw25y_yaw_development.gd")
			== "sha256:" + String(harness_binding.get("raw_sha256", ""))
		)
		and String(supervisor_binding.get("path", ""))
		== "sdk/run_balanced_wave_bw25y_yaw_development.ps1"
		and _raw_sha256(BW25Y_SUPERVISOR_PATH)
		== "sha256:" + String(supervisor_binding.get("raw_sha256", ""))
		and String(evaluator_binding.get("path", ""))
		== "sdk/balanced_wave_bw25y_yaw_development_gate.ps1"
		and _raw_sha256(BW25Y_EVALUATOR_PATH)
		== "sha256:" + String(evaluator_binding.get("raw_sha256", ""))
		and _raw_sha256(BW25Y_PREREGISTRATION_PATH)
		== "sha256:" + String(preregistration_binding.get("raw_sha256", ""))
		and _raw_sha256(BW25Y_CANDIDATES_PATH)
		== "sha256:" + String(candidates_binding.get("raw_sha256", ""))
	)


func _bw25y_physical_authorization_exact(cell_id: String, allow_synthetic: bool) -> bool:
	var attempt_path := OS.get_environment(BW25Y_AUTHORIZATION_PATH_ENV)
	var authorization_token := OS.get_environment(BW25Y_AUTHORIZATION_TOKEN_ENV)
	var authorized_cell := OS.get_environment(BW25Y_AUTHORIZED_CELL_ENV)
	var world_attempt_id := OS.get_environment(BW25Y_WORLD_ATTEMPT_ID_ENV)
	var campaign_attempt_id := OS.get_environment(BW25Y_CAMPAIGN_ATTEMPT_ID_ENV)
	if (
		attempt_path.is_empty()
		or authorization_token.is_empty()
		or authorized_cell != cell_id
		or world_attempt_id.is_empty()
		or campaign_attempt_id.is_empty()
		or not FileAccess.file_exists(attempt_path)
		or attempt_path.replace("/", "\\").begins_with("C:\\tmp\\")
	):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(attempt_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var attempt: Dictionary = parsed
	var synthetic := bool(attempt.get("synthetic_contract_preflight", false))
	var source_exact := (
		(
			String(attempt.get("source_commit", ""))
			== "synthetic_preflight_no_source_identity"
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
	var expected_primary_ids := _expected_primary_world_attempt_ids()
	var expected_replacement_ids := _expected_replacement_world_attempt_ids()
	var declared_world_attempt := (
		world_attempt_id in expected_primary_ids or world_attempt_id in expected_replacement_ids
	)
	var expected_suffix := "::" + cell_id
	return (
		_dictionary_keys_exact(attempt, BW25Y_ATTEMPT_KEYS)
		and String(attempt.get("schema_version", "")) == BW25Y_ATTEMPT_SCHEMA
		and String(attempt.get("campaign_id", "")) == BW25Y_CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == BW25Y_GATE_ID
		and synthetic == allow_synthetic
		and source_exact
		and String(attempt.get("attempt_id", "")) == campaign_attempt_id
		and campaign_attempt_id.length() == 32
		and campaign_attempt_id.is_valid_hex_number()
		and not String(attempt.get("launched_at_utc", "")).is_empty()
		and String(attempt.get("authorization_token", "")) == authorization_token
		and authorization_token.length() == 32
		and authorization_token.is_valid_hex_number()
		and declared_world_attempt
		and world_attempt_id.ends_with(expected_suffix)
		and String(attempt.get("godot_version", "")) == BW25Y_GODOT_VERSION
		and String(attempt.get("godot_executable_sha256", ""))
		== BW25Y_GODOT_EXECUTABLE_SHA256
		and String(attempt.get("godot_runtime_executable_sha256", ""))
		== BW25Y_GODOT_RUNTIME_SHA256
		and String(attempt.get("godot_adapter_artifact_sha256", ""))
		== _raw_sha256(BW25Y_ADAPTER_ARTIFACT_PATH).trim_prefix("sha256:")
		and String(attempt.get("preregistration_raw_sha256", ""))
		== _raw_sha256(BW25Y_PREREGISTRATION_PATH).trim_prefix("sha256:")
		and String(attempt.get("candidates_raw_sha256", ""))
		== _raw_sha256(BW25Y_CANDIDATES_PATH).trim_prefix("sha256:")
		and String(attempt.get("evaluator_raw_sha256", ""))
		== _raw_sha256(BW25Y_EVALUATOR_PATH).trim_prefix("sha256:")
		and String(attempt.get("physical_worker_raw_sha256", ""))
		== _raw_sha256(BW25Y_WORKER_PATH).trim_prefix("sha256:")
		and String(attempt.get("physical_supervisor_raw_sha256", ""))
		== _raw_sha256(BW25Y_SUPERVISOR_PATH).trim_prefix("sha256:")
		and bool(attempt.get("complete_zero_world_gate_passed", false))
		and bool(attempt.get("authority_contract_passed", false))
		and bool(attempt.get("receipt_parity_passed", false))
		and bool(attempt.get("worker_entrypoint_preflight_passed", false))
		and bool(attempt.get("attempt_contract_preflight_passed", false))
		and bool(attempt.get("stage_one_freeze_verified", false))
		and (
			_raw_sha256(BW25Y_FREEZE_PATH)
			== "sha256:" + String(attempt.get("stage_one_freeze_raw_sha256", ""))
		)
		and bool(attempt.get("physical_identity_consumed", false)) == (not synthetic)
		and not bool(attempt.get("same_identity_rerun_allowed", true))
		and not bool(attempt.get("locomotion_outcome_exposed_at_attempt", true))
		and not bool(attempt.get("physical_acceptance_authority", true))
		and bool(attempt.get("retained_physical_execution_serialized", false))
		and int(attempt.get("expected_gate_count", -1)) == 50
		and int(attempt.get("expected_world_count", -1)) == 28
		and int(attempt.get("expected_adapter_start_count", -1)) == 27
		and int(attempt.get("replacement_budget_per_incomplete_cell", -1)) == 1
		and (attempt.get("ordered_cell_ids", []) as Array) == _expected_cell_ids()
		and (attempt.get("primary_world_attempt_ids", []) as Array) == expected_primary_ids
		and (attempt.get("replacement_world_attempt_ids", []) as Array)
		== expected_replacement_ids
	)


static func _dictionary_keys_exact(value: Dictionary, expected: Array) -> bool:
	var actual_keys: Array = []
	for key in value.keys():
		actual_keys.append(String(key))
	actual_keys.sort()
	var expected_keys := expected.duplicate()
	expected_keys.sort()
	return actual_keys == expected_keys


static func _expected_cell_ids() -> Array:
	var ids: Array = []
	for profile_token in BW25Y_PROFILE_TOKENS:
		for seed in BW25Y_SEEDS:
			for candidate_id in BW25Y_CANDIDATE_IDS:
				(
					ids
					. append(
						(
							"development_mu%s_s%d_%s"
							% [
								String(profile_token),
								int(seed),
								String(candidate_id).to_lower().replace("-", "_"),
							]
						)
					)
				)
			if int(seed) == 26011:
				ids.append("development_mu%s_s26011_control" % String(profile_token))
	ids.append("negative_mu000_s26011_safety")
	return ids


static func _expected_primary_world_attempt_ids() -> Array:
	var ids: Array = []
	for cell_id in _expected_cell_ids():
		ids.append("BW25Y-P1::" + String(cell_id))
	return ids


static func _expected_replacement_world_attempt_ids() -> Array:
	var ids: Array = []
	for cell_id in _expected_cell_ids():
		ids.append("BW25Y-R1::" + String(cell_id))
	return ids


static func _false_boolean_count(values: Dictionary) -> int:
	var count := 0
	for value in values.values():
		if typeof(value) == TYPE_BOOL and not bool(value):
			count += 1
	return count
