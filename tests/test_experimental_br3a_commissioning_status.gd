extends SceneTree

## BR3A historical-commissioning/current-decision reconciliation checks.
##
## This file stays outside test_lab_*.gd and BR1 report-v2 by design. It proves
## the pinned snapshot and append-only decision remain distinct. It creates no
## bundles, receipts, knowledge entries, decisions, or locomotion claims.

const RegistryScript := preload(
	"res://scripts/lab/br3a_commissioning_registry.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR3A commissioning status ===")
	var inspection: Dictionary = RegistryScript.inspect_current()
	_check(bool(inspection.get("ok", false)),
		"byte-pinned BR3A status and schema validate against live sources")
	if not bool(inspection.get("ok", false)):
		printerr("  inspection=", inspection)
		_finish()
		return
	var status: Dictionary = inspection["status"]
	_check(bool(inspection["commissioning_complete"])
		and int(status["planned_cell_count"]) == 8
		and int(status["implemented_cell_count"]) == 8,
		"all eight planned L1.0-L1.7 implementation cells are commissioned")
	_check(int(status["commissioning_assertion_count"]) == 236
		and int(status["released_l1_0_assertion_count"]) == 83
		and int(status["experimental_assertion_count"]) == 153,
		"commissioning totals preserve released and experimental boundaries")
	_check(int(status["experimental_test_count"]) == 8
		and bool(inspection["experimental_source_pins_intact"]),
		"all eight experimental source files match their SHA-256 pins")
	_check(bool(inspection["report_v2_guard_intact"])
		and int(status["report_v2_guard"]["test_count"]) == 62
		and bool(status["report_v2_guard"]["mutation_forbidden"]),
		"BR1 report-v2 remains byte-pinned at 62 tests with zero overlap")
	_check(not bool(inspection["promotion_ready"])
		and inspection["formal_status"] == "accepted"
		and bool(inspection["commissioning_snapshot_historical"])
		and (inspection["accepted_milestone_ids"] as Array).has(
			"BR3A_L1_ENGINE_CONTACT_TRUTH"),
		"formal acceptance comes from the separate append-only decision")
	_check((inspection["blocking_gates"] as Array).is_empty()
		and (inspection["snapshot_blocking_gates"] as Array).size() == 5
		and (inspection["snapshot_blocking_gates"] as Array).has(
			"PROMOTION_GRADE_L1_BUNDLE_FAMILY_MISSING")
		and (inspection["snapshot_blocking_gates"] as Array).has(
			"EXPLICIT_BR3A_MILESTONE_DECISION_MISSING"),
		"current blockers close without rewriting the five-blocker snapshot")
	_check(int(status["knowledge"]["accepted_br3a_entries"]) == 0
		and bool(inspection["knowledge_admission_eligible"])
		and bool(inspection["knowledge_admission_complete"])
		and int(inspection["accepted_br3a_knowledge_entries"]) == 9
		and int(inspection["accepted_br3a_milestone_observations"]) == 8
		and int(inspection["accepted_br3a_supplementary_constraints"]) == 1
		and not bool(inspection["automatic_creature_guidance_allowed"]),
		"historical zero-entry snapshot reconciles with nine current observation-only entries")
	var locomotion: Dictionary = status["proven_locomotion"]
	_check(not bool(locomotion["standing"])
		and not bool(locomotion["bracing"])
		and not bool(locomotion["fall_arrest"])
		and not bool(locomotion["getting_up"])
		and not bool(locomotion["walking"]),
		"standing, bracing, arrest, recovery, and walking remain exactly zero")
	_test_adversarial_status(status)
	_finish()


func _test_adversarial_status(status: Dictionary) -> void:
	var forged_hash := status.duplicate(true)
	forged_hash["experimental_tests"][0]["source_sha256"] = (
		"sha256:" + "0".repeat(64))
	var hash_result: Dictionary = RegistryScript.validate_candidate(
		forged_hash, true)
	_check(not bool(hash_result["ok"])
		and hash_result["failure_code"] \
			== "BR3A_EXPERIMENTAL_SOURCE_PIN_MISMATCH",
		"forged experimental source identity fails closed")
	var forged_promotion := status.duplicate(true)
	forged_promotion["promotion"]["ready_for_milestone_decision"] = true
	var promotion_result: Dictionary = RegistryScript.validate_candidate(
		forged_promotion, false)
	_check(not bool(promotion_result["ok"])
		and promotion_result["failure_code"] == "BR3A_STATUS_SCHEMA_INVALID",
		"forged promotion readiness fails the owned schema")
	var weakened := status.duplicate(true)
	weakened["promotion"]["blocking_gates"].remove_at(0)
	var weakened_result: Dictionary = RegistryScript.validate_candidate(
		weakened, false)
	_check(not bool(weakened_result["ok"])
		and weakened_result["failure_code"] \
			== "BR3A_STATUS_SCHEMA_INVALID",
		"removing one real promotion blocker fails the strict contract")
	var broadened := status.duplicate(true)
	broadened["claim_boundary"] = "All BR3A capabilities accepted."
	var broadened_result: Dictionary = RegistryScript.validate_candidate(
		broadened, false)
	_check(not bool(broadened_result["ok"])
		and broadened_result["failure_code"] \
			== "BR3A_STATUS_SEMANTICS_INVALID",
		"broadening the development-only claim boundary fails closed")


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
