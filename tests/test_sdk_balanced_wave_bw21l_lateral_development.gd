extends "res://tests/test_sdk_balanced_wave_bw20f_material_locomotion.gd"
# gdlint: disable=max-line-length
# gdlint: disable=max-returns
# gdlint: disable=max-file-lines

## BW21L outcome-exposed finite lateral-gain development worker.
##
## This is a distinct successor to the immutable BW20F negative result. Its
## preflight traverses all 53 declared entrypoints without building a world.
## Physical mode opens exactly one supervisor-authorized cell and retains the
## steering/cross-track evidence that BW20F's wrapper omitted.

const Bw21CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const BW21L_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw21l_lateral_development_preregistration.json"
const BW21L_CANDIDATES_PATH := "res://sdk/balanced_wave_bw21l_lateral_development_candidates.json"
const BW21L_SCHEMA := "sporespore_balanced_wave_bw21l_lateral_development_preregistration_v1"
const BW21L_STATUS := "frozen_before_first_bw21l_lateral_development_world"
const BW21L_CAMPAIGN_ID := "BW21L-MATERIAL-LATERAL-DEVELOPMENT"
const BW21L_GATE_ID := "BW21L"
const BW21L_CELL_SCHEMA := "sporespore_balanced_wave_bw21l_lateral_development_cell_v1"
const BW21L_PREFLIGHT_SCHEMA := "sporespore_balanced_wave_bw21l_lateral_development_entrypoint_preflight_v1"
const BW21L_CELL_PREFIX := "BW21L_LATERAL_DEVELOPMENT_CELL "
const BW21L_PREFLIGHT_PREFIX := "BW21L_LATERAL_DEVELOPMENT_PREFLIGHT "
const BW21L_AUTHORIZATION_PREFLIGHT_PREFIX := "BW21L_LATERAL_DEVELOPMENT_AUTHORIZATION_PREFLIGHT "
const BW21L_AUTHORIZATION_PATH_ENV := "SPORESPORE_BW21L_ATTEMPT"
const BW21L_AUTHORIZATION_TOKEN_ENV := "SPORESPORE_BW21L_TOKEN"
const BW21L_AUTHORIZED_CELL_ENV := "SPORESPORE_BW21L_CELL"
const BW21L_REFERENCE_MORPHOLOGY_ID := "godot_jolt_stability_physical_influence_reference"
const BW21L_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_a_v3"
const BW21L_EXECUTION_MODE := "native_balanced_wave_base_with_stability_contribution"
const BW21L_CANDIDATE_IDS := ["BW21L-A", "BW21L-B", "BW21L-C", "BW21L-D"]
const BW21L_POLICY_IDS := [
	"sporespore_balanced_wave_bw15f_b_v1",
	"sporespore_balanced_wave_bw21l_b_v1",
	"sporespore_balanced_wave_bw21l_c_v1",
	"sporespore_balanced_wave_bw21l_d_v1",
]
const BW21L_RUNTIME_PROFILE_SHA256 := [
	"sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413",
	"sha256:70b1b0c445bc8b53d94a09f70e18271b9727d9f41b772fa843ae9e59174af6f5",
	"sha256:53c443565996a1a7e7c749ca37c7530a99847d7c3a267a9dea83ee1c17926ff3",
	"sha256:9b558419c3b74218b26fa306407b6efb20a680c80059365a405c6fdb06642a59",
]
const BW21L_COMPOSITION_DIGESTS := [
	"sha256:2546cae8c4d3312b88289b80c65c0f6cf488c940576c6595c4975617814098d8",
	"sha256:7278c8ed0afbdd8124a51beef8ca8ca0b11731aafcfe5537051504cc9ee94d0f",
	"sha256:f494931c45fe792242556b78cd87b228dff1a1f2b2362674986979c6616e3853",
	"sha256:881cb65b226c5e0f934378db8ad556b2a95cbf87b7098cd868de6a3abe7ec8b3",
]
const BW21L_CONTROL_ID := "BW21L-CONTROL"
const BW21L_CONTROL_DIGEST := "sha256:496c701335b3cf857ac19e3654475e75b407f7de7e7a4f343651b5691f22a7e7"
const BW21L_CANDIDATES_RAW_SHA256 := "4cdb98b341a932ccd69d85839301b54d039e3680cd67a44baeea2b77136d913b"
const BW21L_BW20F_CLOSURE_RAW_SHA256 := "bd18cd9a4905182673459b7b203ff7b7ae4cd5f954f00175f14fc721980bc1ef"
const BW21L_BW20F_REPORT_RAW_SHA256 := "69400655be32d09404222a647601aa7a1a0856c5c4f3c0cd6a07dac3841caf03"
const BW21L_PROFILE_TOKENS := ["009", "037", "076", "118"]
const BW21L_PROFILE_IDS := [
	"godot_jolt_bw20f_mu009_v1",
	"godot_jolt_bw20f_mu037_v1",
	"godot_jolt_bw20f_mu076_v1",
	"godot_jolt_bw20f_mu118_v1",
]
const BW21L_PROFILE_DIGESTS := [
	"sha256:92891cfbed2b30c5d6c72fa02a30770fcf75880416a92fe2f69d9ece8246ee55",
	"sha256:690e5c2f035a7a3efc32fa31c86cfab03299f8c539500e110b5ddf9e35b6dfb9",
	"sha256:76f42bc89da95e09d081d17d5e3aa520de25fa6a352067dd8c30ace3834667b0",
	"sha256:e0c6a6d78ae63a129e7ae44088aeb86da44941dba8cfcfd5680f73a236c9b297",
]
const BW21L_AUTHORED_FRICTIONS := [0.09, 0.37, 0.76, 1.18]
const BW21L_SEEDS := [23001, 23002, 23003]
const BW21L_REFERENCE_DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": BW21L_REFERENCE_MORPHOLOGY_ID,
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 18.0 / 35.0,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}

var _bw21l_cell: Dictionary = {}
var _bw21l_profile_id := ""


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": BW21L_PREREGISTRATION_PATH,
		"preregistration_schema": BW21L_SCHEMA,
		"preregistration_status": BW21L_STATUS,
		"campaign_id": BW21L_CAMPAIGN_ID,
		"gate_id": BW21L_GATE_ID,
		"campaign_seeds": BW21L_SEEDS.duplicate(),
		"entrypoint_receipt_schema": BW21L_PREFLIGHT_SCHEMA,
		"cell_receipt_schema": BW21L_CELL_SCHEMA,
		"entrypoint_prefix": BW21L_PREFLIGHT_PREFIX,
		"cell_prefix": BW21L_CELL_PREFIX,
		"display_name": "BW21L material lateral-gain development",
	}


func _candidate_index() -> int:
	return 1 if not _bw21l_cell.is_empty() else -1


func _bw19v_candidate_index() -> int:
	if _bw21l_cell.is_empty():
		return -1
	return 0 if String(_bw21l_cell.get("role", "")) == "control" else 1


func _candidate_id() -> String:
	return String(_bw21l_cell.get("candidate_id", ""))


func _candidate_composition_digest() -> String:
	return String(_bw21l_cell.get("candidate_composition_digest", ""))


func _candidate_global_scale() -> float:
	return float(_bw21l_cell.get("global_requested_correction_scale", NAN))


func _candidate_authority_scope() -> String:
	return "post_settle_full" if not _bw21l_cell.is_empty() else ""


func _controller_candidate_id() -> String:
	return _candidate_id()


func _controller_policy_id() -> String:
	return String(_bw21l_cell.get("controller_policy_id", ""))


func _controller_policy_digest() -> String:
	return String(_bw21l_cell.get("runtime_profile_sha256", ""))


func _stability_policy_id() -> String:
	return BW21L_STABILITY_POLICY_ID if not _bw21l_cell.is_empty() else ""


func _expected_full_authority_execution_mode() -> String:
	return BW21L_EXECUTION_MODE if not _bw21l_cell.is_empty() else ""


func _walking_required_for_cell_success() -> bool:
	return false


func _material_profile_id() -> String:
	return _bw21l_profile_id


func _run() -> void:
	print("\n=== BW21L material lateral-gain development ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var manifest := _read_json(BW21L_PREREGISTRATION_PATH)
	if not _validate_bw21l_manifest(manifest):
		push_error("BW21L frozen manifest, candidate, or prerequisite identity changed")
		quit(1)
		return
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() == 1 and String(user_args[0]) == "preflight":
		await _run_bw21l_entrypoint_preflight(manifest)
		return
	if user_args.size() == 2 and String(user_args[0]) == "authorization_preflight":
		_run_bw21l_authorization_preflight(manifest, String(user_args[1]))
		return
	if user_args.size() != 2 or String(user_args[0]) != "physical":
		push_error(
			(
				"BW21L accepts exactly 'preflight', "
				+ "'authorization_preflight <cell_id>', or 'physical <cell_id>'"
			)
		)
		quit(1)
		return
	var cell := _find_manifest_cell(manifest, String(user_args[1]))
	if cell.is_empty():
		push_error("BW21L physical cell is not in the frozen matrix")
		quit(1)
		return
	if not _physical_authorization_exact(String(cell["cell_id"])):
		push_error("BW21L physical entry requires exact retained supervisor authorization")
		quit(1)
		return
	_configure_cell(cell)
	var receipt: Dictionary
	if String(cell["role"]) == "safety":
		var summary := await _run_zero_safety_cell(cell, false)
		receipt = _bw21l_zero_safety_receipt(cell, summary)
	else:
		var summary := await _run_cell(0, int(cell["campaign_seed"]), false)
		receipt = _bw21l_physical_cell_receipt(cell, summary)
	_clear_cell_configuration()
	var role_passed := _role_gate_passed(receipt)
	receipt["role_gate_passed"] = role_passed
	receipt["harness_passed"] = role_passed
	print(BW21L_CELL_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if role_passed else 1)


func _run_bw21l_authorization_preflight(manifest: Dictionary, cell_id: String) -> void:
	var root_children_before := root.get_child_count()
	var cell := _find_manifest_cell(manifest, cell_id)
	var authorization_exact := not cell.is_empty() and _physical_authorization_exact(cell_id)
	var receipt := {
		"schema_version":
		"sporespore_balanced_wave_bw21l_lateral_development_" + "authorization_preflight_v1",
		"campaign_id": BW21L_CAMPAIGN_ID,
		"gate_id": BW21L_GATE_ID,
		"cell_id": cell_id,
		"cell_declared": not cell.is_empty(),
		"authorization_exact": authorization_exact,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count() - root_children_before,
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(BW21L_AUTHORIZATION_PREFLIGHT_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if authorization_exact else 1)


func _run_bw21l_entrypoint_preflight(manifest: Dictionary) -> void:
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
		"schema_version": BW21L_PREFLIGHT_SCHEMA,
		"ok":
		(
			all_exact
			and receipts.size() == 53
			and candidate_count == 48
			and control_count == 4
			and safety_count == 1
			and adapter_start_count == 52
			and root.get_child_count() == root_children_before
			and Engine.physics_ticks_per_second == physics_hz_before
		),
		"campaign_id": BW21L_CAMPAIGN_ID,
		"gate_id": BW21L_GATE_ID,
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
	print(BW21L_PREFLIGHT_PREFIX, JSON.stringify(aggregate, "", true, true))
	quit(0 if bool(aggregate["ok"]) else 1)


func _configure_cell(cell: Dictionary) -> void:
	_bw21l_cell = cell.duplicate(true)
	_bw21l_profile_id = String(cell.get("profile_id", ""))


func _clear_cell_configuration() -> void:
	_bw21l_cell = {}
	_bw21l_profile_id = ""
	OS.unset_environment(BW19V_CANDIDATE_ENVIRONMENT_VARIABLE)


func _validate_controller_policy_contract(
	preregistration: Dictionary,
	_selected_policy: Dictionary,
) -> bool:
	if _bw21l_cell.is_empty():
		return false
	var declarations := _read_json(BW21L_CANDIDATES_PATH)
	var candidates: Array = declarations.get("candidates", [])
	var candidate: Dictionary = {}
	if String(_bw21l_cell.get("role", "")) == "control":
		candidate = declarations.get("policy_relative_control", {})
	else:
		for candidate_value in candidates:
			var possible: Dictionary = candidate_value
			if String(possible.get("candidate_id", "")) == _candidate_id():
				candidate = possible
				break
	if candidate.is_empty():
		return false
	var digest := Bw21CanonicalJsonScript.sha256(candidate)
	return (
		(
			String(declarations.get("schema_version", ""))
			== "sporespore_balanced_wave_bw21l_lateral_development_candidates_v1"
		)
		and (declarations.get("candidate_order", []) as Array) == BW21L_CANDIDATE_IDS
		and _raw_sha256(BW21L_CANDIDATES_PATH) == "sha256:" + BW21L_CANDIDATES_RAW_SHA256
		and String(candidate.get("candidate_id", "")) == _candidate_id()
		and String(candidate.get("controller_policy_id", "")) == _controller_policy_id()
		and String(candidate.get("runtime_profile_sha256", "")) == _controller_policy_digest()
		and String(candidate.get("stability_policy_id", "")) == BW21L_STABILITY_POLICY_ID
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
			if String(_bw21l_cell.get("role", "")) == "candidate"
			else (
				String(declarations.get("policy_relative_control_composition_digest", "")) == digest
			)
		)
		and String(_bw21l_cell.get("runtime_profile_sha256", "")) == _controller_policy_digest()
		and String(_bw21l_cell.get("candidate_composition_digest", "")) == digest
		and (
			String(
				(
					(preregistration.get("prerequisite_evidence", {}) as Dictionary)
					. get("candidate_declaration", {})
					. get("raw_sha256", "")
				)
			)
			== BW21L_CANDIDATES_RAW_SHA256
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
	var bw20f: Dictionary = prerequisite.get("bw20f_closed_negative", {})
	var cells: Array = matrix.get("ordered_cells", [])
	var ids: Array = []
	for cell_value in cells:
		ids.append(String((cell_value as Dictionary).get("cell_id", "")))
	return (
		String(preregistration.get("schema_version", "")) == BW21L_SCHEMA
		and String(preregistration.get("status", "")) == BW21L_STATUS
		and String(preregistration.get("campaign_id", "")) == BW21L_CAMPAIGN_ID
		and String(preregistration.get("gate_id", "")) == BW21L_GATE_ID
		and (
			String(preregistration.get("implementation_parent_commit", ""))
			== "611ab8c23ee621a2df0adbd423705ab6039a1a4c"
		)
		and (
			String(study.get("classification", ""))
			== "paired_outcome_exposed_finite_controller_development_screen"
		)
		and bool(study.get("development_screen", false))
		and not bool(study.get("finite_acceptance_decision", true))
		and not bool(study.get("population_inference", true))
		and not bool(study.get("superiority_study", true))
		and not bool(study.get("noninferiority_or_equivalence_study", true))
		and int(study.get("expected_world_count", -1)) == 53
		and cells.size() == 53
		and ids == _expected_cell_ids()
		and int(matrix.get("candidate_world_count", -1)) == 48
		and int(matrix.get("control_world_count", -1)) == 4
		and int(matrix.get("safety_world_count", -1)) == 1
		and int(gate.get("expected_gate_count", -1)) == 73
		and int(gate.get("per_world_execution_integrity_gate_count", -1)) == 53
		and int(gate.get("aggregate_gate_count", -1)) == 16
		and not bool(gate.get("walking_success_required_for_every_candidate_cell", true))
		and bool(gate.get("development_result_may_validly_select_none", false))
		and _all_claims_false(claims)
		and String(bw20f.get("raw_sha256", "")) == BW21L_BW20F_CLOSURE_RAW_SHA256
		and String(bw20f.get("retained_report_raw_sha256", "")) == BW21L_BW20F_REPORT_RAW_SHA256
		and not bool(bw20f.get("accepted", true))
		and _file_hash_exact(
			"res://sdk/balanced_wave_bw20f_material_locomotion_closure.json",
			BW21L_BW20F_CLOSURE_RAW_SHA256,
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
			BW21L_STABILITY_POLICY_ID,
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
			BW21L_STABILITY_POLICY_ID,
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
		not _bw21l_cell.is_empty()
		and bool(start.get("ok", false))
		and String(start.get("controller_policy_id", "")) == _controller_policy_id()
		and String(start.get("authority_scope", "")) == "post_settle_full"
		and String(start.get("stability_policy_id", "")) == BW21L_STABILITY_POLICY_ID
		and String(manifest.get("execution_mode", "")) == BW21L_EXECUTION_MODE
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
		"schema_version": "sporespore_bw21l_candidate_adapter_start_preflight_v1",
		"ok": exact,
		"failure_code": "" if exact else "BW21L_CANDIDATE_ADAPTER_START_INVALID",
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


func _bw21l_physical_cell_receipt(cell: Dictionary, summary: Dictionary) -> Dictionary:
	var receipt := _bw20f_physical_cell_receipt(cell, summary)
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
	receipt["schema_version"] = BW21L_CELL_SCHEMA
	receipt["campaign_id"] = BW21L_CAMPAIGN_ID
	receipt["gate_id"] = BW21L_GATE_ID
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
	receipt["initial_perturbation_sha256"] = Bw21CanonicalJsonScript.sha256(initial_perturbation)
	receipt["failed_production_walking_gate_count"] = _false_boolean_count(walking_receipts)
	receipt["development_only"] = true
	receipt["walking_claim_authorized"] = false
	receipt["material_acceptance_claim_authorized"] = false
	receipt["physical_acceptance_authority"] = false
	return receipt


func _bw21l_zero_safety_receipt(cell: Dictionary, summary: Dictionary) -> Dictionary:
	var receipt := _zero_safety_receipt(cell, summary)
	receipt["schema_version"] = BW21L_CELL_SCHEMA
	receipt["campaign_id"] = BW21L_CAMPAIGN_ID
	receipt["gate_id"] = BW21L_GATE_ID
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


func _validate_bw21l_manifest(manifest: Dictionary) -> bool:
	if manifest.is_empty():
		return false
	var matrix: Dictionary = manifest.get("matrix", {})
	var cells: Array = matrix.get("ordered_cells", [])
	var ids: Array = []
	for cell_value in cells:
		ids.append(String((cell_value as Dictionary).get("cell_id", "")))
	return (
		String(manifest.get("schema_version", "")) == BW21L_SCHEMA
		and String(manifest.get("status", "")) == BW21L_STATUS
		and String(manifest.get("campaign_id", "")) == BW21L_CAMPAIGN_ID
		and String(manifest.get("gate_id", "")) == BW21L_GATE_ID
		and cells.size() == 53
		and ids == _expected_cell_ids()
		and int(matrix.get("candidate_world_count", -1)) == 48
		and int(matrix.get("control_world_count", -1)) == 4
		and int(matrix.get("safety_world_count", -1)) == 1
		and _raw_sha256(BW21L_CANDIDATES_PATH) == "sha256:" + BW21L_CANDIDATES_RAW_SHA256
		and _file_hash_exact(
			"res://sdk/balanced_wave_bw20f_material_locomotion_closure.json",
			BW21L_BW20F_CLOSURE_RAW_SHA256,
		)
	)


func _physical_authorization_exact(cell_id: String) -> bool:
	var attempt_path := OS.get_environment(BW21L_AUTHORIZATION_PATH_ENV)
	var authorization_token := OS.get_environment(BW21L_AUTHORIZATION_TOKEN_ENV)
	var authorized_cell := OS.get_environment(BW21L_AUTHORIZED_CELL_ENV)
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
			== "sporespore_balanced_wave_bw21l_lateral_development_attempt_v1"
		)
		and String(attempt.get("campaign_id", "")) == BW21L_CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == BW21L_GATE_ID
		and String(attempt.get("authorization_token", "")) == authorization_token
		and String(attempt.get("source_commit", "")).length() == 40
		and bool(attempt.get("source_worktree_clean", false))
		and bool(attempt.get("source_matches_live_github_main", false))
		and bool(attempt.get("complete_zero_world_gate_passed", false))
		and bool(attempt.get("authority_contract_passed", false))
		and bool(attempt.get("physical_identity_consumed", false))
		and not bool(attempt.get("same_identity_rerun_allowed", true))
		and int(attempt.get("expected_world_count", -1)) == 53
		and (attempt.get("ordered_cell_ids", []) as Array) == _expected_cell_ids()
	)


static func _expected_cell_ids() -> Array:
	var ids: Array = []
	for profile_token in BW21L_PROFILE_TOKENS:
		for seed in BW21L_SEEDS:
			for candidate_id in BW21L_CANDIDATE_IDS:
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
			if int(seed) == 23001:
				ids.append("development_mu%s_s23001_control" % String(profile_token))
	ids.append("negative_mu000_s23001_safety")
	return ids


static func _false_boolean_count(values: Dictionary) -> int:
	var count := 0
	for value in values.values():
		if typeof(value) == TYPE_BOOL and not bool(value):
			count += 1
	return count
