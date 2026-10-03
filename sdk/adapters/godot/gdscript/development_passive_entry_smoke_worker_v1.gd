extends "res://sdk/adapters/godot/gdscript/development_cached_recovery_smoke_worker_v1.gd"
# gdlint: disable=max-line-length

const EntryOrchestrator := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_orchestrator_v1.gd")
const EntryStage := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_stage_v1.gd")
const Cached := preload("res://sdk/adapters/godot/gdscript/development_cached_recovery_smoke_worker_v1.gd")
const ENTRY_WORKER := "res://sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd"
const ENTRY_EXTENSION := "res://sdk/adapters/godot/development_passive_entry_runtime/runtime.gdextension"
const ENTRY_RUNTIME_BINDING := "res://sdk/development_passive_entry_runtime_binding_v1.json"
const ENTRY_DECLARATION_SCHEMA := "sporespore_development_measured_prone_smoke_declaration_v1"
const ENTRY_REPORT_SCHEMA := "sporespore_development_measured_prone_smoke_child_v1"
const ENTRY_WORK_ID := "SDK1-GODOT-MEASURED-PRONE-ENTRY-SMOKE-V1"
# Distinct prospective diagnostic resource limits, not canonical thresholds.
# Two seconds of descent and four seconds total post-kick coverage at 120 Hz.
const MAX_DESCENT_STEPS := 240
const AFTER_INTERACTION_STEPS := 480
var _entry_packets: Array = []
var _entry_transitions: Array = []
var _canonical_packets: Array = []
var _first_recovery_application: Dictionary = {}
var _entry_runtime: Dictionary = {}
var _entry_walking_runtime_preflight: Dictionary = {}


func _initialize() -> void:
	super._initialize()
	_raw_schema = _entry_selection_v1()["report_schema"]
	_work_id = _entry_selection_v1()["work_id"]


func _entry_controller_id_v1() -> String:
	return RouteScript.RECOVERY_CONTROLLER_V6_ID


func _entry_selection_v1() -> Dictionary:
	return {"worker": ENTRY_WORKER, "extension": ENTRY_EXTENSION, "binding": ENTRY_RUNTIME_BINDING,
		"declaration_schema": ENTRY_DECLARATION_SCHEMA, "report_schema": ENTRY_REPORT_SCHEMA,
		"work_id": ENTRY_WORK_ID, "schedule": "measured_prone_entry_then_canonical_recovery_v1"}


func _worker_route_tags_v1() -> Dictionary:
	return {"raw_schema": _entry_selection_v1()["report_schema"], "work_ids": [_entry_selection_v1()["work_id"]],
		"raw_marker": SMOKE_RAW_MARKER, "ready_marker": READY_MARKER,
		"implementation_family": "QSDK-R10F-L15"}


func _development_declaration_valid_v1(raw: String) -> bool:
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return false
	var declaration: Dictionary = parsed
	# Godot comparisons across unrelated Variant kinds can raise script errors.
	# Refuse those at this new boundary before the common identity checks.
	var kinds := {"schema_version": TYPE_STRING, "worker_resource": TYPE_STRING,
		"context_cache_profile_id": TYPE_STRING, "context_cache_call_sites": TYPE_ARRAY,
		"step_cost_profile_id": TYPE_STRING, "attempt_id": TYPE_STRING,
		"source_snapshot": TYPE_DICTIONARY, "children": TYPE_ARRAY,
		"official_qualification": TYPE_BOOL, "physical_acceptance_authority": TYPE_BOOL,
		"release_authority": TYPE_BOOL, "passive_entry_runtime": TYPE_DICTIONARY}
	for key in kinds:
		if typeof(declaration.get(key)) != kinds[key]:
			return false
	if typeof(declaration["source_snapshot"].get("head")) != TYPE_STRING:
		return false
	for child in declaration["children"]:
		if not (child is Dictionary):
			return false
		for key in ["child_attempt_id", "role", "termination_nonce"]:
			if typeof(child.get(key)) != TYPE_STRING:
				return false
	if not Cached._declaration_allows_cache_profile_v1(raw, _authorization_sha256, _source_commit,
		_parent_attempt_id, _attempt_id, _authorized_arm_id, _termination_nonce,
		_entry_selection_v1()["worker"], _entry_selection_v1()["declaration_schema"]):
		return false
	if not declaration_schedule_valid_v1(declaration, _entry_selection_v1()["schedule"], _entry_after_interaction_steps_v1()):
		return false
	if not FileAccess.file_exists(_entry_selection_v1()["binding"]):
		return false
	_entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(_entry_selection_v1()["binding"]))
	return declaration.get("passive_entry_runtime") == _entry_runtime.get("runtime")


static func declaration_schedule_valid_v1(declaration: Dictionary,
	schedule_id: String = "measured_prone_entry_then_canonical_recovery_v1", after_steps: int = AFTER_INTERACTION_STEPS) -> bool:
	var expected := {"diagnostic_schedule_id": schedule_id,
		"maximum_passive_descent_steps": MAX_DESCENT_STEPS,
		"maximum_precondition_steps": SMOKE_MAX_PRECONDITION_STEPS,
		"walking_prefix_steps": SMOKE_PREFIX_STEPS, "interaction_steps": 1,
		"after_interaction_steps": after_steps,
		"maximum_steps_per_child": SMOKE_MAX_STEPS - SMOKE_AFTER_INTERACTION_STEPS + after_steps}
	for key in expected:
		var value: Variant = declaration.get(key)
		if (typeof(expected[key]) == TYPE_INT and typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or typeof(expected[key]) == TYPE_STRING and typeof(value) != TYPE_STRING):
			return false
		if value != expected[key]:
			return false
	return true


func _entry_after_interaction_steps_v1() -> int:
	return AFTER_INTERACTION_STEPS


func _configure_smoke_schedule_v1(declaration: Dictionary) -> bool:
	if not declaration_schedule_valid_v1(declaration, _entry_selection_v1()["schedule"], _entry_after_interaction_steps_v1()):
		return false
	_declared_after_interaction_steps = _entry_after_interaction_steps_v1()
	return true


func _load_runtime_extension_v1() -> bool:
	if _entry_runtime.is_empty():
		return false
	var selected: Dictionary = _entry_runtime["runtime"]
	var local_path := "res://" + String(_entry_runtime["local_build_path"])
	for path in [local_path, selected["path"]]:
		if (not FileAccess.file_exists(path)
			or FileAccess.get_file_as_bytes(path).size() != selected["byte_length"]
			or "sha256:" + FileAccess.get_sha256(path) != selected["raw_sha256"]):
			return false
	for source in _entry_runtime["source_files"]:
		var path := "res://" + String(source["path"])
		if not FileAccess.file_exists(path) or "sha256:" + FileAccess.get_sha256(path) != source["raw_sha256"]:
			return false
	# Only this fresh worker changes its loaded extension, before any SDK
	# instance or physical model exists. The old runtime files are untouched.
	if GDExtensionManager.is_extension_loaded(EXTENSION_PATH):
		if GDExtensionManager.unload_extension(EXTENSION_PATH) != GDExtensionManager.LOAD_STATUS_OK:
			return false
	if GDExtensionManager.load_extension(_entry_selection_v1()["extension"]) != GDExtensionManager.LOAD_STATUS_OK or not ClassDB.class_exists(CLASS_NAME):
		return false
	# Exercise the actual walking adapter's startup and shutdown before any
	# physical model. This is the boundary that reloaded the old DLL previously.
	var probe: Object = ClassDB.instantiate(CLASS_NAME)
	_entry_walking_runtime_preflight = LocomotionFacade.portable_session_preflight_v1(probe, _seed, true, _walking_prefix_profile_id_v1("walking_prefix"))
	return _entry_walking_runtime_preflight.get("ok") == true and not GDExtensionManager.is_extension_loaded(EXTENSION_PATH)


func _walking_uses_preloaded_native_runtime_v1() -> bool:
	return true


func _initialize_orchestrator_v1(arm_id: String, model_id: String, population: String) -> Dictionary:
	return EntryOrchestrator.initialize_v1(_sdk, _attempt_id, arm_id, model_id,
		_configuration_sha256, population, MAX_DESCENT_STEPS, _entry_controller_id_v1(), _walking_policy_id_v1("walking_resume"))


func _build_orchestrator_event_v1(state: Dictionary, fields: Dictionary) -> Dictionary:
	return EntryOrchestrator.build_event_v1(_sdk, state, fields, _entry_controller_id_v1(), _walking_policy_id_v1("walking_resume"))


func _advance_orchestrator_step_v1(state: Dictionary, event: Dictionary) -> Dictionary:
	var result := EntryOrchestrator.advance_v1(_sdk, state, event, _entry_controller_id_v1(), _walking_policy_id_v1("walking_resume"))
	_entry_transitions.append({"state_before": state.duplicate(true),
		"event": event.duplicate(true), "advance": result.duplicate(true)})
	if (result.get("ok") == true and result["next_phase"] == EntryOrchestrator.PHASE_DESCENT
		and state["phase"] == Orchestrator.PHASE_INTERACTION):
		# The completed setup memory remains in its retained terminal receipt.
		# There is no active post-kick canonical memory during descent.
		var arm: Dictionary = _arms[state["arm_id"]]
		arm["recovery_memory"] = {}
		arm["next_recovery_control"] = {}
		arm["last_recovery_terminal"] = false
		arm["passive_entry_state"] = {}
		arm["passive_entry_handoff_receipt"] = {}
		_arms[state["arm_id"]] = arm
	return result


func _process_completed_arm_step_v1(arm_id: String, global_step: int, active_terminal_after_step: bool) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var state: Dictionary = arm["orchestrator_state"]
	if state["phase"] != EntryOrchestrator.PHASE_DESCENT:
		var result := super._process_completed_arm_step_v1(arm_id, global_step, active_terminal_after_step)
		if state["phase"] in [Orchestrator.PHASE_CONFIRM_PRONE, Orchestrator.PHASE_POST_KICK_RECOVERY]:
			var after: Dictionary = _arms[arm_id]
			_canonical_packets.append({"global_semantic_step": global_step,
				"application": arm["pending_application"].duplicate(true),
				"collection_transport": after.get("last_recovery_collection_transport_retention", {}).duplicate(true),
				"step_receipt": after.get("last_recovery_step_receipt", {}).duplicate(true),
				"memory_after": after["recovery_memory"].duplicate(true), "worker_result": result.duplicate(true)})
		return result
	var label := "process_step/" + EntryOrchestrator.PHASE_DESCENT
	_cost.begin_v1(label)
	var result := _process_descent_v1(arm_id, global_step)
	_cost.end_v1(label)
	return result


func _process_descent_v1(arm_id: String, global_step: int) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var state: Dictionary = arm["orchestrator_state"]
	var collection: Dictionary = arm["last_collection"]
	var bound: Dictionary = collection.get("epoch_result", {}).get("bound_epoch_observations", {})
	var packet := EntryStage.advance_v1(_sdk, _context, _attempt_id, MAX_DESCENT_STEPS,
		bound, arm.get("passive_entry_state", {}))
	packet["source_application"] = arm["pending_application"].duplicate(true)
	_entry_packets.append(packet)
	if packet.get("ok") != true:
		return {"ok": false, "failure_code": packet.get("failure_code", "PASSIVE_ENTRY_STAGE_EMPTY")}
	var receipt: Dictionary = packet["entry_receipt"]
	arm["passive_entry_state"] = packet["entry_state"]
	arm["last_recovery_classification"] = receipt["classification"].duplicate(true)
	var rows: Array = arm["trace_rows"]
	rows[rows.size() - 1]["recovery_classification"] = receipt["classification"].duplicate(true)
	if receipt["canonical_memory"] is Dictionary:
		if not arm["recovery_memory"].is_empty() or not arm["passive_entry_handoff_receipt"].is_empty():
			return {"ok": false, "failure_code": "PASSIVE_ENTRY_REINITIALIZATION_FORBIDDEN"}
		arm["recovery_memory"] = receipt["canonical_memory"].duplicate(true)
		arm["passive_entry_handoff_receipt"] = receipt.duplicate(true)
		arm["first_post_entry_application_pending"] = true
	_arms[arm_id] = arm
	var application: Dictionary = arm["pending_application"]
	var event := _build_orchestrator_event_v1(state, {
		"event_kind": "passive_entry_observation", "global_semantic_step": global_step,
		"recovery_epoch_local_step": global_step - int(state["epoch_start_global_step"]),
		"control_owner": "none", "actuation_owner": "none", "no_actuation_requested": true,
		"application_intent_sha256": _canonical_sha256_v1(application),
		"energy_initializer_sha256": _arm_epoch_initializer_sha256_v1(arm),
		"prone_sample": receipt["classification"]["entry_prone_gate"],
		"stable_four_foot_stance": receipt["classification"]["stable_stance_gate"],
		"passive_entry_receipt_sha256": _canonical_sha256_v1(receipt),
		"passive_entry_status": receipt["memory"]["status"],
		"canonical_initialization_count": receipt["canonical_initialization_count"],
		"body_population_rebuild_count": arm["body_population_rebuild_count"],
		"body_transform_write_count": arm["body_transform_write_count"],
		"body_velocity_write_count": arm["body_velocity_write_count"],
		"solver_reset_count": arm["solver_reset_count"],
	})
	return _install_orchestrator_event_v1(arm_id, state, application, collection, bound, event)


func _plan_next_process_isolated_frame_v1(global_step: int) -> Dictionary:
	var phase: String = _arms.get(_authorized_arm_id, {}).get("orchestrator_state", {}).get("phase", "")
	if phase not in [EntryOrchestrator.PHASE_DESCENT, Orchestrator.PHASE_CONFIRM_PRONE, Orchestrator.PHASE_POST_KICK_RECOVERY]:
		return super._plan_next_process_isolated_frame_v1(global_step)
	# These branches bypass the inherited planner, so account for them here once.
	# Otherwise a valid new path would fail the unchanged full profiling audit.
	var label := "plan_step/" + phase
	_cost.begin_v1(label)
	var result := _plan_entry_frame_v1(global_step)
	_cost.end_v1(label)
	return result


func _plan_entry_frame_v1(global_step: int) -> Dictionary:
	var arm: Dictionary = _arms.get(_authorized_arm_id, {})
	var phase: String = arm.get("orchestrator_state", {}).get("phase", "")
	if phase == EntryOrchestrator.PHASE_DESCENT:
		return _plan_descent_application_v1(global_step)
	if phase in [Orchestrator.PHASE_CONFIRM_PRONE, Orchestrator.PHASE_POST_KICK_RECOVERY]:
		if arm.get("passive_entry_handoff_receipt", {}).is_empty():
			return {"ok": false, "failure_code": "PASSIVE_ENTRY_CANONICAL_HANDOFF_MISSING"}
		if arm.get("first_post_entry_application_pending", false):
			var stage := NoActuationStageL15._build_application_v1(_sdk, arm.duplicate(false),
				global_step + 1, arm["recovery_memory"], arm["passive_entry_handoff_receipt"],
				false, "first_recovery_owned_observation_after_measured_prone", 0, _entry_controller_id_v1())
			var consumed := _consume_l15_no_actuation_stage_v1(stage)
			if consumed.get("ok") == true:
				_arms[_authorized_arm_id]["first_post_entry_application_pending"] = false
				_first_recovery_application = _arms[_authorized_arm_id]["pending_application"].duplicate(true)
			return consumed
		return (_create_passive_recovery_observation_application_v1(global_step)
			if phase == Orchestrator.PHASE_CONFIRM_PRONE
			else _apply_recovery_control_v1(_authorized_arm_id, global_step))
	return super._plan_next_process_isolated_frame_v1(global_step)


func _plan_descent_application_v1(completed_global_step: int) -> Dictionary:
	var arm: Dictionary = _arms[_authorized_arm_id]
	if (arm["orchestrator_state"].get("phase") != EntryOrchestrator.PHASE_DESCENT
		or arm["orchestrator_state"].get("previous_global_semantic_step") != completed_global_step
		or not arm["recovery_memory"].is_empty() or not arm["next_recovery_control"].is_empty()):
		return {"ok": false, "failure_code": "PASSIVE_ENTRY_DESCENT_SOURCE_STATE_INVALID"}
	var next_step := completed_global_step + 1
	var facade: RefCounted = arm["facade"]
	var readback: Dictionary = facade.motor_population_readback_v1(next_step, false, "controller_free_passive_descent")
	if readback.get("ok") != true:
		return readback
	_total_native_readback_count += int(readback.get("native_readback_count", 0))
	# The existing opt-in mapping supports owner-none with empty memory and
	# binds its canonical command identifier to the unchanged source receipt.
	var application := LocomotionFacade.no_actuation_ledger_application_intent_v2(_sdk,
		next_step, EntryOrchestrator.PHASE_DESCENT, "none", null, false,
		arm["orchestrator_state"], readback, {})
	if application.get("ok") != true:
		return application
	arm["pending_application"] = application
	_arms[_authorized_arm_id] = arm
	return NoActuationStageL15.validate_pending_v1(_sdk, arm, next_step)


func _attach_entry_retention_v1(report: Dictionary) -> void:
	report["schema_version"] = _entry_selection_v1()["report_schema"]
	report["work_id"] = _entry_selection_v1()["work_id"]
	report["passive_entry"] = {"schema_version": "sporespore_development_measured_prone_entry_retention_v1",
		"walking_runtime_preflight": _entry_walking_runtime_preflight,
		"runtime_binding": _entry_runtime, "entry_packets": _entry_packets,
		"orchestrator_transitions": _entry_transitions, "canonical_packets": _canonical_packets,
		"first_recovery_owned_application": _first_recovery_application,
		"maximum_passive_descent_steps": MAX_DESCENT_STEPS,
		"after_interaction_steps": _entry_after_interaction_steps_v1(),
		"canonical_initialization_permitted_before_prone": false,
		"energy_epoch_reset_permitted_at_handoff": false,
		"physical_acceptance_authority": false, "release_authority": false}


func _publish_smoke_report_v1(report: Dictionary) -> String:
	_attach_entry_retention_v1(report)
	return super._publish_smoke_report_v1(report)


func _publish_process_isolated_child_abort_v1(report: Dictionary) -> void:
	_attach_entry_retention_v1(report)
	super._publish_process_isolated_child_abort_v1(report)
