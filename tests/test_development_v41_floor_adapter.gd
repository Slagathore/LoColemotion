extends "res://tests/test_development_v39_floor_adapter.gd"

func _component_profile_path_v1() -> String:
	return "res://sdk/development/recovery_candidates/v41-upright-stance-v1.json"

func _selected_policy_id_v1() -> String:
	return Shared.Policy.UPRIGHT_POLICY_ID

func _additional_ledger_checks_v1(sdk: Object, ledger: Dictionary, legacy: Dictionary) -> Dictionary:
	# Exercise the production ledger, not just the transport verifier. Its
	# expected schema must come from the selected policy, never the receipt.
	var checks := {}
	for case in [
		["upright_with_legacy_schema", ledger, _selected_policy_id_v1(), Facade.SELECTED_CONTROLLER_RECEIPT_SCHEMA],
		["upright_with_parent_schema", ledger, _selected_policy_id_v1(), Facade.SdkAdapterScript.DEVELOPMENT_ABSENT_CONTACT_REFERENCE_RECEIPT_SCHEMA],
		["legacy_with_upright_schema", legacy, "", Facade.SdkAdapterScript.DEVELOPMENT_UPRIGHT_STANCE_RECEIPT_SCHEMA],
	]:
		var original: Dictionary = case[1]
		var portable: Dictionary = original.portable_step_receipt.duplicate(true)
		portable.native_step_transport_verification.controller_receipt_schema_version = case[3]
		# Keep the advertised schema-exact flag true: the ledger must check
		# the actual identity rather than trust that self-reported boolean.
		var result := Facade.walking_ledger_application_intent_v2(sdk, 900, "walking_resume", original.session_id, 1,
			portable, original.authority_application_receipt, original.motor_population_readback,
			original.walking_actuation_handoff_receipt, case[2])
		checks[case[0] + "_refuses"] = result.get("ok") == false and result.get("walking_ledger_predicate_receipt", {}).get("failed_predicate_ids", []).has("identity.native_transport_verification_valid")
	return checks

func _synthetic_sequence_state_v1(adapter: RefCounted, step: int) -> Dictionary:
	var state: Dictionary = super._synthetic_sequence_state_v1(adapter, step)
	# A synthetic measured tilt, not an edited retained observation or world.
	var half_pitch := 0.04 * sin(float(step) / 19.0)
	state.base_pose_world.orientation_xyzw = {"x": sin(half_pitch), "y": 0.0, "z": 0.0, "w": cos(half_pitch)}
	# Contact-present without bearing must not select upright stance geometry.
	if step % 17 == 0:
		state.ordered_contact_observations[0].presence = true
		state.ordered_contact_observations[0].bears_support = false
	return state
