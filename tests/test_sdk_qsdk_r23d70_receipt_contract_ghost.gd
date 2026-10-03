extends SceneTree

const ReceiptContract := preload("res://sdk/turning/r23d70_receipt_contract.gd")


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	printerr("QSDK_R23D70_GODOT_RECEIPT_GHOST_FAILURE ", message)
	quit(1)


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("RECEIPT_PATH_ARGUMENT_INVALID")
		return
	var path := String(arguments[0])
	if not FileAccess.file_exists(path):
		_fail("RECEIPT_PATH_MISSING")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("RECEIPT_JSON_INVALID")
		return
	var receipt: Dictionary = parsed
	var expected := {
		"schema_version": "sporespore_qsdk_r23d70_trace_retention_v1",
		"stage_id": "trace_retention_receipt_contract_ghost",
		"cell_id": "r23d70_receipt_contract_ghost",
		"engine_id": "contract_ghost",
		"campaign_seed": 23189,
		"profile_id": "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1",
		"host_mapping_id": "contract_ghost",
		"row_count": 2,
		"test_only": true,
	}
	var positive := ReceiptContract.validate_retention_receipt(receipt, expected)
	if not positive.is_empty():
		_fail("POSITIVE_REJECTED:%s" % ",".join(positive))
		return
	var mutations: Array[Dictionary] = []
	var missing := receipt.duplicate(true)
	missing.erase("row_count")
	mutations.append(missing)
	var wrong_integer := receipt.duplicate(true)
	wrong_integer["row_count"] = 3
	mutations.append(wrong_integer)
	var wrong_type := receipt.duplicate(true)
	wrong_type["row_count"] = "2"
	mutations.append(wrong_type)
	var nested_mismatch := receipt.duplicate(true)
	nested_mismatch["trace_summary"]["row_count"] = 1
	mutations.append(nested_mismatch)
	for index in mutations.size():
		var failures := ReceiptContract.validate_retention_receipt(mutations[index], expected)
		if failures.is_empty():
			_fail("NEGATIVE_ACCEPTED:%d" % index)
			return
	print(
		"QSDK_R23D70_GODOT_RECEIPT_GHOST ",
		JSON.stringify(
			{
				"schema_version": "sporespore_qsdk_r23d70_godot_receipt_contract_ghost_v1",
				"positive_passed": true,
				"negative_decision_count": 4,
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			},
			"",
			true,
			true
		)
	)
	quit(0)
