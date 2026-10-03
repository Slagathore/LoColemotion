extends "res://tests/test_sdk_balanced_wave_bw32n_successor_worker.gd"

const GJPT1_CONTRACT_ID := "GJPT1"
const GJPT1_CELL_ID := "gjpt1_baseline_s21001_bw32n_b"
const GJPT1_SOURCE_CELL_ID := "baseline_s21001_bw32n_b"
const GJPT1_RUNNER_PATH := (
	"res://sdk/target/gjpt1/physical_wave_gait_quadruped_phase_timing.gd"
)
const GJPT1_RUNNER_SHA256 := (
	"ac9310ce50ef5649d407ff38ff0f726c9ff0d3458aaad32f4e43610605ea7e09"
)
const GJPT1_AUTHORIZATION_PATH_ENV := "SPORESPORE_GJPT1_AUTHORIZATION_PATH"
const GJPT1_AUTHORIZATION_TOKEN_ENV := "SPORESPORE_GJPT1_AUTHORIZATION_TOKEN"
const GJPT1_OUTPUT_PATH_ENV := "SPORESPORE_GJPT1_WORKER_RECEIPT_PATH"
const GJPT1_PREFIX := "GJPT1_PHASE_TIMING_RECEIPT "

var _gjpt1_runner_script: Script


func _run() -> void:
	print("\n=== GJPT1 Godot/Jolt phase-timing development probe ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var args := OS.get_cmdline_user_args()
	var mode := String(args[0]) if args.size() == 1 else ""
	if mode not in ["preflight", "physical"]:
		_fail_gjpt1("GJPT1 requires exactly one mode: preflight or physical")
		return
	if not _load_instrumented_runner():
		return
	var source_cell := Bw32Common.find_cell(GJPT1_SOURCE_CELL_ID, BW32N_CANDIDATE_ID)
	if (
		source_cell.is_empty()
		or String(source_cell.get("cell_id", "")) != GJPT1_SOURCE_CELL_ID
		or String(source_cell.get("candidate_id", "")) != BW32N_CANDIDATE_ID
		or String(source_cell.get("challenge_profile_id", "")) != "bw6n_baseline_v1"
		or int(source_cell.get("campaign_seed", -1)) != 21001
		or String(source_cell.get("candidate_base_composition_digest", ""))
		!= BW32N_CANDIDATE_DIGEST
	):
		_fail_gjpt1("GJPT1 frozen source-cell template changed")
		return
	if not _configure_bw32n_cell(source_cell):
		_clear_bw32n_cell()
		_fail_gjpt1("GJPT1 source-cell configuration failed")
		return
	if mode == "preflight":
		var root_children_before := root.get_child_count()
		var physics_hz_before := Engine.physics_ticks_per_second
		var summary := await _run_gjpt1_cell(int(source_cell["campaign_seed"]), true)
		var exact := (
			bool(summary.get("ok", false))
			and bool(summary.get("entrypoint_control_flow_complete", false))
			and int(summary.get("actual_world_build_count", -1)) == 0
			and root.get_child_count() == root_children_before
			and Engine.physics_ticks_per_second == physics_hz_before
			and not bool(summary.get("locomotion_outcome_exposed", true))
			and not bool(summary.get("physical_acceptance_authority", true))
		)
		_clear_bw32n_cell()
		var receipt := {
			"schema_version": "sporespore_godot_jolt_phase_timing_preflight_v1",
			"contract_id": GJPT1_CONTRACT_ID,
			"ok": exact,
			"cell_id": GJPT1_CELL_ID,
			"source_cell_template_id": GJPT1_SOURCE_CELL_ID,
			"instrumented_runner_sha256": "sha256:" + GJPT1_RUNNER_SHA256,
			"actual_world_build_count": 0,
			"scene_tree_insertion_count": root.get_child_count() - root_children_before,
			"physics_state_modified": Engine.physics_ticks_per_second != physics_hz_before,
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
		}
		print(GJPT1_PREFIX, JSON.stringify(receipt, "", true, true))
		quit(0 if exact else 1)
		return
	var authorization := _read_physical_authorization()
	if authorization.is_empty():
		_clear_bw32n_cell()
		return
	var worker_start_usec := Time.get_ticks_usec()
	var summary := await _run_gjpt1_cell(int(source_cell["campaign_seed"]), false)
	var world_runner_return_usec := Time.get_ticks_usec()
	var inner: Dictionary = summary.get("gjpt1_phase_timing", {})
	if (
		inner.is_empty()
		or int(summary.get("world_build_count", -1)) != 1
		or int(summary.get("candidate_authority_observation_count", -1)) != 3232
		or int(summary.get("pre_authority_world_tick_count", -1)) != 240
		or int(inner.get("instrumented_tick_count", -1)) != 3472
		or int(inner.get("world_runner_total_usec", -1)) <= 0
	):
		_clear_bw32n_cell()
		_fail_gjpt1("GJPT1 physical runner did not return its timing receipt")
		return
	var compose_start_usec := Time.get_ticks_usec()
	var source_projection := _bw32n_successor_receipt(source_cell, summary)
	var projection_composition_usec := Time.get_ticks_usec() - compose_start_usec
	if source_projection.is_empty():
		_clear_bw32n_cell()
		_fail_gjpt1("GJPT1 source-shaped evidence projection failed")
		return
	var workload_payload := {
		"schema_version": "sporespore_godot_jolt_phase_timing_evidence_workload_v1",
		"contract_id": GJPT1_CONTRACT_ID,
		"cell_id": GJPT1_CELL_ID,
		"source_cell_template_id": GJPT1_SOURCE_CELL_ID,
		"source_shaped_projection": source_projection,
		"outcome_interpretation_authorized": false,
		"physical_acceptance_authority": false,
	}
	var serialize_start_usec := Time.get_ticks_usec()
	var workload_json := JSON.stringify(workload_payload, "", true, true) + "\n"
	var evidence_serialization_usec := Time.get_ticks_usec() - serialize_start_usec
	var worker_receipt_path := OS.get_environment(GJPT1_OUTPUT_PATH_ENV)
	if worker_receipt_path.is_empty() or FileAccess.file_exists(worker_receipt_path):
		_clear_bw32n_cell()
		_fail_gjpt1("GJPT1 worker receipt path is missing or already exists")
		return
	var write_start_usec := Time.get_ticks_usec()
	var output := FileAccess.open(worker_receipt_path, FileAccess.WRITE)
	if output == null:
		_clear_bw32n_cell()
		_fail_gjpt1("GJPT1 could not open its retained evidence-workload path")
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
		"schema_version": "sporespore_godot_jolt_phase_timing_worker_receipt_v1",
		"contract_id": GJPT1_CONTRACT_ID,
		"status": "completed_development_measurement",
		"cell_id": GJPT1_CELL_ID,
		"source_cell_template_id": GJPT1_SOURCE_CELL_ID,
		"authorization_token": String(authorization["authorization_token"]),
		"instrumented_runner_sha256": "sha256:" + GJPT1_RUNNER_SHA256,
		"source_projection_json_sha256": "sha256:" + workload_json.sha256_text(),
		"source_projection_json_bytes": workload_json.to_utf8_buffer().size(),
		"world_runner_call_elapsed_usec": world_runner_return_usec - worker_start_usec,
		"world_runner_inner": inner.duplicate(true),
		"projection_composition_usec": projection_composition_usec,
		"evidence_serialization_usec": evidence_serialization_usec,
		"evidence_file_write_usec": evidence_file_write_usec,
		"evidence_writing_total_usec": evidence_writing_total_usec,
		"instrumented_denominator_usec": instrumented_denominator_usec,
		"source_world_outcome_observed_but_not_interpreted": true,
		"walking_claim_authorized": false,
		"nuisance_claim_authorized": false,
		"performance_generalization_authorized": false,
		"physical_acceptance_authority": false,
		"release_authorized": false,
	}
	_clear_bw32n_cell()
	print(GJPT1_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0)


func _load_instrumented_runner() -> bool:
	if (
		not FileAccess.file_exists(GJPT1_RUNNER_PATH)
		or FileAccess.get_sha256(GJPT1_RUNNER_PATH).to_lower() != GJPT1_RUNNER_SHA256
	):
		_fail_gjpt1("GJPT1 generated runner is missing or has the wrong digest")
		return false
	_gjpt1_runner_script = load(GJPT1_RUNNER_PATH)
	if _gjpt1_runner_script == null:
		_fail_gjpt1("GJPT1 generated runner did not compile")
		return false
	return true


func _read_physical_authorization() -> Dictionary:
	var path := OS.get_environment(GJPT1_AUTHORIZATION_PATH_ENV)
	var token := OS.get_environment(GJPT1_AUTHORIZATION_TOKEN_ENV)
	if path.is_empty() or token.is_empty() or not FileAccess.file_exists(path):
		_fail_gjpt1("GJPT1 physical execution requires supervisor authorization")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail_gjpt1("GJPT1 authorization is not an object")
		return {}
	var authorization: Dictionary = parsed
	if (
		String(authorization.get("schema_version", ""))
		!= "sporespore_godot_jolt_phase_timing_authorization_v1"
		or String(authorization.get("contract_id", "")) != GJPT1_CONTRACT_ID
		or String(authorization.get("cell_id", "")) != GJPT1_CELL_ID
		or String(authorization.get("source_cell_template_id", "")) != GJPT1_SOURCE_CELL_ID
		or String(authorization.get("authorization_token", "")) != token
		or String(authorization.get("instrumented_runner_sha256", ""))
		!= "sha256:" + GJPT1_RUNNER_SHA256
		or bool(authorization.get("physical_identity_consumed", true))
		or bool(authorization.get("physical_acceptance_authority", true))
	):
		_fail_gjpt1("GJPT1 physical authorization fields are not exact")
		return {}
	return authorization


func _run_gjpt1_cell(seed: int, preflight_before_world: bool) -> Dictionary:
	var prepared := _prepare_cell(0)
	if not bool(prepared.get("ok", false)):
		return prepared
	var perturbation_result := WaveGaitScript.compile_seeded_initial_perturbation(seed)
	var clock_result := ClockSpecScript.compile(ClockSpecScript.gq15_clock())
	var acquisition_result := WaveGaitScript.compile_evidence_acquisition_options(
		Bw32Common.ACQUISITION_OPTIONS,
		12,
		3,
	)
	var horizon_result := WaveGaitScript.compile_candidate_authority_horizon_options(
		Bw32Common.AUTHORITY_HORIZON_OPTIONS
	)
	if (
		not bool(perturbation_result.get("ok", false))
		or not bool(clock_result.get("ok", false))
		or not bool(acquisition_result.get("ok", false))
		or not bool(horizon_result.get("ok", false))
		or not bool(
			(
				horizon_result.get("candidate_authority_horizon_options", {}) as Dictionary
			).get("enabled", false)
		)
		or String(acquisition_result.get("evidence_acquisition_configuration_sha256", ""))
		!= Bw32Common.ACQUISITION_SHA256
	):
		return {"ok": false, "failure_code": "GJPT1_INPUT_INVALID"}
	var selected_policy_start: Dictionary = {}
	if preflight_before_world:
		selected_policy_start = _preflight_selected_policy_full_authority_start(
			prepared,
			perturbation_result["initial_perturbation"],
		)
		if not bool(selected_policy_start.get("ok", false)):
			return selected_policy_start
	var root_children_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var runner: RefCounted = _gjpt1_runner_script.new()
	var summary: Dictionary = await runner.run(
		self,
		-1.0,
		10.0,
		1.75,
		"lateral",
		72,
		0.40,
		"all",
		112,
		false,
		perturbation_result["initial_perturbation"],
		ROBUSTNESS_OPTIONS,
		prepared["fixture_spec"],
		HOST_OBSERVER_PATH_OPTIONS,
		ACTUATOR_IMPULSE_OPTIONS,
		HOST_PREAUTHORITY_MOTOR_OPTIONS,
		prepared["evidence_threshold_options"],
		clock_result["gait_clock_options"],
		SOLVER_POLICY_OPTIONS,
		{},
		{},
		prepared["authority_options"],
		_bw32n_challenge_options,
		Bw32Common.ACQUISITION_OPTIONS,
		preflight_before_world,
		Bw32Common.AUTHORITY_HORIZON_OPTIONS,
	)
	if preflight_before_world:
		summary["selected_policy_full_authority_start"] = selected_policy_start.duplicate(true)
		summary["selected_policy_full_authority_start_passed"] = true
		summary["scene_tree_insertion_count"] = root.get_child_count() - root_children_before
		summary["physics_state_modified"] = Engine.physics_ticks_per_second != physics_hz_before
	return summary


func _fail_gjpt1(message: String) -> void:
	push_error(message)
	quit(1)
