class_name LabSdkBw22mFrictionLadderSledRig
extends RefCounted

## BW22M-only successor wrapper around the immutable SDK sled family.
##
## The parent wrapper remains byte-identical because accepted BW20F closures
## bind it directly. This distinct source adds only the prospectively declared
## BW22M fixture identity and finite authored-value allowlist.

const ParentRigScript := preload("res://scripts/lab/rigs/sdk_friction_ladder_sled_rig.gd")

const BW22M_FIXTURE_ID := "SDK.BW22M.godot_jolt_material_sled.v1"
const BW22M_AUTHORED_FRICTION_VALUES := [0.0, 0.57, 0.69, 0.81]
const BW22M_RUN_ID_PREFIX := "sdk_bw22m_godot_jolt_friction"
const BW22M_CAPTURE_STREAM_PREFIX := "sdk_bw22m_friction_contact_stream"


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
			BW22M_AUTHORED_FRICTION_VALUES,
			BW22M_FIXTURE_ID,
			BW22M_RUN_ID_PREFIX,
			BW22M_CAPTURE_STREAM_PREFIX,
			"four preregistered BW22M characterization cells",
		)
	)
	if not bool(rig.get("ok", false)):
		return rig

	var token := "%03d" % int(round(friction * 100.0))
	var world: Node3D = rig["world"]
	var body: RigidBody3D = rig["body"]
	var floor: StaticBody3D = rig["floor"]
	world.name = "SdkBW22MFrictionLadderSled%s" % token
	body.name = "SdkBW22MObservedSled%s" % token
	floor.name = "SdkBW22MFrictionFloor%s" % token
	rig["successor_wrapper_id"] = "sdk_bw22m_friction_ladder_sled_rig_v1"
	rig["immutable_parent_fixture_source"] = ("scripts/lab/rigs/sdk_friction_ladder_sled_rig.gd")
	return rig
