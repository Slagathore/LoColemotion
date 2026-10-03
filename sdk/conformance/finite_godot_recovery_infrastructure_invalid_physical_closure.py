#!/usr/bin/env python3
"""Reusable audit for retained finite Godot recovery infrastructure failures."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    exact,
    git,
    load,
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


def _validate_source(
    root: Path,
    closure: dict[str, Any],
    contract_relative_path: str,
) -> dict[str, Any]:
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
            "gate_id": closure["gate_id"],
            "decision.physical_execution_authorized": True,
            "claim_boundary.complete_zero_world_gate_passed": True,
        },
        "QUALIFICATION_AUTHORITY_CONTENT",
    )
    contract = json.loads(source_bytes(root, freeze, contract_relative_path))
    exact(contract["gate_id"], closure["gate_id"], "CONTRACT_GATE")
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
    return contract


def _validate_attempt(
    root: Path,
    closure: dict[str, Any],
    expected_status: str,
    timeout_seconds: int,
    structured_invalid_profile: dict[str, Any] | None,
) -> None:
    physical = closure["physical_attempt"]
    evidence = Path(str(physical["evidence_root"]))
    exact(
        matching_evidence_roots(
            evidence.parent,
            "",
            "attempt.json",
            closure["gate_id"],
            closure["source"]["commit"],
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
        raw = (evidence / str(artifacts[key]["path"])).read_bytes()
        exact(
            (len(raw), "sha256:" + hashlib.sha256(raw).hexdigest()),
            (artifacts[key]["byte_length"], artifacts[key]["raw_sha256"]),
            key.upper(),
        )

    attempt, raw, terminal = values["attempt"], values["raw"], values["terminal"]
    common_attempt = {
        "gate_id": closure["gate_id"],
        "question_class": "development",
        "status": expected_status,
        "attempt_id": physical["attempt_id"],
        "source_commit": closure["source"]["commit"],
        "seed": physical["seed"],
        "seed_sha256": physical["seed_sha256"],
        "held_out": False,
        "physical_question_kind": "behavior_development",
        "actuator_mode": physical["actuator_mode"],
        "maximum_model_construction_attempt_count": physical[
            "maximum_model_construction_attempt_count"
        ],
        "maximum_model_construction_count": physical[
            "maximum_model_construction_count"
        ],
        "maximum_world_attempt_count": physical["maximum_world_attempt_count"],
        "maximum_world_build_count": physical["maximum_world_build_count"],
        "maximum_solver_step_count": physical["maximum_solver_step_count"],
        "operation_lock.acquired": True,
        "operation_lock.role": "physical_development",
        "operation_lock.test_only": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    verify_exact_paths(attempt, common_attempt, "ATTEMPT")
    terminal_expected: dict[str, Any] = {
        "gate_id": closure["gate_id"],
        "question_class": "development",
        "status": expected_status,
        "physical_question_kind": "behavior_development",
        "actuator_mode": physical["actuator_mode"],
        "integration_ghost_passed": False,
        "behavior_development_completed": False,
        "attempt_id": physical["attempt_id"],
        "source.head": closure["source"]["commit"],
        "source.upstream": closure["source"]["commit"],
        "source.cached_origin_main": closure["source"]["commit"],
        "source.live_origin_main": closure["source"]["commit"],
        "source.worktree_clean": True,
        "authorization.raw_sha256": physical["authorization_sha256"],
        "worker.engine_health.passed": True,
        "worker.engine_health.stderr_raw_byte_length": 0,
        "worker.engine_health.fatal_diagnostic_line_count": 0,
        "raw_result.raw_sha256": artifacts["raw"]["raw_sha256"],
        "raw_result.byte_length": artifacts["raw"]["byte_length"],
        "same_identity_rerun_permitted": False,
        "held_out": False,
        "recovery_success_required": False,
        "recovery_success_observed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    if structured_invalid_profile is None:
        verify_exact_paths(
            raw,
            {
                "ok": False,
                "failure_code": "SUPERVISOR_RAW_RESULT_MISSING_OR_INVALID",
                "raw_marker_count": 0,
            },
            "MISSING_RAW",
        )
        terminal_expected.update(
            {
                "worker.semantic_exit_code": 124,
                "worker.host_exit_code": -1,
                "worker.timed_out": True,
                "worker.termination_protocol_valid": False,
                "worker.raw_marker_count": 0,
                "worker.raw_binding_valid": False,
            }
        )
    else:
        profile_keys = set(structured_invalid_profile)
        common_profile_keys = {
            "physical_exact_paths",
            "raw_exact_paths",
            "terminal_exact_paths",
            "closure_exact_paths",
        }
        optional_profile_keys = {"raw_absent_keys"}
        normalized_profile_keys = profile_keys - optional_profile_keys
        legacy_profile_keys = common_profile_keys | {"raw_first_arm_exact_paths"}
        ordered_profile_keys = common_profile_keys | {
            "raw_ordered_arm_exact_paths"
        }
        require(
            normalized_profile_keys in (legacy_profile_keys, ordered_profile_keys),
            "STRUCTURED_INVALID_PROFILE_KEYS",
        )
        require(
            profile_keys <= normalized_profile_keys | optional_profile_keys,
            "STRUCTURED_INVALID_PROFILE_OPTIONAL_KEYS",
        )
        verify_exact_paths(
            physical,
            dict(structured_invalid_profile["physical_exact_paths"]),
            "STRUCTURED_PHYSICAL",
        )
        verify_exact_paths(
            raw,
            dict(structured_invalid_profile["raw_exact_paths"]),
            "STRUCTURED_RAW",
        )
        for key in structured_invalid_profile.get("raw_absent_keys", ()):
            require(
                isinstance(key, str) and key and key not in raw,
                f"STRUCTURED_RAW_ABSENT_KEY:{key}",
            )
        arm_summaries = raw["arm_execution_summary"]["ordered_arm_summaries"]
        require(isinstance(arm_summaries, list), "STRUCTURED_RAW_ARM_POPULATION")
        if "raw_first_arm_exact_paths" in structured_invalid_profile:
            require(len(arm_summaries) == 1, "STRUCTURED_RAW_ARM_POPULATION")
            arm_profiles = [
                dict(structured_invalid_profile["raw_first_arm_exact_paths"])
            ]
        else:
            ordered_profiles = structured_invalid_profile[
                "raw_ordered_arm_exact_paths"
            ]
            require(
                isinstance(ordered_profiles, (list, tuple))
                and len(arm_summaries) == len(ordered_profiles),
                "STRUCTURED_RAW_ARM_POPULATION",
            )
            if len(ordered_profiles) == 0:
                exact(
                    structured_invalid_profile["raw_exact_paths"].get(
                        "arm_execution_summary.completed_arm_count"
                    ),
                    0,
                    "STRUCTURED_RAW_EMPTY_ARM_COUNT_BINDING",
                )
            arm_profiles = [dict(profile) for profile in ordered_profiles]
        for index, (arm_summary, arm_profile) in enumerate(
            zip(arm_summaries, arm_profiles, strict=True)
        ):
            verify_exact_paths(
                arm_summary,
                arm_profile,
                f"STRUCTURED_RAW_ARM_{index}",
            )
        terminal_expected.update(
            dict(structured_invalid_profile["terminal_exact_paths"])
        )
    verify_exact_paths(terminal, terminal_expected, "TERMINAL")
    exact(
        physical["worker_timeout_seconds"],
        timeout_seconds,
        "WORKER_TIMEOUT_SECONDS",
    )
    exact(terminal["authorization"]["control"], None, "AUTHORIZATION_CONTROL")
    verify_content_addressed_json(physical["raw_result_cas"], label="RAW_CAS")
    verify_content_addressed_json(physical["terminal_cas"], label="TERMINAL_CAS")


def _validate_live_authority(
    root: Path,
    closure: dict[str, Any],
    closure_relative_path: str,
    closure_raw: bytes,
    live_record_key: str,
    live_identity_prefix: str,
) -> None:
    expected = dict(closure["live_authority_projection"])
    expected.update(
        {
            f"{live_identity_prefix}_path": closure_relative_path,
            f"{live_identity_prefix}_raw_sha256": (
                "sha256:" + hashlib.sha256(closure_raw).hexdigest()
            ),
            f"{live_identity_prefix}_byte_length": len(closure_raw),
        }
    )
    verify_legacy_live_authority_projection(
        root,
        tuple(str(path) for path in closure["live_authority_paths"]),
        record_key=live_record_key,
        expected=expected,
        prefix=f"LIVE_{closure['gate_id'].replace('-', '_')}_INVALID_PHYSICAL",
    )


def validate_closure(
    root: Path,
    closure_relative_path: str,
    closure_schema: str,
    gate_id: str,
    expected_raw_sha256: str,
    expected_byte_length: int,
    *,
    contract_relative_path: str,
    live_record_key: str,
    live_identity_prefix: str,
    next_gate_id: str,
    timeout_seconds: int,
    structured_invalid_profile: dict[str, Any] | None = None,
) -> dict[str, Any]:
    closure_path = root / closure_relative_path
    closure_raw = closure_path.read_bytes()
    exact(
        (len(closure_raw), "sha256:" + hashlib.sha256(closure_raw).hexdigest()),
        (expected_byte_length, expected_raw_sha256),
        "CLOSURE_IDENTITY",
    )
    closure = json.loads(closure_raw)
    verify_exact_paths(
        closure,
        {
            "schema_version": closure_schema,
            "gate_id": gate_id,
            "question_class": "development",
            "physical_question_declared": True,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "decision.behavior_attempt_consumed_for_exact_source": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.physical_execution_authorized": False,
            "decision.valid_complete_behavior_result": False,
            "decision.prone_to_standing_claimed": False,
            "claim_boundary.physical_attempted": True,
            "claim_boundary.physical_attempt_consumed": True,
            "claim_boundary.worker_timeout_observed": (
                structured_invalid_profile is None
            ),
            "claim_boundary.valid_complete_behavior_result": False,
            "claim_boundary.physical_trajectory_outcome_observable": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.sdk1_milestone_advanced": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "next_boundary.gate_id": next_gate_id,
            "next_boundary.physical_question_declared": False,
            "next_boundary.physical_execution_authorized": False,
        },
        "CLOSURE",
    )
    if structured_invalid_profile is not None:
        verify_exact_paths(
            closure,
            dict(structured_invalid_profile["closure_exact_paths"]),
            "STRUCTURED_CLOSURE",
        )
    _validate_source(root, closure, contract_relative_path)
    _validate_attempt(
        root,
        closure,
        "invalid_or_incomplete_behavior_development",
        timeout_seconds,
        structured_invalid_profile,
    )
    _validate_live_authority(
        root,
        closure,
        closure_relative_path,
        closure_raw,
        live_record_key,
        live_identity_prefix,
    )
    require((root / str(closure["closure_audit_path"])).is_file(), "AUDIT_PATH")
    return closure


def run_cli(
    root: Path,
    closure_relative_path: str,
    closure_schema: str,
    gate_id: str,
    expected_raw_sha256: str,
    expected_byte_length: int,
    pass_marker: str,
    failure_marker: str,
    *,
    contract_relative_path: str,
    live_record_key: str,
    live_identity_prefix: str,
    next_gate_id: str,
    timeout_seconds: int,
    structured_invalid_profile: dict[str, Any] | None = None,
) -> int:
    try:
        closure = validate_closure(
            root,
            closure_relative_path,
            closure_schema,
            gate_id,
            expected_raw_sha256,
            expected_byte_length,
            contract_relative_path=contract_relative_path,
            live_record_key=live_record_key,
            live_identity_prefix=live_identity_prefix,
            next_gate_id=next_gate_id,
            timeout_seconds=timeout_seconds,
            structured_invalid_profile=structured_invalid_profile,
        )
        physical = closure["physical_attempt"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": gate_id,
                    "ok": True,
                    "status": physical["status"],
                    "worker_timed_out": physical["worker_timed_out"],
                    "raw_marker_count": physical["raw_marker_count"],
                    "physical_trajectory_outcome_observable": False,
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
        print(f"{failure_marker}:{error}", file=sys.stderr)
        return 1
