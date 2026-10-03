extends SceneTree

## M50 — two-point attach + user-placed nubs. Nubs serialize on the genome (round-trip); consuming
## a nub welds a part at the exact spot and removes the nub; hinge-edit opens only on an actuating
## attach (rule 4). The interactive attach state machine + hinge gizmo are play-tested.

const AttachLogicScript := preload("res://scripts/editor/attach_logic.gd")

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
	print("=== M50 attach + nub tests ===")
	_test_nub_round_trips()
	_test_consume_welds_and_removes()
	_test_hinge_trigger_rule()
	_test_slot_state()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# E10: a user-placed nub survives GenomeSnapshot round-trip (else it'd vanish on save/load).
func _test_nub_round_trips() -> void:
	print("- a user-placed nub survives the genome round-trip")
	var g := PartCatalog.clone_template(&"body_small")
	AttachLogicScript.add_nub(g, Vector3(0.12, 0.05, -0.08), Vector3.UP, &"my_nub")
	var restored := GenomeSnapshot.from_dictionary(JSON.parse_string(JSON.stringify(
			GenomeSnapshot.to_dictionary(g))))
	_check(restored != null and restored.attach_points.size() == 1, "nub count survives reload")
	if restored != null and restored.attach_points.size() == 1:
		var ap := restored.attach_points[0]
		_check(ap.id == &"my_nub"
				and ap.local_pose.origin.is_equal_approx(Vector3(0.12, 0.05, -0.08)),
				"nub id + exact local position survive reload")


# Consuming a nub welds the child at the nub's exact spot and removes the nub.
func _test_consume_welds_and_removes() -> void:
	print("- consuming a nub welds the part at the exact spot and removes the nub")
	var parent := PartCatalog.clone_template(&"body_small")
	var spot := Vector3(0.2, 0.0, -0.1)
	AttachLogicScript.add_nub(parent, spot, Vector3.UP, &"nub_a")
	var child := PartCatalog.clone_template(&"leg_upper")
	var ok := AttachLogicScript.consume_nub(parent, &"nub_a", child, 0.0, Vector3(1, 0, 0))
	_check(ok, "consume_nub succeeds")
	_check(parent.attach_points.is_empty(), "the nub is consumed (removed)")
	_check(parent.children.has(child), "the child is attached to the parent")
	_check(child.socket != null and child.socket.parent_attachment.origin.is_equal_approx(spot),
			"the child welds at the nub's EXACT local position")
	_check(child.socket.hinge_axis == Vector3(1, 0, 0) and child.joint != null,
			"a hinged nub-attach makes a powered joint")


func _test_hinge_trigger_rule() -> void:
	print("- hinge-edit opens only when the actuating piece lands on a hinge (rule 4)")
	_check(AttachLogicScript.opens_hinge_edit(true, true), "actuating piece on a hinge -> open")
	_check(not AttachLogicScript.opens_hinge_edit(false, true), "non-actuating attach -> no open")
	_check(not AttachLogicScript.opens_hinge_edit(true, false), "no hinge -> no open")
	_check(not AttachLogicScript.opens_hinge_edit(false, false), "bare hinge creation -> no open")
	_check(AttachLogicScript.opens_hinge_edit(false, false, true), "explicit 'Edit hinge' -> open")


func _test_slot_state() -> void:
	print("- slot state reports free attachment points for the attach warnings")
	var g := PartCatalog.clone_template(&"leg_upper")   # template: no socket yet (proximal free)
	AttachLogicScript.add_nub(g, Vector3.ZERO, Vector3.UP, &"n")
	var s := AttachLogicScript.slot_state(g)
	_check(bool(s["both_free"]), "an unattached part with a nub has both slots free")
