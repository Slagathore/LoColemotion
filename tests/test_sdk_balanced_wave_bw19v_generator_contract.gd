extends SceneTree
# gdlint: disable=max-line-length

## Zero-world generator and candidate-identity contract for BW19V.
##
## This is the only supported way to emit the exact unopened morphology cells
## before the preregistration freezes them. It performs no scene insertion,
## physics mutation, or locomotion evaluation.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const ProportionSpecScript := preload(
	"res://scripts/lab/gait/physical_quadruped_proportion_spec_v2.gd"
)

const CANDIDATES_PATH := "res://sdk/balanced_wave_bw19v_validation_candidates.json"
const CANDIDATES_RAW_SHA256 := "sha256:02124811891638efaad30fc6e04b3a10b600a5eab913984c1d4c8abbd1a963a3"
const CANDIDATE_IDS := ["BW19V-A", "BW19V-B"]
const CANDIDATE_DIGESTS := [
	"sha256:2eb8621882b4ae4047821aca415ab1b67de3399d0ab272a91f57fb0fc2ada7a4",
	"sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK BW19V zero-world generator contract ===")
	var children_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var candidates := _read_json(CANDIDATES_PATH)
	var candidate_rows: Array = candidates.get("candidates", [])
	var candidate_digests: Dictionary = candidates.get(
		"candidate_composition_digests",
		{},
	)
	var candidates_exact := (
		String(candidates.get("schema_version", ""))
		== "sporespore_balanced_wave_bw19v_validation_candidates_v1"
		and String(candidates.get("status", ""))
		== "frozen_before_first_bw19v_physics_world"
		and String(candidates.get("campaign_id", ""))
		== ProportionSpecScript.BW19V_CAMPAIGN_ID
		and (candidates.get("candidate_order", []) as Array) == CANDIDATE_IDS
		and candidate_rows.size() == CANDIDATE_IDS.size()
		and (
			"sha256:%s" % FileAccess.get_sha256(CANDIDATES_PATH)
			== CANDIDATES_RAW_SHA256
		)
	)
	for index in range(candidate_rows.size()):
		var candidate: Dictionary = candidate_rows[index]
		candidates_exact = (
			candidates_exact
			and String(candidate.get("candidate_id", "")) == CANDIDATE_IDS[index]
			and CanonicalJsonScript.sha256(candidate) == CANDIDATE_DIGESTS[index]
			and String(candidate_digests.get(CANDIDATE_IDS[index], ""))
			== CANDIDATE_DIGESTS[index]
			and int(candidate.get("expected_application_pass_count", -1))
			== (0 if index == 0 else 36)
		)
	_check(candidates_exact, "1 candidate raw bytes and canonical compositions are exact")

	var cells: Array = []
	var generator_exact := true
	var morphology_ids: Dictionary = {}
	for generator_index in ProportionSpecScript.BW19V_INDEPENDENT_INDICES:
		var generated := ProportionSpecScript.compile_bw19v_generation(generator_index)
		if not bool(generated.get("ok", false)):
			generator_exact = false
			continue
		var generator_receipt: Dictionary = generated.get("generator_receipt", {})
		var proportion_spec: Dictionary = generated.get("proportion_spec", {})
		var cell := {
			"generator_index": int(generator_index),
			"morphology_id": String(proportion_spec.get("morphology_id", "")),
			"generator_receipt_sha256": String(
				generated.get("generator_receipt_sha256", "")
			),
			"proportion_spec_sha256": String(
				generated.get("proportion_spec_sha256", "")
			),
		}
		generator_exact = (
			generator_exact
			and String(generator_receipt.get("schema_version", ""))
			== ProportionSpecScript.BW19V_GENERATOR_SCHEMA_VERSION
			and String(generator_receipt.get("generator_policy_id", ""))
			== ProportionSpecScript.BW19V_GENERATOR_POLICY_ID
			and String(generator_receipt.get("campaign_id", ""))
			== ProportionSpecScript.BW19V_CAMPAIGN_ID
			and String(generator_receipt.get("campaign_role", "")) == "independent"
			and int(generated.get("world_build_count", -1)) == 0
			and not bool(generated.get("physical_acceptance_authority", true))
			and not morphology_ids.has(cell["morphology_id"])
		)
		morphology_ids[cell["morphology_id"]] = true
		cells.append(cell)
	_check(
		generator_exact and cells.size() == 12 and morphology_ids.size() == 12,
		"2 all twelve BW19V cells are unique deterministic zero-world receipts",
	)

	var wrong_type := ProportionSpecScript.compile_bw19v_generation(205.0)
	var out_of_cohort := ProportionSpecScript.compile_bw19v_generation(204)
	_check(
		(
			not bool(wrong_type.get("ok", true))
			and String(wrong_type.get("failure_code", ""))
			== "INVALID_BW19V_GENERATOR_INDEX_TYPE"
			and not bool(out_of_cohort.get("ok", true))
			and String(out_of_cohort.get("failure_code", ""))
			== "UNKNOWN_BW19V_GENERATOR_INDEX"
		),
		"3 wrong-type and outside-cohort indices fail closed",
	)

	var receipt := {
		"schema_version": "sporespore_bw19v_generated_cells_receipt_v1",
		"campaign_id": ProportionSpecScript.BW19V_CAMPAIGN_ID,
		"generator_policy_id": ProportionSpecScript.BW19V_GENERATOR_POLICY_ID,
		"generator_schema_version": ProportionSpecScript.BW19V_GENERATOR_SCHEMA_VERSION,
		"generator_indices": ProportionSpecScript.BW19V_INDEPENDENT_INDICES,
		"cells": cells,
		"world_build_count": 0,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	_check(
		(
			root.get_child_count() == children_before
			and Engine.physics_ticks_per_second == physics_hz_before
		),
		"4 the complete generator contract creates no world and mutates no physics clock",
	)
	print("BW19V_GENERATED_CELLS ", JSON.stringify(receipt, "", true, true))
	_finish()


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print(
		"\nSDK BW19V generator summary: %d passed, %d failed"
		% [_passed, _failed]
	)
	quit(0 if _failed == 0 else 1)
