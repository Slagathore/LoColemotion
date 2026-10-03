extends SceneTree

# The executable test is the viewer script's own --self-test. This resource
# exists so repository audits can discover the zero-world viewer contract.

func _initialize() -> void:
	quit(0)
