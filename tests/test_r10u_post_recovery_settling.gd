extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"
const Settling := preload("res://sdk/adapters/godot/gdscript/r10u_post_recovery_settling_v1.gd")
const SHA := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const OTHER_SHA := "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

static func _context(kind: String = "upright") -> Dictionary:
	return {"schema_version": Settling.CONTEXT, "attempt_id": "synthetic-r10u", "arm_id": "kick_passive_recovery_resume",
		"model_instance_id": "synthetic-body", "body_population_instance_sha256": SHA, "energy_initializer_sha256": SHA,
		"recovery_memory_sha256": SHA, "recovery_receipt_sha256": SHA, "entry_kind": kind, "recovery_phase": "complete",
		"global_semantic_step": 1000, "prior_walking_session_ids": ["old-prefix"]}

static func _sample(step: int, ready: bool) -> Dictionary:
	return {"schema_version": "sporespore_recovery_walking_readiness_v1", "source_semantic_step": step,
		"ready": ready, "horizontal_com_speed_m_s": 0.02 if ready else 0.03400406676351237,
		"angular_speed_rad_s": 0.02, "torso_tilt_rad": 0.01,
		"checks": {"angular_settled": true, "four_native_supports": true, "horizontal_com_settled": ready,
			"upright": true, "zero_bias_reference_path_feasible": true}}

static func _advance(sdk: Object, memory: Dictionary, ready: bool) -> Dictionary:
	return Settling.advance_v1(sdk, memory, _sample(memory.last_source_step + 1, ready), "fresh-hold", SHA, SHA)

func _dispatch(sdk: Object, _input: Dictionary, _binding: Dictionary) -> Dictionary:
	var checks := {}
	var context := _context()
	var original := Settling.initialize_v1(sdk, context, _sample(1000, false))
	checks.entry_upright_speed_only_selects_hold = original.get("ok") == true and original.memory.outcome == "pending"
	if not checks.entry_upright_speed_only_selects_hold: return {"ok": false, "checks": checks, "failure": original}
	for kind in ["upright", "partial", "prone"]:
		var ready := Settling.initialize_v1(sdk, _context(kind), _sample(1000, true))
		checks["entry_ready_" + kind + "_bypasses"] = ready.get("ok") == true and ready.memory.outcome == "direct" and ready.memory.commands == 0 and ready.memory.hold_session_id == ""
		checks["terminal_direct_" + kind + "_cannot_step"] = _advance(sdk, ready.memory, true).get("ok") == false
		if kind != "upright":
			var unready := Settling.initialize_v1(sdk, _context(kind), _sample(1000, false))
			checks["entry_unready_" + kind + "_refuses"] = unready.get("ok") == true and unready.memory.outcome == "entry_refused"
	for key in ["four_native_supports", "zero_bias_reference_path_feasible", "angular_settled", "upright"]:
		var sample := _sample(1000, false)
		sample.checks[key] = false
		if key == "angular_settled": sample.angular_speed_rad_s = 0.16
		if key == "upright": sample.torso_tilt_rad = 0.051
		var refused := Settling.initialize_v1(sdk, context, sample)
		checks["entry_excludes_" + key] = refused.get("ok") == true and refused.memory.outcome == "entry_refused"
	var malformed := _sample(1000, false)
	malformed.checks.horizontal_com_settled = true
	checks.integrity_inconsistent_speed_check_refused = Settling.initialize_v1(sdk, context, malformed).get("ok") == false
	malformed = _sample(1000, false)
	malformed.horizontal_com_speed_m_s = NAN
	checks.integrity_nonfinite_sample_refused = Settling.initialize_v1(sdk, context, malformed).get("ok") == false
	malformed = _sample(1000, false)
	malformed.checks.erase("four_native_supports")
	checks.integrity_missing_readiness_check_refused = Settling.initialize_v1(sdk, context, malformed).get("ok") == false
	var incomplete := context.duplicate(true)
	incomplete.recovery_phase = "stance_dwell"
	checks.integrity_incomplete_recovery_refused = Settling.initialize_v1(sdk, incomplete, _sample(1000, false)).get("ok") == false
	checks.integrity_initial_clock_refused = Settling.initialize_v1(sdk, context, _sample(999, false)).get("ok") == false
	var baseline := context.duplicate(true)
	baseline.arm_id = "matched_no_kick_continuation"
	checks.integrity_baseline_excluded = Settling.initialize_v1(sdk, baseline, _sample(1000, false)).get("ok") == false
	var duplicate := context.duplicate(true)
	duplicate.prior_walking_session_ids.append("old-prefix")
	checks.integrity_duplicate_prior_session_refused = Settling.initialize_v1(sdk, duplicate, _sample(1000, false)).get("ok") == false
	var memory: Dictionary = original.memory.duplicate(true)
	var after := {}
	for index in range(1, 31):
		after = _advance(sdk, memory, true)
		if after.get("ok") != true: break
		memory = after.memory
		if index == 29: checks.dwell_no_early_release = memory.outcome == "pending" and memory.consecutive_ready == 29
	checks.dwell_release_on_thirtieth = after.get("ok") == true and memory.outcome == "ready" and memory.commands == 30
	checks.terminal_ready_cannot_step = _advance(sdk, memory, true).get("ok") == false
	memory = original.memory.duplicate(true)
	for index in range(1, 51):
		after = _advance(sdk, memory, index != 20)
		if after.get("ok") != true: break
		memory = after.memory
		if index == 20: checks.dwell_resets_on_nonready = memory.consecutive_ready == 0 and memory.outcome == "pending"
		if index == 49: checks.dwell_resumes_from_zero = memory.consecutive_ready == 29 and memory.outcome == "pending"
	checks.dwell_release_after_reset = after.get("ok") == true and memory.outcome == "ready" and memory.commands == 50
	memory = original.memory.duplicate(true)
	for index in range(1, 241):
		after = _advance(sdk, memory, index >= 211)
		if after.get("ok") != true: break
		memory = after.memory
	checks.dwell_ready_at_240_has_priority = after.get("ok") == true and memory.outcome == "ready" and memory.commands == 240 and memory.consecutive_ready == 30
	checks.terminal_241_after_boundary_success_refused = _advance(sdk, memory, true).get("ok") == false
	memory = original.memory.duplicate(true)
	for index in range(1, 241):
		after = _advance(sdk, memory, index >= 212)
		if after.get("ok") != true: break
		memory = after.memory
	checks.dwell_29_ready_at_240_times_out = after.get("ok") == true and memory.outcome == "timeout" and memory.commands == 240 and memory.consecutive_ready == 29
	checks.terminal_timeout_cannot_step = _advance(sdk, memory, true).get("ok") == false
	checks.integrity_original_terminal_and_epoch_retained = memory.context == context and memory.entry_source_step == 1000 and memory.last_source_step == 1240
	checks.integrity_stale_sample_refused = Settling.advance_v1(sdk, original.memory, _sample(1000, true), "fresh-hold", SHA, SHA).get("ok") == false
	checks.integrity_skipped_sample_refused = Settling.advance_v1(sdk, original.memory, _sample(1002, true), "fresh-hold", SHA, SHA).get("ok") == false
	checks.integrity_prefix_session_reuse_refused = Settling.advance_v1(sdk, original.memory, _sample(1001, true), "old-prefix", SHA, SHA).get("ok") == false
	checks.integrity_recovery_memory_change_refused = Settling.advance_v1(sdk, original.memory, _sample(1001, true), "fresh-hold", OTHER_SHA, SHA).get("ok") == false
	checks.integrity_energy_reset_refused = Settling.advance_v1(sdk, original.memory, _sample(1001, true), "fresh-hold", SHA, OTHER_SHA).get("ok") == false
	var first := _advance(sdk, original.memory, false)
	checks.integrity_session_crossing_refused = Settling.advance_v1(sdk, first.memory, _sample(1002, true), "crossed-hold", SHA, SHA).get("ok") == false
	var tampered: Dictionary = original.memory.duplicate(true)
	tampered.commands = 1
	checks.integrity_memory_payload_rewrite_refused = not Settling.memory_valid_v1(sdk, tampered)
	tampered = original.memory.duplicate(true)
	tampered.commands = 241
	tampered.last_source_step = 1241
	tampered.payload_sha256 = Settling._payload(sdk, tampered)
	checks.integrity_resigned_overbudget_memory_refused = not Settling.memory_valid_v1(sdk, tampered)
	checks.integrity_input_not_mutated = original.memory.commands == 0 and original.memory.context == context
	checks.scope_no_lifecycle_or_source_authority = original.source_and_application_provenance_validation_owned_by_caller and not original.native_session_lifecycle_proven_by_component
	return {"ok": not checks.values().has(false), "checks": checks, "check_count": checks.size(),
		"synthetic_scheduler_inputs_only": true, "native_policy_calls": 0,
		"physical_route_qualified": false, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
