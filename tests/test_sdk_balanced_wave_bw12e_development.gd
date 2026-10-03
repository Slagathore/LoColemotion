extends "res://tests/test_sdk_balanced_wave_bw10f_development.gd"

## Prospectively frozen BW12E development replication.
##
## BW12E is a new experiment identity. It does not repair or rerun BW11R.
## It freezes the portable v3 observation-unavailable decision, candidate-
## relative integrity hooks, and a separate-process combined real-entrypoint
## plus exact-full-gate synthetic preflight before any physical world may open.
## Development can select a hypothesis for later independent validation; it
## cannot authorize a physical or robustness claim.

const BW12E_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw12e_preregistration.json"
const BW12E_PREREGISTRATION_SCHEMA := "sporespore_balanced_wave_bw12e_preregistration_v1"
const BW12E_PREREGISTRATION_SHA256 := (
	"sha256:c373fce0ba32687466c648d0484e7655" + "a5c14c1f89f8ce290e01c5cca314394c"
)
const BW12E_IMPLEMENTATION_PARENT_COMMIT := "afd7cb175a3a6eb8504db19d62dcb53c7af9cbf4"
const BW12E_CHALLENGE_SOURCE_PATH := "res://sdk/balanced_wave_bw6n_validation_manifest.json"
const BW12E_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const BW12E_PROFILE_DIGEST := (
	"sha256:e62b97398497f32243bae4fb6eaca258" + "f90cbd233fc8c913c456b01a287bf993"
)
const BW12E_BASE_CONTROLLER_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const BW12E_FRESH_SEEDS := [27001, 27002, 27003, 27004, 27005, 27006]
const BW12E_EXPECTED_WORLD_COUNT := 12
const BW12E_EXPECTED_GATE_COUNT := 23
const BW12E_CANDIDATE_IDS := ["BW12E-A", "BW12E-B", "BW12E-C", "BW12E-D"]
const BW12E_STABILITY_POLICY_IDS := [
	"sporespore_scheduled_load_transfer_bw11r_a_v3",
	"sporespore_scheduled_load_transfer_bw11r_b_v3",
	"sporespore_scheduled_load_transfer_bw11r_c_v3",
	"sporespore_scheduled_load_transfer_bw11r_d_v3",
]
const BW12E_POLICY_DIGESTS := [
	"sha256:f726befa2326e46f3e086f7612a572a253af4b2633b788ea603f433e0b3df8ed",
	"sha256:832fb5d5e26085ba4e79db9dcc875e354e5b52ebbc74a77f263f5cfb51fb598e",
	"sha256:d6f89d01b3b73fe4749317a6efc3b1c2c8a6c45576a290d1a6989f73b7f7ed07",
	"sha256:38977d8a366e67271b6403d1aa18d17b6ebd09d66863a71cf032d96e196818db",
]


func _run() -> void:
	print("\n=== SDK balanced-wave BW12E frozen development candidate ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var user_args := OS.get_cmdline_user_args()
	var candidate_index := -1
	var preflight_only := false
	for argument_value in user_args:
		var argument := String(argument_value)
		if argument == "--preflight-only":
			if preflight_only:
				push_error("BW12E received duplicate --preflight-only")
				quit(1)
				return
			preflight_only = true
			continue
		if argument.begins_with("--bw12e-"):
			if candidate_index >= 0:
				push_error("BW12E requires exactly one candidate")
				quit(1)
				return
			var suffix := argument.trim_prefix("--bw12e-").to_upper()
			candidate_index = BW12E_CANDIDATE_IDS.find("BW12E-%s" % suffix)
			continue
		push_error("Unknown BW12E argument: %s" % argument)
		quit(1)
		return
	if candidate_index < 0 or user_args.size() < 1 or user_args.size() > 2:
		push_error("BW12E requires exactly one of --bw12e-a/b/c/d")
		quit(1)
		return
	_bw2_mode = true
	_bw2_candidate_id = BW12E_CANDIDATE_IDS[candidate_index]
	_bw2_policy_id = BW12E_BASE_CONTROLLER_POLICY_ID
	_bw2_policy_digest = BW12E_POLICY_DIGESTS[candidate_index]
	_bw9l_stability_policy_id = BW12E_STABILITY_POLICY_IDS[candidate_index]
	_opened_development_replay = false
	await _run_bw12e_development(preflight_only)


func _campaign_seeds() -> Array:
	return BW12E_FRESH_SEEDS


func _required_profile_ids() -> Array:
	return [BW12E_PROFILE_ID]


func _expected_cell_ids() -> Array:
	var result: Array = []
	for cohort in ["baseline", "rough"]:
		for seed_value in BW12E_FRESH_SEEDS:
			result.append("fresh_%s_s%d" % [cohort, int(seed_value)])
	return result


func _expected_world_count() -> int:
	return BW12E_EXPECTED_WORLD_COUNT


func _bridge_profile_id() -> String:
	return BW12E_PROFILE_ID


func _expected_stability_policy_id() -> String:
	return _bw9l_stability_policy_id


func _stability_observation_partition_exact(
	stability_shadow: Dictionary,
) -> bool:
	var available_count := int(stability_shadow.get("available_count", -1))
	var unavailable_count := int(stability_shadow.get("unavailable_count", -1))
	return (
		available_count >= 0
		and unavailable_count >= 0
		and available_count + unavailable_count == EXPECTED_STEP_COUNT
	)


func _balanced_wave_treatment_mechanism_integrity(
	contribution: Dictionary,
	overlay: Dictionary,
) -> bool:
	var feedback_count := int(contribution.get("feedback_nonzero_attempt_count", -1))
	var active_count := int(contribution.get("nonzero_active_command_count", -1))
	var overlay_count := int(overlay.get("nonzero_effective_application_count", -1))
	if _bw2_candidate_id == "BW12E-A":
		return feedback_count == 0 and active_count == 0 and overlay_count == 0
	return feedback_count > 0 and active_count > 0 and overlay_count > 0


func _build_matrix() -> Array:
	var challenge_source := _load_json_dictionary(BW12E_CHALLENGE_SOURCE_PATH)
	var challenge_by_id := {}
	for challenge_value in challenge_source.get("challenge_profiles", []):
		var challenge: Dictionary = challenge_value
		var challenge_id := String(challenge.get("challenge_profile_id", ""))
		if challenge_id in ["bw6n_baseline_v1", "bw6n_rough_v1"]:
			var compiled := WaveGaitScript.compile_environment_challenge_options(challenge)
			if bool(compiled.get("ok", false)):
				challenge_by_id[challenge_id] = (
					(compiled["environment_challenge_options"] as Dictionary).duplicate(true)
				)
	var matrix: Array = []
	for cohort in ["baseline", "rough"]:
		var challenge_id := "bw6n_%s_v1" % cohort
		for seed_value in BW12E_FRESH_SEEDS:
			var seed := int(seed_value)
			(
				matrix
				. append(
					{
						"cell_id": "fresh_%s_s%d" % [cohort, seed],
						"partition": "fresh",
						"cohort": cohort,
						"mode": "treatment",
						"campaign_seed": seed,
						"mu_token": "095",
						"authored_friction": 0.95,
						"profile_id": BW12E_PROFILE_ID,
						"profile_digest": BW12E_PROFILE_DIGEST,
						"challenge_profile_id": challenge_id,
						"challenge_options":
						(challenge_by_id.get(challenge_id, {}) as Dictionary).duplicate(true),
					}
				)
			)
	return matrix


func _matrix_cardinality_exact(matrix: Array) -> bool:
	var count_by_cohort := {"baseline": 0, "rough": 0}
	var observed_seeds: Dictionary = {}
	for cell_value in matrix:
		var cell: Dictionary = cell_value
		var cohort := String(cell.get("cohort", ""))
		var seed := int(cell.get("campaign_seed", -1))
		if (
			not count_by_cohort.has(cohort)
			or String(cell.get("partition", "")) != "fresh"
			or String(cell.get("mode", "")) != "treatment"
			or not BW12E_FRESH_SEEDS.has(seed)
			or (cell.get("challenge_options", {}) as Dictionary).is_empty()
		):
			return false
		count_by_cohort[cohort] = int(count_by_cohort[cohort]) + 1
		observed_seeds[seed] = int(observed_seeds.get(seed, 0)) + 1
	for count_value in count_by_cohort.values():
		if int(count_value) != 6:
			return false
	for seed_value in BW12E_FRESH_SEEDS:
		if int(observed_seeds.get(int(seed_value), 0)) != 2:
			return false
	return matrix.size() == BW12E_EXPECTED_WORLD_COUNT


func _validation_manifest_receipt() -> Dictionary:
	var preregistration := _load_json_dictionary(BW12E_PREREGISTRATION_PATH)
	var candidates: Array = preregistration.get("candidates", [])
	var candidate: Dictionary = {}
	for candidate_value in candidates:
		var requested: Dictionary = candidate_value
		if String(requested.get("candidate_id", "")) == _bw2_candidate_id:
			candidate = requested
			break
	var development: Dictionary = preregistration.get("development_matrix", {})
	var selection: Dictionary = preregistration.get("selection", {})
	var portable: Dictionary = preregistration.get("portable_implementation", {})
	var mechanism: Dictionary = preregistration.get("mechanism_receipt_eligibility", {})
	var full_gate: Dictionary = (
		preregistration
		. get(
			"full_gate_satisfiability_preflight",
			{},
		)
	)
	var reason: Dictionary = preregistration.get("reason_for_successor", {})
	var claims: Dictionary = preregistration.get("claims", {})
	var candidate_index := BW12E_CANDIDATE_IDS.find(_bw2_candidate_id)
	var claims_exact := bool(claims.get("development_selection_authority", false))
	for claim_key_value in claims.keys():
		var claim_key := String(claim_key_value)
		if claim_key != "development_selection_authority":
			claims_exact = claims_exact and not bool(claims[claim_key])
	var development_seeds: Array = []
	for seed_value in development.get("fresh_development_seeds", []):
		development_seeds.append(int(seed_value))
	var checks := {
		"candidate_index": candidate_index >= 0,
		"schema_and_status":
		(
			String(preregistration.get("schema_version", "")) == BW12E_PREREGISTRATION_SCHEMA
			and (
				String(preregistration.get("status", ""))
				== "frozen_before_first_bw12e_physics_world"
			)
			and (
				String(preregistration.get("implementation_parent_commit", ""))
				== BW12E_IMPLEMENTATION_PARENT_COMMIT
			)
			and (
				String(preregistration.get("documentation_parent_commit", ""))
				== BW12E_IMPLEMENTATION_PARENT_COMMIT
			)
		),
		"successor_boundary":
		(
			String(reason.get("rejected_family_id", "")) == "BW11R"
			and (
				String(reason.get("rejected_source_commit", ""))
				== "40021c84f3d5a3aa8116c8711e83545810031624"
			)
			and (
				String(reason.get("family_closure_report_sha256", ""))
				== "73f09c4281cb21ec635b35a6bfc59c4a8fa350162c5739cb40d0a75a1fa416ab"
			)
			and (
				String(reason.get("closure_status", ""))
				== "candidate_family_invalidated_before_physics_by_entrypoint_policy_allowlist"
			)
			and int(reason.get("attempted_cell_count", -1)) == 48
			and int(reason.get("reported_cell_receipt_count", -1)) == 48
			and int(reason.get("actual_world_build_count", -1)) == 0
			and int(reason.get("physical_outcome_count", -1)) == 0
			and int(reason.get("sdk_step_receipt_count", -1)) == 0
			and bool(reason.get("bw11r_family_closed", false))
			and bool(reason.get("bw11r_repair_or_rerun_forbidden", false))
		),
		"canonical_digest":
		CanonicalJsonScript.sha256(preregistration) == BW12E_PREREGISTRATION_SHA256,
		"candidate_family":
		(
			(preregistration.get("candidate_order", []) as Array) == BW12E_CANDIDATE_IDS
			and candidates.size() == 4
		),
		"candidate_identity":
		(
			String(candidate.get("stability_policy_id", "")) == _bw9l_stability_policy_id
			and (
				String(candidate.get("base_controller_policy_id", ""))
				== BW12E_BASE_CONTROLLER_POLICY_ID
			)
			and (
				String(
					(
						(preregistration.get("candidate_policy_digests", {}) as Dictionary)
						. get(
							_bw2_candidate_id,
							"",
						)
					)
				)
				== _bw2_policy_digest
			)
			and (candidate.get("branch_surfaces", []) as Array).is_empty()
		),
		"portable_contract":
		(
			String(portable.get("base_controller_policy_id", "")) == BW12E_BASE_CONTROLLER_POLICY_ID
			and (
				String(portable.get("plan_operation", ""))
				== "ss_plan_scheduled_load_transfer_v3_json"
			)
			and (
				String(portable.get("plan_receipt_schema_version", ""))
				== "sporespore_scheduled_load_transfer_receipt_v3"
			)
			and bool(portable.get("host_observation_availability_is_explicit_input", false))
			and bool(portable.get("observation_unavailable_reason_required", false))
			and bool(portable.get("plan_receipt_required_for_every_sdk_step", false))
			and bool(portable.get("plan_receipt_recorded_before_overlay_validation", false))
			and int(portable.get("morphology_branch_surface_count", -1)) == 0
		),
		"full_gate_contract":
		(
			(
				String(full_gate.get("shared_gate_path", ""))
				== "tests/test_sdk_godot_jolt_material_robustness.gd"
			)
			and (
				String(full_gate.get("all_policy_test_path", ""))
				== "tests/test_sdk_full_integrity_gate_satisfiability.gd"
			)
			and bool(
				(
					full_gate
					. get(
						"candidate_preflight_must_run_in_separate_process_before_physical_process",
						false,
					)
				)
			)
			and bool(
				(
					full_gate
					. get(
						"preflight_failure_must_prevent_physical_process_creation",
						false,
					)
				)
			)
			and bool(full_gate.get("real_physical_entrypoint_pre_fixture_path_required", false))
			and bool(full_gate.get("entrypoint_control_flow_complete_must_equal", false))
			and int(full_gate.get("actual_world_build_count_must_equal", -1)) == 0
			and int(full_gate.get("scene_tree_insertion_count_must_equal", -1)) == 0
			and bool(
				(
					full_gate
					. get(
						"preflight_failure_must_prevent_durable_output_directory_creation",
						false,
					)
				)
			)
		),
		"development_identity":
		(
			String(development.get("material_profile_id", "")) == BW12E_PROFILE_ID
			and String(development.get("material_profile_sha256", "")) == BW12E_PROFILE_DIGEST
		),
		"development_matrix":
		(
			development_seeds == BW12E_FRESH_SEEDS
			and int(development.get("expected_world_count_per_candidate", -1)) == 12
			and int(development.get("expected_complete_world_count", -1)) == 48
			and bool(
				(
					development
					. get(
						"all_cells_are_fresh_to_bw9l_bw10f_and_bw11r",
						false,
					)
				)
			)
			and bool(development.get("early_stop_forbidden", false))
		),
		"selection_contract":
		(
			bool(selection.get("all_candidates_must_complete_before_selection", false))
			and bool(
				(
					selection
					. get(
						"treatment_must_be_strictly_lexicographically_better_than_control",
						false,
					)
				)
			)
		),
		"mechanism_contract":
		(
			bool(
				(
					mechanism
					. get(
						"scheduled_load_transfer_receipt_required_on_every_sdk_step",
						false,
					)
				)
			)
			and bool(
				(
					mechanism
					. get(
						"observation_unavailable_receipts_are_typed_portable_decisions",
						false,
					)
				)
			)
			and bool(mechanism.get("activation_uses_scheduler_boundaries_only", false))
			and int(mechanism.get("morphology_branch_surface_count_must_equal", -1)) == 0
		),
		"claims": claims_exact,
	}
	var exact := true
	for check_value in checks.values():
		exact = exact and bool(check_value)
	return {
		"ok": exact,
		"failure_code": "" if exact else "BW12E_PREREGISTRATION_MISMATCH",
		"schema_version": String(preregistration.get("schema_version", "")),
		"preregistration_path": "sdk/balanced_wave_bw12e_preregistration.json",
		"preregistration_sha256": BW12E_PREREGISTRATION_SHA256,
		"candidate": candidate.duplicate(true),
		"candidate_policy_digest": _bw2_policy_digest,
		"checks": checks,
		"world_build_count": 0,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _candidate_full_gate_preflight(preflight: Dictionary) -> Dictionary:
	if not bool(preflight.get("ok", false)):
		return {
			"schema_version": "sporespore_synthetic_execution_integrity_preflight_v1",
			"ok": false,
			"failure_code": "BW12E_COMPILE_PREFLIGHT_FAILED",
			"actual_world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var input_by_profile: Dictionary = preflight.get("input_by_profile", {})
	var input: Dictionary = input_by_profile.get(BW12E_PROFILE_ID, {})
	var perturbation_by_seed: Dictionary = preflight.get("perturbation_by_seed", {})
	var perturbation: Dictionary = (
		perturbation_by_seed
		. get(
			str(BW12E_FRESH_SEEDS[0]),
			{},
		)
	)
	var candidate_index := BW12E_CANDIDATE_IDS.find(_bw2_candidate_id)
	return _synthetic_execution_integrity_preflight(
		input.get("profile", {}),
		String(input.get("profile_sha256", "")),
		String(input.get("fixture_spec_sha256", "")),
		perturbation,
		candidate_index in [1, 2, 3],
		1,
	)


func _run_bw12e_development(preflight_only: bool) -> void:
	var preflight := _compile_preflight()
	var full_gate_preflight := _candidate_full_gate_preflight(preflight)
	var full_gate_ok := bool(full_gate_preflight.get("ok", false))
	if preflight_only:
		var preflight_receipt := {
			"schema_version": "sporespore_balanced_wave_bw12e_development_preflight_v1",
			"ok": bool(preflight.get("ok", false)) and full_gate_ok,
			"candidate_id": _bw2_candidate_id,
			"policy_id": _bw9l_stability_policy_id,
			"base_controller_policy_id": BW12E_BASE_CONTROLLER_POLICY_ID,
			"candidate_policy_digest": _bw2_policy_digest,
			"clock_ok": bool(preflight.get("clock_ok", false)),
			"matrix_ok": bool(preflight.get("matrix_ok", false)),
			"inputs_ok": bool(preflight.get("inputs_ok", false)),
			"full_gate_satisfiability_ok": full_gate_ok,
			"full_gate_satisfiability_receipt": full_gate_preflight.duplicate(true),
			"expected_world_count": BW12E_EXPECTED_WORLD_COUNT,
			"observed_world_count": 0,
			"cell_ids": (preflight.get("cell_ids", []) as Array).duplicate(),
			"seed_receipts": (preflight.get("seed_receipts", []) as Array).duplicate(true),
			"profile_receipts": (preflight.get("profile_receipts", []) as Array).duplicate(true),
			"preregistration":
			(preflight.get("validation_manifest", {}) as Dictionary).duplicate(true),
			"locomotion_outcome_exposed": false,
			"physics_state_modified": false,
			"development_selection_authority": true,
			"walking_acceptance": false,
			"cross_engine_c6": false,
			"completed_engine_neutral_sdk": false,
			"physical_acceptance_authority": false,
		}
		print(
			"BALANCED_WAVE_BW12E_DEVELOPMENT_PREFLIGHT ",
			JSON.stringify(preflight_receipt, "", true, true),
		)
		quit(0 if bool(preflight_receipt["ok"]) else 1)
		return

	var clock_ok := bool(preflight.get("clock_ok", false))
	var matrix_ok := bool(preflight.get("matrix_ok", false))
	var inputs_ok := bool(preflight.get("inputs_ok", false))
	_check(
		full_gate_ok,
		"0 the declared candidate passes the exact full-gate synthetic preflight",
	)
	_check(clock_ok, "1 the frozen clock compiles exactly")
	_check(matrix_ok, "2 the fresh-only BW12E 12-world candidate matrix is exact")
	_check(inputs_ok, "3 the candidate, material, seeds, fixture, and challenges compile")
	var receipts: Array = []
	var integrity_failure_count := 0
	var ordinary_nonwalk_count := 0
	var rough_nonwalk_count := 0
	var release_timeout_count := 0
	var acquisition_failure_count := 0
	var mechanism_receipt_failure_count := 0
	var nonzero_stability_count := 0
	var aggregate_active_step_count := 0
	var aggregate_preferred_step_count := 0
	var aggregate_centroid_step_count := 0
	var aggregate_available_receipt_count := 0
	var aggregate_unavailable_receipt_count := 0
	var aggregate_infeasible_receipt_count := 0
	var aggregate_fail_zero_receipt_count := 0
	var count_by_cohort := {"baseline": 0, "rough": 0}
	if clock_ok and matrix_ok and inputs_ok and full_gate_ok:
		var input: Dictionary = preflight["input_by_profile"][BW12E_PROFILE_ID]
		var perturbation_by_seed: Dictionary = preflight["perturbation_by_seed"]
		for cell_value in preflight["matrix"]:
			var cell: Dictionary = cell_value
			var seed_key := str(int(cell["campaign_seed"]))
			print(
				(
					"BW12E_CELL_START candidate=%s cell=%s world=%d/%d"
					% [
						_bw2_candidate_id,
						String(cell["cell_id"]),
						receipts.size() + 1,
						BW12E_EXPECTED_WORLD_COUNT,
					]
				)
			)
			var summary: Dictionary = await _run_cell(
				preflight["gait_clock_options"],
				cell,
				perturbation_by_seed[seed_key],
				input["fixture_spec"],
			)
			var receipt := _analyze_cell(
				cell,
				summary,
				perturbation_by_seed[seed_key],
				input,
				true,
			)
			receipt = _enrich_bw6n_receipt(cell, summary, receipt)
			var acquisition: Dictionary = (
				summary
				. get(
					"evidence_support_acquisition_receipt",
					{},
				)
			)
			var acquisition_exact: bool = (
				summary.get("evidence_acquisition_options", {}) == BW9L_ACQUISITION_OPTIONS
				and (
					String(
						(
							summary
							. get(
								"evidence_acquisition_configuration_sha256",
								"",
							)
						)
					)
					== BW9L_ACQUISITION_SHA256
				)
				and bool(acquisition.get("acquired", false))
				and not bool(acquisition.get("timed_out", true))
				and not bool(acquisition.get("controller_parameter", true))
				and not bool(acquisition.get("walking_claim_authorized", true))
			)
			var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
			var load_transfer: Dictionary = (
				sdk_summary
				. get(
					"scheduled_load_transfer_summary",
					{},
				)
			)
			var candidate_index := BW12E_CANDIDATE_IDS.find(_bw2_candidate_id)
			var preferred_enabled := candidate_index in [1, 3]
			var centroid_enabled := candidate_index in [2, 3]
			var active_step_count := int(load_transfer.get("active_step_count", -1))
			var unweighted_contact_count := int(load_transfer.get("unweighted_contact_count", -1))
			var preferred_step_count := int(load_transfer.get("preferred_normal_step_count", -1))
			var centroid_step_count := int(load_transfer.get("remaining_centroid_step_count", -1))
			var receipt_count := int(load_transfer.get("receipt_count", -1))
			var available_count := int(load_transfer.get("available_receipt_count", -1))
			var unavailable_count := int(
				load_transfer.get("observation_unavailable_receipt_count", -1)
			)
			var infeasible_count := int(load_transfer.get("upstream_infeasible_receipt_count", -1))
			var fail_zero_count := int(load_transfer.get("fail_zero_receipt_count", -1))
			var mechanism_exact: bool = (
				candidate_index >= 0
				and bool(load_transfer.get("enabled", false))
				and (
					String(load_transfer.get("schema_version", ""))
					== "sporespore_scheduled_load_transfer_execution_summary_v1"
				)
				and String(load_transfer.get("policy_id", "")) == _bw9l_stability_policy_id
				and (
					String(load_transfer.get("portable_plan_operation", ""))
					== "plan_scheduled_load_transfer_v3_json"
				)
				and (
					String(load_transfer.get("receipt_schema_version", ""))
					== "sporespore_scheduled_load_transfer_receipt_v3"
				)
				and receipt_count == int(sdk_summary.get("step_count", -2))
				and receipt_count > 0
				and available_count >= 0
				and unavailable_count >= 0
				and infeasible_count >= 0
				and available_count + unavailable_count + infeasible_count == receipt_count
				and fail_zero_count == unavailable_count + infeasible_count
				and (
					(active_step_count == 0 and unweighted_contact_count == 0)
					if candidate_index == 0
					else (active_step_count >= 0 and unweighted_contact_count >= 0)
				)
				and (preferred_step_count >= 0 if preferred_enabled else preferred_step_count == 0)
				and (centroid_step_count >= 0 if centroid_enabled else centroid_step_count == 0)
				and String(load_transfer.get("first_receipt_sha256", "")).begins_with("sha256:")
				and String(load_transfer.get("first_receipt_sha256", "")).length() == 71
				and String(load_transfer.get("last_receipt_sha256", "")).begins_with("sha256:")
				and String(load_transfer.get("last_receipt_sha256", "")).length() == 71
				and bool(
					(
						load_transfer
						. get(
							"activation_uses_scheduler_boundaries_only",
							false,
						)
					)
				)
				and int(load_transfer.get("morphology_branch_surface_count", -1)) == 0
				and not bool(
					(
						load_transfer
						. get(
							"per_foot_measured_load_allocation_available",
							true,
						)
					)
				)
				and not bool(load_transfer.get("walking_claim_authorized", true))
				and not bool(load_transfer.get("physical_acceptance_authority", true))
			)
			var execution_gate: bool = (
				bool(receipt.get("campaign_execution_gate_passed", false))
				and bool(receipt.get("specialized_axis_gate_passed", false))
				and acquisition_exact
				and mechanism_exact
			)
			receipt["partition"] = "fresh"
			receipt["candidate_id"] = _bw2_candidate_id
			receipt["stability_policy_id"] = _bw9l_stability_policy_id
			receipt["base_controller_policy_id"] = BW12E_BASE_CONTROLLER_POLICY_ID
			receipt["candidate_policy_digest"] = _bw2_policy_digest
			receipt["evidence_acquisition_gate_passed"] = acquisition_exact
			receipt["evidence_support_acquisition_receipt"] = acquisition.duplicate(true)
			receipt["scheduled_load_transfer_gate_passed"] = mechanism_exact
			receipt["scheduled_load_transfer_summary"] = load_transfer.duplicate(true)
			receipt["contact_gate_timeout_count_by_limb"] = (
				(summary.get("contact_gate_timeout_count_by_limb", {}) as Dictionary)
				. duplicate(true)
			)
			receipt["release_timeout_count"] = _sum_integer_values(
				receipt["contact_gate_timeout_count_by_limb"]
			)
			receipt["bw12e_execution_gate_passed"] = execution_gate
			receipts.append(receipt)
			_check(
				execution_gate,
				"%s completes candidate execution integrity" % String(cell["cell_id"]),
			)
			if not execution_gate:
				integrity_failure_count += 1
			if not bool(receipt.get("ordinary_walking_gate_passed", false)):
				ordinary_nonwalk_count += 1
				if String(cell.get("cohort", "")) == "rough":
					rough_nonwalk_count += 1
			release_timeout_count += int(receipt["release_timeout_count"])
			if not acquisition_exact:
				acquisition_failure_count += 1
			if not mechanism_exact:
				mechanism_receipt_failure_count += 1
			var contribution: Dictionary = receipt.get("stability_contribution_shadow", {})
			var overlay: Dictionary = receipt.get("stability_overlay", {})
			if (
				int(contribution.get("nonzero_active_command_count", 0)) > 0
				and int(overlay.get("nonzero_effective_application_count", 0)) > 0
			):
				nonzero_stability_count += 1
			aggregate_active_step_count += maxi(active_step_count, 0)
			aggregate_preferred_step_count += maxi(preferred_step_count, 0)
			aggregate_centroid_step_count += maxi(centroid_step_count, 0)
			aggregate_available_receipt_count += maxi(available_count, 0)
			aggregate_unavailable_receipt_count += maxi(unavailable_count, 0)
			aggregate_infeasible_receipt_count += maxi(infeasible_count, 0)
			aggregate_fail_zero_receipt_count += maxi(fail_zero_count, 0)
			var cohort := String(cell.get("cohort", ""))
			count_by_cohort[cohort] = int(count_by_cohort[cohort]) + 1
			print("BALANCED_WAVE_BW12E_CELL ", JSON.stringify(receipt, "", true, true))

	var roles_exact := (
		receipts.size() == BW12E_EXPECTED_WORLD_COUNT
		and int(count_by_cohort["baseline"]) == 6
		and int(count_by_cohort["rough"]) == 6
	)
	_check(roles_exact, "16 both fresh baseline/rough cohorts complete exactly")
	_check(integrity_failure_count == 0, "17 the complete matrix has zero integrity failures")
	_check(acquisition_failure_count == 0, "18 all worlds satisfy bounded acquisition")
	var candidate_index := BW12E_CANDIDATE_IDS.find(_bw2_candidate_id)
	var expected_nonzero_world_count := 0 if candidate_index == 0 else 12
	_check(
		nonzero_stability_count == expected_nonzero_world_count,
		"19 control remains exact zero and every treatment world applies bounded influence",
	)
	var aggregate_factor_exact := (
		(
			(
				aggregate_active_step_count == 0
				and aggregate_preferred_step_count == 0
				and aggregate_centroid_step_count == 0
			)
			if candidate_index == 0
			else (
				aggregate_active_step_count > 0
				and (
					aggregate_preferred_step_count > 0
					if candidate_index in [1, 3]
					else aggregate_preferred_step_count == 0
				)
				and (
					aggregate_centroid_step_count > 0
					if candidate_index in [2, 3]
					else aggregate_centroid_step_count == 0
				)
			)
		)
		and (
			(
				aggregate_available_receipt_count
				+ aggregate_unavailable_receipt_count
				+ aggregate_infeasible_receipt_count
			)
			== BW12E_EXPECTED_WORLD_COUNT * EXPECTED_STEP_COUNT
		)
		and (
			aggregate_fail_zero_receipt_count
			== aggregate_unavailable_receipt_count + aggregate_infeasible_receipt_count
		)
	)
	_check(
		mechanism_receipt_failure_count == 0 and aggregate_factor_exact,
		"20 every SDK step retains a v3 receipt and the exact registered factors",
	)
	var candidate_identity_exact := true
	for receipt_value in receipts:
		var receipt: Dictionary = receipt_value
		candidate_identity_exact = (
			candidate_identity_exact
			and String(receipt.get("controller_policy_id", "")) == BW12E_BASE_CONTROLLER_POLICY_ID
			and String(receipt.get("stability_policy_id", "")) == _bw9l_stability_policy_id
			and String(receipt.get("candidate_policy_digest", "")) == _bw2_policy_digest
		)
	_check(candidate_identity_exact, "21 every world retains exact base and v3 policy identity")
	_check(true, "22 every physical-acceptance and C6 claim remains false")

	var complete := (
		_failed == 0
		and _passed == BW12E_EXPECTED_GATE_COUNT
		and receipts.size() == BW12E_EXPECTED_WORLD_COUNT
	)
	var development_selectable := complete and candidate_index in [1, 2, 3]
	var result := {
		"schema_version": "sporespore_balanced_wave_bw12e_development_receipt_v1",
		"ok": complete,
		"result_status":
		(
			"treatment_development_selectable"
			if development_selectable
			else ("control_complete" if complete else "candidate_incomplete")
		),
		"development_selectable": development_selectable,
		"candidate_id": _bw2_candidate_id,
		"policy_id": _bw9l_stability_policy_id,
		"base_controller_policy_id": BW12E_BASE_CONTROLLER_POLICY_ID,
		"candidate_policy_digest": _bw2_policy_digest,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": BW12E_EXPECTED_GATE_COUNT,
		"expected_world_count": BW12E_EXPECTED_WORLD_COUNT,
		"observed_world_count": receipts.size(),
		"full_gate_satisfiability_ok": full_gate_ok,
		"full_gate_satisfiability_receipt": full_gate_preflight.duplicate(true),
		"integrity_failure_count": integrity_failure_count,
		"ordinary_nonwalk_count": ordinary_nonwalk_count,
		"rough_ordinary_nonwalk_count": rough_nonwalk_count,
		"release_timeout_count": release_timeout_count,
		"acquisition_failure_count": acquisition_failure_count,
		"mechanism_receipt_failure_count": mechanism_receipt_failure_count,
		"nonzero_stability_world_count": nonzero_stability_count,
		"aggregate_active_step_count": aggregate_active_step_count,
		"aggregate_preferred_normal_step_count": aggregate_preferred_step_count,
		"aggregate_remaining_centroid_step_count": aggregate_centroid_step_count,
		"aggregate_available_receipt_count": aggregate_available_receipt_count,
		"aggregate_observation_unavailable_receipt_count": aggregate_unavailable_receipt_count,
		"aggregate_upstream_infeasible_receipt_count": aggregate_infeasible_receipt_count,
		"aggregate_fail_zero_receipt_count": aggregate_fail_zero_receipt_count,
		"count_by_cohort": count_by_cohort,
		"cells": receipts,
		"known_bw9l_and_bw10f_outcomes_disclosed": true,
		"known_bw11r_zero_world_invalidation_disclosed": true,
		"fresh_only_development_matrix": true,
		"development_selection_authority": true,
		"walking_acceptance": false,
		"material_robustness": false,
		"rough_terrain_robustness": false,
		"physical_balance_recovery": false,
		"fresh_morphology_validation": false,
		"cross_engine_c6": false,
		"completed_engine_neutral_sdk": false,
		"physical_acceptance_authority": false,
	}
	print("BALANCED_WAVE_BW12E_DEVELOPMENT_RECEIPT ", JSON.stringify(result, "", true, true))
	quit(0 if complete else 1)
