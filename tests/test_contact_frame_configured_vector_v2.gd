extends SceneTree

const Fixture := preload("res://tests/test_r10ac_contact_frame_capture.gd")
const Capture := preload("res://sdk/adapters/godot/gdscript/r10ac_contact_frame_capture_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or FileAccess.file_exists(args[0]):
		quit(1); return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixture.PROFILE))
	if GDExtensionManager.is_extension_loaded(Fixture.OLD):
		GDExtensionManager.unload_extension(Fixture.OLD)
	if GDExtensionManager.load_extension(profile.extension) != GDExtensionManager.LOAD_STATUS_OK:
		quit(1); return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var cases := []
	# Authored scalar centers deliberately bypass Vector3 until production replay.
	for center in [-0.08365750000000001, -0.1, -0.1000010001, -0.0998990001]:
		var packet := Fixture.fixture_v1(sdk)
		for body in packet.contact_sites_by_body:
			packet.contact_sites_by_body[body].local_center_m = {"x":0.0,"y":center,"z":0.0}
		var sample: Dictionary = packet.contact_source_receipt.ordered_contact_samples[0]
		sample.classified_as_foot = Vector3(sample.position_body_local_m.x,
			sample.position_body_local_m.y, sample.position_body_local_m.z).y <= Vector3(0,center,0).y + Capture.TOLERANCE_M
		packet.source_component_binding.contact_source_sha256 = Capture._sha(sdk,packet.contact_source_receipt)
		var replay := Capture.replay_v1(sdk,packet,7,Fixture.MODEL,Fixture.POPULATION)
		if replay.get("ok") != true:
			print(Transport.stringify(replay)); sdk=null; quit(1); return
		cases.append({"authored_center":center,"packet":packet,"replay":replay})
	var file := FileAccess.open(args[0],FileAccess.WRITE)
	file.store_string(Transport.line({"ok":true,"cases":cases,
		"world_build_count":0,"solver_step_count":0,
		"physical_acceptance_authority":false,"release_authority":false}))
	file.close()
	sdk=null
	quit(0)
