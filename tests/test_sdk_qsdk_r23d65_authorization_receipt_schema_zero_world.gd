extends SceneTree

## Exercises the actual R23D65 Godot/Jolt production authorization receipt
## composer without creating a model or physics world.

const Worker := preload(
	"res://tests/test_sdk_qsdk_r23d65_godot_jolt_physical_worker.gd"
)
const REQUIRED_FIELD := "complete_ordered_nine_cell_matrix_validated"
const SUPERVISED_TERMINATION_ENV := "SPORESPORE_QSDK_R23D65_SUPERVISED_TERMINATION"
const TERMINATION_NONCE_ENV := "SPORESPORE_QSDK_R23D65_TERMINATION_NONCE"
const TERMINATION_READY_MARKER := "QSDK_R23D65_GODOT_SUPERVISOR_TERMINATION_READY "
const TERMINATION_PROTOCOL_ID := "godot_4_7_gdscript_shutdown_containment_v1"


func _initialize() -> void:
	var cell: Dictionary = Worker._r23d65_cell(
		Worker.R23D65_STAGE_ID,
		Worker.R23D65_ONSET_ID,
		Worker.R23D65_CAMPAIGN_SEED,
		Worker.R23D65_PROFILE_ID,
		"reference_zero",
	)
	_assert(bool(cell.get("ok", false)), "valid cell refused")
	var authorization := {
		"ok": true,
		"failure_code": "",
		REQUIRED_FIELD: true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
	var receipt: Dictionary = (
		Worker._r23d65_compose_authorization_preflight_receipt(
			cell,
			authorization,
		)
	)
	_assert(bool(receipt.get("ok", false)), "valid receipt composition failed")
	_assert(typeof(receipt.get(REQUIRED_FIELD)) == TYPE_BOOL, "proof type changed")
	_assert(bool(receipt.get(REQUIRED_FIELD)), "proof value changed")
	_assert(
		String(receipt.get("actual_production_receipt_composer", ""))
		== "_r23d65_compose_authorization_preflight_receipt",
		"production composer identity changed",
	)

	var mutations: Array[Dictionary] = []
	var missing := authorization.duplicate(true)
	missing.erase(REQUIRED_FIELD)
	mutations.append(missing)
	var false_value := authorization.duplicate(true)
	false_value[REQUIRED_FIELD] = false
	mutations.append(false_value)
	var wrong_type := authorization.duplicate(true)
	wrong_type[REQUIRED_FIELD] = "true"
	mutations.append(wrong_type)
	var alias := authorization.duplicate(true)
	alias.erase(REQUIRED_FIELD)
	alias["complete_nine_cell_matrix_validated"] = true
	mutations.append(alias)

	for mutation in mutations:
		var rejected: Dictionary = (
			Worker._r23d65_compose_authorization_preflight_receipt(
				cell,
				mutation,
			)
		)
		_assert(not bool(rejected.get("ok", true)), "schema mutation accepted")
		_assert(
			String(rejected.get("failure_code", ""))
			== "QSDK_R23D65_GJT_AUTHORIZATION_RECEIPT_SCHEMA_INVALID",
			"schema mutation failure code changed",
		)

	print(
		"QSDK_R23D65_GODOT_AUTHORIZATION_RECEIPT_SCHEMA_PASS ",
		JSON.stringify(
			{
				"schema_version": "sporespore_qsdk_r23d65_authorization_receipt_schema_engine_gate_v1",
				"engine_id": "godot_jolt",
				"required_field": REQUIRED_FIELD,
				"required_json_type": "boolean",
				"required_value": true,
				"actual_production_composer_invoked": true,
				"negative_control_count": mutations.size(),
				"negative_controls_passed": mutations.size(),
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			},
			"",
			true,
			true,
		),
	)
	if OS.get_environment(SUPERVISED_TERMINATION_ENV) == "1":
		var nonce := OS.get_environment(TERMINATION_NONCE_ENV)
		_assert(not nonce.is_empty(), "supervised termination nonce missing")
		print(
			TERMINATION_READY_MARKER,
			JSON.stringify(
				{
					"schema_version": "sporespore_godot_supervised_termination_ready_v1",
					"termination_protocol_id": TERMINATION_PROTOCOL_ID,
					"termination_nonce": nonce,
					"process_id": OS.get_process_id(),
					"requested_exit_code": 0,
					"worker_receipt_kind": "receipt_schema",
					"worker_receipt_emitted": true,
					"drained_process_frame_count": 0,
					"physics_evidence_authority": false,
				},
				"",
				true,
				true,
			),
		)
		return
	quit(0)


func _assert(condition: bool, message: String) -> void:
	assert(condition, "QSDK-R23D65 receipt-schema gate: %s" % message)
