"""Explain descriptor acceptance and public SDK capability boundaries."""

from __future__ import annotations

from typing import Any, Mapping

from python import (
    ABI_GENERATION,
    SDK_VERSION,
    LocomotionCore,
    LocomotionCoreError,
    SELECTED_BALANCED_WAVE_CANDIDATE_ID,
    SELECTED_BALANCED_WAVE_POLICY_ID,
)


def _suggestion_for(failure_code: str) -> str:
    suggestions = {
        "SCHEMA_INVALID": (
            "Compare the descriptor with "
            "sporespore_bounded_quadruped_descriptor_v1 and remove unknown "
            "fields."
        ),
        "DESCRIPTOR_OUT_OF_DOMAIN": (
            "Keep every normalized morphology axis inside the published "
            "bounded quadruped domain; inspect gq15_domain_certificate."
        ),
        "ABI_INVALID_JSON": (
            "Emit finite UTF-8 JSON values and do not use NaN or Infinity."
        ),
    }
    return suggestions.get(
        failure_code,
        "Inspect the typed failure detail and the integration contract.",
    )


def diagnose_descriptor(
    core: LocomotionCore,
    descriptor: Mapping[str, Any],
) -> dict[str, Any]:
    """Return a non-throwing diagnostic receipt for one descriptor."""

    input_identity = core.canonicalize_json(descriptor)
    certificate = core.gq15_domain_certificate()
    try:
        compiled = core.compile_bounded_quadruped(descriptor)
        profile = core.balanced_wave_policy_profile(
            SELECTED_BALANCED_WAVE_POLICY_ID,
            descriptor,
        )
    except LocomotionCoreError as error:
        return {
            "schema_version": ("sporespore_descriptor_diagnostic_receipt_v1"),
            "sdk_version": SDK_VERSION,
            "abi_generation": ABI_GENERATION,
            "candidate_id": SELECTED_BALANCED_WAVE_CANDIDATE_ID,
            "policy_id": SELECTED_BALANCED_WAVE_POLICY_ID,
            "descriptor_sha256": input_identity["sha256"],
            "accepted": False,
            "failure_code": error.failure_code,
            "failure_detail": error.detail,
            "suggestion": _suggestion_for(error.failure_code),
            "domain_certificate": certificate,
            "compiled_morphology_sha256": None,
            "world_build_count": 0,
            "walking_acceptance": False,
            "physical_acceptance_authority": False,
        }
    morphology = compiled["morphology"]
    return {
        "schema_version": "sporespore_descriptor_diagnostic_receipt_v1",
        "sdk_version": SDK_VERSION,
        "abi_generation": ABI_GENERATION,
        "candidate_id": SELECTED_BALANCED_WAVE_CANDIDATE_ID,
        "policy_id": SELECTED_BALANCED_WAVE_POLICY_ID,
        "descriptor_sha256": input_identity["sha256"],
        "accepted": True,
        "failure_code": "",
        "failure_detail": "",
        "suggestion": (
            "Descriptor compiles. Physical locomotion still requires an "
            "advertised engine adapter and separately accepted evidence."
        ),
        "domain_certificate": certificate,
        "compiled_morphology_sha256": morphology["morphology_spec_sha256"],
        "ordered_body_count": len(morphology["ordered_body_ids"]),
        "ordered_joint_count": len(morphology["ordered_joint_ids"]),
        "ordered_actuator_count": len(morphology["ordered_actuator_ids"]),
        "ordered_contact_site_count": len(morphology["ordered_contact_site_ids"]),
        "branch_surface_count": len(profile["branch_surfaces"]),
        "world_build_count": 0,
        "walking_acceptance": False,
        "physical_acceptance_authority": False,
    }
