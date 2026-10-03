extends RefCounted
# gdlint: disable=max-line-length

## R10L development-only population. No R10J campaign authority is selected.
const Json := preload("res://sdk/adapters/godot/gdscript/r10j_campaign_seed_v1.gd")
const Route := preload("res://sdk/adapters/godot/gdscript/r10l_recovery_route_v1.gd")
const DESIGN := "res://sdk/recovery/r10l_extended_support_transfer_successor_design_v1.json"
const DESIGN_SHA := "sha256:e78bea54c7afd4db7f72b305af1f127847e8ed54cb9e18c03dfe244cf3eafc40"
const EVIDENCE := "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
const ROLES := ["matched_no_kick_continuation", "kick_passive_recovery_resume"]
const PAIR := "fresh_paired_development_diagnostic_v1"
const SINGLE := "single_kick_controller_diagnostic_v1"
const KEYS := ["schema_version", "source_commit", "candidate_profile", "design_binding", "seed",
	"required_entry_kind", "prerequisite_pair", "physical_acceptance_authority", "release_authority"]

static func seed_identity_v1(seed: int) -> Dictionary:
	if seed not in [40441, 40443]: return {}
	var phase := 241 if seed == 40441 else 243
	var label := "R10L-DEVELOPMENT-PREFIX-" + str(phase) + ("-PAIR-V1" if seed == 40441 else "-SINGLE-KICK-V1")
	return {"seed": seed, "label": label, "sha256": "sha256:" + label.sha256_text(), "prefix_phase": phase}

static func _hex(value: Variant, length: int) -> bool:
	if not (value is String) or value.length() != length: return false
	for letter in value:
		if letter not in "0123456789abcdef": return false
	return true

static func _positive_pair_v1(value: Variant, candidate: Dictionary) -> bool:
	if not (value is Dictionary) or value.get("schema_version") != "sporespore_r10l_finite_development_result_v1": return false
	if (not Json.same_json_v1(value.get("candidate_profile"), candidate) or not Json.same_json_v1(value.get("seed"), 40441)
		or value.get("all_tasks_positive") != true or value.get("branch_coverage_complete") != true
		or value.get("physical_acceptance_authority") != false or value.get("release_authority") != false): return false
	var cells: Variant = value.get("cells")
	if not (cells is Array) or cells.size() != 2: return false
	for index in 2:
		if not (cells[index] is Dictionary) or cells[index].get("role") != ROLES[index] or cells[index].get("finite_task_predicates_passed") != true: return false
	return cells[0].get("entry_kind") == "unselected" and cells[1].get("entry_kind") == "partial"

static func prerequisite_valid_v1(binding: Variant, candidate: Dictionary) -> bool:
	if not (binding is Dictionary) or binding.size() != 3 or not _hex(binding.get("attempt_id"), 32): return false
	var path: String = EVIDENCE + "development-recovery-smoke-" + binding.attempt_id + "/independent_audit.stdout.json"
	if binding.get("path") != path or not FileAccess.file_exists(path) or binding.get("raw_sha256") != "sha256:" + FileAccess.get_sha256(path): return false
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (record is Dictionary and record.get("ok") == true
		and record.get("schema_version") == "sporespore_sdk1_development_recovery_smoke_audit_v1"
		and _positive_pair_v1(record.get("r10l_finite_development"), candidate))

static func authorized_v1(declaration: Dictionary, seed_text: String, label: String, digest: String,
	role: String, source_commit: String) -> bool:
	if declaration.has("r10j_campaign") or declaration.has("r10k_development") or not seed_text.is_valid_int() or seed_text != str(seed_text.to_int()): return false
	var identity := seed_identity_v1(seed_text.to_int())
	if identity.is_empty() or identity.label != label or identity.sha256 != digest: return false
	var context: Variant = declaration.get("r10l_development")
	if not (context is Dictionary) or context.size() != KEYS.size(): return false
	for key in KEYS:
		if not context.has(key): return false
	if (context.schema_version != "sporespore_r10l_development_child_context_v1"
		or not _hex(source_commit, 40) or context.source_commit != source_commit
		or declaration.get("source_snapshot", {}).get("head") != source_commit
		or not Json.same_json_v1(context.seed, identity) or not Json.same_json_v1(declaration.get("seed"), identity.seed)
		or not Json.same_json_v1(context.candidate_profile, declaration.get("candidate_profile"))
		or not Json.same_json_v1(context.design_binding, {"resource": DESIGN, "raw_sha256": DESIGN_SHA})
		or "sha256:" + FileAccess.get_sha256(DESIGN) != DESIGN_SHA
		or context.physical_acceptance_authority != false or context.release_authority != false): return false
	var mode: String = declaration.get("development_execution_mode", "")
	var paired: bool = identity.seed == 40441
	if mode != (PAIR if paired else SINGLE) or context.required_entry_kind != ("partial" if paired else "prone"): return false
	var prefix := Route.prefix_selection_v1(identity.seed, Route.PREFIX_PROFILE)
	if prefix.get("prefix_phase") != identity.prefix_phase: return false
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
	return context.prerequisite_pair == null if paired else prerequisite_valid_v1(context.prerequisite_pair, declaration.candidate_profile)

static func attach_report_context_v1(report: Dictionary, declaration: Dictionary, seed: int) -> bool:
	var identity := seed_identity_v1(seed)
	if identity.is_empty() or not authorized_v1(declaration, str(seed), identity.label, identity.sha256,
		report.get("arm_id", ""), report.get("source_commit", "")): return false
	var child: Dictionary = declaration.children[ROLES.find(report.arm_id)] if seed == 40441 else declaration.children[0]
	if (report.get("child_attempt_id") != child.child_attempt_id
		or report.get("parent_attempt_id") != declaration.attempt_id
		or not Json.same_json_v1(report.get("seed"), seed)): return false
	var retained: Dictionary = declaration.r10l_development.duplicate(true)
	retained.seed = identity
	report["r10l_development"] = retained
	report["seed_label"] = identity.label
	report["seed_sha256"] = identity.sha256
	report["held_out"] = false
	report["held_out_cell_access_count"] = 0
	return true
