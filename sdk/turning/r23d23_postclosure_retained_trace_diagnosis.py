"""Recompute the R23D23 post-closure threshold diagnosis from retained CAS.

The script reads immutable R23D21 and R23D23 trace payloads only. It never
imports an adapter, constructs a model, or starts a physics world.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any, Callable, Sequence


CONTROLLER_STEPS = 2_992
TERMINAL_STEPS = 960


def _first_step(
    rows: list[dict[str, Any]], predicate: Callable[[dict[str, Any]], bool]
) -> int | None:
    for row in rows:
        if predicate(row):
            return int(row["trace_step"])
    return None


def _cell_projection(
    payload_path: Path,
    *,
    cell_id: str,
    tilt_threshold_rad: float,
    joint_error_threshold_rad: float,
) -> dict[str, Any]:
    rows = [
        json.loads(line)
        for line in payload_path.read_text(encoding="utf-8").splitlines()
        if line
    ]
    if len(rows) != CONTROLLER_STEPS + TERMINAL_STEPS:
        raise RuntimeError("R23D23_D1_TRACE_ROW_COUNT:" + cell_id)
    if any(row.get("cell_id") != cell_id for row in rows):
        raise RuntimeError("R23D23_D1_TRACE_CELL_ID:" + cell_id)
    controller = rows[:CONTROLLER_STEPS]
    terminal = rows[CONTROLLER_STEPS:]
    tilts = [float(row["torso_tilt_rad"]) for row in terminal]
    errors = [
        float(row["maximum_absolute_joint_position_error_rad"])
        for row in terminal
    ]
    if not all(math.isfinite(value) for value in tilts + errors):
        raise RuntimeError("R23D23_D1_TRACE_NONFINITE:" + cell_id)
    tight_indices = [
        index
        for index, (tilt, error) in enumerate(zip(tilts, errors, strict=True))
        if tilt <= tilt_threshold_rad and error <= joint_error_threshold_rad
    ]
    return {
        "cell_id": cell_id,
        "trace_row_count": len(rows),
        "terminal_row_count": len(terminal),
        "terminal_tilt_minimum_rad": min(tilts),
        "terminal_tilt_final_rad": tilts[-1],
        "terminal_joint_error_minimum_rad": min(errors),
        "terminal_joint_error_final_rad": errors[-1],
        "tight_pose_row_count": len(tight_indices),
        "first_tight_terminal_index": tight_indices[0] if tight_indices else None,
        "first_controller_tilt_above_0_2_step": _first_step(
            controller, lambda row: float(row["torso_tilt_rad"]) > 0.2
        ),
        "first_controller_tilt_above_0_5_step": _first_step(
            controller, lambda row: float(row["torso_tilt_rad"]) > 0.5
        ),
        "first_controller_height_below_0_35_step": _first_step(
            controller, lambda row: float(row["torso_height_m"]) < 0.35
        ),
        "first_controller_torso_ground_contact_step": _first_step(
            controller, lambda row: bool(row["torso_ground_contact"])
        ),
    }


def run_diagnosis(
    declaration_path: Path,
    evidence_root: Path,
) -> dict[str, Any]:
    declaration = json.loads(declaration_path.read_text(encoding="utf-8"))
    query = declaration["threshold_provenance_query"]
    cells = []
    for item in query["retained_cells"]:
        sha256 = str(item["trace_cas_sha256"])
        if not sha256.startswith("sha256:") or len(sha256) != 71:
            raise RuntimeError("R23D23_D1_TRACE_SHA256")
        payload = evidence_root / "artifacts" / "sha256" / sha256[7:] / "payload.bin"
        cells.append(
            _cell_projection(
                payload,
                cell_id=str(item["cell_id"]),
                tilt_threshold_rad=float(query["tight_maximum_torso_tilt_rad"]),
                joint_error_threshold_rad=float(
                    query["tight_maximum_joint_position_error_rad"]
                ),
            )
        )
    return {
        "schema_version": "sporespore_qsdk_r23d23_postclosure_retained_trace_diagnosis_v1",
        "gate_id": declaration["gate_id"],
        "source_closure_count": 2,
        "cell_count": len(cells),
        "cells": cells,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "threshold_change_authorized": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--declaration", type=Path, required=True)
    parser.add_argument("--evidence-root", type=Path, required=True)
    arguments = parser.parse_args(argv)
    print(
        "QSDK_R23D23_RETAINED_TRACE_D1 "
        + json.dumps(
            run_diagnosis(arguments.declaration, arguments.evidence_root),
            allow_nan=False,
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
