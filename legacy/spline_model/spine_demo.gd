extends Node3D

## M1 demo — build a swept-tube creature body from a spine and reshape it live.
## Run this scene (F5). The whole scene (camera, light, body, UI) is built in
## code so the .tscn stays trivial. On-screen text lists the controls.

var spine: CreatureSpine
var body: MeshInstance3D
var info_label: Label

# Editable spine parameters.
var segments := 8
var body_length := 4.0
var max_radius := 0.6

# Orbit-camera state.
var cam_pivot: Node3D
var camera: Camera3D
var cam_yaw := 0.6
var cam_pitch := 0.35
var cam_dist := 7.0
var _dragging := false


func _ready() -> void:
	# Key light.
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -40.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	# Background + ambient fill.
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.10, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.32, 0.38)
	env.ambient_light_energy = 0.6
	world_env.environment = env
	add_child(world_env)

	# Orbit-camera rig (camera orbits the origin via the pivot).
	cam_pivot = Node3D.new()
	add_child(cam_pivot)
	camera = Camera3D.new()
	cam_pivot.add_child(camera)

	# Body mesh node + a simple material (double-sided so winding never hides it).
	body = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.45, 0.75)
	mat.roughness = 0.7
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	body.material_override = mat
	add_child(body)

	# On-screen controls/info, on its own canvas layer so it draws on top.
	var ui := CanvasLayer.new()
	add_child(ui)
	info_label = Label.new()
	info_label.position = Vector2(16.0, 12.0)
	info_label.add_theme_color_override("font_color", Color.WHITE)
	ui.add_child(info_label)

	_rebuild()
	_update_camera()


func _rebuild() -> void:
	spine = CreatureSpine.make_default(segments, body_length, max_radius)
	body.mesh = BodyMeshBuilder.build(spine, 18, 56)
	_update_label()


func _update_label() -> void:
	info_label.text = "LoColemotion: M1 spine / body demo\n" \
		+ "segments: %d   length: %.1f   max radius: %.2f\n\n" % [segments, body_length, max_radius] \
		+ "[Up/Down]   add / remove a segment\n" \
		+ "[Left/Right]   shorten / lengthen body\n" \
		+ "[ - / = ]   thinner / fatter\n" \
		+ "[R]   reset      drag = orbit      wheel = zoom"


func _update_camera() -> void:
	cam_pitch = clampf(cam_pitch, -1.4, 1.4)
	cam_dist = clampf(cam_dist, 2.0, 25.0)
	var basis := Basis.from_euler(Vector3(-cam_pitch, cam_yaw, 0.0))
	camera.position = basis * Vector3(0.0, 0.0, cam_dist)
	camera.look_at(Vector3.ZERO, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam_dist -= 0.6
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_dist += 0.6
			_update_camera()
	elif event is InputEventMouseMotion and _dragging:
		cam_yaw -= event.relative.x * 0.01
		cam_pitch += event.relative.y * 0.01
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP:
				segments = mini(segments + 1, 40)
				_rebuild()
			KEY_DOWN:
				segments = maxi(segments - 1, 2)
				_rebuild()
			KEY_RIGHT:
				body_length = minf(body_length + 0.5, 20.0)
				_rebuild()
			KEY_LEFT:
				body_length = maxf(body_length - 0.5, 1.0)
				_rebuild()
			KEY_EQUAL:
				max_radius = minf(max_radius + 0.05, 2.0)
				_rebuild()
			KEY_MINUS:
				max_radius = maxf(max_radius - 0.05, 0.1)
				_rebuild()
			KEY_R:
				segments = 8
				body_length = 4.0
				max_radius = 0.6
				_rebuild()
