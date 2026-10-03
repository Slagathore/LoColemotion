extends "res://tests/test_sdk_balanced_wave_bw9l_development.gd"

## Prospectively frozen BW10F development replication.
##
## The physical mechanisms are the complete BW9L factorial under the additive
## v2 receipt-continuity schema. Every cell uses a fresh seed. Development may
## select a hypothesis for later independent validation; it cannot authorize a
## walking, recovery, friction, morphology, or cross-engine claim.

const BW10F_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw10f_preregistration.json"
const BW10F_PREREGISTRATION_SCHEMA := "sporespore_balanced_wave_bw10f_preregistration_v1"
const BW10F_PREREGISTRATION_SHA256 := (
	"sha256:eb460a1b373a5aef4a9f07724d5e08e573fc18f3898cd94401c80047ebfa5148"
)
const BW10F_CHALLENGE_SOURCE_PATH := "res://sdk/balanced_wave_bw6n_validation_manifest.json"
const BW10F_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const BW10F_PROFILE_DIGEST := (
	"sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
)
const BW10F_BASE_CONTROLLER_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const BW10F_FRESH_SEEDS := [25001, 25002, 25003, 25004, 25005, 25006]
const BW10F_EXPECTED_WORLD_COUNT := 12
const BW10F_EXPECTED_GATE_COUNT := 22
const BW10F_CANDIDATE_IDS := ["BW10F-A", "BW10F-B", "BW10F-C", "BW10F-D"]
const BW10F_STABILITY_POLICY_IDS := [
	"sporespore_scheduled_load_transfer_bw10f_a_v2",
	"sporespore_scheduled_load_transfer_bw10f_b_v2",
	"sporespore_scheduled_load_transfer_bw10f_c_v2",
	"sporespore_scheduled_load_transfer_bw10f_d_v2",
]
const BW10F_POLICY_DIGESTS := [
	"sha256:d7f3dd32eaea8d6bac411bb541216eb70f9b291ee88276f46209a15ee0360bce",
	"sha256:c3c9239e7c044b893cb362e4bec33ccca75eec358b956406739ebf38d3bb9751",
	"sha256:43bbf227b85acb15749a3e54cdb9e00e098a1d843e9ad516a4cfdd4f68ba1c03",
	"sha256:1395551e5f7f4feafe78f3bdcb0be21c57c925a381735812156b0181dc5224a8",
]


func _run() -> void:
	print("\n=== SDK balanced-wave BW10F frozen development candidate ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var user_args := OS.get_cmdline_user_args()
	var candidate_index := -1
	var preflight_only := false
	for argument_value in user_args:
		var argument := String(argument_value)
		if argument == "--preflight-only":
			if preflight_only:
				push_error("BW10F received duplicate --preflight-only")
				quit(1)
				return
			preflight_only = true
			continue
		if argument.begins_with("--bw10f-"):
			if candidate_index >= 0:
				push_error("BW10F requires exactly one candidate")
				quit(1)
				return
			var suffix := argument.trim_prefix("--bw10f-").to_upper()
			candidate_index = BW10F_CANDIDATE_IDS.find("BW10F-%s" % suffix)
			continue
		push_error("Unknown BW10F argument: %s" % argument)
		quit(1)
		return
	if candidate_index < 0 or user_args.size() < 1 or user_args.size() > 2:
		push_error("BW10F requires exactly one of --bw10f-a/b/c/d")
		quit(1)
		return
	_bw2_mode = true
	_bw2_candidate_id = BW10F_CANDIDATE_IDS[candidate_index]
	_bw2_policy_id = BW10F_BASE_CONTROLLER_POLICY_ID
	_bw2_policy_digest = BW10F_POLICY_DIGESTS[candidate_index]
	_bw9l_stability_policy_id = BW10F_STABILITY_POLICY_IDS[candidate_index]
	_opened_development_replay = false
	await _run_bw10f_development(preflight_only)


func _campaign_seeds() -> Array:
	return BW10F_FRESH_SEEDS


func _required_profile_ids() -> Array:
	return [BW10F_PROFILE_ID]


func _expected_cell_ids() -> Array:
	var result: Array = []
	for cohort in ["baseline", "rough"]:
		for seed_value in BW10F_FRESH_SEEDS:
			result.append("fresh_%s_s%d" % [cohort, int(seed_value)])
	return result


func _expected_world_count() -> int:
	return BW10F_EXPECTED_WORLD_COUNT


func _bridge_profile_id() -> String:
	return BW10F_PROFILE_ID


func _build_matrix() -> Array:
	var challenge_source := _load_json_dictionary(BW10F_CHALLENGE_SOURCE_PATH)
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
	for cohort in ["baseline", "rough"]:
		var challenge_id := "bw6n_%s_v1" % cohort
		for seed_value in BW10F_FRESH_SEEDS:
			var seed := int(seed_value)
			matrix.append(
				{
					"cell_id": "fresh_%s_s%d" % [cohort, seed],
					"partition": "fresh",
					"cohort": cohort,
					"mode": "treatment",
					"campaign_seed": seed,
					"mu_token": "095",
					"authored_friction": 0.95,
					"profile_id": BW10F_PROFILE_ID,
					"profile_digest": BW10F_PROFILE_DIGEST,
					"challenge_profile_id": challenge_id,
					"challenge_options":
					(
						challenge_by_id.get(challenge_id, {}) as Dictionary
					).duplicate(true),
				}
			)
	return matrix


func _matrix_cardinality_exact(matrix: Array) -> bool:
	var count_by_cohort := {"baseline": 0, "rough": 0}
	var observed_seeds: Dictionary = {}
	for cell_value in matrix:
		var cell: Dictionary = cell_value
		var cohort := String(cell.get("cohort", ""))
		var seed := int(cell.get("campaign_seed", -1))
		if (
			not count_by_cohort.has(cohort)
			or String(cell.get("partition", "")) != "fresh"
			or String(cell.get("mode", "")) != "treatment"
			or not BW10F_FRESH_SEEDS.has(seed)
			or (cell.get("challenge_options", {}) as Dictionary).is_empty()
		):
			return false
		count_by_cohort[cohort] = int(count_by_cohort[cohort]) + 1
		observed_seeds[seed] = int(observed_seeds.get(seed, 0)) + 1
	for count_value in count_by_cohort.values():
		if int(count_value) != 6:
			return false
	for seed_value in BW10F_FRESH_SEEDS:
		if int(observed_seeds.get(int(seed_value), 0)) != 2:
			return false
	return matrix.size() == BW10F_EXPECTED_WORLD_COUNT


func _validation_manifest_receipt() -> Dictionary:
	var preregistration := _load_json_dictionary(BW10F_PREREGISTRATION_PATH)
	var candidates: Array = preregistration.get("candidates", [])
	var candidate: Dictionary = {}
	for candidate_value in candidates:
		var requested: Dictionary = candidate_value
		if String(requested.get("candidate_id", "")) == _bw2_candidate_id:
			candidate = requested
			break
	var development: Dictionary = preregistration.get("development_matrix", {})
	var selection: Dictionary = preregistration.get("selection", {})
	var portable: Dictionary = preregistration.get("portable_implementation", {})
	var mechanism: Dictionary = preregistration.get("mechanism_receipt_eligibility", {})
	var claims: Dictionary = preregistration.get("claims", {})
	var candidate_index := BW10F_CANDIDATE_IDS.find(_bw2_candidate_id)
	var claims_exact := bool(claims.get("development_selection_authority", false))
	for claim_key_value in claims.keys():
		var claim_key := String(claim_key_value)
		if claim_key != "development_selection_authority":
			claims_exact = claims_exact and not bool(claims[claim_key])
	var development_seeds: Array = []
	for seed_value in development.get("fresh_development_seeds", []):
		development_seeds.append(int(seed_value))
	var checks := {
		"candidate_index": candidate_index >= 0,
		"schema_and_status":
		(
			String(preregistration.get("schema_version", ""))
			== BW10F_PREREGISTRATION_SCHEMA
			and String(preregistration.get("status", ""))
			== "frozen_before_first_bw10f_physics_world"
		),
		"canonical_digest":
		CanonicalJsonScript.sha256(preregistration)
		== BW10F_PREREGISTRATION_SHA256,
		"candidate_family":
		(
			(preregistration.get("candidate_order", []) as Array)
			== BW10F_CANDIDATE_IDS
			and candidates.size() == 4
		),
		"candidate_identity":
		(
			String(candidate.get("stability_policy_id", ""))
			== _bw9l_stability_policy_id
			and String(candidate.get("base_controller_policy_id", ""))
			== BW10F_BASE_CONTROLLER_POLICY_ID
			and String(
				(preregistration.get("candidate_policy_digests", {}) as Dictionary).get(
					_bw2_candidate_id,
					"",
				)
			)
			== _bw2_policy_digest
			and (candidate.get("branch_surfaces", []) as Array).is_empty()
		),
		"portable_contract":
		(
			String(portable.get("base_controller_policy_id", ""))
			== BW10F_BASE_CONTROLLER_POLICY_ID
			and String(portable.get("plan_operation", ""))
			== "ss_plan_scheduled_load_transfer_v2_json"
			and String(portable.get("plan_receipt_schema_version", ""))
			== "sporespore_scheduled_load_transfer_receipt_v2"
			and bool(portable.get("plan_receipt_required_for_every_sdk_step", false))
			and int(portable.get("morphology_branch_surface_count", -1)) == 0
		),
		"development_identity":
		(
			String(development.get("material_profile_id", ""))
			== BW10F_PROFILE_ID
			and String(development.get("material_profile_sha256", ""))
			== BW10F_PROFILE_DIGEST
		),
		"development_matrix":
		(
			development_seeds == BW10F_FRESH_SEEDS
			and int(development.get("expected_world_count_per_candidate", -1)) == 12
			and int(development.get("expected_complete_world_count", -1)) == 48
			and bool(development.get("all_cells_are_fresh_to_bw9l", false))
			and bool(development.get("early_stop_forbidden", false))
		),
		"selection_contract":
		(
			bool(selection.get("all_candidates_must_complete_before_selection", false))
			and bool(
				selection.get(
					"treatment_must_be_strictly_lexicographically_better_than_control",
					false,
				)
			)
		),
		"mechanism_contract":
		(
			bool(
				mechanism.get(
					"scheduled_load_transfer_receipt_required_on_every_sdk_step",
					false,
				)
			)
			and bool(mechanism.get("activation_uses_scheduler_boundaries_only", false))
			and int(mechanism.get("morphology_branch_surface_count_must_equal", -1))
			== 0
		),
		"claims": claims_exact,
	}
	var exact := true
	for check_value in checks.values():
		exact = exact and bool(check_value)
	return {
		"ok": exact,
		"failure_code": "" if exact else "BW10F_PREREGISTRATION_MISMATCH",
		"schema_version": String(preregistration.get("schema_version", "")),
		"preregistration_path": "sdk/balanced_wave_bw10f_preregistration.json",
		"preregistration_sha256": BW10F_PREREGISTRATION_SHA256,
		"candidate": candidate.duplicate(true),
		"candidate_policy_digest": _bw2_policy_digest,
		"checks": checks,
		"world_build_count": 0,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _run_bw10f_development(preflight_only: bool) -> void:
	var preflight := _compile_preflight()
	if preflight_only:
		var preflight_receipt := {
			"schema_version": "sporespore_balanced_wave_bw10f_development_preflight_v1",
			"ok": bool(preflight.get("ok", false)),
			"candidate_id": _bw2_candidate_id,
			"policy_id": _bw9l_stability_policy_id,
			"base_controller_policy_id": BW10F_BASE_CONTROLLER_POLICY_ID,
			"candidate_policy_digest": _bw2_policy_digest,
			"clock_ok": bool(preflight.get("clock_ok", false)),
			"matrix_ok": bool(preflight.get("matrix_ok", false)),
			"inputs_ok": bool(preflight.get("inputs_ok", false)),
			"expected_world_count": BW10F_EXPECTED_WORLD_COUNT,
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
			"BALANCED_WAVE_BW10F_DEVELOPMENT_PREFLIGHT ",
			JSON.stringify(preflight_receipt, "", true, true),
		)
		quit(0 if bool(preflight_receipt["ok"]) else 1)
		return

	var clock_ok := bool(preflight.get("clock_ok", false))
	var matrix_ok := bool(preflight.get("matrix_ok", false))
	var inputs_ok := bool(preflight.get("inputs_ok", false))
	_check(clock_ok, "1 the frozen clock compiles exactly")
	_check(matrix_ok, "2 the fresh-only BW10F 12-world candidate matrix is exact")
	_check(inputs_ok, "3 the candidate, material, seeds, fixture, and challenges compile")
	var receipts: Array = []
	var integrity_failure_count := 0
	var ordinary_nonwalk_count := 0
	var rough_nonwalk_count := 0
	var release_timeout_count := 0
	var acquisition_failure_count := 0
	var mechanism_receipt_failure_count := 0
	var nonzero_stability_count := 0
	var aggregate_active_step_count := 0
	var aggregate_preferred_step_count := 0
	var aggregate_centroid_step_count := 0
	var aggregate_unavailable_receipt_count := 0
	var aggregate_infeasible_receipt_count := 0
	var aggregate_fail_zero_receipt_count := 0
	var count_by_cohort := {"baseline": 0, "rough": 0}
	if clock_ok and matrix_ok and inputs_ok:
		var input: Dictionary = preflight["input_by_profile"][BW10F_PROFILE_ID]
		var perturbation_by_seed: Dictionary = preflight["perturbation_by_seed"]
		for cell_value in preflight["matrix"]:
			var cell: Dictionary = cell_value
			var seed_key := str(int(cell["campaign_seed"]))
			print(
				"BW10F_CELL_START candidate=%s cell=%s world=%d/%d"
				% [
					_bw2_candidate_id,
					String(cell["cell_id"]),
					receipts.size() + 1,
					BW10F_EXPECTED_WORLD_COUNT,
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
				summary.get("evidence_acquisition_options", {})
				== BW9L_ACQUISITION_OPTIONS
				and String(
					summary.get(
						"evidence_acquisition_configuration_sha256",
						"",
					)
				)
				== BW9L_ACQUISITION_SHA256
				and bool(acquisition.get("acquired", false))
				and not bool(acquisition.get("timed_out", true))
				and not bool(acquisition.get("controller_parameter", true))
				and not bool(acquisition.get("walking_claim_authorized", true))
			)
			var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
			var load_transfer: Dictionary = sdk_summary.get(
				"scheduled_load_transfer_summary",
				{},
			)
			var candidate_index := BW10F_CANDIDATE_IDS.find(_bw2_candidate_id)
			var preferred_enabled := candidate_index in [1, 3]
			var centroid_enabled := candidate_index in [2, 3]
			var active_step_count := int(load_transfer.get("active_step_count", -1))
			var unweighted_contact_count := int(
				load_transfer.get("unweighted_contact_count", -1)
			)
			var preferred_step_count := int(
				load_transfer.get("preferred_normal_step_count", -1)
			)
			var centroid_step_count := int(
				load_transfer.get("remaining_centroid_step_count", -1)
			)
			var receipt_count := int(load_transfer.get("receipt_count", -1))
			var available_count := int(
				load_transfer.get("available_receipt_count", -1)
			)
			var unavailable_count := int(
				load_transfer.get("observation_unavailable_receipt_count", -1)
			)
			var infeasible_count := int(
				load_transfer.get("upstream_infeasible_receipt_count", -1)
			)
			var fail_zero_count := int(
				load_transfer.get("fail_zero_receipt_count", -1)
			)
			var mechanism_exact: bool = (
				candidate_index >= 0
				and bool(load_transfer.get("enabled", false))
				and String(load_transfer.get("schema_version", ""))
				== "sporespore_scheduled_load_transfer_execution_summary_v1"
				and String(load_transfer.get("policy_id", ""))
				== _bw9l_stability_policy_id
				and String(load_transfer.get("portable_plan_operation", ""))
				== "plan_scheduled_load_transfer_v2_json"
				and String(load_transfer.get("receipt_schema_version", ""))
				== "sporespore_scheduled_load_transfer_receipt_v2"
				and receipt_count == int(sdk_summary.get("step_count", -2))
				and receipt_count > 0
				and available_count + unavailable_count + infeasible_count
				== receipt_count
				and fail_zero_count == unavailable_count + infeasible_count
				and (
					(active_step_count == 0 and unweighted_contact_count == 0)
					if candidate_index == 0
					else (active_step_count >= 0 and unweighted_contact_count >= 0)
				)
				and (
					preferred_step_count >= 0
					if preferred_enabled
					else preferred_step_count == 0
				)
				and (
					centroid_step_count >= 0
					if centroid_enabled
					else centroid_step_count == 0
				)
				and String(load_transfer.get("first_receipt_sha256", "")).begins_with(
					"sha256:"
				)
				and String(load_transfer.get("first_receipt_sha256", "")).length() == 71
				and String(load_transfer.get("last_receipt_sha256", "")).begins_with(
					"sha256:"
				)
				and String(load_transfer.get("last_receipt_sha256", "")).length() == 71
				and bool(
					load_transfer.get(
						"activation_uses_scheduler_boundaries_only",
						false,
					)
				)
				and int(load_transfer.get("morphology_branch_surface_count", -1)) == 0
				and not bool(
					load_transfer.get(
						"per_foot_measured_load_allocation_available",
						true,
					)
				)
				and not bool(load_transfer.get("walking_claim_authorized", true))
				and not bool(load_transfer.get("physical_acceptance_authority", true))
			)
			var execution_gate: bool = (
				bool(receipt.get("campaign_execution_gate_passed", false))
				and bool(receipt.get("specialized_axis_gate_passed", false))
				and acquisition_exact
				and mechanism_exact
			)
			receipt["partition"] = "fresh"
			receipt["candidate_id"] = _bw2_candidate_id
			receipt["stability_policy_id"] = _bw9l_stability_policy_id
			receipt["base_controller_policy_id"] = BW10F_BASE_CONTROLLER_POLICY_ID
			receipt["candidate_policy_digest"] = _bw2_policy_digest
			receipt["evidence_acquisition_gate_passed"] = acquisition_exact
			receipt["evidence_support_acquisition_receipt"] = acquisition.duplicate(true)
			receipt["scheduled_load_transfer_gate_passed"] = mechanism_exact
			receipt["scheduled_load_transfer_summary"] = load_transfer.duplicate(true)
			receipt["contact_gate_timeout_count_by_limb"] = (
				summary.get("contact_gate_timeout_count_by_limb", {}) as Dictionary
			).duplicate(true)
			receipt["release_timeout_count"] = _sum_integer_values(
				receipt["contact_gate_timeout_count_by_limb"]
			)
			receipt["bw10f_execution_gate_passed"] = execution_gate
			receipts.append(receipt)
			_check(
				execution_gate,
				"%s completes candidate execution integrity" % String(cell["cell_id"]),
			)
			if not execution_gate:
				integrity_failure_count += 1
			if not bool(receipt.get("ordinary_walking_gate_passed", false)):
				ordinary_nonwalk_count += 1
				if String(cell.get("cohort", "")) == "rough":
					rough_nonwalk_count += 1
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
			aggregate_active_step_count += maxi(active_step_count, 0)
			aggregate_preferred_step_count += maxi(preferred_step_count, 0)
			aggregate_centroid_step_count += maxi(centroid_step_count, 0)
			aggregate_unavailable_receipt_count += maxi(unavailable_count, 0)
			aggregate_infeasible_receipt_count += maxi(infeasible_count, 0)
			aggregate_fail_zero_receipt_count += maxi(fail_zero_count, 0)
			var cohort := String(cell.get("cohort", ""))
			count_by_cohort[cohort] = int(count_by_cohort[cohort]) + 1
			print("BALANCED_WAVE_BW10F_CELL ", JSON.stringify(receipt, "", true, true))

	var roles_exact := (
		receipts.size() == BW10F_EXPECTED_WORLD_COUNT
		and int(count_by_cohort["baseline"]) == 6
		and int(count_by_cohort["rough"]) == 6
	)
	_check(roles_exact, "16 both fresh baseline/rough cohorts complete exactly")
	_check(integrity_failure_count == 0, "17 the complete matrix has zero integrity failures")
	_check(acquisition_failure_count == 0, "18 all worlds satisfy bounded acquisition")
	_check(nonzero_stability_count == 12, "19 all worlds apply nonzero bounded stability influence")
	var candidate_index := BW10F_CANDIDATE_IDS.find(_bw2_candidate_id)
	var aggregate_factor_exact := (
		(
			aggregate_active_step_count == 0
			and aggregate_preferred_step_count == 0
			and aggregate_centroid_step_count == 0
			if candidate_index == 0
			else (
				aggregate_active_step_count > 0
				and (
					aggregate_preferred_step_count > 0
					if candidate_index in [1, 3]
					else aggregate_preferred_step_count == 0
				)
				and (
					aggregate_centroid_step_count > 0
					if candidate_index in [2, 3]
					else aggregate_centroid_step_count == 0
				)
			)
		)
		and aggregate_fail_zero_receipt_count
		== aggregate_unavailable_receipt_count + aggregate_infeasible_receipt_count
	)
	_check(
		mechanism_receipt_failure_count == 0 and aggregate_factor_exact,
		"20 every SDK step retains v2 receipt continuity and exact factors",
	)
	var candidate_identity_exact := true
	for receipt_value in receipts:
		var receipt: Dictionary = receipt_value
		candidate_identity_exact = (
			candidate_identity_exact
			and String(receipt.get("controller_policy_id", ""))
			== BW10F_BASE_CONTROLLER_POLICY_ID
			and String(receipt.get("stability_policy_id", ""))
			== _bw9l_stability_policy_id
			and String(receipt.get("candidate_policy_digest", ""))
			== _bw2_policy_digest
		)
	_check(candidate_identity_exact, "21 every world retains exact base and v2 policy identity")
	_check(true, "22 every physical-acceptance and C6 claim remains false")

	var complete := (
		_failed == 0
		and _passed == BW10F_EXPECTED_GATE_COUNT
		and receipts.size() == BW10F_EXPECTED_WORLD_COUNT
	)
	var development_selectable := complete and candidate_index in [1, 2, 3]
	var result := {
		"schema_version": "sporespore_balanced_wave_bw10f_development_receipt_v1",
		"ok": complete,
		"result_status":
		(
			"treatment_development_selectable"
			if development_selectable
			else ("control_complete" if complete else "candidate_incomplete")
		),
		"development_selectable": development_selectable,
		"candidate_id": _bw2_candidate_id,
		"policy_id": _bw9l_stability_policy_id,
		"base_controller_policy_id": BW10F_BASE_CONTROLLER_POLICY_ID,
		"candidate_policy_digest": _bw2_policy_digest,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": BW10F_EXPECTED_GATE_COUNT,
		"expected_world_count": BW10F_EXPECTED_WORLD_COUNT,
		"observed_world_count": receipts.size(),
		"integrity_failure_count": integrity_failure_count,
		"ordinary_nonwalk_count": ordinary_nonwalk_count,
		"rough_ordinary_nonwalk_count": rough_nonwalk_count,
		"release_timeout_count": release_timeout_count,
		"acquisition_failure_count": acquisition_failure_count,
		"mechanism_receipt_failure_count": mechanism_receipt_failure_count,
		"nonzero_stability_world_count": nonzero_stability_count,
		"aggregate_active_step_count": aggregate_active_step_count,
		"aggregate_preferred_normal_step_count": aggregate_preferred_step_count,
		"aggregate_remaining_centroid_step_count": aggregate_centroid_step_count,
		"aggregate_observation_unavailable_receipt_count":
		aggregate_unavailable_receipt_count,
		"aggregate_upstream_infeasible_receipt_count":
		aggregate_infeasible_receipt_count,
		"aggregate_fail_zero_receipt_count": aggregate_fail_zero_receipt_count,
		"count_by_cohort": count_by_cohort,
		"cells": receipts,
		"known_bw9l_outcomes_disclosed": true,
		"fresh_only_development_matrix": true,
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
	print("BALANCED_WAVE_BW10F_DEVELOPMENT_RECEIPT ", JSON.stringify(result, "", true, true))
	quit(0 if complete else 1)
