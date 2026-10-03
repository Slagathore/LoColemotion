extends SceneTree

## Zero-world compiler for the prospectively selected R23D33 native-transfer seed.
## This calls only the pure perturbation compiler and exits before any model,
## body, fixture, or physics world can be constructed.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const CAMPAIGN_SEEDS := [21507]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var compiled: Array[Dictionary] = []
	for seed in CAMPAIGN_SEEDS:
		var result: Dictionary = WaveGaitScript.compile_seeded_initial_perturbation(seed)
		if not bool(result.get("ok", false)):
			printerr("QSDK_R23D33_SEED_FIXTURE_FAILURE ", JSON.stringify(result))
			quit(1)
			return
		var value: Dictionary = result["initial_perturbation"]
		var linear: Vector3 = value["initial_linear_velocity_world_m_s"]
		var angular: Vector3 = value["initial_torso_angular_velocity_world_rad_s"]
		compiled.append(
			{
				"campaign_seed": int(value["campaign_seed"]),
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
		"QSDK_R23D33_SEED_FIXTURES ",
		JSON.stringify(
			{
				"schema_version": "sporespore_qsdk_r23d33_seed_fixtures_v1",
				"world_build_count": 0,
				"model_construction_count": 0,
				"fixtures": compiled,
			}
		)
	)
	quit(0)
