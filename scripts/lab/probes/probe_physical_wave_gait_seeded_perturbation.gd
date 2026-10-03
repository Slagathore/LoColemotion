extends SceneTree
# gdlint: disable=max-line-length

## Development-only perturbation ablation probe. The first argument is a
## positive campaign seed; the optional second argument is one of:
## all, pose, clearance, yaw, linear, angular, phase. This probe never
## authorizes a claim.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var user_args := OS.get_cmdline_user_args()
	if user_args.is_empty():
		printerr("seed argument required")
		quit(2)
		return
	var campaign_seed := int(user_args[0])
	var ablation_id := String(user_args[1]) if user_args.size() >= 2 else "all"
	var contact_gated := user_args.size() >= 3 and String(user_args[2]) == "gated"
	var robustness_options := {}
	if contact_gated:
		robustness_options = {
			"contact_gated_phase_progression": true,
			"maximum_contact_gate_hold_ticks": 96,
			"maximum_contact_gated_phase_skew_ticks": 12,
			"lateral_stride_steering_gain_per_m": 0.5,
		}
	var perturbation_result := WaveGaitScript.compile_seeded_initial_perturbation(campaign_seed)
	if not bool(perturbation_result.get("ok", false)):
		printerr("perturbation_compile=", perturbation_result)
		quit(2)
		return
	var realized_perturbation: Dictionary = perturbation_result["initial_perturbation"]
	var perturbation := realized_perturbation.duplicate(true)
	match ablation_id:
		"all":
			pass
		"pose":
			perturbation["initial_linear_velocity_world_m_s"] = Vector3.ZERO
			perturbation["initial_torso_angular_velocity_world_rad_s"] = Vector3.ZERO
			perturbation["gait_phase_offset_ticks"] = 0
		"clearance":
			_zero_perturbation_except_seed(perturbation)
			perturbation["fixture_vertical_clearance_m"] = (realized_perturbation["fixture_vertical_clearance_m"])
		"yaw":
			_zero_perturbation_except_seed(perturbation)
			perturbation["fixture_yaw_rad"] = realized_perturbation["fixture_yaw_rad"]
		"linear":
			_zero_perturbation_except_seed(perturbation)
			perturbation["initial_linear_velocity_world_m_s"] = (realized_perturbation["initial_linear_velocity_world_m_s"])
		"angular":
			_zero_perturbation_except_seed(perturbation)
			perturbation["initial_torso_angular_velocity_world_rad_s"] = (realized_perturbation["initial_torso_angular_velocity_world_rad_s"])
		"phase":
			_zero_perturbation_except_seed(perturbation)
			perturbation["gait_phase_offset_ticks"] = (realized_perturbation["gait_phase_offset_ticks"])
		_:
			printerr("unknown ablation_id=", ablation_id)
			quit(2)
			return
	var summary := await (WaveGaitScript.new().run(
		self,
		-1.0,
		10.0,
		1.75,
		"lateral",
		72,
		0.40,
		"all",
		112,
		false,
		perturbation,
		robustness_options
	))
	print(
		(
			(
				"PERTURBATION_SCORE seed=%d ablation=%s gated=%s walking=%s perturbation=%s "
				+ "cycles=%s rejected=%s relocation=%s evidence=%s final=%s "
				+ "yaw=%.9f tilt=%.9f anchor=%.9f hinge=%.9f holds=%s timeouts=%s "
				+ "steering_adjustments=%d steering_fraction=%.9f gates=%s"
			)
			% [
				campaign_seed,
				ablation_id,
				str(contact_gated),
				str(summary.get("physical_wave_gait_walking_observed", false)),
				str(perturbation),
				str(summary.get("contact_cycle_count_by_limb", {})),
				str(summary.get("rejected_short_contact_cycle_count_by_limb", {})),
				str(summary.get("minimum_cycle_relocation_by_limb_m", {})),
				str(summary.get("evidence_torso_displacement_world_m", Vector3.ZERO)),
				str(summary.get("final_torso_displacement_world_m", Vector3.ZERO)),
				float(summary.get("final_yaw_drift_rad", NAN)),
				float(summary.get("maximum_tilt_rad", NAN)),
				float(summary.get("maximum_anchor_error_m", NAN)),
				float(summary.get("maximum_hinge_axis_error_rad", NAN)),
				str(summary.get("contact_gate_hold_tick_count_by_limb", {})),
				str(summary.get("contact_gate_timeout_count_by_limb", {})),
				int(summary.get("lateral_stride_steering_target_adjustment_count", 0)),
				float(summary.get("maximum_absolute_lateral_stride_steering_fraction", NAN)),
				str(summary.get("walking_gate_receipts", {})),
			]
		)
	)
	print("PERTURBATION_TRANSITIONS ", summary.get("contact_transition_receipts_by_limb", {}))
	quit(0 if bool(summary.get("physical_wave_gait_walking_observed", false)) else 1)


static func _zero_perturbation_except_seed(perturbation: Dictionary) -> void:
	perturbation["fixture_vertical_clearance_m"] = 0.0
	perturbation["fixture_yaw_rad"] = 0.0
	perturbation["initial_linear_velocity_world_m_s"] = Vector3.ZERO
	perturbation["initial_torso_angular_velocity_world_rad_s"] = Vector3.ZERO
	perturbation["gait_phase_offset_ticks"] = 0
