"""Read-only, zero-world isolation of the untested no-resume child boundary.

The real GDScript orchestrator receives synthetic source events. One explicit
in-memory collector substitution isolates its independent consumer mismatch;
the replacement never touches production code or a retained physical result.
"""

from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import types

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "f35a90e746ba14fb4b51fbfcdec35fecea7d61c7"
GDS_PATH = "tests/test_sdk_qsdk_r10f_l14_no_resume_branch_diagnosis.gd"
GDS_MARKER = "QSDK_R10F_L14_NO_RESUME_BRANCH_DIAGNOSIS "
MARKER = "QSDK_R10F_L14_NO_RESUME_CONSUMER_DIAGNOSIS_PASS "
DEFAULT_GODOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r24d157-godot-jolt-rotation-integration-energy-v6\development-cold-build-ed4ec00a\godot.windows.editor.dev.x86_64.console.exe"
)
FIXED_PATHS = (
    "sdk/conformance/qsdk_r10f_physical_closure.py",
    "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd",
    "sdk/adapters/godot/gdscript/qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1.gd",
    "sdk/conformance/qsdk_r10f_l14_terminal_consumers.py",
    "sdk/conformance/qsdk_r10f_l14_walking_failure_retention.py",
)


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError(code)


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def identity(path: Path) -> dict:
    raw = path.read_bytes()
    return {
        "path": path.relative_to(ROOT).as_posix(),
        "byte_length": len(raw),
        "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
    }


def frozen_source(relative: str) -> bytes:
    return subprocess.check_output(["git", "show", f"{SOURCE}:{relative}"], cwd=ROOT)


def frozen_module(relative: str) -> types.ModuleType:
    module = types.ModuleType("l14_no_resume_frozen_" + Path(relative).stem)
    module.__file__ = str(ROOT / relative)
    exec(compile(frozen_source(relative), module.__file__, "exec"), module.__dict__)
    return module


def diagnose(godot: Path = DEFAULT_GODOT) -> dict:
    require(
        Path(git("rev-parse", "--show-toplevel")).resolve()
        == ROOT
        == Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore"),
        "NO_RESUME_ROOT",
    )
    require(
        git("remote", "get-url", "origin")
        == "https://github.com/Slagathore/sporespore.git",
        "NO_RESUME_REMOTE",
    )
    bindings = []
    for relative in FIXED_PATHS:
        path = ROOT / relative
        blob = git("rev-parse", f"{SOURCE}:{relative}")
        raw = frozen_source(relative)
        # The pure GDScript orchestrator is unchanged and actually executes.
        # The evolving Python closer and worker are reopened from frozen Git.
        if relative == FIXED_PATHS[2]:
            require(
                git("hash-object", str(path)) == blob, "NO_RESUME_ORCHESTRATOR_DRIFT"
            )
        bindings.append(
            {
                "path": relative,
                "git_blob_byte_length": len(raw),
                "git_blob_raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
                "source_commit": SOURCE,
                "git_blob_oid": blob,
            }
        )
    closer = frozen_module(FIXED_PATHS[0])
    closer.l14_terminal = frozen_module(FIXED_PATHS[3])
    closer.l14_walking_failure = frozen_module(FIXED_PATHS[4])
    closer.l14_walking_failure.same_source_value = closer.l14_terminal.same_source_value
    closer_source = frozen_source(FIXED_PATHS[0]).decode("utf-8")
    function_sources = {
        node.name: ast.get_source_segment(closer_source, node)
        for node in ast.parse(closer_source).body
        if isinstance(node, ast.FunctionDef)
    }
    run = subprocess.run(
        [
            str(godot),
            "--headless",
            "--path",
            str(ROOT),
            "--script",
            "res://" + GDS_PATH,
        ],
        cwd=ROOT,
        text=True,
        encoding="utf-8",
        capture_output=True,
        timeout=90,
    )
    require(
        run.returncode == 0 and "ERROR:" not in run.stdout + run.stderr,
        "NO_RESUME_GDSCRIPT_FAILURE:" + run.stderr[:1500],
    )
    marked = [
        line[len(GDS_MARKER) :]
        for line in run.stdout.splitlines()
        if line.startswith(GDS_MARKER)
    ]
    require(len(marked) == 1, "NO_RESUME_GDSCRIPT_MARKER")
    receipt = json.loads(marked[0])
    require(
        receipt.get("ok") is True and receipt.get("source_only_branch_count") == 3,
        "NO_RESUME_GDSCRIPT_BRANCHES",
    )
    for field in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "scene_tree_insertion_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(
            type(receipt.get(field)) is int and receipt[field] == 0,
            "NO_RESUME_ZERO:" + field,
        )

    # Isolate only the named collector predicate in a private namespace. This
    # deliberately is NOT the proposed production repair or qualification.
    collector_text = function_sources["validate_l12_walking_handoff_population"]
    old = 'else ["walking_prefix", "walking_resume"]'
    require(collector_text.count(old) == 1, "NO_RESUME_COLLECTOR_SOURCE_SEAM")
    diagnostic_namespace = dict(closer.__dict__)
    exec(
        compile(
            collector_text.replace(old, 'else ["walking_prefix"]'),
            "<l14-diagnostic-one-session-collector>",
            "exec",
        ),
        diagnostic_namespace,
    )
    exec(
        compile(
            function_sources["validate_l9_child_report"],
            "<l14-diagnostic-original-child-consumer>",
            "exec",
        ),
        diagnostic_namespace,
    )
    cases = []
    for branch in receipt["cases"]:
        state = branch["terminal_state"]
        require(
            state["payload_sha256"] == closer.payload_sha256_v1(state),
            "NO_RESUME_STATE_DIGEST",
        )
        require(
            branch["semantic_advance_receipt"]["state_after"] == state,
            "NO_RESUME_STATE_SOURCE",
        )
        require(
            state["phase"] == "failed"
            and state["walking_resume_step_count"] == 0
            and state["resume_or_continuation_session_id"] == "",
            "NO_RESUME_TERMINAL",
        )
        report = closer.l9_synthetic_child_report(
            closer.ACTIVE_ARM,
            "0123456789abcdef0123456789abcdef",
            "2" * 32,
            "3" * 40,
            "sha256:" + "4" * 64,
            1234,
            outcome="behavior_negative",
        )
        arm = report["arm_result"]
        arm["walking_sessions"] = arm["walking_sessions"][:1]
        arm["walking_actuation_handoff_receipts"] = arm[
            "walking_actuation_handoff_receipts"
        ][:1]
        arm["final_phase"] = state["phase"]
        arm["terminal_reason"] = state["terminal_reason"]
        arm["final_orchestrator_state"] = copy.deepcopy(state)
        report["reached_walking_resume"] = False
        report["reached_post_kick_recovery"] = (
            state["post_kick_recovery_step_count"] > 0
        )
        steps = state["total_completed_solver_step_count"]
        rows, invariants = closer.l9_synthetic_solver_receipts(
            closer.ACTIVE_ARM, arm["body_population_instance_sha256"], steps
        )
        arm["trace"]["rows"] = rows
        arm["trace_sha256"] = closer.canonical_sha256_v1(arm["trace"])
        arm["in_run_invariant_receipts"] = invariants
        for field in (
            "outer_step_count",
            "native_solver_step_count",
            "in_run_invariant_receipt_count",
        ):
            arm[field] = steps
        for field in (
            "solver_step_count",
            "global_solver_frame_count",
            "in_run_invariant_receipt_count",
        ):
            report[field] = steps
        interaction = report["interaction_source"]
        interaction["completed_effect_global_step"] = state["epoch_start_global_step"]
        interaction["payload_sha256"] = closer.payload_sha256_v1(interaction)
        report["interaction_source_sha256"] = interaction["payload_sha256"]
        arm["interaction_source"] = copy.deepcopy(interaction)
        args = dict(
            expected_role=closer.ACTIVE_ARM,
            expected_parent_attempt_id=report["parent_attempt_id"],
            expected_child_attempt_id=report["child_attempt_id"],
            expected_source_commit=report["source_commit"],
            expected_authority_sha256=report["authorization_sha256"],
            expected_worker_process_id=report["process_id"],
        )
        original_error = ""
        try:
            closer.validate_l9_child_report(report, **args)
        except closer.ClosureFailure as exc:
            original_error = str(exc)
        require(
            original_error
            == "L12_kick_passive_recovery_resume_HANDOFF_POPULATION_COUNT",
            "NO_RESUME_ORIGINAL_REFUSAL:" + original_error,
        )
        after = diagnostic_namespace["validate_l9_child_report"](report, **args)
        require(
            after["role_outcome"] == "behavior_negative"
            and after["walking"]["session_count"] == 1
            and after["walking_actuation_handoffs"]["handoff_count"] == 1,
            "NO_RESUME_DOWNSTREAM_ISOLATION",
        )
        cases.append(
            {
                "case_id": branch["case_id"],
                "source_phase": branch["source_phase"],
                "terminal_controller_kind": branch["terminal_controller_kind"],
                "terminal_state_sha256": state["payload_sha256"],
                "synthetic_completed_semantic_steps": steps,
                "walking_prefix_step_count": state["walking_prefix_step_count"],
                "walking_resume_step_count": 0,
                "completed_session_count": 1,
                "walking_handoff_count": 1,
                "original_consumer_refusal": original_error,
                "other_original_child_predicates_pass_after_explicit_diagnostic_substitution": True,
                "physical_result_or_route_ghost_qualified": False,
            }
        )
    for binding in bindings:
        require(
            "sha256:" + hashlib.sha256(frozen_source(binding["path"])).hexdigest()
            == binding["git_blob_raw_sha256"],
            "NO_RESUME_SOURCE_CHANGED_DURING_DIAGNOSIS",
        )
    return {
        "schema_version": "sporespore_qsdk_r10f_l14_no_resume_consumer_diagnosis_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L14",
        "ok": True,
        "status": "closed_zero_world_additional_branch_mismatch_isolated_no_production_repair_authorized",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_source_branch_diagnosis",
            "question_class": "development",
        },
        "diagnosis_source": identity(Path(__file__).resolve()),
        "branch_source": identity(ROOT / GDS_PATH),
        "bound_source_population": bindings,
        "actual_orchestrator_source_branch_count": 3,
        "cases": cases,
        "diagnostic_substitution_count": 1,
        "consumer_reopened_from_frozen_git_not_mutable_checkout": True,
        "production_code_changed_by_diagnosis": False,
        "physical_result_changed_or_promoted": False,
        "next_required_boundary": "distinct_scoped_branch_completeness_design_and_negative_controls",
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


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot-exe", type=Path, default=DEFAULT_GODOT)
    arguments = parser.parse_args()
    print(MARKER + json.dumps(diagnose(arguments.godot_exe), sort_keys=True))
