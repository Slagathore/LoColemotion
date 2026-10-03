extends "res://tests/test_development_r10k_preparation_report.gd"
# gdlint: disable=max-line-length

## Use the complete shared preparation timeline with the actual R10L declaration.
func _declared_v1() -> Dictionary:
	if _declaration.is_empty():
		_declaration = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SPORE_R10L_FIXTURE_DECLARATION")))
	return _declaration
