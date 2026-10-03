extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"
## Post-exposure diagnostic: reproduce both compilation transports without a world.
const EntrySource := preload("res://sdk/adapters/godot/gdscript/recovery_walking_entry_source_v1.gd")
const EntryReplay := preload("res://sdk/adapters/godot/gdscript/recovery_stance_entry_replay_v1.gd")

func _dispatch(sdk: Object, input: Dictionary, _binding: Dictionary) -> Dictionary:
	var descriptor: Dictionary = input.configuration.base_descriptor
	var exact_raw := EntryReplay.Transport.stringify(descriptor)
	var default_raw := JSON.stringify(descriptor)
	var exact: Dictionary = JSON.parse_string(sdk.compile_bounded_quadruped_json(exact_raw)).value
	var rounded: Dictionary = JSON.parse_string(sdk.compile_bounded_quadruped_json(default_raw)).value
	var exact_matches := 0
	var default_matches := 0
	var first_difference := {}
	for row in input.stance_entry.readiness_rows:
		var source: Dictionary = row.source
		var native: Dictionary = source.packet.native_source
		var request: Dictionary = source.projection.request
		var a := EntryReplay.Route.Readiness.measure_v1(request, native.observation.center_of_mass, exact, EntryReplay.Route.task.stance_entry)
		var b := EntryReplay.Route.Readiness.measure_v1(request, native.observation.center_of_mass, rounded, EntryReplay.Route.task.stance_entry)
		if EntryReplay._same(a, source.readiness): exact_matches += 1
		if EntryReplay._same(b, source.readiness): default_matches += 1
		if first_difference.is_empty() and not EntryReplay._same(a, source.readiness):
			first_difference = {"step": row.global_semantic_step, "retained": source.readiness, "exact": a, "default": b,
				"retained_sha256": source.readiness_sha256, "exact_sha256": EntryReplay._sha(sdk, a), "default_sha256": EntryReplay._sha(sdk, b)}
	return {"ok": true, "diagnostic_only": true, "original_attempt_reclassified": false,
		"sample_count": input.stance_entry.readiness_rows.size(), "exact_compilation_matches": exact_matches,
		"default_compilation_matches": default_matches, "exact_descriptor_json": exact_raw, "default_descriptor_json": default_raw,
		"exact_geometry": exact.geometry, "default_geometry": rounded.geometry, "first_difference": first_difference,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
