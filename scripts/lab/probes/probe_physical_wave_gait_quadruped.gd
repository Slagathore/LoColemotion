extends SceneTree
# gdlint: disable=max-line-length

## Development probe for a continuously scheduled, motor-only physical
## quadruped. A positive result remains development evidence until an exact
## multi-seed contract, test, report, and attestation are commissioned.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var motor_direction_sign := -1.0
	var knee_motor_impulse_scale := 10.0
	var knee_flexion_scale := 1.75
	var gait_phase_order_id := "lateral"
	var swing_ticks := 72
	var contact_clearance_assist_rad := 0.40
	var contact_clearance_assist_limb_id := "all"
	var evidence_boundary_alignment_ticks := 112
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		motor_direction_sign = float(user_args[0])
	if user_args.size() >= 2:
		knee_motor_impulse_scale = float(user_args[1])
	if user_args.size() >= 3:
		knee_flexion_scale = float(user_args[2])
	if user_args.size() >= 4:
		gait_phase_order_id = String(user_args[3])
	if user_args.size() >= 5:
		swing_ticks = int(user_args[4])
	if user_args.size() >= 6:
		contact_clearance_assist_rad = float(user_args[5])
	if user_args.size() >= 7:
		contact_clearance_assist_limb_id = String(user_args[6])
	if user_args.size() >= 8:
		evidence_boundary_alignment_ticks = int(user_args[7])
	var result := await WaveGaitScript.new().run(
		self,
		motor_direction_sign,
		knee_motor_impulse_scale,
		knee_flexion_scale,
		gait_phase_order_id,
		swing_ticks,
		contact_clearance_assist_rad,
		contact_clearance_assist_limb_id,
		evidence_boundary_alignment_ticks
	)
	print(
		(
			(
				"score=%s order=%s swing=%d align=%d assist=%.3f/%s cycles=%s rejected=%s "
				+ "min_relocation=%s assist_ticks=%s "
				+ "evidence=%s final=%s lateral=%.6f yaw=%.6f tilt=%.6f "
				+ "anchor=%.6f hinge=%.6f gates=%s"
			)
			% [
				str(result.get("physical_wave_gait_walking_observed", false)),
				gait_phase_order_id,
				swing_ticks,
				evidence_boundary_alignment_ticks,
				contact_clearance_assist_rad,
				contact_clearance_assist_limb_id,
				str(result.get("contact_cycle_count_by_limb", {})),
				str(result.get("rejected_short_contact_cycle_count_by_limb", {})),
				str(result.get("minimum_cycle_relocation_by_limb_m", {})),
				str(result.get("contact_clearance_assist_tick_count_by_limb", {})),
				str(result.get("evidence_torso_displacement_world_m", Vector3(INF, INF, INF))),
				str(result.get("final_torso_displacement_world_m", Vector3(INF, INF, INF))),
				absf(
					(
						(
							result.get("final_torso_displacement_world_m", Vector3(INF, INF, INF))
							as Vector3
						)
						. z
					)
				),
				float(result.get("final_yaw_drift_rad", NAN)),
				float(result.get("maximum_tilt_rad", NAN)),
				float(result.get("maximum_anchor_error_m", NAN)),
				float(result.get("maximum_hinge_axis_error_rad", NAN)),
				str(result.get("walking_gate_receipts", {})),
			]
		)
	)
	print(
		(
			(
				"ok=%s failure=%s sign=%.1f knee=%.3f/%.3f order=%s swing=%d align=%d "
				+ "assist=%.3f/%s ticks=%d "
				+ "cycles=%s rejected=%s "
				+ "min_relocation=%s max_foot_h=%s absent=%s absent_dwell=%s "
				+ "contact_callbacks=%s transitions=%s "
				+ "evidence_displacement=%s final_displacement=%s "
				+ "height=%.6f/%.6f tilt=%.6f yaw=%.6f all4=%s torso_contact=%d "
				+ "motor_commands=%d motor_speed=%.6f measured_rate=%.6f "
				+ "anchor=%.6f hinge=%.6f gates=%s walking=%s claims=false"
			)
			% [
				str(result.get("ok", false)),
				String(result.get("failure_code", "")),
				motor_direction_sign,
				knee_motor_impulse_scale,
				knee_flexion_scale,
				gait_phase_order_id,
				swing_ticks,
				evidence_boundary_alignment_ticks,
				contact_clearance_assist_rad,
				contact_clearance_assist_limb_id,
				int(result.get("executed_ticks", 0)),
				str(result.get("contact_cycle_count_by_limb", {})),
				str(result.get("rejected_short_contact_cycle_count_by_limb", {})),
				str(result.get("minimum_cycle_relocation_by_limb_m", {})),
				str(result.get("maximum_foot_center_height_by_limb_m", {})),
				str(result.get("contact_absent_tick_count_by_limb", {})),
				str(result.get("longest_contact_absent_dwell_by_limb_ticks", {})),
				str(result.get("contact_observer_callback_count_by_limb", {})),
				str(result.get("contact_transition_receipts_by_limb", {})),
				str(result.get("evidence_torso_displacement_world_m", Vector3(INF, INF, INF))),
				str(result.get("final_torso_displacement_world_m", Vector3(INF, INF, INF))),
				float(result.get("minimum_torso_height_m", NAN)),
				float(result.get("final_torso_height_m", NAN)),
				float(result.get("maximum_tilt_rad", NAN)),
				float(result.get("final_yaw_drift_rad", NAN)),
				str(result.get("terminal_all_four_contacts", false)),
				int(result.get("torso_contact_ticks", 0)),
				int(result.get("motor_command_count", 0)),
				float(result.get("maximum_motor_target_speed_rad_s", NAN)),
				float(result.get("maximum_measured_joint_speed_rad_s", NAN)),
				float(result.get("maximum_anchor_error_m", NAN)),
				float(result.get("maximum_hinge_axis_error_rad", NAN)),
				str(result.get("walking_gate_receipts", {})),
				str(result.get("physical_wave_gait_walking_observed", false)),
			]
		)
	)
	quit(0 if bool(result.get("physical_wave_gait_walking_observed", false)) else 2)
