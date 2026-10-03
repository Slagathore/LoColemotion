class_name LabRunSummary
extends RefCounted

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const TERMINATIONS := {
	"completed": true,
	"timed_out": true,
	"aborted": true,
	"crashed": true,
}
const EVIDENCE_STATES := {"valid": true, "invalid": true, "partial": true}
const HYPOTHESIS_RESULTS := {
	"supported": true,
	"contradicted": true,
	"inconclusive": true,
}
const PROMOTION_RESULTS := {"pass": true, "fail": true, "not_evaluated": true}


static func seal(
		run_id: String,
		termination: String,
		evidence_validity: String,
		hypothesis_result: String,
		promotion: String,
		metrics: Array,
		gates: Dictionary = {},
		frame_count := 0,
		runtime_note_count := 0,
		first_frame_id: Variant = null,
		last_frame_id: Variant = null) -> Dictionary:
	if (not TERMINATIONS.has(termination)
			or not EVIDENCE_STATES.has(evidence_validity)
			or not HYPOTHESIS_RESULTS.has(hypothesis_result)
			or not PROMOTION_RESULTS.has(promotion)):
		return {}
	return FrozenValueScript.snapshot({
		"schema": "sporespore.lab.summary.v1",
		"run_id": run_id,
		"termination": termination,
		"evidence_validity": evidence_validity,
		"hypothesis_result": hypothesis_result,
		"promotion": promotion,
		"frame_count": frame_count,
		"runtime_note_count": runtime_note_count,
		"first_frame_id": first_frame_id,
		"last_frame_id": last_frame_id,
		"metrics": metrics,
		"gate_results": gates,
	})
