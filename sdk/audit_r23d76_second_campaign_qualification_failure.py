"""Audit the second closed, zero-world R23D76 qualification failure."""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CLOSURE = (
    ROOT / "sdk/turning/r23d76_second_campaign_qualification_failure_v1.json"
)
MARKER = "QSDK_R23D76_SECOND_CAMPAIGN_QUALIFICATION_FAILURE "


class AuditError(RuntimeError):
    pass


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(f"R23D76_SECOND_QUALIFICATION_{code}")


def _load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    _require(isinstance(value, dict), "JSON_NOT_OBJECT")
    return value


def _sha(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _git(*arguments: str, binary: bool = False) -> str | bytes:
    result = subprocess.run(
        ["git", "-C", str(ROOT), *arguments],
        capture_output=True,
        check=False,
        text=not binary,
    )
    _require(result.returncode == 0, "GIT_FAILED:" + ":".join(arguments))
    return result.stdout if binary else result.stdout.strip()


def _manifest(root: Path) -> tuple[list[dict[str, Any]], int, str]:
    rows: list[dict[str, Any]] = []
    for path in sorted(
        (candidate for candidate in root.rglob("*") if candidate.is_file()),
        key=lambda candidate: candidate.relative_to(root).as_posix(),
    ):
        raw = path.read_bytes()
        rows.append(
            {
                "relative_path": path.relative_to(root).as_posix(),
                "byte_length": len(raw),
                "sha256": _sha(raw),
            }
        )
    raw_manifest = "".join(
        f"{row['relative_path']}\t{row['byte_length']}\t{row['sha256']}\n"
        for row in rows
    ).encode("utf-8")
    return rows, sum(int(row["byte_length"]) for row in rows), _sha(raw_manifest)


def audit() -> dict[str, Any]:
    closure = _load(CLOSURE)
    _require(
        closure.get("schema_version")
        == "sporespore_qsdk_r23d76_second_campaign_qualification_failure_v1",
        "SCHEMA_INVALID",
    )
    _require(
        closure.get("status")
        == "closed_incomplete_zero_world_qualification_mujoco_runtime_path_binding_failure",
        "STATUS_INVALID",
    )

    source = closure["source_authority"]
    commit = source["source_commit"]
    _require(
        _git("rev-parse", f"{commit}^{{tree}}") == source["source_tree_git_oid"],
        "SOURCE_TREE_INVALID",
    )
    ancestor = subprocess.run(
        ["git", "-C", str(ROOT), "merge-base", "--is-ancestor", commit, "origin/main"],
        capture_output=True,
        check=False,
    )
    _require(ancestor.returncode == 0, "SOURCE_NOT_REACHABLE")
    for artifact in source["source_artifacts"]:
        raw = _git("show", f"{commit}:{artifact['path']}", binary=True)
        _require(isinstance(raw, bytes), "SOURCE_ARTIFACT_INVALID")
        _require(
            len(raw) == artifact["byte_length"] and _sha(raw) == artifact["sha256"],
            "SOURCE_ARTIFACT_DRIFT:" + artifact["path"],
        )

    retained = closure["retained_qualification_attempt"]
    attempt_root = Path(retained["attempt_root"]).resolve(strict=True)
    evidence_root = (ROOT.parent / "SporeSpore_Evidence").resolve(strict=True)
    attempt_root.relative_to(evidence_root)
    rows, byte_length, manifest = _manifest(attempt_root)
    _require(len(rows) == retained["file_count"] == 40, "FILE_COUNT_INVALID")
    _require(
        byte_length == retained["total_byte_length"] == 331080,
        "BYTE_COUNT_INVALID",
    )
    _require(manifest == retained["canonical_manifest_sha256"], "MANIFEST_INVALID")
    by_path = {row["relative_path"]: row for row in rows}
    for selected in retained["selected_artifacts"]:
        _require(by_path.get(selected["relative_path"]) == selected, "ARTIFACT_INVALID")

    expected_global_ids = closure["observed_gate_population"][
        "ordered_passing_global_gate_ids"
    ]
    _require(len(expected_global_ids) == 12, "GLOBAL_GATE_DECLARATION_INVALID")
    for ordinal, gate_id in enumerate(expected_global_ids, start=1):
        prefix = f"{ordinal:03d}-{gate_id}"
        receipt = _load(attempt_root / f"{prefix}.receipt.json")
        _require(
            receipt.get("ordinal") == ordinal
            and receipt.get("gate_id") == gate_id
            and receipt.get("passed") is True
            and receipt.get("exit_code") == 0
            and receipt.get("timed_out") is False
            and receipt.get("physical_process_launch_count") == 0
            and receipt.get("physical_world_count") == 0
            and receipt.get("physical_acceptance_authority") is False,
            "GLOBAL_GATE_INVALID:" + gate_id,
        )

    failed = _load(attempt_root / "013-R23D76-COMPLETE-ZERO-WORLD.receipt.json")
    stderr_path = attempt_root / "013-R23D76-COMPLETE-ZERO-WORLD.stderr.log"
    stderr_raw = stderr_path.read_bytes()
    stderr = stderr_raw.decode("utf-8")
    _require(
        "mujoco preflight failed:" in stderr
        and "ModuleNotFoundError: No module named 'mujoco'" in stderr,
        "STDERR_INVALID",
    )
    _require(
        failed.get("ordinal") == 13
        and failed.get("gate_id") == "R23D76-COMPLETE-ZERO-WORLD"
        and failed.get("path")
        == "tests/test_qsdk_r23d76_zero_world_qualification_v2.ps1"
        and failed.get("arguments", [])[-1] == "-ExpectProductionConformanceLockHeld"
        and failed.get("source_raw_sha256")
        == "sha256:fe7a717a358d222a37c32d8981c3be9557fced2bd70e276e198960d27707306c"
        and failed.get("passed") is False
        and failed.get("exit_code") == 1
        and failed.get("timed_out") is False
        and failed.get("terminal_marker_count") == 0
        and failed.get("physical_process_launch_count") == 0
        and failed.get("physical_world_count") == 0
        and failed.get("physical_acceptance_authority") is False,
        "FAILED_GATE_INVALID",
    )
    stderr_cas = failed["stderr_cas"]
    stderr_payload = Path(stderr_cas["payload_path"])
    _require(
        stderr_payload.is_file()
        and len(stderr_raw) == stderr_cas["byte_length"] == 938
        and _sha(stderr_raw) == stderr_cas["sha256"]
        and stderr_payload.read_bytes() == stderr_raw,
        "FAILED_GATE_STDERR_CAS_INVALID",
    )

    failure = _load(attempt_root / "failure.json")
    _require(
        failure.get("campaign_id") == closure["campaign_id"]
        and failure.get("source_commit") == commit
        and failure.get("message")
        == "Campaign-local attestation gate failed: R23D76-COMPLETE-ZERO-WORLD exit=1 timeout=False marker_count=0"
        and failure.get("campaign_local_qualification_passed") is False
        and failure.get("physical_launch_prerequisite_satisfied") is False
        and failure.get("physical_acceptance_authority") is False
        and failure.get("release_authority") is False,
        "FAILURE_DOCUMENT_INVALID",
    )
    _require(not (attempt_root / "attestation.json").exists(), "ATTESTATION_UNEXPECTED")
    _require(
        retained.get("attempt_identity_consumed") is True
        and retained.get("same_source_qualification_rerun_allowed") is False
        and retained.get("selective_gate_rerun_allowed") is False,
        "RERUN_BOUNDARY_INVALID",
    )
    diagnosis = closure["diagnosis"]
    _require(
        diagnosis.get("failure_class")
        == "qualification_wrapper_missing_mujoco_runtime_search_path_binding"
        and diagnosis.get("wrapper_self_bound_mujoco_site_packages") is False
        and diagnosis.get("physics_or_behavior_failure") is False
        and diagnosis.get("campaign_attestation_adoption_attempted") is False,
        "DIAGNOSIS_INVALID",
    )
    _require(
        all(value is False for value in closure["claims"].values()),
        "CLAIMS_INVALID",
    )
    return {
        "schema_version": "sporespore_qsdk_r23d76_second_campaign_qualification_failure_audit_v1",
        "closure_id": closure["closure_id"],
        "passed": True,
        "file_count": len(rows),
        "global_gate_pass_count": 12,
        "failed_ordinal": 13,
        "failed_gate_id": "R23D76-COMPLETE-ZERO-WORLD",
        "failure_class": diagnosis["failure_class"],
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "held_out_seed_23197_opened": False,
        "campaign_local_qualification_passed": False,
        "physical_acceptance_authority": False,
    }


if __name__ == "__main__":
    try:
        print(MARKER + json.dumps(audit(), sort_keys=True, separators=(",", ":")))
    except (AuditError, OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(f"{MARKER}{type(error).__name__}:{error}") from error
