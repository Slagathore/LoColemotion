extends "res://sdk/adapters/godot/gdscript/development_profiled_recovery_smoke_worker_v1.gd"


## Exercise the actual publication override without initializing a model/world.
func _initialize() -> void:
	_profile_start_us = Time.get_ticks_usec()
	var checks := {}
	var cost := CostProfiler.new()
	cost.begin_v1("parent", 10)
	cost.begin_v1("child", 20)
	cost.end_v1("child", 50)
	cost.end_v1("parent", 70)
	var snapshot := cost.snapshot_v1(0, 100)
	checks["nested_exclusive_accounting"] = snapshot["sections"]["parent"]["exclusive_us"] == 30
	checks["nested_inclusive_accounting"] = snapshot["sections"]["parent"]["inclusive_us"] == 60
	checks["no_double_counting"] = (
		snapshot["accounted_us"] == 60 and snapshot["unattributed_us"] == 40
	)
	cost.begin_v1("parent", 100)
	cost.end_v1("parent", 120)
	checks["repeated_section_aggregate"] = (
		cost.sections["parent"]["sample_count"] == 2 and cost.sections["parent"]["maximum_us"] == 60
	)
	var bad := CostProfiler.new()
	bad.begin_v1("open", 10)
	checks["unclosed_section_refused"] = not bad.snapshot_v1(0, 30)["ok"]
	bad.end_v1("wrong", 20)
	checks["wrong_section_refused"] = bad.failure_code == "PROFILE_UNBALANCED_SECTION"
	bad = CostProfiler.new()
	bad.begin_v1("reverse", 20)
	bad.end_v1("reverse", 10)
	checks["reverse_clock_refused"] = not bad.snapshot_v1(0, 30)["ok"]
	var preflight_cost := CostProfiler.new()
	var baseline := NativeEpochRoute.collect_completed_step_v1(
		null, {}, {}, {}, 0, "invalid", "invalid"
	)
	var measured := NativeEpochRoute.collect_completed_step_v1(
		null, {}, {}, {}, 0, "invalid", "invalid", {}, preflight_cost
	)
	checks["real_preflight_refusal_preserved"] = (
		JsonTransportScript.stringify(baseline) == JsonTransportScript.stringify(measured)
		and measured["ok"] == false
	)
	checks["real_refusal_closes_profile_section"] = (
		preflight_cost.snapshot_v1(0, Time.get_ticks_usec())["ok"]
		and preflight_cost.sections["epoch_preflight"]["sample_count"] == 1
	)
	var report := {
		"synthetic_zero_world_fixture": true,
		"source_commit": "a".repeat(40),
		"parent_attempt_id": "b".repeat(32),
		"child_attempt_id": "c".repeat(32),
		"arm_id": "matched_no_kick_continuation",
		"process_id": OS.get_process_id(),
		"diagnostic_declaration_sha256": "sha256:" + "d".repeat(64),
		"solver_step_count": 0,
		"after_interaction_step_count": 0,
		"retained_arm": {"orchestrator_state": {"epoch_start_global_step": null}},
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	_publish_smoke_report_v1(report)
	var ok := checks.values().all(func(value: Variant) -> bool: return value == true)
	print(
		"DEVELOPMENT_STEP_COST_ZERO_WORLD ",
		JsonTransportScript.stringify(
			{"ok": ok, "checks": checks, "world_count": 0, "solver_step_count": 0}
		)
	)
	quit(0 if ok else 1)
