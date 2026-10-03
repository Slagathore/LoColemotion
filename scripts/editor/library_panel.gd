class_name LibraryPanel
extends VBoxContainer

## Small creature browser panel. It delegates persistence to CreatureLibrary and
## emits a fully isolated CreatureCard when a row is opened.

signal open_card(card: CreatureCard)

var library: CreatureLibrary

var _list: ItemList
var _rename_edit: LineEdit
var _status: Label
var _confirm_delete: ConfirmationDialog


func _ready() -> void:
	if library == null:
		library = CreatureLibrary.new()
	_build_ui()
	refresh()


func set_library(next: CreatureLibrary) -> void:
	library = next
	if is_node_ready():
		refresh()


func refresh() -> void:
	if _list == null or library == null:
		return
	_list.clear()
	var rows := library.all()
	for row in rows:
		var label := String(row.get("name", "Untitled"))
		if bool(row.get("builtin", false)):
			label += " *"
		_list.add_item(label)
	_list.set_meta("rows", rows)


func _build_ui() -> void:
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_activated.connect(_open_index)
	_list.item_selected.connect(func(_idx): _sync_rename())
	add_child(_list)

	var buttons := HBoxContainer.new()
	add_child(buttons)
	var open_btn := Button.new()
	open_btn.text = "Open"
	open_btn.pressed.connect(func(): _open_index(_list.get_selected_items()[0] if _list.get_selected_items().size() > 0 else -1))
	buttons.add_child(open_btn)
	var dup_btn := Button.new()
	dup_btn.text = "Duplicate"
	dup_btn.pressed.connect(_duplicate_selected)
	buttons.add_child(dup_btn)
	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.pressed.connect(_ask_delete)
	buttons.add_child(del_btn)

	var rename_row := HBoxContainer.new()
	add_child(rename_row)
	_rename_edit = LineEdit.new()
	_rename_edit.placeholder_text = "Name"
	_rename_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_row.add_child(_rename_edit)
	var rename_btn := Button.new()
	rename_btn.text = "Rename"
	rename_btn.pressed.connect(_rename_selected)
	rename_row.add_child(rename_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

	_confirm_delete = ConfirmationDialog.new()
	_confirm_delete.confirmed.connect(_delete_selected)
	add_child(_confirm_delete)


func _selected_row() -> Dictionary:
	if _list == null:
		return {}
	var selected := _list.get_selected_items()
	if selected.is_empty():
		return {}
	var rows: Array = _list.get_meta("rows", [])
	var idx := int(selected[0])
	if idx < 0 or idx >= rows.size():
		return {}
	return (rows[idx] as Dictionary).duplicate()


func _open_index(index: int) -> void:
	if index < 0:
		return
	var rows: Array = _list.get_meta("rows", [])
	if index >= rows.size():
		return
	var card := library.load_row(rows[index])
	if card == null:
		_status.text = "Open failed"
		return
	open_card.emit(card)
	_status.text = "Opened %s" % card.display_name


func _duplicate_selected() -> void:
	var row := _selected_row()
	if row.is_empty():
		return
	var base := String(row.get("name", "Creature"))
	var err := library.duplicate_card(row, "%s Copy" % base)
	_status.text = "Duplicated" if err == OK else "Duplicate failed: %s" % err
	refresh()


func _ask_delete() -> void:
	var row := _selected_row()
	if row.is_empty() or bool(row.get("builtin", false)):
		_status.text = "Built-ins cannot be deleted"
		return
	_confirm_delete.dialog_text = "Delete %s?" % String(row.get("name", "creature"))
	_confirm_delete.popup_centered()


func _delete_selected() -> void:
	var row := _selected_row()
	if row.is_empty():
		return
	var err := library.remove(String(row.get("path", "")))
	_status.text = "Deleted" if err == OK else "Delete failed: %s" % err
	refresh()


func _rename_selected() -> void:
	var row := _selected_row()
	if row.is_empty() or bool(row.get("builtin", false)):
		_status.text = "Built-ins cannot be renamed"
		return
	var err := library.rename(String(row.get("path", "")), _rename_edit.text)
	_status.text = "Renamed" if err == OK else "Rename failed: %s" % err
	refresh()


func _sync_rename() -> void:
	var row := _selected_row()
	if not row.is_empty():
		_rename_edit.text = String(row.get("name", ""))
