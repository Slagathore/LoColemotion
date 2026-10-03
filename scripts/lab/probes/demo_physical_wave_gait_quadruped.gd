extends SceneTree

## Visible presentation wrapper around the current best structurally bounded
## physical wave-gait candidate. This is deliberately labeled as development
## evidence until every limb repeats its accepted contact cycle and the exact
## multi-seed contract/report/attestation path passes.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := await WaveGaitScript.new().run(
		self, -1.0, 10.0, 1.75, "lateral", 72, 0.40, "all", 112, true
	)
	print(
		(
			"demo_complete displacement=%s cycles=%s walking=%s claims=false"
			% [
				str(result.get("final_torso_displacement_world_m", Vector3.ZERO)),
				str(result.get("contact_cycle_count_by_limb", {})),
				str(result.get("physical_wave_gait_walking_observed", false)),
			]
		)
	)
	await create_timer(2.0).timeout
	quit(0)
