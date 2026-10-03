class_name DialDef
extends Resource

## One live, authorable dial on a part. The descriptor generator reads dial values; the
## genome stores absolute values clamped to [min_value, max_value] on load.

@export var name:          StringName
@export var min_value:     float
@export var max_value:     float
@export var default_value: float
@export var shape_key:     StringName = &""   # glTF shape key driven for M2 visuals
@export var is_branch:     bool = false       # discrete topology selector


func clamp_value(v: float) -> float:
	return clampf(v, min_value, max_value)
