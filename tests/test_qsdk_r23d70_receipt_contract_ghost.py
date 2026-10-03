#!/usr/bin/env python3
"""Two-row real-CAS producer/MuJoCo-consumer ghost for R23D70."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any, Sequence


REPO_ROOT = Path(__file__).resolve().parents[1]
TURNING_ROOT = REPO_ROOT / "sdk" / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

from r23d70_receipt_contract import (  # noqa: E402
    project_retention_receipt,
    receipt_contract_mutations,
    validate_retention_receipt,
)


SCHEMA = "sporespore_qsdk_r23d70_trace_retention_v1"
STAGE_ID = "trace_retention_receipt_contract_ghost"
CELL_ID = "r23d70_receipt_contract_ghost"
ENGINE_ID = "contract_ghost"
CAMPAIGN_SEED = 23189
PROFILE_ID = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
HOST_MAPPING_ID = "contract_ghost"
PUBLISHER_MARKER = "QSDK_R23D48_EVIDENCE_CAS "


class GhostError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise GhostError(message)


def canonical_row(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def validation_kwargs() -> dict[str, Any]:
    return {
        "expected_schema": SCHEMA,
        "expected_stage_id": STAGE_ID,
        "expected_cell_id": CELL_ID,
        "expected_engine_id": ENGINE_ID,
        "expected_campaign_seed": CAMPAIGN_SEED,
        "expected_profile_id": PROFILE_ID,
        "expected_host_mapping_id": HOST_MAPPING_ID,
        "expected_row_count": 2,
        "expected_test_only": True,
    }


def run(output_root: Path, powershell: str) -> dict[str, Any]:
    output_root = output_root.resolve()
    target_root = (REPO_ROOT / "sdk" / "target").resolve()
    require(output_root != target_root and output_root.is_relative_to(target_root), "OUTPUT_ROOT_INVALID")
    require(not output_root.exists(), "OUTPUT_ROOT_ALREADY_EXISTS")
    output_root.mkdir(parents=True)
    trace_path = output_root / "receipt-contract-ghost.ndjson"
    raw = b"".join(
        canonical_row(
            {
                "schema_version": "sporespore_qsdk_r23d70_receipt_contract_ghost_row_v1",
                "semantic_step": step,
            }
        )
        for step in (0, 1)
    )
    trace_path.write_bytes(raw)
    digest = "sha256:" + hashlib.sha256(raw).hexdigest()
    evidence_override = output_root / "evidence"
    evidence_override.mkdir()
    process = subprocess.run(
        [
            powershell,
            "-NoLogo",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(REPO_ROOT / "sdk" / "publish_qsdk_r23d48_trace.ps1"),
            "-RepoRoot",
            str(REPO_ROOT),
            "-ArtifactPath",
            str(trace_path),
            "-ExpectedSha256",
            digest,
            "-ExpectedByteLength",
            str(len(raw)),
            "-TestOnly",
            "-EvidenceRootOverride",
            str(evidence_override),
        ],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
        timeout=60,
    )
    markers = [
        line[len(PUBLISHER_MARKER) :]
        for line in process.stdout.splitlines()
        if line.startswith(PUBLISHER_MARKER)
    ]
    require(process.returncode == 0 and len(markers) == 1, "ACTUAL_CAS_PUBLISHER_FAILED")
    artifact = json.loads(markers[0])
    base = {
        "schema_version": SCHEMA,
        "stage_id": STAGE_ID,
        "cell_id": CELL_ID,
        "engine_id": ENGINE_ID,
        "campaign_seed": CAMPAIGN_SEED,
        "profile_id": PROFILE_ID,
        "host_mapping_id": HOST_MAPPING_ID,
        "trace_artifact": artifact,
        "trace_summary": {
            "schema_version": "sporespore_qsdk_r23d70_trace_summary_v1",
            "row_count": 2,
            "raw_sha256": digest,
            "byte_length": len(raw),
            "physical_acceptance_authority": False,
        },
        "retained_before_terminal_entry": True,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }
    receipt = project_retention_receipt(base, expected_row_count=2)
    failures = validate_retention_receipt(
        receipt,
        **validation_kwargs(),
        verify_artifact_bytes=True,
    )
    require(failures == [], "MUJOCO_POSITIVE_REJECTED:" + ",".join(failures))
    negative_codes: dict[str, list[str]] = {}
    for mutation_id, mutation in receipt_contract_mutations(receipt).items():
        mutation_failures = validate_retention_receipt(mutation, **validation_kwargs())
        require(bool(mutation_failures), f"MUJOCO_NEGATIVE_ACCEPTED:{mutation_id}")
        negative_codes[mutation_id] = mutation_failures
    receipt_path = output_root / "projected-receipt.json"
    receipt_path.write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return {
        "schema_version": "sporespore_qsdk_r23d70_python_receipt_contract_ghost_v1",
        "receipt_path": receipt_path.as_posix(),
        "receipt_raw_sha256": "sha256:" + hashlib.sha256(receipt_path.read_bytes()).hexdigest(),
        "published_trace_row_count": 2,
        "actual_cas_publisher_passed": True,
        "producer_projection_passed": True,
        "mujoco_consumer_positive_passed": True,
        "mujoco_negative_decision_count": len(negative_codes),
        "mujoco_negative_failure_codes": negative_codes,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--powershell", required=True)
    arguments = parser.parse_args(argv)
    value = run(arguments.output_root, arguments.powershell)
    print("QSDK_R23D70_PYTHON_RECEIPT_GHOST " + json.dumps(value, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
