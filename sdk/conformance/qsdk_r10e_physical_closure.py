#!/usr/bin/env python3
"""Audit and close one consumed QSDK-R10E physical campaign report."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Iterable, Mapping


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_EVIDENCE_ROOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
).resolve()
REPORT_SCHEMA = "sporespore_qsdk_r10e_physical_campaign_report_v2"
CLOSURE_SCHEMA = "sporespore_qsdk_r10e_physical_closure_v2"
CAMPAIGN_START_SCHEMA = "sporespore_qsdk_r10e_physical_campaign_start_v2"
PHYSICAL_ATTEMPT_SCHEMA = "sporespore_qsdk_r10e_physical_attempt_v1"
PHYSICAL_CELL_SCHEMA = "sporespore_qsdk_r10e_physical_cell_v1"
PAIR_EVALUATION_SCHEMA = "sporespore_qsdk_r10e_pair_evaluation_v1"
WORKER_FAILURE_SCHEMA = "sporespore_qsdk_r10e_worker_failure_v1"
RUNTIME_IDENTITY_SCHEMA = "sporespore_qsdk_r10e_runtime_identity_v1"
QUALIFICATION_COMPLETION_SCHEMA = (
    "sporespore_qsdk_r10e_zero_world_qualification_completion_v2"
)
STAGE_FREEZE_SCHEMA = "sporespore_qsdk_r10e_stage_freeze_v3"
EXECUTION_AUTHORITY_SCHEMA = "sporespore_qsdk_r10e_execution_authority_v3"
LOCOMOTION_LOCK_SCHEMA = "sporespore_locomotion_operation_lock_receipt_v1"
LOCOMOTION_MUTEX_NAME = "Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"
CELL_MARKER = "QSDK_R10E_PHYSICAL_CELL "
PAIR_MARKER = "QSDK_R10E_PAIR_EVALUATION_ZERO_WORLD "
BASELINE_ARM_ID = "matched_no_impulse_control"
PUSH_ARM_ID = "lateral_upright_impulse"
AUDIT_MARKER = "QSDK_R10E_PHYSICAL_REPORT_AUDIT_PASS "
SELF_TEST_MARKER = "QSDK_R10E_PHYSICAL_CLOSURE_SELF_TEST_PASS "
COMPILED_MARKER = "QSDK_R10E_PHYSICAL_CLOSURE_COMPILED "
EXPECTED_DESIGN_SHA256 = (
    "sha256:791dbf01b8720ca0851b5ec4f722ff421baeb9ca277399974db6338aec03e81a"
)
EXPECTED_R10D_DEVELOPMENT_SHA256 = (
    "sha256:dbbdeb257a260a64c730459880d8d4d66682ec94b65ec8f3beaeb4c38a3cdcc9"
)
EXPECTED_R10D_HELD_OUT_SHA256 = (
    "sha256:4a96145b54161a166e735bfd884e497772774d0f9e1e11ae8db6b8fa557c4ed2"
)
EXPECTED_R05E_SHA256 = (
    "sha256:dac4ac8790cd74d89da0286c36aaf541fbfe7011d2bea66077b941363d47b33e"
)
EXPECTED_SUPERVISOR_REFUSAL_SHA256 = (
    "sha256:831c1c8bdc3720be7e1c9abe584cea098856982b4795f23f00c029f18b3b7fc0"
)
EXPECTED_L2_HELD_OUT_FAILURE_SHA256 = (
    "sha256:29942c4f666d3cc7d88388945bb450d6d64f01a6757f72f7a38e149b5d351211"
)
EXPECTED_GENERATOR_RECEIPT_SHA256 = (
    "sha256:4aef2888d84b80bf7c0ccba1c6dd1854567ca28d6536a2e2335d49ba1b2247a2"
)
EXPECTED_R05E_GENERATOR_RECEIPT_SHA256 = (
    "sha256:11c04da70cf613bc5b40a38568de3e45e3658a3f1cf46bfa35cac23ab2713686"
)
EXPECTED_R05E_PROPORTION_SPEC_SHA256 = (
    "sha256:491074191576f8f784e9cb305321c6fee32e46cf83692c796b6ed3d5467660cd"
)
EXPECTED_SELECTED_POLICY_DIGEST = (
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
)
EXPECTED_FIXTURE_SPEC_SHA256 = (
    "sha256:805dc1d69617414a81cdad74f5cf7c6eaf44f0765a3d53c19f8af3f8324f569d"
)
EXPECTED_CONTROLLER_PROFILE_SHA256 = (
    "sha256:e02fa9c7599cffe8b331f7d8c10b6cc4dbffe7408e319169c09cbcb7d9b3890e"
)
EXPECTED_MATERIAL_PROFILE_SHA256 = (
    "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
)
EXPECTED_ADAPTER_CAPABILITY_SHA256 = (
    "sha256:b9f59849bb6b22c8837f9c2784345899b95a14b1aa058df53df480da9f7a4a68"
)
MINIMUM_NATIVE_EFFECT_M_S = 1.0e-4

# Installed with the final recursive dependency closure.
EXPECTED_SOURCE_COUNT = 91
EXPECTED_SOURCE_PATH_SHA256 = (
    "sha256:348c65a448016b769cc13f3c23336a295a03990ef39e40a8418650a2d9667f67"
)

ROLE_SPECS: dict[str, dict[str, Any]] = {
    "development_route_ghost": {
        "repair_id": "QSDK-R10E-L2",
        "report_schema": "sporespore_qsdk_r10e_physical_campaign_report_v1",
        "closure_schema": "sporespore_qsdk_r10e_physical_closure_v1",
        "campaign_start_schema": "sporespore_qsdk_r10e_physical_campaign_start_v1",
        "qualification_completion_schema": (
            "sporespore_qsdk_r10e_zero_world_qualification_completion_v1"
        ),
        "stage_schema": "sporespore_qsdk_r10e_stage_freeze_v2",
        "authority_schema": "sporespore_qsdk_r10e_execution_authority_v2",
        "campaign_id": "QSDK-R10E-OBSERVER-MINIMIZED-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST",
        "question_class": "development",
        "seeds": [40002],
        "ordered_cell_ids": ["baseline_s40002", "push_s40002"],
        "output_slug": "development-route-ghost",
        "stage_path": (
            "sdk/qsdk_r10e_development_route_ghost_"
            "zero_world_qualification_closure_v2.json"
        ),
        "authority_path": (
            "sdk/qsdk_r10e_development_route_ghost_execution_authority_v2.json"
        ),
        "closure_path": "sdk/qsdk_r10e_development_route_ghost_physical_closure_v2.json",
    },
    "held_out_finite_decision": {
        "repair_id": "QSDK-R10E-L3",
        "report_schema": REPORT_SCHEMA,
        "closure_schema": CLOSURE_SCHEMA,
        "campaign_start_schema": CAMPAIGN_START_SCHEMA,
        "qualification_completion_schema": QUALIFICATION_COMPLETION_SCHEMA,
        "stage_schema": STAGE_FREEZE_SCHEMA,
        "authority_schema": EXECUTION_AUTHORITY_SCHEMA,
        "campaign_id": "QSDK-R10E-OBSERVER-MINIMIZED-UPRIGHT-PUSH-RECOVERY-VALIDATION",
        "question_class": "finite decision",
        "seeds": [40101, 40102, 40103],
        "ordered_cell_ids": [
            "baseline_s40101",
            "push_s40101",
            "baseline_s40102",
            "push_s40102",
            "baseline_s40103",
            "push_s40103",
        ],
        "output_slug": "held-out-finite-decision",
        "stage_path": (
            "sdk/qsdk_r10e_held_out_finite_decision_"
            "zero_world_qualification_closure_v3.json"
        ),
        "authority_path": (
            "sdk/qsdk_r10e_held_out_finite_decision_execution_authority_v3.json"
        ),
        "closure_path": "sdk/qsdk_r10e_held_out_finite_decision_physical_closure_v3.json",
    },
}


class ClosureFailure(RuntimeError):
    """The retained physical report cannot support an immutable closure."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureFailure(code)


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def is_sha256(value: Any) -> bool:
    return (
        isinstance(value, str)
        and re.fullmatch(r"sha256:[0-9a-f]{64}", value) is not None
    )


def is_commit(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def is_finite_number(value: Any) -> bool:
    return type(value) in (int, float) and math.isfinite(float(value))


def read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ClosureFailure(f"{label}_UNREADABLE:{exc}") from exc
    require(isinstance(value, dict), f"{label}_NOT_OBJECT")
    return value


def read_json_bytes(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ClosureFailure(f"{label}_UNREADABLE:{exc}") from exc
    require(isinstance(value, dict), f"{label}_NOT_OBJECT")
    return value


def git_bytes(arguments: Iterable[str], label: str) -> bytes:
    try:
        result = subprocess.run(
            ("git", *arguments),
            cwd=ROOT,
            check=False,
            capture_output=True,
            timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ClosureFailure(f"{label}_PROCESS:{exc}") from exc
    require(result.returncode == 0, f"{label}_PROCESS_EXIT:{result.returncode}")
    return result.stdout


def git_text(arguments: Iterable[str], label: str) -> str:
    raw = git_bytes(arguments, label)
    try:
        return raw.decode("utf-8").strip()
    except UnicodeError as exc:
        raise ClosureFailure(f"{label}_OUTPUT_ENCODING:{exc}") from exc


def git_changed_paths(commit: str, label: str) -> list[str]:
    value = git_text(
        (
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "--no-renames",
            "-r",
            commit,
        ),
        label,
    )
    return value.splitlines() if value else []


def validate_committed_file_binding(
    binding: Any,
    relative_path: str,
    commit: str,
    expected_sha256: str | None,
    label: str,
) -> None:
    require(isinstance(binding, dict), f"{label}_NOT_OBJECT")
    raw = git_bytes(("show", f"{commit}:{relative_path}"), f"{label}_BLOB")
    blob_oid = git_text(("rev-parse", f"{commit}:{relative_path}"), f"{label}_BLOB_OID")
    digest = sha256_bytes(raw)
    require(
        binding.get("path") == relative_path
        and type(binding.get("byte_length")) is int
        and binding.get("byte_length") == len(raw)
        and binding.get("raw_sha256") == digest
        and binding.get("git_blob_oid") == blob_oid
        and (expected_sha256 is None or digest == expected_sha256),
        f"{label}_FIELDS",
    )


def finite_json_tree(value: Any) -> bool:
    if value is None or isinstance(value, (bool, str, int)):
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


def ledger_scope(question_class: str, authority_mode: str) -> dict[str, str]:
    return {
        "subsystem": "recovery",
        "engine_scope": "godot_jolt",
        "authority_mode": authority_mode,
        "question_class": question_class,
    }


def role_spec(role: str) -> dict[str, Any]:
    require(role in ROLE_SPECS, "REPORT_CAMPAIGN_ROLE")
    return ROLE_SPECS[role]


def l2_failure_sha_link_exact(
    value: Mapping[str, Any], spec: Mapping[str, Any]
) -> bool:
    if spec["repair_id"] == "QSDK-R10E-L2":
        return "l2_held_out_failure_closure_sha256" not in value
    return (
        value.get("l2_held_out_failure_closure_sha256")
        == EXPECTED_L2_HELD_OUT_FAILURE_SHA256
    )


def _safe_relative(root: Path, relative: Any, label: str) -> Path:
    require(
        isinstance(relative, str) and relative and "\\" not in relative, f"{label}_PATH"
    )
    candidate = (root / relative).resolve()
    try:
        candidate.relative_to(root.resolve())
    except ValueError as exc:
        raise ClosureFailure(f"{label}_ESCAPES_OUTPUT_ROOT") from exc
    return candidate


def validate_file_binding(output_root: Path, binding: Any, label: str) -> Path:
    require(isinstance(binding, dict), f"{label}_NOT_OBJECT")
    path = _safe_relative(output_root, binding.get("path"), label)
    require(path.is_file(), f"{label}_MISSING")
    require(path.stat().st_size == binding.get("byte_length"), f"{label}_BYTE_LENGTH")
    require(sha256_file(path) == binding.get("raw_sha256"), f"{label}_SHA256")
    return path


def validate_marker_link(
    stdout_path: Path,
    marker: str,
    receipt: Mapping[str, Any],
    label: str,
) -> None:
    try:
        stdout = stdout_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise ClosureFailure(f"{label}_STDOUT_UNREADABLE:{exc}") from exc
    matches = [
        line[len(marker) :] for line in stdout.splitlines() if line.startswith(marker)
    ]
    require(len(matches) == 1, f"{label}_STDOUT_MARKER_COUNT")
    try:
        parsed = json.loads(matches[0])
    except json.JSONDecodeError as exc:
        raise ClosureFailure(f"{label}_STDOUT_MARKER_JSON:{exc}") from exc
    require(parsed == receipt, f"{label}_STDOUT_RECEIPT_DIVERGENCE")


def expected_pair_ids(spec: Mapping[str, Any]) -> list[str]:
    return [f"pair_s{seed}" for seed in spec["seeds"]]


def expected_cell_identity(cell_id: str) -> tuple[str, int]:
    match = re.fullmatch(r"(baseline|push)_s([0-9]+)", cell_id)
    require(match is not None, f"CELL_ID_FORMAT:{cell_id}")
    arm_id = BASELINE_ARM_ID if match.group(1) == "baseline" else PUSH_ARM_ID
    return arm_id, int(match.group(2))


def validate_operation_lock(value: Any, role: str) -> None:
    expected_role = (
        "physical_development" if role == "development_route_ghost" else "physical"
    )
    require(isinstance(value, dict), "OPERATION_LOCK_NOT_OBJECT")
    require(
        value.get("schema_version") == LOCOMOTION_LOCK_SCHEMA
        and value.get("acquired") is True
        and value.get("role") == expected_role
        and value.get("mutex_name") == LOCOMOTION_MUTEX_NAME
        and type(value.get("created_new")) is bool
        and value.get("abandoned_owner_recovered") is False
        and type(value.get("owner_process_id")) is int
        and value.get("owner_process_id") > 0
        and type(value.get("owner_session_id")) is int
        and isinstance(value.get("acquired_utc"), str)
        and bool(value.get("acquired_utc"))
        and value.get("test_only") is False
        and value.get("physical_acceptance_authority") is False,
        "OPERATION_LOCK_FIELDS",
    )


def _exact_int(value: Any, label: str) -> int:
    require(type(value) is int, label)
    return value


def _cell_projection_from_receipt(receipt: Mapping[str, Any]) -> dict[str, Any]:
    evaluation_value = receipt.get("evaluation")
    evaluation = evaluation_value if isinstance(evaluation_value, dict) else None
    observer_value = evaluation.get("observer_instrumentation") if evaluation else None
    observer = observer_value if isinstance(observer_value, dict) else None
    observer_receipt_value = observer.get("receipt") if observer else None
    observer_receipt = (
        observer_receipt_value if isinstance(observer_receipt_value, dict) else None
    )
    runtime_value = receipt.get("runtime_summary_projection")
    runtime = runtime_value if isinstance(runtime_value, dict) else None
    return {
        "worker_ok": bool(receipt.get("ok", False)),
        "failure_code": str(receipt.get("failure_code", "")),
        "world_build_count_known": "world_build_count" in receipt,
        "world_build_count": (
            _exact_int(receipt["world_build_count"], "CELL_RECEIPT_WORLD_BUILD_TYPE")
            if "world_build_count" in receipt
            else 0
        ),
        "external_push_application_count": (
            _exact_int(
                runtime["external_push_application_count"],
                "CELL_RECEIPT_PUSH_COUNT_TYPE",
            )
            if runtime is not None and "external_push_application_count" in runtime
            else None
        ),
        "evaluation": {
            "ok": bool(evaluation.get("ok", False)) if evaluation else False,
            "failure_code": (
                str(evaluation.get("failure_code", "")) if evaluation else ""
            ),
            "outcome_complete": (
                bool(evaluation.get("outcome_complete", False)) if evaluation else False
            ),
            "evidence_valid": (
                bool(evaluation.get("evidence_valid", False)) if evaluation else False
            ),
            "behavior_passed": (
                bool(evaluation["behavior_passed"])
                if evaluation is not None and "behavior_passed" in evaluation
                else None
            ),
        },
        "observer_instrumentation": {
            "valid": bool(observer.get("ok", False)) if observer else False,
            "live_prohibited_operation_count": (
                int(observer["live_prohibited_operation_count"])
                if observer is not None
                and "live_prohibited_operation_count" in observer
                else -1
            ),
            "post_solver_materialized_row_count_matches_trace_row_count": (
                bool(
                    observer_receipt.get(
                        "post_solver_materialized_row_count_matches_trace_row_count",
                        False,
                    )
                )
                if observer_receipt
                else False
            ),
            "post_solver_projection_receipt_count_matches_trace_row_count": (
                bool(
                    observer_receipt.get(
                        "post_solver_projection_receipt_count_matches_trace_row_count",
                        False,
                    )
                )
                if observer_receipt
                else False
            ),
        },
    }


def _pair_projection_from_receipt(receipt: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "ok": bool(receipt.get("ok", False)),
        "failure_code": str(receipt.get("failure_code", "")),
        "outcome_complete": bool(receipt.get("outcome_complete", False)),
        "evidence_valid": bool(receipt.get("evidence_valid", False)),
        "behavior_passed": (
            bool(receipt["behavior_passed"]) if "behavior_passed" in receipt else None
        ),
        "native_effect_confirmed": bool(receipt.get("native_effect_confirmed", False)),
    }


def validate_campaign_start(
    output_root: Path,
    report: Mapping[str, Any],
    spec: Mapping[str, Any],
) -> None:
    path = validate_file_binding(
        output_root, report.get("campaign_start_binding"), "CAMPAIGN_START"
    )
    start = read_json(path, "CAMPAIGN_START")
    require(finite_json_tree(start), "CAMPAIGN_START_NONFINITE")
    require(
        start.get("schema_version") == spec["campaign_start_schema"]
        and start.get("gate_id") == "QSDK-R10E"
        and start.get("repair_id") == spec["repair_id"]
        and start.get("campaign_id") == spec["campaign_id"]
        and start.get("campaign_role") == report.get("campaign_role")
        and start.get("question_class") == spec["question_class"]
        and start.get("ledger_scope")
        == ledger_scope(str(spec["question_class"]), "physical_campaign_start")
        and start.get("source_commit") == report["source"]["source_commit"]
        and start.get("authorization_commit")
        == report["source"]["authorization_commit"]
        and start.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and l2_failure_sha_link_exact(start, spec)
        and start.get("ordered_cell_ids") == spec["ordered_cell_ids"]
        and start.get("maximum_world_count") == len(spec["ordered_cell_ids"])
        and start.get("maximum_campaign_attempt_count") == 1
        and start.get("physical_identity_consumed_on_directory_creation") is True
        and start.get("same_identity_rerun_permitted") is False
        and start.get("operation_lock") == report.get("operation_lock")
        and isinstance(start.get("started_utc"), str)
        and bool(start.get("started_utc"))
        and start.get("physical_acceptance_authority") is False
        and start.get("release_authority") is False,
        "CAMPAIGN_START_FIELDS",
    )


def validate_runtime_identity(
    report: Mapping[str, Any],
    runtime_binding: Mapping[str, Any],
    spec: Mapping[str, Any],
) -> None:
    source_commit = str(report["source"]["source_commit"])
    expected_path = (
        EXPECTED_EVIDENCE_ROOT
        / (
            f"qsdk-r10e-{spec['output_slug']}-zero-world-qualification-"
            f"{source_commit[:12]}"
        )
        / "runtime_identity.json"
    ).resolve()
    path = Path(str(runtime_binding.get("runtime_identity_path", ""))).resolve()
    require(
        path == expected_path
        and path.is_file()
        and path.stat().st_size == runtime_binding.get("runtime_identity_byte_length")
        and sha256_file(path) == runtime_binding.get("runtime_identity_sha256"),
        "REPORT_RUNTIME_FILE_BINDING",
    )
    runtime = read_json(path, "RUNTIME_IDENTITY")
    require(finite_json_tree(runtime), "RUNTIME_IDENTITY_NONFINITE")
    for label in (
        "godot_console",
        "python",
        "powershell",
        "git",
        "cargo",
        "gdformat",
        "gdlint",
    ):
        identity = runtime.get(label)
        require(
            isinstance(identity, dict)
            and isinstance(identity.get("path"), str)
            and bool(identity.get("path"))
            and type(identity.get("byte_length")) is int
            and identity.get("byte_length") > 0
            and is_sha256(identity.get("raw_sha256"))
            and isinstance(identity.get("version"), str)
            and bool(identity.get("version")),
            f"REPORT_RUNTIME_TOOL_IDENTITY:{label}",
        )
    adapter = runtime.get("active_adapter")
    require(
        runtime.get("schema_version") == RUNTIME_IDENTITY_SCHEMA
        and runtime.get("gate_id") == "QSDK-R10E"
        and runtime.get("source_commit") == source_commit
        and runtime.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and runtime.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256
        and runtime.get("runtime_identity_complete") is True
        and runtime["python"].get("version") == runtime.get("python_version")
        and runtime["powershell"].get("version") == runtime.get("powershell_version")
        and isinstance(adapter, dict)
        and adapter.get("path") == "sdk/target/debug/sporespore_godot_adapter.dll"
        and type(adapter.get("byte_length")) is int
        and adapter.get("byte_length") > 0
        and is_sha256(adapter.get("raw_sha256"))
        and adapter.get("raw_sha256")
        == runtime_binding.get("active_adapter_raw_sha256")
        and runtime.get("active_adapter_raw_sha256")
        == runtime_binding.get("active_adapter_raw_sha256"),
        "REPORT_RUNTIME_FILE_FIELDS",
    )


def validate_committed_authority_chain(
    report: Mapping[str, Any],
    runtime_binding: Mapping[str, Any],
    spec: Mapping[str, Any],
) -> None:
    source = report["source"]
    report_authority = report["authority"]
    source_commit = str(source["source_commit"])
    stage_commit = str(source["authorization_parent_commit"])
    authorization_commit = str(source["authorization_commit"])
    stage_relative = str(spec["stage_path"])
    authority_relative = str(spec["authority_path"])

    require(
        source.get("qualification_parent_commit") == source_commit
        and git_text(("rev-parse", f"{stage_commit}^"), "STAGE_PARENT") == source_commit
        and git_text(("rev-parse", f"{authorization_commit}^"), "AUTHORIZATION_PARENT")
        == stage_commit,
        "COMMITTED_AUTHORITY_PARENT_CHAIN",
    )
    require(
        git_changed_paths(stage_commit, "STAGE_CHANGED_PATHS") == [stage_relative]
        and git_changed_paths(authorization_commit, "AUTHORITY_CHANGED_PATHS")
        == [authority_relative],
        "COMMITTED_AUTHORITY_ORDINAL_PATHS",
    )
    combined_paths = git_text(
        (
            "diff",
            "--name-only",
            "--no-renames",
            f"{source_commit}..{authorization_commit}",
        ),
        "COMBINED_AUTHORITY_PATHS",
    ).splitlines()
    require(
        sorted(combined_paths) == sorted((stage_relative, authority_relative))
        and len(combined_paths) == 2,
        "COMMITTED_AUTHORITY_COMBINED_PATHS",
    )

    stage_raw = git_bytes(("show", f"{stage_commit}:{stage_relative}"), "STAGE_BLOB")
    carried_stage_raw = git_bytes(
        ("show", f"{authorization_commit}:{stage_relative}"),
        "AUTHORITY_CARRIED_STAGE_BLOB",
    )
    authority_raw = git_bytes(
        ("show", f"{authorization_commit}:{authority_relative}"), "AUTHORITY_BLOB"
    )
    require(
        stage_raw == carried_stage_raw
        and sha256_bytes(stage_raw) == report_authority["stage_freeze_sha256"]
        and sha256_bytes(authority_raw)
        == report_authority["execution_authority_sha256"],
        "COMMITTED_AUTHORITY_BLOB_BINDING",
    )
    stage = read_json_bytes(stage_raw, "STAGE_FREEZE")
    authority = read_json_bytes(authority_raw, "EXECUTION_AUTHORITY")
    require(
        finite_json_tree(stage) and finite_json_tree(authority),
        "COMMITTED_AUTHORITY_NONFINITE",
    )
    question_class = str(spec["question_class"])
    expected_output_root = Path(str(report["output_root"])).resolve()
    require(
        stage.get("schema_version") == spec["stage_schema"]
        and stage.get("status") == "closed_passing_official_zero_world_qualification"
        and stage.get("gate_id") == "QSDK-R10E"
        and stage.get("repair_id") == spec["repair_id"]
        and stage.get("campaign_id") == spec["campaign_id"]
        and stage.get("campaign_role") == report.get("campaign_role")
        and stage.get("question_class") == question_class
        and stage.get("ledger_scope")
        == ledger_scope(question_class, "official_zero_world_qualification")
        and stage.get("source_commit") == source_commit
        and stage.get("qualification_parent_commit") == source_commit
        and stage.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and stage.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256
        and stage.get("r10e_design_sha256") == EXPECTED_DESIGN_SHA256
        and stage.get("r10d_development_closure_sha256")
        == EXPECTED_R10D_DEVELOPMENT_SHA256
        and stage.get("r10d_held_out_closure_sha256") == EXPECTED_R10D_HELD_OUT_SHA256
        and stage.get("r05e_physical_closure_sha256") == EXPECTED_R05E_SHA256
        and stage.get("ordered_cell_ids") == spec["ordered_cell_ids"]
        and stage.get("maximum_world_count") == len(spec["ordered_cell_ids"])
        and stage.get("maximum_campaign_attempt_count") == 1
        and stage.get("official_zero_world_qualification_passed") is True
        and stage.get("physical_execution_authorized_by_freeze") is False
        and stage.get("physical_acceptance_authority") is False
        and stage.get("release_authority") is False,
        "COMMITTED_STAGE_FREEZE_FIELDS",
    )
    for binding, relative_path, expected_digest, label in (
        (
            stage.get("r10e_successor_design"),
            "sdk/qsdk_r10e_observer_minimized_upright_push_recovery_successor_design_v1.json",
            EXPECTED_DESIGN_SHA256,
            "COMMITTED_R10E_DESIGN",
        ),
        (
            stage.get("consumed_r10d_development_closure"),
            "sdk/qsdk_r10d_l1_development_route_ghost_physical_closure_v1.json",
            EXPECTED_R10D_DEVELOPMENT_SHA256,
            "COMMITTED_R10D_DEVELOPMENT",
        ),
        (
            stage.get("consumed_r10d_held_out_closure"),
            "sdk/qsdk_r10d_l1_held_out_finite_decision_physical_closure_v1.json",
            EXPECTED_R10D_HELD_OUT_SHA256,
            "COMMITTED_R10D_HELD_OUT",
        ),
        (
            stage.get("r05e_generator_225_support"),
            "sdk/qsdk_r05e_exact_finite_morphology_physical_closure_v1.json",
            EXPECTED_R05E_SHA256,
            "COMMITTED_R05E_SUPPORT",
        ),
        (
            stage.get("superseded_physical_supervisor_refusal"),
            "sdk/qsdk_r10e_development_route_ghost_physical_supervisor_refusal_v1.json",
            EXPECTED_SUPERVISOR_REFUSAL_SHA256,
            "COMMITTED_R10E_SUPERVISOR_REFUSAL",
        ),
    ):
        validate_committed_file_binding(
            binding,
            relative_path,
            source_commit,
            expected_digest,
            label,
        )
    supervisor_refusal = stage.get("superseded_physical_supervisor_refusal")
    require(
        isinstance(supervisor_refusal, dict)
        and supervisor_refusal.get("status")
        == "closed_infrastructure_invalid_pre_physics_output_identity_unconsumed"
        and supervisor_refusal.get("repair_id") == "QSDK-R10E-L2"
        and supervisor_refusal.get("physical_attempt_identity_consumed") is False
        and supervisor_refusal.get("world_attempt_count") == 0
        and supervisor_refusal.get("world_build_count") == 0
        and supervisor_refusal.get("solver_step_count") == 0,
        "COMMITTED_R10E_SUPERVISOR_REFUSAL_BOUNDARY",
    )
    l2_failure = stage.get("consumed_l2_held_out_failure_closure")
    if spec["repair_id"] == "QSDK-R10E-L3":
        validate_committed_file_binding(
            l2_failure,
            "sdk/qsdk_r10e_l2_held_out_finite_decision_physical_failure_closure_v1.json",
            source_commit,
            EXPECTED_L2_HELD_OUT_FAILURE_SHA256,
            "COMMITTED_R10E_L2_HELD_OUT_FAILURE",
        )
        require(
            isinstance(l2_failure, dict)
            and l2_failure.get("status")
            == "closed_consumed_invalid_or_incomplete_no_finite_decision"
            and l2_failure.get("repair_id") == "QSDK-R10E-L2"
            and l2_failure.get("physical_identity_consumed") is True
            and l2_failure.get("same_identity_rerun_permitted") is False
            and l2_failure.get("behavioral_conclusion_available") is False
            and l2_failure.get("successor_repair_id") == "QSDK-R10E-L3",
            "COMMITTED_R10E_L2_HELD_OUT_FAILURE_BOUNDARY",
        )
    else:
        require(l2_failure is None, "COMMITTED_STAGE_UNEXPECTED_L2_FAILURE_SUCCESSOR")
    prerequisite = stage.get("prerequisite_development_route_ghost")
    if report.get("campaign_role") == "development_route_ghost":
        require(prerequisite is None, "COMMITTED_STAGE_UNEXPECTED_PREREQUISITE")
    else:
        development_closure_relative = (
            "sdk/qsdk_r10e_development_route_ghost_physical_closure_v2.json"
        )
        require(
            isinstance(prerequisite, dict)
            and prerequisite.get("route_execution_valid") is True
            and prerequisite.get("physical_identity_consumed") is True
            and prerequisite.get("same_identity_rerun_permitted") is False
            and is_sha256(prerequisite.get("physical_closure_sha256")),
            "COMMITTED_STAGE_DEVELOPMENT_PREREQUISITE",
        )
        validate_committed_file_binding(
            prerequisite,
            development_closure_relative,
            source_commit,
            str(prerequisite["physical_closure_sha256"]),
            "COMMITTED_R10E_DEVELOPMENT_PREREQUISITE",
        )

    require(
        authority.get("schema_version") == spec["authority_schema"]
        and authority.get("status") == "authorized_single_use_unconsumed"
        and authority.get("gate_id") == "QSDK-R10E"
        and authority.get("repair_id") == spec["repair_id"]
        and authority.get("campaign_id") == spec["campaign_id"]
        and authority.get("campaign_role") == report.get("campaign_role")
        and authority.get("question_class") == question_class
        and authority.get("ledger_scope")
        == ledger_scope(question_class, "single_use_physical_execution_authority")
        and authority.get("authorization_commit_derived_from_current_head") is True
        and authority.get("authorization_parent_commit") == stage_commit
        and authority.get("qualification_parent_commit") == source_commit
        and authority.get("source_commit") == source_commit
        and authority.get("qualification_closure_path") == stage_relative
        and authority.get("stage_freeze_sha256")
        == report_authority["stage_freeze_sha256"]
        and authority.get("r10e_design_sha256") == EXPECTED_DESIGN_SHA256
        and authority.get("r10d_development_closure_sha256")
        == EXPECTED_R10D_DEVELOPMENT_SHA256
        and authority.get("r10d_held_out_closure_sha256")
        == EXPECTED_R10D_HELD_OUT_SHA256
        and authority.get("r05e_physical_closure_sha256") == EXPECTED_R05E_SHA256
        and authority.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and l2_failure_sha_link_exact(authority, spec)
        and authority.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and authority.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256
        and authority.get("ordered_cell_ids") == spec["ordered_cell_ids"]
        and authority.get("maximum_world_count") == len(spec["ordered_cell_ids"])
        and authority.get("maximum_campaign_attempt_count") == 1
        and Path(str(authority.get("output_root", ""))).resolve()
        == expected_output_root
        and authority.get("zero_world_qualification_passed") is True
        and authority.get("physical_execution_authorized") is True
        and authority.get("physical_identity_consumed") is False
        and authority.get("same_identity_rerun_permitted") is False
        and authority.get("physical_acceptance_authority") is False
        and authority.get("release_authority") is False,
        "COMMITTED_EXECUTION_AUTHORITY_FIELDS",
    )

    expected_qualification_root = (
        EXPECTED_EVIDENCE_ROOT
        / (
            f"qsdk-r10e-{spec['output_slug']}-zero-world-qualification-"
            f"{source_commit[:12]}"
        )
    ).resolve()
    expected_completion_path = (
        expected_qualification_root / "qualification_completion.json"
    ).resolve()
    completion_binding = stage.get("qualification_completion")
    require(
        isinstance(completion_binding, dict),
        "COMMITTED_STAGE_QUALIFICATION_BINDING_NOT_OBJECT",
    )
    completion_path = Path(str(completion_binding.get("path", ""))).resolve()
    require(
        completion_path == expected_completion_path
        and not completion_path.is_symlink()
        and completion_path.is_file()
        and type(completion_binding.get("byte_length")) is int
        and completion_binding.get("byte_length") > 0
        and completion_path.stat().st_size == completion_binding.get("byte_length")
        and sha256_file(completion_path) == completion_binding.get("raw_sha256"),
        "COMMITTED_STAGE_QUALIFICATION_BINDING",
    )
    completion = read_json(completion_path, "QUALIFICATION_COMPLETION")
    require(finite_json_tree(completion), "QUALIFICATION_COMPLETION_NONFINITE")
    completion_runtime = completion.get("runtime_identity")
    require(
        completion.get("schema_version") == spec["qualification_completion_schema"]
        and completion.get("status")
        == "closed_passing_official_zero_world_qualification"
        and completion.get("gate_id") == "QSDK-R10E"
        and completion.get("repair_id") == spec["repair_id"]
        and completion.get("campaign_id") == spec["campaign_id"]
        and completion.get("campaign_role") == report.get("campaign_role")
        and completion.get("question_class") == question_class
        and completion.get("ledger_scope")
        == ledger_scope(question_class, "official_zero_world_qualification")
        and completion.get("source_commit") == source_commit
        and completion.get("source_tree")
        == git_text(("rev-parse", f"{source_commit}^{{tree}}"), "SOURCE_TREE")
        and Path(str(completion.get("qualification_root", ""))).resolve()
        == expected_qualification_root
        and completion.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and completion.get("qualified_source_path_sha256")
        == EXPECTED_SOURCE_PATH_SHA256
        and completion.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and l2_failure_sha_link_exact(completion, spec)
        and completion.get("official_zero_world_qualification_passed") is True
        and completion.get("source_unchanged_during_qualification") is True
        and completion.get("operation_lock_serialization_passed") is True
        and completion.get("ordered_future_cell_ids") == spec["ordered_cell_ids"]
        and completion.get("maximum_future_world_count")
        == len(spec["ordered_cell_ids"])
        and completion.get("maximum_future_campaign_attempt_count") == 1
        and completion.get("same_identity_rerun_permitted") is False
        and completion.get("physical_execution_authorized") is False
        and completion.get("physics_state_modified") is False
        and completion.get("physical_acceptance_authority") is False
        and completion.get("release_authority") is False
        and isinstance(completion_runtime, dict)
        and completion_runtime.get("path") == "runtime_identity.json"
        and completion_runtime.get("byte_length")
        == runtime_binding.get("runtime_identity_byte_length")
        and completion_runtime.get("raw_sha256")
        == runtime_binding.get("runtime_identity_sha256"),
        "QUALIFICATION_COMPLETION_FIELDS",
    )
    for counter in (
        "locomotion_outcome_exposure_count",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "scene_tree_insertion_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(
            type(completion.get(counter)) is int and completion.get(counter) == 0,
            f"QUALIFICATION_COMPLETION_ZERO_COUNTER:{counter}",
        )


def validate_attempt(
    path: Path,
    cell: Mapping[str, Any],
    report: Mapping[str, Any],
    output_root: Path,
    spec: Mapping[str, Any],
) -> dict[str, Any]:
    attempt = read_json(path, f"ATTEMPT_{cell['cell_id']}")
    require(finite_json_tree(attempt), f"ATTEMPT_NONFINITE:{cell['cell_id']}")
    expected_path = (output_root / str(cell["cell_id"]) / "attempt.json").resolve()
    expected_stage = (ROOT / str(spec["stage_path"])).resolve().as_posix()
    expected_authority = (ROOT / str(spec["authority_path"])).resolve().as_posix()
    source = report["source"]
    authority = report["authority"]
    require(
        path.resolve() == expected_path
        and attempt.get("schema_version") == PHYSICAL_ATTEMPT_SCHEMA
        and attempt.get("gate_id") == "QSDK-R10E"
        and attempt.get("repair_id") == spec["repair_id"]
        and attempt.get("campaign_id") == spec["campaign_id"]
        and attempt.get("campaign_role") == report.get("campaign_role")
        and attempt.get("question_class") == spec["question_class"]
        and attempt.get("ledger_scope")
        == ledger_scope(str(spec["question_class"]), "physical_cell_attempt")
        and isinstance(attempt.get("authorization_token"), str)
        and re.fullmatch(r"[0-9a-f]{32}", attempt["authorization_token"]) is not None
        and attempt.get("arm_id") == cell.get("arm_id")
        and attempt.get("campaign_seed") == cell.get("campaign_seed")
        and attempt.get("cell_id") == cell.get("cell_id")
        and Path(str(attempt.get("output_root", ""))).resolve() == output_root
        and attempt.get("source_commit") == source["source_commit"]
        and attempt.get("authorization_commit") == source["authorization_commit"]
        and attempt.get("authorization_parent_commit")
        == source["authorization_parent_commit"]
        and attempt.get("qualification_parent_commit")
        == source["qualification_parent_commit"]
        and attempt.get("r10e_design_sha256") == EXPECTED_DESIGN_SHA256
        and attempt.get("r10d_development_closure_sha256")
        == EXPECTED_R10D_DEVELOPMENT_SHA256
        and attempt.get("r10d_held_out_closure_sha256") == EXPECTED_R10D_HELD_OUT_SHA256
        and attempt.get("r05e_physical_closure_sha256") == EXPECTED_R05E_SHA256
        and attempt.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and l2_failure_sha_link_exact(attempt, spec)
        and attempt.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and attempt.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256
        and Path(str(attempt.get("stage_freeze_path", ""))).resolve().as_posix()
        == expected_stage
        and attempt.get("stage_freeze_sha256") == authority["stage_freeze_sha256"]
        and Path(str(attempt.get("execution_authority_path", ""))).resolve().as_posix()
        == expected_authority
        and attempt.get("execution_authority_sha256")
        == authority["execution_authority_sha256"]
        and attempt.get("operation_lock") == report.get("operation_lock")
        and attempt.get("supervisor_physical_authorized") is True
        and attempt.get("synthetic_authorization_preflight") is False
        and attempt.get("maximum_world_attempt_count") == 1
        and attempt.get("maximum_world_build_count") == 1
        and attempt.get("world_attempt_count_before_worker") == 0
        and attempt.get("world_build_count_before_worker") == 0
        and attempt.get("same_identity_rerun_permitted") is False
        and attempt.get("physical_acceptance_authority") is False
        and attempt.get("release_authority") is False
        and Path(str(attempt.get("attempt_path", ""))).resolve() == expected_path,
        f"ATTEMPT_FIELDS:{cell['cell_id']}",
    )
    validate_operation_lock(attempt["operation_lock"], str(report["campaign_role"]))
    return attempt


def validate_cell_receipt(
    receipt: Mapping[str, Any],
    cell: Mapping[str, Any],
    report: Mapping[str, Any],
    attempt_path: Path,
) -> None:
    require(finite_json_tree(receipt), f"CELL_RECEIPT_NONFINITE:{cell['cell_id']}")
    projection = _cell_projection_from_receipt(receipt)
    for key in (
        "worker_ok",
        "failure_code",
        "world_build_count_known",
        "world_build_count",
        "external_push_application_count",
        "evaluation",
        "observer_instrumentation",
    ):
        require(cell.get(key) == projection[key], f"CELL_RECEIPT_PROJECTION:{key}")
    require(cell.get("parse_failure") == "", "CELL_PARSED_WITH_FAILURE_TEXT")
    schema = receipt.get("schema_version")
    if schema == WORKER_FAILURE_SCHEMA:
        require(
            receipt.get("ok") is False
            and receipt.get("model_construction_count") == 0
            and receipt.get("world_attempt_count") == 0
            and receipt.get("world_build_count") == 0
            and receipt.get("scene_tree_insertion_count") == 0
            and receipt.get("native_readback_count") == 0
            and receipt.get("solver_step_count") == 0
            and receipt.get("physics_state_modified") is False
            and receipt.get("physical_acceptance_authority") is False
            and receipt.get("release_authority") is False,
            f"CELL_WORKER_FAILURE_RECEIPT:{cell['cell_id']}",
        )
        return
    evaluation = receipt.get("evaluation")
    authorization = receipt.get("authorization")
    observer = (
        evaluation.get("observer_instrumentation")
        if isinstance(evaluation, dict)
        else None
    )
    observer_receipt = observer.get("receipt") if isinstance(observer, dict) else None
    spec = role_spec(str(report["campaign_role"]))
    expected_stage = (ROOT / str(spec["stage_path"])).resolve()
    expected_authority = (ROOT / str(spec["authority_path"])).resolve()
    evaluation_terminal_shape_valid = (
        isinstance(evaluation, dict)
        and type(receipt.get("ok")) is bool
        and type(receipt.get("behavior_passed")) is bool
        and type(receipt.get("outcome_complete")) is bool
        and type(receipt.get("evidence_valid")) is bool
        and type(evaluation.get("ok")) is bool
        and type(evaluation.get("behavior_passed")) is bool
        and type(evaluation.get("outcome_complete")) is bool
        and type(evaluation.get("evidence_valid")) is bool
        and receipt.get("ok") is evaluation.get("ok")
        and receipt.get("behavior_passed") is evaluation.get("behavior_passed")
        and receipt.get("outcome_complete") is evaluation.get("outcome_complete")
        and receipt.get("evidence_valid") is evaluation.get("evidence_valid")
        and receipt.get("failure_code") == evaluation.get("failure_code")
        and (
            (
                evaluation.get("ok") is True
                and evaluation.get("outcome_complete") is True
                and evaluation.get("evidence_valid") is True
                and evaluation.get("failure_code") == ""
            )
            or (
                evaluation.get("ok") is False
                and evaluation.get("behavior_passed") is False
                and evaluation.get("outcome_complete") is False
                and evaluation.get("evidence_valid") is False
                and isinstance(evaluation.get("failure_code"), str)
                and bool(evaluation.get("failure_code"))
            )
        )
    )
    observer_terminal_shape_valid = (
        (
            isinstance(observer, dict)
            and observer.get("ok") is True
            and type(observer.get("live_prohibited_operation_count")) is int
            and observer.get("live_prohibited_operation_count") == 0
            and isinstance(observer_receipt, dict)
            and observer_receipt.get(
                "post_solver_materialized_row_count_matches_trace_row_count"
            )
            is True
            and observer_receipt.get(
                "post_solver_projection_receipt_count_matches_trace_row_count"
            )
            is True
        )
        if isinstance(evaluation, dict) and evaluation.get("ok") is True
        else True
    )
    require(
        schema == PHYSICAL_CELL_SCHEMA
        and receipt.get("gate_id") == "QSDK-R10E"
        and receipt.get("campaign_id") == report.get("campaign_id")
        and receipt.get("campaign_role") == report.get("campaign_role")
        and receipt.get("ledger_scope")
        == ledger_scope(str(report["question_class"]), "physical_measurement")
        and receipt.get("source_commit") == report["source"]["source_commit"]
        and receipt.get("arm_id") == cell.get("arm_id")
        and receipt.get("campaign_seed") == cell.get("campaign_seed")
        and receipt.get("cell_id") == cell.get("cell_id")
        and receipt.get("selected_candidate_id") == "BW5R-B"
        and receipt.get("controller_policy_id") == "sporespore_balanced_wave_bw5r_b_v1"
        and receipt.get("selected_policy_digest") == EXPECTED_SELECTED_POLICY_DIGEST
        and receipt.get("generator_index") == 225
        and receipt.get("morphology_id") == "qsdk_r05e_axis_star_foot_radius_low_s225"
        and receipt.get("generator_receipt_sha256") == EXPECTED_GENERATOR_RECEIPT_SHA256
        and receipt.get("source_r05e_generator_receipt_sha256")
        == EXPECTED_R05E_GENERATOR_RECEIPT_SHA256
        and receipt.get("proportion_spec_sha256")
        == EXPECTED_R05E_PROPORTION_SPEC_SHA256
        and receipt.get("material_profile_id") == "godot_jolt_bw5c_mu095_v1"
        and receipt.get("material_profile_sha256") == EXPECTED_MATERIAL_PROFILE_SHA256
        and receipt.get("fixture_spec_sha256") == EXPECTED_FIXTURE_SPEC_SHA256
        and receipt.get("controller_profile_sha256")
        == EXPECTED_CONTROLLER_PROFILE_SHA256
        and receipt.get("adapter_capability_sha256")
        == EXPECTED_ADAPTER_CAPABILITY_SHA256
        and receipt.get("r10e_design_sha256") == EXPECTED_DESIGN_SHA256
        and receipt.get("r10d_development_closure_sha256")
        == EXPECTED_R10D_DEVELOPMENT_SHA256
        and receipt.get("r10d_held_out_closure_sha256") == EXPECTED_R10D_HELD_OUT_SHA256
        and receipt.get("r05e_physical_closure_sha256") == EXPECTED_R05E_SHA256
        and receipt.get("world_build_count") == 1
        and receipt.get("world_reset_count") == 0
        and isinstance(authorization, dict)
        and evaluation_terminal_shape_valid
        and observer_terminal_shape_valid
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False,
        f"CELL_PHYSICAL_RECEIPT:{cell['cell_id']}",
    )
    require(
        authorization.get("ok") is True
        and authorization.get("failure_code") == ""
        and authorization.get("repair_id") == spec["repair_id"]
        and authorization.get("campaign_id") == report.get("campaign_id")
        and authorization.get("campaign_role") == report.get("campaign_role")
        and authorization.get("question_class") == report.get("question_class")
        and authorization.get("ledger_scope")
        == ledger_scope(str(report["question_class"]), "physical_worker_authorization")
        and authorization.get("arm_id") == cell.get("arm_id")
        and authorization.get("campaign_seed") == cell.get("campaign_seed")
        and authorization.get("cell_id") == cell.get("cell_id")
        and authorization.get("source_commit") == report["source"]["source_commit"]
        and authorization.get("authorization_commit")
        == report["source"]["authorization_commit"]
        and authorization.get("authorization_parent_commit")
        == report["source"]["authorization_parent_commit"]
        and authorization.get("qualification_parent_commit")
        == report["source"]["qualification_parent_commit"]
        and authorization.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and l2_failure_sha_link_exact(authorization, spec)
        and Path(str(authorization.get("attempt_path", ""))).resolve()
        == attempt_path.resolve()
        and authorization.get("attempt_sha256") == sha256_file(attempt_path)
        and Path(str(authorization.get("stage_freeze_path", ""))).resolve()
        == expected_stage
        and authorization.get("stage_freeze_sha256")
        == report["authority"]["stage_freeze_sha256"]
        and Path(str(authorization.get("execution_authority_path", ""))).resolve()
        == expected_authority
        and authorization.get("execution_authority_sha256")
        == report["authority"]["execution_authority_sha256"]
        and Path(str(authorization.get("output_root", ""))).resolve()
        == Path(str(report["output_root"])).resolve()
        and authorization.get("world_build_count") == 0
        and authorization.get("physical_acceptance_authority") is False
        and authorization.get("release_authority") is False,
        f"CELL_AUTHORIZATION_RECEIPT:{cell['cell_id']}",
    )


def validate_pair_receipt(
    receipt: Mapping[str, Any],
    pair: Mapping[str, Any],
    report: Mapping[str, Any],
    cell_receipt_digests: Mapping[str, str],
    cell_behaviors: Mapping[str, bool],
) -> None:
    require(finite_json_tree(receipt), f"PAIR_RECEIPT_NONFINITE:{pair['pair_id']}")
    require(
        pair.get("evaluation") == _pair_projection_from_receipt(receipt),
        f"PAIR_RECEIPT_PROJECTION:{pair['pair_id']}",
    )
    require(pair.get("parse_failure") == "", "PAIR_PARSED_WITH_FAILURE_TEXT")
    if receipt.get("schema_version") == WORKER_FAILURE_SCHEMA:
        require(
            receipt.get("ok") is False
            and receipt.get("model_construction_count") == 0
            and receipt.get("world_attempt_count") == 0
            and receipt.get("world_build_count") == 0
            and receipt.get("scene_tree_insertion_count") == 0
            and receipt.get("native_readback_count") == 0
            and receipt.get("solver_step_count") == 0
            and receipt.get("physics_state_modified") is False
            and receipt.get("physical_acceptance_authority") is False
            and receipt.get("release_authority") is False,
            f"PAIR_WORKER_FAILURE_RECEIPT:{pair['pair_id']}",
        )
        return
    seed = int(str(pair["pair_id"]).removeprefix("pair_s"))
    baseline_id = f"baseline_s{seed}"
    push_id = f"push_s{seed}"
    baseline_jump = receipt.get("baseline_lateral_velocity_jump_m_s")
    push_jump = receipt.get("push_lateral_velocity_jump_m_s")
    paired_jump = receipt.get("paired_lateral_velocity_jump_difference_m_s")
    native_effect = receipt.get("native_effect_magnitude_m_s")
    baseline_behavior = cell_behaviors.get(baseline_id)
    push_behavior = cell_behaviors.get(push_id)
    require(
        receipt.get("schema_version") == PAIR_EVALUATION_SCHEMA
        and receipt.get("gate_id") == "QSDK-R10E"
        and receipt.get("failure_code") == ""
        and receipt.get("campaign_seed") == seed
        and receipt.get("baseline_cell_id") == baseline_id
        and receipt.get("push_cell_id") == push_id
        and receipt.get("matched_initial_perturbation") is True
        and receipt.get("native_effect_confirmed") is True
        and type(receipt.get("ok")) is bool
        and receipt.get("ok") is True
        and type(receipt.get("outcome_complete")) is bool
        and receipt.get("outcome_complete") is True
        and type(receipt.get("evidence_valid")) is bool
        and receipt.get("evidence_valid") is True
        and type(receipt.get("behavior_passed")) is bool
        and type(baseline_behavior) is bool
        and type(push_behavior) is bool
        and receipt.get("baseline_behavior_passed") is baseline_behavior
        and receipt.get("push_behavior_passed") is push_behavior
        and receipt.get("behavior_passed") is (baseline_behavior and push_behavior)
        and is_finite_number(baseline_jump)
        and is_finite_number(push_jump)
        and is_finite_number(paired_jump)
        and math.isclose(
            float(paired_jump),
            float(push_jump) - float(baseline_jump),
            rel_tol=0.0,
            abs_tol=1.0e-12,
        )
        and float(paired_jump) > 0.0
        and is_finite_number(native_effect)
        and float(native_effect) > MINIMUM_NATIVE_EFFECT_M_S
        and receipt.get("baseline_cell_raw_sha256")
        == cell_receipt_digests.get(baseline_id)
        and receipt.get("push_cell_raw_sha256") == cell_receipt_digests.get(push_id)
        and receipt.get("model_construction_count") == 0
        and receipt.get("world_attempt_count") == 0
        and receipt.get("world_build_count") == 0
        and receipt.get("scene_tree_insertion_count") == 0
        and receipt.get("native_readback_count") == 0
        and receipt.get("solver_step_count") == 0
        and receipt.get("evaluation_world_build_count") == 0
        and receipt.get("physics_state_modified") is False
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False
        and receipt.get("ledger_scope")
        == ledger_scope(str(report["question_class"]), "zero_world_pair_evaluation"),
        f"PAIR_EVALUATION_RECEIPT:{pair['pair_id']}",
    )


def _cell_is_valid_complete(cell: Mapping[str, Any], expected_id: str) -> bool:
    evaluation = cell.get("evaluation")
    observer = cell.get("observer_instrumentation")
    expected_arm, expected_seed = expected_cell_identity(expected_id)
    return (
        cell.get("cell_id") == expected_id
        and cell.get("arm_id") == expected_arm
        and cell.get("campaign_seed") == expected_seed
        and cell.get("attempted") is True
        and cell.get("process_completed") is True
        and cell.get("timed_out") is False
        and type(cell.get("process_exit_code")) is int
        and cell.get("process_exit_code") == 0
        and cell.get("marker_receipt_parsed") is True
        and cell.get("worker_ok") is True
        and cell.get("world_build_count_known") is True
        and cell.get("world_build_count") == 1
        and isinstance(evaluation, dict)
        and evaluation.get("ok") is True
        and evaluation.get("outcome_complete") is True
        and evaluation.get("evidence_valid") is True
        and isinstance(evaluation.get("behavior_passed"), bool)
        and isinstance(observer, dict)
        and observer.get("valid") is True
        and observer.get("live_prohibited_operation_count") == 0
        and observer.get("post_solver_materialized_row_count_matches_trace_row_count")
        is True
        and observer.get("post_solver_projection_receipt_count_matches_trace_row_count")
        is True
    )


def _pair_is_valid_complete(pair: Mapping[str, Any], expected_id: str) -> bool:
    evaluation = pair.get("evaluation")
    return (
        pair.get("pair_id") == expected_id
        and pair.get("evaluator_completed") is True
        and pair.get("timed_out") is False
        and type(pair.get("process_exit_code")) is int
        and pair.get("process_exit_code") == 0
        and pair.get("marker_receipt_parsed") is True
        and isinstance(evaluation, dict)
        and evaluation.get("ok") is True
        and evaluation.get("outcome_complete") is True
        and evaluation.get("evidence_valid") is True
        and evaluation.get("native_effect_confirmed") is True
        and isinstance(evaluation.get("behavior_passed"), bool)
    )


def _validate_bounded_attempt_counts(
    report: Mapping[str, Any], spec: Mapping[str, Any]
) -> None:
    maximum_world_count = len(spec["ordered_cell_ids"])
    world_attempt_count = report.get("world_attempt_count")
    world_build_count = report.get("world_build_count")
    require(
        report.get("maximum_world_count") == maximum_world_count,
        "REPORT_MAXIMUM_WORLD_COUNT",
    )
    require(
        type(report.get("campaign_attempt_count")) is int
        and report.get("campaign_attempt_count") == 1
        and type(report.get("maximum_campaign_attempt_count")) is int
        and report.get("maximum_campaign_attempt_count") == 1,
        "REPORT_CAMPAIGN_ATTEMPT_BOUND",
    )
    require(
        type(world_attempt_count) is int
        and 0 <= world_attempt_count <= maximum_world_count,
        "REPORT_WORLD_ATTEMPT_BOUND",
    )
    cell_count = len(report["cells"])
    require(
        cell_count <= world_attempt_count <= min(cell_count + 1, maximum_world_count),
        "REPORT_WORLD_ATTEMPT_RECORD_LINK",
    )
    require(
        type(world_build_count) is int
        and 0 <= world_build_count <= maximum_world_count
        and world_build_count <= world_attempt_count,
        "REPORT_WORLD_BUILD_BOUND",
    )
    require(
        type(report.get("world_build_count_known")) is bool,
        "REPORT_WORLD_BUILD_COUNT_KNOWN_TYPE",
    )


def derive_outcome(report: Mapping[str, Any]) -> dict[str, Any]:
    role = str(report.get("campaign_role", ""))
    spec = role_spec(role)
    cells = report.get("cells")
    pairs = report.get("pairs")
    require(isinstance(cells, list), "REPORT_CELLS_NOT_ARRAY")
    require(isinstance(pairs, list), "REPORT_PAIRS_NOT_ARRAY")
    cell_order = [item.get("cell_id") for item in cells if isinstance(item, dict)]
    pair_order = [item.get("pair_id") for item in pairs if isinstance(item, dict)]
    exact_order = cell_order == spec[
        "ordered_cell_ids"
    ] and pair_order == expected_pair_ids(spec)
    valid_cells = (
        exact_order
        and len(cells) == len(spec["ordered_cell_ids"])
        and all(
            isinstance(cell, dict) and _cell_is_valid_complete(cell, expected)
            for cell, expected in zip(cells, spec["ordered_cell_ids"], strict=True)
        )
    )
    pair_ids = expected_pair_ids(spec)
    valid_pairs = (
        exact_order
        and len(pairs) == len(pair_ids)
        and all(
            isinstance(pair, dict) and _pair_is_valid_complete(pair, expected)
            for pair, expected in zip(pairs, pair_ids, strict=True)
        )
    )
    attempts_exact = (
        report.get("world_attempt_count") == len(spec["ordered_cell_ids"])
        and report.get("world_build_count_known") is True
        and report.get("world_build_count") == len(spec["ordered_cell_ids"])
        and report.get("maximum_world_count") == len(spec["ordered_cell_ids"])
        and report.get("campaign_attempt_count") == 1
        and report.get("maximum_campaign_attempt_count") == 1
    )
    valid_complete = bool(valid_cells and valid_pairs and attempts_exact)
    if not valid_complete:
        classification = "invalid_or_incomplete_no_behavioral_conclusion"
        behavior: bool | None = None
    else:
        behavior = all(
            bool(cell["evaluation"]["behavior_passed"]) for cell in cells
        ) and all(bool(pair["evaluation"]["behavior_passed"]) for pair in pairs)
        classification = (
            "valid_complete_behavior_positive"
            if behavior
            else "valid_complete_behavior_finite_negative"
        )
    return {
        "classification": classification,
        "route_execution_valid": valid_complete,
        "outcome_complete": valid_complete,
        "evidence_valid": valid_complete,
        "behavior_passed": behavior,
        "attempted_cell_count": len(
            [
                cell
                for cell in cells
                if isinstance(cell, dict) and cell.get("attempted") is True
            ]
        ),
        "valid_complete_cell_count": (
            len(spec["ordered_cell_ids"]) if valid_cells else 0
        ),
        "valid_complete_pair_count": len(expected_pair_ids(spec)) if valid_pairs else 0,
        "native_effect_pair_count": (
            len(expected_pair_ids(spec)) if valid_pairs else 0
        ),
        "observer_valid_cell_count": len(
            [
                cell
                for cell in cells
                if isinstance(cell, dict)
                and isinstance(cell.get("observer_instrumentation"), dict)
                and cell["observer_instrumentation"].get("valid") is True
            ]
        ),
        "held_out_qualification_eligible": role == "development_route_ghost"
        and valid_complete,
        "separate_qsdk_r10_adoption_eligible": (
            role == "held_out_finite_decision" and behavior is True
        ),
    }


def validate_report(
    report: Mapping[str, Any],
    *,
    verify_files: bool,
    report_path: Path | None = None,
) -> dict[str, Any]:
    require(finite_json_tree(report), "REPORT_NONFINITE_OR_NONJSON_VALUE")
    role = str(report.get("campaign_role", ""))
    spec = role_spec(role)
    source = report.get("source")
    authority = report.get("authority")
    runtime = report.get("runtime_identity")
    declared_outcome = report.get("outcome")
    cells = report.get("cells")
    pairs = report.get("pairs")
    require(
        report.get("schema_version") == spec["report_schema"]
        and report.get("gate_id") == "QSDK-R10E"
        and report.get("campaign_id") == spec["campaign_id"]
        and report.get("question_class") == spec["question_class"]
        and report.get("ledger_scope")
        == ledger_scope(
            str(spec["question_class"]), "consumed_physical_campaign_report"
        )
        and report.get("physical_identity_consumed") is True
        and report.get("same_identity_rerun_permitted") is False
        and report.get("terminal_report_retained") is True
        and report.get("physical_acceptance_authority") is False
        and report.get("release_authority") is False,
        "REPORT_HEADER",
    )
    require(isinstance(source, dict), "REPORT_SOURCE_NOT_OBJECT")
    require(
        is_commit(source.get("source_commit"))
        and is_commit(source.get("authorization_commit"))
        and is_commit(source.get("authorization_parent_commit"))
        and is_commit(source.get("qualification_parent_commit"))
        and source.get("repair_id") == spec["repair_id"]
        and source.get("r10e_design_sha256") == EXPECTED_DESIGN_SHA256
        and source.get("r10d_development_closure_sha256")
        == EXPECTED_R10D_DEVELOPMENT_SHA256
        and source.get("r10d_held_out_closure_sha256") == EXPECTED_R10D_HELD_OUT_SHA256
        and source.get("r05e_physical_closure_sha256") == EXPECTED_R05E_SHA256
        and source.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and l2_failure_sha_link_exact(source, spec)
        and source.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and source.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256,
        "REPORT_SOURCE",
    )
    require(isinstance(authority, dict), "REPORT_AUTHORITY_NOT_OBJECT")
    require(
        authority.get("committed_graph_authority_check_passed") is True
        and authority.get("single_use_authority_consumed_by_this_report") is True
        and is_sha256(authority.get("stage_freeze_sha256"))
        and is_sha256(authority.get("execution_authority_sha256")),
        "REPORT_AUTHORITY",
    )
    require(isinstance(runtime, dict), "REPORT_RUNTIME_NOT_OBJECT")
    require(
        runtime.get("runtime_identity_complete") is True
        and isinstance(runtime.get("runtime_identity_path"), str)
        and bool(runtime.get("runtime_identity_path"))
        and type(runtime.get("runtime_identity_byte_length")) is int
        and runtime.get("runtime_identity_byte_length") > 0
        and is_sha256(runtime.get("runtime_identity_sha256"))
        and is_sha256(runtime.get("active_adapter_raw_sha256")),
        "REPORT_RUNTIME",
    )
    require(
        isinstance(cells, list)
        and all(isinstance(cell, dict) for cell in cells)
        and isinstance(pairs, list)
        and all(isinstance(pair, dict) for pair in pairs),
        "REPORT_RECORD_ARRAYS",
    )
    observed_cell_ids = [str(cell.get("cell_id", "")) for cell in cells]
    observed_pair_ids = [str(pair.get("pair_id", "")) for pair in pairs]
    pair_ids = expected_pair_ids(spec)
    require(
        report.get("ordered_cell_ids") == spec["ordered_cell_ids"]
        and report.get("expected_pair_ids") == pair_ids
        and observed_cell_ids == spec["ordered_cell_ids"][: len(cells)]
        and observed_pair_ids == pair_ids[: len(pairs)],
        "REPORT_RECORD_ORDER",
    )
    validate_operation_lock(report.get("operation_lock"), role)
    _validate_bounded_attempt_counts(report, spec)
    derived = derive_outcome(report)
    require(declared_outcome == derived, "REPORT_OUTCOME_DERIVATION_DRIFT")
    expected_status = {
        "valid_complete_behavior_positive": "closed_consumed_valid_complete_behavior_positive",
        "valid_complete_behavior_finite_negative": "closed_consumed_valid_complete_behavior_finite_negative",
        "invalid_or_incomplete_no_behavioral_conclusion": "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion",
    }[derived["classification"]]
    require(report.get("status") == expected_status, "REPORT_STATUS_CLASSIFICATION")
    terminal_failure = report.get("terminal_failure")
    require(
        isinstance(terminal_failure, str)
        and (
            terminal_failure == ""
            if derived["route_execution_valid"]
            else bool(terminal_failure)
        ),
        "REPORT_TERMINAL_FAILURE_LINK",
    )
    if not derived["route_execution_valid"] and cells:
        last_cell = cells[-1]
        last_cell_id = str(last_cell.get("cell_id", ""))
        last_failure = str(last_cell.get("failure_code", ""))
        if last_failure:
            require(
                last_cell_id in terminal_failure and last_failure in terminal_failure,
                "REPORT_PRIMARY_CELL_FAILURE_NOT_RETAINED",
            )
    if verify_files:
        output_root = Path(str(report.get("output_root", ""))).resolve()
        expected_output_root = (
            EXPECTED_EVIDENCE_ROOT
            / (
                f"qsdk-r10e-{spec['output_slug']}-physical-"
                f"{str(source['source_commit'])[:12]}"
            )
        ).resolve()
        require(
            output_root == expected_output_root and output_root.is_dir(),
            "REPORT_OUTPUT_ROOT",
        )
        require(report_path is not None, "REPORT_PATH_REQUIRED")
        require(
            report_path.resolve() == (output_root / "terminal_report.json").resolve(),
            "REPORT_PATH_OUTSIDE_OUTPUT_ROOT",
        )
        validate_committed_authority_chain(report, runtime, spec)
        validate_runtime_identity(report, runtime, spec)
        validate_campaign_start(output_root, report, spec)
        cell_receipt_digests: dict[str, str] = {}
        cell_behaviors: dict[str, bool] = {}
        for cell in cells:
            attempt_path = validate_file_binding(
                output_root, cell.get("attempt_binding"), "CELL_ATTEMPT"
            )
            validate_attempt(attempt_path, cell, report, output_root, spec)
            stdout_path = validate_file_binding(
                output_root, cell.get("stdout_binding"), "CELL_STDOUT"
            )
            validate_file_binding(
                output_root, cell.get("stderr_binding"), "CELL_STDERR"
            )
            if cell.get("marker_receipt_parsed") is True:
                receipt_path = validate_file_binding(
                    output_root, cell.get("receipt_binding"), "CELL_RECEIPT"
                )
                receipt = read_json(receipt_path, f"CELL_RECEIPT_{cell['cell_id']}")
                validate_marker_link(
                    stdout_path, CELL_MARKER, receipt, f"CELL_{cell['cell_id']}"
                )
                validate_cell_receipt(receipt, cell, report, attempt_path)
                cell_receipt_digests[str(cell["cell_id"])] = sha256_file(receipt_path)
                if (
                    receipt.get("schema_version") == PHYSICAL_CELL_SCHEMA
                    and type(receipt.get("behavior_passed")) is bool
                ):
                    cell_behaviors[str(cell["cell_id"])] = receipt["behavior_passed"]
            else:
                require(cell.get("receipt_binding") is None, "CELL_RECEIPT_UNPARSED")
        for pair in pairs:
            stdout_path = validate_file_binding(
                output_root, pair.get("stdout_binding"), "PAIR_STDOUT"
            )
            validate_file_binding(
                output_root, pair.get("stderr_binding"), "PAIR_STDERR"
            )
            if pair.get("marker_receipt_parsed") is True:
                receipt_path = validate_file_binding(
                    output_root, pair.get("receipt_binding"), "PAIR_RECEIPT"
                )
                receipt = read_json(receipt_path, f"PAIR_RECEIPT_{pair['pair_id']}")
                validate_marker_link(
                    stdout_path, PAIR_MARKER, receipt, f"PAIR_{pair['pair_id']}"
                )
                validate_pair_receipt(
                    receipt,
                    pair,
                    report,
                    cell_receipt_digests,
                    cell_behaviors,
                )
            else:
                require(pair.get("receipt_binding") is None, "PAIR_RECEIPT_UNPARSED")
    return derived


def closure_status(role: str, outcome: Mapping[str, Any]) -> str:
    classification = outcome["classification"]
    if classification == "invalid_or_incomplete_no_behavioral_conclusion":
        return "closed_consumed_invalid_or_incomplete_no_finite_decision"
    if role == "development_route_ghost":
        return (
            "closed_execution_valid_complete_behavior_positive"
            if classification == "valid_complete_behavior_positive"
            else "closed_execution_valid_complete_behavior_finite_negative"
        )
    return (
        "closed_consumed_valid_complete_positive_eligible_for_separate_qsdk_r10_adoption"
        if classification == "valid_complete_behavior_positive"
        else "closed_consumed_valid_complete_finite_negative"
    )


def evidence_tree_inventory(output_root: Path) -> dict[str, Any]:
    require(output_root.is_dir(), "EVIDENCE_TREE_ROOT")
    entries: list[dict[str, Any]] = []
    for path in sorted(
        output_root.rglob("*"),
        key=lambda item: item.relative_to(output_root).as_posix(),
    ):
        require(not path.is_symlink(), f"EVIDENCE_TREE_SYMLINK:{path}")
        if not path.is_file():
            continue
        entries.append(
            {
                "path": path.relative_to(output_root).as_posix(),
                "byte_length": path.stat().st_size,
                "raw_sha256": sha256_file(path),
            }
        )
    paths = [str(entry["path"]) for entry in entries]
    require(paths == sorted(set(paths)), "EVIDENCE_TREE_PATH_ORDER")
    require(
        "campaign_start.json" in paths and "terminal_report.json" in paths,
        "EVIDENCE_TREE_REQUIRED_FILES",
    )
    canonical_entries = json.dumps(
        entries,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return {
        "schema_version": "sporespore_qsdk_r10e_retained_evidence_tree_v1",
        "root": output_root.as_posix(),
        "file_count": len(entries),
        "total_byte_length": sum(int(entry["byte_length"]) for entry in entries),
        "path_set_sha256": sha256_bytes("\n".join(paths).encode("utf-8")),
        "manifest_sha256": sha256_bytes(canonical_entries),
        "files": entries,
    }


def build_closure(
    report_path: Path, report: Mapping[str, Any], outcome: Mapping[str, Any]
) -> dict[str, Any]:
    role = str(report["campaign_role"])
    spec = role_spec(role)
    report_raw = report_path.read_bytes()
    retained_tree = evidence_tree_inventory(Path(str(report["output_root"])).resolve())
    return {
        "schema_version": spec["closure_schema"],
        "status": closure_status(role, outcome),
        "gate_id": "QSDK-R10E",
        "campaign_id": spec["campaign_id"],
        "campaign_role": role,
        "question_class": spec["question_class"],
        "ledger_scope": ledger_scope(
            str(spec["question_class"]), "immutable_physical_closure"
        ),
        "source": dict(report["source"]),
        "authority": dict(report["authority"]),
        "runtime_identity": dict(report["runtime_identity"]),
        "retained_evidence": {
            "output_root": report["output_root"],
            "terminal_report": {
                "path": str(report_path.resolve()),
                "byte_length": len(report_raw),
                "raw_sha256": sha256_bytes(report_raw),
            },
            "retained_tree": retained_tree,
            "declared_cell_count": len(spec["ordered_cell_ids"]),
            "attempted_cell_count": outcome["attempted_cell_count"],
            "valid_complete_cell_count": outcome["valid_complete_cell_count"],
            "valid_complete_pair_count": outcome["valid_complete_pair_count"],
            "terminal_report_retained": True,
        },
        "outcome": dict(outcome),
        "route_execution_valid": outcome["route_execution_valid"],
        "evidence_valid": outcome["evidence_valid"],
        "outcome_complete": outcome["outcome_complete"],
        "behavior_passed": outcome["behavior_passed"],
        "behavioral_conclusion_available": outcome["route_execution_valid"],
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "decision": {
            "q_sdk_r10e_campaign_closed": True,
            "q_sdk_r10_gate_advanced_by_this_closure": False,
            "sdk1_m07_advanced_by_this_closure": False,
            "external_push_recovery_claimed_by_this_closure": False,
            "separate_qsdk_r10_adoption_eligible": outcome[
                "separate_qsdk_r10_adoption_eligible"
            ],
            "held_out_qualification_eligible": outcome[
                "held_out_qualification_eligible"
            ],
        },
        "claim_boundary": {
            "exact_godot_jolt_policy_morphology_material_seed_and_challenge_slice_only": True,
            "forced_fall_or_prone_to_standing_claimed": False,
            "force_aware_recovery_claimed": False,
            "arbitrary_push_tolerance_claimed": False,
            "cross_engine_equivalence_claimed": False,
            "population_inference_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "closure_process": {
            "schema_version": "sporespore_qsdk_r10e_physical_closure_process_v1",
            "ledger_scope": ledger_scope(
                str(spec["question_class"]), "zero_world_closure_compilation"
            ),
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "native_readback_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
    }


def write_new_json(path: Path, value: Mapping[str, Any]) -> None:
    require(not path.exists(), "CLOSURE_OUTPUT_ALREADY_EXISTS")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    )


def _synthetic_cell(cell_id: str, behavior: bool = True) -> dict[str, Any]:
    arm_id, seed = expected_cell_identity(cell_id)
    return {
        "cell_id": cell_id,
        "arm_id": arm_id,
        "campaign_seed": seed,
        "attempted": True,
        "process_completed": True,
        "timed_out": False,
        "process_exit_code": 0,
        "marker_receipt_parsed": True,
        "worker_ok": True,
        "world_build_count_known": True,
        "world_build_count": 1,
        "attempt_binding": {
            "path": "unused",
            "byte_length": 0,
            "raw_sha256": "sha256:" + "0" * 64,
        },
        "receipt_binding": None,
        "stdout_binding": None,
        "stderr_binding": None,
        "evaluation": {
            "ok": True,
            "outcome_complete": True,
            "evidence_valid": True,
            "behavior_passed": behavior,
        },
        "observer_instrumentation": {
            "valid": True,
            "live_prohibited_operation_count": 0,
            "post_solver_materialized_row_count_matches_trace_row_count": True,
            "post_solver_projection_receipt_count_matches_trace_row_count": True,
        },
    }


def _synthetic_pair(pair_id: str, behavior: bool = True) -> dict[str, Any]:
    return {
        "pair_id": pair_id,
        "evaluator_completed": True,
        "timed_out": False,
        "process_exit_code": 0,
        "marker_receipt_parsed": True,
        "receipt_binding": None,
        "stdout_binding": None,
        "stderr_binding": None,
        "evaluation": {
            "ok": True,
            "outcome_complete": True,
            "evidence_valid": True,
            "behavior_passed": behavior,
            "native_effect_confirmed": True,
        },
    }


def _synthetic_invalid_cell(cell_id: str, failure_code: str) -> dict[str, Any]:
    cell = _synthetic_cell(cell_id, behavior=False)
    cell["process_exit_code"] = 1
    cell["worker_ok"] = False
    cell["failure_code"] = failure_code
    cell["evaluation"] = {
        "ok": False,
        "failure_code": failure_code,
        "outcome_complete": False,
        "evidence_valid": False,
        "behavior_passed": False,
    }
    cell["observer_instrumentation"] = {
        "valid": False,
        "live_prohibited_operation_count": -1,
        "post_solver_materialized_row_count_matches_trace_row_count": False,
        "post_solver_projection_receipt_count_matches_trace_row_count": False,
    }
    return cell


def _synthetic_operation_lock(role: str) -> dict[str, Any]:
    return {
        "schema_version": LOCOMOTION_LOCK_SCHEMA,
        "acquired": True,
        "role": (
            "physical_development" if role == "development_route_ghost" else "physical"
        ),
        "mutex_name": LOCOMOTION_MUTEX_NAME,
        "created_new": True,
        "abandoned_owner_recovered": False,
        "owner_process_id": 1,
        "owner_session_id": 1,
        "acquired_utc": "2026-01-01T00:00:00Z",
        "test_only": False,
        "physical_acceptance_authority": False,
    }


def _synthetic_report(role: str, *, behavior: bool = True) -> dict[str, Any]:
    spec = role_spec(role)
    report: dict[str, Any] = {
        "schema_version": spec["report_schema"],
        "status": "",
        "gate_id": "QSDK-R10E",
        "campaign_id": spec["campaign_id"],
        "campaign_role": role,
        "question_class": spec["question_class"],
        "ledger_scope": ledger_scope(
            str(spec["question_class"]), "consumed_physical_campaign_report"
        ),
        "source": {
            "repair_id": spec["repair_id"],
            "source_commit": "1" * 40,
            "authorization_commit": "2" * 40,
            "authorization_parent_commit": "3" * 40,
            "qualification_parent_commit": "1" * 40,
            "r10e_design_sha256": EXPECTED_DESIGN_SHA256,
            "r10d_development_closure_sha256": EXPECTED_R10D_DEVELOPMENT_SHA256,
            "r10d_held_out_closure_sha256": EXPECTED_R10D_HELD_OUT_SHA256,
            "r05e_physical_closure_sha256": EXPECTED_R05E_SHA256,
            "superseded_physical_supervisor_refusal_sha256": (
                EXPECTED_SUPERVISOR_REFUSAL_SHA256
            ),
            "qualified_source_path_count": EXPECTED_SOURCE_COUNT,
            "qualified_source_path_sha256": EXPECTED_SOURCE_PATH_SHA256,
        },
        "authority": {
            "committed_graph_authority_check_passed": True,
            "single_use_authority_consumed_by_this_report": True,
            "stage_freeze_sha256": "sha256:" + "4" * 64,
            "execution_authority_sha256": "sha256:" + "5" * 64,
        },
        "runtime_identity": {
            "runtime_identity_complete": True,
            "runtime_identity_path": "C:/synthetic/runtime_identity.json",
            "runtime_identity_byte_length": 1,
            "runtime_identity_sha256": "sha256:" + "6" * 64,
            "active_adapter_raw_sha256": "sha256:" + "7" * 64,
        },
        "output_root": "C:/synthetic/not-created",
        "ordered_cell_ids": list(spec["ordered_cell_ids"]),
        "expected_pair_ids": expected_pair_ids(spec),
        "campaign_start_binding": None,
        "cells": [
            _synthetic_cell(cell_id, behavior) for cell_id in spec["ordered_cell_ids"]
        ],
        "pairs": [
            _synthetic_pair(pair_id, behavior) for pair_id in expected_pair_ids(spec)
        ],
        "world_attempt_count": len(spec["ordered_cell_ids"]),
        "world_build_count_known": True,
        "world_build_count": len(spec["ordered_cell_ids"]),
        "maximum_world_count": len(spec["ordered_cell_ids"]),
        "campaign_attempt_count": 1,
        "maximum_campaign_attempt_count": 1,
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "terminal_report_retained": True,
        "terminal_failure": "",
        "operation_lock": _synthetic_operation_lock(role),
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    if spec["repair_id"] == "QSDK-R10E-L3":
        report["source"][
            "l2_held_out_failure_closure_sha256"
        ] = EXPECTED_L2_HELD_OUT_FAILURE_SHA256
    report["outcome"] = derive_outcome(report)
    if not report["outcome"]["route_execution_valid"]:
        report["terminal_failure"] = "SYNTHETIC_INVALID_OR_INCOMPLETE"
    report["status"] = {
        "valid_complete_behavior_positive": "closed_consumed_valid_complete_behavior_positive",
        "valid_complete_behavior_finite_negative": "closed_consumed_valid_complete_behavior_finite_negative",
        "invalid_or_incomplete_no_behavioral_conclusion": "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion",
    }[report["outcome"]["classification"]]
    return report


def self_test() -> dict[str, Any]:
    valid_count = 0
    mutation_rejection_count = 0
    classifications: list[str] = []
    fixtures = [
        _synthetic_report("development_route_ghost", behavior=True),
        _synthetic_report("development_route_ghost", behavior=False),
        _synthetic_report("held_out_finite_decision", behavior=True),
        _synthetic_report("held_out_finite_decision", behavior=False),
    ]
    incomplete = _synthetic_report("development_route_ghost", behavior=True)
    incomplete["cells"] = incomplete["cells"][:1]
    incomplete["pairs"] = []
    incomplete["world_attempt_count"] = 1
    incomplete["world_build_count"] = 1
    incomplete["outcome"] = derive_outcome(incomplete)
    incomplete["status"] = (
        "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
    )
    incomplete["terminal_failure"] = "SYNTHETIC_INVALID_OR_INCOMPLETE"
    fixtures.append(incomplete)
    empty = _synthetic_report("held_out_finite_decision", behavior=True)
    empty["cells"] = []
    empty["pairs"] = []
    empty["world_attempt_count"] = 0
    empty["world_build_count"] = 0
    empty["outcome"] = derive_outcome(empty)
    empty["status"] = "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
    empty["terminal_failure"] = "SYNTHETIC_EMPTY_POPULATION"
    fixtures.append(empty)
    primary_failure = _synthetic_report("held_out_finite_decision", behavior=True)
    primary_failure["cells"] = [
        _synthetic_cell("baseline_s40101"),
        _synthetic_invalid_cell(
            "push_s40101", "QSDK_R10E_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH"
        ),
    ]
    primary_failure["pairs"] = []
    primary_failure["world_attempt_count"] = 2
    primary_failure["world_build_count"] = 2
    primary_failure["outcome"] = derive_outcome(primary_failure)
    primary_failure["status"] = (
        "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
    )
    primary_failure["terminal_failure"] = (
        "CELL_INVALID_OR_INCOMPLETE:push_s40101:"
        "QSDK_R10E_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH"
    )
    fixtures.append(primary_failure)
    for fixture in fixtures:
        outcome = validate_report(fixture, verify_files=False)
        valid_count += 1
        classifications.append(str(outcome["classification"]))
    for key, changed in (
        ("physical_identity_consumed", False),
        ("same_identity_rerun_permitted", True),
        ("terminal_report_retained", False),
        ("world_attempt_count", 0),
        ("outcome", {}),
        ("status", "open"),
    ):
        mutation = json.loads(json.dumps(fixtures[0]))
        mutation[key] = changed
        try:
            validate_report(mutation, verify_files=False)
        except ClosureFailure:
            mutation_rejection_count += 1
    omitted_primary = json.loads(json.dumps(primary_failure))
    omitted_primary["terminal_failure"] = "CELL_INVALID_OR_INCOMPLETE"
    try:
        validate_report(omitted_primary, verify_files=False)
    except ClosureFailure:
        mutation_rejection_count += 1
    maximum_world_count = len(role_spec("development_route_ghost")["ordered_cell_ids"])
    for key, changed in (
        ("maximum_world_count", maximum_world_count + 1),
        ("maximum_campaign_attempt_count", 2),
        ("campaign_attempt_count", 0),
        ("world_attempt_count", -1),
        ("world_attempt_count", maximum_world_count + 1),
        ("world_attempt_count", True),
        ("world_build_count", -1),
        ("world_build_count", maximum_world_count + 1),
        ("world_build_count", 2),
        ("world_build_count_known", "true"),
    ):
        mutation = json.loads(json.dumps(incomplete))
        mutation[key] = changed
        try:
            validate_report(mutation, verify_files=False)
        except ClosureFailure:
            mutation_rejection_count += 1
    for section, changed in (("cells", False), ("pairs", 1)):
        mutation = json.loads(json.dumps(fixtures[0]))
        mutation[section][0]["process_exit_code"] = changed
        try:
            validate_report(mutation, verify_files=False)
        except ClosureFailure:
            mutation_rejection_count += 1
    for key, changed in (
        ("repair_id", "QSDK-R10E-L1"),
        (
            "superseded_physical_supervisor_refusal_sha256",
            "sha256:" + "9" * 64,
        ),
        ("l2_held_out_failure_closure_sha256", "sha256:" + "9" * 64),
    ):
        mutation = json.loads(json.dumps(fixtures[0]))
        mutation["source"][key] = changed
        try:
            validate_report(mutation, verify_files=False)
        except ClosureFailure:
            mutation_rejection_count += 1
    require(valid_count == 7, "SELF_TEST_VALID_COUNT")
    require(mutation_rejection_count == 22, "SELF_TEST_MUTATION_COUNT")
    require(
        classifications
        == [
            "valid_complete_behavior_positive",
            "valid_complete_behavior_finite_negative",
            "valid_complete_behavior_positive",
            "valid_complete_behavior_finite_negative",
            "invalid_or_incomplete_no_behavioral_conclusion",
            "invalid_or_incomplete_no_behavioral_conclusion",
            "invalid_or_incomplete_no_behavioral_conclusion",
        ],
        "SELF_TEST_CLASSIFICATIONS",
    )
    return {
        "schema_version": "sporespore_qsdk_r10e_physical_closure_self_test_v1",
        "gate_id": "QSDK-R10E",
        "ledger_scope": ledger_scope(
            "development", "zero_world_physical_closure_self_test"
        ),
        "ok": True,
        "failure_code": "",
        "synthetic_report_control_count": valid_count,
        "report_mutation_rejection_count": mutation_rejection_count,
        "classifications": classifications,
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
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("self-test")
    audit_parser = subparsers.add_parser("audit-report")
    audit_parser.add_argument("--report", required=True, type=Path)
    compile_parser = subparsers.add_parser("compile")
    compile_parser.add_argument("--report", required=True, type=Path)
    compile_parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()
    try:
        if arguments.command == "self-test":
            receipt = self_test()
            print(
                SELF_TEST_MARKER
                + json.dumps(receipt, sort_keys=True, separators=(",", ":"))
            )
            return 0
        report_path = arguments.report.resolve()
        report = read_json(report_path, "REPORT")
        outcome = validate_report(report, verify_files=True, report_path=report_path)
        if arguments.command == "audit-report":
            receipt = {
                "schema_version": "sporespore_qsdk_r10e_physical_report_audit_v1",
                "gate_id": "QSDK-R10E",
                "ledger_scope": ledger_scope(
                    str(report["question_class"]), "zero_world_physical_report_audit"
                ),
                "ok": True,
                "failure_code": "",
                "report_path": str(report_path),
                "report_raw_sha256": sha256_file(report_path),
                "outcome": outcome,
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "native_readback_count": 0,
                "solver_step_count": 0,
                "physics_state_modified": False,
                "physical_acceptance_authority": False,
                "release_authority": False,
            }
            print(
                AUDIT_MARKER
                + json.dumps(receipt, sort_keys=True, separators=(",", ":"))
            )
            return 0
        expected_output = ROOT / str(
            role_spec(str(report["campaign_role"]))["closure_path"]
        )
        require(
            arguments.output.resolve() == expected_output.resolve(),
            "CLOSURE_OUTPUT_PATH",
        )
        closure = build_closure(report_path, report, outcome)
        write_new_json(expected_output, closure)
        receipt = {
            "schema_version": "sporespore_qsdk_r10e_physical_closure_compilation_v1",
            "gate_id": "QSDK-R10E",
            "ledger_scope": ledger_scope(
                str(report["question_class"]), "zero_world_closure_compilation"
            ),
            "ok": True,
            "failure_code": "",
            "output_path": expected_output.relative_to(ROOT).as_posix(),
            "output_byte_length": expected_output.stat().st_size,
            "output_raw_sha256": sha256_file(expected_output),
            "classification": outcome["classification"],
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "native_readback_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        print(
            COMPILED_MARKER + json.dumps(receipt, sort_keys=True, separators=(",", ":"))
        )
        return 0
    except ClosureFailure as exc:
        print(f"QSDK_R10E_PHYSICAL_CLOSURE_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
