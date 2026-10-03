class_name LabGroundQualifier
extends RefCounted

## BR3A pure contact-to-ground qualification contract.
##
## This module answers one deliberately narrow question: does one canonical
## contact record qualify as an allowed external support candidate? It does
## not decide that the contact is load-bearing. LabContactSupportState owns
## persistence, load, separation, and phase transitions.
##
## Height, target position, target arrival, and other geometry hints are never
## read here. A contact only qualifies when the observer/canonicalizer proves
## all of the following:
##
## - a present, canonical creature-versus-environment record;
## - an explicit negative same-creature classification;
## - an allowed semantic role, stable surface layer, and stable surface tag;
## - finite world point and finite available normal; and
## - a normal inside the preregistered upward support cone.
##
## Configuration and results cross a FrozenValue boundary, so later controller
## code cannot rewrite the evidence that caused a support decision.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const CONFIG_SCHEMA_VERSION := "ground_qualifier_config_v1"
const RESULT_SCHEMA_VERSION := "ground_qualification_v1"
const EXTERNAL_OWNERSHIP := "creature_environment"
const NORMAL_LENGTH_EPSILON := 1.0e-8
const REQUIRED_CONTACT_SCHEMA_VERSION := "contact_patch_v1"
const VALID_SAMPLE_PHASES := ["integrate_callback", "post_step"]


static func build_config(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var allowed_roles := _stable_string_allowlist(
		configuration.get("allowed_roles"),
		"/allowed_roles",
		errors)
	var allowed_layers := _stable_layer_allowlist(
		configuration.get("allowed_surface_layers"),
		"/allowed_surface_layers",
		errors)
	var allowed_tags := _stable_string_allowlist(
		configuration.get("allowed_surface_tags"),
		"/allowed_surface_tags",
		errors)

	var up_world := Vector3.ZERO
	var up_value: Variant = configuration.get("up_world")
	if up_value is Vector3 \
			and (up_value as Vector3).is_finite() \
			and (up_value as Vector3).length_squared() > NORMAL_LENGTH_EPSILON:
		up_world = (up_value as Vector3).normalized()
	else:
		_add_error(
			errors,
			"UP_VECTOR_INVALID",
			"/up_world",
			"up_world must be a finite nonzero Vector3")

	var minimum_up_dot := float(configuration.get("minimum_up_dot", NAN))
	if not is_finite(minimum_up_dot) \
			or minimum_up_dot < 0.0 or minimum_up_dot > 1.0:
		_add_error(
			errors,
			"MINIMUM_UP_DOT_INVALID",
			"/minimum_up_dot",
			"minimum_up_dot must be finite and inside [0, 1]")

	if not errors.is_empty():
		return FrozenValueScript.snapshot({
			"ok": false,
			"errors": errors,
			"config": null,
		})

	var config := {
		"schema_version": CONFIG_SCHEMA_VERSION,
		"allowed_roles": allowed_roles,
		"allowed_surface_layers": allowed_layers,
		"allowed_surface_tags": allowed_tags,
		"up_world": up_world,
		"minimum_up_dot": minimum_up_dot,
		"ownership_required": EXTERNAL_OWNERSHIP,
		"same_creature_flag_required": true,
		"geometry_only_support_forbidden": true,
	}
	config["config_digest_sha256"] = CanonicalJsonScript.sha256(config)
	return FrozenValueScript.snapshot({
		"ok": true,
		"errors": [],
		"config": config,
	})


static func qualify(contact: Dictionary, config: Dictionary) -> Dictionary:
	var validation_reasons: Array[String] = []
	var rejection_reasons: Array[String] = []
	var config_valid := _config_valid(config)
	if not config_valid:
		validation_reasons.append("GROUND_QUALIFIER_CONFIG_INVALID")

	var identity := _contact_identity(contact, validation_reasons)
	if String(contact.get("schema_version", "")) \
			!= REQUIRED_CONTACT_SCHEMA_VERSION:
		validation_reasons.append("CONTACT_PATCH_SCHEMA_UNSUPPORTED")
	var contact_present := _required_bool(
		contact, "contact_present", validation_reasons)
	var canonical_pair_side := _required_bool(
		contact, "canonical_pair_side", validation_reasons)
	var same_creature_contact := _required_bool(
		contact, "same_creature_contact", validation_reasons)

	var ownership := _stable_string_field(
		contact, "ownership", validation_reasons)
	var role := _stable_string_field(contact, "role", validation_reasons)
	var surface_tag := _stable_string_field(
		contact, "surface_tag", validation_reasons)
	var surface_layer := _stable_layer_field(
		contact, "surface_layer", validation_reasons)

	var point_world := Vector3.ZERO
	var point_valid := false
	var point_value: Variant = contact.get("point_world")
	if point_value is Vector3 and (point_value as Vector3).is_finite():
		point_world = point_value as Vector3
		point_valid = true
	else:
		validation_reasons.append("CONTACT_POINT_INVALID")

	var normal_available := _required_bool(
		contact, "normal_available", validation_reasons)
	var normal_world := Vector3.ZERO
	var normal_valid := false
	if normal_available:
		var normal_value: Variant = contact.get("normal_world")
		if normal_value is Vector3 \
				and (normal_value as Vector3).is_finite() \
				and (normal_value as Vector3).length_squared() \
					> NORMAL_LENGTH_EPSILON:
			normal_world = (normal_value as Vector3).normalized()
			normal_valid = true
		else:
			validation_reasons.append("CONTACT_NORMAL_INVALID")
	else:
		rejection_reasons.append("CONTACT_NORMAL_UNAVAILABLE")

	var canonical_external := (
		ownership == EXTERNAL_OWNERSHIP and canonical_pair_side)
	var explicitly_not_self := not same_creature_contact
	var role_allowed := config_valid \
		and (config["allowed_roles"] as Array).has(role)
	var layer_allowed := config_valid \
		and (config["allowed_surface_layers"] as Array).has(surface_layer)
	var tag_allowed := config_valid \
		and (config["allowed_surface_tags"] as Array).has(surface_tag)
	var up_dot: Variant = null
	var upward_normal := false
	if config_valid and normal_valid:
		up_dot = normal_world.dot(config["up_world"] as Vector3)
		upward_normal = float(up_dot) >= float(config["minimum_up_dot"])

	if not contact_present:
		rejection_reasons.append("CONTACT_NOT_PRESENT")
	if ownership != EXTERNAL_OWNERSHIP:
		rejection_reasons.append("CONTACT_OWNERSHIP_NOT_EXTERNAL")
	if not canonical_pair_side:
		rejection_reasons.append("CONTACT_NOT_CANONICAL_PAIR_SIDE")
	if same_creature_contact:
		rejection_reasons.append("SAME_CREATURE_CONTACT_EXCLUDED")
	if not role_allowed:
		rejection_reasons.append("CONTACT_ROLE_NOT_ALLOWED")
	if not layer_allowed:
		rejection_reasons.append("CONTACT_SURFACE_LAYER_NOT_ALLOWED")
	if not tag_allowed:
		rejection_reasons.append("CONTACT_SURFACE_TAG_NOT_ALLOWED")
	if normal_valid and not upward_normal:
		rejection_reasons.append("CONTACT_NORMAL_OUTSIDE_SUPPORT_CONE")

	var observation_valid := validation_reasons.is_empty()
	var qualifies_as_ground := observation_valid \
		and rejection_reasons.is_empty() \
		and contact_present \
		and canonical_external \
		and explicitly_not_self \
		and role_allowed and layer_allowed and tag_allowed \
		and point_valid and normal_valid and upward_normal

	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"qualifier_config_schema_version": String(
			config.get("schema_version", "")),
		"physics_step_id": identity["physics_step_id"],
		"capture_epoch": identity["capture_epoch"],
		"sample_phase": identity["sample_phase"],
		"contact_patch_id": String(contact.get("contact_patch_id", "")),
		"config_digest_sha256": String(
			config.get("config_digest_sha256", "")),
		"input_provenance": identity["provenance"],
		"observation_valid": observation_valid,
		"qualifies_as_ground": qualifies_as_ground,
		"validation_reasons": validation_reasons,
		"rejection_reasons": rejection_reasons,
		"point_world": point_world if point_valid else null,
		"normal_world": normal_world if normal_valid else null,
		"up_dot": up_dot,
		"role": role,
		"surface_layer": surface_layer,
		"surface_tag": surface_tag,
		"criteria": {
			"contact_present": contact_present,
			"canonical_external_ownership": canonical_external,
			"explicitly_not_same_creature": explicitly_not_self,
			"role_allowed": role_allowed,
			"surface_layer_allowed": layer_allowed,
			"surface_tag_allowed": tag_allowed,
			"point_finite": point_valid,
			"normal_finite_and_available": normal_valid,
			"normal_inside_upward_cone": upward_normal,
		},
		"geometry_fields_consulted": [],
	})


static func _config_valid(config: Dictionary) -> bool:
	var structurally_valid: bool = String(config.get("schema_version", "")) \
			== CONFIG_SCHEMA_VERSION \
		and config.get("allowed_roles") is Array \
		and not (config.get("allowed_roles") as Array).is_empty() \
		and config.get("allowed_surface_layers") is Array \
		and not (config.get("allowed_surface_layers") as Array).is_empty() \
		and config.get("allowed_surface_tags") is Array \
		and not (config.get("allowed_surface_tags") as Array).is_empty() \
			and config.get("up_world") is Vector3 \
			and (config.get("up_world") as Vector3).is_finite() \
			and absf((config.get("up_world") as Vector3).length() - 1.0) \
				<= 1.0e-6 \
			and is_finite(float(config.get("minimum_up_dot", NAN))) \
			and float(config.get("minimum_up_dot", -1.0)) >= 0.0 \
			and float(config.get("minimum_up_dot", 2.0)) <= 1.0 \
			and String(config.get("ownership_required", "")) \
				== EXTERNAL_OWNERSHIP \
			and config.get("same_creature_flag_required") == true \
			and config.get("geometry_only_support_forbidden") == true
	if not structurally_valid:
		return false
	var digest := String(config.get("config_digest_sha256", ""))
	var payload := config.duplicate(true)
	payload.erase("config_digest_sha256")
	return _is_sha256_digest(digest) \
		and digest == CanonicalJsonScript.sha256(payload)


static func _contact_identity(
		contact: Dictionary,
		validation_reasons: Array[String]) -> Dictionary:
	var step_valid := typeof(contact.get("physics_step_id")) == TYPE_INT \
		and int(contact.get("physics_step_id")) >= 0
	var epoch_valid := typeof(contact.get("capture_epoch")) == TYPE_INT \
		and int(contact.get("capture_epoch")) >= 0
	var phase_value: Variant = contact.get("sample_phase")
	var phase_valid := (phase_value is String or phase_value is StringName) \
		and String(phase_value) in VALID_SAMPLE_PHASES
	var provenance := {}
	for field in [
		"run_id",
		"capture_stream_id",
		"observer_profile_id",
		"observer_adapter_id",
	]:
		var field_value: Variant = contact.get(field)
		if not (field_value is String or field_value is StringName) \
				or String(field_value).is_empty():
			validation_reasons.append(
				"CONTACT_%s_INVALID" % field.to_upper())
		else:
			provenance[field] = String(field_value)
	var patch_id := String(contact.get("contact_patch_id", ""))
	if not _is_sha256_digest(patch_id):
		validation_reasons.append("CONTACT_PATCH_ID_INVALID")
	if not step_valid:
		validation_reasons.append("CONTACT_PHYSICS_STEP_INVALID")
	if not epoch_valid:
		validation_reasons.append("CONTACT_CAPTURE_EPOCH_INVALID")
	if not phase_valid:
		validation_reasons.append("CONTACT_SAMPLE_PHASE_INVALID")
	return {
		"physics_step_id": int(contact.get("physics_step_id", -1)),
		"capture_epoch": int(contact.get("capture_epoch", -1)),
		"sample_phase": String(contact.get("sample_phase", "")),
		"provenance": provenance,
	}


static func _is_sha256_digest(value: String) -> bool:
	if value.length() != 71 or not value.begins_with("sha256:"):
		return false
	for index in range(7, value.length()):
		if value.substr(index, 1) not in "0123456789abcdef":
			return false
	return true


static func _required_bool(
		value: Dictionary,
		field: String,
		validation_reasons: Array[String]) -> bool:
	if typeof(value.get(field)) == TYPE_BOOL:
		return bool(value[field])
	validation_reasons.append("%s_INVALID" % field.to_upper())
	return false


static func _stable_string_field(
		value: Dictionary,
		field: String,
		validation_reasons: Array[String]) -> String:
	var field_value: Variant = value.get(field)
	if (field_value is String or field_value is StringName) \
			and not String(field_value).is_empty():
		return String(field_value)
	validation_reasons.append("%s_INVALID" % field.to_upper())
	return ""


static func _stable_layer_field(
		value: Dictionary,
		field: String,
		validation_reasons: Array[String]) -> int:
	if typeof(value.get(field)) == TYPE_INT and int(value[field]) > 0:
		return int(value[field])
	validation_reasons.append("%s_INVALID" % field.to_upper())
	return 0


static func _stable_string_allowlist(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> Array:
	var result: Array = []
	if not value is Array or (value as Array).is_empty():
		_add_error(
			errors,
			"ALLOWLIST_INVALID",
			path,
			"Expected a nonempty Array of stable nonempty names")
		return result
	for item in value as Array:
		if not (item is String or item is StringName) \
				or String(item).is_empty():
			_add_error(
				errors,
				"ALLOWLIST_ENTRY_INVALID",
				path,
				"Every allowlist entry must be a nonempty String/StringName")
			continue
		var stable_name := String(item)
		if result.has(stable_name):
			_add_error(
				errors,
				"ALLOWLIST_DUPLICATE",
				path,
				"Allowlist entries must be unique")
		else:
			result.append(stable_name)
	result.sort()
	return result


static func _stable_layer_allowlist(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> Array:
	var result: Array = []
	if not value is Array or (value as Array).is_empty():
		_add_error(
			errors,
			"LAYER_ALLOWLIST_INVALID",
			path,
			"Expected a nonempty Array of positive stable layer identifiers")
		return result
	for item in value as Array:
		if typeof(item) != TYPE_INT or int(item) <= 0:
			_add_error(
				errors,
				"LAYER_ALLOWLIST_ENTRY_INVALID",
				path,
				"Every stable layer identifier must be a positive integer")
			continue
		var layer := int(item)
		if result.has(layer):
			_add_error(
				errors,
				"LAYER_ALLOWLIST_DUPLICATE",
				path,
				"Stable layer identifiers must be unique")
		else:
			result.append(layer)
	result.sort()
	return result


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({"code": code, "path": path, "message": message})
