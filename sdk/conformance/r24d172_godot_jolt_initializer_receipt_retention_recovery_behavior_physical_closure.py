#!/usr/bin/env python3
"""Audit the consumed R172 exact-nominal Godot/Jolt behavior positive.

The frozen shared finite-behavior helper predates positive Godot/Jolt results
and universally refuses a terminal prone-to-standing claim. This publication
audit preserves that helper byte-for-byte, reuses its trajectory, contiguous-
transport, and solver-motor projections, and owns the positive-specific claim
boundary for R172.
"""

from __future__ import annotations

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
    _solver_coupled_constraint_motor_projection,
    _trajectory_projection,
)


CLOSURE_PATH = (
    "sdk/recovery/"
    "r24d172_godot_jolt_initializer_receipt_retention_recovery_behavior_"
    "physical_closure_v1.json"
)
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d172_godot_jolt_initializer_receipt_retention_"
    "recovery_behavior_physical_closure_v1"
)
CONTRACT_PATH = (
    "sdk/recovery/"
    "r24d172_godot_jolt_initializer_receipt_retention_recovery_behavior_"
    "contract_v1.json"
)
EXPECTED_CLOSURE_SHA256 = (
    "sha256:87b0c9497ab4fa91da8d58f9cba1be9ab906a0d2603cedd5b8abc92231f36fe8"
)
EXPECTED_CLOSURE_BYTE_LENGTH = 29920
TRANSPORT_DESIGN_ID = (
    "godot_jolt_r24d167_contiguous_completed_step_boundary_transport_v1"
)
TRANSPORT_PROFILE_ID = (
    "godot_jolt_r24d168_live_contiguous_completed_step_boundary_transport_v1"
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
            "qualified_physical_path_count": 70,
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
        (
            len(authority_raw),
            "sha256:" + hashlib.sha256(authority_raw).hexdigest(),
        ),
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
            "gate_id": "QSDK-R24D172",
            "decision.physical_execution_authorized": True,
            "claim_boundary.complete_zero_world_gate_passed": True,
        },
        "QUALIFICATION_AUTHORITY_CONTENT",
    )
    contract = json.loads(source_bytes(root, freeze, CONTRACT_PATH))
    exact(contract["gate_id"], "QSDK-R24D172", "CONTRACT_GATE")
    qualified_paths = tuple(str(path) for path in contract["qualified_physical_paths"])
    exact(len(qualified_paths), 70, "QUALIFIED_PATH_COUNT")
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
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    physical = closure["physical_attempt"]
    evidence = Path(str(physical["evidence_root"]))
    exact(
        matching_evidence_roots(
            evidence.parent,
            "",
            "attempt.json",
            "QSDK-R24D172",
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
            (
                len(raw_bytes),
                "sha256:" + hashlib.sha256(raw_bytes).hexdigest(),
            ),
            (artifact["byte_length"], artifact["raw_sha256"]),
            key.upper(),
        )

    attempt, raw, terminal = values["attempt"], values["raw"], values["terminal"]
    common = {
        "gate_id": "QSDK-R24D172",
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
            "gate_id": "QSDK-R24D172",
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
            "authorization.byte_length": (
                closure["qualification_authority"]["byte_length_at_physical_start"]
            ),
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
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "behavior_evaluator_invocation_count",
        "held_out_cell_access_count",
    ):
        exact(raw[key], physical[key], f"RAW_{key.upper()}")
    verify_exact_paths(
        raw,
        {
            "scientific_outcome": "positive",
            "recovery_success_observed": True,
            "prone_to_standing_claimed": True,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "RAW_POSITIVE",
    )
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
        verify_content_addressed_json(
            physical["raw_result_cas"], label="RAW_CAS"
        ),
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
    return attempt, raw, terminal


def _validate_behavior(closure: dict[str, Any], raw: dict[str, Any]) -> None:
    exact(
        raw["arm_execution_summary"]["ordered_arm_summaries"],
        closure["observed_behavior"]["arm_summaries"],
        "ARM_SUMMARIES",
    )
    projection = {
        "candidate": _trajectory_projection(raw["candidate_arm"]),
        "matched_zero": _trajectory_projection(raw["matched_zero_arm"]),
    }
    candidate_transport = projection["candidate"].get(
        "contiguous_boundary_transport"
    )
    matched_transport = projection["matched_zero"].get(
        "contiguous_boundary_transport"
    )
    require(
        isinstance(candidate_transport, dict)
        and isinstance(matched_transport, dict),
        "CONTIGUOUS_TRANSPORT_REQUIRED",
    )
    verify_exact_paths(
        raw,
        {
            "contiguous_boundary_transport_profile_selected": True,
            "contiguous_boundary_transport_design_id": TRANSPORT_DESIGN_ID,
            "contiguous_boundary_transport_profile_id": TRANSPORT_PROFILE_ID,
            "boundary_transport_initializer_native_readback_count": 18,
            "boundary_transport_completed_boundary_count": 508,
            "boundary_transport_cache_advance_commit_count": 508,
            "candidate_boundary_transport_terminal_cached_sequence": 240,
            "candidate_boundary_transport_terminal_accepted_pair_count": 240,
            "candidate_boundary_transport_terminal_state_revision": 240,
            "matched_zero_boundary_transport_terminal_cached_sequence": 268,
            "matched_zero_boundary_transport_terminal_accepted_pair_count": 268,
            "matched_zero_boundary_transport_terminal_state_revision": 268,
        },
        "RAW_TRANSPORT",
    )
    projection["contiguous_boundary_transport_pair"] = {
        "initializer_native_readback_count": 18,
        "completed_boundary_count": 508,
        "cache_advance_commit_count": 508,
    }
    candidate_motor = _solver_coupled_constraint_motor_projection(
        raw["candidate_arm"]
    )
    matched_motor = _solver_coupled_constraint_motor_projection(
        raw["matched_zero_arm"]
    )
    require(
        int(candidate_motor["active_constraint_configuration_application_count"])
        > 0,
        "CANDIDATE_MOTOR_APPLICATIONS",
    )
    exact(
        matched_motor["active_constraint_configuration_application_count"],
        0,
        "MATCHED_ZERO_MOTOR_APPLICATIONS",
    )
    exact(
        candidate_motor["application_mutation_semantics_ids"],
        matched_motor["application_mutation_semantics_ids"],
        "ARM_MOTOR_SEMANTICS",
    )
    projection["candidate"]["solver_coupled_constraint_motor"] = candidate_motor
    projection["matched_zero"]["solver_coupled_constraint_motor"] = matched_motor
    exact(
        projection,
        closure["observed_behavior"]["computed_projection"],
        "COMPUTED_PROJECTION",
    )
    verify_exact_paths(
        raw["evaluation_acceptance_receipt"],
        closure["observed_behavior"]["evaluator_projection"],
        "EVALUATOR",
    )
    initializer_projection = closure["observed_behavior"][
        "initializer_receipt_projection"
    ]
    initializers = [
        raw["candidate_arm"]["boundary_transport_initializer_receipt"],
        raw["matched_zero_arm"]["boundary_transport_initializer_receipt"],
    ]
    exact(len(initializers), initializer_projection["required_receipt_count"],
          "INITIALIZER_REQUIRED_COUNT")
    exact(
        sum(bool(item.get("ok")) for item in initializers),
        initializer_projection["retained_valid_receipt_count"],
        "INITIALIZER_VALID_COUNT",
    )
    exact(
        sum(int(item["native_readback_count"]) for item in initializers),
        initializer_projection["total_native_readback_count"],
        "INITIALIZER_READBACK_COUNT",
    )
    for item in initializers:
        verify_exact_paths(
            item,
            {
                "schema_version": (
                    "sporespore_qsdk_r24d168_native_initializer_boundary_"
                    "transport_v1"
                ),
                "gate_id": "QSDK-R24D168",
                "initializer_boundary_sequence": 0,
                "state_revision": 0,
                "native_readback_count": 9,
                "physics_active_during_readback": False,
                "source_measurement": True,
                "transport_design_id": TRANSPORT_DESIGN_ID,
                "transport_profile_id": TRANSPORT_PROFILE_ID,
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "physics_state_modified": False,
                "physical_acceptance_authority": False,
                "release_authority": False,
            },
            "INITIALIZER",
        )


def _validate_disposition(closure: dict[str, Any]) -> None:
    verify_exact_paths(
        closure,
        {
            "closure_status": (
                "closed_consumed_valid_complete_initializer_receipt_retention_"
                "recovery_behavior_development_positive_exact_nominal_godot_"
                "jolt_observed_r173_required"
            ),
            "interpretation.complete_behavior_result_established": True,
            "interpretation.scientific_behavior_positive_established_for_exact_cell": True,
            "interpretation.exact_nominal_godot_jolt_prone_to_standing_observed": True,
            "interpretation.three_engine_canonical_conjunction_decision_completed": False,
            "decision.behavior_attempt_consumed_for_exact_source": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.physical_execution_authorized": False,
            "decision.valid_complete_behavior_result": True,
            "decision.behavior_negative_accepted_for_finite_development_inference": False,
            "decision.behavior_positive_accepted_for_exact_nominal_godot_jolt_observation": True,
            "decision.exact_nominal_godot_jolt_prone_to_standing_observed": True,
            "decision.all_engine_canonical_prone_to_standing_claimed": False,
            "decision.r173_three_engine_conjunction_decision_required": True,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "claim_boundary.physical_attempted": True,
            "claim_boundary.physical_attempt_consumed": True,
            "claim_boundary.required_initializer_receipts_observed": True,
            "claim_boundary.valid_complete_behavior_result": True,
            "claim_boundary.scientific_behavior_negative": False,
            "claim_boundary.scientific_behavior_positive_for_exact_nominal_godot_jolt": True,
            "claim_boundary.exact_nominal_godot_jolt_prone_to_standing_observed": True,
            "claim_boundary.all_engine_canonical_prone_to_standing_claimed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.repeatability_claimed": False,
            "claim_boundary.population_claimed": False,
            "claim_boundary.cross_engine_recovery_claimed": False,
            "claim_boundary.cross_engine_equivalence_claimed": False,
            "claim_boundary.sdk1_milestone_advanced": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "sdk_status.sdk1_milestone_advanced": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.full_program_completed_steps": 11,
            "next_boundary.gate_id": "QSDK-R24D173",
            "next_boundary.question_class": "finite_decision",
            "next_boundary.physical_question_declared": False,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_build_count": 0,
            "next_boundary.maximum_physical_steps_authorized": 0,
        },
        "DISPOSITION",
    )


def _validate_live_authority(
    root: Path, closure: dict[str, Any], closure_raw: bytes
) -> None:
    expected = dict(closure["live_authority_projection"])
    for key in (
        "r24d173_three_engine_conjunction_decision_required",
        "r24d173_question_class",
        "r24d173_physical_question_declared",
        "r24d173_physical_execution_authorized",
        "physical_execution_blocked_pending_r24d173_decision",
        "next_gate_id",
    ):
        expected.pop(key, None)
    expected.update(
        {
            "r24d172_physical_closure_path": CLOSURE_PATH,
            "r24d172_physical_closure_raw_sha256": (
                "sha256:" + hashlib.sha256(closure_raw).hexdigest()
            ),
            "r24d172_physical_closure_byte_length": len(closure_raw),
        }
    )
    verify_legacy_live_authority_projection(
        root,
        tuple(str(path) for path in closure["live_authority_paths"]),
        record_key="r24d172_contract_path",
        expected=expected,
        prefix="LIVE_QSDK_R24D172_PHYSICAL",
    )


def _validate(root: Path) -> dict[str, Any]:
    closure_path = root / CLOSURE_PATH
    closure_raw = closure_path.read_bytes()
    exact(
        (
            len(closure_raw),
            "sha256:" + hashlib.sha256(closure_raw).hexdigest(),
        ),
        (EXPECTED_CLOSURE_BYTE_LENGTH, EXPECTED_CLOSURE_SHA256),
        "CLOSURE_IDENTITY",
    )
    closure = json.loads(closure_raw)
    verify_exact_paths(
        closure,
        {
            "schema_version": CLOSURE_SCHEMA,
            "gate_id": "QSDK-R24D172",
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
    _attempt, raw, _terminal = _validate_attempt(closure)
    _validate_behavior(closure, raw)
    _validate_disposition(closure)
    _validate_live_authority(root, closure, closure_raw)
    require((root / str(closure["closure_audit_path"])).is_file(), "AUDIT_PATH")
    return closure


if __name__ == "__main__":
    try:
        value = _validate(ROOT)
        print(
            "QSDK_R24D172_INITIALIZER_RECEIPT_RETENTION_RECOVERY_BEHAVIOR_"
            "PHYSICAL_CLOSURE_PASS",
            json.dumps(
                {
                    "gate_id": value["gate_id"],
                    "ok": True,
                    "status": value["physical_attempt"]["status"],
                    "scientific_outcome": value["physical_attempt"][
                        "scientific_outcome"
                    ],
                    "model_construction_count": value["physical_attempt"][
                        "model_construction_count"
                    ],
                    "world_build_count": value["physical_attempt"][
                        "world_build_count"
                    ],
                    "solver_step_count": value["physical_attempt"][
                        "solver_step_count"
                    ],
                    "initializer_receipt_count": value["observed_behavior"][
                        "initializer_receipt_projection"
                    ]["retained_valid_receipt_count"],
                    "exact_nominal_godot_jolt_prone_to_standing_observed": (
                        value["claim_boundary"][
                            "exact_nominal_godot_jolt_prone_to_standing_observed"
                        ]
                    ),
                    "sdk1_milestone_advanced": value["claim_boundary"][
                        "sdk1_milestone_advanced"
                    ],
                },
                sort_keys=True,
            ),
        )
        raise SystemExit(0)
    except (
        ClosureAuditError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(
            "QSDK_R24D172_INITIALIZER_RECEIPT_RETENTION_RECOVERY_BEHAVIOR_"
            f"PHYSICAL_CLOSURE_FAIL:{error}",
            file=sys.stderr,
        )
        raise SystemExit(1)
