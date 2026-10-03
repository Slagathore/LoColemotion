extends SceneTree
# gdlint: disable=max-line-length

## BR14A.6 exact deterministic development test for the physical quadruped
## wave-gait candidate. This establishes one pinned walking observation. It
## deliberately does not authorize formal milestone acceptance, automatic
## creature guidance, or accepted-knowledge admission.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")

const EXPECTED_CYCLES := {
	"front_left": 2,
	"front_right": 3,
	"rear_left": 3,
	"rear_right": 3,
}
const EXPECTED_MINIMUM_RELOCATION_M := {
	"front_left": 0.02841943502426,
	"front_right": 0.01479953527451,
	"rear_left": 0.02382552623749,
	"rear_right": 0.01807941496372,
}
const EXPECTED_EVIDENCE_DISPLACEMENT_M := Vector3(0.849883, -0.001190, 0.067920)
const EXPECTED_FINAL_DISPLACEMENT_M := Vector3(1.042311, 0.010201, 0.088408)
const EXPECTED_REFERENCE_FIXTURE_DIGEST := "sha256:18361994a68e2a9a150aa539aff39679ba4b6e892092e26d218b08f6e12e9c3b"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Experimental BR14A.6 physical quadruped wave gait ===")
	var solver_velocity_steps := int(
		ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/velocity_steps", -1)
	)
	var solver_position_steps := int(
		ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/position_steps", -1)
	)
	if solver_velocity_steps != 20 or solver_position_steps != 6:
		print(
			(
				(
					"  ISOLATED_VARIANT_REQUIRED velocity_steps=%d position_steps=%d "
					+ "required=20/6"
				)
				% [solver_velocity_steps, solver_position_steps]
			)
		)
		_check(
			(
				(
					String(ProjectSettings.get_setting("physics/3d/physics_engine", ""))
					== "Jolt Physics"
				)
				and solver_velocity_steps == 20
				and solver_position_steps == 4
			),
			"repository-wide solver-4 regression refuses to impersonate the isolated solver-6 variant",
		)
		_finish()
		return
	var summary := await WaveGaitScript.new().run(self)
	_check(
		(
			bool(summary.get("ok", false))
			and bool(summary.get("physical_wave_gait_walking_observed", false))
		),
		"pinned development candidate establishes the full walking predicate",
	)
	_check(
		(
			String(summary.get("schema_version", ""))
			== "physical_wave_gait_quadruped_development_summary_v1"
		),
		"development summary schema is exact",
	)
	_check(
		(
			String(summary.get("physics_engine", "")) == "Jolt Physics"
			and int(summary.get("physics_hz", 0)) == 120
			and int(summary.get("solver_velocity_steps", 0)) == 20
			and int(summary.get("solver_position_steps", 0)) == 6
		),
		"physics engine, frequency, and solver iteration settings are pinned",
	)
	_check(
		(
			int(summary.get("executed_ticks", 0)) == 2392
			and int(summary.get("evidence_start_tick", 0)) == 712
			and int(summary.get("evidence_end_tick", 0)) == 1792
		),
		"continuous world completes the exact warmup, evidence, cooldown, and recovery horizon",
	)
	_check(
		(
			int(summary.get("world_build_count", 0)) == 1
			and int(summary.get("world_reset_count", -1)) == 0
			and int(summary.get("body_count", 0)) == 9
			and int(summary.get("limb_count", 0)) == 4
			and (
				String(summary.get("fixture_spec_sha256", "")) == EXPECTED_REFERENCE_FIXTURE_DIGEST
			)
			and (
				String((summary.get("fixture_spec", {}) as Dictionary).get("schema_version", ""))
				== "sporespore_physical_quadruped_fixture_spec_v1"
			)
			and (
				String(
					(summary.get("controller_configuration", {}) as Dictionary).get(
						"schema_version", ""
					)
				)
				== "sporespore_physical_wave_gait_controller_configuration_v1"
			)
			and String(summary.get("controller_configuration_sha256", "")).begins_with("sha256:")
			and String(summary.get("controller_configuration_sha256", "")).length() == 71
		),
		"one unreset world retains the exact digested nine-body four-limb fixture and controller",
	)
	_check(
		(
			int(summary.get("direct_torso_force_command_count", -1)) == 0
			and int(summary.get("direct_torso_impulse_command_count", -1)) == 0
			and int(summary.get("direct_torso_velocity_command_count", -1)) == 0
			and int(summary.get("direct_torso_transform_command_count", -1)) == 0
			and int(summary.get("motor_command_count", 0)) == 19136
		),
		"only the eight hinge motors provide locomotor authority",
	)
	var callback_counts: Dictionary = summary.get("contact_observer_callback_count_by_limb", {})
	var callbacks_exact := callback_counts.size() == 4
	for limb_id in EXPECTED_CYCLES:
		callbacks_exact = callbacks_exact and int(callback_counts.get(limb_id, 0)) == 2393
	_check(
		callbacks_exact,
		"every direct-state foot contact observer executes on every physics receipt"
	)
	_check(
		summary.get("contact_cycle_count_by_limb", {}) == EXPECTED_CYCLES,
		"all four limbs repeat exact accepted release-recontact cycles",
	)
	var rejected_cycles: Dictionary = summary.get("rejected_short_contact_cycle_count_by_limb", {})
	var zero_rejected_cycles := rejected_cycles.size() == 4
	for limb_id in EXPECTED_CYCLES:
		zero_rejected_cycles = zero_rejected_cycles and int(rejected_cycles.get(limb_id, -1)) == 0
	_check(zero_rejected_cycles, "no short or non-relocating contact cycle is promoted")
	var minimum_relocation: Dictionary = summary.get("minimum_cycle_relocation_by_limb_m", {})
	var exact_relocations := minimum_relocation.size() == 4
	for limb_id in EXPECTED_MINIMUM_RELOCATION_M:
		exact_relocations = (
			exact_relocations
			and _near(minimum_relocation.get(limb_id, NAN), EXPECTED_MINIMUM_RELOCATION_M[limb_id])
		)
	_check(exact_relocations, "every limb matches its exact minimum forward relocation witness")
	_check(
		_vector_near(
			summary.get("evidence_torso_displacement_world_m", Vector3(INF, INF, INF)),
			EXPECTED_EVIDENCE_DISPLACEMENT_M
		),
		"three-cycle evidence displacement matches the pinned forward witness",
	)
	_check(
		_vector_near(
			summary.get("final_torso_displacement_world_m", Vector3(INF, INF, INF)),
			EXPECTED_FINAL_DISPLACEMENT_M
		),
		"final recovered displacement matches the pinned forward and lateral witness",
	)
	_check(
		(
			_near(summary.get("minimum_torso_height_m", NAN), 0.427514)
			and _near(summary.get("final_torso_height_m", NAN), 0.439622)
			and _near(summary.get("maximum_tilt_rad", NAN), 0.136237)
			and _near(summary.get("final_yaw_drift_rad", NAN), 0.160445)
		),
		"height, tilt, and yaw remain inside the exact bounded motion envelope",
	)
	_check(
		(
			_near(summary.get("maximum_anchor_error_m", NAN), 0.022944)
			and _near(summary.get("maximum_hinge_axis_error_rad", NAN), 0.096369)
		),
		"joint anchors and hinge axes retain exact structural bounds",
	)
	_check(
		(
			bool(summary.get("initial_all_four_contacts", false))
			and bool(summary.get("evidence_all_four_contacts_at_start", false))
			and bool(summary.get("terminal_all_four_contacts", false))
			and int(summary.get("torso_contact_ticks", -1)) == 0
		),
		"the run starts, measures, and recovers on four feet without torso contact",
	)
	var gates: Dictionary = summary.get("walking_gate_receipts", {})
	var every_gate_true := not gates.is_empty()
	for gate_value in gates.values():
		every_gate_true = every_gate_true and bool(gate_value)
	_check(every_gate_true, "every named development walking gate is independently true")
	_check(
		(
			not bool(summary.get("formal_milestone_acceptance_authorized", true))
			and not bool(summary.get("encyclopedia_admission_authorized", true))
			and not bool(summary.get("automatic_creature_guidance_allowed", true))
		),
		"single deterministic walking evidence cannot self-promote into trusted knowledge",
	)
	var invalid_alignment := await WaveGaitScript.new().run(
		self, -1.0, 10.0, 1.75, "lateral", 72, 0.40, "all", 360
	)
	_check(
		(
			not bool(invalid_alignment.get("ok", true))
			and (
				String(invalid_alignment.get("failure_code", ""))
				== "INVALID_EVIDENCE_BOUNDARY_ALIGNMENT_TICKS"
			)
		),
		"out-of-cycle evidence alignment fails closed",
	)
	var invalid_assist_limb := await WaveGaitScript.new().run(
		self, -1.0, 10.0, 1.75, "lateral", 72, 0.40, "middle", 112
	)
	_check(
		(
			not bool(invalid_assist_limb.get("ok", true))
			and (
				String(invalid_assist_limb.get("failure_code", ""))
				== "UNKNOWN_CONTACT_CLEARANCE_ASSIST_LIMB"
			)
		),
		"unknown clearance-assist limb fails closed",
	)
	_finish()


static func _near(actual: Variant, expected: Variant) -> bool:
	return absf(float(actual) - float(expected)) <= 2.0e-6


static func _vector_near(actual_value: Variant, expected: Vector3) -> bool:
	var actual: Vector3 = actual_value
	return (
		_near(actual.x, expected.x) and _near(actual.y, expected.y) and _near(actual.z, expected.z)
	)


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
