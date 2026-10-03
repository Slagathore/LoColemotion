"""Compact audit of the consumed invalid R24D57 native-route ghost."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    load,
    matching_evidence_roots,
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
    verify_retained_file_tree,
    verify_retained_json,
    verify_source_binding,
)


CLOSURE = ROOT / (
    "sdk/recovery/"
    "r24d57_godot_native_recovery_route_ghost_invalid_closure_v1.json"
)
SOURCE = "4cfbf6041ec363538db38ec2e9408b8f80377044"
STATUS = (
    "closed_consumed_invalid_native_initializer_readback_before_"
    "world_completion_or_solver_step"
)
DECISION_TRUE = (
    "integration_ghost_attempt_consumed_for_exact_source",
    "native_scene_node_construction_attempted",
    "failure_preceded_body_unfreeze",
    "failure_preceded_solver_step",
    "distinct_successor_source_required",
    "initializer_readback_representation_contract_required",
    "supervisor_output_and_exit_projection_repair_required",
    "construction_counter_semantics_repair_required",
)
DECISION_FALSE = (
    "world_build_completed",
    "physics_state_modified",
    "physical_result_observed",
    "physics_failure_observed",
    "controller_behavior_evaluated",
    "integration_ghost_passed",
    "same_identity_rerun_permitted",
    "r24d57_requalification_permitted",
    "historical_threshold_changed",
    "historical_selector_changed",
    "historical_evaluator_changed",
    "historical_result_rewritten",
    "prone_to_standing_claimed",
    "physical_acceptance_authority",
    "release_authority",
)
CLAIM_TRUE = (
    "integration_ghost_attempt_retained",
    "integration_ghost_attempt_consumed_for_exact_source",
    "invalid_integration_result",
    "native_scene_node_construction_attempted",
    "termination_protocol_valid",
)
CLAIM_FALSE = (
    "world_build_completed",
    "solver_step_executed",
    "physics_state_modified",
    "native_runtime_observation_collection_executed",
    "portable_command_applied",
    "integration_ghost_passed",
    "controller_behavior_evaluated",
    "physics_failure_observed",
    "prone_to_standing_claimed",
    "population_claimed",
    "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced",
    "physical_acceptance_authority",
    "release_authority",
)


def _verify_cas(claim: dict[str, object]) -> None:
    payload = Path(str(claim["payload_path"]))
    manifest_path = Path(str(claim["manifest_path"]))
    raw = payload.read_bytes()
    exact((len(raw), sha256(raw)), (claim["byte_length"], claim["sha256"]), "CAS")
    manifest = load(manifest_path)
    verify_exact_paths(
        manifest,
        {
            "schema_version": "sporespore_content_addressed_artifact_manifest_v1",
            "algorithm": "sha256",
            "sha256": claim["sha256"],
            "byte_length": claim["byte_length"],
            "payload_name": "payload.bin",
            "media_type": "application/json",
        },
        "CAS_MANIFEST",
    )


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d57_godot_native_recovery_route_"
                "ghost_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D57",
            "stage_id": "R24D57-GHOST",
            "closure_status": STATUS,
            "question_class": "development_integration_ghost",
            "physical_question_declared": True,
            "behavior_success_required": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": "931ee0f5210e448f92a7953b546896f7ca6346a1",
            "source.tree": "79bcc3cb09a77cdcd8fb155caaccd0ed7ca2abce",
            "source.subject": "[recovery/godot] Close R57 zero-world qualification",
            "source.qualification_source_commit": (
                "931ee0f5210e448f92a7953b546896f7ca6346a1"
            ),
        },
        "CLOSURE",
    )
    exact(git(ROOT, "show", "-s", "--format=%P", SOURCE),
          closure["source"]["parent_commit"], "SOURCE_PARENT")
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE),
          closure["source"]["tree"], "SOURCE_TREE")
    exact(git(ROOT, "show", "-s", "--format=%s", SOURCE),
          closure["source"]["subject"], "SOURCE_SUBJECT")
    for name in (
        "contract", "qualification_closure", "native_world", "native_route",
        "ghost_worker", "ghost_supervisor",
    ):
        verify_source_binding(ROOT, SOURCE, closure["source"][name])

    physical = closure["physical_attempt"]
    evidence = Path(physical["evidence_root"])
    exact(
        matching_evidence_roots(
            evidence.parent, "", "attempt.json", "QSDK-R24D57", SOURCE
        ),
        [evidence],
        "ATTEMPT_POPULATION",
    )
    verify_retained_file_tree(evidence, physical["retained_tree"])
    attempt = verify_retained_json(
        evidence / physical["attempt_path"],
        physical["attempt_byte_length"], physical["attempt_raw_sha256"],
        physical["attempt_canonical_byte_length"],
        physical["attempt_canonical_sha256"],
    )
    terminal = verify_retained_json(
        evidence / physical["terminal_path"],
        physical["terminal_byte_length"], physical["terminal_raw_sha256"],
        physical["terminal_canonical_byte_length"],
        physical["terminal_canonical_sha256"],
    )
    raw = verify_retained_json(
        evidence / physical["raw_result_path"],
        physical["raw_result_byte_length"], physical["raw_result_raw_sha256"],
        physical["raw_result_canonical_byte_length"],
        physical["raw_result_canonical_sha256"],
    )
    verify_exact_paths(
        attempt,
        {
            "schema_version": "sporespore_qsdk_r24d57_ghost_attempt_v1",
            "gate_id": "QSDK-R24D57", "question_class": "development",
            "status": "invalid_or_incomplete_integration_ghost",
            "attempt_id": physical["attempt_id"], "source_commit": SOURCE,
            "seed": physical["seed"], "seed_sha256": physical["seed_sha256"],
            "held_out": False, "maximum_world_build_count": 1,
            "maximum_solver_step_count": 2,
            "physical_acceptance_authority": False, "release_authority": False,
        },
        "ATTEMPT",
    )
    verify_exact_paths(
        terminal,
        {
            "status": "invalid_or_incomplete_integration_ghost",
            "integration_ghost_passed": False,
            "attempt_id": physical["attempt_id"],
            "source.head": SOURCE, "source.upstream": SOURCE,
            "source.live_origin_main": SOURCE, "source.worktree_clean": True,
            "authorization.raw_sha256": (
                closure["source"]["qualification_closure"]["raw_sha256"]
            ),
            "worker.semantic_exit_code": 1,
            "worker.host_exit_code": -1,
            "worker.timed_out": False,
            "worker.termination_protocol_valid": True,
            "worker.raw_marker_count": 1,
            "worker.raw_binding_valid": True,
            "same_identity_rerun_permitted": False,
            "held_out": False, "recovery_success_required": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False, "release_authority": False,
        },
        "TERMINAL",
    )
    verify_exact_paths(
        raw,
        {
            "status": "invalid_or_incomplete_integration_ghost",
            "failure_code": physical["outer_failure_code"],
            "detail.failure_code": physical["world_failure_code"],
            "detail.detail.readback.failure_code": physical["deepest_failure_code"],
            "model_construction_count": 0, "world_attempt_count": 1,
            "world_build_count": 0, "solver_step_count": 0,
            "behavior_evaluator_invocation_count": 0,
            "threshold_count": 0, "margin_count": 0,
            "held_out_cell_access_count": 0,
            "physics_state_modified": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False, "release_authority": False,
        },
        "RAW",
    )
    for path_key, length_key, hash_key in (
        ("stdout_path", "stdout_byte_length", "stdout_raw_sha256"),
        ("stderr_path", "stderr_byte_length", "stderr_raw_sha256"),
    ):
        blob = (evidence / physical[path_key]).read_bytes()
        exact((len(blob), sha256(blob)),
              (physical[length_key], physical[hash_key]), path_key.upper())
    stdout = (evidence / physical["stdout_path"]).read_text(encoding="utf-8")
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build",
            "QSDK_R24D57_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW ",
            physical["deepest_failure_code"],
            "QSDK_R24D57_GODOT_SUPERVISOR_TERMINATION_READY ",
        ),
        "STDOUT",
    )
    _verify_cas(physical["raw_result_cas"])
    _verify_cas(physical["terminal_cas"])
    exact((physical["model_construction_count_as_recorded"],
           physical["world_attempt_count"], physical["world_build_count"],
           physical["solver_step_count"]), (0, 1, 0, 0), "COUNTS")
    verify_boolean_partition(closure["decision"], DECISION_TRUE, DECISION_FALSE,
                             "DECISION")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE,
                             "CLAIM")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    revision = publication or None
    closure_raw = CLOSURE.read_bytes() if revision is None else source_bytes(
        ROOT, revision, relative
    )
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        {
            **closure["live_gate_expectations"],
            "r24d57_ghost_invalid_closure_raw_sha256": sha256(closure_raw),
        },
        revision=revision,
    )
    print(
        "QSDK_R24D57_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_INVALID_CLOSURE_PASS "
        "attempts=1 nodes_attempted=1 worlds=0 steps=0 evaluator=0 "
        "same_identity_rerun=0 next=R24D58 sdk1=11/20"
    )


if __name__ == "__main__":
    try:
        audit()
    except (
        ClosureAuditError, OSError, KeyError, TypeError, ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            "QSDK_R24D57_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_INVALID_"
            f"CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
