extends "res://tests/probe_godot_jolt_phase_timing.gd"

const GJPT2_CONTRACT_ID := "GJPT2"
const GJPT2_CELL_ID := "gjpt2_baseline_s21001_bw32n_b"
const GJPT2_OUTPUT_PATH_ENV := "SPORESPORE_GJPT2_WORKER_RECEIPT_PATH"
const GJPT2_AUTHORIZATION_PATH_ENV := "SPORESPORE_GJPT2_AUTHORIZATION_PATH"
const GJPT2_AUTHORIZATION_TOKEN_ENV := "SPORESPORE_GJPT2_AUTHORIZATION_TOKEN"
const GJPT2_PREFIX := "GJPT2_PHASE_TIMING_RECEIPT "
const GJPT2_PROJECTION_KEYS := [
	"schema_version",
	"contract_id",
	"cell_id",
	"source_cell_template_id",
	"source_configuration",
	"runtime_provenance",
	"world_outcome_observed_but_not_interpreted",
	"phase_timing",
	"physical_acceptance_authority",
]


func _run() -> void:
	print("\n=== GJPT2 Godot/Jolt phase-timing development probe ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var args := OS.get_cmdline_user_args()
	var mode := String(args[0]) if args.size() == 1 else ""
	if mode not in ["preflight", "physical"]:
		_fail_gjpt2("GJPT2 requires exactly one mode: preflight or physical")
		return
	if not _load_instrumented_runner():
		return
	var source_cell := Bw32Common.find_cell(GJPT1_SOURCE_CELL_ID, BW32N_CANDIDATE_ID)
	if not _gjpt2_source_cell_exact(source_cell):
		_fail_gjpt2("GJPT2 frozen source-cell template changed")
		return
	if not _configure_bw32n_cell(source_cell):
		_clear_bw32n_cell()
		_fail_gjpt2("GJPT2 source-cell configuration failed")
		return
	if mode == "preflight":
		var root_children_before := root.get_child_count()
		var physics_hz_before := Engine.physics_ticks_per_second
		var summary := await _run_gjpt1_cell(int(source_cell["campaign_seed"]), true)
		var canary := _gjpt2_projection_canary(source_cell)
		var exact := (
			bool(summary.get("ok", false))
			and bool(summary.get("entrypoint_control_flow_complete", false))
			and int(summary.get("actual_world_build_count", -1)) == 0
			and root.get_child_count() == root_children_before
			and Engine.physics_ticks_per_second == physics_hz_before
			and bool(canary.get("ok", false))
			and not bool(summary.get("locomotion_outcome_exposed", true))
			and not bool(summary.get("physical_acceptance_authority", true))
		)
		_clear_bw32n_cell()
		var receipt := {
			"schema_version": "sporespore_godot_jolt_phase_timing_gjpt2_preflight_v1",
			"contract_id": GJPT2_CONTRACT_ID,
			"ok": exact,
			"cell_id": GJPT2_CELL_ID,
			"source_cell_template_id": GJPT1_SOURCE_CELL_ID,
			"instrumented_runner_sha256": "sha256:" + GJPT1_RUNNER_SHA256,
			"projection_canary_passed": bool(canary.get("ok", false)),
			"projection_calls_frozen_acceptance_composer": false,
			"actual_world_build_count": 0,
			"scene_tree_insertion_count": root.get_child_count() - root_children_before,
			"physics_state_modified": Engine.physics_ticks_per_second != physics_hz_before,
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
		}
		print(GJPT2_PREFIX, JSON.stringify(receipt, "", true, true))
		quit(0 if exact else 1)
		return
	var authorization := _read_gjpt2_physical_authorization()
	if authorization.is_empty():
		_clear_bw32n_cell()
		return
	var worker_start_usec := Time.get_ticks_usec()
	var summary := await _run_gjpt1_cell(int(source_cell["campaign_seed"]), false)
	var world_runner_return_usec := Time.get_ticks_usec()
	var inner: Dictionary = summary.get("gjpt1_phase_timing", {})
	if not _gjpt2_physical_summary_exact(summary, inner):
		_clear_bw32n_cell()
		_fail_gjpt2("GJPT2 physical runner did not return its exact timing receipt")
		return
	var compose_start_usec := Time.get_ticks_usec()
	var source_projection := _compose_gjpt2_development_projection(source_cell, summary)
	var projection_composition_usec := Time.get_ticks_usec() - compose_start_usec
	if not _gjpt2_projection_exact(source_projection):
		_clear_bw32n_cell()
		_fail_gjpt2("GJPT2 development evidence projection was not exact")
		return
	var workload_payload := {
		"schema_version": "sporespore_godot_jolt_phase_timing_gjpt2_evidence_workload_v1",
		"contract_id": GJPT2_CONTRACT_ID,
		"cell_id": GJPT2_CELL_ID,
		"development_projection": source_projection,
		"outcome_interpretation_authorized": false,
		"physical_acceptance_authority": false,
	}
	var serialize_start_usec := Time.get_ticks_usec()
	var workload_json := JSON.stringify(workload_payload, "", true, true) + "\n"
	var evidence_serialization_usec := Time.get_ticks_usec() - serialize_start_usec
	var worker_receipt_path := OS.get_environment(GJPT2_OUTPUT_PATH_ENV)
	if worker_receipt_path.is_empty() or FileAccess.file_exists(worker_receipt_path):
		_clear_bw32n_cell()
		_fail_gjpt2("GJPT2 worker receipt path is missing or already exists")
		return
	var write_start_usec := Time.get_ticks_usec()
	var output := FileAccess.open(worker_receipt_path, FileAccess.WRITE)
	if output == null:
		_clear_bw32n_cell()
		_fail_gjpt2("GJPT2 could not open its retained evidence-workload path")
		return
	output.store_string(workload_json)
	output.flush()
	output.close()
	var evidence_file_write_usec := Time.get_ticks_usec() - write_start_usec
	var world_runner_total_usec := int(inner["world_runner_total_usec"])
	var evidence_writing_total_usec := (
		projection_composition_usec + evidence_serialization_usec + evidence_file_write_usec
	)
	var instrumented_denominator_usec := world_runner_total_usec + evidence_writing_total_usec
	var receipt := {
		"schema_version": "sporespore_godot_jolt_phase_timing_gjpt2_worker_receipt_v1",
		"contract_id": GJPT2_CONTRACT_ID,
		"status": "completed_development_measurement",
		"cell_id": GJPT2_CELL_ID,
		"source_cell_template_id": GJPT1_SOURCE_CELL_ID,
		"authorization_token": String(authorization["authorization_token"]),
		"instrumented_runner_sha256": "sha256:" + GJPT1_RUNNER_SHA256,
		"development_projection_json_sha256": "sha256:" + workload_json.sha256_text(),
		"development_projection_json_bytes": workload_json.to_utf8_buffer().size(),
		"world_runner_call_elapsed_usec": world_runner_return_usec - worker_start_usec,
		"world_runner_inner": inner.duplicate(true),
		"projection_composition_usec": projection_composition_usec,
		"evidence_serialization_usec": evidence_serialization_usec,
		"evidence_file_write_usec": evidence_file_write_usec,
		"evidence_writing_total_usec": evidence_writing_total_usec,
		"instrumented_denominator_usec": instrumented_denominator_usec,
		"source_world_outcome_observed_but_not_interpreted": true,
		"walking_claim_authorized": false,
		"performance_generalization_authorized": false,
		"physical_acceptance_authority": false,
		"release_authorized": false,
	}
	_clear_bw32n_cell()
	print(GJPT2_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0)


func _gjpt2_source_cell_exact(source_cell: Dictionary) -> bool:
	return (
		not source_cell.is_empty()
		and String(source_cell.get("cell_id", "")) == GJPT1_SOURCE_CELL_ID
		and String(source_cell.get("candidate_id", "")) == BW32N_CANDIDATE_ID
		and String(source_cell.get("challenge_profile_id", "")) == "bw6n_baseline_v1"
		and int(source_cell.get("campaign_seed", -1)) == 21001
		and String(source_cell.get("candidate_base_composition_digest", ""))
		== BW32N_CANDIDATE_DIGEST
	)


func _gjpt2_physical_summary_exact(summary: Dictionary, inner: Dictionary) -> bool:
	return (
		not inner.is_empty()
		and int(summary.get("world_build_count", -1)) == 1
		and int(summary.get("world_reset_count", -1)) == 0
		and int(summary.get("candidate_authority_observation_count", -1)) == 3232
		and int(summary.get("pre_authority_world_tick_count", -1)) == 240
		and int(summary.get("executed_ticks", -1)) == 3472
		and int(inner.get("instrumented_tick_count", -1)) == 3472
		and int(inner.get("world_runner_total_usec", -1)) > 0
	)


func _compose_gjpt2_development_projection(
	source_cell: Dictionary,
	summary: Dictionary,
) -> Dictionary:
	return {
		"schema_version": "sporespore_godot_jolt_phase_timing_gjpt2_projection_v1",
		"contract_id": GJPT2_CONTRACT_ID,
		"cell_id": GJPT2_CELL_ID,
		"source_cell_template_id": GJPT1_SOURCE_CELL_ID,
		"source_configuration": {
			"candidate_id": String(source_cell.get("candidate_id", "")),
			"candidate_base_composition_digest": String(
				source_cell.get("candidate_base_composition_digest", "")
			),
			"challenge_profile_id": String(source_cell.get("challenge_profile_id", "")),
			"campaign_seed": int(source_cell.get("campaign_seed", -1)),
		},
		"runtime_provenance": {
			"world_build_count": int(summary.get("world_build_count", -1)),
			"world_reset_count": int(summary.get("world_reset_count", -1)),
			"executed_ticks": int(summary.get("executed_ticks", -1)),
			"pre_authority_world_tick_count": int(
				summary.get("pre_authority_world_tick_count", -1)
			),
			"candidate_authority_observation_count": int(
				summary.get("candidate_authority_observation_count", -1)
			),
			"physics_engine": String(summary.get("physics_engine", "")),
			"physics_hz": int(summary.get("physics_hz", -1)),
			"solver_velocity_steps": int(summary.get("solver_velocity_steps", -1)),
			"solver_position_steps": int(summary.get("solver_position_steps", -1)),
			"environment_challenge_configuration_sha256": String(
				summary.get("environment_challenge_configuration_sha256", "")
			),
			"sdk_authority_summary": (
				summary.get("sdk_authority_summary", {}) as Dictionary
			).duplicate(true),
		},
		"world_outcome_observed_but_not_interpreted": {
			"failure_code": String(summary.get("failure_code", "")),
			"walking_gate_receipts": (
				summary.get("walking_gate_receipts", {}) as Dictionary
			).duplicate(true),
		},
		"phase_timing": (
			summary.get("gjpt1_phase_timing", {}) as Dictionary
		).duplicate(true),
		"physical_acceptance_authority": false,
	}


func _gjpt2_projection_exact(projection: Dictionary) -> bool:
	return (
		projection.keys() == GJPT2_PROJECTION_KEYS
		and String(projection.get("contract_id", "")) == GJPT2_CONTRACT_ID
		and String(projection.get("cell_id", "")) == GJPT2_CELL_ID
		and not bool(projection.get("physical_acceptance_authority", true))
	)


func _gjpt2_projection_canary(source_cell: Dictionary) -> Dictionary:
	var synthetic_summary := {
		"world_build_count": 1,
		"world_reset_count": 0,
		"executed_ticks": 3472,
		"pre_authority_world_tick_count": 240,
		"candidate_authority_observation_count": 3232,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 7,
		"environment_challenge_configuration_sha256": "sha256:synthetic",
		"sdk_authority_summary": {"step_count": 3232},
		"failure_code": "",
		"walking_gate_receipts": {"synthetic": true},
		"gjpt1_phase_timing": {
			"instrumented_tick_count": 3472,
			"world_runner_total_usec": 1,
		},
	}
	var projection := _compose_gjpt2_development_projection(source_cell, synthetic_summary)
	return {
		"ok": (
			_gjpt2_projection_exact(projection)
			and int(
				(projection["runtime_provenance"] as Dictionary).get("executed_ticks", -1)
			) == 3472
			and int((projection["phase_timing"] as Dictionary).get(
				"instrumented_tick_count", -1
			)) == 3472
		),
		"projection": projection,
	}


func _read_gjpt2_physical_authorization() -> Dictionary:
	var path := OS.get_environment(GJPT2_AUTHORIZATION_PATH_ENV)
	var token := OS.get_environment(GJPT2_AUTHORIZATION_TOKEN_ENV)
	if path.is_empty() or token.is_empty() or not FileAccess.file_exists(path):
		_fail_gjpt2("GJPT2 physical execution requires supervisor authorization")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail_gjpt2("GJPT2 authorization is not an object")
		return {}
	var authorization: Dictionary = parsed
	if (
		String(authorization.get("schema_version", ""))
		!= "sporespore_godot_jolt_phase_timing_gjpt2_authorization_v1"
		or String(authorization.get("contract_id", "")) != GJPT2_CONTRACT_ID
		or String(authorization.get("cell_id", "")) != GJPT2_CELL_ID
		or String(authorization.get("source_cell_template_id", "")) != GJPT1_SOURCE_CELL_ID
		or String(authorization.get("authorization_token", "")) != token
		or String(authorization.get("instrumented_runner_sha256", ""))
		!= "sha256:" + GJPT1_RUNNER_SHA256
		or bool(authorization.get("physical_identity_consumed", true))
		or bool(authorization.get("physical_acceptance_authority", true))
	):
		_fail_gjpt2("GJPT2 physical authorization fields are not exact")
		return {}
	return authorization


func _fail_gjpt2(message: String) -> void:
	push_error(message)
	quit(1)
