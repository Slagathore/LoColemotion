class_name LabDynamicSupportDiagnosticReceipt
extends RefCounted

## Canonical, report-only aggregation for read-only dynamic-support samples.
##
## Neither samples nor aggregate values grant controller, walker-predicate, or
## claim authority. Malformed traces fail the harness closed; measured margins
## do not themselves pass or fail the walker.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FiniteSanitizerScript := preload("res://scripts/lab/finite_sanitizer.gd")

const SCHEMA_VERSION := "sporespore_dynamic_support_diagnostic_receipt_v1"
const POLICY_ID := "g4_gq13_read_only_dynamic_support_trace_v1"
const SAMPLE_SCHEMA_VERSION := "sporespore_dynamic_support_trace_sample_v1"
const GQ14_SCHEMA_VERSION := "sporespore_dynamic_support_diagnostic_receipt_v2"
const GQ14_POLICY_ID := "g4_gq14_read_only_support_set_trace_v1"
const GQ14_SAMPLE_SCHEMA_VERSION := "sporespore_dynamic_support_trace_sample_v2"
const GQ15_SCHEMA_VERSION := "sporespore_dynamic_support_diagnostic_receipt_v3"
const GQ15_POLICY_ID := "g4_gq15_read_only_dynamic_support_sets_v3"
const GQ15_SAMPLE_SCHEMA_VERSION := "sporespore_dynamic_support_sample_v3"
const POLICY_RESPONSE := "REPORT_ONLY_NO_CONTROLLER_OR_ACCEPTANCE_AUTHORITY"
const SUPPORT_FRAME_ID := "world_xz_fixed_floor_plane_v1"
const ORDERED_CONTACT_IDS := [
	"front_left",
	"front_right",
	"rear_left",
	"rear_right",
]
# Semantic receipt ordering and polygon perimeter ordering are different
# contracts. The semantic order above is stable for canonical JSON. This order
# walks the quadruped footprint perimeter so the four-contact support polygon
# cannot become the front/rear bow-tie that invalidated GQ13 diagnostics.
const ORDERED_SUPPORT_POLYGON_CONTACT_IDS := [
	"front_left",
	"front_right",
	"rear_right",
	"rear_left",
]


static func compile_sample(
	tick: int,
	phase_id: String,
	active_semantic_contact_ids: Array,
	observer_result: Dictionary,
	lateral_displacement_from_trace_origin_m: float,
) -> Dictionary:
	return _compile_sample(
		tick,
		phase_id,
		active_semantic_contact_ids,
		observer_result,
		lateral_displacement_from_trace_origin_m,
		SAMPLE_SCHEMA_VERSION,
	)


static func compile_sample_gq14(
	tick: int,
	phase_id: String,
	active_semantic_contact_ids: Array,
	observer_result: Dictionary,
	lateral_displacement_from_trace_origin_m: float,
) -> Dictionary:
	return _compile_sample(
		tick,
		phase_id,
		active_semantic_contact_ids,
		observer_result,
		lateral_displacement_from_trace_origin_m,
		GQ14_SAMPLE_SCHEMA_VERSION,
	)


static func compile_sample_gq15(
	tick: int,
	phase_id: String,
	active_semantic_contact_ids: Array,
	observer_result: Dictionary,
	lateral_displacement_from_trace_origin_m: float,
) -> Dictionary:
	return _compile_sample(
		tick,
		phase_id,
		active_semantic_contact_ids,
		observer_result,
		lateral_displacement_from_trace_origin_m,
		GQ15_SAMPLE_SCHEMA_VERSION,
	)


static func _compile_sample(
	tick: int,
	phase_id: String,
	active_semantic_contact_ids: Array,
	observer_result: Dictionary,
	lateral_displacement_from_trace_origin_m: float,
	sample_schema_version: String,
) -> Dictionary:
	if tick < 0:
		return _failure("DYNAMIC_SUPPORT_SAMPLE_TICK_INVALID")
	if phase_id not in ["SETTLE_BOUNDARY", "WARMUP", "EVIDENCE", "COOLDOWN", "TERMINAL_SETTLE"]:
		return _failure("DYNAMIC_SUPPORT_SAMPLE_PHASE_INVALID")
	if not bool(observer_result.get("ok", false)):
		return _failure(
			"DYNAMIC_SUPPORT_OBSERVER_FAILURE:%s"
			% String(observer_result.get("failure_code", "UNKNOWN"))
		)
	if not _contact_ids_ordered(active_semantic_contact_ids):
		return _failure("DYNAMIC_SUPPORT_SAMPLE_CONTACT_ORDER_INVALID")
	if (
		bool(observer_result.get("contact_presence_is_bearing_measurement", true))
		or bool(observer_result.get("articulated_capture_guarantee_available", true))
		or bool(observer_result.get("physics_state_modified", true))
	):
		return _failure("DYNAMIC_SUPPORT_OBSERVER_AUTHORITY_INVALID")
	var support_dimension := int(
		observer_result.get("support_geometry_dimension", 2)
	)
	var support_kind := String(
		observer_result.get("support_geometry_kind", "POLYGON")
	)
	var support_polygon_available := bool(
		observer_result.get("support_polygon_available", true)
	)
	if sample_schema_version in [GQ14_SAMPLE_SCHEMA_VERSION, GQ15_SAMPLE_SCHEMA_VERSION]:
		var expected_dimension := mini(active_semantic_contact_ids.size() - 1, 2)
		if (
			support_dimension != expected_dimension
			or support_kind != ["POINT", "SEGMENT", "POLYGON"][expected_dimension]
			or support_polygon_available != (expected_dimension == 2)
		):
			return _failure("DYNAMIC_SUPPORT_SAMPLE_SUPPORT_SET_IDENTITY_INVALID")
	var sample := {
		"schema_version": sample_schema_version,
		"support_frame_id": SUPPORT_FRAME_ID,
		"tick_dimensionless": tick,
		"phase_id": phase_id,
		"active_semantic_contact_ids": active_semantic_contact_ids.duplicate(),
		"contact_presence_is_bearing_measurement": false,
		"whole_system_mass_kg": float(observer_result["whole_system_mass_kg"]),
		"center_of_mass_world_m": observer_result["center_of_mass_world_m"],
		"center_of_mass_velocity_world_m_s":
		observer_result["center_of_mass_velocity_world_m_s"],
		"support_plane_height_m": float(observer_result["support_plane_height_m"]),
		"center_of_mass_height_above_support_m":
		float(observer_result["center_of_mass_height_above_support_m"]),
		"linearized_natural_frequency_rad_s":
		float(observer_result["linearized_natural_frequency_rad_s"]),
		"linearized_capture_point_world_m":
		observer_result["linearized_capture_point_world_m"],
		"support_centroid_world_m": observer_result["support_centroid_world_m"],
		"support_vertices_world_xz_m":
		(observer_result["support_vertices_world_xz_m"] as Array).duplicate(true),
		"support_geometry_dimension": support_dimension,
		"support_geometry_kind": support_kind,
		"support_polygon_available": support_polygon_available,
		"center_of_mass_margin_m": float(observer_result["center_of_mass_margin_m"]),
		"linearized_capture_margin_m":
		float(observer_result["linearized_capture_margin_m"]),
		"minimum_dynamic_support_margin_m":
		float(observer_result["minimum_dynamic_support_margin_m"]),
		"lateral_displacement_from_trace_origin_m":
		lateral_displacement_from_trace_origin_m,
		"articulated_capture_guarantee_available": false,
		"per_foot_measured_load_allocation_available": false,
		"linearized_capture_model_only": true,
		"physics_state_modified": false,
	}
	var finite_report := FiniteSanitizerScript.inspect(sample)
	if not bool(finite_report.get("ok", false)):
		return _failure("DYNAMIC_SUPPORT_SAMPLE_NONFINITE")
	return {
		"ok": true,
		"failure_code": "",
		"sample": sample,
		"sample_sha256": CanonicalJsonScript.sha256(sample),
		"world_build_count": 0,
	}


static func compile(trace_samples: Array, metadata: Dictionary) -> Dictionary:
	return _compile_profile(
		trace_samples,
		metadata,
		SCHEMA_VERSION,
		POLICY_ID,
		SAMPLE_SCHEMA_VERSION,
	)


static func compile_gq14(trace_samples: Array, metadata: Dictionary) -> Dictionary:
	return _compile_profile(
		trace_samples,
		metadata,
		GQ14_SCHEMA_VERSION,
		GQ14_POLICY_ID,
		GQ14_SAMPLE_SCHEMA_VERSION,
	)


static func compile_gq15(trace_samples: Array, metadata: Dictionary) -> Dictionary:
	return _compile_profile(
		trace_samples,
		metadata,
		GQ15_SCHEMA_VERSION,
		GQ15_POLICY_ID,
		GQ15_SAMPLE_SCHEMA_VERSION,
	)


static func _compile_profile(
	trace_samples: Array,
	metadata: Dictionary,
	receipt_schema_version: String,
	policy_id: String,
	sample_schema_version: String,
) -> Dictionary:
	if trace_samples.is_empty():
		return _failure("DYNAMIC_SUPPORT_TRACE_EMPTY")
	var required_metadata_keys := [
		"contact_progression_timeout",
		"evidence_extension_ticks",
		"maximum_anchor_error_tick",
		"final_support_contact_state",
		"lateral_limit_m",
		"source_digests",
	]
	if not _has_exact_keys(metadata, required_metadata_keys):
		return _failure("DYNAMIC_SUPPORT_METADATA_KEYS_INVALID")
	if typeof(metadata["contact_progression_timeout"]) != TYPE_BOOL:
		return _failure("DYNAMIC_SUPPORT_TIMEOUT_TYPE_INVALID")
	if (
		typeof(metadata["evidence_extension_ticks"]) != TYPE_INT
		or int(metadata["evidence_extension_ticks"]) < 0
		or typeof(metadata["maximum_anchor_error_tick"]) != TYPE_INT
	):
		return _failure("DYNAMIC_SUPPORT_METADATA_INTEGER_INVALID")
	var lateral_limit_m := float(metadata["lateral_limit_m"])
	if not is_finite(lateral_limit_m) or lateral_limit_m <= 0.0:
		return _failure("DYNAMIC_SUPPORT_LATERAL_LIMIT_INVALID")
	var source_digests: Dictionary = metadata["source_digests"]
	if source_digests.is_empty():
		return _failure("DYNAMIC_SUPPORT_SOURCE_DIGESTS_EMPTY")
	for digest_value in source_digests.values():
		if typeof(digest_value) != TYPE_STRING or not _digest_valid(String(digest_value)):
			return _failure("DYNAMIC_SUPPORT_SOURCE_DIGEST_INVALID")

	var normalized_trace: Array = []
	var previous_tick := -1
	var minimum_com_margin_m := INF
	var minimum_capture_margin_m := INF
	var minimum_dynamic_margin_m := INF
	var first_minimum_com_margin_tick := -1
	var first_minimum_capture_margin_tick := -1
	var first_minimum_dynamic_margin_tick := -1
	var first_nonpositive_com_margin_tick := -1
	var first_nonpositive_capture_margin_tick := -1
	var first_nonpositive_dynamic_margin_tick := -1
	var first_half_lateral_limit_tick := -1
	var first_full_lateral_limit_tick := -1
	var support_geometry_sample_count_by_dimension := {"0": 0, "1": 0, "2": 0}
	for sample_value in trace_samples:
		if not sample_value is Dictionary:
			return _failure("DYNAMIC_SUPPORT_SAMPLE_TYPE_INVALID")
		var sample: Dictionary = sample_value
		if String(sample.get("schema_version", "")) != sample_schema_version:
			return _failure("DYNAMIC_SUPPORT_SAMPLE_SCHEMA_INVALID")
		if String(sample.get("support_frame_id", "")) != SUPPORT_FRAME_ID:
			return _failure("DYNAMIC_SUPPORT_SAMPLE_FRAME_INVALID")
		var tick := int(sample.get("tick_dimensionless", -1))
		if tick <= previous_tick:
			return _failure("DYNAMIC_SUPPORT_TRACE_TICK_ORDER_INVALID")
		previous_tick = tick
		var active_ids: Array = sample.get("active_semantic_contact_ids", [])
		if not _contact_ids_ordered(active_ids):
			return _failure("DYNAMIC_SUPPORT_SAMPLE_CONTACT_ORDER_INVALID")
		if (
			bool(sample.get("contact_presence_is_bearing_measurement", true))
			or bool(sample.get("articulated_capture_guarantee_available", true))
			or bool(sample.get("physics_state_modified", true))
		):
			return _failure("DYNAMIC_SUPPORT_SAMPLE_AUTHORITY_INVALID")
		var support_dimension := int(sample.get("support_geometry_dimension", -1))
		var support_kind := String(sample.get("support_geometry_kind", ""))
		if (
			support_dimension not in [0, 1, 2]
			or support_kind != ["POINT", "SEGMENT", "POLYGON"][support_dimension]
			or bool(sample.get("support_polygon_available", support_dimension != 2))
			!= (support_dimension == 2)
		):
			return _failure("DYNAMIC_SUPPORT_SAMPLE_GEOMETRY_INVALID")
		var support_dimension_key := str(support_dimension)
		support_geometry_sample_count_by_dimension[support_dimension_key] = (
			int(support_geometry_sample_count_by_dimension[support_dimension_key]) + 1
		)
		var finite_report := FiniteSanitizerScript.inspect(sample)
		if not bool(finite_report.get("ok", false)):
			return _failure("DYNAMIC_SUPPORT_SAMPLE_NONFINITE")
		var com_margin_m := float(sample.get("center_of_mass_margin_m", NAN))
		var capture_margin_m := float(sample.get("linearized_capture_margin_m", NAN))
		var dynamic_margin_m := float(sample.get("minimum_dynamic_support_margin_m", NAN))
		var lateral_displacement_m := absf(
			float(sample.get("lateral_displacement_from_trace_origin_m", NAN))
		)
		if com_margin_m < minimum_com_margin_m:
			minimum_com_margin_m = com_margin_m
			first_minimum_com_margin_tick = tick
		if capture_margin_m < minimum_capture_margin_m:
			minimum_capture_margin_m = capture_margin_m
			first_minimum_capture_margin_tick = tick
		if dynamic_margin_m < minimum_dynamic_margin_m:
			minimum_dynamic_margin_m = dynamic_margin_m
			first_minimum_dynamic_margin_tick = tick
		if first_nonpositive_com_margin_tick < 0 and com_margin_m <= 0.0:
			first_nonpositive_com_margin_tick = tick
		if first_nonpositive_capture_margin_tick < 0 and capture_margin_m <= 0.0:
			first_nonpositive_capture_margin_tick = tick
		if first_nonpositive_dynamic_margin_tick < 0 and dynamic_margin_m <= 0.0:
			first_nonpositive_dynamic_margin_tick = tick
		if (
			first_half_lateral_limit_tick < 0
			and lateral_displacement_m >= 0.5 * lateral_limit_m
		):
			first_half_lateral_limit_tick = tick
		if first_full_lateral_limit_tick < 0 and lateral_displacement_m >= lateral_limit_m:
			first_full_lateral_limit_tick = tick
		normalized_trace.append(sample.duplicate(true))

	var observer_policy_digest := CanonicalJsonScript.sha256(
		{
			"policy_id": policy_id,
			"support_frame_id": SUPPORT_FRAME_ID,
			"ordered_contact_ids": ORDERED_CONTACT_IDS,
			"contact_presence_is_bearing_measurement": false,
			"articulated_capture_guarantee_available": false,
		}
	)
	var observer_schema_digest := CanonicalJsonScript.sha256(
		{
			"receipt_schema_version": receipt_schema_version,
			"sample_schema_version": sample_schema_version,
		}
	)
	var receipt := {
		"schema_version": receipt_schema_version,
		"policy_id": policy_id,
		"support_frame_id": SUPPORT_FRAME_ID,
		"sample_count_dimensionless": normalized_trace.size(),
		"support_geometry_sample_count_by_dimension":
		support_geometry_sample_count_by_dimension.duplicate(true),
		"ordered_trace_sha256": CanonicalJsonScript.sha256(normalized_trace),
		"minimum_center_of_mass_margin_m": minimum_com_margin_m,
		"first_minimum_center_of_mass_margin_tick_dimensionless":
		first_minimum_com_margin_tick,
		"minimum_linearized_capture_margin_m": minimum_capture_margin_m,
		"first_minimum_linearized_capture_margin_tick_dimensionless":
		first_minimum_capture_margin_tick,
		"minimum_dynamic_support_margin_m": minimum_dynamic_margin_m,
		"first_minimum_dynamic_support_margin_tick_dimensionless":
		first_minimum_dynamic_margin_tick,
		"first_nonpositive_center_of_mass_margin_tick_dimensionless":
		first_nonpositive_com_margin_tick,
		"first_nonpositive_linearized_capture_margin_tick_dimensionless":
		first_nonpositive_capture_margin_tick,
		"first_nonpositive_dynamic_support_margin_tick_dimensionless":
		first_nonpositive_dynamic_margin_tick,
		"first_half_lateral_limit_tick_dimensionless": first_half_lateral_limit_tick,
		"first_full_lateral_limit_tick_dimensionless": first_full_lateral_limit_tick,
		"lateral_limit_m": lateral_limit_m,
		"contact_progression_timeout": bool(metadata["contact_progression_timeout"]),
		"evidence_extension_ticks_dimensionless":
		int(metadata["evidence_extension_ticks"]),
		"maximum_anchor_error_tick_dimensionless":
		int(metadata["maximum_anchor_error_tick"]),
		"final_support_contact_state":
		(metadata["final_support_contact_state"] as Dictionary).duplicate(true),
		"observer_policy_sha256": observer_policy_digest,
		"observer_schema_sha256": observer_schema_digest,
		"source_digests": source_digests.duplicate(true),
		"contact_presence_is_bearing_measurement": false,
		"articulated_capture_guarantee_available": false,
		"policy_response": POLICY_RESPONSE,
		"controller_authority": false,
		"walker_predicate_authority": false,
		"physical_acceptance_authority": false,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
		"automatic_creature_guidance_allowed": false,
	}
	var finite_report := FiniteSanitizerScript.inspect(receipt)
	if not bool(finite_report.get("ok", false)):
		return _failure("DYNAMIC_SUPPORT_RECEIPT_NONFINITE")
	return {
		"ok": true,
		"failure_code": "",
		"dynamic_support_receipt": receipt,
		"dynamic_support_receipt_sha256": CanonicalJsonScript.sha256(receipt),
		"ordered_trace": normalized_trace,
		"world_build_count": 0,
	}


static func verify(
	trace_samples: Array,
	metadata: Dictionary,
	expected_dynamic_support_receipt_sha256: String,
) -> Dictionary:
	var result := compile(trace_samples, metadata)
	if not bool(result.get("ok", false)):
		return result
	if (
		not _digest_valid(expected_dynamic_support_receipt_sha256)
		or (
			String(result["dynamic_support_receipt_sha256"])
			!= expected_dynamic_support_receipt_sha256
		)
	):
		return _failure("DYNAMIC_SUPPORT_RECEIPT_DIGEST_MISMATCH")
	return result


static func verify_gq14(
	trace_samples: Array,
	metadata: Dictionary,
	expected_dynamic_support_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq14(trace_samples, metadata)
	if not bool(result.get("ok", false)):
		return result
	if (
		not _digest_valid(expected_dynamic_support_receipt_sha256)
		or (
			String(result["dynamic_support_receipt_sha256"])
			!= expected_dynamic_support_receipt_sha256
		)
	):
		return _failure("DYNAMIC_SUPPORT_RECEIPT_DIGEST_MISMATCH")
	return result


static func verify_gq15(
	trace_samples: Array,
	metadata: Dictionary,
	expected_dynamic_support_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq15(trace_samples, metadata)
	if not bool(result.get("ok", false)):
		return result
	if (
		not _digest_valid(expected_dynamic_support_receipt_sha256)
		or (
			String(result["dynamic_support_receipt_sha256"])
			!= expected_dynamic_support_receipt_sha256
		)
	):
		return _failure("DYNAMIC_SUPPORT_RECEIPT_DIGEST_MISMATCH")
	return result


static func _contact_ids_ordered(ids: Array) -> bool:
	var previous_index := -1
	for id_value in ids:
		if typeof(id_value) != TYPE_STRING:
			return false
		var index := ORDERED_CONTACT_IDS.find(String(id_value))
		if index <= previous_index:
			return false
		previous_index = index
	return not ids.is_empty()


static func _has_exact_keys(source: Dictionary, keys: Array) -> bool:
	if source.size() != keys.size():
		return false
	for key in keys:
		if not source.has(key):
			return false
	return true


static func _digest_valid(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"world_build_count": 0,
	}
