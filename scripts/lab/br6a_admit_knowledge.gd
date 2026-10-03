extends SceneTree
# gdlint: disable=max-returns

## Fixed, append-only BR6A observation admission.
##
## Dry run:
## godot --headless --path . --script \
##   res://scripts/lab/br6a_admit_knowledge.gd -- --dry-run
##
## Admission:
## godot --headless --path . --script \
##   res://scripts/lab/br6a_admit_knowledge.gd
##
## No caller-supplied claim, evidence, output path, status, or guidance policy
## is accepted.

const Br6aKnowledgeBaseScript := preload("res://scripts/lab/br6a_knowledge_base.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var dry_run := false
	if arguments.size() == 1 and String(arguments[0]) == "--dry-run":
		dry_run = true
	elif not arguments.is_empty():
		printerr("BR6A_KNOWLEDGE configuration_error=only --dry-run is supported")
		quit(4)
		return
	var proposal := Br6aKnowledgeBaseScript.propose_all()
	if not bool(proposal.get("ok", false)):
		_print_blocked(proposal)
		quit(3)
		return
	var plan := Br6aKnowledgeBaseScript.output_plan()
	if not bool(plan.get("ok", false)):
		_print_blocked(plan)
		quit(3)
		return
	var entries: Array = proposal["entries"]
	var outputs: Array = plan["outputs"]
	if entries.size() != outputs.size():
		printerr("BR6A_KNOWLEDGE admission=blocked code=PLAN_SIZE_MISMATCH")
		quit(3)
		return
	for output_value in outputs:
		var output: Dictionary = output_value
		var absolute := ProjectSettings.globalize_path(String(output["path"]))
		if FileAccess.file_exists(absolute) or DirAccess.dir_exists_absolute(absolute):
			printerr(
				(
					"BR6A_KNOWLEDGE admission=blocked "
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
						"schema": "sporespore.lab.br6a_knowledge_admission_dry_run.v1",
						"ok": true,
						"read_only": true,
						"entry_count": entries.size(),
						"milestone_observation_count": entries.size(),
						"minimal_repair_rule_count": 0,
						"automatic_creature_guidance_allowed": false,
						"automatic_application_allowed": false,
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
		var write := Br6aKnowledgeBaseScript.write_new_entry(String(output["path"]), entry)
		if not bool(write.get("ok", false)):
			printerr(
				(
					"BR6A_KNOWLEDGE write=failed entry_id=%s code=%s"
					% [
						String(entry["entry_id"]),
						String(write.get("failure_code", write.get("code", "UNKNOWN"))),
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
					"schema": "sporespore.lab.br6a_knowledge_admission_result.v1",
					"ok": true,
					"entry_count": writes.size(),
					"minimal_repair_rule_count": 0,
					"automatic_creature_guidance_allowed": false,
					"automatic_application_allowed": false,
					"writes": writes,
				}
			)
		)
	)
	quit(0)


static func _print_blocked(result: Dictionary) -> void:
	printerr(
		(
			"BR6A_KNOWLEDGE admission=blocked code=%s message=%s"
			% [
				String(result.get("failure_code", result.get("code", "UNKNOWN"))),
				String(result.get("message", "")),
			]
		)
	)
	if result.get("details") != null:
		printerr("BR6A_KNOWLEDGE details=%s" % CanonicalJsonScript.stringify(result["details"]))
