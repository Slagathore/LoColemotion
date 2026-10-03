#!/usr/bin/env python3
"""Audit the zero-world QSDK-R10D-L1 stage-freeze representation repair."""

from __future__ import annotations

import copy
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
GODOT = Path(
    r"C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
)
DESIGN_PATH = (
    ROOT
    / "sdk/qsdk_r10d_l1_stage_freeze_numeric_normalization_successor_design_v1.json"
)
DIAGNOSIS_PATH = ROOT / "tests/test_sdk_qsdk_r10d_l1_retained_stage_freeze_diagnosis.gd"
PREDECESSOR_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10d_development_route_ghost_physical_closure_v1.json"
)
PREDECESSOR_STAGE_PATH = (
    ROOT
    / "sdk/qsdk_r10d_development_route_ghost_zero_world_qualification_closure_v1.json"
)
PREDECESSOR_AUTHORITY_PATH = (
    ROOT / "sdk/qsdk_r10d_development_route_ghost_execution_authority_v1.json"
)
EVIDENCE_ROOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    r"\qsdk-r10d-development-route-ghost-physical-f060ca2137c4"
)
ATTEMPT_PATH = EVIDENCE_ROOT / "baseline_s40001/attempt.json"
REPORT_PATH = EVIDENCE_ROOT / "report.json"
STDOUT_PATH = EVIDENCE_ROOT / "baseline_s40001/stdout.log"
EXPECTED_DESIGN_BYTES = 8_548
EXPECTED_DESIGN_SHA256 = (
    "sha256:f98f9f057e6f583b6f0f356a983cdcbcb4d6818f217fe055edd96ddcbf326db3"
)
EXPECTED_FILES = {
    PREDECESSOR_CLOSURE_PATH: (
        7_196,
        "sha256:fbefa85145bcd5bb05c3672c4fe6a0b56eaf75751ae8ed5dae9ff724487b4475",
        "9a4b819bd27a115e804973ff2d496c52ded84305",
    ),
    PREDECESSOR_STAGE_PATH: (
        25_054,
        "sha256:e30828c9896aad6ef6f34f1c52690f60884eae3f4e708ef123c5dd888f311e04",
        "ed182295d4c1b9c3f9f6cd91b9e9fb6a95b9e557",
    ),
    PREDECESSOR_AUTHORITY_PATH: (
        2_066,
        "sha256:74c4f67ec7119e6b92d302e504f8ef8a65f56dff6010a1084e5752ca504eb25d",
        "fe81093ed19038854e80b72f320f21ece567edde",
    ),
}
EXPECTED_RETAINED_FILES = {
    ATTEMPT_PATH: (
        2_624,
        "sha256:37af2f19ca2af192b0109e8e04120afbcdbd4366df99fe5e0698737916b3d280",
    ),
    REPORT_PATH: (
        3_087,
        "sha256:e6bd9cc484ffd09e2cf8a4382492b8afcd4f75a922796c8b266dedb7b56b262e",
    ),
}
DIAGNOSIS_MARKER = "QSDK_R10D_L1_RETAINED_STAGE_FREEZE_DIAGNOSIS_ZERO_WORLD "
PASS_MARKER = "QSDK_R10D_L1_SUCCESSOR_DESIGN_AUDIT_PASS "
ZERO_COUNTERS = (
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "native_readback_count",
    "solver_step_count",
)


class DesignFailure(RuntimeError):
    """Raised when a design or retained-evidence invariant fails."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise DesignFailure(code)


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def finite_json_tree(value: Any) -> bool:
    if value is None or isinstance(value, (str, bool)):
        return True
    if isinstance(value, int):
        return True
    if isinstance(value, float):
        return math.isfinite(value)
    if isinstance(value, list):
        return all(finite_json_tree(item) for item in value)
    if isinstance(value, dict):
        return all(
            isinstance(key, str) and finite_json_tree(item)
            for key, item in value.items()
        )
    return False


def read_json(path: Path, label: str) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"{label}_NOT_OBJECT")
    require(finite_json_tree(value), f"{label}_NONFINITE")
    return value


def git(arguments: Iterable[str]) -> str:
    result = subprocess.run(
        ("git", "-C", str(ROOT), *arguments),
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return result.stdout.strip()


def validate_repository() -> None:
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "WRONG_ROOT")
    require(
        git(("rev-parse", "--show-toplevel")).replace("\\", "/").lower()
        == str(EXPECTED_ROOT).replace("\\", "/").lower(),
        "GIT_ROOT",
    )
    require(git(("remote", "get-url", "origin")) == EXPECTED_REMOTE, "REMOTE")


def validate_file_identities() -> None:
    for path, (byte_length, digest, blob) in EXPECTED_FILES.items():
        relative = path.relative_to(ROOT).as_posix()
        require(path.is_file(), f"MISSING:{relative}")
        require(path.stat().st_size == byte_length, f"BYTE_LENGTH:{relative}")
        require(sha256_file(path) == digest, f"SHA256:{relative}")
        require(git(("rev-parse", f"HEAD:{relative}")) == blob, f"BLOB:{relative}")
    for path, (byte_length, digest) in EXPECTED_RETAINED_FILES.items():
        require(path.is_file(), f"RETAINED_MISSING:{path}")
        require(path.stat().st_size == byte_length, f"RETAINED_BYTES:{path}")
        require(sha256_file(path) == digest, f"RETAINED_SHA256:{path}")


def validate_predecessor() -> None:
    closure = read_json(PREDECESSOR_CLOSURE_PATH, "PREDECESSOR_CLOSURE")
    report = read_json(REPORT_PATH, "RETAINED_REPORT")
    attempt = read_json(ATTEMPT_PATH, "RETAINED_ATTEMPT")
    require(
        closure.get("status") == "closed_consumed_invalid_or_incomplete_no_valid_route"
        and closure.get("route_execution_valid") is False
        and closure.get("behavioral_conclusion_available") is False
        and closure.get("behavior_passed") is None
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("decision", {}).get("held_out_qualification_eligible") is False
        and closure.get("decision", {}).get("qsdk_r10_satisfied") is False
        and closure.get("sdk_status", {}).get("sdk1_completed_steps") == 13,
        "PREDECESSOR_CLOSURE",
    )
    require(
        report.get("status") == "invalid_or_incomplete"
        and report.get("world_attempt_count") == 1
        and report.get("world_build_count") is None
        and report.get("world_build_count_known") is False
        and report.get("confirmed_valid_world_build_count") == 0
        and report.get("behavioral_conclusion_available") is False
        and report.get("behavior_passed") is None
        and report.get("same_identity_rerun_permitted") is False,
        "RETAINED_REPORT",
    )
    require(
        attempt.get("schema_version") == "sporespore_qsdk_r10d_physical_attempt_v1"
        and attempt.get("campaign_seed") == 40001
        and attempt.get("arm_id") == "matched_no_impulse_control"
        and attempt.get("same_identity_rerun_permitted") is False,
        "RETAINED_ATTEMPT",
    )
    stdout = STDOUT_PATH.read_text(encoding="utf-8")
    require(
        stdout.count("QSDK_R10D_PHYSICAL_CELL ") == 1
        and '"failure_code":"QSDK_R10D_STAGE_FREEZE_INVALID"' in stdout
        and '"model_construction_count":0' in stdout
        and '"world_build_count":0' in stdout
        and '"solver_step_count":0' in stdout,
        "RETAINED_WORKER_REFUSAL",
    )


def parse_marker(stdout: str, marker: str) -> dict[str, Any]:
    lines = [line for line in stdout.splitlines() if line.startswith(marker)]
    require(len(lines) == 1, "DIAGNOSIS_MARKER_COUNT")
    value = json.loads(lines[0][len(marker) :])
    require(isinstance(value, dict), "DIAGNOSIS_RECEIPT_NOT_OBJECT")
    return value


def validate_diagnosis(receipt: dict[str, Any]) -> None:
    checks = receipt.get("checks")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10d_l1_retained_stage_freeze_diagnosis_v1"
        and receipt.get("gate_id") == "QSDK-R10D-L1"
        and receipt.get("ok") is True
        and receipt.get("failure_code") == ""
        and isinstance(checks, dict)
        and checks.get("worker_exact_stage_freeze") is True
        and checks.get("r05e_seed_array_direct_equality") is False
        and checks.get("r05e_seed_array_normalized_equality") is True
        and receipt.get("failed_checks") == ["r05e_seed_array_direct_equality"]
        and receipt.get("expected_predecessor_failure_checks")
        == ["r05e_seed_array_direct_equality"]
        and receipt.get("unexpected_failure_checks") == []
        and receipt.get("parsed_supported_seed_types") == ["float", "float", "float"]
        and receipt.get("parsed_supported_seed_values") == [40101.0, 40102.0, 40103.0]
        and receipt.get("normalized_supported_seed_values") == [40101, 40102, 40103]
        and receipt.get("normalization_control_count") == 10
        and receipt.get("normalization_controls_passed") is True
        and receipt.get("stage_raw_sha256") == EXPECTED_FILES[PREDECESSOR_STAGE_PATH][1]
        and receipt.get("attempt_raw_sha256")
        == EXPECTED_RETAINED_FILES[ATTEMPT_PATH][1]
        and all(receipt.get(name) == 0 for name in ZERO_COUNTERS)
        and receipt.get("scene_tree_insertion_count") == 0
        and receipt.get("physics_state_modified") is False
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False,
        "DIAGNOSIS_RECEIPT",
    )


def run_diagnosis() -> dict[str, Any]:
    require(GODOT.is_file(), "GODOT_MISSING")
    with tempfile.TemporaryDirectory(prefix="sporespore-r10d-l1-diagnosis-") as tmp:
        temporary_root = Path(tmp)
        environment = dict(os.environ)
        environment["GODOT_USER_HOME"] = str(temporary_root / "godot-user")
        result = subprocess.run(
            (
                str(GODOT),
                "--headless",
                "--path",
                str(ROOT),
                "--log-file",
                str(temporary_root / "godot.log"),
                "--script",
                "res://tests/test_sdk_qsdk_r10d_l1_retained_stage_freeze_diagnosis.gd",
            ),
            cwd=ROOT,
            env=environment,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=120,
        )
    require(result.returncode == 0, f"DIAGNOSIS_PROCESS:{result.stderr[-1000:]}")
    receipt = parse_marker(result.stdout, DIAGNOSIS_MARKER)
    validate_diagnosis(receipt)
    return receipt


def validate_design(design: dict[str, Any]) -> None:
    predecessor = design.get("consumed_predecessor", {})
    diagnosis = design.get("causal_diagnosis", {})
    repair = design.get("repair_contract", {})
    frozen = design.get("frozen_physical_question", {})
    identity = design.get("successor_identity", {})
    decision = design.get("decision", {})
    claims = design.get("claim_boundary", {})
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10d_l1_stage_freeze_numeric_normalization_successor_design_v1"
        and design.get("status") == "closed_selected_zero_world_successor_design"
        and design.get("gate_id") == "QSDK-R10D-L1"
        and design.get("parent_gate_id") == "QSDK-R10D"
        and design.get("repair_id") == "QSDK-R10D-L1",
        "DESIGN_HEADER",
    )
    expected_predecessor = {
        "physical_closure": {
            "path": "sdk/qsdk_r10d_development_route_ghost_physical_closure_v1.json",
            "byte_length": 7196,
            "raw_sha256": EXPECTED_FILES[PREDECESSOR_CLOSURE_PATH][1],
            "git_blob_oid": EXPECTED_FILES[PREDECESSOR_CLOSURE_PATH][2],
            "status": "closed_consumed_invalid_or_incomplete_no_valid_route",
            "route_execution_valid": False,
            "behavioral_conclusion_available": False,
            "physical_identity_consumed": True,
            "same_identity_rerun_permitted": False,
            "held_out_qualification_eligible": False,
        },
        "stage_freeze": {
            "path": "sdk/qsdk_r10d_development_route_ghost_zero_world_qualification_closure_v1.json",
            "byte_length": 25054,
            "raw_sha256": EXPECTED_FILES[PREDECESSOR_STAGE_PATH][1],
            "git_blob_oid": EXPECTED_FILES[PREDECESSOR_STAGE_PATH][2],
        },
        "execution_authority": {
            "path": "sdk/qsdk_r10d_development_route_ghost_execution_authority_v1.json",
            "byte_length": 2066,
            "raw_sha256": EXPECTED_FILES[PREDECESSOR_AUTHORITY_PATH][1],
            "git_blob_oid": EXPECTED_FILES[PREDECESSOR_AUTHORITY_PATH][2],
        },
        "retained_attempt": {
            "path": ATTEMPT_PATH.as_posix(),
            "byte_length": 2624,
            "raw_sha256": EXPECTED_RETAINED_FILES[ATTEMPT_PATH][1],
            "worker_failure_code": "QSDK_R10D_STAGE_FREEZE_INVALID",
            "worker_world_build_count": 0,
        },
        "retained_report": {
            "path": REPORT_PATH.as_posix(),
            "byte_length": 3087,
            "raw_sha256": EXPECTED_RETAINED_FILES[REPORT_PATH][1],
            "world_attempt_count": 1,
            "world_build_count": None,
            "world_build_count_known": False,
            "confirmed_valid_world_build_count": 0,
            "behavioral_conclusion_available": False,
        },
    }
    require(predecessor == expected_predecessor, "DESIGN_PREDECESSOR_BINDINGS")
    require(
        diagnosis.get("only_failed_predecessor_clause")
        == "r05e_supported_start_closure.supported_campaign_seeds direct array equality"
        and diagnosis.get("retained_json_seed_values") == [40101.0, 40102.0, 40103.0]
        and diagnosis.get("retained_json_seed_value_types")
        == ["float", "float", "float"]
        and diagnosis.get("frozen_in_memory_seed_values") == [40101, 40102, 40103]
        and diagnosis.get("direct_array_equality_result") is False
        and diagnosis.get("elementwise_exact_integer_normalization_result") is True
        and diagnosis.get("failure_happened_before_world_build") is True
        and diagnosis.get("locomotion_outcome_available") is False,
        "DESIGN_DIAGNOSIS",
    )
    require(
        repair.get("expected_values_in_order") == [40101, 40102, 40103]
        and repair.get("normalization_control_count") == 10
        and all(
            repair.get(name) is False
            for name in (
                "policy_logic_changed",
                "controller_changed",
                "morphology_changed",
                "material_changed",
                "physics_configuration_changed",
                "push_changed",
                "threshold_changed",
                "population_changed",
                "seed_changed",
                "outcome_derived_correction",
            )
        ),
        "DESIGN_REPAIR_BOUNDARY",
    )
    require(
        frozen.get("development_seed") == 40001
        and frozen.get("held_out_seeds") == [40101, 40102, 40103]
        and frozen.get("push_impulse_task_n_s") == [0.0, 0.0, 0.25]
        and frozen.get("push_marker_semantic_step") == 900
        and frozen.get("window_step_count") == 720
        and frozen.get("minimum_task_frame_forward_advance_m") == 0.02,
        "DESIGN_FROZEN_QUESTION",
    )
    require(
        identity.get("development_stage_freeze_path", "").endswith("_v2.json")
        and identity.get("development_execution_authority_path", "").endswith(
            "_v2.json"
        )
        and identity.get("development_physical_closure_path")
        == "sdk/qsdk_r10d_l1_development_route_ghost_physical_closure_v1.json"
        and identity.get("source_commit_must_change") is True
        and identity.get("same_predecessor_identity_rerun_permitted") is False
        and decision.get("selected_successor_id") == "QSDK-R10D-L1"
        and decision.get("new_physical_work_authorized_now") is False
        and decision.get("held_out_work_authorized_now") is False
        and decision.get("same_predecessor_identity_rerun_permitted") is False
        and design.get("sdk_status", {}).get("sdk1_completed_steps") == 13
        and claims.get("retained_failure_cause_claimed") is True
        and claims.get("representation_only_successor_selected") is True
        and claims.get("locomotion_behavior_claimed") is False
        and claims.get("bounded_upright_push_recovery_claimed") is False
        and claims.get("physical_acceptance_authority") is False
        and claims.get("release_authority") is False,
        "DESIGN_DECISION_AND_CLAIMS",
    )
    require(
        all(design.get("design_process", {}).get(name) == 0 for name in ZERO_COUNTERS)
        and design.get("design_process", {}).get("physics_state_modified") is False,
        "DESIGN_ZERO_WORLD",
    )


def mutation_controls(design: dict[str, Any], diagnosis: dict[str, Any]) -> int:
    mutations: list[tuple[dict[str, Any], tuple[str, ...], Any]] = [
        (design, ("repair_contract", "threshold_changed"), True),
        (design, ("repair_contract", "population_changed"), True),
        (design, ("repair_contract", "seed_changed"), True),
        (design, ("decision", "new_physical_work_authorized_now"), True),
        (design, ("decision", "same_predecessor_identity_rerun_permitted"), True),
        (design, ("claim_boundary", "locomotion_behavior_claimed"), True),
        (diagnosis, ("checks", "worker_exact_stage_freeze"), False),
        (diagnosis, ("checks", "r05e_seed_array_direct_equality"), True),
        (diagnosis, ("normalization_control_count",), 9),
        (diagnosis, ("world_build_count",), 1),
    ]
    rejected = 0
    for source, path, replacement in mutations:
        changed = copy.deepcopy(source)
        cursor: dict[str, Any] = changed
        for key in path[:-1]:
            cursor = cursor[key]
        cursor[path[-1]] = replacement
        require(changed != source, f"MUTATION_NOT_APPLIED:{'.'.join(path)}")
        try:
            if source is design:
                validate_design(changed)
            else:
                validate_diagnosis(changed)
        except DesignFailure:
            rejected += 1
    require(rejected == len(mutations), "MUTATION_ACCEPTED")
    return rejected


def audit() -> dict[str, Any]:
    validate_repository()
    require(DESIGN_PATH.stat().st_size == EXPECTED_DESIGN_BYTES, "DESIGN_BYTES")
    require(sha256_file(DESIGN_PATH) == EXPECTED_DESIGN_SHA256, "DESIGN_SHA256")
    design = read_json(DESIGN_PATH, "DESIGN")
    validate_file_identities()
    validate_predecessor()
    validate_design(design)
    diagnosis = run_diagnosis()
    mutation_count = mutation_controls(design, diagnosis)
    return {
        "schema_version": "sporespore_qsdk_r10d_l1_successor_design_audit_v1",
        "gate_id": "QSDK-R10D-L1",
        "ok": True,
        "failure_code": "",
        "selected_successor_id": "QSDK-R10D-L1",
        "design_byte_length": EXPECTED_DESIGN_BYTES,
        "design_raw_sha256": EXPECTED_DESIGN_SHA256,
        "predecessor_physical_identity_consumed": True,
        "predecessor_same_identity_rerun_permitted": False,
        "predecessor_worker_world_build_count": 0,
        "predecessor_report_world_build_count_known": False,
        "predecessor_behavioral_conclusion_available": False,
        "only_failed_predecessor_clause": (
            "r05e_supported_start_closure.supported_campaign_seeds direct array equality"
        ),
        "parsed_seed_numeric_type": "float",
        "exact_integer_normalization_passed": True,
        "normalization_control_count": diagnosis["normalization_control_count"],
        "design_and_diagnosis_mutation_control_count": mutation_count,
        "policy_logic_changed": False,
        "controller_changed": False,
        "morphology_changed": False,
        "physics_configuration_changed": False,
        "push_changed": False,
        "threshold_changed": False,
        "population_changed": False,
        "seed_changed": False,
        "outcome_derived_correction": False,
        "new_physical_work_authorized": False,
        "held_out_work_authorized": False,
        "sdk1_completed_steps": 13,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    try:
        receipt = audit()
        print(PASS_MARKER + json.dumps(receipt, separators=(",", ":"), sort_keys=True))
        return 0
    except (
        DesignFailure,
        KeyError,
        OSError,
        TypeError,
        UnicodeError,
        ValueError,
        json.JSONDecodeError,
        subprocess.SubprocessError,
    ) as exc:
        print(f"QSDK_R10D_L1_SUCCESSOR_DESIGN_AUDIT_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
