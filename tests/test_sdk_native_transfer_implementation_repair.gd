extends SceneTree
# gdlint: disable=max-line-length

## Zero-world regression for the two Godot production seams exposed by R23D33.
##
## R23D33 remains closed. Its frozen fixture compiler is reused only as an
## input specimen. Every arm executes the exact live post-controller validator;
## no fixture node or physics world is created.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const ClosedWorkerScript := preload(
	"res://tests/test_sdk_qsdk_r23d33_godot_jolt_physical_worker.gd"
)

const R23D29_POLICY_ID := (
	"sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
	+ "stability_guarded_steering_v1"
)
const LEGACY_POLICY_ID := (
	"sporespore_balanced_wave_r23d21_reduced_yaw_authority_v1"
)
const LEGACY_MEMORY_SCHEMA := "sporespore_balanced_wave_memory_v1"
const PERSISTENT_MEMORY_SCHEMA := (
	"sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
)
const ARMS := ["reference_zero", "positive_heading", "negative_heading"]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK native-transfer implementation repair ===")
	var root_child_count_before := root.get_child_count()
	var production_receipts: Array[Dictionary] = []
	for arm_value in ARMS:
		var arm_id := String(arm_value)
		var cell := ClosedWorkerScript._r23d33_cell(
			ClosedWorkerScript.R23D33_STAGE_ID,
			ClosedWorkerScript.R23D33_ONSET_ID,
			arm_id,
		)
		var prepared := ClosedWorkerScript._r23d33_prepare(cell)
		_check(bool(cell.get("ok", false)), "%s closed-fixture cell compiles" % arm_id)
		_check(bool(prepared.get("ok", false)), "%s closed-fixture input prepares" % arm_id)
		if not bool(cell.get("ok", false)) or not bool(prepared.get("ok", false)):
			continue
		var receipt := _exercise_r23d29_production_validator(prepared, cell)
		production_receipts.append(receipt)
		_check(bool(receipt.get("ok", false)), "%s exact live validator accepts" % arm_id)
		_check(
			String(receipt.get("controller_receipt_schema", ""))
			== "sporespore_controller_step_receipt_v8",
			"%s policy-aware controller receipt is v8" % arm_id,
		)
		_check(
			String(receipt.get("expected_memory_schema", "")) == PERSISTENT_MEMORY_SCHEMA
			and String(receipt.get("observed_memory_schema", "")) == PERSISTENT_MEMORY_SCHEMA,
			"%s policy-aware next-memory schema is exact" % arm_id,
		)
		_check(
			not bool(receipt.get("legacy_memory_accepted", true)),
			"%s legacy memory mutation is rejected" % arm_id,
		)

	var legacy_controls := _exercise_legacy_policy_controls()
	_check(bool(legacy_controls.get("ok", false)), "legacy policy keeps legacy schema")
	_check(
		not bool(legacy_controls.get("persistent_memory_accepted", true)),
		"legacy policy rejects persistent-memory mutation",
	)
	_check(
		root.get_child_count() == root_child_count_before,
		"repair gate inserts no SceneTree node",
	)

	var exact := (
		_failed == 0
		and production_receipts.size() == ARMS.size()
		and bool(legacy_controls.get("ok", false))
	)
	var report := {
		"schema_version": "sporespore_native_transfer_implementation_repair_godot_v1",
		"ok": exact,
		"failure_code": "" if exact else "NATIVE_TRANSFER_GODOT_REPAIR_INVALID",
		"closed_campaign_reexecuted": false,
		"arm_count": production_receipts.size(),
		"production_post_step_validator_count": production_receipts.size(),
		"memory_schema_negative_control_count": ARMS.size() + 1,
		"production_receipts": production_receipts,
		"legacy_policy_controls": legacy_controls,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count() - root_child_count_before,
		"physics_state_modified": false,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
	}
	print("QSDK_NATIVE_TRANSFER_GODOT_REPAIR ", JSON.stringify(report))
	_finish()


func _exercise_r23d29_production_validator(
	prepared: Dictionary,
	cell: Dictionary,
) -> Dictionary:
	var adapter: RefCounted = AdapterScript.new()
	var start := _start_adapter(adapter, prepared, R23D29_POLICY_ID)
	if not bool(start.get("ok", false)):
		adapter = null
		return start
	var command := {
		"schema_version": "sporespore_heading_offset_command_v1",
		"schedule_id": String((prepared["schedule"] as Dictionary)["schedule_id"]),
		"segment_id": "commanded_turn",
		"command_role": "turn_heading",
		"heading_offset_rad": float(cell["turn_heading_offset_rad"]),
	}
	var runtime: Dictionary = adapter.preflight_perfect_declared_policy_runtime_boundary(command)
	var production: Dictionary = runtime.get("production_post_step_validation", {})
	var memory_receipt: Dictionary = production.get(
		"balanced_wave_memory_schema_receipt",
		{},
	)
	var native_output: Dictionary = production.get("native_output", {})
	var actuation: Dictionary = native_output.get("actuation", {})
	var controller_receipt: Dictionary = actuation.get("receipt", {})
	var legacy_mutation: Dictionary = adapter.preflight_balanced_wave_memory_schema_receipt(
		{"schema_version": LEGACY_MEMORY_SCHEMA}
	)
	var exact := (
		bool(runtime.get("ok", false))
		and bool(production.get("ok", false))
		and (production.get("failure_codes", []) as Array).is_empty()
		and bool(memory_receipt.get("ok", false))
		and String(memory_receipt.get("expected_memory_schema_version", ""))
		== PERSISTENT_MEMORY_SCHEMA
		and String(memory_receipt.get("observed_memory_schema_version", ""))
		== PERSISTENT_MEMORY_SCHEMA
		and String(controller_receipt.get("schema_version", ""))
		== "sporespore_controller_step_receipt_v8"
		and not bool(legacy_mutation.get("ok", true))
		and int(runtime.get("actual_world_build_count", -1)) == 0
		and int(runtime.get("scene_tree_insertion_count", -1)) == 0
		and not bool(runtime.get("physics_state_modified", true))
	)
	var result := {
		"ok": exact,
		"failure_code": "" if exact else "R23D29_PRODUCTION_VALIDATOR_INVALID",
		"arm_id": String(cell["arm_id"]),
		"controller_receipt_schema": String(controller_receipt.get("schema_version", "")),
		"expected_memory_schema": String(
			memory_receipt.get("expected_memory_schema_version", "")
		),
		"observed_memory_schema": String(
			memory_receipt.get("observed_memory_schema_version", "")
		),
		"legacy_memory_accepted": bool(legacy_mutation.get("ok", false)),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
	adapter = null
	return result


func _exercise_legacy_policy_controls() -> Dictionary:
	var cell := ClosedWorkerScript._r23d33_cell(
		ClosedWorkerScript.R23D33_STAGE_ID,
		ClosedWorkerScript.R23D33_ONSET_ID,
		"reference_zero",
	)
	var prepared := ClosedWorkerScript._r23d33_prepare(cell)
	if not bool(prepared.get("ok", false)):
		return prepared
	var adapter: RefCounted = AdapterScript.new()
	var start := _start_adapter(adapter, prepared, LEGACY_POLICY_ID)
	if not bool(start.get("ok", false)):
		adapter = null
		return start
	var legacy: Dictionary = adapter.preflight_balanced_wave_memory_schema_receipt(
		{"schema_version": LEGACY_MEMORY_SCHEMA}
	)
	var persistent: Dictionary = adapter.preflight_balanced_wave_memory_schema_receipt(
		{"schema_version": PERSISTENT_MEMORY_SCHEMA}
	)
	var exact := (
		bool(legacy.get("ok", false))
		and not bool(persistent.get("ok", true))
		and String(legacy.get("expected_memory_schema_version", "")) == LEGACY_MEMORY_SCHEMA
	)
	var result := {
		"ok": exact,
		"failure_code": "" if exact else "LEGACY_POLICY_MEMORY_CONTROL_INVALID",
		"legacy_memory_accepted": bool(legacy.get("ok", false)),
		"persistent_memory_accepted": bool(persistent.get("ok", false)),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
	adapter = null
	return result


func _start_adapter(
	adapter: RefCounted,
	prepared: Dictionary,
	policy_id: String,
) -> Dictionary:
	var phase_offset := int(
		(prepared["initial_perturbation"] as Dictionary)["gait_phase_offset_ticks"]
	)
	return adapter.start(
		prepared["descriptor"],
		ClosedWorkerScript.R23D33_GAIT_STEPS,
		0.0,
		Vector3.ZERO,
		Vector3.BACK,
		PI * 0.5,
		120,
		ClosedWorkerScript.R23D33_SOLVER_OPTIONS,
		2.5e-7,
		"clocked",
		true,
		phase_offset,
		360,
		"post_settle_full",
		"p5i3b_weight_support_shadow_v1",
		prepared["material_profile"],
		policy_id,
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", message)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % message)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
