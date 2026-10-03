"""Compact closure audit for the R24D54-L2 production-route authority probe."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CLOSURE = ROOT / "sdk/recovery/r24d54_rapier_authority_route_probe_repair_closure_v1.json"
DECLARATION = ROOT / "sdk/recovery/r24d54_rapier_authority_route_probe_repair_v1.json"
CONTRACT = ROOT / "sdk/recovery/r24d54_rapier_recovery_energy_v3_behavior_contract_v1.json"
L1_CLOSURE = ROOT / "sdk/recovery/r24d54_rapier_integration_authority_routing_repair_closure_v1.json"
L1_AUDIT = ROOT / "tests/test_qsdk_r24d54_rapier_integration_authority_routing_repair_closure.py"
SOURCE_AUDIT = ROOT / "tests/test_qsdk_r24d54_rapier_authority_route_probe_repair.py"
RELEASE = ROOT / "sdk/release/quadruped_release_contract.json"
SUPPORT = ROOT / "sdk/release/quadruped_support_matrix.json"
MAPPING = ROOT / "sdk/release/quadruped_sdk1_milestone_mapping_v1.json"
RUNNER_RELATIVE = "sdk/run_qsdk_r24d48_rapier_recovery_energy_v2.ps1"
PROBE_PREFIX = "qsdk-r24d54-rapier-recovery-energy-v3-authority-route-probe-"


class AuditError(RuntimeError):
    """Raised when an immutable L2 closure assertion fails."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def exact(actual: Any, expected: Any, code: str) -> None:
    require(actual == expected, f"{code}:{actual!r}!={expected!r}")


def digest(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def repository_text_digest(path: Path) -> str:
    return digest(path.read_text(encoding="utf-8").replace("\r\n", "\n").encode())


def git(*arguments: str, text: bool = True) -> str | bytes:
    return subprocess.check_output(
        ["git", *arguments], cwd=ROOT, text=text
    ).strip() if text else subprocess.check_output(["git", *arguments], cwd=ROOT)


def records_with_key(value: Any, key: str) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if key in value:
            records.append(value)
        for child in value.values():
            records.extend(records_with_key(child, key))
    elif isinstance(value, list):
        for child in value:
            records.extend(records_with_key(child, key))
    return records


def run_retained_audit(path: Path, marker: str) -> None:
    result = subprocess.run(
        [sys.executable, str(path)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    require(
        result.returncode == 0 and marker in result.stdout,
        f"RETAINED_AUDIT:{path.name}:{result.stdout}:{result.stderr}",
    )


def audit() -> None:
    closure = json.loads(CLOSURE.read_text(encoding="utf-8"))
    declaration = json.loads(DECLARATION.read_text(encoding="utf-8"))
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    exact(
        (
            closure["schema_version"],
            closure["gate_id"],
            closure["stage_id"],
            closure["closure_status"],
            closure["question_class"],
        ),
        (
            "sporespore_qsdk_r24d54_rapier_authority_route_probe_repair_closure_v1",
            "QSDK-R24D54",
            "R24D54-L2",
            "closed_complete_zero_world_production_route_authority_probe_repair_qualified",
            "development_launch_authority_repair",
        ),
        "CLOSURE_IDENTITY",
    )
    for key in (
        "physical_question_declared",
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        exact(closure[key], False, f"CLOSURE_{key.upper()}")

    predecessor = closure["predecessor_launcher_repair"]
    exact(repository_text_digest(L1_CLOSURE), predecessor["closure_raw_sha256"], "L1_DIGEST")
    exact(predecessor["full_cold_equivalence_development_qualification_passed"], True, "L1_COLD")
    source = closure["repair_source"]
    commit = source["commit"]
    exact(git("rev-parse", f"{commit}^"), source["parent_commit"], "SOURCE_PARENT")
    exact(git("rev-parse", f"{commit}^{{tree}}"), source["tree"], "SOURCE_TREE")
    for record_name in ("runner", "declaration", "source_test"):
        record = source[record_name]
        raw = git("show", f"{commit}:{record['path']}", text=False)
        exact(len(raw), record["repository_text_byte_length"], f"{record_name.upper()}_BYTES")
        exact(digest(raw), record["repository_text_sha256"], f"{record_name.upper()}_DIGEST")
        exact(git("rev-parse", f"{commit}:{record['path']}"), record["git_blob_oid"], f"{record_name.upper()}_BLOB")

    code_paths = contract["physical_runner"]["qualification_source_code_paths"]
    changed = git(
        "diff", "--name-only", closure["base_qualification"]["source_commit"], commit,
        "--", *code_paths,
    ).splitlines()
    exact(changed, [RUNNER_RELATIVE], "QUALIFIED_PATH_DIFF")
    exact(closure["authority_only_qualified_path_exclusions"], changed, "EXCLUSIONS")
    exact(
        closure["qualified_unchanged_source_paths"],
        [path for path in code_paths if path != RUNNER_RELATIVE],
        "UNCHANGED_PATHS",
    )

    probe = closure["authority_route_probe"]
    probe_root = Path(probe["evidence_root"])
    files = sorted(path for path in probe_root.rglob("*") if path.is_file())
    exact([path.relative_to(probe_root).as_posix() for path in files], [probe["receipt_path"]], "PROBE_TREE")
    exact(sum(path.stat().st_size for path in files), probe["retained_total_byte_length"], "PROBE_TREE_BYTES")
    receipt_path = probe_root / probe["receipt_path"]
    exact(receipt_path.stat().st_size, probe["receipt_byte_length"], "RECEIPT_BYTES")
    exact(digest(receipt_path.read_bytes()), probe["receipt_raw_sha256"], "RECEIPT_DIGEST")
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    exact(
        (
            receipt["schema_version"], receipt["gate_id"], receipt["stage_id"],
            receipt["mode"], receipt["source_commit"], receipt["qualification_source_commit"],
            receipt["stage_authority_raw_sha256"], receipt["worktree_clean"],
        ),
        (
            probe["receipt_schema_version"], "QSDK-R24D54", "R24D54-L2",
            "authority_route_probe", commit, closure["base_qualification"]["source_commit"],
            source["declaration"]["repository_text_sha256"], True,
        ),
        "RECEIPT_IDENTITY",
    )
    exact(
        (receipt["upstream_commit"], receipt["live_remote_commit"]),
        (commit, commit),
        "RECEIPT_LIVE_EQUALITY",
    )
    exact(repository_text_digest(ROOT / receipt["integration_closure_path"]), receipt["integration_closure_raw_sha256"], "INTEGRATION_CLOSURE")
    exact(digest(Path(receipt["integration_result_path"]).read_bytes()), receipt["integration_result_raw_sha256"], "INTEGRATION_RESULT")
    lock = receipt["operation_lock"]
    exact(
        (lock["acquired"], lock["role"], lock["mutex_name"], lock["test_only"], receipt["operation_lock_released"]),
        (True, probe["operation_lock_role"], probe["operation_lock_mutex_name"], False, True),
        "OPERATION_LOCK",
    )
    exact(
        (receipt["authority_route_validated"], receipt["ghost_authority_present"], receipt["development_integration_authority_present"]),
        (True, False, True),
        "AUTHORITY_PARTITION",
    )
    zero_fields = (
        "model_construction_count", "world_attempt_count", "world_build_count", "solver_step_count"
    )
    for key in zero_fields:
        exact(receipt[key], 0, f"RECEIPT_{key.upper()}")
    for key in (
        "physical_attempt_record_created", "physics_state_modified", "physical_question_opened",
        "physical_attempt_consumed", "physical_acceptance_authority", "release_authority",
    ):
        exact(receipt[key], False, f"RECEIPT_{key.upper()}")
    same_source_probe_count = 0
    for candidate in probe_root.parent.glob(f"{PROBE_PREFIX}*"):
        candidate_receipt = candidate / probe["receipt_path"]
        if candidate_receipt.is_file():
            value = json.loads(candidate_receipt.read_text(encoding="utf-8"))
            same_source_probe_count += value.get("source_commit") == commit
    exact(same_source_probe_count, probe["same_source_probe_attempt_count"], "PROBE_ATTEMPT_COUNT")

    decision = closure["decision"]
    for key in (
        "observed_launcher_failure_pre_physics",
        "single_changed_qualified_path_proven",
        "twenty_two_qualified_paths_unchanged",
        "full_cold_equivalence_development_qualification_passed",
        "integration_authority_routing_qualified",
        "production_route_authority_probe_passed",
        "launcher_repair_authority",
        "r24d54_paired_physical_attempt_remains_unconsumed",
        "r24d54_paired_development_authorized",
    ):
        exact(decision[key], True, f"DECISION_{key.upper()}")
    exact(
        (decision["physical_attempt_consumed"], decision["physical_acceptance_authority"], decision["release_authority"]),
        (False, False, False),
        "DECISION_CLAIM_BOUNDARY",
    )
    exact(
        (decision["authorized_world_count"], decision["maximum_outer_steps_per_arm"], decision["maximum_physical_steps_authorized"]),
        (2, 1200, 2400),
        "FINITE_AUTHORITY",
    )

    closure_digest = repository_text_digest(CLOSURE)
    expected_status = "closed_base_zero_world_l1_cold_equivalence_and_l2_production_route_probe_qualified_paired_development_authorized"
    for ledger_path in (RELEASE, SUPPORT):
        ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
        records = records_with_key(ledger, "r24d54_question_class")
        exact(len(records), 1, f"LEDGER_RECORD_COUNT:{ledger_path.name}")
        record = records[0]
        exact(
            (
                record["r24d54_source_status"],
                record["r24d54_authority_route_probe_repair_closure_raw_sha256"],
                record["r24d54_authority_route_probe_repair_qualified"],
                record["r24d54_production_route_authority_probe_passed"],
                record["r24d54_paired_development_authorized"],
                record["r24d54_authorized_world_count"],
                record["r24d54_maximum_total_outer_steps"],
                record["physical_execution_blocked_pending_r24d54_authority_route_probe_qualification"],
            ),
            (expected_status, closure_digest, True, True, True, 2, 2400, False),
            f"LEDGER_L2:{ledger_path.name}",
        )
    mapping = json.loads(MAPPING.read_text(encoding="utf-8"))
    exact(mapping["full_program_authority"]["release_contract_raw_sha256"], digest(RELEASE.read_bytes()), "MAPPING_RELEASE")
    exact(mapping["full_program_authority"]["support_matrix_raw_sha256"], digest(SUPPORT.read_bytes()), "MAPPING_SUPPORT")

    run_retained_audit(
        L1_AUDIT,
        "QSDK_R24D54_RAPIER_INTEGRATION_AUTHORITY_ROUTING_REPAIR_CLOSURE_PASS",
    )
    run_retained_audit(
        SOURCE_AUDIT,
        "QSDK_R24D54_RAPIER_AUTHORITY_ROUTE_PROBE_REPAIR_PASS",
    )
    print(
        "QSDK_R24D54_RAPIER_AUTHORITY_ROUTE_PROBE_REPAIR_CLOSURE_PASS "
        "changed_paths=1 unchanged_paths=22 controls=9/9 mutations=6/6 "
        "probe_receipts=1 lock=conformance models=0 worlds=0 solver_steps=0 "
        "physical=false authorized=2x1200 sdk1=11/20 next=QSDK-R24D54"
    )


if __name__ == "__main__":
    try:
        audit()
    except (AuditError, OSError, KeyError, TypeError, ValueError, subprocess.SubprocessError) as error:
        print(f"QSDK_R24D54_RAPIER_AUTHORITY_ROUTE_PROBE_REPAIR_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
