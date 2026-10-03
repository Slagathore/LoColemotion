class_name LabFrameAssembler
extends RefCounted

## Builds one immutable post-step sensor frame. This object is mutable only while
## assembling a single record; controllers receive only the deep-frozen result.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA := "sporespore.lab.frame.v1"
const SAMPLE_PHASES := {
	"pre_control": true,
	"command_sealed": true,
	"pre_integrate": true,
	"integrate_callback": true,
	"post_step": true,
	"derived": true,
}
const EXPERIMENT_PHASES := {
	"CONFIGURE": true,
	"SPAWN": true,
	"SETTLE_SCAFFOLDED": true,
	"RELEASE": true,
	"WARMUP": true,
	"MEASURE": true,
	"COOLDOWN": true,
	"TERMINATED": true,
}

var _run_id := ""
var _release_frame_id := -1


func _init(run_id := "", release_frame_id := -1) -> void:
	_run_id = run_id
	_release_frame_id = release_frame_id


func assemble(
		frame_id: int,
		physics_time_s: float,
		sample_phase: String,
		experiment_phase: String,
		bodies: Array,
		joints: Array = [],
		contacts: Array = [],
		support: Dictionary = {},
		availability: Dictionary = {}) -> Dictionary:
	if frame_id < 0 or not is_finite(physics_time_s):
		return {}
	if not SAMPLE_PHASES.has(sample_phase) or not EXPERIMENT_PHASES.has(experiment_phase):
		return {}
	# frame_v1 is intentionally L0-only. Joint/support channels require a
	# versioned schema extension in BR2/BR3; they are never smuggled into v1.
	if not joints.is_empty() or not support.is_empty():
		return {}
	var sorted_body_values := _sorted_records(bodies, "body_id")
	var sorted_contacts := _sorted_records(contacts, "contact_key")
	if sorted_body_values.size() != bodies.size():
		return {}
	if sorted_contacts.size() != contacts.size():
		return {}
	var bodies_by_id: Dictionary = {}
	var finite := true
	for body in sorted_body_values:
		bodies_by_id[String(body["body_id"])] = body
		finite = finite and bool(body.get("finite", false))
	var field_availability := availability.duplicate(true)
	if field_availability.is_empty():
		for body_id in bodies_by_id.keys():
			field_availability["body:%s" % body_id] = {
				"status": "measured",
				"reason": null,
				"source": "lab_frame_assembler_v1",
			}
		field_availability["contacts"] = {
			"status": "measured",
			"reason": null,
			"source": "lab_frame_assembler_v1",
		}
		field_availability["frame"] = {
			"status": "measured" if finite else "invalid",
			"reason": null if finite else "BODY_SAMPLE_INVALID",
			"source": "lab_frame_assembler_v1",
		}
	return FrozenValueScript.snapshot({
		"schema": SCHEMA,
		"run_id": _run_id,
		"schema_version": "frame_v1",
		"frame_id": frame_id,
		"physics_step_id": frame_id,
		"capture_epoch": frame_id,
		"physics_time_s": physics_time_s,
		"sample_phase": sample_phase,
		"experiment_phase": experiment_phase,
		"release_frame_id": _release_frame_id,
		"bodies": bodies_by_id,
		"contacts": sorted_contacts,
		"availability": {
			"required_body_ids": bodies_by_id.keys(),
			"captured_body_count": bodies_by_id.size(),
			"contact_count": sorted_contacts.size(),
			"invalid_reasons": [] if finite else ["BODY_SAMPLE_INVALID"],
			"fields": field_availability,
		},
		"finite": finite,
	})


static func transition_for_frame(source_frame_id: int) -> Array:
	var transition := [source_frame_id, source_frame_id + 1]
	transition.make_read_only()
	return transition


static func _sorted_records(records: Array, id_field: String) -> Array:
	var copied: Array = []
	for raw in records:
		if not raw is Dictionary:
			return []
		var record: Dictionary = raw
		if not record.has(id_field) or String(record[id_field]).is_empty():
			return []
		copied.append(record)
	copied.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a[id_field]) < String(b[id_field]))
	return copied
