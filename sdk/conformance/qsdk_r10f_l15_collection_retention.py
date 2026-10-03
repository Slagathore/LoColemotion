"""Independent, read-only validation of L15 collection transport packets.

Expected request identity belongs to the enclosing authority, not the packet.
Original UTF-8 response bytes are authoritative for this descriptive reader.
Godot's legacy decoded success numbers are explicitly not used for inference;
this module neither invents a rounding tolerance nor calls the SDK again.
Packet integrity alone never establishes a valid physical route or behavior.
"""

from __future__ import annotations

import hashlib
import json
import math

SCHEMA = "sporespore_qsdk_r10f_l15_collection_transport_retention_v1"
REQUEST_SCHEMA = "sporespore_recovery_native_collection_request_v3"
TRANSPORT_ID = "godot_4_7_sorted_full_precision_authoritative_json_v1"
SOURCE_ROLES = {"source_application", "source_memory", "bound_observation"}
IDENTITY_KEYS = {
    "task_id",
    "semantics_id",
    "actuator_profile_id",
    "descriptor",
    "morphology_context",
    "adapter_capability",
    "runtime_binding",
    "arm_kind",
}
ZERO_COUNTERS = {
    "additional_collection_call_count",
    "additional_controller_advance_count",
    "additional_native_physics_read_count",
    "additional_solver_step_count",
}
FALSE_FLAGS = {
    "raw_and_decoded_numeric_identity_claimed",
    "retention_is_reconstruction",
    "physical_acceptance_authority",
    "release_authority",
}
PACKET_KEYS = (
    {
        "schema_version",
        "ledger_scope",
        "stage",
        "transport_id",
        "transport_failure_code",
        "request",
        "response",
        "source_links",
        "decoded_collection",
        "decoded_collection_is_legacy_godot_view",
        "request_serialization_call_count",
        "compiled_collection_call_count",
        "response_json_parse_call_count",
    }
    | ZERO_COUNTERS
    | FALSE_FLAGS
)


def require(condition, code):
    if not condition:
        raise ValueError("QSDK_R10F_L15_COLLECTION_RETENTION_" + code)


def exact_keys(value, expected, label):
    require(type(value) is dict and value.keys() == expected, label + "_KEYS")


def same(left, right):
    """Keep Boolean, integer and float kinds distinct, including signed zero."""
    if type(left) is not type(right):
        return False
    if type(left) is dict:
        return left.keys() == right.keys() and all(
            same(left[k], right[k]) for k in left
        )
    if type(left) is list:
        return len(left) == len(right) and all(same(a, b) for a, b in zip(left, right))
    if type(left) is float:
        return (
            math.isfinite(left) and math.isfinite(right) and left.hex() == right.hex()
        )
    return left == right


def finite_json(value, depth=0):
    require(depth <= 128, "JSON_DEPTH")
    if type(value) is dict:
        for key, item in value.items():
            require(type(key) is str, "JSON_KEY_KIND")
            finite_json(item, depth + 1)
    elif type(value) is list:
        for item in value:
            finite_json(item, depth + 1)
    elif type(value) is float:
        require(math.isfinite(value), "JSON_NONFINITE")
    else:
        require(value is None or type(value) in (bool, int, str), "JSON_VALUE_KIND")


def parse_json(text):
    def pairs(items):
        result = {}
        for key, item in items:
            require(key not in result, "JSON_DUPLICATE_KEY")
            result[key] = item
        return result

    def invalid_constant(_value):
        raise ValueError("QSDK_R10F_L15_COLLECTION_RETENTION_JSON_NONFINITE")

    value = json.loads(text, object_pairs_hook=pairs, parse_constant=invalid_constant)
    finite_json(value)
    return value


def verify_bytes(binding, label="BYTE_BINDING"):
    exact_keys(binding, {"utf8_text", "utf8_byte_length", "raw_sha256"}, label)
    require(type(binding["utf8_text"]) is str, label + "_TEXT_KIND")
    require(type(binding["utf8_byte_length"]) is int, label + "_LENGTH_KIND")
    require(type(binding["raw_sha256"]) is str, label + "_DIGEST_KIND")
    raw = binding["utf8_text"].encode("utf-8", errors="strict")
    require(len(raw) == binding["utf8_byte_length"], label + "_LENGTH")
    require(
        "sha256:" + hashlib.sha256(raw).hexdigest() == binding["raw_sha256"],
        label + "_DIGEST",
    )
    return raw


def local_failure(code, detail=""):
    return {
        "schema_version": "sporespore_godot_recovery_runtime_local_failure_v1",
        "ok": False,
        "failure_code": code,
        "detail": detail,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def native_envelope(text):
    """Classify independently; stricter duplicate/nonfinite JSON is refused."""
    try:
        value = parse_json(text)
    except (ValueError, RecursionError):
        return None, "ABI_RESPONSE_JSON_INVALID"
    if type(value) is not dict:
        return value, "ABI_RESPONSE_NOT_DICTIONARY"
    if type(value.get("ok")) is not bool:
        return value, "ABI_RESPONSE_OK_FLAG_INVALID"
    if value["ok"] and type(value.get("value")) is not dict:
        return value, "ABI_VALUE_NOT_DICTIONARY"
    if not value["ok"] and (
        type(value.get("failure_code")) is not str
        or not value["failure_code"]
        or type(value.get("detail", "")) is not str
    ):
        return value, "ABI_REFUSAL_SHAPE_INVALID"
    return value, None


def compare_legacy_value(native, legacy, numeric_differences, path="$", depth=0):
    """Check structure and all nonnumeric values, never a numeric tolerance.

    Numeric differences are reported, not approved as equivalent. The reader
    uses original native values and separately checks load-bearing zero counts.
    The producer tests compare the complete view to the actual Godot decoder.
    """
    require(depth <= 128, "DECODED_DEPTH")
    if type(native) in (int, float) and type(legacy) in (int, float):
        finite_json(native)
        finite_json(legacy)
        if not same(native, legacy):
            numeric_differences.append(
                {
                    "path": path,
                    "native_kind": type(native).__name__,
                    "legacy_kind": type(legacy).__name__,
                    "native_repr": repr(native),
                    "legacy_repr": repr(legacy),
                    "native_float_hex": native.hex() if type(native) is float else None,
                    "legacy_float_hex": legacy.hex() if type(legacy) is float else None,
                }
            )
        return
    require(type(native) is type(legacy), "DECODED_KIND:" + path)
    if type(native) is dict:
        require(native.keys() == legacy.keys(), "DECODED_KEYS:" + path)
        for key in native:
            compare_legacy_value(
                native[key],
                legacy[key],
                numeric_differences,
                path + "." + key,
                depth + 1,
            )
    elif type(native) is list:
        require(len(native) == len(legacy), "DECODED_LENGTH:" + path)
        for index, (left, right) in enumerate(zip(native, legacy)):
            compare_legacy_value(
                left, right, numeric_differences, f"{path}[{index}]", depth + 1
            )
    else:
        require(same(native, legacy), "DECODED_VALUE:" + path)


def validate_packet(
    packet, *, expected_identity, canonical_sha256, expected_global_step=None
):
    # Use the enclosing reader's already-qualified SDK canonicalizer. Raw
    # transport byte hashes remain separate and never use this callback.
    require(callable(canonical_sha256), "CANONICALIZER_REQUIRED")
    exact_keys(expected_identity, IDENTITY_KEYS, "EXPECTED_IDENTITY")
    finite_json(expected_identity)
    if expected_global_step is not None:
        require(
            type(expected_global_step) is int and expected_global_step > 0,
            "EXPECTED_STEP",
        )
    exact_keys(packet, PACKET_KEYS, "PACKET")
    require(
        packet["schema_version"] == SCHEMA and packet["transport_id"] == TRANSPORT_ID,
        "PACKET_SCHEMA",
    )
    require(
        same(
            packet["ledger_scope"],
            {
                "subsystem": "recovery",
                "engine_scope": "godot_jolt",
                "authority_mode": "development_exact_collection_transport_retention",
                "question_class": "development",
            },
        ),
        "LEDGER_SCOPE",
    )
    for key in ZERO_COUNTERS:
        require(type(packet[key]) is int and packet[key] == 0, key.upper())
    for key in FALSE_FLAGS:
        require(packet[key] is False, key.upper())
    require(
        packet["decoded_collection_is_legacy_godot_view"] is True,
        "LEGACY_VIEW_DECLARATION",
    )
    exact_keys(packet["source_links"], SOURCE_ROLES, "SOURCE_LINKS")
    sources = {
        role: parse_json(verify_bytes(binding, role).decode("utf-8"))
        for role, binding in packet["source_links"].items()
    }
    for role, value in sources.items():
        require(type(value) is dict and bool(value), "SOURCE_INCOMPLETE:" + role)
    app, memory, bound = (
        sources[role]
        for role in ("source_application", "source_memory", "bound_observation")
    )
    require(
        all(
            key in app
            for key in (
                "schema_version",
                "command_id",
                "command_sha256",
                "semantic_step",
            )
        ),
        "APPLICATION_SOURCE_SHAPE",
    )
    require(
        type(memory.get("phase")) is str and "phase_steps_observed" in memory,
        "MEMORY_SOURCE_SHAPE",
    )
    require(
        all(
            type(bound.get(key)) is dict
            for key in ("observation_v2", "observation_v3", "source_binding")
        ),
        "BOUND_SOURCE_SHAPE",
    )
    if expected_global_step is not None:
        require(
            type(app["semantic_step"]) in (int, float)
            and app["semantic_step"] == expected_global_step,
            "APPLICATION_STEP",
        )
    request = None
    if packet["request"] is not None:
        request = parse_json(verify_bytes(packet["request"], "REQUEST").decode("utf-8"))
        exact_keys(
            request,
            IDENTITY_KEYS
            | {"schema_version", "phase", "observation", "observation_source_binding"},
            "REQUEST",
        )
        for key in IDENTITY_KEYS:
            require(
                same(request[key], expected_identity[key]), "REQUEST_IDENTITY:" + key
            )
        require(request["phase"] == memory["phase"], "REQUEST_MEMORY_PHASE")
        require(
            same(request["observation"], bound["observation_v2"]),
            "REQUEST_OBSERVATION_SOURCE",
        )
        require(
            same(request["observation_source_binding"], bound["source_binding"]),
            "REQUEST_BINDING_SOURCE",
        )
        if expected_global_step is not None:
            identity = request["observation"].get("engine_step_identity", {})
            require(
                type(identity.get("semantic_step")) in (int, float)
                and identity["semantic_step"] == expected_global_step,
                "REQUEST_GLOBAL_STEP",
            )
    expected_serializations = int(request is not None)
    require(
        type(packet["request_serialization_call_count"]) is int
        and packet["request_serialization_call_count"] == expected_serializations,
        "SERIALIZATION_COUNT",
    )
    stage = packet["stage"]
    code = packet["transport_failure_code"]
    decoded = packet["decoded_collection"]
    differences = []
    native_kind = "not_called"
    native_supported = False
    refusal_exact = False
    if stage == "precollection_refused":
        require(type(code) is str and bool(code), "PRECOLLECTION_CODE")
        require(packet["response"] is None, "PRECOLLECTION_RESPONSE")
        require(
            decoded is None or same(decoded, local_failure(code)),
            "PRECOLLECTION_DECODED",
        )
        expected_calls = 0
    else:
        require(
            request is not None and request["schema_version"] == REQUEST_SCHEMA,
            "CALLED_REQUEST",
        )
        if "canonical_ownership_mapping" in app:
            mapping = app["canonical_ownership_mapping"]
            require(
                type(mapping) is dict and same(mapping.get("source_memory"), memory),
                "CALLED_MAPPING_MEMORY_SOURCE",
            )
            for label, value, expected_digest in (
                ("MAPPING_MEMORY", memory, mapping.get("source_memory_sha256")),
                (
                    "MAPPING_APPLICATION",
                    mapping.get("source_application"),
                    mapping.get("source_application_sha256"),
                ),
                ("MAPPING", mapping, app.get("canonical_ownership_mapping_sha256")),
            ):
                require(
                    type(value) is dict and canonical_sha256(value) == expected_digest,
                    label + "_DIGEST",
                )
        applied = request["observation"].get("applied_actuation")
        require(
            type(applied) is dict
            and canonical_sha256(app) == applied.get("adapter_receipt_sha256"),
            "APPLICATION_OBSERVATION_SOURCE_DIGEST",
        )
        response = verify_bytes(packet["response"], "RESPONSE").decode("utf-8")
        envelope, malformed = native_envelope(response)
        expected_calls = 1
        if malformed is not None:
            require(
                stage == "compiled_response_malformed" and code == malformed,
                "MALFORMED_CLASSIFICATION",
            )
            require(same(decoded, local_failure(malformed)), "MALFORMED_DECODED")
            native_kind = "malformed_response"
        else:
            require(
                stage == "compiled_response_decoded" and code is None, "DECODED_STAGE"
            )
            if envelope["ok"] is False:
                require(
                    same(
                        decoded,
                        local_failure(
                            envelope["failure_code"], envelope.get("detail", "")
                        ),
                    ),
                    "ABI_REFUSAL_DECODED",
                )
                native_kind, refusal_exact = "abi_refusal", True
            else:
                value = envelope["value"]
                require(type(decoded) is dict, "DECODED_VALUE_OBJECT")
                compare_legacy_value(value, decoded, differences)
                require(
                    value.get("schema_version")
                    == "sporespore_recovery_native_collection_receipt_v2",
                    "NATIVE_VALUE_SCHEMA",
                )
                for key in (
                    "native_runtime_observation_collection_executed",
                    "engine_identity_exposed_to_controller",
                    "physics_state_modified",
                    "physical_acceptance_authority",
                    "release_authority",
                ):
                    require(value.get(key) is False, "NATIVE_FALSE:" + key)
                for key in (
                    "model_construction_count",
                    "world_attempt_count",
                    "world_build_count",
                    "solver_step_count",
                ):
                    require(
                        type(value.get(key)) is int and value[key] == 0,
                        "NATIVE_ZERO:" + key,
                    )
                    require(
                        type(decoded.get(key)) in (int, float) and decoded[key] == 0,
                        "DECODED_ZERO:" + key,
                    )
                require(
                    type(value.get("support_status")) is str
                    and "refusal_reason" in value,
                    "NATIVE_SUPPORT_SHAPE",
                )
                native_supported = (
                    value["support_status"] == "supported_exact"
                    and value["refusal_reason"] is None
                )
                if native_supported:
                    require(
                        value.get("supplied_native_post_step_observation_validated")
                        is True,
                        "NATIVE_SUPPORTED_VALIDATION_FLAG",
                    )
                    require(
                        same(value.get("observation"), request["observation"]),
                        "NATIVE_OBSERVATION_REQUEST_IDENTITY",
                    )
                    require(
                        same(
                            value.get("observation_source_binding"),
                            request["observation_source_binding"],
                        ),
                        "NATIVE_SOURCE_BINDING_REQUEST_IDENTITY",
                    )
                    require(
                        canonical_sha256(value["observation"])
                        == value.get("observation_sha256")
                        == request["observation_source_binding"].get(
                            "portable_observation_sha256"
                        ),
                        "NATIVE_OBSERVATION_SOURCE_DIGEST",
                    )
                    require(
                        canonical_sha256(value["observation_source_binding"])
                        == value.get("observation_source_binding_sha256"),
                        "NATIVE_SOURCE_BINDING_DIGEST",
                    )
                require(
                    canonical_sha256(request["adapter_capability"])
                    == value.get("capability_sha256"),
                    "NATIVE_CAPABILITY_DIGEST",
                )
                native_kind = (
                    "reported_supported_exact" if native_supported else "value_refusal"
                )
                refusal_exact = not native_supported and not differences
    for key in ("compiled_collection_call_count", "response_json_parse_call_count"):
        require(type(packet[key]) is int and packet[key] == expected_calls, key.upper())
    return {
        "schema_version": "sporespore_qsdk_r10f_l15_collection_retention_audit_v1",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "independent_exact_transport_retention_audit",
            "question_class": "development",
        },
        "retained_transport_integrity_valid": True,
        "source_role_count": len(sources),
        "request_projection_checked": request is not None,
        "expected_request_identity_checked": request is not None,
        "native_response_kind": native_kind,
        "native_collection_reported_supported_exact": native_supported,
        "native_observation_request_and_source_digests_verified": native_supported,
        "decoded_refusal_whole_value_exact": refusal_exact,
        "legacy_numeric_differences": differences,
        "legacy_decoded_numbers_used_for_inference": False,
        "raw_and_decoded_numeric_identity_claimed": False,
        "additional_collection_call_count": 0,
        "additional_controller_advance_count": 0,
        "additional_native_physics_read_count": 0,
        "additional_solver_step_count": 0,
        "valid_physical_route_established": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


REPORT_IDENTITY_KEYS = {
    "schema_version",
    "gate_id",
    "repair_id",
    "work_id",
    "ledger_scope",
    "source_commit",
    "authorization_sha256",
    "parent_attempt_id",
    "child_attempt_id",
    "attempt_id",
    "arm_id",
    "process_id",
    "seed",
    "seed_sha256",
    "actuator_mode",
    "recovery_controller_id",
    "energy_route_id",
}
PARTIAL_PACKET = "last_recovery_collection_transport_retention"
PARTIAL_STEP = "last_recovery_collection_transport_global_semantic_step"
PARTIAL_FAILURE = "last_recovery_advance_failure"


def validate_partial_report(
    report,
    *,
    expected_report_identity,
    expected_identity,
    canonical_sha256,
    maximum_solver_steps,
):
    """Audit failure retention without qualifying the failed child.

    Both expected identities are supplied by the enclosing reader. The source
    qualification handoff must bind the request identity independently; reading
    it from this report is not an authority. A prior successful capture may be
    retained after an unrelated later failure, but is never called a capture of
    that later step. A failed advance must match all three retained copies.
    """
    exact_keys(
        expected_report_identity, REPORT_IDENTITY_KEYS, "EXPECTED_REPORT_IDENTITY"
    )
    exact_keys(expected_identity, IDENTITY_KEYS, "EXPECTED_IDENTITY")
    require(type(report) is dict, "PARTIAL_REPORT_OBJECT")
    for key, value in expected_report_identity.items():
        require(
            key in report and same(report[key], value), "PARTIAL_REPORT_IDENTITY:" + key
        )
    require(
        report.get("status")
        == "invalid_or_incomplete_process_isolated_child_development"
        and report.get("scientific_outcome") == "none"
        and report.get("role_outcome") == "none"
        and type(report.get("failure_code")) is str
        and bool(report["failure_code"]),
        "PARTIAL_REPORT_INVALID_STATUS",
    )
    for key in (
        "ok",
        "measurement_complete",
        "world_or_body_state_imported_from_peer",
        "event_triggered_passive_recovery_observed",
        "recovery_success_observed",
        "prone_to_standing_claimed",
        "kick_impulse_alone_causes_fall_claimed",
        "force_aware_recovery",
        "force_aware_bracing",
        "arbitrary_fall_recovery_claimed",
        "cross_engine_push_recovery_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        require(report.get(key) is False, "PARTIAL_FALSE:" + key)
    for key in ("one_arm_per_process", "one_world_per_process"):
        require(report.get(key) is True, "PARTIAL_TRUE:" + key)
    require(
        type(maximum_solver_steps) is int and maximum_solver_steps > 0, "MAXIMUM_STEPS"
    )
    for key, maximum in (
        ("model_construction_attempt_count", 1),
        ("model_construction_count", 1),
        ("world_attempt_count", 1),
        ("world_build_count", 1),
        ("external_kick_application_count", 1),
        ("solver_step_count", maximum_solver_steps),
        ("global_solver_frame_count", maximum_solver_steps),
        ("explicit_worker_extra_native_readback_count", 10**12),
        ("behavior_evaluator_invocation_count", 0),
    ):
        require(
            type(report.get(key)) is int and 0 <= report[key] <= maximum,
            "PARTIAL_COUNT:" + key,
        )
    require(
        type(report.get("maximum_solver_step_count")) is int
        and report["maximum_solver_step_count"] == maximum_solver_steps,
        "PARTIAL_MAXIMUM_STEPS",
    )
    require(
        report.get("physical_question_opened") is (report["world_attempt_count"] > 0)
        and report.get("physics_state_modified") is (report["solver_step_count"] > 0),
        "PARTIAL_PHYSICAL_COUNTER_FLAGS",
    )
    partial = report.get("partial_arm")
    require(type(partial) is dict, "PARTIAL_ARM_OBJECT")
    require(
        partial.get("arm_id") == expected_report_identity["arm_id"], "PARTIAL_ARM_ID"
    )
    detail = report.get("detail")
    require(type(detail) is dict, "PARTIAL_DETAIL_OBJECT")
    advance_failure = (
        detail.get("failure_code") == "QSDK_R10F_RECOVERY_PRODUCTION_ADVANCE_INVALID"
    )
    packet = partial.get(PARTIAL_PACKET)
    present = type(packet) is dict and bool(packet)
    result = {
        "schema_version": "sporespore_qsdk_r10f_l15_partial_collection_retention_audit_v1",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "independent_partial_collection_failure_retention",
            "question_class": "development",
        },
        "partial_arm_retained": True,
        "collection_packet_present": present,
        "collection_failure_present": advance_failure,
        "collection_failure_retention_valid": False,
        "retention_establishes_valid_child": False,
        "valid_physical_route_established": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    if not present:
        require(
            not advance_failure and not partial.get(PARTIAL_FAILURE),
            "FAILED_ADVANCE_PACKET_MISSING",
        )
        return result
    step = partial.get(PARTIAL_STEP)
    require(
        type(step) is int
        and 1 <= step <= report["solver_step_count"]
        and step <= report["global_solver_frame_count"],
        "PARTIAL_CAPTURE_STEP",
    )
    packet_audit = validate_packet(
        packet,
        expected_identity=expected_identity,
        canonical_sha256=canonical_sha256,
        expected_global_step=step,
    )
    failure = partial.get(PARTIAL_FAILURE)
    require(type(failure) is dict, "PARTIAL_ADVANCE_FAILURE_OBJECT")
    if advance_failure or bool(failure):
        require(
            advance_failure
            and report["failure_code"] == "QSDK_R10F_L9_CHILD_STEP_PROCESSING_INVALID"
            and detail.get("ok") is False
            and failure.get("ok") is False
            and type(failure.get("failure_code")) is str
            and bool(failure["failure_code"])
            and same(detail.get("advance"), failure)
            and same(failure.get("collection_transport_retention"), packet),
            "PARTIAL_FAILED_ADVANCE_COPIES",
        )
        require(
            step == report["solver_step_count"] == report["global_solver_frame_count"],
            "PARTIAL_FAILED_ADVANCE_CURRENT_STEP",
        )
        memory = parse_json(
            verify_bytes(packet["source_links"]["source_memory"]).decode("utf-8")
        )
        require(
            same(partial.get("recovery_memory"), memory),
            "PARTIAL_FAILED_ADVANCE_MEMORY_SOURCE",
        )
    trace = partial.get("trace_rows")
    require(type(trace) is list, "PARTIAL_TRACE_ROWS")
    finite_json(trace)
    result.update(
        collection_failure_retention_valid=advance_failure,
        retained_transport_integrity_valid=True,
        captured_global_semantic_step=step,
        completed_solver_step_count=report["solver_step_count"],
        capture_is_current_completed_step=step == report["solver_step_count"],
        retained_packet_canonical_sha256=canonical_sha256(packet),
        partial_trace_row_count=len(trace),
        partial_trace_canonical_sha256=canonical_sha256(trace),
        packet_audit=packet_audit,
    )
    return result
