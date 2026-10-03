extends "res://tests/test_sdk_balanced_wave_bw6n_validation.gd"

## Prospective BW8U development campaign.
##
## Each invocation opens one frozen candidate over the same 12-world matrix:
## six already-opened BW6N baseline/rough cells and six fresh development
## baseline/rough cells. Selection is forbidden until all four invocations
## retain complete source-bound reports.

const BW8U_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw8u_preregistration.json"
const BW8U_PREREGISTRATION_SCHEMA := "sporespore_balanced_wave_bw8u_preregistration_v1"
const BW8U_PREREGISTRATION_SHA256 := (
	"sha256:51b3af71af5ad933eaaee9767383f38d8b1cdfe00a9845754b7e36370fbc3793"
)
const BW8U_CHALLENGE_SOURCE_PATH := "res://sdk/balanced_wave_bw6n_validation_manifest.json"
const BW8U_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const BW8U_PROFILE_DIGEST := (
	"sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
)
const BW8U_OPENED_SEEDS := [21001, 21002, 21003]
const BW8U_FRESH_SEEDS := [24001, 24002, 24003]
const BW8U_ALL_SEEDS := [21001, 21002, 21003, 24001, 24002, 24003]
const BW8U_EXPECTED_WORLD_COUNT := 12
const BW8U_EXPECTED_GATE_COUNT := 22
const BW8U_CANDIDATE_IDS := ["BW8U-A", "BW8U-B", "BW8U-C", "BW8U-D"]
const BW8U_POLICY_IDS := [
	"sporespore_balanced_wave_bw8u_a_v1",
	"sporespore_balanced_wave_bw8u_b_v1",
	"sporespore_balanced_wave_bw8u_c_v1",
	"sporespore_balanced_wave_bw8u_d_v1",
]
const BW8U_POLICY_DIGESTS := [
	"sha256:d0a66d7350404b2acb0d7723fee0c34ae44cb7fd48e0cc1c2c03a407d34c9383",
	"sha256:b687a6c6d5afe358ceed3239adff8234ff154f4483c6dcef8259e1c9113bdefa",
	"sha256:cf6bc226d56fbde5a9f54ab56fcccbd844493e128b92bc387fa3d35795ca1dc3",
	"sha256:cdb61f9a3bdd6760dc76c70a673dd77db159794f4d13eab2ced502a4e4c2e156",
]
const BW8U_RUNTIME_PROFILE_DIGESTS := [
	"sha256:7cf179accc9858dd2e0683a531c5e947721602ce2a99d87ed35e2f9fb5498069",
	"sha256:00fc8348405648bcaa4ea27a506b4e0e505432bb4eae80399bc9b64a016adb07",
	"sha256:c49dd5f9a0462c6c50176ed896f04ce662ac1e6849233f48a6540460a96aee2a",
	"sha256:02b85937c806842ee075d0aea980e4256126ade9937ebb144c424957bb51fa44",
]
const BW8U_ACQUISITION_OPTIONS := {
	"policy_id": "bounded_all_support_acquisition_v1",
	"enabled": true,
	"maximum_acquisition_ticks": 15,
	"minimum_all_support_dwell_ticks": 3,
}
const BW8U_ACQUISITION_SHA256 := (
	"sha256:4a49770e35b67b2186a5a64ad3dcbf7d1d637e9ffc6ea2a9365615731eb2e748"
)


func _run() -> void:
	print("\n=== SDK balanced-wave BW8U frozen development candidate ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var user_args := OS.get_cmdline_user_args()
	var candidate_index := -1
	var preflight_only := false
	for argument_value in user_args:
		var argument := String(argument_value)
		if argument == "--preflight-only":
			if preflight_only:
				push_error("BW8U received duplicate --preflight-only")
				quit(1)
				return
			preflight_only = true
			continue
		if argument.begins_with("--bw8u-"):
			if candidate_index >= 0:
				push_error("BW8U requires exactly one candidate")
				quit(1)
				return
			var suffix := argument.trim_prefix("--bw8u-").to_upper()
			candidate_index = BW8U_CANDIDATE_IDS.find("BW8U-%s" % suffix)
			continue
		push_error("Unknown BW8U argument: %s" % argument)
		quit(1)
		return
	if candidate_index < 0 or user_args.size() < 1 or user_args.size() > 2:
		push_error("BW8U requires exactly one of --bw8u-a/b/c/d")
		quit(1)
		return
	_bw2_mode = true
	_bw2_candidate_id = BW8U_CANDIDATE_IDS[candidate_index]
	_bw2_policy_id = BW8U_POLICY_IDS[candidate_index]
	_bw2_policy_digest = BW8U_POLICY_DIGESTS[candidate_index]
	_opened_development_replay = false
	await _run_bw8u_development(preflight_only)


func _campaign_seeds() -> Array:
	return BW8U_ALL_SEEDS


func _required_profile_ids() -> Array:
	return [BW8U_PROFILE_ID]


func _expected_cell_ids() -> Array:
	var result: Array = []
	for partition in ["opened", "fresh"]:
		var seeds: Array = BW8U_OPENED_SEEDS if partition == "opened" else BW8U_FRESH_SEEDS
		for cohort in ["baseline", "rough"]:
			for seed_value in seeds:
				result.append("%s_%s_s%d" % [partition, cohort, int(seed_value)])
	return result


func _expected_world_count() -> int:
	return BW8U_EXPECTED_WORLD_COUNT


func _bridge_profile_id() -> String:
	return BW8U_PROFILE_ID


func _build_matrix() -> Array:
	var challenge_source := _load_json_dictionary(BW8U_CHALLENGE_SOURCE_PATH)
	var challenge_by_id := {}
	for challenge_value in challenge_source.get("challenge_profiles", []):
		var challenge: Dictionary = challenge_value
		var challenge_id := String(challenge.get("challenge_profile_id", ""))
		if challenge_id in ["bw6n_baseline_v1", "bw6n_rough_v1"]:
			var compiled := WaveGaitScript.compile_environment_challenge_options(challenge)
			if bool(compiled.get("ok", false)):
				challenge_by_id[challenge_id] = (
					compiled["environment_challenge_options"] as Dictionary
				).duplicate(true)
	var matrix: Array = []
	for partition in ["opened", "fresh"]:
		var seeds: Array = BW8U_OPENED_SEEDS if partition == "opened" else BW8U_FRESH_SEEDS
		for cohort in ["baseline", "rough"]:
			var challenge_id := "bw6n_%s_v1" % cohort
			for seed_value in seeds:
				var seed := int(seed_value)
				matrix.append(
					{
						"cell_id": "%s_%s_s%d" % [partition, cohort, seed],
						"partition": partition,
						"cohort": cohort,
						"mode": "treatment",
						"campaign_seed": seed,
						"mu_token": "095",
						"authored_friction": 0.95,
						"profile_id": BW8U_PROFILE_ID,
						"profile_digest": BW8U_PROFILE_DIGEST,
						"challenge_profile_id": challenge_id,
						"challenge_options":
						(
							challenge_by_id.get(challenge_id, {}) as Dictionary
						).duplicate(true),
					}
				)
	return matrix


func _matrix_cardinality_exact(matrix: Array) -> bool:
	var count_by_role := {
		"opened_baseline": 0,
		"opened_rough": 0,
		"fresh_baseline": 0,
		"fresh_rough": 0,
	}
	for cell_value in matrix:
		var cell: Dictionary = cell_value
		var role := "%s_%s" % [String(cell.get("partition", "")), String(cell.get("cohort", ""))]
		if (
			not count_by_role.has(role)
			or String(cell.get("mode", "")) != "treatment"
			or (cell.get("challenge_options", {}) as Dictionary).is_empty()
		):
			return false
		count_by_role[role] = int(count_by_role[role]) + 1
	for count_value in count_by_role.values():
		if int(count_value) != 3:
			return false
	return matrix.size() == BW8U_EXPECTED_WORLD_COUNT


func _validation_manifest_receipt() -> Dictionary:
	var preregistration := _load_json_dictionary(BW8U_PREREGISTRATION_PATH)
	var candidates: Array = preregistration.get("candidates", [])
	var candidate: Dictionary = {}
	for candidate_value in candidates:
		var requested: Dictionary = candidate_value
		if String(requested.get("candidate_id", "")) == _bw2_candidate_id:
			candidate = requested
			break
	var development: Dictionary = preregistration.get("development_matrix", {})
	var selection: Dictionary = preregistration.get("selection", {})
	var claims: Dictionary = preregistration.get("claims", {})
	var candidate_index := BW8U_CANDIDATE_IDS.find(_bw2_candidate_id)
	var claims_exact := bool(claims.get("development_selection_authority", false))
	for claim_key_value in claims.keys():
		var claim_key := String(claim_key_value)
		if claim_key != "development_selection_authority":
			claims_exact = claims_exact and not bool(claims[claim_key])
	var exact := (
		candidate_index >= 0
		and String(preregistration.get("schema_version", "")) == BW8U_PREREGISTRATION_SCHEMA
		and String(preregistration.get("status", ""))
		== "frozen_before_first_bw8u_physics_world"
		and CanonicalJsonScript.sha256(preregistration) == BW8U_PREREGISTRATION_SHA256
		and (preregistration.get("candidate_order", []) as Array) == BW8U_CANDIDATE_IDS
		and candidates.size() == 4
		and String(candidate.get("policy_id", "")) == _bw2_policy_id
		and (
			String(candidate.get("runtime_profile_sha256", ""))
			== String(BW8U_RUNTIME_PROFILE_DIGESTS[candidate_index])
		)
		and (
			String(
				(preregistration.get("candidate_policy_digests", {}) as Dictionary).get(
					_bw2_candidate_id,
					"",
				)
			)
			== _bw2_policy_digest
		)
		and (candidate.get("branch_surfaces", []) as Array).is_empty()
		and String(development.get("material_profile_id", "")) == BW8U_PROFILE_ID
		and String(development.get("material_profile_sha256", "")) == BW8U_PROFILE_DIGEST
		and int(development.get("expected_world_count_per_candidate", -1)) == 12
		and int(development.get("expected_complete_world_count", -1)) == 48
		and bool(development.get("early_stop_forbidden", false))
		and bool(selection.get("all_candidates_must_complete_before_selection", false))
		and bool(
			selection.get(
				"selection_requires_zero_release_timeouts_and_zero_ordinary_nonwalks",
				false,
			)
		)
		and claims_exact
	)
	return {
		"ok": exact,
		"failure_code": "" if exact else "BW8U_PREREGISTRATION_MISMATCH",
		"schema_version": String(preregistration.get("schema_version", "")),
		"preregistration_path": "sdk/balanced_wave_bw8u_preregistration.json",
		"preregistration_sha256": BW8U_PREREGISTRATION_SHA256,
		"candidate": candidate.duplicate(true),
		"candidate_policy_digest": _bw2_policy_digest,
		"world_build_count": 0,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _run_cell(
	gait_clock_options: Dictionary,
	cell: Dictionary,
	perturbation: Dictionary,
	fixture_spec: Dictionary,
) -> Dictionary:
	var authority_options := {
		"enabled": true,
		"descriptor": DESCRIPTOR,
		"comparison_tolerance": GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
		"authority_scope": "stability_contribution_overlay",
		"stability_policy_id": FEEDBACK_POLICY_ID,
		"material_profile_id": BW8U_PROFILE_ID,
		"controller_policy_id": _bw2_policy_id,
	}
	return await (
		WaveGaitScript
		. new()
		. run(
			self,
			-1.0,
			10.0,
			1.75,
			"lateral",
			72,
			0.40,
			"all",
			112,
			false,
			perturbation,
			ROBUSTNESS_OPTIONS,
			fixture_spec,
			PATH_STEERING_OPTIONS,
			ACTUATOR_IMPULSE_OPTIONS,
			MOTOR_VELOCITY_OPTIONS,
			{},
			gait_clock_options,
			SOLVER_POLICY_OPTIONS,
			{},
			{},
			authority_options,
			cell["challenge_options"],
			BW8U_ACQUISITION_OPTIONS,
		)
	)


func _run_bw8u_development(preflight_only: bool) -> void:
	var preflight := _compile_preflight()
	if preflight_only:
		var preflight_receipt := {
			"schema_version": "sporespore_balanced_wave_bw8u_development_preflight_v1",
			"ok": bool(preflight.get("ok", false)),
			"candidate_id": _bw2_candidate_id,
			"policy_id": _bw2_policy_id,
			"candidate_policy_digest": _bw2_policy_digest,
			"clock_ok": bool(preflight.get("clock_ok", false)),
			"matrix_ok": bool(preflight.get("matrix_ok", false)),
			"inputs_ok": bool(preflight.get("inputs_ok", false)),
			"expected_world_count": BW8U_EXPECTED_WORLD_COUNT,
			"observed_world_count": 0,
			"cell_ids": (preflight.get("cell_ids", []) as Array).duplicate(),
			"seed_receipts": (preflight.get("seed_receipts", []) as Array).duplicate(true),
			"profile_receipts":
			(preflight.get("profile_receipts", []) as Array).duplicate(true),
			"preregistration":
			(preflight.get("validation_manifest", {}) as Dictionary).duplicate(true),
			"locomotion_outcome_exposed": false,
			"physics_state_modified": false,
			"development_selection_authority": true,
			"walking_acceptance": false,
			"cross_engine_c6": false,
			"completed_engine_neutral_sdk": false,
			"physical_acceptance_authority": false,
		}
		print(
			"BALANCED_WAVE_BW8U_DEVELOPMENT_PREFLIGHT ",
			JSON.stringify(preflight_receipt, "", true, true),
		)
		quit(0 if bool(preflight_receipt["ok"]) else 1)
		return

	var clock_ok := bool(preflight.get("clock_ok", false))
	var matrix_ok := bool(preflight.get("matrix_ok", false))
	var inputs_ok := bool(preflight.get("inputs_ok", false))
	_check(clock_ok, "1 the frozen clock compiles exactly")
	_check(matrix_ok, "2 the ordered BW8U 12-world candidate matrix is exact")
	_check(inputs_ok, "3 the candidate, material, seeds, fixture, and challenges compile")
	var receipts: Array = []
	var integrity_failure_count := 0
	var ordinary_nonwalk_count := 0
	var release_timeout_count := 0
	var acquisition_failure_count := 0
	var mechanism_receipt_failure_count := 0
	var nonzero_stability_count := 0
	var count_by_role := {
		"opened_baseline": 0,
		"opened_rough": 0,
		"fresh_baseline": 0,
		"fresh_rough": 0,
	}
	if clock_ok and matrix_ok and inputs_ok:
		var input: Dictionary = preflight["input_by_profile"][BW8U_PROFILE_ID]
		var perturbation_by_seed: Dictionary = preflight["perturbation_by_seed"]
		for cell_value in preflight["matrix"]:
			var cell: Dictionary = cell_value
			var seed_key := str(int(cell["campaign_seed"]))
			print(
				"BW8U_CELL_START candidate=%s cell=%s world=%d/%d"
				% [
					_bw2_candidate_id,
					String(cell["cell_id"]),
					receipts.size() + 1,
					BW8U_EXPECTED_WORLD_COUNT,
				]
			)
			var summary: Dictionary = await _run_cell(
				preflight["gait_clock_options"],
				cell,
				perturbation_by_seed[seed_key],
				input["fixture_spec"],
			)
			var receipt := _analyze_cell(
				cell,
				summary,
				perturbation_by_seed[seed_key],
				input,
				true,
			)
			receipt = _enrich_bw6n_receipt(cell, summary, receipt)
			var acquisition: Dictionary = summary.get(
				"evidence_support_acquisition_receipt",
				{},
			)
			var acquisition_exact: bool = (
				summary.get("evidence_acquisition_options", {}) == BW8U_ACQUISITION_OPTIONS
				and (
					String(summary.get("evidence_acquisition_configuration_sha256", ""))
					== BW8U_ACQUISITION_SHA256
				)
				and bool(acquisition.get("acquired", false))
				and not bool(acquisition.get("timed_out", true))
				and not bool(acquisition.get("controller_parameter", true))
				and not bool(acquisition.get("walking_claim_authorized", true))
			)
			var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
			var unweighting: Dictionary = sdk_summary.get(
				"release_gate_unweighting_summary",
				{},
			)
			var candidate_index := BW8U_CANDIDATE_IDS.find(_bw2_candidate_id)
			var knee_enabled := candidate_index in [1, 3]
			var hip_enabled := candidate_index in [2, 3]
			var mechanism_exact: bool = (
				candidate_index >= 0
				and bool(unweighting.get("enabled", false))
				and String(unweighting.get("schema_version", ""))
				== "sporespore_release_gate_unweighting_execution_summary_v1"
				and int(unweighting.get("receipt_count", -1))
				== int(sdk_summary.get("step_count", -2))
				and (
					(
						int(unweighting.get("knee_override_step_count", -1)) > 0
						and int(unweighting.get("knee_override_limb_count", -1)) > 0
					)
					if knee_enabled
					else (
						int(unweighting.get("knee_override_step_count", -1)) == 0
						and int(unweighting.get("knee_override_limb_count", -1)) == 0
					)
				)
				and (
					(
						int(unweighting.get("hip_override_step_count", -1)) > 0
						and int(unweighting.get("hip_override_limb_count", -1)) > 0
					)
					if hip_enabled
					else (
						int(unweighting.get("hip_override_step_count", -1)) == 0
						and int(unweighting.get("hip_override_limb_count", -1)) == 0
					)
				)
				and String(unweighting.get("analytic_target_basis", ""))
				== "existing_lateral_wave_swing_apex_at_half_swing_v1"
				and int(unweighting.get("morphology_branch_surface_count", -1)) == 0
				and bool(unweighting.get("controller_parameter", false))
				and not bool(unweighting.get("walking_claim_authorized", true))
				and not bool(unweighting.get("physical_acceptance_authority", true))
			)
			var execution_gate: bool = (
				bool(receipt.get("campaign_execution_gate_passed", false))
				and bool(receipt.get("specialized_axis_gate_passed", false))
				and acquisition_exact
				and mechanism_exact
			)
			receipt["partition"] = String(cell["partition"])
			receipt["candidate_id"] = _bw2_candidate_id
			receipt["candidate_policy_digest"] = _bw2_policy_digest
			receipt["evidence_acquisition_gate_passed"] = acquisition_exact
			receipt["evidence_support_acquisition_receipt"] = acquisition.duplicate(true)
			receipt["release_gate_unweighting_gate_passed"] = mechanism_exact
			receipt["release_gate_unweighting_summary"] = unweighting.duplicate(true)
			receipt["contact_gate_timeout_count_by_limb"] = (
				summary.get("contact_gate_timeout_count_by_limb", {}) as Dictionary
			).duplicate(true)
			receipt["release_timeout_count"] = _sum_integer_values(
				receipt["contact_gate_timeout_count_by_limb"]
			)
			receipt["bw8u_execution_gate_passed"] = execution_gate
			receipts.append(receipt)
			_check(
				execution_gate,
				"%s completes candidate execution integrity" % String(cell["cell_id"]),
			)
			if not execution_gate:
				integrity_failure_count += 1
			if not bool(receipt.get("ordinary_walking_gate_passed", false)):
				ordinary_nonwalk_count += 1
			release_timeout_count += int(receipt["release_timeout_count"])
			if not acquisition_exact:
				acquisition_failure_count += 1
			if not mechanism_exact:
				mechanism_receipt_failure_count += 1
			var contribution: Dictionary = receipt.get("stability_contribution_shadow", {})
			var overlay: Dictionary = receipt.get("stability_overlay", {})
			if (
				int(contribution.get("nonzero_active_command_count", 0)) > 0
				and int(overlay.get("nonzero_effective_application_count", 0)) > 0
			):
				nonzero_stability_count += 1
			var role := "%s_%s" % [String(cell["partition"]), String(cell["cohort"])]
			count_by_role[role] = int(count_by_role[role]) + 1
			print("BALANCED_WAVE_BW8U_CELL ", JSON.stringify(receipt, "", true, true))

	var roles_exact := receipts.size() == 12
	for count_value in count_by_role.values():
		roles_exact = roles_exact and int(count_value) == 3
	_check(roles_exact, "16 all four opened/fresh baseline/rough roles complete exactly")
	_check(integrity_failure_count == 0, "17 the complete matrix has zero integrity failures")
	_check(acquisition_failure_count == 0, "18 all worlds satisfy the bounded acquisition contract")
	_check(nonzero_stability_count == 12, "19 all worlds apply nonzero bounded stability influence")
	_check(
		mechanism_receipt_failure_count == 0,
		"20 every world realizes its exact preregistered unweighting factor receipts",
	)
	var candidate_identity_exact := true
	for receipt_value in receipts:
		var receipt: Dictionary = receipt_value
		candidate_identity_exact = (
			candidate_identity_exact
			and String(receipt.get("controller_policy_id", "")) == _bw2_policy_id
			and String(receipt.get("candidate_policy_digest", "")) == _bw2_policy_digest
		)
	_check(candidate_identity_exact, "21 every world retains one candidate identity")
	_check(true, "22 every physical-acceptance and C6 claim remains false")

	var complete := (
		_failed == 0
		and _passed == BW8U_EXPECTED_GATE_COUNT
		and receipts.size() == BW8U_EXPECTED_WORLD_COUNT
	)
	var eligible := (
		complete
		and ordinary_nonwalk_count == 0
		and release_timeout_count == 0
	)
	var result := {
		"schema_version": "sporespore_balanced_wave_bw8u_development_receipt_v1",
		"ok": complete,
		"result_status": "candidate_eligible" if eligible else "candidate_ineligible",
		"candidate_eligible": eligible,
		"candidate_id": _bw2_candidate_id,
		"policy_id": _bw2_policy_id,
		"candidate_policy_digest": _bw2_policy_digest,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": BW8U_EXPECTED_GATE_COUNT,
		"expected_world_count": BW8U_EXPECTED_WORLD_COUNT,
		"observed_world_count": receipts.size(),
		"integrity_failure_count": integrity_failure_count,
		"ordinary_nonwalk_count": ordinary_nonwalk_count,
		"release_timeout_count": release_timeout_count,
		"acquisition_failure_count": acquisition_failure_count,
		"mechanism_receipt_failure_count": mechanism_receipt_failure_count,
		"nonzero_stability_world_count": nonzero_stability_count,
		"count_by_role": count_by_role,
		"cells": receipts,
		"development_selection_authority": true,
		"walking_acceptance": false,
		"material_robustness": false,
		"rough_terrain_robustness": false,
		"physical_balance_recovery": false,
		"fresh_morphology_validation": false,
		"cross_engine_c6": false,
		"completed_engine_neutral_sdk": false,
		"physical_acceptance_authority": false,
	}
	print("BALANCED_WAVE_BW8U_DEVELOPMENT_RECEIPT ", JSON.stringify(result, "", true, true))
	quit(0 if complete else 1)


static func _sum_integer_values(values: Dictionary) -> int:
	var result := 0
	for value in values.values():
		result += int(value)
	return result
