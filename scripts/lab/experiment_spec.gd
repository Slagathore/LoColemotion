class_name ExperimentSpec
extends Resource

## Authored experiment input. The runner must compile this Resource into an
## ExpandedExperiment before using any value.

const CURRENT_SCHEMA := "sporespore.lab.experiment.v1"

@export var schema := CURRENT_SCHEMA
@export var experiment_id: StringName = &""
@export var hypothesis_id: StringName = &""
@export var fixture_id: StringName = &""
@export_range(1, 2147483647, 1) var fixture_version := 1
@export var controller_id: StringName = &"none"
@export var observer_profile_id: StringName = &"full_state_v1"
@export var required_observer_channels: Array[StringName] = []

@export_group("Run")
@export_range(1, 2147483647, 1) var duration_ticks := 120
@export_range(0, 2147483647, 1) var warmup_ticks := 0
@export_range(1, 1000, 1) var physics_ticks_per_second := 60
@export var root_seed := 0
@export var random_stream_ids: Array[StringName] = [
	&"morphology",
	&"disturbance",
	&"controller_exploration",
	&"sensor_noise",
	&"surface_variation",
]

@export_group("Scientific parameters")
@export var body_parameters: Dictionary = {}
@export var fixture_parameters: Dictionary = {}
@export var controller_parameters: Dictionary = {}
@export var gate_parameters: Dictionary = {}

@export_group("Scaffolds and campaign")
@export var allowed_scaffolds: Array[StringName] = []
@export var forbidden_scaffolds: Array[StringName] = []
@export var independent_variables: Array[String] = []

@export_group("Non-scientific labels")
@export var metadata: Dictionary = {}


func to_value_dictionary() -> Dictionary:
	return {
		"schema": schema,
		"experiment_id": String(experiment_id),
		"hypothesis_id": String(hypothesis_id),
		"fixture_id": String(fixture_id),
		"fixture_version": fixture_version,
		"controller_id": String(controller_id),
		"observer_profile_id": String(observer_profile_id),
		"required_observer_channels": _string_array(required_observer_channels),
		"duration_ticks": duration_ticks,
		"warmup_ticks": warmup_ticks,
		"physics_ticks_per_second": physics_ticks_per_second,
		"root_seed": root_seed,
		"random_stream_ids": _string_array(random_stream_ids),
		"body_parameters": body_parameters.duplicate(true),
		"fixture_parameters": fixture_parameters.duplicate(true),
		"controller_parameters": controller_parameters.duplicate(true),
		"gate_parameters": gate_parameters.duplicate(true),
		"allowed_scaffolds": _string_array(allowed_scaffolds),
		"forbidden_scaffolds": _string_array(forbidden_scaffolds),
		"independent_variables": independent_variables.duplicate(),
		"metadata": metadata.duplicate(true),
	}


static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
