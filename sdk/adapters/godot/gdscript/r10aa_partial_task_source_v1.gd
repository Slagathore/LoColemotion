extends RefCounted
# gdlint: disable=max-line-length

## Select the identity of a NEW native measurement before any source hashing.
## The worker installs the same binding on its model and pending application.
## This module never relabels an observation, constructs a world or steps it.
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const OriginalPartial := preload("res://sdk/adapters/godot/gdscript/r10k_partial_task_source_v1.gd")
const KEY := "r10aa_partial_task_source"
const SCHEMA := "sporespore_r10aa_partial_task_source_v1"
const TASK := "sporespore_measured_partial_fall_to_standing_v1"
const SEMANTICS := "sporespore_measured_partial_fall_recovery_semantics_v1"
const CANONICAL_TASK := "sporespore_canonical_ventral_prone_to_four_foot_stance_v1"
const CANONICAL_SEMANTICS := "sporespore_qsdk_r24d2_portable_recovery_semantics_v1"
const RECOVERY := "sporespore_exact_s169_partial_load_seeking_controller_v23"
const COMPOSITION := "sporespore_r10aa_partial_load_seeking_v23_v7_composition_v1"
const KERNEL_PROFILE_SHA := "sha256:ed36dabb8e4a65e68baaa78265f03a1edd40bb849db0888a1d4f2c31f95b1ce1"
const COMPETING_KEYS := ["r10k_partial_task_source", "r10q_upright_task_source", "r10r_upright_task_source", "r10y_partial_task_source", "r10z_partial_task_source"]
const STANCE := "sporespore_exact_s169_stance_handoff_controller_v7"
const PHASES := ["establish_distal_support", "raise_body", "stance_handoff", "stance_dwell"]
const FIELDS := ["schema_version", "task_id", "semantics_id", "declaration_sha256",
	"memory_sha256", "native_control_receipt_sha256", "control", "control_sha256",
	"semantic_step", "phase", "application_sha256", "binding_sha256"]

static func control_context_v1(sdk: Object, native_receipt: Dictionary) -> Dictionary:
	if sdk == null: return _failure("RUNTIME_MISSING")
	if native_receipt.get("control_composition_id") != COMPOSITION: return _failure("COMPOSITION_CROSSED")
	var memory: Dictionary
	var control: Dictionary
	var geometry: Variant
	if native_receipt.get("schema_version") == "sporespore_r10aa_partial_load_seeking_entry_control_receipt_v1":
		var retained: Dictionary = native_receipt.get("original_entry_control", {})
		if (retained.get("schema_version") != "sporespore_r10q_upright_entry_control_receipt_v1"
			or retained.get("entry", {}).get("memory", {}).get("route") != "partial"
			or retained.get("entry", {}).get("original_entry") != retained.get("original_control", {}).get("entry")
			or native_receipt.get("partial_supervisor_synthesized") != false
			or OriginalPartial.control_context_v1(sdk, retained.get("original_control", {})).get("ok") != true):
			return _failure("ORIGINAL_ENTRY_CROSSED")
		if native_receipt.get("original_entry_control", {}).get("original_control", {}).get("entry", {}).get("memory", {}).get("route") != "partial":
			return _failure("ENTRY_NOT_PARTIAL")
		if not (native_receipt.get("original_entry_control", {}).get("original_control", {}).get("entry", {}).get("partial_memory") is Dictionary) or not (native_receipt.get("initial_partial_control") is Dictionary):
			return _failure("ENTRY_CONTROL_MISSING")
		memory = native_receipt.original_entry_control.original_control.entry.partial_memory
		control = native_receipt.initial_partial_control
		geometry = native_receipt.get("initial_load_plan")
	elif native_receipt.get("schema_version") == "sporespore_r10aa_partial_load_seeking_step_control_receipt_v1":
		if not (native_receipt.get("step", {}).get("memory") is Dictionary) or not (native_receipt.get("next_control") is Dictionary):
			return _failure("STEP_CONTROL_MISSING")
		memory = native_receipt.step.memory
		control = native_receipt.next_control
		geometry = native_receipt.get("next_load_plan")
	else:
		return _failure("NATIVE_RECEIPT_SCHEMA")
	if (memory.get("schema_version") != "sporespore_partial_fall_memory_v1"
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
	if not _load_plan_valid(control, geometry): return _failure("GEOMETRY_CONTEXT_CROSSED")
	return {"ok": true, "declaration_sha256": memory.declaration_sha256,
		"memory_sha256": _sha(sdk, memory), "native_control_receipt_sha256": _sha(sdk, native_receipt),
		"control": control.duplicate(true), "control_sha256": _sha(sdk, control),
		"semantic_step": int(control.semantic_step) + 1, "phase": control.phase}

static func bind_application_v1(sdk: Object, native_receipt: Dictionary, application: Dictionary) -> Dictionary:
	var context := control_context_v1(sdk, native_receipt)
	if context.get("ok") != true: return context
	if _has_competing_tag(application) or application.has(KEY) or not _application_matches(application, context.control, context.semantic_step):
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
	if _has_competing_tag(model) or _has_competing_tag(application): return _failure("COMPETING_TASKS")
	if not model.has(KEY) and not application.has(KEY):
		return _failure("PARTIAL_BINDING_MISSING")
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
	return {"ok": true, "task_id": TASK, "semantics_id": SEMANTICS, "partial_task_selected": true,
		"binding_sha256": binding.binding_sha256, "source_observation_rewritten": false}

## Geometry is a planning receipt, never a replacement native measurement.
## Full report replay independently reproduces its entire native call value.
static func _load_plan_valid(control: Dictionary, geometry: Variant) -> bool:
	if control.get("phase") in ["stance_handoff", "stance_dwell"]:
		return geometry == null
	if not (geometry is Dictionary): return false
	if geometry.get("phase") != control.get("phase"): return false
	if not (geometry.get("qualified_support") is Array) or geometry.qualified_support.size() != 4: return false
	if not (geometry.get("load_deficit_fraction") is Array) or geometry.load_deficit_fraction.size() != 4: return false
	for index in range(4):
		if typeof(geometry.qualified_support[index]) != TYPE_BOOL: return false
		var deficit: Variant = geometry.load_deficit_fraction[index]
		if typeof(deficit) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(deficit)) or float(deficit) < 0.0 or float(deficit) > 1.0: return false
		if geometry.qualified_support[index] != (float(deficit) == 0.0): return false
	var loaded: bool = geometry.qualified_support.all(func(value): return value == true)
	var expected := "loaded_geometry_rise" if loaded and control.phase == "raise_body" else ("hold_qualified_support" if loaded else "seek_distal_load")
	if geometry.get("mode") != expected: return false
	if not (geometry.get("virtual_translation_world_m") is Array) or geometry.virtual_translation_world_m.size() != 3: return false
	for coordinate in geometry.virtual_translation_world_m:
		if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)): return false
	if expected == "loaded_geometry_rise":
		if not (geometry.get("rise_geometry") is Dictionary): return false
		if geometry.rise_geometry.get("schema_version") != "sporespore_r10z_partial_pose_geometry_plan_v1": return false
		if geometry.rise_geometry.get("source_observation_sha256") != control.get("observation_sha256"): return false
	else:
		if geometry.get("rise_geometry") != null or float(geometry.virtual_translation_world_m[1]) > 0.0: return false
	return (geometry.get("schema_version") == "sporespore_r10aa_load_seeking_plan_v1"
		and geometry.get("source_observation_sha256") == control.get("observation_sha256")
		and geometry.get("ordered_target_positions_rad") is Array
		and geometry.ordered_target_positions_rad.size() == 8
		and geometry.get("native_source_validation_performed") == false
		and geometry.get("physical_acceptance_authority") == false
		and geometry.get("release_authority") == false
		and geometry.get("world_build_count") == 0 and geometry.get("solver_step_count") == 0)

static func _control_valid(sdk: Object, control: Dictionary) -> bool:
	var stance: bool = control.get("phase") in ["stance_handoff", "stance_dwell"]
	return (control.get("schema_version") == "sporespore_recovery_control_receipt_v1"
		and control.get("support_status") == "supported_exact" and control.get("refusal_reason") == null
		and control.get("phase") in PHASES and typeof(control.get("semantic_step")) == TYPE_INT
		and control.semantic_step >= 0 and control.semantic_step < 9007199254740991
		and control.get("controller_id") == (STANCE if stance else RECOVERY)
		and (stance or control.get("controller_profile_sha256") == KERNEL_PROFILE_SHA)
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
		and application.get("recovery_controller_id") == (null if stance else RECOVERY)
		and application.get("stance_controller_id") == (STANCE if stance else null)
		and application.get("fallback_controller_active") == false and application.get("zero_command") == false
		and application.get("physical_acceptance_authority") == false and application.get("release_authority") == false)

static func _has_competing_tag(value: Dictionary) -> bool:
	for key in COMPETING_KEYS:
		if value.has(key): return true
	return false

static func _sha(sdk: Object, value: Variant) -> String:
	return Runtime.canonicalize(sdk, value).get("sha256", "")

static func _digest(value: Variant) -> bool:
	if not (value is String) or value.length() != 71 or not value.begins_with("sha256:"): return false
	for letter in value.substr(7):
		if letter not in "0123456789abcdef": return false
	return true

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "failure_code": "R10AA_PARTIAL_TASK_SOURCE_" + reason}
