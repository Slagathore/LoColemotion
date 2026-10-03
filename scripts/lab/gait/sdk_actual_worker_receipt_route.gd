class_name LabSdkActualWorkerReceiptRoute
extends RefCounted

## Shared zero-world/physical raw-receipt route for successors that inherit
## BW25Y's physical fixture. The actual inherited constructor is always called;
## this layer requires the successor to declare every compatibility field,
## repairs only the explicit broad-base observation, and computes structural
## completeness from the contract instead of trusting a worker assertion.

const ROUTE_SCHEMA := "sporespore_actual_worker_receipt_route_v1"


static func compose(
	owner: Object,
	cell_value: Dictionary,
	summary: Dictionary,
	required_common_keys: Array,
	required_role_keys: Array,
	campaign_attempt_id: String,
	world_attempt_id: String,
) -> Dictionary:
	var cell := cell_value.duplicate(true)
	var role := String(cell.get("role", ""))
	# Do not manufacture a cohort here. BW25Y failed because its frozen cell did
	# not declare this inherited-constructor input. A physical successor must bind
	# it in its own preregistration, while zero-world commissioning supplies an
	# explicitly labelled fixture value before entering this shared route.
	if not cell.has("cohort") or String(cell.get("cohort", "")).is_empty():
		return {
			"receipt_route_schema": ROUTE_SCHEMA,
			"raw_receipt_complete": false,
			"receipt_route_failure_codes": ["MISSING_DECLARED_COHORT"],
			"walking_result_controls_process_exit": false,
			"physical_acceptance_authority": false,
		}
	var receipt_value: Variant
	if role == "safety":
		receipt_value = owner.call("_bw25y_zero_safety_receipt", cell, summary)
	else:
		receipt_value = owner.call("_bw25y_physical_cell_receipt", cell, summary)
	if typeof(receipt_value) != TYPE_DICTIONARY:
		return {
			"receipt_route_schema": ROUTE_SCHEMA,
			"raw_receipt_complete": false,
			"receipt_route_failure_codes": ["ACTUAL_CONSTRUCTOR_DID_NOT_RETURN_DICTIONARY"],
			"physical_acceptance_authority": false,
		}
	var receipt: Dictionary = receipt_value
	# The inherited BW19V scale-0 control intentionally reports no residual
	# overlay influence. The still-active portable base is observed by its native
	# motor writes; preserve that distinct observation explicitly.
	if role == "control":
		receipt["broad_base_controller_physical_influence_observed"] = (
			int(receipt.get("sdk_native_motor_write_count", -1)) > 0
		)
	receipt["world_attempt_id"] = world_attempt_id
	receipt["campaign_attempt_id"] = campaign_attempt_id
	receipt["walking_result_controls_process_exit"] = false
	var validation := validate_structure(
		receipt,
		cell,
		required_common_keys,
		required_role_keys,
		campaign_attempt_id,
		world_attempt_id,
	)
	receipt["receipt_route_schema"] = ROUTE_SCHEMA
	receipt["receipt_route_failure_codes"] = validation["failure_codes"]
	receipt["raw_receipt_complete"] = bool(validation["ok"])
	receipt["role_gate_passed"] = bool(owner.call("_role_gate_passed", receipt))
	receipt["physical_acceptance_authority"] = false
	return receipt


static func validate_structure(
	receipt: Dictionary,
	expected_cell: Dictionary,
	required_common_keys: Array,
	required_role_keys: Array,
	campaign_attempt_id: String,
	world_attempt_id: String,
) -> Dictionary:
	var failures: Array[String] = []
	for key_value in required_common_keys + required_role_keys:
		var key := String(key_value)
		if not receipt.has(key):
			failures.append("MISSING_KEY::" + key)
	if String(receipt.get("cell_id", "")) != String(expected_cell.get("cell_id", "")):
		failures.append("CELL_ID_MISMATCH")
	if String(receipt.get("role", "")) != String(expected_cell.get("role", "")):
		failures.append("ROLE_MISMATCH")
	if String(receipt.get("cohort", "")) != String(expected_cell.get("cohort", "")):
		failures.append("COHORT_MISMATCH")
	if int(receipt.get("campaign_seed", -1)) != int(expected_cell.get("campaign_seed", -2)):
		failures.append("CAMPAIGN_SEED_MISMATCH")
	if String(receipt.get("campaign_attempt_id", "")) != campaign_attempt_id:
		failures.append("CAMPAIGN_ATTEMPT_ID_MISMATCH")
	if String(receipt.get("world_attempt_id", "")) != world_attempt_id:
		failures.append("WORLD_ATTEMPT_ID_MISMATCH")
	if typeof(receipt.get("walking_gate_receipts")) != TYPE_DICTIONARY:
		failures.append("WALKING_RECEIPT_NOT_DICTIONARY")
	failures.sort()
	return {
		"schema_version": ROUTE_SCHEMA,
		"ok": failures.is_empty(),
		"failure_codes": failures,
		"required_key_count": required_common_keys.size() + required_role_keys.size(),
		"physical_acceptance_authority": false,
	}
