extends SceneTree

## Headless BR1 entry point.
##
## Example:
##   godot --headless --path . --script res://scripts/lab/run_lab.gd -- \
##     --experiment-spec res://data/lab/experiments/L0_0_stationary_gravity_off_v1.tres \
##     --seed 42 --observer full_contacts_v1 --output-root user://lab/runs

const LabRunnerScript := preload("res://scripts/lab/lab_runner.gd")
const ProcessLauncherScript := preload(
	"res://scripts/lab/lab_process_launcher.gd")
const SpecCompilerScript := preload("res://scripts/lab/spec_compiler.gd")

const EXIT_PASS := 0
const EXIT_PHYSICAL_OR_PROMOTION_FAIL := 2
const EXIT_EVIDENCE_INVALID := 3
const EXIT_CONFIGURATION_ERROR := 4
const EXIT_CONTROLLED_ABORT := 5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var user_arguments := OS.get_cmdline_user_args()
	if not user_arguments.is_empty() \
			and String(user_arguments[0]) == "--child-launch-plan":
		await _run_reserved_child(user_arguments)
		return
	var parsed := _parse_arguments(user_arguments)
	if not parsed["ok"]:
		printerr("LAB configuration_error=%s" % parsed["error"])
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var options: Dictionary = parsed["options"]
	var spec_path := String(options["experiment_spec"])
	if not spec_path.begins_with("res://") or not spec_path.ends_with(".tres"):
		printerr("LAB configuration_error=experiment spec must be one res:// .tres resource")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	if not FileAccess.file_exists(spec_path):
		printerr("LAB configuration_error=experiment spec does not exist: %s" % spec_path)
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var loaded = ResourceLoader.load(spec_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not loaded.has_method("to_value_dictionary"):
		printerr("LAB configuration_error=resource is not an ExperimentSpec: %s" % spec_path)
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var resource_sha := "sha256:%s" % FileAccess.get_sha256(spec_path)
	var overrides: Dictionary = {}
	if options.has("seed"):
		overrides["root_seed"] = options["seed"]
	if options.has("observer"):
		overrides["observer_profile_id"] = options["observer"]
	var compiled: Dictionary = SpecCompilerScript.compile(
		loaded,
		{},
		overrides,
		{
			"resource_path": spec_path,
			"resource_sha256": resource_sha,
		})
	if not compiled["ok"]:
		printerr("LAB configuration_error=spec compilation failed")
		for error in compiled["errors"]:
			printerr("LAB error code=%s path=%s message=%s" % [
				error.get("code", "UNKNOWN"),
				error.get("path", "/"),
				error.get("message", ""),
			])
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var experiment: RefCounted = compiled["experiment"]
	var expanded: Dictionary = experiment.call("value")
	print("LAB resolved_spec=%s" % spec_path)
	print("LAB experiment_resource_sha256=%s" % resource_sha)
	print("LAB expanded_spec_sha256=%s" % experiment.call("expanded_spec_sha256"))
	print("LAB experiment=%s seed=%d observer=%s" % [
		expanded["experiment_id"],
		int(expanded["root_seed"]),
		expanded["observer_profile_id"],
	])
	if bool(options.get("validate_only", false)):
		print("LAB validation=valid spawned_physics=false artifact_directory_created=false")
		quit(EXIT_PASS)
		return

	if String(expanded["experiment_id"]) == "L0_4_TRACE_PLAYBACK":
		var replay_path := String(options.get("replay_bundle", ""))
		if replay_path.is_empty():
			printerr("LAB configuration_error=L0_4 requires --replay-bundle <completed-run>")
			quit(EXIT_CONFIGURATION_ERROR)
			return
		var replay: Dictionary = LabRunnerScript.replay_bundle(
			replay_path, _attestation_validation_options(options))
		if not replay["ok"]:
			printerr("LAB replay=failed code=%s" % replay.get("code", "TRACE_REPLAY_FAILED"))
			quit(int(replay.get("exit_code", EXIT_EVIDENCE_INVALID)))
			return
		print("LAB replay=pass simulation_steps=0 run_id=%s frames=%d events=%d" % [
			replay["run_id"],
			replay["timeline"].size(),
			replay["event_order"].size(),
		])
		quit(EXIT_PASS)
		return

	var output_root := String(options.get("output_root", "user://lab/runs"))
	if not _safe_output_root(output_root):
		printerr("LAB configuration_error=unsafe output root")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var runner = LabRunnerScript.new()
	var result: Dictionary = await runner.run(
		self,
		experiment,
		output_root,
		{
			"resource_path": spec_path,
			"resource_sha256": resource_sha,
		})
	if not bool(result.get("ok", false)) \
			and String(result.get("termination", "")) == "aborted":
		printerr("LAB controlled_abort code=%s run_id=%s" % [
			result.get("code", "CONTROLLED_ABORT"),
			result.get("run_id", ""),
		])
		printerr("LAB artifacts=%s" % result.get("artifacts", ""))
		quit(int(result.get("exit_code", EXIT_CONTROLLED_ABORT)))
		return
	if not result.has("run_id"):
		printerr("LAB run_failed code=%s" % result.get("code", "UNKNOWN"))
		if result.get("details") != null:
			printerr("LAB details=%s" % str(result["details"]))
		quit(int(result.get("exit_code", EXIT_CONTROLLED_ABORT)))
		return
	print("LAB run_id=%s" % result["run_id"])
	print("LAB termination=%s evidence_validity=%s" % [
		result["termination"],
		result["evidence_validity"],
	])
	print("LAB hypothesis_result=%s promotion=%s" % [
		result["hypothesis_result"],
		result["promotion"],
	])
	print("LAB physical_gate=%s source_state_gate=%s" % [
		"pass" if result["physical_gate"]["pass"] else "fail",
		"pass" if result["source_state_gate"]["pass"] else "blocked",
	])
	print("LAB artifacts=%s" % result["artifacts"])
	quit(int(result["exit_code"]))


func _run_reserved_child(arguments: PackedStringArray) -> void:
	if arguments.size() != 2:
		printerr("LAB child_configuration_error=exactly one launch-plan path is required")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var launch_plan_path := String(arguments[1])
	if not launch_plan_path.is_absolute_path():
		printerr("LAB child_configuration_error=launch-plan path must be absolute")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var loaded_plan: Dictionary = ProcessLauncherScript.load_launch_plan(
		launch_plan_path)
	if not loaded_plan["ok"]:
		printerr("LAB child_configuration_error=%s" % loaded_plan.get(
			"error", "LAUNCH_PLAN_INVALID"))
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var plan: Dictionary = loaded_plan["plan"]
	var payload: Dictionary = plan["payload"]
	if payload["user_arguments"] != Array(arguments):
		printerr("LAB child_configuration_error=runtime argv differs from frozen launch plan")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	if String(payload["run_id"]) != String(plan["run_id"]) \
			or String(payload["reservation_id"]) \
				!= String(plan["reservation_id"]):
		printerr("LAB child_configuration_error=launch-plan identity mismatch")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var identity: Dictionary = payload["experiment_identity"]
	var spec_path := String(identity.get("resource_path", ""))
	if not spec_path.begins_with("res://") \
			or not FileAccess.file_exists(spec_path):
		printerr("LAB child_configuration_error=planned experiment resource is absent")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var live_resource_sha := "sha256:%s" % FileAccess.get_sha256(spec_path)
	if live_resource_sha != String(identity.get("resource_sha256", "")):
		printerr("LAB child_configuration_error=experiment bytes changed after reservation")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var loaded = ResourceLoader.load(
		spec_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not loaded.has_method("to_value_dictionary"):
		printerr("LAB child_configuration_error=planned resource is not an ExperimentSpec")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var overrides := {
		"root_seed": int(identity["root_seed"]),
		"observer_profile_id": String(identity["observer_profile_id"]),
	}
	var compiled: Dictionary = SpecCompilerScript.compile(
		loaded,
		{},
		overrides,
		{
			"resource_path": spec_path,
			"resource_sha256": live_resource_sha,
		})
	if not compiled["ok"]:
		printerr("LAB child_configuration_error=planned spec compilation failed")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var experiment: RefCounted = compiled["experiment"]
	if String(experiment.call("expanded_spec_sha256")) \
			!= String(identity.get("expanded_spec_sha256", "")):
		printerr("LAB child_configuration_error=expanded spec differs from frozen launch plan")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var lifecycle_context := {
		"mode": "reserved_child",
		"run_id": String(plan["run_id"]),
		"reservation_id": String(plan["reservation_id"]),
		"partial_path": String(payload["partial_path"]),
		"final_path": String(payload["final_path"]),
		"token_descriptor_path":
			String(payload["token_descriptor_path"]),
		"launch_plan_path": String(loaded_plan["path"]),
		"launch_plan_sha256": String(loaded_plan["sha256"]),
	}
	var runner = LabRunnerScript.new()
	var result: Dictionary = await runner.run(
		self,
		experiment,
		String(payload["output_root"]),
		{
			"resource_path": spec_path,
			"resource_sha256": live_resource_sha,
		},
		lifecycle_context)
	if not bool(result.get("ok", false)):
		printerr("LAB child_run_failed code=%s run_id=%s" % [
			result.get("code", "UNKNOWN"),
			result.get("run_id", plan["run_id"]),
		])
		quit(int(result.get("exit_code", EXIT_CONTROLLED_ABORT)))
		return
	if not bool(result.get("candidate_ready", false)):
		printerr("LAB child_run_failed code=CANDIDATE_NOT_READY")
		quit(EXIT_EVIDENCE_INVALID)
		return
	print("LAB child_candidate_ready run_id=%s path=%s" % [
		result["run_id"],
		result["artifacts"],
	])
	quit(EXIT_PASS)


static func _parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var options: Dictionary = {
		"validate_only": false,
		"output_root": "user://lab/runs",
	}
	var seen: Dictionary = {}
	var index := 0
	while index < arguments.size():
		var argument := String(arguments[index])
		if argument == "--validate-only":
			if seen.has(argument):
				return _parse_failure("duplicate --validate-only")
			seen[argument] = true
			options["validate_only"] = true
			index += 1
			continue
		if argument in [
			"--experiment-spec",
			"--seed",
			"--observer",
			"--output-root",
			"--replay-bundle",
			"--engine-log-path",
			"--attestation-test-root",
		]:
			if seen.has(argument):
				return _parse_failure("duplicate argument: %s" % argument)
			if index + 1 >= arguments.size():
				return _parse_failure("missing value for %s" % argument)
			seen[argument] = true
			var value := String(arguments[index + 1])
			match argument:
				"--experiment-spec":
					options["experiment_spec"] = value
				"--seed":
					if not value.is_valid_int():
						return _parse_failure("--seed must be an integer")
					options["seed"] = int(value)
				"--observer":
					options["observer"] = value
				"--output-root":
					options["output_root"] = value
				"--replay-bundle":
					options["replay_bundle"] = value
				"--engine-log-path":
					if not value.is_absolute_path():
						return _parse_failure(
							"--engine-log-path must be an absolute path")
					options["engine_log_path"] = value
				"--attestation-test-root":
					if not value.is_absolute_path():
						return _parse_failure(
							"--attestation-test-root must be an absolute path")
					options["attestation_test_root"] = value
			index += 2
			continue
		if argument in ["--seed-set", "--sweep"]:
			return _parse_failure(
				"%s is reserved for the isolated campaign launcher and is not accepted by a single-run process"
					% argument)
		return _parse_failure("unknown argument: %s" % argument)
	if not options.has("experiment_spec"):
		return _parse_failure("--experiment-spec is required exactly once")
	return {"ok": true, "options": options}


static func _parse_failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "options": {}}


static func _safe_output_root(path: String) -> bool:
	if path.is_empty() or path.contains("..") or path.begins_with("res://"):
		return false
	return path.begins_with("user://") or path.is_absolute_path()


static func _attestation_validation_options(options: Dictionary) -> Dictionary:
	var validation_options := {
		"attestation_requirement": "required",
	}
	var test_root := String(options.get(
		"attestation_test_root", "")).strip_edges()
	if not test_root.is_empty():
		validation_options["attestation_test_root"] = test_root
	return validation_options
