extends "res://sdk/adapters/godot/gdscript/r10dg_linked_capture_worker_v1.gd"
## Only the exact child with a complete gate and durable reservation can initialize.
const R10DGSeed := preload("res://sdk/adapters/godot/gdscript/r10dg_development_seed_v1.gd")
const R10DGWorldGuard := preload("res://sdk/adapters/godot/gdscript/r10dg_native_world_guard_v1.gd")
var _diagnostic_terminal: Dictionary = {}

func _abort(code: String, detail: Dictionary = {}) -> void:
	# Only the declared native refusal or entry branch is a diagnostic endpoint.
	# Cleanup/publication failures retain the original infrastructure-abort path.
	if not _diagnostic_terminal.is_empty() and not _finalizing and not _exit_scheduled:
		_finish_smoke_v1("r10dg_" + str(_diagnostic_terminal.disposition))
		return
	super._abort(code, detail)

func _entry_packet_v1(bound: Dictionary, prior: Dictionary) -> Dictionary:
	var packet := super._entry_packet_v1(bound, prior)
	if packet.get("ok") != true:
		_retain_native_entry_refusal_v1(packet, "passive_entry")
	return packet

func _partial_step_packet_v1(bound: Dictionary, declaration: Dictionary, memory: Dictionary) -> Dictionary:
	var packet := super._partial_step_packet_v1(bound, declaration, memory)
	if packet.get("ok") != true:
		_retain_native_entry_refusal_v1(packet, "first_partial_observation")
	return packet

func _retain_native_entry_refusal_v1(packet: Dictionary, boundary: String) -> void:
	var call: Variant = packet.get("call")
	if not call is Dictionary or not call.get("response") is Dictionary: return
	var response: Variant = _sdk.decode_exact_json_v1(call.response.get("utf8_text", ""))
	if not response is Dictionary or response.get("ok") != false or response.get("failure_code") != "FRAME_INVALID": return
	if response.get("detail") not in ["r10dd_reference_entry_physical_state", "r10dd_reference_entry_clock", "r10dd_reference_entry_descriptor"]: return
	_diagnostic_terminal = {"disposition": "native_reference_entry_refusal", "boundary": boundary,
		"native_failure": response.duplicate(true), "packet": packet.duplicate(true),
		"physical_acceptance_authority": false, "release_authority": false}

func _process_descent_v1(arm_id: String, global_step: int) -> Dictionary:
	var result := super._process_descent_v1(arm_id, global_step)
	if result.get("ok") != true: return result
	var kind: String = _arms[arm_id].orchestrator_state.r10v_entry_kind
	if kind in ["prone", "upright"]:
		_diagnostic_terminal = {"disposition": "unexpected_entry_branch", "entry_kind": kind,
			"global_semantic_step": global_step, "physical_acceptance_authority": false, "release_authority": false}
		return {"ok": false, "failure_code": "R10DG_DIAGNOSTIC_UNEXPECTED_ENTRY_BRANCH"}
	return result

func _attach_profile_recovery_retention_v1(report: Dictionary) -> void:
	super._attach_profile_recovery_retention_v1(report)
	report["r10dg_diagnostic_terminal"] = _diagnostic_terminal.duplicate(true)

func _authorized_seed_binding_v1(seed_text: String, label: String, digest: String) -> bool:
	if not _r10k_selected_v1(): return false
	if not R10DGSeed.authorized_v1(_campaign_declaration, seed_text, label, digest,
		OS.get_environment(CHILD_ROLE_ENV), OS.get_environment(SOURCE_COMMIT_ENV)): return false
	var authorized := R10DGWorldGuard.authorize_worker_v1(_campaign_declaration)
	print("R10DG_STARTUP_DIAGNOSTIC " + JSON.stringify(R10DGWorldGuard.startup_diagnostic_v1()))
	return authorized

func _load_runtime_extension_v1() -> bool:
	var runtime := RouteScript.ProfileCapabilityScript.select_r10dg_diagnostic_runtime_v1(
		_campaign_declaration, _candidate_selection.get("candidate_profile", {}))
	if runtime.get("ok") != true: return false
	return super._load_runtime_extension_v1()

func _walking_prefix_profile_id_v1(segment: String) -> String:
	return R10DGSeed.PREFIX_PROFILE if segment == "walking_prefix" else ""

func _attach_profile_seed_context_v1(report: Dictionary) -> bool:
	if not R10DGSeed.attach_report_context_v1(report, _campaign_declaration, _seed): return false
	var claim := R10DGWorldGuard.report_binding_v1()
	if not claim.is_empty(): report["r10dg_native_world_claim"] = claim
	return true
