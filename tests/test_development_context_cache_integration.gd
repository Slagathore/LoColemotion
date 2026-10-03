extends "res://sdk/adapters/godot/gdscript/development_cached_recovery_smoke_worker_v1.gd"

var integration_checks: Dictionary = {}


## Only pure preflights, missing-model refusals and publication run here.
func _initialize() -> void:
	_profile_start_us = Time.get_ticks_usec()
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var context := RouteScript.prepare_complete_energy_context_v18(sdk, RECOVERY_CONTROLLER_ID)
	var model := {
		"ok": true, "host_step_count": 0, NativeEpochRoute.MODEL_EPOCH_INITIALIZED_KEY: false
	}
	var intent := {"ok": true, "semantic_step": 1, "phase": "confirm_prone"}
	var cache := CountedContextCache.new()
	var valid := _preflight_v1(
		sdk, context, model, intent, 1, "confirm_prone", "global_only", {}, cache
	)
	integration_checks["real_preflight_positive"] = valid.get("ok") == true
	var repeated := _preflight_v1(
		sdk, context, model, intent, 1, "confirm_prone", "global_only", {}, cache
	)
	integration_checks["real_preflight_warm_hit"] = (
		JsonTransportScript.stringify(valid) == JsonTransportScript.stringify(repeated)
		and cache.full_checks == 1
		and cache.hits == 1
		and cache.calls == [2, 0]
	)
	var cases: Array = []
	for key in ["ok", "host_step_count"]:
		var changed := model.duplicate(true)
		changed.erase(key)
		cases.append({"label": "model_missing_" + key, "model": changed})
	for key in ["ok", "semantic_step", "phase"]:
		var changed := intent.duplicate(true)
		changed.erase(key)
		cases.append({"label": "intent_missing_" + key, "intent": changed})
	cases.append({"label": "zero_step", "step": 0})
	cases.append({"label": "wrong_sequence", "step": 2})
	cases.append({"label": "empty_phase", "phase": ""})
	cases.append({"label": "wrong_phase", "phase": "other"})
	cases.append({"label": "unknown_epoch_mode", "mode": "other"})
	for key in NativeEpochRoute.OUTCOME_DERIVED_KEYS:
		var changed := intent.duplicate(true)
		changed[key] = true
		cases.append({"label": "outcome_in_intent_" + key, "intent": changed})
		cases.append({"label": "outcome_in_interaction_" + key, "interaction": {key: true}})
	var initialized := model.duplicate(true)
	initialized[NativeEpochRoute.MODEL_EPOCH_INITIALIZED_KEY] = true
	cases.append({"label": "global_after_epoch", "model": initialized})
	cases.append({"label": "global_with_interaction", "interaction": {"extra": true}})
	cases.append({"label": "initialize_missing_receipt", "mode": "initialize_epoch"})
	cases.append(
		{"label": "initialize_already_started", "mode": "initialize_epoch", "model": initialized}
	)
	cases.append({"label": "advance_before_epoch", "mode": "global_and_epoch"})
	cases.append(
		{"label": "advance_missing_epoch_state", "mode": "global_and_epoch", "model": initialized}
	)
	cases.append(
		{
			"label": "advance_with_interaction",
			"mode": "global_and_epoch",
			"model": initialized,
			"interaction": {"extra": true}
		}
	)
	for item in cases:
		var args := [
			sdk,
			context,
			item.get("model", model),
			item.get("intent", intent),
			item.get("step", 1),
			item.get("phase", "confirm_prone"),
			item.get("mode", "global_only"),
			item.get("interaction", {})
		]
		var plain: Dictionary = NativeEpochRoute.collection_preflight_v1.callv(args)
		args.append(cache)
		var cached: Dictionary = NativeEpochRoute.collection_preflight_v1.callv(args)
		integration_checks[item["label"]] = (
			plain.get("ok") == false
			and JsonTransportScript.stringify(plain) == JsonTransportScript.stringify(cached)
		)
	var next_model := model.duplicate(true)
	next_model["host_step_count"] = 1
	var next_intent := intent.duplicate(true)
	next_intent["semantic_step"] = 2
	var before := cache.full_checks
	integration_checks["fresh_sequence_still_checked_and_accepted"] = (
		(
			(
				_preflight_v1(
					sdk,
					context,
					next_model,
					next_intent,
					2,
					"confirm_prone",
					"global_only",
					{},
					cache
				)
				. get("ok")
			)
			== true
		)
		and cache.full_checks == before
	)
	var changed_context := context.duplicate(true)
	changed_context["r170_behavior_context_sha256"] = "sha256:" + "0".repeat(64)
	integration_checks["context_changed_after_hit_refuses"] = (
		(
			(
				_preflight_v1(
					sdk,
					changed_context,
					model,
					intent,
					1,
					"confirm_prone",
					"global_only",
					{},
					cache
				)
				. get("ok")
			)
			== false
		)
		and cache.full_checks == before + 1
	)
	# An empty model is rejected at the native sampler's first guard, before any
	# body access/read. Exercise the actual outer collector twice to prove both
	# call sites are wired, and a hit does not skip that downstream refusal.
	cache = CountedContextCache.new()
	var plain := NativeEpochRoute.collect_completed_step_v1(
		sdk, context, model, intent, 1, "confirm_prone", "global_only"
	)
	for iteration in range(2):
		var cached := NativeEpochRoute.collect_completed_step_v1(
			sdk, context, model, intent, 1, "confirm_prone", "global_only", {}, null, cache
		)
		integration_checks["real_collection_missing_native_model_" + str(iteration)] = (
			plain.get("ok") == false
			and JsonTransportScript.stringify(plain) == JsonTransportScript.stringify(cached)
		)
	integration_checks["both_real_collection_sites_counted"] = (
		cache.calls == [2, 2] and cache.full_checks == 2 and cache.hits == 2
	)
	_declaration_controls_v1()
	var report := {
		"synthetic_zero_world_fixture": true,
		"source_commit": "a".repeat(40),
		"parent_attempt_id": "b".repeat(32),
		"child_attempt_id": "c".repeat(32),
		"arm_id": "matched_no_kick_continuation",
		"process_id": OS.get_process_id(),
		"diagnostic_declaration_sha256": "sha256:" + "d".repeat(64),
		"solver_step_count": 0,
		"after_interaction_step_count": 0,
		"retained_arm": {"orchestrator_state": {"epoch_start_global_step": null}},
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	_publish_smoke_report_v1(report)
	var ok := integration_checks.values().all(func(value: Variant) -> bool: return value == true)
	print(
		"DEVELOPMENT_CONTEXT_CACHE_INTEGRATION ",
		(
			JsonTransportScript
			. stringify(
				{
					"ok": ok,
					"checks": integration_checks,
					"world_build_count": 0,
					"solver_step_count": 0,
					"native_physics_read_count": 0,
				}
			)
		)
	)
	quit(0 if ok else 1)


func _preflight_v1(
	sdk: Object,
	context: Dictionary,
	model: Dictionary,
	intent: Dictionary,
	step: int,
	phase: String,
	mode: String,
	interaction: Dictionary,
	cache: RefCounted
) -> Dictionary:
	return NativeEpochRoute.collection_preflight_v1(
		sdk, context, model, intent, step, phase, mode, interaction, cache
	)


func _declaration_controls_v1() -> void:
	var declaration := {
		"schema_version": "sporespore_sdk1_development_recovery_smoke_declaration_v1",
		"context_cache_profile_id": CACHE_PROFILE_ID,
		"context_cache_call_sites": CACHE_CALL_SITES,
		"worker_resource": WORKER_RESOURCE,
		"step_cost_profile_id": PROFILE_ID,
		"attempt_id": "b".repeat(32),
		"source_snapshot": {"head": "a".repeat(40)},
		"official_qualification": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"children":
		[
			{
				"child_attempt_id": "c".repeat(32),
				"role": "matched_no_kick_continuation",
				"termination_nonce": "e".repeat(32)
			}
		],
	}
	var raw := JsonTransportScript.stringify(declaration)
	var expected_args := [
		"a".repeat(40),
		"b".repeat(32),
		"c".repeat(32),
		"matched_no_kick_continuation",
		"e".repeat(32)
	]
	integration_checks["declaration_exact_bound_opt_in"] = declaration_allows_cache_v1.callv(
		[raw, "sha256:" + raw.sha256_text()] + expected_args
	)
	integration_checks["declaration_changed_bytes_refuse"] = not declaration_allows_cache_v1.callv(
		[raw + " ", "sha256:" + raw.sha256_text()] + expected_args
	)
	for key in declaration:
		var changed := declaration.duplicate(true)
		changed.erase(key)
		raw = JsonTransportScript.stringify(changed)
		integration_checks["declaration_missing_" + key] = not declaration_allows_cache_v1.callv(
			[raw, "sha256:" + raw.sha256_text()] + expected_args
		)
	for key in ["role", "termination_nonce", "child_attempt_id"]:
		var changed := declaration.duplicate(true)
		changed["children"][0][key] = "wrong"
		raw = JsonTransportScript.stringify(changed)
		integration_checks["declaration_wrong_child_" + key] = not (
			declaration_allows_cache_v1.callv([raw, "sha256:" + raw.sha256_text()] + expected_args)
		)
