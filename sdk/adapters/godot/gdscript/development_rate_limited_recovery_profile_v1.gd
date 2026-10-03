extends RefCounted

## One definition shared with the Python consumer and PowerShell launcher.
## Return copies: callers cannot mutate the process's loaded selection.
const PATH := "res://sdk/development_rate_limited_recovery_profile_v1.json"
static var _source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))

static func value_v1() -> Dictionary:
	return _source.duplicate(true)
