"""Zero-world R24D31 retained-trace diagnosis and energy-ledger correction gate."""

from __future__ import annotations

import argparse
from collections import OrderedDict
from copy import deepcopy
import hashlib
import inspect
import json
import math
from pathlib import Path
import subprocess
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import native_recovery_development as runtime
from .recovery_capability import MAPPING_ID, mujoco_recovery_capability_v1


GATE_ID = "QSDK-R24D31"
CAMPAIGN_ID = "QSDK-R24D31-MUJOCO-INDEPENDENT-ENERGY-WORK-LEDGER"
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d31_mujoco_energy_ledger_correction_contract_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r24d31_mujoco_energy_ledger_correction_preflight_v1"
)
R24D30_SOURCE = "876131bd8aca2f1fe70f59d53157d1f285322c71"
R24D30_CLOSURE_SHA256 = (
    "sha256:6055133c41179c1d58d0c79e453a8089ee2d4b3dfcf5a90fabfbc6b70aba7a1a"
)
R24D30_FULL_SHA256 = (
    "sha256:e5eaaad18203f02901d643f55568b5f0981462f7f0242aa5162220812f59d945"
)
REPO_ROOT = Path(__file__).resolve().parents[4]
CONTRACT_PATH = (
    REPO_ROOT / "sdk/recovery/r24d31_mujoco_energy_ledger_correction_contract_v1.json"
)
FIXTURE_PATH = (
    REPO_ROOT / "sdk/recovery/r24d31_r24d30_energy_ledger_fixture_v1.json"
)
R24D30_CLOSURE_PATH = (
    REPO_ROOT / "sdk/recovery/r24d30_natural_recovery_progression_physical_closure_v1.json"
)
R24D17_CONTRACT_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
)


class R24D31WorkerError(RuntimeError):
    """Stable fail-closed error for the R24D31 zero-world boundary."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D31WorkerError(code)


def _load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    _require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def _sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _git_source(source: str, relative: str) -> str:
    completed = subprocess.run(
        ["git", "show", f"{source}:{relative}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
    )
    return completed.stdout.decode("utf-8")


def _residual(row: Mapping[str, Any]) -> float:
    return (
        float(row["current_mechanical_energy_j"])
        - float(row["initial_mechanical_energy_j"])
        - float(row["cumulative_applied_actuator_work_j"])
        - float(row["cumulative_external_work_j"])
        + float(row["cumulative_dissipated_energy_j"])
    )


def _trace_points_match(
    full: Mapping[str, Any],
    fixture: Mapping[str, Any],
) -> bool:
    result = full["result"]
    for arm_key, fixture_key in (
        ("candidate", "candidate_points"),
        ("matched_zero_command", "matched_zero_points"),
    ):
        arm = result[arm_key]
        for point in fixture[fixture_key]:
            index = int(point["outer_index_zero_based"])
            observation = arm["observations"][index]
            native = arm["native_receipts"][index]["native_step"]
            portable = arm["portable_step_receipts"][index]
            energy = observation["energy_balance"]
            if (
                observation["semantic_step"] != point["semantic_step"]
                or portable["next_phase"] != point["phase_after_step"]
                or portable["classification"]["pose_class"] != point["pose_class"]
                or any(
                    energy[key] != point[key]
                    for key in (
                        "initial_mechanical_energy_j",
                        "current_mechanical_energy_j",
                        "cumulative_applied_actuator_work_j",
                        "cumulative_external_work_j",
                        "cumulative_dissipated_energy_j",
                    )
                )
                or native["current_mechanical_energy_j"]
                != point["current_mechanical_energy_j"]
                or native["cumulative_actuator_work_j"]
                != point["cumulative_applied_actuator_work_j"]
                or _residual(point) != point["signed_residual_j"]
            ):
                return False
    return True


def load_contract_v1(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    contract = _load(path)
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "CONTRACT_QUESTION")
    _require(contract.get("physical_question_declared") is False, "CONTRACT_PHYSICAL")
    _require(
        contract["controlled_change"]["mujoco_capability_mapping_id_after"] == MAPPING_ID,
        "CONTRACT_MAPPING",
    )
    _require(
        contract["controlled_change"]["energy_ledger_profile_id"]
        == runtime.ENERGY_LEDGER_PROFILE_ID,
        "CONTRACT_ENERGY_PROFILE",
    )
    return contract


def _zero_world_controls() -> tuple[OrderedDict[str, bool], dict[str, Any]]:
    contract = load_contract_v1()
    fixture = _load(FIXTURE_PATH)
    closure = _load(R24D30_CLOSURE_PATH)
    physical = closure["physical_attempt"]
    full_path = Path(physical["evidence_root"]) / "paired_full_result.json"
    full = _load(full_path)
    artifact = next(
        item
        for item in physical["retained_artifacts"]
        if item["path"] == "paired_full_result.json"
    )
    candidate = fixture["candidate_points"]
    matched = fixture["matched_zero_points"]
    matched_terminal = matched[-1]

    predecessor_runtime = _git_source(
        R24D30_SOURCE,
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py",
    )
    predecessor_capability = _git_source(
        R24D30_SOURCE,
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_capability.py",
    )
    current_runtime = Path(runtime.__file__).read_text(encoding="utf-8")
    capability = mujoco_recovery_capability_v1()
    energy_channel = next(
        item
        for item in capability["ordered_channels"]
        if item["channel"] == "energy_balance_ledger"
    )

    nominal = runtime.measure_native_energy_work_v2(
        timestep_s=0.1,
        actuator_force=[1.0],
        actuator_velocity=[2.0],
        generalized_velocity=[2.0, -1.0],
        generalized_actuator_force=[3.0, 4.0],
        generalized_constraint_force=[-2.0, 1.0],
        generalized_damper_force=[-1.0, 0.0],
        generalized_fluid_force=[0.0, 0.5],
        generalized_adhesion_force=[0.0, 0.0],
    )
    malformed_rejected = False
    try:
        runtime.measure_native_energy_work_v2(
            timestep_s=0.1,
            actuator_force=[1.0],
            actuator_velocity=[2.0],
            generalized_velocity=[2.0, -1.0],
            generalized_actuator_force=[3.0, 4.0],
            generalized_constraint_force=[1.0],
            generalized_damper_force=[-1.0, 0.0],
            generalized_fluid_force=[0.0, 0.5],
            generalized_adhesion_force=[0.0, 0.0],
        )
    except runtime.NativeRecoveryRouteError as error:
        malformed_rejected = str(error) == "QSDK_R24D31_QFRC_CONSTRAINT_SHAPE_MISMATCH"

    tautology_rejected = False
    try:
        runtime.measure_native_energy_work_v2(  # type: ignore[call-arg]
            timestep_s=0.1,
            actuator_force=[1.0],
            actuator_velocity=[2.0],
            generalized_velocity=[2.0, -1.0],
            generalized_actuator_force=[3.0, 4.0],
            generalized_constraint_force=[-2.0, 1.0],
            generalized_damper_force=[-1.0, 0.0],
            generalized_fluid_force=[0.0, 0.5],
            generalized_adhesion_force=[0.0, 0.0],
            balance_residual_j=-0.75,
        )
    except TypeError:
        tautology_rejected = True

    threshold_contract = _load(R24D17_CONTRACT_PATH)
    energy_threshold = next(
        item
        for item in threshold_contract["threshold_profile"]["thresholds"]
        if item["threshold_id"] == "maximum_energy_balance_residual_j"
    )["value"]
    required_sources = set(contract["controlled_change"]["independent_native_sources"])
    signature = set(inspect.signature(runtime.measure_native_energy_work_v2).parameters)

    checks: OrderedDict[str, bool] = OrderedDict(
        [
            (
                "r24d30_closure_and_full_trace_digest_are_exact",
                _sha256(R24D30_CLOSURE_PATH) == R24D30_CLOSURE_SHA256
                and closure["source_commit"] == R24D30_SOURCE
                and artifact["raw_sha256"] == R24D30_FULL_SHA256
                and _sha256(full_path) == R24D30_FULL_SHA256,
            ),
            (
                "all_ten_compact_fixture_points_match_the_retained_full_trace",
                len(candidate) == 6
                and len(matched) == 4
                and _trace_points_match(full, fixture),
            ),
            (
                "the_matched_zero_terminal_has_zero_actuator_external_and_recorded_dissipation_work_but_nonzero_mechanical_energy_change",
                matched_terminal["cumulative_applied_actuator_work_j"] == 0.0
                and matched_terminal["cumulative_external_work_j"] == 0.0
                and matched_terminal["cumulative_dissipated_energy_j"] == 0.0
                and matched_terminal["current_mechanical_energy_j"]
                != matched_terminal["initial_mechanical_energy_j"],
            ),
            (
                "the_matched_zero_terminal_residual_exceeds_the_unchanged_limit",
                abs(_residual(matched_terminal)) > 0.25,
            ),
            (
                "candidate_residuals_recompute_exactly_at_pre_actuation_post_actuation_distal_support_first_raised_and_terminal_points",
                all(_residual(point) == point["signed_residual_j"] for point in candidate),
            ),
            (
                "the_predecessor_source_hard_codes_zero_dissipation_and_names_its_mapping_unclosed",
                '"cumulative_dissipated_energy_j": 0.0' in predecessor_runtime
                and "mujoco_mechanical_energy_known_work_and_unclosed_residual_ledger_v1"
                in predecessor_capability,
            ),
            (
                "the_successor_capability_maps_all_independent_native_work_sources",
                capability["mapping_id"] == MAPPING_ID
                and required_sources.issubset(set(energy_channel["host_source_ids"]))
                and energy_channel["mapping_rule_id"]
                == "mujoco_mechanical_energy_independent_native_work_balance_ledger_v2",
            ),
            (
                "the_successor_collector_retains_each_component_and_publishes_their_independent_sum",
                all(
                    token in current_runtime
                    for token in (
                        '"step_constraint_work_j"',
                        '"step_damper_work_j"',
                        '"step_fluid_work_j"',
                        '"step_adhesion_work_j"',
                        '"cumulative_dissipated_energy_j": self.cumulative_dissipated_energy_j',
                    )
                ),
            ),
            (
                "actuator_space_and_generalized_actuator_work_are_cross_checked",
                nominal.actuator_work_j == nominal.generalized_actuator_work_j == 0.2
                and "QSDK_R24D31_ACTUATOR_WORK_CROSSCHECK_FAILED" in current_runtime,
            ),
            (
                "omitted_or_shape_mismatched_native_terms_fail_closed",
                malformed_rejected,
            ),
            (
                "a_tautological_residual_derived_dissipation_mutation_is_rejected",
                tautology_rejected
                and "balance_residual_j" not in signature
                and "initial_mechanical_energy_j" not in signature
                and "current_mechanical_energy_j" not in signature,
            ),
            (
                "threshold_controller_physics_morphology_phase_evaluator_and_historical_result_remain_unchanged",
                energy_threshold == 0.25
                and contract["controlled_change"]["controller_changed"] is False
                and contract["controlled_change"]["native_physics_changed"] is False
                and contract["controlled_change"]["behavior_thresholds_changed"] is False
                and contract["lineage"]["predecessor_result"]
                == closure["closure_status"]
                and contract["lineage"]["predecessor_may_rerun"] is False,
            ),
        ]
    )
    details = {
        "fixture_raw_sha256": _sha256(FIXTURE_PATH),
        "retained_full_result_raw_sha256": _sha256(full_path),
        "matched_zero_terminal_signed_residual_j": _residual(matched_terminal),
        "candidate_terminal_signed_residual_j": _residual(candidate[-1]),
        "unchanged_maximum_absolute_residual_j": energy_threshold,
        "energy_ledger_profile_id": runtime.ENERGY_LEDGER_PROFILE_ID,
        "capability_mapping_id": MAPPING_ID,
    }
    return checks, details


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = runtime.run_zero_world_preflight(core)
    checks, details = _zero_world_controls()
    _require(all(checks.values()), "R24D31_ZERO_WORLD_CONTROL_FAILED")
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "gate_id": GATE_ID,
            "negative_control_count": len(checks),
            "negative_controls_passed": sum(checks.values()),
            "energy_ledger_controls": checks,
            "energy_ledger_control_details": details,
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
    receipt = run_zero_world_preflight(
        LocomotionCore(arguments.core_library.resolve())
    )
    print(json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
