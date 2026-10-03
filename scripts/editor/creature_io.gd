class_name CreatureIO
extends RefCounted

## Save/load/scan helpers for embedded CreatureCard resources.

const DEFAULT_DIR := "res://data/creatures"


static func save(card: CreatureCard, path: String) -> Error:
	if card == null or card.root == null:
		push_error("CreatureIO.save: card/root is null")
		return ERR_INVALID_PARAMETER
	if card.schema_version > CreatureMigrations.CURRENT:
		push_error("CreatureIO.save: future schema %d is not supported" % card.schema_version)
		return ERR_INVALID_DATA
	var chk := GenomeSnapshot.validate_unique(card.root)
	if not bool(chk["ok"]):
		push_error("CreatureIO.save: invalid genome: %s" % chk["error"])
		return ERR_INVALID_DATA
	_ensure_parent_dir(path)
	var frozen := CreatureCard.new()
	frozen.display_name = card.display_name
	frozen.schema_version = CreatureMigrations.CURRENT
	frozen.notes = card.notes
	frozen.palette = card.palette.duplicate(true)   # M51: carry the display palette
	frozen.root = GenomeSnapshot.deep_copy(card.root)
	return ResourceSaver.save(frozen, path)


static func load(path: String) -> CreatureCard:
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var card := res as CreatureCard
	if card == null:
		push_error("CreatureIO.load: '%s' is not a CreatureCard" % path)
		return null
	if card.schema_version > CreatureMigrations.CURRENT:
		push_error("CreatureIO.load: '%s' schema %d is newer than supported %d" %
				[path, card.schema_version, CreatureMigrations.CURRENT])
		return null
	if card.schema_version < CreatureMigrations.CURRENT:
		card = CreatureMigrations.migrate(card)
		if card == null:
			push_error("CreatureIO.load: '%s' migration failed" % path)
			return null
	if card.root == null:
		push_error("CreatureIO.load: '%s' has no root genome" % path)
		return null
	var chk := GenomeSnapshot.validate_unique(card.root)
	if not bool(chk["ok"]):
		push_error("CreatureIO.load: '%s' has invalid genome: %s" % [path, chk["error"]])
		return null
	var isolated := CreatureCard.new()
	isolated.display_name = card.display_name
	isolated.schema_version = CreatureMigrations.CURRENT
	isolated.notes = card.notes
	isolated.palette = card.palette.duplicate(true)   # M51: carry the display palette
	isolated.root = GenomeSnapshot.deep_copy(card.root)
	return isolated


static func scan(dir := DEFAULT_DIR, include_builtins := true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if include_builtins:
		for card in PartCatalog.built_in_cards():
			out.append({"name": card.display_name, "path": "", "card": card, "builtin": true})

	var da := DirAccess.open(dir)
	if da == null:
		return out
	da.list_dir_begin()
	while true:
		var file_name := da.get_next()
		if file_name == "":
			break
		if da.current_is_dir():
			continue
		if not file_name.ends_with(".tres"):
			continue
		var path := dir.path_join(file_name)
		out.append({"name": file_name.get_basename(), "path": path, "card": null, "builtin": false})
	da.list_dir_end()
	out.sort_custom(func(a, b): return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	return out


static func _ensure_parent_dir(path: String) -> void:
	var base := path.get_base_dir()
	if base == "" or base == "res://" or base == "user://":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base))
