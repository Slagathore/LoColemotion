extends SceneTree

const Evidence := preload("recovery_evidence.gd")
const EvidencePanel := preload("recovery_evidence_panel.gd")
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if not condition:
		printerr("EXPLORER_RECOVERY_EVIDENCE_FAIL " + label)
		quit(1)
		return
	_checks += 1


func _run() -> void:
	var sdk_root := "res://sdk"
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--sdk-root":
		sdk_root = args[1]
	var adoption := FileAccess.get_file_as_bytes(sdk_root.path_join(Evidence.ADOPTION_PATH))
	var closure := FileAccess.get_file_as_bytes(sdk_root.path_join(Evidence.CLOSURE_PATH))
	var good := Evidence.inspect(sdk_root)
	_check(good["evidence_status"] == "proved" and good["cells"].size() == 6, "exact accepted records")
	_check(good["live_recovery_status"] == "unproven", "retained proof is not live proof")
	var matching := Evidence.inspect_bytes(adoption, closure, good["runtime_dll_sha256"])
	_check(matching["runtime_status"] == "matches_retained_dll", "runtime match visible")
	_check(matching["live_recovery_status"] == "unproven", "DLL alone insufficient")
	var wrong_runtime := Evidence.inspect_bytes(adoption, closure, "sha256:" + "0".repeat(64))
	_check(wrong_runtime["runtime_status"] == "different_dll", "wrong runtime visible")
	_check(wrong_runtime["live_recovery_status"] == "unproven", "wrong runtime cannot inherit")
	_check(Evidence.inspect_bytes(PackedByteArray(), closure)["evidence_status"] == "unproven", "missing adoption")
	_check(Evidence.inspect_bytes(adoption, PackedByteArray())["evidence_status"] == "unproven", "missing closure")
	var changed := adoption.duplicate()
	changed[changed.size() - 2] = 32
	_check(Evidence.inspect_bytes(changed, closure)["evidence_status"] == "ambiguous", "tampered adoption")
	var changed_closure := closure.duplicate()
	changed_closure[changed_closure.size() - 2] = 32
	_check(Evidence.inspect_bytes(adoption, changed_closure)["evidence_status"] == "ambiguous", "tampered closure")
	_check(Evidence.inspect_bytes(closure, adoption)["evidence_status"] == "ambiguous", "crossed records")
	_check(not good["physical_execution_authorized"] and not good["release_authority"] and good["new_world_count"] == 0, "read only")
	var description := EvidencePanel.describe(good)
	_check(description.contains("Current sandbox recovery: UNPROVEN") and description.contains("0.25"), "view claim boundary")
	var panel := EvidencePanel.new()
	panel.sdk_root = sdk_root
	root.add_child(panel)
	panel.refresh_evidence()
	_check(panel.get_child_count() == 3, "real panel construction")
	panel.sdk_root = sdk_root.path_join("missing-test-root")
	panel.refresh_evidence()
	_check(panel.get_child(0).text.begins_with("UNPROVEN"), "refresh removes proved heading")
	_check(not panel.get_child(1).text.contains("Phase 72"), "refresh clears previous results")
	panel.queue_free()
	if _checks == 16:
		print("EXPLORER_RECOVERY_EVIDENCE_PASS checks=16 worlds=0")
		quit(0)
	else:
		quit(1)
