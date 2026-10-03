"""Read a separately byte-bound prepared-context capture, never a failed packet.

The enclosing qualification must supply the expected raw binding. This reader
checks integrity and source relationships; it cannot establish that binding's
origin or turn a development capture into official qualification by itself.
"""

from __future__ import annotations

import hashlib

import qsdk_r10f_l15_collection_retention as packet

SCHEMA = "sporespore_qsdk_r10f_l15_prepared_collection_context_v1"
CONTEXT_SCHEMA = (
    "sporespore_qsdk_r24d172_godot_initializer_retention_recovery_behavior_context_v18"
)
TASK = "sporespore_canonical_ventral_prone_to_four_foot_stance_v1"
SEMANTICS = "sporespore_qsdk_r24d2_portable_recovery_semantics_v1"
PROFILE = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
CONTROLLER = "sporespore_exact_s169_prone_to_standing_controller_v6"
BASE_SHA = "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0"
RECOVERY_SHA = "sha256:431a9c8001931e751bb2f1f2750c31650dd2d994575a736c53adbef1b27a71f6"
ZERO_COUNTERS = {
    "compiled_collection_call_count",
    "portable_recovery_advance_call_count",
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "scene_tree_insertion_count",
    "native_physics_read_count",
    "solver_step_count",
}
FALSE_FLAGS = {
    "physics_state_modified",
    "official_context_qualification",
    "physical_worker_context_installed",
    "physical_execution_authorized",
    "physical_acceptance_authority",
    "release_authority",
}
CAPTURE_FIELDS = (
    ZERO_COUNTERS
    | FALSE_FLAGS
    | {
        "schema_version",
        "ledger_scope",
        "ok",
        "failure_code",
        "source_context",
        "expected_identity",
        "source_is_prepared_context_not_observation",
        "production_request_identity_projection_checked",
        "collection_request_constructor_call_count",
    }
)


def require(condition, code):
    if not condition:
        raise ValueError("QSDK_R10F_L15_COLLECTION_CONTEXT_" + code)


COMPARISON_SCHEMA = "sporespore_qsdk_r10f_l15_pre_world_context_comparison_v1"
COMPARISON_FALSE_FLAGS = {
    "observation_or_failed_packet_used_as_expected_context",
    "expected_binding_origin_authenticated_here",
    "official_context_qualification",
    "physics_state_modified",
    "physical_execution_authorized",
    "physical_acceptance_authority",
    "release_authority",
}
COMPARISON_FIELDS = (
    ZERO_COUNTERS
    | COMPARISON_FALSE_FLAGS
    | {
        "schema_version",
        "ledger_scope",
        "ok",
        "failure_code",
        "expected_capture_binding",
        "observed_capture",
        "prepared_context_capture_failure_code",
        "expected_capture_binding_matched",
        "context_capture_call_count",
    }
)


def validate_expected_binding(value):
    """Validate a caller-supplied identity, never discover it in a worker report."""
    require(
        type(value) is dict and value.keys() == {"utf8_byte_length", "raw_sha256"},
        "EXPECTED_BINDING_FIELDS",
    )
    digest = value["raw_sha256"]
    require(
        type(value["utf8_byte_length"]) is int
        and 1 <= value["utf8_byte_length"] <= 2**63 - 1
        and type(digest) is str
        and len(digest) == 71
        and digest.startswith("sha256:")
        and all(character in "0123456789abcdef" for character in digest[7:]),
        "EXPECTED_BINDING_KINDS_OR_VALUES",
    )


def validate_worker_comparison(
    value, *, expected_raw_binding, expected_identity, canonical_sha256
):
    """Verify the worker's actual pre-world success against external expectations.

    A retained refusal or absent capture is not a successful context comparison.
    The enclosing reader can still preserve those reports as invalid diagnostics.
    This function cannot authenticate the enclosing qualification's origin.
    """
    validate_expected_binding(expected_raw_binding)
    packet.exact_keys(expected_identity, packet.IDENTITY_KEYS, "EXPECTED_IDENTITY")
    packet.exact_keys(value, COMPARISON_FIELDS, "WORKER_CONTEXT_COMPARISON")
    require(
        value["schema_version"] == COMPARISON_SCHEMA
        and packet.same(
            value["ledger_scope"],
            {
                "subsystem": "recovery",
                "engine_scope": "godot_jolt",
                "authority_mode": "prepared_context_comparison_before_world",
                "question_class": "development",
            },
        )
        and value["ok"] is True
        and value["failure_code"] is None
        and value["prepared_context_capture_failure_code"] is None
        and value["expected_capture_binding_matched"] is True
        and type(value["context_capture_call_count"]) is int
        and value["context_capture_call_count"] == 1,
        "WORKER_COMPARISON_SCOPE",
    )
    for name in ZERO_COUNTERS:
        require(
            type(value[name]) is int and value[name] == 0,
            "WORKER_COMPARISON_ZERO:" + name,
        )
    for name in COMPARISON_FALSE_FLAGS:
        require(value[name] is False, "WORKER_COMPARISON_AUTHORITY:" + name)
    require(
        packet.same(value["expected_capture_binding"], expected_raw_binding),
        "WORKER_EXPECTED_BINDING_NOT_ENCLOSING_EXPECTATION",
    )
    raw = packet.verify_bytes(value["observed_capture"], "WORKER_CAPTURE").decode(
        "utf-8", errors="strict"
    )
    proof = validate_capture(
        raw,
        expected_raw_binding=expected_raw_binding,
        canonical_sha256=canonical_sha256,
    )
    require(
        packet.same(proof["expected_identity"], expected_identity),
        "WORKER_CONTEXT_NOT_ENCLOSING_COLLECTION_IDENTITY",
    )
    return {
        "schema_version": "sporespore_qsdk_r10f_l15_worker_context_integrity_v1",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "read_only_worker_context_against_enclosing_expectation",
            "question_class": "development",
        },
        "ok": True,
        "prepared_context_valid": True,
        "expected_context_origin_authenticated_here": False,
        "official_context_qualification": False,
        "context_integrity_establishes_valid_child": False,
        "raw_capture_binding": dict(expected_raw_binding),
        **dict.fromkeys(ZERO_COUNTERS, 0),
        "physics_state_modified": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def raw_binding(text):
    require(type(text) is str, "RAW_TEXT_KIND")
    raw = text.encode("utf-8", errors="strict")
    return {
        "utf8_byte_length": len(raw),
        "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
    }


def validate_capture(raw_text, *, expected_raw_binding, canonical_sha256):
    require(
        packet.same(expected_raw_binding, raw_binding(raw_text)),
        "ENCLOSING_RAW_BINDING",
    )
    capture = packet.parse_json(raw_text)
    packet.exact_keys(capture, CAPTURE_FIELDS, "PREPARED_CONTEXT_CAPTURE")
    require(
        capture["schema_version"] == SCHEMA
        and packet.same(
            capture["ledger_scope"],
            {
                "subsystem": "recovery",
                "engine_scope": "godot_jolt",
                "authority_mode": "zero_world_prepared_expected_context_capture",
                "question_class": "development",
            },
        )
        and capture["ok"] is True
        and capture["failure_code"] is None
        and capture["source_is_prepared_context_not_observation"] is True
        and capture["production_request_identity_projection_checked"] is True
        and type(capture["collection_request_constructor_call_count"]) is int
        and capture["collection_request_constructor_call_count"] == 1,
        "CAPTURE_SCOPE",
    )
    for name in ZERO_COUNTERS:
        require(
            type(capture[name]) is int and capture[name] == 0, "CAPTURE_ZERO:" + name
        )
    for name in FALSE_FLAGS:
        require(capture[name] is False, "CAPTURE_AUTHORITY:" + name)
    context_raw = packet.verify_bytes(capture["source_context"], "SOURCE_CONTEXT")
    identity_raw = packet.verify_bytes(
        capture["expected_identity"], "EXPECTED_IDENTITY"
    )
    context = packet.parse_json(context_raw.decode("utf-8"))
    identity = packet.parse_json(identity_raw.decode("utf-8"))
    packet.exact_keys(identity, packet.IDENTITY_KEYS, "EXPECTED_CONTEXT_IDENTITY")
    require(
        type(context) is dict
        and context.get("schema_version") == CONTEXT_SCHEMA
        and context.get("ok") is True
        and context.get("recovery_controller_id") == CONTROLLER,
        "SOURCE_CONTEXT_IDENTITY",
    )
    for name in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        require(
            type(context.get(name)) is int and context[name] == 0, "SOURCE_ZERO:" + name
        )
    for name in (
        "physics_state_modified",
        "physical_acceptance_authority",
        "release_authority",
    ):
        require(context.get(name) is False, "SOURCE_AUTHORITY:" + name)
    require(
        identity["task_id"] == TASK
        and identity["semantics_id"] == SEMANTICS
        and identity["actuator_profile_id"] == PROFILE
        and identity["arm_kind"] == "candidate_command"
        and packet.same(
            identity["morphology_context"], context.get("morphology_context")
        )
        and packet.same(identity["adapter_capability"], context.get("capability"))
        and packet.same(identity["runtime_binding"], context.get("runtime_binding")),
        "IDENTITY_SOURCE_PROJECTION",
    )
    morphology = identity["morphology_context"]
    runtime = identity["runtime_binding"]
    require(type(morphology) is dict and type(runtime) is dict, "SOURCE_OBJECT_KINDS")
    require(
        morphology.get("schema_version") == "sporespore_recovery_morphology_context_v1"
        and morphology.get("recovery_morphology_id") == "qsdk_r24_recovery_s169_v1"
        and morphology.get("base_descriptor_sha256") == BASE_SHA
        and morphology.get("recovery_descriptor_sha256") == RECOVERY_SHA
        and canonical_sha256(identity["descriptor"]) == BASE_SHA
        and canonical_sha256(morphology.get("recovery_descriptor")) == RECOVERY_SHA,
        "DESCRIPTOR_DIGESTS",
    )
    require(
        runtime.get("schema_version")
        == "sporespore_recovery_native_collector_binding_v1"
        and runtime.get("capability_sha256")
        == context.get("capability_sha256")
        == canonical_sha256(identity["adapter_capability"])
        and runtime.get("runtime_qualification_sha256")
        == context.get("runtime_qualification_sha256")
        == canonical_sha256(context.get("runtime_profile_receipt")),
        "CAPABILITY_RUNTIME_DIGESTS",
    )
    for key, expected in {
        "exact_runtime_identity_qualified": True,
        "native_post_step_only": True,
        "source_measurement_only": True,
        "missing_value_synthesis_permitted": False,
        "engine_identity_exposed_to_controller": False,
    }.items():
        require(runtime.get(key) is expected, "RUNTIME_SCOPE:" + key)
    return {
        "schema_version": "sporespore_qsdk_r10f_l15_prepared_collection_context_integrity_v1",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_read_only_expected_context_integrity",
            "question_class": "development",
        },
        "ok": True,
        "external_raw_capture_binding_verified": True,
        "raw_capture_binding": raw_binding(raw_text),
        "source_context_raw_sha256": capture["source_context"]["raw_sha256"],
        "expected_identity_raw_sha256": capture["expected_identity"]["raw_sha256"],
        "expected_identity": identity,
        "source_origin_authenticated_by_this_reader": False,
        "complete_v18_native_predicate_reexecuted_by_this_reader": False,
        "official_context_qualification": False,
        "physical_worker_context_installed": False,
        **dict.fromkeys(ZERO_COUNTERS, 0),
        "physics_state_modified": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
