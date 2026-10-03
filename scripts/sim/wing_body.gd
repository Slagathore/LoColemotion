class_name WingBody
extends RigidBody3D

## M52 — flight. The first reserved force model: an aero element on a &"wing"-tagged part. In
## _integrate_forces (no custom_integrator, so gravity/contact still run) it computes lift ⟂ to the
## airflow and drag along it from the wing's OWN velocity — F = 0.5·ρ·v²·A·C — and applies it AT THE
## WING (Principle 17: aero acts on the surface, never a magic up-force on the root). Force is zero
## when airflow or wing area is zero, so it can't regress into "shove the root upward".

const AIR_DENSITY := 1.2

@export var wing_area: float = 0.2          # planform area (m²), from the wing's footprint
@export var lift_coeff: float = 1.1
@export var drag_coeff: float = 0.35
@export var normal_local: Vector3 = Vector3.UP   # the wing's chord normal in its local frame
@export var wing_enabled: bool = true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not wing_enabled or wing_area <= 0.0:
		return
	var v := state.linear_velocity
	var speed := v.length()
	if speed < 0.05:
		return
	var vhat := v / speed
	var q := 0.5 * AIR_DENSITY * speed * speed * wing_area    # dynamic pressure × area (∝ v²·A)
	var n := (state.transform.basis * normal_local)
	if n.length() < 0.0001:
		return
	n = n.normalized()
	# Lift is perpendicular to the airflow, in the plane of (airflow, wing normal).
	var lift_dir := n - vhat * n.dot(vhat)
	var lift := Vector3.ZERO
	if lift_dir.length() > 0.0001:
		lift = lift_dir.normalized() * (q * lift_coeff)
	var drag := -vhat * (q * drag_coeff)
	state.apply_central_force(lift + drag)        # at the wing body, NOT the root


# The aero force this wing would produce at a given world velocity (for tests / overlays).
func aero_force(velocity: Vector3) -> Vector3:
	if not wing_enabled or wing_area <= 0.0:
		return Vector3.ZERO
	var speed := velocity.length()
	if speed < 0.05:
		return Vector3.ZERO
	var vhat := velocity / speed
	var q := 0.5 * AIR_DENSITY * speed * speed * wing_area
	var n := (global_transform.basis * normal_local)
	if n.length() < 0.0001:
		return Vector3.ZERO
	n = n.normalized()
	var lift_dir := n - vhat * n.dot(vhat)
	var lift := Vector3.ZERO
	if lift_dir.length() > 0.0001:
		lift = lift_dir.normalized() * (q * lift_coeff)
	return lift + (-vhat * (q * drag_coeff))
