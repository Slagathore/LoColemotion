extends SceneTree

const ComparisonRunnerScript := preload(
	"res://scripts/lab/comparison_runner.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab paired-comparison contract ===")
	var control := {
		"root_seed": 42,
		"observer_profile_id": "full_state_v1",
		"controller_parameters": {"brace_enabled": false, "gain_ratio": 1.0},
	}
	var intervention := control.duplicate(true)
	intervention["controller_parameters"]["brace_enabled"] = true
	var accepted: Dictionary = ComparisonRunnerScript.compare_specs(
		"cmp_brace", "control", "intervention", control, intervention,
		"/controller_parameters/brace_enabled")
	_check(
		accepted["evidence_validity"] == "valid",
		"exactly one preregistered difference is valid")
	_check(
		accepted["declared_diff_paths"]
			== ["/controller_parameters/brace_enabled"],
		"actual difference path is explicit")
	intervention["root_seed"] = 99
	var rejected: Dictionary = ComparisonRunnerScript.compare_specs(
		"cmp_bad", "control", "intervention", control, intervention,
		"/controller_parameters/brace_enabled")
	_check(
		rejected["evidence_validity"] == "invalid",
		"undeclared seed difference invalidates causal comparison")
	_check(
		rejected["declared_diff_paths"].has("/root_seed"),
		"validator identifies the undeclared nuisance difference")
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
