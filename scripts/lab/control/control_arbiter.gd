class_name LabControlArbiter
extends RefCounted

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")


static func select_active_intent(intents: Array, tick: int) -> Dictionary:
	var feasible: Array = []
	for raw in intents:
		if not raw is Dictionary:
			continue
		var intent: Dictionary = raw
		if (int(intent.get("tick", -1)) == tick
			and int(intent.get("valid_until_tick", -1)) >= tick
			and bool(intent.get("feasible", false))):
			feasible.append(intent)
	if feasible.is_empty():
		return FrozenValueScript.snapshot({
			"mode": "SAFE_DAMP",
			"source": "control_arbiter",
			"reason": "NO_FEASIBLE_INTENT",
			"desired_joint_torques": {},
		})
	feasible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("priority", 0)) != int(b.get("priority", 0)):
			return int(a.get("priority", 0)) > int(b.get("priority", 0))
		return String(a.get("intent_id", "")) < String(b.get("intent_id", "")))
	return FrozenValueScript.snapshot(feasible[0])
