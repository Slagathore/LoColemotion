#!/usr/bin/env python3
"""Strict R24D14 evaluator specialization for exact native float projections.

R24D13 remains immutable. This distinct evaluator reuses its complete report
contract while replacing only the campaign identity and the two adjacent
binary64 values that the actual native readback/telemetry paths produce.
"""

from __future__ import annotations

import argparse
import copy
import importlib.util
import json
import struct
from pathlib import Path
from types import ModuleType
from typing import Any


HERE = Path(__file__).resolve().parent
BASE_PATH = HERE / "r24d13_godot_jolt_braking_mechanism_activation_evaluator.py"
GATE_ID = "QSDK-R24D14"
RAW_SCHEMA = "sporespore_qsdk_r24d14_godot_jolt_braking_mechanism_activation_raw_report_v1"
EVALUATION_SCHEMA = "sporespore_qsdk_r24d14_godot_jolt_braking_mechanism_activation_evaluation_v1"
FIXTURE_ID = "QSDK.R24D14.godot_jolt_braking_mechanism_activation.v1"
EXPECTED_NATIVE_IMPULSE = struct.unpack("<f", bytes.fromhex("6f12033b"))[0]
EXPECTED_NATIVE_TIMESTEP = struct.unpack("<f", bytes.fromhex("8988083c"))[0]
REJECTED_R24D13_IMPULSE = float("0.0020000000949949")
REJECTED_R24D13_TIMESTEP = float("0.00833333376795053")


def load_base() -> ModuleType:
    spec = importlib.util.spec_from_file_location("qsdk_r24d13_evaluator_base", BASE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("R24D14_BASE_EVALUATOR_IMPORT")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.GATE_ID = GATE_ID
    module.RAW_SCHEMA = RAW_SCHEMA
    module.EVALUATION_SCHEMA = EVALUATION_SCHEMA
    module.FIXTURE_ID = FIXTURE_ID
    module.EXPECTED_REAL_T_IMPULSE = EXPECTED_NATIVE_IMPULSE
    module.EXPECTED_DT = EXPECTED_NATIVE_TIMESTEP
    return module


BASE = load_base()
EvaluationError = BASE.EvaluationError


def require(condition: bool, code: str) -> None:
    if not condition:
        raise EvaluationError(code)


def binary64_hex(value: float) -> str:
    return struct.pack(">d", value).hex()


def set_path(value: dict[str, Any], path: tuple[Any, ...], replacement: Any) -> None:
    target: Any = value
    for part in path[:-1]:
        target = target[part]
    target[path[-1]] = replacement


def evaluate_file(
    input_path: Path,
    output_path: Path,
    expected_evidence_kind: str,
    expected_source_commit: str,
    expected_nonce: str,
) -> dict[str, Any]:
    report = BASE.load_report(input_path)
    evaluation = BASE.evaluate(
        report,
        expected_evidence_kind=expected_evidence_kind,
        expected_source_commit=expected_source_commit,
        expected_nonce=expected_nonce,
    )
    BASE.write_json(output_path, evaluation)
    return evaluation


def self_test() -> tuple[int, int]:
    require(struct.pack("<f", EXPECTED_NATIVE_IMPULSE).hex() == "6f12033b", "IMPULSE_BINARY32")
    require(binary64_hex(EXPECTED_NATIVE_IMPULSE) == "3f60624de0000000", "IMPULSE_BINARY64")
    require(struct.pack("<f", EXPECTED_NATIVE_TIMESTEP).hex() == "8988083c", "TIMESTEP_BINARY32")
    require(binary64_hex(EXPECTED_NATIVE_TIMESTEP) == "3f81111120000000", "TIMESTEP_BINARY64")
    require(binary64_hex(REJECTED_R24D13_IMPULSE) == "3f60624ddffffffa", "OLD_IMPULSE_BINARY64")
    require(binary64_hex(REJECTED_R24D13_TIMESTEP) == "3f8111111ffffffd", "OLD_TIMESTEP_BINARY64")
    require(EXPECTED_NATIVE_IMPULSE != REJECTED_R24D13_IMPULSE, "IMPULSE_ADJACENCY")
    require(EXPECTED_NATIVE_TIMESTEP != REJECTED_R24D13_TIMESTEP, "TIMESTEP_ADJACENCY")

    source = "1" * 40
    nonce = "2" * 32
    synthetic = BASE.synthetic_report(source, nonce)
    result = BASE.evaluate(
        synthetic,
        expected_evidence_kind="synthetic_zero_world",
        expected_source_commit=source,
        expected_nonce=nonce,
    )
    require(result["result"] == "synthetic_shape_conforms_zero_world_only", "SYNTHETIC_RESULT")

    invalid_cases: list[tuple[str, tuple[Any, ...], Any]] = [
        ("old_impulse", ("cells", 0, "parameter_readback", "public_maximum_motor_impulse_nms"), REJECTED_R24D13_IMPULSE),
        ("authored_impulse", ("cells", 0, "parameter_readback", "public_maximum_motor_impulse_nms"), 0.002),
        ("old_timestep", ("cells", 0, "samples", 0, "telemetry", "solver_step_s"), REJECTED_R24D13_TIMESTEP),
        ("authored_timestep", ("cells", 0, "samples", 0, "telemetry", "solver_step_s"), 1.0 / 120.0),
        ("schema", ("schema_version",), "mutated"),
        ("gate", ("gate_id",), "QSDK-MUTATED"),
        ("source", ("source_commit",), "0" * 40),
        ("nonce", ("execution_nonce",), "0" * 32),
        ("fixture", ("fixture", "fixture_id"), "mutated"),
        ("runtime", ("runtime_provenance", "combined_patch_raw_sha256"), "sha256:" + "0" * 64),
        ("step_count", ("execution", "physics_step_count"), 2),
        ("authority", ("claims", "release_authority"), True),
    ]
    rejected = 0
    for case_id, path, replacement in invalid_cases:
        mutated = copy.deepcopy(synthetic)
        set_path(mutated, path, replacement)
        try:
            BASE.evaluate(
                mutated,
                expected_evidence_kind="synthetic_zero_world",
                expected_source_commit=source,
                expected_nonce=nonce,
            )
        except EvaluationError:
            rejected += 1
        else:
            raise EvaluationError(f"INVALID_MUTATION_ACCEPTED:{case_id}")

    physical_negative = BASE.synthetic_report(source, nonce, "native_physical")
    for cell in physical_negative["cells"][:2]:
        telemetry = cell["samples"][0]["telemetry"]
        telemetry["signed_motor_impulse_nms"] = 0.0
        telemetry["absorbed_motor_work_j"] = 0.0
        telemetry["net_motor_work_j"] = 0.0
    negative = BASE.evaluate(
        physical_negative,
        expected_evidence_kind="native_physical",
        expected_source_commit=source,
        expected_nonce=nonce,
    )
    require(negative["result"].endswith("_negative"), "ADVERSE_RESULT")
    return rejected, 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--expected-evidence-kind", choices=("synthetic_zero_world", "native_physical"))
    parser.add_argument("--expected-source-commit")
    parser.add_argument("--expected-nonce")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        rejected, adverse = self_test()
        print(
            "QSDK_R24D14_EVALUATOR_SELF_TEST_PASS "
            f"invalid_mutations={rejected} accepted_adverse_outcomes={adverse} "
            "worlds=0 builds=0 solver_steps=0"
        )
        return 0
    require(args.input is not None and args.output is not None, "CLI_INPUT_OUTPUT")
    require(args.expected_evidence_kind is not None, "CLI_EVIDENCE_KIND")
    require(bool(args.expected_source_commit) and len(args.expected_source_commit) == 40, "CLI_SOURCE_COMMIT")
    require(bool(args.expected_nonce) and len(args.expected_nonce) == 32, "CLI_NONCE")
    evaluation = evaluate_file(
        args.input,
        args.output,
        args.expected_evidence_kind,
        args.expected_source_commit,
        args.expected_nonce,
    )
    print(
        "QSDK_R24D14_EVALUATION "
        f"ok=true result={evaluation['result']} "
        f"enabled_witnesses={evaluation['summary']['motor_enabled_braking_witness_count']}/2 "
        f"disabled_zero={evaluation['summary']['motor_disabled_zero_witness_count']}/2"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except EvaluationError as error:
        print(f"QSDK_R24D14_EVALUATION_FAILURE code={error}")
        raise SystemExit(1)
