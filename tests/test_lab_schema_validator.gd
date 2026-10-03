extends SceneTree

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const HASH := "sha256:0000000000000000000000000000000000000000000000000000000000000000"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab schema validator tests ===")
	_test_all_owned_schemas_load()
	_test_manifest_contract()
	_test_l0_frame_contract()
	_test_summary_provenance_contract()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_all_owned_schemas_load() -> void:
	print("- every BR1 record schema is parseable and uses supported keywords")
	for schema_name in [
		"manifest_v1",
		"frame_v1",
		"command_v1",
		"application_v1",
		"decision_v1",
		"intervention_v1",
		"mechanics_v1",
		"event_v1",
		"comparison_v1",
		"campaign_manifest_v1",
		"child_run_index_v1",
		"matrix_summary_v1",
		"runtime_note_v1",
		"configuration_v1",
		"launch_plan_v1",
		"process_metadata_v1",
		"pre_event_entry_v1",
		"summary_v1",
		"checksums_v1",
		"knowledge_entry_v1",
	]:
		var schema_path := "res://data/lab/schemas/%s.schema.json" % schema_name
		var loaded := SchemaValidatorScript.load_schema(schema_path)
		_check(loaded["ok"], "%s schema loads" % schema_name)
		var probe := SchemaValidatorScript.validate_file(schema_path, {})
		var unsupported := false
		for error_value in probe.get("errors", []):
			if String(error_value.get("code", "")) == "UNSUPPORTED_SCHEMA_KEYWORD":
				unsupported = true
				break
		_check(not unsupported, "%s schema vocabulary is implemented" % schema_name)


func _test_manifest_contract() -> void:
	print("- manifest rejects missing, unknown, and invalid lifecycle fields")
	var manifest := _manifest("schema_validator")
	var valid := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/manifest_v1.schema.json", manifest)
	_check(valid["ok"], "complete running manifest validates")

	var missing := manifest.duplicate(true)
	missing.erase("expanded_spec_sha256")
	var missing_result := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/manifest_v1.schema.json", missing)
	_check(not missing_result["ok"], "missing expanded spec hash is rejected")

	var unknown := manifest.duplicate(true)
	unknown["secret_assist"] = true
	var unknown_result := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/manifest_v1.schema.json", unknown)
	_check(not unknown_result["ok"], "unknown manifest field is rejected")

	var invalid_status := manifest.duplicate(true)
	invalid_status["status"] = "LOOKS_GOOD"
	var status_result := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/manifest_v1.schema.json", invalid_status)
	_check(not status_result["ok"], "unregistered lifecycle status is rejected")


func _test_l0_frame_contract() -> void:
	print("- exact L0 direct-state frame and nested body record validate")
	var frame := _frame("schema_validator", 0, 0.0)
	var valid := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/frame_v1.schema.json", frame)
	if not valid["ok"]:
		printerr(SchemaValidatorScript.format_errors(valid))
	_check(valid["ok"], "exact L0 frame validates")

	var bad_phase := frame.duplicate(true)
	bad_phase["sample_phase"] = "after_everything"
	var phase_result := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/frame_v1.schema.json", bad_phase)
	_check(not phase_result["ok"], "unknown sample phase is rejected")

	var missing_epoch := frame.duplicate(true)
	missing_epoch["bodies"]["body_0"].erase("capture_epoch")
	var epoch_result := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/frame_v1.schema.json", missing_epoch)
	_check(not epoch_result["ok"], "body without capture epoch is rejected")

	var mixed_epoch := frame.duplicate(true)
	mixed_epoch["bodies"]["body_0"]["capture_epoch"] = 9
	var mixed_result := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/frame_v1.schema.json", mixed_epoch)
	_check(not mixed_result["ok"], "frame cannot blend samples from another capture epoch")

	var extra_body_field := frame.duplicate(true)
	extra_body_field["bodies"]["body_0"]["teleported"] = true
	var extra_result := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/frame_v1.schema.json", extra_body_field)
	_check(not extra_result["ok"], "unknown direct-state body field is rejected")

	for forbidden_field in ["joints", "support", "derived_metrics"]:
		var smuggled_channel := frame.duplicate(true)
		smuggled_channel[forbidden_field] = (
			[{"joint_id": "joint_0"}]
			if forbidden_field == "joints"
			else {"looks_valid": true})
		var smuggled_result := SchemaValidatorScript.validate_file(
			"res://data/lab/schemas/frame_v1.schema.json",
			smuggled_channel)
		_check(
			not smuggled_result["ok"],
			"frame_v1 rejects undeclared %s channel" % forbidden_field)


func _test_summary_provenance_contract() -> void:
	print("- derived metrics require explicit stream/range/field/units/aggregation")
	var summary := _summary("schema_validator", 1, 0)
	summary["metrics"] = [{
		"metric_id": "maximum_absolute_height_error",
		"value": 0.012,
		"unit": "m",
		"availability": "derived",
		"source_stream": "frames.jsonl",
		"source_frame_range": [0, 0],
		"source_field": "/bodies/body_0/transform/origin/1",
		"aggregation_id": "max_abs_error",
		"aggregation_version": 1,
	}]
	var valid := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/summary_v1.schema.json", summary)
	_check(valid["ok"], "metric with full provenance validates")
	var missing_unit := summary.duplicate(true)
	missing_unit["metrics"][0].erase("unit")
	var invalid := SchemaValidatorScript.validate_file(
		"res://data/lab/schemas/summary_v1.schema.json", missing_unit)
	_check(not invalid["ok"], "metric without unit is rejected")


static func _manifest(run_id: String) -> Dictionary:
	return {
		"schema": "sporespore.lab.manifest.v1",
		"run_id": run_id,
		"status": "RUNNING",
		"experiment_id": "L0_TEST",
		"schema_set": "sporespore.lab.schemas.v1",
		"recorder_version": "flight-recorder-v1",
		"expanded_spec_sha256": HASH,
		"resolved_configuration_sha256": HASH,
		"applied_configuration_sha256": null,
		"dirty_worktree": true,
		"execution_mode": "development",
		"reproducibility": "partial_dirty_source",
		"units": "SI",
		"started_utc": "2026-07-19T00:00:00Z",
		"required_artifacts": [
			"manifest.json",
			"frames.jsonl",
			"runtime_notes.jsonl",
			"summary.json",
		],
	}


static func _frame(run_id: String, frame_id: int, time_s: float) -> Dictionary:
	return {
		"schema": "sporespore.lab.frame.v1",
		"run_id": run_id,
		"schema_version": "frame_v1",
		"frame_id": frame_id,
		"physics_step_id": frame_id,
		"capture_epoch": frame_id,
		"physics_time_s": time_s,
		"sample_phase": "integrate_callback",
		"experiment_phase": "MEASURE",
		"release_frame_id": 0,
		"bodies": {
			"body_0": {
				"physics_step_id": frame_id,
				"body_callback_sequence": frame_id + 1,
				"capture_epoch": frame_id,
				"sample_phase": "integrate_callback",
				"body_id": "body_0",
				"part_index": 0,
				"transform": {
					"basis": [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
					"origin": [time_s, 1.0, 0.0],
				},
				"center_of_mass_world": [time_s, 1.0, 0.0],
				"linear_velocity": [1.0, 0.0, 0.0],
				"angular_velocity": [0.0, 0.0, 0.0],
				"mass_kg": 1.0,
				"inverse_inertia_tensor_world": {
					"x": [1.0, 0.0, 0.0],
					"y": [0.0, 1.0, 0.0],
					"z": [0.0, 0.0, 1.0],
				},
				"sleeping": false,
				"finite": true,
				"step_s": 1.0 / 60.0,
				"total_gravity_world": [0.0, 0.0, 0.0],
				"com_frame_oracle_error_m": 0.0,
				"observer_profile_id": "full_state_v1",
				"observer_adapter_id": "rigid_body_integrate_forces_v1",
			},
		},
		"contacts": [],
		"availability": {
			"required_body_ids": ["body_0"],
			"captured_body_count": 1,
			"contact_count": 0,
			"invalid_reasons": [],
			"fields": {
				"body:body_0": {
					"status": "measured",
					"reason": null,
					"source": "rigid_body_integrate_forces_v1",
				},
				"contacts": {
					"status": "measured",
					"reason": null,
					"source": "rigid_body_integrate_forces_v1",
				},
				"frame": {
					"status": "measured",
					"reason": null,
					"source": "sensor_frame_builder_v1",
				},
			},
		},
		"finite": true,
	}


static func _summary(run_id: String, frame_count: int, note_count: int) -> Dictionary:
	return {
		"schema": "sporespore.lab.summary.v1",
		"run_id": run_id,
		"termination": "completed",
		"evidence_validity": "valid",
		"hypothesis_result": "supported",
		"promotion": "pass",
		"frame_count": frame_count,
		"runtime_note_count": note_count,
		"first_frame_id": 0 if frame_count > 0 else null,
		"last_frame_id": frame_count - 1 if frame_count > 0 else null,
		"metrics": [],
	}
