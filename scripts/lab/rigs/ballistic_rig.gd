class_name LabBallisticRig
extends RefCounted

const StationaryRigScript := preload(
	"res://scripts/lab/rigs/stationary_body_rig.gd")

const FIXTURE_ID := "L0.2.ballistic_zero_g.v1"
const GRAVITY_FIXTURE_ID := "L0.2.ballistic_gravity.v1"
const INITIAL_POSITION := Vector3(-1.25, 2.5, 0.75)
const INITIAL_VELOCITY := Vector3(2.5, 1.25, -0.75)


static func build(
		capture_clock,
		observer_profile: Dictionary,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	return StationaryRigScript._build_isolated_body(
		capture_clock,
		observer_profile,
		INITIAL_POSITION,
		INITIAL_VELOCITY,
		0.0,
		FIXTURE_ID,
		body_parameters,
		fixture_parameters)


static func build_with_gravity(
		capture_clock,
		observer_profile: Dictionary,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	return StationaryRigScript._build_isolated_body(
		capture_clock,
		observer_profile,
		INITIAL_POSITION,
		INITIAL_VELOCITY,
		1.0,
		GRAVITY_FIXTURE_ID,
		body_parameters,
		fixture_parameters)
