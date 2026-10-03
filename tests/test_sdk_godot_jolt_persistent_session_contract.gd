extends SceneTree

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const NATIVE_CLASS_NAME := "SporeLocomotionSdk"
const TRANSPORT_VERSION := "sporespore_godot_json_preallocated_single_pass_v1"
const TRANSPORT_SCHEMA := "sporespore_godot_transport_execution_contract_v1"
const SESSION_VERSION := "sporespore_godot_balanced_wave_persistent_session_v1"
const SESSION_SCHEMA := "sporespore_godot_controller_session_execution_contract_v1"


class MissingSessionApi extends RefCounted:
	func transport_execution_version() -> String:
		return TRANSPORT_VERSION

	func transport_execution_contract_json() -> String:
		return JSON.stringify(_valid_transport_contract())

	func _valid_transport_contract() -> Dictionary:
		return {
			"schema_version": TRANSPORT_SCHEMA,
			"execution_version": TRANSPORT_VERSION,
			"input_transport": "normalized_json_utf8",
			"output_transport": "json_utf8",
			"initial_output_capacity_bytes": 16384,
			"normal_path_native_invocation_count": 1,
			"overflow_retry_limit": 1,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}


class ConfigurableSessionApi extends RefCounted:
	var mode := "valid"

	func _init(requested_mode: String) -> void:
		mode = requested_mode

	func transport_execution_version() -> String:
		return TRANSPORT_VERSION

	func transport_execution_contract_json() -> String:
		return JSON.stringify(
			{
				"schema_version": TRANSPORT_SCHEMA,
				"execution_version": TRANSPORT_VERSION,
				"input_transport": "normalized_json_utf8",
				"output_transport": "json_utf8",
				"initial_output_capacity_bytes": 16384,
				"normal_path_native_invocation_count": 1,
				"overflow_retry_limit": 1,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		)

	func controller_session_execution_version() -> String:
		return "tampered_session_version" if mode == "wrong_version" else SESSION_VERSION

	func controller_session_execution_contract_json() -> String:
		var compiled_reused := mode != "wrong_contract"
		return JSON.stringify(
			{
				"schema_version": SESSION_SCHEMA,
				"execution_version": SESSION_VERSION,
				"create_request_schema_version":
				"sporespore_balanced_wave_policy_session_create_request_v1",
				"initial_memory_request_schema_version":
				"sporespore_balanced_wave_policy_initial_memory_request_v1",
				"step_request_schema_version":
				"sporespore_balanced_wave_policy_session_step_request_v1",
				"controller_memory_initialization": "explicit_named_policy",
				"controller_memory_transport": "explicit_every_step",
				"compiled_morphology_reused": compiled_reused,
				"controller_profile_reused": true,
				"process_local_opaque_handle": true,
				"automatic_destroy_on_adapter_release": true,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		)

	func balanced_wave_policy_session_create_json(_input: String) -> String:
		return "{}"

	func balanced_wave_policy_session_step_json(_input: String) -> String:
		return "{}"

	func balanced_wave_policy_session_destroy_json() -> String:
		return "{}"

	func balanced_wave_policy_initial_memory_json(_input: String) -> String:
		return "{}"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var actual := AdapterScript.preflight_transport_execution()
	if not _is_exact_success(actual):
		_fail("live persistent-session preflight was not exact: %s" % actual)
		return

	var missing := AdapterScript._validate_transport_api(MissingSessionApi.new())
	if (
		bool(missing.get("ok", true))
		or String(missing.get("failure_code", ""))
		!= "ADAPTER_CONTROLLER_SESSION_VERSION_METHOD_MISSING"
		or not _is_zero_world_failure(missing)
	):
		_fail("missing-session canary did not fail closed: %s" % missing)
		return

	var wrong_version := AdapterScript._validate_transport_api(
		ConfigurableSessionApi.new("wrong_version")
	)
	if (
		bool(wrong_version.get("ok", true))
		or String(wrong_version.get("failure_code", ""))
		!= "ADAPTER_CONTROLLER_SESSION_EXECUTION_VERSION_MISMATCH"
		or not _is_zero_world_failure(wrong_version)
	):
		_fail("wrong-session-version canary did not fail closed: %s" % wrong_version)
		return

	var wrong_contract := AdapterScript._validate_transport_api(
		ConfigurableSessionApi.new("wrong_contract")
	)
	if (
		bool(wrong_contract.get("ok", true))
		or String(wrong_contract.get("failure_code", ""))
		!= "ADAPTER_CONTROLLER_SESSION_CONTRACT_MISMATCH"
		or not _is_zero_world_failure(wrong_contract)
	):
		_fail("wrong-session-contract canary did not fail closed: %s" % wrong_contract)
		return

	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(NATIVE_CLASS_NAME):
		_fail("live GDExtension or native class is unavailable")
		return
	var api: Object = ClassDB.instantiate(NATIVE_CLASS_NAME)
	if api == null:
		_fail("live native class could not be instantiated")
		return
	var create := _call_input(
		api,
		"balanced_wave_policy_session_create_json",
		{
			"schema_version":
			"sporespore_balanced_wave_policy_session_create_request_v1",
			"policy_id": "sporespore_balanced_wave_bw5r_b_v1",
			"descriptor": _reference_descriptor(),
		},
	)
	var receipt: Dictionary = create.get("value", {})
	if (
		not bool(create.get("ok", false))
		or String(receipt.get("schema_version", ""))
		!= "sporespore_godot_balanced_wave_policy_session_receipt_v1"
		or String(receipt.get("execution_version", "")) != SESSION_VERSION
		or not bool(receipt.get("active", false))
		or int(receipt.get("world_build_count", -1)) != 0
		or bool(receipt.get("physical_acceptance_authority", true))
	):
		_fail("live session create receipt was invalid: %s" % create)
		return
	var duplicate := _call_input(
		api,
		"balanced_wave_policy_session_create_json",
		{
			"schema_version":
			"sporespore_balanced_wave_policy_session_create_request_v1",
			"policy_id": "sporespore_balanced_wave_bw5r_b_v1",
			"descriptor": _reference_descriptor(),
		},
	)
	if (
		bool(duplicate.get("ok", true))
		or String(duplicate.get("failure_code", ""))
		!= "GODOT_ADAPTER_CONTROLLER_SESSION_ALREADY_ACTIVE"
	):
		_fail("duplicate-create lifecycle canary did not fail closed: %s" % duplicate)
		return
	var destroy := _call_no_input(api, "balanced_wave_policy_session_destroy_json")
	if (
		not bool(destroy.get("ok", false))
		or bool((destroy.get("value", {}) as Dictionary).get("active", true))
	):
		_fail("live session destroy receipt was invalid: %s" % destroy)
		return
	var duplicate_destroy := _call_no_input(
		api,
		"balanced_wave_policy_session_destroy_json",
	)
	if (
		bool(duplicate_destroy.get("ok", true))
		or String(duplicate_destroy.get("failure_code", ""))
		!= "GODOT_ADAPTER_CONTROLLER_SESSION_NOT_ACTIVE"
	):
		_fail("duplicate-destroy lifecycle canary did not fail closed: %s" % duplicate_destroy)
		return

	print(
		"GODOT_JOLT_PERSISTENT_SESSION_CONTRACT_PASS ",
		JSON.stringify(
			{
				"session_execution_version": SESSION_VERSION,
				"negative_canary_count": 5,
				"live_create_count": 1,
				"live_destroy_count": 1,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		)
	)
	quit(0)


func _reference_descriptor() -> Dictionary:
	return {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": "gjps1_live_reference",
		"torso_length_scale": 1.0,
		"torso_width_scale": 1.0,
		"upper_length_fraction": 18.0 / 35.0,
		"hip_span_scale": 1.0,
		"foot_radius_scale": 1.0,
		"front_limb_mass_scale": 1.0,
	}


func _call_input(api: Object, method: String, request: Dictionary) -> Dictionary:
	var value: Variant = JSON.parse_string(
		String(api.call(method, JSON.stringify(request, "", true, true)))
	)
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _call_no_input(api: Object, method: String) -> Dictionary:
	var value: Variant = JSON.parse_string(String(api.call(method)))
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _is_exact_success(receipt: Dictionary) -> bool:
	var contract: Dictionary = receipt.get("controller_session_execution_contract", {})
	return (
		bool(receipt.get("ok", false))
		and String(receipt.get("controller_session_execution_version", ""))
		== SESSION_VERSION
		and String(contract.get("schema_version", "")) == SESSION_SCHEMA
		and String(contract.get("execution_version", "")) == SESSION_VERSION
		and bool(contract.get("compiled_morphology_reused", false))
		and bool(contract.get("controller_profile_reused", false))
		and String(contract.get("initial_memory_request_schema_version", ""))
		== "sporespore_balanced_wave_policy_initial_memory_request_v1"
		and String(contract.get("controller_memory_initialization", ""))
		== "explicit_named_policy"
		and String(contract.get("controller_memory_transport", ""))
		== "explicit_every_step"
		and String(
			receipt.get("controller_session_execution_contract_sha256", "")
		).begins_with("sha256:")
		and _is_zero_world_failure(receipt)
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
