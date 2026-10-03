extends "res://tests/test_development_v42_floor_adapter.gd"

func _component_profile_path_v1() -> String:
	return "res://sdk/development/recovery_candidates/v43-support-progression-v1.json"

func _selected_policy_id_v1() -> String:
	return Shared.Policy.PROGRESSION_POLICY_ID

func _synthetic_sequence_state_v1(adapter: RefCounted, step: int) -> Dictionary:
	var state: Dictionary = super._synthetic_sequence_state_v1(adapter, step)
	# Synthetic loss/recovery windows, not modified retained observations.
	# Unlike the old interleaved pattern, this supplies three clear samples
	# after each loss so the bounded progression guard can hold AND release.
	for index in range(state.ordered_contact_observations.size()):
		var contact: Dictionary = state.ordered_contact_observations[index]
		contact.presence = not (step % 32 < 7 and index == int(step / 32) % 4)
		contact.bears_support = contact.presence
	if step % 41 == 0:
		state.ordered_contact_observations[0].presence = true
		state.ordered_contact_observations[0].bears_support = false
	return state

func _additional_ledger_checks_v1(sdk: Object, ledger: Dictionary, legacy: Dictionary) -> Dictionary:
	var checks: Dictionary = super._additional_ledger_checks_v1(sdk, ledger, legacy)
	for case in [
		["progression_with_v42_schema", ledger, _selected_policy_id_v1(), Facade.SdkAdapterScript.DEVELOPMENT_STANCE_LATCH_RECEIPT_SCHEMA],
		["legacy_with_progression_schema", legacy, "", Facade.SdkAdapterScript.DEVELOPMENT_SUPPORT_PROGRESSION_RECEIPT_SCHEMA],
	]:
		var original: Dictionary = case[1]
		var portable: Dictionary = original.portable_step_receipt.duplicate(true)
		portable.native_step_transport_verification.controller_receipt_schema_version = case[3]
		var result := Facade.walking_ledger_application_intent_v2(sdk, 900, "walking_resume", original.session_id, 1,
			portable, original.authority_application_receipt, original.motor_population_readback,
			original.walking_actuation_handoff_receipt, case[2])
		checks[case[0] + "_refuses"] = result.get("ok") == false and result.get("walking_ledger_predicate_receipt", {}).get("failed_predicate_ids", []).has("identity.native_transport_verification_valid")
	return checks
