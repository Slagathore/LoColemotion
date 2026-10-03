"""Compact source audit for the prospective QSDK-R24D41 route conjunction."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    exact_bools,
    load,
    require,
    sha256,
)

CONTRACT_PATH = (
    ROOT / "sdk/recovery/"
    "r24d41_mujoco_recovery_morphology_observation_v2_smoke_contract_v1.json"
)
R40_CLOSURE_PATH = (
    ROOT / "sdk/recovery/"
    "r24d40_mujoco_observation_v2_native_smoke_invalid_closure_v1.json"
)
R40_AUDIT_PATH = (
    ROOT / "tests/test_qsdk_r24d40_observation_v2_native_smoke_invalid_closure.py"
)
GATE = "QSDK-R24D41"
CAMPAIGN = "QSDK-R24D41-MUJOCO-RECOVERY-MORPHOLOGY-OBSERVATION-V2-SMOKE"
R40_CLOSURE_HASH = (
    "sha256:6015015a87e533ba128810282aba4338f36e3fab0a9e3b53fe7599728012a715"
)
R40_AUDIT_HASH = (
    "sha256:9b12b3795ccd740fcad226a790b0593f1444e63240306141804135b8f841c72e"
)


def _text(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def _json(relative: str) -> dict[str, Any]:
    value = json.loads((ROOT / relative).read_bytes())
    require(isinstance(value, dict), f"JSON_ROOT:{relative}")
    return value


def _ordered(source: str, markers: tuple[str, ...], code: str) -> None:
    require(all(marker in source for marker in markers), f"{code}_MARKER")
    offsets = [source.index(marker) for marker in markers]
    require(offsets == sorted(offsets), f"{code}_ORDER")


def _find_gate(value: object, gate_id: str) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if value.get("gate_id") == gate_id:
            found.append(value)
        for child in value.values():
            found.extend(_find_gate(child, gate_id))
    elif isinstance(value, list):
        for child in value:
            found.extend(_find_gate(child, gate_id))
    return found


def audit() -> None:
    contract = load(CONTRACT_PATH)
    exact(
        (
            contract["gate_id"],
            contract["campaign_id"],
            contract["question_class"],
            contract["physical_question_declared"],
            contract["behavior_question_declared"],
        ),
        (GATE, CAMPAIGN, "development", True, False),
        "CONTRACT_IDENTITY",
    )
    exact_bools(
        contract,
        (
            "superiority_question_declared",
            "equivalence_or_non_inferiority_question_declared",
            "population_inference_declared",
        ),
        False,
        "QUESTION_LIMIT",
    )

    inventory = contract["source_inventory"]
    exact(len(inventory), 25, "INVENTORY_COUNT")
    exact(len(inventory), len(set(inventory)), "INVENTORY_UNIQUE")
    require(
        all((ROOT / relative).is_file() for relative in inventory), "INVENTORY_FILE"
    )
    exact(
        contract["source_inventory_strategy"]["source_inventory_count"],
        len(inventory),
        "INVENTORY_STRATEGY",
    )
    exact(
        contract["prospective_freeze"]["source_inventory_count"],
        len(inventory),
        "FREEZE_INVENTORY",
    )

    closure = load(R40_CLOSURE_PATH)
    exact(sha256(R40_CLOSURE_PATH.read_bytes()), R40_CLOSURE_HASH, "R40_CLOSURE_HASH")
    exact(sha256(R40_AUDIT_PATH.read_bytes()), R40_AUDIT_HASH, "R40_AUDIT_HASH")
    exact(
        (
            closure["closure_status"],
            closure["decision"]["result"],
            closure["decision"]["r24d40_may_be_rerun"],
            closure["next_boundary"]["gate_id"],
        ),
        (
            "closed_consumed_invalid_recovery_morphology_route_context_missing",
            "consumed_invalid_incomplete_and_retained",
            False,
            GATE,
        ),
        "R40_CLOSURE",
    )
    lineage = contract["lineage"]
    exact(
        (
            lineage["predecessor_source_commit"],
            lineage["predecessor_closure_commit"],
            lineage["predecessor_closure_raw_sha256"],
            lineage["predecessor_closure_audit_raw_sha256"],
            lineage["predecessor_may_rerun"],
        ),
        (
            "c68a1aef834998b9c57be59f2bffa8e134ddef64",
            "a30d469742629ba8ce15c1d3d8b7169146a4e99b",
            R40_CLOSURE_HASH,
            R40_AUDIT_HASH,
            False,
        ),
        "LINEAGE",
    )
    exact_bools(
        lineage,
        (
            "historical_result_rewritten",
            "historical_threshold_rewritten",
            "historical_selector_rewritten",
            "historical_evaluator_rewritten",
            "historical_interpretation_rewritten",
        ),
        False,
        "LINEAGE_LIMIT",
    )

    gate = contract["complete_zero_world_gate"]
    exact(
        (
            gate["must_pass_before_physics"],
            gate["construct_mujoco_model"],
            gate["world_attempt_count"],
            gate["world_build_count"],
            gate["solver_step_count"],
            gate["required_control_count"],
            gate["forced_failure_count"],
        ),
        (True, False, 0, 0, 0, 8, 9),
        "ZERO_WORLD_GATE",
    )
    exact(
        len(gate["required_controls"]), len(set(gate["required_controls"])), "CONTROLS"
    )
    exact(len(gate["negative_controls"]), 3, "NEGATIVE_CONTROLS")
    exact(gate["historical_closure_audits_reexecuted"], False, "AUDIT_REEXECUTION")

    shared_smoke = _text(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/bounded_recovery_route_smoke.py"
    )
    composite = _text(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
        "recovery_observation_v2_morphology_route.py"
    )
    worker = _text(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
        "qsdk_r24d41_observation_v2_morphology_smoke_worker.py"
    )
    route_test = _text("sdk/adapters/mujoco/test_native_recovery_development.py")
    _ordered(
        shared_smoke,
        (
            "route_factory: Callable[",
            "execution_core = LocomotionCore(core_library)",
            "exact_route = None if route_factory is None else route_factory(execution_core)",
            "result = runtime.run_paired_development(",
            "route=exact_route",
        ),
        "SHARED_ROUTE_FACTORY",
    )
    require("| None = None" in shared_smoke, "SHARED_DEFAULT")
    _ordered(
        composite,
        (
            "class MujocoRecoveryMorphologyObservationV2World(",
            "morphology.MujocoRecoveryMorphologyWorld,",
            "runtime.MujocoObservationV2RecoveryWorld,",
            "route_id = runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID",
            "def validate_recovery_observation_v2_morphology_conjunction_v1(",
        ),
        "COMPOSITE_SOURCE",
    )
    for marker in (
        "QSDK_R24D41_RECOVERY_MORPHOLOGY_ROUTE_REQUIRED",
        "QSDK_R24D41_COMPOSITE_WORLD_REQUIRED",
        "QSDK_R24D41_COMPOSITE_MRO_INVALID",
        "QSDK_R24D41_COMPOSITE_METHOD_ROUTE_INVALID",
        "QSDK_R24D41_MORPHOLOGY_CONTEXT_INVALID",
        'model_construction_count": 0',
        'solver_step_count": 0',
    ):
        require(marker in composite, f"COMPOSITE_MARKER:{marker}")
    _ordered(
        worker,
        (
            "world_type=conjunction.MujocoRecoveryMorphologyObservationV2World",
            "route_factory=morphology.compile_recovery_morphology_model_route",
        ),
        "WORKER_CONJUNCTION",
    )
    for marker in (
        "test_bounded_smoke_publisher_is_zero_world_and_qualification_gated",
        'self.assertIs(run.call_args.kwargs["route"], exact_route)',
        "test_observation_v2_recovery_morphology_conjunction_is_zero_world",
        "model.assert_not_called()",
        "QSDK_R24D41_RECOVERY_MORPHOLOGY_ROUTE_REQUIRED",
        "QSDK_R24D41_COMPOSITE_WORLD_REQUIRED",
    ):
        require(marker in route_test, f"ROUTE_TEST_MARKER:{marker}")

    route = contract["route_conjunction"]
    exact(
        (
            route["route_factory"],
            route["compiled_receipt_schema"],
            route["world_type"],
            route["native_source_route_id"],
            route["publication_route_id"],
            route["existing_callers_default_to_none"],
        ),
        (
            "compile_recovery_morphology_model_route",
            "sporespore_recovery_morphology_receipt_v1",
            "MujocoRecoveryMorphologyObservationV2World",
            "sporespore_mujoco_exact_s169_native_recovery_implicit_step_energy_v3",
            "sporespore_mujoco_exact_s169_recovery_observation_v2_consumer_v1",
            True,
        ),
        "ROUTE_CONJUNCTION",
    )
    change = contract["controlled_change"]
    exact_bools(
        change,
        (
            "production_route_factory_handoff_changed",
            "production_world_composition_changed",
            "r24d40_observed_constructor_input_changed",
        ),
        True,
        "CHANGE",
    )
    exact_bools(
        change,
        tuple(
            key
            for key, value in change.items()
            if isinstance(value, bool)
            and key
            not in {
                "production_route_factory_handoff_changed",
                "production_world_composition_changed",
                "r24d40_observed_constructor_input_changed",
            }
        ),
        False,
        "UNCHANGED",
    )

    for wrapper in (
        "sdk/run_qsdk_r24d41_observation_v2_morphology_smoke.ps1",
        "sdk/run_qsdk_r24d41_observation_v2_morphology_smoke_zero_world.ps1",
    ):
        source = _text(wrapper)
        require(GATE in source, f"WRAPPER_GATE:{wrapper}")
        require(
            "qsdk_r24d41_observation_v2_morphology_smoke_worker" in source,
            f"WRAPPER_WORKER:{wrapper}",
        )

    release_path = "sdk/release/quadruped_release_contract.json"
    support_path = "sdk/release/quadruped_support_matrix.json"
    release = _json(release_path)
    support = _json(support_path)
    for document, code in ((release, "RELEASE"), (support, "SUPPORT")):
        nodes = [
            node
            for node in _find_gate(document, GATE)
            if node.get("predecessor_gate_id") == "QSDK-R24D40"
        ]
        exact(len(nodes), 1, f"{code}_NODE_COUNT")
        node = nodes[0]
        exact(
            node["contract_path"],
            contract["contract_path"]
            if "contract_path" in contract
            else CONTRACT_PATH.relative_to(ROOT).as_posix(),
            f"{code}_CONTRACT",
        )
        exact(node["physical_question_declared"], True, f"{code}_QUESTION")
        exact(node["physical_execution_authorized"], False, f"{code}_PHYSICS")
        exact(node["r24d40_may_be_rerun"], False, f"{code}_R40_RERUN")
    mapping = _json("sdk/release/quadruped_sdk1_milestone_mapping_v1.json")
    authority = mapping["full_program_authority"]
    exact(
        authority["release_contract_raw_sha256"],
        "sha256:" + hashlib.sha256((ROOT / release_path).read_bytes()).hexdigest(),
        "MAPPING_RELEASE_HASH",
    )
    exact(
        authority["support_matrix_raw_sha256"],
        "sha256:" + hashlib.sha256((ROOT / support_path).read_bytes()).hexdigest(),
        "MAPPING_SUPPORT_HASH",
    )

    documentation_markers = {
        "docs/README.md": "R24D41 declares the exact morphology/observation-V2 conjunction",
        "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md": "R24D41 prospective route-conjunction repair",
        "docs/LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md": "R24D41 declared finite population and adequacy",
        "docs/LOCOMOTION_ARCHITECTURE.md": "R24D41 composite route is source-complete",
        "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md": "R24D41 exact route conjunction is declared",
        "sdk/adapters/mujoco/README.md": "R24D41 prospective composite route",
    }
    for relative, marker in documentation_markers.items():
        require(marker in _text(relative), f"DOC_MARKER:{relative}")

    claims = contract["claim_boundary"]
    exact_bools(
        claims,
        (
            "route_factory_source_implemented",
            "composite_world_source_implemented",
            "development_zero_world_route_conformance_passed",
        ),
        True,
        "CLAIM_IMPLEMENTED",
    )
    exact_bools(
        claims,
        (
            "r24d40_reopened",
            "native_route_v2_observation_physically_published",
            "new_physical_observation_made",
            "physical_measurement_adequacy_established",
            "recovery_progression_proven",
            "controller_physical_viability_proven",
            "prone_to_standing_claimed",
            "repeatability_rate_claimed",
            "population_claimed",
            "held_out_validation_claimed",
            "cross_engine_recovery_claimed",
            "cross_engine_equivalence_claimed",
            "sdk1_milestone_advanced",
            "physical_acceptance_authority",
            "release_authority",
        ),
        False,
        "CLAIM_LIMIT",
    )
    print(
        "QSDK_R24D41_OBSERVATION_V2_MORPHOLOGY_SMOKE_SOURCE_PASS "
        "inventory=25 controls=8 forced_failures=9 models=0 worlds=0 "
        "solver_steps=0 physical=false sdk1=11/20"
    )


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError) as error:
        print(
            f"QSDK_R24D41_OBSERVATION_V2_MORPHOLOGY_SMOKE_SOURCE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
