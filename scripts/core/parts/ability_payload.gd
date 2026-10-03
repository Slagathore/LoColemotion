class_name AbilityPayload
extends Resource

## H2 forward hook: the evaluator NEVER reads this. Problem 3 (abilities) reads it and
## scales `params` off the named dials in `scaling`.

@export var type:    StringName
@export var params:  Dictionary
@export var scaling: Dictionary[StringName, StringName] = {}   # ability-param → dial name


func _init(p_type: StringName = &"", p_params: Dictionary = {},
		p_scaling: Dictionary[StringName, StringName] = {}) -> void:
	type = p_type
	params = p_params
	scaling = p_scaling
