extends SceneTree
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## No-world contract tests for the preregistered G3 morphology compiler.

const ProportionSpecScript := preload(
	"res://scripts/lab/gait/physical_quadruped_proportion_spec.gd"
)
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const ClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const CampaignScript := preload(
	"res://tests/test_experimental_br14a_11_physical_wave_gait_nonuniform_proportion_probe.gd"
)
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FeatureReceiptScript := preload(
	"res://scripts/lab/gait/morphology_feature_receipt.gd"
)
const CoverageReceiptScript := preload(
	"res://scripts/lab/gait/morphology_coverage_receipt.gd"
)
const DynamicSupportReceiptScript := preload(
	"res://scripts/lab/mechanics/dynamic_support_diagnostic_receipt.gd"
)
const DynamicSupportObserverScript := preload(
	"res://scripts/lab/mechanics/spatial_dynamic_support_observer.gd"
)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Experimental BR14A.10 G3-GP1 proportion compilers ===")
	var selection := ProportionSpecScript.selection_cells()
	var held_out := ProportionSpecScript.held_out_cells()
	_check(
		selection.size() == 13 and held_out.size() == 4,
		"the exact preregistered selection and held-out grids are published",
	)
	_check(
		_declared_ids_exact(selection, held_out),
		"cell IDs and role lookup are exact, unique, and fail closed",
	)

	var reference_parameters := ProportionSpecScript.reference_parameters()
	var reference_result := ProportionSpecScript.compile(reference_parameters)
	var reference_fixture_result := FixtureSpecScript.compile(FixtureSpecScript.reference_spec())
	_check(
		(
			bool(reference_result.get("ok", false))
			and int(reference_result.get("world_build_count", -1)) == 0
		),
		"the reference morphology compiles before world construction",
	)
	if not bool(reference_result.get("ok", false)):
		print("NONUNIFORM_PROPORTION_REFERENCE_COMPILE_FAILURE ", reference_result)
		_finish()
		return
	_check(
		(
			(
				(reference_result.get("fixture_spec", {}) as Dictionary)
				== (reference_fixture_result.get("fixture_spec", {}) as Dictionary)
			)
			and (
				String(reference_result.get("fixture_spec_sha256", ""))
				== String(reference_fixture_result.get("fixture_spec_sha256", ""))
			)
		),
		"the reference cell is byte-identical to the pinned fixture",
	)
	_check(
		_static_screen_exact(reference_result),
		"the reference static screen is complete, positive-margin, and no-world",
	)
	_check(
		_reference_policy_identity_exact(reference_result),
		"the reference fixture, controller, and numerical thresholds match GS3 unit identity",
	)

	var all_cells := selection + held_out
	var compiled_cells: Array = []
	for cell_value in all_cells:
		compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		_all_cells_compile(compiled_cells),
		"every preregistered morphology compiles with three sealed receipts",
	)
	_check(
		_all_fixture_formulas_exact(all_cells, compiled_cells),
		"every torso, hip, reach, radius, height, and mass field matches the policy",
	)
	_check(
		_all_mass_and_reach_invariants_exact(compiled_cells),
		"total reach and front-plus-rear limb mass remain invariant",
	)
	_check(
		_all_static_screens_exact(compiled_cells),
		"every declared cell clears floor, anchor, overlap, clearance, and support screens",
	)
	_check(
		_all_receipts_distinct(compiled_cells),
		"all seventeen declared cells have distinct parameter, fixture, and static digests",
	)

	var gp2_selection := ProportionSpecScript.gp2_selection_cells()
	var gp2_held_out := ProportionSpecScript.gp2_held_out_cells()
	_check(
		_gp2_declared_ids_exact(gp2_selection, gp2_held_out),
		"the narrower GP2 selection and untouched held-out grids are exact",
	)
	var gp2_cells := gp2_selection + gp2_held_out
	var gp2_compiled_cells: Array = []
	for cell_value in gp2_cells:
		gp2_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		_all_cells_compile(gp2_compiled_cells),
		"every GP2 selection and held-out morphology compiles before physics",
	)
	_check(
		(
			_all_fixture_formulas_exact(gp2_cells, gp2_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gp2_compiled_cells)
		),
		"every GP2 cell preserves the exact generator, reach, and mass formulas",
	)
	_check(
		_all_static_screens_exact(gp2_compiled_cells),
		"all seventeen GP2 cells clear the unchanged static construction screen",
	)
	_check(
		(
			_all_receipts_distinct(gp2_compiled_cells)
			and _reference_policy_identity_exact(gp2_compiled_cells[0])
		),
		"GP2 receipts are distinct while its reference retains exact GS3 unit identity",
	)

	var gp3_selection := ProportionSpecScript.gp3_selection_cells()
	var gp3_held_out := ProportionSpecScript.gp3_held_out_cells()
	_check(
		_gp3_declared_ids_exact(gp3_selection, gp3_held_out),
		"the GP3 selection and still-unopened held-out grids are exact and fail closed",
	)
	var gp3_cells := gp3_selection + gp3_held_out
	var gp3_compiled_cells: Array = []
	for cell_value in gp3_cells:
		gp3_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		_all_cells_compile(gp3_compiled_cells),
		"all seventeen GP3 morphologies compile before any physics world",
	)
	_check(
		(
			_all_fixture_formulas_exact(gp3_cells, gp3_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gp3_compiled_cells)
		),
		"every GP3 cell preserves the exact generator, reach, and mass formulas",
	)
	_check(
		(
			_all_static_screens_exact(gp3_compiled_cells)
			and _all_receipts_distinct(gp3_compiled_cells)
		),
		"all GP3 cells clear unchanged static screens with distinct sealed receipts",
	)
	_check(
		_gp3_controller_policy_exact(gp3_compiled_cells[0]),
		"GP3 seals one global path and actuator policy with exact uniform impulses",
	)

	var gp4_selection := ProportionSpecScript.gp4_selection_cells()
	var gp4_held_out := ProportionSpecScript.gp4_held_out_cells()
	_check(
		_gp4_declared_ids_exact(gp4_selection, gp4_held_out),
		"the GP4 selection and held-out grids are exact and fail closed",
	)
	var gp4_cells := gp4_selection + gp4_held_out
	var gp4_compiled_cells: Array = []
	for cell_value in gp4_cells:
		gp4_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		_all_cells_compile(gp4_compiled_cells),
		"all seventeen GP4 morphologies compile before any physics world",
	)
	_check(
		(
			_all_fixture_formulas_exact(gp4_cells, gp4_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gp4_compiled_cells)
			and _cells_numerically_equal_except_id(gp3_cells, gp4_cells)
		),
		"every GP4 cell preserves the exact GP3 generator, reach, mass, and numeric grid",
	)
	_check(
		(
			_all_static_screens_exact(gp4_compiled_cells)
			and _all_receipts_distinct(gp4_compiled_cells)
		),
		"all GP4 cells clear unchanged static screens with distinct sealed receipts",
	)
	_check(
		_gp4_controller_and_solver_policy_exact(gp4_compiled_cells[0]),
		"GP4 retains the GP3 controller and seals exact fail-closed 20/7 solver policy",
	)

	var gp5_selection := ProportionSpecScript.gp5_selection_cells()
	var gp5_held_out := ProportionSpecScript.gp5_held_out_cells()
	_check(
		_gp5_declared_ids_exact(gp5_selection, gp5_held_out),
		"the GP5 selection and held-out grids are fresh, exact, and fail closed",
	)
	var gp5_cells := gp5_selection + gp5_held_out
	var gp5_compiled_cells: Array = []
	for cell_value in gp5_cells:
		gp5_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		(
			_all_cells_compile(gp5_compiled_cells)
			and _all_fixture_formulas_exact(gp5_cells, gp5_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gp5_compiled_cells)
			and _cells_numerically_equal_except_id(gp4_cells, gp5_cells)
		),
		"all GP5 morphologies compile with the exact frozen GP4 numeric grid and generator",
	)
	_check(
		(
			_all_static_screens_exact(gp5_compiled_cells)
			and _all_receipts_distinct(gp5_compiled_cells)
		),
		"all GP5 cells clear unchanged static screens with distinct sealed receipts",
	)
	_check(
		_gp5_scores_exact(gp5_selection, gp5_held_out),
		"the morphology interaction formula is exactly zero on selection and one on held-outs",
	)
	_check(
		_gp5_controller_policy_exact(gp5_selection, gp5_held_out),
		"GP5 seals the continuous anchor guard and its motor policy fails closed",
	)

	var gq1_selection := ProportionSpecScript.gq1_selection_cells()
	var gq1_held_out := ProportionSpecScript.gq1_held_out_cells()
	_check(
		_gq1_declared_ids_exact(gq1_selection, gq1_held_out),
		"GQ1 publishes exactly twelve generated selection and eight held-out IDs",
	)
	_check(
		_gq1_generator_receipts_exact(gq1_selection, gq1_held_out),
		"all twenty deterministic generator receipts recompute exactly without a world",
	)
	var gq1_cells := gq1_selection + gq1_held_out
	var gq1_compiled_cells: Array = []
	for cell_value in gq1_cells:
		gq1_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		(
			_all_cells_compile(gq1_compiled_cells)
			and _all_fixture_formulas_exact(gq1_cells, gq1_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gq1_compiled_cells)
		),
		"all generated GQ1 bodies compile through the unchanged fixture formulas",
	)
	_check(
		(
			_all_static_screens_exact(gq1_compiled_cells)
			and _all_receipts_distinct(gq1_compiled_cells)
		),
		"all generated GQ1 bodies clear static screens with distinct sealed receipts",
	)
	_check(
		_gq1_sample_exact(),
		"the preregistered radical-inverse sample and shell realization are exact",
	)
	_check(
		_gq1_score_and_controller_derivation_exact(gq1_cells),
		"GQ1 spans intermediate and saturated scores with per-body controller receipts",
	)
	_check(
		_gq1_policy_and_fail_closed_exact(gq1_selection, gq1_held_out),
		"the GQ1 formula policy is complete and invalid generation requests fail closed",
	)

	var gq2_selection := ProportionSpecScript.gq2_selection_cells()
	var gq2_held_out := ProportionSpecScript.gq2_held_out_cells()
	_check(
		_gq2_declared_ids_exact(gq2_selection, gq2_held_out),
		"GQ2 publishes fresh exact selection and still-unopened held-out IDs",
	)
	_check(
		_gq2_generation_equivalence_exact(
			gq1_selection,
			gq1_held_out,
			gq2_selection,
			gq2_held_out,
		),
		"GQ2 reissues the exact GQ1 numeric generator under distinct receipts",
	)
	var gq2_cells := gq2_selection + gq2_held_out
	var gq2_compiled_cells: Array = []
	for cell_value in gq2_cells:
		gq2_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		(
			_all_cells_compile(gq2_compiled_cells)
			and _all_fixture_formulas_exact(gq2_cells, gq2_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gq2_compiled_cells)
			and _all_static_screens_exact(gq2_compiled_cells)
			and _all_receipts_distinct(gq2_compiled_cells)
		),
		"all GQ2 bodies compile and clear unchanged static screens without a world",
	)
	_check(
		_gq2_path_and_controller_derivation_exact(gq2_cells),
		"GQ2 seals both half-score path modes into per-body controller receipts",
	)
	_check(
		_gq2_policy_and_fail_closed_exact(gq2_selection, gq2_held_out),
		"GQ2 policy is distinct while malformed requests fail before physics",
	)

	var gq3_selection := ProportionSpecScript.gq3_selection_cells()
	var gq3_held_out := ProportionSpecScript.gq3_held_out_cells()
	_check(
		_gq3_declared_ids_exact(gq3_selection, gq3_held_out),
		"GQ3 publishes fresh exact selection and untouched held-out IDs",
	)
	_check(
		_gq3_generation_formula_exact(gq3_selection, gq3_held_out),
		"GQ3 independently recomputes all twenty fresh generator receipts",
	)
	var gq3_cells := gq3_selection + gq3_held_out
	var gq3_compiled_cells: Array = []
	for cell_value in gq3_cells:
		gq3_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		(
			_all_cells_compile(gq3_compiled_cells)
			and _all_fixture_formulas_exact(gq3_cells, gq3_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gq3_compiled_cells)
			and _all_static_screens_exact(gq3_compiled_cells)
			and _all_receipts_distinct(gq3_compiled_cells)
		),
		"all fresh GQ3 bodies compile and clear unchanged static screens without a world",
	)
	_check(
		_gq3_path_and_controller_derivation_exact(gq3_cells),
		"GQ3 seals independent cross-track and foot-radius yaw modes into each controller",
	)
	_check(
		_gq3_policy_and_fail_closed_exact(gq3_selection, gq3_held_out),
		"GQ3 policy is complete and distinct while malformed requests fail before physics",
	)

	var gq4_selection := ProportionSpecScript.gq4_selection_cells()
	var gq4_held_out := ProportionSpecScript.gq4_held_out_cells()
	_check(
		_gq4_declared_ids_exact(gq4_selection, gq4_held_out),
		"GQ4 publishes fresh exact selection and untouched held-out IDs",
	)
	_check(
		_gq4_generation_formula_exact(gq4_selection, gq4_held_out),
		"GQ4 independently recomputes all twenty fresh generator receipts",
	)
	var gq4_cells := gq4_selection + gq4_held_out
	var gq4_compiled_cells: Array = []
	for cell_value in gq4_cells:
		gq4_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		(
			_all_cells_compile(gq4_compiled_cells)
			and _all_fixture_formulas_exact(gq4_cells, gq4_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gq4_compiled_cells)
			and _all_static_screens_exact(gq4_compiled_cells)
			and _all_receipts_distinct(gq4_compiled_cells)
		),
		"all fresh GQ4 bodies compile and clear unchanged static screens without a world",
	)
	_check(
		_gq4_path_and_controller_derivation_exact(gq4_cells),
		"GQ4 seals every score-foot-hip yaw branch into per-body controllers",
	)
	_check(
		_gq4_policy_and_fail_closed_exact(gq4_selection, gq4_held_out),
		"GQ4 policy is complete and distinct while malformed requests fail before physics",
	)

	var gq5_selection := ProportionSpecScript.gq5_selection_cells()
	var gq5_held_out := ProportionSpecScript.gq5_held_out_cells()
	_check(
		_gq5_declared_ids_exact(gq5_selection, gq5_held_out),
		"GQ5 publishes fresh exact selection and untouched held-out IDs",
	)
	_check(
		_gq5_generation_formula_exact(gq5_selection, gq5_held_out),
		"GQ5 independently recomputes all twenty fresh generator receipts",
	)
	var gq5_cells := gq5_selection + gq5_held_out
	var gq5_compiled_cells: Array = []
	for cell_value in gq5_cells:
		gq5_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		(
			_all_cells_compile(gq5_compiled_cells)
			and _all_fixture_formulas_exact(gq5_cells, gq5_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gq5_compiled_cells)
			and _all_static_screens_exact(gq5_compiled_cells)
			and _all_receipts_distinct(gq5_compiled_cells)
		),
		"all fresh GQ5 bodies compile and clear unchanged static screens without a world",
	)
	_check(
		_gq5_path_and_controller_derivation_exact(gq5_cells),
		"GQ5 seals score-first yaw precedence into every per-body controller",
	)
	_check(
		_gq5_policy_and_fail_closed_exact(gq5_selection, gq5_held_out),
		"GQ5 policy is complete and distinct while malformed requests fail before physics",
	)

	var gq6_selection := ProportionSpecScript.gq6_selection_cells()
	var gq6_held_out := ProportionSpecScript.gq6_held_out_cells()
	_check(
		_gq6_declared_ids_exact(gq6_selection, gq6_held_out),
		"GQ6 publishes exactly the preregistered fresh selection and untouched held-out IDs",
	)
	_check(
		_gq6_generation_formula_exact(gq6_selection, gq6_held_out),
		"GQ6 independently reconstructs all twenty fresh generator receipts",
	)
	var gq6_cells := gq6_selection + gq6_held_out
	var gq6_compiled_cells: Array = []
	for cell_value in gq6_cells:
		gq6_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		(
			_all_cells_compile(gq6_compiled_cells)
			and _all_fixture_formulas_exact(gq6_cells, gq6_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gq6_compiled_cells)
			and _all_static_screens_exact(gq6_compiled_cells)
			and _all_receipts_distinct(gq6_compiled_cells)
		),
		"all fresh GQ6 fixtures and static screens compile with zero world construction",
	)
	_check(
		_gq6_controller_derivation_and_boundaries_exact(gq6_cells),
		"GQ6 seals morphology-derived position, yaw, velocity, and motor guard boundaries",
	)
	_check(
		_gq6_clock_solver_and_thresholds_exact(gq6_compiled_cells),
		"GQ6 seals the four-cycle clock, 20/7 solver, and two threshold corrections",
	)
	_check(
		_gq6_policy_preservation_and_fail_closed_exact(gq6_selection, gq6_held_out),
		"GQ6 is distinct and fail-closed while every GQ1-GQ5 policy digest is preserved",
	)

	var gq7_selection := ProportionSpecScript.gq7_selection_cells()
	var gq7_held_out := ProportionSpecScript.gq7_held_out_cells()
	_check(
		_gq7_declared_ids_exact(gq7_selection, gq7_held_out),
		"GQ7 publishes exactly the preregistered fresh selection and untouched held-out IDs",
	)
	_check(
		_gq7_generation_formula_exact(gq7_selection, gq7_held_out),
		"GQ7 independently reconstructs all twenty fresh generator receipts",
	)
	var gq7_cells := gq7_selection + gq7_held_out
	var gq7_compiled_cells: Array = []
	for cell_value in gq7_cells:
		gq7_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		(
			_all_cells_compile(gq7_compiled_cells)
			and _all_fixture_formulas_exact(gq7_cells, gq7_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gq7_compiled_cells)
			and _all_static_screens_exact(gq7_compiled_cells)
			and _all_receipts_distinct(gq7_compiled_cells)
		),
		"all fresh GQ7 fixtures and static screens compile with zero world construction",
	)
	_check(
		_gq7_controller_derivation_and_boundaries_exact(gq7_cells),
		"GQ7 seals the smooth high-interaction feedback curve and every controller boundary",
	)
	_check(
		_gq7_clock_solver_and_thresholds_exact(gq7_compiled_cells),
		"GQ7 seals its distinct four-cycle clock, 20/7 solver, and threshold receipts",
	)
	_check(
		_gq7_policy_preservation_and_fail_closed_exact(gq7_selection, gq7_held_out),
		"GQ7 is distinct and fail-closed while every GQ1-GQ6 policy digest is preserved",
	)

	var gq8_selection := ProportionSpecScript.gq8_selection_cells()
	var gq8_held_out := ProportionSpecScript.gq8_held_out_cells()
	_check(
		_gq8_declared_ids_exact(gq8_selection, gq8_held_out),
		"GQ8 publishes exactly the preregistered fresh selection and untouched held-out IDs",
	)
	_check(
		_gq8_generation_formula_exact(gq8_selection, gq8_held_out),
		"GQ8 independently reconstructs all twenty fresh generator receipts",
	)
	var gq8_cells := gq8_selection + gq8_held_out
	var gq8_compiled_cells: Array = []
	for cell_value in gq8_cells:
		gq8_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		(
			_all_cells_compile(gq8_compiled_cells)
			and _all_fixture_formulas_exact(gq8_cells, gq8_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gq8_compiled_cells)
			and _all_static_screens_exact(gq8_compiled_cells)
			and _all_receipts_distinct(gq8_compiled_cells)
		),
		"all fresh GQ8 fixtures and static screens compile with zero world construction",
	)
	_check(
		_gq8_controller_derivation_and_boundaries_exact(gq8_cells),
		"GQ8 seals Candidate 27 velocity feedback and every controller boundary",
	)
	_check(
		_gq8_clock_solver_and_thresholds_exact(gq8_compiled_cells),
		"GQ8 seals its distinct four-cycle clock, 20/7 solver, and threshold receipts",
	)
	_check(
		_gq8_policy_preservation_and_fail_closed_exact(gq8_selection, gq8_held_out),
		"GQ8 is distinct and fail-closed while every GQ1-GQ7 policy digest is preserved",
	)

	var gq9_selection := ProportionSpecScript.gq9_selection_cells()
	var gq9_held_out := ProportionSpecScript.gq9_held_out_cells()
	_check(
		_gq9_declared_ids_exact(gq9_selection, gq9_held_out),
		"GQ9 publishes exactly the preregistered fresh selection and untouched held-out IDs",
	)
	_check(
		_gq9_generation_formula_exact(gq9_selection, gq9_held_out),
		"GQ9 independently reconstructs all twenty fresh generator receipts",
	)
	var gq9_cells := gq9_selection + gq9_held_out
	var gq9_compiled_cells: Array = []
	for cell_value in gq9_cells:
		gq9_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		(
			_all_cells_compile(gq9_compiled_cells)
			and _all_fixture_formulas_exact(gq9_cells, gq9_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gq9_compiled_cells)
			and _all_static_screens_exact(gq9_compiled_cells)
			and _all_receipts_distinct(gq9_compiled_cells)
		),
		"all fresh GQ9 fixtures and static screens compile with zero world construction",
	)
	_check(
		_gq9_controller_derivation_and_boundaries_exact(gq9_cells),
		"GQ9 seals Candidate 28 velocity feedback and every controller boundary",
	)
	_check(
		_gq9_clock_solver_and_thresholds_exact(gq9_compiled_cells),
		"GQ9 seals its distinct four-cycle clock, 20/7 solver, and threshold receipts",
	)
	_check(
		_gq9_policy_preservation_and_fail_closed_exact(gq9_selection, gq9_held_out),
		"GQ9 is distinct and fail-closed while every GQ1-GQ8 policy digest is preserved",
	)

	var gq10_selection := ProportionSpecScript.gq10_selection_cells()
	var gq10_held_out := ProportionSpecScript.gq10_held_out_cells()
	_check(
		_gq10_declared_ids_exact(gq10_selection, gq10_held_out),
		"GQ10 publishes exactly the preregistered fresh selection and untouched held-out IDs",
	)
	_check(
		_gq10_generation_formula_exact(gq10_selection, gq10_held_out),
		"GQ10 independently reconstructs all twenty fresh generator receipts",
	)
	var gq10_cells := gq10_selection + gq10_held_out
	var gq10_compiled_cells: Array = []
	for cell_value in gq10_cells:
		gq10_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		(
			_all_cells_compile(gq10_compiled_cells)
			and _all_fixture_formulas_exact(gq10_cells, gq10_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gq10_compiled_cells)
			and _all_static_screens_exact(gq10_compiled_cells)
			and _all_receipts_distinct(gq10_compiled_cells)
		),
		"all fresh GQ10 fixtures and static screens compile with zero world construction",
	)
	_check(
		_gq10_controller_derivation_and_boundaries_exact(gq10_cells),
		"GQ10 seals Candidate 29 velocity feedback and every controller boundary",
	)
	_check(
		_gq10_clock_solver_and_thresholds_exact(gq10_compiled_cells),
		"GQ10 seals its distinct four-cycle clock, 20/7 solver, and threshold receipts",
	)
	_check(
		_gq10_policy_preservation_and_fail_closed_exact(gq10_selection, gq10_held_out),
		"GQ10 is distinct and fail-closed while every GQ1-GQ9 policy digest is preserved",
	)

	var gq11_selection := ProportionSpecScript.gq11_selection_cells()
	var gq11_held_out := ProportionSpecScript.gq11_held_out_cells()
	_check(
		_gq11_declared_ids_exact(gq11_selection, gq11_held_out),
		"GQ11 publishes exactly the preregistered fresh selection and untouched held-out IDs",
	)
	_check(
		_gq11_generation_formula_exact(gq11_selection, gq11_held_out),
		"GQ11 independently reconstructs all twenty fresh generator receipts",
	)
	var gq11_cells := gq11_selection + gq11_held_out
	var gq11_compiled_cells: Array = []
	for cell_value in gq11_cells:
		gq11_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		(
			_all_cells_compile(gq11_compiled_cells)
			and _all_fixture_formulas_exact(gq11_cells, gq11_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gq11_compiled_cells)
			and _all_static_screens_exact(gq11_compiled_cells)
			and _all_receipts_distinct(gq11_compiled_cells)
		),
		"all fresh GQ11 fixtures and static screens compile with zero world construction",
	)
	_check(
		_gq11_controller_derivation_and_boundaries_exact(gq11_cells),
		"GQ11 seals Candidate 31 velocity feedback and every controller boundary",
	)
	_check(
		_gq11_clock_solver_and_thresholds_exact(gq11_compiled_cells),
		"GQ11 seals its distinct four-cycle clock, 20/7 solver, and threshold receipts",
	)
	_check(
		_gq11_policy_preservation_and_fail_closed_exact(gq11_selection, gq11_held_out),
		"GQ11 is distinct and fail-closed while every GQ1-GQ10 policy digest is preserved",
	)

	var gq12_selection := ProportionSpecScript.gq12_selection_cells()
	var gq12_held_out := ProportionSpecScript.gq12_held_out_cells()
	_check(
		_gq12_declared_ids_exact(gq12_selection, gq12_held_out),
		"GQ12 publishes exactly the preregistered fresh selection and untouched held-out IDs",
	)
	_check(
		_gq12_generation_formula_exact(gq12_selection, gq12_held_out),
		"GQ12 independently reconstructs all twenty fresh generator receipts",
	)
	var gq12_cells := gq12_selection + gq12_held_out
	var gq12_compiled_cells: Array = []
	for cell_value in gq12_cells:
		gq12_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	_check(
		(
			_all_cells_compile(gq12_compiled_cells)
			and _all_fixture_formulas_exact(gq12_cells, gq12_compiled_cells)
			and _all_mass_and_reach_invariants_exact(gq12_compiled_cells)
			and _all_static_screens_exact(gq12_compiled_cells)
			and _all_receipts_distinct(gq12_compiled_cells)
		),
		"all fresh GQ12 fixtures and static screens compile with zero world construction",
	)
	_check(
		_gq12_controller_derivation_and_boundaries_exact(gq12_cells),
		"GQ12 seals Candidate 32 dual-geometry velocity feedback and every controller boundary",
	)
	_check(
		_gq12_clock_solver_and_thresholds_exact(gq12_compiled_cells),
		"GQ12 seals its distinct four-cycle clock, 20/7 solver, and threshold receipts",
	)
	_check(
		_gq12_policy_preservation_and_fail_closed_exact(gq12_selection, gq12_held_out),
		"GQ12 is distinct and fail-closed while every GQ1-GQ11 policy digest is preserved",
	)

	var gq13_selection := ProportionSpecScript.gq13_selection_cells()
	var gq13_held_out := ProportionSpecScript.gq13_held_out_cells()
	var gq13_cells := gq13_selection + gq13_held_out
	var gq13_compiled_cells: Array = []
	for cell_value in gq13_cells:
		gq13_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	var gq13_generator_contract := _gq13_generator_contract(gq13_selection, gq13_held_out)
	var gq13_controller_contract := _gq13_controller_contract(gq13_cells)
	var gq13_numerical_contract := _gq13_numerical_contract(gq13_compiled_cells)
	var gq13_policy_contract := _gq13_policy_contract(gq13_selection, gq13_held_out)
	var gq13_receipt_contract := _gq13_receipt_contract(
		gq13_cells,
		gq13_compiled_cells,
	)
	_check(
		bool(gq13_generator_contract.get("selection_ids_exact", false)),
		"GQ13 publishes exactly selection IDs s133 through s144",
	)
	_check(
		bool(gq13_generator_contract.get("heldout_ids_exact", false)),
		"GQ13 publishes exactly held-out IDs s1201 through s1208",
	)
	_check(
		bool(gq13_generator_contract.get("reverse_lookup_exact", false)),
		"GQ13 reverse lookup preserves role and rejects cross-role aliases",
	)
	_check(
		bool(gq13_generator_contract.get("all_generation_ok", false)),
		"all twenty GQ13 generation requests compile without a world",
	)
	_check(
		bool(gq13_generator_contract.get("generation_formula_exact", false)),
		"all twenty GQ13 bodies independently reconstruct the frozen radical-inverse shells",
	)
	_check(
		bool(gq13_generator_contract.get("generation_receipts_distinct", false)),
		"all twenty GQ13 generation receipts are canonical and distinct",
	)
	_check(
		bool(gq13_generator_contract.get("generator_verify_exact", false)),
		"every GQ13 generator receipt verifies against its own canonical digest",
	)
	_check(
		bool(gq13_generator_contract.get("generator_fail_closed", false)),
		"GQ13 generation rejects wrong types, indices, roles, identities, and tampering",
	)
	_check(
		_all_cells_compile(gq13_compiled_cells),
		"all twenty GQ13 proportion bundles compile with zero world construction",
	)
	_check(
		_all_fixture_formulas_exact(gq13_cells, gq13_compiled_cells),
		"every GQ13 fixture reconstructs all declared geometry and mass formulas",
	)
	_check(
		_all_mass_and_reach_invariants_exact(gq13_compiled_cells),
		"every GQ13 fixture preserves total reach and front-plus-rear mass invariants",
	)
	_check(
		_all_static_screens_exact(gq13_compiled_cells),
		"every GQ13 fixture clears the unchanged fail-closed static screen",
	)
	_check(
		_all_receipts_distinct(gq13_compiled_cells),
		"all twenty GQ13 parameter, fixture, and static-screen receipt triples are distinct",
	)
	_check(
		bool(gq13_numerical_contract.get("clock_identity_exact", false)),
		"GQ13 seals a distinct clock identity with no numerical drift",
	)
	_check(
		bool(gq13_numerical_contract.get("clock_timing_exact", false)),
		"GQ13 retains the exact 120 Hz four-cycle timing and contact bounds",
	)
	_check(
		bool(gq13_numerical_contract.get("solver_exact", false)),
		"GQ13 seals the exact Jolt 20/7 solver receipt",
	)
	_check(
		bool(gq13_numerical_contract.get("thresholds_exact", false)),
		"GQ13 retains exact dimensionless relocation, drift, and structural thresholds",
	)
	_check(
		bool(gq13_controller_contract.get("all_cells_exact", false)),
		"every GQ13 cell reconstructs the frozen Candidate 33 controller",
	)
	_check(
		bool(gq13_controller_contract.get("yaw_precedence_exact", false)),
		"the Y greater-than-one branch precedes score, width, length, and foot branches",
	)
	_check(
		bool(gq13_controller_contract.get("long_wide_smooth_exact", false)),
		"the long-wide product proves zero, interior, and saturation endpoints",
	)
	_check(
		bool(gq13_controller_contract.get("long_small_foot_smooth_exact", false)),
		"the low-score long-small-foot product proves zero, interior, and saturation endpoints",
	)
	_check(
		bool(gq13_controller_contract.get("score_015_boundary_exact", false)),
		"S equals 0.15 enters the Candidate 33 mid-score branch exactly",
	)
	_check(
		bool(gq13_controller_contract.get("score_05_boundary_exact", false)),
		"S equals 0.5 exits the mid-score branch exactly",
	)
	_check(
		bool(gq13_controller_contract.get("width_boundary_exact", false)),
		"W equals 1.0 remains in the narrow-or-equal branch exactly",
	)
	_check(
		bool(gq13_controller_contract.get("length_boundary_exact", false)),
		"L equals 1.0 does not enter the short-wide taper",
	)
	_check(
		bool(gq13_controller_contract.get("foot_boundary_exact", false)),
		"F equals 1.01 is the exact zero endpoint for the small-foot product",
	)
	_check(
		bool(gq13_controller_contract.get("motor_guard_exact", false)),
		"the score-derived anchor guard retains its exact half-score boundary",
	)
	_check(
		bool(gq13_controller_contract.get("metadata_independence_exact", false)),
		"IDs, indices, roles, repetitions, seeds, and outcomes cannot change GQ13 control",
	)
	_check(
		bool(gq13_controller_contract.get("controller_digests_distinct", false)),
		"GQ13 controller digests are valid and vary only with frozen physical features",
	)
	_check(
		bool(gq13_policy_contract.get("identities_exact", false)),
		"GQ13 seals every campaign, generator, controller, receipt, clock, and report identity",
	)
	_check(
		bool(gq13_policy_contract.get("legacy_digests_exact", false)),
		"GQ1 through GQ12 policy digests, including the frozen rejected GQ12 digest, reproduce",
	)
	_check(
		bool(gq13_policy_contract.get("fail_closed_exact", false)),
		"GQ13 policy and receipt inputs reject identity-, authority-, and outcome-driven changes",
	)
	_check(
		bool(gq13_receipt_contract.get("cohort_features_exact", false)),
		"all twenty fixed GQ11 Candidate 33 cohort feature receipts reconstruct no-world",
	)
	_check(
		bool(gq13_receipt_contract.get("cohort_order_exact", false)),
		"the coverage cohort membership, order, claim level, and source hash are exact",
	)
	_check(
		bool(gq13_receipt_contract.get("query_features_exact", false)),
		"all twenty GQ13 query feature receipts reconstruct every signed axis and source digest",
	)
	_check(
		bool(gq13_receipt_contract.get("feature_verify_fail_closed", false)),
		"feature verification accepts exact digests and rejects tampering without authority",
	)
	_check(
		bool(gq13_receipt_contract.get("coverage_math_exact", false)),
		"coverage independently reproduces population standardization and leave-one-out distances",
	)
	_check(
		bool(gq13_receipt_contract.get("coverage_boundaries_exact", false)),
		"SUPPORTED, EDGE, and OUT_OF_DISTRIBUTION use the exact frozen inclusive boundaries",
	)
	_check(
		bool(gq13_receipt_contract.get("coverage_authority_fail_closed", false)),
		"coverage is output-only and malformed cohort, order, query, or digest inputs fail closed",
	)
	_check(
		_gq13_dynamic_trace_contract_exact(),
		"synthetic dynamic support proves ordered samples, minima, crossings, digest, authority, and malformed rejection",
	)
	_check(
		_dynamic_support_polygon_order_contract_exact(),
		"semantic contact order stays canonical while support points follow the noncrossing footprint perimeter",
	)

	var gq14_selection := ProportionSpecScript.gq14_selection_cells()
	var gq14_held_out := ProportionSpecScript.gq14_held_out_cells()
	var gq14_cells := gq14_selection + gq14_held_out
	var gq14_compiled_cells: Array = []
	for cell_value in gq14_cells:
		gq14_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	var gq14_contract := _gq14_contract(
		gq14_selection,
		gq14_held_out,
		gq14_compiled_cells,
	)
	_check(
		bool(gq14_contract.get("population_exact", false)),
		"GQ14 publishes exactly fresh selection s145-s156 and sealed held-outs s1301-s1308",
	)
	_check(
		bool(gq14_contract.get("generation_exact", false)),
		"all twenty GQ14 generators, receipts, verification paths, and reverse lookups are exact",
	)
	_check(
		bool(gq14_contract.get("fixtures_exact", false)),
		"all twenty GQ14 fixtures and static screens compile with zero world construction",
	)
	_check(
		bool(gq14_contract.get("controllers_exact", false)),
		"every GQ14 body reconstructs Candidate 34 from physical features only",
	)
	_check(
		bool(gq14_contract.get("velocity_boundaries_exact", false)),
		"Candidate 34 proves every branch, boundary, product endpoint, max combination, and precedence edge",
	)
	_check(
		bool(gq14_contract.get("anchor_guard_exact", false)),
		"Candidate 34 proves the exact high-score long-narrow guard override and strict boundaries",
	)
	_check(
		bool(gq14_contract.get("numerics_exact", false)),
		"GQ14 seals the identity-only clock change, Jolt 20/7 solver, and dimensionless thresholds",
	)
	_check(
		bool(gq14_contract.get("policy_and_preservation_exact", false)),
		"GQ14 seals every identity while reproducing the frozen GQ13 policy digest exactly",
	)
	_check(
		bool(gq14_contract.get("cohort_features_exact", false)),
		"the 32-member opened Candidate 34 cohort reconstructs in exact order without a world",
	)
	_check(
		bool(gq14_contract.get("coverage_exact", false)),
		"GQ14 v2 coverage reconstructs all queries, distances, boundaries, source identity, and report-only authority",
	)
	_check(
		bool(gq14_contract.get("support_sets_exact", false)),
		"GQ14 v2 support diagnostics prove point, segment, polygon, order, digest, and fail-closed cases",
	)
	_check(
		bool(gq14_contract.get("runtime_profile_exact", false)),
		"the GQ14 runtime profile selects v2 diagnostics and v19 reporting without granting control or acceptance",
	)

	var gq15_selection := ProportionSpecScript.gq15_selection_cells()
	var gq15_held_out := ProportionSpecScript.gq15_held_out_cells()
	var gq15_cells := gq15_selection + gq15_held_out
	var gq15_compiled_cells: Array = []
	for cell_value in gq15_cells:
		gq15_compiled_cells.append(ProportionSpecScript.compile(cell_value))
	var gq15_contract := _gq15_contract(
		gq15_selection,
		gq15_held_out,
		gq15_compiled_cells,
	)
	_check(
		bool(gq15_contract.get("population_exact", false)),
		"GQ15 publishes exactly fresh selection s157-s168 and sealed held-outs s1401-s1408",
	)
	_check(
		bool(gq15_contract.get("generation_exact", false)),
		"all twenty GQ15 generators, canonical receipts, verification, lookup, and rejection paths are exact",
	)
	_check(
		bool(gq15_contract.get("fixtures_exact", false)),
		"all twenty GQ15 fixtures preserve formulas, invariants, static screens, and no-world construction",
	)
	_check(
		bool(gq15_contract.get("controllers_exact", false)),
		"every GQ15 body reconstructs frozen Candidate 35 from physical features only",
	)
	_check(
		bool(gq15_contract.get("velocity_boundaries_exact", false)),
		"Candidate 35 proves its short-wide score and width products plus Candidate 34 precedence",
	)
	_check(
		bool(gq15_contract.get("anchor_guard_exact", false)),
		"Candidate 35 proves the union guard and every strict score, length, and width boundary",
	)
	_check(
		bool(gq15_contract.get("numerics_exact", false)),
		"GQ15 seals its identity-only four-cycle clock, Jolt 20/7 solver, and dimensionless thresholds",
	)
	_check(
		bool(gq15_contract.get("policy_and_preservation_exact", false)),
		"GQ15 seals all identities while reproducing the frozen GQ13 and GQ14 policy digests exactly",
	)
	_check(
		bool(gq15_contract.get("cohort_features_exact", false)),
		"the 56-member opened Candidate 35 development cohort reconstructs in exact order without a world",
	)
	_check(
		bool(gq15_contract.get("coverage_exact", false)),
		"GQ15 v3 population-distance coverage reconstructs every query with report-only authority",
	)
	_check(
		bool(gq15_contract.get("support_sets_exact", false)),
		"GQ15 v3 dynamic support proves point, segment, polygon, digest, verification, and tamper rejection",
	)
	_check(
		bool(gq15_contract.get("runtime_profile_exact", false)),
		"the GQ15 runtime and runner select v3 diagnostics and v20 reporting without granting authority",
	)

	var out_of_range := reference_parameters.duplicate(true)
	out_of_range["torso_length_scale"] = 0.899
	_check(
		_fails_without_world(out_of_range, "PROPORTION_PARAMETER_OUT_OF_RANGE"),
		"scale values outside the sealed envelope fail before world construction",
	)
	var upper_out_of_range := reference_parameters.duplicate(true)
	upper_out_of_range["upper_length_fraction"] = 0.551
	_check(
		_fails_without_world(upper_out_of_range, "UPPER_FRACTION_OUT_OF_RANGE"),
		"upper/lower reach splits outside the sealed envelope fail closed",
	)
	var nonfinite := reference_parameters.duplicate(true)
	nonfinite["foot_radius_scale"] = INF
	_check(
		_fails_without_world(nonfinite, "NONFINITE_NUMBER"),
		"nonfinite morphology parameters fail before fixture generation",
	)
	var unexpected := reference_parameters.duplicate(true)
	unexpected["surprise"] = 1.0
	_check(
		_fails_without_world(unexpected, "UNEXPECTED_KEYS"),
		"unexpected morphology fields cannot silently enter the policy",
	)
	var missing := reference_parameters.duplicate(true)
	missing.erase("hip_span_scale")
	_check(
		_fails_without_world(missing, "UNEXPECTED_KEYS"),
		"missing morphology fields cannot fall back to hidden defaults",
	)

	var verified := (
		ProportionSpecScript
		. verify(
			reference_parameters,
			String(reference_result.get("proportion_spec_sha256", "")),
			String(reference_result.get("fixture_spec_sha256", "")),
			String(reference_result.get("static_screen_sha256", "")),
		)
	)
	_check(
		bool(verified.get("ok", false)) and int(verified.get("world_build_count", -1)) == 0,
		"the exact three-receipt bundle verifies without a world",
	)
	_check(
		_all_tampered_receipts_fail(reference_parameters, reference_result),
		"tampering any parameter, fixture, or static-screen digest fails closed",
	)
	_check(
		(
			not bool(reference_result.get("formal_milestone_acceptance_authorized", true))
			and not bool(reference_result.get("encyclopedia_admission_authorized", true))
			and not bool(reference_result.get("automatic_creature_guidance_allowed", true))
		),
		"the compiler grants no walking, acceptance, or guidance authority",
	)
	_finish()


static func _declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"reference",
		"torso_length_0p900",
		"torso_length_1p100",
		"torso_width_0p900",
		"torso_width_1p100",
		"upper_share_0p480",
		"upper_share_0p550",
		"hip_span_0p900",
		"hip_span_1p100",
		"foot_radius_0p900",
		"foot_radius_1p100",
		"front_mass_0p900",
		"front_mass_1p100",
	]
	var expected_held_out := ["mixed_a", "mixed_b", "mixed_c", "mixed_d"]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		var cell: Dictionary = cell_value
		realized_selection.append(String(cell["morphology_id"]))
	for cell_value in held_out:
		var cell: Dictionary = cell_value
		realized_held_out.append(String(cell["morphology_id"]))
	return (
		realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and ProportionSpecScript.declared_cell("mixed_a", "heldout") == held_out[0]
		and ProportionSpecScript.declared_cell("mixed_a", "selection").is_empty()
		and ProportionSpecScript.declared_cell("unknown", "selection").is_empty()
	)


static func _gp2_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gp2_reference",
		"gp2_torso_length_0p900",
		"gp2_torso_length_1p100",
		"gp2_torso_width_0p900",
		"gp2_torso_width_1p100",
		"gp2_upper_share_0p500",
		"gp2_upper_share_0p550",
		"gp2_hip_span_0p900",
		"gp2_hip_span_1p100",
		"gp2_foot_radius_0p975",
		"gp2_foot_radius_1p100",
		"gp2_front_mass_0p900",
		"gp2_front_mass_1p050",
	]
	var expected_held_out := [
		"gp2_mixed_a",
		"gp2_mixed_b",
		"gp2_mixed_c",
		"gp2_mixed_d",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		var cell: Dictionary = cell_value
		realized_selection.append(String(cell["morphology_id"]))
	for cell_value in held_out:
		var cell: Dictionary = cell_value
		realized_held_out.append(String(cell["morphology_id"]))
	return (
		realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gp2_mixed_a",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GP2,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gp2_mixed_a",
				"heldout",
				ProportionSpecScript.CAMPAIGN_GP1,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gp2_reference",
				"selection",
				"unknown_campaign",
			)
			. is_empty()
		)
	)


static func _gp3_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gp3_reference",
		"gp3_torso_length_0p900",
		"gp3_torso_length_1p100",
		"gp3_torso_width_0p900",
		"gp3_torso_width_1p100",
		"gp3_upper_share_0p500",
		"gp3_upper_share_0p550",
		"gp3_hip_span_0p900",
		"gp3_hip_span_1p100",
		"gp3_foot_radius_0p975",
		"gp3_foot_radius_1p100",
		"gp3_front_mass_0p900",
		"gp3_front_mass_1p050",
	]
	var expected_held_out := [
		"gp3_mixed_a",
		"gp3_mixed_b",
		"gp3_mixed_c",
		"gp3_mixed_d",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		var cell: Dictionary = cell_value
		realized_selection.append(String(cell["morphology_id"]))
	for cell_value in held_out:
		var cell: Dictionary = cell_value
		realized_held_out.append(String(cell["morphology_id"]))
	return (
		realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gp3_mixed_a",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GP3,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gp3_mixed_a",
				"heldout",
				ProportionSpecScript.CAMPAIGN_GP2,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gp3_reference",
				"selection",
				"unknown_campaign",
			)
			. is_empty()
		)
	)


static func _gp4_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gp4_reference",
		"gp4_torso_length_0p900",
		"gp4_torso_length_1p100",
		"gp4_torso_width_0p900",
		"gp4_torso_width_1p100",
		"gp4_upper_share_0p500",
		"gp4_upper_share_0p550",
		"gp4_hip_span_0p900",
		"gp4_hip_span_1p100",
		"gp4_foot_radius_0p975",
		"gp4_foot_radius_1p100",
		"gp4_front_mass_0p900",
		"gp4_front_mass_1p050",
	]
	var expected_held_out := [
		"gp4_mixed_a",
		"gp4_mixed_b",
		"gp4_mixed_c",
		"gp4_mixed_d",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		var cell: Dictionary = cell_value
		realized_selection.append(String(cell["morphology_id"]))
	for cell_value in held_out:
		var cell: Dictionary = cell_value
		realized_held_out.append(String(cell["morphology_id"]))
	return (
		realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gp4_mixed_a",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GP4,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gp4_mixed_a",
				"heldout",
				ProportionSpecScript.CAMPAIGN_GP3,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gp4_reference",
				"selection",
				"unknown_campaign",
			)
			. is_empty()
		)
	)


static func _gp5_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gp5_reference",
		"gp5_torso_length_0p900",
		"gp5_torso_length_1p100",
		"gp5_torso_width_0p900",
		"gp5_torso_width_1p100",
		"gp5_upper_share_0p500",
		"gp5_upper_share_0p550",
		"gp5_hip_span_0p900",
		"gp5_hip_span_1p100",
		"gp5_foot_radius_0p975",
		"gp5_foot_radius_1p100",
		"gp5_front_mass_0p900",
		"gp5_front_mass_1p050",
	]
	var expected_held_out := [
		"gp5_mixed_a",
		"gp5_mixed_b",
		"gp5_mixed_c",
		"gp5_mixed_d",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		var cell: Dictionary = cell_value
		realized_selection.append(String(cell["morphology_id"]))
	for cell_value in held_out:
		var cell: Dictionary = cell_value
		realized_held_out.append(String(cell["morphology_id"]))
	return (
		realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gp5_mixed_a",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GP5,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gp5_mixed_a",
				"heldout",
				ProportionSpecScript.CAMPAIGN_GP4,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gp5_reference",
				"selection",
				"unknown_campaign",
			)
			. is_empty()
		)
	)


static func _gq1_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gq1_generated_s001",
		"gq1_generated_s002",
		"gq1_generated_s003",
		"gq1_generated_s004",
		"gq1_generated_s005",
		"gq1_generated_s006",
		"gq1_generated_s007",
		"gq1_generated_s008",
		"gq1_generated_s009",
		"gq1_generated_s010",
		"gq1_generated_s011",
		"gq1_generated_s012",
	]
	var expected_held_out := [
		"gq1_generated_s101",
		"gq1_generated_s102",
		"gq1_generated_s103",
		"gq1_generated_s104",
		"gq1_generated_s105",
		"gq1_generated_s106",
		"gq1_generated_s107",
		"gq1_generated_s108",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		realized_selection.append(String((cell_value as Dictionary)["morphology_id"]))
	for cell_value in held_out:
		realized_held_out.append(String((cell_value as Dictionary)["morphology_id"]))
	return (
		realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq1_generated_s001",
					"selection",
					ProportionSpecScript.CAMPAIGN_GQ1,
				)
			)
			== selection[0]
		)
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq1_generated_s101",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GQ1,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq1_generated_s101",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ1,
			)
			. is_empty()
		)
	)


static func _gq1_generator_receipts_exact(selection: Array, held_out: Array) -> bool:
	var indices: Array = (
		ProportionSpecScript.GQ1_SELECTION_INDICES + ProportionSpecScript.GQ1_HELD_OUT_INDICES
	)
	var cells := selection + held_out
	var digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var result := ProportionSpecScript.compile_gq1_generation(generator_index)
		if (
			not bool(result.get("ok", false))
			or int(result.get("world_build_count", -1)) != 0
			or (result.get("proportion_spec", {}) as Dictionary) != cells[cell_index]
		):
			return false
		var receipt: Dictionary = result.get("generator_receipt", {})
		var digest := String(result.get("generator_receipt_sha256", ""))
		var expected_role := "selection" if cell_index < selection.size() else "heldout"
		var expected_shell := 0.25 * float(1 + posmod(generator_index - 1, 4))
		if (
			(
				String(receipt.get("schema_version", ""))
				!= ProportionSpecScript.GQ1_GENERATOR_SCHEMA_VERSION
			)
			or (
				String(receipt.get("generator_policy_id", ""))
				!= ProportionSpecScript.GQ1_GENERATOR_POLICY_ID
			)
			or String(receipt.get("campaign_id", "")) != ProportionSpecScript.CAMPAIGN_GQ1
			or String(receipt.get("campaign_role", "")) != expected_role
			or int(receipt.get("generator_index", -1)) != generator_index
			or not is_equal_approx(float(receipt.get("shell_fraction", NAN)), expected_shell)
			or int(receipt.get("world_build_count", -1)) != 0
			or CanonicalJsonScript.sha256(receipt) != digest
			or digest.length() != 71
		):
			return false
		var axis_coordinates: Dictionary = receipt.get("axis_coordinates", {})
		for axis_key_value in ProportionSpecScript.GQ1_AXIS_KEYS:
			var axis_key := String(axis_key_value)
			var coordinate: Dictionary = axis_coordinates.get(axis_key, {})
			var interval: Array = ProportionSpecScript.GQ1_AXIS_INTERVALS[axis_key]
			var radical_inverse := float(coordinate.get("radical_inverse", NAN))
			if (
				(
					int(coordinate.get("base", -1))
					!= int(ProportionSpecScript.GQ1_AXIS_BASES[axis_key])
				)
				or radical_inverse < 0.0
				or radical_inverse >= 1.0
				or not is_equal_approx(
					float(coordinate.get("centered_coordinate", NAN)),
					2.0 * radical_inverse - 1.0,
				)
				or not is_equal_approx(
					float(coordinate.get("reference_value", NAN)),
					float(interval[0]),
				)
				or not is_equal_approx(
					float(coordinate.get("lower_endpoint", NAN)),
					float(interval[1]),
				)
				or not is_equal_approx(
					float(coordinate.get("upper_endpoint", NAN)),
					float(interval[2]),
				)
				or not is_equal_approx(
					float(coordinate.get("realized_value", NAN)),
					float((cells[cell_index] as Dictionary)[axis_key]),
				)
			):
				return false
		var repeated := ProportionSpecScript.compile_gq1_generation(generator_index)
		var verified := ProportionSpecScript.verify_gq1_generation(generator_index, digest)
		if (
			String(repeated.get("generator_receipt_sha256", "")) != digest
			or not bool(verified.get("ok", false))
			or (verified.get("proportion_spec", {}) as Dictionary) != cells[cell_index]
		):
			return false
		digests[digest] = true
	return digests.size() == indices.size()


static func _gq1_sample_exact() -> bool:
	var generated := ProportionSpecScript.compile_gq1_generation(101)
	if not bool(generated.get("ok", false)):
		return false
	var spec: Dictionary = generated["proportion_spec"]
	var receipt: Dictionary = generated["generator_receipt"]
	var axes: Dictionary = receipt["axis_coordinates"]
	return (
		is_equal_approx(float(receipt["shell_fraction"]), 0.25)
		and is_equal_approx(
			float((axes["torso_length_scale"] as Dictionary)["radical_inverse"]), 0.6484375
		)
		and is_equal_approx(float(spec["torso_length_scale"]), 1.007421875)
		and is_equal_approx(float(spec["torso_width_scale"]), 1.0122427983539095)
		and is_equal_approx(float(spec["upper_length_fraction"]), 0.5123714285714285)
		and is_equal_approx(float(spec["hip_span_scale"]), 0.9967201166180758)
		and is_equal_approx(float(spec["foot_radius_scale"]), 0.9969524793388430)
		and is_equal_approx(float(spec["front_limb_mass_scale"]), 1.0077662721893492)
	)


static func _gq1_score_and_controller_derivation_exact(cells: Array) -> bool:
	var intermediate_score_count := 0
	var saturated_score_count := 0
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := CampaignScript._morphology_interaction_score(cell)
		if score <= 0.0 or score > 1.0:
			return false
		if score < 1.0:
			intermediate_score_count += 1
		else:
			saturated_score_count += 1
		var options := CampaignScript._motor_velocity_options(CampaignScript.CAMPAIGN_GQ1, cell)
		var path_options := (
			CampaignScript
			. _path_steering_options(
				CampaignScript.CAMPAIGN_GQ1,
				cell,
			)
		)
		var digest := (
			CampaignScript
			. _expected_controller_sha256(
				CampaignScript.CAMPAIGN_GQ1,
				options,
				path_options,
			)
		)
		if (
			not is_equal_approx(float(options.get("morphology_interaction_score", NAN)), score)
			or not is_equal_approx(
				float(path_options.get("cross_track_heading_gain_rad_per_m", NAN)),
				0.75,
			)
			or not digest.begins_with("sha256:")
			or digest.length() != 71
		):
			return false
		controller_digests[digest] = true
	return (
		intermediate_score_count > 0 and saturated_score_count > 0 and controller_digests.size() > 1
	)


static func _gq1_policy_and_fail_closed_exact(selection: Array, held_out: Array) -> bool:
	var gq1_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ1)
	var gp5_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GP5)
	var first_generation := ProportionSpecScript.compile_gq1_generation(1)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var tampered_digest := first_digest.left(70) + ("0" if first_digest.right(1) != "0" else "1")
	var wrong_type := ProportionSpecScript.compile_gq1_generation(1.0)
	var unknown_index := ProportionSpecScript.compile_gq1_generation(13)
	var tampered := ProportionSpecScript.verify_gq1_generation(1, tampered_digest)
	var invalid_role := (
		ProportionSpecScript
		. gq1_generation_for_morphology(
			"gq1_generated_s001",
			"invalid",
		)
	)
	var wrong_role := (
		ProportionSpecScript
		. gq1_generation_for_morphology(
			"gq1_generated_s001",
			"heldout",
		)
	)
	var unknown_morphology := (
		ProportionSpecScript
		. gq1_generation_for_morphology(
			"gq1_generated_s999",
			"selection",
		)
	)
	return (
		(
			String(gq1_policy.get("schema_version", ""))
			== "sporespore_g4_gq1_generated_morphology_policy_v1"
		)
		and (gq1_policy.get("selection_cells", []) as Array) == selection
		and (gq1_policy.get("held_out_cells", []) as Array) == held_out
		and (
			(gq1_policy.get("selection_generator_indices", []) as Array)
			== ProportionSpecScript.GQ1_SELECTION_INDICES
		)
		and (
			(gq1_policy.get("held_out_generator_indices", []) as Array)
			== ProportionSpecScript.GQ1_HELD_OUT_INDICES
		)
		and (
			(gq1_policy.get("generator_axis_bases", {}) as Dictionary)
			== ProportionSpecScript.GQ1_AXIS_BASES
		)
		and (
			(gq1_policy.get("generator_axis_intervals", {}) as Dictionary)
			== ProportionSpecScript.GQ1_AXIS_INTERVALS
		)
		and (gq1_policy.get("generator_receipts", []) as Array).size() == 20
		and (
			String(gq1_policy.get("controller_configuration_derivation_id", ""))
			== "gp3_base_plus_morphology_interaction_score_v1"
		)
		and not gq1_policy.has("controller_sha256")
		and (
			CanonicalJsonScript.sha256(gq1_policy)
			== "sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698"
		)
		and CanonicalJsonScript.sha256(gq1_policy) != CanonicalJsonScript.sha256(gp5_policy)
		and not bool(wrong_type.get("ok", true))
		and String(wrong_type.get("failure_code", "")) == "INVALID_GQ1_GENERATOR_INDEX_TYPE"
		and int(wrong_type.get("world_build_count", -1)) == 0
		and not bool(unknown_index.get("ok", true))
		and String(unknown_index.get("failure_code", "")) == "UNKNOWN_GQ1_GENERATOR_INDEX"
		and int(unknown_index.get("world_build_count", -1)) == 0
		and not bool(tampered.get("ok", true))
		and String(tampered.get("failure_code", "")) == "GQ1_GENERATOR_RECEIPT_DIGEST_MISMATCH"
		and int(tampered.get("world_build_count", -1)) == 0
		and not bool(invalid_role.get("ok", true))
		and String(invalid_role.get("failure_code", "")) == "INVALID_GQ1_CAMPAIGN_ROLE"
		and int(invalid_role.get("world_build_count", -1)) == 0
		and not bool(wrong_role.get("ok", true))
		and String(wrong_role.get("failure_code", "")) == "UNKNOWN_GQ1_MORPHOLOGY"
		and int(wrong_role.get("world_build_count", -1)) == 0
		and not bool(unknown_morphology.get("ok", true))
		and String(unknown_morphology.get("failure_code", "")) == "UNKNOWN_GQ1_MORPHOLOGY"
		and int(unknown_morphology.get("world_build_count", -1)) == 0
	)


static func _gq2_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gq2_generated_s001",
		"gq2_generated_s002",
		"gq2_generated_s003",
		"gq2_generated_s004",
		"gq2_generated_s005",
		"gq2_generated_s006",
		"gq2_generated_s007",
		"gq2_generated_s008",
		"gq2_generated_s009",
		"gq2_generated_s010",
		"gq2_generated_s011",
		"gq2_generated_s012",
	]
	var expected_held_out := [
		"gq2_generated_s101",
		"gq2_generated_s102",
		"gq2_generated_s103",
		"gq2_generated_s104",
		"gq2_generated_s105",
		"gq2_generated_s106",
		"gq2_generated_s107",
		"gq2_generated_s108",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		realized_selection.append(String((cell_value as Dictionary)["morphology_id"]))
	for cell_value in held_out:
		realized_held_out.append(String((cell_value as Dictionary)["morphology_id"]))
	return (
		realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq2_generated_s001",
					"selection",
					ProportionSpecScript.CAMPAIGN_GQ2,
				)
			)
			== selection[0]
		)
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq2_generated_s101",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GQ2,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq2_generated_s101",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ2,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq1_generated_s001",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ2,
			)
			. is_empty()
		)
	)


static func _gq2_generation_equivalence_exact(
	gq1_selection: Array,
	gq1_held_out: Array,
	gq2_selection: Array,
	gq2_held_out: Array,
) -> bool:
	var indices: Array = (
		ProportionSpecScript.GQ2_SELECTION_INDICES + ProportionSpecScript.GQ2_HELD_OUT_INDICES
	)
	var gq1_cells := gq1_selection + gq1_held_out
	var gq2_cells := gq2_selection + gq2_held_out
	var gq2_digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var gq1_result := ProportionSpecScript.compile_gq1_generation(generator_index)
		var gq2_result := ProportionSpecScript.compile_gq2_generation(generator_index)
		if not bool(gq1_result.get("ok", false)) or not bool(gq2_result.get("ok", false)):
			return false
		var gq1_numeric: Dictionary = (gq1_cells[cell_index] as Dictionary).duplicate(true)
		var gq2_numeric: Dictionary = (gq2_cells[cell_index] as Dictionary).duplicate(true)
		gq1_numeric.erase("morphology_id")
		gq2_numeric.erase("morphology_id")
		var gq1_receipt: Dictionary = gq1_result["generator_receipt"]
		var gq2_receipt: Dictionary = gq2_result["generator_receipt"]
		var gq2_digest := String(gq2_result["generator_receipt_sha256"])
		var verified := ProportionSpecScript.verify_gq2_generation(generator_index, gq2_digest)
		if (
			gq1_numeric != gq2_numeric
			or (
				String(gq2_receipt.get("schema_version", ""))
				!= ProportionSpecScript.GQ2_GENERATOR_SCHEMA_VERSION
			)
			or (
				String(gq2_receipt.get("generator_policy_id", ""))
				!= ProportionSpecScript.GQ2_GENERATOR_POLICY_ID
			)
			or String(gq2_receipt.get("campaign_id", "")) != ProportionSpecScript.CAMPAIGN_GQ2
			or (
				(gq2_receipt.get("axis_coordinates", {}) as Dictionary)
				!= (gq1_receipt.get("axis_coordinates", {}) as Dictionary)
			)
			or CanonicalJsonScript.sha256(gq2_receipt) != gq2_digest
			or gq2_digest == String(gq1_result["generator_receipt_sha256"])
			or not bool(verified.get("ok", false))
			or int(verified.get("world_build_count", -1)) != 0
		):
			return false
		gq2_digests[gq2_digest] = true
	return gq2_digests.size() == indices.size()


static func _gq2_path_and_controller_derivation_exact(cells: Array) -> bool:
	var low_score_count := 0
	var high_score_count := 0
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := CampaignScript._morphology_interaction_score(cell)
		var expected_gain := 1.0 if score < 0.5 else 0.75
		var path_options := (
			CampaignScript
			. _path_steering_options(
				CampaignScript.CAMPAIGN_GQ2,
				cell,
			)
		)
		var motor_options := (
			CampaignScript
			. _motor_velocity_options(
				CampaignScript.CAMPAIGN_GQ2,
				cell,
			)
		)
		var digest := (
			CampaignScript
			. _expected_controller_sha256(
				CampaignScript.CAMPAIGN_GQ2,
				motor_options,
				path_options,
			)
		)
		if score < 0.5:
			low_score_count += 1
		else:
			high_score_count += 1
		if (
			not is_equal_approx(
				float(path_options.get("cross_track_heading_gain_rad_per_m", NAN)),
				expected_gain,
			)
			or not is_equal_approx(
				float(motor_options.get("morphology_interaction_score", NAN)),
				score,
			)
			or not digest.begins_with("sha256:")
			or digest.length() != 71
		):
			return false
		controller_digests[digest] = true
	return low_score_count > 0 and high_score_count > 0 and controller_digests.size() > 2


static func _gq2_policy_and_fail_closed_exact(selection: Array, held_out: Array) -> bool:
	var gq1_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ1)
	var gq2_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ2)
	var first_generation := ProportionSpecScript.compile_gq2_generation(1)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var tampered_digest := first_digest.left(70) + ("0" if first_digest.right(1) != "0" else "1")
	var wrong_type := ProportionSpecScript.compile_gq2_generation(1.0)
	var unknown_index := ProportionSpecScript.compile_gq2_generation(13)
	var tampered := ProportionSpecScript.verify_gq2_generation(1, tampered_digest)
	var invalid_role := (
		ProportionSpecScript
		. gq2_generation_for_morphology(
			"gq2_generated_s001",
			"invalid",
		)
	)
	var wrong_role := (
		ProportionSpecScript
		. gq2_generation_for_morphology(
			"gq2_generated_s001",
			"heldout",
		)
	)
	var unknown_morphology := (
		ProportionSpecScript
		. gq2_generation_for_morphology(
			"gq2_generated_s999",
			"selection",
		)
	)
	return (
		(
			String(gq2_policy.get("schema_version", ""))
			== "sporespore_g4_gq2_complementary_path_generated_morphology_policy_v1"
		)
		and (gq2_policy.get("selection_cells", []) as Array) == selection
		and (gq2_policy.get("held_out_cells", []) as Array) == held_out
		and (
			String(gq2_policy.get("generator_policy_id", ""))
			== ProportionSpecScript.GQ2_GENERATOR_POLICY_ID
		)
		and (
			(gq2_policy.get("selection_generator_indices", []) as Array)
			== ProportionSpecScript.GQ2_SELECTION_INDICES
		)
		and (
			(gq2_policy.get("held_out_generator_indices", []) as Array)
			== ProportionSpecScript.GQ2_HELD_OUT_INDICES
		)
		and (gq2_policy.get("generator_receipts", []) as Array).size() == 20
		and (
			String(gq2_policy.get("path_cross_track_gain_derivation_id", ""))
			== "interaction_score_half_threshold_v1"
		)
		and (
			String(gq2_policy.get("path_cross_track_gain_formula", ""))
			== "1.0 if morphology_interaction_score<0.5 else 0.75"
		)
		and not gq2_policy.has("controller_sha256")
		and (
			CanonicalJsonScript.sha256(gq1_policy)
			== "sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698"
		)
		and CanonicalJsonScript.sha256(gq2_policy) != CanonicalJsonScript.sha256(gq1_policy)
		and not bool(wrong_type.get("ok", true))
		and String(wrong_type.get("failure_code", "")) == "INVALID_GQ2_GENERATOR_INDEX_TYPE"
		and int(wrong_type.get("world_build_count", -1)) == 0
		and not bool(unknown_index.get("ok", true))
		and String(unknown_index.get("failure_code", "")) == "UNKNOWN_GQ2_GENERATOR_INDEX"
		and int(unknown_index.get("world_build_count", -1)) == 0
		and not bool(tampered.get("ok", true))
		and String(tampered.get("failure_code", "")) == "GQ2_GENERATOR_RECEIPT_DIGEST_MISMATCH"
		and int(tampered.get("world_build_count", -1)) == 0
		and not bool(invalid_role.get("ok", true))
		and String(invalid_role.get("failure_code", "")) == "INVALID_GQ2_CAMPAIGN_ROLE"
		and int(invalid_role.get("world_build_count", -1)) == 0
		and not bool(wrong_role.get("ok", true))
		and String(wrong_role.get("failure_code", "")) == "UNKNOWN_GQ2_MORPHOLOGY"
		and int(wrong_role.get("world_build_count", -1)) == 0
		and not bool(unknown_morphology.get("ok", true))
		and String(unknown_morphology.get("failure_code", "")) == "UNKNOWN_GQ2_MORPHOLOGY"
		and int(unknown_morphology.get("world_build_count", -1)) == 0
	)


static func _gq3_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gq3_generated_s013",
		"gq3_generated_s014",
		"gq3_generated_s015",
		"gq3_generated_s016",
		"gq3_generated_s017",
		"gq3_generated_s018",
		"gq3_generated_s019",
		"gq3_generated_s020",
		"gq3_generated_s021",
		"gq3_generated_s022",
		"gq3_generated_s023",
		"gq3_generated_s024",
	]
	var expected_held_out := [
		"gq3_generated_s201",
		"gq3_generated_s202",
		"gq3_generated_s203",
		"gq3_generated_s204",
		"gq3_generated_s205",
		"gq3_generated_s206",
		"gq3_generated_s207",
		"gq3_generated_s208",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		realized_selection.append(String((cell_value as Dictionary)["morphology_id"]))
	for cell_value in held_out:
		realized_held_out.append(String((cell_value as Dictionary)["morphology_id"]))
	return (
		realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			ProportionSpecScript.GQ3_SELECTION_INDICES
			== [13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]
		)
		and ProportionSpecScript.GQ3_HELD_OUT_INDICES == [201, 202, 203, 204, 205, 206, 207, 208]
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq3_generated_s013",
					"selection",
					ProportionSpecScript.CAMPAIGN_GQ3,
				)
			)
			== selection[0]
		)
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq3_generated_s201",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GQ3,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq3_generated_s201",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ3,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq2_generated_s013",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ3,
			)
			. is_empty()
		)
	)


static func _test_radical_inverse(generator_index: int, base: int) -> float:
	var quotient := generator_index
	var place_value := 1.0 / float(base)
	var value := 0.0
	while quotient > 0:
		value += float(quotient % base) * place_value
		quotient = int(quotient / base)
		place_value /= float(base)
	return value


static func _expected_gq3_generation(generator_index: int, campaign_role: String) -> Dictionary:
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": ProportionSpecScript.SCHEMA_VERSION,
		"morphology_id": "gq3_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in ProportionSpecScript.GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(ProportionSpecScript.GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _test_radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = ProportionSpecScript.GQ1_AXIS_INTERVALS[axis_key]
		var reference_value := float(interval[0])
		var lower_endpoint := float(interval[1])
		var upper_endpoint := float(interval[2])
		var endpoint_distance := (
			reference_value - lower_endpoint
			if centered_coordinate < 0.0
			else upper_endpoint - reference_value
		)
		var realized_value := (
			reference_value + shell_fraction * centered_coordinate * endpoint_distance
		)
		proportion_spec[axis_key] = realized_value
		axis_coordinates[axis_key] = {
			"base": axis_base,
			"radical_inverse": radical_inverse,
			"centered_coordinate": centered_coordinate,
			"reference_value": reference_value,
			"lower_endpoint": lower_endpoint,
			"upper_endpoint": upper_endpoint,
			"realized_value": realized_value,
		}
	var generator_receipt := {
		"schema_version": ProportionSpecScript.GQ3_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": ProportionSpecScript.GQ3_GENERATOR_POLICY_ID,
		"campaign_id": ProportionSpecScript.CAMPAIGN_GQ3,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"proportion_spec": proportion_spec,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
	}


static func _gq3_generation_formula_exact(selection: Array, held_out: Array) -> bool:
	var indices := [
		13,
		14,
		15,
		16,
		17,
		18,
		19,
		20,
		21,
		22,
		23,
		24,
		201,
		202,
		203,
		204,
		205,
		206,
		207,
		208,
	]
	var cells := selection + held_out
	var digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var campaign_role := "selection" if cell_index < selection.size() else "heldout"
		var expected := _expected_gq3_generation(generator_index, campaign_role)
		var realized := ProportionSpecScript.compile_gq3_generation(generator_index)
		var digest := String(realized.get("generator_receipt_sha256", ""))
		var verified := ProportionSpecScript.verify_gq3_generation(generator_index, digest)
		if (
			not bool(realized.get("ok", false))
			or int(realized.get("world_build_count", -1)) != 0
			or (realized.get("proportion_spec", {}) as Dictionary) != cells[cell_index]
			or realized.get("proportion_spec", {}) != expected["proportion_spec"]
			or realized.get("generator_receipt", {}) != expected["generator_receipt"]
			or digest != String(expected["generator_receipt_sha256"])
			or not bool(verified.get("ok", false))
			or int(verified.get("world_build_count", -1)) != 0
		):
			return false
		digests[digest] = true
	var old_gq1_request := ProportionSpecScript.compile_gq1_generation(13)
	var old_gq2_request := ProportionSpecScript.compile_gq2_generation(13)
	return (
		digests.size() == indices.size()
		and not bool(old_gq1_request.get("ok", true))
		and String(old_gq1_request.get("failure_code", "")) == "UNKNOWN_GQ1_GENERATOR_INDEX"
		and int(old_gq1_request.get("world_build_count", -1)) == 0
		and not bool(old_gq2_request.get("ok", true))
		and String(old_gq2_request.get("failure_code", "")) == "UNKNOWN_GQ2_GENERATOR_INDEX"
		and int(old_gq2_request.get("world_build_count", -1)) == 0
	)


static func _gq3_path_and_controller_derivation_exact(cells: Array) -> bool:
	var cross_track_gains: Dictionary = {}
	var yaw_gains: Dictionary = {}
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := CampaignScript._morphology_interaction_score(cell)
		var expected_cross_track_gain := 1.0 if score < 0.5 else 0.75
		var expected_yaw_gain := 1.3 if float(cell["foot_radius_scale"]) <= 1.025 else 1.0
		var expected_path := CampaignScript.GQ3_PATH_STEERING_OPTIONS.duplicate(true)
		expected_path["cross_track_heading_gain_rad_per_m"] = expected_cross_track_gain
		expected_path["yaw_error_stride_gain_per_rad"] = expected_yaw_gain
		var path_options := CampaignScript._path_steering_options(CampaignScript.CAMPAIGN_GQ3, cell)
		var motor_options := CampaignScript._motor_velocity_options(
			CampaignScript.CAMPAIGN_GQ3, cell
		)
		var digest := (
			CampaignScript
			. _expected_controller_sha256(
				CampaignScript.CAMPAIGN_GQ3,
				motor_options,
				path_options,
			)
		)
		var renamed := cell.duplicate(true)
		renamed["morphology_id"] = "%s_renamed" % String(cell["morphology_id"])
		if (
			path_options != expected_path
			or not is_equal_approx(
				float(motor_options.get("morphology_interaction_score", NAN)),
				score,
			)
			or (
				CampaignScript._path_steering_options(CampaignScript.CAMPAIGN_GQ3, renamed)
				!= path_options
			)
			or (
				CampaignScript._motor_velocity_options(CampaignScript.CAMPAIGN_GQ3, renamed)
				!= motor_options
			)
			or not digest.begins_with("sha256:")
			or digest.length() != 71
		):
			return false
		cross_track_gains[expected_cross_track_gain] = true
		yaw_gains[expected_yaw_gain] = true
		controller_digests[digest] = true

	var below := ProportionSpecScript.reference_parameters("gq3_boundary_below")
	var exact := ProportionSpecScript.reference_parameters("gq3_boundary_exact")
	var above := ProportionSpecScript.reference_parameters("gq3_boundary_above")
	below["foot_radius_scale"] = 1.024999
	exact["foot_radius_scale"] = 1.025
	above["foot_radius_scale"] = 1.025001
	var below_path := CampaignScript._path_steering_options(CampaignScript.CAMPAIGN_GQ3, below)
	var exact_path := CampaignScript._path_steering_options(CampaignScript.CAMPAIGN_GQ3, exact)
	var above_path := CampaignScript._path_steering_options(CampaignScript.CAMPAIGN_GQ3, above)
	var gq2_exact_path := CampaignScript._path_steering_options(CampaignScript.CAMPAIGN_GQ2, exact)
	return (
		cross_track_gains.size() == 2
		and yaw_gains.size() == 2
		and controller_digests.size() > 2
		and is_equal_approx(float(below_path["yaw_error_stride_gain_per_rad"]), 1.3)
		and is_equal_approx(float(exact_path["yaw_error_stride_gain_per_rad"]), 1.3)
		and is_equal_approx(float(above_path["yaw_error_stride_gain_per_rad"]), 1.0)
		and is_equal_approx(float(gq2_exact_path["yaw_error_stride_gain_per_rad"]), 1.0)
	)


static func _gq3_policy_and_fail_closed_exact(selection: Array, held_out: Array) -> bool:
	var gq1_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ1)
	var gq2_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ2)
	var gq3_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ3)
	var first_generation := ProportionSpecScript.compile_gq3_generation(13)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var tampered_digest := first_digest.left(70) + ("0" if first_digest.right(1) != "0" else "1")
	var wrong_type := ProportionSpecScript.compile_gq3_generation(13.0)
	var unknown_index := ProportionSpecScript.compile_gq3_generation(25)
	var tampered := ProportionSpecScript.verify_gq3_generation(13, tampered_digest)
	var invalid_role := ProportionSpecScript.gq3_generation_for_morphology(
		"gq3_generated_s013", "invalid"
	)
	var wrong_role := ProportionSpecScript.gq3_generation_for_morphology(
		"gq3_generated_s013", "heldout"
	)
	var unknown_morphology := (
		ProportionSpecScript
		. gq3_generation_for_morphology(
			"gq3_generated_s999",
			"selection",
		)
	)
	var gq1_digest := CanonicalJsonScript.sha256(gq1_policy)
	var gq2_digest := CanonicalJsonScript.sha256(gq2_policy)
	var gq3_digest := CanonicalJsonScript.sha256(gq3_policy)
	return (
		(
			String(gq3_policy.get("schema_version", ""))
			== "sporespore_g4_gq3_foot_aware_yaw_generated_morphology_policy_v1"
		)
		and (gq3_policy.get("selection_cells", []) as Array) == selection
		and (gq3_policy.get("held_out_cells", []) as Array) == held_out
		and (
			String(gq3_policy.get("generator_policy_id", ""))
			== ProportionSpecScript.GQ3_GENERATOR_POLICY_ID
		)
		and (
			String(gq3_policy.get("generator_schema_version", ""))
			== ProportionSpecScript.GQ3_GENERATOR_SCHEMA_VERSION
		)
		and (
			(gq3_policy.get("selection_generator_indices", []) as Array)
			== ProportionSpecScript.GQ3_SELECTION_INDICES
		)
		and (
			(gq3_policy.get("held_out_generator_indices", []) as Array)
			== ProportionSpecScript.GQ3_HELD_OUT_INDICES
		)
		and (gq3_policy.get("generator_receipts", []) as Array).size() == 20
		and (
			String(gq3_policy.get("path_cross_track_gain_derivation_id", ""))
			== "interaction_score_half_threshold_v1"
		)
		and (
			String(gq3_policy.get("path_cross_track_gain_formula", ""))
			== "1.0 if morphology_interaction_score<0.5 else 0.75"
		)
		and (
			String(gq3_policy.get("path_yaw_gain_derivation_id", ""))
			== "foot_radius_scale_1p025_threshold_v1"
		)
		and (
			String(gq3_policy.get("path_yaw_gain_formula", ""))
			== "1.3 if foot_radius_scale<=1.025 else 1.0"
		)
		and not gq3_policy.has("controller_sha256")
		and gq1_digest == "sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698"
		and gq2_digest == "sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463"
		and gq3_digest != gq1_digest
		and gq3_digest != gq2_digest
		and not bool(wrong_type.get("ok", true))
		and String(wrong_type.get("failure_code", "")) == "INVALID_GQ3_GENERATOR_INDEX_TYPE"
		and int(wrong_type.get("world_build_count", -1)) == 0
		and not bool(unknown_index.get("ok", true))
		and String(unknown_index.get("failure_code", "")) == "UNKNOWN_GQ3_GENERATOR_INDEX"
		and int(unknown_index.get("world_build_count", -1)) == 0
		and not bool(tampered.get("ok", true))
		and String(tampered.get("failure_code", "")) == "GQ3_GENERATOR_RECEIPT_DIGEST_MISMATCH"
		and int(tampered.get("world_build_count", -1)) == 0
		and not bool(invalid_role.get("ok", true))
		and String(invalid_role.get("failure_code", "")) == "INVALID_GQ3_CAMPAIGN_ROLE"
		and int(invalid_role.get("world_build_count", -1)) == 0
		and not bool(wrong_role.get("ok", true))
		and String(wrong_role.get("failure_code", "")) == "UNKNOWN_GQ3_MORPHOLOGY"
		and int(wrong_role.get("world_build_count", -1)) == 0
		and not bool(unknown_morphology.get("ok", true))
		and String(unknown_morphology.get("failure_code", "")) == "UNKNOWN_GQ3_MORPHOLOGY"
		and int(unknown_morphology.get("world_build_count", -1)) == 0
	)


static func _gq4_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gq4_generated_s025",
		"gq4_generated_s026",
		"gq4_generated_s027",
		"gq4_generated_s028",
		"gq4_generated_s029",
		"gq4_generated_s030",
		"gq4_generated_s031",
		"gq4_generated_s032",
		"gq4_generated_s033",
		"gq4_generated_s034",
		"gq4_generated_s035",
		"gq4_generated_s036",
	]
	var expected_held_out := [
		"gq4_generated_s301",
		"gq4_generated_s302",
		"gq4_generated_s303",
		"gq4_generated_s304",
		"gq4_generated_s305",
		"gq4_generated_s306",
		"gq4_generated_s307",
		"gq4_generated_s308",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		realized_selection.append(String((cell_value as Dictionary)["morphology_id"]))
	for cell_value in held_out:
		realized_held_out.append(String((cell_value as Dictionary)["morphology_id"]))
	return (
		realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			ProportionSpecScript.GQ4_SELECTION_INDICES
			== [25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36]
		)
		and ProportionSpecScript.GQ4_HELD_OUT_INDICES == [301, 302, 303, 304, 305, 306, 307, 308]
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq4_generated_s025",
					"selection",
					ProportionSpecScript.CAMPAIGN_GQ4,
				)
			)
			== selection[0]
		)
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq4_generated_s301",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GQ4,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq4_generated_s301",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ4,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq3_generated_s025",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ4,
			)
			. is_empty()
		)
	)


static func _expected_gq4_generation(generator_index: int, campaign_role: String) -> Dictionary:
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": ProportionSpecScript.SCHEMA_VERSION,
		"morphology_id": "gq4_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in ProportionSpecScript.GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(ProportionSpecScript.GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _test_radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = ProportionSpecScript.GQ1_AXIS_INTERVALS[axis_key]
		var reference_value := float(interval[0])
		var lower_endpoint := float(interval[1])
		var upper_endpoint := float(interval[2])
		var endpoint_distance := (
			reference_value - lower_endpoint
			if centered_coordinate < 0.0
			else upper_endpoint - reference_value
		)
		var realized_value := (
			reference_value + shell_fraction * centered_coordinate * endpoint_distance
		)
		proportion_spec[axis_key] = realized_value
		axis_coordinates[axis_key] = {
			"base": axis_base,
			"radical_inverse": radical_inverse,
			"centered_coordinate": centered_coordinate,
			"reference_value": reference_value,
			"lower_endpoint": lower_endpoint,
			"upper_endpoint": upper_endpoint,
			"realized_value": realized_value,
		}
	var generator_receipt := {
		"schema_version": ProportionSpecScript.GQ4_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": ProportionSpecScript.GQ4_GENERATOR_POLICY_ID,
		"campaign_id": ProportionSpecScript.CAMPAIGN_GQ4,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"proportion_spec": proportion_spec,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
	}


static func _gq4_generation_formula_exact(selection: Array, held_out: Array) -> bool:
	var indices := [
		25,
		26,
		27,
		28,
		29,
		30,
		31,
		32,
		33,
		34,
		35,
		36,
		301,
		302,
		303,
		304,
		305,
		306,
		307,
		308,
	]
	var cells := selection + held_out
	var digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var campaign_role := "selection" if cell_index < selection.size() else "heldout"
		var expected := _expected_gq4_generation(generator_index, campaign_role)
		var realized := ProportionSpecScript.compile_gq4_generation(generator_index)
		var digest := String(realized.get("generator_receipt_sha256", ""))
		var verified := ProportionSpecScript.verify_gq4_generation(generator_index, digest)
		if (
			not bool(realized.get("ok", false))
			or int(realized.get("world_build_count", -1)) != 0
			or (realized.get("proportion_spec", {}) as Dictionary) != cells[cell_index]
			or realized.get("proportion_spec", {}) != expected["proportion_spec"]
			or realized.get("generator_receipt", {}) != expected["generator_receipt"]
			or digest != String(expected["generator_receipt_sha256"])
			or not bool(verified.get("ok", false))
			or int(verified.get("world_build_count", -1)) != 0
		):
			return false
		digests[digest] = true
	var old_gq3_request := ProportionSpecScript.compile_gq3_generation(25)
	return (
		digests.size() == indices.size()
		and not bool(old_gq3_request.get("ok", true))
		and String(old_gq3_request.get("failure_code", "")) == "UNKNOWN_GQ3_GENERATOR_INDEX"
		and int(old_gq3_request.get("world_build_count", -1)) == 0
	)


static func _gq4_path_and_controller_derivation_exact(cells: Array) -> bool:
	var cross_track_gains: Dictionary = {}
	var yaw_gains: Dictionary = {}
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := CampaignScript._morphology_interaction_score(cell)
		var foot_radius_scale := float(cell["foot_radius_scale"])
		var hip_span_scale := float(cell["hip_span_scale"])
		var expected_cross_track_gain := 1.0 if score < 0.5 else 0.75
		var expected_yaw_gain := 1.0
		if foot_radius_scale <= 1.025:
			if foot_radius_scale > 1.01:
				expected_yaw_gain = 1.3
			elif score >= 0.5 and absf(hip_span_scale - 1.0) >= 0.02:
				expected_yaw_gain = 1.25
		var expected_path := CampaignScript.GQ4_PATH_STEERING_OPTIONS.duplicate(true)
		expected_path["cross_track_heading_gain_rad_per_m"] = expected_cross_track_gain
		expected_path["yaw_error_stride_gain_per_rad"] = expected_yaw_gain
		var path_options := CampaignScript._path_steering_options(CampaignScript.CAMPAIGN_GQ4, cell)
		var motor_options := CampaignScript._motor_velocity_options(
			CampaignScript.CAMPAIGN_GQ4, cell
		)
		var digest := (
			CampaignScript
			. _expected_controller_sha256(
				CampaignScript.CAMPAIGN_GQ4,
				motor_options,
				path_options,
			)
		)
		var renamed := cell.duplicate(true)
		renamed["morphology_id"] = "%s_renamed" % String(cell["morphology_id"])
		if (
			path_options != expected_path
			or not is_equal_approx(
				float(motor_options.get("morphology_interaction_score", NAN)),
				score,
			)
			or (
				CampaignScript._path_steering_options(CampaignScript.CAMPAIGN_GQ4, renamed)
				!= path_options
			)
			or (
				CampaignScript._motor_velocity_options(CampaignScript.CAMPAIGN_GQ4, renamed)
				!= motor_options
			)
			or not digest.begins_with("sha256:")
			or digest.length() != 71
		):
			return false
		cross_track_gains[expected_cross_track_gain] = true
		yaw_gains[expected_yaw_gain] = true
		controller_digests[digest] = true

	return (
		cross_track_gains.size() == 2
		and yaw_gains.size() >= 2
		and controller_digests.size() > 2
		and is_equal_approx(CampaignScript._gq4_yaw_gain_per_rad(1.0, 1.025001, 1.1), 1.0)
		and is_equal_approx(CampaignScript._gq4_yaw_gain_per_rad(0.0, 1.025, 1.0), 1.3)
		and is_equal_approx(CampaignScript._gq4_yaw_gain_per_rad(0.0, 1.010001, 1.0), 1.3)
		and is_equal_approx(CampaignScript._gq4_yaw_gain_per_rad(0.5, 1.01, 1.02), 1.25)
		and is_equal_approx(
			CampaignScript._gq4_yaw_gain_per_rad(0.499999, 1.01, 1.02),
			1.0,
		)
		and is_equal_approx(
			CampaignScript._gq4_yaw_gain_per_rad(0.5, 1.01, 1.019999),
			1.0,
		)
		and is_equal_approx(CampaignScript._gq4_yaw_gain_per_rad(0.5, 1.01, 0.98), 1.25)
		and is_equal_approx(CampaignScript._gq4_yaw_gain_per_rad(1.0, 1.0, 1.0), 1.0)
	)


static func _gq4_policy_and_fail_closed_exact(selection: Array, held_out: Array) -> bool:
	var gq1_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ1)
	var gq2_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ2)
	var gq3_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ3)
	var gq4_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ4)
	var first_generation := ProportionSpecScript.compile_gq4_generation(25)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var tampered_digest := first_digest.left(70) + ("0" if first_digest.right(1) != "0" else "1")
	var wrong_type := ProportionSpecScript.compile_gq4_generation(25.0)
	var unknown_index := ProportionSpecScript.compile_gq4_generation(37)
	var tampered := ProportionSpecScript.verify_gq4_generation(25, tampered_digest)
	var invalid_role := ProportionSpecScript.gq4_generation_for_morphology(
		"gq4_generated_s025", "invalid"
	)
	var wrong_role := ProportionSpecScript.gq4_generation_for_morphology(
		"gq4_generated_s025", "heldout"
	)
	var unknown_morphology := (
		ProportionSpecScript
		. gq4_generation_for_morphology(
			"gq4_generated_s999",
			"selection",
		)
	)
	var gq1_digest := CanonicalJsonScript.sha256(gq1_policy)
	var gq2_digest := CanonicalJsonScript.sha256(gq2_policy)
	var gq3_digest := CanonicalJsonScript.sha256(gq3_policy)
	var gq4_digest := CanonicalJsonScript.sha256(gq4_policy)
	return (
		(
			String(gq4_policy.get("schema_version", ""))
			== "sporespore_g4_gq4_score_foot_hip_yaw_generated_morphology_policy_v1"
		)
		and (gq4_policy.get("selection_cells", []) as Array) == selection
		and (gq4_policy.get("held_out_cells", []) as Array) == held_out
		and (
			String(gq4_policy.get("generator_policy_id", ""))
			== ProportionSpecScript.GQ4_GENERATOR_POLICY_ID
		)
		and (
			String(gq4_policy.get("generator_schema_version", ""))
			== ProportionSpecScript.GQ4_GENERATOR_SCHEMA_VERSION
		)
		and (
			(gq4_policy.get("selection_generator_indices", []) as Array)
			== ProportionSpecScript.GQ4_SELECTION_INDICES
		)
		and (
			(gq4_policy.get("held_out_generator_indices", []) as Array)
			== ProportionSpecScript.GQ4_HELD_OUT_INDICES
		)
		and (gq4_policy.get("generator_receipts", []) as Array).size() == 20
		and (
			String(gq4_policy.get("path_cross_track_gain_derivation_id", ""))
			== "interaction_score_half_threshold_v1"
		)
		and (
			String(gq4_policy.get("path_cross_track_gain_formula", ""))
			== "1.0 if morphology_interaction_score<0.5 else 0.75"
		)
		and (
			String(gq4_policy.get("path_yaw_gain_derivation_id", ""))
			== "score_foot_radius_hip_span_piecewise_v1"
		)
		and (
			String(gq4_policy.get("path_yaw_gain_formula", ""))
			== (
				"1.0 if F>1.025 else (1.3 if F>1.01 else "
				+ "(1.25 if S>=0.5 and abs(H-1.0)>=0.02 else 1.0))"
			)
		)
		and not gq4_policy.has("controller_sha256")
		and gq1_digest == "sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698"
		and gq2_digest == "sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463"
		and gq3_digest == "sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253"
		and gq4_digest == "sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38"
		and gq4_digest != gq1_digest
		and gq4_digest != gq2_digest
		and gq4_digest != gq3_digest
		and not bool(wrong_type.get("ok", true))
		and String(wrong_type.get("failure_code", "")) == "INVALID_GQ4_GENERATOR_INDEX_TYPE"
		and int(wrong_type.get("world_build_count", -1)) == 0
		and not bool(unknown_index.get("ok", true))
		and String(unknown_index.get("failure_code", "")) == "UNKNOWN_GQ4_GENERATOR_INDEX"
		and int(unknown_index.get("world_build_count", -1)) == 0
		and not bool(tampered.get("ok", true))
		and String(tampered.get("failure_code", "")) == "GQ4_GENERATOR_RECEIPT_DIGEST_MISMATCH"
		and int(tampered.get("world_build_count", -1)) == 0
		and not bool(invalid_role.get("ok", true))
		and String(invalid_role.get("failure_code", "")) == "INVALID_GQ4_CAMPAIGN_ROLE"
		and int(invalid_role.get("world_build_count", -1)) == 0
		and not bool(wrong_role.get("ok", true))
		and String(wrong_role.get("failure_code", "")) == "UNKNOWN_GQ4_MORPHOLOGY"
		and int(wrong_role.get("world_build_count", -1)) == 0
		and not bool(unknown_morphology.get("ok", true))
		and String(unknown_morphology.get("failure_code", "")) == "UNKNOWN_GQ4_MORPHOLOGY"
		and int(unknown_morphology.get("world_build_count", -1)) == 0
	)


static func _gq5_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gq5_generated_s037",
		"gq5_generated_s038",
		"gq5_generated_s039",
		"gq5_generated_s040",
		"gq5_generated_s041",
		"gq5_generated_s042",
		"gq5_generated_s043",
		"gq5_generated_s044",
		"gq5_generated_s045",
		"gq5_generated_s046",
		"gq5_generated_s047",
		"gq5_generated_s048",
	]
	var expected_held_out := [
		"gq5_generated_s401",
		"gq5_generated_s402",
		"gq5_generated_s403",
		"gq5_generated_s404",
		"gq5_generated_s405",
		"gq5_generated_s406",
		"gq5_generated_s407",
		"gq5_generated_s408",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		realized_selection.append(String((cell_value as Dictionary)["morphology_id"]))
	for cell_value in held_out:
		realized_held_out.append(String((cell_value as Dictionary)["morphology_id"]))
	return (
		realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			ProportionSpecScript.GQ5_SELECTION_INDICES
			== [37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48]
		)
		and ProportionSpecScript.GQ5_HELD_OUT_INDICES == [401, 402, 403, 404, 405, 406, 407, 408]
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq5_generated_s037",
					"selection",
					ProportionSpecScript.CAMPAIGN_GQ5,
				)
			)
			== selection[0]
		)
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq5_generated_s401",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GQ5,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq5_generated_s401",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ5,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq4_generated_s037",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ5,
			)
			. is_empty()
		)
	)


static func _expected_gq5_generation(generator_index: int, campaign_role: String) -> Dictionary:
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": ProportionSpecScript.SCHEMA_VERSION,
		"morphology_id": "gq5_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in ProportionSpecScript.GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(ProportionSpecScript.GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _test_radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = ProportionSpecScript.GQ1_AXIS_INTERVALS[axis_key]
		var reference_value := float(interval[0])
		var lower_endpoint := float(interval[1])
		var upper_endpoint := float(interval[2])
		var endpoint_distance := (
			reference_value - lower_endpoint
			if centered_coordinate < 0.0
			else upper_endpoint - reference_value
		)
		var realized_value := (
			reference_value + shell_fraction * centered_coordinate * endpoint_distance
		)
		proportion_spec[axis_key] = realized_value
		axis_coordinates[axis_key] = {
			"base": axis_base,
			"radical_inverse": radical_inverse,
			"centered_coordinate": centered_coordinate,
			"reference_value": reference_value,
			"lower_endpoint": lower_endpoint,
			"upper_endpoint": upper_endpoint,
			"realized_value": realized_value,
		}
	var generator_receipt := {
		"schema_version": ProportionSpecScript.GQ5_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": ProportionSpecScript.GQ5_GENERATOR_POLICY_ID,
		"campaign_id": ProportionSpecScript.CAMPAIGN_GQ5,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"proportion_spec": proportion_spec,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
	}


static func _gq5_generation_formula_exact(selection: Array, held_out: Array) -> bool:
	var indices := [
		37,
		38,
		39,
		40,
		41,
		42,
		43,
		44,
		45,
		46,
		47,
		48,
		401,
		402,
		403,
		404,
		405,
		406,
		407,
		408,
	]
	var cells := selection + held_out
	var digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var campaign_role := "selection" if cell_index < selection.size() else "heldout"
		var expected := _expected_gq5_generation(generator_index, campaign_role)
		var realized := ProportionSpecScript.compile_gq5_generation(generator_index)
		var digest := String(realized.get("generator_receipt_sha256", ""))
		var verified := ProportionSpecScript.verify_gq5_generation(generator_index, digest)
		if (
			not bool(realized.get("ok", false))
			or int(realized.get("world_build_count", -1)) != 0
			or (realized.get("proportion_spec", {}) as Dictionary) != cells[cell_index]
			or realized.get("proportion_spec", {}) != expected["proportion_spec"]
			or realized.get("generator_receipt", {}) != expected["generator_receipt"]
			or digest != String(expected["generator_receipt_sha256"])
			or not bool(verified.get("ok", false))
			or int(verified.get("world_build_count", -1)) != 0
		):
			return false
		digests[digest] = true
	var old_gq4_request := ProportionSpecScript.compile_gq4_generation(37)
	return (
		digests.size() == indices.size()
		and not bool(old_gq4_request.get("ok", true))
		and String(old_gq4_request.get("failure_code", "")) == "UNKNOWN_GQ4_GENERATOR_INDEX"
		and int(old_gq4_request.get("world_build_count", -1)) == 0
	)


static func _gq5_path_and_controller_derivation_exact(cells: Array) -> bool:
	var cross_track_gains: Dictionary = {}
	var yaw_gains: Dictionary = {}
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := CampaignScript._morphology_interaction_score(cell)
		var foot_radius_scale := float(cell["foot_radius_scale"])
		var hip_span_scale := float(cell["hip_span_scale"])
		var expected_cross_track_gain := 1.0 if score < 0.5 else 0.75
		var expected_yaw_gain := 1.0
		if score >= 0.5 and foot_radius_scale <= 1.025:
			if foot_radius_scale > 1.01:
				expected_yaw_gain = 1.3
			elif absf(hip_span_scale - 1.0) >= 0.02:
				expected_yaw_gain = 1.25
		var expected_path := CampaignScript.GQ5_PATH_STEERING_OPTIONS.duplicate(true)
		expected_path["cross_track_heading_gain_rad_per_m"] = expected_cross_track_gain
		expected_path["yaw_error_stride_gain_per_rad"] = expected_yaw_gain
		var path_options := CampaignScript._path_steering_options(CampaignScript.CAMPAIGN_GQ5, cell)
		var motor_options := CampaignScript._motor_velocity_options(
			CampaignScript.CAMPAIGN_GQ5, cell
		)
		var digest := (
			CampaignScript
			. _expected_controller_sha256(
				CampaignScript.CAMPAIGN_GQ5,
				motor_options,
				path_options,
			)
		)
		var metadata_varied := cell.duplicate(true)
		metadata_varied["morphology_id"] = "%s_renamed" % String(cell["morphology_id"])
		metadata_varied["generator_index"] = 999
		metadata_varied["seed"] = 123456
		metadata_varied["campaign_role"] = "heldout"
		metadata_varied["repetition"] = 3
		if (
			path_options != expected_path
			or not is_equal_approx(
				float(motor_options.get("morphology_interaction_score", NAN)),
				score,
			)
			or (
				(
					CampaignScript
					. _path_steering_options(
						CampaignScript.CAMPAIGN_GQ5,
						metadata_varied,
					)
				)
				!= path_options
			)
			or (
				(
					CampaignScript
					. _motor_velocity_options(
						CampaignScript.CAMPAIGN_GQ5,
						metadata_varied,
					)
				)
				!= motor_options
			)
			or not digest.begins_with("sha256:")
			or digest.length() != 71
		):
			return false
		cross_track_gains[expected_cross_track_gain] = true
		yaw_gains[expected_yaw_gain] = true
		controller_digests[digest] = true

	return (
		cross_track_gains.size() == 2
		and yaw_gains.size() >= 2
		and controller_digests.size() > 2
		and is_equal_approx(CampaignScript._gq5_yaw_gain_per_rad(0.499999, 1.02, 1.02), 1.0)
		and is_equal_approx(CampaignScript._gq5_yaw_gain_per_rad(0.5, 1.02, 1.0), 1.3)
		and is_equal_approx(CampaignScript._gq5_yaw_gain_per_rad(0.5, 1.025, 1.0), 1.3)
		and is_equal_approx(CampaignScript._gq5_yaw_gain_per_rad(0.5, 1.025001, 1.02), 1.0)
		and is_equal_approx(CampaignScript._gq5_yaw_gain_per_rad(0.5, 1.01, 1.02), 1.25)
		and is_equal_approx(
			CampaignScript._gq5_yaw_gain_per_rad(0.5, 1.01, 1.019999),
			1.0,
		)
		and is_equal_approx(CampaignScript._gq5_yaw_gain_per_rad(0.5, 1.01, 0.98), 1.25)
		and is_equal_approx(CampaignScript._gq5_yaw_gain_per_rad(1.0, 1.0, 1.0), 1.0)
	)


static func _gq5_policy_and_fail_closed_exact(selection: Array, held_out: Array) -> bool:
	var gq1_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ1)
	var gq2_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ2)
	var gq3_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ3)
	var gq4_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ4)
	var gq5_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ5)
	var first_generation := ProportionSpecScript.compile_gq5_generation(37)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var tampered_digest := first_digest.left(70) + ("0" if first_digest.right(1) != "0" else "1")
	var wrong_type := ProportionSpecScript.compile_gq5_generation(37.0)
	var unknown_index := ProportionSpecScript.compile_gq5_generation(49)
	var tampered := ProportionSpecScript.verify_gq5_generation(37, tampered_digest)
	var invalid_role := ProportionSpecScript.gq5_generation_for_morphology(
		"gq5_generated_s037", "invalid"
	)
	var wrong_role := ProportionSpecScript.gq5_generation_for_morphology(
		"gq5_generated_s037", "heldout"
	)
	var unknown_morphology := (
		ProportionSpecScript
		. gq5_generation_for_morphology(
			"gq5_generated_s999",
			"selection",
		)
	)
	var gq1_digest := CanonicalJsonScript.sha256(gq1_policy)
	var gq2_digest := CanonicalJsonScript.sha256(gq2_policy)
	var gq3_digest := CanonicalJsonScript.sha256(gq3_policy)
	var gq4_digest := CanonicalJsonScript.sha256(gq4_policy)
	var gq5_digest := CanonicalJsonScript.sha256(gq5_policy)
	return (
		(
			String(gq5_policy.get("schema_version", ""))
			== "sporespore_g4_gq5_score_first_foot_hip_yaw_generated_morphology_policy_v1"
		)
		and (gq5_policy.get("selection_cells", []) as Array) == selection
		and (gq5_policy.get("held_out_cells", []) as Array) == held_out
		and (
			String(gq5_policy.get("generator_policy_id", ""))
			== ProportionSpecScript.GQ5_GENERATOR_POLICY_ID
		)
		and (
			String(gq5_policy.get("generator_schema_version", ""))
			== ProportionSpecScript.GQ5_GENERATOR_SCHEMA_VERSION
		)
		and (
			(gq5_policy.get("selection_generator_indices", []) as Array)
			== ProportionSpecScript.GQ5_SELECTION_INDICES
		)
		and (
			(gq5_policy.get("held_out_generator_indices", []) as Array)
			== ProportionSpecScript.GQ5_HELD_OUT_INDICES
		)
		and (gq5_policy.get("generator_receipts", []) as Array).size() == 20
		and (
			String(gq5_policy.get("path_cross_track_gain_derivation_id", ""))
			== "interaction_score_half_threshold_v1"
		)
		and (
			String(gq5_policy.get("path_cross_track_gain_formula", ""))
			== "1.0 if morphology_interaction_score<0.5 else 0.75"
		)
		and (
			String(gq5_policy.get("path_yaw_gain_derivation_id", ""))
			== "score_first_foot_radius_hip_span_piecewise_v1"
		)
		and (
			String(gq5_policy.get("path_yaw_gain_formula", ""))
			== (
				"1.0 if S<0.5 or F>1.025 else (1.3 if F>1.01 else "
				+ "(1.25 if abs(H-1.0)>=0.02 else 1.0))"
			)
		)
		and not gq5_policy.has("controller_sha256")
		and gq1_digest == "sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698"
		and gq2_digest == "sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463"
		and gq3_digest == "sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253"
		and gq4_digest == "sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38"
		and gq5_digest != gq1_digest
		and gq5_digest != gq2_digest
		and gq5_digest != gq3_digest
		and gq5_digest != gq4_digest
		and not bool(wrong_type.get("ok", true))
		and String(wrong_type.get("failure_code", "")) == "INVALID_GQ5_GENERATOR_INDEX_TYPE"
		and int(wrong_type.get("world_build_count", -1)) == 0
		and not bool(unknown_index.get("ok", true))
		and String(unknown_index.get("failure_code", "")) == "UNKNOWN_GQ5_GENERATOR_INDEX"
		and int(unknown_index.get("world_build_count", -1)) == 0
		and not bool(tampered.get("ok", true))
		and String(tampered.get("failure_code", "")) == "GQ5_GENERATOR_RECEIPT_DIGEST_MISMATCH"
		and int(tampered.get("world_build_count", -1)) == 0
		and not bool(invalid_role.get("ok", true))
		and String(invalid_role.get("failure_code", "")) == "INVALID_GQ5_CAMPAIGN_ROLE"
		and int(invalid_role.get("world_build_count", -1)) == 0
		and not bool(wrong_role.get("ok", true))
		and String(wrong_role.get("failure_code", "")) == "UNKNOWN_GQ5_MORPHOLOGY"
		and int(wrong_role.get("world_build_count", -1)) == 0
		and not bool(unknown_morphology.get("ok", true))
		and String(unknown_morphology.get("failure_code", "")) == "UNKNOWN_GQ5_MORPHOLOGY"
		and int(unknown_morphology.get("world_build_count", -1)) == 0
	)


static func _gq6_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gq6_generated_s049",
		"gq6_generated_s050",
		"gq6_generated_s051",
		"gq6_generated_s052",
		"gq6_generated_s053",
		"gq6_generated_s054",
		"gq6_generated_s055",
		"gq6_generated_s056",
		"gq6_generated_s057",
		"gq6_generated_s058",
		"gq6_generated_s059",
		"gq6_generated_s060",
	]
	var expected_held_out := [
		"gq6_generated_s501",
		"gq6_generated_s502",
		"gq6_generated_s503",
		"gq6_generated_s504",
		"gq6_generated_s505",
		"gq6_generated_s506",
		"gq6_generated_s507",
		"gq6_generated_s508",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		realized_selection.append(String((cell_value as Dictionary)["morphology_id"]))
	for cell_value in held_out:
		realized_held_out.append(String((cell_value as Dictionary)["morphology_id"]))
	var index_set: Dictionary = {}
	for generator_index in ProportionSpecScript.GQ6_SELECTION_INDICES:
		index_set[int(generator_index)] = true
	for generator_index in ProportionSpecScript.GQ6_HELD_OUT_INDICES:
		if index_set.has(int(generator_index)):
			return false
		index_set[int(generator_index)] = true
	return (
		selection.size() == 12
		and held_out.size() == 8
		and realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			ProportionSpecScript.GQ6_SELECTION_INDICES
			== [49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60]
		)
		and ProportionSpecScript.GQ6_HELD_OUT_INDICES == [501, 502, 503, 504, 505, 506, 507, 508]
		and index_set.size() == 20
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq6_generated_s049",
					"selection",
					ProportionSpecScript.CAMPAIGN_GQ6,
				)
			)
			== selection[0]
		)
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq6_generated_s501",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GQ6,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq6_generated_s501",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ6,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq5_generated_s049",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ6,
			)
			. is_empty()
		)
	)


static func _expected_gq6_generation(generator_index: int, campaign_role: String) -> Dictionary:
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": ProportionSpecScript.SCHEMA_VERSION,
		"morphology_id": "gq6_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in ProportionSpecScript.GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(ProportionSpecScript.GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _test_radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = ProportionSpecScript.GQ1_AXIS_INTERVALS[axis_key]
		var reference_value := float(interval[0])
		var lower_endpoint := float(interval[1])
		var upper_endpoint := float(interval[2])
		var endpoint_distance := (
			reference_value - lower_endpoint
			if centered_coordinate < 0.0
			else upper_endpoint - reference_value
		)
		var realized_value := (
			reference_value + shell_fraction * centered_coordinate * endpoint_distance
		)
		proportion_spec[axis_key] = realized_value
		axis_coordinates[axis_key] = {
			"base": axis_base,
			"radical_inverse": radical_inverse,
			"centered_coordinate": centered_coordinate,
			"reference_value": reference_value,
			"lower_endpoint": lower_endpoint,
			"upper_endpoint": upper_endpoint,
			"realized_value": realized_value,
		}
	var generator_receipt := {
		"schema_version": ProportionSpecScript.GQ6_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": ProportionSpecScript.GQ6_GENERATOR_POLICY_ID,
		"campaign_id": ProportionSpecScript.CAMPAIGN_GQ6,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"proportion_spec": proportion_spec,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
	}


static func _gq6_generation_formula_exact(selection: Array, held_out: Array) -> bool:
	var indices := [
		49,
		50,
		51,
		52,
		53,
		54,
		55,
		56,
		57,
		58,
		59,
		60,
		501,
		502,
		503,
		504,
		505,
		506,
		507,
		508,
	]
	var cells := selection + held_out
	var digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var campaign_role := "selection" if cell_index < selection.size() else "heldout"
		var expected := _expected_gq6_generation(generator_index, campaign_role)
		var realized := ProportionSpecScript.compile_gq6_generation(generator_index)
		var digest := String(realized.get("generator_receipt_sha256", ""))
		var verified := ProportionSpecScript.verify_gq6_generation(generator_index, digest)
		if (
			not bool(realized.get("ok", false))
			or int(realized.get("world_build_count", -1)) != 0
			or (realized.get("proportion_spec", {}) as Dictionary) != cells[cell_index]
			or realized.get("proportion_spec", {}) != expected["proportion_spec"]
			or realized.get("generator_receipt", {}) != expected["generator_receipt"]
			or digest != String(expected["generator_receipt_sha256"])
			or not bool(verified.get("ok", false))
			or int(verified.get("world_build_count", -1)) != 0
		):
			return false
		digests[digest] = true
	var old_gq5_request := ProportionSpecScript.compile_gq5_generation(49)
	return (
		digests.size() == indices.size()
		and not bool(old_gq5_request.get("ok", true))
		and String(old_gq5_request.get("failure_code", "")) == "UNKNOWN_GQ5_GENERATOR_INDEX"
		and int(old_gq5_request.get("world_build_count", -1)) == 0
	)


static func _test_morphology_interaction_score(cell: Dictionary) -> float:
	var normalized_absolute_deviations := [
		absf((float(cell["torso_length_scale"]) - 1.0) / 0.10),
		absf((float(cell["torso_width_scale"]) - 1.0) / 0.10),
		absf((float(cell["upper_length_fraction"]) - (18.0 / 35.0)) / 0.05),
		absf((float(cell["hip_span_scale"]) - 1.0) / 0.10),
		absf((float(cell["foot_radius_scale"]) - 1.0) / 0.10),
		absf((float(cell["front_limb_mass_scale"]) - 1.0) / 0.10),
	]
	var pairwise_product_sum := 0.0
	for first_index in range(normalized_absolute_deviations.size()):
		for second_index in range(first_index + 1, normalized_absolute_deviations.size()):
			pairwise_product_sum += (
				float(normalized_absolute_deviations[first_index])
				* float(normalized_absolute_deviations[second_index])
			)
	return clampf(pairwise_product_sum, 0.0, 1.0)


static func _test_gq6_yaw_gain(
	score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if foot_radius_scale < 0.985:
		return 1.3 if score >= 0.9 else 1.1
	if score < 0.5 or foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if absf(hip_span_scale - 1.0) >= 0.02:
		return 1.1 if torso_length_scale > 1.02 else 1.0
	return 1.0


static func _test_gq6_velocity_gain(
	score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	yaw_gain: float,
) -> float:
	if yaw_gain > 1.0:
		return 0.20
	if score < 0.15:
		return 0.20 if torso_width_scale <= 1.0 else 0.25
	if score < 0.5:
		return 0.30 if torso_width_scale <= 1.0 else 0.20
	return 0.20 if torso_width_scale > 1.0 and torso_length_scale < 1.0 else 0.25


static func _gq6_controller_derivation_and_boundaries_exact(cells: Array) -> bool:
	var cross_track_gains: Dictionary = {}
	var yaw_gains: Dictionary = {}
	var velocity_gains: Dictionary = {}
	var guard_fractions: Dictionary = {}
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := _test_morphology_interaction_score(cell)
		var torso_length_scale := float(cell["torso_length_scale"])
		var torso_width_scale := float(cell["torso_width_scale"])
		var foot_radius_scale := float(cell["foot_radius_scale"])
		var hip_span_scale := float(cell["hip_span_scale"])
		var expected_cross_track_gain := 1.0 if score < 0.5 else 0.75
		var expected_yaw_gain := _test_gq6_yaw_gain(
			score,
			torso_length_scale,
			foot_radius_scale,
			hip_span_scale,
		)
		var expected_velocity_gain := _test_gq6_velocity_gain(
			score,
			torso_length_scale,
			torso_width_scale,
			expected_yaw_gain,
		)
		var expected_path := CampaignScript.GQ6_PATH_STEERING_OPTIONS.duplicate(true)
		expected_path["cross_track_heading_gain_rad_per_m"] = expected_cross_track_gain
		expected_path["yaw_error_stride_gain_per_rad"] = expected_yaw_gain
		expected_path["cross_track_velocity_heading_gain_rad_per_m_s"] = expected_velocity_gain
		var expected_guard_fraction := 0.80 if score >= 0.5 else 0.90
		var expected_guard_speed := 2.0 if score >= 0.5 else 2.5
		var path_options := CampaignScript._path_steering_options(CampaignScript.CAMPAIGN_GQ6, cell)
		var motor_options := (
			CampaignScript
			. _motor_velocity_options(
				CampaignScript.CAMPAIGN_GQ6,
				cell,
			)
		)
		var digest := (
			CampaignScript
			. _expected_controller_sha256(
				CampaignScript.CAMPAIGN_GQ6,
				motor_options,
				path_options,
			)
		)
		var metadata_varied := cell.duplicate(true)
		metadata_varied["morphology_id"] = "%s_renamed" % String(cell["morphology_id"])
		metadata_varied["generator_index"] = 999
		metadata_varied["seed"] = 123456
		metadata_varied["campaign_role"] = "heldout"
		metadata_varied["repetition"] = 3
		metadata_varied["walking_observed"] = false
		if (
			path_options != expected_path
			or not is_equal_approx(
				float(motor_options.get("morphology_interaction_score", NAN)),
				score,
			)
			or not is_equal_approx(
				float(motor_options.get("anchor_error_guard_activation_fraction", NAN)),
				expected_guard_fraction,
			)
			or not is_equal_approx(
				float(
					(
						motor_options
						. get(
							"anchor_error_guard_maximum_motor_target_speed_rad_s",
							NAN,
						)
					)
				),
				expected_guard_speed,
			)
			or (
				(
					CampaignScript
					. _path_steering_options(
						CampaignScript.CAMPAIGN_GQ6,
						metadata_varied,
					)
				)
				!= path_options
			)
			or (
				(
					CampaignScript
					. _motor_velocity_options(
						CampaignScript.CAMPAIGN_GQ6,
						metadata_varied,
					)
				)
				!= motor_options
			)
			or not digest.begins_with("sha256:")
			or digest.length() != 71
		):
			return false
		cross_track_gains[expected_cross_track_gain] = true
		yaw_gains[expected_yaw_gain] = true
		velocity_gains[expected_velocity_gain] = true
		guard_fractions[expected_guard_fraction] = true
		controller_digests[digest] = true
	var valid_path := CampaignScript.GQ6_PATH_STEERING_OPTIONS.duplicate(true)
	var valid_path_result := WaveGaitScript._normalize_path_steering_options(valid_path, 360)
	var nonfinite_path := valid_path.duplicate(true)
	nonfinite_path["cross_track_velocity_heading_gain_rad_per_m_s"] = INF
	var nonfinite_path_result := (
		WaveGaitScript
		. _normalize_path_steering_options(
			nonfinite_path,
			360,
		)
	)
	var unknown_path := valid_path.duplicate(true)
	unknown_path["runtime_outcome_gain"] = 0.2
	var unknown_path_result := WaveGaitScript._normalize_path_steering_options(unknown_path, 360)
	return (
		cross_track_gains.size() == 2
		and yaw_gains.size() >= 2
		and velocity_gains.size() >= 2
		and guard_fractions.size() == 2
		and controller_digests.size() > 2
		and bool(valid_path_result.get("ok", false))
		and (valid_path_result.get("path_steering_options", {}) as Dictionary) == valid_path
		and not bool(nonfinite_path_result.get("ok", true))
		and int(nonfinite_path_result.get("world_build_count", -1)) == 0
		and not bool(unknown_path_result.get("ok", true))
		and String(unknown_path_result.get("failure_code", "")) == "UNKNOWN_PATH_STEERING_OPTION"
		and int(unknown_path_result.get("world_build_count", -1)) == 0
		and is_equal_approx(CampaignScript._gq6_cross_track_gain_per_m(0.499999), 1.0)
		and is_equal_approx(CampaignScript._gq6_cross_track_gain_per_m(0.5), 0.75)
		and is_equal_approx(CampaignScript._gq6_yaw_gain_per_rad(0.899999, 1.0, 0.984999, 1.0), 1.1)
		and is_equal_approx(CampaignScript._gq6_yaw_gain_per_rad(0.9, 1.0, 0.984999, 1.0), 1.3)
		and is_equal_approx(CampaignScript._gq6_yaw_gain_per_rad(0.1, 1.0, 0.985, 1.0), 1.0)
		and is_equal_approx(CampaignScript._gq6_yaw_gain_per_rad(0.5, 1.0, 1.025, 1.0), 1.3)
		and is_equal_approx(CampaignScript._gq6_yaw_gain_per_rad(0.5, 1.0, 1.025001, 1.0), 1.0)
		and is_equal_approx(CampaignScript._gq6_yaw_gain_per_rad(0.5, 1.020001, 1.01, 1.02), 1.1)
		and is_equal_approx(CampaignScript._gq6_yaw_gain_per_rad(0.5, 1.02, 1.01, 1.02), 1.0)
		and is_equal_approx(CampaignScript._gq6_yaw_gain_per_rad(0.5, 1.1, 1.01, 1.019999), 1.0)
		and is_equal_approx(CampaignScript._gq6_velocity_gain_rad_per_m_s(1.0, 1.0, 1.0, 1.1), 0.20)
		and is_equal_approx(
			CampaignScript._gq6_velocity_gain_rad_per_m_s(0.149999, 1.0, 1.0, 1.0), 0.20
		)
		and is_equal_approx(
			CampaignScript._gq6_velocity_gain_rad_per_m_s(0.149999, 1.0, 1.000001, 1.0), 0.25
		)
		and is_equal_approx(
			CampaignScript._gq6_velocity_gain_rad_per_m_s(0.15, 1.0, 1.0, 1.0), 0.30
		)
		and is_equal_approx(
			CampaignScript._gq6_velocity_gain_rad_per_m_s(0.15, 1.0, 1.000001, 1.0), 0.20
		)
		and is_equal_approx(
			CampaignScript._gq6_velocity_gain_rad_per_m_s(0.5, 0.999999, 1.000001, 1.0), 0.20
		)
		and is_equal_approx(
			CampaignScript._gq6_velocity_gain_rad_per_m_s(0.5, 1.0, 1.000001, 1.0), 0.25
		)
		and CampaignScript._gq6_motor_guard_values(0.499999) == [0.90, 2.5]
		and CampaignScript._gq6_motor_guard_values(0.5) == [0.80, 2.0]
	)


static func _gq6_clock_solver_and_thresholds_exact(compiled_cells: Array) -> bool:
	if compiled_cells.is_empty():
		return false
	var clock := ClockSpecScript.gq6_clock()
	var clock_result := ClockSpecScript.compile(clock)
	var bad_clock := clock.duplicate(true)
	bad_clock["evidence_cycles"] = 3
	var bad_clock_result := ClockSpecScript.compile(bad_clock)
	var solver_result := (
		WaveGaitScript
		. compile_solver_policy_options(
			CampaignScript.GP4_SOLVER_POLICY_OPTIONS,
		)
	)
	var fixture: Dictionary = (compiled_cells[0] as Dictionary)["fixture_spec"]
	var torso: Dictionary = fixture["torso"]
	var torso_size: Array = torso["size_m"]
	var first_limb: Dictionary = (fixture["limbs"] as Array)[0]
	var thresholds := (
		CampaignScript
		. _evidence_thresholds(
			fixture,
			CampaignScript.CAMPAIGN_GQ6,
		)
	)
	var threshold_result := WaveGaitScript.compile_evidence_threshold_options(thresholds)
	var unknown_threshold := thresholds.duplicate(true)
	unknown_threshold["relax_after_failure"] = true
	var unknown_threshold_result := (
		WaveGaitScript
		. compile_evidence_threshold_options(
			unknown_threshold,
		)
	)
	return (
		bool(clock_result.get("ok", false))
		and int(clock_result.get("world_build_count", -1)) == 0
		and (clock_result.get("gait_clock_options", {}) as Dictionary) == clock
		and String(clock.get("policy_id", "")) == ClockSpecScript.GQ6_POLICY_ID
		and int(clock.get("cycle_ticks", -1)) == 360
		and int(clock.get("evidence_cycles", -1)) == 4
		and int(clock.get("maximum_contact_gate_hold_ticks", -1)) == 120
		and int(clock.get("maximum_contact_gated_evidence_extension_ticks", -1)) == 720
		and int(clock.get("maximum_contact_gated_phase_skew_ticks", -1)) == 12
		and not bool(bad_clock_result.get("ok", true))
		and int(bad_clock_result.get("world_build_count", -1)) == 0
		and bool(solver_result.get("ok", false))
		and int(solver_result.get("world_build_count", -1)) == 0
		and (
			(solver_result.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_velocity_steps"]) == 20
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_position_steps"]) == 7
		and bool(threshold_result.get("ok", false))
		and int(threshold_result.get("world_build_count", -1)) == 0
		and ((threshold_result.get("evidence_threshold_options", {}) as Dictionary) == thresholds)
		and (
			String(thresholds.get("evidence_threshold_policy_id", ""))
			== "nonuniform_dimensionless_thresholds_v1"
		)
		and is_equal_approx(
			float(thresholds.get("minimum_foot_relocation_m", NAN)),
			0.0238 * float(torso_size[0]),
		)
		and is_equal_approx(
			float(thresholds.get("maximum_anchor_error_m", NAN)),
			0.14 * float(first_limb["upper_length_m"]),
		)
		and is_equal_approx(
			float(thresholds.get("minimum_evidence_torso_advance_m", NAN)),
			0.080 * float(torso_size[0]),
		)
		and is_equal_approx(
			float(thresholds.get("minimum_final_torso_advance_m", NAN)),
			0.060 * float(torso_size[0]),
		)
		and not bool(unknown_threshold_result.get("ok", true))
		and int(unknown_threshold_result.get("world_build_count", -1)) == 0
	)


static func _gq6_policy_preservation_and_fail_closed_exact(
	selection: Array,
	held_out: Array,
) -> bool:
	var gq1_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ1)
	var gq2_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ2)
	var gq3_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ3)
	var gq4_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ4)
	var gq5_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ5)
	var gq6_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ6)
	var gq1_digest := CanonicalJsonScript.sha256(gq1_policy)
	var gq2_digest := CanonicalJsonScript.sha256(gq2_policy)
	var gq3_digest := CanonicalJsonScript.sha256(gq3_policy)
	var gq4_digest := CanonicalJsonScript.sha256(gq4_policy)
	var gq5_digest := CanonicalJsonScript.sha256(gq5_policy)
	var gq6_digest := CanonicalJsonScript.sha256(gq6_policy)
	var first_generation := ProportionSpecScript.compile_gq6_generation(49)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var tampered_digest := first_digest.left(70) + ("0" if first_digest.right(1) != "0" else "1")
	var wrong_type := ProportionSpecScript.compile_gq6_generation(49.0)
	var unknown_index := ProportionSpecScript.compile_gq6_generation(61)
	var tampered := ProportionSpecScript.verify_gq6_generation(49, tampered_digest)
	var invalid_role := (
		ProportionSpecScript
		. gq6_generation_for_morphology(
			"gq6_generated_s049",
			"invalid",
		)
	)
	var wrong_role := (
		ProportionSpecScript
		. gq6_generation_for_morphology(
			"gq6_generated_s049",
			"heldout",
		)
	)
	var unknown_morphology := (
		ProportionSpecScript
		. gq6_generation_for_morphology(
			"gq6_generated_s999",
			"selection",
		)
	)
	return (
		(
			String(gq6_policy.get("schema_version", ""))
			== "sporespore_g4_gq6_morphology_adaptive_velocity_feedback_policy_v1"
		)
		and String(gq6_policy.get("campaign_id", "")) == CampaignScript.CAMPAIGN_GQ6
		and (gq6_policy.get("selection_cells", []) as Array) == selection
		and (gq6_policy.get("held_out_cells", []) as Array) == held_out
		and (
			String(gq6_policy.get("generator_policy_id", ""))
			== ProportionSpecScript.GQ6_GENERATOR_POLICY_ID
		)
		and (
			String(gq6_policy.get("generator_schema_version", ""))
			== ProportionSpecScript.GQ6_GENERATOR_SCHEMA_VERSION
		)
		and (
			(gq6_policy.get("selection_generator_indices", []) as Array)
			== ProportionSpecScript.GQ6_SELECTION_INDICES
		)
		and (
			(gq6_policy.get("held_out_generator_indices", []) as Array)
			== ProportionSpecScript.GQ6_HELD_OUT_INDICES
		)
		and (gq6_policy.get("generator_receipts", []) as Array).size() == 20
		and String(gq6_policy.get("clock_policy_id", "")) == ClockSpecScript.GQ6_POLICY_ID
		and ((gq6_policy.get("clock_options", {}) as Dictionary) == ClockSpecScript.gq6_clock())
		and (
			(gq6_policy.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and (
			(gq6_policy.get("robustness_options", {}) as Dictionary)
			== CampaignScript.GQ6_ROBUSTNESS_OPTIONS
		)
		and not gq6_policy.has("controller_sha256")
		and gq1_digest == "sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698"
		and gq2_digest == "sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463"
		and gq3_digest == "sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253"
		and gq4_digest == "sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38"
		and gq5_digest == "sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb"
		and gq6_digest.begins_with("sha256:")
		and gq6_digest.length() == 71
		and gq6_digest not in [gq1_digest, gq2_digest, gq3_digest, gq4_digest, gq5_digest]
		and not bool(wrong_type.get("ok", true))
		and String(wrong_type.get("failure_code", "")) == "INVALID_GQ6_GENERATOR_INDEX_TYPE"
		and int(wrong_type.get("world_build_count", -1)) == 0
		and not bool(unknown_index.get("ok", true))
		and String(unknown_index.get("failure_code", "")) == "UNKNOWN_GQ6_GENERATOR_INDEX"
		and int(unknown_index.get("world_build_count", -1)) == 0
		and not bool(tampered.get("ok", true))
		and String(tampered.get("failure_code", "")) == "GQ6_GENERATOR_RECEIPT_DIGEST_MISMATCH"
		and int(tampered.get("world_build_count", -1)) == 0
		and not bool(invalid_role.get("ok", true))
		and String(invalid_role.get("failure_code", "")) == "INVALID_GQ6_CAMPAIGN_ROLE"
		and int(invalid_role.get("world_build_count", -1)) == 0
		and not bool(wrong_role.get("ok", true))
		and String(wrong_role.get("failure_code", "")) == "UNKNOWN_GQ6_MORPHOLOGY"
		and int(wrong_role.get("world_build_count", -1)) == 0
		and not bool(unknown_morphology.get("ok", true))
		and String(unknown_morphology.get("failure_code", "")) == "UNKNOWN_GQ6_MORPHOLOGY"
		and int(unknown_morphology.get("world_build_count", -1)) == 0
	)


static func _gq7_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gq7_generated_s061",
		"gq7_generated_s062",
		"gq7_generated_s063",
		"gq7_generated_s064",
		"gq7_generated_s065",
		"gq7_generated_s066",
		"gq7_generated_s067",
		"gq7_generated_s068",
		"gq7_generated_s069",
		"gq7_generated_s070",
		"gq7_generated_s071",
		"gq7_generated_s072",
	]
	var expected_held_out := [
		"gq7_generated_s601",
		"gq7_generated_s602",
		"gq7_generated_s603",
		"gq7_generated_s604",
		"gq7_generated_s605",
		"gq7_generated_s606",
		"gq7_generated_s607",
		"gq7_generated_s608",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		realized_selection.append(String((cell_value as Dictionary)["morphology_id"]))
	for cell_value in held_out:
		realized_held_out.append(String((cell_value as Dictionary)["morphology_id"]))
	var index_set: Dictionary = {}
	for generator_index in ProportionSpecScript.GQ7_SELECTION_INDICES:
		index_set[int(generator_index)] = true
	for generator_index in ProportionSpecScript.GQ7_HELD_OUT_INDICES:
		if index_set.has(int(generator_index)):
			return false
		index_set[int(generator_index)] = true
	return (
		selection.size() == 12
		and held_out.size() == 8
		and realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			ProportionSpecScript.GQ7_SELECTION_INDICES
			== [61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72]
		)
		and ProportionSpecScript.GQ7_HELD_OUT_INDICES == [601, 602, 603, 604, 605, 606, 607, 608]
		and index_set.size() == 20
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq7_generated_s061",
					"selection",
					ProportionSpecScript.CAMPAIGN_GQ7,
				)
			)
			== selection[0]
		)
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq7_generated_s601",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GQ7,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq7_generated_s601",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ7,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq6_generated_s061",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ7,
			)
			. is_empty()
		)
	)


static func _expected_gq7_generation(generator_index: int, campaign_role: String) -> Dictionary:
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": ProportionSpecScript.SCHEMA_VERSION,
		"morphology_id": "gq7_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in ProportionSpecScript.GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(ProportionSpecScript.GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _test_radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = ProportionSpecScript.GQ1_AXIS_INTERVALS[axis_key]
		var reference_value := float(interval[0])
		var lower_endpoint := float(interval[1])
		var upper_endpoint := float(interval[2])
		var endpoint_distance := (
			reference_value - lower_endpoint
			if centered_coordinate < 0.0
			else upper_endpoint - reference_value
		)
		var realized_value := (
			reference_value + shell_fraction * centered_coordinate * endpoint_distance
		)
		proportion_spec[axis_key] = realized_value
		axis_coordinates[axis_key] = {
			"base": axis_base,
			"radical_inverse": radical_inverse,
			"centered_coordinate": centered_coordinate,
			"reference_value": reference_value,
			"lower_endpoint": lower_endpoint,
			"upper_endpoint": upper_endpoint,
			"realized_value": realized_value,
		}
	var generator_receipt := {
		"schema_version": ProportionSpecScript.GQ7_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": ProportionSpecScript.GQ7_GENERATOR_POLICY_ID,
		"campaign_id": ProportionSpecScript.CAMPAIGN_GQ7,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"proportion_spec": proportion_spec,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
	}


static func _gq7_generation_formula_exact(selection: Array, held_out: Array) -> bool:
	var indices := [
		61,
		62,
		63,
		64,
		65,
		66,
		67,
		68,
		69,
		70,
		71,
		72,
		601,
		602,
		603,
		604,
		605,
		606,
		607,
		608,
	]
	var cells := selection + held_out
	var digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var campaign_role := "selection" if cell_index < selection.size() else "heldout"
		var expected := _expected_gq7_generation(generator_index, campaign_role)
		var realized := ProportionSpecScript.compile_gq7_generation(generator_index)
		var digest := String(realized.get("generator_receipt_sha256", ""))
		var verified := ProportionSpecScript.verify_gq7_generation(generator_index, digest)
		if (
			not bool(realized.get("ok", false))
			or int(realized.get("world_build_count", -1)) != 0
			or (realized.get("proportion_spec", {}) as Dictionary) != cells[cell_index]
			or realized.get("proportion_spec", {}) != expected["proportion_spec"]
			or realized.get("generator_receipt", {}) != expected["generator_receipt"]
			or digest != String(expected["generator_receipt_sha256"])
			or not bool(verified.get("ok", false))
			or int(verified.get("world_build_count", -1)) != 0
		):
			return false
		digests[digest] = true
	var old_gq6_request := ProportionSpecScript.compile_gq6_generation(61)
	return (
		digests.size() == indices.size()
		and not bool(old_gq6_request.get("ok", true))
		and String(old_gq6_request.get("failure_code", "")) == "UNKNOWN_GQ6_GENERATOR_INDEX"
		and int(old_gq6_request.get("world_build_count", -1)) == 0
	)


static func _test_gq7_yaw_gain(
	score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if foot_radius_scale < 0.985:
		return 1.3 if score >= 0.9 else 1.1
	if score < 0.5 or foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if absf(hip_span_scale - 1.0) >= 0.02:
		return 1.1 if torso_length_scale > 1.02 else 1.0
	return 1.0


static func _test_gq7_velocity_gain(
	score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	yaw_gain: float,
) -> float:
	if yaw_gain > 1.0:
		return 0.20
	if score < 0.15:
		return 0.20 if torso_width_scale <= 1.0 else 0.25
	if score < 0.5:
		return 0.30 if torso_width_scale <= 1.0 else 0.20
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((score - 0.5) / 0.5, 0.0, 1.0)
	return 0.25


static func _gq7_controller_derivation_and_boundaries_exact(cells: Array) -> bool:
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := _test_morphology_interaction_score(cell)
		var torso_length_scale := float(cell["torso_length_scale"])
		var torso_width_scale := float(cell["torso_width_scale"])
		var foot_radius_scale := float(cell["foot_radius_scale"])
		var hip_span_scale := float(cell["hip_span_scale"])
		var expected_cross_track_gain := 1.0 if score < 0.5 else 0.75
		var expected_yaw_gain := _test_gq7_yaw_gain(
			score,
			torso_length_scale,
			foot_radius_scale,
			hip_span_scale,
		)
		var expected_velocity_gain := _test_gq7_velocity_gain(
			score,
			torso_length_scale,
			torso_width_scale,
			expected_yaw_gain,
		)
		var expected_path := CampaignScript.GQ7_PATH_STEERING_OPTIONS.duplicate(true)
		expected_path["cross_track_heading_gain_rad_per_m"] = expected_cross_track_gain
		expected_path["yaw_error_stride_gain_per_rad"] = expected_yaw_gain
		expected_path["cross_track_velocity_heading_gain_rad_per_m_s"] = expected_velocity_gain
		var expected_guard_fraction := 0.80 if score >= 0.5 else 0.90
		var expected_guard_speed := 2.0 if score >= 0.5 else 2.5
		var path_options := CampaignScript._path_steering_options(CampaignScript.CAMPAIGN_GQ7, cell)
		var motor_options := (
			CampaignScript
			. _motor_velocity_options(
				CampaignScript.CAMPAIGN_GQ7,
				cell,
			)
		)
		var digest := (
			CampaignScript
			. _expected_controller_sha256(
				CampaignScript.CAMPAIGN_GQ7,
				motor_options,
				path_options,
			)
		)
		var metadata_varied := cell.duplicate(true)
		metadata_varied["morphology_id"] = "%s_renamed" % String(cell["morphology_id"])
		metadata_varied["generator_index"] = 999
		metadata_varied["seed"] = 123456
		metadata_varied["campaign_role"] = "heldout"
		metadata_varied["repetition"] = 3
		metadata_varied["walking_observed"] = false
		if (
			path_options != expected_path
			or not is_equal_approx(
				float(motor_options.get("morphology_interaction_score", NAN)),
				score,
			)
			or not is_equal_approx(
				float(motor_options.get("anchor_error_guard_activation_fraction", NAN)),
				expected_guard_fraction,
			)
			or not is_equal_approx(
				float(
					(
						motor_options
						. get(
							"anchor_error_guard_maximum_motor_target_speed_rad_s",
							NAN,
						)
					)
				),
				expected_guard_speed,
			)
			or (
				(
					CampaignScript
					. _path_steering_options(
						CampaignScript.CAMPAIGN_GQ7,
						metadata_varied,
					)
				)
				!= path_options
			)
			or (
				(
					CampaignScript
					. _motor_velocity_options(
						CampaignScript.CAMPAIGN_GQ7,
						metadata_varied,
					)
				)
				!= motor_options
			)
			or not digest.begins_with("sha256:")
			or digest.length() != 71
		):
			return false
		controller_digests[digest] = true
	var valid_path := CampaignScript.GQ7_PATH_STEERING_OPTIONS.duplicate(true)
	var valid_path_result := WaveGaitScript._normalize_path_steering_options(valid_path, 360)
	var nonfinite_path := valid_path.duplicate(true)
	nonfinite_path["cross_track_velocity_heading_gain_rad_per_m_s"] = INF
	var nonfinite_path_result := (
		WaveGaitScript
		. _normalize_path_steering_options(
			nonfinite_path,
			360,
		)
	)
	var unknown_path := valid_path.duplicate(true)
	unknown_path["runtime_outcome_gain"] = 0.2
	var unknown_path_result := WaveGaitScript._normalize_path_steering_options(unknown_path, 360)
	var s050_gain := 0.25 - 0.05 * ((0.692711698 - 0.5) / 0.5)
	return (
		controller_digests.size() > 2
		and bool(valid_path_result.get("ok", false))
		and (valid_path_result.get("path_steering_options", {}) as Dictionary) == valid_path
		and not bool(nonfinite_path_result.get("ok", true))
		and int(nonfinite_path_result.get("world_build_count", -1)) == 0
		and not bool(unknown_path_result.get("ok", true))
		and String(unknown_path_result.get("failure_code", "")) == "UNKNOWN_PATH_STEERING_OPTION"
		and int(unknown_path_result.get("world_build_count", -1)) == 0
		and is_equal_approx(CampaignScript._gq7_cross_track_gain_per_m(0.499999), 1.0)
		and is_equal_approx(CampaignScript._gq7_cross_track_gain_per_m(0.5), 0.75)
		and is_equal_approx(CampaignScript._gq7_yaw_gain_per_rad(0.899999, 1.0, 0.984999, 1.0), 1.1)
		and is_equal_approx(CampaignScript._gq7_yaw_gain_per_rad(0.9, 1.0, 0.984999, 1.0), 1.3)
		and is_equal_approx(CampaignScript._gq7_yaw_gain_per_rad(0.1, 1.0, 0.985, 1.0), 1.0)
		and is_equal_approx(CampaignScript._gq7_yaw_gain_per_rad(0.5, 1.0, 1.025, 1.0), 1.3)
		and is_equal_approx(CampaignScript._gq7_yaw_gain_per_rad(0.5, 1.0, 1.025001, 1.0), 1.0)
		and is_equal_approx(CampaignScript._gq7_yaw_gain_per_rad(0.5, 1.020001, 1.01, 1.02), 1.1)
		and is_equal_approx(CampaignScript._gq7_yaw_gain_per_rad(0.5, 1.02, 1.01, 1.02), 1.0)
		and is_equal_approx(CampaignScript._gq7_yaw_gain_per_rad(0.5, 1.1, 1.01, 1.019999), 1.0)
		and is_equal_approx(CampaignScript._gq7_velocity_gain_rad_per_m_s(1.0, 1.0, 1.0, 1.1), 0.20)
		and is_equal_approx(
			CampaignScript._gq7_velocity_gain_rad_per_m_s(0.149999, 1.0, 1.0, 1.0), 0.20
		)
		and is_equal_approx(
			CampaignScript._gq7_velocity_gain_rad_per_m_s(0.149999, 1.0, 1.000001, 1.0), 0.25
		)
		and is_equal_approx(
			CampaignScript._gq7_velocity_gain_rad_per_m_s(0.15, 1.0, 1.0, 1.0), 0.30
		)
		and is_equal_approx(
			CampaignScript._gq7_velocity_gain_rad_per_m_s(0.15, 1.0, 1.000001, 1.0), 0.20
		)
		and is_equal_approx(
			CampaignScript._gq7_velocity_gain_rad_per_m_s(0.5, 0.999999, 1.000001, 1.0), 0.25
		)
		and is_equal_approx(
			CampaignScript._gq7_velocity_gain_rad_per_m_s(0.75, 0.999999, 1.000001, 1.0), 0.225
		)
		and is_equal_approx(
			CampaignScript._gq7_velocity_gain_rad_per_m_s(1.0, 0.999999, 1.000001, 1.0), 0.20
		)
		and is_equal_approx(
			CampaignScript._gq7_velocity_gain_rad_per_m_s(0.692711698, 0.9796875, 1.036419753, 1.0),
			s050_gain,
		)
		and is_equal_approx(
			CampaignScript._gq7_velocity_gain_rad_per_m_s(0.75, 0.999999, 1.0, 1.0), 0.25
		)
		and is_equal_approx(
			CampaignScript._gq7_velocity_gain_rad_per_m_s(0.75, 1.0, 1.000001, 1.0), 0.25
		)
		and CampaignScript._gq7_motor_guard_values(0.499999) == [0.90, 2.5]
		and CampaignScript._gq7_motor_guard_values(0.5) == [0.80, 2.0]
	)


static func _gq7_clock_solver_and_thresholds_exact(compiled_cells: Array) -> bool:
	if compiled_cells.is_empty():
		return false
	var clock := ClockSpecScript.gq7_clock()
	var clock_result := ClockSpecScript.compile(clock)
	var bad_clock := clock.duplicate(true)
	bad_clock["evidence_cycles"] = 3
	var bad_clock_result := ClockSpecScript.compile(bad_clock)
	var solver_result := (
		WaveGaitScript
		. compile_solver_policy_options(
			CampaignScript.GP4_SOLVER_POLICY_OPTIONS,
		)
	)
	var fixture: Dictionary = (compiled_cells[0] as Dictionary)["fixture_spec"]
	var torso: Dictionary = fixture["torso"]
	var torso_size: Array = torso["size_m"]
	var first_limb: Dictionary = (fixture["limbs"] as Array)[0]
	var thresholds := (
		CampaignScript
		. _evidence_thresholds(
			fixture,
			CampaignScript.CAMPAIGN_GQ7,
		)
	)
	var threshold_result := WaveGaitScript.compile_evidence_threshold_options(thresholds)
	var unknown_threshold := thresholds.duplicate(true)
	unknown_threshold["relax_after_failure"] = true
	var unknown_threshold_result := (
		WaveGaitScript
		. compile_evidence_threshold_options(
			unknown_threshold,
		)
	)
	return (
		bool(clock_result.get("ok", false))
		and int(clock_result.get("world_build_count", -1)) == 0
		and (clock_result.get("gait_clock_options", {}) as Dictionary) == clock
		and String(clock.get("policy_id", "")) == ClockSpecScript.GQ7_POLICY_ID
		and ClockSpecScript.GQ7_POLICY_ID != ClockSpecScript.GQ6_POLICY_ID
		and int(clock.get("cycle_ticks", -1)) == 360
		and int(clock.get("evidence_cycles", -1)) == 4
		and int(clock.get("maximum_contact_gate_hold_ticks", -1)) == 120
		and int(clock.get("maximum_contact_gated_evidence_extension_ticks", -1)) == 720
		and int(clock.get("maximum_contact_gated_phase_skew_ticks", -1)) == 12
		and not bool(bad_clock_result.get("ok", true))
		and int(bad_clock_result.get("world_build_count", -1)) == 0
		and bool(solver_result.get("ok", false))
		and int(solver_result.get("world_build_count", -1)) == 0
		and (
			(solver_result.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_velocity_steps"]) == 20
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_position_steps"]) == 7
		and bool(threshold_result.get("ok", false))
		and int(threshold_result.get("world_build_count", -1)) == 0
		and ((threshold_result.get("evidence_threshold_options", {}) as Dictionary) == thresholds)
		and is_equal_approx(
			float(thresholds.get("minimum_foot_relocation_m", NAN)),
			0.0238 * float(torso_size[0]),
		)
		and is_equal_approx(
			float(thresholds.get("maximum_anchor_error_m", NAN)),
			0.14 * float(first_limb["upper_length_m"]),
		)
		and is_equal_approx(
			float(thresholds.get("minimum_evidence_torso_advance_m", NAN)),
			0.080 * float(torso_size[0]),
		)
		and is_equal_approx(
			float(thresholds.get("minimum_final_torso_advance_m", NAN)),
			0.060 * float(torso_size[0]),
		)
		and not bool(unknown_threshold_result.get("ok", true))
		and int(unknown_threshold_result.get("world_build_count", -1)) == 0
	)


static func _gq7_policy_preservation_and_fail_closed_exact(
	selection: Array,
	held_out: Array,
) -> bool:
	var gq1_digest := CanonicalJsonScript.sha256(
		CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ1)
	)
	var gq2_digest := CanonicalJsonScript.sha256(
		CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ2)
	)
	var gq3_digest := CanonicalJsonScript.sha256(
		CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ3)
	)
	var gq4_digest := CanonicalJsonScript.sha256(
		CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ4)
	)
	var gq5_digest := CanonicalJsonScript.sha256(
		CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ5)
	)
	var gq6_digest := CanonicalJsonScript.sha256(
		CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ6)
	)
	var gq7_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ7)
	var gq7_digest := CanonicalJsonScript.sha256(gq7_policy)
	var first_generation := ProportionSpecScript.compile_gq7_generation(61)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var tampered_digest := first_digest.left(70) + ("0" if first_digest.right(1) != "0" else "1")
	var wrong_type := ProportionSpecScript.compile_gq7_generation(61.0)
	var unknown_index := ProportionSpecScript.compile_gq7_generation(73)
	var tampered := ProportionSpecScript.verify_gq7_generation(61, tampered_digest)
	var invalid_role := (
		ProportionSpecScript
		. gq7_generation_for_morphology(
			"gq7_generated_s061",
			"invalid",
		)
	)
	var wrong_role := (
		ProportionSpecScript
		. gq7_generation_for_morphology(
			"gq7_generated_s061",
			"heldout",
		)
	)
	var unknown_morphology := (
		ProportionSpecScript
		. gq7_generation_for_morphology(
			"gq7_generated_s999",
			"selection",
		)
	)
	return (
		(
			String(gq7_policy.get("schema_version", ""))
			== "sporespore_g4_gq7_smooth_high_interaction_velocity_feedback_policy_v1"
		)
		and String(gq7_policy.get("campaign_id", "")) == CampaignScript.CAMPAIGN_GQ7
		and (gq7_policy.get("selection_cells", []) as Array) == selection
		and (gq7_policy.get("held_out_cells", []) as Array) == held_out
		and (
			String(gq7_policy.get("generator_policy_id", ""))
			== ProportionSpecScript.GQ7_GENERATOR_POLICY_ID
		)
		and (
			String(gq7_policy.get("generator_schema_version", ""))
			== ProportionSpecScript.GQ7_GENERATOR_SCHEMA_VERSION
		)
		and (
			(gq7_policy.get("selection_generator_indices", []) as Array)
			== ProportionSpecScript.GQ7_SELECTION_INDICES
		)
		and (
			(gq7_policy.get("held_out_generator_indices", []) as Array)
			== ProportionSpecScript.GQ7_HELD_OUT_INDICES
		)
		and (gq7_policy.get("generator_receipts", []) as Array).size() == 20
		and String(gq7_policy.get("clock_policy_id", "")) == ClockSpecScript.GQ7_POLICY_ID
		and ((gq7_policy.get("clock_options", {}) as Dictionary) == ClockSpecScript.gq7_clock())
		and (
			(gq7_policy.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and (
			(gq7_policy.get("robustness_options", {}) as Dictionary)
			== CampaignScript.GQ7_ROBUSTNESS_OPTIONS
		)
		and (
			String(gq7_policy.get("path_velocity_gain_derivation_id", ""))
			== "yaw_score_width_length_smooth_high_interaction_v1"
		)
		and (
			String(gq7_policy.get("path_velocity_gain_formula", ""))
			== (
				"0.20 if Y>1 else (0.20 if S<0.15 and W<=1 else "
				+ "(0.25 if S<0.15 else (0.30 if S<0.5 and W<=1 else "
				+ "(0.20 if S<0.5 else "
				+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else 0.25)))))"
			)
		)
		and not gq7_policy.has("controller_sha256")
		and gq1_digest == "sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698"
		and gq2_digest == "sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463"
		and gq3_digest == "sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253"
		and gq4_digest == "sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38"
		and gq5_digest == "sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb"
		and gq6_digest == "sha256:1c099d6c3179323c9e2dbdf20adcfd1cb91e11221fd0d2a49f349acec512a85f"
		and gq7_digest.begins_with("sha256:")
		and gq7_digest.length() == 71
		and (
			gq7_digest
			not in [gq1_digest, gq2_digest, gq3_digest, gq4_digest, gq5_digest, gq6_digest]
		)
		and not bool(wrong_type.get("ok", true))
		and String(wrong_type.get("failure_code", "")) == "INVALID_GQ7_GENERATOR_INDEX_TYPE"
		and int(wrong_type.get("world_build_count", -1)) == 0
		and not bool(unknown_index.get("ok", true))
		and String(unknown_index.get("failure_code", "")) == "UNKNOWN_GQ7_GENERATOR_INDEX"
		and int(unknown_index.get("world_build_count", -1)) == 0
		and not bool(tampered.get("ok", true))
		and String(tampered.get("failure_code", "")) == "GQ7_GENERATOR_RECEIPT_DIGEST_MISMATCH"
		and int(tampered.get("world_build_count", -1)) == 0
		and not bool(invalid_role.get("ok", true))
		and String(invalid_role.get("failure_code", "")) == "INVALID_GQ7_CAMPAIGN_ROLE"
		and int(invalid_role.get("world_build_count", -1)) == 0
		and not bool(wrong_role.get("ok", true))
		and String(wrong_role.get("failure_code", "")) == "UNKNOWN_GQ7_MORPHOLOGY"
		and int(wrong_role.get("world_build_count", -1)) == 0
		and not bool(unknown_morphology.get("ok", true))
		and String(unknown_morphology.get("failure_code", "")) == "UNKNOWN_GQ7_MORPHOLOGY"
		and int(unknown_morphology.get("world_build_count", -1)) == 0
	)


static func _gq8_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gq8_generated_s073",
		"gq8_generated_s074",
		"gq8_generated_s075",
		"gq8_generated_s076",
		"gq8_generated_s077",
		"gq8_generated_s078",
		"gq8_generated_s079",
		"gq8_generated_s080",
		"gq8_generated_s081",
		"gq8_generated_s082",
		"gq8_generated_s083",
		"gq8_generated_s084",
	]
	var expected_held_out := [
		"gq8_generated_s701",
		"gq8_generated_s702",
		"gq8_generated_s703",
		"gq8_generated_s704",
		"gq8_generated_s705",
		"gq8_generated_s706",
		"gq8_generated_s707",
		"gq8_generated_s708",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		realized_selection.append(String((cell_value as Dictionary)["morphology_id"]))
	for cell_value in held_out:
		realized_held_out.append(String((cell_value as Dictionary)["morphology_id"]))
	var index_set: Dictionary = {}
	for generator_index in ProportionSpecScript.GQ8_SELECTION_INDICES:
		index_set[int(generator_index)] = true
	for generator_index in ProportionSpecScript.GQ8_HELD_OUT_INDICES:
		if index_set.has(int(generator_index)):
			return false
		index_set[int(generator_index)] = true
	return (
		selection.size() == 12
		and held_out.size() == 8
		and realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			ProportionSpecScript.GQ8_SELECTION_INDICES
			== [73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84]
		)
		and ProportionSpecScript.GQ8_HELD_OUT_INDICES == [701, 702, 703, 704, 705, 706, 707, 708]
		and index_set.size() == 20
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq8_generated_s073",
					"selection",
					ProportionSpecScript.CAMPAIGN_GQ8,
				)
			)
			== selection[0]
		)
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq8_generated_s701",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GQ8,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq8_generated_s701",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ8,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq7_generated_s073",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ8,
			)
			. is_empty()
		)
	)


static func _expected_gq8_generation(generator_index: int, campaign_role: String) -> Dictionary:
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": ProportionSpecScript.SCHEMA_VERSION,
		"morphology_id": "gq8_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in ProportionSpecScript.GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(ProportionSpecScript.GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _test_radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = ProportionSpecScript.GQ1_AXIS_INTERVALS[axis_key]
		var reference_value := float(interval[0])
		var lower_endpoint := float(interval[1])
		var upper_endpoint := float(interval[2])
		var endpoint_distance := (
			reference_value - lower_endpoint
			if centered_coordinate < 0.0
			else upper_endpoint - reference_value
		)
		var realized_value := (
			reference_value + shell_fraction * centered_coordinate * endpoint_distance
		)
		proportion_spec[axis_key] = realized_value
		axis_coordinates[axis_key] = {
			"base": axis_base,
			"radical_inverse": radical_inverse,
			"centered_coordinate": centered_coordinate,
			"reference_value": reference_value,
			"lower_endpoint": lower_endpoint,
			"upper_endpoint": upper_endpoint,
			"realized_value": realized_value,
		}
	var generator_receipt := {
		"schema_version": ProportionSpecScript.GQ8_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": ProportionSpecScript.GQ8_GENERATOR_POLICY_ID,
		"campaign_id": ProportionSpecScript.CAMPAIGN_GQ8,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"proportion_spec": proportion_spec,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
	}


static func _gq8_generation_formula_exact(selection: Array, held_out: Array) -> bool:
	var indices := [
		73,
		74,
		75,
		76,
		77,
		78,
		79,
		80,
		81,
		82,
		83,
		84,
		701,
		702,
		703,
		704,
		705,
		706,
		707,
		708,
	]
	var cells := selection + held_out
	var digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var campaign_role := "selection" if cell_index < selection.size() else "heldout"
		var expected := _expected_gq8_generation(generator_index, campaign_role)
		var realized := ProportionSpecScript.compile_gq8_generation(generator_index)
		var digest := String(realized.get("generator_receipt_sha256", ""))
		var verified := ProportionSpecScript.verify_gq8_generation(generator_index, digest)
		if (
			not bool(realized.get("ok", false))
			or int(realized.get("world_build_count", -1)) != 0
			or (realized.get("proportion_spec", {}) as Dictionary) != cells[cell_index]
			or realized.get("proportion_spec", {}) != expected["proportion_spec"]
			or realized.get("generator_receipt", {}) != expected["generator_receipt"]
			or digest != String(expected["generator_receipt_sha256"])
			or not bool(verified.get("ok", false))
			or int(verified.get("world_build_count", -1)) != 0
		):
			return false
		digests[digest] = true
	var old_gq7_request := ProportionSpecScript.compile_gq7_generation(73)
	return (
		digests.size() == indices.size()
		and not bool(old_gq7_request.get("ok", true))
		and String(old_gq7_request.get("failure_code", "")) == "UNKNOWN_GQ7_GENERATOR_INDEX"
		and int(old_gq7_request.get("world_build_count", -1)) == 0
	)


static func _test_gq8_yaw_gain(
	score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if foot_radius_scale < 0.985:
		return 1.3 if score >= 0.9 else 1.1
	if score < 0.5 or foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if absf(hip_span_scale - 1.0) >= 0.02:
		return 1.1 if torso_length_scale > 1.02 else 1.0
	return 1.0


static func _test_gq8_velocity_gain(
	score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	yaw_gain: float,
) -> float:
	if yaw_gain > 1.0:
		return 0.20
	if score < 0.15:
		return 0.25 if torso_width_scale <= 1.0 else 0.30
	if score < 0.5:
		return 0.60 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((score - 0.5) / 0.5, 0.0, 1.0)
	return 0.30


static func _gq8_controller_derivation_and_boundaries_exact(cells: Array) -> bool:
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := _test_morphology_interaction_score(cell)
		var torso_length_scale := float(cell["torso_length_scale"])
		var torso_width_scale := float(cell["torso_width_scale"])
		var foot_radius_scale := float(cell["foot_radius_scale"])
		var hip_span_scale := float(cell["hip_span_scale"])
		var expected_yaw_gain := _test_gq8_yaw_gain(
			score,
			torso_length_scale,
			foot_radius_scale,
			hip_span_scale,
		)
		var expected_path := CampaignScript.GQ8_PATH_STEERING_OPTIONS.duplicate(true)
		expected_path["cross_track_heading_gain_rad_per_m"] = 1.0 if score < 0.5 else 0.75
		expected_path["yaw_error_stride_gain_per_rad"] = expected_yaw_gain
		expected_path["cross_track_velocity_heading_gain_rad_per_m_s"] = (_test_gq8_velocity_gain(
			score,
			torso_length_scale,
			torso_width_scale,
			expected_yaw_gain,
		))
		var expected_guard_fraction := 0.80 if score >= 0.5 else 0.90
		var expected_guard_speed := 2.0 if score >= 0.5 else 2.5
		var path_options := CampaignScript._path_steering_options(CampaignScript.CAMPAIGN_GQ8, cell)
		var motor_options := (
			CampaignScript
			. _motor_velocity_options(
				CampaignScript.CAMPAIGN_GQ8,
				cell,
			)
		)
		var digest := (
			CampaignScript
			. _expected_controller_sha256(
				CampaignScript.CAMPAIGN_GQ8,
				motor_options,
				path_options,
			)
		)
		var metadata_varied := cell.duplicate(true)
		metadata_varied["morphology_id"] = "%s_renamed" % String(cell["morphology_id"])
		metadata_varied["generator_index"] = 999
		metadata_varied["seed"] = 123456
		metadata_varied["campaign_role"] = "heldout"
		metadata_varied["repetition"] = 3
		metadata_varied["walking_observed"] = false
		if (
			path_options != expected_path
			or not is_equal_approx(
				float(motor_options.get("morphology_interaction_score", NAN)),
				score,
			)
			or not is_equal_approx(
				float(motor_options.get("anchor_error_guard_activation_fraction", NAN)),
				expected_guard_fraction,
			)
			or not is_equal_approx(
				float(
					(
						motor_options
						. get(
							"anchor_error_guard_maximum_motor_target_speed_rad_s",
							NAN,
						)
					)
				),
				expected_guard_speed,
			)
			or (
				(
					CampaignScript
					. _path_steering_options(
						CampaignScript.CAMPAIGN_GQ8,
						metadata_varied,
					)
				)
				!= path_options
			)
			or (
				(
					CampaignScript
					. _motor_velocity_options(
						CampaignScript.CAMPAIGN_GQ8,
						metadata_varied,
					)
				)
				!= motor_options
			)
			or not digest.begins_with("sha256:")
			or digest.length() != 71
		):
			return false
		controller_digests[digest] = true
	var valid_path := CampaignScript.GQ8_PATH_STEERING_OPTIONS.duplicate(true)
	var valid_path_result := WaveGaitScript._normalize_path_steering_options(valid_path, 360)
	var nonfinite_path := valid_path.duplicate(true)
	nonfinite_path["cross_track_velocity_heading_gain_rad_per_m_s"] = INF
	var nonfinite_path_result := (
		WaveGaitScript
		. _normalize_path_steering_options(
			nonfinite_path,
			360,
		)
	)
	var unknown_path := valid_path.duplicate(true)
	unknown_path["runtime_outcome_gain"] = 0.2
	var unknown_path_result := WaveGaitScript._normalize_path_steering_options(unknown_path, 360)
	var s050_gain := 0.25 - 0.05 * ((0.692711698 - 0.5) / 0.5)
	return (
		controller_digests.size() > 2
		and bool(valid_path_result.get("ok", false))
		and (valid_path_result.get("path_steering_options", {}) as Dictionary) == valid_path
		and not bool(nonfinite_path_result.get("ok", true))
		and int(nonfinite_path_result.get("world_build_count", -1)) == 0
		and not bool(unknown_path_result.get("ok", true))
		and String(unknown_path_result.get("failure_code", "")) == "UNKNOWN_PATH_STEERING_OPTION"
		and int(unknown_path_result.get("world_build_count", -1)) == 0
		and is_equal_approx(CampaignScript._gq8_cross_track_gain_per_m(0.499999), 1.0)
		and is_equal_approx(CampaignScript._gq8_cross_track_gain_per_m(0.5), 0.75)
		and is_equal_approx(CampaignScript._gq8_yaw_gain_per_rad(0.899999, 1.0, 0.984999, 1.0), 1.1)
		and is_equal_approx(CampaignScript._gq8_yaw_gain_per_rad(0.9, 1.0, 0.984999, 1.0), 1.3)
		and is_equal_approx(CampaignScript._gq8_yaw_gain_per_rad(0.1, 1.0, 0.985, 1.0), 1.0)
		and is_equal_approx(CampaignScript._gq8_yaw_gain_per_rad(0.5, 1.0, 1.025, 1.0), 1.3)
		and is_equal_approx(CampaignScript._gq8_yaw_gain_per_rad(0.5, 1.0, 1.025001, 1.0), 1.0)
		and is_equal_approx(CampaignScript._gq8_yaw_gain_per_rad(0.5, 1.020001, 1.01, 1.02), 1.1)
		and is_equal_approx(CampaignScript._gq8_yaw_gain_per_rad(0.5, 1.02, 1.01, 1.02), 1.0)
		and is_equal_approx(CampaignScript._gq8_yaw_gain_per_rad(0.5, 1.1, 1.01, 1.019999), 1.0)
		and is_equal_approx(CampaignScript._gq8_velocity_gain_rad_per_m_s(1.0, 1.0, 1.0, 1.1), 0.20)
		and is_equal_approx(
			CampaignScript._gq8_velocity_gain_rad_per_m_s(0.149999, 1.0, 1.0, 1.0),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq8_velocity_gain_rad_per_m_s(0.149999, 1.0, 1.000001, 1.0),
			0.30,
		)
		and is_equal_approx(
			CampaignScript._gq8_velocity_gain_rad_per_m_s(0.15, 1.0, 1.0, 1.0),
			0.60,
		)
		and is_equal_approx(
			CampaignScript._gq8_velocity_gain_rad_per_m_s(0.15, 1.0, 1.000001, 1.0),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq8_velocity_gain_rad_per_m_s(0.5, 0.999999, 1.000001, 1.0),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq8_velocity_gain_rad_per_m_s(0.75, 0.999999, 1.000001, 1.0),
			0.225,
		)
		and is_equal_approx(
			CampaignScript._gq8_velocity_gain_rad_per_m_s(1.0, 0.999999, 1.000001, 1.0),
			0.20,
		)
		and is_equal_approx(
			CampaignScript._gq8_velocity_gain_rad_per_m_s(0.692711698, 0.9796875, 1.036419753, 1.0),
			s050_gain,
		)
		and is_equal_approx(
			CampaignScript._gq8_velocity_gain_rad_per_m_s(0.75, 0.999999, 1.0, 1.0),
			0.30,
		)
		and is_equal_approx(
			CampaignScript._gq8_velocity_gain_rad_per_m_s(0.75, 1.0, 1.000001, 1.0),
			0.30,
		)
		and CampaignScript._gq8_motor_guard_values(0.499999) == [0.90, 2.5]
		and CampaignScript._gq8_motor_guard_values(0.5) == [0.80, 2.0]
	)


static func _gq8_clock_solver_and_thresholds_exact(compiled_cells: Array) -> bool:
	if compiled_cells.is_empty():
		return false
	var clock := ClockSpecScript.gq8_clock()
	var clock_result := ClockSpecScript.compile(clock)
	var bad_clock := clock.duplicate(true)
	bad_clock["evidence_cycles"] = 3
	var bad_clock_result := ClockSpecScript.compile(bad_clock)
	var solver_result := (
		WaveGaitScript
		. compile_solver_policy_options(
			CampaignScript.GP4_SOLVER_POLICY_OPTIONS,
		)
	)
	var fixture: Dictionary = (compiled_cells[0] as Dictionary)["fixture_spec"]
	var torso_size: Array = (fixture["torso"] as Dictionary)["size_m"]
	var first_limb: Dictionary = (fixture["limbs"] as Array)[0]
	var thresholds := (
		CampaignScript
		. _evidence_thresholds(
			fixture,
			CampaignScript.CAMPAIGN_GQ8,
		)
	)
	var threshold_result := WaveGaitScript.compile_evidence_threshold_options(thresholds)
	var unknown_threshold := thresholds.duplicate(true)
	unknown_threshold["relax_after_failure"] = true
	var unknown_threshold_result := (
		WaveGaitScript
		. compile_evidence_threshold_options(
			unknown_threshold,
		)
	)
	return (
		bool(clock_result.get("ok", false))
		and int(clock_result.get("world_build_count", -1)) == 0
		and (clock_result.get("gait_clock_options", {}) as Dictionary) == clock
		and String(clock.get("policy_id", "")) == ClockSpecScript.GQ8_POLICY_ID
		and ClockSpecScript.GQ8_POLICY_ID != ClockSpecScript.GQ7_POLICY_ID
		and int(clock.get("cycle_ticks", -1)) == 360
		and int(clock.get("evidence_cycles", -1)) == 4
		and int(clock.get("maximum_contact_gate_hold_ticks", -1)) == 120
		and int(clock.get("maximum_contact_gated_evidence_extension_ticks", -1)) == 720
		and int(clock.get("maximum_contact_gated_phase_skew_ticks", -1)) == 12
		and not bool(bad_clock_result.get("ok", true))
		and int(bad_clock_result.get("world_build_count", -1)) == 0
		and bool(solver_result.get("ok", false))
		and int(solver_result.get("world_build_count", -1)) == 0
		and (
			(solver_result.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_velocity_steps"]) == 20
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_position_steps"]) == 7
		and bool(threshold_result.get("ok", false))
		and int(threshold_result.get("world_build_count", -1)) == 0
		and (threshold_result.get("evidence_threshold_options", {}) as Dictionary) == thresholds
		and is_equal_approx(
			float(thresholds.get("minimum_foot_relocation_m", NAN)),
			0.0238 * float(torso_size[0]),
		)
		and is_equal_approx(
			float(thresholds.get("maximum_anchor_error_m", NAN)),
			0.14 * float(first_limb["upper_length_m"]),
		)
		and not bool(unknown_threshold_result.get("ok", true))
		and int(unknown_threshold_result.get("world_build_count", -1)) == 0
	)


static func _gq8_policy_preservation_and_fail_closed_exact(
	selection: Array,
	held_out: Array,
) -> bool:
	var prior_digests := [
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ1)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ2)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ3)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ4)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ5)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ6)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ7)),
	]
	var expected_prior_digests := [
		"sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698",
		"sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463",
		"sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253",
		"sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38",
		"sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb",
		"sha256:1c099d6c3179323c9e2dbdf20adcfd1cb91e11221fd0d2a49f349acec512a85f",
		"sha256:32c68e0d0f1c4ecb54499793a2f090e7bee37846f6babf27f563bd5afb5c0346",
	]
	var policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ8)
	var policy_digest := CanonicalJsonScript.sha256(policy)
	var first_generation := ProportionSpecScript.compile_gq8_generation(73)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var tampered_digest := first_digest.left(70) + ("0" if first_digest.right(1) != "0" else "1")
	var wrong_type := ProportionSpecScript.compile_gq8_generation(73.0)
	var unknown_index := ProportionSpecScript.compile_gq8_generation(85)
	var tampered := ProportionSpecScript.verify_gq8_generation(73, tampered_digest)
	var invalid_role := (
		ProportionSpecScript
		. gq8_generation_for_morphology(
			"gq8_generated_s073",
			"invalid",
		)
	)
	var wrong_role := (
		ProportionSpecScript
		. gq8_generation_for_morphology(
			"gq8_generated_s073",
			"heldout",
		)
	)
	var unknown_morphology := (
		ProportionSpecScript
		. gq8_generation_for_morphology(
			"gq8_generated_s999",
			"selection",
		)
	)
	return (
		prior_digests == expected_prior_digests
		and (
			String(policy.get("schema_version", ""))
			== "sporespore_g4_gq8_boosted_velocity_feedback_policy_v1"
		)
		and String(policy.get("campaign_id", "")) == CampaignScript.CAMPAIGN_GQ8
		and (policy.get("selection_cells", []) as Array) == selection
		and (policy.get("held_out_cells", []) as Array) == held_out
		and (
			String(policy.get("generator_policy_id", ""))
			== ProportionSpecScript.GQ8_GENERATOR_POLICY_ID
		)
		and (
			String(policy.get("generator_schema_version", ""))
			== ProportionSpecScript.GQ8_GENERATOR_SCHEMA_VERSION
		)
		and (
			(policy.get("selection_generator_indices", []) as Array)
			== ProportionSpecScript.GQ8_SELECTION_INDICES
		)
		and (
			(policy.get("held_out_generator_indices", []) as Array)
			== ProportionSpecScript.GQ8_HELD_OUT_INDICES
		)
		and (policy.get("generator_receipts", []) as Array).size() == 20
		and String(policy.get("clock_policy_id", "")) == ClockSpecScript.GQ8_POLICY_ID
		and (policy.get("clock_options", {}) as Dictionary) == ClockSpecScript.gq8_clock()
		and (
			(policy.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and (
			(policy.get("robustness_options", {}) as Dictionary)
			== CampaignScript.GQ8_ROBUSTNESS_OPTIONS
		)
		and (
			String(policy.get("path_velocity_gain_derivation_id", ""))
			== "yaw_score_width_length_boosted_mid_narrow_v2"
		)
		and (
			String(policy.get("path_velocity_gain_formula", ""))
			== (
				"0.20 if Y>1 else (0.25 if S<0.15 and W<=1 else "
				+ "(0.30 if S<0.15 else (0.60 if S<0.5 and W<=1 else "
				+ "(0.25 if S<0.5 else "
				+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else 0.30)))))"
			)
		)
		and not policy.has("controller_sha256")
		and policy_digest.begins_with("sha256:")
		and policy_digest.length() == 71
		and policy_digest not in prior_digests
		and not bool(wrong_type.get("ok", true))
		and String(wrong_type.get("failure_code", "")) == "INVALID_GQ8_GENERATOR_INDEX_TYPE"
		and int(wrong_type.get("world_build_count", -1)) == 0
		and not bool(unknown_index.get("ok", true))
		and String(unknown_index.get("failure_code", "")) == "UNKNOWN_GQ8_GENERATOR_INDEX"
		and int(unknown_index.get("world_build_count", -1)) == 0
		and not bool(tampered.get("ok", true))
		and String(tampered.get("failure_code", "")) == "GQ8_GENERATOR_RECEIPT_DIGEST_MISMATCH"
		and int(tampered.get("world_build_count", -1)) == 0
		and not bool(invalid_role.get("ok", true))
		and String(invalid_role.get("failure_code", "")) == "INVALID_GQ8_CAMPAIGN_ROLE"
		and int(invalid_role.get("world_build_count", -1)) == 0
		and not bool(wrong_role.get("ok", true))
		and String(wrong_role.get("failure_code", "")) == "UNKNOWN_GQ8_MORPHOLOGY"
		and int(wrong_role.get("world_build_count", -1)) == 0
		and not bool(unknown_morphology.get("ok", true))
		and String(unknown_morphology.get("failure_code", "")) == "UNKNOWN_GQ8_MORPHOLOGY"
		and int(unknown_morphology.get("world_build_count", -1)) == 0
	)


static func _gq9_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gq9_generated_s085",
		"gq9_generated_s086",
		"gq9_generated_s087",
		"gq9_generated_s088",
		"gq9_generated_s089",
		"gq9_generated_s090",
		"gq9_generated_s091",
		"gq9_generated_s092",
		"gq9_generated_s093",
		"gq9_generated_s094",
		"gq9_generated_s095",
		"gq9_generated_s096",
	]
	var expected_held_out := [
		"gq9_generated_s801",
		"gq9_generated_s802",
		"gq9_generated_s803",
		"gq9_generated_s804",
		"gq9_generated_s805",
		"gq9_generated_s806",
		"gq9_generated_s807",
		"gq9_generated_s808",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		realized_selection.append(String((cell_value as Dictionary)["morphology_id"]))
	for cell_value in held_out:
		realized_held_out.append(String((cell_value as Dictionary)["morphology_id"]))
	var index_set: Dictionary = {}
	for generator_index in ProportionSpecScript.GQ9_SELECTION_INDICES:
		index_set[int(generator_index)] = true
	for generator_index in ProportionSpecScript.GQ9_HELD_OUT_INDICES:
		if index_set.has(int(generator_index)):
			return false
		index_set[int(generator_index)] = true
	return (
		selection.size() == 12
		and held_out.size() == 8
		and realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			ProportionSpecScript.GQ9_SELECTION_INDICES
			== [85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96]
		)
		and ProportionSpecScript.GQ9_HELD_OUT_INDICES == [801, 802, 803, 804, 805, 806, 807, 808]
		and index_set.size() == 20
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq9_generated_s085",
					"selection",
					ProportionSpecScript.CAMPAIGN_GQ9,
				)
			)
			== selection[0]
		)
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq9_generated_s801",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GQ9,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq9_generated_s801",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ9,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq8_generated_s085",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ9,
			)
			. is_empty()
		)
	)


static func _expected_gq9_generation(generator_index: int, campaign_role: String) -> Dictionary:
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": ProportionSpecScript.SCHEMA_VERSION,
		"morphology_id": "gq9_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in ProportionSpecScript.GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(ProportionSpecScript.GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _test_radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = ProportionSpecScript.GQ1_AXIS_INTERVALS[axis_key]
		var reference_value := float(interval[0])
		var lower_endpoint := float(interval[1])
		var upper_endpoint := float(interval[2])
		var endpoint_distance := (
			reference_value - lower_endpoint
			if centered_coordinate < 0.0
			else upper_endpoint - reference_value
		)
		var realized_value := (
			reference_value + shell_fraction * centered_coordinate * endpoint_distance
		)
		proportion_spec[axis_key] = realized_value
		axis_coordinates[axis_key] = {
			"base": axis_base,
			"radical_inverse": radical_inverse,
			"centered_coordinate": centered_coordinate,
			"reference_value": reference_value,
			"lower_endpoint": lower_endpoint,
			"upper_endpoint": upper_endpoint,
			"realized_value": realized_value,
		}
	var generator_receipt := {
		"schema_version": ProportionSpecScript.GQ9_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": ProportionSpecScript.GQ9_GENERATOR_POLICY_ID,
		"campaign_id": ProportionSpecScript.CAMPAIGN_GQ9,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"proportion_spec": proportion_spec,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
	}


static func _gq9_generation_formula_exact(selection: Array, held_out: Array) -> bool:
	var indices := [
		85,
		86,
		87,
		88,
		89,
		90,
		91,
		92,
		93,
		94,
		95,
		96,
		801,
		802,
		803,
		804,
		805,
		806,
		807,
		808,
	]
	var cells := selection + held_out
	var digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var campaign_role := "selection" if cell_index < selection.size() else "heldout"
		var expected := _expected_gq9_generation(generator_index, campaign_role)
		var realized := ProportionSpecScript.compile_gq9_generation(generator_index)
		var digest := String(realized.get("generator_receipt_sha256", ""))
		var verified := ProportionSpecScript.verify_gq9_generation(generator_index, digest)
		if (
			not bool(realized.get("ok", false))
			or int(realized.get("world_build_count", -1)) != 0
			or (realized.get("proportion_spec", {}) as Dictionary) != cells[cell_index]
			or realized.get("proportion_spec", {}) != expected["proportion_spec"]
			or realized.get("generator_receipt", {}) != expected["generator_receipt"]
			or digest != String(expected["generator_receipt_sha256"])
			or not bool(verified.get("ok", false))
			or int(verified.get("world_build_count", -1)) != 0
		):
			return false
		digests[digest] = true
	var old_gq8_request := ProportionSpecScript.compile_gq8_generation(85)
	return (
		digests.size() == indices.size()
		and not bool(old_gq8_request.get("ok", true))
		and String(old_gq8_request.get("failure_code", "")) == "UNKNOWN_GQ8_GENERATOR_INDEX"
		and int(old_gq8_request.get("world_build_count", -1)) == 0
	)


static func _test_gq9_yaw_gain(
	score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if foot_radius_scale < 0.985:
		return 1.3 if score >= 0.9 else 1.1
	if score < 0.5 or foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if absf(hip_span_scale - 1.0) >= 0.02:
		return 1.1 if torso_length_scale > 1.02 else 1.0
	return 1.0


static func _test_gq9_velocity_gain(
	score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	yaw_gain: float,
) -> float:
	if yaw_gain > 1.0:
		return 0.20
	if score < 0.15:
		return 0.25 if torso_width_scale <= 1.0 else 0.30
	if score < 0.5:
		return 0.60 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((score - 0.5) / 0.5, 0.0, 1.0)
	return 0.35


static func _gq9_controller_derivation_and_boundaries_exact(cells: Array) -> bool:
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := _test_morphology_interaction_score(cell)
		var torso_length_scale := float(cell["torso_length_scale"])
		var torso_width_scale := float(cell["torso_width_scale"])
		var foot_radius_scale := float(cell["foot_radius_scale"])
		var hip_span_scale := float(cell["hip_span_scale"])
		var expected_yaw_gain := _test_gq9_yaw_gain(
			score,
			torso_length_scale,
			foot_radius_scale,
			hip_span_scale,
		)
		var expected_path := CampaignScript.GQ9_PATH_STEERING_OPTIONS.duplicate(true)
		expected_path["cross_track_heading_gain_rad_per_m"] = 1.0 if score < 0.5 else 0.75
		expected_path["yaw_error_stride_gain_per_rad"] = expected_yaw_gain
		expected_path["cross_track_velocity_heading_gain_rad_per_m_s"] = (_test_gq9_velocity_gain(
			score,
			torso_length_scale,
			torso_width_scale,
			expected_yaw_gain,
		))
		var expected_guard_fraction := 0.80 if score >= 0.5 else 0.90
		var expected_guard_speed := 2.0 if score >= 0.5 else 2.5
		var path_options := CampaignScript._path_steering_options(CampaignScript.CAMPAIGN_GQ9, cell)
		var motor_options := CampaignScript._motor_velocity_options(
			CampaignScript.CAMPAIGN_GQ9, cell
		)
		var digest := (
			CampaignScript
			. _expected_controller_sha256(
				CampaignScript.CAMPAIGN_GQ9,
				motor_options,
				path_options,
			)
		)
		var metadata_varied := cell.duplicate(true)
		metadata_varied["morphology_id"] = "%s_renamed" % String(cell["morphology_id"])
		metadata_varied["generator_index"] = 999
		metadata_varied["seed"] = 123456
		metadata_varied["campaign_role"] = "heldout"
		metadata_varied["repetition"] = 3
		metadata_varied["walking_observed"] = false
		if (
			path_options != expected_path
			or not is_equal_approx(
				float(motor_options.get("morphology_interaction_score", NAN)),
				score,
			)
			or not is_equal_approx(
				float(motor_options.get("anchor_error_guard_activation_fraction", NAN)),
				expected_guard_fraction,
			)
			or not is_equal_approx(
				float(
					(
						motor_options
						. get(
							"anchor_error_guard_maximum_motor_target_speed_rad_s",
							NAN,
						)
					)
				),
				expected_guard_speed,
			)
			or (
				(
					CampaignScript
					. _path_steering_options(
						CampaignScript.CAMPAIGN_GQ9,
						metadata_varied,
					)
				)
				!= path_options
			)
			or (
				(
					CampaignScript
					. _motor_velocity_options(
						CampaignScript.CAMPAIGN_GQ9,
						metadata_varied,
					)
				)
				!= motor_options
			)
			or not digest.begins_with("sha256:")
			or digest.length() != 71
		):
			return false
		controller_digests[digest] = true
	var valid_path := CampaignScript.GQ9_PATH_STEERING_OPTIONS.duplicate(true)
	var valid_path_result := WaveGaitScript._normalize_path_steering_options(valid_path, 360)
	var nonfinite_path := valid_path.duplicate(true)
	nonfinite_path["cross_track_velocity_heading_gain_rad_per_m_s"] = INF
	var nonfinite_path_result := (
		WaveGaitScript
		. _normalize_path_steering_options(
			nonfinite_path,
			360,
		)
	)
	var unknown_path := valid_path.duplicate(true)
	unknown_path["runtime_outcome_gain"] = 0.2
	var unknown_path_result := WaveGaitScript._normalize_path_steering_options(unknown_path, 360)
	var s050_gain := 0.25 - 0.05 * ((0.692711698 - 0.5) / 0.5)
	return (
		controller_digests.size() > 2
		and bool(valid_path_result.get("ok", false))
		and (valid_path_result.get("path_steering_options", {}) as Dictionary) == valid_path
		and not bool(nonfinite_path_result.get("ok", true))
		and int(nonfinite_path_result.get("world_build_count", -1)) == 0
		and not bool(unknown_path_result.get("ok", true))
		and String(unknown_path_result.get("failure_code", "")) == "UNKNOWN_PATH_STEERING_OPTION"
		and int(unknown_path_result.get("world_build_count", -1)) == 0
		and is_equal_approx(CampaignScript._gq9_cross_track_gain_per_m(0.499999), 1.0)
		and is_equal_approx(CampaignScript._gq9_cross_track_gain_per_m(0.5), 0.75)
		and is_equal_approx(CampaignScript._gq9_yaw_gain_per_rad(0.899999, 1.0, 0.984999, 1.0), 1.1)
		and is_equal_approx(CampaignScript._gq9_yaw_gain_per_rad(0.9, 1.0, 0.984999, 1.0), 1.3)
		and is_equal_approx(CampaignScript._gq9_yaw_gain_per_rad(0.1, 1.0, 0.985, 1.0), 1.0)
		and is_equal_approx(CampaignScript._gq9_yaw_gain_per_rad(0.5, 1.0, 1.025, 1.0), 1.3)
		and is_equal_approx(CampaignScript._gq9_yaw_gain_per_rad(0.5, 1.0, 1.025001, 1.0), 1.0)
		and is_equal_approx(CampaignScript._gq9_yaw_gain_per_rad(0.5, 1.020001, 1.01, 1.02), 1.1)
		and is_equal_approx(CampaignScript._gq9_yaw_gain_per_rad(0.5, 1.02, 1.01, 1.02), 1.0)
		and is_equal_approx(CampaignScript._gq9_yaw_gain_per_rad(0.5, 1.1, 1.01, 1.019999), 1.0)
		and is_equal_approx(CampaignScript._gq9_velocity_gain_rad_per_m_s(1.0, 1.0, 1.0, 1.1), 0.20)
		and is_equal_approx(
			CampaignScript._gq9_velocity_gain_rad_per_m_s(0.149999, 1.0, 1.0, 1.0),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq9_velocity_gain_rad_per_m_s(0.149999, 1.0, 1.000001, 1.0),
			0.30,
		)
		and is_equal_approx(
			CampaignScript._gq9_velocity_gain_rad_per_m_s(0.15, 1.0, 1.0, 1.0),
			0.60,
		)
		and is_equal_approx(
			CampaignScript._gq9_velocity_gain_rad_per_m_s(0.15, 1.0, 1.000001, 1.0),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq9_velocity_gain_rad_per_m_s(0.5, 0.999999, 1.000001, 1.0),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq9_velocity_gain_rad_per_m_s(0.75, 0.999999, 1.000001, 1.0),
			0.225,
		)
		and is_equal_approx(
			CampaignScript._gq9_velocity_gain_rad_per_m_s(1.0, 0.999999, 1.000001, 1.0),
			0.20,
		)
		and is_equal_approx(
			CampaignScript._gq9_velocity_gain_rad_per_m_s(0.692711698, 0.9796875, 1.036419753, 1.0),
			s050_gain,
		)
		and is_equal_approx(
			CampaignScript._gq9_velocity_gain_rad_per_m_s(0.75, 0.999999, 1.0, 1.0),
			0.35,
		)
		and is_equal_approx(
			CampaignScript._gq9_velocity_gain_rad_per_m_s(0.75, 1.0, 1.000001, 1.0),
			0.35,
		)
		and CampaignScript._gq9_motor_guard_values(0.499999) == [0.90, 2.5]
		and CampaignScript._gq9_motor_guard_values(0.5) == [0.80, 2.0]
	)


static func _gq9_clock_solver_and_thresholds_exact(compiled_cells: Array) -> bool:
	if compiled_cells.is_empty():
		return false
	var clock := ClockSpecScript.gq9_clock()
	var clock_result := ClockSpecScript.compile(clock)
	var bad_clock := clock.duplicate(true)
	bad_clock["evidence_cycles"] = 3
	var bad_clock_result := ClockSpecScript.compile(bad_clock)
	var solver_result := (
		WaveGaitScript
		. compile_solver_policy_options(
			CampaignScript.GP4_SOLVER_POLICY_OPTIONS,
		)
	)
	var fixture: Dictionary = (compiled_cells[0] as Dictionary)["fixture_spec"]
	var torso_size: Array = (fixture["torso"] as Dictionary)["size_m"]
	var first_limb: Dictionary = (fixture["limbs"] as Array)[0]
	var thresholds := (
		CampaignScript
		. _evidence_thresholds(
			fixture,
			CampaignScript.CAMPAIGN_GQ9,
		)
	)
	var threshold_result := WaveGaitScript.compile_evidence_threshold_options(thresholds)
	var unknown_threshold := thresholds.duplicate(true)
	unknown_threshold["relax_after_failure"] = true
	var unknown_threshold_result := (
		WaveGaitScript
		. compile_evidence_threshold_options(
			unknown_threshold,
		)
	)
	return (
		bool(clock_result.get("ok", false))
		and int(clock_result.get("world_build_count", -1)) == 0
		and (clock_result.get("gait_clock_options", {}) as Dictionary) == clock
		and String(clock.get("policy_id", "")) == ClockSpecScript.GQ9_POLICY_ID
		and ClockSpecScript.GQ9_POLICY_ID != ClockSpecScript.GQ8_POLICY_ID
		and int(clock.get("cycle_ticks", -1)) == 360
		and int(clock.get("evidence_cycles", -1)) == 4
		and int(clock.get("maximum_contact_gate_hold_ticks", -1)) == 120
		and int(clock.get("maximum_contact_gated_evidence_extension_ticks", -1)) == 720
		and int(clock.get("maximum_contact_gated_phase_skew_ticks", -1)) == 12
		and not bool(bad_clock_result.get("ok", true))
		and int(bad_clock_result.get("world_build_count", -1)) == 0
		and bool(solver_result.get("ok", false))
		and int(solver_result.get("world_build_count", -1)) == 0
		and (
			(solver_result.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_velocity_steps"]) == 20
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_position_steps"]) == 7
		and bool(threshold_result.get("ok", false))
		and int(threshold_result.get("world_build_count", -1)) == 0
		and (threshold_result.get("evidence_threshold_options", {}) as Dictionary) == thresholds
		and is_equal_approx(
			float(thresholds.get("minimum_foot_relocation_m", NAN)),
			0.0238 * float(torso_size[0]),
		)
		and is_equal_approx(
			float(thresholds.get("maximum_anchor_error_m", NAN)),
			0.14 * float(first_limb["upper_length_m"]),
		)
		and not bool(unknown_threshold_result.get("ok", true))
		and int(unknown_threshold_result.get("world_build_count", -1)) == 0
	)


static func _gq9_policy_preservation_and_fail_closed_exact(
	selection: Array,
	held_out: Array,
) -> bool:
	var prior_digests := [
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ1)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ2)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ3)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ4)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ5)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ6)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ7)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ8)),
	]
	var expected_prior_digests := [
		"sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698",
		"sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463",
		"sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253",
		"sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38",
		"sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb",
		"sha256:1c099d6c3179323c9e2dbdf20adcfd1cb91e11221fd0d2a49f349acec512a85f",
		"sha256:32c68e0d0f1c4ecb54499793a2f090e7bee37846f6babf27f563bd5afb5c0346",
		"sha256:c39d147f61057cb4b96e745b5aa7258bbfbcbfedaab4116a93b518f2b46348a0",
	]
	var policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ9)
	var policy_digest := CanonicalJsonScript.sha256(policy)
	var first_generation := ProportionSpecScript.compile_gq9_generation(85)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var tampered_digest := first_digest.left(70) + ("0" if first_digest.right(1) != "0" else "1")
	var wrong_type := ProportionSpecScript.compile_gq9_generation(85.0)
	var unknown_index := ProportionSpecScript.compile_gq9_generation(97)
	var tampered := ProportionSpecScript.verify_gq9_generation(85, tampered_digest)
	var invalid_role := (
		ProportionSpecScript
		. gq9_generation_for_morphology(
			"gq9_generated_s085",
			"invalid",
		)
	)
	var wrong_role := (
		ProportionSpecScript
		. gq9_generation_for_morphology(
			"gq9_generated_s085",
			"heldout",
		)
	)
	var unknown_morphology := (
		ProportionSpecScript
		. gq9_generation_for_morphology(
			"gq9_generated_s999",
			"selection",
		)
	)
	return (
		prior_digests == expected_prior_digests
		and (
			String(policy.get("schema_version", ""))
			== "sporespore_g4_gq9_high_fallback_velocity_feedback_policy_v1"
		)
		and String(policy.get("campaign_id", "")) == CampaignScript.CAMPAIGN_GQ9
		and (policy.get("selection_cells", []) as Array) == selection
		and (policy.get("held_out_cells", []) as Array) == held_out
		and (
			String(policy.get("generator_policy_id", ""))
			== ProportionSpecScript.GQ9_GENERATOR_POLICY_ID
		)
		and (
			String(policy.get("generator_schema_version", ""))
			== ProportionSpecScript.GQ9_GENERATOR_SCHEMA_VERSION
		)
		and (
			(policy.get("selection_generator_indices", []) as Array)
			== ProportionSpecScript.GQ9_SELECTION_INDICES
		)
		and (
			(policy.get("held_out_generator_indices", []) as Array)
			== ProportionSpecScript.GQ9_HELD_OUT_INDICES
		)
		and (policy.get("generator_receipts", []) as Array).size() == 20
		and String(policy.get("clock_policy_id", "")) == ClockSpecScript.GQ9_POLICY_ID
		and (policy.get("clock_options", {}) as Dictionary) == ClockSpecScript.gq9_clock()
		and (
			(policy.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and (
			(policy.get("robustness_options", {}) as Dictionary)
			== CampaignScript.GQ9_ROBUSTNESS_OPTIONS
		)
		and (
			String(policy.get("path_velocity_gain_derivation_id", ""))
			== "yaw_score_width_length_boosted_high_fallback_v3"
		)
		and (
			String(policy.get("path_velocity_gain_formula", ""))
			== (
				"0.20 if Y>1 else (0.25 if S<0.15 and W<=1 else "
				+ "(0.30 if S<0.15 else (0.60 if S<0.5 and W<=1 else "
				+ "(0.25 if S<0.5 else "
				+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else 0.35)))))"
			)
		)
		and not policy.has("controller_sha256")
		and policy_digest.begins_with("sha256:")
		and policy_digest.length() == 71
		and policy_digest not in prior_digests
		and not bool(wrong_type.get("ok", true))
		and String(wrong_type.get("failure_code", "")) == "INVALID_GQ9_GENERATOR_INDEX_TYPE"
		and int(wrong_type.get("world_build_count", -1)) == 0
		and not bool(unknown_index.get("ok", true))
		and String(unknown_index.get("failure_code", "")) == "UNKNOWN_GQ9_GENERATOR_INDEX"
		and int(unknown_index.get("world_build_count", -1)) == 0
		and not bool(tampered.get("ok", true))
		and String(tampered.get("failure_code", "")) == "GQ9_GENERATOR_RECEIPT_DIGEST_MISMATCH"
		and int(tampered.get("world_build_count", -1)) == 0
		and not bool(invalid_role.get("ok", true))
		and String(invalid_role.get("failure_code", "")) == "INVALID_GQ9_CAMPAIGN_ROLE"
		and int(invalid_role.get("world_build_count", -1)) == 0
		and not bool(wrong_role.get("ok", true))
		and String(wrong_role.get("failure_code", "")) == "UNKNOWN_GQ9_MORPHOLOGY"
		and int(wrong_role.get("world_build_count", -1)) == 0
		and not bool(unknown_morphology.get("ok", true))
		and String(unknown_morphology.get("failure_code", "")) == "UNKNOWN_GQ9_MORPHOLOGY"
		and int(unknown_morphology.get("world_build_count", -1)) == 0
	)


static func _gq10_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gq10_generated_s097",
		"gq10_generated_s098",
		"gq10_generated_s099",
		"gq10_generated_s100",
		"gq10_generated_s101",
		"gq10_generated_s102",
		"gq10_generated_s103",
		"gq10_generated_s104",
		"gq10_generated_s105",
		"gq10_generated_s106",
		"gq10_generated_s107",
		"gq10_generated_s108",
	]
	var expected_held_out := [
		"gq10_generated_s901",
		"gq10_generated_s902",
		"gq10_generated_s903",
		"gq10_generated_s904",
		"gq10_generated_s905",
		"gq10_generated_s906",
		"gq10_generated_s907",
		"gq10_generated_s908",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		realized_selection.append(String((cell_value as Dictionary)["morphology_id"]))
	for cell_value in held_out:
		realized_held_out.append(String((cell_value as Dictionary)["morphology_id"]))
	var index_set: Dictionary = {}
	for generator_index in ProportionSpecScript.GQ10_SELECTION_INDICES:
		index_set[int(generator_index)] = true
	for generator_index in ProportionSpecScript.GQ10_HELD_OUT_INDICES:
		if index_set.has(int(generator_index)):
			return false
		index_set[int(generator_index)] = true
	return (
		selection.size() == 12
		and held_out.size() == 8
		and realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			ProportionSpecScript.GQ10_SELECTION_INDICES
			== [97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108]
		)
		and (ProportionSpecScript.GQ10_HELD_OUT_INDICES == [901, 902, 903, 904, 905, 906, 907, 908])
		and index_set.size() == 20
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq10_generated_s097",
					"selection",
					ProportionSpecScript.CAMPAIGN_GQ10,
				)
			)
			== selection[0]
		)
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq10_generated_s901",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GQ10,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq10_generated_s901",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ10,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq9_generated_s097",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ10,
			)
			. is_empty()
		)
	)


static func _expected_gq10_generation(generator_index: int, campaign_role: String) -> Dictionary:
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": ProportionSpecScript.SCHEMA_VERSION,
		"morphology_id": "gq10_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in ProportionSpecScript.GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(ProportionSpecScript.GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _test_radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = ProportionSpecScript.GQ1_AXIS_INTERVALS[axis_key]
		var reference_value := float(interval[0])
		var lower_endpoint := float(interval[1])
		var upper_endpoint := float(interval[2])
		var endpoint_distance := (
			reference_value - lower_endpoint
			if centered_coordinate < 0.0
			else upper_endpoint - reference_value
		)
		var realized_value := (
			reference_value + shell_fraction * centered_coordinate * endpoint_distance
		)
		proportion_spec[axis_key] = realized_value
		axis_coordinates[axis_key] = {
			"base": axis_base,
			"radical_inverse": radical_inverse,
			"centered_coordinate": centered_coordinate,
			"reference_value": reference_value,
			"lower_endpoint": lower_endpoint,
			"upper_endpoint": upper_endpoint,
			"realized_value": realized_value,
		}
	var generator_receipt := {
		"schema_version": ProportionSpecScript.GQ10_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": ProportionSpecScript.GQ10_GENERATOR_POLICY_ID,
		"campaign_id": ProportionSpecScript.CAMPAIGN_GQ10,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"proportion_spec": proportion_spec,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
	}


static func _gq10_generation_formula_exact(selection: Array, held_out: Array) -> bool:
	var indices := [
		97,
		98,
		99,
		100,
		101,
		102,
		103,
		104,
		105,
		106,
		107,
		108,
		901,
		902,
		903,
		904,
		905,
		906,
		907,
		908,
	]
	var cells := selection + held_out
	var digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var campaign_role := "selection" if cell_index < selection.size() else "heldout"
		var expected := _expected_gq10_generation(generator_index, campaign_role)
		var realized := ProportionSpecScript.compile_gq10_generation(generator_index)
		var digest := String(realized.get("generator_receipt_sha256", ""))
		var verified := ProportionSpecScript.verify_gq10_generation(generator_index, digest)
		if (
			not bool(realized.get("ok", false))
			or int(realized.get("world_build_count", -1)) != 0
			or (realized.get("proportion_spec", {}) as Dictionary) != cells[cell_index]
			or realized.get("proportion_spec", {}) != expected["proportion_spec"]
			or realized.get("generator_receipt", {}) != expected["generator_receipt"]
			or digest != String(expected["generator_receipt_sha256"])
			or not bool(verified.get("ok", false))
			or int(verified.get("world_build_count", -1)) != 0
		):
			return false
		digests[digest] = true
	var old_gq9_request := ProportionSpecScript.compile_gq9_generation(97)
	return (
		digests.size() == indices.size()
		and not bool(old_gq9_request.get("ok", true))
		and String(old_gq9_request.get("failure_code", "")) == "UNKNOWN_GQ9_GENERATOR_INDEX"
		and int(old_gq9_request.get("world_build_count", -1)) == 0
	)


static func _test_gq10_yaw_gain(
	score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if foot_radius_scale < 0.985:
		return 1.3 if score >= 0.9 else 1.1
	if score < 0.5 or foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if absf(hip_span_scale - 1.0) >= 0.02:
		return 1.1 if torso_length_scale > 1.02 else 1.0
	return 1.0


static func _test_gq10_velocity_gain(
	score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	yaw_gain: float,
) -> float:
	if yaw_gain > 1.0:
		return 0.20
	if score < 0.15:
		return 0.25 if torso_width_scale <= 1.0 else 0.35
	if score < 0.5:
		return 0.70 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((score - 0.5) / 0.5, 0.0, 1.0)
	return 0.35


static func _gq10_controller_derivation_and_boundaries_exact(cells: Array) -> bool:
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := _test_morphology_interaction_score(cell)
		var torso_length_scale := float(cell["torso_length_scale"])
		var torso_width_scale := float(cell["torso_width_scale"])
		var foot_radius_scale := float(cell["foot_radius_scale"])
		var hip_span_scale := float(cell["hip_span_scale"])
		var expected_yaw_gain := _test_gq10_yaw_gain(
			score,
			torso_length_scale,
			foot_radius_scale,
			hip_span_scale,
		)
		var expected_path := CampaignScript.GQ10_PATH_STEERING_OPTIONS.duplicate(true)
		expected_path["cross_track_heading_gain_rad_per_m"] = 1.0 if score < 0.5 else 0.75
		expected_path["yaw_error_stride_gain_per_rad"] = expected_yaw_gain
		expected_path["cross_track_velocity_heading_gain_rad_per_m_s"] = (_test_gq10_velocity_gain(
			score,
			torso_length_scale,
			torso_width_scale,
			expected_yaw_gain,
		))
		var expected_guard_fraction := 0.80 if score >= 0.5 else 0.90
		var expected_guard_speed := 2.0 if score >= 0.5 else 2.5
		var path_options := (
			CampaignScript
			. _path_steering_options(
				CampaignScript.CAMPAIGN_GQ10,
				cell,
			)
		)
		var motor_options := (
			CampaignScript
			. _motor_velocity_options(
				CampaignScript.CAMPAIGN_GQ10,
				cell,
			)
		)
		var digest := (
			CampaignScript
			. _expected_controller_sha256(
				CampaignScript.CAMPAIGN_GQ10,
				motor_options,
				path_options,
			)
		)
		var metadata_varied := cell.duplicate(true)
		metadata_varied["morphology_id"] = "%s_renamed" % String(cell["morphology_id"])
		metadata_varied["generator_index"] = 999
		metadata_varied["seed"] = 123456
		metadata_varied["campaign_role"] = "heldout"
		metadata_varied["repetition"] = 3
		metadata_varied["walking_observed"] = false
		if (
			path_options != expected_path
			or not is_equal_approx(
				float(motor_options.get("morphology_interaction_score", NAN)),
				score,
			)
			or not is_equal_approx(
				float(motor_options.get("anchor_error_guard_activation_fraction", NAN)),
				expected_guard_fraction,
			)
			or not is_equal_approx(
				float(
					(
						motor_options
						. get(
							"anchor_error_guard_maximum_motor_target_speed_rad_s",
							NAN,
						)
					)
				),
				expected_guard_speed,
			)
			or (
				(
					CampaignScript
					. _path_steering_options(
						CampaignScript.CAMPAIGN_GQ10,
						metadata_varied,
					)
				)
				!= path_options
			)
			or (
				(
					CampaignScript
					. _motor_velocity_options(
						CampaignScript.CAMPAIGN_GQ10,
						metadata_varied,
					)
				)
				!= motor_options
			)
			or not digest.begins_with("sha256:")
			or digest.length() != 71
		):
			return false
		controller_digests[digest] = true
	var valid_path := CampaignScript.GQ10_PATH_STEERING_OPTIONS.duplicate(true)
	var valid_path_result := WaveGaitScript._normalize_path_steering_options(valid_path, 360)
	var nonfinite_path := valid_path.duplicate(true)
	nonfinite_path["cross_track_velocity_heading_gain_rad_per_m_s"] = INF
	var nonfinite_path_result := (
		WaveGaitScript
		. _normalize_path_steering_options(
			nonfinite_path,
			360,
		)
	)
	var unknown_path := valid_path.duplicate(true)
	unknown_path["runtime_outcome_gain"] = 0.2
	var unknown_path_result := (
		WaveGaitScript
		. _normalize_path_steering_options(
			unknown_path,
			360,
		)
	)
	var smooth_middle_gain := 0.25 - 0.05 * ((0.75 - 0.5) / 0.5)
	return (
		controller_digests.size() > 2
		and bool(valid_path_result.get("ok", false))
		and (valid_path_result.get("path_steering_options", {}) as Dictionary) == valid_path
		and not bool(nonfinite_path_result.get("ok", true))
		and int(nonfinite_path_result.get("world_build_count", -1)) == 0
		and not bool(unknown_path_result.get("ok", true))
		and String(unknown_path_result.get("failure_code", "")) == "UNKNOWN_PATH_STEERING_OPTION"
		and int(unknown_path_result.get("world_build_count", -1)) == 0
		and is_equal_approx(CampaignScript._gq10_cross_track_gain_per_m(0.499999), 1.0)
		and is_equal_approx(CampaignScript._gq10_cross_track_gain_per_m(0.5), 0.75)
		and is_equal_approx(
			CampaignScript._gq10_yaw_gain_per_rad(0.899999, 1.0, 0.984999, 1.0),
			1.1,
		)
		and is_equal_approx(
			CampaignScript._gq10_yaw_gain_per_rad(0.9, 1.0, 0.984999, 1.0),
			1.3,
		)
		and is_equal_approx(
			CampaignScript._gq10_yaw_gain_per_rad(0.1, 1.0, 0.985, 1.0),
			1.0,
		)
		and is_equal_approx(
			CampaignScript._gq10_yaw_gain_per_rad(0.5, 1.0, 1.025, 1.0),
			1.3,
		)
		and is_equal_approx(
			CampaignScript._gq10_yaw_gain_per_rad(0.5, 1.0, 1.025001, 1.0),
			1.0,
		)
		and is_equal_approx(
			CampaignScript._gq10_yaw_gain_per_rad(0.5, 1.020001, 1.01, 1.02),
			1.1,
		)
		and is_equal_approx(
			CampaignScript._gq10_yaw_gain_per_rad(0.5, 1.02, 1.01, 1.02),
			1.0,
		)
		and is_equal_approx(
			CampaignScript._gq10_yaw_gain_per_rad(0.5, 1.1, 1.01, 1.019999),
			1.0,
		)
		and is_equal_approx(
			CampaignScript._gq10_velocity_gain_rad_per_m_s(1.0, 1.0, 1.0, 1.1),
			0.20,
		)
		and is_equal_approx(
			CampaignScript._gq10_velocity_gain_rad_per_m_s(0.149999, 1.0, 1.0, 1.0),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq10_velocity_gain_rad_per_m_s(0.149999, 1.0, 1.000001, 1.0),
			0.35,
		)
		and is_equal_approx(
			CampaignScript._gq10_velocity_gain_rad_per_m_s(0.15, 1.0, 1.0, 1.0),
			0.70,
		)
		and is_equal_approx(
			CampaignScript._gq10_velocity_gain_rad_per_m_s(0.15, 1.0, 1.000001, 1.0),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq10_velocity_gain_rad_per_m_s(0.5, 0.999999, 1.000001, 1.0),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq10_velocity_gain_rad_per_m_s(0.75, 0.999999, 1.000001, 1.0),
			smooth_middle_gain,
		)
		and is_equal_approx(
			CampaignScript._gq10_velocity_gain_rad_per_m_s(1.0, 0.999999, 1.000001, 1.0),
			0.20,
		)
		and is_equal_approx(
			CampaignScript._gq10_velocity_gain_rad_per_m_s(0.75, 0.999999, 1.0, 1.0),
			0.35,
		)
		and is_equal_approx(
			CampaignScript._gq10_velocity_gain_rad_per_m_s(0.75, 1.0, 1.000001, 1.0),
			0.35,
		)
		and CampaignScript._gq10_motor_guard_values(0.499999) == [0.90, 2.5]
		and CampaignScript._gq10_motor_guard_values(0.5) == [0.80, 2.0]
	)


static func _gq10_clock_solver_and_thresholds_exact(compiled_cells: Array) -> bool:
	if compiled_cells.is_empty():
		return false
	var clock := ClockSpecScript.gq10_clock()
	var clock_result := ClockSpecScript.compile(clock)
	var bad_clock := clock.duplicate(true)
	bad_clock["evidence_cycles"] = 3
	var bad_clock_result := ClockSpecScript.compile(bad_clock)
	var solver_result := (
		WaveGaitScript
		. compile_solver_policy_options(
			CampaignScript.GP4_SOLVER_POLICY_OPTIONS,
		)
	)
	var fixture: Dictionary = (compiled_cells[0] as Dictionary)["fixture_spec"]
	var torso_size: Array = (fixture["torso"] as Dictionary)["size_m"]
	var first_limb: Dictionary = (fixture["limbs"] as Array)[0]
	var thresholds := (
		CampaignScript
		. _evidence_thresholds(
			fixture,
			CampaignScript.CAMPAIGN_GQ10,
		)
	)
	var threshold_result := WaveGaitScript.compile_evidence_threshold_options(thresholds)
	var unknown_threshold := thresholds.duplicate(true)
	unknown_threshold["relax_after_failure"] = true
	var unknown_threshold_result := (
		WaveGaitScript
		. compile_evidence_threshold_options(
			unknown_threshold,
		)
	)
	return (
		bool(clock_result.get("ok", false))
		and int(clock_result.get("world_build_count", -1)) == 0
		and (clock_result.get("gait_clock_options", {}) as Dictionary) == clock
		and String(clock.get("policy_id", "")) == ClockSpecScript.GQ10_POLICY_ID
		and ClockSpecScript.GQ10_POLICY_ID != ClockSpecScript.GQ9_POLICY_ID
		and int(clock.get("cycle_ticks", -1)) == 360
		and int(clock.get("evidence_cycles", -1)) == 4
		and int(clock.get("maximum_contact_gate_hold_ticks", -1)) == 120
		and int(clock.get("maximum_contact_gated_evidence_extension_ticks", -1)) == 720
		and int(clock.get("maximum_contact_gated_phase_skew_ticks", -1)) == 12
		and not bool(bad_clock_result.get("ok", true))
		and int(bad_clock_result.get("world_build_count", -1)) == 0
		and bool(solver_result.get("ok", false))
		and int(solver_result.get("world_build_count", -1)) == 0
		and (
			(solver_result.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_velocity_steps"]) == 20
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_position_steps"]) == 7
		and bool(threshold_result.get("ok", false))
		and int(threshold_result.get("world_build_count", -1)) == 0
		and (threshold_result.get("evidence_threshold_options", {}) as Dictionary) == thresholds
		and is_equal_approx(
			float(thresholds.get("minimum_foot_relocation_m", NAN)),
			0.0238 * float(torso_size[0]),
		)
		and is_equal_approx(
			float(thresholds.get("maximum_anchor_error_m", NAN)),
			0.14 * float(first_limb["upper_length_m"]),
		)
		and not bool(unknown_threshold_result.get("ok", true))
		and int(unknown_threshold_result.get("world_build_count", -1)) == 0
	)


static func _gq10_policy_preservation_and_fail_closed_exact(
	selection: Array,
	held_out: Array,
) -> bool:
	var prior_digests := [
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ1)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ2)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ3)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ4)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ5)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ6)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ7)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ8)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ9)),
	]
	var expected_prior_digests := [
		"sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698",
		"sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463",
		"sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253",
		"sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38",
		"sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb",
		"sha256:1c099d6c3179323c9e2dbdf20adcfd1cb91e11221fd0d2a49f349acec512a85f",
		"sha256:32c68e0d0f1c4ecb54499793a2f090e7bee37846f6babf27f563bd5afb5c0346",
		"sha256:c39d147f61057cb4b96e745b5aa7258bbfbcbfedaab4116a93b518f2b46348a0",
		"sha256:3410448ca5b7b35e06310abcc794ca0acaeaa3d559de37a19ef9e666c80d1c74",
	]
	var policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ10)
	var policy_digest := CanonicalJsonScript.sha256(policy)
	var first_generation := ProportionSpecScript.compile_gq10_generation(97)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var tampered_digest := first_digest.left(70) + ("0" if first_digest.right(1) != "0" else "1")
	var wrong_type := ProportionSpecScript.compile_gq10_generation(97.0)
	var unknown_index := ProportionSpecScript.compile_gq10_generation(109)
	var tampered := ProportionSpecScript.verify_gq10_generation(97, tampered_digest)
	var invalid_role := (
		ProportionSpecScript
		. gq10_generation_for_morphology(
			"gq10_generated_s097",
			"invalid",
		)
	)
	var wrong_role := (
		ProportionSpecScript
		. gq10_generation_for_morphology(
			"gq10_generated_s097",
			"heldout",
		)
	)
	var unknown_morphology := (
		ProportionSpecScript
		. gq10_generation_for_morphology(
			"gq10_generated_s999",
			"selection",
		)
	)
	return (
		prior_digests == expected_prior_digests
		and (
			String(policy.get("schema_version", ""))
			== "sporespore_g4_gq10_perturbation_margin_velocity_feedback_policy_v1"
		)
		and String(policy.get("campaign_id", "")) == CampaignScript.CAMPAIGN_GQ10
		and (policy.get("selection_cells", []) as Array) == selection
		and (policy.get("held_out_cells", []) as Array) == held_out
		and (
			String(policy.get("generator_policy_id", ""))
			== ProportionSpecScript.GQ10_GENERATOR_POLICY_ID
		)
		and (
			String(policy.get("generator_schema_version", ""))
			== ProportionSpecScript.GQ10_GENERATOR_SCHEMA_VERSION
		)
		and (
			(policy.get("selection_generator_indices", []) as Array)
			== ProportionSpecScript.GQ10_SELECTION_INDICES
		)
		and (
			(policy.get("held_out_generator_indices", []) as Array)
			== ProportionSpecScript.GQ10_HELD_OUT_INDICES
		)
		and (policy.get("generator_receipts", []) as Array).size() == 20
		and String(policy.get("clock_policy_id", "")) == ClockSpecScript.GQ10_POLICY_ID
		and (policy.get("clock_options", {}) as Dictionary) == ClockSpecScript.gq10_clock()
		and (
			(policy.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and (
			(policy.get("robustness_options", {}) as Dictionary)
			== CampaignScript.GQ10_ROBUSTNESS_OPTIONS
		)
		and (
			String(policy.get("path_velocity_gain_derivation_id", ""))
			== "yaw_score_width_length_perturbation_margin_v4"
		)
		and (
			String(policy.get("path_velocity_gain_formula", ""))
			== (
				"0.20 if Y>1 else (0.25 if S<0.15 and W<=1 else "
				+ "(0.35 if S<0.15 else (0.70 if S<0.5 and W<=1 else "
				+ "(0.25 if S<0.5 else "
				+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else 0.35)))))"
			)
		)
		and not policy.has("controller_sha256")
		and policy_digest.begins_with("sha256:")
		and policy_digest.length() == 71
		and policy_digest not in prior_digests
		and not bool(wrong_type.get("ok", true))
		and String(wrong_type.get("failure_code", "")) == "INVALID_GQ10_GENERATOR_INDEX_TYPE"
		and int(wrong_type.get("world_build_count", -1)) == 0
		and not bool(unknown_index.get("ok", true))
		and String(unknown_index.get("failure_code", "")) == "UNKNOWN_GQ10_GENERATOR_INDEX"
		and int(unknown_index.get("world_build_count", -1)) == 0
		and not bool(tampered.get("ok", true))
		and String(tampered.get("failure_code", "")) == "GQ10_GENERATOR_RECEIPT_DIGEST_MISMATCH"
		and int(tampered.get("world_build_count", -1)) == 0
		and not bool(invalid_role.get("ok", true))
		and String(invalid_role.get("failure_code", "")) == "INVALID_GQ10_CAMPAIGN_ROLE"
		and int(invalid_role.get("world_build_count", -1)) == 0
		and not bool(wrong_role.get("ok", true))
		and String(wrong_role.get("failure_code", "")) == "UNKNOWN_GQ10_MORPHOLOGY"
		and int(wrong_role.get("world_build_count", -1)) == 0
		and not bool(unknown_morphology.get("ok", true))
		and String(unknown_morphology.get("failure_code", "")) == "UNKNOWN_GQ10_MORPHOLOGY"
		and int(unknown_morphology.get("world_build_count", -1)) == 0
	)


static func _gq11_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection := [
		"gq11_generated_s109",
		"gq11_generated_s110",
		"gq11_generated_s111",
		"gq11_generated_s112",
		"gq11_generated_s113",
		"gq11_generated_s114",
		"gq11_generated_s115",
		"gq11_generated_s116",
		"gq11_generated_s117",
		"gq11_generated_s118",
		"gq11_generated_s119",
		"gq11_generated_s120",
	]
	var expected_held_out := [
		"gq11_generated_s1001",
		"gq11_generated_s1002",
		"gq11_generated_s1003",
		"gq11_generated_s1004",
		"gq11_generated_s1005",
		"gq11_generated_s1006",
		"gq11_generated_s1007",
		"gq11_generated_s1008",
	]
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		realized_selection.append(String((cell_value as Dictionary)["morphology_id"]))
	for cell_value in held_out:
		realized_held_out.append(String((cell_value as Dictionary)["morphology_id"]))
	var index_set: Dictionary = {}
	for generator_index in ProportionSpecScript.GQ11_SELECTION_INDICES:
		index_set[int(generator_index)] = true
	for generator_index in ProportionSpecScript.GQ11_HELD_OUT_INDICES:
		if index_set.has(int(generator_index)):
			return false
		index_set[int(generator_index)] = true
	return (
		selection.size() == 12
		and held_out.size() == 8
		and realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			ProportionSpecScript.GQ11_SELECTION_INDICES
			== [109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120]
		)
		and (
			ProportionSpecScript.GQ11_HELD_OUT_INDICES
			== [1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008]
		)
		and index_set.size() == 20
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq11_generated_s109",
					"selection",
					ProportionSpecScript.CAMPAIGN_GQ11,
				)
			)
			== selection[0]
		)
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq11_generated_s1001",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GQ11,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq11_generated_s1001",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ11,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq10_generated_s109",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ11,
			)
			. is_empty()
		)
	)


static func _expected_gq11_generation(generator_index: int, campaign_role: String) -> Dictionary:
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": ProportionSpecScript.SCHEMA_VERSION,
		"morphology_id": "gq11_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in ProportionSpecScript.GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(ProportionSpecScript.GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _test_radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = ProportionSpecScript.GQ1_AXIS_INTERVALS[axis_key]
		var reference_value := float(interval[0])
		var lower_endpoint := float(interval[1])
		var upper_endpoint := float(interval[2])
		var endpoint_distance := (
			reference_value - lower_endpoint
			if centered_coordinate < 0.0
			else upper_endpoint - reference_value
		)
		var realized_value := (
			reference_value + shell_fraction * centered_coordinate * endpoint_distance
		)
		proportion_spec[axis_key] = realized_value
		axis_coordinates[axis_key] = {
			"base": axis_base,
			"radical_inverse": radical_inverse,
			"centered_coordinate": centered_coordinate,
			"reference_value": reference_value,
			"lower_endpoint": lower_endpoint,
			"upper_endpoint": upper_endpoint,
			"realized_value": realized_value,
		}
	var generator_receipt := {
		"schema_version": ProportionSpecScript.GQ11_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": ProportionSpecScript.GQ11_GENERATOR_POLICY_ID,
		"campaign_id": ProportionSpecScript.CAMPAIGN_GQ11,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"proportion_spec": proportion_spec,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
	}


static func _gq11_generation_formula_exact(selection: Array, held_out: Array) -> bool:
	var indices := [
		109,
		110,
		111,
		112,
		113,
		114,
		115,
		116,
		117,
		118,
		119,
		120,
		1001,
		1002,
		1003,
		1004,
		1005,
		1006,
		1007,
		1008,
	]
	var cells := selection + held_out
	var digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var campaign_role := "selection" if cell_index < selection.size() else "heldout"
		var expected := _expected_gq11_generation(generator_index, campaign_role)
		var realized := ProportionSpecScript.compile_gq11_generation(generator_index)
		var digest := String(realized.get("generator_receipt_sha256", ""))
		var verified := ProportionSpecScript.verify_gq11_generation(generator_index, digest)
		if (
			not bool(realized.get("ok", false))
			or int(realized.get("world_build_count", -1)) != 0
			or (realized.get("proportion_spec", {}) as Dictionary) != cells[cell_index]
			or realized.get("proportion_spec", {}) != expected["proportion_spec"]
			or realized.get("generator_receipt", {}) != expected["generator_receipt"]
			or digest != String(expected["generator_receipt_sha256"])
			or not bool(verified.get("ok", false))
			or int(verified.get("world_build_count", -1)) != 0
		):
			return false
		digests[digest] = true
	var old_gq10_request := ProportionSpecScript.compile_gq10_generation(109)
	return (
		digests.size() == indices.size()
		and not bool(old_gq10_request.get("ok", true))
		and (String(old_gq10_request.get("failure_code", "")) == "UNKNOWN_GQ10_GENERATOR_INDEX")
		and int(old_gq10_request.get("world_build_count", -1)) == 0
	)


static func _test_gq11_velocity_gain(
	score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	yaw_gain: float,
) -> float:
	if yaw_gain > 1.0:
		return 0.25
	if score < 0.15:
		return 0.275 if torso_width_scale <= 1.0 else 0.35
	if score < 0.5:
		return 0.70 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((score - 0.5) / 0.5, 0.0, 1.0)
	return 0.35


static func _gq11_controller_derivation_and_boundaries_exact(cells: Array) -> bool:
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := _test_morphology_interaction_score(cell)
		var torso_length_scale := float(cell["torso_length_scale"])
		var torso_width_scale := float(cell["torso_width_scale"])
		var foot_radius_scale := float(cell["foot_radius_scale"])
		var hip_span_scale := float(cell["hip_span_scale"])
		var expected_yaw_gain := _test_gq10_yaw_gain(
			score,
			torso_length_scale,
			foot_radius_scale,
			hip_span_scale,
		)
		var expected_path := CampaignScript.GQ11_PATH_STEERING_OPTIONS.duplicate(true)
		expected_path["cross_track_heading_gain_rad_per_m"] = 1.0 if score < 0.5 else 0.75
		expected_path["yaw_error_stride_gain_per_rad"] = expected_yaw_gain
		expected_path["cross_track_velocity_heading_gain_rad_per_m_s"] = (_test_gq11_velocity_gain(
			score,
			torso_length_scale,
			torso_width_scale,
			expected_yaw_gain,
		))
		var expected_guard_fraction := 0.80 if score >= 0.5 else 0.90
		var expected_guard_speed := 2.0 if score >= 0.5 else 2.5
		var path_options := (
			CampaignScript
			. _path_steering_options(
				CampaignScript.CAMPAIGN_GQ11,
				cell,
			)
		)
		var motor_options := (
			CampaignScript
			. _motor_velocity_options(
				CampaignScript.CAMPAIGN_GQ11,
				cell,
			)
		)
		var digest := (
			CampaignScript
			. _expected_controller_sha256(
				CampaignScript.CAMPAIGN_GQ11,
				motor_options,
				path_options,
			)
		)
		var metadata_varied := cell.duplicate(true)
		metadata_varied["morphology_id"] = "%s_renamed" % String(cell["morphology_id"])
		metadata_varied["generator_index"] = 999
		metadata_varied["seed"] = 123456
		metadata_varied["campaign_role"] = "heldout"
		metadata_varied["repetition"] = 3
		metadata_varied["walking_observed"] = false
		if (
			path_options != expected_path
			or not is_equal_approx(
				float(motor_options.get("morphology_interaction_score", NAN)),
				score,
			)
			or not is_equal_approx(
				float(motor_options.get("anchor_error_guard_activation_fraction", NAN)),
				expected_guard_fraction,
			)
			or not is_equal_approx(
				float(
					(
						motor_options
						. get(
							"anchor_error_guard_maximum_motor_target_speed_rad_s",
							NAN,
						)
					)
				),
				expected_guard_speed,
			)
			or (
				(
					CampaignScript
					. _path_steering_options(
						CampaignScript.CAMPAIGN_GQ11,
						metadata_varied,
					)
				)
				!= path_options
			)
			or (
				(
					CampaignScript
					. _motor_velocity_options(
						CampaignScript.CAMPAIGN_GQ11,
						metadata_varied,
					)
				)
				!= motor_options
			)
			or not digest.begins_with("sha256:")
			or digest.length() != 71
		):
			return false
		controller_digests[digest] = true
	var valid_path := CampaignScript.GQ11_PATH_STEERING_OPTIONS.duplicate(true)
	var valid_path_result := WaveGaitScript._normalize_path_steering_options(valid_path, 360)
	var nonfinite_path := valid_path.duplicate(true)
	nonfinite_path["cross_track_velocity_heading_gain_rad_per_m_s"] = INF
	var nonfinite_path_result := (
		WaveGaitScript
		. _normalize_path_steering_options(
			nonfinite_path,
			360,
		)
	)
	var unknown_path := valid_path.duplicate(true)
	unknown_path["runtime_outcome_gain"] = 0.2
	var unknown_path_result := (
		WaveGaitScript
		. _normalize_path_steering_options(
			unknown_path,
			360,
		)
	)
	var smooth_middle_gain := 0.25 - 0.05 * ((0.75 - 0.5) / 0.5)
	return (
		controller_digests.size() > 2
		and bool(valid_path_result.get("ok", false))
		and (valid_path_result.get("path_steering_options", {}) as Dictionary) == valid_path
		and not bool(nonfinite_path_result.get("ok", true))
		and int(nonfinite_path_result.get("world_build_count", -1)) == 0
		and not bool(unknown_path_result.get("ok", true))
		and (String(unknown_path_result.get("failure_code", "")) == "UNKNOWN_PATH_STEERING_OPTION")
		and int(unknown_path_result.get("world_build_count", -1)) == 0
		and is_equal_approx(CampaignScript._gq11_cross_track_gain_per_m(0.499999), 1.0)
		and is_equal_approx(CampaignScript._gq11_cross_track_gain_per_m(0.5), 0.75)
		and is_equal_approx(
			CampaignScript._gq11_yaw_gain_per_rad(0.899999, 1.0, 0.984999, 1.0),
			1.1,
		)
		and is_equal_approx(
			CampaignScript._gq11_yaw_gain_per_rad(0.9, 1.0, 0.984999, 1.0),
			1.3,
		)
		and is_equal_approx(
			CampaignScript._gq11_yaw_gain_per_rad(0.1, 1.0, 0.985, 1.0),
			1.0,
		)
		and is_equal_approx(
			CampaignScript._gq11_yaw_gain_per_rad(0.5, 1.0, 1.025, 1.0),
			1.3,
		)
		and is_equal_approx(
			CampaignScript._gq11_yaw_gain_per_rad(0.5, 1.0, 1.025001, 1.0),
			1.0,
		)
		and is_equal_approx(
			CampaignScript._gq11_yaw_gain_per_rad(0.5, 1.020001, 1.01, 1.02),
			1.1,
		)
		and is_equal_approx(
			CampaignScript._gq11_yaw_gain_per_rad(0.5, 1.02, 1.01, 1.02),
			1.0,
		)
		and is_equal_approx(
			CampaignScript._gq11_yaw_gain_per_rad(0.5, 1.1, 1.01, 1.019999),
			1.0,
		)
		and is_equal_approx(
			CampaignScript._gq11_velocity_gain_rad_per_m_s(1.0, 1.0, 1.0, 1.1),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq11_velocity_gain_rad_per_m_s(0.149999, 1.0, 1.0, 1.0),
			0.275,
		)
		and is_equal_approx(
			CampaignScript._gq11_velocity_gain_rad_per_m_s(0.149999, 1.0, 1.000001, 1.0),
			0.35,
		)
		and is_equal_approx(
			CampaignScript._gq11_velocity_gain_rad_per_m_s(0.15, 1.0, 1.0, 1.0),
			0.70,
		)
		and is_equal_approx(
			CampaignScript._gq11_velocity_gain_rad_per_m_s(0.15, 1.0, 1.000001, 1.0),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq11_velocity_gain_rad_per_m_s(0.5, 0.999999, 1.000001, 1.0),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq11_velocity_gain_rad_per_m_s(0.75, 0.999999, 1.000001, 1.0),
			smooth_middle_gain,
		)
		and is_equal_approx(
			CampaignScript._gq11_velocity_gain_rad_per_m_s(1.0, 0.999999, 1.000001, 1.0),
			0.20,
		)
		and is_equal_approx(
			CampaignScript._gq11_velocity_gain_rad_per_m_s(0.75, 0.999999, 1.0, 1.0),
			0.35,
		)
		and is_equal_approx(
			CampaignScript._gq11_velocity_gain_rad_per_m_s(0.75, 1.0, 1.000001, 1.0),
			0.35,
		)
		and CampaignScript._gq11_motor_guard_values(0.499999) == [0.90, 2.5]
		and CampaignScript._gq11_motor_guard_values(0.5) == [0.80, 2.0]
	)


static func _gq11_clock_solver_and_thresholds_exact(compiled_cells: Array) -> bool:
	if compiled_cells.is_empty():
		return false
	var clock := ClockSpecScript.gq11_clock()
	var clock_result := ClockSpecScript.compile(clock)
	var bad_clock := clock.duplicate(true)
	bad_clock["evidence_cycles"] = 3
	var bad_clock_result := ClockSpecScript.compile(bad_clock)
	var solver_result := (
		WaveGaitScript
		. compile_solver_policy_options(
			CampaignScript.GP4_SOLVER_POLICY_OPTIONS,
		)
	)
	var fixture: Dictionary = (compiled_cells[0] as Dictionary)["fixture_spec"]
	var torso_size: Array = (fixture["torso"] as Dictionary)["size_m"]
	var first_limb: Dictionary = (fixture["limbs"] as Array)[0]
	var thresholds := (
		CampaignScript
		. _evidence_thresholds(
			fixture,
			CampaignScript.CAMPAIGN_GQ11,
		)
	)
	var threshold_result := WaveGaitScript.compile_evidence_threshold_options(thresholds)
	var unknown_threshold := thresholds.duplicate(true)
	unknown_threshold["relax_after_failure"] = true
	var unknown_threshold_result := (
		WaveGaitScript
		. compile_evidence_threshold_options(
			unknown_threshold,
		)
	)
	return (
		bool(clock_result.get("ok", false))
		and int(clock_result.get("world_build_count", -1)) == 0
		and (clock_result.get("gait_clock_options", {}) as Dictionary) == clock
		and String(clock.get("policy_id", "")) == ClockSpecScript.GQ11_POLICY_ID
		and ClockSpecScript.GQ11_POLICY_ID != ClockSpecScript.GQ10_POLICY_ID
		and int(clock.get("cycle_ticks", -1)) == 360
		and int(clock.get("evidence_cycles", -1)) == 4
		and int(clock.get("maximum_contact_gate_hold_ticks", -1)) == 120
		and int(clock.get("maximum_contact_gated_evidence_extension_ticks", -1)) == 720
		and int(clock.get("maximum_contact_gated_phase_skew_ticks", -1)) == 12
		and not bool(bad_clock_result.get("ok", true))
		and int(bad_clock_result.get("world_build_count", -1)) == 0
		and bool(solver_result.get("ok", false))
		and int(solver_result.get("world_build_count", -1)) == 0
		and (
			(solver_result.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_velocity_steps"]) == 20
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_position_steps"]) == 7
		and bool(threshold_result.get("ok", false))
		and int(threshold_result.get("world_build_count", -1)) == 0
		and (threshold_result.get("evidence_threshold_options", {}) as Dictionary) == thresholds
		and is_equal_approx(
			float(thresholds.get("minimum_foot_relocation_m", NAN)),
			0.0238 * float(torso_size[0]),
		)
		and is_equal_approx(
			float(thresholds.get("maximum_anchor_error_m", NAN)),
			0.14 * float(first_limb["upper_length_m"]),
		)
		and not bool(unknown_threshold_result.get("ok", true))
		and int(unknown_threshold_result.get("world_build_count", -1)) == 0
	)


static func _gq11_policy_preservation_and_fail_closed_exact(
	selection: Array,
	held_out: Array,
) -> bool:
	var prior_digests := [
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ1)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ2)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ3)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ4)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ5)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ6)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ7)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ8)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ9)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ10)),
	]
	var expected_prior_digests := [
		"sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698",
		"sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463",
		"sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253",
		"sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38",
		"sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb",
		"sha256:1c099d6c3179323c9e2dbdf20adcfd1cb91e11221fd0d2a49f349acec512a85f",
		"sha256:32c68e0d0f1c4ecb54499793a2f090e7bee37846f6babf27f563bd5afb5c0346",
		"sha256:c39d147f61057cb4b96e745b5aa7258bbfbcbfedaab4116a93b518f2b46348a0",
		"sha256:3410448ca5b7b35e06310abcc794ca0acaeaa3d559de37a19ef9e666c80d1c74",
		"sha256:f487f4da8976a2295d6369057f21b60a2fe2688e78ccbeb4c80043d73b770fad",
	]
	var policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ11)
	var policy_digest := CanonicalJsonScript.sha256(policy)
	var first_generation := ProportionSpecScript.compile_gq11_generation(109)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var tampered_digest := first_digest.left(70) + ("0" if first_digest.right(1) != "0" else "1")
	var wrong_type := ProportionSpecScript.compile_gq11_generation(109.0)
	var unknown_index := ProportionSpecScript.compile_gq11_generation(121)
	var tampered := ProportionSpecScript.verify_gq11_generation(109, tampered_digest)
	var invalid_role := (
		ProportionSpecScript
		. gq11_generation_for_morphology(
			"gq11_generated_s109",
			"invalid",
		)
	)
	var wrong_role := (
		ProportionSpecScript
		. gq11_generation_for_morphology(
			"gq11_generated_s109",
			"heldout",
		)
	)
	var unknown_morphology := (
		ProportionSpecScript
		. gq11_generation_for_morphology(
			"gq11_generated_s999",
			"selection",
		)
	)
	return (
		prior_digests == expected_prior_digests
		and (
			String(policy.get("schema_version", ""))
			== "sporespore_g4_gq11_contact_and_lateral_margin_velocity_feedback_policy_v1"
		)
		and String(policy.get("campaign_id", "")) == CampaignScript.CAMPAIGN_GQ11
		and (policy.get("selection_cells", []) as Array) == selection
		and (policy.get("held_out_cells", []) as Array) == held_out
		and (
			String(policy.get("generator_policy_id", ""))
			== ProportionSpecScript.GQ11_GENERATOR_POLICY_ID
		)
		and (
			String(policy.get("generator_schema_version", ""))
			== ProportionSpecScript.GQ11_GENERATOR_SCHEMA_VERSION
		)
		and (
			(policy.get("selection_generator_indices", []) as Array)
			== ProportionSpecScript.GQ11_SELECTION_INDICES
		)
		and (
			(policy.get("held_out_generator_indices", []) as Array)
			== ProportionSpecScript.GQ11_HELD_OUT_INDICES
		)
		and (policy.get("generator_receipts", []) as Array).size() == 20
		and String(policy.get("clock_policy_id", "")) == ClockSpecScript.GQ11_POLICY_ID
		and (policy.get("clock_options", {}) as Dictionary) == ClockSpecScript.gq11_clock()
		and (
			(policy.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and (
			(policy.get("robustness_options", {}) as Dictionary)
			== CampaignScript.GQ11_ROBUSTNESS_OPTIONS
		)
		and (
			String(policy.get("path_velocity_gain_derivation_id", ""))
			== "yaw025_low_narrow_midpoint0275_v6"
		)
		and (
			String(policy.get("path_velocity_gain_formula", ""))
			== (
				"0.25 if Y>1 else (0.275 if S<0.15 and W<=1 else "
				+ "(0.35 if S<0.15 else (0.70 if S<0.5 and W<=1 else "
				+ "(0.25 if S<0.5 else "
				+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else 0.35)))))"
			)
		)
		and not policy.has("controller_sha256")
		and policy_digest.begins_with("sha256:")
		and policy_digest.length() == 71
		and policy_digest not in prior_digests
		and not bool(wrong_type.get("ok", true))
		and (String(wrong_type.get("failure_code", "")) == "INVALID_GQ11_GENERATOR_INDEX_TYPE")
		and int(wrong_type.get("world_build_count", -1)) == 0
		and not bool(unknown_index.get("ok", true))
		and String(unknown_index.get("failure_code", "")) == "UNKNOWN_GQ11_GENERATOR_INDEX"
		and int(unknown_index.get("world_build_count", -1)) == 0
		and not bool(tampered.get("ok", true))
		and (String(tampered.get("failure_code", "")) == "GQ11_GENERATOR_RECEIPT_DIGEST_MISMATCH")
		and int(tampered.get("world_build_count", -1)) == 0
		and not bool(invalid_role.get("ok", true))
		and (String(invalid_role.get("failure_code", "")) == "INVALID_GQ11_CAMPAIGN_ROLE")
		and int(invalid_role.get("world_build_count", -1)) == 0
		and not bool(wrong_role.get("ok", true))
		and String(wrong_role.get("failure_code", "")) == "UNKNOWN_GQ11_MORPHOLOGY"
		and int(wrong_role.get("world_build_count", -1)) == 0
		and not bool(unknown_morphology.get("ok", true))
		and (String(unknown_morphology.get("failure_code", "")) == "UNKNOWN_GQ11_MORPHOLOGY")
		and int(unknown_morphology.get("world_build_count", -1)) == 0
	)


static func _gq12_declared_ids_exact(selection: Array, held_out: Array) -> bool:
	var expected_selection: Array = []
	for generator_index in range(121, 133):
		expected_selection.append("gq12_generated_s%03d" % generator_index)
	var expected_held_out: Array = []
	for generator_index in range(1101, 1109):
		expected_held_out.append("gq12_generated_s%03d" % generator_index)
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		realized_selection.append(String((cell_value as Dictionary)["morphology_id"]))
	for cell_value in held_out:
		realized_held_out.append(String((cell_value as Dictionary)["morphology_id"]))
	var index_set: Dictionary = {}
	for generator_index in ProportionSpecScript.GQ12_SELECTION_INDICES:
		index_set[int(generator_index)] = true
	for generator_index in ProportionSpecScript.GQ12_HELD_OUT_INDICES:
		if index_set.has(int(generator_index)):
			return false
		index_set[int(generator_index)] = true
	return (
		selection.size() == 12
		and held_out.size() == 8
		and realized_selection == expected_selection
		and realized_held_out == expected_held_out
		and (
			ProportionSpecScript.GQ12_SELECTION_INDICES
			== [121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132]
		)
		and (
			ProportionSpecScript.GQ12_HELD_OUT_INDICES
			== [1101, 1102, 1103, 1104, 1105, 1106, 1107, 1108]
		)
		and index_set.size() == 20
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq12_generated_s121",
					"selection",
					ProportionSpecScript.CAMPAIGN_GQ12,
				)
			)
			== selection[0]
		)
		and (
			(
				ProportionSpecScript
				. declared_cell(
					"gq12_generated_s1101",
					"heldout",
					ProportionSpecScript.CAMPAIGN_GQ12,
				)
			)
			== held_out[0]
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq12_generated_s1101",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ12,
			)
			. is_empty()
		)
		and (
			ProportionSpecScript
			. declared_cell(
				"gq11_generated_s121",
				"selection",
				ProportionSpecScript.CAMPAIGN_GQ12,
			)
			. is_empty()
		)
	)


static func _expected_gq12_generation(generator_index: int, campaign_role: String) -> Dictionary:
	var predecessor := _expected_gq11_generation(generator_index, campaign_role)
	var proportion_spec: Dictionary = (predecessor["proportion_spec"] as Dictionary).duplicate(true)
	proportion_spec["morphology_id"] = "gq12_generated_s%03d" % generator_index
	var generator_receipt: Dictionary = (predecessor["generator_receipt"] as Dictionary).duplicate(
		true
	)
	generator_receipt["schema_version"] = ProportionSpecScript.GQ12_GENERATOR_SCHEMA_VERSION
	generator_receipt["generator_policy_id"] = ProportionSpecScript.GQ12_GENERATOR_POLICY_ID
	generator_receipt["campaign_id"] = ProportionSpecScript.CAMPAIGN_GQ12
	generator_receipt["proportion_spec"] = proportion_spec.duplicate(true)
	return {
		"proportion_spec": proportion_spec,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
	}


static func _gq12_generation_formula_exact(selection: Array, held_out: Array) -> bool:
	var indices := (
		ProportionSpecScript.GQ12_SELECTION_INDICES + ProportionSpecScript.GQ12_HELD_OUT_INDICES
	)
	var cells := selection + held_out
	var digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var campaign_role := "selection" if cell_index < selection.size() else "heldout"
		var expected := _expected_gq12_generation(generator_index, campaign_role)
		var realized := ProportionSpecScript.compile_gq12_generation(generator_index)
		var digest := String(realized.get("generator_receipt_sha256", ""))
		var verified := ProportionSpecScript.verify_gq12_generation(generator_index, digest)
		if (
			not bool(realized.get("ok", false))
			or int(realized.get("world_build_count", -1)) != 0
			or (realized.get("proportion_spec", {}) as Dictionary) != cells[cell_index]
			or realized.get("proportion_spec", {}) != expected["proportion_spec"]
			or realized.get("generator_receipt", {}) != expected["generator_receipt"]
			or digest != String(expected["generator_receipt_sha256"])
			or not bool(verified.get("ok", false))
			or int(verified.get("world_build_count", -1)) != 0
		):
			return false
		digests[digest] = true
	var old_gq11_request := ProportionSpecScript.compile_gq11_generation(121)
	return (
		digests.size() == indices.size()
		and not bool(old_gq11_request.get("ok", true))
		and (String(old_gq11_request.get("failure_code", "")) == "UNKNOWN_GQ11_GENERATOR_INDEX")
		and int(old_gq11_request.get("world_build_count", -1)) == 0
	)


static func _test_gq12_velocity_gain(
	score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	foot_radius_scale: float,
	yaw_gain: float,
) -> float:
	if yaw_gain > 1.0:
		return (
			0.25
			+ (
				0.05
				* clampf((torso_length_scale - 1.0) / 0.07, 0.0, 1.0)
				* clampf((torso_width_scale - 1.0) / 0.06, 0.0, 1.0)
			)
		)
	if score < 0.15:
		if torso_width_scale <= 1.0:
			return (
				0.275
				+ (
					0.075
					* clampf((torso_length_scale - 1.0) / 0.01, 0.0, 1.0)
					* clampf((1.01 - foot_radius_scale) / 0.01, 0.0, 1.0)
				)
			)
		return 0.35
	if score < 0.5:
		return 0.70 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((score - 0.5) / 0.5, 0.0, 1.0)
	return 0.35


static func _gq12_controller_derivation_and_boundaries_exact(cells: Array) -> bool:
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := _test_morphology_interaction_score(cell)
		var torso_length_scale := float(cell["torso_length_scale"])
		var torso_width_scale := float(cell["torso_width_scale"])
		var foot_radius_scale := float(cell["foot_radius_scale"])
		var hip_span_scale := float(cell["hip_span_scale"])
		var expected_yaw_gain := _test_gq10_yaw_gain(
			score,
			torso_length_scale,
			foot_radius_scale,
			hip_span_scale,
		)
		var expected_path := CampaignScript.GQ12_PATH_STEERING_OPTIONS.duplicate(true)
		expected_path["cross_track_heading_gain_rad_per_m"] = 1.0 if score < 0.5 else 0.75
		expected_path["yaw_error_stride_gain_per_rad"] = expected_yaw_gain
		expected_path["cross_track_velocity_heading_gain_rad_per_m_s"] = (_test_gq12_velocity_gain(
			score,
			torso_length_scale,
			torso_width_scale,
			foot_radius_scale,
			expected_yaw_gain,
		))
		var expected_guard_fraction := 0.80 if score >= 0.5 else 0.90
		var expected_guard_speed := 2.0 if score >= 0.5 else 2.5
		var path_options := CampaignScript._path_steering_options(
			CampaignScript.CAMPAIGN_GQ12, cell
		)
		var motor_options := CampaignScript._motor_velocity_options(
			CampaignScript.CAMPAIGN_GQ12, cell
		)
		var digest := (
			CampaignScript
			. _expected_controller_sha256(
				CampaignScript.CAMPAIGN_GQ12,
				motor_options,
				path_options,
			)
		)
		var metadata_varied := cell.duplicate(true)
		metadata_varied["morphology_id"] = "%s_renamed" % String(cell["morphology_id"])
		metadata_varied["generator_index"] = 999
		metadata_varied["seed"] = 123456
		metadata_varied["campaign_role"] = "heldout"
		metadata_varied["repetition"] = 3
		if (
			path_options != expected_path
			or not is_equal_approx(
				float(motor_options.get("morphology_interaction_score", NAN)),
				score,
			)
			or not is_equal_approx(
				float(motor_options.get("anchor_error_guard_activation_fraction", NAN)),
				expected_guard_fraction,
			)
			or not is_equal_approx(
				float(
					(
						motor_options
						. get(
							"anchor_error_guard_maximum_motor_target_speed_rad_s",
							NAN,
						)
					)
				),
				expected_guard_speed,
			)
			or (
				(
					CampaignScript
					. _path_steering_options(
						CampaignScript.CAMPAIGN_GQ12,
						metadata_varied,
					)
				)
				!= path_options
			)
			or (
				(
					CampaignScript
					. _motor_velocity_options(
						CampaignScript.CAMPAIGN_GQ12,
						metadata_varied,
					)
				)
				!= motor_options
			)
			or not digest.begins_with("sha256:")
			or digest.length() != 71
		):
			return false
		controller_digests[digest] = true
	var valid_path := CampaignScript.GQ12_PATH_STEERING_OPTIONS.duplicate(true)
	var valid_path_result := WaveGaitScript._normalize_path_steering_options(valid_path, 360)
	var nonfinite_path := valid_path.duplicate(true)
	nonfinite_path["cross_track_velocity_heading_gain_rad_per_m_s"] = INF
	var nonfinite_path_result := WaveGaitScript._normalize_path_steering_options(
		nonfinite_path, 360
	)
	var unknown_path := valid_path.duplicate(true)
	unknown_path["runtime_outcome_gain"] = 0.2
	var unknown_path_result := WaveGaitScript._normalize_path_steering_options(unknown_path, 360)
	return (
		controller_digests.size() > 2
		and bool(valid_path_result.get("ok", false))
		and (valid_path_result.get("path_steering_options", {}) as Dictionary) == valid_path
		and not bool(nonfinite_path_result.get("ok", true))
		and int(nonfinite_path_result.get("world_build_count", -1)) == 0
		and not bool(unknown_path_result.get("ok", true))
		and String(unknown_path_result.get("failure_code", "")) == "UNKNOWN_PATH_STEERING_OPTION"
		and int(unknown_path_result.get("world_build_count", -1)) == 0
		and is_equal_approx(CampaignScript._gq12_cross_track_gain_per_m(0.499999), 1.0)
		and is_equal_approx(CampaignScript._gq12_cross_track_gain_per_m(0.5), 0.75)
		and is_equal_approx(
			CampaignScript._gq12_yaw_gain_per_rad(0.9, 1.07, 0.984999, 1.0),
			1.3,
		)
		and is_equal_approx(
			CampaignScript._gq12_yaw_gain_per_rad(0.5, 1.0, 1.025, 1.0),
			1.3,
		)
		and is_equal_approx(
			CampaignScript._gq12_velocity_gain_rad_per_m_s(1.0, 1.0, 1.0, 1.0, 1.1),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq12_velocity_gain_rad_per_m_s(1.0, 1.07, 1.06, 1.0, 1.1),
			0.30,
		)
		and is_equal_approx(
			CampaignScript._gq12_velocity_gain_rad_per_m_s(1.0, 1.035, 1.03, 1.0, 1.1),
			0.2625,
		)
		and is_equal_approx(
			CampaignScript._gq12_velocity_gain_rad_per_m_s(0.149999, 1.0, 1.0, 1.0, 1.0),
			0.275,
		)
		and is_equal_approx(
			CampaignScript._gq12_velocity_gain_rad_per_m_s(0.149999, 1.01, 1.0, 1.0, 1.0),
			0.35,
		)
		and is_equal_approx(
			(
				CampaignScript
				. _gq12_velocity_gain_rad_per_m_s(
					0.149999,
					1.005,
					1.0,
					1.005,
					1.0,
				)
			),
			0.29375,
		)
		and is_equal_approx(
			CampaignScript._gq12_velocity_gain_rad_per_m_s(0.15, 1.0, 1.0, 1.0, 1.0),
			0.70,
		)
		and is_equal_approx(
			CampaignScript._gq12_velocity_gain_rad_per_m_s(0.15, 1.0, 1.000001, 1.0, 1.0),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq12_velocity_gain_rad_per_m_s(1.0, 0.999999, 1.000001, 1.0, 1.0),
			0.20,
		)
		and CampaignScript._gq12_motor_guard_values(0.499999) == [0.90, 2.5]
		and CampaignScript._gq12_motor_guard_values(0.5) == [0.80, 2.0]
	)


static func _gq12_clock_solver_and_thresholds_exact(compiled_cells: Array) -> bool:
	if compiled_cells.is_empty():
		return false
	var clock := ClockSpecScript.gq12_clock()
	var clock_result := ClockSpecScript.compile(clock)
	var bad_clock := clock.duplicate(true)
	bad_clock["evidence_cycles"] = 3
	var bad_clock_result := ClockSpecScript.compile(bad_clock)
	var solver_result := WaveGaitScript.compile_solver_policy_options(
		CampaignScript.GP4_SOLVER_POLICY_OPTIONS
	)
	var fixture: Dictionary = (compiled_cells[0] as Dictionary)["fixture_spec"]
	var torso_size: Array = (fixture["torso"] as Dictionary)["size_m"]
	var first_limb: Dictionary = (fixture["limbs"] as Array)[0]
	var thresholds := CampaignScript._evidence_thresholds(fixture, CampaignScript.CAMPAIGN_GQ12)
	var threshold_result := WaveGaitScript.compile_evidence_threshold_options(thresholds)
	var unknown_threshold := thresholds.duplicate(true)
	unknown_threshold["relax_after_failure"] = true
	var unknown_threshold_result := WaveGaitScript.compile_evidence_threshold_options(
		unknown_threshold
	)
	return (
		bool(clock_result.get("ok", false))
		and int(clock_result.get("world_build_count", -1)) == 0
		and (clock_result.get("gait_clock_options", {}) as Dictionary) == clock
		and String(clock.get("policy_id", "")) == ClockSpecScript.GQ12_POLICY_ID
		and ClockSpecScript.GQ12_POLICY_ID != ClockSpecScript.GQ11_POLICY_ID
		and int(clock.get("cycle_ticks", -1)) == 360
		and int(clock.get("evidence_cycles", -1)) == 4
		and int(clock.get("maximum_contact_gate_hold_ticks", -1)) == 120
		and int(clock.get("maximum_contact_gated_evidence_extension_ticks", -1)) == 720
		and int(clock.get("maximum_contact_gated_phase_skew_ticks", -1)) == 12
		and not bool(bad_clock_result.get("ok", true))
		and int(bad_clock_result.get("world_build_count", -1)) == 0
		and bool(solver_result.get("ok", false))
		and int(solver_result.get("world_build_count", -1)) == 0
		and (
			(solver_result.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_velocity_steps"]) == 20
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_position_steps"]) == 7
		and bool(threshold_result.get("ok", false))
		and int(threshold_result.get("world_build_count", -1)) == 0
		and (threshold_result.get("evidence_threshold_options", {}) as Dictionary) == thresholds
		and is_equal_approx(
			float(thresholds.get("minimum_foot_relocation_m", NAN)),
			0.0238 * float(torso_size[0]),
		)
		and is_equal_approx(
			float(thresholds.get("maximum_anchor_error_m", NAN)),
			0.14 * float(first_limb["upper_length_m"]),
		)
		and not bool(unknown_threshold_result.get("ok", true))
		and int(unknown_threshold_result.get("world_build_count", -1)) == 0
	)


static func _gq12_policy_preservation_and_fail_closed_exact(
	selection: Array,
	held_out: Array,
) -> bool:
	var prior_digests := [
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ1)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ2)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ3)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ4)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ5)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ6)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ7)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ8)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ9)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ10)),
		CanonicalJsonScript.sha256(CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ11)),
	]
	var expected_prior_digests := [
		"sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698",
		"sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463",
		"sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253",
		"sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38",
		"sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb",
		"sha256:1c099d6c3179323c9e2dbdf20adcfd1cb91e11221fd0d2a49f349acec512a85f",
		"sha256:32c68e0d0f1c4ecb54499793a2f090e7bee37846f6babf27f563bd5afb5c0346",
		"sha256:c39d147f61057cb4b96e745b5aa7258bbfbcbfedaab4116a93b518f2b46348a0",
		"sha256:3410448ca5b7b35e06310abcc794ca0acaeaa3d559de37a19ef9e666c80d1c74",
		"sha256:f487f4da8976a2295d6369057f21b60a2fe2688e78ccbeb4c80043d73b770fad",
		"sha256:2cc535c9c6e8064c5c4653d9b67b959c75ec9520c0eb98fcb59d33813562936f",
	]
	var policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ12)
	var policy_digest := CanonicalJsonScript.sha256(policy)
	var first_generation := ProportionSpecScript.compile_gq12_generation(121)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var tampered_digest := first_digest.left(70) + ("0" if first_digest.right(1) != "0" else "1")
	var wrong_type := ProportionSpecScript.compile_gq12_generation(121.0)
	var unknown_index := ProportionSpecScript.compile_gq12_generation(109)
	var tampered := ProportionSpecScript.verify_gq12_generation(121, tampered_digest)
	var invalid_role := ProportionSpecScript.gq12_generation_for_morphology(
		"gq12_generated_s121", "invalid"
	)
	var wrong_role := ProportionSpecScript.gq12_generation_for_morphology(
		"gq12_generated_s121", "heldout"
	)
	var unknown_morphology := ProportionSpecScript.gq12_generation_for_morphology(
		"gq12_generated_s999", "selection"
	)
	return (
		prior_digests == expected_prior_digests
		and (
			String(policy.get("schema_version", ""))
			== "sporespore_g4_gq12_dual_geometry_velocity_feedback_policy_v1"
		)
		and String(policy.get("campaign_id", "")) == CampaignScript.CAMPAIGN_GQ12
		and (policy.get("selection_cells", []) as Array) == selection
		and (policy.get("held_out_cells", []) as Array) == held_out
		and (
			String(policy.get("generator_policy_id", ""))
			== ProportionSpecScript.GQ12_GENERATOR_POLICY_ID
		)
		and (
			String(policy.get("generator_schema_version", ""))
			== ProportionSpecScript.GQ12_GENERATOR_SCHEMA_VERSION
		)
		and (
			(policy.get("selection_generator_indices", []) as Array)
			== ProportionSpecScript.GQ12_SELECTION_INDICES
		)
		and (
			(policy.get("held_out_generator_indices", []) as Array)
			== ProportionSpecScript.GQ12_HELD_OUT_INDICES
		)
		and (policy.get("generator_receipts", []) as Array).size() == 20
		and String(policy.get("clock_policy_id", "")) == ClockSpecScript.GQ12_POLICY_ID
		and (policy.get("clock_options", {}) as Dictionary) == ClockSpecScript.gq12_clock()
		and (
			(policy.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and (
			(policy.get("robustness_options", {}) as Dictionary)
			== CampaignScript.GQ12_ROBUSTNESS_OPTIONS
		)
		and (
			String(policy.get("path_velocity_gain_derivation_id", ""))
			== "dual_smooth_long_small_foot_and_long_wide_v7"
		)
		and (
			String(policy.get("path_velocity_gain_formula", ""))
			== (
				"0.25+0.05*clamp((L-1)/0.07,0,1)*clamp((W-1)/0.06,0,1) "
				+ "if Y>1 else (0.275+0.075*clamp((L-1)/0.01,0,1)"
				+ "*clamp((1.01-F)/0.01,0,1) if S<0.15 and W<=1 else "
				+ "(0.35 if S<0.15 else (0.70 if S<0.5 and W<=1 else "
				+ "(0.25 if S<0.5 else "
				+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else 0.35)))))"
			)
		)
		and not policy.has("controller_sha256")
		and policy_digest.begins_with("sha256:")
		and policy_digest.length() == 71
		and policy_digest not in prior_digests
		and not bool(wrong_type.get("ok", true))
		and String(wrong_type.get("failure_code", "")) == "INVALID_GQ12_GENERATOR_INDEX_TYPE"
		and int(wrong_type.get("world_build_count", -1)) == 0
		and not bool(unknown_index.get("ok", true))
		and String(unknown_index.get("failure_code", "")) == "UNKNOWN_GQ12_GENERATOR_INDEX"
		and int(unknown_index.get("world_build_count", -1)) == 0
		and not bool(tampered.get("ok", true))
		and String(tampered.get("failure_code", "")) == "GQ12_GENERATOR_RECEIPT_DIGEST_MISMATCH"
		and int(tampered.get("world_build_count", -1)) == 0
		and not bool(invalid_role.get("ok", true))
		and String(invalid_role.get("failure_code", "")) == "INVALID_GQ12_CAMPAIGN_ROLE"
		and int(invalid_role.get("world_build_count", -1)) == 0
		and not bool(wrong_role.get("ok", true))
		and String(wrong_role.get("failure_code", "")) == "UNKNOWN_GQ12_MORPHOLOGY"
		and int(wrong_role.get("world_build_count", -1)) == 0
		and not bool(unknown_morphology.get("ok", true))
		and String(unknown_morphology.get("failure_code", "")) == "UNKNOWN_GQ12_MORPHOLOGY"
		and int(unknown_morphology.get("world_build_count", -1)) == 0
	)


static func _expected_gq13_generation(generator_index: int, campaign_role: String) -> Dictionary:
	var predecessor := _expected_gq12_generation(generator_index, campaign_role)
	var proportion_spec: Dictionary = (predecessor["proportion_spec"] as Dictionary).duplicate(true)
	proportion_spec["morphology_id"] = "gq13_generated_s%03d" % generator_index
	var generator_receipt: Dictionary = (predecessor["generator_receipt"] as Dictionary).duplicate(
		true
	)
	generator_receipt["schema_version"] = ProportionSpecScript.GQ13_GENERATOR_SCHEMA_VERSION
	generator_receipt["generator_policy_id"] = ProportionSpecScript.GQ13_GENERATOR_POLICY_ID
	generator_receipt["campaign_id"] = ProportionSpecScript.CAMPAIGN_GQ13
	generator_receipt["proportion_spec"] = proportion_spec.duplicate(true)
	return {
		"proportion_spec": proportion_spec,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
	}


static func _gq13_generator_contract(selection: Array, held_out: Array) -> Dictionary:
	var expected_selection: Array = []
	for generator_index in range(133, 145):
		expected_selection.append("gq13_generated_s%03d" % generator_index)
	var expected_held_out: Array = []
	for generator_index in range(1201, 1209):
		expected_held_out.append("gq13_generated_s%03d" % generator_index)
	var realized_selection: Array = []
	var realized_held_out: Array = []
	for cell_value in selection:
		realized_selection.append(String((cell_value as Dictionary).get("morphology_id", "")))
	for cell_value in held_out:
		realized_held_out.append(String((cell_value as Dictionary).get("morphology_id", "")))
	var selection_ids_exact := (
		selection.size() == 12
		and realized_selection == expected_selection
		and (
			ProportionSpecScript.GQ13_SELECTION_INDICES
			== [133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144]
		)
	)
	var heldout_ids_exact := (
		held_out.size() == 8
		and realized_held_out == expected_held_out
		and (
			ProportionSpecScript.GQ13_HELD_OUT_INDICES
			== [1201, 1202, 1203, 1204, 1205, 1206, 1207, 1208]
		)
	)
	var reverse_lookup_exact := selection_ids_exact and heldout_ids_exact
	if reverse_lookup_exact:
		for cell_value in selection:
			var cell: Dictionary = cell_value
			reverse_lookup_exact = (
				reverse_lookup_exact
				and (
					ProportionSpecScript.gq13_generation_for_morphology(
						String(cell["morphology_id"]),
						"selection",
					).get("proportion_spec", {})
					== cell
				)
				and (
					ProportionSpecScript.gq13_generation_for_morphology(
						String(cell["morphology_id"]),
						"heldout",
					).get("ok", true)
					== false
				)
			)
		for cell_value in held_out:
			var cell: Dictionary = cell_value
			reverse_lookup_exact = (
				reverse_lookup_exact
				and (
					ProportionSpecScript.gq13_generation_for_morphology(
						String(cell["morphology_id"]),
						"heldout",
					).get("proportion_spec", {})
					== cell
				)
				and (
					ProportionSpecScript.gq13_generation_for_morphology(
						String(cell["morphology_id"]),
						"selection",
					).get("ok", true)
					== false
				)
			)
	var indices: Array = (
		ProportionSpecScript.GQ13_SELECTION_INDICES
		+ ProportionSpecScript.GQ13_HELD_OUT_INDICES
	)
	var cells := selection + held_out
	var all_generation_ok := cells.size() == 20
	var generation_formula_exact := all_generation_ok
	var generator_verify_exact := all_generation_ok
	var digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var role := "selection" if cell_index < selection.size() else "heldout"
		var expected := _expected_gq13_generation(generator_index, role)
		var realized := ProportionSpecScript.compile_gq13_generation(generator_index)
		var digest := String(realized.get("generator_receipt_sha256", ""))
		var verified := ProportionSpecScript.verify_gq13_generation(generator_index, digest)
		all_generation_ok = (
			all_generation_ok
			and bool(realized.get("ok", false))
			and int(realized.get("world_build_count", -1)) == 0
		)
		generation_formula_exact = (
			generation_formula_exact
			and realized.get("proportion_spec", {}) == cells[cell_index]
			and realized.get("proportion_spec", {}) == expected["proportion_spec"]
			and realized.get("generator_receipt", {}) == expected["generator_receipt"]
			and digest == String(expected["generator_receipt_sha256"])
		)
		generator_verify_exact = (
			generator_verify_exact
			and bool(verified.get("ok", false))
			and int(verified.get("world_build_count", -1)) == 0
		)
		digests[digest] = true
	var first_generation := ProportionSpecScript.compile_gq13_generation(133)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var tampered_digest := first_digest.left(70) + ("0" if first_digest.right(1) != "0" else "1")
	var wrong_type := ProportionSpecScript.compile_gq13_generation(133.0)
	var unknown_index := ProportionSpecScript.compile_gq13_generation(132)
	var tampered := ProportionSpecScript.verify_gq13_generation(133, tampered_digest)
	var invalid_role := ProportionSpecScript.gq13_generation_for_morphology(
		"gq13_generated_s133",
		"invalid",
	)
	var wrong_identity := ProportionSpecScript.gq13_generation_for_morphology(
		"gq12_generated_s133",
		"selection",
	)
	var old_campaign_request := ProportionSpecScript.compile_gq12_generation(133)
	var generator_fail_closed := (
		not bool(wrong_type.get("ok", true))
		and String(wrong_type.get("failure_code", "")) == "INVALID_GQ13_GENERATOR_INDEX_TYPE"
		and int(wrong_type.get("world_build_count", -1)) == 0
		and not bool(unknown_index.get("ok", true))
		and String(unknown_index.get("failure_code", "")) == "UNKNOWN_GQ13_GENERATOR_INDEX"
		and int(unknown_index.get("world_build_count", -1)) == 0
		and not bool(tampered.get("ok", true))
		and (
			String(tampered.get("failure_code", ""))
			== "GQ13_GENERATOR_RECEIPT_DIGEST_MISMATCH"
		)
		and int(tampered.get("world_build_count", -1)) == 0
		and not bool(invalid_role.get("ok", true))
		and String(invalid_role.get("failure_code", "")) == "INVALID_GQ13_CAMPAIGN_ROLE"
		and int(invalid_role.get("world_build_count", -1)) == 0
		and not bool(wrong_identity.get("ok", true))
		and String(wrong_identity.get("failure_code", "")) == "UNKNOWN_GQ13_MORPHOLOGY"
		and int(wrong_identity.get("world_build_count", -1)) == 0
		and not bool(old_campaign_request.get("ok", true))
		and int(old_campaign_request.get("world_build_count", -1)) == 0
	)
	return {
		"selection_ids_exact": selection_ids_exact,
		"heldout_ids_exact": heldout_ids_exact,
		"reverse_lookup_exact": reverse_lookup_exact,
		"all_generation_ok": all_generation_ok,
		"generation_formula_exact": generation_formula_exact,
		"generation_receipts_distinct": digests.size() == 20 and not digests.has(""),
		"generator_verify_exact": generator_verify_exact,
		"generator_fail_closed": generator_fail_closed,
	}


static func _test_gq13_velocity_gain(
	score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	foot_radius_scale: float,
	yaw_gain: float,
) -> float:
	if yaw_gain > 1.0:
		return (
			0.25
			+ 0.05
			* clampf((torso_length_scale - 1.0) / 0.07, 0.0, 1.0)
			* clampf((torso_width_scale - 1.0) / 0.06, 0.0, 1.0)
		)
	if score < 0.15:
		if torso_width_scale <= 1.0:
			return (
				0.275
				+ 0.075
				* clampf((torso_length_scale - 1.0) / 0.01, 0.0, 1.0)
				* clampf((1.01 - foot_radius_scale) / 0.01, 0.0, 1.0)
			)
		return 0.35
	if score < 0.5:
		return 0.75 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((score - 0.5) / 0.5, 0.0, 1.0)
	return 0.35


static func _gq13_controller_contract(cells: Array) -> Dictionary:
	var all_cells_exact := cells.size() == 20
	var metadata_independence_exact := all_cells_exact
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := _test_morphology_interaction_score(cell)
		var length_scale := float(cell["torso_length_scale"])
		var width_scale := float(cell["torso_width_scale"])
		var foot_scale := float(cell["foot_radius_scale"])
		var hip_scale := float(cell["hip_span_scale"])
		var yaw_gain := _test_gq10_yaw_gain(
			score,
			length_scale,
			foot_scale,
			hip_scale,
		)
		var expected_path := CampaignScript.GQ13_PATH_STEERING_OPTIONS.duplicate(true)
		expected_path["cross_track_heading_gain_rad_per_m"] = 1.0 if score < 0.5 else 0.75
		expected_path["yaw_error_stride_gain_per_rad"] = yaw_gain
		expected_path["cross_track_velocity_heading_gain_rad_per_m_s"] = (
			_test_gq13_velocity_gain(
				score,
				length_scale,
				width_scale,
				foot_scale,
				yaw_gain,
			)
		)
		var path_options := CampaignScript._path_steering_options(
			CampaignScript.CAMPAIGN_GQ13,
			cell,
		)
		var motor_options := CampaignScript._motor_velocity_options(
			CampaignScript.CAMPAIGN_GQ13,
			cell,
		)
		var expected_guard := [0.80, 2.0] if score >= 0.5 else [0.90, 2.5]
		var digest := CampaignScript._expected_controller_sha256(
			CampaignScript.CAMPAIGN_GQ13,
			motor_options,
			path_options,
		)
		all_cells_exact = (
			all_cells_exact
			and path_options == expected_path
			and is_equal_approx(
				float(motor_options.get("morphology_interaction_score", NAN)),
				score,
			)
			and is_equal_approx(
				float(motor_options.get("anchor_error_guard_activation_fraction", NAN)),
				float(expected_guard[0]),
			)
			and is_equal_approx(
				float(
					motor_options.get(
						"anchor_error_guard_maximum_motor_target_speed_rad_s",
						NAN,
					)
				),
				float(expected_guard[1]),
			)
			and digest.begins_with("sha256:")
			and digest.length() == 71
		)
		var varied := cell.duplicate(true)
		varied["morphology_id"] = "outcome_named_failure"
		varied["generator_index"] = 999999
		varied["campaign_role"] = "heldout"
		varied["repetition"] = 3
		varied["seed"] = 123456
		varied["coverage_status"] = "OUT_OF_DISTRIBUTION"
		varied["support_margin_m"] = -999.0
		varied["observed_outcome"] = false
		metadata_independence_exact = (
			metadata_independence_exact
			and (
				CampaignScript._path_steering_options(
					CampaignScript.CAMPAIGN_GQ13,
					varied,
				)
				== path_options
			)
			and (
				CampaignScript._motor_velocity_options(
					CampaignScript.CAMPAIGN_GQ13,
					varied,
				)
				== motor_options
			)
		)
		controller_digests[digest] = true
	var actual := Callable(CampaignScript, "_gq13_velocity_gain_rad_per_m_s")
	return {
		"all_cells_exact": all_cells_exact,
		"yaw_precedence_exact":
		is_equal_approx(actual.call(0.0, 1.07, 1.06, 0.90, 1.000001), 0.30)
		and is_equal_approx(actual.call(0.8, 1.035, 1.03, 1.10, 1.000001), 0.2625),
		"long_wide_smooth_exact":
		is_equal_approx(actual.call(1.0, 1.0, 1.06, 1.0, 1.1), 0.25)
		and is_equal_approx(actual.call(1.0, 1.035, 1.03, 1.0, 1.1), 0.2625)
		and is_equal_approx(actual.call(1.0, 1.07, 1.06, 1.0, 1.1), 0.30)
		and is_equal_approx(actual.call(1.0, 1.08, 1.08, 1.0, 1.1), 0.30),
		"long_small_foot_smooth_exact":
		is_equal_approx(actual.call(0.149999, 1.0, 1.0, 1.0, 1.0), 0.275)
		and is_equal_approx(actual.call(0.149999, 1.005, 1.0, 1.005, 1.0), 0.29375)
		and is_equal_approx(actual.call(0.149999, 1.01, 1.0, 1.0, 1.0), 0.35)
		and is_equal_approx(actual.call(0.149999, 1.02, 1.0, 0.90, 1.0), 0.35),
		"score_015_boundary_exact":
		is_equal_approx(actual.call(0.149999, 1.0, 1.0, 1.0, 1.0), 0.275)
		and is_equal_approx(actual.call(0.15, 1.0, 1.0, 1.0, 1.0), 0.75)
		and is_equal_approx(actual.call(0.15, 1.0, 1.000001, 1.0, 1.0), 0.25),
		"score_05_boundary_exact":
		is_equal_approx(actual.call(0.499999, 1.0, 1.0, 1.0, 1.0), 0.75)
		and is_equal_approx(actual.call(0.5, 1.0, 1.0, 1.0, 1.0), 0.35),
		"width_boundary_exact":
		is_equal_approx(actual.call(0.2, 1.0, 1.0, 1.0, 1.0), 0.75)
		and is_equal_approx(actual.call(0.2, 1.0, 1.000001, 1.0, 1.0), 0.25),
		"length_boundary_exact":
		is_equal_approx(actual.call(1.0, 1.0, 1.000001, 1.0, 1.0), 0.35)
		and is_equal_approx(actual.call(1.0, 0.999999, 1.000001, 1.0, 1.0), 0.20),
		"foot_boundary_exact":
		is_equal_approx(actual.call(0.149999, 1.01, 1.0, 1.01, 1.0), 0.275)
		and actual.call(0.149999, 1.01, 1.0, 1.009999, 1.0) > 0.275,
		"motor_guard_exact":
		CampaignScript._gq13_motor_guard_values(0.499999) == [0.90, 2.5]
		and CampaignScript._gq13_motor_guard_values(0.5) == [0.80, 2.0],
		"metadata_independence_exact": metadata_independence_exact,
		"controller_digests_distinct":
		controller_digests.size() > 2 and not controller_digests.has(""),
	}


static func _gq13_numerical_contract(compiled_cells: Array) -> Dictionary:
	if compiled_cells.is_empty():
		return {}
	var clock := ClockSpecScript.gq13_clock()
	var clock_result := ClockSpecScript.compile(clock)
	var bad_clock := clock.duplicate(true)
	bad_clock["evidence_cycles"] = 3
	var bad_clock_result := ClockSpecScript.compile(bad_clock)
	var solver_result := WaveGaitScript.compile_solver_policy_options(
		CampaignScript.GP4_SOLVER_POLICY_OPTIONS
	)
	var solver_exact := (
		bool(solver_result.get("ok", false))
		and int(solver_result.get("world_build_count", -1)) == 0
		and (
			(solver_result.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_velocity_steps"]) == 20
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_position_steps"]) == 7
	)
	var thresholds_exact := true
	for compiled_value in compiled_cells:
		var compiled: Dictionary = compiled_value
		var fixture: Dictionary = compiled["fixture_spec"]
		var torso_size: Array = (fixture["torso"] as Dictionary)["size_m"]
		var first_limb: Dictionary = (fixture["limbs"] as Array)[0]
		var thresholds := CampaignScript._evidence_thresholds(
			fixture,
			CampaignScript.CAMPAIGN_GQ13,
		)
		var result := WaveGaitScript.compile_evidence_threshold_options(thresholds)
		thresholds_exact = (
			thresholds_exact
			and bool(result.get("ok", false))
			and int(result.get("world_build_count", -1)) == 0
			and (result.get("evidence_threshold_options", {}) as Dictionary) == thresholds
			and is_equal_approx(
				float(thresholds["minimum_foot_relocation_m"]),
				0.0238 * float(torso_size[0]),
			)
			and is_equal_approx(
				float(thresholds["maximum_anchor_error_m"]),
				0.14 * float(first_limb["upper_length_m"]),
			)
			and is_equal_approx(
				float(thresholds["maximum_lateral_drift_m"]),
				0.3125 * float(torso_size[2]),
			)
		)
	return {
		"clock_identity_exact":
		bool(clock_result.get("ok", false))
		and int(clock_result.get("world_build_count", -1)) == 0
		and (clock_result.get("gait_clock_options", {}) as Dictionary) == clock
		and String(clock.get("policy_id", "")) == ClockSpecScript.GQ13_POLICY_ID
		and ClockSpecScript.GQ13_POLICY_ID != ClockSpecScript.GQ12_POLICY_ID
		and not bool(bad_clock_result.get("ok", true))
		and int(bad_clock_result.get("world_build_count", -1)) == 0,
		"clock_timing_exact":
		int(clock.get("physics_hz", -1)) == 120
		and int(clock.get("cycle_ticks", -1)) == 360
		and int(clock.get("swing_ticks", -1)) == 72
		and int(clock.get("evidence_cycles", -1)) == 4
		and int(clock.get("settle_ticks", -1)) == 240
		and int(clock.get("terminal_settle_ticks", -1)) == 240
		and int(clock.get("maximum_contact_gate_hold_ticks", -1)) == 120
		and int(clock.get("maximum_contact_gated_evidence_extension_ticks", -1)) == 720
		and int(clock.get("maximum_contact_gated_phase_skew_ticks", -1)) == 12
		and int(clock.get("steering_update_interval_ticks", -1)) == 90,
		"solver_exact": solver_exact,
		"thresholds_exact": thresholds_exact,
	}


static func _gq13_policy_contract(selection: Array, held_out: Array) -> Dictionary:
	var campaigns := [
		CampaignScript.CAMPAIGN_GQ1,
		CampaignScript.CAMPAIGN_GQ2,
		CampaignScript.CAMPAIGN_GQ3,
		CampaignScript.CAMPAIGN_GQ4,
		CampaignScript.CAMPAIGN_GQ5,
		CampaignScript.CAMPAIGN_GQ6,
		CampaignScript.CAMPAIGN_GQ7,
		CampaignScript.CAMPAIGN_GQ8,
		CampaignScript.CAMPAIGN_GQ9,
		CampaignScript.CAMPAIGN_GQ10,
		CampaignScript.CAMPAIGN_GQ11,
		CampaignScript.CAMPAIGN_GQ12,
	]
	var expected_legacy_digests := [
		"sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698",
		"sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463",
		"sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253",
		"sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38",
		"sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb",
		"sha256:1c099d6c3179323c9e2dbdf20adcfd1cb91e11221fd0d2a49f349acec512a85f",
		"sha256:32c68e0d0f1c4ecb54499793a2f090e7bee37846f6babf27f563bd5afb5c0346",
		"sha256:c39d147f61057cb4b96e745b5aa7258bbfbcbfedaab4116a93b518f2b46348a0",
		"sha256:3410448ca5b7b35e06310abcc794ca0acaeaa3d559de37a19ef9e666c80d1c74",
		"sha256:f487f4da8976a2295d6369057f21b60a2fe2688e78ccbeb4c80043d73b770fad",
		"sha256:2cc535c9c6e8064c5c4653d9b67b959c75ec9520c0eb98fcb59d33813562936f",
		"sha256:1f6ab51904ae76f5c634a7d781cc3673c49f8d6708e59d743a4d4ff95b47c62f",
	]
	var legacy_digests: Array = []
	for campaign_id_value in campaigns:
		legacy_digests.append(
			CanonicalJsonScript.sha256(CampaignScript._formula_policy(String(campaign_id_value)))
		)
	var policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ13)
	var policy_digest := CanonicalJsonScript.sha256(policy)
	var identities_exact := (
		String(policy.get("schema_version", ""))
		== "sporespore_g4_gq13_candidate33_diagnostic_receipts_policy_v1"
		and String(policy.get("campaign_id", "")) == CampaignScript.CAMPAIGN_GQ13
		and (policy.get("selection_cells", []) as Array) == selection
		and (policy.get("held_out_cells", []) as Array) == held_out
		and (
			String(policy.get("generator_policy_id", ""))
			== ProportionSpecScript.GQ13_GENERATOR_POLICY_ID
		)
		and (
			String(policy.get("generator_schema_version", ""))
			== ProportionSpecScript.GQ13_GENERATOR_SCHEMA_VERSION
		)
		and (
			String(policy.get("path_velocity_gain_derivation_id", ""))
			== "dual_smooth_long_small_foot_long_wide_mid_narrow_075_v8"
		)
		and String(policy.get("clock_policy_id", "")) == ClockSpecScript.GQ13_POLICY_ID
		and String(policy.get("feature_schema_version", "")) == FeatureReceiptScript.SCHEMA_VERSION
		and String(policy.get("feature_policy_id", "")) == FeatureReceiptScript.POLICY_ID
		and (
			String(policy.get("coverage_schema_version", ""))
			== CoverageReceiptScript.SCHEMA_VERSION
		)
		and String(policy.get("coverage_policy_id", "")) == CoverageReceiptScript.POLICY_ID
		and (
			String(policy.get("dynamic_support_schema_version", ""))
			== DynamicSupportReceiptScript.SCHEMA_VERSION
		)
		and (
			String(policy.get("dynamic_support_policy_id", ""))
			== DynamicSupportReceiptScript.POLICY_ID
		)
		and (
			String(policy.get("report_schema_version", ""))
			== "sporespore_br14a_nonuniform_proportion_probe_report_v18"
		)
		and policy_digest.begins_with("sha256:")
		and policy_digest.length() == 71
		and policy_digest not in legacy_digests
	)
	var formula_text := String(policy.get("path_velocity_gain_formula", ""))
	var fail_closed_exact := (
		not policy.has("controller_sha256")
		and formula_text.contains("0.75 if S<0.5 and W<=1")
		and not formula_text.contains("coverage")
		and not formula_text.contains("support")
		and not bool(policy.get("formal_milestone_acceptance_authorized", true))
		and not bool(policy.get("encyclopedia_admission_authorized", true))
		and not bool(policy.get("automatic_creature_guidance_allowed", true))
	)
	return {
		"identities_exact": identities_exact,
		"legacy_digests_exact": legacy_digests == expected_legacy_digests,
		"fail_closed_exact": fail_closed_exact,
	}


static func _gq13_build_cohort_feature_results() -> Array:
	var clock_result := ClockSpecScript.compile(ClockSpecScript.gq11_clock())
	var solver_result := WaveGaitScript.compile_solver_policy_options(
		CampaignScript.GP4_SOLVER_POLICY_OPTIONS
	)
	if not bool(clock_result.get("ok", false)) or not bool(solver_result.get("ok", false)):
		return []
	var clock: Dictionary = clock_result["gait_clock_options"]
	var solver: Dictionary = solver_result["solver_policy_options"]
	var results: Array = []
	var indices: Array = (
		ProportionSpecScript.GQ11_SELECTION_INDICES
		+ ProportionSpecScript.GQ11_HELD_OUT_INDICES
	)
	for generator_index_value in indices:
		var generation := ProportionSpecScript.compile_gq11_generation(int(generator_index_value))
		if not bool(generation.get("ok", false)):
			return []
		var declared: Dictionary = generation["proportion_spec"]
		var compiled := ProportionSpecScript.compile(declared)
		var controller_digest := CampaignScript._candidate33_controller_sha256(
			declared,
			clock,
			CampaignScript.GQ11_ROBUSTNESS_OPTIONS,
		)
		var feature := FeatureReceiptScript.compile(
			generation,
			compiled,
			controller_digest,
			clock,
			solver,
		)
		if not bool(feature.get("ok", false)):
			return []
		results.append(feature)
	return results


static func _gq13_query_feature_results(
	cells: Array,
	compiled_cells: Array,
) -> Array:
	if cells.size() != compiled_cells.size():
		return []
	var clock_result := ClockSpecScript.compile(ClockSpecScript.gq13_clock())
	var solver_result := WaveGaitScript.compile_solver_policy_options(
		CampaignScript.GP4_SOLVER_POLICY_OPTIONS
	)
	if not bool(clock_result.get("ok", false)) or not bool(solver_result.get("ok", false)):
		return []
	var clock: Dictionary = clock_result["gait_clock_options"]
	var solver: Dictionary = solver_result["solver_policy_options"]
	var indices: Array = (
		ProportionSpecScript.GQ13_SELECTION_INDICES
		+ ProportionSpecScript.GQ13_HELD_OUT_INDICES
	)
	var results: Array = []
	for cell_index in range(cells.size()):
		var cell: Dictionary = cells[cell_index]
		var generation := ProportionSpecScript.compile_gq13_generation(int(indices[cell_index]))
		var path := CampaignScript._path_steering_options(
			CampaignScript.CAMPAIGN_GQ13,
			cell,
		)
		var motor := CampaignScript._motor_velocity_options(
			CampaignScript.CAMPAIGN_GQ13,
			cell,
		)
		var controller_digest := CampaignScript._expected_controller_sha256(
			CampaignScript.CAMPAIGN_GQ13,
			motor,
			path,
		)
		var feature := FeatureReceiptScript.compile(
			generation,
			compiled_cells[cell_index],
			controller_digest,
			clock,
			solver,
		)
		if not bool(feature.get("ok", false)):
			return []
		results.append(feature)
	return results


static func _arrays_approximately_equal(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if not is_equal_approx(float(left[index]), float(right[index])):
			return false
	return true


static func _standardized_vector(vector: Array, means: Array, deviations: Array) -> Array:
	var result: Array = []
	for axis_index in range(vector.size()):
		result.append(
			(float(vector[axis_index]) - float(means[axis_index]))
			/ float(deviations[axis_index])
		)
	return result


static func _vector_distance(left: Array, right: Array) -> float:
	var squared := 0.0
	for axis_index in range(left.size()):
		var delta := float(left[axis_index]) - float(right[axis_index])
		squared += delta * delta
	return sqrt(squared)


static func _coverage_math_exact(
	coverage_result: Dictionary,
	cohort_features: Array,
	query_feature: Dictionary,
) -> bool:
	var receipt: Dictionary = coverage_result.get("coverage_receipt", {})
	var ordered_cohort_ids: Array = receipt.get("ordered_cohort_member_ids", [])
	if (
		not bool(coverage_result.get("ok", false))
		or cohort_features.size() < 2
		or cohort_features.size() != ordered_cohort_ids.size()
		or not bool(query_feature.get("ok", false))
	):
		return false
	var raw_vectors: Array = []
	for feature_value in cohort_features:
		var feature: Dictionary = feature_value
		var feature_receipt: Dictionary = feature["feature_receipt"]
		raw_vectors.append(
			(feature_receipt["ordered_signed_centered_coordinates_dimensionless"] as Array)
			. duplicate()
		)
	var means: Array = []
	var deviations: Array = []
	for axis_index in range(FeatureReceiptScript.AXIS_ORDER.size()):
		var mean := 0.0
		for vector_value in raw_vectors:
			mean += float((vector_value as Array)[axis_index])
		mean /= float(raw_vectors.size())
		var variance := 0.0
		for vector_value in raw_vectors:
			var centered := float((vector_value as Array)[axis_index]) - mean
			variance += centered * centered
		variance /= float(raw_vectors.size())
		means.append(mean)
		deviations.append(sqrt(variance))
	var standardized_cohort: Array = []
	for vector_value in raw_vectors:
		standardized_cohort.append(
			_standardized_vector(vector_value, means, deviations)
		)
	var leave_one_out: Array = []
	var supported_threshold := 0.0
	for left_index in range(standardized_cohort.size()):
		var nearest := INF
		for right_index in range(standardized_cohort.size()):
			if left_index == right_index:
				continue
			nearest = minf(
				nearest,
				_vector_distance(
					standardized_cohort[left_index],
					standardized_cohort[right_index],
				),
			)
		leave_one_out.append(nearest)
		supported_threshold = maxf(supported_threshold, nearest)
	var query_receipt: Dictionary = query_feature["feature_receipt"]
	var query_raw: Array = query_receipt[
		"ordered_signed_centered_coordinates_dimensionless"
	]
	var query_standardized := _standardized_vector(query_raw, means, deviations)
	var nearest_query := INF
	var nearest_id := ""
	for cohort_index in range(standardized_cohort.size()):
		var distance := _vector_distance(
			query_standardized,
			standardized_cohort[cohort_index],
		)
		if distance < nearest_query:
			nearest_query = distance
			nearest_id = String(ordered_cohort_ids[cohort_index])
	return (
		_arrays_approximately_equal(
			receipt.get("population_mean_dimensionless", []),
			means,
		)
		and _arrays_approximately_equal(
			receipt.get("population_standard_deviation_dimensionless", []),
			deviations,
		)
		and _arrays_approximately_equal(
			receipt.get("leave_one_out_nearest_distances_dimensionless", []),
			leave_one_out,
		)
		and is_equal_approx(
			float(receipt.get("supported_threshold_dimensionless", NAN)),
			supported_threshold,
		)
		and is_equal_approx(
			float(receipt.get("edge_threshold_dimensionless", NAN)),
			2.0 * supported_threshold,
		)
		and is_equal_approx(
			float(receipt.get("nearest_distance_dimensionless", NAN)),
			nearest_query,
		)
		and String(receipt.get("nearest_cohort_id", "")) == nearest_id
		and (
			String(receipt.get("status", ""))
			== CoverageReceiptScript.classify_distance(
				nearest_query,
				supported_threshold,
				2.0 * supported_threshold,
			)
		)
	)


static func _gq13_receipt_contract(cells: Array, compiled_cells: Array) -> Dictionary:
	var cohort_features := _gq13_build_cohort_feature_results()
	var query_features := _gq13_query_feature_results(cells, compiled_cells)
	var cohort_features_exact := cohort_features.size() == 20
	var realized_cohort_ids: Array = []
	for feature_value in cohort_features:
		var feature: Dictionary = feature_value
		var receipt: Dictionary = feature.get("feature_receipt", {})
		var digest := String(feature.get("feature_receipt_sha256", ""))
		realized_cohort_ids.append(String(receipt.get("morphology_id", "")))
		cohort_features_exact = (
			cohort_features_exact
			and int(feature.get("world_build_count", -1)) == 0
			and String(receipt.get("campaign_id", "")) == CampaignScript.CAMPAIGN_GQ11
			and digest == CanonicalJsonScript.sha256(receipt)
			and (
				String(receipt.get("policy_response", ""))
				== "REPORT_ONLY_NO_CONTROLLER_OR_ACCEPTANCE_AUTHORITY"
			)
			and not bool(receipt.get("formal_milestone_acceptance_authorized", true))
		)
	var query_features_exact := query_features.size() == 20
	for feature_value in query_features:
		var feature: Dictionary = feature_value
		var receipt: Dictionary = feature.get("feature_receipt", {})
		var source_digests: Dictionary = receipt.get("source_digests", {})
		query_features_exact = (
			query_features_exact
			and int(feature.get("world_build_count", -1)) == 0
			and String(receipt.get("campaign_id", "")) == CampaignScript.CAMPAIGN_GQ13
			and (
				(receipt.get("axis_order", []) as Array)
				== FeatureReceiptScript.AXIS_ORDER
			)
			and (
				(receipt.get("ordered_signed_centered_coordinates_dimensionless", []) as Array)
				. size()
				== 6
			)
			and (
				(receipt.get("ordered_realized_scales_dimensionless", []) as Array)
				. size()
				== 6
			)
			and source_digests.size() == 7
			and (
				String(feature.get("feature_receipt_sha256", ""))
				== CanonicalJsonScript.sha256(receipt)
			)
			and not bool(receipt.get("formal_milestone_acceptance_authorized", true))
			and not bool(receipt.get("encyclopedia_admission_authorized", true))
			and not bool(receipt.get("automatic_creature_guidance_allowed", true))
		)
	var coverage_results: Array = []
	if cohort_features.size() == 20 and query_features.size() == 20:
		for query_value in query_features:
			coverage_results.append(
				CoverageReceiptScript.compile(
					cohort_features,
					query_value,
				)
			)
	var cohort_order_exact := coverage_results.size() == 20
	var coverage_math_exact := coverage_results.size() == 20
	var coverage_authority_exact := coverage_results.size() == 20
	for result_index in range(coverage_results.size()):
		var coverage: Dictionary = coverage_results[result_index]
		var receipt: Dictionary = coverage.get("coverage_receipt", {})
		cohort_order_exact = (
			cohort_order_exact
			and (
				(receipt.get("ordered_cohort_member_ids", []) as Array)
				== CoverageReceiptScript.COHORT_IDS
			)
			and (
				String(receipt.get("claim_level", ""))
				== CoverageReceiptScript.CLAIM_LEVEL
			)
			and (
				String(receipt.get("candidate33_source_sha256", ""))
				== CoverageReceiptScript.CANDIDATE33_SOURCE_SHA256
			)
		)
		coverage_math_exact = (
			coverage_math_exact
			and _coverage_math_exact(
				coverage,
				cohort_features,
				query_features[result_index],
			)
		)
		coverage_authority_exact = (
			coverage_authority_exact
			and bool(coverage.get("ok", false))
			and int(coverage.get("world_build_count", -1)) == 0
			and (
				String(receipt.get("policy_response", ""))
				== CoverageReceiptScript.POLICY_RESPONSE
			)
			and not bool(receipt.get("controller_branch_authority", true))
			and not bool(receipt.get("physical_acceptance_authority", true))
			and not bool(receipt.get("formal_milestone_acceptance_authorized", true))
			and not bool(receipt.get("encyclopedia_admission_authorized", true))
			and not bool(receipt.get("automatic_creature_guidance_allowed", true))
		)
	var feature_verify_fail_closed := false
	if query_features.size() == 20:
		var first_generation := ProportionSpecScript.compile_gq13_generation(133)
		var first_cell: Dictionary = cells[0]
		var clock := ClockSpecScript.gq13_clock()
		var solver_result := WaveGaitScript.compile_solver_policy_options(
			CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		var controller_digest := CampaignScript._expected_controller_sha256(
			CampaignScript.CAMPAIGN_GQ13,
			CampaignScript._motor_velocity_options(
				CampaignScript.CAMPAIGN_GQ13,
				first_cell,
			),
			CampaignScript._path_steering_options(
				CampaignScript.CAMPAIGN_GQ13,
				first_cell,
			),
		)
		var exact_digest := String(query_features[0].get("feature_receipt_sha256", ""))
		var verified := FeatureReceiptScript.verify(
			first_generation,
			compiled_cells[0],
			controller_digest,
			clock,
			solver_result.get("solver_policy_options", {}),
			exact_digest,
		)
		var bad_digest := exact_digest.left(70) + ("0" if exact_digest.right(1) != "0" else "1")
		var tampered := FeatureReceiptScript.verify(
			first_generation,
			compiled_cells[0],
			controller_digest,
			clock,
			solver_result.get("solver_policy_options", {}),
			bad_digest,
		)
		var invalid_controller := FeatureReceiptScript.compile(
			first_generation,
			compiled_cells[0],
			"not-a-digest",
			clock,
			solver_result.get("solver_policy_options", {}),
		)
		feature_verify_fail_closed = (
			bool(verified.get("ok", false))
			and int(verified.get("world_build_count", -1)) == 0
			and not bool(tampered.get("ok", true))
			and (
				String(tampered.get("failure_code", ""))
				== "MORPHOLOGY_FEATURE_RECEIPT_DIGEST_MISMATCH"
			)
			and int(tampered.get("world_build_count", -1)) == 0
			and not bool(invalid_controller.get("ok", true))
			and int(invalid_controller.get("world_build_count", -1)) == 0
		)
	var coverage_boundaries_exact := (
		CoverageReceiptScript.classify_distance(2.0, 2.0, 4.0) == "SUPPORTED"
		and CoverageReceiptScript.classify_distance(2.000001, 2.0, 4.0) == "EDGE"
		and CoverageReceiptScript.classify_distance(4.0, 2.0, 4.0) == "EDGE"
		and (
			CoverageReceiptScript.classify_distance(4.000001, 2.0, 4.0)
			== "OUT_OF_DISTRIBUTION"
		)
		and CoverageReceiptScript.classify_distance(NAN, 2.0, 4.0).is_empty()
	)
	if cohort_features.size() == 20 and query_features.size() == 20:
		var reversed_cohort := cohort_features.duplicate(true)
		reversed_cohort.reverse()
		var wrong_order := CoverageReceiptScript.compile(reversed_cohort, query_features[0])
		var short_cohort := CoverageReceiptScript.compile(
			cohort_features.slice(0, 19),
			query_features[0],
		)
		var tampered_query: Dictionary = query_features[0].duplicate(true)
		tampered_query["feature_receipt_sha256"] = "sha256:%064d" % 0
		var bad_query := CoverageReceiptScript.compile(cohort_features, tampered_query)
		coverage_authority_exact = (
			coverage_authority_exact
			and not bool(wrong_order.get("ok", true))
			and int(wrong_order.get("world_build_count", -1)) == 0
			and not bool(short_cohort.get("ok", true))
			and int(short_cohort.get("world_build_count", -1)) == 0
			and not bool(bad_query.get("ok", true))
			and int(bad_query.get("world_build_count", -1)) == 0
		)
	return {
		"cohort_features_exact": cohort_features_exact,
		"cohort_order_exact":
		cohort_order_exact and realized_cohort_ids == CoverageReceiptScript.COHORT_IDS,
		"query_features_exact": query_features_exact,
		"feature_verify_fail_closed": feature_verify_fail_closed,
		"coverage_math_exact": coverage_math_exact,
		"coverage_boundaries_exact": coverage_boundaries_exact,
		"coverage_authority_fail_closed": coverage_authority_exact,
	}


static func _synthetic_dynamic_observer(
	center_of_mass_margin_m: float,
	capture_margin_m: float,
) -> Dictionary:
	return {
		"ok": true,
		"whole_system_mass_kg": 5.0,
		"center_of_mass_world_m": Vector3(0.0, 0.5, 0.0),
		"center_of_mass_velocity_world_m_s": Vector3(0.1, 0.0, 0.0),
		"support_plane_height_m": 0.0,
		"center_of_mass_height_above_support_m": 0.5,
		"linearized_natural_frequency_rad_s": sqrt(9.8 / 0.5),
		"linearized_capture_point_world_m": Vector3(0.02, 0.5, 0.0),
		"support_centroid_world_m": Vector3.ZERO,
		"support_vertices_world_xz_m":
		[[-0.2, -0.2], [0.2, -0.2], [0.2, 0.2], [-0.2, 0.2]],
		"center_of_mass_margin_m": center_of_mass_margin_m,
		"linearized_capture_margin_m": capture_margin_m,
		"minimum_dynamic_support_margin_m":
		minf(center_of_mass_margin_m, capture_margin_m),
		"contact_presence_is_bearing_measurement": false,
		"articulated_capture_guarantee_available": false,
		"per_foot_measured_load_allocation_available": false,
		"physics_state_modified": false,
	}


static func _dynamic_support_polygon_order_contract_exact() -> bool:
	var canonical_semantic_order_points: Array[Vector3] = [
		Vector3(1.0, 0.0, -1.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(-1.0, 0.0, -1.0),
		Vector3(-1.0, 0.0, 1.0),
	]
	var perimeter_points: Array[Vector3] = [
		Vector3(1.0, 0.0, -1.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(-1.0, 0.0, 1.0),
		Vector3(-1.0, 0.0, -1.0),
	]
	var crossed := DynamicSupportObserverScript._polygon_metrics(
		canonical_semantic_order_points
	)
	var perimeter := DynamicSupportObserverScript._polygon_metrics(perimeter_points)
	return (
		DynamicSupportReceiptScript.ORDERED_CONTACT_IDS
		== ["front_left", "front_right", "rear_left", "rear_right"]
		and (
			DynamicSupportReceiptScript.ORDERED_SUPPORT_POLYGON_CONTACT_IDS
			== ["front_left", "front_right", "rear_right", "rear_left"]
		)
		and not bool(crossed.get("ok", false))
		and (
			String(crossed.get("failure_code", ""))
			== "SPATIAL_DYNAMIC_SUPPORT_POLYGON_DEGENERATE"
		)
		and bool(perimeter.get("ok", false))
		and is_equal_approx(float(perimeter.get("mean_height_m", NAN)), 0.0)
	)


static func _gq13_dynamic_trace_contract_exact() -> bool:
	var active_ids := ["front_left", "front_right", "rear_left"]
	var sample_results := [
		DynamicSupportReceiptScript.compile_sample(
			10,
			"SETTLE_BOUNDARY",
			active_ids,
			_synthetic_dynamic_observer(0.20, 0.10),
			0.0,
		),
		DynamicSupportReceiptScript.compile_sample(
			11,
			"EVIDENCE",
			active_ids,
			_synthetic_dynamic_observer(-0.10, 0.05),
			0.60,
		),
		DynamicSupportReceiptScript.compile_sample(
			12,
			"TERMINAL_SETTLE",
			active_ids,
			_synthetic_dynamic_observer(-0.10, -0.20),
			1.10,
		),
	]
	var samples: Array = []
	for result_value in sample_results:
		var result: Dictionary = result_value
		if not bool(result.get("ok", false)) or int(result.get("world_build_count", -1)) != 0:
			return false
		samples.append(result["sample"])
	var valid_digest := "sha256:%064d" % 0
	var metadata := {
		"contact_progression_timeout": false,
		"evidence_extension_ticks": 7,
		"maximum_anchor_error_tick": 11,
		"final_support_contact_state":
		{
			"front_left": true,
			"front_right": true,
			"rear_left": true,
			"rear_right": true,
		},
		"lateral_limit_m": 1.0,
		"source_digests": {"synthetic_source_sha256": valid_digest},
	}
	var aggregate := DynamicSupportReceiptScript.compile(samples, metadata)
	if not bool(aggregate.get("ok", false)):
		return false
	var receipt: Dictionary = aggregate["dynamic_support_receipt"]
	var aggregate_digest := String(aggregate["dynamic_support_receipt_sha256"])
	var verified := DynamicSupportReceiptScript.verify(
		samples,
		metadata,
		aggregate_digest,
	)
	var unordered := DynamicSupportReceiptScript.compile_sample(
		13,
		"EVIDENCE",
		["rear_left", "front_left", "front_right"],
		_synthetic_dynamic_observer(0.1, 0.1),
		0.0,
	)
	var nonfinite_observer := _synthetic_dynamic_observer(0.1, 0.1)
	nonfinite_observer["center_of_mass_margin_m"] = NAN
	var nonfinite := DynamicSupportReceiptScript.compile_sample(
		13,
		"EVIDENCE",
		active_ids,
		nonfinite_observer,
		0.0,
	)
	var unordered_trace := samples.duplicate(true)
	unordered_trace.reverse()
	var bad_order := DynamicSupportReceiptScript.compile(unordered_trace, metadata)
	var tampered_verify := DynamicSupportReceiptScript.verify(
		samples,
		metadata,
		"sha256:%064d" % 1,
	)
	return (
		int(receipt.get("sample_count_dimensionless", -1)) == 3
		and (
			String(receipt.get("ordered_trace_sha256", ""))
			== CanonicalJsonScript.sha256(samples)
		)
		and is_equal_approx(
			float(receipt.get("minimum_center_of_mass_margin_m", NAN)),
			-0.10,
		)
		and int(receipt.get("first_minimum_center_of_mass_margin_tick_dimensionless", -1)) == 11
		and is_equal_approx(
			float(receipt.get("minimum_linearized_capture_margin_m", NAN)),
			-0.20,
		)
		and (
			int(receipt.get("first_minimum_linearized_capture_margin_tick_dimensionless", -1))
			== 12
		)
		and is_equal_approx(
			float(receipt.get("minimum_dynamic_support_margin_m", NAN)),
			-0.20,
		)
		and (
			int(receipt.get("first_minimum_dynamic_support_margin_tick_dimensionless", -1))
			== 12
		)
		and (
			int(receipt.get("first_nonpositive_center_of_mass_margin_tick_dimensionless", -1))
			== 11
		)
		and (
			int(
				receipt.get(
					"first_nonpositive_linearized_capture_margin_tick_dimensionless",
					-1,
				)
			)
			== 12
		)
		and (
			int(receipt.get("first_nonpositive_dynamic_support_margin_tick_dimensionless", -1))
			== 11
		)
		and int(receipt.get("first_half_lateral_limit_tick_dimensionless", -1)) == 11
		and int(receipt.get("first_full_lateral_limit_tick_dimensionless", -1)) == 12
		and aggregate_digest == CanonicalJsonScript.sha256(receipt)
		and bool(verified.get("ok", false))
		and int(verified.get("world_build_count", -1)) == 0
		and not bool(receipt.get("contact_presence_is_bearing_measurement", true))
		and not bool(receipt.get("articulated_capture_guarantee_available", true))
		and not bool(receipt.get("controller_authority", true))
		and not bool(receipt.get("walker_predicate_authority", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
		and not bool(unordered.get("ok", true))
		and int(unordered.get("world_build_count", -1)) == 0
		and not bool(nonfinite.get("ok", true))
		and int(nonfinite.get("world_build_count", -1)) == 0
		and not bool(bad_order.get("ok", true))
		and int(bad_order.get("world_build_count", -1)) == 0
		and not bool(tampered_verify.get("ok", true))
		and int(tampered_verify.get("world_build_count", -1)) == 0
	)


static func _static_screen_exact(compiled: Dictionary) -> bool:
	var screen: Dictionary = compiled.get("static_screen", {})
	var predicates: Dictionary = screen.get("predicates", {})
	return (
		bool(screen.get("passed", false))
		and int(screen.get("world_build_count", -1)) == 0
		and String(screen.get("failed_predicate", "x")).is_empty()
		and float(screen.get("foot_floor_error_m", INF)) <= 1.0e-9
		and float(screen.get("minimum_nonadjacent_clearance_m", -INF)) >= 0.0
		and float(screen.get("maximum_connected_attachment_overlap_m", INF)) <= 0.012
		and float(screen.get("minimum_support_polygon_margin_m", -INF)) > 0.002
		and _all_true(predicates)
	)


static func _reference_policy_identity_exact(compiled: Dictionary) -> bool:
	var fixture: Dictionary = compiled["fixture_spec"]
	var clock_result := ClockSpecScript.dynamic_similarity_clock(1.0)
	var clock: Dictionary = clock_result.get("gait_clock_options", {})
	var path_result := WaveGaitScript._normalize_path_steering_options(
		CampaignScript.PATH_STEERING_OPTIONS
	)
	var actuator_result := WaveGaitScript._normalize_actuator_impulse_options({})
	var motor_result := WaveGaitScript._normalize_motor_velocity_options({}, 360)
	var controller := (
		WaveGaitScript
		. _controller_configuration(
			-1.0,
			10.0,
			1.75,
			"lateral",
			["rear_left", "front_left", "rear_right", "front_right"],
			72,
			0.40,
			"all",
			112,
			CampaignScript.ROBUSTNESS_OPTIONS,
			path_result.get("path_steering_options", {}),
			actuator_result.get("actuator_impulse_options", {}),
			motor_result.get("motor_velocity_options", {}),
			clock,
		)
	)
	var thresholds: Dictionary = CampaignScript._evidence_thresholds(fixture)
	var threshold_result := WaveGaitScript.compile_evidence_threshold_options(thresholds)
	print(
		(
			"G3_GP1_REFERENCE_IDENTITY controller=%s expected=%s thresholds=%s"
			% [
				CanonicalJsonScript.sha256(controller),
				CampaignScript.REFERENCE_CONTROLLER_SHA256,
				str(thresholds),
			]
		)
	)
	return (
		bool(clock_result.get("ok", false))
		and bool(path_result.get("ok", false))
		and bool(actuator_result.get("ok", false))
		and bool(motor_result.get("ok", false))
		and bool(threshold_result.get("ok", false))
		and int(threshold_result.get("world_build_count", -1)) == 0
		and CanonicalJsonScript.sha256(controller) == CampaignScript.REFERENCE_CONTROLLER_SHA256
		and is_equal_approx(float(thresholds["minimum_foot_relocation_m"]), 0.012)
		and is_equal_approx(float(thresholds["minimum_evidence_torso_advance_m"]), 0.040)
		and is_equal_approx(float(thresholds["minimum_final_torso_advance_m"]), 0.030)
		and is_equal_approx(float(thresholds["maximum_lateral_drift_m"]), 0.100)
		and is_equal_approx(float(thresholds["minimum_torso_height_m"]), 0.250)
		and is_equal_approx(float(thresholds["maximum_anchor_error_m"]), 0.025)
		and is_equal_approx(float(thresholds["maximum_yaw_drift_rad"]), 0.45)
		and is_equal_approx(float(thresholds["maximum_tilt_rad"]), 0.60)
		and is_equal_approx(float(thresholds["maximum_hinge_axis_error_rad"]), 0.20)
	)


static func _gp3_controller_policy_exact(compiled: Dictionary) -> bool:
	var fixture: Dictionary = compiled["fixture_spec"]
	var motor_impulses: Dictionary = fixture["motor_impulses"]
	var clock_result := ClockSpecScript.dynamic_similarity_clock(1.0)
	var clock: Dictionary = clock_result.get("gait_clock_options", {})
	var path_result := WaveGaitScript._normalize_path_steering_options(
		CampaignScript.GP3_PATH_STEERING_OPTIONS
	)
	var actuator_result := WaveGaitScript._normalize_actuator_impulse_options(
		CampaignScript.GP3_ACTUATOR_IMPULSE_OPTIONS
	)
	var motor_result := WaveGaitScript._normalize_motor_velocity_options({}, 360)
	var normalized_path: Dictionary = path_result.get("path_steering_options", {})
	var normalized_actuator: Dictionary = actuator_result.get("actuator_impulse_options", {})
	var controller := (
		WaveGaitScript
		. _controller_configuration(
			-1.0,
			10.0,
			1.75,
			"lateral",
			["rear_left", "front_left", "rear_right", "front_right"],
			72,
			0.40,
			"all",
			112,
			CampaignScript.ROBUSTNESS_OPTIONS,
			normalized_path,
			normalized_actuator,
			motor_result.get("motor_velocity_options", {}),
			clock,
		)
	)
	var controller_digest := CanonicalJsonScript.sha256(controller)
	var actuator_scale := float(normalized_actuator.get("actuator_impulse_scale", NAN))
	var realized_hip_impulse := float(motor_impulses["hip_max_impulse_nms"]) * actuator_scale
	var realized_knee_impulse := (
		float(motor_impulses["knee_base_max_impulse_nms"]) * 10.0 * actuator_scale
	)
	print(
		(
			"G3_GP3_CONTROLLER_IDENTITY controller=%s expected=%s impulses=(%.9f,%.9f)"
			% [
				controller_digest,
				CampaignScript.GP3_CONTROLLER_SHA256,
				realized_hip_impulse,
				realized_knee_impulse,
			]
		)
	)
	return (
		bool(clock_result.get("ok", false))
		and bool(path_result.get("ok", false))
		and bool(actuator_result.get("ok", false))
		and bool(motor_result.get("ok", false))
		and normalized_path == CampaignScript.GP3_PATH_STEERING_OPTIONS
		and normalized_actuator == CampaignScript.GP3_ACTUATOR_IMPULSE_OPTIONS
		and controller_digest == CampaignScript.GP3_CONTROLLER_SHA256
		and controller_digest != CampaignScript.REFERENCE_CONTROLLER_SHA256
		and is_equal_approx(realized_hip_impulse, 0.055825)
		and is_equal_approx(realized_knee_impulse, 0.456750)
	)


static func _gp4_controller_and_solver_policy_exact(compiled: Dictionary) -> bool:
	var gp3_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GP3)
	var gp4_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GP4)
	var default_solver_result := WaveGaitScript.compile_solver_policy_options()
	var gp4_solver_result := WaveGaitScript.compile_solver_policy_options(
		CampaignScript.GP4_SOLVER_POLICY_OPTIONS
	)
	var unknown_field := CampaignScript.GP4_SOLVER_POLICY_OPTIONS.duplicate(true)
	unknown_field["surprise"] = 1
	var wrong_type := CampaignScript.GP4_SOLVER_POLICY_OPTIONS.duplicate(true)
	wrong_type["solver_position_steps"] = 7.0
	var missing_field := CampaignScript.GP4_SOLVER_POLICY_OPTIONS.duplicate(true)
	missing_field.erase("solver_velocity_steps")
	var mismatched_receipt := CampaignScript.GP4_SOLVER_POLICY_OPTIONS.duplicate(true)
	mismatched_receipt["solver_position_steps"] = 6
	var unknown_policy := CampaignScript.GP4_SOLVER_POLICY_OPTIONS.duplicate(true)
	unknown_policy["solver_policy_id"] = "unknown"
	var gp4_solver_digest := String(gp4_solver_result.get("solver_policy_configuration_sha256", ""))
	return (
		_gp3_controller_policy_exact(compiled)
		and bool(default_solver_result.get("ok", false))
		and (
			(default_solver_result.get("solver_policy_options", {}) as Dictionary)
			== (
				WaveGaitScript.ALLOWED_SOLVER_POLICY_OPTIONS[
					WaveGaitScript.DEFAULT_SOLVER_POLICY_ID
				]
				as Dictionary
			)
		)
		and bool(gp4_solver_result.get("ok", false))
		and int(gp4_solver_result.get("world_build_count", -1)) == 0
		and (
			(gp4_solver_result.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and gp4_solver_digest.begins_with("sha256:")
		and gp4_solver_digest.length() == 71
		and String(gp4_policy.get("controller_sha256", "")) == CampaignScript.GP3_CONTROLLER_SHA256
		and (
			(gp4_policy.get("path_steering_options", {}) as Dictionary)
			== CampaignScript.GP3_PATH_STEERING_OPTIONS
		)
		and (
			(gp4_policy.get("actuator_impulse_options", {}) as Dictionary)
			== CampaignScript.GP3_ACTUATOR_IMPULSE_OPTIONS
		)
		and (
			(gp4_policy.get("solver_policy_options", {}) as Dictionary)
			== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		)
		and String(gp4_policy.get("solver_policy_sha256", "")) == gp4_solver_digest
		and CanonicalJsonScript.sha256(gp4_policy) != CanonicalJsonScript.sha256(gp3_policy)
		and _solver_policy_fails_without_world(unknown_field, "UNKNOWN_SOLVER_POLICY_OPTION")
		and _solver_policy_fails_without_world(wrong_type, "INVALID_SOLVER_POLICY_OPTION_TYPE")
		and _solver_policy_fails_without_world(missing_field, "MISSING_SOLVER_POLICY_OPTION")
		and _solver_policy_fails_without_world(
			mismatched_receipt,
			"SOLVER_POLICY_RECEIPT_MISMATCH",
		)
		and _solver_policy_fails_without_world(unknown_policy, "UNKNOWN_SOLVER_POLICY_ID")
	)


static func _gp5_scores_exact(selection: Array, held_out: Array) -> bool:
	for cell_value in selection:
		var cell: Dictionary = cell_value
		if CampaignScript._morphology_interaction_score(cell) != 0.0:
			return false
	for cell_value in held_out:
		var cell: Dictionary = cell_value
		if CampaignScript._morphology_interaction_score(cell) != 1.0:
			return false
	return true


static func _gp5_controller_policy_exact(selection: Array, held_out: Array) -> bool:
	var selection_options := (
		CampaignScript
		. _motor_velocity_options(
			CampaignScript.CAMPAIGN_GP5,
			selection[0],
		)
	)
	var held_out_options := (
		CampaignScript
		. _motor_velocity_options(
			CampaignScript.CAMPAIGN_GP5,
			held_out[0],
		)
	)
	var selection_result := (
		WaveGaitScript
		. _normalize_motor_velocity_options(
			selection_options,
			360,
		)
	)
	var held_out_result := (
		WaveGaitScript
		. _normalize_motor_velocity_options(
			held_out_options,
			360,
		)
	)
	if not bool(selection_result.get("ok", false)) or not bool(held_out_result.get("ok", false)):
		return false
	var normalized_selection: Dictionary = selection_result["motor_velocity_options"]
	var normalized_held_out: Dictionary = held_out_result["motor_velocity_options"]
	var selection_controller_digest := (
		CampaignScript
		. _expected_controller_sha256(
			CampaignScript.CAMPAIGN_GP5,
			selection_options,
		)
	)
	var held_out_controller_digest := (
		CampaignScript
		. _expected_controller_sha256(
			CampaignScript.CAMPAIGN_GP5,
			held_out_options,
		)
	)
	var gp4_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GP4)
	var gp5_policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GP5)
	var unknown_field := selection_options.duplicate(true)
	unknown_field["surprise"] = 1
	var missing_field := selection_options.duplicate(true)
	missing_field.erase("motor_velocity_policy_id")
	var wrong_guard_mode := selection_options.duplicate(true)
	wrong_guard_mode["anchor_error_guard_enabled"] = "true"
	var invalid_score := selection_options.duplicate(true)
	invalid_score["morphology_interaction_score"] = 1.01
	var nonfinite_score := selection_options.duplicate(true)
	nonfinite_score["morphology_interaction_score"] = INF
	var invalid_fraction := selection_options.duplicate(true)
	invalid_fraction["anchor_error_guard_activation_fraction"] = 1.0
	var invalid_speed := selection_options.duplicate(true)
	invalid_speed["anchor_error_guard_maximum_motor_target_speed_rad_s"] = 3.6
	return (
		normalized_selection["mass_adaptive_motor_velocity_enabled"] == true
		and (
			String(normalized_selection["motor_velocity_policy_id"])
			== "g3_gp5_morphology_interaction_anchor_guard_v1"
		)
		and (
			String(normalized_selection["activation_predicate_id"])
			== "morphology_interaction_anchor_guarded_contact_loaded_swing_knee"
		)
		and float(normalized_selection["morphology_interaction_score"]) == 0.0
		and float(normalized_held_out["morphology_interaction_score"]) == 1.0
		and float(normalized_selection["anchor_error_guard_activation_fraction"]) == 0.90
		and (
			float(normalized_selection["anchor_error_guard_maximum_motor_target_speed_rad_s"])
			== 2.5
		)
		and selection_controller_digest.begins_with("sha256:")
		and selection_controller_digest.length() == 71
		and held_out_controller_digest.begins_with("sha256:")
		and held_out_controller_digest.length() == 71
		and selection_controller_digest != held_out_controller_digest
		and (
			String(gp5_policy.get("selection_controller_sha256", "")) == selection_controller_digest
		)
		and (String(gp5_policy.get("held_out_controller_sha256", "")) == held_out_controller_digest)
		and (
			(gp5_policy.get("motor_velocity_options_score_zero_template", {}) as Dictionary)
			== CampaignScript.GP5_MOTOR_VELOCITY_OPTIONS
		)
		and (
			String(gp5_policy.get("morphology_interaction_score_policy_id", ""))
			== "clamped_pairwise_normalized_absolute_deviation_sum_v1"
		)
		and CanonicalJsonScript.sha256(gp5_policy) != CanonicalJsonScript.sha256(gp4_policy)
		and _motor_velocity_policy_fails_without_world(
			unknown_field,
			"UNKNOWN_MOTOR_VELOCITY_OPTION",
		)
		and _motor_velocity_policy_fails_without_world(
			missing_field,
			"MISSING_MOTOR_VELOCITY_OPTION",
		)
		and _motor_velocity_policy_fails_without_world(
			wrong_guard_mode,
			"INVALID_ANCHOR_ERROR_GUARD_MODE",
		)
		and _motor_velocity_policy_fails_without_world(
			invalid_score,
			"MORPHOLOGY_INTERACTION_SCORE_OUT_OF_BOUNDS",
		)
		and _motor_velocity_policy_fails_without_world(
			nonfinite_score,
			"MORPHOLOGY_INTERACTION_SCORE_OUT_OF_BOUNDS",
		)
		and _motor_velocity_policy_fails_without_world(
			invalid_fraction,
			"ANCHOR_ERROR_GUARD_ACTIVATION_FRACTION_OUT_OF_BOUNDS",
		)
		and _motor_velocity_policy_fails_without_world(
			invalid_speed,
			"ANCHOR_ERROR_GUARD_MOTOR_TARGET_SPEED_OUT_OF_BOUNDS",
		)
	)


static func _motor_velocity_policy_fails_without_world(
	requested: Dictionary,
	expected_failure: String,
) -> bool:
	var result := WaveGaitScript._normalize_motor_velocity_options(requested, 360)
	return (
		not bool(result.get("ok", true))
		and String(result.get("failure_code", "")) == expected_failure
		and int(result.get("world_build_count", -1)) == 0
	)


static func _solver_policy_fails_without_world(
	requested: Dictionary,
	expected_failure: String,
) -> bool:
	var result := WaveGaitScript.compile_solver_policy_options(requested)
	return (
		not bool(result.get("ok", true))
		and String(result.get("failure_code", "")) == expected_failure
		and int(result.get("world_build_count", -1)) == 0
	)


static func _cells_numerically_equal_except_id(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		var left_cell: Dictionary = left[index].duplicate(true)
		var right_cell: Dictionary = right[index].duplicate(true)
		left_cell.erase("morphology_id")
		right_cell.erase("morphology_id")
		if left_cell != right_cell:
			return false
	return true


static func _all_cells_compile(compiled_cells: Array) -> bool:
	for compiled_value in compiled_cells:
		var compiled: Dictionary = compiled_value
		if not bool(compiled.get("ok", false)) or int(compiled.get("world_build_count", -1)) != 0:
			return false
		for key_value in [
			"proportion_spec_sha256",
			"fixture_spec_sha256",
			"static_screen_sha256",
		]:
			var digest := String(compiled.get(key_value, ""))
			if not digest.begins_with("sha256:") or digest.length() != 71:
				return false
	return true


static func _all_fixture_formulas_exact(cells: Array, compiled_cells: Array) -> bool:
	for index in range(cells.size()):
		var parameters: Dictionary = cells[index]
		var fixture: Dictionary = compiled_cells[index]["fixture_spec"]
		var torso: Dictionary = fixture["torso"]
		var torso_size: Array = torso["size_m"]
		var torso_center: Array = torso["initial_center_m"]
		if (
			not is_equal_approx(
				float(torso_size[0]), 0.50 * float(parameters["torso_length_scale"])
			)
			or not is_equal_approx(float(torso_size[1]), 0.12)
			or not is_equal_approx(
				float(torso_size[2]), 0.32 * float(parameters["torso_width_scale"])
			)
			or not is_equal_approx(
				float(torso_center[1]),
				0.40 + 0.04 * float(parameters["foot_radius_scale"]),
			)
		):
			return false
		for limb_value in fixture["limbs"]:
			var limb: Dictionary = limb_value
			var limb_id := String(limb["limb_id"])
			var hip: Array = limb["hip_offset_from_torso_center_m"]
			var expected_x_sign := 1.0 if limb_id.begins_with("front_") else -1.0
			var expected_z_sign := -1.0 if limb_id.ends_with("_left") else 1.0
			var expected_mass_scale := (
				float(parameters["front_limb_mass_scale"])
				if limb_id.begins_with("front_")
				else 2.0 - float(parameters["front_limb_mass_scale"])
			)
			if (
				not is_equal_approx(
					float(hip[0]),
					expected_x_sign * 0.20 * float(parameters["hip_span_scale"]),
				)
				or not is_equal_approx(
					float(hip[2]),
					expected_z_sign * 0.18 * float(parameters["hip_span_scale"]),
				)
				or not is_equal_approx(
					float(limb["upper_length_m"]),
					0.35 * float(parameters["upper_length_fraction"]),
				)
				or not is_equal_approx(
					float(limb["lower_length_m"]),
					0.35 * (1.0 - float(parameters["upper_length_fraction"])),
				)
				or not is_equal_approx(
					float(limb["foot_radius_m"]),
					0.04 * float(parameters["foot_radius_scale"]),
				)
				or not is_equal_approx(float(limb["upper_mass_kg"]), 0.25 * expected_mass_scale)
				or not is_equal_approx(float(limb["distal_mass_kg"]), 0.18 * expected_mass_scale)
			):
				return false
	return true


static func _all_mass_and_reach_invariants_exact(compiled_cells: Array) -> bool:
	for compiled_value in compiled_cells:
		var fixture: Dictionary = compiled_value["fixture_spec"]
		var upper_mass := 0.0
		var distal_mass := 0.0
		for limb_value in fixture["limbs"]:
			var limb: Dictionary = limb_value
			if not is_equal_approx(
				float(limb["upper_length_m"]) + float(limb["lower_length_m"]),
				0.35,
			):
				return false
			upper_mass += float(limb["upper_mass_kg"])
			distal_mass += float(limb["distal_mass_kg"])
		if (
			not is_equal_approx(float((fixture["torso"] as Dictionary)["mass_kg"]), 3.0)
			or not is_equal_approx(upper_mass, 1.0)
			or not is_equal_approx(distal_mass, 0.72)
		):
			return false
	return true


static func _all_static_screens_exact(compiled_cells: Array) -> bool:
	for compiled_value in compiled_cells:
		if not _static_screen_exact(compiled_value):
			return false
	return true


static func _expected_gq14_generation(
	generator_index: int,
	campaign_role: String,
) -> Dictionary:
	var predecessor := _expected_gq13_generation(generator_index, campaign_role)
	var proportion_spec: Dictionary = (
		predecessor["proportion_spec"] as Dictionary
	).duplicate(true)
	proportion_spec["morphology_id"] = "gq14_generated_s%03d" % generator_index
	var generator_receipt: Dictionary = (
		predecessor["generator_receipt"] as Dictionary
	).duplicate(true)
	generator_receipt["schema_version"] = (
		ProportionSpecScript.GQ14_GENERATOR_SCHEMA_VERSION
	)
	generator_receipt["generator_policy_id"] = (
		ProportionSpecScript.GQ14_GENERATOR_POLICY_ID
	)
	generator_receipt["campaign_id"] = ProportionSpecScript.CAMPAIGN_GQ14
	generator_receipt["proportion_spec"] = proportion_spec.duplicate(true)
	return {
		"proportion_spec": proportion_spec,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
	}


static func _test_gq14_velocity(
	score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	foot_radius_scale: float,
	yaw_gain: float,
) -> float:
	if yaw_gain > 1.0:
		var long_wide := (
			clampf((torso_length_scale - 1.0) / 0.07, 0.0, 1.0)
			* clampf((torso_width_scale - 1.0) / 0.06, 0.0, 1.0)
		)
		var long_large_foot := (
			clampf((torso_length_scale - 1.0) / 0.05, 0.0, 1.0)
			* clampf((foot_radius_scale - 1.01) / 0.02, 0.0, 1.0)
		)
		return 0.25 + 0.05 * maxf(long_wide, long_large_foot)
	if score < 0.15:
		if torso_width_scale <= 1.0:
			return (
				0.275
				+ 0.075
				* clampf((torso_length_scale - 1.0) / 0.01, 0.0, 1.0)
				* clampf((1.01 - foot_radius_scale) / 0.01, 0.0, 1.0)
			)
		return 0.40
	if score < 0.5:
		return 0.75 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((score - 0.5) / 0.5, 0.0, 1.0)
	if torso_width_scale <= 1.0 and torso_length_scale < 0.95:
		return 0.35 + 0.10 * clampf((1.0 - score) / 0.40, 0.0, 1.0)
	return 0.35


static func _gq14_query_feature_results(
	cells: Array,
	compiled_cells: Array,
) -> Array:
	if cells.size() != compiled_cells.size():
		return []
	var clock_result := ClockSpecScript.compile(ClockSpecScript.gq14_clock())
	var solver_result := WaveGaitScript.compile_solver_policy_options(
		CampaignScript.GP4_SOLVER_POLICY_OPTIONS
	)
	if not bool(clock_result.get("ok", false)) or not bool(solver_result.get("ok", false)):
		return []
	var clock: Dictionary = clock_result["gait_clock_options"]
	var solver: Dictionary = solver_result["solver_policy_options"]
	var indices: Array = (
		ProportionSpecScript.GQ14_SELECTION_INDICES
		+ ProportionSpecScript.GQ14_HELD_OUT_INDICES
	)
	var results: Array = []
	for cell_index in range(cells.size()):
		var cell: Dictionary = cells[cell_index]
		var generation := ProportionSpecScript.compile_gq14_generation(
			int(indices[cell_index])
		)
		var controller_digest := CampaignScript._expected_controller_sha256(
			CampaignScript.CAMPAIGN_GQ14,
			CampaignScript._motor_velocity_options(
				CampaignScript.CAMPAIGN_GQ14,
				cell,
			),
			CampaignScript._path_steering_options(
				CampaignScript.CAMPAIGN_GQ14,
				cell,
			),
		)
		var feature := FeatureReceiptScript.compile(
			generation,
			compiled_cells[cell_index],
			controller_digest,
			clock,
			solver,
		)
		if not bool(feature.get("ok", false)):
			return []
		results.append(feature)
	return results


static func _synthetic_support_observer(
	dimension: int,
	com_margin_m: float,
	capture_margin_m: float,
) -> Dictionary:
	var observer := _synthetic_dynamic_observer(com_margin_m, capture_margin_m)
	observer["support_geometry_dimension"] = dimension
	observer["support_geometry_kind"] = ["POINT", "SEGMENT", "POLYGON"][dimension]
	observer["support_polygon_available"] = dimension == 2
	if dimension == 0:
		observer["support_vertices_world_xz_m"] = [[0.0, 0.0]]
	elif dimension == 1:
		observer["support_vertices_world_xz_m"] = [[-0.2, 0.0], [0.2, 0.0]]
	return observer


static func _gq14_contract(
	selection: Array,
	held_out: Array,
	compiled_cells: Array,
) -> Dictionary:
	var cells := selection + held_out
	var expected_selection_ids: Array = []
	for generator_index in range(145, 157):
		expected_selection_ids.append("gq14_generated_s%03d" % generator_index)
	var expected_heldout_ids: Array = []
	for generator_index in range(1301, 1309):
		expected_heldout_ids.append("gq14_generated_s%03d" % generator_index)
	var realized_selection_ids: Array = []
	var realized_heldout_ids: Array = []
	for cell_value in selection:
		realized_selection_ids.append(
			String((cell_value as Dictionary).get("morphology_id", ""))
		)
	for cell_value in held_out:
		realized_heldout_ids.append(
			String((cell_value as Dictionary).get("morphology_id", ""))
		)
	var population_exact := (
		selection.size() == 12
		and held_out.size() == 8
		and realized_selection_ids == expected_selection_ids
		and realized_heldout_ids == expected_heldout_ids
		and (
			ProportionSpecScript.GQ14_SELECTION_INDICES
			== [145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156]
		)
		and (
			ProportionSpecScript.GQ14_HELD_OUT_INDICES
			== [1301, 1302, 1303, 1304, 1305, 1306, 1307, 1308]
		)
	)
	var indices: Array = (
		ProportionSpecScript.GQ14_SELECTION_INDICES
		+ ProportionSpecScript.GQ14_HELD_OUT_INDICES
	)
	var generation_exact := population_exact and cells.size() == 20
	var generation_digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var role := "selection" if cell_index < selection.size() else "heldout"
		var cell: Dictionary = cells[cell_index]
		var expected := _expected_gq14_generation(generator_index, role)
		var realized := ProportionSpecScript.compile_gq14_generation(generator_index)
		var digest := String(realized.get("generator_receipt_sha256", ""))
		var verified := ProportionSpecScript.verify_gq14_generation(
			generator_index,
			digest,
		)
		var reverse := ProportionSpecScript.gq14_generation_for_morphology(
			String(cell["morphology_id"]),
			role,
		)
		generation_exact = (
			generation_exact
			and bool(realized.get("ok", false))
			and int(realized.get("world_build_count", -1)) == 0
			and realized.get("proportion_spec", {}) == cell
			and realized.get("proportion_spec", {}) == expected["proportion_spec"]
			and realized.get("generator_receipt", {}) == expected["generator_receipt"]
			and digest == String(expected["generator_receipt_sha256"])
			and bool(verified.get("ok", false))
			and int(verified.get("world_build_count", -1)) == 0
			and reverse.get("proportion_spec", {}) == cell
		)
		generation_digests[digest] = true
	var first_generation := ProportionSpecScript.compile_gq14_generation(145)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var bad_digest := first_digest.left(70) + (
		"0" if first_digest.right(1) != "0" else "1"
	)
	generation_exact = (
		generation_exact
		and generation_digests.size() == 20
		and not generation_digests.has("")
		and not bool(
			ProportionSpecScript.compile_gq14_generation(145.0).get("ok", true)
		)
		and not bool(
			ProportionSpecScript.compile_gq14_generation(144).get("ok", true)
		)
		and not bool(
			ProportionSpecScript.verify_gq14_generation(145, bad_digest).get(
				"ok",
				true,
			)
		)
		and not bool(
			ProportionSpecScript.gq14_generation_for_morphology(
				"gq14_generated_s145",
				"heldout",
			).get("ok", true)
		)
		and not bool(
			ProportionSpecScript.gq14_generation_for_morphology(
				"gq13_generated_s145",
				"selection",
			).get("ok", true)
		)
	)
	var fixtures_exact := (
		compiled_cells.size() == 20
		and _all_cells_compile(compiled_cells)
		and _all_fixture_formulas_exact(cells, compiled_cells)
		and _all_mass_and_reach_invariants_exact(compiled_cells)
		and _all_static_screens_exact(compiled_cells)
		and _all_receipts_distinct(compiled_cells)
	)
	var controllers_exact := cells.size() == 20
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var score := _test_morphology_interaction_score(cell)
		var length_scale := float(cell["torso_length_scale"])
		var width_scale := float(cell["torso_width_scale"])
		var foot_scale := float(cell["foot_radius_scale"])
		var yaw_gain := _test_gq10_yaw_gain(
			score,
			length_scale,
			foot_scale,
			float(cell["hip_span_scale"]),
		)
		var path := CampaignScript._path_steering_options(
			CampaignScript.CAMPAIGN_GQ14,
			cell,
		)
		var motor := CampaignScript._motor_velocity_options(
			CampaignScript.CAMPAIGN_GQ14,
			cell,
		)
		var expected_guard := (
			[0.70, 1.75]
			if score >= 0.5 and length_scale > 1.04 and width_scale < 0.95
			else ([0.80, 2.0] if score >= 0.5 else [0.90, 2.5])
		)
		var digest := CampaignScript._expected_controller_sha256(
			CampaignScript.CAMPAIGN_GQ14,
			motor,
			path,
		)
		var varied := cell.duplicate(true)
		varied["morphology_id"] = "outcome_named_failure"
		varied["generator_index"] = 999999
		varied["campaign_role"] = "heldout"
		varied["repetition"] = 3
		varied["seed"] = 123456
		varied["coverage_status"] = "OUT_OF_DISTRIBUTION"
		varied["support_margin_m"] = -999.0
		varied["observed_outcome"] = false
		controllers_exact = (
			controllers_exact
			and is_equal_approx(
				float(path.get("cross_track_velocity_heading_gain_rad_per_m_s", NAN)),
				_test_gq14_velocity(
					score,
					length_scale,
					width_scale,
					foot_scale,
					yaw_gain,
				),
			)
			and is_equal_approx(
				float(motor.get("anchor_error_guard_activation_fraction", NAN)),
				float(expected_guard[0]),
			)
			and is_equal_approx(
				float(
					motor.get(
						"anchor_error_guard_maximum_motor_target_speed_rad_s",
						NAN,
					)
				),
				float(expected_guard[1]),
			)
			and digest.begins_with("sha256:")
			and digest.length() == 71
			and (
				CampaignScript._path_steering_options(
					CampaignScript.CAMPAIGN_GQ14,
					varied,
				)
				== path
			)
			and (
				CampaignScript._motor_velocity_options(
					CampaignScript.CAMPAIGN_GQ14,
					varied,
				)
				== motor
			)
		)
		controller_digests[digest] = true
	controllers_exact = (
		controllers_exact
		and controller_digests.size() > 2
		and not controller_digests.has("")
	)
	var actual_velocity := Callable(
		CampaignScript,
		"_gq14_velocity_gain_rad_per_m_s",
	)
	var velocity_boundaries_exact := (
		is_equal_approx(
			actual_velocity.call(0.0, 1.035, 1.03, 1.02, 1.1),
			0.2675,
		)
		and is_equal_approx(
			actual_velocity.call(0.0, 1.07, 1.06, 1.03, 1.1),
			0.30,
		)
		and is_equal_approx(
			actual_velocity.call(0.149999, 1.0, 1.000001, 1.0, 1.0),
			0.40,
		)
		and is_equal_approx(
			actual_velocity.call(0.149999, 1.005, 1.0, 1.005, 1.0),
			0.29375,
		)
		and is_equal_approx(
			actual_velocity.call(0.15, 1.0, 1.0, 1.0, 1.0),
			0.75,
		)
		and is_equal_approx(
			actual_velocity.call(0.499999, 1.0, 1.000001, 1.0, 1.0),
			0.25,
		)
		and is_equal_approx(
			actual_velocity.call(0.5, 0.94, 1.0, 1.0, 1.0),
			0.45,
		)
		and is_equal_approx(
			actual_velocity.call(0.8, 0.94, 1.0, 1.0, 1.0),
			0.40,
		)
		and is_equal_approx(
			actual_velocity.call(0.5, 0.95, 1.0, 1.0, 1.0),
			0.35,
		)
		and is_equal_approx(
			actual_velocity.call(1.0, 0.999999, 1.000001, 1.0, 1.0),
			0.20,
		)
		and is_equal_approx(
			actual_velocity.call(1.0, 1.0, 1.000001, 1.0, 1.0),
			0.35,
		)
		and is_equal_approx(
			actual_velocity.call(0.149999, 1.01, 1.0, 1.01, 1.0),
			0.275,
		)
		and is_equal_approx(
			actual_velocity.call(1.0, 1.0, 1.06, 1.01, 1.1),
			0.25,
		)
	)
	var anchor_guard_exact := (
		CampaignScript._gq14_motor_guard_values(
			0.499999,
			{"torso_length_scale": 1.1, "torso_width_scale": 0.9},
		)
		== [0.90, 2.5]
		and (
			CampaignScript._gq14_motor_guard_values(
				0.5,
				{"torso_length_scale": 1.040001, "torso_width_scale": 0.949999},
			)
			== [0.70, 1.75]
		)
		and (
			CampaignScript._gq14_motor_guard_values(
				0.5,
				{"torso_length_scale": 1.04, "torso_width_scale": 0.949999},
			)
			== [0.80, 2.0]
		)
		and (
			CampaignScript._gq14_motor_guard_values(
				0.5,
				{"torso_length_scale": 1.040001, "torso_width_scale": 0.95},
			)
			== [0.80, 2.0]
		)
	)
	var clock := ClockSpecScript.gq14_clock()
	var clock_result := ClockSpecScript.compile(clock)
	var solver_result := WaveGaitScript.compile_solver_policy_options(
		CampaignScript.GP4_SOLVER_POLICY_OPTIONS
	)
	var numerics_exact: bool = (
		bool(clock_result.get("ok", false))
		and int(clock_result.get("world_build_count", -1)) == 0
		and String(clock.get("policy_id", "")) == ClockSpecScript.GQ14_POLICY_ID
		and ClockSpecScript.GQ14_POLICY_ID != ClockSpecScript.GQ13_POLICY_ID
		and int(clock.get("physics_hz", -1)) == 120
		and int(clock.get("cycle_ticks", -1)) == 360
		and int(clock.get("evidence_cycles", -1)) == 4
		and int(clock.get("maximum_contact_gate_hold_ticks", -1)) == 120
		and int(clock.get("maximum_contact_gated_evidence_extension_ticks", -1)) == 720
		and bool(solver_result.get("ok", false))
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_velocity_steps"]) == 20
		and int(CampaignScript.GP4_SOLVER_POLICY_OPTIONS["solver_position_steps"]) == 7
	)
	for compiled_value in compiled_cells:
		var fixture: Dictionary = (compiled_value as Dictionary)["fixture_spec"]
		var thresholds := CampaignScript._evidence_thresholds(
			fixture,
			CampaignScript.CAMPAIGN_GQ14,
		)
		var threshold_result := WaveGaitScript.compile_evidence_threshold_options(
			thresholds
		)
		numerics_exact = (
			numerics_exact
			and bool(threshold_result.get("ok", false))
			and int(threshold_result.get("world_build_count", -1)) == 0
		)
	var policy := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ14)
	var policy_text := CanonicalJsonScript.stringify(policy)
	var policy_and_preservation_exact := (
		String(policy.get("schema_version", ""))
		== "sporespore_g4_gq14_candidate34_support_sets_policy_v1"
		and String(policy.get("campaign_id", "")) == CampaignScript.CAMPAIGN_GQ14
		and String(policy.get("generator_policy_id", ""))
		== ProportionSpecScript.GQ14_GENERATOR_POLICY_ID
		and String(policy.get("clock_policy_id", "")) == ClockSpecScript.GQ14_POLICY_ID
		and String(policy.get("feature_policy_id", ""))
		== FeatureReceiptScript.GQ14_POLICY_ID
		and String(policy.get("coverage_schema_version", ""))
		== CoverageReceiptScript.GQ14_SCHEMA_VERSION
		and String(policy.get("coverage_policy_id", ""))
		== CoverageReceiptScript.GQ14_POLICY_ID
		and String(policy.get("dynamic_support_schema_version", ""))
		== DynamicSupportReceiptScript.GQ14_SCHEMA_VERSION
		and String(policy.get("dynamic_support_policy_id", ""))
		== DynamicSupportReceiptScript.GQ14_POLICY_ID
		and String(policy.get("report_schema_version", ""))
		== "sporespore_br14a_nonuniform_proportion_probe_report_v19"
		and CanonicalJsonScript.sha256(
			CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ13)
		)
		== "sha256:5e2eb3092479ad7c8b979d24e11fde4d9748e9374c142782ca8160085c15d7a4"
		and not policy_text.contains("coverage_status")
		and not policy_text.contains("observed_outcome")
		and not bool(policy.get("formal_milestone_acceptance_authorized", true))
		and not bool(policy.get("encyclopedia_admission_authorized", true))
		and not bool(policy.get("automatic_creature_guidance_allowed", true))
	)
	var cohort_features := CampaignScript._gq14_candidate34_cohort_feature_results()
	var realized_cohort_ids: Array = []
	var cohort_features_exact := cohort_features.size() == 32
	for feature_value in cohort_features:
		var feature: Dictionary = feature_value
		var receipt: Dictionary = feature.get("feature_receipt", {})
		realized_cohort_ids.append(String(receipt.get("morphology_id", "")))
		cohort_features_exact = (
			cohort_features_exact
			and bool(feature.get("ok", false))
			and int(feature.get("world_build_count", -1)) == 0
			and String(receipt.get("schema_version", ""))
			== FeatureReceiptScript.SCHEMA_VERSION
			and String(receipt.get("policy_id", ""))
			== FeatureReceiptScript.POLICY_ID
			and String(feature.get("feature_receipt_sha256", ""))
			== CanonicalJsonScript.sha256(receipt)
		)
	cohort_features_exact = (
		cohort_features_exact
		and realized_cohort_ids == CoverageReceiptScript.GQ14_COHORT_IDS
	)
	var query_features := _gq14_query_feature_results(cells, compiled_cells)
	var coverage_exact := (
		query_features.size() == 20
		and cohort_features.size() == 32
	)
	var coverage_results: Array = []
	if coverage_exact:
		for query_value in query_features:
			coverage_results.append(
				CoverageReceiptScript.compile_gq14(
					cohort_features,
					query_value,
				)
			)
	for coverage_index in range(coverage_results.size()):
		var coverage: Dictionary = coverage_results[coverage_index]
		var receipt: Dictionary = coverage.get("coverage_receipt", {})
		coverage_exact = (
			coverage_exact
			and bool(coverage.get("ok", false))
			and int(coverage.get("world_build_count", -1)) == 0
			and String(receipt.get("schema_version", ""))
			== CoverageReceiptScript.GQ14_SCHEMA_VERSION
			and String(receipt.get("policy_id", ""))
			== CoverageReceiptScript.GQ14_POLICY_ID
			and String(receipt.get("claim_level", ""))
			== CoverageReceiptScript.GQ14_CLAIM_LEVEL
			and String(receipt.get("candidate34_source_sha256", ""))
			== CoverageReceiptScript.CANDIDATE34_SOURCE_SHA256
			and (receipt.get("ordered_cohort_member_ids", []) as Array)
			== CoverageReceiptScript.GQ14_COHORT_IDS
			and _coverage_math_exact(
				coverage,
				cohort_features,
				query_features[coverage_index],
			)
			and not bool(receipt.get("controller_branch_authority", true))
			and not bool(receipt.get("physical_acceptance_authority", true))
			and not bool(receipt.get("formal_milestone_acceptance_authorized", true))
		)
	if coverage_results.size() == 20:
		var first_coverage: Dictionary = coverage_results[0]
		var verified_coverage := CoverageReceiptScript.verify_gq14(
			cohort_features,
			query_features[0],
			String(first_coverage.get("coverage_receipt_sha256", "")),
		)
		var reversed_cohort := cohort_features.duplicate(true)
		reversed_cohort.reverse()
		var wrong_order := CoverageReceiptScript.compile_gq14(
			reversed_cohort,
			query_features[0],
		)
		var short_cohort := CoverageReceiptScript.compile_gq14(
			cohort_features.slice(0, 31),
			query_features[0],
		)
		coverage_exact = (
			coverage_exact
			and bool(verified_coverage.get("ok", false))
			and int(verified_coverage.get("world_build_count", -1)) == 0
			and not bool(wrong_order.get("ok", true))
			and not bool(short_cohort.get("ok", true))
			and CoverageReceiptScript.classify_distance(2.0, 2.0, 4.0)
			== "SUPPORTED"
			and CoverageReceiptScript.classify_distance(4.0, 2.0, 4.0)
			== "EDGE"
			and CoverageReceiptScript.classify_distance(4.000001, 2.0, 4.0)
			== "OUT_OF_DISTRIBUTION"
		)
	return {
		"population_exact": population_exact,
		"generation_exact": generation_exact,
		"fixtures_exact": fixtures_exact,
		"controllers_exact": controllers_exact,
		"velocity_boundaries_exact": velocity_boundaries_exact,
		"anchor_guard_exact": anchor_guard_exact,
		"numerics_exact": numerics_exact,
		"policy_and_preservation_exact": policy_and_preservation_exact,
		"cohort_features_exact": cohort_features_exact,
		"coverage_exact": coverage_exact,
		"support_sets_exact": _gq14_support_sets_exact(),
		"runtime_profile_exact": _gq14_runtime_profile_exact(),
	}


static func _gq14_support_sets_exact() -> bool:
	var sample_results := [
		DynamicSupportReceiptScript.compile_sample_gq14(
			10,
			"SETTLE_BOUNDARY",
			["front_left"],
			_synthetic_support_observer(0, -0.10, -0.20),
			0.0,
		),
		DynamicSupportReceiptScript.compile_sample_gq14(
			11,
			"EVIDENCE",
			["front_left", "front_right"],
			_synthetic_support_observer(1, -0.05, -0.08),
			0.4,
		),
		DynamicSupportReceiptScript.compile_sample_gq14(
			12,
			"TERMINAL_SETTLE",
			["front_left", "front_right", "rear_left"],
			_synthetic_support_observer(2, 0.10, 0.05),
			1.1,
		),
	]
	var samples: Array = []
	for result_value in sample_results:
		var result: Dictionary = result_value
		if not bool(result.get("ok", false)) or int(result.get("world_build_count", -1)) != 0:
			return false
		samples.append(result["sample"])
	var valid_digest := "sha256:%064d" % 0
	var metadata := {
		"contact_progression_timeout": false,
		"evidence_extension_ticks": 7,
		"maximum_anchor_error_tick": 11,
		"final_support_contact_state":
		{
			"front_left": true,
			"front_right": true,
			"rear_left": true,
			"rear_right": true,
		},
		"lateral_limit_m": 1.0,
		"source_digests": {"synthetic_source_sha256": valid_digest},
	}
	var aggregate := DynamicSupportReceiptScript.compile_gq14(samples, metadata)
	if not bool(aggregate.get("ok", false)):
		return false
	var receipt: Dictionary = aggregate["dynamic_support_receipt"]
	var digest := String(aggregate["dynamic_support_receipt_sha256"])
	var verified := DynamicSupportReceiptScript.verify_gq14(
		samples,
		metadata,
		digest,
	)
	var empty := DynamicSupportReceiptScript.compile_sample_gq14(
		13,
		"EVIDENCE",
		[],
		{
			"ok": false,
			"failure_code": "SPATIAL_DYNAMIC_SUPPORT_SET_EMPTY",
			"world_build_count": 0,
		},
		0.0,
	)
	var mismatched_dimension := DynamicSupportReceiptScript.compile_sample_gq14(
		13,
		"EVIDENCE",
		["front_left"],
		_synthetic_support_observer(1, -0.1, -0.1),
		0.0,
	)
	var unordered := DynamicSupportReceiptScript.compile_sample_gq14(
		13,
		"EVIDENCE",
		["rear_left", "front_left"],
		_synthetic_support_observer(1, -0.1, -0.1),
		0.0,
	)
	var nonfinite_observer := _synthetic_support_observer(0, -0.1, -0.1)
	nonfinite_observer["center_of_mass_margin_m"] = NAN
	var nonfinite := DynamicSupportReceiptScript.compile_sample_gq14(
		13,
		"EVIDENCE",
		["front_left"],
		nonfinite_observer,
		0.0,
	)
	var reversed := samples.duplicate(true)
	reversed.reverse()
	var bad_order := DynamicSupportReceiptScript.compile_gq14(reversed, metadata)
	var bad_digest := digest.left(70) + ("0" if digest.right(1) != "0" else "1")
	var bad_verify := DynamicSupportReceiptScript.verify_gq14(
		samples,
		metadata,
		bad_digest,
	)
	return (
		String(receipt.get("schema_version", ""))
		== DynamicSupportReceiptScript.GQ14_SCHEMA_VERSION
		and String(receipt.get("policy_id", ""))
		== DynamicSupportReceiptScript.GQ14_POLICY_ID
		and (
			(receipt.get("support_geometry_sample_count_by_dimension", {}) as Dictionary)
			== {"0": 1, "1": 1, "2": 1}
		)
		and int(receipt.get("sample_count_dimensionless", -1)) == 3
		and digest == CanonicalJsonScript.sha256(receipt)
		and bool(verified.get("ok", false))
		and int(verified.get("world_build_count", -1)) == 0
		and String(receipt.get("policy_response", ""))
		== DynamicSupportReceiptScript.POLICY_RESPONSE
		and not bool(receipt.get("controller_authority", true))
		and not bool(receipt.get("walker_predicate_authority", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
		and not bool(empty.get("ok", true))
		and String(empty.get("failure_code", ""))
		== "DYNAMIC_SUPPORT_OBSERVER_FAILURE:SPATIAL_DYNAMIC_SUPPORT_SET_EMPTY"
		and not bool(mismatched_dimension.get("ok", true))
		and String(mismatched_dimension.get("failure_code", ""))
		== "DYNAMIC_SUPPORT_SAMPLE_SUPPORT_SET_IDENTITY_INVALID"
		and not bool(unordered.get("ok", true))
		and not bool(nonfinite.get("ok", true))
		and not bool(bad_order.get("ok", true))
		and not bool(bad_verify.get("ok", true))
	)


static func _gq14_runtime_profile_exact() -> bool:
	var digest := "sha256:%064d" % 0
	var requested := {
		"enabled": true,
		"lateral_limit_m": 0.1,
		"source_digests": {"synthetic_source_sha256": digest},
		"receipt_schema_version": DynamicSupportReceiptScript.GQ14_SCHEMA_VERSION,
		"policy_id": DynamicSupportReceiptScript.GQ14_POLICY_ID,
		"sample_schema_version":
		DynamicSupportReceiptScript.GQ14_SAMPLE_SCHEMA_VERSION,
	}
	var normalized := WaveGaitScript._normalize_dynamic_support_diagnostic_options(
		requested
	)
	var wrong_profile := requested.duplicate(true)
	wrong_profile["policy_id"] = DynamicSupportReceiptScript.POLICY_ID
	var rejected := WaveGaitScript._normalize_dynamic_support_diagnostic_options(
		wrong_profile
	)
	var legacy := WaveGaitScript._normalize_dynamic_support_diagnostic_options(
		{
			"enabled": true,
			"lateral_limit_m": 0.1,
			"source_digests": {"synthetic_source_sha256": digest},
		}
	)
	var runner_text := FileAccess.get_file_as_string(
		"res://scripts/run_br14a_nonuniform_proportion_probe.ps1"
	)
	return (
		bool(normalized.get("ok", false))
		and int(normalized.get("world_build_count", -1)) == 0
		and (
			(normalized.get("dynamic_support_diagnostic_options", {}) as Dictionary)
			== requested
		)
		and not bool(rejected.get("ok", true))
		and int(rejected.get("world_build_count", -1)) == 0
		and bool(legacy.get("ok", false))
		and String(
			(
				legacy.get("dynamic_support_diagnostic_options", {}) as Dictionary
			).get("receipt_schema_version", "unexpected")
		).is_empty()
		and runner_text.contains('"G4-GQ14"')
		and runner_text.contains("gq14_generated_s145")
		and runner_text.contains("gq14_generated_s1308")
		and runner_text.contains(
			"sporespore_br14a_nonuniform_proportion_probe_report_v19"
		)
		and runner_text.contains("gq14_complete = $false")
	)


static func _expected_gq15_generation(
	generator_index: int,
	campaign_role: String,
) -> Dictionary:
	var predecessor := _expected_gq14_generation(generator_index, campaign_role)
	var proportion_spec: Dictionary = (
		predecessor["proportion_spec"] as Dictionary
	).duplicate(true)
	proportion_spec["morphology_id"] = "gq15_generated_s%03d" % generator_index
	var generator_receipt: Dictionary = (
		predecessor["generator_receipt"] as Dictionary
	).duplicate(true)
	generator_receipt["schema_version"] = (
		ProportionSpecScript.GQ15_GENERATOR_SCHEMA_VERSION
	)
	generator_receipt["generator_policy_id"] = (
		ProportionSpecScript.GQ15_GENERATOR_POLICY_ID
	)
	generator_receipt["campaign_id"] = ProportionSpecScript.CAMPAIGN_GQ15
	generator_receipt["proportion_spec"] = proportion_spec.duplicate(true)
	return {
		"proportion_spec": proportion_spec,
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
	}


static func _test_gq15_velocity(
	score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	foot_radius_scale: float,
	yaw_gain: float,
) -> float:
	if (
		yaw_gain <= 1.0
		and score >= 0.5
		and torso_length_scale < 1.0
		and torso_width_scale > 1.0
	):
		var interaction_fraction := clampf((score - 0.5) / 0.5, 0.0, 1.0)
		var wide_fraction := clampf((torso_width_scale - 1.02) / 0.04, 0.0, 1.0)
		return (
			0.25
			+ 0.025 * interaction_fraction
			+ 0.025 * interaction_fraction * wide_fraction
		)
	return _test_gq14_velocity(
		score,
		torso_length_scale,
		torso_width_scale,
		foot_radius_scale,
		yaw_gain,
	)


static func _gq15_query_feature_results(
	cells: Array,
	compiled_cells: Array,
) -> Array:
	if cells.size() != compiled_cells.size():
		return []
	var clock_result := ClockSpecScript.compile(ClockSpecScript.gq15_clock())
	var solver_result := WaveGaitScript.compile_solver_policy_options(
		CampaignScript.GP4_SOLVER_POLICY_OPTIONS
	)
	if not bool(clock_result.get("ok", false)) or not bool(solver_result.get("ok", false)):
		return []
	var clock: Dictionary = clock_result["gait_clock_options"]
	var solver: Dictionary = solver_result["solver_policy_options"]
	var indices: Array = (
		ProportionSpecScript.GQ15_SELECTION_INDICES
		+ ProportionSpecScript.GQ15_HELD_OUT_INDICES
	)
	var results: Array = []
	for cell_index in range(cells.size()):
		var cell: Dictionary = cells[cell_index]
		var generation := ProportionSpecScript.compile_gq15_generation(
			int(indices[cell_index])
		)
		var controller_digest := CampaignScript._expected_controller_sha256(
			CampaignScript.CAMPAIGN_GQ15,
			CampaignScript._motor_velocity_options(
				CampaignScript.CAMPAIGN_GQ15,
				cell,
			),
			CampaignScript._path_steering_options(
				CampaignScript.CAMPAIGN_GQ15,
				cell,
			),
		)
		var feature := FeatureReceiptScript.compile(
			generation,
			compiled_cells[cell_index],
			controller_digest,
			clock,
			solver,
		)
		if not bool(feature.get("ok", false)):
			return []
		results.append(feature)
	return results


static func _gq15_contract(
	selection: Array,
	held_out: Array,
	compiled_cells: Array,
) -> Dictionary:
	var cells := selection + held_out
	var expected_selection_ids: Array = []
	for generator_index in range(157, 169):
		expected_selection_ids.append("gq15_generated_s%03d" % generator_index)
	var expected_heldout_ids: Array = []
	for generator_index in range(1401, 1409):
		expected_heldout_ids.append("gq15_generated_s%03d" % generator_index)
	var realized_selection_ids: Array = []
	var realized_heldout_ids: Array = []
	for cell_value in selection:
		realized_selection_ids.append(String((cell_value as Dictionary)["morphology_id"]))
	for cell_value in held_out:
		realized_heldout_ids.append(String((cell_value as Dictionary)["morphology_id"]))
	var population_exact := (
		selection.size() == 12
		and held_out.size() == 8
		and realized_selection_ids == expected_selection_ids
		and realized_heldout_ids == expected_heldout_ids
		and ProportionSpecScript.GQ15_SELECTION_INDICES
		== [157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168]
		and ProportionSpecScript.GQ15_HELD_OUT_INDICES
		== [1401, 1402, 1403, 1404, 1405, 1406, 1407, 1408]
	)
	var indices: Array = (
		ProportionSpecScript.GQ15_SELECTION_INDICES
		+ ProportionSpecScript.GQ15_HELD_OUT_INDICES
	)
	var generation_exact := population_exact and cells.size() == 20
	var generation_digests: Dictionary = {}
	for cell_index in range(indices.size()):
		var generator_index := int(indices[cell_index])
		var role := "selection" if cell_index < selection.size() else "heldout"
		var cell: Dictionary = cells[cell_index]
		var expected := _expected_gq15_generation(generator_index, role)
		var realized := ProportionSpecScript.compile_gq15_generation(generator_index)
		var digest := String(realized.get("generator_receipt_sha256", ""))
		var verified := ProportionSpecScript.verify_gq15_generation(
			generator_index,
			digest,
		)
		var reverse := ProportionSpecScript.gq15_generation_for_morphology(
			String(cell["morphology_id"]),
			role,
		)
		generation_exact = (
			generation_exact
			and bool(realized.get("ok", false))
			and int(realized.get("world_build_count", -1)) == 0
			and realized.get("proportion_spec", {}) == cell
			and realized.get("proportion_spec", {}) == expected["proportion_spec"]
			and realized.get("generator_receipt", {}) == expected["generator_receipt"]
			and digest == String(expected["generator_receipt_sha256"])
			and bool(verified.get("ok", false))
			and int(verified.get("world_build_count", -1)) == 0
			and reverse.get("proportion_spec", {}) == cell
		)
		generation_digests[digest] = true
	var first_generation := ProportionSpecScript.compile_gq15_generation(157)
	var first_digest := String(first_generation.get("generator_receipt_sha256", ""))
	var bad_digest := first_digest.left(70) + (
		"0" if first_digest.right(1) != "0" else "1"
	)
	generation_exact = (
		generation_exact
		and generation_digests.size() == 20
		and not generation_digests.has("")
		and not bool(ProportionSpecScript.compile_gq15_generation(157.0).get("ok", true))
		and not bool(ProportionSpecScript.compile_gq15_generation(156).get("ok", true))
		and not bool(
			ProportionSpecScript.verify_gq15_generation(157, bad_digest).get("ok", true)
		)
		and not bool(
			ProportionSpecScript.gq15_generation_for_morphology(
				"gq15_generated_s157",
				"heldout",
			).get("ok", true)
		)
	)

	var fixtures_exact := (
		compiled_cells.size() == 20
		and _all_fixture_formulas_exact(cells, compiled_cells)
		and _all_mass_and_reach_invariants_exact(compiled_cells)
		and _all_static_screens_exact(compiled_cells)
		and _all_receipts_distinct(compiled_cells)
	)
	for compiled_value in compiled_cells:
		fixtures_exact = (
			fixtures_exact
			and bool((compiled_value as Dictionary).get("ok", false))
			and int((compiled_value as Dictionary).get("world_build_count", -1)) == 0
		)

	var controllers_exact := true
	var controller_digests: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var motor := CampaignScript._motor_velocity_options(
			CampaignScript.CAMPAIGN_GQ15,
			cell,
		)
		var path := CampaignScript._path_steering_options(
			CampaignScript.CAMPAIGN_GQ15,
			cell,
		)
		var expected_controller := CampaignScript._expected_controller_sha256(
			CampaignScript.CAMPAIGN_GQ15,
			motor,
			path,
		)
		var direct_controller := CampaignScript._candidate35_controller_sha256(
			cell,
			ClockSpecScript.gq15_clock(),
			CampaignScript.GQ15_ROBUSTNESS_OPTIONS,
		)
		controllers_exact = (
			controllers_exact
			and expected_controller == direct_controller
			and expected_controller.begins_with("sha256:")
			and expected_controller.length() == 71
			and is_equal_approx(
				float(path["cross_track_velocity_heading_gain_rad_per_m_s"]),
				_test_gq15_velocity(
					CampaignScript._morphology_interaction_score(cell),
					float(cell["torso_length_scale"]),
					float(cell["torso_width_scale"]),
					float(cell["foot_radius_scale"]),
					float(path["yaw_error_stride_gain_per_rad"]),
				),
			)
		)
		controller_digests[expected_controller] = true
	controllers_exact = controllers_exact and controller_digests.size() >= 2

	var velocity_boundaries_exact := true
	var velocity_cases := [
		[0.50, 0.99, 1.0001, 1.0, 1.0],
		[0.75, 0.99, 1.02, 1.0, 1.0],
		[0.75, 0.99, 1.04, 1.0, 1.0],
		[1.00, 0.99, 1.06, 1.0, 1.0],
		[0.75, 0.99, 1.00, 1.0, 1.0],
		[0.75, 1.00, 1.04, 1.0, 1.0],
		[0.49, 0.99, 1.04, 1.0, 1.0],
		[0.75, 0.99, 1.04, 1.03, 1.1],
	]
	for case_value in velocity_cases:
		var c: Array = case_value
		velocity_boundaries_exact = (
			velocity_boundaries_exact
			and is_equal_approx(
				CampaignScript._gq15_velocity_gain_rad_per_m_s(
					float(c[0]),
					float(c[1]),
					float(c[2]),
					float(c[3]),
					float(c[4]),
				),
				_test_gq15_velocity(
					float(c[0]),
					float(c[1]),
					float(c[2]),
					float(c[3]),
					float(c[4]),
				),
			)
		)
	velocity_boundaries_exact = (
		velocity_boundaries_exact
		and is_equal_approx(
			CampaignScript._gq15_velocity_gain_rad_per_m_s(0.50, 0.99, 1.0001, 1.0, 1.0),
			0.25,
		)
		and is_equal_approx(
			CampaignScript._gq15_velocity_gain_rad_per_m_s(0.75, 0.99, 1.02, 1.0, 1.0),
			0.2625,
		)
		and is_equal_approx(
			CampaignScript._gq15_velocity_gain_rad_per_m_s(0.75, 0.99, 1.04, 1.0, 1.0),
			0.26875,
		)
		and is_equal_approx(
			CampaignScript._gq15_velocity_gain_rad_per_m_s(1.0, 0.99, 1.06, 1.0, 1.0),
			0.30,
		)
	)

	var guard_cell := ProportionSpecScript.reference_parameters()
	guard_cell["torso_length_scale"] = 1.05
	guard_cell["torso_width_scale"] = 0.94
	var anchor_guard_exact := (
		CampaignScript._gq15_motor_guard_values(0.5, guard_cell) == [0.70, 1.75]
	)
	guard_cell["torso_width_scale"] = 1.01
	anchor_guard_exact = (
		anchor_guard_exact
		and CampaignScript._gq15_motor_guard_values(0.5, guard_cell) == [0.70, 1.75]
	)
	guard_cell["torso_width_scale"] = 0.95
	anchor_guard_exact = (
		anchor_guard_exact
		and CampaignScript._gq15_motor_guard_values(0.5, guard_cell) == [0.80, 2.0]
	)
	guard_cell["torso_width_scale"] = 1.0
	anchor_guard_exact = (
		anchor_guard_exact
		and CampaignScript._gq15_motor_guard_values(0.5, guard_cell) == [0.80, 2.0]
	)
	guard_cell["torso_width_scale"] = 1.01
	guard_cell["torso_length_scale"] = 1.04
	anchor_guard_exact = (
		anchor_guard_exact
		and CampaignScript._gq15_motor_guard_values(0.5, guard_cell) == [0.80, 2.0]
	)
	guard_cell["torso_length_scale"] = 1.05
	anchor_guard_exact = (
		anchor_guard_exact
		and CampaignScript._gq15_motor_guard_values(0.499999, guard_cell) == [0.90, 2.5]
	)

	var clock15_result := ClockSpecScript.compile(ClockSpecScript.gq15_clock())
	var clock14_result := ClockSpecScript.compile(ClockSpecScript.gq14_clock())
	var solver_result := WaveGaitScript.compile_solver_policy_options(
		CampaignScript.GP4_SOLVER_POLICY_OPTIONS
	)
	var clock15: Dictionary = clock15_result.get("gait_clock_options", {})
	var clock14: Dictionary = clock14_result.get("gait_clock_options", {})
	var clock15_numeric := clock15.duplicate(true)
	var clock14_numeric := clock14.duplicate(true)
	clock15_numeric.erase("policy_id")
	clock14_numeric.erase("policy_id")
	var first_fixture: Dictionary = (
		(compiled_cells[0] as Dictionary).get("fixture_spec", {})
		if not compiled_cells.is_empty()
		else {}
	)
	var thresholds := CampaignScript._evidence_thresholds(
		first_fixture,
		CampaignScript.CAMPAIGN_GQ15,
	)
	var numerics_exact: bool = (
		bool(clock15_result.get("ok", false))
		and int(clock15_result.get("world_build_count", -1)) == 0
		and String(clock15.get("policy_id", "")) == ClockSpecScript.GQ15_POLICY_ID
		and clock15_numeric == clock14_numeric
		and bool(solver_result.get("ok", false))
		and solver_result.get("solver_policy_options", {})
		== CampaignScript.GP4_SOLVER_POLICY_OPTIONS
		and is_equal_approx(
			float(thresholds["minimum_foot_relocation_m"]),
			0.0238 * float(((first_fixture["torso"] as Dictionary)["size_m"] as Array)[0]),
		)
		and is_equal_approx(
			float(thresholds["maximum_anchor_error_m"]),
			0.14 * float((((first_fixture["limbs"] as Array)[0] as Dictionary)["upper_length_m"])),
		)
	)

	var policy13 := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ13)
	var policy14 := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ14)
	var policy15 := CampaignScript._formula_policy(CampaignScript.CAMPAIGN_GQ15)
	var policy_and_preservation_exact := (
		CanonicalJsonScript.sha256(policy13)
		== "sha256:5e2eb3092479ad7c8b979d24e11fde4d9748e9374c142782ca8160085c15d7a4"
		and CanonicalJsonScript.sha256(policy14)
		== "sha256:b121d0e7adc24ef239c213cbb8da69bacf42a9b7d5fb634c8f2e1e41182d7291"
		and String(policy15.get("schema_version", ""))
		== "sporespore_g4_gq15_candidate35_opened_matrix_policy_v1"
		and String(policy15.get("campaign_id", "")) == CampaignScript.CAMPAIGN_GQ15
		and String(policy15.get("generator_policy_id", ""))
		== ProportionSpecScript.GQ15_GENERATOR_POLICY_ID
		and String(policy15.get("clock_policy_id", "")) == ClockSpecScript.GQ15_POLICY_ID
		and String(policy15.get("feature_policy_id", ""))
		== FeatureReceiptScript.GQ15_POLICY_ID
		and String(policy15.get("coverage_policy_id", ""))
		== CoverageReceiptScript.GQ15_POLICY_ID
		and String(policy15.get("candidate35_source_sha256", ""))
		== CoverageReceiptScript.CANDIDATE35_SOURCE_SHA256
		and String(policy15.get("dynamic_support_policy_id", ""))
		== DynamicSupportReceiptScript.GQ15_POLICY_ID
		and String(policy15.get("report_schema_version", ""))
		== "sporespore_br14a_nonuniform_proportion_probe_report_v20"
		and not bool(policy15.get("formal_milestone_acceptance_authorized", true))
		and not bool(policy15.get("encyclopedia_admission_authorized", true))
		and not bool(policy15.get("automatic_creature_guidance_allowed", true))
	)

	var cohort := CampaignScript._gq15_candidate35_cohort_feature_results()
	var cohort_ids: Array = []
	var cohort_features_exact := cohort.size() == 56
	for feature_value in cohort:
		var feature: Dictionary = feature_value
		var receipt: Dictionary = feature.get("feature_receipt", {})
		cohort_ids.append(String(receipt.get("morphology_id", "")))
		cohort_features_exact = (
			cohort_features_exact
			and bool(feature.get("ok", false))
			and int(feature.get("world_build_count", -1)) == 0
			and String(feature.get("feature_receipt_sha256", ""))
			== CanonicalJsonScript.sha256(receipt)
		)
	cohort_features_exact = (
		cohort_features_exact
		and cohort_ids == CoverageReceiptScript.GQ15_COHORT_IDS
	)

	var query_features := _gq15_query_feature_results(cells, compiled_cells)
	var coverage_exact := cohort_features_exact and query_features.size() == 20
	var coverage_digests: Dictionary = {}
	for query_feature_value in query_features:
		var query_feature: Dictionary = query_feature_value
		var coverage := CoverageReceiptScript.compile_gq15(cohort, query_feature)
		var coverage_receipt: Dictionary = coverage.get("coverage_receipt", {})
		var coverage_digest := String(coverage.get("coverage_receipt_sha256", ""))
		var verified := CoverageReceiptScript.verify_gq15(
			cohort,
			query_feature,
			coverage_digest,
		)
		coverage_exact = (
			coverage_exact
			and bool(coverage.get("ok", false))
			and int(coverage.get("world_build_count", -1)) == 0
			and bool(verified.get("ok", false))
			and coverage_digest == CanonicalJsonScript.sha256(coverage_receipt)
			and String(coverage_receipt.get("schema_version", ""))
			== CoverageReceiptScript.GQ15_SCHEMA_VERSION
			and String(coverage_receipt.get("policy_id", ""))
			== CoverageReceiptScript.GQ15_POLICY_ID
			and String(coverage_receipt.get("claim_level", ""))
			== CoverageReceiptScript.GQ15_CLAIM_LEVEL
			and String(coverage_receipt.get("candidate35_source_sha256", ""))
			== CoverageReceiptScript.CANDIDATE35_SOURCE_SHA256
			and not bool(coverage_receipt.get("controller_branch_authority", true))
			and not bool(coverage_receipt.get("physical_acceptance_authority", true))
			and not bool(
				coverage_receipt.get("formal_milestone_acceptance_authorized", true)
			)
		)
		coverage_digests[coverage_digest] = true
	coverage_exact = (
		coverage_exact
		and coverage_digests.size() == 20
		and not coverage_digests.has("")
	)

	return {
		"population_exact": population_exact,
		"generation_exact": generation_exact,
		"fixtures_exact": fixtures_exact,
		"controllers_exact": controllers_exact,
		"velocity_boundaries_exact": velocity_boundaries_exact,
		"anchor_guard_exact": anchor_guard_exact,
		"numerics_exact": numerics_exact,
		"policy_and_preservation_exact": policy_and_preservation_exact,
		"cohort_features_exact": cohort_features_exact,
		"coverage_exact": coverage_exact,
		"support_sets_exact": _gq15_support_sets_exact(),
		"runtime_profile_exact": _gq15_runtime_profile_exact(),
	}


static func _gq15_support_sets_exact() -> bool:
	var active_ids_by_dimension := [
		["front_left"],
		["front_left", "front_right"],
		["front_left", "front_right", "rear_left"],
	]
	var samples: Array = []
	for dimension in range(3):
		var sample_result := DynamicSupportReceiptScript.compile_sample_gq15(
			dimension + 1,
			"EVIDENCE",
			active_ids_by_dimension[dimension],
			_synthetic_support_observer(dimension, 0.10 - 0.01 * dimension, 0.08),
			0.01 * dimension,
		)
		if not bool(sample_result.get("ok", false)):
			return false
		samples.append(sample_result["sample"])
	var metadata := {
		"contact_progression_timeout": false,
		"evidence_extension_ticks": 0,
		"maximum_anchor_error_tick": 2,
		"final_support_contact_state": {"front_left": true},
		"lateral_limit_m": 0.1,
		"source_digests": {"synthetic_source_sha256": "sha256:%064d" % 0},
	}
	var compiled := DynamicSupportReceiptScript.compile_gq15(samples, metadata)
	var digest := String(compiled.get("dynamic_support_receipt_sha256", ""))
	var verified := DynamicSupportReceiptScript.verify_gq15(samples, metadata, digest)
	var bad_digest := digest.left(70) + ("0" if digest.right(1) != "0" else "1")
	var tampered_samples := samples.duplicate(true)
	(tampered_samples[0] as Dictionary)["schema_version"] = "tampered"
	var tampered := DynamicSupportReceiptScript.compile_gq15(tampered_samples, metadata)
	var receipt: Dictionary = compiled.get("dynamic_support_receipt", {})
	return (
		bool(compiled.get("ok", false))
		and int(compiled.get("world_build_count", -1)) == 0
		and bool(verified.get("ok", false))
		and not bool(
			DynamicSupportReceiptScript.verify_gq15(samples, metadata, bad_digest).get(
				"ok",
				true,
			)
		)
		and not bool(tampered.get("ok", true))
		and String(receipt.get("schema_version", ""))
		== DynamicSupportReceiptScript.GQ15_SCHEMA_VERSION
		and String(receipt.get("policy_id", ""))
		== DynamicSupportReceiptScript.GQ15_POLICY_ID
		and digest == CanonicalJsonScript.sha256(receipt)
		and (
			receipt.get("support_geometry_sample_count_by_dimension", {}) as Dictionary
		) == {"0": 1, "1": 1, "2": 1}
		and not bool(receipt.get("controller_authority", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
	)


static func _gq15_runtime_profile_exact() -> bool:
	var digest := "sha256:%064d" % 0
	var requested := {
		"enabled": true,
		"lateral_limit_m": 0.1,
		"source_digests": {"synthetic_source_sha256": digest},
		"receipt_schema_version": DynamicSupportReceiptScript.GQ15_SCHEMA_VERSION,
		"policy_id": DynamicSupportReceiptScript.GQ15_POLICY_ID,
		"sample_schema_version":
		DynamicSupportReceiptScript.GQ15_SAMPLE_SCHEMA_VERSION,
	}
	var normalized := WaveGaitScript._normalize_dynamic_support_diagnostic_options(
		requested
	)
	var wrong_profile := requested.duplicate(true)
	wrong_profile["policy_id"] = DynamicSupportReceiptScript.GQ14_POLICY_ID
	var rejected := WaveGaitScript._normalize_dynamic_support_diagnostic_options(
		wrong_profile
	)
	var runner_text := FileAccess.get_file_as_string(
		"res://scripts/run_br14a_nonuniform_proportion_probe.ps1"
	)
	return (
		bool(normalized.get("ok", false))
		and int(normalized.get("world_build_count", -1)) == 0
		and (
			(normalized.get("dynamic_support_diagnostic_options", {}) as Dictionary)
			== requested
		)
		and not bool(rejected.get("ok", true))
		and int(rejected.get("world_build_count", -1)) == 0
		and runner_text.contains('"G4-GQ15"')
		and runner_text.contains("gq15_generated_s157")
		and runner_text.contains("gq15_generated_s1408")
		and runner_text.contains(
			"sporespore_br14a_nonuniform_proportion_probe_report_v20"
		)
		and runner_text.contains("gq15_complete = $false")
	)


static func _all_receipts_distinct(compiled_cells: Array) -> bool:
	for key_value in [
		"proportion_spec_sha256",
		"fixture_spec_sha256",
		"static_screen_sha256",
	]:
		var digests: Dictionary = {}
		for compiled_value in compiled_cells:
			var compiled: Dictionary = compiled_value
			digests[String(compiled[key_value])] = true
		if digests.size() != compiled_cells.size():
			return false
	return true


static func _fails_without_world(requested: Dictionary, failure_code: String) -> bool:
	var result := ProportionSpecScript.compile(requested)
	return (
		not bool(result.get("ok", true))
		and String(result.get("failure_code", "")) == failure_code
		and int(result.get("world_build_count", -1)) == 0
	)


static func _all_tampered_receipts_fail(
	parameters: Dictionary,
	compiled: Dictionary,
) -> bool:
	var digests := [
		String(compiled["proportion_spec_sha256"]),
		String(compiled["fixture_spec_sha256"]),
		String(compiled["static_screen_sha256"]),
	]
	for index in range(3):
		var requested_digests := digests.duplicate()
		var original := String(requested_digests[index])
		var replacement := "0" if original.right(1) != "0" else "1"
		requested_digests[index] = original.left(70) + replacement
		var result := (
			ProportionSpecScript
			. verify(
				parameters,
				String(requested_digests[0]),
				String(requested_digests[1]),
				String(requested_digests[2]),
			)
		)
		if (
			bool(result.get("ok", true))
			or String(result.get("failure_code", "")) != "PROPORTION_RECEIPT_DIGEST_MISMATCH"
			or int(result.get("world_build_count", -1)) != 0
		):
			return false
	return true


static func _all_true(values: Dictionary) -> bool:
	if values.is_empty():
		return false
	for value in values.values():
		if typeof(value) != TYPE_BOOL or not bool(value):
			return false
	return true


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", description)
	else:
		_failed += 1
		print("  FAIL  ", description)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
