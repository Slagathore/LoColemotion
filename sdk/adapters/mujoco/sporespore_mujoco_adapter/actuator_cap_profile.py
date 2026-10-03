"""Pure, zero-world mapping of the public actuator-cap profile to MuJoCo.

The mapper emits ordered force limits and production-shaped ``<velocity>``
actuator fragments. It intentionally does not import MuJoCo, construct an
``MjModel``/``MjData``, or step physics. Native physical validation remains a
separate prospective question.
"""

from __future__ import annotations

from copy import deepcopy
import math
from typing import Any


REPORT_SCHEMA_VERSION = (
    "sporespore_mujoco_actuator_cap_profile_zero_world_mapping_v1"
)
HOST_MAPPING_ID = "sporespore_mujoco_velocity_force_range_cap_mapping_v1"
PROFILE_ID = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
PROFILE_SHA256 = (
    "sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
)
DESCRIPTOR_SHA256 = (
    "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0"
)
MORPHOLOGY_SPEC_SHA256 = (
    "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e"
)
PORTABLE_SEMANTICS_ID = (
    "sporespore_outer_control_step_angular_impulse_budget_120hz_v1"
)
CONTROLLER_DT_S = 1.0 / 120.0
INTERNAL_DT_S = 1.0 / 600.0
INTERNAL_STEPS_PER_OUTER = 5
VELOCITY_GAIN_NM_S_PER_RAD = 10.0
FLOAT_ROUNDING_BUDGET_ULPS = 8

ORDERED_ACTUATOR_IDS = (
    "front_left_hip_motor",
    "front_left_knee_motor",
    "front_right_hip_motor",
    "front_right_knee_motor",
    "rear_left_hip_motor",
    "rear_left_knee_motor",
    "rear_right_hip_motor",
    "rear_right_knee_motor",
)
ORDERED_JOINT_IDS = (
    "front_left_hip",
    "front_left_knee",
    "front_right_hip",
    "front_right_knee",
    "rear_left_hip",
    "rear_left_knee",
    "rear_right_hip",
    "rear_right_knee",
)
ORDERED_CAPS_NMS = (
    0.05362625170687301,
    0.4567500054836273,
    0.05362625170687301,
    0.4567500054836273,
    0.05637374829312699,
    0.4567500054836273,
    0.05637374829312699,
    0.4567500054836273,
)
ORDERED_BASE_CAPS_NMS = (
    0.05362625170687301,
    0.04387602412380519,
    0.05362625170687301,
    0.04387602412380519,
    0.056373748293126996,
    0.046123975876194816,
    0.056373748293126996,
    0.046123975876194816,
)
ORDERED_BASE_CAPS_BINARY64_HEX = (
    "0x3fab74e66a937fb7",
    "0x3fa676eb1161687e",
    "0x3fab74e66a937fb7",
    "0x3fa676eb1161687e",
    "0x3facdd051a8b389c",
    "0x3fa79d8fcfe64597",
    "0x3facdd051a8b389c",
    "0x3fa79d8fcfe64597",
)
ORDERED_CAPS_BINARY64_HEX = (
    "0x3fab74e66a937fb7",
    "0x3fdd3b6460000000",
    "0x3fab74e66a937fb7",
    "0x3fdd3b6460000000",
    "0x3facdd051a8b389b",
    "0x3fdd3b6460000000",
    "0x3facdd051a8b389b",
    "0x3fdd3b6460000000",
)
ORDERED_ULP_DISTANCES = (
    "0",
    "15415674031478658",
    "0",
    "15415674031478658",
    "1",
    "15091710041897577",
    "1",
    "15091710041897577",
)


class ActuatorCapProfileMappingError(RuntimeError):
    """Stable fail-closed error for a profile receipt or host mapping."""


def _require(condition: bool, failure_code: str) -> None:
    if not condition:
        raise ActuatorCapProfileMappingError(failure_code)


def _profile(receipt: dict[str, Any]) -> dict[str, Any]:
    _require(
        set(receipt)
        == {
            "schema_version",
            "requested_profile_id",
            "supported_profile_ids",
            "support_status",
            "refusal_reason",
            "descriptor_sha256",
            "morphology_spec_sha256",
            "profile",
            "profile_sha256",
            "world_build_count",
            "physics_state_modified",
            "physical_acceptance_authority",
            "release_authority",
        },
        "QSDK_R23D61_MUJOCO_RECEIPT_FIELDS_INVALID",
    )
    _require(
        receipt.get("schema_version")
        == "sporespore_actuator_cap_profile_receipt_v1",
        "QSDK_R23D61_MUJOCO_RECEIPT_SCHEMA_INVALID",
    )
    _require(
        receipt.get("requested_profile_id") == PROFILE_ID
        and receipt.get("supported_profile_ids") == [PROFILE_ID]
        and receipt.get("support_status") == "supported_exact"
        and receipt.get("refusal_reason") is None,
        "QSDK_R23D61_MUJOCO_PROFILE_SUPPORT_INVALID",
    )
    _require(
        receipt.get("descriptor_sha256") == DESCRIPTOR_SHA256
        and receipt.get("morphology_spec_sha256") == MORPHOLOGY_SPEC_SHA256
        and receipt.get("profile_sha256") == PROFILE_SHA256,
        "QSDK_R23D61_MUJOCO_PROFILE_IDENTITY_INVALID",
    )
    _require(
        receipt.get("world_build_count") == 0
        and receipt.get("physics_state_modified") is False
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False,
        "QSDK_R23D61_MUJOCO_PROFILE_AUTHORITY_INVALID",
    )
    profile = receipt.get("profile")
    _require(
        isinstance(profile, dict),
        "QSDK_R23D61_MUJOCO_PROFILE_MISSING",
    )
    assert isinstance(profile, dict)
    _require(
        set(profile)
        == {
            "schema_version",
            "profile_id",
            "supported_morphology_id",
            "supported_descriptor_sha256",
            "supported_morphology_spec_sha256",
            "semantics",
            "ordered_caps",
            "provenance",
            "claim_boundary",
        },
        "QSDK_R23D61_MUJOCO_PROFILE_FIELDS_INVALID",
    )
    _require(
        profile.get("schema_version") == "sporespore_actuator_cap_profile_v1"
        and profile.get("profile_id") == PROFILE_ID
        and profile.get("supported_morphology_id")
        == "qsdk_r05_generated_s169"
        and profile.get("supported_descriptor_sha256") == DESCRIPTOR_SHA256
        and profile.get("supported_morphology_spec_sha256")
        == MORPHOLOGY_SPEC_SHA256,
        "QSDK_R23D61_MUJOCO_PROFILE_SURFACE_INVALID",
    )
    semantics = profile.get("semantics")
    _require(
        isinstance(semantics, dict)
        and set(semantics)
        == {
            "semantics_id",
            "quantity",
            "unit",
            "outer_step_hz",
            "outer_step_duration_s",
            "host_mapping_rule",
            "solver_iteration_multiplier_in_canonical_budget",
        }
        and semantics.get("semantics_id") == PORTABLE_SEMANTICS_ID
        and semantics.get("quantity")
        == "maximum_angular_impulse_per_complete_outer_control_step"
        and semantics.get("unit") == "newton_meter_second"
        and semantics.get("outer_step_hz") == 120
        and semantics.get("outer_step_duration_s") == CONTROLLER_DT_S
        and semantics.get("host_mapping_rule")
        == "preserve_maximum_outer_step_angular_impulse_exactly"
        and semantics.get("solver_iteration_multiplier_in_canonical_budget")
        is False,
        "QSDK_R23D61_MUJOCO_PROFILE_SEMANTICS_INVALID",
    )
    boundary = profile.get("claim_boundary")
    _require(
        isinstance(boundary, dict)
        and set(boundary)
        == {
            "exact_scope_profile_publication",
            "arbitrary_morphology_support",
            "physical_question_declared",
            "physical_world_opened",
            "three_engine_turning",
            "prone_to_standing",
            "cross_engine_equivalence",
            "physical_acceptance_authority",
            "release_authority",
        }
        and boundary.get("exact_scope_profile_publication") is True
        and boundary.get("arbitrary_morphology_support") is False
        and boundary.get("physical_question_declared") is False
        and boundary.get("physical_world_opened") is False
        and boundary.get("three_engine_turning") is False
        and boundary.get("prone_to_standing") is False
        and boundary.get("cross_engine_equivalence") is False
        and boundary.get("physical_acceptance_authority") is False
        and boundary.get("release_authority") is False,
        "QSDK_R23D61_MUJOCO_PROFILE_CLAIM_BOUNDARY_INVALID",
    )
    provenance = profile.get("provenance")
    _require(
        isinstance(provenance, dict)
        and set(provenance)
        == {
            "r23d58_zero_world_contract_path",
            "r23d58_zero_world_contract_raw_sha256",
            "r23d58_physical_source_commit",
            "r23d59_selection_closure_path",
            "r23d59_selection_closure_raw_sha256",
            "r23d59_selection_source_commit",
            "r23d60_validation_closure_path",
            "r23d60_validation_closure_raw_sha256",
            "r23d60_validation_source_commit",
            "selected_predecessor_profile_id",
            "fixture_comparator_was_public_sdk_semantics",
            "fixture_behavior_silently_applied",
            "historical_result_reinterpreted",
        }
        and provenance.get("r23d58_zero_world_contract_path")
        == "sdk/turning/r23d58_godot_terminal_trace_cap_factorial_zero_world_v1.json"
        and provenance.get("r23d58_zero_world_contract_raw_sha256")
        == "sha256:b1d5615048c624e506dd4b89a3abac41dd07c41e90a9b814bae6cbb5913961ad"
        and provenance.get("r23d58_physical_source_commit")
        == "ecfc191bcc97ea53b089e9862a5d0b5a7a8ad6b5"
        and provenance.get("r23d59_selection_closure_path")
        == "sdk/turning/r23d59_godot_knee_source_finite_decision_closure_v1.json"
        and provenance.get("r23d59_selection_closure_raw_sha256")
        == "sha256:cbce64d87d18dbd819f8afd759943f4bbe7c066d32da3d4c4f567fc7b4422cc8"
        and provenance.get("r23d59_selection_source_commit")
        == "22020d397ea4ce952a67051a843c22b388f0f78b"
        and provenance.get("r23d60_validation_closure_path")
        == "sdk/turning/r23d60_godot_fixture_knee_held_out_turning_validation_closure_v1.json"
        and provenance.get("r23d60_validation_closure_raw_sha256")
        == "sha256:910fd0ba2369a889430c1228f2eaea1146cf26005c4ac51f353803869d709fd8"
        and provenance.get("r23d60_validation_source_commit")
        == "3d884af6dc0a15aa9bd2cde15de4535a24bb44a2"
        and provenance.get("selected_predecessor_profile_id")
        == "portable_hip__fixture_knee"
        and provenance.get("fixture_comparator_was_public_sdk_semantics")
        is False
        and provenance.get("fixture_behavior_silently_applied") is False
        and provenance.get("historical_result_reinterpreted") is False,
        "QSDK_R23D61_MUJOCO_PROFILE_PROVENANCE_INVALID",
    )
    ordered_caps = profile.get("ordered_caps")
    _require(
        isinstance(ordered_caps, list) and len(ordered_caps) == 8,
        "QSDK_R23D61_MUJOCO_PROFILE_CARDINALITY_INVALID",
    )
    for index, item in enumerate(ordered_caps):
        _require(
            isinstance(item, dict)
            and set(item)
            == {
                "actuator_id",
                "joint_id",
                "source",
                "base_compiled_maximum_impulse_nms",
                "base_compiled_maximum_impulse_binary64_hex",
                "maximum_outer_step_impulse_nms",
                "maximum_outer_step_impulse_binary64_hex",
                "differs_from_base_compiled_morphology",
                "base_to_profile_binary64_ulp_distance",
            }
            and item.get("actuator_id") == ORDERED_ACTUATOR_IDS[index]
            and item.get("joint_id") == ORDERED_JOINT_IDS[index]
            and item.get("source")
            == (
                "r23d60_selected_portable_hip_explicit_publication"
                if index % 2 == 0
                else "r23d60_selected_fixture_knee_explicit_publication"
            )
            and item.get("base_compiled_maximum_impulse_nms")
            == ORDERED_BASE_CAPS_NMS[index]
            and item.get("base_compiled_maximum_impulse_binary64_hex")
            == ORDERED_BASE_CAPS_BINARY64_HEX[index]
            and item.get("maximum_outer_step_impulse_nms")
            == ORDERED_CAPS_NMS[index]
            and item.get("maximum_outer_step_impulse_binary64_hex")
            == ORDERED_CAPS_BINARY64_HEX[index]
            and item.get("differs_from_base_compiled_morphology")
            == (index not in (0, 2))
            and item.get("base_to_profile_binary64_ulp_distance")
            == ORDERED_ULP_DISTANCES[index],
            "QSDK_R23D61_MUJOCO_PROFILE_ORDER_OR_CAP_INVALID",
        )
    return profile


def map_actuator_cap_profile(receipt: dict[str, Any]) -> dict[str, Any]:
    """Map one validated exact-scope receipt to ordered MuJoCo force limits."""

    profile = _profile(receipt)
    ordered_mappings: list[dict[str, Any]] = []
    maximum_reconstruction_error_nms = 0.0
    maximum_reconstruction_budget_nms = 0.0
    for item in profile["ordered_caps"]:
        cap = float(item["maximum_outer_step_impulse_nms"])
        _require(
            math.isfinite(cap) and cap > 0.0,
            "QSDK_R23D61_MUJOCO_CAP_INVALID",
        )
        maximum_force_nm = cap / CONTROLLER_DT_S
        internal_impulse_limit_nms = maximum_force_nm * INTERNAL_DT_S
        reconstructed_outer_impulse_nms = (
            internal_impulse_limit_nms * INTERNAL_STEPS_PER_OUTER
        )
        reconstruction_error_nms = abs(reconstructed_outer_impulse_nms - cap)
        reconstruction_budget_nms = FLOAT_ROUNDING_BUDGET_ULPS * math.ulp(cap)
        _require(
            reconstruction_error_nms <= reconstruction_budget_nms,
            "QSDK_R23D61_MUJOCO_MAPPING_BUDGET_EXCEEDED",
        )
        maximum_reconstruction_error_nms = max(
            maximum_reconstruction_error_nms,
            reconstruction_error_nms,
        )
        maximum_reconstruction_budget_nms = max(
            maximum_reconstruction_budget_nms,
            reconstruction_budget_nms,
        )
        force_text = format(maximum_force_nm, ".17g")
        ordered_mappings.append(
            {
                "actuator_id": item["actuator_id"],
                "joint_id": item["joint_id"],
                "portable_maximum_outer_step_impulse_nms": cap,
                "mujoco_symmetric_force_range_nm": [
                    -maximum_force_nm,
                    maximum_force_nm,
                ],
                "mujoco_internal_step_impulse_limit_nms": (
                    internal_impulse_limit_nms
                ),
                "reconstructed_outer_step_impulse_nms": (
                    reconstructed_outer_impulse_nms
                ),
                "outer_step_reconstruction_error_nms": (
                    reconstruction_error_nms
                ),
                "outer_step_reconstruction_budget_nms": (
                    reconstruction_budget_nms
                ),
                "velocity_actuator_xml": (
                    f'<velocity name="{item["actuator_id"]}" '
                    f'joint="{item["joint_id"]}" '
                    f'kv="{VELOCITY_GAIN_NM_S_PER_RAD:.17g}" '
                    'forcelimited="true" '
                    f'forcerange="-{force_text} {force_text}"/>'
                ),
            }
        )

    return {
        "schema_version": REPORT_SCHEMA_VERSION,
        "ok": True,
        "adapter_id": "sporespore_mujoco_adapter",
        "host_mapping_id": HOST_MAPPING_ID,
        "profile_id": PROFILE_ID,
        "profile_sha256": PROFILE_SHA256,
        "portable_semantics_id": PORTABLE_SEMANTICS_ID,
        "mujoco_scalar": "float64",
        "portable_controller_timestep_s": CONTROLLER_DT_S,
        "internal_physics_timestep_s": INTERNAL_DT_S,
        "internal_steps_per_outer": INTERNAL_STEPS_PER_OUTER,
        "ordered_mappings": ordered_mappings,
        "validated_actuator_count": len(ordered_mappings),
        "maximum_outer_step_reconstruction_error_nms": (
            maximum_reconstruction_error_nms
        ),
        "maximum_outer_step_reconstruction_budget_nms": (
            maximum_reconstruction_budget_nms
        ),
        "numeric_adequacy": {
            "kind": "binary64_representation_rounding_bound_not_physical_margin",
            "binary64_ulp_multiplier": FLOAT_ROUNDING_BUDGET_ULPS,
            "applies_only_to": (
                "portable_cap_to_force_then_five_internal_step_round_trip"
            ),
            "population_claim": False,
            "physical_claim": False,
        },
        "xml_fragment_count": len(ordered_mappings),
        "mujoco_import_count": 0,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "locomotion_outcome_exposed": False,
        "turning_claimed": False,
        "prone_to_standing_claimed": False,
        "cross_engine_equivalence_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def run_actuator_cap_profile_preflight(
    receipt: dict[str, Any],
) -> dict[str, Any]:
    """Run the exact mapping and its complete receipt-mutation controls."""

    report = map_actuator_cap_profile(receipt)
    candidates: list[tuple[str, dict[str, Any]]] = []

    wrong_receipt_schema = deepcopy(receipt)
    wrong_receipt_schema["schema_version"] += "_mutated"
    candidates.append(("wrong_receipt_schema", wrong_receipt_schema))

    wrong_support = deepcopy(receipt)
    wrong_support["support_status"] = "out_of_domain_morphology"
    candidates.append(("wrong_support_status", wrong_support))

    wrong_profile_sha = deepcopy(receipt)
    wrong_profile_sha["profile_sha256"] = "sha256:mutated"
    candidates.append(("wrong_profile_sha256", wrong_profile_sha))

    wrong_semantics = deepcopy(receipt)
    wrong_semantics["profile"]["semantics"]["semantics_id"] += "_mutated"
    candidates.append(("wrong_semantics", wrong_semantics))

    swapped_order = deepcopy(receipt)
    swapped_order["profile"]["ordered_caps"][0:2] = reversed(
        swapped_order["profile"]["ordered_caps"][0:2]
    )
    candidates.append(("swapped_actuator_order", swapped_order))

    wrong_cap = deepcopy(receipt)
    wrong_cap["profile"]["ordered_caps"][0][
        "maximum_outer_step_impulse_nms"
    ] = 0.0
    candidates.append(("zero_cap", wrong_cap))

    mutated_bound_profile_field = deepcopy(receipt)
    mutated_bound_profile_field["profile"]["ordered_caps"][4][
        "maximum_outer_step_impulse_binary64_hex"
    ] = "0x3facdd051a8b389c"
    candidates.append(
        ("mutated_bound_profile_field", mutated_bound_profile_field)
    )

    inflated_world = deepcopy(receipt)
    inflated_world["world_build_count"] = 1
    candidates.append(("inflated_world_count", inflated_world))

    inflated_claim = deepcopy(receipt)
    inflated_claim["profile"]["claim_boundary"][
        "cross_engine_equivalence"
    ] = True
    candidates.append(("inflated_claim_authority", inflated_claim))

    mutation_results: list[dict[str, Any]] = []
    for mutation_id, candidate in candidates:
        try:
            map_actuator_cap_profile(candidate)
        except ActuatorCapProfileMappingError:
            rejected = True
        else:
            rejected = False
        _require(
            rejected,
            f"QSDK_R23D61_MUJOCO_MUTATION_ACCEPTED:{mutation_id}",
        )
        mutation_results.append(
            {"mutation_id": mutation_id, "rejected": rejected}
        )
    report["mutation_rejection_count"] = len(mutation_results)
    report["mutation_results"] = mutation_results
    return report
