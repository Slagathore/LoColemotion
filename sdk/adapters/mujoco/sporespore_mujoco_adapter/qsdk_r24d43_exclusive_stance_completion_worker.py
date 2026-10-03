"""R24D43 exclusive stance ownership and portable-completion worker."""

from __future__ import annotations

import argparse
from copy import deepcopy
import inspect
import json
from pathlib import Path
import traceback
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore
import sporespore_recovery_stance as stance

from . import native_recovery_development as runtime
from . import qsdk_r24d18_recovery_development_worker as shared
from . import qsdk_r24d27_natural_recovery_progression_worker as progression
from . import qsdk_r24d42_observation_v2_natural_progression_worker as r42
from . import recovery_morphology_route as morphology
from . import recovery_observation_v2_streaming_route as streaming
from .recovery_observation_v2_route_fixture import (
    synthetic_r24d40_native_invariant_case_v1,
)


GATE_ID = "QSDK-R24D43"
CAMPAIGN_ID = "QSDK-R24D43-MUJOCO-EXCLUSIVE-STANCE-COMPLETION"
CONTRACT_SCHEMA = "sporespore_qsdk_r24d43_exclusive_stance_completion_contract_v1"
PREFLIGHT_SCHEMA = "sporespore_qsdk_r24d43_exclusive_stance_completion_preflight_v1"
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d43_exclusive_stance_completion_zero_world_receipt_v1"
)
TRACE_INVARIANTS_SCHEMA = (
    "sporespore_qsdk_r24d43_exclusive_stance_completion_trace_invariants_v1"
)
FULL_RESULT_SCHEMA = "sporespore_qsdk_r24d43_exclusive_stance_completion_full_result_v1"
COMPACT_PROJECTION_SCHEMA = (
    "sporespore_qsdk_r24d43_exclusive_stance_completion_compact_projection_v1"
)
MANIFEST_SCHEMA = "sporespore_qsdk_r24d43_exclusive_stance_completion_manifest_v1"
INVALID_SCHEMA = "sporespore_qsdk_r24d43_exclusive_stance_completion_invalid_v1"

EXPECTED_CELL_ID = progression.EXPECTED_CELL_ID
EXPECTED_SEED = progression.EXPECTED_SEED
EXPECTED_MAXIMUM_HORIZON_STEPS = progression.EXPECTED_MAXIMUM_HORIZON_STEPS
EXPECTED_PAIRED_ARM_COUNT = progression.EXPECTED_PAIRED_ARM_COUNT
EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS = progression.EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS
EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS = (
    progression.EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS
)
EXPECTED_SOURCE_INVENTORY_COUNT = 45
EXPECTED_CONTROL_COUNT = 10
EXPECTED_FORCED_FAILURE_COUNT = 12
TERMINAL_STOP_PHASES = {"complete", "failed", "refused"}
STANCE_PHASES = {"stance_handoff", "stance_dwell"}
EXPECTED_SUCCESS_TRANSITIONS = [
    ["confirm_prone", "establish_distal_support"],
    ["establish_distal_support", "raise_body"],
    ["raise_body", "stance_handoff"],
    ["stance_handoff", "stance_dwell"],
    ["stance_dwell", "complete"],
]

REPO_ROOT = Path(__file__).resolve().parents[4]
CONTRACT_PATH = (
    REPO_ROOT / "sdk/recovery/r24d43_exclusive_stance_completion_contract_v1.json"
)
R42_CONTRACT_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d42_mujoco_observation_v2_natural_progression_contract_v1.json"
)
R42_CLOSURE_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d42_mujoco_observation_v2_natural_progression_positive_closure_v1.json"
)
R42_CLOSURE_AUDIT_PATH = (
    REPO_ROOT
    / "tests/test_qsdk_r24d42_observation_v2_natural_progression_positive_closure.py"
)


class R24D43WorkerError(RuntimeError):
    """Stable fail-closed R24D43 worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D43WorkerError(code)


def load_contract_v1(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    """Load the frozen finite question and bind it to the immutable R42 result."""

    contract = shared._load_json(path)
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "QUESTION_CLASS")
    _require(contract.get("physical_question_declared") is True, "PHYSICAL_QUESTION")
    _require(contract.get("behavior_question_declared") is True, "BEHAVIOR_QUESTION")
    _require(
        contract.get("superiority_question_declared") is False
        and contract.get("equivalence_or_non_inferiority_question_declared") is False
        and contract.get("population_inference_declared") is False,
        "QUESTION_SCOPE",
    )

    lineage = contract["lineage"]
    _require(
        lineage["predecessor_gate_id"] == r42.GATE_ID
        and lineage["predecessor_contract_path"]
        == R42_CONTRACT_PATH.relative_to(REPO_ROOT).as_posix()
        and lineage["predecessor_positive_closure_path"]
        == R42_CLOSURE_PATH.relative_to(REPO_ROOT).as_posix()
        and lineage["predecessor_positive_closure_raw_sha256"]
        == shared._sha256_path(R42_CLOSURE_PATH)
        and lineage["predecessor_closure_audit_path"]
        == R42_CLOSURE_AUDIT_PATH.relative_to(REPO_ROOT).as_posix()
        and lineage["predecessor_closure_audit_raw_sha256"]
        == shared._sha256_path(R42_CLOSURE_AUDIT_PATH)
        and lineage["predecessor_result_is_immutable"] is True
        and lineage["predecessor_reinterpreted"] is False
        and lineage["predecessor_reopened"] is False,
        "R42_LINEAGE",
    )
    r42_contract = shared._load_json(R42_CONTRACT_PATH)
    cell = contract["selected_development_cell"]
    r42_cell = r42_contract["selected_development_cell"]
    _require(
        {key: value for key, value in cell.items() if key != "selection_provenance"}
        == {
            key: value
            for key, value in r42_cell.items()
            if key != "selection_provenance"
        },
        "SELECTED_CELL_CHANGED",
    )
    _require(
        cell["cell_id"] == EXPECTED_CELL_ID
        and cell["seed"] == EXPECTED_SEED
        and cell["random_draw_count"] == 0
        and cell["question_class"] == "development"
        and cell["population_claim_permitted"] is False,
        "SELECTED_CELL",
    )
    horizon = contract["natural_stop_horizon"]
    _require(
        horizon["maximum_steps_per_arm"] == EXPECTED_MAXIMUM_HORIZON_STEPS
        and horizon["native_substeps_per_outer_step"] == 5
        and horizon["paired_arm_count"] == EXPECTED_PAIRED_ARM_COUNT
        and horizon["maximum_total_outer_steps"] == EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS
        and horizon["maximum_total_native_solver_steps"]
        == EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS
        and set(horizon["terminal_stop_phases"]) == TERMINAL_STOP_PHASES
        and horizon["stance_handoff_is_no_longer_a_stop"] is True
        and horizon["full_seeded_predictive_ghost_required"] is False
        and horizon["physical_canary_required"] is False,
        "NATURAL_STOP_HORIZON",
    )
    change = contract["prospective_change"]
    _require(
        change["portable_stance_request_schema"] == stance.REQUEST_SCHEMA
        and change["reused_control_receipt_schema"] == stance.CONTROL_RECEIPT_SCHEMA
        and change["stance_controller_id"] == stance.STANCE_CONTROLLER_ID
        and change["stance_pose_id"] == stance.STANCE_POSE_ID
        and tuple(change["stance_target_positions_rad"])
        == stance.STANCE_TARGET_POSITIONS_RAD
        and change["maximum_stance_target_speed_rad_s"]
        == stance.MAXIMUM_STANCE_TARGET_SPEED_RAD_S
        and change["controller_overlap_permitted"] is False
        and change["shared_runner_default_still_stops_at_handoff"] is True
        and change["r24d43_explicitly_opts_into_stance_continuation"] is True,
        "STANCE_CHANGE",
    )
    _require(
        not any(
            change[field]
            for field in (
                "recovery_controller_changed",
                "recovery_profile_changed",
                "stance_pose_or_speed_changed",
                "actuator_profile_changed",
                "native_physics_changed",
                "morphology_changed",
                "initializer_changed",
                "observation_or_streaming_mapping_changed",
                "threshold_or_margin_changed",
                "cell_or_seed_changed",
                "held_out_selector_changed_or_opened",
            )
        ),
        "UNCHANGED_SURFACE_CHANGED",
    )
    thresholds = contract["threshold_margin_and_population_provenance"]
    _require(
        thresholds["maximum_energy_balance_residual_j"] == 0.25
        and thresholds["stance_height_ratio_min"] == 0.75
        and thresholds["stance_torso_up_dot_min"] == 0.95
        and thresholds["maximum_terminal_linear_speed_m_s"] == 0.1
        and thresholds["maximum_terminal_angular_speed_rad_s"] == 0.2
        and thresholds["stance_dwell_steps"] == 60
        and thresholds["new_behavior_threshold_count"] == 0
        and thresholds["new_empirical_threshold_count"] == 0
        and thresholds["new_statistical_margin_count"] == 0
        and thresholds["post_outcome_rethresholding_permitted"] is False,
        "THRESHOLDS",
    )
    gate = contract["complete_zero_world_gate"]
    _require(
        gate["must_pass_before_physics"] is True
        and gate["construct_mujoco_model"] is False
        and gate["required_control_count"] == EXPECTED_CONTROL_COUNT
        and gate["required_forced_failure_count"] == EXPECTED_FORCED_FAILURE_COUNT
        and len(gate["controls"]) == EXPECTED_CONTROL_COUNT
        and len(gate["forced_failure_families"]) == EXPECTED_FORCED_FAILURE_COUNT
        and gate["model_construction_count"] == 0
        and gate["world_attempt_count"] == 0
        and gate["world_build_count"] == 0
        and gate["solver_step_count"] == 0
        and gate["physics_state_modified"] is False,
        "ZERO_WORLD_GATE",
    )
    inventory = contract["source_inventory"]
    _require(
        len(inventory)
        == len(set(inventory))
        == contract["prospective_freeze"]["source_inventory_count"]
        == EXPECTED_SOURCE_INVENTORY_COUNT
        and all((REPO_ROOT / item).is_file() for item in inventory),
        "SOURCE_INVENTORY",
    )
    claims = contract["claim_boundary"]
    _require(
        claims["source_declared"] is True
        and claims["development_zero_world_gate_passed"] is True
        and claims["physical_question_opened"] is False
        and claims["sdk1_completed_steps"] == 11
        and claims["sdk1_total_steps"] == 20
        and claims["full_program_completed_steps"] == 11
        and claims["full_program_total_steps"] == 25
        and claims["physical_acceptance_authority"] is False
        and claims["release_authority"] is False,
        "CLAIM_BOUNDARY",
    )
    return contract


def _edge_fixture(
    core: LocomotionCore,
    prior_phase: str,
) -> dict[str, Any]:
    """Exercise one source-bound collector, supervisor, and stance-composer edge."""

    completed = {
        "raise_body": ["confirm_prone", "establish_distal_support"],
        "stance_handoff": [
            "confirm_prone",
            "establish_distal_support",
            "raise_body",
        ],
        "stance_dwell": [
            "confirm_prone",
            "establish_distal_support",
            "raise_body",
            "stance_handoff",
        ],
    }
    expected = {
        "raise_body": ("stance_handoff", True),
        "stance_handoff": ("stance_dwell", True),
        "stance_dwell": ("stance_dwell", False),
    }
    _require(prior_phase in completed, "EDGE_PHASE")
    semantic_step = len(completed[prior_phase]) + 3
    fixture = synthetic_r24d40_native_invariant_case_v1(
        core,
        phase=prior_phase,
        semantic_step=semantic_step,
    )
    publication = fixture["publication"]
    collection = deepcopy(publication["collection_request"])
    initialize_request = {
        "schema_version": "sporespore_recovery_initialize_request_v2",
        "task_id": collection["task_id"],
        "semantics_id": collection["semantics_id"],
        "actuator_profile_id": collection["actuator_profile_id"],
        "threshold_profile_id": runtime.PHYSICAL_THRESHOLD_PROFILE_ID,
        "descriptor": deepcopy(collection["descriptor"]),
        "morphology_context": deepcopy(collection["morphology_context"]),
        "adapter_capability": deepcopy(collection["adapter_capability"]),
        "arm_kind": "candidate_command",
    }
    initialized = core.recovery_initialize_v2(initialize_request)
    _require(initialized.get("support_status") == "supported_exact", "EDGE_INITIALIZE")
    memory = deepcopy(initialized["memory"])
    current_com_y = float(
        collection["observation"]["center_of_mass"]["position_world_m"]["y"]
    )
    memory.update(
        {
            "phase": prior_phase,
            "phase_steps_observed": 0,
            "ordered_completed_phases": completed[prior_phase],
            "total_steps_observed": semantic_step,
            "start_semantic_step": 0,
            "last_semantic_step": semantic_step - 1,
            "initial_center_of_mass_height_m": current_com_y - 0.25,
            "stance_dwell_steps_observed": 0,
            "terminal_failure_code": None,
        }
    )
    step = core.recovery_step_v3(
        {
            "schema_version": "sporespore_recovery_step_request_v3",
            "descriptor": deepcopy(collection["descriptor"]),
            "morphology_context": deepcopy(collection["morphology_context"]),
            "adapter_capability": deepcopy(collection["adapter_capability"]),
            "memory": memory,
            "observation": deepcopy(collection["observation"]),
        }
    )
    next_phase, transitioned = expected[prior_phase]
    _require(
        step.get("support_status") == "supported_exact"
        and step.get("prior_phase") == prior_phase
        and step.get("next_phase") == next_phase
        and step.get("transitioned") is transitioned,
        f"EDGE_STEP:{prior_phase}",
    )
    control = runtime.plan_stance_control_v1(core, collection, step)
    _require(
        control.get("support_status") == "supported_exact"
        and control.get("owner") == "stance"
        and control.get("recovery_controller_active") is False
        and control.get("observation_sha256") == step.get("observation_sha256")
        and control.get("model_construction_count") == 0
        and control.get("world_attempt_count") == 0
        and control.get("world_build_count") == 0
        and control.get("solver_step_count") == 0
        and control.get("physics_state_modified") is False,
        f"EDGE_CONTROL:{prior_phase}",
    )
    return {
        "prior_phase": prior_phase,
        "next_phase": next_phase,
        "transitioned": transitioned,
        "publication": publication,
        "collection": collection,
        "step": step,
        "control": control,
    }


class _MutatingCore:
    def __init__(self, core: LocomotionCore, mutation: str) -> None:
        self._core = core
        self._mutation = mutation

    def __getattr__(self, name: str) -> Any:
        return getattr(self._core, name)

    def recovery_development_profile_v1(self) -> dict[str, Any]:
        profile = deepcopy(self._core.recovery_development_profile_v1())
        if self._mutation == "pose_order":
            profile["stance_pose"]["ordered_joint_ids"][0:2] = reversed(
                profile["stance_pose"]["ordered_joint_ids"][0:2]
            )
        return profile

    def resolve_actuator_cap_profile_v1(
        self,
        profile_id: str,
        descriptor: Mapping[str, Any],
    ) -> dict[str, Any]:
        receipt = deepcopy(
            self._core.resolve_actuator_cap_profile_v1(profile_id, descriptor)
        )
        if self._mutation == "cap_order":
            receipt["profile"]["ordered_caps"][0:2] = reversed(
                receipt["profile"]["ordered_caps"][0:2]
            )
        return receipt


def _stance_request(edge: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": stance.REQUEST_SCHEMA,
        "controller_id": stance.STANCE_CONTROLLER_ID,
        "collection": deepcopy(edge["collection"]),
        "handoff_or_stance_step": deepcopy(edge["step"]),
    }


def _expect_stance_failure(
    core: Any,
    request: Mapping[str, Any],
    expected_code: str,
) -> bool:
    try:
        stance.plan_recovery_stance_control_v1(core, request)
    except stance.RecoveryStanceControlError as error:
        return str(error) == expected_code
    return False


def _zero_world_controls(
    core: LocomotionCore,
) -> tuple[dict[str, bool], dict[str, Any]]:
    contract = load_contract_v1()
    inherited = r42.run_zero_world_preflight(core)
    raise_edge = _edge_fixture(core, "raise_body")
    handoff_edge = _edge_fixture(core, "stance_handoff")
    dwell_edge = _edge_fixture(core, "stance_dwell")
    positive_commands = raise_edge["control"]["ordered_commands"]

    base = _stance_request(raise_edge)
    mutations: dict[str, tuple[Any, dict[str, Any], str]] = {}

    request = deepcopy(base)
    request["unexpected"] = True
    mutations["unknown_request_field"] = (core, request, "STANCE_REQUEST_KEYS")

    request = deepcopy(base)
    request["controller_id"] = "wrong_controller"
    mutations["wrong_controller_id"] = (core, request, "STANCE_CONTROLLER_ID")

    request = deepcopy(base)
    request["collection"]["arm_kind"] = "matched_zero_command"
    mutations["matched_zero_stance_seizure"] = (
        core,
        request,
        "STANCE_CANDIDATE_ARM",
    )

    request = deepcopy(base)
    request["handoff_or_stance_step"]["observation_sha256"] = "sha256:" + "f" * 64
    mutations["observation_digest_mismatch"] = (
        core,
        request,
        "STANCE_STEP_OBSERVATION_BINDING",
    )

    request = deepcopy(base)
    request["handoff_or_stance_step"]["next_phase"] = "stance_dwell"
    request["handoff_or_stance_step"]["memory"]["phase"] = "stance_dwell"
    mutations["phase_skip"] = (core, request, "STANCE_STEP_EDGE")

    request = deepcopy(base)
    request["handoff_or_stance_step"]["classification"]["raised_body_gate"] = False
    mutations["missing_raise_gate"] = (core, request, "STANCE_HANDOFF_GATES")

    request = deepcopy(base)
    request["handoff_or_stance_step"]["classification"]["safety_gate"] = False
    mutations["missing_safety_gate"] = (core, request, "STANCE_HANDOFF_GATES")

    request = _stance_request(handoff_edge)
    request["handoff_or_stance_step"]["classification"][
        "exclusive_stance_handoff_gate"
    ] = False
    mutations["missing_exclusive_owner_gate"] = (
        core,
        request,
        "STANCE_OWNERSHIP_GATE",
    )

    request = deepcopy(base)
    request["handoff_or_stance_step"]["memory"]["terminal_failure_code"] = (
        "retained_terminal_failure"
    )
    mutations["terminal_memory"] = (core, request, "STANCE_TERMINAL_MEMORY")

    mutations["cap_order_mismatch"] = (
        _MutatingCore(core, "cap_order"),
        deepcopy(base),
        "STANCE_CAP_IDENTITY:0",
    )
    mutations["stance_pose_order_mismatch"] = (
        _MutatingCore(core, "pose_order"),
        deepcopy(base),
        "STANCE_POSE_IDENTITY",
    )

    forced_failures = {
        name: _expect_stance_failure(core_like, request_value, expected)
        for name, (core_like, request_value, expected) in mutations.items()
    }
    try:
        runtime.require_stance_continuation_commissioned_v1(
            "stance_handoff",
            False,
        )
    except runtime.NativeRecoveryRouteError as error:
        forced_failures["uncommissioned_runner_default"] = str(error) == (
            "QSDK_R24D18_STANCE_HANDOFF_CONTROLLER_NOT_COMMISSIONED"
        )
    else:
        forced_failures["uncommissioned_runner_default"] = False

    signature = inspect.signature(runtime.run_paired_development)
    default_parameter = signature.parameters["continue_through_stance"]
    runtime.require_stance_continuation_commissioned_v1("stance_handoff", True)
    controls = {
        "r24d42_closure_and_audit_exact": (
            contract["lineage"]["predecessor_positive_closure_raw_sha256"]
            == shared._sha256_path(R42_CLOSURE_PATH)
            and contract["lineage"]["predecessor_closure_audit_raw_sha256"]
            == shared._sha256_path(R42_CLOSURE_AUDIT_PATH)
        ),
        "complete_r24d42_zero_world_route_replayed": (
            inherited["gate_id"] == r42.GATE_ID
            and inherited["control_count"] == r42.EXPECTED_CONTROL_COUNT
            and inherited["controls_passed"] == r42.EXPECTED_CONTROL_COUNT
            and inherited["forced_failure_count"] == r42.EXPECTED_FORCED_FAILURE_COUNT
            and inherited["world_attempt_count"] == 0
            and inherited["solver_step_count"] == 0
        ),
        "exact_stance_pose_and_actuator_caps_bound": (
            len(positive_commands) == 8
            and tuple(item["actuator_id"] for item in positive_commands)
            == stance.ORDERED_ACTUATOR_IDS
            and tuple(item["joint_id"] for item in positive_commands)
            == stance.ORDERED_JOINT_IDS
            and tuple(item["target_position_rad"] for item in positive_commands)
            == stance.STANCE_TARGET_POSITIONS_RAD
            and all(
                item["maximum_target_speed_rad_s"]
                == stance.MAXIMUM_STANCE_TARGET_SPEED_RAD_S
                for item in positive_commands
            )
        ),
        "handoff_step_observation_digest_bound": (
            raise_edge["control"]["observation_sha256"]
            == raise_edge["step"]["observation_sha256"]
            == raise_edge["publication"]["collection_receipt"]["observation_sha256"]
        ),
        "raise_body_to_handoff_edge_accepted": (
            raise_edge["next_phase"] == "stance_handoff"
            and raise_edge["transitioned"] is True
        ),
        "handoff_to_dwell_edge_accepted": (
            handoff_edge["next_phase"] == "stance_dwell"
            and handoff_edge["transitioned"] is True
        ),
        "dwell_continuation_edge_accepted": (
            dwell_edge["next_phase"] == "stance_dwell"
            and dwell_edge["transitioned"] is False
        ),
        "shared_runner_default_handoff_stop_preserved": (
            default_parameter.default is False
            and forced_failures["uncommissioned_runner_default"]
        ),
        "r24d43_explicit_continuation_wiring_exact": (
            runtime.STANCE_CONTROLLER_ID == stance.STANCE_CONTROLLER_ID
            and runtime._STANCE_PHASES == {"stance_handoff", "stance_dwell", "complete"}
        ),
        "zero_model_world_solver_and_physics_counts": all(
            edge["control"][field] == expected
            for edge in (raise_edge, handoff_edge, dwell_edge)
            for field, expected in (
                ("model_construction_count", 0),
                ("world_attempt_count", 0),
                ("world_build_count", 0),
                ("solver_step_count", 0),
                ("physics_state_modified", False),
            )
        ),
    }
    _require(all(controls.values()), "ZERO_WORLD_CONTROL_FAILED")
    _require(len(controls) == EXPECTED_CONTROL_COUNT, "CONTROL_COUNT")
    _require(all(forced_failures.values()), "FORCED_FAILURE_ACCEPTED")
    _require(
        len(forced_failures) == EXPECTED_FORCED_FAILURE_COUNT,
        "FORCED_FAILURE_COUNT",
    )
    return controls, {
        "inherited_r24d42_control_count": inherited["control_count"],
        "inherited_r24d42_forced_failure_count": inherited["forced_failure_count"],
        "forced_failure_count": len(forced_failures),
        "forced_failures": forced_failures,
        "edge_receipts": {
            edge["prior_phase"]: {
                "next_phase": edge["next_phase"],
                "transitioned": edge["transitioned"],
                "observation_sha256": edge["control"]["observation_sha256"],
                "command_sha256": edge["control"]["command_sha256"],
            }
            for edge in (raise_edge, handoff_edge, dwell_edge)
        },
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    """Run inherited conformance plus R43's compact integration controls."""

    inherited = r42.run_zero_world_preflight(core)
    controls, details = _zero_world_controls(core)
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "question_class": "non_physical_source_conformance",
            "behavior_question_opened": False,
            "natural_stop_phases": sorted(TERMINAL_STOP_PHASES),
            "terminal_stop_phases": sorted(TERMINAL_STOP_PHASES),
            "stance_handoff_is_stop": False,
            "stance_controller_id": stance.STANCE_CONTROLLER_ID,
            "control_count": len(controls),
            "controls_passed": sum(controls.values()),
            "forced_failure_count": details["forced_failure_count"],
            "exclusive_stance_completion_controls": controls,
            "exclusive_stance_completion_control_details": details,
            "development_integration_smoke_executed": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "exact_nominal_mujoco_prone_to_standing_observed": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
    )
    return receipt


def _arm_execution_checks_v1(arm: Mapping[str, Any]) -> dict[str, bool]:
    """Reuse the R42 route checks and replace only stop/control ownership semantics."""

    checks = dict(r42._arm_execution_checks_v3(arm))
    checks.pop("natural_stop_exact")
    checks.pop("route_and_request_family_exact")
    observations = arm["observations"]
    steps = arm["portable_step_receipts"]
    trace = arm["portable_request_trace"]
    count = len(observations)
    final_phase = arm["final_phase"]
    stopped = final_phase in TERMINAL_STOP_PHASES
    expected_control_count = count - 1 if stopped else count
    prior_terminal = [item["memory"]["phase"] for item in steps[:-1]]
    arm_kind = arm["arm_kind"]
    control_phases = [
        item["memory"]["phase"] for item in steps[:expected_control_count]
    ]
    expected_controls = [
        (
            stance.REQUEST_SCHEMA
            if arm_kind == "candidate_command" and phase in STANCE_PHASES
            else "sporespore_recovery_control_request_v3"
        )
        for phase in control_phases
    ]
    stance_control_indices = [
        index
        for index, schema in enumerate(trace["control_request_schemas"])
        if schema == stance.REQUEST_SCHEMA
    ]

    def ownership_exact(
        observation: Mapping[str, Any], step: Mapping[str, Any]
    ) -> bool:
        ownership = observation["controller_ownership"]
        if arm_kind == "matched_zero_command":
            return (
                ownership["owner"] == "none"
                and ownership["recovery_controller_id"] is None
                and ownership["stance_controller_id"] is None
            )
        if step["prior_phase"] in STANCE_PHASES:
            return (
                ownership["owner"] == "stance"
                and ownership["recovery_controller_id"] is None
                and ownership["stance_controller_id"] == stance.STANCE_CONTROLLER_ID
                and ownership["handoff_event_count"] == 1
                and ownership["fallback_controller_active"] is False
            )
        return (
            ownership["owner"] == "recovery"
            and ownership["recovery_controller_id"] == runtime.CONTROLLER_ID
            and ownership["stance_controller_id"] is None
            and ownership["handoff_event_count"] == 0
            and ownership["fallback_controller_active"] is False
        )

    checks.update(
        {
            "terminal_stop_exact": (
                stopped
                and bool(steps)
                and steps[-1]["memory"]["phase"] == final_phase
                and not any(phase in TERMINAL_STOP_PHASES for phase in prior_terminal)
            ),
            "route_and_request_families_exact": (
                arm["route_id"] == streaming.PUBLICATION_ROUTE_ID
                and arm["native_source_route_id"]
                == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
                and arm["portable_observation_schema"]
                == "sporespore_recovery_observation_v2"
                and trace["initialize_request_schema"]
                == "sporespore_recovery_initialize_request_v2"
                and trace["collection_request_schemas"]
                == ["sporespore_recovery_native_collection_request_v3"] * count
                and trace["step_request_schemas"]
                == ["sporespore_recovery_step_request_v3"] * count
                and trace["control_request_schemas"] == expected_controls
            ),
            "stance_continuation_explicitly_commissioned": (
                arm["stance_continuation_commissioned"] is True
            ),
            "controller_ownership_exclusive_and_phase_exact": all(
                ownership_exact(observation, step)
                for observation, step in zip(observations, steps, strict=True)
            ),
            "stance_control_is_candidate_only_contiguous_suffix": (
                (
                    bool(stance_control_indices)
                    and stance_control_indices
                    == list(range(stance_control_indices[0], expected_control_count))
                )
                if arm_kind == "candidate_command"
                else not stance_control_indices
            ),
        }
    )
    return checks


def compact_projection_v1(
    result: Mapping[str, Any],
    trace_invariants: Mapping[str, Any],
) -> dict[str, Any]:
    candidate = result["candidate"]
    matched = result["matched_zero_command"]
    evaluation = result["evaluation"]
    candidate_checks = _arm_execution_checks_v1(candidate)
    matched_checks = _arm_execution_checks_v1(matched)
    candidate_sequence = progression._arm_sequences(candidate)
    matched_sequence = progression._arm_sequences(matched)
    handoff = progression._transition_classification(
        candidate_sequence,
        "raise_body",
        "stance_handoff",
    )
    exclusive = progression._transition_classification(
        candidate_sequence,
        "stance_handoff",
        "stance_dwell",
    )
    completed = progression._transition_classification(
        candidate_sequence,
        "stance_dwell",
        "complete",
    )
    final_memory = candidate["portable_step_receipts"][-1]["memory"]
    candidate_stance_observations = [
        observation
        for observation, step in zip(
            candidate["observations"],
            candidate["portable_step_receipts"],
            strict=True,
        )
        if step["prior_phase"] in STANCE_PHASES
    ]
    candidate_control_schemas = candidate["portable_request_trace"][
        "control_request_schemas"
    ]
    matched_control_schemas = matched["portable_request_trace"][
        "control_request_schemas"
    ]
    total_outer = (
        candidate_sequence["outer_step_count"] + matched_sequence["outer_step_count"]
    )
    execution_checks = {
        "observation_v2_route_exact": result["route_id"]
        == streaming.PUBLICATION_ROUTE_ID,
        "paired_initializer_identity_matched": result["initializer_identity_matched"]
        is True,
        "model_world_counts_exact": (
            result["model_construction_count"] == 2
            and result["world_attempt_count"] == 2
            and result["world_build_count"] == 2
        ),
        "outer_and_solver_counts_exact_bounded": (
            result["outer_step_count"] == total_outer
            and total_outer <= EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS
            and result["native_solver_step_count"] == total_outer * 5
            and result["native_solver_step_count"]
            <= EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS
        ),
        "candidate_in_run_checks_pass": all(candidate_checks.values()),
        "matched_zero_in_run_checks_pass": all(matched_checks.values()),
        "complete_observation_v2_replay_pass": (
            trace_invariants["validated_outer_step_count"] == total_outer
            and trace_invariants["validated_native_substep_count"] == total_outer * 5
            and trace_invariants["portable_publication_replayed_exact"] is True
            and trace_invariants["streaming_chain_replayed_once"] is True
            and trace_invariants["final_legacy_full_aggregate_numeric_parity"] is True
            and trace_invariants["current_batch_mapping_cardinality_bounded"] is True
        ),
        "portable_evaluation_supported_valid": (
            result["portable_evaluation_request_schema"]
            == "sporespore_recovery_evaluation_request_v3"
            and evaluation["support_status"] == "supported_exact"
            and evaluation["physical_development_trace_valid"] is True
        ),
        "finite_development_claim_boundary_preserved": (
            result["stance_continuation_commissioned"] is True
            and result["prone_to_standing_claimed"] is False
            and result["repeatability_rate_claimed"] is False
            and result["population_claimed"] is False
            and result["cross_engine_recovery_claimed"] is False
            and result["cross_engine_equivalence_claimed"] is False
            and result["physical_acceptance_authority"] is False
            and result["release_authority"] is False
        ),
    }
    target_checks = {
        "candidate_reached_portable_complete": (
            candidate_sequence["final_phase"] == "complete"
            and candidate_sequence["terminal_failure_code"] is None
        ),
        "candidate_phase_sequence_exact": (
            candidate_sequence["transition_pairs"] == EXPECTED_SUCCESS_TRANSITIONS
        ),
        "recovery_handoff_gates_passed": (
            handoff.get("raised_body_gate") is True
            and handoff.get("safety_gate") is True
        ),
        "exclusive_stance_handoff_gate_passed": (
            exclusive.get("exclusive_stance_handoff_gate") is True
        ),
        "stable_stance_dwell_completed": (
            completed.get("stable_stance_gate") is True
            and final_memory["stance_dwell_steps_observed"] >= 60
        ),
        "stance_owner_observed_exclusively": (
            bool(candidate_stance_observations)
            and all(
                observation["controller_ownership"]["owner"] == "stance"
                and observation["controller_ownership"]["recovery_controller_id"]
                is None
                and observation["controller_ownership"]["stance_controller_id"]
                == stance.STANCE_CONTROLLER_ID
                for observation in candidate_stance_observations
            )
        ),
        "portable_stance_control_executed": (
            candidate_control_schemas.count(stance.REQUEST_SCHEMA) > 0
            and matched_control_schemas.count(stance.REQUEST_SCHEMA) == 0
        ),
        "matched_zero_failed_without_actuation": (
            matched_sequence["final_phase"] == "failed"
            and matched_sequence["terminal_failure_code"] is not None
            and matched_sequence["active_application_count"] == 0
            and matched_sequence["observations_all_zero_command"] is True
        ),
        "portable_evaluator_passed_exact_development_pair": (
            evaluation["verdict"] == "physical_development_passed"
            and evaluation["candidate_physical_path_completed"] is True
            and evaluation["matched_zero_command_physical_control_failed_to_complete"]
            is True
        ),
    }
    execution_valid = all(execution_checks.values())
    decision_positive = execution_valid and all(target_checks.values())
    return {
        "schema_version": COMPACT_PROJECTION_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "ledger_scope": {
            "subsystem": "recovery_stance_completion",
            "engine_scope": ["mujoco_native"],
            "authority_mode": "one_exact_paired_natural_stop_development_attempt",
            "question_class": "development",
        },
        "route_id": streaming.PUBLICATION_ROUTE_ID,
        "native_source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
        "portable_observation_schema": "sporespore_recovery_observation_v2",
        "cell_id": EXPECTED_CELL_ID,
        "seed": EXPECTED_SEED,
        "maximum_horizon_steps_per_arm": EXPECTED_MAXIMUM_HORIZON_STEPS,
        "candidate": candidate_sequence,
        "matched_zero_command": matched_sequence,
        "candidate_stance_observation_count": len(candidate_stance_observations),
        "candidate_stance_control_request_count": candidate_control_schemas.count(
            stance.REQUEST_SCHEMA
        ),
        "portable_evaluation_verdict": evaluation["verdict"],
        "execution_checks": execution_checks,
        "target_checks": target_checks,
        "trace_invariants": deepcopy(trace_invariants),
        "execution_valid": execution_valid,
        "decision_positive": decision_positive,
        "valid_negative_if_decision_not_positive": (
            execution_valid and not decision_positive
        ),
        "exact_nominal_mujoco_prone_to_standing_observed": decision_positive,
        "repeatability_rate_claimed": False,
        "population_claimed": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "cross_engine_recovery_claimed": False,
        "cross_engine_equivalence_claimed": False,
        "prone_to_standing_claimed": False,
        "prone_to_standing_release_acceptance_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _run_route(
    core_library: Path,
    contract: Mapping[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    core = LocomotionCore(core_library)
    exact_route = morphology.compile_recovery_morphology_model_route(core)
    streaming.validate_streaming_morphology_route_v1(core, exact_route)
    result = runtime.run_paired_development(
        core,
        cell=deepcopy(contract["selected_development_cell"]),
        horizon_steps=EXPECTED_MAXIMUM_HORIZON_STEPS,
        route=exact_route,
        world_type=streaming.MujocoRecoveryMorphologyStreamingObservationV2World,
        behavior_claim_authority=False,
        continue_through_stance=True,
    )
    invariants = r42.validate_observation_v2_trace_v1(
        core,
        result,
        arm_checks=_arm_execution_checks_v1,
        receipt_schema=TRACE_INVARIANTS_SCHEMA,
    )
    return result, invariants


def run_and_publish_v1(
    *,
    core_library: Path,
    contract_path: Path,
    output_directory: Path,
    source_commit: str,
    qualification_receipt_path: Path,
    operation_lock_receipt_path: Path,
) -> dict[str, Any]:
    _require(output_directory.is_dir(), "OUTPUT_DIRECTORY")
    contract = load_contract_v1(contract_path)
    qualification = shared._load_json(qualification_receipt_path)
    operation_lock = shared._load_json(operation_lock_receipt_path)
    _require(
        qualification["schema_version"] == QUALIFICATION_RECEIPT_SCHEMA
        and qualification["gate_id"] == GATE_ID
        and qualification["ok"] is True
        and qualification["mode"] == "qualification"
        and qualification["source_commit"] == source_commit,
        "QUALIFICATION_RECEIPT",
    )
    _require(
        operation_lock["acquired"] is True
        and operation_lock["role"] == "physical"
        and operation_lock["test_only"] is False,
        "OPERATION_LOCK",
    )
    result, invariants = _run_route(core_library, contract)
    projection = compact_projection_v1(result, invariants)
    envelope = {
        "schema_version": FULL_RESULT_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "ledger_scope": deepcopy(contract["ledger_scope"]),
        "source_commit": source_commit,
        "contract_path": contract_path.as_posix(),
        "contract_raw_sha256": shared._sha256_path(contract_path),
        "qualification_receipt_path": str(qualification_receipt_path),
        "qualification_receipt_raw_sha256": shared._sha256_path(
            qualification_receipt_path
        ),
        "operation_lock": operation_lock,
        "predecessor_gate_id": r42.GATE_ID,
        "result": result,
        "trace_invariants": invariants,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "repeatability_rate_claimed": False,
        "population_claimed": False,
        "cross_engine_recovery_claimed": False,
        "cross_engine_equivalence_claimed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    full_path = output_directory / "paired_full_result.json"
    full_sha256 = shared._write_json_exclusive(full_path, envelope)
    projection["source_commit"] = source_commit
    projection["full_result_path"] = full_path.name
    projection["full_result_raw_sha256"] = full_sha256
    summary_path = output_directory / "paired_summary.json"
    summary_sha256 = shared._write_json_exclusive(summary_path, projection)
    manifest = {
        "schema_version": MANIFEST_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "source_commit": source_commit,
        "artifacts": [
            {
                "path": full_path.name,
                "raw_sha256": full_sha256,
                "byte_length": full_path.stat().st_size,
            },
            {
                "path": summary_path.name,
                "raw_sha256": summary_sha256,
                "byte_length": summary_path.stat().st_size,
            },
        ],
        "execution_valid": projection["execution_valid"],
        "decision_positive": projection["decision_positive"],
        "complete_trace_retained": True,
        "compact_projection_retained": True,
        "held_out_cell_access_count": 0,
        "repeatability_rate_claimed": False,
        "population_claimed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    manifest_path = output_directory / "manifest.json"
    manifest_sha256 = shared._write_json_exclusive(manifest_path, manifest)
    return {
        "ok": bool(projection["execution_valid"]),
        "execution_valid": bool(projection["execution_valid"]),
        "decision_positive": bool(projection["decision_positive"]),
        "summary_path": str(summary_path),
        "summary_raw_sha256": summary_sha256,
        "manifest_path": str(manifest_path),
        "manifest_raw_sha256": manifest_sha256,
        "exact_nominal_mujoco_prone_to_standing_observed": bool(
            projection["exact_nominal_mujoco_prone_to_standing_observed"]
        ),
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _publish_invalid(
    error: Exception,
    *,
    output_directory: Path,
    source_commit: str,
) -> dict[str, Any]:
    diagnostic = getattr(error, "diagnostic", None)
    invalid = {
        "schema_version": INVALID_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "source_commit": source_commit,
        "error_type": type(error).__name__,
        "error": str(error),
        "traceback": traceback.format_exc(),
        "native_collection_refusal_diagnostic": (
            deepcopy(diagnostic) if isinstance(diagnostic, dict) else None
        ),
        "invalid_or_incomplete_retained": True,
        "valid_behavior_result_observed": False,
        "valid_physical_behavior_result_observed": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "repeatability_rate_claimed": False,
        "population_claimed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    if output_directory.is_dir():
        shared._write_json_exclusive(output_directory / "invalid_result.json", invalid)
    return invalid


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    preflight = commands.add_parser("preflight")
    preflight.add_argument("--core-library", type=Path, required=True)
    run = commands.add_parser("run")
    run.add_argument("--core-library", type=Path, required=True)
    run.add_argument("--contract", type=Path, required=True)
    run.add_argument("--output-directory", type=Path, required=True)
    run.add_argument("--source-commit", required=True)
    run.add_argument("--qualification-receipt", type=Path, required=True)
    run.add_argument("--operation-lock-receipt", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    if arguments.command == "preflight":
        receipt = run_zero_world_preflight(
            LocomotionCore(arguments.core_library.resolve())
        )
        print(
            json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 0
    try:
        completion = run_and_publish_v1(
            core_library=arguments.core_library.resolve(),
            contract_path=arguments.contract.resolve(),
            output_directory=arguments.output_directory.resolve(),
            source_commit=str(arguments.source_commit),
            qualification_receipt_path=arguments.qualification_receipt.resolve(),
            operation_lock_receipt_path=arguments.operation_lock_receipt.resolve(),
        )
        print(json.dumps(completion, allow_nan=False, sort_keys=True))
        return 0 if completion["ok"] else 3
    except Exception as error:
        invalid = _publish_invalid(
            error,
            output_directory=arguments.output_directory.resolve(),
            source_commit=str(arguments.source_commit),
        )
        print(json.dumps(invalid, allow_nan=False, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
