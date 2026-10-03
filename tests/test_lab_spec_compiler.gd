extends SceneTree

const ExperimentSpecScript := preload("res://scripts/lab/experiment_spec.gd")
const RandomStreamCapabilityScript := preload(
	"res://scripts/lab/random_stream_capability.gd")
const SpecCompilerScript := preload("res://scripts/lab/spec_compiler.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab experiment-spec compiler tests ===")
	_test_valid_compile_and_precedence()
	_test_canonical_hash_ignores_dictionary_insertion_order()
	_test_configuration_errors_are_rejected()
	_test_source_identity_is_validated_but_not_hashed_into_science()
	_test_shipped_l0_resources_compile()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _valid_spec():
	var spec = ExperimentSpecScript.new()
	spec.experiment_id = &"L0_0_STATIONARY_GRAVITY_OFF"
	spec.hypothesis_id = &"H-L0-000"
	spec.fixture_id = &"stationary_body_v1"
	spec.controller_id = &"none"
	spec.observer_profile_id = &"full_contacts_v1"
	var required_channels: Array[StringName] = [
		&"body_transform",
		&"linear_velocity",
	]
	spec.required_observer_channels = required_channels
	spec.duration_ticks = 60
	spec.warmup_ticks = 0
	spec.physics_ticks_per_second = 60
	spec.root_seed = 7
	spec.body_parameters = {
		"angular_damp_s1": 0.0,
		"mass_kg": 2.0,
		"initial_position_m": Vector3(0.0, 1.0, 0.0),
		"initial_velocity_m_s": Vector3.ZERO,
		"gravity_scale": 0.0,
		"linear_damp_s1": 0.0,
	}
	spec.fixture_parameters = {
		"contact_cap": 32,
	}
	spec.controller_parameters = {}
	spec.gate_parameters = {
		"external_work_j": 0.0,
		"max_position_error_m": 1.0e-6,
		"max_velocity_error_m_s": 1.0e-6,
		"total_contact_count": 0,
	}
	return spec


func _test_valid_compile_and_precedence() -> void:
	print("- resolves authored < campaign < explicit override")
	var spec = _valid_spec()
	var result := SpecCompilerScript.compile(
		spec,
		{"body_parameters": {"mass_kg": 3.0}},
		{"/body_parameters/mass_kg": 4.0, "/root_seed": 42})
	_check(bool(result["ok"]), "valid fully-unitized L0 spec compiles")
	if not bool(result["ok"]):
		printerr("    errors: ", result["errors"])
		return
	var expanded = result["experiment"]
	var value: Dictionary = expanded.value()
	_check(
		is_equal_approx(float(value["body_parameters"]["mass_kg"]), 4.0),
		"explicit override wins over campaign patch")
	_check(int(value["root_seed"]) == 42, "pointer override updates root seed")
	_check(
		value.has("observer_profile")
			and value["observer_profile"]["profile_id"] == "full_contacts_v1",
		"exact observer profile is expanded and sealed")
	_check(
		value.has("random_streams")
			and value["random_streams"].size()
				== spec.random_stream_ids.size(),
		"named stream seeds are fully expanded")
	var first_stream: Dictionary = value["random_streams"][0]
	var capability = RandomStreamCapabilityScript.create(
		StringName(first_stream["stream_id"]),
		int(first_stream["seed"]))
	_check(
		capability.seed_sha256 == first_stream["seed_sha256"],
		"compiled stream provenance matches the draw capability")
	_check(expanded.assert_integrity(), "compiled experiment is immutable and self-consistent")
	_check(
		result["applied_overrides"].size() == 3,
		"every campaign/CLI replacement is retained in provenance order")


func _test_canonical_hash_ignores_dictionary_insertion_order() -> void:
	print("- canonical hash depends on values, not dictionary insertion")
	var first = _valid_spec()
	first.body_parameters = {}
	first.body_parameters["mass_kg"] = 2.0
	first.body_parameters["gravity_scale"] = 0.0
	first.body_parameters["initial_position_m"] = Vector3(0.0, 1.0, 0.0)
	first.body_parameters["initial_velocity_m_s"] = Vector3.ZERO
	first.body_parameters["linear_damp_s1"] = 0.0
	first.body_parameters["angular_damp_s1"] = 0.0
	var second = _valid_spec()
	second.body_parameters = {}
	second.body_parameters["angular_damp_s1"] = 0.0
	second.body_parameters["linear_damp_s1"] = 0.0
	second.body_parameters["initial_velocity_m_s"] = Vector3.ZERO
	second.body_parameters["initial_position_m"] = Vector3(0.0, 1.0, 0.0)
	second.body_parameters["gravity_scale"] = 0.0
	second.body_parameters["mass_kg"] = 2.0
	var first_result := SpecCompilerScript.compile(first)
	var second_result := SpecCompilerScript.compile(second)
	_check(bool(first_result["ok"]) and bool(second_result["ok"]),
		"both insertion-order variants compile")
	if bool(first_result["ok"]) and bool(second_result["ok"]):
		_check(
			first_result["experiment"].expanded_spec_sha256()
				== second_result["experiment"].expanded_spec_sha256(),
			"expanded-spec digest is insertion-order independent")


func _test_configuration_errors_are_rejected() -> void:
	print("- rejects schema, finite, unit, observer, and actuator violations")
	var bad_schema = _valid_spec()
	bad_schema.schema = "sporespore.lab.experiment.v999"
	_check(
		_has_error(SpecCompilerScript.compile(bad_schema), "UNKNOWN_SCHEMA_VERSION"),
		"unknown schema version is rejected")

	var bad_finite = _valid_spec()
	bad_finite.body_parameters["mass_kg"] = INF
	_check(
		_has_error(SpecCompilerScript.compile(bad_finite), "NONFINITE_FLOAT"),
		"non-finite scientific value is rejected before hashing")

	var bad_unit = _valid_spec()
	bad_unit.fixture_parameters["gravity"] = -9.81
	_check(
		_has_error(SpecCompilerScript.compile(bad_unit), "MISSING_UNIT"),
		"unitless scientific value is rejected")

	var bad_observer = _valid_spec()
	bad_observer.observer_profile_id = &"minimal_state_v1"
	var contact_channels: Array[StringName] = [&"contact_impulses"]
	bad_observer.required_observer_channels = contact_channels
	_check(
		_has_error(SpecCompilerScript.compile(bad_observer), "OBSERVER_CHANNEL_MISSING"),
		"gate-required channel must exist in the observer profile")

	var aspirational_observer = _valid_spec()
	aspirational_observer.observer_profile_id = &"full_energy_v1"
	_check(
		_has_error(
			SpecCompilerScript.compile(aspirational_observer),
			"OBSERVER_PROFILE_NOT_IMPLEMENTED"),
		"profiles with no certified runtime provider are not executable")

	var bad_actuator = _valid_spec()
	bad_actuator.controller_parameters = {
		"actuator": {
			"no_load_speed_rad_s": 0.0,
			"max_eccentric_multiplier": 0.75,
		},
	}
	var actuator_result := SpecCompilerScript.compile(bad_actuator)
	_check(
		_count_error(actuator_result, "ACTUATOR_DOMAIN_ERROR") == 2,
		"actuator domain table rejects zero speed and sub-unity eccentric capacity")

	var too_many_factors = _valid_spec()
	var factor_paths: Array[String] = [
		"/body_parameters/mass_kg",
		"/fixture_parameters/contact_cap",
	]
	too_many_factors.independent_variables = factor_paths
	_check(
		_has_error(
			SpecCompilerScript.compile(too_many_factors),
			"TOO_MANY_INDEPENDENT_VARIABLES"),
		"ordinary experiment cannot hide a second independent variable")

	var unknown_factor = _valid_spec()
	var unknown_factor_paths: Array[String] = [
		"/body_parameters/not_authored_kg",
	]
	unknown_factor.independent_variables = unknown_factor_paths
	_check(
		_has_error(
			SpecCompilerScript.compile(unknown_factor),
			"INVALID_INDEPENDENT_VARIABLE_PATH"),
		"declared independent variable must resolve to an authored path")

	var unknown_override := SpecCompilerScript.compile(
		_valid_spec(),
		{},
		{"/body_parameters/undeclared_force_n": 20.0})
	_check(
		_has_error(unknown_override, "UNKNOWN_OVERRIDE_PATH"),
		"override cannot introduce an undeclared parameter")

	var wrong_fixture = _valid_spec()
	wrong_fixture.fixture_id = &"ballistic_body_v1"
	_check(
		_has_error(
			SpecCompilerScript.compile(wrong_fixture),
			"EXPERIMENT_FIXTURE_INCOMPATIBLE"),
		"experiment cannot compile against a physically different fixture")

	var hidden_parameter = _valid_spec()
	hidden_parameter.body_parameters["decorative_force_n"] = 10.0
	_check(
		_has_error(
			SpecCompilerScript.compile(hidden_parameter),
			"PARAMETER_HAS_NO_EXECUTION_CONSUMER"),
		"authored parameters with no runtime consumer are rejected")

	var missing_parameter = _valid_spec()
	missing_parameter.body_parameters.erase("linear_damp_s1")
	_check(
		_has_error(
			SpecCompilerScript.compile(missing_parameter),
			"REQUIRED_EXECUTION_PARAMETER_MISSING"),
		"runner-required physical parameters cannot fall back invisibly")

	var cap_too_small = _valid_spec()
	cap_too_small.fixture_parameters["contact_cap"] = 0
	_check(
		_has_error(
			SpecCompilerScript.compile(cap_too_small),
			"OBSERVER_CONTACT_CAP_EXCEEDS_FIXTURE"),
		"fixture contact capacity must cover the selected observer")


func _test_source_identity_is_validated_but_not_hashed_into_science() -> void:
	print("- keeps resource identity adjacent to, not inside, scientific hash")
	var spec = _valid_spec()
	var source_a := {
		"resource_path": "res://data/lab/experiments/a.tres",
		"resource_sha256": "sha256:%s" % "a".repeat(64),
	}
	var source_b := {
		"resource_path": "res://data/lab/experiments/b.tres",
		"resource_sha256": "sha256:%s" % "b".repeat(64),
	}
	var result_a := SpecCompilerScript.compile(spec, {}, {}, source_a)
	var result_b := SpecCompilerScript.compile(spec, {}, {}, source_b)
	_check(bool(result_a["ok"]) and bool(result_b["ok"]),
		"valid resource identities compile")
	if bool(result_a["ok"]) and bool(result_b["ok"]):
		_check(
			result_a["experiment"].expanded_spec_sha256()
				== result_b["experiment"].expanded_spec_sha256(),
			"resource location does not rewrite scientific expanded-spec identity")
		_check(
			result_a["source_identity"]["resource_path"]
				!= result_b["source_identity"]["resource_path"],
			"authored resource identity remains available for the manifest")
	var invalid_source := SpecCompilerScript.compile(
		spec,
		{},
		{},
		{"resource_sha256": "not-a-digest"})
	_check(
		_has_error(invalid_source, "INVALID_SHA256"),
		"malformed authored-resource digest is rejected")


func _test_shipped_l0_resources_compile() -> void:
	print("- compiles every shipped L0 authored resource")
	var paths := [
		"res://data/lab/experiments/L0_0_stationary_gravity_off_v1.tres",
		"res://data/lab/experiments/L0_1_free_fall_v1.tres",
		"res://data/lab/experiments/L0_2_ballistic_zero_g_v1.tres",
		"res://data/lab/experiments/L0_3_observer_ab_v1.tres",
		"res://data/lab/experiments/L0_4_trace_playback_v1.tres",
	]
	for path in paths:
		var loaded := ResourceLoader.load(path)
		var result := SpecCompilerScript.compile(loaded)
		_check(
			loaded != null and bool(result["ok"]),
			"%s loads and compiles" % path.get_file())
		if not bool(result["ok"]):
			printerr("    errors: ", result["errors"])


func _has_error(result: Dictionary, code: String) -> bool:
	return _count_error(result, code) > 0


func _count_error(result: Dictionary, code: String) -> int:
	var count := 0
	for error in result["errors"]:
		if String(error["code"]) == code:
			count += 1
	return count
