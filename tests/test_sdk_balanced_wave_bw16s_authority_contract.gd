extends SceneTree
# gdlint: disable=max-line-length

## Zero-world contract for the BW16S portable-balance composition pair.
##
## This verifies the exact candidate digests, unchanged BW15F-B controller,
## frozen P5I.3C gains, and the two distinct production adapter routes. It
## constructs no physics body and exposes no locomotion outcome.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")

const PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw16s_morphology_development_preregistration.json"
const CANDIDATES_PATH := "res://sdk/balanced_wave_bw16s_balance_composition_candidates.json"
const CANDIDATES_RAW_SHA256 := "sha256:0c42d2c90159980a695480a561b2fe519ddcc8b7b7cc65a2515257bfa24731ec"
const CONTROLLER_POLICY_ID := "sporespore_balanced_wave_bw15f_b_v1"
const CONTROLLER_POLICY_DIGEST := "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
const CANDIDATE_IDS := ["BW16S-A", "BW16S-B"]
const COMPOSITION_DIGESTS := [
	"sha256:5fdd2fae60409d31fb66c7152cecf7123e8cf410c56dd902a21ea90aad037bce",
	"sha256:e77f0ab9a8828a95c1c6d30003a381b5d4a8386a4ff49df270fcf31b86e0c94c",
]
const STABILITY_POLICY_IDS := [
	"p5i3b_weight_support_shadow_v1",
	"p5i3c_support_centroid_tilt_feedback_v1",
]
const AUTHORITY_SCOPES := ["post_settle_full", "stability_contribution_overlay"]
const EXECUTION_MODES := [
	"native_authority_with_legacy_observer",
	"portable_balanced_wave_base_with_stability_overlay",
]
const MATERIAL_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const SOLVER_POLICY_OPTIONS := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": 120,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "bw16s_zero_world_reference",
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 18.0 / 35.0,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK BW16S zero-world authority contract ===")
	var preregistration := _read_json(PREREGISTRATION_PATH)
	var declarations := _read_json(CANDIDATES_PATH)
	_check(
		(
			(
				String(preregistration.get("schema_version", ""))
				== "sporespore_balanced_wave_bw16s_morphology_development_preregistration_v1"
			)
			and (
				String(preregistration.get("status", ""))
				== "frozen_before_first_bw16s_physics_world"
			)
			and String(preregistration.get("campaign_id", "")) == "BW16S-MORPHOLOGY-DEVELOPMENT"
			and String(preregistration.get("gate_id", "")) == "BW16S"
			and (preregistration.get("candidate_order", []) as Array) == CANDIDATE_IDS
		),
		"1 the prospective two-arm preregistration identity is exact",
	)
	_check(
		(
			(
				String(declarations.get("schema_version", ""))
				== "sporespore_balanced_wave_bw16s_balance_composition_candidates_v1"
			)
			and String(declarations.get("status", "")) == "frozen_before_first_bw16s_physics_world"
			and (declarations.get("candidate_order", []) as Array) == CANDIDATE_IDS
			and _raw_sha256(CANDIDATES_PATH) == CANDIDATES_RAW_SHA256
			and (
				String(
					(
						(preregistration.get("candidate_declarations", {}) as Dictionary)
						. get(
							"raw_sha256",
							"",
						)
					)
				)
				== CANDIDATES_RAW_SHA256
			)
		),
		"2 the candidate declaration bytes and order are frozen",
	)
	var candidates: Array = declarations.get("candidates", [])
	var declaration_digests: Dictionary = (
		declarations
		. get(
			"candidate_composition_digests",
			{},
		)
	)
	var preregistration_digests: Dictionary = (
		preregistration
		. get(
			"candidate_composition_digests",
			{},
		)
	)
	var candidate_contract_exact := candidates.size() == 2
	for index in range(2):
		var candidate: Dictionary = candidates[index]
		candidate_contract_exact = (
			candidate_contract_exact
			and String(candidate.get("candidate_id", "")) == String(CANDIDATE_IDS[index])
			and String(candidate.get("controller_candidate_id", "")) == "BW15F-B"
			and String(candidate.get("controller_policy_id", "")) == CONTROLLER_POLICY_ID
			and String(candidate.get("controller_policy_digest", "")) == CONTROLLER_POLICY_DIGEST
			and (
				String(candidate.get("stability_policy_id", ""))
				== String(STABILITY_POLICY_IDS[index])
			)
			and bool(candidate.get("feedback_enabled", index == 0)) == (index == 1)
			and bool(candidate.get("physical_overlay_enabled", index == 0)) == (index == 1)
			and int(candidate.get("morphology_condition_count", -1)) == 0
			and int(candidate.get("material_condition_count", -1)) == 0
			and int(candidate.get("seed_condition_count", -1)) == 0
			and int(candidate.get("failure_identity_condition_count", -1)) == 0
			and int(candidate.get("outcome_condition_count", -1)) == 0
			and (candidate.get("branch_surfaces", []) as Array).is_empty()
			and not bool(candidate.get("physical_acceptance_authority", true))
			and (
				String(declaration_digests.get(CANDIDATE_IDS[index], ""))
				== String(COMPOSITION_DIGESTS[index])
			)
			and (
				String(preregistration_digests.get(CANDIDATE_IDS[index], ""))
				== String(COMPOSITION_DIGESTS[index])
			)
			and CanonicalJsonScript.sha256(candidate) == String(COMPOSITION_DIGESTS[index])
		)
	_check(candidate_contract_exact, "3 both branch-free candidate digests recompute exactly")
	var feedback_profile: Dictionary = declarations.get("feedback_profile", {})
	_check(
		(
			(
				String(feedback_profile.get("source_policy_id", ""))
				== "p5i3c_support_centroid_tilt_feedback_v1"
			)
			and is_equal_approx(
				float(feedback_profile.get("horizontal_position_gain_n_per_m", NAN)),
				5.0,
			)
			and is_equal_approx(
				float(feedback_profile.get("horizontal_velocity_gain_ns_per_m", NAN)),
				0.1,
			)
			and is_equal_approx(
				float(feedback_profile.get("maximum_horizontal_force_n", NAN)),
				0.75,
			)
			and is_zero_approx(float(feedback_profile.get("vertical_position_gain_n_per_m", NAN)))
			and is_zero_approx(float(feedback_profile.get("vertical_velocity_gain_ns_per_m", NAN)))
			and is_zero_approx(float(feedback_profile.get("maximum_vertical_correction_n", NAN)))
			and is_equal_approx(
				float(feedback_profile.get("roll_position_gain_nm_per_rad", NAN)),
				0.5,
			)
			and is_equal_approx(
				float(feedback_profile.get("roll_velocity_gain_nm_s_per_rad", NAN)),
				0.05,
			)
			and is_equal_approx(
				float(feedback_profile.get("pitch_position_gain_nm_per_rad", NAN)),
				0.5,
			)
			and is_equal_approx(
				float(feedback_profile.get("pitch_velocity_gain_nm_s_per_rad", NAN)),
				0.05,
			)
			and is_equal_approx(
				float(feedback_profile.get("maximum_roll_pitch_moment_nm", NAN)),
				0.1,
			)
			and int(feedback_profile.get("new_tunable_gain_count", -1)) == 0
			and not bool(feedback_profile.get("fit_to_qsdk_r05c_outcomes", true))
		),
		"4 the pre-existing P5I.3C dimensional gains are unchanged and untuned",
	)
	var material_result := MaterialProfilesScript.resolve(MATERIAL_PROFILE_ID)
	_check(
		(
			bool(material_result.get("ok", false))
			and (
				String(
					(
						(material_result.get("profile", {}) as Dictionary)
						. get(
							"profile_id",
							"",
						)
					)
				)
				== MATERIAL_PROFILE_ID
			)
		),
		"5 the held material profile resolves without a world",
	)
	if not bool(material_result.get("ok", false)):
		_finish()
		return
	var material_profile: Dictionary = material_result["profile"]
	var root_children_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var starts: Array[Dictionary] = []
	var boundaries: Array[Dictionary] = []
	var plans: Array[Dictionary] = []
	for index in range(2):
		var plan := (
			WaveGaitScript
			. compile_sdk_execution_mode_plan(
				true,
				true,
				String(AUTHORITY_SCOPES[index]),
				String(STABILITY_POLICY_IDS[index]),
				-3,
			)
		)
		plans.append(plan)
		var adapter: RefCounted = AdapterScript.new()
		var start: Dictionary = (
			adapter
			. start(
				DESCRIPTOR,
				plan.get("zero_base_initial_gait_steps", {}) as Dictionary,
				0.0,
				Vector3.ZERO,
				Vector3.BACK,
				0.0,
				120,
				SOLVER_POLICY_OPTIONS,
				2.5e-7,
				"clocked",
				true,
				-3,
				360,
				String(AUTHORITY_SCOPES[index]),
				String(STABILITY_POLICY_IDS[index]),
				material_profile,
				CONTROLLER_POLICY_ID,
			)
		)
		starts.append(start)
		boundaries.append(
			(
				adapter.preflight_perfect_declared_policy_runtime_boundary()
				if bool(start.get("ok", false))
				else {}
			)
		)
	var control_plan: Dictionary = plans[0]
	var treatment_plan: Dictionary = plans[1]
	_check(
		(
			bool(control_plan.get("ok", false))
			and bool(control_plan.get("full_post_settle_authority_enabled", false))
			and not bool(control_plan.get("stability_contribution_overlay_enabled", true))
			and not bool(control_plan.get("fixed_exposure_enabled", true))
			and not bool(control_plan.get("legacy_base_motor_writes_allowed", true))
			and bool(
				(
					control_plan
					. get(
						"exclusive_native_post_settle_motor_writes_required",
						false,
					)
				)
			)
		),
		"6 candidate A resolves to exclusive post-settle native authority",
	)
	_check(
		(
			bool(treatment_plan.get("ok", false))
			and not bool(treatment_plan.get("full_post_settle_authority_enabled", true))
			and bool(treatment_plan.get("stability_contribution_overlay_enabled", false))
			and bool(treatment_plan.get("fixed_exposure_enabled", false))
			and bool(treatment_plan.get("legacy_base_motor_writes_allowed", false))
			and not bool(
				(
					treatment_plan
					. get(
						"exclusive_native_post_settle_motor_writes_required",
						true,
					)
				)
			)
		),
		"7 candidate B resolves to the declared counted overlay route",
	)
	var control_manifest: Dictionary = starts[0].get("adapter_manifest", {})
	var treatment_manifest: Dictionary = starts[1].get("adapter_manifest", {})
	var control_stability: Dictionary = control_manifest.get("stability_v3", {})
	var treatment_stability: Dictionary = treatment_manifest.get("stability_v3", {})
	var control_feedback: Dictionary = control_stability.get("feedback_policy", {})
	var treatment_feedback: Dictionary = treatment_stability.get("feedback_policy", {})
	var control_overlay: Dictionary = control_stability.get("physical_overlay", {})
	var treatment_overlay: Dictionary = treatment_stability.get("physical_overlay", {})
	_check(
		(
			bool(starts[0].get("ok", false))
			and String(starts[0].get("controller_policy_id", "")) == CONTROLLER_POLICY_ID
			and String(starts[0].get("authority_scope", "")) == String(AUTHORITY_SCOPES[0])
			and String(starts[0].get("stability_policy_id", "")) == String(STABILITY_POLICY_IDS[0])
			and String(control_manifest.get("execution_mode", "")) == String(EXECUTION_MODES[0])
			and not bool(control_feedback.get("enabled", true))
			and not bool(control_overlay.get("enabled", true))
		),
		"8 candidate A adapter manifest keeps feedback and overlay disabled",
	)
	_check(
		(
			bool(starts[1].get("ok", false))
			and String(starts[1].get("controller_policy_id", "")) == CONTROLLER_POLICY_ID
			and String(starts[1].get("authority_scope", "")) == String(AUTHORITY_SCOPES[1])
			and String(starts[1].get("stability_policy_id", "")) == String(STABILITY_POLICY_IDS[1])
			and String(treatment_manifest.get("execution_mode", "")) == String(EXECUTION_MODES[1])
			and bool(treatment_feedback.get("enabled", false))
			and bool(treatment_overlay.get("enabled", false))
			and (
				String(treatment_overlay.get("base_command", ""))
				== "portable_balanced_wave_ordered_command"
			)
			and (
				String(treatment_overlay.get("operation", ""))
				== "bounded_host_delta_add_then_existing_speed_limit"
			)
			and not bool(treatment_overlay.get("body_state_write_authority", true))
		),
		"9 candidate B adapter manifest composes the portable base and frozen feedback",
	)
	var boundaries_exact := boundaries.size() == 2
	for index in range(boundaries.size()):
		var boundary: Dictionary = boundaries[index]
		boundaries_exact = (
			boundaries_exact
			and bool(boundary.get("ok", false))
			and String(boundary.get("controller_policy_id", "")) == CONTROLLER_POLICY_ID
			and (
				String(boundary.get("stability_policy_id", ""))
				== String(STABILITY_POLICY_IDS[index])
			)
			and int(boundary.get("requested_phase_offset_ticks", 99)) == -3
			and int(boundary.get("actual_world_build_count", -1)) == 0
			and int(boundary.get("scene_tree_insertion_count", -1)) == 0
			and not bool(boundary.get("physics_state_modified", true))
			and not bool(boundary.get("locomotion_outcome_exposed", true))
			and not bool(boundary.get("physical_acceptance_authority", true))
		)
	_check(
		(
			boundaries_exact
			and root.get_child_count() == root_children_before
			and Engine.physics_ticks_per_second == physics_hz_before
		),
		"10 both real runtime boundaries pass without a world or physics mutation",
	)
	_finish()


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _raw_sha256(resource_path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(resource_path))
	if bytes.is_empty():
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		return ""
	return "sha256:" + context.finish().hex_encode()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print("\nSDK BW16S authority summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
