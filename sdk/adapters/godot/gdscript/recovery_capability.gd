extends RefCounted
# gdlint: disable=max-line-length

## Zero-world Godot 4.7/Jolt recovery-observation capability mapping.
##
## PhysicsDirectBodyState3D exposes post-step contact impulses, but the public
## HingeJoint3D surface exposes only the configured motor impulse limit. It does
## not expose the solved per-step motor impulse/work. Those two dependent
## channels therefore remain explicitly unsupported; no value is synthesized.

const CAPABILITY_SCHEMA_VERSION := "sporespore_recovery_adapter_capability_v1"
const ADAPTER_ID := "sporespore_godot_jolt_adapter"
const ENGINE_ID := "godot_jolt4_7"
const ENGINE_VERSION := "godot-4.7-stable-jolt-physics"
const MAPPING_ID := "sporespore_godot_jolt_recovery_observation_capability_v1"

const ORDERED_CHANNELS := [
	"canonical_body_pose_and_twist",
	"whole_system_center_of_mass_position_and_velocity",
	"ordered_joint_position_and_velocity",
	"ordered_foot_bearing_contact_observations",
	"classified_nonfoot_contact_observations",
	"applied_actuation_receipts",
	"external_intervention_ledger",
	"controller_ownership_receipt",
	"energy_balance_ledger",
	"engine_step_identity",
]
const UNSUPPORTED_CHANNELS := [
	"applied_actuation_receipts",
	"energy_balance_ledger",
]

const SOURCE_RECORDS := [
	{
		"sources": [
			"PhysicsDirectBodyState3D.get_transform",
			"PhysicsDirectBodyState3D.get_linear_velocity",
			"PhysicsDirectBodyState3D.get_angular_velocity",
		],
		"mapping": "godot_direct_body_state_to_canonical_y_up_right_handed_v1",
	},
	{
		"sources": [
			"PhysicsDirectBodyState3D.get_center_of_mass",
			"PhysicsDirectBodyState3D.get_linear_velocity",
			"PhysicsDirectBodyState3D.get_inverse_mass",
			"sporespore_godot_jolt_adapter.mass_weighted_whole_system_com_ledger_v1",
		],
		"mapping": "godot_mass_weighted_whole_system_com_projection_v1",
	},
	{
		"sources": [
			"RigidBody3D.global_transform",
			"RigidBody3D.angular_velocity",
			"HingeJoint3D.node_a",
			"HingeJoint3D.node_b",
		],
		"mapping": "godot_relative_body_transform_and_axis_velocity_ordered_v1",
	},
	{
		"sources": [
			"PhysicsDirectBodyState3D.get_contact_count",
			"PhysicsDirectBodyState3D.get_contact_local_position",
			"PhysicsDirectBodyState3D.get_contact_local_normal",
			"PhysicsDirectBodyState3D.get_contact_impulse",
			"PhysicsDirectBodyState3D.get_contact_local_shape",
		],
		"mapping": "godot_post_step_ordinary_unilateral_foot_normal_impulse_sum_v1",
	},
	{
		"sources": [
			"PhysicsDirectBodyState3D.get_contact_count",
			"PhysicsDirectBodyState3D.get_contact_impulse",
			"PhysicsDirectBodyState3D.get_contact_local_shape",
			"PhysicsDirectSpaceState3D.cast_motion",
		],
		"mapping": "godot_shape_identity_nonfoot_classification_and_clearance_query_v1",
	},
	{
		"sources": [
			"HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE_configured_limit_only",
			"HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY_configured_target_only",
		],
		"mapping": "unsupported_no_public_post_solver_hinge_motor_impulse_readback_v1",
	},
	{
		"sources": [
			"sporespore_godot_jolt_adapter.append_only_intervention_call_ledger_v1",
		],
		"mapping": "godot_adapter_owned_exact_intervention_counter_projection_v1",
	},
	{
		"sources": [
			"sporespore_godot_jolt_adapter.exclusive_controller_owner_ledger_v1",
		],
		"mapping": "godot_adapter_owned_controller_handoff_projection_v1",
	},
	{
		"sources": [
			"PhysicsDirectBodyState3D_state_energy_terms",
			"missing_public_post_solver_hinge_motor_work",
		],
		"mapping": "unsupported_energy_balance_requires_solved_actuator_work_v1",
	},
	{
		"sources": [
			"PhysicsDirectBodyState3D.get_step",
			"sporespore_godot_jolt_adapter.physics_frame_identity_ledger_v1",
		],
		"mapping": "godot_exact_post_step_and_native_solver_identity_v1",
	},
]


static func capability_v1() -> Dictionary:
	var channels: Array = []
	for index in range(ORDERED_CHANNELS.size()):
		var channel_id := String(ORDERED_CHANNELS[index])
		var supported := channel_id not in UNSUPPORTED_CHANNELS
		var record: Dictionary = SOURCE_RECORDS[index]
		channels.append(
			{
				"channel": channel_id,
				"support": "supported_measured" if supported else "unsupported",
				"host_source_ids": (record["sources"] as Array).duplicate(),
				"mapping_rule_id": String(record["mapping"]),
				"source_measurement_only": supported,
				"synthesized_when_missing": false,
			}
		)
	return {
		"schema_version": CAPABILITY_SCHEMA_VERSION,
		"adapter_id": ADAPTER_ID,
		"engine": ENGINE_ID,
		"engine_version": ENGINE_VERSION,
		"mapping_id": MAPPING_ID,
		"native_engine": true,
		"ordered_channels": channels,
		"host_pose_label_used_for_success": false,
		"fallback_control_permitted": false,
		"engine_identity_exposed_to_policy": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}

static func validate_capability_v1(capability: Dictionary) -> Dictionary:
	var failure_code := ""
	if String(capability.get("schema_version", "")) != CAPABILITY_SCHEMA_VERSION:
		failure_code = "CAPABILITY_SCHEMA_INVALID"
	elif String(capability.get("adapter_id", "")) != ADAPTER_ID:
		failure_code = "ADAPTER_ID_INVALID"
	elif String(capability.get("engine", "")) != ENGINE_ID:
		failure_code = "ENGINE_ID_INVALID"
	elif String(capability.get("engine_version", "")) != ENGINE_VERSION:
		failure_code = "ENGINE_VERSION_INVALID"
	elif String(capability.get("mapping_id", "")) != MAPPING_ID:
		failure_code = "MAPPING_ID_INVALID"
	elif not bool(capability.get("native_engine", false)):
		failure_code = "NATIVE_ENGINE_INVALID"
	elif (
		bool(capability.get("host_pose_label_used_for_success", true))
		or bool(capability.get("fallback_control_permitted", true))
		or bool(capability.get("engine_identity_exposed_to_policy", true))
		or int(capability.get("model_construction_count", -1)) != 0
		or int(capability.get("world_attempt_count", -1)) != 0
		or int(capability.get("world_build_count", -1)) != 0
		or int(capability.get("solver_step_count", -1)) != 0
		or bool(capability.get("physics_state_modified", true))
		or bool(capability.get("physical_acceptance_authority", true))
		or bool(capability.get("release_authority", true))
	):
		failure_code = "SIDE_EFFECT_OR_AUTHORITY_BOUNDARY_INVALID"
	var channels_value: Variant = capability.get("ordered_channels")
	if failure_code.is_empty() and not (channels_value is Array):
		failure_code = "CHANNELS_INVALID"
	var channels: Array = [] if not (channels_value is Array) else channels_value
	if failure_code.is_empty() and channels.size() != ORDERED_CHANNELS.size():
		failure_code = "CHANNEL_COUNT_INVALID"
	if failure_code.is_empty():
		for index in range(channels.size()):
			var item_value: Variant = channels[index]
			if not (item_value is Dictionary):
				failure_code = "CHANNEL_RECORD_INVALID"
				break
			var item: Dictionary = item_value
			var channel_id := String(ORDERED_CHANNELS[index])
			var expected_supported := channel_id not in UNSUPPORTED_CHANNELS
			var sources_value: Variant = item.get("host_source_ids")
			if (
				String(item.get("channel", "")) != channel_id
				or String(item.get("support", ""))
				!= ("supported_measured" if expected_supported else "unsupported")
				or bool(item.get("source_measurement_only", false)) != expected_supported
				or bool(item.get("synthesized_when_missing", true))
				or not (sources_value is Array)
				or (sources_value as Array).is_empty()
				or String(item.get("mapping_rule_id", "")).is_empty()
			):
				failure_code = "CHANNEL_MAPPING_INVALID_%s" % channel_id
				break
	return {
		"ok": failure_code.is_empty(),
		"failure_code": failure_code,
		"required_channel_count": ORDERED_CHANNELS.size(),
		"supported_channel_count": ORDERED_CHANNELS.size() - UNSUPPORTED_CHANNELS.size(),
		"unsupported_channel_count": UNSUPPORTED_CHANNELS.size(),
		"unsupported_channels": UNSUPPORTED_CHANNELS.duplicate(),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
