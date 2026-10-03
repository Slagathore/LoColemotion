extends RefCounted
# gdlint: disable=max-line-length

## R10U development-only population. No R10J campaign authority is selected.
const Json := preload("res://sdk/adapters/godot/gdscript/r10j_campaign_seed_v1.gd")
const DESIGN := "res://sdk/recovery/r10u_audit_handoff_design_v1.json"
const DESIGN_SHA := "sha256:81f18c3e99929ee02c830f973c32c3db4fdb5917a5efa2863d59e5ee2a7fa981"
const EVIDENCE := "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
const ROLES := ["matched_no_kick_continuation", "kick_passive_recovery_resume"]
const PAIR := "fresh_paired_development_diagnostic_v1"
const SINGLE := "single_kick_controller_diagnostic_v1"
const KEYS := ["schema_version", "source_commit", "candidate_profile", "design_binding", "seed",
	"required_entry_kind", "required_handoff", "stage", "prerequisite_pair", "physical_acceptance_authority", "release_authority"]

static func seed_identity_v1(seed: int) -> Dictionary:
	if seed not in [41245, 41246, 41241, 41243]: return {}
	var phase: int = {41245: 245, 41246: 246, 41241: 241, 41243: 243}[seed]
	var label := "R10U-DEVELOPMENT-PREFIX-" + str(phase) + "-V1"
	return {"seed": seed, "label": label, "sha256": "sha256:" + label.sha256_text(), "prefix_phase": phase}

static func _hex(value: Variant, length: int) -> bool:
	if not (value is String) or value.length() != length: return false
	for letter in value:
		if letter not in "0123456789abcdef": return false
	return true

static func _positive_result_v1(value: Variant, candidate: Dictionary, paired: bool) -> bool:
	if not paired: return false
	if not (value is Dictionary) or value.get("schema_version") != "sporespore_r10u_finite_development_result_v1": return false
	if (not Json.same_json_v1(value.get("candidate_profile"), candidate) or not Json.same_json_v1(value.get("seed"), 41245)
		or value.get("all_tasks_positive") != true or value.get("branch_coverage_complete") != true
		or value.get("physical_acceptance_authority") != false or value.get("release_authority") != false): return false
	var cells: Variant = value.get("cells")
	var roles: Array = ROLES if paired else [ROLES[1]]
	if not (cells is Array) or cells.size() != roles.size(): return false
	for index in roles.size():
		if not (cells[index] is Dictionary) or cells[index].get("role") != roles[index] or cells[index].get("finite_task_predicates_passed") != true: return false
	if cells[-1].get("post_recovery_handoff") != "bounded_hold": return false
	return (cells[0].get("entry_kind") == "unselected" and cells[1].get("entry_kind") == "upright") if paired else cells[0].get("entry_kind") == "upright"

static func prerequisite_valid_v1(binding: Variant, candidate: Dictionary, paired: bool) -> bool:
	if not paired: return false
	if not (binding is Dictionary) or binding.size() != 3 or not _hex(binding.get("attempt_id"), 32): return false
	var path: String = EVIDENCE + "development-recovery-smoke-" + binding.attempt_id + "/independent_audit.stdout.json"
	if binding.get("path") != path or not FileAccess.file_exists(path) or binding.get("raw_sha256") != "sha256:" + FileAccess.get_sha256(path): return false
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (record is Dictionary and record.get("ok") == true
		and record.get("schema_version") == "sporespore_sdk1_development_recovery_smoke_audit_v1"
		and _positive_result_v1(record.get("r10u_finite_development"), candidate, paired))

static func authorized_v1(declaration: Dictionary, seed_text: String, label: String, digest: String,
	role: String, source_commit: String) -> bool:
	if declaration.has("r10t_development") or declaration.has("r10s_development") or declaration.has("r10r_development") or declaration.has("r10q_development") or declaration.has("r10p_campaign") or declaration.has("r10o_development") or declaration.has("r10j_campaign") or declaration.has("r10k_development") or declaration.has("r10l_development") or declaration.has("r10n_development") or declaration.has("r10m_development") or not seed_text.is_valid_int() or seed_text != str(seed_text.to_int()): return false
	var identity := seed_identity_v1(seed_text.to_int())
	if identity.is_empty() or identity.label != label or identity.sha256 != digest: return false
	var context: Variant = declaration.get("r10u_development")
	if not (context is Dictionary) or context.size() != KEYS.size(): return false
	for key in KEYS:
		if not context.has(key): return false
	if (context.schema_version != "sporespore_r10u_development_child_context_v1"
		or not _hex(source_commit, 40) or context.source_commit != source_commit
		or declaration.get("source_snapshot", {}).get("head") != source_commit
		or not Json.same_json_v1(context.seed, identity) or not Json.same_json_v1(declaration.get("seed"), identity.seed)
		or not Json.same_json_v1(context.candidate_profile, declaration.get("candidate_profile"))
		or not Json.same_json_v1(context.design_binding, {"resource": DESIGN, "raw_sha256": DESIGN_SHA})
		or "sha256:" + FileAccess.get_sha256(DESIGN) != DESIGN_SHA
		or context.physical_acceptance_authority != false or context.release_authority != false): return false
	if context.required_handoff != ("bounded_hold" if identity.seed == 41245 else "direct"): return false
	var mode: String = declaration.get("development_execution_mode", "")
	var paired: bool = mode == PAIR
	if mode not in [PAIR, SINGLE] or (paired and identity.seed != 41245) or (not paired and identity.seed == 41245): return false
	if mode != (PAIR if paired else SINGLE) or context.required_entry_kind != {41245: "upright", 41246: "upright", 41241: "partial", 41243: "prone"}[identity.seed]: return false
	var roles: Array = ROLES if paired else [ROLES[1]]
	var children: Variant = declaration.get("children")
	var attempt: Variant = declaration.get("attempt_id")
	if not _hex(attempt, 32) or not (children is Array) or children.size() != roles.size() or role not in roles: return false
	var seen := {}
	for index in roles.size():
		var child: Variant = children[index]
		if not (child is Dictionary) or child.get("role") != roles[index]: return false
		for key in ["child_attempt_id", "termination_nonce"]:
			var id: Variant = child.get(key)
			if not _hex(id, 32) or seen.has(id) or id == attempt: return false
			seen[id] = true
		var path: Variant = child.get("evidence_path")
		if not (path is String) or path.replace("\\", "/") != EVIDENCE + "development-recovery-smoke-" + attempt + "/children/" + roles[index]: return false
	if paired:
		return context.stage == "paired_commissioning" and context.prerequisite_pair == null
	return context.stage == "additional_branch_diagnostic" and prerequisite_valid_v1(context.prerequisite_pair, declaration.candidate_profile, true)

static func attach_report_context_v1(report: Dictionary, declaration: Dictionary, seed: int) -> bool:
	var identity := seed_identity_v1(seed)
	if identity.is_empty() or not authorized_v1(declaration, str(seed), identity.label, identity.sha256,
		report.get("arm_id", ""), report.get("source_commit", "")): return false
	var child: Dictionary = declaration.children[ROLES.find(report.arm_id)] if declaration.development_execution_mode == PAIR else declaration.children[0]
	if (report.get("child_attempt_id") != child.child_attempt_id
		or report.get("parent_attempt_id") != declaration.attempt_id
		or not Json.same_json_v1(report.get("seed"), seed)): return false
	var retained: Dictionary = declaration.r10u_development.duplicate(true)
	retained.seed = identity
	report["r10u_development"] = retained
	report["seed_label"] = identity.label
	report["seed_sha256"] = identity.sha256
	report["held_out"] = false
	report["held_out_cell_access_count"] = 0
	return true
