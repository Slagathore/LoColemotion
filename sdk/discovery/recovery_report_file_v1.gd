extends RefCounted
## Same sorted full-precision JSON transport, emitted in bounded pieces.
## Nothing is sampled, rounded, omitted, or replaced by a derived measurement.
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const FILE_NAME := "worker-streamed-report.json"
const MARKER := "DISCOVERY_FULL_REPORT_FILE "

static func write_new(path: String, value: Dictionary) -> Dictionary:
	var pending := path + ".partial"
	if FileAccess.file_exists(path) or FileAccess.file_exists(pending):
		return {"ok":false,"failure_code":"REPORT_FILE_EXISTS"}
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null: return {"ok":false,"failure_code":"REPORT_FILE_OPEN"}
	_write(file, value)
	file.flush()
	var size := file.get_length()
	var error := file.get_error()
	file.close()
	if error != OK: return {"ok":false,"failure_code":"REPORT_FILE_WRITE"}
	if FileAccess.file_exists(path) or DirAccess.rename_absolute(pending,path) != OK:
		return {"ok":false,"failure_code":"REPORT_FILE_FINALIZE"}
	return {"ok":true,"path":path,"byte_length":size,"raw_sha256":"sha256:"+FileAccess.get_sha256(path),
		"transport_id":Transport.TRANSPORT_ID,"telemetry_reduced":false}

static func _write(file: FileAccess, value: Variant) -> void:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		file.store_string("{")
		for index in range(keys.size()):
			if index: file.store_string(",")
			file.store_string(Transport.stringify(keys[index])+":")
			_write(file,value[keys[index]])
		file.store_string("}")
	elif value is Array and value.size() > 64:
		file.store_string("[")
		for index in range(value.size()):
			if index: file.store_string(",")
			# Each entry is one original complete packet or trace row. This avoids
			# building a second String containing the whole retained population.
			file.store_string(Transport.stringify(value[index]))
		file.store_string("]")
	else:
		file.store_string(Transport.stringify(value))
