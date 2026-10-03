extends SceneTree
const Writer := preload("res://sdk/discovery/recovery_report_file_v1.gd")
const Transport := Writer.Transport
func _initialize() -> void:
	var folder := OS.get_cmdline_user_args()[0]
	var checks := {}
	var value := {"unicode_é":"漢字\n\t\"\\", "integer":9007199254740993,"float":0.12345678901234567,
		"negative_zero":-0.0,"nested":{"z":null,"a":[true,false,{},[]]},"rows":[]}
	for index in range(130): value.rows.append({"index":index,"nested":[index/7.0,"entry"]})
	var expected := Transport.stringify(value)
	var path := folder+"/stream-control.json"
	var result := Writer.write_new(path,value)
	checks["identical_utf8"] = result.get("ok") == true and FileAccess.get_file_as_string(path) == expected
	checks["identical_digest"] = result.get("raw_sha256") == "sha256:"+expected.sha256_text()
	checks["identical_length"] = result.get("byte_length") == expected.to_utf8_buffer().size()
	checks["no_partial_after_success"] = not FileAccess.file_exists(path+".partial")
	checks["overwrite_refused"] = Writer.write_new(path,{}).get("failure_code") == "REPORT_FILE_EXISTS"
	checks["original_preserved"] = FileAccess.get_file_as_string(path) == expected
	var partial := FileAccess.open(folder+"/incomplete.json.partial",FileAccess.WRITE)
	partial.store_string("incomplete");partial.close()
	checks["incomplete_refused"] = Writer.write_new(folder+"/incomplete.json",{}).get("failure_code") == "REPORT_FILE_EXISTS"
	checks["incomplete_not_published"] = not FileAccess.file_exists(folder+"/incomplete.json")
	var ok := not checks.values().has(false)
	var out := FileAccess.open(folder+"/stream-controls-result.json",FileAccess.WRITE)
	out.store_string(Transport.stringify({"ok":ok,"checks":checks,"world_build_count":0,"solver_step_count":0}))
	out.close();quit(0 if ok else 1)
