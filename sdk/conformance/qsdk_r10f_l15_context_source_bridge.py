"""Strict source-only context reader for the actual PowerShell child validator.

Expected identities are explicit caller inputs, not derived from the comparison.
Official qualification origin, worker health and behavioral validity are separate.
"""

from __future__ import annotations

import hashlib
import json
import sys

import qsdk_r10f_l14_authority_contract as authority
import qsdk_r10f_l15_collection_context as context
import qsdk_r10f_physical_closure as closer

REQUEST_SCHEMA = "sporespore_qsdk_r10f_l15_worker_context_source_request_v1"
RECEIPT_SCHEMA = "sporespore_qsdk_r10f_l15_worker_context_source_receipt_v1"
MARKER = "QSDK_R10F_L15_WORKER_CONTEXT_SOURCE "


def validate_request(value):
    context.packet.exact_keys(
        value,
        {
            "schema_version",
            "comparison",
            "expected_capture_binding",
            "expected_collection_identity",
        },
        "WORKER_CONTEXT_BRIDGE_REQUEST",
    )
    context.require(value["schema_version"] == REQUEST_SCHEMA, "BRIDGE_REQUEST_SCHEMA")
    return context.validate_worker_comparison(
        value["comparison"],
        expected_raw_binding=value["expected_capture_binding"],
        expected_identity=value["expected_collection_identity"],
        canonical_sha256=closer.canonical_sha256_v1,
    )


def main():
    raw = sys.stdin.buffer.read()
    failure = ""
    proof = None
    try:
        authority.verify_repository()
        context.require(len(sys.argv) == 1, "BRIDGE_NO_OPTIONS")
        proof = validate_request(
            context.packet.parse_json(raw.decode("utf-8", errors="strict"))
        )
    except (ValueError, TypeError, KeyError, closer.ClosureFailure) as exc:
        failure = type(exc).__name__ + ":" + str(exc)
    receipt = {
        "schema_version": RECEIPT_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L15",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "read_only_worker_context_source_bridge",
            "question_class": "development",
        },
        "ok": failure == "",
        "failure_code": failure,
        "offered_request_raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
        "proof": proof,
        **dict.fromkeys(context.ZERO_COUNTERS, 0),
        "expected_context_origin_authenticated_here": False,
        "official_context_qualification": False,
        "physics_state_modified": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    print(MARKER + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 1 if failure else 0


if __name__ == "__main__":
    raise SystemExit(main())
