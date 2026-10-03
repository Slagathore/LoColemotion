class_name LabKnowledgeQuery
extends RefCounted

## Deterministic retrieval for morphology-neutral guidance. Automatic repair
## uses accepted entries only by default; development observations require an
## explicit opt-in and remain labeled in every returned rule.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const KnowledgeBaseScript := preload("res://scripts/lab/knowledge_base.gd")


static func load_entries(
	directory: String, include_development := false, validation_options: Dictionary = {}
) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(directory)
	var access := DirAccess.open(absolute)
	if access == null:
		return {
			"ok": false,
			"code": "KNOWLEDGE_DIRECTORY_MISSING",
			"entries": [],
			"errors": [],
		}
	var entries: Array = []
	var errors: Array = []
	var names: Array[String] = []
	for name in access.get_files():
		if name.ends_with(".json"):
			names.append(name)
	names.sort()
	var seen_ids: Dictionary = {}
	for name in names:
		var path := absolute.path_join(name)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			(
				errors
				. append(
					{
						"code": "KNOWLEDGE_JSON_INVALID",
						"path": path,
					}
				)
			)
			continue
		var verification := KnowledgeBaseScript.verify_entry(parsed, false, validation_options)
		if not verification["ok"]:
			(
				errors
				. append(
					{
						"code": "KNOWLEDGE_ENTRY_UNTRUSTED",
						"path": path,
						"details": verification,
					}
				)
			)
			continue
		var entry_id := String(parsed["entry_id"])
		if seen_ids.has(entry_id):
			(
				errors
				. append(
					{
						"code": "KNOWLEDGE_ENTRY_ID_DUPLICATE",
						"path": path,
						"entry_id": entry_id,
					}
				)
			)
			continue
		seen_ids[entry_id] = FrozenValueScript.snapshot(parsed)

	var superseded_by: Dictionary = {}
	var graph: Dictionary = {}
	for entry_id_value in seen_ids:
		var entry_id := String(entry_id_value)
		var entry: Dictionary = seen_ids[entry_id_value]
		var prior_ids: Array = entry.get("supersedes", [])
		graph[entry_id] = prior_ids
		for prior_id_value in prior_ids:
			var prior_id := String(prior_id_value)
			if prior_id == entry_id:
				(
					errors
					. append(
						{
							"code": "KNOWLEDGE_SELF_SUPERSESSION",
							"entry_id": entry_id,
						}
					)
				)
			elif not seen_ids.has(prior_id):
				(
					errors
					. append(
						{
							"code": "KNOWLEDGE_SUPERSEDED_ENTRY_MISSING",
							"entry_id": entry_id,
							"superseded_entry_id": prior_id,
						}
					)
				)
			if String(entry["claim_status"]) == "development_observation":
				continue
			if superseded_by.has(prior_id) and String(superseded_by[prior_id]) != entry_id:
				(
					errors
					. append(
						{
							"code": "KNOWLEDGE_SUPERSESSION_AMBIGUOUS",
							"superseded_entry_id": prior_id,
							"successors":
							[
								superseded_by[prior_id],
								entry_id,
							],
						}
					)
				)
			else:
				superseded_by[prior_id] = entry_id
	if _has_supersession_cycle(graph):
		(
			errors
			. append(
				{
					"code": "KNOWLEDGE_SUPERSESSION_CYCLE",
				}
			)
		)

	if errors.is_empty():
		for entry_id_value in seen_ids:
			var entry_id := String(entry_id_value)
			if superseded_by.has(entry_id):
				continue
			var entry: Dictionary = seen_ids[entry_id_value]
			if (
				entry["claim_status"] == "accepted"
				or (include_development and entry["claim_status"] == "development_observation")
			):
				entries.append(entry)
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a["entry_id"]) < String(b["entry_id"])
	)
	var superseded_ids: Array = superseded_by.keys()
	superseded_ids.sort()
	return {
		"ok": errors.is_empty(),
		"entries": entries,
		"errors": errors,
		"include_development": include_development,
		"superseded_entry_ids": superseded_ids,
	}


static func repair_candidates(
	entries: Array,
	morphology_tags: Array,
	symptom_query: String,
	validation_options: Dictionary = {}
) -> Array:
	var normalized_query := symptom_query.strip_edges().to_lower()
	var requested_tags: Array[String] = []
	for tag in morphology_tags:
		requested_tags.append(String(tag))
	requested_tags.sort()
	var candidates: Array = []
	for entry_value in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var verification := KnowledgeBaseScript.verify_entry(entry, false, validation_options)
		if not verification["ok"]:
			continue
		if (
			String(entry.get("claim_status", ""))
			not in [
				"accepted",
				"development_observation",
			]
		):
			continue
		var automatic_application_allowed := String(entry.get("claim_status", "")) == "accepted"
		if entry.has("guidance_policy"):
			var guidance_value: Variant = entry["guidance_policy"]
			if not guidance_value is Dictionary:
				continue
			automatic_application_allowed = (
				automatic_application_allowed
				and bool((guidance_value as Dictionary).get("automatic_application_allowed", false))
			)
		var entry_tags: Array = entry.get("morphology_tags", [])
		var matching_tags: Array[String] = []
		for tag in requested_tags:
			if entry_tags.has(tag) or entry_tags.has("body_agnostic"):
				matching_tags.append(tag)
		if not requested_tags.is_empty() and matching_tags.is_empty():
			continue
		for rule_value in entry.get("minimal_repair_rules", []):
			if not rule_value is Dictionary:
				continue
			var rule: Dictionary = rule_value
			var symptom := String(rule.get("symptom", ""))
			if (
				not normalized_query.is_empty()
				and not symptom.to_lower().contains(normalized_query)
			):
				continue
			(
				candidates
				. append(
					(
						FrozenValueScript
						. snapshot(
							{
								"entry_id": entry["entry_id"],
								"claim_status": entry["claim_status"],
								"evidence_run_id": entry["evidence"]["run_id"],
								"matching_morphology_tags": matching_tags,
								"rule": rule,
								"provenance_verified": true,
								"automatic_application_allowed": automatic_application_allowed,
							}
						)
					)
				)
			)
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_allowed := bool(a["automatic_application_allowed"])
			var b_allowed := bool(b["automatic_application_allowed"])
			if a_allowed != b_allowed:
				return a_allowed
			var a_matches := int(a["matching_morphology_tags"].size())
			var b_matches := int(b["matching_morphology_tags"].size())
			if a_matches != b_matches:
				return a_matches > b_matches
			return String(a["entry_id"]) < String(b["entry_id"])
	)
	return candidates


static func _has_supersession_cycle(graph: Dictionary) -> bool:
	var states: Dictionary = {}
	var entry_ids: Array = graph.keys()
	entry_ids.sort()
	for entry_id_value in entry_ids:
		var entry_id := String(entry_id_value)
		if int(states.get(entry_id, 0)) == 0 and _visit_supersession(entry_id, graph, states):
			return true
	return false


static func _visit_supersession(entry_id: String, graph: Dictionary, states: Dictionary) -> bool:
	states[entry_id] = 1
	for prior_id_value in graph.get(entry_id, []):
		var prior_id := String(prior_id_value)
		if not graph.has(prior_id):
			continue
		var prior_state := int(states.get(prior_id, 0))
		if prior_state == 1:
			return true
		if prior_state == 0 and _visit_supersession(prior_id, graph, states):
			return true
	states[entry_id] = 2
	return false
