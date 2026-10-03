class_name EditorBench
extends Control

## T1 editor bench: load a CreatureCard, assemble it in a 3D viewport, render the
## evaluator score, and allow simple per-part scale edits through EditSession.

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const ViewportDropContainerScript := preload("res://scripts/editor/viewport_drop_container.gd")
const LocomotionViewerScript := preload("res://scripts/sim/locomotion_viewer.gd")
const KinestheticTrainerScript := preload("res://scripts/sim/kinesthetic_trainer.gd")

const CAMERA_DRAG_NONE := 0
const CAMERA_DRAG_ORBIT := 1
const CAMERA_DRAG_PAN := 2
const PAUSE_UNPAUSE := 0
const PAUSE_SETTINGS := 1
const PAUSE_SAVE := 2
const PAUSE_QUIT_TITLE := 3
const PAUSE_EXIT_GAME := 4
const PAUSE_EXIT_PROJECTS := 5

var _session: EditSession
var _rows: Array[Dictionary] = []
var _tab_rows := {}
var _selected_index := 0
var _selected_indices: Array[int] = [0]
var _updating_controls := false
var _syncing_part_selection := false
var _active_card_name := "Untitled"

var _root_layout: HBoxContainer
var _creature_tabs: TabContainer
var _part_list: ItemList
var _parts_breadcrumb: Button         # M54 (B11): collapsed summary over the parts list
var _tab_overflow_popup: PopupMenu    # M54 (B8): overflow menu for creature groups
var _part_names: PackedStringArray    # M54: cached short names for the breadcrumb
var _score_mass: Label
var _score_radius: Label
var _score_stable: Label
var _score_margin: Label
var _score_tip: Label
var _score_speed: Label
var _score_probe: Label
var _score_measured: Label
var _score_debt: Label
var _score_vitals: Label
var _score_message: Label
var _attachment_status: Label
var _status_label: Label
var _scale_x: SpinBox
var _scale_y: SpinBox
var _scale_z: SpinBox
var _undo_button: Button
var _redo_button: Button
var _save_button: Button
var _save_name_edit: LineEdit
var _type_option: OptionButton
var _density_spin: SpinBox
var _extent_x: SpinBox
var _extent_y: SpinBox
var _extent_z: SpinBox
var _socket_x: SpinBox
var _socket_y: SpinBox
var _socket_z: SpinBox
var _hinge_x: SpinBox
var _hinge_y: SpinBox
var _hinge_z: SpinBox
var _rot_x: SpinBox
var _rot_y: SpinBox
var _rot_z: SpinBox
var _joint_amp: SpinBox
var _joint_rest: SpinBox
var _joint_min: SpinBox
var _joint_max: SpinBox
var _gait_phase: SpinBox
var _muscle_check: CheckBox
var _muscle_amount: SpinBox
var _global_muscle_amount: SpinBox
# M44 authoring widgets
var _spring_k: SpinBox
var _spring_damp: SpinBox
var _spring_eff: SpinBox
var _weapon_kind: OptionButton
var _weapon_sharp: SpinBox
var _weapon_pen: SpinBox
var _weapon_impact: SpinBox
var _weapon_reach: SpinBox
var _loco_mode: OptionButton
# M55 surface controls
var _drive_turn: SpinBox
var _drive_tear: SpinBox
var _drive_traction: SpinBox
var _drive_posture: SpinBox
var _mesh_import_dialog: FileDialog
var _score_viability: Label
# M57 co-pilot dock + settings popup
var _copilot_log: RichTextLabel
var _copilot_input: LineEdit
var _copilot_scope: CheckBox
var _copilot_scope_chip: Label
var _copilot_preview_label: Label
var _copilot_apply_button: Button
var _copilot_discard_button: Button
var _copilot_pending_call := {}
var _last_measured := {}   # last "Measure walk" result, so the co-pilot can diagnose explosions/falls
var _settings_popup: PopupPanel
var _settings_llm_models: OptionButton
# M58 display layer
var _force_xray := false
var _force_xray_node: MeshInstance3D
var _wireframe := false
var _palette_data: Dictionary = {}
var _palette_base_btn: ColorPickerButton
var _palette_secondary_btn: ColorPickerButton
var _pattern_option: OptionButton
var _fossils: FossilRecorder = FossilRecorder.new()
var _ghost_enabled := false
var _ghost_node: Node3D
var _ghost_t := 0.0
var _ghost_fossil_index := -1
var _overlay_gizmos := false
var _overlay_node: Node3D
var _sonify := false
var _sonify_player: AudioStreamPlayer
var _sonify_playback
var _sonify_phase := 0.0
var _stat_card_label: RichTextLabel
var _gpu_status: Label
var _pause_menu: PopupMenu

var _viewport: SubViewport
var _world: Node3D
var _creature_node: Node3D
var _part_mat: StandardMaterial3D
var _highlight_mat: StandardMaterial3D
var _hinge_guide: MeshInstance3D
var _hinge_guide_segments := 0
var _move_mode := false
var _cog_marker: MeshInstance3D
var _camera_pivot: Node3D
var _camera: Camera3D
var _cam_yaw := 0.7
var _cam_pitch := 0.35
var _cam_dist := 6.0
var _cam_target := Vector3.ZERO
var _dragging := false
var _camera_drag_mode := CAMERA_DRAG_NONE
var _empty_press_pending := false
var _empty_press_pos := Vector2.ZERO
const CLEAN_CLICK_PX := 4.0
var _gizmo_dragging := false
var _gizmo_pending_socket_pos := Vector3.ZERO

var _palette: PartPalette
var _gen_seed: SpinBox
var _gen_legs: SpinBox
var _gen_spine: SpinBox
var _gen_leg_segs: SpinBox
var _gen_arm_pairs: SpinBox
var _gen_arm_segs: SpinBox
var _gen_head: CheckBox
var _gen_organs: CheckBox
var _gen_symmetry: CheckBox
var _gen_biped: CheckBox
var _drop_highlight: MeshInstance3D
var _drop_ghost: MeshInstance3D
var _ground: MeshInstance3D
var _sim_button: Button
var _measure_button: Button
var _sim_speed: SpinBox
var _track_picker: OptionButton    # M55: which Track Measure/Optimize run on (incl. curved + hazards)
var _sim_viewer: Node
var _optimize_button: Button
var _optimizing := false
var _measuring := false
var _kinesthetic_button: Button    # AI-drive training: demonstrate -> capture forces -> bake a MotionClip
var _training := false
var _tension_label: Label          # live per-joint torque readout ("tension sensors") during the sim
var _llm_check: CheckBox
var _llm_models: OptionButton
var _skin_check: CheckBox
var _skin_enabled := false
var _skin_node: Node3D
var _dashboard_label: Label
var _armed_part_id: StringName = &""
var _attach_existing_mode := false
# M56 interactive attach + hinge editor
var _place_nub_mode := false
var _nub_node: Node3D
var _hinge_editing := false
var _hinge_edit_index := -1
var _hinge_editor_node: MeshInstance3D
var _hinge_drag_handle := 0           # -1 = min handle, +1 = max handle, 0 = none
var _nub_toggle_button: Button
const NUB_PICK_PX := 22.0


func _ready() -> void:
	_build_ui()
	_load_cards()
	_open_initial_card()


func _process(_delta: float) -> void:
	pump_scores_blocking()
	_tick_skin()
	_tick_force_xray()   # M58 FUN-1
	_tick_ghost()        # M58 FUN-2
	_tick_sonification() # M58 FUN-3
	_tick_tension()      # AI-drive training: live per-joint torque readout


func load_card(card: CreatureCard) -> void:
	if card == null or card.root == null:
		return
	_teardown_sim()
	_disarm_palette()
	_session = EditSession.new(card.root)
	_session.genome_changed.connect(_on_genome_changed)
	_session.score_changed.connect(_on_score_changed)
	_session.edit_rejected.connect(_on_edit_rejected)
	_selected_index = 0
	_selected_indices = [0]
	_attach_existing_mode = false
	_active_card_name = card.display_name
	# M58 (B7): adopt the card's display palette (display-only; round-trips on save).
	_palette_data = card.palette.duplicate(true) if card.palette != null else {}
	_sync_palette_controls()
	_rebuild_view()
	_rebuild_part_list()
	_sync_controls_from_selection()
	pump_scores_blocking()
	_frame_camera_on_creature()
	_update_buttons()
	_update_copilot_scope_chip()
	_status_label.text = card.display_name


func save_current_card(path := "") -> Error:
	if _session == null:
		return ERR_UNCONFIGURED
	var save_path := path
	if save_path == "":
		save_path = CreatureIO.DEFAULT_DIR.path_join("%s.tres" % _safe_file_stem(_active_card_name))
	var card := CreatureCard.new()
	card.display_name = _active_card_name
	card.root = _session.root()
	card.notes = "Saved from the editor bench."
	card.palette = _palette_data.duplicate(true)   # M58 (B7): persist the display palette
	var err := CreatureIO.save(card, save_path)
	if err == OK:
		_status_label.text = "Saved %s" % save_path
		_load_cards()
	else:
		_status_label.text = "Save failed: %s" % err
	return err


# Start a fresh, empty creature (a single body box) to build off of.
func new_creature() -> void:
	var card := CreatureCard.new()
	card.display_name = "New Creature"
	card.root = PartCatalog.make_blank()
	card.notes = "New blank creature."
	load_card(card)
	if _save_name_edit != null:
		_save_name_edit.text = ""
	_status_label.text = "New blank creature — build it up, type a name, then Save."


# Save, using the name field when the user typed one (else keep the current name).
func _save_from_name_field() -> void:
	var nm := _save_name_edit.text.strip_edges() if _save_name_edit != null else ""
	if nm != "":
		_active_card_name = nm
	save_current_card()


# Save a COPY under the typed name (Save As); requires a name.
func _save_as_from_name_field() -> void:
	var nm := _save_name_edit.text.strip_edges() if _save_name_edit != null else ""
	if nm == "":
		_status_label.text = "Type a name in the field first to Save As."
		return
	_active_card_name = nm
	save_current_card()


func select_part(index: int, additive := false) -> void:
	if _session == null:
		return
	var count := part_count()
	_selected_index = clampi(index, 0, maxi(count - 1, 0))
	if additive:
		if _selected_indices.has(_selected_index):
			if _selected_indices.size() > 1:
				_selected_indices.erase(_selected_index)
				_selected_index = _selected_indices[_selected_indices.size() - 1]
		else:
			_selected_indices.append(_selected_index)
	else:
		_selected_indices = [_selected_index]
	_sync_part_list_selection()
	_apply_selection_highlight()
	_sync_controls_from_selection()


func select_parts(indices: Array, primary := -1) -> void:
	if _session == null:
		return
	var count := part_count()
	var cleaned: Array[int] = []
	for idx in indices:
		var i := clampi(int(idx), 0, maxi(count - 1, 0))
		if not cleaned.has(i):
			cleaned.append(i)
	if cleaned.is_empty():
		cleaned.append(0)
	_selected_indices = cleaned
	_selected_index = cleaned[cleaned.size() - 1] if primary < 0 else clampi(primary, 0, maxi(count - 1, 0))
	if not _selected_indices.has(_selected_index):
		_selected_indices.append(_selected_index)
	_sync_part_list_selection()
	_apply_selection_highlight()
	_sync_controls_from_selection()


func selected_parts() -> PackedInt32Array:
	var out := PackedInt32Array()
	for idx in _selected_indices:
		out.append(idx)
	return out


func deselect_all_parts() -> void:
	_selected_indices.clear()
	_selected_index = -1
	_attach_existing_mode = false
	_move_mode = false
	_gizmo_dragging = false
	_sync_part_list_selection()
	_apply_selection_highlight()
	_update_hinge_guide()
	if _attachment_status != null:
		_attachment_status.text = "No part selected."


func has_part_selection() -> bool:
	return not _selected_indices.is_empty()


func apply_selected_scale(new_scale: Vector3) -> bool:
	if _session == null:
		return false
	var indices := _editable_selected_indices(true)
	var ok := _session.apply_edit(func(root: PartGene):
		for idx in indices:
			var g := _gene_by_index(root, idx)
			if g != null:
				g.scale = _valid_scale(new_scale)
	)
	if ok:
		_sync_controls_from_selection()
	return ok


func edit_selected_shape(part_type: StringName, extents: Vector3, density: float) -> bool:
	if _session == null:
		return false
	var indices := _editable_selected_indices(true)
	var ok := _session.apply_edit(func(root: PartGene):
		for idx in indices:
			var g := _gene_by_index(root, idx)
			if g != null and g.definition != null:
				var d := g.definition.duplicate(true) as PartDefinition
				d.part_type = part_type
				d.extents = _valid_extents(extents)
				d.density = maxf(density, 0.001)
				g.definition = d
	)
	if ok:
		_sync_controls_from_selection()
	return ok


func edit_selected_socket(parent_position: Vector3, hinge_axis: Vector3,
		rotation_deg = null) -> bool:
	if _session == null or _selected_index <= 0:
		return false
	var idx := _selected_index
	var ok := _session.apply_edit(func(root: PartGene):
		var g := _gene_by_index(root, idx)
		if g != null:
			if g.socket == null:
				g.socket = SocketDef.new()
			# The part's rest ORIENTATION lives in parent_attachment.basis (fold honors it), so a rotation
			# here actually turns the segment. rotation_deg == null → keep the current rotation (callers
			# that only move/re-hinge shouldn't zero it). child_anchor is preserved — it holds the proximal
			# end-offset that keeps a limb attached by its END, not its middle (wiping it snapped to centre).
			var basis: Basis = g.socket.parent_attachment.basis
			if rotation_deg != null:
				basis = Basis.from_euler((rotation_deg as Vector3) * (PI / 180.0))
			g.socket.parent_attachment = Transform3D(basis, parent_position)
			g.socket.hinge_axis = hinge_axis
	)
	if ok:
		_sync_controls_from_selection()
	return ok


func edit_selected_joint(amplitude: float, rest_angle: float, angle_min: float, angle_max: float) -> bool:
	if _session == null or _selected_index <= 0:
		return false
	var idx := _selected_index
	return _session.apply_edit(func(root: PartGene):
		var g := _gene_by_index(root, idx)
		if g != null:
			if g.joint == null:
				g.joint = JointDef.new()
			g.joint.amplitude = amplitude
			g.joint.rest_angle = rest_angle
			g.joint.angle_min = angle_min
			g.joint.angle_max = angle_max
	)


func clear_selected_joint() -> bool:
	if _session == null or _selected_index <= 0:
		return false
	var idx := _selected_index
	return _session.apply_edit(func(root: PartGene):
		var g := _gene_by_index(root, idx)
		if g != null:
			g.joint = null
	)


func set_selected_gait_phase(phase: float) -> bool:
	if _session == null or _selected_index <= 0:
		return false
	var idx := _selected_index
	return _session.apply_edit(func(root: PartGene):
		var root_gene := root
		var g := _gene_by_index(root, idx)
		if root_gene != null and g != null and g.socket != null:
			if root_gene.gait == null:
				root_gene.gait = GaitDef.new()
			root_gene.gait.assignments[g.socket.id] = wrapf(phase, 0.0, 1.0)
	)


# M44: author a per-part SpringDef (the M36 honest torsional spring). Reuses the joint-edit
# pattern; the rollout reads these authored values straight off the genome.
func edit_selected_spring(stiffness: float, damping: float, efficiency: float,
		enabled := true) -> bool:
	if _session == null or _selected_index < 0:
		return false
	var idx := _selected_index
	var ok := _session.apply_edit(func(root: PartGene):
		var g := _gene_by_index(root, idx)
		if g != null:
			if g.spring == null:
				g.spring = SpringDef.new()
			g.spring.enabled = enabled
			g.spring.stiffness = maxf(stiffness, 0.0)
			g.spring.damping = clampf(damping, 0.0, 0.95)
			g.spring.efficiency = clampf(efficiency, 0.0, 1.0)
			if enabled and not g.tags.has(&"spring"):
				g.tags.append(&"spring")
	)
	if ok:
		_sync_controls_from_selection()
	return ok


func clear_selected_spring() -> bool:
	if _session == null or _selected_index < 0:
		return false
	var idx := _selected_index
	return _session.apply_edit(func(root: PartGene):
		var g := _gene_by_index(root, idx)
		if g != null:
			g.spring = null
	)


func clear_selected_weapon() -> bool:
	if _session == null or _selected_index < 0:
		return false
	var idx := _selected_index
	return _session.apply_edit(func(root: PartGene):
		var g := _gene_by_index(root, idx)
		if g != null:
			g.weapon = null
	)


# M44: author a per-part WeaponDef (M35 anatomy + M43 edge alignment).
func edit_selected_weapon(kind: StringName, sharpness: float, penetration: float,
		impact: float, reach: float) -> bool:
	if _session == null or _selected_index < 0:
		return false
	var idx := _selected_index
	var ok := _session.apply_edit(func(root: PartGene):
		var g := _gene_by_index(root, idx)
		if g != null:
			if g.weapon == null:
				g.weapon = WeaponDef.new()
			g.weapon.kind = kind
			g.weapon.sharpness = maxf(sharpness, 0.0)
			g.weapon.penetration = maxf(penetration, 0.0)
			g.weapon.impact_multiplier = maxf(impact, 0.0)
			g.weapon.reach = maxf(reach, 0.0)
			if not g.tags.has(&"attack"):
				g.tags.append(&"attack")
	)
	if ok:
		_sync_controls_from_selection()
	return ok


# M44: expose locomotion_mode per creature (authored on the root gait) instead of inferring it
# from the gait-pattern string. "" restores the legacy pattern inference.
func set_root_locomotion_mode(mode: StringName) -> bool:
	if _session == null:
		return false
	return _session.apply_edit(func(root: PartGene):
		if root != null:
			if root.gait == null:
				root.gait = GaitDef.new()
			root.gait.locomotion_mode = mode
	)


# M55: author the per-creature steering / tear / assist drive on the root gait. These feed
# CpgController.Params via _controller_params_for_current_gait(), so they drive the live sim
# and Measure/Optimize rollouts.
func set_root_drive(turn_rate: float, tear_omega: float, traction_scale: float,
		posture_scale: float) -> bool:
	if _session == null:
		return false
	var ok := _session.apply_edit(func(root: PartGene):
		if root != null:
			if root.gait == null:
				root.gait = GaitDef.new()
			root.gait.turn_rate = turn_rate
			root.gait.tear_omega = maxf(tear_omega, 0.0)
			root.gait.traction_scale = maxf(traction_scale, 0.0)
			root.gait.posture_scale = maxf(posture_scale, 0.0)
	)
	if ok:
		_sync_controls_from_selection()
	return ok


# M55 viability readout (warn, never block): a creature with no vital organs is flagged dead by
# CombatResolver.durability, but the editor still lets you build/experiment.
func viability_summary() -> String:
	var g := current_root()
	if g == null:
		return "-"
	var d := CombatResolver.durability(g)
	var alive := bool(d.get("alive", true))
	return "%s  HP %.0f (vital %.0f)  atk %.1f" % [
		"alive" if alive else "⚠ no vital organs",
		float(d.get("hp", 0.0)), float(d.get("vital_hp", 0.0)), float(d.get("attack_power", 0.0))]


# M55: spar the editor creature against a chosen opponent (a built-in pregen by display name, or
# the flagship quadruped when unnamed). Returns the bout quip; prints the result to the status bar.
func spar_against(opponent_name := "") -> String:
	if _session == null:
		return "No creature to spar."
	var opponent := _opponent_root(opponent_name)
	if opponent == null:
		return "No opponent available."
	_status_label.text = "Sparring vs %s ..." % CreatureFlavor.name_for(opponent)
	var bout := await AdversarialBout.run_bout(
		GenomeSnapshot.deep_copy(_session.root()), opponent, get_tree())
	if not bool(bout.get("ok", false)):
		var msg := "Spar failed: %s" % String(bout.get("error", "non-finite"))
		_status_label.text = msg
		return msg
	var quip := String(bout.get("quip", ""))
	_status_label.text = "%s  (you %+.1f, them %+.1f, winner %s)" % [
		quip, float(bout.get("a_score", 0.0)), float(bout.get("b_score", 0.0)),
		String(bout.get("winner", &"draw"))]
	return quip


func _opponent_root(opponent_name: String) -> PartGene:
	for card in PartCatalog.built_in_cards():
		if card != null and card.root != null and (opponent_name == "" or card.display_name == opponent_name):
			# Skip sparring a creature against itself when unnamed: prefer a different pregen.
			if opponent_name == "" and card.display_name == _active_card_name:
				continue
			return GenomeSnapshot.deep_copy(card.root)
	return PartCatalog.make_flagship_quadruped()


# ============================================================================
# M56 — interactive nub placement, two-point attach, in-viewport hinge editor
# ============================================================================

func set_place_nub_mode(on: bool) -> void:
	_place_nub_mode = on
	if on:
		_disarm_palette()
		_attach_existing_mode = false
		_status_label.text = "Place Nub: click a body part to drop an attachment nub (Esc to stop)."
	elif _status_label != null and _status_label.text.begins_with("Place Nub"):
		_status_label.text = "Nub placement off."


func place_nub_mode() -> bool:
	return _place_nub_mode


# M56: drop a user attachment nub at a world hit on `part_index`, converting the hit point + normal
# into the part's local frame and recording it via AttachLogic (serialized on the genome).
func place_nub_at(part_index: int, world_point: Vector3, world_normal := Vector3.UP) -> bool:
	if _session == null:
		return false
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	if part_index < 0 or part_index >= fold["parts"].size():
		return false
	var xform: Transform3D = fold["parts"][part_index].xform
	var local_pos: Vector3 = xform.affine_inverse() * world_point
	var local_normal: Vector3 = (xform.basis.inverse() * world_normal).normalized()
	if local_normal.is_zero_approx():
		local_normal = Vector3.UP
	var ok := _session.apply_edit(func(root: PartGene):
		var g := _gene_by_index(root, part_index)
		if g != null:
			AttachLogic.add_nub(g, local_pos, local_normal)
	)
	if ok:
		_status_label.text = "Placed a nub on part %02d (%d total)." % [part_index, nub_count(part_index)]
	return ok


func nub_count(part_index: int) -> int:
	var g := _gene_by_index(_session.root(), part_index) if _session != null else null
	return 0 if g == null else g.attach_points.size()


# M56: weld the selected part onto a nub on `parent_index`, consuming the nub (Principle 19 end-meet).
# An actuating piece (locomotor/leg/jointed) welds with a powered hinge and auto-opens the hinge
# editor (rule 4); a passive piece welds rigidly.
func attach_selected_to_nub(parent_index: int, nub_id: StringName) -> bool:
	if _session == null or _selected_index <= 0:
		_on_edit_rejected("Select a non-root part before attaching it to a nub.")
		return false
	var moving_index := _selected_index
	var moving_path := _path_to_index(_session.root(), moving_index)
	var parent_path := _path_to_index(_session.root(), parent_index)
	if moving_path.is_empty() or (parent_index > 0 and parent_path.is_empty()):
		return false
	if _path_starts_with(parent_path, moving_path):
		_on_edit_rejected("Cannot attach a part into its own subtree.")
		return false
	# The target must actually carry the nub (else _detach_by_index would orphan the moving part).
	var parent_pre := _gene_by_index(_session.root(), parent_index)
	var has_nub := false
	if parent_pre != null:
		for ap in parent_pre.attach_points:
			if ap != null and ap.id == nub_id:
				has_nub = true
				break
	if not has_nub:
		_on_edit_rejected("No nub '%s' on the target part." % String(nub_id))
		return false
	var moving_gene := _gene_by_index(_session.root(), moving_index)
	var is_actuating := moving_gene != null and (
			moving_gene.tags.has(&"locomotor") or moving_gene.tags.has(&"leg")
			or moving_gene.joint != null)
	# An actuating piece welds with a powered hinge; the weld lands a hinge iff actuating.
	# (Computed here, not in the closure — GDScript lambdas don't write back to outer locals.)
	var landed_hinge := is_actuating
	var ok := _session.apply_edit(func(root: PartGene):
		var parent := _gene_by_path(root, parent_path)
		var moving := _detach_by_index(root, moving_index)
		if parent == null or moving == null:
			return
		var proximal := moving.definition.extents.y if moving.definition != null else 0.0
		var hinge_axis := Vector3.RIGHT if is_actuating else Vector3.ZERO
		if AttachLogic.consume_nub(parent, nub_id, moving, proximal, hinge_axis):
			moving.socket_id = nub_id
	)
	if not ok:
		_on_edit_rejected("Could not weld to nub '%s'." % String(nub_id))
		return false
	_selected_index = _index_for_socket_id(_session.root(), nub_id)
	if _selected_index < 0:
		_selected_index = maxi(part_count() - 1, 0)
	_selected_indices = [_selected_index]
	_attach_existing_mode = false
	_sync_part_list_selection()
	_apply_selection_highlight()
	_sync_controls_from_selection()
	_status_label.text = "Welded to nub '%s'%s." % [String(nub_id), " (hinged)" if landed_hinge else ""]
	# Rule 4: open the hinge editor only when an ACTUATING piece landed on a hinge.
	if AttachLogic.opens_hinge_edit(is_actuating, landed_hinge):
		open_hinge_editor(_selected_index)
	return true


func is_hinge_editing() -> bool:
	return _hinge_editing


func hinge_editor_index() -> int:
	return _hinge_edit_index


# M56: enter the modal hinge editor on `index` (or the current selection). Creates a default hinge
# on a rigid part so there is always something to edit (the explicit "Edit Hinge" path).
func open_hinge_editor(index := -1) -> bool:
	if _session == null:
		return false
	var idx := index if index >= 0 else _selected_index
	if idx <= 0:
		_on_edit_rejected("Select a non-root part to edit its hinge.")
		return false
	if _selected_index != idx:
		select_part(idx)
	var g := _gene_by_index(_session.root(), idx)
	if g == null or g.socket == null:
		return false
	if g.socket.hinge_axis.is_zero_approx():
		edit_selected_socket(g.socket.parent_attachment.origin, Vector3.RIGHT)
	g = _gene_by_index(_session.root(), idx)
	if g != null and g.joint == null:
		edit_selected_joint(1.0, 0.0, -1.1, 1.1)
	_hinge_editing = true
	_hinge_edit_index = idx
	_hinge_drag_handle = 0
	_focus_camera_on_index(idx)
	_update_hinge_editor_gizmo()
	_status_label.text = "Hinge editor: drag a limit handle to set the range; Enter or empty-click to finish."
	return true


func close_hinge_editor() -> void:
	var was := _hinge_editing
	_hinge_editing = false
	_hinge_edit_index = -1
	_hinge_drag_handle = 0
	if _hinge_editor_node != null:
		_hinge_editor_node.visible = false
		_hinge_editor_node.mesh = null
	if was and _status_label != null and _status_label.text.begins_with("Hinge editor"):
		_status_label.text = "Hinge committed."


func hinge_editor_set_limits(angle_min: float, angle_max: float) -> bool:
	if not _hinge_editing or _hinge_edit_index <= 0:
		return false
	if _selected_index != _hinge_edit_index:
		select_part(_hinge_edit_index)
	var g := _gene_by_index(_session.root(), _hinge_edit_index)
	var rest := g.joint.rest_angle if g != null and g.joint != null else 0.0
	var amp := g.joint.amplitude if g != null and g.joint != null else 1.0
	var lo := minf(angle_min, angle_max)
	var hi := maxf(angle_min, angle_max)
	var ok := edit_selected_joint(amp, clampf(rest, lo, hi), lo, hi)
	_update_hinge_editor_gizmo()
	return ok


func hinge_editor_set_axis(axis: Vector3) -> bool:
	if not _hinge_editing or _hinge_edit_index <= 0:
		return false
	if _selected_index != _hinge_edit_index:
		select_part(_hinge_edit_index)
	var g := _gene_by_index(_session.root(), _hinge_edit_index)
	if g == null or g.socket == null:
		return false
	var ok := edit_selected_socket(g.socket.parent_attachment.origin, axis)
	_update_hinge_editor_gizmo()
	return ok


func _focus_camera_on_index(idx: int) -> void:
	if _session == null:
		return
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	if idx >= 0 and idx < fold["parts"].size():
		_cam_target = fold["parts"][idx].xform.origin
		_update_camera()


# Geometry of the hinge under edit, in world space: {center, axis, radial(rest direction)}.
func _hinge_geometry() -> Dictionary:
	if _session == null or _hinge_edit_index <= 0:
		return {}
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	if _hinge_edit_index >= fold["parts"].size():
		return {}
	var part = fold["parts"][_hinge_edit_index]
	var axis: Vector3 = part.hinge_axis
	if axis.length() <= 1e-4:
		return {}
	var world_axis: Vector3 = (part.xform.basis * axis.normalized()).normalized()
	var radial := Vector3.DOWN
	if absf(radial.dot(world_axis)) > 0.9:
		radial = Vector3.FORWARD
	radial = (radial - world_axis * radial.dot(world_axis)).normalized()
	return {"center": part.xform.origin, "axis": world_axis, "radial": radial}


func _hinge_radius() -> float:
	if _session == null:
		return 0.4
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	if _hinge_edit_index >= 0 and _hinge_edit_index < fold["parts"].size():
		return maxf(fold["parts"][_hinge_edit_index].world_aabb.size.length() * 0.4, 0.25)
	return 0.4


func _hinge_handle_screen_positions() -> Dictionary:
	var info := _hinge_geometry()
	if info.is_empty() or _camera == null:
		return {}
	var g := _gene_by_index(_session.root(), _hinge_edit_index)
	var a0 := g.joint.angle_min if g != null and g.joint != null else -0.7
	var a1 := g.joint.angle_max if g != null and g.joint != null else 0.7
	var center: Vector3 = info["center"]
	var axis: Vector3 = info["axis"]
	var spoke: Vector3 = info["radial"] * _hinge_radius()
	var out := {}
	var pmin := center + spoke.rotated(axis, a0)
	var pmax := center + spoke.rotated(axis, a1)
	if not _camera.is_position_behind(pmin):
		out["min"] = _camera.unproject_position(pmin)
	if not _camera.is_position_behind(pmax):
		out["max"] = _camera.unproject_position(pmax)
	return out


func _hinge_angle_from_mouse(pos: Vector2) -> float:
	var info := _hinge_geometry()
	if info.is_empty() or _camera == null:
		return NAN
	var center: Vector3 = info["center"]
	var axis: Vector3 = info["axis"]
	var radial: Vector3 = info["radial"]
	var vp := _to_viewport_pos(pos)
	var origin := _camera.project_ray_origin(vp)
	var dir := _camera.project_ray_normal(vp)
	var denom := dir.dot(axis)
	if absf(denom) < 1e-5:
		return NAN
	var t := (center - origin).dot(axis) / denom
	if t < 0.0:
		return NAN
	var hit := origin + dir * t
	var v := hit - center
	v = v - axis * v.dot(axis)
	if v.length() < 1e-4:
		return NAN
	var vn := v.normalized()
	return atan2(radial.cross(vn).dot(axis), radial.dot(vn))


func _hinge_editor_press(pos: Vector2) -> void:
	var handles := _hinge_handle_screen_positions()
	if handles.is_empty():
		close_hinge_editor()
		return
	var vp := _to_viewport_pos(pos)
	var d_min: float = handles["min"].distance_to(vp) if handles.has("min") else INF
	var d_max: float = handles["max"].distance_to(vp) if handles.has("max") else INF
	if minf(d_min, d_max) > 48.0:
		close_hinge_editor()
		return
	_hinge_drag_handle = -1 if d_min <= d_max else 1


func _hinge_editor_drag(pos: Vector2) -> void:
	if _hinge_drag_handle == 0:
		return
	var angle := _hinge_angle_from_mouse(pos)
	if is_nan(angle):
		return
	var g := _gene_by_index(_session.root(), _hinge_edit_index)
	if g == null or g.joint == null:
		return
	var amin := g.joint.angle_min
	var amax := g.joint.angle_max
	if _hinge_drag_handle < 0:
		amin = clampf(angle, -PI, amax - 0.05)
	else:
		amax = clampf(angle, amin + 0.05, PI)
	hinge_editor_set_limits(amin, amax)


func _update_hinge_editor_gizmo() -> void:
	if _hinge_editor_node == null:
		return
	if not _hinge_editing:
		_hinge_editor_node.visible = false
		_hinge_editor_node.mesh = null
		return
	var info := _hinge_geometry()
	if info.is_empty():
		_hinge_editor_node.visible = false
		return
	var center: Vector3 = info["center"]
	var axis: Vector3 = info["axis"]
	var radial: Vector3 = info["radial"]
	var radius := _hinge_radius()
	var g := _gene_by_index(_session.root(), _hinge_edit_index)
	var a0 := g.joint.angle_min if g != null and g.joint != null else -0.7
	var a1 := g.joint.angle_max if g != null and g.joint != null else 0.7
	var rest := g.joint.rest_angle if g != null and g.joint != null else 0.0
	var spoke := radial * radius
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var steps := 20
	var prev := center + spoke.rotated(axis, a0)
	for s in range(1, steps + 1):
		var ang := lerpf(a0, a1, float(s) / float(steps))
		var nxt := center + spoke.rotated(axis, ang)
		mesh.surface_add_vertex(prev)
		mesh.surface_add_vertex(nxt)
		prev = nxt
	mesh.surface_add_vertex(center)
	mesh.surface_add_vertex(center + spoke.rotated(axis, a0))
	mesh.surface_add_vertex(center)
	mesh.surface_add_vertex(center + spoke.rotated(axis, a1))
	mesh.surface_add_vertex(center + (spoke * 0.6).rotated(axis, rest))
	mesh.surface_add_vertex(center + (spoke * 1.15).rotated(axis, rest))
	var r2 := axis.cross(radial).normalized() * (radius * 0.35)
	var r1 := radial * (radius * 0.35)
	var ring_steps := 16
	var rp := center + r1
	for s in range(1, ring_steps + 1):
		var ang := TAU * float(s) / float(ring_steps)
		var rn := center + r1 * cos(ang) + r2 * sin(ang)
		mesh.surface_add_vertex(rp)
		mesh.surface_add_vertex(rn)
		rp = rn
	mesh.surface_add_vertex(center - axis * radius)
	mesh.surface_add_vertex(center + axis * radius)
	mesh.surface_end()
	_hinge_editor_node.mesh = mesh
	_hinge_editor_node.visible = true


# M56: build the half-sphere nub markers at each part's authored attach points.
func _rebuild_nubs() -> void:
	if _world == null:
		return
	if _nub_node != null:
		_nub_node.queue_free()
		_nub_node = null
	if _session == null:
		return
	var has_any := false
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	for p in fold["parts"]:
		var g := _gene_by_index(_session.root(), int(p.index))
		if g != null and not g.attach_points.is_empty():
			has_any = true
			break
	if not has_any:
		return
	_nub_node = Node3D.new()
	_nub_node.name = "AttachNubs"
	_world.add_child(_nub_node)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.85, 0.35, 0.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for p in fold["parts"]:
		var g := _gene_by_index(_session.root(), int(p.index))
		if g == null:
			continue
		for ap in g.attach_points:
			if ap == null:
				continue
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.05
			sm.height = 0.1
			sm.is_hemisphere = true
			mi.mesh = sm
			mi.material_override = mat
			mi.transform = p.xform * ap.local_pose
			mi.set_meta("part_index", int(p.index))
			mi.set_meta("nub_id", ap.id)
			_nub_node.add_child(mi)


func _pick_nub(at_position: Vector2) -> Dictionary:
	if _nub_node == null or _camera == null:
		return {}
	var click_vp := _to_viewport_pos(at_position)
	var best := {}
	var best_d := NUB_PICK_PX
	for child in _nub_node.get_children():
		var mi := child as MeshInstance3D
		if mi == null or _camera.is_position_behind(mi.global_position):
			continue
		var d := _camera.unproject_position(mi.global_position).distance_to(click_vp)
		if d < best_d:
			best_d = d
			best = {"part_index": int(mi.get_meta("part_index", -1)),
					"nub_id": StringName(mi.get_meta("nub_id", &"")),
					"world_pos": mi.global_position}
	return best


# Approximate outward surface normal at a world hit (direction from the part centroid).
func _surface_normal_at(part_index: int, world_point: Vector3) -> Vector3:
	if _session == null:
		return Vector3.UP
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	if part_index < 0 or part_index >= fold["parts"].size():
		return Vector3.UP
	var origin: Vector3 = fold["parts"][part_index].xform.origin
	var n := world_point - origin
	return n.normalized() if not n.is_zero_approx() else Vector3.UP


# ============================================================================
# M57 — in-editor LLM co-pilot chat dock (drives EditorCopilot through EditSession)
# ============================================================================

func _build_copilot_dock(parent: VBoxContainer) -> void:
	_copilot_scope_chip = Label.new()
	_copilot_scope_chip.text = "▣ editing: (none)"
	_copilot_scope_chip.tooltip_text = "The creature the co-pilot's edits target (scope chip)."
	parent.add_child(_copilot_scope_chip)
	_copilot_scope = CheckBox.new()
	_copilot_scope.text = "this is about the creature in the editor"
	_copilot_scope.button_pressed = true
	_copilot_scope.tooltip_text = "Checked = edits target the editor creature (scope=current). " \
			+ "Unchecked = the model must name a target before any mutation is allowed."
	_copilot_scope.toggled.connect(func(_p): _update_copilot_scope_chip())
	parent.add_child(_copilot_scope)
	_copilot_log = RichTextLabel.new()
	_copilot_log.bbcode_enabled = true
	_copilot_log.scroll_following = true
	_copilot_log.custom_minimum_size = Vector2(0, 150)
	parent.add_child(_copilot_log)
	_copilot_preview_label = Label.new()
	_copilot_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_copilot_preview_label)
	var actions := HBoxContainer.new()
	_copilot_apply_button = _button("Apply", "Apply the previewed edit through EditSession (undoable).",
			copilot_apply)
	_copilot_discard_button = _button("Discard", "Discard the previewed edit.", copilot_discard)
	_copilot_apply_button.disabled = true
	_copilot_discard_button.disabled = true
	actions.add_child(_copilot_apply_button)
	actions.add_child(_copilot_discard_button)
	actions.add_child(_button("↶ Undo", "Undo the last applied edit.", _copilot_undo))
	parent.add_child(actions)
	var input_row := HBoxContainer.new()
	_copilot_input = LineEdit.new()
	_copilot_input.placeholder_text = "Ask or instruct… (needs `ollama serve`)"
	_copilot_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copilot_input.text_submitted.connect(func(_t): _on_copilot_send())
	input_row.add_child(_copilot_input)
	input_row.add_child(_button("Send", "Send the message to the co-pilot.", _on_copilot_send))
	parent.add_child(input_row)


func _on_copilot_send() -> void:
	if _copilot_input == null:
		return
	var msg := _copilot_input.text
	_copilot_input.text = ""
	await copilot_send(msg)


func _copilot_model() -> String:
	# Default to the qwen3-coder-next:cloud coding model for everything; the Settings popup can still
	# override it, but there's no bottom-bar picker to fiddle (Cole's request).
	var m := String(get_setting(&"llm_model"))
	if m != "":
		return m
	return LlmDirector.DEFAULT_MODEL


# Full round-trip: build the tool-use prompt + read context, call Ollama (which returns a parsed
# JSON tool-call), then dispatch it through the same trust gate as the injection path.
func last_measured() -> Dictionary:
	return _last_measured


func copilot_send(message: String) -> void:
	if message.strip_edges() == "":
		return
	_copilot_say("you", message)
	# Diagnostic questions ("why does it explode / fall / not walk") are answered locally from the
	# live data — deterministic and useful even with a weak/absent model (Principle 23).
	var low := message.to_lower()
	if low.contains("why") or low.contains("explod") or low.contains("blow") \
			or low.contains("unstable") or low.contains("fall") or low.contains("walk") \
			or low.contains("move") or low.contains("stuck") or low.contains("diagnos"):
		_copilot_say("co-pilot", EditorCopilot.diagnose(self))
		return
	var model := _copilot_model()
	if model == "":
		_copilot_say("co-pilot", "No model selected — pick one in Settings (pause menu) or the LLM picker.")
		return
	var sys := EditorCopilot.build_system_prompt()
	var user := EditorCopilot.build_user_prompt(EditorCopilot.read_context(self), message)
	_copilot_say("co-pilot", "thinking…")
	var call := await OllamaClient.chat(get_tree(), model, sys, user)
	if call.is_empty():
		_copilot_say("co-pilot", "No usable response (is `ollama serve` running?).")
		return
	copilot_handle_call(call)


# Test/injection entry: parse a raw model string into a tool-call, then dispatch.
func copilot_handle_response(text: String) -> Dictionary:
	return copilot_handle_call(EditorCopilot.parse_tool_call(text))


# Core dispatch: queries answer immediately (read-only); mutations are gated behind a will-do
# preview + Apply/Discard. The scope checkbox is authoritative for the editor creature.
func copilot_handle_call(call: Dictionary) -> Dictionary:
	if call.is_empty() or not call.has("tool"):
		_copilot_say("co-pilot", "I couldn't parse a tool call from that.")
		return {}
	if _copilot_scope != null:
		call["scope"] = "current" if _copilot_scope.button_pressed else String(call.get("scope", "global"))
	if not EditorCopilot.is_mutation(call):
		var res := EditorCopilot.execute(self, call)
		_copilot_say("co-pilot", String(res.get("answer", "(no answer)")))
		return res
	_copilot_pending_call = call.duplicate(true)
	var prev := EditorCopilot.preview(self, call)
	_copilot_say("co-pilot", "Will do: %s" % prev)
	_copilot_set_preview("Will do: %s — Apply or Discard?" % prev, true)
	return call


func copilot_apply() -> Dictionary:
	if _copilot_pending_call.is_empty():
		return {}
	var res := EditorCopilot.execute(self, _copilot_pending_call)
	if bool(res.get("ok", false)):
		_copilot_say("co-pilot", "Applied: %s   [↶ undo]" % EditorCopilot.preview(self, _copilot_pending_call))
	elif bool(res.get("needs_target", false)):
		_copilot_say("co-pilot", String(res.get("message", "Out of scope — name the target creature first.")))
	else:
		_copilot_say("co-pilot", "Couldn't apply: %s" % String(res.get("error", "rejected")))
	_copilot_pending_call = {}
	_copilot_set_preview("", false)
	return res


func copilot_discard() -> void:
	_copilot_pending_call = {}
	_copilot_set_preview("", false)
	_copilot_say("co-pilot", "Discarded.")


func copilot_has_pending() -> bool:
	return not _copilot_pending_call.is_empty()


func _copilot_undo() -> void:
	if undo():
		_copilot_say("co-pilot", "Undone.")
	else:
		_copilot_say("co-pilot", "Nothing to undo.")


func _copilot_say(who: String, text: String) -> void:
	if _copilot_log == null:
		return
	var color := "9cf" if who == "you" else "fc9"
	_copilot_log.append_text("[color=#%s]%s:[/color] %s\n" % [color, who, text])


func _copilot_set_preview(text: String, has_pending: bool) -> void:
	if _copilot_preview_label != null:
		_copilot_preview_label.text = text
	if _copilot_apply_button != null:
		_copilot_apply_button.disabled = not has_pending
	if _copilot_discard_button != null:
		_copilot_discard_button.disabled = not has_pending


func _update_copilot_scope_chip() -> void:
	if _copilot_scope_chip == null:
		return
	var scoped := _copilot_scope == null or _copilot_scope.button_pressed
	_copilot_scope_chip.text = ("▣ editing: %s" % _active_card_name) if scoped \
			else "▢ no editor scope — name a target"


# M57 (B9): the Settings popup the model picker moves into (opened from the pause menu).
func _build_settings_popup() -> void:
	_settings_popup = PopupPanel.new()
	_settings_popup.name = "EditorSettingsPopup"
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	_settings_popup.add_child(box)
	box.add_child(_heading("Settings"))
	var model_row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Co-pilot model"
	lbl.custom_minimum_size = Vector2(110, 0)
	model_row.add_child(lbl)
	_settings_llm_models = OptionButton.new()
	_settings_llm_models.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_llm_models.tooltip_text = "Ollama model used by the in-editor co-pilot."
	_settings_llm_models.item_selected.connect(func(i):
		set_setting(&"llm_model", _settings_llm_models.get_item_text(i)))
	model_row.add_child(_settings_llm_models)
	box.add_child(model_row)
	box.add_child(_button("Refresh models", "Query `ollama serve` for installed models.",
			_refresh_settings_models))
	box.add_child(_button("Close", "Close settings.", func(): _settings_popup.hide()))
	add_child(_settings_popup)


func _refresh_settings_models() -> void:
	if _settings_llm_models == null:
		return
	var models := await OllamaClient.list_models(get_tree())
	_settings_llm_models.clear()
	if models.is_empty():
		_settings_llm_models.add_item("(no models — is ollama running?)")
		return
	for name in models:
		_settings_llm_models.add_item(String(name))
	var saved := String(get_setting(&"llm_model"))
	for i in models.size():
		if String(models[i]) == saved or (saved == "" and String(models[i]) == LlmDirector.DEFAULT_MODEL):
			_settings_llm_models.select(i)
			set_setting(&"llm_model", String(models[i]))
			break


func open_settings() -> void:
	if _settings_popup != null:
		_settings_popup.popup_centered()


# ============================================================================
# M58 — display layer (all display-only; never touches physics/score, Principle 22)
# ============================================================================

func _build_display_panel(parent: VBoxContainer) -> void:
	var t1 := HBoxContainer.new()
	var fx := CheckBox.new()
	fx.text = "Force x-ray"
	fx.tooltip_text = "FUN-1: draw torque (cyan) + contact (green) arrows during a sim."
	fx.toggled.connect(set_force_xray)
	t1.add_child(fx)
	var wf := CheckBox.new()
	wf.text = "Wireframe"
	wf.tooltip_text = "Render the viewport in wireframe."
	wf.toggled.connect(set_wireframe)
	t1.add_child(wf)
	parent.add_child(t1)
	var t2 := HBoxContainer.new()
	var gh := CheckBox.new()
	gh.text = "Ghost"
	gh.tooltip_text = "FUN-2: show the last recorded champion as a translucent ancestor following its path."
	gh.toggled.connect(set_ghost_enabled)
	t2.add_child(gh)
	var ov := CheckBox.new()
	ov.text = "Overlays"
	ov.tooltip_text = "Floating per-part tags (spring/weapon/armor/foot/radial)."
	ov.toggled.connect(set_overlay_gizmos)
	t2.add_child(ov)
	var sn := CheckBox.new()
	sn.text = "Sound"
	sn.tooltip_text = "FUN-3: sonify the gait (pitch from drive activity)."
	sn.toggled.connect(set_sonification_enabled)
	t2.add_child(sn)
	parent.add_child(t2)
	parent.add_child(_heading("Palette"))
	var pal_row := HBoxContainer.new()
	_palette_base_btn = ColorPickerButton.new()
	_palette_base_btn.color = Color(0.62, 0.47, 0.74)
	_palette_base_btn.custom_minimum_size = Vector2(56, 0)
	_palette_base_btn.tooltip_text = "Base skin colour."
	_palette_base_btn.color_changed.connect(set_palette_base)
	pal_row.add_child(_palette_base_btn)
	_palette_secondary_btn = ColorPickerButton.new()
	_palette_secondary_btn.color = Color(0.4, 0.6, 0.8)
	_palette_secondary_btn.custom_minimum_size = Vector2(56, 0)
	_palette_secondary_btn.tooltip_text = "Secondary skin colour (alternating parts)."
	_palette_secondary_btn.color_changed.connect(set_palette_secondary)
	pal_row.add_child(_palette_secondary_btn)
	_pattern_option = OptionButton.new()
	for pat in ["flat", "glossy"]:
		_pattern_option.add_item(pat)
	_pattern_option.item_selected.connect(func(i): set_palette_pattern(_pattern_option.get_item_text(i)))
	pal_row.add_child(_pattern_option)
	pal_row.add_child(_button("Randomize", "Randomize the palette.", randomize_palette))
	parent.add_child(pal_row)
	parent.add_child(_heading("Mutation brush"))
	var brush_row := HBoxContainer.new()
	brush_row.add_child(_button("Longer", "Lengthen the selected part(s).",
			func(): mutation_brush(&"lengthen")))
	brush_row.add_child(_button("Thicker", "Thicken the selected part(s).",
			func(): mutation_brush(&"thicken")))
	brush_row.add_child(_button("Shrink", "Shrink the selected part(s).",
			func(): mutation_brush(&"shrink")))
	brush_row.add_child(_button("Mirror", "Mirror the selected subtree across X.",
			func(): mutation_brush(&"mirror_x")))
	parent.add_child(brush_row)
	parent.add_child(_heading("Stat card"))
	_stat_card_label = RichTextLabel.new()
	_stat_card_label.bbcode_enabled = true
	_stat_card_label.fit_content = true
	_stat_card_label.custom_minimum_size = Vector2(0, 84)
	parent.add_child(_stat_card_label)


# --- Force x-ray (FUN-1) ---

func set_force_xray(on: bool) -> void:
	_force_xray = on
	if _force_xray_node != null and not on:
		_force_xray_node.visible = false
		_force_xray_node.mesh = null


func force_xray_enabled() -> bool:
	return _force_xray


func _tick_force_xray() -> void:
	if not _force_xray or _force_xray_node == null:
		return
	if _sim_viewer == null or not _sim_viewer.has_method("controller"):
		_force_xray_node.visible = false
		return
	var ctrl = _sim_viewer.call("controller")
	if ctrl == null or not ctrl.has_method("force_xray"):
		_force_xray_node.visible = false
		return
	var xray: Array = ctrl.call("force_xray")
	var cmds: Array = ctrl.call("last_commands") if ctrl.has_method("last_commands") else []
	var traction_by_index := {}
	for c in cmds:
		traction_by_index[int(c.get("index", -1))] = float(c.get("traction", 0.0))
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for e in xray:
		var at: Vector3 = e.get("at", Vector3.ZERO)
		var torque: Vector3 = e.get("torque", Vector3.ZERO)
		mesh.surface_set_color(Color(0.2, 0.9, 1.0))                 # torque = cyan
		mesh.surface_add_vertex(at)
		mesh.surface_add_vertex(at + torque.limit_length(3.0) * 0.12)
		var tr := float(traction_by_index.get(int(e.get("index", -1)), 0.0))
		if tr > 0.001:
			mesh.surface_set_color(Color(0.3, 1.0, 0.4))            # contact/traction = green
			mesh.surface_add_vertex(at)
			mesh.surface_add_vertex(at + Vector3.UP * minf(tr * 0.5, 0.4))
	mesh.surface_end()
	_force_xray_node.mesh = mesh
	_force_xray_node.visible = xray.size() > 0


# Live "tension sensors": the per-joint torque the controller applied this frame. Shows REPLAY vs live and
# the strongest joints. Gated on the section being expanded (is_visible_in_tree) so it costs nothing folded.
func _tick_tension() -> void:
	if _tension_label == null or not _tension_label.is_visible_in_tree():
		return
	if _sim_viewer == null or not _sim_viewer.has_method("controller"):
		if not is_simulating():
			_tension_label.text = "Press Watch it walk to see live joint torques."
		return
	var ctrl = _sim_viewer.call("controller")
	if ctrl == null or not ctrl.has_method("joint_tensions"):
		return
	var tens: Dictionary = ctrl.call("joint_tensions")
	if tens.is_empty():
		_tension_label.text = "(no actuated joints reporting yet)"
		return
	var rows: Array = []
	for pidx in tens:
		rows.append([int(pidx), float(tens[pidx])])
	rows.sort_custom(func(a, b): return absf(a[1]) > absf(b[1]))
	var replaying: bool = ctrl.has_method("is_replaying") and bool(ctrl.call("is_replaying"))
	var lines: Array[String] = ["mode: %s" % ("REPLAY (baked clip)" if replaying else "live tracker")]
	var shown := mini(rows.size(), 8)
	for i in shown:
		lines.append("joint %d:  %+7.1f" % [int(rows[i][0]), float(rows[i][1])])
	if rows.size() > shown:
		lines.append("... +%d more" % (rows.size() - shown))
	_tension_label.text = "\n".join(lines)


# --- Wireframe ---

func set_wireframe(on: bool) -> void:
	_wireframe = on
	set_setting(&"wireframe", on)
	if on:
		RenderingServer.set_debug_generate_wireframes(true)
	if _viewport != null:
		_viewport.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME if on else Viewport.DEBUG_DRAW_DISABLED


func wireframe_enabled() -> bool:
	return _wireframe


# --- Palette (B7) ---

func set_palette_base(c: Color) -> void:
	_palette_data["base"] = "#" + c.to_html(false)
	_apply_palette_live()


func set_palette_secondary(c: Color) -> void:
	_palette_data["secondary"] = "#" + c.to_html(false)
	_apply_palette_live()


func set_palette_pattern(pattern: String) -> void:
	_palette_data["pattern"] = pattern
	_apply_palette_live()


func randomize_palette() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var base := Color.from_hsv(rng.randf(), 0.55, 0.85)
	var sec := Color.from_hsv(rng.randf(), 0.55, 0.85)
	_palette_data["base"] = "#" + base.to_html(false)
	_palette_data["secondary"] = "#" + sec.to_html(false)
	if _palette_base_btn != null:
		_palette_base_btn.color = base
	if _palette_secondary_btn != null:
		_palette_secondary_btn.color = sec
	_apply_palette_live()


func creature_palette() -> Dictionary:
	return _palette_data


func _apply_palette_live() -> void:
	if _skin_node != null:
		SkinBuilder.apply_palette(_skin_node, _palette_data)


func _sync_palette_controls() -> void:
	if _palette_base_btn != null and _palette_data.has("base"):
		_palette_base_btn.color = Color.from_string(String(_palette_data["base"]), _palette_base_btn.color)
	if _palette_secondary_btn != null and _palette_data.has("secondary"):
		_palette_secondary_btn.color = Color.from_string(
				String(_palette_data["secondary"]), _palette_secondary_btn.color)


# --- Fossil ghost (FUN-2) ---

func record_fossil(measured: Dictionary) -> void:
	if _session == null or measured.is_empty() or not bool(measured.get("ok", false)):
		return
	var traj: Array = measured.get("trajectory", [])
	_fossils.record(_fossils.count(), _session.root(), traj, float(measured.get("forward", 0.0)))
	_ghost_fossil_index = _fossils.count() - 1


func fossil_count() -> int:
	return _fossils.count()


func set_ghost_enabled(on: bool) -> void:
	_ghost_enabled = on
	if _ghost_node != null:
		_ghost_node.queue_free()
		_ghost_node = null
	if not on:
		return
	if _fossils.count() == 0:
		_ghost_enabled = false
		if _status_label != null:
			_status_label.text = "No fossils yet — Measure or Optimize first to record a champion."
		return
	_ghost_fossil_index = _fossils.count() - 1
	var ghost_root := _fossils.ghost_genome(_ghost_fossil_index)
	if ghost_root == null or _world == null:
		_ghost_enabled = false
		return
	var ghost_mat := StandardMaterial3D.new()
	ghost_mat.albedo_color = Color(0.5, 0.8, 1.0, 0.32)
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_node = CreatureAssembler.build(ghost_root, Transform3D.IDENTITY, ghost_mat)
	_world.add_child(_ghost_node)
	_ghost_t = 0.0


func _tick_ghost() -> void:
	if not _ghost_enabled or _ghost_node == null or _ghost_fossil_index < 0:
		return
	_ghost_t = fmod(_ghost_t + 0.004, 1.0)
	_ghost_node.position = _fossils.replay_position(_ghost_fossil_index, _ghost_t)


# --- Mutation brush (FUN-5) ---

func mutation_brush(op: StringName, factor := 1.25) -> bool:
	if _session == null:
		return false
	var indices := _editable_selected_indices(true)
	if indices.is_empty():
		return false
	var ok := _session.apply_edit(func(root: PartGene):
		for idx in indices:
			var g := _gene_by_index(root, idx)
			if g != null:
				MutationBrush.paint(g, op, factor)
	)
	if ok:
		pump_scores_blocking()
		_sync_controls_from_selection()
		_status_label.text = "Brush: %s on %d part(s)." % [String(op), indices.size()]
	return ok


# --- Gait sonification (FUN-3) ---

func set_sonification_enabled(on: bool) -> void:
	_sonify = on
	if not on:
		if _sonify_player != null:
			_sonify_player.stop()
		return
	if _sonify_player == null:
		_sonify_player = AudioStreamPlayer.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.1
		_sonify_player.stream = gen
		add_child(_sonify_player)
	_sonify_player.play()
	_sonify_playback = _sonify_player.get_stream_playback()


func sonification_enabled() -> bool:
	return _sonify


func _tick_sonification() -> void:
	if not _sonify or _sonify_playback == null or _sim_viewer == null:
		return
	if not _sim_viewer.has_method("controller"):
		return
	var ctrl = _sim_viewer.call("controller")
	if ctrl == null or not ctrl.has_method("drive_count"):
		return
	var drives := int(ctrl.call("drive_count"))
	var note := GaitSonifier.contact_note(maxi(drives, 0))
	var hz := GaitSonifier.midi_to_hz(note)
	var frames: int = _sonify_playback.get_frames_available()
	for i in frames:
		_sonify_phase += hz / 22050.0
		var s := sin(_sonify_phase * TAU) * 0.12
		_sonify_playback.push_frame(Vector2(s, s))


# --- Per-part overlay gizmos (M44 residual) ---

func set_overlay_gizmos(on: bool) -> void:
	_overlay_gizmos = on
	_rebuild_overlay_gizmos()


func _rebuild_overlay_gizmos() -> void:
	if _overlay_node != null:
		_overlay_node.queue_free()
		_overlay_node = null
	if not _overlay_gizmos or _session == null or _world == null:
		return
	_overlay_node = Node3D.new()
	_overlay_node.name = "PartOverlays"
	_world.add_child(_overlay_node)
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	for p in fold["parts"]:
		var tag := _overlay_tag(part_authoring_summary(int(p.index)))
		if tag == "":
			continue
		var lbl := Label3D.new()
		lbl.text = tag
		lbl.pixel_size = 0.0032
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.modulate = Color(1.0, 1.0, 0.6)
		lbl.outline_size = 4
		var origin: Vector3 = p.xform.origin
		lbl.position = origin + Vector3.UP * 0.14
		_overlay_node.add_child(lbl)


func _overlay_tag(summary: Dictionary) -> String:
	var parts := PackedStringArray()
	if bool(summary.get("has_spring", false)):
		parts.append("spring")
	if bool(summary.get("has_weapon", false)):
		parts.append(String(summary.get("weapon_kind", "wpn")))
	if bool(summary.get("is_armor", false)):
		parts.append("armor")
	if bool(summary.get("is_ground_contact", false)):
		parts.append("foot")
	if bool(summary.get("is_radial", false)):
		parts.append("radial")
	return " ".join(parts)


# --- Creature stat card (FUN-4) ---

func _update_stat_card() -> void:
	if _stat_card_label == null:
		return
	var s := creature_card_stats()
	if s.is_empty():
		_stat_card_label.text = "(no creature)"
		return
	_stat_card_label.text = "[b]%s[/b]\n%s · %s\nsig %s · mass %.1f · %d parts" % [
		String(s.get("name", "?")), String(s.get("taxonomy", "?")),
		String(s.get("temperament", "?")), String(s.get("signature", "")),
		float(s.get("mass", 0.0)), int(s.get("part_count", 0))]


# M44: per-part overlay data — the authoring-relevant flags a viewport gizmo/label would show
# (spring/weapon/armor/ground_contact/radial), plus a live spring store/return readout if running.
func part_authoring_summary(index: int) -> Dictionary:
	var root_gene: PartGene = _session.root() if _session != null else null
	var g := _gene_by_index(root_gene, index) if root_gene != null else null
	if g == null:
		return {}
	var d := g.definition
	var e: Vector3 = d.extents if d != null else Vector3.ONE
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	var axis := Vector3.ZERO
	if g.socket != null:
		pos = g.socket.parent_attachment.origin
		rot = g.socket.parent_attachment.basis.get_euler() * (180.0 / PI)
		axis = g.socket.hinge_axis
	var jd := g.joint
	return {
		"index": index,
		"tags": g.tags.duplicate(),
		"part_type": String(d.part_type) if d != null else "box",
		"size": [e.x, e.y, e.z],
		"density": (d.density if d != null else 0.0),
		"position": [pos.x, pos.y, pos.z],
		"rotation_deg": [rot.x, rot.y, rot.z],
		"joint_axis": [axis.x, axis.y, axis.z],
		"swing": [(jd.amplitude if jd else 0.0), (jd.rest_angle if jd else 0.0),
			(jd.angle_min if jd else 0.0), (jd.angle_max if jd else 0.0)],
		"has_spring": g.spring != null and g.spring.enabled,
		"spring_stiffness": (g.spring.stiffness if g.spring != null else 0.0),
		"has_weapon": g.weapon != null,
		"weapon_kind": (g.weapon.kind if g.weapon != null else &"none"),
		"is_armor": g.tags.has(&"armor") or g.tags.has(&"shell"),
		"is_ground_contact": g.tags.has(&"ground_contact"),
		"is_radial": g.tags.has(&"pogo") or g.tags.has(&"radial"),
		"is_anisotropic": g.tags.has(&"anisotropic_ventral"),
	}


func set_selected_muscle(on: bool) -> bool:
	if _session == null:
		return false
	var indices := _editable_selected_indices(true)
	var ok := _session.apply_edit(func(root: PartGene):
		for idx in indices:
			_set_gene_muscle_amount(_gene_by_index(root, idx),
					1.0 if on else 0.0,
					true)
	)
	if ok:
		_sync_controls_from_selection()
	return ok


func set_selected_muscle_amount(amount: float) -> bool:
	if _session == null:
		return false
	var indices := _editable_selected_indices(true)
	var clamped := clampf(amount, 0.0, 4.0)
	var ok := _session.apply_edit(func(root: PartGene):
		for idx in indices:
			_set_gene_muscle_amount(_gene_by_index(root, idx), clamped, true)
	)
	if ok:
		_sync_controls_from_selection()
	return ok


func set_global_muscle_amount(amount: float) -> bool:
	if _session == null:
		return false
	var clamped := clampf(amount, 0.0, 4.0)
	var ok := _session.apply_edit(func(root: PartGene):
		_apply_global_muscle(root, clamped)
	)
	if ok:
		_sync_controls_from_selection()
	return ok


func add_child_part(part_id: StringName) -> bool:
	if _session == null or _selected_index < 0:
		return false
	var parent_idx := _selected_index
	var ok := _session.apply_edit(func(root: PartGene):
		var parent := _gene_by_index(root, parent_idx)
		if parent == null:
			return
		var child := _clone_part_template(part_id)
		if child == null:
			return
		child.socket_id = _unique_socket_id(parent, StringName("%s_%d" % [String(part_id), parent.children.size()]))
		child.socket = _default_child_socket(parent, child.socket_id)
		parent.children.append(child)
	)
	if ok:
		_selected_index = maxi(part_count() - 1, 0)
	return ok


func add_child_part_at(part_id: StringName, parent_index: int, point_id: StringName) -> bool:
	if _session == null:
		return false
	var parent_before := _gene_by_index(_session.root(), parent_index)
	var child_before := _clone_part_template(part_id)
	if parent_before == null or child_before == null:
		return false
	var child_tags_before: Array[StringName] = []
	child_tags_before.assign(child_before.tags)
	var preflight := SocketCatalog.can_attach(parent_before, point_id, child_tags_before)
	if not bool(preflight["ok"]):
		_on_edit_rejected(String(preflight["reason"]))
		return false
	var ok := _session.apply_edit(func(root: PartGene):
		var parent := _gene_by_index(root, parent_index)
		if parent == null:
			return
		var child := _clone_part_template(part_id)
		if child == null:
			return
		var child_tags: Array[StringName] = []
		child_tags.assign(child.tags)
		var gate := SocketCatalog.can_attach(parent, point_id, child_tags)
		if not bool(gate["ok"]):
			return
		var point := gate["point"] as AttachPoint
		var socket_id := SocketCatalog.next_socket_id(parent, point_id)
		child.socket_id = socket_id
		child.socket = SocketCatalog.socket_for_child(point, socket_id, child,
				&"top" if child.tags.has(&"locomotor") or child.tags.has(&"ground_contact") else &"center")
		parent.children.append(child)
	)
	if ok:
		_selected_index = maxi(part_count() - 1, 0)
	return ok


func generate_creature(seed_value: int) -> bool:
	var cfg := CreatureGenerator.Config.new()
	cfg.seed = seed_value
	return generate_creature_cfg(cfg)


func generate_creature_cfg(cfg) -> bool:
	if cfg == null:
		return false
	var generated := CreatureGenerator.generate(cfg)
	if generated == null:
		return false
	var card := CreatureCard.new()
	card.display_name = "Generated (seed %d)" % cfg.seed
	card.root = generated
	card.notes = "Procedurally generated; unsaved until you press Save."
	load_card(card)
	return true


func _generate_from_ui() -> void:
	var cfg := CreatureGenerator.Config.new()
	cfg.seed = int(_gen_seed.value)
	cfg.limb_pairs_min = int(_gen_legs.value)
	cfg.limb_pairs_max = int(_gen_legs.value)
	cfg.spine_segments_min = int(_gen_spine.value)
	cfg.spine_segments_max = int(_gen_spine.value)
	cfg.leg_segments = int(_gen_leg_segs.value)
	cfg.arm_pairs = int(_gen_arm_pairs.value)
	cfg.arm_segments = int(_gen_arm_segs.value)
	cfg.want_head = _gen_head.button_pressed
	cfg.want_organs = _gen_organs.button_pressed
	cfg.symmetry = _gen_symmetry.button_pressed
	cfg.biped = _gen_biped.button_pressed
	generate_creature_cfg(cfg)


func is_simulating() -> bool:
	return _sim_viewer != null


func sim_viewer() -> Node:
	return _sim_viewer


# --- M10 display skin (visual only; never touches physics/score) --------------

func set_skin_enabled(on: bool) -> void:
	_skin_enabled = on
	if _skin_check != null and _skin_check.button_pressed != on:
		_skin_check.button_pressed = on
	_refresh_skin()


func skin_enabled() -> bool:
	return _skin_enabled


func _refresh_skin() -> void:
	if _skin_node != null:
		_skin_node.queue_free()
		_skin_node = null
	if not _skin_enabled or _sim_viewer == null or not _sim_viewer.has_method("body"):
		return
	var b = _sim_viewer.call("body")
	if b != null:
		# M51-B6: the LIVE sim skin must be the per-part trackable sleeve (build_display_skin),
		# not the baked CONTINUOUS mesh — the continuous mesh has no per-part index, so
		# update_display_skin can't move it and it gets left behind as a "shed skin".
		_skin_node = SkinBuilder.build_display_skin(b)
		_sim_viewer.add_child(_skin_node)
		_apply_palette_live()   # M58 (B7): tint the live skin from the creature palette


func _tick_skin() -> void:
	if not _skin_enabled or _sim_viewer == null or not _sim_viewer.has_method("body"):
		return
	var b = _sim_viewer.call("body")
	if b == null:
		return
	if _skin_node == null:
		_refresh_skin()          # lazily build once the sim body exists
	if _skin_node != null:
		SkinBuilder.update_display_skin(_skin_node, b)


# --- M11 training dashboard (read-side) ---------------------------------------

func refresh_dashboard() -> void:
	if _dashboard_label != null:
		_dashboard_label.text = TrainingDashboard.summary_text()


func dashboard_text() -> String:
	return TrainingDashboard.summary_text()


func toggle_simulation() -> void:
	if is_simulating():
		stop_simulation()
	else:
		start_simulation()


func _on_measure_pressed() -> void:
	if _session == null or _measuring:
		return
	if is_simulating():
		stop_simulation()
	_measuring = true
	if _measure_button != null:
		_measure_button.disabled = true
	_status_label.text = "Measuring real walk..."
	var params := SimRollout.Params.new()
	params.controller_params = _controller_params_for_current_gait()
	params.track = _selected_track()   # M55: Measure on the chosen track (curved/hazards/etc.)
	var measured := await SimRollout.run(GenomeSnapshot.deep_copy(_session.root()), 4.0, 2001, get_tree(), params)
	_last_measured = measured   # so the co-pilot can diagnose explosions/falls (M57)
	var summary := _measured_walk_summary(measured)
	_status_label.text = summary
	if _score_measured != null:
		_score_measured.text = summary
	record_fossil(measured)   # M58 FUN-2: bank this run as a fossil for the ghost overlay
	_measuring = false
	if _measure_button != null:
		_measure_button.disabled = false


func is_training() -> bool:
	return _training


# AI-drive training mode. A demonstrator walks a COPY of the creature under the real muscle cap; we record
# each joint's angle+torque by gait phase and bake a MotionClip. The clip is written back through the edit
# session (undoable + persisted by Save), so afterwards Watch-it-walk REPLAYS the baked numbers.
func _on_kinesthetic_train_pressed() -> void:
	if _session == null or _training or _measuring or _optimizing:
		return
	if is_simulating():
		stop_simulation()
	_training = true
	if _kinesthetic_button != null:
		_kinesthetic_button.disabled = true
		_kinesthetic_button.text = "Training..."
	_status_label.text = "Training: demonstrating the walk and recording joint forces (through the cap)..."
	# Capture on a deep copy so its transient physics body can't perturb the editor creature.
	var demo_root := GenomeSnapshot.deep_copy(_session.root())
	var res: Dictionary = await KinestheticTrainerScript.capture_and_bake(demo_root, get_tree(), 2.0, 5.0, 24)
	var clip = res.get("clip", null)
	if clip != null and _session != null:
		_session.apply_edit(func(root: PartGene):
			if root.gait == null:
				root.gait = GaitDef.new()
			root.gait.motion_clip = clip
		)
		_status_label.text = "Baked kinesthetic clip: %d joints, peak %.0f N-m. Watch it walk replays it; Save keeps it." % [
			int(res.get("joints", 0)), float(res.get("peak_torque", 0.0))]
	else:
		_status_label.text = "Training produced no clip (no actuated joints to record)."
	_training = false
	if _kinesthetic_button != null:
		_kinesthetic_button.disabled = false
		_kinesthetic_button.text = "Train (kinesthetic)"


func is_optimizing() -> bool:
	return _optimizing


func _on_optimize_pressed() -> void:
	if _session == null or _optimizing:
		return
	if is_simulating():
		stop_simulation()
	_optimizing = true
	if _optimize_button != null:
		_optimize_button.disabled = true
	if _llm_check != null and _llm_check.button_pressed:
		await _optimize_with_llm()
	else:
		await _optimize_with_search()
	_optimizing = false
	if _optimize_button != null:
		_optimize_button.disabled = false


func _optimize_with_search() -> void:
	_status_label.text = "Optimizing gait..."
	var progress := func(done: int, total: int, fwd: float):
		_status_label.text = "Optimizing gait %d/%d  (best forward %+.2f)" % [done, total, fwd]
	var result = await GaitOptimizer.optimize(_session.root(), get_tree(), 10, 3.0, 1, 2, progress)
	apply_optimized_gait(result)
	_status_label.text = "Tuned gait: forward %+.2f, sustained %+.2f. Press Save to keep; Watch it walk." \
			% [result.forward, result.forward_tail]


func _optimize_with_llm() -> void:
	var model := _copilot_model()   # always the default coding model (qwen), no bottom-bar picker
	_status_label.text = "Training with %s ..." % model
	var progress := func(done: int, total: int, best_forward: float, credible: bool):
		_status_label.text = "LLM training %d/%d  (best %.2fm %s)" % [
			done, total, best_forward, "credible walk" if credible else "not credible yet"]
	var cfg := Trainer.Config.new()
	cfg.rounds = 14
	cfg.horizon = 3.0
	cfg.seed = 1
	cfg.proposer = &"llm"
	cfg.model = model
	cfg.creature_name = _active_card_name
	var working := GenomeSnapshot.deep_copy(_session.root())
	var best := await Trainer.train(working, get_tree(), cfg, Time.get_unix_time_from_system(), progress)
	if best.is_empty():
		_status_label.text = "LLM training produced nothing (is Ollama running?)."
		return
	_apply_trainer_candidate(best["candidate"])
	var m: Dictionary = best["metrics"]
	_status_label.text = "%s trained: forward %+.2f, %s. Save to keep; Watch it walk." % [
		model, float(m["forward"]), "credible walk" if bool(m["credible_walk"]) else "not credible yet"]


func _on_llm_toggled(pressed: bool) -> void:
	if _llm_models == null:
		return
	_llm_models.visible = pressed
	if not pressed:
		return
	_status_label.text = "Querying Ollama models..."
	var models := await OllamaClient.list_models(get_tree())
	_llm_models.clear()
	if models.is_empty():
		_status_label.text = "No Ollama models found - is `ollama serve` running?"
		return
	for name in models:
		_llm_models.add_item(name)
	# Pre-select the evidence-chosen default director if installed (docs/MODEL_BAKEOFF.md).
	for i in models.size():
		if String(models[i]) == LlmDirector.DEFAULT_MODEL:
			_llm_models.select(i)
			break
	_status_label.text = "%d Ollama model(s) available." % models.size()


# Apply a Trainer candidate ({phases, scales, pattern}) through the edit session.
func _apply_trainer_candidate(cand: Dictionary) -> bool:
	if _session == null or cand.is_empty():
		return false
	var ok := _session.apply_edit(func(root: PartGene):
		if root.gait == null:
			root.gait = GaitDef.new()
		for sid in cand["phases"]:
			root.gait.assignments[sid] = cand["phases"][sid]
		var s: Dictionary = cand["scales"]
		root.gait.amplitude_scale = float(s.get("amplitude", 1.0))
		root.gait.frequency_scale = float(s.get("frequency", 1.0))
		root.gait.gain_scale = float(s.get("gain", 8.0))
		root.gait.traction_scale = float(s.get("traction", 1.4))
		root.gait.posture_scale = float(s.get("posture", 2.2))
	)
	if ok:
		pump_scores_blocking()
	return ok


# Writes a GaitOptimizer.Result into the live creature through the edit session
# (so it is undoable and persists on Save).
func apply_optimized_gait(result) -> bool:
	if _session == null or result == null:
		return false
	var ok := _session.apply_edit(func(root: PartGene):
		GaitOptimizer.apply_to(root, result)
	)
	if ok:
		pump_scores_blocking()
	return ok


func start_simulation() -> bool:
	if _session == null or _world == null:
		return false
	if is_simulating():
		return true
	_disarm_palette()
	close_hinge_editor()
	if _nub_node != null:
		_nub_node.visible = false
	_sim_viewer = LocomotionViewerScript.new()
	_world.add_child(_sim_viewer)
	var ctrl_params := _controller_params_for_current_gait()
	_sim_viewer.call("load_creature", GenomeSnapshot.deep_copy(_session.root()), null, ctrl_params)
	if _creature_node != null:
		_creature_node.visible = false
	if _cog_marker != null:
		_cog_marker.visible = false
	if _ground != null:
		_ground.visible = false
	if _sim_button != null:
		_sim_button.text = "[] Stop"
	_status_label.text = "Simulating... click Stop to return to editing."
	return true


func _controller_params_for_current_gait() -> CpgController.Params:
	var ctrl_params := CpgController.Params.new()
	var speed := float(_sim_speed.value) if _sim_speed != null else 1.0
	var gait: GaitDef = _session.root().gait if _session != null else null
	if gait != null:
		ctrl_params.amplitude_scale = gait.amplitude_scale
		ctrl_params.gain_scale = gait.gain_scale
		ctrl_params.frequency_scale = gait.frequency_scale * speed
		ctrl_params.traction_scale = gait.traction_scale
		ctrl_params.posture_scale = gait.posture_scale
		ctrl_params.turn_rate = gait.turn_rate
		ctrl_params.tear_omega = gait.tear_omega   # M55: authored joint-tear threshold
	else:
		ctrl_params.frequency_scale = speed
	return ctrl_params


func _measured_walk_summary(m: Dictionary) -> String:
	if m.is_empty() or not bool(m.get("ok", false)):
		return "Measured walk failed: %s" % String(m.get("error", "non-finite rollout"))
	var reasons: Array = m.get("locomotion_reasons", [])
	var reason_text := ""
	if not reasons.is_empty():
		var reason_strings := PackedStringArray()
		for reason in reasons:
			reason_strings.append(String(reason))
		reason_text = " (%s)" % ", ".join(reason_strings)
	var base := "Measured: %s, forward %.2fm, tail %.2fm, straight %.2f, fell %s%s" % [
		"credible" if bool(m.get("credible_walk", false)) else String(m.get("locomotion_class", "not credible")),
		float(m.get("forward", 0.0)),
		float(m.get("forward_tail", 0.0)),
		float(m.get("straightness", 0.0)),
		str(bool(m.get("fell", false))),
		reason_text,
	]
	# M55: when run on a grasp/tool track, surface the reach/grasp outcome (ReachController is
	# driven inside the rollout on auto-grasp tracks).
	if m.has("tool_progress"):
		base += "  | tool: progress %.2f, %s" % [
			float(m.get("tool_progress", 0.0)),
			"applied" if bool(m.get("tool_applied", false)) else "not applied"]
	elif bool(m.get("reach_used", false)) or bool(m.get("grasp_grasped", false)):
		base += "  | grasp: %s (reach %.2fm)" % [
			"grabbed" if bool(m.get("grasp_grasped", false)) else "reached" if bool(m.get("reach_used", false)) else "no",
			float(m.get("reach_distance", 0.0))]
	return base


func stop_simulation() -> void:
	if not is_simulating():
		return
	_teardown_sim()
	_rebuild_view()


func _teardown_sim() -> void:
	_skin_node = null   # freed with the viewer below; drop the dangling ref
	if _sim_viewer != null:
		_sim_viewer.queue_free()
		_sim_viewer = null
	if _creature_node != null:
		_creature_node.visible = true
	if _cog_marker != null:
		_cog_marker.visible = true
	if _ground != null:
		_ground.visible = true
	if _sim_button != null:
		_sim_button.text = "> Watch it walk"
	# Clear the "Simulating..." status when the sim ends (it used to linger until a reload).
	if _status_label != null and _status_label.text.begins_with("Simulating"):
		_status_label.text = ""


func arm_part(part_id: StringName) -> void:
	_armed_part_id = part_id
	if part_id != &"":
		_status_label.text = "Placing %s: click a body part (drag empty space to orbit/cancel)" \
				% String(part_id)


func armed_part() -> StringName:
	return _armed_part_id


func add_child_part_to_selected(part_id: StringName) -> bool:
	if _session == null or _selected_index < 0:
		return false
	var parent_gene := _gene_by_index(_session.root(), _selected_index)
	if parent_gene == null:
		return false
	var child := _clone_part_template(part_id)
	if child == null:
		return false
	var child_tags: Array[StringName] = []
	child_tags.assign(child.tags)
	for point in SocketCatalog.points_for(parent_gene.definition):
		if bool(SocketCatalog.can_attach(parent_gene, point.id, child_tags)["ok"]):
			return add_child_part_at(part_id, _selected_index, point.id)
	_on_edit_rejected("No legal attach point for %s on the selected part" % String(part_id))
	return false


func preview_drop(part_id: StringName, parent_index: int, world_point: Vector3) -> bool:
	if _session == null:
		_clear_drop_preview()
		return false
	var nearest := ViewportDropTarget.nearest_attach_point(_session.root(), parent_index, world_point)
	if not bool(nearest.get("ok", false)):
		_clear_drop_preview()
		_status_label.text = String(nearest.get("reason", "no attach point"))
		return false
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	if parent_index < 0 or parent_index >= fold["parts"].size():
		_clear_drop_preview()
		return false
	var point := nearest["point"] as AttachPoint
	var result := _can_drop_part_template(part_id, parent_index, world_point)
	var legal := bool(result.get("ok", false))
	_show_drop_preview(part_id, fold["parts"][parent_index], point, legal)
	if legal:
		_status_label.text = "Drop %s -> %s" % [String(part_id), String(point.id)]
	else:
		_status_label.text = "Can't attach %s: %s" % [String(part_id), String(result.get("reason", "illegal"))]
	return legal


func commit_drop(part_id: StringName, parent_index: int, world_point: Vector3) -> bool:
	if _session == null:
		return false
	var result := _can_drop_part_template(part_id, parent_index, world_point)
	if not bool(result.get("ok", false)):
		_on_edit_rejected("Can't attach %s: %s" % [String(part_id), String(result.get("reason", "illegal"))])
		_clear_drop_preview()
		return false
	var point := result["point"] as AttachPoint
	var ok := add_child_part_at(part_id, parent_index, point.id)
	_clear_drop_preview()
	return ok


func begin_attach_selected() -> bool:
	if _session == null or _selected_index <= 0:
		_on_edit_rejected("Select a non-root part or limb before attaching it.")
		return false
	_attach_existing_mode = true
	var g := _gene_by_index(_session.root(), _selected_index)
	var nm := String(g.part_id if g != null and g.part_id != &"" else &"selected part")
	# M56: slot-state-aware guidance for the two-point attach.
	var slot := AttachLogic.slot_state(g)
	var hint := "click a body part, nub, or socket area to attach to."
	if bool(slot.get("fully_attached", false)) and not bool(slot.get("distal_free", false)):
		hint = "already attached on both sides — click a nub or free socket to re-home it."
	_status_label.text = "Attach %s: %s" % [nm, hint]
	return true


func attach_selected_to_part_at(parent_index: int, world_point: Vector3) -> bool:
	if _session == null:
		return false
	var moving_index := _selected_index
	var result := _can_attach_existing(moving_index, parent_index, world_point)
	if not bool(result.get("ok", false)):
		_on_edit_rejected("Can't attach selected part: %s" % String(result.get("reason", "illegal")))
		return false
	var point := result["point"] as AttachPoint
	var point_id := point.id
	var parent_path: Array = result["parent_path"]
	var anchor: StringName = result["anchor"]
	var new_socket_id := &""
	var ok := _session.apply_edit(func(root: PartGene):
		var parent := _gene_by_path(root, parent_path)
		var moving := _detach_by_index(root, moving_index)
		if parent == null or moving == null:
			return
		var socket_id := SocketCatalog.next_socket_id(parent, point_id)
		new_socket_id = socket_id
		moving.socket_id = socket_id
		moving.socket = SocketCatalog.socket_for_child(point, socket_id, moving, anchor)
		parent.children.append(moving)
	)
	if ok:
		_selected_index = _index_for_socket_id(_session.root(), new_socket_id)
		if _selected_index < 0:
			_selected_index = maxi(part_count() - 1, 0)
		_selected_indices = [_selected_index]
		_sync_part_list_selection()
		_apply_selection_highlight()
		_sync_controls_from_selection()
		_attach_existing_mode = false
		_status_label.text = "Attached at %s with hinge %s" % [String(point_id), str(point.hinge_axis)]
	return ok


func attach_selected_near_current() -> bool:
	if _session == null or _selected_index <= 0:
		_on_edit_rejected("Select a detached/parked part before attaching near its current position.")
		return false
	var result := _best_attach_existing_near_current(_selected_index)
	if not bool(result.get("ok", false)):
		_on_edit_rejected("No legal nearby attach point: %s" % String(result.get("reason", "none")))
		return false
	return attach_selected_to_part_at(int(result["parent_index"]), result["world_point"])


func detach_selected_to_root() -> bool:
	if _session == null or _selected_index <= 0:
		return false
	var moving_index := _selected_index
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	if moving_index >= fold["parts"].size():
		return false
	var current_pos: Vector3 = fold["parts"][moving_index].xform.origin
	var new_socket_id := _unique_socket_id(_session.root(), &"detached")
	var ok := _session.apply_edit(func(root: PartGene):
		var moving := _detach_by_index(root, moving_index)
		if moving == null:
			return
		var socket := SocketDef.new()
		socket.id = new_socket_id
		socket.display_name = String(new_socket_id)
		socket.parent_attachment = Transform3D(Basis.IDENTITY, current_pos)
		socket.child_anchor = Transform3D.IDENTITY
		socket.hinge_axis = Vector3.ZERO
		moving.socket_id = new_socket_id
		moving.socket = socket
		root.children.append(moving)
	)
	if ok:
		_selected_index = _index_for_socket_id(_session.root(), new_socket_id)
		_selected_indices = [_selected_index]
		_status_label.text = "Detached to root parking socket. Use Attach Near or Attach Here to snap it back."
	return ok


func mirror_selected_parts() -> bool:
	if _session == null:
		return false
	var indices := _top_level_selected_indices()
	if indices.is_empty():
		return false
	var ok := _session.apply_edit(func(root: PartGene):
		for idx in indices:
			var parent := _parent_of_index(root, idx)
			var original := _gene_by_index(root, idx)
			if parent == null or original == null or original.socket == null:
				continue
			var clone := GenomeSnapshot.deep_copy(original)
			_mirror_gene_local_x(clone)
			var target_point := _mirrored_point_id(original.socket_id)
			var point := SocketCatalog.point_for(parent, target_point)
			var tags: Array[StringName] = []
			tags.assign(clone.tags)
			if point != null and bool(SocketCatalog.can_attach(parent, target_point, tags).get("ok", false)):
				var socket_id := SocketCatalog.next_socket_id(parent, target_point)
				clone.socket_id = socket_id
				clone.socket = SocketCatalog.socket_for_child(point, socket_id, clone, _anchor_for_child(clone))
			else:
				clone.socket_id = _unique_socket_id(parent, StringName("%s_mirror" % String(original.socket_id)))
				clone.socket.id = clone.socket_id
				clone.socket.parent_attachment.origin.x *= -1.0
			parent.children.append(clone)
	)
	if ok:
		_status_label.text = "Mirrored %d selected part(s)." % indices.size()
	return ok


func save_selected_part_template() -> Error:
	if _session == null or _selected_index < 0 or _palette == null:
		return ERR_UNCONFIGURED
	var g := _gene_by_index(_session.root(), _selected_index)
	if g == null:
		return ERR_INVALID_PARAMETER
	var name := String(g.part_id if g.part_id != &"" else StringName("part_%02d" % _selected_index))
	var err := _palette.save_custom_part(name, g)
	if err == OK:
		_status_label.text = "Saved custom part %s" % name
	else:
		_status_label.text = "Save custom part failed: %s" % err
	return err


func remove_selected_part() -> bool:
	if _session == null or _selected_index <= 0:
		return false
	var idx := _selected_index
	var ok := _session.apply_edit(func(root: PartGene):
		_remove_by_index(root, idx)
	)
	if ok:
		_selected_index = clampi(idx - 1, 0, maxi(part_count() - 1, 0))
	return ok


func reparent_selected_to(target_parent_index: int) -> bool:
	if _session == null or _selected_index <= 0 or target_parent_index == _selected_index:
		return false
	var moving_idx := _selected_index
	return _session.apply_edit(func(root: PartGene):
		var moving := _detach_by_index(root, moving_idx)
		if moving == null:
			return
		var parent := _gene_by_index(root, target_parent_index)
		if parent == null:
			return
		moving.socket_id = _unique_socket_id(parent, moving.socket_id if moving.socket_id != &"" else &"reparented")
		if moving.socket == null:
			moving.socket = _default_child_socket(parent, moving.socket_id)
		parent.children.append(moving)
	)


func snap_selected_to_spine(z_fraction: float = 0.5, side := -1.0) -> bool:
	if _session == null or _selected_index <= 0:
		return false
	var idx := _selected_index
	return _session.apply_edit(func(root: PartGene):
		var parent := _parent_of_index(root, idx)
		var child := _gene_by_index(root, idx)
		if parent == null or child == null or parent.definition == null:
			return
		var hinge := child.socket.hinge_axis if child.socket != null else Vector3.ZERO
		child.socket = CreatureFrames.spine_socket(parent,
				child.socket_id if child.socket_id != &"" else &"spine_snap",
				z_fraction, side, hinge)
	)


func pump_scores_blocking() -> bool:
	if _session == null:
		return false
	var applied := _session.pump_blocking()
	if applied:
		_update_buttons()
	return applied


func current_score() -> Dictionary:
	return {} if _session == null else _session.current_score()


# M44: the live authored genome, for save / round-trip / inspection (never alias it).
func current_root() -> PartGene:
	return null if _session == null else _session.root()


# M49 surfacing: every Track kind reachable from the editor (B12/B19), incl. curved + hazards.
func available_tracks() -> Array:
	return ["straight", "obstacle", "target", "curved", "push", "grasp", "tool", "hop", "lateral",
			"ice", "mud", "wind", "low_g"]


# M49 surfacing: locomotion modes the editor can author (controller-driveable + classifier-aware).
func available_modes() -> Array:
	return ["(infer)", "walk", "hop", "lateral", "fly"]


# M55: build the Track the toolbar picker selects (null = plain straight world).
func _selected_track():
	if _track_picker == null or _track_picker.selected < 0:
		return null
	match _track_picker.get_item_text(_track_picker.selected):
		"obstacle": return Track.obstacle()
		"target": return Track.target()
		"curved": return Track.curved()
		"push": return Track.push_object()
		"grasp": return Track.grasp_carry()
		"tool": return Track.tool_use()
		"hop": return Track.hop()
		"lateral": return Track.lateral()
		"ice": return Track.ice()
		"mud": return Track.mud()
		"wind": return Track.wind_track()
		"low_g": return Track.low_g()
		_: return null   # "straight" / default


# M49 (B18): import a real .glb/.gltf mesh onto the selected part — drives display AND collision
# (M45 wired the runtime import + convex hull; this surfaces it). Returns false if no part selected.
func import_mesh_for_selected(path: String) -> bool:
	if _session == null or _selected_index < 0:
		return false
	var g := _gene_by_index(_session.root(), _selected_index)
	if g == null or String(g.part_id) == "":
		return false
	PartMeshProvider.register_authored(g.part_id, path)
	_settings["use_authored_colliders"] = true
	# M60: tag the creature so headless rollouts + the sim build authored colliders automatically
	# (the per-creature flag), and it round-trips on save instead of relying on editor-only state.
	_session.apply_edit(func(root: PartGene):
		if not root.tags.has(&"authored_colliders"):
			root.tags.append(&"authored_colliders"))
	return PartMeshProvider.has_authored(g.part_id)


# M49 settings (B9): a small settings store — the LLM model picker, wireframe toggle, etc. live here
# instead of cluttering the toolbar. UI is a Settings popup (play-tested); this is the backing store.
var _settings := {"llm_model": "", "wireframe": false, "use_authored_colliders": false}


func get_setting(key: StringName):
	return _settings.get(key, null)


func set_setting(key: StringName, value) -> void:
	_settings[key] = value


# M49 FUN-4: a shareable creature stat-card (morphology name + taxonomy + temperament + live stats).
func creature_card_stats() -> Dictionary:
	var g := current_root()
	if g == null:
		return {}
	var score := current_score()
	return {
		"name": CreatureFlavor.name_for(g),
		"taxonomy": CreatureFlavor.taxonomy(g),
		"temperament": CreatureFlavor.temperament(g),
		"signature": CreatureFlavor.dna_signature(g),
		"mass": float(score.get("total_mass", 0.0)),
		"part_count": part_count(),
	}


func part_count() -> int:
	if _session == null:
		return 0
	return CE.fold_graph(_session.root(), Transform3D.IDENTITY)["parts"].size()


func creature_tab_names() -> PackedStringArray:
	var names := PackedStringArray()
	if _creature_tabs == null:
		return names
	for child in _creature_tabs.get_children():
		names.append(child.name)
	return names


func creature_tab_item_count(tab_name: String) -> int:
	if _creature_tabs == null:
		return 0
	for child in _creature_tabs.get_children():
		if child.name == tab_name:
			var list := child as ItemList
			return 0 if list == null else list.item_count
	return 0


func pick_part_from_ray(origin: Vector3, direction: Vector3) -> int:
	if _session == null:
		return -1
	var dir := direction.normalized()
	var best_index := -1
	var best_t := INF
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	for p in fold["parts"]:
		var hit := _ray_aabb(origin, dir, p.world_aabb)
		if hit >= 0.0 and hit < best_t:
			best_t = hit
			best_index = int(p.index)
	return best_index


func undo() -> bool:
	if _session == null:
		return false
	var ok := _session.undo()
	if ok:
		_teardown_sim()
		_rebuild_view()
		_rebuild_part_list()
		select_part(mini(_selected_index, part_count() - 1))
		pump_scores_blocking()
	return ok


func redo() -> bool:
	if _session == null:
		return false
	var ok := _session.redo()
	if ok:
		_teardown_sim()
		_rebuild_view()
		_rebuild_part_list()
		select_part(mini(_selected_index, part_count() - 1))
		pump_scores_blocking()
	return ok


func _build_ui() -> void:
	_root_layout = HBoxContainer.new()
	_root_layout.name = "EditorBenchLayout"
	_root_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root_layout)

	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(232, 0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root_layout.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left)

	var creatures_box := _collapsible_section(left, "Creatures", &"sec_creatures", true)
	_creature_tabs = TabContainer.new()
	_creature_tabs.custom_minimum_size = Vector2(0, 240)
	_creature_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_creature_tabs.tooltip_text = "Pregen is read-only starter inventory. Saved creatures are grouped by authored leg count."
	# M54 (B8): an overflow menu button on the tab bar so every group stays reachable when many.
	_tab_overflow_popup = PopupMenu.new()
	_tab_overflow_popup.id_pressed.connect(_on_tab_overflow_selected)
	_creature_tabs.set_popup(_tab_overflow_popup)
	creatures_box.add_child(_creature_tabs)

	# New creature + Save As <name>: type a name and press Save (or Save As) to store it under that name.
	var name_row := HBoxContainer.new()
	var new_button := Button.new()
	new_button.text = "＋ New"
	new_button.tooltip_text = "Start a fresh, empty creature (a single body box) to build off of."
	new_button.pressed.connect(new_creature)
	name_row.add_child(new_button)
	_save_name_edit = LineEdit.new()
	_save_name_edit.placeholder_text = "creature name…"
	_save_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_name_edit.tooltip_text = "Name to save under. Empty = keep the current name."
	name_row.add_child(_save_name_edit)
	creatures_box.add_child(name_row)

	var save_row := HBoxContainer.new()
	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_button.tooltip_text = "Save the current creature to your library (uses the name field if set)."
	_save_button.pressed.connect(func(): _save_from_name_field())
	save_row.add_child(_save_button)
	var save_as_button := Button.new()
	save_as_button.text = "Save As"
	save_as_button.tooltip_text = "Save a COPY under the name in the field (leaves the original)."
	save_as_button.pressed.connect(_save_as_from_name_field)
	save_row.add_child(save_as_button)
	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.tooltip_text = "Reload the creature library tabs from disk."
	refresh_button.pressed.connect(_load_cards)
	save_row.add_child(refresh_button)
	creatures_box.add_child(save_row)

	var generate_box := _collapsible_section(left, "Generate", &"sec_generate", false)
	_gen_seed = _labeled_spin(generate_box, "seed", 0, 999999, 1, 42,
			"Random seed. Same seed = same creature; change it for a different body.")
	_gen_legs = _labeled_spin(generate_box, "leg pairs", 1, 8, 1, 2,
			"How many pairs of legs the generator adds.")
	_gen_spine = _labeled_spin(generate_box, "spine segs", 1, 6, 1, 2,
			"How many body segments along the spine (more = longer, centipede-like).")
	_gen_leg_segs = _labeled_spin(generate_box, "leg segs", 1, 4, 1, 1,
			"Capsule segments per leg. 1 = stump, 2 = knee, 3 = knee + ankle.")
	_gen_arm_pairs = _labeled_spin(generate_box, "arm pairs", 0, 3, 1, 0,
			"Pairs of upper (non-foot) limbs / arms. 0 = none.")
	_gen_arm_segs = _labeled_spin(generate_box, "arm segs", 1, 4, 1, 2,
			"Capsule segments per arm. 2 = elbow. Only used when arm pairs > 0.")
	_gen_head = _labeled_check(generate_box, "head", true, "Add a head (sensor sphere) to the front.")
	_gen_organs = _labeled_check(generate_box, "organs", true, "Add a heart and brain organ.")
	_gen_symmetry = _labeled_check(generate_box, "symmetry", true, "Mirror limbs left/right.")
	_gen_biped = _labeled_check(generate_box, "biped", false,
			"Upright two-legged body plan (torso, 2 legs, 2 arms, head on top).")
	var gen_button := Button.new()
	gen_button.text = "Generate"
	gen_button.tooltip_text = "Build a fresh procedural creature from these settings and load it (unsaved)."
	gen_button.pressed.connect(_generate_from_ui)
	generate_box.add_child(gen_button)

	var parts_lib_box := _collapsible_section(left, "Parts Library", &"sec_parts_library", true)
	_palette = PartPalette.new()
	_palette.custom_minimum_size = Vector2(0, 190)
	_palette.tooltip_text = "Click a part to pick it up, then click a body part in the 3D view to attach it."
	_palette.item_selected.connect(_on_palette_selected)
	_palette.item_activated.connect(_on_palette_activated)
	parts_lib_box.add_child(_palette)
	var part_save_row := HBoxContainer.new()
	part_save_row.add_child(_button("Save Part", "Save the selected subtree into the Custom part tab.",
			save_selected_part_template))
	part_save_row.add_child(_button("Refresh Parts", "Reload built-in and custom part tabs.",
			func(): _palette.populate()))
	parts_lib_box.add_child(part_save_row)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_layout.add_child(center)

	var vp_container := ViewportDropContainerScript.new()
	vp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_container.stretch = true
	vp_container.gui_input.connect(_on_viewport_gui_input)
	vp_container.can_drop_cb = _on_viewport_can_drop
	vp_container.drop_cb = _on_viewport_drop
	center.add_child(vp_container)

	_viewport = SubViewport.new()
	_viewport.name = "CreatureViewport"
	_viewport.size = Vector2i(960, 640)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_container.add_child(_viewport)
	_build_world()

	# M54: HFlowContainer auto-wraps the toolbar to new rows when the window is narrow, so controls
	# never clip off-screen (the resize bug). Replaces the old single-row HBoxContainer.
	var knobs := HFlowContainer.new()
	knobs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(knobs)
	_sim_button = Button.new()
	_sim_button.text = "> Watch it walk"
	_sim_button.tooltip_text = "Run the current creature in physics and watch its gait. Click again to stop."
	_sim_button.pressed.connect(toggle_simulation)
	knobs.add_child(_sim_button)
	_measure_button = Button.new()
	_measure_button.text = "Measure walk"
	_measure_button.tooltip_text = "Run a headless physics rollout and report real distance, fall state, and credibility."
	_measure_button.pressed.connect(_on_measure_pressed)
	knobs.add_child(_measure_button)
	# M55: track picker — Measure/Optimize run on the chosen Track (curved + hazards now reachable).
	_track_picker = OptionButton.new()
	for tk in available_tracks():
		_track_picker.add_item(String(tk))
	_track_picker.tooltip_text = "Track for Measure/Optimize: straight, curved, push, grasp, tool, " \
			+ "hop, lateral, and hazards (ice/mud/wind/low-g)."
	knobs.add_child(_track_picker)
	knobs.add_child(_button("Focus", "Center the camera target on the current creature.", _frame_camera_on_creature))
	knobs.add_child(_button("Reset View", "Reset orbit, pan, and zoom to the default editor view.", _reset_camera_view))
	_gpu_status = Label.new()
	_gpu_status.text = _gpu_diagnostics_text()
	_gpu_status.tooltip_text = "Renderer/GPU diagnostic. Godot rendering uses the GPU; Jolt creature physics remains CPU-side."
	knobs.add_child(_gpu_status)
	var spd_label := Label.new()
	spd_label.text = "speed"
	spd_label.tooltip_text = "Gait speed: 1 = walk, higher = run. Set before pressing Watch it walk."
	knobs.add_child(spd_label)
	_sim_speed = _spin(0.3, 3.0, 0.1)
	_sim_speed.value = 1.0
	_sim_speed.tooltip_text = "Gait speed: 1 = walk, 2+ = run. Drives the CPG frequency."
	knobs.add_child(_sim_speed)
	_optimize_button = Button.new()
	_optimize_button.text = "Optimize gait"
	_optimize_button.tooltip_text = "Search for a gait that walks this creature forward and " \
			+ "sustains it. Takes ~1-2 min (UI stays responsive). Press Save to keep the result."
	_optimize_button.pressed.connect(_on_optimize_pressed)
	knobs.add_child(_optimize_button)
	# AI-drive training mode: a demonstrator walks the creature under the real muscle cap, we record each
	# joint's angle+torque by gait phase and BAKE it onto the creature as a MotionClip. Afterwards "Watch it
	# walk" REPLAYS the baked numbers (see the live tension readout). Save persists the clip.
	_kinesthetic_button = Button.new()
	_kinesthetic_button.text = "Train (kinesthetic)"
	_kinesthetic_button.tooltip_text = "Let the demonstrator walk this creature and RECORD the forces each " \
			+ "joint used (through the real muscle cap), then bake those numbers onto it so it reproduces " \
			+ "the motion. ~10s. Then press Watch it walk to replay; Save to keep the clip."
	_kinesthetic_button.pressed.connect(_on_kinesthetic_train_pressed)
	knobs.add_child(_kinesthetic_button)
	# M55: spar the editor creature against a pregen and print the combat quip.
	knobs.add_child(_button("Spar",
			"Run one combat bout vs a pregen opponent and report the result + quip.",
			func(): spar_against()))
	_llm_check = CheckBox.new()
	_llm_check.text = "LLM"
	_llm_check.tooltip_text = "Use a local Ollama model to DIRECT gait training (it picks the " \
			+ "gait + drive scales each round from the run history). Reveals a model picker; " \
			+ "needs `ollama serve` running. Then press Optimize gait to train with the model."
	_llm_check.toggled.connect(_on_llm_toggled)
	knobs.add_child(_llm_check)
	# No bottom-bar model picker (Cole's request): the checkbox alone toggles the LLM, and it always uses
	# the default coding model (qwen3-coder-next:cloud). The picker object is kept but NOT shown so the
	# rest of the code can still read it harmlessly; change the model in the Settings popup if ever needed.
	_llm_models = OptionButton.new()
	_llm_models.visible = false
	_skin_check = CheckBox.new()
	_skin_check.text = "Skin"
	_skin_check.tooltip_text = "Sleeve the creature in a display-only mesh skin that follows the " \
			+ "live sim. Purely visual — never affects physics or score."
	_skin_check.toggled.connect(set_skin_enabled)
	knobs.add_child(_skin_check)
	var scale_label := Label.new()
	scale_label.text = "Scale"
	scale_label.tooltip_text = "Per-axis size multiplier for the selected part."
	knobs.add_child(scale_label)
	_scale_x = _spin(0.05, 5.0, 0.05)
	_scale_y = _spin(0.05, 5.0, 0.05)
	_scale_z = _spin(0.05, 5.0, 0.05)
	for s in [_scale_x, _scale_y, _scale_z]:
		s.tooltip_text = "Per-axis size multiplier for the selected part."
		s.value_changed.connect(_on_scale_changed)
		knobs.add_child(s)
	_undo_button = Button.new()
	_undo_button.text = "Undo"
	_undo_button.pressed.connect(undo)
	knobs.add_child(_undo_button)
	_redo_button = Button.new()
	_redo_button.text = "Redo"
	_redo_button.pressed.connect(redo)
	knobs.add_child(_redo_button)

	var right_scroll := ScrollContainer.new()
	right_scroll.name = "RightPanelScroll"
	right_scroll.custom_minimum_size = Vector2(280, 0)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_layout.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right)
	var parts_box := _collapsible_section(right, "Parts", &"sec_parts", true)
	# M54 (B11): a one-line breadcrumb summary; click it to collapse/expand the scrollable list.
	_parts_breadcrumb = Button.new()
	_parts_breadcrumb.toggle_mode = true
	_parts_breadcrumb.button_pressed = true
	_parts_breadcrumb.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_parts_breadcrumb.tooltip_text = "Selected (or first) parts. Click to collapse/expand the full list."
	_parts_breadcrumb.toggled.connect(func(pressed: bool):
		if _part_list != null:
			_part_list.visible = pressed
		_update_parts_breadcrumb())
	parts_box.add_child(_parts_breadcrumb)
	_part_list = ItemList.new()
	_part_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_part_list.custom_minimum_size = Vector2(0, 150)
	_part_list.select_mode = ItemList.SELECT_MULTI
	_part_list.item_selected.connect(_on_part_list_item_selected)
	parts_box.add_child(_part_list)

	var score_box := _collapsible_section(right, "Score", &"sec_score", false)
	_build_score_panel(score_box)

	var dash_box := _collapsible_section(right, "Training dashboard", &"sec_dashboard", false)
	_dashboard_label = Label.new()
	_dashboard_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dashboard_label.tooltip_text = "Live read of the training log: run/failure counts, best " \
			+ "forward, top performers, and the assist-ratio distribution (debt visible at scale)."
	dash_box.add_child(_dashboard_label)
	dash_box.add_child(_button("Refresh dashboard",
			"Re-read the training log and update the dashboard.", refresh_dashboard))
	refresh_dashboard()

	# Live "tension sensors": while the sim runs, the per-joint torque the controller is applying right now
	# (what the AI is doing to hold/move each joint). This is the force readout the training mode records.
	var tension_box := _collapsible_section(right, "Live tension (N-m)", &"sec_tension", false)
	_tension_label = Label.new()
	_tension_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tension_label.text = "Press Watch it walk to see live joint torques."
	_tension_label.tooltip_text = "Per-joint applied torque (N-m) each frame while the sim runs — the " \
			+ "'tension sensors'. A baked kinesthetic clip replays these; without one you see the live " \
			+ "reference tracker's forces."
	tension_box.add_child(_tension_label)

	var inspector_box := _collapsible_section(right, "Inspector", &"sec_inspector", true)
	_build_inspector(inspector_box)
	var copilot_box := _collapsible_section(right, "Co-pilot (M57)", &"sec_copilot", false)
	_build_copilot_dock(copilot_box)
	var display_box := _collapsible_section(right, "Display (M58)", &"sec_display", false)
	_build_display_panel(display_box)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status_label)
	_build_pause_menu()
	_build_settings_popup()


func _build_inspector(parent: VBoxContainer) -> void:
	_type_option = OptionButton.new()
	for t in [&"box", &"sphere", &"cylinder", &"capsule"]:
		_type_option.add_item(String(t))
	_type_option.item_selected.connect(_on_shape_controls_changed)
	parent.add_child(_row("Type", _type_option,
			"Primitive shape of the selected part. Changes how it looks and its mass."))

	_density_spin = _spin(0.001, 10000.0, 10.0)
	_density_spin.value_changed.connect(_on_shape_controls_changed)
	parent.add_child(_row("Density", _density_spin,
			"Mass per volume. ~1000 = water; bone/dense tissue higher, fat/foam lower."))

	_extent_x = _spin(0.02, 5.0, 0.02)
	_extent_y = _spin(0.02, 5.0, 0.02)
	_extent_z = _spin(0.02, 5.0, 0.02)
	parent.add_child(_vec_row("Size", [_extent_x, _extent_y, _extent_z], _on_shape_controls_changed,
			"Half-size of the part along X, Y, Z. Bigger = larger and heavier.", ["x", "y", "z"]))

	_socket_x = _spin(-5.0, 5.0, 0.05)
	_socket_y = _spin(-5.0, 5.0, 0.05)
	_socket_z = _spin(-5.0, 5.0, 0.05)
	parent.add_child(_vec_row("Position", [_socket_x, _socket_y, _socket_z], _on_socket_controls_changed,
			"Where this part attaches on its parent, in the parent's local space (X, Y, Z).",
			["x", "y", "z"]))

	_hinge_x = _spin(-1.0, 1.0, 0.1)
	_hinge_y = _spin(-1.0, 1.0, 0.1)
	_hinge_z = _spin(-1.0, 1.0, 0.1)
	parent.add_child(_vec_row("Joint", [_hinge_x, _hinge_y, _hinge_z], _on_socket_controls_changed,
			"Axis the joint bends around. All zero = rigid weld.", ["x", "y", "z"]))

	_rot_x = _spin(-180.0, 180.0, 5.0)
	_rot_y = _spin(-180.0, 180.0, 5.0)
	_rot_z = _spin(-180.0, 180.0, 5.0)
	parent.add_child(_vec_row("Rotate", [_rot_x, _rot_y, _rot_z], _on_socket_controls_changed,
			"Turn this segment about X, Y, Z (degrees). Actually re-poses the part in the 3D view.",
			["x", "y", "z"]))

	_joint_amp = _spin(0.0, 3.0, 0.05)
	_joint_rest = _spin(-3.14, 3.14, 0.05)
	_joint_min = _spin(-3.14, 3.14, 0.05)
	_joint_max = _spin(-3.14, 3.14, 0.05)
	parent.add_child(_vec_row("Swing", [_joint_amp, _joint_rest, _joint_min, _joint_max],
			_on_joint_controls_changed,
			"Powered swing of the joint: amplitude, rest angle, min, max (radians). This drives a step.",
			["amp", "rest", "min", "max"]))

	_gait_phase = _spin(0.0, 0.999, 0.05)
	_gait_phase.value_changed.connect(_on_gait_phase_changed)
	parent.add_child(_row("Phase", _gait_phase,
			"Timing of this limb in the gait cycle (0-1). Opposite legs at 0.0 and 0.5 trot."))

	_muscle_check = CheckBox.new()
	_muscle_check.text = "muscle"
	_muscle_check.tooltip_text = "Tag this part as muscle. Muscle near a joint sets that joint's " \
			+ "torque ceiling (more muscle mass = stronger). No-muscle joints still have a finite " \
			+ "passive cap. Matters most on limb/joint parts."
	_muscle_check.toggled.connect(_on_muscle_toggled)
	parent.add_child(_muscle_check)
	_muscle_amount = _spin(0.0, 4.0, 0.1)
	_muscle_amount.value_changed.connect(_on_muscle_amount_changed)
	parent.add_child(_row("Muscle amt", _muscle_amount,
			"Local muscle multiplier for this part. 0 removes muscle; higher values raise joint torque for this subtree."))
	_global_muscle_amount = _spin(0.0, 4.0, 0.1)
	_global_muscle_amount.value = 0.0
	_global_muscle_amount.value_changed.connect(_on_global_muscle_amount_changed)
	parent.add_child(_row("Global muscle", _global_muscle_amount,
			"Apply a muscle amount to every locomotor part. Body-only muscle mostly adds metabolic demand unless it is inside a driven limb subtree."))

	_attachment_status = Label.new()
	_attachment_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_attachment_status.tooltip_text = "Shows the selected part's parent, socket id, and hinge. A non-root part with a socket is attached."
	parent.add_child(_attachment_status)

	var topology := HBoxContainer.new()
	topology.add_child(_button("+Leg", "Add a capsule leg (locomotor) to the selected part.",
			func(): add_child_part(&"primitive_capsule")))
	topology.add_child(_button("+Box", "Add a box body segment (spine) to the selected part.",
			func(): add_child_part(&"primitive_box")))
	topology.add_child(_button("Remove", "Delete the selected part and its children (not the root).",
			remove_selected_part))
	parent.add_child(topology)

	var topo2 := HBoxContainer.new()
	topo2.add_child(_button("To Root", "Reparent the selected part onto the root body.",
			func(): reparent_selected_to(0)))
	topo2.add_child(_button("Attach Here", "Click this, then click a legal target on the creature to reattach the selected part with a catalog socket.",
			begin_attach_selected))
	topo2.add_child(_button("Attach Near", "Attach the selected part to the nearest legal socket from where it currently sits.",
			attach_selected_near_current))
	topo2.add_child(_button("Snap Spine", "Snap the selected part onto the parent's spine axis.",
			func(): snap_selected_to_spine(0.5, -1.0)))
	topo2.add_child(_button("No Joint", "Remove the powered joint (makes the part a rigid weld).",
			clear_selected_joint))
	parent.add_child(topo2)

	var topo3 := HBoxContainer.new()
	topo3.add_child(_button("Detach", "Park the selected subtree under the root at its current position.",
			detach_selected_to_root))
	topo3.add_child(_button("Mirror", "Mirror the selected top-level subtree/subtrees across the creature's left-right axis.",
			mirror_selected_parts))
	# M56: place attachment nubs, then Attach Here onto one; edit the hinge in the viewport.
	_nub_toggle_button = Button.new()
	_nub_toggle_button.text = "Place Nub"
	_nub_toggle_button.toggle_mode = true
	_nub_toggle_button.tooltip_text = "Toggle nub placement: click a body part to drop an attach " \
			+ "point. Then select a part, Attach Here, and click the nub to weld there."
	_nub_toggle_button.toggled.connect(set_place_nub_mode)
	topo3.add_child(_nub_toggle_button)
	topo3.add_child(_button("Edit Hinge",
			"Open the in-viewport hinge editor on the selected part: drag the limit handles, "
			+ "Enter or empty-click to finish.", func(): open_hinge_editor()))
	parent.add_child(topo3)

	# M44 authoring surface: spring / weapon / locomotion-mode.
	var spring_box := _collapsible_section(parent, "Spring (M36)", &"sec_spring", false)
	_spring_k = _spin(0.0, 2000.0, 5.0)
	_spring_damp = _spin(0.0, 0.95, 0.01)
	_spring_eff = _spin(0.0, 1.0, 0.01)
	spring_box.add_child(_vec_row("k / damp / eff", [_spring_k, _spring_damp, _spring_eff],
			_on_spring_controls_changed,
			"Torsional spring: stiffness k (N·m/rad), damping (0-0.95), efficiency (return cap). "
			+ "Stored 0.5·k·θ²; released <= efficiency·stored."))
	spring_box.add_child(_button("No Spring", "Remove the spring from the selected part.",
			clear_selected_spring))

	var weapon_box := _collapsible_section(parent, "Weapon (M35/M43)", &"sec_weapon", false)
	_weapon_kind = OptionButton.new()
	for k in [&"bludgeon", &"blade", &"claw", &"stinger", &"spike"]:
		_weapon_kind.add_item(String(k))
	_weapon_kind.item_selected.connect(_on_weapon_controls_changed)
	weapon_box.add_child(_row("Kind", _weapon_kind, "Weapon kind: blade/claw cut, stinger/spike puncture, bludgeon blunt."))
	_weapon_sharp = _spin(0.0, 1.0, 0.05)
	_weapon_pen = _spin(0.0, 1.0, 0.05)
	_weapon_impact = _spin(0.0, 3.0, 0.05)
	_weapon_reach = _spin(0.0, 1.0, 0.02)
	weapon_box.add_child(_vec_row("sharp/pen/impact/reach",
			[_weapon_sharp, _weapon_pen, _weapon_impact, _weapon_reach], _on_weapon_controls_changed,
			"Sharpness (edge-on cut), penetration (puncture/armor), impact multiplier, reach (m)."))
	weapon_box.add_child(_button("No Weapon", "Remove the weapon from the selected part.",
			clear_selected_weapon))

	var loco_box := _collapsible_section(parent, "Locomotion mode (M44)", &"sec_loco", false)
	_loco_mode = OptionButton.new()
	# M55: extended with `fly` from available_modes() (classifier-aware + controller-driveable).
	for m in available_modes():
		_loco_mode.add_item(String(m))
	_loco_mode.item_selected.connect(_on_loco_mode_changed)
	loco_box.add_child(_row("Mode", _loco_mode,
			"Authored locomotion mode for the whole creature. (infer) = derive from the gait pattern."))

	# M55: steering / tear / assist drive — authored on the root gait, feeds the live controller.
	var drive_box := _collapsible_section(parent, "Drive (M55)", &"sec_drive", false)
	_drive_turn = _spin(-2.0, 2.0, 0.05)
	_drive_tear = _spin(0.0, 40.0, 0.5)
	_drive_traction = _spin(0.0, 3.0, 0.05)
	_drive_posture = _spin(0.0, 4.0, 0.05)
	drive_box.add_child(_vec_row("turn/tear/trac/post",
			[_drive_turn, _drive_tear, _drive_traction, _drive_posture], _on_drive_controls_changed,
			"turn_rate (rad/s steady yaw), tear_omega (joint-tear threshold), traction_scale, "
			+ "posture_scale. These drive the live sim and Measure/Optimize rollouts."))

	# M55 (B18): import a real .glb/.gltf mesh onto the selected part (drives display + collision).
	var import_box := _collapsible_section(parent, "Mesh import (M55)", &"sec_import", false)
	import_box.add_child(_button("Import mesh…",
			"Pick a .glb/.gltf file to drive the selected part's display and collision.",
			_open_mesh_import_dialog))


func _build_score_panel(parent: VBoxContainer) -> void:
	_score_mass = _score_row(parent, "mass",
			"Total mass of all parts (kg-ish). Heavier bodies are harder for legs to move and "
			+ "need more support and power.")
	_score_radius = _score_row(parent, "radius",
			"Characteristic body size (cube-root of total volume). Used to normalize balance, "
			+ "reach, and step timing.")
	_score_stable = _score_row(parent, "stable",
			"Does it stand without tipping? Static check: true = the center of mass sits over the "
			+ "support base (the feet).")
	_score_margin = _score_row(parent, "margin",
			"Balance headroom before tipping (normalized to body size). Positive = stable, bigger "
			+ "is safer; negative = it falls over.")
	_score_tip = _score_row(parent, "tip angle",
			"How far it can lean before tipping, in degrees. Bigger = more stable; small (under "
			+ "~17 deg) = top-heavy and easy to tip over.")
	_score_speed = _score_row(parent, "speed (potential)",
			"Theoretical top speed estimated from body shape (limb count, length, leverage). "
			+ "This is NOT a simulation.")
	_score_probe = _score_row(parent, "probe",
			"Quick deterministic test-drive verdict: did it actually move? 'no_translation' = it "
			+ "didn't go anywhere; 'passed' = it moved. Can disagree with speed potential.")
	_score_measured = _score_row(parent, "measured",
			"Last Measure walk result: real physics rollout distance and credible-walk classification.")
	_score_debt = _score_row(parent, "debt",
			"Biological debt (0-1): missing vital organs, under-supported tissue, bad "
			+ "surface-area:volume, or poor perfusion. 0 = healthy, 1 = maxed out/dead.")
	_score_vitals = _score_row(parent, "vitals",
			"Heart, brain, and lung counts. Missing required vitals mark the creature dead unless a rare explicit perk waives that organ.")
	_score_viability = _score_row(parent, "viability",
			"M55: combat durability readout (HP, vital HP, attack power). Warns when the creature "
			+ "has no vital organs — it does NOT block authoring.")
	_score_message = Label.new()
	_score_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_score_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_score_message)


func _score_row(parent: VBoxContainer, name_text: String, tip: String) -> Label:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = name_text
	name_label.tooltip_text = tip
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.text = "-"
	value_label.tooltip_text = tip
	value_label.mouse_filter = Control.MOUSE_FILTER_PASS
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)
	parent.add_child(row)
	return value_label


func _build_world() -> void:
	_world = Node3D.new()
	_viewport.add_child(_world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -40.0, 0.0)
	light.light_energy = 1.2
	_world.add_child(light)

	_ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30.0, 30.0)   # 30 m platform, extends 15 m in every direction from centre
	_ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.16, 0.17, 0.20)
	_ground.material_override = gmat
	_ground.position.y = -0.7
	_world.add_child(_ground)
	# 1 m grid overlay: lines every metre across the 30 m platform, so scale is readable.
	var grid := MeshInstance3D.new()
	var gm := ImmediateMesh.new()
	gm.surface_begin(Mesh.PRIMITIVE_LINES)
	var half := 15
	for i in range(-half, half + 1):
		gm.surface_add_vertex(Vector3(float(i), 0.0, -float(half)))
		gm.surface_add_vertex(Vector3(float(i), 0.0, float(half)))
		gm.surface_add_vertex(Vector3(-float(half), 0.0, float(i)))
		gm.surface_add_vertex(Vector3(float(half), 0.0, float(i)))
	gm.surface_end()
	grid.mesh = gm
	var grid_mat := StandardMaterial3D.new()
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_mat.albedo_color = Color(0.32, 0.34, 0.40)
	grid_mat.vertex_color_use_as_albedo = false
	grid.material_override = grid_mat
	grid.position.y = 0.002   # just above the plane to avoid z-fighting
	_ground.add_child(grid)

	_camera_pivot = Node3D.new()
	_world.add_child(_camera_pivot)
	_camera = Camera3D.new()
	_camera_pivot.add_child(_camera)
	_viewport.get_camera_3d()

	_cog_marker = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	_cog_marker.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.0)
	_cog_marker.material_override = mat
	_world.add_child(_cog_marker)

	_drop_highlight = MeshInstance3D.new()
	var hl_mesh := SphereMesh.new()
	hl_mesh.radius = 0.07
	hl_mesh.height = 0.14
	_drop_highlight.mesh = hl_mesh
	var hl_mat := StandardMaterial3D.new()
	hl_mat.albedo_color = Color(0.2, 1.0, 0.3)
	hl_mat.emission_enabled = true
	hl_mat.emission = Color(0.16, 0.8, 0.24)
	hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_drop_highlight.material_override = hl_mat
	_drop_highlight.visible = false
	_world.add_child(_drop_highlight)

	_drop_ghost = MeshInstance3D.new()
	var ghost_mat := StandardMaterial3D.new()
	ghost_mat.albedo_color = Color(0.4, 0.9, 1.0, 0.45)
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_drop_ghost.material_override = ghost_mat
	_drop_ghost.visible = false
	_world.add_child(_drop_ghost)

	_hinge_guide = MeshInstance3D.new()
	_hinge_guide.name = "HingeDirectionGuide"
	var hinge_mat := StandardMaterial3D.new()
	hinge_mat.albedo_color = Color(0.12, 0.95, 1.0)
	hinge_mat.emission_enabled = true
	hinge_mat.emission = Color(0.08, 0.6, 0.8)
	hinge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hinge_guide.material_override = hinge_mat
	_hinge_guide.visible = false
	_world.add_child(_hinge_guide)

	# M56: the in-viewport hinge editor gizmo (ROM arc + limit handles + rest tick + axis ring).
	_hinge_editor_node = MeshInstance3D.new()
	_hinge_editor_node.name = "HingeEditorGizmo"
	var he_mat := StandardMaterial3D.new()
	he_mat.albedo_color = Color(1.0, 0.85, 0.2)
	he_mat.emission_enabled = true
	he_mat.emission = Color(1.0, 0.7, 0.05)
	he_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hinge_editor_node.material_override = he_mat
	_hinge_editor_node.visible = false
	_world.add_child(_hinge_editor_node)

	# M58 (FUN-1): force x-ray overlay (torque/contact/assist arrows during a sim).
	_force_xray_node = MeshInstance3D.new()
	_force_xray_node.name = "ForceXray"
	var fx_mat := StandardMaterial3D.new()
	fx_mat.vertex_color_use_as_albedo = true
	fx_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_force_xray_node.material_override = fx_mat
	_force_xray_node.visible = false
	_world.add_child(_force_xray_node)
	_update_camera()


func _load_cards() -> void:
	if _creature_tabs == null:
		return
	var selected_name := _active_card_name
	_rows.clear()
	_tab_rows.clear()
	for child in _creature_tabs.get_children():
		_creature_tabs.remove_child(child)
		child.queue_free()

	var pregen_rows: Array[Dictionary] = []
	for card in PartCatalog.built_in_cards():
		pregen_rows.append({"name": card.display_name, "path": "", "card": card, "builtin": true})
	_add_creature_tab("Pregen", pregen_rows, selected_name)

	var saved_groups := {}
	for row in CreatureIO.scan(CreatureIO.DEFAULT_DIR, false):
		var path := String(row.get("path", ""))
		if path == "":
			continue
		var card := CreatureIO.load(path)
		if card == null:
			continue
		var leg_count := _library_leg_count(card.root)
		var saved_row := {
			"name": card.display_name,
			"path": path,
			"card": card,
			"builtin": false,
			"leg_count": leg_count,
		}
		_rows.append(saved_row)
		if not saved_groups.has(leg_count):
			saved_groups[leg_count] = []
		saved_groups[leg_count].append(saved_row)

	var counts: Array[int] = []
	for k in saved_groups.keys():
		counts.append(int(k))
	counts.sort()
	for count in counts:
		var rows: Array = saved_groups[count]
		rows.sort_custom(func(a, b): return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
		_add_creature_tab(_leg_tab_name(count), rows, selected_name)
	# B8: saved 0-leg (serpent/urchin) and 3-leg (tripod) bodies land in their own "0 legs"/"3 legs"
	# groups automatically; pregens stay in Pregen. The overflow menu keeps every group reachable.
	_refresh_tab_overflow()


func _open_row(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	var row := _rows[index]
	var card: CreatureCard = row.get("card", null)
	load_card(card)


func _open_initial_card() -> void:
	if _session != null or _creature_tabs == null:
		return
	for child in _creature_tabs.get_children():
		var list := child as ItemList
		if list == null:
			continue
		var rows: Array = _tab_rows.get(list.get_instance_id(), [])
		if rows.is_empty():
			continue
		list.select(0)
		_open_creature_tab_row(0, list)
		return


func _add_creature_tab(tab_name: String, rows: Array, selected_name: String) -> void:
	var list := ItemList.new()
	list.name = tab_name
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.tooltip_text = "Open a creature from this group."
	list.item_selected.connect(_open_creature_tab_row.bind(list))
	list.item_activated.connect(_open_creature_tab_row.bind(list))
	var selected_index := -1
	for i in rows.size():
		var row: Dictionary = rows[i]
		list.add_item(_creature_row_label(row))
		if String(row.get("name", "")) == selected_name:
			selected_index = i
	_creature_tabs.add_child(list)
	_tab_rows[list.get_instance_id()] = rows
	if selected_index >= 0:
		_creature_tabs.current_tab = _creature_tabs.get_child_count() - 1
		list.select(selected_index)
		list.ensure_current_is_visible()


func _open_creature_tab_row(index: int, list: ItemList) -> void:
	if list == null:
		return
	var rows: Array = _tab_rows.get(list.get_instance_id(), [])
	if index < 0 or index >= rows.size():
		return
	var row: Dictionary = rows[index]
	var card: CreatureCard = row.get("card", null)
	if card == null:
		var path := String(row.get("path", ""))
		card = CreatureIO.load(path) if path != "" else null
	load_card(card)


func _creature_row_label(row: Dictionary) -> String:
	var name := String(row.get("name", "Untitled"))
	if bool(row.get("builtin", false)):
		return name
	var path := String(row.get("path", ""))
	if path == "":
		return name
	var file_stem := path.get_file().get_basename()
	if file_stem != "" and file_stem.naturalnocasecmp_to(_safe_file_stem(name)) != 0:
		return "%s  (%s)" % [name, file_stem]
	return name


func _library_leg_count(root_gene: PartGene) -> int:
	if root_gene == null:
		return 0
	var f := CreatureFeatures.extract(root_gene)
	var feet := int(f.get("foot_count", 0))
	if feet > 0:
		return feet
	return int(f.get("leg_count", 0))


func _leg_tab_name(count: int) -> String:
	return "%d leg%s" % [count, "" if count == 1 else "s"]


func _on_genome_changed(_root: PartGene) -> void:
	if is_simulating():
		stop_simulation()
	else:
		_rebuild_view()
	_rebuild_part_list()
	var count := part_count()
	var cleaned: Array[int] = []
	for idx in _selected_indices:
		if idx >= 0 and idx < count and not cleaned.has(idx):
			cleaned.append(idx)
	if cleaned.is_empty() and _selected_index >= 0:
		cleaned.append(clampi(_selected_index, 0, maxi(count - 1, 0)))
	_selected_indices = cleaned
	if _selected_indices.is_empty():
		_selected_index = -1
	elif not _selected_indices.has(_selected_index):
		_selected_index = _selected_indices[0]
	else:
		_selected_index = clampi(_selected_index, 0, maxi(count - 1, 0))
	_sync_part_list_selection()
	_apply_selection_highlight()
	_sync_controls_from_selection()


func _on_score_changed(result: Dictionary) -> void:
	_update_score(result)


func _on_edit_rejected(reason: String) -> void:
	_status_label.text = reason


func _rebuild_view() -> void:
	if _session == null or _world == null:
		return
	if _creature_node != null:
		_creature_node.queue_free()
	if _part_mat == null:
		_part_mat = StandardMaterial3D.new()
		_part_mat.albedo_color = Color(0.62, 0.47, 0.74)
		_part_mat.roughness = 0.75
		_highlight_mat = StandardMaterial3D.new()
		_highlight_mat.albedo_color = Color(1.0, 0.55, 0.05)
		_highlight_mat.emission_enabled = true
		_highlight_mat.emission = Color(1.0, 0.5, 0.0)
		_highlight_mat.emission_energy_multiplier = 2.5   # unmistakable glow for the selected part(s)
	_creature_node = CreatureAssembler.build(_session.root(), Transform3D.IDENTITY, _part_mat)
	_world.add_child(_creature_node)
	_apply_selection_highlight()
	# Sit the ground plane at the creature's feet so it looks like it stands on the
	# ground instead of being half-buried (the creature stays at identity so picking
	# is unaffected).
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	var min_y := 0.0
	for p in fold["parts"]:
		min_y = minf(min_y, p.world_aabb.position.y)
	if _ground != null:
		_ground.position.y = min_y - 0.02
	var r := CE.evaluate(_session.root())
	_cog_marker.position = r["cog"]
	_update_score(r)
	_rebuild_nubs()              # M56: redraw user attachment nubs
	_update_hinge_editor_gizmo() # M56: keep the hinge gizmo in sync after a rebuild
	_rebuild_overlay_gizmos()    # M58: per-part overlay tags


func _apply_selection_highlight() -> void:
	if _creature_node == null or _part_mat == null:
		_update_hinge_guide()
		return
	for i in _creature_node.get_child_count():
		var mi := _creature_node.get_child(i) as MeshInstance3D
		if mi != null:
			mi.material_override = _highlight_mat if _selected_indices.has(i) else _part_mat
	_update_hinge_guide()
	_update_parts_breadcrumb()


func _rebuild_part_list() -> void:
	_part_list.clear()
	_part_names = PackedStringArray()
	if _session == null:
		_update_parts_breadcrumb()
		return
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	for p in fold["parts"]:
		var label := "%02d  %s  %s  %s" % [
			int(p.index), String(p.definition.part_type), _tag_text(p.tags), _attachment_short_text(p)]
		_part_list.add_item(label)
		_part_list.set_item_tooltip(_part_list.item_count - 1, _attachment_detail_text(p))
		_part_names.append(_breadcrumb_name(p))
	if _part_list.item_count > 0:
		_sync_part_list_selection()
	_update_parts_breadcrumb()


func _update_score(r: Dictionary) -> void:
	if r.is_empty():
		for lbl in [_score_mass, _score_radius, _score_stable, _score_margin, _score_tip,
				_score_speed, _score_probe, _score_measured, _score_debt, _score_vitals,
				_score_viability]:
			lbl.text = "-"
		_score_message.text = "No score"
		return
	var b: Dictionary = r["balance"]
	_score_mass.text = "%.1f" % float(r["total_mass"])
	_score_radius.text = "%.2f" % float(r["body_radius"])
	_score_stable.text = str(b["stable"])
	_score_margin.text = "%.2f" % float(b["balance_margin"])
	_score_tip.text = "%.1f deg" % rad_to_deg(float(b["tip_angle"]))
	_score_speed.text = "%.2f" % float(r["speed"]["value"])
	_score_probe.text = str(r["probe"]["verdict"])
	if _score_measured != null and _score_measured.text == "":
		_score_measured.text = "-"
	_score_debt.text = "%.2f" % float(r["debt"]["debt_total"])
	_score_vitals.text = _vitals_text(r)
	if _score_viability != null:
		_score_viability.text = viability_summary()
	_score_message.text = String(r["reconciliation"]["message"])
	_update_stat_card()   # M58 FUN-4
	_cog_marker.position = r["cog"]


func _sync_controls_from_selection() -> void:
	if _session == null:
		return
	var g := _gene_by_index(_session.root(), _selected_index)
	if g == null:
		if _attachment_status != null:
			_attachment_status.text = "No part selected."
		return
	_updating_controls = true
	_scale_x.value = g.scale.x
	_scale_y.value = g.scale.y
	_scale_z.value = g.scale.z
	if g.definition != null:
		_select_part_type(g.definition.part_type)
		_density_spin.value = g.definition.density
		_extent_x.value = g.definition.extents.x
		_extent_y.value = g.definition.extents.y
		_extent_z.value = g.definition.extents.z
	var socket_pos := Vector3.ZERO
	var hinge := Vector3.ZERO
	var rot_deg := Vector3.ZERO
	if g.socket != null:
		socket_pos = g.socket.parent_attachment.origin
		hinge = g.socket.hinge_axis
		rot_deg = g.socket.parent_attachment.basis.get_euler() * (180.0 / PI)
	_socket_x.value = socket_pos.x
	_socket_y.value = socket_pos.y
	_socket_z.value = socket_pos.z
	_hinge_x.value = hinge.x
	_hinge_y.value = hinge.y
	_hinge_z.value = hinge.z
	_rot_x.value = rot_deg.x
	_rot_y.value = rot_deg.y
	_rot_z.value = rot_deg.z
	var jd := g.joint
	_joint_amp.value = 1.0 if jd == null else jd.amplitude
	_joint_rest.value = 0.0 if jd == null else jd.rest_angle
	_joint_min.value = 0.0 if jd == null else jd.angle_min
	_joint_max.value = 0.0 if jd == null else jd.angle_max
	var phase := 0.0
	if _session.root().gait != null and g.socket != null and _session.root().gait.assignments.has(g.socket.id):
		phase = float(_session.root().gait.assignments[g.socket.id])
	_gait_phase.value = phase
	_muscle_check.button_pressed = g.tags.has(&"muscle")
	_muscle_amount.value = float(g.dial_values.get(&"muscle_amount", 1.0)) if g.tags.has(&"muscle") else 0.0
	# M44: spring / weapon / locomotion-mode authoring widgets.
	if _spring_k != null:
		_spring_k.value = g.spring.stiffness if g.spring != null else 0.0
		_spring_damp.value = g.spring.damping if g.spring != null else 0.0
		_spring_eff.value = g.spring.efficiency if g.spring != null else 0.0
	if _weapon_kind != null:
		_select_option_text(_weapon_kind, String(g.weapon.kind) if g.weapon != null else "bludgeon")
		_weapon_sharp.value = g.weapon.sharpness if g.weapon != null else 0.0
		_weapon_pen.value = g.weapon.penetration if g.weapon != null else 0.0
		_weapon_impact.value = g.weapon.impact_multiplier if g.weapon != null else 1.0
		_weapon_reach.value = g.weapon.reach if g.weapon != null else 0.0
	if _loco_mode != null:
		var gait := _session.root().gait
		var mode := String(gait.locomotion_mode) if gait != null else ""
		_select_option_text(_loco_mode, "(infer)" if mode == "" else mode)
	# M55: sync the drive sliders from the root gait (defaults when unauthored).
	if _drive_turn != null:
		var gait2 := _session.root().gait
		_drive_turn.value = gait2.turn_rate if gait2 != null else 0.0
		_drive_tear.value = gait2.tear_omega if gait2 != null else 0.0
		_drive_traction.value = gait2.traction_scale if gait2 != null else 0.0
		_drive_posture.value = gait2.posture_scale if gait2 != null else 0.0
	_attachment_status.text = _selected_attachment_status()
	_updating_controls = false


func _on_scale_changed(_value: float) -> void:
	if _updating_controls:
		return
	apply_selected_scale(Vector3(float(_scale_x.value), float(_scale_y.value), float(_scale_z.value)))


func _on_shape_controls_changed(_value = 0) -> void:
	if _updating_controls:
		return
	var part_type := StringName(_type_option.get_item_text(_type_option.selected))
	edit_selected_shape(part_type,
			Vector3(float(_extent_x.value), float(_extent_y.value), float(_extent_z.value)),
			float(_density_spin.value))


func _on_socket_controls_changed(_value = 0) -> void:
	if _updating_controls:
		return
	edit_selected_socket(
			Vector3(float(_socket_x.value), float(_socket_y.value), float(_socket_z.value)),
			Vector3(float(_hinge_x.value), float(_hinge_y.value), float(_hinge_z.value)),
			Vector3(float(_rot_x.value), float(_rot_y.value), float(_rot_z.value)))


func _on_joint_controls_changed(_value = 0) -> void:
	if _updating_controls:
		return
	edit_selected_joint(float(_joint_amp.value), float(_joint_rest.value),
			float(_joint_min.value), float(_joint_max.value))


func _on_gait_phase_changed(_value: float) -> void:
	if _updating_controls:
		return
	set_selected_gait_phase(float(_gait_phase.value))


func _on_spring_controls_changed(_value = 0) -> void:
	if _updating_controls:
		return
	edit_selected_spring(float(_spring_k.value), float(_spring_damp.value), float(_spring_eff.value))


func _on_weapon_controls_changed(_value = 0) -> void:
	if _updating_controls:
		return
	edit_selected_weapon(StringName(_weapon_kind.get_item_text(_weapon_kind.selected)),
			float(_weapon_sharp.value), float(_weapon_pen.value),
			float(_weapon_impact.value), float(_weapon_reach.value))


func _on_loco_mode_changed(_index = 0) -> void:
	if _updating_controls:
		return
	var label := _loco_mode.get_item_text(_loco_mode.selected)
	set_root_locomotion_mode(&"" if label == "(infer)" else StringName(label))


func _on_drive_controls_changed(_value = 0) -> void:
	if _updating_controls:
		return
	set_root_drive(float(_drive_turn.value), float(_drive_tear.value),
			float(_drive_traction.value), float(_drive_posture.value))


# M55 (B18): open a file picker for a .glb/.gltf mesh, then drive the selected part with it.
func _open_mesh_import_dialog() -> void:
	if _session == null or _selected_index < 0:
		_status_label.text = "Select a part before importing a mesh."
		return
	if _mesh_import_dialog == null:
		_mesh_import_dialog = FileDialog.new()
		_mesh_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_mesh_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_mesh_import_dialog.add_filter("*.glb,*.gltf", "glTF mesh")
		_mesh_import_dialog.size = Vector2i(720, 480)
		_mesh_import_dialog.file_selected.connect(_on_mesh_import_selected)
		add_child(_mesh_import_dialog)
	_mesh_import_dialog.popup_centered()


func _on_mesh_import_selected(path: String) -> void:
	if import_mesh_for_selected(path):
		_rebuild_view()
		_status_label.text = "Imported mesh %s onto the selected part (drives display + collision)." % path.get_file()
	else:
		_status_label.text = "Mesh import failed (no part selected or part has no id)."


func _on_muscle_toggled(pressed: bool) -> void:
	if _updating_controls:
		return
	set_selected_muscle(pressed)


func _on_muscle_amount_changed(value: float) -> void:
	if _updating_controls:
		return
	set_selected_muscle_amount(value)


func _on_global_muscle_amount_changed(value: float) -> void:
	if _updating_controls:
		return
	set_global_muscle_amount(value)


func _on_part_list_item_selected(index: int) -> void:
	if _syncing_part_selection:
		return
	var items := _part_list.get_selected_items()
	var selected: Array[int] = []
	for item in items:
		selected.append(int(item))
	if selected.is_empty():
		selected.append(index)
	_selected_indices = selected
	_selected_index = clampi(index, 0, maxi(part_count() - 1, 0))
	if not _selected_indices.has(_selected_index):
		_selected_indices.append(_selected_index)
	_apply_selection_highlight()
	_sync_controls_from_selection()


func _update_buttons() -> void:
	if _session == null:
		_undo_button.disabled = true
		_redo_button.disabled = true
		return
	_undo_button.disabled = not _session.can_undo()
	_redo_button.disabled = not _session.can_redo()


func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _hinge_editing:
					# M56: in the hinge editor, a press grabs a limit handle (or finishes if off-handle).
					_hinge_editor_press(event.position)
				elif _place_nub_mode:
					# M56: click a body part to drop a nub at the surface hit (outward normal).
					var nub_pick := _pick_part_and_point(event.position)
					if not nub_pick.is_empty():
						var pidx := int(nub_pick["index"])
						var wpt: Vector3 = nub_pick["point"]
						place_nub_at(pidx, wpt, _surface_normal_at(pidx, wpt))
					else:
						_dragging = true
						_camera_drag_mode = CAMERA_DRAG_ORBIT
				elif _move_mode:
					# A click while carrying a part drops it here.
					_commit_gizmo_drag()
					_move_mode = false
				elif event.double_click:
					# Double-click a (non-root) part to pick it up and move with the mouse.
					var dhit := _pick_from_viewport(event.position)
					if dhit > 0:
						select_part(dhit)
						_begin_gizmo_drag()
						_move_mode = true
				elif _attach_existing_mode:
					# M56: a clicked nub welds via consume_nub; otherwise fall back to the catalog
					# socket attach. The target may be a placed part, a nub, or a parts-list entry.
					var nub := _pick_nub(event.position)
					if not nub.is_empty():
						attach_selected_to_nub(int(nub["part_index"]), nub["nub_id"])
					else:
						var attach_pick := _pick_part_and_point(event.position)
						if not attach_pick.is_empty():
							attach_selected_to_part_at(int(attach_pick["index"]), attach_pick["point"])
						else:
							_attach_existing_mode = false
							_status_label.text = "Attach cancelled."
				elif _armed_part_id != &"":
					var pick := _pick_part_and_point(event.position)
					if not pick.is_empty():
						commit_drop(_armed_part_id, int(pick["index"]), pick["point"])
						_disarm_palette()
					else:
						_disarm_palette()
						_dragging = true
				else:
					var hit := _pick_from_viewport(event.position)
					if hit >= 0:
						_empty_press_pending = false
						select_part(hit, event.ctrl_pressed)
						if event.shift_pressed and hit > 0:
							_begin_gizmo_drag()
						else:
							_dragging = false
							_camera_drag_mode = CAMERA_DRAG_NONE
					else:
						_empty_press_pending = true
						_empty_press_pos = event.position
						_dragging = true
						_camera_drag_mode = CAMERA_DRAG_ORBIT
			else:
				if _hinge_editing:
					# M56: releasing a limit handle keeps the editor open (commit is live).
					_hinge_drag_handle = 0
					_dragging = false
					if _camera_drag_mode == CAMERA_DRAG_ORBIT:
						_camera_drag_mode = CAMERA_DRAG_NONE
					return
				# shift-drag commits on release; double-click move waits for the next click
				if _gizmo_dragging and not _move_mode:
					_commit_gizmo_drag()
				var clean_empty_click: bool = _empty_press_pending \
						and event.position.distance_to(_empty_press_pos) <= CLEAN_CLICK_PX
				_dragging = false
				if _camera_drag_mode == CAMERA_DRAG_ORBIT:
					_camera_drag_mode = CAMERA_DRAG_NONE
				if clean_empty_click:
					deselect_all_parts()
				_empty_press_pending = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_dragging = true
				_camera_drag_mode = CAMERA_DRAG_PAN
			elif _camera_drag_mode == CAMERA_DRAG_PAN:
				_dragging = false
				_camera_drag_mode = CAMERA_DRAG_NONE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_dist -= 0.5
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_dist += 0.5
			_update_camera()
	elif event is InputEventMouseMotion and _hinge_editing and _hinge_drag_handle != 0:
		_hinge_editor_drag(event.position)
	elif event is InputEventMouseMotion and _gizmo_dragging:
		_update_gizmo_preview(event.position)
	elif event is InputEventMouseMotion and _armed_part_id != &"" and not _dragging:
		_update_armed_preview(event.position)
	elif event is InputEventMouseMotion and _camera_drag_mode == CAMERA_DRAG_ORBIT:
		if _empty_press_pending and event.position.distance_to(_empty_press_pos) > CLEAN_CLICK_PX:
			_empty_press_pending = false
		_cam_yaw -= event.relative.x * 0.01
		_cam_pitch += event.relative.y * 0.01
		_update_camera()
	elif event is InputEventMouseMotion and _camera_drag_mode == CAMERA_DRAG_PAN:
		_empty_press_pending = false
		_pan_camera(event.relative)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# M56: Enter finishes the hinge editor (the limits are already committed live).
	if _hinge_editing and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		close_hinge_editor()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE:
		if _cancel_editor_state():
			get_viewport().set_input_as_handled()
			return
		if _pause_menu != null:
			_pause_menu.popup_centered()
			get_viewport().set_input_as_handled()


func _cancel_editor_state() -> bool:
	# M56: Esc backs out of the hinge editor / nub-placement first, leaving selection intact.
	if _hinge_editing:
		close_hinge_editor()
		return true
	if _place_nub_mode:
		if _nub_toggle_button != null:
			_nub_toggle_button.button_pressed = false
		else:
			set_place_nub_mode(false)
		return true
	var had_state := (
			_armed_part_id != &""
			or _attach_existing_mode
			or _move_mode
			or _gizmo_dragging
			or not _selected_indices.is_empty())
	_disarm_palette()
	_attach_existing_mode = false
	_move_mode = false
	_gizmo_dragging = false
	_dragging = false
	_camera_drag_mode = CAMERA_DRAG_NONE
	if not _selected_indices.is_empty():
		deselect_all_parts()
	elif _attachment_status != null:
		_attachment_status.text = "No part selected."
	if had_state and _status_label != null:
		_status_label.text = "Selection cleared."
	return had_state


func _build_pause_menu() -> void:
	_pause_menu = PopupMenu.new()
	_pause_menu.name = "EditorPauseMenu"
	_pause_menu.add_item("Unpause", PAUSE_UNPAUSE)
	_pause_menu.add_item("Settings", PAUSE_SETTINGS)
	_pause_menu.add_item("Save Progress", PAUSE_SAVE)
	_pause_menu.add_item("Quit to Title", PAUSE_QUIT_TITLE)
	_pause_menu.add_item("Exit Game", PAUSE_EXIT_GAME)
	_pause_menu.add_item("Exit to Project Selection", PAUSE_EXIT_PROJECTS)
	_pause_menu.id_pressed.connect(_on_pause_menu_id_pressed)
	add_child(_pause_menu)


func _on_pause_menu_id_pressed(id: int) -> void:
	match id:
		PAUSE_UNPAUSE:
			_pause_menu.hide()
		PAUSE_SETTINGS:
			open_settings()
		PAUSE_SAVE:
			save_current_card()
		PAUSE_QUIT_TITLE:
			_status_label.text = "Title screen is not wired yet."
		PAUSE_EXIT_GAME:
			get_tree().quit()
		PAUSE_EXIT_PROJECTS:
			_status_label.text = "Godot project selection is editor-owned; stop the running project to return there."


func pause_menu_item_count() -> int:
	return 0 if _pause_menu == null else _pause_menu.item_count


func _update_camera() -> void:
	_cam_pitch = clampf(_cam_pitch, -1.35, 1.35)
	_cam_dist = clampf(_cam_dist, 2.0, 20.0)
	var basis := Basis.from_euler(Vector3(-_cam_pitch, _cam_yaw, 0.0))
	_camera.global_position = _cam_target + basis * Vector3(0.0, 0.0, _cam_dist)
	_camera.look_at(_cam_target, Vector3.UP)


func _pan_camera(relative: Vector2) -> void:
	if _camera == null:
		return
	var scale := maxf(_cam_dist, 1.0) * 0.0018
	var right := _camera.global_basis.x.normalized()
	var up := _camera.global_basis.y.normalized()
	_cam_target += (-right * relative.x + up * relative.y) * scale
	_update_camera()


func _reset_camera_view() -> void:
	_cam_yaw = 0.7
	_cam_pitch = 0.35
	_cam_dist = 6.0
	_cam_target = Vector3.ZERO
	_frame_camera_on_creature()


func _frame_camera_on_creature() -> void:
	if _session == null:
		_update_camera()
		return
	var r := CE.evaluate(_session.root())
	if r.has("cog"):
		_cam_target = r["cog"]
	_update_camera()


func _to_viewport_pos(pos: Vector2) -> Vector2:
	var container := _viewport.get_parent() as SubViewportContainer
	if container != null and container.size.x > 0.0 and container.size.y > 0.0:
		return Vector2(pos.x * float(_viewport.size.x) / container.size.x,
				pos.y * float(_viewport.size.y) / container.size.y)
	return pos


func _pick_from_viewport(pos: Vector2) -> int:
	if _camera == null:
		return -1
	var vp_pos := _to_viewport_pos(pos)
	return pick_part_from_ray(_camera.project_ray_origin(vp_pos), _camera.project_ray_normal(vp_pos))


func _begin_gizmo_drag() -> void:
	_gizmo_dragging = true
	var g := _gene_by_index(_session.root(), _selected_index)
	_gizmo_pending_socket_pos = Vector3.ZERO if g == null or g.socket == null else g.socket.parent_attachment.origin


func _update_gizmo_preview(pos: Vector2) -> void:
	if _session == null or _selected_index <= 0 or _creature_node == null:
		return
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	if _selected_index >= fold["parts"].size():
		return
	var part = fold["parts"][_selected_index]
	if part.parent < 0:
		return
	var parent = fold["parts"][part.parent]
	var hit: Variant = _mouse_on_plane(pos, part.xform.origin.y)
	if hit == null:
		return
	var local: Vector3 = parent.xform.affine_inverse() * hit
	_gizmo_pending_socket_pos = local
	var preview_socket := SocketDef.new()
	preview_socket.parent_attachment = Transform3D(Basis.IDENTITY, local)
	preview_socket.child_anchor = part.socket.child_anchor if part.socket != null else Transform3D.IDENTITY
	var mi := _creature_node.get_child(_selected_index) as MeshInstance3D
	if mi != null:
		mi.transform = CreatureFrames.child_world(parent.xform, preview_socket)


func _commit_gizmo_drag() -> void:
	_gizmo_dragging = false
	if _selected_index <= 0:
		return
	var g := _gene_by_index(_session.root(), _selected_index)
	var hinge := Vector3.ZERO if g == null or g.socket == null else g.socket.hinge_axis
	edit_selected_socket(_gizmo_pending_socket_pos, hinge)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_clear_drop_preview()


func _on_palette_activated(index: int) -> void:
	if _palette == null:
		return
	var part_id := StringName(_palette.drag_data_for_index(index).get("id", &""))
	if part_id != &"":
		add_child_part_to_selected(part_id)


func _on_palette_selected(index: int) -> void:
	if _palette == null:
		return
	arm_part(StringName(_palette.drag_data_for_index(index).get("id", &"")))


func _disarm_palette() -> void:
	_armed_part_id = &""
	_clear_drop_preview()
	if _palette != null:
		_palette.deselect_all()


func _update_armed_preview(pos: Vector2) -> void:
	if _armed_part_id == &"":
		return
	var pick := _pick_part_and_point(pos)
	if pick.is_empty():
		_clear_drop_preview()
		return
	preview_drop(_armed_part_id, int(pick["index"]), pick["point"])


func _on_viewport_can_drop(at_position: Vector2, data: Variant) -> bool:
	var part_id := _drag_part_id(data)
	if part_id == &"":
		_clear_drop_preview()
		return false
	var pick := _pick_part_and_point(at_position)
	if pick.is_empty():
		_clear_drop_preview()
		return false
	return preview_drop(part_id, int(pick["index"]), pick["point"])


func _on_viewport_drop(at_position: Vector2, data: Variant) -> void:
	var part_id := _drag_part_id(data)
	if part_id == &"":
		return
	var pick := _pick_part_and_point(at_position)
	if pick.is_empty():
		_clear_drop_preview()
		return
	commit_drop(part_id, int(pick["index"]), pick["point"])


func _drag_part_id(data: Variant) -> StringName:
	if data is Dictionary and String(data.get("type", "")) == "part_template":
		return StringName(data.get("id", &""))
	return &""


func _pick_part_and_point(at_position: Vector2) -> Dictionary:
	if _camera == null or _session == null:
		return {}
	var vp_pos := _to_viewport_pos(at_position)
	var origin := _camera.project_ray_origin(vp_pos)
	var dir := _camera.project_ray_normal(vp_pos)
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	var best_index := -1
	var best_t := INF
	for p in fold["parts"]:
		var hit := _ray_aabb(origin, dir, p.world_aabb)
		if hit >= 0.0 and hit < best_t:
			best_t = hit
			best_index = int(p.index)
	if best_index < 0:
		return {}
	return {"index": best_index, "point": origin + dir * best_t}


func _show_drop_preview(part_id: StringName, parent_part, point: AttachPoint, legal: bool) -> void:
	if _drop_highlight == null or _drop_ghost == null:
		return
	_drop_highlight.position = parent_part.xform * point.local_pose.origin
	_drop_highlight.visible = true
	var hl_mat := _drop_highlight.material_override as StandardMaterial3D
	if hl_mat != null:
		var col := Color(0.2, 1.0, 0.3) if legal else Color(1.0, 0.3, 0.25)
		hl_mat.albedo_color = col
		hl_mat.emission = col * 0.8
	var tmpl := _clone_part_template(part_id)
	if tmpl == null or not legal:
		_drop_ghost.visible = false
		return
	var socket := SocketCatalog.socket_for_point(point, &"__ghost__")
	var dims := CreatureFrames.dims_for(tmpl.definition, tmpl.scale)
	_drop_ghost.mesh = PartMeshProvider.mesh_for(tmpl.definition.part_type, dims)
	_drop_ghost.transform = CreatureFrames.child_world(parent_part.xform, socket)
	_drop_ghost.visible = true


func _clear_drop_preview() -> void:
	if _drop_highlight != null:
		_drop_highlight.visible = false
	if _drop_ghost != null:
		_drop_ghost.visible = false


func _mouse_on_plane(pos: Vector2, plane_y: float):
	var vp_pos := _to_viewport_pos(pos)
	var origin := _camera.project_ray_origin(vp_pos)
	var dir := _camera.project_ray_normal(vp_pos)
	if absf(dir.y) < 0.000001:
		return null
	var t := (plane_y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t


func _ray_aabb(origin: Vector3, dir: Vector3, box: AABB) -> float:
	var minp := box.position
	var maxp := box.position + box.size
	var tmin := -INF
	var tmax := INF
	for axis in 3:
		var o := origin[axis]
		var d := dir[axis]
		var mn := minp[axis]
		var mx := maxp[axis]
		if absf(d) < 0.000001:
			if o < mn or o > mx:
				return -1.0
			continue
		var t1 := (mn - o) / d
		var t2 := (mx - o) / d
		if t1 > t2:
			var tmp := t1
			t1 = t2
			t2 = tmp
		tmin = maxf(tmin, t1)
		tmax = minf(tmax, t2)
		if tmin > tmax:
			return -1.0
	if tmax < 0.0:
		return -1.0
	return maxf(tmin, 0.0)


func _clone_part_template(part_id: StringName) -> PartGene:
	if _palette != null:
		var palette_part := _palette.clone_part(part_id)
		if palette_part != null:
			return palette_part
	return PartCatalog.clone_template(part_id)


func _can_drop_part_template(part_id: StringName, parent_index: int, world_point: Vector3) -> Dictionary:
	if _session == null:
		return {"ok": false, "reason": "no session"}
	var child := _clone_part_template(part_id)
	if child == null:
		return {"ok": false, "reason": "unknown part"}
	var nearest := ViewportDropTarget.nearest_attach_point(_session.root(), parent_index, world_point)
	if not bool(nearest.get("ok", false)):
		return nearest
	var parent_gene := _gene_by_index(_session.root(), parent_index)
	var child_tags: Array[StringName] = []
	child_tags.assign(child.tags)
	var point := nearest["point"] as AttachPoint
	var gate := SocketCatalog.can_attach(parent_gene, point.id, child_tags)
	if not bool(gate.get("ok", false)):
		return gate
	return {"ok": true, "point": point, "part_id": part_id}


func _best_attach_existing_near_current(moving_index: int) -> Dictionary:
	if _session == null:
		return {"ok": false, "reason": "no session"}
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	if moving_index <= 0 or moving_index >= fold["parts"].size():
		return {"ok": false, "reason": "bad selected part"}
	var moving_path := _path_to_index(_session.root(), moving_index)
	if moving_path.is_empty():
		return {"ok": false, "reason": "missing selected path"}
	var moving_pos: Vector3 = fold["parts"][moving_index].xform.origin
	var best := {"ok": false, "reason": "no legal attach point"}
	var best_d := INF
	for part in fold["parts"]:
		var parent_index := int(part.index)
		if parent_index == moving_index:
			continue
		var parent_path := _path_to_index(_session.root(), parent_index)
		if _path_starts_with(parent_path, moving_path):
			continue
		var parent_gene := _gene_by_index(_session.root(), parent_index)
		if parent_gene == null:
			continue
		for point in SocketCatalog.points_for(parent_gene.definition):
			var wp: Vector3 = part.xform * point.local_pose.origin
			var result := _can_attach_existing(moving_index, parent_index, wp)
			if not bool(result.get("ok", false)):
				continue
			var d := moving_pos.distance_squared_to(wp)
			if d < best_d:
				best_d = d
				best = {"ok": true, "parent_index": parent_index, "world_point": wp,
						"distance_sq": d}
	return best


func _top_level_selected_indices() -> Array[int]:
	var out: Array[int] = []
	var paths := {}
	for idx in _selected_indices:
		if idx <= 0:
			continue
		paths[idx] = _path_to_index(_session.root(), idx)
	for idx in paths.keys():
		var path: Array = paths[idx]
		if path.is_empty():
			continue
		var covered := false
		for other in paths.keys():
			if int(other) == int(idx):
				continue
			var other_path: Array = paths[other]
			if not other_path.is_empty() and _path_starts_with(path, other_path):
				covered = true
				break
		if not covered:
			out.append(int(idx))
	out.sort()
	return out


func _mirror_gene_local_x(g: PartGene) -> void:
	if g == null:
		return
	if g.socket != null:
		g.socket.parent_attachment.origin.x *= -1.0
		g.socket.hinge_axis.x *= -1.0
	for child in g.children:
		_mirror_gene_local_x(child)


func _mirrored_point_id(socket_id: StringName) -> StringName:
	var point := String(SocketCatalog.point_id_for_socket_id(socket_id))
	if point.contains("left") or point.contains("right"):
		return StringName(point.replace("left", "__tmp__").replace("right", "left").replace("__tmp__", "right"))
	if point.contains("_L") or point.contains("_R"):
		return StringName(point.replace("_L", "__tmp__").replace("_R", "_L").replace("__tmp__", "_R"))
	if point.contains("BL") or point.contains("BR") or point.contains("FL") or point.contains("FR"):
		return StringName(point.replace("BL", "__tmp_bl__").replace("BR", "BL").replace("__tmp_bl__", "BR")
				.replace("FL", "__tmp_fl__").replace("FR", "FL").replace("__tmp_fl__", "FR"))
	return socket_id


func _update_hinge_guide() -> void:
	_hinge_guide_segments = 0
	if _hinge_guide == null:
		return
	_hinge_guide.visible = false
	if _session == null or _selected_indices.is_empty():
		_hinge_guide.mesh = null
		return
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	var mesh := ImmediateMesh.new()
	var begun := false
	for idx in _selected_indices:
		if idx <= 0 or idx >= fold["parts"].size():
			continue
		var part = fold["parts"][idx]
		var axis: Vector3 = part.hinge_axis
		if axis.length() <= 0.001:
			continue
		if not begun:
			mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			begun = true
		var world_axis: Vector3 = (part.xform.basis * axis.normalized()).normalized()
		var radius: float = maxf(part.world_aabb.size.length() * 0.35, 0.18)
		var center: Vector3 = part.xform.origin
		mesh.surface_add_vertex(center - world_axis * radius)
		mesh.surface_add_vertex(center + world_axis * radius)
		_hinge_guide_segments += 1
		var radial := Vector3.DOWN
		if absf(radial.dot(world_axis)) > 0.9:
			radial = Vector3.FORWARD
		radial = (radial - world_axis * radial.dot(world_axis)).normalized() * radius
		var g := _gene_by_index(_session.root(), idx)
		var a0 := -PI * 0.35
		var a1 := PI * 0.35
		if g != null and g.joint != null:
			a0 = g.joint.angle_min
			a1 = g.joint.angle_max
			if absf(a1 - a0) < 0.02:
				a0 = g.joint.rest_angle - 0.35
				a1 = g.joint.rest_angle + 0.35
		var steps := 12
		var prev := center + radial.rotated(world_axis, a0)
		for s in range(1, steps + 1):
			var t := float(s) / float(steps)
			var angle := lerpf(a0, a1, t)
			var next := center + radial.rotated(world_axis, angle)
			mesh.surface_add_vertex(prev)
			mesh.surface_add_vertex(next)
			_hinge_guide_segments += 1
			prev = next
	if begun:
		mesh.surface_end()
		_hinge_guide.mesh = mesh
		_hinge_guide.visible = _hinge_guide_segments > 0
	else:
		_hinge_guide.mesh = null


func hinge_guide_segments() -> int:
	return _hinge_guide_segments


func _gpu_diagnostics_text() -> String:
	var adapter := "unknown GPU"
	if RenderingServer.has_method("get_video_adapter_name"):
		adapter = str(RenderingServer.call("get_video_adapter_name"))
	var method := String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "Forward+"))
	var physics := String(ProjectSettings.get_setting("physics/3d/physics_engine", "default physics"))
	return "GPU %s | render %s | physics %s" % [adapter, method, physics]


func _editable_selected_indices(include_root := true) -> Array[int]:
	var out: Array[int] = []
	for idx in _selected_indices:
		if not include_root and idx <= 0:
			continue
		if idx < 0:
			continue
		if not out.has(idx):
			out.append(idx)
	if out.is_empty() and _selected_index >= 0 and (include_root or _selected_index > 0):
		out.append(_selected_index)
	return out


func _sync_part_list_selection() -> void:
	if _part_list == null:
		return
	_syncing_part_selection = true
	_part_list.deselect_all()
	for idx in _selected_indices:
		if idx >= 0 and idx < _part_list.item_count:
			_part_list.select(idx, false)
	if _selected_index >= 0 and _selected_index < _part_list.item_count:
		_part_list.ensure_current_is_visible()
	_syncing_part_selection = false


func _set_gene_muscle_amount(g: PartGene, amount: float, explicit_zero_removes := true) -> void:
	if g == null:
		return
	var tags: Array[StringName] = []
	for t in g.tags:
		if t != &"muscle":
			tags.append(t)
	var clamped := clampf(amount, 0.0, 4.0)
	if clamped > 0.0:
		tags.append(&"muscle")
		g.dial_values[&"muscle_amount"] = clamped
	elif explicit_zero_removes:
		g.dial_values.erase(&"muscle_amount")
	g.tags = tags


func _apply_global_muscle(g: PartGene, amount: float) -> void:
	if g == null:
		return
	if g.tags.has(&"locomotor"):
		_set_gene_muscle_amount(g, amount, true)
	for child in g.children:
		_apply_global_muscle(child, amount)


func _can_attach_existing(moving_index: int, parent_index: int, world_point: Vector3) -> Dictionary:
	if _session == null:
		return {"ok": false, "reason": "no session"}
	if moving_index <= 0:
		return {"ok": false, "reason": "root cannot be attached under another part"}
	if parent_index < 0:
		return {"ok": false, "reason": "missing target parent"}
	if moving_index == parent_index:
		return {"ok": false, "reason": "cannot attach a part to itself"}
	var moving_path := _path_to_index(_session.root(), moving_index)
	var parent_path := _path_to_index(_session.root(), parent_index)
	if moving_path.is_empty() or (parent_index > 0 and parent_path.is_empty()):
		return {"ok": false, "reason": "missing part path"}
	if _path_starts_with(parent_path, moving_path):
		return {"ok": false, "reason": "cannot attach a part inside its own subtree"}
	var nearest := ViewportDropTarget.nearest_attach_point(_session.root(), parent_index, world_point)
	if not bool(nearest.get("ok", false)):
		return nearest
	var point := nearest["point"] as AttachPoint
	var trial := GenomeSnapshot.deep_copy(_session.root())
	var parent := _gene_by_path(trial, parent_path)
	var moving := _detach_by_index(trial, moving_index)
	if parent == null or moving == null:
		return {"ok": false, "reason": "could not detach or find target"}
	var tags: Array[StringName] = []
	tags.assign(moving.tags)
	var gate := SocketCatalog.can_attach(parent, point.id, tags)
	if not bool(gate.get("ok", false)):
		return gate
	return {
		"ok": true,
		"point": point,
		"parent_path": parent_path,
		"moving_path": moving_path,
		"anchor": _anchor_for_child(moving),
	}


func _anchor_for_child(child: PartGene) -> StringName:
	if child == null:
		return &"center"
	# Attach elongated / limb-like parts by their proximal END (the joint), not their middle — that's the
	# "snaps to the middle of the segment instead of the joint" complaint. Round organs/sensors/fat sit
	# AT the point, so they keep the centre anchor.
	for t in [&"locomotor", &"ground_contact", &"leg", &"arm", &"tail", &"manipulator", &"muscle",
			&"tendon", &"attack", &"ankle", &"knee", &"spine"]:
		if child.tags.has(t):
			return &"top"
	if child.definition != null and (child.definition.part_type == &"capsule"
			or child.definition.part_type == &"cylinder"):
		return &"top"
	return &"center"


func _vitals_text(r: Dictionary) -> String:
	if _session == null:
		return "-"
	var counts := _tag_counts(_session.root(), [&"heart", &"brain", &"lung"])
	var debt: Dictionary = r.get("debt", {})
	var alive := bool(debt.get("alive", true))
	var fatal: Array = debt.get("fatal_reasons", [])
	var state := "alive" if alive else "dead: %s" % ", ".join(fatal)
	return "H%d B%d L%d  %s  supply/demand %.2f" % [
		int(counts.get(&"heart", 0)),
		int(counts.get(&"brain", 0)),
		int(counts.get(&"lung", 0)),
		state,
		float(debt.get("supply", 0.0)) / maxf(float(debt.get("demand", 0.0)), 0.000001),
	]


func _tag_counts(root_gene: PartGene, tags: Array[StringName]) -> Dictionary:
	var counts := {}
	for t in tags:
		counts[t] = 0
	_count_tags_walk(root_gene, counts)
	return counts


func _count_tags_walk(g: PartGene, counts: Dictionary) -> void:
	if g == null:
		return
	for t in g.tags:
		if counts.has(t):
			counts[t] = int(counts[t]) + 1
	for child in g.children:
		_count_tags_walk(child, counts)


func _attachment_short_text(part) -> String:
	if int(part.index) == 0:
		return "root"
	var socket_id := "nosocket" if part.socket == null else String(part.socket.id)
	var hinge := "hinge" if part.hinge_axis.length() > 0.001 else "rigid"
	return "p%02d %s %s" % [int(part.parent), socket_id, hinge]


func _attachment_detail_text(part) -> String:
	if int(part.index) == 0:
		return "Root body: attached by definition."
	var socket_id := "missing socket" if part.socket == null else String(part.socket.id)
	var hinge: Vector3 = Vector3.ZERO if part.socket == null else part.socket.hinge_axis
	return "Attached to parent %02d via socket '%s'. Hinge axis: %s. %s" % [
		int(part.parent),
		socket_id,
		str(hinge),
		"Powered/rotating if hinge is non-zero and a joint/gait drive exists." if hinge.length() > 0.001 else "Rigid/welded attachment.",
	]


func _selected_attachment_status() -> String:
	if _session == null:
		return ""
	var fold := CE.fold_graph(_session.root(), Transform3D.IDENTITY)
	if _selected_index < 0 or _selected_index >= fold["parts"].size():
		return ""
	var suffix := "" if _selected_indices.size() <= 1 else "  (%d selected; metrics edit all selected)" % _selected_indices.size()
	return _attachment_detail_text(fold["parts"][_selected_index]) + suffix


func _gene_by_index(root: PartGene, index: int) -> PartGene:
	var counter := [0]
	return _gene_by_index_walk(root, index, counter)


func _gene_by_index_walk(g: PartGene, index: int, counter: Array) -> PartGene:
	if g == null:
		return null
	if int(counter[0]) == index:
		return g
	counter[0] = int(counter[0]) + 1
	for child in g.children:
		var found := _gene_by_index_walk(child, index, counter)
		if found != null:
			return found
	return null


func _parent_of_index(root: PartGene, index: int) -> PartGene:
	if index <= 0:
		return null
	var counter := [0]
	return _parent_of_index_walk(root, index, counter, null)


func _parent_of_index_walk(g: PartGene, index: int, counter: Array, parent: PartGene) -> PartGene:
	if g == null:
		return null
	if int(counter[0]) == index:
		return parent
	counter[0] = int(counter[0]) + 1
	for child in g.children:
		var found := _parent_of_index_walk(child, index, counter, g)
		if found != null:
			return found
	return null


func _path_to_index(root: PartGene, index: int) -> Array:
	var counter := [0]
	var path: Array = []
	if _path_to_index_walk(root, index, counter, [], path):
		return path
	return []


func _path_to_index_walk(g: PartGene, index: int, counter: Array,
		current_path: Array, out_path: Array) -> bool:
	if g == null:
		return false
	if int(counter[0]) == index:
		out_path.assign(current_path)
		return true
	counter[0] = int(counter[0]) + 1
	for i in g.children.size():
		var child_path := current_path.duplicate()
		child_path.append(i)
		if _path_to_index_walk(g.children[i], index, counter, child_path, out_path):
			return true
	return false


func _gene_by_path(root: PartGene, path: Array) -> PartGene:
	var g := root
	for p in path:
		if g == null:
			return null
		var i := int(p)
		if i < 0 or i >= g.children.size():
			return null
		g = g.children[i]
	return g


func _path_starts_with(path: Array, prefix: Array) -> bool:
	if prefix.size() > path.size():
		return false
	for i in prefix.size():
		if int(path[i]) != int(prefix[i]):
			return false
	return true


func _index_for_socket_id(root: PartGene, socket_id: StringName) -> int:
	var counter := [0]
	return _index_for_socket_id_walk(root, socket_id, counter)


func _index_for_socket_id_walk(g: PartGene, socket_id: StringName, counter: Array) -> int:
	if g == null:
		return -1
	if g.socket_id == socket_id and socket_id != &"":
		return int(counter[0])
	counter[0] = int(counter[0]) + 1
	for child in g.children:
		var found := _index_for_socket_id_walk(child, socket_id, counter)
		if found >= 0:
			return found
	return -1


func _remove_by_index(root: PartGene, index: int) -> bool:
	var parent := _parent_of_index(root, index)
	if parent == null:
		return false
	var target := _gene_by_index(root, index)
	var pos := parent.children.find(target)
	if pos < 0:
		return false
	parent.children.remove_at(pos)
	return true


func _detach_by_index(root: PartGene, index: int) -> PartGene:
	var parent := _parent_of_index(root, index)
	if parent == null:
		return null
	var target := _gene_by_index(root, index)
	if target == null:
		return null
	var pos := parent.children.find(target)
	if pos < 0:
		return null
	parent.children.remove_at(pos)
	return target


func _default_child_socket(parent: PartGene, id: StringName) -> SocketDef:
	var s := SocketDef.new()
	s.id = id
	s.display_name = String(id)
	var e := Vector3.ONE
	if parent != null and parent.definition != null:
		e = parent.definition.extents
	s.parent_attachment = Transform3D(Basis.IDENTITY, Vector3(0.0, -e.y, 0.0))
	s.child_anchor = Transform3D.IDENTITY
	s.hinge_axis = Vector3.ZERO
	return s


func _unique_socket_id(parent: PartGene, base: StringName) -> StringName:
	var used := {}
	for child in parent.children:
		used[child.socket_id] = true
	var stem := String(base if base != &"" else &"socket")
	var candidate := StringName(stem)
	var i := 1
	while used.has(candidate):
		candidate = StringName("%s_%d" % [stem, i])
		i += 1
	return candidate


func _valid_scale(v: Vector3) -> Vector3:
	return Vector3(maxf(v.x, 0.05), maxf(v.y, 0.05), maxf(v.z, 0.05))


func _valid_extents(v: Vector3) -> Vector3:
	return Vector3(maxf(v.x, 0.02), maxf(v.y, 0.02), maxf(v.z, 0.02))


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	return l


# M54: a collapsible section. Adds a ▾/▸ toggle button to `parent` and returns a content VBox
# (also added to `parent`) for callers to fill. Open/closed state lives in _settings keyed by
# `key`, so it survives a card reload within the session.
func _collapsible_section(parent: VBoxContainer, title: String, key: StringName,
		default_open := true) -> VBoxContainer:
	var open := bool(_settings.get(key, default_open))
	_settings[key] = open
	var content := VBoxContainer.new()
	content.visible = open
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = open
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 16)
	btn.text = "%s  %s" % ["▾" if open else "▸", title]
	btn.tooltip_text = "Collapse/expand the %s section." % title
	btn.toggled.connect(func(pressed: bool):
		content.visible = pressed
		_settings[key] = pressed
		btn.text = "%s  %s" % ["▾" if pressed else "▸", title])
	parent.add_child(btn)
	parent.add_child(content)
	return content


# M54 (B8): jump to the chosen creature group from the tab overflow menu.
func _on_tab_overflow_selected(id: int) -> void:
	if _creature_tabs != null and id >= 0 and id < _creature_tabs.get_tab_count():
		_creature_tabs.current_tab = id


# M54 (B8): rebuild the overflow popup to list every current creature group.
func _refresh_tab_overflow() -> void:
	if _tab_overflow_popup == null or _creature_tabs == null:
		return
	_tab_overflow_popup.clear()
	for i in _creature_tabs.get_tab_count():
		_tab_overflow_popup.add_item(_creature_tabs.get_tab_title(i), i)


# M54 (B11): refresh the one-line parts breadcrumb from the cached names + current selection.
func _update_parts_breadcrumb() -> void:
	if _parts_breadcrumb == null:
		return
	var n := _part_names.size()
	var expanded := _part_list != null and _part_list.visible
	var arrow := "▾" if expanded else "▸"
	var shown := PackedStringArray()
	var more := ""
	if not _selected_indices.is_empty():
		for idx in _selected_indices:
			if idx >= 0 and idx < n:
				shown.append(_part_names[idx])
	else:
		for i in mini(n, 4):
			shown.append(_part_names[i])
		if n > 4:
			more = " …"
	_parts_breadcrumb.text = "Parts: %s%s  %s (%d)" % [" · ".join(shown), more, arrow, n]


func _breadcrumb_name(part) -> String:
	if int(part.index) == 0:
		return "body"
	if part.socket != null and String(part.socket.id) != "":
		return String(part.socket.id)
	return String(part.definition.part_type)


func _spin(min_value: float, max_value: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_value
	s.max_value = max_value
	s.step = step
	s.value = 1.0
	s.custom_minimum_size = Vector2(72, 0)
	return s


func _row(label: String, control: Control, tip := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(70, 0)
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.tooltip_text = tip
	row.add_child(control)
	return row


func _vec_row(label: String, spins: Array, on_change: Callable, tip := "",
		field_labels: Array = []) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(70, 0)
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(l)
	for i in spins.size():
		var s: SpinBox = spins[i]
		if i < field_labels.size():
			# Axis/field tag right before its number (x/y/z or amp/rest/min/max) so the columns are legible.
			var fl := Label.new()
			fl.text = String(field_labels[i])
			fl.tooltip_text = tip
			fl.mouse_filter = Control.MOUSE_FILTER_PASS
			row.add_child(fl)
		s.tooltip_text = tip
		s.value_changed.connect(on_change)
		row.add_child(s)
	return row


func _button(text: String, tip: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(on_press)
	return b


func _labeled_spin(parent: VBoxContainer, label: String, min_value: float, max_value: float,
		step: float, value: float, tip: String) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_value
	s.max_value = max_value
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_row(label, s, tip))
	return s


func _labeled_check(parent: VBoxContainer, label: String, pressed: bool, tip: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = pressed
	c.tooltip_text = tip
	parent.add_child(c)
	return c


func _safe_file_stem(raw: String) -> String:
	var s := raw.strip_edges().to_lower()
	if s == "":
		s = "untitled"
	var out := ""
	for i in s.length():
		var ch := s[i]
		var ok := (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")
		out += ch if ok else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.trim_prefix("_").trim_suffix("_")
	return "untitled" if out == "" else out


func _select_part_type(part_type: StringName) -> void:
	for i in _type_option.item_count:
		if StringName(_type_option.get_item_text(i)) == part_type:
			_type_option.select(i)
			return
	_type_option.select(0)


# M44: select an OptionButton entry by its visible text (no-op-safe if absent).
func _select_option_text(option: OptionButton, text: String) -> void:
	for i in option.item_count:
		if option.get_item_text(i) == text:
			option.select(i)
			return
	option.select(0)


func _tag_text(tags: Dictionary) -> String:
	var names: Array[String] = []
	for k in tags.keys():
		names.append(String(k))
	names.sort()
	return ",".join(names)
