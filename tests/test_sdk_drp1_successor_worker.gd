extends "res://tests/test_sdk_balanced_wave_bw31n_successor_worker.gd"

const Drp1Common := preload("res://scripts/lab/gait/sdk_drp1_worker_common.gd")
const ROUTE_ID := Drp1Common.SUCCESSOR_ROUTE_ID
const RAW_PREFIX := "DRP1_DYNAMIC_RECEIPT_RAW_CELL "
const PREFLIGHT_PREFIX := "DRP1_WORKER_PREFLIGHT "


func _run() -> void:
	print("\n=== DRP1 noncampaign successor-route dynamic receipt worker ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var args := OS.get_cmdline_user_args()
	if args.size() == 1 and String(args[0]) == "preflight-all":
		await _run_preflight_all()
		return
	var mode := String(args[0]) if args.size() == 2 else ""
	var cell_id := String(args[1]) if args.size() == 2 else ""
	var cell := Drp1Common.find_cell(cell_id, ROUTE_ID)
	if mode not in ["preflight", "regression"] or cell.is_empty():
		push_error("DRP1 successor worker requires preflight or regression plus one exact cell")
		quit(1)
		return
	var configured := _configure_bw31n_cell(cell)
	if not configured:
		_clear_bw31n_cell()
		push_error("DRP1 successor challenge or material preparation failed")
		quit(1)
		return
	if mode == "preflight":
		var prepared := await _run_cell(0, int(cell["regression_seed"]), true)
		var exact := (
			bool(prepared.get("ok", false))
			and bool(prepared.get("entrypoint_control_flow_complete", false))
			and int(prepared.get("actual_world_build_count", -1)) == 0
			and Drp1Common.declaration_exact()
			and bool(Drp1Common.walking_receipt_schema_preflight(ROUTE_ID).get("ok", false))
			and Drp1Common.compose_final_receipt(
				ROUTE_ID,
				cell,
				{"world_build_count": 0},
				{},
			).is_empty()
		)
		_clear_bw31n_cell()
		print(PREFLIGHT_PREFIX, JSON.stringify(_drp1_preflight_receipt(cell, exact), "", true, true))
		quit(0 if exact else 1)
		return
	if not _regression_authorization_exact(cell_id):
		_clear_bw31n_cell()
		push_error("DRP1 successor regression requires exact conformance-owned authorization")
		quit(1)
		return
	var summary := await _run_cell(0, int(cell["regression_seed"]), false)
	var receipt := Drp1Common.compose_final_receipt(ROUTE_ID, cell, summary, {})
	_clear_bw31n_cell()
	print(RAW_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(receipt.get("route_integrity_passed", false)) else 1)


func _run_preflight_all() -> void:
	var receipts: Array = []
	var all_exact := Drp1Common.declaration_exact()
	for cell_value in Drp1Common.ordered_cells():
		var cell: Dictionary = cell_value
		if String(cell["route_id"]) != ROUTE_ID:
			continue
		var configured := _configure_bw31n_cell(cell)
		var prepared: Dictionary = {}
		if configured:
			prepared = await _run_cell(0, int(cell["regression_seed"]), true)
		_clear_bw31n_cell()
		var exact := (
			configured
			and bool(prepared.get("ok", false))
			and bool(prepared.get("entrypoint_control_flow_complete", false))
			and int(prepared.get("actual_world_build_count", -1)) == 0
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
