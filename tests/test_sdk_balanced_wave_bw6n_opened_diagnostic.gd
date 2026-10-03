extends "res://tests/test_sdk_balanced_wave_bw6n_validation.gd"

## Development-only replay of the already-opened BW6N baseline and rough worlds.
##
## This diagnostic cannot accept BW6N, a successor policy, or any robustness
## claim. It reuses the rejected campaign's exposed seeds only to localize the
## nominal evidence-boundary misses and rough-terrain contact-gating failures.

const DIAGNOSTIC_SCHEMA := "sporespore_balanced_wave_bw6n_opened_diagnostic_receipt_v1"
const DIAGNOSTIC_CELL_IDS := [
	"baseline_s21001",
	"baseline_s21002",
	"baseline_s21003",
	"rough_s21001",
	"rough_s21002",
	"rough_s21003",
]


func _run() -> void:
	print("\n=== SDK balanced-wave BW6N opened-world causal diagnostic ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() != 1 or String(user_args[0]) != "--opened-bw6n-diagnostic":
		push_error(
			"Opened BW6N diagnostic requires exactly --opened-bw6n-diagnostic"
		)
		quit(1)
		return
	_bw2_mode = true
	_bw2_candidate_id = BW5C_CANDIDATE_ID
	_bw2_policy_id = BW5C_POLICY_ID
	_bw2_policy_digest = BW5C_POLICY_DIGEST
	_opened_development_replay = true
	await _run_opened_diagnostic()


func _run_opened_diagnostic() -> void:
	var preflight := _compile_preflight()
	var preflight_ok := (
		bool(preflight.get("clock_ok", false))
		and bool(preflight.get("matrix_ok", false))
		and bool(preflight.get("inputs_ok", false))
	)
	var diagnostic_cells: Array = []
	if preflight_ok:
		var gait_clock_options: Dictionary = preflight["gait_clock_options"]
		var perturbation_by_seed: Dictionary = preflight["perturbation_by_seed"]
		var input: Dictionary = preflight["input_by_profile"][BW6N_PROFILE_ID]
		for cell_value in preflight["matrix"]:
			var cell: Dictionary = cell_value
			var cell_id := String(cell["cell_id"])
			if cell_id not in DIAGNOSTIC_CELL_IDS:
				continue
			print(
				"BW6N_OPENED_DIAGNOSTIC_CELL_START ",
				cell_id,
				" world=",
				diagnostic_cells.size() + 1,
				"/",
				DIAGNOSTIC_CELL_IDS.size(),
			)
			var seed_key := str(int(cell["campaign_seed"]))
			var perturbation: Dictionary = perturbation_by_seed[seed_key]
			var summary: Dictionary = await _run_cell(
				gait_clock_options,
				cell,
				perturbation,
				input["fixture_spec"],
			)
			var analyzed := _analyze_cell(cell, summary, perturbation, input, true)
			var diagnostic := _diagnostic_cell_receipt(cell, summary, analyzed)
			diagnostic_cells.append(diagnostic)
			print(
				"BALANCED_WAVE_BW6N_OPENED_DIAGNOSTIC_CELL ",
				JSON.stringify(diagnostic, "", true, true),
			)
	var observed_cell_ids: Array = []
	var execution_complete := preflight_ok
	for receipt_value in diagnostic_cells:
		var receipt: Dictionary = receipt_value
		observed_cell_ids.append(String(receipt.get("cell_id", "")))
		execution_complete = (
			execution_complete
			and bool(receipt.get("diagnostic_execution_complete", false))
		)
	execution_complete = (
		execution_complete
		and observed_cell_ids == DIAGNOSTIC_CELL_IDS
		and diagnostic_cells.size() == DIAGNOSTIC_CELL_IDS.size()
	)
	var result := {
		"schema_version": DIAGNOSTIC_SCHEMA,
		"ok": execution_complete,
		"result": "development_diagnostic_complete" if execution_complete else "diagnostic_failed",
		"campaign_partition": "opened_bw6n_development_replay",
		"source_campaign": "BW6N",
		"source_campaign_final_result": "rejected",
		"source_campaign_rerun": false,
		"controller_changed": false,
		"thresholds_changed": false,
		"opened_seed_replay": true,
		"candidate_id": _bw2_candidate_id,
		"policy_id": _bw2_policy_id,
		"candidate_policy_digest": _bw2_policy_digest,
		"expected_cell_ids": DIAGNOSTIC_CELL_IDS.duplicate(),
		"observed_cell_ids": observed_cell_ids,
		"observed_world_count": diagnostic_cells.size(),
		"cells": diagnostic_cells,
		"acceptance_authority": false,
		"walking_claim_authorized": false,
		"rough_terrain_robustness": false,
		"physical_balance_recovery": false,
		"cross_engine_c6": false,
		"completed_engine_neutral_sdk": false,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
		"automatic_creature_guidance_allowed": false,
	}
	print(
		"BALANCED_WAVE_BW6N_OPENED_DIAGNOSTIC_RECEIPT ",
		JSON.stringify(result, "", true, true),
	)
	quit(0 if execution_complete else 1)


func _diagnostic_cell_receipt(
	cell: Dictionary,
	summary: Dictionary,
	analyzed: Dictionary,
) -> Dictionary:
	return {
		"cell_id": String(cell["cell_id"]),
		"cohort": String(cell["cohort"]),
		"campaign_seed": int(cell["campaign_seed"]),
		"challenge_profile_id": String(cell["challenge_profile_id"]),
		"initial_perturbation":
		(summary.get("initial_perturbation", {}) as Dictionary).duplicate(true),
		# The inherited "diagnostic_execution_complete" field is intentionally
		# cohort-specific and is false for BW6N's baseline/rough cohort names.
		# Its balanced-wave campaign gate is the execution-integrity receipt
		# used by the frozen BW6N harness before walking/axis acceptance.
		"diagnostic_execution_complete": bool(
			analyzed.get("campaign_execution_gate_passed", false)
		),
		"inherited_diagnostic_cohort_gate": bool(
			analyzed.get("diagnostic_execution_complete", false)
		),
		"ordinary_walking_gate_passed": bool(
			analyzed.get("treatment_gate_passed", false)
		),
		"walking_gate_receipts":
		(summary.get("walking_gate_receipts", {}) as Dictionary).duplicate(true),
		"evidence_start_tick": int(summary.get("evidence_start_tick", -1)),
		"evidence_end_tick": int(summary.get("evidence_end_tick", -1)),
		"evidence_extension_ticks": int(summary.get("evidence_extension_ticks", -1)),
		"evidence_all_four_contacts_at_start": bool(
			summary.get("evidence_all_four_contacts_at_start", false)
		),
		"evidence_start_bearing_contact_by_limb":
		(
			summary.get("evidence_start_bearing_contact_by_limb", {}) as Dictionary
		).duplicate(true),
		"evidence_boundary_contact_trace":
		(summary.get("evidence_boundary_contact_trace", []) as Array).duplicate(true),
		"terminal_all_four_contacts": bool(summary.get("terminal_all_four_contacts", false)),
		"terminal_bearing_contact_by_limb":
		(summary.get("terminal_bearing_contact_by_limb", {}) as Dictionary).duplicate(true),
		"contact_gate_timeout_count_by_limb":
		(summary.get("contact_gate_timeout_count_by_limb", {}) as Dictionary).duplicate(true),
		"contact_gate_timeout_receipts_by_limb":
		(
			summary.get("contact_gate_timeout_receipts_by_limb", {}) as Dictionary
		).duplicate(true),
		"contact_gate_release_hold_tick_count_by_limb":
		(
			summary.get("contact_gate_release_hold_tick_count_by_limb", {}) as Dictionary
		).duplicate(true),
		"contact_gate_recontact_hold_tick_count_by_limb":
		(
			summary.get("contact_gate_recontact_hold_tick_count_by_limb", {}) as Dictionary
		).duplicate(true),
		"contact_gate_phase_sync_hold_tick_count_by_limb":
		(
			summary.get("contact_gate_phase_sync_hold_tick_count_by_limb", {}) as Dictionary
		).duplicate(true),
		"contact_cycle_count_by_limb":
		(summary.get("contact_cycle_count_by_limb", {}) as Dictionary).duplicate(true),
		"rejected_short_contact_cycle_count_by_limb":
		(
			summary.get("rejected_short_contact_cycle_count_by_limb", {}) as Dictionary
		).duplicate(true),
		"contact_transition_receipts_by_limb":
		(
			summary.get("contact_transition_receipts_by_limb", {}) as Dictionary
		).duplicate(true),
		"maximum_cycle_relocation_by_limb_m":
		(
			summary.get("maximum_cycle_relocation_by_limb_m", {}) as Dictionary
		).duplicate(true),
		"minimum_cycle_relocation_by_limb_m":
		(
			summary.get("minimum_cycle_relocation_by_limb_m", {}) as Dictionary
		).duplicate(true),
		"contact_absent_tick_count_by_limb":
		(
			summary.get("contact_absent_tick_count_by_limb", {}) as Dictionary
		).duplicate(true),
		"longest_contact_absent_dwell_by_limb_ticks":
		(
			summary.get(
				"longest_contact_absent_dwell_by_limb_ticks",
				{},
			) as Dictionary
		).duplicate(true),
		"path_steering_update_receipts":
		(summary.get("path_steering_update_receipts", []) as Array).duplicate(true),
		"maximum_absolute_requested_steering_fraction": float(
			analyzed.get("maximum_absolute_requested_steering_fraction", INF)
		),
		"maximum_absolute_filtered_steering_fraction": float(
			analyzed.get("maximum_absolute_filtered_steering_fraction", INF)
		),
		"steering_saturation_count": int(analyzed.get("steering_saturation_count", -1)),
		"maximum_cross_track_error_m": float(
			analyzed.get("maximum_cross_track_error_m", INF)
		),
		"cumulative_absolute_cross_track_error_m_s": float(
			analyzed.get("cumulative_absolute_cross_track_error_m_s", INF)
		),
		"final_task_frame_lateral_displacement_m": float(
			summary.get("final_task_frame_lateral_displacement_m", INF)
		),
		"evidence_task_frame_forward_displacement_m": float(
			summary.get("evidence_task_frame_forward_displacement_m", -INF)
		),
		"final_task_frame_forward_displacement_m": float(
			summary.get("final_task_frame_forward_displacement_m", -INF)
		),
		"maximum_tilt_rad": float(summary.get("maximum_tilt_rad", INF)),
		"stability_shadow":
		(analyzed.get("stability_shadow", {}) as Dictionary).duplicate(true),
		"stability_contribution_shadow":
		(
			analyzed.get("stability_contribution_shadow", {}) as Dictionary
		).duplicate(true),
		"stability_overlay":
		(analyzed.get("stability_overlay", {}) as Dictionary).duplicate(true),
		"acceptance_authority": false,
		"walking_claim_authorized": false,
	}
