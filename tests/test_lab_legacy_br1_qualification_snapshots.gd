extends SceneTree

const RegistryScript := preload("res://scripts/lab/certification_qualification_profile_registry.gd")

const SNAPSHOTS := {
	"res://data/lab/legacy/br1_report_v1/r001_i45/BR1_required_lab_tests_v1.snapshot.json":
	{
		"bytes": 2044,
		"sha256": "4e090096c4009e1406214307a80e46480e80efbb4228f30df8efdc9de4ff13f6",
	},
	"res://data/lab/legacy/br1_report_v1/r001_i45/br1_certification_report_v1.snapshot.schema.json":
	{
		"bytes": 29674,
		"sha256": "f7596fcaf798c1c4627d5cef1af4bda4136cbf08346acf00284e13f23e502567",
	},
	"res://data/lab/legacy/br1_report_v1/r002_i51/BR1_required_lab_tests_v1.snapshot.json":
	{
		"bytes": 2305,
		"sha256": "f287e53d6b47fad15205a8ed416b0616e5eaae694453cd661c6eb08e1e2b79fa",
	},
	"res://data/lab/legacy/br1_report_v1/r002_i51/br1_certification_report_v1.snapshot.schema.json":
	{
		"bytes": 29676,
		"sha256": "f42f060962fd2870f36c9e615d9efea5af1e2744f36f3c95e9ed4f46991b7be8",
	},
	"res://data/lab/legacy/br1_report_v1/common/BR1_L0_certification_v1.snapshot.json":
	{
		"bytes": 3894,
		"sha256": "c8146b00bfabfd2c4784cf2907ef68244d03388ccc184a9d16a99d49423419cd",
	},
	(
		"res://data/lab/legacy/br1_report_v1/common/"
		+ "certification_report_attestation_v1.snapshot.schema.json"
	):
	{
		"bytes": 2120,
		"sha256": "8cb6aceefa9b11bbd6756b91185c6f00adea06633633929d5c588d2a1804d716",
	},
}

const R001_INVENTORY := (
	"res://data/lab/legacy/br1_report_v1/r001_i45/" + "BR1_required_lab_tests_v1.snapshot.json"
)
const R002_INVENTORY := (
	"res://data/lab/legacy/br1_report_v1/r002_i51/" + "BR1_required_lab_tests_v1.snapshot.json"
)
const R001_REPORT_SCHEMA := (
	"res://data/lab/legacy/br1_report_v1/r001_i45/"
	+ "br1_certification_report_v1.snapshot.schema.json"
)
const R002_REPORT_SCHEMA := (
	"res://data/lab/legacy/br1_report_v1/r002_i51/"
	+ "br1_certification_report_v1.snapshot.schema.json"
)
const ADDED_R002_TESTS := [
	"test_lab_angle_sign.gd",
	"test_lab_angular_momentum_availability.gd",
	"test_lab_body_sample_frames.gd",
	"test_lab_direct_inertia_finite.gd",
	"test_lab_joint_axis_rotates_with_parent.gd",
	"test_lab_unwrapped_angle_stream_continuity.gd",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Legacy BR1 qualification snapshot tests ===")
	_test_exact_snapshot_bytes()
	_test_inventory_revisions_are_exact()
	_test_report_schema_cardinalities_are_exact()
	_test_registry_accepts_both_complete_snapshot_sets()
	_finish()


func _test_exact_snapshot_bytes() -> void:
	print("- preserves every historical file byte-for-byte")
	for path_value in SNAPSHOTS:
		var path := String(path_value)
		var expected: Dictionary = SNAPSHOTS[path]
		_check(FileAccess.file_exists(path), "%s exists" % path.get_file())
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		_check(
			file != null and file.get_length() == int(expected["bytes"]),
			"%s keeps its exact byte count" % path.get_file()
		)
		var actual_hash := FileAccess.get_sha256(ProjectSettings.globalize_path(path)).to_lower()
		_check(
			actual_hash == String(expected["sha256"]),
			"%s keeps its exact SHA-256" % path.get_file()
		)


func _test_inventory_revisions_are_exact() -> void:
	print("- keeps the 45-test and 51-test inventories distinct")
	var r001 := _read_object(R001_INVENTORY)
	var r002 := _read_object(R002_INVENTORY)
	_check(not r001.is_empty() and not r002.is_empty(), "both inventories parse")
	if r001.is_empty() or r002.is_empty():
		return
	_check(
		int(r001["test_count"]) == 45 and (r001["tests"] as Array).size() == 45,
		"R001 is the exact 45-test contract"
	)
	_check(
		int(r002["test_count"]) == 51 and (r002["tests"] as Array).size() == 51,
		"R002 is the exact 51-test contract"
	)
	var added: Array[String] = []
	for test_value in r002["tests"]:
		var test_name := String(test_value)
		if not (r001["tests"] as Array).has(test_name):
			added.append(test_name)
	_check(added == ADDED_R002_TESTS, "R002 adds exactly the six BR2 observation tests")
	var removed: Array[String] = []
	for test_value in r001["tests"]:
		var test_name := String(test_value)
		if not (r002["tests"] as Array).has(test_name):
			removed.append(test_name)
	_check(removed.is_empty(), "R002 removes no R001 test")


func _test_report_schema_cardinalities_are_exact() -> void:
	print("- keeps each report schema coupled to its inventory cardinality")
	var r001 := _read_object(R001_REPORT_SCHEMA)
	var r002 := _read_object(R002_REPORT_SCHEMA)
	_check(not r001.is_empty() and not r002.is_empty(), "both report schemas parse")
	if r001.is_empty() or r002.is_empty():
		return
	_check(
		(
			_report_schema_count(r001) == 45
			and _report_schema_artifact_min(r001) == 90
			and _report_schema_artifact_max(r001) == 90
		),
		"R001 report schema pins 45 tests and 90 artifacts"
	)
	_check(
		(
			_report_schema_count(r002) == 51
			and _report_schema_artifact_min(r002) == 102
			and _report_schema_artifact_max(r002) == 102
		),
		"R002 report schema pins 51 tests and 102 artifacts"
	)
	_check(
		String(r001["$id"]) == String(r002["$id"]),
		"the snapshots expose the historical reused schema ID"
	)


func _test_registry_accepts_both_complete_snapshot_sets() -> void:
	print("- loads both immutable snapshot sets through the allowlist")
	var r001 := RegistryScript.load_by_id(RegistryScript.PROFILE_R001_I45)
	var r002 := RegistryScript.load_by_id(RegistryScript.PROFILE_R002_I51)
	_check(bool(r001.get("ok", false)), "R001 snapshot set passes registry integrity")
	_check(bool(r002.get("ok", false)), "R002 snapshot set passes registry integrity")


static func _report_schema_count(schema: Dictionary) -> int:
	return int(schema["$defs"]["test_inventory"]["properties"]["required"]["const"])


static func _report_schema_artifact_min(schema: Dictionary) -> int:
	return int(schema["$defs"]["test_inventory"]["properties"]["artifacts"]["minItems"])


static func _report_schema_artifact_max(schema: Dictionary) -> int:
	return int(schema["$defs"]["test_inventory"]["properties"]["artifacts"]["maxItems"])


static func _read_object(path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
