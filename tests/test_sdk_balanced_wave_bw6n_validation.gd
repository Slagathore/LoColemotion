extends "res://tests/test_sdk_balanced_wave_bw5c_validation.gd"

## BW6N prospective Godot/Jolt nuisance-acceptance harness.
##
## This campaign keeps BW5R-B, the reference morphology, the characterized
## 0.95 material profile, solver policy, clock, and three new seeds fixed. It
## opens exactly one baseline profile and three nuisance profiles: rough
## geometry, one external lateral impulse, and deterministic additive
## observation noise. Every profile has three fresh seeded worlds.

const BW6N_MANIFEST_PATH := "res://sdk/balanced_wave_bw6n_validation_manifest.json"
const BW6N_MANIFEST_SCHEMA := "sporespore_balanced_wave_bw6n_validation_manifest_v1"
const BW6N_MANIFEST_SHA256 := (
	"83886d8c893a4a6e5a960b06b3398d907a203a865e1ac66ed1870ea09dc3d38e"
)
const BW6N_PREFLIGHT_SCHEMA := (
	"sporespore_balanced_wave_bw6n_validation_preflight_receipt_v1"
)
const BW6N_RECEIPT_SCHEMA := "sporespore_balanced_wave_bw6n_validation_receipt_v1"
const BW6N_FREEZE_PARENT := "24ddd46db1ae86f7d2303cda76cd01fbdbb30f3f"
const BW6N_BW5C_REPORT_SHA256 := (
	"6648c1473c97d2b7229ba0decd8881ca2d8f06e68ca9737d7255120dab2653da"
)
const BW6N_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const BW6N_PROFILE_DIGEST := (
	"sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
)
const BW6N_SEEDS := [21001, 21002, 21003]
const BW6N_PROFILE_IDS := [
	"bw6n_baseline_v1",
	"bw6n_rough_v1",
	"bw6n_push_v1",
	"bw6n_sensor_noise_v1",
]
const BW6N_EXPECTED_CELL_IDS := [
	"baseline_s21001",
	"baseline_s21002",
	"baseline_s21003",
	"rough_s21001",
	"rough_s21002",
	"rough_s21003",
	"push_s21001",
	"push_s21002",
	"push_s21003",
	"sensor_noise_s21001",
	"sensor_noise_s21002",
	"sensor_noise_s21003",
]
const BW6N_EXPECTED_GATE_COUNT := 24
const BW6N_EXPECTED_WORLD_COUNT := 12
const BW6N_EXPECTED_AXIS_WORLD_COUNT := 3


func _run() -> void:
	print("\n=== SDK balanced-wave BW6N frozen Godot/Jolt nuisance acceptance ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var user_args := OS.get_cmdline_user_args()
	var allowed_args := ["--preflight-only", "--bw5r-b"]
	var arguments_valid := (
		user_args.has("--bw5r-b")
		and user_args.size() >= 1
		and user_args.size() <= 2
	)
	for argument_value in user_args:
		arguments_valid = arguments_valid and String(argument_value) in allowed_args
	if not arguments_valid:
		push_error("BW6N requires --bw5r-b and accepts optional --preflight-only")
		quit(1)
		return
	_bw2_mode = true
	_bw2_candidate_id = BW5C_CANDIDATE_ID
	_bw2_policy_id = BW5C_POLICY_ID
	_bw2_policy_digest = BW5C_POLICY_DIGEST
	_opened_development_replay = false
	await _run_bw6n_validation(user_args.has("--preflight-only"))


func _campaign_seeds() -> Array:
	return BW6N_SEEDS


func _required_profile_ids() -> Array:
	return [BW6N_PROFILE_ID]


func _expected_cell_ids() -> Array:
	return BW6N_EXPECTED_CELL_IDS


func _expected_world_count() -> int:
	return BW6N_EXPECTED_WORLD_COUNT


func _bridge_profile_id() -> String:
	return BW6N_PROFILE_ID


func _build_matrix() -> Array:
	var manifest := _load_json_dictionary(BW6N_MANIFEST_PATH)
	var profile_by_id := {}
	for profile_value in manifest.get("challenge_profiles", []):
		var requested: Dictionary = profile_value
		var compiled := WaveGaitScript.compile_environment_challenge_options(requested)
		if bool(compiled.get("ok", false)):
			profile_by_id[String(requested.get("challenge_profile_id", ""))] = (
				compiled["environment_challenge_options"]
			)
	var matrix: Array = []
	for profile_id_value in BW6N_PROFILE_IDS:
		var profile_id := String(profile_id_value)
		var cell_prefix := profile_id.trim_prefix("bw6n_").trim_suffix("_v1")
		for seed_value in BW6N_SEEDS:
			var seed := int(seed_value)
			matrix.append(
				{
					"cell_id": "%s_s%d" % [cell_prefix, seed],
					"cohort": cell_prefix,
					"mode": "treatment",
					"campaign_seed": seed,
					"mu_token": "095",
					"authored_friction": 0.95,
					"profile_id": BW6N_PROFILE_ID,
					"profile_digest": BW6N_PROFILE_DIGEST,
					"challenge_profile_id": profile_id,
					"challenge_options":
					(profile_by_id.get(profile_id, {}) as Dictionary).duplicate(true),
				}
			)
	return matrix


func _matrix_cardinality_exact(matrix: Array) -> bool:
	var count_by_cohort := {
		"baseline": 0,
		"rough": 0,
		"push": 0,
		"sensor_noise": 0,
	}
	for cell_value in matrix:
		var cell: Dictionary = cell_value
		var cohort := String(cell.get("cohort", ""))
		if (
			not count_by_cohort.has(cohort)
			or String(cell.get("mode", "")) != "treatment"
			or (cell.get("challenge_options", {}) as Dictionary).is_empty()
		):
			return false
		count_by_cohort[cohort] = int(count_by_cohort[cohort]) + 1
	return (
		matrix.size() == BW6N_EXPECTED_WORLD_COUNT
		and int(count_by_cohort["baseline"]) == BW6N_EXPECTED_AXIS_WORLD_COUNT
		and int(count_by_cohort["rough"]) == BW6N_EXPECTED_AXIS_WORLD_COUNT
		and int(count_by_cohort["push"]) == BW6N_EXPECTED_AXIS_WORLD_COUNT
		and int(count_by_cohort["sensor_noise"]) == BW6N_EXPECTED_AXIS_WORLD_COUNT
	)


func _validation_manifest_receipt() -> Dictionary:
	var manifest := _load_json_dictionary(BW6N_MANIFEST_PATH)
	if manifest.is_empty():
		return _manifest_failure("BW6N_VALIDATION_MANIFEST_UNREADABLE")
	var profiles: Array = manifest.get("challenge_profiles", [])
	var compiled_profiles: Array = []
	var profile_ids: Array = []
	var profiles_compile := profiles.size() == BW6N_PROFILE_IDS.size()
	for profile_value in profiles:
		var profile: Dictionary = profile_value
		var compiled := WaveGaitScript.compile_environment_challenge_options(profile)
		profiles_compile = profiles_compile and bool(compiled.get("ok", false))
		profile_ids.append(String(profile.get("challenge_profile_id", "")))
		if bool(compiled.get("ok", false)):
			compiled_profiles.append(
				{
					"challenge_profile_id":
					String(profile.get("challenge_profile_id", "")),
					"configuration_sha256":
					String(compiled["environment_challenge_configuration_sha256"]),
					"configuration":
					(
						compiled["environment_challenge_options"]
						as Dictionary
					).duplicate(true),
				}
			)
	var prerequisite: Dictionary = (
		manifest.get("prerequisite_evidence", {}).get("bw5c_cold_acceptance", {})
	)
	var prerequisite_path := String(prerequisite.get("path", ""))
	var selected_policy := _load_json_dictionary(BW5C_SELECTED_POLICY_PATH)
	var matrix: Dictionary = manifest.get("matrix", {})
	var gates: Dictionary = manifest.get("gate_contract", {})
	var claims_if_accepted: Dictionary = manifest.get("claims_if_accepted", {})
	var claims_always_false: Dictionary = manifest.get("claims_always_false", {})
	var metadata_exact := (
		String(manifest.get("schema_version", "")) == BW6N_MANIFEST_SCHEMA
		and String(manifest.get("status", "")) == "frozen_before_first_bw6n_world"
		and String(manifest.get("freeze_parent_commit", "")) == BW6N_FREEZE_PARENT
		and (
			String(manifest.get("campaign_partition", ""))
			== "prospective_nuisance_acceptance"
		)
		and not bool(manifest.get("locomotion_outcome_exposed", true))
		and _file_hash_exact(BW6N_MANIFEST_PATH, BW6N_MANIFEST_SHA256)
	)
	var policy_exact := (
		String(selected_policy.get("selected_candidate_id", "")) == BW5C_CANDIDATE_ID
		and String(selected_policy.get("selected_policy_id", "")) == BW5C_POLICY_ID
		and (
			String(selected_policy.get("selected_candidate_policy_digest", ""))
			== BW5C_POLICY_DIGEST
		)
		and (
			String((manifest.get("selected_policy", {}) as Dictionary).get(
				"candidate_id", ""
			))
			== BW5C_CANDIDATE_ID
		)
		and (
			String((manifest.get("selected_policy", {}) as Dictionary).get(
				"policy_id", ""
			))
			== BW5C_POLICY_ID
		)
		and (
			String((manifest.get("selected_policy", {}) as Dictionary).get(
				"policy_digest", ""
			))
			== BW5C_POLICY_DIGEST
		)
	)
	var prerequisite_exact := (
		_file_hash_exact(prerequisite_path, BW6N_BW5C_REPORT_SHA256)
		and String(prerequisite.get("sha256", "")) == BW6N_BW5C_REPORT_SHA256
		and bool(prerequisite.get("accepted", false))
		and int(prerequisite.get("observed_world_count", -1)) == 17
		and int(prerequisite.get("passed_gate_count", -1)) == 28
	)
	var material: Dictionary = manifest.get("material_profile", {})
	var material_exact := (
		String(material.get("profile_id", "")) == BW6N_PROFILE_ID
		and String(material.get("profile_digest", "")) == BW6N_PROFILE_DIGEST
		and absf(float(material.get("authored_friction", NAN)) - 0.95) <= 1.0e-12
		and (
			absf(float(material.get("characterized_friction_coefficient", NAN)) - 0.94)
			<= 1.0e-12
		)
	)
	var manifest_seeds: Array = []
	for seed_value in matrix.get("seeds", []):
		manifest_seeds.append(int(seed_value))
	var manifest_cell_ids: Array = []
	for cell_id_value in matrix.get("ordered_cell_ids", []):
		manifest_cell_ids.append(String(cell_id_value))
	var matrix_exact: bool = (
		manifest_seeds == BW6N_SEEDS
		and manifest_cell_ids == BW6N_EXPECTED_CELL_IDS
		and int(matrix.get("expected_baseline_world_count", -1)) == 3
		and int(matrix.get("expected_rough_world_count", -1)) == 3
		and int(matrix.get("expected_push_world_count", -1)) == 3
		and int(matrix.get("expected_sensor_noise_world_count", -1)) == 3
		and int(matrix.get("expected_world_count", -1)) == BW6N_EXPECTED_WORLD_COUNT
		and int(matrix.get("expected_sdk_exposure_steps", -1)) == EXPECTED_STEP_COUNT
		and bool(matrix.get("averaging_forbidden", false))
		and bool(matrix.get("failed_cell_replacement_forbidden", false))
		and bool(matrix.get("post_result_gate_edit_forbidden", false))
		and bool(matrix.get("first_result_is_final_for_this_source_identity", false))
	)
	var gates_exact: bool = (
		int(gates.get("expected_gate_count", -1)) == BW6N_EXPECTED_GATE_COUNT
		and int(gates.get("preflight_gate_count", -1)) == 3
		and int(gates.get("per_world_execution_integrity_gate_count", -1)) == 12
		and int(gates.get("aggregate_gate_count", -1)) == 9
		and (gates.get("aggregate_gates", []) as Array).size() == 9
	)
	var claims_exact: bool = (
		bool(claims_if_accepted.get("godot_jolt_nuisance_acceptance", false))
		and bool(claims_if_accepted.get("rough_terrain_robustness", false))
		and bool(claims_if_accepted.get("external_push_recovery", false))
		and bool(claims_if_accepted.get("sensor_noise_robustness", false))
		and bool(claims_if_accepted.get("physical_balance_recovery", false))
		and _all_claim_values_false(claims_always_false)
	)
	var ok: bool = (
		metadata_exact
		and policy_exact
		and prerequisite_exact
		and material_exact
		and profiles_compile
		and profile_ids == BW6N_PROFILE_IDS
		and compiled_profiles.size() == BW6N_PROFILE_IDS.size()
		and matrix_exact
		and gates_exact
		and claims_exact
	)
	return {
		"ok": ok,
		"failure_code": "" if ok else "BW6N_VALIDATION_MANIFEST_MISMATCH",
		"schema_version": String(manifest.get("schema_version", "")),
		"manifest_path": "sdk/balanced_wave_bw6n_validation_manifest.json",
		"manifest_sha256": BW6N_MANIFEST_SHA256,
		"metadata_exact": metadata_exact,
		"policy_exact": policy_exact,
		"prerequisite_exact": prerequisite_exact,
		"material_exact": material_exact,
		"profiles_compile": profiles_compile,
		"profile_ids": profile_ids,
		"compiled_profiles": compiled_profiles,
		"matrix_exact": matrix_exact,
		"gates_exact": gates_exact,
		"claims_exact": claims_exact,
		"world_build_count": 0,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _run_cell(
	gait_clock_options: Dictionary,
	cell: Dictionary,
	perturbation: Dictionary,
	fixture_spec: Dictionary,
) -> Dictionary:
	var authority_options := {
		"enabled": true,
		"descriptor": DESCRIPTOR,
		"comparison_tolerance": GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
		"authority_scope": "stability_contribution_overlay",
		"stability_policy_id": FEEDBACK_POLICY_ID,
		"material_profile_id": BW6N_PROFILE_ID,
		"controller_policy_id": BW5C_POLICY_ID,
	}
	return await (
		WaveGaitScript
		. new()
		. run(
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
			perturbation,
			ROBUSTNESS_OPTIONS,
			fixture_spec,
			PATH_STEERING_OPTIONS,
			ACTUATOR_IMPULSE_OPTIONS,
			MOTOR_VELOCITY_OPTIONS,
			{},
			gait_clock_options,
			SOLVER_POLICY_OPTIONS,
			{},
			{},
			authority_options,
			cell["challenge_options"],
		)
	)


func _run_bw6n_validation(preflight_only: bool) -> void:
	var preflight := _compile_preflight()
	if preflight_only:
		var receipt := _bw6n_preflight_receipt(preflight)
		print(
			"BALANCED_WAVE_BW6N_VALIDATION_PREFLIGHT_RECEIPT ",
			JSON.stringify(receipt, "", true, true),
		)
		quit(0 if bool(receipt.get("ok", false)) else 1)
		return
	var clock_ok := bool(preflight.get("clock_ok", false))
	var matrix_ok := bool(preflight.get("matrix_ok", false))
	var inputs_ok := bool(preflight.get("inputs_ok", false))
	_check(clock_ok, "1 the frozen GQ15 clock compiles exactly")
	_check(matrix_ok, "2 the frozen ordered BW6N 12-world matrix is exact")
	_check(
		inputs_ok,
		"3 the prerequisite, policy, material, seeds, fixture, and challenges compile",
	)
	if not (clock_ok and matrix_ok and inputs_ok):
		_emit_bw6n_receipt(preflight, [], {}, {})
		_finish_bw6n()
		return
	var matrix: Array = preflight["matrix"]
	var gait_clock_options: Dictionary = preflight["gait_clock_options"]
	var perturbation_by_seed: Dictionary = preflight["perturbation_by_seed"]
	var input: Dictionary = preflight["input_by_profile"][BW6N_PROFILE_ID]
	var receipts: Array = []
	var receipt_by_cell_id := {}
	var integrity_failure_count := 0
	var count_by_cohort := {
		"baseline": 0,
		"rough": 0,
		"push": 0,
		"sensor_noise": 0,
	}
	var pass_by_cohort := {
		"baseline": 0,
		"rough": 0,
		"push": 0,
		"sensor_noise": 0,
	}
	var nonzero_stability_count := 0
	for cell_value in matrix:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		var seed_key := str(int(cell["campaign_seed"]))
		print(
			"BW6N_VALIDATION_CELL_START ",
			cell_id,
			" world=",
			receipts.size() + 1,
			"/",
			BW6N_EXPECTED_WORLD_COUNT,
		)
		var summary: Dictionary = await _run_cell(
			gait_clock_options,
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
		receipts.append(receipt)
		receipt_by_cell_id[cell_id] = receipt
		var execution_ok := bool(receipt.get("bw6n_execution_gate_passed", false))
		_check(execution_ok, "%s completes its frozen challenge execution gate" % cell_id)
		if not execution_ok:
			integrity_failure_count += 1
		var cohort := String(cell["cohort"])
		count_by_cohort[cohort] = int(count_by_cohort[cohort]) + 1
		if bool(receipt.get("ordinary_walking_gate_passed", false)):
			pass_by_cohort[cohort] = int(pass_by_cohort[cohort]) + 1
		var contribution: Dictionary = receipt.get("stability_contribution_shadow", {})
		var overlay: Dictionary = receipt.get("stability_overlay", {})
		if (
			int(contribution.get("nonzero_active_command_count", 0)) > 0
			and int(overlay.get("nonzero_effective_application_count", 0)) > 0
		):
			nonzero_stability_count += 1
		print(
			"BALANCED_WAVE_BW6N_VALIDATION_CELL ",
			JSON.stringify(receipt, "", true, true),
		)
	var roles_exact := (
		receipts.size() == BW6N_EXPECTED_WORLD_COUNT
		and int(count_by_cohort["baseline"]) == 3
		and int(count_by_cohort["rough"]) == 3
		and int(count_by_cohort["push"]) == 3
		and int(count_by_cohort["sensor_noise"]) == 3
	)
	_check(roles_exact, "16 exact baseline/rough/push/sensor cardinality completes")
	var integrity_complete := integrity_failure_count == 0
	_check(integrity_complete, "17 the complete matrix has zero integrity failures")
	var walking_complete := _all_cohort_counts(pass_by_cohort, 3)
	_check(walking_complete, "18 all 12 worlds pass every ordinary physical walking gate")
	var rough_complete := _all_specialized_axis_gates(receipts, "rough")
	_check(rough_complete, "19 all three rough worlds realize the frozen 64-tile geometry")
	var push_complete := _all_specialized_axis_gates(receipts, "push")
	_check(push_complete, "20 all three push worlds apply one measurable external impulse")
	var sensor_complete := _all_specialized_axis_gates(receipts, "sensor_noise")
	_check(
		sensor_complete,
		"21 all three sensor worlds fault base and stability observations for 1514 steps",
	)
	var stability_complete := nonzero_stability_count == BW6N_EXPECTED_WORLD_COUNT
	_check(stability_complete, "22 all 12 worlds apply nonzero bounded stability influence")
	var matched_pairs := _matched_challenge_receipts(receipt_by_cell_id)
	var pairs_complete := matched_pairs.size() == 9 and _all_pair_gates_pass(matched_pairs)
	_check(pairs_complete, "23 all nine challenges retain exact matched-baseline identity")
	var broader_claims_false := _all_claim_values_false(
		(_load_json_dictionary(BW6N_MANIFEST_PATH).get("claims_always_false", {}) as Dictionary)
	)
	_check(broader_claims_false, "24 every out-of-scope C6 and SDK claim remains false")
	_emit_bw6n_receipt(
		preflight,
		receipts,
		{
			"roles_exact": roles_exact,
			"integrity_complete": integrity_complete,
			"walking_complete": walking_complete,
			"rough_complete": rough_complete,
			"push_complete": push_complete,
			"sensor_complete": sensor_complete,
			"stability_complete": stability_complete,
			"pairs_complete": pairs_complete,
			"broader_claims_false": broader_claims_false,
			"integrity_failure_count": integrity_failure_count,
			"count_by_cohort": count_by_cohort,
			"pass_by_cohort": pass_by_cohort,
			"nonzero_stability_count": nonzero_stability_count,
		},
		{"matched_pairs": matched_pairs},
	)
	_finish_bw6n()


func _enrich_bw6n_receipt(
	cell: Dictionary,
	summary: Dictionary,
	receipt: Dictionary,
) -> Dictionary:
	var result := receipt.duplicate(true)
	var expected_options: Dictionary = cell["challenge_options"]
	var expected_compile: Dictionary = WaveGaitScript.compile_environment_challenge_options(
		expected_options
	)
	var expected_digest := String(
		expected_compile.get("environment_challenge_configuration_sha256", "")
	)
	var options_exact: bool = (
		bool(expected_compile.get("ok", false))
		and summary.get("environment_challenge_options", {}) == expected_options
		and (
			String(summary.get("environment_challenge_configuration_sha256", ""))
			== expected_digest
		)
	)
	var cohort := String(cell["cohort"])
	var axis_gate: bool = options_exact
	match cohort:
		"baseline":
			axis_gate = (
				axis_gate
				and int(summary.get("terrain_shape_count", -1)) == 1
				and int(summary.get("external_push_application_count", -1)) == 0
				and int(summary.get("observation_fault_application_count", -1)) == 0
			)
		"rough":
			axis_gate = (
				axis_gate
				and int(summary.get("terrain_shape_count", -1)) == 64
				and int(summary.get("external_push_application_count", -1)) == 0
				and int(summary.get("observation_fault_application_count", -1)) == 0
			)
		"push":
			var push_receipt: Dictionary = summary.get("external_push_receipt", {})
			axis_gate = (
				axis_gate
				and int(summary.get("terrain_shape_count", -1)) == 1
				and int(summary.get("external_push_application_count", -1)) == 1
				and bool(push_receipt.get("effect_sampled", false))
				and (
					float(
						push_receipt.get(
							"observed_next_tick_velocity_delta_magnitude_m_s",
							0.0,
						)
					)
					> 1.0e-4
				)
				and not bool(push_receipt.get("controller_command", true))
			)
		"sensor_noise":
			axis_gate = (
				axis_gate
				and int(summary.get("terrain_shape_count", -1)) == 1
				and int(summary.get("external_push_application_count", -1)) == 0
				and (
					int(summary.get("observation_fault_application_count", -1))
					== EXPECTED_STEP_COUNT
				)
				and (
					int(summary.get("observation_fault_base_and_stability_count", -1))
					== EXPECTED_STEP_COUNT
				)
				and float(summary.get("maximum_observation_fault_component", 0.0)) > 0.0
			)
	var ordinary_walking := bool(result.get("treatment_gate_passed", false))
	result["challenge_profile_id"] = String(cell["challenge_profile_id"])
	result["challenge_configuration_sha256"] = expected_digest
	result["challenge_options_exact"] = options_exact
	result["specialized_axis_gate_passed"] = axis_gate
	result["ordinary_walking_gate_passed"] = ordinary_walking
	result["terrain_shape_count"] = int(summary.get("terrain_shape_count", -1))
	result["external_push_application_count"] = int(
		summary.get("external_push_application_count", -1)
	)
	result["external_push_receipt"] = (
		summary.get("external_push_receipt", {}) as Dictionary
	).duplicate(true)
	result["observation_fault_application_count"] = int(
		summary.get("observation_fault_application_count", -1)
	)
	result["observation_fault_base_and_stability_count"] = int(
		summary.get("observation_fault_base_and_stability_count", -1)
	)
	result["maximum_observation_fault_component"] = float(
		summary.get("maximum_observation_fault_component", INF)
	)
	result["bw6n_execution_gate_passed"] = (
		bool(result.get("campaign_execution_gate_passed", false))
		and ordinary_walking
		and axis_gate
	)
	return result


static func _all_cohort_counts(counts: Dictionary, expected: int) -> bool:
	for count_value in counts.values():
		if int(count_value) != expected:
			return false
	return counts.size() == 4


static func _all_specialized_axis_gates(receipts: Array, cohort: String) -> bool:
	var observed := 0
	for receipt_value in receipts:
		var receipt: Dictionary = receipt_value
		if String(receipt.get("cohort", "")) != cohort:
			continue
		observed += 1
		if not bool(receipt.get("specialized_axis_gate_passed", false)):
			return false
	return observed == BW6N_EXPECTED_AXIS_WORLD_COUNT


static func _matched_challenge_receipts(receipt_by_cell_id: Dictionary) -> Array:
	var pairs: Array = []
	for cohort in ["rough", "push", "sensor_noise"]:
		for seed_value in BW6N_SEEDS:
			var seed := int(seed_value)
			var baseline: Dictionary = receipt_by_cell_id.get("baseline_s%d" % seed, {})
			var challenge: Dictionary = receipt_by_cell_id.get(
				"%s_s%d" % [cohort, seed],
				{},
			)
			var identity_exact: bool = (
				not baseline.is_empty()
				and not challenge.is_empty()
				and int(baseline.get("campaign_seed", -1)) == seed
				and int(challenge.get("campaign_seed", -1)) == seed
				and baseline.get("initial_perturbation", {}) == challenge.get(
					"initial_perturbation", {}
				)
				and String(baseline.get("profile_sha256", ""))
				== String(challenge.get("profile_sha256", ""))
				and String(baseline.get("fixture_spec_sha256", ""))
				== String(challenge.get("fixture_spec_sha256", ""))
				and String(baseline.get("controller_policy_id", ""))
				== String(challenge.get("controller_policy_id", ""))
				and String(baseline.get("challenge_configuration_sha256", ""))
				!= String(challenge.get("challenge_configuration_sha256", ""))
			)
			pairs.append(
				{
					"pair_id": "%s_s%d_pair" % [cohort, seed],
					"baseline_cell_id": "baseline_s%d" % seed,
					"challenge_cell_id": "%s_s%d" % [cohort, seed],
					"identity_gate_passed": identity_exact,
					"baseline_walking_gate_passed":
					bool(baseline.get("ordinary_walking_gate_passed", false)),
					"challenge_walking_gate_passed":
					bool(challenge.get("ordinary_walking_gate_passed", false)),
					"pair_gate_passed":
					(
						identity_exact
						and bool(baseline.get("ordinary_walking_gate_passed", false))
						and bool(challenge.get("ordinary_walking_gate_passed", false))
					),
				}
			)
	return pairs


static func _all_pair_gates_pass(pairs: Array) -> bool:
	for pair_value in pairs:
		if not bool((pair_value as Dictionary).get("pair_gate_passed", false)):
			return false
	return not pairs.is_empty()


func _bw6n_preflight_receipt(preflight: Dictionary) -> Dictionary:
	var manifest_receipt: Dictionary = preflight.get("validation_manifest", {})
	return {
		"schema_version": BW6N_PREFLIGHT_SCHEMA,
		"ok": bool(preflight.get("ok", false)),
		"candidate_id": _bw2_candidate_id,
		"policy_id": _bw2_policy_id,
		"candidate_policy_digest": _bw2_policy_digest,
		"clock_ok": bool(preflight.get("clock_ok", false)),
		"matrix_ok": bool(preflight.get("matrix_ok", false)),
		"inputs_ok": bool(preflight.get("inputs_ok", false)),
		"expected_world_count": BW6N_EXPECTED_WORLD_COUNT,
		"observed_world_count": 0,
		"cell_ids": (preflight.get("cell_ids", []) as Array).duplicate(),
		"seed_receipts": (preflight.get("seed_receipts", []) as Array).duplicate(true),
		"profile_receipts": (preflight.get("profile_receipts", []) as Array).duplicate(true),
		"validation_manifest": manifest_receipt.duplicate(true),
		"locomotion_outcome_exposed": false,
		"adapter_actuation_applied": false,
		"physics_state_modified": false,
		"godot_jolt_nuisance_acceptance": false,
		"rough_terrain_robustness": false,
		"external_push_recovery": false,
		"sensor_noise_robustness": false,
		"physical_balance_recovery": false,
		"cross_engine_c6": false,
		"completed_engine_neutral_sdk": false,
		"physical_acceptance_authority": false,
	}


func _emit_bw6n_receipt(
	preflight: Dictionary,
	cells: Array,
	metrics: Dictionary,
	extra: Dictionary,
) -> void:
	var accepted := (
		_failed == 0
		and _passed == BW6N_EXPECTED_GATE_COUNT
		and bool(metrics.get("roles_exact", false))
		and bool(metrics.get("integrity_complete", false))
		and bool(metrics.get("walking_complete", false))
		and bool(metrics.get("rough_complete", false))
		and bool(metrics.get("push_complete", false))
		and bool(metrics.get("sensor_complete", false))
		and bool(metrics.get("stability_complete", false))
		and bool(metrics.get("pairs_complete", false))
		and bool(metrics.get("broader_claims_false", false))
	)
	var receipt := {
		"schema_version": BW6N_RECEIPT_SCHEMA,
		"ok": accepted,
		"accepted": accepted,
		"result": "nuisance_acceptance_passed" if accepted else "nuisance_acceptance_rejected",
		"candidate_id": _bw2_candidate_id,
		"policy_id": _bw2_policy_id,
		"candidate_policy_digest": _bw2_policy_digest,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": BW6N_EXPECTED_GATE_COUNT,
		"expected_world_count": BW6N_EXPECTED_WORLD_COUNT,
		"observed_world_count": cells.size(),
		"integrity_failure_count": int(metrics.get("integrity_failure_count", -1)),
		"count_by_cohort":
		(metrics.get("count_by_cohort", {}) as Dictionary).duplicate(true),
		"pass_by_cohort":
		(metrics.get("pass_by_cohort", {}) as Dictionary).duplicate(true),
		"nonzero_stability_world_count":
		int(metrics.get("nonzero_stability_count", -1)),
		"validation_manifest":
		(preflight.get("validation_manifest", {}) as Dictionary).duplicate(true),
		"cells": cells.duplicate(true),
		"matched_pairs":
		(extra.get("matched_pairs", []) as Array).duplicate(true),
		"godot_jolt_nuisance_acceptance": accepted,
		"rough_terrain_robustness": accepted,
		"external_push_recovery": accepted,
		"sensor_noise_robustness": accepted,
		"physical_balance_recovery": accepted,
		"arbitrary_terrain_robustness": false,
		"continuous_terrain_coverage": false,
		"arbitrary_push_recovery": false,
		"arbitrary_sensor_fault_robustness": false,
		"sensor_latency_robustness": false,
		"combined_nuisance_robustness": false,
		"fresh_morphology_validation": false,
		"cross_engine_c6": false,
		"completed_engine_neutral_sdk": false,
		"physical_acceptance_authority": false,
	}
	print(
		"BALANCED_WAVE_BW6N_VALIDATION_RECEIPT ",
		JSON.stringify(receipt, "", true, true),
	)


func _finish_bw6n() -> void:
	print(
		"\nBW6N nuisance acceptance: %d passed, %d failed (expected %d)"
		% [_passed, _failed, BW6N_EXPECTED_GATE_COUNT]
	)
	if _failed == 0 and _passed == BW6N_EXPECTED_GATE_COUNT:
		quit(0)
	else:
		push_error(
			"BW6N nuisance acceptance failed: %d passed, %d failed"
			% [_passed, _failed]
		)
		quit(1)
