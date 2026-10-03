extends SceneTree

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const LabControlContextScript := preload(
	"res://scripts/lab/control/lab_control_context.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab immutable controller-context contract ===")
	var mutable_spec := {
		"experiment_id": "CONTEXT_TEST",
		"controller_parameters": {"gain_ratio": 1.0},
	}
	var context = LabControlContextScript.new(mutable_spec, {"disturbance": 42})
	var original_hash := context.expanded_spec_sha256()
	mutable_spec["controller_parameters"]["gain_ratio"] = 999.0
	_check(
		float(context.expanded_experiment()["controller_parameters"]["gain_ratio"]) == 1.0,
		"retained authored dictionary cannot mutate controller-visible spec")
	_check(context.spec_is_unchanged(), "context verifies its frozen hash at the boundary")
	_check(
		CanonicalJsonScript.sha256(context.expanded_experiment()) == original_hash,
		"controller-visible expanded-spec hash remains stable")
	var stream: RefCounted = context.rng(&"disturbance")
	_check(stream != null, "registered named RNG stream is available")
	stream.call("randf")
	var manifest: Dictionary = context.rng_manifest_values()
	_check(int(manifest["disturbance"]["draw_count"]) == 1, "named stream accounts for every draw")
	_check(context.rng(&"unregistered") == null, "unregistered randomness is unavailable")
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
