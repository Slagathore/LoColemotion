extends SceneTree

const ActuationExecutorScript := preload(
	"res://scripts/lab/actuation_executor.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const ExecutionReceiptSinkScript := preload(
	"res://scripts/lab/records/execution_receipt.gd")
const FiniteSanitizerScript := preload(
	"res://scripts/lab/finite_sanitizer.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab non-finite terminal-evidence contract ===")
	_test_terminal_evidence_nulls_invalid_leaves_with_provenance()
	_test_unsealed_nonfinite_command_has_no_application_receipt()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_terminal_evidence_nulls_invalid_leaves_with_provenance() -> void:
	print("- sanitizes every invalid terminal leaf without losing its cause")
	var raw_terminal_evidence := {
		"observation": {
			"nan_value": NAN,
			"positive_infinity": INF,
			"negative_infinity": -INF,
			"unsafe_json_integer": 9007199254740992,
			"velocity_world_m_s": Vector3(1.0, INF, -2.0),
		},
		"termination": {
			"code": "NONFINITE_STATE",
			"source_frame_id": 17,
		},
	}
	var report: Dictionary = FiniteSanitizerScript.sanitize(
		raw_terminal_evidence,
		"observer.direct_state")
	var evidence: Dictionary = report["value"]
	var observation: Dictionary = evidence["observation"]
	var availability: Dictionary = report["availability"]

	_check(
		not bool(report["ok"]) and report["failures"].size() == 5,
		"NaN, both infinities, an unsafe integer, and a vector infinity are all reported")
	_check(
		observation["nan_value"] == null
			and observation["positive_infinity"] == null
			and observation["negative_infinity"] == null
			and observation["unsafe_json_integer"] == null
			and observation["velocity_world_m_s"][1] == null,
		"every invalid leaf is replaced by JSON null")
	_check(
		observation["velocity_world_m_s"][0] == 1.0
			and observation["velocity_world_m_s"][2] == -2.0
			and evidence["termination"]["source_frame_id"] == 17,
		"finite neighboring evidence is preserved")
	_check(
		availability["/observation/nan_value"]["reason"] == "NAN"
			and availability["/observation/positive_infinity"]["reason"] == "POS_INF"
			and availability["/observation/negative_infinity"]["reason"] == "NEG_INF"
			and availability["/observation/unsafe_json_integer"]["reason"]
				== "INTEGER_OUT_OF_JSON_EXACT_RANGE"
			and availability["/observation/velocity_world_m_s/1"]["reason"]
				== "POS_INF",
		"availability records the exact reason at each JSON-pointer path")
	var provenance_is_explicit := true
	for path in availability:
		var entry: Dictionary = availability[path]
		provenance_is_explicit = (
			provenance_is_explicit
			and entry["status"] == "invalid"
			and entry["source_id"] == "observer.direct_state")
	_check(
		provenance_is_explicit,
		"every unavailable leaf names its invalid status and observation source")
	var canonical_text := CanonicalJsonScript.stringify(evidence)
	var reparsed: Variant = JSON.parse_string(canonical_text)
	_check(
		reparsed is Dictionary
			and CanonicalJsonScript.sha256(evidence)
				== CanonicalJsonScript.sha256(reparsed),
		"sanitized terminal evidence is canonical and hash-stable after JSON round-trip")
	_check(
		reparsed is Dictionary
			and bool(FiniteSanitizerScript.inspect(reparsed)["ok"]),
		"serialized terminal evidence contains no non-finite numeric value")


func _test_unsealed_nonfinite_command_has_no_application_receipt() -> void:
	print("- rejects a non-finite command before any physics-call receipt")
	var nonfinite_payload := {
		"schema": "sporespore.lab.command.v1",
		"run_id": "nonfinite_command_run",
		"command_id": 0,
		"source_frame_id": 0,
		"applied_transition": [0, 1],
		"mode": "TEST",
		"intervention_operation_ids": [],
		"joint_commands": [{
			"tick": 0,
			"joint_id": "fixture_joint",
			"planned_application_operations": [{
				"operation_id": "nonfinite_torque_0",
				"body_id": "fixture_body",
				"api": "RigidBody3D.apply_torque",
				"torque_world_nm": Vector3(INF, 0.0, 0.0),
			}],
		}],
	}
	var finite_report: Dictionary = FiniteSanitizerScript.inspect(
		nonfinite_payload)
	_check(
		not bool(finite_report["ok"])
			and finite_report["failures"].size() == 1
			and finite_report["failures"][0]["path"]
				== "/joint_commands/0/planned_application_operations/0/torque_world_nm/x",
		"pre-seal inspection identifies the exact non-finite command argument")

	# A non-finite payload cannot receive a canonical payload hash, so it is
	# intentionally presented as an unsealed envelope. The executor must reject
	# it at the envelope boundary before it allocates a call ordinal or receipt.
	var sink = ExecutionReceiptSinkScript.new("nonfinite_command_run")
	var rejected: Dictionary = ActuationExecutorScript.apply_command_envelope(
		{"payload": nonfinite_payload},
		{},
		sink)
	_check(
		not bool(rejected["ok"])
			and rejected["error"] == "COMMAND_ENVELOPE_MALFORMED",
		"executor rejects the unsealed non-finite command")
	_check(
		sink.values().is_empty(),
		"rejected non-finite command yields no application receipt")
