extends SceneTree
# gdlint: disable=max-line-length

## Compact R139 zero-world coverage for the shared two-step route worker. It
## tests only campaign selection and the retained position-solver receipt seam;
## it creates no Node, RID, model, world, or solver step.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const RouteGhostWorker := preload(
	"res://tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
)
const MARKER := "QSDK_R24D139_GODOT_JOLT_POSITION_SOLVER_ROUTE_ZERO_WORLD "
const ACTUATOR_MODE := (
	"force_based_order_neutral_joint_space_effective_inertia_native_angular_velocity_guarded_v3"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JSON.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var legacy_binding_passed := RouteGhostWorker.route_binding_valid_v1(
		RouteScript.RECOVERY_CONTROLLER_ID,
		RouteScript.ROUTE_ID,
		"legacy_velocity_motor_v1",
	)
	var complete_energy_binding_passed := RouteGhostWorker.route_binding_valid_v1(
		RouteScript.RECOVERY_CONTROLLER_V6_ID,
		RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
		ACTUATOR_MODE,
	)
	var fixture := _native_fixture(1)
	var projection := RouteGhostWorker.complete_energy_solver_projection_v1(
		fixture,
		1,
		RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
	)
	var solver_projection_passed := (
		bool(projection.get("ok", false))
		and bool(projection.get("required", false))
		and bool(projection.get("position_phase_present", false))
		and bool(projection.get("position_coverage_complete", false))
		and bool(projection.get("native_complete", false))
	)

	var forced_failures: Array[bool] = [
		not RouteGhostWorker.route_binding_valid_v1(
			RouteScript.RECOVERY_CONTROLLER_ID,
			RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
			ACTUATOR_MODE,
		),
		not RouteGhostWorker.route_binding_valid_v1(
			RouteScript.RECOVERY_CONTROLLER_V6_ID,
			RouteScript.ROUTE_ID,
			ACTUATOR_MODE,
		),
		not RouteGhostWorker.route_binding_valid_v1(
			RouteScript.RECOVERY_CONTROLLER_V6_ID,
			RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
			"legacy_velocity_motor_v1",
		),
	]
	var missing_receipt := fixture.duplicate(true)
	(missing_receipt["measurement"]["source_component_receipts"] as Dictionary).erase(
		"solver_energy_exchange_receipt"
	)
	forced_failures.append(
		not bool(
			RouteGhostWorker.complete_energy_solver_projection_v1(
				missing_receipt,
				1,
				RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
			).get("ok", false)
		)
	)
	var false_position_phase := fixture.duplicate(true)
	var false_position_receipt: Dictionary = (
		false_position_phase["measurement"]["source_component_receipts"][
			"solver_energy_exchange_receipt"
		]
	)
	(false_position_receipt["ordered_checks"] as Dictionary)["position_phase_present"] = false
	forced_failures.append(
		not bool(
			RouteGhostWorker.complete_energy_solver_projection_v1(
				false_position_phase,
				1,
				RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
			).get("ok", false)
		)
	)
	var stale_sequence := fixture.duplicate(true)
	var stale_receipt: Dictionary = (
		stale_sequence["measurement"]["source_component_receipts"][
			"solver_energy_exchange_receipt"
		]
	)
	stale_receipt["read_space_step_sequence"] = 0
	forced_failures.append(
		not bool(
			RouteGhostWorker.complete_energy_solver_projection_v1(
				stale_sequence,
				1,
				RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
			).get("ok", false)
		)
	)
	var invalid_digest := fixture.duplicate(true)
	invalid_digest["measurement"]["source_component_receipts"][
		"solver_energy_exchange_receipt_sha256"
	] = "sha256:invalid"
	forced_failures.append(
		not bool(
			RouteGhostWorker.complete_energy_solver_projection_v1(
				invalid_digest,
				1,
				RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
			).get("ok", false)
		)
	)

	var rejected := forced_failures.count(true)
	var exact := (
		legacy_binding_passed
		and complete_energy_binding_passed
		and solver_projection_passed
		and rejected == forced_failures.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d139_godot_jolt_position_solver_route_zero_world_v1",
		"gate_id": "QSDK-R24D139",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D139_ZERO_WORLD_CONJUNCTION_INVALID",
		"question_class": "development",
		"runtime_profile_id": "godot_4_7_jolt_sporespore_solver_energy_position_velocity_read_access_v5",
		"route_profile_id": "godot_jolt_r24d139_complete_energy_position_solver_two_step_route_v1",
		"legacy_route_regression_passed": legacy_binding_passed,
		"complete_energy_route_binding_passed": complete_energy_binding_passed,
		"position_solver_receipt_projection_passed": solver_projection_passed,
		"positive_case_count": 3,
		"forced_failure_case_count": rejected,
		"historical_closure_audits_executed_count": 0,
		"bespoke_physical_canary_count": 0,
		"full_seeded_ghost_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _native_fixture(semantic_step: int) -> Dictionary:
	var checks := {
		"constrained_island_present": true,
		"velocity_coverage_complete": true,
		"position_coverage_complete": true,
		"joint_velocity_phase_present": true,
		"position_phase_present": true,
		"dynamic_body_observation_present": true,
		"invalid_body_measurement_zero": true,
		"large_island_velocity_zero": true,
		"large_island_position_zero": true,
		"ccd_active_body_zero": true,
		"active_soft_body_zero": true,
		"update_error_zero": true,
		"native_complete": true,
		"source_measurement": true,
		"residual_not_used": true,
	}
	var receipt := {
		"schema_version": "sporespore_qsdk_r24d136_godot_solver_energy_exchange_contract_v1",
		"ok": true,
		"expected_space_step_sequence": semantic_step,
		"capture_space_step_sequence": semantic_step,
		"read_space_step_sequence": semantic_step,
		"ordered_checks": checks,
		"check_count": checks.size(),
	}
	return {
		"ok": true,
		"measurement": {
			"source_component_receipts": {
				"schema_version": "sporespore_qsdk_r24d136_godot_complete_energy_source_component_receipts_v1",
				"solver_energy_exchange_receipt": receipt,
				"solver_energy_exchange_receipt_sha256": "sha256:%s" % "a".repeat(64),
			},
		},
	}
