extends RefCounted
## Explicit campaign seed-to-prefix mapping. No model, SDK or world creation.
const Seed := preload("res://sdk/adapters/godot/gdscript/r10w_campaign_seed_v1.gd")
const PREFIX_PROFILE := "r10w_declared_campaign_prefix_phase_v1"
const DESIGN_SHA := "sha256:950b5a8f7de511f50739ded10ab53c66644379d8f8a4af63561a2c1438a02db0"

static func prefix_selection_v1(seed_value: int, profile: String) -> Dictionary:
	var identity := Seed.seed_identity_v1(seed_value)
	if profile != PREFIX_PROFILE or identity.is_empty(): return {}
	return {"schema_version": "sporespore_r10w_prefix_phase_selection_v1", "profile_id": profile,
		"seed": seed_value, "prefix_phase": identity.prefix_phase, "source_design_sha256": DESIGN_SHA,
		"physical_acceptance_authority": false, "release_authority": false}

static func prefix_gait_steps_v1(seed_value: int, profile: String) -> Dictionary:
	var selected := prefix_selection_v1(seed_value, profile)
	if selected.is_empty(): return {}
	return {"front_left": selected.prefix_phase, "front_right": selected.prefix_phase,
		"rear_left": selected.prefix_phase, "rear_right": selected.prefix_phase}
