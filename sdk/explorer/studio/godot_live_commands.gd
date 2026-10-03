extends RefCounted
## Validate a live request before the physics thread chooses the next step.
const PROTOCOL:="sporespore_live_explorer_protocol_v1"

static func decode(value: Variant, session_id: String, seen: Dictionary, completed_step: int) -> Dictionary:
	if not (value is Dictionary):return {"ok":false}
	if value.get("schema_version")!=PROTOCOL or value.get("message_type")!="apply_impulse" or value.get("session_id")!=session_id:return {"ok":false}
	if value.get("target_body_id")!="torso" or value.get("apply_when")!="next_native_step" or value.has("apply_at_frame"):return {"ok":false}
	var id: Variant=value.get("command_id")
	if not (id is String) or id.is_empty() or id.length()>96 or seen.has(id) or seen.size()>=16 or completed_step<1:return {"ok":false}
	var v: Variant=value.get("impulse_n_s")
	if not (v is Dictionary) or v.size()!=3 or not v.has_all(["x","y","z"]):return {"ok":false}
	for number in v.values():
		if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(number):return {"ok":false}
	var vector:=Vector3(v.x,v.y,v.z)
	if vector.length()<0.01 or vector.length()>8.0:return {"ok":false}
	return {"ok":true,"vector":vector,"event":{"command_id":id,"apply_at_frame":completed_step+1,
		"impulse_n_s":v.duplicate(true),"native_polled_after_frame":completed_step,
		"application_policy":"next_native_step","native_application":"RigidBody3D.apply_central_impulse"}}

static func zero_world() -> Dictionary:
	var base: Dictionary={"schema_version":PROTOCOL,"message_type":"apply_impulse","session_id":"session",
		"target_body_id":"torso","apply_when":"next_native_step","command_id":"kick","impulse_n_s":{"x":0,"y":0,"z":0.25}}
	var failures: Array=[];var checks:=0
	var valid:=decode(base,"session",{},74);checks+=1
	if valid.get("ok")!=true or valid.event.apply_at_frame!=75:failures.append("next native step")
	for change in [{"session_id":"crossed"},{"target_body_id":"head"},{"apply_when":"later"},{"apply_at_frame":900},{"command_id":""},
		{"impulse_n_s":{"x":0,"y":0,"z":9}},{"impulse_n_s":{"x":0,"y":0,"z":NAN}},
		{"impulse_n_s":{"x":0,"y":0,"z":0}},{"impulse_n_s":{"x":true,"y":0,"z":1}}]:
		var bad:=base.duplicate(true);bad.merge(change,true);checks+=1
		if decode(bad,"session",{},74).get("ok")!=false:failures.append("crossed input")
	checks+=1
	if decode(base,"session",{"kick":true},74).get("ok")!=false:failures.append("duplicate command")
	var full: Dictionary={}
	for index in 16:full[str(index)]=true
	checks+=1
	if decode(base,"session",full,74).get("ok")!=false:failures.append("command bound")
	return {"ok":failures.is_empty(),"checks":checks,"failures":failures,"world_build_count":0,"solver_step_count":0}
