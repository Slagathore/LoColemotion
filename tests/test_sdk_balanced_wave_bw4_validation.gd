extends "res://tests/test_sdk_godot_jolt_material_robustness.gd"

## BW4 prospective cold material-acceptance harness.
##
## This entry point reuses the established physical quadruped world, portable
## balanced-wave authority path, stability overlay, physical-integrity checks,
## and ordinary walking gates. It opens only the frozen BW4 profiles, seeds,
## roles, and claims. The zero-friction cell is deliberately a shadow-only
## safety control and therefore performs no SDK-native motor writes.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const BW4_MANIFEST_PATH := "res://sdk/balanced_wave_bw4_validation_manifest.json"
const BW4_MANIFEST_SCHEMA := "sporespore_balanced_wave_bw4_validation_manifest_v1"
const BW4_PREFLIGHT_SCHEMA := (
	"sporespore_balanced_wave_bw4_validation_preflight_receipt_v1"
)
const BW4_RECEIPT_SCHEMA := "sporespore_balanced_wave_bw4_validation_receipt_v1"
const BW4_SELECTED_POLICY_PATH := "res://sdk/balanced_wave_selected_policy.json"
const BW4_SELECTED_POLICY_SCHEMA := "sporespore_balanced_wave_selected_policy_v1"
const BW4_FREEZE_PARENT := "36739aa9e50c7330f9e6f230daaca58445fd8bba"
const BW4_POLICY_ID := "sporespore_balanced_wave_bw2r_c_v1"
const BW4_POLICY_DIGEST := (
	"sha256:709aacc898e62a0c1902a04a201006f5501934562cabec4b68c1613811ae0ad0"
)
const BW4R_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw4r_preregistration.json"
const BW4R_PREREGISTRATION_SCHEMA := "sporespore_balanced_wave_bw4r_preregistration_v1"
const BW5R_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw5r_preregistration.json"
const BW5R_PREREGISTRATION_SCHEMA := "sporespore_balanced_wave_bw5r_preregistration_v1"
const BW4R_REPLAY_CANDIDATES := {
	"--bw4r-a":
	{
		"candidate_id": "BW4R-A",
		"policy_id": "sporespore_balanced_wave_bw4r_a_v1",
		"policy_digest": "sha256:40dc551e99fea518df68c35d49e3d7d9605484e25cb385f938b3568ddcab2cf4",
	},
	"--bw4r-b":
	{
		"candidate_id": "BW4R-B",
		"policy_id": "sporespore_balanced_wave_bw4r_b_v1",
		"policy_digest": "sha256:2496dc6da6dea17cfc7ffee0027234fa7a2a0f4eea8bc463a68db9a9d105bae7",
	},
	"--bw5r-a":
	{
		"candidate_id": "BW5R-A",
		"policy_id": "sporespore_balanced_wave_bw5r_a_v1",
		"policy_digest": "sha256:6001dd2b5926908a1bad16d17e49e233cbfb1dfa7eb360bdfe8e4df147b245ac",
	},
	"--bw5r-b":
	{
		"candidate_id": "BW5R-B",
		"policy_id": "sporespore_balanced_wave_bw5r_b_v1",
		"policy_digest": "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f",
	},
	"--bw5r-c":
	{
		"candidate_id": "BW5R-C",
		"policy_id": "sporespore_balanced_wave_bw5r_c_v1",
		"policy_digest": "sha256:c067ece936a53edb9cc9d667a68274451e4db67b762ab262bf42e8efe88d742d",
	},
}
const BW4_EXPECTED_GATE_COUNT := 28
const BW4_EXPECTED_WORLD_COUNT := 17
const BW4_EXPECTED_TREATMENT_COUNT := 12
const BW4_EXPECTED_CONTROL_COUNT := 4
const BW4_EXPECTED_PAIR_COUNT := 4
const BW4_EXPECTED_ZERO_SAFETY_COUNT := 1
const BW4_SEEDS := [18001, 18002, 18003]
const BW4_CONTROL_SEED := 18001
const BW4_BW3R_REPORT_SHA256 := (
	"8cb29f019497a1b9bd0f4285ccd7eef20083ccd1b636ec5ef914d7e10e261913"
)
const BW4_CHARACTERIZATION_REPORT_SHA256 := (
	"f4a7291849d53540f31d58f40be97f26f01ad9cb76a2e2ae6fedabd56e0925c3"
)
const BW4_PUBLICATION_REPORT_SHA256 := (
	"61ecbc8bb853dd6abace6f5d4f356c79f3b9cfab304bec47b6daf1f9476292e6"
)
const BW4_MATERIAL_CELLS := [
	{
		"mu_token": "015",
		"authored_friction": 0.15,
		"profile_id": "godot_jolt_bw4_mu015_v1",
		"profile_digest":
		"sha256:5ce384234368bb6b64d3bb820da22ed47faa7ffbe274c9e3c9c3cd4b88c4fa6e",
	},
	{
		"mu_token": "050",
		"authored_friction": 0.5,
		"profile_id": "godot_jolt_bw4_mu050_v1",
		"profile_digest":
		"sha256:dbfc36e296682aec6b580319dd38ffae4c094e7a6cf66af2018a4f9bafc1e6dd",
	},
	{
		"mu_token": "090",
		"authored_friction": 0.9,
		"profile_id": "godot_jolt_bw4_mu090_v1",
		"profile_digest":
		"sha256:44dca6e33a70a939599affb091049a4fd478a35f3f3fe154c922f39e917ea240",
	},
	{
		"mu_token": "140",
		"authored_friction": 1.4,
		"profile_id": "godot_jolt_bw4_mu140_v1",
		"profile_digest":
		"sha256:b882df0698d2785d3512c935c46e1eb79092e29b5fadc86f5d28669369469384",
	},
]
const BW4_ZERO_CELL := {
	"mu_token": "000",
	"authored_friction": 0.0,
	"profile_id": "godot_jolt_p5m1r1_mu000_v1",
	"profile_digest":
	"sha256:b70b71e4aa16f877d1ddaf45ffc233a23300196eeb3240f4fefbe666b915b070",
}
const BW4_EXPECTED_CELL_IDS := [
	"validation_mu015_s18001_treatment",
	"validation_mu015_s18001_control",
	"validation_mu015_s18002_treatment",
	"validation_mu015_s18003_treatment",
	"validation_mu050_s18001_treatment",
	"validation_mu050_s18001_control",
	"validation_mu050_s18002_treatment",
	"validation_mu050_s18003_treatment",
	"validation_mu090_s18001_treatment",
	"validation_mu090_s18001_control",
	"validation_mu090_s18002_treatment",
	"validation_mu090_s18003_treatment",
	"validation_mu140_s18001_treatment",
	"validation_mu140_s18001_control",
	"validation_mu140_s18002_treatment",
	"validation_mu140_s18003_treatment",
	"negative_mu000_s18001_control",
]

var _opened_development_replay := false


func _run() -> void:
	print("\n=== SDK balanced-wave BW4 frozen 17-world cold material acceptance ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var user_args := OS.get_cmdline_user_args()
	var replay_arguments: Array[String] = []
	for argument_value in user_args:
		var argument := String(argument_value)
		if BW4R_REPLAY_CANDIDATES.has(argument):
			replay_arguments.append(argument)
	var allowed_args := ["--preflight-only"]
	if replay_arguments.size() == 1:
		allowed_args.append(replay_arguments[0])
	var arguments_valid := user_args.size() <= 2 and replay_arguments.size() <= 1
	for argument_value in user_args:
		arguments_valid = arguments_valid and String(argument_value) in allowed_args
	if not arguments_valid:
		push_error(
			"BW4 accepts optional --preflight-only plus at most one frozen BW4R replay argument"
		)
		quit(1)
		return
	_bw2_mode = true
	if replay_arguments.is_empty():
		_bw2_candidate_id = "BW2R-C"
		_bw2_policy_id = BW4_POLICY_ID
		_bw2_policy_digest = BW4_POLICY_DIGEST
	else:
		_opened_development_replay = true
		var replay: Dictionary = BW4R_REPLAY_CANDIDATES[replay_arguments[0]]
		_bw2_candidate_id = String(replay["candidate_id"])
		_bw2_policy_id = String(replay["policy_id"])
		_bw2_policy_digest = String(replay["policy_digest"])
	await _run_bw4_validation(user_args.has("--preflight-only"))


func _campaign_seeds() -> Array:
	return BW4_SEEDS


func _required_profile_ids() -> Array:
	var result: Array = []
	for material_value in BW4_MATERIAL_CELLS:
		result.append(String((material_value as Dictionary)["profile_id"]))
	result.append(String(BW4_ZERO_CELL["profile_id"]))
	return result


func _expected_cell_ids() -> Array:
	return BW4_EXPECTED_CELL_IDS


func _expected_world_count() -> int:
	return BW4_EXPECTED_WORLD_COUNT


func _bridge_profile_id() -> String:
	return "godot_jolt_bw4_mu015_v1"


func _build_matrix() -> Array:
	var matrix: Array = []
	for material_value in BW4_MATERIAL_CELLS:
		var material: Dictionary = material_value
		for seed_value in BW4_SEEDS:
			var seed := int(seed_value)
			matrix.append(_cell_spec("validation", "treatment", material, seed))
			if seed == BW4_CONTROL_SEED:
				matrix.append(_cell_spec("validation", "control", material, seed))
	matrix.append(_cell_spec("negative", "control", BW4_ZERO_CELL, BW4_CONTROL_SEED))
	return matrix


func _matrix_cardinality_exact(matrix: Array) -> bool:
	var treatment_count := 0
	var control_count := 0
	var zero_safety_count := 0
	for cell_value in matrix:
		var cell: Dictionary = cell_value
		var cohort := String(cell.get("cohort", ""))
		var mode := String(cell.get("mode", ""))
		if cohort == "validation" and mode == "treatment":
			treatment_count += 1
		elif cohort == "validation" and mode == "control":
			control_count += 1
		elif cohort == "negative" and mode == "control":
			zero_safety_count += 1
		else:
			return false
	return (
		matrix.size() == BW4_EXPECTED_WORLD_COUNT
		and treatment_count == BW4_EXPECTED_TREATMENT_COUNT
		and control_count == BW4_EXPECTED_CONTROL_COUNT
		and zero_safety_count == BW4_EXPECTED_ZERO_SAFETY_COUNT
	)


func _validation_manifest_receipt() -> Dictionary:
	var parsed := _load_json_dictionary(BW4_MANIFEST_PATH)
	if parsed.is_empty():
		return _manifest_failure("BW4_VALIDATION_MANIFEST_UNREADABLE")
	var selected: Dictionary = parsed.get("selected_policy", {})
	var prerequisite: Dictionary = parsed.get("prerequisite_evidence", {})
	var bw3r: Dictionary = prerequisite.get("bw3r_validation", {})
	var characterization: Dictionary = prerequisite.get("material_characterization", {})
	var publication: Dictionary = prerequisite.get("material_profile_publication", {})
	var matrix: Dictionary = parsed.get("matrix", {})
	var gate_contract: Dictionary = parsed.get("gate_contract", {})
	var claims_if_accepted: Dictionary = parsed.get("claims_if_accepted", {})
	var claims_always_false: Dictionary = parsed.get("claims_always_false", {})
	var scope: Dictionary = claims_if_accepted.get("scope", {})
	var manifest_profiles: Array = parsed.get("profiles", [])
	var profiles_exact := manifest_profiles.size() == BW4_MATERIAL_CELLS.size()
	var manifest_profile_ids: Array = []
	var manifest_profile_digests: Array = []
	for index in range(manifest_profiles.size()):
		var profile: Dictionary = manifest_profiles[index]
		manifest_profile_ids.append(String(profile.get("profile_id", "")))
		manifest_profile_digests.append(String(profile.get("profile_digest", "")))
		if index >= BW4_MATERIAL_CELLS.size():
			profiles_exact = false
			continue
		var expected: Dictionary = BW4_MATERIAL_CELLS[index]
		var resolved: Dictionary = MaterialProfilesScript.resolve(String(expected["profile_id"]))
		profiles_exact = (
			profiles_exact
			and bool(resolved.get("ok", false))
			and String(profile.get("profile_id", "")) == String(expected["profile_id"])
			and String(profile.get("profile_digest", "")) == String(expected["profile_digest"])
			and String(resolved.get("profile_sha256", "")) == String(expected["profile_digest"])
			and (
				absf(
					float(profile.get("authored_friction", NAN))
					- float(expected["authored_friction"])
				)
				<= 1.0e-12
			)
		)
	var zero_profile: Dictionary = parsed.get("zero_friction_safety_profile", {})
	var resolved_zero := MaterialProfilesScript.resolve(String(BW4_ZERO_CELL["profile_id"]))
	var zero_profile_exact := (
		bool(resolved_zero.get("ok", false))
		and (
			String(zero_profile.get("profile_id", ""))
			== String(BW4_ZERO_CELL["profile_id"])
		)
		and (
			String(zero_profile.get("profile_digest", ""))
			== String(BW4_ZERO_CELL["profile_digest"])
		)
		and (
			String(resolved_zero.get("profile_sha256", ""))
			== String(BW4_ZERO_CELL["profile_digest"])
		)
		and float(zero_profile.get("authored_friction", NAN)) == 0.0
		and float(zero_profile.get("characterized_friction_coefficient", NAN)) == 0.0
		and bool(zero_profile.get("negative_control", false))
	)
	var bw3r_path := String(bw3r.get("path", ""))
	var characterization_path := String(characterization.get("path", ""))
	var publication_path := String(publication.get("path", ""))
	var bw3r_hash_exact := _file_hash_exact(bw3r_path, BW4_BW3R_REPORT_SHA256)
	var characterization_hash_exact := _file_hash_exact(
		characterization_path,
		BW4_CHARACTERIZATION_REPORT_SHA256,
	)
	var publication_hash_exact := _file_hash_exact(
		publication_path,
		BW4_PUBLICATION_REPORT_SHA256,
	)
	var selected_policy_manifest := _load_json_dictionary(BW4_SELECTED_POLICY_PATH)
	var historical_selected_binding_exact := (
		String(selected_policy_manifest.get("selected_candidate_id", ""))
		== "BW2R-C"
		and (
			String(selected_policy_manifest.get("selected_policy_id", ""))
			== BW4_POLICY_ID
		)
		and (
			String(
				selected_policy_manifest.get(
					"selected_candidate_policy_digest",
					"",
				)
			)
			== BW4_POLICY_DIGEST
		)
	)
	if not historical_selected_binding_exact:
		for history_value in selected_policy_manifest.get("selection_history", []):
			var history: Dictionary = history_value
			if (
				String(history.get("candidate_id", "")) == "BW2R-C"
				and String(history.get("policy_id", "")) == BW4_POLICY_ID
				and String(history.get("policy_digest", "")) == BW4_POLICY_DIGEST
			):
				historical_selected_binding_exact = true
				break
	var selected_policy_exact := (
		String(selected_policy_manifest.get("schema_version", ""))
		== BW4_SELECTED_POLICY_SCHEMA
		and historical_selected_binding_exact
		and (
			(selected_policy_manifest.get("selected_profile", {}) as Dictionary)
			. get("branch_surfaces", [])
			as Array
		).is_empty()
	)
	var ordered_cell_ids: Array = []
	for cell_id_value in matrix.get("ordered_cell_ids", []):
		ordered_cell_ids.append(String(cell_id_value))
	var seeds: Array = []
	for seed_value in matrix.get("seeds", []):
		seeds.append(int(seed_value))
	var metadata_exact := (
		String(parsed.get("schema_version", "")) == BW4_MANIFEST_SCHEMA
		and (
			String(parsed.get("status", ""))
			== "frozen_before_first_bw4_validation_world"
		)
		and String(parsed.get("freeze_parent_commit", "")) == BW4_FREEZE_PARENT
		and String(parsed.get("campaign_partition", "")) == "cold_acceptance"
		and not bool(parsed.get("development_data_only", true))
		and not bool(parsed.get("locomotion_outcome_exposed", true))
	)
	var policy_exact := (
		String(selected.get("candidate_id", "")) == "BW2R-C"
		and String(selected.get("policy_id", "")) == BW4_POLICY_ID
		and String(selected.get("policy_digest", "")) == BW4_POLICY_DIGEST
		and (
			(
				not _opened_development_replay
				and _bw2_candidate_id == "BW2R-C"
				and _bw2_policy_id == BW4_POLICY_ID
				and _bw2_policy_digest == BW4_POLICY_DIGEST
			)
			or (
				_opened_development_replay
				and _bw4r_replay_policy_exact()
			)
		)
		and selected_policy_exact
	)
	var prerequisite_exact := (
		String(bw3r.get("sha256", "")) == BW4_BW3R_REPORT_SHA256
		and bool(bw3r.get("accepted", false))
		and int(bw3r.get("observed_world_count", -1)) == 12
		and int(bw3r.get("passed_gate_count", -1)) == 22
		and bw3r_hash_exact
		and (
			String(characterization.get("sha256", ""))
			== BW4_CHARACTERIZATION_REPORT_SHA256
		)
		and bool(characterization.get("accepted", false))
		and int(characterization.get("observed_world_count", -1)) == 13
		and int(characterization.get("passed_gate_count", -1)) == 23
		and characterization_hash_exact
		and (
			String(publication.get("sha256", ""))
			== BW4_PUBLICATION_REPORT_SHA256
		)
		and bool(publication.get("accepted", false))
		and int(publication.get("observed_world_count", -1)) == 0
		and int(publication.get("passed_gate_count", -1)) == 29
		and int(publication.get("observed_profile_count", -1)) == 18
		and publication_hash_exact
	)
	var matrix_exact := (
		seeds == BW4_SEEDS
		and ordered_cell_ids == BW4_EXPECTED_CELL_IDS
		and (
			int(matrix.get("expected_treatment_world_count", -1))
			== BW4_EXPECTED_TREATMENT_COUNT
		)
		and (
			int(matrix.get("expected_control_world_count", -1))
			== BW4_EXPECTED_CONTROL_COUNT
		)
		and (
			int(matrix.get("expected_zero_friction_safety_world_count", -1))
			== BW4_EXPECTED_ZERO_SAFETY_COUNT
		)
		and (
			int(matrix.get("expected_causal_pair_count", -1))
			== BW4_EXPECTED_PAIR_COUNT
		)
		and int(matrix.get("expected_world_count", -1)) == BW4_EXPECTED_WORLD_COUNT
		and int(matrix.get("exposure_steps", -1)) == EXPECTED_STEP_COUNT
		and (
			int(matrix.get("expected_base_commands_and_motor_writes_per_treatment", -1))
			== EXPECTED_MOTOR_WRITE_COUNT
		)
		and int(matrix.get("control_seed", -1)) == BW4_CONTROL_SEED
		and int(matrix.get("zero_friction_seed", -1)) == BW4_CONTROL_SEED
		and int(matrix.get("zero_friction_native_motor_write_count", -1)) == 0
		and (
			absf(
				float(matrix.get("minimum_terminal_pair_separation_m", NAN))
				- MINIMUM_PAIRED_TERMINAL_SEPARATION_M
			)
			<= 1.0e-15
		)
	)
	var gates_exact := (
		int(gate_contract.get("expected_gate_count", -1)) == BW4_EXPECTED_GATE_COUNT
		and int(gate_contract.get("preflight_gate_count", -1)) == 3
		and (
			int(gate_contract.get("per_world_execution_integrity_gate_count", -1))
			== BW4_EXPECTED_WORLD_COUNT
		)
		and int(gate_contract.get("aggregate_gate_count", -1)) == 8
		and bool(gate_contract.get("averaging_forbidden", false))
		and bool(gate_contract.get("failed_cell_replacement_forbidden", false))
		and bool(gate_contract.get("post_result_gate_edit_forbidden", false))
		and bool(gate_contract.get("first_result_is_final_for_this_source_identity", false))
	)
	var scoped_friction_values: Array = []
	for value in scope.get("authored_friction_values", []):
		scoped_friction_values.append(float(value))
	var scoped_seeds: Array = []
	for value in scope.get("seeds", []):
		scoped_seeds.append(int(value))
	var claim_checks := {
		"cold_authority":
		bool(claims_if_accepted.get("bw4_cold_acceptance_authority", false)),
		"walking": bool(claims_if_accepted.get("walking_acceptance", false)),
		"bounded_discrete":
		bool(claims_if_accepted.get("bounded_discrete_material_robustness", false)),
		"material": bool(claims_if_accepted.get("material_robustness", false)),
		"adapter": String(scope.get("adapter_id", "")) == "godot_jolt_gdextension_v1",
		"engine": String(scope.get("physics_engine", "")) == "Jolt Physics",
		"policy": String(scope.get("controller_policy_id", "")) == BW4_POLICY_ID,
		"friction_values": scoped_friction_values == [0.15, 0.5, 0.9, 1.4],
		"seeds": scoped_seeds == BW4_SEEDS,
		"terrain": String(scope.get("terrain", "")) == "flat",
		"no_pushes": not bool(scope.get("external_pushes", true)),
		"no_sensor_faults": not bool(scope.get("sensor_faults", true)),
		"broader_false": _all_claim_values_false(claims_always_false),
	}
	var claims_exact := true
	for claim_check in claim_checks.values():
		claims_exact = claims_exact and bool(claim_check)
	var exact: bool = (
		metadata_exact
		and policy_exact
		and prerequisite_exact
		and profiles_exact
		and zero_profile_exact
		and matrix_exact
		and gates_exact
		and claims_exact
	)
	return {
		"ok": exact,
		"failure_code": "" if exact else "BW4_VALIDATION_MANIFEST_MISMATCH",
		"schema_version": String(parsed.get("schema_version", "")),
		"status": String(parsed.get("status", "")),
		"manifest_path": "sdk/balanced_wave_bw4_validation_manifest.json",
		"selected_policy_id": String(selected.get("policy_id", "")),
		"selected_policy_digest": String(selected.get("policy_digest", "")),
		"active_policy_id": _bw2_policy_id,
		"active_policy_digest": _bw2_policy_digest,
		"selected_policy_manifest_exact": selected_policy_exact,
		"bw3r_validation_report_path": bw3r_path,
		"bw3r_validation_report_sha256": String(bw3r.get("sha256", "")),
		"bw3r_validation_report_hash_exact": bw3r_hash_exact,
		"characterization_report_path": characterization_path,
		"characterization_report_sha256": String(characterization.get("sha256", "")),
		"characterization_report_hash_exact": characterization_hash_exact,
		"profile_publication_report_path": publication_path,
		"profile_publication_report_sha256": String(publication.get("sha256", "")),
		"profile_publication_report_hash_exact": publication_hash_exact,
		"profile_ids": manifest_profile_ids,
		"profile_digests": manifest_profile_digests,
		"zero_profile_id": String(zero_profile.get("profile_id", "")),
		"zero_profile_digest": String(zero_profile.get("profile_digest", "")),
		"metadata_exact": metadata_exact,
		"policy_exact": policy_exact,
		"prerequisite_exact": prerequisite_exact,
		"profiles_exact": profiles_exact,
		"zero_profile_exact": zero_profile_exact,
		"matrix_exact": matrix_exact,
		"gates_exact": gates_exact,
		"claims_exact": claims_exact,
		"claim_checks": claim_checks.duplicate(true),
		"scope": scope.duplicate(true),
		"world_build_count": 0,
		"locomotion_outcome_exposed": false,
	}


func _run_bw4_validation(preflight_only: bool) -> void:
	var preflight := _compile_preflight()
	if preflight_only:
		var receipt := _bw4_preflight_receipt(preflight)
		print(
			"BALANCED_WAVE_BW4_VALIDATION_PREFLIGHT_RECEIPT ",
			JSON.stringify(receipt, "", true, true),
		)
		quit(0 if bool(receipt.get("ok", false)) else 1)
		return

	var clock_ok := bool(preflight.get("clock_ok", false))
	var matrix_ok := bool(preflight.get("matrix_ok", false))
	var inputs_ok := bool(preflight.get("inputs_ok", false))
	_check(clock_ok, "1 the frozen GQ15 clock compiles exactly")
	_check(matrix_ok, "2 the frozen ordered BW4 17-world matrix is exact")
	_check(
		inputs_ok,
		"3 every prerequisite report, profile, seed, fixture, and binding compiles",
	)
	if not (clock_ok and matrix_ok and inputs_ok):
		_emit_bw4_receipt(preflight, [], [], _empty_bw4_metrics())
		_finish_bw4()
		return

	var matrix: Array = preflight["matrix"]
	var gait_clock_options: Dictionary = preflight["gait_clock_options"]
	var perturbation_by_seed: Dictionary = preflight["perturbation_by_seed"]
	var input_by_profile: Dictionary = preflight["input_by_profile"]
	var cell_receipts: Array = []
	var summary_by_cell_id: Dictionary = {}
	var integrity_failure_count := 0
	var treatment_count := 0
	var control_count := 0
	var zero_safety_count := 0
	var treatment_pass_count := 0
	var control_pass_count := 0
	var zero_safety_pass_count := 0
	var treatment_with_nonzero_stability_count := 0

	for cell_value in matrix:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		var profile_id := String(cell["profile_id"])
		var seed_key := str(int(cell["campaign_seed"]))
		var input: Dictionary = input_by_profile[profile_id]
		var perturbation: Dictionary = perturbation_by_seed[seed_key]
		print(
			"BW4_VALIDATION_CELL_START ",
			cell_id,
			" world=",
			cell_receipts.size() + 1,
			"/",
			BW4_EXPECTED_WORLD_COUNT,
		)
		var summary: Dictionary = await _run_cell(
			gait_clock_options,
			cell,
			perturbation,
			input["fixture_spec"],
		)
		summary_by_cell_id[cell_id] = summary
		var cell_receipt := _analyze_cell(cell, summary, perturbation, input, true)
		if String(cell["cohort"]) == "negative":
			cell_receipt = _analyze_zero_safety(
				cell,
				summary,
				input,
				cell_receipt,
			)
		cell_receipts.append(cell_receipt)
		var execution_ok := bool(
			cell_receipt.get("campaign_execution_gate_passed", false)
		)
		_check(
			execution_ok,
			"%s completes its frozen role-specific execution gate" % cell_id,
		)
		if not execution_ok:
			integrity_failure_count += 1
		if String(cell["cohort"]) == "negative":
			zero_safety_count += 1
			if bool(cell_receipt.get("zero_friction_safety_gate_passed", false)):
				zero_safety_pass_count += 1
		elif String(cell["mode"]) == "treatment":
			treatment_count += 1
			if bool(cell_receipt.get("treatment_gate_passed", false)):
				treatment_pass_count += 1
			var contribution: Dictionary = (
				cell_receipt.get("stability_contribution_shadow", {})
			)
			var overlay: Dictionary = cell_receipt.get("stability_overlay", {})
			if (
				int(contribution.get("nonzero_active_command_count", 0)) > 0
				and int(overlay.get("nonzero_effective_application_count", 0)) > 0
			):
				treatment_with_nonzero_stability_count += 1
		else:
			control_count += 1
			if bool(cell_receipt.get("control_gate_passed", false)):
				control_pass_count += 1
		print(
			"BALANCED_WAVE_BW4_VALIDATION_CELL ",
			JSON.stringify(cell_receipt, "", true, true),
		)

	var paired_receipts := _bw4_paired_receipts(summary_by_cell_id)
	var roles_exact := (
		cell_receipts.size() == BW4_EXPECTED_WORLD_COUNT
		and treatment_count == BW4_EXPECTED_TREATMENT_COUNT
		and control_count == BW4_EXPECTED_CONTROL_COUNT
		and zero_safety_count == BW4_EXPECTED_ZERO_SAFETY_COUNT
	)
	_check(
		roles_exact,
		"21 all 17 roles complete with exact 12-treatment/4-control/1-safety cardinality",
	)
	var integrity_complete := integrity_failure_count == 0
	_check(
		integrity_complete,
		"22 the complete BW4 matrix has zero infrastructure or integrity failures",
	)
	var stability_complete := (
		treatment_with_nonzero_stability_count == BW4_EXPECTED_TREATMENT_COUNT
	)
	_check(
		stability_complete,
		"23 all 12 positive treatments apply nonzero stability influence",
	)
	var treatments_complete := treatment_pass_count == BW4_EXPECTED_TREATMENT_COUNT
	_check(
		treatments_complete,
		"24 all 12 positive treatments pass every ordinary physical walking gate",
	)
	var controls_complete := control_pass_count == BW4_EXPECTED_CONTROL_COUNT
	_check(
		controls_complete,
		"25 all four material-matched controls pass their shadow gates",
	)
	var pairs_complete := (
		paired_receipts.size() == BW4_EXPECTED_PAIR_COUNT
		and _all_pair_gates_pass(paired_receipts)
	)
	_check(
		pairs_complete,
		"26 all four matched pairs retain identity and nonzero terminal separation",
	)
	var zero_safety_complete := (
		zero_safety_count == BW4_EXPECTED_ZERO_SAFETY_COUNT
		and zero_safety_pass_count == BW4_EXPECTED_ZERO_SAFETY_COUNT
	)
	_check(
		zero_safety_complete,
		"27 zero friction remains shadow-only with zero SDK-native motor writes",
	)
	var broader_claims_false := (
		bool((preflight.get("validation_manifest", {}) as Dictionary).get("ok", false))
		and not bool(preflight.get("continuous_friction_coverage", true))
		and not bool(preflight.get("cross_engine_equivalence", true))
		and not bool(preflight.get("rough_terrain_robustness", true))
		and not bool(preflight.get("external_push_recovery", true))
		and not bool(preflight.get("sensor_fault_robustness", true))
		and not bool(preflight.get("fresh_morphology_validation", true))
		and not bool(preflight.get("completed_sdk", true))
	)
	_check(
		broader_claims_false,
		"28 every out-of-scope robustness, recovery, and completed-SDK claim remains false",
	)
	_emit_bw4_receipt(
		preflight,
		cell_receipts,
		paired_receipts,
		{
			"integrity_failure_count": integrity_failure_count,
			"treatment_count": treatment_count,
			"control_count": control_count,
			"zero_safety_count": zero_safety_count,
			"treatment_pass_count": treatment_pass_count,
			"control_pass_count": control_pass_count,
			"zero_safety_pass_count": zero_safety_pass_count,
			"treatment_with_nonzero_stability_count":
			treatment_with_nonzero_stability_count,
			"pair_pass_count": _pair_pass_count(paired_receipts),
			"roles_exact": roles_exact,
			"integrity_complete": integrity_complete,
			"stability_complete": stability_complete,
			"treatments_complete": treatments_complete,
			"controls_complete": controls_complete,
			"pairs_complete": pairs_complete,
			"zero_safety_complete": zero_safety_complete,
			"broader_claims_false": broader_claims_false,
		},
	)
	_finish_bw4()


func _analyze_zero_safety(
	cell: Dictionary,
	summary: Dictionary,
	input: Dictionary,
	base_receipt: Dictionary,
) -> Dictionary:
	var receipt := base_receipt.duplicate(true)
	var contribution: Dictionary = receipt.get("stability_contribution_shadow", {})
	var overlay: Dictionary = receipt.get("stability_overlay", {})
	var profile: Dictionary = input.get("profile", {})
	var safety_passed := (
		String(cell.get("cohort", "")) == "negative"
		and String(cell.get("mode", "")) == "control"
		and bool(receipt.get("common_execution_integrity", false))
		and float(profile.get("authored_friction", NAN)) == 0.0
		and float(profile.get("characterized_friction_coefficient", NAN)) == 0.0
		and bool(profile.get("negative_control", false))
		and int(receipt.get("native_actuation_application_count", -1)) == 0
		and int(receipt.get("legacy_sdk_overlay_base_application_count", -1)) == 0
		and int(overlay.get("application_step_count", -1)) == 0
		and int(overlay.get("motor_write_count", -1)) == 0
		and int(overlay.get("portable_controller_base_application_count", -1)) == 0
		and int(contribution.get("nonzero_active_command_count", -1)) == 0
		and int(overlay.get("nonzero_effective_application_count", -1)) == 0
		and _outcome_is_complete(summary)
		and not bool(receipt.get("walking_claim_authorized", true))
	)
	receipt["campaign_execution_gate_passed"] = safety_passed
	receipt["zero_friction_safety_gate_passed"] = safety_passed
	receipt["control_gate_passed"] = false
	receipt["walking_claim_authorized"] = false
	receipt["sdk_native_motor_write_count"] = int(
		receipt.get("native_actuation_application_count", -1)
	)
	return receipt


func _bw4_paired_receipts(summary_by_cell_id: Dictionary) -> Array:
	var pairs: Array = []
	for material_value in BW4_MATERIAL_CELLS:
		var material: Dictionary = material_value
		var token := String(material["mu_token"])
		var treatment_id := (
			"validation_mu%s_s%d_treatment" % [token, BW4_CONTROL_SEED]
		)
		var control_id := "validation_mu%s_s%d_control" % [token, BW4_CONTROL_SEED]
		if (
			not summary_by_cell_id.has(treatment_id)
			or not summary_by_cell_id.has(control_id)
		):
			continue
		var treatment: Dictionary = summary_by_cell_id[treatment_id]
		var control: Dictionary = summary_by_cell_id[control_id]
		var initial_position_error_m := (
			(control["initial_torso_position_world_m"] as Vector3)
			. distance_to(treatment["initial_torso_position_world_m"] as Vector3)
		)
		var initial_orientation_error := _orientation_error(
			control.get("initial_torso_orientation_xyzw", {}),
			treatment.get("initial_torso_orientation_xyzw", {}),
		)
		var terminal_separation_m := (
			(control["final_torso_position_world_m"] as Vector3)
			. distance_to(treatment["final_torso_position_world_m"] as Vector3)
		)
		var identity_exact: bool = (
			String(control.get("fixture_spec_sha256", ""))
			== String(treatment.get("fixture_spec_sha256", ""))
			and (
				String(control.get("controller_configuration_sha256", ""))
				== String(treatment.get("controller_configuration_sha256", ""))
			)
			and (
				String(control.get("evidence_threshold_configuration_sha256", ""))
				== String(treatment.get("evidence_threshold_configuration_sha256", ""))
			)
			and (
				String(control.get("solver_policy_configuration_sha256", ""))
				== String(treatment.get("solver_policy_configuration_sha256", ""))
			)
			and control.get("gait_clock_options", {}) == treatment.get("gait_clock_options", {})
			and control.get("initial_perturbation", {}) == treatment.get("initial_perturbation", {})
			and control.get("sdk_material_profile", {}) == treatment.get("sdk_material_profile", {})
			and initial_position_error_m <= 1.0e-9
			and initial_orientation_error <= 1.0e-9
		)
		pairs.append(
			{
				"pair_id": "validation_mu%s_s%d_pair" % [token, BW4_CONTROL_SEED],
				"control_cell_id": control_id,
				"treatment_cell_id": treatment_id,
				"configuration_identity_exact": identity_exact,
				"initial_position_error_m": initial_position_error_m,
				"initial_orientation_error": initial_orientation_error,
				"terminal_position_separation_m": terminal_separation_m,
				"causal_influence_gate_passed":
				(
					identity_exact
					and terminal_separation_m >= MINIMUM_PAIRED_TERMINAL_SEPARATION_M
				),
				"balance_improvement": false,
				"physical_balance_recovery": false,
			}
		)
	return pairs


func _bw4r_replay_policy_exact() -> bool:
	var bw5r_replay := _bw2_candidate_id.begins_with("BW5R-")
	var preregistration_path := (
		BW5R_PREREGISTRATION_PATH if bw5r_replay else BW4R_PREREGISTRATION_PATH
	)
	var preregistration_schema := (
		BW5R_PREREGISTRATION_SCHEMA if bw5r_replay else BW4R_PREREGISTRATION_SCHEMA
	)
	var preregistration_status := (
		"frozen_before_first_bw5r_physics_world"
		if bw5r_replay
		else "frozen_before_first_bw4r_physics_world"
	)
	var preregistration := _load_json_dictionary(preregistration_path)
	if (
		String(preregistration.get("schema_version", "")) != preregistration_schema
		or String(preregistration.get("status", "")) != preregistration_status
		or (
			int(
				(preregistration.get("development_matrix", {}) as Dictionary).get(
					"expected_world_count_per_candidate",
					-1,
				)
			)
			!= 58
		)
		or not bool(
			(preregistration.get("development_matrix", {}) as Dictionary).get(
				"every_candidate_runs_the_complete_matrix",
				false,
			)
		)
	):
		return false
	for candidate_value in preregistration.get("candidates", []):
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_value
		if String(candidate.get("candidate_id", "")) != _bw2_candidate_id:
			continue
		return (
			String(candidate.get("policy_id", "")) == _bw2_policy_id
			and CanonicalJsonScript.sha256(candidate) == _bw2_policy_digest
			and (
				String(
					(preregistration.get("candidate_policy_digests", {}) as Dictionary).get(
						_bw2_candidate_id,
						"",
					)
				)
				== _bw2_policy_digest
			)
			and int(candidate.get("steering_feedback_update_interval_steps", -1)) == 1
			and (candidate.get("branch_surfaces", []) as Array).is_empty()
		)
	return false


func _bw4_preflight_receipt(preflight: Dictionary) -> Dictionary:
	return {
		"schema_version": BW4_PREFLIGHT_SCHEMA,
		"ok": bool(preflight.get("ok", false)),
		"candidate_id": _bw2_candidate_id,
		"policy_id": _bw2_policy_id,
		"candidate_policy_digest": _bw2_policy_digest,
		"campaign_partition":
		(
			"opened_bw4_development_replay"
			if _opened_development_replay
			else "cold_acceptance"
		),
		"clock_ok": bool(preflight.get("clock_ok", false)),
		"matrix_ok": bool(preflight.get("matrix_ok", false)),
		"inputs_ok": bool(preflight.get("inputs_ok", false)),
		"validation_manifest":
		(preflight.get("validation_manifest", {}) as Dictionary).duplicate(true),
		"expected_world_count": BW4_EXPECTED_WORLD_COUNT,
		"observed_world_count": 0,
		"cell_ids": (preflight.get("cell_ids", []) as Array).duplicate(),
		"seed_receipts": (preflight.get("seed_receipts", []) as Array).duplicate(true),
		"task_frame_receipts":
		(preflight.get("task_frame_receipts", []) as Array).duplicate(true),
		"bridge_conformance":
		(preflight.get("bridge_conformance", {}) as Dictionary).duplicate(true),
		"profile_receipts": (preflight.get("profile_receipts", []) as Array).duplicate(true),
		"locomotion_outcome_exposed": false,
		"adapter_actuation_applied": false,
		"physics_transform_or_velocity_written": false,
		"development_data_only": _opened_development_replay,
		"cold_acceptance_partition": not _opened_development_replay,
		"cold_acceptance": false,
		"walking_acceptance": false,
		"bounded_discrete_material_robustness": false,
		"material_robustness": false,
		"continuous_friction_coverage": false,
		"cross_engine_c6": false,
		"completed_engine_neutral_sdk": false,
		"physical_acceptance_authority": false,
	}


func _emit_bw4_receipt(
	preflight: Dictionary,
	cell_receipts: Array,
	paired_receipts: Array,
	metrics: Dictionary,
) -> void:
	var accepted := (
		_failed == 0
		and _passed == BW4_EXPECTED_GATE_COUNT
		and bool(metrics.get("roles_exact", false))
		and bool(metrics.get("integrity_complete", false))
		and bool(metrics.get("stability_complete", false))
		and bool(metrics.get("treatments_complete", false))
		and bool(metrics.get("controls_complete", false))
		and bool(metrics.get("pairs_complete", false))
		and bool(metrics.get("zero_safety_complete", false))
		and bool(metrics.get("broader_claims_false", false))
	)
	var scope: Dictionary = (
		(
			preflight
			. get(
				"validation_manifest",
				{},
			)
			as Dictionary
		)
		. get(
			"scope",
			{},
		)
		as Dictionary
	)
	var receipt := {
		"schema_version": BW4_RECEIPT_SCHEMA,
		"ok": accepted,
		"validation_passed": accepted and not _opened_development_replay,
		"development_matrix_passed": accepted and _opened_development_replay,
		"candidate_id": _bw2_candidate_id,
		"policy_id": _bw2_policy_id,
		"candidate_policy_digest": _bw2_policy_digest,
		"campaign_partition":
		(
			"opened_bw4_development_replay"
			if _opened_development_replay
			else "cold_acceptance"
		),
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": BW4_EXPECTED_GATE_COUNT,
		"expected_world_count": BW4_EXPECTED_WORLD_COUNT,
		"observed_world_count": cell_receipts.size(),
		"expected_treatment_count": BW4_EXPECTED_TREATMENT_COUNT,
		"observed_treatment_count": int(metrics.get("treatment_count", 0)),
		"observed_treatment_pass_count": int(metrics.get("treatment_pass_count", 0)),
		"treatment_with_nonzero_stability_count":
		int(metrics.get("treatment_with_nonzero_stability_count", 0)),
		"expected_control_count": BW4_EXPECTED_CONTROL_COUNT,
		"observed_control_count": int(metrics.get("control_count", 0)),
		"observed_control_pass_count": int(metrics.get("control_pass_count", 0)),
		"expected_pair_count": BW4_EXPECTED_PAIR_COUNT,
		"observed_pair_pass_count": int(metrics.get("pair_pass_count", 0)),
		"expected_zero_friction_safety_count": BW4_EXPECTED_ZERO_SAFETY_COUNT,
		"observed_zero_friction_safety_count": int(metrics.get("zero_safety_count", 0)),
		"observed_zero_friction_safety_pass_count":
		int(metrics.get("zero_safety_pass_count", 0)),
		"integrity_failure_count": int(metrics.get("integrity_failure_count", -1)),
		"validation_manifest":
		(preflight.get("validation_manifest", {}) as Dictionary).duplicate(true),
		"cell_ids": (preflight.get("cell_ids", []) as Array).duplicate(),
		"seed_receipts": (preflight.get("seed_receipts", []) as Array).duplicate(true),
		"profile_receipts": (preflight.get("profile_receipts", []) as Array).duplicate(true),
		"cells": cell_receipts.duplicate(true),
		"paired_controls": paired_receipts.duplicate(true),
		"development_data_only": _opened_development_replay,
		"cold_acceptance_partition": not _opened_development_replay,
		"cold_acceptance": accepted and not _opened_development_replay,
		"bw4_cold_acceptance_authority": accepted and not _opened_development_replay,
		"walking_acceptance": accepted and not _opened_development_replay,
		"bounded_discrete_material_robustness": accepted and not _opened_development_replay,
		"material_robustness": accepted and not _opened_development_replay,
		"material_robustness_scope": scope.duplicate(true),
		"arbitrary_material_robustness": false,
		"continuous_friction_coverage": false,
		"balance_improvement": false,
		"physical_balance_recovery": false,
		"rough_terrain_robustness": false,
		"external_push_recovery": false,
		"sensor_fault_robustness": false,
		"arbitrary_quadruped_coverage": false,
		"continuous_full_volume_coverage": false,
		"cross_engine_c6": false,
		"completed_engine_neutral_sdk": false,
		"physical_acceptance_authority": false,
	}
	print(
		"BALANCED_WAVE_BW4_VALIDATION_RECEIPT ",
		JSON.stringify(receipt, "", true, true),
	)


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _file_hash_exact(path: String, expected_sha256: String) -> bool:
	return (
		not path.is_empty()
		and FileAccess.file_exists(path)
		and FileAccess.get_sha256(path) == expected_sha256
	)


static func _all_claim_values_false(claims: Dictionary) -> bool:
	for value in claims.values():
		if typeof(value) != TYPE_BOOL or bool(value):
			return false
	return true


static func _manifest_failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"manifest_path": "sdk/balanced_wave_bw4_validation_manifest.json",
		"world_build_count": 0,
		"locomotion_outcome_exposed": false,
	}


static func _empty_bw4_metrics() -> Dictionary:
	return {
		"integrity_failure_count": -1,
		"treatment_count": 0,
		"control_count": 0,
		"zero_safety_count": 0,
		"treatment_pass_count": 0,
		"control_pass_count": 0,
		"zero_safety_pass_count": 0,
		"treatment_with_nonzero_stability_count": 0,
		"pair_pass_count": 0,
		"roles_exact": false,
		"integrity_complete": false,
		"stability_complete": false,
		"treatments_complete": false,
		"controls_complete": false,
		"pairs_complete": false,
		"zero_safety_complete": false,
		"broader_claims_false": false,
	}


func _finish_bw4() -> void:
	print(
		"\nSDK balanced-wave BW4 validation summary: %d passed, %d failed"
		% [_passed, _failed]
	)
	if _failed == 0 and _passed != BW4_EXPECTED_GATE_COUNT:
		_failed += 1
		push_error(
			"Expected %d BW4 validation gates, observed %d"
			% [BW4_EXPECTED_GATE_COUNT, _passed]
		)
	quit(0 if _failed == 0 else 1)
