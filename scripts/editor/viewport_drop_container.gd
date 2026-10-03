extends SubViewportContainer

## SubViewportContainer that forwards Godot drag-and-drop to bench callbacks while
## leaving the 3D viewport's own gui_input (camera orbit + part picking) intact.
## Deliberately has no class_name: the bench preloads it by path, so a headless
## run needs no global class registration.

var can_drop_cb: Callable
var drop_cb: Callable


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return can_drop_cb.is_valid() and bool(can_drop_cb.call(at_position, data))


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if drop_cb.is_valid():
		drop_cb.call(at_position, data)
