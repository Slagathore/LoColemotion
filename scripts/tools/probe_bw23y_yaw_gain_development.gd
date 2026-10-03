extends "res://tests/test_sdk_balanced_wave_bw22l_lateral_development.gd"
# gdlint: disable=max-line-length

## Nonretained BW23Y yaw-authority development probe.
##
## This script may open one real Godot/Jolt world, but only on BW22L values and
## seeds whose outcomes are already exposed. It is not a campaign worker, does
## not accept fresh successor values, writes no retained evidence, and grants
## no selection or physical authority.

const PROBE_SCHEMA := "sporespore_bw23y_yaw_gain_development_probe_v1"
const PROBE_PREFIX := "BW23Y_YAW_GAIN_DEVELOPMENT_PROBE "
const PROBE_POLICY_ID := "sporespore_balanced_wave_bw23y_b_v1"
const PROBE_CANDIDATE_ID := "BW23Y-B-DEVELOPMENT"
const ALLOWED_SEEDS := [24011, 24012, 24013, 24014]
const PROFILE_BY_TOKEN := {
	"057": {
		"profile_id": "godot_jolt_bw22m_mu057_v1",
		"profile_digest": "sha256:754c2f45b19dea315bd3527db8b8b87041be57cb7e4999412710d82c7c57903f",
		"authored_friction": 0.57,
	},
	"069": {
		"profile_id": "godot_jolt_bw22m_mu069_v1",
		"profile_digest": "sha256:a66f00fb0836a0838ab20e3f54c531ee5e9a6ea50180780e81e4f6106aad5ff3",
		"authored_friction": 0.69,
	},
	"081": {
		"profile_id": "godot_jolt_bw22m_mu081_v1",
		"profile_digest": "sha256:9446ba227a7a80f7592ffb7e358b8903a4e7afeb7297d5ba94dab87be8e33cbd",
		"authored_friction": 0.81,
	},
}
const DECLARED_WALKING_KEYS := [
	"bounded_lateral_drift",
	"bounded_tilt",
	"minimum_final_forward_translation",
	"native_sdk_exclusive_post_settle_actuation",
]


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2 or arguments.size() > 3:
		_fail_probe("BW23Y_PROBE_REQUIRES_PROFILE_TOKEN_AND_EXPOSED_SEED")
		return
	var profile_token := String(arguments[0])
	var seed := int(String(arguments[1]))
	var preflight_only := arguments.size() == 3 and String(arguments[2]) == "preflight"
	if arguments.size() == 3 and not preflight_only:
		_fail_probe("BW23Y_PROBE_UNKNOWN_MODE")
		return
	if not PROFILE_BY_TOKEN.has(profile_token) or not ALLOWED_SEEDS.has(seed):
		_fail_probe("BW23Y_PROBE_REJECTS_UNEXPOSED_VALUE_OR_SEED")
		return
	var profile: Dictionary = PROFILE_BY_TOKEN[profile_token]
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var cell := {
		"cell_id": "development_mu%s_s%d_bw23y_b" % [profile_token, seed],
		"cohort": "outcome_exposed_bw22l_development_probe",
		"role": "candidate",
		"campaign_seed": seed,
		"authored_friction": float(profile["authored_friction"]),
		"profile_id": String(profile["profile_id"]),
		"profile_digest": String(profile["profile_digest"]),
		"candidate_id": PROBE_CANDIDATE_ID,
		"candidate_composition_digest": "development-only-unfrozen",
		"controller_policy_id": PROBE_POLICY_ID,
		"runtime_profile_sha256": "development-only-unfrozen",
		"proportional_factor": 1.0,
		"velocity_factor": 1.0,
		"controller_coefficient": float(profile["authored_friction"]),
		"global_requested_correction_scale": 0.5,
	}
	_configure_cell(cell)
	var summary: Dictionary = await _run_cell(0, seed, preflight_only)
	if preflight_only:
		_clear_cell_configuration()
		var preflight_receipt := {
			"schema_version": PROBE_SCHEMA,
			"ok": bool(summary.get("ok", false)),
			"failure_code": String(summary.get("failure_code", "")),
			"controller_policy_id": PROBE_POLICY_ID,
			"profile_token": profile_token,
			"campaign_seed": seed,
			"actual_world_build_count": int(summary.get("actual_world_build_count", 0)),
			"scene_tree_insertion_count": int(summary.get("scene_tree_insertion_count", 0)),
			"physics_state_modified": bool(summary.get("physics_state_modified", false)),
			"locomotion_outcome_exposed": bool(summary.get("locomotion_outcome_exposed", false)),
			"summary": summary.duplicate(true),
			"development_only": true,
			"selection_authority": false,
			"validation_authority": false,
			"physical_acceptance_authority": false,
		}
		print(PROBE_PREFIX, JSON.stringify(preflight_receipt, "", true, true))
		quit(0 if bool(preflight_receipt["ok"]) else 1)
		return
	var receipt := _bw22l_physical_cell_receipt(cell, summary)
	_clear_cell_configuration()
	var inherited_walking: Dictionary = receipt.get("walking_gate_receipts", {})
	var projected_walking := {}
	var failed_count := 0
	for key in DECLARED_WALKING_KEYS:
		var passed := bool(inherited_walking.get(key, false))
		projected_walking[key] = passed
		if not passed:
			failed_count += 1
	receipt["schema_version"] = PROBE_SCHEMA
	receipt["campaign_id"] = "BW23Y-NONRETAINED-DEVELOPMENT-PROBE"
	receipt["gate_id"] = "NONE"
	receipt["controller_coefficient"] = float(profile["authored_friction"])
	receipt["declared_controller_policy_id"] = PROBE_POLICY_ID
	receipt["walking_gate_receipts"] = projected_walking
	receipt["walking_observed"] = failed_count == 0
	receipt["failed_production_walking_gate_count"] = failed_count
	receipt["development_only"] = true
	receipt["retained_evidence"] = false
	receipt["selection_authority"] = false
	receipt["validation_authority"] = false
	receipt["physical_acceptance_authority"] = false
	receipt["source_worktree_may_be_dirty"] = true
	receipt["outcome_values_and_seeds_were_previously_exposed"] = true
	receipt["sdk_authority_failure"] = String(summary.get("sdk_authority_failure", ""))
	receipt["sdk_authority_start_result"] = (
		(summary.get("sdk_authority_start_result", {}) as Dictionary).duplicate(true)
	)
	receipt["sdk_failure_codes"] = (
		(summary.get("sdk_authority_summary", {}) as Dictionary).get("failure_codes", []).duplicate()
	)
	receipt["role_gate_passed"] = _role_gate_passed(receipt)
	receipt["harness_passed"] = bool(receipt["role_gate_passed"])
	print(PROBE_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(receipt.get("role_gate_passed", false)) else 1)


func _fail_probe(code: String) -> void:
	print(
		PROBE_PREFIX,
		JSON.stringify(
			{
				"schema_version": PROBE_SCHEMA,
				"ok": false,
				"failure_code": code,
				"world_build_count": 0,
				"development_only": true,
				"selection_authority": false,
				"physical_acceptance_authority": false,
			},
			"",
			true,
			true,
		),
	)
	quit(1)
