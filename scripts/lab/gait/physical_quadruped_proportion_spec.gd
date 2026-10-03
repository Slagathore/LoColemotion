class_name LabPhysicalQuadrupedProportionSpec
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Fail-closed G3 nonuniform quadruped morphology compiler.
##
## The compiler owns the preregistered cell grid, derives an ordinary
## LabPhysicalQuadrupedFixtureSpec, and performs the complete no-world static
## construction screen before the physical walker can create a viewport.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")

const SCHEMA_VERSION := "sporespore_physical_quadruped_proportion_spec_v1"
const STATIC_SCREEN_SCHEMA_VERSION := "sporespore_quadruped_static_screen_v1"
const POLICY_ID := "g3_gp1_independent_proportions_v1"
const CAMPAIGN_GP1 := "G3-GP1"
const CAMPAIGN_GP2 := "G3-GP2"
const CAMPAIGN_GP3 := "G3-GP3"
const CAMPAIGN_GP4 := "G3-GP4"
const CAMPAIGN_GP5 := "G3-GP5"
const CAMPAIGN_GQ1 := "G4-GQ1"
const CAMPAIGN_GQ2 := "G4-GQ2"
const CAMPAIGN_GQ3 := "G4-GQ3"
const CAMPAIGN_GQ4 := "G4-GQ4"
const CAMPAIGN_GQ5 := "G4-GQ5"
const CAMPAIGN_GQ6 := "G4-GQ6"
const CAMPAIGN_GQ7 := "G4-GQ7"
const CAMPAIGN_GQ8 := "G4-GQ8"
const CAMPAIGN_GQ9 := "G4-GQ9"
const CAMPAIGN_GQ10 := "G4-GQ10"
const CAMPAIGN_GQ11 := "G4-GQ11"
const CAMPAIGN_GQ12 := "G4-GQ12"
const CAMPAIGN_GQ13 := "G4-GQ13"
const CAMPAIGN_GQ14 := "G4-GQ14"
const CAMPAIGN_GQ15 := "G4-GQ15"
const GQ1_GENERATOR_POLICY_ID := "g4_gq1_radical_inverse_piecewise_shell_v1"
const GQ1_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq1_generation_receipt_v1"
const GQ1_SELECTION_INDICES := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const GQ1_HELD_OUT_INDICES := [101, 102, 103, 104, 105, 106, 107, 108]
const GQ2_GENERATOR_POLICY_ID := "g4_gq2_radical_inverse_piecewise_shell_v1"
const GQ2_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq2_generation_receipt_v1"
const GQ2_SELECTION_INDICES := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const GQ2_HELD_OUT_INDICES := [101, 102, 103, 104, 105, 106, 107, 108]
const GQ3_GENERATOR_POLICY_ID := "g4_gq3_radical_inverse_piecewise_shell_v1"
const GQ3_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq3_generation_receipt_v1"
const GQ3_SELECTION_INDICES := [13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]
const GQ3_HELD_OUT_INDICES := [201, 202, 203, 204, 205, 206, 207, 208]
const GQ4_GENERATOR_POLICY_ID := "g4_gq4_radical_inverse_piecewise_shell_v1"
const GQ4_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq4_generation_receipt_v1"
const GQ4_SELECTION_INDICES := [25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36]
const GQ4_HELD_OUT_INDICES := [301, 302, 303, 304, 305, 306, 307, 308]
const GQ5_GENERATOR_POLICY_ID := "g4_gq5_radical_inverse_piecewise_shell_v1"
const GQ5_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq5_generation_receipt_v1"
const GQ5_SELECTION_INDICES := [37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48]
const GQ5_HELD_OUT_INDICES := [401, 402, 403, 404, 405, 406, 407, 408]
const GQ6_GENERATOR_POLICY_ID := "g4_gq6_radical_inverse_piecewise_shell_v1"
const GQ6_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq6_generation_receipt_v1"
const GQ6_SELECTION_INDICES := [49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60]
const GQ6_HELD_OUT_INDICES := [501, 502, 503, 504, 505, 506, 507, 508]
const GQ7_GENERATOR_POLICY_ID := "g4_gq7_radical_inverse_piecewise_shell_v1"
const GQ7_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq7_generation_receipt_v1"
const GQ7_SELECTION_INDICES := [61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72]
const GQ7_HELD_OUT_INDICES := [601, 602, 603, 604, 605, 606, 607, 608]
const GQ8_GENERATOR_POLICY_ID := "g4_gq8_radical_inverse_piecewise_shell_v1"
const GQ8_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq8_generation_receipt_v1"
const GQ8_SELECTION_INDICES := [73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84]
const GQ8_HELD_OUT_INDICES := [701, 702, 703, 704, 705, 706, 707, 708]
const GQ9_GENERATOR_POLICY_ID := "g4_gq9_radical_inverse_piecewise_shell_v1"
const GQ9_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq9_generation_receipt_v1"
const GQ9_SELECTION_INDICES := [85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96]
const GQ9_HELD_OUT_INDICES := [801, 802, 803, 804, 805, 806, 807, 808]
const GQ10_GENERATOR_POLICY_ID := "g4_gq10_radical_inverse_piecewise_shell_v1"
const GQ10_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq10_generation_receipt_v1"
const GQ10_SELECTION_INDICES := [97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108]
const GQ10_HELD_OUT_INDICES := [901, 902, 903, 904, 905, 906, 907, 908]
const GQ11_GENERATOR_POLICY_ID := "g4_gq11_radical_inverse_piecewise_shell_v1"
const GQ11_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq11_generation_receipt_v1"
const GQ11_SELECTION_INDICES := [109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120]
const GQ11_HELD_OUT_INDICES := [1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008]
const GQ12_GENERATOR_POLICY_ID := "g4_gq12_radical_inverse_piecewise_shell_v1"
const GQ12_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq12_generation_receipt_v1"
const GQ12_SELECTION_INDICES := [121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132]
const GQ12_HELD_OUT_INDICES := [1101, 1102, 1103, 1104, 1105, 1106, 1107, 1108]
const GQ13_GENERATOR_POLICY_ID := "g4_gq13_radical_inverse_piecewise_shell_v1"
const GQ13_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq13_generation_receipt_v1"
const GQ13_SELECTION_INDICES := [133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144]
const GQ13_HELD_OUT_INDICES := [1201, 1202, 1203, 1204, 1205, 1206, 1207, 1208]
const GQ14_GENERATOR_POLICY_ID := "g4_gq14_radical_inverse_piecewise_shell_v1"
const GQ14_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq14_generation_receipt_v1"
const GQ14_SELECTION_INDICES := [145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156]
const GQ14_HELD_OUT_INDICES := [1301, 1302, 1303, 1304, 1305, 1306, 1307, 1308]
const GQ15_GENERATOR_POLICY_ID := "g4_gq15_radical_inverse_piecewise_shell_v1"
const GQ15_GENERATOR_SCHEMA_VERSION := "sporespore_g4_gq15_generation_receipt_v1"
const GQ15_SELECTION_INDICES := [157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168]
const GQ15_HELD_OUT_INDICES := [1401, 1402, 1403, 1404, 1405, 1406, 1407, 1408]
const QSDK_R05_CAMPAIGN_ID := "QSDK-R05"
const QSDK_R05_GENERATOR_POLICY_ID := "qsdk_r05_radical_inverse_piecewise_shell_v1"
const QSDK_R05_GENERATOR_SCHEMA_VERSION := "sporespore_qsdk_r05_generation_receipt_v1"
const QSDK_R05_INDEPENDENT_INDICES := [
	169,
	170,
	171,
	172,
	173,
	174,
	175,
	176,
	177,
	178,
	179,
	180,
]
const QSDK_R05B_CAMPAIGN_ID := "QSDK-R05B"
const QSDK_R05B_GENERATOR_POLICY_ID := "qsdk_r05b_radical_inverse_piecewise_shell_v1"
const QSDK_R05B_GENERATOR_SCHEMA_VERSION := "sporespore_qsdk_r05b_generation_receipt_v1"
const QSDK_R05B_INDEPENDENT_INDICES := [
	181,
	182,
	183,
	184,
	185,
	186,
	187,
	188,
	189,
	190,
	191,
	192,
]
const GQ1_AXIS_KEYS := [
	"torso_length_scale",
	"torso_width_scale",
	"upper_length_fraction",
	"hip_span_scale",
	"foot_radius_scale",
	"front_limb_mass_scale",
]
const GQ1_AXIS_BASES := {
	"torso_length_scale": 2,
	"torso_width_scale": 3,
	"upper_length_fraction": 5,
	"hip_span_scale": 7,
	"foot_radius_scale": 11,
	"front_limb_mass_scale": 13,
}
const GQ1_AXIS_INTERVALS := {
	"torso_length_scale": [1.0, 0.90, 1.10],
	"torso_width_scale": [1.0, 0.90, 1.10],
	"upper_length_fraction": [18.0 / 35.0, 0.50, 0.55],
	"hip_span_scale": [1.0, 0.90, 1.10],
	"foot_radius_scale": [1.0, 0.975, 1.10],
	"front_limb_mass_scale": [1.0, 0.90, 1.05],
}
const PARAMETER_KEYS := [
	"schema_version",
	"morphology_id",
	"torso_length_scale",
	"torso_width_scale",
	"upper_length_fraction",
	"hip_span_scale",
	"foot_radius_scale",
	"front_limb_mass_scale",
]
const REFERENCE_UPPER_FRACTION := 18.0 / 35.0
const MINIMUM_SCALE := 0.90
const MAXIMUM_SCALE := 1.10
const MINIMUM_UPPER_FRACTION := 0.48
const MAXIMUM_UPPER_FRACTION := 0.55
const TOTAL_LEG_REACH_M := 0.35
const CONNECTED_ATTACHMENT_OVERLAP_LIMIT_M := 0.012
const FLOOR_TOLERANCE_M := 1.0e-9


static func reference_parameters(morphology_id: String = "reference") -> Dictionary:
	return _parameters(
		morphology_id,
		1.0,
		1.0,
		REFERENCE_UPPER_FRACTION,
		1.0,
		1.0,
		1.0,
	)


static func selection_cells() -> Array:
	return [
		reference_parameters(),
		_parameters("torso_length_0p900", 0.90, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("torso_length_1p100", 1.10, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("torso_width_0p900", 1.0, 0.90, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("torso_width_1p100", 1.0, 1.10, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("upper_share_0p480", 1.0, 1.0, 0.48, 1.0, 1.0, 1.0),
		_parameters("upper_share_0p550", 1.0, 1.0, 0.55, 1.0, 1.0, 1.0),
		_parameters("hip_span_0p900", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 0.90, 1.0, 1.0),
		_parameters("hip_span_1p100", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.10, 1.0, 1.0),
		_parameters("foot_radius_0p900", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 0.90, 1.0),
		_parameters("foot_radius_1p100", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.10, 1.0),
		_parameters("front_mass_0p900", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 0.90),
		_parameters("front_mass_1p100", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.10),
	]


static func held_out_cells() -> Array:
	return [
		_parameters("mixed_a", 0.95, 1.05, 0.50, 1.05, 0.95, 1.05),
		_parameters("mixed_b", 1.05, 0.95, 0.53, 0.95, 1.05, 0.95),
		_parameters("mixed_c", 0.95, 0.95, 0.53, 1.05, 1.05, 1.05),
		_parameters("mixed_d", 1.05, 1.05, 0.50, 0.95, 0.95, 0.95),
	]


static func gp2_selection_cells() -> Array:
	return [
		reference_parameters("gp2_reference"),
		_parameters("gp2_torso_length_0p900", 0.90, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp2_torso_length_1p100", 1.10, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp2_torso_width_0p900", 1.0, 0.90, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp2_torso_width_1p100", 1.0, 1.10, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp2_upper_share_0p500", 1.0, 1.0, 0.50, 1.0, 1.0, 1.0),
		_parameters("gp2_upper_share_0p550", 1.0, 1.0, 0.55, 1.0, 1.0, 1.0),
		_parameters("gp2_hip_span_0p900", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 0.90, 1.0, 1.0),
		_parameters("gp2_hip_span_1p100", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.10, 1.0, 1.0),
		_parameters("gp2_foot_radius_0p975", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 0.975, 1.0),
		_parameters("gp2_foot_radius_1p100", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.10, 1.0),
		_parameters("gp2_front_mass_0p900", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 0.90),
		_parameters("gp2_front_mass_1p050", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.05),
	]


static func gp2_held_out_cells() -> Array:
	return [
		_parameters("gp2_mixed_a", 0.95, 1.05, 0.51, 1.05, 0.9875, 1.025),
		_parameters("gp2_mixed_b", 1.05, 0.95, 0.54, 0.95, 1.075, 0.95),
		_parameters("gp2_mixed_c", 0.95, 0.95, 0.54, 1.05, 1.075, 1.025),
		_parameters("gp2_mixed_d", 1.05, 1.05, 0.51, 0.95, 0.9875, 0.95),
	]


static func gp3_selection_cells() -> Array:
	return [
		reference_parameters("gp3_reference"),
		_parameters("gp3_torso_length_0p900", 0.90, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp3_torso_length_1p100", 1.10, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp3_torso_width_0p900", 1.0, 0.90, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp3_torso_width_1p100", 1.0, 1.10, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp3_upper_share_0p500", 1.0, 1.0, 0.50, 1.0, 1.0, 1.0),
		_parameters("gp3_upper_share_0p550", 1.0, 1.0, 0.55, 1.0, 1.0, 1.0),
		_parameters("gp3_hip_span_0p900", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 0.90, 1.0, 1.0),
		_parameters("gp3_hip_span_1p100", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.10, 1.0, 1.0),
		_parameters("gp3_foot_radius_0p975", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 0.975, 1.0),
		_parameters("gp3_foot_radius_1p100", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.10, 1.0),
		_parameters("gp3_front_mass_0p900", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 0.90),
		_parameters("gp3_front_mass_1p050", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.05),
	]


static func gp3_held_out_cells() -> Array:
	return [
		_parameters("gp3_mixed_a", 0.95, 1.05, 0.51, 1.05, 0.9875, 1.025),
		_parameters("gp3_mixed_b", 1.05, 0.95, 0.54, 0.95, 1.075, 0.95),
		_parameters("gp3_mixed_c", 0.95, 0.95, 0.54, 1.05, 1.075, 1.025),
		_parameters("gp3_mixed_d", 1.05, 1.05, 0.51, 0.95, 0.9875, 0.95),
	]


static func gp4_selection_cells() -> Array:
	return [
		reference_parameters("gp4_reference"),
		_parameters("gp4_torso_length_0p900", 0.90, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp4_torso_length_1p100", 1.10, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp4_torso_width_0p900", 1.0, 0.90, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp4_torso_width_1p100", 1.0, 1.10, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp4_upper_share_0p500", 1.0, 1.0, 0.50, 1.0, 1.0, 1.0),
		_parameters("gp4_upper_share_0p550", 1.0, 1.0, 0.55, 1.0, 1.0, 1.0),
		_parameters("gp4_hip_span_0p900", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 0.90, 1.0, 1.0),
		_parameters("gp4_hip_span_1p100", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.10, 1.0, 1.0),
		_parameters("gp4_foot_radius_0p975", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 0.975, 1.0),
		_parameters("gp4_foot_radius_1p100", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.10, 1.0),
		_parameters("gp4_front_mass_0p900", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 0.90),
		_parameters("gp4_front_mass_1p050", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.05),
	]


static func gp4_held_out_cells() -> Array:
	return [
		_parameters("gp4_mixed_a", 0.95, 1.05, 0.51, 1.05, 0.9875, 1.025),
		_parameters("gp4_mixed_b", 1.05, 0.95, 0.54, 0.95, 1.075, 0.95),
		_parameters("gp4_mixed_c", 0.95, 0.95, 0.54, 1.05, 1.075, 1.025),
		_parameters("gp4_mixed_d", 1.05, 1.05, 0.51, 0.95, 0.9875, 0.95),
	]


static func gp5_selection_cells() -> Array:
	return [
		reference_parameters("gp5_reference"),
		_parameters("gp5_torso_length_0p900", 0.90, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp5_torso_length_1p100", 1.10, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp5_torso_width_0p900", 1.0, 0.90, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp5_torso_width_1p100", 1.0, 1.10, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.0),
		_parameters("gp5_upper_share_0p500", 1.0, 1.0, 0.50, 1.0, 1.0, 1.0),
		_parameters("gp5_upper_share_0p550", 1.0, 1.0, 0.55, 1.0, 1.0, 1.0),
		_parameters("gp5_hip_span_0p900", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 0.90, 1.0, 1.0),
		_parameters("gp5_hip_span_1p100", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.10, 1.0, 1.0),
		_parameters("gp5_foot_radius_0p975", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 0.975, 1.0),
		_parameters("gp5_foot_radius_1p100", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.10, 1.0),
		_parameters("gp5_front_mass_0p900", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 0.90),
		_parameters("gp5_front_mass_1p050", 1.0, 1.0, REFERENCE_UPPER_FRACTION, 1.0, 1.0, 1.05),
	]


static func gp5_held_out_cells() -> Array:
	return [
		_parameters("gp5_mixed_a", 0.95, 1.05, 0.51, 1.05, 0.9875, 1.025),
		_parameters("gp5_mixed_b", 1.05, 0.95, 0.54, 0.95, 1.075, 0.95),
		_parameters("gp5_mixed_c", 0.95, 0.95, 0.54, 1.05, 1.075, 1.025),
		_parameters("gp5_mixed_d", 1.05, 1.05, 0.51, 0.95, 0.9875, 0.95),
	]


static func gq1_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ1_SELECTION_INDICES:
		var result := compile_gq1_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq1_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ1_HELD_OUT_INDICES:
		var result := compile_gq1_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq2_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ2_SELECTION_INDICES:
		var result := compile_gq2_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq2_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ2_HELD_OUT_INDICES:
		var result := compile_gq2_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq3_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ3_SELECTION_INDICES:
		var result := compile_gq3_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq3_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ3_HELD_OUT_INDICES:
		var result := compile_gq3_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq4_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ4_SELECTION_INDICES:
		var result := compile_gq4_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq4_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ4_HELD_OUT_INDICES:
		var result := compile_gq4_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq5_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ5_SELECTION_INDICES:
		var result := compile_gq5_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq5_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ5_HELD_OUT_INDICES:
		var result := compile_gq5_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq6_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ6_SELECTION_INDICES:
		var result := compile_gq6_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq6_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ6_HELD_OUT_INDICES:
		var result := compile_gq6_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq7_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ7_SELECTION_INDICES:
		var result := compile_gq7_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq7_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ7_HELD_OUT_INDICES:
		var result := compile_gq7_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq8_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ8_SELECTION_INDICES:
		var result := compile_gq8_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq8_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ8_HELD_OUT_INDICES:
		var result := compile_gq8_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq9_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ9_SELECTION_INDICES:
		var result := compile_gq9_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq9_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ9_HELD_OUT_INDICES:
		var result := compile_gq9_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq10_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ10_SELECTION_INDICES:
		var result := compile_gq10_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq10_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ10_HELD_OUT_INDICES:
		var result := compile_gq10_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq11_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ11_SELECTION_INDICES:
		var result := compile_gq11_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq11_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ11_HELD_OUT_INDICES:
		var result := compile_gq11_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq12_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ12_SELECTION_INDICES:
		var result := compile_gq12_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq12_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ12_HELD_OUT_INDICES:
		var result := compile_gq12_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq13_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ13_SELECTION_INDICES:
		var result := compile_gq13_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq13_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ13_HELD_OUT_INDICES:
		var result := compile_gq13_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq14_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ14_SELECTION_INDICES:
		var result := compile_gq14_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq14_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ14_HELD_OUT_INDICES:
		var result := compile_gq14_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq15_selection_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ15_SELECTION_INDICES:
		var result := compile_gq15_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func gq15_held_out_cells() -> Array:
	var cells: Array = []
	for generator_index in GQ15_HELD_OUT_INDICES:
		var result := compile_gq15_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func qsdk_r05_independent_cells() -> Array:
	var cells: Array = []
	for generator_index in QSDK_R05_INDEPENDENT_INDICES:
		var result := compile_qsdk_r05_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func qsdk_r05b_independent_cells() -> Array:
	var cells: Array = []
	for generator_index in QSDK_R05B_INDEPENDENT_INDICES:
		var result := compile_qsdk_r05b_generation(generator_index)
		if not bool(result.get("ok", false)):
			return []
		cells.append((result["proportion_spec"] as Dictionary).duplicate(true))
	return cells


static func compile_gq1_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ1_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ1_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ1_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ1_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var morphology_id := "gq1_generated_s%03d" % generator_index
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": morphology_id,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ1_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ1_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ1,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func verify_gq1_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq1_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ1_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func compile_gq2_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ2_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ2_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ2_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ2_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var gq1_result := compile_gq1_generation(generator_index)
	if not bool(gq1_result.get("ok", false)):
		return {
			"ok": false,
			"failure_code": "GQ2_BASE_GENERATION_FAILURE",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var proportion_spec: Dictionary = (gq1_result["proportion_spec"] as Dictionary).duplicate(true)
	proportion_spec["morphology_id"] = "gq2_generated_s%03d" % generator_index
	var gq1_receipt: Dictionary = gq1_result["generator_receipt"]
	var generator_receipt := {
		"schema_version": GQ2_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ2_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ2,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": float(gq1_receipt["shell_fraction"]),
		"axis_coordinates": (gq1_receipt["axis_coordinates"] as Dictionary).duplicate(true),
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func verify_gq2_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq2_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ2_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func compile_gq3_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ3_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ3_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ3_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ3_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "gq3_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ3_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ3_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ3,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func compile_gq4_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ4_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ4_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ4_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ4_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "gq4_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ4_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ4_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ4,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func compile_gq5_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ5_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ5_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ5_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ5_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "gq5_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ5_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ5_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ5,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func compile_gq6_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ6_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ6_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ6_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ6_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "gq6_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ6_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ6_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ6,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func compile_gq7_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ7_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ7_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ7_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ7_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "gq7_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ7_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ7_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ7,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func compile_gq8_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ8_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ8_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ8_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ8_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "gq8_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ8_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ8_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ8,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func compile_gq9_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ9_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ9_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ9_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ9_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "gq9_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ9_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ9_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ9,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func compile_gq10_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ10_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ10_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ10_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ10_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "gq10_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ10_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ10_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ10,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func compile_gq11_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ11_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ11_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ11_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ11_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "gq11_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ11_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ11_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ11,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func compile_gq12_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ12_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ12_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ12_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ12_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "gq12_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ12_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ12_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ12,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func compile_gq13_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ13_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ13_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ13_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ13_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "gq13_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ13_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ13_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ13,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func compile_gq14_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ14_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ14_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ14_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ14_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "gq14_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ14_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ14_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ14,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func compile_gq15_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_GQ15_GENERATOR_INDEX_TYPE",
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	var campaign_role := ""
	if GQ15_SELECTION_INDICES.has(generator_index):
		campaign_role = "selection"
	elif GQ15_HELD_OUT_INDICES.has(generator_index):
		campaign_role = "heldout"
	else:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GQ15_GENERATOR_INDEX",
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "gq15_generated_s%03d" % generator_index,
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": GQ15_GENERATOR_SCHEMA_VERSION,
		"generator_policy_id": GQ15_GENERATOR_POLICY_ID,
		"campaign_id": CAMPAIGN_GQ15,
		"campaign_role": campaign_role,
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"world_build_count": 0,
	}


static func compile_qsdk_r05_generation(generator_index_value: Variant) -> Dictionary:
	return _compile_qsdk_independent_generation(
		generator_index_value,
		QSDK_R05_INDEPENDENT_INDICES,
		QSDK_R05_CAMPAIGN_ID,
		QSDK_R05_GENERATOR_POLICY_ID,
		QSDK_R05_GENERATOR_SCHEMA_VERSION,
		"qsdk_r05_generated",
		"QSDK_R05",
	)


static func compile_qsdk_r05b_generation(generator_index_value: Variant) -> Dictionary:
	return _compile_qsdk_independent_generation(
		generator_index_value,
		QSDK_R05B_INDEPENDENT_INDICES,
		QSDK_R05B_CAMPAIGN_ID,
		QSDK_R05B_GENERATOR_POLICY_ID,
		QSDK_R05B_GENERATOR_SCHEMA_VERSION,
		"qsdk_r05b_generated",
		"QSDK_R05B",
	)


static func _compile_qsdk_independent_generation(
	generator_index_value: Variant,
	allowed_indices: Array,
	campaign_id: String,
	generator_policy_id: String,
	generator_schema_version: String,
	morphology_prefix: String,
	failure_prefix: String,
) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_%s_GENERATOR_INDEX_TYPE" % failure_prefix,
			"world_build_count": 0,
		}
	var generator_index := int(generator_index_value)
	if not allowed_indices.has(generator_index):
		return {
			"ok": false,
			"failure_code": "UNKNOWN_%s_GENERATOR_INDEX" % failure_prefix,
			"generator_index": generator_index,
			"world_build_count": 0,
		}
	var shell_fraction := 0.25 * float(1 + posmod(generator_index - 1, 4))
	var proportion_spec := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": "%s_s%03d" % [morphology_prefix, generator_index],
	}
	var axis_coordinates := {}
	for axis_key_value in GQ1_AXIS_KEYS:
		var axis_key := String(axis_key_value)
		var axis_base := int(GQ1_AXIS_BASES[axis_key])
		var radical_inverse := _radical_inverse(generator_index, axis_base)
		var centered_coordinate := 2.0 * radical_inverse - 1.0
		var interval: Array = GQ1_AXIS_INTERVALS[axis_key]
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
		"schema_version": generator_schema_version,
		"generator_policy_id": generator_policy_id,
		"campaign_id": campaign_id,
		"campaign_role": "independent",
		"generator_index": generator_index,
		"shell_fraction": shell_fraction,
		"axis_coordinates": axis_coordinates,
		"proportion_spec": proportion_spec.duplicate(true),
		"world_build_count": 0,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"proportion_spec_sha256": CanonicalJsonScript.sha256(proportion_spec),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func verify_gq3_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq3_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ3_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func verify_gq4_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq4_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ4_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func verify_gq5_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq5_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ5_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func verify_gq6_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq6_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ6_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func verify_gq7_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq7_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ7_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func verify_gq8_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq8_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ8_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func verify_gq9_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq9_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ9_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func verify_gq10_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq10_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ10_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func verify_gq11_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq11_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ11_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func verify_gq12_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq12_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ12_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func verify_gq13_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq13_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ13_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func verify_gq14_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq14_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ14_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func verify_gq15_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
) -> Dictionary:
	var result := compile_gq15_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
	):
		return {
			"ok": false,
			"failure_code": "GQ15_GENERATOR_RECEIPT_DIGEST_MISMATCH",
			"world_build_count": 0,
		}
	return result


static func verify_qsdk_r05_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
	expected_proportion_spec_sha256: String,
) -> Dictionary:
	var result := compile_qsdk_r05_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
		or expected_proportion_spec_sha256.is_empty()
		or String(result["proportion_spec_sha256"]) != expected_proportion_spec_sha256
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R05_GENERATION_DIGEST_MISMATCH",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	return result


static func verify_qsdk_r05b_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
	expected_proportion_spec_sha256: String,
) -> Dictionary:
	var result := compile_qsdk_r05b_generation(generator_index_value)
	if not bool(result.get("ok", false)):
		return result
	if (
		expected_generator_receipt_sha256.is_empty()
		or String(result["generator_receipt_sha256"]) != expected_generator_receipt_sha256
		or expected_proportion_spec_sha256.is_empty()
		or String(result["proportion_spec_sha256"]) != expected_proportion_spec_sha256
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R05B_GENERATION_DIGEST_MISMATCH",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	return result


static func gq1_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ1_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ1_SELECTION_INDICES if role == "selection" else GQ1_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq1_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ1_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq2_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ2_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ2_SELECTION_INDICES if role == "selection" else GQ2_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq2_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ2_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq3_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ3_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ3_SELECTION_INDICES if role == "selection" else GQ3_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq3_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ3_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq4_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ4_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ4_SELECTION_INDICES if role == "selection" else GQ4_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq4_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ4_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq5_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ5_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ5_SELECTION_INDICES if role == "selection" else GQ5_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq5_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ5_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq6_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ6_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ6_SELECTION_INDICES if role == "selection" else GQ6_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq6_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ6_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq7_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ7_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ7_SELECTION_INDICES if role == "selection" else GQ7_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq7_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ7_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq8_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ8_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ8_SELECTION_INDICES if role == "selection" else GQ8_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq8_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ8_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq9_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ9_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ9_SELECTION_INDICES if role == "selection" else GQ9_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq9_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ9_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq10_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ10_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ10_SELECTION_INDICES if role == "selection" else GQ10_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq10_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ10_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq11_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ11_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ11_SELECTION_INDICES if role == "selection" else GQ11_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq11_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ11_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq12_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ12_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ12_SELECTION_INDICES if role == "selection" else GQ12_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq12_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ12_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq13_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ13_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ13_SELECTION_INDICES if role == "selection" else GQ13_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq13_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ13_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq14_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ14_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ14_SELECTION_INDICES if role == "selection" else GQ14_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq14_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ14_MORPHOLOGY",
		"world_build_count": 0,
	}


static func gq15_generation_for_morphology(
	morphology_id: String,
	role: String,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {
			"ok": false,
			"failure_code": "INVALID_GQ15_CAMPAIGN_ROLE",
			"world_build_count": 0,
		}
	var indices: Array = GQ15_SELECTION_INDICES if role == "selection" else GQ15_HELD_OUT_INDICES
	for generator_index in indices:
		var result := compile_gq15_generation(generator_index)
		if (
			bool(result.get("ok", false))
			and String((result["proportion_spec"] as Dictionary)["morphology_id"]) == morphology_id
		):
			return result
	return {
		"ok": false,
		"failure_code": "UNKNOWN_GQ15_MORPHOLOGY",
		"world_build_count": 0,
	}


static func declared_cell(
	morphology_id: String,
	role: String,
	campaign_id: String = CAMPAIGN_GP1,
) -> Dictionary:
	if role != "selection" and role != "heldout":
		return {}
	var selection: Array
	var held_out: Array
	match campaign_id:
		CAMPAIGN_GP1:
			selection = selection_cells()
			held_out = held_out_cells()
		CAMPAIGN_GP2:
			selection = gp2_selection_cells()
			held_out = gp2_held_out_cells()
		CAMPAIGN_GP3:
			selection = gp3_selection_cells()
			held_out = gp3_held_out_cells()
		CAMPAIGN_GP4:
			selection = gp4_selection_cells()
			held_out = gp4_held_out_cells()
		CAMPAIGN_GP5:
			selection = gp5_selection_cells()
			held_out = gp5_held_out_cells()
		CAMPAIGN_GQ1:
			selection = gq1_selection_cells()
			held_out = gq1_held_out_cells()
		CAMPAIGN_GQ2:
			selection = gq2_selection_cells()
			held_out = gq2_held_out_cells()
		CAMPAIGN_GQ3:
			selection = gq3_selection_cells()
			held_out = gq3_held_out_cells()
		CAMPAIGN_GQ4:
			selection = gq4_selection_cells()
			held_out = gq4_held_out_cells()
		CAMPAIGN_GQ5:
			selection = gq5_selection_cells()
			held_out = gq5_held_out_cells()
		CAMPAIGN_GQ6:
			selection = gq6_selection_cells()
			held_out = gq6_held_out_cells()
		CAMPAIGN_GQ7:
			selection = gq7_selection_cells()
			held_out = gq7_held_out_cells()
		CAMPAIGN_GQ8:
			selection = gq8_selection_cells()
			held_out = gq8_held_out_cells()
		CAMPAIGN_GQ9:
			selection = gq9_selection_cells()
			held_out = gq9_held_out_cells()
		CAMPAIGN_GQ10:
			selection = gq10_selection_cells()
			held_out = gq10_held_out_cells()
		CAMPAIGN_GQ11:
			selection = gq11_selection_cells()
			held_out = gq11_held_out_cells()
		CAMPAIGN_GQ12:
			selection = gq12_selection_cells()
			held_out = gq12_held_out_cells()
		CAMPAIGN_GQ13:
			selection = gq13_selection_cells()
			held_out = gq13_held_out_cells()
		CAMPAIGN_GQ14:
			selection = gq14_selection_cells()
			held_out = gq14_held_out_cells()
		CAMPAIGN_GQ15:
			selection = gq15_selection_cells()
			held_out = gq15_held_out_cells()
		_:
			return {}
	var cells := selection if role == "selection" else held_out
	for cell_value in cells:
		var cell: Dictionary = cell_value
		if String(cell["morphology_id"]) == morphology_id:
			return cell.duplicate(true)
	return {}


static func _radical_inverse(generator_index: int, base: int) -> float:
	var remaining := generator_index
	var place_value := 1.0 / float(base)
	var result := 0.0
	while remaining > 0:
		result += float(remaining % base) * place_value
		remaining = int(remaining / base)
		place_value /= float(base)
	return result


static func compile(requested: Dictionary) -> Dictionary:
	var keys_result := _validate_exact_keys(requested, PARAMETER_KEYS, "proportion_spec")
	if not bool(keys_result.get("ok", false)):
		return keys_result
	if (
		typeof(requested["schema_version"]) != TYPE_STRING
		or String(requested["schema_version"]) != SCHEMA_VERSION
	):
		return _failure("UNKNOWN_SCHEMA_VERSION", "schema_version")
	if typeof(requested["morphology_id"]) != TYPE_STRING:
		return _failure("INVALID_MORPHOLOGY_ID", "morphology_id")
	var morphology_id := String(requested["morphology_id"])
	if morphology_id.is_empty() or not morphology_id.is_valid_identifier():
		return _failure("INVALID_MORPHOLOGY_ID", "morphology_id")

	var normalized := {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": morphology_id,
	}
	for key_value in [
		"torso_length_scale",
		"torso_width_scale",
		"upper_length_fraction",
		"hip_span_scale",
		"foot_radius_scale",
		"front_limb_mass_scale",
	]:
		var key := String(key_value)
		var number_result := _finite_number(requested[key], key)
		if not bool(number_result.get("ok", false)):
			return number_result
		normalized[key] = float(number_result["value"])

	for key_value in [
		"torso_length_scale",
		"torso_width_scale",
		"hip_span_scale",
		"foot_radius_scale",
		"front_limb_mass_scale",
	]:
		var key := String(key_value)
		var value := float(normalized[key])
		if value < MINIMUM_SCALE or value > MAXIMUM_SCALE:
			return _failure("PROPORTION_PARAMETER_OUT_OF_RANGE", key)
	var upper_fraction := float(normalized["upper_length_fraction"])
	if upper_fraction < MINIMUM_UPPER_FRACTION or upper_fraction > MAXIMUM_UPPER_FRACTION:
		return _failure("UPPER_FRACTION_OUT_OF_RANGE", "upper_length_fraction")

	var fixture_spec := FixtureSpecScript.reference_spec()
	if not _is_reference_parameters(normalized):
		fixture_spec = _derive_fixture(normalized)
	var fixture_result := FixtureSpecScript.compile(fixture_spec)
	if not bool(fixture_result.get("ok", false)):
		return _failure(
			"DERIVED_FIXTURE_REJECTED_%s" % String(fixture_result.get("failure_code", "UNKNOWN")),
			String(fixture_result.get("field", "fixture_spec")),
		)
	var compiled_fixture: Dictionary = fixture_result["fixture_spec"]
	var static_screen := _static_screen(normalized, compiled_fixture)
	if not bool(static_screen.get("passed", false)):
		return {
			"ok": false,
			"failure_code": "STATIC_SCREEN_REJECTED",
			"field": String(static_screen.get("failed_predicate", "static_screen")),
			"proportion_spec": normalized.duplicate(true),
			"static_screen": static_screen.duplicate(true),
			"world_build_count": 0,
		}
	var parameter_sha256 := CanonicalJsonScript.sha256(normalized)
	var static_screen_sha256 := CanonicalJsonScript.sha256(static_screen)
	return {
		"ok": true,
		"policy_id": POLICY_ID,
		"proportion_spec": normalized.duplicate(true),
		"proportion_spec_sha256": parameter_sha256,
		"fixture_spec": compiled_fixture.duplicate(true),
		"fixture_spec_sha256": String(fixture_result["fixture_spec_sha256"]),
		"static_screen": static_screen.duplicate(true),
		"static_screen_sha256": static_screen_sha256,
		"world_build_count": 0,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
		"automatic_creature_guidance_allowed": false,
	}


static func verify(
	requested: Dictionary,
	expected_proportion_sha256: String,
	expected_fixture_sha256: String,
	expected_static_screen_sha256: String,
) -> Dictionary:
	var compiled := compile(requested)
	if not bool(compiled.get("ok", false)):
		return compiled
	for pair_value in [
		["proportion_spec_sha256", expected_proportion_sha256],
		["fixture_spec_sha256", expected_fixture_sha256],
		["static_screen_sha256", expected_static_screen_sha256],
	]:
		var pair: Array = pair_value
		var key := String(pair[0])
		var expected := String(pair[1])
		var actual := String(compiled[key])
		if not expected.begins_with("sha256:") or expected.length() != 71 or expected != actual:
			return {
				"ok": false,
				"failure_code": "PROPORTION_RECEIPT_DIGEST_MISMATCH",
				"field": key,
				"expected_sha256": expected,
				"actual_sha256": actual,
				"world_build_count": 0,
			}
	return compiled


static func _derive_fixture(parameters: Dictionary) -> Dictionary:
	var fixture := FixtureSpecScript.reference_spec()
	var torso: Dictionary = fixture["torso"]
	var torso_size: Array = torso["size_m"]
	torso_size[0] = 0.50 * float(parameters["torso_length_scale"])
	torso_size[2] = 0.32 * float(parameters["torso_width_scale"])
	var foot_radius_m := 0.04 * float(parameters["foot_radius_scale"])
	var torso_center: Array = torso["initial_center_m"]
	torso_center[1] = 0.05 + TOTAL_LEG_REACH_M + foot_radius_m
	var upper_fraction := float(parameters["upper_length_fraction"])
	var upper_length_m := TOTAL_LEG_REACH_M * upper_fraction
	var lower_length_m := TOTAL_LEG_REACH_M - upper_length_m
	var hip_span_scale := float(parameters["hip_span_scale"])
	var front_mass_scale := float(parameters["front_limb_mass_scale"])
	var rear_mass_scale := 2.0 - front_mass_scale
	for limb_value in fixture["limbs"]:
		var limb: Dictionary = limb_value
		var offset: Array = limb["hip_offset_from_torso_center_m"]
		offset[0] = float(offset[0]) * hip_span_scale
		offset[2] = float(offset[2]) * hip_span_scale
		limb["upper_length_m"] = upper_length_m
		limb["lower_length_m"] = lower_length_m
		limb["foot_radius_m"] = foot_radius_m
		var limb_mass_scale := (
			front_mass_scale if String(limb["limb_id"]).begins_with("front_") else rear_mass_scale
		)
		limb["upper_mass_kg"] = 0.25 * limb_mass_scale
		limb["distal_mass_kg"] = 0.18 * limb_mass_scale
	return fixture


static func _static_screen(parameters: Dictionary, fixture: Dictionary) -> Dictionary:
	var torso: Dictionary = fixture["torso"]
	var torso_center := FixtureSpecScript.vector3_from_array(torso["initial_center_m"])
	var torso_size := FixtureSpecScript.vector3_from_array(torso["size_m"])
	var joint_limits: Dictionary = fixture["joint_limits"]
	var motor_impulses: Dictionary = fixture["motor_impulses"]
	var collision_margin_m := float(fixture["collision_margin_m"])
	var limbs: Array = fixture["limbs"]
	var foot_floor_error_m := 0.0
	var maximum_attachment_overlap_m := 0.0
	var anchors_finite := true
	var ordered_ids: Array = []
	var upper_centers: Array = []
	var upper_radii: Array = []
	var foot_centers: Array = []
	var foot_radii: Array = []
	var total_mass_kg := float(torso["mass_kg"])
	var weighted_com_xz := Vector2.ZERO
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var limb_id := String(limb["limb_id"])
		ordered_ids.append(limb_id)
		var hip_offset_components: Array = limb["hip_offset_from_torso_center_m"]
		var hip := torso_center + FixtureSpecScript.vector3_from_array(hip_offset_components)
		var upper_length_m := float(limb["upper_length_m"])
		var lower_length_m := float(limb["lower_length_m"])
		var knee := hip + Vector3.DOWN * upper_length_m
		var foot := knee + Vector3.DOWN * lower_length_m
		anchors_finite = anchors_finite and hip.is_finite() and knee.is_finite()
		var radius_m := float(limb["foot_radius_m"])
		var exact_foot_center_height_m := (
			float((torso["initial_center_m"] as Array)[1])
			+ float(hip_offset_components[1])
			- upper_length_m
			- lower_length_m
		)
		foot_floor_error_m = maxf(
			foot_floor_error_m,
			absf(exact_foot_center_height_m - radius_m),
		)
		var upper_center := hip.lerp(knee, 0.5)
		var cross_section: Array = limb["upper_cross_section_m"]
		var upper_radius := (
			Vector3(
				float(cross_section[0]) * 0.5,
				upper_length_m * 0.5,
				float(cross_section[1]) * 0.5,
			)
			. length()
		)
		upper_centers.append(upper_center)
		upper_radii.append(upper_radius)
		foot_centers.append(foot)
		foot_radii.append(radius_m)
		var torso_bottom_m := torso_center.y - torso_size.y * 0.5
		maximum_attachment_overlap_m = maxf(
			maximum_attachment_overlap_m,
			maxf(0.0, hip.y - torso_bottom_m),
		)
		var limb_mass_kg := float(limb["upper_mass_kg"]) + float(limb["distal_mass_kg"])
		total_mass_kg += limb_mass_kg
		weighted_com_xz += Vector2(hip.x, hip.z) * limb_mass_kg
	var projected_com_m := weighted_com_xz / total_mass_kg
	var support_half_x_m := absf(float((foot_centers[0] as Vector3).x))
	var support_half_z_m := absf(float((foot_centers[0] as Vector3).z))
	var support_margin_m := minf(
		support_half_x_m - absf(projected_com_m.x),
		support_half_z_m - absf(projected_com_m.y),
	)
	var minimum_nonadjacent_clearance_m := INF
	for left_index in range(limbs.size()):
		for right_index in range(left_index + 1, limbs.size()):
			var upper_left: Vector3 = upper_centers[left_index]
			var upper_right: Vector3 = upper_centers[right_index]
			minimum_nonadjacent_clearance_m = minf(
				minimum_nonadjacent_clearance_m,
				(
					upper_left.distance_to(upper_right)
					- float(upper_radii[left_index])
					- float(upper_radii[right_index])
				),
			)
			var foot_left: Vector3 = foot_centers[left_index]
			var foot_right: Vector3 = foot_centers[right_index]
			minimum_nonadjacent_clearance_m = minf(
				minimum_nonadjacent_clearance_m,
				(
					foot_left.distance_to(foot_right)
					- float(foot_radii[left_index])
					- float(foot_radii[right_index])
				),
			)
	for upper_index in range(limbs.size()):
		for foot_index in range(limbs.size()):
			var upper_center: Vector3 = upper_centers[upper_index]
			var foot_center: Vector3 = foot_centers[foot_index]
			minimum_nonadjacent_clearance_m = minf(
				minimum_nonadjacent_clearance_m,
				(
					upper_center.distance_to(foot_center)
					- float(upper_radii[upper_index])
					- float(foot_radii[foot_index])
				),
			)
	var torso_radius_m := torso_size.length() * 0.5
	for foot_index in range(limbs.size()):
		var foot_center: Vector3 = foot_centers[foot_index]
		minimum_nonadjacent_clearance_m = minf(
			minimum_nonadjacent_clearance_m,
			torso_center.distance_to(foot_center) - torso_radius_m - float(foot_radii[foot_index]),
		)
	var topology_exact := ordered_ids == FixtureSpecScript.REFERENCE_LIMB_IDS
	var neutral_inside_limits := (
		float(joint_limits["hip_lower_rad"]) <= 0.0
		and float(joint_limits["hip_upper_rad"]) >= 0.0
		and float(joint_limits["knee_lower_rad"]) <= 0.0
		and float(joint_limits["knee_upper_rad"]) >= 0.0
	)
	var motor_capacity_positive := (
		is_finite(float(motor_impulses["hip_max_impulse_nms"]))
		and float(motor_impulses["hip_max_impulse_nms"]) > 0.0
		and is_finite(float(motor_impulses["knee_base_max_impulse_nms"]))
		and float(motor_impulses["knee_base_max_impulse_nms"]) > 0.0
	)
	var predicates := {
		"parameters_finite_and_in_envelope": _parameters_in_envelope(parameters),
		"topology_and_order_exact": topology_exact,
		"feet_tangent_to_floor": foot_floor_error_m <= FLOOR_TOLERANCE_M,
		"joint_anchors_finite": anchors_finite,
		"neutral_inside_joint_limits": neutral_inside_limits,
		"motor_capacity_positive": motor_capacity_positive,
		"nonadjacent_shape_clearance_nonnegative": minimum_nonadjacent_clearance_m >= 0.0,
		"connected_attachment_overlap_bounded":
		maximum_attachment_overlap_m <= CONNECTED_ATTACHMENT_OVERLAP_LIMIT_M,
		"projected_com_inside_support_polygon": support_margin_m > collision_margin_m,
	}
	var failed_predicate := ""
	for key_value in predicates:
		var key := String(key_value)
		if not bool(predicates[key]):
			failed_predicate = key
			break
	return {
		"schema_version": STATIC_SCREEN_SCHEMA_VERSION,
		"policy_id": POLICY_ID,
		"morphology_id": String(parameters["morphology_id"]),
		"predicates": predicates,
		"foot_floor_error_m": foot_floor_error_m,
		"floor_tolerance_m": FLOOR_TOLERANCE_M,
		"minimum_nonadjacent_clearance_m": minimum_nonadjacent_clearance_m,
		"maximum_connected_attachment_overlap_m": maximum_attachment_overlap_m,
		"connected_attachment_overlap_limit_m": CONNECTED_ATTACHMENT_OVERLAP_LIMIT_M,
		"projected_center_of_mass_xz_m": [projected_com_m.x, projected_com_m.y],
		"support_half_extents_xz_m": [support_half_x_m, support_half_z_m],
		"minimum_support_polygon_margin_m": support_margin_m,
		"total_system_mass_kg": total_mass_kg,
		"failed_predicate": failed_predicate,
		"passed": failed_predicate.is_empty(),
		"world_build_count": 0,
	}


static func _parameters_in_envelope(parameters: Dictionary) -> bool:
	for key_value in [
		"torso_length_scale",
		"torso_width_scale",
		"hip_span_scale",
		"foot_radius_scale",
		"front_limb_mass_scale",
	]:
		var value := float(parameters[key_value])
		if not is_finite(value) or value < MINIMUM_SCALE or value > MAXIMUM_SCALE:
			return false
	var upper_fraction := float(parameters["upper_length_fraction"])
	return (
		is_finite(upper_fraction)
		and upper_fraction >= MINIMUM_UPPER_FRACTION
		and upper_fraction <= MAXIMUM_UPPER_FRACTION
	)


static func _is_reference_parameters(parameters: Dictionary) -> bool:
	return (
		float(parameters["torso_length_scale"]) == 1.0
		and float(parameters["torso_width_scale"]) == 1.0
		and float(parameters["upper_length_fraction"]) == REFERENCE_UPPER_FRACTION
		and float(parameters["hip_span_scale"]) == 1.0
		and float(parameters["foot_radius_scale"]) == 1.0
		and float(parameters["front_limb_mass_scale"]) == 1.0
	)


static func _parameters(
	morphology_id: String,
	torso_length_scale: float,
	torso_width_scale: float,
	upper_length_fraction: float,
	hip_span_scale: float,
	foot_radius_scale: float,
	front_limb_mass_scale: float,
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"morphology_id": morphology_id,
		"torso_length_scale": torso_length_scale,
		"torso_width_scale": torso_width_scale,
		"upper_length_fraction": upper_length_fraction,
		"hip_span_scale": hip_span_scale,
		"foot_radius_scale": foot_radius_scale,
		"front_limb_mass_scale": front_limb_mass_scale,
	}


static func _validate_exact_keys(source: Dictionary, expected: Array, field: String) -> Dictionary:
	if source.size() != expected.size():
		return _failure("UNEXPECTED_KEYS", field)
	for key_value in expected:
		if not source.has(key_value):
			return _failure("MISSING_KEY", "%s.%s" % [field, key_value])
	for key_value in source:
		if not expected.has(key_value):
			return _failure("UNEXPECTED_KEY", "%s.%s" % [field, key_value])
	return {"ok": true}


static func _finite_number(value: Variant, field: String) -> Dictionary:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return _failure("INVALID_NUMBER", field)
	var number := float(value)
	if not is_finite(number):
		return _failure("NONFINITE_NUMBER", field)
	return {"ok": true, "value": number}


static func _failure(failure_code: String, field: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": failure_code,
		"field": field,
		"world_build_count": 0,
	}
