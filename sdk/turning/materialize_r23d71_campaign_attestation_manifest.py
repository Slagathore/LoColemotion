#!/usr/bin/env python3
"""Materialize the compact R23D71 campaign-attestation manifest.

The manifest composes the commissioned generic attestation executor with the
complete R23D71 zero-world lineage gate and one fast campaign-local gate for
each required role. It constructs no model or world and grants no physical
authority by itself.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[2]
IMPLEMENTATION = (
    ROOT
    / "sdk"
    / "turning"
    / "r23d71_production_route_three_engine_turning_implementation_v1.json"
)
OUTPUT = (
    ROOT / "sdk" / "turning" / "r23d71_campaign_attestation_manifest_v1.json"
)
SELF = Path(__file__).resolve()
ZERO_WORLD_GATE = ROOT / "tests" / "test_qsdk_r23d71_zero_world.ps1"
ROLE_GATE = ROOT / "tests" / "test_qsdk_r23d71_campaign_roles.ps1"
EVALUATOR = (
    ROOT
    / "sdk"
    / "turning"
    / "r23d71_production_route_three_engine_turning_evaluator.py"
)
SUPERVISOR = ROOT / "sdk" / "run_qsdk_r23d71_supervisor.ps1"
CAMPAIGN_ID = (
    "QSDK-R23D71-SUCCESS-TERMINAL-PROJECTION-REPAIRED-"
    "THREE-ENGINE-TURNING-VALIDATION"
)


class ManifestError(RuntimeError):
    """The deterministic campaign-attestation manifest could not be built."""


def _relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError as error:
        raise ManifestError(
            f"R23D71_ATTESTATION_PATH_ESCAPES_REPOSITORY:{path}"
        ) from error


def _raw_sha256(path: Path) -> str:
    if not path.is_file():
        raise ManifestError(
            f"R23D71_ATTESTATION_SOURCE_MISSING:{_relative(path)}"
        )
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _load_implementation() -> dict[str, Any]:
    try:
        value = json.loads(IMPLEMENTATION.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ManifestError("R23D71_ATTESTATION_IMPLEMENTATION_UNREADABLE") from error
    exact = (
        isinstance(value, dict)
        and value.get("campaign_id") == CAMPAIGN_ID
        and value.get("gate_id") == "QSDK-R23D71"
        and value.get("question_class") == "finite_decision"
        and value.get("declared_cell_count") == 9
        and len(value.get("ordered_cell_ids", [])) == 9
        and value.get("claims", {}).get("implementation_complete") is True
        and value.get("claims", {}).get("complete_zero_world_gate_passed") is True
        and value.get("claims", {}).get("complete_authorization_ghost_passed")
        is True
        and value.get("claims", {}).get("physical_campaign_opened") is False
        and isinstance(value.get("dependency_digests"), dict)
        and len(value["dependency_digests"])
        == value["dependency_inventory"]["transitive_path_count"]
        and len(value["dependency_digests"]) > 0
    )
    if not exact:
        raise ManifestError("R23D71_ATTESTATION_IMPLEMENTATION_INVALID")
    return value


def _gate(
    ordinal: int,
    gate_id: str,
    role: str,
    path: Path,
    arguments: list[str],
    marker: str,
) -> dict[str, Any]:
    return {
        "ordinal": ordinal,
        "gate_id": gate_id,
        "role": role,
        "invocation_kind": "powershell_file",
        "path": _relative(path),
        "arguments": arguments,
        "terminal_marker_prefix": marker,
        "raw_sha256": _raw_sha256(path),
    }


def compose() -> dict[str, Any]:
    implementation = _load_implementation()
    implementation_hash = _raw_sha256(IMPLEMENTATION)
    role_hash = _raw_sha256(ROLE_GATE)
    lineage = [
        _gate(
            1,
            "R23D71-COMPLETE-ZERO-WORLD",
            "lineage",
            ZERO_WORLD_GATE,
            [
                "-Godot",
                "<canonical-godot>",
                "-Python",
                "<python>",
                "-PowerShell",
                "pwsh",
                "-ExpectProductionConformanceLockHeld",
            ],
            "[turning/3e] PASS R23D71 complete zero-world gate:",
        )
    ]
    roles = [
        _gate(
            2,
            "R23D71-WORKER-ROLE",
            "worker",
            ROLE_GATE,
            [
                "-Role",
                "worker",
                "-Python",
                "<python>",
                "-Godot",
                "<canonical-godot>",
                "-PowerShell",
                "pwsh",
            ],
            "QSDK_R23D71_CAMPAIGN_WORKER_ROLE_PASS ",
        ),
        _gate(
            3,
            "R23D71-EVALUATOR-ROLE",
            "evaluator",
            ROLE_GATE,
            [
                "-Role",
                "evaluator",
                "-Python",
                "<python>",
                "-Godot",
                "<canonical-godot>",
                "-PowerShell",
                "pwsh",
            ],
            "QSDK_R23D71_CAMPAIGN_EVALUATOR_ROLE_PASS ",
        ),
        _gate(
            4,
            "R23D71-SUPERVISOR-ROLE",
            "supervisor",
            ROLE_GATE,
            [
                "-Role",
                "supervisor",
                "-Python",
                "<python>",
                "-Godot",
                "<canonical-godot>",
                "-PowerShell",
                "pwsh",
            ],
            "QSDK_R23D71_CAMPAIGN_SUPERVISOR_ROLE_PASS ",
        ),
    ]
    role_bindings = [
        {
            "role": "worker",
            "source_path": _relative(IMPLEMENTATION),
            "source_raw_sha256": implementation_hash,
            "test_gate_id": "R23D71-WORKER-ROLE",
            "test_path": _relative(ROLE_GATE),
            "test_raw_sha256": role_hash,
        },
        {
            "role": "evaluator",
            "source_path": _relative(EVALUATOR),
            "source_raw_sha256": _raw_sha256(EVALUATOR),
            "test_gate_id": "R23D71-EVALUATOR-ROLE",
            "test_path": _relative(ROLE_GATE),
            "test_raw_sha256": role_hash,
        },
        {
            "role": "supervisor",
            "source_path": _relative(SUPERVISOR),
            "source_raw_sha256": _raw_sha256(SUPERVISOR),
            "test_gate_id": "R23D71-SUPERVISOR-ROLE",
            "test_path": _relative(ROLE_GATE),
            "test_raw_sha256": role_hash,
        },
    ]
    source_digests = dict(implementation["dependency_digests"])
    source_digests[_relative(IMPLEMENTATION)] = implementation_hash
    source_digests[_relative(SELF)] = _raw_sha256(SELF)
    source_digests[_relative(SUPERVISOR)] = _raw_sha256(SUPERVISOR)
    source_digests[_relative(ROLE_GATE)] = role_hash
    source_digests[_relative(ZERO_WORLD_GATE)] = _raw_sha256(ZERO_WORLD_GATE)
    source_digests[_relative(EVALUATOR)] = _raw_sha256(EVALUATOR)
    source_bindings = [
        {"path": path, "raw_sha256": source_digests[path]}
        for path in sorted(source_digests)
    ]
    return {
        "schema_version": "sporespore_locomotion_campaign_attestation_manifest_v1",
        "status": "prospective_zero_world_physical_candidate",
        "campaign_id": CAMPAIGN_ID,
        "question_class": "finite_decision",
        "declared_physical_world_count": 9,
        "physical_launch_candidate": True,
        "godot_including": True,
        "skip_godot": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "declared_lineage_gate_count": 1,
        "declared_campaign_gate_count": 3,
        "declared_total_gate_count": 4,
        "declared_role_binding_count": 3,
        "lineage_gates": lineage,
        "campaign_gates": roles,
        "campaign_role_bindings": role_bindings,
        "dependency_authority": {
            "path": _relative(IMPLEMENTATION),
            "raw_sha256": implementation_hash,
        },
        "source_bindings": source_bindings,
        "claims": {
            "campaign_local_qualification_passed": False,
            "cold_commissioning_complete": False,
            "physical_launch_prerequisite_satisfied": False,
            "physical_campaign_executed": False,
            "scientific_result": False,
            "walking_acceptance": False,
            "turning_acceptance": False,
            "cross_engine_equivalence": False,
            "arbitrary_quadruped_coverage": False,
            "release_authority": False,
            "physical_acceptance_authority": False,
        },
    }


def _raw_document(value: dict[str, Any]) -> bytes:
    return (
        json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            indent=2,
            sort_keys=False,
        )
        + "\n"
    ).encode("utf-8")


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("write", "check", "print"))
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    value = compose()
    raw = _raw_document(value)
    if arguments.command == "write":
        OUTPUT.write_bytes(raw)
    elif arguments.command == "check":
        if not OUTPUT.is_file() or OUTPUT.read_bytes() != raw:
            raise ManifestError("R23D71_ATTESTATION_MANIFEST_MATERIALIZATION_DRIFT")
    else:
        sys.stdout.buffer.write(raw)
        return 0
    print(
        "QSDK_R23D71_ATTESTATION_MANIFEST "
        + json.dumps(
            {
                "path": _relative(OUTPUT),
                "raw_sha256": _raw_sha256(OUTPUT),
                "source_binding_count": len(value["source_bindings"]),
                "lineage_gate_count": 1,
                "campaign_gate_count": 3,
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "physical_execution_authorized": False,
                "physical_acceptance_authority": False,
            },
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
