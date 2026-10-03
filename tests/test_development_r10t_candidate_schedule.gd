extends SceneTree

const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Smoke := preload("res://sdk/adapters/godot/gdscript/development_recovery_smoke_worker_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

class Probe:
	extends "res://sdk/adapters/godot/gdscript/r10t_recovery_worker_v1.gd"
	func _initialize() -> void:
		pass # Suppress launch only; called scheduling/retention methods are real.

class CompletionOnly:
	extends RefCounted
	var receipt: Dictionary
	var calls := 0
	func finish_walking_session_v1() -> Dictionary:
		calls += 1
		return receipt.duplicate(true)

func _test_actual_walking_close(probe: Probe, selection: Dictionary, checks: Dictionary) -> void:
	# Replay the actual failed closing input; never restart its physical session.
	var path := probe.EVIDENCE_ROOT + "development-recovery-smoke-4337cdb9c34d4661881a56b6a20175e7/children/kick_passive_recovery_resume/worker_report.json"
	checks["failed_report_bytes_exact"] = FileAccess.get_sha256(path) == "08382f1a0665b0cdf543c28c93f59589b2b233cc8342e95edf4b1b88cd55ff1c"
	probe._seed = 41145 # Declared R10T pair seed; this fixture opens zero worlds.
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(selection["worker_selection"]["binding"]))
	checks["close_runtime_loaded"] = probe._load_runtime_extension_v1()
	if not checks["failed_report_bytes_exact"] or not checks["close_runtime_loaded"]:
		return
	probe._sdk = ClassDB.instantiate("SporeLocomotionSdk")
	var retained: Dictionary = probe._sdk.decode_exact_json_v1(FileAccess.get_file_as_string(path))
	var original: Dictionary = retained["partial_arm"]
	var completion: Dictionary = original["last_walking_evaluation_failure"]["completion_receipt"]
	var role: String = retained["arm_id"]
	var after: int = Profile.limits_v1(selection)["after_interaction_steps"]
	for count in [30, 60, 480, after, after + 1]:
		var arm := original.duplicate(true)
		var receipt := completion.duplicate(true)
		var policy_id := ""
		# Only 30 rows are original. Longer populations are explicitly synthetic
		# repeated rows to exercise the real finalizer/evaluator, not new physics.
		if count != 30:
			var template: Dictionary = arm["trace_rows"][-1]
			var rows := []
			for index in range(count):
				var row := template.duplicate(true)
				row["synthetic_test_row"] = true
				row["walking_session_local_step"] = index + 1
				rows.append(row)
			arm["trace_rows"] = rows
			arm["active_walking_session"]["trace_start_index"] = 0
			arm["active_walking_session"]["scheduled_step_count"] = count
			arm["active_walking_session"]["evaluation_segment_id"] = "walking_resume"
			policy_id = probe._walking_policy_id_v1("walking_resume")
			if not policy_id.is_empty():
				# These repeated rows are a synthetic identity-bound finalizer
				# fixture. The retained 30-step prefix is never relabeled.
				arm["active_walking_session"]["start_receipt"]["selected_policy_id"] = Profile.WalkingPolicy.binding_v1(policy_id, "walking_resume")["policy_id"]
				receipt["adapter_summary"]["controller_policy_id"] = Profile.WalkingPolicy.binding_v1(policy_id, "walking_resume")["policy_id"]
			for key in ["step_count", "validated_balanced_wave_command_count", "native_actuation_application_count"]:
				receipt["adapter_summary"][key] = count
		arm["walking_session_completion_attempted"] = false
		var facade := CompletionOnly.new()
		facade.receipt = receipt
		arm["facade"] = facade
		var pristine := arm.duplicate(true)
		if not policy_id.is_empty() and count == 60:
			# Identical synthetic measurements must yield identical diagnostics;
			# only the explicitly selected controller identity is different.
			var legacy := pristine.duplicate(true)
			var legacy_receipt := receipt.duplicate(true)
			legacy["active_walking_session"]["start_receipt"]["selected_policy_id"] = Profile.WalkingPolicy.LEGACY_POLICY_ID
			legacy_receipt["adapter_summary"]["controller_policy_id"] = Profile.WalkingPolicy.LEGACY_POLICY_ID
			var old_input := probe.walking_terminal_input_v2(role, legacy, legacy_receipt)
			var new_input := probe.walking_terminal_input_v2(role, pristine, receipt)
			var old_result := probe.WalkingEvaluator.evaluate_development_smoke_segment_v1(probe._sdk, old_input["evidence"], after)
			var new_result := probe.WalkingEvaluator.evaluate_development_smoke_segment_v1(probe._sdk, new_input["evidence"], after, policy_id)
			checks["same_measurements_same_diagnostics"] = old_result == new_result and new_result.get("ok") == true
			checks["legacy_reader_refuses_new_identity"] = probe.WalkingEvaluator.evaluate_development_smoke_segment_v1(probe._sdk, new_input["evidence"], after).get("ok") == false
			checks["selected_reader_refuses_old_identity"] = probe.WalkingEvaluator.evaluate_development_smoke_segment_v1(probe._sdk, old_input["evidence"], after, policy_id).get("ok") == false
		if count == 60 and Profile.WalkingPolicy.FiniteRoute.StanceEntry.selected_v1(policy_id):
			# Separate synthetic entry finalizer fixture, with the selected entry's
			# native IDs: legacy BW5R-B for R10H, the joint-pose entry policy for R10I.
			var entry_segment: String = Profile.WalkingPolicy.FiniteRoute.StanceEntry.SEGMENT
			var entry_policy_id: String = Profile.WalkingPolicy.binding_v1(probe._walking_policy_id_v1(entry_segment), entry_segment)["policy_id"]
			var neutral := pristine.duplicate(true)
			var neutral_receipt := receipt.duplicate(true)
			neutral.active_walking_session.evaluation_segment_id = entry_segment
			neutral.active_walking_session.start_receipt.selected_policy_id = entry_policy_id
			neutral_receipt.adapter_summary.controller_policy_id = entry_policy_id
			var neutral_facade := CompletionOnly.new()
			neutral_facade.receipt = neutral_receipt
			neutral.facade = neutral_facade
			probe._arms[role] = neutral
			var neutral_result := probe._finish_walking_session_v1(role)
			if neutral_result.get("ok") != true:
				print("CANDIDATE_SCHEDULE_UNEXPECTED_ENTRY_CLOSE ", Transport.stringify({"entry_policy_id": entry_policy_id,
					"failure_code": neutral_result.get("failure_code"), "evaluator_failure_code": neutral_result.get("retained_failure", {}).get("evaluator_failure_code")}))
			checks["neutral_finalizes_exactly_once"] = neutral_result.get("ok") == true and neutral_facade.calls == 1 and probe._arms[role].active_walking_session.is_empty()
			var again := probe._finish_walking_session_v1(role)
			checks["neutral_finished_session_is_not_closed_twice"] = again.get("ok") == true and again.get("session_closed") == false and neutral_facade.calls == 1
		probe._arms[role] = arm
		var result := probe._finish_walking_session_v1(role)
		if result.get("ok") != (count <= after):
			print("CANDIDATE_SCHEDULE_UNEXPECTED_CLOSE ", Transport.stringify({"count": count, "bound": after,
				"failure_code": result.get("failure_code"), "evaluator_failure_code": result.get("evaluator_failure_code")}))
		checks["real_close_once_" + str(count)] = facade.calls == 1
		checks["real_close_bound_" + str(count)] = result.get("ok") == (count <= after)
		if result.get("ok") == true:
			checks["real_close_no_claim_" + str(count)] = (probe._arms[role]["active_walking_session"].is_empty()
				and probe._arms[role]["walking_sessions"][-1]["evaluation"].get("behavioral_conclusion") == "none")
		checks["official_refuses_shortened_" + str(count)] = not probe.close_walking_session_sources_v2(probe._sdk, role, pristine.duplicate(true), receipt, false, after).get("ok", false)
		if count == after:
			for corruption in ["missing_row", "bad_shutdown", "unknown_bound"]:
				var changed := pristine.duplicate(true)
				var changed_receipt := receipt.duplicate(true)
				var bound := after
				if corruption == "missing_row":
					changed["trace_rows"].pop_back()
				elif corruption == "bad_shutdown":
					changed_receipt["adapter_shutdown_receipt"]["explicit_shutdown_completed"] = "false"
				else:
					bound += 1
				checks["real_close_rejects_" + corruption] = not probe.close_walking_session_sources_v2(probe._sdk, role, changed, changed_receipt, true, bound, policy_id).get("ok", false)
			checks["legacy_bound_refuses_long_close"] = not probe.close_walking_session_sources_v2(probe._sdk, role, pristine, receipt, true, 480, policy_id).get("ok", false)
	probe._arms.clear()
	probe._sdk = null

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var selection := Profile.load_v1({"resource": args[0], "raw_sha256": args[1]})
	var checks := {"profile_loaded": selection.has("diagnostic_schedule")}
	if not checks["profile_loaded"]:
		print("CANDIDATE_SCHEDULE_CHECKS ", Transport.stringify({"ok": false, "checks": checks}))
		quit(1)
		return
	var probe := Probe.new()
	probe._candidate_selection = selection
	probe._candidate_mode = selection["single_mode"]
	var limits := Profile.limits_v1(selection)
	for key in limits:
		checks["integer_protocol_" + key] = typeof(limits[key]) == TYPE_INT
	var after := int(limits["after_interaction_steps"])
	var declaration := limits.duplicate(true)
	declaration["diagnostic_schedule_id"] = selection["worker_selection"]["schedule"]
	checks["real_configure"] = probe._configure_smoke_schedule_v1(declaration)
	checks["real_cutoff_getter"] = probe._smoke_after_interaction_steps_v1() == after
	checks["real_walking_close_bound"] = probe._development_walking_diagnostic_maximum_steps_v1() == after
	var report := {}
	probe._attach_entry_retention_v1(report)
	checks["retained_bound"] = report["passive_entry"]["after_interaction_steps"] == after
	var state := {"epoch_start_global_step": 272, "phase": "post_kick_recovery"}
	checks["one_before_cutoff"] = Smoke.diagnostic_stop_reason_v1(state, 272 + after - 1, after).is_empty()
	checks["exact_cutoff"] = Smoke.diagnostic_stop_reason_v1(state, 272 + after, after) == "diagnostic_after_interaction_horizon"
	checks["total_resource_cap"] = Smoke.diagnostic_stop_reason_v1({"epoch_start_global_step": null, "phase": "walking_prefix"}, int(limits["maximum_steps_per_child"]), after) == "diagnostic_setup_or_total_horizon"
	for key in limits:
		for value in [false, "626", int(limits[key]) + 1]:
			var bad := declaration.duplicate(true)
			bad[key] = value
			checks["reject_" + key + str(value)] = not probe._configure_smoke_schedule_v1(bad)
	checks["refusal_keeps_bound"] = probe._smoke_after_interaction_steps_v1() == after
	_test_actual_walking_close(probe, selection, checks)
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_candidates/v14-knee-fold-replant-v1.json"))
	var old_path := "res://sdk/development/recovery_candidates/v14-knee-fold-replant-v1.json"
	probe._candidate_selection = Profile.load_v1({"resource": old_path, "raw_sha256": "sha256:" + FileAccess.get_sha256(old_path)})
	checks["controller_identity_matches_declared_schedule"] = selection["diagnostic_schedule"]["controller_id"] == selection["post_kick_controller_id"]
	checks["unchanged_or_explicit_successor"] = (old["post_kick_controller_id"] == selection["post_kick_controller_id"]
		or selection["diagnostic_schedule"]["coverage_basis"].get("new_controller_preserves_v14_recovery_motion") == true
		or selection["diagnostic_schedule"]["coverage_basis"].get("new_controller_preserves_existing_limits_and_later_phase_commands") == true
		or selection["diagnostic_schedule"]["coverage_basis"].get("new_controller_preserves_pre_stance_motion_and_limits") == true
		or (selection.diagnostic_schedule.walking_policy_id == Profile.WalkingPolicy.R10T.ID
			and selection.diagnostic_schedule.coverage_basis.get("successor_design_sha256") == "sha256:" + FileAccess.get_sha256("res://sdk/recovery/r10t_post_recovery_settling_design_v1.json"))
		or (selection.diagnostic_schedule.walking_policy_id == Profile.WalkingPolicy.R10N.ID
			and selection.diagnostic_schedule.coverage_basis.get("successor_design_sha256") == "sha256:" + FileAccess.get_sha256("res://sdk/recovery/r10n_zero_velocity_brake_successor_design_v1.json"))
		or (selection.diagnostic_schedule.walking_policy_id == Profile.WalkingPolicy.R10M.ID
			and selection.diagnostic_schedule.coverage_basis.get("successor_design_sha256") == "sha256:" + FileAccess.get_sha256("res://sdk/recovery/r10m_bounded_stop_velocity_successor_design_v1.json"))
		or (selection.diagnostic_schedule.walking_policy_id == Profile.WalkingPolicy.R10L.ID
			and selection.diagnostic_schedule.coverage_basis.get("successor_design_sha256") == "sha256:" + FileAccess.get_sha256("res://sdk/recovery/r10l_extended_support_transfer_successor_design_v1.json"))
		or (selection.diagnostic_schedule.walking_policy_id == Profile.WalkingPolicy.R10K.ID
			and selection.diagnostic_schedule.coverage_basis.get("successor_design_sha256") == "sha256:" + FileAccess.get_sha256("res://sdk/recovery/r10k_partial_fall_successor_design_v1.json")))
	checks["old_profile_refuses_long_tail"] = not probe._configure_smoke_schedule_v1(declaration)
	probe.free()
	print("CANDIDATE_SCHEDULE_CHECKS ", Transport.stringify({"ok": not checks.values().has(false), "checks": checks,
		"limits": limits, "world_build_count": 0, "solver_step_count": 0}))
	quit(0 if not checks.values().has(false) else 1)
