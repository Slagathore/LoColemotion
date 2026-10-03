class_name LocomotionExperimentPreview
extends Control
# gdlint: disable=max-line-length

## Interactive 3D setup inspector for the locomotion experiment workbench.
##
## This constructs meshes, lights, a camera, and an isolated render viewport.
## It deliberately creates no physics bodies, joints, collision shapes,
## controller, experiment worker, or retained evidence. The setup model is
## static. The workbench launches real physics through its separate
## live-sandbox control.

const BACKGROUND := Color("0b1020")
const TERRAIN := Color("243a34")
const TERRAIN_EDGE := Color("55c99a")
const BODY := Color("a78bfa")
const BODY_DRAFT := Color("f59e0b")
const LIMB := Color("ddd6fe")
const JOINT := Color("38bdf8")
const WARNING := Color("fb7185")
const GRID := Color("34445e")
const TEXT := Color("dbeafe")

var _configuration: Dictionary = {}
var _engine_label := ""
var _draft := false

var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _world_root: Node3D
var _content_root: Node3D
var _creature_root: Node3D
var _camera: Camera3D
var _state_label: Label
var _detail_label: Label

var _camera_target := Vector3(0.0, 0.85, 0.0)
var _camera_yaw := -0.82
var _camera_pitch := 0.36
var _camera_distance := 6.8
var _orbiting := false


func _ready() -> void:
	custom_minimum_size = Vector2(560.0, 390.0)
	clip_contents = true
	_build_viewport()
	_build_overlay()
	resized.connect(_sync_viewport_size)
	call_deferred("_sync_viewport_size")


func set_configuration(configuration: Dictionary, engine_label: String, draft: bool) -> void:
	_configuration = configuration.duplicate(true)
	_engine_label = engine_label
	_draft = draft
	if is_node_ready():
		_rebuild_scene()


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "Interactive3DViewport"
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_target = true
	_viewport_container.gui_input.connect(_on_viewport_gui_input)
	add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.name = "RenderOnlyWorld"
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport_container.add_child(_viewport)

	_world_root = Node3D.new()
	_world_root.name = "RenderOnlyScene"
	_viewport.add_child(_world_root)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9fb7d5")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	_world_root.add_child(environment_node)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	key_light.light_color = Color("dbeafe")
	key_light.light_energy = 1.45
	key_light.shadow_enabled = true
	_world_root.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.5, 3.8, 3.0)
	fill_light.omni_range = 10.0
	fill_light.light_color = Color("a78bfa")
	fill_light.light_energy = 2.0
	_world_root.add_child(fill_light)

	_camera = Camera3D.new()
	_camera.name = "OrbitCamera"
	_camera.fov = 49.0
	_camera.current = true
	_world_root.add_child(_camera)

	_content_root = Node3D.new()
	_content_root.name = "ConfigurationGeometry"
	_world_root.add_child(_content_root)
	_update_camera()


func _build_overlay() -> void:
	var top_margin := MarginContainer.new()
	top_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	top_margin.add_theme_constant_override("margin_top", 12)
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_margin)
	var top_row := HBoxContainer.new()
	top_margin.add_child(top_row)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(labels)
	_state_label = Label.new()
	_state_label.add_theme_font_size_override("font_size", 17)
	labels.add_child(_state_label)
	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 13)
	_detail_label.add_theme_color_override("font_color", TEXT)
	labels.add_child(_detail_label)


func _sync_viewport_size() -> void:
	if _viewport == null:
		return
	if _viewport_container != null and _viewport_container.stretch:
		return
	_viewport.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))


func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_orbiting = button.pressed
			accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(2.4, _camera_distance * 0.88)
			_update_camera()
			accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(18.0, _camera_distance * 1.14)
			_update_camera()
			accept_event()
	elif event is InputEventMouseMotion and _orbiting:
		var motion := event as InputEventMouseMotion
		_camera_yaw -= motion.screen_relative.x * 0.008
		_camera_pitch = clampf(_camera_pitch - motion.screen_relative.y * 0.008, -0.18, 1.28)
		_update_camera()
		accept_event()


func _reset_camera() -> void:
	_camera_yaw = -0.82
	_camera_pitch = 0.36
	_camera_distance = 6.8
	_update_camera()


func _update_camera() -> void:
	if _camera == null:
		return
	var horizontal := cos(_camera_pitch)
	var offset := (
		Vector3(sin(_camera_yaw) * horizontal, sin(_camera_pitch), cos(_camera_yaw) * horizontal)
		* _camera_distance
	)
	_camera.position = _camera_target + offset
	_camera.look_at(_camera_target, Vector3.UP)


func _rebuild_scene() -> void:
	for child in _content_root.get_children():
		_content_root.remove_child(child)
		child.queue_free()
	if _configuration.is_empty():
		return
	_build_terrain()
	_build_creature()
	_build_heading_and_disturbance()
	_refresh_overlay()


func _build_terrain() -> void:
	var terrain_root := Node3D.new()
	terrain_root.name = "Terrain"
	_content_root.add_child(terrain_root)
	var terrain_kind := String(_configuration.get("terrain_kind", "flat"))
	var slope := float(_configuration.get("slope_degrees", 0.0))
	var roughness := float(_configuration.get("terrain_roughness", 0.0))
	var obstacle_height := float(_configuration.get("obstacle_height_m", 0.0))
	var seed_value := int(_configuration.get("terrain_seed", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	match terrain_kind:
		"rough":
			for x_index in 9:
				for z_index in 7:
					var height := 0.12 + rng.randf_range(0.0, maxf(0.02, roughness * 0.55))
					_add_box(
						terrain_root,
						Vector3(1.12, height, 1.12),
						Vector3(
							float(x_index - 4) * 1.12,
							-0.12 + height * 0.5,
							float(z_index - 3) * 1.12
						),
						TERRAIN
					)
		"steps":
			for index in 7:
				var height := 0.10 + float(index % 3) * maxf(0.08, obstacle_height)
				_add_box(
					terrain_root,
					Vector3(1.45, height, 7.8),
					Vector3(float(index - 3) * 1.45, -0.12 + height * 0.5, 0.0),
					TERRAIN
				)
		"slope":
			var slope_surface := _add_box(
				terrain_root, Vector3(10.5, 0.18, 8.0), Vector3(0.0, -0.12, 0.0), TERRAIN
			)
			slope_surface.rotation_degrees.z = slope
		_:
			var flat_surface := _add_box(
				terrain_root, Vector3(10.5, 0.18, 8.0), Vector3(0.0, -0.12, 0.0), TERRAIN
			)
			flat_surface.rotation_degrees.z = slope

	if obstacle_height > 0.001 and terrain_kind != "steps":
		_add_box(
			terrain_root,
			Vector3(0.50, obstacle_height, 2.4),
			Vector3(2.25, obstacle_height * 0.5, 0.0),
			WARNING
		)
	_add_grid(terrain_root)


func _build_creature() -> void:
	_creature_root = Node3D.new()
	_creature_root.name = "Creature"
	_content_root.add_child(_creature_root)
	var limb_count := int(_configuration.get("limb_count", 4))
	var mode := String(_configuration.get("locomotion_mode", "balanced_wave_walk"))
	if limb_count == 0 or mode == "serpentine":
		_build_serpentine()
	elif mode == "radial_pogo":
		_build_radial_pogo(maxi(3, limb_count))
	else:
		_build_legged_creature(limb_count)


func _build_legged_creature(limb_count: int) -> void:
	var length_scale := float(_configuration.get("torso_length_scale", 1.0))
	var width_scale := float(_configuration.get("torso_width_scale", 1.0))
	var hip_span := float(_configuration.get("hip_span_scale", 1.0))
	var upper_fraction := float(_configuration.get("upper_length_fraction", 0.5142857))
	var foot_scale := float(_configuration.get("foot_radius_scale", 1.0))
	var body_size := Vector3(2.05 * length_scale, 0.52 * width_scale, 0.92 * width_scale)
	var leg_height := 1.22 * maxf(0.65, length_scale)
	var body_y := leg_height + body_size.y * 0.42
	_add_box(_creature_root, body_size, Vector3(0.0, body_y, 0.0), BODY_DRAFT if _draft else BODY)

	var visible_limbs := clampi(limb_count, 1, 16)
	var pair_count := maxi(1, int(ceil(float(visible_limbs) / 2.0)))
	for index in visible_limbs:
		var pair_index := index / 2
		var t := 0.5 if pair_count == 1 else float(pair_index) / float(pair_count - 1)
		var x := lerpf(-body_size.x * 0.42, body_size.x * 0.42, t)
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := side * body_size.z * 0.49 * hip_span
		var hip := Vector3(x, body_y - body_size.y * 0.30, z)
		var foot := Vector3(x + (0.18 if pair_index % 2 == 0 else -0.14), 0.08, z * 1.26)
		var knee := hip.lerp(foot, clampf(upper_fraction, 0.25, 0.78))
		knee.x += 0.22 * (-1.0 if pair_index % 2 == 0 else 1.0)
		var limb_root := Node3D.new()
		limb_root.name = "Limb_%02d" % index
		limb_root.position = hip
		_creature_root.add_child(limb_root)
		var knee_local := knee - hip
		var foot_local := foot - hip
		_add_segment(limb_root, Vector3.ZERO, knee_local, 0.055, LIMB)
		_add_segment(limb_root, knee_local, foot_local, 0.050, LIMB)
		_add_sphere(limb_root, 0.095, Vector3.ZERO, JOINT)
		_add_sphere(limb_root, 0.082, knee_local, BODY_DRAFT if _draft else BODY)
		_add_cylinder(limb_root, 0.105 * foot_scale, 0.055, foot_local, JOINT)


func _build_serpentine() -> void:
	var prior := Vector3.ZERO
	for index in 15:
		var point := Vector3(
			float(index - 7) * 0.30,
			0.31 + 0.035 * cos(float(index)),
			sin(float(index) * 0.72) * 0.42
		)
		_add_sphere(_creature_root, 0.20, point, BODY_DRAFT if _draft else BODY)
		if index > 0:
			_add_segment(_creature_root, prior, point, 0.13, LIMB)
		prior = point


func _build_radial_pogo(limb_count: int) -> void:
	var center := Vector3(0.0, 1.35, 0.0)
	_add_sphere(_creature_root, 0.47, center, BODY_DRAFT if _draft else BODY)
	var visible_limbs := clampi(limb_count, 3, 16)
	for index in visible_limbs:
		var angle := TAU * float(index) / float(visible_limbs)
		var hip := center + Vector3(cos(angle), -0.12, sin(angle)) * 0.40
		var foot := Vector3(cos(angle) * 1.22, 0.08, sin(angle) * 1.22)
		var knee := hip.lerp(foot, 0.52) + Vector3(0.0, 0.15, 0.0)
		_add_segment(_creature_root, hip, knee, 0.055, LIMB)
		_add_segment(_creature_root, knee, foot, 0.050, LIMB)
		_add_sphere(_creature_root, 0.08, knee, JOINT)


func _build_heading_and_disturbance() -> void:
	_add_segment(_content_root, Vector3(0.0, 1.95, 0.0), Vector3(1.55, 1.95, 0.0), 0.028, JOINT)
	_add_cone(_content_root, 0.11, 0.30, Vector3(1.68, 1.95, 0.0), Vector3(0.0, 0.0, -90.0), JOINT)
	if bool(_configuration.get("external_push_enabled", false)):
		var strength := clampf(float(_configuration.get("push_impulse_ns", 0.0)) / 50.0, 0.15, 1.0)
		var start := Vector3(2.6 + strength, 1.25, 0.0)
		var finish := Vector3(1.0, 1.25, 0.0)
		_add_segment(_content_root, start, finish, 0.055, WARNING)
		_add_cone(_content_root, 0.15, 0.35, finish, Vector3(0.0, 0.0, 90.0), WARNING)


func _refresh_overlay() -> void:
	var state := "EXPLORATION DRAFT" if _draft else "FROZEN PRESET VIEW"
	_state_label.text = "%s  •  3D SETUP INSPECTOR  •  RENDER ONLY" % state
	_state_label.add_theme_color_override("font_color", BODY_DRAFT if _draft else TERRAIN_EDGE)
	var flags: Array[String] = []
	if bool(_configuration.get("external_push_enabled", false)):
		flags.append("push %.1f N·s" % float(_configuration.get("push_impulse_ns", 0.0)))
	if bool(_configuration.get("sensor_noise_enabled", false)):
		flags.append("sensor noise")
	if bool(_configuration.get("sensor_latency_enabled", false)):
		flags.append("latency %.1f ms" % float(_configuration.get("sensor_latency_ms", 0.0)))
	var suffix := "" if flags.is_empty() else "  •  " + ", ".join(flags)
	_detail_label.text = (
		"%s  •  seed %d  •  terrain %d  •  μ %.2f%s\nLeft-drag: orbit  •  wheel: zoom  •  static setup only"
		% [
			_engine_label,
			int(_configuration.get("random_seed", 0)),
			int(_configuration.get("terrain_seed", 0)),
			float(_configuration.get("authored_friction", 0.0)),
			suffix
		]
	)


func _add_grid(parent: Node3D) -> void:
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, _material(GRID, true))
	for index in range(-5, 6):
		var value := float(index)
		immediate.surface_add_vertex(Vector3(value, 0.015, -4.0))
		immediate.surface_add_vertex(Vector3(value, 0.015, 4.0))
		immediate.surface_add_vertex(Vector3(-5.0, 0.015, value * 0.8))
		immediate.surface_add_vertex(Vector3(5.0, 0.015, value * 0.8))
	immediate.surface_end()
	var instance := MeshInstance3D.new()
	instance.name = "ScaleGrid"
	instance.mesh = immediate
	parent.add_child(instance)


func _add_box(parent: Node3D, box_size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, radius: float, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _add_cylinder(
	parent: Node3D, radius: float, height: float, position: Vector3, color: Color
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _add_cone(
	parent: Node3D,
	radius: float,
	height: float,
	position: Vector3,
	rotation_degrees: Vector3,
	color: Color
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.rotation_degrees = rotation_degrees
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _add_segment(
	parent: Node3D, start: Vector3, finish: Vector3, radius: float, color: Color
) -> MeshInstance3D:
	var delta := finish - start
	var length := delta.length()
	if length <= 0.00001:
		return _add_sphere(parent, radius, start, color)
	var y_axis := delta / length
	var x_axis := y_axis.cross(Vector3.FORWARD)
	if x_axis.length_squared() < 0.0001:
		x_axis = y_axis.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = Transform3D(Basis(x_axis, y_axis, z_axis), start.lerp(finish, 0.5))
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.68
	material.metallic = 0.06
	material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	)
	return material
