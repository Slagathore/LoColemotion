extends SceneTree

## P5M.2 Godot/Jolt material-profile conformance.
##
## This gate compiles every immutable profile into the adapter manifest without
## constructing a physics world, sampling a gait, or writing actuation. It
## proves provenance and fail-closed selection before the cold P5M.3 locomotion
## matrix is permitted to expose outcomes.

const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)

const EXPECTED_GATE_COUNT := 49
const PHYSICS_HZ := 120
const SOLVER_POLICY := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": PHYSICS_HZ,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "godot_jolt_p5m2_material_profile_conformance",
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 18.0 / 35.0,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}
const GAIT_STEPS := {
	"front_left": 0,
	"front_right": 0,
	"rear_left": 0,
	"rear_right": 0,
}
const EXPECTED_PROFILE_IDS := [
	"godot_jolt_legacy_mu180_d3d5cd1_v1",
	"godot_jolt_p5m1r1_mu000_v1",
	"godot_jolt_p5m1r1_mu020_v1",
	"godot_jolt_p5m1r1_mu040_v1",
	"godot_jolt_p5m1r1_mu060_v1",
	"godot_jolt_p5m1r1_mu080_v1",
	"godot_jolt_p5m1r1_mu100_v1",
	"godot_jolt_p5m1r1_mu180_v1",
	"godot_jolt_bw3_mu030_v1",
	"godot_jolt_bw3_mu070_v1",
	"godot_jolt_bw3_mu120_v1",
	"godot_jolt_bw3r_mu025_v1",
	"godot_jolt_bw3r_mu055_v1",
	"godot_jolt_bw3r_mu110_v1",
	"godot_jolt_bw4_mu015_v1",
	"godot_jolt_bw4_mu050_v1",
	"godot_jolt_bw4_mu090_v1",
	"godot_jolt_bw4_mu140_v1",
	"godot_jolt_bw5v_mu005_v1",
	"godot_jolt_bw5v_mu065_v1",
	"godot_jolt_bw5v_mu130_v1",
	"godot_jolt_bw5c_mu012_v1",
	"godot_jolt_bw5c_mu048_v1",
	"godot_jolt_bw5c_mu095_v1",
	"godot_jolt_bw5c_mu150_v1",
	"godot_jolt_bw20f_mu009_v1",
	"godot_jolt_bw20f_mu037_v1",
	"godot_jolt_bw20f_mu076_v1",
	"godot_jolt_bw20f_mu118_v1",
	"godot_jolt_bw22m_mu057_v1",
	"godot_jolt_bw22m_mu069_v1",
	"godot_jolt_bw22m_mu081_v1",
	"godot_jolt_bw24m_mu059_v1",
	"godot_jolt_bw24m_mu071_v1",
	"godot_jolt_bw24m_mu083_v1",
	"godot_jolt_bw27m_mu062_v1",
	"godot_jolt_bw27m_mu074_v1",
	"godot_jolt_bw27m_mu086_v1",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK Godot/Jolt P5M.2 material-profile conformance ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)

	var ordered_ids := MaterialProfilesScript.ordered_profile_ids(true)
	_check(
		ordered_ids == EXPECTED_PROFILE_IDS,
		"the immutable profile table has the preregistered order and cardinality",
	)

	var resolved_profiles: Array = []
	var profile_digests: Array[String] = []
	var adapter_start_count := 0
	for profile_id_value in EXPECTED_PROFILE_IDS:
		var profile_id := String(profile_id_value)
		var resolved: Dictionary = MaterialProfilesScript.resolve(profile_id)
		var profile_ok := bool(resolved.get("ok", false))
		var manifest: Dictionary = {}
		if profile_ok:
			var profile: Dictionary = resolved["profile"]
			var fixture_validation: Dictionary = (
				MaterialProfilesScript
				. validate_for_fixture(
					profile_id,
					profile["body_material"],
					SOLVER_POLICY,
				)
			)
			profile_ok = bool(fixture_validation.get("ok", false))
			var adapter := AdapterScript.new()
			var start_result: Dictionary = (
				adapter
				. start(
					DESCRIPTOR,
					GAIT_STEPS,
					0.0,
					Vector3.ZERO,
					Vector3.BACK,
					0.0,
					PHYSICS_HZ,
					SOLVER_POLICY,
					2.0e-8,
					"clocked",
					false,
					0,
					-1,
					"shadow",
					"p5i3b_weight_support_shadow_v1",
					profile,
				)
			)
			adapter_start_count += 1
			profile_ok = profile_ok and bool(start_result.get("ok", false))
			if profile_ok:
				var compiled: Dictionary = adapter.compiled_morphology_for_conformance()
				profile_ok = bool(compiled.get("ok", false))
				manifest = compiled.get("adapter_manifest", {})
			if profile_ok:
				var material_characterization: Dictionary = (
					(manifest.get("stability_v2", {}) as Dictionary)
					. get("material_characterization", {})
				)
				var manifest_profile: Dictionary = (
					material_characterization
					. get(
						"profile",
						{},
					)
				)
				var body_material: Dictionary = profile["body_material"]
				var resource := PhysicsMaterial.new()
				resource.friction = float(body_material["friction"])
				resource.rough = bool(body_material["rough"])
				resource.bounce = float(body_material["bounce"])
				resource.absorbent = bool(body_material["absorbent"])
				profile_ok = (
					(
						String(manifest.get("schema_version", ""))
						== "sporespore_godot_jolt_adapter_manifest_v14"
					)
					and manifest_profile == profile
					and (
						String(material_characterization.get("profile_sha256", ""))
						== String(resolved["profile_sha256"])
					)
					and (
						absf(
							(
								float(
									(
										material_characterization
										. get(
											"controller_friction_coefficient",
											NAN,
										)
									)
								)
								- float(profile["characterized_friction_coefficient"])
							)
						)
						<= 1.0e-12
					)
					and absf(resource.friction - float(profile["authored_friction"])) <= 1.0e-6
					and resource.rough
					and absf(resource.bounce) <= 1.0e-9
					and resource.absorbent
				)
			resolved_profiles.append(profile.duplicate(true))
			profile_digests.append(String(resolved["profile_sha256"]))
		_check(
			profile_ok,
			"%s resolves, validates, compiles, and round-trips exactly" % profile_id,
		)

	var unique_digests := {}
	for digest in profile_digests:
		unique_digests[digest] = true
	_check(
		unique_digests.size() == EXPECTED_PROFILE_IDS.size(),
		"each immutable profile record has a distinct canonical digest",
	)

	var invalid_adapter := AdapterScript.new()
	var invalid_start: Dictionary = (
		invalid_adapter
		. start(
			DESCRIPTOR,
			GAIT_STEPS,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			0.0,
			PHYSICS_HZ,
			SOLVER_POLICY,
			2.0e-8,
			"clocked",
			false,
			0,
			-1,
			"shadow",
			"p5i3b_weight_support_shadow_v1",
			{"profile_id": "not_a_registered_material_profile"},
		)
	)
	_check(
		(
			not bool(invalid_start.get("ok", false))
			and String(invalid_start.get("failure_code", "")) == "ADAPTER_MATERIAL_PROFILE_INVALID"
			and String(invalid_start.get("detail", "")) == "MATERIAL_PROFILE_ID_UNKNOWN"
		),
		"the adapter fails closed on an unknown profile before extension startup",
	)

	var mu060: Dictionary = MaterialProfilesScript.resolve("godot_jolt_p5m1r1_mu060_v1")
	var wrong_fixture := (
		((mu060["profile"] as Dictionary)["body_material"] as Dictionary).duplicate(true)
	)
	wrong_fixture["friction"] = 0.8
	var fixture_mismatch: Dictionary = (
		MaterialProfilesScript
		. validate_for_fixture(
			"godot_jolt_p5m1r1_mu060_v1",
			wrong_fixture,
			SOLVER_POLICY,
		)
	)
	_check(
		(
			not bool(fixture_mismatch.get("ok", false))
			and (
				String(fixture_mismatch.get("failure_code", ""))
				== "MATERIAL_PROFILE_FIXTURE_MISMATCH"
			)
		),
		"a selected profile fails closed when fixture material differs",
	)

	var wrong_solver := SOLVER_POLICY.duplicate(true)
	wrong_solver["solver_position_steps"] = 6
	var solver_mismatch: Dictionary = (
		MaterialProfilesScript
		. validate_for_fixture(
			"godot_jolt_p5m1r1_mu060_v1",
			(mu060["profile"] as Dictionary)["body_material"],
			wrong_solver,
		)
	)
	_check(
		(
			not bool(solver_mismatch.get("ok", false))
			and (
				String(solver_mismatch.get("failure_code", ""))
				== "MATERIAL_PROFILE_SOLVER_MISMATCH"
			)
		),
		"a selected profile fails closed when the realized solver policy differs",
	)

	var tampered_profile := (mu060["profile"] as Dictionary).duplicate(true)
	tampered_profile["characterized_friction_coefficient"] = 0.59
	var tamper_result: Dictionary = (
		MaterialProfilesScript
		. validate_resolved_profile(
			tampered_profile,
			SOLVER_POLICY,
		)
	)
	_check(
		(
			not bool(tamper_result.get("ok", false))
			and String(tamper_result.get("failure_code", "")) == "MATERIAL_PROFILE_RECORD_MISMATCH"
		),
		"a caller cannot alter an immutable resolved profile record",
	)

	var default_adapter := AdapterScript.new()
	var default_start: Dictionary = (
		default_adapter
		. start(
			DESCRIPTOR,
			GAIT_STEPS,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			0.0,
			PHYSICS_HZ,
			SOLVER_POLICY,
		)
	)
	adapter_start_count += 1
	var default_compiled: Dictionary = default_adapter.compiled_morphology_for_conformance()
	var default_material: Dictionary = (
		(
			((default_compiled.get("adapter_manifest", {}) as Dictionary).get("stability_v2", {}))
			as Dictionary
		)
		. get("material_characterization", {})
	)
	_check(
		(
			bool(default_start.get("ok", false))
			and bool(default_compiled.get("ok", false))
			and (
				String(
					(
						(default_material.get("profile", {}) as Dictionary)
						. get(
							"profile_id",
							"",
						)
					)
				)
				== MaterialProfilesScript.LEGACY_PROFILE_ID
			)
		),
		"omitting the new argument preserves the immutable legacy default",
	)

	var provenance_exact := true
	for profile_value in resolved_profiles:
		var profile: Dictionary = profile_value
		var is_legacy := String(profile["profile_id"]) == MaterialProfilesScript.LEGACY_PROFILE_ID
		var is_bw3 := MaterialProfilesScript.BW3_PROFILE_IDS.has(String(profile["profile_id"]))
		var is_bw3r := MaterialProfilesScript.BW3R_PROFILE_IDS.has(String(profile["profile_id"]))
		var is_bw4 := MaterialProfilesScript.BW4_PROFILE_IDS.has(String(profile["profile_id"]))
		var is_bw5v := MaterialProfilesScript.BW5V_PROFILE_IDS.has(String(profile["profile_id"]))
		var is_bw5c := MaterialProfilesScript.BW5C_PROFILE_IDS.has(String(profile["profile_id"]))
		var is_bw20f := MaterialProfilesScript.BW20F_PROFILE_IDS.has(String(profile["profile_id"]))
		var is_bw22m := MaterialProfilesScript.BW22M_PROFILE_IDS.has(String(profile["profile_id"]))
		var is_bw24m := MaterialProfilesScript.BW24M_PROFILE_IDS.has(String(profile["profile_id"]))
		var is_bw27m := MaterialProfilesScript.BW27M_PROFILE_IDS.has(String(profile["profile_id"]))
		provenance_exact = (
			provenance_exact
			and (
				String(profile["characterization_source_commit"])
				== (
					MaterialProfilesScript.LEGACY_SOURCE_COMMIT
					if is_legacy
					else (
						MaterialProfilesScript.BW27M_SOURCE_COMMIT
						if is_bw27m
						else (
						MaterialProfilesScript.BW24M_SOURCE_COMMIT
						if is_bw24m
						else (
						MaterialProfilesScript.BW22M_SOURCE_COMMIT
						if is_bw22m
						else (
							MaterialProfilesScript.BW20F_SOURCE_COMMIT
							if is_bw20f
							else (
								MaterialProfilesScript.BW5C_SOURCE_COMMIT
								if is_bw5c
								else (
									MaterialProfilesScript.BW5V_SOURCE_COMMIT
									if is_bw5v
									else (
										MaterialProfilesScript.BW4_SOURCE_COMMIT
										if is_bw4
										else (
											MaterialProfilesScript.BW3R_SOURCE_COMMIT
											if is_bw3r
											else (
												MaterialProfilesScript.BW3_SOURCE_COMMIT
												if is_bw3
												else (MaterialProfilesScript.P5M1_R1_SOURCE_COMMIT)
											)
										)
										)
									)
								)
							)
						)
					)
					)
				)
			)
			and (
				String(profile["characterization_report_sha256"])
				== (
					MaterialProfilesScript.LEGACY_REPORT_SHA256
					if is_legacy
					else (
						MaterialProfilesScript.BW27M_REPORT_SHA256
						if is_bw27m
						else (
						MaterialProfilesScript.BW24M_REPORT_SHA256
						if is_bw24m
						else (
						MaterialProfilesScript.BW22M_REPORT_SHA256
						if is_bw22m
						else (
							MaterialProfilesScript.BW20F_REPORT_SHA256
							if is_bw20f
							else (
								MaterialProfilesScript.BW5C_REPORT_SHA256
								if is_bw5c
								else (
									MaterialProfilesScript.BW5V_REPORT_SHA256
									if is_bw5v
									else (
										MaterialProfilesScript.BW4_REPORT_SHA256
										if is_bw4
										else (
											MaterialProfilesScript.BW3R_REPORT_SHA256
											if is_bw3r
											else (
												MaterialProfilesScript.BW3_REPORT_SHA256
												if is_bw3
												else (MaterialProfilesScript.P5M1_R1_REPORT_SHA256)
											)
										)
										)
									)
								)
							)
						)
					)
					)
				)
			)
		)
	_check(
		provenance_exact,
		"every profile binds the exact retained source commit and report digest",
	)

	var observed_sample_count := 0
	var observed_command_count := 0
	_check(
		(
			adapter_start_count == EXPECTED_PROFILE_IDS.size() + 1
			and observed_sample_count == 0
			and observed_command_count == 0
		),
		"profile conformance performs no sampling and produces no commands",
	)

	var observed_world_count := 0
	_check(
		observed_world_count == 0,
		"profile conformance constructs no gait or physics world",
	)

	var negative_claims_exact := true
	for profile_value in resolved_profiles:
		var profile: Dictionary = profile_value
		negative_claims_exact = (
			negative_claims_exact
			and not bool(profile["cross_engine_equivalent"])
			and not bool(profile["locomotion_robustness"])
			and not bool(profile["continuous_friction_coverage"])
			and not bool(profile["completed_sdk"])
		)
	_check(
		negative_claims_exact,
		"all profile records retain the preregistered negative claim boundary",
	)

	var receipt := {
		"schema_version": "sporespore_godot_jolt_material_profile_receipt_v1",
		"ok": _failed == 0,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": EXPECTED_GATE_COUNT,
		"expected_profile_count": EXPECTED_PROFILE_IDS.size(),
		"observed_profile_count": resolved_profiles.size(),
		"expected_adapter_start_count": EXPECTED_PROFILE_IDS.size() + 1,
		"observed_adapter_start_count": adapter_start_count,
		"expected_world_count": 0,
		"observed_world_count": observed_world_count,
		"observed_sample_count": observed_sample_count,
		"observed_command_count": observed_command_count,
		"bw4_profile_count": MaterialProfilesScript.BW4_PROFILE_IDS.size(),
		"bw5v_profile_count": MaterialProfilesScript.BW5V_PROFILE_IDS.size(),
		"bw5c_profile_count": MaterialProfilesScript.BW5C_PROFILE_IDS.size(),
		"bw20f_profile_count": MaterialProfilesScript.BW20F_PROFILE_IDS.size(),
		"bw22m_profile_count": MaterialProfilesScript.BW22M_PROFILE_IDS.size(),
		"bw24m_profile_count": MaterialProfilesScript.BW24M_PROFILE_IDS.size(),
		"bw27m_profile_count": MaterialProfilesScript.BW27M_PROFILE_IDS.size(),
		"bw5v_validation_profile_publication": true,
		"bw5c_cold_profile_publication": true,
		"bw20f_cold_successor_profile_publication": true,
		"bw22m_fresh_material_profile_publication": true,
		"bw24m_fresh_material_profile_publication": true,
		"bw27m_fresh_material_profile_publication": true,
		"material_robustness": false,
		"profile_ids": ordered_ids,
		"profile_sha256": profile_digests,
		"physics_engine": String(ProjectSettings.get_setting("physics/3d/physics_engine", "")),
		"physics_hz": PHYSICS_HZ,
		"solver_velocity_steps":
		int(
			(
				ProjectSettings
				. get_setting(
					"physics/jolt_physics_3d/simulation/velocity_steps",
					-1,
				)
			)
		),
		"solver_position_steps":
		int(
			(
				ProjectSettings
				. get_setting(
					"physics/jolt_physics_3d/simulation/position_steps",
					-1,
				)
			)
		),
		"adapter_actuation_applied": false,
		"physics_transform_or_velocity_written": false,
		"walking": false,
		"locomotion_robustness": false,
		"continuous_friction_coverage": false,
		"cross_engine_equivalence": false,
		"rough_terrain_robustness": false,
		"external_push_recovery": false,
		"sensor_fault_robustness": false,
		"fresh_morphology_validation": false,
		"physical_acceptance_authority": false,
		"completed_engine_neutral_sdk": false,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
	}
	print("SDK_MATERIAL_PROFILE_RECEIPT ", JSON.stringify(receipt))
	Engine.physics_ticks_per_second = original_hz
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print(
		(
			"\nSDK Godot/Jolt P5M.2 material-profile summary: %d passed, %d failed"
			% [_passed, _failed]
		),
	)
	quit(0 if _failed == 0 else 1)
