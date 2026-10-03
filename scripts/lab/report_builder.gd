class_name LabReportBuilder
extends RefCounted

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")


static func metric(
		metric_id: String,
		value: Variant,
		unit: String,
		source_stream: String,
		source_frame_range: Array,
		source_field: String,
		aggregation_id: String,
		aggregation_version := 1,
		availability := "derived",
		target_value: Variant = null) -> Dictionary:
	if (metric_id.is_empty() or unit.is_empty() or source_stream.is_empty()
		or source_frame_range.size() != 2 or source_field.is_empty()
		or aggregation_id.is_empty() or aggregation_version < 1):
		return {}
	return FrozenValueScript.snapshot({
		"metric_id": metric_id,
		"value": value,
		"unit": unit,
		"availability": availability,
		"source_stream": source_stream,
		"source_frame_range": source_frame_range,
		"source_field": source_field,
		"aggregation_id": aggregation_id,
		"aggregation_version": aggregation_version,
		"target_value": target_value,
	})


static func comparison_metric(
		run_id: String,
		metric_id: String,
		value: Variant,
		unit: String,
		left_stream: String,
		right_stream: String,
		source_frame_range: Array,
		source_field: String,
		aggregation_id := "max_pairwise_vec3_distance_v1",
		aggregation_version := 1,
		target_value: Variant = null,
		recompute_absolute_tolerance := 1.0e-7) -> Dictionary:
	if (
		run_id.is_empty()
		or metric_id.is_empty()
		or unit.is_empty()
		or left_stream.is_empty()
		or right_stream.is_empty()
		or source_frame_range.size() != 2
		or source_field.is_empty()
		or aggregation_id.is_empty()
		or aggregation_version < 1
		or not is_finite(recompute_absolute_tolerance)
		or recompute_absolute_tolerance < 0.0
	):
		return {}
	return FrozenValueScript.snapshot({
		"metric_id": metric_id,
		"value": value,
		"unit": unit,
		"availability": "derived",
		"source_operands": [
			{
				"stream": left_stream,
				"frame_range": source_frame_range,
				"field": source_field,
				"run_id": run_id,
			},
			{
				"stream": right_stream,
				"frame_range": source_frame_range,
				"field": source_field,
				"run_id": run_id,
			},
		],
		"aggregation_id": aggregation_id,
		"aggregation_version": aggregation_version,
		"target_value": target_value,
		"recompute_absolute_tolerance": recompute_absolute_tolerance,
	})


static func metrics_dictionary(metrics: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw in metrics:
		if raw is Dictionary and raw.has("metric_id"):
			result[String(raw["metric_id"])] = raw.get("value")
	return result
