extends RefCounted
## Prospective discovery identity, separate from every historical campaign seed.
const CONTEXT_KEY := "recovery_panel"
const SEED := 0 # The contact-reader interface passes this sentinel; declaration owns the actual seed.
const Json := preload("res://sdk/adapters/godot/gdscript/r10j_campaign_seed_v1.gd")

static func attach_report_context_v1(report: Dictionary, declaration: Dictionary, seed: int) -> bool:
	if declaration.get("discovery_kind") != "full_recovery_panel_v1": return false
	if not declaration.get("children") is Array or declaration.children.size() != 1: return false
	var child: Dictionary = declaration.children[0]
	if child.get("role") not in ["kick_passive_recovery_resume", "matched_no_kick_continuation"]: return false
	if seed != 0 and seed != int(declaration.seed): return false
	if (report.get("seed") != declaration.seed or report.get("arm_id") != child.role
		or report.get("source_commit") != declaration.source_snapshot.head
		or report.get("child_attempt_id") != child.child_attempt_id
		or report.get("parent_attempt_id") != declaration.attempt_id): return false
	for key in ["physical_acceptance_authority", "release_authority"]:
		if report.get(key) != false or declaration.get(key) != false: return false
	var cell: Dictionary = declaration.discovery_cell.duplicate(true)
	cell.phase = int(cell.phase)
	var label := "DISCOVERY-PHASE-" + str(cell.phase) + "-V1"
	report[CONTEXT_KEY] = {"schema_version": "sporespore_full_recovery_discovery_context_v1",
		"cell": cell, "manifest": declaration.discovery_manifest.duplicate(true),
		"allowed_entry_kinds": ["partial", "prone", "upright"],
		"historical_partial_only_task_regraded": false,
		"physical_acceptance_authority": false, "release_authority": false}
	report["seed_label"] = label
	report["seed_sha256"] = "sha256:" + label.sha256_text()
	report["held_out"] = false
	report["held_out_cell_access_count"] = 0
	report["official_qualification"] = false
	return true
