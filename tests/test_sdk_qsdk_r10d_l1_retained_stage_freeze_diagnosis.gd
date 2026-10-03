extends SceneTree

const RecoveryScript := preload(
	"res://scripts/lab/gait/qsdk_r10d_supported_start_phase_robust_push_recovery.gd"
)
const WorkerScript := preload(
	"res://tests/test_sdk_qsdk_r10d_supported_start_phase_robust_push_recovery_worker.gd"
)
const MARKER := "QSDK_R10D_L1_RETAINED_STAGE_FREEZE_DIAGNOSIS_ZERO_WORLD "
const STAGE_PATH := "res://sdk/qsdk_r10d_development_route_ghost_zero_world_qualification_closure_v1.json"
const ATTEMPT_PATH := (
	"C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
	+ "qsdk-r10d-development-route-ghost-physical-f060ca2137c4/"
	+ "baseline_s40001/attempt.json"
)


func _initialize() -> void:
	var receipt := _diagnose()
	print(MARKER, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(receipt.get("ok", false)) else 1)


func _diagnose() -> Dictionary:
	if root.get_child_count() != 0:
		return _failure("QSDK_R10D_L1_SCENE_TREE_NOT_EMPTY")
	var freeze := _read_json_object(STAGE_PATH)
	var attempt := _read_json_object(ATTEMPT_PATH)
	if freeze.is_empty() or attempt.is_empty():
		return _failure("QSDK_R10D_L1_RETAINED_INPUT_MISSING")
	var role := "development_route_ghost"
	var expected_cell_ids := ["baseline_s40001", "push_s40001"]
	var r10b: Dictionary = freeze.get("consumed_r10b_held_out_closure", {})
	var r05e: Dictionary = freeze.get("r05e_supported_start_closure", {})
	var parsed_seed_values: Array = r05e.get("supported_campaign_seeds", [])
	var parsed_seed_types: Array = []
	var normalized_seed_values: Array = []
	for value in parsed_seed_values:
		parsed_seed_types.append(type_string(typeof(value)))
		normalized_seed_values.append(int(value))
	var successor_freeze := freeze.duplicate(true)
	successor_freeze["schema_version"] = WorkerScript.STAGE_FREEZE_SCHEMA
	successor_freeze["repair_id"] = RecoveryScript.REPAIR_ID
	successor_freeze["r10d_l1_design_sha256"] = "sha256:" + RecoveryScript.L1_DESIGN_RAW_SHA256
	successor_freeze["consumed_r10d_physical_closure_sha256"] = (
		WorkerScript.CONSUMED_R10D_PHYSICAL_CLOSURE_SHA256
	)
	successor_freeze["qualified_source_path_count"] = WorkerScript.QUALIFIED_SOURCE_PATH_COUNT
	successor_freeze["qualified_source_path_sha256"] = WorkerScript.QUALIFIED_SOURCE_PATH_SHA256
	var normalization_controls := [
		WorkerScript._exact_integer_array([40101, 40102, 40103], RecoveryScript.HELD_OUT_SEEDS),
		WorkerScript._exact_integer_array(
			[40101.0, 40102.0, 40103.0], RecoveryScript.HELD_OUT_SEEDS
		),
		not WorkerScript._exact_integer_array(
			[40101.5, 40102.0, 40103.0], RecoveryScript.HELD_OUT_SEEDS
		),
		not WorkerScript._exact_integer_array(
			[40101.0, 40103.0, 40102.0], RecoveryScript.HELD_OUT_SEEDS
		),
		not WorkerScript._exact_integer_array([40101.0, 40102.0], RecoveryScript.HELD_OUT_SEEDS),
		not WorkerScript._exact_integer_array(
			[40101.0, true, 40103.0], RecoveryScript.HELD_OUT_SEEDS
		),
		not WorkerScript._exact_integer_array(
			[40101.0, "40102", 40103.0], RecoveryScript.HELD_OUT_SEEDS
		),
		not WorkerScript._exact_integer_array(
			[40101.0, NAN, 40103.0], RecoveryScript.HELD_OUT_SEEDS
		),
		not WorkerScript._exact_integer_array(
			[40101.0, INF, 40103.0], RecoveryScript.HELD_OUT_SEEDS
		),
		not WorkerScript._exact_integer_array(null, RecoveryScript.HELD_OUT_SEEDS),
	]
	var checks := {
		"worker_exact_stage_freeze":
		(
			WorkerScript
			. _stage_freeze_is_exact(
				successor_freeze,
				role,
				String(attempt.get("source_commit", "")),
				String(attempt.get("qualification_parent_commit", "")),
				expected_cell_ids,
			)
		),
		"schema":
		String(freeze.get("schema_version", "")) == "sporespore_qsdk_r10d_stage_freeze_v1",
		"status":
		String(freeze.get("status", "")) == "closed_passing_official_zero_world_qualification",
		"gate": String(freeze.get("gate_id", "")) == RecoveryScript.GATE_ID,
		"campaign":
		String(freeze.get("campaign_id", "")) == RecoveryScript.DEVELOPMENT_GHOST_CAMPAIGN_ID,
		"role": String(freeze.get("campaign_role", "")) == role,
		"question_class": String(freeze.get("question_class", "")) == "development",
		"source_commit":
		String(freeze.get("source_commit", "")) == String(attempt.get("source_commit", "")),
		"qualification_parent_commit":
		(
			String(freeze.get("qualification_parent_commit", ""))
			== String(attempt.get("qualification_parent_commit", ""))
		),
		"qualified_source_count": int(freeze.get("qualified_source_path_count", -1)) == 81,
		"qualified_source_digest":
		(
			String(freeze.get("qualified_source_path_sha256", ""))
			== "sha256:ef91bb238822860b9bfb841b9cbdb52c452169f694cf2825e2362df427ac005e"
		),
		"design_digest":
		(
			String(freeze.get("r10c_design_sha256", ""))
			== "sha256:" + RecoveryScript.DESIGN_RAW_SHA256
		),
		"maximum_world_count": int(freeze.get("maximum_world_count", -1)) == 2,
		"qualification_passed": bool(freeze.get("official_zero_world_qualification_passed", false)),
		"freeze_does_not_authorize_physics":
		not bool(freeze.get("physical_execution_authorized_by_freeze", true)),
		"physical_acceptance_false": not bool(freeze.get("physical_acceptance_authority", true)),
		"release_authority_false": not bool(freeze.get("release_authority", true)),
		"ordered_cell_ids": freeze.get("ordered_cell_ids", []) == expected_cell_ids,
		"development_prerequisite_null":
		freeze.get("prerequisite_development_route_ghost", null) == null,
		"r10b_status":
		String(r10b.get("status", "")) == "closed_consumed_valid_complete_finite_negative",
		"r10b_identity_consumed": bool(r10b.get("physical_identity_consumed", false)),
		"r10b_rerun_refused": not bool(r10b.get("same_identity_rerun_permitted", true)),
		"r10b_claim_false": not bool(r10b.get("bounded_upright_push_recovery_claimed", true)),
		"r05e_status":
		(
			String(r05e.get("status", ""))
			== (
				"closed_consumed_complete_held_out_finite_positive_"
				+ "eligible_for_separate_qsdk_r05_adoption"
			)
		),
		"r05e_generator": int(r05e.get("selected_generator_index", -1)) == 217,
		"r05e_morphology":
		String(r05e.get("selected_morphology_id", "")) == RecoveryScript.MORPHOLOGY_ID,
		"r05e_seed_array_direct_equality": parsed_seed_values == RecoveryScript.HELD_OUT_SEEDS,
		"r05e_seed_array_normalized_equality":
		normalized_seed_values == RecoveryScript.HELD_OUT_SEEDS,
		"r05e_walking_pass_count": int(r05e.get("walking_pass_count", -1)) == 3,
		"r05e_false_walking_count": int(r05e.get("false_walking_receipt_count", -1)) == 0,
		"r05e_push_claim_false": not bool(r05e.get("external_push_recovery_claimed", true)),
	}
	var failed_checks: Array = []
	for key in checks:
		if not bool(checks[key]):
			failed_checks.append(String(key))
	var expected_predecessor_failure_checks := ["r05e_seed_array_direct_equality"]
	var unexpected_failure_checks: Array = []
	for key in failed_checks:
		if not expected_predecessor_failure_checks.has(key):
			unexpected_failure_checks.append(key)
	var normalization_controls_passed := normalization_controls.all(func(value): return bool(value))
	var diagnosis_passed := (
		bool(checks["worker_exact_stage_freeze"])
		and not bool(checks["r05e_seed_array_direct_equality"])
		and bool(checks["r05e_seed_array_normalized_equality"])
		and failed_checks == expected_predecessor_failure_checks
		and unexpected_failure_checks.is_empty()
		and normalization_controls_passed
	)
	return {
		"schema_version": "sporespore_qsdk_r10d_l1_retained_stage_freeze_diagnosis_v1",
		"gate_id": "QSDK-R10D-L1",
		"ok": diagnosis_passed,
		"failure_code": "" if diagnosis_passed else "QSDK_R10D_L1_DIAGNOSIS_MISMATCH",
		"consumed_predecessor_gate_id": "QSDK-R10D",
		"consumed_predecessor_closure_path":
		"sdk/qsdk_r10d_development_route_ghost_physical_closure_v1.json",
		"stage_raw_sha256": "sha256:" + FileAccess.get_sha256(STAGE_PATH).to_lower(),
		"attempt_raw_sha256": "sha256:" + FileAccess.get_sha256(ATTEMPT_PATH).to_lower(),
		"checks": checks,
		"failed_checks": failed_checks,
		"expected_predecessor_failure_checks": expected_predecessor_failure_checks,
		"unexpected_failure_checks": unexpected_failure_checks,
		"parsed_supported_seed_values": parsed_seed_values,
		"parsed_supported_seed_types": parsed_seed_types,
		"normalized_supported_seed_values": normalized_seed_values,
		"normalization_control_count": normalization_controls.size(),
		"normalization_controls_passed": normalization_controls_passed,
		"diagnosis_world_build_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count(),
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _read_json_object(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _failure(code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10d_l1_retained_stage_freeze_diagnosis_v1",
		"gate_id": "QSDK-R10D-L1",
		"ok": false,
		"failure_code": code,
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
