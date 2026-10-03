class_name DriveIntent
extends RefCounted

## Per-joint target overlay consumed by CpgController. Higher-level controllers
## propose intent here; the existing PD drive still earns the motion with torque.

var part_index := -1
var target_angle := 0.0
var weight := 1.0
var ttl_ticks := 3
var source := &"unknown"


static func make(part_idx: int, target: float, blend_weight := 1.0,
		ticks := 3, intent_source := &"unknown"):
	var d := new()
	d.part_index = part_idx
	d.target_angle = target
	d.weight = clampf(blend_weight, 0.0, 1.0)
	d.ttl_ticks = maxi(ticks, 1)
	d.source = intent_source
	return d
