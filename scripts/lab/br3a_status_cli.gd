extends SceneTree

## Read-only BR3A commissioning/current-decision status printer.
##
## godot --headless --path . --script res://scripts/lab/br3a_status_cli.gd
## godot --headless --path . --script res://scripts/lab/br3a_status_cli.gd -- --json
##
## This command reconciles the byte-pinned historical commissioning snapshot
## with the append-only milestone-decision registry. It renders the result for
## a human or as one JSON object and never writes files. Exit codes: 0 when
## both records validate, 3 when the registry refuses, 4 on bad arguments.

const RegistryScript := preload(
	"res://scripts/lab/br3a_commissioning_registry.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var json_output := false
	for argument in arguments:
		if String(argument) == "--json":
			json_output = true
		else:
			printerr("BR3A_STATUS configuration_error=unknown argument: %s"
				% String(argument))
			quit(4)
			return
	var inspection: Dictionary = RegistryScript.inspect_current()
	if not bool(inspection.get("ok", false)):
		printerr("BR3A_STATUS registry=refused code=%s message=%s" % [
			String(inspection.get("failure_code", "UNKNOWN")),
			String(inspection.get("message", "")),
		])
		quit(3)
		return
	if json_output:
		print(CanonicalJsonScript.stringify({
			"schema": "sporespore.lab.br3a_status_cli_render.v1",
			"read_only": true,
			"inspection": inspection,
		}))
		quit(0)
		return
	_render_human(inspection)
	quit(0)


func _render_human(inspection: Dictionary) -> void:
	var status: Dictionary = inspection["status"]
	print("BR3A L1 formal status (read-only)")
	print("  historical commissioning snapshot: %s" % String(
		inspection["status_path"]))
	print("  snapshot sha256: %s" % String(inspection["status_sha256"]))
	print("  milestone decision: %s" % String(
		inspection["milestone_decision_id"]))
	print("  decision sha256: %s" % String(
		inspection["milestone_decision_sha256"]))
	print("")
	print("Implemented cells: %d/%d, %d commissioning assertions total" % [
		int(status["implemented_cell_count"]),
		int(status["planned_cell_count"]),
		int(status["commissioning_assertion_count"]),
	])
	for cell_value in status["cells"]:
		var cell: Dictionary = cell_value
		print("  %-5s %-30s %3d assertions" % [
			String(cell["cell_id"]),
			String(cell["commission_status"]),
			int(cell["assertion_count"]),
		])
	print("")
	print("Experimental sources pinned: %d (all SHA-256 verified: %s)" % [
		int(status["experimental_test_count"]),
		str(bool(inspection["experimental_source_pins_intact"])),
	])
	print("BR1 report-v2 guard intact: %s (%d released tests, overlap 0)" % [
		str(bool(inspection["report_v2_guard_intact"])),
		int(status["report_v2_guard"]["test_count"]),
	])
	print("")
	print("Formal status: %s" % String(inspection["formal_status"]))
	print("Current open promotion blockers (%d):" % (
		inspection["blocking_gates"] as Array).size())
	for gate_value in inspection["blocking_gates"]:
		print("  - %s" % String(gate_value))
	print("Historical snapshot blockers at commissioning time (%d):" % (
		inspection["snapshot_blocking_gates"] as Array).size())
	for gate_value in inspection["snapshot_blocking_gates"]:
		print("  - %s" % String(gate_value))
	print("Separate nonblocking work:")
	for work_value in status["promotion"]["separate_nonblocking_work"]:
		print("  - %s" % String(work_value))
	print("")
	var knowledge: Dictionary = status["knowledge"]
	print("Historical snapshot BR3A knowledge entries: %d" % int(
		knowledge["accepted_br3a_entries"]))
	print(("Current accepted BR3A knowledge entries: %d "
		+ "(%d milestone observations, %d supplementary constraint)") % [
		int(inspection["accepted_br3a_knowledge_entries"]),
		int(inspection["accepted_br3a_milestone_observations"]),
		int(inspection["accepted_br3a_supplementary_constraints"]),
	])
	print("Separate knowledge admission eligible: %s" % str(bool(
		inspection["knowledge_admission_eligible"])))
	print("Separate knowledge admission complete: %s" % str(bool(
		inspection["knowledge_admission_complete"])))
	print("Automatic creature guidance allowed: %s" % str(bool(
		inspection["automatic_creature_guidance_allowed"])))
	print("")
	print("Proven locomotion:")
	var locomotion: Dictionary = status["proven_locomotion"]
	var capability_names: Array = locomotion.keys()
	capability_names.sort()
	for capability_value in capability_names:
		print("  %-12s %s" % [
			String(capability_value),
			"yes" if bool(locomotion[capability_value]) else "no",
		])
	print("")
	print("Accepted decision still excludes:")
	for claim_value in inspection["formal_excluded_capabilities"]:
		print("  - %s" % String(claim_value))
	print("")
	print("Supplementary constraints:")
	for constraint_value in inspection["supplementary_constraints"]:
		print("  - %s" % String(constraint_value))
	print("")
	print("Formal claim boundary: %s" % String(
		inspection["formal_claim_boundary"]))
