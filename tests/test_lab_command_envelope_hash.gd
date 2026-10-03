extends SceneTree

const ActuationExecutorScript := preload("res://scripts/lab/actuation_executor.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const CommandLedgerScript := preload("res://scripts/lab/command_ledger.gd")
const ExecutionReceiptSinkScript := preload(
	"res://scripts/lab/records/execution_receipt.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab command-envelope hash contract ===")
	var mutable_diagnostics := {"nested": {"gain": 1.0}}
	var mutable_operation := {
		"operation_id": "noop_0",
		"body_id": "synthetic",
		"api": "lab.synthetic_noop",
		"arguments": {"value": 7},
	}
	var command_builder := {
		"tick": 0,
		"joint_id": "synthetic_joint",
		"diagnostics": mutable_diagnostics,
		"planned_application_operations": [mutable_operation],
	}
	var ledger = CommandLedgerScript.new()
	ledger.begin_tick(0)
	_check(ledger.queue_joint(command_builder), "mutable builder is accepted before seal")
	var envelope: Dictionary = ledger.seal({
		"run_id": "command_hash_run",
		"command_id": 0,
		"source_frame_id": 0,
		"applied_transition": [0, 1],
		"mode": "NONE",
	})
	var sealed_hash := String(envelope["command_payload_sha256"])
	var sealed_bytes := CanonicalJsonScript.stringify(envelope)
	mutable_diagnostics["nested"]["gain"] = 999.0
	mutable_operation["arguments"]["value"] = -1
	command_builder["planned_application_operations"].clear()
	_check(
		CanonicalJsonScript.stringify(envelope) == sealed_bytes,
		"retained builder mutation cannot change serialized envelope")
	_check(
		CanonicalJsonScript.sha256(envelope["payload"]) == sealed_hash,
		"retained builder mutation cannot change payload hash")
	var sink = ExecutionReceiptSinkScript.new("command_hash_run")
	var applied: Dictionary = ActuationExecutorScript.apply_command_envelope(
		envelope, {}, sink)
	_check(bool(applied["ok"]), "executor accepts the untampered sealed envelope")
	_check(sink.values().size() == 1, "synthetic plan produces exactly one receipt")
	var tampered := envelope.duplicate(true)
	tampered["payload"]["mode"] = "TAMPERED"
	var rejected: Dictionary = ActuationExecutorScript.apply_command_envelope(
		tampered, {}, ExecutionReceiptSinkScript.new("command_hash_run"))
	_check(
		not bool(rejected["ok"]) and rejected["error"] == "COMMAND_HASH_MISMATCH",
		"executor rejects post-seal payload tampering")
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
