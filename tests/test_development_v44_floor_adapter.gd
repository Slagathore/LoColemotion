extends "res://tests/test_development_v43_floor_adapter.gd"

func _component_profile_path_v1() -> String:
	return "res://sdk/development/recovery_candidates/v44-support-hold-posture-v1.json"

func _selected_policy_id_v1() -> String:
	return Shared.Policy.POSTURE_POLICY_ID

func _additional_ledger_checks_v1(sdk: Object, ledger: Dictionary, legacy: Dictionary) -> Dictionary:
	var checks: Dictionary = super._additional_ledger_checks_v1(sdk, ledger, legacy)
	for case in [
		["hold_posture_with_progression_schema", ledger, _selected_policy_id_v1(), Facade.SdkAdapterScript.DEVELOPMENT_SUPPORT_PROGRESSION_RECEIPT_SCHEMA],
		["legacy_with_hold_posture_schema", legacy, "", Facade.SdkAdapterScript.DEVELOPMENT_SUPPORT_HOLD_POSTURE_RECEIPT_SCHEMA],
	]:
		var original: Dictionary = case[1]
		var portable: Dictionary = original.portable_step_receipt.duplicate(true)
		portable.native_step_transport_verification.controller_receipt_schema_version = case[3]
		var result := Facade.walking_ledger_application_intent_v2(sdk, 900, "walking_resume", original.session_id, 1,
			portable, original.authority_application_receipt, original.motor_population_readback,
			original.walking_actuation_handoff_receipt, case[2])
		checks[case[0] + "_refuses"] = result.get("ok") == false and result.get("walking_ledger_predicate_receipt", {}).get("failed_predicate_ids", []).has("identity.native_transport_verification_valid")
	return checks
