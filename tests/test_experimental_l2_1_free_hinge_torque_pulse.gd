extends SceneTree

## Experimental BR4/L2.1 free-hinge paired-torque pulse.
##
## Two collisionless dynamic boxes share a coaxial HingeJoint3D through both
## centers of mass. Gravity, damping, limits, and Godot's built-in hinge motor
## are disabled. Every active torque crosses:
##
##   LabJointActuator -> LabCommandLedger -> LabActuationExecutor -> receipts
##
## The child and parent receive equal-and-opposite world torques exactly once.
## The oracle uses the engine-recorded inverse inertia tensors to predict the
## relative angular-velocity increment, while total angular momentum of the
## free-floating pair must stay near zero.

const ObservedRigidBodyScript := preload("res://scripts/lab/mechanics/observed_rigid_body.gd")
const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const MechanicsBodySampleScript := preload("res://scripts/lab/mechanics/mechanics_body_sample.gd")
const JointBindingScript := preload("res://scripts/lab/mechanics/joint_binding.gd")
const JointStateScript := preload("res://scripts/lab/mechanics/joint_state.gd")
const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")
const TorquePulseAnalyzerScript := preload(
	"res://scripts/lab/mechanics/joint_torque_pulse_analyzer.gd"
)
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const ActuationExecutorScript := preload("res://scripts/lab/actuation_executor.gd")
const ExecutionReceiptSinkScript := preload("res://scripts/lab/records/execution_receipt.gd")

const PHYSICS_HZ := 120
const PULSE_TICKS := 24
const COAST_TICKS := 12
const REQUESTED_TORQUE_NM := 0.05
const PARENT_MASS_KG := 2.0
const PARENT_SIZE_M := Vector3(0.5, 0.4, 0.2)
const CHILD_MASS_KG := 1.0
const CHILD_SIZE_M := Vector3(0.3, 0.2, 0.2)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR4/L2.1 free-hinge torque pulse ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ

	var spec_build: Dictionary = ActuatorSpecScript.compile(_actuator_configuration(true))
	_check(
		bool(spec_build.get("ok", false)),
		"explicit lab actuator compiles without hidden anatomy capacity"
	)
	_test_spec_and_resolver_refusals()
	var positive_build: Dictionary = TorquePulseAnalyzerScript.build(
		_trial_configuration("positive_pulse", "positive", REQUESTED_TORQUE_NM)
	)
	var negative_build: Dictionary = TorquePulseAnalyzerScript.build(
		_trial_configuration("negative_pulse", "negative", REQUESTED_TORQUE_NM)
	)
	var zero_build: Dictionary = TorquePulseAnalyzerScript.build(
		_trial_configuration("zero_control", "zero", 0.0)
	)
	_check(
		(
			bool(positive_build.get("ok", false))
			and bool(negative_build.get("ok", false))
			and bool(zero_build.get("ok", false))
		),
		"positive, negative, and zero schedules seal into exact contracts"
	)
	_test_configuration_refusals()
	if (
		not bool(spec_build.get("ok", false))
		or not bool(positive_build.get("ok", false))
		or not bool(negative_build.get("ok", false))
		or not bool(zero_build.get("ok", false))
	):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return

	var spec: Dictionary = spec_build["spec"]
	var positive: Dictionary = await _run_trial(positive_build["contract"], spec)
	var negative: Dictionary = await _run_trial(negative_build["contract"], spec)
	var zero: Dictionary = await _run_trial(zero_build["contract"], spec)
	_print_result("positive", positive)
	_print_result("negative", negative)
	_print_result("zero", zero)

	_check(
		(
			bool(positive.get("fixture_complete", false))
			and bool(negative.get("fixture_complete", false))
			and bool(zero.get("fixture_complete", false))
		),
		"all three fresh-world dynos retain complete joint, command, and receipt evidence"
	)
	_check(
		(
			bool(positive.get("analysis_ok", false))
			and bool(negative.get("analysis_ok", false))
			and bool(zero.get("analysis_ok", false))
		),
		"all dyno traces satisfy their digest-bound analyzer contracts"
	)
	if not (
		bool(positive.get("analysis_ok", false))
		and bool(negative.get("analysis_ok", false))
		and bool(zero.get("analysis_ok", false))
	):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var positive_result: Dictionary = positive["result"]
	var negative_result: Dictionary = negative["result"]
	var zero_result: Dictionary = zero["result"]
	_check(
		(
			bool(positive_result["accepted"])
			and bool(negative_result["accepted"])
			and bool(zero_result["accepted"])
		),
		"positive, negative, and zero-control cells satisfy all L2.1 gates"
	)
	_check(
		(
			float(positive_result["max_driven_relative_delta_error_fraction"]) <= 0.02
			and float(negative_result["max_driven_relative_delta_error_fraction"]) <= 0.02
		),
		"measured angular acceleration matches applied torque and engine inertia"
	)
	_check(
		(
			float(positive_result["max_total_axis_angular_momentum_abs_n_m_s"]) <= 1.0e-4
			and float(negative_result["max_total_axis_angular_momentum_abs_n_m_s"]) <= 1.0e-4
		),
		"free-floating parent-plus-child angular momentum remains near zero"
	)
	_check(
		(
			float(positive_result["max_pairing_residual_nm"]) <= 1.0e-9
			and float(negative_result["max_pairing_residual_nm"]) <= 1.0e-9
			and float(zero_result["max_pairing_residual_nm"]) <= 1.0e-9
		),
		"every executor plan contains an exact equal-and-opposite torque pair"
	)
	_check(
		(
			bool(positive_result["all_execution_receipts_complete"])
			and bool(negative_result["all_execution_receipts_complete"])
			and bool(zero_result["all_execution_receipts_complete"])
		),
		"two hash-linked call-returned receipts exist for every physics transition"
	)
	_check(
		(
			float(positive_result["max_parent_inverse_inertia_error_fraction"]) <= 1.0e-4
			and float(positive_result["max_child_inverse_inertia_error_fraction"]) <= 1.0e-4
			and float(negative_result["max_parent_inverse_inertia_error_fraction"]) <= 1.0e-4
			and float(negative_result["max_child_inverse_inertia_error_fraction"]) <= 1.0e-4
		),
		"engine inverse inertia tensors agree with both analytic box inertias"
	)
	_check(
		(
			absf(
				(
					float(positive_result["final_relative_rate_rad_s"])
					+ float(negative_result["final_relative_rate_rad_s"])
				)
			)
			<= 2.0e-4
		),
		"positive and negative pulse responses mirror in sign and magnitude"
	)
	_check(
		(
			absf(float(zero_result["final_relative_rate_rad_s"])) <= 1.0e-5
			and absf(float(zero_result["applied_angular_impulse_nm_s"])) <= 1.0e-12
		),
		"zero active request produces zero torque impulse and no joint motion"
	)
	_check(
		(
			bool(positive["motor_disabled"])
			and bool(positive["limit_disabled"])
			and bool(positive["gravity_disabled"])
			and bool(positive["contact_disabled"])
		),
		"live dyno confirms motor, limit, gravity, damping, and contact exclusions"
	)
	_test_analyzer_refusals(positive_build["contract"], positive["samples"])
	_check(
		(
			String(positive_result["claim_boundary"])
			== (
				"Exact gravity-off coaxial free-hinge paired-torque fixture only; "
				+ "no load-bearing, contact, standing, bracing, recovery, gait, "
				+ "or walking claim."
			)
		),
		"L2.1 result carries the exact contact-free non-claim boundary"
	)

	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _run_trial(contract: Dictionary, spec: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "FreeHinge_%s" % String(contract["trial_id"])
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var world := Node3D.new()
	world.name = "FreeHingeWorld"
	var clock = CaptureClockScript.new()
	var profile := {
		"profile_id": "l2_1_inertia_joint_frames",
		"contacts_enabled": false,
		"contact_cap_per_body": 0,
		"channels": [],
	}
	var parent = _body("rotor_parent", PARENT_MASS_KG, PARENT_SIZE_M, clock, profile)
	var child = _body("rotor_child", CHILD_MASS_KG, CHILD_SIZE_M, clock, profile)
	world.add_child(parent)
	world.add_child(child)
	var joint := HingeJoint3D.new()
	joint.name = "FreeHinge"
	joint.position = Vector3(0.0, 2.0, 0.0)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	world.add_child(joint)
	viewport.add_child(world)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)
	var binding_build: Dictionary = (
		JointBindingScript
		. build(
			{
				"joint_id": "l2_1_free_hinge",
				"parent_body_id": "rotor_parent",
				"child_body_id": "rotor_child",
				"axis_parent_local": Vector3.BACK,
				"axis_child_local": Vector3.BACK,
				"anchor_parent_local": Vector3.ZERO,
				"anchor_child_local": Vector3.ZERO,
				"rest_child_rotation_parent_local": Quaternion.IDENTITY,
				"anchor_agreement_tolerance_m": 5.0e-3,
				"axis_agreement_tolerance_rad": 2.0e-2,
				"swing_tolerance_rad": 2.0e-2,
				"local_joint_scale_m": 0.2,
				"local_joint_scale_basis": "joint_fixture_extent_min_v1",
				"morphology_config_digest_sha256":
				"sha256:%s" % String(contract["configuration_sha256"]).sha256_text(),
				"requires_unwrapped_angle": false,
			}
		)
	)
	var binding: Dictionary = binding_build.get("binding", {})
	var fresh_world := viewport.own_world_3d and viewport.world_3d != root.world_3d

	await process_frame
	clock.open_epoch(0, 0.0, &"integrate_callback")
	await physics_frame
	clock.close_epoch()
	var current_state := _joint_state(
		binding, parent.latest_body_sample, child.latest_body_sample, String(contract["trial_id"])
	)
	var samples: Array = []
	var fixture_complete := (
		fresh_world
		and bool(binding_build.get("ok", false))
		and bool(current_state.get("complete", false))
	)
	var previous_active := 0.0
	var previous_activation := 0.0
	var receipt_sink = ExecutionReceiptSinkScript.new("l2_1_%s" % String(contract["trial_id"]))
	var bodies := {
		"rotor_parent": parent,
		"rotor_child": child,
	}
	var step_s := 1.0 / float(contract["physics_hz"])
	var signed_request := float(contract["requested_torque_nm"])
	if String(contract["pulse_direction"]) == "negative":
		signed_request = -signed_request
	for tick in int(contract["expected_sample_count"]):
		var requested := signed_request if tick < int(contract["pulse_ticks"]) else 0.0
		var axis := _vector3(current_state["current_axis_world"])
		var parent_before: float = parent.angular_velocity.dot(axis)
		var child_before: float = child.angular_velocity.dot(axis)
		var plan: Dictionary = (
			JointActuatorScript
			. resolve_and_plan(
				{
					"schema_version": "joint_actuator_input_v1",
					"tick": tick,
					"joint_id": "l2_1_free_hinge",
					"parent_body_id": "rotor_parent",
					"child_body_id": "rotor_child",
					"source_id": "l2_1_known_pulse",
					"behavior_state": "DYNO",
					"axis_world": axis,
					"pivot_world": Vector3(0.0, 2.0, 0.0),
					"angular_velocity_rad_s": child_before - parent_before,
					"active_components": {"l2_1.pulse": requested},
					"passive_components": {},
					"previous_active_nm": previous_active,
					"previous_activation": previous_activation,
					"step_s": step_s,
				},
				spec
			)
		)
		fixture_complete = bool(plan.get("ok", false)) and fixture_complete
		if not bool(plan.get("ok", false)):
			break
		var resolution: Dictionary = plan["resolution"]
		var command: Dictionary = plan["command"]
		var ledger = CommandLedgerScript.new()
		fixture_complete = ledger.begin_tick(tick) and fixture_complete
		fixture_complete = ledger.queue_joint(command) and fixture_complete
		var envelope: Dictionary = (
			ledger
			. seal(
				{
					"run_id": "l2_1_%s" % String(contract["trial_id"]),
					"command_id": tick,
					"source_frame_id": tick,
					"applied_transition": [tick, tick + 1],
					"mode": "L2_1_TORQUE_PULSE",
				}
			)
		)
		var receipt_count_before := receipt_sink.values().size()
		clock.open_epoch(tick + 1, float(tick + 1) * step_s, &"integrate_callback")
		var execution: Dictionary = ActuationExecutorScript.apply_command_envelope(
			envelope, bodies, receipt_sink
		)
		await physics_frame
		clock.close_epoch()
		var all_receipts: Array = receipt_sink.values()
		var new_receipts := all_receipts.slice(receipt_count_before)
		var receipts_match := _receipts_match(
			new_receipts,
			String(envelope["command_payload_sha256"]),
			command["planned_application_operations"]
		)
		current_state = _joint_state(
			binding,
			parent.latest_body_sample,
			child.latest_body_sample,
			String(contract["trial_id"])
		)
		fixture_complete = (
			bool(execution.get("ok", false))
			and int(execution.get("applied_count", -1)) == 2
			and bool(current_state.get("complete", false))
			and new_receipts.size() == 2
			and receipts_match
			and fixture_complete
		)
		var post_axis := _vector3(current_state["current_axis_world"])
		var inverse_parent := _axis_inverse_inertia(parent.latest_body_sample, post_axis)
		var inverse_child := _axis_inverse_inertia(child.latest_body_sample, post_axis)
		(
			samples
			. append(
				{
					"tick": tick,
					"requested_torque_nm": float(resolution["requested_active_nm"]),
					"applied_torque_nm": float(resolution["applied_total_nm"]),
					"parent_rate_before_rad_s": parent_before,
					"child_rate_before_rad_s": child_before,
					"parent_rate_after_rad_s": parent.angular_velocity.dot(post_axis),
					"child_rate_after_rad_s": child.angular_velocity.dot(post_axis),
					"engine_parent_axis_inverse_inertia": inverse_parent,
					"engine_child_axis_inverse_inertia": inverse_child,
					"pairing_residual_nm":
					float((command["diagnostics"] as Dictionary)["pairing_residual_nm"]),
					"receipt_count": new_receipts.size(),
					"receipts_match_command": receipts_match,
					"joint_observation_valid": bool(current_state["observation_valid"]),
					"anchor_error_m": float(current_state["anchor_agreement_error_m"]),
					"axis_error_rad": float(current_state["axis_agreement_error_rad"]),
					"swing_residual_rad": float(current_state["swing_residual_rad"]),
					"off_axis_rate_rad_s": float(current_state["off_axis_rate_rad_s"]),
				}
			)
		)
		previous_active = float(resolution["applied_active_nm"])
		previous_activation = float(resolution["activation_next"])
	var analysis: Dictionary = TorquePulseAnalyzerScript.analyze(contract, samples)
	var result := {
		"fixture_complete":
		fixture_complete and samples.size() == int(contract["expected_sample_count"]),
		"analysis_ok": bool(analysis.get("ok", false)),
		"analysis_failure": {} if bool(analysis.get("ok", false)) else analysis,
		"result": analysis.get("result", {}),
		"samples": samples,
		"motor_disabled": not joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR),
		"limit_disabled": not joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT),
		"gravity_disabled": parent.gravity_scale == 0.0 and child.gravity_scale == 0.0,
		"contact_disabled":
		(
			not parent.contact_monitor
			and not child.contact_monitor
			and parent.collision_mask == 0
			and child.collision_mask == 0
		),
	}
	viewport.queue_free()
	await physics_frame
	return result


func _test_spec_and_resolver_refusals() -> void:
	var negative_capacity := _actuator_configuration(true)
	negative_capacity["max_isometric_torque_nm"] = -1.0
	var dual_provenance := _actuator_configuration(true)
	dual_provenance["muscle_pcsa_m2"] = 0.001
	var legacy := _actuator_configuration(true)
	legacy["capacity_source"] = "legacy"
	_check(
		(
			not bool(ActuatorSpecScript.compile(negative_capacity).get("ok", true))
			and not bool(ActuatorSpecScript.compile(dual_provenance).get("ok", true))
			and not bool(ActuatorSpecScript.compile(legacy).get("ok", true))
		),
		"spec compiler rejects negative capacity, dual provenance, and legacy source"
	)
	var enabled_build: Dictionary = ActuatorSpecScript.compile(_actuator_configuration(true))
	var input := _resolver_input()
	var resolved: Dictionary = JointActuatorScript.resolve_and_plan(input, enabled_build["spec"])
	var sealed_command: Dictionary = resolved.get("command", {})
	input["active_components"]["test.request"] = 999.0
	_check(
		(
			bool(resolved.get("ok", false))
			and float(sealed_command["requested_active_nm"]) == REQUESTED_TORQUE_NM
		),
		"resolved command is detached from later mutable input changes"
	)
	var invalid_axis := _resolver_input()
	invalid_axis["axis_world"] = Vector3(0.0, 0.0, 2.0)
	var self_pair := _resolver_input()
	self_pair["child_body_id"] = "rotor_parent"
	var unknown_field := _resolver_input()
	unknown_field["direct_apply"] = true
	_check(
		(
			not bool(
				JointActuatorScript.resolve_and_plan(invalid_axis, enabled_build["spec"]).get(
					"ok", true
				)
			)
			and not bool(
				JointActuatorScript.resolve_and_plan(self_pair, enabled_build["spec"]).get(
					"ok", true
				)
			)
			and not bool(
				JointActuatorScript.resolve_and_plan(unknown_field, enabled_build["spec"]).get(
					"ok", true
				)
			)
		),
		"resolver rejects non-unit axes, self-pairs, and unknown bypass fields"
	)
	var disabled_build: Dictionary = ActuatorSpecScript.compile(_actuator_configuration(false))
	var disabled: Dictionary = JointActuatorScript.resolve_and_plan(
		_resolver_input(), disabled_build["spec"]
	)
	_check(
		(
			bool(disabled.get("ok", false))
			and float(disabled["resolution"]["applied_active_nm"]) == 0.0
			and float(disabled["resolution"]["applied_total_nm"]) == 0.0
		),
		"disabled actuator has exactly zero active capacity with no baseline"
	)


func _test_configuration_refusals() -> void:
	var hidden_motor := _trial_configuration("hidden_motor", "positive", REQUESTED_TORQUE_NM)
	hidden_motor["built_in_motor_enabled"] = true
	var hidden_gravity := _trial_configuration("hidden_gravity", "positive", REQUESTED_TORQUE_NM)
	hidden_gravity["gravity_enabled"] = true
	var mislabeled_zero := _trial_configuration("false_zero", "zero", REQUESTED_TORQUE_NM)
	var unknown := _trial_configuration("unknown", "positive", REQUESTED_TORQUE_NM)
	unknown["root_reaction_torque_nm"] = 1.0
	_check(
		(
			not bool(TorquePulseAnalyzerScript.build(hidden_motor).get("ok", true))
			and not bool(TorquePulseAnalyzerScript.build(hidden_gravity).get("ok", true))
			and not bool(TorquePulseAnalyzerScript.build(mislabeled_zero).get("ok", true))
			and not bool(TorquePulseAnalyzerScript.build(unknown).get("ok", true))
		),
		"dyno contract rejects hidden motor/gravity, false zero, and root reaction"
	)


func _test_analyzer_refusals(contract: Dictionary, source_samples: Array) -> void:
	var changed_contract := contract.duplicate(true)
	changed_contract["requested_torque_nm"] = 0.06
	var changed_result: Dictionary = TorquePulseAnalyzerScript.analyze(
		changed_contract, source_samples
	)
	_check(
		(
			not bool(changed_result.get("ok", true))
			and (
				String(changed_result.get("failure_code", ""))
				== "JOINT_TORQUE_PULSE_CONTRACT_DIGEST_MISMATCH"
			)
		),
		"post-seal torque-contract mutation fails closed"
	)
	var short_samples := source_samples.duplicate(true)
	short_samples.pop_back()
	var short_result: Dictionary = TorquePulseAnalyzerScript.analyze(contract, short_samples)
	_check(
		(
			not bool(short_result.get("ok", true))
			and (
				String(short_result.get("failure_code", ""))
				== "JOINT_TORQUE_PULSE_SAMPLE_COUNT_MISMATCH"
			)
		),
		"missing torque-transition sample fails closed"
	)
	var nonfinite_samples := source_samples.duplicate(true)
	(nonfinite_samples[3] as Dictionary)["engine_child_axis_inverse_inertia"] = NAN
	var nonfinite_result: Dictionary = TorquePulseAnalyzerScript.analyze(
		contract, nonfinite_samples
	)
	_check(
		(
			not bool(nonfinite_result.get("ok", true))
			and (
				String(nonfinite_result.get("failure_code", ""))
				== "JOINT_TORQUE_PULSE_SAMPLE_NONFINITE"
			)
		),
		"nonfinite engine-inertia evidence fails closed"
	)
	var request_forge := source_samples.duplicate(true)
	(request_forge[2] as Dictionary)["requested_torque_nm"] = 0.04
	var request_result: Dictionary = TorquePulseAnalyzerScript.analyze(contract, request_forge)
	_check(
		(
			not bool(request_result.get("ok", true))
			and (
				String(request_result.get("failure_code", ""))
				== "JOINT_TORQUE_PULSE_REQUEST_SCHEDULE_MISMATCH"
			)
		),
		"request trace that disagrees with the sealed schedule fails closed"
	)
	var missing_receipt := source_samples.duplicate(true)
	(missing_receipt[4] as Dictionary)["receipt_count"] = 1
	var receipt_result: Dictionary = TorquePulseAnalyzerScript.analyze(contract, missing_receipt)
	_check(
		(
			bool(receipt_result.get("ok", false))
			and not bool(receipt_result["result"]["accepted"])
			and (receipt_result["result"]["acceptance_failures"] as Array).has(
				"EXECUTION_RECEIPT_INCOMPLETE"
			)
		),
		"missing paired executor receipt makes a complete trace non-acceptable"
	)


static func _body(body_id: String, mass_kg: float, size_m: Vector3, clock, profile: Dictionary):
	var body = ObservedRigidBodyScript.new()
	body.name = body_id
	body.body_id = StringName(body_id)
	body.part_index = 0 if body_id == "rotor_parent" else 1
	body.capture_clock = clock
	body.observer_profile = profile
	body.mass = mass_kg
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0.0, 2.0, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_m
	collision.shape = shape
	body.add_child(collision)
	return body


static func _joint_state(
	binding: Dictionary, parent_sample: Dictionary, child_sample: Dictionary, trial_id: String
) -> Dictionary:
	var parent_projection: Dictionary = MechanicsBodySampleScript.project(
		parent_sample, "l2_1_%s" % trial_id, "l2_1_free_hinge_capture"
	)
	var child_projection: Dictionary = MechanicsBodySampleScript.project(
		child_sample, "l2_1_%s" % trial_id, "l2_1_free_hinge_capture"
	)
	if not bool(parent_projection.get("ok", false)) or not bool(child_projection.get("ok", false)):
		return {}
	return JointStateScript.sample(binding, parent_projection["sample"], child_projection["sample"])


static func _axis_inverse_inertia(body_sample: Dictionary, axis_world: Vector3) -> float:
	var inverse_tensor := _basis(body_sample["inverse_inertia_tensor_world"])
	return axis_world.dot(inverse_tensor * axis_world)


static func _basis(value: Dictionary) -> Basis:
	return Basis(_vector3(value["x"]), _vector3(value["y"]), _vector3(value["z"]))


static func _receipts_match(receipts: Array, payload_hash: String, operations: Array) -> bool:
	if receipts.size() != 2 or operations.size() != 2:
		return false
	var expected: Dictionary = {}
	for operation_value in operations:
		var operation: Dictionary = operation_value
		expected[String(operation["operation_id"])] = String(operation["body_id"])
	for receipt_value in receipts:
		var receipt: Dictionary = receipt_value
		if (
			String(receipt.get("status", "")) != "call_returned"
			or String(receipt.get("source_payload_sha256", "")) != payload_hash
			or not expected.has(String(receipt.get("operation_id", "")))
			or (
				expected[String(receipt["operation_id"])]
				!= String(receipt.get("target_body_id", ""))
			)
		):
			return false
	return true


static func _actuator_configuration(enabled: bool) -> Dictionary:
	return {
		"schema_version": "actuator_spec_v1",
		"actuator_id": "l2_1_explicit_lab_motor",
		"enabled": enabled,
		"max_isometric_torque_nm": 1.0,
		"no_load_speed_rad_s": 100.0,
		"max_positive_power_w": 0.0,
		"max_absorption_power_w": 0.0,
		"max_eccentric_multiplier": 1.25,
		"activation_time_s": 0.0011,
		"deactivation_time_s": 0.0011,
		"max_torque_rate_nm_s": 1000.0,
		"structural_torque_limit_nm": 2.0,
		"tear_dwell_s": 0.05,
		"capacity_source": "explicit_lab",
		"muscle_pcsa_m2": 0.0,
		"specific_tension_pa": 0.0,
		"moment_arm_m": 0.0,
	}


static func _trial_configuration(
	trial_id: String, direction: String, torque_nm: float
) -> Dictionary:
	return {
		"schema_version": "joint_torque_pulse_configuration_v1",
		"trial_id": trial_id,
		"physics_hz": PHYSICS_HZ,
		"pulse_ticks": PULSE_TICKS,
		"coast_ticks": COAST_TICKS,
		"requested_torque_nm": torque_nm,
		"pulse_direction": direction,
		"parent_mass_kg": PARENT_MASS_KG,
		"parent_size_m": PARENT_SIZE_M,
		"child_mass_kg": CHILD_MASS_KG,
		"child_size_m": CHILD_SIZE_M,
		"gravity_enabled": false,
		"linear_damp_s_inv": 0.0,
		"angular_damp_s_inv": 0.0,
		"contact_enabled": false,
		"built_in_motor_enabled": false,
		"limit_enabled": false,
	}


static func _resolver_input() -> Dictionary:
	return {
		"schema_version": "joint_actuator_input_v1",
		"tick": 0,
		"joint_id": "l2_1_free_hinge",
		"parent_body_id": "rotor_parent",
		"child_body_id": "rotor_child",
		"source_id": "l2_1_known_pulse",
		"behavior_state": "DYNO",
		"axis_world": Vector3.BACK,
		"pivot_world": Vector3(0.0, 2.0, 0.0),
		"angular_velocity_rad_s": 0.0,
		"active_components": {"test.request": REQUESTED_TORQUE_NM},
		"passive_components": {},
		"previous_active_nm": 0.0,
		"previous_activation": 0.0,
		"step_s": 1.0 / float(PHYSICS_HZ),
	}


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


static func _print_result(label: String, trial: Dictionary) -> void:
	if not bool(trial.get("analysis_ok", false)):
		print("  %s analysis_failure=%s" % [label, str(trial.get("analysis_failure", {}))])
		return
	var result: Dictionary = trial["result"]
	print(
		(
			(
				"  %s accepted=%s samples=%d final_qdot=%.6frad/s "
				+ "impulse=%.8fNms accel_err=%.4f%% coast=%.9frad/s "
				+ "momentum=%.9fNms inertia=%.6f/%.6f%% failures=%s"
			)
			% [
				label,
				str(bool(result["accepted"])),
				int(result["sample_count"]),
				float(result["final_relative_rate_rad_s"]),
				float(result["applied_angular_impulse_nm_s"]),
				100.0 * float(result["max_driven_relative_delta_error_fraction"]),
				float(result["max_coast_relative_delta_rad_s"]),
				float(result["max_total_axis_angular_momentum_abs_n_m_s"]),
				100.0 * float(result["max_parent_inverse_inertia_error_fraction"]),
				100.0 * float(result["max_child_inverse_inertia_error_fraction"]),
				str(result["acceptance_failures"]),
			]
		)
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
