extends "res://tests/test_development_r10ab_report_fixture.gd"
## Fresh synthetic inputs only. The real controller and report publisher run;
## source contact frames are declared fixtures, never a native physics result.
const AC := preload("res://sdk/adapters/godot/gdscript/r10ad_development_worker_v1.gd")
const FrameCapture := AC.ContactFrames
const FrameReport := AC.ContactReport
var _frame_template := {}
var _captures_by_step := {}
var _links_by_step := {}
var _rejected_collection_controls := {}

class R10ADProbe:
	extends "res://sdk/adapters/godot/gdscript/r10ad_development_worker_v1.gd"
	func _initialize() -> void:
		pass # Suppress automatic launch; use the actual selected worker hooks.

func _make_report_probe_v1() -> SceneTree:
	return R10ADProbe.new()

func _declared_v1() -> Dictionary:
	if _declaration.is_empty():
		_declaration = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SPORE_R10AD_FIXTURE_DECLARATION")))
	return _declaration

func _configure_fixture_probe_v1(probe: SceneTree, resource: String) -> void:
	super._configure_fixture_probe_v1(probe, resource)
	checks["v7_default_native_profile_refuses"] = not Route.ProfileCapabilityScript.rotation_aware_complete_energy_runtime_identity_v1().get("exact_binary_pair_match", false)
	for key in ["seed", "candidate_profile", "runtime", "official_qualification", "source_snapshot"]:
		var crossed := _declared_v1().duplicate(true)
		if key == "seed": crossed.seed = 51008
		elif key == "official_qualification": crossed[key] = true
		else: crossed[key] = {}
		var refused := Route.ProfileCapabilityScript.select_r10ad_diagnostic_runtime_v1(crossed, probe._candidate_selection.candidate_profile)
		checks["native_runtime_refuses_" + key] = refused.get("ok") == false
		checks["refusal_preserves_default_" + key] = not Route.ProfileCapabilityScript.rotation_aware_complete_energy_runtime_identity_v1().get("exact_binary_pair_match", false)
	var selected := Route.ProfileCapabilityScript.select_r10ad_diagnostic_runtime_v1(
		_declared_v1(), probe._candidate_selection.candidate_profile)
	checks["explicit_v7_diagnostic_runtime_selected"] = selected.get("ok") == true
	checks["other_native_profile_stays_unselected"] = not Route.ProfileCapabilityScript.complete_energy_runtime_identity_v1().get("exact_binary_pair_match", false)
	checks["runtime_selection_has_no_world_authority"] = selected.get("physical_execution_authorized") == false
	var world_refusal: Dictionary = await Sources.World.build_world_v1(null, null, {})
	checks["native_world_stays_closed_after_runtime_selection"] = world_refusal.get("failure_code") == "R10AD_NATIVE_WORLD_QUALIFICATION_PENDING"
	if selected.get("ok") != true: push_error(str(selected))

func _crossed_memory_probe_v1(probe: SceneTree, step: int) -> Dictionary:
	# A rejected collection is retained by the real diagnostic worker. Give the
	# negative control its own probe, preserving its rejection outside the valid
	# synthetic timeline instead of deleting it from a publication population.
	var negative := R10ADProbe.new()
	negative._sdk = probe._sdk
	negative._arms = probe._arms.duplicate(true)
	negative._candidate_selection = probe._candidate_selection.duplicate(true)
	negative._arms[ARM].r10k_partial_memory.last_semantic_step += 1
	var refused: Dictionary = negative._collect_arm_completed_step_v1(ARM, step)
	_rejected_collection_controls = {"result": refused,
		"capture_records": negative._r10ac_contact_frame_records.duplicate(true),
		"link_records": negative._r10ac_observation_links.duplicate(true),
		"synthetic_negative_control": true, "world_build_count": 0, "solver_step_count": 0}
	negative._sdk = null
	negative.free()
	var file := FileAccess.open(_output + ".rejected.json", FileAccess.WRITE)
	file.store_string(Transport.stringify(_rejected_collection_controls) + "\n"); file.close()
	return refused

func _packet_v1(sdk: Object, step: int) -> Dictionary:
	if _frame_template.is_empty():
		var raw := FileAccess.get_file_as_string(OS.get_environment("SPORE_R10AD_FRAME_FIXTURES"))
		var decoded: Dictionary = sdk.decode_exact_json_v1(raw)
		# The stationary packet supplies one explicitly synthetic loaded contact.
		_frame_template = decoded.fixtures[1].packet
	var packet := _frame_template.duplicate(true)
	packet.model_instance_id = Sources.Prior.MODEL_INSTANCE_ID
	packet.body_population_instance_sha256 = SHA
	packet.semantic_step = step
	for key in ["direct_state_source", "contact_source_receipt", "source_component_binding"]:
		packet[key].semantic_step = step
	packet.contact_source_receipt.native_space_step_sequence = step
	for body in packet.callback_bodies + packet.direct_state_source.ordered_body_states:
		body.callback_sequence = step
	packet.native_snapshot.capture_space_step_sequence = step
	packet.native_snapshot.read_space_step_sequence = step
	packet.source_component_binding.direct_state_source_sha256 = Runtime.canonicalize(sdk, packet.direct_state_source).get("sha256")
	packet.source_component_binding.contact_source_sha256 = Runtime.canonicalize(sdk, packet.contact_source_receipt).get("sha256")
	var replay := FrameCapture.replay_v1(sdk, packet, step, Sources.Prior.MODEL_INSTANCE_ID, SHA)
	_captures_by_step[step] = {"ok": replay.get("ok") == true, "packet": packet,
		"packet_sha256": Runtime.canonicalize(sdk, packet).get("sha256"), "replay": replay,
		"controller_observation_changed": false, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	return packet

func _bind_diagnostic_fixture_sources_v1(sdk: Object, sources: Dictionary, observation: Dictionary, step: int) -> Dictionary:
	var packet := _packet_v1(sdk, step)
	if _captures_by_step[step].get("ok") != true: return _captures_by_step[step].replay
	var components: Dictionary = sources.source_component_receipts
	# The inherited energy-only synthetic source has no body/contact trace.
	# Declare this fixture's trace before native observation hashing/composition.
	components["source_trace"] = {"schema_version": "sporespore_r10ad_synthetic_recovery_source_v1",
		"semantic_step": step, "synthetic_test_fixture": true}
	for key in ["direct_state_source_sha256", "contact_source_sha256"]:
		components[key] = packet.source_component_binding[key]
		components.source_trace[key] = packet.source_component_binding[key]
	components.source_trace.direct_state_callback_sequence = step
	components.source_trace.native_space_step_sequence = step
	components.source_trace.host_step_before = step - 1
	components.source_trace.host_step_after = step
	components.source_trace.source_measurement = true
	components.source_trace_sha256 = Runtime.canonicalize(sdk, components.source_trace).get("sha256")
	observation.engine_step_identity.source_trace_sha256 = components.source_trace_sha256
	return {"ok": true}

func _complete_fixture_collection_v1(_sdk: Object, result: Dictionary, _step: int) -> void:
	result.measurement.source_component_receipts = result.bound.native_to_portable_staging_mapping.rotation_aware_predecessor_source_component_receipts.duplicate(true)

func _completed_fixture_trace_v1(sdk: Object, arm: Dictionary, projected: Dictionary, step: int) -> Dictionary:
	var row := super._completed_fixture_trace_v1(sdk, arm, projected, step)
	var input := {"last_collection": {"global_result": projected.global_result}, "trace_rows": [row]}
	_links_by_step[step] = FrameReport.link_v1(sdk, input, step)
	return row

func _report_v1(probe: SceneTree, baseline: bool) -> Dictionary:
	# The inherited controller fixture declares setup/prefix events synthetically.
	# Give those steps their own source-linked captures before publication as well.
	for step in range(1, 273):
		var packet := _packet_v1(probe._sdk, step)
		var source := {"schema_version": "sporespore_r10ad_synthetic_setup_source_v1", "semantic_step": step,
			"direct_state_callback_sequence": step, "native_space_step_sequence": step,
			"host_step_before": step-1, "host_step_after": step, "source_measurement": true,
			"direct_state_source_sha256": packet.source_component_binding.direct_state_source_sha256,
			"contact_source_sha256": packet.source_component_binding.contact_source_sha256}
		var observation := {"engine_step_identity": {"schema_version": "sporespore_recovery_engine_step_identity_v1",
			"semantic_step": step, "host_step_before": step-1, "host_step_after": step,
			"native_solver_substep_count": 1, "post_step_observation": true,
			"source_trace_sha256": Runtime.canonicalize(probe._sdk, source).get("sha256")}}
		_links_by_step[step] = {"ok": true, "semantic_step": step, "source_trace": source, "global_observation": observation}
	var count: int = probe._arms[ARM].orchestrator_state.previous_global_semantic_step
	for step in range(1, count+1):
		if not _captures_by_step.has(step) or not _links_by_step.has(step):
			return {"ok": false, "failure_code": "R10AD_FIXTURE_CAPTURE_MISSING", "step": step}
		if _captures_by_step[step].get("ok") != true or _links_by_step[step].get("ok") != true:
			return {"ok": false, "failure_code": "R10AD_FIXTURE_LINK_REFUSED", "step": step,
				"capture": _captures_by_step[step].get("replay"), "link": _links_by_step[step]}
		probe._r10ac_contact_frame_records.append(_captures_by_step[step])
		probe._r10ac_observation_links.append(_links_by_step[step])
	var result := super._report_v1(probe, baseline)
	if result.get("ok") != true: return result
	# Complete the explicitly synthetic setup rows with the hashes declared above.
	for row in result.report.retained_arm.trace_rows:
		if row.global_semantic_step > 272: break
		row.body_population_instance_sha256 = SHA
		row.observation_sha256 = Runtime.canonicalize(probe._sdk,
			_links_by_step[row.global_semantic_step].global_observation).get("sha256")
	return result
