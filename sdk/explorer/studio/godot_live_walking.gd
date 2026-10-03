extends RefCounted
## Live-only walking operations. The existing contact classifier, sampler,
## portable controller, command validator and motor application remain owners.
## No recovery energy observation or scientific ledger is manufactured here.
const World := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")

static func snapshot_valid(snapshot: Dictionary, contact_sequence: int, completed_step: int) -> bool:
	return completed_step>0 and snapshot.get("callback_sequence")==completed_step and contact_sequence==completed_step and snapshot.get("source_measurement")==true and snapshot.get("transform") is Transform3D

static func motor_readbacks_valid(commands: Array, applied: Dictionary, caps: Dictionary) -> bool:
	var rows: Array=applied.get("ordered_applications",[])
	if commands.size()!=8 or rows.size()!=8 or caps.size()!=8:return false
	var seen: Dictionary={}
	for index in range(8):
		var command: Dictionary=commands[index];var row: Dictionary=rows[index]
		var id: String=command.get("actuator_id","")
		var target: float=command.get("target_velocity_rad_s",NAN)
		var cap: float=caps.get(id,NAN)
		if id.is_empty() or seen.has(id) or row.get("actuator_id")!=id or not is_finite(target) or not is_finite(cap) or cap<=0.0:return false
		seen[id]=true
		# The existing L13 contract requires the exact binary32 host projection,
		# not the legacy adapter's binary64-tolerance diagnostic flag.
		if row.get("host_applied_target_velocity_rad_s")!=target or row.get("motor_target_velocity_readback_rad_s")!=float(PackedFloat32Array([target])[0]):return false
		if row.get("declared_maximum_impulse_nms")!=cap or row.get("motor_maximum_impulse_readback_nms")!=cap:return false
	return true

static func project_samples(contact: Dictionary, points: Array, limb_id: String, samples: Array) -> Dictionary:
	if contact.get("contact_site_id") != limb_id+"_foot":return {"ok":false}
	var matched: Array[Dictionary]=[]
	var ids: Array=[]
	for point in points:
		if point.get("body_id")!=limb_id+"_distal" or point.get("classified_as_foot")!=true:continue
		var position: Dictionary=point.get("position_world_m",{})
		if not position.has_all(["x","y","z"]):return {"ok":false}
		var found:=false
		for sample in samples:
			if sample.get("engine_contact_id")==point.get("engine_contact_id") and sample.get("local_position_world_m")==Vector3(position.x,position.y,position.z):
				matched.append(sample.duplicate(true));ids.append(sample.engine_contact_id);found=true;break
		if not found:return {"ok":false}
	var projection:=World.native_contact_identity_projection_v2(ids)
	if projection.get("ok")!=true or projection.get("engine_contact_ids")!=contact.get("provenance",{}).get("engine_contact_ids"):return {"ok":false}
	return {"ok":true,"observation":contact.duplicate(true),"samples":matched}

static func prepare_contacts(model: Dictionary, binding: Dictionary, completed_step: int, native_sequence: int) -> Dictionary:
	var snapshots: Dictionary={}
	for id in World.ORDERED_BODY_IDS:
		var body: RigidBody3D=model.body_nodes[id]
		var snapshot: Dictionary=body.get("latest_direct_state_snapshot")
		if not snapshot_valid(snapshot,int(body.get("semantic_contact_callback_count")),completed_step):return {"ok":false,"failure_code":"LIVE_WALK_CALLBACK_CLOCK"}
		snapshots[id]=snapshot
	var measured:=World._measure_contacts_v1(model,snapshots,completed_step,native_sequence)
	if measured.get("ok")!=true:return measured
	var staged: Array=[]
	var limbs: Array=binding.limbs
	if limbs.size()!=4 or measured.ordered_contact_observations.size()!=4:return {"ok":false,"failure_code":"LIVE_WALK_CONTACT_POPULATION"}
	for index in range(4):
		var limb: Dictionary=limbs[index]
		var projected:=project_samples(measured.ordered_contact_observations[index],measured.source_receipt.ordered_contact_samples,
			limb.limb_id,limb.foot.get("latest_semantic_contact_samples"))
		if projected.get("ok")!=true:return {"ok":false,"failure_code":"LIVE_WALK_CONTACT_PROJECTION"}
		staged.append(projected)
	# No partial update if any contact population or identity was refused.
	for index in range(4):
		limbs[index].native_qualified_contact=staged[index].observation
		limbs[index].native_qualified_contact_samples=staged[index].samples
	return {"ok":true,"contacts":measured.ordered_contact_observations}

static func control_step(facade: Object, local_step: int, amplitude: float, phase_mode: String) -> Dictionary:
	if local_step<1 or not is_finite(amplitude) or amplitude<0.0 or amplitude>1.0 or phase_mode not in ["clocked","contact_gated"]:
		return {"ok":false,"failure_code":"LIVE_WALK_COMMAND_INPUT"}
	var sample: Dictionary=facade._sample_walking_input_v1(local_step,amplitude,phase_mode)
	if sample.get("ok")!=true:return sample
	var step: Dictionary=facade._adapter.step(sample,local_step,{},facade._initial_gait_steps,0.0,{},true)
	if step.get("ok")!=true:return step
	var applied: Dictionary=facade._adapter.apply_authority(step,facade._binding.joint_state_by_legacy_id,true,facade._authorized_host_cap_by_actuator_id)
	if applied.get("ok")!=true:return applied
	if not motor_readbacks_valid(step.native_output.actuation.ordered_commands,applied,facade._authorized_host_cap_by_actuator_id):return {"ok":false,"failure_code":"LIVE_WALK_MOTOR_READBACK"}
	return {"ok":true,"sample":sample,"step":step,"application":applied}
