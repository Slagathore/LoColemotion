class_name LabCampaignRunner
extends RefCounted

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")


static func matrix_summary(campaign_id: String, declared_cells: Array, child_summaries: Array) -> Dictionary:
	var child_by_id: Dictionary = {}
	for child in child_summaries:
		if child is Dictionary:
			child_by_id[String(child.get("cell_id", ""))] = child
	var rows: Array = []
	var valid := true
	for cell in declared_cells:
		var cell_id := String(cell.get("cell_id", ""))
		if cell_id.is_empty() or not child_by_id.has(cell_id):
			rows.append({
				"cell_id": cell_id,
				"status": "missing",
				"policy": cell.get("policy", "required_feasible"),
			})
			valid = false
		else:
			rows.append(child_by_id[cell_id])
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("cell_id", "")) < String(b.get("cell_id", "")))
	return FrozenValueScript.snapshot({
		"schema": "sporespore.lab.matrix_summary.v1",
		"campaign_id": campaign_id,
		"declared_cell_count": declared_cells.size(),
		"observed_cell_count": child_summaries.size(),
		"cells": rows,
		"evidence_validity": "valid" if valid else "invalid",
	})
