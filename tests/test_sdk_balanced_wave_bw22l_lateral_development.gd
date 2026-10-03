extends "res://tests/test_sdk_balanced_wave_bw20f_material_locomotion.gd"
# gdlint: disable=max-line-length
# gdlint: disable=max-returns
# gdlint: disable=max-file-lines

## BW22L outcome-exposed finite lateral-gain development worker.
##
## This is a distinct successor to the immutable infrastructure-invalid BW21L
## result. Its preflight traverses all 28 declared entrypoints without building a world.
## Physical mode opens exactly one supervisor-authorized cell and retains the
## steering/cross-track evidence that BW20F's wrapper omitted.

const Bw22CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const Bw22PolicyRelativeIntegrityScript := preload(
	"res://scripts/lab/gait/sdk_policy_relative_execution_integrity.gd"
)
const BW22L_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw22l_lateral_development_preregistration.json"
const BW22L_CANDIDATES_PATH := "res://sdk/balanced_wave_bw22l_lateral_development_candidates.json"
const BW22L_FREEZE_PATH := "res://sdk/balanced_wave_bw22l_lateral_development_freeze.json"
const BW22L_SCHEMA := "sporespore_balanced_wave_bw22l_lateral_development_preregistration_v1"
const BW22L_STATUS := "prospective_stage_zero_zero_world_only_physical_execution_blocked"
const BW22L_FREEZE_SCHEMA := "sporespore_balanced_wave_bw22l_lateral_development_freeze_v1"
const BW22L_FREEZE_STATUS := "frozen_before_first_bw22l_physical_world"
const BW22L_CAMPAIGN_ID := "BW22L-FRESH-MATERIAL-LATERAL-DEVELOPMENT"
const BW22L_GATE_ID := "BW22L"
const BW22L_CELL_SCHEMA := "sporespore_balanced_wave_bw22l_lateral_development_cell_v1"
const BW22L_PREFLIGHT_SCHEMA := "sporespore_balanced_wave_bw22l_lateral_development_entrypoint_preflight_v1"
const BW22L_CELL_PREFIX := "BW22L_LATERAL_DEVELOPMENT_CELL "
const BW22L_PREFLIGHT_PREFIX := "BW22L_LATERAL_DEVELOPMENT_PREFLIGHT "
const BW22L_AUTHORIZATION_PREFLIGHT_PREFIX := "BW22L_LATERAL_DEVELOPMENT_AUTHORIZATION_PREFLIGHT "
const BW22L_AUTHORIZATION_PATH_ENV := "SPORESPORE_BW22L_ATTEMPT"
const BW22L_AUTHORIZATION_TOKEN_ENV := "SPORESPORE_BW22L_TOKEN"
const BW22L_AUTHORIZED_CELL_ENV := "SPORESPORE_BW22L_CELL"
const BW22L_REFERENCE_MORPHOLOGY_ID := "godot_jolt_stability_physical_influence_reference"
const BW22L_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_a_v3"
const BW22L_EXECUTION_MODE := "native_balanced_wave_base_with_stability_contribution"
const BW22L_CANDIDATE_IDS := ["BW22L-A", "BW22L-B"]
const BW22L_POLICY_IDS := [
	"sporespore_balanced_wave_bw15f_b_v1",
	"sporespore_balanced_wave_bw21l_b_v1",
]
const BW22L_RUNTIME_PROFILE_SHA256 := [
	"sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413",
	"sha256:70b1b0c445bc8b53d94a09f70e18271b9727d9f41b772fa843ae9e59174af6f5",
]
const BW22L_COMPOSITION_DIGESTS := [
	"sha256:c67ad10b9eb0c74eae4a91b7a431c0d0eaae8c28574dcc78d91ab90fdee82aba",
	"sha256:431e8ea82d751f5c3755a21a2e91d096264580caa3b84d2dbaa9fc50062db07e",
]
const BW22L_CONTROL_ID := "BW22L-CONTROL"
const BW22L_CONTROL_DIGEST := "sha256:867ac6c232ae94d27fe2f0789ef4df752cfcbb5881deb609e8c5acedf1bd35ef"
const BW22L_CANDIDATES_RAW_SHA256 := "31b02c3cfd6c15ed054d27082c21d8e2fad7811260bfc952e8455ba72a90a55c"
const BW22L_BW21L_CLOSURE_RAW_SHA256 := "d592e160c1111d05047a545986099ce957226a8d12e81d19013930133b98af4b"
const BW22L_BW21L_REPORT_RAW_SHA256 := "b35b774cf8abdeebe38bccbfd7890fd9151fa280e123b9d30cd2a68e7cebbc53"
const BW22L_BW22M_PROFILE_CLOSURE_RAW_SHA256 := "09a7f017a85f9bfe53c6f707985bd9b87083cee564168bf0311d8b57d8b787e9"
const BW22L_BW22M_PROFILE_REPORT_RAW_SHA256 := "35cfe781bfdd87744b31dee20ce1102f16434d483e14e769d84571969e7010b0"
const BW22L_PROFILE_TOKENS := ["057", "069", "081"]
const BW22L_PROFILE_IDS := [
	"godot_jolt_bw22m_mu057_v1",
	"godot_jolt_bw22m_mu069_v1",
	"godot_jolt_bw22m_mu081_v1",
]
const BW22L_PROFILE_DIGESTS := [
	"sha256:754c2f45b19dea315bd3527db8b8b87041be57cb7e4999412710d82c7c57903f",
	"sha256:a66f00fb0836a0838ab20e3f54c531ee5e9a6ea50180780e81e4f6106aad5ff3",
	"sha256:9446ba227a7a80f7592ffb7e358b8903a4e7afeb7297d5ba94dab87be8e33cbd",
]
const BW22L_AUTHORED_FRICTIONS := [0.57, 0.69, 0.81]
const BW22L_SEEDS := [24011, 24012, 24013, 24014]
const BW22L_REFERENCE_DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": BW22L_REFERENCE_MORPHOLOGY_ID,
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 18.0 / 35.0,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}

var _bw22l_cell: Dictionary = {}
var _bw22l_profile_id := ""


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": BW22L_PREREGISTRATION_PATH,
		"preregistration_schema": BW22L_SCHEMA,
		"preregistration_status": BW22L_STATUS,
		"campaign_id": BW22L_CAMPAIGN_ID,
		"gate_id": BW22L_GATE_ID,
		"campaign_seeds": BW22L_SEEDS.duplicate(),
		"entrypoint_receipt_schema": BW22L_PREFLIGHT_SCHEMA,
		"cell_receipt_schema": BW22L_CELL_SCHEMA,
		"entrypoint_prefix": BW22L_PREFLIGHT_PREFIX,
		"cell_prefix": BW22L_CELL_PREFIX,
		"display_name": "BW22L material lateral-gain development",
	}


func _candidate_index() -> int:
	return 1 if not _bw22l_cell.is_empty() else -1


func _bw19v_candidate_index() -> int:
	if _bw22l_cell.is_empty():
		return -1
	return 0 if String(_bw22l_cell.get("role", "")) == "control" else 1


func _candidate_id() -> String:
	return String(_bw22l_cell.get("candidate_id", ""))


func _candidate_composition_digest() -> String:
	return String(_bw22l_cell.get("candidate_composition_digest", ""))


func _candidate_global_scale() -> float:
	return float(_bw22l_cell.get("global_requested_correction_scale", NAN))


func _candidate_authority_scope() -> String:
	return "post_settle_full" if not _bw22l_cell.is_empty() else ""


func _controller_candidate_id() -> String:
	return _candidate_id()


func _controller_policy_id() -> String:
	return String(_bw22l_cell.get("controller_policy_id", ""))


func _controller_policy_digest() -> String:
	return String(_bw22l_cell.get("runtime_profile_sha256", ""))


func _stability_policy_id() -> String:
	return BW22L_STABILITY_POLICY_ID if not _bw22l_cell.is_empty() else ""


func _expected_full_authority_execution_mode() -> String:
	return BW22L_EXECUTION_MODE if not _bw22l_cell.is_empty() else ""


func _walking_required_for_cell_success() -> bool:
	return false


func _material_profile_id() -> String:
	return _bw22l_profile_id


func _run() -> void:
	print("\n=== BW22L material lateral-gain development ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var manifest := _read_json(BW22L_PREREGISTRATION_PATH)
	if not _validate_bw22l_manifest(manifest):
		push_error("BW22L frozen manifest, candidate, or prerequisite identity changed")
		quit(1)
		return
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() == 1 and String(user_args[0]) == "preflight":
		await _run_bw22l_entrypoint_preflight(manifest)
		return
	if user_args.size() == 2 and String(user_args[0]) == "authorization_preflight":
		_run_bw22l_authorization_preflight(manifest, String(user_args[1]))
		return
	if user_args.size() != 2 or String(user_args[0]) != "physical":
		push_error(
			(
				"BW22L accepts exactly 'preflight', "
				+ "'authorization_preflight <cell_id>', or 'physical <cell_id>'"
			)
		)
		quit(1)
		return
	var cell := _find_manifest_cell(manifest, String(user_args[1]))
	if cell.is_empty():
		push_error("BW22L physical cell is not in the frozen matrix")
		quit(1)
		return
	if not _physical_authorization_exact(String(cell["cell_id"])):
		push_error("BW22L physical entry requires exact retained supervisor authorization")
		quit(1)
		return
	_configure_cell(cell)
	var receipt: Dictionary
	if String(cell["role"]) == "safety":
		var summary := await _run_zero_safety_cell(cell, false)
		receipt = _bw22l_zero_safety_receipt(cell, summary)
	else:
		var summary := await _run_cell(0, int(cell["campaign_seed"]), false)
		receipt = _bw22l_physical_cell_receipt(cell, summary)
	_clear_cell_configuration()
	var role_passed := _role_gate_passed(receipt)
	receipt["role_gate_passed"] = role_passed
	receipt["harness_passed"] = role_passed
	print(BW22L_CELL_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if role_passed else 1)


func _run_bw22l_authorization_preflight(manifest: Dictionary, cell_id: String) -> void:
	var root_children_before := root.get_child_count()
	var cell := _find_manifest_cell(manifest, cell_id)
	var authorization_exact := not cell.is_empty() and _physical_authorization_exact(cell_id)
	var receipt := {
		"schema_version":
		"sporespore_balanced_wave_bw22l_lateral_development_" + "authorization_preflight_v1",
		"campaign_id": BW22L_CAMPAIGN_ID,
		"gate_id": BW22L_GATE_ID,
		"cell_id": cell_id,
		"cell_declared": not cell.is_empty(),
		"authorization_exact": authorization_exact,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count() - root_children_before,
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(BW22L_AUTHORIZATION_PREFLIGHT_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if authorization_exact else 1)


func _run_bw22l_entrypoint_preflight(manifest: Dictionary) -> void:
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
		"schema_version": BW22L_PREFLIGHT_SCHEMA,
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
		"campaign_id": BW22L_CAMPAIGN_ID,
		"gate_id": BW22L_GATE_ID,
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
	print(BW22L_PREFLIGHT_PREFIX, JSON.stringify(aggregate, "", true, true))
	quit(0 if bool(aggregate["ok"]) else 1)


func _configure_cell(cell: Dictionary) -> void:
	_bw22l_cell = cell.duplicate(true)
	_bw22l_profile_id = String(cell.get("profile_id", ""))


func _clear_cell_configuration() -> void:
	_bw22l_cell = {}
	_bw22l_profile_id = ""
	OS.unset_environment(BW19V_CANDIDATE_ENVIRONMENT_VARIABLE)


func _validate_controller_policy_contract(
	preregistration: Dictionary,
	_selected_policy: Dictionary,
) -> bool:
	if _bw22l_cell.is_empty():
		return false
	var declarations := _read_json(BW22L_CANDIDATES_PATH)
	var candidates: Array = declarations.get("candidates", [])
	var candidate: Dictionary = {}
	if String(_bw22l_cell.get("role", "")) == "control":
		candidate = declarations.get("policy_relative_control", {})
	else:
		for candidate_value in candidates:
			var possible: Dictionary = candidate_value
			if String(possible.get("candidate_id", "")) == _candidate_id():
				candidate = possible
				break
	if candidate.is_empty():
		return false
	var digest := Bw22CanonicalJsonScript.sha256(candidate)
	return (
		(
			String(declarations.get("schema_version", ""))
			== "sporespore_balanced_wave_bw22l_lateral_development_candidates_v1"
		)
		and (declarations.get("candidate_order", []) as Array) == BW22L_CANDIDATE_IDS
		and _raw_sha256(BW22L_CANDIDATES_PATH) == "sha256:" + BW22L_CANDIDATES_RAW_SHA256
		and String(candidate.get("candidate_id", "")) == _candidate_id()
		and String(candidate.get("controller_policy_id", "")) == _controller_policy_id()
		and String(candidate.get("runtime_profile_sha256", "")) == _controller_policy_digest()
		and String(candidate.get("stability_policy_id", "")) == BW22L_STABILITY_POLICY_ID
		and String(candidate.get("authority_scope", "")) == "post_settle_full"
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
			if String(_bw22l_cell.get("role", "")) == "candidate"
			else (
				String(declarations.get("policy_relative_control_composition_digest", "")) == digest
			)
		)
		and String(_bw22l_cell.get("runtime_profile_sha256", "")) == _controller_policy_digest()
		and String(_bw22l_cell.get("candidate_composition_digest", "")) == digest
		and (
			String(
				(
					(preregistration.get("prerequisite_evidence", {}) as Dictionary)
					. get("candidate_declaration", {})
					. get("raw_sha256", "")
				)
			)
			== BW22L_CANDIDATES_RAW_SHA256
		)
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
	var claims: Dictionary = preregistration.get("claims_before_and_after_development", {})
	var prerequisite: Dictionary = preregistration.get("prerequisite_evidence", {})
	var bw21l: Dictionary = prerequisite.get("bw21l_invalid_development_closure", {})
	var bw22m: Dictionary = prerequisite.get("bw22m_profile_publication_closure", {})
	var cells: Array = matrix.get("ordered_cells", [])
	var ids: Array = []
	for cell_value in cells:
		ids.append(String((cell_value as Dictionary).get("cell_id", "")))
	return (
		String(preregistration.get("schema_version", "")) == BW22L_SCHEMA
		and String(preregistration.get("status", "")) == BW22L_STATUS
		and String(preregistration.get("campaign_id", "")) == BW22L_CAMPAIGN_ID
		and String(preregistration.get("gate_id", "")) == BW22L_GATE_ID
		and (
			String(preregistration.get("implementation_parent_commit", ""))
			== "dff8dfb647a3b04e78134d2f9e1bccf74c4c8e16"
		)
		and (
			String(study.get("classification", ""))
			== "paired_outcome_exposed_finite_controller_development_screen"
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
		and int(gate.get("expected_gate_count", -1)) == 50
		and int(gate.get("per_world_execution_integrity_gate_count", -1)) == 28
		and int(gate.get("aggregate_gate_count", -1)) == 18
		and not bool(gate.get("walking_success_required_for_every_candidate_cell", true))
		and bool(gate.get("development_result_may_validly_select_none", false))
		and _all_claims_false(claims)
		and String(bw21l.get("raw_sha256", "")) == BW22L_BW21L_CLOSURE_RAW_SHA256
		and String(bw21l.get("retained_report_raw_sha256", "")) == BW22L_BW21L_REPORT_RAW_SHA256
		and not bool(bw21l.get("infrastructure_valid", true))
		and not bool(bw21l.get("controller_comparison_result", true))
		and not bool(bw21l.get("bw21l_b_selected", true))
		and String(bw22m.get("raw_sha256", "")) == BW22L_BW22M_PROFILE_CLOSURE_RAW_SHA256
		and (
			String(bw22m.get("retained_report_raw_sha256", ""))
			== BW22L_BW22M_PROFILE_REPORT_RAW_SHA256
		)
		and bool(bw22m.get("accepted", false))
		and bool(bw22m.get("profile_published", false))
		and _file_hash_exact(
			"res://sdk/balanced_wave_bw21l_lateral_development_closure.json",
			BW22L_BW21L_CLOSURE_RAW_SHA256,
		)
		and _file_hash_exact(
			"res://sdk/balanced_wave_bw22m_material_profile_publication_closure.json",
			BW22L_BW22M_PROFILE_CLOSURE_RAW_SHA256,
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
			BW22L_STABILITY_POLICY_ID,
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
			BW22L_STABILITY_POLICY_ID,
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
	var exact := (
		not _bw22l_cell.is_empty()
		and bool(start.get("ok", false))
		and String(start.get("controller_policy_id", "")) == _controller_policy_id()
		and String(start.get("authority_scope", "")) == "post_settle_full"
		and String(start.get("stability_policy_id", "")) == BW22L_STABILITY_POLICY_ID
		and String(manifest.get("execution_mode", "")) == BW22L_EXECUTION_MODE
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
		"schema_version": "sporespore_bw22l_candidate_adapter_start_preflight_v1",
		"ok": exact,
		"failure_code": "" if exact else "BW22L_CANDIDATE_ADAPTER_START_INVALID",
		"candidate_id": _candidate_id(),
		"candidate_composition_digest": _candidate_composition_digest(),
		"controller_policy_id": String(start.get("controller_policy_id", "")),
		"controller_runtime_profile_sha256": _controller_policy_digest(),
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


func _bw22l_physical_cell_receipt(cell: Dictionary, summary: Dictionary) -> Dictionary:
	var inherited_receipt := _bw20f_physical_cell_receipt(cell, summary)
	var receipt := (
		Bw22PolicyRelativeIntegrityScript
		. bind_physical_receipt(
			inherited_receipt,
			summary,
			_policy_relative_expected_integrity(cell),
		)
	)
	var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var minimum_cross_track := float(sdk_summary.get("minimum_cross_track_error_m", NAN))
	var maximum_cross_track := float(sdk_summary.get("maximum_cross_track_error_m", NAN))
	var maximum_absolute_cross_track := maxf(
		absf(minimum_cross_track),
		absf(maximum_cross_track),
	)
	var initial_perturbation: Dictionary = (
		(summary.get("initial_perturbation", {}) as Dictionary).duplicate(true)
	)
	var walking_receipts: Dictionary = receipt.get("walking_gate_receipts", {})
	var residual_application_observed := (
		int(receipt.get("sdk_effective_application_count", 0)) > 0
		or float(receipt.get("maximum_absolute_applied_velocity_rad_s", 0.0)) > 0.0
	)
	var base_controller_application_observed := (
		int(receipt.get("sdk_native_motor_write_count", 0)) > 0
	)
	receipt["schema_version"] = BW22L_CELL_SCHEMA
	receipt["campaign_id"] = BW22L_CAMPAIGN_ID
	receipt["gate_id"] = BW22L_GATE_ID
	receipt["controller_runtime_profile_sha256"] = String(cell["runtime_profile_sha256"])
	receipt["proportional_factor"] = float(cell["proportional_factor"])
	receipt["velocity_factor"] = float(cell["velocity_factor"])
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
	receipt["initial_perturbation_sha256"] = Bw22CanonicalJsonScript.sha256(initial_perturbation)
	receipt["failed_production_walking_gate_count"] = _false_boolean_count(walking_receipts)
	receipt["development_only"] = true
	receipt["walking_claim_authorized"] = false
	receipt["material_acceptance_claim_authorized"] = false
	receipt["physical_acceptance_authority"] = false
	return receipt


func _policy_relative_expected_integrity(cell: Dictionary) -> Dictionary:
	return {
		"controller_policy_id": String(cell["controller_policy_id"]),
		"stability_policy_id": BW22L_STABILITY_POLICY_ID,
		"authority_scope": "post_settle_full",
		"execution_mode": BW22L_EXECUTION_MODE,
		"actuator_count": EXPECTED_ACTUATOR_COUNT_BW17P,
		"world_build_count": 1,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 7,
		"body_count": 9,
		"limb_count": 4,
	}


func _bw22l_zero_safety_receipt(cell: Dictionary, summary: Dictionary) -> Dictionary:
	var receipt := _zero_safety_receipt(cell, summary)
	receipt["schema_version"] = BW22L_CELL_SCHEMA
	receipt["campaign_id"] = BW22L_CAMPAIGN_ID
	receipt["gate_id"] = BW22L_GATE_ID
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


func _validate_bw22l_manifest(manifest: Dictionary) -> bool:
	if manifest.is_empty():
		return false
	var matrix: Dictionary = manifest.get("matrix", {})
	var cells: Array = matrix.get("ordered_cells", [])
	var ids: Array = []
	for cell_value in cells:
		ids.append(String((cell_value as Dictionary).get("cell_id", "")))
	return (
		String(manifest.get("schema_version", "")) == BW22L_SCHEMA
		and String(manifest.get("status", "")) == BW22L_STATUS
		and String(manifest.get("campaign_id", "")) == BW22L_CAMPAIGN_ID
		and String(manifest.get("gate_id", "")) == BW22L_GATE_ID
		and cells.size() == 28
		and ids == _expected_cell_ids()
		and int(matrix.get("candidate_world_count", -1)) == 24
		and int(matrix.get("control_world_count", -1)) == 3
		and int(matrix.get("safety_world_count", -1)) == 1
		and _raw_sha256(BW22L_CANDIDATES_PATH) == "sha256:" + BW22L_CANDIDATES_RAW_SHA256
		and _file_hash_exact(
			"res://sdk/balanced_wave_bw21l_lateral_development_closure.json",
			BW22L_BW21L_CLOSURE_RAW_SHA256,
		)
		and _file_hash_exact(
			"res://sdk/balanced_wave_bw22m_material_profile_publication_closure.json",
			BW22L_BW22M_PROFILE_CLOSURE_RAW_SHA256,
		)
		and _validate_stage_one_freeze()
	)


func _validate_stage_one_freeze() -> bool:
	var freeze := _read_json(BW22L_FREEZE_PATH)
	if freeze.is_empty():
		return false
	var matrix: Dictionary = freeze.get("physical_matrix", {})
	var gate: Dictionary = freeze.get("gate_contract", {})
	var bindings: Dictionary = freeze.get("source_bindings", {})
	var harness_binding: Dictionary = bindings.get("physical_harness", {})
	return (
		String(freeze.get("schema_version", "")) == BW22L_FREEZE_SCHEMA
		and String(freeze.get("status", "")) == BW22L_FREEZE_STATUS
		and String(freeze.get("campaign_id", "")) == BW22L_CAMPAIGN_ID
		and String(freeze.get("gate_id", "")) == BW22L_GATE_ID
		and int(matrix.get("expected_world_count", -1)) == 28
		and int(gate.get("expected_gate_count", -1)) == 50
		and (
			String(harness_binding.get("path", ""))
			== "tests/test_sdk_balanced_wave_bw22l_lateral_development.gd"
		)
		and (
			_raw_sha256("res://tests/test_sdk_balanced_wave_bw22l_lateral_development.gd")
			== "sha256:" + String(harness_binding.get("raw_sha256", ""))
		)
	)


func _physical_authorization_exact(cell_id: String) -> bool:
	var attempt_path := OS.get_environment(BW22L_AUTHORIZATION_PATH_ENV)
	var authorization_token := OS.get_environment(BW22L_AUTHORIZATION_TOKEN_ENV)
	var authorized_cell := OS.get_environment(BW22L_AUTHORIZED_CELL_ENV)
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
		(
			String(attempt.get("schema_version", ""))
			== "sporespore_balanced_wave_bw22l_lateral_development_attempt_v1"
		)
		and String(attempt.get("campaign_id", "")) == BW22L_CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == BW22L_GATE_ID
		and String(attempt.get("authorization_token", "")) == authorization_token
		and String(attempt.get("source_commit", "")).length() == 40
		and bool(attempt.get("source_worktree_clean", false))
		and bool(attempt.get("source_matches_live_github_main", false))
		and bool(attempt.get("complete_zero_world_gate_passed", false))
		and bool(attempt.get("authority_contract_passed", false))
		and bool(attempt.get("stage_one_freeze_verified", false))
		and (
			_raw_sha256(BW22L_FREEZE_PATH)
			== "sha256:" + String(attempt.get("stage_one_freeze_raw_sha256", ""))
		)
		and bool(attempt.get("physical_identity_consumed", false))
		and not bool(attempt.get("same_identity_rerun_allowed", true))
		and int(attempt.get("expected_world_count", -1)) == 28
		and (attempt.get("ordered_cell_ids", []) as Array) == _expected_cell_ids()
	)


static func _expected_cell_ids() -> Array:
	var ids: Array = []
	for profile_token in BW22L_PROFILE_TOKENS:
		for seed in BW22L_SEEDS:
			for candidate_id in BW22L_CANDIDATE_IDS:
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
			if int(seed) == 24011:
				ids.append("development_mu%s_s24011_control" % String(profile_token))
	ids.append("negative_mu000_s24011_safety")
	return ids


static func _false_boolean_count(values: Dictionary) -> int:
	var count := 0
	for value in values.values():
		if typeof(value) == TYPE_BOOL and not bool(value):
			count += 1
	return count
