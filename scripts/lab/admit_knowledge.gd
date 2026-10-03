extends SceneTree

## Append-only knowledge admission CLI.
##
## godot --headless --path . --script res://scripts/lab/admit_knowledge.gd -- \
##   --bundle "$env:TEMP\sporespore_locomotion_bootstrap\...\runs\<run_id>" \
##   --draft res://data/lab/knowledge/drafts/my_finding.json \
##   --output res://data/lab/knowledge/entries/my_finding.json \
##   --status development_observation

const KnowledgeBaseScript := preload("res://scripts/lab/knowledge_base.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed := _parse_arguments(OS.get_cmdline_user_args())
	if not parsed["ok"]:
		printerr("KNOWLEDGE configuration_error=%s" % parsed["error"])
		quit(4)
		return
	var options: Dictionary = parsed["options"]
	var draft_path := String(options["draft"])
	if not FileAccess.file_exists(draft_path):
		printerr("KNOWLEDGE configuration_error=draft does not exist")
		quit(4)
		return
	var draft: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(draft_path))
	if not draft is Dictionary:
		printerr("KNOWLEDGE configuration_error=draft is not one JSON object")
		quit(4)
		return
	var proposal: Dictionary = KnowledgeBaseScript.propose_from_bundle(
		String(options["bundle"]),
		draft,
		String(options["status"]))
	if not proposal["ok"]:
		printerr("KNOWLEDGE admission=blocked code=%s message=%s" % [
			proposal.get("code", "UNKNOWN"),
			proposal.get("message", ""),
		])
		quit(3)
		return
	var write: Dictionary = KnowledgeBaseScript.write_new_entry(
		String(options["output"]), proposal["entry"])
	if not write["ok"]:
		printerr("KNOWLEDGE write=failed code=%s" % write.get("code", "UNKNOWN"))
		quit(5)
		return
	print("KNOWLEDGE admission=recorded status=%s entry_id=%s" % [
		proposal["entry"]["claim_status"],
		proposal["entry"]["entry_id"],
	])
	print("KNOWLEDGE path=%s sha256=%s" % [write["path"], write["sha256"]])
	quit(0)


static func _parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var options := {
		"status": "development_observation",
	}
	var seen: Dictionary = {}
	var index := 0
	while index < arguments.size():
		var name := String(arguments[index])
		if name not in ["--bundle", "--draft", "--output", "--status"]:
			return _failure("unknown argument: %s" % name)
		if index + 1 >= arguments.size():
			return _failure("missing value for %s" % name)
		if seen.has(name):
			return _failure("duplicate argument: %s" % name)
		seen[name] = true
		options[name.trim_prefix("--")] = String(arguments[index + 1])
		index += 2
	for required in ["bundle", "draft", "output"]:
		if not options.has(required):
			return _failure("--%s is required" % required)
	var output := String(options["output"])
	var output_root := "res://data/lab/knowledge/entries/"
	var output_name := output.trim_prefix(output_root)
	if (
		not output.begins_with(output_root)
		or not output.ends_with(".json")
		or output.contains("..")
		or output_name.is_empty()
		or output_name.contains("/")
		or output_name.contains("\\")
	):
		return _failure(
			"--output must be one new JSON file directly under res://data/lab/knowledge/entries/")
	return {"ok": true, "options": options}


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "options": {}}
