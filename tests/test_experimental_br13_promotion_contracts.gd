extends SceneTree
# gdlint: disable=max-line-length

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")
const BundleCliScript := preload("res://scripts/lab/br13_bundle_attestation_cli.gd")
const ReportAttestationScript := preload(
	"res://scripts/lab/br13_certification_report_attestation.gd"
)
const ReportCliScript := preload("res://scripts/lab/br13_certification_report_attestation_cli.gd")

const CAMPAIGN_SCHEMA := "res://data/lab/schemas/br13_canonical_get_up_promotion_campaign_v1.schema.json"
const INVENTORY_SCHEMA := "res://data/lab/schemas/br13_canonical_get_up_source_inventory_v1.schema.json"
const METRICS_SCHEMA := "res://data/lab/schemas/br13_canonical_get_up_evidence_metrics_v1.schema.json"
const CAPSULE_SCHEMA := "res://data/lab/schemas/br13_canonical_get_up_evidence_capsule_v1.schema.json"
const REPORT_SCHEMA := "res://data/lab/schemas/br13_certification_report_v1.schema.json"
const RECEIPT_SCHEMA := (
	"res://data/lab/schemas/" + "br13_certification_report_attestation_v1.schema.json"
)
const HASH := "sha256:0000000000000000000000000000000000000000000000000000000000000000"
const COMMIT := "0000000000000000000000000000000000000000"
const CERTIFICATION_ID := "br13_20260722T220000Z_00000000"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR13 promotion-contract tests ===")
	var campaign := _read_json(
		"res://data/lab/campaigns/BR13_canonical_get_up_promotion_campaign_v1.json"
	)
	_test_campaign(campaign)
	_test_inventory(campaign)
	_test_metrics(campaign)
	_test_capsule()
	_test_report_and_receipt(campaign)
	_test_cli_boundaries()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_campaign(campaign: Dictionary) -> void:
	print("- campaign has a strict, role-separated, bounded canonical get-up contract")
	var validation := SchemaValidatorScript.validate_file(CAMPAIGN_SCHEMA, campaign)
	_check(bool(validation.get("ok", false)), "source campaign passes its owned strict schema")
	var role_counts := {"milestone": 0, "supplementary": 0, "integrity": 0}
	var role_assertions := {"milestone": 0, "supplementary": 0, "integrity": 0}
	for value in campaign["programs"]:
		var program: Dictionary = value
		var role := String(program["evidence_role"])
		role_counts[role] = int(role_counts[role]) + 1
		role_assertions[role] = int(role_assertions[role]) + int(program["expected_assertions"])
	_check(
		(
			role_counts == {"milestone": 3, "supplementary": 0, "integrity": 2}
			and role_assertions == {"milestone": 57, "supplementary": 0, "integrity": 33}
		),
		"5 programs preserve the exact milestone and integrity role boundary"
	)
	_check(
		(
			(campaign["does_not_establish"] as Array).has(
				"Per-contact, per-body, per-foot, per-toe, or center-of-pressure load allocation"
			)
			and (campaign["does_not_establish"] as Array).has(
				"Free-3D, unscaffolded, or morphology-generalized self-righting or recovery"
			)
			and (campaign["does_not_establish"] as Array).has(
				"A step, weight-transfer maneuver, gait, candidate walking, or walking"
			)
		),
		"campaign explicitly excludes free-3D transfer, measured allocation, and walking"
	)
	var weakened := campaign.duplicate(true)
	weakened["process_policy"]["cherry_pick_policy"] = "best_replicate_only"
	_check(
		not bool(SchemaValidatorScript.validate_file(CAMPAIGN_SCHEMA, weakened).get("ok", false)),
		"campaign schema rejects a cherry-picking policy"
	)
	var broadened := campaign.duplicate(true)
	broadened["claim_boundary"] = "Any useful contact or locomotion conclusion."
	_check(
		not bool(SchemaValidatorScript.validate_file(CAMPAIGN_SCHEMA, broadened).get("ok", false)),
		"campaign schema rejects a rewritten claim boundary"
	)
	var role_weakened := campaign.duplicate(true)
	role_weakened["role_accounting"]["supplementary"]["programs"] = 1
	_check(
		not bool(
			SchemaValidatorScript.validate_file(CAMPAIGN_SCHEMA, role_weakened).get("ok", false)
		),
		"campaign schema rejects invented supplementary evidence"
	)


func _test_inventory(campaign: Dictionary) -> void:
	print("- source inventory owns exact sorted file bytes")
	var inventory := {
		"schema": "sporespore.lab.br13_canonical_get_up_source_inventory.v1",
		"commit_sha": COMMIT,
		"algorithm": "sha256",
		"file_count": 1,
		"files":
		[
			{
				"path": "project.godot",
				"sha256": HASH,
				"bytes": 1,
			}
		],
	}
	_check(
		bool(SchemaValidatorScript.validate_file(INVENTORY_SCHEMA, inventory).get("ok", false)),
		"minimal exact source inventory passes"
	)
	var injected := inventory.duplicate(true)
	injected["files"][0]["ignored_digest"] = HASH
	_check(
		not bool(SchemaValidatorScript.validate_file(INVENTORY_SCHEMA, injected).get("ok", false)),
		"source inventory rejects an unowned digest field"
	)
	var traversal := inventory.duplicate(true)
	traversal["files"][0]["path"] = "../project.godot"
	_check(
		not bool(SchemaValidatorScript.validate_file(INVENTORY_SCHEMA, traversal).get("ok", false)),
		"source inventory rejects path traversal"
	)
	var project_root := ProjectSettings.globalize_path("res://")
	var expected := ReportAttestationScript._expected_source_paths(campaign, project_root)
	_check(
		(
			bool(expected.get("ok", false))
			and not (expected.get("paths", []) as Array).is_empty()
			and (expected.get("paths", []) as Array).has(
				"scripts/lab/br13_certification_report_attestation.gd"
			)
			and (expected.get("paths", []) as Array).has(
				"scripts/lab/br13_bundle_attestation_cli.gd"
			)
			and (expected.get("paths", []) as Array).has(
				"data/lab/schemas/br13_certification_report_v1.schema.json"
			)
			and (expected.get("paths", []) as Array).has(
				"data/lab/campaigns/BR13_canonical_get_up_promotion_campaign_v1.json"
			)
			and (expected.get("paths", []) as Array).has(
				"tests/test_experimental_br13_4_live_canonical_get_up.gd"
			)
		),
		"independent readback rebuilds the complete declared source closure"
	)
	var live_inventory := _live_inventory(expected.get("paths", []), project_root)
	_check(
		bool(
			(
				ReportAttestationScript
				. _verify_source_inventory(live_inventory, COMMIT, expected["paths"])
				. get("ok", false)
			)
		),
		"independent source verifier accepts the exact live closure"
	)
	var omitted_live := live_inventory.duplicate(true)
	omitted_live["files"].pop_back()
	omitted_live["file_count"] = (omitted_live["files"] as Array).size()
	_check(
		not bool(
			(
				ReportAttestationScript
				. _verify_source_inventory(omitted_live, COMMIT, expected["paths"])
				. get("ok", false)
			)
		),
		"independent source verifier rejects one omitted live file"
	)


func _test_metrics(campaign: Dictionary) -> void:
	print("- metrics retain ordered assertions, observations, process identity, and non-claims")
	var program: Dictionary = campaign["programs"][0]
	var metrics := _metrics_fixture(program)
	_check(
		bool(SchemaValidatorScript.validate_file(METRICS_SCHEMA, metrics).get("ok", false)),
		"BR13 canonical get-up metrics fixture passes its owned schema"
	)
	var same_process := metrics.duplicate(true)
	same_process["process"]["fresh_process"] = false
	_check(
		not bool(
			SchemaValidatorScript.validate_file(METRICS_SCHEMA, same_process).get("ok", false)
		),
		"metrics cannot relabel a non-fresh process as evidence"
	)
	var failed := metrics.duplicate(true)
	failed["harness"]["assertions_failed"] = 1
	_check(
		not bool(SchemaValidatorScript.validate_file(METRICS_SCHEMA, failed).get("ok", false)),
		"metrics reject a failed assertion"
	)
	var invented := metrics.duplicate(true)
	invented["per_foot_load_n"] = 9.8
	_check(
		not bool(SchemaValidatorScript.validate_file(METRICS_SCHEMA, invented).get("ok", false)),
		"metrics reject an invented per-foot load channel"
	)


func _test_capsule() -> void:
	print("- capsule binds one complete run to source, campaign, process, and raw evidence")
	var capsule := {
		"schema": "sporespore.lab.br13_canonical_get_up_evidence_capsule.v1",
		"bundle_id": "%s.fixture.r1" % CERTIFICATION_ID,
		"campaign_id": "BR13_CANONICAL_GET_UP_PROMOTION_CAMPAIGN_V1",
		"certification_id": CERTIFICATION_ID,
		"program_id": "BR13_FIXTURE_V1",
		"cell_id": "BR13.0",
		"evidence_role": "milestone",
		"replicate": 1,
		"status": "COMPLETE",
		"source_commit_sha": COMMIT,
		"campaign_sha256": HASH,
		"source_inventory_sha256": HASH,
		"metrics_sha256": HASH,
		"harness_report_sha256": HASH,
		"engine_log_sha256": HASH,
		"transcript_log_sha256": HASH,
		"process":
		{
			"containment_host_process_id": 1,
			"target_process_id": 2,
			"started_utc": "2026-07-22T22:00:00Z",
			"ended_utc": "2026-07-22T22:00:01Z",
		},
		"created_utc": "2026-07-22T22:00:00Z",
		"claim_boundary":
		(
			"This fixture proves only schema containment and does not establish "
			+ "a foot, limb, standing, bracing, recovery, or walking capability."
		),
	}
	_check(
		bool(SchemaValidatorScript.validate_file(CAPSULE_SCHEMA, capsule).get("ok", false)),
		"complete capsule fixture passes"
	)
	var running := capsule.duplicate(true)
	running["status"] = "RUNNING"
	_check(
		not bool(SchemaValidatorScript.validate_file(CAPSULE_SCHEMA, running).get("ok", false)),
		"incomplete capsule cannot enter the family"
	)
	var reused := capsule.duplicate(true)
	reused["process"]["target_process_id"] = 0
	_check(
		not bool(SchemaValidatorScript.validate_file(CAPSULE_SCHEMA, reused).get("ok", false)),
		"capsule requires a positive target-process witness"
	)


func _test_report_and_receipt(campaign: Dictionary) -> void:
	print("- report accounts for every role while retaining a separate human decision")
	var report := _report_fixture(campaign)
	var validation := SchemaValidatorScript.validate_file(REPORT_SCHEMA, report)
	if not bool(validation.get("ok", false)):
		printerr("  report_schema_errors=", validation.get("errors", []))
	_check(bool(validation.get("ok", false)), "complete 5-program/10-bundle report fixture passes")
	var walking := report.duplicate(true)
	walking["capabilities"]["walking"] = true
	_check(
		not bool(SchemaValidatorScript.validate_file(REPORT_SCHEMA, walking).get("ok", false)),
		"report schema makes a walking claim unrepresentable"
	)
	var hidden_motor := report.duplicate(true)
	hidden_motor["canonical_get_up_constraints"]["guide_motors_or_springs_enabled"] = true
	_check(
		not bool(SchemaValidatorScript.validate_file(REPORT_SCHEMA, hidden_motor).get("ok", false)),
		"report schema rejects a motorized or spring-assisted guide"
	)
	var false_measurement := report.duplicate(true)
	false_measurement["capabilities"]["per_body_or_per_foot_measured_load_allocation"] = true
	_check(
		not bool(
			SchemaValidatorScript.validate_file(REPORT_SCHEMA, false_measurement).get("ok", false)
		),
		"report schema rejects invented per-body or per-foot allocation"
	)
	var free_3d := report.duplicate(true)
	free_3d["capabilities"]["free_3d_recovery"] = true
	_check(
		not bool(SchemaValidatorScript.validate_file(REPORT_SCHEMA, free_3d).get("ok", false)),
		"report schema makes free-3D recovery unrepresentable"
	)
	var independent_limbs := report.duplicate(true)
	independent_limbs["capabilities"]["independent_four_limb_control"] = true
	_check(
		not bool(
			SchemaValidatorScript.validate_file(REPORT_SCHEMA, independent_limbs).get("ok", false)
		),
		"report schema rejects forged independent four-limb control"
	)
	var omitted := report.duplicate(true)
	omitted["programs"].pop_back()
	_check(
		not bool(SchemaValidatorScript.validate_file(REPORT_SCHEMA, omitted).get("ok", false)),
		"report schema rejects one omitted declared program"
	)
	var receipt := {
		"schema": ReportAttestationScript.RECEIPT_SCHEMA,
		"domain": ReportAttestationScript.RECEIPT_DOMAIN,
		"algorithm": "hmac-sha256",
		"key_id": HASH,
		"certification_id": CERTIFICATION_ID,
		"report_name": "br13_certification_report.json",
		"report_sha256": HASH,
		"report_bytes": 1,
		"report_schema": "sporespore.lab.br13_certification_report.v1",
		"report_status": "pass",
		"certification": "BR13_CONSTRAINED_CANONICAL_GET_UP",
		"commit_sha": COMMIT,
		"campaign_id": "BR13_CANONICAL_GET_UP_PROMOTION_CAMPAIGN_V1",
		"campaign_sha256": HASH,
		"attested_utc": "2026-07-22T22:00:00Z",
		"tag": "hmac-sha256:%s" % HASH.trim_prefix("sha256:"),
	}
	_check(
		bool(SchemaValidatorScript.validate_file(RECEIPT_SCHEMA, receipt).get("ok", false)),
		"detached BR13 receipt fixture passes"
	)
	var wrong_domain := receipt.duplicate(true)
	wrong_domain["domain"] = "sporespore.lab.br1_certification_report_attestation.v2"
	_check(
		not bool(
			SchemaValidatorScript.validate_file(RECEIPT_SCHEMA, wrong_domain).get("ok", false)
		),
		"BR1-domain receipt cannot authenticate a BR13 report"
	)
	_check(
		(
			(
				ReportAttestationScript.RECEIPT_DOMAIN
				== "sporespore.lab.br13_certification_report_attestation.v1"
			)
			and (
				ReportAttestationScript.RECEIPT_DOMAIN
				!= "sporespore.lab.publication_attestation.v1"
			)
		),
		"final report domain is separate from generic bundle publication"
	)


func _test_cli_boundaries() -> void:
	print("- both CLIs reject ambiguous or unknown authoring requests")
	var bundle_ok := (
		BundleCliScript
		. parse_arguments(
			PackedStringArray(
				[
					"--mode",
					"verify",
					"--bundle",
					"C:/tmp/bundle",
				]
			)
		)
	)
	_check(bool(bundle_ok.get("ok", false)), "bundle CLI accepts one explicit verify request")
	var bundle_unknown := (
		BundleCliScript
		. parse_arguments(
			PackedStringArray(
				[
					"--mode",
					"attest",
					"--bundle",
					"C:/tmp/bundle",
					"--accept-milestone",
				]
			)
		)
	)
	_check(
		not bool(bundle_unknown.get("ok", false)), "bundle CLI has no milestone-acceptance switch"
	)
	var report_ok := (
		ReportCliScript
		. parse_arguments(
			PackedStringArray(
				[
					"--mode",
					"verify",
					"--report",
					"C:/tmp/br13_certification_report.json",
					"--certification-id",
					CERTIFICATION_ID,
				]
			)
		)
	)
	_check(bool(report_ok.get("ok", false)), "report CLI accepts one explicit verify request")
	var report_missing := (
		ReportCliScript
		. parse_arguments(
			PackedStringArray(
				[
					"--mode",
					"attest",
					"--report",
					"C:/tmp/br13_certification_report.json",
				]
			)
		)
	)
	_check(
		not bool(report_missing.get("ok", false)),
		"report CLI refuses an unbound certification identity"
	)


func _metrics_fixture(program: Dictionary) -> Dictionary:
	return {
		"schema": "sporespore.lab.br13_canonical_get_up_evidence_metrics.v1",
		"program_id": String(program["program_id"]),
		"cell_id": String(program["cell_id"]),
		"evidence_role": String(program["evidence_role"]),
		"replicate": 1,
		"test": String(program["test_resource_path"]).get_file(),
		"source_commit_sha": COMMIT,
		"process":
		{
			"containment_host_process_id": 1,
			"target_process_id": 2,
			"started_utc": "2026-07-22T22:00:00Z",
			"ended_utc": "2026-07-22T22:00:01Z",
			"fresh_process": true,
		},
		"harness":
		{
			"status": "pass",
			"process_exit_code": 0,
			"timed_out": false,
			"containment_tree_closed": true,
			"exit_marker_observed": true,
			"footer_count": 1,
			"assertions_passed": int(program["expected_assertions"]),
			"assertions_failed": 0,
			"unexpected_engine_error_count": 0,
		},
		"assertion_labels": ["fixture assertion"],
		"observation_lines": ["fixture observation"],
		"transcript_line_count": 2,
		"artifact_hashes":
		{
			"harness_report": HASH,
			"engine_log": HASH,
			"transcript_log": HASH,
			"source_inventory": HASH,
		},
		"claim_scope": String(program["claim_scope"]),
		"does_not_establish": ["walking"],
	}


func _live_inventory(paths: Array, project_root: String) -> Dictionary:
	var files: Array = []
	for path_value in paths:
		var relative := String(path_value)
		var absolute := project_root.path_join(relative)
		var file := FileAccess.open(absolute, FileAccess.READ)
		assert(file != null)
		var byte_count := file.get_length()
		file.close()
		(
			files
			. append(
				{
					"path": relative,
					"sha256": "sha256:%s" % FileAccess.get_sha256(absolute),
					"bytes": byte_count,
				}
			)
		)
	return {
		"schema": "sporespore.lab.br13_canonical_get_up_source_inventory.v1",
		"commit_sha": COMMIT,
		"algorithm": "sha256",
		"file_count": files.size(),
		"files": files,
	}


func _report_fixture(campaign: Dictionary) -> Dictionary:
	var replicate := {
		"replicate": 1,
		"bundle_id": "%s.fixture.r1" % CERTIFICATION_ID,
		"bundle_path": "C:/tmp/bundle",
		"manifest_sha256": HASH,
		"checksums_sha256": HASH,
		"capsule_sha256": HASH,
		"metrics_sha256": HASH,
		"source_inventory_sha256": HASH,
		"containment_host_process_id": 2,
		"target_process_id": 1,
		"started_utc": "2026-07-22T22:00:00Z",
		"ended_utc": "2026-07-22T22:00:01Z",
		"assertions_passed": 1,
		"assertion_labels_sha256": HASH,
		"transcript_sha256": HASH,
		"attestation":
		{
			"valid": true,
			"trust_mode": "production",
			"key_id": HASH,
			"receipt_path": "C:/tmp/receipt.json",
			"receipt_sha256": HASH,
		},
	}
	var programs: Array = []
	var process_id := 1
	for value in campaign["programs"]:
		var declared: Dictionary = value
		var left := replicate.duplicate(true)
		left["replicate"] = 1
		left["bundle_id"] = "%s.%s.r1" % [CERTIFICATION_ID, String(declared["program_id"])]
		left["target_process_id"] = process_id
		left["started_utc"] = "2026-07-22T22:%02d:00Z" % (process_id % 60)
		left["ended_utc"] = "2026-07-22T22:%02d:01Z" % (process_id % 60)
		left["assertions_passed"] = int(declared["expected_assertions"])
		process_id += 1
		var right := left.duplicate(true)
		right["replicate"] = 2
		right["bundle_id"] = "%s.%s.r2" % [CERTIFICATION_ID, String(declared["program_id"])]
		right["target_process_id"] = process_id
		right["started_utc"] = "2026-07-22T22:%02d:00Z" % (process_id % 60)
		right["ended_utc"] = "2026-07-22T22:%02d:01Z" % (process_id % 60)
		process_id += 1
		(
			programs
			. append(
				{
					"program_id": String(declared["program_id"]),
					"cell_id": String(declared["cell_id"]),
					"evidence_role": String(declared["evidence_role"]),
					"test": String(declared["test_resource_path"]).get_file(),
					"expected_assertions": int(declared["expected_assertions"]),
					"claim_scope": String(declared["claim_scope"]),
					"replicates": [left, right],
					"reconciliation":
					{
						"pass": true,
						"source_identity_match": true,
						"assertion_count_match": true,
						"ordered_assertion_labels_match": true,
						"both_raw_transcripts_retained": true,
						"raw_transcript_identity_required": false,
					},
				}
			)
		)
	var cells: Array = []
	for cell_id in ["BR13.0", "BR13.2", "BR13.4"]:
		var count := 0
		var assertions := 0
		for value in campaign["programs"]:
			var declared: Dictionary = value
			if (
				String(declared["cell_id"]) == cell_id
				and String(declared["evidence_role"]) == "milestone"
			):
				count += 1
				assertions += int(declared["expected_assertions"])
		(
			cells
			. append(
				{
					"cell_id": cell_id,
					"programs_required": count,
					"programs_passed": count,
					"assertions_per_replicate": assertions,
					"status": "pass",
				}
			)
		)
	return {
		"schema": "sporespore.lab.br13_certification_report.v1",
		"status": "pass",
		"certification": "BR13_CONSTRAINED_CANONICAL_GET_UP",
		"certification_id": CERTIFICATION_ID,
		"milestone_id": "BR13_CONSTRAINED_CANONICAL_GET_UP",
		"claim_boundary": String(campaign["claim_boundary"]),
		"generated_utc": "2026-07-22T22:00:00Z",
		"source":
		{
			"repository_root": "C:/repo",
			"commit_sha": COMMIT,
			"clean_at_start": true,
			"clean_at_end": true,
			"campaign_path": "C:/repo/campaign.json",
			"campaign_sha256": HASH,
			"source_inventory_sha256": HASH,
			"source_file_count": 1,
			"br1_inventory_path": "C:/repo/br1.json",
			"br1_inventory_sha256": HASH,
			"br1_inventory_unchanged": true,
		},
		"engine":
		{
			"executable": "C:/godot.exe",
			"sha256": HASH,
			"version": "4.7.stable.mono.official.5b4e0cb0f",
			"fresh_target_process_invocations": 10,
			"pid_recycle_events_recorded": true,
		},
		"bundle_policy":
		{
			"manifest_schema": "sporespore.lab.manifest.v1",
			"capsule_schema": "sporespore.lab.br13_canonical_get_up_evidence_capsule.v1",
			"metrics_schema": "sporespore.lab.br13_canonical_get_up_evidence_metrics.v1",
			"receipt_schema": "sporespore.lab.publication_attestation.v1",
			"receipt_domain": "sporespore.lab.publication_attestation.v1",
			"trust_mode": "production",
		},
		"report_attestation_policy":
		{
			"receipt_schema": ReportAttestationScript.RECEIPT_SCHEMA,
			"receipt_domain": ReportAttestationScript.RECEIPT_DOMAIN,
			"trust_mode": "production",
			"detached": true,
			"report_rewrite_after_attestation_forbidden": true,
		},
		"accounting":
		{
			"programs_required": 5,
			"programs_passed": 5,
			"replicates_per_program": 2,
			"bundles_required": 10,
			"bundles_passed": 10,
			"assertions_required": 180,
			"assertions_passed": 180,
			"milestone_programs": 3,
			"milestone_assertions": 114,
			"supplementary_programs": 0,
			"supplementary_assertions": 0,
			"integrity_programs": 2,
			"integrity_assertions": 66,
		},
		"cells": cells,
		"programs": programs,
		"final_readback":
		{
			"bundles_required": 10,
			"bundles_verified": 10,
			"receipts_required": 10,
			"receipts_verified": 10,
			"source_inventories_verified": 10,
			"metrics_verified": 10,
			"target_process_invocations": 10,
			"unique_target_processes": 10,
			"pid_recycle_events": 0,
			"complete_campaign": true,
		},
		"canonical_get_up_constraints":
		{
			"profile_id": "canonical_symmetry_collapsed_quadruped_prone_v1",
			"seed_set": ["13001", "13002", "13003"],
			"physics_hz": 120,
			"guide_type": "Generic6DOFJoint3D_out_of_plane_scaffold",
			"sagittal_x_y_translation_released": true,
			"root_pitch_released": true,
			"out_of_plane_translation_locked": true,
			"roll_and_yaw_locked": true,
			"front_and_rear_each_represent_mirrored_pair": true,
			"independent_left_right_control": false,
			"ordinary_unilateral_contacts_required": true,
			"guide_motors_or_springs_enabled": false,
			"built_in_joint_motors_enabled": false,
			"joint_limits_enabled": false,
			"passive_tissues_enabled": false,
			"foot_pin_enabled": false,
			"controller_root_rescue_enabled": false,
			"pose_teleport_enabled": false,
			"same_initial_state_control_required": true,
			"zero_command_control_required": true,
			"semantic_prone_start_required": true,
			"semantic_stance_terminal_required": true,
			"minimum_com_height_gain_m": 0.35,
			"transition_integrated_actuator_work_required": true,
			"mechanical_energy_reconciliation_required": true,
			"contact_dissipation_is_residual_inferred": true,
			"guide_work_is_residual_inferred_and_bounded": true,
			"finite_paired_hinge_actuator_required": true,
			"actuator_spec_digest_bound": true,
			"command_receipt_and_capacity_reconciliation": true,
			"exclusive_recovery_to_stance_handoff_required": true,
			"stable_stance_dwell_required": true,
			"constrained_planar_get_up_established": true,
			"actuator_saturation_allowed": true,
		},
		"capabilities":
		{
			"accepted_knowledge_entries": 0,
			"automatic_creature_guidance_allowed": false,
			"per_body_or_per_foot_measured_load_allocation": false,
			"constrained_planar_get_up": true,
			"paired_zero_command_control": true,
			"stable_stance_terminal": true,
			"free_3d_recovery": false,
			"morphology_transfer": false,
			"independent_four_limb_control": false,
			"general_standing": false,
			"bracing": false,
			"fall_arrest": false,
			"gait": false,
			"walking": false,
		},
		"does_not_establish": campaign["does_not_establish"],
	}


static func _read_json(path: String) -> Dictionary:
	var parser := JSON.new()
	assert(parser.parse(FileAccess.get_file_as_string(path)) == OK)
	assert(typeof(parser.data) == TYPE_DICTIONARY)
	return parser.data


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)
