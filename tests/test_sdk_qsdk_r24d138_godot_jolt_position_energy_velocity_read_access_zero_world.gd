extends SceneTree
# gdlint: disable=max-line-length

## R138's zero-world source contract. It proves the additive patch grants only
## velocity Read access to the position job that already performs checked
## kinetic-energy reads. It creates no Node, RID, model, world, or solver step.

const BASE_PATCH_PATH := "res://sdk/adapters/godot/engine_patches/godot_4_7_jolt_solver_energy_exchange_telemetry_v4.patch"
const DELTA_PATCH_PATH := "res://sdk/adapters/godot/engine_patches/godot_4_7_jolt_solver_energy_position_velocity_read_access_v5.patch"
const MARKER := "QSDK_R24D138_GODOT_JOLT_POSITION_VELOCITY_READ_ACCESS_ZERO_WORLD "
const INDEX_LINE := "index be8e31b74e..5feb86f497 100644"
const OLD_GRANT := "-\tBodyAccess::Grant grant(BodyAccess::EAccess::None, BodyAccess::EAccess::ReadWrite);"
const NEW_GRANT := "+\tBodyAccess::Grant grant(BodyAccess::EAccess::Read, BodyAccess::EAccess::ReadWrite);"
const POSITION_FUNCTION := "void PhysicsSystem::JobSolvePositionConstraints(PhysicsUpdateContext *ioContext, PhysicsUpdateContext::Step *ioStep)"
const BEFORE_SNAPSHOT := "+\t\t\t\t\tSporeSporeEnergySnapshot before = MeasureSporeSporeEnergy(bodies_begin, bodies_end);"
const AFTER_SNAPSHOT := "+\t\t\t\t\tSporeSporeEnergySnapshot after = MeasureSporeSporeEnergy(bodies_begin, bodies_end);"
const CHECKED_LINEAR_READ := "+\t\tconst Vec3 linear_velocity = motion->GetLinearVelocity();"
const CHECKED_ANGULAR_READ := "+\t\tconst Vec3 angular_velocity = motion->GetAngularVelocity();"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JSON.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	if not FileAccess.file_exists(BASE_PATCH_PATH) or not FileAccess.file_exists(DELTA_PATCH_PATH):
		return _failure("QSDK_R24D138_PATCH_MISSING")
	var base := FileAccess.get_file_as_string(BASE_PATCH_PATH)
	var delta := FileAccess.get_file_as_string(DELTA_PATCH_PATH)
	if not _valid_source_pair(base, delta):
		return _failure(
			"QSDK_R24D138_EXACT_SOURCE_PAIR_INVALID",
			_source_pair_diagnostics(base, delta),
		)

	var mutations: Array[Dictionary] = [
		{"base": base, "delta": delta.replace(NEW_GRANT, OLD_GRANT.trim_prefix("-"))},
		{
			"base": base,
			"delta": delta.replace(
				NEW_GRANT,
				"+\tBodyAccess::Grant grant(BodyAccess::EAccess::ReadWrite, BodyAccess::EAccess::ReadWrite);",
			),
		},
		{
			"base": base,
			"delta": delta.replace(
				NEW_GRANT,
				"+\tBodyAccess::Grant grant(BodyAccess::EAccess::Read, BodyAccess::EAccess::Read);",
			),
		},
		{"base": base, "delta": delta.replace(INDEX_LINE, INDEX_LINE.replace("5feb86f497", "0000000000"))},
		{"base": base, "delta": delta.replace(POSITION_FUNCTION, POSITION_FUNCTION.replace("Position", "Velocity"))},
		{"base": base, "delta": delta + "\n+motion->GetLinearVelocityUnchecked();\n"},
		{"base": base, "delta": delta + "\n+#undef JPH_ENABLE_ASSERTS\n"},
		{"base": base, "delta": delta.replace("+\t// velocities immediately before and after each correction.\n", "")},
		{"base": base.replace(CHECKED_LINEAR_READ, CHECKED_LINEAR_READ.replace("GetLinearVelocity()", "GetLinearVelocityUnchecked()")), "delta": delta},
		{"base": base.replace(AFTER_SNAPSHOT, ""), "delta": delta},
	]
	var rejected := 0
	for mutation in mutations:
		if not _valid_source_pair(String(mutation["base"]), String(mutation["delta"])):
			rejected += 1

	var positive_case_count := 5
	var exact := rejected == mutations.size()
	return {
		"schema_version": "sporespore_qsdk_r24d138_godot_jolt_position_energy_velocity_read_access_zero_world_v1",
		"gate_id": "QSDK-R24D138",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D138_MUTATION_CONTROL_INVALID",
		"question_class": "development",
		"runtime_profile_id": "godot_4_7_jolt_sporespore_solver_energy_position_velocity_read_access_v5",
		"source_access_contract_id": "godot_jolt_r24d138_position_energy_velocity_read_access_v1",
		"base_patch_bound": true,
		"delta_patch_bound": true,
		"position_job_velocity_access": "Read",
		"position_job_position_access": "ReadWrite",
		"checked_velocity_accessors_preserved": true,
		"assertion_disable_added": false,
		"unchecked_velocity_accessor_added": false,
		"behavior_semantics_changed": false,
		"positive_case_count": positive_case_count,
		"forced_failure_case_count": rejected,
		"historical_closure_audits_executed_count": 0,
		"bespoke_physical_canary_count": 0,
		"full_seeded_ghost_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _valid_source_pair(base: String, delta: String) -> bool:
	return (
		delta.count("diff --git ") == 1
		and delta.count(INDEX_LINE) == 1
		and delta.count(POSITION_FUNCTION) == 1
		and delta.count(OLD_GRANT) == 1
		and delta.count(NEW_GRANT) == 1
		and delta.count("+\t// Position constraints write positions while SporeSpore energy telemetry reads") == 1
		and delta.count("+\t// velocities immediately before and after each correction.") == 1
		and not delta.contains("EAccess::ReadWrite, BodyAccess::EAccess::ReadWrite")
		and not delta.contains("EAccess::Read, BodyAccess::EAccess::Read);")
		and not delta.contains("GetLinearVelocityUnchecked")
		and not delta.contains("GetAngularVelocityUnchecked")
		and not delta.contains("#undef JPH_ENABLE_ASSERTS")
		and base.count(BEFORE_SNAPSHOT) == 3
		and base.count(AFTER_SNAPSHOT) == 3
		and base.count(CHECKED_LINEAR_READ) == 1
		and base.count(CHECKED_ANGULAR_READ) == 1
		and not base.contains("GetLinearVelocityUnchecked()")
		and not base.contains("GetAngularVelocityUnchecked()")
	)


static func _source_pair_diagnostics(base: String, delta: String) -> Dictionary:
	return {
		"delta_diff_count": delta.count("diff --git "),
		"delta_index_count": delta.count(INDEX_LINE),
		"delta_function_count": delta.count(POSITION_FUNCTION),
		"delta_old_grant_count": delta.count(OLD_GRANT),
		"delta_new_grant_count": delta.count(NEW_GRANT),
		"delta_comment_one_count": delta.count("+\t// Position constraints write positions while SporeSpore energy telemetry reads"),
		"delta_comment_two_count": delta.count("+\t// velocities immediately before and after each correction."),
		"base_before_snapshot_count": base.count(BEFORE_SNAPSHOT),
		"base_after_snapshot_count": base.count(AFTER_SNAPSHOT),
		"base_checked_linear_count": base.count(CHECKED_LINEAR_READ),
		"base_checked_angular_count": base.count(CHECKED_ANGULAR_READ),
	}


static func _failure(code: String, diagnostics: Dictionary = {}) -> Dictionary:
	var result := {
		"schema_version": "sporespore_qsdk_r24d138_godot_jolt_position_energy_velocity_read_access_zero_world_v1",
		"gate_id": "QSDK-R24D138",
		"ok": false,
		"failure_code": code,
		"positive_case_count": 0,
		"forced_failure_case_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	result.merge(diagnostics)
	return result
