"""Add exact startup input capture to an isolated short Studio route."""
from pathlib import Path
import shutil

STUDIO=Path(__file__).resolve().parent
NAME="advance_behavior_solver_coupled_complete_energy_l15_v1"


def materialize(project):
    route=project/"sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
    source=route.read_text(encoding="utf-8-sig")
    signature=f"static func {NAME}("
    if source.count(signature)!=1:raise ValueError("Startup capture route boundary changed")
    source=source.replace(signature,f"static func _studio_uncaptured_{NAME}(",1)
    source+='''
const StartupCapture := preload("res://sdk/explorer/studio/startup_packet_capture.gd")

static func advance_behavior_solver_coupled_complete_energy_l15_v1(
	sdk: Object, context: Dictionary, bound: Dictionary, memory: Dictionary,
	arm_kind: String, phase: String, source_application: Dictionary
) -> Dictionary:
	var token := StartupCapture.begin(context,bound,memory,arm_kind,phase,source_application)
	var result := _studio_uncaptured_advance_behavior_solver_coupled_complete_energy_l15_v1(
		sdk,context,bound,memory,arm_kind,phase,source_application)
	StartupCapture.finish(token,result)
	return result
'''
    worker=project/"sdk/explorer/native_recovery/worker.gd"
    old=worker.read_text(encoding="utf-8-sig")
    verify="func _verify_l15_prepared_context_before_world_v1() -> bool:\n"
    complete='\tif value.get("message_type")=="completed":\n'
    if old.count(verify)!=1 or old.count(complete)!=1 or "func _after_completed_process_isolated_step_v1(" in old:
        raise ValueError("Startup capture worker hook changed")
    updated=old.replace(verify,verify+'''	var capture_checks := StartupCapture.zero_world(_diagnostic.output.get_base_dir().path_join("startup-capture-controls"))
	if not capture_checks.ok:
		_abort("STARTUP_CAPTURE_CONTROL_FAILED",capture_checks);return false
	_startup_capture_controls=capture_checks
	if not _check_only:StartupCapture.reset(_diagnostic.output.get_base_dir().path_join("startup-packets"))
''',1)
    updated=updated.replace(complete,complete+'''		value.summary["startup_packet_capture_controls"]=_startup_capture_controls
		if not _check_only:
			value.summary["startup_packet_capture"]=StartupCapture.summary()
			value.ok=value.get("ok")==true and value.summary.startup_packet_capture.ok
''',1)
    updated+='''
const StartupCapture := preload("res://sdk/explorer/studio/startup_packet_capture.gd")
var _startup_capture_controls: Dictionary = {}

func _after_completed_process_isolated_step_v1() -> bool:
	if not StartupCapture.failure.is_empty():
		_abort("STARTUP_CAPTURE_FAILED",{"detail":StartupCapture.failure});return true
	return super._after_completed_process_isolated_step_v1()
'''
    # Validate both insertion sites before writing either source.
    route.write_text(source,encoding="utf-8",newline="\n")
    worker.write_text(updated,encoding="utf-8",newline="\n")
    shutil.copy2(STUDIO/"startup_packet_capture.gd",project/"sdk/explorer/studio/startup_packet_capture.gd")
    return dict(fixed_steps=[1,30,60,120,180,239,240],first_call_of_each_phase=True,
        maximum_packets=16,maximum_semantic_step=240,additional_controller_calls=0,
        additional_physics_reads=0,performance_comparison_authority=False)
