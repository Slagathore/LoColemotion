extends RefCounted
## A report carries the original admitted declaration, never a promoted discovery identity.
const CONTEXT_KEY := "r10dh_campaign"
const SEED := 0 # The declaration owns the actual seed; this is the reader-interface sentinel.

static func attach_report_context_v1(report: Dictionary, declaration: Dictionary, seed: int) -> bool:
	if declaration.get("campaign_kind") != "r10dh_finite_recovery_v1": return false
	if not declaration.get("children") is Array or declaration.children.size() != 1: return false
	var child: Dictionary = declaration.children[0]
	var context: Dictionary = declaration.get(CONTEXT_KEY, {})
	if context.get("schema_version") != "sporespore_r10dh_campaign_child_context_v1": return false
	if context.get("mode") not in ["development_ghost", "held_out"]: return false
	if context.get("role") != child.role or child.role not in ["matched_no_kick_continuation", "kick_passive_recovery_resume"]: return false
	if seed != 0 and seed != int(declaration.seed): return false
	if (report.get("seed") != declaration.seed or report.get("arm_id") != child.role
		or report.get("source_commit") != declaration.source_snapshot.head
		or report.get("child_attempt_id") != child.child_attempt_id
		or report.get("parent_attempt_id") != declaration.attempt_id): return false
	if report.get("physical_acceptance_authority") != false or report.get("release_authority") != false: return false
	if report.get("official_qualification", false) != false or report.get("complete_route_proven", false) != false: return false
	for key in ["official_qualification", "physical_acceptance_authority", "release_authority"]:
		if declaration.get(key) != false: return false
	var identity: Dictionary = context.get("seed", {})
	if identity.get("seed") != declaration.seed or typeof(identity.get("label")) != TYPE_STRING: return false
	if identity.get("sha256") != "sha256:" + String(identity.label).sha256_text(): return false
	if typeof(identity.get("prefix_phase")) not in [TYPE_INT, TYPE_FLOAT]: return false
	if identity.prefix_phase != floor(identity.prefix_phase): return false
	var phase := int(identity.prefix_phase)
	if phase not in ([71] if context.mode == "development_ghost" else [72, 73, 74]): return false
	if int(declaration.seed) != 93600 + phase: return false
	var label := "R10DH-" + String(context.mode).to_upper() + "-PREFIX-" + str(phase) + "-SEED-" + str(93600 + phase) + "-V1"
	if identity.label != label: return false
	# JSON.parse_string materializes declaration numbers as floats. Reconstruct
	# the five integer fields before the authoritative serializer sees them;
	# never relax the independent reader's exact type or boolean checks.
	var canonical := context.duplicate(true)
	for key in ["seed", "prefix_phase"]:
		if not _exact_nonnegative_integer(identity.get(key)): return false
		canonical.seed[key] = int(identity[key])
	for key in ["manifest", "task_contract", "design"]:
		if not context.get(key) is Dictionary: return false
		if not _exact_nonnegative_integer(context[key].get("byte_length")): return false
		canonical[key].byte_length = int(context[key].byte_length)
	report[CONTEXT_KEY] = canonical
	report["seed_label"] = identity.label
	report["seed_sha256"] = identity.sha256
	report["held_out"] = context.mode == "held_out"
	report["held_out_cell_access_count"] = 1 if context.mode == "held_out" else 0
	report["official_qualification"] = false
	report["physical_acceptance_authority"] = false
	report["release_authority"] = false
	return true

static func _exact_nonnegative_integer(value: Variant) -> bool:
	return (typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
		and value >= 0 and value < 9007199254740992 and value == floor(value))
