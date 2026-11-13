extends RefCounted
const Epoch := preload("res://sdk/adapters/godot/gdscript/live_recovery_epoch_v1.gd")


static func fixture(step: int, native_step: int) -> Dictionary:
	var snapshots := {}
	var instances: Array = []
	for index in range(9):
		instances.append(1000 + index)
		snapshots[Epoch.Boundary.ORDERED_BODY_IDS[index]] = {"callback_sequence": step, "source_measurement": true,
			"transform": Transform3D(Basis.IDENTITY, Vector3(index * 0.1, 1.0 + (step - 300) * 0.001, 0.0)),
			"linear_velocity_world_m_s": Vector3(0.1, -0.2, 0), "angular_velocity_world_rad_s": Vector3(0, 0, 0.2),
			"total_gravity_world_m_s2": Vector3(0, -9.81, 0), "inverse_inertia_tensor_world_kg_inv_m2": Basis.IDENTITY,
			"mass_kg": 1.0, "solver_step_s": 1.0 / 120.0}
	var telemetry := {"schema": Epoch.Solver.TELEMETRY_SCHEMA_VERSION, "profile_id": Epoch.Solver.TELEMETRY_PROFILE_ID,
		"position_constraint_mass_weighted_displacement_kg_m": Vector3.ZERO}
	for key in Epoch.Solver.REQUIRED_INTEGER_FIELDS: telemetry[key] = 0
	for key in Epoch.Solver.REQUIRED_NUMERIC_FIELDS: telemetry[key] = 0.0
	for key in Epoch.Solver.REQUIRED_BOOLEAN_FIELDS: telemetry[key] = true
	telemetry.mechanical_energy_residual_used_as_work_source = false
	for key in ["telemetry_sequence", "capture_space_step_sequence", "read_space_step_sequence"]: telemetry[key] = native_step
	for key in ["collision_step_count", "constrained_island_count", "velocity_measured_island_count", "position_measured_island_count",
		"joint_velocity_phase_count", "position_constraint_phase_count"]: telemetry[key] = 1
	for key in ["rotation_integration_expected_active_body_count", "rotation_integration_observed_active_body_count",
		"rotation_integration_dynamic_body_count", "dynamic_body_observation_count"]: telemetry[key] = 9
	return {"identity": {"attempt_id": "live_epoch_synthetic", "arm_id": "active", "model_instance_id": "same_model"},
		"snapshots": snapshots, "instances": instances, "step": step, "native_step": native_step, "telemetry": telemetry}


static func project(sdk: Object, input: Dictionary) -> Dictionary:
	return Epoch.project_v1(sdk, input.identity, input.snapshots, input.instances, input.step, input.native_step, input.telemetry)


static func run(sdk: Object) -> Dictionary:
	var checks := 0
	var failures: Array = []
	var input := fixture(300, 900)
	var untouched := input.duplicate(true)
	var first := project(sdk, input)
	checks += 1
	if first.get("ok") != true or input != untouched: return {"ok": false, "checks": checks, "failures": ["initial projection", first]}
	var begun := Epoch.begin_v1(sdk, first, "live_epoch_1", "sha256:" + "1".repeat(64))
	checks += 1
	if begun.get("ok") != true or not Epoch.state_valid_v1(sdk, begun.state): return {"ok": false, "checks": checks, "failures": ["fresh epoch", begun]}
	var original: Dictionary = begun.state.duplicate(true)
	var second := project(sdk, fixture(301, 901))
	var advanced := Epoch.advance_v1(sdk, begun.state, second)
	checks += 1
	if (advanced.get("ok") != true or begun.state != original or advanced.get("epoch_local_step") != 1
		or advanced.get("completed_global_step") != 301): return {"ok": false, "checks": checks, "failures": ["contiguous advance", advanced]}
	var third := Epoch.advance_v1(sdk, advanced.state_after, project(sdk, fixture(302, 902)))
	checks += 1
	if third.get("ok") != true or third.get("epoch_local_step") != 2: return {"ok": false, "checks": checks, "failures": ["second pair", third]}
	checks += 1
	if (third.state_after.cumulative_signed_discrete_staging_exchange_j != advanced.staging_observer_receipt.signed_discrete_staging_exchange_j
		+ third.staging_observer_receipt.signed_discrete_staging_exchange_j): failures.append("ordered staging sum")
	for clocks in [[300,900],[299,899],[302,902],[301,902],[301,900]]:
		checks += 1
		if Epoch.advance_v1(sdk, original, project(sdk, fixture(clocks[0], clocks[1]))).get("ok") == true: failures.append("crossed clock")
	for key in ["attempt_id", "arm_id", "model_instance_id"]:
		var changed := fixture(301, 901); changed.identity[key] = "crossed"
		checks += 1
		if Epoch.advance_v1(sdk, original, project(sdk, changed)).get("ok") == true: failures.append("crossed identity")
	for key in ["mass_kg", "total_gravity_world_m_s2", "solver_step_s"]:
		var changed := fixture(301, 901)
		for value in changed.snapshots.values(): value[key] = value[key] * 1.01
		checks += 1
		if Epoch.advance_v1(sdk, original, project(sdk, changed)).get("ok") == true: failures.append("changed body/profile")
	var replaced := fixture(301, 901); replaced.instances[0] = 9999
	checks += 1
	if Epoch.advance_v1(sdk, original, project(sdk, replaced)).get("ok") == true: failures.append("rebuilt body")
	for key in ["callback_sequence", "source_measurement", "transform", "inverse_inertia_tensor_world_kg_inv_m2", "solver_step_s"]:
		var changed := fixture(300, 900); changed.snapshots.torso[key] = null
		checks += 1
		if project(sdk, changed).get("ok") == true: failures.append("missing native field")
	for key in ["capture_space_step_sequence", "read_space_step_sequence", "complete", "rotation_integration_kinetic_exchange_j"]:
		var changed := fixture(300, 900); changed.telemetry.erase(key)
		checks += 1
		if project(sdk, changed).get("ok") == true: failures.append("missing solver field")
	for key in ["observed_pair_count", "global_sequence_rewritten", "complete_recovery_energy_partition", "unobserved_pre_epoch_history_claimed"]:
		var changed := original.duplicate(true); changed[key] = 99 if key == "observed_pair_count" else true
		changed = Epoch._seal(sdk, changed); checks += 1
		if Epoch.advance_v1(sdk, changed, second).get("ok") == true: failures.append("forged epoch")
	var corrupted := first.duplicate(true); corrupted.mechanical_energy_j += 1.0
	checks += 1
	if Epoch.begin_v1(sdk, corrupted, "other", "sha256:" + "1".repeat(64)).get("ok") == true: failures.append("changed boundary digest")
	return {"ok": failures.is_empty(), "checks": checks, "failures": failures, "synthetic": true,
		"positive_rows": Epoch.json_safe_v1([{"capture": first, "transition": begun}, {"capture": second, "transition": advanced}, {"capture": project(sdk, fixture(302,902)), "transition": third}]),
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
