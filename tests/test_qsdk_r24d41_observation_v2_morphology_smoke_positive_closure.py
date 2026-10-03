"""Audit the retained QSDK-R24D41 native route-integration positive."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    exact_bools,
    git,
    load,
    loads,
    require,
    sha256,
    source_bytes,
    verify_retained_commit,
    verify_retained_file_manifest,
    verify_source_receipt_manifest,
)


CLOSURE = (
    ROOT
    / "sdk/recovery/"
    "r24d41_mujoco_recovery_morphology_observation_v2_smoke_positive_closure_v1.json"
)
SOURCE = "de418f0fec4d1584dff8439f87e9eba01d12094e"
CAMPAIGN = "QSDK-R24D41-MUJOCO-RECOVERY-MORPHOLOGY-OBSERVATION-V2-SMOKE"
ROUTE = "sporespore_mujoco_exact_s169_recovery_observation_v2_consumer_v1"
NATIVE_ROUTE = "sporespore_mujoco_exact_s169_native_recovery_implicit_step_energy_v3"
MORPHOLOGY = "sha256:926551af3a72eb1fd1f3b71bfb103587a0b906a116775551a2463792e2c160f9"


def _json(relative: str) -> dict[str, Any]:
    value = json.loads((ROOT / relative).read_bytes())
    require(isinstance(value, dict), f"JSON_ROOT:{relative}")
    return value


def _find_gate(value: object, gate_id: str) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if value.get("gate_id") == gate_id:
            found.append(value)
        for child in value.values():
            found.extend(_find_gate(child, gate_id))
    elif isinstance(value, list):
        for child in value:
            found.extend(_find_gate(child, gate_id))
    return found


def audit() -> None:
    closure = load(CLOSURE)
    exact(
        closure["schema_version"],
        "sporespore_qsdk_r24d41_mujoco_recovery_morphology_observation_v2_smoke_positive_closure_v1",
        "SCHEMA",
    )
    exact(closure["gate_id"], "QSDK-R24D41", "GATE")
    exact(closure["campaign_id"], CAMPAIGN, "CAMPAIGN")
    exact(closure["question_class"], "development", "QUESTION")
    exact(closure["physical_question_declared"], True, "PHYSICAL_QUESTION")
    exact_bools(
        closure,
        (
            "behavior_question_declared",
            "superiority_question_declared",
            "equivalence_or_non_inferiority_question_declared",
            "population_inference_declared",
        ),
        False,
        "QUESTION_LIMIT",
    )

    source = closure["source"]
    exact(source["commit"], SOURCE, "SOURCE")
    verify_retained_commit(ROOT, SOURCE, source["parent_commit"])
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE), source["tree"], "TREE")
    exact(
        git(ROOT, "show", "-s", "--format=%s", SOURCE),
        source["subject"],
        "SUBJECT",
    )
    contract_binding = source["contract"]
    contract_raw = source_bytes(ROOT, SOURCE, contract_binding["path"])
    exact(len(contract_raw), contract_binding["byte_length"], "CONTRACT_LENGTH")
    exact(sha256(contract_raw), contract_binding["raw_sha256"], "CONTRACT_HASH")
    exact(
        git(ROOT, "rev-parse", f"{SOURCE}:{contract_binding['path']}"),
        contract_binding["git_blob_oid"],
        "CONTRACT_OID",
    )
    contract = loads(contract_raw)
    exact(contract["question_class"], "development", "CONTRACT_QUESTION")
    exact(contract["behavior_question_declared"], False, "CONTRACT_BEHAVIOR")
    exact(
        (
            contract["ghost_horizon"]["outer_steps_per_arm"],
            contract["ghost_horizon"]["paired_arm_count"],
            contract["bounded_native_code_path_smoke"]["maximum_total_outer_steps"],
            contract["bounded_native_code_path_smoke"][
                "maximum_total_native_solver_steps"
            ],
        ),
        (1, 2, 2, 10),
        "CONTRACT_BUDGET",
    )
    exact(
        contract["threshold_margin_and_population_provenance"][
            "new_empirical_threshold_count"
        ],
        0,
        "THRESHOLD_COUNT",
    )
    exact(
        contract["threshold_margin_and_population_provenance"][
            "new_statistical_margin_count"
        ],
        0,
        "MARGIN_COUNT",
    )

    qualification = closure["qualification"]
    qualification_root = Path(qualification["evidence_root"])
    exact(
        len(qualification["retained_artifacts"]),
        qualification["retained_artifact_count"],
        "QUALIFICATION_ARTIFACT_COUNT",
    )
    verify_retained_file_manifest(
        qualification_root,
        qualification["retained_artifacts"],
    )
    receipt_path = qualification_root / qualification["receipt_path"]
    receipt_raw = receipt_path.read_bytes()
    exact(len(receipt_raw), qualification["receipt_byte_length"], "QUAL_LENGTH")
    exact(sha256(receipt_raw), qualification["receipt_raw_sha256"], "QUAL_HASH")
    receipt = loads(receipt_raw)
    exact(
        (receipt["ok"], receipt["mode"], receipt["source_commit"]),
        (True, "qualification", SOURCE),
        "QUAL_IDENTITY",
    )
    exact(
        [entry["path"] for entry in receipt["source_manifest"]],
        contract["source_inventory"],
        "SOURCE_INVENTORY",
    )
    exact(
        len(receipt["source_manifest"]),
        qualification["source_manifest_entry_count"],
        "SOURCE_COUNT",
    )
    verify_source_receipt_manifest(
        ROOT,
        SOURCE,
        receipt["source_manifest"],
        qualification["source_manifest_raw_representation"],
    )
    blob_matches = 0
    checkout_only: list[dict[str, Any]] = []
    for entry in receipt["source_manifest"]:
        blob = source_bytes(ROOT, SOURCE, entry["path"])
        blob_hash = sha256(blob)
        if len(blob) == entry["byte_length"] and blob_hash == entry["raw_sha256"]:
            blob_matches += 1
        else:
            checkout_only.append(
                {
                    "path": entry["path"],
                    "observed_checkout_byte_length": entry["byte_length"],
                    "observed_checkout_raw_sha256": entry["raw_sha256"],
                    "canonical_git_blob_byte_length": len(blob),
                    "canonical_git_blob_raw_sha256": blob_hash,
                    "representation_note": "qualification_runner_recorded_exact_windows_checkout_bytes_while_git_blob_oid_retained_canonical_source_identity",
                }
            )
    representation = qualification["source_manifest_representation_evidence"]
    exact(blob_matches, representation["git_blob_raw_byte_match_count"], "BLOB_MATCHES")
    exact(
        len(receipt["source_manifest"]),
        representation["git_blob_oid_match_count"],
        "OID_MATCHES",
    )
    exact(checkout_only, representation["checkout_only_entries"], "CHECKOUT_ONLY")
    exact(len(checkout_only), representation["checkout_only_entry_count"], "CHECKOUT_COUNT")

    preflight = receipt["production_preflight"]
    exact(
        (preflight["controls_passed"], preflight["control_count"]),
        (qualification["controls_passed"], qualification["control_count"]),
        "CONTROL_COUNT",
    )
    exact(preflight["forced_failure_count"], qualification["forced_failure_count"], "FORCED")
    require(all(preflight["recovery_morphology_observation_v2_controls"].values()), "CONTROLS")
    details = preflight["recovery_morphology_observation_v2_control_details"]
    exact(details["conjunction_receipt_sha256"], qualification["conjunction_receipt_sha256"], "CONJUNCTION")
    exact(details["compiled_receipt_sha256"], qualification["compiled_receipt_sha256"], "COMPILED")
    exact(details["candidate_invariant_receipt_sha256"], qualification["candidate_invariant_receipt_sha256"], "CANDIDATE_INVARIANT")
    exact(details["matched_zero_invariant_receipt_sha256"], qualification["matched_zero_invariant_receipt_sha256"], "ZERO_INVARIANT")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "held_out_cell_access_count",
        "held_out_selector_invocation_count",
    ):
        exact(receipt[key], 0, f"QUAL_{key.upper()}")
    exact(receipt["physics_state_modified"], False, "QUAL_PHYSICS")
    exact(receipt["operation_lock_released"], True, "QUAL_LOCK")

    attempt = closure["physical_attempt"]
    attempt_root = Path(attempt["evidence_root"])
    exact(
        len(closure["retained_physical_artifacts"]),
        closure["retained_physical_artifact_count"],
        "PHYSICAL_ARTIFACT_COUNT",
    )
    verify_retained_file_manifest(
        attempt_root,
        closure["retained_physical_artifacts"],
    )
    require(not (attempt_root / "invalid_result.json").exists(), "INVALID_RESULT")
    reservation = load(attempt_root / "attempt_reservation.json")
    manifest = load(attempt_root / "manifest.json")
    summary = load(attempt_root / "smoke_summary.json")
    supervisor = load(attempt_root / "supervisor_completion.json")
    envelope = load(attempt_root / "smoke_result.json")
    exact(
        (
            reservation["source_commit"],
            reservation["selected_cell_id"],
            reservation["selected_seed"],
            reservation["horizon_steps_per_arm"],
            reservation["paired_arm_count"],
            reservation["qualification_receipt_raw_sha256"],
        ),
        (
            SOURCE,
            attempt["selected_cell_id"],
            attempt["selected_seed"],
            attempt["horizon_steps_per_arm"],
            attempt["paired_arm_count"],
            attempt["qualification_receipt_raw_sha256"],
        ),
        "RESERVATION",
    )
    exact(
        (
            manifest["source_commit"],
            manifest["code_path_integration_passed"],
            manifest["complete_trace_retained"],
            manifest["trace_invariants_replayed"],
            manifest["behavior_result_observed"],
        ),
        (SOURCE, True, True, True, False),
        "MANIFEST",
    )
    exact(
        (supervisor["worker_exit_code"], supervisor["route_coverage_passed"], supervisor["invalid_or_incomplete_retained"], supervisor["operation_lock_released"], supervisor["caught_error"]),
        (0, True, False, True, None),
        "SUPERVISOR",
    )
    exact(summary["result_raw_sha256"], sha256((attempt_root / "smoke_result.json").read_bytes()), "RESULT_HASH")
    exact(
        (
            summary["model_construction_count"],
            summary["world_attempt_count"],
            summary["world_build_count"],
            summary["outer_step_count"],
            summary["native_solver_step_count"],
            summary["validated_native_substep_count"],
        ),
        (2, 2, 2, 2, 10, 10),
        "SUMMARY_COUNTS",
    )
    invariants = summary["trace_invariants"]
    exact(invariants["in_run_invariant_receipt_sha256s"], attempt["in_run_invariant_receipt_sha256s"], "INVARIANT_HASHES")
    exact(
        (
            invariants["validated_arm_count"],
            invariants["validated_outer_step_count"],
            invariants["validated_native_substep_count"],
            invariants["portable_publication_replayed_exact"],
            invariants["public_collector_supervisor_controller_and_evaluator_executed"],
            invariants["recovery_morphology_readback_exact"],
            invariants["recovery_morphology_initializer_exact"],
        ),
        (2, 2, 10, True, True, True, True),
        "INVARIANTS",
    )

    exact(
        (envelope["gate_id"], envelope["campaign_id"], envelope["source_commit"], envelope["question_class"]),
        ("QSDK-R24D41", CAMPAIGN, SOURCE, "development"),
        "ENVELOPE",
    )
    result = envelope["result"]
    exact(result["route_id"], ROUTE, "RESULT_ROUTE")
    exact(
        (
            result["model_construction_count"],
            result["world_attempt_count"],
            result["world_build_count"],
            result["outer_step_count"],
            result["native_solver_step_count"],
            result["initializer_identity_matched"],
            result["native_runtime_observation_collection_executed"],
        ),
        (2, 2, 2, 2, 10, True, True),
        "RESULT_COUNTS",
    )
    for label, arm_kind, arm in (
        ("CANDIDATE", "candidate_command", result["candidate"]),
        ("MATCHED", "matched_zero_command", result["matched_zero_command"]),
    ):
        exact(
            (arm["arm_kind"], arm["route_id"], arm["native_source_route_id"], arm["portable_observation_schema"], arm["portable_recovery_context_bound"]),
            (arm_kind, ROUTE, NATIVE_ROUTE, "sporespore_recovery_observation_v2", True),
            f"{label}_ROUTE",
        )
        mapping = arm["native_recovery_morphology_readback"]
        exact(mapping["ordered_joint_readback_count"], 8, f"{label}_READBACK_COUNT")
        require(all(item["matches_zero_world_mapping"] for item in mapping["ordered_joint_readbacks"]), f"{label}_READBACK")
        initializer = arm["initializer_manifest"]
        exact(initializer["recovery_morphology_spec_sha256"], MORPHOLOGY, f"{label}_MORPHOLOGY")
        exact(initializer["native_joint_position_readback_matches"], True, f"{label}_INITIALIZER")
        for key in ("observations", "native_receipts", "collector_receipts", "portable_step_receipts"):
            exact(len(arm[key]), 1, f"{label}_{key.upper()}")
        native = arm["native_receipts"][0]
        exact((native["native_source_route_id"], native["application"]["route_id"], native["native_step"]["route_id"]), (NATIVE_ROUTE, NATIVE_ROUTE, NATIVE_ROUTE), f"{label}_NATIVE_ROUTE")
        exact(
            arm["observations"][0]["schema_version"],
            "sporespore_recovery_observation_v2",
            f"{label}_OBSERVATION",
        )
        require(
            all(
                value == 0
                for value in arm["observations"][0]["external_interventions"].values()
            ),
            f"{label}_INTERVENTIONS",
        )
        exact(arm["collector_receipts"][0]["supplied_native_post_step_observation_validated"], True, f"{label}_COLLECTOR")
        exact(arm["portable_step_receipts"][0]["controller_command_emitted"], False, f"{label}_COMMAND")
        exact(arm["final_phase"], "confirm_prone", f"{label}_PHASE")
    evaluation = result["evaluation"]
    exact(
        (evaluation["physical_development_trace_valid"], evaluation["verdict"], evaluation["physical_result"], evaluation["refusal_reason"]),
        (True, "physical_development_incomplete", False, None),
        "EVALUATION",
    )

    decision = closure["decision"]
    exact(decision["r24d41_may_be_rerun"], False, "RERUN")
    exact(decision["exact_recovery_morphology_observation_v2_route_conjunction_proven"], True, "ROUTE_PROVEN")
    exact(decision["native_observation_v2_physically_published"], True, "V2_PUBLISHED")
    exact(decision["sdk1_completed_steps"], 11, "SDK1_COUNT")
    exact(decision["sdk1_total_steps"], 20, "SDK1_TOTAL")
    exact(closure["next_boundary"]["gate_id"], "QSDK-R24D42", "NEXT_GATE")
    exact(closure["next_boundary"]["next_physical_execution_authorized"], False, "NEXT_PHYSICS")
    exact(closure["audit_economy"]["historical_closure_audit_execution_count"], 0, "AUDIT_REEXECUTION")
    exact_bools(
        closure["claim_boundary"],
        (
            "recovery_progression_proven",
            "recovery_to_stance_handoff_observed",
            "controller_physical_viability_proven",
            "prone_to_standing_claimed",
            "repeatability_rate_claimed",
            "population_claimed",
            "held_out_validation_claimed",
            "cross_engine_recovery_claimed",
            "cross_engine_equivalence_claimed",
            "sdk1_milestone_advanced",
            "physical_acceptance_authority",
            "release_authority",
        ),
        False,
        "CLAIM_LIMIT",
    )

    release_path = "sdk/release/quadruped_release_contract.json"
    support_path = "sdk/release/quadruped_support_matrix.json"
    for document, code in ((_json(release_path), "RELEASE"), (_json(support_path), "SUPPORT")):
        nodes = [node for node in _find_gate(document, "QSDK-R24D42") if node.get("predecessor_gate_id") == "QSDK-R24D41"]
        exact(len(nodes), 1, f"{code}_NEXT_NODE")
        exact(
            nodes[0]["predecessor_closure_raw_sha256"],
            sha256(CLOSURE.read_bytes()),
            f"{code}_CLOSURE_HASH",
        )
        exact(
            nodes[0]["predecessor_closure_audit_raw_sha256"],
            sha256(Path(__file__).read_bytes()),
            f"{code}_AUDIT_HASH",
        )
        exact(nodes[0]["physical_execution_authorized"], False, f"{code}_NEXT_PHYSICS")
        exact(nodes[0]["r24d41_may_be_rerun"], False, f"{code}_R41_RERUN")
    mapping = _json("sdk/release/quadruped_sdk1_milestone_mapping_v1.json")
    authority = mapping["full_program_authority"]
    exact(authority["release_contract_raw_sha256"], "sha256:" + hashlib.sha256((ROOT / release_path).read_bytes()).hexdigest(), "MAPPING_RELEASE")
    exact(authority["support_matrix_raw_sha256"], "sha256:" + hashlib.sha256((ROOT / support_path).read_bytes()).hexdigest(), "MAPPING_SUPPORT")
    documentation_markers = {
        "docs/README.md": "R24D41 closes the native observation-V2 route positive",
        "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md": "R24D41 closes route integration; R24D42 owns behavior",
        "docs/LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md": "R24D41 observed finite population and adequacy",
        "docs/LOCOMOTION_ARCHITECTURE.md": "R24D41 physically closes the composite route",
        "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md": "R24D41 closes positive and selects direct progression",
        "sdk/adapters/mujoco/README.md": "R24D41 retained route-integration positive",
    }
    for relative, marker in documentation_markers.items():
        require(marker in (ROOT / relative).read_text(encoding="utf-8"), f"DOC:{relative}")

    print(
        "QSDK_R24D41_OBSERVATION_V2_MORPHOLOGY_SMOKE_POSITIVE_CLOSURE_PASS "
        "qualification=8/8 forced_failures=9 models=2 worlds=2 outer_steps=2 "
        "solver_steps=10 observation_v2=published route=positive behavior=incomplete "
        "heldout=0 sdk1=11/20 next=QSDK-R24D42"
    )


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError) as error:
        print(
            "QSDK_R24D41_OBSERVATION_V2_MORPHOLOGY_SMOKE_POSITIVE_CLOSURE_FAIL "
            f"{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
