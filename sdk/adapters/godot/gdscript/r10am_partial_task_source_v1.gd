extends RefCounted
# gdlint: disable=max-line-length

## Select the identity of a NEW native measurement before any source hashing.
## The worker installs the same binding on its model and pending application.
## This module never relabels an observation, constructs a world or steps it.
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Baseline := preload("res://sdk/adapters/godot/gdscript/r10ai_partial_task_source_v1.gd")
const OriginalPartial := preload("res://sdk/adapters/godot/gdscript/r10k_partial_task_source_v1.gd")
const KEY := "r10am_partial_task_source"
const SCHEMA := "sporespore_r10am_partial_task_source_v1"
const TASK := "sporespore_measured_partial_fall_to_standing_v1"
const SEMANTICS := "sporespore_measured_partial_fall_recovery_semantics_v1"
const CANONICAL_TASK := "sporespore_canonical_ventral_prone_to_four_foot_stance_v1"
const CANONICAL_SEMANTICS := "sporespore_qsdk_r24d2_portable_recovery_semantics_v1"
const RECOVERY := "sporespore_exact_s169_partial_support_anchored_controller_v27"
const COMPOSITION := "sporespore_r10am_partial_support_anchored_v27_v7_composition_v1"
const KERNEL_PROFILE_SHA := "sha256:cd749bfb15ec548f8ee8b62df50fb265aee1142b39a6ccd276f9f7c6801f9092"
const COMPETING_KEYS := ["r10k_partial_task_source", "r10q_upright_task_source", "r10r_upright_task_source", "r10y_partial_task_source", "r10z_partial_task_source", "r10aa_partial_task_source", "r10ab_partial_task_source", "r10ai_partial_task_source", "r10aj_partial_task_source"]
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
	if native_receipt.get("schema_version") == "sporespore_r10am_partial_support_anchored_entry_control_receipt_v1":
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
	elif native_receipt.get("schema_version") == "sporespore_r10am_partial_support_anchored_step_control_receipt_v1":
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
	if geometry is Dictionary:
		# Native commands intentionally retain 13 significant decimal digits;
		# raw kernel targets retain binary64 precision (canonical hashes use 14).
		# At the existing 1.6-rad maximum, rounding contributes <=5e-13 rad.
		# The additional 1e-15 covers binary64 parse error. This only checks
		# transport agreement; full native replay still requires exact receipts.
		for index in range(8):
			var planned := float(geometry.ordered_target_positions_rad[index])
			var applied: Variant = control.ordered_commands[index].get("target_position_rad")
			if (typeof(applied) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(applied))
				or absf(planned) > (1.6 if index % 2 == 0 else 1.1)
				or absf(planned - float(applied)) > 5.01e-13):
				return _failure("GEOMETRY_COMMAND_CROSSED")
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
	if control.get("phase") in ["stance_handoff", "stance_dwell"]: return geometry == null
	if not (geometry is Dictionary): return false
	if geometry.get("schema_version") != "sporespore_r10am_support_anchored_plan_v1": return false
	if geometry.get("phase") != control.get("phase") or not _plan_source_valid(control, geometry): return false
	var baseline: Variant = geometry.get("baseline_reference")
	if not (baseline is Dictionary) or not Baseline._load_plan_valid(control, baseline): return false
	if not _finite_vector(geometry.get("ordered_target_positions_rad"), 8): return false
	var anchored: Variant = geometry.get("support_anchored_geometry")
	if control.phase == "establish_distal_support":
		return (geometry.get("mode") == "unchanged_support_reference" and anchored == null
			and geometry.ordered_target_positions_rad == baseline.ordered_target_positions_rad)
	if control.phase != "raise_body" or not (anchored is Dictionary): return false
	if (anchored.get("schema_version") != "sporespore_r10am_support_anchored_geometry_v1"
		or not _finite_vector(anchored.get("ordered_target_positions_rad"), 8)
		or not _finite_vector(anchored.get("virtual_translation_world_m"), 3)
		or not (anchored.get("positive_bearing") is Array) or anchored.positive_bearing.size() != 4): return false
	for bearing in anchored.positive_bearing:
		if typeof(bearing) != TYPE_BOOL: return false
	for key in ["candidate_count", "feasible_candidate_count"]:
		if typeof(anchored.get(key)) != TYPE_INT or anchored[key] < 0 or anchored[key] > 90: return false
	if anchored.feasible_candidate_count > anchored.candidate_count: return false
	for key in ["virtual_level_blend", "maximum_anchor_error_m"]:
		if not _finite_number(anchored.get(key)) or anchored[key] < 0.0: return false
	if anchored.maximum_anchor_error_m > 0.0005 + 1e-12: return false
	for key in ["initial_cost", "selected_cost"]:
		if anchored.get(key) != null and (not _finite_number(anchored[key]) or anchored[key] < 0.0): return false
	if geometry.get("mode") == "support_anchored_leveling":
		if (anchored.get("selected_scale") not in [1.0, 0.5, 0.25, 0.125, 0.0625]
			or anchored.get("hold_reason") != null or not anchored.positive_bearing.has(true)
			or anchored.candidate_count != 90 or anchored.feasible_candidate_count == 0
			or anchored.initial_cost == null or anchored.selected_cost == null
			or anchored.selected_cost >= anchored.initial_cost
			or geometry.ordered_target_positions_rad != anchored.ordered_target_positions_rad): return false
		var distance: float = 0.1 / 120.0 * anchored.selected_scale
		var delta: Array = anchored.virtual_translation_world_m
		return (sqrt(float(delta[0]) * float(delta[0]) + float(delta[2]) * float(delta[2])) <= distance + 1e-12
			and absf(float(delta[1])) <= distance + 1e-12
			and anchored.virtual_level_blend in [0.0, 0.6 / 120.0 * anchored.selected_scale])
	if geometry.get("mode") != "explicit_v23_fallback": return false
	if (anchored.get("selected_scale") != null
		or anchored.virtual_translation_world_m != [0.0, 0.0, 0.0]
		or anchored.virtual_level_blend != 0.0 or anchored.maximum_anchor_error_m != 0.0
		or geometry.ordered_target_positions_rad != baseline.baseline_reference.ordered_target_positions_rad): return false
	match anchored.get("hold_reason"):
		"no_positive_bearing_plane":
			return (not anchored.positive_bearing.has(true) and anchored.candidate_count == 0
				and anchored.feasible_candidate_count == 0 and anchored.initial_cost == null and anchored.selected_cost == null)
		"undefined_horizontal_heading":
			return (anchored.positive_bearing.has(true) and anchored.candidate_count == 0
				and anchored.feasible_candidate_count == 0 and anchored.initial_cost == null and anchored.selected_cost == null)
		"no_feasible_candidate", "no_cost_decreasing_candidate":
			return (anchored.positive_bearing.has(true) and anchored.candidate_count == 90
				and anchored.initial_cost != null and anchored.initial_cost == anchored.selected_cost
				and (anchored.feasible_candidate_count == 0 if anchored.hold_reason == "no_feasible_candidate" else anchored.feasible_candidate_count > 0))
	return false

static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

static func _plan_source_valid(control: Dictionary, plan: Dictionary) -> bool:
	return (plan.get("source_observation_sha256") == control.get("observation_sha256")
		and plan.get("native_source_validation_performed") == false
		and plan.get("physical_acceptance_authority") == false and plan.get("release_authority") == false
		and plan.get("world_build_count") == 0 and plan.get("solver_step_count") == 0)

static func _finite_vector(value: Variant, count: int) -> bool:
	if not (value is Array) or value.size() != count: return false
	for number in value:
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)): return false
	return true

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
	return {"ok": false, "failure_code": "R10AM_PARTIAL_TASK_SOURCE_" + reason}
