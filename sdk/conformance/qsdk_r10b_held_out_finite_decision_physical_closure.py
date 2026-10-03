#!/usr/bin/env python3
"""Audit the consumed QSDK-R10B held-out decision without opening a world."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
from typing import Any

import qsdk_r10b_development_route_ghost_physical_closure as common


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
EVIDENCE_ROOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    r"\qsdk-r10b-held-out-finite-decision-physical-ce048f2b8390"
)
QUALIFICATION_ROOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    r"\qsdk-r10b-held-out-finite-decision-zero-world-qualification-132063a58ab6"
)
CLOSURE_PATH = ROOT / "sdk/qsdk_r10b_held_out_finite_decision_physical_closure_v1.json"
SOURCE_COMMIT = "ce048f2b83903c04190b5ad226f1b4f12953a252"
DEVELOPMENT_CLOSURE_COMMIT = "132063a58ab6f561fe8bec256fadcdde9a736365"
STAGE_COMMIT = "7389c067a34eb203cd45551f35bf387fd796676c"
AUTHORITY_COMMIT = "eb23cac8c534a31de98fdbcf83defa40377ac6d7"
CAMPAIGN_ID = "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-VALIDATION"
CELL_MARKER = "QSDK_R10B_PHYSICAL_CELL "
PASS_MARKER = "QSDK_R10B_HELD_OUT_FINITE_DECISION_PHYSICAL_CLOSURE_PASS "
PHYSICAL_MANIFEST_SHA256 = (
    "sha256:5fb5b1f1ab1b68baea8a9c4f25dd8a95cdbf8e8bde11ce2892e0de605a5ec850"
)
QUALIFICATION_MANIFEST_SHA256 = (
    "sha256:83982a89923ed411c86ea4af0685f0ea9bc44069c420fa0ea9ad0c6b794eec80"
)

CELL_SPECS: dict[str, dict[str, Any]] = {
    "baseline_s50301": {
        "arm": "matched_no_impulse_control",
        "seed": 50301,
        "rows": 2715,
        "raw": "sha256:25295042f920ed70a08e6577d1eecca670c48f32d52cfc94abb5ff5e0096d350",
        "canonical": "sha256:83898ce4efa9a151afd1d124efc8f4b9d20fa6675ca7cfcc8edf835392688acf",
        "evaluation": "sha256:4b7aa0598085251869535ac186a75f5ea4c9fa20ac9d8372a363faef78754dd9",
        "trace": "sha256:ce669d8e37cb9642076ef1fa4a8b1cfbaedb23c99371ed94b7d06e549821b411",
        "initial": "sha256:779c5e73a91b2f73fb20864fccdfe79927dfd86f73e32635f94ee1236eb98305",
        "pre_advance": 0.16087616980075836,
        "failed_limbs": ["front_left"],
        "post_advance": 0.15594150125980377,
        "effect": 0.0,
    },
    "push_s50301": {
        "arm": "lateral_upright_impulse",
        "seed": 50301,
        "rows": 2661,
        "raw": "sha256:8bf98904f0db7fab23656ca9d5feb74d8625ad3ac8311e3482752537cc3c4e8a",
        "canonical": "sha256:2e2e1e1a96a565c06191c3c5a02cf1359a0ca87f89763c23338b17f439911e75",
        "evaluation": "sha256:fb13a028a66b04a8dd62d88b90bff92390bb9865d1c67790d92751d56134eb12",
        "trace": "sha256:b509f1c8020975149f87500e327e40a389f870ed0222b4c31567cc0fd8957bf4",
        "initial": "sha256:779c5e73a91b2f73fb20864fccdfe79927dfd86f73e32635f94ee1236eb98305",
        "pre_advance": 0.16087616980075836,
        "failed_limbs": ["front_left"],
        "recovery_advance": 0.14110228419303894,
        "effect": 0.05630834400653839,
    },
    "baseline_s50302": {
        "arm": "matched_no_impulse_control",
        "seed": 50302,
        "rows": 2727,
        "raw": "sha256:398acf0a0c4f32fc979c0b84fe8c6f4676e55dfa8290d4d61ddf0f34e49b6319",
        "canonical": "sha256:04a66b67ebd250e1e6e5bf91352c30e66481ef09e7d2cfe83d3b2d8e46771607",
        "evaluation": "sha256:912306861ff1031591b628a2596af02dd0970e02b03487148db4601a85985f94",
        "trace": "sha256:4dca1918645c93ddf3be99c11eed58451b1519375a42f0dae04474283fd92776",
        "initial": "sha256:3425768374b8bb33fd94b5c1a2b024e2de9d20d4ce21c4d17619a46ef8110a68",
        "pre_advance": 0.1606803983449936,
        "failed_limbs": ["front_left", "front_right"],
        "post_advance": 0.23721948266029358,
        "effect": 0.0,
    },
    "push_s50302": {
        "arm": "lateral_upright_impulse",
        "seed": 50302,
        "rows": 2660,
        "raw": "sha256:a3fb5c5b0d06d6e8529b86596927b3de1ee5f667802cfd15c013adf8b22c1664",
        "canonical": "sha256:e1123b21db1dd1f622be831a383e5d4d0c6c343c308cade5c9ec509170c2dcc5",
        "evaluation": "sha256:b8af04a6d673042d61c1ac533f522dfcde702884a7613fc7d605f6bfb131a9e4",
        "trace": "sha256:4f7c6d6f18b1b1ba8e796406a31847c860b3b2224cba322ca23503f96445daa3",
        "initial": "sha256:3425768374b8bb33fd94b5c1a2b024e2de9d20d4ce21c4d17619a46ef8110a68",
        "pre_advance": 0.1606803983449936,
        "failed_limbs": ["front_left", "front_right"],
        "recovery_advance": 0.16813455522060394,
        "effect": 0.04133891686797142,
    },
    "baseline_s50303": {
        "arm": "matched_no_impulse_control",
        "seed": 50303,
        "rows": 2698,
        "raw": "sha256:c65b9fd5f2d1413992d8f024b372dd6abc4d119b32778f6c2aea6d077f5602d0",
        "canonical": "sha256:9b60c8e9e707f850daa581922278cabfb7fc712c067b0bb8662b6987acf2eeef",
        "evaluation": "sha256:5ff4b485f47c548bd473081a2dea6b12f454b044fb49d7a3e109d79138bbad85",
        "trace": "sha256:640b5deed8882c42a3a21c4836ff71d559e6539adaee0294e81804f6a1f927a9",
        "initial": "sha256:230a95821ee4e57c0684ef05af1c2d49b557035a8abc50d1ee23e73323226db2",
        "pre_advance": 0.1312842071056366,
        "failed_limbs": ["front_left"],
        "post_advance": 0.15395283699035645,
        "effect": 0.0,
    },
    "push_s50303": {
        "arm": "lateral_upright_impulse",
        "seed": 50303,
        "rows": 2854,
        "raw": "sha256:c92ae3a0a08028b43551bf89afd070301e15b79aae3310ab71e4c1564dcfa2dd",
        "canonical": "sha256:3493620a1dfd17a886941b0ea58491ee9497a9982962019b94dd6a6b4dc210f3",
        "evaluation": "sha256:feac7c7c4ac5e4c0fc5660cb6ddd26bd185bc7813c482ec09be52a6ea51ccc3e",
        "trace": "sha256:a2776099fe35ec97de1ad44e82cc66d8fc19f782cfa815eb2c0fc215838bdd76",
        "initial": "sha256:230a95821ee4e57c0684ef05af1c2d49b557035a8abc50d1ee23e73323226db2",
        "pre_advance": 0.1312842071056366,
        "failed_limbs": ["front_left"],
        "recovery_advance": 0.14334970712661743,
        "effect": 0.04132305458188057,
    },
}

PAIR_SPECS = {
    50301: {
        "raw": "sha256:f635220ece03f0f85eaf650651ac08ad171e3052e876aa0fca5d6047b658aaa1",
        "native_effect_magnitude_m_s": 0.05630834400653839,
        "baseline_lateral_velocity_jump_m_s": -0.007432072423398495,
        "push_lateral_velocity_jump_m_s": 0.0560254342854023,
        "paired_lateral_velocity_jump_difference_m_s": 0.06345750670880079,
    },
    50302: {
        "raw": "sha256:ac75446caf4af1ad4388b0005b25999fe947060cf6c7c7d17de7564fe20bbd0e",
        "native_effect_magnitude_m_s": 0.04133891686797142,
        "baseline_lateral_velocity_jump_m_s": -0.022762037813663483,
        "push_lateral_velocity_jump_m_s": 0.04056607931852341,
        "paired_lateral_velocity_jump_difference_m_s": 0.06332811713218689,
    },
    50303: {
        "raw": "sha256:4ba108d5dad1c7db7aeb8b3a8d025fd43d2514be458217829ac859fae509ac65",
        "native_effect_magnitude_m_s": 0.04132305458188057,
        "baseline_lateral_velocity_jump_m_s": -0.022319510579109192,
        "push_lateral_velocity_jump_m_s": 0.0411054901778698,
        "paired_lateral_velocity_jump_difference_m_s": 0.06342500075697899,
    },
}


def require(condition: bool, code: str) -> None:
    common.require(condition, code)


def hash_object(value: Any) -> str:
    return common.sha256_bytes(common.canonical_bytes(value))


def commit_paths(commit: str) -> list[str]:
    output = str(
        common.git(("diff-tree", "--no-commit-id", "--name-only", "-r", commit))
    )
    return output.splitlines() if output else []


def validate_repository() -> None:
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "WRONG_SCRIPT_ROOT")
    require(
        Path(str(common.git(("rev-parse", "--show-toplevel")))).resolve()
        == EXPECTED_ROOT.resolve(),
        "WRONG_GIT_ROOT",
    )
    require(
        common.git(("remote", "get-url", "origin")) == EXPECTED_REMOTE,
        "WRONG_REMOTE",
    )


def validate_source_graph(closure: dict[str, Any]) -> None:
    graph = closure.get("source_graph")
    require(isinstance(graph, dict), "SOURCE_GRAPH_MISSING")
    require(
        graph.get("implementation_source") == common.commit_identity(SOURCE_COMMIT),
        "SOURCE_IDENTITY_DRIFT",
    )
    dev_path = "sdk/qsdk_r10b_development_route_ghost_physical_closure_v1.json"
    dev_audit_path = (
        "sdk/conformance/qsdk_r10b_development_route_ghost_physical_closure.py"
    )
    expected_dev = {
        **common.commit_identity(DEVELOPMENT_CLOSURE_COMMIT),
        **common.committed_file_identity(DEVELOPMENT_CLOSURE_COMMIT, dev_path),
        "route_execution_valid": True,
    }
    require(
        graph.get("development_route_closure") == expected_dev,
        "DEVELOPMENT_CLOSURE_DRIFT",
    )
    require(
        graph.get("development_route_closure_audit")
        == common.committed_file_identity(
            DEVELOPMENT_CLOSURE_COMMIT,
            dev_audit_path,
            blob_key="git_blob_oid_at_development_closure_commit",
        ),
        "DEVELOPMENT_AUDIT_DRIFT",
    )
    current_development_audit = ROOT / dev_audit_path
    require(
        Path(common.__file__).resolve() == current_development_audit.resolve()
        and common.sha256_bytes(current_development_audit.read_bytes())
        == graph["development_route_closure_audit"]["raw_sha256"],
        "IMPORTED_DEVELOPMENT_AUDIT_DRIFT",
    )
    require(
        set(commit_paths(DEVELOPMENT_CLOSURE_COMMIT)) == {dev_path, dev_audit_path},
        "DEVELOPMENT_CLOSURE_COMMIT_SCOPE",
    )
    stage_path = (
        "sdk/qsdk_r10b_held_out_finite_decision_"
        "zero_world_qualification_closure_v4.json"
    )
    expected_stage = {
        **common.commit_identity(STAGE_COMMIT),
        **common.committed_file_identity(STAGE_COMMIT, stage_path),
    }
    require(graph.get("stage_freeze") == expected_stage, "STAGE_IDENTITY_DRIFT")
    require(commit_paths(STAGE_COMMIT) == [stage_path], "STAGE_COMMIT_SCOPE")
    authority_path = (
        "sdk/qsdk_r10b_held_out_finite_decision_execution_authority_v4.json"
    )
    expected_authority = {
        **common.commit_identity(AUTHORITY_COMMIT),
        **common.committed_file_identity(AUTHORITY_COMMIT, authority_path),
    }
    require(
        graph.get("execution_authority") == expected_authority,
        "AUTHORITY_IDENTITY_DRIFT",
    )
    require(
        commit_paths(AUTHORITY_COMMIT) == [authority_path], "AUTHORITY_COMMIT_SCOPE"
    )


def validate_qualification(closure: dict[str, Any]) -> None:
    boundary = closure.get("zero_world_authorization_boundary")
    require(isinstance(boundary, dict), "QUALIFICATION_BOUNDARY_MISSING")
    files = common.tree_manifest(QUALIFICATION_ROOT)
    manifest = common.canonical_bytes(files)
    require(len(files) == 5, "QUALIFICATION_FILE_COUNT")
    require(
        sum(int(item["byte_length"]) for item in files) == 17_994,
        "QUALIFICATION_TOTAL_BYTES",
    )
    require(len(manifest) == 701, "QUALIFICATION_MANIFEST_BYTES")
    require(
        common.sha256_bytes(manifest) == QUALIFICATION_MANIFEST_SHA256,
        "QUALIFICATION_MANIFEST_SHA",
    )
    require(
        boundary.get("qualification_files") == files
        and boundary.get("qualification_file_count") == 5
        and boundary.get("qualification_total_byte_length") == 17_994
        and boundary.get("qualification_tree_manifest_canonical_byte_length") == 701
        and boundary.get("qualification_tree_manifest_sha256")
        == QUALIFICATION_MANIFEST_SHA256,
        "QUALIFICATION_CLOSURE_MANIFEST",
    )
    require(
        Path(str(boundary.get("official_qualification_evidence_root"))).resolve()
        == QUALIFICATION_ROOT.resolve(),
        "QUALIFICATION_ROOT",
    )
    attempt = common.read_json(
        QUALIFICATION_ROOT / "qualification_attempt.json", "QUALIFICATION_ATTEMPT"
    )
    completion = common.read_json(
        QUALIFICATION_ROOT / "qualification_completion.json",
        "QUALIFICATION_COMPLETION",
    )
    receipt = common.read_json(
        QUALIFICATION_ROOT / "qualification_receipt.json", "QUALIFICATION_RECEIPT"
    )
    require(
        attempt.get("campaign_role") == "held_out_finite_decision"
        and attempt.get("question_class") == "finite decision"
        and attempt.get("maximum_world_count") == 6
        and attempt.get("official_qualification_attempt_count_for_source_and_role") == 1
        and attempt.get("source", {}).get("commit") == DEVELOPMENT_CLOSURE_COMMIT
        and attempt.get("physical_execution_authorized") is False,
        "QUALIFICATION_ATTEMPT",
    )
    require(
        completion.get("status") == "complete_valid_official_zero_world_qualification"
        and completion.get("campaign_role") == "held_out_finite_decision"
        and completion.get("official_zero_world_qualification_passed") is True
        and completion.get("physical_execution_authorized") is False
        and completion.get("physical_acceptance_authority") is False
        and completion.get("release_authority") is False,
        "QUALIFICATION_COMPLETION",
    )
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10b_zero_world_implementation_audit_v4"
        and receipt.get("source_commit") == DEVELOPMENT_CLOSURE_COMMIT
        and receipt.get("ok") is True
        and receipt.get("qualified_source_path_count") == 85
        and receipt.get("qualified_source_path_sha256")
        == "sha256:4bfe0e8a7cbdb920655cb3082b6e2a7182f4f05ac76e24142a73acca640a7a8d",
        "QUALIFICATION_RECEIPT",
    )
    for counter in common.ZERO_COUNTERS:
        require(receipt.get(counter) == 0, f"QUALIFICATION_NONZERO_{counter.upper()}")
        require(
            boundary.get(f"authority_check_{counter}") == 0,
            f"AUTHORITY_CHECK_NONZERO_{counter.upper()}",
        )
    require(
        receipt.get("locomotion_outcome_exposure_count") == 0
        and receipt.get("physics_state_modified") is False
        and boundary.get("official_qualification_passed") is True
        and boundary.get("committed_graph_authority_check_passed") is True
        and boundary.get("authority_check_output_root_absent") is True
        and boundary.get("authority_check_locomotion_outcome_exposure_count") == 0,
        "QUALIFICATION_ZERO_WORLD_BOUNDARY",
    )


def validate_closure_contract(closure: dict[str, Any]) -> None:
    require(
        closure.get("schema_version")
        == "sporespore_qsdk_r10b_held_out_finite_decision_physical_closure_v1"
        and closure.get("status") == "closed_consumed_valid_complete_finite_negative"
        and closure.get("gate_id") == "QSDK-R10B"
        and closure.get("closure_id") == "QSDK-R10B-H1"
        and closure.get("campaign_id") == CAMPAIGN_ID
        and closure.get("campaign_role") == "held_out_finite_decision"
        and closure.get("question_class") == "finite decision",
        "CLOSURE_IDENTITY",
    )
    require(
        closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("evidence_valid") is True
        and closure.get("outcome_complete") is True
        and closure.get("behavior_passed") is False,
        "CLOSURE_RESULT",
    )
    require(
        closure.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "retained_consumed_physical_finite_decision_closure",
            "question_class": "finite decision",
        },
        "CLOSURE_LEDGER_SCOPE",
    )
    declared = closure.get("declared_question")
    require(
        isinstance(declared, dict)
        and declared.get("exact_finite_population") is True
        and declared.get("campaign_seeds") == [50301, 50302, 50303]
        and declared.get("ordered_cell_ids") == list(CELL_SPECS)
        and declared.get("maximum_campaign_attempt_count") == 1
        and declared.get("maximum_world_count") == 6
        and declared.get("all_cells_run_regardless_of_intermediate_behavior") is True
        and declared.get("acceptance_requires_every_cell_and_pair_behavior_pass")
        is True
        and declared.get(
            "pooling_averaging_replacement_or_same_identity_rerun_permitted"
        )
        is False
        and declared.get("superiority_question_declared") is False
        and declared.get("equivalence_or_non_inferiority_question_declared") is False
        and declared.get("population_inference_declared") is False,
        "CLOSURE_DECLARED_QUESTION",
    )
    physical = closure.get("physical_attempt")
    require(isinstance(physical, dict), "CLOSURE_PHYSICAL_MISSING")
    require(
        Path(str(physical.get("evidence_root"))).resolve() == EVIDENCE_ROOT.resolve()
        and physical.get("campaign_attempt_count") == 1
        and physical.get("physical_identity_consumed") is True
        and physical.get("same_identity_rerun_permitted") is False
        and physical.get("same_identity_requalification_permitted") is False
        and physical.get("attempted_cell_count") == 6
        and physical.get("completed_valid_cell_count") == 6
        and physical.get("unattempted_cell_count") == 0
        and physical.get("world_attempt_count") == 6
        and physical.get("world_build_count") == 6
        and physical.get("world_reset_count") == 0
        and physical.get("pair_count") == 3
        and physical.get("campaign_report_count") == 1
        and physical.get("external_push_application_count") == 3
        and physical.get("retained_trace_row_count") == 16_315
        and physical.get("recorded_physics_tick_count") == 17_755,
        "CLOSURE_PHYSICAL_COUNTS",
    )
    aggregate = closure.get("aggregate_result")
    require(
        isinstance(aggregate, dict)
        and aggregate.get("classification") == "valid_complete_exact_finite_negative"
        and aggregate.get("valid_complete_cell_count") == 6
        and aggregate.get("valid_complete_pair_count") == 3
        and aggregate.get("ordinary_walking_pass_count") == 0
        and aggregate.get("bounded_anchor_error_failure_count") == 6
        and aggregate.get("all_other_walking_receipt_failure_count") == 0
        and aggregate.get("pre_push_window_pass_count") == 0
        and aggregate.get("pre_push_safe_envelope_pass_count") == 6
        and aggregate.get("pre_push_forward_advance_pass_count") == 6
        and aggregate.get("pre_push_command_application_pass_count") == 6
        and aggregate.get("matched_pair_pre_push_window_identity_count") == 3
        and aggregate.get("baseline_post_marker_window_pass_count") == 3
        and aggregate.get("push_recovery_window_found_count") == 3
        and aggregate.get("immediate_reentry_count") == 3
        and aggregate.get("native_push_application_count") == 3
        and aggregate.get("native_effect_confirmed_pair_count") == 3
        and aggregate.get("cell_behavior_pass_count") == 0
        and aggregate.get("pair_behavior_pass_count") == 0
        and aggregate.get("overall_behavior_passed") is False,
        "CLOSURE_AGGREGATE",
    )
    decision = closure.get("decision")
    require(
        isinstance(decision, dict)
        and decision.get("result") == "consumed_valid_complete_held_out_finite_negative"
        and decision.get("qsdk_r10_satisfied") is False
        and decision.get("sdk1_m07_satisfied") is False
        and decision.get("same_identity_rerun_permitted") is False
        and decision.get("replacement_cell_permitted") is False
        and decision.get("threshold_change_applied") is False
        and decision.get("seed_or_population_change_applied") is False
        and decision.get("controller_change_applied") is False
        and decision.get("marker_timing_change_applied") is False
        and decision.get("fixture_or_material_change_applied") is False
        and decision.get("native_push_path_established_for_exact_population") is True
        and decision.get("post_push_recovery_window_established_for_exact_population")
        is True
        and decision.get("bounded_upright_push_recovery_acceptance_established")
        is False
        and decision.get("selected_successor_id") is None
        and decision.get("new_physical_work_authorized") is False
        and decision.get("physical_acceptance_authority") is False
        and decision.get("release_authority") is False,
        "CLOSURE_DECISION",
    )
    require(
        closure.get("sdk_status")
        == {
            "qsdk_r10_satisfied": False,
            "sdk1_m07_satisfied": False,
            "sdk1_completed_steps": 13,
            "sdk1_total_steps": 20,
            "full_program_completed_steps": 13,
            "full_program_total_steps": 25,
        },
        "CLOSURE_SDK_STATUS",
    )
    claims = closure.get("claim_boundary")
    require(isinstance(claims, dict), "CLOSURE_CLAIMS_MISSING")
    for key in (
        "bounded_upright_push_recovery_claimed",
        "external_push_recovery_claimed",
        "fall_recovery_claimed",
        "prone_to_standing_claimed",
        "force_aware_recovery_claimed",
        "other_engine_claimed",
        "cross_engine_equivalence_claimed",
        "population_success_rate_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        require(claims.get(key) is False, f"CLOSURE_FORBIDDEN_CLAIM:{key}")


def marker_payload(path: Path) -> dict[str, Any]:
    lines = [
        line
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.startswith(CELL_MARKER)
    ]
    require(len(lines) == 1, f"CELL_MARKER_COUNT:{path}")
    try:
        value = json.loads(lines[0][len(CELL_MARKER) :])
    except json.JSONDecodeError as exc:
        raise common.ClosureFailure(f"CELL_MARKER_JSON:{path}:{exc}") from exc
    require(isinstance(value, dict), f"CELL_MARKER_OBJECT:{path}")
    return value


def validate_attempt(
    attempt: dict[str, Any], cell_id: str, spec: dict[str, Any]
) -> None:
    require(
        attempt.get("schema_version") == "sporespore_qsdk_r10b_physical_attempt_v4"
        and attempt.get("campaign_id") == CAMPAIGN_ID
        and attempt.get("campaign_role") == "held_out_finite_decision"
        and attempt.get("cell_id") == cell_id
        and attempt.get("arm_id") == spec["arm"]
        and attempt.get("campaign_seed") == spec["seed"],
        f"{cell_id}_ATTEMPT_IDENTITY",
    )
    require(
        attempt.get("source_commit") == SOURCE_COMMIT
        and attempt.get("qualification_parent_commit") == DEVELOPMENT_CLOSURE_COMMIT
        and attempt.get("authorization_commit") == AUTHORITY_COMMIT
        and attempt.get("authorization_parent_commit") == STAGE_COMMIT
        and attempt.get("stage_freeze_sha256")
        == "sha256:5d3d7c6b04f5dd91c129b659d50329efdd7218f5a9a1dc78579992c0a49bd746"
        and attempt.get("execution_authority_sha256")
        == "sha256:aa67f3255f2336b43fbbecc31e6407907369f29d1353d0bfd894547eb0111f2b",
        f"{cell_id}_ATTEMPT_GRAPH",
    )
    require(
        Path(str(attempt.get("output_root"))).resolve() == EVIDENCE_ROOT.resolve()
        and attempt.get("supervisor_physical_authorized") is True
        and attempt.get("synthetic_authorization_preflight") is False
        and attempt.get("maximum_world_attempt_count") == 1
        and attempt.get("maximum_world_build_count") == 1
        and attempt.get("world_attempt_count_before_worker") == 0
        and attempt.get("world_build_count_before_worker") == 0
        and attempt.get("same_identity_rerun_permitted") is False
        and attempt.get("physical_acceptance_authority") is False,
        f"{cell_id}_ATTEMPT_AUTHORITY",
    )
    token = attempt.get("authorization_token")
    require(isinstance(token, str) and len(token) == 32, f"{cell_id}_TOKEN")
    lock = attempt.get("operation_lock")
    require(
        isinstance(lock, dict)
        and lock.get("schema_version")
        == "sporespore_locomotion_operation_lock_receipt_v1"
        and lock.get("acquired") is True
        and lock.get("role") == "physical"
        and lock.get("created_new") is True
        and lock.get("abandoned_owner_recovered") is False
        and lock.get("test_only") is False
        and lock.get("physical_acceptance_authority") is False,
        f"{cell_id}_LOCK",
    )


def validate_window(
    window: dict[str, Any],
    *,
    label: str,
    start: int,
    end: int,
    advance: float,
    failed_limbs: list[str],
) -> None:
    passed = not failed_limbs
    require(
        window.get("start_semantic_step") == start
        and window.get("end_semantic_step_exclusive") == end
        and window.get("duration_steps") == 360
        and window.get("minimum_task_frame_forward_advance_m") == 0.01
        and window.get("task_frame_forward_advance_m") == advance,
        f"{label}_INTERVAL",
    )
    require(
        window.get("safe_envelope_passed") is True
        and window.get("forward_advance_passed") is True
        and window.get("command_application_passed") is True
        and window.get("every_limb_airborne_then_recontact") is passed
        and window.get("passed") is passed
        and window.get("failure_code")
        == ("" if passed else "QSDK_R10B_WINDOW_REQUIREMENT_FAILED"),
        f"{label}_RESULT",
    )
    cycles = window.get("contact_cycle_by_limb")
    require(
        isinstance(cycles, dict) and set(cycles) == common.EXPECTED_LIMBS,
        f"{label}_CYCLES",
    )
    observed_failed = sorted(
        limb for limb, receipt in cycles.items() if receipt.get("passed") is False
    )
    require(observed_failed == failed_limbs, f"{label}_FAILED_LIMBS")


def validate_cell(
    cell: dict[str, Any], cell_id: str, spec: dict[str, Any]
) -> dict[str, Any]:
    require(
        cell.get("schema_version") == "sporespore_qsdk_r10b_physical_cell_v4"
        and cell.get("campaign_id") == CAMPAIGN_ID
        and cell.get("campaign_role") == "held_out_finite_decision"
        and cell.get("cell_id") == cell_id
        and cell.get("arm_id") == spec["arm"]
        and cell.get("campaign_seed") == spec["seed"]
        and cell.get("source_commit") == SOURCE_COMMIT,
        f"{cell_id}_IDENTITY",
    )
    require(
        cell.get("world_build_count") == 1
        and cell.get("world_reset_count") == 0
        and cell.get("evidence_valid") is True
        and cell.get("outcome_complete") is True
        and cell.get("behavior_passed") is False
        and cell.get("physical_acceptance_authority") is False
        and cell.get("release_authority") is False,
        f"{cell_id}_RESULT",
    )
    require(hash_object(cell) == spec["canonical"], f"{cell_id}_CANONICAL_SHA")
    evaluation = cell.get("evaluation")
    require(isinstance(evaluation, dict), f"{cell_id}_EVALUATION_MISSING")
    require(hash_object(evaluation) == spec["evaluation"], f"{cell_id}_EVALUATION_SHA")
    require(
        evaluation.get("schema_version") == "sporespore_qsdk_r10b_world_evaluation_v1"
        and evaluation.get("ok") is True
        and evaluation.get("failure_code") == ""
        and evaluation.get("evidence_valid") is True
        and evaluation.get("outcome_complete") is True
        and evaluation.get("behavior_passed") is False
        and evaluation.get("common_execution_integrity") is True
        and evaluation.get("walking_receipts_structurally_complete") is True
        and evaluation.get("ordinary_walking_passed") is False
        and evaluation.get("sdk_step_count") == spec["rows"]
        and evaluation.get("trace_row_count") == spec["rows"]
        and evaluation.get("evaluation_world_build_count") == 0,
        f"{cell_id}_EVALUATION_RESULT",
    )
    require(
        common.false_receipts(evaluation["walking_gate_receipts"])
        == ["bounded_anchor_error"],
        f"{cell_id}_WALKING_RECEIPTS",
    )
    require(
        evaluation.get("initial_perturbation_sha256") == spec["initial"],
        f"{cell_id}_INITIAL_PERTURBATION",
    )
    validate_window(
        evaluation["pre_push_window"],
        label=f"{cell_id}_PRE",
        start=180,
        end=540,
        advance=spec["pre_advance"],
        failed_limbs=spec["failed_limbs"],
    )
    application = evaluation["application_receipt"]
    if spec["arm"] == "matched_no_impulse_control":
        require(
            application
            == {
                "application_count": 0,
                "effect_magnitude_m_s": 0.0,
                "effect_sampled": False,
            },
            f"{cell_id}_APPLICATION",
        )
        validate_window(
            evaluation["baseline_post_marker_window"],
            label=f"{cell_id}_POST",
            start=541,
            end=901,
            advance=spec["post_advance"],
            failed_limbs=[],
        )
        require(evaluation["recovery_search"] == {}, f"{cell_id}_RECOVERY_EMPTY")
    else:
        require(
            application.get("application_count") == 1
            and application.get("effect_magnitude_m_s") == spec["effect"]
            and application.get("effect_sampled") is True
            and application.get("profile_id") == "lateral_impulse_v1"
            and application.get("step_from_sdk_start") == 540,
            f"{cell_id}_APPLICATION",
        )
        recovery = evaluation["recovery_search"]
        require(
            recovery.get("found") is True
            and recovery.get("failure_code") == ""
            and recovery.get("first_valid_start_semantic_step") == 541
            and recovery.get("reentry_latency_steps") == 0
            and recovery.get("reentry_latency_s") == 0.0,
            f"{cell_id}_RECOVERY",
        )
        validate_window(
            recovery["window"],
            label=f"{cell_id}_RECOVERY_WINDOW",
            start=541,
            end=901,
            advance=spec["recovery_advance"],
            failed_limbs=[],
        )
    common.validate_trace(cell, cell_id, int(spec["rows"]))
    require(
        hash_object(cell["sdk_physical_trace"]) == spec["trace"],
        f"{cell_id}_TRACE_SHA",
    )
    return evaluation


def validate_pair(
    pair: dict[str, Any], seed: int, cells: dict[str, dict[str, Any]]
) -> None:
    spec = PAIR_SPECS[seed]
    baseline_id = f"baseline_s{seed}"
    push_id = f"push_s{seed}"
    require(
        pair.get("schema_version") == "sporespore_qsdk_r10b_pair_evaluation_v1"
        and pair.get("campaign_seed") == seed
        and pair.get("baseline_cell_id") == baseline_id
        and pair.get("push_cell_id") == push_id
        and pair.get("ok") is True
        and pair.get("failure_code") == ""
        and pair.get("evidence_valid") is True
        and pair.get("outcome_complete") is True
        and pair.get("matched_initial_perturbation") is True
        and pair.get("native_effect_confirmed") is True
        and pair.get("behavior_passed") is False,
        f"PAIR_{seed}_RESULT",
    )
    require(
        pair.get("baseline_cell_raw_sha256") == CELL_SPECS[baseline_id]["raw"]
        and pair.get("push_cell_raw_sha256") == CELL_SPECS[push_id]["raw"],
        f"PAIR_{seed}_CELL_HASHES",
    )
    for field in (
        "native_effect_magnitude_m_s",
        "baseline_lateral_velocity_jump_m_s",
        "push_lateral_velocity_jump_m_s",
        "paired_lateral_velocity_jump_difference_m_s",
    ):
        require(pair.get(field) == spec[field], f"PAIR_{seed}_{field}")
    for counter in (
        "world_attempt_count",
        "world_build_count",
        "evaluation_world_build_count",
        "model_construction_count",
        "native_readback_count",
        "solver_step_count",
        "scene_tree_insertion_count",
    ):
        require(pair.get(counter) == 0, f"PAIR_{seed}_NONZERO_{counter}")
    require(
        pair.get("physics_state_modified") is False
        and pair.get("physical_acceptance_authority") is False
        and pair.get("release_authority") is False,
        f"PAIR_{seed}_AUTHORITY",
    )
    baseline = cells[baseline_id]["evaluation"]
    push = cells[push_id]["evaluation"]
    require(
        baseline["initial_perturbation_sha256"] == push["initial_perturbation_sha256"]
        and baseline["pre_push_window"] == push["pre_push_window"],
        f"PAIR_{seed}_MATCHING",
    )


def cell_projection(cell_id: str, cell: dict[str, Any]) -> dict[str, Any]:
    spec = CELL_SPECS[cell_id]
    evaluation = cell["evaluation"]
    pre = evaluation["pre_push_window"]
    baseline = evaluation["baseline_post_marker_window"]
    recovery = evaluation["recovery_search"]
    application = evaluation["application_receipt"]
    return {
        "cell_id": cell_id,
        "arm_id": spec["arm"],
        "campaign_seed": spec["seed"],
        "path": f"{cell_id}/cell.json",
        "raw_sha256": spec["raw"],
        "canonical_sha256": hash_object(cell),
        "evaluation_canonical_sha256": hash_object(evaluation),
        "trace_canonical_sha256": hash_object(cell["sdk_physical_trace"]),
        "initial_perturbation_sha256": evaluation["initial_perturbation_sha256"],
        "evidence_valid": cell["evidence_valid"],
        "outcome_complete": cell["outcome_complete"],
        "behavior_passed": cell["behavior_passed"],
        "world_build_count": cell["world_build_count"],
        "world_reset_count": cell["world_reset_count"],
        "sdk_step_count": evaluation["sdk_step_count"],
        "trace_row_count": evaluation["trace_row_count"],
        "ordinary_walking_passed": evaluation["ordinary_walking_passed"],
        "false_walking_receipts": common.false_receipts(
            evaluation["walking_gate_receipts"]
        ),
        "pre_push_window_passed": pre["passed"],
        "pre_push_forward_advance_m": pre["task_frame_forward_advance_m"],
        "pre_push_failed_limbs": sorted(
            limb
            for limb, receipt in pre["contact_cycle_by_limb"].items()
            if receipt["passed"] is False
        ),
        "baseline_post_marker_window_passed": baseline.get("passed") or None,
        "baseline_post_marker_forward_advance_m": (
            baseline.get("task_frame_forward_advance_m") if baseline else None
        ),
        "push_recovery_window_found": recovery.get("found") or None,
        "push_reentry_latency_steps": (
            recovery.get("reentry_latency_steps") if recovery else None
        ),
        "push_recovery_forward_advance_m": (
            recovery.get("window", {}).get("task_frame_forward_advance_m")
            if recovery
            else None
        ),
        "external_push_application_count": application["application_count"],
        "native_effect_magnitude_m_s": application["effect_magnitude_m_s"],
    }


def pair_projection(seed: int, pair: dict[str, Any]) -> dict[str, Any]:
    fields = (
        "ok",
        "evidence_valid",
        "outcome_complete",
        "matched_initial_perturbation",
        "native_effect_confirmed",
        "native_effect_magnitude_m_s",
        "baseline_lateral_velocity_jump_m_s",
        "push_lateral_velocity_jump_m_s",
        "paired_lateral_velocity_jump_difference_m_s",
        "behavior_passed",
        "evaluation_world_build_count",
        "physics_state_modified",
        "physical_acceptance_authority",
        "release_authority",
    )
    return {
        "campaign_seed": seed,
        "path": f"pair-s{seed}.json",
        "raw_sha256": PAIR_SPECS[seed]["raw"],
        **{field: pair[field] for field in fields},
    }


def validate_report(report: dict[str, Any]) -> None:
    require(
        report.get("schema_version") == "sporespore_qsdk_r10b_physical_report_v4"
        and report.get("campaign_id") == CAMPAIGN_ID
        and report.get("campaign_role") == "held_out_finite_decision"
        and report.get("question_class") == "finite decision"
        and report.get("status") == "complete_valid_finite_negative"
        and report.get("complete") is True
        and report.get("behavior_passed") is False
        and report.get("world_attempt_count") == 6
        and report.get("world_build_count") == 6
        and report.get("expected_world_count") == 6
        and report.get("pair_count") == 3
        and report.get("same_identity_rerun_permitted") is False
        and report.get("physical_acceptance_authority") is False
        and report.get("release_authority") is False,
        "REPORT_RESULT",
    )
    require(report.get("ordered_cell_ids") == list(CELL_SPECS), "REPORT_CELL_ORDER")
    source = report.get("source")
    require(
        source.get("source_freeze_commit") == SOURCE_COMMIT
        and source.get("qualification_parent_commit") == DEVELOPMENT_CLOSURE_COMMIT
        and source.get("qualification_commit") == STAGE_COMMIT
        and source.get("authorization_commit") == AUTHORITY_COMMIT
        and source.get("origin_main_commit") == AUTHORITY_COMMIT
        and source.get("live_main_commit") == AUTHORITY_COMMIT
        and source.get("remote") == EXPECTED_REMOTE
        and source.get("clean") is True,
        "REPORT_SOURCE",
    )
    require(
        [item.get("cell_id") for item in report.get("cells", [])] == list(CELL_SPECS)
        and [item.get("campaign_seed") for item in report.get("pairs", [])]
        == list(PAIR_SPECS),
        "REPORT_PROJECTIONS",
    )


def validate_retained_evidence(closure: dict[str, Any]) -> tuple[int, int]:
    files = common.tree_manifest(EVIDENCE_ROOT)
    manifest = common.canonical_bytes(files)
    require(len(files) == 37, "PHYSICAL_FILE_COUNT")
    require(
        sum(int(item["byte_length"]) for item in files) == 121_645_064,
        "PHYSICAL_TOTAL_BYTES",
    )
    require(len(manifest) == 5398, "PHYSICAL_MANIFEST_BYTES")
    require(
        common.sha256_bytes(manifest) == PHYSICAL_MANIFEST_SHA256,
        "PHYSICAL_MANIFEST_SHA",
    )
    require(
        closure["physical_attempt"]["retained_tree"]
        == {
            "schema_version": "sporespore_retained_file_tree_manifest_v1",
            "file_count": 37,
            "total_byte_length": 121_645_064,
            "manifest_canonical_byte_length": 5398,
            "manifest_canonical_sha256": PHYSICAL_MANIFEST_SHA256,
            "files": files,
        },
        "CLOSURE_RETAINED_TREE",
    )
    attempts: dict[str, dict[str, Any]] = {}
    cells: dict[str, dict[str, Any]] = {}
    markers = 0
    for cell_id, spec in CELL_SPECS.items():
        attempt_path = EVIDENCE_ROOT / cell_id / "attempt.json"
        attempt = common.read_json(attempt_path, f"{cell_id}_ATTEMPT")
        validate_attempt(attempt, cell_id, spec)
        attempts[cell_id] = attempt
        cell_path = EVIDENCE_ROOT / cell_id / "cell.json"
        require(
            common.sha256_bytes(cell_path.read_bytes()) == spec["raw"],
            f"{cell_id}_RAW_SHA",
        )
        cell = common.read_json(cell_path, f"{cell_id}_CELL")
        validate_cell(cell, cell_id, spec)
        cells[cell_id] = cell
        require(
            cell["authorization"]["attempt_sha256"]
            == common.sha256_bytes(attempt_path.read_bytes()),
            f"{cell_id}_ATTEMPT_LINK",
        )
        for log_name in ("stdout.log", "godot.log"):
            require(
                marker_payload(EVIDENCE_ROOT / cell_id / log_name) == cell,
                f"{cell_id}_{log_name}_MARKER",
            )
            markers += 1
    require(
        len({attempt["authorization_token"] for attempt in attempts.values()}) == 6,
        "ATTEMPT_TOKEN_REUSE",
    )
    pairs: dict[int, dict[str, Any]] = {}
    for seed, spec in PAIR_SPECS.items():
        path = EVIDENCE_ROOT / f"pair-s{seed}.json"
        require(
            common.sha256_bytes(path.read_bytes()) == spec["raw"],
            f"PAIR_{seed}_RAW_SHA",
        )
        pair = common.read_json(path, f"PAIR_{seed}")
        validate_pair(pair, seed, cells)
        pairs[seed] = pair
    require(
        closure.get("cell_results")
        == [cell_projection(cell_id, cells[cell_id]) for cell_id in CELL_SPECS],
        "CLOSURE_CELL_RESULTS",
    )
    require(
        closure.get("pair_results")
        == [pair_projection(seed, pairs[seed]) for seed in PAIR_SPECS],
        "CLOSURE_PAIR_RESULTS",
    )
    report_path = EVIDENCE_ROOT / "report.json"
    require(
        common.sha256_bytes(report_path.read_bytes())
        == "sha256:bae243e99ebfa844542b698582ec647326814d2d879a649ffebd8f59fd4c65a1",
        "REPORT_RAW_SHA",
    )
    report = common.read_json(report_path, "REPORT")
    validate_report(report)
    report_projection = closure["physical_attempt"]["report"]
    require(
        report_projection.get("raw_sha256")
        == "sha256:bae243e99ebfa844542b698582ec647326814d2d879a649ffebd8f59fd4c65a1"
        and report_projection.get("byte_length") == 5963
        and report_projection.get("status") == report["status"]
        and report_projection.get("complete") is True
        and report_projection.get("behavior_passed") is False
        and report_projection.get("world_attempt_count") == 6
        and report_projection.get("world_build_count") == 6
        and report_projection.get("expected_world_count") == 6
        and report_projection.get("pair_count") == 3
        and report_projection.get("same_identity_rerun_permitted") is False,
        "CLOSURE_REPORT",
    )
    require(
        sum(
            int(cell["runtime_summary_projection"]["executed_ticks"])
            for cell in cells.values()
        )
        == 17_755,
        "RECORDED_TICK_COUNT",
    )
    return markers, sum(int(spec["rows"]) for spec in CELL_SPECS.values())


def mutation_refusal_count(closure: dict[str, Any]) -> int:
    mutations = (
        (None, "physical_identity_consumed", False),
        (None, "same_identity_rerun_permitted", True),
        (None, "evidence_valid", False),
        (None, "outcome_complete", False),
        (None, "behavior_passed", True),
        (None, "status", "closed_positive"),
        ("decision", "same_identity_rerun_permitted", True),
        ("decision", "threshold_change_applied", True),
        ("decision", "sdk1_m07_satisfied", True),
        ("sdk_status", "sdk1_completed_steps", 14),
        ("claim_boundary", "external_push_recovery_claimed", True),
        ("physical_attempt", "world_build_count", 7),
    )
    refused = 0
    for section, key, value in mutations:
        candidate = copy.deepcopy(closure)
        target = candidate if section is None else candidate[section]
        target[key] = value
        try:
            validate_closure_contract(candidate)
        except common.ClosureFailure:
            refused += 1
    require(refused == len(mutations), "MUTATION_CONTROL_FAILED")
    return refused


def main() -> int:
    validate_repository()
    closure = common.read_json(CLOSURE_PATH, "CLOSURE")
    validate_closure_contract(closure)
    validate_source_graph(closure)
    validate_qualification(closure)
    marker_count, trace_rows = validate_retained_evidence(closure)
    mutation_count = mutation_refusal_count(closure)
    receipt = {
        "schema_version": (
            "sporespore_qsdk_r10b_held_out_finite_decision_" "physical_closure_audit_v1"
        ),
        "gate_id": "QSDK-R10B",
        "closure_id": "QSDK-R10B-H1",
        "ok": True,
        "evidence_valid": True,
        "outcome_complete": True,
        "behavior_passed": False,
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "retained_file_count": 37,
        "retained_total_byte_length": 121_645_064,
        "retained_tree_manifest_sha256": PHYSICAL_MANIFEST_SHA256,
        "qualification_file_count": 5,
        "world_attempt_count_in_retained_evidence": 6,
        "world_build_count_in_retained_evidence": 6,
        "valid_complete_cell_count": 6,
        "valid_complete_pair_count": 3,
        "retained_trace_row_count": trace_rows,
        "native_push_application_count": 3,
        "native_effect_confirmed_pair_count": 3,
        "post_push_recovery_window_found_count": 3,
        "baseline_post_marker_window_pass_count": 3,
        "ordinary_walking_conjunction_pass_count": 0,
        "pre_push_window_pass_count": 0,
        "cell_marker_count": marker_count,
        "closure_mutation_rejection_count": mutation_count,
        "qsdk_r10_satisfied": False,
        "sdk1_m07_satisfied": False,
        "model_construction_count": 0,
        "audit_world_attempt_count": 0,
        "audit_world_build_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    print(PASS_MARKER + json.dumps(receipt, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except common.ClosureFailure as exc:
        print(
            f"QSDK_R10B_HELD_OUT_FINITE_DECISION_PHYSICAL_CLOSURE_FAIL {exc}",
            file=sys.stderr,
        )
        raise SystemExit(1)
