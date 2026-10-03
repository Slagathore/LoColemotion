"""Read-only bridge from the PowerShell pair consumer to the L14 source proof.

This validates the complete offered child report, not a caller-supplied success
flag. It writes no evidence, opens no engine, and grants no execution authority.
The unchanged serialized process/health/peer checks remain in the supervisor.
"""

from __future__ import annotations

import hashlib
import json
import sys

import qsdk_r10f_l14_authority_contract as authority
import qsdk_r10f_physical_closure as closer

REQUEST_SCHEMA = "sporespore_qsdk_r10f_l14_no_resume_child_source_request_v1"
RECEIPT_SCHEMA = "sporespore_qsdk_r10f_l14_no_resume_child_source_receipt_v1"
MARKER = "QSDK_R10F_L14_NO_RESUME_CHILD_SOURCE "
IDENTITY_KEYS = {
    "expected_role",
    "expected_parent_attempt_id",
    "expected_child_attempt_id",
    "expected_source_commit",
    "expected_authority_sha256",
    "expected_worker_process_id",
}


def validate_request(request: dict) -> dict:
    closer.require(
        type(request) is dict
        and set(request) == {"schema_version", "report", "expected_identity"}
        and request["schema_version"] == REQUEST_SCHEMA
        and type(request["expected_identity"]) is dict
        and set(request["expected_identity"]) == IDENTITY_KEYS,
        "L14_CHILD_BRIDGE_REQUEST_SCHEMA",
    )
    identity = request["expected_identity"]
    closer.require(
        identity["expected_role"] == "kick_passive_recovery_resume"
        and type(identity["expected_worker_process_id"]) is int,
        "L14_CHILD_BRIDGE_ACTIVE_IDENTITY",
    )
    projection = closer.validate_l9_child_report(request["report"], **identity)
    proof = projection["no_resume_terminal"]
    closer.require(
        type(proof) is dict
        and proof.get("source_proven_no_resume_negative") is True
        and proof.get("recovery_success_observed") is False,
        "L14_CHILD_BRIDGE_NO_RESUME_PROOF_REQUIRED",
    )
    return {
        "expected_identity": dict(identity),
        "no_resume_terminal": proof,
        "whole_child_source_validation_passed": True,
        "process_health_and_peer_validation_still_required": True,
    }


def main() -> int:
    raw = sys.stdin.buffer.read()
    result = {}
    failure = ""
    try:
        authority.verify_repository()
        request = json.loads(raw)
        result = validate_request(request)
    except (
        ValueError,
        TypeError,
        KeyError,
        AttributeError,
        closer.ClosureFailure,
    ) as exc:
        failure = type(exc).__name__ + ":" + str(exc)
    receipt = {
        "schema_version": RECEIPT_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L14",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "read_only_full_child_source_validation",
            "question_class": "development",
        },
        "ok": failure == "",
        "failure_code": failure,
        "offered_request_raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
        **result,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    print(MARKER + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 1 if failure else 0


if __name__ == "__main__":
    raise SystemExit(main())
