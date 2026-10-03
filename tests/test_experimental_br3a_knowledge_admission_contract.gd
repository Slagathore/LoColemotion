extends SceneTree
# gdlint: disable=max-line-length

## Adversarial checks for the certification-backed, observation-only BR3A
## knowledge contract. This test may propose entries in memory but never writes
## an encyclopedia file or authorizes creature guidance.

const Br3aKnowledgeBaseScript := preload("res://scripts/lab/br3a_knowledge_base.gd")
const Br4KnowledgeBaseScript := preload("res://scripts/lab/br4_knowledge_base.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const KnowledgeBaseScript := preload("res://scripts/lab/knowledge_base.gd")
const KnowledgeQueryScript := preload("res://scripts/lab/knowledge_query.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

const RECORDED_UTC := "2026-07-23T07:00:00Z"
const REPORT_SHA256 := "sha256:8574122ad227084657bb8edd947b4e7c7d001af553f63cf645cb595afbd5fc6b"
const REPORT_RECEIPT_SHA256 := "sha256:a355f549907eb87742a8310eb56e58c88aaf1ebd98ee68f22c05b459c3f8dd8c"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR3A knowledge-admission contract ===")
	var proposal := Br3aKnowledgeBaseScript.propose_all(RECORDED_UTC)
	_check(
		bool(proposal.get("ok", false)),
		"exact decision, report, receipt, and every cited capsule reverify"
	)
	if not bool(proposal.get("ok", false)):
		printerr("  proposal_failure=", proposal)
		_finish()
		return
	var entries: Array = proposal["entries"]
	_check(entries.size() == 9, "manifest proposes exactly nine accepted observation records")
	_check(
		(
			_count_class(entries, "milestone_observation") == 8
			and _count_class(entries, "supplementary_constraint") == 1
		),
		"L1.0-L1.7 are milestone observations and L1.8 alone is supplementary"
	)
	_check(
		(
			_cells(entries)
			== [
				"L1.0",
				"L1.1",
				"L1.2",
				"L1.3",
				"L1.4",
				"L1.5",
				"L1.6",
				"L1.7",
				"L1.8",
			]
		),
		"the admission covers every and only intended L1 cell"
	)
	_check(
		_all_guidance_fenced(entries),
		"all entries are accepted observations with zero repair or guidance permission"
	)
	_check(
		_all_evidence_exact(entries),
		"every program retains exact roles, claims, and two production-attested replicates"
	)
	_check(
		_no_integrity_program_admitted(entries),
		"knowledge guard and commissioning registry remain containment evidence, not entries"
	)
	_check(
		_evidence_identity_pinned(entries),
		"every entry pins the accepted decision and exact report/receipt identity"
	)
	_check(
		_l1_8_boundary_exact(entries),
		"L1.8 remains a one-program supplementary non-additivity constraint"
	)

	var dispatcher_accepts_all := true
	for entry_value in entries:
		var verification := KnowledgeBaseScript.verify_entry(entry_value)
		if not bool(verification.get("ok", false)):
			dispatcher_accepts_all = false
			printerr("  dispatch_failure=", verification)
	_check(
		dispatcher_accepts_all,
		"generic knowledge verifier dispatches the BR3A schema without weakening v1"
	)
	var candidates := KnowledgeQueryScript.repair_candidates(entries, ["body_agnostic"], "")
	_check(
		candidates.is_empty(), "accepted BR3A observations yield zero automatic repair candidates"
	)

	_test_adversarial_entries(entries)
	_test_output_plan(entries)
	var installed := Br3aKnowledgeBaseScript.inspect_installed()
	_check(
		(
			bool(installed.get("ok", false))
			and int(installed.get("installed_entry_count", -1)) == 9
			and not bool(installed.get("automatic_creature_guidance_allowed", true))
		),
		"all nine append-only entries are installed and live-verifiable"
	)
	var catalog := KnowledgeQueryScript.load_entries("res://data/lab/knowledge/entries", false)
	var catalog_entries: Array = catalog.get("entries", [])
	var br3a_count := 0
	var br4_count := 0
	for entry_value in catalog_entries:
		if (
			String((entry_value as Dictionary).get("schema", ""))
			== Br3aKnowledgeBaseScript.ENTRY_SCHEMA
		):
			br3a_count += 1
		elif (
			String((entry_value as Dictionary).get("schema", ""))
			== Br4KnowledgeBaseScript.ENTRY_SCHEMA
		):
			br4_count += 1
	_check(
		(
			bool(catalog.get("ok", false))
			and catalog_entries.size() == 51
			and br3a_count == 9
			and br4_count == 8
		),
		(
			"shared catalog retains L0, nine BR3A, three BR3B, eight BR4, and "
			+ "three BR6A, four each from BR7-BR12, and three BR13 observations"
		)
	)
	_finish()


func _test_adversarial_entries(entries: Array) -> void:
	var original: Dictionary = entries[0]
	var forged_report := original.duplicate(true)
	forged_report["evidence"]["report_sha256"] = "sha256:" + "a".repeat(64)
	_reseal(forged_report)
	_assert_rejected(forged_report, "substituting the accepted certification report fails closed")

	var forged_decision := original.duplicate(true)
	forged_decision["evidence"]["decision_sha256"] = ("sha256:" + "b".repeat(64))
	_reseal(forged_decision)
	_assert_rejected(forged_decision, "substituting the milestone decision fails closed")

	var automatic_guidance := original.duplicate(true)
	automatic_guidance["guidance_policy"]["automatic_creature_guidance_allowed"] = true
	_reseal(automatic_guidance)
	_assert_rejected(
		automatic_guidance, "automatic creature guidance cannot be enabled in entry v1"
	)

	var automatic_application := original.duplicate(true)
	automatic_application["guidance_policy"]["automatic_application_allowed"] = true
	_reseal(automatic_application)
	_assert_rejected(automatic_application, "automatic application cannot be enabled in entry v1")

	var rule_injected := original.duplicate(true)
	rule_injected["minimal_repair_rules"] = [
		{
			"symptom": "anything",
		}
	]
	_reseal(rule_injected)
	_assert_rejected(
		rule_injected, "repair-rule injection violates the structurally empty contract"
	)

	var l1_8: Dictionary = entries[8]
	var promoted_l1_8 := l1_8.duplicate(true)
	promoted_l1_8["knowledge_class"] = "milestone_observation"
	_reseal(promoted_l1_8)
	_assert_rejected(
		promoted_l1_8, "L1.8 cannot be relabeled from supplementary to milestone knowledge"
	)

	var guard_smuggled := l1_8.duplicate(true)
	guard_smuggled["evidence"]["programs"][0]["program_id"] = ("BR3A_KNOWLEDGE_DRAFT_GUARD_V1")
	_reseal(guard_smuggled)
	_assert_rejected(
		guard_smuggled, "containment-program substitution cannot be smuggled into an entry"
	)

	var changed_claim := original.duplicate(true)
	changed_claim["claim"] = "BR3A proves standing."
	_reseal(changed_claim)
	_assert_rejected(
		changed_claim, "re-sealing a broader claim cannot bypass the admission manifest"
	)


func _test_output_plan(entries: Array) -> void:
	var plan := Br3aKnowledgeBaseScript.output_plan()
	var outputs: Array = plan.get("outputs", [])
	var unique_paths: Dictionary = {}
	var direct_children := bool(plan.get("ok", false))
	for output_value in outputs:
		var path := String((output_value as Dictionary)["path"])
		unique_paths[path] = true
		direct_children = (
			direct_children
			and path.begins_with("res://data/lab/knowledge/entries/")
			and path.ends_with(".v1.json")
			and path.trim_prefix("res://data/lab/knowledge/entries/").find("/") < 0
		)
	_check(
		(
			outputs.size() == entries.size()
			and unique_paths.size() == entries.size()
			and direct_children
		),
		"fixed output plan has nine unique direct append-only entry paths"
	)


func _all_guidance_fenced(entries: Array) -> bool:
	for entry_value in entries:
		var entry: Dictionary = entry_value
		var guidance: Dictionary = entry["guidance_policy"]
		if (
			String(entry["claim_status"]) != "accepted"
			or not (entry["minimal_repair_rules"] as Array).is_empty()
			or bool(guidance["automatic_creature_guidance_allowed"])
			or bool(guidance["automatic_application_allowed"])
			or (
				guidance["unlock_requires"]
				!= [
					"ACCEPTED_SUPPORT_MILESTONE",
					"SEPARATE_GUIDANCE_DECISION",
				]
			)
		):
			return false
	return true


func _all_evidence_exact(entries: Array) -> bool:
	for entry_value in entries:
		var entry: Dictionary = entry_value
		for program_value in entry["evidence"]["programs"]:
			var program: Dictionary = program_value
			if (
				String(program["cell_id"]) != String(entry["cell_id"])
				or String(program["claim_scope"]).is_empty()
				or (program["replicates"] as Array).size() != 2
			):
				return false
			var expected_role := (
				"supplementary"
				if String(entry["knowledge_class"]) == "supplementary_constraint"
				else "milestone"
			)
			if String(program["evidence_role"]) != expected_role:
				return false
			for replicate_value in program["replicates"]:
				var replicate: Dictionary = replicate_value
				var attestation: Dictionary = replicate["attestation"]
				if (
					String(attestation["algorithm"]) != "hmac-sha256"
					or String(attestation["trust_mode"]) != "production"
					or int(attestation["artifact_count"]) != 7
				):
					return false
	return true


func _no_integrity_program_admitted(entries: Array) -> bool:
	for entry_value in entries:
		for program_value in (entry_value as Dictionary)["evidence"]["programs"]:
			var program_id := String((program_value as Dictionary)["program_id"])
			if (
				program_id
				in [
					"BR3A_KNOWLEDGE_DRAFT_GUARD_V1",
					"BR3A_COMMISSIONING_REGISTRY_INTEGRITY_V1",
				]
			):
				return false
	return true


func _evidence_identity_pinned(entries: Array) -> bool:
	for entry_value in entries:
		var evidence: Dictionary = (entry_value as Dictionary)["evidence"]
		if (
			String(evidence["decision_sha256"]) != Br3aKnowledgeBaseScript.DECISION_SHA256
			or String(evidence["report_sha256"]) != REPORT_SHA256
			or String(evidence["report_receipt_sha256"]) != REPORT_RECEIPT_SHA256
			or String(evidence["source_commit_sha"]) != "109cc664c3282077cd806e61e1ba756e6578e639"
		):
			return false
	return true


func _l1_8_boundary_exact(entries: Array) -> bool:
	var entry: Dictionary = entries[8]
	var programs: Array = entry["evidence"]["programs"]
	return (
		String(entry["cell_id"]) == "L1.8"
		and String(entry["knowledge_class"]) == "supplementary_constraint"
		and programs.size() == 1
		and (
			String((programs[0] as Dictionary)["program_id"])
			== "BR3A_L1_8_CONTACT_DISCRETIZATION_V1"
		)
		and String((programs[0] as Dictionary)["claim_scope"]).contains("non-additive")
	)


func _count_class(entries: Array, requested: String) -> int:
	var count := 0
	for entry_value in entries:
		if String((entry_value as Dictionary)["knowledge_class"]) == requested:
			count += 1
	return count


func _cells(entries: Array) -> Array:
	var cells: Array = []
	for entry_value in entries:
		cells.append(String((entry_value as Dictionary)["cell_id"]))
	return cells


func _reseal(entry: Dictionary) -> void:
	var payload: Dictionary = {}
	for key_value in entry:
		if String(key_value) != "admission":
			payload[key_value] = entry[key_value]
	entry["admission"]["payload_sha256"] = CanonicalJsonScript.sha256(payload)


func _assert_rejected(candidate: Dictionary, label: String) -> void:
	var result := KnowledgeBaseScript.verify_entry(candidate)
	_check(not bool(result.get("ok", true)), label)


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
