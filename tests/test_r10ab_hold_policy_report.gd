extends SceneTree
const Policy := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_policy_v1.gd")
const Contacts := preload("res://sdk/adapters/godot/gdscript/development_recovery_native_walking_contacts_v1.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var report: Dictionary = input.report
	var checks := {}
	var result := Policy.validate_report_v1(report, Policy.R10AB.ID)
	checks.synthetic_session_selection = result.get("ok") == true
	checks.hold_never_counts_as_walking = result.get("validated_resume_sessions") == 0
	for key in ["schema_version", "selected_policy_id", "selected_policy_digest", "development_walking_policy_id", "controller_profile_sha256"]:
		var bad: Dictionary = report.duplicate(true)
		bad.retained_arm.walking_sessions[0].start_receipt[key] = "crossed"
		checks["reject_" + key] = Policy.validate_report_v1(bad, Policy.R10AB.ID).get("failure_code") == "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"
	var bad: Dictionary = report.duplicate(true)
	bad.retained_arm.walking_sessions[0].completion_receipt.adapter_summary.controller_policy_id = "crossed"
	checks.reject_crossed_completion = Policy.validate_report_v1(bad, Policy.R10AB.ID).get("failure_code") == "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"
	checks.post_hold_selector = Policy.selected_id_v1({"diagnostic_schedule":{"walking_policy_id":Policy.R10AB.ID}}, Policy.R10AB.POST_HOLD_SEGMENT) == Policy.R10AB.POST_HOLD_ALIAS
	for id in [Policy.R10AB.ID, Policy.R10AB.POST_HOLD_ALIAS]:
		checks["post_hold_owner_" + id] = Policy.owner_for_phase_v1("post_recovery_stationary_settling", id) == "stance"
	var contact_report: Dictionary = report.duplicate(true)
	contact_report.retained_arm.trace_rows = []
	contact_report.development_native_walking_contacts = Contacts.retention_v1([])
	checks.contact_reader_defers_exact_hold = Contacts.validate_report_v1(null,contact_report,Policy.R10AB.ID).get("ok") == true
	checks.contact_reader_other_route_refuses = Contacts.validate_report_v1(null,contact_report,Policy.R10S.ID).get("failure_code") == "DEVELOPMENT_NATIVE_WALKING_CONTACT_READER_SESSION_SELECTION"
	bad = contact_report.duplicate(true)
	bad.retained_arm.walking_sessions[0].start_receipt.development_walking_policy_id = Policy.R10AB.HOLD_ALIAS
	checks.contact_reader_crossed_alias_refuses = Contacts.validate_report_v1(null,bad,Policy.R10AB.ID).get("failure_code") == "DEVELOPMENT_NATIVE_WALKING_CONTACT_READER_POST_HOLD_SELECTION"
	bad = contact_report.duplicate(true)
	bad.retained_arm.walking_sessions[0].start_receipt.development_walking_contact_profile_id = Contacts._contract.profile_id
	checks.contact_reader_crossed_population_refuses = Contacts.validate_report_v1(null,bad,Policy.R10AB.ID).get("failure_code") == "DEVELOPMENT_NATIVE_WALKING_CONTACT_READER_POST_HOLD_SELECTION"
	var output := FileAccess.open(args[1],FileAccess.WRITE)
	output.store_string(JSON.stringify({"ok":not checks.values().has(false),"checks":checks,"world_build_count":0,"solver_step_count":0,"physical_acceptance_authority":false,"release_authority":false}) + "\n")
	output.close()
	quit(1 if checks.values().has(false) else 0)
