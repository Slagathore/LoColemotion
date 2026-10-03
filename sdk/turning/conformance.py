"""Compile H0-H8 public heading-command source conformance."""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable

try:
    from sporespore_locomotion import (
        LocomotionCore,
        LocomotionCoreError,
        SELECTED_BALANCED_WAVE_POLICY_ID,
        reference_quadruped,
    )
except ImportError:
    from python.sporespore_locomotion import (
        LocomotionCore,
        LocomotionCoreError,
        SELECTED_BALANCED_WAVE_POLICY_ID,
        reference_quadruped,
    )

from examples.reference_quadruped import build_reference_request


SDK_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = SDK_ROOT.parent
CONTRACT_PATH = Path(__file__).resolve().with_name(
    "heading_command_contract_v1.json"
)
REPORT_SCHEMA = "sporespore_heading_command_turning_conformance_report_v1"
CONTRACT_ID = "sporespore_bounded_heading_command_source_v1"
EXPECTED_POLICY = "sporespore_balanced_wave_bw5r_b_v1"
EXPECTED_CELL_COUNT = 9


class HeadingCommandConformanceFailure(RuntimeError):
    """One heading-command source invariant failed."""


def _require(condition: bool, code: str, detail: str = "") -> None:
    if not condition:
        raise HeadingCommandConformanceFailure(f"{code}:{detail}")


def _near(left: float, right: float, tolerance: float = 1.0e-12) -> bool:
    return math.isclose(left, right, rel_tol=0.0, abs_tol=tolerance)


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return f"sha256:{digest.hexdigest()}"


def _git(*arguments: str) -> tuple[bool, str]:
    result = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return result.returncode == 0, result.stdout.strip()


def _source_receipt() -> dict[str, Any]:
    head_ok, head = _git("rev-parse", "HEAD")
    origin_ok, origin = _git("rev-parse", "origin/main")
    status_ok, status = _git(
        "status",
        "--porcelain=v1",
        "--untracked-files=all",
    )
    return {
        "commit": head if head_ok else None,
        "origin_main": origin if origin_ok else None,
        "clean": status_ok and status == "",
        "matches_origin_main": head_ok and origin_ok and head == origin,
        "status_entries": status.splitlines() if status else [],
    }


def _load_contract() -> dict[str, Any]:
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    _require(
        contract.get("schema_version")
        == "sporespore_heading_command_turning_contract_v1",
        "HEADING_CONTRACT_SCHEMA",
    )
    _require(contract.get("contract_id") == CONTRACT_ID, "HEADING_CONTRACT_ID")
    return contract


def _fixture(
    core: LocomotionCore,
    *,
    descriptor: dict[str, Any] | None = None,
    heading_rad: float | None = 0.0,
    yaw_rate_rad_s: float | None = None,
    semantic_step: int = 0,
) -> tuple[dict[str, Any], dict[str, Any]]:
    selected_descriptor = descriptor or reference_quadruped(
        "heading_command_conformance"
    )
    compiled = core.compile_bounded_quadruped(selected_descriptor)
    request = build_reference_request(
        descriptor=selected_descriptor,
        morphology=compiled["morphology"],
        memory=core.balanced_wave_policy_initial_memory(
            SELECTED_BALANCED_WAVE_POLICY_ID,
            selected_descriptor,
        ),
        semantic_step=semantic_step,
    )
    request["command"]["command_id"] = "heading_command_conformance"
    request["command"]["desired_heading_rad"] = heading_rad
    request["command"]["desired_yaw_rate_rad_s"] = yaw_rate_rad_s
    return request, compiled["morphology"]


def _step(core: LocomotionCore, request: dict[str, Any]) -> dict[str, Any]:
    return core.balanced_wave_policy_step(
        SELECTED_BALANCED_WAVE_POLICY_ID,
        request,
    )


def _assert_active(output: dict[str, Any], code: str) -> None:
    actuation = output["actuation"]
    _require(actuation["safe_no_actuation"] is False, f"{code}_SAFE_ZERO")
    _require(actuation["failure_codes"] == [], f"{code}_FAILURES")
    _require(actuation["world_build_count"] == 0, f"{code}_WORLD_COUNT")
    _require(
        actuation["physical_acceptance_authority"] is False,
        f"{code}_PHYSICAL_AUTHORITY",
    )
    _require(
        actuation["receipt"]["physical_acceptance_authority"] is False,
        f"{code}_RECEIPT_AUTHORITY",
    )


def _assert_safe_zero(
    output: dict[str, Any],
    expected_failure: str,
    expected_detail: str,
    code: str,
) -> None:
    actuation = output["actuation"]
    _require(actuation["safe_no_actuation"] is True, f"{code}_NOT_SAFE_ZERO")
    _require(
        actuation["failure_codes"] == [expected_failure],
        f"{code}_FAILURE_CODE",
    )
    _require(len(actuation["ordered_commands"]) == 8, f"{code}_ORDER_COUNT")
    for command in actuation["ordered_commands"]:
        for field in (
            "requested_target_position_rad",
            "clamped_target_position_rad",
            "target_velocity_rad_s",
            "residual_contribution_rad_s",
            "safety_contribution_rad_s",
        ):
            _require(command[field] == 0.0, f"{code}_NONZERO", field)
    receipt = actuation["receipt"]
    _require(
        receipt["controller_error"] == f"{expected_failure}:{expected_detail}",
        f"{code}_ERROR_DETAIL",
    )
    _require(actuation["world_build_count"] == 0, f"{code}_WORLD_COUNT")
    _require(
        actuation["physical_acceptance_authority"] is False,
        f"{code}_PHYSICAL_AUTHORITY",
    )


def _all_finite(value: Any) -> bool:
    if isinstance(value, float):
        return math.isfinite(value)
    if isinstance(value, dict):
        return all(_all_finite(item) for item in value.values())
    if isinstance(value, list):
        return all(_all_finite(item) for item in value)
    return True


def _cell_h0_contract(core: LocomotionCore) -> dict[str, Any]:
    contract = _load_contract()
    _require(contract["selected_policy_id"] == EXPECTED_POLICY, "H0_POLICY")
    _require(
        len(contract["conformance_cells"]) == EXPECTED_CELL_COUNT,
        "H0_CELL_COUNT",
    )
    _require(
        contract["release_boundary"]["source_conformance_may_satisfy_qsdk_r23"]
        is False,
        "H0_RELEASE_BOUNDARY",
    )
    _require(contract["world_build_count"] == 0, "H0_WORLD_COUNT")
    _require(contract["turning_acceptance"] is False, "H0_TURNING_AUTHORITY")
    _require(
        contract["physical_acceptance_authority"] is False,
        "H0_PHYSICAL_AUTHORITY",
    )
    return {
        "cell_id": "h0_contract_and_authority",
        "passed": True,
        "contract_id": CONTRACT_ID,
        "contract_canonical_sha256": core.canonicalize_json(contract)["sha256"],
        "world_build_count": 0,
        "turning_acceptance": False,
        "physical_acceptance_authority": False,
    }


def _cell_h1_zero_compatibility(core: LocomotionCore) -> dict[str, Any]:
    implicit_request, _ = _fixture(core, heading_rad=None)
    explicit_request, _ = _fixture(core, heading_rad=0.0)
    implicit = _step(core, implicit_request)
    explicit = _step(core, explicit_request)
    _assert_active(implicit, "H1_IMPLICIT")
    _assert_active(explicit, "H1_EXPLICIT")
    _require(implicit == explicit, "H1_NOT_EXACT")
    digest = core.canonicalize_json(implicit)["sha256"]
    return {
        "cell_id": "h1_exact_zero_command_compatibility",
        "passed": True,
        "implicit_reference_hold_sha256": digest,
        "explicit_reference_heading_sha256": digest,
        "exact_output_equal": True,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_h2_signed_mirror(core: LocomotionCore) -> dict[str, Any]:
    zero = _step(core, _fixture(core, heading_rad=0.0)[0])
    positive = _step(core, _fixture(core, heading_rad=0.2)[0])
    negative = _step(core, _fixture(core, heading_rad=-0.2)[0])
    for label, output in (("ZERO", zero), ("POS", positive), ("NEG", negative)):
        _assert_active(output, f"H2_{label}")
    pos_receipt = positive["actuation"]["receipt"]
    neg_receipt = negative["actuation"]["receipt"]
    _require(
        _near(
            pos_receipt["desired_heading_error_rad"],
            -neg_receipt["desired_heading_error_rad"],
        ),
        "H2_HEADING_NOT_MIRRORED",
    )
    _require(
        _near(
            pos_receipt["requested_steering_fraction"],
            -neg_receipt["requested_steering_fraction"],
        ),
        "H2_REQUEST_NOT_MIRRORED",
    )
    _require(
        _near(
            pos_receipt["held_steering_fraction"],
            -neg_receipt["held_steering_fraction"],
        ),
        "H2_HELD_NOT_MIRRORED",
    )
    zero_commands = {
        command["actuator_id"]: command
        for command in zero["actuation"]["ordered_commands"]
    }
    for output in (positive, negative):
        held = output["actuation"]["receipt"]["held_steering_fraction"]
        for command in output["actuation"]["ordered_commands"]:
            actuator_id = command["actuator_id"]
            baseline = zero_commands[actuator_id]
            if "_hip_" not in actuator_id:
                _require(command == baseline, "H2_KNEE_CHANGED", actuator_id)
                continue
            side_sign = -1.0 if "_left_" in actuator_id else 1.0
            expected_scale = 1.0 + side_sign * held
            for field in (
                "requested_target_position_rad",
                "clamped_target_position_rad",
                "target_velocity_rad_s",
            ):
                _require(
                    _near(command[field], baseline[field] * expected_scale),
                    "H2_STRIDE_SCALE",
                    f"{actuator_id}.{field}",
                )
    return {
        "cell_id": "h2_signed_mirror_and_bilateral_stride",
        "passed": True,
        "positive_requested_steering_fraction": pos_receipt[
            "requested_steering_fraction"
        ],
        "positive_held_steering_fraction": pos_receipt[
            "held_steering_fraction"
        ],
        "signed_mirror_passed": True,
        "bilateral_stride_transform_passed": True,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_h3_bounds(core: LocomotionCore) -> dict[str, Any]:
    observed: list[dict[str, float | bool]] = []
    for heading, expected_error, expected_request in (
        (2.0, 0.25, -0.325),
        (-2.0, -0.25, 0.325),
    ):
        output = _step(core, _fixture(core, heading_rad=heading)[0])
        _assert_active(output, "H3")
        receipt = output["actuation"]["receipt"]
        _require(
            _near(receipt["desired_heading_error_rad"], expected_error),
            "H3_HEADING_CLAMP",
        )
        _require(
            _near(receipt["requested_steering_fraction"], expected_request),
            "H3_STEERING_REQUEST",
        )
        _require(
            abs(receipt["requested_steering_fraction"]) <= 0.4,
            "H3_REQUEST_BOUND",
        )
        _require(
            abs(receipt["held_steering_fraction"]) <= 0.4,
            "H3_HELD_BOUND",
        )
        observed.append(
            {
                "input_heading_rad": heading,
                "desired_heading_error_rad": receipt[
                    "desired_heading_error_rad"
                ],
                "requested_steering_fraction": receipt[
                    "requested_steering_fraction"
                ],
                "held_steering_fraction": receipt["held_steering_fraction"],
                "steering_saturated": receipt["steering_saturated"],
            }
        )
    return {
        "cell_id": "h3_heading_and_steering_bounds",
        "passed": True,
        "observed": observed,
        "desired_heading_error_limit_rad": 0.25,
        "steering_fraction_limit": 0.4,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_h4_wrapping(core: LocomotionCore) -> dict[str, Any]:
    reference = math.pi - 0.05
    desired = -math.pi + 0.05
    request, _ = _fixture(core, heading_rad=desired)
    request["state"]["task_frame"]["reference_yaw_rad"] = reference
    request["state"]["base_pose_world"]["orientation_xyzw"] = {
        "x": 0.0,
        "y": -math.sin(reference / 2.0),
        "z": 0.0,
        "w": math.cos(reference / 2.0),
    }
    output = _step(core, request)
    _assert_active(output, "H4")
    receipt = output["actuation"]["receipt"]
    _require(_near(receipt["measured_yaw_error_rad"], 0.0), "H4_POSE")
    _require(
        _near(receipt["desired_heading_error_rad"], 0.1),
        "H4_SHORTEST_ARC",
    )
    _require(
        _near(receipt["requested_steering_fraction"], -0.13),
        "H4_STEERING",
    )
    return {
        "cell_id": "h4_shortest_arc_wrapping",
        "passed": True,
        "reference_yaw_rad": reference,
        "desired_heading_rad": desired,
        "wrapped_heading_error_rad": receipt["desired_heading_error_rad"],
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_h5_mutual_exclusion(core: LocomotionCore) -> dict[str, Any]:
    request, _ = _fixture(core, heading_rad=0.1, yaw_rate_rad_s=0.1)
    output = _step(core, request)
    _assert_safe_zero(
        output,
        "SCHEMA_INVALID",
        "heading_and_yaw_rate_both_present",
        "H5",
    )
    return {
        "cell_id": "h5_mutually_exclusive_mode_safe_zero",
        "passed": True,
        "failure_code": "SCHEMA_INVALID",
        "ordered_safe_zero_command_count": 8,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_h6_yaw_rate_refusal(core: LocomotionCore) -> dict[str, Any]:
    request, _ = _fixture(core, heading_rad=None, yaw_rate_rad_s=0.1)
    output = _step(core, request)
    _assert_safe_zero(
        output,
        "CAPABILITY_UNSUPPORTED",
        "balanced_wave_yaw_rate_command",
        "H6",
    )
    return {
        "cell_id": "h6_unsupported_yaw_rate_safe_zero",
        "passed": True,
        "failure_code": "CAPABILITY_UNSUPPORTED",
        "ordered_safe_zero_command_count": 8,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_h7_session_equivalence(core: LocomotionCore) -> dict[str, Any]:
    request, _ = _fixture(core, heading_rad=0.2)
    stateless = _step(core, request)
    session_request = {
        key: value
        for key, value in request.items()
        if key not in ("descriptor", "policy_id")
    }
    with core.create_balanced_wave_policy_session(
        SELECTED_BALANCED_WAVE_POLICY_ID,
        request["descriptor"],
    ) as session:
        persistent = session.step(session_request)
    _require(stateless == persistent, "H7_OUTPUT_MISMATCH")
    digest = core.canonicalize_json(stateless)["sha256"]
    return {
        "cell_id": "h7_stateless_persistent_session_equivalence",
        "passed": True,
        "stateless_output_sha256": digest,
        "persistent_output_sha256": digest,
        "exact_output_equal": True,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_h8_vertices(core: LocomotionCore) -> dict[str, Any]:
    contract = _load_contract()
    dimensions = contract["bounded_descriptor_vertex_fixture"]["dimensions"]
    names = list(dimensions)
    expected_count = contract["bounded_descriptor_vertex_fixture"][
        "expected_vertex_count"
    ]
    output_digests: list[str] = []
    for index, values in enumerate(
        itertools.product(*(dimensions[name] for name in names))
    ):
        descriptor = {
            "schema_version": "sporespore_bounded_quadruped_descriptor_v1",
            "morphology_id": f"heading_vertex_{index:02d}",
            **dict(zip(names, values, strict=True)),
        }
        request, morphology = _fixture(
            core,
            descriptor=descriptor,
            heading_rad=0.2,
        )
        output = _step(core, request)
        _assert_active(output, "H8")
        _require(_all_finite(output), "H8_NONFINITE", str(index))
        observed_ids = [
            command["actuator_id"]
            for command in output["actuation"]["ordered_commands"]
        ]
        _require(
            observed_ids == morphology["ordered_actuator_ids"],
            "H8_ACTUATOR_ORDER",
            str(index),
        )
        receipt = output["actuation"]["receipt"]
        _require(
            abs(receipt["desired_heading_error_rad"]) <= 0.25,
            "H8_HEADING_BOUND",
            str(index),
        )
        _require(
            abs(receipt["requested_steering_fraction"]) <= 0.4,
            "H8_STEERING_BOUND",
            str(index),
        )
        output_digests.append(core.canonicalize_json(output)["sha256"])
    _require(len(output_digests) == expected_count, "H8_VERTEX_COUNT")
    digest_set = core.canonicalize_json(output_digests)["sha256"]
    return {
        "cell_id": "h8_all_bounded_descriptor_vertices",
        "passed": True,
        "vertex_count": len(output_digests),
        "ordered_output_digest_set_sha256": digest_set,
        "continuous_interior_authority": False,
        "physical_population_authority": False,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _run_cell(
    callback: Callable[[LocomotionCore], dict[str, Any]],
    core: LocomotionCore,
) -> dict[str, Any]:
    try:
        return callback(core)
    except (HeadingCommandConformanceFailure, LocomotionCoreError) as error:
        return {
            "cell_id": callback.__name__.removeprefix("_cell_"),
            "passed": False,
            "failure": str(error),
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }


def run_heading_command_conformance() -> dict[str, Any]:
    core = LocomotionCore()
    callbacks = [
        _cell_h0_contract,
        _cell_h1_zero_compatibility,
        _cell_h2_signed_mirror,
        _cell_h3_bounds,
        _cell_h4_wrapping,
        _cell_h5_mutual_exclusion,
        _cell_h6_yaw_rate_refusal,
        _cell_h7_session_equivalence,
        _cell_h8_vertices,
    ]
    cells = [_run_cell(callback, core) for callback in callbacks]
    passed = sum(cell["passed"] is True for cell in cells)
    failed = len(cells) - passed
    return {
        "schema_version": REPORT_SCHEMA,
        "ok": failed == 0,
        "contract_id": CONTRACT_ID,
        "release_gate_id": "QSDK-R23",
        "release_gate_satisfied": False,
        "source": _source_receipt(),
        "core": {
            "version": core.version,
            "library_path_execution_only": str(core.library_path),
            "library_sha256": _file_sha256(core.library_path),
        },
        "contract_file_sha256": _file_sha256(CONTRACT_PATH),
        "cells": cells,
        "passed_cells": passed,
        "failed_cells": failed,
        "zero_command_source_compatibility_passed": failed == 0,
        "bounded_heading_source_mechanism_passed": failed == 0,
        "public_c_abi_and_python_binding_exercised": True,
        "persistent_session_exercised": True,
        "descriptor_vertex_count": 64,
        "world_build_count": 0,
        "physics_state_modified": False,
        "commanded_turning_physical_campaign_executed": False,
        "walking_acceptance": False,
        "turning_acceptance": False,
        "physical_acceptance_authority": False,
        "completed_engine_neutral_sdk": False,
    }


def _retain_report(report: dict[str, Any], path: Path) -> None:
    _require(path.name == "report.json", "HEADING_REPORT_NAME_INVALID")
    _require(not path.exists(), "HEADING_REPORT_ALREADY_EXISTS", str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name("report.json.tmp")
    _require(
        not temporary.exists(),
        "HEADING_REPORT_TEMPORARY_EXISTS",
        str(temporary),
    )
    serialized = json.dumps(report, indent=2, allow_nan=False) + "\n"
    temporary.write_text(serialized, encoding="utf-8", newline="\n")
    os.replace(temporary, path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        report = run_heading_command_conformance()
        if not report["ok"]:
            raise HeadingCommandConformanceFailure("HEADING_CELLS_FAILED")
        if args.output is not None:
            output = args.output.resolve()
            _retain_report(report, output)
            print(f"retained heading-command report: {output}", file=sys.stderr)
        print(json.dumps(report, indent=2, allow_nan=False))
    except (
        HeadingCommandConformanceFailure,
        LocomotionCoreError,
        OSError,
        ValueError,
    ) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
