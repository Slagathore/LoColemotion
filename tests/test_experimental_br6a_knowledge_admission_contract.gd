extends SceneTree
# gdlint: disable=max-line-length

## Adversarial checks for certification-backed, observation-only BR6A
## knowledge. This contract proposes entries in memory but writes nothing.

const Br6aKnowledgeBaseScript := preload("res://scripts/lab/br6a_knowledge_base.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const KnowledgeBaseScript := preload("res://scripts/lab/knowledge_base.gd")
const KnowledgeQueryScript := preload("res://scripts/lab/knowledge_query.gd")

const RECORDED_UTC := "2026-07-23T10:00:00Z"
const REPORT_SHA256 := "sha256:431a98cbf727d09885378ad094efae105468c47b41c5df536b13e18c5855e42e"
const REPORT_RECEIPT_SHA256 := "sha256:1f86dca2a62b10e7a215b9b8791692061eddb65dcdfed8c7a560f83659d4fba5"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR6A knowledge-admission contract ===")
	var proposal := Br6aKnowledgeBaseScript.propose_all(RECORDED_UTC)
	_check(
		bool(proposal.get("ok", false)),
		"exact decision, report, receipt, and all six cited capsules reverify"
	)
	if not bool(proposal.get("ok", false)):
		printerr("  proposal_failure=", proposal)
		_finish()
		return
	var entries: Array = proposal["entries"]
	_check(entries.size() == 3, "manifest proposes exactly three accepted L4 observations")
	_check(
		(
			_cells(entries)
			== [
				"L4.0",
				"L4.1",
				"L4.3",
			]
		),
		"the admission covers every and only certified L4.0, L4.1, and L4.3 cell"
	)
	_check(_all_guidance_fenced(entries), "every entry has zero repair and guidance authority")
	_check(
		_all_program_evidence_exact(entries), "every entry retains one exact two-replicate program"
	)
	_check(_evidence_identity_pinned(entries), "decision, report, receipt, and source are exact")
	_check(
		_non_claims_retained(entries),
		"every entry retains articulated-support and locomotion exclusions"
	)

	var dispatcher_accepts_all := true
	for entry_value in entries:
		var verification := KnowledgeBaseScript.verify_entry(entry_value)
		if not bool(verification.get("ok", false)):
			dispatcher_accepts_all = false
			printerr("  dispatch_failure=", verification)
	_check(
		dispatcher_accepts_all,
		"generic knowledge verifier dispatches all three BR6A entries without weakening them"
	)
	_check(
		KnowledgeQueryScript.repair_candidates(entries, ["body_agnostic"], "").is_empty(),
		"accepted BR6A observations yield zero automatic repair candidates"
	)

	_test_adversarial_entries(entries)
	_test_output_plan(entries)
	var installed := Br6aKnowledgeBaseScript.inspect_installed()
	_check(
		(
			bool(installed.get("ok", false))
			and int(installed.get("installed_entry_count", -1)) == 3
			and int(installed.get("minimal_repair_rule_count", -1)) == 0
			and not bool(installed.get("automatic_creature_guidance_allowed", true))
			and not bool(installed.get("automatic_application_allowed", true))
		),
		"all three append-only BR6A observations are installed and live-verifiable"
	)
	var catalog := KnowledgeQueryScript.load_entries("res://data/lab/knowledge/entries", false)
	var catalog_entries: Array = catalog.get("entries", [])
	var br6a_count := 0
	for entry_value in catalog_entries:
		if (
			String((entry_value as Dictionary).get("schema", ""))
			== Br6aKnowledgeBaseScript.ENTRY_SCHEMA
		):
			br6a_count += 1
	_check(
		bool(catalog.get("ok", false)) and catalog_entries.size() == 51 and br6a_count == 3,
		"shared accepted catalog contains exactly three BR6A observations among fifty-one entries"
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
	wrong_program["evidence"]["program"]["program_id"] = "BR6A_L4_3_RAIL_LEG_SUPPORT_V1"
	_reseal(wrong_program)
	_assert_rejected(wrong_program, "cross-cell program substitution fails closed")

	var broader_claim := original.duplicate(true)
	broader_claim["claim"] = "BR6A proves a free-root standing creature."
	_reseal(broader_claim)
	_assert_rejected(broader_claim, "re-sealing a broader claim cannot bypass the manifest")

	var invented_allocator: Dictionary = entries[2].duplicate(true)
	invented_allocator["claim"] = "The rail-leg observation allocates exact load to every foot."
	_reseal(invented_allocator)
	_assert_rejected(
		invented_allocator, "aggregate rail-leg support cannot become per-foot allocation"
	)


func _test_output_plan(entries: Array) -> void:
	var plan := Br6aKnowledgeBaseScript.output_plan()
	var outputs: Array = plan.get("outputs", [])
	var unique_paths: Dictionary = {}
	var direct_children := bool(plan.get("ok", false))
	for output_value in outputs:
		var path := String((output_value as Dictionary)["path"])
		unique_paths[path] = true
		direct_children = (
			direct_children
			and path.begins_with("res://data/lab/knowledge/entries/br6a_l4_")
			and path.ends_with(".v1.json")
			and path.trim_prefix("res://data/lab/knowledge/entries/").find("/") < 0
		)
	_check(
		(
			outputs.size() == entries.size()
			and unique_paths.size() == entries.size()
			and direct_children
		),
		"fixed output plan has three unique direct append-only entry paths"
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
					"ACCEPTED_FREE_ROOT_SUPPORT_CONTROL_MILESTONE",
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
	return seen_programs.size() == 3


func _evidence_identity_pinned(entries: Array) -> bool:
	for entry_value in entries:
		var evidence: Dictionary = (entry_value as Dictionary)["evidence"]
		if (
			String(evidence["decision_sha256"]) != Br6aKnowledgeBaseScript.DECISION_SHA256
			or String(evidence["report_sha256"]) != REPORT_SHA256
			or String(evidence["report_receipt_sha256"]) != REPORT_RECEIPT_SHA256
			or String(evidence["source_commit_sha"]) != "c0e725496c5daf6b55bab38b1485920e1d993ff8"
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
			or not boundaries.contains("bracing")
			or not boundaries.contains("rail")
			or not boundaries.contains("allocation")
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
