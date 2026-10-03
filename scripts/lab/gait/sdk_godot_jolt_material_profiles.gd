class_name LabSdkGodotJoltMaterialProfiles
extends RefCounted

## Immutable Godot/Jolt adapter material profiles.
##
## These profiles bind authored Godot material values to isolated, retained
## breakaway evidence. They are adapter provenance; they are not portable
## claims that another engine realizes equivalent contact behavior.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const SCHEMA_VERSION := "sporespore_adapter_material_profile_v1"
const ADAPTER_ID := "godot_jolt_gdextension_v1"
const SOLVER_POLICY_ID := "jolt_120hz_20v_7p_v1"
const PHYSICS_ENGINE := "Jolt Physics"
const PHYSICS_HZ := 120
const SOLVER_VELOCITY_STEPS := 20
const SOLVER_POSITION_STEPS := 7
const MATERIAL_COMBINE_RULE := "highest_friction_both_rough_v1"
const P5M1_R1_SOURCE_COMMIT := "559aa323f3a07179cc074f1749abc94c78ceafb3"
const P5M1_R1_REPORT_SHA256 := "66555991eb7ef004725a458d86cdc8a8b0011447a266f056ddf1b33c9c776eed"
const P5M1_R1_REPORT_LOCATOR := (
	"SporeSpore_Evidence/" + "godot-jolt-friction-ladder-r1-559aa32/report.json"
)
const BW3_SOURCE_COMMIT := "60df802344884dde466d104513e279b7a89de1cd"
const BW3_REPORT_SHA256 := "94d3d9b6b2dc9086c4e21840540d8faf8d2fb7f64d915bc809d8969e9accd2e7"
const BW3_REPORT_LOCATOR := (
	"SporeSpore_Evidence/" + "balanced-wave-bw3-material-characterization-60df802/report.json"
)
const BW3R_SOURCE_COMMIT := "9d99485ffdb61501a87efaabe73ca27048dab9f5"
const BW3R_REPORT_SHA256 := "044952767924503bfd6f213dad930f24beedc256164d9bbceb5e8f31db44b1a1"
const BW3R_REPORT_LOCATOR := (
	"SporeSpore_Evidence/" + "balanced-wave-bw3r-material-characterization-9d99485/report.json"
)
const BW4_SOURCE_COMMIT := "4de55aa4521afa9ed2cd596199d809a0781b8ba2"
const BW4_REPORT_SHA256 := "f4a7291849d53540f31d58f40be97f26f01ad9cb76a2e2ae6fedabd56e0925c3"
const BW4_REPORT_LOCATOR := (
	"SporeSpore_Evidence/" + "balanced-wave-bw4-material-characterization-4de55aa/report.json"
)
const BW5V_SOURCE_COMMIT := "2a5eb94dca81a8c638e31a0d7c9692c270b44ca6"
const BW5V_REPORT_SHA256 := "a99a7f2aa9798d26c7a4df9e9b218a5979195eb05dc97b02cd36a5dc21d45d84"
const BW5V_REPORT_LOCATOR := (
	"SporeSpore_Evidence/" + "balanced-wave-bw5v-material-characterization-2a5eb94/report.json"
)
const BW5C_SOURCE_COMMIT := "dca2618bd1cb42768235bc69711eb3dab6b2379a"
const BW5C_REPORT_SHA256 := "067b033266166b15eb0e9f98a5962fdfe7bc199a0af335a64bbb44cc18a09143"
const BW5C_REPORT_LOCATOR := (
	"SporeSpore_Evidence/" + "balanced-wave-bw5c-material-characterization-dca2618/report.json"
)
const BW20F_SOURCE_COMMIT := "476aa4ea521a519a6cd91ef12f265cdb26245839"
const BW20F_REPORT_SHA256 := "f0a279fb9660554a0d4997c6b8adb5c767bc3f92f2497694448429f142155030"
const BW20F_REPORT_LOCATOR := (
	"SporeSpore_Evidence/" + "balanced-wave-bw20f-material-characterization-476aa4e/report.json"
)
const BW22M_SOURCE_COMMIT := "ff9a2cca466984e863ffb4c9063267231186618f"
const BW22M_REPORT_SHA256 := "cfce09d78192aaf280f44e4ec310e0c5760c687892b5f8b3d346cbaa13a1c03c"
const BW22M_REPORT_LOCATOR := (
	"SporeSpore_Evidence/" + "balanced-wave-bw22m-material-characterization-ff9a2cc/report.json"
)
const BW24M_SOURCE_COMMIT := "730fa100d14f427c6ccf09e83f30d4716e0f00e2"
const BW24M_REPORT_SHA256 := "141d31074e1422228e7e4b91a1f25c80c7a076e99d59cc2aad83c499d86ece9b"
const BW24M_REPORT_LOCATOR := (
	"SporeSpore_Evidence/" + "balanced-wave-bw24m-material-characterization-730fa10/report.json"
)
const BW27M_SOURCE_COMMIT := "a219ba86f8033971c6025edb4e45d04d651a73ee"
const BW27M_REPORT_SHA256 := "eb44e73c8494becd7d5bfc777f08630b3442cade64971a203079aadad29ccae3"
const BW27M_REPORT_LOCATOR := (
	"SporeSpore_Evidence/" + "balanced-wave-bw27m-material-characterization-a219ba8/report.json"
)
const LEGACY_SOURCE_COMMIT := "d3d5cd1eb47d5fa9dc06106759cce4b01d4c3bd4"
const LEGACY_REPORT_SHA256 := "f673eceb7e67a395943ebf7e00927a031d221a60eef371b1505b4a680db8a795"
const LEGACY_REPORT_LOCATOR := "SporeSpore_Evidence/godot-jolt-legacy-material-d3d5cd1/report.json"
const LEGACY_PROFILE_ID := "godot_jolt_legacy_mu180_d3d5cd1_v1"
const P5M1_R1_PROFILE_IDS := [
	"godot_jolt_p5m1r1_mu000_v1",
	"godot_jolt_p5m1r1_mu020_v1",
	"godot_jolt_p5m1r1_mu040_v1",
	"godot_jolt_p5m1r1_mu060_v1",
	"godot_jolt_p5m1r1_mu080_v1",
	"godot_jolt_p5m1r1_mu100_v1",
	"godot_jolt_p5m1r1_mu180_v1",
]
const BW3_PROFILE_IDS := [
	"godot_jolt_bw3_mu030_v1",
	"godot_jolt_bw3_mu070_v1",
	"godot_jolt_bw3_mu120_v1",
]
const BW3R_PROFILE_IDS := [
	"godot_jolt_bw3r_mu025_v1",
	"godot_jolt_bw3r_mu055_v1",
	"godot_jolt_bw3r_mu110_v1",
]
const BW4_PROFILE_IDS := [
	"godot_jolt_bw4_mu015_v1",
	"godot_jolt_bw4_mu050_v1",
	"godot_jolt_bw4_mu090_v1",
	"godot_jolt_bw4_mu140_v1",
]
const BW5V_PROFILE_IDS := [
	"godot_jolt_bw5v_mu005_v1",
	"godot_jolt_bw5v_mu065_v1",
	"godot_jolt_bw5v_mu130_v1",
]
const BW5C_PROFILE_IDS := [
	"godot_jolt_bw5c_mu012_v1",
	"godot_jolt_bw5c_mu048_v1",
	"godot_jolt_bw5c_mu095_v1",
	"godot_jolt_bw5c_mu150_v1",
]
const BW20F_PROFILE_IDS := [
	"godot_jolt_bw20f_mu009_v1",
	"godot_jolt_bw20f_mu037_v1",
	"godot_jolt_bw20f_mu076_v1",
	"godot_jolt_bw20f_mu118_v1",
]
const BW22M_PROFILE_IDS := [
	"godot_jolt_bw22m_mu057_v1",
	"godot_jolt_bw22m_mu069_v1",
	"godot_jolt_bw22m_mu081_v1",
]
const BW24M_PROFILE_IDS := [
	"godot_jolt_bw24m_mu059_v1",
	"godot_jolt_bw24m_mu071_v1",
	"godot_jolt_bw24m_mu083_v1",
]
const BW27M_PROFILE_IDS := [
	"godot_jolt_bw27m_mu062_v1",
	"godot_jolt_bw27m_mu074_v1",
	"godot_jolt_bw27m_mu086_v1",
]
const PROFILE_SPECS := {
	LEGACY_PROFILE_ID:
	{
		"authored_friction": 1.8,
		"characterized_friction_coefficient": 1.0,
		"minimum_lower_empirical_ratio": 1.7843903657805014,
		"replicate_brackets_n": [[70.0, 72.0], [70.0, 72.0], [70.0, 72.0]],
		"campaign_role": "historical_legacy_default",
		"characterization_source_commit": LEGACY_SOURCE_COMMIT,
		"characterization_report_sha256": LEGACY_REPORT_SHA256,
		"characterization_report_locator": LEGACY_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_p5m1r1_mu000_v1":
	{
		"authored_friction": 0.0,
		"characterized_friction_coefficient": 0.0,
		"minimum_lower_empirical_ratio": 0.0,
		"replicate_brackets_n": [],
		"campaign_role": "fail_safe_negative_control",
		"characterization_source_commit": P5M1_R1_SOURCE_COMMIT,
		"characterization_report_sha256": P5M1_R1_REPORT_SHA256,
		"characterization_report_locator": P5M1_R1_REPORT_LOCATOR,
		"negative_control": true,
	},
	"godot_jolt_p5m1r1_mu020_v1":
	{
		"authored_friction": 0.2,
		"characterized_friction_coefficient": 0.17,
		"minimum_lower_empirical_ratio": 0.178432416069519,
		"replicate_brackets_n": [[7.0, 9.0], [7.0, 9.0], [7.0, 9.0]],
		"campaign_role": "lower_diagnostic",
		"characterization_source_commit": P5M1_R1_SOURCE_COMMIT,
		"characterization_report_sha256": P5M1_R1_REPORT_SHA256,
		"characterization_report_locator": P5M1_R1_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_p5m1r1_mu040_v1":
	{
		"authored_friction": 0.4,
		"characterized_friction_coefficient": 0.38,
		"minimum_lower_empirical_ratio": 0.382421187990019,
		"replicate_brackets_n": [[15.0, 17.0], [15.0, 17.0], [15.0, 17.0]],
		"campaign_role": "lower_diagnostic",
		"characterization_source_commit": P5M1_R1_SOURCE_COMMIT,
		"characterization_report_sha256": P5M1_R1_REPORT_SHA256,
		"characterization_report_locator": P5M1_R1_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_p5m1r1_mu060_v1":
	{
		"authored_friction": 0.6,
		"characterized_friction_coefficient": 0.58,
		"minimum_lower_empirical_ratio": 0.586461846703393,
		"replicate_brackets_n": [[23.0, 24.0], [23.0, 24.0], [23.0, 24.0]],
		"campaign_role": "primary",
		"characterization_source_commit": P5M1_R1_SOURCE_COMMIT,
		"characterization_report_sha256": P5M1_R1_REPORT_SHA256,
		"characterization_report_locator": P5M1_R1_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_p5m1r1_mu080_v1":
	{
		"authored_friction": 0.8,
		"characterized_friction_coefficient": 0.79,
		"minimum_lower_empirical_ratio": 0.790486780424924,
		"replicate_brackets_n": [[31.0, 32.0], [31.0, 32.0], [31.0, 32.0]],
		"campaign_role": "primary",
		"characterization_source_commit": P5M1_R1_SOURCE_COMMIT,
		"characterization_report_sha256": P5M1_R1_REPORT_SHA256,
		"characterization_report_locator": P5M1_R1_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_p5m1r1_mu100_v1":
	{
		"authored_friction": 1.0,
		"characterized_friction_coefficient": 0.99,
		"minimum_lower_empirical_ratio": 0.994542505667106,
		"replicate_brackets_n": [[39.0, 40.0], [39.0, 40.0], [39.0, 40.0]],
		"campaign_role": "primary",
		"characterization_source_commit": P5M1_R1_SOURCE_COMMIT,
		"characterization_report_sha256": P5M1_R1_REPORT_SHA256,
		"characterization_report_locator": P5M1_R1_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_p5m1r1_mu180_v1":
	{
		"authored_friction": 1.8,
		"characterized_friction_coefficient": 1.0,
		"minimum_lower_empirical_ratio": 1.78439054471982,
		"replicate_brackets_n": [[70.0, 71.0], [70.0, 71.0], [70.0, 71.0]],
		"campaign_role": "primary_legacy_authored_cell",
		"characterization_source_commit": P5M1_R1_SOURCE_COMMIT,
		"characterization_report_sha256": P5M1_R1_REPORT_SHA256,
		"characterization_report_locator": P5M1_R1_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw3_mu030_v1":
	{
		"authored_friction": 0.3,
		"characterized_friction_coefficient": 0.28,
		"minimum_lower_empirical_ratio": 0.28042017626632176,
		"replicate_brackets_n": [[11.0, 13.0], [11.0, 13.0], [11.0, 13.0]],
		"campaign_role": "bw3_validation",
		"characterization_source_commit": BW3_SOURCE_COMMIT,
		"characterization_report_sha256": BW3_REPORT_SHA256,
		"characterization_report_locator": BW3_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw3_mu070_v1":
	{
		"authored_friction": 0.7,
		"characterized_friction_coefficient": 0.68,
		"minimum_lower_empirical_ratio": 0.6884732191182156,
		"replicate_brackets_n": [[27.0, 28.0], [27.0, 28.0], [27.0, 28.0]],
		"campaign_role": "bw3_validation",
		"characterization_source_commit": BW3_SOURCE_COMMIT,
		"characterization_report_sha256": BW3_REPORT_SHA256,
		"characterization_report_locator": BW3_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw3_mu120_v1":
	{
		"authored_friction": 1.2,
		"characterized_friction_coefficient": 1.0,
		"minimum_lower_empirical_ratio": 1.1985757500551864,
		"replicate_brackets_n": [[47.0, 48.0], [47.0, 48.0], [47.0, 48.0]],
		"campaign_role": "bw3_validation",
		"characterization_source_commit": BW3_SOURCE_COMMIT,
		"characterization_report_sha256": BW3_REPORT_SHA256,
		"characterization_report_locator": BW3_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw3r_mu025_v1":
	{
		"authored_friction": 0.25,
		"characterized_friction_coefficient": 0.22,
		"minimum_lower_empirical_ratio": 0.22942660400069761,
		"replicate_brackets_n": [[9.0, 11.0], [9.0, 11.0], [9.0, 11.0]],
		"campaign_role": "bw3r_independent_validation",
		"characterization_source_commit": BW3R_SOURCE_COMMIT,
		"characterization_report_sha256": BW3R_REPORT_SHA256,
		"characterization_report_locator": BW3R_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw3r_mu055_v1":
	{
		"authored_friction": 0.55,
		"characterized_friction_coefficient": 0.53,
		"minimum_lower_empirical_ratio": 0.5354552035269395,
		"replicate_brackets_n": [[21.0, 22.0], [21.0, 22.0], [21.0, 22.0]],
		"campaign_role": "bw3r_independent_validation",
		"characterization_source_commit": BW3R_SOURCE_COMMIT,
		"characterization_report_sha256": BW3R_REPORT_SHA256,
		"characterization_report_locator": BW3R_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw3r_mu110_v1":
	{
		"authored_friction": 1.1,
		"characterized_friction_coefficient": 1.0,
		"minimum_lower_empirical_ratio": 1.096564949574403,
		"replicate_brackets_n": [[43.0, 44.0], [43.0, 44.0], [43.0, 44.0]],
		"campaign_role": "bw3r_independent_validation",
		"characterization_source_commit": BW3R_SOURCE_COMMIT,
		"characterization_report_sha256": BW3R_REPORT_SHA256,
		"characterization_report_locator": BW3R_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw4_mu015_v1":
	{
		"authored_friction": 0.15,
		"characterized_friction_coefficient": 0.12,
		"minimum_lower_empirical_ratio": 0.12744362813307736,
		"replicate_brackets_n": [[5.0, 7.0], [5.0, 7.0], [5.0, 7.0]],
		"campaign_role": "bw4_cold_acceptance",
		"characterization_source_commit": BW4_SOURCE_COMMIT,
		"characterization_report_sha256": BW4_REPORT_SHA256,
		"characterization_report_locator": BW4_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw4_mu050_v1":
	{
		"authored_friction": 0.5,
		"characterized_friction_coefficient": 0.48,
		"minimum_lower_empirical_ratio": 0.4844417851229055,
		"replicate_brackets_n": [[19.0, 21.0], [19.0, 21.0], [19.0, 21.0]],
		"campaign_role": "bw4_cold_acceptance",
		"characterization_source_commit": BW4_SOURCE_COMMIT,
		"characterization_report_sha256": BW4_REPORT_SHA256,
		"characterization_report_locator": BW4_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw4_mu090_v1":
	{
		"authored_friction": 0.9,
		"characterized_friction_coefficient": 0.89,
		"minimum_lower_empirical_ratio": 0.8925120993227881,
		"replicate_brackets_n": [[35.0, 36.0], [35.0, 36.0], [35.0, 36.0]],
		"campaign_role": "bw4_cold_acceptance",
		"characterization_source_commit": BW4_SOURCE_COMMIT,
		"characterization_report_sha256": BW4_REPORT_SHA256,
		"characterization_report_locator": BW4_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw4_mu140_v1":
	{
		"authored_friction": 1.4,
		"characterized_friction_coefficient": 1.0,
		"minimum_lower_empirical_ratio": 1.376945500678404,
		"replicate_brackets_n": [[54.0, 56.0], [54.0, 56.0], [54.0, 56.0]],
		"campaign_role": "bw4_cold_acceptance",
		"characterization_source_commit": BW4_SOURCE_COMMIT,
		"characterization_report_sha256": BW4_REPORT_SHA256,
		"characterization_report_locator": BW4_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw5v_mu005_v1":
	{
		"authored_friction": 0.05,
		"characterized_friction_coefficient": 0.05,
		"minimum_lower_empirical_ratio": 0.051014061933156406,
		"replicate_brackets_n": [[2.0, 3.0], [2.0, 3.0], [2.0, 3.0]],
		"campaign_role": "bw5v_independent_validation",
		"characterization_source_commit": BW5V_SOURCE_COMMIT,
		"characterization_report_sha256": BW5V_REPORT_SHA256,
		"characterization_report_locator": BW5V_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw5v_mu065_v1":
	{
		"authored_friction": 0.65,
		"characterized_friction_coefficient": 0.63,
		"minimum_lower_empirical_ratio": 0.6374671361558075,
		"replicate_brackets_n": [[25.0, 26.0], [25.0, 26.0], [25.0, 26.0]],
		"campaign_role": "bw5v_independent_validation",
		"characterization_source_commit": BW5V_SOURCE_COMMIT,
		"characterization_report_sha256": BW5V_REPORT_SHA256,
		"characterization_report_locator": BW5V_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw5v_mu130_v1":
	{
		"authored_friction": 1.3,
		"characterized_friction_coefficient": 1.0,
		"minimum_lower_empirical_ratio": 1.3011857646200224,
		"replicate_brackets_n": [[51.0, 52.0], [51.0, 52.0], [51.0, 52.0]],
		"campaign_role": "bw5v_independent_validation",
		"characterization_source_commit": BW5V_SOURCE_COMMIT,
		"characterization_report_sha256": BW5V_REPORT_SHA256,
		"characterization_report_locator": BW5V_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw5c_mu012_v1":
	{
		"authored_friction": 0.12,
		"characterized_friction_coefficient": 0.1,
		"minimum_lower_empirical_ratio": 0.10195638022257647,
		"replicate_brackets_n": [[4.0, 6.0], [4.0, 6.0], [4.0, 6.0]],
		"campaign_role": "bw5c_cold_acceptance",
		"characterization_source_commit": BW5C_SOURCE_COMMIT,
		"characterization_report_sha256": BW5C_REPORT_SHA256,
		"characterization_report_locator": BW5C_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw5c_mu048_v1":
	{
		"authored_friction": 0.48,
		"characterized_friction_coefficient": 0.45,
		"minimum_lower_empirical_ratio": 0.4589432881202321,
		"replicate_brackets_n": [[18.0, 20.0], [18.0, 20.0], [18.0, 20.0]],
		"campaign_role": "bw5c_cold_acceptance",
		"characterization_source_commit": BW5C_SOURCE_COMMIT,
		"characterization_report_sha256": BW5C_REPORT_SHA256,
		"characterization_report_locator": BW5C_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw5c_mu095_v1":
	{
		"authored_friction": 0.95,
		"characterized_friction_coefficient": 0.94,
		"minimum_lower_empirical_ratio": 0.9435280065673369,
		"replicate_brackets_n": [[37.0, 38.0], [37.0, 38.0], [37.0, 38.0]],
		"campaign_role": "bw5c_cold_acceptance",
		"characterization_source_commit": BW5C_SOURCE_COMMIT,
		"characterization_report_sha256": BW5C_REPORT_SHA256,
		"characterization_report_locator": BW5C_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw5c_mu150_v1":
	{
		"authored_friction": 1.5,
		"characterized_friction_coefficient": 1.0,
		"minimum_lower_empirical_ratio": 1.4788371649976932,
		"replicate_brackets_n": [[58.0, 60.0], [58.0, 60.0], [58.0, 60.0]],
		"campaign_role": "bw5c_cold_acceptance",
		"characterization_source_commit": BW5C_SOURCE_COMMIT,
		"characterization_report_sha256": BW5C_REPORT_SHA256,
		"characterization_report_locator": BW5C_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw20f_mu009_v1":
	{
		"authored_friction": 0.09,
		"characterized_friction_coefficient": 0.07,
		"minimum_lower_empirical_ratio": 0.07647180229187284,
		"replicate_brackets_n": [[3.0, 4.0], [3.0, 4.0], [3.0, 4.0]],
		"campaign_role": "bw20f_bw19v_b_cold_successor",
		"characterization_source_commit": BW20F_SOURCE_COMMIT,
		"characterization_report_sha256": BW20F_REPORT_SHA256,
		"characterization_report_locator": BW20F_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw20f_mu037_v1":
	{
		"authored_friction": 0.37,
		"characterized_friction_coefficient": 0.35,
		"minimum_lower_empirical_ratio": 0.35691676077326845,
		"replicate_brackets_n": [[14.0, 15.0], [14.0, 15.0], [14.0, 15.0]],
		"campaign_role": "bw20f_bw19v_b_cold_successor",
		"characterization_source_commit": BW20F_SOURCE_COMMIT,
		"characterization_report_sha256": BW20F_REPORT_SHA256,
		"characterization_report_locator": BW20F_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw20f_mu076_v1":
	{
		"authored_friction": 0.76,
		"characterized_friction_coefficient": 0.73,
		"minimum_lower_empirical_ratio": 0.7395363279264746,
		"replicate_brackets_n": [[29.0, 31.0], [29.0, 31.0], [29.0, 31.0]],
		"campaign_role": "bw20f_bw19v_b_cold_successor",
		"characterization_source_commit": BW20F_SOURCE_COMMIT,
		"characterization_report_sha256": BW20F_REPORT_SHA256,
		"characterization_report_locator": BW20F_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw20f_mu118_v1":
	{
		"authored_friction": 1.18,
		"characterized_friction_coefficient": 1.0,
		"minimum_lower_empirical_ratio": 1.1730118440718895,
		"replicate_brackets_n": [[46.0, 47.0], [46.0, 47.0], [46.0, 47.0]],
		"campaign_role": "bw20f_bw19v_b_cold_successor",
		"characterization_source_commit": BW20F_SOURCE_COMMIT,
		"characterization_report_sha256": BW20F_REPORT_SHA256,
		"characterization_report_locator": BW20F_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw22m_mu057_v1":
	{
		"authored_friction": 0.57,
		"characterized_friction_coefficient": 0.56,
		"minimum_lower_empirical_ratio": 0.5609241215877279,
		"replicate_brackets_n": [[22.0, 23.0], [22.0, 23.0], [22.0, 23.0]],
		"campaign_role": "bw22m_bw21l_fresh_material_successor",
		"characterization_source_commit": BW22M_SOURCE_COMMIT,
		"characterization_report_sha256": BW22M_REPORT_SHA256,
		"characterization_report_locator": BW22M_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw22m_mu069_v1":
	{
		"authored_friction": 0.69,
		"characterized_friction_coefficient": 0.68,
		"minimum_lower_empirical_ratio": 0.6884900746592023,
		"replicate_brackets_n": [[27.0, 28.0], [27.0, 28.0], [27.0, 28.0]],
		"campaign_role": "bw22m_bw21l_fresh_material_successor",
		"characterization_source_commit": BW22M_SOURCE_COMMIT,
		"characterization_report_sha256": BW22M_REPORT_SHA256,
		"characterization_report_locator": BW22M_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw22m_mu081_v1":
	{
		"authored_friction": 0.81,
		"characterized_friction_coefficient": 0.79,
		"minimum_lower_empirical_ratio": 0.7905503689593908,
		"replicate_brackets_n": [[31.0, 33.0], [31.0, 33.0], [31.0, 33.0]],
		"campaign_role": "bw22m_bw21l_fresh_material_successor",
		"characterization_source_commit": BW22M_SOURCE_COMMIT,
		"characterization_report_sha256": BW22M_REPORT_SHA256,
		"characterization_report_locator": BW22M_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw24m_mu059_v1":
	{
		"authored_friction": 0.59,
		"characterized_friction_coefficient": 0.58,
		"minimum_lower_empirical_ratio": 0.5864476091642263,
		"replicate_brackets_n": [[23.0, 24.0], [23.0, 24.0], [23.0, 24.0]],
		"campaign_role": "bw24m_bw23y_fresh_material_successor",
		"characterization_source_commit": BW24M_SOURCE_COMMIT,
		"characterization_report_sha256": BW24M_REPORT_SHA256,
		"characterization_report_locator": BW24M_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw24m_mu071_v1":
	{
		"authored_friction": 0.71,
		"characterized_friction_coefficient": 0.68,
		"minimum_lower_empirical_ratio": 0.688520883045167,
		"replicate_brackets_n": [[27.0, 29.0], [27.0, 29.0], [27.0, 29.0]],
		"campaign_role": "bw24m_bw23y_fresh_material_successor",
		"characterization_source_commit": BW24M_SOURCE_COMMIT,
		"characterization_report_sha256": BW24M_REPORT_SHA256,
		"characterization_report_locator": BW24M_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw24m_mu083_v1":
	{
		"authored_friction": 0.83,
		"characterized_friction_coefficient": 0.81,
		"minimum_lower_empirical_ratio": 0.816026345341562,
		"replicate_brackets_n": [[32.0, 33.0], [32.0, 33.0], [32.0, 33.0]],
		"campaign_role": "bw24m_bw23y_fresh_material_successor",
		"characterization_source_commit": BW24M_SOURCE_COMMIT,
		"characterization_report_sha256": BW24M_REPORT_SHA256,
		"characterization_report_locator": BW24M_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw27m_mu062_v1":
	{
		"authored_friction": 0.62,
		"characterized_friction_coefficient": 0.61,
		"minimum_lower_empirical_ratio": 0.6119398367698766,
		"replicate_brackets_n": [[24.0, 25.0], [24.0, 25.0], [24.0, 25.0]],
		"campaign_role": "bw27m_bw28y_fresh_material_successor",
		"characterization_source_commit": BW27M_SOURCE_COMMIT,
		"characterization_report_sha256": BW27M_REPORT_SHA256,
		"characterization_report_locator": BW27M_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw27m_mu074_v1":
	{
		"authored_friction": 0.74,
		"characterized_friction_coefficient": 0.73,
		"minimum_lower_empirical_ratio": 0.739513920992915,
		"replicate_brackets_n": [[29.0, 30.0], [29.0, 30.0], [29.0, 30.0]],
		"campaign_role": "bw27m_bw28y_fresh_material_successor",
		"characterization_source_commit": BW27M_SOURCE_COMMIT,
		"characterization_report_sha256": BW27M_REPORT_SHA256,
		"characterization_report_locator": BW27M_REPORT_LOCATOR,
		"negative_control": false,
	},
	"godot_jolt_bw27m_mu086_v1":
	{
		"authored_friction": 0.86,
		"characterized_friction_coefficient": 0.84,
		"minimum_lower_empirical_ratio": 0.8415623682133044,
		"replicate_brackets_n": [[33.0, 35.0], [33.0, 35.0], [33.0, 35.0]],
		"campaign_role": "bw27m_bw28y_fresh_material_successor",
		"characterization_source_commit": BW27M_SOURCE_COMMIT,
		"characterization_report_sha256": BW27M_REPORT_SHA256,
		"characterization_report_locator": BW27M_REPORT_LOCATOR,
		"negative_control": false,
	},
}


static func ordered_profile_ids(include_legacy: bool = true, include_bw3: bool = true) -> Array:
	var result: Array = []
	if include_legacy:
		result.append(LEGACY_PROFILE_ID)
	result.append_array(P5M1_R1_PROFILE_IDS)
	if include_bw3:
		result.append_array(BW3_PROFILE_IDS)
		result.append_array(BW3R_PROFILE_IDS)
		result.append_array(BW4_PROFILE_IDS)
		result.append_array(BW5V_PROFILE_IDS)
		result.append_array(BW5C_PROFILE_IDS)
		result.append_array(BW20F_PROFILE_IDS)
		result.append_array(BW22M_PROFILE_IDS)
		result.append_array(BW24M_PROFILE_IDS)
		result.append_array(BW27M_PROFILE_IDS)
	return result


static func resolve(profile_id: String) -> Dictionary:
	if not PROFILE_SPECS.has(profile_id):
		return _failure("MATERIAL_PROFILE_ID_UNKNOWN", profile_id)
	var profile := _profile_from_spec(profile_id, PROFILE_SPECS[profile_id])
	var validation := _validate_profile_shape(profile)
	if not bool(validation.get("ok", false)):
		return validation
	var digest := CanonicalJsonScript.sha256(profile)
	return {
		"ok": true,
		"failure_code": "",
		"profile": profile,
		"profile_sha256": digest,
	}


static func validate_for_fixture(
	profile_id: String, fixture_material: Dictionary, realized_solver_policy: Dictionary
) -> Dictionary:
	var resolved := resolve(profile_id)
	if not bool(resolved.get("ok", false)):
		return resolved
	var profile: Dictionary = resolved["profile"]
	var fixture_validation := _validate_fixture_material(
		profile,
		fixture_material,
	)
	if not bool(fixture_validation.get("ok", false)):
		return fixture_validation
	var solver_validation := _validate_solver(profile, realized_solver_policy)
	if not bool(solver_validation.get("ok", false)):
		return solver_validation
	return resolved


static func validate_resolved_profile(
	requested_profile: Dictionary, realized_solver_policy: Dictionary
) -> Dictionary:
	var candidate := requested_profile
	if candidate.is_empty():
		var legacy := resolve(LEGACY_PROFILE_ID)
		if not bool(legacy.get("ok", false)):
			return legacy
		candidate = legacy["profile"]
	var profile_id := String(candidate.get("profile_id", ""))
	var resolved := resolve(profile_id)
	if not bool(resolved.get("ok", false)):
		return resolved
	var expected: Dictionary = resolved["profile"]
	if candidate != expected:
		return _failure("MATERIAL_PROFILE_RECORD_MISMATCH", profile_id)
	var solver_validation := _validate_solver(expected, realized_solver_policy)
	if not bool(solver_validation.get("ok", false)):
		return solver_validation
	return resolved


static func _profile_from_spec(profile_id: String, spec_value: Variant) -> Dictionary:
	var spec: Dictionary = spec_value
	var friction := float(spec["authored_friction"])
	var material := {
		"friction": friction,
		"rough": true,
		"bounce": 0.0,
		"absorbent": true,
	}
	return {
		"schema_version": SCHEMA_VERSION,
		"profile_id": profile_id,
		"adapter_id": ADAPTER_ID,
		"physics_engine": PHYSICS_ENGINE,
		"solver_policy_id": SOLVER_POLICY_ID,
		"physics_hz": PHYSICS_HZ,
		"solver_velocity_steps": SOLVER_VELOCITY_STEPS,
		"solver_position_steps": SOLVER_POSITION_STEPS,
		"body_material": material.duplicate(true),
		"ground_material": material.duplicate(true),
		"material_combine_rule": MATERIAL_COMBINE_RULE,
		"authored_friction": friction,
		"characterized_friction_coefficient": float(spec["characterized_friction_coefficient"]),
		"minimum_lower_empirical_ratio": float(spec["minimum_lower_empirical_ratio"]),
		"replicate_breakaway_brackets_n": (spec["replicate_brackets_n"] as Array).duplicate(true),
		"campaign_role": String(spec["campaign_role"]),
		"characterization_source_commit": String(spec["characterization_source_commit"]),
		"characterization_report_sha256": String(spec["characterization_report_sha256"]),
		"characterization_report_locator": String(spec["characterization_report_locator"]),
		"negative_control": bool(spec["negative_control"]),
		"authored_value_outside_documented_range": friction > 1.0,
		"cross_engine_equivalent": false,
		"locomotion_robustness": false,
		"continuous_friction_coverage": false,
		"completed_sdk": false,
	}


static func _validate_profile_shape(profile: Dictionary) -> Dictionary:
	var coefficient := float(profile.get("characterized_friction_coefficient", NAN))
	var friction := float(profile.get("authored_friction", NAN))
	if (
		String(profile.get("schema_version", "")) != SCHEMA_VERSION
		or String(profile.get("adapter_id", "")) != ADAPTER_ID
		or String(profile.get("physics_engine", "")) != PHYSICS_ENGINE
		or String(profile.get("solver_policy_id", "")) != SOLVER_POLICY_ID
		or int(profile.get("physics_hz", -1)) != PHYSICS_HZ
		or int(profile.get("solver_velocity_steps", -1)) != SOLVER_VELOCITY_STEPS
		or int(profile.get("solver_position_steps", -1)) != SOLVER_POSITION_STEPS
		or not is_finite(friction)
		or friction < 0.0
		or not is_finite(coefficient)
		or coefficient < 0.0
		or coefficient > 1.0
		or String(profile.get("characterization_source_commit", "")).length() != 40
		or String(profile.get("characterization_report_sha256", "")).length() != 64
		or bool(profile.get("cross_engine_equivalent", true))
		or bool(profile.get("locomotion_robustness", true))
		or bool(profile.get("continuous_friction_coverage", true))
		or bool(profile.get("completed_sdk", true))
	):
		return _failure(
			"MATERIAL_PROFILE_SHAPE_INVALID",
			String(profile.get("profile_id", "")),
		)
	for side in ["body_material", "ground_material"]:
		var material_value: Variant = profile.get(side, {})
		if typeof(material_value) != TYPE_DICTIONARY:
			return _failure("MATERIAL_PROFILE_MATERIAL_INVALID", side)
		var material: Dictionary = material_value
		if not _material_matches(material, friction):
			return _failure("MATERIAL_PROFILE_MATERIAL_INVALID", side)
	return {"ok": true, "failure_code": ""}


static func _validate_fixture_material(
	profile: Dictionary, fixture_material: Dictionary
) -> Dictionary:
	if not _material_matches(
		fixture_material,
		float(profile["authored_friction"]),
	):
		return _failure(
			"MATERIAL_PROFILE_FIXTURE_MISMATCH",
			String(profile["profile_id"]),
		)
	return {"ok": true, "failure_code": ""}


static func _validate_solver(profile: Dictionary, realized_solver_policy: Dictionary) -> Dictionary:
	if (
		(
			String(realized_solver_policy.get("solver_policy_id", ""))
			!= String(profile["solver_policy_id"])
		)
		or (
			String(realized_solver_policy.get("physics_engine", ""))
			!= String(profile["physics_engine"])
		)
		or int(realized_solver_policy.get("physics_hz", -1)) != int(profile["physics_hz"])
		or (
			int(realized_solver_policy.get("solver_velocity_steps", -1))
			!= int(profile["solver_velocity_steps"])
		)
		or (
			int(realized_solver_policy.get("solver_position_steps", -1))
			!= int(profile["solver_position_steps"])
		)
	):
		return _failure(
			"MATERIAL_PROFILE_SOLVER_MISMATCH",
			String(profile["profile_id"]),
		)
	return {"ok": true, "failure_code": ""}


static func _material_matches(material: Dictionary, friction: float) -> bool:
	return (
		absf(float(material.get("friction", NAN)) - friction) <= 1.0e-6
		and bool(material.get("rough", false))
		and absf(float(material.get("bounce", NAN))) <= 1.0e-9
		and bool(material.get("absorbent", false))
	)


static func _failure(code: String, detail: String = "") -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"failure_detail": detail,
	}
