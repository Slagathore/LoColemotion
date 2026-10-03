extends SceneTree

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const FixedRunnerScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const FixedHorizonRunnerScript := preload(
	"res://scripts/lab/gait/physical_wave_gait_quadruped_bw30n_fixed_horizon.gd"
)
const EXPECTED_EXECUTION_VERSION := "sporespore_godot_json_preallocated_single_pass_v1"
const EXPECTED_CONTRACT_SCHEMA := "sporespore_godot_transport_execution_contract_v1"


class MissingTransportApi extends RefCounted:
	pass


class WrongVersionApi extends RefCounted:
	func transport_execution_version() -> String:
		return "tampered_transport_version"

	func transport_execution_contract_json() -> String:
		return "{}"


class WrongContractApi extends RefCounted:
	func transport_execution_version() -> String:
		return EXPECTED_EXECUTION_VERSION

	func transport_execution_contract_json() -> String:
		return JSON.stringify(
			{
				"schema_version": EXPECTED_CONTRACT_SCHEMA,
				"execution_version": EXPECTED_EXECUTION_VERSION,
				"input_transport": "normalized_json_utf8",
				"output_transport": "json_utf8",
				"initial_output_capacity_bytes": 16384,
				"normal_path_native_invocation_count": 2,
				"overflow_retry_limit": 1,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		)


func _initialize() -> void:
	if FixedRunnerScript == null or FixedHorizonRunnerScript == null:
		_fail("one or both transport-bound real-physics runner scripts failed to load")
		return
	var actual := AdapterScript.preflight_transport_execution()
	if not _is_exact_success(actual):
		_fail("live transport preflight did not return the exact zero-world contract: %s" % actual)
		return

	var missing := AdapterScript._validate_transport_api(MissingTransportApi.new())
	if (
		bool(missing.get("ok", true))
		or String(missing.get("failure_code", ""))
		!= "ADAPTER_TRANSPORT_VERSION_METHOD_MISSING"
		or not _is_zero_world_failure(missing)
	):
		_fail("missing-method canary did not fail closed: %s" % missing)
		return

	var wrong_version := AdapterScript._validate_transport_api(WrongVersionApi.new())
	if (
		bool(wrong_version.get("ok", true))
		or String(wrong_version.get("failure_code", ""))
		!= "ADAPTER_TRANSPORT_EXECUTION_VERSION_MISMATCH"
		or not _is_zero_world_failure(wrong_version)
	):
		_fail("wrong-version canary did not fail closed: %s" % wrong_version)
		return

	var wrong_contract := AdapterScript._validate_transport_api(WrongContractApi.new())
	if (
		bool(wrong_contract.get("ok", true))
		or String(wrong_contract.get("failure_code", ""))
		!= "ADAPTER_TRANSPORT_CONTRACT_MISMATCH"
		or not _is_zero_world_failure(wrong_contract)
	):
		_fail("wrong-contract canary did not fail closed: %s" % wrong_contract)
		return

	print(
		"GODOT_JOLT_TRANSPORT_EXECUTION_CONTRACT_PASS ",
		JSON.stringify(
			{
				"execution_version": EXPECTED_EXECUTION_VERSION,
				"normal_path_native_invocation_count": 1,
				"overflow_retry_limit": 1,
				"negative_canary_count": 3,
				"transport_bound_runner_count": 2,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		)
	)
	quit(0)


func _is_exact_success(receipt: Dictionary) -> bool:
	var contract: Dictionary = receipt.get("transport_execution_contract", {})
	return (
		bool(receipt.get("ok", false))
		and String(receipt.get("failure_code", "")).is_empty()
		and String(receipt.get("transport_execution_version", ""))
		== EXPECTED_EXECUTION_VERSION
		and String(contract.get("schema_version", "")) == EXPECTED_CONTRACT_SCHEMA
		and String(contract.get("execution_version", "")) == EXPECTED_EXECUTION_VERSION
		and int(contract.get("initial_output_capacity_bytes", -1)) == 16384
		and int(contract.get("normal_path_native_invocation_count", -1)) == 1
		and int(contract.get("overflow_retry_limit", -1)) == 1
		and int(receipt.get("world_build_count", -1)) == 0
		and int(receipt.get("scene_tree_insertion_count", -1)) == 0
		and not bool(receipt.get("physics_state_modified", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
		and String(receipt.get("transport_execution_contract_sha256", "")).begins_with(
			"sha256:"
		)
	)


func _is_zero_world_failure(receipt: Dictionary) -> bool:
	return (
		int(receipt.get("world_build_count", -1)) == 0
		and int(receipt.get("scene_tree_insertion_count", -1)) == 0
		and not bool(receipt.get("physics_state_modified", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
	)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
