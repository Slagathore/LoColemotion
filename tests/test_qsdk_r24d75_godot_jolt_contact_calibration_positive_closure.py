#!/usr/bin/env python3
"""Audit the consumed positive R75 finite contact calibration."""

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
    load,
    records_with_key,
    require,
    require_ordered_markers,
    sha256,
    verify_boolean_partition,
    verify_exact_paths,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)
from sdk.python.sporespore_locomotion import LocomotionCore  # noqa: E402

CLOSURE = ROOT / (
    "sdk/recovery/r24d75_godot_jolt_contact_calibration_"
    "positive_closure_v1.json"
)
SOURCE = "9cc1e03afa16ed418e480ab0094ae0ffadc747d3"
STATUS = (
    "closed_consumed_positive_nonzero_exact_contact_population_after_valid_"
    "two_step_route"
)


def main() -> None:
    closure = json.loads(CLOSURE.read_text(encoding="utf-8"))
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d75_godot_jolt_contact_calibration_"
                "positive_closure_v1"
            ),
            "gate_id": "QSDK-R24D75",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": True,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": "4ceadcf1c9ae04420b9f3d1787056cf8c7614346",
            "source.tree": "73d5b08e3f01792ec8205e9be37684fbd7fd4b11",
            "source.subject": (
                "[recovery/godot] Close R75: authorize retained-classifier "
                "calibration"
            ),
        },
        "CLOSURE",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%P", SOURCE),
        closure["source"]["parent_commit"],
        "SOURCE_PARENT",
    )
    for binding in closure["source"]["bindings"]:
        verify_source_binding(ROOT, SOURCE, binding)

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id="QSDK-R24D75",
        source_commit=SOURCE,
        status="valid_complete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d75_contact_calibration_attempt_v1",
            "raw": "sporespore_qsdk_r24d75_godot_contact_calibration_raw_v1",
            "terminal": "sporespore_qsdk_r24d75_contact_calibration_terminal_v1",
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

    core_claim = closure["exact_core_canonicalizer"]
    payload = Path(core_claim["payload_path"])
    payload_raw = payload.read_bytes()
    exact(
        (len(payload_raw), sha256(payload_raw)),
        (core_claim["byte_length"], core_claim["qualification_toolchain_sha256"]),
        "CORE_PAYLOAD",
    )
    exact(
        core_claim["post_physical_local_sha256"],
        core_claim["qualification_toolchain_sha256"],
        "CORE_IDENTITY_CONTINUITY",
    )
    verify_exact_paths(
        load(Path(core_claim["manifest_path"])),
        {
            "schema_version": "sporespore_content_addressed_artifact_manifest_v1",
            "algorithm": "sha256",
            "sha256": core_claim["qualification_toolchain_sha256"],
            "byte_length": core_claim["byte_length"],
            "payload_name": "payload.bin",
            "media_type": "application/vnd.microsoft.portable-executable",
        },
        "CORE_MANIFEST",
    )
    core = LocomotionCore(payload)
    exact(core.version, core_claim["core_version"], "CORE_VERSION")

    classifier = closure["classifier_observation"]
    counts: list[int] = []
    stored_hashes: list[str] = []
    recomputed_hashes: list[str] = []
    for step_name in ("first_step", "second_step"):
        components = raw[step_name]["native_route"]["measurement"][
            "source_component_receipts"
        ]
        exact(
            components["schema_version"],
            "sporespore_qsdk_r24d75_godot_source_component_receipts_v1",
            f"COMPONENT_SCHEMA:{step_name}",
        )
        source = components.get("contact_source_receipt")
        require(isinstance(source, dict), f"CONTACT_SOURCE:{step_name}")
        contract = source.get("solved_contact_telemetry_contract")
        require(isinstance(contract, dict), f"CONTACT_CONTRACT:{step_name}")
        verify_exact_paths(
            contract,
            {
                "schema_version": (
                    "sporespore_qsdk_r24d71_godot_solved_contact_"
                    "telemetry_contract_v1"
                ),
                "ok": True,
            },
            f"CONTACT_CONTRACT:{step_name}",
        )
        count = contract.get("exact_contact_point_count")
        require(type(count) is int and count >= 0, f"CONTACT_COUNT_TYPE:{step_name}")
        stored = str(components.get("contact_source_sha256", ""))
        recomputed = str(core.canonicalize_json(source)["sha256"])
        exact(recomputed, stored, f"CONTACT_DIGEST:{step_name}")
        counts.append(count)
        stored_hashes.append(stored)
        recomputed_hashes.append(recomputed)

    exact(counts, [8, 8], "EXACT_CONTACT_COUNTS")
    exact(
        stored_hashes,
        [
            classifier["first_step_contact_source_sha256"],
            classifier["second_step_contact_source_sha256"],
        ],
        "STORED_CONTACT_HASHES",
    )
    exact(
        recomputed_hashes,
        [
            classifier["first_step_exact_core_recomputed_sha256"],
            classifier["second_step_exact_core_recomputed_sha256"],
        ],
        "RECOMPUTED_CONTACT_HASHES",
    )
    verify_exact_paths(
        classifier,
        {
            "first_step_exact_contact_point_count": 8,
            "second_step_exact_contact_point_count": 8,
            "exact_core_digest_match_count": 2,
            "complete_step_count": 2,
            "nonzero_step_count": 2,
            "zero_step_count": 0,
            "prospective_positive_classification_satisfied": True,
            "prospective_negative_classification_satisfied": False,
            "post_hoc_proxy_classification_used": False,
        },
        "CLASSIFIER",
    )

    stdout = (Path(physical["evidence_root"]) / "godot.stdout.log").read_text()
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build",
            "QSDK_R24D75_GODOT_CONTACT_CALIBRATION_RAW ",
            '"status":"valid_complete_integration_ghost"',
            "QSDK_R24D75_GODOT_SUPERVISOR_TERMINATION_READY ",
        ),
        "STDOUT",
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
            "contact_source_receipts_retained",
            "exact_core_digest_recomputation_passed",
            "prospective_classifier_complete",
            "valid_contact_calibration_result_observed",
            "scientific_positive_observed",
        ),
        (
            "scientific_negative_observed",
            "same_identity_rerun_permitted",
            "r24d75_requalification_permitted",
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
            "next_boundary.gate_id": "QSDK-R24D76",
            "next_boundary.physical_execution_blocked": True,
            "next_boundary.maximum_world_build_count": 0,
            "next_boundary.maximum_physical_steps_authorized": 0,
            "next_boundary.r24d75_may_be_rerun_or_requalified": False,
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
        "next_gate_id": "QSDK-R24D76",
        "r24d75_source_status": STATUS,
        "r24d75_physical_attempt_consumed": True,
        "r24d75_physical_result_status": "valid_complete_integration_ghost",
        "r24d75_campaign_calibration_status": "positive_nonzero_exact_contact_population",
        "r24d75_observed_world_build_count": 1,
        "r24d75_observed_solver_step_count": 2,
        "r24d75_route_integration_valid": True,
        "r24d75_exact_core_digest_match_count": 2,
        "r24d75_first_step_exact_contact_point_count": 8,
        "r24d75_second_step_exact_contact_point_count": 8,
        "r24d75_valid_contact_calibration_result_observed": True,
        "r24d75_scientific_positive_observed": True,
        "r24d75_physical_execution_authorized": False,
        "r24d76_distinct_successor_required": True,
    }
    for authority_relative in closure["live_authority_paths"]:
        authority = json.loads((ROOT / authority_relative).read_text(encoding="utf-8"))
        records = records_with_key(authority, "r24d75_physical_attempt_consumed")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{authority_relative}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{authority_relative}",
        )
        exact(
            record["r24d75_positive_closure_raw_sha256"],
            sha256(closure_blob),
            f"LIVE_CLOSURE_HASH:{authority_relative}",
        )
    print(
        "QSDK_R24D75_GODOT_JOLT_CONTACT_CALIBRATION_POSITIVE_CLOSURE_PASS "
        "attempts=1 models=1 worlds=1 steps=2 route=valid counts=8,8 "
        "digests=2/2 outcome=positive next=R24D76 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
