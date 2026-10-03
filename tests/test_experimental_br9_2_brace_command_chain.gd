extends SceneTree
# gdlint: disable=max-line-length

## BR9.2 controller -> force map -> actuator -> ledger -> executor -> receipt.
##
## The test also proves that a forged non-torque/root-intervention API reaches
## the executor boundary only to be rejected.

const ActuationExecutorScript := preload("res://scripts/lab/actuation_executor.gd")
const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const BraceControllerScript := preload("res://scripts/lab/mechanics/brace_controller.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const ForceMapScript := preload("res://scripts/lab/mechanics/force_to_joint_map.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")
const ReceiptSinkScript := preload("res://scripts/lab/records/execution_receipt.gd")

const BRACE_CONFIGURATION := {
	"schema_version": "existing_contact_brace_configuration_v1",
	"angular_momentum_gain_s_inv": 12.0,
	"pitch_rate_gain_nm_s_rad": 0.0,
	"reserve_fraction": 0.20,
	"max_normal_load_rate_n_s": 120.0,
	"max_tangent_load_rate_n_s": 120.0,
	"stable_angular_momentum_abs_kg_m2_s": 0.01,
	"stable_pitch_error_abs_rad": 0.02,
	"stable_pitch_rate_abs_rad_s": 0.02,
	"stable_dwell_ticks": 3,
	"feasibility_tolerance": 1.0e-8,
}
const ACTUATOR_CONFIGURATION := {
	"schema_version": "actuator_spec_v1",
	"actuator_id": "br9_chain_actuator",
	"enabled": true,
	"max_isometric_torque_nm": 60.0,
	"no_load_speed_rad_s": 1000.0,
	"max_positive_power_w": 0.0,
	"max_absorption_power_w": 0.0,
	"max_eccentric_multiplier": 1.25,
	"activation_time_s": 0.0011,
	"deactivation_time_s": 100.0,
	"max_torque_rate_nm_s": 12000.0,
	"structural_torque_limit_nm": 75.0,
	"tear_dwell_s": 0.05,
	"capacity_source": "explicit_lab",
	"muscle_pcsa_m2": 0.0,
	"specific_tension_pa": 0.0,
	"moment_arm_m": 0.0,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR9.2 brace command chain ===")
	var controller = BraceControllerScript.new()
	var setup: Dictionary = controller.configure(BRACE_CONFIGURATION, 20.0, 20.0)
	var brace: Dictionary = controller.update(_brace_request())
	var actuator: Dictionary = ActuatorSpecScript.compile(ACTUATOR_CONFIGURATION)
	_check(
		(
			bool(setup.get("ok", false))
			and bool(brace.get("ok", false))
			and bool(actuator.get("ok", false))
		),
		"brace command and finite actuator contract seal before any engine mutation"
	)
	if not bool(brace.get("ok", false)) or not bool(actuator.get("ok", false)):
		printerr("  brace=", brace, " actuator=", actuator)
		_finish()
		return
	var brace_command: Dictionary = brace["command"]
	var mapped := (
		ForceMapScript
		. map(
			{
				"schema_version": "two_link_force_map_request_v1",
				"joint_1_angle_rad": 0.70,
				"joint_2_angle_rad": -1.40,
				"link_1_length_m": 0.40,
				"link_2_length_m": 0.40,
				"carriage_mass_kg": 2.0,
				"link_1_mass_kg": 0.5,
				"link_2_mass_kg": 0.5,
				"gravity_m_s2": 9.8,
				"wrench":
				{
					"schema_version": "body_wrench_v1",
					"frame_id": "world",
					"force_world_n": [0.0, float(brace_command["left"]["normal_force_n"]), 0.0],
					"moment_world_nm": [0.0, 0.0, 0.0],
				},
			}
		)
	)
	_check(
		bool(mapped.get("ok", false)),
		"rate-limited left-contact command maps through the certified vertical J-transpose seam"
	)
	if not bool(mapped.get("ok", false)):
		printerr("  mapping=", mapped)
		_finish()
		return
	var mapping: Dictionary = mapped["mapping"]
	var plan := (
		JointActuatorScript
		. resolve_and_plan(
			{
				"schema_version": "joint_actuator_input_v1",
				"tick": 0,
				"joint_id": "br9_left_hip",
				"parent_body_id": "br9_root",
				"child_body_id": "br9_left_link",
				"source_id": "br9_existing_contact_brace",
				"behavior_state": "BRACE",
				"axis_world": Vector3.BACK,
				"pivot_world": Vector3(-0.30, 0.70, 0.0),
				"angular_velocity_rad_s": 0.0,
				"active_components": {"br9.contact_map": float(mapping["joint_1_feedforward_nm"])},
				"passive_components": {},
				"previous_active_nm": 0.0,
				"previous_activation": 1.0,
				"step_s": 1.0 / 60.0,
			},
			actuator["spec"]
		)
	)
	_check(
		bool(plan.get("ok", false)),
		"mapped contact command resolves into one paired finite joint-torque plan"
	)
	if not bool(plan.get("ok", false)):
		printerr("  plan=", plan)
		_finish()
		return
	var command: Dictionary = plan["command"]
	var operations: Array = command["planned_application_operations"]
	var paired_sum := Vector3.ZERO
	var torque_only := operations.size() == 2
	for operation_value in operations:
		var operation: Dictionary = operation_value
		paired_sum += operation["torque_world_nm"] as Vector3
		torque_only = torque_only and String(operation["api"]) == "RigidBody3D.apply_torque"
	_check(
		torque_only and paired_sum.length() <= 1.0e-12,
		"the only planned engine calls are an equal-and-opposite joint torque pair"
	)

	var root_body := RigidBody3D.new()
	root_body.name = "br9_root"
	root_body.gravity_scale = 0.0
	var link_body := RigidBody3D.new()
	link_body.name = "br9_left_link"
	link_body.gravity_scale = 0.0
	get_root().add_child(root_body)
	get_root().add_child(link_body)
	var ledger = CommandLedgerScript.new()
	var ledger_ok := ledger.begin_tick(0) and ledger.queue_joint(command)
	var envelope: Dictionary = (
		ledger
		. seal(
			{
				"run_id": "br9_command_chain",
				"command_id": 0,
				"source_frame_id": 0,
				"applied_transition": [0, 1],
				"mode": "BR9_EXISTING_CONTACT_BRACE",
			}
		)
	)
	var receipt_sink = ReceiptSinkScript.new("br9_command_chain")
	var execution := ActuationExecutorScript.apply_command_envelope(
		envelope, {"br9_root": root_body, "br9_left_link": link_body}, receipt_sink
	)
	var receipts: Array = receipt_sink.values()
	_check(
		(
			ledger_ok
			and bool(execution.get("ok", false))
			and int(execution.get("applied_count", -1)) == 2
			and receipts.size() == 2
			and _receipts_match(receipts, String(envelope["command_payload_sha256"]), operations)
		),
		"ledger hash, executor calls, and two append-only receipts reconcile exactly"
	)
	_check(
		(
			not bool(brace_command["root_intervention_requested"])
			and not bool(brace_command["foot_pin_requested"])
			and not bool(brace_command["new_contact_requested"])
			and bool(brace_command["per_contact_values_are_commands_not_measurements"])
		),
		"controller command retains no-root/no-pin/no-new-contact and non-measurement boundaries"
	)

	var forged_command := command.duplicate(true)
	forged_command["planned_application_operations"][0]["api"] = "RigidBody3D.apply_force"
	var forged_ledger = CommandLedgerScript.new()
	var forged_ledger_ok := forged_ledger.begin_tick(1)
	forged_command["tick"] = 1
	forged_ledger_ok = forged_ledger.queue_joint(forged_command) and forged_ledger_ok
	var forged_envelope: Dictionary = (
		forged_ledger
		. seal(
			{
				"run_id": "br9_forged_root_intervention",
				"command_id": 1,
				"source_frame_id": 1,
				"applied_transition": [1, 2],
				"mode": "BR9_EXISTING_CONTACT_BRACE",
			}
		)
	)
	var forged_sink = ReceiptSinkScript.new("br9_forged_root_intervention")
	var forged_execution := ActuationExecutorScript.apply_command_envelope(
		forged_envelope, {"br9_root": root_body, "br9_left_link": link_body}, forged_sink
	)
	_check(
		(
			forged_ledger_ok
			and not bool(forged_execution.get("ok", true))
			and String(forged_execution.get("error", "")) == "EXECUTOR_TARGET_OR_API_INVALID"
			and (forged_sink.values() as Array).size() == 1
			and String((forged_sink.values()[0] as Dictionary)["status"]) == "call_failed"
		),
		"a rehashed non-torque intervention is refused and receives one failed receipt"
	)
	root_body.queue_free()
	link_body.queue_free()
	_finish()


func _brace_request() -> Dictionary:
	return {
		"schema_version": "existing_contact_brace_request_v1",
		"tick": 0,
		"detector_state": "BRACE",
		"angular_momentum_z_kg_m2_s": 0.5,
		"pitch_error_rad": 0.0,
		"pitch_rate_rad_s": 0.0,
		"desired_force_x_n": 0.0,
		"desired_force_y_n": 40.0,
		"left_support_x_m": -0.30,
		"right_support_x_m": 0.30,
		"left_bearing": true,
		"right_bearing": true,
		"friction_coefficient": 0.8,
		"minimum_normal_n": 0.0,
		"maximum_normal_n": 50.0,
		"dt_s": 1.0 / 60.0,
	}


func _receipts_match(receipts: Array, payload_hash: String, operations: Array) -> bool:
	if receipts.size() != operations.size():
		return false
	for index in range(operations.size()):
		var receipt: Dictionary = receipts[index]
		var operation: Dictionary = operations[index]
		if (
			String(receipt["status"]) != "call_returned"
			or String(receipt["source_payload_sha256"]) != payload_hash
			or String(receipt["operation_id"]) != String(operation["operation_id"])
			or String(receipt["api"]) != String(operation["api"])
		):
			return false
	return true


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
