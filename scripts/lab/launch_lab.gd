extends SceneTree

## Canonical outer-process lab entry point.
##
## This process owns reservation and publication.  Every physics experiment is
## executed by a fresh Godot child which can only prepare candidate evidence.
##
## Example:
##   godot --headless --path . --script res://scripts/lab/launch_lab.gd -- \
##     --experiment-spec res://data/lab/experiments/L0_0_stationary_gravity_off_v1.tres \
##     --seed 42 --observer full_contacts_v1 --output-root <absolute-output-path>

const LabRunnerScript := preload("res://scripts/lab/lab_runner.gd")
const FinalizerScript := preload("res://scripts/lab/lab_run_finalizer.gd")
const ProcessLauncherScript := preload(
	"res://scripts/lab/lab_process_launcher.gd")
const RunIndexScript := preload("res://scripts/lab/run_index.gd")
const SpecCompilerScript := preload("res://scripts/lab/spec_compiler.gd")
const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")

const EXIT_PASS := 0
const EXIT_PHYSICAL_OR_PROMOTION_FAIL := 2
const EXIT_EVIDENCE_INVALID := 3
const EXIT_CONFIGURATION_ERROR := 4
const EXIT_CONTROLLED_ABORT := 5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var requested_arguments := OS.get_cmdline_user_args()
	var parsed := _parse_arguments(requested_arguments)
	if not parsed["ok"]:
		printerr("LAB launcher_configuration_error=%s" % parsed["error"])
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var options: Dictionary = parsed["options"]
	var compiled_result := _compile(options)
	if not compiled_result["ok"]:
		printerr("LAB launcher_configuration_error=%s" % compiled_result["error"])
		for error in compiled_result.get("details", []):
			printerr("LAB error=%s" % str(error))
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var experiment: RefCounted = compiled_result["experiment"]
	var expanded: Dictionary = experiment.call("value")
	print("LAB resolved_spec=%s" % compiled_result["resource_path"])
	print("LAB experiment_resource_sha256=%s" % compiled_result["resource_sha256"])
	print("LAB expanded_spec_sha256=%s" % experiment.call(
		"expanded_spec_sha256"))
	if bool(options.get("validate_only", false)):
		print("LAB validation=valid spawned_physics=false artifact_directory_created=false")
		quit(EXIT_PASS)
		return
	if String(expanded["experiment_id"]) == "L0_4_TRACE_PLAYBACK":
		var replay_path := String(options.get("replay_bundle", ""))
		if replay_path.is_empty():
			printerr("LAB launcher_configuration_error=L0_4 requires --replay-bundle")
			quit(EXIT_CONFIGURATION_ERROR)
			return
		var replay_options := _attestation_validation_options(options)
		var replay := LabRunnerScript.replay_bundle(
			replay_path, replay_options)
		if not replay["ok"]:
			printerr("LAB replay=failed code=%s" % replay.get(
				"code", "TRACE_REPLAY_FAILED"))
			quit(EXIT_EVIDENCE_INVALID)
			return
		print("LAB replay=pass simulation_steps=0 run_id=%s" % replay["run_id"])
		quit(EXIT_PASS)
		return

	var output_root := String(options["output_root"])
	if not _safe_output_root(output_root):
		printerr("LAB launcher_configuration_error=unsafe output root")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var run_id := ProcessLauncherScript.make_run_id(
		String(expanded["experiment_id"]),
		str(int(expanded["root_seed"])))
	var reservation := RunIndexScript.reserve_partial(
		output_root, run_id, OS.get_process_id())
	if not reservation["ok"]:
		printerr("LAB reservation_failed=%s" % reservation.get(
			"error", "UNKNOWN"))
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var project_path := ProjectSettings.globalize_path("res://").replace(
		"\\", "/").trim_suffix("/")
	var launch_plan_path := String(reservation["partial_path"]).path_join(
		"launch_plan.json")
	var engine_log_path := String(options.get(
		"engine_log_path",
		String(reservation["partial_path"]).path_join("engine.log")))
	var executable := OS.get_executable_path()
	var engine_arguments: Array = [
		"--headless",
		"--path",
		project_path,
		"--log-file",
		engine_log_path,
		"--script",
		"res://scripts/lab/run_lab.gd",
	]
	var child_user_arguments: Array = [
		"--child-launch-plan",
		launch_plan_path,
	]
	var log_paths := {
		"engine_log": ProcessLauncherScript.captured_log(
			engine_log_path, "godot_--log-file"),
		"stdout": ProcessLauncherScript.unavailable_log(
			"OS.create_process does not expose stdout redirection.",
			"inherited_console_not_captured"),
		"stderr": ProcessLauncherScript.unavailable_log(
			"OS.create_process does not expose stderr redirection.",
			"inherited_console_not_captured"),
	}
	var plan := ProcessLauncherScript.build_launch_plan(
		reservation,
		executable,
		engine_arguments,
		child_user_arguments,
		Array(requested_arguments),
		project_path,
		log_paths,
		{
			"resource_path": compiled_result["resource_path"],
			"resource_sha256": compiled_result["resource_sha256"],
			"expanded_spec_sha256":
				experiment.call("expanded_spec_sha256"),
			"experiment_id": expanded["experiment_id"],
			"root_seed": expanded["root_seed"],
			"observer_profile_id":
				expanded["observer_profile_id"],
		})
	var plan_write := ProcessLauncherScript.write_launch_plan(
		launch_plan_path, plan)
	if not plan_write["ok"]:
		printerr("LAB launch_plan_failed=%s" % plan_write.get(
			"error", "UNKNOWN"))
		RunIndexScript.abort_before_adoption(
			reservation["partial_path"],
			run_id,
			reservation["reservation_id"],
			"launch_plan_write_failed")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var plan_bind := RunIndexScript.bind_launch_plan(
		reservation["partial_path"],
		run_id,
		reservation["adoption_token"],
		launch_plan_path,
		plan_write["sha256"])
	if not plan_bind["ok"]:
		printerr("LAB launch_plan_bind_failed=%s" % plan_bind.get(
			"error", "UNKNOWN"))
		RunIndexScript.abort_before_adoption(
			reservation["partial_path"],
			run_id,
			reservation["reservation_id"],
			"launch_plan_bind_failed")
		quit(EXIT_CONFIGURATION_ERROR)
		return
	# Erase the convenience copy as soon as the token descriptor is bound.
	reservation["adoption_token"] = ""

	var metadata_lifecycle := {
		"engine_arguments": engine_arguments,
		"requested_user_arguments": Array(requested_arguments),
		"started_utc": plan["payload"]["created_utc"],
		"reservation_id": reservation["reservation_id"],
		"launch_plan_path": launch_plan_path,
		"launch_plan_sha256": plan_write["sha256"],
		"launch_plan_payload_sha256": plan["payload_sha256"],
		"adoption_token_sha256":
			reservation["adoption_token_sha256"],
		"partial_path": reservation["partial_path"],
		"final_path": reservation["final_path"],
	}
	var pre_spawn_metadata := ProcessLauncherScript.running_process_metadata(
		run_id,
		executable,
		plan["payload"]["arguments"],
		project_path,
		log_paths,
		OS.get_process_id(),
		child_user_arguments,
		"launcher_exact",
		-1,
		metadata_lifecycle)
	var launch := ProcessLauncherScript.launch_async(
		executable, plan["payload"]["arguments"])
	if not launch["ok"]:
		printerr("LAB child_spawn_failed=%s" % launch["error"])
		var spawn_terminal := ProcessLauncherScript.terminal_process_metadata(
			pre_spawn_metadata,
			-1,
			"child_process_create_failed",
			"ABORTED",
			OS.get_process_id())
		FinalizerScript.record_terminal_metadata(
			reservation["partial_path"],
			run_id,
			reservation["reservation_id"],
			-1,
			spawn_terminal)
		RunIndexScript.abort_before_adoption(
			reservation["partial_path"],
			run_id,
			reservation["reservation_id"],
			"child_process_create_failed")
		print("LAB partial_artifacts=%s" % reservation["partial_path"])
		quit(EXIT_CONTROLLED_ABORT)
		return
	var child_pid := int(launch["child_process_id"])
	var running_metadata := ProcessLauncherScript.running_process_metadata(
		run_id,
		executable,
		plan["payload"]["arguments"],
		project_path,
		log_paths,
		OS.get_process_id(),
		child_user_arguments,
		"launcher_exact",
		child_pid,
		metadata_lifecycle)
	var running_write := TraceStoreScript.write_json_for_parent(
		String(reservation["partial_path"]).path_join(
			"process_metadata.json"),
		running_metadata)
	if not running_write["ok"]:
		printerr("LAB process_metadata_running_write_failed")

	while OS.is_process_running(child_pid):
		await create_timer(0.02).timeout
	var child_exit_code := OS.get_process_exit_code(child_pid)
	var terminal_status := (
		"CRASHED"
		if child_exit_code < 0
		else ("COMPLETE" if child_exit_code == 0 else "ABORTED"))
	var exit_disposition := (
		"exit_code_unavailable_or_crashed"
		if child_exit_code < 0
		else (
			"candidate_ready_parent_observed"
			if child_exit_code == 0
			else "child_nonzero_exit"))
	var terminal_metadata := ProcessLauncherScript.terminal_process_metadata(
		running_metadata,
		child_exit_code,
		exit_disposition,
		terminal_status,
		OS.get_process_id())
	if not running_write["ok"]:
		var provenance_terminal := ProcessLauncherScript.terminal_process_metadata(
			running_metadata,
			child_exit_code,
			"running_process_metadata_write_failed",
			"ABORTED",
			OS.get_process_id())
		var provenance_write := FinalizerScript.record_terminal_metadata(
			reservation["partial_path"],
			run_id,
			reservation["reservation_id"],
			child_pid,
			provenance_terminal)
		printerr("LAB publication_blocked=process_metadata_running_write_failed")
		printerr("LAB terminal_metadata=%s" % (
			"written" if provenance_write["ok"] else "write_failed"))
		printerr("LAB partial_artifacts=%s" % reservation["partial_path"])
		quit(EXIT_EVIDENCE_INVALID)
		return
	if child_exit_code != 0:
		var terminal_write := FinalizerScript.record_terminal_metadata(
			reservation["partial_path"],
			run_id,
			reservation["reservation_id"],
			child_pid,
			terminal_metadata)
		print("LAB child_exit_code=%d terminal_metadata=%s" % [
			child_exit_code,
			"written" if terminal_write["ok"] else "write_failed",
		])
		print("LAB partial_artifacts=%s" % reservation["partial_path"])
		quit(
			child_exit_code
			if child_exit_code > 0
			else EXIT_CONTROLLED_ABORT)
		return

	var finalized := FinalizerScript.finalize_candidate(
		reservation["partial_path"],
		run_id,
		reservation["reservation_id"],
		child_pid,
		terminal_metadata,
		_attestation_validation_options(options))
	if not finalized["ok"]:
		printerr("LAB parent_finalization_failed=%s" % finalized.get(
			"error", "UNKNOWN"))
		if finalized.has("bundle_path"):
			printerr("LAB unattested_artifacts=%s" % finalized["bundle_path"])
		else:
			printerr("LAB partial_artifacts=%s" % reservation["partial_path"])
		quit(EXIT_EVIDENCE_INVALID)
		return
	var validation: Dictionary = finalized["validation"]
	var attestation: Dictionary = finalized["attestation"]
	print("LAB run_id=%s" % run_id)
	print("LAB child_exit_code=0 parent_finalization=pass")
	print("LAB attestation=valid algorithm=%s key_id=%s receipt=%s" % [
		attestation.get("algorithm", "hmac-sha256"),
		attestation["key_id"],
		attestation["receipt_path"],
	])
	print("LAB promotion=%s" % (
		"pass" if validation["can_promote"] else "not_evaluated"))
	print("LAB artifacts=%s" % finalized["bundle_path"])
	quit(
		EXIT_PASS
		if validation["can_promote"]
		else EXIT_PHYSICAL_OR_PROMOTION_FAIL)


static func _compile(options: Dictionary) -> Dictionary:
	var spec_path := String(options.get("experiment_spec", ""))
	if not spec_path.begins_with("res://") or not spec_path.ends_with(".tres"):
		return {"ok": false, "error": "experiment spec must be one res:// .tres resource"}
	if not FileAccess.file_exists(spec_path):
		return {"ok": false, "error": "experiment spec does not exist"}
	var loaded = ResourceLoader.load(
		spec_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not loaded.has_method("to_value_dictionary"):
		return {"ok": false, "error": "resource is not an ExperimentSpec"}
	var resource_sha := "sha256:%s" % FileAccess.get_sha256(spec_path)
	var overrides: Dictionary = {}
	if options.has("seed"):
		overrides["root_seed"] = options["seed"]
	if options.has("observer"):
		overrides["observer_profile_id"] = options["observer"]
	var compiled := SpecCompilerScript.compile(
		loaded,
		{},
		overrides,
		{
			"resource_path": spec_path,
			"resource_sha256": resource_sha,
		})
	if not compiled["ok"]:
		return {
			"ok": false,
			"error": "spec compilation failed",
			"details": compiled["errors"],
		}
	return {
		"ok": true,
		"experiment": compiled["experiment"],
		"resource_path": spec_path,
		"resource_sha256": resource_sha,
	}


static func _parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var options := {
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
							"--engine-log-path must be absolute")
					options["engine_log_path"] = value
				"--attestation-test-root":
					if not value.is_absolute_path():
						return _parse_failure(
							"--attestation-test-root must be absolute")
					options["attestation_test_root"] = value
			index += 2
			continue
		if argument in ["--seed-set", "--sweep"]:
			return _parse_failure(
				"%s is reserved for a future campaign launcher" % argument)
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
