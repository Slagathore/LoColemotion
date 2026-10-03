class_name AnisotropicBody
extends RigidBody3D

## M40 — directional ground friction for undulation. A snake's belly slides easily ALONG
## its body (axial) but grips SIDEWAYS (lateral), so a body-wave produces net forward
## translation. Godot/Jolt friction is impulse-based (not contact-area-based), so a flatter
## collision box gives anisotropic tip-over but ISOTROPIC friction — geometry alone can't do
## this. Instead we damp only the horizontal LATERAL velocity component
## in _integrate_forces. Purely dissipative (KE can only drop), deterministic, probe-exempt.
##
## We override _integrate_forces WITHOUT custom_integrator, so default gravity/contact still
## run and we only trim the post-step velocity.

@export var axial_axis_local: Vector3 = Vector3(0.0, 0.0, 1.0)  # the segment's slither (body) axis
@export var lateral_damp_coeff: float = 12.0                    # sideways grip (high)
# Along-body slip: low (the belly slides easily along the body) but NOT frictionless — a real snake has
# some forward drag. Raised 0.15 -> 0.4 after the vital-organ right-sizing left the light body COASTING
# (near-zero axial drag let settling momentum slide it ~5.8 m with no drive, beating the driven wave).
# 0.4 keeps the belly clearly axial-dominant (belly still slides freely) while killing the free coast.
@export var axial_damp_coeff: float = 0.4
@export var anisotropic_enabled: bool = true


# M59: anisotropic ground friction applied as a FORCE (not a post-step velocity trim). Applying it
# during integration lets the constraint solver couple it through the jointed body, so a traveling
# body-wave nets real FORWARD thrust — the standard viscous-crawler result. A snake's belly slides
# easily ALONG the body (low axial drag) but grips SIDEWAYS (high lateral drag); the asymmetry
# rectifies the wave into translation. Still dissipative (drag only opposes velocity, never adds
# energy — the muscles/joints do the work); the friction just chooses the direction.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not anisotropic_enabled:
		return
	var v := state.linear_velocity
	var axis_world := (state.transform.basis * axial_axis_local)
	axis_world.y = 0.0
	if axis_world.length() < 0.0001:
		return
	axis_world = axis_world.normalized()
	var v_h := Vector3(v.x, 0.0, v.z)
	var v_axial := axis_world * v_h.dot(axis_world)   # slides along the body (low drag)
	var v_lat := v_h - v_axial                        # grips sideways (high drag)
	var f := -v_lat * (lateral_damp_coeff * mass) - v_axial * (axial_damp_coeff * mass)
	if f.is_finite():
		state.apply_central_force(f)
