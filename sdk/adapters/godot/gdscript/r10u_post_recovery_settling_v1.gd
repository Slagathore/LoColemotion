extends RefCounted
## Pure scheduling component. The worker/reader must independently validate the
## native terminal receipt, source packet, motor application and session lifecycle.
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Readiness := preload("res://sdk/adapters/godot/gdscript/recovery_walking_readiness_v1.gd")
const DESIGN_PATH := "res://sdk/recovery/r10u_audit_handoff_design_v1.json"
const DESIGN_SHA := "sha256:81f18c3e99929ee02c830f973c32c3db4fdb5917a5efa2863d59e5ee2a7fa981"
const CONTEXT := "sporespore_r10u_completed_recovery_handoff_context_v1"
const MEMORY := "sporespore_r10u_post_recovery_settling_memory_v1"
const MAXIMUM_COMMANDS := 240
const READY_SAMPLES := 30
const CHECKS := ["angular_settled", "four_native_supports", "horizontal_com_settled", "upright", "zero_bias_reference_path_feasible"]
const CONTEXT_KEYS := ["schema_version", "attempt_id", "arm_id", "model_instance_id", "body_population_instance_sha256",
	"energy_initializer_sha256", "recovery_memory_sha256", "recovery_receipt_sha256", "entry_kind", "recovery_phase",
	"global_semantic_step", "prior_walking_session_ids"]
const MEMORY_KEYS := ["schema_version", "design_sha256", "context", "entry_source_step", "last_source_step",
	"commands", "consecutive_ready", "outcome", "hold_session_id", "initial_readiness_sha256", "latest_readiness_sha256", "payload_sha256"]

static func _keys(value: Dictionary, keys: Array) -> bool:
	return value.size() == keys.size() and keys.all(func(key): return value.has(key))

static func _digest(value: Variant) -> bool:
	if not (value is String) or value.length() != 71 or not value.begins_with("sha256:"): return false
	for c in value.substr(7):
		if c not in "0123456789abcdef": return false
	return true

static func _sha(sdk: Object, value: Variant) -> String:
	return Runtime.canonicalize(sdk, value).get("sha256", "") if sdk != null else ""

static func _payload(sdk: Object, memory: Dictionary) -> String:
	var value := memory.duplicate(true)
	value.erase("payload_sha256")
	return _sha(sdk, value)

static func context_valid_v1(context: Dictionary) -> bool:
	if not _keys(context, CONTEXT_KEYS) or context.schema_version != CONTEXT: return false
	for key in ["attempt_id", "arm_id", "model_instance_id"]:
		if not (context[key] is String) or context[key].is_empty(): return false
	if (context.arm_id != "kick_passive_recovery_resume" or context.entry_kind not in ["upright", "partial", "prone"]
		or context.recovery_phase != "complete" or typeof(context.global_semantic_step) != TYPE_INT or context.global_semantic_step < 1): return false
	for key in ["body_population_instance_sha256", "energy_initializer_sha256", "recovery_memory_sha256", "recovery_receipt_sha256"]:
		if not _digest(context[key]): return false
	if not (context.prior_walking_session_ids is Array): return false
	var seen := {}
	for session in context.prior_walking_session_ids:
		if not (session is String) or session.is_empty() or seen.has(session): return false
		seen[session] = true
	return not seen.is_empty()

static func readiness_valid_v1(sample: Dictionary) -> bool:
	if (sample.get("schema_version") != "sporespore_recovery_walking_readiness_v1"
		or typeof(sample.get("source_semantic_step")) != TYPE_INT or sample.source_semantic_step < 1
		or typeof(sample.get("ready")) != TYPE_BOOL or not (sample.get("checks") is Dictionary)
		or not _keys(sample.checks, CHECKS)): return false
	for key in CHECKS:
		if typeof(sample.checks[key]) != TYPE_BOOL: return false
	for key in ["horizontal_com_speed_m_s", "angular_speed_rad_s", "torso_tilt_rad"]:
		if typeof(sample.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(sample[key]) or sample[key] < 0.0: return false
	return (sample.ready == (not sample.checks.values().has(false))
		and sample.checks.horizontal_com_settled == (sample.horizontal_com_speed_m_s <= 0.03)
		and sample.checks.angular_settled == (sample.angular_speed_rad_s <= 0.15)
		and sample.checks.upright == (sample.torso_tilt_rad <= 0.05))

static func initialize_v1(sdk: Object, context: Dictionary, sample: Dictionary) -> Dictionary:
	if "sha256:" + FileAccess.get_sha256(DESIGN_PATH) != DESIGN_SHA: return _failure("DESIGN")
	if not context_valid_v1(context) or not readiness_valid_v1(sample): return _failure("INITIAL_INPUT")
	if sample.source_semantic_step != context.global_semantic_step: return _failure("INITIAL_SOURCE_STEP")
	var outcome := "entry_refused"
	if sample.ready: outcome = "direct"
	elif (context.entry_kind == "upright" and not sample.checks.horizontal_com_settled
		and sample.checks.angular_settled and sample.checks.four_native_supports
		and sample.checks.upright and sample.checks.zero_bias_reference_path_feasible): outcome = "pending"
	var memory := {"schema_version": MEMORY, "design_sha256": DESIGN_SHA, "context": context.duplicate(true),
		"entry_source_step": context.global_semantic_step, "last_source_step": context.global_semantic_step,
		"commands": 0, "consecutive_ready": 0, "outcome": outcome, "hold_session_id": "",
		"initial_readiness_sha256": _sha(sdk, sample), "latest_readiness_sha256": _sha(sdk, sample)}
	memory.payload_sha256 = _payload(sdk, memory)
	if not memory_valid_v1(sdk, memory): return _failure("INITIAL_MEMORY")
	return _receipt(memory)

static func memory_valid_v1(sdk: Object, memory: Dictionary) -> bool:
	if (not _keys(memory, MEMORY_KEYS) or memory.schema_version != MEMORY or memory.design_sha256 != DESIGN_SHA
		or not (memory.context is Dictionary) or not context_valid_v1(memory.context)
		or not (memory.hold_session_id is String) or not _digest(memory.payload_sha256)
		or memory.payload_sha256 != _payload(sdk, memory)): return false
	for key in ["entry_source_step", "last_source_step", "commands", "consecutive_ready"]:
		if typeof(memory[key]) != TYPE_INT: return false
	for key in ["initial_readiness_sha256", "latest_readiness_sha256"]:
		if not _digest(memory[key]): return false
	if (memory.entry_source_step != memory.context.global_semantic_step or memory.commands < 0 or memory.commands > MAXIMUM_COMMANDS
		or memory.last_source_step != memory.entry_source_step + memory.commands
		or memory.consecutive_ready < 0 or memory.consecutive_ready > mini(memory.commands, READY_SAMPLES)
		or memory.outcome not in ["direct", "pending", "ready", "timeout", "entry_refused"]): return false
	if memory.commands == 0:
		return (memory.outcome in ["direct", "pending", "entry_refused"] and memory.consecutive_ready == 0
			and memory.hold_session_id.is_empty() and memory.initial_readiness_sha256 == memory.latest_readiness_sha256
			and (memory.outcome != "pending" or memory.context.entry_kind == "upright"))
	if (memory.context.entry_kind != "upright" or memory.hold_session_id.is_empty()
		or memory.hold_session_id in memory.context.prior_walking_session_ids): return false
	if memory.outcome == "pending": return memory.commands < MAXIMUM_COMMANDS and memory.consecutive_ready < READY_SAMPLES
	if memory.outcome == "ready": return memory.consecutive_ready == READY_SAMPLES
	return memory.outcome == "timeout" and memory.commands == MAXIMUM_COMMANDS and memory.consecutive_ready < READY_SAMPLES

static func advance_v1(sdk: Object, memory: Dictionary, sample: Dictionary, session_id: String,
	recovery_memory_sha256: String, energy_initializer_sha256: String) -> Dictionary:
	if not memory_valid_v1(sdk, memory) or memory.outcome != "pending": return _failure("MEMORY_OR_TERMINAL")
	if not readiness_valid_v1(sample): return _failure("READINESS")
	if (recovery_memory_sha256 != memory.context.recovery_memory_sha256
		or energy_initializer_sha256 != memory.context.energy_initializer_sha256): return _failure("RECOVERY_OR_EPOCH_CHANGED")
	if (session_id.is_empty() or session_id in memory.context.prior_walking_session_ids
		or not memory.hold_session_id.is_empty() and memory.hold_session_id != session_id): return _failure("SESSION")
	# Reuse the established bounded dwell arithmetic with explicit independent counters.
	var advanced := Readiness.advance_v1({"commands": memory.commands, "consecutive_ready": memory.consecutive_ready,
		"last_source_step": memory.last_source_step, "outcome": "pending"}, sample,
		{"maximum_commands": MAXIMUM_COMMANDS, "ready_consecutive_completed_samples": READY_SAMPLES})
	if not advanced.has("outcome"): return _failure("SEQUENCE_OR_BOUND")
	var next := memory.duplicate(true)
	for key in ["commands", "consecutive_ready", "last_source_step", "outcome"]: next[key] = advanced[key]
	next.hold_session_id = session_id
	next.latest_readiness_sha256 = _sha(sdk, sample)
	next.payload_sha256 = _payload(sdk, next)
	if not memory_valid_v1(sdk, next): return _failure("NEXT_MEMORY")
	return _receipt(next)

static func _receipt(memory: Dictionary) -> Dictionary:
	return {"ok": true, "schema_version": "sporespore_r10u_post_recovery_settling_schedule_receipt_v1", "memory": memory,
		"source_and_application_provenance_validation_owned_by_caller": true,
		"native_session_lifecycle_proven_by_component": false,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}

static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": "R10U_POST_RECOVERY_SETTLING_" + code,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
