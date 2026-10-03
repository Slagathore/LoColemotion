extends SceneTree
# gdlint: disable=max-line-length

const RegistryScript := preload("res://scripts/lab/certification_qualification_profile_registry.gd")
const AttestationScript := preload("res://scripts/lab/certification_report_attestation.gd")
const FailureCodesScript := preload("res://scripts/lab/failure_codes.gd")
const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")
const MilestoneDecisionRegistryScript := preload("res://scripts/lab/milestone_decision_registry.gd")

const REPORT_SCHEMA := "sporespore.lab.br1_certification_report.v1"
const CAMPAIGN_ID := "BR1_L0_CERTIFICATION_V1"
const CAMPAIGN_SHA256 := "sha256:c8146b00bfabfd2c4784cf2907ef68244d03388ccc184a9d16a99d49423419cd"
const R001_INVENTORY_SHA256 := "sha256:4e090096c4009e1406214307a80e46480e80efbb4228f30df8efdc9de4ff13f6"
const R002_INVENTORY_SHA256 := "sha256:f287e53d6b47fad15205a8ed416b0616e5eaae694453cd661c6eb08e1e2b79fa"
const V2_INVENTORY_PATH := "res://data/lab/campaigns/BR1_required_lab_tests_v2.json"
const V2_INVENTORY_SHA256 := "sha256:f22a43c3125d2a87c3f4b154af40d5e99a2a9dd1da35e159825e79635357605e"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Legacy BR1 qualification dispatch tests ===")
	_test_exact_revision_dispatch()
	_test_cross_revision_and_partial_matches_fail_closed()
	_test_dispatch_shape_rejections()
	_test_report_adapter_uses_observed_artifact_cardinality()
	_test_v2_authoring_boundary_is_separate_and_current()
	_test_br2_1_milestone_decision_is_bounded_and_append_only()
	_finish()


func _test_exact_revision_dispatch() -> void:
	print("- routes only the two complete historical tuples")
	var r001 := RegistryScript.dispatch(_identity(R001_INVENTORY_SHA256, 45, 90))
	var r002 := RegistryScript.dispatch(_identity(R002_INVENTORY_SHA256, 51, 102))
	_check(
		bool(r001.get("ok", false)) and r001.get("profile_id") == RegistryScript.PROFILE_R001_I45,
		"45-test tuple selects only R001"
	)
	_check(
		bool(r002.get("ok", false)) and r002.get("profile_id") == RegistryScript.PROFILE_R002_I51,
		"51-test tuple selects only R002"
	)


func _test_cross_revision_and_partial_matches_fail_closed() -> void:
	print("- rejects coherent-looking cross-pairs and one-field drift")
	var cases := [
		_identity(R001_INVENTORY_SHA256, 51, 102),
		_identity(R002_INVENTORY_SHA256, 45, 90),
		_identity(R001_INVENTORY_SHA256, 45, 102),
		_identity(R002_INVENTORY_SHA256, 51, 90),
		_identity(
			"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 45, 90
		),
	]
	var wrong_campaign_id := _identity(R001_INVENTORY_SHA256, 45, 90)
	wrong_campaign_id["campaign_id"] = "BR1_L0_CERTIFICATION_V2"
	cases.append(wrong_campaign_id)
	var wrong_campaign_hash := _identity(R001_INVENTORY_SHA256, 45, 90)
	wrong_campaign_hash["campaign_sha256"] = ("sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
	cases.append(wrong_campaign_hash)
	var wrong_report_schema := _identity(R001_INVENTORY_SHA256, 45, 90)
	wrong_report_schema["report_schema"] = "sporespore.lab.br1_certification_report.v2"
	cases.append(wrong_report_schema)
	for index in cases.size():
		var result := RegistryScript.dispatch(cases[index])
		_check(
			(
				not bool(result.get("ok", true))
				and result.get("failure_code") == RegistryScript.FAILURE_PROFILE_UNKNOWN
			),
			"mismatched tuple %d has no permissive fallback" % (index + 1)
		)


func _test_dispatch_shape_rejections() -> void:
	print("- rejects missing, extra, path, and non-integral selector data")
	var missing := _identity(R001_INVENTORY_SHA256, 45, 90)
	missing.erase("campaign_sha256")
	_assert_invalid_identity(missing, "missing selector field")
	var extra := _identity(R001_INVENTORY_SHA256, 45, 90)
	extra["schema_path"] = "res://attacker_selected.schema.json"
	_assert_invalid_identity(extra, "report-supplied path field")
	var fractional := _identity(R001_INVENTORY_SHA256, 45, 90)
	fractional["tests_required"] = 45.5
	_assert_invalid_identity(fractional, "fractional test count")
	var wrong_type := _identity(R001_INVENTORY_SHA256, 45, 90)
	wrong_type["inventory_sha256"] = 45
	_assert_invalid_identity(wrong_type, "non-string inventory hash")


func _test_report_adapter_uses_observed_artifact_cardinality() -> void:
	print("- extracts selection facts without consuming report paths")
	var r001_artifacts: Array = []
	r001_artifacts.resize(90)
	var r001_report := {
		"schema": REPORT_SCHEMA,
		"test_inventory":
		{
			"path": "C:/untrusted/original/path.json",
			"sha256": R001_INVENTORY_SHA256,
			"required": 45,
			"artifacts": r001_artifacts,
		},
		"campaign":
		{
			"path": "C:/untrusted/original/campaign.json",
			"campaign_id": CAMPAIGN_ID,
			"sha256": CAMPAIGN_SHA256,
		},
	}
	var selected := RegistryScript.dispatch_report(r001_report)
	_check(
		(
			bool(selected.get("ok", false))
			and selected.get("profile_id") == RegistryScript.PROFILE_R001_I45
		),
		"report adapter selects R001 without trusting either reported path"
	)
	r001_artifacts.resize(89)
	var wrong_artifact_count := RegistryScript.dispatch_report(r001_report)
	_check(
		(
			not bool(wrong_artifact_count.get("ok", true))
			and wrong_artifact_count.get("failure_code") == RegistryScript.FAILURE_PROFILE_UNKNOWN
		),
		"observed 89-artifact array cannot claim the 90-artifact profile"
	)
	var no_artifacts := r001_report.duplicate(true)
	no_artifacts["test_inventory"].erase("artifacts")
	var missing_artifacts := RegistryScript.dispatch_report(no_artifacts)
	_check(
		(
			not bool(missing_artifacts.get("ok", true))
			and (
				missing_artifacts.get("failure_code")
				== RegistryScript.FAILURE_DISPATCH_IDENTITY_INVALID
			)
		),
		"report adapter requires a concrete artifact array"
	)


func _test_v2_authoring_boundary_is_separate_and_current() -> void:
	print("- separates legacy verification from current v2 authoring")
	var inventory := _read_json(V2_INVENTORY_PATH)
	var discovered: Array[String] = []
	for file_name in DirAccess.get_files_at("res://tests"):
		if file_name.begins_with("test_lab_") and file_name.ends_with(".gd"):
			discovered.append(file_name)
	discovered.sort()
	var expected: Array = inventory.get("tests", [])
	var inventory_matches_discovery := expected.size() == discovered.size()
	if inventory_matches_discovery:
		for index in expected.size():
			if String(expected[index]) != discovered[index]:
				print(
					(
						"  inventory mismatch index=%d expected=%s discovered=%s"
						% [index, String(expected[index]), discovered[index]]
					)
				)
				inventory_matches_discovery = false
				break
	if expected.size() != discovered.size():
		print(
			(
				"  inventory size mismatch expected=%d discovered=%d discovered_files=%s"
				% [expected.size(), discovered.size(), str(discovered)]
			)
		)
	_check(
		(
			String(inventory.get("schema", "")) == "sporespore.lab.br1_required_test_inventory.v2"
			and String(inventory.get("inventory_id", "")) == "BR1_REQUIRED_LAB_TESTS_V2"
			and int(inventory.get("inventory_version", -1)) == 2
			and int(inventory.get("test_count", -1)) == 62
			and inventory_matches_discovery
		),
		"v2 inventory is the exact sorted 62-test discovery set"
	)
	_check(
		"sha256:%s" % FileAccess.get_sha256(V2_INVENTORY_PATH) == V2_INVENTORY_SHA256,
		"v2 inventory bytes match the operator's immutable SHA-256 pin"
	)

	var report_schema_result := SchemaValidatorScript.load_schema(
		"res://data/lab/schemas/br1_certification_report_v2.schema.json"
	)
	var receipt_schema_result := SchemaValidatorScript.load_schema(
		"res://data/lab/schemas/certification_report_attestation_v2.schema.json"
	)
	var report_schema: Dictionary = report_schema_result.get("schema", {})
	var receipt_schema: Dictionary = receipt_schema_result.get("schema", {})
	var report_defs: Dictionary = report_schema.get("$defs", {})
	var inventory_contract: Dictionary = report_defs.get("test_inventory", {})
	var inventory_properties: Dictionary = inventory_contract.get("properties", {})
	_check(
		(
			bool(report_schema_result.get("ok", false))
			and (
				report_schema["properties"]["schema"]["const"]
				== "sporespore.lab.br1_certification_report.v2"
			)
			and inventory_properties["required"]["const"] == 62
			and inventory_properties["artifacts"]["minItems"] == 124
			and inventory_properties["artifacts"]["maxItems"] == 124
		),
		"report-v2 schema pins 62 tests and exactly 124 artifacts"
	)
	_check(
		(
			bool(receipt_schema_result.get("ok", false))
			and (
				receipt_schema["properties"]["schema"]["const"]
				== "sporespore.lab.br1_certification_report_attestation.v2"
			)
			and (
				receipt_schema["properties"]["domain"]["const"]
				== "sporespore.lab.br1_certification_report_attestation.v2"
			)
			and (
				receipt_schema["properties"]["report_schema"]["const"]
				== "sporespore.lab.br1_certification_report.v2"
			)
		),
		"receipt-v2 has a distinct schema, HMAC domain, and report identity"
	)

	var disabled := AttestationScript.attest_production(
		"C:/does/not/matter/br1_certification_report.json", "legacy-authoring-must-not-run"
	)
	_check(
		(
			not bool(disabled.get("ok", true))
			and (
				String(disabled.get("failure_code", ""))
				== FailureCodesScript.LEGACY_CERTIFICATION_AUTHORING_DISABLED
			)
		),
		"production report-v1 authoring is explicitly disabled"
	)
	var v2_receipt_path := AttestationScript.receipt_path_for_certification_id_v2(
		"C:/tmp/sporespore_attestation_contract", "v2-contract-probe"
	)
	_check(
		v2_receipt_path.replace("\\", "/").contains("/certification_reports_v2/receipts/"),
		"v2 receipts occupy a separate append-only namespace"
	)


func _test_br2_1_milestone_decision_is_bounded_and_append_only() -> void:
	print("- records Cole's BR2.1 acceptance without broadening its evidence")
	var loaded := MilestoneDecisionRegistryScript.load_by_id(
		MilestoneDecisionRegistryScript.BR2_1_DECISION_ID
	)
	_check(
		bool(loaded.get("ok", false)),
		"allowlisted BR2.1 milestone decision loads from exact pinned bytes"
	)
	if not bool(loaded.get("ok", false)):
		return
	var decision: Dictionary = loaded["decision"]
	_check(
		(
			decision.is_read_only()
			and decision["status"] == "accepted"
			and decision["decided_by"]["id"] == "Cole"
		),
		"accepted decision is immutable and names the project decider"
	)
	_check(
		(
			MilestoneDecisionRegistryScript.accepted_milestone_ids()
			== [
				"BR10_REACHABLE_PLANAR_CATCH",
				"BR11_CONTROLLED_PLANAR_FALL",
				"BR12_POSE_AND_RECOVERY_FEASIBILITY",
				"BR13_CONSTRAINED_CANONICAL_GET_UP",
				"BR2.1_ARTICULATED_OBSERVER",
				"BR3A_L1_ENGINE_CONTACT_TRUTH",
				"BR3B_L3_BASIC_LOADED_FOOT_TRUTH",
				"BR4_L2_JOINT_ACTUATOR_TRUTH",
				"BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT",
				"BR7_PLANAR_MULTI_CONTACT_STANCE",
				"BR8_EARLY_LOSS_OF_VIABILITY_DETECTION",
				"BR9_EXISTING_CONTACT_PLANAR_BRACE",
			]
		),
		(
			"registry preserves BR2.1 beside all nine separately accepted "
			+ "BR3A-through-BR11 milestone records"
		)
	)
	_check(
		(
			decision["excluded_capabilities"].has("Gait, candidate walking, or walking")
			and decision["excluded_capabilities"].has(
				"Actuator strength, torque application, or force transmission"
			)
			and decision["excluded_capabilities"].has(
				"BR3A contact-engine truth as a complete milestone"
			)
		),
		"decision explicitly excludes walking, actuation, and BR3A promotion"
	)

	var weakened_boundary := decision.duplicate(true)
	weakened_boundary["claim_boundary"] = "BR2 is generally accepted."
	_assert_milestone_candidate_rejected(
		weakened_boundary, "claim-boundary broadening fails closed"
	)
	var weakened_exclusions := decision.duplicate(true)
	weakened_exclusions["excluded_capabilities"].erase("Gait, candidate walking, or walking")
	_assert_milestone_candidate_rejected(
		weakened_exclusions, "removing the walking exclusion fails closed"
	)
	var forged_report := decision.duplicate(true)
	forged_report["evidence_basis"]["report_sha256"] = ("sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
	_assert_milestone_candidate_rejected(
		forged_report, "substituting certification report identity fails closed"
	)
	var forged_decider := decision.duplicate(true)
	forged_decider["decided_by"]["id"] = "automatic_gate"
	_assert_milestone_candidate_rejected(
		forged_decider, "an automatic system cannot impersonate Cole's decision"
	)
	var unknown := MilestoneDecisionRegistryScript.load_by_id("BR2_1_UNREGISTERED_DECISION_V2")
	_check(
		(
			not bool(unknown.get("ok", true))
			and (
				unknown.get("failure_code")
				== MilestoneDecisionRegistryScript.FAILURE_DECISION_UNKNOWN
			)
		),
		"unregistered milestone decisions have no permissive fallback"
	)


func _assert_milestone_candidate_rejected(candidate: Dictionary, label: String) -> void:
	var result := MilestoneDecisionRegistryScript.validate_candidate(candidate)
	_check(not bool(result.get("ok", true)), label)


static func _identity(
	inventory_sha256: String, tests_required: int, artifacts_required: int
) -> Dictionary:
	return {
		"report_schema": REPORT_SCHEMA,
		"inventory_sha256": inventory_sha256,
		"tests_required": tests_required,
		"test_artifacts_required": artifacts_required,
		"campaign_id": CAMPAIGN_ID,
		"campaign_sha256": CAMPAIGN_SHA256,
	}


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "owned test JSON must exist: %s" % path)
	var parser := JSON.new()
	assert(parser.parse(file.get_as_text()) == OK, "owned test JSON must parse: %s" % path)
	return parser.data if parser.data is Dictionary else {}


func _assert_invalid_identity(identity: Dictionary, label: String) -> void:
	var result := RegistryScript.dispatch(identity)
	_check(
		(
			not bool(result.get("ok", true))
			and result.get("failure_code") == RegistryScript.FAILURE_DISPATCH_IDENTITY_INVALID
		),
		"%s is rejected before lookup" % label
	)


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
