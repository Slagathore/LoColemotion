extends SceneTree
# gdlint: disable=max-line-length

const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Facade := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd")
const Frame := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_frame_v1.gd")
const Prior := preload("res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd")
const Evaluator := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v2.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

class Probe:
	extends "res://sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd"
	func _initialize() -> void:
		pass # No launch. Exercise the actual worker's selection hook only.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var selection := Profile.load_v1({"resource": args[0], "raw_sha256": args[1]})
	var checks := {"profile_loaded": not selection.is_empty()}
	if selection.is_empty():
		_finish(checks)
		return
	var id: String = selection["diagnostic_schedule"]["walking_resume_frame_id"]
	var probe := Probe.new()
	probe._candidate_selection = selection
	checks["real_worker_resume_selected"] = probe._walking_frame_id_v1("walking_resume") == id
	var route_id: String = selection["diagnostic_schedule"].get("walking_policy_id", "")
	var finite := Profile.WalkingPolicy.FiniteRoute.selected_v1(route_id)
	for segment in ["", "walking_prefix"]:
		checks["real_worker_preserves_" + segment] = probe._walking_frame_id_v1(segment).is_empty()
	checks["real_worker_matched_frame_matches_selected_route"] = probe._walking_frame_id_v1("matched_continuation") == (id if finite else "")
	var old_path := "res://sdk/development/recovery_candidates/v17-velocity-damped-stance-v1.json"
	probe._candidate_selection = Profile.load_v1({"resource": old_path, "raw_sha256": "sha256:" + FileAccess.get_sha256(old_path)})
	checks["v17_worker_unchanged"] = probe._walking_frame_id_v1("walking_resume").is_empty()
	probe._candidate_selection = selection
	if probe._r10k_selected_v1(): probe._seed = 40741 if probe._r10o_selected_v1() else 40641 if probe._r10n_selected_v1() else 40541 if probe._r10m_selected_v1() else 40441 if probe._r10l_selected_v1() else 40341 # Explicit zero-world prefix preflight.
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(selection["worker_selection"]["binding"]))
	checks["exact_runtime_loaded"] = probe._load_runtime_extension_v1()
	if not checks["exact_runtime_loaded"]:
		probe.free()
		_finish(checks)
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[2]))
	var q: Dictionary = fixture["native_quaternion_at_standing_completion"]
	var bases := [Basis.IDENTITY, Basis(Vector3.UP, PI / 2.0),
		Basis.from_euler(Vector3(0.13, -0.7, 0.09)),
		Basis(Quaternion(q["x"], q["y"], q["z"], q["w"]))]
	for index in range(bases.size()):
		var basis: Basis = bases[index]
		var old := Frame.frame_v1(basis, "walking_resume")
		var frame := Frame.frame_v1(basis, "walking_resume", id)
		var expected_lateral := Vector3(basis.z.x, 0.0, basis.z.z).normalized()
		var expected_forward := Vector3.UP.cross(expected_lateral).normalized()
		checks["normal_launcher_axes_" + str(index)] = (frame["lateral"] == expected_lateral and frame["forward"] == expected_forward)
		checks["legacy_exact_" + str(index)] = (old["lateral"] == basis.x.normalized() and old["forward"] == -basis.z.normalized())
		checks["legacy_yaw_preserved_" + str(index)] = frame["legacy_yaw_rad"] == old["legacy_yaw_rad"]
		checks["trace_anatomical_forward_" + str(index)] = Frame.trace_forward_v1(basis, id) == basis.x.normalized()
		var facade := Facade.new()
		var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID)["profile"]
		# This is the exact call used by start_walking_session_v1, including the
		# selected DLL, real controller session, phase initialization and shutdown.
		var started := facade._start_adapter_from_frame_v1(frame, Vector3(0.1, 0.4, -0.2),
			Facade.initial_gait_steps_v1(240, "walking_resume"), material, true)
		checks["actual_adapter_start_" + str(index)] = started.get("ok") == true
		if started.get("ok") == true:
			checks["actual_adapter_frame_" + str(index)] = (facade._adapter._initial_forward_axis_world.is_equal_approx(expected_forward)
				and facade._adapter._initial_lateral_axis_world.is_equal_approx(expected_lateral))
			checks["actual_adapter_heading_" + str(index)] = absf(wrapf(facade._adapter._canonical_initial_heading_rad - (frame["legacy_yaw_rad"] - PI / 2.0), -PI, PI)) < 1.0e-12
			checks["actual_adapter_shutdown_" + str(index)] = facade._adapter.shutdown().get("ok") == true
		facade._adapter = null
		var evidence := Prior._walking_evaluation_fixture_v1()
		evidence["expected_step_count"] = 30
		evidence["segment_id"] = "walking_resume"
		evidence["rows"] = evidence["rows"].slice(0, 30)
		for key in ["step_count", "validated_balanced_wave_command_count", "native_actuation_application_count"]:
			evidence["completion_receipt"]["adapter_summary"][key] = 30 if key == "step_count" else 240
		evidence["start_receipt"]["task_frame_forward_axis_world_host_real"] = [expected_forward.x, expected_forward.y, expected_forward.z]
		evidence["start_receipt"]["task_frame_lateral_axis_world_host_real"] = [expected_lateral.x, expected_lateral.y, expected_lateral.z]
		for row in evidence["rows"]:
			var forward := Frame.trace_forward_v1(basis, id)
			row["torso_forward_axis_world_unit"] = [forward.x, forward.y, forward.z]
		var result := Evaluator.evaluate_development_smoke_segment_v1(sdk, evidence)
		checks["actual_evaluator_heading_" + str(index)] = (result.get("ok") == true and result["walking_gate_receipts"]["bounded_yaw_drift"] == true)
		checks["diagnostic_no_authority_" + str(index)] = result.get("behavioral_conclusion") == "none"
		checks["official_short_refusal_" + str(index)] = not Evaluator.evaluate_segment_v2(sdk, evidence).get("ok", false)
		for row in evidence["rows"]:
			var wrong := -basis.z.normalized()
			row["torso_forward_axis_world_unit"] = [wrong.x, wrong.y, wrong.z]
		result = Evaluator.evaluate_development_smoke_segment_v1(sdk, evidence)
		checks["mixed_axis_negative_" + str(index)] = (result.get("ok") == true and result["walking_gate_receipts"]["bounded_yaw_drift"] == false)
	for bad in [false, null, "unknown", 17]:
		checks["bad_selection_" + str(bad)] = not Frame.valid_selection_v1(bad)
	checks["prefix_override_refuses"] = not Frame.frame_v1(Basis.IDENTITY, "walking_prefix", id).get("ok", false)
	checks["vertical_lateral_refuses"] = not Frame.frame_v1(Basis(Vector3.RIGHT, PI / 2.0), "walking_resume", id).get("ok", false)
	var segments := ["walking_resume", "matched_continuation"] if finite else ["walking_resume"]
	for segment in segments:
		var arm := {"walking_sessions": [{"evaluation_segment_id": segment, "start_receipt": {"development_walking_frame_id": id}}],
			"trace_rows": [{"walking_segment_id": segment, "development_walking_frame_id": id}]}
		checks["reader_declared_frame_" + segment] = Frame.report_selection_valid_v1(arm, id, route_id)
		checks["reader_refuses_v17_transplant_" + segment] = not Frame.report_selection_valid_v1(arm, "", route_id)
		if segment == "matched_continuation":
			checks["reader_refuses_undeclared_matched_frame"] = not Frame.report_selection_valid_v1(arm, id)
		arm["trace_rows"][0].erase("development_walking_frame_id")
		checks["reader_refuses_missing_row_frame_" + segment] = not Frame.report_selection_valid_v1(arm, id, route_id)
		arm["trace_rows"] = []
		arm["walking_sessions"][0]["start_receipt"].erase("development_walking_frame_id")
		checks["reader_refuses_missing_start_frame_" + segment] = not Frame.report_selection_valid_v1(arm, id, route_id)
	sdk = null
	probe.free()
	_finish(checks)

func _finish(checks: Dictionary) -> void:
	var ok := not checks.values().has(false)
	print("DEVELOPMENT_WALKING_FRAME_CHECKS ", Transport.stringify({"ok": ok, "checks": checks,
		"synthetic_and_retained_inputs_only": true, "model_construction_count": 0,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	quit(0 if ok else 1)
