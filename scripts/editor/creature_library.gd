class_name CreatureLibrary
extends RefCounted

## In-memory browser model over CreatureIO.scan(). Built-ins are represented as
## rows, saved cards are lazy-loaded through CreatureIO.load().

signal changed

var directory := CreatureIO.DEFAULT_DIR
var include_builtins := true

var _rows: Array[Dictionary] = []


func _init(p_directory := CreatureIO.DEFAULT_DIR, p_include_builtins := true) -> void:
	directory = p_directory
	include_builtins = p_include_builtins
	refresh()


func refresh() -> Array[Dictionary]:
	_rows = CreatureIO.scan(directory, include_builtins)
	changed.emit()
	return all()


func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in _rows:
		out.append(row.duplicate())
	return out


func by_name(name: String) -> Dictionary:
	for row in _rows:
		if String(row.get("name", "")) == name:
			return row.duplicate()
	return {}


func load_row(row: Dictionary) -> CreatureCard:
	var card: CreatureCard = row.get("card", null)
	if card != null:
		return _isolate_card(card)
	var path := String(row.get("path", ""))
	if path == "":
		return null
	return CreatureIO.load(path)


func add(card: CreatureCard, path := "") -> Error:
	if card == null:
		return ERR_INVALID_PARAMETER
	var save_path := path
	if save_path == "":
		save_path = directory.path_join("%s.tres" % _safe_file_stem(card.display_name))
	var err := CreatureIO.save(card, save_path)
	if err == OK:
		refresh()
	return err


func remove(path: String) -> Error:
	if path == "":
		return ERR_INVALID_PARAMETER
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if err == OK:
		refresh()
	return err


func rename(path: String, new_name: String) -> Error:
	if path == "" or new_name.strip_edges() == "":
		return ERR_INVALID_PARAMETER
	var card := CreatureIO.load(path)
	if card == null:
		return ERR_INVALID_DATA
	var new_path := directory.path_join("%s.tres" % _safe_file_stem(new_name))
	card.display_name = new_name
	var save_err := CreatureIO.save(card, new_path)
	if save_err != OK:
		return save_err
	var old_abs := ProjectSettings.globalize_path(path)
	var new_abs := ProjectSettings.globalize_path(new_path)
	if old_abs != new_abs and FileAccess.file_exists(path):
		var remove_err := DirAccess.remove_absolute(old_abs)
		if remove_err != OK:
			return remove_err
	refresh()
	return OK


func duplicate_card(row: Dictionary, new_name: String) -> Error:
	var card := load_row(row)
	if card == null:
		return ERR_INVALID_DATA
	card.display_name = new_name
	return add(card)


func _isolate_card(card: CreatureCard) -> CreatureCard:
	var copy := CreatureCard.new()
	copy.display_name = card.display_name
	copy.schema_version = card.schema_version
	copy.notes = card.notes
	copy.root = GenomeSnapshot.deep_copy(card.root)
	return copy


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
