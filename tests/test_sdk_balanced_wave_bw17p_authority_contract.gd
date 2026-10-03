extends SceneTree
# gdlint: disable=max-line-length

## Zero-world contract for the BW17P portable-plan composition pair.
##
## This verifies the exact candidate digests, unchanged BW15F-B controller,
## frozen BW13P-A portable plan, and the two distinct production adapter
## configurations. It
## constructs no physics body and exposes no locomotion outcome.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")

const PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw17p_morphology_development_preregistration.json"
const CANDIDATES_PATH := "res://sdk/balanced_wave_bw17p_portable_plan_candidates.json"
const CANDIDATES_RAW_SHA256 := "sha256:8f8b44d63acdb58513320a629eedd6709889a4d9f28726c698b2c6f81f910605"
const CONTROLLER_POLICY_ID := "sporespore_balanced_wave_bw15f_b_v1"
const CONTROLLER_POLICY_DIGEST := "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
const CANDIDATE_IDS := ["BW17P-A", "BW17P-B"]
const COMPOSITION_DIGESTS := [
	"sha256:7093744b5fe5fcac36b59ba94741fc83b59e42c445d6b01b90711c5f71ba422e",
	"sha256:b25729d73a07007c5cb49d0fe522c3e9e574413ebb19167339091106ca5da212",
]
const STABILITY_POLICY_IDS := [
	"p5i3b_weight_support_shadow_v1",
	"sporespore_scheduled_load_transfer_bw13p_a_v3",
]
const AUTHORITY_SCOPES := ["post_settle_full", "post_settle_full"]
const EXECUTION_MODES := [
	"native_authority_with_legacy_observer",
	"native_balanced_wave_base_with_stability_contribution",
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
	"morphology_id": "bw17p_zero_world_reference",
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
	print("\n=== SDK BW17P zero-world authority contract ===")
	var preregistration := _read_json(PREREGISTRATION_PATH)
	var declarations := _read_json(CANDIDATES_PATH)
	_check(
		(
			(
				String(preregistration.get("schema_version", ""))
				== "sporespore_balanced_wave_bw17p_morphology_development_preregistration_v1"
			)
			and (
				String(preregistration.get("status", ""))
				== "frozen_before_first_bw17p_physics_world"
			)
			and String(preregistration.get("campaign_id", "")) == "BW17P-MORPHOLOGY-DEVELOPMENT"
			and String(preregistration.get("gate_id", "")) == "BW17P"
			and (preregistration.get("candidate_order", []) as Array) == CANDIDATE_IDS
		),
		"1 the prospective two-arm preregistration identity is exact",
	)
	_check(
		(
			(
				String(declarations.get("schema_version", ""))
				== "sporespore_balanced_wave_bw17p_portable_plan_candidates_v1"
			)
			and String(declarations.get("status", "")) == "frozen_before_first_bw17p_physics_world"
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
			and bool(candidate.get("portable_plan_enabled", index == 0)) == (index == 1)
			and (
				String(candidate.get("portable_plan_operation", ""))
				== ("plan_scheduled_load_transfer_v3_json" if index == 1 else "not_requested")
			)
			and (
				String(candidate.get("portable_plan_receipt_schema_version", ""))
				== ("sporespore_scheduled_load_transfer_receipt_v3" if index == 1 else "")
			)
			and bool(candidate.get("stability_contribution_authority", index == 0)) == (index == 1)
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
	var portable_plan: Dictionary = declarations.get("portable_plan_profile", {})
	_check(
		(
			(
				String(portable_plan.get("source_policy_id", ""))
				== "sporespore_scheduled_load_transfer_bw13p_a_v3"
			)
			and (
				String(portable_plan.get("source_freeze", ""))
				== "balanced_wave_bw13p_r3_complete_control_arm_v1"
			)
			and (
				String(portable_plan.get("plan_operation", ""))
				== "plan_scheduled_load_transfer_v3_json"
			)
			and (
				String(portable_plan.get("request_schema_version", ""))
				== "sporespore_scheduled_load_transfer_request_v3"
			)
			and (
				String(portable_plan.get("receipt_schema_version", ""))
				== "sporespore_scheduled_load_transfer_receipt_v3"
			)
			and String(portable_plan.get("mode", "")) == "control"
			and not bool(portable_plan.get("preferred_normal_force_factor", true))
			and not bool(portable_plan.get("remaining_support_centroid_factor", true))
			and bool(portable_plan.get("shared_baseline_centroidal_command", false))
			and bool(portable_plan.get("total_preferred_normal_force_conserved", false))
			and bool(portable_plan.get("activation_uses_scheduler_boundaries_only", false))
			and int(portable_plan.get("morphology_branch_surface_count", -1)) == 0
			and int(portable_plan.get("material_branch_surface_count", -1)) == 0
			and int(portable_plan.get("seed_branch_surface_count", -1)) == 0
			and int(portable_plan.get("failure_identity_branch_surface_count", -1)) == 0
			and int(portable_plan.get("outcome_branch_surface_count", -1)) == 0
			and int(portable_plan.get("new_tunable_gain_count", -1)) == 0
			and not bool(portable_plan.get("fit_to_qsdk_r05c_or_bw16s_outcomes", true))
		),
		"4 the pre-existing BW13P-A portable control plan is unchanged and untuned",
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
			and bool(treatment_plan.get("full_post_settle_authority_enabled", false))
			and not bool(treatment_plan.get("stability_contribution_overlay_enabled", true))
			and not bool(treatment_plan.get("fixed_exposure_enabled", true))
			and not bool(treatment_plan.get("legacy_base_motor_writes_allowed", true))
			and bool(
				(
					treatment_plan
					. get(
						"exclusive_native_post_settle_motor_writes_required",
						false,
					)
				)
			)
			and bool(
				(
					treatment_plan
					. get(
						"full_authority_stability_contribution_enabled",
						false,
					)
				)
			)
		),
		"7 candidate B resolves to full native authority plus portable contribution",
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
			and (
				String(treatment_feedback.get("portable_plan_operation", ""))
				== "plan_scheduled_load_transfer_v3_json"
			)
			and (
				String(treatment_feedback.get("portable_plan_schema_version", ""))
				== "sporespore_scheduled_load_transfer_receipt_v3"
			)
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
		"9 candidate B manifest exposes the portable plan and bounded contribution",
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
	print("\nSDK BW17P authority summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
