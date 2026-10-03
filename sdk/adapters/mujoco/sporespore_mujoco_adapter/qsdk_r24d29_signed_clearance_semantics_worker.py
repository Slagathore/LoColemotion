"""R24D29 zero-world signed-clearance/contact-provenance conformance."""

from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import qsdk_r24d28_collection_refusal_observability_worker as predecessor


GATE_ID = "QSDK-R24D29"
CONTRACT_SCHEMA = "sporespore_qsdk_r24d29_signed_clearance_semantics_contract_v1"
PREFLIGHT_SCHEMA = "sporespore_qsdk_r24d29_signed_clearance_semantics_preflight_v1"
FIXTURE_SCHEMA = "sporespore_qsdk_r24d29_retained_step82_clearance_fixture_v1"
REPO_ROOT = Path(__file__).resolve().parents[4]
FIXTURE_PATH = (
    REPO_ROOT / "sdk/recovery/r24d29_retained_step82_clearance_fixture_v1.json"
)


class R24D29WorkerError(RuntimeError):
    """Stable fail-closed R24D29 conformance error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D29WorkerError(code)


def _load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    _require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _canonical_identity(core: LocomotionCore, value: object) -> tuple[str, int]:
    receipt = core.canonicalize_json(value)
    canonical = receipt.get("canonical_json")
    digest = receipt.get("sha256")
    _require(isinstance(canonical, str), "CANONICAL_JSON")
    _require(isinstance(digest, str), "CANONICAL_DIGEST")
    return digest, len(canonical.encode("utf-8"))


def _step_request(context: Mapping[str, Any]) -> dict[str, Any]:
    collection = context["current_collection_request"]
    return {
        "schema_version": "sporespore_recovery_step_request_v2",
        "descriptor": deepcopy(collection["descriptor"]),
        "morphology_context": deepcopy(
            context["portable_recovery_morphology_context"]
        ),
        "adapter_capability": deepcopy(collection["adapter_capability"]),
        "memory": deepcopy(context["memory_before_current_step"]),
        "observation": deepcopy(context["current_observation"]),
    }


def _body(observation: Mapping[str, Any], body_id: str) -> dict[str, Any]:
    matches = [
        item
        for item in observation["ordered_body_clearance_observations"]
        if item.get("body_id") == body_id
    ]
    _require(len(matches) == 1, f"BODY_ID:{body_id}")
    return matches[0]


def _foot_state(observation: Mapping[str, Any], site_id: str) -> dict[str, Any]:
    matches = [
        item
        for item in observation["state"]["ordered_contact_observations"]
        if item.get("contact_site_id") == site_id
    ]
    _require(len(matches) == 1, f"FOOT_STATE:{site_id}")
    return matches[0]


def _foot_bearing(observation: Mapping[str, Any], site_id: str) -> dict[str, Any]:
    matches = [
        item
        for item in observation["ordered_foot_bearing_observations"]
        if item.get("contact_site_id") == site_id
    ]
    _require(len(matches) == 1, f"FOOT_BEARING:{site_id}")
    return matches[0]


def _collect_with_body_mutation(
    core: LocomotionCore,
    request: Mapping[str, Any],
    body_id: str,
    changes: Mapping[str, Any],
) -> dict[str, Any]:
    mutated = deepcopy(dict(request))
    target = _body(mutated["observation"], body_id)
    target.update(deepcopy(dict(changes)))
    return core.recovery_collect_native_v2(mutated)


def _fixture_context(core: LocomotionCore) -> tuple[dict[str, Any], dict[str, Any]]:
    fixture = _load(FIXTURE_PATH)
    _require(fixture.get("schema_version") == FIXTURE_SCHEMA, "FIXTURE_SCHEMA")
    _require(fixture.get("gate_id") == GATE_ID, "FIXTURE_GATE")
    source = fixture["source"]
    closure_path = REPO_ROOT / source["predecessor_closure_path"]
    _require(
        _raw_sha256(closure_path) == source["predecessor_closure_raw_sha256"],
        "CLOSURE_DIGEST",
    )
    closure = _load(closure_path)
    _require(
        closure.get("closure_status")
        == "closed_consumed_diagnosable_invalid_observation_"
        "observability_positive_progression_unresolved",
        "CLOSURE_STATUS",
    )
    partial_path = Path(source["evidence_root"]) / source["partial_result_path"]
    _require(partial_path.stat().st_size == source["partial_result_byte_length"], "PARTIAL_LENGTH")
    _require(_raw_sha256(partial_path) == source["partial_result_raw_sha256"], "PARTIAL_DIGEST")
    partial = _load(partial_path)
    context = partial["native_collection_refusal"]["refusal_context"]
    identity = fixture["exact_fixture_identity"]
    _require(context["arm_kind"] == identity["arm_kind"], "ARM")
    _require(context["semantic_step"] == identity["semantic_step"], "STEP")
    _require(context["phase"] == identity["phase"], "PHASE")

    values = (
        (
            context["current_observation"],
            "current_observation_canonical_sha256",
            "current_observation_canonical_byte_length",
        ),
        (
            context["current_collection_request"],
            "current_collection_request_canonical_sha256",
            "current_collection_request_canonical_byte_length",
        ),
        (
            _step_request(context),
            "current_step_request_canonical_sha256",
            "current_step_request_canonical_byte_length",
        ),
    )
    for value, digest_key, length_key in values:
        digest, length = _canonical_identity(core, value)
        _require(digest == identity[digest_key], f"FIXTURE_DIGEST:{digest_key}")
        _require(length == identity[length_key], f"FIXTURE_LENGTH:{length_key}")

    observation = context["current_observation"]
    for expected in fixture["exact_rear_distal_projection"]:
        actual = _body(observation, expected["body_id"])
        for key in (
            "body_id",
            "nonfoot_contact_present",
            "engine_contact_ids",
            "accumulated_nonfoot_normal_impulse_ns",
            "minimum_nonfoot_clearance_m",
        ):
            _require(actual[key] == expected[key], f"PROJECTION:{expected['body_id']}:{key}")
        site_id = expected["body_id"].replace("_distal", "_foot")
        ids = _foot_state(observation, site_id)["provenance"]["engine_contact_ids"]
        impulse = _foot_bearing(observation, site_id)["bearing_normal_impulse_ns"]
        _require(len(ids) == expected["foot_contact_id_count"], f"FOOT_IDS:{site_id}")
        _require(impulse == expected["foot_bearing_normal_impulse_ns"], f"FOOT_IMPULSE:{site_id}")
    return fixture, context


def _signed_clearance_controls(
    core: LocomotionCore,
) -> tuple[dict[str, bool], dict[str, Any]]:
    fixture, context = _fixture_context(core)
    request = context["current_collection_request"]
    collected = core.recovery_collect_native_v2(deepcopy(request))
    step = core.recovery_step_v2(_step_request(context))
    expected = fixture["expected_successor_projection"]
    classification = step.get("classification") or {}
    memory = step.get("memory") or {}

    absent_with_id = _collect_with_body_mutation(
        core,
        request,
        "rear_left_distal",
        {"engine_contact_ids": ["mutated_nonfoot_contact"]},
    )
    absent_with_impulse = _collect_with_body_mutation(
        core,
        request,
        "rear_left_distal",
        {"accumulated_nonfoot_normal_impulse_ns": 0.001},
    )
    present_without_id = _collect_with_body_mutation(
        core,
        request,
        "rear_left_distal",
        {"nonfoot_contact_present": True},
    )
    duplicate_id = _collect_with_body_mutation(
        core,
        request,
        "rear_left_distal",
        {
            "nonfoot_contact_present": True,
            "engine_contact_ids": ["duplicate", "duplicate"],
        },
    )
    non_torso_ventral = _collect_with_body_mutation(
        core,
        request,
        "rear_left_distal",
        {
            "nonfoot_contact_present": True,
            "ventral_surface_contact": True,
            "engine_contact_ids": ["mutated_nonfoot_contact"],
        },
    )
    present_positive_clearance = _collect_with_body_mutation(
        core,
        request,
        "rear_left_distal",
        {
            "nonfoot_contact_present": True,
            "engine_contact_ids": ["mutated_nonfoot_contact"],
            "minimum_nonfoot_clearance_m": 0.001,
        },
    )

    checks = {
        "exact_retained_negative_clearance_without_native_nonfoot_contact_is_accepted_as_data": (
            collected.get("support_status") == expected["collector_support_status"]
            and collected.get("refusal_reason") == expected["collector_refusal_reason"]
            and collected.get("supplied_native_post_step_observation_validated") is True
        ),
        "exact_retained_negative_clearance_still_blocks_raised_body": (
            step.get("support_status") == expected["portable_step_support_status"]
            and step.get("refusal_reason") == expected["portable_step_refusal_reason"]
            and classification.get("pose_class") == expected["pose_class"]
            and classification.get("minimum_nonfoot_clearance_m")
            == expected["minimum_nonfoot_clearance_m"]
            and classification.get("any_nonfoot_contact")
            == expected["any_nonfoot_contact"]
            and classification.get("raised_body_gate") == expected["raised_body_gate"]
            and classification.get("stable_stance_gate") == expected["stable_stance_gate"]
            and memory.get("phase") == expected["next_phase"]
        ),
        "absent_contact_with_engine_contact_id_is_rejected": (
            absent_with_id.get("support_status") == "invalid_observation"
            and absent_with_id.get("refusal_reason")
            == "absent_nonfoot_contact_values_invalid"
        ),
        "absent_contact_with_nonzero_impulse_is_rejected": (
            absent_with_impulse.get("support_status") == "invalid_observation"
            and absent_with_impulse.get("refusal_reason")
            == "absent_nonfoot_contact_values_invalid"
        ),
        "present_contact_without_engine_contact_id_is_rejected": (
            present_without_id.get("support_status") == "invalid_observation"
            and present_without_id.get("refusal_reason")
            == "present_nonfoot_contact_provenance_invalid"
        ),
        "duplicate_engine_contact_id_is_rejected": (
            duplicate_id.get("support_status") == "invalid_observation"
            and duplicate_id.get("refusal_reason")
            == "body_clearance_engine_contact_identity_invalid"
        ),
        "ventral_contact_on_non_torso_body_is_rejected": (
            non_torso_ventral.get("support_status") == "invalid_observation"
            and non_torso_ventral.get("refusal_reason")
            == "ventral_contact_classification_invalid"
        ),
        "present_contact_with_positive_signed_clearance_is_accepted_as_independent_measurements": (
            present_positive_clearance.get("support_status") == "supported_exact"
            and present_positive_clearance.get("refusal_reason") is None
        ),
    }
    _require(list(checks) == fixture["mutation_population"], "MUTATION_ORDER")
    details = {
        "partial_result_raw_sha256": fixture["source"]["partial_result_raw_sha256"],
        "current_observation_canonical_sha256": fixture["exact_fixture_identity"][
            "current_observation_canonical_sha256"
        ],
        "retained_semantic_step": context["semantic_step"],
        "retained_phase": context["phase"],
        "successor_pose_class": classification.get("pose_class"),
        "successor_minimum_nonfoot_clearance_m": classification.get(
            "minimum_nonfoot_clearance_m"
        ),
        "successor_next_phase": memory.get("phase"),
    }
    return checks, details


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = predecessor.run_zero_world_preflight(core)
    checks, details = _signed_clearance_controls(core)
    _require(all(checks.values()), "SIGNED_CLEARANCE_CONTROL_FAILED")
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "gate_id": GATE_ID,
            "inherited_r24d28_control_count": inherited["negative_control_count"],
            "signed_clearance_control_count": len(checks),
            "signed_clearance_controls": checks,
            "signed_clearance_control_details": details,
            "negative_control_count": inherited["negative_control_count"] + len(checks),
            "negative_controls_passed": inherited["negative_controls_passed"]
            + sum(checks.values()),
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
    print(json.dumps(receipt, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
