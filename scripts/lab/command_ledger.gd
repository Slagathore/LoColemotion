class_name LabCommandLedger
extends RefCounted

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

var _tick := -1
var _sealed := true
var _joint_commands: Array = []
var _sealed_envelope: Dictionary = {}
var sealed_sha256 := ""
var last_error := ""


func begin_tick(tick: int) -> bool:
	if not _sealed or tick < 0:
		last_error = "LEDGER_NOT_READY"
		return false
	_tick = tick
	_sealed = false
	_joint_commands.clear()
	_sealed_envelope = {}
	sealed_sha256 = ""
	last_error = ""
	return true


func queue_joint(command: Variant) -> bool:
	if _sealed:
		last_error = "LEDGER_ALREADY_SEALED"
		return false
	var value: Dictionary
	if command is Dictionary:
		value = command
	elif command is RefCounted and command.has_method("to_value_dictionary"):
		value = command.call("to_value_dictionary")
	else:
		last_error = "INVALID_COMMAND_TYPE"
		return false
	if int(value.get("tick", -1)) != _tick:
		last_error = "COMMAND_TICK_MISMATCH"
		return false
	_joint_commands.append(value)
	return true


func seal(record_fields: Dictionary) -> Dictionary:
	if _sealed:
		last_error = "LEDGER_ALREADY_SEALED"
		return {}
	if (int(record_fields.get("command_id", -1)) != _tick
		or record_fields.has("joint_commands")
		or record_fields.has("command_payload_sha256")):
		last_error = "INVALID_COMMAND_RECORD_FIELDS"
		return {}
	var joint_values: Array = []
	for command in _joint_commands:
		joint_values.append(FrozenValueScript.snapshot(command))
	joint_values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("joint_id", "")) < String(b.get("joint_id", "")))
	_joint_commands.clear()
	var payload_builder := record_fields.duplicate(true)
	payload_builder["schema"] = "sporespore.lab.command.v1"
	payload_builder["joint_commands"] = joint_values
	if not payload_builder.has("intervention_operation_ids"):
		payload_builder["intervention_operation_ids"] = []
	var payload: Dictionary = FrozenValueScript.snapshot(payload_builder)
	sealed_sha256 = CanonicalJsonScript.sha256(payload)
	_sealed_envelope = FrozenValueScript.snapshot({
		"command_payload_sha256": sealed_sha256,
		"payload": payload,
	})
	_sealed = true
	last_error = ""
	return _sealed_envelope


func sealed_envelope() -> Dictionary:
	return _sealed_envelope
