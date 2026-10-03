extends SceneTree

## Zero-world Godot/Jolt composition-plus-diagnostic route for R23D12.
## The inherited R23D11 controller/composition remains unchanged; R23D12 adds
## only the independently qualified support-margin availability semantics.

const Composition := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_stability_assisted_taper.gd"
)
const Diagnostics := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_r23d12_measurement_semantics.gd"
)

const CAMPAIGN_ID := (
	"QSDK-R23D12-INDEPENDENT-PLANNER-AND-SUPPORT-MARGIN-SEMANTICS-"
	+ "BILATERAL-TURN-DEVELOPMENT"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed := _parse(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		print("QSDK_R23D12_GODOT_JOLT_FAILURE ", JSON.stringify(parsed))
		quit(1)
		return
	if String(parsed["command"]) == "physical":
		var failure := {
			"schema_version": "sporespore_qsdk_r23d12_worker_failure_v1",
			"failure_stage": "before_model",
			"failure_code": "QSDK_R23D12_GJT_PHYSICAL_ROUTE_NOT_IMPLEMENTED",
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
		print("QSDK_R23D12_GODOT_JOLT_FAILURE ", JSON.stringify(failure))
		quit(1)
		return
	var composition := Composition.preflight(
		String(parsed["stage_id"]),
		String(parsed["arm_id"]),
	)
	var diagnostics := Diagnostics.preflight()
	if not bool(composition.get("ok", false)) or not bool(diagnostics.get("ok", false)):
		var failure := {
			"ok": false,
			"failure_code": "R23D12_GJT_COMPOSITION_OR_DIAGNOSTICS_INVALID",
			"composition": composition,
			"diagnostics": diagnostics,
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
		print("QSDK_R23D12_GODOT_JOLT_FAILURE ", JSON.stringify(failure))
		quit(1)
		return
	var receipt := {
		"schema_version": (
			"sporespore_qsdk_r23d12_godot_jolt_composition_and_diagnostic_preflight_v1"
		),
		"ok": true,
		"failure_code": "",
		"campaign_id": CAMPAIGN_ID,
		"gate_id": "QSDK-R23D12",
		"engine_id": "godot_jolt",
		"stage_id": String(parsed["stage_id"]),
		"arm_id": String(parsed["arm_id"]),
		"inherited_composition_campaign_id": String(composition["campaign_id"]),
		"composition_canary_count": int(composition["composition_canary_count"]),
		"composition_mutation_control_count": int(composition["mutation_control_count"]),
		"diagnostic_valid_canary_count": int(diagnostics["valid_canary_count"]),
		"diagnostic_active_cross_product_count": int(diagnostics["active_cross_product_count"]),
		"diagnostic_mutation_control_count": int(diagnostics["mutation_control_count"]),
		"critical_r23d11_failure_shape_passed": bool(
			diagnostics["critical_r23d11_failure_shape_passed"]
		),
		"planner_and_support_margin_availability_are_independent": true,
		"physical_worker_implemented": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
	}
	print("QSDK_R23D12_GODOT_JOLT_PREFLIGHT ", JSON.stringify(receipt))
	quit(0)


func _parse(args: PackedStringArray) -> Dictionary:
	if args.size() != 5 or not ["preflight", "physical"].has(String(args[0])):
		return {"ok": false, "failure_code": "R23D12_GJT_ARGUMENTS_INVALID"}
	var stage_id := ""
	var arm_id := ""
	var index := 1
	while index < args.size():
		match String(args[index]):
			"--stage":
				stage_id = String(args[index + 1])
			"--arm":
				arm_id = String(args[index + 1])
			_:
				return {"ok": false, "failure_code": "R23D12_GJT_ARGUMENTS_INVALID"}
		index += 2
	if stage_id.is_empty() or arm_id.is_empty():
		return {"ok": false, "failure_code": "R23D12_GJT_ARGUMENTS_INVALID"}
	return {
		"ok": true,
		"command": String(args[0]),
		"stage_id": stage_id,
		"arm_id": arm_id,
	}
