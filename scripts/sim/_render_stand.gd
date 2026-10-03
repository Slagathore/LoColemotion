extends SceneTree

## Render the SETTLE/STAND (no gait): PNG every 0.5 s for 5 s. Run WITHOUT --headless.
## Frames -> SPORE_FRAMES_DIR or user://stand_frames.

const SimWorldScript := preload("res://scripts/sim/sim_world.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")

var _dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var env := OS.get_environment("SPORE_FRAMES_DIR")
	_dir = env if env != "" else ProjectSettings.globalize_path("user://stand_frames")
	print("render_stand: frames -> ", _dir)
	DisplayServer.window_set_size(Vector2i(720, 440))
	DirAccess.make_dir_recursive_absolute(_dir)
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := SimWorldScript.add_floor(world, 1.0)
	var fmi := MeshInstance3D.new()
	var fmesh := BoxMesh.new()
	fmesh.size = Vector3(30.0, 0.2, 30.0)
	fmi.mesh = fmesh
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.35, 0.36, 0.40)
	fmi.material_override = fmat
	floor_body.add_child(fmi)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	world.add_child(sun)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.09, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.55)
	e.ambient_light_energy = 0.7
	we.environment = e
	world.add_child(we)
	var cam := Camera3D.new()
	world.add_child(cam)

	var g = PartCatalog.make_quadruped_v2()
	var spawn_y: float = SimRolloutScript.spawn_y(g)
	var body: Node3D = CreatureBodyScript.build(GenomeSnapshot.deep_copy(g),
			Transform3D(Basis.IDENTITY, Vector3(0, spawn_y, 0)), null)
	world.add_child(body)
	var bodies: Array = body.call("part_bodies")
	var parts: Array = body.call("parts")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.47, 0.74)
	for i in bodies.size():
		var rb := bodies[i] as RigidBody3D
		if rb == null or i >= parts.size():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = PartMeshProvider.mesh_for(parts[i].definition.part_type, parts[i].dims)
		mi.material_override = mat
		rb.add_child(mi)
	var cp := CpgControllerScript.Params.new()
	if g.gait != null:
		cp.amplitude_scale = g.gait.amplitude_scale
		cp.frequency_scale = g.gait.frequency_scale
		cp.gain_scale = g.gait.gain_scale
		cp.locomotion_mode = g.gait.locomotion_mode
	var ctrl := CpgControllerScript.new()
	ctrl.bind(body, g, cp)
	world.add_child(ctrl)
	var rb0 := bodies[0] as RigidBody3D
	for i in 300:
		if ctrl.wants_settle_tick():
			ctrl.settle_tick(1.0 / 60.0)
		_track(cam, rb0)
		await physics_frame
		if i % 30 == 29:
			print("t=%.1f y=%.3f up=%.3f" % [
				(i + 1) / 60.0, rb0.global_position.y, rb0.global_basis.y.dot(Vector3.UP)])
			await _snap(cam, rb0, "s%03d" % (i + 1))
	quit(0)


func _track(cam: Camera3D, rb: RigidBody3D) -> void:
	if rb == null:
		return
	var p := rb.global_position
	cam.global_position = p + Vector3(1.6, 0.7, 1.9)
	cam.look_at(p, Vector3.UP)


func _snap(cam: Camera3D, rb: RigidBody3D, name_s: String) -> void:
	_track(cam, rb)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, name_s])
