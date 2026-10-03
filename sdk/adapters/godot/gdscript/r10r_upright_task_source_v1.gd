extends RefCounted
# gdlint: disable=max-line-length

## Select the identity of a NEW native measurement before any source hashing.
## The worker installs the same binding on its model and pending application.
## This module never relabels an observation, constructs a world or steps it.
const Partial := preload("res://sdk/adapters/godot/gdscript/r10k_partial_task_source_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const KEY := "r10r_upright_task_source"
const SCHEMA := "sporespore_r10r_upright_task_source_v1"
const TASK := "sporespore_measured_upright_recovery_to_standing_v1"
const SEMANTICS := "sporespore_measured_upright_recovery_semantics_v1"
const CANONICAL_TASK := "sporespore_canonical_ventral_prone_to_four_foot_stance_v1"
const CANONICAL_SEMANTICS := "sporespore_qsdk_r24d2_portable_recovery_semantics_v1"
const RECOVERY := "sporespore_exact_s169_prone_to_standing_controller_v20"
const OriginalUpright := preload("res://sdk/adapters/godot/gdscript/r10q_upright_task_source_v1.gd")
const RAISE := "sporespore_exact_s169_prone_to_standing_controller_v12"
const COMPOSITION := "sporespore_r10r_upright_v20_v12_v7_control_composition_v1"
const STANCE := "sporespore_exact_s169_stance_handoff_controller_v7"
const PHASES := ["establish_distal_support", "raise_body", "stance_handoff", "stance_dwell"]
const FIELDS := ["schema_version", "task_id", "semantics_id", "declaration_sha256",
	"memory_sha256", "native_control_receipt_sha256", "control", "control_sha256",
	"semantic_step", "phase", "application_sha256", "binding_sha256"]

static func control_context_v1(sdk: Object, native_receipt: Dictionary) -> Dictionary:
	if sdk == null: return _failure("RUNTIME_MISSING")
	var memory: Dictionary
	var control: Dictionary
	if native_receipt.get("schema_version") == "sporespore_r10q_upright_entry_control_receipt_v1":
		if native_receipt.get("entry", {}).get("memory", {}).get("route") != "upright":
			return _failure("ENTRY_NOT_UPRIGHT")
		if not (native_receipt.get("entry", {}).get("upright_memory") is Dictionary) or not (native_receipt.get("initial_upright_control") is Dictionary):
			return _failure("ENTRY_CONTROL_MISSING")
		memory = native_receipt.entry.upright_memory
		control = native_receipt.initial_upright_control
	elif native_receipt.get("schema_version") == "sporespore_r10r_upright_direct_rise_step_control_receipt_v1":
		if native_receipt.get("control_composition_id") != COMPOSITION: return _failure("COMPOSITION_CROSSED")
		if not (native_receipt.get("step", {}).get("memory") is Dictionary) or not (native_receipt.get("next_control") is Dictionary):
			return _failure("STEP_CONTROL_MISSING")
		memory = native_receipt.step.memory
		control = native_receipt.next_control
	else:
		return _failure("NATIVE_RECEIPT_SCHEMA")
	if (memory.get("schema_version") != "sporespore_upright_recovery_memory_v1"
		or memory.get("phase") not in PHASES or memory.get("phase") != control.get("phase")
		or memory.get("last_semantic_step") != control.get("semantic_step")
		or memory.get("last_observation_sha256") != control.get("observation_sha256")
		or memory.get("phase_steps_observed") != control.get("phase_step")
		or memory.get("terminal_failure_code") != null or not _digest(memory.get("declaration_sha256"))):
		return _failure("MEMORY_CONTROL_CROSSED")
	for flag in ["original_observation_rewritten", "canonical_supervisor_synthesized", "physical_acceptance_authority", "release_authority"]:
		if native_receipt.get(flag) != false: return _failure("NATIVE_AUTHORITY")
	if native_receipt.get("world_build_count") != 0 or native_receipt.get("solver_step_count") != 0:
		return _failure("NATIVE_WORLD_COUNT")
	if not _control_valid(sdk, control): return _failure("CONTROL_INVALID")
	return {"ok": true, "declaration_sha256": memory.declaration_sha256,
		"memory_sha256": _sha(sdk, memory), "native_control_receipt_sha256": _sha(sdk, native_receipt),
		"control": control.duplicate(true), "control_sha256": _sha(sdk, control),
		"semantic_step": int(control.semantic_step) + 1, "phase": control.phase}

static func bind_application_v1(sdk: Object, native_receipt: Dictionary, application: Dictionary) -> Dictionary:
	var context := control_context_v1(sdk, native_receipt)
	if context.get("ok") != true: return context
	if application.has(KEY) or application.has(Partial.KEY) or application.has(OriginalUpright.KEY) or not _application_matches(application, context.control, context.semantic_step):
		return _failure("APPLICATION_CROSSED")
	var binding := context.duplicate(true)
	binding.erase("ok")
	binding.merge({"schema_version": SCHEMA, "task_id": TASK, "semantics_id": SEMANTICS,
		"application_sha256": _sha(sdk, application)})
	binding["binding_sha256"] = _sha(sdk, binding)
	var tagged := application.duplicate(true)
	tagged[KEY] = binding.duplicate(true)
	return {"ok": true, "application": tagged, "model_binding": binding,
		"world_build_count": 0, "solver_step_count": 0, "source_observation_rewritten": false}

static func select_v1(sdk: Object, model: Dictionary, application: Dictionary, semantic_step: int) -> Dictionary:
	if model.has(Partial.KEY) or application.has(Partial.KEY) or model.has(OriginalUpright.KEY) or application.has(OriginalUpright.KEY): return _failure("COMPETING_TASK_BINDING")
	if not model.has(KEY) and not application.has(KEY):
		return _failure("UPRIGHT_BINDING_MISSING")
	if sdk == null: return _failure("RUNTIME_MISSING")
	if not (model.get(KEY) is Dictionary) or not (application.get(KEY) is Dictionary):
		return _failure("MODEL_APPLICATION_BINDING_MISSING")
	var binding: Dictionary = application[KEY]
	if binding.keys().size() != FIELDS.size(): return _failure("BINDING_SHAPE")
	for key in FIELDS:
		if not binding.has(key): return _failure("BINDING_FIELD:" + key)
	if _sha(sdk, binding) != _sha(sdk, model[KEY]): return _failure("MODEL_APPLICATION_CROSSED")
	var payload := binding.duplicate(true)
	payload.erase("binding_sha256")
	if (binding.schema_version != SCHEMA or binding.task_id != TASK or binding.semantics_id != SEMANTICS
		or typeof(binding.semantic_step) != TYPE_INT or binding.semantic_step != semantic_step
		or binding.phase not in PHASES or not (binding.control is Dictionary)
		or binding.binding_sha256 != _sha(sdk, payload)):
		return _failure("BINDING_IDENTITY")
	for key in ["declaration_sha256", "memory_sha256", "native_control_receipt_sha256", "control_sha256", "application_sha256", "binding_sha256"]:
		if not _digest(binding[key]): return _failure("BINDING_DIGEST")
	if not _control_valid(sdk, binding.control) or binding.control_sha256 != _sha(sdk, binding.control):
		return _failure("BOUND_CONTROL_INVALID")
	var original := application.duplicate(true)
	original.erase(KEY)
	if (binding.application_sha256 != _sha(sdk, original) or binding.phase != application.get("phase")
		or not _application_matches(original, binding.control, semantic_step)):
		return _failure("BOUND_APPLICATION_CROSSED")
	return {"ok": true, "task_id": TASK, "semantics_id": SEMANTICS, "upright_task_selected": true,
		"binding_sha256": binding.binding_sha256, "source_observation_rewritten": false}

static func _control_valid(sdk: Object, control: Dictionary) -> bool:
	var stance: bool = control.get("phase") in ["stance_handoff", "stance_dwell"]
	return (control.get("schema_version") == "sporespore_recovery_control_receipt_v1"
		and control.get("support_status") == "supported_exact" and control.get("refusal_reason") == null
		and control.get("phase") in PHASES and typeof(control.get("semantic_step")) == TYPE_INT
		and control.semantic_step >= 0 and control.semantic_step < 9007199254740991
		and control.get("controller_id") == (STANCE if stance else recovery_controller_for_phase_v1(control.phase))
		and control.get("owner") == ("stance" if stance else "recovery")
		and control.get("recovery_controller_active") == (not stance)
		and control.get("fallback_controller_active") == false and control.get("no_actuation_requested") == false
		and control.get("matched_zero_command") == false and control.get("prone_to_standing_claimed") == false
		and control.get("physical_acceptance_authority") == false and control.get("release_authority") == false
		and control.get("world_build_count") == 0 and control.get("solver_step_count") == 0
		and control.get("ordered_commands") is Array and control.ordered_commands.size() == 8
		and control.get("command_sha256") == _sha(sdk, control.ordered_commands))

static func _application_matches(application: Dictionary, control: Dictionary, semantic_step: int) -> bool:
	var stance: bool = control.get("phase") in ["stance_handoff", "stance_dwell"]
	return (application.get("ok") == true and application.get("semantic_step") == semantic_step
		and application.get("phase") == control.phase and application.get("command_sha256") == control.command_sha256
		and application.get("controller_owner") == ("stance" if stance else "recovery")
		and application.get("recovery_controller_id") == (null if stance else recovery_controller_for_phase_v1(control.phase))
		and application.get("stance_controller_id") == (STANCE if stance else null)
		and application.get("fallback_controller_active") == false and application.get("zero_command") == false
		and application.get("physical_acceptance_authority") == false and application.get("release_authority") == false)

static func _sha(sdk: Object, value: Variant) -> String:
	return Runtime.canonicalize(sdk, value).get("sha256", "")

static func _digest(value: Variant) -> bool:
	if not (value is String) or value.length() != 71 or not value.begins_with("sha256:"): return false
	for letter in value.substr(7):
		if letter not in "0123456789abcdef": return false
	return true

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "failure_code": "R10R_UPRIGHT_TASK_SOURCE_" + reason}

static func recovery_controller_for_phase_v1(phase: String) -> String:
	return RAISE if phase == "raise_body" else RECOVERY
