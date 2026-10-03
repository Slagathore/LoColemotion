class_name LabSemanticContactRigidBody
extends RigidBody3D

## Minimal read-only per-shape contact observer for physical lab rigs.
##
## RigidBody3D.get_colliding_bodies() cannot distinguish a distal foot sphere
## from another collision shape on the same limb. This observer resolves the
## local CollisionShape3D semantic ID inside _integrate_forces without
## modifying physics state.

var latest_semantic_contacts: Dictionary = {}
var latest_semantic_contact_samples: Array[Dictionary] = []
var semantic_contact_callback_count := 0
var latest_direct_state_snapshot: Dictionary = {}


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	semantic_contact_callback_count += 1
	# Keep one read-only, callback-coherent state snapshot for native SDK
	# samplers.  The inverse inertia tensor is read here while the body is under
	# physics ownership; consumers can reconstruct rotational kinetic energy
	# without reaching back into a stale PhysicsDirectBodyState3D object.
	latest_direct_state_snapshot = {
		"callback_sequence": semantic_contact_callback_count,
		"transform": state.transform,
		"linear_velocity_world_m_s": state.linear_velocity,
		"angular_velocity_world_rad_s": state.angular_velocity,
		"total_gravity_world_m_s2": state.total_gravity,
		"solver_step_s": state.step,
		"mass_kg": mass,
		"inverse_inertia_tensor_world_kg_inv_m2": get_inverse_inertia_tensor(),
		"source_measurement": true,
	}
	var observed: Dictionary = {}
	var samples: Array[Dictionary] = []
	for contact_index in state.get_contact_count():
		var local_shape_index := state.get_contact_local_shape(contact_index)
		var collider_shape_index := state.get_contact_collider_shape(contact_index)
		var shape_id := _shape_semantic_id(self, local_shape_index)
		var collider := state.get_contact_collider_object(contact_index)
		var counterparty_id := ""
		if collider != null and collider.has_meta("lab_body_id"):
			counterparty_id = String(collider.get_meta("lab_body_id"))
		if not shape_id.is_empty() and not counterparty_id.is_empty():
			observed["%s|%s" % [shape_id, counterparty_id]] = true
			var local_position_world := state.get_contact_local_position(contact_index)
			var local_velocity_world := (
				state.linear_velocity
				+ state.angular_velocity.cross(local_position_world - state.transform.origin)
			)
			var collider_velocity_world := state.get_contact_collider_velocity_at_position(
				contact_index
			)
			samples.append(
				{
					"engine_contact_id":
					"%s:%d|%s:%d"
					% [
						shape_id,
						local_shape_index,
						counterparty_id,
						collider_shape_index,
					],
					"local_shape_id": shape_id,
					"local_shape_index": local_shape_index,
					"counterparty_id": counterparty_id,
					"collider_shape_index": collider_shape_index,
					"local_position_world_m": local_position_world,
					"collider_position_world_m":
					state.get_contact_collider_position(contact_index),
					"local_normal_world_unit": state.get_contact_local_normal(contact_index),
					"relative_velocity_world_m_s":
					local_velocity_world - collider_velocity_world,
					"raw_impulse_world_nms": state.get_contact_impulse(contact_index),
				}
			)
	latest_semantic_contacts = observed
	latest_semantic_contact_samples = samples


func has_semantic_contact(shape_id: String, counterparty_id: String) -> bool:
	return latest_semantic_contacts.has("%s|%s" % [shape_id, counterparty_id])


static func _shape_semantic_id(collision_object: CollisionObject3D, shape_index: int) -> String:
	if shape_index < 0:
		return ""
	var owner_id := collision_object.shape_find_owner(shape_index)
	if owner_id < 0:
		return ""
	var owner := collision_object.shape_owner_get_owner(owner_id)
	if owner == null or not owner.has_meta("lab_shape_id"):
		return ""
	return String(owner.get_meta("lab_shape_id"))
