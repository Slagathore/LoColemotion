"""Independent, read-only consumer for the opt-in L15 host process receipt.

The expected context must come from the enclosing qualified authority/child,
never from the receipt itself. This verifies retained provenance consistency,
not cryptographic attestation, current OS ancestry or behavioral acceptance.
"""

from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import ntpath
import re

from recovery_interface_contract import PROCESS


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError("QSDK_R10F_L15_LAUNCH_" + code)


def same(left: object, right: object) -> bool:
    return json.dumps(left, sort_keys=True, allow_nan=False) == json.dumps(
        right, sort_keys=True, allow_nan=False
    )


def integer(value: object, minimum: int = 1, maximum: int = 2**31 - 1) -> bool:
    return type(value) is int and minimum <= value <= maximum


def keys(value: object, expected: set[str], label: str) -> None:
    require(type(value) is dict and value.keys() == expected, label + "_KEYS")


def exact_json(raw: str) -> dict:
    def pairs(items: list[tuple[str, object]]) -> dict:
        result = {}
        for key, item in items:
            require(key not in result, "JSON_DUPLICATE_KEY")
            result[key] = item
        return result

    def invalid_constant(value: str) -> None:
        raise ValueError("QSDK_R10F_L15_LAUNCH_NONFINITE_JSON:" + value)

    value = json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid_constant)
    require(type(value) is dict, "JSON_OBJECT")
    return value


def utc_ticks(value: object) -> int:
    """Keep all seven .NET fractional digits, without microsecond rounding."""
    require(type(value) is str, "UTC_TYPE")
    match = re.fullmatch(
        r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\.(\d{7})(?:Z|\+00:00)", value
    )
    require(match is not None, "UTC_FORMAT")
    whole = datetime.strptime(match[1], "%Y-%m-%dT%H:%M:%S").replace(
        tzinfo=timezone.utc
    )
    epoch = whole - datetime(1970, 1, 1, tzinfo=timezone.utc)
    return (epoch.days * 86400 + epoch.seconds) * 10_000_000 + int(match[2])


def image_path(value: object) -> str:
    require(type(value) is str and ntpath.isabs(value), "IMAGE_PATH")
    drive, tail = ntpath.splitdrive(value)
    require(bool(drive) and tail.startswith(("/", "\\")), "FULL_IMAGE_PATH")
    return ntpath.normcase(ntpath.normpath(value))


def validate_context(context: dict) -> None:
    keys(
        context,
        {
            "schema_version",
            "parent_attempt_id",
            "child_attempt_id",
            "role",
            "source_commit",
            "authority_sha256",
            "termination_nonce",
            "ready_marker_prefix",
            "root_image",
            "worker_image",
        },
        "CONTEXT",
    )
    require(
        context["schema_version"] == PROCESS["context_schema"],
        "CONTEXT_SCHEMA",
    )
    for key in ("parent_attempt_id", "child_attempt_id", "termination_nonce"):
        require(
            type(context[key]) is str
            and re.fullmatch(r"[0-9a-f]{32}", context[key]) is not None,
            "CONTEXT_" + key,
        )
    require(
        context["parent_attempt_id"] != context["child_attempt_id"], "DISTINCT_CHILD"
    )
    require(
        context["role"]
        in PROCESS["roles"],
        "ROLE",
    )
    for key, pattern in (
        ("source_commit", r"[0-9a-f]{40}"),
        ("authority_sha256", r"sha256:[0-9a-f]{64}"),
    ):
        require(
            type(context[key]) is str
            and re.fullmatch(pattern, context[key]) is not None,
            key.upper(),
        )
    require(
        type(context["ready_marker_prefix"]) is str
        and bool(context["ready_marker_prefix"]),
        "MARKER",
    )
    for key in ("root_image", "worker_image"):
        image = context[key]
        keys(image, {"path", "byte_length", "raw_sha256"}, "IMAGE")
        image_path(image["path"])
        require(integer(image["byte_length"], maximum=2**63 - 1), "IMAGE_BYTES")
        require(
            type(image["raw_sha256"]) is str
            and re.fullmatch(r"sha256:[0-9a-f]{64}", image["raw_sha256"]) is not None,
            "IMAGE_SHA",
        )


def validate_receipt(
    receipt: dict,
    *,
    expected_context: dict,
    root_process_id: int,
    worker_process_id: int,
    started_utc: str,
    expected_ready_receipt: dict,
) -> dict:
    validate_context(expected_context)
    keys(
        receipt,
        {
            "schema_version",
            "ledger_scope",
            "ok",
            "payload_json",
            "payload_byte_length",
            "payload_raw_sha256",
            "physical_acceptance_authority",
            "release_authority",
        },
        "RECEIPT",
    )
    require(
        receipt["schema_version"]
        == PROCESS["receipt_schema"],
        "RECEIPT_SCHEMA",
    )
    require(
        same(
            receipt["ledger_scope"],
            {
                "subsystem": "recovery",
                "engine_scope": "godot_jolt",
                "authority_mode": "development_host_process_relationship",
                "question_class": "development",
            },
        ),
        "RECEIPT_LEDGER_SCOPE",
    )
    require(
        receipt["ok"] is True
        and receipt["physical_acceptance_authority"] is False
        and receipt["release_authority"] is False,
        "RECEIPT_FLAGS",
    )
    require(type(receipt["payload_json"]) is str, "PAYLOAD_TEXT")
    raw = receipt["payload_json"].encode("utf-8", errors="strict")
    require(
        integer(receipt["payload_byte_length"], maximum=2**63 - 1)
        and len(raw) == receipt["payload_byte_length"]
        and receipt["payload_raw_sha256"]
        == "sha256:" + hashlib.sha256(raw).hexdigest(),
        "PAYLOAD_CONTENT_ADDRESS",
    )
    payload = exact_json(receipt["payload_json"])
    keys(
        payload,
        {
            "context",
            "root_process_id",
            "worker_process_id",
            "started_utc",
            "observed_utc",
            "relationship",
            "process_chain",
            "ready_line",
            "ready_receipt",
        },
        "PAYLOAD",
    )
    require(same(payload["context"], expected_context), "CONTEXT_BINDING")
    require(
        all(
            integer(value)
            for value in (
                root_process_id,
                worker_process_id,
                payload["root_process_id"],
                payload["worker_process_id"],
            )
        ),
        "PID_TYPE_OR_RANGE",
    )
    require(
        payload["root_process_id"] == root_process_id
        and payload["worker_process_id"] == worker_process_id,
        "ENCLOSING_PIDS",
    )
    require(payload["started_utc"] == started_utc, "START_BINDING")
    started = utc_ticks(started_utc)
    observed = utc_ticks(payload["observed_utc"])
    require(observed >= started, "OBSERVATION_TIME")
    prefix = expected_context["ready_marker_prefix"]
    require(
        type(payload["ready_line"]) is str and payload["ready_line"].startswith(prefix),
        "READY_LINE",
    )
    ready = exact_json(payload["ready_line"][len(prefix) :])
    require(
        same(ready, payload["ready_receipt"]) and same(ready, expected_ready_receipt),
        "READY_RECEIPT_BINDING",
    )
    require(
        ready.get("schema_version")
        == PROCESS["ready_schema"]
        and ready.get("termination_protocol_id")
        == PROCESS["termination_protocol_id"]
        and ready.get("termination_nonce") == expected_context["termination_nonce"]
        and integer(ready.get("process_id"))
        and ready["process_id"] == worker_process_id
        and ready.get("worker_receipt_emitted") is True
        and integer(ready.get("requested_exit_code"), 0, 1),
        "READY_CONTRACT",
    )
    chain = payload["process_chain"]
    require(type(chain) is list and 1 <= len(chain) <= PROCESS["maximum_chain_nodes"], "CHAIN_LENGTH")
    seen = set()
    creation_times = []
    for index, node in enumerate(chain):
        keys(
            node,
            {"process_id", "parent_process_id", "created_utc", "executable_path"},
            "NODE",
        )
        require(
            integer(node["process_id"]) and integer(node["parent_process_id"], 0),
            "NODE_PIDS",
        )
        require(node["process_id"] not in seen, "CYCLIC_CHAIN")
        seen.add(node["process_id"])
        image_path(node["executable_path"])
        created = utc_ticks(node["created_utc"])
        require(started <= created <= observed, "NODE_LIFETIME")
        creation_times.append(created)
        if index:
            require(
                chain[index - 1]["parent_process_id"] == node["process_id"],
                "CHAIN_EDGE",
            )
            require(creation_times[index - 1] >= created, "PARENT_NEWER_THAN_CHILD")
    require(
        chain[0]["process_id"] == worker_process_id
        and chain[-1]["process_id"] == root_process_id,
        "CHAIN_ENDPOINTS",
    )
    relationship = PROCESS["self_relationship"] if root_process_id == worker_process_id else PROCESS["descendant_relationship"]
    require(
        payload["relationship"] == relationship
        and (len(chain) == 1) == (relationship == PROCESS["self_relationship"]),
        "RELATIONSHIP",
    )
    require(
        image_path(chain[-1]["executable_path"])
        == image_path(expected_context["root_image"]["path"])
        and image_path(chain[0]["executable_path"])
        == image_path(expected_context["worker_image"]["path"]),
        "ENDPOINT_IMAGES",
    )
    return payload


def production_context(
    *,
    parent_attempt_id: str,
    descriptor: dict,
    source_commit: str,
    authority_sha256: str,
    runtime_binding: dict,
) -> dict:
    # Runtime selection is external authority; never trust the child to select
    # its own executable, source commit, nonce or parent identity.
    import qsdk_r10f_l14_runtime_binding as runtime

    runtime.validate_binding(runtime_binding)
    value = {
        "schema_version": PROCESS["context_schema"],
        "parent_attempt_id": parent_attempt_id,
        "child_attempt_id": descriptor["child_attempt_id"],
        "role": descriptor["role"],
        "source_commit": source_commit,
        "authority_sha256": authority_sha256,
        "termination_nonce": descriptor["termination_nonce"],
        "ready_marker_prefix": PROCESS["ready_marker_prefix"],
        "root_image": runtime_binding["images"]["godot_console"],
        "worker_image": runtime_binding["images"]["godot_engine"],
    }
    validate_context(value)
    return value


def validate_child_launch(envelope: dict, expected_context: dict) -> dict:
    for field in ("role", "child_attempt_id", "termination_nonce"):
        require(
            same(envelope.get(field), expected_context[field]),
            "ENCLOSING_CHILD_" + field,
        )
    require(
        "r10f_l15_launch_relationship" in envelope
        and "termination_ready_receipt" in envelope,
        "ENVELOPE_MISSING_PROOF",
    )
    payload = validate_receipt(
        envelope["r10f_l15_launch_relationship"],
        expected_context=expected_context,
        root_process_id=envelope["process_id"],
        worker_process_id=envelope["worker_process_id"],
        started_utc=envelope["started_utc"],
        expected_ready_receipt=envelope["termination_ready_receipt"],
    )
    require(
        utc_ticks(payload["observed_utc"]) <= utc_ticks(envelope["completed_utc"]),
        "OBSERVATION_AFTER_EXIT",
    )
    require(
        integer(envelope["exit_code"], 0, 1)
        and envelope["exit_code"]
        == envelope["termination_ready_receipt"]["requested_exit_code"],
        "READY_EXIT_BINDING",
    )
    return payload
