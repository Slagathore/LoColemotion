class_name LabRuntimeNote
extends RefCounted

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")


static func seal(
		run_id: String,
		note_sequence: int,
		source: String,
		severity: String,
		code: String,
		message: String,
		evidence: Dictionary = {},
		frame_id: Variant = null) -> Dictionary:
	return FrozenValueScript.snapshot({
		"schema": "sporespore.lab.runtime_note.v1",
		"run_id": run_id,
		"note_sequence": note_sequence,
		"frame_id": frame_id,
		"source": source,
		"severity": severity,
		"code": code,
		"message": message,
		"evidence": evidence,
	})
