extends RefCounted
## Additive source capture at the pure route boundary; never calls the SDK.
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const STEPS := [1,30,60,120,180,239,240]
const MAX_PACKETS := 16
static var enabled := false
static var directory := ""
static var phases: Dictionary = {}
static var rows: Array = []
static var observed_calls: Array = []
static var failure := ""
static var cost_us := 0

static func reset(path: String = "") -> void:
	enabled = not path.is_empty()
	directory = path
	phases.clear();rows.clear();observed_calls.clear();failure="";cost_us=0
	if enabled and (DirAccess.dir_exists_absolute(path) or DirAccess.make_dir_recursive_absolute(path)!=OK):
		failure="capture directory is not fresh";enabled=false

static func bytes(value: Variant) -> Dictionary:
	var text := Transport.stringify(value)
	return {"utf8_text":text,"utf8_byte_length":text.to_utf8_buffer().size(),"raw_sha256":"sha256:"+text.sha256_text()}

static func begin(context: Dictionary, bound: Dictionary, memory: Dictionary,
		arm_kind: String, phase: String, application: Dictionary) -> Dictionary:
	if not enabled or not failure.is_empty():return {}
	var start := Time.get_ticks_usec()
	var step: int = int(bound.get("observation_v3",{}).get("semantic_step",-1))
	if step<1 or step>240:return {}
	observed_calls.append({"global_step":step,"phase":phase})
	var first := not phases.has(phase)
	phases[phase]=true
	if not first and step not in STEPS:return {}
	if rows.size()>=MAX_PACKETS:
		failure="capture packet limit exceeded";return {}
	for row in rows:
		if row.global_step==step:
			failure="repeated selected startup step";return {}
	var packet := {"schema_version":"locolemotion_studio_startup_replay_packet_v1",
		"ledger_scope":{"subsystem":"explorer","engine_scope":"godot_jolt","authority_mode":"development_exact_startup_input_capture","question_class":"development"},
		"global_step":step,"phase":phase,"arm_kind":arm_kind,"context":bytes(context),
		"sources":{"bound_observation":bytes(bound),"source_memory":bytes(memory),"source_application":bytes(application)},
		"selection":{"fixed_step":step in STEPS,"first_phase_call":first},
		"physical_acceptance_authority":false,"release_authority":false}
	cost_us+=Time.get_ticks_usec()-start
	return packet

static func finish(packet: Dictionary, result: Dictionary) -> void:
	if packet.is_empty():return
	var start := Time.get_ticks_usec()
	packet["expected_route"]=bytes(result)
	packet["route_ok"]=result.get("ok")==true
	var collection: Dictionary=result.get("collection_transport_retention",{})
	packet["request"]=collection.get("request",{})
	packet["response"]=collection.get("response",{})
	packet["expected_step"]=result.get("step_receipt",{})
	var path := directory.path_join("step-%03d.json" % packet.global_step)
	if FileAccess.file_exists(path):
		failure="packet file already exists";return
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		failure="packet file open failed";return
	file.store_string(Transport.stringify(packet)+"\n")
	file.flush()
	var error := file.get_error();file.close()
	if error!=OK:
		failure="packet file write failed";return
	rows.append({"global_step":packet.global_step,"phase":packet.phase,"path":path,
		"sha256":FileAccess.get_sha256(path),"selection":packet.selection,"route_ok":packet.route_ok})
	if not packet.route_ok:failure="captured route refused"
	cost_us+=Time.get_ticks_usec()-start

static func summary() -> Dictionary:
	var complete := failure.is_empty() and not rows.is_empty()
	var steps: Array=[]
	for row in rows:steps.append(row.global_step)
	for step in STEPS:
		if step not in steps:complete=false
	return {"ok":complete,"failure":failure,"packets":rows.duplicate(true),"phases":phases.keys(),
		"fixed_steps":STEPS,"maximum_packets":MAX_PACKETS,"selected_packet_capture_wall_us":cost_us,
		"observed_calls":observed_calls.duplicate(true),
		"additional_controller_calls":0,"additional_physics_reads":0,"additional_solver_steps":0,
		"performance_comparison_authority":false,"physical_acceptance_authority":false,"release_authority":false}

static func zero_world(path: String) -> Dictionary:
	reset(path)
	var context := {"number":1,"float":1.0,"signed_zero":-0.0}
	var memory := {"phase":"initial"}
	var application := {"semantic_step":1}
	var bound := {"observation_v3":{"semantic_step":1}}
	var identity := var_to_bytes([context,bound,memory,application])
	var checks := 0
	var token := begin(context,bound,memory,"candidate_command","initial",application)
	if token.is_empty():return {"ok":false,"failure":"positive capture selection"}
	var result := {"ok":true,"step_receipt":{"phase":"next"},"collection_transport_retention":{"request":bytes({"request":1}),"response":bytes({"response":1})}}
	finish(token,result);checks+=1
	if rows.size()!=1 or not failure.is_empty():return {"ok":false,"failure":"positive retention"}
	var saved := FileAccess.get_file_as_string(rows[0].path)
	if saved!=Transport.stringify(token)+"\n":return {"ok":false,"failure":"retained bytes"}
	checks+=1
	if var_to_bytes([context,bound,memory,application])!=identity:return {"ok":false,"failure":"source mutation"}
	checks+=1
	bound.observation_v3.semantic_step=2
	if not begin(context,bound,memory,"candidate_command","initial",application).is_empty():return {"ok":false,"failure":"unselected call captured"}
	checks+=1
	if begin(context,bound,memory,"candidate_command","next",application).is_empty():return {"ok":false,"failure":"first phase call missing"}
	checks+=1
	bound.observation_v3.semantic_step=1
	begin(context,bound,memory,"candidate_command","initial",application)
	if failure!="repeated selected startup step":return {"ok":false,"failure":"duplicate accepted"}
	checks+=1
	reset(path)
	if failure!="capture directory is not fresh":return {"ok":false,"failure":"existing directory accepted"}
	checks+=1
	enabled=true;failure="";rows.resize(MAX_PACKETS)
	bound.observation_v3.semantic_step=30
	begin(context,bound,memory,"candidate_command","initial",application)
	if failure!="capture packet limit exceeded":return {"ok":false,"failure":"packet limit accepted"}
	checks+=1
	reset()
	if not begin(context,bound,memory,"candidate_command","initial",application).is_empty():return {"ok":false,"failure":"disabled capture active"}
	checks+=1
	return {"ok":true,"checks":checks,"world_build_count":0,"solver_steps":0}
