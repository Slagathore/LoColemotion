extends SceneTree
const Boundary := preload("res://tests/test_r10v_settling_orchestrator.gd")
const R10V := Boundary.R10V
const Reader := preload("res://sdk/adapters/godot/gdscript/r10v_recovery_replay_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
class Worker:
	extends "res://sdk/adapters/godot/gdscript/r10v_recovery_worker_v1.gd"
	var measured: Dictionary = {}
	var close_count := 0
	var published_reason := ""
	func _initialize() -> void: pass
	func _entry_measurement_v1(_arm: Dictionary) -> Dictionary: return measured.duplicate(true)
	func _finish_walking_session_v1(_arm_id: String) -> Dictionary:
		close_count += 1
		return {"ok":true}
	func _finish_smoke_v1(reason: String) -> void: published_reason = reason
var checks := {}
var detail := {}
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old):
		if GDExtensionManager.unload_extension(old) != GDExtensionManager.LOAD_STATUS_OK: quit(2); return
	if GDExtensionManager.load_extension("res://sdk/adapters/godot/development_candidate_runtimes/r10s-extended-preparation-core-v1.gdextension") != GDExtensionManager.LOAD_STATUS_OK: quit(3); return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var input: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	var original: Dictionary = input.cases.filter(func(v): return v.case_id == "phase245_upright")[0]
	var before := Boundary._state(sdk, original.transition.state_before)
	var event := Boundary._event(sdk, original.transition.event, original.source)
	var advanced := R10V.advance_v1(sdk,before,event)
	checks.real_terminal_enters_hold = advanced.get("ok") == true and advanced.next_phase == R10V.PHASE_SETTLING
	if checks.real_terminal_enters_hold:
		var compiled: Dictionary = sdk.decode_exact_json_v1(sdk.compile_bounded_quadruped_json(Transport.stringify(Reader.Facade.RecoveryRoute.exact_base_descriptor_v1())))
		var measured := Reader._settling_source_v1(sdk,original.source,compiled.value,before,event.global_semantic_step)
		checks.reader_recomputes_real_terminal_source = measured.get("ok") == true and measured.readiness.ready == false
		var changed: Dictionary = original.source.duplicate(true)
		changed.readiness.ready = true
		checks.reader_refuses_rewritten_readiness = Reader._settling_source_v1(sdk,changed,compiled.value,before,event.global_semantic_step).get("ok") == false
		checks.reader_refuses_crossed_clock = Reader._settling_source_v1(sdk,original.source,compiled.value,before,event.global_semantic_step+1).get("ok") == false
		for mode in ["early_ready","last_command_ready","timeout"]: _run_worker(sdk,advanced.state_after,event,original.source.readiness,mode)
	sdk = null
	var ok := checks.values().all(func(v): return v == true)
	var out := FileAccess.open(args[1],FileAccess.WRITE)
	out.store_string(Transport.stringify({"ok":ok,"checks":checks,"detail":detail,"synthetic_hold_measurements":true,"native_hold_commands":0,"world_build_count":0,"solver_step_count":0,"physical_route_qualified":false,"physical_acceptance_authority":false,"release_authority":false}))
	out.close()
	print("R10V_WORKER_SETTLING_BOUNDARY ",checks.size()," checks; ok=",ok)
	quit(0 if ok else 1)
func _run_worker(sdk: Object, pending: Dictionary, terminal: Dictionary, sample: Dictionary, mode: String) -> void:
	var worker := Worker.new()
	worker._sdk = sdk
	var arm_id: String = pending.arm_id
	worker._authorized_arm_id = arm_id
	worker._candidate_selection = {"diagnostic_schedule":{"walking_policy_id":R10V.ROUTE}}
	var native: Dictionary = terminal.r10v_native_receipt
	worker._arms[arm_id] = {"orchestrator_state":pending.duplicate(true),"r10v_upright_memory":native.step.memory.duplicate(true),"r10v_native_receipt":native.duplicate(true),"model":{},"pending_application":{},"last_collection":{"global_result":{"bound":{"observation_v3":{}}}},"body_population_rebuild_count":0,"body_transform_write_count":0,"body_velocity_write_count":0,"solver_reset_count":0}
	var arm: Dictionary = worker._arms[arm_id]
	checks[mode+"_completed_memory_guard"] = worker._completed_upright_memory_preserved_v1(arm)
	var changed := arm.duplicate(true)
	changed.r10v_upright_memory.phase = "stance_dwell"
	checks[mode+"_reopened_memory_refused"] = not worker._completed_upright_memory_preserved_v1(changed)
	changed = arm.duplicate(true)
	changed.model[worker.UprightBridge.Source.KEY] = {}
	checks[mode+"_old_controller_tag_refused"] = not worker._completed_upright_memory_preserved_v1(changed)
	var count := 30 if mode == "early_ready" else 240
	var processing_ok := true
	for index in range(count):
		var state: Dictionary = worker._arms[arm_id].orchestrator_state
		var global: int = state.previous_global_semantic_step+1
		var ready: bool = mode == "early_ready" or mode == "last_command_ready" and index >= 210
		var observed := sample.duplicate(true)
		observed.source_semantic_step = global
		observed.ready = ready
		observed.checks.horizontal_com_settled = ready
		observed.horizontal_com_speed_m_s = 0.02 if ready else 0.03400406676351237
		worker.measured = {"ok":true,"readiness":observed,"synthetic_worker_test_measurement":true}
		worker._arms[arm_id].pending_application = {"walking_session_id":"fresh-post-hold", "walking_session_local_step":index+1}
		worker._post_recovery_hold_control_rows.append({"step":{"global_semantic_step":global}})
		var processed := worker._process_post_recovery_hold_v1(arm_id,global)
		if processed.get("ok") != true:
			processing_ok = false
			detail[mode] = processed
			break
		if index < count-1 and worker.close_count != 0: processing_ok = false; break
	var final: Dictionary = worker._arms[arm_id].orchestrator_state
	checks[mode+"_actual_worker_transition_chain"] = processing_ok and worker._entry_transitions.size() == count
	checks[mode+"_exact_once_close"] = worker.close_count == 1
	checks[mode+"_separate_readiness_retention"] = worker._post_recovery_hold_readiness_rows.size() == count and worker._entry_readiness_rows.is_empty()
	checks[mode+"_original_recovery_memory_preserved"] = worker._completed_upright_memory_preserved_v1(worker._arms[arm_id])
	checks[mode+"_walking_counter_zero"] = final.walking_resume_step_count == 0 and final.recovery_epoch_step_count == final.previous_global_semantic_step-final.epoch_start_global_step
	checks[mode+"_terminal_outcome"] = final.post_recovery_settling.outcome == ("timeout" if mode == "timeout" else "ready")
	if mode == "timeout":
		checks.timeout_publication_path = worker._after_completed_process_isolated_step_v1() and worker.published_reason == "diagnostic_post_recovery_hold_timeout"
		checks.timeout_original_terminal_retained = worker._arms[arm_id].get("terminal_orchestrator_transition", {}).get("advance_receipt", {}).get("state_after", {}).get("terminal_reason") == "post_recovery_hold_timeout"
	worker._sdk = null
	worker.free()
