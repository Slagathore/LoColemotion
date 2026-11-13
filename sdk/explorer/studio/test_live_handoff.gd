extends RefCounted
const Bridge := preload("res://sdk/adapters/godot/gdscript/live_recovery_controller_v1.gd")
const Fall := preload("res://sdk/adapters/godot/gdscript/live_fall_detector_v1.gd")
const EnergyChecks := preload("res://sdk/explorer/studio/test_live_recovery_energy.gd")
const EpochChecks := EnergyChecks.Fixture
const Epoch := Bridge.Epoch
const Energy := Bridge.Energy
const Bound := Bridge.Bound
const World := Bound.World
const Facade := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd")


static func synthetic_frame(sdk: Object, step: int, height: float = 0.06) -> Dictionary:
	var input := EpochChecks.fixture(step,600+step)
	for snapshot in input.snapshots.values():
		snapshot.solver_step_s = float(PackedFloat32Array([World.OUTER_STEP_DURATION_S])[0])
		snapshot.transform = Transform3D(Basis.IDENTITY,Vector3(0,height,0))
		snapshot.linear_velocity_world_m_s = Vector3.ZERO
		snapshot.angular_velocity_world_rad_s = Vector3.ZERO
	# Explicit static synthetic body: constraint work removes the prescribed
	# gravity velocity increment. No physical residual supplies this source.
	input.telemetry.joint_velocity_constraint_exchange_j = -9.0*0.5*(Vector3(0,-9.81,0)*(1.0/120.0)).length_squared()
	return EpochChecks.project(sdk,input)


static func synthetic_sources(sdk: Object, context: Dictionary, frame: Dictionary) -> Dictionary:
	var step: int = frame.completed_boundary.boundary_sequence
	var raw := EnergyChecks.raw_fixture(step,true)
	raw.solver_telemetry = EpochChecks.fixture(step,600+step).telemetry
	raw.solver_telemetry.joint_velocity_constraint_exchange_j = -9.0*0.5*(Vector3(0,-9.81,0)*(1.0/120.0)).length_squared()
	return Energy.project_sources_v1(sdk,context,frame,raw)


static func passive_application(sdk: Object, step: int, owner: Dictionary, memory: Dictionary = {}, controller: String = Facade.RECOVERY_CONTROLLER_ID) -> Dictionary:
	var rows: Array = []
	for index in range(8):
		rows.append({"actuator_id":World.ORDERED_ACTUATOR_IDS[index],"joint_id":World.ORDERED_JOINT_IDS[index],
			"motor_enabled":false,"motor_target_velocity_rad_s":0.0,"motor_maximum_impulse_nms":World.ORDERED_STRICT_HOST_CAPS_NMS[index]})
	var readback := {"schema_version":Facade.MOTOR_POPULATION_READBACK_SCHEMA,"gate_id":Facade.GATE_ID,"ok":true,
		"global_semantic_step":step,"reason":"synthetic_live_handoff","expected_motor_enabled":false,"ordered_joint_readbacks":rows,
		"motor_enabled_count":0,"zero_target_velocity_count":8,"native_readback_count":24,
		"body_transform_write_count":0,"body_velocity_write_count":0,"body_impulse_write_count":0,"solver_reset_count":0,
		"solver_step_count":0,"physics_state_modified":false,"physical_acceptance_authority":false,"release_authority":false}
	var profile := Facade.CanonicalOwnershipL15.profile_v1(controller)
	return Facade.no_actuation_ledger_application_intent_v2(sdk,step,memory.get("phase","passive_descent"),
		profile.owner if not memory.is_empty() else "none",controller if not memory.is_empty() else null,false,owner,readback,memory,{},controller)


static func synthetic_bound(sdk: Object, context: Dictionary, epoch: Dictionary, energy: Dictionary, sources: Dictionary, application: Dictionary, task: Dictionary = {}) -> Dictionary:
	var fixture := Bridge.Route._zero_world_fixture_for_controller_v1(sdk,context,context.recovery_controller_id)
	if fixture.get("ok") != true: return fixture
	var base: Dictionary = fixture.observation_v3.duplicate(true)
	for key in ["schema_version","applied_actuation","controller_ownership","engine_step_identity","external_interventions","energy_balance"]: base.erase(key)
	var step: int = epoch.state_after.latest.completed_boundary.boundary_sequence
	base.semantic_step = step; base.state.semantic_step = step; base.state.sample_time_s = step*World.OUTER_STEP_DURATION_S
	var rows: Array = []
	for source in epoch.state_after.latest.ordered_body_sources:
		rows.append({"body_id":source.body_id,"callback_sequence":step,"position_world_m":World._vector_json(Epoch._from_vec(source.position_world_m)),
			"orientation_xyzw":{"x":0.0,"y":0.0,"z":0.0,"w":1.0},"mass_kg":source.mass_kg,
			"linear_velocity_world_m_s":{"x":0.0,"y":0.0,"z":0.0},"angular_velocity_world_rad_s":{"x":0.0,"y":0.0,"z":0.0}})
	base.state.base_pose_world.position_m = rows[0].position_world_m
	base.center_of_mass.position_world_m = rows[0].position_world_m
	if rows[0].position_world_m.y > 0.07:
		base.ordered_body_clearance_observations[0].nonfoot_contact_present = false
		base.ordered_body_clearance_observations[0].ventral_surface_contact = false
		base.ordered_body_clearance_observations[0].accumulated_nonfoot_normal_impulse_ns = 0.0
		base.ordered_body_clearance_observations[0].minimum_nonfoot_clearance_m = rows[0].position_world_m.y-0.06
		base.ordered_body_clearance_observations[0].engine_contact_ids = []
	var measured := {"ok":true,"observation_base":base,"direct_state_source_receipt":{
		"schema_version":"sporespore_qsdk_r24d57_godot_direct_state_source_v1","semantic_step":step,"ordered_body_states":rows,
		"gravity_world_m_s2":World._vector_json(Epoch._from_vec(epoch.state_after.latest.ordered_body_sources[0].total_gravity_world_m_s2)),"source_measurement":true}}
	base.state.gravity_world_m_s2 = measured.direct_state_source_receipt.gravity_world_m_s2
	var contacts := World.retain_contact_source_receipt_v1(sdk,{"source_receipt":{
		"schema_version":World.SOLVED_CONTACT_SOURCE_SCHEMA,"semantic_step":step,"native_space_step_sequence":600+step,
		"solved_contact_telemetry_contract":{"schema_version":World.SOLVED_CONTACT_TELEMETRY_CONTRACT_SCHEMA,"ok":true,"exact_contact_point_count":5},
		"ordered_contact_samples":[],"ordered_contact_identity_projections":[],"source_measurement":true}})
	if task.is_empty(): task = {"ok":true,"task_id":Bridge.Route.TASK_ID,"semantics_id":Bridge.Route.SEMANTICS_ID}
	base.task_id = task.task_id; base.semantics_id = task.semantics_id
	return Bound.compose_v1(sdk,context,epoch,energy,sources,application,measured,contacts,task)


static func run(sdk: Object, context: Dictionary) -> Dictionary:
	var failures: Array = []; var checks := 0
	var native_dt: float = PackedFloat32Array([World.OUTER_STEP_DURATION_S])[0]
	checks += 1
	if not Bound.step_duration_projection_valid_v1(World.OUTER_STEP_DURATION_S,native_dt): failures.append("native clock projection")
	for pair in [[native_dt,native_dt],[World.OUTER_STEP_DURATION_S,World.OUTER_STEP_DURATION_S],
		[World.OUTER_STEP_DURATION_S,native_dt+pow(2.0,-30.0)]]:
		checks += 1
		if Bound.step_duration_projection_valid_v1(pair[0],pair[1]): failures.append("crossed or adjacent clock")
	var fall_state := {}
	for step in range(1,7):
		var contact := step in [1,2,4,5,6]
		var sample := {"global_step":step,"callback_sequence":step,"torso_up_world":Vector3.UP,"torso_nonfoot_contact":contact,"source_measurement":true}
		var detected := Fall.advance_v1(fall_state,sample); checks += 1
		if detected.get("ok") != true or detected.state_after.triggered != (step == 6): failures.append("fall hysteresis")
		fall_state = detected.get("state_after",{})
	for key in ["global_step","callback_sequence","torso_up_world","torso_nonfoot_contact","source_measurement"]:
		var sample := {"global_step":1,"callback_sequence":1,"torso_up_world":Vector3.UP,"torso_nonfoot_contact":false,"source_measurement":true}
		sample[key] = null; checks += 1
		if Fall.advance_v1({},sample).get("ok") == true: failures.append("fall source "+key)
	var origin := synthetic_frame(sdk,300)
	var begun := Epoch.begin_v1(sdk,origin,"live_handoff_synthetic","sha256:"+"4".repeat(64))
	if begun.get("ok") != true: return _failed(checks,"epoch",begun)
	var energy_origin := Energy.begin_v1(sdk,context,begun.state)
	if energy_origin.get("ok") != true: return _failed(checks,"energy",energy_origin)
	var controller := Bridge.begin_v1(sdk,context,begun.state,energy_origin.state,"live_handoff_synthetic")
	checks += 1
	if controller.get("ok") != true: return _failed(checks,"controller origin",controller)
	var frame := synthetic_frame(sdk,301)
	var transition := Epoch.advance_v1(sdk,begun.state,frame)
	var sources := synthetic_sources(sdk,context,frame)
	var energy := Energy.advance_v1(sdk,energy_origin.state,transition,sources)
	if energy.get("ok") != true: return _failed(checks,"increment",energy)
	var application := passive_application(sdk,301,controller)
	if application.get("ok") != true: return _failed(checks,"passive application",application)
	var bound := synthetic_bound(sdk,context,transition,energy,sources,application)
	checks += 1
	if bound.get("ok") != true or not Bound.valid_v1(sdk,context,bound): return _failed(checks,"bound",bound)
	var before: Dictionary = controller.state.duplicate(true)
	var advanced := Bridge.advance_v1(sdk,context,controller.state,bound)
	checks += 1
	if advanced.get("ok") != true or controller.state != before: return _failed(checks,"compiled entry",advanced)
	for key in ["last_global_step","epoch_id","context_sha256","terminal"]:
		var changed: Dictionary = before.duplicate(true)
		if key == "last_global_step": changed[key] += 1
		elif key == "terminal": changed[key] = true
		else: changed[key] = "crossed"
		changed = Epoch._seal(sdk,changed); checks += 1
		if Bridge.advance_v1(sdk,context,changed,bound).get("ok") == true: failures.append("controller "+key)
	for kind in ["clock","body","orientation","contact_clock","application","task","energy"]:
		var changed := bound.duplicate(true)
		var c: Dictionary = changed.source_component_receipts
		match kind:
			"clock": c.state_source.observation_base.semantic_step += 1
			"body": c.state_source.direct_state_source_receipt.ordered_body_states[0].mass_kg += 1
			"orientation": c.state_source.observation_base.state.base_pose_world.orientation_xyzw.w = 0.5
			"contact_clock":
				c.contact_source.contact_source_receipt.native_space_step_sequence += 1
				c.contact_source.contact_source_sha256 = Bound._sha(sdk,c.contact_source.contact_source_receipt)
			"application": c.application.source_control_semantic_step += 1
			"task": c.task_source.task_id = "crossed"
			"energy": c.energy_transition.state_after.ledger.cumulative_applied_actuator_work_j += 1
		changed = Epoch._seal(sdk,changed); checks += 1
		if Bound.valid_v1(sdk,context,changed): failures.append("bound "+kind)
	var prone_frame := synthetic_frame(sdk,302)
	var prone_epoch := Epoch.advance_v1(sdk,transition.state_after,prone_frame)
	var prone_sources := synthetic_sources(sdk,context,prone_frame)
	var prone_energy := Energy.advance_v1(sdk,energy.state_after,prone_epoch,prone_sources)
	if prone_energy.get("ok") != true: return _failed(checks,"prone energy",prone_energy)
	var prone_application := passive_application(sdk,302,advanced.native_receipt,advanced.state_after.memory,Bridge.PRONE_CONTROLLER)
	if prone_application.get("ok") != true: return _failed(checks,"prone application",prone_application)
	var prone_bound := synthetic_bound(sdk,context,prone_epoch,prone_energy,prone_sources,prone_application)
	var prone_step := Bridge.advance_v1(sdk,context,advanced.state_after,prone_bound)
	checks += 1
	if prone_step.get("ok") != true: return _failed(checks,"prone step",prone_step)
	var branches := {}
	for kind in ["partial","upright"]:
		branches[kind] = specialized_branch(sdk,context,kind)
		checks += 1
		if branches[kind].get("ok") != true: return _failed(checks,kind,branches[kind])
	return {"ok":failures.is_empty(),"checks":checks,"failures":failures,"synthetic":true,
		"entry_route":advanced.state_after.route,"compiled_calls":advanced.calls.size()+prone_step.calls.size()+branches.partial.calls.size()+branches.upright.calls.size(),"fixture":{"origin":origin,"epoch_begin":begun,
			"energy_begin":energy_origin,"controller_begin":controller,"epoch":transition,"sources":sources,"energy":energy,"bound":bound,"controller":advanced,"branches":branches,
			"prone":{"frame":prone_frame,"epoch":prone_epoch,"sources":prone_sources,"energy":prone_energy,"bound":prone_bound,"controller":prone_step}},
		"world_build_count":0,"solver_step_count":0,"physical_acceptance_authority":false,"release_authority":false}


static func specialized_branch(sdk: Object, context: Dictionary, kind: String) -> Dictionary:
	var height := 0.125 if kind == "partial" else 0.25
	var origin := synthetic_frame(sdk,300,height)
	var epoch := Epoch.begin_v1(sdk,origin,"live_handoff_"+kind,"sha256:"+"5".repeat(64))
	var energy := Energy.begin_v1(sdk,context,epoch.state)
	var controller := Bridge.begin_v1(sdk,context,epoch.state,energy.state,"live_handoff_"+kind)
	if controller.get("ok") != true: return controller
	var observer_state: Dictionary = epoch.state
	var energy_state: Dictionary = energy.state
	var controller_state: Dictionary = controller.state
	var calls: Array = []
	var transition: Dictionary
	var energy_transition: Dictionary
	var advanced: Dictionary
	var bound: Dictionary
	for step in range(301,541):
		var frame := synthetic_frame(sdk,step,height)
		transition = Epoch.advance_v1(sdk,observer_state,frame)
		var sources := synthetic_sources(sdk,context,frame)
		energy_transition = Energy.advance_v1(sdk,energy_state,transition,sources)
		if energy_transition.get("ok") != true: return energy_transition
		var application := passive_application(sdk,step,controller_state)
		bound = synthetic_bound(sdk,context,transition,energy_transition,sources,application)
		advanced = Bridge.advance_v1(sdk,context,controller_state,bound)
		if advanced.get("ok") != true: return advanced
		calls.append_array(advanced.calls)
		observer_state = transition.state_after; energy_state = energy_transition.state_after; controller_state = advanced.state_after
		if controller_state.route != (kind if step == 540 else "entry"): return _failed(step,"entry route",advanced)
	var source: Variant = Bridge.Partial.Source if kind == "partial" else Bridge.Upright.Source
	var surface := Bridge.Route.zero_world_command_surface_v1(context)
	if surface.get("ok") != true: return surface
	var model := {"complete_energy_profile_selected":true,"solver_coupled_complete_energy_profile_selected":true,
		"discrete_staging_complete_energy_profile_selected":true,"route_aware_application_provenance_selected":true,
		"joint_by_actuator_id":surface.joint_by_actuator_id}
	var positions := {}
	for joint in bound.observation_v3.state.ordered_joint_observations: positions[joint.joint_id] = joint.position_rad
	var applied := Bridge.Route.apply_behavior_control_route_aware_discrete_staging_v2(sdk,advanced.control,model,positions,true,source.RECOVERY)
	Bridge.Route.free_zero_world_command_surface_v1(surface)
	if applied.get("ok") != true: return applied
	var tagged: Dictionary = source.bind_application_v1(sdk,advanced.native_receipt,applied)
	if tagged.get("ok") != true: return tagged
	var task: Dictionary = source.select_v1(sdk,{source.KEY:tagged.model_binding},tagged.application,541)
	if task.get("ok") != true: return task
	var frame := synthetic_frame(sdk,541,height)
	transition = Epoch.advance_v1(sdk,observer_state,frame)
	var raw := EnergyChecks.raw_fixture(541)
	raw.solver_telemetry = EpochChecks.fixture(541,1141).telemetry
	raw.solver_telemetry.joint_velocity_constraint_exchange_j = -9.0*0.5*(Vector3(0,-9.81,0)*(1.0/120.0)).length_squared()
	for motor in raw.ordered_motor_sources:
		for key in ["positive_motor_work_j","absorbed_motor_work_j","net_motor_work_j","signed_motor_impulse_nms"]: motor.telemetry[key] = 0.0
	var sources := Energy.project_sources_v1(sdk,context,frame,raw)
	energy_transition = Energy.advance_v1(sdk,energy_state,transition,sources)
	if energy_transition.get("ok") != true: return energy_transition
	bound = synthetic_bound(sdk,context,transition,energy_transition,sources,tagged.application,task)
	var stepped := Bridge.advance_v1(sdk,context,controller_state,bound)
	if stepped.get("ok") != true: return stepped
	calls.append_array(stepped.calls)
	return {"ok":true,"route":kind,"calls":calls,"entry":advanced,"application":tagged,"step":stepped,
		"world_build_count":0,"solver_step_count":0,"synthetic":true}


static func _failed(checks: int, label: String, detail: Dictionary) -> Dictionary:
	return {"ok":false,"checks":checks,"failures":[label],"detail":detail,"world_build_count":0,"solver_step_count":0}
