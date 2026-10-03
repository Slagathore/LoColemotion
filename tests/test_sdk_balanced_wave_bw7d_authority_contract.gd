extends SceneTree

## Zero-world authority contract for the prospective BW7D mechanism family.
##
## This test is allowed before the preregistered physics campaign because it
## creates no PhysicsServer body or simulation world. It binds the public native
## profile ABI, the branch-free 2x2 candidate identities, and the separately
## bounded evidence-acquisition policy to canonical hashes.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw7d_preregistration.json"
const PREREGISTRATION_SCHEMA := "sporespore_balanced_wave_bw7d_preregistration_v1"
const EXPECTED_PREREGISTRATION_SHA256 := (
	"sha256:9cc586d24ac2dd780f4c15b0e8de2009b0c026bd8d869af89e4212070eb43b75"
)
const CLASS_NAME := "SporeLocomotionSdk"
const PROFILE_SCHEMA := "sporespore_balanced_wave_release_progress_profile_v1"
const RECIPROCAL_TRANSFORM_ID := "reciprocal_steering_stride_transform_v1"
const POLICY_IDS := [
	"sporespore_balanced_wave_bw7d_a_v1",
	"sporespore_balanced_wave_bw7d_b_v1",
	"sporespore_balanced_wave_bw7d_c_v1",
	"sporespore_balanced_wave_bw7d_d_v1",
]
const CANDIDATE_IDS := ["BW7D-A", "BW7D-B", "BW7D-C", "BW7D-D"]
const EXPECTED_RELEASE_CAPS := [
	[3.25, 0.85, 2.25],
	[3.50, 0.90, 2.50],
	[3.25, 0.85, 2.25],
	[3.50, 0.90, 2.50],
]
const EXPECTED_TRANSFORMS := [
	"",
	"",
	RECIPROCAL_TRANSFORM_ID,
	RECIPROCAL_TRANSFORM_ID,
]
const EXPECTED_RUNTIME_PROFILE_SHA256 := [
	"sha256:14ac0f8d107fa13fca7ecf13fdd9fe95451bf9f1e6e21205bbcc457859caa4ab",
	"sha256:130c2b4959f3f8bdeb43d9a447c13dec1c870a8aadfdeb0bb9306ce61aad91ab",
	"sha256:91a634462ca4b579af406cbd78f078a69aef03f44ed671b37f37ecae359c43cb",
	"sha256:5708156714cdb9dc5c3f956b452c60d09acaa998e39970b556e3c2010a12878f",
]
const EXPECTED_CANDIDATE_POLICY_SHA256 := [
	"sha256:f02ce514f4afa074774c726155649c49fbf69ceaa953c518d6eaf418fc26cde0",
	"sha256:a5e58cd49f90af2d4c404478fbd25dd64b632df707e364aea3b9163268431424",
	"sha256:c3ef32cb4688dec23a2e01284fc73defe6cecbbed3738faaa6fb0779ea749b6a",
	"sha256:4700b9b7a5ea5379d8839103c04965fe6b4053b8e6adc830b50c6a7b5ff94003",
]
const EXPECTED_ACQUISITION_SHA256 := (
	"sha256:4a49770e35b67b2186a5a64ad3dcbf7d1d637e9ffc6ea2a9365615731eb2e748"
)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK balanced-wave BW7D zero-world authority contract ===")
	var extension_resource := load(EXTENSION_PATH)
	_check(extension_resource != null, "the checked-in GDExtension resource loads")
	_check(ClassDB.class_exists(CLASS_NAME), "the native SDK class is registered")
	if not ClassDB.class_exists(CLASS_NAME):
		_finish()
		return
	var api: Object = ClassDB.instantiate(CLASS_NAME)
	_check(api != null, "the native SDK class instantiates")
	_check(
		api != null and api.has_method("balanced_wave_policy_profile_json"),
		"the named balanced-wave profile ABI is registered",
	)
	if api == null or not api.has_method("balanced_wave_policy_profile_json"):
		_finish()
		return

	var bounded_acquisition := WaveGaitScript.compile_evidence_acquisition_options(
		{
			"policy_id": "bounded_all_support_acquisition_v1",
			"enabled": true,
			"maximum_acquisition_ticks": 15,
			"minimum_all_support_dwell_ticks": 3,
		},
		12,
		3,
	)
	var acquisition_sha := String(
		bounded_acquisition.get("evidence_acquisition_configuration_sha256", "")
	)
	print("BW7D_ACQUISITION_SHA256=", acquisition_sha)
	_check(
		bool(bounded_acquisition.get("ok", false))
		and acquisition_sha == EXPECTED_ACQUISITION_SHA256,
		"bounded acquisition is exactly phase-skew plus airborne dwell and hash-bound",
	)
	var malformed_acquisition := WaveGaitScript.compile_evidence_acquisition_options(
		{
			"policy_id": "bounded_all_support_acquisition_v1",
			"enabled": true,
			"maximum_acquisition_ticks": 14,
			"minimum_all_support_dwell_ticks": 3,
		},
		12,
		3,
	)
	_check(
		not bool(malformed_acquisition.get("ok", true))
		and String(malformed_acquisition.get("failure_code", ""))
		== "EVIDENCE_ACQUISITION_POLICY_RECEIPT_MISMATCH",
		"an off-by-one acquisition window fails closed",
	)
	var legacy_acquisition := WaveGaitScript.compile_evidence_acquisition_options({})
	_check(
		bool(legacy_acquisition.get("ok", false))
		and not bool(
			(
				legacy_acquisition.get("evidence_acquisition_options", {})
				as Dictionary
			).get("enabled", true)
		),
		"the omitted option preserves the legacy exact-boundary contract",
	)

	var descriptor := _reference_descriptor()
	var preregistration := _load_json_dictionary(PREREGISTRATION_PATH)
	var preregistration_sha := CanonicalJsonScript.sha256(preregistration)
	print("BW7D_PREREGISTRATION_SHA256=", preregistration_sha)
	_check(
		String(preregistration.get("schema_version", "")) == PREREGISTRATION_SCHEMA
		and String(preregistration.get("status", ""))
		== "frozen_before_first_bw7d_physics_world"
		and preregistration_sha == EXPECTED_PREREGISTRATION_SHA256,
		"the prospective preregistration is readable, frozen, and hash-bound",
	)
	var registered_candidates: Array = preregistration.get("candidates", [])
	var registered_digests: Dictionary = preregistration.get(
		"candidate_policy_digests",
		{},
	)
	var candidate_digests_match := true
	var runtime_digests_match := true
	var profiles_exact := true
	var manifest_candidates_exact := registered_candidates.size() == POLICY_IDS.size()
	for index in range(POLICY_IDS.size()):
		var envelope := _call_input(
			api,
			"balanced_wave_policy_profile_json",
			{
				"schema_version":
				"sporespore_balanced_wave_policy_profile_request_v1",
				"policy_id": POLICY_IDS[index],
				"descriptor": descriptor,
			},
		)
		var profile: Dictionary = envelope.get("value", {})
		var runtime_sha := CanonicalJsonScript.sha256(profile)
		var candidate := _candidate(index, runtime_sha)
		var candidate_sha := CanonicalJsonScript.sha256(candidate)
		print(
			"BW7D_DIGEST candidate=%s runtime=%s policy=%s"
			% [CANDIDATE_IDS[index], runtime_sha, candidate_sha]
		)
		runtime_digests_match = (
			runtime_digests_match
			and runtime_sha == EXPECTED_RUNTIME_PROFILE_SHA256[index]
		)
		candidate_digests_match = (
			candidate_digests_match
			and candidate_sha == EXPECTED_CANDIDATE_POLICY_SHA256[index]
			and String(
				registered_digests.get(String(CANDIDATE_IDS[index]), "")
			)
			== candidate_sha
		)
		manifest_candidates_exact = (
			manifest_candidates_exact
			and index < registered_candidates.size()
			and CanonicalJsonScript.sha256(registered_candidates[index])
			== candidate_sha
		)
		var expected_transform := String(EXPECTED_TRANSFORMS[index])
		var observed_transform := String(profile.get("steering_stride_transform_id", ""))
		var caps: Array = EXPECTED_RELEASE_CAPS[index]
		profiles_exact = (
			profiles_exact
			and bool(envelope.get("ok", false))
			and String(profile.get("schema_version", "")) == PROFILE_SCHEMA
			and String(profile.get("policy_id", "")) == String(POLICY_IDS[index])
			and float(profile.get("cross_track_heading_gain_rad_per_m", NAN)) == 1.0
			and float(
				profile.get(
					"cross_track_velocity_heading_gain_rad_per_m_s",
					NAN,
				)
			)
			== 0.35
			and float(profile.get("yaw_error_stride_gain_per_rad", NAN)) == 1.3
			and float(
				profile.get(
					"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s",
					NAN,
				)
			)
			== float(caps[0])
			and float(
				profile.get("anchor_error_guard_activation_fraction", NAN)
			)
			== float(caps[1])
			and float(
				profile.get(
					"anchor_error_guard_maximum_motor_target_speed_rad_s",
					NAN,
				)
			)
			== float(caps[2])
			and int(profile.get("steering_feedback_update_interval_steps", -1)) == 1
			and float(
				profile.get(
					"steering_low_pass_time_constant_cycle_fraction",
					NAN,
				)
			)
			== 0.0625
			and observed_transform == expected_transform
			and (profile.get("branch_surfaces", []) as Array).is_empty()
			and bool(profile.get("controller_authority", false))
			and not bool(profile.get("physical_acceptance_authority", true))
		)
	_check(profiles_exact, "all four native profiles implement the frozen 2x2 family")
	_check(runtime_digests_match, "all four native runtime profiles are hash-bound")
	_check(candidate_digests_match, "all four candidate records are hash-bound")
	_check(
		manifest_candidates_exact,
		"the preregistered candidate records exactly match the native identities",
	)

	var old_envelope := _call_input(
		api,
		"balanced_wave_policy_profile_json",
		{
			"schema_version": "sporespore_balanced_wave_policy_profile_request_v1",
			"policy_id": "sporespore_balanced_wave_bw5r_b_v1",
			"descriptor": descriptor,
		},
	)
	_check(
		bool(old_envelope.get("ok", false))
		and CanonicalJsonScript.sha256(old_envelope.get("value", {}))
		== "sha256:e02fa9c7599cffe8b331f7d8c10b6cc4dbffe7408e319169c09cbcb7d9b3890e",
		"the selected BW5R-B runtime profile remains byte-identical",
	)
	_finish()


func _candidate(index: int, runtime_sha: String) -> Dictionary:
	var caps: Array = EXPECTED_RELEASE_CAPS[index]
	var transform: Variant = null
	if not String(EXPECTED_TRANSFORMS[index]).is_empty():
		transform = String(EXPECTED_TRANSFORMS[index])
	return {
		"candidate_id": CANDIDATE_IDS[index],
		"policy_id": POLICY_IDS[index],
		"parent_policy_id": "sporespore_balanced_wave_bw5r_b_v1",
		"profile_schema_version": PROFILE_SCHEMA,
		"runtime_profile_sha256": runtime_sha,
		"release_factor": "moderate" if index % 2 == 0 else "full",
		"path_factor": "linear" if index < 2 else "reciprocal",
		"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s": caps[0],
		"anchor_error_guard_activation_fraction": caps[1],
		"anchor_error_guard_maximum_motor_target_speed_rad_s": caps[2],
		"steering_stride_transform_id": transform,
		"steering_low_pass_time_constant_cycle_fraction": 0.0625,
		"evidence_acquisition_policy_id": "bounded_all_support_acquisition_v1",
		"evidence_acquisition_maximum_ticks": 15,
		"evidence_acquisition_minimum_all_support_dwell_ticks": 3,
		"branch_surfaces": [],
	}


func _reference_descriptor() -> Dictionary:
	return {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": "bw7d_zero_world_reference",
		"torso_length_scale": 1.0,
		"torso_width_scale": 1.0,
		"upper_length_fraction": 18.0 / 35.0,
		"hip_span_scale": 1.0,
		"foot_radius_scale": 1.0,
		"front_limb_mass_scale": 1.0,
	}


func _call_input(api: Object, method: StringName, value: Dictionary) -> Dictionary:
	var response := String(api.call(method, JSON.stringify(value, "", true, true)))
	var parsed: Variant = JSON.parse_string(response)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print("SDK BW7D authority summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
