#!/usr/bin/env python3
"""Reopen L13's exact sources and diagnose terminal faults without a world.

The two in-memory predicate substitutions below are diagnostic interventions,
not a replacement evaluator or a reclassification of the consumed experiment.
The original engine-health failure and missing child remain disqualifying.
"""

from __future__ import annotations

import ast
import hashlib
import json
from pathlib import Path
import subprocess
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
SOURCE = "0eee653968c75fe66e0dd5522011611cb5f1e282"
CLOSURE_PATH = ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v14.json"
CLOSURE_SHA = "sha256:1df9bd1896deb23989d6a3c080948a21805a1465b2682748d7e31c7fa1bdd4cb"
EVIDENCE_ROOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    r"\qsdk-r10f-development-route-ghost-30427ba7f22cd306"
)
SOURCE_BINDINGS = {
    "sdk/conformance/qsdk_r10f_physical_closure.py": (
        "8a02ead9d2e49416e671e222851f7b159a3025d0",
        502599,
        "sha256:61b89d8155b3174958703b63c2b32eb5c1d0ebf91c0c1d8398fc6aa917d70b73",
    ),
    "sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v1.gd": (
        "a122ebcc07930c6e41e34a3614595f3083b90ad4",
        19750,
        "sha256:fd3302794548df8eb72fa12f0bf56b4b22ac67f1d9c309ef1e946cc33464d4e7",
    ),
    "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd": (
        "ea52b0d9f3bbb1aee4dde9650826e65321b20e9c",
        274788,
        "sha256:9f7a9183a275a1a5f451db550ea150cf8e2548023a8bb233a01caa3f521ae398",
    ),
    "sdk/adapters/godot/gdscript/qsdk_r10f_process_isolated_child_contract_v1.gd": (
        "8620d1def286db217554bd1289d9023bdd0beebf",
        81660,
        "sha256:a81771f418ed49744e6eed5a2e9626d75516a1f59ffa9b2ac076508ab5399972",
    ),
    "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd": (
        "bba9d8c82b304f35b87f48b52157a3ac86480110",
        139818,
        "sha256:0a137200ce804c9f9efb135b5a9a6c0080e3854efd08e63d630cc86f885657d8",
    ),
}
LIMBS = ("front_left", "front_right", "rear_left", "rear_right")


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError(code)


def digest(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def git(*arguments: str) -> bytes:
    return subprocess.check_output(["git", *arguments], cwd=ROOT)


def identity(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    return {"path": path.as_posix(), "byte_length": len(raw), "raw_sha256": digest(raw)}


def reopen_binding(binding: dict[str, Any]) -> None:
    path = Path(binding["path"])
    if not path.is_absolute():
        path = ROOT / path
    found = identity(path)
    require(found["byte_length"] == binding["byte_length"], "RETAINED_BYTE_LENGTH")
    require(found["raw_sha256"] == binding["raw_sha256"], "RETAINED_RAW_DIGEST")


def contact_boundary_diagnosis(arm: dict[str, Any]) -> list[dict[str, Any]]:
    """Replay the frozen contact-state branches, recording undefined operands."""
    all_rows = arm["trace"]["rows"]
    require(
        [r["global_semantic_step"] for r in all_rows] == list(range(1, 2883)),
        "TRACE_ORDER",
    )
    by_step = {row["global_semantic_step"]: row for row in all_rows}
    result = []
    for session in arm["walking_sessions"]:
        start_step = session["start_receipt"]["global_start_step"]
        initial = by_step[start_step]["contact_by_limb"]
        rows = [r for r in all_rows if r["walking_session_id"] == session["session_id"]]
        require(
            [r["walking_session_local_step"] for r in rows]
            == list(range(1, len(rows) + 1)),
            "SESSION_ORDER",
        )
        require(rows[0]["global_semantic_step"] == start_step + 1, "SESSION_BOUNDARY")
        state = {
            limb: {
                "bearing": initial[limb],
                "airborne_steps": 0,
                "release_position": [],
            }
            for limb in LIMBS
        }
        counts = dict.fromkeys(LIMBS, 0)
        witnessed = dict.fromkeys(LIMBS, 0)
        undefined = []
        initial_touchdowns = []
        initially_open = {limb for limb in LIMBS if not initial[limb]}
        for row in rows:
            for limb in LIMBS:
                current = state[limb]
                contact = row["contact_by_limb"][limb]
                position = row["foot_position_world_m_by_limb"][limb]
                if current["bearing"] and not contact:
                    current.update(
                        bearing=False, airborne_steps=1, release_position=position
                    )
                elif not current["bearing"] and not contact:
                    current["airborne_steps"] += 1
                elif not current["bearing"] and contact:
                    event = {
                        "limb_id": limb,
                        "global_semantic_step": row["global_semantic_step"],
                        "session_local_step": row["walking_session_local_step"],
                        "observed_airborne_row_count": current["airborne_steps"],
                        "release_position_length": len(current["release_position"]),
                    }
                    if limb in initially_open:
                        initial_touchdowns.append(event)
                        initially_open.remove(limb)
                    if current["airborne_steps"] >= 3:
                        counts[limb] += 1
                        if len(current["release_position"]) != 3:
                            undefined.append(event)
                        else:
                            witnessed[limb] += 1
                    current.update(bearing=True, airborne_steps=0, release_position=[])
        require(
            counts == session["evaluation"]["contact_cycle_count_by_limb"],
            "FROZEN_BRANCH_COUNT_REPLAY",
        )
        result.append(
            {
                "segment_id": session["evaluation_segment_id"],
                "session_id": session["session_id"],
                "completed_start_global_step": start_step,
                "trace_row_count": len(rows),
                "initial_contact_by_limb_from_same_completed_observation": initial,
                "initial_partial_flight_touchdowns": initial_touchdowns,
                "undefined_release_operand_events": undefined,
                "frozen_report_cycle_counts_reproduced": counts,
                "cycles_with_observed_release_and_touchdown_diagnostic_only": witnessed,
            }
        )
    require(
        result[0]["undefined_release_operand_events"] == [],
        "PREFIX_UNEXPECTED_OPERAND_FAULT",
    )
    require(
        result[1]["undefined_release_operand_events"]
        == [
            {
                "limb_id": "rear_left",
                "global_semantic_step": 973,
                "session_local_step": 11,
                "observed_airborne_row_count": 10,
                "release_position_length": 0,
            }
        ],
        "CONTINUATION_EXACT_OPERAND_FAULT",
    )
    return result


def diagnose() -> dict[str, Any]:
    require(
        Path(git("rev-parse", "--show-toplevel").decode().strip()).resolve()
        == ROOT.resolve()
        == EXPECTED_ROOT.resolve(),
        "ROOT",
    )
    require(
        git("remote", "get-url", "origin").decode().strip()
        == "https://github.com/Slagathore/sporespore.git",
        "REMOTE",
    )
    closure_bytes = CLOSURE_PATH.read_bytes()
    require(
        len(closure_bytes) == 9998 and digest(closure_bytes) == CLOSURE_SHA,
        "L13_CLOSURE_IDENTITY",
    )
    closure = json.loads(closure_bytes)
    require(
        closure["classification"] == "invalid_or_incomplete_no_behavioral_conclusion"
        and closure["physical_identity_consumed"] is True
        and closure["same_identity_rerun_permitted"] is False,
        "L13_DISPOSITION",
    )
    bindings = closure["evidence_bindings"]
    for name, binding in bindings.items():
        if name == "child_process_artifacts":
            for artifacts in binding.values():
                for artifact in artifacts.values():
                    reopen_binding(artifact)
        else:
            reopen_binding(binding)
    reserved = (
        EVIDENCE_ROOT
        / "children/02-kick_passive_recovery_resume/child_attempt_identity.json"
    )
    require(
        identity(reserved)["raw_sha256"]
        == "sha256:fdf249d42e316dda6c94e3bf05c717fbb0bd7c2d1bb55cd14913cc84cda345db",
        "RESERVED_IDENTITY",
    )
    population = [identity(p) for p in sorted(EVIDENCE_ROOT.rglob("*")) if p.is_file()]
    require(
        len(population) == 10 and sum(p["byte_length"] for p in population) == 87684710,
        "RETAINED_POPULATION",
    )

    texts = {}
    sources = []
    for path, (blob, length, sha) in SOURCE_BINDINGS.items():
        raw = git("show", f"{SOURCE}:{path}")
        require(
            git("rev-parse", f"{SOURCE}:{path}").decode().strip() == blob
            and len(raw) == length
            and digest(raw) == sha,
            "FROZEN_SOURCE_IDENTITY",
        )
        texts[path] = raw.decode("utf-8")
        sources.append(
            {
                "path": path,
                "source_commit": SOURCE,
                "git_blob_oid": blob,
                "git_blob_byte_length": length,
                "git_blob_raw_sha256": sha,
            }
        )
    closer_path = "sdk/conformance/qsdk_r10f_physical_closure.py"
    ns: dict[str, Any] = {
        "__name__": "_l13_frozen_terminal_diagnostic",
        "__file__": str(ROOT / closer_path),
    }
    exec(compile(texts[closer_path], str(ROOT / closer_path), "exec"), ns)
    artifacts = bindings["child_process_artifacts"]["matched_no_kick_continuation"]
    report = json.loads(Path(artifacts["worker_report"]["path"]).read_bytes())
    health = json.loads(Path(artifacts["engine_health"]["path"]).read_bytes())
    stderr = Path(artifacts["worker_stderr"]["path"]).read_text()
    require(
        stderr.count("SCRIPT ERROR: Out of bounds get index '0'") == 2
        and "evaluate_segment_v1" in stderr,
        "EXACT_ENGINE_ERRORS",
    )
    require(
        health["passed"] is False and health["engine_error_line_count"] == 2,
        "FAILED_ENGINE_HEALTH_PRESERVED",
    )
    terminal = report["precondition_terminal_receipt"]
    memory = terminal["recovery_memory"]
    step = terminal["recovery_step_receipt"]
    classification = terminal["recovery_classification"]
    checks = {
        "memory_step_exact_int": ns["exact_int"](
            memory["last_semantic_step"], terminal["completed_global_semantic_step"]
        ),
        "step_memory_equal": step["memory"] == memory,
        "step_classification_equal": step["classification"] == classification,
        "memory_step_number_kind_equal": type(step["memory"]["last_semantic_step"])
        is type(memory["last_semantic_step"]),
        "step_next_phase_equal": step["next_phase"] == memory["phase"],
        "terminal_phase_equal": terminal["recovery_terminal_phase"] == memory["phase"],
    }
    hashes = {}
    for name, value in (
        ("recovery_memory", memory),
        ("recovery_step_receipt", step),
        ("recovery_classification", classification),
    ):
        computed = ns["canonical_sha256_v1"](value)
        hashes[name] = {"stored": terminal[name + "_sha256"], "recomputed": computed}
        checks[name + "_sha256"] = hashes[name]["stored"] == computed
    hashes["terminal_payload"] = {
        "stored": terminal["payload_sha256"],
        "recomputed": ns["payload_sha256_v1"](terminal),
    }
    checks["terminal_payload_sha256"] = (
        hashes["terminal_payload"]["stored"] == hashes["terminal_payload"]["recomputed"]
    )
    require(
        [key for key, value in checks.items() if not value]
        == ["memory_step_exact_int"],
        "EXACT_TERMINAL_PREDICATE",
    )
    require(
        type(memory["last_semantic_step"]) is float
        and memory["last_semantic_step"] == 240.0
        and type(terminal["completed_global_semantic_step"]) is int,
        "EXACT_NATIVE_NUMBER_KIND",
    )

    arguments = {
        "expected_role": report["arm_id"],
        "expected_parent_attempt_id": report["parent_attempt_id"],
        "expected_child_attempt_id": report["child_attempt_id"],
        "expected_source_commit": report["source_commit"],
        "expected_authority_sha256": report["authorization_sha256"],
        "expected_worker_process_id": report["process_id"],
    }
    outcomes = []
    functions = {
        node.name: ast.get_source_segment(texts[closer_path], node)
        for node in ast.parse(texts[closer_path]).body
        if isinstance(node, ast.FunctionDef)
    }
    interventions = [
        None,
        (
            "validate_l9_terminal_receipt",
            'exact_int(memory.get("last_semantic_step"), int(step_number))',
            'integer_valued_native_step_matches(memory.get("last_semantic_step"), step.get("memory", {}).get("last_semantic_step"), step_number)',
        ),
        (
            "validate_l9_child_report",
            "prefix_session=prefix,",
            'prefix_session=prefix.get("start_receipt", {}),',
        ),
    ]
    for intervention in interventions:
        if intervention is not None:
            name, old, new = intervention
            source = functions[name]
            require(source.count(old) == 1, "ISOLATION_EXACT_SUBSTITUTION")
            exec(
                compile(
                    source.replace(old, new),
                    "<diagnostic-in-memory-intervention>",
                    "exec",
                ),
                ns,
            )
        try:
            ns["validate_l9_child_report"](report, **arguments)
            outcomes.append("child_data_predicates_complete_engine_health_not_accepted")
        except ns["ClosureFailure"] as exc:
            outcomes.append(str(exc))
    require(
        outcomes
        == [
            "L9_matched_no_kick_continuation_TERMINAL_CONTENT_ADDRESS",
            "L9_matched_no_kick_continuation_INTERACTION_FIELDS",
            "child_data_predicates_complete_engine_health_not_accepted",
        ],
        "DOWNSTREAM_ISOLATION_SEQUENCE",
    )
    session = report["arm_result"]["walking_sessions"][0]
    interaction = report["interaction_source"]
    prefix_hash = ns["canonical_sha256_v1"](session["start_receipt"])
    wrapper_hash = ns["canonical_sha256_v1"](session)
    require(
        interaction["prefix_session_receipt_sha256"] == prefix_hash != wrapper_hash,
        "PREFIX_SOURCE_VS_WRAPPER",
    )
    require(
        interaction["payload_sha256"] == ns["payload_sha256_v1"](interaction),
        "INTERACTION_PAYLOAD_INTACT",
    )
    worker = texts["tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"]
    require(
        "var contacts := _contact_map_v1(observation)" in worker
        and 'var observation := _global_observation_from_collection_v1(arm["last_collection"])'
        in worker
        and "var initial_contacts := _contact_map_v1(observation)" in worker,
        "SAME_COMPLETED_OBSERVATION_SOURCE",
    )
    contacts = contact_boundary_diagnosis(report["arm_result"])
    # Recheck the immutable record after all diagnostic interventions.
    require(CLOSURE_PATH.read_bytes() == closure_bytes, "CLOSURE_MUTATED")
    for artifact in artifacts.values():
        reopen_binding(artifact)
    return {
        "schema_version": "sporespore_qsdk_r10f_l14_retained_terminal_diagnosis_v1",
        "status": "closed_zero_world_three_terminal_boundary_faults_isolated",
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L14",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_retained_terminal_diagnosis",
            "question_class": "development",
        },
        "ok": True,
        "diagnosis_source": identity(Path(__file__).resolve()),
        "consumed_predecessor_closure": identity(CLOSURE_PATH),
        "observed_source_commit": SOURCE,
        "frozen_source_bindings": sources,
        "retained_population_file_count": 10,
        "retained_population_byte_length": 87684710,
        "retained_population": population,
        "terminal_number_kind": {
            "retained_memory_step": memory["last_semantic_step"],
            "retained_memory_step_kind": "float",
            "completed_global_step": terminal["completed_global_semantic_step"],
            "completed_global_step_kind": "int",
            "predicate_vector": checks,
            "digest_recomputations": hashes,
            "diagnosis": "Exact numerical equality and all four digests hold; the Python consumer rejects the source number kind.",
        },
        "walking_contact_boundary": contacts,
        "walking_fault_explanation": "The continuation begins with two feet already airborne. Rear-left lands after ten retained airborne rows with no within-segment lift-off position. The frozen evaluator increments a cycle then indexes an empty vector; the two engine errors follow from subtraction and its dot-product caller.",
        "interaction_source_binding": {
            "stored_prefix_sha256": interaction["prefix_session_receipt_sha256"],
            "start_receipt_sha256": prefix_hash,
            "completed_session_wrapper_sha256": wrapper_hash,
            "interaction_payload_digest_matches": True,
            "diagnosis": "The native producer binds the start receipt; the Python caller supplies the later completed-session wrapper. The synthetic Python fixture duplicates that incorrect wrapper binding.",
        },
        "in_memory_consumer_isolation_sequence": outcomes,
        "in_memory_interventions_are_development_diagnostics_only": True,
        "stored_sources_modified": False,
        "retained_result_reclassified": False,
        "retained_engine_health_passed": False,
        "retained_engine_error_line_count": 2,
        "active_child_launched": False,
        "original_classification": closure["classification"],
        "original_child_projections_remain_empty": True,
        "source_controller_threshold_or_solver_inputs_changed": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_execution_authorized": False,
        "sdk1_m07_satisfied": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


if __name__ == "__main__":
    print(json.dumps(diagnose(), indent=2, ensure_ascii=False))
