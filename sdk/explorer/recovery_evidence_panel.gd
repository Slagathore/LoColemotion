extends VBoxContainer
## SDK-local view; it renders evidence and never starts a physics process.

const Evidence := preload("recovery_evidence.gd")
var sdk_root := "res://sdk"
var _heading: Label
var _details: RichTextLabel


func _ready() -> void:
	name = "Recovery Evidence"
	add_theme_constant_override("separation", 10)
	_heading = Label.new()
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_heading)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = false
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_details)
	var refresh := Button.new()
	refresh.text = "Verify retained recovery records"
	refresh.pressed.connect(refresh_evidence)
	add_child(refresh)
	refresh_evidence()


func refresh_evidence() -> void:
	var result := Evidence.inspect(sdk_root)
	_heading.text = String(result["label"])
	_heading.add_theme_color_override(
		"font_color", Color("55c99a") if result["evidence_status"] == "proved" else Color("f59e0b")
	)
	_details.text = describe(result)


static func describe(result: Dictionary) -> String:
	var text := String(result["reason"]) + "\n\n"
	if result["evidence_status"] != "proved":
		return text + "Live recovery: UNPROVEN. No execution or release authority."
	text += "Accepted scope\nS169 · Godot/Jolt · phases 72, 73, 74\n"
	text += "0.25 N·s positive task-lateral kick · prone recovery\n"
	text += "Four walking cycles and a 120-command settled stop\n\n"
	text += "Retained results\n"
	for cell: Dictionary in result["cells"]:
		var role := "Control" if cell["role"] == "matched_no_kick_continuation" else "Kicked"
		text += "Phase %d · %s · PASS · %d steps · %.4f m forward\n" % [
			int(cell["phase"]), role, int(cell["solver_steps"]), float(cell["forward_advance_m"])
		]
	text += "\nCurrent sandbox recovery: UNPROVEN\n"
	text += "The workbench sandbox uses a separate controller route. Editing a seed, force or body does not inherit this acceptance.\n"
	text += "The matching DLL alone would not establish a complete matching setup.\n\n"
	text += "Limits\nExact finite conditions only. Broader force, morphology, phase coverage and cross-engine recovery remain unproved. SDK release remains pending.\n\n"
	text += "Provenance\nAuthority source: %s\nDLL: %s\nProduction key: %s\n" % [
		result["source_commit"], result["runtime_dll_sha256"], result["production_route_key"]
	]
	text += "This view verifies the two retained record digests; it does not rerun the physical audit."
	return text
