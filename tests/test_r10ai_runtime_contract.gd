extends "res://tests/test_development_r10r_contract.gd"
## Explicit diagnostic host selection before the unchanged zero-world contract.
## Selection itself grants no native world permission.
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		quit(1)
		return
	var reference := {"resource": args[0], "raw_sha256": args[1]}
	var declaration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[2]))
	var selected := Replay.Canonical.Route.ProfileCapabilityScript.select_r10ai_diagnostic_runtime_v1(declaration, reference)
	if selected.get("ok") != true or selected.get("physical_execution_authorized") != false:
		print("DEVELOPMENT_RECOVERY_CANDIDATE_CONTRACT ", Transport.stringify({"ok": false, "checks": {"explicit_diagnostic_host": false}, "detail": selected}))
		quit(1)
		return
	super._run()
