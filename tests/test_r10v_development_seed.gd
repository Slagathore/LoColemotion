extends SceneTree
# gdlint: disable=max-line-length
## Direct production population guard; no worker, SDK, or physical world.
const Guard := preload("res://sdk/adapters/godot/gdscript/r10v_development_seed_v1.gd")

func allowed(value: Dictionary, role: String = Guard.ROLES[1]) -> bool:
	var identity := Guard.seed_identity_v1(int(value.seed))
	# Godot's generic JSON reader yields floats; the launcher passes canonical integers.
	return Guard.authorized_v1(value, str(int(value.seed)), identity.label, identity.sha256, role, value.source_snapshot.head)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var declaration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var checks := {}
	for child in declaration.children:
		checks["pair_role_" + child.role] = allowed(declaration, child.role)
		var report := {"arm_id": child.role, "child_attempt_id": child.child_attempt_id,
			"parent_attempt_id": declaration.attempt_id, "source_commit": declaration.source_snapshot.head, "seed": 41345}
		checks["publication_" + child.role] = Guard.attach_report_context_v1(report, declaration, 41345)
		for field in ["child_attempt_id", "parent_attempt_id", "source_commit", "seed"]:
			var crossed := report.duplicate(true)
			crossed[field] = 41145 if field == "seed" else "crossed"
			checks["publication_refuses_" + child.role + "_" + field] = not Guard.attach_report_context_v1(crossed, declaration, 41345)
	for field in ["source_commit", "required_entry_kind", "required_handoff", "stage", "design_binding", "candidate_profile", "prerequisite_pair", "release_authority"]:
		var crossed := declaration.duplicate(true)
		crossed.r10v_development[field] = true if field == "release_authority" else {} if field in ["design_binding", "candidate_profile", "prerequisite_pair"] else "crossed"
		checks["context_refuses_" + field] = not allowed(crossed)
	for field in ["r10j_campaign", "r10k_development", "r10l_development", "r10m_development", "r10n_development", "r10o_development", "r10p_campaign", "r10q_development", "r10r_development", "r10s_development", "r10t_development", "r10u_development"]:
		var crossed := declaration.duplicate(true); crossed[field] = {}
		checks["crossed_authority_" + field] = not allowed(crossed)
	for seed in [41145, 40200, 50641]:
		checks["old_or_held_out_seed_" + str(seed)] = Guard.seed_identity_v1(seed).is_empty()
	var identity := Guard.seed_identity_v1(41345)
	checks["noncanonical_seed"] = not Guard.authorized_v1(declaration, "041345", identity.label, identity.sha256, Guard.ROLES[1], declaration.source_snapshot.head)
	var single := declaration.duplicate(true); single.development_execution_mode = Guard.SINGLE
	checks["single_first_refused"] = not allowed(single)
	var missing := declaration.duplicate(true); missing.children.remove_at(0)
	checks["missing_baseline_refused"] = not allowed(missing)
	var reused := declaration.duplicate(true); reused.children[1].child_attempt_id = reused.children[0].child_attempt_id
	checks["reused_child_refused"] = not allowed(reused)
	for seed in [41346, 41341, 41343]:
		var later := declaration.duplicate(true)
		later.seed = seed; later.r10v_development.seed = Guard.seed_identity_v1(seed)
		later.r10v_development.required_handoff = "direct"
		later.r10v_development.required_entry_kind = {41346: "upright", 41341: "partial", 41343: "prone"}[seed]
		later.r10v_development.stage = "additional_branch_diagnostic"
		later.development_execution_mode = Guard.SINGLE; later.children.remove_at(0)
		checks["later_missing_pair_" + str(seed)] = not allowed(later)
	var cells := [{"role": Guard.ROLES[0], "entry_kind": "unselected", "post_recovery_handoff": "direct", "finite_task_predicates_passed": true},
		{"role": Guard.ROLES[1], "entry_kind": "upright", "post_recovery_handoff": "bounded_hold", "finite_task_predicates_passed": true}]
	var positive := {"schema_version": "sporespore_r10v_finite_development_result_v1", "candidate_profile": declaration.candidate_profile,
		"seed": 41345, "cells": cells, "all_tasks_positive": true, "branch_coverage_complete": true,
		"physical_acceptance_authority": false, "release_authority": false}
	checks["positive_pair"] = Guard._positive_result_v1(positive, declaration.candidate_profile, true)
	checks["single_cannot_qualify"] = not Guard._positive_result_v1(positive, declaration.candidate_profile, false)
	for index in cells.size():
		var negative := positive.duplicate(true); negative.cells[index].finite_task_predicates_passed = false
		checks["negative_cell_" + str(index)] = not Guard._positive_result_v1(negative, declaration.candidate_profile, true)
	var observed := {"ok": not checks.values().has(false), "checks": checks, "world_build_count": 0,
		"solver_step_count": 0, "sdk_instantiation_count": 0, "physical_acceptance_authority": false, "release_authority": false}
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	output.store_string(JSON.stringify(observed) + "\n"); output.close()
	print("R10V_POPULATION_GUARD ", JSON.stringify(observed))
	quit(0 if observed.ok else 1)
