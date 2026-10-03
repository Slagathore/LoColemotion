class_name LabBr3aCommissioningRegistry
extends RefCounted

## Fail-closed reconciliation of the historical BR3A commissioning snapshot.
##
## The pinned v1 status remains the exact pre-certification snapshot and is
## never rewritten. Current formal state comes only from the append-only
## milestone-decision registry. This lets the CLI show both what was true at
## commissioning time and what is true after Cole's separate decision.

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const MilestoneDecisionRegistryScript := preload(
	"res://scripts/lab/milestone_decision_registry.gd")
const Br3aKnowledgeBaseScript := preload(
	"res://scripts/lab/br3a_knowledge_base.gd")

const SCHEMA_PATH := (
	"res://data/lab/schemas/br3a_commissioning_status_v1.schema.json")
const SCHEMA_SHA256 := (
	"sha256:c2efefb0e38c0b55b4717ff4ce5fec46c7deecce87c8e02f1bae859864cfad2c")
const STATUS_PATH := (
	"res://data/lab/campaigns/BR3A_L1_commissioning_status_v1.json")
const STATUS_SHA256 := (
	"sha256:e03a896658c8e6f5bdf36a164ec81d29bebfa29a708fa70dc371debbd23403f3")
const BR3A_MILESTONE_ID := "BR3A_L1_ENGINE_CONTACT_TRUTH"

const EXPECTED_CELL_ASSERTIONS := {
	"L1.0": 83,
	"L1.1": 49,
	"L1.2": 19,
	"L1.3": 15,
	"L1.4": 20,
	"L1.5": 13,
	"L1.6": 17,
	"L1.7": 20,
}
const EXPECTED_EXPERIMENTAL_TEST_ASSERTIONS := {
	"res://tests/test_experimental_l1_1_contact_slip.gd": 29,
	"res://tests/test_experimental_l1_1_friction_breakaway.gd": 20,
	"res://tests/test_experimental_l1_2_incline_threshold.gd": 19,
	"res://tests/test_experimental_l1_3_tipping_edge.gd": 15,
	"res://tests/test_experimental_l1_4_pad_center_of_pressure.gd": 20,
	"res://tests/test_experimental_l1_5_timestep_convergence.gd": 13,
	"res://tests/test_experimental_l1_6_solver_step_sensitivity.gd": 17,
	"res://tests/test_experimental_l1_7_mass_ratio_grid.gd": 20,
}
const EXPECTED_BLOCKING_GATES := [
	"PROMOTION_GRADE_L1_BUNDLE_FAMILY_MISSING",
	"BR3A_CERTIFICATION_REPORT_FAMILY_MISSING",
	"BR3A_DETACHED_ATTESTATION_DOMAIN_MISSING",
	"CLEAN_FRESH_PROCESS_BR3A_CAMPAIGN_MISSING",
	"EXPLICIT_BR3A_MILESTONE_DECISION_MISSING",
]
const EXPECTED_SEPARATE_WORK := [
	"L1_8_CONTACT_DISCRETIZATION_PACK",
	"ARTICULATED_MASS_RATIO_GRID_AFTER_L2",
]


static func inspect_current() -> Dictionary:
	var schema_pin := _verify_file_hash(SCHEMA_PATH, SCHEMA_SHA256)
	if not bool(schema_pin.get("ok", false)):
		return schema_pin
	var status_pin := _verify_file_hash(STATUS_PATH, STATUS_SHA256)
	if not bool(status_pin.get("ok", false)):
		return status_pin
	var loaded := _read_json_object(STATUS_PATH)
	if not bool(loaded.get("ok", false)):
		return loaded
	var validated := validate_candidate(loaded["value"], true)
	if not bool(validated.get("ok", false)):
		return validated
	validated["status_path"] = STATUS_PATH
	validated["status_sha256"] = STATUS_SHA256
	validated["schema_path"] = SCHEMA_PATH
	validated["schema_sha256"] = SCHEMA_SHA256
	return validated


static func validate_candidate(
		value: Variant, verify_source_files := true) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("BR3A_STATUS_JSON_INVALID",
			"BR3A commissioning status root must be an object.")
	var status: Dictionary = value
	var schema_result := SchemaValidatorScript.validate_file(
		SCHEMA_PATH, status)
	if not bool(schema_result.get("ok", false)):
		return _failure(
			"BR3A_STATUS_SCHEMA_INVALID",
			"BR3A commissioning status fails its strict schema.",
			{"schema_errors": schema_result.get("errors", [])})
	var semantic_errors := _semantic_errors(status)
	if not semantic_errors.is_empty():
		return _failure(
			"BR3A_STATUS_SEMANTICS_INVALID",
			"BR3A commissioning totals or claim boundaries are incoherent.",
			{"semantic_errors": semantic_errors})
	if verify_source_files:
		var source_result := _verify_source_files(status)
		if not bool(source_result.get("ok", false)):
			return source_result
	var decision_result := MilestoneDecisionRegistryScript.load_by_id(
		MilestoneDecisionRegistryScript.BR3A_DECISION_ID)
	if not bool(decision_result.get("ok", false)):
		return _failure(
			"BR3A_CURRENT_DECISION_INVALID",
			"The registered BR3A milestone decision failed closed.",
			{"decision_failure": decision_result})
	var decision: Dictionary = decision_result["decision"]
	var accepted_milestones: Array[String] = (
		MilestoneDecisionRegistryScript.accepted_milestone_ids())
	var formally_accepted := (
		accepted_milestones.has(BR3A_MILESTONE_ID)
		and String(decision.get("status", "")) == "accepted")
	if not formally_accepted:
		return _failure(
			"BR3A_CURRENT_DECISION_NOT_ACCEPTED",
			"The registered BR3A decision does not accept the bounded milestone.")
	var knowledge_result := Br3aKnowledgeBaseScript.inspect_installed()
	if not bool(knowledge_result.get("ok", false)) \
			or int(knowledge_result.get("installed_entry_count", -1)) != 9:
		return _failure(
			"BR3A_CURRENT_KNOWLEDGE_INVALID",
			"The fixed BR3A knowledge admission is incomplete or untrusted.",
			{"knowledge_failure": knowledge_result})
	var snapshot_blockers: Array = status["promotion"]["blocking_gates"]
	return {
		"ok": true,
		"failure_code": "",
		"commissioning_complete": true,
		"promotion_ready": false,
		"formal_status": "accepted",
		"commissioning_snapshot_historical": true,
		"report_v2_guard_intact": true,
		"experimental_source_pins_intact": verify_source_files,
		"accepted_milestone_ids": accepted_milestones,
		"milestone_decision_id": String(decision["decision_id"]),
		"milestone_decision_sha256": String(
			decision_result["decision_sha256"]),
		"formal_claim_boundary": String(decision["claim_boundary"]),
		"formal_excluded_capabilities": FrozenValueScript.snapshot(
			decision["excluded_capabilities"]),
		"supplementary_constraints": FrozenValueScript.snapshot(
			decision["supplementary_constraints"]),
		"blocking_gates": FrozenValueScript.snapshot([]),
		"snapshot_blocking_gates": FrozenValueScript.snapshot(
			snapshot_blockers),
		"knowledge_admission_eligible": true,
		"knowledge_admission_complete": true,
		"accepted_br3a_knowledge_entries": 9,
		"accepted_br3a_milestone_observations": 8,
		"accepted_br3a_supplementary_constraints": 1,
		"automatic_creature_guidance_allowed": false,
		"status": FrozenValueScript.snapshot(status),
	}


static func _semantic_errors(status: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var seen_cells: Dictionary = {}
	var cell_assertion_sum := 0
	for cell_value in status.get("cells", []):
		var cell: Dictionary = cell_value
		var cell_id := String(cell.get("cell_id", ""))
		if not EXPECTED_CELL_ASSERTIONS.has(cell_id) or seen_cells.has(cell_id):
			errors.append("CELL_IDENTITY_INVALID:%s" % cell_id)
			continue
		seen_cells[cell_id] = true
		var assertions := int(cell.get("assertion_count", -1))
		cell_assertion_sum += assertions
		if assertions != int(EXPECTED_CELL_ASSERTIONS[cell_id]):
			errors.append("CELL_ASSERTION_COUNT_MISMATCH:%s" % cell_id)
		var expected_status := (
			"released_suite_commissioning"
			if cell_id == "L1.0" else "experimental_green")
		if String(cell.get("commission_status", "")) != expected_status:
			errors.append("CELL_COMMISSION_STATUS_MISMATCH:%s" % cell_id)
	if seen_cells.size() != EXPECTED_CELL_ASSERTIONS.size() \
			or cell_assertion_sum != 236:
		errors.append("CELL_GRID_OR_TOTAL_MISMATCH")

	var seen_tests: Dictionary = {}
	var experimental_assertion_sum := 0
	for test_value in status.get("experimental_tests", []):
		var test: Dictionary = test_value
		var path := String(test.get("resource_path", ""))
		if not EXPECTED_EXPERIMENTAL_TEST_ASSERTIONS.has(path) \
				or seen_tests.has(path):
			errors.append("EXPERIMENTAL_TEST_IDENTITY_INVALID:%s" % path)
			continue
		seen_tests[path] = true
		var assertions := int(test.get("expected_passed_assertions", -1))
		experimental_assertion_sum += assertions
		if assertions != int(EXPECTED_EXPERIMENTAL_TEST_ASSERTIONS[path]):
			errors.append("EXPERIMENTAL_ASSERTION_COUNT_MISMATCH:%s" % path)
	if seen_tests.size() != EXPECTED_EXPERIMENTAL_TEST_ASSERTIONS.size() \
			or experimental_assertion_sum != 153:
		errors.append("EXPERIMENTAL_GRID_OR_TOTAL_MISMATCH")
	if not _arrays_equal(
			status["promotion"].get("blocking_gates", []),
			EXPECTED_BLOCKING_GATES):
		errors.append("PROMOTION_BLOCKERS_MISMATCH")
	if not _arrays_equal(
			status["promotion"].get("separate_nonblocking_work", []),
			EXPECTED_SEPARATE_WORK):
		errors.append("SEPARATE_WORK_BOUNDARY_MISMATCH")
	if String(status.get("claim_boundary", "")).find(
			"development commissioning only") < 0:
		errors.append("CLAIM_BOUNDARY_WEAKENED")
	return errors


static func _verify_source_files(status: Dictionary) -> Dictionary:
	for test_value in status["experimental_tests"]:
		var test: Dictionary = test_value
		var verified := _verify_file_hash(
			String(test["resource_path"]), String(test["source_sha256"]))
		if not bool(verified.get("ok", false)):
			verified["failure_code"] = "BR3A_EXPERIMENTAL_SOURCE_PIN_MISMATCH"
			return verified
	var guard: Dictionary = status["report_v2_guard"]
	var guard_hash := _verify_file_hash(
		String(guard["resource_path"]), String(guard["source_sha256"]))
	if not bool(guard_hash.get("ok", false)):
		guard_hash["failure_code"] = "BR3A_REPORT_V2_GUARD_HASH_MISMATCH"
		return guard_hash
	var loaded := _read_json_object(String(guard["resource_path"]))
	if not bool(loaded.get("ok", false)):
		return loaded
	var inventory: Dictionary = loaded["value"]
	var tests_value: Variant = inventory.get("tests")
	if String(inventory.get("inventory_id", "")) != String(
			guard["inventory_id"]) \
			or int(inventory.get("test_count", -1)) != int(guard["test_count"]) \
			or String(inventory.get("pattern", "")) != String(guard["pattern"]) \
			or not tests_value is Array \
			or (tests_value as Array).size() != int(guard["test_count"]):
		return _failure(
			"BR3A_REPORT_V2_GUARD_SEMANTICS_MISMATCH",
			"The immutable BR1 report-v2 inventory contract changed.")
	var overlap := 0
	for path_value in EXPECTED_EXPERIMENTAL_TEST_ASSERTIONS.keys():
		if (tests_value as Array).has(String(path_value).get_file()):
			overlap += 1
	if overlap != int(guard["experimental_overlap_expected"]):
		return _failure(
			"BR3A_REPORT_V2_EXPERIMENTAL_OVERLAP",
			"Experimental BR3A tests were smuggled into BR1 report-v2.",
			{"observed_overlap": overlap})
	return {"ok": true, "failure_code": ""}


static func _verify_file_hash(path: String, expected: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure(
			"BR3A_PINNED_FILE_MISSING",
			"Required BR3A commissioning resource is missing.",
			{"path": path})
	var actual := "sha256:%s" % FileAccess.get_sha256(path)
	if actual != expected:
		return _failure(
			"BR3A_PINNED_FILE_HASH_MISMATCH",
			"BR3A commissioning resource bytes changed after pinning.",
			{
				"path": path,
				"expected_sha256": expected,
				"actual_sha256": actual,
			})
	return {"ok": true, "failure_code": "", "path": path, "sha256": actual}


static func _read_json_object(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(
			"BR3A_STATUS_JSON_INVALID", "JSON resource cannot be opened.")
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK \
			or typeof(parser.data) != TYPE_DICTIONARY:
		return _failure(
			"BR3A_STATUS_JSON_INVALID", "Resource is not one JSON object.")
	return {"ok": true, "failure_code": "", "value": parser.data}


static func _arrays_equal(left_value: Variant, right: Array) -> bool:
	if typeof(left_value) != TYPE_ARRAY:
		return false
	var left: Array = left_value
	if left.size() != right.size():
		return false
	for index in right.size():
		if left[index] != right[index]:
			return false
	return true


static func _failure(
		failure_code: String,
		message: String,
		extra: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": false,
		"failure_code": failure_code,
		"message": message,
	}
	for key_value in extra.keys():
		result[key_value] = extra[key_value]
	return result
