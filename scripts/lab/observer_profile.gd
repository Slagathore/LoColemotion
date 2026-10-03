class_name ObserverProfile
extends RefCounted

## Immutable, versioned observer-profile registry. IDs are exact; changing a
## channel or capture semantic requires a new versioned ID.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const _IMPLEMENTED_CHANNELS := [
	"body_transform",
	"center_of_mass_world",
	"linear_velocity",
	"angular_velocity",
	"sleeping",
	"mass",
	"inverse_inertia_tensor_world",
	"whole_body_momentum",
	"contacts",
	"contact_impulses",
	"raw_contacts_v2",
	"contact_capacity_v1",
	"callback_sequence",
	"capture_epoch",
]

const _PROFILE_DEFINITIONS := {
	"minimal_state_v1": {
		"contacts_enabled": false,
		"contact_cap_per_body": 0,
		"channels": [
			"body_transform",
			"center_of_mass_world",
			"linear_velocity",
			"angular_velocity",
			"sleeping",
		],
	},
	"full_state_v1": {
		"contacts_enabled": false,
		"contact_cap_per_body": 0,
		"channels": [
			"body_transform",
			"center_of_mass_world",
			"linear_velocity",
			"angular_velocity",
			"sleeping",
			"mass",
			"inverse_inertia_tensor_world",
			"whole_body_momentum",
		],
	},
	"full_contacts_v1": {
		"contacts_enabled": true,
		"contact_cap_per_body": 32,
		"channels": [
			"body_transform",
			"center_of_mass_world",
			"linear_velocity",
			"angular_velocity",
			"sleeping",
			"mass",
			"inverse_inertia_tensor_world",
			"whole_body_momentum",
			"contacts",
			"contact_impulses",
		],
	},
	"full_contacts_v2": {
		"contacts_enabled": true,
		# v2 bodies do not inherit one magic contact cap from the profile.
		# Their fixture/morphology derives the effective cap and binds it to
		# the observer before the body enters the physics world.
		"contact_cap_per_body": 0,
		"contact_cap_mode": "fixture_derived_v1",
		"contact_policy_max_cap_per_body": 256,
		"channels": [
			"body_transform",
			"center_of_mass_world",
			"linear_velocity",
			"angular_velocity",
			"sleeping",
			"mass",
			"inverse_inertia_tensor_world",
			"whole_body_momentum",
			# Keep the v1 projection available for frame_v1 compatibility while
			# emitting the append-only semantic raw-contact stream alongside it.
			"contacts",
			"contact_impulses",
			"raw_contacts_v2",
			"contact_capacity_v1",
		],
	},
	"full_energy_v1": {
		"contacts_enabled": true,
		"contact_cap_per_body": 32,
		"channels": [
			"body_transform",
			"center_of_mass_world",
			"linear_velocity",
			"angular_velocity",
			"sleeping",
			"mass",
			"inverse_inertia_tensor_world",
			"whole_body_momentum",
			"contacts",
			"contact_impulses",
			"kinetic_energy",
			"gravitational_potential_energy",
			"mechanics_residuals",
		],
	},
	"debug_everything_v1": {
		"contacts_enabled": true,
		"contact_cap_per_body": 64,
		"channels": [
			"body_transform",
			"center_of_mass_world",
			"linear_velocity",
			"angular_velocity",
			"sleeping",
			"mass",
			"inverse_inertia_tensor_world",
			"whole_body_momentum",
			"contacts",
			"contact_impulses",
			"kinetic_energy",
			"gravitational_potential_energy",
			"mechanics_residuals",
			"callback_sequence",
			"capture_epoch",
			"raw_direct_state",
		],
	},
}


static func registered_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for profile_id in _PROFILE_DEFINITIONS.keys():
		result.append(StringName(profile_id))
	result.sort()
	return result


static func has_profile(profile_id: StringName) -> bool:
	return _PROFILE_DEFINITIONS.has(String(profile_id))


static func resolve(profile_id: StringName) -> Dictionary:
	var key := String(profile_id)
	assert(
		_PROFILE_DEFINITIONS.has(key),
		"Unknown observer profile ID: %s" % key)
	var definition: Dictionary = _PROFILE_DEFINITIONS[key]
	var channels: Array = definition["channels"].duplicate()
	channels.sort()
	var channel_identity := {
		"profile_id": key,
		"channels": channels,
		"contacts_enabled": bool(definition["contacts_enabled"]),
		"contact_cap_per_body": int(definition["contact_cap_per_body"]),
	}
	# These fields exist only on v2 definitions. Keeping them conditional is
	# intentional: the frozen v1 profile identities and SHA-256 digests must not
	# change merely because a new observer generation was registered.
	if definition.has("contact_cap_mode"):
		channel_identity["contact_cap_mode"] = String(
			definition["contact_cap_mode"])
		channel_identity["contact_policy_max_cap_per_body"] = int(
			definition["contact_policy_max_cap_per_body"])
	var resolved := channel_identity.duplicate(true)
	resolved["channel_set_sha256"] = CanonicalJsonScript.sha256(channel_identity)
	var unsupported_channels: Array = []
	for channel in channels:
		if not _IMPLEMENTED_CHANNELS.has(String(channel)):
			unsupported_channels.append(channel)
	resolved["unsupported_channels"] = unsupported_channels
	resolved["executable"] = unsupported_channels.is_empty()
	return FrozenValueScript.snapshot(resolved)


static func captures(profile_id: StringName, channel_id: StringName) -> bool:
	if not has_profile(profile_id):
		return false
	var channels: Array = _PROFILE_DEFINITIONS[String(profile_id)]["channels"]
	return channels.has(String(channel_id))


static func is_executable(profile_id: StringName) -> bool:
	if not has_profile(profile_id):
		return false
	return bool(resolve(profile_id)["executable"])
