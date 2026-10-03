extends SceneTree

const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")
const SpecCompilerScript := preload("res://scripts/lab/spec_compiler.gd")

const CATALOG_PATH := (
	"res://data/lab/campaigns/BR1_L0_certification_v1.json")
const EXPECTED_CELL_IDS := [
	"BR1_L0_0_STATIONARY_60HZ_V1",
	"BR1_L0_1_FREE_FALL_30HZ_V1",
	"BR1_L0_1_FREE_FALL_60HZ_V1",
	"BR1_L0_1_FREE_FALL_120HZ_V1",
	"BR1_L0_2_BALLISTIC_GRAVITY_OFF_60HZ_V1",
	"BR1_L0_2_BALLISTIC_GRAVITY_ON_60HZ_V1",
	"BR1_L0_3_OBSERVER_AB_60HZ_V1",
]
const EXPECTED := {
	"BR1_L0_0_STATIONARY_60HZ_V1": {
		"path": "res://data/lab/experiments/br1/BR1_L0_0_stationary_60hz_v1.tres",
		"experiment_id": "L0_0_STATIONARY_GRAVITY_OFF",
		"duration_ticks": 60,
		"physics_hz": 60,
		"gravity_scale": 0.0,
		"independent_variables": [],
		"gate_parameters": {
			"external_work_j": 0.0,
			"max_position_error_m": 1.0e-7,
			"max_velocity_error_m_s": 1.0e-7,
			"total_contact_count": 0.0,
		},
		"comparison_profiles": [],
	},
	"BR1_L0_1_FREE_FALL_30HZ_V1": {
		"path": "res://data/lab/experiments/br1/BR1_L0_1_free_fall_30hz_v1.tres",
		"experiment_id": "L0_1_FREE_FALL",
		"duration_ticks": 15,
		"physics_hz": 30,
		"gravity_scale": 1.0,
		"independent_variables": ["/physics_ticks_per_second"],
		"gate_parameters": {
			"max_acceleration_error_m_s2": 0.02,
			"max_position_error_m": 0.089925,
			"max_velocity_error_m_s": 0.02,
		},
		"comparison_profiles": [],
	},
	"BR1_L0_1_FREE_FALL_60HZ_V1": {
		"path": "res://data/lab/experiments/br1/BR1_L0_1_free_fall_60hz_v1.tres",
		"experiment_id": "L0_1_FREE_FALL",
		"duration_ticks": 30,
		"physics_hz": 60,
		"gravity_scale": 1.0,
		"independent_variables": ["/physics_ticks_per_second"],
		"gate_parameters": {
			"max_acceleration_error_m_s2": 0.02,
			"max_position_error_m": 0.0449625,
			"max_velocity_error_m_s": 0.02,
		},
		"comparison_profiles": [],
	},
	"BR1_L0_1_FREE_FALL_120HZ_V1": {
		"path": "res://data/lab/experiments/br1/BR1_L0_1_free_fall_120hz_v1.tres",
		"experiment_id": "L0_1_FREE_FALL",
		"duration_ticks": 60,
		"physics_hz": 120,
		"gravity_scale": 1.0,
		"independent_variables": ["/physics_ticks_per_second"],
		"gate_parameters": {
			"max_acceleration_error_m_s2": 0.02,
			"max_position_error_m": 0.02248125,
			"max_velocity_error_m_s": 0.02,
		},
		"comparison_profiles": [],
	},
	"BR1_L0_2_BALLISTIC_GRAVITY_OFF_60HZ_V1": {
		"path": "res://data/lab/experiments/br1/BR1_L0_2_ballistic_gravity_off_60hz_v1.tres",
		"experiment_id": "L0_2_BALLISTIC_ZERO_G",
		"duration_ticks": 60,
		"physics_hz": 60,
		"gravity_scale": 0.0,
		"independent_variables": ["/body_parameters/gravity_scale"],
		"gate_parameters": {
			"max_momentum_error_kg_m_s": 2.0e-6,
			"max_position_error_m": 2.0e-5,
			"max_velocity_error_m_s": 1.0e-6,
		},
		"comparison_profiles": [],
	},
	"BR1_L0_2_BALLISTIC_GRAVITY_ON_60HZ_V1": {
		"path": "res://data/lab/experiments/br1/BR1_L0_2_ballistic_gravity_on_60hz_v1.tres",
		"experiment_id": "L0_2_BALLISTIC_ZERO_G",
		"duration_ticks": 60,
		"physics_hz": 60,
		"gravity_scale": 1.0,
		"independent_variables": ["/body_parameters/gravity_scale"],
		"gate_parameters": {
			"max_momentum_error_kg_m_s": 0.04,
			"max_position_error_m": 0.0858375,
			"max_velocity_error_m_s": 0.02,
		},
		"comparison_profiles": [],
	},
	"BR1_L0_3_OBSERVER_AB_60HZ_V1": {
		"path": "res://data/lab/experiments/br1/BR1_L0_3_observer_ab_60hz_v1.tres",
		"experiment_id": "L0_3_OBSERVER_AB",
		"duration_ticks": 60,
		"physics_hz": 60,
		"gravity_scale": 0.0,
		"independent_variables": ["/observer_profile_id"],
		"gate_parameters": {
			"max_contact_profile_position_delta_m": 2.0e-5,
			"max_contact_profile_velocity_delta_m_s": 1.0e-6,
			"max_position_delta_m": 2.0e-5,
			"max_velocity_delta_m_s": 1.0e-6,
		},
		"comparison_profiles": [
			"minimal_state_v1",
			"full_state_v1",
			"full_contacts_v1",
		],
	},
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR1 L0 certification catalog ===")
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(CATALOG_PATH))
	var errors := _validate_catalog(parsed)
	if not errors.is_empty():
		printerr("  CATALOG ERRORS  ", errors)
	_check(
		errors.is_empty(),
		"the committed catalog is the exact seven-cell executable matrix")

	if parsed is Dictionary:
		var missing := (parsed as Dictionary).duplicate(true)
		(missing["cells"] as Array).remove_at(
			(missing["cells"] as Array).size() - 1)
		var missing_errors := _validate_catalog(missing)
		_check(
			_has_error(missing_errors, "CELL_ARRAY_COUNT_INVALID")
				and _has_error(missing_errors, "REQUIRED_CELL_MISSING"),
			"removing one cell is rejected closed")

		var duplicate := (parsed as Dictionary).duplicate(true)
		(duplicate["cells"] as Array)[1] = (
			(duplicate["cells"] as Array)[0] as Dictionary).duplicate(true)
		var duplicate_errors := _validate_catalog(duplicate)
		_check(
			_has_error(duplicate_errors, "DUPLICATE_CELL_ID")
				and _has_error(duplicate_errors, "DUPLICATE_RESOURCE_PATH")
				and _has_error(duplicate_errors, "REQUIRED_CELL_MISSING"),
			"duplicating a cell cannot masquerade as complete coverage")

		var incorrect := (parsed as Dictionary).duplicate(true)
		var first_incorrect: Dictionary = incorrect["cells"][0]
		first_incorrect["repeat_count"] = 1
		first_incorrect["replay_required"] = false
		(first_incorrect["seed_policy"] as Dictionary)["root_seed"] = 43
		var incorrect_errors := _validate_catalog(incorrect)
		_check(
			_has_error(incorrect_errors, "REPEAT_POLICY_INVALID")
				and _has_error(incorrect_errors, "REPLAY_POLICY_INVALID")
				and _has_error(incorrect_errors, "SEED_RESOURCE_MISMATCH"),
			"repeat, replay, and seed-policy drift are rejected")

	_finish()


func _validate_catalog(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary:
		errors.append("CATALOG_NOT_DICTIONARY")
		return errors
	var catalog: Dictionary = value
	_require_exact_keys(
		catalog,
		[
			"campaign_id",
			"campaign_version",
			"cell_count",
			"cells",
			"process_policy",
			"resource_patch_policy",
			"schema",
		],
		"CATALOG_KEYS_INVALID",
		errors)
	if String(catalog.get("schema", "")) \
			!= "sporespore.lab.br1_l0_certification_campaign.v1":
		errors.append("CATALOG_SCHEMA_INVALID")
	if String(catalog.get("campaign_id", "")) != "BR1_L0_CERTIFICATION_V1":
		errors.append("CAMPAIGN_ID_INVALID")
	if int(catalog.get("campaign_version", 0)) != 1:
		errors.append("CAMPAIGN_VERSION_INVALID")
	if int(catalog.get("cell_count", 0)) != EXPECTED_CELL_IDS.size():
		errors.append("DECLARED_CELL_COUNT_INVALID")
	if String(catalog.get("resource_patch_policy", "")) != "forbidden":
		errors.append("RESOURCE_PATCH_POLICY_INVALID")
	_validate_process_policy(catalog.get("process_policy"), errors)

	var cells_value: Variant = catalog.get("cells")
	if not cells_value is Array:
		errors.append("CELLS_NOT_ARRAY")
		return errors
	var cells: Array = cells_value
	if cells.size() != EXPECTED_CELL_IDS.size():
		errors.append("CELL_ARRAY_COUNT_INVALID")
	var seen_ids := {}
	var seen_paths := {}
	for index in cells.size():
		var cell_value: Variant = cells[index]
		if not cell_value is Dictionary:
			errors.append("CELL_NOT_DICTIONARY")
			continue
		var cell: Dictionary = cell_value
		_require_exact_keys(
			cell,
			[
				"cell_id",
				"observer",
				"repeat_count",
				"replay_required",
				"resource_path",
				"seed_policy",
			],
			"CELL_KEYS_INVALID",
			errors)
		var cell_id := String(cell.get("cell_id", ""))
		var resource_path := String(cell.get("resource_path", ""))
		if seen_ids.has(cell_id):
			errors.append("DUPLICATE_CELL_ID")
		seen_ids[cell_id] = true
		if seen_paths.has(resource_path):
			errors.append("DUPLICATE_RESOURCE_PATH")
		seen_paths[resource_path] = true
		if not EXPECTED.has(cell_id):
			errors.append("UNKNOWN_CELL_ID")
			continue
		var expected: Dictionary = EXPECTED[cell_id]
		if resource_path != String(expected["path"]):
			errors.append("RESOURCE_PATH_INVALID")
		if int(cell.get("repeat_count", 0)) != 2:
			errors.append("REPEAT_POLICY_INVALID")
		if cell.get("replay_required") != true:
			errors.append("REPLAY_POLICY_INVALID")
		_validate_seed_policy(cell.get("seed_policy"), errors)
		_validate_observer(
			cell.get("observer"),
			expected["comparison_profiles"],
			errors)
		_validate_resource(cell_id, cell, expected, errors)
	for required_id in EXPECTED_CELL_IDS:
		if not seen_ids.has(required_id):
			errors.append("REQUIRED_CELL_MISSING")
	return errors


func _validate_process_policy(
		value: Variant,
		errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("PROCESS_POLICY_NOT_DICTIONARY")
		return
	var policy: Dictionary = value
	_require_exact_keys(
		policy,
		[
			"fresh_process_per_replicate",
			"replicate_isolation",
			"required_replicates_per_cell",
		],
		"PROCESS_POLICY_KEYS_INVALID",
		errors)
	if policy.get("fresh_process_per_replicate") != true \
			or String(policy.get("replicate_isolation", "")) \
				!= "one_physics_run_per_os_process" \
			or int(policy.get("required_replicates_per_cell", 0)) != 2:
		errors.append("PROCESS_POLICY_INVALID")


func _validate_seed_policy(
		value: Variant,
		errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("SEED_POLICY_NOT_DICTIONARY")
		return
	var policy: Dictionary = value
	_require_exact_keys(
		policy,
		["kind", "root_seed"],
		"SEED_POLICY_KEYS_INVALID",
		errors)
	if String(policy.get("kind", "")) != "fixed_same_seed_fresh_process" \
			or int(policy.get("root_seed", -1)) != 42:
		errors.append("SEED_POLICY_INVALID")


func _validate_observer(
		value: Variant,
		expected_comparison_profiles: Array,
		errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("OBSERVER_POLICY_NOT_DICTIONARY")
		return
	var observer: Dictionary = value
	_require_exact_keys(
		observer,
		[
			"adapter_id",
			"comparison_profile_ids",
			"primary_profile_id",
		],
		"OBSERVER_POLICY_KEYS_INVALID",
		errors)
	if String(observer.get("adapter_id", "")) \
			!= "rigid_body_integrate_forces_v1":
		errors.append("OBSERVER_ADAPTER_INVALID")
	if String(observer.get("primary_profile_id", "")) \
			!= "full_contacts_v1":
		errors.append("PRIMARY_OBSERVER_INVALID")
	var profiles: Variant = observer.get("comparison_profile_ids")
	if not profiles is Array \
			or not _same_string_array(profiles, expected_comparison_profiles):
		errors.append("OBSERVER_COMPARISON_SET_INVALID")
		return
	for profile_id in profiles:
		if not ObserverProfileScript.has_profile(
				StringName(String(profile_id))) \
				or not ObserverProfileScript.is_executable(
					StringName(String(profile_id))):
			errors.append("OBSERVER_PROFILE_NOT_EXECUTABLE")


func _validate_resource(
		cell_id: String,
		cell: Dictionary,
		expected: Dictionary,
		errors: Array[String]) -> void:
	var path := String(cell.get("resource_path", ""))
	if not path.begins_with("res://data/lab/experiments/br1/") \
			or not path.ends_with("_v1.tres") \
			or not ResourceLoader.exists(path):
		errors.append("RESOURCE_MISSING_OR_UNVERSIONED")
		return
	var loaded: Resource = ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not loaded.has_method("to_value_dictionary"):
		errors.append("RESOURCE_TYPE_INVALID")
		return
	var digest := FileAccess.get_sha256(path)
	if digest.length() != 64:
		errors.append("RESOURCE_HASH_INVALID")
		return
	var compiled := SpecCompilerScript.compile(
		loaded,
		{},
		{},
		{
			"resource_path": path,
			"resource_sha256": "sha256:%s" % digest,
		})
	if not bool(compiled.get("ok", false)):
		errors.append("RESOURCE_COMPILE_FAILED")
		return
	var authored: Dictionary = loaded.call("to_value_dictionary")
	if String(authored.get("experiment_id", "")) \
			!= String(expected["experiment_id"]):
		errors.append("EXPERIMENT_ID_INVALID")
	if int(authored.get("duration_ticks", 0)) \
			!= int(expected["duration_ticks"]) \
			or int(authored.get("physics_ticks_per_second", 0)) \
				!= int(expected["physics_hz"]):
		errors.append("TIMING_CELL_INVALID")
	if int(authored.get("root_seed", -1)) \
			!= int((cell["seed_policy"] as Dictionary).get("root_seed", -2)):
		errors.append("SEED_RESOURCE_MISMATCH")
	if String(authored.get("observer_profile_id", "")) \
			!= String((cell["observer"] as Dictionary).get(
				"primary_profile_id", "")):
		errors.append("OBSERVER_RESOURCE_MISMATCH")
	var body: Variant = authored.get("body_parameters")
	if not body is Dictionary:
		errors.append("BODY_PARAMETERS_INVALID")
	else:
		var body_parameters: Dictionary = body
		if not _same_number(
				body_parameters.get("gravity_scale"),
				expected["gravity_scale"]):
			errors.append("GRAVITY_CELL_INVALID")
		if not _same_number(body_parameters.get("mass_kg"), 2.0) \
				or not _same_number(
					body_parameters.get("linear_damp_s1"), 0.0) \
				or not _same_number(
					body_parameters.get("angular_damp_s1"), 0.0):
			errors.append("COMMON_BODY_PARAMETERS_INVALID")
	var metadata: Variant = authored.get("metadata")
	if not metadata is Dictionary \
			or String((metadata as Dictionary).get(
				"campaign_cell_id", "")) != cell_id:
		errors.append("RESOURCE_CELL_ID_MISMATCH")
	if not _same_string_array(
			authored.get("independent_variables", []),
			expected["independent_variables"]):
		errors.append("INDEPENDENT_VARIABLE_INVALID")
	if not _same_numeric_dictionary(
			authored.get("gate_parameters"),
			expected["gate_parameters"]):
		errors.append("GATE_PARAMETERS_INVALID")
	_validate_discrete_tolerance_derivations(cell_id, authored, errors)


func _validate_discrete_tolerance_derivations(
		cell_id: String,
		authored: Dictionary,
		errors: Array[String]) -> void:
	var ticks := int(authored["duration_ticks"])
	var hz := int(authored["physics_ticks_per_second"])
	var duration_s := float(ticks) / float(hz)
	var gates: Dictionary = authored["gate_parameters"]
	if cell_id.begins_with("BR1_L0_1_FREE_FALL_"):
		if not _same_number(duration_s, 0.5):
			errors.append("FREE_FALL_DURATION_NOT_HELD_CONSTANT")
		var discrete_bound := (
			0.5 * 9.81 * duration_s * (1.0 / float(hz)) * 1.10)
		if not _same_number(
				gates.get("max_position_error_m"), discrete_bound):
			errors.append("FREE_FALL_DISCRETE_BOUND_INVALID")
	if cell_id == "BR1_L0_2_BALLISTIC_GRAVITY_ON_60HZ_V1":
		var position_bound := (
			0.5 * 9.81 * duration_s * (1.0 / float(hz)) * 1.05)
		if not _same_number(
				gates.get("max_position_error_m"), position_bound):
			errors.append("BALLISTIC_DISCRETE_BOUND_INVALID")
		var body: Dictionary = authored["body_parameters"]
		var momentum_bound := (
			float(body["mass_kg"])
			* float(gates["max_velocity_error_m_s"]))
		if not _same_number(
				gates.get("max_momentum_error_kg_m_s"), momentum_bound):
			errors.append("BALLISTIC_MOMENTUM_BOUND_INVALID")


static func _require_exact_keys(
		value: Dictionary,
		expected: Array,
		error_code: String,
		errors: Array[String]) -> void:
	var actual_keys: Array[String] = []
	for key in value:
		actual_keys.append(String(key))
	var expected_keys: Array[String] = []
	for key in expected:
		expected_keys.append(String(key))
	actual_keys.sort()
	expected_keys.sort()
	if actual_keys != expected_keys:
		errors.append(error_code)


static func _same_numeric_dictionary(
		actual_value: Variant,
		expected: Dictionary) -> bool:
	if not actual_value is Dictionary:
		return false
	var actual: Dictionary = actual_value
	if actual.size() != expected.size():
		return false
	for key in expected:
		if not actual.has(key) \
				or not _same_number(actual[key], expected[key]):
			return false
	return true


static func _same_number(a: Variant, b: Variant) -> bool:
	if typeof(a) not in [TYPE_INT, TYPE_FLOAT] \
			or typeof(b) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return absf(float(a) - float(b)) <= 1.0e-12


static func _same_string_array(a: Variant, b: Variant) -> bool:
	if not a is Array or not b is Array or a.size() != b.size():
		return false
	for index in a.size():
		if String(a[index]) != String(b[index]):
			return false
	return true


static func _has_error(errors: Array[String], code: String) -> bool:
	return errors.has(code)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
