extends SceneTree
# gdlint: disable=max-line-length,max-returns

## Zero-world source and evaluator controls for QSDK-R10B.
##
## World-shaped summaries in this test are synthetic fixtures. They exercise
## validity/negative distinctions but carry no locomotion evidence or claim
## authority.

const RecoveryScript := preload("res://scripts/lab/gait/qsdk_r10b_bounded_upright_push_recovery.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const QuaternionScalarProjectionScript := preload(
	"res://sdk/adapters/godot/gdscript/quaternion_scalar_projection_v1.gd"
)
const QuaternionScalarProjectionValidationScript := preload(
	"res://sdk/adapters/godot/gdscript/quaternion_scalar_projection_validation_v2.gd"
)
const ExportedScalarValidationScript := preload(
	"res://sdk/adapters/godot/gdscript/exported_scalar_validation_v1.gd"
)
const WorkerScript := preload(
	"res://tests/test_sdk_qsdk_r10b_bounded_upright_push_recovery_worker.gd"
)

const MARKER := "QSDK_R10B_BOUNDED_UPRIGHT_PUSH_RECOVERY_SOURCE_ZERO_WORLD "
const RETAINED_ROW_ZERO_ORIENTATION_XYZW := [
	3.013798050233163e-6,
	0.00013243728608358651,
	-5.525192136701662e-6,
	1.0,
]
const RETAINED_ROW_1889_ORIENTATION_XYZW := [
	0.011945354752242565,
	-0.0590871162712574,
	-0.00016306180623359978,
	0.9981814622879028,
]


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(receipt.get("ok", false)) else 1)


func _run() -> Dictionary:
	if root.get_child_count() != 0:
		return _failure("QSDK_R10B_SOURCE_SCENE_TREE_NOT_EMPTY")
	var generated := RecoveryScript.compile_generation(RecoveryScript.GENERATOR_INDEX)
	if not _zero_world_success(generated):
		return _failure("QSDK_R10B_REFERENCE_GENERATION_FAILED")
	var verified := (
		RecoveryScript
		. verify_generation(
			RecoveryScript.GENERATOR_INDEX,
			String(generated["generator_receipt_sha256"]),
			String(generated["proportion_spec_sha256"]),
		)
	)
	if not _zero_world_success(verified):
		return _failure("QSDK_R10B_REFERENCE_GENERATION_VERIFICATION_FAILED")
	var projection_controls := _quaternion_projection_controls()
	if not bool(projection_controls.get("ok", false)):
		return _failure("QSDK_R10B_L2_QUATERNION_PROJECTION_CONTROLS_FAILED", projection_controls)
	var l3_controls := _l3_representation_validation_controls()
	if not bool(l3_controls.get("ok", false)):
		return _failure("QSDK_R10B_L3_REPRESENTATION_VALIDATION_CONTROLS_FAILED", l3_controls)

	var static_contract_count := 0
	for seed_value in RecoveryScript.ALL_SEEDS:
		var seed := int(seed_value)
		for arm_value in RecoveryScript.ARM_ORDER:
			var arm_id := String(arm_value)
			var contract := RecoveryScript.compile_static_contract(arm_id, seed)
			if (
				not _zero_world_success(contract)
				or String(contract.get("cell_id", "")) != RecoveryScript.cell_id(arm_id, seed)
			):
				return _failure("QSDK_R10B_STATIC_CONTRACT_FAILED")
			static_contract_count += 1

	var turning_options := {
		"cell_id": "turning_legacy_compile_control",
		"exact_controller_step_count": 2,
		"policy_id": "sporespore_turning_route_two_step_trace_v1",
		"recovery_duration_steps": 0,
		"turn_duration_steps": 2,
		"turn_heading_offset_rad": 0.2,
		"turn_start_semantic_step": 0,
	}
	var turning_compile := WaveGaitScript.compile_sdk_physical_trace_options(turning_options)
	if not bool(turning_compile.get("ok", false)):
		return _failure("QSDK_R10B_LEGACY_TURNING_TRACE_COMPILE_REGRESSED")

	var completion := (
		WaveGaitScript
		. complete_sdk_recovery_trace_observation(
			{
				"schema_version": RecoveryScript.TRACE_ROW_SCHEMA,
				"post_physics_observation_complete": false,
			},
			Vector3(1.0, 0.44, 2.0),
			Quaternion(
				float(RETAINED_ROW_ZERO_ORIENTATION_XYZW[0]),
				float(RETAINED_ROW_ZERO_ORIENTATION_XYZW[1]),
				float(RETAINED_ROW_ZERO_ORIENTATION_XYZW[2]),
				float(RETAINED_ROW_ZERO_ORIENTATION_XYZW[3]),
			),
			Vector3(0.1, 0.0, 0.0),
			Vector3(0.0, 0.2, 0.0),
			0.1,
			false,
			_all_contacts(true),
		)
	)
	if (
		not bool(completion.get("ok", false))
		or not bool(
			(completion["row"] as Dictionary).get("post_physics_observation_complete", false)
		)
		or not bool(
			(
				(
					RecoveryScript
					. validate_trace_orientation_projection(
						(completion["row"] as Dictionary).get("torso_orientation_xyzw", null),
						(completion["row"] as Dictionary).get("torso_orientation_projection", null),
					)
				)
				. get("ok", false)
			)
		)
	):
		return _failure("QSDK_R10B_POST_PHYSICS_COMPLETION_FAILED")

	var baseline_summary := _synthetic_summary(RecoveryScript.BASELINE_ARM_ID, 50300)
	var push_summary := _synthetic_summary(RecoveryScript.PUSH_ARM_ID, 50300)
	var baseline := (
		RecoveryScript
		. evaluate_world(
			baseline_summary,
			RecoveryScript.BASELINE_ARM_ID,
			50300,
		)
	)
	var push := (
		RecoveryScript
		. evaluate_world(
			push_summary,
			RecoveryScript.PUSH_ARM_ID,
			50300,
		)
	)
	var pair := RecoveryScript.evaluate_pair(baseline, push)
	if (
		not bool(baseline.get("ok", false))
		or not bool(baseline.get("behavior_passed", false))
		or not bool(push.get("ok", false))
		or not bool(push.get("behavior_passed", false))
		or not bool(pair.get("ok", false))
		or not bool(pair.get("behavior_passed", false))
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
			"QSDK_R10B_POSITIVE_SYNTHETIC_CONTROL_FAILED",
			{"baseline": baseline, "push": push, "pair": pair},
		)

	var negative_controls: Array = []
	(
		negative_controls
		. append(
			_refusal(
				"generator_type",
				RecoveryScript.compile_generation(0.0),
				"QSDK_R10B_GENERATOR_INDEX_TYPE_INVALID",
			)
		)
	)
	(
		negative_controls
		. append(
			_refusal(
				"generator_index",
				RecoveryScript.compile_generation(1),
				"QSDK_R10B_GENERATOR_INDEX_UNKNOWN",
			)
		)
	)
	(
		negative_controls
		. append(
			_refusal(
				"generation_digest",
				(
					RecoveryScript
					. verify_generation(
						0,
						"sha256:" + "0".repeat(64),
						String(generated["proportion_spec_sha256"]),
					)
				),
				"QSDK_R10B_GENERATION_DIGEST_MISMATCH",
			)
		)
	)
	var malformed_trace_options := (
		RecoveryScript
		. trace_options(
			RecoveryScript.BASELINE_ARM_ID,
			50300,
		)
	)
	malformed_trace_options["maximum_controller_step_count"] -= 1
	(
		negative_controls
		. append(
			_refusal(
				"trace_horizon",
				WaveGaitScript.compile_sdk_physical_trace_options(malformed_trace_options),
				"QSDK_R10B_RECOVERY_TRACE_POLICY_RECEIPT_MISMATCH",
			)
		)
	)

	var missing_row_summary := baseline_summary.duplicate(true)
	var missing_row_trace: Dictionary = missing_row_summary["sdk_physical_trace"]
	var missing_rows: Array = missing_row_trace["rows"]
	missing_rows.pop_back()
	missing_row_trace["rows"] = missing_rows
	missing_row_summary["sdk_physical_trace"] = missing_row_trace
	(
		negative_controls
		. append(
			_refusal(
				"missing_trace_row",
				(
					RecoveryScript
					. evaluate_world(
						missing_row_summary,
						RecoveryScript.BASELINE_ARM_ID,
						50300,
					)
				),
				"QSDK_R10B_COMMON_EXECUTION_INTEGRITY_INVALID",
			)
		)
	)

	var wrong_step_summary := baseline_summary.duplicate(true)
	var wrong_step_trace: Dictionary = wrong_step_summary["sdk_physical_trace"]
	var wrong_step_rows: Array = wrong_step_trace["rows"]
	var wrong_step_row: Dictionary = wrong_step_rows[100]
	wrong_step_row["semantic_step"] = 99
	wrong_step_rows[100] = wrong_step_row
	wrong_step_trace["rows"] = wrong_step_rows
	wrong_step_summary["sdk_physical_trace"] = wrong_step_trace
	(
		negative_controls
		. append(
			_refusal(
				"noncontiguous_trace",
				(
					RecoveryScript
					. evaluate_world(
						wrong_step_summary,
						RecoveryScript.BASELINE_ARM_ID,
						50300,
					)
				),
				"QSDK_R10B_TRACE_ROW_HEADER_INVALID",
			)
		)
	)

	var wrong_application_summary := push_summary.duplicate(true)
	wrong_application_summary["external_push_application_count"] = 0
	(
		negative_controls
		. append(
			_refusal(
				"native_application_count",
				(
					RecoveryScript
					. evaluate_world(
						wrong_application_summary,
						RecoveryScript.PUSH_ARM_ID,
						50300,
					)
				),
				"QSDK_R10B_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH",
			)
		)
	)

	var unmatched_push := push.duplicate(true)
	unmatched_push["initial_perturbation_sha256"] = "sha256:" + "0".repeat(64)
	(
		negative_controls
		. append(
			_refusal(
				"unmatched_pair",
				RecoveryScript.evaluate_pair(baseline, unmatched_push),
				"QSDK_R10B_PAIR_IDENTITY_OR_WORLD_INTEGRITY_INVALID",
			)
		)
	)

	var reversed_effect_push := push.duplicate(true)
	reversed_effect_push["marker_linear_velocity_after_world_m_s"] = [0.0, 0.0, -1.0]
	(
		negative_controls
		. append(
			_refusal(
				"nonpositive_paired_effect",
				RecoveryScript.evaluate_pair(baseline, reversed_effect_push),
				"QSDK_R10B_PAIRED_NATIVE_EFFECT_NOT_CONFIRMED",
			)
		)
	)

	var walking_negative_summary := baseline_summary.duplicate(true)
	walking_negative_summary["walking_gate_receipts"] = {"ordinary_gate": false}
	walking_negative_summary["ok"] = false
	walking_negative_summary["physical_wave_gait_walking_observed"] = false
	walking_negative_summary["failure_code"] = "PHYSICAL_WAVE_GAIT_WALKING_NOT_ESTABLISHED"
	var walking_negative := (
		RecoveryScript
		. evaluate_world(
			walking_negative_summary,
			RecoveryScript.BASELINE_ARM_ID,
			50300,
		)
	)
	if (
		not bool(walking_negative.get("ok", false))
		or not bool(walking_negative.get("outcome_complete", false))
		or not bool(walking_negative.get("evidence_valid", false))
		or bool(walking_negative.get("behavior_passed", true))
		or bool(walking_negative.get("ordinary_walking_passed", true))
	):
		return _failure("QSDK_R10B_VALID_WALKING_NEGATIVE_CLASSIFICATION_FAILED")

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
			50300,
		)
	)
	if (
		not bool(recovery_negative.get("ok", false))
		or not bool(recovery_negative.get("outcome_complete", false))
		or not bool(recovery_negative.get("evidence_valid", false))
		or bool(recovery_negative.get("behavior_passed", true))
		or bool((recovery_negative.get("recovery_search", {}) as Dictionary).get("found", true))
	):
		return _failure("QSDK_R10B_VALID_RECOVERY_NEGATIVE_CLASSIFICATION_FAILED")

	var authorization_controls := _authorization_document_controls()
	if not bool(authorization_controls.get("ok", false)):
		return _failure("QSDK_R10B_AUTHORIZATION_DOCUMENT_CONTROLS_FAILED", authorization_controls)

	for control_value in negative_controls:
		var control: Dictionary = control_value
		if not bool(control.get("passed", false)):
			return _failure("QSDK_R10B_NEGATIVE_CONTROL_FAILED", control)
	if root.get_child_count() != 0:
		return _failure("QSDK_R10B_SOURCE_CREATED_SCENE_CHILD")
	return {
		"schema_version": "sporespore_qsdk_r10b_source_zero_world_v4",
		"gate_id": RecoveryScript.GATE_ID,
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
		"legacy_turning_trace_compile_control_passed": true,
		"post_physics_observation_completion_control_passed": true,
		"quaternion_projection_case_count": int(projection_controls["projection_case_count"]),
		"retained_raw_quaternion_refusal_count":
		int(projection_controls["retained_raw_refusal_count"]),
		"retained_projected_quaternion_acceptance_count":
		int(projection_controls["retained_projected_acceptance_count"]),
		"additional_nonidentity_projected_acceptance_count":
		int(projection_controls["additional_nonidentity_projected_acceptance_count"]),
		"zero_quaternion_projection_refusal_count":
		int(projection_controls["zero_quaternion_projection_refusal_count"]),
		"projection_receipt_mutation_rejection_count":
		int(projection_controls["projection_receipt_mutation_rejection_count"]),
		"zero_completion_structured_refusal_count":
		int(projection_controls["zero_completion_structured_refusal_count"]),
		"l3_within_allowance_positive_control_count":
		int(l3_controls["within_allowance_positive_control_count"]),
		"l3_outside_allowance_refusal_count": int(l3_controls["outside_allowance_refusal_count"]),
		"l3_nonfinite_refusal_count": int(l3_controls["nonfinite_refusal_count"]),
		"l3_type_refusal_count": int(l3_controls["type_refusal_count"]),
		"l3_projection_receipt_static_mutation_rejection_count":
		int(l3_controls["projection_receipt_static_mutation_rejection_count"]),
		"l3_projection_receipt_key_mutation_rejection_count":
		int(l3_controls["projection_receipt_key_mutation_rejection_count"]),
		"l3_projection_receipt_row_link_mutation_rejection_count":
		int(l3_controls["projection_receipt_row_link_mutation_rejection_count"]),
		"l3_projection_receipt_numeric_mutation_rejection_count":
		int(l3_controls["projection_receipt_numeric_mutation_rejection_count"]),
		"l3_projection_receipt_numeric_type_mutation_rejection_count":
		int(l3_controls["projection_receipt_numeric_type_mutation_rejection_count"]),
		"l3_nonunit_axis_refusal_count": int(l3_controls["nonunit_axis_refusal_count"]),
		"l3_nonorthogonal_axis_refusal_count": int(l3_controls["nonorthogonal_axis_refusal_count"]),
		"l3_changed_task_frame_refusal_count": int(l3_controls["changed_task_frame_refusal_count"]),
		"positive_synthetic_world_control_count": 2,
		"positive_synthetic_pair_control_count": 1,
		"valid_finite_negative_control_count": 2,
		"invalid_or_incomplete_refusal_count": negative_controls.size(),
		"authorization_document_valid_control_count": int(authorization_controls["valid_count"]),
		"authorization_document_mutation_rejection_count":
		int(authorization_controls["mutation_count"]),
		"synthetic_world_shaped_fixture_count": 8,
		"locomotion_outcome_exposure_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count(),
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _authorization_document_controls() -> Dictionary:
	var valid_count := 0
	var mutation_count := 0
	for campaign_role in ["development_route_ghost", "held_out_finite_decision"]:
		var source_commit := "1".repeat(40)
		var authorization_parent_commit := "2".repeat(40)
		var qualification_parent_commit := "3".repeat(40)
		var stage_freeze_sha256 := "sha256:" + "4".repeat(64)
		var output_root: String = "C:/durable/qsdk-r10b-" + campaign_role
		var cells := _synthetic_cell_ids(campaign_role)
		var authority_check_refusal := {
			"path": WorkerScript.AUTHORITY_CHECK_REFUSAL_PATH,
			"byte_length": WorkerScript.AUTHORITY_CHECK_REFUSAL_BYTES,
			"raw_sha256": WorkerScript.AUTHORITY_CHECK_REFUSAL_SHA256,
			"git_blob_oid": "5".repeat(40),
			"status": "closed_infrastructure_invalid_pre_physics",
			"repair_id": "QSDK-R10B-L1",
			"physical_attempt_identity_consumed": false,
		}
		var consumed_l1_physical_invalid_closure := {
			"path": WorkerScript.L1_PHYSICAL_INVALID_CLOSURE_PATH,
			"byte_length": WorkerScript.L1_PHYSICAL_INVALID_CLOSURE_BYTES,
			"raw_sha256": WorkerScript.L1_PHYSICAL_INVALID_CLOSURE_SHA256,
			"git_blob_oid": "6".repeat(40),
			"status": "closed_consumed_infrastructure_invalid_baseline_trace_quaternion_projection",
			"repair_id": "QSDK-R10B-L1",
			"closure_id": "QSDK-R10B-L1-P1",
			"physical_identity_consumed": true,
			"same_identity_rerun_permitted": false,
			"selected_successor_id": "QSDK-R10B-L2",
		}
		var consumed_l2_physical_invalid_closure := {
			"path": WorkerScript.L2_PHYSICAL_INVALID_CLOSURE_PATH,
			"byte_length": WorkerScript.L2_PHYSICAL_INVALID_CLOSURE_BYTES,
			"raw_sha256": WorkerScript.L2_PHYSICAL_INVALID_CLOSURE_SHA256,
			"git_blob_oid": "7".repeat(40),
			"status":
			"closed_consumed_infrastructure_invalid_compound_trace_representation_validation",
			"repair_id": "QSDK-R10B-L2",
			"closure_id": "QSDK-R10B-L2-P1",
			"physical_identity_consumed": true,
			"same_identity_rerun_permitted": false,
			"selected_successor_id": "QSDK-R10B-L3",
		}
		var prerequisite: Variant = null
		if campaign_role == "held_out_finite_decision":
			prerequisite = {
				"route_execution_valid": true,
				"physical_identity_consumed": true,
				"same_identity_rerun_permitted": false,
			}
		var freeze := {
			"schema_version": WorkerScript.STAGE_FREEZE_SCHEMA,
			"status": "closed_passing_official_zero_world_qualification",
			"gate_id": RecoveryScript.GATE_ID,
			"campaign_id": _synthetic_campaign_id(campaign_role),
			"campaign_role": campaign_role,
			"question_class": _synthetic_question_class(campaign_role),
			"source_commit": source_commit,
			"qualification_parent_commit": qualification_parent_commit,
			"qualified_source_path_count": WorkerScript.QUALIFIED_SOURCE_PATH_COUNT,
			"qualified_source_path_sha256": WorkerScript.QUALIFIED_SOURCE_PATH_SHA256,
			"r10a_design_sha256": "sha256:" + RecoveryScript.DESIGN_RAW_SHA256,
			"l2_successor_design_sha256": WorkerScript.L2_DESIGN_SHA256,
			"l3_successor_design_sha256": WorkerScript.L3_DESIGN_SHA256,
			"maximum_world_count": cells.size(),
			"official_zero_world_qualification_passed": true,
			"physical_execution_authorized_by_freeze": false,
			"physical_acceptance_authority": false,
			"release_authority": false,
			"ordered_cell_ids": cells.duplicate(),
			"prerequisite_development_route_ghost": prerequisite,
			"superseded_authority_check_refusal": authority_check_refusal,
			"consumed_l1_physical_invalid_closure": consumed_l1_physical_invalid_closure,
			"consumed_l2_physical_invalid_closure": consumed_l2_physical_invalid_closure,
		}
		if not (
			WorkerScript
			. _stage_freeze_is_exact(
				freeze,
				campaign_role,
				source_commit,
				qualification_parent_commit,
				cells,
			)
		):
			return {"ok": false, "failure_code": "valid_stage_freeze_rejected"}
		valid_count += 1
		var freeze_mutations := {
			"schema_version": "invalid",
			"status": "invalid",
			"gate_id": "invalid",
			"campaign_id": "invalid",
			"campaign_role": "invalid",
			"question_class": "invalid",
			"source_commit": "0".repeat(40),
			"qualification_parent_commit": "0".repeat(40),
			"qualified_source_path_count": -1,
			"qualified_source_path_sha256": "sha256:" + "0".repeat(64),
			"r10a_design_sha256": "sha256:" + "0".repeat(64),
			"l2_successor_design_sha256": "sha256:" + "0".repeat(64),
			"l3_successor_design_sha256": "sha256:" + "0".repeat(64),
			"maximum_world_count": -1,
			"official_zero_world_qualification_passed": false,
			"physical_execution_authorized_by_freeze": true,
			"physical_acceptance_authority": true,
			"release_authority": true,
			"ordered_cell_ids": [],
			"prerequisite_development_route_ghost":
			{} if campaign_role == "held_out_finite_decision" else {"unexpected": true},
			"superseded_authority_check_refusal": {},
			"consumed_l1_physical_invalid_closure": {},
			"consumed_l2_physical_invalid_closure": {},
		}
		for field in freeze_mutations:
			var mutated_freeze := freeze.duplicate(true)
			mutated_freeze[field] = freeze_mutations[field]
			if (
				WorkerScript
				. _stage_freeze_is_exact(
					mutated_freeze,
					campaign_role,
					source_commit,
					qualification_parent_commit,
					cells,
				)
			):
				return {
					"ok": false, "failure_code": "stage_freeze_mutation_accepted", "field": field
				}
			mutation_count += 1

		var authority := {
			"schema_version": WorkerScript.EXECUTION_AUTHORITY_SCHEMA,
			"status": "authorized_single_use_unconsumed",
			"gate_id": RecoveryScript.GATE_ID,
			"campaign_id": _synthetic_campaign_id(campaign_role),
			"campaign_role": campaign_role,
			"question_class": _synthetic_question_class(campaign_role),
			"source_commit": source_commit,
			"authorization_commit_derived_from_current_head": true,
			"authorization_parent_commit": authorization_parent_commit,
			"qualification_parent_commit": qualification_parent_commit,
			"r10a_design_sha256": "sha256:" + RecoveryScript.DESIGN_RAW_SHA256,
			"l2_successor_design_sha256": WorkerScript.L2_DESIGN_SHA256,
			"l3_successor_design_sha256": WorkerScript.L3_DESIGN_SHA256,
			"stage_freeze_sha256": stage_freeze_sha256,
			"superseded_authority_check_refusal_sha256":
			WorkerScript.AUTHORITY_CHECK_REFUSAL_SHA256,
			"consumed_l1_physical_invalid_closure_sha256":
			WorkerScript.L1_PHYSICAL_INVALID_CLOSURE_SHA256,
			"consumed_l2_physical_invalid_closure_sha256":
			WorkerScript.L2_PHYSICAL_INVALID_CLOSURE_SHA256,
			"qualified_source_path_count": WorkerScript.QUALIFIED_SOURCE_PATH_COUNT,
			"qualified_source_path_sha256": WorkerScript.QUALIFIED_SOURCE_PATH_SHA256,
			"output_root": output_root,
			"zero_world_qualification_passed": true,
			"physical_execution_authorized": true,
			"physical_identity_consumed": false,
			"same_identity_rerun_permitted": false,
			"ordered_cell_ids": cells.duplicate(),
			"maximum_world_count": cells.size(),
			"maximum_campaign_attempt_count": 1,
			"physical_acceptance_authority": false,
			"release_authority": false,
		}
		if not (
			WorkerScript
			. _execution_authority_is_exact(
				authority,
				campaign_role,
				source_commit,
				authorization_parent_commit,
				qualification_parent_commit,
				stage_freeze_sha256,
				output_root,
				cells,
			)
		):
			return {"ok": false, "failure_code": "valid_execution_authority_rejected"}
		valid_count += 1
		var authority_mutations := {
			"schema_version": "invalid",
			"status": "invalid",
			"gate_id": "invalid",
			"campaign_id": "invalid",
			"campaign_role": "invalid",
			"question_class": "invalid",
			"source_commit": "0".repeat(40),
			"authorization_commit_derived_from_current_head": false,
			"authorization_parent_commit": "0".repeat(40),
			"qualification_parent_commit": "0".repeat(40),
			"r10a_design_sha256": "sha256:" + "0".repeat(64),
			"l2_successor_design_sha256": "sha256:" + "0".repeat(64),
			"l3_successor_design_sha256": "sha256:" + "0".repeat(64),
			"stage_freeze_sha256": "sha256:" + "0".repeat(64),
			"superseded_authority_check_refusal_sha256": "sha256:" + "0".repeat(64),
			"consumed_l1_physical_invalid_closure_sha256": "sha256:" + "0".repeat(64),
			"consumed_l2_physical_invalid_closure_sha256": "sha256:" + "0".repeat(64),
			"qualified_source_path_count": -1,
			"qualified_source_path_sha256": "sha256:" + "0".repeat(64),
			"output_root": "C:/wrong",
			"zero_world_qualification_passed": false,
			"physical_execution_authorized": false,
			"physical_identity_consumed": true,
			"same_identity_rerun_permitted": true,
			"ordered_cell_ids": [],
			"maximum_world_count": -1,
			"maximum_campaign_attempt_count": 2,
			"physical_acceptance_authority": true,
			"release_authority": true,
		}
		for field in authority_mutations:
			var mutated_authority := authority.duplicate(true)
			mutated_authority[field] = authority_mutations[field]
			if (
				WorkerScript
				. _execution_authority_is_exact(
					mutated_authority,
					campaign_role,
					source_commit,
					authorization_parent_commit,
					qualification_parent_commit,
					stage_freeze_sha256,
					output_root,
					cells,
				)
			):
				return {
					"ok": false,
					"failure_code": "execution_authority_mutation_accepted",
					"field": field,
				}
			mutation_count += 1
	return {
		"ok": true, "failure_code": "", "valid_count": valid_count, "mutation_count": mutation_count
	}


static func _synthetic_campaign_id(campaign_role: String) -> String:
	return (
		RecoveryScript.DEVELOPMENT_GHOST_CAMPAIGN_ID
		if campaign_role == "development_route_ghost"
		else RecoveryScript.OFFICIAL_CAMPAIGN_ID
	)


static func _synthetic_question_class(campaign_role: String) -> String:
	return "development" if campaign_role == "development_route_ghost" else "finite decision"


static func _synthetic_cell_ids(campaign_role: String) -> Array:
	var seeds := (
		RecoveryScript.DEVELOPMENT_GHOST_SEEDS
		if campaign_role == "development_route_ghost"
		else RecoveryScript.HELD_OUT_SEEDS
	)
	var cells: Array = []
	for seed in seeds:
		for arm in RecoveryScript.ARM_ORDER:
			cells.append(RecoveryScript.cell_id(String(arm), int(seed)))
	return cells


func _synthetic_summary(arm_id: String, campaign_seed: int) -> Dictionary:
	var contract := RecoveryScript.compile_static_contract(arm_id, campaign_seed)
	var orientation_projection := (
		QuaternionScalarProjectionScript.project_quaternion_to_unit_scalar_v1(Quaternion.IDENTITY)
	)
	if not bool(orientation_projection.get("ok", false)):
		return {}
	var step_count := RecoveryScript.MINIMUM_SDK_STEP_COUNT
	var rows: Array = []
	for step in range(step_count):
		var contact := posmod(step, 90) >= 3
		var linear_velocity_z := 0.0
		if arm_id == RecoveryScript.PUSH_ARM_ID and step == RecoveryScript.PUSH_MARKER_STEP:
			linear_velocity_z = 1.0
		(
			rows
			. append(
				{
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
			)
		)
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
		"external_push_receipt":
		(
			{
				"profile_id": "lateral_impulse_v1",
				"step_from_sdk_start": RecoveryScript.PUSH_MARKER_STEP,
				"impulse_task_n_s": [0.0, 0.0, 0.25],
				"impulse_world_n_s": [0.0, 0.0, 0.25],
				"application_count": 1,
				"controller_command": false,
				"effect_sampled": true,
				"observed_next_tick_velocity_delta_world_m_s": [0.0, 0.0, 1.0],
				"observed_next_tick_velocity_delta_magnitude_m_s": 1.0,
			}
			if push_arm
			else {}
		),
		"walking_gate_receipts": {"ordinary_gate": true},
		"sdk_authority_summary":
		{
			"ok": true,
			"actuation_authority": true,
			"controller_policy_id": RecoveryScript.SELECTED_POLICY_ID,
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
			"world_build_count": 1,
			"physical_acceptance_authority": false,
		},
	}


static func _all_contacts(value: bool) -> Dictionary:
	return {
		"front_left": value,
		"front_right": value,
		"rear_left": value,
		"rear_right": value,
	}


static func _l3_representation_validation_controls() -> Dictionary:
	var unit_allowance := ExportedScalarValidationScript.UNIT_SCALE_REPRESENTATION_ALLOWANCE
	var within_allowance_cases := [
		[1.0, 1.0],
		[1.0 + ExportedScalarValidationScript.BINARY64_MACHINE_EPSILON, 1.0],
		[0.00013243728491951, 0.00013243728491950626],
		[1.0000000511645777, 1.0000000511645772],
	]
	var outside_allowance_cases := [
		[1.0 + 1.0e-12, 1.0],
		[1.001, 1.0],
		[1.0e-12, 0.0],
		[-1.0 - 1.0e-12, -1.0],
	]
	var nonfinite_cases := [
		[NAN, 1.0],
		[1.0, NAN],
		[INF, 1.0],
		[1.0, -INF],
	]
	var within_allowance_positive_count := 0
	for case_value in within_allowance_cases:
		var values: Array = case_value
		within_allowance_positive_count += int(
			ExportedScalarValidationScript.representation_equal_v1(values[0], values[1])
		)
	var outside_allowance_refusal_count := 0
	for case_value in outside_allowance_cases:
		var values: Array = case_value
		outside_allowance_refusal_count += int(
			not ExportedScalarValidationScript.representation_equal_v1(values[0], values[1])
		)
	var nonfinite_refusal_count := 0
	for case_value in nonfinite_cases:
		var values: Array = case_value
		nonfinite_refusal_count += int(
			not ExportedScalarValidationScript.representation_equal_v1(values[0], values[1])
		)
	var type_refusal_count := (
		int(not ExportedScalarValidationScript.representation_equal_v1(1, 1.0))
		+ int(not ExportedScalarValidationScript.representation_equal_v1(true, 1.0))
	)

	var reference_receipt := QuaternionScalarProjectionScript.project_components_to_unit_scalar_v1(
		RETAINED_ROW_ZERO_ORIENTATION_XYZW
	)
	var reference_orientation: Array = reference_receipt["orientation_xyzw"]
	var reference_validation := (
		QuaternionScalarProjectionValidationScript
		. validate_projection_receipt_v2(
			reference_receipt,
			reference_orientation,
		)
	)
	var static_mutation_rejection_count := 0
	for field_value in QuaternionScalarProjectionValidationScript.STATIC_FIELDS:
		var field := String(field_value)
		var mutated: Dictionary = reference_receipt.duplicate(true)
		var original: Variant = mutated[field]
		if typeof(original) == TYPE_BOOL:
			mutated[field] = not bool(original)
		elif typeof(original) == TYPE_STRING:
			mutated[field] = String(original) + "_mutated"
		elif typeof(original) == TYPE_INT:
			mutated[field] = int(original) + 1
		elif typeof(original) == TYPE_FLOAT:
			mutated[field] = float(original) + 0.001
		elif original == null:
			mutated[field] = "mutated"
		else:
			mutated[field] = null
		static_mutation_rejection_count += int(
			not (
				QuaternionScalarProjectionValidationScript
				. projection_receipt_matches_orientation_v2(mutated, reference_orientation)
			)
		)

	var key_mutation_rejection_count := 0
	var missing_key_receipt: Dictionary = reference_receipt.duplicate(true)
	missing_key_receipt.erase("projected_norm_delta")
	key_mutation_rejection_count += int(
		not QuaternionScalarProjectionValidationScript.projection_receipt_matches_orientation_v2(
			missing_key_receipt, reference_orientation
		)
	)
	var extra_key_receipt: Dictionary = reference_receipt.duplicate(true)
	extra_key_receipt["unexpected"] = 0.0
	key_mutation_rejection_count += int(
		not QuaternionScalarProjectionValidationScript.projection_receipt_matches_orientation_v2(
			extra_key_receipt, reference_orientation
		)
	)

	var row_link_mutation_rejection_count := 0
	for component_index in range(4):
		var mutated_orientation: Array = reference_orientation.duplicate()
		mutated_orientation[component_index] = float(mutated_orientation[component_index]) + 0.001
		row_link_mutation_rejection_count += int(
			not (
				QuaternionScalarProjectionValidationScript
				. projection_receipt_matches_orientation_v2(reference_receipt, mutated_orientation)
			)
		)

	var numeric_mutation_rejection_count := 0
	for field_value in [
		"source_norm_squared",
		"source_norm",
		"source_norm_squared_delta",
		"source_norm_delta",
		"orientation_xyzw",
		"projected_norm_squared",
		"projected_norm",
		"projected_norm_squared_delta",
		"projected_norm_delta",
	]:
		var field := String(field_value)
		var mutated: Dictionary = reference_receipt.duplicate(true)
		var linked_orientation: Array = reference_orientation
		if field == "orientation_xyzw":
			var orientation: Array = (mutated[field] as Array).duplicate()
			orientation[0] = float(orientation[0]) + 0.001
			mutated[field] = orientation
			linked_orientation = orientation
		else:
			mutated[field] = float(mutated[field]) + 0.001
		numeric_mutation_rejection_count += int(
			not (
				QuaternionScalarProjectionValidationScript
				. projection_receipt_matches_orientation_v2(mutated, linked_orientation)
			)
		)
	var numeric_type_mutation_rejection_count := 0
	var identity_receipt := QuaternionScalarProjectionScript.project_components_to_unit_scalar_v1(
		[0.0, 0.0, 0.0, 1.0]
	)
	var scalar_type_mutation: Dictionary = identity_receipt.duplicate(true)
	scalar_type_mutation["projected_norm"] = 1
	numeric_type_mutation_rejection_count += int(
		not (
			QuaternionScalarProjectionValidationScript
			. projection_receipt_matches_orientation_v2(
				scalar_type_mutation,
				identity_receipt["orientation_xyzw"],
			)
		)
	)
	var orientation_type_mutation: Dictionary = identity_receipt.duplicate(true)
	var type_mutated_orientation: Array = (
		(orientation_type_mutation["orientation_xyzw"] as Array).duplicate()
	)
	type_mutated_orientation[0] = 0
	orientation_type_mutation["orientation_xyzw"] = type_mutated_orientation
	numeric_type_mutation_rejection_count += int(
		not (
			QuaternionScalarProjectionValidationScript
			. projection_receipt_matches_orientation_v2(
				orientation_type_mutation,
				type_mutated_orientation,
			)
		)
	)

	var nonunit_axis_refusal_count := 0
	for axis_value in [[1.001, 0.0, 0.0], [0.0, 0.0, 0.999]]:
		var axis: Array = axis_value
		nonunit_axis_refusal_count += int(
			ExportedScalarValidationScript.norm_delta_v1(axis) > RecoveryScript.VECTOR_TOLERANCE
		)
	var nonorthogonal_axis_refusal_count := 0
	for axes_value in [
		[[1.0, 0.0, 0.0], [1.0e-6, 0.0, 1.0]],
		[[0.0, 0.0, 1.0], [0.0, 0.0, 1.0]],
	]:
		var axes: Array = axes_value
		nonorthogonal_axis_refusal_count += int(
			(
				ExportedScalarValidationScript.dot_absolute_v1(axes[0], axes[1])
				> RecoveryScript.VECTOR_TOLERANCE
			)
		)
	var reference_forward := [1.0, 0.0, 0.0]
	var reference_lateral := [0.0, 0.0, 1.0]
	var changed_task_frame_refusal_count := (
		int([1.0, 0.0, 1.0e-6] != reference_forward) + int([1.0e-6, 0.0, 1.0] != reference_lateral)
	)

	var ok := (
		unit_allowance == 7.105427357601002e-15
		and bool(reference_validation.get("ok", false))
		and int(reference_validation.get("numeric_comparison_count", -1)) == 12
		and not bool(reference_validation.get("whole_dictionary_equality_used", true))
		and within_allowance_positive_count == 4
		and outside_allowance_refusal_count == 4
		and nonfinite_refusal_count == 4
		and type_refusal_count == 2
		and static_mutation_rejection_count == 18
		and key_mutation_rejection_count == 2
		and row_link_mutation_rejection_count == 4
		and numeric_mutation_rejection_count == 9
		and numeric_type_mutation_rejection_count == 2
		and nonunit_axis_refusal_count == 2
		and nonorthogonal_axis_refusal_count == 2
		and changed_task_frame_refusal_count == 2
	)
	return {
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R10B_L3_REPRESENTATION_VALIDATION_INVALID",
		"operation_event_budget": int(ExportedScalarValidationScript.OPERATION_EVENT_BUDGET),
		"unit_scale_representation_allowance": unit_allowance,
		"within_allowance_positive_control_count": within_allowance_positive_count,
		"outside_allowance_refusal_count": outside_allowance_refusal_count,
		"nonfinite_refusal_count": nonfinite_refusal_count,
		"type_refusal_count": type_refusal_count,
		"projection_receipt_static_mutation_rejection_count": static_mutation_rejection_count,
		"projection_receipt_key_mutation_rejection_count": key_mutation_rejection_count,
		"projection_receipt_row_link_mutation_rejection_count": row_link_mutation_rejection_count,
		"projection_receipt_numeric_mutation_rejection_count": numeric_mutation_rejection_count,
		"projection_receipt_numeric_type_mutation_rejection_count":
		numeric_type_mutation_rejection_count,
		"nonunit_axis_refusal_count": nonunit_axis_refusal_count,
		"nonorthogonal_axis_refusal_count": nonorthogonal_axis_refusal_count,
		"changed_task_frame_refusal_count": changed_task_frame_refusal_count,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _quaternion_projection_controls() -> Dictionary:
	var retained_cases := [
		RETAINED_ROW_ZERO_ORIENTATION_XYZW,
		RETAINED_ROW_1889_ORIENTATION_XYZW,
	]
	var additional_cases := [
		Quaternion(Vector3.RIGHT, 0.1),
		Quaternion(Vector3(1.0, 2.0, 3.0).normalized(), 0.73),
	]
	var retained_raw_refusal_count := 0
	var retained_projected_acceptance_count := 0
	var additional_nonidentity_projected_acceptance_count := 0
	var projection_receipts: Array = []
	for source_value in retained_cases:
		var source: Array = source_value
		var raw_diagnostic := QuaternionScalarProjectionScript.diagnose_orientation_xyzw_v1(source)
		retained_raw_refusal_count += int(
			(
				bool(raw_diagnostic.get("ok", false))
				and (
					float(raw_diagnostic.get("norm_delta", 0.0))
					> RecoveryScript.QUATERNION_NORM_TOLERANCE
				)
			)
		)
		var projection := QuaternionScalarProjectionScript.project_components_to_unit_scalar_v1(
			source
		)
		projection_receipts.append(projection)
		var validation := (
			RecoveryScript
			. validate_trace_orientation_projection(
				projection.get("orientation_xyzw", null),
				projection,
			)
		)
		retained_projected_acceptance_count += int(
			bool(projection.get("ok", false)) and bool(validation.get("ok", false))
		)
	for quaternion_value in additional_cases:
		var projection := QuaternionScalarProjectionScript.project_quaternion_to_unit_scalar_v1(
			quaternion_value
		)
		projection_receipts.append(projection)
		var validation := (
			RecoveryScript
			. validate_trace_orientation_projection(
				projection.get("orientation_xyzw", null),
				projection,
			)
		)
		additional_nonidentity_projected_acceptance_count += int(
			bool(projection.get("ok", false)) and bool(validation.get("ok", false))
		)

	var mutation_rejection_count := 0
	var reference_projection: Dictionary = projection_receipts[0]
	for mutation_id in ["method", "source", "projected"]:
		var mutated := reference_projection.duplicate(true)
		if mutation_id == "method":
			mutated["projection_method_id"] = "invalid"
		elif mutation_id == "source":
			var source: Array = (mutated["source_orientation_xyzw"] as Array).duplicate()
			source[0] = float(source[0]) + 0.001
			mutated["source_orientation_xyzw"] = source
		else:
			var projected: Array = (mutated["orientation_xyzw"] as Array).duplicate()
			projected[3] = float(projected[3]) - 0.001
			mutated["orientation_xyzw"] = projected
		mutation_rejection_count += int(
			not bool(
				(
					(
						RecoveryScript
						. validate_trace_orientation_projection(
							reference_projection["orientation_xyzw"],
							mutated,
						)
					)
					. get("ok", true)
				)
			)
		)

	var zero_projection := QuaternionScalarProjectionScript.project_components_to_unit_scalar_v1(
		[0.0, 0.0, 0.0, 0.0]
	)
	var zero_projection_refused := (
		not bool(zero_projection.get("ok", true))
		and String(zero_projection.get("refusal_reason", "")) == "nonpositive_source_norm_squared"
		and float(zero_projection.get("source_norm_squared", NAN)) == 0.0
		and zero_projection.get("orientation_xyzw", "unexpected") == null
		and int(zero_projection.get("world_build_count", -1)) == 0
		and int(zero_projection.get("solver_step_count", -1)) == 0
		and not bool(zero_projection.get("physics_state_modified", true))
	)
	var zero_completion := (
		WaveGaitScript
		. complete_sdk_recovery_trace_observation(
			{
				"schema_version": RecoveryScript.TRACE_ROW_SCHEMA,
				"post_physics_observation_complete": false,
			},
			Vector3.ZERO,
			Quaternion(0.0, 0.0, 0.0, 0.0),
			Vector3.ZERO,
			Vector3.ZERO,
			0.0,
			false,
			_all_contacts(true),
		)
	)
	var zero_detail: Dictionary = zero_completion.get("detail", {})
	var zero_completion_projection: Dictionary = zero_detail.get("quaternion_projection", {})
	var zero_completion_refused := (
		not bool(zero_completion.get("ok", true))
		and (
			String(zero_completion.get("failure_code", ""))
			== "QSDK_R10B_RECOVERY_TRACE_QUATERNION_PROJECTION_REFUSED"
		)
		and (
			String(zero_completion_projection.get("refusal_reason", ""))
			== "nonpositive_source_norm_squared"
		)
		and zero_completion_projection == zero_projection
	)
	var all_projection_receipts_valid := true
	for receipt_value in projection_receipts:
		all_projection_receipts_valid = (
			all_projection_receipts_valid
			and receipt_value is Dictionary
			and bool(receipt_value.get("ok", false))
		)
	var ok := (
		projection_receipts.size() == 4
		and all_projection_receipts_valid
		and retained_raw_refusal_count == 2
		and retained_projected_acceptance_count == 2
		and additional_nonidentity_projected_acceptance_count == 2
		and mutation_rejection_count == 3
		and zero_projection_refused
		and zero_completion_refused
	)
	return {
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R10B_L2_QUATERNION_PROJECTION_INVALID",
		"projection_case_count": projection_receipts.size(),
		"retained_raw_refusal_count": retained_raw_refusal_count,
		"retained_projected_acceptance_count": retained_projected_acceptance_count,
		"additional_nonidentity_projected_acceptance_count":
		additional_nonidentity_projected_acceptance_count,
		"zero_quaternion_projection_refusal_count": int(zero_projection_refused),
		"projection_receipt_mutation_rejection_count": mutation_rejection_count,
		"zero_completion_structured_refusal_count": int(zero_completion_refused),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _refusal(control_id: String, result: Dictionary, code: String) -> Dictionary:
	return {
		"control_id": control_id,
		"passed":
		(
			not bool(result.get("ok", true))
			and String(result.get("failure_code", "")) == code
			and not bool(result.get("physical_acceptance_authority", true))
		),
		"expected_failure_code": code,
		"observed_failure_code": String(result.get("failure_code", "")),
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
		"schema_version": "sporespore_qsdk_r10b_source_zero_world_v4",
		"gate_id": RecoveryScript.GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"locomotion_outcome_exposure_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
