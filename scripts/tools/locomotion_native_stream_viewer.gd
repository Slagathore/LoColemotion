extends SceneTree
# gdlint: disable=max-line-length

## Real-time renderer and operator surface for one native Explorer worker.
##
## Rendering consumes native post-step poses. It never authors body motion or
## writes transforms back to Rapier or MuJoCo.

const PROTOCOL_VERSION := "sporespore_live_explorer_protocol_v1"
const PORT_START := 43120
const PORT_END := 43220

var _engine_id := ""
var _source_commit := ""
var _session_id := ""
var _start_gate_path := ""
var _ready_receipt_path := ""
var _ready_to_start := false
var _start_sent := false
var _server := TCPServer.new()
var _peer: StreamPeerTCP
var _worker_pid := 0
var _incoming := ""
var _current_frame := 0
var _engine_version := "connecting"
var _initial_torso_x := NAN
var _torso_position := Vector3.ZERO
var _torso_up_alignment := 1.0
var _torso_ground_contact := false
var _foot_contact_count := 0
var _last_kick_applied_frame := -1
var _completed := false
var _body_nodes: Dictionary = {}
var _world: Node3D
var _camera: Camera3D
var _status: Label
var _provenance: Label
var _kick_button: Button
var _last_event := "Waiting for native worker handshake."


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := _parse_arguments(OS.get_cmdline_user_args())
	_build_surface()
	if bool(arguments.get("self_test", false)):
		_run_self_test()
		return
	_engine_id = String(arguments.get("engine_id", ""))
	_source_commit = String(arguments.get("source_commit", ""))
	_session_id = String(arguments.get("session_id", ""))
	_start_gate_path = String(arguments.get("start_gate", ""))
	if not ["rapier_parry", "mujoco"].has(_engine_id):
		_fail("LIVE_EXPLORER_VIEWER_ENGINE_INVALID")
		return
	if _source_commit.length() != 40 or not _source_commit.is_valid_hex_number(false):
		_fail("LIVE_EXPLORER_VIEWER_SOURCE_COMMIT_INVALID")
		return
	if _session_id.is_empty():
		_fail("LIVE_EXPLORER_VIEWER_SESSION_MISSING")
		return
	if not _start_gate_path.is_empty():
		var runtime_root := ProjectSettings.globalize_path("res://.tmp/workbench").replace("\\", "/")
		_start_gate_path = ProjectSettings.globalize_path(_start_gate_path).replace("\\", "/")
		if not _start_gate_path.begins_with(runtime_root.trim_suffix("/") + "/"):
			_fail("LIVE_EXPLORER_VIEWER_START_GATE_PATH_INVALID")
			return
		_ready_receipt_path = "%s.%s.ready.json" % [_start_gate_path, _engine_id]
	root.title = "SporeSpore — %s native live physics" % _engine_label()
	var port := _listen_on_available_port()
	if port <= 0:
		_fail("LIVE_EXPLORER_VIEWER_LISTEN_FAILED")
		return
	_worker_pid = _launch_worker(port)
	if _worker_pid <= 0:
		_fail("LIVE_EXPLORER_VIEWER_WORKER_LAUNCH_FAILED")
		return
	_last_event = "Native worker %d started; waiting for engine hello." % _worker_pid
	_update_labels()


func _parse_arguments(values: PackedStringArray) -> Dictionary:
	var parsed := {"self_test": values.has("--self-test")}
	var index := 0
	while index < values.size():
		var argument := String(values[index])
		if ["--engine", "--source-commit", "--session", "--start-gate"].has(argument):
			if index + 1 >= values.size():
				return parsed
			var key := argument.trim_prefix("--").replace("-", "_")
			parsed[key] = String(values[index + 1])
			index += 2
		else:
			index += 1
	return parsed


func _build_surface() -> void:
	root.size = Vector2i(900, 620)
	root.close_requested.connect(quit)
	_world = Node3D.new()
	_world.name = "NativePhysicsWorldView"
	root.add_child(_world)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07101d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9d8ff")
	environment.ambient_light_energy = 0.55
	environment_node.environment = environment
	_world.add_child(environment_node)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	_world.add_child(light)

	var ground := MeshInstance3D.new()
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(20.0, 0.08, 8.0)
	ground.mesh = ground_mesh
	ground.position = Vector3(4.0, -0.04, 0.0)
	ground.material_override = _material(Color("17263b"), 0.82)
	_world.add_child(ground)

	_camera = Camera3D.new()
	_camera.position = Vector3(2.6, 1.45, 3.2)
	_camera.fov = 52.0
	_world.add_child(_camera)
	_camera.look_at(Vector3(0.6, 0.35, 0.0), Vector3.UP)

	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var shade := ColorRect.new()
	shade.position = Vector2(16.0, 16.0)
	shade.size = Vector2(868.0, 132.0)
	shade.color = Color(0.025, 0.055, 0.10, 0.91)
	canvas.add_child(shade)

	_provenance = Label.new()
	_provenance.position = Vector2(34.0, 28.0)
	_provenance.size = Vector2(830.0, 30.0)
	_provenance.add_theme_font_size_override("font_size", 19)
	_provenance.add_theme_color_override("font_color", Color("55c99a"))
	canvas.add_child(_provenance)

	_status = Label.new()
	_status.position = Vector2(34.0, 60.0)
	_status.size = Vector2(830.0, 52.0)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("c6d4e8"))
	canvas.add_child(_status)

	_kick_button = Button.new()
	_kick_button.position = Vector2(34.0, 108.0)
	_kick_button.size = Vector2(260.0, 34.0)
	_kick_button.text = "Kick torso right — 3.5 N·s"
	_kick_button.disabled = true
	_kick_button.tooltip_text = (
		"Schedules a native lateral torso impulse 30 simulation frames ahead. "
		+ "This is an interactive development disturbance, not proof of recovery."
	)
	_kick_button.pressed.connect(_on_kick_pressed)
	canvas.add_child(_kick_button)
	_update_labels()


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.08
	return material


func _listen_on_available_port() -> int:
	for port in range(PORT_START, PORT_END):
		if _server.listen(port, "127.0.0.1") == OK:
			return port
	return -1


func _launch_worker(port: int) -> int:
	var address := "127.0.0.1:%d" % port
	if _engine_id == "rapier_parry":
		var release_worker := ProjectSettings.globalize_path(
			"res://sdk/target/release/locomotion_live_explorer.exe"
		)
		var debug_worker := ProjectSettings.globalize_path(
			"res://sdk/target/debug/locomotion_live_explorer.exe"
		)
		var worker := release_worker if FileAccess.file_exists(release_worker) else debug_worker
		if not FileAccess.file_exists(worker):
			_last_event = "Rapier live worker is not built. Run the native preflight first."
			return 0
		var rapier_arguments := PackedStringArray(
			[
				"--connect",
				address,
				"--session",
				_session_id,
				"--source-commit",
				_source_commit,
				"--realtime",
			]
		)
		if not _start_gate_path.is_empty():
			rapier_arguments.append("--wait-for-start")
		return OS.create_process(worker, rapier_arguments, false)
	var python := ProjectSettings.globalize_path(
		"res://sdk/adapters/mujoco/.venv/Scripts/python.exe"
	)
	var package_root := ProjectSettings.globalize_path("res://sdk/adapters/mujoco")
	if not FileAccess.file_exists(python):
		_last_event = "MuJoCo virtual-environment Python is missing."
		return 0
	var previous_python_path := OS.get_environment("PYTHONPATH")
	OS.set_environment("PYTHONPATH", package_root)
	var mujoco_arguments := PackedStringArray(
		[
			"-m",
			"sporespore_mujoco_adapter.live_explorer_worker",
			"--connect",
			address,
			"--session",
			_session_id,
			"--source-commit",
			_source_commit,
			"--realtime",
		]
	)
	if not _start_gate_path.is_empty():
		mujoco_arguments.append("--wait-for-start")
	var pid := OS.create_process(python, mujoco_arguments, false)
	OS.set_environment("PYTHONPATH", previous_python_path)
	return pid


func _process(_delta: float) -> bool:
	if _peer == null and _server.is_connection_available():
		_peer = _server.take_connection()
		_last_event = "Loopback transport connected; awaiting native engine identity."
	if _peer != null and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var available := _peer.get_available_bytes()
		if available > 0:
			_incoming += _peer.get_utf8_string(available)
			_drain_messages()
	if _worker_pid > 0 and not OS.is_process_running(_worker_pid) and not _completed:
		var exit_code := OS.get_process_exit_code(_worker_pid)
		_last_event = "Native worker exited before completion: %d" % exit_code
		_completed = true
		_kick_button.disabled = true
		if not _start_gate_path.is_empty() and not _start_sent:
			quit(1)
			return false
	if _ready_to_start and not _start_sent and FileAccess.file_exists(_start_gate_path):
		_send_start_command()
	if not is_nan(_torso_position.x):
		var target_camera := _torso_position + Vector3(2.6, 1.05, 3.2)
		_camera.position = _camera.position.lerp(target_camera, 0.08)
		_camera.look_at(_torso_position + Vector3(0.15, 0.10, 0.0), Vector3.UP)
	_update_labels()
	return false


func _drain_messages() -> void:
	while true:
		var newline := _incoming.find("\n")
		if newline < 0:
			return
		var line := _incoming.substr(0, newline)
		_incoming = _incoming.substr(newline + 1)
		if line.strip_edges().is_empty():
			continue
		var value: Variant = JSON.parse_string(line)
		if not value is Dictionary:
			_fail("LIVE_EXPLORER_VIEWER_MESSAGE_NOT_OBJECT")
			return
		_handle_message(value as Dictionary)


func _handle_message(message: Dictionary) -> void:
	if String(message.get("schema_version", "")) != PROTOCOL_VERSION:
		_fail("LIVE_EXPLORER_VIEWER_PROTOCOL_MISMATCH")
		return
	if String(message.get("session_id", "")) != _session_id:
		_fail("LIVE_EXPLORER_VIEWER_SESSION_MISMATCH")
		return
	if String(message.get("engine_id", "")) != _engine_id:
		_fail("LIVE_EXPLORER_VIEWER_ENGINE_MISMATCH")
		return
	var message_type := String(message.get("message_type", ""))
	match message_type:
		"hello":
			if not bool(message.get("native_physics", false)) or bool(message.get("replay", true)):
				_fail("LIVE_EXPLORER_VIEWER_PROVENANCE_INVALID")
				return
			if String(message.get("source_commit", "")) != _source_commit:
				_fail("LIVE_EXPLORER_VIEWER_SOURCE_COMMIT_MISMATCH")
				return
			_engine_version = String(message.get("engine_version", "unknown"))
			if message.has("scene"):
				_build_native_bodies(message["scene"])
			_last_event = (
				"Verified native hello; running zero-world and pre-step preparation."
				if not _start_gate_path.is_empty()
				else "Verified native hello; waiting for the first physical frame."
			)
		"scene":
			_build_native_bodies(message.get("scene", {}))
		"frame":
			if not bool(message.get("native_physics", false)) or bool(message.get("replay", true)):
				_fail("LIVE_EXPLORER_VIEWER_FRAME_PROVENANCE_INVALID")
				return
			_apply_native_frame(message)
		"command_scheduled":
			_last_event = (
				"Native worker scheduled %s for physical frame %d."
				% [String(message.get("command_id", "unknown")), int(message.get("apply_at_frame", -1))]
			)
		"ready_to_start":
			if _start_gate_path.is_empty():
				_fail("LIVE_EXPLORER_VIEWER_UNEXPECTED_START_GATE")
				return
			_ready_to_start = true
			if not _write_ready_receipt():
				_fail("LIVE_EXPLORER_VIEWER_READY_RECEIPT_FAILED")
				return
			_last_event = "Native preflight and settle completed; waiting at the shared start gate."
		"started":
			_last_event = "Shared start gate accepted; native stepping is live."
		"completed":
			_completed = true
			_kick_button.disabled = true
			_last_event = (
				(
					"Native development run complete: walker gates=%s, frames=%d. "
					+ "A disturbed run does not establish fall recovery."
				)
				% [String(message.get("outcome", "unknown")), int(message.get("frame_count", 0))]
			)
		"error":
			_fail(String(message.get("error", "LIVE_EXPLORER_NATIVE_ERROR")))
		_:
			_fail("LIVE_EXPLORER_VIEWER_MESSAGE_TYPE_INVALID:%s" % message_type)


func _build_native_bodies(scene: Variant) -> void:
	if not scene is Dictionary:
		_fail("LIVE_EXPLORER_VIEWER_SCENE_INVALID")
		return
	var morphology: Variant = (scene as Dictionary).get("morphology_spec", {})
	if not morphology is Dictionary:
		_fail("LIVE_EXPLORER_VIEWER_MORPHOLOGY_INVALID")
		return
	for body_value in (morphology as Dictionary).get("bodies", []):
		if not body_value is Dictionary:
			continue
		var body := body_value as Dictionary
		var body_id := String(body.get("body_id", ""))
		if body_id.is_empty() or _body_nodes.has(body_id):
			continue
		var collision: Dictionary = body.get("collision", {})
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "native_%s" % body_id
		match String(collision.get("kind", "")):
			"box":
				var box := BoxMesh.new()
				box.size = _vector(collision.get("size_m", {}))
				mesh_instance.mesh = box
			"capsule":
				var capsule := CapsuleMesh.new()
				capsule.radius = float(collision.get("radius_m", 0.04))
				capsule.height = float(collision.get("length_m", 0.1)) + 2.0 * capsule.radius
				mesh_instance.mesh = capsule
			"sphere":
				var sphere := SphereMesh.new()
				sphere.radius = float(collision.get("radius_m", 0.04))
				sphere.height = sphere.radius * 2.0
				mesh_instance.mesh = sphere
			_:
				_fail("LIVE_EXPLORER_VIEWER_COLLISION_KIND_INVALID:%s" % body_id)
				return
		mesh_instance.material_override = _material(
			Color("55c99a") if body_id == "torso" else Color("7fb7ff"), 0.48
		)
		_world.add_child(mesh_instance)
		_body_nodes[body_id] = mesh_instance


func _apply_native_frame(frame: Dictionary) -> void:
	_current_frame = int(frame.get("frame_index", 0))
	for body_value in frame.get("ordered_bodies", []):
		var body: Dictionary = body_value
		var body_id := String(body.get("body_id", ""))
		var node := _body_nodes.get(body_id) as MeshInstance3D
		if node == null:
			continue
		var orientation: Dictionary = body.get("orientation_xyzw", {})
		var native_basis := Basis(
			Quaternion(
				float(orientation.get("x", 0.0)),
				float(orientation.get("y", 0.0)),
				float(orientation.get("z", 0.0)),
				float(orientation.get("w", 1.0)),
			)
		)
		node.transform = Transform3D(
			native_basis,
			_vector(body.get("position_m", {})),
		)
		if body_id == "torso":
			_torso_position = node.position
			_torso_up_alignment = native_basis.y.normalized().dot(Vector3.UP)
			if is_nan(_initial_torso_x):
				_initial_torso_x = _torso_position.x
	_torso_ground_contact = false
	_foot_contact_count = 0
	for contact_value in frame.get("ordered_body_ground_contacts", []):
		var contact: Dictionary = contact_value
		if not bool(contact.get("ground_contact", contact.get("present", false))):
			continue
		var contact_body_id := String(contact.get("body_id", ""))
		if contact_body_id == "torso":
			_torso_ground_contact = true
		elif contact_body_id.ends_with("_foot"):
			_foot_contact_count += 1
	var applied: Array = frame.get("applied_impulses", [])
	if not applied.is_empty():
		_last_kick_applied_frame = _current_frame
		_last_event = (
			(
				"Native disturbance applied at frame %d via %s. "
				+ "Post-kick state below is raw observation; recovery is not presumed."
			)
			% [_current_frame, String((applied[0] as Dictionary).get("native_application", "unknown"))]
		)
	_kick_button.disabled = _completed or _peer == null
	var sim_time := float(frame.get("simulation_time_s", 0.0))
	var wall_time := float(frame.get("physics_wall_time_s", 0.0))
	var ratio := sim_time / wall_time if wall_time > 0.0 else 0.0
	root.title = "SporeSpore — %s LIVE — %.2fx realtime" % [_engine_label(), ratio]


func _on_kick_pressed() -> void:
	if _peer == null or _current_frame <= 0 or _completed:
		return
	var command := _impulse_command(_current_frame + 30)
	var packet := (JSON.stringify(command) + "\n").to_utf8_buffer()
	if _peer.put_data(packet) != OK:
		_fail("LIVE_EXPLORER_VIEWER_IMPULSE_SEND_FAILED")
		return
	_kick_button.disabled = true
	_last_event = (
		"Requested a 3.5 N·s canonical rightward torso kick for frame %d."
		% int(command["apply_at_frame"])
	)


func _impulse_command(apply_at_frame: int) -> Dictionary:
	return {
		"schema_version": PROTOCOL_VERSION,
		"message_type": "apply_impulse",
		"session_id": _session_id,
		"command_id": "viewer_kick_%d" % apply_at_frame,
		"target_body_id": "torso",
		"apply_at_frame": apply_at_frame,
		"impulse_n_s": {"x": 0.0, "y": 0.0, "z": 3.5},
	}


func _send_start_command() -> void:
	if _peer == null or not _ready_to_start or _start_sent:
		return
	var command := {
		"schema_version": PROTOCOL_VERSION,
		"message_type": "start",
		"session_id": _session_id,
		"command_id": "coordinated_start",
	}
	if _peer.put_data((JSON.stringify(command) + "\n").to_utf8_buffer()) != OK:
		_fail("LIVE_EXPLORER_VIEWER_START_SEND_FAILED")
		return
	_start_sent = true
	_last_event = "Shared start released; waiting for native start receipt."


func _write_ready_receipt() -> bool:
	if _ready_receipt_path.is_empty():
		return false
	var file := FileAccess.open(_ready_receipt_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(
		JSON.stringify(
			{
				"schema_version": PROTOCOL_VERSION,
				"engine_id": _engine_id,
				"session_id": _session_id,
				"source_commit": _source_commit,
				"ready_to_start": true,
				"scientific_evidence_authority": false,
			}
		)
	)
	file.close()
	return true


func _vector(value: Variant) -> Vector3:
	if not value is Dictionary:
		return Vector3.ZERO
	return Vector3(
		float((value as Dictionary).get("x", 0.0)),
		float((value as Dictionary).get("y", 0.0)),
		float((value as Dictionary).get("z", 0.0)),
	)


func _engine_label() -> String:
	return "Rapier / Parry" if _engine_id == "rapier_parry" else "MuJoCo"


func _update_labels() -> void:
	if _provenance == null or _status == null:
		return
	var displacement := 0.0 if is_nan(_initial_torso_x) else _torso_position.x - _initial_torso_x
	_provenance.text = (
		"LIVE NATIVE PHYSICS • %s %s • source %s • replay=false • evidence authority=false"
		% [_engine_label(), _engine_version, _source_commit.substr(0, 12)]
	)
	_status.text = (
		(
			"Frame %d • forward displacement %.3f m • torso height %.3f m • up alignment %.3f\n"
			+ "Contacts: feet %d/4 • torso %s • last kick frame %s\n%s"
		)
		% [
			_current_frame,
			displacement,
			_torso_position.y,
			_torso_up_alignment,
			_foot_contact_count,
			str(_torso_ground_contact),
			"none" if _last_kick_applied_frame < 0 else str(_last_kick_applied_frame),
			_last_event,
		]
	)


func _run_self_test() -> void:
	_engine_id = "rapier_parry"
	_session_id = "viewer_self_test"
	_build_native_bodies(
		{
			"morphology_spec": {
				"bodies": [
					{
						"body_id": "torso",
						"collision": {
							"kind": "box",
							"size_m": {"x": 0.5, "y": 0.12, "z": 0.32},
						},
					}
				]
			}
		}
	)
	_apply_native_frame(
		{
			"frame_index": 1,
			"simulation_time_s": 1.0 / 120.0,
			"physics_wall_time_s": 1.0 / 120.0,
			"ordered_bodies": [
				{
					"body_id": "torso",
					"position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
					"orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
				}
			],
			"applied_impulses": [],
		}
	)
	var command := _impulse_command(31)
	var passed: bool = (
		_body_nodes.size() == 1
		and _current_frame == 1
		and command["message_type"] == "apply_impulse"
		and command["target_body_id"] == "torso"
		and command["apply_at_frame"] == 31
		and command["impulse_n_s"]["z"] == 3.5
	)
	print(
		"LOCOMOTION_NATIVE_STREAM_VIEWER_%s worlds=0 frames=0 native_processes=0"
		% ("PASS" if passed else "FAIL")
	)
	quit(0 if passed else 1)


func _fail(code: String) -> void:
	printerr(code)
	_last_event = code
	_completed = true
	if _kick_button != null:
		_kick_button.disabled = true
	if not _start_gate_path.is_empty() and not _start_sent:
		call_deferred("quit", 1)


func _finalize() -> void:
	if _worker_pid > 0 and OS.is_process_running(_worker_pid):
		OS.kill(_worker_pid)
	_server.stop()
	if not _ready_receipt_path.is_empty() and FileAccess.file_exists(_ready_receipt_path):
		DirAccess.remove_absolute(_ready_receipt_path)
