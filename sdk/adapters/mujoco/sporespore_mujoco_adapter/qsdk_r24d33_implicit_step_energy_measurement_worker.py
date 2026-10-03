"""Zero-world R24D33 implicit-step energy measurement gate."""

from __future__ import annotations

import argparse
from collections import OrderedDict
from copy import deepcopy
import hashlib
import json
from pathlib import Path
from typing import Any, Sequence

from sporespore_locomotion import LocomotionCore

from . import native_recovery_development as runtime
from .implicit_step_energy import (
    PROFILE_ID,
    implicit_step_energy_zero_world_controls_v1,
)


GATE_ID = "QSDK-R24D33"
CAMPAIGN_ID = "QSDK-R24D33-MUJOCO-IMPLICIT-STEP-ENERGY-MEASUREMENT"
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d33_mujoco_implicit_step_energy_measurement_contract_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r24d33_mujoco_implicit_step_energy_measurement_preflight_v1"
)
R24D32_SOURCE = "326dd1d22b40b675f12372089d77d7724dc20a9a"
R24D32_CLOSURE_SHA256 = (
    "sha256:d2c84767823171406a868f6ccda4331b210d3c517974d0ae018c6e357e802eb8"
)
R24D32_DIAGNOSIS_SHA256 = (
    "sha256:7ece8fa6060662b772e34d2c9874a2fa15c4b51ce4e8a3c68a479087dc4ab2f8"
)
REPO_ROOT = Path(__file__).resolve().parents[4]
CONTRACT_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d33_mujoco_implicit_step_energy_measurement_contract_v1.json"
)
R24D32_CLOSURE_PATH = (
    REPO_ROOT / "sdk/recovery/r24d32_corrected_energy_progression_physical_closure_v1.json"
)
R24D32_DIAGNOSIS_PATH = (
    REPO_ROOT / "sdk/recovery/r24d32_implicit_step_energy_diagnosis_v1.json"
)
R24D17_CONTRACT_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
)


class R24D33WorkerError(RuntimeError):
    """Stable fail-closed error for the R24D33 zero-world boundary."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D33WorkerError(code)


def _load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    _require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def _sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def load_contract_v1(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    contract = _load(path)
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "QUESTION_CLASS")
    _require(contract.get("physical_question_declared") is False, "PHYSICAL_QUESTION")
    return contract


def _zero_world_controls() -> tuple[OrderedDict[str, bool], dict[str, Any]]:
    contract = load_contract_v1()
    closure = _load(R24D32_CLOSURE_PATH)
    diagnosis = _load(R24D32_DIAGNOSIS_PATH)
    threshold_contract = _load(R24D17_CONTRACT_PATH)
    energy_limit = next(
        item["value"]
        for item in threshold_contract["threshold_profile"]["thresholds"]
        if item["threshold_id"] == "maximum_energy_balance_residual_j"
    )
    shared, details = implicit_step_energy_zero_world_controls_v1()
    checks: OrderedDict[str, bool] = OrderedDict()
    checks["r24d32_closure_and_retained_diagnosis_are_exact_and_consumed"] = (
        _sha256(R24D32_CLOSURE_PATH) == R24D32_CLOSURE_SHA256
        and _sha256(R24D32_DIAGNOSIS_PATH) == R24D32_DIAGNOSIS_SHA256
        and closure["source"]["commit"] == R24D32_SOURCE
        and closure["closure_status"] == contract["lineage"]["predecessor_result"]
        and diagnosis["next_boundary"]["gate_id"] == GATE_ID
        and diagnosis["next_boundary"]["next_physical_execution_authorized"] is False
    )
    checks.update(shared)
    checks["threshold_controller_physics_result_and_claim_boundary_remain_unchanged"] = (
        energy_limit == 0.25
        and contract["controlled_change"]["behavior_thresholds_changed"] is False
        and contract["controlled_change"]["controller_changed"] is False
        and contract["controlled_change"]["native_physics_changed"] is False
        and contract["controlled_change"]["historical_result_changed"] is False
        and contract["qualification_and_closure"]["physical_execution_permitted"] is False
    )
    return checks, {
        **details,
        "profile_id": PROFILE_ID,
        "r24d32_closure_raw_sha256": _sha256(R24D32_CLOSURE_PATH),
        "r24d32_diagnosis_raw_sha256": _sha256(R24D32_DIAGNOSIS_PATH),
        "unchanged_maximum_absolute_residual_j": energy_limit,
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = runtime.run_zero_world_preflight(core)
    checks, details = _zero_world_controls()
    _require(all(checks.values()), "R24D33_ZERO_WORLD_CONTROL_FAILED")
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "gate_id": GATE_ID,
            "negative_control_count": len(checks),
            "negative_controls_passed": sum(checks.values()),
            "implicit_step_energy_controls": checks,
            "implicit_step_energy_control_details": details,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
    )
    return receipt


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("preflight",))
    parser.add_argument("--core-library", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    receipt = run_zero_world_preflight(LocomotionCore(arguments.core_library.resolve()))
    print(json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
