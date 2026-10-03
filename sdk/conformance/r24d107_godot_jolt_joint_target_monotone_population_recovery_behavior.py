#!/usr/bin/env python3
"""Thin R107 binding for the reusable finite recovery behavior gate."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_gate import run_cli  # noqa: E402

CONTRACT = (
	"sdk/recovery/r24d107_godot_jolt_joint_target_monotone_population_recovery_"
	"behavior_contract_v1.json"
)
CONTRACT_SCHEMA = (
	"sporespore_qsdk_r24d107_godot_jolt_joint_target_monotone_population_recovery_"
	"behavior_contract_v1"
)


if __name__ == "__main__":
    raise SystemExit(
		run_cli(
			ROOT,
			CONTRACT,
			CONTRACT_SCHEMA,
			terminal_closure_relative_path=(
				"sdk/recovery/r24d107_godot_jolt_joint_target_monotone_population_"
				"recovery_behavior_physical_closure_v1.json"
			),
			terminal_closure_schema=(
				"sporespore_qsdk_r24d107_godot_jolt_joint_target_monotone_"
				"population_recovery_behavior_physical_closure_v1"
			),
			terminal_closure_raw_sha256=(
				"sha256:1b94ab31c614dfc03696baa390ba8470dabb386d04330aa92b2988cdf9a5710d"
			),
			terminal_closure_byte_length=27477,
			terminal_live_keys=(
				"r24d107_source_status",
				"r24d107_physical_execution_authorized",
			),
		)
    )
