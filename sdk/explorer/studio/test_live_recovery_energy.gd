extends RefCounted
const Energy := preload("res://sdk/adapters/godot/gdscript/live_recovery_energy_v1.gd")
const Fixture := preload("res://sdk/explorer/studio/test_live_recovery_epoch.gd")
const Epoch := Energy.Epoch
const World := Energy.World


static func input_fixture(step: int) -> Dictionary:
	var input := Fixture.fixture(step,600+step)
	input.telemetry.joint_velocity_constraint_exchange_j = 0.012
	input.telemetry.contact_velocity_constraint_exchange_j = -0.003
	input.telemetry.rotation_integration_kinetic_exchange_j = 0.0007
	input.telemetry.position_constraint_kinetic_exchange_j = -0.001
	input.telemetry.position_constraint_mass_weighted_displacement_kg_m = Vector3(0,0.00002,0)
	return input


static func raw_fixture(step: int, passive: bool = false) -> Dictionary:
	var bodies: Array = []
	var joints: Array = []
	var motors: Array = []
	for id in World.ORDERED_BODY_IDS:
		bodies.append({"body_id": id, "total_gravity_world_m_s2": Vector3(0,-9.81,0),
			"linear_damp_mode": int(RigidBody3D.DAMP_MODE_REPLACE), "angular_damp_mode": int(RigidBody3D.DAMP_MODE_REPLACE),
			"linear_damp": 0.0, "angular_damp": 0.0, "continuous_cd": false})
	for index in range(8):
		var positive := float(PackedFloat32Array([0.0002 * (index+1) if not passive else 0.0])[0])
		var absorbed := float(PackedFloat32Array([0.00005 * (index+1) if not passive else 0.0])[0])
		joints.append({"joint_id": World.ORDERED_JOINT_IDS[index], "motor_enabled": not passive})
		motors.append({"joint_id": World.ORDERED_JOINT_IDS[index], "actuator_id": World.ORDERED_ACTUATOR_IDS[index],
			"joint_instance_id": 2000+index, "published_cap_nms": World.ORDERED_PUBLISHED_CAPS_NMS[index],
			"target_velocity_readback_rad_s": 1.0 if not passive else 0.0,
			"maximum_impulse_readback_nms": World.ORDERED_STRICT_HOST_CAPS_NMS[index],
			"telemetry": {"schema": "sporespore.godot_jolt_hinge_motor_telemetry.v2", "captured_during_active_step": true,
				"snapshot_is_current_space_step": true, "capture_space_step_sequence": 600+step, "read_space_step_sequence": 600+step,
				"solver_step_s": 1.0/120.0, "signed_motor_impulse_nms": 0.001 if not passive else 0.0,
				"positive_motor_work_j": positive, "absorbed_motor_work_j": absorbed,
				"net_motor_work_j": float(PackedFloat32Array([positive-absorbed])[0])}})
	return {"ordered_body_readbacks": bodies, "ordered_joint_readbacks": joints, "ordered_motor_sources": motors,
		"solver_telemetry": input_fixture(step).telemetry, "no_actuation_requested": passive, "external_events": []}


static func run(sdk: Object, context: Dictionary) -> Dictionary:
	var checks := 0
	var failures: Array = []
	var frames: Array = []
	for step in [300,301,302]: frames.append(Fixture.project(sdk, input_fixture(step)))
	var epoch_begin := Epoch.begin_v1(sdk, frames[0], "energy_epoch", "sha256:"+"2".repeat(64))
	var first_epoch := Epoch.advance_v1(sdk, epoch_begin.state, frames[1])
	var second_epoch := Epoch.advance_v1(sdk, first_epoch.state_after, frames[2])
	var begun := Energy.begin_v1(sdk, context, epoch_begin.state)
	checks += 1
	if begun.get("ok") != true: return {"ok": false, "checks": checks, "failures": ["begin", begun]}
	var raw := raw_fixture(301); var raw_before := raw.duplicate(true)
	var source := Energy.project_sources_v1(sdk, context, frames[1], raw)
	checks += 1
	if source.get("ok") != true or raw != raw_before: return {"ok": false, "checks": checks, "failures": ["source", source]}
	var before: Dictionary = begun.state.duplicate(true)
	var first := Energy.advance_v1(sdk, begun.state, first_epoch, source)
	checks += 1
	if first.get("ok") != true or begun.state != before: return {"ok": false, "checks": checks, "failures": ["advance", first]}
	var passive := Energy.project_sources_v1(sdk, context, frames[2], raw_fixture(302,true))
	var second := Energy.advance_v1(sdk, first.state_after, second_epoch, passive)
	checks += 1
	if second.get("ok") != true: return {"ok": false, "checks": checks, "failures": ["passive", second]}
	var batch := Energy.Calls.call_v1(sdk, "recovery_energy_balance_aggregate_v3_json", {
		"schema_version": "sporespore_recovery_energy_balance_aggregation_request_v3", "source_profile_id": Epoch.Staging.MAPPING_PROFILE_ID,
		"initial_mechanical_energy_j": frames[0].mechanical_energy_j, "current_mechanical_energy_j": frames[2].mechanical_energy_j,
		"ordered_increments": [first.energy_increment,second.energy_increment]})
	checks += 1
	if batch.get("ok") != true: return {"ok": false, "checks": checks, "failures": ["core batch", batch]}
	for key in Energy.CHANNELS:
		checks += 1
		if batch.value.ledger["cumulative_"+key] != second.state_after.ledger["cumulative_"+key]: failures.append("core accumulator "+key)
	for kind in ["missing_motor", "duplicate_joint", "wrong_actuator", "wrong_joint", "motor_clock", "stale_motor", "motor_work",
		"cap_exceeded", "cap_readback", "motor_disabled", "damping", "gravity", "missing_body", "solver_clock", "solver_incomplete",
		"solver_rotation_missing", "external_impulse", "false_zero_command"]:
		var changed := raw_fixture(301)
		match kind:
			"missing_motor": changed.ordered_motor_sources.pop_back()
			"duplicate_joint": changed.ordered_motor_sources[1].joint_instance_id = changed.ordered_motor_sources[0].joint_instance_id
			"wrong_actuator": changed.ordered_motor_sources[0].actuator_id = "wrong"
			"wrong_joint": changed.ordered_joint_readbacks[0].joint_id = "wrong"
			"motor_clock": changed.ordered_motor_sources[0].telemetry.read_space_step_sequence += 1
			"stale_motor": changed.ordered_motor_sources[0].telemetry.snapshot_is_current_space_step = false
			"motor_work": changed.ordered_motor_sources[0].telemetry.net_motor_work_j += 1.0
			"cap_exceeded": changed.ordered_motor_sources[0].telemetry.signed_motor_impulse_nms = 100.0
			"cap_readback": changed.ordered_motor_sources[0].maximum_impulse_readback_nms = 100.0
			"motor_disabled": changed.ordered_joint_readbacks[0].motor_enabled = false
			"damping": changed.ordered_body_readbacks[0].linear_damp = 0.1
			"gravity": changed.ordered_body_readbacks[0].total_gravity_world_m_s2 *= 0.5
			"missing_body": changed.ordered_body_readbacks.pop_back()
			"solver_clock": changed.solver_telemetry.read_space_step_sequence += 1
			"solver_incomplete": changed.solver_telemetry.complete = false
			"solver_rotation_missing": changed.solver_telemetry.erase("rotation_integration_kinetic_exchange_j")
			"external_impulse": changed.external_events.append({"apply_at_frame":301})
			"false_zero_command": changed.no_actuation_requested = true
		checks += 1
		if Energy.project_sources_v1(sdk, context, frames[1], changed).get("ok") == true: failures.append(kind)
	for key in ["increment_count", "last_global_step", "unobserved_history_claimed", "context_sha256"]:
		var changed := before.duplicate(true)
		if key == "unobserved_history_claimed": changed[key] = true
		elif key == "context_sha256": changed[key] = "sha256:"+"3".repeat(64)
		else: changed[key] += 1
		changed = Epoch._seal(sdk, changed); checks += 1
		if Energy.advance_v1(sdk, changed, first_epoch, source).get("ok") == true: failures.append("state "+key)
	checks += 1
	if Energy.advance_v1(sdk, first.state_after, first_epoch, source).get("ok") == true: failures.append("duplicate step")
	var replaced := raw_fixture(302,true); replaced.ordered_motor_sources[0].joint_instance_id = 9999
	checks += 1
	if Energy.advance_v1(sdk, first.state_after, second_epoch, Energy.project_sources_v1(sdk,context,frames[2],replaced)).get("ok") == true: failures.append("replaced joint")
	checks += 1
	if Energy.begin_v1(sdk,context,first_epoch.state_after).get("ok") == true: failures.append("reused epoch origin")
	return {"ok": failures.is_empty(), "checks": checks, "failures": failures, "synthetic": true,
		"positive_fixture": Epoch.json_safe_v1({"epoch_rows":[{"capture":frames[0],"transition":epoch_begin},
			{"capture":frames[1],"transition":first_epoch},{"capture":frames[2],"transition":second_epoch}],
			"energy_rows":[{"begin":begun},{"sources":source,"transition":first},{"sources":passive,"transition":second}]}),
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
