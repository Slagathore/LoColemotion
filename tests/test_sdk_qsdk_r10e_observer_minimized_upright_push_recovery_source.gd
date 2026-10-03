extends SceneTree
# gdlint: disable=max-file-lines,max-line-length,max-returns

## Zero-world source, evaluator, and authority-document controls for QSDK-R10E.
##
## Every world-shaped value below is a synthetic dictionary. This script creates
## no Node, model, fixture, physics world, native route, or locomotion evidence.

const RecoveryScript := preload(
	"res://scripts/lab/gait/qsdk_r10e_observer_minimized_upright_push_recovery.gd"
)
const QuaternionScalarProjectionScript := preload(
	"res://sdk/adapters/godot/gdscript/quaternion_scalar_projection_v1.gd"
)
const ScalarImpulseValidationScript := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10e_native_impulse_scalar_receipt_validation_v2.gd"
)
const WorkerScript := preload(
	"res://tests/test_sdk_qsdk_r10e_observer_minimized_upright_push_recovery_worker.gd"
)

const MARKER := "QSDK_R10E_OBSERVER_MINIMIZED_UPRIGHT_PUSH_RECOVERY_SOURCE_ZERO_WORLD "


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(receipt.get("ok", false)) else 1)


func _run() -> Dictionary:
	if root.get_child_count() != 0:
		return _failure("QSDK_R10E_SOURCE_SCENE_TREE_NOT_EMPTY")
	var generated := RecoveryScript.compile_generation(RecoveryScript.GENERATOR_INDEX)
	if not _zero_world_success(generated):
		return _failure("QSDK_R10E_SUPPORTED_GENERATION_FAILED", generated)
	var verified := (
		RecoveryScript
		. verify_generation(
			RecoveryScript.GENERATOR_INDEX,
			String(generated.get("generator_receipt_sha256", "")),
			String(generated.get("proportion_spec_sha256", "")),
		)
	)
	if not _zero_world_success(verified):
		return _failure("QSDK_R10E_SUPPORTED_GENERATION_VERIFICATION_FAILED", verified)

	var static_contract_count := 0
	for seed_value in RecoveryScript.ALL_SEEDS:
		for arm_value in RecoveryScript.ARM_ORDER:
			var arm_id := String(arm_value)
			var seed := int(seed_value)
			var contract := RecoveryScript.compile_static_contract(arm_id, seed)
			if (
				not _zero_world_success(contract)
				or String(contract.get("cell_id", "")) != RecoveryScript.cell_id(arm_id, seed)
			):
				return _failure("QSDK_R10E_STATIC_CONTRACT_FAILED", contract)
			static_contract_count += 1

	var baseline_summary := _synthetic_summary(RecoveryScript.BASELINE_ARM_ID, 40002)
	var push_summary := _synthetic_summary(RecoveryScript.PUSH_ARM_ID, 40002)
	var baseline := (
		RecoveryScript
		. evaluate_world(
			baseline_summary,
			RecoveryScript.BASELINE_ARM_ID,
			40002,
		)
	)
	var push := (
		RecoveryScript
		. evaluate_world(
			push_summary,
			RecoveryScript.PUSH_ARM_ID,
			40002,
		)
	)
	var pair := RecoveryScript.evaluate_pair(baseline, push)
	if (
		not _valid_positive_world(baseline)
		or not _valid_positive_world(push)
		or not _valid_positive_pair(pair)
		or (
			int(
				(push.get("recovery_search", {}) as Dictionary).get(
					"first_valid_start_semantic_step", -1
				)
			)
			!= RecoveryScript.FIRST_RECOVERY_START
		)
	):
		return _failure(
			"QSDK_R10E_POSITIVE_SYNTHETIC_CONTROL_FAILED",
			{"baseline": baseline, "push": push, "pair": pair},
		)

	var walking_negative_summary := baseline_summary.duplicate(true)
	var walking_negative_receipts := _all_walking_receipts(true)
	walking_negative_receipts["bounded_anchor_error"] = false
	walking_negative_summary["walking_gate_receipts"] = walking_negative_receipts
	walking_negative_summary["ok"] = false
	walking_negative_summary["physical_wave_gait_walking_observed"] = false
	walking_negative_summary["failure_code"] = "PHYSICAL_WAVE_GAIT_WALKING_NOT_ESTABLISHED"
	var walking_negative := (
		RecoveryScript
		. evaluate_world(
			walking_negative_summary,
			RecoveryScript.BASELINE_ARM_ID,
			40002,
		)
	)
	if not _valid_finite_negative_world(walking_negative):
		return _failure("QSDK_R10E_VALID_WALKING_NEGATIVE_CLASSIFICATION_FAILED")

	var recovery_negative_summary := push_summary.duplicate(true)
	var recovery_negative_trace: Dictionary = recovery_negative_summary["sdk_physical_trace"]
	var recovery_negative_rows: Array = recovery_negative_trace["rows"]
	for step in range(
		RecoveryScript.FIRST_RECOVERY_START,
		RecoveryScript.LAST_RECOVERY_START + RecoveryScript.WINDOW_STEP_COUNT,
	):
		var row: Dictionary = recovery_negative_rows[step]
		row["torso_tilt_rad"] = RecoveryScript.MAXIMUM_TORSO_TILT_RAD + 0.01
		recovery_negative_rows[step] = row
	recovery_negative_trace["rows"] = recovery_negative_rows
	recovery_negative_summary["sdk_physical_trace"] = recovery_negative_trace
	var recovery_negative := (
		RecoveryScript
		. evaluate_world(
			recovery_negative_summary,
			RecoveryScript.PUSH_ARM_ID,
			40002,
		)
	)
	if (
		not _valid_finite_negative_world(recovery_negative)
		or bool((recovery_negative.get("recovery_search", {}) as Dictionary).get("found", true))
		or (
			(recovery_negative.get("recovery_search", {}) as Dictionary).get(
				"reentry_latency_s", 0.0
			)
			!= null
		)
	):
		return _failure("QSDK_R10E_VALID_RECOVERY_NEGATIVE_CLASSIFICATION_FAILED")

	var refusals: Array = []
	(
		refusals
		. append(
			_refusal(
				"generator_type",
				RecoveryScript.compile_generation(225.0),
				"QSDK_R10E_GENERATOR_INDEX_TYPE_INVALID",
			)
		)
	)
	(
		refusals
		. append(
			_refusal(
				"generator_index",
				RecoveryScript.compile_generation(224),
				"QSDK_R10E_GENERATOR_INDEX_UNKNOWN",
			)
		)
	)
	(
		refusals
		. append(
			_refusal(
				"generation_digest",
				(
					RecoveryScript
					. verify_generation(
						RecoveryScript.GENERATOR_INDEX,
						"sha256:" + "0".repeat(64),
						String(generated["proportion_spec_sha256"]),
					)
				),
				"QSDK_R10E_GENERATION_DIGEST_MISMATCH",
			)
		)
	)
	(
		refusals
		. append(
			_refusal(
				"invalid_seed",
				RecoveryScript.compile_static_contract(RecoveryScript.BASELINE_ARM_ID, 40001),
				"QSDK_R10E_CELL_IDENTITY_INVALID",
			)
		)
	)
	(
		refusals
		. append(
			_refusal(
				"invalid_arm",
				RecoveryScript.compile_static_contract("unknown_arm", 40002),
				"QSDK_R10E_CELL_IDENTITY_INVALID",
			)
		)
	)
	refusals.append_array(_instrumentation_refusals(baseline_summary))
	refusals.append_array(_trace_refusals(baseline_summary))
	refusals.append_array(
		_application_and_pair_refusals(baseline_summary, push_summary, baseline, push)
	)

	var authority_controls := _authorization_document_controls()
	if not bool(authority_controls.get("ok", false)):
		return _failure("QSDK_R10E_AUTHORIZATION_DOCUMENT_CONTROLS_FAILED", authority_controls)
	for refusal_value in refusals:
		var refusal: Dictionary = refusal_value
		if not bool(refusal.get("passed", false)):
			return _failure("QSDK_R10E_NEGATIVE_CONTROL_FAILED", refusal)
	if root.get_child_count() != 0:
		return _failure("QSDK_R10E_SOURCE_CREATED_SCENE_CHILD")
	return {
		"schema_version": "sporespore_qsdk_r10e_source_zero_world_v1",
		"gate_id": RecoveryScript.GATE_ID,
		"repair_id": "QSDK-R10E-L3",
		"superseded_physical_supervisor_refusal_sha256":
		WorkerScript.PHYSICAL_SUPERVISOR_REFUSAL_SHA256,
		"l2_held_out_failure_closure_sha256": WorkerScript.L2_HELD_OUT_FAILURE_CLOSURE_SHA256,
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_source_and_evaluator_qualification",
			"question_class": "development",
		},
		"ok": true,
		"failure_code": "",
		"static_contract_compile_count": static_contract_count,
		"synthetic_positive_world_count": 2,
		"synthetic_positive_pair_count": 1,
		"valid_finite_negative_world_count": 2,
		"invalid_or_incomplete_refusal_count": refusals.size(),
		"authorization_document_valid_control_count": int(authority_controls["valid_count"]),
		"authorization_document_mutation_rejection_count":
		int(authority_controls["mutation_rejection_count"]),
		"locomotion_outcome_exposure_count": 0,
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


static func _instrumentation_refusals(summary: Dictionary) -> Array:
	var controls: Array = []
	var cases := [
		["missing", "QSDK_R10E_OBSERVER_INSTRUMENTATION_MISSING"],
		["extra_key", "QSDK_R10E_OBSERVER_INSTRUMENTATION_KEY_SET_MISMATCH"],
		["live_rows", "QSDK_R10E_OBSERVER_INSTRUMENTATION_VALUE_MISMATCH"],
		["live_duplicate", "QSDK_R10E_OBSERVER_INSTRUMENTATION_VALUE_MISMATCH"],
		["live_hash", "QSDK_R10E_OBSERVER_INSTRUMENTATION_VALUE_MISMATCH"],
		["live_projection", "QSDK_R10E_OBSERVER_INSTRUMENTATION_VALUE_MISMATCH"],
		["materialized_count", "QSDK_R10E_OBSERVER_INSTRUMENTATION_VALUE_MISMATCH"],
		["materialization_phase", "QSDK_R10E_OBSERVER_INSTRUMENTATION_VALUE_MISMATCH"],
	]
	for case_value in cases:
		var case: Array = case_value
		var mutated := summary.duplicate(true)
		var trace: Dictionary = mutated["sdk_physical_trace"]
		if String(case[0]) == "missing":
			trace.erase("observer_instrumentation_receipt")
		else:
			var instrumentation: Dictionary = trace["observer_instrumentation_receipt"]
			match String(case[0]):
				"extra_key":
					instrumentation["undeclared"] = 0
				"live_rows":
					instrumentation["live_nested_row_materialization_count"] = 1
				"live_duplicate":
					instrumentation["live_trace_row_deep_duplicate_count"] = 1
				"live_hash":
					instrumentation["live_trace_json_or_hash_count"] = 1
				"live_projection":
					instrumentation["live_quaternion_projection_receipt_count"] = 1
				"materialized_count":
					instrumentation["post_solver_materialized_row_count"] -= 1
				"materialization_phase":
					instrumentation["materialization_after_final_solver_step_declared_by_caller"] = false
			trace["observer_instrumentation_receipt"] = instrumentation
		mutated["sdk_physical_trace"] = trace
		(
			controls
			. append(
				_refusal(
					"observer_" + String(case[0]),
					RecoveryScript.evaluate_world(mutated, RecoveryScript.BASELINE_ARM_ID, 40002),
					String(case[1]),
				)
			)
		)
	return controls


static func _trace_refusals(summary: Dictionary) -> Array:
	var controls: Array = []
	var extra_key := summary.duplicate(true)
	var extra_trace: Dictionary = extra_key["sdk_physical_trace"]
	var extra_rows: Array = extra_trace["rows"]
	var extra_row: Dictionary = extra_rows[10]
	extra_row["undeclared"] = true
	extra_rows[10] = extra_row
	extra_trace["rows"] = extra_rows
	extra_key["sdk_physical_trace"] = extra_trace
	(
		controls
		. append(
			_refusal(
				"trace_extra_key",
				RecoveryScript.evaluate_world(extra_key, RecoveryScript.BASELINE_ARM_ID, 40002),
				"QSDK_R10E_TRACE_ROW_KEY_SET_MISMATCH",
			)
		)
	)
	var wrong_step := summary.duplicate(true)
	var wrong_step_trace: Dictionary = wrong_step["sdk_physical_trace"]
	var wrong_step_rows: Array = wrong_step_trace["rows"]
	var wrong_step_row: Dictionary = wrong_step_rows[100]
	wrong_step_row["semantic_step"] = 99
	wrong_step_rows[100] = wrong_step_row
	wrong_step_trace["rows"] = wrong_step_rows
	wrong_step["sdk_physical_trace"] = wrong_step_trace
	(
		controls
		. append(
			_refusal(
				"trace_noncontiguous",
				RecoveryScript.evaluate_world(wrong_step, RecoveryScript.BASELINE_ARM_ID, 40002),
				"QSDK_R10E_TRACE_ROW_HEADER_INVALID",
			)
		)
	)
	var changed_axis := summary.duplicate(true)
	var changed_axis_trace: Dictionary = changed_axis["sdk_physical_trace"]
	var changed_axis_rows: Array = changed_axis_trace["rows"]
	var changed_axis_row: Dictionary = changed_axis_rows[101]
	changed_axis_row["task_frame_lateral_axis_world_unit"] = [0.0, 0.0, -1.0]
	changed_axis_rows[101] = changed_axis_row
	changed_axis_trace["rows"] = changed_axis_rows
	changed_axis["sdk_physical_trace"] = changed_axis_trace
	(
		controls
		. append(
			_refusal(
				"trace_changed_axis",
				RecoveryScript.evaluate_world(changed_axis, RecoveryScript.BASELINE_ARM_ID, 40002),
				"QSDK_R10E_TRACE_TASK_FRAME_CHANGED",
			)
		)
	)
	var missing_row := summary.duplicate(true)
	var missing_row_trace: Dictionary = missing_row["sdk_physical_trace"]
	var missing_rows: Array = missing_row_trace["rows"]
	missing_rows.pop_back()
	missing_row_trace["rows"] = missing_rows
	missing_row["sdk_physical_trace"] = missing_row_trace
	(
		controls
		. append(
			_refusal(
				"trace_missing_row",
				RecoveryScript.evaluate_world(missing_row, RecoveryScript.BASELINE_ARM_ID, 40002),
				"QSDK_R10E_OBSERVER_INSTRUMENTATION_VALUE_MISMATCH",
			)
		)
	)
	return controls


static func _application_and_pair_refusals(
	baseline_summary: Dictionary,
	push_summary: Dictionary,
	baseline: Dictionary,
	push: Dictionary,
) -> Array:
	var controls: Array = []
	var baseline_application := baseline_summary.duplicate(true)
	baseline_application["external_push_application_count"] = 1
	(
		controls
		. append(
			_refusal(
				"baseline_application_count",
				(
					RecoveryScript
					. evaluate_world(
						baseline_application,
						RecoveryScript.BASELINE_ARM_ID,
						40002,
					)
				),
				"QSDK_R10E_BASELINE_NATIVE_IMPULSE_MISMATCH",
			)
		)
	)
	var wrong_receipt := push_summary.duplicate(true)
	var receipt: Dictionary = wrong_receipt["external_push_receipt"]
	receipt["schema_version"] = "sporespore_qsdk_r10d_native_impulse_application_receipt_v1"
	wrong_receipt["external_push_receipt"] = receipt
	(
		controls
		. append(
			_refusal(
				"push_receipt_schema",
				RecoveryScript.evaluate_world(wrong_receipt, RecoveryScript.PUSH_ARM_ID, 40002),
				"QSDK_R10E_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH",
			)
		)
	)
	var unmatched_push := push.duplicate(true)
	unmatched_push["initial_perturbation_sha256"] = "sha256:" + "0".repeat(64)
	(
		controls
		. append(
			_refusal(
				"pair_initial_perturbation",
				RecoveryScript.evaluate_pair(baseline, unmatched_push),
				"QSDK_R10E_PAIR_IDENTITY_OR_WORLD_INTEGRITY_INVALID",
			)
		)
	)
	var weak_effect_summary := push_summary.duplicate(true)
	var weak_receipt: Dictionary = weak_effect_summary["external_push_receipt"]
	var weak_delta := Vector3(0.0, 0.0, 0.00005)
	weak_receipt["observed_next_tick_velocity_delta_world_m_s"] = [
		weak_delta.x,
		weak_delta.y,
		weak_delta.z,
	]
	weak_receipt["observed_next_tick_velocity_delta_magnitude_m_s"] = weak_delta.length()
	weak_effect_summary["external_push_receipt"] = weak_receipt
	var weak_push := (
		RecoveryScript
		. evaluate_world(
			weak_effect_summary,
			RecoveryScript.PUSH_ARM_ID,
			40002,
		)
	)
	(
		controls
		. append(
			_refusal(
				"pair_native_effect_floor",
				RecoveryScript.evaluate_pair(baseline, weak_push),
				"QSDK_R10E_PAIRED_NATIVE_EFFECT_NOT_CONFIRMED",
			)
		)
	)
	return controls


static func _authorization_document_controls() -> Dictionary:
	var source_commit := "1".repeat(40)
	var authorization_parent_commit := "3".repeat(40)
	var qualification_parent_commit := "4".repeat(40)
	var stage_sha256 := "sha256:" + "5".repeat(64)
	var output_root := "C:/qualified/r10e"
	var valid_count := 0
	var mutation_rejection_count := 0
	for role in ["held_out_finite_decision"]:
		var cell_ids := _cell_ids_for_role(role)
		var freeze := _stage_freeze(role, source_commit, qualification_parent_commit, cell_ids)
		if not (
			WorkerScript
			. _stage_freeze_is_exact(
				freeze,
				role,
				source_commit,
				qualification_parent_commit,
				cell_ids,
			)
		):
			return {"ok": false, "failure_code": "VALID_STAGE_FREEZE_REFUSED", "role": role}
		valid_count += 1
		var authority := _execution_authority(
			role,
			source_commit,
			authorization_parent_commit,
			qualification_parent_commit,
			stage_sha256,
			output_root,
			cell_ids,
		)
		if not (
			WorkerScript
			. _execution_authority_is_exact(
				authority,
				role,
				source_commit,
				authorization_parent_commit,
				qualification_parent_commit,
				stage_sha256,
				output_root,
				cell_ids,
			)
		):
			return {"ok": false, "failure_code": "VALID_EXECUTION_AUTHORITY_REFUSED", "role": role}
		valid_count += 1

		for field in [
			"status",
			"repair_id",
			"source_commit",
			"qualified_source_path_count",
			"official_zero_world_qualification_passed",
			"ordered_cell_ids",
			"superseded_physical_supervisor_refusal",
			"consumed_l2_held_out_failure_closure",
		]:
			var mutation := freeze.duplicate(true)
			match field:
				"status":
					mutation[field] = "open"
				"repair_id":
					mutation[field] = "QSDK-R10E-L1"
				"source_commit":
					mutation[field] = "9".repeat(40)
				"qualified_source_path_count":
					mutation[field] = WorkerScript.QUALIFIED_SOURCE_PATH_COUNT + 1
				"official_zero_world_qualification_passed":
					mutation[field] = false
				"ordered_cell_ids":
					mutation[field] = (cell_ids as Array).slice(1)
				"superseded_physical_supervisor_refusal":
					mutation[field] = {}
				"consumed_l2_held_out_failure_closure":
					mutation[field] = {}
			if not (
				WorkerScript
				. _stage_freeze_is_exact(
					mutation,
					role,
					source_commit,
					qualification_parent_commit,
					cell_ids,
				)
			):
				mutation_rejection_count += 1

		for field in [
			"status",
			"repair_id",
			"authorization_parent_commit",
			"stage_freeze_sha256",
			"superseded_physical_supervisor_refusal_sha256",
			"l2_held_out_failure_closure_sha256",
			"output_root",
			"physical_execution_authorized",
			"physical_identity_consumed",
			"same_identity_rerun_permitted",
			"ordered_cell_ids",
		]:
			var mutation := authority.duplicate(true)
			match field:
				"status":
					mutation[field] = "consumed"
				"repair_id":
					mutation[field] = "QSDK-R10E-L1"
				"authorization_parent_commit":
					mutation[field] = "9".repeat(40)
				"stage_freeze_sha256":
					mutation[field] = "sha256:" + "9".repeat(64)
				"superseded_physical_supervisor_refusal_sha256":
					mutation[field] = "sha256:" + "9".repeat(64)
				"l2_held_out_failure_closure_sha256":
					mutation[field] = "sha256:" + "9".repeat(64)
				"output_root":
					mutation[field] = output_root + "/changed"
				"physical_execution_authorized":
					mutation[field] = false
				"physical_identity_consumed":
					mutation[field] = true
				"same_identity_rerun_permitted":
					mutation[field] = true
				"ordered_cell_ids":
					mutation[field] = (cell_ids as Array).slice(1)
			if not (
				WorkerScript
				. _execution_authority_is_exact(
					mutation,
					role,
					source_commit,
					authorization_parent_commit,
					qualification_parent_commit,
					stage_sha256,
					output_root,
					cell_ids,
				)
			):
				mutation_rejection_count += 1
	return {
		"ok": valid_count == 2 and mutation_rejection_count == 19,
		"valid_count": valid_count,
		"mutation_rejection_count": mutation_rejection_count,
	}


static func _stage_freeze(
	role: String,
	source_commit: String,
	qualification_parent_commit: String,
	cell_ids: Array,
) -> Dictionary:
	return {
		"schema_version": WorkerScript.STAGE_FREEZE_SCHEMA,
		"status": "closed_passing_official_zero_world_qualification",
		"gate_id": RecoveryScript.GATE_ID,
		"repair_id": "QSDK-R10E-L3",
		"campaign_id": _campaign_id(role),
		"campaign_role": role,
		"question_class": _question_class(role),
		"ledger_scope": _ledger_scope(role, "official_zero_world_qualification"),
		"source_commit": source_commit,
		"qualification_parent_commit": qualification_parent_commit,
		"qualified_source_path_count": WorkerScript.QUALIFIED_SOURCE_PATH_COUNT,
		"qualified_source_path_sha256": WorkerScript.QUALIFIED_SOURCE_PATH_SHA256,
		"r10e_design_sha256": WorkerScript.R10E_DESIGN_SHA256,
		"r10d_development_closure_sha256": WorkerScript.R10D_DEVELOPMENT_CLOSURE_SHA256,
		"r10d_held_out_closure_sha256": WorkerScript.R10D_HELD_OUT_CLOSURE_SHA256,
		"r05e_physical_closure_sha256": WorkerScript.R05E_PHYSICAL_CLOSURE_SHA256,
		"maximum_world_count": cell_ids.size(),
		"maximum_campaign_attempt_count": 1,
		"official_zero_world_qualification_passed": true,
		"physical_execution_authorized_by_freeze": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"ordered_cell_ids": cell_ids.duplicate(),
		"prerequisite_development_route_ghost":
		(
			{
				"route_execution_valid": true,
				"physical_identity_consumed": true,
				"same_identity_rerun_permitted": false,
				"physical_closure_sha256": "sha256:" + "6".repeat(64),
			}
			if role == "held_out_finite_decision"
			else null
		),
		"r10e_successor_design":
		{
			"path": WorkerScript.R10E_DESIGN_PATH,
			"byte_length": WorkerScript.R10E_DESIGN_BYTES,
			"raw_sha256": WorkerScript.R10E_DESIGN_SHA256,
			"git_blob_oid": "7".repeat(40),
			"status": "prospective_zero_world_successor_design_complete_physics_blocked",
		},
		"consumed_r10d_development_closure":
		{
			"path": WorkerScript.R10D_DEVELOPMENT_CLOSURE_PATH,
			"byte_length": WorkerScript.R10D_DEVELOPMENT_CLOSURE_BYTES,
			"raw_sha256": WorkerScript.R10D_DEVELOPMENT_CLOSURE_SHA256,
			"git_blob_oid": "7".repeat(40),
			"status": "closed_execution_valid_complete_behavior_finite_negative",
			"route_execution_valid": true,
			"physical_identity_consumed": true,
			"same_identity_rerun_permitted": false,
		},
		"consumed_r10d_held_out_closure":
		{
			"path": WorkerScript.R10D_HELD_OUT_CLOSURE_PATH,
			"byte_length": WorkerScript.R10D_HELD_OUT_CLOSURE_BYTES,
			"raw_sha256": WorkerScript.R10D_HELD_OUT_CLOSURE_SHA256,
			"git_blob_oid": "7".repeat(40),
			"status": "closed_consumed_invalid_or_incomplete_no_finite_decision",
			"route_execution_valid": false,
			"physical_identity_consumed": true,
			"same_identity_rerun_permitted": false,
		},
		"r05e_generator_225_support":
		{
			"path": WorkerScript.R05E_PHYSICAL_CLOSURE_PATH,
			"byte_length": WorkerScript.R05E_PHYSICAL_CLOSURE_BYTES,
			"raw_sha256": WorkerScript.R05E_PHYSICAL_CLOSURE_SHA256,
			"git_blob_oid": "7".repeat(40),
			"generator_index": RecoveryScript.GENERATOR_INDEX,
			"morphology_id": RecoveryScript.MORPHOLOGY_ID,
			"supported_campaign_seeds": RecoveryScript.HELD_OUT_SEEDS.duplicate(),
			"walking_receipt_count": 81,
			"false_walking_receipt_count": 0,
			"all_three_exact_walking_cells_passed": true,
			"r10_push_or_recovery_outcome_known": false,
		},
		"superseded_physical_supervisor_refusal":
		{
			"path": WorkerScript.PHYSICAL_SUPERVISOR_REFUSAL_PATH,
			"byte_length": WorkerScript.PHYSICAL_SUPERVISOR_REFUSAL_BYTES,
			"raw_sha256": WorkerScript.PHYSICAL_SUPERVISOR_REFUSAL_SHA256,
			"git_blob_oid": "7".repeat(40),
			"status": "closed_infrastructure_invalid_pre_physics_output_identity_unconsumed",
			"repair_id": "QSDK-R10E-L2",
			"physical_attempt_identity_consumed": false,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"solver_step_count": 0,
		},
		"consumed_l2_held_out_failure_closure":
		{
			"path": WorkerScript.L2_HELD_OUT_FAILURE_CLOSURE_PATH,
			"byte_length": WorkerScript.L2_HELD_OUT_FAILURE_CLOSURE_BYTES,
			"raw_sha256": WorkerScript.L2_HELD_OUT_FAILURE_CLOSURE_SHA256,
			"git_blob_oid": "7".repeat(40),
			"status": "closed_consumed_invalid_or_incomplete_no_finite_decision",
			"repair_id": "QSDK-R10E-L2",
			"physical_identity_consumed": true,
			"same_identity_rerun_permitted": false,
		},
	}


static func _execution_authority(
	role: String,
	source_commit: String,
	authorization_parent_commit: String,
	qualification_parent_commit: String,
	stage_sha256: String,
	output_root: String,
	cell_ids: Array,
) -> Dictionary:
	return {
		"schema_version": WorkerScript.EXECUTION_AUTHORITY_SCHEMA,
		"status": "authorized_single_use_unconsumed",
		"gate_id": RecoveryScript.GATE_ID,
		"repair_id": "QSDK-R10E-L3",
		"campaign_id": _campaign_id(role),
		"campaign_role": role,
		"question_class": _question_class(role),
		"ledger_scope": _ledger_scope(role, "single_use_physical_execution_authority"),
		"source_commit": source_commit,
		"authorization_commit_derived_from_current_head": true,
		"authorization_parent_commit": authorization_parent_commit,
		"qualification_parent_commit": qualification_parent_commit,
		"r10e_design_sha256": WorkerScript.R10E_DESIGN_SHA256,
		"r10d_development_closure_sha256": WorkerScript.R10D_DEVELOPMENT_CLOSURE_SHA256,
		"r10d_held_out_closure_sha256": WorkerScript.R10D_HELD_OUT_CLOSURE_SHA256,
		"r05e_physical_closure_sha256": WorkerScript.R05E_PHYSICAL_CLOSURE_SHA256,
		"superseded_physical_supervisor_refusal_sha256":
		WorkerScript.PHYSICAL_SUPERVISOR_REFUSAL_SHA256,
		"l2_held_out_failure_closure_sha256": WorkerScript.L2_HELD_OUT_FAILURE_CLOSURE_SHA256,
		"qualified_source_path_count": WorkerScript.QUALIFIED_SOURCE_PATH_COUNT,
		"qualified_source_path_sha256": WorkerScript.QUALIFIED_SOURCE_PATH_SHA256,
		"stage_freeze_sha256": stage_sha256,
		"output_root": output_root,
		"zero_world_qualification_passed": true,
		"physical_execution_authorized": true,
		"physical_identity_consumed": false,
		"same_identity_rerun_permitted": false,
		"ordered_cell_ids": cell_ids.duplicate(),
		"maximum_world_count": cell_ids.size(),
		"maximum_campaign_attempt_count": 1,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _synthetic_summary(arm_id: String, campaign_seed: int) -> Dictionary:
	var contract := RecoveryScript.compile_static_contract(arm_id, campaign_seed)
	var orientation_projection := (
		QuaternionScalarProjectionScript.project_quaternion_to_unit_scalar_v1(Quaternion.IDENTITY)
	)
	if not bool(contract.get("ok", false)) or not bool(orientation_projection.get("ok", false)):
		return {}
	var step_count := RecoveryScript.MINIMUM_SDK_STEP_COUNT
	var rows: Array = []
	rows.resize(step_count)
	for step in range(step_count):
		var contact := posmod(step, 90) >= RecoveryScript.MINIMUM_AIRBORNE_DWELL_STEPS
		var linear_velocity_z := 0.0
		if arm_id == RecoveryScript.PUSH_ARM_ID and step == RecoveryScript.PUSH_MARKER_STEP:
			linear_velocity_z = 1.0
		rows[step] = {
			"schema_version": RecoveryScript.TRACE_ROW_SCHEMA,
			"cell_id": RecoveryScript.cell_id(arm_id, campaign_seed),
			"semantic_step": step,
			"sampling_phase": RecoveryScript.TRACE_SAMPLING_PHASE,
			"push_marker_semantic_step": RecoveryScript.PUSH_MARKER_STEP,
			"task_frame_forward_axis_world_unit": [1.0, 0.0, 0.0],
			"task_frame_lateral_axis_world_unit": [0.0, 0.0, 1.0],
			"ordered_foot_contacts_before": _all_contacts(contact),
			"ordered_foot_contacts_after": _all_contacts(contact),
			"validated_portable_command_count": 8,
			"native_actuation_application_count": 8,
			"torso_position_world_m": [float(step) * 0.0001, 0.44, 0.0],
			"torso_orientation_xyzw":
			(orientation_projection["orientation_xyzw"] as Array).duplicate(),
			"torso_orientation_projection": orientation_projection.duplicate(true),
			"torso_linear_velocity_world_m_s": [0.012, 0.0, linear_velocity_z],
			"torso_angular_velocity_world_rad_s": [0.0, 0.0, 0.0],
			"torso_tilt_rad": 0.1,
			"torso_ground_contact": false,
			"post_physics_observation_complete": true,
			"observer_physics_state_modified": false,
		}
	var push_arm := arm_id == RecoveryScript.PUSH_ARM_ID
	return {
		"ok": true,
		"failure_code": "",
		"physical_wave_gait_walking_observed": true,
		"world_build_count": 1,
		"world_reset_count": 0,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 7,
		"body_count": 9,
		"limb_count": 4,
		"fixture_spec_sha256": RecoveryScript.FIXTURE_SPEC_SHA256,
		"sdk_material_profile_sha256": RecoveryScript.MATERIAL_PROFILE_SHA256,
		"direct_torso_force_command_count": 0,
		"direct_torso_impulse_command_count": 0,
		"direct_torso_velocity_command_count": 0,
		"direct_torso_transform_command_count": 0,
		"sdk_authority_enabled": true,
		"sdk_authority_scope": "post_settle_full",
		"sdk_authority_failure_code": "",
		"executed_ticks": step_count + 240,
		"sdk_adapter_start_tick": 240,
		"legacy_post_settle_actuation_application_count": 0,
		"legacy_evidence_actuation_application_count": 0,
		"terrain_shape_count": 1,
		"initial_perturbation": {"campaign_seed": campaign_seed, "synthetic": true},
		"environment_challenge_options": contract["challenge_options"],
		"environment_challenge_configuration_sha256": contract["challenge_configuration_sha256"],
		"external_push_application_count": 1 if push_arm else 0,
		"external_push_receipt": _push_receipt() if push_arm else {},
		"walking_gate_receipts": _all_walking_receipts(true),
		"sdk_authority_summary":
		{
			"ok": true,
			"actuation_authority": true,
			"controller_policy_id": RecoveryScript.SELECTED_POLICY_ID,
			"controller_profile_sha256": RecoveryScript.CONTROLLER_PROFILE_SHA256,
			"adapter_capability_sha256": RecoveryScript.ADAPTER_CAPABILITY_SHA256,
			"step_count": step_count,
			"validated_balanced_wave_command_count": step_count * 8,
			"native_actuation_application_count": step_count * 8,
			"mismatch_count": 0,
			"safe_no_actuation_count": 0,
			"native_safe_disable_application_count": 0,
		},
		"sdk_physical_trace":
		{
			"schema_version": "sporespore_sdk_physical_trace_v1",
			"enabled": true,
			"options": contract["trace_options"],
			"configuration_sha256": contract["trace_configuration_sha256"],
			"row_count": rows.size(),
			"failure_codes": [],
			"rows": rows,
			"observer_instrumentation_receipt": _instrumentation(step_count),
			"world_build_count": 1,
			"physical_acceptance_authority": false,
		},
	}


static func _instrumentation(step_count: int) -> Dictionary:
	return {
		"schema_version": RecoveryScript.OBSERVER_INSTRUMENTATION_SCHEMA,
		"trace_policy_id": RecoveryScript.TRACE_POLICY_ID,
		"trace_row_schema": RecoveryScript.TRACE_ROW_SCHEMA,
		"capture_buffer_preallocated": true,
		"capture_buffer_capacity": RecoveryScript.MAXIMUM_SDK_STEP_COUNT,
		"captured_row_count": step_count,
		"live_raw_before_capture_count": step_count,
		"live_raw_after_capture_count": step_count,
		"live_nested_row_materialization_count": 0,
		"live_trace_row_deep_duplicate_count": 0,
		"live_trace_json_or_hash_count": 0,
		"live_quaternion_projection_receipt_count": 0,
		"post_solver_materialized_row_count": step_count,
		"post_solver_projection_receipt_count": step_count,
		"trace_row_count": step_count,
		"captured_row_count_matches_trace_row_count": true,
		"post_solver_materialized_row_count_matches_trace_row_count": true,
		"post_solver_projection_receipt_count_matches_trace_row_count": true,
		"materialization_after_final_solver_step_declared_by_caller": true,
		"additional_solver_step_during_materialization_count": 0,
		"downsampled_row_count": 0,
		"missing_measurement_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _push_receipt() -> Dictionary:
	return {
		"schema_version": ScalarImpulseValidationScript.RECEIPT_SCHEMA,
		"profile_id": ScalarImpulseValidationScript.PROFILE_ID,
		"target_body_id": ScalarImpulseValidationScript.TARGET_BODY_ID,
		"application_method": ScalarImpulseValidationScript.APPLICATION_METHOD,
		"tick": 1140,
		"step_from_sdk_start": RecoveryScript.PUSH_MARKER_STEP,
		"impulse_task_n_s": [0.0, 0.0, 0.25],
		"impulse_world_n_s": [0.0, 0.0, 0.25],
		"application_count": 1,
		"controller_command": false,
		"effect_sampled": true,
		"observed_next_tick_velocity_delta_world_m_s": [0.0, 0.0, 1.0],
		"observed_next_tick_velocity_delta_magnitude_m_s": 1.0,
		"initial_task_frame_forward_axis_world_host_real": [1.0, 0.0, 0.0],
		"initial_task_frame_lateral_axis_world_host_real": [0.0, 0.0, 1.0],
		"impulse_composition_numeric_precision":
		ScalarImpulseValidationScript.IMPULSE_COMPOSITION_NUMERIC_PRECISION,
	}


static func _all_contacts(value: bool) -> Dictionary:
	return {
		"front_left": value,
		"front_right": value,
		"rear_left": value,
		"rear_right": value,
	}


static func _all_walking_receipts(value: bool) -> Dictionary:
	var receipts := {}
	for key_value in RecoveryScript.EXPECTED_WALKING_RECEIPT_KEYS:
		receipts[String(key_value)] = value
	return receipts


static func _cell_ids_for_role(role: String) -> Array:
	var seeds := (
		RecoveryScript.DEVELOPMENT_GHOST_SEEDS
		if role == "development_route_ghost"
		else RecoveryScript.HELD_OUT_SEEDS
	)
	var cells: Array = []
	for seed in seeds:
		for arm in RecoveryScript.ARM_ORDER:
			cells.append(RecoveryScript.cell_id(String(arm), int(seed)))
	return cells


static func _campaign_id(role: String) -> String:
	return (
		RecoveryScript.DEVELOPMENT_GHOST_CAMPAIGN_ID
		if role == "development_route_ghost"
		else RecoveryScript.OFFICIAL_CAMPAIGN_ID
	)


static func _question_class(role: String) -> String:
	return "development" if role == "development_route_ghost" else "finite decision"


static func _ledger_scope(role: String, authority_mode: String) -> Dictionary:
	return {
		"subsystem": "recovery",
		"engine_scope": "godot_jolt",
		"authority_mode": authority_mode,
		"question_class": _question_class(role),
	}


static func _valid_positive_world(value: Dictionary) -> bool:
	return (
		bool(value.get("ok", false))
		and bool(value.get("outcome_complete", false))
		and bool(value.get("evidence_valid", false))
		and bool(value.get("behavior_passed", false))
		and int(value.get("evaluation_world_build_count", -1)) == 0
		and not bool(value.get("physical_acceptance_authority", true))
	)


static func _valid_positive_pair(value: Dictionary) -> bool:
	return _valid_positive_world(value) and bool(value.get("native_effect_confirmed", false))


static func _valid_finite_negative_world(value: Dictionary) -> bool:
	return (
		bool(value.get("ok", false))
		and bool(value.get("outcome_complete", false))
		and bool(value.get("evidence_valid", false))
		and not bool(value.get("behavior_passed", true))
		and int(value.get("evaluation_world_build_count", -1)) == 0
		and not bool(value.get("physical_acceptance_authority", true))
	)


static func _refusal(control_id: String, result: Dictionary, expected_code: String) -> Dictionary:
	return {
		"control_id": control_id,
		"expected_failure_code": expected_code,
		"observed_failure_code": String(result.get("failure_code", "")),
		"passed":
		(
			not bool(result.get("ok", true))
			and String(result.get("failure_code", "")) == expected_code
			and int(result.get("world_build_count", 0)) == 0
			and not bool(result.get("physical_acceptance_authority", true))
		),
	}


static func _zero_world_success(result: Dictionary) -> bool:
	return (
		bool(result.get("ok", false))
		and int(result.get("world_build_count", -1)) == 0
		and int(result.get("solver_step_count", -1)) == 0
		and not bool(result.get("physical_acceptance_authority", true))
	)


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10e_source_zero_world_failure_v1",
		"gate_id": RecoveryScript.GATE_ID,
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_source_and_evaluator_refusal",
			"question_class": "development",
		},
		"ok": false,
		"failure_code": code,
		"detail": detail,
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
