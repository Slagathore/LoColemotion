extends RefCounted
## Exact-request memoization for a pure serializer only. Controller calls always execute.
var native: Object
var cache: Dictionary = {}
var hits := 0
var misses := 0
var saved_us := 0
# Historical byte_count counts String characters, not allocated bytes.
var byte_count := 0
var max_cache_characters := 16000000
var eviction_policy := "lru"
var evictions := 0
var clears := 0
var oversized_skips := 0
func _init(value: Object) -> void:
	native = value
func canonicalize_json(input: String) -> String:
	if cache.has(input):
		hits += 1
		var cached: Array = cache[input]
		saved_us += cached[1]
		if eviction_policy == "lru":
			# Dictionary insertion order is the recency queue. Strings are exact keys.
			cache.erase(input)
			cache[input] = cached
		return cached[0]
	var start := Time.get_ticks_usec()
	var result: String = native.canonicalize_json(input)
	var duration := Time.get_ticks_usec()-start
	misses += 1
	var size := input.length()+result.length()
	if eviction_policy == "clear_all":
		# Retain the predecessor policy only for fresh matched diagnostics.
		if byte_count+size > max_cache_characters:
			cache.clear(); byte_count=0; clears+=1
	else:
		# One large request must not evict the working set or exceed its bound.
		if size > max_cache_characters:
			oversized_skips += 1
			return result
		while byte_count+size > max_cache_characters and not cache.is_empty():
			var oldest: String = cache.keys()[0]
			byte_count -= oldest.length()+String(cache[oldest][0]).length()
			cache.erase(oldest)
			evictions += 1
	cache[input] = [result,duration]
	byte_count += size
	return result

func cache_summary() -> Dictionary:
	return {"policy":eviction_policy,"hits":hits,"misses":misses,"evictions":evictions,
		"clears":clears,"oversized_skips":oversized_skips,"entries":cache.size(),
		"retained_characters":byte_count,"maximum_characters":max_cache_characters,
		"scope":"Exact-request pure serialization only; controller calls always execute."}

func version():
	return native.version()

func candidate35_runtime_version():
	return native.candidate35_runtime_version()

func balanced_wave_runtime_version():
	return native.balanced_wave_runtime_version()

func transport_execution_version():
	return native.transport_execution_version()

func transport_execution_contract_json():
	return native.transport_execution_contract_json()

func controller_session_execution_version():
	return native.controller_session_execution_version()

func controller_session_execution_contract_json():
	return native.controller_session_execution_contract_json()

func balanced_wave_native_step_transport_verification_version():
	return native.balanced_wave_native_step_transport_verification_version()

func balanced_wave_native_step_transport_verification_contract_json():
	return native.balanced_wave_native_step_transport_verification_contract_json()

func balanced_wave_native_step_transport_verification_json(raw_response,expected_policy_id,expected_receipt_schema,expected_semantic_step):
	return native.balanced_wave_native_step_transport_verification_json(raw_response,expected_policy_id,expected_receipt_schema,expected_semantic_step)

func compile_bounded_quadruped_json(input):
	return native.compile_bounded_quadruped_json(input)

func compile_recovery_morphology_v1_json(input):
	return native.compile_recovery_morphology_v1_json(input)

func resolve_actuator_cap_profile_v1_json(input):
	return native.resolve_actuator_cap_profile_v1_json(input)

func recovery_initialize_v1_json(input):
	return native.recovery_initialize_v1_json(input)

func recovery_initialize_v2_json(input):
	return native.recovery_initialize_v2_json(input)

func recovery_step_v1_json(input):
	return native.recovery_step_v1_json(input)

func recovery_step_v2_json(input):
	return native.recovery_step_v2_json(input)

func recovery_step_v3_json(input):
	return native.recovery_step_v3_json(input)

func recovery_step_v4_json(input):
	return native.recovery_step_v4_json(input)

func recovery_step_v5_json(input):
	return native.recovery_step_v5_json(input)

func recovery_collect_passive_native_v1_json(input):
	return native.recovery_collect_passive_native_v1_json(input)

func decode_passive_recovery_response_v1(input):
	return native.decode_passive_recovery_response_v1(input)

func decode_exact_json_v1(input):
	return native.decode_exact_json_v1(input)

func recovery_passive_entry_step_v1_json(input):
	return native.recovery_passive_entry_step_v1_json(input)

func recovery_r10k_entry_control_v1_json(input):
	return native.recovery_r10k_entry_control_v1_json(input)

func recovery_partial_fall_step_control_v1_json(input):
	return native.recovery_partial_fall_step_control_v1_json(input)

func recovery_r10q_upright_entry_control_v1_json(input):
	return native.recovery_r10q_upright_entry_control_v1_json(input)

func recovery_upright_step_control_v1_json(input):
	return native.recovery_upright_step_control_v1_json(input)

func recovery_r10r_upright_step_control_v1_json(input):
	return native.recovery_r10r_upright_step_control_v1_json(input)

func recovery_r10y_partial_entry_control_v1_json(input):
	return native.recovery_r10y_partial_entry_control_v1_json(input)

func recovery_r10y_partial_step_control_v1_json(input):
	return native.recovery_r10y_partial_step_control_v1_json(input)

func recovery_r10z_partial_entry_control_v1_json(input):
	return native.recovery_r10z_partial_entry_control_v1_json(input)

func recovery_r10z_partial_step_control_v1_json(input):
	return native.recovery_r10z_partial_step_control_v1_json(input)

func recovery_r10aa_partial_entry_control_v1_json(input):
	return native.recovery_r10aa_partial_entry_control_v1_json(input)

func recovery_r10aa_partial_step_control_v1_json(input):
	return native.recovery_r10aa_partial_step_control_v1_json(input)

func recovery_r10ab_partial_entry_control_v1_json(input):
	return native.recovery_r10ab_partial_entry_control_v1_json(input)

func recovery_r10ab_partial_step_control_v1_json(input):
	return native.recovery_r10ab_partial_step_control_v1_json(input)

func recovery_r10ai_partial_entry_control_v1_json(input):
	return native.recovery_r10ai_partial_entry_control_v1_json(input)

func recovery_r10ai_partial_step_control_v1_json(input):
	return native.recovery_r10ai_partial_step_control_v1_json(input)

func recovery_r10aj_partial_entry_control_v1_json(input):
	return native.recovery_r10aj_partial_entry_control_v1_json(input)

func recovery_r10aj_partial_step_control_v1_json(input):
	return native.recovery_r10aj_partial_step_control_v1_json(input)

func recovery_r10am_partial_entry_control_v1_json(input):
	return native.recovery_r10am_partial_entry_control_v1_json(input)

func recovery_r10am_partial_step_control_v1_json(input):
	return native.recovery_r10am_partial_step_control_v1_json(input)

func recovery_r10ap_partial_entry_control_v1_json(input):
	return native.recovery_r10ap_partial_entry_control_v1_json(input)

func recovery_r10ap_partial_step_control_v1_json(input):
	return native.recovery_r10ap_partial_step_control_v1_json(input)

func recovery_r10dd_partial_entry_control_v1_json(input):
	return native.recovery_r10dd_partial_entry_control_v1_json(input)

func recovery_r10dd_partial_step_control_v1_json(input):
	return native.recovery_r10dd_partial_step_control_v1_json(input)

func recovery_evaluate_trace_v1_json(input):
	return native.recovery_evaluate_trace_v1_json(input)

func recovery_evaluate_trace_v2_json(input):
	return native.recovery_evaluate_trace_v2_json(input)

func recovery_evaluate_trace_v3_json(input):
	return native.recovery_evaluate_trace_v3_json(input)

func recovery_evaluate_trace_v4_json(input):
	return native.recovery_evaluate_trace_v4_json(input)

func recovery_evaluate_trace_v5_json(input):
	return native.recovery_evaluate_trace_v5_json(input)

func recovery_energy_balance_aggregate_v2_json(input):
	return native.recovery_energy_balance_aggregate_v2_json(input)

func recovery_energy_balance_evaluate_v2_json(input):
	return native.recovery_energy_balance_evaluate_v2_json(input)

func recovery_energy_balance_aggregate_v3_json(input):
	return native.recovery_energy_balance_aggregate_v3_json(input)

func recovery_energy_balance_evaluate_v3_json(input):
	return native.recovery_energy_balance_evaluate_v3_json(input)

func recovery_energy_balance_migrate_v1_json(input):
	return native.recovery_energy_balance_migrate_v1_json(input)

func recovery_development_profile_v1_json():
	return native.recovery_development_profile_v1_json()

func recovery_collect_native_v1_json(input):
	return native.recovery_collect_native_v1_json(input)

func recovery_collect_native_v2_json(input):
	return native.recovery_collect_native_v2_json(input)

func recovery_collect_native_v3_json(input):
	return native.recovery_collect_native_v3_json(input)

func recovery_plan_control_v1_json(input):
	return native.recovery_plan_control_v1_json(input)

func recovery_plan_control_v2_json(input):
	return native.recovery_plan_control_v2_json(input)

func recovery_plan_control_v3_json(input):
	return native.recovery_plan_control_v3_json(input)

func recovery_plan_stance_control_v1_json(input):
	return native.recovery_plan_stance_control_v1_json(input)

func recovery_plan_stance_control_v2_json(input):
	return native.recovery_plan_stance_control_v2_json(input)

func recovery_plan_stance_control_v3_json(input):
	return native.recovery_plan_stance_control_v3_json(input)

func recovery_plan_stance_control_v4_json(input):
	return native.recovery_plan_stance_control_v4_json(input)

func candidate35_profile_json(input):
	return native.candidate35_profile_json(input)

func candidate35_initial_memory_json():
	return native.candidate35_initial_memory_json()

func candidate35_step_json(input):
	return native.candidate35_step_json(input)

func balanced_wave_profile_json(input):
	return native.balanced_wave_profile_json(input)

func balanced_wave_policy_profile_json(input):
	return native.balanced_wave_policy_profile_json(input)

func balanced_wave_initial_memory_json():
	return native.balanced_wave_initial_memory_json()

func balanced_wave_policy_initial_memory_json(input):
	return native.balanced_wave_policy_initial_memory_json(input)

func balanced_wave_step_json(input):
	return native.balanced_wave_step_json(input)

func balanced_wave_policy_step_json(input):
	return native.balanced_wave_policy_step_json(input)

func balanced_wave_policy_session_create_json(input):
	return native.balanced_wave_policy_session_create_json(input)

func balanced_wave_policy_session_step_json(input):
	return native.balanced_wave_policy_session_step_json(input)

func balanced_wave_policy_session_destroy_json():
	return native.balanced_wave_policy_session_destroy_json()

func observe_stability_v2_json(input):
	return native.observe_stability_v2_json(input)

func plan_scheduled_load_transfer_v1_json(input):
	return native.plan_scheduled_load_transfer_v1_json(input)

func plan_scheduled_load_transfer_v2_json(input):
	return native.plan_scheduled_load_transfer_v2_json(input)

func plan_scheduled_load_transfer_v3_json(input):
	return native.plan_scheduled_load_transfer_v3_json(input)

func command_centroidal_support_v2_json(input):
	return native.command_centroidal_support_v2_json(input)

func map_endpoint_force_to_joint_v2_json(input):
	return native.map_endpoint_force_to_joint_v2_json(input)

func map_endpoint_force_to_joint_v3_json(input):
	return native.map_endpoint_force_to_joint_v3_json(input)

func bound_stability_influence_v2_json(input):
	return native.bound_stability_influence_v2_json(input)

func bound_stability_influence_v3_json(input):
	return native.bound_stability_influence_v3_json(input)

func gq15_domain_certificate_json():
	return native.gq15_domain_certificate_json()
