#!/usr/bin/env python3
"""Materialize the compact R23D76 campaign-attestation manifest.

The manifest composes the commissioned generic attestation executor with the
complete R23D76 zero-world gate, the immutable passing native-smoke closure,
and one fast campaign-local gate for each required role. It constructs no
model or world and grants no physical authority by itself.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[2]
TURNING = ROOT / "sdk" / "turning"
IMPLEMENTATION = (
    TURNING / "r23d76_production_route_three_engine_turning_implementation_v1.json"
)
OUTPUT = TURNING / "r23d76_campaign_attestation_manifest_v1.json"
SELF = Path(__file__).resolve()
ZERO_WORLD_GATE = (
    ROOT / "tests" / "test_qsdk_r23d76_zero_world_qualification_v3.ps1"
)
ROLE_GATE = ROOT / "tests" / "test_qsdk_r23d76_campaign_roles.ps1"
SMOKE_CLOSURE = TURNING / "r23d76_bounded_native_smoke_v3_closure.json"
SMOKE_CLOSURE_AUDIT = (
    ROOT / "sdk" / "audit_r23d76_bounded_native_smoke_v3_closure.py"
)
FIRST_QUALIFICATION_FAILURE = (
    TURNING / "r23d76_first_campaign_qualification_failure_v1.json"
)
FIRST_QUALIFICATION_FAILURE_AUDIT = (
    ROOT / "sdk" / "audit_r23d76_first_campaign_qualification_failure.py"
)
SECOND_QUALIFICATION_FAILURE = (
    TURNING / "r23d76_second_campaign_qualification_failure_v1.json"
)
SECOND_QUALIFICATION_FAILURE_AUDIT = (
    ROOT / "sdk" / "audit_r23d76_second_campaign_qualification_failure.py"
)
EVALUATOR = (
    TURNING / "r23d76_production_route_three_engine_turning_evaluator.py"
)
SUPERVISOR = ROOT / "sdk" / "run_qsdk_r23d76_supervisor.ps1"
CAMPAIGN_ID = "QSDK-R23D76-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"


class ManifestError(RuntimeError):
    """The deterministic campaign-attestation manifest could not be built."""


def _relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError as error:
        raise ManifestError(
            f"R23D76_ATTESTATION_PATH_ESCAPES_REPOSITORY:{path}"
        ) from error


def _raw_sha256(path: Path) -> str:
    if not path.is_file():
        raise ManifestError(
            f"R23D76_ATTESTATION_SOURCE_MISSING:{_relative(path)}"
        )
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _load_json(path: Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ManifestError(code) from error
    if not isinstance(value, dict):
        raise ManifestError(code)
    return value


def _load_implementation() -> dict[str, Any]:
    value = _load_json(
        IMPLEMENTATION, "R23D76_ATTESTATION_IMPLEMENTATION_UNREADABLE"
    )
    claims = value.get("claims", {})
    exact = (
        value.get("campaign_id") == CAMPAIGN_ID
        and value.get("gate_id") == "QSDK-R23D76"
        and value.get("question_class") == "finite_decision"
        and value.get("declared_cell_count") == 9
        and len(value.get("ordered_cell_ids", [])) == 9
        and claims.get("implementation_complete") is True
        and claims.get("complete_zero_world_gate_passed") is True
        and claims.get("both_predecessor_replays_passed") is True
        and claims.get("bounded_native_smoke_passed") is False
        and claims.get("full_seeded_world_ghost_used") is False
        and claims.get("physical_campaign_opened") is False
        and claims.get("q_sdk_r23_satisfied") is False
        and isinstance(value.get("dependency_digests"), dict)
        and len(value["dependency_digests"])
        == value["dependency_inventory"]["transitive_path_count"]
        and len(value["dependency_digests"]) == 222
    )
    if not exact:
        raise ManifestError("R23D76_ATTESTATION_IMPLEMENTATION_INVALID")
    return value


def _load_smoke_closure() -> dict[str, Any]:
    value = _load_json(
        SMOKE_CLOSURE, "R23D76_ATTESTATION_SMOKE_CLOSURE_UNREADABLE"
    )
    source_commit = value.get("source_authority", {}).get("source_commit", "")
    claims = value.get("claims", {})
    observed = value.get("observed_population", {})
    retained = value.get("retained_attempt", {})
    exact = (
        value.get("schema_version")
        == "sporespore_qsdk_r23d76_bounded_native_smoke_v3_closure_v1"
        and value.get("status")
        == "closed_complete_integration_valid_bounded_native_smoke"
        and re.fullmatch(r"[0-9a-f]{40}", str(source_commit)) is not None
        and value.get("interpretation", {}).get("bounded_native_smoke_passed")
        is True
        and value.get("interpretation", {}).get("behavior_outcome_evaluated")
        is False
        and value.get("interpretation", {}).get("held_out_seed_23197_opened")
        is False
        and value.get("interpretation", {}).get("physical_campaign_opened")
        is False
        and observed.get("complete_native_producer_population_count") == 3
        and observed.get("success_terminal_count") == 3
        and observed.get("failure_terminal_count") == 0
        and observed.get("world_attempt_count") == 3
        and observed.get("world_build_count") == 3
        and observed.get("exact_observed_solver_step_count") == 6
        and retained.get("attempt_identity_consumed") is True
        and retained.get("same_source_rerun_allowed") is False
        and retained.get("selective_engine_rerun_allowed") is False
        and claims.get("bounded_native_smoke_passed") is True
        and all(
            claim is False
            for name, claim in claims.items()
            if name != "bounded_native_smoke_passed"
        )
    )
    if not exact:
        raise ManifestError("R23D76_ATTESTATION_SMOKE_CLOSURE_INVALID")
    return value


def _load_first_qualification_failure() -> dict[str, Any]:
    value = _load_json(
        FIRST_QUALIFICATION_FAILURE,
        "R23D76_ATTESTATION_FIRST_QUALIFICATION_FAILURE_UNREADABLE",
    )
    source = value.get("source_authority", {})
    retained = value.get("retained_qualification_attempt", {})
    observed = value.get("observed_gate_population", {})
    diagnosis = value.get("diagnosis", {})
    successor = value.get("successor_constraints", {})
    exact = (
        value.get("schema_version")
        == "sporespore_qsdk_r23d76_campaign_qualification_failure_v1"
        and value.get("campaign_id") == CAMPAIGN_ID
        and value.get("gate_id") == "QSDK-R23D76"
        and value.get("status")
        == "closed_incomplete_zero_world_qualification_manifest_parameter_binding_failure"
        and re.fullmatch(r"[0-9a-f]{40}", str(source.get("source_commit", "")))
        is not None
        and source.get("source_was_clean_pushed_and_live_equal") is True
        and retained.get("attempt_identity_consumed") is True
        and retained.get("same_source_qualification_rerun_allowed") is False
        and retained.get("selective_gate_rerun_allowed") is False
        and retained.get("file_count") == 40
        and retained.get("total_byte_length") == 330248
        and observed.get("declared_total_gate_count") == 17
        and observed.get("global_gate_pass_count") == 12
        and observed.get("failed_ordinal") == 13
        and observed.get("failed_gate_id") == "R23D76-COMPLETE-ZERO-WORLD"
        and observed.get("physical_process_launch_count") == 0
        and observed.get("model_construction_count") == 0
        and observed.get("world_attempt_count") == 0
        and observed.get("world_build_count") == 0
        and observed.get("solver_step_count") == 0
        and diagnosis.get("failure_class")
        == "manifest_to_lineage_gate_parameter_binding_mismatch"
        and diagnosis.get("physics_or_behavior_failure") is False
        and diagnosis.get("campaign_local_qualification_passed") is False
        and successor.get("preserve_this_attempt_unchanged") is True
        and successor.get("distinct_clean_pushed_source_required") is True
        and successor.get("fresh_complete_qualification_required") is True
        and all(claim is False for claim in value.get("claims", {}).values())
    )
    if not exact:
        raise ManifestError(
            "R23D76_ATTESTATION_FIRST_QUALIFICATION_FAILURE_INVALID"
        )
    return value


def _load_second_qualification_failure() -> dict[str, Any]:
    value = _load_json(
        SECOND_QUALIFICATION_FAILURE,
        "R23D76_ATTESTATION_SECOND_QUALIFICATION_FAILURE_UNREADABLE",
    )
    source = value.get("source_authority", {})
    retained = value.get("retained_qualification_attempt", {})
    observed = value.get("observed_gate_population", {})
    diagnosis = value.get("diagnosis", {})
    successor = value.get("successor_constraints", {})
    exact = (
        value.get("schema_version")
        == "sporespore_qsdk_r23d76_second_campaign_qualification_failure_v1"
        and value.get("campaign_id") == CAMPAIGN_ID
        and value.get("gate_id") == "QSDK-R23D76"
        and value.get("status")
        == "closed_incomplete_zero_world_qualification_mujoco_runtime_path_binding_failure"
        and re.fullmatch(r"[0-9a-f]{40}", str(source.get("source_commit", "")))
        is not None
        and source.get("source_was_clean_pushed_and_live_equal") is True
        and retained.get("attempt_identity_consumed") is True
        and retained.get("same_source_qualification_rerun_allowed") is False
        and retained.get("selective_gate_rerun_allowed") is False
        and retained.get("file_count") == 40
        and retained.get("total_byte_length") == 331080
        and observed.get("declared_total_gate_count") == 17
        and observed.get("global_gate_pass_count") == 12
        and observed.get("failed_ordinal") == 13
        and observed.get("failed_gate_id") == "R23D76-COMPLETE-ZERO-WORLD"
        and observed.get("lineage_gate_body_started") is True
        and observed.get("physical_process_launch_count") == 0
        and observed.get("model_construction_count") == 0
        and observed.get("world_attempt_count") == 0
        and observed.get("world_build_count") == 0
        and observed.get("solver_step_count") == 0
        and diagnosis.get("failure_class")
        == "qualification_wrapper_missing_mujoco_runtime_search_path_binding"
        and diagnosis.get("wrapper_self_bound_mujoco_site_packages") is False
        and diagnosis.get("physics_or_behavior_failure") is False
        and diagnosis.get("campaign_local_qualification_passed") is False
        and successor.get("preserve_this_attempt_unchanged") is True
        and successor.get("distinct_clean_pushed_source_required") is True
        and successor.get("fresh_complete_qualification_required") is True
        and all(claim is False for claim in value.get("claims", {}).values())
    )
    if not exact:
        raise ManifestError(
            "R23D76_ATTESTATION_SECOND_QUALIFICATION_FAILURE_INVALID"
        )
    return value


def _gate(
    ordinal: int,
    gate_id: str,
    role: str,
    invocation_kind: str,
    path: Path,
    arguments: list[str],
    marker: str,
) -> dict[str, Any]:
    return {
        "ordinal": ordinal,
        "gate_id": gate_id,
        "role": role,
        "invocation_kind": invocation_kind,
        "path": _relative(path),
        "arguments": arguments,
        "terminal_marker_prefix": marker,
        "raw_sha256": _raw_sha256(path),
    }


def compose() -> dict[str, Any]:
    implementation = _load_implementation()
    smoke = _load_smoke_closure()
    first_qualification_failure = _load_first_qualification_failure()
    second_qualification_failure = _load_second_qualification_failure()
    implementation_hash = _raw_sha256(IMPLEMENTATION)
    role_hash = _raw_sha256(ROLE_GATE)
    lineage = [
        _gate(
            1,
            "R23D76-COMPLETE-ZERO-WORLD",
            "lineage",
            "powershell_file",
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
            "[turning/3e] R23D76 qualification zero-world PASS ",
        ),
        _gate(
            2,
            "R23D76-BOUNDED-NATIVE-SMOKE-CLOSURE",
            "lineage",
            "python_file",
            SMOKE_CLOSURE_AUDIT,
            [],
            "QSDK_R23D76_BOUNDED_NATIVE_SMOKE_V3_CLOSURE ",
        ),
    ]
    roles = [
        _gate(
            3,
            "R23D76-WORKER-ROLE",
            "worker",
            "powershell_file",
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
            "QSDK_R23D76_CAMPAIGN_WORKER_ROLE_PASS ",
        ),
        _gate(
            4,
            "R23D76-EVALUATOR-ROLE",
            "evaluator",
            "powershell_file",
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
            "QSDK_R23D76_CAMPAIGN_EVALUATOR_ROLE_PASS ",
        ),
        _gate(
            5,
            "R23D76-SUPERVISOR-ROLE",
            "supervisor",
            "powershell_file",
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
            "QSDK_R23D76_CAMPAIGN_SUPERVISOR_ROLE_PASS ",
        ),
    ]
    role_bindings = [
        {
            "role": "worker",
            "source_path": _relative(IMPLEMENTATION),
            "source_raw_sha256": implementation_hash,
            "test_gate_id": "R23D76-WORKER-ROLE",
            "test_path": _relative(ROLE_GATE),
            "test_raw_sha256": role_hash,
        },
        {
            "role": "evaluator",
            "source_path": _relative(EVALUATOR),
            "source_raw_sha256": _raw_sha256(EVALUATOR),
            "test_gate_id": "R23D76-EVALUATOR-ROLE",
            "test_path": _relative(ROLE_GATE),
            "test_raw_sha256": role_hash,
        },
        {
            "role": "supervisor",
            "source_path": _relative(SUPERVISOR),
            "source_raw_sha256": _raw_sha256(SUPERVISOR),
            "test_gate_id": "R23D76-SUPERVISOR-ROLE",
            "test_path": _relative(ROLE_GATE),
            "test_raw_sha256": role_hash,
        },
    ]
    source_digests = dict(implementation["dependency_digests"])
    for path in (
        IMPLEMENTATION,
        SELF,
        SUPERVISOR,
        ROLE_GATE,
        ZERO_WORLD_GATE,
        EVALUATOR,
        SMOKE_CLOSURE,
        SMOKE_CLOSURE_AUDIT,
        FIRST_QUALIFICATION_FAILURE,
        FIRST_QUALIFICATION_FAILURE_AUDIT,
        SECOND_QUALIFICATION_FAILURE,
        SECOND_QUALIFICATION_FAILURE_AUDIT,
    ):
        source_digests[_relative(path)] = _raw_sha256(path)
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
        "declared_lineage_gate_count": 2,
        "declared_campaign_gate_count": 3,
        "declared_total_gate_count": 5,
        "declared_role_binding_count": 3,
        "lineage_gates": lineage,
        "campaign_gates": roles,
        "campaign_role_bindings": role_bindings,
        "dependency_authority": {
            "path": _relative(IMPLEMENTATION),
            "raw_sha256": implementation_hash,
        },
        "bounded_native_smoke_closure": {
            "path": _relative(SMOKE_CLOSURE),
            "raw_sha256": _raw_sha256(SMOKE_CLOSURE),
            "audit_path": _relative(SMOKE_CLOSURE_AUDIT),
            "audit_raw_sha256": _raw_sha256(SMOKE_CLOSURE_AUDIT),
            "attempt_id": smoke["retained_attempt"]["attempt_id"],
            "source_commit": smoke["source_authority"]["source_commit"],
            "native_engine_count": 3,
            "world_build_count": 3,
            "solver_step_count": 6,
            "behavior_outcome_evaluated": False,
            "held_out_seed_23197_opened": False,
        },
        "first_campaign_qualification_failure": {
            "path": _relative(FIRST_QUALIFICATION_FAILURE),
            "raw_sha256": _raw_sha256(FIRST_QUALIFICATION_FAILURE),
            "audit_path": _relative(FIRST_QUALIFICATION_FAILURE_AUDIT),
            "audit_raw_sha256": _raw_sha256(
                FIRST_QUALIFICATION_FAILURE_AUDIT
            ),
            "source_commit": first_qualification_failure["source_authority"][
                "source_commit"
            ],
            "attempt_root": first_qualification_failure[
                "retained_qualification_attempt"
            ]["attempt_root"],
            "global_gate_pass_count": 12,
            "failed_ordinal": 13,
            "failed_gate_id": "R23D76-COMPLETE-ZERO-WORLD",
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "reusable": False,
        },
        "second_campaign_qualification_failure": {
            "path": _relative(SECOND_QUALIFICATION_FAILURE),
            "raw_sha256": _raw_sha256(SECOND_QUALIFICATION_FAILURE),
            "audit_path": _relative(SECOND_QUALIFICATION_FAILURE_AUDIT),
            "audit_raw_sha256": _raw_sha256(
                SECOND_QUALIFICATION_FAILURE_AUDIT
            ),
            "source_commit": second_qualification_failure["source_authority"][
                "source_commit"
            ],
            "attempt_root": second_qualification_failure[
                "retained_qualification_attempt"
            ]["attempt_root"],
            "global_gate_pass_count": 12,
            "failed_ordinal": 13,
            "failed_gate_id": "R23D76-COMPLETE-ZERO-WORLD",
            "failure_class": (
                "qualification_wrapper_missing_mujoco_runtime_search_path_binding"
            ),
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "reusable": False,
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
            raise ManifestError("R23D76_ATTESTATION_MANIFEST_MATERIALIZATION_DRIFT")
    else:
        sys.stdout.buffer.write(raw)
        return 0
    print(
        "QSDK_R23D76_ATTESTATION_MANIFEST "
        + json.dumps(
            {
                "path": _relative(OUTPUT),
                "raw_sha256": _raw_sha256(OUTPUT),
                "source_binding_count": len(value["source_bindings"]),
                "lineage_gate_count": 2,
                "campaign_gate_count": 3,
                "bounded_native_smoke_passed": True,
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
