class_name PartPalette
extends TabContainer

## Tabbed drag source for part templates. Built-ins come from PartCatalog; custom
## saved subtrees live in res://data/parts as PartGene resources.

signal item_selected(index: int)
signal item_activated(index: int)

const CUSTOM_DIR := "res://data/parts"
const CUSTOM_PREFIX := "custom:"

var _entries: Array[Dictionary] = []


func _ready() -> void:
	populate()


func populate() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_entries.clear()
	var groups := {
		"Bodies": [],
		"Limbs": [],
		"Organs": [],
		"Tissue": [],
		"Tools": [],
		"Custom": [],
	}
	for id in PartCatalog.template_ids():
		var gene := PartCatalog.clone_template(id)
		if gene == null:
			continue
		var entry := _make_entry(id, String(id), gene, false, "")
		groups[_category_for(gene, id)].append(entry)
	for entry in _scan_custom_parts():
		groups["Custom"].append(entry)
	for tab_name in ["Bodies", "Limbs", "Organs", "Tissue", "Tools", "Custom"]:
		_add_tab(tab_name, groups[tab_name])


func drag_data_for_index(index: int) -> Dictionary:
	if index < 0 or index >= _entries.size():
		return {}
	var entry := _entries[index]
	return {"type": "part_template", "id": StringName(entry["id"])}


func entry_count() -> int:
	return _entries.size()


func has_part_id(part_id: StringName) -> bool:
	var id := String(part_id)
	for entry in _entries:
		if String(entry["id"]) == id:
			return true
	return false


func clone_part(part_id: StringName) -> PartGene:
	var id := String(part_id)
	for entry in _entries:
		if String(entry["id"]) == id:
			return GenomeSnapshot.deep_copy(entry["gene"])
	return PartCatalog.clone_template(part_id)


func save_custom_part(display_name: String, gene: PartGene) -> Error:
	if gene == null:
		return ERR_INVALID_PARAMETER
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CUSTOM_DIR))
	var stem := _safe_file_stem(display_name)
	var path := CUSTOM_DIR.path_join("%s.tres" % stem)
	var copy := GenomeSnapshot.deep_copy(gene)
	copy.part_id = StringName("%s%s" % [CUSTOM_PREFIX, stem])
	var err := ResourceSaver.save(copy, path)
	if err == OK:
		populate()
	return err


func deselect_all() -> void:
	for child in get_children():
		var list := child as ItemList
		if list != null:
			list.deselect_all()


func _get_drag_data(pos: Vector2) -> Variant:
	var list := get_current_tab_control() as ItemList
	if list == null:
		return null
	var local_pos := list.get_local_mouse_position()
	var idx := list.get_item_at_position(local_pos, true)
	if idx < 0:
		return null
	var entry_index := int(list.get_item_metadata(idx))
	var data := drag_data_for_index(entry_index)
	if data.is_empty():
		return null
	var label := Label.new()
	label.text = String(data["id"])
	set_drag_preview(label)
	return data


func _add_tab(tab_name: String, rows: Array) -> void:
	var list := ItemList.new()
	list.name = tab_name
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.tooltip_text = "Click to arm a part, double-click to attach to the selected creature part, or drag into the viewport."
	list.item_selected.connect(_on_list_selected.bind(list))
	list.item_activated.connect(_on_list_activated.bind(list))
	for row in rows:
		var entry: Dictionary = row
		var global_index := _entries.size()
		_entries.append(entry)
		list.add_item(String(entry["label"]))
		list.set_item_metadata(list.item_count - 1, global_index)
		list.set_item_tooltip(list.item_count - 1, _entry_tooltip(entry))
	add_child(list)


func _on_list_selected(local_index: int, list: ItemList) -> void:
	if list == null or local_index < 0:
		return
	item_selected.emit(int(list.get_item_metadata(local_index)))


func _on_list_activated(local_index: int, list: ItemList) -> void:
	if list == null or local_index < 0:
		return
	item_activated.emit(int(list.get_item_metadata(local_index)))


func _make_entry(id: StringName, label: String, gene: PartGene, custom: bool,
		path: String) -> Dictionary:
	return {"id": String(id), "label": label, "gene": gene, "custom": custom, "path": path}


func _scan_custom_parts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var da := DirAccess.open(CUSTOM_DIR)
	if da == null:
		return out
	da.list_dir_begin()
	while true:
		var file_name := da.get_next()
		if file_name == "":
			break
		if da.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		var path := CUSTOM_DIR.path_join(file_name)
		var gene := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PartGene
		if gene == null:
			continue
		var stem := file_name.get_basename()
		out.append(_make_entry(StringName("%s%s" % [CUSTOM_PREFIX, stem]), stem,
				GenomeSnapshot.deep_copy(gene), true, path))
	da.list_dir_end()
	out.sort_custom(func(a, b): return String(a["label"]).naturalnocasecmp_to(String(b["label"])) < 0)
	return out


func _category_for(gene: PartGene, id: StringName) -> String:
	if gene.tags.has(&"heart") or gene.tags.has(&"brain") or gene.tags.has(&"lung"):
		return "Organs"
	if gene.tags.has(&"muscle") or gene.tags.has(&"tendon") or gene.tags.has(&"fat") or gene.tags.has(&"armor"):
		return "Tissue"
	if gene.tags.has(&"locomotor") or gene.tags.has(&"ground_contact") or gene.tags.has(&"manipulator"):
		return "Limbs"
	if gene.tags.has(&"sensor") or gene.tags.has(&"attack"):
		return "Tools"
	if gene.tags.has(&"spine") or String(id).begins_with("body_") or String(id).begins_with("primitive_"):
		return "Bodies"
	return "Tools"


func _entry_tooltip(entry: Dictionary) -> String:
	var gene := entry["gene"] as PartGene
	var tags := PackedStringArray()
	if gene != null:
		for t in gene.tags:
			tags.append(String(t))
	return "%s\n%s" % [String(entry["id"]), ", ".join(tags)]


func _safe_file_stem(raw: String) -> String:
	var s := raw.strip_edges().to_lower()
	if s == "":
		s = "part"
	var out := ""
	for i in s.length():
		var ch := s[i]
		var ok := (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")
		out += ch if ok else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.trim_prefix("_").trim_suffix("_")
	return "part" if out == "" else out
