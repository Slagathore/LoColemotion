"""Compile the public optional-provider A0-A7 zero-world conformance report."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import struct
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable

try:
    from sporespore_locomotion import (
        LocomotionCore,
        LocomotionCoreError,
        SELECTED_BALANCED_WAVE_POLICY_ID,
    )
except ImportError:
    from python.sporespore_locomotion import (
        LocomotionCore,
        LocomotionCoreError,
        SELECTED_BALANCED_WAVE_POLICY_ID,
    )

from adapter_kit.reference_adapter import ReferenceHostAdapter


SDK_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = SDK_ROOT.parent
CONTRACT_PATH = Path(__file__).resolve().with_name("provider_contract_v1.json")
REPORT_SCHEMA = "sporespore_adaptation_provider_conformance_report_v1"
EMPTY_STATE_DIGEST = (
    "sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"
)


class AdaptationConformanceFailure(RuntimeError):
    """One optional-provider conformance invariant failed."""


def _require(condition: bool, code: str, detail: str = "") -> None:
    if not condition:
        raise AdaptationConformanceFailure(f"{code}:{detail}")


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
        == "sporespore_adaptation_provider_contract_v1",
        "ADAPTATION_CONTRACT_SCHEMA",
    )
    return contract


def _binary64_equal(left: float, right: float) -> bool:
    return struct.pack(">d", left) == struct.pack(">d", right)


def _provider_memory(provider_id: str = "conformance_provider") -> dict[str, Any]:
    return {
        "schema_version": "sporespore_adaptation_provider_memory_v1",
        "provider_id": provider_id,
        "reset_epoch": 0,
        "sequence": 0,
        "opaque_state": {},
        "opaque_state_sha256": EMPTY_STATE_DIGEST,
        "weights_mutated": False,
    }


def _fixture(core: LocomotionCore) -> dict[str, Any]:
    adapter = ReferenceHostAdapter(core)
    step_request = adapter.build_step_request(0)
    controller_output = core.balanced_wave_policy_step(
        SELECTED_BALANCED_WAVE_POLICY_ID,
        step_request,
    )
    actuation = controller_output["actuation"]
    _require(
        actuation["safe_no_actuation"] is False,
        "ADAPTATION_FIXTURE_SAFE_ZERO",
    )
    residuals = [
        {
            "schema_version": "sporespore_canonical_velocity_residual_v1",
            "actuator_id": command["actuator_id"],
            "canonical_velocity_delta_rad_s": 0.0,
            "command_not_measurement": True,
            "physical_acceptance_authority": False,
        }
        for command in actuation["ordered_commands"]
    ]
    baseline = core.canonical_velocity_compose_v1(
        {
            "schema_version": (
                "sporespore_canonical_velocity_compose_request_v1"
            ),
            "descriptor": adapter.descriptor,
            "source_actuation": actuation,
            "ordered_stability_residuals": residuals,
        }
    )
    provider_request = {
        "schema_version": "sporespore_adaptation_provider_request_v1",
        "request_id": "adaptation_conformance_request",
        "provider_id": "conformance_provider",
        "expected_provider_version": "conformance_provider_v1",
        "expected_model_id": "conformance_model",
        "expected_model_sha256": "sha256:" + "3" * 64,
        "expected_training_corpus_id": "conformance_corpus",
        "expected_training_corpus_sha256": "sha256:" + "4" * 64,
        "descriptor": adapter.descriptor,
        "state": step_request["state"],
        "command": step_request["command"],
        "deterministic_baseline": baseline,
        "controller_context": {
            "schema_version": "sporespore_adaptation_controller_context_v1",
            "source_policy_id": SELECTED_BALANCED_WAVE_POLICY_ID,
            "skill_id": "bounded_walk",
            "phase_id": None,
            "controller_memory_schema_version": controller_output[
                "next_memory"
            ]["schema_version"],
            "controller_memory": controller_output["next_memory"],
            "controller_memory_sha256": core.canonicalize_json(
                controller_output["next_memory"]
            )["sha256"],
            "engine_specific": False,
            "physical_acceptance_authority": False,
        },
        "history": {
            "schema_version": "sporespore_adaptation_history_v1",
            "ordered_entries": [],
        },
        "provider_memory": _provider_memory(),
        "safety_envelope": {
            "schema_version": "sporespore_adaptation_safety_envelope_v1",
            "correction_kind": "canonical_velocity_delta_rad_s",
            "minimum_confidence": 0.8,
            "maximum_support_distance": 1.0,
            "ordered_actuator_limits": [
                {
                    "actuator_id": command["actuator_id"],
                    "maximum_absolute_correction_rad_s": 0.5,
                    "maximum_slew_per_step_rad_s": 0.2,
                    "previous_applied_correction_rad_s": 0.0,
                }
                for command in baseline["ordered_commands"]
            ],
            "deterministic_baseline_fallback_required": True,
            "engine_specific_output_allowed": False,
            "direct_world_access_allowed": False,
            "safety_limit_override_allowed": False,
            "physical_acceptance_authority": False,
        },
        "seed": 7001,
        "provider_may_build_worlds": False,
        "provider_may_modify_physics_state": False,
        "provider_has_physical_acceptance_authority": False,
    }
    return {
        "schema_version": "sporespore_adaptation_resolution_request_v1",
        "provider_request": provider_request,
        "provider_response": None,
    }


def _response(
    core: LocomotionCore,
    resolution: dict[str, Any],
    *,
    status: str = "applied",
    confidence: float = 0.95,
    support_distance: float = 0.2,
    correction: float = 0.4,
    candidate: bool = False,
) -> dict[str, Any]:
    request = resolution["provider_request"]
    request_sha256 = core.canonicalize_json(request)["sha256"]
    next_opaque_state = {"conformance_sequence": 1}
    response = {
        "schema_version": "sporespore_adaptation_provider_response_v1",
        "request_id": request["request_id"],
        "request_sha256": request_sha256,
        "status": status,
        "confidence": confidence,
        "support_distance": support_distance,
        "ordered_corrections": (
            [
                {
                    "actuator_id": command["actuator_id"],
                    "canonical_velocity_delta_rad_s": correction,
                }
                for command in request["deterministic_baseline"][
                    "ordered_commands"
                ]
            ]
            if status == "applied"
            else []
        ),
        "next_memory": {
            "schema_version": "sporespore_adaptation_provider_memory_v1",
            "provider_id": request["provider_id"],
            "reset_epoch": request["provider_memory"]["reset_epoch"],
            "sequence": request["provider_memory"]["sequence"] + 1,
            "opaque_state": next_opaque_state,
            "opaque_state_sha256": core.canonicalize_json(next_opaque_state)[
                "sha256"
            ],
            "weights_mutated": False,
        },
        "provenance": {
            "provider_id": request["provider_id"],
            "provider_version": request["expected_provider_version"],
            "model_id": request["expected_model_id"],
            "model_sha256": request["expected_model_sha256"],
            "training_corpus_id": request[
                "expected_training_corpus_id"
            ],
            "training_corpus_sha256": request[
                "expected_training_corpus_sha256"
            ],
            "seed": request["seed"],
            "engine_specific_logic_used": False,
            "direct_world_access_used": False,
            "weights_mutated": False,
            "physical_acceptance_authority": False,
        },
        "candidate_experience": (
            {
                "schema_version": (
                    "sporespore_adaptation_candidate_experience_v1"
                ),
                "candidate_event_id": "conformance_candidate",
                "lesson_family_id": "bounded_residual",
                "candidate_only": True,
                "encyclopedia_promotion_authority": False,
                "physical_acceptance_authority": False,
            }
            if candidate
            else None
        ),
        "diagnostics": ["zero_world_conformance"],
        "physical_acceptance_authority": False,
    }
    return response


def _assert_exact_baseline(
    resolution: dict[str, Any], receipt: dict[str, Any]
) -> None:
    baseline = resolution["provider_request"]["deterministic_baseline"]
    _require(
        len(receipt["ordered_commands"]) == len(baseline["ordered_commands"]),
        "ADAPTATION_COMMAND_COUNT",
    )
    for resolved, original in zip(
        receipt["ordered_commands"], baseline["ordered_commands"], strict=True
    ):
        _require(
            resolved["actuator_id"] == original["actuator_id"],
            "ADAPTATION_COMMAND_ORDER",
        )
        _require(
            _binary64_equal(
                resolved["final_canonical_target_velocity_rad_s"],
                original["combined_canonical_target_velocity_rad_s"],
            ),
            "ADAPTATION_BASELINE_NOT_BIT_EXACT",
            resolved["actuator_id"],
        )
        _require(
            _binary64_equal(resolved["applied_correction_rad_s"], 0.0),
            "ADAPTATION_FALLBACK_HAS_CORRECTION",
            resolved["actuator_id"],
        )


def _cell_a0_contract(core: LocomotionCore) -> dict[str, Any]:
    contract = _load_contract()
    canonical = core.canonicalize_json(contract)
    _require(contract["provider_optional_at_runtime"] is True, "A0_OPTIONAL")
    _require(
        contract["trained_provider_required_for_first_public_release"] is False,
        "A0_TRAINED_PROVIDER_SCOPE",
    )
    _require(contract["world_build_count"] == 0, "A0_WORLD_COUNT")
    _require(
        contract["physical_acceptance_authority"] is False,
        "A0_PHYSICAL_AUTHORITY",
    )
    return {
        "cell_id": "a0_contract",
        "passed": True,
        "contract_id": contract["contract_id"],
        "contract_file_sha256": _file_sha256(CONTRACT_PATH),
        "contract_canonical_sha256": canonical["sha256"],
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_a1_absent_provider(core: LocomotionCore) -> dict[str, Any]:
    resolution = _fixture(core)
    for limit in resolution["provider_request"]["safety_envelope"][
        "ordered_actuator_limits"
    ]:
        limit["previous_applied_correction_rad_s"] = 0.4
    receipt = core.resolve_adaptation_v1(resolution)
    _require(receipt["fallback_reason"] == "provider_absent", "A1_REASON")
    _require(receipt["adaptation_applied"] is False, "A1_APPLIED")
    _assert_exact_baseline(resolution, receipt)
    return {
        "cell_id": "a1_absent_provider",
        "passed": True,
        "fallback_reason": receipt["fallback_reason"],
        "bit_exact_baseline_count": len(receipt["ordered_commands"]),
        "world_build_count": receipt["world_build_count"],
        "physical_acceptance_authority": receipt[
            "physical_acceptance_authority"
        ],
    }


def _cell_a2_bounded_application(core: LocomotionCore) -> dict[str, Any]:
    resolution = _fixture(core)
    resolution["provider_response"] = _response(core, resolution)
    receipt = core.resolve_adaptation_v1(resolution)
    _require(receipt["fallback_reason"] == "none", "A2_REASON")
    _require(receipt["adaptation_applied"] is True, "A2_NOT_APPLIED")
    _require(
        all(
            command["applied_correction_rad_s"] == 0.2
            and command["slew_clamped"] is True
            and abs(command["final_canonical_target_velocity_rad_s"])
            <= command["maximum_target_speed_rad_s"]
            for command in receipt["ordered_commands"]
        ),
        "A2_BOUNDS",
    )
    return {
        "cell_id": "a2_bounded_application",
        "passed": True,
        "applied_count": len(receipt["ordered_commands"]),
        "absolute_limit_rad_s": 0.5,
        "slew_limit_rad_s": 0.2,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_a3_confidence_and_support(core: LocomotionCore) -> dict[str, Any]:
    observed = []
    for confidence, distance, expected in (
        (0.5, 0.2, "confidence_below_minimum"),
        (0.95, 2.0, "outside_supported_domain"),
    ):
        resolution = _fixture(core)
        resolution["provider_response"] = _response(
            core,
            resolution,
            confidence=confidence,
            support_distance=distance,
        )
        receipt = core.resolve_adaptation_v1(resolution)
        _require(receipt["fallback_reason"] == expected, "A3_REASON")
        _assert_exact_baseline(resolution, receipt)
        observed.append(expected)
    return {
        "cell_id": "a3_confidence_and_support",
        "passed": True,
        "observed_fallback_reasons": observed,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_a4_invalid_and_stale(core: LocomotionCore) -> dict[str, Any]:
    invalid = _fixture(core)
    invalid["provider_response"] = {"surprise": True}
    invalid_receipt = core.resolve_adaptation_v1(invalid)
    _require(
        invalid_receipt["fallback_reason"] == "invalid_provider_response",
        "A4_INVALID_REASON",
    )
    _assert_exact_baseline(invalid, invalid_receipt)

    stale = _fixture(core)
    stale["provider_response"] = _response(core, stale)
    stale["provider_response"]["request_id"] = "different_request"
    stale_receipt = core.resolve_adaptation_v1(stale)
    _require(
        stale_receipt["fallback_reason"] == "request_identity_mismatch",
        "A4_STALE_REASON",
    )
    _assert_exact_baseline(stale, stale_receipt)

    unpinned = _fixture(core)
    unpinned["provider_response"] = _response(core, unpinned)
    unpinned["provider_response"]["provenance"]["model_id"] = "other_model"
    unpinned_receipt = core.resolve_adaptation_v1(unpinned)
    _require(
        unpinned_receipt["fallback_reason"] == "invalid_provider_response",
        "A4_UNPINNED_MODEL_REASON",
    )
    _assert_exact_baseline(unpinned, unpinned_receipt)
    return {
        "cell_id": "a4_invalid_and_stale",
        "passed": True,
        "observed_fallback_reasons": [
            invalid_receipt["fallback_reason"],
            stale_receipt["fallback_reason"],
            unpinned_receipt["fallback_reason"],
        ],
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_a5_refusal_and_reset(core: LocomotionCore) -> dict[str, Any]:
    refused = _fixture(core)
    refused["provider_response"] = _response(
        core, refused, status="refused"
    )
    refused_receipt = core.resolve_adaptation_v1(refused)
    _require(
        refused_receipt["fallback_reason"] == "provider_refused",
        "A5_REFUSED_REASON",
    )
    _assert_exact_baseline(refused, refused_receipt)

    reset = _fixture(core)
    reset_response = _response(core, reset, status="reset")
    reset_response["next_memory"] = _provider_memory()
    reset_response["next_memory"]["reset_epoch"] = 1
    reset["provider_response"] = reset_response
    reset_receipt = core.resolve_adaptation_v1(reset)
    _require(
        reset_receipt["fallback_reason"] == "provider_reset",
        "A5_RESET_REASON",
    )
    _require(reset_receipt["next_memory"]["reset_epoch"] == 1, "A5_EPOCH")
    _require(reset_receipt["next_memory"]["sequence"] == 0, "A5_SEQUENCE")
    _require(
        reset_receipt["next_memory"]["opaque_state_sha256"]
        == EMPTY_STATE_DIGEST,
        "A5_STATE_NOT_CLEARED",
    )
    return {
        "cell_id": "a5_refusal_and_reset",
        "passed": True,
        "observed_fallback_reasons": [
            refused_receipt["fallback_reason"],
            reset_receipt["fallback_reason"],
        ],
        "reset_epoch": reset_receipt["next_memory"]["reset_epoch"],
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_a6_candidate_only(core: LocomotionCore) -> dict[str, Any]:
    resolution = _fixture(core)
    resolution["provider_response"] = _response(
        core, resolution, candidate=True
    )
    receipt = core.resolve_adaptation_v1(resolution)
    candidate = receipt["candidate_experience"]
    _require(candidate["candidate_only"] is True, "A6_NOT_CANDIDATE")
    _require(
        candidate["encyclopedia_promotion_authority"] is False,
        "A6_PROMOTION_AUTHORITY",
    )
    _require(
        candidate["physical_acceptance_authority"] is False,
        "A6_PHYSICAL_AUTHORITY",
    )
    return {
        "cell_id": "a6_candidate_only",
        "passed": True,
        "candidate_event_id": candidate["candidate_event_id"],
        "encyclopedia_promotion_authority": False,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _expect_failure(
    callback: Callable[[], object], expected_code: str
) -> str:
    try:
        callback()
    except LocomotionCoreError as error:
        _require(error.failure_code == expected_code, "A7_FAILURE_CODE")
        return error.failure_code
    raise AdaptationConformanceFailure("A7_INVALID_HOST_REQUEST_ACCEPTED")


def _cell_a7_host_fail_closed(core: LocomotionCore) -> dict[str, Any]:
    invalid = _fixture(core)
    invalid["provider_request"]["provider_may_modify_physics_state"] = True
    code = _expect_failure(
        lambda: core.resolve_adaptation_v1(invalid), "ACTUATION_INVALID"
    )
    return {
        "cell_id": "a7_host_fail_closed",
        "passed": True,
        "forbidden_authority_failure_code": code,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def run_adaptation_provider_conformance() -> dict[str, Any]:
    core = LocomotionCore()
    cells = [
        _cell_a0_contract(core),
        _cell_a1_absent_provider(core),
        _cell_a2_bounded_application(core),
        _cell_a3_confidence_and_support(core),
        _cell_a4_invalid_and_stale(core),
        _cell_a5_refusal_and_reset(core),
        _cell_a6_candidate_only(core),
        _cell_a7_host_fail_closed(core),
    ]
    return {
        "schema_version": REPORT_SCHEMA,
        "ok": True,
        "contract_id": "sporespore_optional_adaptation_provider_v1",
        "release_gate_id": "QSDK-R21",
        "source": _source_receipt(),
        "core": {
            "version": core.version,
            "library_path_execution_only": str(core.library_path),
            "library_sha256": _file_sha256(core.library_path),
        },
        "contract_file_sha256": _file_sha256(CONTRACT_PATH),
        "cells": cells,
        "passed_cells": len(cells),
        "failed_cells": 0,
        "provider_optional_at_runtime": True,
        "trained_provider_evaluated": False,
        "deterministic_baseline_oracle_passed": True,
        "bounds_refusal_reset_and_provenance_passed": True,
        "public_c_abi_and_python_binding_exercised": True,
        "world_build_count": 0,
        "walking_acceptance": False,
        "physical_acceptance_authority": False,
        "completed_engine_neutral_sdk": False,
    }


def _retain_report(report: dict[str, Any], path: Path) -> None:
    _require(path.name == "report.json", "ADAPTATION_REPORT_NAME_INVALID")
    _require(not path.exists(), "ADAPTATION_REPORT_ALREADY_EXISTS", str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name("report.json.tmp")
    _require(
        not temporary.exists(),
        "ADAPTATION_REPORT_TEMPORARY_EXISTS",
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
        report = run_adaptation_provider_conformance()
        if args.output is not None:
            output = args.output.resolve()
            _retain_report(report, output)
            print(f"retained adaptation report: {output}", file=sys.stderr)
        print(json.dumps(report, indent=2, allow_nan=False))
    except (
        AdaptationConformanceFailure,
        LocomotionCoreError,
        OSError,
        ValueError,
    ) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
