extends SceneTree
# gdlint: disable=max-line-length

## Adversarial checks for certification-backed, observation-only BR11
## knowledge. The append-only entries must already exist; this test writes
## nothing.

const Br11KnowledgeBaseScript := preload("res://scripts/lab/br11_knowledge_base.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const KnowledgeBaseScript := preload("res://scripts/lab/knowledge_base.gd")
const KnowledgeQueryScript := preload("res://scripts/lab/knowledge_query.gd")

const RECORDED_UTC := "2026-07-23T20:06:00Z"
const REPORT_SHA256 := "sha256:914c939f6721bac3d713e7cc62df2189c372ff86bd20416bdd186352d1768f88"
const REPORT_RECEIPT_SHA256 := "sha256:c2ca9c82325d7b4dd7720f7b4809e5bcb77bb1785d586bf9b8b1378f673371c0"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR11 knowledge-admission contract ===")
	var proposal := Br11KnowledgeBaseScript.propose_all(RECORDED_UTC)
	_check(
		bool(proposal.get("ok", false)),
		"exact decision, report, receipt, and all eight cited capsules reverify"
	)
	if not bool(proposal.get("ok", false)):
		printerr("  proposal_failure=", proposal)
		_finish()
		return
	var entries: Array = proposal["entries"]
	_check(entries.size() == 4, "manifest proposes exactly four accepted BR11 observations")
	_check(
		(
			_cells(entries)
			== [
				"BR11.0",
				"BR11.1",
				"BR11.2",
				"BR11.3",
			]
		),
		"admission covers every and only certified BR11.0 through BR11.3 milestone cell"
	)
	_check(
		not _cells(entries).has("BR11.4"), "integrity-only BR11.4 is not admitted as an observation"
	)
	_check(_all_guidance_fenced(entries), "every entry has zero repair and guidance authority")
	_check(
		_all_program_evidence_exact(entries), "every entry retains one exact two-replicate program"
	)
	_check(_evidence_identity_pinned(entries), "decision, report, receipt, and source are exact")
	_check(
		_non_claims_retained(entries),
		"every entry retains scaffold, injury, allocation, recovery, locomotion, repair, and guidance exclusions"
	)

	var dispatcher_accepts_all := true
	for entry_value in entries:
		var verification := KnowledgeBaseScript.verify_entry(entry_value)
		if not bool(verification.get("ok", false)):
			dispatcher_accepts_all = false
			printerr("  dispatch_failure=", verification)
	_check(
		dispatcher_accepts_all,
		"generic knowledge verifier dispatches all four BR11 entries without weakening them"
	)
	_check(
		KnowledgeQueryScript.repair_candidates(entries, ["observation_only"], "").is_empty(),
		"accepted BR11 observations yield zero automatic repair candidates"
	)

	_test_adversarial_entries(entries)
	_test_output_plan(entries)
	var installed := Br11KnowledgeBaseScript.inspect_installed()
	_check(
		(
			bool(installed.get("ok", false))
			and int(installed.get("installed_entry_count", -1)) == 4
			and int(installed.get("minimal_repair_rule_count", -1)) == 0
			and not bool(installed.get("automatic_creature_guidance_allowed", true))
			and not bool(installed.get("automatic_application_allowed", true))
		),
		"all four append-only BR11 observations are installed and live-verifiable"
	)
	var catalog := KnowledgeQueryScript.load_entries("res://data/lab/knowledge/entries", false)
	var catalog_entries: Array = catalog.get("entries", [])
	var br11_count := 0
	for entry_value in catalog_entries:
		if (
			String((entry_value as Dictionary).get("schema", ""))
			== Br11KnowledgeBaseScript.ENTRY_SCHEMA
		):
			br11_count += 1
	_check(
		bool(catalog.get("ok", false)) and catalog_entries.size() == 51 and br11_count == 4,
		"shared accepted catalog contains exactly four BR11 observations among fifty-one entries"
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
	wrong_program["evidence"]["program"]["program_id"] = ("BR11_CONTROLLED_FALL_3_LIVE_PAIRED_FALL_V1")
	_reseal(wrong_program)
	_assert_rejected(wrong_program, "cross-cell program substitution fails closed")

	var integrity_program := original.duplicate(true)
	integrity_program["cell_id"] = "BR11.4"
	integrity_program["evidence"]["program"]["cell_id"] = "BR11.4"
	integrity_program["evidence"]["program"]["program_id"] = ("BR11_CONTROLLED_FALL_4_CONTAINMENT_V1")
	_reseal(integrity_program)
	_assert_rejected(integrity_program, "integrity-only BR11.4 cannot enter accepted knowledge")

	var broader_claim := original.duplicate(true)
	broader_claim["claim"] = "BR11 proves free 3D standing."
	_reseal(broader_claim)
	_assert_rejected(broader_claim, "re-sealing a broader claim cannot bypass the manifest")

	var invented_injury_model: Dictionary = entries[2].duplicate(true)
	invented_injury_model["claim"] = "BR11 predicts biomechanical injury."
	_reseal(invented_injury_model)
	_assert_rejected(
		invented_injury_model, "mechanics severity evidence cannot become an injury model"
	)
	var invented_upright_recovery: Dictionary = entries[3].duplicate(true)
	invented_upright_recovery["claim"] = "BR11 proves upright recovery and getting up."
	_reseal(invented_upright_recovery)
	_assert_rejected(
		invented_upright_recovery, "stable-FALLEN evidence cannot become upright recovery"
	)


func _test_output_plan(entries: Array) -> void:
	var plan := Br11KnowledgeBaseScript.output_plan()
	var outputs: Array = plan.get("outputs", [])
	var unique_paths: Dictionary = {}
	var direct_children := bool(plan.get("ok", false))
	for output_value in outputs:
		var path := String((output_value as Dictionary)["path"])
		unique_paths[path] = true
		direct_children = (
			direct_children
			and path.begins_with("res://data/lab/knowledge/entries/br11_")
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
					"VALIDATED_CREATURE_GUIDANCE_CONSUMER",
					"CERTIFIED_MORPHOLOGY_TERRAIN_TRANSFER",
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
			String(evidence["decision_sha256"]) != Br11KnowledgeBaseScript.DECISION_SHA256
			or String(evidence["report_sha256"]) != REPORT_SHA256
			or String(evidence["report_receipt_sha256"]) != REPORT_RECEIPT_SHA256
			or (String(evidence["source_commit_sha"]) != "d4551f99ce0260ac901ca682e0237e81e38df3d8")
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
			or not boundaries.contains("fall arrest")
			or not boundaries.contains("injury")
			or not boundaries.contains("allocation")
			or not boundaries.contains("upright recovery")
			or not boundaries.contains("getting up")
			or not boundaries.contains("gait")
			or not boundaries.contains("walking")
			or not boundaries.contains("repair")
			or not boundaries.contains("guidance")
			or not boundaries.contains("scaffold")
			or not boundaries.contains("observation")
			or not boundaries.contains("fallen")
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
