extends RefCounted
## Prospective development trigger, separate from portable recovery success.
## Three consecutive current callbacks with >45-degree tilt or torso contact.
const UP_DOT_MIN := 0.7071067811865476
const REQUIRED_SAMPLES := 3

static func advance_v1(prior: Dictionary, sample: Dictionary) -> Dictionary:
	var step: Variant = sample.get("global_step")
	var up: Variant = sample.get("torso_up_world")
	var contact: Variant = sample.get("torso_nonfoot_contact")
	if (typeof(step) != TYPE_INT or step <= 0 or sample.get("callback_sequence") != step
		or not (up is Vector3) or not up.is_finite() or absf(up.length()-1.0) > 0.00001
		or typeof(contact) != TYPE_BOOL or sample.get("source_measurement") != true): return {"ok":false,"failure_code":"LIVE_FALL_SOURCE"}
	if not prior.is_empty() and (prior.get("last_global_step") != step-1 or prior.get("triggered") != false
		or typeof(prior.get("consecutive")) != TYPE_INT or prior.consecutive < 0 or prior.consecutive >= REQUIRED_SAMPLES): return {"ok":false,"failure_code":"LIVE_FALL_CONTINUITY"}
	var abnormal: bool = up.dot(Vector3.UP) < UP_DOT_MIN or contact
	var count: int = prior.get("consecutive",0)+1 if abnormal else 0
	return {"ok":true,"state_after":{"last_global_step":step,"consecutive":count,"triggered":count == REQUIRED_SAMPLES},
		"sample":sample.duplicate(true),"abnormal":abnormal,"up_dot":up.dot(Vector3.UP),
		"world_build_count":0,"solver_step_count":0,"physics_state_modified":false,
		"physical_acceptance_authority":false,"release_authority":false}
