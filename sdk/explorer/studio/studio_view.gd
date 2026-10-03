extends "../showcase.gd"
## Presentation successor. The original accepted showcase remains unchanged.
var duration: SpinBox
var construction_note: Label
var sandbox_exercise := false
var catalog: Dictionary = {}
var recipes: OptionButton
var recipe_text: RichTextLabel
var recipe_load: Button
var timeline: HSlider
var timeline_label: Label
var replay_loaded_session := ""
var pending_kicks: Dictionary = {}
var kick_receipts: Array[Dictionary] = []
var kick_latency: Label
var route_note: Label
var live_walk_session := ""
var live_walk_sim := 0.0
var live_walk_wall := 0.0
var display_elapsed := 0.0

func build() -> void:
	# This process only renders native observations; the separate worker keeps
	# its declared 120 Hz solver clock and full stream retention.
	Engine.max_fps=60
	super.build()
	root.title="SporeSpore Studio | Explore native locomotion"
	engine.set_item_text(2,"Godot / Jolt live walking")
	engine.select(1)
	duration=SpinBox.new(); duration.min_value=1; duration.max_value=60; duration.value=30
	var controls:=launch.get_parent()
	var caption:=label("MuJoCo duration (simulated seconds)",13,Color("9aadc7"))
	controls.add_child(caption); controls.move_child(caption,launch.get_index())
	controls.add_child(duration); controls.move_child(duration,launch.get_index())
	for connection in launch.pressed.get_connections():launch.pressed.disconnect(connection.callable)
	launch.pressed.connect(func():send({"kind":"start","engine":ENGINES[engine.selected],"phase":int(phase.value),"steps":int(duration.value)*120}))
	for node in root.find_children("*","Label",true,false):
		if node.text.begins_with("Godot recovery: one scheduled"):route_note=node
		if node.text.begins_with("Valid construction does not establish"):
			construction_note=node
			construction_note.text="Valid edited bodies can explore MuJoCo. Walking and recovery are unproven until observed. Rapier and Godot retain their exact S169 routes."
	build_browser()
	kick_latency=label("MuJoCo and Godot kicks apply at the next physics step.",12,Color("9aadc7"))
	kick_latency.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	kick.get_parent().add_child(kick_latency)
	kick.get_parent().move_child(kick_latency,kick.get_index()+1)
	if "--exercise-sandbox" in OS.get_cmdline_user_args():call_deferred("exercise_sandbox")
	if "--exercise-godot-live" in OS.get_cmdline_user_args():call_deferred("exercise_godot_live")

func send(value: Dictionary) -> void:
	if value.get("kind")=="start":
		pending_kicks.clear();kick_receipts.clear()
	if value.get("kind")=="kick" and engine.selected in [1,2]:
		value=value.duplicate()
		var stamp:=Time.get_ticks_usec()
		value["command_id"]="studio_%d_%d" % [stamp,command_number+1]
		pending_kicks[value.command_id]=stamp
	super.send(value)

func native_frame(value: Dictionary) -> void:
	super.native_frame(value)
	observe_impulses(value.session_id,value.get("applied_impulses",[]))
	if value.get("telemetry_profile")=="live_walking_without_recovery_energy_ledger":
		if live_walk_session!=value.session_id:
			live_walk_session=value.session_id;live_walk_sim=value.simulation_time_s;live_walk_wall=value.physics_wall_time_s
		var walk_sim: float=value.simulation_time_s-live_walk_sim
		var walk_wall: float=value.physics_wall_time_s-live_walk_wall
		if walk_wall>.1:
			metrics.text="LIVE GODOT WALKING • %.2fx real time since first walking sample\n%.2f s walking • forward %.3f m • torso height %.3f m" % [walk_sim/walk_wall,(value.frame_index-241)/120.0,target.x-initial_x,target.y]

func observe_impulses(native_session: String, impulses: Array) -> void:
	if native_session!=session:return
	for applied in impulses:
		var command_id: String=applied.command_id
		if not pending_kicks.has(command_id) or applied.apply_at_frame>frame_index:continue
		var now:=Time.get_ticks_usec()
		var elapsed_ms: float=(now-int(pending_kicks[command_id]))/1000.0
		kick_receipts.append({"command_id":command_id,"session_id":native_session,
			"applied_frame":applied.apply_at_frame,"ui_pressed_ticks_usec":pending_kicks[command_id],
			"ui_observed_ticks_usec":now,"button_to_observed_application_ms":elapsed_ms})
		pending_kicks.erase(command_id)
		kick_latency.text="Last kick applied • %.0f ms button-to-display response" % elapsed_ms
		var file:=FileAccess.open(channel.path_join("interaction.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(kick_receipts,"  "));file.close()

func preview(value: Dictionary) -> void:
	super.preview(value)
	if descriptor.morphology_id.begins_with("explorer_seed_"):seed.value=int(descriptor.morphology_id.trim_prefix("explorer_seed_"))
	if descriptor.morphology_id=="qsdk_r05_generated_s169":seed.value=169
	replay_frames.clear();replaying=false;replay_loaded_session=""
	detail.text="Descriptor: %s\nConstruction digest: %s\n\nMuJoCo can run this valid construction in a fresh native world. This is exploration: no walking or recovery outcome is promised.\n\nRapier and Godot require the retained exact S169 setup." % [descriptor.morphology_id,value.compiled.descriptor_sha256]

func _process(delta: float) -> bool:
	var result:=super._process(delta)
	display_elapsed+=delta
	if display_elapsed>=1.0/30.0:
		display_elapsed=0.0
		if not replaying and status.get("state") in ["running","complete","stopped","refused"]:
			var displayed:=read_json("frame.json")
			if not displayed.is_empty() and (displayed.get("session_id")!=session or int(displayed.get("frame_index",0))>frame_index):native_frame(displayed)
	var events:=read_json("impulse-events.json")
	if not events.is_empty():observe_impulses(events.get("session_id",""),events.get("impulses",[]))
	if launch!=null and duration!=null:
		if route_note!=null:
			route_note.text=["Live native impulses on the retained S169 setup. Recovery varies with the force and timing.","Live native physics with user-timed impulses. Walking and recovery vary with the body and force.","Fresh stand-up, then 15 seconds of live walking. Kick whenever it is walking. This route does not yet switch to a get-up controller after a fall."][engine.selected]
		var active: bool=status.get("state") in ["preflight","running"]
		engine.disabled=active
		if engine.selected==2:phase.value=74;phase.editable=false
		if status.get("engine")=="godot_jolt":
			kick.disabled=status.get("state")!="running" or frame_index<242 or session!=status.get("native_session","") or pending_kicks.size()+kick_receipts.size()>=16
		launch.disabled=active or (engine.selected!=1 and descriptor.get("morphology_id","")!="qsdk_r05_generated_s169")
		duration.editable=not active and engine.selected==1
		if recipe_load!=null:recipe_load.disabled=active
		if timeline!=null:
			timeline.editable=not active and not replay_frames.is_empty()
			if replaying:timeline.set_value_no_signal(replay_clock)
	return result

func build_browser() -> void:
	catalog=read_json("catalog.json")
	var tabs:=detail.get_parent()
	var page:=VBoxContainer.new();page.name="Tested scenarios";tabs.add_child(page)
	recipes=OptionButton.new();recipes.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for entry in catalog.get("entries",[]):recipes.add_item(entry.title)
	page.add_child(recipes);recipes.item_selected.connect(show_recipe)
	recipe_text=RichTextLabel.new();recipe_text.size_flags_vertical=Control.SIZE_EXPAND_FILL;page.add_child(recipe_text)
	recipe_load=button("Load setup (does not start physics)",load_recipe);page.add_child(recipe_load)
	show_recipe(0)
	var center:=metrics.get_parent()
	var bar:=HBoxContainer.new();center.add_child(bar);center.move_child(bar,metrics.get_index())
	bar.add_child(button("Load timeline",load_timeline))
	timeline=HSlider.new();timeline.min_value=0;timeline.max_value=1;timeline.step=1.0/120.0
	timeline.size_flags_horizontal=Control.SIZE_EXPAND_FILL;timeline.editable=false
	bar.add_child(timeline);timeline.value_changed.connect(seek_timeline)
	timeline_label=label("Recorded poses • load after a session",12,Color("9aadc7"))
	center.add_child(timeline_label);center.move_child(timeline_label,metrics.get_index())

func show_recipe(index: int) -> void:
	if catalog.get("entries",[]).is_empty():return
	var entry: Dictionary=catalog.entries[index]
	recipe_text.text="%s\n\n%s\n\nSource: sdk/%s\nLoading a setup never transfers historical acceptance to a new run.\n\n%s\n%s" % [entry.status,entry.story,entry.source,catalog.title,catalog.explanation]

func load_recipe() -> void:
	if status.get("state") in ["preflight","running"]:return
	show_recipe(recipes.selected)
	var entry: Dictionary=catalog.entries[recipes.selected]
	seed.value=entry.seed;engine.select(ENGINES.find(entry.engine));phase.value=entry.phase
	phase.editable=entry.engine=="godot_jolt";duration.value=entry.duration
	send({"kind":"generate","seed":int(entry.seed)})

func load_timeline() -> void:
	if status.get("state") not in ["complete","stopped"]:return
	var path: String=String(status.get("native_directory","")).path_join("physical/stream.jsonl")
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return
	if file.get_length()>268435456:file.close();return
	replay_frames.clear();replaying=false
	while not file.eof_reached():
		var line:=file.get_line()
		if line.strip_edges().is_empty():continue
		var value: Variant=JSON.parse_string(line)
		if value is Dictionary and value.get("message_type")=="frame" and value.get("session_id")==session:replay_frames.append(value)
	file.close()
	if replay_frames.is_empty():return
	replay_loaded_session=session;timeline.max_value=replay_frames[-1].simulation_time_s;timeline.editable=true
	var events: Array[String]=[];var previous_phase:=""
	for frame in replay_frames:
		if not frame.get("applied_impulses",[]).is_empty():events.append("Kick %.2f s" % frame.simulation_time_s)
		var current_phase: String=frame.get("phase","")
		if not current_phase.is_empty() and current_phase!=previous_phase:
			events.append("%s %.2f s" % [current_phase,frame.simulation_time_s]);previous_phase=current_phase
	timeline_label.text="Recorded native poses • "+(" | ".join(events) if not events.is_empty() else "No scheduled event in this recording")
	timeline_label.tooltip_text=timeline_label.text
	seek_timeline(0)

func seek_timeline(seconds: float) -> void:
	if replay_frames.is_empty() or status.get("state") in ["preflight","running"]:return
	replaying=false;replay_clock=seconds;replay_index=0
	timeline.set_value_no_signal(seconds)
	while replay_index+1<replay_frames.size() and replay_frames[replay_index+1].simulation_time_s<=seconds:replay_index+=1
	apply_poses(replay_frames[replay_index])
	metrics.text="RECORDED NATIVE POSES • %.2f / %.2f s • frame %d\nScrub or replay • no physics running" % [seconds,timeline.max_value,replay_frames[replay_index].frame_index]

func start_replay() -> void:
	if replay_loaded_session!=session:load_timeline()
	if not replay_frames.is_empty() and status.get("state") in ["complete","stopped"]:
		if replay_index>=replay_frames.size()-1:seek_timeline(0)
		replaying=true

func run_self_test() -> void:
	await create_timer(1.0).timeout
	var ok: bool=nodes.size()==9 and engine.selected==1
	send({"kind":"generate","seed":42})
	await create_timer(.8).timeout
	ok=ok and descriptor.morphology_id=="explorer_seed_42" and not launch.disabled
	engine.select(0)
	await create_timer(.2).timeout
	ok=ok and launch.disabled
	engine.select(1)
	await create_timer(.2).timeout
	ok=ok and not launch.disabled and nodes.size()==9
	ok=ok and recipes.item_count==6
	recipes.select(4);load_recipe()
	await create_timer(.4).timeout
	ok=ok and int(seed.value)==42 and duration.value==8 and String(catalog.entries[4].status) in recipe_text.text
	if "--replay-test" in OS.get_cmdline_user_args():
		var record:=read_json("replay-test.json")
		status={"state":"complete","native_directory":record.native_directory}
		native_frame(read_json("frame.json"));load_timeline();seek_timeline(4)
		ok=ok and replay_frames.size()==241 and replay_frames[replay_index].frame_index==480 and "Kick" in timeline_label.text
		start_replay();ok=ok and replaying;replaying=false
		tabs_for_test()
	# The native pose channel can skip the impulse frame. The cumulative event
	# channel must still acknowledge it exactly once after later poses arrive.
	var saved_session:=session;var saved_frame:=frame_index
	session="zero-world-ui-test";frame_index=20
	pending_kicks={"missed_first":Time.get_ticks_usec(),"missed_second":Time.get_ticks_usec()}
	var missed: Array=[{"command_id":"missed_first","apply_at_frame":9},{"command_id":"missed_second","apply_at_frame":13}]
	observe_impulses("other-session",missed);ok=ok and kick_receipts.is_empty()
	observe_impulses(session,missed);observe_impulses(session,missed)
	ok=ok and kick_receipts.size()==2 and pending_kicks.is_empty()
	kick_receipts.clear();session=saved_session;frame_index=saved_frame
	kick_latency.text="MuJoCo and Godot kicks apply at the next physics step."
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(channel.path_join("studio.png"))
	print("STUDIO_UI_", "PASS" if ok else "FAIL", " worlds=0 native_workers=0")
	quit(0 if ok else 3)

func tabs_for_test() -> void:
	var tabs: TabContainer=detail.get_parent()
	tabs.current_tab=3

func exercise_sandbox() -> void:
	await create_timer(1.0).timeout
	send({"kind":"generate","seed":42})
	await create_timer(.5).timeout
	engine.select(1);duration.value=8;launch.pressed.emit()
	var kicked:=0;var seen:=false
	var deadline:=Time.get_ticks_msec()+180000
	while Time.get_ticks_msec()<deadline:
		await create_timer(.05).timeout
		if status.get("state") in ["preflight","running"]:seen=true
		if kicked==0 and frame_index>=240:
			kick.pressed.emit();kicked=1
		elif kicked==1 and frame_index>=600:
			direction.select(1);kick.pressed.emit();kicked=2
		if seen and status.get("state") in ["complete","stopped","refused"]:break
	await create_timer(.2).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(channel.path_join("studio-native.png"))
	var ok: bool=status.get("state")=="complete" and frame_index==960 and kicked==2 and kick_receipts.size()==2
	print("STUDIO_NATIVE_UI_", "PASS" if ok else "FAIL", " frame=",frame_index)
	quit(0 if ok else 4)

func exercise_godot_live() -> void:
	await create_timer(1.0).timeout
	send({"kind":"generate","seed":169})
	await create_timer(.5).timeout
	engine.select(2);phase.value=74;launch.pressed.emit()
	var kicked:=0;var seen:=false
	var deadline:=Time.get_ticks_msec()+220000
	while Time.get_ticks_msec()<deadline:
		await create_timer(.05).timeout
		if status.get("state") in ["preflight","running"]:seen=true
		if not kick.disabled and kicked==0 and frame_index>=841:
			kick.pressed.emit();kicked=1
		elif not kick.disabled and kicked==1 and frame_index>=1441:
			direction.select(1);kick.pressed.emit();kicked=2
		if seen and status.get("state") in ["complete","stopped","refused"]:break
	await create_timer(.2).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(channel.path_join("studio-godot-native.png"))
	var ok: bool=status.get("state")=="complete" and frame_index==2041 and kicked==2 and kick_receipts.size()==2
	print("STUDIO_GODOT_LIVE_UI_", "PASS" if ok else "FAIL", " frame=",frame_index)
	quit(0 if ok else 4)
