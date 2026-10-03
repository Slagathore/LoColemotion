#!/usr/bin/env python3
"""Audit the immutable R24D10 finite physical characterization closure.

This audit reads exact Git objects, the durable run, and content-addressed
payloads. It does not invoke the production supervisor, launch Godot, create
an attempt, or construct a physics world.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import subprocess
from pathlib import Path
from typing import Any, NoReturn


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
AUTHORIZATION_COMMIT = "9d2f8d59834c7cb9bf8271d0a10b3c2edcef7d22"
AUTHORIZATION_TREE = "60fd3bb03bedc032211e275d4bf995beafeae8c5"
FREEZE_COMMIT = "b2bccdb76041a46a5d51ba56129f014e6c0dbf95"
FREEZE_TREE = "3e19ff30cb1a07dbee60f32fe35b8e6f6ac0050d"
RUN_ROOT = EVIDENCE_ROOT / (
    "qsdk-r24d10-exact-step-numerical-telemetry/physical/"
    "20260826T204714579Z-9d2f8d59-6ccc8d1496a5"
)
QUALIFICATION_ROOT = EVIDENCE_ROOT / (
    "qsdk-r24d10-exact-step-numerical-telemetry/"
    "physical-supervisor-qualification/"
    "20260826T203447143Z-b2bccdb7-a2955f32da4a"
)
CLOSURE_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_characterization_closure_v1.json"
)
AUDIT_REL = (
    "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_"
    "physical_characterization_closure.py"
)
AUTHORIZATION_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_authorization_v2.json"
)
QUALIFICATION_CLOSURE_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_supervisor_qualification_positive_closure_v2.json"
)
SUPERVISOR_REL = (
    "sdk/run_qsdk_r24d10_exact_step_numerical_telemetry_characterization.ps1"
)
MANIFEST_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_supervisor_manifest_v2.json"
)
EVALUATOR_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "characterization_evaluator.py"
)
KERNEL_REL = (
    "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_"
    "characterization_evaluator.py"
)

CLOSURE_SHA = (
    "sha256:465b9c4ecbd8c1b0e5a5839ebc27f826c56cdf9a1b153a65f187a0940972b2c5"
)
AUTHORIZATION_SHA = (
    "sha256:c228c020c3ec42f246a9676f0cdecc29742f2b69b595cbd756c13ac106e3b059"
)
QUALIFICATION_CLOSURE_SHA = (
    "sha256:2eff43d9c960c64a7a889874711de4af89baea066e774ea278f17a0375752a58"
)
QUALIFICATION_RECEIPT_SHA = (
    "sha256:a260a3c1a883487e5615fd1de82d8d6b05a5deefbf484bf82e266b4a73412cd7"
)
ATTEMPT_SHA = (
    "sha256:01b012db8b764dedb16e194ab297be603b7c54b912e89734f175c637212d63f1"
)
RAW_REPORT_SHA = (
    "sha256:882c129917694de6c00d33f564e9b968e9a06b2fa7f10acbf73a227ae3520ef5"
)
RAW_REPORT_CANONICAL_SHA = (
    "sha256:72d9d6104eac95885866e8fcf69acf780ca426350cde17cd2b49c1cc7096a0ea"
)
EVALUATION_SHA = (
    "sha256:5cc0d1823c5b47e23e8d4e986d1110b9ece4093c95b2d6d42f3d2808c247bca5"
)
RECEIPT_SHA = (
    "sha256:1b75e51e8299b2b7a35ddff26db3059a9fea93e49a95e6feb170744a7a309f1b"
)
CONSOLE_SHA = (
    "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
)
ENGINE_SHA = (
    "sha256:2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
)
EXECUTION_NONCE = "6ccc8d1496a5409a918c3dee501814a4"

ORDERED_STAGES = [
    "immutable_r24d10_v1_adoption_refusal_recheck",
    "immutable_r24d10_zero_world_closure_recheck",
    "r24d10_physical_supervisor_source_audit",
    "r24d10_evaluator_self_test",
    "native_exact_step_evaluation",
]
CELL_IDS = [
    "drive_positive",
    "drive_negative",
    "brake_positive",
    "brake_negative",
    "disabled_positive",
    "disabled_negative",
    "limit_positive",
    "limit_negative",
    "sleep_stale",
]
EXPECTED_CELL_SHAPE = {
    "drive_positive": ("signed_drive", 4, 4, 0, 2.3283064365386963e-10, 2.540648247340016e-11),
    "drive_negative": ("signed_drive", 4, 4, 0, 2.3283064365386963e-10, 2.540648247340016e-11),
    "brake_positive": ("signed_braking", 4, 4, 0, 0.020000000298023225, 0.004000000119209291),
    "brake_negative": ("signed_braking", 4, 4, 0, 0.020000000298023225, 0.004000000119209291),
    "disabled_positive": ("motor_disabled", 4, 4, 0, 0.020000000298023225, 0.004000000119209291),
    "disabled_negative": ("motor_disabled", 4, 4, 0, 0.020000000298023225, 0.004000000119209291),
    "limit_positive": ("limit_active_separation", 20, 20, 0, 0.05999999679625034, 0.03599999602884063),
    "limit_negative": ("limit_active_separation", 20, 20, 0, 0.05999999679625034, 0.03599999602884063),
    "sleep_stale": ("sleeping_freshness", 4, 1, 3, 0.0, 0.0),
}
INITIAL_REAL_T_PROJECTION = {
    "drive_positive": 0.0,
    "drive_negative": 0.0,
    "brake_positive": 0.4000000059604645,
    "brake_negative": -0.4000000059604645,
    "disabled_positive": 0.4000000059604645,
    "disabled_negative": -0.4000000059604645,
    "limit_positive": 0.0,
    "limit_negative": 0.0,
    "sleep_stale": 0.0,
}

FROZEN_SOURCE = {
    SUPERVISOR_REL: (
        "sha256:889ab73e34c9c4dfa4d24484f8d57e199ca665b137183e80dd390e40cb4de7ca",
        72353,
        "8b43ae7d8e52af481c6ede39010eeaa3d06b5a5a",
    ),
    MANIFEST_REL: (
        "sha256:6684a37ba78f68818cc35c23240d6f66ebcf0bb592aed6041e82f632ec35210a",
        7132,
        "2375ee6064110fd05891a2d0a3450d5bbf0a6dfb",
    ),
    AUTHORIZATION_REL: (
        AUTHORIZATION_SHA,
        2804,
        "3f11bfe69b667717f34440ee359edc6e76ec20bf",
    ),
    EVALUATOR_REL: (
        "sha256:59d1401aa2637ced6fbb5c6a700c7181a0f54be7471ee08a179c594c63f67246",
        27839,
        "83a08a6f1664c7901729d9a733cc04cf98bc560e",
    ),
    KERNEL_REL: (
        "sha256:a5a1e988734877564ae9288fb33c8ac30a99be86edccb4409400031c1b579554",
        58064,
        "e8094e2e4a5c0781822f79af3b6e8e705b67f8f0",
    ),
    "scripts/lab/rigs/r24d10_godot_jolt_exact_step_numerical_telemetry_rig.gd": (
        "sha256:422a35f3ae917ca54ca67bee9fe023f9485b618f14b0e580c0c1121ad64489fb",
        1905,
        "4a53783310cb4efa321a9888394314e6d3c2f463",
    ),
    "scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd": (
        "sha256:47a4d8ec969181a79fa3c849d8278674164b209a54075bb1549b0e1d0cdc4625",
        10862,
        "7f0058b6ab375b36238f7a6b063330c1dc40c09b",
    ),
    "tests/test_sdk_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_worker.gd": (
        "sha256:a182d2c73652b71159f2b9d2667c689c795d7a6ae8aed18584c5629b8697cf8d",
        24913,
        "1fa19c8fe78bd3fe718425864686df0f8c36db84",
    ),
    "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd": (
        "sha256:8bf00926b26d66c2916388ff1dbae1a774f019653a3c1b4d051173e35e2e6b25",
        21798,
        "4e24d75f6fde7729a6d028fd05b37b028c55bf7b",
    ),
}

PROJECT_SOURCE_MAP = {
    "project/scripts/lab/rigs/r24d10_godot_jolt_exact_step_numerical_telemetry_rig.gd": (
        "scripts/lab/rigs/r24d10_godot_jolt_exact_step_numerical_telemetry_rig.gd"
    ),
    "project/scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd": (
        "scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd"
    ),
    "project/tests/test_sdk_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_worker.gd": (
        "tests/test_sdk_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_worker.gd"
    ),
    "project/tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd": (
        "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd"
    ),
}

EXPECTED_INVENTORY = [
    ("01-immutable_r24d10_v1_adoption_refusal_recheck.log", "sha256:6d5fdd476c45342819d286d43e87098429ee271a58fddebfe1e9a09d95d9c83b", 357),
    ("02-immutable_r24d10_zero_world_closure_recheck.log", "sha256:a22e472055711469f8675da6cb288fd42d5f84f513fbee10c2863802b7736aea", 431),
    ("03-r24d10_physical_supervisor_source_audit.log", "sha256:e643283090b8e03ba8641689313a7ef39fea455be363b71ebd4d13c66a82b5ab", 356),
    ("04-r24d10_evaluator_self_test.log", "sha256:92c03f90e71f7a181d57a7f832145ecb080364daec4a810c41bb15e569116b92", 360),
    ("05-native_exact_step_evaluation.log", "sha256:af4f6912bccec47660d206d4372dd91bf67b791547ef7a87e33b347e450bb08d", 849),
    ("attempt.json", ATTEMPT_SHA, 1447),
    ("evaluation.json", EVALUATION_SHA, 64527),
    ("godot-physical-engine.log", "sha256:e5df886ba236f2a80dd811498e0e9a7ecb5d5574eb02527e7a35424ca12ecd24", 1357),
    ("godot-physical-stderr.log", "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", 0),
    ("godot-physical-stdout.log", "sha256:e5df886ba236f2a80dd811498e0e9a7ecb5d5574eb02527e7a35424ca12ecd24", 1357),
    ("project/project.godot", "sha256:4b94ffbfc8bd76374792ce5cff9c359da52d7252b12f84ddb0a24743c64e6833", 486),
    ("project/scripts/lab/rigs/r24d10_godot_jolt_exact_step_numerical_telemetry_rig.gd", "sha256:422a35f3ae917ca54ca67bee9fe023f9485b618f14b0e580c0c1121ad64489fb", 1905),
    ("project/scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd", "sha256:47a4d8ec969181a79fa3c849d8278674164b209a54075bb1549b0e1d0cdc4625", 10862),
    ("project/tests/test_sdk_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_worker.gd", "sha256:a182d2c73652b71159f2b9d2667c689c795d7a6ae8aed18584c5629b8697cf8d", 24913),
    ("project/tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd", "sha256:8bf00926b26d66c2916388ff1dbae1a774f019653a3c1b4d051173e35e2e6b25", 21798),
    ("raw-report.json", RAW_REPORT_SHA, 74970),
    ("receipt.json", RECEIPT_SHA, 202421),
]


def fail(code: str) -> NoReturn:
    raise SystemExit(f"QSDK-R24D10 physical characterization closure audit: {code}")


def exact(value: Any, expected: Any, code: str) -> None:
    if type(value) is not type(expected) or value != expected:
        fail(code)


def mapping(value: Any, code: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(code)
    return value


def sequence(value: Any, code: str) -> list[Any]:
    if not isinstance(value, list):
        fail(code)
    return value


def finite(value: Any, code: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        fail(code)
    result = float(value)
    if not math.isfinite(result):
        fail(code)
    return result


def reject_constant(value: str) -> NoReturn:
    fail(f"non_finite_json:{value}")


def load_json(path: Path) -> dict[str, Any]:
    try:
        return mapping(
            json.loads(path.read_text(encoding="utf-8"), parse_constant=reject_constant),
            f"json_object:{path}",
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        fail(f"json:{path}:{exc}")


def raw_receipt(path: Path) -> tuple[str, int]:
    try:
        payload = path.read_bytes()
    except OSError as exc:
        fail(f"file:{path}:{exc}")
    return "sha256:" + hashlib.sha256(payload).hexdigest(), len(payload)


def git(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    run = subprocess.run(
        ["git", "-C", str(ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    if check and run.returncode != 0:
        fail(f"git:{'_'.join(arguments)}:{run.stderr.strip()}")
    return run


def git_text(*arguments: str) -> str:
    return git(*arguments).stdout.strip()


def git_bytes(commit: str, relative: str) -> bytes:
    run = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{commit}:{relative}"],
        check=False,
        capture_output=True,
    )
    if run.returncode != 0:
        fail(f"git_show:{commit}:{relative}:{run.stderr.decode(errors='replace')}")
    return run.stdout


def find_cas_receipts(node: Any) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if isinstance(node, dict):
        if node.get("schema_version") == "sporespore_content_addressed_artifact_receipt_v1":
            found.append(node)
        for value in node.values():
            found.extend(find_cas_receipts(value))
    elif isinstance(node, list):
        for value in node:
            found.extend(find_cas_receipts(value))
    return found


def validate_closure(closure: dict[str, Any]) -> None:
    exact(
        closure.get("schema_version"),
        "sporespore_qsdk_r24d10_exact_step_numerical_telemetry_"
        "physical_characterization_closure_v1",
        "closure_schema",
    )
    exact(closure.get("closure_id"), "QSDK-R24D10-PH1-CLOSURE", "closure_id")
    exact(closure.get("gate_id"), "QSDK-R24D10", "closure_gate")
    exact(closure.get("question_class"), "development", "closure_question")
    exact(
        closure.get("status"),
        "complete_valid_finite_descriptive_native_exact_step_numerical_characterization",
        "closure_status",
    )
    exact(
        closure.get("result_class"),
        "valid_finite_descriptive_development_result",
        "closure_result_class",
    )
    if len(str(closure.get("scope", ""))) < 400:
        fail("closure_scope")

    source = mapping(closure.get("source"), "source")
    exact(source.get("repository_root"), ROOT.as_posix(), "source_root")
    exact(
        source.get("repository_remote"),
        "https://github.com/Slagathore/sporespore.git",
        "source_remote",
    )
    exact(source.get("branch"), "main", "source_branch")
    exact(source.get("authorization_commit"), AUTHORIZATION_COMMIT, "source_commit")
    exact(source.get("authorization_tree_git_oid"), AUTHORIZATION_TREE, "source_tree")
    exact(source.get("authorization_parent_commit"), FREEZE_COMMIT, "source_parent")
    exact(source.get("supervisor_freeze_commit"), FREEZE_COMMIT, "source_freeze")
    for key in (
        "clean_pushed_before_physical_attempt",
        "local_upstream_cached_live_equal_before_physical_attempt",
        "single_worktree",
    ):
        exact(source.get(key), True, f"source_{key}")
    exact(source.get("physical_supervisor_path"), SUPERVISOR_REL, "source_supervisor_path")
    exact(source.get("physical_supervisor_raw_sha256"), FROZEN_SOURCE[SUPERVISOR_REL][0], "source_supervisor_sha")
    exact(source.get("physical_supervisor_git_blob_oid"), FROZEN_SOURCE[SUPERVISOR_REL][2], "source_supervisor_blob")
    exact(source.get("physical_supervisor_manifest_raw_sha256"), FROZEN_SOURCE[MANIFEST_REL][0], "source_manifest_sha")
    exact(source.get("physical_supervisor_manifest_git_blob_oid"), FROZEN_SOURCE[MANIFEST_REL][2], "source_manifest_blob")

    qualification = mapping(closure.get("prerequisite_qualification"), "qualification")
    exact(qualification.get("source_commit"), FREEZE_COMMIT, "qualification_source")
    exact(qualification.get("run_root"), QUALIFICATION_ROOT.as_posix(), "qualification_root")
    exact(qualification.get("receipt_raw_sha256"), QUALIFICATION_RECEIPT_SHA, "qualification_receipt")
    exact(qualification.get("receipt_byte_length"), 91463, "qualification_receipt_bytes")
    exact(qualification.get("closure_path"), QUALIFICATION_CLOSURE_REL, "qualification_closure")
    exact(qualification.get("closure_raw_sha256"), QUALIFICATION_CLOSURE_SHA, "qualification_closure_sha")
    for key, expected in {
        "stage_count": 7,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
    }.items():
        exact(qualification.get(key), expected, f"qualification_{key}")
    exact(qualification.get("physical_authority"), False, "qualification_authority")

    authorization = mapping(closure.get("physical_authorization"), "authorization")
    exact(authorization.get("path"), AUTHORIZATION_REL, "authorization_path")
    exact(authorization.get("raw_sha256"), AUTHORIZATION_SHA, "authorization_sha")
    exact(authorization.get("authorization_parent_commit"), FREEZE_COMMIT, "authorization_parent")
    exact(authorization.get("authorization_commit_derived_from_current_head"), True, "authorization_derived")
    exact(authorization.get("authorization_json_contains_self_commit_identity"), False, "authorization_self")
    exact(authorization.get("production_authorization_only_check_observed_before_attempt"), True, "authorization_check")
    exact(authorization.get("physical_route_replayed_same_authorization_before_attempt"), True, "authorization_replay")
    exact(authorization.get("physical_attempt_limit"), 1, "authorization_limit")
    exact(authorization.get("physical_attempt_consumed"), True, "authorization_consumed")
    exact(authorization.get("same_source_rerun_allowed"), False, "authorization_rerun")

    runtime = mapping(closure.get("runtime"), "runtime")
    exact(runtime.get("profile_id"), "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2", "runtime_profile")
    exact(runtime.get("executed_console_binary_raw_sha256"), CONSOLE_SHA, "runtime_console")
    exact(runtime.get("executed_console_binary_byte_length"), 293376, "runtime_console_bytes")
    exact(runtime.get("executed_engine_binary_raw_sha256"), ENGINE_SHA, "runtime_engine")
    exact(runtime.get("executed_engine_binary_byte_length"), 188829184, "runtime_engine_bytes")
    exact(runtime.get("physics_engine"), "Jolt Physics", "runtime_engine_name")
    exact(runtime.get("physics_ticks_per_second"), 120, "runtime_ticks")
    exact(runtime.get("solver_velocity_steps"), 20, "runtime_velocity_steps")
    exact(runtime.get("solver_position_steps"), 7, "runtime_position_steps")
    exact(runtime.get("thread_model"), "single_safe", "runtime_thread")
    exact(runtime.get("retained_binary_pair_executed"), True, "runtime_pair")
    exact(runtime.get("result_reuse_authority"), False, "runtime_reuse")

    attempt = mapping(closure.get("physical_attempt"), "physical_attempt")
    exact(attempt.get("run_root"), RUN_ROOT.as_posix(), "attempt_root")
    exact(attempt.get("execution_nonce"), EXECUTION_NONCE, "attempt_nonce")
    for key, expected in {
        "attempt_raw_sha256": ATTEMPT_SHA,
        "raw_report_raw_sha256": RAW_REPORT_SHA,
        "raw_report_canonical_sha256": RAW_REPORT_CANONICAL_SHA,
        "evaluation_raw_sha256": EVALUATION_SHA,
        "receipt_raw_sha256": RECEIPT_SHA,
        "result": "complete_valid_finite_descriptive_native_exact_step_numerical_characterization",
    }.items():
        exact(attempt.get(key), expected, f"attempt_{key}")
    for key, expected in {
        "attempt_byte_length": 1447,
        "raw_report_byte_length": 74970,
        "evaluation_byte_length": 64527,
        "receipt_byte_length": 202421,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 20,
        "retained_sample_count": 68,
    }.items():
        exact(attempt.get(key), expected, f"attempt_{key}")
    exact(attempt.get("execution_valid"), True, "attempt_valid")
    exact(attempt.get("same_source_rerun_allowed"), False, "attempt_rerun")

    exact_step = mapping(closure.get("exact_step_execution"), "exact_step")
    exact(
        exact_step,
        {
            "space_step_sequence_initial_value": 0,
            "first_retained_space_step_sequence": 1,
            "last_retained_space_step_sequence": 20,
            "observed_retained_awake_space_step_token_count": 20,
            "token_derived_physics_step_count": 20,
            "pre_sample_physics_frame_count": 0,
            "extra_unretained_post_activation_step_count": 0,
            "all_declared_initial_real_t_projections_preserved": True,
            "terminal_physics_server_deactivation_count": 1,
        },
        "exact_step_vector",
    )
    summary = mapping(closure.get("descriptive_summary"), "summary")
    exact(
        summary,
        {
            "cell_count": 9,
            "retained_sample_count": 68,
            "current_numerical_aggregate_sample_count": 65,
            "sleeping_stale_excluded_sample_count": 3,
            "source_derived_hard_cap_observation_count": 65,
            "within_source_derived_hard_cap_count": 65,
            "maximum_absolute_impulse_residual_nms": 0.05999999679625034,
            "maximum_absolute_work_residual_j": 0.03599999602884063,
            "maximum_absolute_net_work_decomposition_residual_j": 0.0,
            "maximum_absolute_relative_angle_integral_residual_rad": 0.0,
            "descriptive_findings_are_acceptance_gates": False,
        },
        "summary_vector",
    )
    cell_summaries = sequence(closure.get("cell_observation_summary"), "cell_summary")
    exact([mapping(item, "cell_summary_item").get("cell_id") for item in cell_summaries], CELL_IDS, "cell_summary_order")
    for item_value in cell_summaries:
        item = mapping(item_value, "cell_summary_item")
        cell_id = str(item.get("cell_id"))
        family, samples, included, stale, impulse, work = EXPECTED_CELL_SHAPE[cell_id]
        exact(item.get("family"), family, f"cell_family:{cell_id}")
        exact(item.get("sample_count"), samples, f"cell_samples:{cell_id}")
        exact(item.get("included_count"), included, f"cell_included:{cell_id}")
        exact(item.get("stale_excluded_count"), stale, f"cell_stale:{cell_id}")
        exact(item.get("maximum_absolute_impulse_residual_nms"), impulse, f"cell_impulse:{cell_id}")
        exact(item.get("maximum_absolute_work_residual_j"), work, f"cell_work:{cell_id}")
        exact(item.get("all_included_samples_within_source_derived_hard_cap"), True, f"cell_cap:{cell_id}")

    interpretation = mapping(closure.get("interpretation"), "interpretation")
    for key in (
        "exact_fixture_native_numerical_telemetry_characterized",
        "all_source_derived_hard_cap_observations_within_cap",
        "braking_disabled_and_limit_residuals_preserved_as_observed",
        "result_authorizes_only_distinct_profile_promotion_decision_declaration",
    ):
        exact(interpretation.get(key), True, f"interpretation_{key}")
    for key in (
        "hard_cap_observation_is_numerical_accuracy_acceptance",
        "reported_motor_impulse_and_work_are_complete_joint_constraint_accounting",
        "threshold_or_margin_selected_from_result",
        "runtime_profile_promoted_from_result",
    ):
        exact(interpretation.get(key), False, f"interpretation_{key}")

    inventory = sequence(closure.get("physical_retained_inventory"), "inventory")
    exact(
        [
            (mapping(item, "inventory_item").get("path"), item.get("raw_sha256"), item.get("byte_length"))
            for item in inventory
        ],
        EXPECTED_INVENTORY,
        "inventory_vector",
    )
    retention = mapping(closure.get("retention"), "retention")
    for key, expected in {
        "physical_retained_file_count": 17,
        "physical_retained_total_byte_length": 408396,
        "physical_unique_content_digest_count": 16,
        "embedded_cas_reference_count": 25,
        "embedded_unique_cas_digest_count": 20,
    }.items():
        exact(retention.get(key), expected, f"retention_{key}")
    for key in (
        "receipt_cas_verified",
        "live_run_root_is_durable_convenience_copy",
        "content_addressed_and_git_bound_records_are_identity_authority",
    ):
        exact(retention.get(key), True, f"retention_{key}")

    statistics = mapping(closure.get("statistical_claim_boundary"), "statistics")
    for key in (
        "empirical_acceptance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "held_out_validation_cohort_count",
        "population_claim_count",
    ):
        exact(statistics.get(key), 0, f"statistics_{key}")
    if len(str(statistics.get("adequacy_argument", ""))) < 600:
        fail("statistics_adequacy")

    immutability = mapping(closure.get("immutability"), "immutability")
    for key in (
        "same_authorization_physical_rerun_forbidden",
        "same_source_repair_or_rerun_forbidden",
        "observed_threshold_retrofitting_forbidden",
        "observed_result_reinterpretation_forbidden",
        "retained_file_deletion_or_replacement_forbidden",
        "distinct_successor_required_for_profile_promotion_decision",
    ):
        exact(immutability.get(key), True, f"immutability_{key}")

    boundary = mapping(closure.get("next_boundary"), "next_boundary")
    exact(boundary.get("work"), "distinct_prospectively_declared_instrumented_profile_promotion_decision", "boundary_work")
    exact(boundary.get("question_class"), "finite_decision", "boundary_question")
    exact(boundary.get("declaration_authorized"), True, "boundary_declaration")
    for key in (
        "physical_execution_authorized",
        "instrumented_profile_promotion_authorized",
        "stock_profile_promotion_authorized",
        "recovery_world_authorized",
        "prone_to_standing_world_authorized",
    ):
        exact(boundary.get(key), False, f"boundary_{key}")

    claims = mapping(closure.get("claims"), "claims")
    for key in (
        "complete_zero_world_gate_passed",
        "production_authorization_only_check_passed",
        "physical_world_executed",
        "valid_finite_descriptive_development_result",
        "native_numerical_telemetry_characterized_for_exact_fixture",
    ):
        exact(claims.get(key), True, f"claim_{key}")
    for key in (
        "numerical_accuracy_accepted",
        "instrumented_profile_promoted",
        "stock_godot_profile_promoted",
        "recovery_world_opened",
        "prone_to_standing_world_opened",
        "turning_claim_changed",
        "cross_engine_equivalence_claimed",
        "q_sdk_r24_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claims.get(key), False, f"claim_{key}")
    exact(closure.get("closure_audit_path"), AUDIT_REL, "closure_audit_path")


def validate_git_authority() -> None:
    exact(git_text("rev-parse", f"{AUTHORIZATION_COMMIT}^{{tree}}"), AUTHORIZATION_TREE, "authorization_tree")
    parents = git_text("rev-list", "--parents", "-n", "1", AUTHORIZATION_COMMIT).split()
    exact(parents, [AUTHORIZATION_COMMIT, FREEZE_COMMIT], "authorization_parent_vector")
    exact(git_text("rev-parse", f"{FREEZE_COMMIT}^{{tree}}"), FREEZE_TREE, "freeze_tree")
    for relative, (sha, length, blob) in FROZEN_SOURCE.items():
        payload = git_bytes(AUTHORIZATION_COMMIT, relative)
        exact("sha256:" + hashlib.sha256(payload).hexdigest(), sha, f"source_sha:{relative}")
        exact(len(payload), length, f"source_bytes:{relative}")
        exact(git_text("rev-parse", f"{AUTHORIZATION_COMMIT}:{relative}"), blob, f"source_blob:{relative}")
        if relative != AUTHORIZATION_REL:
            exact(
                git_text("rev-parse", f"{AUTHORIZATION_COMMIT}:{relative}"),
                git_text("rev-parse", f"{FREEZE_COMMIT}:{relative}"),
                f"freeze_transition:{relative}",
            )
    authorization = mapping(json.loads(git_bytes(AUTHORIZATION_COMMIT, AUTHORIZATION_REL)), "authorization_json")
    exact(authorization.get("authorization_parent_commit"), FREEZE_COMMIT, "authorization_json_parent")
    exact(authorization.get("physical_attempt_limit"), 1, "authorization_json_limit")
    exact(authorization.get("same_source_rerun_allowed"), False, "authorization_json_rerun")
    exact(authorization.get("physical_execution_authorized"), True, "authorization_json_physical")
    for key in (
        "numerical_accuracy_accepted",
        "instrumented_profile_promoted",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(authorization.get(key), False, f"authorization_json_{key}")

    for retained_relative, source_relative in PROJECT_SOURCE_MAP.items():
        exact(
            (RUN_ROOT / retained_relative).read_bytes(),
            git_bytes(AUTHORIZATION_COMMIT, source_relative),
            f"retained_source_copy:{source_relative}",
        )


def validate_inventory_and_cas(closure: dict[str, Any], receipt: dict[str, Any]) -> None:
    inventory = sequence(closure.get("physical_retained_inventory"), "inventory")
    declared: dict[str, tuple[str, int]] = {}
    for item_value in inventory:
        item = mapping(item_value, "inventory_item")
        relative = str(item.get("path"))
        if relative in declared or relative.startswith(("/", "\\")) or ".." in Path(relative).parts:
            fail(f"inventory_path:{relative}")
        declared[relative] = (str(item.get("raw_sha256")), int(item.get("byte_length")))
    actual = sorted(
        path.relative_to(RUN_ROOT).as_posix()
        for path in RUN_ROOT.rglob("*")
        if path.is_file()
    )
    exact(sorted(declared), actual, "inventory_population")
    total = 0
    digests: set[str] = set()
    for relative in actual:
        observed = raw_receipt(RUN_ROOT / relative)
        exact(observed, declared[relative], f"inventory_receipt:{relative}")
        total += observed[1]
        digests.add(observed[0])
    exact(len(actual), 17, "inventory_count")
    exact(total, 408396, "inventory_bytes")
    exact(len(digests), 16, "inventory_unique")

    cas_receipts = find_cas_receipts(receipt)
    exact(len(cas_receipts), 25, "cas_reference_count")
    exact(len({str(item.get("sha256")) for item in cas_receipts}), 20, "cas_unique_count")
    for item in cas_receipts:
        sha = str(item.get("sha256"))
        if not sha.startswith("sha256:") or len(sha) != 71:
            fail("cas_digest_shape")
        length = item.get("byte_length")
        if isinstance(length, bool) or not isinstance(length, int) or length < 0:
            fail("cas_length")
        digest = sha[7:]
        payload = EVIDENCE_ROOT / "artifacts" / "sha256" / digest / "payload.bin"
        manifest = EVIDENCE_ROOT / "artifacts" / "sha256" / digest / "manifest.json"
        exact(raw_receipt(payload), (sha, length), f"cas_payload:{digest}")
        if not manifest.is_file():
            fail(f"cas_manifest:{digest}")
    receipt_payload = EVIDENCE_ROOT / "artifacts" / "sha256" / RECEIPT_SHA[7:] / "payload.bin"
    exact(raw_receipt(receipt_payload), (RECEIPT_SHA, 202421), "receipt_cas_payload")


def validate_attempt(attempt: dict[str, Any]) -> None:
    exact(attempt.get("schema_version"), "sporespore_qsdk_r24d10_physical_attempt_v2", "attempt_schema")
    exact(attempt.get("gate_id"), "QSDK-R24D10", "attempt_gate")
    exact(attempt.get("question_class"), "development", "attempt_question")
    exact(attempt.get("status"), "complete_valid_finite_descriptive_development_result", "attempt_status")
    exact(attempt.get("authorization_commit"), AUTHORIZATION_COMMIT, "attempt_commit")
    exact(attempt.get("authorization_parent_commit"), FREEZE_COMMIT, "attempt_parent")
    exact(attempt.get("authorization_sha256"), AUTHORIZATION_SHA, "attempt_authorization_sha")
    exact(attempt.get("supervisor_freeze_commit"), FREEZE_COMMIT, "attempt_freeze")
    exact(attempt.get("qualification_receipt_sha256"), QUALIFICATION_RECEIPT_SHA, "attempt_qualification")
    exact(attempt.get("qualification_closure_sha256"), QUALIFICATION_CLOSURE_SHA, "attempt_qualification_closure")
    exact(attempt.get("console_binary_sha256"), CONSOLE_SHA, "attempt_console")
    exact(attempt.get("engine_binary_sha256"), ENGINE_SHA, "attempt_engine")
    exact(attempt.get("execution_nonce"), EXECUTION_NONCE, "attempt_nonce")
    for key, expected in {
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 20,
        "retained_sample_count": 68,
        "worker_launch_count": 1,
    }.items():
        exact(attempt.get(key), expected, f"attempt_{key}")
    exact(attempt.get("same_source_rerun_allowed"), False, "attempt_rerun")
    exact(attempt.get("physical_acceptance_authority"), False, "attempt_acceptance")
    exact(attempt.get("release_authority"), False, "attempt_release")


def recompute_evaluation(raw: dict[str, Any], evaluation: dict[str, Any]) -> None:
    exact(raw.get("schema_version"), "sporespore_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_raw_report_v1", "raw_schema")
    exact(raw.get("gate_id"), "QSDK-R24D10", "raw_gate")
    exact(raw.get("question_class"), "development", "raw_question")
    exact(raw.get("evidence_kind"), "native_physical", "raw_kind")
    exact(raw.get("source_commit"), AUTHORIZATION_COMMIT, "raw_source")
    exact(raw.get("execution_nonce"), EXECUTION_NONCE, "raw_nonce")
    provenance = mapping(raw.get("evidence_provenance"), "raw_provenance")
    exact(provenance, {"native_physical_observation": True, "synthetic_shape_only": False}, "raw_provenance_vector")
    claims = mapping(raw.get("claims"), "raw_claims")
    exact(claims.get("descriptive_development_characterization_only"), True, "raw_descriptive")
    exact(claims.get("descriptive_findings_are_acceptance_gates"), False, "raw_gate_claim")
    for key in (
        "instrumented_profile_promoted",
        "numerical_accuracy_accepted",
        "physical_acceptance_authority",
        "prone_to_standing_claimed",
        "recovery_claimed",
        "release_authority",
        "stock_godot_profile_promoted",
        "turning_claim_changed",
        "cross_engine_equivalence_claimed",
    ):
        exact(claims.get(key), False, f"raw_claim_{key}")

    execution = mapping(raw.get("execution"), "raw_execution")
    for key, expected in {
        "world_attempt_count": 1,
        "world_build_count": 1,
        "physics_step_count": 20,
        "retained_sample_count": 68,
        "pre_sample_physics_frame_count": 0,
        "space_step_sequence_initial_value": 0,
        "first_retained_space_step_sequence": 1,
        "last_retained_space_step_sequence": 20,
        "observed_retained_awake_space_step_token_count": 20,
        "extra_unretained_post_activation_step_count": 0,
        "terminal_physics_server_deactivation_count": 1,
        "outcome_dependent_early_stop_count": 0,
    }.items():
        exact(execution.get(key), expected, f"raw_execution_{key}")
    exact(execution.get("physics_server_disabled_before_step_twenty_one"), True, "raw_deactivation")
    exact(
        execution.get("physics_step_count_source"),
        "max_retained_awake_read_space_step_sequence_minus_zero_initialized_space_step_sequence",
        "raw_step_source",
    )

    canonical = json.dumps(
        raw,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    exact("sha256:" + hashlib.sha256(canonical).hexdigest(), RAW_REPORT_CANONICAL_SHA, "raw_canonical_sha")

    raw_cells = sequence(raw.get("cells"), "raw_cells")
    evaluated_cells = sequence(evaluation.get("cells"), "evaluation_cells")
    exact([mapping(cell, "raw_cell").get("cell_id") for cell in raw_cells], CELL_IDS, "raw_cell_order")
    exact([mapping(cell, "evaluated_cell").get("cell_id") for cell in evaluated_cells], CELL_IDS, "evaluation_cell_order")
    recomputed_cells: list[dict[str, Any]] = []
    awake_tokens: set[int] = set()
    total_samples = 0
    included_count = 0
    stale_count = 0
    within_cap_count = 0
    max_impulse = 0.0
    max_work = 0.0
    max_decomposition = 0.0
    max_angle = 0.0
    for raw_cell_value in raw_cells:
        raw_cell = mapping(raw_cell_value, "raw_cell")
        cell_id = str(raw_cell.get("cell_id"))
        samples = sequence(raw_cell.get("samples"), f"raw_samples:{cell_id}")
        expected_sample_count = EXPECTED_CELL_SHAPE[cell_id][1]
        exact(len(samples), expected_sample_count, f"raw_sample_count:{cell_id}")
        first = mapping(samples[0], f"raw_first:{cell_id}")
        exact(first.get("pre_canonical_relative_rate_rad_s"), INITIAL_REAL_T_PROJECTION[cell_id], f"initial_projection:{cell_id}")
        prior_angle = 0.0
        recomputed_samples: list[dict[str, Any]] = []
        for step, raw_sample_value in enumerate(samples, start=1):
            sample = mapping(raw_sample_value, f"raw_sample:{cell_id}:{step}")
            telemetry = mapping(sample.get("telemetry"), f"telemetry:{cell_id}:{step}")
            exact(sample.get("step_index"), step, f"step_index:{cell_id}:{step}")
            exact(telemetry.get("read_space_step_sequence"), step, f"read_token:{cell_id}:{step}")
            if cell_id == "sleep_stale":
                exact(telemetry.get("capture_space_step_sequence"), 1, f"sleep_capture:{step}")
                exact(telemetry.get("telemetry_sequence"), 1, f"sleep_sequence:{step}")
                exact(telemetry.get("snapshot_is_current_space_step"), step == 1, f"sleep_current:{step}")
            else:
                exact(telemetry.get("capture_space_step_sequence"), step, f"capture_token:{cell_id}:{step}")
                exact(telemetry.get("telemetry_sequence"), step, f"telemetry_sequence:{cell_id}:{step}")
                exact(telemetry.get("snapshot_is_current_space_step"), True, f"snapshot_current:{cell_id}:{step}")
                awake_tokens.add(step)
            inertia = 1.0 / finite(sample.get("inverse_inertia_axis_kg_inv_m2"), "inverse_inertia")
            pre_rate = finite(sample.get("pre_canonical_relative_rate_rad_s"), "pre_rate")
            post_rate = finite(sample.get("post_canonical_relative_rate_rad_s"), "post_rate")
            dt = finite(telemetry.get("solver_step_s"), "solver_step_s")
            signed_impulse = finite(telemetry.get("signed_motor_impulse_nms"), "signed_impulse")
            positive_work = finite(telemetry.get("positive_motor_work_j"), "positive_work")
            absorbed_work = finite(telemetry.get("absorbed_motor_work_j"), "absorbed_work")
            net_work = finite(telemetry.get("net_motor_work_j"), "net_work")
            independent_impulse = inertia * (post_rate - pre_rate)
            independent_energy = 0.5 * inertia * (post_rate * post_rate - pre_rate * pre_rate)
            impulse_residual = signed_impulse - independent_impulse
            work_residual = net_work - independent_energy
            decomposition_residual = net_work - (positive_work - absorbed_work)
            cap = max(
                abs(finite(telemetry.get("min_torque_limit_nm"), "min_torque")),
                abs(finite(telemetry.get("max_torque_limit_nm"), "max_torque")),
            ) * dt
            recomputed_angle = prior_angle + 0.5 * (pre_rate + post_rate) * dt
            integrated_angle = finite(sample.get("integrated_canonical_angle_rad"), "integrated_angle")
            angle_residual = integrated_angle - recomputed_angle
            included = not (cell_id == "sleep_stale" and step > 1)
            if included:
                included_count += 1
                within_cap_count += int(abs(signed_impulse) <= cap)
                max_impulse = max(max_impulse, abs(impulse_residual))
                max_work = max(max_work, abs(work_residual))
                max_decomposition = max(max_decomposition, abs(decomposition_residual))
                max_angle = max(max_angle, abs(angle_residual))
            else:
                stale_count += 1
            recomputed_samples.append(
                {
                    "step_index": step,
                    "numerical_aggregate_included": included,
                    "snapshot_current": telemetry["snapshot_is_current_space_step"],
                    "effective_axis_inertia_kg_m2": inertia,
                    "independent_angular_momentum_change_nms": independent_impulse,
                    "independent_kinetic_energy_change_j": independent_energy,
                    "signed_motor_impulse_nms": signed_impulse,
                    "positive_motor_work_j": telemetry["positive_motor_work_j"],
                    "absorbed_motor_work_j": telemetry["absorbed_motor_work_j"],
                    "net_motor_work_j": net_work,
                    "impulse_residual_nms": impulse_residual,
                    "work_residual_j": work_residual,
                    "net_work_decomposition_residual_j": decomposition_residual,
                    "motor_impulse_cap_nms": cap,
                    "within_source_derived_hard_solver_cap": abs(signed_impulse) <= cap,
                    "relative_angle_integral_residual_rad": angle_residual,
                    "integrated_canonical_angle_rad": sample["integrated_canonical_angle_rad"],
                }
            )
            prior_angle = integrated_angle
            total_samples += 1
        recomputed_cells.append(
            {
                "cell_id": cell_id,
                "family": raw_cell["family"],
                "motor_enabled": raw_cell["motor_enabled"],
                "joint_limits_enabled": raw_cell["joint_limits_enabled"],
                "samples": recomputed_samples,
            }
        )
    exact(sorted(awake_tokens), list(range(1, 21)), "awake_token_population")
    exact(total_samples, 68, "recomputed_sample_count")
    exact(recomputed_cells, evaluated_cells, "recomputed_evaluation_cells")
    recomputed_summary = {
        "cell_count": 9,
        "retained_sample_count": 68,
        "current_numerical_aggregate_sample_count": included_count,
        "sleeping_stale_excluded_sample_count": stale_count,
        "source_derived_hard_cap_observation_count": included_count,
        "within_source_derived_hard_cap_count": within_cap_count,
        "maximum_absolute_impulse_residual_nms": max_impulse,
        "maximum_absolute_work_residual_j": max_work,
        "maximum_absolute_net_work_decomposition_residual_j": max_decomposition,
        "maximum_absolute_relative_angle_integral_residual_rad": max_angle,
    }
    exact(mapping(evaluation.get("summary"), "evaluation_summary"), recomputed_summary, "recomputed_summary")

    exact(evaluation.get("schema_version"), "sporespore_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_evaluation_v1", "evaluation_schema")
    exact(evaluation.get("ok"), True, "evaluation_ok")
    exact(evaluation.get("gate_id"), "QSDK-R24D10", "evaluation_gate")
    exact(evaluation.get("question_class"), "development", "evaluation_question")
    exact(evaluation.get("evidence_kind"), "native_physical", "evaluation_kind")
    exact(evaluation.get("result"), "complete_valid_finite_descriptive_native_exact_step_numerical_characterization", "evaluation_result")
    exact(evaluation.get("source_commit"), AUTHORIZATION_COMMIT, "evaluation_source")
    exact(evaluation.get("execution_nonce"), EXECUTION_NONCE, "evaluation_nonce")
    exact(evaluation.get("raw_report_canonical_sha256"), RAW_REPORT_CANONICAL_SHA, "evaluation_raw_sha")
    exact(evaluation.get("execution_valid"), True, "evaluation_valid")
    exact(evaluation.get("descriptive_findings_are_acceptance_gates"), False, "evaluation_gate_claim")
    for key in (
        "empirical_acceptance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "held_out_validation_cohort_count",
        "population_claim_count",
    ):
        exact(evaluation.get(key), 0, f"evaluation_{key}")
    exact(evaluation.get("native_numerical_telemetry_characterized"), True, "evaluation_characterized")
    for key in (
        "numerical_accuracy_accepted",
        "instrumented_profile_promoted",
        "recovery_claimed",
        "prone_to_standing_claimed",
        "turning_claim_changed",
        "cross_engine_equivalence_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(evaluation.get(key), False, f"evaluation_{key}")
    exact(
        mapping(evaluation.get("exact_step_execution"), "evaluation_exact_step"),
        {
            "space_step_sequence_initial_value": 0,
            "first_retained_space_step_sequence": 1,
            "last_retained_space_step_sequence": 20,
            "observed_retained_awake_space_step_token_count": 20,
            "token_derived_physics_step_count": 20,
            "pre_sample_physics_frame_count": 0,
            "extra_unretained_post_activation_step_count": 0,
            "all_declared_initial_real_t_projections_preserved": True,
        },
        "evaluation_exact_step_vector",
    )
    kernel = mapping(evaluation.get("numerical_kernel_provenance"), "evaluation_kernel")
    exact(kernel.get("raw_sha256"), FROZEN_SOURCE[KERNEL_REL][0], "evaluation_kernel_sha")
    exact(kernel.get("r24d9_result_reused_or_reinterpreted"), False, "evaluation_kernel_reuse")
    exact(kernel.get("kernel_invoked_only_after_r24d10_exact_step_validation"), True, "evaluation_kernel_order")


def validate_receipt(receipt: dict[str, Any]) -> None:
    exact(receipt.get("schema_version"), "sporespore_qsdk_r24d10_exact_step_numerical_telemetry_physical_receipt_v2", "receipt_schema")
    exact(receipt.get("ok"), True, "receipt_ok")
    exact(receipt.get("gate_id"), "QSDK-R24D10", "receipt_gate")
    exact(receipt.get("question_class"), "development", "receipt_question")
    exact(receipt.get("status"), "complete_valid_finite_descriptive_development_result", "receipt_status")
    source = mapping(receipt.get("source"), "receipt_source")
    exact(source.get("root"), ROOT.as_posix(), "receipt_root")
    exact(source.get("remote"), "https://github.com/Slagathore/sporespore.git", "receipt_remote")
    exact(source.get("branch"), "main", "receipt_branch")
    for key in ("head", "upstream", "cached_origin_main", "live_origin_main"):
        exact(source.get(key), AUTHORIZATION_COMMIT, f"receipt_{key}")
    exact(source.get("worktree_count"), 1, "receipt_worktrees")
    exact(source.get("worktree_clean"), True, "receipt_clean")
    authorization = mapping(receipt.get("authorization"), "receipt_authorization")
    exact(mapping(authorization.get("file"), "authorization_file").get("raw_sha256"), AUTHORIZATION_SHA, "receipt_authorization_sha")
    exact(mapping(authorization.get("value"), "authorization_value").get("authorization_parent_commit"), FREEZE_COMMIT, "receipt_authorization_parent")
    exact(mapping(authorization.get("value"), "authorization_value").get("physical_attempt_limit"), 1, "receipt_authorization_limit")
    exact(mapping(receipt.get("validation_manifest"), "receipt_manifest").get("raw_sha256"), FROZEN_SOURCE[MANIFEST_REL][0], "receipt_manifest_sha")
    qualification = mapping(receipt.get("prerequisite_qualification"), "receipt_qualification")
    exact(mapping(qualification.get("receipt"), "qualification_receipt").get("raw_sha256"), QUALIFICATION_RECEIPT_SHA, "receipt_qualification_sha")
    qualification_closure = mapping(receipt.get("prerequisite_qualification_closure"), "receipt_qualification_closure")
    exact(mapping(qualification_closure.get("file"), "qualification_closure_file").get("raw_sha256"), QUALIFICATION_CLOSURE_SHA, "receipt_qualification_closure_sha")
    binary = mapping(receipt.get("binary_pair"), "receipt_binary")
    exact(mapping(binary.get("console"), "receipt_console").get("raw_sha256"), CONSOLE_SHA, "receipt_console_sha")
    exact(mapping(binary.get("engine"), "receipt_engine").get("raw_sha256"), ENGINE_SHA, "receipt_engine_sha")
    exact(binary.get("executed_retained_pair"), True, "receipt_pair_executed")
    exact(binary.get("precise_reuse_of_exact_qualified_pair"), True, "receipt_pair_exact")
    stages = sequence(receipt.get("stages"), "receipt_stages")
    exact([mapping(item, "receipt_stage").get("name") for item in stages], ORDERED_STAGES, "receipt_stage_order")
    exact(
        mapping(receipt.get("actual_counts"), "receipt_counts"),
        {
            "world_attempt_count": 1,
            "world_build_count": 1,
            "solver_step_count": 20,
            "retained_sample_count": 68,
        },
        "receipt_count_vector",
    )
    claims = mapping(receipt.get("claims"), "receipt_claims")
    exact(claims.get("native_numerical_telemetry_characterized"), True, "receipt_characterized")
    exact(claims.get("exact_step_schedule_observed"), True, "receipt_exact_step")
    for key in (
        "numerical_accuracy_accepted",
        "instrumented_profile_promoted",
        "stock_godot_profile_promoted",
        "recovery_world_opened",
        "prone_to_standing_world_opened",
        "turning_claim_changed",
        "cross_engine_equivalence_claimed",
        "q_sdk_r24_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claims.get(key), False, f"receipt_claim_{key}")


def validate_single_attempt() -> None:
    physical_root = EVIDENCE_ROOT / "qsdk-r24d10-exact-step-numerical-telemetry" / "physical"
    matching: list[Path] = []
    for path in physical_root.glob("*/attempt.json"):
        attempt = load_json(path)
        if (
            attempt.get("authorization_commit") == AUTHORIZATION_COMMIT
            and attempt.get("authorization_sha256") == AUTHORIZATION_SHA
        ):
            matching.append(path.resolve())
    exact(len(matching), 1, "same_authorization_attempt_count")
    exact(matching[0], (RUN_ROOT / "attempt.json").resolve(), "same_authorization_attempt_path")


def validate_publication(*, allow_prospective_uncommitted: bool) -> None:
    if allow_prospective_uncommitted:
        return
    exact(git_text("status", "--short"), "", "worktree_clean")
    closure_commits = git_text("log", "--diff-filter=A", "--format=%H", "--", CLOSURE_REL).splitlines()
    audit_commits = git_text("log", "--diff-filter=A", "--format=%H", "--", AUDIT_REL).splitlines()
    exact(len(closure_commits), 1, "closure_publication_count")
    exact(audit_commits, closure_commits, "audit_publication_commit")
    publication = closure_commits[0]
    exact(
        git_text("rev-list", "--parents", "-n", "1", publication).split(),
        [publication, AUTHORIZATION_COMMIT],
        "publication_parent_vector",
    )
    for relative in (CLOSURE_REL, AUDIT_REL):
        exact(
            git_text("rev-parse", f"{publication}:{relative}"),
            git_text("rev-parse", f"HEAD:{relative}"),
            f"publication_immutable:{relative}",
        )
    for relative in FROZEN_SOURCE:
        exact(
            git_text("rev-parse", f"{publication}:{relative}"),
            git_text("rev-parse", f"{AUTHORIZATION_COMMIT}:{relative}"),
            f"publication_frozen_source:{relative}",
        )


def mutation_controls(closure: dict[str, Any]) -> int:
    mutations: list[tuple[tuple[Any, ...], Any]] = [
        (("question_class",), "finite_decision"),
        (("status",), "accepted"),
        (("source", "authorization_commit"), FREEZE_COMMIT),
        (("source", "authorization_tree_git_oid"), FREEZE_TREE),
        (("prerequisite_qualification", "world_attempt_count"), 1),
        (("physical_authorization", "physical_attempt_limit"), 2),
        (("physical_authorization", "same_source_rerun_allowed"), True),
        (("physical_attempt", "solver_step_count"), 21),
        (("physical_attempt", "retained_sample_count"), 67),
        (("exact_step_execution", "first_retained_space_step_sequence"), 2),
        (("exact_step_execution", "last_retained_space_step_sequence"), 21),
        (("descriptive_summary", "current_numerical_aggregate_sample_count"), 68),
        (("descriptive_summary", "maximum_absolute_impulse_residual_nms"), 0.0),
        (("interpretation", "hard_cap_observation_is_numerical_accuracy_acceptance"), True),
        (("interpretation", "reported_motor_impulse_and_work_are_complete_joint_constraint_accounting"), True),
        (("physical_retained_inventory", 0, "byte_length"), 358),
        (("retention", "embedded_cas_reference_count"), 24),
        (("statistical_claim_boundary", "empirical_acceptance_threshold_count"), 1),
        (("immutability", "same_source_repair_or_rerun_forbidden"), False),
        (("next_boundary", "question_class"), "development"),
        (("next_boundary", "physical_execution_authorized"), True),
        (("claims", "numerical_accuracy_accepted"), True),
        (("claims", "instrumented_profile_promoted"), True),
        (("claims", "prone_to_standing_world_opened"), True),
        (("claims", "release_authority"), True),
    ]
    rejected = 0
    for path, replacement in mutations:
        candidate: Any = copy.deepcopy(closure)
        target: Any = candidate
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = replacement
        try:
            validate_closure(mapping(candidate, "mutation_candidate"))
        except SystemExit:
            rejected += 1
        else:
            fail(f"mutation_accepted:{'.'.join(str(item) for item in path)}")
    return rejected


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-prospective-uncommitted", action="store_true")
    args = parser.parse_args()
    exact(Path(git_text("rev-parse", "--show-toplevel")).resolve(), ROOT.resolve(), "root")
    exact(
        git_text("remote", "get-url", "origin"),
        "https://github.com/Slagathore/sporespore.git",
        "remote",
    )
    exact(raw_receipt(ROOT / CLOSURE_REL), (CLOSURE_SHA, 15715), "closure_file")
    exact(raw_receipt(ROOT / AUTHORIZATION_REL), (AUTHORIZATION_SHA, 2804), "authorization_file")
    exact(raw_receipt(ROOT / QUALIFICATION_CLOSURE_REL), (QUALIFICATION_CLOSURE_SHA, 9297), "qualification_closure_file")
    exact(raw_receipt(QUALIFICATION_ROOT / "receipt.json"), (QUALIFICATION_RECEIPT_SHA, 91463), "qualification_receipt_file")
    exact(raw_receipt(RUN_ROOT / "attempt.json"), (ATTEMPT_SHA, 1447), "attempt_file")
    exact(raw_receipt(RUN_ROOT / "raw-report.json"), (RAW_REPORT_SHA, 74970), "raw_report_file")
    exact(raw_receipt(RUN_ROOT / "evaluation.json"), (EVALUATION_SHA, 64527), "evaluation_file")
    exact(raw_receipt(RUN_ROOT / "receipt.json"), (RECEIPT_SHA, 202421), "receipt_file")

    closure = load_json(ROOT / CLOSURE_REL)
    attempt = load_json(RUN_ROOT / "attempt.json")
    raw = load_json(RUN_ROOT / "raw-report.json")
    evaluation = load_json(RUN_ROOT / "evaluation.json")
    receipt = load_json(RUN_ROOT / "receipt.json")
    validate_closure(closure)
    validate_git_authority()
    validate_attempt(attempt)
    recompute_evaluation(raw, evaluation)
    validate_receipt(receipt)
    validate_inventory_and_cas(closure, receipt)
    validate_single_attempt()
    validate_publication(allow_prospective_uncommitted=args.allow_prospective_uncommitted)
    rejected = mutation_controls(closure)
    print(
        "QSDK_R24D10_EXACT_STEP_NUMERICAL_TELEMETRY_PHYSICAL_"
        "CHARACTERIZATION_CLOSURE_PASS "
        f"source={AUTHORIZATION_COMMIT[:8]} cells=9 samples=68 "
        f"current_samples=65 stale_excluded=3 files=17 unique_digests=16 "
        f"cas_refs=25 cas_unique=20 mutations={rejected} "
        "worlds=0 builds=0 solver_steps=0 physical_attempts=1 "
        "accuracy_accepted=false profile_promoted=false "
        "physical_acceptance_authority=false release=false"
    )


if __name__ == "__main__":
    main()
