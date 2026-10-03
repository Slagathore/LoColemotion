extends SceneTree
# gdlint: disable=max-line-length

## Thin R127 binding over the reusable versioned-controller evaluator. R123
## supplies the complete V1-V5 regression; this successor preserves V5's
## portable commands and qualifies only the explicit solver-coupled Godot
## realization binding with uninserted hinges and zero physics worlds.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const HistoricalControllerTest := preload(
	"res://tests/test_sdk_qsdk_r24d123_godot_raise_body_speed_controller_zero_world.gd"
)
const Evaluator := preload("res://tests/helpers/versioned_recovery_raise_body_speed_zero_world.gd")
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_R24D127_SOLVER_COUPLED_CONTROLLER_ZERO_WORLD "


func _initialize() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var result := (
		Evaluator
		. evaluate(
			{
				"schema_version":
				"sporespore_qsdk_r24d127_godot_solver_coupled_controller_zero_world_v1",
				"gate_id": "QSDK-R24D127",
				"failure_prefix": "QSDK_R24D127",
				"authority_mode": "zero_world_versioned_solver_coupled_realization_implementation",
				"historical_regression": HistoricalControllerTest._evaluate(),
				"historical_regression_key": "historical_v1_v5_regression_passed",
				"historical_controller_id": RouteScript.RECOVERY_CONTROLLER_V5_ID,
				"successor_controller_id": RouteScript.RECOVERY_CONTROLLER_V6_ID,
				"historical_profile_sha256":
				"sha256:fe6beb259550c06e137fc89a5e752d2cfc088edd5f8136cd944c5776a4c34909",
				"successor_profile_sha256":
				"sha256:a764ea9f96bc9dbb00d594d87603aa87a95bf7a43c03085520952138f3989d33",
				"support_command_sha256":
				"sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4",
				"historical_raise_command_sha256":
				[
					"sha256:ddef8c449c3c02109ae5f23cac0df5627df0513c7d07270f79dd865bd46040bc",
					"sha256:6a3bea40b02478ecf05c7baf4a77d27d8b7688cadb6d83b0f441a174b551691d",
					"sha256:c6398659885964de9b154d520c90311f3896881557aa93b4ce90cd1f048a783f",
				],
				"successor_raise_command_sha256":
				[
					"sha256:ddef8c449c3c02109ae5f23cac0df5627df0513c7d07270f79dd865bd46040bc",
					"sha256:6a3bea40b02478ecf05c7baf4a77d27d8b7688cadb6d83b0f441a174b551691d",
					"sha256:c6398659885964de9b154d520c90311f3896881557aa93b4ce90cd1f048a783f",
				],
				"historical_speed_rad_s": 22.0,
				"successor_speed_rad_s": 22.0,
				"expected_changed_speed_count": 0,
				"speed_mutation_value_rad_s": 8.0,
				"prepare_historical": Callable(RouteScript, "prepare_context_v5"),
				"prepare_successor": Callable(RouteScript, "prepare_context_v6"),
				"fixture_historical": Callable(RouteScript, "zero_world_fixture_v5"),
				"fixture_successor": Callable(RouteScript, "zero_world_fixture_v6"),
				"bootstrap_successor": Callable(RouteScript, "initial_behavior_application_v6"),
				"apply_successor":
				Callable(
					RouteScript,
					"apply_behavior_control_solver_coupled_native_constraint_motor_v10",
				),
				"invalid_context_failure_code": "QSDK_R24D127_CONTROLLER_ID_INVALID",
				"invalid_bootstrap_failure_code": "QSDK_R24D127_INITIAL_CONTROLLER_ID_INVALID",
				"unknown_application_failure_code":
				"QSDK_R24D127_CONTROLLER_REALIZATION_IDENTITY_INVALID",
				"historical_realization_failure_code":
				"QSDK_R24D127_CONTROLLER_REALIZATION_IDENTITY_INVALID",
				"mutated_realization_failure_code":
				"QSDK_R24D127_ACTUATION_REALIZATION_INVALID",
				"expected_realization_mismatch_refusal_count": 2,
				"expected_actuation_realization_id":
				RouteScript.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID,
				"expected_energy_source_profile_id": RouteScript.ENERGY_MAPPING_PROFILE_ID,
			}
		)
	)
	var pairing_control_count := (
		int(
			BehaviorWorker.actuator_mode_controller_pair_valid_v1(
				BehaviorWorker.ACTUATOR_MODE_SOLVER_COUPLED,
				RouteScript.RECOVERY_CONTROLLER_V6_ID,
			)
		)
		+ int(
			BehaviorWorker.actuator_mode_controller_pair_valid_v1(
				BehaviorWorker.ACTUATOR_MODE_LEGACY,
				RouteScript.RECOVERY_CONTROLLER_V5_ID,
			)
		)
		+ int(
			not BehaviorWorker.actuator_mode_controller_pair_valid_v1(
				BehaviorWorker.ACTUATOR_MODE_SOLVER_COUPLED,
				RouteScript.RECOVERY_CONTROLLER_V5_ID,
			)
		)
		+ int(
			not BehaviorWorker.actuator_mode_controller_pair_valid_v1(
				BehaviorWorker.ACTUATOR_MODE_FORCE_BASED,
				RouteScript.RECOVERY_CONTROLLER_V6_ID,
			)
		)
	)
	result["production_worker_pairing_control_count"] = pairing_control_count
	if pairing_control_count != 4:
		result["ok"] = false
		result["failure_code"] = "QSDK_R24D127_PRODUCTION_WORKER_PAIRING_INVALID"
	return result
