class_name LabBodySample
extends RefCounted

## Mutable direct-state sample builder. Call seal() before the value crosses an
## observer/controller/recorder boundary.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

var body_id: StringName
var physics_step_id := -1
var body_callback_sequence := -1
var capture_epoch := -1
var sample_phase: StringName = &"integrate_callback"
var position_m := Vector3.ZERO
var rotation_world := Quaternion.IDENTITY
var linear_velocity_m_s := Vector3.ZERO
var angular_velocity_rad_s := Vector3.ZERO
var mass_kg := 0.0
var inverse_inertia_tensor_world := Basis.IDENTITY
var step_s := 0.0
var total_gravity_world := Vector3.ZERO
var com_frame_oracle_error_m := 0.0
var observer_profile_id: StringName = &"full_state_v1"
var observer_adapter_id: StringName = &"rigid_body_integrate_forces_v1"
var finite := true
var sleeping := false


func to_value_dictionary() -> Dictionary:
	return {
		"physics_step_id": physics_step_id,
		"body_callback_sequence": body_callback_sequence,
		"capture_epoch": capture_epoch,
		"sample_phase": String(sample_phase),
		"body_id": String(body_id),
		"part_index": 0,
		"transform": Transform3D(Basis(rotation_world), position_m),
		"center_of_mass_world": position_m,
		"linear_velocity": linear_velocity_m_s,
		"angular_velocity": angular_velocity_rad_s,
		"mass_kg": mass_kg,
		"inverse_inertia_tensor_world": inverse_inertia_tensor_world,
		"sleeping": sleeping,
		"finite": finite,
		"step_s": step_s,
		"total_gravity_world": total_gravity_world,
		"com_frame_oracle_error_m": com_frame_oracle_error_m,
		"observer_profile_id": String(observer_profile_id),
		"observer_adapter_id": String(observer_adapter_id),
	}


func seal() -> Dictionary:
	return FrozenValueScript.snapshot(to_value_dictionary())
