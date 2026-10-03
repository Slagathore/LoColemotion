extends SceneTree

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== SocketCatalog tests ===")
	_test_default_points_and_mapping()
	_test_can_attach_capacity_and_tags()
	_test_bench_add_child_part_at()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_default_points_and_mapping() -> void:
	print("- default points and socket-id mapping")
	var root := PartCatalog.make_quadruped(false)
	var ids: Array[StringName] = []
	for p in SocketCatalog.points_for(root.definition):
		ids.append(p.id)
	_check(ids.has(&"limb_left_front") and ids.has(&"body_front"), "box advertises semantic body/limb points")
	_check(SocketCatalog.socket_id_for_point(&"organ_top", 1, 3) == &"organ_top__01", "multi-capacity socket id encodes slot")
	_check(SocketCatalog.point_id_for_socket_id(&"organ_top__01") == &"organ_top", "reverse mapping recovers point id")
	_check(SocketCatalog.socket_id_for_point(&"limb_left_front", 0, 1) == &"limb_left_front", "capacity-one socket id is point id")
	_check(ids.has(&"limb_left_upper") and ids.has(&"limb_right_upper") and ids.has(&"organ_core"),
			"box advertises extra anchors (upper limbs, organ core)")
	var cap := PartCatalog.clone_template(&"primitive_capsule")
	var cap_ids: Array[StringName] = []
	for p in SocketCatalog.points_for(cap.definition):
		cap_ids.append(p.id)
	_check(cap_ids.has(&"mid_left") and cap_ids.has(&"mid_right"), "capsule advertises mid-side anchors")


func _test_can_attach_capacity_and_tags() -> void:
	print("- can_attach enforces hard legality")
	var parent := PartCatalog.make_quadruped(false)
	var leg := PartCatalog.clone_template(&"primitive_capsule")
	var heart := PartCatalog.clone_template(&"organ_heart")
	var leg_tags: Array[StringName] = []
	leg_tags.assign(leg.tags)
	var heart_tags: Array[StringName] = []
	heart_tags.assign(heart.tags)
	_check(bool(SocketCatalog.can_attach(parent, &"limb_left_front", leg_tags)["ok"]), "free compatible limb point accepts leg")
	_check(not bool(SocketCatalog.can_attach(parent, &"limb_left_front", heart_tags)["ok"]), "limb point rejects organ tag")
	var occupied := PartCatalog.clone_template(&"primitive_capsule")
	occupied.socket_id = &"limb_left_front"
	parent.children.append(occupied)
	_check(not bool(SocketCatalog.can_attach(parent, &"limb_left_front", leg_tags)["ok"]), "capacity-one point rejects second child")
	_check(bool(SocketCatalog.can_attach(parent, &"organ_top", heart_tags)["ok"]), "multi-capacity organ point accepts first organ")


func _test_bench_add_child_part_at() -> void:
	print("- bench docks a child at a named legal point")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.display_name = "Socket Test"
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)
	var before := bench.part_count()
	_check(bench.add_child_part_at(&"primitive_capsule", 0, &"limb_left_front"), "legal point add succeeds")
	bench.pump_scores_blocking()
	_check(bench.part_count() == before + 1, "part count increases after legal point add")
	var g := _last_child(bench)
	_check(g != null and g.socket_id == &"limb_left_front", "child uses point id as socket id")
	_check(g != null and g.socket != null and g.socket.hinge_axis == Vector3.RIGHT, "child receives point hinge axis")
	_check(g != null and g.socket != null and g.socket.child_anchor.origin.y < 0.0,
			"locomotor child docks by its top anchor instead of its center")
	_check(not bench.add_child_part_at(&"organ_heart", 0, &"limb_left_front"), "illegal occupied/mismatched add refuses")
	bench.queue_free()


func _last_child(bench: EditorBench) -> PartGene:
	var root_gene := bench._session.root()
	if root_gene.children.is_empty():
		return null
	return root_gene.children[root_gene.children.size() - 1]
