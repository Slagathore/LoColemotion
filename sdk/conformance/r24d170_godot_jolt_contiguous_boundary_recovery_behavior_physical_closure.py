#!/usr/bin/env python3
"""Audit the consumed R170 result and its missing initializer receipts.

The R170 supervisor retained a complete positive terminal observation, but the
qualified publication audit requires each arm's nine-body native initializer
receipt.  The worker serialized empty dictionaries instead.  This audit keeps
the observed result immutable while proving why it is not a valid complete
behavior result for the project ledger.
"""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    matching_evidence_roots,
    require,
    source_bytes,
    verify_content_addressed_json,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
    verify_retained_commit,
    verify_retained_file_tree,
    verify_retained_json,
)
from sdk.conformance.finite_godot_recovery_behavior_physical_closure import (  # noqa: E402
    _contiguous_boundary_transport_projection,
    _solver_coupled_constraint_motor_projection,
    _trajectory_projection,
)


CLOSURE_PATH = (
    "sdk/recovery/"
    "r24d170_godot_jolt_contiguous_boundary_recovery_behavior_"
    "physical_closure_v1.json"
)
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d170_godot_jolt_contiguous_boundary_recovery_"
    "behavior_physical_closure_v1"
)
CONTRACT_PATH = (
    "sdk/recovery/"
    "r24d170_godot_jolt_contiguous_boundary_recovery_behavior_contract_v1.json"
)
EXPECTED_CLOSURE_SHA256 = (
    "sha256:cf1f476f88f9a82ca934306c25b6d0684d693971dbaa9f1192de2d7d6539d3b7"
)
EXPECTED_CLOSURE_BYTE_LENGTH = 29816

TRANSPORT_DESIGN_ID = (
    "godot_jolt_r24d167_contiguous_completed_step_boundary_transport_v1"
)
TRANSPORT_PROFILE_ID = (
    "godot_jolt_r24d168_live_contiguous_completed_step_boundary_transport_v1"
)
TRANSPORT_STATE_SCHEMA = "sporespore_qsdk_r24d167_boundary_transport_state_v1"
TRANSPORT_PAIR_SCHEMA = (
    "sporespore_qsdk_r24d167_contiguous_body_boundary_pair_v1"
)
INITIALIZER_SCHEMA = (
    "sporespore_qsdk_r24d168_native_initializer_boundary_transport_v1"
)
INITIALIZER_AUDIT_FAILURE = (
    "BOUNDARY_TRANSPORT_INITIALIZER_PATH:schema_version"
)


def _validate_source(root: Path, closure: dict[str, Any]) -> None:
    source = closure["source"]
    commit = str(source["commit"])
    freeze = str(source["qualification_source_commit"])
    verify_retained_commit(root, commit, str(source["parent_commit"]))
    exact(git(root, "show", "-s", "--format=%T", commit), source["tree"], "TREE")
    exact(
        git(root, "show", "-s", "--format=%s", commit),
        source["subject"],
        "SUBJECT",
    )
    verify_exact_paths(
        source,
        {
            "branch": "main",
            "remote": "https://github.com/Slagathore/sporespore.git",
            "upstream_equal_at_physical_start": True,
            "live_remote_equal_at_physical_start": True,
            "worktree_clean_at_physical_start": True,
            "qualified_physical_source_drift_count_at_physical_start": 0,
        },
        "SOURCE",
    )
    require(
        subprocess.run(
            ["git", "merge-base", "--is-ancestor", freeze, commit],
            cwd=root,
            check=False,
        ).returncode
        == 0,
        "QUALIFICATION_NOT_ANCESTOR",
    )
    authority = closure["qualification_authority"]
    authority_raw = source_bytes(root, commit, str(authority["path"]))
    exact(
        (len(authority_raw), "sha256:" + hashlib.sha256(authority_raw).hexdigest()),
        (
            authority["byte_length_at_physical_start"],
            authority["raw_sha256_at_physical_start"],
        ),
        "QUALIFICATION_AUTHORITY",
    )
    qualification = json.loads(authority_raw)
    verify_exact_paths(
        qualification,
        {
            "gate_id": "QSDK-R24D170",
            "decision.physical_execution_authorized": True,
            "claim_boundary.complete_zero_world_gate_passed": True,
        },
        "QUALIFICATION_AUTHORITY_CONTENT",
    )
    contract = json.loads(source_bytes(root, freeze, CONTRACT_PATH))
    exact(contract["gate_id"], "QSDK-R24D170", "CONTRACT_GATE")
    qualified_paths = tuple(str(path) for path in contract["qualified_physical_paths"])
    exact(len(qualified_paths), source["qualified_physical_path_count"], "PATH_COUNT")
    require(
        subprocess.run(
            ["git", "diff", "--quiet", freeze, commit, "--", *qualified_paths],
            cwd=root,
            check=False,
        ).returncode
        == 0,
        "QUALIFIED_PHYSICAL_SOURCE_DRIFT",
    )


def _validate_attempt(
    closure: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    physical = closure["physical_attempt"]
    evidence = Path(str(physical["evidence_root"]))
    exact(
        matching_evidence_roots(
            evidence.parent,
            "",
            "attempt.json",
            "QSDK-R24D170",
            str(closure["source"]["commit"]),
        ),
        [evidence],
        "ATTEMPT_POPULATION",
    )
    verify_retained_file_tree(evidence, physical["retained_tree"])
    artifacts = physical["artifacts"]
    exact(
        set(artifacts),
        {"attempt", "raw", "terminal", "stdout", "stderr"},
        "ARTIFACT_KEYS",
    )
    values: dict[str, dict[str, Any]] = {}
    for key in ("attempt", "raw", "terminal"):
        artifact = artifacts[key]
        values[key] = verify_retained_json(
            evidence / str(artifact["path"]),
            int(artifact["byte_length"]),
            str(artifact["raw_sha256"]),
            int(artifact["canonical_byte_length"]),
            str(artifact["canonical_sha256"]),
        )
        exact(
            values[key]["schema_version"],
            physical["schemas"][key],
            f"{key.upper()}_SCHEMA",
        )
    for key in ("stdout", "stderr"):
        artifact = artifacts[key]
        raw_bytes = (evidence / str(artifact["path"])).read_bytes()
        exact(
            (len(raw_bytes), "sha256:" + hashlib.sha256(raw_bytes).hexdigest()),
            (artifact["byte_length"], artifact["raw_sha256"]),
            key.upper(),
        )

    attempt, raw, terminal = values["attempt"], values["raw"], values["terminal"]
    common = {
        "gate_id": "QSDK-R24D170",
        "question_class": "development",
        "status": "valid_complete_behavior_development",
        "attempt_id": physical["attempt_id"],
        "source_commit": closure["source"]["commit"],
        "seed": physical["seed"],
        "seed_sha256": physical["seed_sha256"],
        "held_out": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    verify_exact_paths(attempt, common, "ATTEMPT")
    verify_exact_paths(
        attempt,
        {
            "authorization_sha256": physical["authorization_sha256"],
            "authorization_control_sha256": None,
            "physical_question_kind": "behavior_development",
            "maximum_model_construction_attempt_count": 2,
            "maximum_model_construction_count": 2,
            "maximum_world_attempt_count": 2,
            "maximum_world_build_count": 2,
            "maximum_solver_step_count": 2400,
            "operation_lock.acquired": True,
            "operation_lock.role": "physical_development",
            "operation_lock.test_only": False,
        },
        "ATTEMPT_AUTHORITY",
    )
    verify_exact_paths(
        terminal,
        {
            "gate_id": "QSDK-R24D170",
            "question_class": "development",
            "status": "valid_complete_behavior_development",
            "physical_question_kind": "behavior_development",
            "integration_ghost_passed": False,
            "behavior_development_completed": True,
            "attempt_id": physical["attempt_id"],
            "source.head": closure["source"]["commit"],
            "source.upstream": closure["source"]["commit"],
            "source.cached_origin_main": closure["source"]["commit"],
            "source.live_origin_main": closure["source"]["commit"],
            "source.worktree_clean": True,
            "authorization.raw_sha256": physical["authorization_sha256"],
            "authorization.control": None,
            "worker.semantic_exit_code": 0,
            "worker.host_exit_code": -1,
            "worker.timed_out": False,
            "worker.termination_protocol_valid": True,
            "worker.raw_marker_count": 1,
            "worker.raw_binding_valid": True,
            "worker.progress_marker_count": 24,
            "worker.progress_binding_valid": True,
            "worker.engine_health.passed": True,
            "worker.engine_health.stderr_raw_byte_length": 0,
            "recovery_success_observed": True,
            "prone_to_standing_claimed": True,
            "same_identity_rerun_permitted": False,
            "held_out": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "TERMINAL",
    )
    verify_exact_paths(raw, common, "RAW")
    verify_exact_paths(raw, closure["observed_behavior"]["raw_exact"], "RAW_EXACT")
    exact(
        terminal["raw_result"]["raw_sha256"],
        artifacts["raw"]["raw_sha256"],
        "TERMINAL_RAW_HASH",
    )
    exact(
        terminal["raw_result"]["byte_length"],
        artifacts["raw"]["byte_length"],
        "TERMINAL_RAW_LENGTH",
    )
    exact(
        verify_content_addressed_json(physical["raw_result_cas"], label="RAW_CAS"),
        raw,
        "RAW_CAS_CONTENT",
    )
    exact(
        verify_content_addressed_json(
            physical["terminal_cas"], label="TERMINAL_CAS"
        ),
        terminal,
        "TERMINAL_CAS_CONTENT",
    )
    return raw, terminal


def _count_schema(value: object, schema: str) -> int:
    count = 0
    if isinstance(value, dict):
        count += int(value.get("schema_version") == schema)
        for child in value.values():
            count += _count_schema(child, schema)
    elif isinstance(value, list):
        for child in value:
            count += _count_schema(child, schema)
    return count


def _incomplete_transport_projection(arm: dict[str, Any]) -> dict[str, Any]:
    initializer = arm["boundary_transport_initializer_receipt"]
    exact(initializer, {}, "MISSING_INITIALIZER_RECEIPT")
    official_failure = ""
    try:
        _contiguous_boundary_transport_projection(arm, int(arm["outer_step_count"]))
    except ClosureAuditError as error:
        official_failure = str(error)
    exact(official_failure, INITIALIZER_AUDIT_FAILURE, "OFFICIAL_TRANSPORT_REFUSAL")

    step_count = int(arm["outer_step_count"])
    terminal = arm["boundary_transport_terminal_state"]
    verify_exact_paths(
        terminal,
        {
            "schema_version": TRANSPORT_STATE_SCHEMA,
            "transport_design_id": TRANSPORT_DESIGN_ID,
            "arm_id": arm["arm_kind"],
            "cached_boundary_sequence": step_count,
            "accepted_pair_count": step_count,
            "state_revision": step_count,
            "cached_completed_boundary.boundary_sequence": step_count,
            "cached_completed_boundary.source_kind": (
                "completed_step_direct_state_callback_v1"
            ),
            "cached_completed_boundary.physics_active": True,
            "cached_completed_boundary.source_measurement": True,
            "cached_completed_boundary.mechanical_energy_change_used_as_input": False,
            "cached_completed_boundary.energy_balance_residual_used_as_input": False,
            "cached_completed_boundary.acceptance_threshold_used_as_input": False,
            "cached_completed_boundary.controller_or_behavior_result_used_as_input": False,
        },
        "TRANSPORT_TERMINAL",
    )
    receipts = arm["in_run_invariant_receipts"]
    require(isinstance(receipts, list) and len(receipts) == step_count, "TRANSPORT_STEPS")
    for semantic_step, receipt in enumerate(receipts, start=1):
        verify_exact_paths(
            receipt,
            {
                "semantic_step": semantic_step,
                "contiguous_boundary_transport_profile_selected": True,
                "boundary_transport_capture_schema_version": (
                    "sporespore_qsdk_r24d168_godot_jolt_"
                    "contiguous_body_boundary_capture_v1"
                ),
                "boundary_transport_design_id": TRANSPORT_DESIGN_ID,
                "boundary_transport_profile_id": TRANSPORT_PROFILE_ID,
                "boundary_transport_previous_sequence": semantic_step - 1,
                "boundary_transport_state_revision_before": semantic_step - 1,
                "boundary_transport_state_revision_after": semantic_step,
                "boundary_transport_pre_boundary_source_kind": (
                    "inactive_physics_initializer_readback_v1"
                    if semantic_step == 1
                    else "completed_step_direct_state_callback_v1"
                ),
                "boundary_transport_post_boundary_source_kind": (
                    "completed_step_direct_state_callback_v1"
                ),
                "boundary_transport_cache_advance_count_pending_commit": 1,
                "boundary_transport_cache_advance_committed": True,
                "boundary_transport_source_measurement": True,
                "boundary_transport_mechanical_energy_change_used_as_input": False,
                "boundary_transport_energy_balance_residual_used_as_input": False,
                "boundary_transport_acceptance_threshold_used_as_input": False,
                "boundary_transport_controller_or_behavior_result_used_as_input": False,
            },
            "TRANSPORT_STEP",
        )
        capture_sha256 = receipt.get("boundary_transport_capture_sha256")
        require(
            isinstance(capture_sha256, str)
            and len(capture_sha256) == 71
            and capture_sha256.startswith("sha256:")
            and all(char in "0123456789abcdef" for char in capture_sha256[7:]),
            "TRANSPORT_CAPTURE_SHA256",
        )
    return {
        "initializer_receipt": {},
        "initializer_required_audit_failure": official_failure,
        "per_step_invariant_receipt_count": len(receipts),
        "first_pre_boundary_source_kind": receipts[0][
            "boundary_transport_pre_boundary_source_kind"
        ],
        "last_post_boundary_source_kind": receipts[-1][
            "boundary_transport_post_boundary_source_kind"
        ],
        "terminal_cached_boundary_sequence": terminal["cached_boundary_sequence"],
        "terminal_accepted_pair_count": terminal["accepted_pair_count"],
        "terminal_state_revision": terminal["state_revision"],
    }


def _core_projection(arm: dict[str, Any]) -> dict[str, Any]:
    without_transport = copy.deepcopy(arm)
    del without_transport["boundary_transport_initializer_receipt"]
    del without_transport["boundary_transport_terminal_state"]
    projection = _trajectory_projection(without_transport)
    projection["solver_coupled_constraint_motor"] = (
        _solver_coupled_constraint_motor_projection(arm)
    )
    return projection


def _validate_closure(root: Path) -> dict[str, Any]:
    closure_path = root / CLOSURE_PATH
    closure_raw = closure_path.read_bytes()
    exact(
        (len(closure_raw), "sha256:" + hashlib.sha256(closure_raw).hexdigest()),
        (EXPECTED_CLOSURE_BYTE_LENGTH, EXPECTED_CLOSURE_SHA256),
        "CLOSURE_IDENTITY",
    )
    closure = json.loads(closure_raw)
    verify_exact_paths(
        closure,
        {
            "schema_version": CLOSURE_SCHEMA,
            "gate_id": "QSDK-R24D170",
            "question_class": "development",
            "physical_question_declared": True,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
        },
        "CLOSURE",
    )
    _validate_source(root, closure)
    raw, _terminal = _validate_attempt(closure)
    exact(
        raw["arm_execution_summary"]["ordered_arm_summaries"],
        closure["observed_behavior"]["arm_summaries"],
        "ARM_SUMMARIES",
    )
    core_projection = {
        "candidate": _core_projection(raw["candidate_arm"]),
        "matched_zero": _core_projection(raw["matched_zero_arm"]),
    }
    exact(
        core_projection,
        closure["observed_behavior"]["core_computed_projection"],
        "CORE_PROJECTION",
    )
    transport_projection = {
        "candidate": _incomplete_transport_projection(raw["candidate_arm"]),
        "matched_zero": _incomplete_transport_projection(raw["matched_zero_arm"]),
    }
    exact(
        transport_projection,
        closure["observed_failure"]["retained_transport_projection"],
        "INCOMPLETE_TRANSPORT_PROJECTION",
    )
    exact(_count_schema(raw, INITIALIZER_SCHEMA), 0, "INITIALIZER_SCHEMA_POPULATION")
    verify_exact_paths(
        raw["evaluation_acceptance_receipt"],
        closure["observed_behavior"]["evaluator_projection"],
        "EVALUATOR_OBSERVATION",
    )
    verify_exact_paths(
        closure,
        {
            "observed_failure.classification": (
                "required_per_arm_native_initializer_boundary_transport_receipt_"
                "not_retained"
            ),
            "observed_failure.required_initializer_receipt_count": 2,
            "observed_failure.retained_initializer_receipt_count": 0,
            "observed_failure.required_initializer_native_readback_count": 18,
            "observed_failure.retained_initializer_native_readback_count": -2,
            "interpretation.supervisor_complete_positive_observation_preserved": True,
            "interpretation.publication_contract_complete_behavior_result_established": False,
            "interpretation.post_hoc_initializer_receipt_reconstruction_permitted": False,
            "decision.behavior_attempt_consumed_for_exact_source": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.physical_execution_authorized": False,
            "decision.valid_complete_behavior_result": False,
            "decision.infrastructure_invalid_or_incomplete_result_retained": True,
            "decision.r171_distinct_successor_required": True,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "claim_boundary.physical_attempted": True,
            "claim_boundary.physical_attempt_consumed": True,
            "claim_boundary.positive_terminal_observation_preserved": True,
            "claim_boundary.valid_complete_behavior_result": False,
            "claim_boundary.scientific_behavior_positive_accepted": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.sdk1_milestone_advanced": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "next_boundary.gate_id": "QSDK-R24D171",
            "next_boundary.physical_question_declared": False,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_build_count": 0,
            "next_boundary.maximum_physical_steps_authorized": 0,
        },
        "DISPOSITION",
    )
    expected_live = dict(closure["live_authority_projection"])
    expected_live.update(
        {
            "r24d170_physical_closure_path": CLOSURE_PATH,
            "r24d170_physical_closure_raw_sha256": (
                "sha256:" + hashlib.sha256(closure_raw).hexdigest()
            ),
            "r24d170_physical_closure_byte_length": len(closure_raw),
        }
    )
    verify_legacy_live_authority_projection(
        root,
        tuple(str(path) for path in closure["live_authority_paths"]),
        record_key="r24d170_contract_path",
        expected=expected_live,
        prefix="LIVE_QSDK_R24D170_PHYSICAL",
    )
    require((root / str(closure["closure_audit_path"])).is_file(), "AUDIT_PATH")
    return closure


def main() -> int:
    try:
        closure = _validate_closure(ROOT)
        physical = closure["physical_attempt"]
        print(
            "QSDK_R24D170_CONTIGUOUS_BOUNDARY_RECOVERY_BEHAVIOR_"
            "PHYSICAL_CLOSURE_PASS",
            json.dumps(
                {
                    "gate_id": "QSDK-R24D170",
                    "ok": True,
                    "retained_supervisor_status": physical["status"],
                    "retained_scientific_outcome": physical["scientific_outcome"],
                    "publication_valid_complete_behavior_result": False,
                    "initializer_receipt_count": 0,
                    "r171_required": True,
                    "prone_to_standing_claimed": False,
                },
                sort_keys=True,
            ),
        )
        return 0
    except (
        ClosureAuditError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(
            "QSDK_R24D170_CONTIGUOUS_BOUNDARY_RECOVERY_BEHAVIOR_"
            f"PHYSICAL_CLOSURE_FAIL:{error}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
