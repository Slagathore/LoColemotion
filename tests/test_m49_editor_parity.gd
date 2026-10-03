extends SceneTree

## M49 — editor parity (testable backbone). Surfacing accessors (tracks incl. curved, modes incl.
## fly, .glb import, settings), and the LLM co-pilot's tool-router acting ONLY through EditSession
## (undoable, scoped, truthful). The chat dock / HFlowContainer reflow / collapsible panels / tab
## overflow / parts breadcrumb RENDERING is play-tested.

const EditorCopilotScript := preload("res://scripts/editor/editor_copilot.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _run() -> void:
	print("=== M49 editor parity tests ===")
	_test_surfacing()
	_test_copilot()
	_test_card_stats()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_surfacing() -> void:
	print("- the editor surfaces every track, mode, import, and setting")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.root = PartCatalog.make_demo_creature(&"bare")
	bench.load_card(card)
	var tracks := bench.available_tracks()
	_check(tracks.has("curved") and tracks.size() >= 8, "track picker exposes curved + the full set")
	_check(bench.available_modes().has("fly"), "mode picker includes fly (M52)")
	bench.select_part(0)
	_check(bench.import_mesh_for_selected("user://_x.glb"), "a .glb can be imported onto a part")
	bench.set_setting(&"llm_model", "qwen2.5")
	_check(String(bench.get_setting(&"llm_model")) == "qwen2.5", "settings store the LLM model")
	_check(bench.get_setting(&"wireframe") == false, "settings expose the wireframe toggle")
	bench.queue_free()


func _test_copilot() -> void:
	print("- the co-pilot acts only through EditSession (undoable, scoped, truthful)")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.root = PartCatalog.make_demo_creature(&"bare")
	bench.load_card(card)
	# A scoped query answers from the live genome (truthful).
	var q := EditorCopilotScript.execute(bench, {"tool": &"query", "args": {"what": &"leg_count"}})
	_check(bool(q["ok"]) and String(q["answer"]).contains("legs"), "co-pilot answers a scoped query")
	# A scoped mutation routes through the editor verb + is undoable.
	EditorCopilotScript.execute(bench, {"tool": &"select", "args": {"index": 4}})
	var before := _spring_count(bench.current_root())
	var r := EditorCopilotScript.execute(bench, {"tool": &"set_spring",
			"args": {"stiffness": 240.0}})
	_check(bool(r["ok"]) and bool(r["undoable"]), "co-pilot set_spring applies + is undoable")
	_check(_spring_count(bench.current_root()) > before, "the edit actually changed the genome")
	bench.undo()
	_check(_spring_count(bench.current_root()) == before, "undo reverts the co-pilot's edit")
	# An out-of-scope mutation refuses to silently touch the current creature.
	var oos := EditorCopilotScript.execute(bench, {"tool": &"set_spring", "scope": &"all",
			"args": {"stiffness": 999.0}})
	_check(not bool(oos["ok"]) and bool(oos.get("needs_target", false)),
			"an out-of-scope edit names its target before applying (scope checkbox)")
	bench.queue_free()


func _test_card_stats() -> void:
	print("- FUN-4 creature stat card pulls a name + live stats")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.root = PartCatalog.make_demo_creature(&"muscle")
	bench.load_card(card)
	var stats := bench.creature_card_stats()
	_check(String(stats.get("name", "")).length() > 0 and int(stats.get("part_count", 0)) > 0,
			"stat card has a morphology name + part count")
	bench.queue_free()


func _spring_count(g: PartGene) -> int:
	if g == null:
		return 0
	var n := 1 if g.spring != null else 0
	for c in g.children:
		n += _spring_count(c)
	return n
