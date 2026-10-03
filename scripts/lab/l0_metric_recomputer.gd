class_name LabL0MetricRecomputer
extends RefCounted

## Independent semantic verifier for unary Level-0 metrics.
##
## Input records must already have crossed the bundle checksum, JSON, and
## schema gates. This verifier deliberately does not trust summary values,
## runtime-note conclusions, or runner-side analytic dictionaries: it rebuilds
## every currently emitted unary L0.0/L0.1/L0.2 metric from the sealed streams.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const GateEvaluatorScript := preload("res://scripts/lab/gate_evaluator.gd")

const RECOMPUTER_ID := "sporespore.lab.l0_unary_metric_recomputer.v1"
const ANALYTIC_CONTRACT_VERSION := 1
const VALUE_ABSOLUTE_TOLERANCE := 1.0e-7
const GATE_NUMERIC_ABSOLUTE_TOLERANCE := 1.0e-7
const GRAVITY_ZERO_TOLERANCE_M_S2 := 1.0e-12

const _CONTRACTS := {
	"L0_0_STATIONARY_GRAVITY_OFF": {
		"contract_id": "sporespore.lab.l0_0.unary_metrics.v1",
		"analytic_model": "stationary_from_first_direct_state_v1",
		"gate_metric_ids": [
			"max_position_error_m",
			"max_velocity_error_m_s",
			"total_contact_count",
			"external_work_j",
		],
		"metrics": {
			"external_work_j": {
				"unit": "J",
				"source_stream": "runtime_notes.jsonl",
				"source_field":
					"/1/evidence/external_work_derivation/value_j",
				"aggregation_id":
					"zero_external_work_from_sealed_absence_v1",
			},
			"max_position_error_m": {
				"unit": "m",
				"source_stream": "frames.jsonl",
				"source_field": "/bodies/body_0/transform/origin",
				"aggregation_id": "max_analytic_residual",
			},
			"max_velocity_error_m_s": {
				"unit": "m/s",
				"source_stream": "frames.jsonl",
				"source_field": "/bodies/body_0/linear_velocity",
				"aggregation_id": "max_analytic_residual",
			},
			"max_kinetic_energy_j": {
				"unit": "J",
				"source_stream": "frames.jsonl",
				"source_field": "/bodies/body_0/linear_velocity",
				"aggregation_id": "max_analytic_residual",
			},
			"total_contact_count": {
				"unit": "count",
				"source_stream": "frames.jsonl",
				"source_field": "/contacts",
				"aggregation_id": "sum",
			},
		},
	},
	"L0_1_FREE_FALL": {
		"contract_id": "sporespore.lab.l0_1.unary_metrics.v1",
		"analytic_model": "constant_gravity_from_first_direct_state_v1",
		"gate_metric_ids": [
			"max_acceleration_error_m_s2",
			"max_velocity_error_m_s",
			"max_position_error_m",
		],
		"metrics": {
			"max_position_error_m": {
				"unit": "m",
				"source_stream": "frames.jsonl",
				"source_field": "/bodies/body_0/transform/origin",
				"aggregation_id": "max_analytic_residual",
			},
			"max_velocity_error_m_s": {
				"unit": "m/s",
				"source_stream": "frames.jsonl",
				"source_field": "/bodies/body_0/linear_velocity",
				"aggregation_id": "max_analytic_residual",
			},
			"max_acceleration_error_m_s2": {
				"unit": "m/s^2",
				"source_stream": "frames.jsonl",
				"source_field": "/bodies/body_0/linear_velocity",
				"aggregation_id": "max_analytic_residual",
			},
			"max_momentum_error_kg_m_s": {
				"unit": "kg*m/s",
				"source_stream": "frames.jsonl",
				"source_field": "/bodies/body_0/linear_velocity",
				"aggregation_id": "max_analytic_residual",
			},
			"total_contact_count": {
				"unit": "count",
				"source_stream": "frames.jsonl",
				"source_field": "/contacts",
				"aggregation_id": "sum",
			},
		},
	},
	"L0_2_BALLISTIC_ZERO_G": {
		"contract_id": "sporespore.lab.l0_2.unary_metrics.v1",
		"analytic_model":
			"manifest_gravity_scale_selected_ballistic_v1",
		"gate_metric_ids": [
			"max_position_error_m",
			"max_velocity_error_m_s",
			"max_momentum_error_kg_m_s",
		],
		"metrics": {
			"max_position_error_m": {
				"unit": "m",
				"source_stream": "frames.jsonl",
				"source_field": "/bodies/body_0/transform/origin",
				"aggregation_id": "max_analytic_residual",
			},
			"max_velocity_error_m_s": {
				"unit": "m/s",
				"source_stream": "frames.jsonl",
				"source_field": "/bodies/body_0/linear_velocity",
				"aggregation_id": "max_analytic_residual",
			},
			"max_acceleration_error_m_s2": {
				"unit": "m/s^2",
				"source_stream": "frames.jsonl",
				"source_field": "/bodies/body_0/linear_velocity",
				"aggregation_id": "max_analytic_residual",
			},
			"max_momentum_error_kg_m_s": {
				"unit": "kg*m/s",
				"source_stream": "frames.jsonl",
				"source_field": "/bodies/body_0/linear_velocity",
				"aggregation_id": "max_analytic_residual",
			},
			"total_contact_count": {
				"unit": "count",
				"source_stream": "frames.jsonl",
				"source_field": "/contacts",
				"aggregation_id": "sum",
			},
		},
	},
}


static func supports_experiment(experiment_id: String) -> bool:
	return _CONTRACTS.has(experiment_id)


static func verify(
		manifest: Dictionary,
		summary: Dictionary,
		streams: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var experiment_id := String(manifest.get("experiment_id", ""))
	if not _CONTRACTS.has(experiment_id):
		_error(
			errors,
			"UNSUPPORTED_UNARY_METRIC_CONTRACT",
			"/manifest.json/experiment_id",
			"No L0 unary recomputation contract exists for this experiment")
		return _result(experiment_id, {}, {}, {}, errors)
	var contract: Dictionary = _CONTRACTS[experiment_id]
	var run_id := _validate_run_identity(manifest, summary, errors)
	var frame_records: Array = _required_stream(
		streams, "frames.jsonl", errors)
	var parsed_frames := _validate_and_parse_frames(
		frame_records, run_id, manifest, errors)
	var analytic_selection := _analytic_selection(
		experiment_id, manifest, parsed_frames.get("frames", []), errors)
	var recomputed_metrics: Dictionary = {}
	var work_proof: Dictionary = {}
	if (
		bool(parsed_frames.get("ok", false))
		and bool(analytic_selection.get("ok", false))
	):
		var all_frame_metrics := _recompute_frame_metrics(
			experiment_id,
			parsed_frames["frames"],
			bool(analytic_selection.get("include_gravity", false)))
		for metric_id in contract["metrics"]:
			if (
				String(metric_id) != "external_work_j"
				and all_frame_metrics.has(metric_id)
			):
				recomputed_metrics[String(metric_id)] = all_frame_metrics[
					metric_id]
		if experiment_id == "L0_0_STATIONARY_GRAVITY_OFF":
			work_proof = _prove_zero_external_work(
				streams,
				run_id,
				parsed_frames["frames"],
				errors)
			if bool(work_proof.get("available", false)):
				recomputed_metrics["external_work_j"] = 0.0

	var metric_checks := _verify_summary_metrics(
		summary,
		contract,
		recomputed_metrics,
		frame_records.size(),
		streams,
		errors)
	var gate_parameters := _validate_gate_parameters(
		manifest, contract, errors)
	var recomputed_gate: Dictionary = {}
	if (
		not gate_parameters.is_empty()
		and _has_gate_metrics(contract, recomputed_metrics, errors)
	):
		var gate_inputs: Dictionary = {}
		for metric_id in contract["gate_metric_ids"]:
			gate_inputs[String(metric_id)] = recomputed_metrics[
				String(metric_id)]
		recomputed_gate = GateEvaluatorScript.evaluate_l0(
			experiment_id, gate_inputs, gate_parameters)
		_verify_summary_semantics(
			summary, recomputed_gate, errors)
	return _result(
		experiment_id,
		recomputed_metrics,
		recomputed_gate,
		work_proof,
		errors,
		metric_checks,
		contract)


static func _validate_run_identity(
		manifest: Dictionary,
		summary: Dictionary,
		errors: Array[Dictionary]) -> String:
	var run_id := String(manifest.get("run_id", ""))
	if run_id.is_empty():
		_error(
			errors,
			"RUN_ID_MISSING",
			"/manifest.json/run_id",
			"Manifest must name the sealed run")
	if String(summary.get("run_id", "")) != run_id:
		_error(
			errors,
			"RUN_ID_MISMATCH",
			"/summary.json/run_id",
			"Summary run_id does not match manifest",
			run_id,
			summary.get("run_id"))
	if String(manifest.get("status", "")) != "COMPLETE":
		_error(
			errors,
			"RUN_NOT_COMPLETE",
			"/manifest.json/status",
			"Unary metric recomputation requires a COMPLETE manifest",
			"COMPLETE",
			manifest.get("status"))
	return run_id


static func _required_stream(
		streams: Dictionary,
		stream_name: String,
		errors: Array[Dictionary]) -> Array:
	if not streams.has(stream_name):
		_error(
			errors,
			"REQUIRED_STREAM_MISSING",
			"/streams/%s" % stream_name,
			"Required sealed stream was not supplied")
		return []
	var value: Variant = streams[stream_name]
	if typeof(value) != TYPE_ARRAY:
		_error(
			errors,
			"STREAM_TYPE_INVALID",
			"/streams/%s" % stream_name,
			"Sealed stream must be supplied as an Array of parsed records")
		return []
	return value


static func _validate_and_parse_frames(
		records: Array,
		run_id: String,
		manifest: Dictionary,
		errors: Array[Dictionary]) -> Dictionary:
	var parsed: Array[Dictionary] = []
	if records.size() < 2:
		_error(
			errors,
			"FRAME_RANGE_INCOMPLETE",
			"/streams/frames.jsonl",
			"L0 unary contracts require at least one complete transition")
		return {"ok": false, "frames": []}
	var expected_step := (
		1.0 / float(manifest.get("physics_ticks_per_second", 0))
		if int(manifest.get("physics_ticks_per_second", 0)) > 0
		else NAN)
	if not is_finite(expected_step) or expected_step <= 0.0:
		_error(
			errors,
			"PHYSICS_STEP_INVALID",
			"/manifest.json/physics_ticks_per_second",
			"Manifest must supply a positive physics tick rate")
	var invariant_mass := NAN
	var invariant_step := NAN
	var invariant_gravity := Vector3.ZERO
	var prior_callback_sequence := -1
	for index in records.size():
		var path := "/streams/frames.jsonl/%d" % index
		var raw: Variant = records[index]
		if typeof(raw) != TYPE_DICTIONARY:
			_error(
				errors,
				"FRAME_TYPE_INVALID",
				path,
				"Frame record must be an object")
			continue
		var frame: Dictionary = raw
		if String(frame.get("schema", "")) != "sporespore.lab.frame.v1":
			_error(
				errors,
				"FRAME_SCHEMA_MISMATCH",
				"%s/schema" % path,
				"Frame schema is not frame_v1")
		if String(frame.get("schema_version", "")) != "frame_v1":
			_error(
				errors,
				"FRAME_SCHEMA_MISMATCH",
				"%s/schema_version" % path,
				"Frame schema_version is not frame_v1")
		if String(frame.get("run_id", "")) != run_id:
			_error(
				errors,
				"RUN_ID_MISMATCH",
				"%s/run_id" % path,
				"Frame run_id does not match manifest")
		for field in ["frame_id", "physics_step_id", "capture_epoch"]:
			var identity := _exact_json_integer(frame.get(field))
			if not bool(identity.get("ok", false)) \
					or int(identity.get("value", -1)) != index:
				_error(
					errors,
					"FRAME_IDENTITY_INVALID",
					"%s/%s" % [path, field],
					"Frame, physics step, and capture epoch must be contiguous",
					index,
					frame.get(field))
		if not bool(frame.get("finite", false)):
			_error(
				errors,
				"FRAME_MARKED_NONFINITE",
				"%s/finite" % path,
				"Non-finite frame cannot support a unary metric")
		if String(frame.get("sample_phase", "")) != "integrate_callback":
			_error(
				errors,
				"FRAME_PHASE_INVALID",
				"%s/sample_phase" % path,
				"L0 analytic contract requires integrate_callback samples")
		if String(frame.get("experiment_phase", "")) != "MEASURE":
			_error(
				errors,
				"FRAME_PHASE_INVALID",
				"%s/experiment_phase" % path,
				"L0 analytic contract requires MEASURE frames")
		var bodies: Variant = frame.get("bodies")
		if typeof(bodies) != TYPE_DICTIONARY \
				or (bodies as Dictionary).size() != 1 \
				or not (bodies as Dictionary).has("body_0"):
			_error(
				errors,
				"FRAME_BODY_SET_INVALID",
				"%s/bodies" % path,
				"Unary L0 contract requires exactly body_0")
			continue
		var body_value: Variant = (bodies as Dictionary)["body_0"]
		if typeof(body_value) != TYPE_DICTIONARY:
			_error(
				errors,
				"BODY_RECORD_INVALID",
				"%s/bodies/body_0" % path,
				"body_0 must be an object")
			continue
		var body: Dictionary = body_value
		if (
			String(body.get("body_id", "")) != "body_0"
			or int(body.get("physics_step_id", -1)) != index
			or int(body.get("capture_epoch", -1)) != index
			or String(body.get("sample_phase", ""))
				!= "integrate_callback"
		):
			_error(
				errors,
				"BODY_FRAME_IDENTITY_INVALID",
				"%s/bodies/body_0" % path,
				"Body record does not belong to its enclosing capture epoch")
		if not bool(body.get("finite", false)):
			_error(
				errors,
				"BODY_MARKED_NONFINITE",
				"%s/bodies/body_0/finite" % path,
				"Non-finite body cannot support a unary metric")
		var callback_sequence_value: Variant = body.get(
			"body_callback_sequence")
		var callback_sequence := _exact_json_integer(
			callback_sequence_value)
		if (
			not bool(callback_sequence.get("ok", false))
			or int(callback_sequence.get(
				"value", prior_callback_sequence)) <= prior_callback_sequence
		):
			_error(
				errors,
				"BODY_CALLBACK_ORDER_INVALID",
				"%s/bodies/body_0/body_callback_sequence" % path,
				"Body callbacks must be strictly increasing")
		else:
			prior_callback_sequence = int(callback_sequence["value"])
		var mass_result := _finite_number(
			body.get("mass_kg"),
			"%s/bodies/body_0/mass_kg" % path,
			errors,
			true)
		var step_result := _finite_number(
			body.get("step_s"),
			"%s/bodies/body_0/step_s" % path,
			errors,
			true)
		var transform: Variant = body.get("transform")
		var origin_value: Variant = (
			(transform as Dictionary).get("origin")
				if typeof(transform) == TYPE_DICTIONARY
				else null)
		var position_result := _finite_vector(
			origin_value,
			"%s/bodies/body_0/transform/origin" % path,
			errors)
		var velocity_result := _finite_vector(
			body.get("linear_velocity"),
			"%s/bodies/body_0/linear_velocity" % path,
			errors)
		var gravity_result := _finite_vector(
			body.get("total_gravity_world"),
			"%s/bodies/body_0/total_gravity_world" % path,
			errors)
		var contacts: Variant = frame.get("contacts")
		if typeof(contacts) != TYPE_ARRAY:
			_error(
				errors,
				"CONTACT_STREAM_INVALID",
				"%s/contacts" % path,
				"Frame contacts must be an array")
			contacts = []
		var availability: Variant = frame.get("availability")
		if (
			typeof(availability) != TYPE_DICTIONARY
			or int((availability as Dictionary).get(
				"captured_body_count", -1)) != 1
			or int((availability as Dictionary).get(
				"contact_count", -1)) != (contacts as Array).size()
			or not ((availability as Dictionary).get(
				"invalid_reasons", []) as Array).is_empty()
		):
			_error(
				errors,
				"FRAME_AVAILABILITY_INVALID",
				"%s/availability" % path,
				"Frame availability does not match its sealed body/contact state")
		var time_result := _finite_number(
			frame.get("physics_time_s"),
			"%s/physics_time_s" % path,
			errors,
			false)
		if not (
			bool(mass_result["ok"])
			and bool(step_result["ok"])
			and bool(position_result["ok"])
			and bool(velocity_result["ok"])
			and bool(gravity_result["ok"])
			and bool(time_result["ok"])
		):
			continue
		var mass := float(mass_result["value"])
		var step := float(step_result["value"])
		var gravity: Vector3 = gravity_result["value"]
		if index == 0:
			invariant_mass = mass
			invariant_step = step
			invariant_gravity = gravity
		else:
			if not is_equal_approx(mass, invariant_mass):
				_error(
					errors,
					"BODY_MASS_CHANGED",
					"%s/bodies/body_0/mass_kg" % path,
					"Unary mass oracle must remain invariant",
					invariant_mass,
					mass)
			if not is_equal_approx(step, invariant_step):
				_error(
					errors,
					"PHYSICS_STEP_CHANGED",
					"%s/bodies/body_0/step_s" % path,
					"Frame step changed inside one run",
					invariant_step,
					step)
			if not gravity.is_equal_approx(invariant_gravity):
				_error(
					errors,
					"GRAVITY_FIELD_CHANGED",
					"%s/bodies/body_0/total_gravity_world" % path,
					"L0 unary analytic contract requires an invariant field")
		if is_finite(expected_step) and not is_equal_approx(step, expected_step):
			_error(
				errors,
				"PHYSICS_STEP_MANIFEST_MISMATCH",
				"%s/bodies/body_0/step_s" % path,
				"Direct-state step does not match manifest tick rate",
				expected_step,
				step)
		var expected_time := float(index) * step
		if not is_equal_approx(float(time_result["value"]), expected_time):
			_error(
				errors,
				"PHYSICS_TIME_INVALID",
				"%s/physics_time_s" % path,
				"Frame time does not match contiguous step time",
				expected_time,
				time_result["value"])
		parsed.append({
			"frame_id": index,
			"position": position_result["value"],
			"velocity": velocity_result["value"],
			"gravity": gravity,
			"mass_kg": mass,
			"step_s": step,
			"contact_count": (contacts as Array).size(),
		})
	return {
		"ok": errors.is_empty() and parsed.size() == records.size(),
		"frames": parsed,
	}


static func _recompute_frame_metrics(
		experiment_id: String,
		frames: Array,
		include_gravity: bool) -> Dictionary:
	var first: Dictionary = frames[0]
	var initial_position: Vector3 = first["position"]
	var initial_velocity: Vector3 = first["velocity"]
	var gravity: Vector3 = first["gravity"]
	var mass_kg := float(first["mass_kg"])
	var step_s := float(first["step_s"])
	var max_position_error_m := 0.0
	var max_velocity_error_m_s := 0.0
	var max_acceleration_error_m_s2 := 0.0
	var max_momentum_error_kg_m_s := 0.0
	var max_kinetic_energy_j := 0.0
	var total_contact_count := 0
	var previous_velocity := initial_velocity
	for index in frames.size():
		var sample: Dictionary = frames[index]
		var position: Vector3 = sample["position"]
		var velocity: Vector3 = sample["velocity"]
		var elapsed_s := float(index) * step_s
		var expected_position := initial_position
		var expected_velocity := initial_velocity
		match experiment_id:
			"L0_1_FREE_FALL":
				expected_position += (
					initial_velocity * elapsed_s
					+ 0.5 * gravity * elapsed_s * elapsed_s)
				expected_velocity += gravity * elapsed_s
			"L0_2_BALLISTIC_ZERO_G":
				expected_position += initial_velocity * elapsed_s
				if include_gravity:
					expected_position += (
						0.5 * gravity * elapsed_s * elapsed_s)
					expected_velocity += gravity * elapsed_s
			"L0_0_STATIONARY_GRAVITY_OFF":
				pass
		max_position_error_m = maxf(
			max_position_error_m,
			position.distance_to(expected_position))
		max_velocity_error_m_s = maxf(
			max_velocity_error_m_s,
			velocity.distance_to(expected_velocity))
		max_momentum_error_kg_m_s = maxf(
			max_momentum_error_kg_m_s,
			(mass_kg * velocity).distance_to(
				mass_kg * expected_velocity))
		max_kinetic_energy_j = maxf(
			max_kinetic_energy_j,
			0.5 * mass_kg * velocity.length_squared())
		total_contact_count += int(sample["contact_count"])
		if index > 0:
			var observed_acceleration := (
				velocity - previous_velocity) / step_s
			max_acceleration_error_m_s2 = maxf(
				max_acceleration_error_m_s2,
				observed_acceleration.distance_to(gravity))
		previous_velocity = velocity
	return {
		"max_position_error_m": max_position_error_m,
		"max_velocity_error_m_s": max_velocity_error_m_s,
		"max_acceleration_error_m_s2":
			max_acceleration_error_m_s2,
		"max_momentum_error_kg_m_s":
			max_momentum_error_kg_m_s,
		"max_kinetic_energy_j": max_kinetic_energy_j,
		"total_contact_count": total_contact_count,
	}


static func _analytic_selection(
		experiment_id: String,
		manifest: Dictionary,
		frames: Array,
		errors: Array[Dictionary]) -> Dictionary:
	if experiment_id == "L0_1_FREE_FALL":
		return {
			"ok": true,
			"include_gravity": true,
			"model": "constant_gravity_from_first_direct_state_v1",
		}
	if experiment_id != "L0_2_BALLISTIC_ZERO_G":
		return {
			"ok": true,
			"include_gravity": false,
			"model": "stationary_from_first_direct_state_v1",
		}
	var expanded: Variant = manifest.get("expanded_parameters")
	var body_parameters: Variant = (
		(expanded as Dictionary).get("body_parameters")
			if typeof(expanded) == TYPE_DICTIONARY
			else null)
	var gravity_scale_value: Variant = (
		(body_parameters as Dictionary).get("gravity_scale")
			if typeof(body_parameters) == TYPE_DICTIONARY
			else null)
	if typeof(gravity_scale_value) not in [TYPE_INT, TYPE_FLOAT] \
			or not is_finite(float(gravity_scale_value)):
		_error(
			errors,
			"BALLISTIC_GRAVITY_CONFIGURATION_MISSING",
			"/manifest.json/expanded_parameters/body_parameters/gravity_scale",
			"L0.2 analytic selection requires sealed finite gravity_scale")
		return {"ok": false}
	var gravity_scale := float(gravity_scale_value)
	var include_gravity := not is_zero_approx(gravity_scale)
	if (
		not include_gravity
		and not frames.is_empty()
		and (frames[0]["gravity"] as Vector3).length()
			> GRAVITY_ZERO_TOLERANCE_M_S2
	):
		_error(
			errors,
			"BALLISTIC_GRAVITY_CONFIGURATION_MISMATCH",
			"/streams/frames.jsonl/0/bodies/body_0/total_gravity_world",
			"gravity_scale=0 cannot select a nonzero measured field")
		return {"ok": false}
	return {
		"ok": true,
		"include_gravity": include_gravity,
		"model": (
			"constant_gravity_from_first_direct_state_v1"
				if include_gravity
				else "zero_g_ballistic_from_first_direct_state_v1"),
	}


static func _prove_zero_external_work(
		streams: Dictionary,
		run_id: String,
		frames: Array,
		errors: Array[Dictionary]) -> Dictionary:
	var commands := _required_stream(streams, "commands.jsonl", errors)
	var applications := _required_stream(
		streams, "applications.jsonl", errors)
	var interventions := _required_stream(
		streams, "interventions.jsonl", errors)
	var runtime_notes := _required_stream(
		streams, "runtime_notes.jsonl", errors)
	var expected_command_count := maxi(frames.size() - 1, 0)
	var command_count_matches := commands.size() == expected_command_count
	if not command_count_matches:
		_error(
			errors,
			"EXTERNAL_WORK_COMMAND_COUNT_INVALID",
			"/streams/commands.jsonl",
			"NONE command stream must cover every transition",
			expected_command_count,
			commands.size())
	var commands_are_sealed_none := command_count_matches
	for index in commands.size():
		var path := "/streams/commands.jsonl/%d" % index
		var envelope_value: Variant = commands[index]
		if typeof(envelope_value) != TYPE_DICTIONARY:
			commands_are_sealed_none = false
			_error(
				errors,
				"COMMAND_RECORD_INVALID",
				path,
				"Command envelope must be an object")
			continue
		var envelope: Dictionary = envelope_value
		var payload_value: Variant = envelope.get("payload")
		if typeof(payload_value) != TYPE_DICTIONARY:
			commands_are_sealed_none = false
			_error(
				errors,
				"COMMAND_RECORD_INVALID",
				"%s/payload" % path,
				"Command envelope must contain a payload object")
			continue
		var payload: Dictionary = payload_value
		var recorded_hash := String(envelope.get(
			"command_payload_sha256", ""))
		var recomputed_hash := CanonicalJsonScript.sha256(payload)
		if recorded_hash != recomputed_hash:
			commands_are_sealed_none = false
			_error(
				errors,
				"COMMAND_PAYLOAD_HASH_MISMATCH",
				"%s/command_payload_sha256" % path,
				"Command payload digest does not match sealed bytes",
				recomputed_hash,
				recorded_hash)
		var transition: Variant = payload.get("applied_transition")
		var command_identity_valid := (
			String(payload.get("schema", ""))
				== "sporespore.lab.command.v1"
			and String(payload.get("run_id", "")) == run_id
			and int(payload.get("command_id", -1)) == index
			and int(payload.get("source_frame_id", -1)) == index
			and typeof(transition) == TYPE_ARRAY
			and (transition as Array).size() == 2
			and int(transition[0]) == index
			and int(transition[1]) == index + 1)
		if not command_identity_valid:
			commands_are_sealed_none = false
			_error(
				errors,
				"COMMAND_TRANSITION_INVALID",
				"%s/payload" % path,
				"Command identity must exactly cover its source transition")
		var none_payload := (
			String(payload.get("mode", "")) == "NONE"
			and typeof(payload.get("joint_commands")) == TYPE_ARRAY
			and (payload.get("joint_commands") as Array).is_empty()
			and typeof(payload.get("intervention_operation_ids"))
				== TYPE_ARRAY
			and (payload.get(
				"intervention_operation_ids") as Array).is_empty())
		if not none_payload:
			commands_are_sealed_none = false
			_error(
				errors,
				"EXTERNAL_WORK_COMMANDS_NOT_NONE",
				"%s/payload" % path,
				"Zero external work requires a sealed NONE payload with no operations")
	var applications_absent := applications.is_empty()
	if not applications_absent:
		_error(
			errors,
			"EXTERNAL_WORK_APPLICATIONS_PRESENT",
			"/streams/applications.jsonl",
			"Application receipts prevent proof of zero external work",
			0,
			applications.size())
	var interventions_absent := interventions.is_empty()
	if not interventions_absent:
		_error(
			errors,
			"EXTERNAL_WORK_INTERVENTIONS_PRESENT",
			"/streams/interventions.jsonl",
			"Fixture interventions prevent proof of zero external work",
			0,
			interventions.size())
	var contacts_absent := true
	var gravity_zero := true
	var contact_count := 0
	var max_gravity_m_s2 := 0.0
	for frame in frames:
		contact_count += int(frame["contact_count"])
		contacts_absent = contacts_absent \
			and int(frame["contact_count"]) == 0
		var gravity: Vector3 = frame["gravity"]
		max_gravity_m_s2 = maxf(max_gravity_m_s2, gravity.length())
		gravity_zero = (
			gravity_zero
			and gravity.length() <= GRAVITY_ZERO_TOLERANCE_M_S2)
	if not contacts_absent:
		_error(
			errors,
			"EXTERNAL_WORK_CONTACTS_PRESENT",
			"/streams/frames.jsonl/*/contacts",
			"Contact impulses prevent proof of zero external work",
			0,
			contact_count)
	if not gravity_zero:
		_error(
			errors,
			"EXTERNAL_WORK_GRAVITY_PRESENT",
			"/streams/frames.jsonl/*/bodies/body_0/total_gravity_world",
			"Nonzero gravity prevents the sealed-absence zero-work proof",
			0.0,
			max_gravity_m_s2)
	var note_claim_valid := _validate_external_work_note(
		runtime_notes, run_id, errors)
	var available := (
		command_count_matches
		and commands_are_sealed_none
		and applications_absent
		and interventions_absent
		and contacts_absent
		and gravity_zero)
	return {
		"contract_id":
			"sporespore.lab.zero_external_work_from_sealed_absence.v1",
		"available": available,
		"value_j": 0.0 if available else null,
		"conditions": {
			"expected_command_count": expected_command_count,
			"actual_command_count": commands.size(),
			"command_count_matches": command_count_matches,
			"commands_are_sealed_none": commands_are_sealed_none,
			"applications_absent": applications_absent,
			"interventions_absent": interventions_absent,
			"contacts_absent": contacts_absent,
			"gravity_zero": gravity_zero,
			"runtime_note_claim_matches": note_claim_valid,
		},
	}


static func _validate_external_work_note(
		runtime_notes: Array,
		run_id: String,
		errors: Array[Dictionary]) -> bool:
	var path := "/streams/runtime_notes.jsonl/1/evidence/external_work_derivation"
	if runtime_notes.size() < 2 \
			or typeof(runtime_notes[1]) != TYPE_DICTIONARY:
		_error(
			errors,
			"EXTERNAL_WORK_NOTE_MISSING",
			path,
			"Second runtime note must contain the sealed derivation claim")
		return false
	var note: Dictionary = runtime_notes[1]
	if String(note.get("run_id", "")) != run_id:
		_error(
			errors,
			"RUN_ID_MISMATCH",
			"/streams/runtime_notes.jsonl/1/run_id",
			"Runtime note run_id does not match manifest")
		return false
	var evidence: Variant = note.get("evidence")
	var derivation: Variant = (
		(evidence as Dictionary).get("external_work_derivation")
			if typeof(evidence) == TYPE_DICTIONARY
			else null)
	if typeof(derivation) != TYPE_DICTIONARY:
		_error(
			errors,
			"EXTERNAL_WORK_NOTE_MISSING",
			path,
			"Runtime note does not contain the derivation object")
		return false
	var value: Dictionary = derivation
	var valid := (
		bool(value.get("available", false))
		and String(value.get("method", ""))
			== "zero_external_work_from_sealed_absence_v1"
		and typeof(value.get("value_j")) in [TYPE_INT, TYPE_FLOAT]
		and is_finite(float(value.get("value_j")))
		and is_zero_approx(float(value.get("value_j"))))
	if not valid:
		_error(
			errors,
			"EXTERNAL_WORK_NOTE_MISMATCH",
			path,
			"Runtime note claim does not match the versioned zero-work contract")
	return valid


static func _verify_summary_metrics(
		summary: Dictionary,
		contract: Dictionary,
		recomputed: Dictionary,
		frame_count: int,
		streams: Dictionary,
		errors: Array[Dictionary]) -> Array[Dictionary]:
	var checks: Array[Dictionary] = []
	if int(summary.get("frame_count", -1)) != frame_count:
		_error(
			errors,
			"SUMMARY_FRAME_COUNT_MISMATCH",
			"/summary.json/frame_count",
			"Summary frame count does not match the sealed frame stream",
			frame_count,
			summary.get("frame_count"))
	if (
		summary.get("first_frame_id") != 0
		or summary.get("last_frame_id") != frame_count - 1
	):
		_error(
			errors,
			"SUMMARY_FRAME_RANGE_MISMATCH",
			"/summary.json",
			"Summary first/last frame IDs do not cover the sealed stream",
			[0, frame_count - 1],
			[
				summary.get("first_frame_id"),
				summary.get("last_frame_id"),
			])
	var metrics_value: Variant = summary.get("metrics")
	if typeof(metrics_value) != TYPE_ARRAY:
		_error(
			errors,
			"SUMMARY_METRICS_INVALID",
			"/summary.json/metrics",
			"Summary metrics must be an array")
		return checks
	var recorded_by_id: Dictionary = {}
	for index in (metrics_value as Array).size():
		var raw: Variant = metrics_value[index]
		if typeof(raw) != TYPE_DICTIONARY:
			_error(
				errors,
				"SUMMARY_METRIC_INVALID",
				"/summary.json/metrics/%d" % index,
				"Metric must be an object")
			continue
		var metric: Dictionary = raw
		var metric_id := String(metric.get("metric_id", ""))
		if metric_id.is_empty() or recorded_by_id.has(metric_id):
			_error(
				errors,
				"SUMMARY_METRIC_DUPLICATE_OR_UNNAMED",
				"/summary.json/metrics/%d/metric_id" % index,
				"Metric IDs must be present and unique")
			continue
		recorded_by_id[metric_id] = {
			"index": index,
			"metric": metric,
		}
	var expected_contracts: Dictionary = contract["metrics"]
	for recorded_id in recorded_by_id:
		if not expected_contracts.has(recorded_id):
			_error(
				errors,
				"UNEXPECTED_UNARY_METRIC",
				"/summary.json/metrics/%d/metric_id"
					% int(recorded_by_id[recorded_id]["index"]),
				"Metric is not emitted by this versioned experiment contract")
	for metric_id_value in expected_contracts:
		var metric_id := String(metric_id_value)
		if not recorded_by_id.has(metric_id):
			_error(
				errors,
				"REQUIRED_UNARY_METRIC_MISSING",
				"/summary.json/metrics",
				"Required metric is absent",
				metric_id,
				null)
			continue
		var entry: Dictionary = recorded_by_id[metric_id]
		var index := int(entry["index"])
		var metric: Dictionary = entry["metric"]
		var definition: Dictionary = expected_contracts[metric_id]
		var path := "/summary.json/metrics/%d" % index
		_exact_metric_field(
			metric, "unit", definition["unit"], path, errors)
		_exact_metric_field(
			metric,
			"source_stream",
			definition["source_stream"],
			path,
			errors)
		_exact_metric_field(
			metric,
			"source_field",
			definition["source_field"],
			path,
			errors)
		_exact_metric_field(
			metric,
			"aggregation_id",
			definition["aggregation_id"],
			path,
			errors)
		_exact_metric_field(
			metric,
			"aggregation_version",
			ANALYTIC_CONTRACT_VERSION,
			path,
			errors)
		_exact_metric_field(
			metric, "availability", "derived", path, errors)
		_exact_metric_field(
			metric, "target_value", 0.0, path, errors)
		var frame_range: Variant = metric.get("source_frame_range")
		var expected_range := [0, frame_count - 1]
		if not _exact_frame_range_matches(
				frame_range, 0, frame_count - 1):
			_error(
				errors,
				"METRIC_SOURCE_RANGE_MISMATCH",
				"%s/source_frame_range" % path,
				"Metric must cover the complete sealed frame range",
				expected_range,
				frame_range)
		var source_stream := String(definition["source_stream"])
		if not streams.has(source_stream):
			_error(
				errors,
				"METRIC_SOURCE_STREAM_MISSING",
				"%s/source_stream" % path,
				"Declared metric source stream was not supplied")
		if not recomputed.has(metric_id):
			_error(
				errors,
				"METRIC_RECOMPUTATION_UNAVAILABLE",
				"%s/value" % path,
				"Metric could not be reconstructed from sealed raw streams")
			continue
		var recorded_result := _finite_number(
			metric.get("value"),
			"%s/value" % path,
			errors,
			false)
		if not bool(recorded_result["ok"]):
			continue
		var recorded := float(recorded_result["value"])
		var rebuilt := float(recomputed[metric_id])
		var tolerance := maxf(
			VALUE_ABSOLUTE_TOLERANCE,
			absf(rebuilt) * 1.0e-12)
		var matches := absf(recorded - rebuilt) <= tolerance
		checks.append({
			"metric_id": metric_id,
			"recorded": recorded,
			"recomputed": rebuilt,
			"absolute_tolerance": tolerance,
			"pass": matches,
		})
		if not matches:
			_error(
				errors,
				"METRIC_VALUE_MISMATCH",
				"%s/value" % path,
				"Stored metric does not reproduce from sealed raw records",
				rebuilt,
				recorded)
	return checks


static func _exact_metric_field(
		metric: Dictionary,
		field: String,
		expected: Variant,
		base_path: String,
		errors: Array[Dictionary]) -> void:
	if not metric.has(field) or metric[field] != expected:
		_error(
			errors,
			"METRIC_CONTRACT_MISMATCH",
			"%s/%s" % [base_path, field],
			"Metric provenance does not match its versioned unary contract",
			expected,
			metric.get(field))


static func _validate_gate_parameters(
		manifest: Dictionary,
		contract: Dictionary,
		errors: Array[Dictionary]) -> Dictionary:
	var error_count_before := errors.size()
	var expanded: Variant = manifest.get("expanded_parameters")
	if typeof(expanded) != TYPE_DICTIONARY:
		_error(
			errors,
			"GATE_PARAMETERS_MISSING",
			"/manifest.json/expanded_parameters",
			"Manifest lacks its sealed expanded experiment")
		return {}
	var gate_value: Variant = (expanded as Dictionary).get("gate_parameters")
	if typeof(gate_value) != TYPE_DICTIONARY:
		_error(
			errors,
			"GATE_PARAMETERS_MISSING",
			"/manifest.json/expanded_parameters/gate_parameters",
			"Expanded experiment lacks gate_parameters")
		return {}
	var gates: Dictionary = gate_value
	var expected_ids: Array = contract["gate_metric_ids"]
	for key in gates:
		if not expected_ids.has(String(key)):
			_error(
				errors,
				"UNEXPECTED_GATE_PARAMETER",
				"/manifest.json/expanded_parameters/gate_parameters/%s"
					% String(key),
				"Gate parameter is not consumed by this experiment contract")
	for metric_id in expected_ids:
		var key := String(metric_id)
		if not gates.has(key):
			_error(
				errors,
				"GATE_PARAMETER_MISSING",
				"/manifest.json/expanded_parameters/gate_parameters/%s"
					% key,
				"Versioned physical gate requires this tolerance")
			continue
		var checked := _finite_number(
			gates[key],
			"/manifest.json/expanded_parameters/gate_parameters/%s"
				% key,
			errors,
			false)
		if bool(checked["ok"]) and float(checked["value"]) < 0.0:
			_error(
				errors,
				"GATE_PARAMETER_INVALID",
				"/manifest.json/expanded_parameters/gate_parameters/%s"
					% key,
				"Gate tolerance must be non-negative")
	return (
		gates.duplicate(true)
			if errors.size() == error_count_before
			else {})


static func _has_gate_metrics(
		contract: Dictionary,
		recomputed: Dictionary,
		errors: Array[Dictionary]) -> bool:
	var complete := true
	for metric_id in contract["gate_metric_ids"]:
		var key := String(metric_id)
		if not recomputed.has(key):
			complete = false
			_error(
				errors,
				"GATE_METRIC_UNAVAILABLE",
				"/recomputed_metrics/%s" % key,
				"Physical gate input could not be independently recomputed")
	return complete


static func _verify_summary_semantics(
		summary: Dictionary,
		recomputed_gate: Dictionary,
		errors: Array[Dictionary]) -> void:
	var gates_value: Variant = summary.get("gate_results")
	if typeof(gates_value) != TYPE_DICTIONARY:
		_error(
			errors,
			"SUMMARY_GATE_RESULTS_MISSING",
			"/summary.json/gate_results",
			"Summary lacks gate results")
		return
	var gates: Dictionary = gates_value
	var physical_value: Variant = gates.get("physical")
	if typeof(physical_value) != TYPE_DICTIONARY:
		_error(
			errors,
			"SUMMARY_PHYSICAL_GATE_MISSING",
			"/summary.json/gate_results/physical",
			"Summary lacks the recorded physical gate")
	else:
		var recorded_gate: Dictionary = physical_value
		if not _physical_gates_match(recorded_gate, recomputed_gate):
			_error(
				errors,
				"PHYSICAL_GATE_RESULT_MISMATCH",
				"/summary.json/gate_results/physical",
				"Stored physical gate does not match recomputed metric inputs")
	var configuration: Variant = gates.get("configuration")
	var source_state: Variant = gates.get("source_state")
	if typeof(configuration) != TYPE_DICTIONARY:
		_error(
			errors,
			"SUMMARY_CONFIGURATION_GATE_MISSING",
			"/summary.json/gate_results/configuration",
			"Cannot derive summary semantics without configuration gate")
		return
	if typeof(source_state) != TYPE_DICTIONARY:
		_error(
			errors,
			"SUMMARY_SOURCE_GATE_MISSING",
			"/summary.json/gate_results/source_state",
			"Cannot derive summary semantics without source-state gate")
		return
	var configuration_pass := bool(
		(configuration as Dictionary).get("pass", false))
	var source_pass := bool((source_state as Dictionary).get("pass", false))
	var physical_pass := bool(recomputed_gate.get("pass", false)) \
		and configuration_pass
	var expected_hypothesis := (
		("supported" if physical_pass else "contradicted")
			if configuration_pass
			else "inconclusive")
	var expected_promotion := (
		"pass"
			if physical_pass and source_pass
			else ("not_evaluated" if not source_pass else "fail"))
	if String(summary.get("hypothesis_result", "")) != expected_hypothesis:
		_error(
			errors,
			"SUMMARY_HYPOTHESIS_RESULT_MISMATCH",
			"/summary.json/hypothesis_result",
			"Stored hypothesis result disagrees with recomputed physical gate",
			expected_hypothesis,
			summary.get("hypothesis_result"))
	if String(summary.get("promotion", "")) != expected_promotion:
		_error(
			errors,
			"SUMMARY_PROMOTION_MISMATCH",
			"/summary.json/promotion",
			"Stored promotion disagrees with recomputed and prerequisite gates",
			expected_promotion,
			summary.get("promotion"))


static func _finite_number(
		value: Variant,
		path: String,
		errors: Array[Dictionary],
		require_positive: bool) -> Dictionary:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		_error(
			errors,
			"FINITE_NUMBER_REQUIRED",
			path,
			"Expected a finite numeric value")
		return {"ok": false}
	var number := float(value)
	if not is_finite(number) or (require_positive and number <= 0.0):
		_error(
			errors,
			"FINITE_NUMBER_REQUIRED",
			path,
			"Expected a finite%s numeric value"
				% (" positive" if require_positive else ""))
		return {"ok": false}
	return {"ok": true, "value": number}


static func _exact_json_integer(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_INT:
		return {"ok": true, "value": int(value)}
	if typeof(value) != TYPE_FLOAT:
		return {"ok": false}
	var number := float(value)
	if (
		not is_finite(number)
		or number != floor(number)
		or absf(number) > 9007199254740991.0
	):
		return {"ok": false}
	return {"ok": true, "value": int(number)}


static func _exact_frame_range_matches(
		value: Variant,
		expected_first: int,
		expected_last: int) -> bool:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 2:
		return false
	var first := _exact_json_integer((value as Array)[0])
	var last := _exact_json_integer((value as Array)[1])
	return (
		bool(first.get("ok", false))
		and bool(last.get("ok", false))
		and int(first["value"]) == expected_first
		and int(last["value"]) == expected_last)


static func _physical_gates_match(
		recorded: Dictionary,
		recomputed: Dictionary) -> bool:
	for field in ["gate_id", "pass", "reason"]:
		if recorded.get(field) != recomputed.get(field):
			return false
	var recorded_checks: Variant = recorded.get("checks")
	var recomputed_checks: Variant = recomputed.get("checks")
	if (
		typeof(recorded_checks) != TYPE_ARRAY
		or typeof(recomputed_checks) != TYPE_ARRAY
		or (recorded_checks as Array).size()
			!= (recomputed_checks as Array).size()
	):
		return false
	for index in (recomputed_checks as Array).size():
		var recorded_value: Variant = recorded_checks[index]
		var recomputed_value: Variant = recomputed_checks[index]
		if (
			typeof(recorded_value) != TYPE_DICTIONARY
			or typeof(recomputed_value) != TYPE_DICTIONARY
		):
			return false
		var recorded_check: Dictionary = recorded_value
		var recomputed_check: Dictionary = recomputed_value
		for field in ["metric_id", "pass", "operator", "reason"]:
			if recorded_check.get(field) != recomputed_check.get(field):
				return false
		for field in ["observed", "limit"]:
			var recorded_number: Variant = recorded_check.get(field)
			var recomputed_number: Variant = recomputed_check.get(field)
			if (
				typeof(recorded_number) not in [TYPE_INT, TYPE_FLOAT]
				or typeof(recomputed_number) not in [TYPE_INT, TYPE_FLOAT]
				or not is_finite(float(recorded_number))
				or not is_finite(float(recomputed_number))
				or absf(
					float(recorded_number) - float(recomputed_number))
					> GATE_NUMERIC_ABSOLUTE_TOLERANCE
			):
				return false
	return true


static func _finite_vector(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 3:
		_error(
			errors,
			"FINITE_VEC3_REQUIRED",
			path,
			"Expected a three-component numeric array")
		return {"ok": false}
	for component in value:
		if typeof(component) not in [TYPE_INT, TYPE_FLOAT] \
				or not is_finite(float(component)):
			_error(
				errors,
				"FINITE_VEC3_REQUIRED",
				path,
				"Expected a finite three-component numeric array")
			return {"ok": false}
	return {
		"ok": true,
		"value": Vector3(
			float(value[0]),
			float(value[1]),
			float(value[2])),
	}


static func _result(
		experiment_id: String,
		recomputed_metrics: Dictionary,
		physical_gate: Dictionary,
		work_proof: Dictionary,
		errors: Array[Dictionary],
		metric_checks: Array[Dictionary] = [],
		contract: Dictionary = {}) -> Dictionary:
	return {
		"ok": errors.is_empty(),
		"recomputer_id": RECOMPUTER_ID,
		"experiment_id": experiment_id,
		"contract_id": contract.get("contract_id"),
		"analytic_model": contract.get("analytic_model"),
		"analytic_contract_version": ANALYTIC_CONTRACT_VERSION,
		"value_absolute_tolerance": VALUE_ABSOLUTE_TOLERANCE,
		"gate_numeric_absolute_tolerance":
			GATE_NUMERIC_ABSOLUTE_TOLERANCE,
		"recomputed_metrics": recomputed_metrics,
		"metric_checks": metric_checks,
		"recomputed_physical_gate": physical_gate,
		"external_work_proof": work_proof,
		"errors": errors,
	}


static func _error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String,
		expected: Variant = null,
		actual: Variant = null) -> void:
	var value := {
		"code": code,
		"path": path,
		"message": message,
	}
	if expected != null or actual != null:
		value["expected"] = expected
		value["actual"] = actual
	errors.append(value)
