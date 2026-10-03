extends "res://sdk/explorer/showcase.gd"
## Exercise the shipped UI methods and signals. This checker has no native
## launcher; the editing harness accepts only construction commands.
var checks: Array[String] = []

func _initialize() -> void:
	super._initialize()
	call_deferred("verify_desktop")

func check(value: bool, name: String) -> void:
	if not value:
		push_error("SHOWCASE_DESKTOP_FAIL "+name)
		quit(3)
		assert(value, name)
	checks.append(name)

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text==text: return node
	for child in node.get_children():
		var found := find_button(child,text)
		if found!=null: return found
	return null

func no_native_bodies(node: Node) -> bool:
	if node is PhysicsBody3D: return false
	for child in node.get_children():
		if not no_native_bodies(child): return false
	return true

func wait_revision(expected: int) -> void:
	for n in 100:
		if revision>=expected: break
		await create_timer(.05).timeout
	check(revision==expected,"construction_revision_"+str(expected))

func verify_desktop() -> void:
	await create_timer(1).timeout
	var replay_mode := "--replay-check" in OS.get_cmdline_user_args()
	check(nodes.size()==9,"nine_display_bodies")
	check(no_native_bodies(root),"presentation_has_no_native_bodies")
	if replay_mode:
		check(status.get("state")=="complete" and frame_index>2000,"retained_session_loaded")
		replay_button.pressed.emit()
		await create_timer(.7).timeout
		check(replaying and replay_index>20,"recorded_replay_advances")
		check(metrics.text.begins_with("RECORDED NATIVE POSES"),"explicit_replay_label")
		var recorded: Dictionary=replay_frames[replay_index]
		for body in recorded.ordered_bodies:
			check(nodes[body.body_id].position.distance_to(vector(body.position_m))<.000001,"recorded_pose_"+body.body_id)
		await create_timer(17).timeout
		check(not replaying and replay_index==replay_frames.size()-1,"replay_reaches_original_last_frame")
	else:
		edits["torso_length_scale"].value=1.03
		apply_button.pressed.emit()
		await wait_revision(2)
		check(absf(descriptor.torso_length_scale-1.03)<.000001 and launch.disabled,"edited_construction_refuses_native_launch")
		seed.value=42; find_button(root,"Generate").pressed.emit()
		await wait_revision(3)
		check(launch.disabled,"generated_body_refuses_native_launch")
		find_button(root,"Restore native S169").pressed.emit()
		await wait_revision(4)
		check(not launch.disabled,"exact_native_body_restored")
		var old_angle:=angle
		dragging=true
		var motion:=InputEventMouseMotion.new(); motion.relative=Vector2(20,10)
		camera_input(motion); dragging=false
		check(angle!=old_angle,"camera_orbit")
		var old_distance:=distance
		var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
		camera_input(wheel)
		check(distance<old_distance,"camera_zoom")
		find_button(root,"Wireframe").pressed.emit()
		check(viewport.debug_draw==Viewport.DEBUG_DRAW_WIREFRAME,"wireframe_toggle")
		find_button(root,"Wireframe").pressed.emit()
		find_button(root,"Reset camera").pressed.emit()
		check(distance==1.9 and angle==.65,"camera_reset")
		find_button(root,"Refresh proof labels").pressed.emit()
		check("PROVED" in evidence.text and "UNPROVEN" in evidence.text and "AMBIGUOUS" in evidence.text,"three_evidence_labels")
		check("SHA-256" in provenance.text and status.source_commit in provenance.text,"runtime_and_source_provenance")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(channel.path_join("verified-desktop.png"))
	var result:={"ok":true,"mode":"replay" if replay_mode else "editing","checks":checks,"world_build_count":0,"native_launch_count":0}
	var file:=FileAccess.open(channel.path_join("desktop-check.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result));file.close()
	print("SHOWCASE_DESKTOP_PASS ",JSON.stringify(result))
	quit(0)
