class_name LabControllerCapabilityGate
extends RefCounted

## Conservative static tripwire for controller scripts. It strips comments and
## string literals, then rejects raw RNG ownership and unqualified global draws.
## A future parser-backed gate may tighten this; this implementation fails
## closed on every currently forbidden spelling.

const FORBIDDEN_IDENTIFIERS := [
	"RandomNumberGenerator",
	"randomize",
	"rand_from_seed",
]
const GLOBAL_DRAWS := [
	"randf",
	"randi",
	"randfn",
	"randf_range",
	"randi_range",
]


static func inspect_source(source: String) -> Dictionary:
	var stripped := _strip_comments_and_strings(source)
	var violations: Array = []
	for identifier in FORBIDDEN_IDENTIFIERS:
		var regex := RegEx.new()
		regex.compile("(^|[^A-Za-z0-9_])%s([^A-Za-z0-9_]|$)" % identifier)
		if regex.search(stripped) != null:
			violations.append({
				"code": "FORBIDDEN_RNG_CAPABILITY",
				"identifier": identifier,
			})
	var member_regex := RegEx.new()
	member_regex.compile("(^|[^A-Za-z0-9_])(_rng|seed|state)([^A-Za-z0-9_]|$)")
	for hit in member_regex.search_all(stripped):
		violations.append({
			"code": "FORBIDDEN_RNG_STATE_ACCESS",
			"identifier": hit.get_string(2),
		})
	for draw in GLOBAL_DRAWS:
		var draw_regex := RegEx.new()
		# A preceding dot identifies a draw through an explicit capability.
		draw_regex.compile("(^|[^A-Za-z0-9_.])%s\\s*\\(" % draw)
		if draw_regex.search(stripped) != null:
			violations.append({
				"code": "UNQUALIFIED_GLOBAL_RANDOM_DRAW",
				"identifier": draw,
			})
	violations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if String(a["code"]) != String(b["code"]):
			return String(a["code"]) < String(b["code"])
		return String(a["identifier"]) < String(b["identifier"]))
	return {
		"ok": violations.is_empty(),
		"violations": violations,
	}


static func inspect_path(resource_path: String) -> Dictionary:
	if not FileAccess.file_exists(resource_path):
		return {
			"ok": false,
			"violations": [{
				"code": "CONTROLLER_SOURCE_MISSING",
				"identifier": resource_path,
			}],
		}
	return inspect_source(FileAccess.get_file_as_string(resource_path))


static func _strip_comments_and_strings(source: String) -> String:
	var result := ""
	var in_string := false
	var quote := ""
	var escaped := false
	var index := 0
	while index < source.length():
		var c := source[index]
		if in_string:
			if escaped:
				escaped = false
			elif c == "\\":
				escaped = true
			elif c == quote:
				in_string = false
			result += " "
			index += 1
			continue
		if c == "\"" or c == "'":
			in_string = true
			quote = c
			result += " "
			index += 1
			continue
		if c == "#":
			while index < source.length() and source[index] != "\n":
				result += " "
				index += 1
			continue
		result += c
		index += 1
	return result
