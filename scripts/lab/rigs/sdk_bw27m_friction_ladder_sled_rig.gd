class_name LabSdkBw27mFrictionLadderSledRig
extends RefCounted

## BW27M-only successor wrapper around the immutable SDK sled family.
##
## Historical material closures bind every earlier wrapper byte-for-byte. This
## source owns only the BW27M fixture identity and its prospectively declared
## finite authored-value allowlist.

const ParentRigScript := preload("res://scripts/lab/rigs/sdk_friction_ladder_sled_rig.gd")

const BW27M_FIXTURE_ID := "SDK.BW27M.godot_jolt_material_sled.v1"
const BW27M_AUTHORED_FRICTION_VALUES := [0.0, 0.62, 0.74, 0.86]
const BW27M_RUN_ID_PREFIX := "sdk_bw27m_godot_jolt_friction"
const BW27M_CAPTURE_STREAM_PREFIX := "sdk_bw27m_friction_contact_stream"


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
			BW27M_AUTHORED_FRICTION_VALUES,
			BW27M_FIXTURE_ID,
			BW27M_RUN_ID_PREFIX,
			BW27M_CAPTURE_STREAM_PREFIX,
			"four preregistered BW27M characterization cells",
		)
	)
	if not bool(rig.get("ok", false)):
		return rig

	var token := "%03d" % int(round(friction * 100.0))
	var world: Node3D = rig["world"]
	var body: RigidBody3D = rig["body"]
	var floor: StaticBody3D = rig["floor"]
	world.name = "SdkBW27MFrictionLadderSled%s" % token
	body.name = "SdkBW27MObservedSled%s" % token
	floor.name = "SdkBW27MFrictionFloor%s" % token
	rig["successor_wrapper_id"] = "sdk_bw27m_friction_ladder_sled_rig_v1"
	rig["immutable_parent_fixture_source"] = (
		"scripts/lab/rigs/sdk_friction_ladder_sled_rig.gd"
	)
	return rig
