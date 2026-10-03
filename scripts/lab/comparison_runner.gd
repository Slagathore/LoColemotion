class_name LabComparisonRunner
extends RefCounted

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")


static func compare_specs(
		comparison_id: String,
		control_run_id: String,
		intervention_run_id: String,
		control_spec: Dictionary,
		intervention_spec: Dictionary,
		declared_path: String) -> Dictionary:
	var diff_paths: Array = []
	_collect_diff_paths(control_spec, intervention_spec, "", diff_paths)
	diff_paths.sort()
	var valid := diff_paths == [declared_path]
	var control_base := control_spec.duplicate(true)
	var intervention_base := intervention_spec.duplicate(true)
	_remove_pointer(control_base, declared_path)
	_remove_pointer(intervention_base, declared_path)
	var base_equal := CanonicalJsonScript.sha256(control_base) == CanonicalJsonScript.sha256(
		intervention_base)
	valid = valid and base_equal
	return FrozenValueScript.snapshot({
		"schema": "sporespore.lab.comparison.v1",
		"comparison_id": comparison_id,
		"control_run_id": control_run_id,
		"intervention_run_id": intervention_run_id,
		"declared_independent_variable": {"path": declared_path},
		"declared_diff_paths": diff_paths,
		"paired_base_spec_sha256": CanonicalJsonScript.sha256(control_base),
		"control_expanded_spec_sha256": CanonicalJsonScript.sha256(control_spec),
		"intervention_expanded_spec_sha256": CanonicalJsonScript.sha256(intervention_spec),
		"evidence_validity": "valid" if valid else "invalid",
		"conclusion": "inconclusive" if valid else "undeclared_difference",
	})


static func _collect_diff_paths(a: Variant, b: Variant, path: String, result: Array) -> void:
	if typeof(a) != typeof(b):
		result.append(path if not path.is_empty() else "/")
		return
	if a is Dictionary:
		var keys: Array = []
		for key in a.keys():
			if not keys.has(String(key)):
				keys.append(String(key))
		for key in b.keys():
			if not keys.has(String(key)):
				keys.append(String(key))
		keys.sort()
		for key in keys:
			var child_path := "%s/%s" % [path, _escape_pointer(key)]
			if not a.has(key) or not b.has(key):
				result.append(child_path)
			else:
				_collect_diff_paths(a[key], b[key], child_path, result)
	elif a is Array:
		if a.size() != b.size():
			result.append(path)
		else:
			for index in a.size():
				_collect_diff_paths(a[index], b[index], "%s/%d" % [path, index], result)
	elif a != b:
		result.append(path)


static func _remove_pointer(value: Dictionary, pointer: String) -> void:
	var pieces := pointer.trim_prefix("/").split("/")
	var cursor: Variant = value
	for index in range(pieces.size() - 1):
		var key := pieces[index].replace("~1", "/").replace("~0", "~")
		if not cursor is Dictionary or not cursor.has(key):
			return
		cursor = cursor[key]
	if cursor is Dictionary and not pieces.is_empty():
		var last := pieces[pieces.size() - 1].replace("~1", "/").replace("~0", "~")
		cursor.erase(last)


static func _escape_pointer(value: String) -> String:
	return value.replace("~", "~0").replace("/", "~1")
