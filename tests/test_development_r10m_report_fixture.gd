extends "res://tests/test_development_r10k_report_fixture.gd"
# gdlint: disable=max-line-length

## Reuse the complete recovery timelines with the actual R10M candidate and publisher.
func _declared_v1() -> Dictionary:
	if _declaration.is_empty():
		_declaration = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SPORE_R10M_FIXTURE_DECLARATION")))
	return _declaration
