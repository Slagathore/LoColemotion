extends SceneTree
# gdlint: disable=max-returns

## Fixed, append-only BR3A observation admission.
##
## Dry run:
## godot --headless --path . --script \
##   res://scripts/lab/br3a_admit_knowledge.gd -- --dry-run
##
## Admission:
## godot --headless --path . --script \
##   res://scripts/lab/br3a_admit_knowledge.gd
##
## No caller-supplied draft, evidence, status, output, or claim is accepted.

const Br3aKnowledgeBaseScript := preload("res://scripts/lab/br3a_knowledge_base.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var dry_run := false
	if arguments.size() == 1 and String(arguments[0]) == "--dry-run":
		dry_run = true
	elif not arguments.is_empty():
		printerr("BR3A_KNOWLEDGE configuration_error=only --dry-run is supported")
		quit(4)
		return
	var proposal := Br3aKnowledgeBaseScript.propose_all()
	if not bool(proposal.get("ok", false)):
		printerr(
			(
				"BR3A_KNOWLEDGE admission=blocked code=%s message=%s"
				% [
					String(proposal.get("failure_code", "UNKNOWN")),
					String(proposal.get("message", "")),
				]
			)
		)
		if proposal.get("details") != null:
			printerr(
				"BR3A_KNOWLEDGE details=%s" % (CanonicalJsonScript.stringify(proposal["details"]))
			)
		quit(3)
		return
	var plan := Br3aKnowledgeBaseScript.output_plan()
	if not bool(plan.get("ok", false)):
		printerr(
			"BR3A_KNOWLEDGE admission=blocked code=%s" % String(plan.get("failure_code", "UNKNOWN"))
		)
		quit(3)
		return
	var entries: Array = proposal["entries"]
	var outputs: Array = plan["outputs"]
	if entries.size() != outputs.size():
		printerr("BR3A_KNOWLEDGE admission=blocked code=PLAN_SIZE_MISMATCH")
		quit(3)
		return
	for output_value in outputs:
		var output: Dictionary = output_value
		var absolute := ProjectSettings.globalize_path(String(output["path"]))
		if FileAccess.file_exists(absolute) or DirAccess.dir_exists_absolute(absolute):
			printerr(
				(
					"BR3A_KNOWLEDGE admission=blocked "
					+ "code=KNOWLEDGE_ENTRY_ALREADY_EXISTS path=%s" % String(output["path"])
				)
			)
			quit(5)
			return
	if dry_run:
		print(
			(
				CanonicalJsonScript
				. stringify(
					{
						"schema": "sporespore.lab.br3a_knowledge_admission_dry_run.v1",
						"ok": true,
						"read_only": true,
						"entry_count": entries.size(),
						"milestone_observation_count":
						_count_class(entries, "milestone_observation"),
						"supplementary_constraint_count":
						_count_class(entries, "supplementary_constraint"),
						"automatic_creature_guidance_allowed": false,
						"outputs": outputs,
					}
				)
			)
		)
		quit(0)
		return
	var writes: Array = []
	for index in range(entries.size()):
		var output: Dictionary = outputs[index]
		var entry: Dictionary = entries[index]
		var write := Br3aKnowledgeBaseScript.write_new_entry(String(output["path"]), entry)
		if not bool(write.get("ok", false)):
			printerr(
				(
					"BR3A_KNOWLEDGE write=failed entry_id=%s code=%s"
					% [
						String(entry["entry_id"]),
						String(write.get("failure_code", "UNKNOWN")),
					]
				)
			)
			quit(5)
			return
		(
			writes
			. append(
				{
					"entry_id": entry["entry_id"],
					"path": write["path"],
					"sha256": write["sha256"],
				}
			)
		)
	print(
		(
			CanonicalJsonScript
			. stringify(
				{
					"schema": "sporespore.lab.br3a_knowledge_admission_result.v1",
					"ok": true,
					"entry_count": writes.size(),
					"automatic_creature_guidance_allowed": false,
					"writes": writes,
				}
			)
		)
	)
	quit(0)


static func _count_class(entries: Array, requested_class: String) -> int:
	var count := 0
	for entry_value in entries:
		if String((entry_value as Dictionary)["knowledge_class"]) == requested_class:
			count += 1
	return count
