extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"
const Probe := preload("res://sdk/trace_analysis/recovery_post_completion_hold_probe_v1.gd")
## Inspect retained native bytes without invoking a policy or advancing a session.
func _dispatch(sdk: Object, input: Dictionary, _binding: Dictionary) -> Dictionary:
	var native: Dictionary = sdk.decode_exact_json_v1(input.raw_response)
	var prior: Dictionary = input.request.memory
	var next: Dictionary = native.value.next_memory
	var crossed := next.duplicate(true)
	crossed.measured_support_transfer.preparation_commands += 1
	var corrected := Probe.same_json_value_v1(prior, next)
	var mutation_refused := not Probe.same_json_value_v1(prior, crossed)
	var difference := {}
	for key in prior:
		if Transport.stringify(prior[key]) != Transport.stringify(next.get(key)):
			difference[key] = {"prior": prior[key], "next": next.get(key), "value_equal": prior[key] == next.get(key)}
	return {"ok": corrected and mutation_refused, "corrected_memory_comparison": corrected,
		"changed_counter_refused": mutation_refused, "outer_ok": native.ok, "safe_no_actuation": native.value.actuation.safe_no_actuation,
		"failure_code_matches": native.value.actuation.failure_codes == ["FRAME_INVALID"],
		"memory_value_equal": prior == next, "memory_transport_equal": Transport.stringify(prior) == Transport.stringify(next),
		"differences": difference, "native_policy_calls": 0}
