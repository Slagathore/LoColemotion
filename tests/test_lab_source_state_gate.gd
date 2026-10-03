extends SceneTree

const SourceStateGateScript := preload("res://scripts/lab/source_state_gate.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab source-state promotion gate ===")
	var hashes := {
		"res://fixture.gd":
			"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
	}
	var clean: Dictionary = SourceStateGateScript.assess(
		"0123456789abcdef0123456789abcdef01234567", false, hashes)
	var dirty: Dictionary = SourceStateGateScript.assess(
		"0123456789abcdef0123456789abcdef01234567", true, hashes)
	var unresolved: Dictionary = SourceStateGateScript.assess(
		"CURRENT_OR_EXPLICIT_DIRTY", false, hashes)
	var empty_hashes: Dictionary = SourceStateGateScript.assess(
		"0123456789abcdef0123456789abcdef01234567", false, {})
	_check(bool(clean["pass"]), "clean committed source with loaded hashes may promote")
	_check(not bool(dirty["pass"]), "dirty worktree cannot promote")
	_check(dirty["execution_mode"] == "development", "dirty run remains labeled development")
	_check(not bool(unresolved["pass"]), "unresolved commit identity cannot promote")
	_check(
		not bool(empty_hashes["pass"])
			and empty_hashes["reasons"].has("LOADED_RESOURCE_HASHES_EMPTY"),
		"promotion cannot pass without a source-resource inventory")
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
