class_name LabMorphologyCoverageReceipt
extends RefCounted

## Pure, report-only morphology coverage diagnostic.
##
## The fixed GQ11 Candidate 33 development cohort defines a standardized
## six-dimensional coordinate space. Its distances never enter controller
## selection or physical acceptance.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FiniteSanitizerScript := preload("res://scripts/lab/finite_sanitizer.gd")
const FeatureReceiptScript := preload(
	"res://scripts/lab/gait/morphology_feature_receipt.gd"
)

const SCHEMA_VERSION := "sporespore_morphology_coverage_receipt_v1"
const POLICY_ID := "g4_gq13_gq11_candidate33_cohort_euclidean_v1"
const CLAIM_LEVEL := "development_only_candidate33_flat_floor_godot_jolt_20_7_r1_r3"
const CANDIDATE33_SOURCE_SHA256 := (
	"sha256:b7f62cd6a6fb0c5bd2c5695ad78e9c47449ed2f0aefd36f7f19cf57088701d34"
)
const GQ14_SCHEMA_VERSION := "sporespore_morphology_coverage_receipt_v2"
const GQ14_POLICY_ID := "g4_gq14_opened_candidate34_cohort_euclidean_v1"
const GQ14_CLAIM_LEVEL := (
	"development_only_candidate34_flat_floor_godot_jolt_20_7_gq11_r1_r3_gq13_selection"
)
const CANDIDATE34_SOURCE_SHA256 := (
	"sha256:d82ac838137ff8d8c735ca614797f335a43f8ea698552730450b31b3565d4e27"
)
const GQ15_SCHEMA_VERSION := "sporespore_morphology_coverage_receipt_v3"
const GQ15_POLICY_ID := "g4_gq15_opened_candidate35_population_distance_v3"
const GQ15_CLAIM_LEVEL := "finite_opened_development_population_distance_report_only"
const CANDIDATE35_SOURCE_SHA256 := (
	"sha256:a7fd448046cdc6608ca524c1ff88b2d671fef3258ee8a6723d1c8efda7528294"
)
const PROFILE_GQ13 := 13
const PROFILE_GQ14 := 14
const PROFILE_GQ15 := 15
const POLICY_RESPONSE := "REPORT_ONLY_NO_CONTROLLER_OR_ACCEPTANCE_AUTHORITY"
const COHORT_IDS := [
	"gq11_generated_s109",
	"gq11_generated_s110",
	"gq11_generated_s111",
	"gq11_generated_s112",
	"gq11_generated_s113",
	"gq11_generated_s114",
	"gq11_generated_s115",
	"gq11_generated_s116",
	"gq11_generated_s117",
	"gq11_generated_s118",
	"gq11_generated_s119",
	"gq11_generated_s120",
	"gq11_generated_s1001",
	"gq11_generated_s1002",
	"gq11_generated_s1003",
	"gq11_generated_s1004",
	"gq11_generated_s1005",
	"gq11_generated_s1006",
	"gq11_generated_s1007",
	"gq11_generated_s1008",
]
const GQ14_COHORT_IDS := [
	"gq11_generated_s109",
	"gq11_generated_s110",
	"gq11_generated_s111",
	"gq11_generated_s112",
	"gq11_generated_s113",
	"gq11_generated_s114",
	"gq11_generated_s115",
	"gq11_generated_s116",
	"gq11_generated_s117",
	"gq11_generated_s118",
	"gq11_generated_s119",
	"gq11_generated_s120",
	"gq11_generated_s1001",
	"gq11_generated_s1002",
	"gq11_generated_s1003",
	"gq11_generated_s1004",
	"gq11_generated_s1005",
	"gq11_generated_s1006",
	"gq11_generated_s1007",
	"gq11_generated_s1008",
	"gq13_generated_s133",
	"gq13_generated_s134",
	"gq13_generated_s135",
	"gq13_generated_s136",
	"gq13_generated_s137",
	"gq13_generated_s138",
	"gq13_generated_s139",
	"gq13_generated_s140",
	"gq13_generated_s141",
	"gq13_generated_s142",
	"gq13_generated_s143",
	"gq13_generated_s144",
]
const GQ15_COHORT_IDS := [
	"gq11_generated_s109",
	"gq11_generated_s110",
	"gq11_generated_s111",
	"gq11_generated_s112",
	"gq11_generated_s113",
	"gq11_generated_s114",
	"gq11_generated_s115",
	"gq11_generated_s116",
	"gq11_generated_s117",
	"gq11_generated_s118",
	"gq11_generated_s119",
	"gq11_generated_s120",
	"gq11_generated_s1001",
	"gq11_generated_s1002",
	"gq11_generated_s1003",
	"gq11_generated_s1004",
	"gq11_generated_s1005",
	"gq11_generated_s1006",
	"gq11_generated_s1007",
	"gq11_generated_s1008",
	"gq12_generated_s121",
	"gq12_generated_s122",
	"gq12_generated_s123",
	"gq12_generated_s124",
	"gq12_generated_s125",
	"gq12_generated_s126",
	"gq12_generated_s127",
	"gq12_generated_s128",
	"gq12_generated_s129",
	"gq12_generated_s130",
	"gq12_generated_s131",
	"gq12_generated_s132",
	"gq13_generated_s133",
	"gq13_generated_s134",
	"gq13_generated_s135",
	"gq13_generated_s136",
	"gq13_generated_s137",
	"gq13_generated_s138",
	"gq13_generated_s139",
	"gq13_generated_s140",
	"gq13_generated_s141",
	"gq13_generated_s142",
	"gq13_generated_s143",
	"gq13_generated_s144",
	"gq14_generated_s145",
	"gq14_generated_s146",
	"gq14_generated_s147",
	"gq14_generated_s148",
	"gq14_generated_s149",
	"gq14_generated_s150",
	"gq14_generated_s151",
	"gq14_generated_s152",
	"gq14_generated_s153",
	"gq14_generated_s154",
	"gq14_generated_s155",
	"gq14_generated_s156",
]


static func compile(cohort_feature_results: Array, query_feature_result: Dictionary) -> Dictionary:
	return _compile_profile(cohort_feature_results, query_feature_result, PROFILE_GQ13)


static func compile_gq14(
	cohort_feature_results: Array,
	query_feature_result: Dictionary,
) -> Dictionary:
	return _compile_profile(cohort_feature_results, query_feature_result, PROFILE_GQ14)


static func compile_gq15(
	cohort_feature_results: Array,
	query_feature_result: Dictionary,
) -> Dictionary:
	return _compile_profile(cohort_feature_results, query_feature_result, PROFILE_GQ15)


static func _compile_profile(
	cohort_feature_results: Array,
	query_feature_result: Dictionary,
	profile_generation: int,
) -> Dictionary:
	if profile_generation not in [PROFILE_GQ13, PROFILE_GQ14, PROFILE_GQ15]:
		return _failure("MORPHOLOGY_COVERAGE_PROFILE_INVALID")
	var cohort_ids: Array = (
		GQ15_COHORT_IDS
		if profile_generation == PROFILE_GQ15
		else (GQ14_COHORT_IDS if profile_generation == PROFILE_GQ14 else COHORT_IDS)
	)
	var schema_version := (
		GQ15_SCHEMA_VERSION
		if profile_generation == PROFILE_GQ15
		else (GQ14_SCHEMA_VERSION if profile_generation == PROFILE_GQ14 else SCHEMA_VERSION)
	)
	var policy_id := (
		GQ15_POLICY_ID
		if profile_generation == PROFILE_GQ15
		else (GQ14_POLICY_ID if profile_generation == PROFILE_GQ14 else POLICY_ID)
	)
	var claim_level := (
		GQ15_CLAIM_LEVEL
		if profile_generation == PROFILE_GQ15
		else (GQ14_CLAIM_LEVEL if profile_generation == PROFILE_GQ14 else CLAIM_LEVEL)
	)
	var candidate_source_sha256 := (
		CANDIDATE35_SOURCE_SHA256
		if profile_generation == PROFILE_GQ15
		else (
			CANDIDATE34_SOURCE_SHA256
			if profile_generation == PROFILE_GQ14
			else CANDIDATE33_SOURCE_SHA256
		)
	)
	var query_campaign_id := "G4-GQ%d" % profile_generation
	var query_feature_policy_id := (
		FeatureReceiptScript.GQ15_POLICY_ID
		if profile_generation == PROFILE_GQ15
		else (
			FeatureReceiptScript.GQ14_POLICY_ID
			if profile_generation == PROFILE_GQ14
			else FeatureReceiptScript.POLICY_ID
		)
	)
	if cohort_feature_results.size() != cohort_ids.size():
		return _failure("MORPHOLOGY_COVERAGE_COHORT_SIZE_INVALID")
	var cohort_vectors: Array = []
	var cohort_feature_digests: Array = []
	var realized_ids: Array = []
	for result_value in cohort_feature_results:
		var result: Dictionary = result_value
		if (
			not bool(result.get("ok", false))
			or int(result.get("world_build_count", -1)) != 0
		):
			return _failure("MORPHOLOGY_COVERAGE_COHORT_FEATURE_INVALID")
		var receipt: Dictionary = result.get("feature_receipt", {})
		var cohort_morphology_id := String(receipt.get("morphology_id", ""))
		var expected_cohort_campaign_id := (
			"G4-GQ14"
			if cohort_morphology_id.begins_with("gq14_")
			else (
				"G4-GQ13"
				if cohort_morphology_id.begins_with("gq13_")
				else (
					"G4-GQ12"
					if cohort_morphology_id.begins_with("gq12_")
					else "G4-GQ11"
				)
			)
		)
		var expected_cohort_policy_id := (
			FeatureReceiptScript.GQ14_POLICY_ID
			if cohort_morphology_id.begins_with("gq14_")
			else FeatureReceiptScript.POLICY_ID
		)
		if (
			String(receipt.get("schema_version", "")) != FeatureReceiptScript.SCHEMA_VERSION
			or String(receipt.get("policy_id", "")) != expected_cohort_policy_id
			or String(receipt.get("campaign_id", "")) != expected_cohort_campaign_id
		):
			return _failure("MORPHOLOGY_COVERAGE_COHORT_FEATURE_IDENTITY_INVALID")
		var feature_digest := String(result.get("feature_receipt_sha256", ""))
		if feature_digest != CanonicalJsonScript.sha256(receipt):
			return _failure("MORPHOLOGY_COVERAGE_COHORT_FEATURE_DIGEST_MISMATCH")
		realized_ids.append(cohort_morphology_id)
		cohort_vectors.append(
			(receipt.get("ordered_signed_centered_coordinates_dimensionless", []) as Array)
			. duplicate()
		)
		cohort_feature_digests.append(feature_digest)
	if realized_ids != cohort_ids:
		return _failure("MORPHOLOGY_COVERAGE_COHORT_ORDER_INVALID")
	if (
		not bool(query_feature_result.get("ok", false))
		or int(query_feature_result.get("world_build_count", -1)) != 0
	):
		return _failure("MORPHOLOGY_COVERAGE_QUERY_FEATURE_INVALID")
	var query_receipt: Dictionary = query_feature_result.get("feature_receipt", {})
	if (
		String(query_receipt.get("schema_version", "")) != FeatureReceiptScript.SCHEMA_VERSION
		or String(query_receipt.get("policy_id", "")) != query_feature_policy_id
		or String(query_receipt.get("campaign_id", "")) != query_campaign_id
	):
		return _failure("MORPHOLOGY_COVERAGE_QUERY_FEATURE_IDENTITY_INVALID")
	var query_feature_digest := String(query_feature_result.get("feature_receipt_sha256", ""))
	if query_feature_digest != CanonicalJsonScript.sha256(query_receipt):
		return _failure("MORPHOLOGY_COVERAGE_QUERY_FEATURE_DIGEST_MISMATCH")
	var query_vector: Array = (
		query_receipt.get("ordered_signed_centered_coordinates_dimensionless", []) as Array
	).duplicate()
	if not _vectors_valid(cohort_vectors, query_vector):
		return _failure("MORPHOLOGY_COVERAGE_COORDINATES_INVALID")

	var means: Array = []
	var standard_deviations: Array = []
	var raw_minima: Array = []
	var raw_maxima: Array = []
	for axis_index in range(FeatureReceiptScript.AXIS_ORDER.size()):
		var mean := 0.0
		var raw_minimum := INF
		var raw_maximum := -INF
		for vector_value in cohort_vectors:
			var vector: Array = vector_value
			var value := float(vector[axis_index])
			mean += value
			raw_minimum = minf(raw_minimum, value)
			raw_maximum = maxf(raw_maximum, value)
		mean /= float(cohort_vectors.size())
		var variance := 0.0
		for vector_value in cohort_vectors:
			var vector: Array = vector_value
			var centered := float(vector[axis_index]) - mean
			variance += centered * centered
		variance /= float(cohort_vectors.size())
		var standard_deviation := sqrt(variance)
		if not is_finite(standard_deviation) or standard_deviation <= 0.0:
			return _failure("MORPHOLOGY_COVERAGE_STANDARD_DEVIATION_INVALID")
		means.append(mean)
		standard_deviations.append(standard_deviation)
		raw_minima.append(raw_minimum)
		raw_maxima.append(raw_maximum)

	var standardized_cohort: Array = []
	for vector_value in cohort_vectors:
		standardized_cohort.append(
			_standardize(vector_value, means, standard_deviations)
		)
	var standardized_query := _standardize(query_vector, means, standard_deviations)
	var supported_threshold := 0.0
	var leave_one_out_nearest_distances: Array = []
	for left_index in range(standardized_cohort.size()):
		var nearest := INF
		for right_index in range(standardized_cohort.size()):
			if left_index == right_index:
				continue
			nearest = minf(
				nearest,
				_euclidean_distance(
					standardized_cohort[left_index],
					standardized_cohort[right_index],
				),
			)
		if not is_finite(nearest):
			return _failure("MORPHOLOGY_COVERAGE_LEAVE_ONE_OUT_INVALID")
		leave_one_out_nearest_distances.append(nearest)
		supported_threshold = maxf(supported_threshold, nearest)
	if supported_threshold <= 0.0:
		return _failure("MORPHOLOGY_COVERAGE_SUPPORTED_THRESHOLD_INVALID")
	var edge_threshold := 2.0 * supported_threshold
	var nearest_query_distance := INF
	var nearest_cohort_id := ""
	for cohort_index in range(standardized_cohort.size()):
		var distance := _euclidean_distance(
			standardized_query,
			standardized_cohort[cohort_index],
		)
		if distance < nearest_query_distance:
			nearest_query_distance = distance
			nearest_cohort_id = String(cohort_ids[cohort_index])
	if not is_finite(nearest_query_distance):
		return _failure("MORPHOLOGY_COVERAGE_QUERY_DISTANCE_INVALID")
	var status := classify_distance(
		nearest_query_distance,
		supported_threshold,
		edge_threshold,
	)
	if status.is_empty():
		return _failure("MORPHOLOGY_COVERAGE_STATUS_INPUT_INVALID")

	var per_axis_excursion: Array = []
	var maximum_standardized_excursion := 0.0
	for axis_index in range(FeatureReceiptScript.AXIS_ORDER.size()):
		var query_value := float(query_vector[axis_index])
		var raw_excursion := 0.0
		var direction := "INSIDE"
		if query_value < float(raw_minima[axis_index]):
			raw_excursion = float(raw_minima[axis_index]) - query_value
			direction = "BELOW"
		elif query_value > float(raw_maxima[axis_index]):
			raw_excursion = query_value - float(raw_maxima[axis_index])
			direction = "ABOVE"
		var standardized_excursion := raw_excursion / float(standard_deviations[axis_index])
		maximum_standardized_excursion = maxf(
			maximum_standardized_excursion,
			standardized_excursion,
		)
		per_axis_excursion.append(
			{
				"axis_id": String(FeatureReceiptScript.AXIS_ORDER[axis_index]),
				"cohort_minimum_dimensionless": float(raw_minima[axis_index]),
				"cohort_maximum_dimensionless": float(raw_maxima[axis_index]),
				"query_dimensionless": query_value,
				"excursion_direction": direction,
				"excursion_dimensionless": raw_excursion,
				"standardized_excursion_dimensionless": standardized_excursion,
			}
		)

	var cohort_record := {
		"claim_level": claim_level,
		"feature_order": FeatureReceiptScript.AXIS_ORDER.duplicate(),
		"ordered_member_ids": cohort_ids.duplicate(),
		"ordered_member_raw_coordinates_dimensionless": cohort_vectors,
		"ordered_member_feature_receipt_sha256": cohort_feature_digests,
	}
	if profile_generation == PROFILE_GQ15:
		cohort_record["candidate35_source_sha256"] = candidate_source_sha256
	elif profile_generation == PROFILE_GQ14:
		cohort_record["candidate34_source_sha256"] = candidate_source_sha256
	else:
		cohort_record["candidate33_source_sha256"] = candidate_source_sha256
	var cohort_digest := CanonicalJsonScript.sha256(cohort_record)
	var policy_digest := CanonicalJsonScript.sha256({"policy_id": policy_id})
	var schema_digest := CanonicalJsonScript.sha256({"schema_version": schema_version})
	var receipt := {
		"schema_version": schema_version,
		"policy_id": policy_id,
		"claim_level": claim_level,
		"feature_order": FeatureReceiptScript.AXIS_ORDER.duplicate(),
		"ordered_cohort_member_ids": cohort_ids.duplicate(),
		"ordered_cohort_feature_receipt_sha256": cohort_feature_digests,
		"cohort_sha256": cohort_digest,
		"population_mean_dimensionless": means,
		"population_standard_deviation_dimensionless": standard_deviations,
		"ordered_cohort_standardized_coordinates_dimensionless": standardized_cohort,
		"leave_one_out_nearest_distances_dimensionless":
		leave_one_out_nearest_distances,
		"supported_threshold_dimensionless": supported_threshold,
		"edge_threshold_dimensionless": edge_threshold,
		"query_morphology_id": String(query_receipt["morphology_id"]),
		"query_feature_receipt_sha256": query_feature_digest,
		"query_raw_coordinates_dimensionless": query_vector,
		"query_standardized_coordinates_dimensionless": standardized_query,
		"nearest_cohort_id": nearest_cohort_id,
		"nearest_distance_dimensionless": nearest_query_distance,
		"per_axis_excursion": per_axis_excursion,
		"maximum_standardized_excursion_dimensionless":
		maximum_standardized_excursion,
		"status": status,
		"coverage_policy_sha256": policy_digest,
		"coverage_schema_sha256": schema_digest,
		"policy_response": POLICY_RESPONSE,
		"controller_branch_authority": false,
		"physical_acceptance_authority": false,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
		"automatic_creature_guidance_allowed": false,
		"world_build_count": 0,
	}
	if profile_generation == PROFILE_GQ15:
		receipt["candidate35_source_sha256"] = candidate_source_sha256
	elif profile_generation == PROFILE_GQ14:
		receipt["candidate34_source_sha256"] = candidate_source_sha256
	else:
		receipt["candidate33_source_sha256"] = candidate_source_sha256
	var finite_report := FiniteSanitizerScript.inspect(receipt)
	if not bool(finite_report.get("ok", false)):
		return _failure("MORPHOLOGY_COVERAGE_RECEIPT_NONFINITE")
	return {
		"ok": true,
		"failure_code": "",
		"coverage_receipt": receipt,
		"coverage_receipt_sha256": CanonicalJsonScript.sha256(receipt),
		"world_build_count": 0,
	}


static func verify(
	cohort_feature_results: Array,
	query_feature_result: Dictionary,
	expected_coverage_receipt_sha256: String,
) -> Dictionary:
	var result := compile(cohort_feature_results, query_feature_result)
	if not bool(result.get("ok", false)):
		return result
	if (
		not _digest_valid(expected_coverage_receipt_sha256)
		or String(result["coverage_receipt_sha256"]) != expected_coverage_receipt_sha256
	):
		return _failure("MORPHOLOGY_COVERAGE_RECEIPT_DIGEST_MISMATCH")
	return result


static func verify_gq14(
	cohort_feature_results: Array,
	query_feature_result: Dictionary,
	expected_coverage_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq14(cohort_feature_results, query_feature_result)
	if not bool(result.get("ok", false)):
		return result
	if (
		not _digest_valid(expected_coverage_receipt_sha256)
		or String(result["coverage_receipt_sha256"]) != expected_coverage_receipt_sha256
	):
		return _failure("MORPHOLOGY_COVERAGE_RECEIPT_DIGEST_MISMATCH")
	return result


static func verify_gq15(
	cohort_feature_results: Array,
	query_feature_result: Dictionary,
	expected_coverage_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq15(cohort_feature_results, query_feature_result)
	if not bool(result.get("ok", false)):
		return result
	if (
		not _digest_valid(expected_coverage_receipt_sha256)
		or String(result["coverage_receipt_sha256"]) != expected_coverage_receipt_sha256
	):
		return _failure("MORPHOLOGY_COVERAGE_RECEIPT_DIGEST_MISMATCH")
	return result


static func classify_distance(
	nearest_distance: float,
	supported_threshold: float,
	edge_threshold: float,
) -> String:
	if (
		not is_finite(nearest_distance)
		or not is_finite(supported_threshold)
		or not is_finite(edge_threshold)
		or nearest_distance < 0.0
		or supported_threshold <= 0.0
		or edge_threshold < supported_threshold
	):
		return ""
	if nearest_distance <= supported_threshold:
		return "SUPPORTED"
	if nearest_distance <= edge_threshold:
		return "EDGE"
	return "OUT_OF_DISTRIBUTION"


static func _vectors_valid(cohort_vectors: Array, query_vector: Array) -> bool:
	if query_vector.size() != FeatureReceiptScript.AXIS_ORDER.size():
		return false
	for vector_value in cohort_vectors + [query_vector]:
		if not vector_value is Array:
			return false
		var vector: Array = vector_value
		if vector.size() != FeatureReceiptScript.AXIS_ORDER.size():
			return false
		for value in vector:
			if (
				(typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT)
				or not is_finite(float(value))
			):
				return false
	return true


static func _standardize(vector: Array, means: Array, standard_deviations: Array) -> Array:
	var standardized: Array = []
	for axis_index in range(vector.size()):
		standardized.append(
			(float(vector[axis_index]) - float(means[axis_index]))
			/ float(standard_deviations[axis_index])
		)
	return standardized


static func _euclidean_distance(left: Array, right: Array) -> float:
	var squared_distance := 0.0
	for axis_index in range(left.size()):
		var delta := float(left[axis_index]) - float(right[axis_index])
		squared_distance += delta * delta
	return sqrt(squared_distance)


static func _digest_valid(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"world_build_count": 0,
	}
