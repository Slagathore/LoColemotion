class_name SpecCompiler
extends RefCounted

## Resolves authored spec < campaign patch < explicit CLI overrides. The
## compiler rejects invalid input; it never repairs a scientific parameter.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const ExpandedExperimentScript := preload("res://scripts/lab/expanded_experiment.gd")
const FiniteSanitizerScript := preload("res://scripts/lab/finite_sanitizer.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const ExecutionContractRegistryScript := preload(
	"res://scripts/lab/execution_contract_registry.gd")
const ObserverProfileScript := preload("res://scripts/lab/observer_profile.gd")
const RandomStreamCapabilityScript := preload(
	"res://scripts/lab/random_stream_capability.gd")

const CURRENT_SCHEMA := "sporespore.lab.experiment.v1"
const COMPILER_VERSION := "spec-compiler-v1"
const SCHEMA_SET := "sporespore.lab.schemas.v1"
const _PARAMETER_DICTIONARIES := [
	"body_parameters",
	"fixture_parameters",
	"controller_parameters",
	"gate_parameters",
]
const _KNOWN_FIELDS := [
	"schema",
	"experiment_id",
	"hypothesis_id",
	"fixture_id",
	"fixture_version",
	"controller_id",
	"observer_profile_id",
	"required_observer_channels",
	"duration_ticks",
	"warmup_ticks",
	"physics_ticks_per_second",
	"root_seed",
	"random_stream_ids",
	"body_parameters",
	"fixture_parameters",
	"controller_parameters",
	"gate_parameters",
	"allowed_scaffolds",
	"forbidden_scaffolds",
	"independent_variables",
	"metadata",
]
const _UNIT_SUFFIXES := [
	"_kg",
	"_m",
	"_m2",
	"_m_s",
	"_m_s2",
	"_rad",
	"_rad_s",
	"_rad_s2",
	"_n",
	"_nm",
	"_nm_s",
	"_n_s",
	"_pa",
	"_j",
	"_w",
	"_s",
	"_s1",
	"_hz",
	"_ratio",
	"_scale",
	"_coefficient",
	"_multiplier",
	"_ticks",
	"_count",
	"_index",
	"_version",
	"_cap",
	"_seed",
]
const _DIMENSIONLESS_NUMERIC_FIELDS := [
	"friction",
	"bounce",
	"roughness",
	"restitution",
]


static func compile(
		spec: Resource,
		campaign_patch: Dictionary = {},
		cli_overrides: Dictionary = {},
		source_identity: Dictionary = {}) -> Dictionary:
	var errors: Array[Dictionary] = []
	if spec == null or not spec.has_method("to_value_dictionary"):
		_add_error(
			errors,
			"SPEC_RESOURCE_INVALID",
			"",
			"Expected an ExperimentSpec-compatible Resource")
		return _failure(errors, source_identity)

	var authored: Dictionary = spec.to_value_dictionary()
	_validate_known_fields(authored, errors)
	var expanded := authored.duplicate(true)
	var applied_overrides: Array[Dictionary] = []
	_apply_patch(
		expanded,
		campaign_patch,
		"campaign_patch",
		errors,
		applied_overrides)
	_apply_patch(
		expanded,
		cli_overrides,
		"cli_override",
		errors,
		applied_overrides)

	_validate_expanded(expanded, errors)
	if errors.is_empty():
		# The execution registry validates against the fully resolved observer
		# identity, so attach it temporarily before the immutable expansion.
		if ObserverProfileScript.has_profile(
			StringName(String(expanded.get("observer_profile_id", "")))):
			expanded["observer_profile"] = ObserverProfileScript.resolve(
				StringName(String(expanded["observer_profile_id"])))
		errors.append_array(ExecutionContractRegistryScript.validate(expanded))
	_validate_source_identity(source_identity, errors)
	if not errors.is_empty():
		return _failure(errors, source_identity, applied_overrides)

	var observer_profile: Dictionary = expanded["observer_profile"]
	expanded["schema_set"] = SCHEMA_SET
	expanded["compiler_version"] = COMPILER_VERSION
	expanded["random_streams"] = _expand_random_streams(
		int(expanded["root_seed"]),
		expanded["random_stream_ids"])

	var compiled = ExpandedExperimentScript.new(expanded, applied_overrides)
	return {
		"ok": true,
		"experiment": compiled,
		"errors": [],
		"applied_overrides": compiled.applied_overrides(),
		"source_identity": FrozenValueScript.snapshot(source_identity),
	}


static func _failure(
		errors: Array[Dictionary],
		source_identity: Dictionary,
		applied_overrides: Array[Dictionary] = []) -> Dictionary:
	return {
		"ok": false,
		"experiment": null,
		"errors": FrozenValueScript.snapshot(errors),
		"applied_overrides": FrozenValueScript.snapshot(applied_overrides),
		"source_identity": FrozenValueScript.snapshot(source_identity),
	}


static func _validate_known_fields(
		authored: Dictionary,
		errors: Array[Dictionary]) -> void:
	for field in authored.keys():
		if not _KNOWN_FIELDS.has(String(field)):
			_add_error(
				errors,
				"UNKNOWN_FIELD",
				"/%s" % _escape_pointer_segment(String(field)),
				"Unknown experiment field")
	for required_field in _KNOWN_FIELDS:
		if not authored.has(required_field):
			_add_error(
				errors,
				"MISSING_FIELD",
				"/%s" % required_field,
				"ExperimentSpec did not expand a required field")


static func _apply_patch(
		target: Dictionary,
		patch: Dictionary,
		source: String,
		errors: Array[Dictionary],
		applied_overrides: Array[Dictionary]) -> void:
	if patch.is_empty():
		return
	var pointer_form := false
	for key in patch.keys():
		if String(key).begins_with("/"):
			pointer_form = true
			break
	if pointer_form:
		for key in patch.keys():
			var pointer := String(key)
			if not pointer.begins_with("/"):
				_add_error(
					errors,
					"MIXED_OVERRIDE_FORMAT",
					"",
					"Pointer and recursive patch keys cannot be mixed")
				continue
			_apply_pointer_override(
				target,
				pointer,
				patch[key],
				source,
				errors,
				applied_overrides)
		return
	_merge_dictionary(
		target,
		patch,
		"",
		source,
		errors,
		applied_overrides)


static func _merge_dictionary(
		target: Dictionary,
		patch: Dictionary,
		path: String,
		source: String,
		errors: Array[Dictionary],
		applied_overrides: Array[Dictionary]) -> void:
	var keys: Array = patch.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return String(a) < String(b))
	for raw_key in keys:
		var key := String(raw_key)
		var child_path := "%s/%s" % [path, _escape_pointer_segment(key)]
		if not target.has(key):
			_add_error(
				errors,
				"UNKNOWN_OVERRIDE_PATH",
				child_path,
				"Patch cannot introduce an undeclared field")
			continue
		var old_value: Variant = target[key]
		var new_value: Variant = patch[raw_key]
		if typeof(old_value) == TYPE_DICTIONARY \
				and typeof(new_value) == TYPE_DICTIONARY:
			_merge_dictionary(
				old_value,
				new_value,
				child_path,
				source,
				errors,
				applied_overrides)
		else:
			target[key] = new_value
			applied_overrides.append({
				"source": source,
				"path": child_path,
				"old_value": old_value,
				"new_value": new_value,
			})


static func _apply_pointer_override(
		target: Dictionary,
		pointer: String,
		new_value: Variant,
		source: String,
		errors: Array[Dictionary],
		applied_overrides: Array[Dictionary]) -> void:
	var segments := _parse_pointer(pointer)
	if segments.is_empty():
		_add_error(
			errors,
			"INVALID_OVERRIDE_PATH",
			pointer,
			"Root replacement is not allowed")
		return
	var cursor: Variant = target
	for index in range(segments.size() - 1):
		var segment: String = segments[index]
		if typeof(cursor) != TYPE_DICTIONARY or not cursor.has(segment):
			_add_error(
				errors,
				"UNKNOWN_OVERRIDE_PATH",
				pointer,
				"Override path does not exist")
			return
		cursor = cursor[segment]
	var leaf: String = segments[-1]
	if typeof(cursor) != TYPE_DICTIONARY or not cursor.has(leaf):
		_add_error(
			errors,
			"UNKNOWN_OVERRIDE_PATH",
			pointer,
			"Override path does not exist")
		return
	var old_value: Variant = cursor[leaf]
	cursor[leaf] = new_value
	applied_overrides.append({
		"source": source,
		"path": pointer,
		"old_value": old_value,
		"new_value": new_value,
	})


static func _validate_expanded(
		expanded: Dictionary,
		errors: Array[Dictionary]) -> void:
	var finite_report := FiniteSanitizerScript.inspect(expanded)
	if not bool(finite_report["ok"]):
		for failure in finite_report["failures"]:
			_add_error(
				errors,
				String(failure["code"]),
				String(failure["path"]),
				"Experiment contains an invalid value")

	if String(expanded.get("schema", "")) != CURRENT_SCHEMA:
		_add_error(
			errors,
			"UNKNOWN_SCHEMA_VERSION",
			"/schema",
			"Expected %s" % CURRENT_SCHEMA)

	for field in [
		"experiment_id",
		"hypothesis_id",
		"fixture_id",
		"controller_id",
	]:
		_validate_stable_id(
			String(expanded.get(field, "")),
			"/%s" % field,
			errors)

	if int(expanded.get("fixture_version", 0)) < 1:
		_add_error(
			errors,
			"DOMAIN_ERROR",
			"/fixture_version",
			"Fixture version must be at least one")
	if int(expanded.get("duration_ticks", 0)) < 1:
		_add_error(
			errors,
			"DOMAIN_ERROR",
			"/duration_ticks",
			"Duration must be at least one tick")
	var duration_ticks := int(expanded.get("duration_ticks", 0))
	var warmup_ticks := int(expanded.get("warmup_ticks", -1))
	if warmup_ticks < 0 or warmup_ticks > duration_ticks:
		_add_error(
			errors,
			"DOMAIN_ERROR",
			"/warmup_ticks",
			"Warmup ticks must be between zero and duration ticks")
	var ticks_per_second := int(expanded.get("physics_ticks_per_second", 0))
	if ticks_per_second < 1 or ticks_per_second > 1000:
		_add_error(
			errors,
			"DOMAIN_ERROR",
			"/physics_ticks_per_second",
			"Physics tick rate must be in [1, 1000]")

	var observer_id := StringName(
		String(expanded.get("observer_profile_id", "")))
	if not ObserverProfileScript.has_profile(observer_id):
		_add_error(
			errors,
			"UNKNOWN_OBSERVER_PROFILE",
			"/observer_profile_id",
			"Observer profile ID must be an exact registered version")
	else:
		if not ObserverProfileScript.is_executable(observer_id):
			var unsupported: Array = ObserverProfileScript.resolve(
				observer_id)["unsupported_channels"]
			_add_error(
				errors,
				"OBSERVER_PROFILE_NOT_IMPLEMENTED",
				"/observer_profile_id",
				"Observer profile advertises channels with no certified provider: %s"
					% ", ".join(unsupported))
		for channel in expanded.get("required_observer_channels", []):
			if not ObserverProfileScript.captures(
					observer_id,
					StringName(String(channel))):
				_add_error(
					errors,
					"OBSERVER_CHANNEL_MISSING",
					"/required_observer_channels",
					"Observer %s does not capture %s"
						% [String(observer_id), String(channel)])

	_validate_id_array(
		expanded.get("random_stream_ids", []),
		"/random_stream_ids",
		true,
		errors)
	_validate_id_array(
		expanded.get("allowed_scaffolds", []),
		"/allowed_scaffolds",
		true,
		errors)
	_validate_id_array(
		expanded.get("forbidden_scaffolds", []),
		"/forbidden_scaffolds",
		true,
		errors)
	for scaffold in expanded.get("allowed_scaffolds", []):
		if expanded.get("forbidden_scaffolds", []).has(scaffold):
			_add_error(
				errors,
				"SCAFFOLD_CONFLICT",
				"/allowed_scaffolds",
				"A scaffold cannot be both allowed and forbidden")
	if expanded.get("independent_variables", []).size() > 1:
		_add_error(
			errors,
			"TOO_MANY_INDEPENDENT_VARIABLES",
			"/independent_variables",
			"Ordinary experiments declare at most one independent variable")
	for index in range(expanded.get("independent_variables", []).size()):
		var independent_path := String(
			expanded.get("independent_variables", [])[index])
		if (
			not independent_path.begins_with("/")
			or not _pointer_exists(expanded, independent_path)
		):
			_add_error(
				errors,
				"INVALID_INDEPENDENT_VARIABLE_PATH",
				"/independent_variables/%d" % index,
				"Independent variable must name an existing JSON-pointer path")

	for dictionary_name in _PARAMETER_DICTIONARIES:
		var parameters: Variant = expanded.get(dictionary_name, null)
		if typeof(parameters) != TYPE_DICTIONARY:
			_add_error(
				errors,
				"TYPE_ERROR",
				"/%s" % dictionary_name,
				"Scientific parameter group must be a Dictionary")
			continue
		_validate_parameter_units(
			parameters,
			"/%s" % dictionary_name,
			errors)
	_validate_actuator_domains(expanded, "", errors)


static func _validate_parameter_units(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	var dictionary: Dictionary = value
	for raw_key in dictionary.keys():
		var key := String(raw_key)
		var child: Variant = dictionary[raw_key]
		var child_path := "%s/%s" % [path, _escape_pointer_segment(key)]
		if typeof(child) == TYPE_DICTIONARY:
			_validate_parameter_units(child, child_path, errors)
		elif _is_numeric_measurement(child) and not _has_declared_unit(key):
			_add_error(
				errors,
				"MISSING_UNIT",
				child_path,
				"Numeric scientific parameters require a unit-bearing field name")


static func _validate_actuator_domains(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	var dictionary: Dictionary = value
	for raw_key in dictionary.keys():
		var key := String(raw_key)
		var child: Variant = dictionary[raw_key]
		var child_path := "%s/%s" % [path, _escape_pointer_segment(key)]
		if typeof(child) == TYPE_DICTIONARY:
			_validate_actuator_domains(child, child_path, errors)
			continue
		if typeof(child) not in [TYPE_INT, TYPE_FLOAT]:
			continue
		var number := float(child)
		match key:
			"max_isometric_torque_nm", "max_torque_rate_nm_s", \
			"max_positive_power_w", "max_absorption_power_w", \
			"structural_torque_limit_nm", "tear_dwell_s":
				if number < 0.0:
					_add_error(
						errors,
						"ACTUATOR_DOMAIN_ERROR",
						child_path,
						"%s must be non-negative" % key)
			"no_load_speed_rad_s", "activation_time_s", \
			"deactivation_time_s":
				if number <= 1.0e-8:
					_add_error(
						errors,
						"ACTUATOR_DOMAIN_ERROR",
						child_path,
						"%s must be greater than the runtime epsilon" % key)
			"max_eccentric_multiplier":
				if number < 1.0:
					_add_error(
						errors,
						"ACTUATOR_DOMAIN_ERROR",
						child_path,
						"max_eccentric_multiplier must be at least one")


static func _expand_random_streams(
		root_seed: int,
		stream_ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stream_id in stream_ids:
		var id := StringName(String(stream_id))
		var derived_seed := RandomStreamCapabilityScript.derive_seed(
			root_seed,
			id)
		result.append({
			"stream_id": String(id),
			"seed": derived_seed,
			"seed_sha256": CanonicalJsonScript.sha256({
				"seed": derived_seed,
				"stream_id": String(id),
			}),
		})
	return result


static func _validate_stable_id(
		value: String,
		path: String,
		errors: Array[Dictionary]) -> void:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z][A-Za-z0-9_.-]*$")
	if regex.search(value) == null:
		_add_error(
			errors,
			"INVALID_STABLE_ID",
			path,
			"Stable IDs must start with a letter and contain only letters, numbers, _, ., or -")


static func _validate_id_array(
		values: Variant,
		path: String,
		require_unique: bool,
		errors: Array[Dictionary]) -> void:
	if typeof(values) != TYPE_ARRAY:
		_add_error(errors, "TYPE_ERROR", path, "Expected an Array")
		return
	var seen: Dictionary = {}
	for index in range(values.size()):
		var value := String(values[index])
		_validate_stable_id(value, "%s/%d" % [path, index], errors)
		if require_unique and seen.has(value):
			_add_error(
				errors,
				"DUPLICATE_ID",
				"%s/%d" % [path, index],
				"IDs in this list must be unique")
		seen[value] = true


static func _validate_source_identity(
		source_identity: Dictionary,
		errors: Array[Dictionary]) -> void:
	for key in source_identity.keys():
		if String(key) not in [
			"resource_path",
			"resource_sha256",
		]:
			_add_error(
				errors,
				"UNKNOWN_SOURCE_IDENTITY_FIELD",
				"/source_identity/%s" % _escape_pointer_segment(String(key)),
				"Unknown source identity field")
	if source_identity.has("resource_sha256"):
		var digest := String(source_identity["resource_sha256"])
		if not _is_sha256(digest):
			_add_error(
				errors,
				"INVALID_SHA256",
				"/source_identity/resource_sha256",
				"Expected sha256:<64 lowercase hexadecimal digits>")


static func _is_numeric_measurement(value: Variant) -> bool:
	return typeof(value) in [
		TYPE_INT,
		TYPE_FLOAT,
		TYPE_VECTOR2,
		TYPE_VECTOR3,
		TYPE_VECTOR4,
		TYPE_QUATERNION,
		TYPE_BASIS,
		TYPE_TRANSFORM3D,
	]


static func _has_declared_unit(field: String) -> bool:
	if _DIMENSIONLESS_NUMERIC_FIELDS.has(field):
		return true
	for suffix in _UNIT_SUFFIXES:
		if field.ends_with(suffix):
			return true
	return false


static func _parse_pointer(pointer: String) -> Array[String]:
	if not pointer.begins_with("/"):
		return []
	var result: Array[String] = []
	for encoded_segment in pointer.substr(1).split("/", true):
		result.append(
			String(encoded_segment).replace("~1", "/").replace("~0", "~"))
	return result


static func _pointer_exists(root: Dictionary, pointer: String) -> bool:
	var segments := _parse_pointer(pointer)
	if segments.is_empty():
		return false
	var cursor: Variant = root
	for segment in segments:
		if typeof(cursor) != TYPE_DICTIONARY or not cursor.has(segment):
			return false
		cursor = cursor[segment]
	return true


static func _is_sha256(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^sha256:[0-9a-f]{64}$")
	return regex.search(value) != null


static func _escape_pointer_segment(segment: String) -> String:
	return segment.replace("~", "~0").replace("/", "~1")


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({
		"code": code,
		"path": path,
		"message": message,
	})
