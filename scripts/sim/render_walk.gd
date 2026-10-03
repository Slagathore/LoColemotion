extends SceneTree

## RENDER-WALK diagnostic: run the viewer-equivalent sim (the same params the bench's "Watch it
## walk" passes) and save a PNG frame every 0.5 s so a gait's MOTION SHAPE can be inspected —
## aggregate rollout metrics can hide a face-plant (a run that pitches to 45° and nose-shuffles
## still reads "up_min 0.7, fwd 1.0"). Needs a display: run WITHOUT --headless (a small window
## opens for ~12 s):
##
##   Godot_v4.7-..._console.exe --path . --script res://scripts/sim/render_walk.gd
##
## Frames land in OUT_DIR (default user://walk_frames). Optionally set SPORE_FRAMES_DIR to
## redirect. Prints t / fwd / up every 0.5 s alongside the frames.

const SimWorldScript := preload("res://scripts/sim/sim_world.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")

var _frames_dir := ""


func _out_dir() -> String:
	var env := OS.get_environment("SPORE_FRAMES_DIR")
	if env != "":
		return env
	return ProjectSettings.globalize_path("user://walk_frames")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_frames_dir = _out_dir()
	print("render_walk: frames -> ", _frames_dir)
	DisplayServer.window_set_size(Vector2i(720, 440))
	DirAccess.make_dir_recursive_absolute(_frames_dir)
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
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.09, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.55)
	e.ambient_light_energy = 0.7
	env.environment = e
	world.add_child(env)
	var cam := Camera3D.new()
	world.add_child(cam)

	# Default creature: the built-in quad_v2. Pass `-- card=res://data/creatures/x.tres`
	# (or set SPORE_WALK_CARD) to render a saved CreatureCard instead — e.g. the
	# GaitOptimizer's tuned output, so the frames judge exactly what the tuner saved.
	var g: PartGene = null
	var card_path := OS.get_environment("SPORE_WALK_CARD")
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("card="):
			card_path = s.substr(5)
	if card_path != "":
		var card := CreatureIO.load(card_path)
		if card != null and card.root != null:
			g = card.root
			print("render_walk: creature <- ", card_path)
	if g == null:
		g = PartCatalog.make_quadruped_v2()
	var spawn_y: float = SimRolloutScript.spawn_y(g)
	var body: Node3D = CreatureBodyScript.build(GenomeSnapshot.deep_copy(g),
			Transform3D(Basis.IDENTITY, Vector3(0, spawn_y, 0)), null)
	world.add_child(body)
	# viewer-style display meshes
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
	# bench-equivalent controller params (speed = 1)
	var cp := CpgControllerScript.Params.new()
	cp.amplitude_scale = g.gait.amplitude_scale
	cp.gain_scale = g.gait.gain_scale
	cp.frequency_scale = g.gait.frequency_scale
	cp.traction_scale = g.gait.traction_scale
	cp.posture_scale = g.gait.posture_scale
	cp.turn_rate = g.gait.turn_rate
	var ctrl := CpgControllerScript.new()
	ctrl.bind(body, g, cp)
	world.add_child(ctrl)

	var rb0 := bodies[0] as RigidBody3D
	for _i in 90:
		if ctrl.wants_settle_tick():
			ctrl.settle_tick(1.0 / 60.0)
		_track(cam, rb0)
		await physics_frame
	await _snap(cam, rb0, "settle")
	var start := rb0.global_position
	var t := 0.0
	for i in 600:
		t += 1.0 / 60.0
		ctrl.tick(t, 1.0 / 60.0)
		_track(cam, rb0)
		await physics_frame
		if i % 30 == 29:
			var fwd := (rb0.global_position - start).dot(Vector3(0, 0, -1))
			var up := rb0.global_basis.y.dot(Vector3.UP)
			print("t=%5.2f fwd=%+.3f up=%+.3f" % [t, fwd, up])
			await _snap(cam, rb0, "t%04d" % (i + 1))
	quit(0)


func _track(cam: Camera3D, rb: RigidBody3D) -> void:
	if rb == null:
		return
	var p := rb.global_position
	cam.global_position = p + Vector3(2.0, 1.1, 2.4)
	cam.look_at(p, Vector3.UP)


func _snap(cam: Camera3D, rb: RigidBody3D, name_s: String) -> void:
	_track(cam, rb)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_frames_dir, name_s])
