extends SceneTree

## Independent no-world GDScript-oracle verification for the SDK's frozen
## Candidate 35 conformance vectors. The Rust core consumes the same JSON.

const CampaignScript := preload(
	"res://tests/test_experimental_br14a_11_physical_wave_gait_nonuniform_proportion_probe.gd"
)
const GOLDEN_PATH := "res://sdk/conformance/golden/candidate35_gq15_v1.json"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK Candidate 35 GDScript golden-vector oracle ===")
	var parsed := _load_golden()
	_check(not parsed.is_empty(), "golden vector document parses")
	if parsed.is_empty():
		_finish()
		return
	_check(
		String(parsed.get("schema_version", ""))
		== "sporespore_candidate35_golden_vectors_v1",
		"golden vector schema is exact",
	)
	_check(
		String(parsed.get("oracle_source_commit", ""))
		== "52ce84d300dfac945096403250e429a183ebda4e",
		"golden vectors remain pinned to the GQ15 implementation commit",
	)
	var tolerance := float(parsed.get("tolerance", 0.0))
	for vector_value in parsed.get("interaction_vectors", []):
		var vector: Dictionary = vector_value
		var scales: Array = vector.get("scales", [])
		var declared := {
			"torso_length_scale": float(scales[0]),
			"torso_width_scale": float(scales[1]),
			"upper_length_fraction": float(scales[2]),
			"hip_span_scale": float(scales[3]),
			"foot_radius_scale": float(scales[4]),
			"front_limb_mass_scale": float(scales[5]),
		}
		_check_close(
			CampaignScript._morphology_interaction_score(declared),
			float(vector["expected_score"]),
			tolerance,
			"interaction vector %s" % String(vector["vector_id"]),
		)
	for vector_value in parsed.get("controller_vectors", []):
		var vector: Dictionary = vector_value
		var score := float(vector["score"])
		var length := float(vector["torso_length_scale"])
		var width := float(vector["torso_width_scale"])
		var foot := float(vector["foot_radius_scale"])
		var hip := float(vector["hip_span_scale"])
		var yaw := CampaignScript._gq13_yaw_gain_per_rad(score, length, foot, hip)
		var guard := CampaignScript._gq15_motor_guard_values(
			score,
			{
				"torso_length_scale": length,
				"torso_width_scale": width,
			},
		)
		var actual := [
			CampaignScript._gq13_cross_track_gain_per_m(score),
			yaw,
			CampaignScript._gq15_velocity_gain_rad_per_m_s(
				score,
				length,
				width,
				foot,
				yaw,
			),
			float(guard[0]),
			float(guard[1]),
		]
		var expected: Array = vector["expected"]
		for index in range(actual.size()):
			_check_close(
				float(actual[index]),
				float(expected[index]),
				tolerance,
				"controller vector %s field %d" % [String(vector["vector_id"]), index],
			)
	_finish()


func _load_golden() -> Dictionary:
	var file := FileAccess.open(GOLDEN_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _check_close(
	actual: float,
	expected: float,
	tolerance: float,
	label: String,
) -> void:
	_check(
		is_finite(actual)
		and is_finite(expected)
		and absf(actual - expected) <= tolerance,
		"%s (expected %.15f, got %.15f)" % [label, expected, actual],
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print("\nSDK golden-vector summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
