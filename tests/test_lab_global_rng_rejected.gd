extends SceneTree

const ControllerGateScript := preload(
	"res://scripts/lab/controller_capability_gate.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab controller RNG capability gate ===")
	var accepted: Dictionary = ControllerGateScript.inspect_source("""
func decide(context):
	var disturbance = context.rng(&"disturbance")
	return disturbance.randf()
""")
	var rejected_global: Dictionary = ControllerGateScript.inspect_source("""
func decide(_context):
	return randf()
""")
	var rejected_owned: Dictionary = ControllerGateScript.inspect_source("""
var _rng := RandomNumberGenerator.new()
func decide(_context):
	_rng.seed = 9
	return _rng.randf()
""")
	var comment_only: Dictionary = ControllerGateScript.inspect_source("""
# randf() and RandomNumberGenerator are forbidden, but this is only documentation.
func decide(context):
	return context.rng(&"disturbance").randf()
""")
	_check(bool(accepted["ok"]), "draw through registered context capability is accepted")
	_check(not bool(rejected_global["ok"]), "unqualified global randf is rejected")
	_check(not bool(rejected_owned["ok"]), "controller-owned RNG/seed state is rejected")
	_check(bool(comment_only["ok"]), "comments do not trigger false RNG violations")
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
