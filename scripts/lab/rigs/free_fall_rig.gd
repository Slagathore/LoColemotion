class_name LabFreeFallRig
extends RefCounted

const StationaryRigScript := preload(
	"res://scripts/lab/rigs/stationary_body_rig.gd")

const FIXTURE_ID := "L0.1.free_fall.v1"
const INITIAL_POSITION := Vector3(-0.5, 10.0, 0.75)


static func build(
		capture_clock,
		observer_profile: Dictionary,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	return StationaryRigScript._build_isolated_body(
		capture_clock,
		observer_profile,
		INITIAL_POSITION,
		Vector3.ZERO,
		1.0,
		FIXTURE_ID,
		body_parameters,
		fixture_parameters)
