class_name LabRunner
extends RefCounted

## One compiled experiment -> one immutable run bundle.
##
## This layer owns scientific lifecycle, not physics details. LabL0Runner owns
## the real Jolt fixtures; LabTraceStore owns append/finalize/checksum behavior.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const EventDetectorScript := preload("res://scripts/lab/event_detector.gd")
const FiniteSanitizerScript := preload("res://scripts/lab/finite_sanitizer.gd")
const GateEvaluatorScript := preload("res://scripts/lab/gate_evaluator.gd")
const L0RunnerScript := preload("res://scripts/lab/l0_runner.gd")
const MechanicsAccountantScript := preload(
	"res://scripts/lab/mechanics_accountant.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")
const ProcessLauncherScript := preload(
	"res://scripts/lab/lab_process_launcher.gd")
const PreEventRingBufferScript := preload(
	"res://scripts/lab/pre_event_ring_buffer.gd")
const ReportBuilderScript := preload("res://scripts/lab/report_builder.gd")
const RuntimeNoteScript := preload("res://scripts/lab/records/runtime_note.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")
const SourceStateGateScript := preload("res://scripts/lab/source_state_gate.gd")
const TraceReplayScript := preload("res://scripts/lab/trace_replay.gd")
const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")

const REQUIRED_ARTIFACTS := [
	"manifest.json",
	"process_metadata.json",
	"configuration.json",
	"pre_event_snapshot.jsonl",
	"frames.jsonl",
	"commands.jsonl",
	"applications.jsonl",
	"decisions.jsonl",
	"interventions.jsonl",
	"mechanics.jsonl",
	"events.jsonl",
	"runtime_notes.jsonl",
	"summary.json",
]
const OBSERVER_AB_ARTIFACTS := [
	"observer_minimal_frames.jsonl",
	"observer_full_frames.jsonl",
	"observer_contact_frames.jsonl",
]


func run(
		tree: SceneTree,
		compiled_experiment: RefCounted,
		output_root: String,
		source_identity: Dictionary = {},
		lifecycle_context: Dictionary = {}) -> Dictionary:
	if tree == null or compiled_experiment == null:
		return _failure(4, "RUNNER_INPUT_INVALID")
	if not compiled_experiment.call("assert_integrity"):
		return _failure(4, "EXPANDED_SPEC_INTEGRITY_FAILED")
	var expanded: Dictionary = compiled_experiment.call("value")
	var experiment_id := String(expanded["experiment_id"])
	var canonical_child := String(
		lifecycle_context.get("mode", "direct_development")) \
			== "reserved_child"
	if experiment_id == "L0_4_TRACE_PLAYBACK":
		return _failure(4, "TRACE_PLAYBACK_REQUIRES_REPLAY_BUNDLE")

	var original_ticks := Engine.physics_ticks_per_second
	var desired_ticks := int(expanded["physics_ticks_per_second"])
	if original_ticks != desired_ticks:
		Engine.physics_ticks_per_second = desired_ticks
		# Godot 4.7 applies a runtime tick-rate change across main-loop
		# boundaries. Do not spawn into a mixed-dt transition.
		await tree.process_frame
		await tree.process_frame
		await tree.physics_frame

	var source_probe := SourceStateGateScript.probe_repository(
		ProjectSettings.globalize_path("res://"))
	var loaded_hashes := _loaded_resource_hashes(expanded, source_identity)
	var source_gate := SourceStateGateScript.assess(
		String(source_probe.get("git_commit", "")),
		bool(source_probe.get("dirty_worktree", true)),
		loaded_hashes)
	if not canonical_child:
		source_gate = source_gate.duplicate(true)
		source_gate["pass"] = false
		source_gate["execution_mode"] = "development"
		source_gate["reproducibility"] = "direct_in_process_development_only"
		var direct_reasons: Array = source_gate.get("reasons", []).duplicate()
		direct_reasons.append("NON_CANONICAL_DIRECT_RUN")
		direct_reasons.sort()
		source_gate["reasons"] = direct_reasons
	var run_id := (
		String(lifecycle_context.get("run_id", ""))
		if canonical_child
		else ProcessLauncherScript.make_run_id(
			experiment_id, str(int(expanded["root_seed"]))))
	if canonical_child and run_id.is_empty():
		Engine.physics_ticks_per_second = original_ticks
		return _failure(4, "RESERVED_RUN_ID_MISSING")
	var resolved_configuration := _resolved_configuration(expanded)
	var resolved_configuration_sha256 := CanonicalJsonScript.sha256(
		resolved_configuration)
	var manifest := _manifest(
		run_id,
		expanded,
		compiled_experiment,
		source_identity,
		source_probe,
		source_gate,
		loaded_hashes,
		lifecycle_context,
		resolved_configuration_sha256)
	var trace = TraceStoreScript.new()
	var start_result: Dictionary
	if canonical_child:
		start_result = trace.adopt_reserved(
			String(lifecycle_context.get("partial_path", "")),
			run_id,
			String(lifecycle_context.get("token_descriptor_path", "")),
			String(lifecycle_context.get("launch_plan_path", "")),
			manifest)
	else:
		start_result = trace.start(output_root, run_id, manifest)
	if not bool(start_result.get("ok", false)):
		Engine.physics_ticks_per_second = original_ticks
		return _failure(4, String(start_result.get("code", "TRACE_START_FAILED")), start_result)

	var process_metadata: Dictionary = {}
	var metadata_result: Dictionary = {"ok": true}
	if not canonical_child:
		var observed_engine_log: Variant = _first_non_null([
			_engine_argument("--log-file"),
			_user_argument("--engine-log-path"),
		])
		process_metadata = ProcessLauncherScript.running_process_metadata(
			run_id,
			OS.get_executable_path(),
			OS.get_cmdline_args(),
			ProjectSettings.globalize_path("res://"),
			{
				"engine_log": (
					ProcessLauncherScript.captured_log(
						String(observed_engine_log),
						"godot_runtime_observed_log_path")
					if observed_engine_log != null
					else ProcessLauncherScript.unavailable_log(
						"No explicit Godot log path was observable.",
						"godot_runtime_observation")),
				"stdout": ProcessLauncherScript.unavailable_log(
					"Direct in-process run did not redirect stdout.",
					"inherited_console_not_captured"),
				"stderr": ProcessLauncherScript.unavailable_log(
					"Direct in-process run did not redirect stderr.",
					"inherited_console_not_captured"),
			},
			-1,
			Array(OS.get_cmdline_user_args()),
			"godot_runtime_observed")
		metadata_result = _write_json_artifact(
			trace.partial_path(),
			"process_metadata.json",
			process_metadata,
			"res://data/lab/schemas/process_metadata_v1.schema.json")
		if not metadata_result["ok"]:
			trace.leave_partial()
			Engine.physics_ticks_per_second = original_ticks
			return _failure(5, "PROCESS_METADATA_WRITE_FAILED", metadata_result)

	var note_0 := RuntimeNoteScript.seal(
		run_id,
		0,
		"lab_runner",
		"info",
		"RUN_STARTED",
		"Compiled experiment entered the isolated L0 runner.",
		{
			"experiment_id": experiment_id,
			"expanded_spec_sha256":
				compiled_experiment.call("expanded_spec_sha256"),
		})
	var note_result: Dictionary = trace.append_runtime_note(note_0)
	if not note_result["ok"]:
		trace.leave_partial()
		Engine.physics_ticks_per_second = original_ticks
		return _failure(5, "RUNTIME_NOTE_WRITE_FAILED", note_result)

	var pre_event_buffer = PreEventRingBufferScript.new(
		trace.partial_path().path_join("pre_event_slots"),
		maxi(desired_ticks * 2, 1),
		run_id)
	var ring_initialize: Dictionary = pre_event_buffer.initialize()
	if not ring_initialize["ok"]:
		trace.leave_partial()
		Engine.physics_ticks_per_second = original_ticks
		return _failure(5, "PRE_EVENT_RING_INITIALIZE_FAILED", ring_initialize)

	var l0 = L0RunnerScript.new()
	var observer_profile: Dictionary = expanded["observer_profile"]
	var body_parameters: Dictionary = expanded["body_parameters"]
	var fixture_parameters: Dictionary = expanded["fixture_parameters"]
	var interval_count := int(expanded["duration_ticks"])
	var scientific_result: Dictionary
	var recorded_result: Dictionary
	match experiment_id:
		"L0_0_STATIONARY_GRAVITY_OFF":
			recorded_result = await l0.run_stationary(
				tree,
				interval_count,
				observer_profile,
				trace,
				pre_event_buffer,
				body_parameters,
				fixture_parameters)
			scientific_result = recorded_result
		"L0_1_FREE_FALL":
			recorded_result = await l0.run_free_fall(
				tree,
				interval_count,
				observer_profile,
				trace,
				pre_event_buffer,
				body_parameters,
				fixture_parameters)
			scientific_result = recorded_result
		"L0_2_BALLISTIC_ZERO_G":
			if float(expanded["body_parameters"].get("gravity_scale", 0.0)) == 0.0:
				recorded_result = await l0.run_ballistic_zero_g(
					tree,
					interval_count,
					observer_profile,
					trace,
					pre_event_buffer,
					body_parameters,
					fixture_parameters)
			else:
				recorded_result = await l0.run_ballistic_gravity(
					tree,
					interval_count,
					observer_profile,
					trace,
					pre_event_buffer,
					body_parameters,
					fixture_parameters)
			scientific_result = recorded_result
		"L0_3_OBSERVER_AB":
			scientific_result = await l0.run_observer_ab(
				tree,
				interval_count,
				body_parameters,
				fixture_parameters)
			recorded_result = scientific_result["contact"]
			var observer_arms := {
				"observer_minimal_frames": scientific_result["minimal"],
				"observer_full_frames": scientific_result["full"],
				"observer_contact_frames": scientific_result["contact"],
			}
			for stream_id in observer_arms:
				for frame in observer_arms[stream_id]["frames"]:
					var arm_append: Dictionary = trace.append_observer_frame(
						stream_id, frame)
					if not arm_append["ok"]:
						recorded_result["recording_ok"] = false
			# The enabled full-contact arm is also the bundle's primary
			# trajectory, so ordinary frame-linked evidence remains usable.
			for frame in recorded_result["frames"]:
				var primary_append: Dictionary = trace.append_frame(frame)
				if not primary_append["ok"]:
					recorded_result["recording_ok"] = false
				var ring_append: Dictionary = pre_event_buffer.append(
					int(frame["frame_id"]), frame)
				if not ring_append["ok"]:
					recorded_result["recording_ok"] = false
		_:
			trace.leave_partial()
			Engine.physics_ticks_per_second = original_ticks
			return _failure(4, "EXPERIMENT_NOT_IMPLEMENTED")

	if not bool(recorded_result.get("recording_ok", true)):
		var recording_abort := _controlled_abort(
			trace,
			pre_event_buffer,
			run_id,
			"FRAME_RECORDING_FAILED",
			recorded_result,
			process_metadata,
			canonical_child)
		Engine.physics_ticks_per_second = original_ticks
		return recording_abort

	var frames: Array = recorded_result.get("frames", [])
	if (
		bool(lifecycle_context.get(
			"allow_test_fault_injection", false))
		and String(lifecycle_context.get("fault_injection", ""))
			== "force_nonfinite_runtime_after_capture"
	):
		var injected_abort := _controlled_abort(
			trace,
			pre_event_buffer,
			run_id,
			"FORCED_NONFINITE_RUNTIME_FAILURE",
			{
				"fault_source": "lab_runner_test_seam",
				"invalid_value": NAN,
				"frame_count_before_abort": frames.size(),
			},
			process_metadata,
			canonical_child)
		Engine.physics_ticks_per_second = original_ticks
		return injected_abort
	var snapshot_result: Dictionary = pre_event_buffer.materialize_snapshot(
		trace.partial_path().path_join("pre_event_snapshot.jsonl"))
	if not snapshot_result["ok"]:
		trace.leave_partial()
		Engine.physics_ticks_per_second = original_ticks
		return _failure(5, "PRE_EVENT_SNAPSHOT_FAILED", snapshot_result)
	var ring_cleanup: Dictionary = pre_event_buffer.cleanup_transient_slots()
	if not ring_cleanup["ok"]:
		trace.leave_partial()
		Engine.physics_ticks_per_second = original_ticks
		return _failure(5, "PRE_EVENT_RING_CLEANUP_FAILED", ring_cleanup)

	var transition_result := _append_transition_evidence(trace, run_id, frames)
	if not transition_result["ok"]:
		trace.leave_partial()
		Engine.physics_ticks_per_second = original_ticks
		return _failure(5, "TRANSITION_EVIDENCE_FAILED", transition_result)

	var external_work_derivation := _derive_external_work_l0(
		trace, scientific_result, frames.size())
	scientific_result["external_work_derivation"] = external_work_derivation
	if bool(external_work_derivation.get("available", false)):
		scientific_result["external_work_j"] = external_work_derivation["value_j"]

	var applied_configuration := _applied_configuration(
		expanded, recorded_result)
	if bool(lifecycle_context.get(
		"allow_test_configuration_mismatch", false)):
		applied_configuration = applied_configuration.duplicate(true)
		applied_configuration["body_parameters"]["mass_kg"] = (
			float(applied_configuration["body_parameters"].get(
				"mass_kg", 0.0)) + 1.0)
	var applied_configuration_sha256 := CanonicalJsonScript.sha256(
		applied_configuration)
	var configuration_gate := {
		"gate_id": "G0_CONFIGURATION_INTEGRITY",
		"pass": (
			# L0.3 owns three observer arms. Its primary recorded trajectory is
			# the contact arm, but configuration validity must cover minimal,
			# full-state, and full-contact arms together. Unary experiments set
			# scientific_result == recorded_result, so this is one fail-closed
			# gate for both shapes.
			bool(scientific_result.get("configuration_valid", false))
			and bool(recorded_result.get(
				"observer_contract_satisfied", true))
			and resolved_configuration_sha256
				== applied_configuration_sha256),
		"resolved_configuration_sha256":
			resolved_configuration_sha256,
		"applied_configuration_sha256":
			applied_configuration_sha256,
		"errors": scientific_result.get(
			"configuration_errors", []).duplicate(true),
		"source_artifact": "configuration.json",
	}
	scientific_result["configuration_gate"] = configuration_gate
	var observed_configuration := _observed_configuration(
		recorded_result)
	var configuration_evidence := {
		"schema": "sporespore.lab.configuration.v1",
		"run_id": run_id,
		"resolved": resolved_configuration,
		"applied": applied_configuration,
		"observed": observed_configuration,
		"resolved_configuration_sha256":
			resolved_configuration_sha256,
		"applied_configuration_sha256":
			applied_configuration_sha256,
		"observed_configuration_sha256":
			CanonicalJsonScript.sha256(observed_configuration),
		"match": resolved_configuration_sha256
			== applied_configuration_sha256,
		"configuration_valid": bool(configuration_gate["pass"]),
		"errors": scientific_result.get(
			"configuration_errors", []).duplicate(true),
	}
	if experiment_id == "L0_3_OBSERVER_AB":
		configuration_evidence["observer_arms"] = (
			_observer_ab_configuration_evidence(
				expanded, scientific_result))
	var configuration_write := _write_json_artifact(
		trace.partial_path(),
		"configuration.json",
		configuration_evidence,
		"res://data/lab/schemas/configuration_v1.schema.json")
	if not configuration_write["ok"]:
		var configuration_abort := _controlled_abort(
			trace,
			pre_event_buffer,
			run_id,
			"CONFIGURATION_EVIDENCE_WRITE_FAILED",
			configuration_write,
			process_metadata,
			canonical_child)
		Engine.physics_ticks_per_second = original_ticks
		return configuration_abort
	var gate_metrics := _gate_metrics(experiment_id, scientific_result)
	var physical_gate: Dictionary = GateEvaluatorScript.evaluate_l0(
		experiment_id, gate_metrics, expanded["gate_parameters"])
	var event_detector = EventDetectorScript.new(run_id)
	event_detector.queue(
		maxi(frames.size() - 1, 0),
		"PROMOTION_DECISION",
		{
			"physical_gate_pass": physical_gate["pass"],
			"source_state_gate_pass": source_gate["pass"],
		},
		experiment_id)
	for event in event_detector.commit_frame(maxi(frames.size() - 1, 0)):
		var event_result: Dictionary = trace.append_event(event)
		if not event_result["ok"]:
			trace.leave_partial()
			Engine.physics_ticks_per_second = original_ticks
			return _failure(5, "EVENT_WRITE_FAILED", event_result)

	var result_note := RuntimeNoteScript.seal(
		run_id,
		1,
		"lab_runner",
		"info" if bool(physical_gate["pass"]) else "warning",
		"RUN_RESULT",
		"L0 physical gate evaluation completed.",
		_result_note_evidence(experiment_id, scientific_result, physical_gate))
	var result_note_append: Dictionary = trace.append_runtime_note(result_note)
	if not result_note_append["ok"]:
		trace.leave_partial()
		Engine.physics_ticks_per_second = original_ticks
		return _failure(5, "RESULT_NOTE_WRITE_FAILED", result_note_append)

	var physical_pass := (
		bool(physical_gate["pass"])
		and bool(scientific_result.get("finite", false))
		and bool(configuration_gate["pass"]))
	var summary_metrics := _summary_metrics(
		run_id, experiment_id, scientific_result, frames.size())
	var promotion := (
		"pass"
		if physical_pass and bool(source_gate["pass"])
		else ("not_evaluated" if not bool(source_gate["pass"]) else "fail"))
	var summary := {
		"termination": "completed",
		"evidence_validity": "valid",
		"hypothesis_result": (
			("supported" if physical_pass else "contradicted")
			if bool(configuration_gate["pass"])
			else "inconclusive"),
		"promotion": promotion,
		"frame_count": frames.size(),
		"runtime_note_count": 2,
		"first_frame_id": 0 if not frames.is_empty() else null,
		"last_frame_id": frames.size() - 1 if not frames.is_empty() else null,
		"metrics": summary_metrics,
		"failure_codes": [],
		"gate_results": {
			"configuration": configuration_gate,
			"physical": physical_gate,
			"source_state": source_gate,
		},
		"completed_utc": _utc_now(),
	}
	var final_manifest := manifest.duplicate(true)
	final_manifest["finalized_utc"] = _utc_now()
	final_manifest["applied_configuration_sha256"] = (
		applied_configuration_sha256)
	if not canonical_child:
		var final_process_metadata := ProcessLauncherScript.terminal_process_metadata(
			process_metadata,
			0 if promotion == "pass" else 2,
			"promotion_pass" if promotion == "pass" else "completed_development",
			"COMPLETE",
			OS.get_process_id())
		metadata_result = _write_json_artifact(
			trace.partial_path(),
			"process_metadata.json",
			final_process_metadata,
			"res://data/lab/schemas/process_metadata_v1.schema.json")
		if not metadata_result["ok"]:
			trace.leave_partial()
			Engine.physics_ticks_per_second = original_ticks
			return _failure(5, "PROCESS_METADATA_FINALIZE_FAILED", metadata_result)

	var finalize_result: Dictionary = (
		trace.prepare_candidate(final_manifest, summary)
		if canonical_child
		else trace.finalize(final_manifest, summary))
	Engine.physics_ticks_per_second = original_ticks
	if not finalize_result["ok"]:
		return _failure(3, "BUNDLE_FINALIZATION_FAILED", finalize_result)
	if canonical_child:
		return {
			"ok": true,
			"exit_code": 0,
			"candidate_ready": true,
			"run_id": run_id,
			"experiment_id": experiment_id,
			"expanded_spec_sha256":
				compiled_experiment.call("expanded_spec_sha256"),
			"termination": "completed",
			"evidence_validity": "valid",
			"hypothesis_result": summary["hypothesis_result"],
			"promotion": promotion,
			"physical_gate": physical_gate,
			"configuration_gate": configuration_gate,
			"source_state_gate": source_gate,
			"artifacts": finalize_result["candidate_path"],
		}
	var finalized_validation: Dictionary = finalize_result["validation"]
	var validator_promotes := bool(finalized_validation.get(
		"can_promote", false))
	var summary_promotes := promotion == "pass"
	if validator_promotes != summary_promotes:
		return {
			"ok": false,
			"exit_code": 3,
			"code": "PROMOTION_GATE_DISAGREEMENT",
			"details": {
				"summary_promotion": promotion,
				"bundle_validation": finalized_validation,
			},
			"run_id": run_id,
			"artifacts": finalize_result["bundle_path"],
		}
	return {
		"ok": validator_promotes,
		"exit_code": 0 if validator_promotes else 2,
		"run_id": run_id,
		"experiment_id": experiment_id,
		"expanded_spec_sha256":
			compiled_experiment.call("expanded_spec_sha256"),
		"termination": "completed",
		"evidence_validity": "valid",
		"hypothesis_result": summary["hypothesis_result"],
		"promotion": promotion,
		"physical_gate": physical_gate,
		"configuration_gate": configuration_gate,
		"source_state_gate": source_gate,
		"artifacts": finalize_result["bundle_path"],
		"bundle_validation": finalize_result["validation"],
	}


static func replay_bundle(
		bundle_path: String,
		validation_options: Dictionary = {}) -> Dictionary:
	var replay: Dictionary = TraceReplayScript.replay_bundle(
		bundle_path, validation_options)
	if not replay.get("ok", false):
		return _failure(3, "TRACE_REPLAY_FAILED", replay)
	if int(replay.get("simulation_steps", -1)) != 0:
		return _failure(3, "TRACE_REPLAY_INVOKED_PHYSICS", replay)
	return {
		"ok": true,
		"exit_code": 0,
		"simulation_steps": 0,
		"run_id": replay["run_id"],
		"timeline": replay["timeline"],
		"event_order": replay["event_order"],
		"metrics": replay["metrics"],
		"artifact_hashes": replay["artifact_hashes"],
	}


static func _append_transition_evidence(
		trace: RefCounted,
		run_id: String,
		frames: Array) -> Dictionary:
	for index in range(maxi(frames.size() - 1, 0)):
		var ledger = CommandLedgerScript.new()
		if not ledger.begin_tick(index):
			return {"ok": false, "error": ledger.last_error}
		var envelope: Dictionary = ledger.seal({
			"run_id": run_id,
			"command_id": index,
			"source_frame_id": int(frames[index]["frame_id"]),
			"applied_transition": [
				int(frames[index]["frame_id"]),
				int(frames[index + 1]["frame_id"]),
			],
			"mode": "NONE",
		})
		var command_result: Dictionary = trace.call("append_command", envelope)
		if not command_result["ok"]:
			return command_result
		var first_body: Dictionary = frames[index]["bodies"].values()[0]
		var gravity := _vector3(first_body.get(
			"total_gravity_world", [0.0, 0.0, 0.0]))
		var mechanics: Dictionary = MechanicsAccountantScript.body_transition(
			run_id, frames[index], frames[index + 1], gravity)
		if mechanics.is_empty():
			return {"ok": false, "error": "MECHANICS_TRANSITION_INVALID"}
		var mechanics_result: Dictionary = trace.call(
			"append_mechanics", mechanics)
		if not mechanics_result["ok"]:
			return mechanics_result
	return {"ok": true, "transition_count": maxi(frames.size() - 1, 0)}


static func _manifest(
		run_id: String,
		expanded: Dictionary,
		compiled: RefCounted,
		source_identity: Dictionary,
		source_probe: Dictionary,
		source_gate: Dictionary,
		loaded_hashes: Dictionary,
		lifecycle_context: Dictionary,
		resolved_configuration_sha256: String) -> Dictionary:
	var version: Dictionary = Engine.get_version_info()
	var observer: Dictionary = expanded["observer_profile"]
	var rng_streams: Dictionary = {}
	for stream in expanded.get("random_streams", []):
		rng_streams[String(stream["stream_id"])] = {
			"seed": int(stream["seed"]),
			"seed_sha256": stream["seed_sha256"],
			"consumed": false,
			"draw_count": 0,
		}
	var fixture_path := _fixture_path(String(expanded["fixture_id"]))
	var dirty := bool(source_probe.get("dirty_worktree", true))
	var dirty_digest: Variant = null
	if dirty:
		dirty_digest = CanonicalJsonScript.sha256({
			"status_porcelain": source_probe.get("status_porcelain", ""),
		})
	return {
		"schema": "sporespore.lab.manifest.v1",
		"run_id": run_id,
		"status": "RUNNING",
		"experiment_id": expanded["experiment_id"],
		"hypothesis_id": expanded["hypothesis_id"],
		"experiment_resource_path": source_identity.get("resource_path", ""),
		"experiment_resource_sha256": source_identity.get(
			"resource_sha256",
			CanonicalJsonScript.sha256(expanded)),
		"fixture_id": expanded["fixture_id"],
		"fixture_version": expanded["fixture_version"],
		"fixture_resource_path": fixture_path,
		"fixture_resource_sha256": loaded_hashes.get(
			fixture_path, CanonicalJsonScript.sha256({"missing": fixture_path})),
		"loaded_resource_hashes": loaded_hashes,
		"schema_set": "sporespore.lab.schemas.v1",
		"recorder_version": "flight-recorder-v1",
		"expanded_spec_sha256": compiled.call("expanded_spec_sha256"),
		"resolved_configuration_sha256":
			resolved_configuration_sha256,
		"applied_configuration_sha256": null,
		"git_commit": source_probe.get("git_commit", ""),
		"dirty_worktree": dirty,
		"dirty_diff_sha256": dirty_digest,
		"execution_mode": source_gate["execution_mode"],
		"reproducibility": (
			"clean_committed_source"
			if source_gate["pass"]
			else "partial_dirty_source"),
		"godot_version": version.get("string", ""),
		"godot_commit": version.get("hash", ""),
		"physics_backend": ProjectSettings.get_setting(
			"physics/3d/physics_engine", "unknown"),
		"physics_backend_adapter": "rigid_body_integrate_forces_v1",
		"platform": "%s-%s" % [OS.get_name(), Engine.get_architecture_name()],
		"physics_ticks_per_second": int(expanded["physics_ticks_per_second"]),
		"solver_velocity_iterations": int(ProjectSettings.get_setting(
			"physics/jolt_physics_3d/simulation/velocity_steps", 20)),
		"solver_position_iterations": int(ProjectSettings.get_setting(
			"physics/jolt_physics_3d/simulation/position_steps", 4)),
		"observer_profile": observer["profile_id"],
		"observer_channel_set_sha256": observer["channel_set_sha256"],
		"observer_parity_envelope_id": (
			"L0_3_%s" % observer["profile_id"]
			if String(expanded["experiment_id"]) == "L0_3_OBSERVER_AB"
			else null),
		"contact_cap_per_body": int(observer["contact_cap_per_body"]),
		"process_isolation": (
			"outer_parent_reserved_fresh_godot_v1"
			if String(lifecycle_context.get("mode", "")) == "reserved_child"
			else "direct_in_process_development_only"),
		"body_dynamics": expanded["body_parameters"],
		"joint_dynamics": {},
		"surface_materials": {},
		"seed_root": expanded["root_seed"],
		"rng_derivation": "sporespore-lab-seed-v1-sha256-low52",
		"rng_streams": rng_streams,
		"scaffolds_allowed": expanded["allowed_scaffolds"],
		"scaffolds_forbidden": expanded["forbidden_scaffolds"],
		"expanded_parameters": expanded,
		"comparison_role": null,
		"paired_run_id": null,
		"units": "SI",
		"started_utc": _utc_now(),
		"required_artifacts": _required_artifacts(
			String(expanded["experiment_id"]),
			String(lifecycle_context.get("mode", "")) == "reserved_child"),
	}


static func _required_artifacts(
		experiment_id: String,
		canonical_child := false) -> Array:
	var artifacts := REQUIRED_ARTIFACTS.duplicate()
	if canonical_child:
		artifacts.append("launch_plan.json")
	if experiment_id == "L0_3_OBSERVER_AB":
		artifacts.append_array(OBSERVER_AB_ARTIFACTS)
	return artifacts


static func _gate_metrics(experiment_id: String, result: Dictionary) -> Dictionary:
	match experiment_id:
		"L0_0_STATIONARY_GRAVITY_OFF":
			return {
				"max_position_error_m": result.get("max_position_error_m", INF),
				"max_velocity_error_m_s": result.get("max_velocity_error_m_s", INF),
				"total_contact_count": result.get("total_contact_count", 2147483647),
				"external_work_j": result.get("external_work_j", INF),
			}
		"L0_1_FREE_FALL":
			return {
				"max_acceleration_error_m_s2":
					result.get("max_acceleration_error_m_s2", INF),
				"max_velocity_error_m_s":
					result.get("max_velocity_error_m_s", INF),
				"max_position_error_m":
					result.get("max_position_error_m", INF),
			}
		"L0_2_BALLISTIC_ZERO_G":
			return {
				"max_position_error_m":
					result.get("max_position_error_m", INF),
				"max_velocity_error_m_s":
					result.get("max_velocity_error_m_s", INF),
				"max_momentum_error_kg_m_s":
					result.get("max_momentum_error_kg_m_s", INF),
			}
		"L0_3_OBSERVER_AB":
			return {
				"max_position_delta_m":
					result.get("max_position_delta_m", INF),
				"max_velocity_delta_m_s":
					result.get("max_velocity_delta_m_s", INF),
				"max_contact_profile_position_delta_m":
					result.get("max_contact_profile_position_delta_m", INF),
				"max_contact_profile_velocity_delta_m_s":
					result.get("max_contact_profile_velocity_delta_m_s", INF),
			}
	return {}


static func _summary_metrics(
		run_id: String,
		experiment_id: String,
		result: Dictionary,
		frame_count: int) -> Array:
	var last_frame := maxi(frame_count - 1, 0)
	var values: Array = []
	var mappings: Array = []
	match experiment_id:
		"L0_0_STATIONARY_GRAVITY_OFF":
			mappings = [
				["max_position_error_m", "m", "/bodies/body_0/transform/origin"],
				["max_velocity_error_m_s", "m/s", "/bodies/body_0/linear_velocity"],
				["max_kinetic_energy_j", "J", "/bodies/body_0/linear_velocity"],
				["total_contact_count", "count", "/contacts"],
			]
			values.append(ReportBuilderScript.metric(
				"external_work_j",
				result.get("external_work_j", null),
				"J",
				"runtime_notes.jsonl",
				[0, last_frame],
				"/1/evidence/external_work_derivation/value_j",
				"zero_external_work_from_sealed_absence_v1",
				1,
				(
					"derived"
					if bool(result.get(
						"external_work_derivation", {}).get(
							"available", false))
					else "unavailable"),
				0.0))
		"L0_1_FREE_FALL", "L0_2_BALLISTIC_ZERO_G":
			mappings = [
				["max_position_error_m", "m", "/bodies/body_0/transform/origin"],
				["max_velocity_error_m_s", "m/s", "/bodies/body_0/linear_velocity"],
				["max_acceleration_error_m_s2", "m/s^2", "/bodies/body_0/linear_velocity"],
				["max_momentum_error_kg_m_s", "kg*m/s", "/bodies/body_0/linear_velocity"],
				["total_contact_count", "count", "/contacts"],
			]
		"L0_3_OBSERVER_AB":
			for comparison in [
				[
					"max_position_delta_m",
					"m",
					"observer_minimal_frames.jsonl",
					"observer_full_frames.jsonl",
					"/bodies/body_0/transform/origin",
				],
				[
					"max_velocity_delta_m_s",
					"m/s",
					"observer_minimal_frames.jsonl",
					"observer_full_frames.jsonl",
					"/bodies/body_0/linear_velocity",
				],
				[
					"max_contact_profile_position_delta_m",
					"m",
					"observer_full_frames.jsonl",
					"observer_contact_frames.jsonl",
					"/bodies/body_0/transform/origin",
				],
				[
					"max_contact_profile_velocity_delta_m_s",
					"m/s",
					"observer_full_frames.jsonl",
					"observer_contact_frames.jsonl",
					"/bodies/body_0/linear_velocity",
				],
			]:
				values.append(ReportBuilderScript.comparison_metric(
					run_id,
					String(comparison[0]),
					result.get(comparison[0], null),
					String(comparison[1]),
					String(comparison[2]),
					String(comparison[3]),
					[0, last_frame],
					String(comparison[4]),
					"max_pairwise_vec3_distance_v1",
					1,
					0.0))
			return values
	for mapping in mappings:
		values.append(ReportBuilderScript.metric(
			String(mapping[0]),
			result.get(mapping[0], null),
			String(mapping[1]),
			"frames.jsonl",
			[0, last_frame],
			String(mapping[2]),
			"max_analytic_residual" if String(mapping[0]).begins_with("max_") else "sum",
			1,
			"derived",
			0.0))
	return values


static func _result_note_evidence(
		experiment_id: String,
		result: Dictionary,
		gate: Dictionary) -> Dictionary:
	var evidence := {
		"experiment_id": experiment_id,
		"finite": result.get("finite", false),
		"gate": gate,
	}
	for key in [
		"max_position_error_m",
		"max_velocity_error_m_s",
		"max_acceleration_error_m_s2",
		"max_momentum_error_kg_m_s",
		"max_position_delta_m",
		"max_velocity_delta_m_s",
		"max_contact_profile_position_delta_m",
		"max_contact_profile_velocity_delta_m_s",
		"total_contact_count",
		"external_work_j",
	]:
		if result.has(key):
			evidence[key] = result[key]
	if (
		experiment_id == "L0_0_STATIONARY_GRAVITY_OFF"
		and result.has("external_work_derivation")
	):
		evidence["external_work_derivation"] = result["external_work_derivation"]
	return evidence


static func _derive_external_work_l0(
		trace: RefCounted,
		result: Dictionary,
		frame_count: int) -> Dictionary:
	var line_counts: Dictionary = trace.call("line_counts")
	var command_read: Dictionary = TraceStoreScript.read_jsonl(
		trace.call("partial_path").path_join("commands.jsonl"))
	var commands_are_none := bool(command_read.get("ok", false))
	var command_records: Array = command_read.get("records", [])
	commands_are_none = (
		commands_are_none
		and command_records.size() == maxi(frame_count - 1, 0))
	for envelope_value in command_records:
		var envelope: Dictionary = envelope_value
		var payload: Dictionary = envelope.get("payload", {})
		commands_are_none = (
			commands_are_none
			and String(payload.get("mode", "")) == "NONE"
			and (payload.get("joint_commands", []) as Array).is_empty()
			and (payload.get(
				"intervention_operation_ids", []) as Array).is_empty())
	var gravity := _vector3(result.get(
		"measured_gravity_world_m_s2", [INF, INF, INF]))
	var conditions := {
		"command_count": command_records.size(),
		"expected_command_count": maxi(frame_count - 1, 0),
		"all_commands_mode_none": commands_are_none,
		"application_record_count": int(line_counts.get("applications", -1)),
		"intervention_record_count": int(line_counts.get("interventions", -1)),
		"contact_record_count": int(result.get("total_contact_count", -1)),
		"measured_gravity_world_m_s2": [
			gravity.x,
			gravity.y,
			gravity.z,
		],
	}
	var available := (
		commands_are_none
		and int(conditions["application_record_count"]) == 0
		and int(conditions["intervention_record_count"]) == 0
		and int(conditions["contact_record_count"]) == 0
		and gravity.is_finite()
		and gravity.length() <= 1.0e-12)
	return {
		"available": available,
		"value_j": 0.0 if available else null,
		"method": "zero_external_work_from_sealed_absence_v1",
		"conditions": conditions,
		"sources": [
			"commands.jsonl",
			"applications.jsonl",
			"interventions.jsonl",
			"frames.jsonl",
		],
		"reason": null if available else "ZERO_WORK_PRECONDITIONS_NOT_PROVEN",
	}


static func _resolved_configuration(expanded: Dictionary) -> Dictionary:
	return _resolved_configuration_for_profile(
		expanded, expanded["observer_profile"])


static func _resolved_configuration_for_profile(
		expanded: Dictionary,
		observer: Dictionary) -> Dictionary:
	var configuration := {
		"body_parameters": expanded["body_parameters"].duplicate(true),
		"fixture_contact_cap": int(expanded[
			"fixture_parameters"].get(
				"contact_cap",
				observer["contact_cap_per_body"])),
		"observer_identity": {
			"profile_id": String(observer["profile_id"]),
			"channel_set_sha256": observer["channel_set_sha256"],
			"channel_count": (observer["channels"] as Array).size(),
			"contacts_enabled": bool(observer["contacts_enabled"]),
			"contact_cap_per_body":
				int(observer["contact_cap_per_body"]),
		},
	}
	return CanonicalJsonScript.normalize(configuration) as Dictionary


static func _applied_configuration(
		expanded: Dictionary,
		recorded_result: Dictionary) -> Dictionary:
	return _applied_configuration_for_profile(
		expanded["observer_profile"], recorded_result)


static func _applied_configuration_for_profile(
		observer: Dictionary,
		recorded_result: Dictionary) -> Dictionary:
	var applied_fixture: Dictionary = recorded_result.get(
		"applied_fixture_parameters", {})
	var configuration := {
		"body_parameters": recorded_result.get(
			"applied_body_parameters", {}).duplicate(true),
		"fixture_contact_cap": int(applied_fixture.get(
			"contact_cap", -1)),
		"observer_identity": {
			"profile_id": String(recorded_result.get(
				"observer_profile_id", "")),
			# The channel-set hash is registry identity, while the remaining
			# fields are independently observed from the live adapter.
			"channel_set_sha256": (
				observer["channel_set_sha256"]
				if String(recorded_result.get(
					"observer_profile_id", ""))
					== String(observer["profile_id"])
				else "sha256:0000000000000000000000000000000000000000000000000000000000000000"),
			"channel_count": int(recorded_result.get(
				"observer_profile_channel_count", -1)),
			"contacts_enabled": bool(recorded_result.get(
				"observer_contacts_enabled", false)),
			"contact_cap_per_body": int(recorded_result.get(
				"observer_contact_cap_per_body", -1)),
		},
	}
	return CanonicalJsonScript.normalize(configuration) as Dictionary


static func _observer_ab_configuration_evidence(
		expanded: Dictionary,
		scientific_result: Dictionary) -> Dictionary:
	var arm_profiles := {
		"minimal": "minimal_state_v1",
		"full": "full_state_v1",
		"contact": "full_contacts_v1",
	}
	var evidence: Dictionary = {}
	for arm_name_value in arm_profiles:
		var arm_name := String(arm_name_value)
		var profile: Dictionary = ObserverProfileScript.resolve(
			StringName(arm_profiles[arm_name_value]))
		var arm_result: Dictionary = scientific_result.get(arm_name, {})
		var resolved := _resolved_configuration_for_profile(
			expanded, profile)
		var applied := _applied_configuration_for_profile(
			profile, arm_result)
		var observed := _observed_configuration(arm_result)
		var resolved_sha := CanonicalJsonScript.sha256(resolved)
		var applied_sha := CanonicalJsonScript.sha256(applied)
		var observed_sha := CanonicalJsonScript.sha256(observed)
		var match := resolved_sha == applied_sha
		var arm_errors: Array = arm_result.get(
			"configuration_errors", []).duplicate(true)
		evidence[arm_name] = {
			"resolved": resolved,
			"applied": applied,
			"observed": observed,
			"resolved_configuration_sha256": resolved_sha,
			"applied_configuration_sha256": applied_sha,
			"observed_configuration_sha256": observed_sha,
			"match": match,
			"configuration_valid": (
				match
				and bool(arm_result.get(
					"configuration_valid", false))
				and bool(arm_result.get(
					"observer_contract_satisfied", false))
				and arm_errors.is_empty()),
			"errors": arm_errors,
		}
	return evidence


static func _observed_configuration(
		recorded_result: Dictionary) -> Dictionary:
	var configuration := {
		"actual_body_parameters": recorded_result.get(
			"actual_body_parameters", {}).duplicate(true),
		"actual_fixture_parameters": recorded_result.get(
			"actual_fixture_parameters", {}).duplicate(true),
		"observer_profile_id": String(recorded_result.get(
			"observer_profile_id", "")),
		"observer_adapter_id": String(recorded_result.get(
			"observer_adapter_id", "")),
		"observer_profile_channel_count": int(recorded_result.get(
			"observer_profile_channel_count", -1)),
		"observer_projected_channel_count": int(recorded_result.get(
			"observer_projected_channel_count", -1)),
		"observer_available_channel_count": int(recorded_result.get(
			"observer_available_channel_count", -1)),
		"observer_channel_availability": recorded_result.get(
			"observer_channel_availability", {}).duplicate(true),
		"observer_contract_satisfied": bool(recorded_result.get(
			"observer_contract_satisfied", false)),
		"observer_contacts_enabled": bool(recorded_result.get(
			"observer_contacts_enabled", false)),
		"observer_contact_cap_per_body": int(recorded_result.get(
			"observer_contact_cap_per_body", -1)),
	}
	return CanonicalJsonScript.normalize(configuration) as Dictionary


static func _loaded_resource_hashes(
		expanded: Dictionary,
		source_identity: Dictionary) -> Dictionary:
	var hashes: Dictionary = {}
	if source_identity.has("resource_path") and source_identity.has("resource_sha256"):
		hashes[String(source_identity["resource_path"])] = source_identity["resource_sha256"]
	for root_path in [
		"res://scripts/lab",
		"res://data/lab/schemas",
	]:
		_hash_source_tree(root_path, hashes)
	for singleton_path in [
		"res://project.godot",
		_fixture_path(String(expanded["fixture_id"])),
	]:
		if FileAccess.file_exists(singleton_path):
			hashes[singleton_path] = (
				"sha256:%s" % FileAccess.get_sha256(singleton_path))
	return hashes


static func _hash_source_tree(directory: String, hashes: Dictionary) -> void:
	var access := DirAccess.open(directory)
	if access == null:
		return
	var directories: Array[String] = []
	var files: Array[String] = []
	access.list_dir_begin()
	var name := access.get_next()
	while not name.is_empty():
		if not name.begins_with("."):
			if access.current_is_dir():
				directories.append(name)
			elif (
				name.ends_with(".gd")
				or name.ends_with(".json")
				or name.ends_with(".tres")
			):
				files.append(name)
		name = access.get_next()
	access.list_dir_end()
	directories.sort()
	files.sort()
	for file_name in files:
		var resource_path := directory.path_join(file_name)
		hashes[resource_path] = (
			"sha256:%s" % FileAccess.get_sha256(resource_path))
	for child_directory in directories:
		_hash_source_tree(directory.path_join(child_directory), hashes)


static func _fixture_path(fixture_id: String) -> String:
	match fixture_id:
		"stationary_body_v1":
			return "res://scripts/lab/rigs/stationary_body_rig.gd"
		"free_fall_body_v1":
			return "res://scripts/lab/rigs/free_fall_rig.gd"
		"ballistic_body_v1":
			return "res://scripts/lab/rigs/ballistic_rig.gd"
		"observer_ab_ballistic_v1":
			return "res://scripts/lab/l0_runner.gd"
		_:
			return "res://scripts/lab/l0_runner.gd"


static func _write_json_artifact(
		directory: String,
		name: String,
		value: Dictionary,
		schema_path: String) -> Dictionary:
	var validation := SchemaValidatorScript.validate_file(schema_path, value)
	if not validation["ok"]:
		return {
			"ok": false,
			"error": "ARTIFACT_SCHEMA_INVALID",
			"details": validation["errors"],
		}
	var path := directory.path_join(name)
	var temporary := "%s.tmp" % path
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "ARTIFACT_TEMP_OPEN_FAILED"}
	file.store_string(CanonicalJsonScript.stringify(value) + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {
			"ok": false,
			"error": "ARTIFACT_WRITE_FAILED",
			"code": write_error,
		}
	if FileAccess.file_exists(path):
		var remove_error := DirAccess.remove_absolute(path)
		if remove_error != OK:
			return {
				"ok": false,
				"error": "ARTIFACT_REPLACE_REMOVE_FAILED",
				"code": remove_error,
			}
	var rename_error := DirAccess.rename_absolute(temporary, path)
	return {
		"ok": rename_error == OK,
		"error": "" if rename_error == OK else "ARTIFACT_RENAME_FAILED",
		"code": rename_error,
	}


static func _controlled_abort(
		trace: RefCounted,
		pre_event_buffer: RefCounted,
		run_id: String,
		failure_code: String,
		raw_details: Variant,
		process_metadata: Dictionary,
		canonical_child: bool) -> Dictionary:
	var sanitized: Dictionary = FiniteSanitizerScript.sanitize(
		raw_details, failure_code)
	var line_counts: Dictionary = trace.call("line_counts")
	var frame_count := int(line_counts.get("frames", 0))
	var note_sequence := int(line_counts.get("runtime_notes", 0))
	var terminal_note := RuntimeNoteScript.seal(
		run_id,
		note_sequence,
		"lab_runner",
		"fatal",
		failure_code,
		"Run stopped at the controlled-abort boundary; invalid values were replaced by null.",
		{
			"sanitized_details": sanitized["value"],
			"availability": sanitized["availability"],
			"failures": sanitized["failures"],
			"no_post_failure_applications": true,
		},
		frame_count - 1 if frame_count > 0 else null)
	var note_result: Dictionary = trace.call(
		"append_runtime_note", terminal_note)
	var snapshot_result: Dictionary = {
		"ok": false,
		"error": "PRE_EVENT_BUFFER_UNAVAILABLE",
	}
	if pre_event_buffer != null and frame_count > 0:
		var snapshot_path: String = trace.call(
			"partial_path").path_join("pre_event_snapshot.jsonl")
		var existing_snapshot: Dictionary = (
			TraceStoreScript.read_jsonl(snapshot_path)
			if FileAccess.file_exists(snapshot_path)
			else {"ok": false, "records": []})
		if (
			bool(existing_snapshot.get("ok", false))
			and not (existing_snapshot.get("records", []) as Array).is_empty()
		):
			snapshot_result = {
				"ok": true,
				"path": snapshot_path,
				"existing": true,
				"entry_count":
					(existing_snapshot["records"] as Array).size(),
			}
		else:
			snapshot_result = pre_event_buffer.call(
				"materialize_snapshot", snapshot_path)
		if bool(snapshot_result.get("ok", false)):
			var cleanup_result: Dictionary = pre_event_buffer.call(
				"cleanup_transient_slots")
			if not bool(cleanup_result.get("ok", false)):
				snapshot_result = snapshot_result.duplicate(true)
				snapshot_result["ok"] = false
				snapshot_result["cleanup_error"] = cleanup_result
	var metadata_result: Dictionary = {"ok": true}
	if not canonical_child and not process_metadata.is_empty():
		var terminal_metadata := ProcessLauncherScript.terminal_process_metadata(
			process_metadata,
			5,
			"controlled_abort",
			"ABORTED",
			OS.get_process_id())
		metadata_result = _write_json_artifact(
			trace.call("partial_path"),
			"process_metadata.json",
			terminal_metadata,
			"res://data/lab/schemas/process_metadata_v1.schema.json")
	var partial_result: Dictionary = trace.call("leave_partial")
	return {
		"ok": false,
		"exit_code": 5,
		"code": failure_code,
		"details": {
			"sanitized_details": sanitized["value"],
			"availability": sanitized["availability"],
			"failures": sanitized["failures"],
			"terminal_note": note_result,
			"pre_event_snapshot": snapshot_result,
			"process_metadata": metadata_result,
		},
		"run_id": run_id,
		"artifacts": partial_result.get(
			"partial_path", trace.call("partial_path")),
		"termination": "aborted",
		"evidence_validity": "partial",
		"hypothesis_result": "inconclusive",
		"promotion": "not_evaluated",
	}


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var array: Array = value
	return Vector3(float(array[0]), float(array[1]), float(array[2]))


static func _engine_argument(name: String) -> Variant:
	var args := OS.get_cmdline_args()
	for index in range(args.size() - 1):
		if String(args[index]) == name:
			return String(args[index + 1])
	return null


static func _user_argument(name: String) -> Variant:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		if String(args[index]) == name:
			return String(args[index + 1])
	return null


static func _first_non_null(values: Array) -> Variant:
	for value in values:
		if value != null:
			return value
	return null


static func _utc_now() -> String:
	return Time.get_datetime_string_from_system(true, false) + "Z"


static func _failure(
		exit_code: int,
		code: String,
		details: Variant = null) -> Dictionary:
	return {
		"ok": false,
		"exit_code": exit_code,
		"code": code,
		"details": details,
	}
