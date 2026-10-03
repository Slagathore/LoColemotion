extends RefCounted
const Live:=preload("res://sdk/explorer/studio/godot_live_walking.gd")

class Adapter extends RefCounted:
	var calls: Array=[]
	var rejected: String=""
	func step(sample, local, a, b, c, d, verify):
		calls.append("step")
		var commands: Array=[]
		for index in 8:commands.append({"actuator_id":str(index),"target_velocity_rad_s":0.1})
		return {"ok":rejected!="step" and sample.request.step==local and a=={} and b=={} and c==0.0 and d=={} and verify,"native_output":{"actuation":{"ordered_commands":commands}}}
	func apply_authority(result, joints, readback, caps):
		calls.append("apply")
		var rows: Array=[]
		for index in 8:rows.append({"actuator_id":str(index),"host_applied_target_velocity_rad_s":0.1,
			"motor_target_velocity_readback_rad_s":float(PackedFloat32Array([0.1])[0]),"declared_maximum_impulse_nms":1.0,"motor_maximum_impulse_readback_nms":1.0})
		return {"ok":rejected!="apply" and result.ok and joints=={} and readback and caps.size()==8,"ordered_applications":rows}

class Facade extends RefCounted:
	var _adapter:=Adapter.new()
	var _initial_gait_steps: Dictionary={}
	var _binding: Dictionary={"joint_state_by_legacy_id":{}}
	var _authorized_host_cap_by_actuator_id: Dictionary={"0":1.0,"1":1.0,"2":1.0,"3":1.0,"4":1.0,"5":1.0,"6":1.0,"7":1.0}
	func _sample_walking_input_v1(local, amplitude, phase):
		_adapter.calls.append("sample")
		return {"ok":_adapter.rejected!="sample","request":{"step":local,"amplitude":amplitude,"phase":phase}}

static func run() -> Dictionary:
	var failures: Array=[]
	var checks:=0
	for rejected in ["","sample","step","apply"]:
		var facade:=Facade.new();facade._adapter.rejected=rejected
		var result:=Live.control_step(facade,1,1.0,"contact_gated")
		var expected: Array=["sample"] if rejected=="sample" else ["sample","step"] if rejected=="step" else ["sample","step","apply"]
		checks+=1
		if result.get("ok")!=(rejected=="") or facade._adapter.calls!=expected:failures.append("call ownership "+rejected)
	for args in [[0,1.0,"clocked"],[1,NAN,"clocked"],[1,-0.1,"clocked"],[1,1.1,"clocked"],[1,1.0,"invalid"]]:
		var facade:=Facade.new()
		checks+=1
		if Live.control_step(facade,args[0],args[1],args[2]).get("ok")!=false or not facade._adapter.calls.is_empty():failures.append("invalid command")
	var empty: Dictionary={"contact_site_id":"front_left_foot","provenance":{"engine_contact_ids":[]}}
	checks+=1
	if Live.project_samples(empty,[],"front_left",[]).get("ok")!=true:failures.append("empty native contact")
	checks+=1
	if Live.project_samples(empty,[],"rear_left",[]).get("ok")!=false:failures.append("crossed limb")
	var missing: Array=[{"body_id":"front_left_distal","classified_as_foot":true,"engine_contact_id":"missing","position_world_m":{"x":0,"y":0,"z":0}}]
	checks+=1
	if Live.project_samples(empty,missing,"front_left",[]).get("ok")!=false:failures.append("missing callback point")
	var samples: Array=[{"engine_contact_id":"missing","local_position_world_m":Vector3.ZERO}]
	var present:=empty.duplicate(true)
	present.provenance.engine_contact_ids=Live.World.native_contact_identity_projection_v2(["missing"]).engine_contact_ids
	checks+=1
	var projected:=Live.project_samples(present,missing,"front_left",samples)
	if projected.get("ok")!=true or projected.samples!=samples:failures.append("exact native point")
	checks+=1
	if Live.project_samples(empty,missing,"front_left",samples).get("ok")!=false:failures.append("crossed contact identity")
	var snapshot: Dictionary={"callback_sequence":7,"source_measurement":true,"transform":Transform3D.IDENTITY}
	checks+=1
	if not Live.snapshot_valid(snapshot,7,7):failures.append("measured snapshot")
	for changed in [{"callback_sequence":6},{"source_measurement":false},{"transform":null}]:
		var crossed:=snapshot.duplicate(true);crossed.merge(changed,true);checks+=1
		if Live.snapshot_valid(crossed,7,7):failures.append("crossed snapshot")
	checks+=1
	if Live.snapshot_valid(snapshot,6,7):failures.append("crossed contact clock")
	var facade:=Facade.new()
	var passed:=Live.control_step(facade,1,1.0,"contact_gated")
	for field in ["motor_target_velocity_readback_rad_s","motor_maximum_impulse_readback_nms","host_applied_target_velocity_rad_s"]:
		var changed: Dictionary=passed.application.duplicate(true);changed.ordered_applications[0][field]=0.123456;checks+=1
		if Live.motor_readbacks_valid(passed.step.native_output.actuation.ordered_commands,changed,facade._authorized_host_cap_by_actuator_id):failures.append("crossed motor readback")
	return {"ok":failures.is_empty(),"checks":checks,"failures":failures,"world_build_count":0,"solver_step_count":0}
