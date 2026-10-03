"""R24D42 direct observation-V2 natural recovery progression worker."""

from __future__ import annotations

import argparse
from copy import deepcopy
import json
from pathlib import Path
import traceback
from typing import Any, Callable, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import native_recovery_development as runtime
from . import qsdk_r24d18_recovery_development_worker as shared
from . import qsdk_r24d27_natural_recovery_progression_worker as progression
from . import qsdk_r24d41_observation_v2_morphology_smoke_worker as r41
from . import recovery_morphology_route as morphology
from . import recovery_energy_v2_mapping as full_mapping
from . import recovery_observation_v2_morphology_route as conjunction
from . import recovery_observation_v2_route as observation_v2
from . import recovery_observation_v2_streaming_route as streaming
from . import selected_policy_development as base
from .recovery_observation_v2_route_fixture import (
    synthetic_r24d40_native_invariant_case_v1,
)


GATE_ID = "QSDK-R24D42"
CAMPAIGN_ID = "QSDK-R24D42-MUJOCO-OBSERVATION-V2-NATURAL-RECOVERY-PROGRESSION"
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_contract_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_preflight_v1"
)
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_"
    "zero_world_receipt_v1"
)
FULL_RESULT_SCHEMA = (
    "sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_full_result_v1"
)
COMPACT_PROJECTION_SCHEMA = (
    "sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_"
    "compact_projection_v1"
)
MANIFEST_SCHEMA = (
    "sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_manifest_v1"
)
INVALID_SCHEMA = (
    "sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_invalid_v1"
)
EXPECTED_CELL_ID = progression.EXPECTED_CELL_ID
EXPECTED_SEED = progression.EXPECTED_SEED
EXPECTED_MAXIMUM_HORIZON_STEPS = progression.EXPECTED_MAXIMUM_HORIZON_STEPS
EXPECTED_PAIRED_ARM_COUNT = progression.EXPECTED_PAIRED_ARM_COUNT
EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS = progression.EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS
EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS = (
    progression.EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS
)
EXPECTED_SOURCE_INVENTORY_COUNT = 37
EXPECTED_CONTROL_COUNT = 9
EXPECTED_FORCED_FAILURE_COUNT = 21
REPO_ROOT = Path(__file__).resolve().parents[4]
CONTRACT_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d42_mujoco_observation_v2_natural_progression_contract_v1.json"
)
R32_CONTRACT_PATH = (
    REPO_ROOT / "sdk/recovery/r24d32_corrected_energy_progression_contract_v1.json"
)
R32_CLOSURE_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d32_corrected_energy_progression_physical_closure_v1.json"
)
R32_CLOSURE_AUDIT_PATH = (
    REPO_ROOT
    / "tests/test_qsdk_r24d32_corrected_energy_progression_physical_closure.py"
)
R41_CLOSURE_PATH = (
    REPO_ROOT / "sdk/recovery/"
    "r24d41_mujoco_recovery_morphology_observation_v2_smoke_positive_closure_v1.json"
)
R41_CLOSURE_AUDIT_PATH = (
    REPO_ROOT
    / "tests/test_qsdk_r24d41_observation_v2_morphology_smoke_positive_closure.py"
)
R32_CONTRACT_SHA256 = (
    "sha256:47e07753b5e2a13e8773bec5d9afacaf99b9f64a706624e2aed712216bf42a03"
)
R32_CLOSURE_SHA256 = (
    "sha256:d2c84767823171406a868f6ccda4331b210d3c517974d0ae018c6e357e802eb8"
)
R32_CLOSURE_AUDIT_SHA256 = (
    "sha256:77a03662cd9dd9f77b9cc3fa2b830c894b1aae104298ac9b4a5482ae8ea78271"
)
R41_CLOSURE_SHA256 = (
    "sha256:179967c0720d0f0c2508ce9f01ad6c8d359302dc852d9ef97e07ad9e89258f5c"
)
R41_CLOSURE_AUDIT_SHA256 = (
    "sha256:93f558c44b6bc405b99966274dfcf44bee70aca58621dfbc17744c01ad2771e5"
)


class R24D42WorkerError(RuntimeError):
    """Stable fail-closed R24D42 worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D42WorkerError(code)


def _canonical_sha256(core: LocomotionCore, value: Mapping[str, Any]) -> str:
    digest = core.canonicalize_json(deepcopy(dict(value))).get("sha256")
    _require(
        isinstance(digest, str) and digest.startswith("sha256:") and len(digest) == 71,
        "CANONICAL_SHA256",
    )
    return digest


def _require_replayed_streaming_state_v1(
    core: LocomotionCore,
    actual: Mapping[str, Any],
    expected: Mapping[str, Any],
) -> dict[str, Any]:
    validated = streaming.validate_streaming_state_v1(core, actual)
    _require(validated == dict(expected), "STREAMING_STATE_REPLAY_MISMATCH")
    return validated


def load_contract_v1(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    contract = shared._load_json(path)
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "QUESTION_CLASS")
    _require(contract.get("physical_question_declared") is True, "PHYSICAL_QUESTION")
    _require(contract.get("behavior_question_declared") is True, "BEHAVIOR_QUESTION")
    lineage = contract["lineage"]
    _require(
        lineage["behavior_predecessor_contract_raw_sha256"]
        == shared._sha256_path(R32_CONTRACT_PATH)
        == R32_CONTRACT_SHA256
        and lineage["behavior_predecessor_closure_raw_sha256"]
        == shared._sha256_path(R32_CLOSURE_PATH)
        == R32_CLOSURE_SHA256
        and lineage["behavior_predecessor_closure_audit_raw_sha256"]
        == shared._sha256_path(R32_CLOSURE_AUDIT_PATH)
        == R32_CLOSURE_AUDIT_SHA256
        and lineage["route_predecessor_closure_raw_sha256"]
        == shared._sha256_path(R41_CLOSURE_PATH)
        == R41_CLOSURE_SHA256
        and lineage["route_predecessor_closure_audit_raw_sha256"]
        == shared._sha256_path(R41_CLOSURE_AUDIT_PATH)
        == R41_CLOSURE_AUDIT_SHA256,
        "LINEAGE",
    )
    cell = contract["selected_development_cell"]
    horizon = contract["ghost_horizon"]
    _require(
        cell["cell_id"] == EXPECTED_CELL_ID
        and cell["seed"] == EXPECTED_SEED
        and cell["random_draw_count"] == 0,
        "CELL",
    )
    _require(
        horizon["outer_steps_per_arm"] == EXPECTED_MAXIMUM_HORIZON_STEPS
        and horizon["maximum_steps_per_arm"] == EXPECTED_MAXIMUM_HORIZON_STEPS
        and horizon["paired_arm_count"] == EXPECTED_PAIRED_ARM_COUNT
        and horizon["maximum_total_outer_steps"] == EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS
        and horizon["maximum_total_native_solver_steps"]
        == EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS
        and set(horizon["existing_route_stop_phases"])
        == progression.NATURAL_STOP_PHASES,
        "HORIZON",
    )
    threshold = contract["threshold_margin_and_population_provenance"]
    _require(
        threshold["maximum_energy_balance_residual_j"] == 0.25
        and threshold["new_behavior_threshold_count"] == 0
        and threshold["new_empirical_threshold_count"] == 0
        and threshold["new_statistical_margin_count"] == 0,
        "THRESHOLD",
    )
    inventory = contract["source_inventory"]
    _require(
        len(inventory)
        == len(set(inventory))
        == contract["prospective_freeze"]["source_inventory_count"]
        == EXPECTED_SOURCE_INVENTORY_COUNT,
        "SOURCE_INVENTORY",
    )
    return contract


def _progression_mutation_controls() -> dict[str, bool]:
    positive = progression._positive_control_facts()
    _require(
        all(progression.evaluate_progression_facts_v1(positive).values()), "POSITIVE"
    )
    mutations = {
        "candidate_terminal_failure_rejected": ("candidate_final_phase", "failed"),
        "candidate_phase_skip_rejected": (
            "candidate_transition_pairs",
            [
                ["confirm_prone", "establish_distal_support"],
                ["establish_distal_support", "stance_handoff"],
            ],
        ),
        "unmeasured_handoff_gate_rejected": (
            "candidate_handoff_raised_body_gate",
            False,
        ),
        "first_application_only_rejected": (
            "candidate_active_application_count",
            1,
        ),
        "matched_zero_nonterminal_rejected": (
            "matched_zero_final_phase",
            "establish_distal_support",
        ),
        "matched_zero_actuation_rejected": (
            "matched_zero_active_application_count",
            1,
        ),
    }
    checks: dict[str, bool] = {}
    for name, (field, replacement) in mutations.items():
        mutated = deepcopy(positive)
        mutated[field] = replacement
        checks[name] = not all(
            progression.evaluate_progression_facts_v1(mutated).values()
        )
    return checks


def _streaming_mapping_controls(
    core: LocomotionCore,
) -> tuple[dict[str, Any], int]:
    """Prove bounded current-batch work and exact cumulative numeric parity."""

    case = synthetic_r24d40_native_invariant_case_v1(core)
    prototype_publication = case["publication"]
    prototype_observation = prototype_publication["portable_observation"]
    prototype_native = case["native_step"]
    collection = prototype_publication["collection_request"]
    initial_energy = float(
        prototype_observation["energy_balance"]["initial_mechanical_energy_j"]
    )
    state = streaming.initial_streaming_state_v1(
        core,
        initial_mechanical_energy_j=initial_energy,
        arm_kind="candidate_command",
    )
    prefixes = {1, 2, 4, 8, 16, 32, 64}
    batches: list[dict[str, Any]] = []
    parity_prefixes: list[int] = []
    publication_byte_lengths: list[int] = []
    state_byte_lengths: list[int] = []
    first_request: dict[str, Any] | None = None
    first_native: dict[str, Any] | None = None
    first_publication: dict[str, Any] | None = None
    first_next_state: dict[str, Any] | None = None

    def numeric_projection(observation: Mapping[str, Any]) -> dict[str, Any]:
        value = deepcopy(dict(observation))
        ledger = value["energy_balance"]
        ledger.pop("source_profile_id")
        ledger.pop("source_values_sha256")
        return value

    for semantic_step in range(64):
        native = deepcopy(prototype_native)
        duration_s = float(native["time_after_s"] - native["time_before_s"])
        native.update(
            {
                "semantic_step": semantic_step,
                "host_step_before": semantic_step,
                "host_step_after": semantic_step + 1,
                "time_before_s": semantic_step * duration_s,
                "time_after_s": (semantic_step + 1) * duration_s,
                "solver_step_count_after": (semantic_step + 1) * 5,
                "current_mechanical_energy_j": (
                    float(prototype_native["current_mechanical_energy_j"])
                    + semantic_step * 1.0e-6
                ),
            }
        )
        observation = deepcopy(prototype_observation)
        observation["semantic_step"] = semantic_step
        observation["state"]["semantic_step"] = semantic_step
        observation["state"]["sample_time_s"] = native["time_after_s"]
        observation["applied_actuation"]["source_semantic_step"] = semantic_step
        observation["energy_balance"]["current_mechanical_energy_j"] = native[
            "current_mechanical_energy_j"
        ]
        observation["engine_step_identity"].update(
            {
                "semantic_step": semantic_step,
                "host_step_before": semantic_step,
                "host_step_after": semantic_step + 1,
                "source_trace_sha256": _canonical_sha256(core, native),
            }
        )
        request = streaming.streaming_mapping_request_v1(
            observation=observation,
            native_step=native,
        )
        prior_state = deepcopy(state)
        publication, state = streaming.publish_recovery_observation_v2_streaming_v1(
            core,
            mapping_request=request,
            prior_state=prior_state,
            descriptor=collection["descriptor"],
            morphology_context=collection["morphology_context"],
            capability_sha256=collection["runtime_binding"]["capability_sha256"],
            runtime_qualification_sha256=collection["runtime_binding"][
                "runtime_qualification_sha256"
            ],
            arm_kind="candidate_command",
            phase=collection["phase"],
        )
        invariant, replayed_state = streaming.validate_streaming_publication_in_run_v1(
            core,
            publication=publication,
            native_step=native,
            mapping_request=request,
            prior_state=prior_state,
            descriptor=collection["descriptor"],
            morphology_context=collection["morphology_context"],
            capability_sha256=collection["runtime_binding"]["capability_sha256"],
            runtime_qualification_sha256=collection["runtime_binding"][
                "runtime_qualification_sha256"
            ],
            expected_arm_kind="candidate_command",
            expected_phase=collection["phase"],
        )
        _require(
            publication["support_status"] == "supported_exact"
            and invariant["publication_replayed_exact"] is True,
            "STREAMING_SYNTHETIC_PUBLICATION",
        )
        _require_replayed_streaming_state_v1(core, replayed_state, state)
        batch = deepcopy(request["native_component_batch"])
        batches.append(batch)
        mapping = publication["mapping_receipt"]
        _require(
            len(mapping["current_batch_component_mappings"]) == 5
            and len(mapping["current_batch_ordered_increments"]) == 5
            and mapping["native_component_batch_count"] == semantic_step + 1
            and mapping["native_component_receipt_count"] == (semantic_step + 1) * 5
            and mapping["prior_history_replayed_in_current_step"] is False,
            "STREAMING_CURRENT_BATCH_CARDINALITY",
        )
        publication_byte_lengths.append(len(shared._canonical_bytes(publication)))
        state_byte_lengths.append(len(shared._canonical_bytes(state)))
        if semantic_step + 1 in prefixes:
            legacy = full_mapping.map_r24d36_components_to_recovery_observation_v2(
                core,
                {
                    "schema_version": full_mapping.MAPPING_REQUEST_SCHEMA,
                    "source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
                    "initial_mechanical_energy_j": initial_energy,
                    "current_mechanical_energy_j": native[
                        "current_mechanical_energy_j"
                    ],
                    "observation_base": deepcopy(request["observation_base"]),
                    "ordered_native_component_batches": deepcopy(batches),
                },
            )
            _require(
                legacy["support_status"] == "supported_exact"
                and numeric_projection(legacy["portable_observation"])
                == numeric_projection(publication["portable_observation"]),
                f"STREAMING_LEGACY_NUMERIC_PARITY:{semantic_step + 1}",
            )
            parity_prefixes.append(semantic_step + 1)
        if semantic_step == 0:
            first_request = deepcopy(request)
            first_native = deepcopy(native)
            first_publication = deepcopy(publication)
            first_next_state = deepcopy(state)

    _require(
        parity_prefixes == sorted(prefixes)
        and state["next_semantic_step"] == 64
        and state["native_component_receipt_count"] == 320,
        "STREAMING_SYNTHETIC_PREFIXES",
    )
    _require(
        first_request is not None
        and first_native is not None
        and first_publication is not None
        and first_next_state is not None,
        "STREAMING_SYNTHETIC_FIRST_STEP",
    )
    genesis = streaming.initial_streaming_state_v1(
        core,
        initial_mechanical_energy_j=initial_energy,
        arm_kind="candidate_command",
    )

    mutation_checks: dict[str, bool] = {}

    bad_digest = deepcopy(genesis)
    bad_digest["state_sha256"] = "sha256:" + ("f" * 64)
    try:
        streaming.map_native_batch_to_streaming_observation_v2_v1(
            core, first_request, bad_digest
        )
    except streaming.RecoveryObservationV2StreamingError:
        mutation_checks["prior_state_digest_mutation_rejected"] = True

    bad_chain = deepcopy(first_next_state)
    bad_chain["source_chain_sha256"] = "sha256:" + ("e" * 64)
    bad_chain_payload = {
        key: value for key, value in bad_chain.items() if key != "state_sha256"
    }
    bad_chain["state_sha256"] = _canonical_sha256(core, bad_chain_payload)
    try:
        _require_replayed_streaming_state_v1(core, bad_chain, first_next_state)
    except R24D42WorkerError:
        mutation_checks["recomputed_source_chain_mutation_rejected_by_replay"] = True

    skipped = deepcopy(first_request)
    skipped["native_component_batch"]["semantic_step"] = 1
    try:
        streaming.map_native_batch_to_streaming_observation_v2_v1(
            core, skipped, genesis
        )
    except streaming.RecoveryObservationV2StreamingError:
        mutation_checks["semantic_step_skip_rejected"] = True

    bad_component = deepcopy(first_request)
    bad_component["native_component_batch"]["ordered_substep_receipts"][0][
        "implicit_v3"
    ]["effective_centered_actuator_work_j"] += 0.01
    try:
        streaming.map_native_batch_to_streaming_observation_v2_v1(
            core, bad_component, genesis
        )
    except (streaming.RecoveryObservationV2StreamingError, ValueError):
        mutation_checks["native_component_mutation_rejected"] = True

    bad_publication = deepcopy(first_publication)
    bad_publication["mapping_receipt"]["prior_state_sha256"] = "sha256:" + ("d" * 64)
    try:
        streaming.validate_streaming_publication_in_run_v1(
            core,
            publication=bad_publication,
            native_step=first_native,
            mapping_request=first_request,
            prior_state=genesis,
            descriptor=collection["descriptor"],
            morphology_context=collection["morphology_context"],
            capability_sha256=collection["runtime_binding"]["capability_sha256"],
            runtime_qualification_sha256=collection["runtime_binding"][
                "runtime_qualification_sha256"
            ],
            expected_arm_kind="candidate_command",
            expected_phase=collection["phase"],
        )
    except streaming.RecoveryObservationV2StreamingError:
        mutation_checks["publication_mapping_mutation_rejected"] = True

    crossed_mapping = deepcopy(first_publication["mapping_receipt"])
    crossed_mapping["portable_observation"]["energy_balance"]["source_profile_id"] = (
        full_mapping.MAPPING_PROFILE_ID
    )
    crossed_mapping["ledger_sha256"] = _canonical_sha256(
        core, crossed_mapping["portable_observation"]["energy_balance"]
    )
    crossed_mapping["portable_observation_sha256"] = _canonical_sha256(
        core, crossed_mapping["portable_observation"]
    )
    try:
        observation_v2.publish_recovery_observation_v2_mapping_v1(
            core,
            mapping=crossed_mapping,
            descriptor=collection["descriptor"],
            morphology_context=collection["morphology_context"],
            capability_sha256=collection["runtime_binding"]["capability_sha256"],
            runtime_qualification_sha256=collection["runtime_binding"][
                "runtime_qualification_sha256"
            ],
            arm_kind="candidate_command",
            phase=collection["phase"],
            mapping_profile_id=streaming.MAPPING_PROFILE_ID,
            mapping_receipt_schema=streaming.MAPPING_RECEIPT_SCHEMA,
            publisher_id=streaming.PUBLISHER_ID,
        )
    except observation_v2.RecoveryObservationV2PublicationError:
        mutation_checks["mapping_and_ledger_profile_cross_rejected"] = True

    _require(
        len(mutation_checks) == 6 and all(mutation_checks.values()),
        "STREAMING_MUTATION_CONTROLS",
    )
    return {
        "mapping_profile_id": streaming.MAPPING_PROFILE_ID,
        "publication_route_id": streaming.PUBLICATION_ROUTE_ID,
        "synthetic_step_count": 64,
        "numeric_parity_prefixes": parity_prefixes,
        "final_source_chain_sha256": state["source_chain_sha256"],
        "final_state_sha256": state["state_sha256"],
        "minimum_publication_canonical_byte_length": min(publication_byte_lengths),
        "maximum_publication_canonical_byte_length": max(publication_byte_lengths),
        "minimum_state_canonical_byte_length": min(state_byte_lengths),
        "maximum_state_canonical_byte_length": max(state_byte_lengths),
        "current_batch_component_mapping_count": 5,
        "current_batch_ordered_increment_count": 5,
        "prior_history_replayed_in_current_step": False,
        "mutation_controls": mutation_checks,
    }, len(mutation_checks)


def _zero_world_controls(
    core: LocomotionCore,
) -> tuple[dict[str, bool], dict[str, Any]]:
    contract = load_contract_v1()
    contract32 = shared._load_json(R32_CONTRACT_PATH)
    closure32 = shared._load_json(R32_CLOSURE_PATH)
    closure41 = shared._load_json(R41_CLOSURE_PATH)
    inherited = r41.run_zero_world_preflight(core)
    exact_route = morphology.compile_recovery_morphology_model_route(core)
    conjunction_receipt = streaming.validate_streaming_morphology_route_v1(
        core,
        exact_route,
    )
    progression_mutations = _progression_mutation_controls()
    streaming_controls, streaming_mutations = _streaming_mapping_controls(core)
    cell = contract["selected_development_cell"]
    horizon = contract["ghost_horizon"]
    threshold = contract["threshold_margin_and_population_provenance"]
    change = contract["controlled_change"]
    claims = contract["claim_boundary"]
    controls = {
        "r24d41_positive_closure_is_exact_and_not_reexecuted": (
            closure41["closure_status"]
            == "closed_complete_execution_valid_native_observation_v2_route_integration_positive_behavior_incomplete"
            and closure41["decision"]["r24d41_may_be_rerun"] is False
            and closure41["decision"][
                "exact_recovery_morphology_observation_v2_route_conjunction_proven"
            ]
            is True
            and closure41["physical_attempt"]["native_solver_step_count"] == 10
            and contract["complete_zero_world_gate"][
                "historical_closure_audits_reexecuted"
            ]
            is False
        ),
        "r24d32_negative_behavior_contract_is_exact_and_not_reexecuted": (
            closure32["closure_status"]
            == "closed_consumed_execution_valid_development_negative_corrected_energy_residual_above_unchanged_limit_no_handoff"
            and closure32["next_boundary"]["r24d32_may_be_requalified"] is False
            and closure32["claim_boundary"][
                "complete_physical_development_trace_observed"
            ]
            is True
            and closure32["claim_boundary"]["recovery_to_stance_handoff_observed"]
            is False
        ),
        "recovery_morphology_observation_v2_conjunction_compiles_at_zero_world": (
            conjunction_receipt["ok"] is True
            and conjunction_receipt["compiled_receipt_schema"]
            == conjunction.EXPECTED_COMPILED_SCHEMA
            and conjunction_receipt["model_xml_sha256"]
            == contract["route_identity"]["model_xml_sha256"]
            and conjunction_receipt["model_construction_count"] == 0
            and conjunction_receipt["world_attempt_count"] == 0
            and conjunction_receipt["solver_step_count"] == 0
        ),
        "r24d41_nine_route_and_invariant_forced_failures_remain_closed": (
            inherited["control_count"] == 8
            and inherited["controls_passed"] == 8
            and inherited["forced_failure_count"] == 9
            and inherited["recovery_morphology_observation_v2_control_details"][
                "candidate_invariant_receipt_sha256"
            ]
            == "sha256:4a9eba58be2902889c0099b656cf527b8350ec7dcb74fcb4ae82116dcd1a0b96"
            and inherited["recovery_morphology_observation_v2_control_details"][
                "matched_zero_invariant_receipt_sha256"
            ]
            == "sha256:6ef8e7dc6e2144f4d211bee004cba8753ade6d929c137cea10d341ec2144a7ee"
        ),
        "r24d27_six_progression_decision_mutations_remain_rejected": (
            len(progression_mutations) == 6 and all(progression_mutations.values())
        ),
        "streaming_mapping_is_current_batch_bounded_numerically_exact_and_mutations_fail_closed": (
            streaming_controls["numeric_parity_prefixes"] == [1, 2, 4, 8, 16, 32, 64]
            and streaming_controls["current_batch_component_mapping_count"] == 5
            and streaming_controls["current_batch_ordered_increment_count"] == 5
            and streaming_controls["prior_history_replayed_in_current_step"] is False
            and streaming_mutations == 6
        ),
        "v3_natural_progression_projection_preserves_the_r24d32_behavior_facts": (
            contract["route_identity"]["evaluation_request_schema"]
            == "sporespore_recovery_evaluation_request_v3"
            and contract["controlled_change"]["progression_decision_facts_changed"]
            is False
            and contract["controlled_change"]["progression_evaluator_meaning_changed"]
            is False
            and all(
                progression.evaluate_progression_facts_v1(
                    progression._positive_control_facts()
                ).values()
            )
        ),
        "cell_seed_horizon_natural_stops_controller_evaluator_thresholds_and_margins_are_unchanged": (
            all(
                cell[key] == contract32["selected_development_cell"][key]
                for key in (
                    "cohort_id",
                    "question_class",
                    "cell_id",
                    "initial_state_id",
                    "torso_roll_rad",
                    "seed_label",
                    "seed_sha256",
                    "seed",
                    "random_draw_count",
                )
            )
            and horizon["outer_steps_per_arm"]
            == contract32["ghost_horizon"]["outer_steps_per_arm"]
            and set(horizon["existing_route_stop_phases"])
            == set(contract32["ghost_horizon"]["existing_route_stop_phases"])
            and threshold["maximum_energy_balance_residual_j"]
            == contract32["threshold_and_adequacy_authority"][
                "maximum_energy_balance_residual_j"
            ]
            and change["controller_changed"] is False
            and change["behavior_thresholds_changed"] is False
            and change["margins_changed"] is False
        ),
        "one_qualification_then_one_direct_full_run_has_no_extra_canary_heldout_population_or_release_authority": (
            contract["development_integration_smoke"]["required"] is False
            and contract["development_integration_smoke"][
                "new_physical_canary_authorized"
            ]
            is False
            and contract["qualification_and_physical_authority"][
                "official_physical_attempt_count_after_qualification"
            ]
            == 1
            and contract["held_out_seal"]["held_out_cell_access_count"] == 0
            and contract["held_out_seal"]["held_out_selector_invocation_count"] == 0
            and claims["population_claimed"] is False
            and claims["prone_to_standing_claimed"] is False
            and claims["release_authority"] is False
        ),
    }
    return controls, {
        "r24d32_contract_raw_sha256": shared._sha256_path(R32_CONTRACT_PATH),
        "r24d32_closure_raw_sha256": shared._sha256_path(R32_CLOSURE_PATH),
        "r24d41_closure_raw_sha256": shared._sha256_path(R41_CLOSURE_PATH),
        "r24d41_inherited_control_count": inherited["control_count"],
        "r24d41_inherited_forced_failure_count": inherited["forced_failure_count"],
        "progression_forced_failure_count": len(progression_mutations),
        "streaming_mapping_forced_failure_count": streaming_mutations,
        "forced_failure_count": (
            inherited["forced_failure_count"]
            + len(progression_mutations)
            + streaming_mutations
        ),
        "conjunction_receipt_sha256": conjunction_receipt["receipt_sha256"],
        "model_xml_sha256": conjunction_receipt["model_xml_sha256"],
        "progression_mutation_controls": progression_mutations,
        "streaming_mapping_controls": streaming_controls,
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = r41.run_zero_world_preflight(core)
    controls, details = _zero_world_controls(core)
    _require(all(controls.values()), "ZERO_WORLD_CONTROL_FAILED")
    _require(len(controls) == EXPECTED_CONTROL_COUNT, "CONTROL_COUNT")
    _require(
        details["forced_failure_count"] == EXPECTED_FORCED_FAILURE_COUNT,
        "FORCED_FAILURE_COUNT",
    )
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "gate_id": GATE_ID,
            "route_id": streaming.PUBLICATION_ROUTE_ID,
            "native_source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
            "mapping_profile_id": streaming.MAPPING_PROFILE_ID,
            "conjunction_schema": streaming.CONJUNCTION_SCHEMA,
            "question_class": "non_physical_source_conformance",
            "behavior_question_opened": False,
            "maximum_horizon_steps_per_arm": EXPECTED_MAXIMUM_HORIZON_STEPS,
            "maximum_total_outer_steps": EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS,
            "maximum_total_native_solver_steps": (
                EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS
            ),
            "natural_stop_phases": sorted(progression.NATURAL_STOP_PHASES),
            "control_count": len(controls),
            "controls_passed": sum(controls.values()),
            "forced_failure_count": details["forced_failure_count"],
            "observation_v2_natural_progression_controls": controls,
            "observation_v2_natural_progression_control_details": details,
            "development_integration_smoke_executed": False,
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


def _arm_execution_checks_v3(arm: Mapping[str, Any]) -> dict[str, bool]:
    observations = arm["observations"]
    native = arm["native_receipts"]
    collectors = arm["collector_receipts"]
    steps = arm["portable_step_receipts"]
    count = len(observations)
    final_phase = arm["final_phase"]
    stopped = final_phase in progression.NATURAL_STOP_PHASES
    expected_control_count = count - 1 if stopped else count
    prior_phases = [item["memory"]["phase"] for item in steps[:-1]]
    trace = arm["portable_request_trace"]
    mapping = arm["native_recovery_morphology_readback"]
    initializer = arm["initializer_manifest"]
    return {
        "trace_lengths_complete_and_bounded": (
            0 < count <= EXPECTED_MAXIMUM_HORIZON_STEPS
            and len(native) == len(collectors) == len(steps) == count
        ),
        "native_counts_exact": (
            arm["outer_step_count"] == count
            and arm["native_solver_step_count"] == count * 5
        ),
        "natural_stop_exact": (
            stopped
            and bool(steps)
            and steps[-1]["memory"]["phase"] == final_phase
            and not any(
                phase in progression.NATURAL_STOP_PHASES for phase in prior_phases
            )
        ),
        "route_and_request_family_exact": (
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
            and trace["control_request_schemas"]
            == ["sporespore_recovery_control_request_v3"] * expected_control_count
        ),
        "receipts_supported_and_publication_bound": (
            all(item["support_status"] == "supported_exact" for item in steps)
            and all(
                item["support_status"] == "supported_exact"
                and item["supplied_native_post_step_observation_validated"] is True
                for item in collectors
            )
            and all(
                item["native_source_route_id"]
                == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
                and item["publication_route_id"] == streaming.PUBLICATION_ROUTE_ID
                and item["observation_v2_in_run_invariants"][
                    "publication_replayed_exact"
                ]
                is True
                for item in native
            )
        ),
        "streaming_publication_is_current_batch_bounded_and_content_addressed": all(
            item.get("observation_v2_publication", {}).get("mapping_profile_id")
            == streaming.MAPPING_PROFILE_ID
            and item.get("observation_v2_streaming_state", {}).get("schema_version")
            == streaming.STATE_SCHEMA
            and item["observation_v2_streaming_state"].get("state_sha256")
            == item["observation_v2_in_run_invariants"].get("next_state_sha256")
            and len(
                item["observation_v2_publication"]["mapping_receipt"][
                    "current_batch_component_mappings"
                ]
            )
            == 5
            and len(
                item["observation_v2_publication"]["mapping_receipt"][
                    "current_batch_ordered_increments"
                ]
            )
            == 5
            and item["observation_v2_publication"]["mapping_receipt"].get(
                "prior_history_replayed_in_current_step"
            )
            is False
            for item in native
        ),
        "all_external_interventions_zero": all(
            all(value == 0 for value in item["external_interventions"].values())
            for item in observations
        ),
        "joint_limits_exact": all(
            item["classification"]["joint_limits_respected"] is True for item in steps
        ),
        "native_mapping_and_initializer_exact": (
            mapping["ok"] is True
            and mapping["recovery_morphology_spec_sha256"]
            == morphology.EXPECTED_RECOVERY_MORPHOLOGY_SHA256
            and mapping["ordered_joint_readback_count"] == 8
            and all(
                item["matches_zero_world_mapping"]
                for item in mapping["ordered_joint_readbacks"]
            )
            and initializer["initializer_id"] == morphology.INITIALIZER_ID
            and initializer["recovery_morphology_spec_sha256"]
            == morphology.EXPECTED_RECOVERY_MORPHOLOGY_SHA256
            and initializer["native_joint_position_readback_matches"] is True
        ),
    }


def _observation_numeric_projection_v1(
    observation: Mapping[str, Any],
) -> dict[str, Any]:
    projection = deepcopy(dict(observation))
    ledger = projection["energy_balance"]
    ledger.pop("source_profile_id")
    ledger.pop("source_values_sha256")
    return projection


def validate_observation_v2_trace_v1(
    core: LocomotionCore,
    result: Mapping[str, Any],
    *,
    arm_checks: Callable[[Mapping[str, Any]], Mapping[str, bool]] = (
        _arm_execution_checks_v3
    ),
    receipt_schema: str = (
        "sporespore_qsdk_r24d42_observation_v2_natural_progression_trace_invariants_v1"
    ),
) -> dict[str, Any]:
    """Replay the shared streaming chain with campaign-owned arm checks."""

    _require(
        result["route_id"] == streaming.PUBLICATION_ROUTE_ID
        and result["portable_evaluation_request_schema"]
        == "sporespore_recovery_evaluation_request_v3"
        and result["model_construction_count"] == 2
        and result["world_attempt_count"] == 2
        and result["world_build_count"] == 2,
        "TRACE_TOP_LEVEL",
    )
    invariant_hashes: list[str] = []
    arm_step_counts: dict[str, int] = {}
    final_source_chain_sha256s: dict[str, str] = {}
    final_legacy_mapping_sha256s: dict[str, str] = {}
    validated_substeps = 0
    retained_publication_byte_count = 0
    maximum_publication_byte_length = 0
    for result_key, arm_kind in (
        ("candidate", "candidate_command"),
        ("matched_zero_command", "matched_zero_command"),
    ):
        arm = result[result_key]
        checks = arm_checks(arm)
        _require(all(checks.values()), f"TRACE_ARM:{arm_kind}")
        arm_step_counts[arm_kind] = arm["outer_step_count"]
        batches: list[dict[str, Any]] = []
        first_observation = arm["observations"][0]
        state = streaming.initial_streaming_state_v1(
            core,
            initial_mechanical_energy_j=float(
                first_observation["energy_balance"]["initial_mechanical_energy_j"]
            ),
            arm_kind=arm_kind,
        )
        for semantic_step, native in enumerate(arm["native_receipts"]):
            native_step = native["native_step"]
            observation = arm["observations"][semantic_step]
            publication = native["observation_v2_publication"]
            mapping_request = streaming.streaming_mapping_request_v1(
                observation=observation,
                native_step=native_step,
            )
            prior_state = deepcopy(state)
            replay, state = streaming.validate_streaming_publication_in_run_v1(
                core,
                publication=publication,
                native_step=native_step,
                mapping_request=mapping_request,
                prior_state=prior_state,
                descriptor=base.s169_descriptor(),
                morphology_context=arm["portable_recovery_morphology_context"],
                capability_sha256=arm["portable_initialization_receipt"][
                    "capability_sha256"
                ],
                runtime_qualification_sha256=(
                    runtime.R24D17_RUNTIME_QUALIFICATION_SHA256
                ),
                expected_arm_kind=arm_kind,
                expected_phase=publication["collection_request"]["phase"],
            )
            _require_replayed_streaming_state_v1(
                core,
                native["observation_v2_streaming_state"],
                state,
            )
            _require(
                native["observation_v2_in_run_invariants"] == replay
                and observation == publication["portable_observation"]
                and arm["collector_receipts"][semantic_step]
                == publication["collection_receipt"]
                and publication["mapping_receipt"]["native_component_batch_count"]
                == semantic_step + 1
                and publication["mapping_receipt"]["native_component_receipt_count"]
                == (semantic_step + 1) * 5,
                f"TRACE_REPLAY:{arm_kind}:{semantic_step}",
            )
            batches.append(
                {
                    "semantic_step": semantic_step,
                    "ordered_substep_receipts": deepcopy(
                        native_step["implicit_substep_energy_receipts"]
                    ),
                }
            )
            invariant_hashes.append(replay["receipt_sha256"])
            validated_substeps += replay["validated_native_substep_count"]
            publication_bytes = len(shared._canonical_bytes(publication))
            retained_publication_byte_count += publication_bytes
            maximum_publication_byte_length = max(
                maximum_publication_byte_length,
                publication_bytes,
            )
        final_observation = arm["observations"][-1]
        final_ledger = final_observation["energy_balance"]
        final_base = {
            key: deepcopy(value)
            for key, value in final_observation.items()
            if key not in {"schema_version", "energy_balance"}
        }
        legacy = full_mapping.map_r24d36_components_to_recovery_observation_v2(
            core,
            {
                "schema_version": full_mapping.MAPPING_REQUEST_SCHEMA,
                "source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
                "initial_mechanical_energy_j": final_ledger[
                    "initial_mechanical_energy_j"
                ],
                "current_mechanical_energy_j": final_ledger[
                    "current_mechanical_energy_j"
                ],
                "observation_base": final_base,
                "ordered_native_component_batches": batches,
            },
        )
        _require(
            legacy["support_status"] == "supported_exact"
            and _observation_numeric_projection_v1(legacy["portable_observation"])
            == _observation_numeric_projection_v1(final_observation),
            f"TRACE_FINAL_LEGACY_NUMERIC_PARITY:{arm_kind}",
        )
        final_source_chain_sha256s[arm_kind] = state["source_chain_sha256"]
        final_legacy_mapping_sha256s[arm_kind] = _canonical_sha256(core, legacy)
    total_outer = sum(arm_step_counts.values())
    _require(
        result["outer_step_count"] == total_outer
        and total_outer <= EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS
        and result["native_solver_step_count"] == validated_substeps
        and validated_substeps == total_outer * 5
        and validated_substeps <= EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS,
        "TRACE_COUNTS",
    )
    evaluation = result["evaluation"]
    _require(
        evaluation["support_status"] == "supported_exact"
        and evaluation["physical_development_trace_valid"] is True
        and result["prone_to_standing_claimed"] is False
        and result["repeatability_rate_claimed"] is False
        and result["population_claimed"] is False
        and result["physical_acceptance_authority"] is False
        and result["release_authority"] is False,
        "TRACE_EVALUATION",
    )
    return {
        "schema_version": receipt_schema,
        "validator_id": observation_v2.IN_RUN_INVARIANT_VALIDATOR_ID,
        "validated_arm_count": EXPECTED_PAIRED_ARM_COUNT,
        "arm_step_counts": arm_step_counts,
        "validated_outer_step_count": total_outer,
        "validated_native_substep_count": validated_substeps,
        "in_run_invariant_receipt_sha256s": invariant_hashes,
        "final_source_chain_sha256s": final_source_chain_sha256s,
        "final_legacy_mapping_sha256s": final_legacy_mapping_sha256s,
        "portable_publication_replayed_exact": True,
        "mapping_profile_id": streaming.MAPPING_PROFILE_ID,
        "streaming_chain_replayed_once": True,
        "final_legacy_full_aggregate_execution_count": 2,
        "final_legacy_full_aggregate_numeric_parity": True,
        "full_streaming_publications_retained_inline": True,
        "retained_streaming_publication_canonical_byte_count": (
            retained_publication_byte_count
        ),
        "maximum_streaming_publication_canonical_byte_length": (
            maximum_publication_byte_length
        ),
        "current_batch_mapping_cardinality_bounded": True,
        "natural_stops_validated": True,
        "public_collector_supervisor_controller_and_evaluator_executed": True,
        "behavior_threshold_selected_or_changed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def compact_projection_v1(
    result: Mapping[str, Any],
    trace_invariants: Mapping[str, Any],
) -> dict[str, Any]:
    candidate = result["candidate"]
    matched = result["matched_zero_command"]
    evaluation = result["evaluation"]
    candidate_checks = _arm_execution_checks_v3(candidate)
    matched_checks = _arm_execution_checks_v3(matched)
    candidate_sequence = progression._arm_sequences(candidate)
    matched_sequence = progression._arm_sequences(matched)
    distal = progression._transition_classification(
        candidate_sequence,
        "establish_distal_support",
        "raise_body",
    )
    handoff = progression._transition_classification(
        candidate_sequence,
        "raise_body",
        "stance_handoff",
    )
    facts = {
        "candidate_outer_step_count": candidate_sequence["outer_step_count"],
        "matched_zero_outer_step_count": matched_sequence["outer_step_count"],
        "candidate_final_phase": candidate_sequence["final_phase"],
        "candidate_terminal_failure_code": candidate_sequence["terminal_failure_code"],
        "candidate_transition_pairs": candidate_sequence["transition_pairs"],
        "candidate_distal_support_transition_gate": distal.get("distal_support_gate"),
        "candidate_handoff_raised_body_gate": handoff.get("raised_body_gate"),
        "candidate_handoff_safety_gate": handoff.get("safety_gate"),
        "candidate_active_application_count": candidate_sequence[
            "active_application_count"
        ],
        "matched_zero_final_phase": matched_sequence["final_phase"],
        "matched_zero_terminal_failure_code": matched_sequence["terminal_failure_code"],
        "matched_zero_active_application_count": matched_sequence[
            "active_application_count"
        ],
        "matched_zero_observations_all_zero_command": matched_sequence[
            "observations_all_zero_command"
        ],
    }
    target_checks = progression.evaluate_progression_facts_v1(facts)
    total_outer = (
        facts["candidate_outer_step_count"] + facts["matched_zero_outer_step_count"]
    )
    execution_checks = {
        "observation_v2_route_exact": (
            result["route_id"] == streaming.PUBLICATION_ROUTE_ID
        ),
        "paired_initializer_identity_matched": (
            result["initializer_identity_matched"] is True
        ),
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
        "candidate_in_run_invariants_pass": all(candidate_checks.values()),
        "matched_zero_in_run_invariants_pass": all(matched_checks.values()),
        "complete_observation_v2_replay_pass": (
            trace_invariants["validated_outer_step_count"] == total_outer
            and trace_invariants["validated_native_substep_count"] == total_outer * 5
            and trace_invariants["portable_publication_replayed_exact"] is True
            and trace_invariants["streaming_chain_replayed_once"] is True
            and trace_invariants["final_legacy_full_aggregate_numeric_parity"] is True
            and trace_invariants["current_batch_mapping_cardinality_bounded"] is True
        ),
        "portable_evaluation_v3_supported_valid": (
            result["portable_evaluation_request_schema"]
            == "sporespore_recovery_evaluation_request_v3"
            and evaluation["support_status"] == "supported_exact"
            and evaluation["physical_development_trace_valid"] is True
            and evaluation["candidate_trace"]["final_phase"]
            == candidate_sequence["final_phase"]
            and evaluation["matched_zero_command_trace"]["final_phase"]
            == matched_sequence["final_phase"]
        ),
        "full_recovery_and_release_authority_absent": (
            result["prone_to_standing_claimed"] is False
            and result["physical_acceptance_authority"] is False
            and result["release_authority"] is False
        ),
    }
    execution_valid = all(execution_checks.values())
    decision_positive = execution_valid and all(target_checks.values())
    return {
        "schema_version": COMPACT_PROJECTION_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "ledger_scope": {
            "subsystem": "recovery_mujoco_observation_v2_progression",
            "engine_scope": ["mujoco_native"],
            "authority_mode": "development_natural_stop",
            "question_class": "development",
        },
        "route_id": streaming.PUBLICATION_ROUTE_ID,
        "native_source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
        "portable_observation_schema": "sporespore_recovery_observation_v2",
        "mapping_profile_id": streaming.MAPPING_PROFILE_ID,
        "cell_id": EXPECTED_CELL_ID,
        "seed": EXPECTED_SEED,
        "maximum_horizon_steps_per_arm": EXPECTED_MAXIMUM_HORIZON_STEPS,
        "candidate": candidate_sequence,
        "matched_zero_command": matched_sequence,
        "portable_evaluation_verdict": evaluation["verdict"],
        "execution_checks": execution_checks,
        "target_facts": facts,
        "target_checks": target_checks,
        "trace_invariants": deepcopy(trace_invariants),
        "execution_valid": execution_valid,
        "decision_positive": decision_positive,
        "valid_negative_if_decision_not_positive": (
            execution_valid and not decision_positive
        ),
        "full_prone_to_standing_success_required": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
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
    )
    invariants = validate_observation_v2_trace_v1(core, result)
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
        "route_predecessor_gate_id": "QSDK-R24D41",
        "behavior_predecessor_gate_id": "QSDK-R24D32",
        "mapping_profile_id": streaming.MAPPING_PROFILE_ID,
        "result": result,
        "trace_invariants": invariants,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
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
        "observation_v2_invariants_passed": True,
        "streaming_chain_replayed_once": True,
        "final_legacy_full_aggregate_numeric_parity": True,
        "full_streaming_publications_retained_inline": True,
        "complete_trace_retained": True,
        "compact_projection_retained": True,
        "held_out_cell_access_count": 0,
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
        "prone_to_standing_claimed": False,
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
        "valid_physical_behavior_result_observed": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
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
