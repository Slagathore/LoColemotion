#!/usr/bin/env python3
"""Audit the consumed R74 route-valid but classifier-incomplete calibration."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    git,
    records_with_key,
    require,
    require_ordered_markers,
    sha256,
    verify_boolean_partition,
    verify_exact_paths,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d74_godot_jolt_contact_calibration_"
    "incomplete_closure_v1.json"
)
SOURCE = "a11892515dbb6de5cd0ab2d72adfaa4ae316fd2b"
STATUS = (
    "closed_consumed_invalid_incomplete_declared_contact_point_classifier_not_"
    "retained_after_valid_two_step_route"
)


def main() -> None:
    closure = json.loads(CLOSURE.read_text(encoding="utf-8"))
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d74_godot_jolt_contact_calibration_"
                "incomplete_closure_v1"
            ),
            "gate_id": "QSDK-R24D74",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": True,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": "454dbd0268a4729efe58ec800ecc2e8b3ad15eac",
            "source.tree": "bc18feb3feedc9287277820600fec5142bcf4108",
            "source.subject": (
                "[recovery/core] Close R74: authorize repaired contact calibration"
            ),
        },
        "CLOSURE",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%P", SOURCE),
        closure["source"]["parent_commit"],
        "SOURCE_PARENT",
    )
    bound = {
        item["path"]: verify_source_binding(ROOT, SOURCE, item)
        for item in closure["source"]["bindings"]
    }
    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id="QSDK-R24D74",
        source_commit=SOURCE,
        status="valid_complete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d74_contact_calibration_attempt_v1",
            "raw": "sporespore_qsdk_r24d74_godot_contact_calibration_raw_v1",
            "terminal": "sporespore_qsdk_r24d74_contact_calibration_terminal_v1",
        },
        raw_count_keys=(
            "model_construction_attempt_count",
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
            "behavior_evaluator_invocation_count",
            "threshold_count",
            "margin_count",
            "held_out_cell_access_count",
        ),
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(
        raw,
        {
            "ok": True,
            "physical_question_opened": True,
            "physics_state_modified": True,
            "portable_collection_count": 2,
            "portable_control_plan_count": 2,
            "portable_command_application_count": 1,
            "first_step.native_route.ok": True,
            "first_step.native_route.solver_step_count": 1,
            "first_step.portable_route.ok": True,
            "second_step.native_route.ok": True,
            "second_step.native_route.solver_step_count": 2,
            "second_step.portable_route.ok": True,
        },
        "RAW",
    )
    verify_exact_paths(
        terminal,
        {
            "integration_ghost_passed": True,
            "worker.semantic_exit_code": 0,
            "worker.termination_protocol_valid": True,
            "raw_result.raw_sha256": physical["artifacts"]["raw"]["raw_sha256"],
            "same_identity_rerun_permitted": False,
        },
        "TERMINAL",
    )

    contact_hashes = []
    for step_name in ("first_step", "second_step"):
        components = raw[step_name]["native_route"]["measurement"][
            "source_component_receipts"
        ]
        require("contact_source_sha256" in components, f"CONTACT_HASH:{step_name}")
        require(
            "contact_source_receipt" not in components,
            f"CONTACT_PAYLOAD_UNEXPECTED:{step_name}",
        )
        contact_hashes.append(components["contact_source_sha256"])
        contacts = raw[step_name]["portable_route"]["collection_receipt"][
            "observation"
        ]["state"]["ordered_contact_observations"]
        exact(len(contacts), 4, f"CONTACT_COUNT:{step_name}")
        require(
            all(
                contact["provenance"]["impulse_source_profile_id"]
                == "godot_4_7_jolt_sporespore_solved_contact_telemetry_v1"
                and contact["provenance"]["impulse_source_kind"]
                == "native_post_solve_contact_constraint_lambda"
                for contact in contacts
            ),
            f"PAIRED_PROVENANCE:{step_name}",
        )
    exact(len(set(contact_hashes)), 2, "DISTINCT_CONTACT_SOURCE_HASHES")
    exact(records_with_key(raw, "exact_contact_point_count"), [], "CLASSIFIER_ABSENT")

    native_world = bound[
        "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
    ].decode()
    require(
        'var contact_source_sha256 := _sha256(sdk, contact_receipt["source_receipt"])'
        in native_world,
        "SOURCE_PAYLOAD_HASHED",
    )
    require(
        '"contact_source_sha256": contact_source_sha256' in native_world,
        "SOURCE_HASH_RETAINED",
    )

    stdout = (Path(physical["evidence_root"]) / "godot.stdout.log").read_text()
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build",
            "QSDK_R24D74_GODOT_CONTACT_CALIBRATION_RAW ",
            '"status":"valid_complete_integration_ghost"',
            "QSDK_R24D74_GODOT_SUPERVISOR_TERMINATION_READY ",
        ),
        "STDOUT",
    )
    verify_exact_paths(
        closure["causal_diagnosis"],
        {
            "portable_decoder_completed_step_count": 2,
            "contact_source_digest_retained_step_count": 2,
            "contact_source_payload_retained_step_count": 0,
            "declared_exact_contact_point_count_retained_step_count": 0,
            "route_integration_valid": True,
            "prospective_positive_or_negative_classifier_available": False,
            "derived_proxy_substitution_after_outcome_access_permitted": False,
            "physics_positive_or_negative_classification_available": False,
            "distinct_retention_successor_required_before_any_new_world": True,
        },
        "CAUSE",
    )
    verify_boolean_partition(
        closure["decision"],
        (
            "physical_attempt_retained",
            "physical_attempt_consumed_for_exact_source",
            "route_integration_valid",
            "world_constructed",
            "two_solver_steps_executed",
            "paired_core_decoder_completed",
            "physics_state_modified",
            "termination_protocol_valid",
            "raw_result_content_addressed",
            "terminal_content_addressed",
            "campaign_calibration_invalid_or_incomplete_observed",
            "distinct_successor_required",
        ),
        (
            "same_identity_rerun_permitted",
            "r24d74_requalification_permitted",
            "valid_contact_calibration_result_observed",
            "scientific_positive_observed",
            "scientific_negative_observed",
            "post_hoc_proxy_classification_used",
            "recovery_success_observed",
            "historical_result_rewritten",
            "prone_to_standing_claimed",
            "sdk1_milestone_advanced",
            "physical_acceptance_authority",
            "release_authority",
        ),
        "DECISION",
    )
    verify_exact_paths(
        closure,
        {
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "next_boundary.gate_id": "QSDK-R24D75",
            "next_boundary.physical_execution_blocked": True,
            "next_boundary.maximum_world_build_count": 0,
            "next_boundary.maximum_physical_steps_authorized": 0,
            "next_boundary.r24d74_may_be_rerun_or_requalified": False,
        },
        "DECISION_BOUNDARY",
    )

    relative = CLOSURE.relative_to(ROOT).as_posix()
    try:
        closure_blob = git(ROOT, "show", f"HEAD:{relative}", text=False)
    except subprocess.CalledProcessError:
        closure_blob = git(ROOT, "show", f":{relative}", text=False)
    assert isinstance(closure_blob, bytes)
    expected = {
        "r24d74_source_status": STATUS,
        "r24d74_physical_attempt_consumed": True,
        "r24d74_physical_result_status": "valid_complete_integration_ghost",
        "r24d74_campaign_calibration_status": "invalid_or_incomplete",
        "r24d74_observed_world_build_count": 1,
        "r24d74_observed_solver_step_count": 2,
        "r24d74_route_integration_valid": True,
        "r24d74_valid_contact_calibration_result_observed": False,
        "r24d74_physical_execution_authorized": False,
        "r24d75_distinct_successor_required": True,
    }
    for authority_relative in closure["live_authority_paths"]:
        authority = json.loads((ROOT / authority_relative).read_text(encoding="utf-8"))
        records = records_with_key(authority, "r24d74_physical_attempt_consumed")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{authority_relative}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{authority_relative}",
        )
        exact(
            record["r24d74_incomplete_closure_raw_sha256"],
            sha256(closure_blob),
            f"LIVE_CLOSURE_HASH:{authority_relative}",
        )
    print(
        "QSDK_R24D74_GODOT_JOLT_CONTACT_CALIBRATION_INCOMPLETE_CLOSURE_PASS "
        "attempts=1 models=1 worlds=1 steps=2 route=valid classifier=incomplete "
        "outcome=invalid next=R24D75 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
