extends SceneTree

## Regression for runner-versus-sealed-stream numeric identity.
##
## At 120 Hz, calculating summary residuals from pre-serialization floats
## produced values about 1e-6 away from the independent verifier reading the
## canonical JSON bytes. That made an otherwise valid physical run impossible
## to finalize. This test requires the summary to be authored from the same
## canonical representation that is actually sealed.

const BundleValidatorScript := preload(
	"res://scripts/lab/run_bundle_validator.gd")
const LabRunnerScript := preload("res://scripts/lab/lab_runner.gd")
const SpecCompilerScript := preload("res://scripts/lab/spec_compiler.gd")

const SPEC_PATH := (
	"res://data/lab/experiments/br1/"
	+ "BR1_L0_1_free_fall_120hz_v1.tres")
const RECOMPUTER_ID := "sporespore.lab.l0_unary_metric_recomputer.v1"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab L0 sealed numeric identity ===")
	var loaded = ResourceLoader.load(
		SPEC_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var resource_sha := "sha256:%s" % FileAccess.get_sha256(SPEC_PATH)
	var compiled := SpecCompilerScript.compile(
		loaded,
		{},
		{},
		{
			"resource_path": SPEC_PATH,
			"resource_sha256": resource_sha,
		})
	_check(
		bool(compiled.get("ok", false)),
		"the preregistered 120 Hz cell compiles")
	if not bool(compiled.get("ok", false)):
		_finish("")
		return

	var root := ProjectSettings.globalize_path(
		"res://.tmp/lab_l0_sealed_numeric_identity_%d_%d" % [
			OS.get_process_id(),
			Time.get_ticks_usec(),
		]).replace("\\", "/")
	var runner = LabRunnerScript.new()
	var run_result: Dictionary = await runner.run(
		self,
		compiled["experiment"],
		root,
		{
			"resource_path": SPEC_PATH,
			"resource_sha256": resource_sha,
		})
	var bundle_path := String(run_result.get("artifacts", ""))
	_check(
		run_result.get("termination") == "completed"
			and int(run_result.get("exit_code", -1)) == 2
			and not bundle_path.is_empty(),
		"120 Hz direct evidence completes without semantic-finalization drift")
	if bundle_path.is_empty() \
			or not DirAccess.dir_exists_absolute(bundle_path):
		printerr("  RUN DIAGNOSTIC  ", run_result)
		_finish(root)
		return

	var validation := BundleValidatorScript.validate_bundle(bundle_path)
	var semantic: Dictionary = validation.get(
		"stats", {}).get("semantic_verifiers", {}).get(RECOMPUTER_ID, {})
	_check(
		bool(validation.get("ok", false))
			and bool(validation.get("can_finalize", false))
			and bool(semantic.get("ok", false)),
		"sealed bytes independently reproduce every stored unary conclusion")
	var checked_ids: Array[String] = []
	var all_checks_pass := true
	for check_value in semantic.get("metric_checks", []):
		var check: Dictionary = check_value
		checked_ids.append(String(check.get("metric_id", "")))
		all_checks_pass = all_checks_pass and bool(check.get("pass", false))
	_check(
		all_checks_pass
			and "max_velocity_error_m_s" in checked_ids
			and "max_momentum_error_kg_m_s" in checked_ids,
		"velocity and momentum residuals match after canonical round-trip")
	_check(
		bool(run_result.get("physical_gate", {}).get("pass", false)),
		"numeric identity repair does not weaken the preregistered physical gate")
	if not bool(validation.get("ok", false)):
		printerr("  VALIDATION DIAGNOSTIC  ", validation)
	_finish(root)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish(root: String) -> void:
	if not root.is_empty():
		_remove_tree(root)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


static func _remove_tree(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child in directory.get_files():
		directory.remove(child)
	for child in directory.get_directories():
		_remove_tree(path.path_join(child))
		directory.remove(child)
	DirAccess.remove_absolute(path)
