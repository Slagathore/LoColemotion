extends SceneTree

const SchemaValidatorScript := preload(
	"res://scripts/lab/schema_validator.gd")
const ExecutionReceiptSinkScript := preload(
	"res://scripts/lab/records/execution_receipt.gd")
const DecisionRecordScript := preload(
	"res://scripts/lab/records/decision_record.gd")
const InterventionRecordScript := preload(
	"res://scripts/lab/records/intervention_record.gd")
const EventDetectorScript := preload(
	"res://scripts/lab/event_detector.gd")
const ComparisonRunnerScript := preload(
	"res://scripts/lab/comparison_runner.gd")
const CampaignRunnerScript := preload(
	"res://scripts/lab/campaign_runner.gd")
const PreEventRingBufferScript := preload(
	"res://scripts/lab/pre_event_ring_buffer.gd")

const HASH := "sha256:0000000000000000000000000000000000000000000000000000000000000000"
const OWNED_SCHEMAS := [
	"application_v1",
	"decision_v1",
	"intervention_v1",
	"event_v1",
	"comparison_v1",
	"campaign_manifest_v1",
	"child_run_index_v1",
	"matrix_summary_v1",
	"pre_event_entry_v1",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Strict lab-owned record schema tests ===")
	_test_schema_object_boundaries_are_closed()
	_test_application_contract()
	_test_decision_contract()
	_test_intervention_contract()
	_test_event_contract()
	_test_comparison_contract()
	_test_campaign_manifest_contract()
	_test_child_run_index_contract()
	_test_matrix_summary_contract()
	_test_pre_event_entry_contract()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_schema_object_boundaries_are_closed() -> void:
	print("- every declared static object boundary rejects unknown fields")
	for schema_name in OWNED_SCHEMAS:
		var loaded := SchemaValidatorScript.load_schema(_schema_path(schema_name))
		_check(bool(loaded["ok"]), "%s schema loads" % schema_name)
		if not bool(loaded["ok"]):
			continue
		var open_paths: Array[String] = []
		_find_open_object_schemas(loaded["schema"], "#", open_paths)
		_check(
			open_paths.is_empty(),
			"%s has no open declared object schemas%s" % [
				schema_name,
				"" if open_paths.is_empty() else ": %s" % str(open_paths),
			])


func _test_application_contract() -> void:
	print("- application receipts discriminate source, API, arguments, and disposition")
	var sink = ExecutionReceiptSinkScript.new("schema_application")
	var receipt: Dictionary = sink.append_call_returned({
		"source_kind": "command",
		"source_record_id": "command:0",
		"source_payload_sha256": HASH,
		"operation_id": "noop_0",
		"executor_call_ordinal": sink.next_call_ordinal(),
		"api": "lab.synthetic_noop",
		"target_body_id": "body_0",
		"arguments": {"value": 7.0},
	})
	_accept("application_v1", receipt, "builder-produced command noop receipt validates")

	var torque: Dictionary = sink.append_call_failed({
		"source_kind": "command",
		"source_record_id": "command:1",
		"source_payload_sha256": HASH,
		"operation_id": "torque_0",
		"executor_call_ordinal": sink.next_call_ordinal(),
		"api": "RigidBody3D.apply_torque",
		"target_body_id": "body_0",
		"arguments": {"torque_world_nm": Vector3(1.0, 2.0, 3.0)},
	}, "CONTROLLED_EXECUTOR_FAILURE")
	_accept(
		"application_v1",
		torque,
		"receipt sealer normalizes a torque Vector3 to an exact JSON vec3")
	_check(
		torque["arguments"]["torque_world_nm"] is Array,
		"receipt contains JSON-ready arrays, not engine math variants")
	var intervention_sink = ExecutionReceiptSinkScript.new("schema_application")
	var impulse: Dictionary = intervention_sink.append_call_returned({
		"source_kind": "intervention",
		"source_record_id": "intervention:push_0",
		"source_payload_sha256": HASH,
		"operation_id": "push_0",
		"executor_call_ordinal": intervention_sink.next_call_ordinal(),
		"api": "RigidBody3D.apply_central_impulse",
		"target_body_id": "body_0",
		"arguments": {"linear_impulse_world_n_s": Vector3(2.0, 0.0, 0.0)},
	})
	_accept(
		"application_v1",
		impulse,
		"builder-produced intervention impulse receipt validates")
	_check(
		impulse["arguments"]["linear_impulse_world_n_s"] is Array,
		"impulse receipt contains an exact JSON vec3")

	var unknown := receipt.duplicate(true)
	unknown["unsealed_result"] = true
	_reject("application_v1", unknown, "unknown top-level receipt field is rejected")

	var unknown_argument := receipt.duplicate(true)
	unknown_argument["arguments"]["mystery"] = 1
	_reject(
		"application_v1",
		unknown_argument,
		"unknown nested executor argument is rejected")

	var wrong_source := torque.duplicate(true)
	wrong_source["source_kind"] = "intervention"
	wrong_source["source_record_id"] = "intervention:torque_0"
	_reject(
		"application_v1",
		wrong_source,
		"torque receipt cannot masquerade as an intervention receipt")

	var short_vector := torque.duplicate(true)
	short_vector["arguments"]["torque_world_nm"] = [1.0, 2.0]
	_reject("application_v1", short_vector, "two-component torque vector is rejected")

	var mismatched_disposition := receipt.duplicate(true)
	mismatched_disposition["failure_code"] = "FAILURE_ON_RETURN"
	_reject(
		"application_v1",
		mismatched_disposition,
		"successful call cannot carry a failure code")

	var failed_without_code := torque.duplicate(true)
	failed_without_code["failure_code"] = null
	_reject(
		"application_v1",
		failed_without_code,
		"failed call must carry a nonempty failure code")


func _test_decision_contract() -> void:
	print("- decisions close detector, strategy, wrench, allocator, and anti-windup objects")
	var decision: Dictionary = DecisionRecordScript.seal({
		"run_id": "schema_decision",
		"decision_id": 4,
		"source_frame_id": 4,
		"supervisor_mode": "BRACE",
		"detector": {
			"static_margin_m": 0.019,
			"static_enter_threshold_m": 0.035,
			"capture_margin_m": -0.011,
			"time_to_boundary_s": 0.14,
			"urgency_terms": {"static": 0.46, "capture": 0.72},
		},
		"candidate_strategies": [
			{"id": "redistribute", "feasible": false, "reason": "WRENCH_OUTSIDE_CONE"},
			{"id": "catch_left", "feasible": true, "score": 0.81},
		],
		"selected_strategy": "catch_left",
		"desired_wrench": {
			"reference_point_world_m": Vector3(0.0, 0.61, 0.0),
			"force_world_n": Vector3(91.0, 111.0, 0.0),
			"moment_world_nm": Vector3(0.0, 0.0, -13.2),
		},
		"allocator": {
			"feasible": true,
			"arithmetic_residual_norm": 0.00002,
			"predicted_feasibility_residual_norm": 0.0,
		},
		"anti_windup": {"active": false, "reason": null},
		"availability": {},
	})
	_accept("decision_v1", decision, "builder-produced full decision validates")
	_check(
		decision["desired_wrench"]["force_world_n"] is Array,
		"decision sealer normalizes desired-wrench vectors")

	var unknown_detector := decision.duplicate(true)
	unknown_detector["detector"]["magic_stability"] = 1.0
	_reject(
		"decision_v1",
		unknown_detector,
		"undeclared detector term is rejected")

	var short_wrench := decision.duplicate(true)
	short_wrench["desired_wrench"]["force_world_n"] = [1.0, 2.0]
	_reject("decision_v1", short_wrench, "malformed desired-wrench vector is rejected")

	var incomplete_candidate := decision.duplicate(true)
	incomplete_candidate["candidate_strategies"][0].erase("feasible")
	_reject(
		"decision_v1",
		incomplete_candidate,
		"strategy without a feasibility result is rejected")

	var unknown_allocator := decision.duplicate(true)
	unknown_allocator["allocator"]["solver_said_ok"] = true
	_reject(
		"decision_v1",
		unknown_allocator,
		"undeclared allocator conclusion is rejected")

	var unknown_availability := decision.duplicate(true)
	unknown_availability["availability"]["secret_channel"] = {
		"status": "measured",
		"reason": null,
	}
	_reject(
		"decision_v1",
		unknown_availability,
		"unknown decision availability channel is rejected")


func _test_intervention_contract() -> void:
	print("- intervention envelopes distinguish current executable operation shapes")
	var noop: Dictionary = InterventionRecordScript.seal({
		"run_id": "schema_intervention",
		"record_kind": "planned_operation",
		"operation_id": "noop_0",
		"source_frame_id": 0,
		"applied_transition": [0, 1],
		"source": "fixture.contract_test",
		"type": "synthetic_noop",
		"planned_api": "lab.synthetic_noop",
		"target_body_id": "none",
		"allowed": true,
		"experiment_phase": "MEASURE",
		"availability": {},
	})
	_accept("intervention_v1", noop, "builder-produced synthetic intervention validates")

	var impulse: Dictionary = InterventionRecordScript.seal({
		"run_id": "schema_intervention",
		"record_kind": "planned_operation",
		"operation_id": "push_0",
		"source_frame_id": 3,
		"applied_transition": [3, 4],
		"source": "fixture.disturbance",
		"type": "central_impulse",
		"planned_api": "RigidBody3D.apply_central_impulse",
		"target_body_id": "body_0",
		"point_world_m": null,
		"force_world_n": null,
		"torque_world_nm": null,
		"linear_impulse_world_n_s": Vector3(2.0, 0.0, 0.0),
		"angular_impulse_world_n_m_s": Vector3.ZERO,
		"signed_work_j": null,
		"work_quality": "unavailable",
		"allowed": true,
		"experiment_phase": "MEASURE",
		"availability": {
			"/signed_work_j": {
				"status": "unavailable",
				"reason": "POST_IMPULSE_ENDPOINT_NOT_CAPTURED",
				"source": "fixture.disturbance",
			},
		},
	})
	_accept("intervention_v1", impulse, "builder-produced central impulse validates")
	_check(
		impulse["payload"]["linear_impulse_world_n_s"] is Array,
		"intervention sealer normalizes impulse vectors")

	var unknown := noop.duplicate(true)
	unknown["payload"]["silent_teleport"] = true
	_reject("intervention_v1", unknown, "unknown intervention mutation is rejected")

	var mismatched_api := impulse.duplicate(true)
	mismatched_api["payload"]["planned_api"] = "lab.synthetic_noop"
	_reject(
		"intervention_v1",
		mismatched_api,
		"central-impulse type cannot name the noop API")

	var short_vector := impulse.duplicate(true)
	short_vector["payload"]["linear_impulse_world_n_s"] = [2.0, 0.0]
	_reject("intervention_v1", short_vector, "two-component impulse is rejected")

	var observed_not_implemented := impulse.duplicate(true)
	observed_not_implemented["payload"]["record_kind"] = "observed_constraint_reaction"
	_reject(
		"intervention_v1",
		observed_not_implemented,
		"unimplemented observed-reaction shape cannot enter the planned-operation stream")


func _test_event_contract() -> void:
	print("- event records close current evidence and retain deterministic ordering fields")
	var detector = EventDetectorScript.new("schema_event")
	_check(
		detector.queue(
			8,
			"PROMOTION_DECISION",
			{"physical_gate_pass": true, "source_state_gate_pass": false},
			"L0_0_STATIONARY_GRAVITY_OFF"),
		"promotion event queues")
	var promotion: Dictionary = detector.commit_frame(8)[0]
	_accept("event_v1", promotion, "current promotion-decision event validates")

	var unknown := promotion.duplicate(true)
	unknown["wall_clock_guess"] = 3
	_reject("event_v1", unknown, "unknown event field is rejected")

	var unknown_evidence := promotion.duplicate(true)
	unknown_evidence["evidence"]["looks_stable"] = true
	_reject("event_v1", unknown_evidence, "undeclared promotion evidence is rejected")

	var missing_ordinal := promotion.duplicate(true)
	missing_ordinal.erase("detector_local_ordinal")
	_reject(
		"event_v1",
		missing_ordinal,
		"event without deterministic detector ordinal is rejected")

	var wrong_family := promotion.duplicate(true)
	wrong_family["event"] = "CONTACT_BEGIN"
	_reject(
		"event_v1",
		wrong_family,
		"promotion-only evidence cannot be relabeled as a contact event")

	var contact_detector = EventDetectorScript.new("schema_event")
	contact_detector.queue(9, "CONTACT_BEGIN", {}, "body_0")
	_accept(
		"event_v1",
		contact_detector.commit_frame(9)[0],
		"registered event without a versioned evidence payload validates only when empty")


func _test_comparison_contract() -> void:
	print("- paired comparisons close declarations and couple validity to conclusions")
	var control := {
		"root_seed": 42,
		"controller_parameters": {"brace_enabled": false},
	}
	var intervention := control.duplicate(true)
	intervention["controller_parameters"]["brace_enabled"] = true
	var comparison: Dictionary = ComparisonRunnerScript.compare_specs(
		"cmp_brace",
		"control_run",
		"intervention_run",
		control,
		intervention,
		"/controller_parameters/brace_enabled")
	_accept("comparison_v1", comparison, "builder-produced valid comparison validates")

	intervention["root_seed"] = 99
	var invalid_comparison: Dictionary = ComparisonRunnerScript.compare_specs(
		"cmp_bad",
		"control_run",
		"intervention_run",
		control,
		intervention,
		"/controller_parameters/brace_enabled")
	_accept(
		"comparison_v1",
		invalid_comparison,
		"builder-produced undeclared-difference conclusion validates")

	var unknown_declaration := comparison.duplicate(true)
	unknown_declaration["declared_independent_variable"]["display_name"] = "brace"
	_reject(
		"comparison_v1",
		unknown_declaration,
		"unknown independent-variable declaration field is rejected")

	var bad_pointer := comparison.duplicate(true)
	bad_pointer["declared_independent_variable"]["path"] = "controller/brace"
	_reject("comparison_v1", bad_pointer, "non-pointer declaration path is rejected")

	var contradictory := comparison.duplicate(true)
	contradictory["conclusion"] = "undeclared_difference"
	_reject(
		"comparison_v1",
		contradictory,
		"valid evidence cannot claim an undeclared difference")


func _test_campaign_manifest_contract() -> void:
	print("- campaign manifests close factor declarations and child references")
	var manifest := {
		"schema": "sporespore.lab.campaign_manifest.v1",
		"campaign_id": "campaign_0",
		"status": "RUNNING",
		"campaign_kind": "sweep",
		"schema_set": "sporespore.lab.schemas.v1",
		"declared_factors": [{
			"factor_id": "gravity_scale",
			"path": "/body_parameters/gravity_scale",
			"role": "treatment",
			"levels": [0.0, 0.5, 1.0],
			"allowed_interactions": [],
		}],
		"child_run_ids": ["child_0", "child_1"],
		"source_revision": "dirty-development-source",
		"nuisance_fingerprint_sha256": HASH,
	}
	_accept("campaign_manifest_v1", manifest, "strict campaign manifest validates")

	var unknown_factor := manifest.duplicate(true)
	unknown_factor["declared_factors"][0]["magic_level"] = 7
	_reject(
		"campaign_manifest_v1",
		unknown_factor,
		"unknown factor declaration field is rejected")

	var missing_path := manifest.duplicate(true)
	missing_path["declared_factors"][0].erase("path")
	_reject(
		"campaign_manifest_v1",
		missing_path,
		"factor without a spec pointer is rejected")

	var structured_level := manifest.duplicate(true)
	structured_level["declared_factors"][0]["levels"] = [{"hidden": true}]
	_reject(
		"campaign_manifest_v1",
		structured_level,
		"undeclared structured factor level is rejected")

	var duplicate_children := manifest.duplicate(true)
	duplicate_children["child_run_ids"] = ["child_0", "child_0"]
	_reject(
		"campaign_manifest_v1",
		duplicate_children,
		"duplicate child run reference is rejected")


func _test_child_run_index_contract() -> void:
	print("- child-run index entries are exact sealed references")
	var index := {
		"schema": "sporespore.lab.child_run_index.v1",
		"campaign_id": "campaign_0",
		"children": [{
			"cell_id": "cell_0",
			"run_id": "child_0",
			"manifest_sha256": HASH,
			"policy": "required_feasible",
		}],
	}
	_accept("child_run_index_v1", index, "strict child-run index validates")

	var unknown_child := index.duplicate(true)
	unknown_child["children"][0]["trusted"] = true
	_reject("child_run_index_v1", unknown_child, "unknown child trust flag is rejected")

	var missing_policy := index.duplicate(true)
	missing_policy["children"][0].erase("policy")
	_reject(
		"child_run_index_v1",
		missing_policy,
		"child without preregistered policy is rejected")

	var bad_hash := index.duplicate(true)
	bad_hash["children"][0]["manifest_sha256"] = "sha256:not-a-hash"
	_reject("child_run_index_v1", bad_hash, "malformed child manifest hash is rejected")

	var unknown_root := index.duplicate(true)
	unknown_root["best_child"] = "child_0"
	_reject("child_run_index_v1", unknown_root, "unknown child-index field is rejected")


func _test_matrix_summary_contract() -> void:
	print("- matrix summaries contain only current cell result fields")
	var declared := [{
		"cell_id": "cell_0",
		"policy": "required_feasible",
	}]
	var observed := [{
		"cell_id": "cell_0",
		"status": "pass",
		"policy": "required_feasible",
	}]
	var summary: Dictionary = CampaignRunnerScript.matrix_summary(
		"campaign_0", declared, observed)
	_accept("matrix_summary_v1", summary, "builder-produced matrix summary validates")

	var missing: Dictionary = CampaignRunnerScript.matrix_summary(
		"campaign_0",
		declared + [{"cell_id": "cell_1", "policy": "exploratory"}],
		observed)
	_accept(
		"matrix_summary_v1",
		missing,
		"builder-produced missing-cell summary remains structurally valid")

	var unknown_cell := summary.duplicate(true)
	unknown_cell["cells"][0]["unsealed_score"] = 99.0
	_reject("matrix_summary_v1", unknown_cell, "unknown matrix-cell field is rejected")

	var missing_status := summary.duplicate(true)
	missing_status["cells"][0].erase("status")
	_reject("matrix_summary_v1", missing_status, "cell without status is rejected")

	var partial := summary.duplicate(true)
	partial["evidence_validity"] = "partial"
	_reject(
		"matrix_summary_v1",
		partial,
		"unimplemented partial-validity state is rejected")


func _test_pre_event_entry_contract() -> void:
	print("- pre-event entries carry one exact current L0 core frame")
	var directory := OS.get_temp_dir().path_join(
		"sporespore_schema_pre_event_%d" % OS.get_process_id())
	_remove_tree(directory)
	var buffer = PreEventRingBufferScript.new(directory, 2, "schema_pre_event")
	_check(bool(buffer.initialize()["ok"]), "pre-event fixture directory initializes")
	var appended: Dictionary = buffer.append(0, _l0_core_frame(0))
	_check(bool(appended["ok"]), "strict L0 core frame reaches ring buffer")
	if not bool(appended["ok"]):
		_remove_tree(directory)
		return
	var entry: Dictionary = appended["entry"]
	_accept("pre_event_entry_v1", entry, "builder-produced pre-event entry validates")

	var unknown_entry := entry.duplicate(true)
	unknown_entry["recovered_by_guess"] = true
	_reject(
		"pre_event_entry_v1",
		unknown_entry,
		"unknown pre-event metadata is rejected")

	var unknown_payload := entry.duplicate(true)
	unknown_payload["payload"]["marker"] = "not-a-frame"
	_reject(
		"pre_event_entry_v1",
		unknown_payload,
		"arbitrary payload cannot masquerade as an L0 pre-event frame")

	var bad_origin := entry.duplicate(true)
	bad_origin["payload"]["bodies"]["body_0"]["transform"]["origin"] = [0.0, 1.0]
	_reject(
		"pre_event_entry_v1",
		bad_origin,
		"malformed nested body vector is rejected")

	var unknown_availability := entry.duplicate(true)
	unknown_availability["payload"]["availability"]["fields"]["secret_sensor"] = {
		"status": "measured",
		"reason": null,
		"source": "unknown",
	}
	_reject(
		"pre_event_entry_v1",
		unknown_availability,
		"undeclared pre-event sensor channel is rejected")
	_remove_tree(directory)


func _accept(schema_name: String, value: Variant, label: String) -> void:
	var result := SchemaValidatorScript.validate_file(
		_schema_path(schema_name), value)
	if not bool(result["ok"]):
		printerr(SchemaValidatorScript.format_errors(result))
	_check(bool(result["ok"]), label)


func _reject(schema_name: String, value: Variant, label: String) -> void:
	var result := SchemaValidatorScript.validate_file(
		_schema_path(schema_name), value)
	_check(not bool(result["ok"]), label)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


static func _schema_path(schema_name: String) -> String:
	return "res://data/lab/schemas/%s.schema.json" % schema_name


static func _find_open_object_schemas(
		value: Variant,
		path: String,
		result: Array[String]) -> void:
	if value is Array:
		for index in value.size():
			_find_open_object_schemas(value[index], "%s/%d" % [path, index], result)
		return
	if not value is Dictionary:
		return
	var node: Dictionary = value
	var declared_type: Variant = node.get("type")
	if (
		typeof(declared_type) == TYPE_STRING
		and String(declared_type) == "object"
		and node.get("additionalProperties", null) != false
	):
		result.append(path)
	for key in node:
		_find_open_object_schemas(node[key], "%s/%s" % [path, String(key)], result)


static func _l0_core_frame(frame_id: int) -> Dictionary:
	var time_s := float(frame_id) / 60.0
	return {
		"schema_version": "frame_v1",
		"frame_id": frame_id,
		"physics_step_id": frame_id,
		"capture_epoch": frame_id,
		"physics_time_s": time_s,
		"sample_phase": "integrate_callback",
		"experiment_phase": "MEASURE",
		"release_frame_id": 0,
		"bodies": {
			"body_0": {
				"physics_step_id": frame_id,
				"body_callback_sequence": frame_id + 1,
				"capture_epoch": frame_id,
				"sample_phase": "integrate_callback",
				"body_id": "body_0",
				"part_index": 0,
				"transform": {
					"basis": [
						[1.0, 0.0, 0.0],
						[0.0, 1.0, 0.0],
						[0.0, 0.0, 1.0],
					],
					"origin": [0.25, 1.75, -0.5],
				},
				"center_of_mass_world": [0.25, 1.75, -0.5],
				"linear_velocity": [0.0, 0.0, 0.0],
				"angular_velocity": [0.0, 0.0, 0.0],
				"mass_kg": 2.0,
				"inverse_inertia_tensor_world": {
					"x": [1.0, 0.0, 0.0],
					"y": [0.0, 1.0, 0.0],
					"z": [0.0, 0.0, 1.0],
				},
				"sleeping": false,
				"finite": true,
				"step_s": 1.0 / 60.0,
				"total_gravity_world": [0.0, 0.0, 0.0],
				"com_frame_oracle_error_m": 0.0,
				"observer_profile_id": "full_contacts_v1",
				"observer_adapter_id": "rigid_body_integrate_forces_v1",
			},
		},
		"contacts": [],
		"whole_body": {
			"frame_id": frame_id,
			"physics_step_id": frame_id,
			"capture_epoch": frame_id,
			"body_ids": ["body_0"],
			"total_mass_kg": 2.0,
			"center_of_mass_world_m": [0.25, 1.75, -0.5],
			"linear_momentum_world_n_s": [0.0, 0.0, 0.0],
			"center_of_mass_velocity_world_m_s": [0.0, 0.0, 0.0],
			"angular_momentum_about_com_world_n_m_s": null,
			"availability": {
				"/angular_momentum_about_com_world_n_m_s": {
					"status": "unavailable",
					"reason": "BR1_INERTIA_CHANNEL_NOT_CERTIFIED",
					"source": "whole_body_state_v1",
				},
			},
			"finite": true,
		},
		"availability": {
			"required_body_ids": ["body_0"],
			"captured_body_count": 1,
			"contact_count": 0,
			"invalid_reasons": [],
			"fields": {
				"body:body_0": {
					"status": "measured",
					"reason": null,
					"source": "rigid_body_integrate_forces_v1",
				},
				"contacts": {
					"status": "measured",
					"reason": null,
					"source": "rigid_body_integrate_forces_v1",
				},
				"whole_body": {
					"status": "derived",
					"reason": null,
					"source": "whole_body_state_v1",
				},
				"frame": {
					"status": "measured",
					"reason": null,
					"source": "sensor_frame_builder_v1",
				},
			},
		},
		"finite": true,
	}


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var access := DirAccess.open(path)
	if access == null:
		return
	for child in access.get_directories():
		_remove_tree(path.path_join(child))
	for file_name in access.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
