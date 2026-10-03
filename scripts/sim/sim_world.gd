class_name SimWorld
extends RefCounted

## Shared physics-world construction for rollout, viewer, and tests.


static func make_physics_material(friction := 1.0, bounce := 0.0) -> PhysicsMaterial:
	var mat := PhysicsMaterial.new()
	mat.friction = maxf(friction, 0.0)
	mat.bounce = maxf(bounce, 0.0)
	return mat


static func add_floor(parent: Node3D, friction := 1.0, bounce := 0.0) -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "SimFloor"
	floor.physics_material_override = make_physics_material(friction, bounce)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# THICK floor. A thin floor (0.2) let a fast foot/segment tunnel through in one tick (no continuous
	# collision) and get stuck BELOW it with nothing to push it back up. A deep box means a part that
	# punches the top surface is still inside the floor, so penetration recovery shoves it back UP.
	# The top surface stays at y=0 (size.y/2 + position.y = 1 + -1) and the width is unchanged, so
	# contact physics/friction and the arena are identical — only the get-stuck-below failure is gone.
	box.size = Vector3(30.0, 2.0, 30.0)
	cs.shape = box
	floor.add_child(cs)
	floor.position.y = -1.0
	parent.add_child(floor)
	return floor
