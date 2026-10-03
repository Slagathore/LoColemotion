"""Executable closure audit for the consumed prephysical R23D76 smoke v1."""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CLOSURE_PATH = ROOT / "sdk/turning/r23d76_bounded_native_smoke_v1_closure.json"
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
MARKER = "QSDK_R23D76_BOUNDED_NATIVE_SMOKE_V1_CLOSURE "


class ClosureAuditError(RuntimeError):
    pass


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureAuditError(f"R23D76_SMOKE_V1_CLOSURE_{code}")


def _load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    _require(isinstance(value, dict), "JSON_NOT_OBJECT")
    return value


def _sha(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _git(*arguments: str, binary: bool = False) -> bytes | str:
    completed = subprocess.run(
        ["git", "-C", str(ROOT), *arguments],
        capture_output=True,
        check=False,
        text=not binary,
    )
    _require(completed.returncode == 0, "GIT_FAILED:" + ":".join(arguments))
    return completed.stdout if binary else completed.stdout.strip()


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
    encoded = "".join(
        f"{row['relative_path']}\t{row['byte_length']}\t{row['sha256']}\n"
        for row in rows
    ).encode("utf-8")
    return rows, sum(int(row["byte_length"]) for row in rows), _sha(encoded)


def audit() -> dict[str, Any]:
    closure = _load(CLOSURE_PATH)
    _require(
        closure.get("schema_version")
        == "sporespore_qsdk_r23d76_bounded_native_smoke_v1_closure_v1",
        "SCHEMA_INVALID",
    )
    _require(
        closure.get("status")
        == "closed_consumed_prephysical_incomplete_zero_world_no_native_world_opened",
        "STATUS_INVALID",
    )
    _require(_git("remote", "get-url", "origin") == EXPECTED_REMOTE, "REMOTE_INVALID")

    source = closure["source_authority"]
    commit = str(source["source_commit"])
    _require(len(commit) == 40, "SOURCE_COMMIT_INVALID")
    _require(
        _git("rev-parse", f"{commit}^{{tree}}") == source["source_tree_git_oid"],
        "SOURCE_TREE_INVALID",
    )
    ancestor = subprocess.run(
        ["git", "-C", str(ROOT), "merge-base", "--is-ancestor", commit, "origin/main"],
        capture_output=True,
        check=False,
    )
    _require(ancestor.returncode == 0, "SOURCE_NOT_REACHABLE_FROM_ORIGIN_MAIN")
    _require(source.get("source_was_clean_pushed_and_live_equal") is True, "SOURCE_NOT_FROZEN")
    for artifact in source["source_artifacts"]:
        raw = _git("show", f"{commit}:{artifact['path']}", binary=True)
        _require(isinstance(raw, bytes), "SOURCE_ARTIFACT_READ_INVALID")
        _require(len(raw) == artifact["byte_length"], "SOURCE_ARTIFACT_LENGTH_INVALID")
        _require(_sha(raw) == artifact["sha256"], "SOURCE_ARTIFACT_DIGEST_INVALID")

    retained = closure["retained_attempt"]
    attempt_root = Path(retained["attempt_root"]).resolve(strict=True)
    evidence_root = (ROOT.parent / "SporeSpore_Evidence").resolve(strict=True)
    attempt_root.relative_to(evidence_root)
    rows, total_bytes, manifest_sha = _manifest(attempt_root)
    _require(len(rows) == retained["file_count"] == 7, "FILE_COUNT_INVALID")
    _require(total_bytes == retained["total_byte_length"] == 10814, "BYTE_COUNT_INVALID")
    _require(
        manifest_sha == retained["canonical_manifest_sha256"],
        "MANIFEST_DIGEST_INVALID",
    )
    row_by_path = {row["relative_path"]: row for row in rows}
    for selected in retained["selected_artifacts"]:
        _require(
            row_by_path.get(selected["relative_path"]) == selected,
            "SELECTED_ARTIFACT_INVALID:" + selected["relative_path"],
        )

    reservation = _load(attempt_root / "operation-reservation.json")
    incomplete = _load(attempt_root / "supervisor-incomplete.json")
    build = _load(
        attempt_root / "pre-physical/processes/00__rapier_build/process.json"
    )
    source_preflight = _load(attempt_root / "pre-physical/source-preflight.json")
    diagnosis = _load(attempt_root / "postmortem/artifact-drift.json")
    _require(reservation.get("source_commit") == commit, "RESERVATION_SOURCE_INVALID")
    _require(
        reservation.get("attempt_id") == retained["attempt_id"]
        and reservation.get("uses_held_out_seed_23197") is False,
        "RESERVATION_IDENTITY_INVALID",
    )
    _require(
        incomplete.get("failure_code")
        == "BoundedSmokeError:R23D76_BOUNDED_SMOKE_COLD_DEPENDENCY_OR_TOOLCHAIN_DRIFT"
        and incomplete.get("attempt_identity_consumed") is True
        and incomplete.get("physical_worker_process_count") == 0
        and incomplete.get("world_attempt_count") == 0
        and incomplete.get("world_build_count") == 0
        and incomplete.get("uses_held_out_seed_23197") is False,
        "INCOMPLETE_RESULT_INVALID",
    )
    _require(
        build.get("name") == "rapier_build"
        and build.get("exit_code") == 0
        and build.get("timed_out") is False,
        "BUILD_RECEIPT_INVALID",
    )
    _require(
        source_preflight.get("world_build_count") == 0
        and source_preflight.get("solver_step_count") == 0
        and source_preflight.get("physical_execution_authorized") is False,
        "SOURCE_PREFLIGHT_INVALID",
    )
    _require(
        diagnosis.get("historical_dependency_artifact_count") == 15
        and diagnosis.get("exact_artifact_count_after_build") == 14
        and diagnosis.get("drifted_artifact_count_after_build") == 1
        and diagnosis.get("interpretation", {}).get("world_build_count") == 0
        and diagnosis.get("interpretation", {}).get("solver_step_count") == 0
        and diagnosis.get("interpretation", {}).get("held_out_seed_23197_opened")
        is False,
        "DIAGNOSIS_INVALID",
    )
    _require(not (attempt_root / "physical").exists(), "PHYSICAL_DIRECTORY_PRESENT")
    observed = closure["observed_result"]
    _require(
        observed.get("physical_worker_process_count") == 0
        and observed.get("model_construction_count") == 0
        and observed.get("world_attempt_count") == 0
        and observed.get("world_build_count") == 0
        and observed.get("solver_step_count") == 0
        and observed.get("held_out_seed_23197_opened") is False
        and observed.get("bounded_native_smoke_passed") is False,
        "OBSERVED_RESULT_INVALID",
    )
    _require(all(value is False for value in closure["claims"].values()), "CLAIM_TRUE")
    return {
        "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v1_closure_audit_v1",
        "closure_id": closure["closure_id"],
        "passed": True,
        "file_count": len(rows),
        "total_byte_length": total_bytes,
        "physical_worker_process_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "held_out_seed_23197_opened": False,
        "physical_acceptance_authority": False,
    }


if __name__ == "__main__":
    try:
        print(MARKER + json.dumps(audit(), sort_keys=True, separators=(",", ":")))
    except (ClosureAuditError, OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(f"{MARKER}{type(error).__name__}:{error}") from error
