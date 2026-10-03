extends SceneTree

const InterventionExecutorScript := preload(
	"res://scripts/lab/intervention_executor.gd")
const InterventionRecordScript := preload(
	"res://scripts/lab/records/intervention_record.gd")
const ExecutionReceiptSinkScript := preload(
	"res://scripts/lab/records/execution_receipt.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab application-receipt contract ===")
	var envelope: Dictionary = InterventionRecordScript.seal({
		"run_id": "receipt_run",
		"record_kind": "planned_operation",
		"operation_id": "synthetic_fixture_0",
		"source_frame_id": 0,
		"applied_transition": [0, 1],
		"source": "fixture.contract_test",
		"type": "synthetic_noop",
		"planned_api": "lab.synthetic_noop",
		"target_body_id": "none",
		"allowed": true,
		"experiment_phase": "MEASURE",
		"availability": {},
	})
	var sink = ExecutionReceiptSinkScript.new("receipt_run")
	var result: Dictionary = InterventionExecutorScript.apply_intervention_envelope(
		envelope, {}, sink)
	var receipts: Array = sink.values()
	_check(bool(result["ok"]), "sealed synthetic intervention executes")
	_check(receipts.size() == 1, "one planned operation produces one receipt")
	_check(receipts[0]["source_kind"] == "intervention", "receipt discriminates source kind")
	_check(
		receipts[0]["source_payload_sha256"]
			== envelope["intervention_payload_sha256"],
		"receipt cross-links the exact immutable plan hash")
	_check(
		receipts[0]["operation_id"] == envelope["payload"]["operation_id"],
		"receipt cross-links the planned operation ID")
	_check(receipts[0]["status"] == "call_returned", "receipt records call disposition")
	_finish()


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
