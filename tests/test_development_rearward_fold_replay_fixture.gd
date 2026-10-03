extends "res://tests/test_development_rearward_fold_worker_hooks.gd"

const Exporter := preload("res://tests/test_development_passive_entry_replay_fixture.gd")

func _finish(probe: SceneTree, failure: Dictionary) -> void:
	var exported := Exporter.export_v1(probe, checks, failure)
	print("DEVELOPMENT_REARWARD_FOLD_REPLAY_FIXTURE ", Transport.stringify(exported))
	probe._sdk = null
	probe.free()
	quit(0 if exported["ok"] else 1)
