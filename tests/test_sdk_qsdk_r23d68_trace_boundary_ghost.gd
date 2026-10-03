extends SceneTree

## Compact zero-world traversal of the exact segment helper called by the
## production row emitter. This proves metadata-route conformance only; it does
## not instantiate a creature, create a physics world, or predict behavior.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const DECLARATION_PATH := (
	"res://sdk/turning/"
	+ "r23d68_production_path_conformance_repaired_three_engine_turning_"
	+ "preregistration_v1.json"
)


func _initialize() -> void:
	call_deferred("_run")


func _failure(code: String) -> void:
	printerr("QSDK_R23D68_TRACE_BOUNDARY_GHOST_FAILURE ", code)
	quit(1)


func _run() -> void:
	var file := FileAccess.open(DECLARATION_PATH, FileAccess.READ)
	if file == null:
		_failure("DECLARATION_UNREADABLE")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failure("DECLARATION_INVALID")
		return
	var declaration: Dictionary = parsed
	var ghost: Dictionary = declaration.get("compact_development_ghosts", {}).get(
		"trace_boundary_ghost", {}
	)
	var semantic_steps: Array = ghost.get("semantic_steps", [])
	var expected_segments: Array = ghost.get("expected_segment_ids", [])
	if semantic_steps.size() != 7 or expected_segments.size() != semantic_steps.size():
		_failure("BOUNDARY_POPULATION_INVALID")
		return

	var trace_options := {
		"cell_id": "r23d68__godot_jolt__s23185__reference_zero",
		"exact_controller_step_count": 2992,
		"policy_id": "qsdk_r23d3_phase_balanced_trace_v1",
		"post_schedule_segment_id": "reference_continuation",
		"recovery_duration_steps": 600,
		"turn_duration_steps": 1200,
		"turn_heading_offset_rad": 0.0,
		"turn_start_semantic_step": 600,
	}
	var compiled := WaveGaitScript.compile_sdk_physical_trace_options(trace_options)
	if not bool(compiled.get("ok", false)):
		_failure(String(compiled.get("failure_code", "TRACE_OPTIONS_INVALID")))
		return

	var observed_segments: Array[String] = []
	for index in range(semantic_steps.size()):
		var result := WaveGaitScript._r23d3_trace_segment(
			trace_options,
			int(semantic_steps[index]),
		)
		if (
			not bool(result.get("ok", false))
			or String(result.get("segment_id", "")) != String(expected_segments[index])
		):
			_failure("SEGMENT_MISMATCH:%s" % int(semantic_steps[index]))
			return
		observed_segments.append(String(result["segment_id"]))

	print(
		"QSDK_R23D68_TRACE_BOUNDARY_GHOST ",
		JSON.stringify(
			{
				"schema_version": "sporespore_qsdk_r23d68_trace_boundary_ghost_v1",
				"semantic_steps": semantic_steps,
				"observed_segment_ids": observed_segments,
				"same_helper_as_production_row_emitter": true,
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			},
			"",
			true,
			true
		)
	)
	quit(0)
