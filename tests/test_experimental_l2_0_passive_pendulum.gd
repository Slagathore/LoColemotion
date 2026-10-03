extends SceneTree

## Experimental BR4/L2.0 fixed-base passive-pendulum truth.
##
## This cell is deliberately below every actuator and load-bearing claim. It
## joins one collisionless rigid box to a fixed StaticBody3D with a live Jolt
## HingeJoint3D, releases the link from a small known angle, and samples both
## live body frames through LabJointState on every post-step tick.
##
## The independent oracle is the small-angle physical-pendulum period for a
## rectangular link pivoted at one end. Two undamped fresh-world controls must
## reproduce it and conserve mechanical energy; a third fresh-world comparison
## must preserve the same hinge geometry while dissipating energy under an
## explicitly declared angular damping coefficient.
##
## No motor, limit, collision contact, external torque, articulated support,
## standing, bracing, recovery, gait, or walking claim is present here.

const PassivePendulumAnalyzerScript := preload(
	"res://scripts/lab/mechanics/passive_pendulum_analyzer.gd"
)
const JointBindingScript := preload("res://scripts/lab/mechanics/joint_binding.gd")
const JointStateScript := preload("res://scripts/lab/mechanics/joint_state.gd")

const PHYSICS_HZ := 120
const DURATION_S := 6.0
const MASS_KG := 1.5
const LINK_WIDTH_M := 0.08
const LINK_LENGTH_M := 1.0
const LINK_DEPTH_M := 0.08
const PIVOT_TO_COM_M := 0.5
const GRAVITY_M_S2 := 9.8
const INITIAL_ANGLE_RAD := 0.2
const DAMPED_COMPARISON_S_INV := 0.8

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR4/L2.0 passive-pendulum truth ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ

	var baseline_a_build: Dictionary = PassivePendulumAnalyzerScript.build(
		_configuration("undamped_a", "undamped_control", 0.0)
	)
	var baseline_b_build: Dictionary = PassivePendulumAnalyzerScript.build(
		_configuration("undamped_b", "undamped_control", 0.0)
	)
	var damped_build: Dictionary = PassivePendulumAnalyzerScript.build(
		_configuration("damped_comparison", "damped_comparison", DAMPED_COMPARISON_S_INV)
	)
	_check(
		(
			bool(baseline_a_build.get("ok", false))
			and bool(baseline_b_build.get("ok", false))
			and bool(damped_build.get("ok", false))
		),
		"three exact trial configurations seal into digest-bound contracts"
	)
	_test_configuration_refusals()
	if not (
		bool(baseline_a_build.get("ok", false))
		and bool(baseline_b_build.get("ok", false))
		and bool(damped_build.get("ok", false))
	):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return

	var baseline_a: Dictionary = await _run_trial(baseline_a_build["contract"])
	var baseline_b: Dictionary = await _run_trial(baseline_b_build["contract"])
	var damped: Dictionary = await _run_trial(damped_build["contract"])
	_print_result("undamped_a", baseline_a)
	_print_result("undamped_b", baseline_b)
	_print_result("damped", damped)

	var all_trials_complete := (
		bool(baseline_a.get("fixture_complete", false))
		and bool(baseline_b.get("fixture_complete", false))
		and bool(damped.get("fixture_complete", false))
	)
	_check(all_trials_complete, "all fresh-world trials retain finite complete live joint samples")
	var analyses_ok := (
		bool(baseline_a.get("analysis_ok", false))
		and bool(baseline_b.get("analysis_ok", false))
		and bool(damped.get("analysis_ok", false))
	)
	_check(analyses_ok, "all trial traces satisfy the sealed analyzer input contract")
	if not analyses_ok:
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return

	var baseline_a_result: Dictionary = baseline_a["result"]
	var baseline_b_result: Dictionary = baseline_b["result"]
	var damped_result: Dictionary = damped["result"]
	_check(
		bool(baseline_a_result["accepted"]) and bool(baseline_b_result["accepted"]),
		"both undamped controls satisfy period, geometry, and energy gates"
	)
	_check(
		bool(damped_result["accepted"]),
		"declared damped comparison satisfies geometry and decay gates"
	)
	_check(
		(
			float(baseline_a_result["period_error_fraction"]) <= 0.05
			and float(baseline_b_result["period_error_fraction"]) <= 0.05
			and float(damped_result["period_error_fraction"]) <= 0.05
		),
		"measured period remains within 5 percent of the analytic oracle"
	)
	_check(
		(
			absf(
				(
					float(baseline_a_result["mean_period_s"])
					- float(baseline_b_result["mean_period_s"])
				)
			)
			<= 0.01
		),
		"fresh-world undamped controls repeat within 10 ms"
	)
	_check(
		(
			float(baseline_a_result["max_anchor_error_m"]) <= 5.0e-3
			and float(baseline_b_result["max_anchor_error_m"]) <= 5.0e-3
			and float(damped_result["max_anchor_error_m"]) <= 5.0e-3
		),
		"live parent/child anchor reconstructions agree within 5 mm"
	)
	_check(
		(
			float(baseline_a_result["max_axis_error_rad"]) <= 2.0e-2
			and float(baseline_b_result["max_axis_error_rad"]) <= 2.0e-2
			and float(damped_result["max_axis_error_rad"]) <= 2.0e-2
		),
		"live parent/child hinge axes remain mutually coherent"
	)
	_check(
		(
			float(baseline_a_result["max_swing_residual_rad"]) <= 2.0e-2
			and float(baseline_b_result["max_swing_residual_rad"]) <= 2.0e-2
			and float(damped_result["max_swing_residual_rad"]) <= 2.0e-2
		),
		"motion remains a one-axis hinge rotation rather than hidden swing"
	)
	_check(
		(
			float(baseline_a_result["max_off_axis_rate_rad_s"]) <= 5.0e-2
			and float(baseline_b_result["max_off_axis_rate_rad_s"]) <= 5.0e-2
			and float(damped_result["max_off_axis_rate_rad_s"]) <= 5.0e-2
		),
		"relative angular velocity remains aligned with the live hinge axis"
	)
	_check(
		(
			float(baseline_a_result["initial_rate_rad_s"]) < 0.0
			and float(baseline_b_result["initial_rate_rad_s"]) < 0.0
			and float(damped_result["initial_rate_rad_s"]) < 0.0
		),
		"gravity accelerates the positive release toward the downward rest pose"
	)
	_check(
		(
			float(baseline_a_result["energy_range_fraction"]) <= 0.12
			and float(baseline_b_result["energy_range_fraction"]) <= 0.12
		),
		"undamped mechanical-energy range stays within the preregistered envelope"
	)
	_check(
		(
			float(damped_result["energy_final_fraction"]) <= 0.45
			and float(damped_result["amplitude_retention_fraction"]) <= 0.75
			and (
				float(damped_result["amplitude_retention_fraction"])
				< float(baseline_a_result["amplitude_retention_fraction"])
			)
		),
		"explicit damping reduces energy and amplitude relative to control"
	)
	_check(
		(
			(
				String(baseline_a_result["configuration_sha256"])
				!= String(baseline_b_result["configuration_sha256"])
			)
			and (
				String(baseline_a_result["result_sha256"])
				!= String(baseline_b_result["result_sha256"])
			)
		),
		"trial identity remains part of configuration and result provenance"
	)
	_test_analyzer_refusals(baseline_a_build["contract"], baseline_a["samples"])
	_check(
		(
			not bool(baseline_a["motor_enabled"])
			and not bool(baseline_a["limit_enabled"])
			and not bool(baseline_a["contact_enabled"])
			and String(baseline_a["parent_kind"]) == "StaticBody3D"
		),
		"live fixture confirms fixed parent with motor, limit, and contact disabled"
	)
	_check(
		(
			String(baseline_a_result["claim_boundary"])
			== (
				"Exact fixed-base passive hinge fixture only; no actuator, "
				+ "load-bearing, standing, bracing, recovery, gait, or "
				+ "walking claim."
			)
		),
		"L2.0 result carries the exact passive-only non-claim boundary"
	)

	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _run_trial(contract: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "PassivePendulum_%s" % String(contract["trial_id"])
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)

	var world := Node3D.new()
	world.name = "PendulumWorld"
	var parent := StaticBody3D.new()
	parent.name = "FixedParent"
	parent.position = Vector3.ZERO
	parent.collision_layer = 0
	parent.collision_mask = 0
	world.add_child(parent)

	var child := RigidBody3D.new()
	child.name = "PassiveLink"
	child.mass = float(contract["mass_kg"])
	child.can_sleep = false
	# The link stays frozen while the fresh physics space and joint activate.
	# This prevents process/physics catch-up ticks from consuming an unknown
	# part of the authored release before the measurement schedule begins.
	child.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	child.freeze = true
	child.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	child.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	child.linear_damp = 0.0
	child.angular_damp = float(contract["angular_damp_s_inv"])
	child.collision_layer = 0
	child.collision_mask = 0
	var initial_angle := float(contract["initial_angle_rad"])
	var pivot_to_com := float(contract["pivot_to_com_m"])
	child.quaternion = Quaternion(Vector3.BACK, initial_angle)
	child.position = Vector3(
		pivot_to_com * sin(initial_angle), -pivot_to_com * cos(initial_angle), 0.0
	)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		float(contract["link_width_m"]),
		float(contract["link_length_m"]),
		float(contract["link_depth_m"])
	)
	collision.shape = shape
	child.add_child(collision)
	world.add_child(child)

	var joint := HingeJoint3D.new()
	joint.name = "PassiveHinge"
	joint.transform = Transform3D.IDENTITY
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
				"joint_id": "l2_0_passive_hinge",
				"parent_body_id": "pendulum_parent",
				"child_body_id": "pendulum_child",
				"axis_parent_local": Vector3.BACK,
				"axis_child_local": Vector3.BACK,
				"anchor_parent_local": Vector3.ZERO,
				"anchor_child_local": Vector3(0.0, pivot_to_com, 0.0),
				"rest_child_rotation_parent_local": Quaternion.IDENTITY,
				"anchor_agreement_tolerance_m": 5.0e-3,
				"axis_agreement_tolerance_rad": 2.0e-2,
				"swing_tolerance_rad": 2.0e-2,
				"local_joint_scale_m": float(contract["link_length_m"]),
				"local_joint_scale_basis": "joint_fixture_extent_min_v1",
				"morphology_config_digest_sha256":
				"sha256:%s" % String(contract["configuration_sha256"]).sha256_text(),
				"requires_unwrapped_angle": false,
			}
		)
	)
	var binding_ok := bool(binding_build.get("ok", false))
	var binding: Dictionary = binding_build.get("binding", {})
	var fresh_world := viewport.own_world_3d and viewport.world_3d != root.world_3d

	# Exclude one tagged activation tick. Measurement time begins only after
	# the newly constructed physics space and hinge are live. Reapply the
	# authored pose while frozen, then release immediately before tick zero.
	await process_frame
	await physics_frame
	child.quaternion = Quaternion(Vector3.BACK, initial_angle)
	child.position = Vector3(
		pivot_to_com * sin(initial_angle), -pivot_to_com * cos(initial_angle), 0.0
	)
	child.linear_velocity = Vector3.ZERO
	child.angular_velocity = Vector3.ZERO
	child.freeze = false
	var samples: Array = []
	var live_samples_complete := binding_ok
	var step_s := 1.0 / float(contract["physics_hz"])
	var expected_count := int(contract["expected_sample_count"])
	for tick in expected_count:
		await physics_frame
		var parent_sample := _body_sample(
			"pendulum_parent",
			String(contract["trial_id"]),
			tick,
			step_s,
			parent.global_transform,
			Vector3.ZERO
		)
		var child_sample := _body_sample(
			"pendulum_child",
			String(contract["trial_id"]),
			tick,
			step_s,
			child.global_transform,
			child.angular_velocity
		)
		var state: Dictionary = JointStateScript.sample(binding, parent_sample, child_sample)
		live_samples_complete = (
			bool(state.get("finite", false))
			and bool(state.get("complete", false))
			and bool(state.get("observation_valid", false))
			and live_samples_complete
		)
		if not bool(state.get("complete", false)):
			continue
		(
			samples
			. append(
				{
					"time_s": float(tick + 1) * step_s,
					"angle_rad": float(state["wrapped_angle_rad"]),
					"axis_rate_rad_s": float(state["axis_rate_rad_s"]),
					"anchor_error_m": float(state["anchor_agreement_error_m"]),
					"axis_error_rad": float(state["axis_agreement_error_rad"]),
					"swing_residual_rad": float(state["swing_residual_rad"]),
					"off_axis_rate_rad_s": float(state["off_axis_rate_rad_s"]),
				}
			)
		)

	var analysis: Dictionary = PassivePendulumAnalyzerScript.analyze(contract, samples)
	var result: Dictionary = analysis.get("result", {})
	var fixture_result := {
		"fixture_complete":
		fresh_world and binding_ok and live_samples_complete and samples.size() == expected_count,
		"analysis_ok": bool(analysis.get("ok", false)),
		"analysis_failure": {} if bool(analysis.get("ok", false)) else analysis,
		"result": result,
		"samples": samples,
		"motor_enabled": joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR),
		"limit_enabled": joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT),
		"contact_enabled": child.collision_layer != 0 or child.collision_mask != 0,
		"parent_kind": parent.get_class(),
		"tagged_activation_tick_excluded": true,
	}
	viewport.queue_free()
	await physics_frame
	return fixture_result


func _test_configuration_refusals() -> void:
	var hidden_motor := _configuration("invalid_motor", "undamped_control", 0.0)
	hidden_motor["motor_enabled"] = true
	var hidden_limit := _configuration("invalid_limit", "undamped_control", 0.0)
	hidden_limit["limit_enabled"] = true
	var hidden_contact := _configuration("invalid_contact", "undamped_control", 0.0)
	hidden_contact["contact_enabled"] = true
	var mobile_parent := _configuration("invalid_parent", "undamped_control", 0.0)
	mobile_parent["parent_mode"] = "dynamic"
	var unknown_field := _configuration("invalid_field", "undamped_control", 0.0)
	unknown_field["motor_torque_nm"] = 1.0
	var mislabeled_damping := _configuration("invalid_damping", "undamped_control", 0.5)
	_check(
		(
			not bool(PassivePendulumAnalyzerScript.build(hidden_motor).get("ok", true))
			and not bool(PassivePendulumAnalyzerScript.build(hidden_limit).get("ok", true))
			and not bool(PassivePendulumAnalyzerScript.build(hidden_contact).get("ok", true))
		),
		"configuration rejects hidden motor, limit, and contact assistance"
	)
	_check(
		(
			not bool(PassivePendulumAnalyzerScript.build(mobile_parent).get("ok", true))
			and not bool(PassivePendulumAnalyzerScript.build(unknown_field).get("ok", true))
			and not bool(PassivePendulumAnalyzerScript.build(mislabeled_damping).get("ok", true))
		),
		"configuration rejects mobile parent, unknown fields, and false damping labels"
	)


func _test_analyzer_refusals(contract: Dictionary, source_samples: Array) -> void:
	var mutated_contract: Dictionary = contract.duplicate(true)
	mutated_contract["initial_angle_rad"] = 0.21
	var mutated_result: Dictionary = PassivePendulumAnalyzerScript.analyze(
		mutated_contract, source_samples
	)
	_check(
		(
			not bool(mutated_result.get("ok", true))
			and (
				String(mutated_result.get("failure_code", ""))
				== "PASSIVE_PENDULUM_CONTRACT_DIGEST_MISMATCH"
			)
		),
		"post-seal contract mutation fails closed"
	)

	var short_samples: Array = source_samples.duplicate(true)
	short_samples.pop_back()
	var short_result: Dictionary = PassivePendulumAnalyzerScript.analyze(contract, short_samples)
	_check(
		(
			not bool(short_result.get("ok", true))
			and (
				String(short_result.get("failure_code", ""))
				== "PASSIVE_PENDULUM_SAMPLE_COUNT_MISMATCH"
			)
		),
		"missing preregistered physics sample fails closed"
	)

	var nonfinite_samples: Array = source_samples.duplicate(true)
	(nonfinite_samples[4] as Dictionary)["angle_rad"] = NAN
	var nonfinite_result: Dictionary = PassivePendulumAnalyzerScript.analyze(
		contract, nonfinite_samples
	)
	_check(
		(
			not bool(nonfinite_result.get("ok", true))
			and (
				String(nonfinite_result.get("failure_code", ""))
				== "PASSIVE_PENDULUM_SAMPLE_NONFINITE"
			)
		),
		"nonfinite measured joint channel fails closed"
	)

	var mistimed_samples: Array = source_samples.duplicate(true)
	(mistimed_samples[10] as Dictionary)["time_s"] = (
		float((mistimed_samples[10] as Dictionary)["time_s"]) + 0.001
	)
	var mistimed_result: Dictionary = PassivePendulumAnalyzerScript.analyze(
		contract, mistimed_samples
	)
	_check(
		(
			not bool(mistimed_result.get("ok", true))
			and (
				String(mistimed_result.get("failure_code", ""))
				== "PASSIVE_PENDULUM_SAMPLE_SCHEDULE_MISMATCH"
			)
		),
		"plausible monotonic but off-schedule timestamps fail closed"
	)

	var negative_error_samples: Array = source_samples.duplicate(true)
	(negative_error_samples[8] as Dictionary)["anchor_error_m"] = -0.001
	var negative_result: Dictionary = PassivePendulumAnalyzerScript.analyze(
		contract, negative_error_samples
	)
	_check(
		(
			not bool(negative_result.get("ok", true))
			and (
				String(negative_result.get("failure_code", ""))
				== "PASSIVE_PENDULUM_ERROR_CHANNEL_NEGATIVE"
			)
		),
		"negative norm-like measurement channels fail closed"
	)


static func _configuration(
	trial_id: String, damping_class: String, angular_damp_s_inv: float
) -> Dictionary:
	return {
		"schema_version": "passive_pendulum_configuration_v1",
		"trial_id": trial_id,
		"physics_hz": PHYSICS_HZ,
		"duration_s": DURATION_S,
		"mass_kg": MASS_KG,
		"link_width_m": LINK_WIDTH_M,
		"link_length_m": LINK_LENGTH_M,
		"link_depth_m": LINK_DEPTH_M,
		"pivot_to_com_m": PIVOT_TO_COM_M,
		"gravity_m_s2": GRAVITY_M_S2,
		"initial_angle_rad": INITIAL_ANGLE_RAD,
		"angular_damp_s_inv": angular_damp_s_inv,
		"damping_class": damping_class,
		"parent_mode": "fixed_static",
		"motor_enabled": false,
		"limit_enabled": false,
		"external_torque_enabled": false,
		"contact_enabled": false,
	}


static func _body_sample(
	body_id: String,
	trial_id: String,
	tick: int,
	step_s: float,
	transform: Transform3D,
	angular_velocity: Vector3
) -> Dictionary:
	return {
		"schema_version": "mechanics_body_sample_v1",
		"physics_step_id": tick,
		"capture_epoch": tick,
		"sample_phase": "post_step",
		"step_s": step_s,
		"body_id": body_id,
		"run_id": "l2_0_%s" % trial_id,
		"capture_stream_id": "l2_0_passive_pendulum",
		"observer_profile_id": "l2_0_joint_frames_only",
		"observer_adapter_id": "node_post_step_joint_pair_v1",
		"finite":
		(
			transform.origin.is_finite()
			and transform.basis.x.is_finite()
			and transform.basis.y.is_finite()
			and transform.basis.z.is_finite()
			and angular_velocity.is_finite()
		),
		"transform":
		{
			"basis":
			[
				_vector3_array(transform.basis.x),
				_vector3_array(transform.basis.y),
				_vector3_array(transform.basis.z),
			],
			"origin": _vector3_array(transform.origin),
		},
		"angular_velocity": _vector3_array(angular_velocity),
	}


static func _vector3_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _print_result(label: String, trial: Dictionary) -> void:
	if not bool(trial.get("analysis_ok", false)):
		print(
			(
				"  %s analysis_failure=%s"
				% [
					label,
					str(trial.get("analysis_failure", {})),
				]
			)
		)
		return
	var result: Dictionary = trial["result"]
	print(
		(
			(
				"  %s accepted=%s samples=%d period=%.6f/%.6fs err=%.3f%% "
				+ "anchor=%.6fm axis/swing=%.6f/%.6frad off_axis=%.6frad/s "
				+ "initial=%.6frad rate=%.6frad/s energy_range=%.3f%% "
				+ "final_energy=%.3f%% amplitude=%.3f%% failures=%s"
			)
			% [
				label,
				str(bool(result["accepted"])),
				int(result["sample_count"]),
				float(result["mean_period_s"]),
				float(result["analytic_small_angle_period_s"]),
				100.0 * float(result["period_error_fraction"]),
				float(result["max_anchor_error_m"]),
				float(result["max_axis_error_rad"]),
				float(result["max_swing_residual_rad"]),
				float(result["max_off_axis_rate_rad_s"]),
				float(result["initial_measured_angle_rad"]),
				float(result["initial_rate_rad_s"]),
				100.0 * float(result["energy_range_fraction"]),
				100.0 * float(result["energy_final_fraction"]),
				100.0 * float(result["amplitude_retention_fraction"]),
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
