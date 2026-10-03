class_name LocomotionExperimentWorkbench
extends Control
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## Repository-native operator interface for SporeSpore locomotion research.
##
## The workbench intentionally separates three surfaces:
## 1. editable exploration values, which are never passed to frozen runners;
## 2. repository audits and zero-world preflights, which may execute safely;
## 3. physical one-shot supervisors, which retain their own clean-source,
##    evidence-root, attempt-receipt, and no-rerun interlocks.

const PreviewScript := preload("res://scripts/tools/locomotion_experiment_preview.gd")
const RecoveryEvidencePanel := preload("res://sdk/explorer/recovery_evidence_panel.gd")
const CATALOG_PATH := "res://sdk/workbench/experiment_catalog.json"
const EXPECTED_CATALOG_SCHEMA := "sporespore_locomotion_experiment_workbench_catalog_v1"
const LIVE_PHYSICS_CONFIG_SCHEMA := "sporespore_workbench_live_physics_configuration_v1"
const LIVE_PHYSICS_SCRIPT := "res://scripts/tools/locomotion_live_physics_demo.gd"
const NATIVE_STREAM_VIEWER_SCRIPT := "res://scripts/tools/locomotion_native_stream_viewer.gd"
const MAX_OUTPUT_CHARACTERS := 180000

const COLOR_BACKGROUND := Color("0b1020")
const COLOR_PANEL := Color("111827")
const COLOR_PANEL_ALT := Color("162033")
const COLOR_BORDER := Color("2a3b55")
const COLOR_TEXT := Color("dbeafe")
const COLOR_MUTED := Color("8da2bd")
const COLOR_ACCENT := Color("38bdf8")
const COLOR_SUCCESS := Color("55c99a")
const COLOR_WARNING := Color("f59e0b")
const COLOR_DANGER := Color("fb7185")

var _catalog: Dictionary = {}
var _repo_root := ""
var _pwsh_path := ""
var _git_head := "unknown"
var _source_clean := false
var _source_matches_local_origin_main := false

var _engine_select: OptionButton
var _run_select: OptionButton
var _preset_select: OptionButton
var _source_status: Label
var _draft_status: Label
var _parameter_scroll: ScrollContainer
var _parameter_list: VBoxContainer
var _preview: Control
var _preview_badge: Label
var _live_physics_button: Button
var _live_physics_status: Label
var _all_engine_physics_button: Button
var _all_engine_physics_status: Label
var _selection_explanation: RichTextLabel
var _diagnostics: RichTextLabel
var _proof_tree: Tree
var _proof_details: RichTextLabel
var _run_output: RichTextLabel
var _run_button: Button
var _cancel_button: Button
var _copy_draft_button: Button
var _confirmation_dialog: ConfirmationDialog
var _confirmation_phrase: LineEdit
var _confirmation_output_root: LineEdit
var _confirmation_help: Label

var _parameter_controls: Dictionary = {}
var _current_values: Dictionary = {}
var _baseline_values: Dictionary = {}
var _current_preset: Dictionary = {}
var _selected_engine: Dictionary = {}
var _selected_run: Dictionary = {}
var _selected_proof: Dictionary = {}
var _focused_parameter_id := "random_seed"
var _suppress_parameter_events := false

var _process_info: Dictionary = {}
var _process_output := ""
var _process_started_msec := 0
var _safe_process_self_test := false
var _live_physics_process_self_test := false
var _live_physics_pid := 0
var _live_physics_config_path := ""
var _native_physics_pids: Dictionary = {}
var _native_start_gate_path := ""
var _all_engine_launch_pending := false


func _ready() -> void:
	_repo_root = ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	_pwsh_path = _find_executable("pwsh.exe")
	_load_catalog()
	_apply_theme()
	_build_interface()
	_refresh_source_identity()
	_populate_engines()
	_populate_presets()
	_build_parameter_controls()
	if _preset_select.item_count > 0:
		_preset_select.select(0)
		_on_preset_selected(0)
	_validate_or_report_catalog()
	if _has_command_line_argument("--workbench-safe-process-self-test"):
		_safe_process_self_test = true
		call_deferred("_start_safe_process_self_test")
	elif _has_command_line_argument("--workbench-live-physics-process-self-test"):
		_live_physics_process_self_test = true
		call_deferred("_start_live_physics_process_self_test")
	elif _has_command_line_argument("--workbench-self-test"):
		call_deferred("_finish_self_test")


func _process(_delta: float) -> void:
	_poll_live_physics_process()
	_poll_native_physics_processes()
	if _process_info.is_empty():
		return
	_drain_process_stream("stdio", "")
	_drain_process_stream("stderr", "[stderr] ")
	var pid := int(_process_info.get("pid", 0))
	if pid > 0 and not OS.is_process_running(pid):
		_drain_process_stream("stdio", "")
		_drain_process_stream("stderr", "[stderr] ")
		var exit_code := OS.get_process_exit_code(pid)
		var elapsed := float(Time.get_ticks_msec() - _process_started_msec) / 1000.0
		_append_output(
			"\n[workbench] process finished: exit=%d elapsed=%.2fs\n" % [exit_code, elapsed]
		)
		_process_info.clear()
		_run_button.disabled = false
		_cancel_button.disabled = true
		_update_run_controls()
		if _safe_process_self_test:
			call_deferred("_finish_safe_process_self_test", exit_code)


func _exit_tree() -> void:
	if not _process_info.is_empty():
		var pid := int(_process_info.get("pid", 0))
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_stop_all_live_physics_processes()
	_remove_live_physics_configuration()


func _load_catalog() -> void:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("Experiment workbench catalog is missing: %s" % CATALOG_PATH)
		_catalog = {}
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Experiment workbench catalog is not a JSON object")
		_catalog = {}
		return
	_catalog = parsed as Dictionary


func _apply_theme() -> void:
	var workbench_theme := Theme.new()
	workbench_theme.default_font_size = 15
	workbench_theme.set_color("font_color", "Label", COLOR_TEXT)
	workbench_theme.set_color("font_color", "Button", COLOR_TEXT)
	workbench_theme.set_color("font_color", "CheckBox", COLOR_TEXT)
	workbench_theme.set_color("font_color", "CheckButton", COLOR_TEXT)
	workbench_theme.set_color("font_color", "OptionButton", COLOR_TEXT)
	workbench_theme.set_color("font_color", "LineEdit", COLOR_TEXT)
	workbench_theme.set_color("font_color", "SpinBox", COLOR_TEXT)
	workbench_theme.set_color("default_color", "RichTextLabel", COLOR_TEXT)
	workbench_theme.set_color("font_selected_color", "LineEdit", Color.WHITE)
	workbench_theme.set_color("selection_color", "LineEdit", Color("285b78"))
	workbench_theme.set_color("font_hover_color", "Button", Color.WHITE)
	workbench_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	workbench_theme.set_color("font_disabled_color", "Button", COLOR_MUTED)
	workbench_theme.set_color("font_color", "Tree", COLOR_TEXT)
	workbench_theme.set_color("font_selected_color", "Tree", Color.WHITE)
	workbench_theme.set_color("guide_color", "Tree", COLOR_BORDER)
	workbench_theme.set_color("drop_position_color", "Tree", COLOR_ACCENT)
	workbench_theme.set_color("font_color", "TabBar", COLOR_TEXT)
	workbench_theme.set_color("font_selected_color", "TabBar", COLOR_ACCENT)
	workbench_theme.set_color("font_unselected_color", "TabBar", COLOR_MUTED)
	workbench_theme.set_stylebox("normal", "Button", _style_box(COLOR_PANEL_ALT, COLOR_BORDER, 7))
	workbench_theme.set_stylebox("hover", "Button", _style_box(Color("20314b"), COLOR_ACCENT, 7))
	workbench_theme.set_stylebox("pressed", "Button", _style_box(Color("172a41"), COLOR_ACCENT, 7))
	workbench_theme.set_stylebox(
		"disabled", "Button", _style_box(Color("111827"), Color("233149"), 7)
	)
	workbench_theme.set_stylebox("normal", "LineEdit", _style_box(Color("0f172a"), COLOR_BORDER, 6))
	workbench_theme.set_stylebox("focus", "LineEdit", _style_box(Color("0f172a"), COLOR_ACCENT, 6))
	workbench_theme.set_stylebox("normal", "SpinBox", _style_box(Color("0f172a"), COLOR_BORDER, 6))
	workbench_theme.set_stylebox(
		"normal", "OptionButton", _style_box(Color("0f172a"), COLOR_BORDER, 6)
	)
	workbench_theme.set_stylebox(
		"hover", "OptionButton", _style_box(Color("17243a"), COLOR_ACCENT, 6)
	)
	workbench_theme.set_stylebox(
		"pressed", "OptionButton", _style_box(Color("17243a"), COLOR_ACCENT, 6)
	)
	workbench_theme.set_stylebox(
		"panel", "PanelContainer", _style_box(COLOR_PANEL, COLOR_BORDER, 9)
	)
	workbench_theme.set_stylebox("panel", "TabContainer", _style_box(COLOR_PANEL, COLOR_BORDER, 9))
	theme = workbench_theme


func _style_box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)
	root_box.add_child(_build_header())

	var main_split := HSplitContainer.new()
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.split_offset = 370
	root_box.add_child(main_split)
	main_split.add_child(_build_left_panel())

	var center_right_split := HSplitContainer.new()
	center_right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_right_split.split_offset = 640
	main_split.add_child(center_right_split)
	center_right_split.add_child(_build_preview_panel())
	center_right_split.add_child(_build_diagnostics_panel())

	_build_confirmation_dialog()


func _build_header() -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_box)
	var title := Label.new()
	title.text = String(_catalog.get("title", "Locomotion Experiment Workbench"))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = String(_catalog.get("subtitle", ""))
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	title_box.add_child(subtitle)

	_source_status = Label.new()
	_source_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_source_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_source_status.custom_minimum_size = Vector2(280.0, 48.0)
	row.add_child(_source_status)
	var refresh := Button.new()
	refresh.text = "Refresh source"
	refresh.tooltip_text = "Re-read Git HEAD and tracked/ignored worktree status."
	refresh.pressed.connect(_refresh_source_identity)
	row.add_child(refresh)
	var guide := Button.new()
	guide.text = "Open full guide"
	guide.tooltip_text = "Open the newcomer explanation of the SDK, research process, proof, and roadmap."
	guide.pressed.connect(_open_full_guide)
	row.add_child(guide)
	return panel


func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(350.0, 0.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	box.add_child(_section_label("Experiment context"))
	_engine_select = _labeled_option(box, "Engine")
	_engine_select.item_selected.connect(_on_engine_selected)
	_run_select = _labeled_option(box, "Run / audit")
	_run_select.item_selected.connect(_on_run_selected)
	_preset_select = _labeled_option(box, "Parameter preset")
	_preset_select.item_selected.connect(_on_preset_selected)

	_draft_status = Label.new()
	_draft_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_draft_status)

	var seed_buttons := HBoxContainer.new()
	seed_buttons.add_theme_constant_override("separation", 6)
	var random_seed := Button.new()
	random_seed.text = "New run seed"
	random_seed.pressed.connect(_generate_run_seed)
	seed_buttons.add_child(random_seed)
	var terrain_seed := Button.new()
	terrain_seed.text = "New terrain seed"
	terrain_seed.pressed.connect(_generate_terrain_seed)
	seed_buttons.add_child(terrain_seed)
	var both := Button.new()
	both.text = "Both"
	both.pressed.connect(_generate_both_seeds)
	seed_buttons.add_child(both)
	box.add_child(seed_buttons)

	var action_buttons := HBoxContainer.new()
	action_buttons.add_theme_constant_override("separation", 6)
	var reset := Button.new()
	reset.text = "Reset preset"
	reset.pressed.connect(_reset_current_preset)
	action_buttons.add_child(reset)
	_copy_draft_button = Button.new()
	_copy_draft_button.text = "Copy draft JSON"
	_copy_draft_button.pressed.connect(_copy_draft_json)
	action_buttons.add_child(_copy_draft_button)
	box.add_child(action_buttons)

	box.add_child(HSeparator.new())
	_parameter_scroll = ScrollContainer.new()
	_parameter_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_parameter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_parameter_scroll)
	_parameter_list = VBoxContainer.new()
	_parameter_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_parameter_list.add_theme_constant_override("separation", 5)
	_parameter_scroll.add_child(_parameter_list)
	return panel


func _build_preview_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading := HBoxContainer.new()
	var label := _section_label("3D experiment view")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	_preview_badge = Label.new()
	_preview_badge.text = "SETUP INSPECTOR — RENDER ONLY"
	_preview_badge.add_theme_color_override("font_color", COLOR_WARNING)
	heading.add_child(_preview_badge)
	box.add_child(heading)
	_preview = PreviewScript.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_preview)
	var live_actions := HBoxContainer.new()
	live_actions.add_theme_constant_override("separation", 8)
	_live_physics_button = Button.new()
	_live_physics_button.text = "Launch real Jolt physics"
	_live_physics_button.pressed.connect(_on_live_physics_pressed)
	live_actions.add_child(_live_physics_button)
	_live_physics_status = Label.new()
	_live_physics_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_live_physics_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_live_physics_status.add_theme_color_override("font_color", COLOR_MUTED)
	live_actions.add_child(_live_physics_status)
	box.add_child(live_actions)
	var all_engine_actions := HBoxContainer.new()
	all_engine_actions.add_theme_constant_override("separation", 8)
	_all_engine_physics_button = Button.new()
	_all_engine_physics_button.text = "Launch all 3 real engines"
	_all_engine_physics_button.pressed.connect(_on_all_engine_physics_pressed)
	all_engine_actions.add_child(_all_engine_physics_button)
	_all_engine_physics_status = Label.new()
	_all_engine_physics_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_all_engine_physics_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_all_engine_physics_status.add_theme_color_override("font_color", COLOR_MUTED)
	all_engine_actions.add_child(_all_engine_physics_status)
	box.add_child(all_engine_actions)
	_selection_explanation = RichTextLabel.new()
	_selection_explanation.bbcode_enabled = true
	_selection_explanation.fit_content = false
	_selection_explanation.custom_minimum_size = Vector2(0.0, 190.0)
	_selection_explanation.scroll_active = true
	box.add_child(_selection_explanation)
	return panel


func _on_live_physics_pressed() -> void:
	if _live_physics_pid > 0 and OS.is_process_running(_live_physics_pid):
		OS.kill(_live_physics_pid)
		_live_physics_status.text = (
			"Stop requested for live physics process %d." % _live_physics_pid
		)
		return
	_launch_live_physics(false)


func _on_all_engine_physics_pressed() -> void:
	if _any_live_physics_process_running():
		_stop_all_live_physics_processes()
		_all_engine_physics_status.text = "Stop requested for all live physics processes."
		_update_live_physics_controls()
		return
	var errors := _all_engine_physics_support_errors()
	if not errors.is_empty():
		_all_engine_physics_status.text = String(errors[0])
		return
	var runtime_root := _repo_root.path_join(".tmp").path_join("workbench")
	if DirAccess.make_dir_recursive_absolute(runtime_root) != OK:
		_all_engine_physics_status.text = "Could not create the workbench start-gate directory."
		return
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "")
	_native_start_gate_path = runtime_root.path_join(
		"native_start_%s_%d.json" % [stamp, OS.get_process_id()]
	)
	for engine_id in ["rapier_parry", "mujoco"]:
		var pid := _launch_native_stream_viewer(engine_id)
		if pid <= 0:
			_stop_all_live_physics_processes()
			_all_engine_physics_status.text = (
				"%s did not start; all partially opened live processes were stopped."
				% _native_engine_label(engine_id)
			)
			_update_live_physics_controls()
			return
		_native_physics_pids[engine_id] = pid
	_all_engine_launch_pending = true
	_all_engine_physics_status.text = (
		"Rapier and MuJoCo are running their zero-world gates. Jolt will open when both native "
		+ "workers reach the shared start barrier; no physical engine is released early."
	)
	_update_live_physics_controls()


func _launch_live_physics(validate_only: bool) -> void:
	var errors := _live_physics_support_errors(not validate_only)
	if not errors.is_empty():
		_live_physics_status.text = String(errors[0])
		return
	var runtime_root := _repo_root.path_join(".tmp").path_join("workbench")
	var directory_error := DirAccess.make_dir_recursive_absolute(runtime_root)
	if directory_error != OK:
		_live_physics_status.text = "Could not create repository-local workbench runtime directory."
		return
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "")
	_live_physics_config_path = runtime_root.path_join(
		"live_physics_%s_%d.json" % [stamp, OS.get_process_id()]
	)
	var envelope := {
		"schema_version": LIVE_PHYSICS_CONFIG_SCHEMA,
		"role":
		(
			"zero_world_process_self_test"
			if validate_only
			else "repeatable_development_visualization_not_evidence"
		),
		"source_head": _git_head,
		"preset_id": String(_current_preset.get("id", "")),
		"engine_id": String(_selected_engine.get("id", "")),
		"values": _current_values.duplicate(true),
	}
	var file := FileAccess.open(_live_physics_config_path, FileAccess.WRITE)
	if file == null:
		_live_physics_status.text = "Could not write the repository-local live-physics configuration."
		_live_physics_config_path = ""
		return
	file.store_string(JSON.stringify(envelope, "  ", true))
	file.close()

	var arguments := PackedStringArray()
	if validate_only:
		arguments.append("--headless")
	(
		arguments
		. append_array(
			PackedStringArray(
				[
					"--path",
					_repo_root,
					"--resolution",
					"1280x720",
					"--script",
					LIVE_PHYSICS_SCRIPT,
					"--",
				]
			)
		)
	)
	if validate_only:
		arguments.append("--validate-only")
	arguments.append(_live_physics_config_path)
	_live_physics_pid = OS.create_process(OS.get_executable_path(), arguments, false)
	if _live_physics_pid <= 0:
		_live_physics_status.text = "Godot could not start the live physics process."
		_live_physics_pid = 0
		_remove_live_physics_configuration()
		return
	_live_physics_status.text = (
		("Zero-world live-process self-test %d opened." % _live_physics_pid)
		if validate_only
		else (
			"Live process %d opened. It runs real gravity/contact/motor physics with no evidence authority."
			% _live_physics_pid
		)
	)
	_update_live_physics_controls()


func _live_physics_support_errors(require_clean_pushed_source: bool = true) -> Array[String]:
	var errors: Array[String] = []
	if require_clean_pushed_source:
		if not _source_clean:
			errors.append("Live physical worlds require a clean source tree.")
		elif not _source_matches_local_origin_main:
			errors.append("Live physical worlds require HEAD to match the local origin/main ref.")
	if String(_selected_engine.get("id", "")) != "godot_jolt":
		errors.append("Live 3D physics is currently implemented for Godot/Jolt only.")
	if int(_current_values.get("limb_count", 4)) != 4:
		errors.append("The live physical fixture currently supports exactly four limbs.")
	if String(_current_values.get("locomotion_mode", "")) != "balanced_wave_walk":
		errors.append("The live physical controller currently supports balanced-wave walking only.")
	var terrain_kind := String(_current_values.get("terrain_kind", "flat"))
	if not ["flat", "rough"].has(terrain_kind):
		errors.append("The live physical sandbox currently supports flat or seeded rough terrain.")
	if absf(float(_current_values.get("slope_degrees", 0.0))) > 0.000001:
		errors.append(
			"Inclined live terrain is not implemented; the setup inspector may still render it."
		)
	if float(_current_values.get("obstacle_height_m", 0.0)) > 0.000001:
		(
			errors
			. append(
				"Discrete live obstacles are not implemented; the setup inspector may still render them."
			)
		)
	if float(_current_values.get("terrain_roughness", 0.0)) > 0.025:
		errors.append("The physical walker's declared rough-height bound is 0.025 m.")
	if (
		bool(_current_values.get("external_push_enabled", false))
		and (
			float(_current_values.get("push_impulse_ns", 0.0)) <= 0.0
			or float(_current_values.get("push_impulse_ns", 0.0)) > 0.40
		)
	):
		errors.append("The physical walker's declared lateral-push bound is (0, 0.40] N·s.")
	if bool(_current_values.get("sensor_noise_enabled", false)):
		errors.append("Live sensor-noise injection is not yet wired to this development viewer.")
	if bool(_current_values.get("sensor_latency_enabled", false)):
		errors.append("Live sensor latency is not yet wired to this development viewer.")
	if int(_current_values.get("physics_hz", 120)) != 120:
		errors.append("The live walker is pinned to its 120 Hz controller and solver contract.")
	if int(_current_values.get("random_seed", 0)) <= 0:
		errors.append("The live physical perturbation seed must be positive.")
	if int(_current_values.get("terrain_seed", 0)) <= 0:
		errors.append("The live terrain seed must be positive.")
	return errors


func _all_engine_physics_support_errors() -> Array[String]:
	var errors := _live_physics_support_errors(true)
	var rapier_release := ProjectSettings.globalize_path(
		"res://sdk/target/release/locomotion_live_explorer.exe"
	)
	var rapier_debug := ProjectSettings.globalize_path(
		"res://sdk/target/debug/locomotion_live_explorer.exe"
	)
	if not FileAccess.file_exists(rapier_release) and not FileAccess.file_exists(rapier_debug):
		errors.append("The Rapier native Explorer worker is not built; run its zero-world preflight.")
	var mujoco_python := ProjectSettings.globalize_path(
		"res://sdk/adapters/mujoco/.venv/Scripts/python.exe"
	)
	if not FileAccess.file_exists(mujoco_python):
		errors.append("The pinned MuJoCo virtual-environment Python is missing.")
	return errors


func _launch_native_stream_viewer(engine_id: String) -> int:
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "")
	var session_id := "workbench_%s_%s_%d" % [engine_id, stamp, OS.get_process_id()]
	var arguments := PackedStringArray(
		[
			"--path",
			_repo_root,
			"--resolution",
			"900x620",
			"--script",
			NATIVE_STREAM_VIEWER_SCRIPT,
			"--",
			"--engine",
			engine_id,
			"--source-commit",
			_git_head,
			"--session",
			session_id,
		]
	)
	if not _native_start_gate_path.is_empty():
		arguments.append("--start-gate")
		arguments.append(_native_start_gate_path)
	return OS.create_process(OS.get_executable_path(), arguments, false)


func _native_engine_label(engine_id: String) -> String:
	return "Rapier / Parry" if engine_id == "rapier_parry" else "MuJoCo"


func _update_live_physics_controls() -> void:
	if _live_physics_button == null or _live_physics_status == null:
		return
	if _live_physics_pid > 0 and OS.is_process_running(_live_physics_pid):
		_live_physics_button.disabled = false
		_live_physics_button.text = "Stop live physics"
		_preview_badge.text = "LIVE PHYSICS OPEN IN 3D WINDOW"
		_preview_badge.add_theme_color_override("font_color", COLOR_SUCCESS)
		_update_all_engine_physics_controls()
		return
	var errors := _live_physics_support_errors(true)
	_live_physics_button.text = "Launch real Jolt physics"
	_live_physics_button.disabled = not errors.is_empty()
	_preview_badge.text = "SETUP INSPECTOR — RENDER ONLY"
	_preview_badge.add_theme_color_override("font_color", COLOR_WARNING)
	if errors.is_empty():
		_live_physics_status.text = (
			"Repeatable 20/7 Jolt sandbox: real gravity, contacts, rigid bodies, and hinge motors. "
			+ "It uses the physical baseline controller, not the closed BW22L A/B campaign."
		)
		_live_physics_status.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		_live_physics_status.text = String(errors[0])
		_live_physics_status.add_theme_color_override("font_color", COLOR_WARNING)
	_update_all_engine_physics_controls()


func _update_all_engine_physics_controls() -> void:
	if _all_engine_physics_button == null or _all_engine_physics_status == null:
		return
	if _any_live_physics_process_running():
		_all_engine_physics_button.text = "Stop all live engines"
		_all_engine_physics_button.disabled = false
		_all_engine_physics_status.add_theme_color_override("font_color", COLOR_SUCCESS)
		return
	var errors := _all_engine_physics_support_errors()
	_all_engine_physics_button.text = "Launch all 3 real engines"
	_all_engine_physics_button.disabled = not errors.is_empty()
	if errors.is_empty():
		_all_engine_physics_status.text = (
			"Opens Jolt, Rapier, and MuJoCo native physics windows. Each has a real impulse control; "
			+ "each window reports its measured wall-clock ratio. Arbitrary morphology, equivalence, "
			+ "real-time performance, and fall recovery are not assumed."
		)
		_all_engine_physics_status.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		_all_engine_physics_status.text = String(errors[0])
		_all_engine_physics_status.add_theme_color_override("font_color", COLOR_WARNING)


func _poll_live_physics_process() -> void:
	if _live_physics_pid <= 0 or OS.is_process_running(_live_physics_pid):
		return
	var exit_code := OS.get_process_exit_code(_live_physics_pid)
	var was_self_test := _live_physics_process_self_test
	_live_physics_status.text = "Live physics process finished with exit code %d." % exit_code
	_live_physics_pid = 0
	_remove_live_physics_configuration()
	_update_live_physics_controls()
	if was_self_test:
		if exit_code == 0:
			print(
				"LOCOMOTION_EXPERIMENT_WORKBENCH_LIVE_PROCESS_PASS exit=0 worlds=0 physical_identity_consumed=False"
			)
			get_tree().quit(0)
		else:
			printerr("LOCOMOTION_EXPERIMENT_WORKBENCH_LIVE_PROCESS_ERROR exit=%d" % exit_code)
			get_tree().quit(1)


func _poll_native_physics_processes() -> void:
	var finished: Array[String] = []
	for engine_id_value in _native_physics_pids.keys():
		var engine_id := String(engine_id_value)
		var pid := int(_native_physics_pids[engine_id])
		if pid > 0 and not OS.is_process_running(pid):
			var exit_code := OS.get_process_exit_code(pid)
			finished.append("%s exit=%d" % [_native_engine_label(engine_id), exit_code])
			_native_physics_pids.erase(engine_id)
	if not finished.is_empty() and _all_engine_physics_status != null:
		_all_engine_physics_status.text = "Native viewer finished: %s" % ", ".join(finished)
		if _all_engine_launch_pending:
			_stop_all_live_physics_processes()
			_all_engine_physics_status.text += (
				". Coordinated launch aborted before the shared start gate."
			)
		_update_live_physics_controls()
		return
	_maybe_release_all_engine_start()


func _maybe_release_all_engine_start() -> void:
	if not _all_engine_launch_pending or _native_start_gate_path.is_empty():
		return
	for engine_id in ["rapier_parry", "mujoco"]:
		if not _native_ready_receipt_valid(engine_id):
			return
	var gate := FileAccess.open(_native_start_gate_path, FileAccess.WRITE)
	if gate == null:
		_stop_all_live_physics_processes()
		_all_engine_physics_status.text = "Could not release the shared native start gate."
		_update_live_physics_controls()
		return
	gate.store_string(
		JSON.stringify(
			{
				"schema_version": "sporespore_live_explorer_protocol_v1",
				"source_commit": _git_head,
				"release_all_engines": true,
				"scientific_evidence_authority": false,
			}
		)
	)
	gate.close()
	_all_engine_launch_pending = false
	_launch_live_physics(false)
	if _live_physics_pid <= 0:
		_stop_all_live_physics_processes()
		_all_engine_physics_status.text = "Jolt did not start; native workers were stopped."
		_update_live_physics_controls()
		return
	_all_engine_physics_status.text = (
		"Shared start released: Jolt, Rapier, and MuJoCo are now real physical simulations. "
		+ "Read each window's measured wall-clock ratio; this is not a formal equivalence or "
		+ "real-time-performance result."
	)
	_update_live_physics_controls()


func _native_ready_receipt_valid(engine_id: String) -> bool:
	var path := "%s.%s.ready.json" % [_native_start_gate_path, engine_id]
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return (
		parsed is Dictionary
		and String((parsed as Dictionary).get("engine_id", "")) == engine_id
		and String((parsed as Dictionary).get("source_commit", "")) == _git_head
		and bool((parsed as Dictionary).get("ready_to_start", false))
		and not bool((parsed as Dictionary).get("scientific_evidence_authority", true))
	)


func _any_native_physics_process_running() -> bool:
	for pid_value in _native_physics_pids.values():
		if int(pid_value) > 0 and OS.is_process_running(int(pid_value)):
			return true
	return false


func _any_live_physics_process_running() -> bool:
	return (
		(_live_physics_pid > 0 and OS.is_process_running(_live_physics_pid))
		or _any_native_physics_process_running()
	)


func _stop_native_physics_processes() -> void:
	for pid_value in _native_physics_pids.values():
		var pid := int(pid_value)
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_native_physics_pids.clear()


func _stop_all_live_physics_processes() -> void:
	if _live_physics_pid > 0 and OS.is_process_running(_live_physics_pid):
		OS.kill(_live_physics_pid)
	_stop_native_physics_processes()
	_all_engine_launch_pending = false
	_cleanup_native_start_gate_files()


func _cleanup_native_start_gate_files() -> void:
	if _native_start_gate_path.is_empty():
		return
	var runtime_root := _repo_root.path_join(".tmp").path_join("workbench")
	for path in [
		_native_start_gate_path,
		"%s.rapier_parry.ready.json" % _native_start_gate_path,
		"%s.mujoco.ready.json" % _native_start_gate_path,
	]:
		var resolved := ProjectSettings.globalize_path(String(path))
		if resolved.begins_with(runtime_root) and FileAccess.file_exists(resolved):
			DirAccess.remove_absolute(resolved)
	_native_start_gate_path = ""


func _remove_live_physics_configuration() -> void:
	if _live_physics_config_path.is_empty():
		return
	var runtime_root := _repo_root.path_join(".tmp").path_join("workbench")
	var resolved := ProjectSettings.globalize_path(_live_physics_config_path)
	if resolved.begins_with(runtime_root) and FileAccess.file_exists(resolved):
		DirAccess.remove_absolute(resolved)
	_live_physics_config_path = ""


func _build_diagnostics_panel() -> Control:
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(480.0, 0.0)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_diagnostics = RichTextLabel.new()
	_diagnostics.name = "Diagnostics"
	_diagnostics.bbcode_enabled = true
	_diagnostics.scroll_active = true
	tabs.add_child(_diagnostics)
	tabs.add_child(RecoveryEvidencePanel.new())

	var proof_box := VBoxContainer.new()
	proof_box.name = "Proof"
	proof_box.add_theme_constant_override("separation", 7)
	_proof_tree = Tree.new()
	_proof_tree.columns = 3
	_proof_tree.set_column_title(0, "State")
	_proof_tree.set_column_title(1, "Artifact")
	_proof_tree.set_column_title(2, "SHA-256")
	_proof_tree.column_titles_visible = true
	_proof_tree.hide_root = true
	_proof_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_proof_tree.set_column_expand(0, false)
	_proof_tree.set_column_custom_minimum_width(0, 72)
	_proof_tree.set_column_expand(1, true)
	_proof_tree.set_column_expand(2, false)
	_proof_tree.set_column_custom_minimum_width(2, 110)
	_proof_tree.item_selected.connect(_on_proof_selected)
	proof_box.add_child(_proof_tree)
	_proof_details = RichTextLabel.new()
	_proof_details.bbcode_enabled = true
	_proof_details.custom_minimum_size = Vector2(0.0, 160.0)
	proof_box.add_child(_proof_details)
	var proof_actions := HBoxContainer.new()
	var open_proof := Button.new()
	open_proof.text = "Open artifact"
	open_proof.pressed.connect(_open_selected_proof)
	proof_actions.add_child(open_proof)
	var copy_path := Button.new()
	copy_path.text = "Copy path"
	copy_path.pressed.connect(_copy_selected_proof_path)
	proof_actions.add_child(copy_path)
	proof_box.add_child(proof_actions)
	tabs.add_child(proof_box)

	var output_box := VBoxContainer.new()
	output_box.name = "Run_Output"
	output_box.add_theme_constant_override("separation", 7)
	var safety := Label.new()
	safety.text = "Explorer values are never injected into frozen runners. The selected runner reloads repository authority."
	safety.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	safety.add_theme_color_override("font_color", COLOR_WARNING)
	output_box.add_child(safety)
	_run_output = RichTextLabel.new()
	_run_output.bbcode_enabled = false
	_run_output.scroll_following = true
	_run_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_run_output.text = "Select a run to see its command and safety boundary.\n"
	output_box.add_child(_run_output)
	var run_actions := HBoxContainer.new()
	_run_button = Button.new()
	_run_button.text = "Run selected audit"
	_run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_button.pressed.connect(_on_run_pressed)
	run_actions.add_child(_run_button)
	_cancel_button = Button.new()
	_cancel_button.text = "Stop process"
	_cancel_button.disabled = true
	_cancel_button.pressed.connect(_cancel_process)
	run_actions.add_child(_cancel_button)
	var clear := Button.new()
	clear.text = "Clear"
	clear.pressed.connect(_clear_output)
	run_actions.add_child(clear)
	output_box.add_child(run_actions)
	tabs.add_child(output_box)
	return tabs


func _build_confirmation_dialog() -> void:
	_confirmation_dialog = ConfirmationDialog.new()
	_confirmation_dialog.title = "Authorize one-shot physical campaign"
	_confirmation_dialog.dialog_text = (
		"The frozen supervisor consumes its experiment identity before the first world. "
		+ "It ignores the editable explorer controls and reloads repository authority."
	)
	_confirmation_dialog.ok_button_text = "Consume identity and run"
	_confirmation_dialog.cancel_button_text = "Keep experiment unconsumed"
	_confirmation_dialog.min_size = Vector2i(720, 390)
	add_child(_confirmation_dialog)
	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(660.0, 185.0)
	body.add_theme_constant_override("separation", 8)
	_confirmation_dialog.add_child(body)
	_confirmation_help = Label.new()
	_confirmation_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_confirmation_help)
	var phrase_label := Label.new()
	phrase_label.text = "Type the exact authorization phrase:"
	body.add_child(phrase_label)
	_confirmation_phrase = LineEdit.new()
	_confirmation_phrase.placeholder_text = "Exact phrase required"
	_confirmation_phrase.text_changed.connect(_on_confirmation_changed)
	body.add_child(_confirmation_phrase)
	var output_label := Label.new()
	output_label.text = "Durable output root (must not already exist):"
	body.add_child(output_label)
	_confirmation_output_root = LineEdit.new()
	_confirmation_output_root.text_changed.connect(_on_confirmation_changed)
	body.add_child(_confirmation_output_root)
	_confirmation_dialog.confirmed.connect(_execute_selected_run)


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", COLOR_ACCENT)
	return label


func _labeled_option(parent: VBoxContainer, label_text: String) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", COLOR_MUTED)
	parent.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(option)
	return option


func _populate_engines() -> void:
	_engine_select.clear()
	for engine_variant in _catalog.get("engines", []):
		var engine := engine_variant as Dictionary
		_engine_select.add_item(String(engine.get("label", engine.get("id", "engine"))))
		_engine_select.set_item_metadata(
			_engine_select.item_count - 1, String(engine.get("id", ""))
		)
	if _engine_select.item_count > 0:
		_engine_select.select(0)
		_on_engine_selected(0)


func _populate_presets() -> void:
	_preset_select.clear()
	for preset_variant in _catalog.get("presets", []):
		var preset := preset_variant as Dictionary
		_preset_select.add_item(String(preset.get("label", preset.get("id", "preset"))))
		_preset_select.set_item_metadata(
			_preset_select.item_count - 1, String(preset.get("id", ""))
		)


func _populate_runs() -> void:
	var previous_id := String(_selected_run.get("id", ""))
	_run_select.clear()
	var engine_id := String(_selected_engine.get("id", "all"))
	var selected_index := 0
	for run_variant in _catalog.get("runs", []):
		var run := run_variant as Dictionary
		var engine_ids: Array = run.get("engine_ids", [])
		if not engine_ids.has(engine_id):
			continue
		_run_select.add_item(String(run.get("label", run.get("id", "run"))))
		var index := _run_select.item_count - 1
		_run_select.set_item_metadata(index, String(run.get("id", "")))
		if String(run.get("id", "")) == previous_id:
			selected_index = index
	if _run_select.item_count > 0:
		_run_select.select(selected_index)
		_on_run_selected(selected_index)


func _build_parameter_controls() -> void:
	for child in _parameter_list.get_children():
		child.queue_free()
	_parameter_controls.clear()
	var current_group := ""
	for parameter_variant in _catalog.get("parameters", []):
		var parameter := parameter_variant as Dictionary
		var group := String(parameter.get("group", "Other"))
		if group != current_group:
			if not current_group.is_empty():
				_parameter_list.add_child(HSeparator.new())
			_parameter_list.add_child(_section_label(group))
			current_group = group
		_parameter_list.add_child(_build_parameter_row(parameter))


func _build_parameter_row(parameter: Dictionary) -> Control:
	var parameter_id := String(parameter.get("id", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var label := Label.new()
	label.text = String(parameter.get("label", parameter_id))
	var unit := String(parameter.get("unit", ""))
	if not unit.is_empty():
		label.text += " (%s)" % unit
	label.custom_minimum_size = Vector2(190.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.tooltip_text = String(parameter.get("why", ""))
	row.add_child(label)

	var parameter_type := String(parameter.get("type", "float"))
	var control: Control
	match parameter_type:
		"boolean":
			var toggle := CheckButton.new()
			toggle.toggled.connect(_on_boolean_changed.bind(parameter_id))
			toggle.focus_entered.connect(_on_parameter_focused.bind(parameter_id))
			control = toggle
		"enum":
			var option := OptionButton.new()
			for option_variant in parameter.get("options", []):
				var option_spec := option_variant as Dictionary
				option.add_item(String(option_spec.get("label", option_spec.get("id", "option"))))
				option.set_item_metadata(option.item_count - 1, String(option_spec.get("id", "")))
			option.item_selected.connect(_on_enum_changed.bind(parameter_id, option))
			option.focus_entered.connect(_on_parameter_focused.bind(parameter_id))
			control = option
		_:
			var spin := SpinBox.new()
			spin.min_value = float(parameter.get("minimum", -1000000.0))
			spin.max_value = float(parameter.get("maximum", 1000000.0))
			spin.step = float(parameter.get("step", 0.01))
			spin.allow_greater = false
			spin.allow_lesser = false
			spin.update_on_text_changed = true
			spin.value_changed.connect(_on_numeric_changed.bind(parameter_id, parameter_type))
			spin.get_line_edit().focus_entered.connect(_on_parameter_focused.bind(parameter_id))
			control = spin
	control.custom_minimum_size = Vector2(128.0, 0.0)
	control.size_flags_horizontal = Control.SIZE_SHRINK_END
	control.tooltip_text = String(parameter.get("why", ""))
	row.add_child(control)
	_parameter_controls[parameter_id] = control
	return row


func _on_engine_selected(index: int) -> void:
	if index < 0 or index >= _engine_select.item_count:
		return
	var engine_id := String(_engine_select.get_item_metadata(index))
	_selected_engine = _find_by_id(_catalog.get("engines", []), engine_id)
	_populate_runs()
	_refresh_all_views()


func _on_run_selected(index: int) -> void:
	if index < 0 or index >= _run_select.item_count:
		return
	var run_id := String(_run_select.get_item_metadata(index))
	_selected_run = _find_by_id(_catalog.get("runs", []), run_id)
	_refresh_proofs()
	_refresh_all_views()


func _on_preset_selected(index: int) -> void:
	if index < 0 or index >= _preset_select.item_count:
		return
	var preset_id := String(_preset_select.get_item_metadata(index))
	_current_preset = _find_by_id(_catalog.get("presets", []), preset_id)
	_baseline_values = (_current_preset.get("values", {}) as Dictionary).duplicate(true)
	_current_values = _baseline_values.duplicate(true)
	var preset_engine := String(_current_preset.get("engine_id", "all"))
	_select_option_by_metadata(_engine_select, preset_engine)
	_selected_engine = _find_by_id(_catalog.get("engines", []), preset_engine)
	_populate_runs()
	_sync_controls_from_values()
	_refresh_all_views()


func _sync_controls_from_values() -> void:
	_suppress_parameter_events = true
	for parameter_variant in _catalog.get("parameters", []):
		var parameter := parameter_variant as Dictionary
		var parameter_id := String(parameter.get("id", ""))
		var control := _parameter_controls.get(parameter_id) as Control
		if control == null or not _current_values.has(parameter_id):
			continue
		var value: Variant = _current_values[parameter_id]
		if control is SpinBox:
			(control as SpinBox).value = float(value)
		elif control is CheckButton:
			(control as CheckButton).button_pressed = bool(value)
		elif control is OptionButton:
			_select_option_by_metadata(control as OptionButton, String(value))
	_suppress_parameter_events = false


func _on_numeric_changed(value: float, parameter_id: String, parameter_type: String) -> void:
	if _suppress_parameter_events:
		return
	_current_values[parameter_id] = int(round(value)) if parameter_type == "integer" else value
	_focused_parameter_id = parameter_id
	_refresh_all_views()


func _on_boolean_changed(value: bool, parameter_id: String) -> void:
	if _suppress_parameter_events:
		return
	_current_values[parameter_id] = value
	_focused_parameter_id = parameter_id
	_refresh_all_views()


func _on_enum_changed(index: int, parameter_id: String, option: OptionButton) -> void:
	if _suppress_parameter_events:
		return
	_current_values[parameter_id] = String(option.get_item_metadata(index))
	_focused_parameter_id = parameter_id
	_refresh_all_views()


func _on_parameter_focused(parameter_id: String) -> void:
	_focused_parameter_id = parameter_id
	_refresh_selection_explanation()


func _refresh_all_views() -> void:
	if _preview == null:
		return
	var draft := _is_draft()
	var engine_label := String(_selected_engine.get("label", "No engine selected"))
	_preview.set_configuration(_current_values, engine_label, draft)
	_update_live_physics_controls()
	_refresh_draft_status(draft)
	_refresh_selection_explanation()
	_refresh_diagnostics()
	_update_run_controls()


func _refresh_draft_status(draft: bool) -> void:
	var preset_status := String(_current_preset.get("status", "unknown"))
	if draft:
		_draft_status.text = "EXPLORATION DRAFT — settings differ from the loaded preset. A new preregistration and campaign identity are required."
		_draft_status.add_theme_color_override("font_color", COLOR_WARNING)
	elif preset_status.begins_with("prospective_frozen"):
		_draft_status.text = "FROZEN PRESET VIEW — exact values loaded. The workbench still does not grant physical authority."
		_draft_status.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		_draft_status.text = "EXPLORATION PRESET — no existing campaign or evidence authority."
		_draft_status.add_theme_color_override("font_color", COLOR_WARNING)


func _refresh_selection_explanation() -> void:
	var parameter := _find_by_id(_catalog.get("parameters", []), _focused_parameter_id)
	var value: Variant = _current_values.get(_focused_parameter_id, "unknown")
	var preset_explanation := String(_current_preset.get("explanation", ""))
	var derived := _derived_values()
	_selection_explanation.text = (
		(
			"[font_size=18][color=#38bdf8]%s[/color][/font_size]\n"
			% String(parameter.get("label", _focused_parameter_id))
		)
		+ "[color=#f8fafc]Current value:[/color] %s\n" % str(value)
		+ "[color=#8da2bd]%s[/color]\n\n" % String(parameter.get("why", ""))
		+ "[b]Loaded preset[/b]\n%s\n\n" % preset_explanation
		+ "[b]Derived execution view[/b]\n"
		+ "P heading gain: %.4f rad/m\n" % float(derived.get("p_heading_gain", 0.0))
		+ "V heading gain: %.4f rad/(m/s)\n" % float(derived.get("v_heading_gain", 0.0))
		+ (
			"Timestep: %.4f ms; estimated steps: %d\n"
			% [float(derived.get("timestep_ms", 0.0)), int(derived.get("estimated_steps", 0))]
		)
		+ "Draft fingerprint: [code]%s[/code]" % _draft_fingerprint()
	)


func _refresh_diagnostics() -> void:
	var warnings := _claim_warnings()
	var warning_lines := ""
	if warnings.is_empty():
		warning_lines = "[color=#55c99a]No extra unsupported dimensions enabled in this view.[/color]"
	else:
		for warning_variant in warnings:
			warning_lines += "• [color=#fb7185]%s[/color]\n" % String(warning_variant)
	var run_summary := String(_selected_run.get("summary", "No run selected."))
	var runner_path := String(_selected_run.get("runner_path", ""))
	var command_preview := "No process — explore only"
	if not runner_path.is_empty():
		command_preview = (
			"pwsh -NoProfile -File %s %s"
			% [runner_path, " ".join(PackedStringArray(_selected_run.get("arguments", [])))]
		)
	_diagnostics.text = (
		"[font_size=19][color=#38bdf8]Current authority and risk[/color][/font_size]\n\n"
		+ (
			"[b]Engine[/b]\n%s\n%s\n\n"
			% [
				String(_selected_engine.get("label", "unknown")),
				String(_selected_engine.get("summary", ""))
			]
		)
		+ "[b]Selected run[/b]\n%s\n\n" % run_summary
		+ "Status: [code]%s[/code]\n" % String(_selected_run.get("status", "n/a"))
		+ "World policy: [code]%s[/code]\n" % String(_selected_run.get("world_policy", "none"))
		+ "Risk: [code]%s[/code]\n\n" % String(_selected_run.get("risk", "none"))
		+ "[b]Command[/b]\n[code]%s[/code]\n\n" % command_preview
		+ (
			"[b]What this may establish[/b]\n%s\n\n"
			% String(_selected_run.get("claim_boundary", "No evidence claim."))
		)
		+ "[b]Draft/coverage diagnostics[/b]\n%s\n\n" % warning_lines
		+ (
			"[b]Source state[/b]\nHEAD: [code]%s[/code]\nTracked source: %s\n"
			% [_git_head, "clean" if _source_clean else "dirty"]
		)
		+ "Workbench catalog: operator interface, never scientific authority."
	)


func _claim_warnings() -> Array[String]:
	var warnings: Array[String] = []
	if _is_draft():
		warnings.append(
			"Values or engine differ from the loaded preset; this is a new-campaign draft."
		)
	if int(_current_values.get("limb_count", 4)) != 4:
		(
			warnings
			. append(
				"Current SDK release evidence is quadruped-only; this limb topology is unsupported research scope."
			)
		)
	if String(_current_values.get("locomotion_mode", "balanced_wave_walk")) != "balanced_wave_walk":
		warnings.append("The selected locomotion mode has no accepted SDK evidence yet.")
	if (
		String(_current_values.get("terrain_kind", "flat")) != "flat"
		or absf(float(_current_values.get("slope_degrees", 0.0))) > 0.0001
	):
		warnings.append("Rough, stepped, or inclined terrain robustness is currently unaccepted.")
	if bool(_current_values.get("external_push_enabled", false)):
		warnings.append("External-push recovery is currently unaccepted.")
	if bool(_current_values.get("sensor_noise_enabled", false)):
		warnings.append("Sensor-noise robustness is currently unaccepted.")
	if bool(_current_values.get("sensor_latency_enabled", false)):
		warnings.append("Sensor-latency robustness is currently unaccepted.")
	var friction := float(_current_values.get("authored_friction", 0.0))
	var fresh_points := [0.57, 0.69, 0.81]
	var matches_fresh := false
	for point in fresh_points:
		if is_equal_approx(friction, float(point)):
			matches_fresh = true
	if not matches_fresh:
		(
			warnings
			. append(
				"Friction is outside BW22M/BW22L's three fresh authored points; no interpolation claim is permitted."
			)
		)
	var engine_id := String(_selected_engine.get("id", "all"))
	if engine_id == "rapier_parry" or engine_id == "mujoco":
		warnings.append(
			"This engine does not yet have accepted selected-policy physical C6 evidence."
		)
	return warnings


func _derived_values() -> Dictionary:
	var length_scale := maxf(0.0001, float(_current_values.get("torso_length_scale", 1.0)))
	var p_factor := float(_current_values.get("cross_track_proportional_factor", 1.0))
	var v_factor := float(_current_values.get("cross_track_velocity_factor", 1.0))
	var hz := maxi(1, int(_current_values.get("physics_hz", 120)))
	var duration := float(_current_values.get("duration_seconds", 0.0))
	return {
		"p_heading_gain": p_factor / length_scale,
		"v_heading_gain": 0.35 * v_factor * sqrt(length_scale),
		"timestep_ms": 1000.0 / float(hz),
		"estimated_steps": int(round(duration * float(hz)))
	}


func _is_draft() -> bool:
	if _current_preset.is_empty():
		return true
	if String(_selected_engine.get("id", "")) != String(_current_preset.get("engine_id", "")):
		return true
	for parameter_variant in _catalog.get("parameters", []):
		var parameter := parameter_variant as Dictionary
		var parameter_id := String(parameter.get("id", ""))
		if not _baseline_values.has(parameter_id) or not _current_values.has(parameter_id):
			return true
		var expected: Variant = _baseline_values[parameter_id]
		var actual: Variant = _current_values[parameter_id]
		if expected is float or actual is float:
			if not is_equal_approx(float(expected), float(actual)):
				return true
		elif expected != actual:
			return true
	return false


func _draft_fingerprint() -> String:
	var envelope := {"engine_id": String(_selected_engine.get("id", "")), "values": _current_values}
	return JSON.stringify(envelope, "", true).sha256_text().substr(0, 16)


func _generate_run_seed() -> void:
	_set_parameter_value("random_seed", _new_seed())


func _generate_terrain_seed() -> void:
	_set_parameter_value("terrain_seed", _new_seed())


func _generate_both_seeds() -> void:
	_set_parameter_value("random_seed", _new_seed(), false)
	_set_parameter_value("terrain_seed", _new_seed(), true)


func _new_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 2147483646)


func _set_parameter_value(parameter_id: String, value: Variant, refresh: bool = true) -> void:
	_current_values[parameter_id] = value
	var control := _parameter_controls.get(parameter_id) as Control
	_suppress_parameter_events = true
	if control is SpinBox:
		(control as SpinBox).value = float(value)
	elif control is CheckButton:
		(control as CheckButton).button_pressed = bool(value)
	elif control is OptionButton:
		_select_option_by_metadata(control as OptionButton, String(value))
	_suppress_parameter_events = false
	_focused_parameter_id = parameter_id
	if refresh:
		_refresh_all_views()


func _reset_current_preset() -> void:
	_current_values = _baseline_values.duplicate(true)
	var preset_engine := String(_current_preset.get("engine_id", "all"))
	_select_option_by_metadata(_engine_select, preset_engine)
	_selected_engine = _find_by_id(_catalog.get("engines", []), preset_engine)
	_populate_runs()
	_sync_controls_from_values()
	_refresh_all_views()


func _copy_draft_json() -> void:
	var draft := {
		"schema_version": "sporespore_locomotion_workbench_exploration_draft_v1",
		"evidence_authority": false,
		"new_campaign_required": true,
		"base_preset_id": String(_current_preset.get("id", "")),
		"engine_id": String(_selected_engine.get("id", "")),
		"values": _current_values,
		"fingerprint_sha256": _draft_fingerprint()
	}
	DisplayServer.clipboard_set(JSON.stringify(draft, "  ", true))
	_copy_draft_button.text = "Copied — no authority"
	get_tree().create_timer(1.8).timeout.connect(
		func(): _copy_draft_button.text = "Copy draft JSON"
	)


static func proof_digest_state(exists: bool, actual: String, expected: String) -> String:
	if not exists:
		return "MISSING"
	if expected.is_empty():
		return "FOUND"
	return "MATCH" if actual == expected else "MISMATCH"


func _refresh_proofs() -> void:
	if _proof_tree == null:
		return
	_proof_tree.clear()
	_selected_proof.clear()
	var root := _proof_tree.create_item()
	for proof_variant in _selected_run.get("proofs", []):
		var proof := (proof_variant as Dictionary).duplicate(true)
		var path := String(proof.get("path", ""))
		var absolute := _absolute_path(path)
		var exists := FileAccess.file_exists(absolute)
		var actual_sha := _sha256_file(absolute) if exists else ""
		var expected_sha := String(proof.get("expected_sha256", "")).trim_prefix("sha256:")
		var matches := exists and (expected_sha.is_empty() or actual_sha == expected_sha)
		proof["absolute_path"] = absolute
		proof["exists"] = exists
		proof["actual_sha256"] = actual_sha
		proof["matches"] = matches
		proof["digest_state"] = proof_digest_state(exists, actual_sha, expected_sha)
		var item := _proof_tree.create_item(root)
		item.set_text(0, String(proof["digest_state"]))
		item.set_text(1, String(proof.get("label", path)))
		item.set_text(2, actual_sha.substr(0, 12) if exists else "—")
		item.set_tooltip_text(1, absolute)
		item.set_metadata(0, proof)
		var color := COLOR_SUCCESS if matches else COLOR_DANGER
		if expected_sha.is_empty() and exists:
			color = COLOR_ACCENT
		for column in 3:
			item.set_custom_color(column, color)
	if root.get_first_child() != null:
		root.get_first_child().select(0)
		_on_proof_selected()
	else:
		_proof_details.text = "No proof artifacts are attached to this view."


func _on_proof_selected() -> void:
	var item := _proof_tree.get_selected()
	if item == null:
		return
	var metadata: Variant = item.get_metadata(0)
	if not metadata is Dictionary:
		return
	_selected_proof = metadata as Dictionary
	var expected := String(_selected_proof.get("expected_sha256", ""))
	var actual := String(_selected_proof.get("actual_sha256", ""))
	_proof_details.text = (
		"[b]%s[/b]\n" % String(_selected_proof.get("label", "Artifact"))
		+ "[code]%s[/code]\n\n" % String(_selected_proof.get("absolute_path", ""))
		+ "Exists: %s\n" % str(bool(_selected_proof.get("exists", false)))
		+ "Reference role: %s\n" % String(_selected_proof.get("binding_role", "pinned_artifact"))
		+ "Historical source mismatches do not regrade their retained campaign results.\n"
		+ (
			"Expected SHA-256: [code]%s[/code]\n"
			% (expected if not expected.is_empty() else "not pinned in catalog; see closure")
		)
		+ (
			"Current SHA-256: [code]%s[/code]\n"
			% (actual if not actual.is_empty() else "unavailable")
		)
		+ (
			"Digest status: %s"
			% String(_selected_proof.get("digest_state", "MISSING"))
		)
	)


func _open_selected_proof() -> void:
	var path := String(_selected_proof.get("absolute_path", ""))
	if not path.is_empty() and FileAccess.file_exists(path):
		OS.shell_open(path)


func _copy_selected_proof_path() -> void:
	var path := String(_selected_proof.get("absolute_path", ""))
	if not path.is_empty():
		DisplayServer.clipboard_set(path)


func _open_full_guide() -> void:
	OS.shell_open(_absolute_path("docs/LOCOMOTION_EXPERIMENT_WORKBENCH_GUIDE.md"))


func _update_run_controls() -> void:
	if _run_button == null:
		return
	var runner_path := String(_selected_run.get("runner_path", ""))
	var physical := bool(_selected_run.get("requires_confirmation", false))
	var busy := not _process_info.is_empty()
	var physical_view_ready := (
		not _is_draft() and String(_current_preset.get("id", "")).begins_with("bw22l_")
	)
	_run_button.disabled = busy or runner_path.is_empty() or (physical and not physical_view_ready)
	if runner_path.is_empty():
		_run_button.text = "Explore only — no process"
	elif physical and not physical_view_ready:
		_run_button.text = "Load an exact BW22L preset to authorize"
	elif physical:
		_run_button.text = "Review one-shot physical authorization"
	else:
		_run_button.text = (
			"Run selected %s" % String(_selected_run.get("kind", "audit")).replace("_", " ")
		)
	_cancel_button.disabled = not busy


func _on_run_pressed() -> void:
	if _selected_run.is_empty() or not _process_info.is_empty():
		return
	if bool(_selected_run.get("requires_confirmation", false)):
		_prepare_physical_confirmation()
		return
	_execute_selected_run()


func _prepare_physical_confirmation() -> void:
	var phrase := String(_selected_run.get("confirmation_phrase", ""))
	_confirmation_phrase.text = ""
	_confirmation_output_root.text = _default_physical_output_root()
	_confirmation_help.text = (
		"Required phrase: %s\n\n" % phrase
		+ "The supervisor will independently require a clean pushed HEAD equal to live GitHub main, "
		+ "a new durable output directory, zero prior attempts, exact frozen hashes, and its complete synthetic preflight."
	)
	_on_confirmation_changed("")
	_confirmation_dialog.popup_centered(Vector2i(760, 430))
	_confirmation_phrase.grab_focus()


func _on_confirmation_changed(_text: String) -> void:
	if _confirmation_dialog == null:
		return
	var phrase_ok := (
		_confirmation_phrase.text == String(_selected_run.get("confirmation_phrase", ""))
	)
	var output_path := _confirmation_output_root.text.strip_edges()
	var output_ok := not output_path.is_empty() and not DirAccess.dir_exists_absolute(output_path)
	_confirmation_dialog.get_ok_button().disabled = not (phrase_ok and output_ok)


func _default_physical_output_root() -> String:
	var evidence_root := _repo_root.get_base_dir().path_join("SporeSpore_Evidence")
	var prefix := String(_selected_run.get("output_leaf_prefix", "physical-"))
	return evidence_root.path_join(prefix + _git_head.substr(0, 7))


func _execute_selected_run() -> void:
	var runner_path := String(_selected_run.get("runner_path", ""))
	if runner_path.is_empty():
		return
	if _pwsh_path.is_empty():
		_append_output("[workbench] ERROR: pwsh.exe was not found on PATH.\n")
		return
	var absolute_runner := _absolute_path(runner_path)
	if not FileAccess.file_exists(absolute_runner):
		_append_output("[workbench] ERROR: runner does not exist: %s\n" % absolute_runner)
		return
	var arguments := PackedStringArray(["-NoLogo", "-NoProfile", "-File", absolute_runner])
	for argument_variant in _selected_run.get("arguments", []):
		arguments.append(String(argument_variant))
	if bool(_selected_run.get("requires_output_root", false)):
		arguments.append("-OutputRoot")
		arguments.append(_confirmation_output_root.text.strip_edges())

	_process_output = ""
	_run_output.text = ""
	_append_output("[workbench] repository: %s\n" % _repo_root)
	_append_output("[workbench] command: %s %s\n\n" % [_pwsh_path, " ".join(arguments)])
	var launched := OS.execute_with_pipe(_pwsh_path, arguments, false)
	if launched.is_empty():
		_append_output("[workbench] ERROR: process could not be started.\n")
		return
	_process_info = launched
	_process_started_msec = Time.get_ticks_msec()
	_run_button.disabled = true
	_cancel_button.disabled = false


func _drain_process_stream(key: String, prefix: String) -> void:
	var stream := _process_info.get(key) as FileAccess
	if stream == null:
		return
	# With execute_with_pipe(..., false), get_buffer() itself is nonblocking and
	# returns fewer bytes (including zero) when the pipe currently has no data.
	# Bound the loop so a noisy verifier cannot monopolize a rendered frame.
	for _chunk_index in 16:
		var bytes := stream.get_buffer(4096)
		if bytes.is_empty():
			return
		var chunk := bytes.get_string_from_utf8()
		if not prefix.is_empty():
			var lines := chunk.split("\n", true)
			chunk = prefix + ("\n" + prefix).join(lines)
		_append_output(chunk)
		if bytes.size() < 4096:
			return


func _append_output(text_to_append: String) -> void:
	_process_output += text_to_append
	if _process_output.length() > MAX_OUTPUT_CHARACTERS:
		_process_output = (
			"[workbench] earlier output truncated\n" + _process_output.right(MAX_OUTPUT_CHARACTERS)
		)
	_run_output.text = _process_output


func _cancel_process() -> void:
	if _process_info.is_empty():
		return
	var pid := int(_process_info.get("pid", 0))
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
		_append_output("\n[workbench] stop requested for process %d\n" % pid)


func _clear_output() -> void:
	if _process_info.is_empty():
		_process_output = ""
		_run_output.text = ""


func _refresh_source_identity() -> void:
	_git_head = _git_output(["rev-parse", "HEAD"]).strip_edges()
	if _git_head.is_empty():
		_git_head = "unknown"
	var status := _git_output(["status", "--porcelain=v1", "--untracked-files=all"])
	_source_clean = status.strip_edges().is_empty()
	var local_origin_main := _git_output(["rev-parse", "origin/main"]).strip_edges()
	_source_matches_local_origin_main = (
		_source_clean and not local_origin_main.is_empty() and _git_head == local_origin_main
	)
	_source_status.text = (
		"HEAD %s\n%s"
		% [
			_git_head.substr(0, 12),
			(
				"clean and matches local origin/main"
				if _source_matches_local_origin_main
				else (
					"clean but does not match local origin/main"
					if _source_clean
					else "working tree has source changes"
				)
			)
		]
	)
	_source_status.add_theme_color_override(
		"font_color", COLOR_SUCCESS if _source_matches_local_origin_main else COLOR_WARNING
	)
	_refresh_all_views()


func _git_output(arguments: Array[String]) -> String:
	var output: Array = []
	var packed := PackedStringArray(["-C", _repo_root])
	packed.append_array(PackedStringArray(arguments))
	var exit_code := OS.execute("git.exe", packed, output, true)
	if exit_code != 0 or output.is_empty():
		return ""
	return "".join(output)


func _find_executable(executable_name: String) -> String:
	var output: Array = []
	var exit_code := OS.execute("where.exe", PackedStringArray([executable_name]), output, true)
	if exit_code != 0 or output.is_empty():
		return ""
	var candidates := String(output[0]).replace("\r", "").split("\n", false)
	return String(candidates[0]).strip_edges() if not candidates.is_empty() else ""


func _absolute_path(path: String) -> String:
	if path.is_absolute_path():
		return path.replace("/", "\\") if OS.get_name() == "Windows" else path
	return _repo_root.path_join(path)


func _sha256_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	while file.get_position() < file.get_length():
		var remaining := file.get_length() - file.get_position()
		context.update(file.get_buffer(mini(1048576, remaining)))
	return context.finish().hex_encode()


func _find_by_id(items: Array, wanted_id: String) -> Dictionary:
	for item_variant in items:
		if (
			item_variant is Dictionary
			and String((item_variant as Dictionary).get("id", "")) == wanted_id
		):
			return item_variant as Dictionary
	return {}


func _select_option_by_metadata(option: OptionButton, wanted: String) -> void:
	for index in option.item_count:
		if String(option.get_item_metadata(index)) == wanted:
			option.select(index)
			return


func catalog_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if String(_catalog.get("schema_version", "")) != EXPECTED_CATALOG_SCHEMA:
		errors.append("catalog schema mismatch")
	for key in ["engines", "presets", "parameters", "runs"]:
		if not _catalog.get(key, []) is Array or (_catalog.get(key, []) as Array).is_empty():
			errors.append("catalog %s must be a non-empty array" % key)
	var parameter_ids: Dictionary = {}
	for parameter_variant in _catalog.get("parameters", []):
		var parameter := parameter_variant as Dictionary
		var parameter_id := String(parameter.get("id", ""))
		if parameter_id.is_empty() or parameter_ids.has(parameter_id):
			errors.append("parameter id missing or duplicated: %s" % parameter_id)
		parameter_ids[parameter_id] = true
	for preset_variant in _catalog.get("presets", []):
		var preset := preset_variant as Dictionary
		var values := preset.get("values", {}) as Dictionary
		for parameter_id in parameter_ids:
			if not values.has(parameter_id):
				errors.append("preset %s lacks %s" % [String(preset.get("id", "")), parameter_id])
	var physical_count := 0
	for run_variant in _catalog.get("runs", []):
		var run := run_variant as Dictionary
		var runner_path := String(run.get("runner_path", ""))
		if not runner_path.is_empty() and not FileAccess.file_exists(_absolute_path(runner_path)):
			errors.append("run %s runner is missing" % String(run.get("id", "")))
		if String(run.get("kind", "")) == "physical_one_shot":
			physical_count += 1
			if not bool(run.get("requires_confirmation", false)):
				errors.append("physical run lacks confirmation")
		elif PackedStringArray(run.get("arguments", [])).has("-RunPhysical"):
			errors.append("nonphysical run exposes -RunPhysical")
	if physical_count != 0:
		errors.append("closed BW22L catalog must expose zero physical one-shot runs")
	return errors


func _validate_or_report_catalog() -> void:
	var errors := catalog_validation_errors()
	if errors.is_empty():
		_append_output(
			(
				"[workbench] catalog validated: engines=%d presets=%d parameters=%d runs=%d\n"
				% [
					(_catalog.get("engines", []) as Array).size(),
					(_catalog.get("presets", []) as Array).size(),
					(_catalog.get("parameters", []) as Array).size(),
					(_catalog.get("runs", []) as Array).size()
				]
			)
		)
	else:
		for error in errors:
			_append_output("[workbench] CATALOG ERROR: %s\n" % error)


func _has_command_line_argument(argument: String) -> bool:
	return OS.get_cmdline_user_args().has(argument)


func _finish_self_test() -> void:
	var errors := catalog_validation_errors()
	for test_case in [
		[false, "", "pinned", "MISSING"],
		[true, "actual", "", "FOUND"],
		[true, "pinned", "pinned", "MATCH"],
		[true, "changed", "pinned", "MISMATCH"]
	]:
		if proof_digest_state(test_case[0], test_case[1], test_case[2]) != test_case[3]:
			errors.append("proof digest state misreported")
	if errors.is_empty():
		print(
			(
				"LOCOMOTION_EXPERIMENT_WORKBENCH_PASS engines=%d presets=%d parameters=%d runs=%d worlds=0 physical_identity_consumed=False"
				% [
					(_catalog.get("engines", []) as Array).size(),
					(_catalog.get("presets", []) as Array).size(),
					(_catalog.get("parameters", []) as Array).size(),
					(_catalog.get("runs", []) as Array).size()
				]
			)
		)
		get_tree().quit(0)
	else:
		for error in errors:
			printerr("LOCOMOTION_EXPERIMENT_WORKBENCH_ERROR %s" % error)
		get_tree().quit(1)


func _start_live_physics_process_self_test() -> void:
	print("LOCOMOTION_EXPERIMENT_WORKBENCH_LIVE_PROCESS_START mode=validate_only worlds=0")
	_launch_live_physics(true)
	if _live_physics_pid <= 0:
		printerr("LOCOMOTION_EXPERIMENT_WORKBENCH_LIVE_PROCESS_ERROR process did not start")
		get_tree().quit(1)


func _start_safe_process_self_test() -> void:
	print("LOCOMOTION_EXPERIMENT_WORKBENCH_SAFE_PROCESS_START audit=repository_boundary worlds=0")
	_selected_run = _find_by_id(_catalog.get("runs", []), "repository_boundary")
	if _selected_run.is_empty():
		printerr(
			"LOCOMOTION_EXPERIMENT_WORKBENCH_SAFE_PROCESS_ERROR repository_boundary run is missing"
		)
		get_tree().quit(1)
		return
	_execute_selected_run()
	if _process_info.is_empty():
		printerr("LOCOMOTION_EXPERIMENT_WORKBENCH_SAFE_PROCESS_ERROR process did not start")
		get_tree().quit(1)


func _finish_safe_process_self_test(exit_code: int) -> void:
	var expected := "REPOSITORY_AGENT_BOUNDARY_PASS"
	print(
		(
			"LOCOMOTION_EXPERIMENT_WORKBENCH_SAFE_PROCESS_RESULT exit=%d output_chars=%d marker=%s"
			% [exit_code, _process_output.length(), str(_process_output.contains(expected))]
		)
	)
	if exit_code == 0 and _process_output.contains(expected):
		print(
			"LOCOMOTION_EXPERIMENT_WORKBENCH_SAFE_PROCESS_PASS audit=repository_boundary exit=0 worlds=0 physical_identity_consumed=False"
		)
		get_tree().quit(0)
	else:
		printerr(
			(
				"LOCOMOTION_EXPERIMENT_WORKBENCH_SAFE_PROCESS_ERROR exit=%d marker=%s"
				% [exit_code, str(_process_output.contains(expected))]
			)
		)
		get_tree().quit(1)
