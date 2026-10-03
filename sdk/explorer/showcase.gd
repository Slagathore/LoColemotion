extends SceneTree
## Standalone presentation only. All meshes below are display meshes; native
## bodies live in the separately owned engine process, never in this UI.
const Evidence := preload("recovery_evidence.gd")
const ENGINES := ["rapier_parry", "mujoco", "godot_jolt"]
const FIELDS := ["torso_length_scale", "torso_width_scale", "upper_length_fraction", "hip_span_scale", "foot_radius_scale", "front_limb_mass_scale"]
const LABELS := ["Torso length", "Torso width", "Upper leg fraction", "Hip span", "Foot radius", "Front leg mass"]
var channel := ""
var status: Dictionary = {}
var descriptor: Dictionary = {}
var nodes: Dictionary = {}
var edits: Dictionary = {}
var world: Node3D
var camera: Camera3D
var viewport: SubViewport
var engine: OptionButton
var direction: OptionButton
var magnitude: SpinBox
var phase: SpinBox
var seed: SpinBox
var banner: Label
var metrics: Label
var detail: RichTextLabel
var provenance: RichTextLabel
var evidence: RichTextLabel
var launch: Button
var kick: Button
var stop_button: Button
var apply_button: Button
var revision := -1
var session := ""
var frame_index := -1
var elapsed := 0.0
var target := Vector3(0, 0.3, 0)
var angle := 0.65
var elevation := 0.38
var distance := 1.9
var dragging := false
var self_test := false
var wireframe := false
var command_number := 0
var initial_x := 0.0
var last_frame: Dictionary = {}
var exercise_engine := ""
var replay_button: Button
var replay_frames: Array = []
var replay_clock := 0.0
var replay_index := 0
var replaying := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for n in args.size():
		if args[n] == "--channel" and n+1 < args.size(): channel = args[n+1]
		if args[n] == "--exercise-engine" and n+1 < args.size(): exercise_engine = args[n+1]
	self_test = "--self-test" in args
	if channel.is_empty() or not DirAccess.dir_exists_absolute(channel.path_join("commands")):
		quit(2); return
	call_deferred("build")

func label(text: String, size: int = 16, color: Color = Color("dce8f4")) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node

func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 38
	node.pressed.connect(action)
	return node

func box(parent: Node, width: float = 0) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111d30")
	style.set_corner_radius_all(12)
	style.content_margin_left = 18; style.content_margin_right = 18
	style.content_margin_top = 16; style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = width
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	return column

func build() -> void:
	root.title = "SporeSpore Explorer | Native locomotion studio"
	root.size = Vector2i(1480, 960)
	root.min_size = Vector2i(1160, 760)
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	var theme := Theme.new()
	theme.default_font_size = 16
	canvas.theme = theme
	var background := ColorRect.new()
	background.color = Color("080f1c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_"+side, 20)
	canvas.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := label("SPORESPORE  /  EXPLORER", 26, Color("73dfd1"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(label("SDK1 • DEVELOPMENT SHOWCASE", 14, Color("9aadc7")))
	banner = label("Connecting to the session owner…", 16, Color("d8bd82"))
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(row)
	var controls := box(row, 285)
	controls.add_child(label("01  CONSTRUCT", 18, Color("73dfd1")))
	controls.add_child(label("Body seed", 14))
	seed = SpinBox.new(); seed.max_value = 2147483647; seed.value = 169
	controls.add_child(seed)
	var seed_row := HBoxContainer.new(); controls.add_child(seed_row)
	seed_row.add_child(button("Generate", func(): send({"kind":"generate", "seed":int(seed.value)})))
	seed_row.add_child(button("Random", func(): seed.value = randi_range(0, 999999); send({"kind":"generate", "seed":int(seed.value)})))
	controls.add_child(button("Restore native S169", func(): seed.value = 169; send({"kind":"generate", "seed":169})))
	for n in FIELDS.size():
		controls.add_child(label(LABELS[n], 13, Color("9aadc7")))
		var spin := SpinBox.new()
		spin.min_value = .48 if n == 2 else .90
		spin.max_value = .55 if n == 2 else 1.10
		spin.step = .0001
		spin.custom_arrow_step = .005
		controls.add_child(spin); edits[FIELDS[n]] = spin
	apply_button = button("Apply construction edits", edit)
	controls.add_child(apply_button)
	var construction := label("Valid construction does not establish walking. Native sessions require exact S169.", 13, Color("9aadc7"))
	construction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(construction)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 12)
	row.add_child(center)
	var view_container := SubViewportContainer.new()
	view_container.stretch = true
	view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_container.custom_minimum_size = Vector2(540, 350)
	view_container.gui_input.connect(camera_input)
	center.add_child(view_container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(700, 540)
	viewport.own_world_3d = true
	view_container.add_child(viewport)
	world = Node3D.new(); viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("0c1626")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b9d6f5")
	environment.environment.ambient_light_energy = .75
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-25,0); light.light_energy = 1.5
	world.add_child(light)
	var floor_mesh := PlaneMesh.new(); floor_mesh.size = Vector2(40,40)
	var floor_node := MeshInstance3D.new(); floor_node.mesh = floor_mesh
	floor_node.material_override = material(Color("192b3c")); floor_node.position.y = -.005
	world.add_child(floor_node)
	for n in range(-30,31):
		for axis in 2:
			var line := MeshInstance3D.new(); var mesh := BoxMesh.new()
			mesh.size = Vector3(12,.001,.003) if axis == 0 else Vector3(.003,.001,12)
			line.mesh = mesh
			line.position = Vector3(0,0,n*.2) if axis == 0 else Vector3(n*.2,0,0)
			line.material_override = material(Color("294053"))
			world.add_child(line)
	camera = Camera3D.new(); world.add_child(camera); update_camera()
	var view_tools := HBoxContainer.new(); center.add_child(view_tools)
	view_tools.add_child(button("Reset camera", func(): distance=1.9; angle=.65; elevation=.38; update_camera()))
	view_tools.add_child(button("Wireframe", func(): wireframe=not wireframe; viewport.debug_draw=Viewport.DEBUG_DRAW_WIREFRAME if wireframe else Viewport.DEBUG_DRAW_DISABLED))
	replay_button=button("Replay at 1×", start_replay); view_tools.add_child(replay_button)
	view_tools.add_child(label("Drag to orbit • Scroll to zoom", 13, Color("9aadc7")))
	metrics = label("CONSTRUCTION PREVIEW • no physics world", 15, Color("73dfd1"))
	metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(metrics)
	var tabs := TabContainer.new(); tabs.custom_minimum_size.y = 230
	center.add_child(tabs)
	detail = RichTextLabel.new(); detail.name = "Session"; tabs.add_child(detail)
	provenance = RichTextLabel.new(); provenance.name = "Provenance"; tabs.add_child(provenance)
	evidence = RichTextLabel.new(); evidence.name = "Retained proof"; tabs.add_child(evidence)
	var right := box(row, 285)
	right.add_child(label("02  NATIVE PHYSICS", 18, Color("73dfd1")))
	engine = OptionButton.new()
	for item in ["Rapier / Parry", "MuJoCo", "Godot / Jolt recovery"]: engine.add_item(item)
	right.add_child(engine)
	engine.item_selected.connect(func(_n): phase.editable = engine.selected == 2; phase.value = 74 if engine.selected == 2 else 0)
	right.add_child(label("Godot starting phase (0–359)", 13, Color("9aadc7")))
	phase = SpinBox.new(); phase.max_value=359; phase.editable=false
	right.add_child(phase)
	launch = button("Start fresh native session", func(): send({"kind":"start", "engine":ENGINES[engine.selected], "phase":int(phase.value)}))
	right.add_child(launch)
	stop_button = button("Stop and retain session", func(): send({"kind":"stop"}))
	right.add_child(stop_button)
	right.add_child(HSeparator.new())
	right.add_child(label("03  INTERACT", 18, Color("73dfd1")))
	direction = OptionButton.new()
	for item in ["right", "left", "forward", "back"]: direction.add_item(item)
	right.add_child(direction)
	right.add_child(label("Torso impulse (N·s)", 13))
	magnitude = SpinBox.new(); magnitude.min_value=.01; magnitude.max_value=8; magnitude.step=.01; magnitude.value=.25
	right.add_child(magnitude)
	kick = button("Apply native impulse", func(): send({"kind":"kick", "magnitude":magnitude.value, "direction":direction.get_item_text(direction.selected)}))
	right.add_child(kick)
	var note := label("Godot recovery: one scheduled 0.25 N·s kick after setup + 5 simulated seconds. The actual recovery controller selects its branch.\n\nRapier and MuJoCo: interactive torso impulses; successful recovery is not assumed.", 14, Color("9aadc7"))
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; right.add_child(note)
	var spacer := Control.new(); spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL; right.add_child(spacer)
	right.add_child(button("Open retained session files", func(): OS.shell_open(channel)))
	right.add_child(button("Refresh proof labels", refresh_evidence))
	layout.add_child(label("Live sessions are development observations. Finite retained acceptance stays attached to its exact body, controller, engine and schedule.", 13, Color("8499b4")))
	refresh_evidence()
	if self_test: call_deferred("run_self_test")
	if not exercise_engine.is_empty(): call_deferred("exercise_native")

func read_json(name: String) -> Dictionary:
	var path := channel.path_join(name)
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var text := file.get_as_text(); file.close()
	var value: Variant = JSON.parse_string(text)
	return value if value is Dictionary else {}

func send(value: Dictionary) -> void:
	command_number += 1
	var path := channel.path_join("commands/%020d-%04d" % [Time.get_ticks_usec(),command_number])
	var file := FileAccess.open(path+".writing", FileAccess.WRITE)
	file.store_string(JSON.stringify(value)); file.close()
	DirAccess.rename_absolute(path+".writing", path+".json")

func edit() -> void:
	var modified := descriptor.duplicate(true)
	for field in FIELDS: modified[field] = edits[field].value
	modified["morphology_id"] = "explorer_edited"
	send({"kind":"edit", "descriptor":modified})

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new(); result.albedo_color=color; result.roughness=.45
	return result

func vector(value: Dictionary) -> Vector3:
	return Vector3(value.get("x",0),value.get("y",0),value.get("z",0))

func bodies(spec: Dictionary) -> void:
	for node in nodes.values(): node.queue_free()
	nodes.clear()
	for body in spec.get("bodies",[]):
		var mesh: Mesh
		var collision: Dictionary = body.collision
		match collision.kind:
			"box":
				var shape := BoxMesh.new(); shape.size=vector(collision.size_m); mesh=shape
			"capsule":
				var shape := CapsuleMesh.new(); shape.radius=collision.radius_m; shape.height=collision.length_m+2*shape.radius; mesh=shape
			"sphere":
				var shape := SphereMesh.new(); shape.radius=collision.radius_m; shape.height=2*shape.radius; mesh=shape
			_: continue
		var node := MeshInstance3D.new(); node.mesh=mesh
		node.material_override=material(Color("e9a65e") if body.body_id=="torso" else Color("65cfc2"))
		world.add_child(node); nodes[body.body_id]=node

func preview(value: Dictionary) -> void:
	revision=int(value.revision); descriptor=value.descriptor
	for field in FIELDS: edits[field].value=descriptor[field]
	bodies(value.compiled.morphology.morphology_spec)
	var geometry: Dictionary = value.compiled.geometry
	for id in nodes:
		var node: Node3D = nodes[id]
		if id == "torso": node.position=Vector3(0,geometry.initial_torso_center_y_m,0)
		else:
			var x: float = geometry.front_hip_x_m if id.begins_with("front") else geometry.rear_hip_x_m
			var z: float = geometry.left_hip_z_m if "left" in id else geometry.right_hip_z_m
			var y: float = geometry.initial_torso_center_y_m-geometry.upper_length_m*.5 if id.ends_with("upper") else geometry.foot_radius_m+geometry.lower_length_m*.5
			node.position=Vector3(x,y,z)
	target=Vector3(0,.3,0); update_camera()
	metrics.text="CONSTRUCTION PREVIEW • 9 bodies / 8 joints • native compiler • no physics world"
	detail.text="Descriptor: %s\nConstruction digest: %s\n\n%s" % [descriptor.morphology_id,value.compiled.descriptor_sha256,"Native S169 session supported." if value.runnable else "Construction is valid. Walking and recovery are UNPROVEN; native launch is refused for this edited body."]
	launch.disabled=not value.runnable

func native_frame(value: Dictionary) -> void:
	if session != value.session_id:
		session=value.session_id; frame_index=-1
		var scene := read_json("scene.json")
		if scene.get("session_id") != session: return
		bodies(scene.morphology_spec)
	if int(value.frame_index) <= frame_index: return
	frame_index=int(value.frame_index); last_frame=value
	apply_poses(value)
	var sim: float=value.simulation_time_s
	var wall: float=maxf(value.get("physics_wall_time_s",.001),.001)
	metrics.text="NATIVE OBSERVATION • frame %d • %.2f s simulated • %.2fx realtime\nForward %.3f m • torso height %.3f m • %s" % [frame_index,sim,sim/wall,target.x-initial_x,target.y,value.get("phase","walking controller")]
	var contacts := 0
	for contact in value.get("ordered_body_ground_contacts",[]):
		if contact.get("present",contact.get("ground_contact",false)): contacts+=1
	detail.text="Live session: UNPROVEN behavior\nNative engine: %s\nCompleted steps: %d • sampled ground contacts: %d\nSimulation / wall time: %.3f / %.3f seconds\n\n%s\n\nThe viewer renders reported native poses. It never teleports or animates the physics body." % [value.engine_id,frame_index,contacts,sim,wall,status.get("event","")]

func apply_poses(value: Dictionary) -> void:
	for body in value.ordered_bodies:
		if not nodes.has(body.body_id): continue
		var q: Dictionary=body.orientation_xyzw
		var node: Node3D=nodes[body.body_id]
		node.transform=Transform3D(Basis(Quaternion(q.x,q.y,q.z,q.w)),vector(body.position_m))
		if body.body_id=="torso":
			target=node.position
			if frame_index <= 4: initial_x=target.x
	update_camera()

func start_replay() -> void:
	if status.get("state") not in ["complete","stopped"]: return
	var path: String=String(status.get("native_directory","")).path_join("physical/stream.jsonl")
	if not FileAccess.file_exists(path): return
	var file:=FileAccess.open(path,FileAccess.READ)
	replay_frames.clear()
	while not file.eof_reached():
		var value: Variant=JSON.parse_string(file.get_line())
		if value is Dictionary and value.get("message_type")=="frame" and value.get("session_id")==session:
			replay_frames.append(value)
	file.close()
	if replay_frames.is_empty(): return
	replay_clock=replay_frames[0].simulation_time_s; replay_index=0; replaying=true

func refresh_evidence() -> void:
	var result := Evidence.inspect("res://sdk")
	evidence.text="%s\n\n%s\n\n" % [result.label,result.reason]
	if result.evidence_status=="proved":
		evidence.text+="PROVED retained finite recovery: S169, Godot/Jolt, phases 72–74, prescribed 0.25 N·s kick, exact retained runtime and schedule.\nSix accepted role cells. This live session does not inherit that acceptance.\n\n"
	evidence.text+="UNPROVEN: behavior of each new live session, edited body, different force or phase.\nAMBIGUOUS: missing identity or altered retained records; no proof is promoted.\n\nSDK release remains pending."

func camera_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: dragging=event.pressed
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP: distance=maxf(.65,distance*.9)
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance=minf(8,distance*1.1)
	if event is InputEventMouseMotion and dragging:
		angle-=event.relative.x*.008; elevation=clampf(elevation+event.relative.y*.005,.1,1.35)
	update_camera()

func update_camera() -> void:
	if camera==null: return
	camera.position=target+distance*Vector3(cos(angle)*cos(elevation),sin(elevation),sin(angle)*cos(elevation))
	camera.look_at(target)

func _process(delta: float) -> bool:
	if banner==null: return false
	if replaying:
		replay_clock+=delta
		while replay_index+1<replay_frames.size() and replay_frames[replay_index+1].simulation_time_s<=replay_clock: replay_index+=1
		apply_poses(replay_frames[replay_index])
		metrics.text="RECORDED NATIVE POSES • 1× replay • %.2f s • no physics running\n%s" % [replay_clock,replay_frames[replay_index].get("phase","recorded walking")]
		if replay_index==replay_frames.size()-1: replaying=false
	elapsed+=delta
	if elapsed < .08: return false
	elapsed=0
	status=read_json("status.json")
	banner.text=String(status.get("state","connecting")).to_upper()+"  /  "+String(status.get("event",""))
	var active: bool=status.get("state") in ["preflight","running"]
	replay_button.disabled=active or status.get("state") not in ["complete","stopped"]
	if active: replaying=false
	stop_button.disabled=not active
	kick.disabled=not active or status.get("state")!="running" or status.get("engine")=="godot_jolt" or frame_index<1 or session!=status.get("native_session","")
	apply_button.disabled=active
	var p := read_json("preview.json")
	if not p.is_empty() and int(p.revision)!=revision: preview(p)
	launch.disabled=active or not p.get("runnable",false)
	var f := read_json("frame.json")
	if not replaying and not f.is_empty() and status.get("state") in ["running","complete","stopped","refused"]: native_frame(f)
	provenance.text="Source commit: %s\nRetained session: %s\n\n" % [status.get("source_commit","unknown"),status.get("native_directory",channel)]
	for key in status.get("runtime",{}): provenance.text+="%s SHA-256\n%s\n\n" % [key,status.runtime[key].sha256]
	return false

func run_self_test() -> void:
	await create_timer(1.0).timeout
	var ok: bool = nodes.size()==9 and not descriptor.is_empty() and revision==1 and Evidence.inspect("res://sdk").evidence_status=="proved"
	send({"kind":"generate","seed":42})
	await create_timer(.8).timeout
	ok=ok and revision==2 and launch.disabled
	send({"kind":"generate","seed":169})
	await create_timer(.8).timeout
	ok=ok and revision==3 and not launch.disabled and nodes.size()==9
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(channel.path_join("showcase.png"))
	print("SHOWCASE_UI_", "PASS" if ok else "FAIL", " worlds=0 native_workers=0")
	quit(0 if ok else 3)

func exercise_native() -> void:
	await create_timer(1.0).timeout
	engine.select(ENGINES.find(exercise_engine))
	phase.value=74 if exercise_engine=="godot_jolt" else 0
	launch.pressed.emit()
	var kicked := false
	var active_seen := false
	var deadline := Time.get_ticks_msec()+4200000
	while Time.get_ticks_msec()<deadline:
		await create_timer(.1).timeout
		if status.get("state") in ["preflight","running"]: active_seen=true
		if frame_index>=720 and not kicked and exercise_engine!="godot_jolt":
			kick.pressed.emit(); kicked=true
		if active_seen and status.get("state") in ["complete","refused","stopped"]: break
	await create_timer(.2).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(channel.path_join("native-showcase.png"))
	var ok: bool=status.get("state")=="complete" and frame_index>720
	print("SHOWCASE_NATIVE_UI_", "PASS" if ok else "FAIL", " engine=",exercise_engine," frame=",frame_index)
	quit(0 if ok else 4)
