extends SceneTree
# gdlint: disable=max-line-length

## Complete pure-data mutation population for the production R71 in-run
## solved-contact completeness contract. No model, world, RID, or step exists.

const WorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "QSDK_R24D71_GODOT_SOLVED_CONTACT_CONTRACT_ZERO_WORLD "
const CONTRACT_SCHEMA := (
	"sporespore_qsdk_r24d71_godot_solved_contact_telemetry_contract_v1"
)
const INVALID_CODE := "QSDK_R24D71_WORLD_SOLVED_CONTACT_TELEMETRY_INVALID"
const EXPECTED_STEP := 7


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JsonTransportScript.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)


func _run() -> Dictionary:
	var populated_positive := WorldScript.native_solved_contact_telemetry_contract_v1(
		_base_telemetry(), EXPECTED_STEP
	)
	var zero_contact := _base_telemetry()
	for field_name in [
		"reported_manifold_count",
		"reported_contact_point_count",
		"exact_manifold_count",
		"exact_contact_point_count",
	]:
		zero_contact[field_name] = 0
	var zero_positive := WorldScript.native_solved_contact_telemetry_contract_v1(
		zero_contact, EXPECTED_STEP
	)

	var mutations: Array = []
	_append_mutation(mutations, "field_population_exact", "profile_id", null, true)
	_append_mutation(mutations, "schema_exact", "schema", "wrong")
	_append_mutation(mutations, "profile_exact", "profile_id", "wrong")
	_append_mutation(mutations, "sequence_and_count_types_exact", "reported_manifold_count", 3.0)
	_append_mutation(mutations, "boolean_types_exact", "complete", 1)
	mutations.append({"first": "expected_space_step_sequence_positive", "value": _base_telemetry(), "expected": 0})
	_append_mutation(mutations, "capture_matches_expected_space_step_sequence", "capture_space_step_sequence", 6)
	_append_mutation(mutations, "read_matches_expected_space_step_sequence", "read_space_step_sequence", 6)
	_append_mutation(mutations, "captured_during_active_step", "captured_during_active_step", false)
	_append_mutation(mutations, "snapshot_is_current_space_step", "snapshot_is_current_space_step", false)
	_append_mutation(mutations, "counts_nonnegative", "reported_manifold_count", -1)
	_append_mutation(mutations, "reported_exact_manifold_population_equal", "exact_manifold_count", 2)
	_append_mutation(mutations, "reported_exact_contact_point_population_equal", "exact_contact_point_count", 7)
	_append_mutation(mutations, "missing_manifold_population_zero", "missing_manifold_count", 1)
	_append_mutation(mutations, "ccd_only_manifold_population_zero", "ccd_only_manifold_count", 1)
	_append_mutation(mutations, "point_count_mismatch_population_zero", "point_count_mismatch_count", 1)
	_append_mutation(mutations, "nonfinite_impulse_population_zero", "nonfinite_impulse_count", 1)
	_append_mutation(mutations, "native_completeness_true", "complete", false)

	var exact_rejection_count := 0
	for mutation_value in mutations:
		var mutation: Dictionary = mutation_value
		var result := WorldScript.native_solved_contact_telemetry_contract_v1(
			mutation["value"], int(mutation["expected"])
		)
		var detail: Dictionary = result.get("detail", {})
		exact_rejection_count += int(
			not bool(result.get("ok", true))
			and String(result.get("failure_code", "")) == INVALID_CODE
			and String(detail.get("schema_version", "")) == CONTRACT_SCHEMA
			and String(detail.get("first_failed_invariant_id", ""))
			== String(mutation["first"])
			and _zero_world_receipt(result)
		)
	var missing_result := WorldScript.native_solved_contact_telemetry_contract_v1(
		null, EXPECTED_STEP
	)
	var missing_rejected := (
		not bool(missing_result.get("ok", true))
		and String(missing_result.get("failure_code", ""))
		== "QSDK_R24D71_WORLD_SOLVED_CONTACT_TELEMETRY_MISSING"
		and _zero_world_receipt(missing_result)
	)
	var positives_exact := (
		_positive_exact(populated_positive, 3, 8)
		and _positive_exact(zero_positive, 0, 0)
	)
	var exact := (
		positives_exact
		and exact_rejection_count == mutations.size()
		and mutations.size() == 18
		and missing_rejected
	)
	return {
		"schema_version": "sporespore_qsdk_r24d71_godot_solved_contact_contract_zero_world_v1",
		"gate_id": "QSDK-R24D71",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D71_SOLVED_CONTACT_CONTRACT_ZERO_WORLD_INVALID",
		"positive_population_count": 2,
		"positive_exact_count": 2 if positives_exact else 0,
		"mutation_population_count": mutations.size(),
		"exact_mutation_rejection_count": exact_rejection_count,
		"missing_variant_rejection_count": int(missing_rejected),
		"native_runtime_observation_collection_executed": false,
		"held_out_cell_access_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _append_mutation(
	mutations: Array,
	first_invariant: String,
	field_name: String,
	value: Variant,
	erase_field: bool = false,
) -> void:
	var telemetry := _base_telemetry()
	if erase_field:
		telemetry.erase(field_name)
	else:
		telemetry[field_name] = value
	mutations.append({"first": first_invariant, "value": telemetry, "expected": EXPECTED_STEP})


static func _base_telemetry() -> Dictionary:
	return {
		"schema": "sporespore.godot_jolt_solved_contact_telemetry.v1",
		"profile_id": "godot_4_7_jolt_sporespore_solved_contact_telemetry_v1",
		"capture_space_step_sequence": EXPECTED_STEP,
		"read_space_step_sequence": EXPECTED_STEP,
		"captured_during_active_step": true,
		"snapshot_is_current_space_step": true,
		"reported_manifold_count": 3,
		"reported_contact_point_count": 8,
		"exact_manifold_count": 3,
		"exact_contact_point_count": 8,
		"missing_manifold_count": 0,
		"ccd_only_manifold_count": 0,
		"point_count_mismatch_count": 0,
		"nonfinite_impulse_count": 0,
		"complete": true,
	}


static func _positive_exact(result: Dictionary, manifolds: int, points: int) -> bool:
	return (
		bool(result.get("ok", false))
		and String(result.get("schema_version", "")) == CONTRACT_SCHEMA
		and int(result.get("expected_space_step_sequence", -1)) == EXPECTED_STEP
		and int(result.get("reported_manifold_count", -1)) == manifolds
		and int(result.get("reported_contact_point_count", -1)) == points
		and int(result.get("exact_manifold_count", -1)) == manifolds
		and int(result.get("exact_contact_point_count", -1)) == points
		and _zero_world_receipt(result)
	)


static func _zero_world_receipt(receipt: Dictionary) -> bool:
	return (
		int(receipt.get("model_construction_count", -1)) == 0
		and int(receipt.get("world_attempt_count", -1)) == 0
		and int(receipt.get("world_build_count", -1)) == 0
		and int(receipt.get("solver_step_count", -1)) == 0
		and not bool(receipt.get("physics_state_modified", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
		and not bool(receipt.get("release_authority", true))
	)
