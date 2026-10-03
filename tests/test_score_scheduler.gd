extends SceneTree
## F5 acceptance — live re-score concurrency contract (staleness, snapshot isolation,
## coalescing, real worker round-trip).
## Run: godot --headless --script res://tests/test_score_scheduler.gd   (exit 0 = all pass)

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

var _passed := 0
var _failed := 0

func _check(c: bool, l: String) -> void:
	if c: _passed += 1; print("  PASS  ", l)
	else: _failed += 1; printerr("  FAIL  ", l)


# ----------------------------- builders -----------------------------

func _def(pt: StringName, d: float, e: Vector3) -> PartDefinition:
	var x := PartDefinition.new(); x.part_type = pt; x.density = d; x.extents = e
	return x
func _sock(p: Vector3, h := Vector3.ZERO) -> SocketDef:
	var s := SocketDef.new(); s.parent_attachment = Transform3D(Basis.IDENTITY, p); s.hinge_axis = h
	return s
func _gene(defn: PartDefinition, tags: Array, socket: SocketDef = null) -> PartGene:
	var g := PartGene.new(); g.definition = defn
	var t: Array[StringName] = []
	for x in tags: t.append(x)
	g.tags = t; g.socket = socket
	return g
# Centered (stable) vs front-loaded (unstable) quad -> clearly different scores.
func _quad(front: bool) -> PartGene:
	var root := _gene(_def(&"box", 1000.0, Vector3(0.5,0.2,0.8)), [&"spine"])
	root.children.append(_gene(_def(&"box", 800.0, Vector3(0.3,0.3,0.3)), [&"heart"], _sock(Vector3.ZERO)))
	var leg := _def(&"capsule", 1000.0, Vector3(0.1,0.5,0.1))
	var pos = [Vector3(-0.4,-0.2,0.3),Vector3(0.4,-0.2,0.3),Vector3(-0.4,-0.2,0.7),Vector3(0.4,-0.2,0.7)] if front \
		else [Vector3(-0.4,-0.2,-0.6),Vector3(0.4,-0.2,-0.6),Vector3(-0.4,-0.2,0.6),Vector3(0.4,-0.2,0.6)]
	for p in pos:
		root.children.append(_gene(leg, [&"locomotor",&"ground_contact"], _sock(p, Vector3(1,0,0))))
	return root

func _sig(r: Dictionary) -> Array:
	var b: Dictionary = r["balance"]
	return [float(r["total_mass"]), float(r["body_radius"]), (1 if bool(b["stable"]) else 0),
		float(b["balance_margin"]), float(r["debt"]["debt_total"]), str(r["probe"]["verdict"])]
func _sig_eq(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if a[i] != b[i]: return false
	return true


# ----------------------------- tests -----------------------------

func _initialize() -> void:
	print("=== F5 score scheduler ===")
	_test_staleness_drop()
	_test_no_data_race_via_snapshot()
	_test_coalescing()
	_test_real_worker_roundtrip()
	_test_empty_lifecycle()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_staleness_drop() -> void:
	print("- dispatch A then B; A finishes last -> UI shows B (older dropped)")
	var sched := ScoreScheduler.new()
	var rootA := _quad(false)     # centered (stable)
	var rootB := _quad(true)      # front-loaded (unstable) -> different score
	var gA: int = sched.request(rootA)
	var jobA := sched.take_pending()
	var gB: int = sched.request(rootB)
	var jobB := sched.take_pending()
	var rA := CE.evaluate(jobA["snapshot"])
	var rB := CE.evaluate(jobB["snapshot"])
	_check(not _sig_eq(_sig(rA), _sig(rB)), "A and B genuinely differ (sanity)")
	# B completes first and is applied; A arrives late and must be dropped.
	_check(sched.accept(gB, rB) == true, "newer result B applied")
	_check(sched.accept(gA, rA) == false, "older result A dropped (stale)")
	_check(_sig_eq(_sig(sched.current()), _sig(rB)), "current result is B, not A")

func _test_no_data_race_via_snapshot() -> void:
	print("- mutating the live genome mid-eval cannot affect the in-flight result")
	var sched := ScoreScheduler.new()
	var root := _quad(false)
	var r_pre := CE.evaluate(root)
	sched.request(root)                          # snapshot taken here
	var job := sched.take_pending()
	# Main thread mutates the live genome AFTER dispatch.
	root.children[2].scale = Vector3(3, 3, 3)
	_check(not _sig_eq(_sig(r_pre), _sig(CE.evaluate(root))), "live mutation changed the live score (sanity)")
	_check(_sig_eq(_sig(r_pre), _sig(CE.evaluate(job["snapshot"]))), "in-flight snapshot == dispatch state, not the mutation")

func _test_coalescing() -> void:
	print("- N rapid requests -> exactly one (latest) dispatched")
	var sched := ScoreScheduler.new()
	var g := 0
	for i in 5:
		g = sched.request(_quad(i % 2 == 0))
	_check(sched.generation() == 5, "generation advanced once per request (=5)")
	var job := sched.take_pending()
	_check(not job.is_empty() and int(job["gen"]) == 5, "the one dispatched job is the latest (gen 5)")
	_check(sched.take_pending().is_empty(), "nothing else pending (intermediate edits coalesced away)")

func _test_real_worker_roundtrip() -> void:
	print("- evaluate() runs on a real worker thread and the result is applied")
	var sched := ScoreScheduler.new()
	var root := _quad(false)
	var expected := CE.evaluate(root)
	var g: int = sched.request(root)
	var out := sched.run_pending_blocking()
	_check(not out.is_empty() and bool(out["applied"]) and int(out["gen"]) == g, "worker result applied for the right generation")
	_check(_sig_eq(_sig(out["result"]), _sig(expected)), "worker-thread evaluate() == main-thread evaluate() (cross-thread determinism)")
	_check(_sig_eq(_sig(sched.current()), _sig(expected)), "scheduler.current() shows the worker result")

func _test_empty_lifecycle() -> void:
	print("- run with nothing pending is a clean no-op (no deadlock/leak)")
	var sched := ScoreScheduler.new()
	_check(sched.run_pending_blocking().is_empty(), "no pending -> empty result, no hang")
	_check(sched.applied_generation() == 0, "nothing applied yet")
