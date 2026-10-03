class_name MonsterPartRegistry
extends RefCounted

## Manifest-backed authored part mesh registry.
##
## This is the handoff seam for the future art-asset pipeline: artists/tools can
## emit stable part IDs and mesh resource paths, while the editor/runtime keep using
## primitive fallback when an authored mesh is absent or invalid.


static func load_manifest(path: String) -> Dictionary:
	var result := validate_manifest(path)
	for row in result.get("registered", []):
		PartMeshProvider.register_authored(StringName(String(row.get("id", ""))),
				String(row.get("mesh", "")))
	return result


static func validate_manifest(path: String) -> Dictionary:
	var out := {
		"ok": false,
		"path": path,
		"registered": [],
		"missing": [],
		"invalid": [],
		"errors": [],
	}
	if not FileAccess.file_exists(path):
		out["errors"].append("manifest not found: %s" % path)
		return out
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	if not (data is Dictionary):
		out["errors"].append("manifest is not a JSON object")
		return out
	var entries = (data as Dictionary).get("parts", [])
	if not (entries is Array):
		out["errors"].append("manifest.parts must be an array")
		return out
	for entry in entries:
		if not (entry is Dictionary):
			out["invalid"].append({"entry": entry, "reason": "part entry is not an object"})
			continue
		var row: Dictionary = entry
		var id := String(row.get("id", ""))
		var mesh_path := String(row.get("mesh", row.get("path", "")))
		if id.strip_edges() == "":
			out["invalid"].append({"entry": row, "reason": "missing id"})
			continue
		if mesh_path.strip_edges() == "":
			out["invalid"].append({"id": id, "reason": "missing mesh path"})
			continue
		if not ResourceLoader.exists(mesh_path):
			out["missing"].append({"id": id, "mesh": mesh_path})
			continue
		if not _is_mesh_resource(mesh_path):
			out["invalid"].append({"id": id, "mesh": mesh_path, "reason": "resource is not Mesh or PackedScene with a MeshInstance3D"})
			continue
		out["registered"].append({"id": id, "mesh": mesh_path})
	out["ok"] = (out["errors"] as Array).is_empty() and (out["invalid"] as Array).is_empty() \
			and (out["missing"] as Array).is_empty()
	return out


static func _is_mesh_resource(path: String) -> bool:
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res is Mesh:
		return true
	if res is PackedScene:
		var inst := (res as PackedScene).instantiate()
		var has_mesh := _find_mesh(inst) != null
		inst.queue_free()
		return has_mesh
	return false


static func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and node.mesh != null:
		return node.mesh
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null
