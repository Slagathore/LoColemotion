extends SceneTree

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== EditorBench wiring smoke ===")
	_test_load_scale_undo()
	_test_shape_socket_joint_gait()
	_test_topology_mutators()
	_test_ray_pick_selects_part()
	_test_generate_and_drop()
	_test_arm_place()
	_test_muscle_toggle()
	_test_muscle_amount()
	_test_multi_select_and_global_muscle()
	_test_existing_part_attach_here()
	_test_attach_near_detach_and_mirror()
	_test_m56_attach_and_hinge()
	_test_hinge_guide_and_deselect()
	_test_drag_aware_deselect_and_layout_scroll()
	_test_custom_part_save_and_palette()
	_test_pause_menu_and_gpu_status()
	_test_vitals_visible()
	_test_expanded_part_library()
	_test_creature_tabs_group_saved_by_legs()
	_test_m54_shell()
	_test_m57_copilot()
	_test_m58_display()
	_test_apply_optimized_gait()
	_test_skin_toggle_and_dashboard()
	await _test_m55_surface()
	await _test_simulation()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_skin_toggle_and_dashboard() -> void:
	print("- bench exposes the M10 skin toggle and the M11 dashboard read-out")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	_check(not bench.skin_enabled(), "skin starts off")
	bench.set_skin_enabled(true)
	_check(bench.skin_enabled(), "skin toggle turns the display sleeve on")
	bench.set_skin_enabled(false)
	_check(not bench.skin_enabled(), "skin toggle turns it back off")
	var dash := bench.dashboard_text()
	_check(dash.length() > 0 and dash.contains("Runs:"),
			"dashboard text reports training-log counters")
	bench.queue_free()


func _test_load_scale_undo() -> void:
	print("- bench loads a card, edits through EditSession, scores through scheduler")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Bench Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	_check(bench.part_count() == 12, "built-in quad resolves body, organs, legs, foot pads, and lung")
	_check(not bench.current_score().is_empty(), "initial score applied")
	var before := float(bench.current_score()["total_mass"])
	bench.select_part(0)
	_check(bench.apply_selected_scale(Vector3(1.5, 1.5, 1.5)), "scale edit accepted")
	bench.pump_scores_blocking()
	var after := float(bench.current_score()["total_mass"])
	_check(after > before, "score mass increased after scale edit")
	_check(bench.undo(), "undo succeeded")
	bench.pump_scores_blocking()
	var undone := float(bench.current_score()["total_mass"])
	_check(is_equal_approx(undone, before), "undo restored original score")
	_check(bench.save_current_card("user://_bench_saved_card.tres") == OK, "bench saves through CreatureIO")
	bench.queue_free()


func _test_shape_socket_joint_gait() -> void:
	print("- inspector mutators edit shape, socket, joint, and gait through the session")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Inspector Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	bench.select_part(3)
	var before_mass := float(bench.current_score()["total_mass"])
	_check(bench.edit_selected_shape(&"box", Vector3(0.2, 0.6, 0.2), 1200.0), "shape edit accepted")
	bench.pump_scores_blocking()
	_check(float(bench.current_score()["total_mass"]) != before_mass, "shape edit changed evaluated mass")
	_check(bench.edit_selected_socket(Vector3(-0.7, -0.3, 0.1), Vector3(1, 0, 0)), "socket edit accepted")
	_check(bench.snap_selected_to_spine(0.75, -1.0), "advanced spine snap accepted")
	_check(bench.edit_selected_joint(0.25, 0.1, -0.2, 0.2), "joint edit accepted")
	_check(bench.set_selected_gait_phase(0.35), "gait phase edit accepted")
	bench.pump_scores_blocking()
	_check(not bench.current_score().is_empty(), "score remains available after socket/joint/gait edits")
	bench.queue_free()


func _test_topology_mutators() -> void:
	print("- add/remove/reparent topology edits are real genome edits")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Topology Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	var before_count := bench.part_count()
	bench.select_part(0)
	_check(bench.add_child_part(&"primitive_box"), "add child accepted")
	bench.pump_scores_blocking()
	_check(bench.part_count() == before_count + 1, "part count increased after add")
	var added_index := bench.part_count() - 1
	bench.select_part(added_index)
	_check(bench.reparent_selected_to(1), "reparent accepted")
	bench.pump_scores_blocking()
	_check(bench.part_count() == before_count + 1, "part count preserved after reparent")
	_check(bench.remove_selected_part(), "remove accepted")
	bench.pump_scores_blocking()
	_check(bench.part_count() == before_count, "part count restored after remove")
	bench.queue_free()


func _test_ray_pick_selects_part() -> void:
	print("- 3D picking uses folded world AABBs")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Pick Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	var hit := bench.pick_part_from_ray(Vector3(0, 0, 6), Vector3(0, 0, -1))
	_check(hit == 0, "center ray hits the root body")
	bench.select_part(hit)
	_check(bench.apply_selected_scale(Vector3(1.2, 1.2, 1.2)), "picked part can be edited")
	bench.queue_free()


func _test_generate_and_drop() -> void:
	print("- generator button + palette/drop share the SocketCatalog legality gate")
	var bench := EditorBench.new()
	root.add_child(bench)

	_check(bench.generate_creature(7), "generate button produces a creature")
	bench.pump_scores_blocking()
	_check(bench.part_count() >= 5, "generated creature has a real body plan")
	_check(not bench.current_score().is_empty(), "generated creature scores")

	var card := CreatureCard.new()
	card.display_name = "Drop Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	var base := bench.part_count()
	bench.select_part(0)

	_check(bench.add_child_part_to_selected(&"primitive_capsule"), "palette click attaches a leg")
	bench.pump_scores_blocking()
	_check(bench.part_count() == base + 1, "palette attach adds one part")

	# Right-front limb point on the root box, in world space (root xform is identity).
	var dropped := bench.commit_drop(&"primitive_capsule", 0, Vector3(0.5, -0.2, -0.44))
	bench.pump_scores_blocking()
	_check(dropped, "viewport drop attaches at nearest free limb point")
	_check(bench.part_count() == base + 2, "drop adds one part")

	# A leg cannot attach to the brain sphere (tag mismatch) -> rejected, nothing added.
	_check(not bench.commit_drop(&"primitive_capsule", 2, Vector3(0.0, 0.3, 0.0)),
			"drop onto an incompatible part is rejected")
	bench.pump_scores_blocking()
	_check(bench.part_count() == base + 2, "rejected drop adds nothing")
	bench.queue_free()


func _test_arm_place() -> void:
	print("- click-to-place arms a library part, then places it on a body part")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Arm Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)

	bench.arm_part(&"primitive_capsule")
	_check(bench.armed_part() == &"primitive_capsule", "arming records the chosen part")
	var base := bench.part_count()
	_check(bench.commit_drop(&"primitive_capsule", 0, Vector3(0.5, -0.2, -0.44)),
			"armed part places onto a legal body point")
	bench.pump_scores_blocking()
	_check(bench.part_count() == base + 1, "placement adds one part")
	bench.queue_free()


func _test_muscle_toggle() -> void:
	print("- muscle toggle tags the selected part as muscle through the session")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Muscle Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	bench.select_part(3)   # a leg
	_check(bench.set_selected_muscle(true), "muscle tag add accepted")
	bench.pump_scores_blocking()
	_check(_part_has_tag(bench, 3, &"muscle"), "selected part is tagged muscle")
	_check(bench.set_selected_muscle(false), "muscle tag remove accepted")
	bench.pump_scores_blocking()
	_check(not _part_has_tag(bench, 3, &"muscle"), "muscle tag removed")
	bench.queue_free()


func _test_muscle_amount() -> void:
	print("- muscle amount is an authored runtime dial, not just UI state")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Muscle Amount Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	bench.select_part(3)
	_check(bench.set_selected_muscle_amount(2.5), "muscle amount edit accepted")
	bench.pump_scores_blocking()
	var g := _part_gene_by_index(bench._session.root(), 3)
	_check(g != null and g.tags.has(&"muscle"), "muscle amount turns on muscle tag")
	_check(g != null and absf(float(g.dial_values.get(&"muscle_amount", 0.0)) - 2.5) < 0.001,
			"muscle amount persists in dial_values")
	var fold := CharacteristicsEvaluator.fold_graph(bench._session.root(), Transform3D.IDENTITY)
	_check(absf(float(fold["parts"][3].muscle_amount) - 2.5) < 0.001,
			"folded runtime part carries muscle amount")
	_check(bench.set_selected_muscle_amount(0.0), "zero muscle amount edit accepted")
	g = _part_gene_by_index(bench._session.root(), 3)
	_check(g != null and not g.tags.has(&"muscle") and not g.dial_values.has(&"muscle_amount"),
			"zero amount removes muscle tag and dial")
	bench.queue_free()


func _test_multi_select_and_global_muscle() -> void:
	print("- multi-select edits shared metrics; global muscle targets locomotor parts")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Multi Muscle Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	bench.select_parts([3, 5], 5)
	_check(bench.selected_parts().size() == 2, "two parts are selected")
	_check(bench.set_selected_muscle_amount(1.8), "bulk muscle amount edit accepted")
	var g3 := _part_gene_by_index(bench._session.root(), 3)
	var g5 := _part_gene_by_index(bench._session.root(), 5)
	_check(g3 != null and g5 != null and g3.tags.has(&"muscle") and g5.tags.has(&"muscle"),
			"bulk muscle tags both selected legs")
	_check(absf(float(g3.dial_values.get(&"muscle_amount", 0.0)) - 1.8) < 0.001
			and absf(float(g5.dial_values.get(&"muscle_amount", 0.0)) - 1.8) < 0.001,
			"bulk muscle amount written to both selected legs")
	_check(bench.set_global_muscle_amount(2.2), "global locomotor muscle edit accepted")
	_check(_all_locomotors_have_muscle(bench._session.root(), 2.2),
			"global muscle amount applies to all locomotor parts")
	bench.queue_free()


func _test_existing_part_attach_here() -> void:
	print("- Attach Here reattaches an existing part through SocketCatalog")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Attach Existing Test"
	card.root = _single_leg_creature()
	bench.load_card(card)
	bench.select_part(1)
	_check(bench.attach_selected_to_part_at(0, Vector3(0.5, -0.2, -0.44)),
			"existing leg attaches to nearest legal free limb socket")
	var moved := _part_gene_by_index(bench._session.root(), bench.selected_parts()[0])
	_check(moved != null and moved.socket_id == &"limb_right_front",
			"reattached leg uses the catalog socket id")
	_check(moved != null and moved.socket != null and moved.socket.hinge_axis == Vector3.RIGHT,
			"reattached leg receives the catalog hinge axis")
	_check(moved != null and moved.socket != null and moved.socket.child_anchor.origin.y < 0.0,
			"reattached leg is top-anchored for rotation")
	bench.queue_free()


func _test_attach_near_detach_and_mirror() -> void:
	print("- detach parks a part, attach-near snaps it back, and mirror duplicates legal subtrees")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Attach Near Test"
	card.root = _single_leg_creature()
	bench.load_card(card)
	bench.select_part(1)
	_check(bench.detach_selected_to_root(), "detach selected part parks it under the root")
	var detached := _part_gene_by_index(bench._session.root(), bench.selected_parts()[0])
	_check(detached != null and String(detached.socket_id).begins_with("detached"),
			"detached part has an explicit parking socket")
	_check(bench.attach_selected_near_current(), "attach-near finds the nearest legal catalog socket")
	var attached := _part_gene_by_index(bench._session.root(), bench.selected_parts()[0])
	_check(attached != null and not String(attached.socket_id).begins_with("detached"),
			"attach-near replaces the parking socket")
	var before := bench.part_count()
	_check(bench.mirror_selected_parts(), "mirror selected part succeeds")
	_check(bench.part_count() == before + 1, "mirror adds one copied subtree")
	bench.queue_free()


func _test_hinge_guide_and_deselect() -> void:
	print("- selected hinged parts show a direction guide and clear cleanly")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Hinge Guide Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	bench.select_part(3)
	_check(bench.hinge_guide_segments() > 0, "hinged selected part draws hinge guide segments")
	bench.deselect_all_parts()
	_check(not bench.has_part_selection() and bench.selected_parts().is_empty(),
			"deselect clears all selected parts")
	_check(bench.hinge_guide_segments() == 0, "deselect hides hinge guide")
	bench.queue_free()


func _test_drag_aware_deselect_and_layout_scroll() -> void:
	print("- empty-space camera drag does not deselect, but a clean click can")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Drag Deselect Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	bench.select_part(3)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(-1000, -1000)
	bench._on_viewport_gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(-950, -1000)
	motion.relative = Vector2(50, 0)
	bench._on_viewport_gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(-950, -1000)
	bench._on_viewport_gui_input(release)
	_check(bench.has_part_selection(), "camera drag preserves selected part")
	var clean_press := InputEventMouseButton.new()
	clean_press.button_index = MOUSE_BUTTON_LEFT
	clean_press.pressed = true
	clean_press.position = Vector2(-1000, -1000)
	bench._on_viewport_gui_input(clean_press)
	var clean_release := InputEventMouseButton.new()
	clean_release.button_index = MOUSE_BUTTON_LEFT
	clean_release.pressed = false
	clean_release.position = Vector2(-1000, -1000)
	bench._on_viewport_gui_input(clean_release)
	_check(not bench.has_part_selection(), "clean empty click deselects")
	_check(bench.find_child("RightPanelScroll", true, false) is ScrollContainer,
			"right editor panel is scroll-contained")
	bench.queue_free()


func _test_custom_part_save_and_palette() -> void:
	print("- selected subtree can be saved into the custom part tab")
	var path := "res://data/parts/primitive_capsule.tres"
	_delete_resource(path)
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Custom Part Test"
	card.root = _single_leg_creature()
	bench.load_card(card)
	bench.select_part(1)
	_check(bench.save_selected_part_template() == OK, "save selected subtree accepted")
	_check(FileAccess.file_exists(path), "custom part resource exists on disk")
	_check(bench._palette.has_part_id(&"custom:primitive_capsule"),
			"custom part appears in the tabbed palette")
	bench.queue_free()
	_delete_resource(path)


func _test_pause_menu_and_gpu_status() -> void:
	print("- pause menu and GPU diagnostics are present in the editor chrome")
	var bench := EditorBench.new()
	root.add_child(bench)
	_check(bench.pause_menu_item_count() == 6, "pause menu exposes the requested actions")
	_check(bench._gpu_status != null and bench._gpu_status.text.contains("GPU"),
			"GPU/render/physics diagnostics are visible")
	bench.queue_free()


func _test_vitals_visible() -> void:
	print("- score panel exposes necessary organ counts")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Vitals Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	bench.pump_scores_blocking()
	_check(bench._score_vitals.text.contains("H1") and bench._score_vitals.text.contains("B1")
			and bench._score_vitals.text.contains("L1"),
			"vitals row shows heart, brain, and lung counts")
	bench.queue_free()


func _test_expanded_part_library() -> void:
	print("- part catalog exposes limbs, feet, tissues, organs, sensors, and manipulators")
	var ids := PartCatalog.template_ids()
	for id in [&"leg_upper", &"leg_lower", &"ankle_link", &"foot_pad", &"wide_foot_pad",
			&"arm_upper", &"hand_grasper", &"sensor_eye", &"muscle_bundle",
			&"armor_plate", &"fat_pad", &"organ_lung"]:
		_check(ids.has(id), "catalog includes %s" % String(id))
	var root := PartCatalog.make_quadruped(false)
	var muscle := PartCatalog.clone_template(&"muscle_bundle")
	var muscle_tags: Array[StringName] = []
	muscle_tags.assign(muscle.tags)
	_check(bool(SocketCatalog.can_attach(root, &"organ_top", muscle_tags)["ok"]),
			"body organ/surface point accepts muscle tissue")
	var foot := PartCatalog.clone_template(&"foot_pad")
	var foot_tags: Array[StringName] = []
	foot_tags.assign(foot.tags)
	_check(bool(SocketCatalog.can_attach(root, &"limb_left_front", foot_tags)["ok"]),
			"limb point accepts explicit foot pad")


func _test_creature_tabs_group_saved_by_legs() -> void:
	print("- creature browser separates pregens from saved leg-count tabs")
	var path := "res://data/creatures/_bench_10_leg_tab_test.tres"
	_delete_resource(path)
	var card := CreatureCard.new()
	card.display_name = "Bench Ten Legs"
	card.root = _flat_foot_creature(10)
	_check(CreatureIO.save(card, path) == OK, "test ten-leg creature saved")
	var bench := EditorBench.new()
	root.add_child(bench)
	var tabs := bench.creature_tab_names()
	_check(tabs.has("Pregen"), "browser has consolidated pregen tab")
	_check(tabs.has("10 legs"), "browser creates dynamic 10 legs tab")
	_check(bench.creature_tab_item_count("10 legs") >= 1, "10 legs tab contains saved creature")
	bench.queue_free()
	_delete_resource(path)


func _part_has_tag(bench: EditorBench, index: int, tag: StringName) -> bool:
	var fold := CharacteristicsEvaluator.fold_graph(bench._session.root(), Transform3D.IDENTITY)
	if index < 0 or index >= fold["parts"].size():
		return false
	return fold["parts"][index].tags.has(tag)


func _part_gene_by_index(root_gene: PartGene, target: int) -> PartGene:
	var cursor := [0]
	return _part_gene_by_index_rec(root_gene, target, cursor)


func _part_gene_by_index_rec(gene: PartGene, target: int, cursor: Array) -> PartGene:
	if gene == null:
		return null
	if int(cursor[0]) == target:
		return gene
	cursor[0] = int(cursor[0]) + 1
	for child in gene.children:
		var found := _part_gene_by_index_rec(child, target, cursor)
		if found != null:
			return found
	return null


func _flat_foot_creature(feet: int) -> PartGene:
	var root_gene := PartGene.new()
	root_gene.definition = _def(&"box", 1000.0, Vector3(0.7, 0.18, 0.9))
	root_gene.tags = [&"spine"]
	for i in feet:
		var foot := PartGene.new()
		foot.definition = _def(&"box", 650.0, Vector3(0.12, 0.035, 0.18))
		foot.tags = [&"ground_contact"]
		foot.socket_id = StringName("foot_%02d" % i)
		var x := -0.55 if i % 2 == 0 else 0.55
		var z := -0.75 + 1.5 * float(i) / maxf(float(feet - 1), 1.0)
		foot.socket = _sock(Vector3(x, -0.22, z), Vector3.ZERO, foot.socket_id)
		root_gene.children.append(foot)
	return root_gene


func _single_leg_creature() -> PartGene:
	var root_gene := PartGene.new()
	root_gene.definition = _def(&"box", 1000.0, Vector3(0.5, 0.2, 0.8))
	root_gene.tags = [&"spine"]
	var leg := PartCatalog.clone_template(&"primitive_capsule")
	leg.tags = [&"locomotor", &"ground_contact"]
	leg.socket_id = &"limb_left_front"
	var point := SocketCatalog.point_for(root_gene, &"limb_left_front")
	leg.socket = SocketCatalog.socket_for_child(point, leg.socket_id, leg, &"top")
	root_gene.children.append(leg)
	return root_gene


func _all_locomotors_have_muscle(root_gene: PartGene, amount: float) -> bool:
	if root_gene == null:
		return true
	if root_gene.tags.has(&"locomotor"):
		if not root_gene.tags.has(&"muscle"):
			return false
		if absf(float(root_gene.dial_values.get(&"muscle_amount", 0.0)) - amount) > 0.001:
			return false
	for child in root_gene.children:
		if not _all_locomotors_have_muscle(child, amount):
			return false
	return true


func _def(part_type: StringName, density: float, extents: Vector3) -> PartDefinition:
	var d := PartDefinition.new()
	d.part_type = part_type
	d.density = density
	d.extents = extents
	return d


func _sock(pos: Vector3, hinge: Vector3, id: StringName) -> SocketDef:
	var s := SocketDef.new()
	s.id = id
	s.display_name = String(id)
	s.parent_attachment = Transform3D(Basis.IDENTITY, pos)
	s.child_anchor = Transform3D.IDENTITY
	s.hinge_axis = hinge
	return s


func _delete_resource(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path)
	if FileAccess.file_exists("%s.uid" % path):
		DirAccess.remove_absolute("%s.uid" % abs_path)


func _test_m56_attach_and_hinge() -> void:
	print("- M56: nub placement, attach-to-nub welds + consumes, in-viewport hinge editor")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "M56 Attach Test"
	card.root = _single_leg_creature()
	bench.load_card(card)
	# Place a nub on the root body (index 0).
	_check(bench.place_nub_at(0, Vector3(0.5, 0.0, 0.2), Vector3.UP), "place nub on the body accepted")
	_check(bench.nub_count(0) == 1, "body carries one nub")
	# Weld the existing leg (index 1) onto that nub; the nub is consumed.
	var nub_g := _part_gene_by_index(bench._session.root(), 0)
	var nub_id: StringName = nub_g.attach_points[0].id
	bench.select_part(1)
	_check(bench.attach_selected_to_nub(0, nub_id), "attach selected part to the nub accepted")
	_check(bench.nub_count(0) == 0, "the nub was consumed by the weld")
	# The leg is actuating -> the weld is hinged and the hinge editor auto-opened (rule 4).
	_check(bench.is_hinge_editing(), "actuating attach auto-opens the hinge editor")
	# Drive the limit handles through the editor verb.
	_check(bench.hinge_editor_set_limits(-0.8, 0.9), "hinge editor sets joint limits")
	var idx := bench.hinge_editor_index()
	var edited := _part_gene_by_index(bench._session.root(), idx)
	_check(edited != null and edited.joint != null
			and absf(edited.joint.angle_min + 0.8) < 1e-5
			and absf(edited.joint.angle_max - 0.9) < 1e-5,
			"limit edits land on the joint")
	bench.close_hinge_editor()
	_check(not bench.is_hinge_editing(), "hinge editor closes")
	# Manual Edit Hinge on a rigid part creates a default hinge to edit.
	bench.select_part(0)
	_check(not bench.open_hinge_editor(0), "hinge editor refuses the root part")
	bench.queue_free()


func _test_m55_surface() -> void:
	print("- M55 surface: track picker, fly mode, drive author, viability, grasp-aware measure, spar")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "M55 Surface Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	_check(bench.available_tracks().size() >= 8 and bench.available_tracks().has("curved"),
			"track picker exposes >=8 tracks incl. curved")
	_check(bench.available_modes().has("fly"), "mode picker includes fly")
	_check(bench.set_root_drive(0.4, 12.0, 1.5, 2.0), "drive author accepted")
	var gait: GaitDef = bench._session.root().gait
	_check(gait != null and absf(gait.turn_rate - 0.4) < 1e-6 and absf(gait.tear_omega - 12.0) < 1e-6,
			"turn_rate + tear_omega authored on the root gait")
	_check(bench.viability_summary().contains("HP"), "viability readout reports durability")
	var quip := await bench.spar_against()
	_check(quip.length() > 0, "spar produces a combat quip")
	bench.queue_free()


func _test_m58_display() -> void:
	print("- M58 display: mutation brush, palette round-trip, fossil ghost, toggles, stat card")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "M58 Display Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	bench.select_part(3)
	var g0 := _part_gene_by_index(bench._session.root(), 3)
	var y0 := g0.scale.y
	_check(bench.mutation_brush(&"lengthen"), "mutation brush lengthen accepted")
	var g1 := _part_gene_by_index(bench._session.root(), 3)
	_check(g1.scale.y > y0, "lengthen brush grows the part along Y")
	bench.set_palette_base(Color(0.9, 0.2, 0.2))
	bench.set_palette_pattern("glossy")
	_check(String(bench.creature_palette().get("pattern", "")) == "glossy", "palette pattern set")
	var ppath := "user://_m58_palette_test.tres"
	_check(bench.save_current_card(ppath) == OK, "save with palette")
	var reloaded := CreatureIO.load(ppath)
	_check(reloaded != null and String(reloaded.palette.get("pattern", "")) == "glossy",
			"palette round-trips through the saved card")
	bench.record_fossil({"ok": true, "trajectory": [Vector3.ZERO, Vector3(1, 0, 0)], "forward": 1.0})
	_check(bench.fossil_count() == 1, "measure run banks a fossil")
	bench.set_ghost_enabled(true)
	_check(bench._ghost_node != null, "Show Ghost spawns the ancestor body")
	bench.set_ghost_enabled(false)
	bench.set_force_xray(true)
	_check(bench.force_xray_enabled(), "force x-ray toggles on")
	bench.set_wireframe(true)
	_check(bench.wireframe_enabled(), "wireframe toggles on")
	bench.set_overlay_gizmos(true)
	_check(bench._overlay_node != null, "overlay gizmos build")
	bench.set_sonification_enabled(true)
	_check(bench.sonification_enabled(), "sonification toggles on")
	bench.set_force_xray(false)
	bench.set_wireframe(false)
	bench.set_overlay_gizmos(false)
	bench.set_sonification_enabled(false)
	bench.pump_scores_blocking()
	_check(bench._stat_card_label != null and bench._stat_card_label.text.length() > 0
			and not bench._stat_card_label.text.contains("no creature"),
			"stat card renders the creature identity")
	bench.queue_free()
	if FileAccess.file_exists(ppath):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ppath))


func _test_m57_copilot() -> void:
	print("- M57 co-pilot: query answer, preview+apply gate, scope guard, undo, codebase reader")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "M57 Copilot Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	var qres := bench.copilot_handle_response('{"tool":"query","args":{"what":"leg_count"}}')
	_check(bool(qres.get("ok", false)) and String(qres.get("answer", "")).contains("legs"),
			"query tool answers from the live genome")
	_check(not bench.copilot_has_pending(), "a query leaves no pending mutation")
	# Diagnostic question: with no Measure yet it must NOT misanswer (e.g. "13 parts") — it tells
	# you to Measure first. After a fake exploding Measure it explains the explosion.
	var nodiag := bench.copilot_handle_response('{"tool":"query","args":{"what":"diagnosis"}}')
	_check(String(nodiag.get("answer", "")).to_lower().contains("measure"),
			"diagnosis with no rollout asks you to Measure first (not a wrong fact)")
	bench._last_measured = {"ok": true, "teleport": true, "forward": 0.0}
	_check(EditorCopilot.diagnose(bench).to_lower().contains("explod"),
			"diagnosis reads a teleporting Measure as an explosion")
	var before := bench.part_count()
	bench.copilot_handle_response('{"tool":"add_part","args":{"part_id":"primitive_capsule"}}')
	_check(bench.copilot_has_pending(), "a mutation is staged as a pending call")
	_check(bench.part_count() == before, "nothing changes until Apply")
	bench.select_part(0)
	var ares := bench.copilot_apply()
	bench.pump_scores_blocking()
	_check(bool(ares.get("ok", false)) and bench.part_count() == before + 1,
			"Apply runs the staged edit through EditSession")
	_check(not bench.copilot_has_pending(), "applying clears the pending call")
	_check(bench.undo(), "co-pilot edit is undoable")
	bench.pump_scores_blocking()
	_check(bench.part_count() == before, "undo reverts the co-pilot edit")
	bench._copilot_scope.button_pressed = false
	bench.copilot_handle_response('{"tool":"set_mode","args":{"mode":"hop"}}')
	var sres := bench.copilot_apply()
	_check(bool(sres.get("needs_target", false)), "scope off -> mutation needs an explicit target")
	bench._copilot_scope.button_pressed = true
	_check(EditorCopilot.read_codebase("scripts/editor/attach_logic.gd").contains("AttachLogic"),
			"codebase reader returns allow-listed source")
	_check(EditorCopilot.read_codebase("../secrets.txt").contains("can't read"),
			"codebase reader refuses out-of-tree paths")
	bench.queue_free()


func _test_m54_shell() -> void:
	print("- M54 shell: parts breadcrumb, collapsible sections, and the tab overflow menu")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "M54 Shell Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	_check(bench._parts_breadcrumb != null and bench._parts_breadcrumb.text.begins_with("Parts:"),
			"parts breadcrumb summarizes the parts list")
	_check(bench._parts_breadcrumb.text.contains("(%d)" % bench.part_count()),
			"breadcrumb reports the part count")
	bench.select_parts([0], 0)
	_check(bench._parts_breadcrumb.text.contains("body"),
			"breadcrumb shows the selected part name (root = body)")
	bench._parts_breadcrumb.button_pressed = false
	_check(not bench._part_list.visible, "collapsing the breadcrumb hides the full part list")
	_check(bench._tab_overflow_popup != null
			and bench._tab_overflow_popup.item_count == bench.creature_tab_names().size(),
			"tab overflow menu lists every creature group")
	_check(bench.get_setting(&"sec_score") == false and bench.get_setting(&"sec_inspector") == true,
			"sections default per spec: Score collapsed, Inspector open")
	bench.queue_free()


func _test_apply_optimized_gait() -> void:
	print("- apply_optimized_gait writes a tuned gait (phases + scales) into the creature")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Opt Apply Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	var r = GaitOptimizer.Result.new()
	r.phases = {&"hip_BL": 0.3}
	r.amplitude_scale = 1.5
	r.frequency_scale = 0.8
	r.gain_scale = 1.2
	r.traction_scale = 0.4
	r.posture_scale = 0.6
	_check(bench.apply_optimized_gait(r), "apply accepted")
	var gait: GaitDef = bench._session.root().gait
	_check(gait != null and absf(float(gait.assignments.get(&"hip_BL", -1.0)) - 0.3) < 1e-6,
			"tuned phase written into the gait")
	_check(gait != null and absf(gait.amplitude_scale - 1.5) < 1e-6, "tuned amplitude scale written")
	_check(gait != null and absf(gait.traction_scale - 0.4) < 1e-6, "tuned traction scale written")
	_check(gait != null and absf(gait.posture_scale - 0.6) < 1e-6, "tuned posture scale written")
	bench.queue_free()


func _test_simulation() -> void:
	print("- watch-it-walk runs physics on the current creature inside the editor")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Sim Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)

	_check(bench.start_simulation(), "simulation starts")
	var viewer := bench.sim_viewer()
	_check(viewer != null, "sim viewer created")
	var sim_body: Node = viewer.body() if viewer != null else null
	_check(sim_body != null, "sim viewer built a physics body")
	var cog0: Vector3 = sim_body.measure()["cog"] if sim_body != null else Vector3.ZERO
	for _i in 45:
		await physics_frame
	var cog1: Vector3 = sim_body.measure()["cog"] if sim_body != null else Vector3.ZERO
	_check(cog0.distance_to(cog1) > 0.01, "creature actually moves under physics")
	bench.stop_simulation()
	_check(not bench.is_simulating(), "stop returns to the static editor view")
	bench.queue_free()
