extends Control

## Camera, diagnostics, and explicit operator-disturbance controls for the
## repeatable workbench physics sandbox. The camera is observation-only; the
## kick control is a labeled native-physics input with no evidence authority.

var _camera: Camera3D
var _torso: RigidBody3D
var _status: Label
var _disturbance_status: Label
var _pause_button: Button
var _camera_target := Vector3.ZERO
var _yaw := -0.92
var _pitch := 0.34
var _distance := 1.75
var _orbiting := false
var _elapsed_seconds := 0.0
var _initial_torso_position := Vector3.ZERO
var _link_guides: Array[Dictionary] = []
var _kick_count := 0


func configure(camera: Camera3D, torso: RigidBody3D, configuration: Dictionary) -> void:
	_camera = camera
	_torso = torso
	_initial_torso_position = torso.global_position
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 126.0)
	panel.custom_minimum_size = Vector2(720.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "LIVE GODOT/JOLT PHYSICS — DEVELOPMENT SANDBOX"
	title.add_theme_color_override("font_color", Color("55c99a"))
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var boundary := Label.new()
	boundary.text = (
		"Gravity + contacts + 9 free rigid bodies + 8 hinge motors\n"
		+ "Torso authority: none after release • acceptance authority: false\n"
		+ "Operator kick: real Jolt impulse • recovery authority: false\n"
		+ "Thin lower-leg rods: observer-only joint-link guides, not collision bodies"
	)
	boundary.add_theme_color_override("font_color", Color("dbeafe"))
	box.add_child(boundary)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color("8da2bd"))
	box.add_child(_status)
	_disturbance_status = Label.new()
	_disturbance_status.text = "No operator disturbance applied."
	_disturbance_status.add_theme_color_override("font_color", Color("f59e0b"))
	box.add_child(_disturbance_status)

	var configured := Label.new()
	configured.text = (
		"seed %d • terrain %d • authored friction %.3f • %s"
		% [
			int(configuration.get("random_seed", 0)),
			int(configuration.get("terrain_seed", 0)),
			float(configuration.get("authored_friction", 0.0)),
			String(configuration.get("terrain_kind", "flat")),
		]
	)
	configured.add_theme_color_override("font_color", Color("38bdf8"))
	box.add_child(configured)

	var actions := HBoxContainer.new()
	box.add_child(actions)
	_pause_button = Button.new()
	_pause_button.text = "Pause physics"
	_pause_button.pressed.connect(_toggle_pause)
	actions.add_child(_pause_button)
	var kick := Button.new()
	kick.text = "Kick torso right — 3.5 N·s"
	kick.tooltip_text = (
		"Applies a real world-right impulse to the Jolt torso. "
		+ "Remaining upright or getting up afterward is observed behavior, not a recovery claim."
	)
	kick.pressed.connect(_kick_torso)
	actions.add_child(kick)
	var reset := Button.new()
	reset.text = "Reset camera"
	reset.pressed.connect(_reset_camera)
	actions.add_child(reset)
	var help := Label.new()
	help.text = "Left-drag: orbit   Wheel: zoom   Close window: stop"
	help.add_theme_color_override("font_color", Color("8da2bd"))
	actions.add_child(help)

	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 52.0
	_camera.current = true
	_camera_target = _torso.global_position
	_build_link_guides()
	_update_camera()


func _process(delta: float) -> void:
	if _camera == null or _torso == null:
		return
	if not get_tree().paused:
		_elapsed_seconds += delta
	_camera_target = _camera_target.lerp(_torso.global_position, 0.085)
	_update_link_guides()
	_update_camera()
	var displacement := _torso.global_position - _initial_torso_position
	var torso_up_alignment := _torso.global_transform.basis.y.normalized().dot(Vector3.UP)
	_status.text = (
		"t %.2f s • torso height %.3f m • up alignment %.3f • speed %.3f m/s • displacement (%.3f, %.3f, %.3f) m"
		% [
			_elapsed_seconds,
			_torso.global_position.y,
			torso_up_alignment,
			_torso.linear_velocity.length(),
			displacement.x,
			displacement.y,
			displacement.z,
		]
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_orbiting = button.pressed
			accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(0.75, _distance * 0.88)
			accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(6.0, _distance * 1.14)
			accept_event()
	elif event is InputEventMouseMotion and _orbiting:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.screen_relative.x * 0.008
		_pitch = clampf(_pitch - motion.screen_relative.y * 0.008, -0.12, 1.18)
		accept_event()


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_pause_button.text = "Resume physics" if get_tree().paused else "Pause physics"


func _kick_torso() -> void:
	if _torso == null:
		return
	if get_tree().paused:
		_disturbance_status.text = "Kick not applied: resume physics first."
		return
	var impulse := Vector3(0.0, 0.0, 3.5)
	_torso.apply_central_impulse(impulse)
	_kick_count += 1
	_disturbance_status.text = (
		(
			"Jolt applied operator impulse #%d: (0.0, 0.0, 3.5) N·s at t=%.3f s. "
			+ "Watch the raw height/up-alignment values; self-righting is not established."
		)
		% [_kick_count, _elapsed_seconds]
	)


func _reset_camera() -> void:
	_yaw = -0.92
	_pitch = 0.34
	_distance = 1.75


func _update_camera() -> void:
	var horizontal := cos(_pitch)
	var offset := Vector3(sin(_yaw) * horizontal, sin(_pitch), cos(_yaw) * horizontal) * _distance
	_camera.global_position = _camera_target + offset
	_camera.look_at(_camera_target, Vector3.UP)


func _build_link_guides() -> void:
	var world := _torso.get_parent()
	for limb_id in ["front_left", "front_right", "rear_left", "rear_right"]:
		var upper := world.get_node_or_null("wave_gait_%s_upper" % limb_id) as RigidBody3D
		var foot := world.get_node_or_null("wave_gait_%s_foot" % limb_id) as RigidBody3D
		if upper == null or foot == null:
			continue
		var upper_half_length := 0.09
		var collision := upper.find_child("CollisionShape3D", true, false) as CollisionShape3D
		if collision != null and collision.shape is BoxShape3D:
			upper_half_length = (collision.shape as BoxShape3D).size.y * 0.5
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.018
		mesh.bottom_radius = 0.018
		mesh.height = 1.0
		mesh.radial_segments = 10
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("dbeafe")
		material.roughness = 0.75
		mesh.material = material
		var guide := MeshInstance3D.new()
		guide.name = "ObserverOnlyLinkGuide_%s" % limb_id
		guide.mesh = mesh
		world.add_child(guide)
		(
			_link_guides
			. append(
				{
					"upper": upper,
					"foot": foot,
					"guide": guide,
					"upper_half_length": upper_half_length,
				}
			)
		)
	_update_link_guides()


func _update_link_guides() -> void:
	for guide_value in _link_guides:
		var upper: RigidBody3D = guide_value["upper"]
		var foot: RigidBody3D = guide_value["foot"]
		var guide: MeshInstance3D = guide_value["guide"]
		var start := upper.to_global(Vector3.DOWN * float(guide_value["upper_half_length"]))
		var finish := foot.global_position
		var delta := finish - start
		var length := delta.length()
		if length <= 0.00001:
			guide.visible = false
			continue
		guide.visible = true
		var y_axis := delta / length
		var x_axis := y_axis.cross(Vector3.FORWARD)
		if x_axis.length_squared() < 0.0001:
			x_axis = y_axis.cross(Vector3.RIGHT)
		x_axis = x_axis.normalized()
		var z_axis := x_axis.cross(y_axis).normalized()
		(guide.mesh as CylinderMesh).height = length
		guide.global_transform = Transform3D(
			Basis(x_axis, y_axis, z_axis),
			start.lerp(finish, 0.5),
		)
