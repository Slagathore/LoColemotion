extends RefCounted
## Identity/publication binding for the first R10Z single-kick diagnostic.
## Admission is not safety qualification, attempt reservation or acceptance.
const Json := preload("res://sdk/adapters/godot/gdscript/r10j_campaign_seed_v1.gd")
const DESIGN := "res://sdk/recovery/r10z_partial_pose_geometry_development_design_v1.json"
const DESIGN_SHA := "sha256:26419b8b075df3265ab2d32c12b291762183528ed0c93c9ac2b65186e470ea76"
const EVIDENCE := "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
const ROLE := "kick_passive_recovery_resume"
const SINGLE := "single_kick_controller_diagnostic_v1"
const KEYS := ["schema_version", "source_commit", "candidate_profile", "design_binding", "seed",
	"required_entry_kind", "stage", "physical_acceptance_authority", "release_authority"]

static func seed_identity_v1(seed: int) -> Dictionary:
	if seed != 51008: return {}
	var label := "R10Z-DEVELOPMENT-PREFIX-248-V1"
	return {"seed": seed, "label": label, "sha256": "sha256:" + label.sha256_text(), "prefix_phase": 248}

static func _hex(value: Variant, length: int) -> bool:
	if not (value is String) or value.length() != length: return false
	for letter in value:
		if letter not in "0123456789abcdef": return false
	return true

static func authorized_v1(declaration: Dictionary, seed_text: String, label: String, digest: String,
	role: String, source_commit: String) -> bool:
	if seed_text != "51008" or role != ROLE: return false
	var crossed := RegEx.new()
	crossed.compile("^r10[a-z]+_(development|campaign|host)$")
	for key in declaration:
		if key != "r10z_development" and crossed.search(str(key)) != null: return false
	var identity := seed_identity_v1(51008)
	if label != identity.label or digest != identity.sha256: return false
	var context: Variant = declaration.get("r10z_development")
	if not (context is Dictionary) or context.size() != KEYS.size(): return false
	for key in KEYS:
		if not context.has(key): return false
	if (context.schema_version != "sporespore_r10z_development_child_context_v1"
		or not _hex(source_commit, 40) or context.source_commit != source_commit
		or declaration.get("source_snapshot", {}).get("head") != source_commit
		or declaration.get("development_execution_mode") != SINGLE
		or declaration.get("comparative_authority") != false or declaration.get("baseline_reused") != false
		or not Json.same_json_v1(context.seed, identity) or not Json.same_json_v1(declaration.get("seed"), 51008)
		or not Json.same_json_v1(context.candidate_profile, declaration.get("candidate_profile"))
		or not Json.same_json_v1(context.design_binding, {"resource": DESIGN, "raw_sha256": DESIGN_SHA})
		or "sha256:" + FileAccess.get_sha256(DESIGN) != DESIGN_SHA
		or context.required_entry_kind != "partial" or context.stage != "first_support_diagnostic"
		or context.physical_acceptance_authority != false or context.release_authority != false): return false
	var children: Variant = declaration.get("children")
	var attempt: Variant = declaration.get("attempt_id")
	if not _hex(attempt, 32) or not (children is Array) or children.size() != 1: return false
	var child: Variant = children[0]
	if not (child is Dictionary) or child.get("role") != ROLE: return false
	var seen := {attempt: true}
	for key in ["child_attempt_id", "termination_nonce"]:
		var id: Variant = child.get(key)
		if not _hex(id, 32) or seen.has(id): return false
		seen[id] = true
	var path: Variant = child.get("evidence_path")
	return path is String and path.replace("\\", "/") == EVIDENCE + "development-recovery-smoke-" + attempt + "/children/" + ROLE

static func attach_report_context_v1(report: Dictionary, declaration: Dictionary, seed: int) -> bool:
	var identity := seed_identity_v1(seed)
	if identity.is_empty() or not authorized_v1(declaration, str(seed), identity.label, identity.sha256,
		report.get("arm_id", ""), report.get("source_commit", "")): return false
	if (report.get("child_attempt_id") != declaration.children[0].child_attempt_id
		or report.get("parent_attempt_id") != declaration.attempt_id
		or not Json.same_json_v1(report.get("seed"), seed)): return false
	var retained: Dictionary = declaration.r10z_development.duplicate(true)
	retained.seed = identity
	report["r10z_development"] = retained
	report["seed_label"] = identity.label
	report["seed_sha256"] = identity.sha256
	report["held_out"] = false
	report["held_out_cell_access_count"] = 0
	return true
