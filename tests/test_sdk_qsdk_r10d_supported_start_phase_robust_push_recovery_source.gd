extends SceneTree
# gdlint: disable=max-line-length,max-returns

## Zero-world source and evaluator controls for QSDK-R10D.
##
## World-shaped summaries in this test are synthetic fixtures. They exercise
## validity/negative distinctions but carry no locomotion evidence or claim
## authority.

const RecoveryScript := preload(
	"res://scripts/lab/gait/qsdk_r10d_supported_start_phase_robust_push_recovery.gd"
)
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
	"res://tests/test_sdk_qsdk_r10d_supported_start_phase_robust_push_recovery_worker.gd"
)

const MARKER := "QSDK_R10D_SUPPORTED_START_PHASE_ROBUST_PUSH_RECOVERY_SOURCE_ZERO_WORLD "
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
		return _failure("QSDK_R10D_SOURCE_SCENE_TREE_NOT_EMPTY")
	var generated := RecoveryScript.compile_generation(RecoveryScript.GENERATOR_INDEX)
	if not _zero_world_success(generated):
		return _failure("QSDK_R10D_SUPPORTED_GENERATION_FAILED", generated)
	var verified := (
		RecoveryScript
		. verify_generation(
			RecoveryScript.GENERATOR_INDEX,
			String(generated["generator_receipt_sha256"]),
			String(generated["proportion_spec_sha256"]),
		)
	)
	if not _zero_world_success(verified):
		return _failure("QSDK_R10D_SUPPORTED_GENERATION_VERIFICATION_FAILED")
	var definition_controls := _successor_definition_controls(generated)
	if not bool(definition_controls.get("ok", false)):
		return _failure("QSDK_R10D_SUCCESSOR_DEFINITION_CONTROLS_FAILED", definition_controls)
	var projection_controls := _quaternion_projection_controls()
	if not bool(projection_controls.get("ok", false)):
		return _failure("QSDK_R10D_L2_QUATERNION_PROJECTION_CONTROLS_FAILED", projection_controls)
	var l3_controls := _l3_representation_validation_controls()
	if not bool(l3_controls.get("ok", false)):
		return _failure("QSDK_R10D_L3_REPRESENTATION_VALIDATION_CONTROLS_FAILED", l3_controls)

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
				return _failure("QSDK_R10D_STATIC_CONTRACT_FAILED")
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
		return _failure("QSDK_R10D_LEGACY_TURNING_TRACE_COMPILE_REGRESSED")

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
		return _failure("QSDK_R10D_POST_PHYSICS_COMPLETION_FAILED")

	var baseline_summary := _synthetic_summary(RecoveryScript.BASELINE_ARM_ID, 40001)
	var push_summary := _synthetic_summary(RecoveryScript.PUSH_ARM_ID, 40001)
	var baseline := (
		RecoveryScript
		. evaluate_world(
			baseline_summary,
			RecoveryScript.BASELINE_ARM_ID,
			40001,
		)
	)
	var window_controls := _window_contract_controls(baseline_summary)
	if not bool(window_controls.get("ok", false)):
		return _failure("QSDK_R10D_WINDOW_CONTRACT_CONTROLS_FAILED", window_controls)
	var push := (
		RecoveryScript
		. evaluate_world(
			push_summary,
			RecoveryScript.PUSH_ARM_ID,
			40001,
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
			"QSDK_R10D_POSITIVE_SYNTHETIC_CONTROL_FAILED",
			{"baseline": baseline, "push": push, "pair": pair},
		)

	var negative_controls: Array = []
	(
		negative_controls
		. append(
			_refusal(
				"generator_type",
				RecoveryScript.compile_generation(0.0),
				"QSDK_R10D_GENERATOR_INDEX_TYPE_INVALID",
			)
		)
	)
	negative_controls.append_array(_application_receipt_mutation_controls(push_summary))
	var weak_effect_summary := push_summary.duplicate(false)
	var weak_effect_receipt: Dictionary = (
		(push_summary["external_push_receipt"] as Dictionary).duplicate(true)
	)
	weak_effect_receipt["observed_next_tick_velocity_delta_world_m_s"] = [0.0, 0.0, 0.00005]
	weak_effect_receipt["observed_next_tick_velocity_delta_magnitude_m_s"] = 0.00005
	weak_effect_summary["external_push_receipt"] = weak_effect_receipt
	var weak_effect_world := (
		RecoveryScript
		. evaluate_world(
			weak_effect_summary,
			RecoveryScript.PUSH_ARM_ID,
			40001,
		)
	)
	(
		negative_controls
		. append(
			_refusal(
				"native_effect_floor",
				RecoveryScript.evaluate_pair(baseline, weak_effect_world),
				"QSDK_R10D_PAIRED_NATIVE_EFFECT_NOT_CONFIRMED",
			)
		)
	)
	(
		negative_controls
		. append(
			_refusal(
				"invalid_static_contract_seed",
				RecoveryScript.compile_static_contract(RecoveryScript.BASELINE_ARM_ID, 50301),
				"QSDK_R10D_CELL_IDENTITY_INVALID",
			)
		)
	)
	(
		negative_controls
		. append(
			_refusal(
				"invalid_static_contract_arm",
				RecoveryScript.compile_static_contract("unknown_arm", 40001),
				"QSDK_R10D_CELL_IDENTITY_INVALID",
			)
		)
	)
	(
		negative_controls
		. append(
			_refusal(
				"generator_index",
				RecoveryScript.compile_generation(1),
				"QSDK_R10D_GENERATOR_INDEX_UNKNOWN",
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
						RecoveryScript.GENERATOR_INDEX,
						"sha256:" + "0".repeat(64),
						String(generated["proportion_spec_sha256"]),
					)
				),
				"QSDK_R10D_GENERATION_DIGEST_MISMATCH",
			)
		)
	)
	var malformed_trace_options := (
		RecoveryScript
		. trace_options(
			RecoveryScript.BASELINE_ARM_ID,
			40001,
		)
	)
	malformed_trace_options["maximum_controller_step_count"] -= 1
	(
		negative_controls
		. append(
			_refusal(
				"trace_horizon",
				WaveGaitScript.compile_sdk_physical_trace_options(malformed_trace_options),
				"QSDK_R10D_RECOVERY_TRACE_POLICY_RECEIPT_MISMATCH",
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
						40001,
					)
				),
				"QSDK_R10D_COMMON_EXECUTION_INTEGRITY_INVALID",
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
						40001,
					)
				),
				"QSDK_R10D_TRACE_ROW_HEADER_INVALID",
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
						40001,
					)
				),
				"QSDK_R10D_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH",
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
				"QSDK_R10D_PAIR_IDENTITY_OR_WORLD_INTEGRITY_INVALID",
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
				"QSDK_R10D_PAIRED_NATIVE_EFFECT_NOT_CONFIRMED",
			)
		)
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
			40001,
		)
	)
	if (
		not bool(walking_negative.get("ok", false))
		or not bool(walking_negative.get("outcome_complete", false))
		or not bool(walking_negative.get("evidence_valid", false))
		or bool(walking_negative.get("behavior_passed", true))
		or bool(walking_negative.get("ordinary_walking_passed", true))
	):
		return _failure("QSDK_R10D_VALID_WALKING_NEGATIVE_CLASSIFICATION_FAILED")
	var incomplete_walking_summary := baseline_summary.duplicate(false)
	var incomplete_walking_receipts := _all_walking_receipts(true)
	incomplete_walking_receipts.erase("bounded_anchor_error")
	incomplete_walking_summary["walking_gate_receipts"] = incomplete_walking_receipts
	(
		negative_controls
		. append(
			_refusal(
				"incomplete_walking_receipt_set",
				(
					RecoveryScript
					. evaluate_world(
						incomplete_walking_summary,
						RecoveryScript.BASELINE_ARM_ID,
						40001,
					)
				),
				"QSDK_R10D_COMMON_EXECUTION_INTEGRITY_INVALID",
			)
		)
	)

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
			40001,
		)
	)
	var recovery_negative_search: Dictionary = recovery_negative.get("recovery_search", {})
	var recovery_negative_json := JSON.stringify(recovery_negative, "", true, true)
	var recovery_negative_round_trip: Variant = JSON.parse_string(recovery_negative_json)
	var recovery_negative_round_trip_search := {}
	if typeof(recovery_negative_round_trip) == TYPE_DICTIONARY:
		recovery_negative_round_trip_search = ((recovery_negative_round_trip as Dictionary).get(
			"recovery_search", {}
		))
	if (
		not bool(recovery_negative.get("ok", false))
		or not bool(recovery_negative.get("outcome_complete", false))
		or not bool(recovery_negative.get("evidence_valid", false))
		or bool(recovery_negative.get("behavior_passed", true))
		or bool(recovery_negative_search.get("found", true))
		or recovery_negative_search.get("reentry_latency_s", 0.0) != null
		or typeof(recovery_negative_round_trip) != TYPE_DICTIONARY
		or typeof(recovery_negative_round_trip_search) != TYPE_DICTIONARY
		or bool(recovery_negative_round_trip_search.get("found", true))
		or recovery_negative_round_trip_search.get("reentry_latency_s", 0.0) != null
	):
		return _failure("QSDK_R10D_VALID_RECOVERY_NEGATIVE_CLASSIFICATION_FAILED")

	var authorization_controls := _authorization_document_controls()
	if not bool(authorization_controls.get("ok", false)):
		return _failure("QSDK_R10D_AUTHORIZATION_DOCUMENT_CONTROLS_FAILED", authorization_controls)

	for control_value in negative_controls:
		var control: Dictionary = control_value
		if not bool(control.get("passed", false)):
			return _failure("QSDK_R10D_NEGATIVE_CONTROL_FAILED", control)
	if root.get_child_count() != 0:
		return _failure("QSDK_R10D_SOURCE_CREATED_SCENE_CHILD")
	return {
		"schema_version": "sporespore_qsdk_r10d_source_zero_world_v2",
		"gate_id": RecoveryScript.GATE_ID,
		"repair_id": RecoveryScript.REPAIR_ID,
		"r10d_l1_design_sha256": WorkerScript.R10D_L1_DESIGN_SHA256,
		"consumed_r10d_physical_closure_sha256": WorkerScript.CONSUMED_R10D_PHYSICAL_CLOSURE_SHA256,
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
		"successor_definition_control_count": int(definition_controls["control_count"]),
		"supported_descriptor_hash_control_count":
		int(definition_controls["supported_descriptor_hash_control_count"]),
		"development_held_out_seed_separation_control_count":
		int(definition_controls["seed_separation_control_count"]),
		"challenge_marker_and_impulse_exactness_control_count":
		int(definition_controls["challenge_exactness_control_count"]),
		"prospective_two_cycle_positive_control_count":
		int(window_controls["prospective_two_cycle_positive_control_count"]),
		"historical_one_cycle_negative_control_count":
		int(window_controls["historical_one_cycle_negative_control_count"]),
		"window_boundary_and_duration_refusal_count":
		int(window_controls["boundary_and_duration_refusal_count"]),
		"forward_floor_exact_scaling_control_count":
		int(window_controls["forward_floor_exact_scaling_control_count"]),
		"forward_floor_negative_control_count":
		int(window_controls["forward_floor_negative_control_count"]),
		"safe_envelope_negative_control_count":
		int(window_controls["safe_envelope_negative_control_count"]),
		"command_application_negative_control_count":
		int(window_controls["command_application_negative_control_count"]),
		"per_limb_contact_cycle_negative_control_count":
		int(window_controls["per_limb_contact_cycle_negative_control_count"]),
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
		"valid_finite_negative_json_round_trip_control_count": 1,
		"invalid_or_incomplete_refusal_count": negative_controls.size(),
		"authorization_document_valid_control_count": int(authorization_controls["valid_count"]),
		"authorization_document_mutation_rejection_count":
		int(authorization_controls["mutation_count"]),
		"stage_freeze_numeric_normalization_control_count":
		int(authorization_controls["numeric_normalization_count"]),
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


static func _successor_definition_controls(generated: Dictionary) -> Dictionary:
	var generator_receipt: Dictionary = generated.get("generator_receipt", {})
	var baseline_challenge := RecoveryScript.challenge_options(RecoveryScript.BASELINE_ARM_ID)
	var push_challenge := RecoveryScript.challenge_options(RecoveryScript.PUSH_ARM_ID)
	var baseline_trace := RecoveryScript.trace_options(RecoveryScript.BASELINE_ARM_ID, 40001)
	var push_trace := RecoveryScript.trace_options(RecoveryScript.PUSH_ARM_ID, 40001)
	var seeds_disjoint := true
	for development_seed in RecoveryScript.DEVELOPMENT_GHOST_SEEDS:
		seeds_disjoint = (
			seeds_disjoint and not RecoveryScript.HELD_OUT_SEEDS.has(int(development_seed))
		)
	var supported_descriptor_hashes_exact: bool = (
		(
			String(generated.get("generator_receipt_sha256", ""))
			== RecoveryScript.GENERATOR_RECEIPT_SHA256
		)
		and (
			String(generated.get("proportion_spec_sha256", ""))
			== RecoveryScript.R05E_PROPORTION_SPEC_SHA256
		)
		and String(generated.get("fixture_spec_sha256", "")) == RecoveryScript.FIXTURE_SPEC_SHA256
		and (
			String(generated.get("material_profile_sha256", ""))
			== RecoveryScript.MATERIAL_PROFILE_SHA256
		)
		and (
			String(generator_receipt.get("source_generator_receipt_sha256", ""))
			== RecoveryScript.R05E_GENERATOR_RECEIPT_SHA256
		)
		and (
			String(generator_receipt.get("source_proportion_spec_sha256", ""))
			== RecoveryScript.R05E_PROPORTION_SPEC_SHA256
		)
		and int(generator_receipt.get("generator_index", -1)) == RecoveryScript.GENERATOR_INDEX
		and String(generator_receipt.get("morphology_id", "")) == RecoveryScript.MORPHOLOGY_ID
	)
	var seed_separation_exact: bool = (
		RecoveryScript.DEVELOPMENT_GHOST_SEEDS == [40001]
		and RecoveryScript.HELD_OUT_SEEDS == [40101, 40102, 40103]
		and RecoveryScript.ALL_SEEDS == [40001, 40101, 40102, 40103]
		and seeds_disjoint
		and RecoveryScript.cell_id(RecoveryScript.BASELINE_ARM_ID, 40001) == "baseline_s40001"
		and RecoveryScript.cell_id(RecoveryScript.PUSH_ARM_ID, 40103) == "push_s40103"
		and RecoveryScript.cell_id(RecoveryScript.BASELINE_ARM_ID, 50301).is_empty()
	)
	var challenge_exact: bool = (
		(
			String(baseline_challenge.get("challenge_profile_id", ""))
			== "qsdk_r10d_matched_no_impulse_control_v1"
		)
		and String(baseline_challenge.get("push_profile_id", "")) == "none"
		and int(baseline_challenge.get("push_step_from_sdk_start", -2)) == -1
		and baseline_challenge.get("push_impulse_task_n_s", []) == [0.0, 0.0, 0.0]
		and (
			String(push_challenge.get("challenge_profile_id", ""))
			== "qsdk_r10d_lateral_upright_impulse_v1"
		)
		and String(push_challenge.get("push_profile_id", "")) == "lateral_impulse_v1"
		and int(push_challenge.get("push_step_from_sdk_start", -1)) == 900
		and push_challenge.get("push_impulse_task_n_s", []) == [0.0, 0.0, 0.25]
		and int(baseline_trace.get("push_marker_semantic_step", -1)) == 900
		and int(push_trace.get("push_marker_semantic_step", -1)) == 900
	)
	var trace_exact: bool = (
		(
			RecoveryScript.TRACE_POLICY_ID
			== "qsdk_r10d_supported_start_phase_robust_push_recovery_trace_v1"
		)
		and (
			RecoveryScript.TRACE_ROW_SCHEMA
			== "sporespore_qsdk_r10d_supported_start_phase_robust_push_recovery_trace_row_v1"
		)
		and int(baseline_trace.get("minimum_controller_step_count", -1)) == 2152
		and int(baseline_trace.get("maximum_controller_step_count", -1)) == 2872
		and (
			String(baseline_trace.get("sampling_phase", ""))
			== "post_physics_for_applied_semantic_step"
		)
		and RecoveryScript.EXPECTED_WALKING_RECEIPT_KEYS.size() == 27
	)
	var bounds_exact: bool = (
		RecoveryScript.PRE_WINDOW_START == 180
		and RecoveryScript.PRE_WINDOW_END_EXCLUSIVE == 900
		and RecoveryScript.BASELINE_WINDOW_START == 901
		and RecoveryScript.BASELINE_WINDOW_END_EXCLUSIVE == 1621
		and RecoveryScript.FIRST_RECOVERY_START == 901
		and RecoveryScript.LAST_RECOVERY_START == 1260
		and RecoveryScript.WINDOW_STEP_COUNT == 720
		and RecoveryScript.MINIMUM_FORWARD_ADVANCE_M == 0.02
		and (
			(
				RecoveryScript.PUSH_MARKER_STEP
				- RecoveryScript.R10B_DIAGNOSTIC_PRE_WINDOW_END_EXCLUSIVE
			)
			== 360
		)
	)
	var ok: bool = (
		supported_descriptor_hashes_exact
		and seed_separation_exact
		and challenge_exact
		and trace_exact
		and bounds_exact
	)
	return {
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R10D_SUCCESSOR_DEFINITION_INVALID",
		"control_count": 5,
		"supported_descriptor_hash_control_count": int(supported_descriptor_hashes_exact),
		"observed_generator_receipt_sha256": String(generated.get("generator_receipt_sha256", "")),
		"seed_separation_control_count": int(seed_separation_exact),
		"challenge_exactness_control_count": int(challenge_exact),
		"trace_forward_version_control_count": int(trace_exact),
		"fixed_bounds_control_count": int(bounds_exact),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
	}


static func _window_contract_controls(baseline_summary: Dictionary) -> Dictionary:
	var trace: Dictionary = baseline_summary.get("sdk_physical_trace", {})
	var base_rows_value: Variant = trace.get("rows", null)
	if typeof(base_rows_value) != TYPE_ARRAY:
		return {"ok": false, "failure_code": "synthetic_rows_missing"}
	var base_rows: Array = base_rows_value

	var boundary_rows: Array = base_rows.duplicate(true)
	for step in range(
		RecoveryScript.PRE_WINDOW_START,
		RecoveryScript.PRE_WINDOW_END_EXCLUSIVE,
	):
		var row: Dictionary = boundary_rows[step]
		var contacts: Dictionary = (row["ordered_foot_contacts_after"] as Dictionary).duplicate(
			true
		)
		contacts["front_left"] = not (step >= 538 and step <= 540)
		row["ordered_foot_contacts_after"] = contacts
		boundary_rows[step] = row
	var prospective_boundary := (
		RecoveryScript
		. evaluate_two_cycle_window_for_zero_world_control(
			boundary_rows,
			RecoveryScript.PRE_WINDOW_START,
			RecoveryScript.PRE_WINDOW_END_EXCLUSIVE,
		)
	)
	var historical_boundary := RecoveryScript.evaluate_r10b_one_cycle_window_for_zero_world_control(
		boundary_rows
	)
	var historical_front_left: Dictionary = (
		(historical_boundary.get("contact_cycle_by_limb", {}) as Dictionary).get("front_left", {})
	)
	var prospective_two_cycle_positive: bool = (
		bool(prospective_boundary.get("passed", false))
		and int(prospective_boundary.get("start_semantic_step", -1)) == 180
		and int(prospective_boundary.get("end_semantic_step_exclusive", -1)) == 900
		and int(prospective_boundary.get("duration_steps", -1)) == 720
	)
	var historical_one_cycle_negative: bool = (
		not bool(historical_boundary.get("passed", true))
		and bool(historical_boundary.get("safe_envelope_passed", false))
		and bool(historical_boundary.get("command_application_passed", false))
		and bool(historical_boundary.get("forward_advance_passed", false))
		and not bool(historical_boundary.get("every_limb_airborne_then_recontact", true))
		and int(historical_front_left.get("longest_airborne_dwell_steps", -1)) == 2
		and int(historical_front_left.get("qualifying_recontact_semantic_step", -2)) == -1
		and not bool(historical_boundary.get("r10b_reclassification_authority", true))
		and not bool(historical_boundary.get("r10d_acceptance_authority", true))
	)

	var duration_refusal_count := 0
	for end_exclusive in [899, 901]:
		var invalid_duration := (
			RecoveryScript
			. evaluate_two_cycle_window_for_zero_world_control(
				base_rows,
				180,
				int(end_exclusive),
			)
		)
		duration_refusal_count += int(
			(
				not bool(invalid_duration.get("passed", true))
				and (
					String(invalid_duration.get("failure_code", ""))
					== "QSDK_R10D_WINDOW_BOUNDS_INVALID"
				)
			)
		)

	var forward_floor_scaling_exact: bool = (
		RecoveryScript.WINDOW_STEP_COUNT == 2 * RecoveryScript.R10B_DIAGNOSTIC_WINDOW_STEP_COUNT
		and (
			RecoveryScript.MINIMUM_FORWARD_ADVANCE_M
			== 2.0 * RecoveryScript.R10B_DIAGNOSTIC_MINIMUM_FORWARD_ADVANCE_M
		)
		and float(prospective_boundary.get("minimum_task_frame_forward_advance_m", NAN)) == 0.02
		and float(historical_boundary.get("minimum_task_frame_forward_advance_m", NAN)) == 0.01
	)
	var forward_rows: Array = base_rows.duplicate(true)
	var origin_position: Array = (
		(
			(forward_rows[RecoveryScript.PRE_WINDOW_START - 1] as Dictionary)["torso_position_world_m"]
			as Array
		)
		. duplicate()
	)
	var terminal_step := RecoveryScript.PRE_WINDOW_END_EXCLUSIVE - 1
	var terminal_row: Dictionary = forward_rows[terminal_step]
	var terminal_position: Array = (terminal_row["torso_position_world_m"] as Array).duplicate()
	terminal_position[0] = float(origin_position[0]) + 0.019999
	terminal_row["torso_position_world_m"] = terminal_position
	forward_rows[terminal_step] = terminal_row
	var forward_negative := RecoveryScript.evaluate_two_cycle_window_for_zero_world_control(
		forward_rows, 180, 900
	)
	var forward_negative_exact: bool = (
		not bool(forward_negative.get("passed", true))
		and bool(forward_negative.get("safe_envelope_passed", false))
		and bool(forward_negative.get("command_application_passed", false))
		and bool(forward_negative.get("every_limb_airborne_then_recontact", false))
		and not bool(forward_negative.get("forward_advance_passed", true))
	)

	var safe_envelope_negative_count := 0
	for mutation_id in ["height", "tilt", "ground_contact"]:
		var safe_rows: Array = base_rows.duplicate(true)
		var safe_row: Dictionary = safe_rows[400]
		if mutation_id == "height":
			var position: Array = (safe_row["torso_position_world_m"] as Array).duplicate()
			position[1] = RecoveryScript.MINIMUM_TORSO_HEIGHT_M - 0.001
			safe_row["torso_position_world_m"] = position
		elif mutation_id == "tilt":
			safe_row["torso_tilt_rad"] = RecoveryScript.MAXIMUM_TORSO_TILT_RAD + 0.001
		else:
			safe_row["torso_ground_contact"] = true
		safe_rows[400] = safe_row
		var safe_negative := RecoveryScript.evaluate_two_cycle_window_for_zero_world_control(
			safe_rows, 180, 900
		)
		safe_envelope_negative_count += int(
			(
				not bool(safe_negative.get("passed", true))
				and not bool(safe_negative.get("safe_envelope_passed", true))
				and bool(safe_negative.get("command_application_passed", false))
				and bool(safe_negative.get("every_limb_airborne_then_recontact", false))
				and bool(safe_negative.get("forward_advance_passed", false))
			)
		)

	var command_application_negative_count := 0
	for field_value in [
		"validated_portable_command_count",
		"native_actuation_application_count",
	]:
		var command_rows: Array = base_rows.duplicate(true)
		var command_row: Dictionary = command_rows[400]
		command_row[String(field_value)] = 7
		command_rows[400] = command_row
		var command_negative := RecoveryScript.evaluate_two_cycle_window_for_zero_world_control(
			command_rows, 180, 900
		)
		command_application_negative_count += int(
			(
				not bool(command_negative.get("passed", true))
				and bool(command_negative.get("safe_envelope_passed", false))
				and not bool(command_negative.get("command_application_passed", true))
				and bool(command_negative.get("every_limb_airborne_then_recontact", false))
				and bool(command_negative.get("forward_advance_passed", false))
			)
		)

	var per_limb_contact_negative_count := 0
	for limb_value in RecoveryScript.EXPECTED_LIMB_ORDER:
		var limb_id := String(limb_value)
		var contact_rows: Array = base_rows.duplicate(true)
		for step in range(180, 900):
			var contact_row: Dictionary = contact_rows[step]
			var contacts: Dictionary = (
				(contact_row["ordered_foot_contacts_after"] as Dictionary).duplicate(true)
			)
			contacts[limb_id] = true
			contact_row["ordered_foot_contacts_after"] = contacts
			contact_rows[step] = contact_row
		var contact_negative := RecoveryScript.evaluate_two_cycle_window_for_zero_world_control(
			contact_rows, 180, 900
		)
		var contact_by_limb: Dictionary = contact_negative.get("contact_cycle_by_limb", {})
		var limb_receipt: Dictionary = contact_by_limb.get(limb_id, {})
		per_limb_contact_negative_count += int(
			(
				not bool(contact_negative.get("passed", true))
				and bool(contact_negative.get("safe_envelope_passed", false))
				and bool(contact_negative.get("command_application_passed", false))
				and not bool(contact_negative.get("every_limb_airborne_then_recontact", true))
				and not bool(limb_receipt.get("passed", true))
				and bool(contact_negative.get("forward_advance_passed", false))
			)
		)

	var fixed_bounds_exact: bool = (
		RecoveryScript.LAST_RECOVERY_START - RecoveryScript.FIRST_RECOVERY_START + 1 == 360
		and RecoveryScript.LAST_RECOVERY_START + RecoveryScript.WINDOW_STEP_COUNT == 1980
		and (
			RecoveryScript.BASELINE_WINDOW_END_EXCLUSIVE - RecoveryScript.BASELINE_WINDOW_START
			== 720
		)
		and 1980 <= RecoveryScript.MINIMUM_SDK_STEP_COUNT
	)
	var ok: bool = (
		prospective_two_cycle_positive
		and historical_one_cycle_negative
		and duration_refusal_count == 2
		and forward_floor_scaling_exact
		and forward_negative_exact
		and safe_envelope_negative_count == 3
		and command_application_negative_count == 2
		and per_limb_contact_negative_count == 4
		and fixed_bounds_exact
	)
	return {
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R10D_WINDOW_CONTRACT_INVALID",
		"prospective_two_cycle_positive_control_count": int(prospective_two_cycle_positive),
		"historical_one_cycle_negative_control_count": int(historical_one_cycle_negative),
		"boundary_and_duration_refusal_count": duration_refusal_count,
		"forward_floor_exact_scaling_control_count": int(forward_floor_scaling_exact),
		"forward_floor_negative_control_count": int(forward_negative_exact),
		"safe_envelope_negative_control_count": safe_envelope_negative_count,
		"command_application_negative_control_count": command_application_negative_count,
		"per_limb_contact_cycle_negative_control_count": per_limb_contact_negative_count,
		"fixed_recovery_search_bounds_control_count": int(fixed_bounds_exact),
		"historical_one_cycle_receipt": historical_boundary,
		"prospective_two_cycle_receipt": prospective_boundary,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
	}


static func _application_receipt_mutation_controls(push_summary: Dictionary) -> Array:
	var controls: Array = []
	var mutations := [
		{"id": "push_target", "field": "target_body_id", "value": "limb"},
		{"id": "push_method", "field": "application_method", "value": "apply_impulse"},
		{"id": "push_marker", "field": "step_from_sdk_start", "value": 899},
		{"id": "push_task_impulse", "field": "impulse_task_n_s", "value": [0.0, 0.0, 0.249]},
		{"id": "push_world_direction", "field": "impulse_world_n_s", "value": [0.25, 0.0, 0.0]},
		{"id": "push_effect_sampling", "field": "effect_sampled", "value": false},
		{
			"id": "push_effect_magnitude",
			"field": "observed_next_tick_velocity_delta_magnitude_m_s",
			"value": 0.5,
		},
	]
	for mutation_value in mutations:
		var mutation: Dictionary = mutation_value
		var candidate := push_summary.duplicate(false)
		var receipt: Dictionary = (push_summary["external_push_receipt"] as Dictionary).duplicate(
			true
		)
		receipt[String(mutation["field"])] = mutation["value"]
		candidate["external_push_receipt"] = receipt
		(
			controls
			. append(
				_refusal(
					String(mutation["id"]),
					RecoveryScript.evaluate_world(candidate, RecoveryScript.PUSH_ARM_ID, 40001),
					"QSDK_R10D_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH",
				)
			)
		)
	return controls


static func _authorization_document_controls() -> Dictionary:
	var valid_count := 0
	var mutation_count := 0
	for campaign_role in ["development_route_ghost", "held_out_finite_decision"]:
		var source_commit := "1".repeat(40)
		var authorization_parent_commit := "2".repeat(40)
		var qualification_parent_commit := "3".repeat(40)
		var stage_freeze_sha256 := "sha256:" + "4".repeat(64)
		var output_root: String = "C:/durable/qsdk-r10d-" + campaign_role
		var cells := _synthetic_cell_ids(campaign_role)
		var predecessor := {
			"path": WorkerScript.R10B_HELD_OUT_CLOSURE_PATH,
			"byte_length": WorkerScript.R10B_HELD_OUT_CLOSURE_BYTES,
			"raw_sha256": WorkerScript.R10B_HELD_OUT_CLOSURE_SHA256,
			"git_blob_oid": "5".repeat(40),
			"status": "closed_consumed_valid_complete_finite_negative",
			"physical_identity_consumed": true,
			"same_identity_rerun_permitted": false,
			"bounded_upright_push_recovery_claimed": false,
		}
		var support := {
			"path": WorkerScript.R05E_PHYSICAL_CLOSURE_PATH,
			"byte_length": WorkerScript.R05E_PHYSICAL_CLOSURE_BYTES,
			"raw_sha256": WorkerScript.R05E_PHYSICAL_CLOSURE_SHA256,
			"git_blob_oid": "6".repeat(40),
			"status":
			"closed_consumed_complete_held_out_finite_positive_eligible_for_separate_qsdk_r05_adoption",
			"selected_generator_index": RecoveryScript.GENERATOR_INDEX,
			"selected_morphology_id": RecoveryScript.MORPHOLOGY_ID,
			"supported_campaign_seeds": [40101.0, 40102.0, 40103.0],
			"walking_pass_count": 3,
			"false_walking_receipt_count": 0,
			"external_push_recovery_claimed": false,
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
			"repair_id": RecoveryScript.REPAIR_ID,
			"campaign_id": _synthetic_campaign_id(campaign_role),
			"campaign_role": campaign_role,
			"question_class": _synthetic_question_class(campaign_role),
			"source_commit": source_commit,
			"qualification_parent_commit": qualification_parent_commit,
			"qualified_source_path_count": WorkerScript.QUALIFIED_SOURCE_PATH_COUNT,
			"qualified_source_path_sha256": WorkerScript.QUALIFIED_SOURCE_PATH_SHA256,
			"r10c_design_sha256": WorkerScript.R10C_DESIGN_SHA256,
			"r10d_l1_design_sha256": WorkerScript.R10D_L1_DESIGN_SHA256,
			"consumed_r10d_physical_closure_sha256":
			WorkerScript.CONSUMED_R10D_PHYSICAL_CLOSURE_SHA256,
			"maximum_world_count": cells.size(),
			"official_zero_world_qualification_passed": true,
			"physical_execution_authorized_by_freeze": false,
			"physical_acceptance_authority": false,
			"release_authority": false,
			"ordered_cell_ids": cells.duplicate(),
			"prerequisite_development_route_ghost": prerequisite,
			"consumed_r10b_held_out_closure": predecessor,
			"r05e_supported_start_closure": support,
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
			"repair_id": "invalid",
			"campaign_id": "invalid",
			"campaign_role": "invalid",
			"question_class": "invalid",
			"source_commit": "0".repeat(40),
			"qualification_parent_commit": "0".repeat(40),
			"qualified_source_path_count": -1,
			"qualified_source_path_sha256": "sha256:" + "0".repeat(64),
			"r10c_design_sha256": "sha256:" + "0".repeat(64),
			"r10d_l1_design_sha256": "sha256:" + "0".repeat(64),
			"consumed_r10d_physical_closure_sha256": "sha256:" + "0".repeat(64),
			"maximum_world_count": -1,
			"official_zero_world_qualification_passed": false,
			"physical_execution_authorized_by_freeze": true,
			"physical_acceptance_authority": true,
			"release_authority": true,
			"ordered_cell_ids": [],
			"prerequisite_development_route_ghost":
			{} if campaign_role == "held_out_finite_decision" else {"unexpected": true},
			"consumed_r10b_held_out_closure": {},
			"r05e_supported_start_closure": {},
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
			"repair_id": RecoveryScript.REPAIR_ID,
			"campaign_id": _synthetic_campaign_id(campaign_role),
			"campaign_role": campaign_role,
			"question_class": _synthetic_question_class(campaign_role),
			"source_commit": source_commit,
			"authorization_commit_derived_from_current_head": true,
			"authorization_parent_commit": authorization_parent_commit,
			"qualification_parent_commit": qualification_parent_commit,
			"r10c_design_sha256": WorkerScript.R10C_DESIGN_SHA256,
			"r10d_l1_design_sha256": WorkerScript.R10D_L1_DESIGN_SHA256,
			"consumed_r10d_physical_closure_sha256":
			WorkerScript.CONSUMED_R10D_PHYSICAL_CLOSURE_SHA256,
			"stage_freeze_sha256": stage_freeze_sha256,
			"consumed_r10b_held_out_closure_sha256": WorkerScript.R10B_HELD_OUT_CLOSURE_SHA256,
			"r05e_physical_closure_sha256": WorkerScript.R05E_PHYSICAL_CLOSURE_SHA256,
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
			"repair_id": "invalid",
			"campaign_id": "invalid",
			"campaign_role": "invalid",
			"question_class": "invalid",
			"source_commit": "0".repeat(40),
			"authorization_commit_derived_from_current_head": false,
			"authorization_parent_commit": "0".repeat(40),
			"qualification_parent_commit": "0".repeat(40),
			"r10c_design_sha256": "sha256:" + "0".repeat(64),
			"r10d_l1_design_sha256": "sha256:" + "0".repeat(64),
			"consumed_r10d_physical_closure_sha256": "sha256:" + "0".repeat(64),
			"stage_freeze_sha256": "sha256:" + "0".repeat(64),
			"consumed_r10b_held_out_closure_sha256": "sha256:" + "0".repeat(64),
			"r05e_physical_closure_sha256": "sha256:" + "0".repeat(64),
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
		"ok": true,
		"failure_code": "",
		"valid_count": valid_count,
		"mutation_count": mutation_count,
		"numeric_normalization_count": 2,
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
		"external_push_receipt":
		(
			{
				"profile_id": "lateral_impulse_v1",
				"target_body_id": "torso",
				"application_method": "RigidBody3D.apply_central_impulse",
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


static func _all_walking_receipts(value: bool) -> Dictionary:
	var receipts := {}
	for key_value in RecoveryScript.EXPECTED_WALKING_RECEIPT_KEYS:
		receipts[String(key_value)] = value
	return receipts


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
		"failure_code": "" if ok else "QSDK_R10D_L3_REPRESENTATION_VALIDATION_INVALID",
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
			== "QSDK_R10D_RECOVERY_TRACE_QUATERNION_PROJECTION_REFUSED"
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
		"failure_code": "" if ok else "QSDK_R10D_L2_QUATERNION_PROJECTION_INVALID",
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
		"schema_version": "sporespore_qsdk_r10d_source_zero_world_v2",
		"gate_id": RecoveryScript.GATE_ID,
		"repair_id": RecoveryScript.REPAIR_ID,
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
