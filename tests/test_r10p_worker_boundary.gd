extends SceneTree
# gdlint: disable=max-line-length

## Invoke real worker hooks with synthetic retained fields. No worker launch,
## SDK construction, body construction or physics stepping occurs here.
const Worker := preload("res://sdk/adapters/godot/gdscript/r10p_campaign_worker_v1.gd")
const Facade := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

class Probe:
	extends "res://sdk/adapters/godot/gdscript/r10p_campaign_worker_v1.gd"
	func _initialize() -> void: pass

class HistoricalProbe:
	extends "res://sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd"
	func _initialize() -> void: pass

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1: quit(1); return
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var probe := Probe.new()
	var prior := HistoricalProbe.new()
	probe._candidate_selection = Worker.CandidateProfile.load_v1(input.candidate)
	prior._candidate_selection = Worker.CandidateProfile.load_v1(input.original_candidate)
	var checks := {"candidate_loads": not probe._candidate_selection.is_empty(),
		"historical_candidate_loads": not prior._candidate_selection.is_empty()}
	if not checks.candidate_loads or not checks.historical_candidate_loads:
		print("R10P_WORKER_BOUNDARY "+Transport.stringify({"checks": checks})); quit(1); return
	var phases := {}
	var publications := {}
	var retained_fields := ["schema_version", "work_id", "passive_entry", "finite_recovery_task", "stance_entry",
		"r10k_partial_recovery", "development_cycle_stop", "development_walking_entry", "development_native_walking_contacts"]
	for name in input.cases:
		var item: Dictionary = input.cases[name]
		probe._seed = int(item.seed_text)
		probe._campaign_declaration = item.declaration.duplicate(true)
		probe._candidate_mode = item.declaration.development_execution_mode
		probe._authorized_arm_id = item.role
		probe._entry_packets = [{"synthetic_retention_marker": 7.000000000000001}]
		prior._entry_packets = probe._entry_packets.duplicate(true)
		var prefix: String = probe._walking_prefix_profile_id_v1("walking_prefix")
		phases[name] = Facade.initial_gait_steps_v1(probe._seed, "walking_prefix", "", prefix)
		checks[name+"_worker"] = probe._entry_selection_v1().worker == Worker.R10PSeed.WORKER
		checks[name+"_resume_prefix_empty"] = probe._walking_prefix_profile_id_v1("walking_resume").is_empty()
		var descriptors: Array = item.declaration.children.filter(func(child): return child.role == item.role)
		var report := {"ok": true, "seed": probe._seed, "arm_id": item.role,
			"parent_attempt_id": item.declaration.attempt_id, "child_attempt_id": descriptors[0].child_attempt_id,
			"source_commit": item.source_commit, "solver_step_count": 0, "stop_reason": "synthetic_boundary_fixture",
			"ledger_scope": {"subsystem": "recovery", "engine_scope": "godot_jolt"}}
		var before := report.duplicate(true)
		probe._attach_entry_retention_v1(report)
		publications[name] = report
		# The old publisher is expected to reject the new campaign context. Its
		# physical serializer still runs; compare those fields, never its verdict.
		prior._seed = 40741
		prior._authorized_arm_id = item.role
		prior._candidate_mode = probe._candidate_mode
		prior._attach_entry_retention_v1(before)
		before.passive_entry.candidate_profile = report.passive_entry.candidate_profile
		var same := true
		for field in retained_fields:
			same = same and Transport.stringify(before.get(field)) == Transport.stringify(report.get(field))
		checks[name+"_physical_retention_unchanged"] = same
		var bad: Dictionary = report.duplicate(true)
		bad.child_attempt_id = "crossed-child"
		probe._attach_entry_retention_v1(bad)
		checks[name+"_publication_refuses_crossed_child"] = bad.ok == false and bad.failure_code == "R10P_CAMPAIGN_PUBLICATION_CONTEXT_INVALID"
	var launch: Dictionary = input.launch
	probe._campaign_declaration = launch.declaration
	probe._seed = int(launch.seed_text)
	var child: Dictionary = launch.declaration.children[0]
	var environment := {Worker.CHILD_ROLE_ENV: launch.role, Worker.PARENT_ATTEMPT_ID_ENV: launch.declaration.attempt_id,
		Worker.ATTEMPT_ID_ENV: child.child_attempt_id, Worker.NONCE_ENV: child.termination_nonce,
		Worker.SOURCE_COMMIT_ENV: launch.source_commit}
	for key in environment: OS.set_environment(key, environment[key])
	checks["bound_development_launch_accepted"] = probe._authorized_seed_binding_v1(launch.seed_text, launch.label, launch.digest)
	for key in environment:
		OS.set_environment(key, "crossed-value")
		checks["refuses_"+key] = not probe._authorized_seed_binding_v1(launch.seed_text, launch.label, launch.digest)
		OS.set_environment(key, environment[key])
	probe._campaign_declaration.r10p_campaign.claim_binding.raw_sha256 = "sha256:"+"0".repeat(64)
	checks["changed_claim_refused"] = not probe._authorized_seed_binding_v1(launch.seed_text, launch.label, launch.digest)
	for key in environment: OS.unset_environment(key)
	probe.free()
	prior.free()
	print("R10P_WORKER_BOUNDARY "+Transport.stringify({"checks": checks, "phases": phases,
		"publications": publications, "world_build_count": 0, "solver_step_count": 0}))
	quit(0)
