extends Node3D

## Tier-1 assembly smoke test (the project's main scene; run with F5).
##
## Builds a hardcoded quadruped genome from primitive parts, assembles it via
## CreatureAssembler (which reads CharacteristicsEvaluator.fold_graph, so the picture
## can't drift from the stats), drops a marker at the evaluator's reported CoG, and
## overlays a few live stats. Press SPACE to toggle centered <-> front-loaded legs:
## the visible build and the overlay's balance.stable must agree (centered = stable,
## front-loaded = not). Drag to orbit, wheel to zoom.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

var creature: Node3D
var cog_marker: MeshInstance3D
var info: Label
var front_loaded := false

# orbit camera
var cam_pivot: Node3D
var camera: Camera3D
var cam_yaw := 0.7
var cam_pitch := 0.35
var cam_dist := 6.0
var _dragging := false


func _ready() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -40.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.10, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.32, 0.38)
	env.ambient_light_energy = 0.6
	we.environment = env
	add_child(we)

	# Ground reference plane, roughly at foot height.
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12.0, 12.0)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.16, 0.17, 0.20)
	ground.material_override = gmat
	ground.position.y = -0.7
	add_child(ground)

	cam_pivot = Node3D.new()
	add_child(cam_pivot)
	camera = Camera3D.new()
	cam_pivot.add_child(camera)

	cog_marker = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	cog_marker.mesh = sm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(1.0, 0.85, 0.1)
	cmat.emission_enabled = true
	cmat.emission = Color(1.0, 0.7, 0.0)
	cog_marker.material_override = cmat
	add_child(cog_marker)

	var ui := CanvasLayer.new()
	add_child(ui)
	info = Label.new()
	info.position = Vector2(16.0, 12.0)
	info.add_theme_color_override("font_color", Color.WHITE)
	ui.add_child(info)

	_rebuild()
	_update_camera()


func _rebuild() -> void:
	if creature != null:
		creature.queue_free()
	var root := _make_quad(front_loaded)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.45, 0.75)
	mat.roughness = 0.7
	creature = CreatureAssembler.build(root, Transform3D.IDENTITY, mat)
	add_child(creature)

	var r := CE.evaluate(root)
	cog_marker.position = r["cog"]
	_update_label(r)


func _update_label(r: Dictionary) -> void:
	var b: Dictionary = r["balance"]
	info.text = "sporespore — Tier 1 assembly smoke\n" \
		+ "mode: %s   (SPACE toggles legs)\n" % ("front-loaded" if front_loaded else "centered") \
		+ "parts: %d   mass: %.0f   body_radius: %.2f\n" % [creature.get_child_count(), float(r["total_mass"]), float(r["body_radius"])] \
		+ "balance.stable: %s   margin: %.2f   tip_risk: %s\n" % [str(b["stable"]), float(b["balance_margin"]), str(b.get("tip_risk", false))] \
		+ "probe: %s   debt_total: %.2f\n" % [str(r["probe"]["verdict"]), float(r["debt"]["debt_total"])] \
		+ str(r["reconciliation"]["message"]) + "\n\n" \
		+ "drag = orbit      wheel = zoom"


# --- genome builder (mirrors the golden test's quadruped) ---

func _def(part_type: StringName, density: float, extents: Vector3) -> PartDefinition:
	var d := PartDefinition.new()
	d.part_type = part_type
	d.density = density
	d.extents = extents
	return d

func _sock(pos: Vector3, hinge := Vector3.ZERO) -> SocketDef:
	var s := SocketDef.new()
	s.parent_attachment = Transform3D(Basis.IDENTITY, pos)
	s.hinge_axis = hinge
	return s

func _gene(defn: PartDefinition, tags: Array, socket: SocketDef = null) -> PartGene:
	var g := PartGene.new()
	g.definition = defn
	var t: Array[StringName] = []
	for x in tags:
		t.append(x)
	g.tags = t
	g.socket = socket
	return g

func _make_quad(front: bool) -> PartGene:
	var root := _gene(_def(&"box", 1000.0, Vector3(0.5, 0.2, 0.8)), [&"spine"])
	root.children.append(_gene(_def(&"box", 800.0, Vector3(0.30, 0.30, 0.30)), [&"heart"], _sock(Vector3.ZERO)))
	root.children.append(_gene(_def(&"box", 600.0, Vector3(0.18, 0.18, 0.18)), [&"brain"], _sock(Vector3(0.0, 0.1, 0.0))))
	var leg := _def(&"capsule", 1000.0, Vector3(0.1, 0.5, 0.1))
	var pos: Array
	if front:
		pos = [Vector3(-0.4,-0.2,0.3), Vector3(0.4,-0.2,0.3), Vector3(-0.4,-0.2,0.7), Vector3(0.4,-0.2,0.7)]
	else:
		pos = [Vector3(-0.4,-0.2,-0.6), Vector3(0.4,-0.2,-0.6), Vector3(-0.4,-0.2,0.6), Vector3(0.4,-0.2,0.6)]
	for p in pos:
		root.children.append(_gene(leg, [&"locomotor", &"ground_contact"], _sock(p, Vector3(1.0, 0.0, 0.0))))
	return root


# --- orbit camera ---

func _update_camera() -> void:
	cam_pitch = clampf(cam_pitch, -1.4, 1.4)
	cam_dist = clampf(cam_dist, 2.0, 20.0)
	var cam_basis := Basis.from_euler(Vector3(-cam_pitch, cam_yaw, 0.0))
	camera.position = cam_basis * Vector3(0.0, 0.0, cam_dist)
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam_dist -= 0.5
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_dist += 0.5
			_update_camera()
	elif event is InputEventMouseMotion and _dragging:
		cam_yaw -= event.relative.x * 0.01
		cam_pitch += event.relative.y * 0.01
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			front_loaded = not front_loaded
			_rebuild()
