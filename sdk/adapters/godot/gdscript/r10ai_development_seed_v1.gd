extends RefCounted
## Identity admission only. Complete safety qualification and a durable single-use
## launch reservation are separate requirements, not provided by this module.
const Json := preload("res://sdk/adapters/godot/gdscript/r10j_campaign_seed_v1.gd")
const DESIGN := "res://sdk/recovery/r10ai_concurrent_load_rise_development_design_v1.json"
const DESIGN_SHA := "sha256:b23215cd2f22c72fb1b31533f6908e6dcb4027e88f107b186e808a600de7a7d1"
const PROFILE := "res://sdk/development/recovery_candidates/r10ai-concurrent-load-rise-v1.json"
const PROFILE_SHA := "sha256:4e96488af333ef61c99c57b69629ef6b13329dc334e03deca92b1718ec98b7e7"
const PREFIX_PROFILE := "r10ai_declared_concurrent_load_rise_prefix_phase_v1"
const EVIDENCE := "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
const CONTEXT_KEY := "r10ai_development"
const ROLE := "kick_passive_recovery_resume"
const SINGLE := "single_kick_controller_diagnostic_v1"
const SEED := 67248


static func seed_identity_v1(seed: int) -> Dictionary:
	if seed != SEED: return {}
	var label := "R10AI-CONCURRENT-LOAD-RISE-PREFIX-248-V1"
	return {"seed": seed, "label": label, "sha256": "sha256:" + label.sha256_text(), "prefix_phase": 248}


static func prefix_selection_v1(seed: int, profile: String) -> Dictionary:
	if seed != SEED or profile != PREFIX_PROFILE: return {}
	return {"schema_version": "sporespore_r10ai_prefix_phase_selection_v1", "profile_id": profile,
		"seed": seed, "prefix_phase": 248, "source_design_sha256": DESIGN_SHA,
		"physical_acceptance_authority": false, "release_authority": false}


static func prefix_gait_steps_v1(seed: int, profile: String) -> Dictionary:
	if prefix_selection_v1(seed, profile).is_empty(): return {}
	return {"front_left": 248, "front_right": 248, "rear_left": 248, "rear_right": 248}


static func _hex(value: Variant, length: int) -> bool:
	if not (value is String) or value.length() != length: return false
	for letter in value:
		if letter not in "0123456789abcdef": return false
	return true


static func authorized_v1(declaration: Dictionary, seed_text: String, label: String, digest: String,
	role: String, source_commit: String) -> bool:
	if seed_text != str(SEED) or role != ROLE or not _hex(source_commit, 40): return false
	var crossed := RegEx.new()
	crossed.compile("^r10[a-z]+_(development|campaign|host)$")
	for key in declaration:
		if key != "r10ai_development" and crossed.search(str(key)) != null: return false
	for key in ["comparative_authority", "baseline_reused", "official_qualification", "physical_acceptance_authority", "release_authority"]:
		if typeof(declaration.get(key)) != TYPE_BOOL or declaration[key]: return false
	var identity := seed_identity_v1(SEED)
	if label != identity.label or digest != identity.sha256: return false
	if not Json.same_json_v1(declaration.get("source_snapshot"), {"head": source_commit,
		"dirty": false, "status": [], "changed_file_bindings": []}): return false
	if (declaration.get("development_execution_mode") != SINGLE
		or not Json.same_json_v1(declaration.get("seed"), SEED)
		or not Json.same_json_v1(declaration.get("candidate_profile"), {"resource": PROFILE, "raw_sha256": PROFILE_SHA})
		or "sha256:" + FileAccess.get_sha256(DESIGN) != DESIGN_SHA
		or "sha256:" + FileAccess.get_sha256(PROFILE) != PROFILE_SHA): return false
	var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DESIGN))
	var expected := {"schema_version": "sporespore_r10ai_development_child_context_v1",
		"source_commit": source_commit, "candidate_profile": {"resource": PROFILE, "raw_sha256": PROFILE_SHA},
		"design_binding": {"resource": DESIGN, "raw_sha256": DESIGN_SHA}, "seed": identity,
		"required_entry_kind": "partial", "stage": "concurrent_load_rise_recovery_diagnostic",
		"classification_frame_profile_id": design.preserved.contact_profile,
		"contact_source_schema": design.preserved.contact_source_schema,
		"physical_acceptance_authority": false, "release_authority": false}
	if not Json.same_json_v1(declaration.get("r10ai_development"), expected): return false
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
	report["r10ai_development"] = declaration.r10ai_development.duplicate(true)
	# The real worker uses JSON.parse_string for its declaration, which represents
	# JSON integers as binary64. Publish the already-validated typed seed identity,
	# matching the original integer JSON and the independent Python reader.
	report.r10ai_development.seed = identity
	report["seed_label"] = identity.label
	report["seed_sha256"] = identity.sha256
	report["held_out"] = false
	report["held_out_cell_access_count"] = 0
	return true
