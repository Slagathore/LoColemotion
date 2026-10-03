extends SceneTree
# gdlint: disable=max-line-length
const Worker := preload("res://sdk/adapters/godot/gdscript/r10r_recovery_worker_v1.gd")
class Probe:
	extends "res://sdk/adapters/godot/gdscript/r10r_recovery_worker_v1.gd"
	func _initialize() -> void: pass

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var declaration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var probe := Probe.new()
	probe._candidate_selection = Worker.CandidateProfile.load_v1(declaration.candidate_profile)
	probe._campaign_declaration = declaration
	var seed := Worker.R10RSeed.seed_identity_v1(40946)
	var checks := {"candidate_loaded": not probe._candidate_selection.is_empty()}
	OS.set_environment(Worker.PARENT_ATTEMPT_ID_ENV, declaration.attempt_id)
	OS.set_environment(Worker.SOURCE_COMMIT_ENV, declaration.source_snapshot.head)
	for child in declaration.children:
		OS.set_environment(Worker.CHILD_ROLE_ENV, child.role)
		OS.set_environment(Worker.ATTEMPT_ID_ENV, child.child_attempt_id)
		OS.set_environment(Worker.NONCE_ENV, child.termination_nonce)
		checks["authorized_" + child.role] = probe._authorized_seed_binding_v1("40946", seed.label, seed.sha256)
		var report := {"arm_id": child.role, "child_attempt_id": child.child_attempt_id,
			"parent_attempt_id": declaration.attempt_id, "source_commit": declaration.source_snapshot.head, "seed": 40946}
		checks["publication_" + child.role] = Worker.R10RSeed.attach_report_context_v1(report, declaration, 40946)
		for field in ["child_attempt_id", "parent_attempt_id", "seed", "source_commit"]:
			var crossed := report.duplicate(true)
			crossed[field] = 40200 if field == "seed" else "crossed"
			checks["publication_refuses_" + child.role + "_" + field] = not Worker.R10RSeed.attach_report_context_v1(crossed, declaration, 40946)
	for invalid in [40541, 40200, 40442, 40943, 50641]:
		checks["seed_refused_" + str(invalid)] = not probe._authorized_seed_binding_v1(str(invalid), seed.label, seed.sha256)
	checks["noncanonical_seed_spelling_refused"] = not probe._authorized_seed_binding_v1("040946", seed.label, seed.sha256)
	checks["crossed_label_refused"] = not probe._authorized_seed_binding_v1("40946", "crossed", seed.sha256)
	checks["crossed_seed_digest_refused"] = not probe._authorized_seed_binding_v1("40946", seed.label, "sha256:" + "0".repeat(64))
	for field in ["source_commit", "required_entry_kind", "design_binding", "candidate_profile", "stage", "prerequisite_single_diagnostic", "prerequisite_pair", "physical_acceptance_authority"]:
		probe._campaign_declaration = declaration.duplicate(true)
		probe._campaign_declaration.r10r_development[field] = true if field == "physical_acceptance_authority" else {} if field in ["design_binding", "candidate_profile", "prerequisite_single_diagnostic", "prerequisite_pair"] else "crossed"
		checks["context_refused_" + field] = not probe._authorized_seed_binding_v1("40946", seed.label, seed.sha256)
	probe._campaign_declaration = declaration
	OS.set_environment(Worker.NONCE_ENV, "0".repeat(32))
	checks["crossed_child_nonce_refused"] = not probe._authorized_seed_binding_v1("40946", seed.label, seed.sha256)
	OS.set_environment(Worker.NONCE_ENV, declaration.children[0].termination_nonce)
	probe._campaign_declaration = declaration.duplicate(true)
	probe._campaign_declaration["r10j_campaign"] = {}
	checks["crossed_r10j_authority_refused"] = not probe._authorized_seed_binding_v1("40946", seed.label, seed.sha256)
	probe._campaign_declaration = declaration.duplicate(true)
	probe._campaign_declaration["r10k_development"] = {}
	checks["crossed_r10k_context_refused"] = not probe._authorized_seed_binding_v1("40946", seed.label, seed.sha256)
	probe._campaign_declaration = declaration.duplicate(true)
	probe._campaign_declaration["r10l_development"] = {}
	checks["crossed_r10l_context_refused"] = not probe._authorized_seed_binding_v1("40946", seed.label, seed.sha256)
	probe._campaign_declaration = declaration.duplicate(true)
	probe._campaign_declaration["r10m_development"] = {}
	checks["crossed_r10m_context_refused"] = not probe._authorized_seed_binding_v1("40946", seed.label, seed.sha256)
	probe._campaign_declaration = declaration.duplicate(true)
	probe._campaign_declaration["r10q_development"] = {}
	checks["crossed_r10q_context_refused"] = not probe._authorized_seed_binding_v1("40946", seed.label, seed.sha256)
	for mode in [Worker.R10RSeed.PAIR, Worker.R10RSeed.SINGLE]:
		var later := declaration.duplicate(true)
		later.development_execution_mode = mode
		later.r10r_development.stage = "paired_commissioning" if mode == Worker.R10RSeed.PAIR else "additional_branch_diagnostic"
		probe._campaign_declaration = later
		checks["missing_prerequisite_refused_" + mode] = not probe._authorized_seed_binding_v1("40946", seed.label, seed.sha256)
	for paired in [false, true]:
		var roles: Array = Worker.R10RSeed.ROLES if paired else [Worker.R10RSeed.ROLES[1]]
		var cells := []
		for role in roles:
			cells.append({"role": role, "entry_kind": "unselected" if role == roles[0] and paired else "upright", "finite_task_predicates_passed": true})
		var positive := {"schema_version": "sporespore_r10r_finite_development_result_v1", "candidate_profile": declaration.candidate_profile,
			"seed": 40946, "cells": cells, "all_tasks_positive": true, "branch_coverage_complete": true,
			"physical_acceptance_authority": false, "release_authority": false}
		checks["positive_shape_" + str(paired)] = Worker.R10RSeed._positive_result_v1(positive, declaration.candidate_profile, paired)
		checks["crossed_population_shape_refused_" + str(paired)] = not Worker.R10RSeed._positive_result_v1(positive, declaration.candidate_profile, not paired)
		for index in cells.size():
			var negative := positive.duplicate(true)
			negative.cells[index].finite_task_predicates_passed = false
			checks["negative_cell_refused_" + str(paired) + "_" + str(index)] = not Worker.R10RSeed._positive_result_v1(negative, declaration.candidate_profile, paired)
	var result := {"ok": not checks.values().has(false), "checks": checks,
		"world_build_count": 0, "solver_step_count": 0, "sdk_instantiation_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(result) + "\n"); file.close()
	probe.free()
	print("R10R_SEED_GUARD ", JSON.stringify(result))
	quit(0 if result.ok else 1)
