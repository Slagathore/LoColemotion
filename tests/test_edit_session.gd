extends SceneTree
## P0 spine acceptance: EditSession + GenomeHistory.
## Pins the four load-bearing editor invariants headless, before any UI exists:
##   undo restores the prior tree, undo/redo never alias the live tree (I3),
##   an aliasing edit is rejected (I3), and the score is never stale (I4).
## Run: godot --headless --path . --script res://tests/test_edit_session.gd

var _passed := 0
var _failed := 0

func _initialize() -> void:
    print("=== EditSession (P0 spine) tests ===")
    _test_undo_restores_prior_tree()
    _test_undo_installs_fresh_copy_no_alias()
    _test_redo_restores_edited_tree()
    _test_aliasing_edit_rejected()
    _test_no_stale_score_after_rapid_edits()
    print("=== %d passed, %d failed ===" % [_passed, _failed])
    quit(0 if _failed == 0 else 1)

func _check(cond: bool, label: String) -> void:
    if cond:
        _passed += 1
        print("  PASS  ", label)
    else:
        _failed += 1
        printerr("  FAIL  ", label)

# --- fixtures -------------------------------------------------------------
func _tags(arr: Array) -> Array[StringName]:
    var t: Array[StringName] = []
    for x in arr:
        t.append(x)
    return t

func _def(pt: StringName, density: float, extents: Vector3) -> PartDefinition:
    var d := PartDefinition.new()
    d.part_type = pt
    d.density = density
    d.extents = extents
    return d

func _sock(pos: Vector3) -> SocketDef:
    var s := SocketDef.new()
    s.parent_attachment = Transform3D(Basis.IDENTITY, pos)
    s.child_anchor = Transform3D.IDENTITY
    return s

func _gene(defn: PartDefinition, tags: Array, socket: SocketDef = null, scale := Vector3.ONE) -> PartGene:
    var g := PartGene.new()
    g.definition = defn
    g.tags = _tags(tags)
    g.socket = socket
    g.scale = scale
    return g

func _simple() -> PartGene:
    # root box + two legs, distinct sub-resources (a legal tree).
    var root := _gene(_def(&"box", 1000.0, Vector3(0.3, 0.3, 0.3)), [&"spine", &"ground_contact"])
    root.children.append(_gene(_def(&"box", 1000.0, Vector3(0.1, 0.2, 0.1)), [&"locomotor", &"ground_contact"], _sock(Vector3(0.4, 0, 0))))
    root.children.append(_gene(_def(&"box", 1000.0, Vector3(0.1, 0.2, 0.1)), [&"locomotor", &"ground_contact"], _sock(Vector3(-0.4, 0, 0))))
    return root

# --- tests ----------------------------------------------------------------
func _test_undo_restores_prior_tree() -> void:
    print("- undo restores the pre-edit tree")
    var s := EditSession.new(_simple())
    var before := s.root().scale
    var ok := s.apply_edit(func(r): r.scale = Vector3(2, 2, 2))
    _check(ok and s.root().scale == Vector3(2, 2, 2), "edit applied (scale -> 2,2,2)")
    _check(s.undo() and s.root().scale == before, "undo restored scale and structure")
    _check(s.root().children.size() == 2, "child count intact after undo")

func _test_undo_installs_fresh_copy_no_alias() -> void:
    print("- undo/redo install a FRESH deep copy (no aliasing of the live tree)")
    var s := EditSession.new(_simple())
    var id_initial := s.root().get_instance_id()
    s.apply_edit(func(r): r.scale = Vector3(3, 3, 3))
    s.undo()
    _check(s.root().get_instance_id() != id_initial, "post-undo root is a distinct instance, not the original frame")
    # Corrupting the post-undo live tree must not poison a redo/undo cycle.
    s.root().scale = Vector3(9, 9, 9)
    s.redo()
    _check(s.root().scale == Vector3(3, 3, 3), "redo unaffected by mutation of the live tree (frames not aliased)")

func _test_redo_restores_edited_tree() -> void:
    print("- redo restores the edited tree exactly")
    var s := EditSession.new(_simple())
    s.apply_edit(func(r): r.scale = Vector3(2, 2, 2))
    s.undo()
    _check(s.redo() and s.root().scale == Vector3(2, 2, 2), "redo re-applied the edit")
    _check(not s.can_redo(), "redo stack emptied after redo")

func _test_aliasing_edit_rejected() -> void:
    print("- an edit that aliases a sub-resource is rejected, live tree untouched")
    var s := EditSession.new(_simple())
    var before_children := s.root().children.size()
    var ok := s.apply_edit(func(r):
        var shared := SocketDef.new()                       # ONE socket...
        var a := PartGene.new(); a.definition = _def(&"box", 1000.0, Vector3.ONE); a.socket = shared
        var b := PartGene.new(); b.definition = _def(&"box", 1000.0, Vector3.ONE); b.socket = shared  # ...shared by two genes
        r.children.append(a)
        r.children.append(b))
    _check(not ok, "apply_edit returned false on aliased SocketDef")
    _check(s.root().children.size() == before_children, "live tree unchanged by the rejected edit")
    _check(s.last_error().contains("SocketDef") or s.last_error().contains("shared"), "rejection carries a clear reason")

func _test_no_stale_score_after_rapid_edits() -> void:
    print("- rapid edits coalesce; the applied score is the latest generation (I4)")
    var s := EditSession.new(_simple())
    s.apply_edit(func(r): r.scale = Vector3(1.1, 1.1, 1.1))
    s.apply_edit(func(r): r.scale = Vector3(1.2, 1.2, 1.2))
    s.apply_edit(func(r): r.scale = Vector3(1.3, 1.3, 1.3))
    var applied := s.pump_blocking()
    _check(applied, "a score was applied by the blocking pump")
    _check(s.scheduler().applied_generation() == s.scheduler().generation(), "applied generation == latest requested (no stale verdict)")
    _check(not s.current_score().is_empty() and s.current_score().has("total_mass"), "current score is a real evaluate() result")
