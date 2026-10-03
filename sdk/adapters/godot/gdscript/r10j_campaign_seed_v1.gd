extends RefCounted
## Authority-bound fixture selection before SDK, model, or world construction.
## Repository graph and single-use consumption are checked by the launcher;
## this guard independently binds the selected child to their retained bytes.
const CAMPAIGN_ID := "R10J-HELD-OUT-FINITE-DECISION-V1"
const AUTHORITY := "res://sdk/recovery/r10j_held_out_execution_authority_v1.json"
const PREREGISTRATION := "res://sdk/recovery/r10j_held_out_preregistration_v4.json"
const CANDIDATE := "res://sdk/development/recovery_candidates/r10j-v50-campaign-v4.json"
const EVIDENCE := "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
const ROLES := ["matched_no_kick_continuation", "kick_passive_recovery_resume"]
const SEEDS := [50641, 50642, 50643]
const DEVELOPMENT_LABEL := "QSDK-R10F/development/godot/event-triggered-passive-recovery-v1"
const DEVELOPMENT_SHA := "sha256:efa3c38b428cc5f2daa6b156a8e3e35769623c7c23af6f9079b1d27c66e190fa"

static func same_json_v1(actual: Variant, expected: Variant) -> bool:
	# Godot's JSON parser represents declared integers as binary64. Validate
	# their exact integer domain without rewriting retained JSON or accepting bools.
	if typeof(expected) == TYPE_INT:
		return (typeof(actual) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(actual))
			and absf(float(actual)) <= 9007199254740991.0 and float(actual) == float(expected))
	if typeof(actual) != typeof(expected):
		return false
	if actual is Dictionary:
		if actual.size() != expected.size(): return false
		for key in expected:
			if not actual.has(key) or not same_json_v1(actual[key], expected[key]): return false
		return true
	if actual is Array:
		if actual.size() != expected.size(): return false
		for i in expected.size():
			if not same_json_v1(actual[i], expected[i]): return false
		return true
	return actual == expected


static func seed_identity_v1(seed: int) -> Dictionary:
	if seed == 40200:
		return {"seed": seed, "label": DEVELOPMENT_LABEL, "sha256": DEVELOPMENT_SHA, "prefix_phase": 240}
	if seed not in SEEDS:
		return {}
	var label := CAMPAIGN_ID+"/godot/prefix-phase-"+str(seed % 360)+"/seed-"+str(seed)
	return {"seed": seed, "label": label, "sha256": "sha256:"+label.sha256_text(), "prefix_phase": seed % 360}


static func population_v1(mode: String) -> Array:
	if mode not in ["development_ghost", "held_out_finite_decision"]:
		return []
	var result: Array = []
	for seed in [40200] if mode == "development_ghost" else SEEDS:
		for role in ROLES:
			result.append({"cell_id": str(seed)+":"+role, "seed": seed_identity_v1(seed), "role": role,
				"maximum_world_attempts": 1, "maximum_world_builds": 1,
				"maximum_solver_steps": 2552 if role == ROLES[0] else 3512})
	return result


static func attach_report_context_v1(report: Dictionary, declaration: Dictionary, seed: int) -> bool:
	if not declaration.has("r10j_campaign"):
		return true
	var context: Variant = declaration.r10j_campaign
	var expected_seed := seed_identity_v1(seed)
	if not (context is Dictionary) or expected_seed.is_empty():
		return false
	var mode: String = context.get("mode", "")
	if (mode not in ["development_ghost", "held_out_finite_decision"]
		or (mode == "development_ghost") != (seed == 40200)
		or not same_json_v1(context.get("seed"), expected_seed)):
		return false
	# Publish the already validated declaration's integer seed fields as integers.
	# Generic JSON parsing produces floats; the authoritative emitter preserves
	# that type. Do not alter the declaration or any measured report value.
	var retained: Dictionary = context.duplicate(true)
	retained["seed"] = expected_seed
	report["r10j_campaign"] = retained
	report["seed_label"] = expected_seed.label
	report["seed_sha256"] = expected_seed.sha256
	report["held_out"] = mode == "held_out_finite_decision"
	report["held_out_cell_access_count"] = 1 if report.held_out else 0
	report["ledger_scope"]["authority_mode"] = mode
	report["ledger_scope"]["question_class"] = "finite decision" if report.held_out else "development"
	return true


static func _bound_json_v1(binding: Variant, exact_path: String) -> Dictionary:
	if not (binding is Dictionary) or binding.get("path") != exact_path or not FileAccess.file_exists(exact_path):
		return {}
	if binding.get("raw_sha256") != "sha256:"+FileAccess.get_sha256(exact_path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(exact_path))
	return value if value is Dictionary else {}


static func validate_shape_v1(context: Dictionary, declaration: Dictionary, claim: Dictionary,
	authority: Dictionary, preregistration: Dictionary, seed_text: String, label: String,
	digest: String, role: String, source_commit: String) -> bool:
	if not seed_text.is_valid_int() or seed_text != str(seed_text.to_int()) or role not in ROLES:
		return false
	var expected_seed := seed_identity_v1(seed_text.to_int())
	var mode: String = context.get("mode", "")
	var cells := population_v1(mode)
	if expected_seed.is_empty() or cells.is_empty() or expected_seed.label != label or expected_seed.sha256 != digest:
		return false
	if context.get("schema_version") != "sporespore_r10j_campaign_child_context_v1" or context.get("source_commit") != source_commit:
		return false
	if not same_json_v1(context.get("seed"), expected_seed) or not same_json_v1(declaration.get("seed"), expected_seed.seed):
		return false
	if declaration.get("candidate_profile", {}).get("resource") != CANDIDATE:
		return false
	if context.get("candidate_profile") != declaration.get("candidate_profile") or claim.get("candidate_profile") != context.get("candidate_profile"):
		return false
	if claim.get("schema_version") != "sporespore_r10j_campaign_claim_v1" or claim.get("mode") != mode or not same_json_v1(claim.get("cells"), cells):
		return false
	if claim.get("attempt_id") != context.get("campaign_attempt_id") or claim.get("source_commit") != source_commit:
		return false
	var selected: Array = cells.filter(func(cell): return cell.seed == expected_seed and cell.role == role)
	if selected.size() != 1:
		return false
	var children: Array = claim.get("children", [])
	if children.size() != cells.size(): return false
	var seen := {}
	for index in cells.size():
		var child: Variant = children[index]
		if not (child is Dictionary) or child.get("cell_id") != cells[index].cell_id: return false
		var child_id: Variant = child.get("child_attempt_id")
		if not (child_id is String) or child_id.is_empty() or seen.has(child_id): return false
		seen[child_id] = true
	var bound: Array = children.filter(func(child): return child.get("cell_id") == selected[0].cell_id)
	if bound.size() != 1 or bound[0].get("parent_attempt_id") != declaration.get("attempt_id"):
		return false
	var descriptors: Array = declaration.get("children", [])
	var descriptors_for_role := descriptors.filter(func(child): return child.get("role") == role)
	if descriptors_for_role.size() != 1 or bound[0].get("child_attempt_id") != descriptors_for_role[0].get("child_attempt_id"):
		return false
	if mode == "development_ghost":
		return expected_seed.seed == 40200 and authority.is_empty() and preregistration.is_empty()
	if expected_seed.seed not in SEEDS or authority.get("campaign_id") != CAMPAIGN_ID:
		return false
	if authority.get("schema_version") != "sporespore_r10j_execution_authority_v1" or not same_json_v1(authority.get("physical_execution_authorized"), true):
		return false
	if not same_json_v1(authority.get("cells"), cells) or authority.get("candidate_profile") != context.get("candidate_profile"):
		return false
	if not same_json_v1(authority.get("retry_permitted"), false) or not same_json_v1(authority.get("cell_replacement_permitted"), false):
		return false
	if not same_json_v1(authority.get("physical_acceptance_authority"), false) or not same_json_v1(authority.get("release_authority"), false):
		return false
	var caps := {"maximum_campaign_attempt_count": 1, "maximum_world_attempt_count": 6, "maximum_solver_step_count": 18192}
	for key in caps:
		if not same_json_v1(authority.get(key), caps[key]): return false
	if authority.get("preregistration_sha256") != context.get("preregistration_binding", {}).get("raw_sha256"):
		return false
	return preregistration.get("campaign_id") == CAMPAIGN_ID and same_json_v1(preregistration.get("cells"), cells) and preregistration.get("candidate_profile") == context.get("candidate_profile")


static func authorized_v1(declaration: Dictionary, seed_text: String, label: String,
	digest: String, role: String, source_commit: String) -> bool:
	var context: Variant = declaration.get("r10j_campaign")
	if not (context is Dictionary):
		return false
	var mode: String = context.get("mode", "")
	var id: String = context.get("campaign_attempt_id", "")
	var pattern := RegEx.new()
	pattern.compile("^[0-9a-f]{32}$")
	if pattern.search(id) == null:
		return false
	var claim_path := EVIDENCE+("r10j-production-ghost-"+id if mode == "development_ghost" else "r10j-held-out-finite-decision-v1")+"/campaign_claim.json"
	var claim := _bound_json_v1(context.get("claim_binding"), claim_path)
	var authority := {}
	var preregistration := {}
	if mode == "held_out_finite_decision":
		authority = _bound_json_v1(context.get("authority_binding"), AUTHORITY)
		preregistration = _bound_json_v1(context.get("preregistration_binding"), PREREGISTRATION)
	return validate_shape_v1(context, declaration, claim, authority, preregistration,
		seed_text, label, digest, role, source_commit)
