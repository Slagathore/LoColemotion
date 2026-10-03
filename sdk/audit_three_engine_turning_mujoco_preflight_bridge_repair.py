"""Executable zero-world audit for the MuJoCo preflight bridge repair."""

from __future__ import annotations

import ast
import hashlib
import importlib.util
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
RECORD = ROOT / "sdk/turning/three_engine_turning_mujoco_preflight_bridge_repair_v1.json"
PREDECESSOR_AUDIT = ROOT / "sdk/audit_r23d76_bounded_native_smoke_v2_attempt1.py"
MUJOCO_ROOT = ROOT / "sdk/adapters/mujoco"
MARKER = "TURNING_MUJOCO_PREFLIGHT_BRIDGE_REPAIR "


class RepairAuditError(RuntimeError):
    pass


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise RepairAuditError(f"TURNING_MUJOCO_BRIDGE_REPAIR_{code}")


def _sha(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _load_module() -> Any:
    spec = importlib.util.spec_from_file_location("_r23d76_smoke_v2_attempt1_audit", PREDECESSOR_AUDIT)
    _require(spec is not None and spec.loader is not None, "PREDECESSOR_IMPORT_INVALID")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def audit() -> dict[str, Any]:
    record = json.loads(RECORD.read_text(encoding="utf-8"))
    _require(
        record.get("schema_version")
        == "sporespore_three_engine_turning_mujoco_preflight_bridge_repair_v1",
        "SCHEMA_INVALID",
    )
    predecessor = _load_module().audit()
    _require(
        predecessor.get("passed") is True
        and predecessor.get("bounded_native_smoke_passed") is False,
        "PREDECESSOR_AUDIT_INVALID",
    )
    negative = record["predecessor_negative"]
    closure_path = ROOT / negative["closure_path"]
    _require(_sha(closure_path.read_bytes()) == negative["closure_raw_sha256"], "CLOSURE_DRIFT")

    repair = record["repair"]
    source_path = ROOT / repair["source_path"]
    current_source = source_path.read_bytes()
    old_source = subprocess.check_output(
        ["git", "-C", str(ROOT), "show", f"{negative['source_commit']}:{repair['source_path']}"]
    )
    _require(
        len(old_source) == repair["old_byte_length"]
        and _sha(old_source) == repair["old_raw_sha256"],
        "OLD_SOURCE_INVALID",
    )
    _require(
        len(current_source) == repair["new_byte_length"]
        and _sha(current_source) == repair["new_raw_sha256"],
        "NEW_SOURCE_INVALID",
    )
    parsed = ast.parse(current_source.decode("utf-8"))
    functions = [
        node
        for node in parsed.body
        if isinstance(node, ast.FunctionDef) and node.name == repair["source_symbol"]
    ]
    _require(
        len(functions) == 1
        and functions[0].args.kwarg is not None
        and functions[0].args.kwarg.arg == "_kwargs",
        "KEYWORD_SINK_INVALID",
    )
    for field in (
        "threshold_changed",
        "seed_changed",
        "selector_changed",
        "evaluator_changed",
        "horizon_changed",
        "terminal_schema_changed",
        "behavior_interpretation_changed",
    ):
        _require(repair.get(field) is False, "FORBIDDEN_CHANGE:" + field)

    regression = record["zero_world_regression"]
    test_path = ROOT / regression["test_path"]
    current_test = test_path.read_bytes()
    old_test = subprocess.check_output(
        ["git", "-C", str(ROOT), "show", f"{negative['source_commit']}:{regression['test_path']}"]
    )
    _require(
        len(old_test) == regression["old_byte_length"]
        and _sha(old_test) == regression["old_raw_sha256"]
        and len(current_test) == regression["new_byte_length"]
        and _sha(current_test) == regression["new_raw_sha256"],
        "TEST_SOURCE_INVALID",
    )
    process = subprocess.run(
        [
            str(MUJOCO_ROOT / ".venv/Scripts/python.exe"),
            "-m",
            "unittest",
            "sporespore_mujoco_adapter.turning_three_engine_route_test",
            "-v",
        ],
        cwd=MUJOCO_ROOT,
        capture_output=True,
        check=False,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=120,
    )
    output = process.stdout + process.stderr
    _require(
        process.returncode == 0
        and "Ran 7 tests" in output
        and regression["test_name"] in output,
        "ZERO_WORLD_REGRESSION_FAILED",
    )
    _require(
        all(regression.get(field) == 0 for field in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
        ))
        and regression.get("physical_execution_authorized") is False,
        "ZERO_WORLD_COUNTS_INVALID",
    )
    return {
        "schema_version": "sporespore_three_engine_turning_mujoco_preflight_bridge_repair_audit_v1",
        "repair_id": record["repair_id"],
        "passed": True,
        "test_count": 7,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_successor_opened": False,
        "physical_acceptance_authority": False,
    }


if __name__ == "__main__":
    try:
        print(MARKER + json.dumps(audit(), sort_keys=True, separators=(",", ":")))
    except (RepairAuditError, OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(f"{MARKER}{type(error).__name__}:{error}") from error
