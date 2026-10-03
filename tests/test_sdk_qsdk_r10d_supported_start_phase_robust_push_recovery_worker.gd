extends "res://tests/test_sdk_qsdk_independent_morphology_v2.gd"
# gdlint: disable=max-line-length,max-returns

## Serialized QSDK-R10D worker.
##
## Contract and preflight modes return before world construction. Physical mode
## is fail-closed behind a separately frozen, content-addressed execution
## authority that does not exist during implementation qualification.

const RecoveryScript := preload(
	"res://scripts/lab/gait/qsdk_r10d_supported_start_phase_robust_push_recovery.gd"
)

const CONTRACT_MARKER := "QSDK_R10D_WORKER_CONTRACT_ZERO_WORLD "
const PREFLIGHT_MARKER := "QSDK_R10D_WORKER_ENTRYPOINT_ZERO_WORLD "
const CELL_MARKER := "QSDK_R10D_PHYSICAL_CELL "
const PAIR_MARKER := "QSDK_R10D_PAIR_EVALUATION_ZERO_WORLD "
const ATTEMPT_PATH_ENV := "SPORESPORE_QSDK_R10D_ATTEMPT"
const ATTEMPT_TOKEN_ENV := "SPORESPORE_QSDK_R10D_TOKEN"
const ATTEMPT_SCHEMA := "sporespore_qsdk_r10d_physical_attempt_v2"
const EXECUTION_AUTHORITY_SCHEMA := "sporespore_qsdk_r10d_execution_authority_v2"
const STAGE_FREEZE_SCHEMA := "sporespore_qsdk_r10d_stage_freeze_v2"
const QUALIFIED_SOURCE_PATH_COUNT := 88
const QUALIFIED_SOURCE_PATH_SHA256 := "sha256:fde0b22bd6fbe0a51a07949efeb93550db16bdb580de39f192192f4d63c897e2"
const R10C_DESIGN_SHA256 := "sha256:" + RecoveryScript.DESIGN_RAW_SHA256
const R10D_L1_DESIGN_SHA256 := "sha256:" + RecoveryScript.L1_DESIGN_RAW_SHA256
const CONSUMED_R10D_PHYSICAL_CLOSURE_SHA256 := "sha256:fbefa85145bcd5bb05c3672c4fe6a0b56eaf75751ae8ed5dae9ff724487b4475"
const R10B_HELD_OUT_CLOSURE_PATH := "sdk/qsdk_r10b_held_out_finite_decision_physical_closure_v1.json"
const R10B_HELD_OUT_CLOSURE_BYTES := 30998
const R10B_HELD_OUT_CLOSURE_SHA256 := "sha256:108473a00fb7d789862996b85e95ef255cc62b5e2c6037aecb556bd77dce625a"
const R05E_PHYSICAL_CLOSURE_PATH := "sdk/qsdk_r05e_exact_finite_morphology_physical_closure_v1.json"
const R05E_PHYSICAL_CLOSURE_BYTES := 49049
const R05E_PHYSICAL_CLOSURE_SHA256 := "sha256:dac4ac8790cd74d89da0286c36aaf541fbfe7011d2bea66077b941363d47b33e"

var _active_arm_id := ""
var _active_seed := -1


func _compile_campaign_generation(generator_index: int) -> Dictionary:
	return RecoveryScript.compile_generation(generator_index)


func _verify_campaign_generation(
	generator_index: int,
	expected_generator_receipt_sha256: String,
	expected_proportion_spec_sha256: String,
) -> Dictionary:
	return (
		RecoveryScript
		. verify_generation(
			generator_index,
			expected_generator_receipt_sha256,
			expected_proportion_spec_sha256,
		)
	)


func _environment_challenge_options_for_cell(
	_generator_index: int,
	_seed: int,
) -> Dictionary:
	return RecoveryScript.challenge_options(_active_arm_id)


func _sdk_physical_trace_options_for_cell(
	_generator_index: int,
	_seed: int,
) -> Dictionary:
	return RecoveryScript.trace_options(_active_arm_id, _active_seed)


func _run() -> void:
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or (args.size() == 1 and String(args[0]) == "contract"):
		var contract_receipt := _contract_receipt()
		print(CONTRACT_MARKER, JSON.stringify(contract_receipt, "", true, true))
		quit(0 if bool(contract_receipt.get("ok", false)) else 1)
		return
	if args.size() == 2 and String(args[0]) == "preflight":
		var preflight_receipt := await _entrypoint_preflight(String(args[1]))
		print(PREFLIGHT_MARKER, JSON.stringify(preflight_receipt, "", true, true))
		quit(0 if bool(preflight_receipt.get("ok", false)) else 1)
		return
	if args.size() == 3 and String(args[0]) == "pair-evaluate":
		var pair_receipt := _pair_evaluate_files(String(args[1]), String(args[2]))
		print(PAIR_MARKER, JSON.stringify(pair_receipt, "", true, true))
		quit(0 if bool(pair_receipt.get("ok", false)) else 1)
		return
	if args.size() == 4 and String(args[0]) == "physical" and String(args[3]).is_valid_int():
		await _physical(
			String(args[1]),
			String(args[2]),
			String(args[3]).to_int(),
		)
		return
	var failure := _worker_failure("QSDK_R10D_WORKER_ARGUMENTS_INVALID")
	print(CONTRACT_MARKER, JSON.stringify(failure, "", true, true))
	quit(1)


func _contract_receipt() -> Dictionary:
	if root.get_child_count() != 0:
		return _worker_failure("QSDK_R10D_WORKER_CONTRACT_SCENE_TREE_NOT_EMPTY")
	var contracts: Array = []
	for seed_value in RecoveryScript.ALL_SEEDS:
		for arm_value in RecoveryScript.ARM_ORDER:
			var arm_id := String(arm_value)
			var seed := int(seed_value)
			var contract := RecoveryScript.compile_static_contract(arm_id, seed)
			if not _zero_world_success(contract):
				return _worker_failure("QSDK_R10D_WORKER_STATIC_CONTRACT_INVALID")
			(
				contracts
				. append(
					{
						"arm_id": arm_id,
						"campaign_seed": seed,
						"cell_id": String(contract["cell_id"]),
						"challenge_configuration_sha256":
						String(contract["challenge_configuration_sha256"]),
						"trace_configuration_sha256":
						String(contract["trace_configuration_sha256"]),
					}
				)
			)
	return {
		"schema_version": "sporespore_qsdk_r10d_worker_contract_zero_world_v2",
		"gate_id": RecoveryScript.GATE_ID,
		"repair_id": RecoveryScript.REPAIR_ID,
		"ok": true,
		"failure_code": "",
		"contract_count": contracts.size(),
		"contracts": contracts,
		"physical_execution_authorized": false,
		"locomotion_outcome_exposure_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count(),
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


func _entrypoint_preflight(campaign_role: String) -> Dictionary:
	var seeds := _seeds_for_role(campaign_role)
	if seeds.is_empty() or root.get_child_count() != 0:
		return _worker_failure("QSDK_R10D_WORKER_PREFLIGHT_ROLE_INVALID")
	var receipts: Array = []
	for seed_value in seeds:
		var seed := int(seed_value)
		for arm_value in RecoveryScript.ARM_ORDER:
			var arm_id := String(arm_value)
			_active_arm_id = arm_id
			_active_seed = seed
			var result := await _run_cell(RecoveryScript.GENERATOR_INDEX, seed, true)
			var selected_start: Dictionary = (
				result
				. get(
					"selected_policy_full_authority_start",
					{},
				)
			)
			var exact: bool = (
				bool(result.get("ok", false))
				and bool(result.get("entrypoint_control_flow_complete", false))
				and int(result.get("actual_world_build_count", -1)) == 0
				and int(result.get("scene_tree_insertion_count", -1)) == 0
				and not bool(result.get("physics_state_modified", true))
				and bool(result.get("sdk_physical_trace_enabled", false))
				and (
					result.get("sdk_physical_trace_options", {})
					== RecoveryScript.compile_static_contract(arm_id, seed)["trace_options"]
				)
				and not bool(result.get("candidate_authority_horizon_enabled", true))
				and not bool(result.get("sdk_heading_schedule_enabled", true))
				and bool(
					(
						selected_start
						. get(
							"declared_policy_runtime_boundary_preflight_passed",
							false,
						)
					)
				)
				and (
					String(selected_start.get("fixture_spec_sha256", ""))
					== RecoveryScript.FIXTURE_SPEC_SHA256
				)
				and (
					String(selected_start.get("material_profile_sha256", ""))
					== RecoveryScript.MATERIAL_PROFILE_SHA256
				)
				and (
					String(selected_start.get("controller_profile_sha256", ""))
					== RecoveryScript.CONTROLLER_PROFILE_SHA256
				)
				and (
					String(selected_start.get("adapter_capability_sha256", ""))
					== RecoveryScript.ADAPTER_CAPABILITY_SHA256
				)
				and not bool(result.get("locomotion_outcome_exposed", true))
				and not bool(result.get("physical_acceptance_authority", true))
			)
			if not exact:
				return _worker_failure(
					"QSDK_R10D_WORKER_PREFLIGHT_ENTRYPOINT_INVALID",
					{"arm_id": arm_id, "campaign_seed": seed, "result": result},
				)
			(
				receipts
				. append(
					{
						"arm_id": arm_id,
						"campaign_seed": seed,
						"cell_id": RecoveryScript.cell_id(arm_id, seed),
						"trace_configuration_sha256":
						String(result["sdk_physical_trace_configuration_sha256"]),
						"declared_policy_runtime_boundary_preflight_passed": true,
						"world_build_count": 0,
					}
				)
			)
	_active_arm_id = ""
	_active_seed = -1
	return {
		"schema_version": "sporespore_qsdk_r10d_worker_entrypoint_zero_world_v2",
		"gate_id": RecoveryScript.GATE_ID,
		"repair_id": RecoveryScript.REPAIR_ID,
		"campaign_role": campaign_role,
		"ok": true,
		"failure_code": "",
		"entrypoint_count": receipts.size(),
		"entrypoints": receipts,
		"physical_execution_authorized": false,
		"locomotion_outcome_exposure_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count(),
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


func _physical(campaign_role: String, arm_id: String, campaign_seed: int) -> void:
	var authorization := _physical_authorization_receipt(campaign_role, arm_id, campaign_seed)
	if not bool(authorization.get("ok", false)):
		var failure := _worker_failure(
			String(authorization.get("failure_code", "QSDK_R10D_PHYSICAL_AUTHORIZATION_INVALID")),
			{"authorization": authorization},
		)
		print(CELL_MARKER, JSON.stringify(failure, "", true, true))
		quit(1)
		return
	_active_arm_id = arm_id
	_active_seed = campaign_seed
	var summary := await _run_cell(RecoveryScript.GENERATOR_INDEX, campaign_seed, false)
	var evaluation := RecoveryScript.evaluate_world(summary, arm_id, campaign_seed)
	var receipt := _physical_receipt(summary, evaluation, authorization)
	print(CELL_MARKER, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(evaluation.get("ok", false)) else 1)


func _physical_receipt(
	summary: Dictionary,
	evaluation: Dictionary,
	authorization: Dictionary,
) -> Dictionary:
	var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var trace: Dictionary = summary.get("sdk_physical_trace", {})
	return {
		"schema_version": "sporespore_qsdk_r10d_physical_cell_v2",
		"gate_id": RecoveryScript.GATE_ID,
		"repair_id": RecoveryScript.REPAIR_ID,
		"campaign_id": String(authorization.get("campaign_id", "")),
		"campaign_role": String(authorization.get("campaign_role", "")),
		"source_commit": String(authorization.get("source_commit", "")),
		"arm_id": _active_arm_id,
		"campaign_seed": _active_seed,
		"cell_id": RecoveryScript.cell_id(_active_arm_id, _active_seed),
		"selected_candidate_id": RecoveryScript.SELECTED_CANDIDATE_ID,
		"controller_policy_id": String(sdk_summary.get("controller_policy_id", "")),
		"selected_policy_digest": RecoveryScript.SELECTED_POLICY_DIGEST,
		"generator_index": RecoveryScript.GENERATOR_INDEX,
		"morphology_id": RecoveryScript.MORPHOLOGY_ID,
		"generator_receipt_sha256": RecoveryScript.GENERATOR_RECEIPT_SHA256,
		"source_r05e_generator_receipt_sha256": RecoveryScript.R05E_GENERATOR_RECEIPT_SHA256,
		"proportion_spec_sha256": RecoveryScript.R05E_PROPORTION_SPEC_SHA256,
		"material_profile_id": RecoveryScript.MATERIAL_PROFILE_ID,
		"material_profile_sha256": String(summary.get("sdk_material_profile_sha256", "")),
		"r10c_design_sha256": R10C_DESIGN_SHA256,
		"r10d_l1_design_sha256": R10D_L1_DESIGN_SHA256,
		"consumed_r10d_physical_closure_sha256": CONSUMED_R10D_PHYSICAL_CLOSURE_SHA256,
		"consumed_r10b_held_out_closure_sha256": R10B_HELD_OUT_CLOSURE_SHA256,
		"r05e_physical_closure_sha256": R05E_PHYSICAL_CLOSURE_SHA256,
		"fixture_spec_sha256": String(summary.get("fixture_spec_sha256", "")),
		"controller_profile_sha256": String(sdk_summary.get("controller_profile_sha256", "")),
		"adapter_capability_sha256": String(sdk_summary.get("adapter_capability_sha256", "")),
		"authorization": authorization.duplicate(true),
		"evaluation": evaluation.duplicate(true),
		"runtime_summary_projection":
		_json_safe(
			{
				"ok": summary.get("ok"),
				"failure_code": summary.get("failure_code"),
				"physical_wave_gait_walking_observed":
				summary.get("physical_wave_gait_walking_observed"),
				"world_build_count": summary.get("world_build_count"),
				"world_reset_count": summary.get("world_reset_count"),
				"executed_ticks": summary.get("executed_ticks"),
				"sdk_adapter_start_tick": summary.get("sdk_adapter_start_tick"),
				"physics_engine": summary.get("physics_engine"),
				"physics_hz": summary.get("physics_hz"),
				"solver_velocity_steps": summary.get("solver_velocity_steps"),
				"solver_position_steps": summary.get("solver_position_steps"),
				"fixture_spec_sha256": summary.get("fixture_spec_sha256"),
				"sdk_material_profile_sha256": summary.get("sdk_material_profile_sha256"),
				"initial_perturbation": summary.get("initial_perturbation"),
				"environment_challenge_options": summary.get("environment_challenge_options"),
				"environment_challenge_configuration_sha256":
				summary.get("environment_challenge_configuration_sha256"),
				"external_push_application_count": summary.get("external_push_application_count"),
				"external_push_receipt": summary.get("external_push_receipt"),
				"walking_gate_receipts": summary.get("walking_gate_receipts"),
				"sdk_authority_summary": sdk_summary,
			}
		),
		"sdk_physical_trace": trace.duplicate(true),
		"world_build_count": int(summary.get("world_build_count", -1)),
		"world_reset_count": int(summary.get("world_reset_count", -1)),
		"behavior_passed": bool(evaluation.get("behavior_passed", false)),
		"outcome_complete": bool(evaluation.get("outcome_complete", false)),
		"evidence_valid": bool(evaluation.get("evidence_valid", false)),
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


func _pair_evaluate_files(baseline_path: String, push_path: String) -> Dictionary:
	if root.get_child_count() != 0:
		return _worker_failure("QSDK_R10D_PAIR_EVALUATOR_SCENE_TREE_NOT_EMPTY")
	var baseline := _read_json_object(baseline_path)
	var push := _read_json_object(push_path)
	if (
		String(baseline.get("schema_version", "")) != "sporespore_qsdk_r10d_physical_cell_v2"
		or String(push.get("schema_version", "")) != "sporespore_qsdk_r10d_physical_cell_v2"
	):
		return _worker_failure("QSDK_R10D_PAIR_EVALUATOR_CELL_FILE_INVALID")
	var result := (
		RecoveryScript
		. evaluate_pair(
			baseline.get("evaluation", {}),
			push.get("evaluation", {}),
		)
	)
	result["baseline_cell_raw_sha256"] = "sha256:" + FileAccess.get_sha256(baseline_path).to_lower()
	result["push_cell_raw_sha256"] = "sha256:" + FileAccess.get_sha256(push_path).to_lower()
	result["model_construction_count"] = 0
	result["world_attempt_count"] = 0
	result["world_build_count"] = 0
	result["scene_tree_insertion_count"] = root.get_child_count()
	result["native_readback_count"] = 0
	result["solver_step_count"] = 0
	result["physics_state_modified"] = false
	result["physical_acceptance_authority"] = false
	return result


func _physical_authorization_receipt(
	campaign_role: String,
	arm_id: String,
	campaign_seed: int,
) -> Dictionary:
	var seeds := _seeds_for_role(campaign_role)
	if not RecoveryScript.ARM_ORDER.has(arm_id) or not seeds.has(campaign_seed):
		return _authorization_failure("QSDK_R10D_PHYSICAL_CELL_OUTSIDE_FROZEN_ROLE")
	var attempt_path := OS.get_environment(ATTEMPT_PATH_ENV)
	var attempt_token := OS.get_environment(ATTEMPT_TOKEN_ENV)
	if (
		attempt_path.is_empty()
		or attempt_token.is_empty()
		or not FileAccess.file_exists(attempt_path)
	):
		return _authorization_failure("QSDK_R10D_PHYSICAL_AUTHORIZATION_REQUIRED")
	var attempt := _read_json_object(attempt_path)
	if attempt.is_empty():
		return _authorization_failure("QSDK_R10D_PHYSICAL_ATTEMPT_INVALID")
	var cell := RecoveryScript.cell_id(arm_id, campaign_seed)
	var output_root := String(attempt.get("output_root", ""))
	var normalized_attempt_path := _normalized_path(attempt_path)
	var normalized_output_root := _normalized_path(output_root)
	var expected_attempt_path := normalized_output_root + "/" + cell + "/attempt.json"
	var exact_attempt := (
		String(attempt.get("schema_version", "")) == ATTEMPT_SCHEMA
		and String(attempt.get("authorization_token", "")) == attempt_token
		and String(attempt.get("gate_id", "")) == RecoveryScript.GATE_ID
		and String(attempt.get("campaign_id", "")) == _campaign_id_for_role(campaign_role)
		and String(attempt.get("campaign_role", "")) == campaign_role
		and String(attempt.get("arm_id", "")) == arm_id
		and int(attempt.get("campaign_seed", -1)) == campaign_seed
		and String(attempt.get("cell_id", "")) == cell
		and not normalized_output_root.is_empty()
		and normalized_attempt_path == expected_attempt_path
		and _is_lower_hex(String(attempt.get("source_commit", "")), 40)
		and _is_lower_hex(String(attempt.get("authorization_commit", "")), 40)
		and _is_lower_hex(String(attempt.get("authorization_parent_commit", "")), 40)
		and _is_lower_hex(String(attempt.get("qualification_parent_commit", "")), 40)
		and String(attempt.get("r10c_design_sha256", "")) == R10C_DESIGN_SHA256
		and String(attempt.get("repair_id", "")) == RecoveryScript.REPAIR_ID
		and String(attempt.get("r10d_l1_design_sha256", "")) == R10D_L1_DESIGN_SHA256
		and (
			String(attempt.get("consumed_r10d_physical_closure_sha256", ""))
			== CONSUMED_R10D_PHYSICAL_CLOSURE_SHA256
		)
		and (
			String(attempt.get("consumed_r10b_held_out_closure_sha256", ""))
			== R10B_HELD_OUT_CLOSURE_SHA256
		)
		and (
			String(attempt.get("r05e_physical_closure_sha256", "")) == R05E_PHYSICAL_CLOSURE_SHA256
		)
		and bool(attempt.get("supervisor_physical_authorized", false))
		and not bool(attempt.get("synthetic_authorization_preflight", true))
		and int(attempt.get("maximum_world_attempt_count", -1)) == 1
		and int(attempt.get("maximum_world_build_count", -1)) == 1
		and int(attempt.get("world_attempt_count_before_worker", -1)) == 0
		and int(attempt.get("world_build_count_before_worker", -1)) == 0
		and not bool(attempt.get("same_identity_rerun_permitted", true))
		and not bool(attempt.get("physical_acceptance_authority", true))
	)
	var lock_value: Variant = attempt.get("operation_lock", null)
	if typeof(lock_value) != TYPE_DICTIONARY:
		return _authorization_failure("QSDK_R10D_PHYSICAL_OPERATION_LOCK_INVALID")
	var lock: Dictionary = lock_value
	exact_attempt = (
		exact_attempt
		and (
			String(lock.get("schema_version", ""))
			== "sporespore_locomotion_operation_lock_receipt_v1"
		)
		and bool(lock.get("acquired", false))
		and (
			String(lock.get("role", ""))
			== (
				"physical_development" if campaign_role == "development_route_ghost" else "physical"
			)
		)
	)
	if not exact_attempt:
		return _authorization_failure("QSDK_R10D_PHYSICAL_ATTEMPT_FIELDS_INVALID")
	var freeze_path := String(attempt.get("stage_freeze_path", ""))
	var freeze_sha256 := String(attempt.get("stage_freeze_sha256", ""))
	var authority_path := String(attempt.get("execution_authority_path", ""))
	var authority_sha256 := String(attempt.get("execution_authority_sha256", ""))
	if (
		freeze_path.is_empty()
		or authority_path.is_empty()
		or not FileAccess.file_exists(freeze_path)
		or not FileAccess.file_exists(authority_path)
		or not _is_prefixed_sha256(freeze_sha256)
		or not _is_prefixed_sha256(authority_sha256)
		or "sha256:" + FileAccess.get_sha256(freeze_path).to_lower() != freeze_sha256
		or "sha256:" + FileAccess.get_sha256(authority_path).to_lower() != authority_sha256
	):
		return _authorization_failure("QSDK_R10D_PHYSICAL_AUTHORITY_BINDING_INVALID")
	var authority := _read_json_object(authority_path)
	var freeze := _read_json_object(freeze_path)
	var expected_cell_ids := _ordered_cell_ids_for_role(campaign_role)
	if not _execution_authority_is_exact(
		authority,
		campaign_role,
		String(attempt.get("source_commit", "")),
		String(attempt.get("authorization_parent_commit", "")),
		String(attempt.get("qualification_parent_commit", "")),
		freeze_sha256,
		normalized_output_root,
		expected_cell_ids,
	):
		return _authorization_failure("QSDK_R10D_EXECUTION_AUTHORITY_INVALID")
	if not _stage_freeze_is_exact(
		freeze,
		campaign_role,
		String(attempt.get("source_commit", "")),
		String(attempt.get("qualification_parent_commit", "")),
		expected_cell_ids,
	):
		return _authorization_failure("QSDK_R10D_STAGE_FREEZE_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"campaign_id": _campaign_id_for_role(campaign_role),
		"repair_id": RecoveryScript.REPAIR_ID,
		"campaign_role": campaign_role,
		"arm_id": arm_id,
		"campaign_seed": campaign_seed,
		"cell_id": cell,
		"source_commit": String(attempt["source_commit"]),
		"authorization_commit": String(attempt["authorization_commit"]),
		"authorization_parent_commit": String(attempt["authorization_parent_commit"]),
		"qualification_parent_commit": String(attempt["qualification_parent_commit"]),
		"attempt_path": attempt_path,
		"attempt_sha256": "sha256:" + FileAccess.get_sha256(attempt_path).to_lower(),
		"stage_freeze_path": freeze_path,
		"stage_freeze_sha256": freeze_sha256,
		"execution_authority_path": authority_path,
		"execution_authority_sha256": authority_sha256,
		"output_root": output_root,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _campaign_id_for_role(campaign_role: String) -> String:
	if campaign_role == "development_route_ghost":
		return RecoveryScript.DEVELOPMENT_GHOST_CAMPAIGN_ID
	if campaign_role == "held_out_finite_decision":
		return RecoveryScript.OFFICIAL_CAMPAIGN_ID
	return ""


static func _question_class_for_role(campaign_role: String) -> String:
	return "development" if campaign_role == "development_route_ghost" else "finite decision"


static func _ordered_cell_ids_for_role(campaign_role: String) -> Array:
	var cells: Array = []
	for seed in _seeds_for_role(campaign_role):
		for arm in RecoveryScript.ARM_ORDER:
			cells.append(RecoveryScript.cell_id(String(arm), int(seed)))
	return cells


static func _stage_freeze_is_exact(
	freeze: Dictionary,
	campaign_role: String,
	source_commit: String,
	qualification_parent_commit: String,
	expected_cell_ids: Array,
) -> bool:
	var prerequisite: Variant = freeze.get("prerequisite_development_route_ghost", null)
	var prerequisite_exact := prerequisite == null
	if campaign_role == "held_out_finite_decision":
		prerequisite_exact = (
			typeof(prerequisite) == TYPE_DICTIONARY
			and bool((prerequisite as Dictionary).get("route_execution_valid", false))
			and bool((prerequisite as Dictionary).get("physical_identity_consumed", false))
			and not bool((prerequisite as Dictionary).get("same_identity_rerun_permitted", true))
		)
	var predecessor_value: Variant = freeze.get("consumed_r10b_held_out_closure", null)
	var predecessor_exact := false
	if typeof(predecessor_value) == TYPE_DICTIONARY:
		var predecessor := predecessor_value as Dictionary
		predecessor_exact = (
			String(predecessor.get("path", "")) == R10B_HELD_OUT_CLOSURE_PATH
			and int(predecessor.get("byte_length", -1)) == R10B_HELD_OUT_CLOSURE_BYTES
			and String(predecessor.get("raw_sha256", "")) == R10B_HELD_OUT_CLOSURE_SHA256
			and _is_lower_hex(String(predecessor.get("git_blob_oid", "")), 40)
			and (
				String(predecessor.get("status", ""))
				== "closed_consumed_valid_complete_finite_negative"
			)
			and bool(predecessor.get("physical_identity_consumed", false))
			and not bool(predecessor.get("same_identity_rerun_permitted", true))
			and not bool(predecessor.get("bounded_upright_push_recovery_claimed", true))
		)
	var support_value: Variant = freeze.get("r05e_supported_start_closure", null)
	var support_exact := false
	if typeof(support_value) == TYPE_DICTIONARY:
		var support := support_value as Dictionary
		support_exact = (
			String(support.get("path", "")) == R05E_PHYSICAL_CLOSURE_PATH
			and int(support.get("byte_length", -1)) == R05E_PHYSICAL_CLOSURE_BYTES
			and String(support.get("raw_sha256", "")) == R05E_PHYSICAL_CLOSURE_SHA256
			and _is_lower_hex(String(support.get("git_blob_oid", "")), 40)
			and (
				String(support.get("status", ""))
				== (
					"closed_consumed_complete_held_out_finite_positive_"
					+ "eligible_for_separate_qsdk_r05_adoption"
				)
			)
			and int(support.get("selected_generator_index", -1)) == RecoveryScript.GENERATOR_INDEX
			and String(support.get("selected_morphology_id", "")) == RecoveryScript.MORPHOLOGY_ID
			and _exact_integer_array(
				support.get("supported_campaign_seeds", null),
				RecoveryScript.HELD_OUT_SEEDS,
			)
			and int(support.get("walking_pass_count", -1)) == 3
			and int(support.get("false_walking_receipt_count", -1)) == 0
			and not bool(support.get("external_push_recovery_claimed", true))
		)
	return (
		String(freeze.get("schema_version", "")) == STAGE_FREEZE_SCHEMA
		and String(freeze.get("status", "")) == "closed_passing_official_zero_world_qualification"
		and String(freeze.get("gate_id", "")) == RecoveryScript.GATE_ID
		and String(freeze.get("repair_id", "")) == RecoveryScript.REPAIR_ID
		and String(freeze.get("campaign_id", "")) == _campaign_id_for_role(campaign_role)
		and String(freeze.get("campaign_role", "")) == campaign_role
		and String(freeze.get("question_class", "")) == _question_class_for_role(campaign_role)
		and String(freeze.get("source_commit", "")) == source_commit
		and String(freeze.get("qualification_parent_commit", "")) == qualification_parent_commit
		and int(freeze.get("qualified_source_path_count", -1)) == QUALIFIED_SOURCE_PATH_COUNT
		and String(freeze.get("qualified_source_path_sha256", "")) == QUALIFIED_SOURCE_PATH_SHA256
		and String(freeze.get("r10c_design_sha256", "")) == R10C_DESIGN_SHA256
		and String(freeze.get("r10d_l1_design_sha256", "")) == R10D_L1_DESIGN_SHA256
		and (
			String(freeze.get("consumed_r10d_physical_closure_sha256", ""))
			== CONSUMED_R10D_PHYSICAL_CLOSURE_SHA256
		)
		and int(freeze.get("maximum_world_count", -1)) == expected_cell_ids.size()
		and bool(freeze.get("official_zero_world_qualification_passed", false))
		and not bool(freeze.get("physical_execution_authorized_by_freeze", true))
		and not bool(freeze.get("physical_acceptance_authority", true))
		and not bool(freeze.get("release_authority", true))
		and freeze.get("ordered_cell_ids", []) == expected_cell_ids
		and prerequisite_exact
		and predecessor_exact
		and support_exact
	)


static func _execution_authority_is_exact(
	authority: Dictionary,
	campaign_role: String,
	source_commit: String,
	authorization_parent_commit: String,
	qualification_parent_commit: String,
	stage_freeze_sha256: String,
	normalized_output_root: String,
	expected_cell_ids: Array,
) -> bool:
	var ordered_cell_ids_value: Variant = authority.get("ordered_cell_ids", null)
	return (
		String(authority.get("schema_version", "")) == EXECUTION_AUTHORITY_SCHEMA
		and String(authority.get("status", "")) == "authorized_single_use_unconsumed"
		and String(authority.get("gate_id", "")) == RecoveryScript.GATE_ID
		and String(authority.get("repair_id", "")) == RecoveryScript.REPAIR_ID
		and String(authority.get("campaign_id", "")) == _campaign_id_for_role(campaign_role)
		and String(authority.get("campaign_role", "")) == campaign_role
		and String(authority.get("question_class", "")) == _question_class_for_role(campaign_role)
		and String(authority.get("source_commit", "")) == source_commit
		and bool(authority.get("authorization_commit_derived_from_current_head", false))
		and String(authority.get("authorization_parent_commit", "")) == authorization_parent_commit
		and String(authority.get("qualification_parent_commit", "")) == qualification_parent_commit
		and String(authority.get("r10c_design_sha256", "")) == R10C_DESIGN_SHA256
		and String(authority.get("r10d_l1_design_sha256", "")) == R10D_L1_DESIGN_SHA256
		and (
			String(authority.get("consumed_r10d_physical_closure_sha256", ""))
			== CONSUMED_R10D_PHYSICAL_CLOSURE_SHA256
		)
		and String(authority.get("stage_freeze_sha256", "")) == stage_freeze_sha256
		and (
			String(authority.get("consumed_r10b_held_out_closure_sha256", ""))
			== R10B_HELD_OUT_CLOSURE_SHA256
		)
		and (
			String(authority.get("r05e_physical_closure_sha256", ""))
			== R05E_PHYSICAL_CLOSURE_SHA256
		)
		and int(authority.get("qualified_source_path_count", -1)) == QUALIFIED_SOURCE_PATH_COUNT
		and (
			String(authority.get("qualified_source_path_sha256", ""))
			== QUALIFIED_SOURCE_PATH_SHA256
		)
		and _normalized_path(String(authority.get("output_root", ""))) == normalized_output_root
		and bool(authority.get("zero_world_qualification_passed", false))
		and bool(authority.get("physical_execution_authorized", false))
		and not bool(authority.get("physical_identity_consumed", true))
		and not bool(authority.get("same_identity_rerun_permitted", true))
		and typeof(ordered_cell_ids_value) == TYPE_ARRAY
		and (ordered_cell_ids_value as Array) == expected_cell_ids
		and (
			int(authority.get("maximum_world_count", -1))
			== _seeds_for_role(campaign_role).size() * 2
		)
		and int(authority.get("maximum_campaign_attempt_count", -1)) == 1
		and not bool(authority.get("physical_acceptance_authority", true))
		and not bool(authority.get("release_authority", true))
	)


static func _seeds_for_role(campaign_role: String) -> Array:
	if campaign_role == "development_route_ghost":
		return RecoveryScript.DEVELOPMENT_GHOST_SEEDS.duplicate()
	if campaign_role == "held_out_finite_decision":
		return RecoveryScript.HELD_OUT_SEEDS.duplicate()
	return []


static func _exact_integer_array(value: Variant, expected: Array) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var values := value as Array
	if values.size() != expected.size():
		return false
	for index in range(expected.size()):
		if typeof(expected[index]) != TYPE_INT:
			return false
		var observed_value: Variant = values[index]
		if typeof(observed_value) != TYPE_INT and typeof(observed_value) != TYPE_FLOAT:
			return false
		var observed_number := float(observed_value)
		if not is_finite(observed_number) or observed_number != float(int(expected[index])):
			return false
	return true


static func _read_json_object(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _normalized_path(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/")


static func _json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR3:
			var vector: Vector3 = value
			return [vector.x, vector.y, vector.z]
		TYPE_VECTOR2:
			var vector: Vector2 = value
			return [vector.x, vector.y]
		TYPE_QUATERNION:
			var quaternion: Quaternion = value
			return [quaternion.x, quaternion.y, quaternion.z, quaternion.w]
		TYPE_ARRAY:
			var output: Array = []
			for item in value:
				output.append(_json_safe(item))
			return output
		TYPE_DICTIONARY:
			var output := {}
			for key in value:
				output[String(key)] = _json_safe(value[key])
			return output
	return value


static func _zero_world_success(result: Dictionary) -> bool:
	return (
		bool(result.get("ok", false))
		and int(result.get("world_build_count", -1)) == 0
		and int(result.get("solver_step_count", -1)) == 0
		and not bool(result.get("physical_acceptance_authority", true))
	)


static func _authorization_failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _worker_failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10d_worker_failure_v2",
		"gate_id": RecoveryScript.GATE_ID,
		"repair_id": RecoveryScript.REPAIR_ID,
		"ok": false,
		"failure_code": code,
		"detail": _json_safe(detail),
		"evidence_valid": false,
		"outcome_complete": false,
		"behavior_passed": false,
		"locomotion_outcome_exposure_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _is_lower_hex(value: String, expected_length: int) -> bool:
	if value.length() != expected_length:
		return false
	for codepoint in value.to_ascii_buffer():
		var digit := codepoint >= 48 and codepoint <= 57
		var lower_hex_letter := codepoint >= 97 and codepoint <= 102
		if not digit and not lower_hex_letter:
			return false
	return true


static func _is_prefixed_sha256(value: String) -> bool:
	return value.begins_with("sha256:") and _is_lower_hex(value.trim_prefix("sha256:"), 64)
