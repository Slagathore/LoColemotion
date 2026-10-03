extends SceneTree
# gdlint: disable=max-line-length

## Thin R123 binding over the reusable versioned raise-body speed evaluator.
## R120 supplies the complete historical V1-V4 regression; this binding names
## only the V4-to-V5 identities and immutable expected content.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const HistoricalControllerTest := preload(
	"res://tests/test_sdk_qsdk_r24d120_godot_raise_body_speed_controller_zero_world.gd"
)
const Evaluator := preload("res://tests/helpers/versioned_recovery_raise_body_speed_zero_world.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_R24D123_RAISE_BODY_SPEED_ZERO_WORLD "


func _initialize() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	return (
		Evaluator
		. evaluate(
			{
				"schema_version":
				"sporespore_qsdk_r24d123_godot_raise_body_speed_controller_zero_world_v1",
				"gate_id": "QSDK-R24D123",
				"failure_prefix": "QSDK_R24D123",
				"historical_regression": HistoricalControllerTest._evaluate(),
				"historical_regression_key": "historical_v1_v4_regression_passed",
				"historical_controller_id": RouteScript.RECOVERY_CONTROLLER_V4_ID,
				"successor_controller_id": RouteScript.RECOVERY_CONTROLLER_V5_ID,
				"historical_profile_sha256":
				"sha256:2e9f4f5720aec96b28552a04c8f1b6bbfeb3b01eaceac76834b450cb0d9b4900",
				"successor_profile_sha256":
				"sha256:fe6beb259550c06e137fc89a5e752d2cfc088edd5f8136cd944c5776a4c34909",
				"support_command_sha256":
				"sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4",
				"historical_raise_command_sha256":
				[
					"sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4",
					"sha256:fd799c70aa596c6f1ce9e8edfa31ed381ff2cb598b820fad9926ce22749b7f2a",
					"sha256:9282c43fdecacd25f8524775ce87f87297fa3d1f2ba99d7e9d8fc3e5ab450022",
				],
				"successor_raise_command_sha256":
				[
					"sha256:ddef8c449c3c02109ae5f23cac0df5627df0513c7d07270f79dd865bd46040bc",
					"sha256:6a3bea40b02478ecf05c7baf4a77d27d8b7688cadb6d83b0f441a174b551691d",
					"sha256:c6398659885964de9b154d520c90311f3896881557aa93b4ce90cd1f048a783f",
				],
				"historical_speed_rad_s": 8.0,
				"successor_speed_rad_s": 22.0,
				"prepare_historical": Callable(RouteScript, "prepare_context_v4"),
				"prepare_successor": Callable(RouteScript, "prepare_context_v5"),
				"fixture_historical": Callable(RouteScript, "zero_world_fixture_v4"),
				"fixture_successor": Callable(RouteScript, "zero_world_fixture_v5"),
				"bootstrap_successor": Callable(RouteScript, "initial_behavior_application_v5"),
				"invalid_context_failure_code": "QSDK_R24D123_CONTROLLER_ID_INVALID",
				"invalid_bootstrap_failure_code": "QSDK_R24D123_INITIAL_CONTROLLER_ID_INVALID",
			}
		)
	)
