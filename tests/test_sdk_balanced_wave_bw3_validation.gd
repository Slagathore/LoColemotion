extends "res://tests/test_sdk_godot_jolt_material_robustness.gd"

## BW3 prospective material-validation harness.
##
## This entry point deliberately reuses the established P5M.3/BW2 world,
## adapter, physical-integrity, and walking-gate implementation. It changes
## only the prospectively frozen material profiles, seeds, ordered matrix, and
## BW3 aggregate pass contract.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const BW3_VALIDATION_MANIFEST_PATH := "res://sdk/balanced_wave_bw3_validation_manifest.json"
const BW3_VALIDATION_MANIFEST_SCHEMA := "sporespore_balanced_wave_bw3_validation_manifest_v1"
const BW3_VALIDATION_RECEIPT_SCHEMA := "sporespore_balanced_wave_bw3_validation_receipt_v1"
const BW3_VALIDATION_PREFLIGHT_SCHEMA := (
	"sporespore_balanced_wave_bw3_validation_preflight_receipt_v1"
)
const BW3R_VALIDATION_MANIFEST_PATH := (
	"res://sdk/balanced_wave_bw3r_validation_manifest.json"
)
const BW3R_VALIDATION_MANIFEST_SCHEMA := (
	"sporespore_balanced_wave_bw3r_validation_manifest_v1"
)
const BW3R_VALIDATION_RECEIPT_SCHEMA := (
	"sporespore_balanced_wave_bw3r_validation_receipt_v1"
)
const BW3R_VALIDATION_PREFLIGHT_SCHEMA := (
	"sporespore_balanced_wave_bw3r_validation_preflight_receipt_v1"
)
const BW5V_VALIDATION_MANIFEST_PATH := (
	"res://sdk/balanced_wave_bw5v_validation_manifest.json"
)
const BW5V_VALIDATION_MANIFEST_SCHEMA := (
	"sporespore_balanced_wave_bw5v_validation_manifest_v1"
)
const BW5V_VALIDATION_RECEIPT_SCHEMA := (
	"sporespore_balanced_wave_bw5v_validation_receipt_v1"
)
const BW5V_VALIDATION_PREFLIGHT_SCHEMA := (
	"sporespore_balanced_wave_bw5v_validation_preflight_receipt_v1"
)
const BW2R_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw2r_preregistration.json"
const BW2R_PREREGISTRATION_SCHEMA := "sporespore_balanced_wave_bw2r_preregistration_v1"
const BW4R_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw4r_preregistration.json"
const BW4R_PREREGISTRATION_SCHEMA := "sporespore_balanced_wave_bw4r_preregistration_v1"
const BW5R_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw5r_preregistration.json"
const BW5R_PREREGISTRATION_SCHEMA := "sporespore_balanced_wave_bw5r_preregistration_v1"
const BW2R_REPLAY_CANDIDATES := {
	"--bw2r-a":
	{
		"candidate_id": "BW2R-A",
		"policy_id": "sporespore_balanced_wave_bw2r_a_v1",
		"policy_digest": "sha256:4ffb7abd947f60287b81c9105fb99b2964355d0e16e13b64bc8b18d9fcec6343",
	},
	"--bw2r-b":
	{
		"candidate_id": "BW2R-B",
		"policy_id": "sporespore_balanced_wave_bw2r_b_v1",
		"policy_digest": "sha256:44e8bfd0e4e1227db56ace8c58fc62fa6dd6bfc0d1cb993367510214272da144",
	},
	"--bw2r-c":
	{
		"candidate_id": "BW2R-C",
		"policy_id": "sporespore_balanced_wave_bw2r_c_v1",
		"policy_digest": "sha256:709aacc898e62a0c1902a04a201006f5501934562cabec4b68c1613811ae0ad0",
	},
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
const BW3_EXPECTED_GATE_COUNT := 22
const BW3_EXPECTED_WORLD_COUNT := 12
const BW3_EXPECTED_TREATMENT_COUNT := 9
const BW3_EXPECTED_CONTROL_COUNT := 3
const BW3_EXPECTED_PAIR_COUNT := 3
const BW3_CAMPAIGN_SEEDS := [17001, 17002, 17003]
const BW3_CONTROL_SEED := 17001
const BW3_CHARACTERIZATION_REPORT_SHA256 := (
	"94d3d9b6b2dc9086c4e21840540d8faf8d2fb7f64d915bc809d8969e9accd2e7"
)
const BW3_PROFILE_PUBLICATION_REPORT_SHA256 := (
	"1f829a4ece0b5a7256de7ae22e04fa866f88c372459a49356ffcde5f5e368934"
)
const BW3R_CAMPAIGN_SEEDS := [17501, 17502, 17503]
const BW3R_CONTROL_SEED := 17501
const BW3R_CHARACTERIZATION_REPORT_SHA256 := (
	"044952767924503bfd6f213dad930f24beedc256164d9bbceb5e8f31db44b1a1"
)
const BW3R_PROFILE_PUBLICATION_REPORT_SHA256 := (
	"7433787ac1dcf4264212f93b5b40c7ecde33fa4799c24c6da4bf7043782b68cb"
)
const BW5V_CAMPAIGN_SEEDS := [19501, 19502, 19503]
const BW5V_CONTROL_SEED := 19501
const BW5V_CHARACTERIZATION_REPORT_SHA256 := (
	"a99a7f2aa9798d26c7a4df9e9b218a5979195eb05dc97b02cd36a5dc21d45d84"
)
const BW5V_PROFILE_PUBLICATION_REPORT_SHA256 := (
	"2430c1a77d7007c13c3a5262e19fba7693154ba40ea61aa3d1cf601844a2a37c"
)
const BW3_MATERIAL_CELLS := [
	{
		"mu_token": "030",
		"authored_friction": 0.3,
		"profile_id": "godot_jolt_bw3_mu030_v1",
		"profile_digest":
		"sha256:b31f74eff128ef232ca37fd2e7e059881432ed9f004b62ae4e57404cc1bc6834",
	},
	{
		"mu_token": "070",
		"authored_friction": 0.7,
		"profile_id": "godot_jolt_bw3_mu070_v1",
		"profile_digest":
		"sha256:2d9d39248419f585393684118b42d264836a0210fdbe7fcb2636960b8e40932d",
	},
	{
		"mu_token": "120",
		"authored_friction": 1.2,
		"profile_id": "godot_jolt_bw3_mu120_v1",
		"profile_digest":
		"sha256:9d50f6feaa340f20f61359455d95d5b9a602b5f76f99c7d58df66a22df6ca8b8",
	},
]
const BW3_EXPECTED_CELL_IDS := [
	"validation_mu030_s17001_treatment",
	"validation_mu030_s17001_control",
	"validation_mu030_s17002_treatment",
	"validation_mu030_s17003_treatment",
	"validation_mu070_s17001_treatment",
	"validation_mu070_s17001_control",
	"validation_mu070_s17002_treatment",
	"validation_mu070_s17003_treatment",
	"validation_mu120_s17001_treatment",
	"validation_mu120_s17001_control",
	"validation_mu120_s17002_treatment",
	"validation_mu120_s17003_treatment",
]
const BW3R_MATERIAL_CELLS := [
	{
		"mu_token": "025",
		"authored_friction": 0.25,
		"profile_id": "godot_jolt_bw3r_mu025_v1",
		"profile_digest":
		"sha256:3583bba43c172171320faa2b8c0d93608cb4d4ef3f5bbbca5e70f4d1d331eb5a",
	},
	{
		"mu_token": "055",
		"authored_friction": 0.55,
		"profile_id": "godot_jolt_bw3r_mu055_v1",
		"profile_digest":
		"sha256:c0a3ed73c693f2d8c853040e35d9c284558c1dda3b8622b807ab9041a96db2af",
	},
	{
		"mu_token": "110",
		"authored_friction": 1.1,
		"profile_id": "godot_jolt_bw3r_mu110_v1",
		"profile_digest":
		"sha256:0377cca2ea355105bc9624ad9e270fa3750a947ad553b7b2cfb9c786f322fdd3",
	},
]
const BW3R_EXPECTED_CELL_IDS := [
	"validation_mu025_s17501_treatment",
	"validation_mu025_s17501_control",
	"validation_mu025_s17502_treatment",
	"validation_mu025_s17503_treatment",
	"validation_mu055_s17501_treatment",
	"validation_mu055_s17501_control",
	"validation_mu055_s17502_treatment",
	"validation_mu055_s17503_treatment",
	"validation_mu110_s17501_treatment",
	"validation_mu110_s17501_control",
	"validation_mu110_s17502_treatment",
	"validation_mu110_s17503_treatment",
]
const BW5V_MATERIAL_CELLS := [
	{
		"mu_token": "005",
		"authored_friction": 0.05,
		"profile_id": "godot_jolt_bw5v_mu005_v1",
		"profile_digest":
		"sha256:5634e67fc0b675da4643e7fa54004d31da44c1313fd6cee3cf6ea5a8d003aed0",
	},
	{
		"mu_token": "065",
		"authored_friction": 0.65,
		"profile_id": "godot_jolt_bw5v_mu065_v1",
		"profile_digest":
		"sha256:4d84c99d74ddf70cbbd9640ec074bd122dd9cf76f2949e884eb6569a4520e527",
	},
	{
		"mu_token": "130",
		"authored_friction": 1.3,
		"profile_id": "godot_jolt_bw5v_mu130_v1",
		"profile_digest":
		"sha256:3c4146e4c539406982d8d991f7dccf5d938f1f5077e3f0964b33ea9e12740082",
	},
]
const BW5V_EXPECTED_CELL_IDS := [
	"validation_mu005_s19501_treatment",
	"validation_mu005_s19501_control",
	"validation_mu005_s19502_treatment",
	"validation_mu005_s19503_treatment",
	"validation_mu065_s19501_treatment",
	"validation_mu065_s19501_control",
	"validation_mu065_s19502_treatment",
	"validation_mu065_s19503_treatment",
	"validation_mu130_s19501_treatment",
	"validation_mu130_s19501_control",
	"validation_mu130_s19502_treatment",
	"validation_mu130_s19503_treatment",
]

var _opened_development_replay := false
var _bw3r_mode := false
var _bw5v_mode := false


func _campaign_label() -> String:
	if _bw5v_mode:
		return "BW5V"
	return "BW3R" if _bw3r_mode else "BW3"


func _run() -> void:
	var user_args := OS.get_cmdline_user_args()
	_bw3r_mode = user_args.has("--bw3r")
	_bw5v_mode = user_args.has("--bw5v")
	print(
		"\n=== SDK balanced-wave %s frozen 12-world material validation ==="
		% _campaign_label()
	)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var allowed_args := ["--preflight-only"]
	if _bw3r_mode:
		allowed_args.append("--bw3r")
	if _bw5v_mode:
		allowed_args.append("--bw5v")
	var replay_arguments: Array[String] = []
	for argument_value in user_args:
		var argument := String(argument_value)
		if BW2R_REPLAY_CANDIDATES.has(argument):
			replay_arguments.append(argument)
	var arguments_valid := (
		user_args.size() <= 3
		and replay_arguments.size() <= 1
		and not (_bw3r_mode and _bw5v_mode)
	)
	if replay_arguments.size() == 1:
		allowed_args.append(replay_arguments[0])
	for argument_value in user_args:
		arguments_valid = arguments_valid and String(argument_value) in allowed_args
	if _bw3r_mode:
		arguments_valid = (
			arguments_valid
			and (
				replay_arguments == ["--bw2r-c"]
				or replay_arguments == ["--bw4r-a"]
				or replay_arguments == ["--bw4r-b"]
				or replay_arguments == ["--bw5r-a"]
				or replay_arguments == ["--bw5r-b"]
				or replay_arguments == ["--bw5r-c"]
			)
		)
	elif _bw5v_mode:
		arguments_valid = arguments_valid and replay_arguments == ["--bw5r-b"]
	if not arguments_valid:
		push_error(
			(
				"%s arguments do not match the frozen candidate and campaign contract"
				% _campaign_label()
			)
		)
		quit(1)
		return

	_bw2_mode = true
	if replay_arguments.is_empty():
		_bw2_candidate_id = "BW2-C"
		_bw2_policy_id = "sporespore_balanced_wave_bw2_c_v1"
		_bw2_policy_digest = (
			"sha256:367e944b33384d8685d746dca0a864cfa33ca013846636236512641456d51ad3"
		)
	else:
		var replay: Dictionary = BW2R_REPLAY_CANDIDATES[replay_arguments[0]]
		_bw2_candidate_id = String(replay["candidate_id"])
		_bw2_policy_id = String(replay["policy_id"])
		_bw2_policy_digest = String(replay["policy_digest"])
		_opened_development_replay = (
			not _bw5v_mode
			and (
				not _bw3r_mode
				or _bw2_candidate_id.begins_with("BW4R-")
				or _bw2_candidate_id.begins_with("BW5R-")
			)
		)
	await _run_bw3_validation(user_args.has("--preflight-only"))


func _campaign_seeds() -> Array:
	if _bw5v_mode:
		return BW5V_CAMPAIGN_SEEDS
	return BW3R_CAMPAIGN_SEEDS if _bw3r_mode else BW3_CAMPAIGN_SEEDS


func _control_seed() -> int:
	if _bw5v_mode:
		return BW5V_CONTROL_SEED
	return BW3R_CONTROL_SEED if _bw3r_mode else BW3_CONTROL_SEED


func _material_cells() -> Array:
	if _bw5v_mode:
		return BW5V_MATERIAL_CELLS
	return BW3R_MATERIAL_CELLS if _bw3r_mode else BW3_MATERIAL_CELLS


func _required_profile_ids() -> Array:
	var result: Array = []
	for material_value in _material_cells():
		result.append(String((material_value as Dictionary)["profile_id"]))
	return result


func _expected_cell_ids() -> Array:
	if _bw5v_mode:
		return BW5V_EXPECTED_CELL_IDS
	return BW3R_EXPECTED_CELL_IDS if _bw3r_mode else BW3_EXPECTED_CELL_IDS


func _expected_world_count() -> int:
	return BW3_EXPECTED_WORLD_COUNT


func _bridge_profile_id() -> String:
	if _bw5v_mode:
		return "godot_jolt_bw5v_mu005_v1"
	return (
		"godot_jolt_bw3r_mu025_v1"
		if _bw3r_mode
		else "godot_jolt_bw3_mu030_v1"
	)


func _build_matrix() -> Array:
	var matrix: Array = []
	for material_value in _material_cells():
		var material: Dictionary = material_value
		for seed_value in _campaign_seeds():
			var seed := int(seed_value)
			matrix.append(_cell_spec("validation", "treatment", material, seed))
			if seed == _control_seed():
				matrix.append(_cell_spec("validation", "control", material, seed))
	return matrix


func _matrix_cardinality_exact(matrix: Array) -> bool:
	var treatment_count := 0
	var control_count := 0
	for cell_value in matrix:
		var cell: Dictionary = cell_value
		if String(cell.get("cohort", "")) != "validation":
			return false
		if String(cell.get("mode", "")) == "treatment":
			treatment_count += 1
		elif String(cell.get("mode", "")) == "control":
			control_count += 1
		else:
			return false
	return (
		matrix.size() == BW3_EXPECTED_WORLD_COUNT
		and treatment_count == BW3_EXPECTED_TREATMENT_COUNT
		and control_count == BW3_EXPECTED_CONTROL_COUNT
	)


func _validation_manifest_receipt() -> Dictionary:
	var manifest_path := (
		BW5V_VALIDATION_MANIFEST_PATH
		if _bw5v_mode
		else (
			BW3R_VALIDATION_MANIFEST_PATH
			if _bw3r_mode
			else BW3_VALIDATION_MANIFEST_PATH
		)
	)
	var expected_manifest_schema := (
		BW5V_VALIDATION_MANIFEST_SCHEMA
		if _bw5v_mode
		else (
			BW3R_VALIDATION_MANIFEST_SCHEMA
			if _bw3r_mode
			else BW3_VALIDATION_MANIFEST_SCHEMA
		)
	)
	var expected_status := (
		"frozen_before_first_bw5v_validation_world"
		if _bw5v_mode
		else (
			"frozen_before_first_bw3r_validation_world"
			if _bw3r_mode
			else "frozen_before_first_bw3_validation_world"
		)
	)
	var expected_freeze_parent := (
		"e76477be61d90829dab0eb70a89505d521e7f8a5"
		if _bw5v_mode
		else (
			"2997ea65e6c0a2dce0d3b06ad5ceeb1c50df0beb"
			if _bw3r_mode
			else "03f36ec58be6c10fdd451db9c278142d54a5f5d0"
		)
	)
	var expected_characterization_hash := (
		BW5V_CHARACTERIZATION_REPORT_SHA256
		if _bw5v_mode
		else (
			BW3R_CHARACTERIZATION_REPORT_SHA256
			if _bw3r_mode
			else BW3_CHARACTERIZATION_REPORT_SHA256
		)
	)
	var expected_publication_hash := (
		BW5V_PROFILE_PUBLICATION_REPORT_SHA256
		if _bw5v_mode
		else (
			BW3R_PROFILE_PUBLICATION_REPORT_SHA256
			if _bw3r_mode
			else BW3_PROFILE_PUBLICATION_REPORT_SHA256
		)
	)
	var expected_candidate_id := (
		"BW5R-B" if _bw5v_mode else ("BW2R-C" if _bw3r_mode else "BW2-C")
	)
	var expected_policy_id := (
		"sporespore_balanced_wave_bw5r_b_v1"
		if _bw5v_mode
		else (
			"sporespore_balanced_wave_bw2r_c_v1"
			if _bw3r_mode
			else "sporespore_balanced_wave_bw2_c_v1"
		)
	)
	var expected_policy_digest := (
		"sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
		if _bw5v_mode
		else (
			"sha256:709aacc898e62a0c1902a04a201006f5501934562cabec4b68c1613811ae0ad0"
			if _bw3r_mode
			else "sha256:367e944b33384d8685d746dca0a864cfa33ca013846636236512641456d51ad3"
		)
	)
	var parsed := _load_json_dictionary(manifest_path)
	if parsed.is_empty():
		return _manifest_failure("%s_VALIDATION_MANIFEST_UNREADABLE" % _campaign_label())
	var selected: Dictionary = parsed.get("selected_policy", {})
	var prerequisite: Dictionary = parsed.get("prerequisite_evidence", {})
	var characterization: Dictionary = prerequisite.get("material_characterization", {})
	var publication: Dictionary = prerequisite.get("material_profile_publication", {})
	var matrix: Dictionary = parsed.get("matrix", {})
	var gate_contract: Dictionary = parsed.get("gate_contract", {})
	var claims: Dictionary = parsed.get("claims", {})
	var cold_reservation: Dictionary = parsed.get("cold_reservation_interlock", {})
	var manifest_profiles: Array = parsed.get("profiles", [])
	var manifest_profile_ids: Array = []
	var manifest_profile_digests: Array = []
	var material_cells := _material_cells()
	var profiles_exact := manifest_profiles.size() == material_cells.size()
	for index in range(manifest_profiles.size()):
		var profile: Dictionary = manifest_profiles[index]
		manifest_profile_ids.append(String(profile.get("profile_id", "")))
		manifest_profile_digests.append(String(profile.get("profile_digest", "")))
		if index >= material_cells.size():
			profiles_exact = false
			continue
		var expected: Dictionary = material_cells[index]
		var resolved: Dictionary = MaterialProfilesScript.resolve(String(expected["profile_id"]))
		profiles_exact = (
			profiles_exact
			and bool(resolved.get("ok", false))
			and String(profile.get("profile_id", "")) == String(expected["profile_id"])
			and String(profile.get("profile_digest", "")) == String(expected["profile_digest"])
			and String(resolved.get("profile_sha256", "")) == String(expected["profile_digest"])
			and (
				absf(float(profile.get("authored_friction", NAN)) - float(expected["authored_friction"]))
				<= 1.0e-12
			)
		)
	var characterization_path := String(characterization.get("path", ""))
	var publication_path := String(publication.get("path", ""))
	var characterization_hash_exact := (
		not characterization_path.is_empty()
		and FileAccess.file_exists(characterization_path)
		and FileAccess.get_sha256(characterization_path) == expected_characterization_hash
	)
	var publication_hash_exact := (
		not publication_path.is_empty()
		and FileAccess.file_exists(publication_path)
		and FileAccess.get_sha256(publication_path) == expected_publication_hash
	)
	var ordered_cell_ids: Array = []
	for cell_id_value in matrix.get("ordered_cell_ids", []):
		ordered_cell_ids.append(String(cell_id_value))
	var seeds: Array = []
	for seed_value in matrix.get("seeds", []):
		seeds.append(int(seed_value))
	var metadata_exact: bool = (
		String(parsed.get("schema_version", "")) == expected_manifest_schema
		and String(parsed.get("status", "")) == expected_status
		and String(parsed.get("freeze_parent_commit", "")) == expected_freeze_parent
		and bool(parsed.get("development_data_only", false))
		and (not _bw5v_mode or bool(parsed.get("independent_validation", false)))
		and not bool(parsed.get("cold_acceptance", true))
	)
	var policy_exact: bool = (
		String(selected.get("candidate_id", "")) == expected_candidate_id
		and String(selected.get("policy_id", "")) == expected_policy_id
		and String(selected.get("policy_digest", "")) == expected_policy_digest
		and (
			not _bw5v_mode
			or (
				String(selected.get("runtime_profile_digest", ""))
				== "sha256:e02fa9c7599cffe8b331f7d8c10b6cc4dbffe7408e319169c09cbcb7d9b3890e"
			)
		)
		and (
			not _bw5v_mode
			or (
				_bw2_candidate_id == expected_candidate_id
				and _bw2_policy_id == expected_policy_id
				and _bw2_policy_digest == expected_policy_digest
			)
		)
	)
	var replay_policy_exact := _bw2r_replay_policy_exact()
	var prerequisite_exact: bool = (
		(
			String(characterization.get("sha256", ""))
			== expected_characterization_hash
		)
		and bool(characterization.get("accepted", false))
		and int(characterization.get("observed_world_count", -1)) == 10
		and (
			not _bw5v_mode
			or (
				String(characterization.get("schema_version", ""))
				== "sporespore_balanced_wave_bw5v_material_characterization_report_v1"
				and (
					String(characterization.get("source_commit", ""))
					== "2a5eb94dca81a8c638e31a0d7c9692c270b44ca6"
				)
				and int(characterization.get("passed_gate_count", -1)) == 19
			)
		)
		and characterization_hash_exact
		and String(publication.get("sha256", "")) == expected_publication_hash
		and bool(publication.get("accepted", false))
		and int(publication.get("observed_world_count", -1)) == 0
		and (
			not _bw5v_mode
			or (
				String(publication.get("schema_version", ""))
				== "sporespore_godot_jolt_material_profile_report_v1"
				and (
					String(publication.get("source_commit", ""))
					== "e76477be61d90829dab0eb70a89505d521e7f8a5"
				)
			)
		)
		and int(publication.get("passed_gate_count", -1))
		== (32 if _bw5v_mode else (25 if _bw3r_mode else 22))
		and publication_hash_exact
	)
	var matrix_exact: bool = (
		seeds == _campaign_seeds()
		and ordered_cell_ids == _expected_cell_ids()
		and int(matrix.get("expected_treatment_world_count", -1)) == BW3_EXPECTED_TREATMENT_COUNT
		and int(matrix.get("expected_control_world_count", -1)) == BW3_EXPECTED_CONTROL_COUNT
		and int(matrix.get("expected_causal_pair_count", -1)) == BW3_EXPECTED_PAIR_COUNT
		and int(matrix.get("expected_world_count", -1)) == BW3_EXPECTED_WORLD_COUNT
		and int(matrix.get("exposure_steps", -1)) == EXPECTED_STEP_COUNT
		and (
			int(matrix.get("expected_base_commands_and_motor_writes_per_treatment", -1))
			== EXPECTED_MOTOR_WRITE_COUNT
		)
		and int(matrix.get("control_seed", -1)) == _control_seed()
		and (
			absf(
				float(matrix.get("minimum_terminal_pair_separation_m", NAN))
				- MINIMUM_PAIRED_TERMINAL_SEPARATION_M
			)
			<= 1.0e-15
		)
	)
	var gates_exact: bool = (
		int(gate_contract.get("expected_gate_count", -1)) == BW3_EXPECTED_GATE_COUNT
		and bool(gate_contract.get("averaging_forbidden", false))
		and bool(gate_contract.get("failed_cell_replacement_forbidden", false))
		and bool(gate_contract.get("post_result_gate_edit_forbidden", false))
		and bool(gate_contract.get("first_result_is_final_for_this_source_identity", false))
	)
	var claims_exact: bool = (
		bool(
			claims.get(
				"bw5v_independent_validation_authority"
				if _bw5v_mode
				else (
					"bw3r_validation_authority"
					if _bw3r_mode
					else "bw3_validation_authority"
				),
				false,
			)
		)
		and _all_broader_claims_false(claims)
	)
	var cold_friction_values: Array = []
	for value in cold_reservation.get("authored_friction_values", []):
		cold_friction_values.append(float(value))
	var cold_campaign_seeds: Array = []
	for value in cold_reservation.get("campaign_seeds", []):
		cold_campaign_seeds.append(int(value))
	var cold_reservation_exact: bool = (
		not _bw5v_mode
		or (
			cold_friction_values == [0.12, 0.48, 0.95, 1.5]
			and cold_campaign_seeds == [20001, 20002, 20003]
			and bool(cold_reservation.get("remains_unopened_during_bw5v_validation", false))
			and bool(
				cold_reservation.get(
					"new_characterization_profile_publication_and_manifest_required",
					false,
				)
			)
		)
	)
	var exact: bool = (
		metadata_exact
		and policy_exact
		and replay_policy_exact
		and prerequisite_exact
		and profiles_exact
		and matrix_exact
		and gates_exact
		and claims_exact
		and cold_reservation_exact
	)
	return {
		"ok": exact,
		"failure_code": (
			""
			if exact
			else "%s_VALIDATION_MANIFEST_MISMATCH" % _campaign_label()
		),
		"schema_version": String(parsed.get("schema_version", "")),
		"status": String(parsed.get("status", "")),
		"manifest_path": (
			"sdk/balanced_wave_bw5v_validation_manifest.json"
			if _bw5v_mode
			else (
				"sdk/balanced_wave_bw3r_validation_manifest.json"
				if _bw3r_mode
				else "sdk/balanced_wave_bw3_validation_manifest.json"
			)
		),
		"selected_policy_id": String(selected.get("policy_id", "")),
		"selected_policy_digest": String(selected.get("policy_digest", "")),
		"active_policy_id": _bw2_policy_id,
		"active_policy_digest": _bw2_policy_digest,
		"opened_development_replay": _opened_development_replay,
		"replay_policy_exact": replay_policy_exact,
		"characterization_report_path": characterization_path,
		"characterization_report_sha256": String(characterization.get("sha256", "")),
		"characterization_report_hash_exact": characterization_hash_exact,
		"profile_publication_report_path": publication_path,
		"profile_publication_report_sha256": String(publication.get("sha256", "")),
		"profile_publication_report_hash_exact": publication_hash_exact,
		"profile_ids": manifest_profile_ids,
		"profile_digests": manifest_profile_digests,
		"metadata_exact": metadata_exact,
		"policy_exact": policy_exact,
		"prerequisite_exact": prerequisite_exact,
		"profiles_exact": profiles_exact,
		"matrix_exact": matrix_exact,
		"gates_exact": gates_exact,
		"claims_exact": claims_exact,
		"cold_reservation_exact": cold_reservation_exact,
		"cell_ids": ordered_cell_ids.duplicate(),
		"expected_gate_count": int(gate_contract.get("expected_gate_count", -1)),
		"expected_world_count": int(matrix.get("expected_world_count", -1)),
		"world_build_count": 0,
		"locomotion_outcome_exposed": false,
	}


func _run_bw3_validation(preflight_only: bool) -> void:
	var preflight := _compile_preflight()
	if preflight_only:
		var receipt := _bw3_preflight_receipt(preflight)
		print(
			(
				"BALANCED_WAVE_BW5V_VALIDATION_PREFLIGHT_RECEIPT "
				if _bw5v_mode
				else (
					"BALANCED_WAVE_BW3R_VALIDATION_PREFLIGHT_RECEIPT "
					if _bw3r_mode
					else "BALANCED_WAVE_BW3_VALIDATION_PREFLIGHT_RECEIPT "
				)
			),
			JSON.stringify(receipt, "", true, true),
		)
		quit(0 if bool(receipt.get("ok", false)) else 1)
		return

	var clock_ok := bool(preflight.get("clock_ok", false))
	var matrix_ok := bool(preflight.get("matrix_ok", false))
	var inputs_ok := bool(preflight.get("inputs_ok", false))
	_check(clock_ok, "1 the frozen GQ15 clock compiles exactly")
	_check(matrix_ok, "2 the frozen ordered BW3 12-world matrix is exact")
	_check(inputs_ok, "3 every frozen evidence input, profile, seed, fixture, and binding compiles")
	if not (clock_ok and matrix_ok and inputs_ok):
		_emit_bw3_receipt(preflight, [], [], _empty_metrics())
		_finish_bw3()
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
	var treatment_pass_count := 0
	var control_pass_count := 0
	var treatment_with_nonzero_stability_count := 0

	for cell_value in matrix:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		var profile_id := String(cell["profile_id"])
		var seed_key := str(int(cell["campaign_seed"]))
		var input: Dictionary = input_by_profile[profile_id]
		var perturbation: Dictionary = perturbation_by_seed[seed_key]
		print(
			"BW3_VALIDATION_CELL_START ",
			cell_id,
			" world=",
			cell_receipts.size() + 1,
			"/",
			BW3_EXPECTED_WORLD_COUNT,
		)
		var summary: Dictionary = await _run_cell(
			gait_clock_options,
			cell,
			perturbation,
			input["fixture_spec"],
		)
		summary_by_cell_id[cell_id] = summary
		var cell_receipt := _analyze_cell(cell, summary, perturbation, input, true)
		cell_receipts.append(cell_receipt)
		var execution_ok := bool(cell_receipt.get("campaign_execution_gate_passed", false))
		_check(execution_ok, "%s completes its frozen role-specific execution gate" % cell_id)
		if not execution_ok:
			integrity_failure_count += 1
		if String(cell["mode"]) == "treatment":
			treatment_count += 1
			if bool(cell_receipt.get("treatment_gate_passed", false)):
				treatment_pass_count += 1
			var contribution: Dictionary = cell_receipt.get("stability_contribution_shadow", {})
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
		print("BALANCED_WAVE_BW3_VALIDATION_CELL ", JSON.stringify(cell_receipt, "", true, true))

	var paired_receipts := _bw3_paired_receipts(summary_by_cell_id)
	var roles_exact := (
		cell_receipts.size() == BW3_EXPECTED_WORLD_COUNT
		and treatment_count == BW3_EXPECTED_TREATMENT_COUNT
		and control_count == BW3_EXPECTED_CONTROL_COUNT
	)
	_check(roles_exact, "16 all 12 frozen roles complete with exact 9-treatment/3-control cardinality")
	var integrity_complete := integrity_failure_count == 0
	_check(integrity_complete, "17 the complete BW3 matrix has zero infrastructure or integrity failures")
	var stability_complete := (
		treatment_with_nonzero_stability_count == BW3_EXPECTED_TREATMENT_COUNT
	)
	_check(stability_complete, "18 all nine treatments apply nonzero stability influence")
	var treatments_complete := treatment_pass_count == BW3_EXPECTED_TREATMENT_COUNT
	_check(treatments_complete, "19 all nine treatments pass every ordinary physical walking gate")
	var controls_complete := control_pass_count == BW3_EXPECTED_CONTROL_COUNT
	_check(controls_complete, "20 all three material-matched controls pass their shadow gates")
	var pairs_complete := (
		paired_receipts.size() == BW3_EXPECTED_PAIR_COUNT
		and _all_pair_gates_pass(paired_receipts)
	)
	_check(pairs_complete, "21 all three matched pairs retain identity and nonzero terminal separation")
	# The manifest verifier checked the frozen claims object before any world.
	# The result receipt also binds the runtime campaign to the same false
	# broader-claim fields instead of granting acceptance by implication.
	var broader_claims_false: bool = (
		bool((preflight.get("validation_manifest", {}) as Dictionary).get("ok", false))
		and not bool(preflight.get("continuous_friction_coverage", true))
		and not bool(preflight.get("cross_engine_equivalence", true))
		and not bool(preflight.get("rough_terrain_robustness", true))
		and not bool(preflight.get("external_push_recovery", true))
		and not bool(preflight.get("sensor_fault_robustness", true))
		and not bool(preflight.get("fresh_morphology_validation", true))
		and not bool(preflight.get("completed_sdk", true))
	)
	_check(broader_claims_false, "22 every broader robustness, acceptance, and completed-SDK claim remains false")

	_emit_bw3_receipt(
		preflight,
		cell_receipts,
		paired_receipts,
		{
			"integrity_failure_count": integrity_failure_count,
			"treatment_count": treatment_count,
			"control_count": control_count,
			"treatment_pass_count": treatment_pass_count,
			"control_pass_count": control_pass_count,
			"treatment_with_nonzero_stability_count":
			treatment_with_nonzero_stability_count,
			"pair_pass_count": _pair_pass_count(paired_receipts),
			"roles_exact": roles_exact,
			"integrity_complete": integrity_complete,
			"stability_complete": stability_complete,
			"treatments_complete": treatments_complete,
			"controls_complete": controls_complete,
			"pairs_complete": pairs_complete,
			"broader_claims_false": broader_claims_false,
		},
	)
	_finish_bw3()


func _bw3_preflight_receipt(preflight: Dictionary) -> Dictionary:
	return {
		"schema_version": (
			BW5V_VALIDATION_PREFLIGHT_SCHEMA
			if _bw5v_mode
			else (
				BW3R_VALIDATION_PREFLIGHT_SCHEMA
				if _bw3r_mode
				else BW3_VALIDATION_PREFLIGHT_SCHEMA
			)
		),
		"ok": bool(preflight.get("ok", false)),
		"candidate_id": _bw2_candidate_id,
		"policy_id": _bw2_policy_id,
		"candidate_policy_digest": _bw2_policy_digest,
		"clock_ok": bool(preflight.get("clock_ok", false)),
		"matrix_ok": bool(preflight.get("matrix_ok", false)),
		"inputs_ok": bool(preflight.get("inputs_ok", false)),
		"validation_manifest":
		(preflight.get("validation_manifest", {}) as Dictionary).duplicate(true),
		"expected_world_count": BW3_EXPECTED_WORLD_COUNT,
		"observed_world_count": 0,
		"cell_ids": (preflight.get("cell_ids", []) as Array).duplicate(),
		"seed_receipts": (preflight.get("seed_receipts", []) as Array).duplicate(true),
		"task_frame_receipts": (preflight.get("task_frame_receipts", []) as Array).duplicate(true),
		"bridge_conformance":
		(preflight.get("bridge_conformance", {}) as Dictionary).duplicate(true),
		"profile_receipts": (preflight.get("profile_receipts", []) as Array).duplicate(true),
		"locomotion_outcome_exposed": false,
		"adapter_actuation_applied": false,
		"physics_transform_or_velocity_written": false,
		"development_data_only": true,
		"opened_validation_replay": _opened_development_replay,
		"validation_data_only": not _opened_development_replay,
		"cold_acceptance": false,
		"walking_acceptance": false,
		"material_robustness": false,
		"cross_engine_c6": false,
		"completed_engine_neutral_sdk": false,
		"physical_acceptance_authority": false,
	}


func _emit_bw3_receipt(
	preflight: Dictionary,
	cell_receipts: Array,
	paired_receipts: Array,
	metrics: Dictionary,
) -> void:
	var validation_passed := (
		_failed == 0
		and _passed == BW3_EXPECTED_GATE_COUNT
		and bool(metrics.get("roles_exact", false))
		and bool(metrics.get("integrity_complete", false))
		and bool(metrics.get("stability_complete", false))
		and bool(metrics.get("treatments_complete", false))
		and bool(metrics.get("controls_complete", false))
		and bool(metrics.get("pairs_complete", false))
		and bool(metrics.get("broader_claims_false", false))
	)
	var receipt := {
		"schema_version": (
			BW5V_VALIDATION_RECEIPT_SCHEMA
			if _bw5v_mode
			else (
				BW3R_VALIDATION_RECEIPT_SCHEMA
				if _bw3r_mode
				else BW3_VALIDATION_RECEIPT_SCHEMA
			)
		),
		"ok": validation_passed,
		"validation_passed": validation_passed,
		"candidate_id": _bw2_candidate_id,
		"policy_id": _bw2_policy_id,
		"candidate_policy_digest": _bw2_policy_digest,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": BW3_EXPECTED_GATE_COUNT,
		"expected_world_count": BW3_EXPECTED_WORLD_COUNT,
		"observed_world_count": cell_receipts.size(),
		"expected_treatment_count": BW3_EXPECTED_TREATMENT_COUNT,
		"observed_treatment_count": int(metrics.get("treatment_count", 0)),
		"observed_treatment_pass_count": int(metrics.get("treatment_pass_count", 0)),
		"expected_control_count": BW3_EXPECTED_CONTROL_COUNT,
		"observed_control_count": int(metrics.get("control_count", 0)),
		"observed_control_pass_count": int(metrics.get("control_pass_count", 0)),
		"expected_pair_count": BW3_EXPECTED_PAIR_COUNT,
		"observed_pair_pass_count": int(metrics.get("pair_pass_count", 0)),
		"treatment_with_nonzero_stability_count":
		int(metrics.get("treatment_with_nonzero_stability_count", 0)),
		"integrity_failure_count": int(metrics.get("integrity_failure_count", -1)),
		"validation_manifest":
		(preflight.get("validation_manifest", {}) as Dictionary).duplicate(true),
		"cell_ids": (preflight.get("cell_ids", []) as Array).duplicate(),
		"seed_receipts": (preflight.get("seed_receipts", []) as Array).duplicate(true),
		"profile_receipts": (preflight.get("profile_receipts", []) as Array).duplicate(true),
		"cells": cell_receipts.duplicate(true),
		"paired_controls": paired_receipts.duplicate(true),
		"development_data_only": true,
		"opened_validation_replay": _opened_development_replay,
		"validation_data_only": not _opened_development_replay,
		"cold_acceptance": false,
		"walking_acceptance": false,
		"material_robustness": false,
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
		(
			"BALANCED_WAVE_BW5V_VALIDATION_RECEIPT "
			if _bw5v_mode
			else (
				"BALANCED_WAVE_BW3R_VALIDATION_RECEIPT "
				if _bw3r_mode
				else "BALANCED_WAVE_BW3_VALIDATION_RECEIPT "
			)
		),
		JSON.stringify(receipt, "", true, true),
	)


func _bw2r_replay_policy_exact() -> bool:
	if _bw5v_mode:
		var selected_policy := _load_json_dictionary(
			"res://sdk/balanced_wave_selected_policy.json"
		)
		var selected_profile: Dictionary = selected_policy.get("selected_profile", {})
		var claims: Dictionary = selected_policy.get("claims", {})
		return (
			String(selected_policy.get("schema_version", ""))
			== "sporespore_balanced_wave_selected_policy_v1"
			and (
				String(selected_policy.get("status", ""))
				== "frozen_after_bw5r_development_before_new_validation"
			)
			and bool(selected_policy.get("development_selection_authority", false))
			and String(selected_policy.get("selected_candidate_id", "")) == "BW5R-B"
			and (
				String(selected_policy.get("selected_policy_id", ""))
				== "sporespore_balanced_wave_bw5r_b_v1"
			)
			and (
				String(selected_policy.get("selected_candidate_policy_digest", ""))
				== "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
			)
			and (
				String(selected_profile.get("runtime_profile_sha256", ""))
				== "sha256:e02fa9c7599cffe8b331f7d8c10b6cc4dbffe7408e319169c09cbcb7d9b3890e"
			)
			and (selected_profile.get("branch_surfaces", []) as Array).is_empty()
			and _bw2_candidate_id == "BW5R-B"
			and _bw2_policy_id == "sporespore_balanced_wave_bw5r_b_v1"
			and (
				_bw2_policy_digest
				== "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
			)
			and not bool(claims.get("walking_acceptance", true))
			and not bool(claims.get("material_robustness", true))
			and not bool(claims.get("arbitrary_quadruped_coverage", true))
			and not bool(claims.get("continuous_full_volume_coverage", true))
			and not bool(claims.get("cross_engine_c6", true))
			and not bool(claims.get("completed_engine_neutral_sdk", true))
			and not bool(claims.get("physical_acceptance_authority", true))
		)
	if not _opened_development_replay and not _bw3r_mode:
		return (
			_bw2_candidate_id == "BW2-C"
			and _bw2_policy_id == "sporespore_balanced_wave_bw2_c_v1"
			and (
				_bw2_policy_digest
				== "sha256:367e944b33384d8685d746dca0a864cfa33ca013846636236512641456d51ad3"
			)
		)
	var bw4r_replay := _bw2_candidate_id.begins_with("BW4R-")
	var bw5r_replay := _bw2_candidate_id.begins_with("BW5R-")
	var successor_replay := bw4r_replay or bw5r_replay
	var preregistration_path := (
		BW5R_PREREGISTRATION_PATH
		if bw5r_replay
		else (BW4R_PREREGISTRATION_PATH if bw4r_replay else BW2R_PREREGISTRATION_PATH)
	)
	var preregistration_schema := (
		BW5R_PREREGISTRATION_SCHEMA
		if bw5r_replay
		else (BW4R_PREREGISTRATION_SCHEMA if bw4r_replay else BW2R_PREREGISTRATION_SCHEMA)
	)
	var preregistration_status := (
		"frozen_before_first_bw5r_physics_world"
		if bw5r_replay
		else (
			"frozen_before_first_bw4r_physics_world"
			if bw4r_replay
			else "frozen_before_first_bw2r_physics_world"
		)
	)
	var preregistration := _load_json_dictionary(
		preregistration_path
	)
	if (
		String(preregistration.get("schema_version", ""))
		!= preregistration_schema
		or (
			String(preregistration.get("status", ""))
			!= preregistration_status
		)
		or (
			int(
				(
					preregistration.get(
						"development_matrix" if successor_replay else "physics_matrix",
						{},
					) as Dictionary
				).get(
					(
						"expected_world_count_per_candidate"
						if successor_replay
						else "total_world_count_per_opened_candidate"
					),
					-1,
				)
			)
			!= (58 if successor_replay else 41)
		)
		or (
			not successor_replay
			and not bool(
			(preregistration.get("post_selection_validation", {}) as Dictionary).get(
				"old_bw3_is_development_data_after_first_result",
				false,
			)
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
			and (candidate.get("branch_surfaces", []) as Array).is_empty()
		)
	return false


func _bw3_paired_receipts(summary_by_cell_id: Dictionary) -> Array:
	var pairs: Array = []
	for material_value in _material_cells():
		var material: Dictionary = material_value
		var token := String(material["mu_token"])
		var treatment_id := "validation_mu%s_s%d_treatment" % [token, _control_seed()]
		var control_id := "validation_mu%s_s%d_control" % [token, _control_seed()]
		if not summary_by_cell_id.has(treatment_id) or not summary_by_cell_id.has(control_id):
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
				"pair_id": "validation_mu%s_s%d_pair" % [token, _control_seed()],
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


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _manifest_failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"manifest_path": (
			"sdk/balanced_wave_bw5v_validation_manifest.json"
			if _bw5v_mode
			else (
				"sdk/balanced_wave_bw3r_validation_manifest.json"
				if _bw3r_mode
				else "sdk/balanced_wave_bw3_validation_manifest.json"
			)
		),
		"world_build_count": 0,
		"locomotion_outcome_exposed": false,
	}


static func _all_broader_claims_false(claims: Dictionary) -> bool:
	for claim_name in [
		"walking_acceptance",
		"material_robustness",
		"arbitrary_material_robustness",
		"continuous_friction_coverage",
		"balance_improvement",
		"physical_balance_recovery",
		"rough_terrain_robustness",
		"external_push_recovery",
		"sensor_fault_robustness",
		"arbitrary_quadruped_coverage",
		"continuous_full_volume_coverage",
		"cross_engine_c6",
		"completed_engine_neutral_sdk",
		"physical_acceptance_authority",
	]:
		if bool(claims.get(claim_name, true)):
			return false
	return true


static func _empty_metrics() -> Dictionary:
	return {
		"integrity_failure_count": -1,
		"treatment_count": 0,
		"control_count": 0,
		"treatment_pass_count": 0,
		"control_pass_count": 0,
		"treatment_with_nonzero_stability_count": 0,
		"pair_pass_count": 0,
		"roles_exact": false,
		"integrity_complete": false,
		"stability_complete": false,
		"treatments_complete": false,
		"controls_complete": false,
		"pairs_complete": false,
		"broader_claims_false": false,
	}


func _finish_bw3() -> void:
	print(
		"\nSDK balanced-wave %s validation summary: %d passed, %d failed"
		% [_campaign_label(), _passed, _failed]
	)
	if _failed == 0 and _passed != BW3_EXPECTED_GATE_COUNT:
		_failed += 1
		push_error(
			"Expected %d %s validation gates, observed %d"
			% [BW3_EXPECTED_GATE_COUNT, _campaign_label(), _passed]
		)
	quit(0 if _failed == 0 else 1)
