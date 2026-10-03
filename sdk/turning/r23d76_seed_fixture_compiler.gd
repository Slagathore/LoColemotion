extends SceneTree

## Pure zero-world compiler for the prospectively reserved R23D76 held-out
## perturbation. It calls only the canonical deterministic perturbation
## compiler and exits before any model, body, fixture, physics server, or world
## can exist.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const R23D76_HELD_OUT_SEEDS := [23197]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var compiled: Array[Dictionary] = []
	for seed in R23D76_HELD_OUT_SEEDS:
		var result: Dictionary = WaveGaitScript.compile_seeded_initial_perturbation(seed)
		if not bool(result.get("ok", false)):
			printerr("QSDK_R23D76_SEED_FIXTURE_FAILURE ", JSON.stringify(result, "", true, true))
			quit(1)
			return
		var value: Dictionary = result["initial_perturbation"]
		var linear: Vector3 = value["initial_linear_velocity_world_m_s"]
		var angular: Vector3 = value["initial_torso_angular_velocity_world_rad_s"]
		compiled.append(
			{
				"campaign_seed": int(value["campaign_seed"]),
				"cohort": "r23d76_unopened_three_engine_held_out_turning",
				"fixture_vertical_clearance_m": float(value["fixture_vertical_clearance_m"]),
				"fixture_yaw_rad": float(value["fixture_yaw_rad"]),
				"initial_linear_velocity_world_m_s": [linear.x, linear.y, linear.z],
				"initial_torso_angular_velocity_world_rad_s": [
					angular.x, angular.y, angular.z
				],
				"gait_phase_offset_ticks": int(value["gait_phase_offset_ticks"]),
			}
		)
	print(
		"QSDK_R23D76_SEED_FIXTURES ",
		JSON.stringify(
			{
				"schema_version": "sporespore_qsdk_r23d76_seed_fixtures_v1",
				"r23d76_unopened_held_out_seeds": R23D76_HELD_OUT_SEEDS,
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"fixtures": compiled,
			},
			"",
			true,
			true
		)
	)
	quit(0)
