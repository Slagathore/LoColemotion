class_name LabSdkBw24mFrictionLadderSledRig
extends RefCounted

## BW24M-only successor wrapper around the immutable SDK sled family.
##
## Accepted earlier material closures bind the parent and BW22M wrappers
## byte-for-byte, so this distinct source owns only the new fixture identity
## and the prospectively declared finite authored-value allowlist.

const ParentRigScript := preload("res://scripts/lab/rigs/sdk_friction_ladder_sled_rig.gd")

const BW24M_FIXTURE_ID := "SDK.BW24M.godot_jolt_material_sled.v1"
const BW24M_AUTHORED_FRICTION_VALUES := [0.0, 0.59, 0.71, 0.83]
const BW24M_RUN_ID_PREFIX := "sdk_bw24m_godot_jolt_friction"
const BW24M_CAPTURE_STREAM_PREFIX := "sdk_bw24m_friction_contact_stream"


static func build(
	capture_clock,
	observer_profile: Dictionary,
	friction: float,
) -> Dictionary:
	var rig: Dictionary = (
		ParentRigScript
		. _build_campaign(
			capture_clock,
			observer_profile,
			friction,
			BW24M_AUTHORED_FRICTION_VALUES,
			BW24M_FIXTURE_ID,
			BW24M_RUN_ID_PREFIX,
			BW24M_CAPTURE_STREAM_PREFIX,
			"four preregistered BW24M characterization cells",
		)
	)
	if not bool(rig.get("ok", false)):
		return rig

	var token := "%03d" % int(round(friction * 100.0))
	var world: Node3D = rig["world"]
	var body: RigidBody3D = rig["body"]
	var floor: StaticBody3D = rig["floor"]
	world.name = "SdkBW24MFrictionLadderSled%s" % token
	body.name = "SdkBW24MObservedSled%s" % token
	floor.name = "SdkBW24MFrictionFloor%s" % token
	rig["successor_wrapper_id"] = "sdk_bw24m_friction_ladder_sled_rig_v1"
	rig["immutable_parent_fixture_source"] = (
		"scripts/lab/rigs/sdk_friction_ladder_sled_rig.gd"
	)
	return rig
