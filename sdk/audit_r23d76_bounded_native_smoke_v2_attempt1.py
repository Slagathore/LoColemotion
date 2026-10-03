"""Audit the retained integration-invalid first R23D76 smoke v2 attempt."""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CLOSURE = ROOT / "sdk/turning/r23d76_bounded_native_smoke_v2_attempt1_closure.json"
MARKER = "QSDK_R23D76_BOUNDED_NATIVE_SMOKE_V2_ATTEMPT1 "


class AuditError(RuntimeError):
    pass


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(f"R23D76_SMOKE_V2_ATTEMPT1_{code}")


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
    encoded = "".join(
        f"{row['relative_path']}\t{row['byte_length']}\t{row['sha256']}\n"
        for row in rows
    ).encode("utf-8")
    return rows, sum(int(row["byte_length"]) for row in rows), _sha(encoded)


def audit() -> dict[str, Any]:
    closure = _load(CLOSURE)
    _require(
        closure.get("schema_version")
        == "sporespore_qsdk_r23d76_bounded_native_smoke_v2_attempt_closure_v1",
        "SCHEMA_INVALID",
    )
    _require(
        closure.get("status")
        == "closed_consumed_integration_invalid_complete_three_worker_population_"
        "mujoco_preflight_bridge_signature_drift",
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

    retained = closure["retained_attempt"]
    attempt_root = Path(retained["attempt_root"]).resolve(strict=True)
    attempt_root.relative_to((ROOT.parent / "SporeSpore_Evidence").resolve(strict=True))
    rows, byte_length, manifest = _manifest(attempt_root)
    _require(len(rows) == retained["file_count"] == 36, "FILE_COUNT_INVALID")
    _require(byte_length == retained["total_byte_length"] == 226454, "BYTE_COUNT_INVALID")
    _require(manifest == retained["canonical_manifest_sha256"], "MANIFEST_INVALID")
    by_path = {row["relative_path"]: row for row in rows}
    for selected in retained["selected_artifacts"]:
        _require(by_path.get(selected["relative_path"]) == selected, "ARTIFACT_INVALID")

    result = _load(attempt_root / "supervisor-result.json")
    completion = _load(attempt_root / "attempt-completion.json")
    proof = _load(attempt_root / "pre-physical/precise-invalidation-proof.json")
    diagnosis = _load(attempt_root / "postmortem/mujoco-preflight-bridge-failure.json")
    terminals = {
        "godot_jolt": _load(
            attempt_root / "physical/00__godot_jolt_bounded_native_smoke_v2/terminal.json"
        ),
        "rapier_parry": _load(
            attempt_root / "physical/01__rapier_parry_bounded_native_smoke_v2/terminal.json"
        ),
        "mujoco": _load(
            attempt_root / "physical/02__mujoco_bounded_native_smoke_v2/terminal.json"
        ),
    }
    _require(
        result.get("attempt_id") == retained["attempt_id"]
        and result.get("source_commit") == commit
        and result.get("bounded_native_smoke_passed") is False
        and result.get("physical_worker_process_count") == 3
        and result.get("world_attempt_count") == 2
        and result.get("world_build_count") == 2
        and result.get("worker_success_terminal_count") == 2
        and result.get("worker_failure_terminal_count") == 1
        and result.get("uses_held_out_seed_23197") is False
        and result.get("behavior_outcome_evaluated") is False,
        "RESULT_INVALID",
    )
    _require(
        completion.get("attempt_identity_consumed") is True
        and completion.get("same_attempt_rerun_allowed") is False
        and completion.get("bounded_native_smoke_passed") is False,
        "COMPLETION_INVALID",
    )
    _require(
        proof.get("exact_reuse_artifact_count") == 14
        and proof.get("invalidated_artifact_count") == 1
        and proof.get("invalidated_artifact_focused_preflight_passed") is True
        and proof.get("composite_zero_world_qualification_passed") is True
        and proof.get("world_build_count") == 0,
        "PRECISE_INVALIDATION_INVALID",
    )
    for engine_id in ("godot_jolt", "rapier_parry"):
        terminal = terminals[engine_id]
        _require(
            terminal.get("engine_id") == engine_id
            and terminal.get("execution", {}).get("world_attempt_count") == 1
            and terminal.get("execution", {}).get("world_build_count") == 1
            and terminal.get("execution", {}).get("controller_semantic_step_count") == 2,
            "SUCCESS_TERMINAL_INVALID:" + engine_id,
        )
    mujoco = terminals["mujoco"]
    expected_failure = (
        "QSDK_R23D3_MJC_PREFLIGHT_ERROR:TypeError:_inherited_preflight_bridge() "
        "got an unexpected keyword argument 'forward_displacement_measurement_origin_plan'"
    )
    _require(
        mujoco.get("failure_code") == expected_failure
        and mujoco.get("failure_stage") == "before_world"
        and mujoco.get("world_attempt_count") == 0
        and mujoco.get("world_build_count") == 0,
        "MUJOCO_FAILURE_INVALID",
    )
    _require(
        diagnosis.get("diagnosis", {}).get("class")
        == "native_integration_signature_drift"
        and diagnosis.get("successor_limit", {}).get("same_source_rerun_allowed")
        is False,
        "DIAGNOSIS_INVALID",
    )
    _require(all(value is False for value in closure["claims"].values()), "CLAIM_TRUE")
    return {
        "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v2_attempt1_audit_v1",
        "closure_id": closure["closure_id"],
        "passed": True,
        "file_count": len(rows),
        "physical_worker_process_count": 3,
        "world_attempt_count": 2,
        "world_build_count": 2,
        "exact_observed_solver_step_count": 4,
        "held_out_seed_23197_opened": False,
        "bounded_native_smoke_passed": False,
        "physical_acceptance_authority": False,
    }


if __name__ == "__main__":
    try:
        print(MARKER + json.dumps(audit(), sort_keys=True, separators=(",", ":")))
    except (AuditError, OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(f"{MARKER}{type(error).__name__}:{error}") from error
