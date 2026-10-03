extends SceneTree
# gdlint: disable=max-line-length

## Adversarial checks for certification-backed, observation-only BR9
## knowledge. The append-only entries must already exist; this test writes
## nothing.

const Br9KnowledgeBaseScript := preload("res://scripts/lab/br9_knowledge_base.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const KnowledgeBaseScript := preload("res://scripts/lab/knowledge_base.gd")
const KnowledgeQueryScript := preload("res://scripts/lab/knowledge_query.gd")

const RECORDED_UTC := "2026-07-23T16:18:00Z"
const REPORT_SHA256 := "sha256:243312f7c9de378daa8ea7382a50c3148261f367141b6df0e0becd728b3a0cde"
const REPORT_RECEIPT_SHA256 := "sha256:0f3bfc904cd23241a3daee3d3d36e70f73982d058d315333e2df22615690a97d"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR9 knowledge-admission contract ===")
	var proposal := Br9KnowledgeBaseScript.propose_all(RECORDED_UTC)
	_check(
		bool(proposal.get("ok", false)),
		"exact decision, report, receipt, and all eight cited capsules reverify"
	)
	if not bool(proposal.get("ok", false)):
		printerr("  proposal_failure=", proposal)
		_finish()
		return
	var entries: Array = proposal["entries"]
	_check(entries.size() == 4, "manifest proposes exactly four accepted BR9 observations")
	_check(
		(
			_cells(entries)
			== [
				"BR9.0",
				"BR9.1",
				"BR9.2",
				"BR9.3",
			]
		),
		"admission covers every and only certified BR9.0 through BR9.3 milestone cell"
	)
	_check(
		not _cells(entries).has("BR9.4"), "integrity-only BR9.4 is not admitted as an observation"
	)
	_check(_all_guidance_fenced(entries), "every entry has zero repair and guidance authority")
	_check(
		_all_program_evidence_exact(entries), "every entry retains one exact two-replicate program"
	)
	_check(_evidence_identity_pinned(entries), "decision, report, receipt, and source are exact")
	_check(
		_non_claims_retained(entries),
		"every entry retains scaffold, bounded-brace, standing, and locomotion exclusions"
	)

	var dispatcher_accepts_all := true
	for entry_value in entries:
		var verification := KnowledgeBaseScript.verify_entry(entry_value)
		if not bool(verification.get("ok", false)):
			dispatcher_accepts_all = false
			printerr("  dispatch_failure=", verification)
	_check(
		dispatcher_accepts_all,
		"generic knowledge verifier dispatches all four BR9 entries without weakening them"
	)
	_check(
		KnowledgeQueryScript.repair_candidates(entries, ["observation_only"], "").is_empty(),
		"accepted BR9 observations yield zero automatic repair candidates"
	)

	_test_adversarial_entries(entries)
	_test_output_plan(entries)
	var installed := Br9KnowledgeBaseScript.inspect_installed()
	_check(
		(
			bool(installed.get("ok", false))
			and int(installed.get("installed_entry_count", -1)) == 4
			and int(installed.get("minimal_repair_rule_count", -1)) == 0
			and not bool(installed.get("automatic_creature_guidance_allowed", true))
			and not bool(installed.get("automatic_application_allowed", true))
		),
		"all four append-only BR9 observations are installed and live-verifiable"
	)
	var catalog := KnowledgeQueryScript.load_entries("res://data/lab/knowledge/entries", false)
	var catalog_entries: Array = catalog.get("entries", [])
	var br9_count := 0
	for entry_value in catalog_entries:
		if (
			String((entry_value as Dictionary).get("schema", ""))
			== Br9KnowledgeBaseScript.ENTRY_SCHEMA
		):
			br9_count += 1
	_check(
		bool(catalog.get("ok", false)) and catalog_entries.size() == 51 and br9_count == 4,
		"shared accepted catalog contains exactly four BR9 observations among fifty-one entries"
	)
	_finish()


func _test_adversarial_entries(entries: Array) -> void:
	var original: Dictionary = entries[0]
	var forged_report := original.duplicate(true)
	forged_report["evidence"]["report_sha256"] = "sha256:" + "a".repeat(64)
	_reseal(forged_report)
	_assert_rejected(forged_report, "certification-report substitution fails closed")

	var forged_receipt := original.duplicate(true)
	forged_receipt["evidence"]["report_receipt_sha256"] = "sha256:" + "b".repeat(64)
	_reseal(forged_receipt)
	_assert_rejected(forged_receipt, "detached-report-receipt substitution fails closed")

	var forged_decision := original.duplicate(true)
	forged_decision["evidence"]["decision_sha256"] = "sha256:" + "c".repeat(64)
	_reseal(forged_decision)
	_assert_rejected(forged_decision, "milestone-decision substitution fails closed")

	var automatic_guidance := original.duplicate(true)
	automatic_guidance["guidance_policy"]["automatic_creature_guidance_allowed"] = true
	_reseal(automatic_guidance)
	_assert_rejected(automatic_guidance, "automatic creature guidance cannot be enabled")

	var automatic_application := original.duplicate(true)
	automatic_application["guidance_policy"]["automatic_application_allowed"] = true
	_reseal(automatic_application)
	_assert_rejected(automatic_application, "automatic application cannot be enabled")

	var rule_injected := original.duplicate(true)
	rule_injected["minimal_repair_rules"] = [{"symptom": "anything"}]
	_reseal(rule_injected)
	_assert_rejected(rule_injected, "repair-rule injection violates the empty contract")

	var wrong_program := original.duplicate(true)
	wrong_program["evidence"]["program"]["program_id"] = ("BR9_EXISTING_CONTACT_BRACE_3_LIVE_PAIRED_PITCH_ARREST_V1")
	_reseal(wrong_program)
	_assert_rejected(wrong_program, "cross-cell program substitution fails closed")

	var integrity_program := original.duplicate(true)
	integrity_program["cell_id"] = "BR9.4"
	integrity_program["evidence"]["program"]["cell_id"] = "BR9.4"
	integrity_program["evidence"]["program"]["program_id"] = ("BR9_EXISTING_CONTACT_BRACE_4_CONTAINMENT_V1")
	_reseal(integrity_program)
	_assert_rejected(integrity_program, "integrity-only BR9.4 cannot enter accepted knowledge")

	var broader_claim := original.duplicate(true)
	broader_claim["claim"] = "BR9 proves free 3D standing."
	_reseal(broader_claim)
	_assert_rejected(broader_claim, "re-sealing a broader claim cannot bypass the manifest")

	var invented_catch: Dictionary = entries[3].duplicate(true)
	invented_catch["claim"] = "The controller executes a successful new-contact catch step."
	_reseal(invented_catch)
	_assert_rejected(
		invented_catch, "existing-contact evidence cannot become a new-contact catch step"
	)


func _test_output_plan(entries: Array) -> void:
	var plan := Br9KnowledgeBaseScript.output_plan()
	var outputs: Array = plan.get("outputs", [])
	var unique_paths: Dictionary = {}
	var direct_children := bool(plan.get("ok", false))
	for output_value in outputs:
		var path := String((output_value as Dictionary)["path"])
		unique_paths[path] = true
		direct_children = (
			direct_children
			and path.begins_with("res://data/lab/knowledge/entries/br9_")
			and path.ends_with(".v1.json")
			and path.trim_prefix("res://data/lab/knowledge/entries/").find("/") < 0
		)
	_check(
		(
			outputs.size() == entries.size()
			and unique_paths.size() == entries.size()
			and direct_children
		),
		"fixed output plan has four unique direct append-only entry paths"
	)


func _all_guidance_fenced(entries: Array) -> bool:
	for entry_value in entries:
		var entry: Dictionary = entry_value
		var guidance: Dictionary = entry["guidance_policy"]
		if (
			String(entry["claim_status"]) != "accepted"
			or String(entry["knowledge_class"]) != "milestone_observation"
			or not (entry["minimal_repair_rules"] as Array).is_empty()
			or bool(guidance["automatic_creature_guidance_allowed"])
			or bool(guidance["automatic_application_allowed"])
			or (
				guidance["unlock_requires"]
				!= [
					"ACCEPTED_BR10_CATCH_STEP",
					"VALIDATED_CREATURE_GUIDANCE_CONSUMER",
					"SEPARATE_GUIDANCE_DECISION",
				]
			)
		):
			return false
	return true


func _all_program_evidence_exact(entries: Array) -> bool:
	var seen_programs: Dictionary = {}
	for entry_value in entries:
		var entry: Dictionary = entry_value
		var program: Dictionary = entry["evidence"]["program"]
		if (
			String(program["cell_id"]) != String(entry["cell_id"])
			or String(program["evidence_role"]) != "milestone"
			or String(program["claim_scope"]).is_empty()
			or (program["replicates"] as Array).size() != 2
			or seen_programs.has(String(program["program_id"]))
		):
			return false
		seen_programs[String(program["program_id"])] = true
		for replicate_value in program["replicates"]:
			var attestation: Dictionary = (replicate_value as Dictionary)["attestation"]
			if (
				String(attestation["algorithm"]) != "hmac-sha256"
				or String(attestation["trust_mode"]) != "production"
				or int(attestation["artifact_count"]) != 7
			):
				return false
	return seen_programs.size() == 4


func _evidence_identity_pinned(entries: Array) -> bool:
	for entry_value in entries:
		var evidence: Dictionary = (entry_value as Dictionary)["evidence"]
		if (
			String(evidence["decision_sha256"]) != Br9KnowledgeBaseScript.DECISION_SHA256
			or String(evidence["report_sha256"]) != REPORT_SHA256
			or String(evidence["report_receipt_sha256"]) != REPORT_RECEIPT_SHA256
			or (String(evidence["source_commit_sha"]) != "4023e51f00030abc6c65574015f37c15265509f0")
		):
			return false
	return true


func _non_claims_retained(entries: Array) -> bool:
	for entry_value in entries:
		var entry: Dictionary = entry_value
		var boundaries := (
			(
				" ".join(PackedStringArray(entry["failure_boundaries"]))
				+ " "
				+ String(entry["evidence"]["certification_claim_boundary"])
			)
			. to_lower()
		)
		if (
			not boundaries.contains("standing")
			or not boundaries.contains("brace")
			or not boundaries.contains("scaffold")
			or not boundaries.contains("observation")
		):
			return false
	return true


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
