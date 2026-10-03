extends SceneTree

const ProcessLauncherScript := preload(
	"res://scripts/lab/lab_process_launcher.gd")
const SchemaValidatorScript := preload(
	"res://scripts/lab/schema_validator.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab process-metadata lifecycle contract ===")
	var metadata: Dictionary = ProcessLauncherScript.running_process_metadata(
		"process_run",
		"godot",
		["--headless", "--child-run"],
		"C:/project",
		{
			"engine_log": ProcessLauncherScript.captured_log(
				"engine.log", "godot_--log-file"),
			"stdout": ProcessLauncherScript.captured_log(
				"stdout.log", "test_redirect"),
			"stderr": ProcessLauncherScript.captured_log(
				"stderr.log", "test_redirect"),
		},
		1234,
		["--experiment-spec", "res://spec.tres"],
		"launcher_exact",
		5678,
		{
			"engine_arguments": ["--headless", "--child-run"],
			"requested_user_arguments": [
				"--experiment-spec",
				"res://spec.tres",
			],
			"reservation_id": "0123456789abcdef0123456789abcdef",
			"launch_plan_path": "C:/run/launch_plan.json",
			"launch_plan_sha256":
				"sha256:0000000000000000000000000000000000000000000000000000000000000000",
			"launch_plan_payload_sha256":
				"sha256:1111111111111111111111111111111111111111111111111111111111111111",
			"adoption_token_sha256":
				"sha256:2222222222222222222222222222222222222222222222222222222222222222",
			"partial_path": "C:/run/process_run.partial",
			"final_path": "C:/run/process_run",
		})
	_check(metadata["schema"] == "sporespore.lab.process_metadata.v1", "schema is versioned")
	_check(metadata["status"] == "RUNNING", "new child metadata starts RUNNING")
	_check(int(metadata["parent_process_id"]) == 1234, "parent PID is explicit")
	_check(int(metadata["child_process_id"]) == 5678, "spawned child PID is explicit")
	_check(metadata["arguments"] == ["--headless", "--child-run"], "exact arguments are retained")
	_check(
		metadata["engine_arguments"] == ["--headless", "--child-run"],
		"engine arguments are separated explicitly")
	_check(
		metadata["user_arguments"]
			== ["--experiment-spec", "res://spec.tres"],
		"experiment/user arguments are retained separately")
	_check(
		metadata["argument_capture_quality"] == "launcher_exact",
		"argument provenance states whether capture is exact or runtime-observed")
	_check(metadata["ended_utc"] == null, "unfinished process has no fabricated end time")
	_check(
		SchemaValidatorScript.validate_file(
			"res://data/lab/schemas/process_metadata_v1.schema.json",
			metadata)["ok"],
		"RUNNING metadata satisfies strict null-state and log descriptors")
	_check(
		metadata["reservation_id"] == "0123456789abcdef0123456789abcdef"
			and metadata["launch_plan_path"] == "C:/run/launch_plan.json",
		"reservation and launch-plan identity are explicit")
	_check(metadata.is_read_only(), "process metadata record is sealed")
	var terminal := ProcessLauncherScript.terminal_process_metadata(
		metadata,
		7,
		"child_nonzero_exit",
		"ABORTED",
		1234)
	_check(
		terminal["status"] == "ABORTED"
			and int(terminal["exit_code"]) == 7
			and terminal["ended_utc"] != null,
		"parent terminalization records actual exit and end time")
	_check(
		int(terminal["termination_observer_process_id"]) == 1234,
		"terminal record identifies the observing parent")
	_check(
		terminal.is_read_only(),
		"terminal process metadata is sealed")
	_check(
		SchemaValidatorScript.validate_file(
			"res://data/lab/schemas/process_metadata_v1.schema.json",
			terminal)["ok"],
		"terminal metadata satisfies strict non-null lifecycle coupling")
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
