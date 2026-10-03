extends SceneTree
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Crosses the R23D64 Godot production cap route without constructing a world.
## The real GDExtension resolves the public R23D61 profile, the exact hinge
## objects later used by the physical fixture receive all eight writes and
## readbacks, and the adapter applies one explicit command to those same
## unparented objects. Negative controls must return before their first write.

const BaseRouteTest := preload(
	"res://tests/test_sdk_qsdk_r23d58_godot_physical_route_cap_factorial_zero_world.gd"
)
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const PublicRouteScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_public_actuator_cap_profile_binding.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const READBACK_TOLERANCE_NMS := 2.5e-7
const EXPECTED_ROUTE_MUTATION_REJECTION_COUNT := 5
const EXPECTED_NORMALIZATION_MUTATION_REJECTION_COUNT := 2


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(
		"QSDK_R23D64_GODOT_PUBLIC_PROFILE_PHYSICAL_ROUTE_ZERO_WORLD ",
		JsonTransportScript.stringify(result),
	)
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var prepared := BaseRouteTest._prepared_boundary()
	if not bool(prepared.get("ok", false)):
		return _failure("R23D64_GODOT_PUBLIC_ROUTE_PREPARATION_INVALID", prepared)
	var started := BaseRouteTest._started_adapter(prepared)
	if not bool(started.get("ok", false)):
		return _failure("R23D64_GODOT_PUBLIC_ROUTE_ADAPTER_START_INVALID", started)
	var adapter: RefCounted = started["adapter"]
	var morphology: Dictionary = started["morphology"]
	var compiled_boundary := {
		"ok": true,
		"failure_code": "",
		"morphology": morphology.duplicate(true),
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	var request := _authority_request(prepared)
	var normalization: Dictionary = WaveGaitScript._normalize_sdk_authority_options(
		request
	)
	if not _normalization_exact(normalization):
		var failed_shutdown: Dictionary = adapter.shutdown()
		return _failure(
			"R23D64_GODOT_PUBLIC_ROUTE_NORMALIZATION_INVALID",
			{"normalization": normalization, "shutdown": failed_shutdown},
		)
	var surface := BaseRouteTest._fixture_surface(prepared)
	if not bool(surface.get("ok", false)):
		var failed_shutdown: Dictionary = adapter.shutdown()
		return _failure(
			"R23D64_GODOT_PUBLIC_ROUTE_SURFACE_INVALID",
			{"surface": surface, "shutdown": failed_shutdown},
		)
	var states: Dictionary = surface["joint_state_by_joint_id"]
	var route: Dictionary = WaveGaitScript.bind_sdk_live_fixture_actuator_cap_route(
		compiled_boundary,
		states,
		READBACK_TOLERANCE_NMS,
		PublicRouteScript.POLICY_ID,
		PublicRouteScript.PROFILE_ID,
		prepared["descriptor"],
	)
	if not _route_exact(route):
		BaseRouteTest._free_surface(surface)
		var failed_shutdown: Dictionary = adapter.shutdown()
		return _failure(
			"R23D64_GODOT_PUBLIC_ROUTE_BINDING_INVALID",
			{"route": route, "shutdown": failed_shutdown},
		)
	var override_by_actuator_id: Dictionary = route[
		"maximum_impulse_override_by_actuator_id"
	]
	var resolution: Dictionary = (
		AdapterScript.resolve_authorized_maximum_impulse_by_actuator_id(
			morphology,
			override_by_actuator_id,
		)
	)
	if not BaseRouteTest._resolution_exact(resolution, override_by_actuator_id):
		BaseRouteTest._free_surface(surface)
		var failed_shutdown: Dictionary = adapter.shutdown()
		return _failure(
			"R23D64_GODOT_PUBLIC_ROUTE_OVERRIDE_RESOLUTION_INVALID",
			{"resolution": resolution, "shutdown": failed_shutdown},
		)
	var step_result := BaseRouteTest._authority_step_result(morphology, 0)
	var authority: Dictionary = adapter.apply_authority(
		step_result,
		states,
		true,
		override_by_actuator_id,
	)
	if not BaseRouteTest._authority_receipt_exact(
		authority,
		override_by_actuator_id,
		0,
	):
		BaseRouteTest._free_surface(surface)
		var failed_shutdown: Dictionary = adapter.shutdown()
		return _failure(
			"R23D64_GODOT_PUBLIC_ROUTE_AUTHORITY_INVALID",
			{"authority": authority, "shutdown": failed_shutdown},
		)

	var normalization_rejections := _normalization_mutation_rejections(
		prepared
	)
	var route_rejections := _route_mutation_rejections(
		compiled_boundary,
		prepared,
	)
	var resolution_receipt: Dictionary = route[
		"actuator_cap_profile_resolution_receipt"
	]
	var host_mapping_receipt: Dictionary = route[
		"actuator_cap_profile_host_mapping_receipt"
	]
	var physical_binding_receipt: Dictionary = route[
		"actuator_cap_profile_physical_binding_receipt"
	]
	var shutdown: Dictionary = adapter.shutdown()
	BaseRouteTest._free_surface(surface)
	var exact := (
		normalization_rejections == EXPECTED_NORMALIZATION_MUTATION_REJECTION_COUNT
		and route_rejections == EXPECTED_ROUTE_MUTATION_REJECTION_COUNT
		and bool(shutdown.get("ok", false))
		and int(shutdown.get("world_build_count", -1)) == 0
	)
	return {
		"schema_version": (
			"sporespore_qsdk_r23d64_godot_public_profile_physical_route_zero_world_v1"
		),
		"ok": exact,
		"failure_code": (
			"" if exact else "R23D64_GODOT_PUBLIC_ROUTE_MUTATION_CONTROL_INVALID"
		),
		"question_class": "non_physical_native_worker_route_conformance",
		"policy_id": PublicRouteScript.POLICY_ID,
		"profile_id": PublicRouteScript.PROFILE_ID,
		"profile_sha256": PublicRouteScript.PROFILE_SHA256,
		"actuator_cap_profile_resolution_receipt": resolution_receipt.duplicate(true),
		"actuator_cap_profile_host_mapping_receipt": (
			host_mapping_receipt.duplicate(true)
		),
		"actuator_cap_profile_physical_binding_receipt": (
			physical_binding_receipt.duplicate(true)
		),
		"ordered_override_by_actuator_id": override_by_actuator_id.duplicate(true),
		"validated_actuator_count": 8,
		"write_count": int(route.get("write_count", -1)),
		"readback_count": int(route.get("readback_count", -1)),
		"authority_application_count": int(
			authority.get("applied_command_count", -1)
		),
		"normalization_mutation_rejection_count": normalization_rejections,
		"route_mutation_rejection_count": route_rejections,
		"host_object_creation_count": 48,
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_campaign_opened": false,
		"turning_claimed": false,
		"prone_to_standing_claimed": false,
		"cross_engine_equivalence_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _authority_request(prepared: Dictionary) -> Dictionary:
	var request: Dictionary = (prepared["authority_options"] as Dictionary).duplicate(true)
	request["task_frame_origin_policy_id"] = BaseRouteTest.ORIGIN_POLICY_ID
	request["live_fixture_actuator_cap_binding_policy_id"] = PublicRouteScript.POLICY_ID
	request["live_fixture_actuator_cap_binding_profile_id"] = PublicRouteScript.PROFILE_ID
	return request


static func _normalization_exact(normalization: Dictionary) -> bool:
	var options: Dictionary = normalization.get("sdk_authority_options", {})
	return (
		bool(normalization.get("ok", false))
		and String(options.get("live_fixture_actuator_cap_binding_policy_id", ""))
		== PublicRouteScript.POLICY_ID
		and String(options.get("live_fixture_actuator_cap_binding_profile_id", ""))
		== PublicRouteScript.PROFILE_ID
		and String(options.get("task_frame_origin_policy_id", ""))
		== BaseRouteTest.ORIGIN_POLICY_ID
		and String(options.get("authority_scope", "")) == "post_settle_full"
		and int(normalization.get("world_build_count", -1)) == 0
	)


static func _route_exact(route: Dictionary) -> bool:
	var resolution: Dictionary = route.get(
		"actuator_cap_profile_resolution_receipt",
		{},
	)
	var host_mapping: Dictionary = route.get(
		"actuator_cap_profile_host_mapping_receipt",
		{},
	)
	var physical_binding: Dictionary = route.get(
		"actuator_cap_profile_physical_binding_receipt",
		{},
	)
	var overrides: Dictionary = route.get(
		"maximum_impulse_override_by_actuator_id",
		{},
	)
	return (
		bool(route.get("ok", false))
		and String(route.get("policy_id", "")) == PublicRouteScript.POLICY_ID
		and String(route.get("profile_id", "")) == PublicRouteScript.PROFILE_ID
		and String(resolution.get("support_status", "")) == "supported_exact"
		and String(resolution.get("profile_sha256", ""))
		== PublicRouteScript.PROFILE_SHA256
		and String(host_mapping.get("schema_version", ""))
		== "sporespore_godot_actuator_cap_profile_binding_receipt_v1"
		and String(host_mapping.get("host_mapping_id", ""))
		== PublicRouteScript.HOST_MAPPING_ID
		and bool(host_mapping.get("all_postbinding_readbacks_match", false))
		and String(physical_binding.get("schema_version", ""))
		== PublicRouteScript.PHYSICAL_BINDING_SCHEMA_VERSION
		and bool(physical_binding.get("completed_before_first_solver_step", false))
		and int(physical_binding.get("solver_step_count_at_binding", -1)) == 0
		and bool(physical_binding.get("all_readbacks_match", false))
		and overrides.size() == 8
		and int(route.get("write_count", -1)) == 8
		and int(route.get("readback_count", -1)) == 8
		and int(route.get("world_build_count", -1)) == 0
		and not bool(route.get("physics_state_modified", true))
	)


static func _normalization_mutation_rejections(prepared: Dictionary) -> int:
	var rejected := 0
	var wrong_profile := _authority_request(prepared)
	wrong_profile["live_fixture_actuator_cap_binding_profile_id"] = "unknown_profile"
	rejected += int(
		not bool(
			WaveGaitScript._normalize_sdk_authority_options(wrong_profile).get(
				"ok",
				false,
			)
		)
	)
	var wrong_policy := _authority_request(prepared)
	wrong_policy["live_fixture_actuator_cap_binding_policy_id"] = "wrong_policy"
	rejected += int(
		not bool(
			WaveGaitScript._normalize_sdk_authority_options(wrong_policy).get(
				"ok",
				false,
			)
		)
	)
	return rejected


static func _route_mutation_rejections(
	compiled_boundary: Dictionary,
	prepared: Dictionary,
) -> int:
	var rejected := 0
	var cases := [
		{"id": "wrong_policy"},
		{"id": "wrong_profile"},
		{"id": "missing_descriptor"},
		{"id": "out_of_domain_descriptor"},
		{"id": "duplicate_host_object"},
	]
	for case_value in cases:
		var case: Dictionary = case_value
		var surface := BaseRouteTest._fixture_surface(prepared)
		if not bool(surface.get("ok", false)):
			BaseRouteTest._free_surface(surface)
			continue
		var before := BaseRouteTest._surface_caps(surface)
		var states: Dictionary = (
			(surface["joint_state_by_joint_id"] as Dictionary).duplicate(true)
		)
		var policy_id := PublicRouteScript.POLICY_ID
		var profile_id := PublicRouteScript.PROFILE_ID
		var descriptor: Dictionary = (prepared["descriptor"] as Dictionary).duplicate(true)
		match String(case["id"]):
			"wrong_policy":
				policy_id = "wrong_policy"
			"wrong_profile":
				profile_id = "unknown_profile"
			"missing_descriptor":
				descriptor = {}
			"out_of_domain_descriptor":
				descriptor["morphology_id"] = "valid_out_of_domain"
			"duplicate_host_object":
				var first: Dictionary = states["front_left.hip_pitch"]
				var second: Dictionary = states["front_left.knee_pitch"]
				second["joint"] = first["joint"]
				states["front_left.knee_pitch"] = second
		var route := WaveGaitScript.bind_sdk_live_fixture_actuator_cap_route(
			compiled_boundary,
			states,
			READBACK_TOLERANCE_NMS,
			policy_id,
			profile_id,
			descriptor,
		)
		rejected += int(
			not bool(route.get("ok", false))
			and BaseRouteTest._caps_unchanged(surface, before)
			and int(route.get("world_build_count", -1)) == 0
			and not bool(route.get("physics_state_modified", true))
		)
		BaseRouteTest._free_surface(surface)
	return rejected


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": (
			"sporespore_qsdk_r23d64_godot_public_profile_physical_route_zero_world_v1"
		),
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_campaign_opened": false,
		"turning_claimed": false,
		"prone_to_standing_claimed": false,
		"cross_engine_equivalence_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
