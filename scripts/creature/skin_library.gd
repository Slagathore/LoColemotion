class_name SkinLibrary
extends RefCounted

## Visual-only material library. Defaults to committed/project assets when
## present and otherwise returns deterministic tinted fallback materials.

const DEFAULT_DIR := "res://assets/skins"


static func materials(dir := DEFAULT_DIR) -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = []
	var da := DirAccess.open(dir)
	if da != null:
		da.list_dir_begin()
		while true:
			var file_name := da.get_next()
			if file_name == "":
				break
			if da.current_is_dir():
				continue
			var ext := file_name.get_extension().to_lower()
			if not ["png", "jpg", "jpeg", "webp", "dds"].has(ext):
				continue
			var tex := ResourceLoader.load(dir.path_join(file_name)) as Texture2D
			if tex == null:
				continue
			var mat := _base_material(Color.WHITE)
			mat.albedo_texture = tex
			out.append(mat)
		da.list_dir_end()
	if out.is_empty():
		out.append(_base_material(Color(0.62, 0.47, 0.74)))
	return out


static func material_for(seed_or_tag = 0, dir := DEFAULT_DIR) -> StandardMaterial3D:
	var mats := materials(dir)
	var idx: int = int(abs(hash(str(seed_or_tag)))) % mats.size()
	return mats[idx]


static func _base_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	return mat
