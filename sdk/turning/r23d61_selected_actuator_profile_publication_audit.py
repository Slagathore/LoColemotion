"""Executable audit for the bounded R23D61 actuator-profile publication."""

from __future__ import annotations

import copy
from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = (
    REPO_ROOT
    / "sdk"
    / "turning"
    / "r23d61_selected_actuator_profile_publication_v1.json"
)
MARKER = "QSDK_R23D61_PUBLICATION_AUDIT "
FROZEN_SOURCE_COMMIT = "c61e56907d255e920297f088b93fc3e09ba12aef"
FROZEN_SOURCE_TREE = "fb55ede695e7dda1784946382e556e7730dff8a6"
FROZEN_SOURCE_BINDINGS = {
    "sdk/core/src/actuator_profile.rs": (
        "sha256:c5a175f0783e0004b4012e803d2d254c3448b2d52b88daeefc23cf746d499795",
        "5a6c8658db5fd520907677450d70fb336697dcc5",
    ),
    "sdk/core/src/ffi.rs": (
        "sha256:195a3f6d267a5ec4dc93b5bdf1493fb6fc7ded0ddb1bb60fd29a5eb4cb7c59bb",
        "e1a65285dc831b367c75514fa41eb788acfa0c12",
    ),
    "sdk/core/src/lib.rs": (
        "sha256:d35ec807d4a1a19845bd5cab7f49efccaf4c51455751cba049d8dbd00560e510",
        "11c418a14e3a5b787c1a5a82204df6e1d10602f7",
    ),
    "sdk/include/sporespore_locomotion.h": (
        "sha256:74bff2f6046f2a110c67993e35c9375e7c79025ebb34585101995ffe70a8d6a3",
        "e6714cc53c5088a3f095d256bef56706bc073589",
    ),
    "sdk/python/sporespore_locomotion.py": (
        "sha256:f0325b6d76bbaf2507b3e8c13862d3ceedd2f388618f1879ba8d46cb09cd7485",
        "613fd86a90c13b4efa526d7038b3b470c4c3de9c",
    ),
    "sdk/python/test_ctypes_smoke.py": (
        "sha256:180eda5d3ea76f5052c6dd4c11350bd81c678d9b736bdf609ecb7b5af12ad757",
        "f786a74ea63afcb858502499c64e49eb775dcac4",
    ),
    "sdk/adapters/godot/src/lib.rs": (
        "sha256:3b9b6bb48ec28dd60c2be83856415d805b926f65370bc7bca31c4c896ccd4f3f",
        "509563d0871a9d506b8a47b3eb9e7f896d8f297a",
    ),
    "sdk/adapters/godot/gdscript/actuator_cap_profile_binding.gd": (
        "sha256:23dd0c2fb1e300175b3d0bd0e4b0b0ebf718d69723d549376af8f2b47d9b024a",
        "eb9282e94a53f4b805aa128b8708521974201f9c",
    ),
    "tests/test_sdk_qsdk_r23d61_godot_actuator_cap_profile_zero_world.gd": (
        "sha256:61d38b584cde1eecf7df2b3c490e7906fa9e2f65a06888609ee67c49aa94a1cc",
        "447dac7a915a136c3b0c11559e1361223d0423a9",
    ),
    "sdk/adapters/rapier/src/actuator_cap_profile.rs": (
        "sha256:4bc7080910078ca3c117ff459a39fdc4286441ac4a181e82867fe087f78899b3",
        "d03c13bbd17a0bd8007ee6b67552a854840e0fa1",
    ),
    "sdk/adapters/rapier/src/lib.rs": (
        "sha256:24045df90c122a547a88dc4ac8a2446c008965327719b7d3a4ab59aa6be5f409",
        "fabdca1f534394f816fc433808ff27cd3f3853a0",
    ),
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/actuator_cap_profile.py": (
        "sha256:5c0385a3c8f1d843070a7ef6623189a4388da720569e6c3f3ec9202cc9891765",
        "a99e8a6b56c62f6d144bf19699b716f504511f1c",
    ),
    "sdk/adapters/mujoco/test_actuator_cap_profile.py": (
        "sha256:90419c71c69bd419a8656c3aeca610714973e3c71d4f116a839c1fa5b015407b",
        "fad15b047005f51d3bd1bf7bc5fdf7fc8705d4db",
    ),
    "sdk/versioning/c_abi_manifest_v1.json": (
        "sha256:03847e9989760b1500783b729e1518f42f82a6421c786980df5e81e2581d66dc",
        "a37f5ca5e3f6ff0695f3017417ac6e2bf3737bf4",
    ),
    "sdk/versioning/schema_registry_v1.json": (
        "sha256:1af475670d36e94336d18bfabce43658be5e6b025cd55833ecdb15bc22e3bc9a",
        "cccdbc5ca3a7b1aa211db782ec70fd65a3b5d02b",
    ),
    "sdk/versioning/test_conformance.py": (
        "sha256:13c41ef83a6af38b94856e4893e914f56041d17d46b803827f21b2d935da5b18",
        "f240d591ec1a0c8093159ed29020c9b75fea5e04",
    ),
    "sdk/turning/r23d61_selected_actuator_profile_publication_audit.py": (
        "sha256:00839b1a390a2f72bcc51b13d4bf1f08268356bd2d44c42e241cfe91b24807f1",
        "67c58c484c36743f22f8fca2003b38baab80a6a1",
    ),
    "sdk/run_qsdk_r23d61_zero_world_gate.ps1": (
        "sha256:1c7921647af1131d6698a016eaf6ba4c9d3152c133d1038fa0da5f3730e0a734",
        "0c3650ac5d3ceba4fa050ffb1737c98b401fff3e",
    ),
    "sdk/run_conformance.ps1": (
        "sha256:7d4199f644dba4979c77cba7c45745cd17ae903e185c26d3faff811ada41fa82",
        "1fe2a1d8197d024417fd930ba5f7b1867cf812f7",
    ),
    "sdk/release/quadruped_release_contract.json": (
        "sha256:57f9190711e8129cbb9532c656958f75756f8a9883f3e6aecf2b548160273c83",
        "671bc17ad1103e0832016206cf9130f684e23a15",
    ),
    "sdk/release/quadruped_support_matrix.json": (
        "sha256:7399c9c1a98406cb8e59c479342c2153f9865425cb05037c892dde734dabbc78",
        "88068ba8ce93092cb5fc3e2d19afc853c251ad7b",
    ),
    "sdk/workbench/experiment_catalog.json": (
        "sha256:f10c05c3c6f5060c03dec7d9a3afdb6a2b9ae11883197926c3f33b74579e5661",
        "03e3b2d83eecc57f9f11dbca7bc5b83d73c40e68",
    ),
}

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
SEMANTICS_ID = (
    "sporespore_outer_control_step_angular_impulse_budget_120hz_v1"
)
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
EXPECTED_MUTATION_REJECTION_COUNT = 18


class PublicationAuditError(RuntimeError):
    """Stable failure for a publication-contract or source mutation."""


def _require(condition: bool, code: str, detail: str = "") -> None:
    if not condition:
        suffix = f":{detail}" if detail else ""
        raise PublicationAuditError(f"{code}{suffix}")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return f"sha256:{digest.hexdigest()}"


def _git_bytes(*arguments: str) -> bytes:
    process = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *arguments],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    _require(
        process.returncode == 0,
        "QSDK_R23D61_FROZEN_GIT_READ_FAILED",
        process.stderr.decode("utf-8", errors="replace").strip(),
    )
    return process.stdout


@lru_cache(maxsize=None)
def _frozen_source_blob_oid(relative: str) -> str:
    return _git_bytes(
        "rev-parse", f"{FROZEN_SOURCE_COMMIT}:{relative}"
    ).decode("ascii").strip()


def _verify_frozen_source_identity() -> None:
    observed_tree = _git_bytes(
        "rev-parse", f"{FROZEN_SOURCE_COMMIT}^{{tree}}"
    ).decode("ascii").strip()
    _require(
        observed_tree == FROZEN_SOURCE_TREE,
        "QSDK_R23D61_FROZEN_SOURCE_TREE_MISMATCH",
    )


def _load_contract() -> dict[str, Any]:
    try:
        value = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise PublicationAuditError(
            f"QSDK_R23D61_CONTRACT_READ_INVALID:{error}"
        ) from error
    _require(
        isinstance(value, dict),
        "QSDK_R23D61_CONTRACT_NOT_OBJECT",
    )
    return value


def _validate(contract: dict[str, Any], *, verify_sources: bool) -> None:
    _require(
        contract.get("schema_version")
        == "sporespore_qsdk_r23d61_selected_actuator_profile_publication_v1",
        "QSDK_R23D61_SCHEMA_INVALID",
    )
    _require(
        contract.get("status")
        == "implemented_complete_zero_world_publication_gate_passed_no_physical_successor_opened",
        "QSDK_R23D61_STATUS_INVALID",
    )
    _require(
        contract.get("gate_id") == "QSDK-R23D61"
        and contract.get("work_id")
        == "QSDK-R23D61-SELECTED-ACTUATOR-PROFILE-PUBLICATION",
        "QSDK_R23D61_IDENTITY_INVALID",
    )
    _require(
        contract.get("question_class") == "non_physical_source_conformance"
        and contract.get("physical_question_declared") is False
        and contract.get("physical_campaign_opened") is False,
        "QSDK_R23D61_QUESTION_CLASS_INVALID",
    )

    immutable = contract.get("immutable_evidence_inputs")
    _require(
        isinstance(immutable, list) and len(immutable) == 3,
        "QSDK_R23D61_IMMUTABLE_INPUT_COUNT_INVALID",
    )
    expected_immutable = (
        (
            "QSDK-R23D58",
            "sdk/turning/r23d58_godot_terminal_trace_cap_factorial_zero_world_v1.json",
            "sha256:b1d5615048c624e506dd4b89a3abac41dd07c41e90a9b814bae6cbb5913961ad",
            "ecfc191bcc97ea53b089e9862a5d0b5a7a8ad6b5",
        ),
        (
            "QSDK-R23D59",
            "sdk/turning/r23d59_godot_knee_source_finite_decision_closure_v1.json",
            "sha256:cbce64d87d18dbd819f8afd759943f4bbe7c066d32da3d4c4f567fc7b4422cc8",
            "22020d397ea4ce952a67051a843c22b388f0f78b",
        ),
        (
            "QSDK-R23D60",
            "sdk/turning/r23d60_godot_fixture_knee_held_out_turning_validation_closure_v1.json",
            "sha256:910fd0ba2369a889430c1228f2eaea1146cf26005c4ac51f353803869d709fd8",
            "3d884af6dc0a15aa9bd2cde15de4535a24bb44a2",
        ),
    )
    for item, expected in zip(immutable, expected_immutable, strict=True):
        gate_id, path, digest, source_commit = expected
        _require(
            item.get("gate_id") == gate_id
            and item.get("path") == path
            and item.get("raw_sha256") == digest
            and item.get("physical_source_commit") == source_commit
            and item.get("historical_result_reinterpreted") is False,
            "QSDK_R23D61_IMMUTABLE_INPUT_INVALID",
            gate_id,
        )
        if verify_sources:
            source_path = REPO_ROOT / path
            _require(
                source_path.is_file() and _sha256(source_path) == digest,
                "QSDK_R23D61_IMMUTABLE_INPUT_HASH_MISMATCH",
                path,
            )

    publication = contract.get("publication")
    _require(
        isinstance(publication, dict)
        and publication.get("profile_id") == PROFILE_ID
        and publication.get("profile_sha256") == PROFILE_SHA256
        and publication.get("descriptor_sha256") == DESCRIPTOR_SHA256
        and publication.get("morphology_spec_sha256")
        == MORPHOLOGY_SPEC_SHA256
        and publication.get("semantics_id") == SEMANTICS_ID
        and publication.get("outer_step_hz") == 120
        and publication.get("unit") == "newton_meter_second"
        and publication.get("selected_predecessor_profile_id")
        == "portable_hip__fixture_knee"
        and publication.get("legacy_fixture_comparator_was_public_semantics")
        is False
        and publication.get("legacy_fixture_behavior_silently_applied")
        is False,
        "QSDK_R23D61_PUBLICATION_IDENTITY_INVALID",
    )
    entries = publication.get("ordered_caps")
    _require(
        isinstance(entries, list) and len(entries) == 8,
        "QSDK_R23D61_PUBLICATION_CAP_COUNT_INVALID",
    )
    for index, entry in enumerate(entries):
        _require(
            entry.get("actuator_id") == ORDERED_ACTUATOR_IDS[index]
            and entry.get("joint_id") == ORDERED_JOINT_IDS[index]
            and entry.get("source")
            == (
                "r23d60_selected_portable_hip_explicit_publication"
                if index % 2 == 0
                else "r23d60_selected_fixture_knee_explicit_publication"
            )
            and entry.get("base_compiled_maximum_impulse_nms")
            == ORDERED_BASE_CAPS_NMS[index]
            and entry.get("base_compiled_maximum_impulse_binary64_hex")
            == ORDERED_BASE_CAPS_BINARY64_HEX[index]
            and entry.get("maximum_outer_step_impulse_nms")
            == ORDERED_CAPS_NMS[index]
            and entry.get("maximum_outer_step_impulse_binary64_hex")
            == ORDERED_CAPS_BINARY64_HEX[index]
            and entry.get("differs_from_base_compiled_morphology")
            == (index not in (0, 2))
            and entry.get("base_to_profile_binary64_ulp_distance")
            == ORDERED_ULP_DISTANCES[index],
            "QSDK_R23D61_PUBLICATION_CAP_INVALID",
            str(index),
        )

    support = contract.get("support_and_refusal_contract")
    _require(
        isinstance(support, dict)
        and support.get("exact_descriptor_status") == "supported_exact"
        and support.get("arbitrary_valid_descriptor_status")
        == "out_of_domain_morphology"
        and support.get("unknown_profile_status") == "unsupported_profile"
        and support.get("invalid_descriptor_transport") == "core_error"
        and support.get("canonical_cross_language_descriptor_identity_required")
        is True
        and support.get("raw_binary64_descriptor_identity_required") is False
        and support.get("profile_cap_binary64_identity_strings_required") is True
        and support.get("arbitrary_morphology_support") is False,
        "QSDK_R23D61_SUPPORT_CONTRACT_INVALID",
    )

    observations = contract.get("preserved_development_observations")
    _require(
        isinstance(observations, list)
        and len(observations) == 5
        and [item.get("observation_id") for item in observations]
        == [
            "QSDK-R23D61-DEV-01",
            "QSDK-R23D61-DEV-02",
            "QSDK-R23D61-DEV-03",
            "QSDK-R23D61-DEV-04",
            "QSDK-R23D61-DEV-05",
        ]
        and observations[0].get("classification")
        == "retained_numeric_identity_difference"
        and observations[1].get("classification")
        == "transport_adequacy_constraint"
        and observations[2].get("classification")
        == "rejected_cross_language_identity_design"
        and observations[3].get("classification")
        == "fail_closed_receipt_observability_gap"
        and observations[4].get("classification")
        == "retained_dirty_full_conformance_incomplete"
        and all(item.get("world_build_count") == 0 for item in observations)
        and all(item.get("physical_result") is False for item in observations)
        and observations[2].get("solver_step_count") == 0
        and observations[2].get("physical_authority") is False
        and observations[3].get("solver_step_count") == 0
        and observations[3].get("physical_authority") is False
        and observations[4].get("source_head")
        == "2858f722e6855995782e1811b3653d520acae333"
        and observations[4].get("run_receipt_raw_sha256")
        == "sha256:dd2289c42ce9b795ba2bdb118cf5a90e096d08d43debadc92caaa0557f262323"
        and observations[4].get("failed_stage_receipt_raw_sha256")
        == "sha256:6b16c840239052516eb730ef446a46c7ac8b763ac6ea338fb2a03bcc92ef6051"
        and observations[4].get("physical_authority") is False
        and observations[4].get("release_authority") is False,
        "QSDK_R23D61_DEVELOPMENT_OBSERVATIONS_INVALID",
    )

    mappings = contract.get("host_mappings")
    _require(
        isinstance(mappings, dict) and set(mappings) == {"godot", "rapier", "mujoco"},
        "QSDK_R23D61_HOST_MAPPING_SET_INVALID",
    )
    expected_mapping_ids = {
        "godot": "sporespore_godot_hinge_maximum_impulse_cap_mapping_v1",
        "rapier": "sporespore_rapier_force_based_outer_impulse_cap_mapping_v1",
        "mujoco": "sporespore_mujoco_velocity_force_range_cap_mapping_v1",
    }
    for engine_id, mapping in mappings.items():
        _require(
            mapping.get("host_mapping_id") == expected_mapping_ids[engine_id]
            and mapping.get("validated_actuator_count") == 8
            and mapping.get("world_build_count") == 0
            and mapping.get("solver_step_count") == 0
            and mapping.get("physics_state_modified") is False
            and mapping.get("physical_acceptance_authority") is False,
            "QSDK_R23D61_HOST_MAPPING_INVALID",
            engine_id,
        )

    adequacy = contract.get("threshold_margin_cohort_and_population_adequacy")
    _require(
        isinstance(adequacy, dict)
        and adequacy.get("physical_outcome_threshold_count") == 0
        and adequacy.get("superiority_margin_declared") is False
        and adequacy.get("equivalence_or_non_inferiority_margin_declared")
        is False
        and adequacy.get("physical_cohort_declared") is False
        and adequacy.get("population_claim") is False
        and adequacy.get("godot_readback_tolerance_nms") == 2.5e-7
        and adequacy.get("godot_tolerance_is_physical_margin") is False
        and adequacy.get("rapier_rounding_bound_is_physical_margin") is False
        and adequacy.get("mujoco_rounding_bound_is_physical_margin") is False,
        "QSDK_R23D61_ADEQUACY_INVALID",
    )

    gate = contract.get("complete_zero_world_gate")
    _require(
        isinstance(gate, dict)
        and gate.get("passed") is True
        and gate.get("core_test_count") == 6
        and gate.get("rapier_test_count") == 2
        and gate.get("mujoco_test_count") == 2
        and gate.get("godot_mutation_rejection_count") == 17
        and gate.get("rapier_mutation_rejection_count") == 9
        and gate.get("mujoco_mutation_rejection_count") == 9
        and gate.get("publication_audit_mutation_rejection_count") == 18
        and gate.get("world_build_count") == 0
        and gate.get("physical_question_declared") is False,
        "QSDK_R23D61_ZERO_WORLD_GATE_INVALID",
    )

    claims = contract.get("claim_boundary")
    _require(
        isinstance(claims, dict)
        and claims.get("exact_scope_profile_published") is True
        and claims.get("godot_configuration_mapping_conformed") is True
        and claims.get("rapier_configuration_mapping_conformed") is True
        and claims.get("mujoco_configuration_mapping_conformed") is True
        and claims.get("arbitrary_morphology_support") is False
        and claims.get("new_physical_result") is False
        and claims.get("three_engine_turning") is False
        and claims.get("prone_to_standing") is False
        and claims.get("cross_engine_equivalence") is False
        and claims.get("physical_acceptance_authority") is False
        and claims.get("release_authority") is False,
        "QSDK_R23D61_CLAIM_BOUNDARY_INVALID",
    )

    next_priority = contract.get("next_movement_priority")
    _require(
        isinstance(next_priority, dict)
        and next_priority.get("movement") == "canonical_prone_to_standing"
        and next_priority.get("priority_after_publication") == 1
        and next_priority.get("physical_question_declared") is False
        and next_priority.get("physical_campaign_opened") is False
        and next_priority.get("additional_turning_campaign_required_first")
        is False,
        "QSDK_R23D61_NEXT_PRIORITY_INVALID",
    )
    release = contract.get("release_boundary")
    _require(
        isinstance(release, dict)
        and release.get("passed_gate_count") == 10
        and release.get("total_gate_count") == 25
        and release.get("release_ready") is False,
        "QSDK_R23D61_RELEASE_BOUNDARY_INVALID",
    )

    bindings = contract.get("source_bindings")
    _require(
        isinstance(bindings, list)
        and len(bindings) == 22
        and len({item.get("path") for item in bindings}) == len(bindings),
        "QSDK_R23D61_SOURCE_BINDING_SET_INVALID",
    )
    _require(
        {item.get("path") for item in bindings}
        == set(FROZEN_SOURCE_BINDINGS),
        "QSDK_R23D61_FROZEN_SOURCE_BINDING_SET_INVALID",
    )
    if verify_sources:
        _verify_frozen_source_identity()
        for item in bindings:
            relative = item.get("path")
            digest = item.get("raw_sha256")
            expected_digest, expected_blob_oid = FROZEN_SOURCE_BINDINGS.get(
                relative, (None, None)
            )
            _require(
                isinstance(relative, str)
                and isinstance(digest, str)
                and digest.startswith("sha256:"),
                "QSDK_R23D61_SOURCE_BINDING_INVALID",
            )
            _require(
                digest == expected_digest
                and _frozen_source_blob_oid(relative) == expected_blob_oid,
                "QSDK_R23D61_SOURCE_BINDING_HASH_MISMATCH",
                relative,
            )


def _mutation_rejection_count(contract: dict[str, Any]) -> int:
    candidates: list[dict[str, Any]] = []

    def mutated() -> dict[str, Any]:
        candidate = copy.deepcopy(contract)
        candidates.append(candidate)
        return candidate

    mutated()["schema_version"] = "mutated"
    mutated()["status"] = "mutated"
    mutated()["gate_id"] = "QSDK-R23D60"
    mutated()["question_class"] = "finite_decision"
    mutated()["physical_question_declared"] = True
    mutated()["publication"]["profile_id"] = "mutated"
    mutated()["publication"]["profile_sha256"] = "sha256:mutated"
    mutated()["publication"]["ordered_caps"][4][
        "maximum_outer_step_impulse_binary64_hex"
    ] = "0x3facdd051a8b389c"
    mutated()["publication"]["ordered_caps"][4][
        "maximum_outer_step_impulse_nms"
    ] = math.nextafter(ORDERED_CAPS_NMS[4], math.inf)
    mutated()["publication"]["ordered_caps"][4][
        "base_to_profile_binary64_ulp_distance"
    ] = "0"
    mutated()["support_and_refusal_contract"]["arbitrary_morphology_support"] = True
    mutated()["host_mappings"]["rapier"]["world_build_count"] = 1
    mutated()["threshold_margin_cohort_and_population_adequacy"][
        "godot_tolerance_is_physical_margin"
    ] = True
    mutated()["source_bindings"][0]["raw_sha256"] = "sha256:mutated"
    mutated()["claim_boundary"]["three_engine_turning"] = True
    mutated()["next_movement_priority"]["movement"] = "more_turning"
    mutated()["release_boundary"]["passed_gate_count"] = 11
    mutated()["immutable_evidence_inputs"][2]["raw_sha256"] = "sha256:mutated"

    rejected = 0
    for candidate in candidates:
        try:
            _validate(candidate, verify_sources=True)
        except PublicationAuditError:
            rejected += 1
    return rejected


def run_audit() -> dict[str, Any]:
    contract = _load_contract()
    _validate(contract, verify_sources=True)
    mutation_rejection_count = _mutation_rejection_count(contract)
    _require(
        mutation_rejection_count == EXPECTED_MUTATION_REJECTION_COUNT,
        "QSDK_R23D61_MUTATION_REJECTION_COUNT_INVALID",
    )
    return {
        "schema_version": "sporespore_qsdk_r23d61_publication_audit_receipt_v1",
        "ok": True,
        "gate_id": "QSDK-R23D61",
        "profile_id": PROFILE_ID,
        "profile_sha256": PROFILE_SHA256,
        "source_binding_mode": "frozen_git_commit",
        "source_commit": FROZEN_SOURCE_COMMIT,
        "source_tree": FROZEN_SOURCE_TREE,
        "source_binding_count": len(contract["source_bindings"]),
        "immutable_evidence_input_count": 3,
        "mutation_rejection_count": mutation_rejection_count,
        "world_build_count": 0,
        "physical_question_declared": False,
        "physical_campaign_opened": False,
        "turning_claimed": False,
        "prone_to_standing_claimed": False,
        "cross_engine_equivalence_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    try:
        report = run_audit()
    except PublicationAuditError as error:
        report = {
            "schema_version": (
                "sporespore_qsdk_r23d61_publication_audit_receipt_v1"
            ),
            "ok": False,
            "failure_code": str(error),
            "world_build_count": 0,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        print(MARKER + json.dumps(report, allow_nan=False, sort_keys=True))
        return 1
    print(MARKER + json.dumps(report, allow_nan=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
