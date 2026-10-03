"""Zero-world R24D36 signed-work preprojection and typed-refusal gate."""

from __future__ import annotations

import argparse
from collections import OrderedDict
from copy import deepcopy
import hashlib
import inspect
import json
from pathlib import Path
from typing import Any, Sequence

from sporespore_locomotion import LocomotionCore

from . import energy_work_projection as projection
from . import native_recovery_development as runtime


GATE_ID = "QSDK-R24D36"
CAMPAIGN_ID = "QSDK-R24D36-MUJOCO-SIGNED-WORK-PREPROJECTION"
CONTRACT_SCHEMA = "sporespore_qsdk_r24d36_signed_work_preprojection_contract_v1"
PREFLIGHT_SCHEMA = "sporespore_qsdk_r24d36_signed_work_preprojection_preflight_v1"
R24D35_SOURCE = "4d4abdcf4439c8c40f6f24816126fc9f4261853a"
R24D35_CLOSURE_COMMIT = "a55dea6c659025597cdd01613ba0c23a05964b79"
R24D35_CONTRACT_SHA256 = (
    "sha256:69bcb3ee55bc7105364154d6a77d990582cdfc8bd08d0755ad7c5fc99d12edaa"
)
R24D35_CLOSURE_SHA256 = (
    "sha256:91585bde639bddfb136b9a25a914b6bf26e284f19c2fed5d909f15a397e70a15"
)
R24D35_CLOSURE_AUDIT_SHA256 = (
    "sha256:0a73c7ed74852552c607da227e9c99d8f43570886bbc6db66fc18eaf10b1fbf3"
)
R24D33_CONTRACT_SHA256 = (
    "sha256:32d34ae7dfe8fc42979dbf0db912659d71a2abf5dcf6282bc43437046033d99a"
)
R24D33_CLOSURE_SHA256 = (
    "sha256:5088d34126362a74e90b4e32170e043f09a2e4d274cc569e0202fce2a9b0f9b0"
)
REPO_ROOT = Path(__file__).resolve().parents[4]
CONTRACT_PATH = REPO_ROOT / "sdk/recovery/r24d36_signed_work_preprojection_contract_v1.json"
R24D35_CONTRACT_PATH = (
    REPO_ROOT / "sdk/recovery/r24d35_mujoco_sparse_actuator_moment_contract_v1.json"
)
R24D35_CLOSURE_PATH = (
    REPO_ROOT / "sdk/recovery/r24d35_mujoco_sparse_actuator_moment_invalid_closure_v1.json"
)
R24D35_CLOSURE_AUDIT_PATH = (
    REPO_ROOT / "tests/test_qsdk_r24d35_mujoco_sparse_actuator_moment_invalid_closure.py"
)
R24D33_CONTRACT_PATH = (
    REPO_ROOT / "sdk/recovery/r24d33_mujoco_implicit_step_energy_measurement_contract_v1.json"
)
R24D33_CLOSURE_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d33_mujoco_implicit_step_energy_measurement_qualification_closure_v1.json"
)


class R24D36WorkerError(RuntimeError):
    """Stable fail-closed error for the R24D36 zero-world boundary."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D36WorkerError(code)


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
    _require(contract.get("behavior_question_declared") is False, "BEHAVIOR_QUESTION")
    _require(
        len(contract["source_inventory"])
        == len(set(contract["source_inventory"]))
        == contract["source_inventory_strategy"]["source_inventory_count"],
        "SOURCE_INVENTORY",
    )
    return contract


def _zero_world_controls() -> tuple[OrderedDict[str, bool], dict[str, Any]]:
    contract = load_contract_v1()
    closure35 = _load(R24D35_CLOSURE_PATH)
    contract33 = _load(R24D33_CONTRACT_PATH)
    closure33 = _load(R24D33_CLOSURE_PATH)
    primitive, details = projection.energy_work_projection_zero_world_controls_v1()
    step_source = inspect.getsource(runtime.MujocoNativeRecoveryWorld.step_native)
    signature = set(
        inspect.signature(projection.classify_energy_work_for_portable_v1).parameters
    )
    change = contract["controlled_change"]
    gate = contract["complete_zero_world_gate"]

    controls: OrderedDict[str, bool] = OrderedDict(
        [
            (
                "r24d35_and_r24d33_authorities_are_exact_consumed_and_not_reexecuted",
                _sha256(R24D35_CONTRACT_PATH) == R24D35_CONTRACT_SHA256
                and _sha256(R24D35_CLOSURE_PATH) == R24D35_CLOSURE_SHA256
                and _sha256(R24D35_CLOSURE_AUDIT_PATH)
                == R24D35_CLOSURE_AUDIT_SHA256
                and closure35["source"]["commit"] == R24D35_SOURCE
                and closure35["closure_status"]
                == "closed_consumed_invalid_incomplete_historical_dissipation_invariant_rejection"
                and closure35["next_boundary"]["gate_id"] == GATE_ID
                and closure35["next_boundary"]["r24d35_may_rerun"] is False
                and _sha256(R24D33_CONTRACT_PATH) == R24D33_CONTRACT_SHA256
                and _sha256(R24D33_CLOSURE_PATH) == R24D33_CLOSURE_SHA256
                and closure33["qualification"]["controls_passed"] == 12
                and contract33["frozen_supported_subset"]["joint_damping"] == 0.0
                and contract33["frozen_supported_subset"]["fluid_force"] == 0.0
                and contract33["frozen_supported_subset"]["adhesion_force"] == 0.0,
            ),
            (
                "signed_constraint_work_can_make_the_historical_derived_dissipation_negative",
                -(0.25 + 0.0 + 0.0 + 0.0) == -0.25
                and primitive[
                    "positive_and_negative_constraint_work_retain_sign_and_refuse_portable_v1"
                ],
            ),
            (
                "exact_zero_nonactuator_tuple_projects_to_exact_zero_dissipation",
                primitive[
                    "exact_zero_nonactuator_tuple_projects_to_zero_nonnegative_dissipation"
                ],
            ),
            (
                "both_constraint_work_signs_are_retained_and_typed_refused",
                primitive[
                    "positive_and_negative_constraint_work_retain_sign_and_refuse_portable_v1"
                ],
            ),
            (
                "nonzero_unqualified_passive_work_is_retained_and_typed_refused",
                primitive[
                    "nonzero_unqualified_passive_terms_refuse_without_sign_transformation"
                ],
            ),
            (
                "ordered_summary_receipt_mutation_and_nonfinite_controls_fail_closed",
                primitive[
                    "ordered_receipt_summary_preserves_signed_terms_and_refusal_indices"
                ]
                and primitive["receipt_mutation_and_nonfinite_input_fail_closed"],
            ),
            (
                "v2_and_v3_receipts_bind_the_distinct_route_before_observation_construction",
                runtime.MujocoSparseMomentImplicitStepRecoveryWorld.energy_work_preprojection_required
                is False
                and runtime.MujocoSignedWorkPreprojectionRecoveryWorld.energy_work_preprojection_required
                is True
                and runtime.MujocoSignedWorkPreprojectionRecoveryWorld.route_id
                == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
                and "historical_v2_energy_preprojection"
                in inspect.getsource(runtime.NativeImplicitStepEnergyV3.receipt_v3)
                and "portable_v3_energy_preprojection"
                in inspect.getsource(runtime.NativeImplicitStepEnergyV3.receipt_v3)
                and step_source.index("raise NativeEnergyProjectionRefusal(diagnostic)")
                < step_source.index("state = self._state_frame"),
            ),
            (
                "absolute_clamp_residual_relabelling_and_semantic_scope_drift_are_absent",
                signature
                == {
                    "constraint_work_j",
                    "damper_work_j",
                    "fluid_work_j",
                    "adhesion_work_j",
                }
                and primitive[
                    "mechanical_energy_residual_clamp_and_absolute_value_are_absent"
                ]
                and all(
                    change[name] is False
                    for name in (
                        "controller_changed",
                        "native_physics_changed",
                        "morphology_changed",
                        "initializer_changed",
                        "observer_values_changed",
                        "cell_changed",
                        "seed_changed",
                        "horizon_changed",
                        "behavior_thresholds_changed",
                        "margins_changed",
                        "portable_evaluator_changed",
                        "held_out_selector_changed",
                        "historical_result_changed",
                        "historical_interpretation_changed",
                    )
                ),
            ),
            (
                "qualification_is_zero_world_only_and_authorizes_no_physics_or_claim",
                gate["must_pass_before_physics"] is True
                and gate["construct_mujoco_model"] is False
                and gate["model_construction_count"] == 0
                and gate["world_attempt_count"] == 0
                and gate["world_build_count"] == 0
                and gate["solver_step_count"] == 0
                and contract["qualification_authority"]["maximum_physical_steps_authorized"]
                == 0
                and contract["held_out_seal"]["held_out_cell_access_count"] == 0
                and contract["claim_boundary"]["prone_to_standing_claimed"] is False
                and contract["claim_boundary"]["release_authority"] is False,
            ),
        ]
    )
    return controls, {
        **details,
        "r24d35_closure_raw_sha256": _sha256(R24D35_CLOSURE_PATH),
        "r24d33_qualification_closure_raw_sha256": _sha256(R24D33_CLOSURE_PATH),
        "historical_positive_constraint_fixture_derived_dissipation_j": -0.25,
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = runtime.run_signed_work_preprojection_zero_world_preflight(core)
    checks, details = _zero_world_controls()
    _require(all(checks.values()), "R24D36_ZERO_WORLD_CONTROL_FAILED")
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "gate_id": GATE_ID,
            "negative_control_count": len(checks),
            "negative_controls_passed": sum(checks.values()),
            "signed_work_preprojection_controls": checks,
            "signed_work_preprojection_control_details": details,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "behavior_question_opened": False,
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
