extends SceneTree

## Zero-world contract for the Godot/Jolt nuisance challenge surface.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MANIFEST_PATH := "res://sdk/balanced_wave_bw6n_validation_manifest.json"
const EXPECTED_DIGESTS := [
	"sha256:0b3f9e0fafd1f00c69a72a216975446897492e4e6e96f9e0405958f99621bb1b",
	"sha256:da97bf60b8ed83c80b9ab3c00c188b8d8b874b3c1ca9b180a4940873cef8ec7e",
	"sha256:0f8bb1a1c522c3d36ea277b4ce778bc6e71f45172f1d3b37e2a7e23021dfa02a",
	"sha256:1f1f7ad6837c16dd7a0415f6fa90c501300968f1c6ffad8775080dd2f399dbbb",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK environment challenge zero-world contract ===")
	var manifest := _load_json_dictionary(MANIFEST_PATH)
	var profiles: Array = manifest.get("challenge_profiles", [])
	_check(profiles.size() == 4, "1 the frozen manifest contains exactly four profiles")
	var observed_digests: Array = []
	var all_compile := profiles.size() == 4
	for profile_value in profiles:
		var result := WaveGaitScript.compile_environment_challenge_options(profile_value)
		all_compile = all_compile and bool(result.get("ok", false))
		observed_digests.append(
			String(result.get("environment_challenge_configuration_sha256", ""))
		)
	_check(
		all_compile and observed_digests == EXPECTED_DIGESTS,
		"2 all challenge profiles compile to their frozen canonical digests",
	)
	var defaults := WaveGaitScript.compile_environment_challenge_options({})
	_check(
		bool(defaults.get("ok", false))
		and (
			String(
				(defaults.get("environment_challenge_options", {}) as Dictionary).get(
					"challenge_profile_id",
					"",
				)
			)
			== "none_v1"
		),
		"3 the empty request remains an explicit flat/no-push/no-fault default",
	)
	var unknown: Dictionary = (profiles[0] as Dictionary).duplicate(true)
	unknown["outcome_tuned_field"] = 1
	_check(
		not bool(
			WaveGaitScript.compile_environment_challenge_options(unknown).get("ok", true)
		),
		"4 unknown challenge fields fail closed",
	)
	var fake_rough: Dictionary = (profiles[1] as Dictionary).duplicate(true)
	fake_rough["terrain_heights_m"] = [0.0, 0.0, 0.0]
	_check(
		not bool(
			WaveGaitScript.compile_environment_challenge_options(fake_rough).get("ok", true)
		),
		"5 a nominal rough profile without three distinct heights fails closed",
	)
	var invalid_push: Dictionary = (profiles[2] as Dictionary).duplicate(true)
	invalid_push["push_impulse_task_n_s"] = [0.2, 0.0, 0.25]
	_check(
		not bool(
			WaveGaitScript.compile_environment_challenge_options(invalid_push).get("ok", true)
		),
		"6 the lateral push profile rejects hidden forward impulse",
	)
	var invalid_noise: Dictionary = (profiles[3] as Dictionary).duplicate(true)
	invalid_noise["base_position_noise_amplitude_m"] = 0.02
	var malformed_noise: Dictionary = (profiles[3] as Dictionary).duplicate(true)
	malformed_noise["base_position_noise_amplitude_m"] = "0.002"
	var malformed_noise_result := WaveGaitScript.compile_environment_challenge_options(
		malformed_noise
	)
	_check(
		not bool(
			WaveGaitScript.compile_environment_challenge_options(invalid_noise).get("ok", true)
		)
		and not bool(malformed_noise_result.get("ok", true))
		and (
			String(malformed_noise_result.get("failure_code", ""))
			== "OBSERVATION_NOISE_AMPLITUDE_INVALID"
		),
		"7 out-of-envelope or malformed observation noise fails closed",
	)
	var sensor_options: Dictionary = (
		WaveGaitScript
		. compile_environment_challenge_options(profiles[3])
		. get(
			"environment_challenge_options",
			{},
		)
	)
	var step_sample := _sample_result()
	var step_fault := AdapterScript._apply_observation_fault_to_step_request(
		step_sample,
		37,
		sensor_options,
	)
	_check(
		bool(step_fault.get("ok", false))
		and bool(step_fault.get("fault_applied", false))
		and float(step_fault.get("maximum_absolute_applied_component", 0.0)) == 0.02
		and step_sample == _sample_result(),
		"8 base and joint sensor noise is deterministic and does not mutate its input",
	)
	var stability_state := _stability_state()
	var support_points := {"front_left_foot": Vector3(0.2, 0.0, -0.18)}
	var stability_fault := AdapterScript._apply_observation_fault_to_stability_state(
		stability_state,
		support_points,
		37,
		sensor_options,
	)
	_check(
		bool(stability_fault.get("ok", false))
		and bool(stability_fault.get("fault_applied", false))
		and float(stability_fault.get("maximum_absolute_applied_component", 0.0)) == 0.02
		and stability_state == _stability_state()
		and support_points == {"front_left_foot": Vector3(0.2, 0.0, -0.18)},
		"9 stability-body and support-point noise is deterministic and non-mutating",
	)
	print(
		"\nSDK environment challenge contract: %d passed, %d failed (expected 9)"
		% [_passed, _failed]
	)
	quit(0 if _failed == 0 and _passed == 9 else 1)


static func _sample_result() -> Dictionary:
	return {
		"ok": true,
		"request":
		{
			"state":
			{
				"base_pose_world":
				{"position_m": {"x": 0.0, "y": 0.4, "z": 0.0}},
				"base_twist_world":
				{"linear_velocity_m_s": {"x": 0.1, "y": 0.0, "z": 0.0}},
				"ordered_joint_observations":
				[
					{
						"joint_id": "front_left_hip",
						"position_rad": 0.1,
						"velocity_rad_s": -0.2,
					}
				],
			}
		},
	}


static func _stability_state() -> Dictionary:
	return {
		"ordered_body_states":
		[
			{
				"body_id": "torso",
				"pose_world":
				{"position_m": {"x": 0.0, "y": 0.4, "z": 0.0}},
				"twist_world":
				{"linear_velocity_m_s": {"x": 0.1, "y": 0.0, "z": 0.0}},
			}
		],
		"ordered_support_contacts":
		[
			{
				"contact_site_id": "front_left_foot",
				"point_world_m": {"x": 0.2, "y": 0.0, "z": -0.18},
			}
		],
	}


static func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)
