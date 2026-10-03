extends RefCounted
## Both independent readers are mandatory. No report translation or new physics.
const Controller := preload("res://sdk/adapters/godot/gdscript/r10ap_controller_report_replay_v1.gd")
const Diagnostic := preload("res://sdk/adapters/godot/gdscript/r10af_contact_frame_report_v1.gd")
const Seed := preload("res://sdk/adapters/godot/gdscript/r10ap_development_seed_v1.gd")

static func replay_report_v1(sdk: Object, report: Dictionary, binding: Dictionary,
	selection: Dictionary, declaration: Dictionary) -> Dictionary:
	if selection.get("candidate_profile") != {"resource": Seed.PROFILE, "raw_sha256": Seed.PROFILE_SHA}:
		return {"ok": false, "failure_code": "R10AP_COMBINED_PROFILE"}
	var diagnostic := Diagnostic.replay_report_v1(sdk, report, declaration, Seed)
	if diagnostic.get("ok") != true: return diagnostic
	var controller := Controller.replay_report_v1(sdk, report, binding,
		selection.get("post_kick_controller_id", ""), selection,
		Controller.CandidateProfile.walking_memory_transition_id_v1(selection))
	if controller.get("ok") != true: return controller
	var result := controller.duplicate(true)
	result["r10af_contact_frame_replay"] = diagnostic
	result["controller_and_diagnostic_replay_passed"] = true
	return result
