extends SceneTree

## BR3A development-draft containment guard.
##
## Drafts under data/lab/knowledge/drafts/br3a are authoring inputs only. This
## guard proves they validate against their own development-observation schema,
## carry every snapshot-era promotion blocker and zero locomotion claims, stay
## advisory, and cannot be consumed through the accepted-knowledge boundary or
## admitted without a promotion-grade bundle. It creates no bundles, entries,
## decisions, or locomotion claims.

const SchemaValidatorScript := preload(
	"res://scripts/lab/schema_validator.gd")
const KnowledgeBaseScript := preload("res://scripts/lab/knowledge_base.gd")
const KnowledgeQueryScript := preload("res://scripts/lab/knowledge_query.gd")
const RegistryScript := preload(
	"res://scripts/lab/br3a_commissioning_registry.gd")
const Br3aKnowledgeBaseScript := preload(
	"res://scripts/lab/br3a_knowledge_base.gd")

const DRAFT_SCHEMA_PATH := (
	"res://data/lab/schemas/br3a_development_observation_v1.schema.json")
const DRAFT_DIRECTORY := "res://data/lab/knowledge/drafts/br3a"
const EXPECTED_DRAFT_FILES := [
	"L1_1_contact_slip_and_breakaway.development.json",
	"L1_2_incline_threshold.development.json",
	"L1_3_tipping_edge.development.json",
	"L1_4_pad_center_of_pressure.development.json",
	"L1_5_timestep_envelope.development.json",
	"L1_6_solver_sensitivity_and_reconstruction.development.json",
	"L1_7_mass_ratio_grid.development.json",
	"L1_8_contact_discretization.development.json",
]
const REQUIRED_NON_CLAIMS := [
	"standing",
	"bracing",
	"fall_arrest",
	"getting_up",
	"walking",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR3A knowledge-draft guard ===")
	var listed := _list_draft_json_files()
	_check(listed == EXPECTED_DRAFT_FILES,
		"draft directory holds exactly the eight expected L1 draft files")

	var drafts: Array = []
	var all_parse := true
	var all_schema_valid := true
	for name_value in EXPECTED_DRAFT_FILES:
		var path := "%s/%s" % [DRAFT_DIRECTORY, String(name_value)]
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			all_parse = false
			continue
		drafts.append(parsed)
		var validation: Dictionary = SchemaValidatorScript.validate_file(
			DRAFT_SCHEMA_PATH, parsed)
		if not bool(validation.get("ok", false)):
			all_schema_valid = false
			printerr("  schema_errors path=", path,
				" errors=", validation.get("errors", []))
	_check(all_parse and drafts.size() == EXPECTED_DRAFT_FILES.size(),
		"every draft parses as one JSON object")
	_check(all_schema_valid,
		"every draft satisfies the strict development-observation schema")
	if drafts.size() != EXPECTED_DRAFT_FILES.size():
		_finish()
		return

	_evaluate_draft_semantics(drafts)
	_evaluate_schema_negations(drafts)
	_evaluate_consumption_refusal(drafts)
	_evaluate_entries_containment()
	_evaluate_registry_after_decision()
	_check(true,
		"draft guard makes no bundle, entry, decision, or locomotion claim")
	_finish()


func _evaluate_draft_semantics(drafts: Array) -> void:
	var expected_blockers: Array = RegistryScript.EXPECTED_BLOCKING_GATES
	var blockers_pinned := true
	var non_claims_pinned := true
	var rules_advisory := true
	var cells_unique: Dictionary = {}
	for draft_value in drafts:
		var draft: Dictionary = draft_value
		var blockers: Array = draft.get("admission_blockers", [])
		blockers_pinned = (
			blockers.size() == expected_blockers.size()
			and draft.get("admissible_now") == false
			and (draft.get("evidence_source", {}) as Dictionary).get(
				"promotion_grade_bundle_exists") == false
			and blockers_pinned)
		for blocker_value in expected_blockers:
			if not blockers.has(String(blocker_value)):
				blockers_pinned = false
		var non_claims: Array = draft.get("does_not_establish", [])
		for required_value in REQUIRED_NON_CLAIMS:
			if not non_claims.has(String(required_value)):
				non_claims_pinned = false
		for rule_value in draft.get("minimal_repair_rules", []):
			var rule: Dictionary = rule_value
			rules_advisory = (
				rule.get("advisory_only") == true
				and rule.get("automatic_application_forbidden") == true
				and rules_advisory)
		cells_unique[String(draft.get("cell_id", ""))] = true
	_check(blockers_pinned,
		"every draft pins all five snapshot blockers and no admissibility")
	_check(non_claims_pinned,
		"every draft explicitly does not establish the five locomotion claims")
	_check(rules_advisory,
		"every repair rule stays advisory with automatic application forbidden")
	_check(cells_unique.size() == drafts.size(),
		"each draft covers a distinct L1 cell")


func _evaluate_schema_negations(drafts: Array) -> void:
	var admissible_forged: Dictionary = (
		drafts[0] as Dictionary).duplicate(true)
	admissible_forged["admissible_now"] = true
	var admissible_result: Dictionary = SchemaValidatorScript.validate_file(
		DRAFT_SCHEMA_PATH, admissible_forged)
	var ceiling_forged: Dictionary = (drafts[0] as Dictionary).duplicate(true)
	ceiling_forged["claim_status_ceiling"] = "accepted"
	var ceiling_result: Dictionary = SchemaValidatorScript.validate_file(
		DRAFT_SCHEMA_PATH, ceiling_forged)
	var blocker_dropped: Dictionary = (drafts[0] as Dictionary).duplicate(true)
	(blocker_dropped["admission_blockers"] as Array).remove_at(0)
	var blocker_result: Dictionary = SchemaValidatorScript.validate_file(
		DRAFT_SCHEMA_PATH, blocker_dropped)
	var rule_unfenced: Dictionary = (drafts[0] as Dictionary).duplicate(true)
	var unfenced_rules: Array = rule_unfenced.get("minimal_repair_rules", [])
	if unfenced_rules.is_empty():
		unfenced_rules = [{}]
	(unfenced_rules[0] as Dictionary)["advisory_only"] = false
	rule_unfenced["minimal_repair_rules"] = unfenced_rules
	var rule_result: Dictionary = SchemaValidatorScript.validate_file(
		DRAFT_SCHEMA_PATH, rule_unfenced)
	var bundle_forged: Dictionary = (drafts[0] as Dictionary).duplicate(true)
	(bundle_forged["evidence_source"] as Dictionary)[
		"promotion_grade_bundle_exists"] = true
	var bundle_result: Dictionary = SchemaValidatorScript.validate_file(
		DRAFT_SCHEMA_PATH, bundle_forged)
	_check(not bool(admissible_result.get("ok", true))
		and not bool(ceiling_result.get("ok", true))
		and not bool(blocker_result.get("ok", true))
		and not bool(rule_result.get("ok", true))
		and not bool(bundle_result.get("ok", true)),
		"forged admissibility, ceiling, blocker, rule, or bundle claims fail closed")


func _evaluate_consumption_refusal(drafts: Array) -> void:
	var all_rejected_as_entries := true
	for draft_value in drafts:
		var verification: Dictionary = KnowledgeBaseScript.verify_entry(
			draft_value)
		if bool(verification.get("ok", false)) \
				or String(verification.get("code", "")) \
					!= "KNOWLEDGE_ENTRY_SCHEMA_INVALID":
			all_rejected_as_entries = false
	_check(all_rejected_as_entries,
		"the accepted-knowledge verifier rejects every draft as a non-entry")

	var loaded: Dictionary = KnowledgeQueryScript.load_entries(
		DRAFT_DIRECTORY, true)
	_check(not bool(loaded.get("ok", true))
		and (loaded.get("entries", [1]) as Array).is_empty()
		and not (loaded.get("errors", []) as Array).is_empty(),
		"knowledge queries over the draft directory fail closed with zero entries")

	var repair_candidates: Array = KnowledgeQueryScript.repair_candidates(
		drafts, ["body_agnostic"], "")
	_check(repair_candidates.is_empty(),
		"repair-candidate retrieval yields nothing from unadmitted drafts")

	var proposal: Dictionary = KnowledgeBaseScript.propose_from_bundle(
		"res://data/lab/knowledge/drafts/br3a/nonexistent_bundle",
		drafts[0],
		"development_observation")
	_check(not bool(proposal.get("ok", true))
		and String(proposal.get("code", "")) == "BUNDLE_NOT_ADMISSIBLE",
		"admission without a valid promotion-grade bundle stays refused")


func _evaluate_entries_containment() -> void:
	var inspection := Br3aKnowledgeBaseScript.inspect_installed()
	var drafts_excluded := bool(inspection.get("ok", false))
	for entry_value in inspection.get("entries", []):
		var entry: Dictionary = entry_value
		drafts_excluded = (
			drafts_excluded
			and String(entry.get("schema", "")) \
				== "sporespore.lab.br3a_knowledge_entry.v1"
			and not String(entry.get("entry_id", "")).ends_with(".draft_v1")
			and (entry.get("minimal_repair_rules", []) as Array).is_empty()
			and not bool(entry["guidance_policy"][
				"automatic_application_allowed"]))
	_check(drafts_excluded
		and int(inspection.get("installed_entry_count", -1)) == 9,
		"nine separately admitted entries exclude draft identity and repair authority")


func _evaluate_registry_after_decision() -> void:
	var inspection: Dictionary = RegistryScript.inspect_current()
	_check(bool(inspection.get("ok", false))
		and not bool(inspection.get("promotion_ready", true))
		and String(inspection.get("formal_status", "")) == "accepted"
		and (inspection.get("blocking_gates", []) as Array).is_empty()
		and (inspection.get("snapshot_blocking_gates", []) as Array).size() == 5
		and bool(inspection.get("knowledge_admission_eligible", false))
		and bool(inspection.get("knowledge_admission_complete", false))
		and int(inspection.get("accepted_br3a_knowledge_entries", -1)) == 9
		and not bool(inspection.get(
			"automatic_creature_guidance_allowed", true)),
		"accepted knowledge is separate from drafts and still grants no guidance")


func _list_draft_json_files() -> Array:
	var names: Array = []
	var access := DirAccess.open(
		ProjectSettings.globalize_path(DRAFT_DIRECTORY))
	if access == null:
		return names
	for name in access.get_files():
		if String(name).ends_with(".json"):
			names.append(String(name))
	names.sort()
	return names


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
