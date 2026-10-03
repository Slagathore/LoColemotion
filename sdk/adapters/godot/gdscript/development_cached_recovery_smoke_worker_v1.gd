extends "res://sdk/adapters/godot/gdscript/development_profiled_recovery_smoke_worker_v1.gd"

const CACHE_PROFILE_ID := "recovery_exact_context_checks_v1"
const WORKER_RESOURCE := "res://sdk/adapters/godot/gdscript/development_cached_recovery_smoke_worker_v1.gd"
const CACHE_CALL_SITES := ["epoch_preflight", "global_context_validation"]
const EVIDENCE_ROOT := "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
const PRONE_DEADLINE_SCHEDULE := "existing_prone_confirmation_deadline_v1"
var _context_cache := CountedContextCache.new()
var _declared_after_interaction_steps := SMOKE_AFTER_INTERACTION_STEPS


class CountedContextCache:
	extends "res://sdk/adapters/godot/gdscript/development_exact_context_cache_v1.gd"
	var calls: Array[int] = [0, 0]

	func validate_v1(sdk: Object, context: Dictionary, predicate: int) -> bool:
		if predicate in [CONTIGUOUS_BEHAVIOR, DISCRETE_LIVE]:
			calls[predicate] += 1
		return super.validate_v1(sdk, context, predicate)


func _declaration_path_v1() -> String:
	return EVIDENCE_ROOT + "development-recovery-smoke-" + OS.get_environment(PARENT_ATTEMPT_ID_ENV) + "/declaration.json"


func _load_campaign_binding_v1() -> bool:
	if not super._load_campaign_binding_v1():
		return false
	var path := _declaration_path_v1()
	if not FileAccess.file_exists(path):
		return false
	var raw := FileAccess.get_file_as_string(path)
	if not _development_declaration_valid_v1(raw):
		return false
	return _configure_smoke_schedule_v1(JSON.parse_string(raw))


func _development_declaration_valid_v1(raw: String) -> bool:
	return declaration_allows_cache_v1(raw, _authorization_sha256, _source_commit,
		_parent_attempt_id, _attempt_id, _authorized_arm_id, _termination_nonce)


## Only the diagnostic observation cutoff changes; the controller still owns
## its original 60-step timeout. This never continues a consumed attempt.
static func declared_after_interaction_steps_v1(declaration: Dictionary) -> int:
	var after := SMOKE_AFTER_INTERACTION_STEPS
	if declaration.has("diagnostic_schedule_id"):
		if (
			not declaration["diagnostic_schedule_id"] is String
			or declaration["diagnostic_schedule_id"] != PRONE_DEADLINE_SCHEDULE
		):
			return 0
		after = Orchestrator.MAXIMUM_CONFIRM_PRONE_STEPS
	var expected := {
		"maximum_precondition_steps": SMOKE_MAX_PRECONDITION_STEPS,
		"walking_prefix_steps": SMOKE_PREFIX_STEPS,
		"interaction_steps": 1,
		"after_interaction_steps": after,
		"maximum_steps_per_child": SMOKE_MAX_STEPS - SMOKE_AFTER_INTERACTION_STEPS + after,
	}
	for key in expected:
		var value: Variant = declaration.get(key)
		if not (value is int or value is float) or value != expected[key]:
			return 0
	return after


func _configure_smoke_schedule_v1(declaration: Dictionary) -> bool:
	var after := declared_after_interaction_steps_v1(declaration)
	if after == 0:
		return false
	_declared_after_interaction_steps = after
	return true


func _smoke_after_interaction_steps_v1() -> int:
	return _declared_after_interaction_steps


static func declaration_allows_cache_v1(
	raw: String,
	digest: String,
	source: String,
	parent: String,
	child: String,
	role: String,
	nonce: String
) -> bool:
	return _declaration_allows_cache_profile_v1(raw, digest, source, parent, child, role, nonce,
		WORKER_RESOURCE, "sporespore_sdk1_development_recovery_smoke_declaration_v1")


static func _declaration_allows_cache_profile_v1(raw: String, digest: String, source: String,
	parent: String, child: String, role: String, nonce: String, worker_resource: String,
	declaration_schema: String) -> bool:
	if "sha256:" + raw.sha256_text() != digest:
		return false
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return false
	var declaration: Dictionary = parsed
	if (
		(
			declaration.get("schema_version")
			!= declaration_schema
		)
		or declaration.get("context_cache_profile_id") != CACHE_PROFILE_ID
		or declaration.get("context_cache_call_sites") != CACHE_CALL_SITES
		or declaration.get("worker_resource") != worker_resource
		or declaration.get("step_cost_profile_id") != PROFILE_ID
		or declaration.get("attempt_id") != parent
		or not declaration.get("source_snapshot") is Dictionary
		or declaration["source_snapshot"].get("head") != source
		or declaration.get("official_qualification") != false
		or declaration.get("physical_acceptance_authority") != false
		or declaration.get("release_authority") != false
		or not declaration.get("children") is Array
	):
		return false
	var matches := 0
	for descriptor in declaration["children"]:
		if descriptor is Dictionary and descriptor.get("child_attempt_id") == child:
			if descriptor.get("role") != role or descriptor.get("termination_nonce") != nonce:
				return false
			matches += 1
	return matches == 1


func _development_context_cache_v1() -> RefCounted:
	return _context_cache


func _development_context_cache_profile_v1() -> Dictionary:
	return {
		"profile_id": CACHE_PROFILE_ID,
		"call_sites":
		{
			"epoch_preflight": _context_cache.calls[0],
			"global_context_validation": _context_cache.calls[1]
		},
		"hits": _context_cache.hits,
		"full_checks": _context_cache.full_checks,
		"bypasses": _context_cache.bypasses,
		"retained_entries": _context_cache.entry_count_v1(),
		"maximum_entries": 2,
		"observations_cached": false,
		"controller_outputs_cached": false,
		"physical_baselines_cached": false,
		"qualification_cached": false,
		"dynamic_preflight_checks_skipped": false,
	}
