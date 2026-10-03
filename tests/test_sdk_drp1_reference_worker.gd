extends "res://tests/test_sdk_balanced_wave_bw31n_reference_worker.gd"

const Drp1Common := preload("res://scripts/lab/gait/sdk_drp1_worker_common.gd")
const ROUTE_ID := Drp1Common.REFERENCE_ROUTE_ID
const RAW_PREFIX := "DRP1_DYNAMIC_RECEIPT_RAW_CELL "
const PREFLIGHT_PREFIX := "DRP1_WORKER_PREFLIGHT "


func _run() -> void:
	print("\n=== DRP1 noncampaign reference-route dynamic receipt worker ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	_configure_reference_policy()
	var args := OS.get_cmdline_user_args()
	if args.size() == 1 and String(args[0]) == "preflight-all":
		_run_preflight_all()
		return
	var mode := String(args[0]) if args.size() == 2 else ""
	var cell_id := String(args[1]) if args.size() == 2 else ""
	var cell := Drp1Common.find_cell(cell_id, ROUTE_ID)
	if mode not in ["preflight", "regression"] or cell.is_empty():
		push_error("DRP1 reference worker requires preflight or regression plus one exact cell")
		quit(1)
		return
	var prepared := _prepare_drp1_cell(cell)
	if mode == "preflight":
		var exact := (
			bool(prepared.get("ok", false))
			and Drp1Common.declaration_exact()
			and bool(Drp1Common.walking_receipt_schema_preflight(ROUTE_ID).get("ok", false))
			and Drp1Common.compose_final_receipt(
				ROUTE_ID,
				cell,
				{"world_build_count": 0},
				{},
			).is_empty()
		)
		print(PREFLIGHT_PREFIX, JSON.stringify(_drp1_preflight_receipt(cell, exact), "", true, true))
		quit(0 if exact else 1)
		return
	if not _regression_authorization_exact(cell_id):
		push_error("DRP1 reference regression requires exact conformance-owned authorization")
		quit(1)
		return
	if not bool(prepared.get("ok", false)):
		push_error("DRP1 reference input preparation failed")
		quit(1)
		return
	var summary: Dictionary = await _run_bw31n_reference_cell(prepared)
	var local_cell: Dictionary = prepared["cell"]
	var parent := _analyze_cell(
		local_cell,
		summary,
		prepared["perturbation"],
		prepared["input"],
		true,
	)
	parent = _enrich_bw6n_receipt(local_cell, summary, parent)
	var direct_primitives := {
		"terrain_shape_count": int(parent.get("terrain_shape_count", -1)),
		"external_push_application_count": int(
			parent.get("external_push_application_count", -1)
		),
		"observation_fault_application_count": int(
			parent.get("observation_fault_application_count", -1)
		),
		"observation_fault_base_and_stability_count": int(
			parent.get("observation_fault_base_and_stability_count", -1)
		),
		"maximum_observation_fault_component": float(
			parent.get("maximum_observation_fault_component", NAN)
		),
		"stability_overlay": (
			parent.get("stability_overlay", {}) as Dictionary
		).duplicate(true),
	}
	var receipt := Drp1Common.compose_final_receipt(
		ROUTE_ID,
		cell,
		summary,
		direct_primitives,
	)
	print(RAW_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(receipt.get("route_integrity_passed", false)) else 1)


func _compile_drp1_reference_invariant() -> Dictionary:
	# Compile only the input this DRP1 cell actually consumes. The inherited
	# BW6N preflight deliberately compiles its complete historical campaign;
	# using it here would make this ordinary 24-world regression depend on a
	# different campaign matrix and would obscure which entrypoint was checked.
	var clock_compile := GaitClockSpecScript.compile(GaitClockSpecScript.gq15_clock())
	var material_resolve: Dictionary = MaterialProfilesScript.resolve(BW6N_PROFILE_ID)
	var material_profile: Dictionary = material_resolve.get("profile", {})
	var requested_fixture := FixtureSpecScript.reference_spec()
	if not material_profile.is_empty():
		requested_fixture["contact_material"] = (
			material_profile.get("body_material", {}) as Dictionary
		).duplicate(true)
	var fixture_compile := FixtureSpecScript.compile(requested_fixture)
	var profile_validation := MaterialProfilesScript.validate_for_fixture(
		BW6N_PROFILE_ID,
		requested_fixture.get("contact_material", {}),
		SOLVER_POLICY_OPTIONS,
	)
	var input := {}
	if (
		bool(material_resolve.get("ok", false))
		and bool(fixture_compile.get("ok", false))
		and bool(profile_validation.get("ok", false))
	):
		input = {
			"profile": material_profile.duplicate(true),
			"profile_sha256": String(material_resolve.get("profile_sha256", "")),
			"fixture_spec": (
				fixture_compile.get("fixture_spec", {}) as Dictionary
			).duplicate(true),
			"fixture_spec_sha256": String(
				fixture_compile.get("fixture_spec_sha256", "")
			),
		}
	return {
		"ok": (
			bool(clock_compile.get("ok", false))
			and String(material_resolve.get("profile_sha256", "")) == BW6N_PROFILE_DIGEST
			and String(material_profile.get("profile_id", "")) == BW6N_PROFILE_ID
			and is_equal_approx(float(material_profile.get("authored_friction", NAN)), 0.95)
			and not input.is_empty()
		),
		"gait_clock_options": (
			clock_compile.get("gait_clock_options", {}) as Dictionary
		).duplicate(true),
		"input": input.duplicate(true),
	}


func _prepare_drp1_cell(
	cell: Dictionary,
	reference_invariant_override: Dictionary = {},
) -> Dictionary:
	var reference_invariant := (
		_compile_drp1_reference_invariant()
		if reference_invariant_override.is_empty()
		else reference_invariant_override.duplicate(true)
	)
	var challenge_compile := WaveGaitScript.compile_environment_challenge_options(
		Drp1Common.challenge_profile(String(cell["challenge_profile_id"]))
	)
	var acquisition_compile := WaveGaitScript.compile_evidence_acquisition_options(
		Bw31Common.ACQUISITION_OPTIONS,
		12,
		3,
	)
	var horizon_compile := WaveGaitScript.compile_candidate_authority_horizon_options(
		Bw31Common.AUTHORITY_HORIZON_OPTIONS
	)
	var perturbation_compile := WaveGaitScript.compile_seeded_initial_perturbation(
		int(cell["regression_seed"])
	)
	var input: Dictionary = reference_invariant.get("input", {})
	var exact := (
		bool(reference_invariant.get("ok", false))
		and bool(challenge_compile.get("ok", false))
		and bool(acquisition_compile.get("ok", false))
		and bool(horizon_compile.get("ok", false))
		and bool(perturbation_compile.get("ok", false))
		and not input.is_empty()
	)
	var local_cell := {
		"cell_id": String(cell["cell_id"]),
		"cohort": "drp1_noncampaign_regression",
		"mode": "treatment",
		"campaign_seed": int(cell["regression_seed"]),
		"mu_token": "095",
		"authored_friction": 0.95,
		"profile_id": BW6N_PROFILE_ID,
		"profile_digest": BW6N_PROFILE_DIGEST,
		"challenge_profile_id": String(cell["challenge_profile_id"]),
		"challenge_options": (
			challenge_compile.get("environment_challenge_options", {}) as Dictionary
		).duplicate(true),
	}
	return {
		"ok": exact,
		"cell": local_cell,
		"gait_clock_options": (
			reference_invariant.get("gait_clock_options", {}) as Dictionary
		).duplicate(true),
		"perturbation": (
			perturbation_compile.get("initial_perturbation", {}) as Dictionary
		).duplicate(true),
		"input": input.duplicate(true),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _run_preflight_all() -> void:
	var receipts: Array = []
	var all_exact := Drp1Common.declaration_exact()
	var reference_invariant := _compile_drp1_reference_invariant()
	for cell_value in Drp1Common.ordered_cells():
		var cell: Dictionary = cell_value
		if String(cell["route_id"]) != ROUTE_ID:
			continue
		var exact := bool(
			_prepare_drp1_cell(cell, reference_invariant).get("ok", false)
		)
		exact = (
			exact
			and bool(Drp1Common.walking_receipt_schema_preflight(ROUTE_ID).get("ok", false))
			and Drp1Common.compose_final_receipt(
				ROUTE_ID,
				cell,
				{"world_build_count": 0},
				{},
			).is_empty()
		)
		all_exact = all_exact and exact
		receipts.append(_drp1_preflight_receipt(cell, exact))
	var aggregate := {
		"schema_version": "sporespore_drp1_worker_preflight_aggregate_v1",
		"ok": all_exact and receipts.size() == 12 and root.get_child_count() == 0,
		"regression_id": Drp1Common.REGRESSION_ID,
		"gate_id": Drp1Common.GATE_ID,
		"route_id": ROUTE_ID,
		"entrypoint_count": receipts.size(),
		"entrypoint_receipts": receipts,
		"actual_world_build_count": 0,
		"physics_state_modified": false,
		"selection_authority": false,
		"physical_acceptance_authority": false,
	}
	print(PREFLIGHT_PREFIX, JSON.stringify(aggregate, "", true, true))
	quit(0 if bool(aggregate["ok"]) else 1)


func _drp1_preflight_receipt(cell: Dictionary, exact: bool) -> Dictionary:
	var nested_schema := Drp1Common.walking_receipt_schema_preflight(ROUTE_ID)
	return {
		"schema_version": "sporespore_drp1_worker_preflight_v1",
		"ok": exact,
		"regression_id": Drp1Common.REGRESSION_ID,
		"gate_id": Drp1Common.GATE_ID,
		"route_id": ROUTE_ID,
		"cell_id": String(cell["cell_id"]),
		"actual_world_build_count": 0,
		"constructed_final_receipt_rejected": true,
		"nested_walking_schema_route_specific": bool(nested_schema.get("ok", false)),
		"nested_walking_schema_key_count": int(nested_schema.get("expected_key_count", -1)),
		"route_actuation_key": String(nested_schema.get("route_actuation_key", "")),
		"cross_route_nested_schema_rejected": bool(
			nested_schema.get("cross_route_schema_rejected", false)
		),
		"selection_authority": false,
		"physical_acceptance_authority": false,
	}


func _regression_authorization_exact(cell_id: String) -> bool:
	return Drp1Common.regression_authorization_exact(cell_id, ROUTE_ID)
