#!/usr/bin/env python3
"""Materialize the compact R23D78 campaign-attestation manifest.

The manifest composes the commissioned generic attestation executor with the
complete R23D78 zero-world gate and one fast campaign-local gate for each
required role. The prospective declaration's exact native-smoke waiver is
bound explicitly; no historical result is reused as an R23D78 outcome. This
materializer constructs no model or world and grants no physical authority.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[2]
TURNING = ROOT / "sdk" / "turning"
IMPLEMENTATION = (
    TURNING / "r23d78_production_route_three_engine_turning_implementation_v1.json"
)
DECLARATION = (
    TURNING / "r23d78_fresh_finite_three_engine_turning_decision_v1.json"
)
OUTPUT = TURNING / "r23d78_campaign_attestation_manifest_v1.json"
SELF = Path(__file__).resolve()
ZERO_WORLD_GATE = ROOT / "tests" / "test_qsdk_r23d78_zero_world.ps1"
ROLE_GATE = ROOT / "tests" / "test_qsdk_r23d78_campaign_roles.ps1"
EVALUATOR = (
    TURNING / "r23d78_production_route_three_engine_turning_evaluator.py"
)
SUPERVISOR = ROOT / "sdk" / "run_qsdk_r23d78_supervisor.ps1"
PROVENANCE_CONTRACT = ROOT / "sdk" / "closure_evidence_provenance_contract.json"
PROVENANCE_INVENTORY = ROOT / "sdk" / "closure_evidence_mode_inventory.json"
PROVENANCE_GATE = ROOT / "tests" / "test_closure_evidence_provenance_contract.ps1"
ATTRIBUTES = ROOT / ".gitattributes"
CAMPAIGN_ID = "QSDK-R23D78-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"


class ManifestError(RuntimeError):
    """The deterministic R23D78 attestation manifest could not be built."""


def _relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError as error:
        raise ManifestError(
            f"R23D78_ATTESTATION_PATH_ESCAPES_REPOSITORY:{path}"
        ) from error


def _raw_sha256(path: Path) -> str:
    if not path.is_file():
        raise ManifestError(
            f"R23D78_ATTESTATION_SOURCE_MISSING:{_relative(path)}"
        )
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _load_json(path: Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ManifestError(code) from error
    if not isinstance(value, dict):
        raise ManifestError(code)
    return value


def _load_implementation() -> dict[str, Any]:
    value = _load_json(
        IMPLEMENTATION, "R23D78_ATTESTATION_IMPLEMENTATION_UNREADABLE"
    )
    claims = value.get("claims", {})
    exact = (
        value.get("campaign_id") == CAMPAIGN_ID
        and value.get("gate_id") == "QSDK-R23D78"
        and value.get("question_class") == "finite_decision"
        and value.get("declared_cell_count") == 9
        and len(value.get("ordered_cell_ids", [])) == 9
        and claims.get("implementation_complete") is True
        and claims.get("complete_zero_world_gate_passed") is True
        and claims.get("both_predecessor_replays_passed") is True
        and value.get("evaluator", {}).get(
            "r23d77_existing_file_identity_verifier_bound"
        )
        is True
        and claims.get("native_smoke_passed") is False
        and claims.get("new_native_smoke_required") is False
        and claims.get("full_seeded_world_ghost_used") is False
        and claims.get("physical_campaign_opened") is False
        and claims.get("q_sdk_r23_satisfied") is False
        and isinstance(value.get("dependency_digests"), dict)
        and len(value["dependency_digests"])
        == value["dependency_inventory"]["transitive_path_count"]
        and len(value["dependency_digests"]) == 227
    )
    if not exact:
        raise ManifestError("R23D78_ATTESTATION_IMPLEMENTATION_INVALID")
    return value


def _load_declaration() -> dict[str, Any]:
    value = _load_json(
        DECLARATION, "R23D78_ATTESTATION_DECLARATION_UNREADABLE"
    )
    smoke = value.get("post_zero_world_native_smoke", {})
    exact = (
        value.get("campaign_id") == CAMPAIGN_ID
        and value.get("gate_id") == "QSDK-R23D78"
        and value.get("question_class") == "finite_decision"
        and smoke.get("required_before_qualification") is False
        and smoke.get("maximum_world_count") == 0
        and smoke.get("maximum_solver_step_count_per_world") == 0
        and smoke.get(
            "r23d76_complete_native_horizon_count_used_for_route_adequacy"
        )
        == 9
        and smoke.get("r23d76_reused_as_r23d78_finite_result") is False
        and smoke.get("behavior_thresholds_applied") is False
        and smoke.get("physical_acceptance_authority") is False
    )
    if not exact:
        raise ManifestError("R23D78_ATTESTATION_DECLARATION_INVALID")
    return value


def _load_provenance_reconciliation() -> tuple[dict[str, Any], dict[str, Any]]:
    contract = _load_json(
        PROVENANCE_CONTRACT,
        "R23D78_ATTESTATION_PROVENANCE_CONTRACT_UNREADABLE",
    )
    inventory = _load_json(
        PROVENANCE_INVENTORY,
        "R23D78_ATTESTATION_PROVENANCE_INVENTORY_UNREADABLE",
    )
    checkout_filter_migration = contract.get("checkout_filter_migration", {})
    failure = checkout_filter_migration.get(
        "r23d78_qualification_provenance_reconciliation", {}
    )
    late_inventory = contract.get("inventory", {}).get(
        "r23d78_successor_r23d76_late_closure_inventory_reconciliation", {}
    )
    current_attributes_sha256 = _raw_sha256(ATTRIBUTES).removeprefix("sha256:")
    added_entry = late_inventory.get("added_entry")
    exact = (
        failure.get("status")
        == "failed_closed_then_current_checkout_identity_rebound_before_any_r23d78_physics"
        and failure.get("qualification_process_question_class") == "development"
        and failure.get("physical_question_class_inherited_unchanged")
        == "finite_decision"
        and failure.get("failed_source_commit")
        == "0e47997990617ee5582b6ebacd552ad4a29378af"
        and failure.get("failed_source_tree_git_oid")
        == "685aa3738e16e0fd00ad849787bc75cab75d5527"
        and failure.get("failed_qualification_passed_gate_count") == 3
        and failure.get("failed_qualification_gate_id")
        == "CAK1-EVIDENCE-PROVENANCE"
        and failure.get("failed_qualification_campaign_role_gate_count") == 0
        and failure.get("failed_qualification_model_construction_count") == 0
        and failure.get("failed_qualification_world_attempt_count") == 0
        and failure.get("failed_qualification_world_build_count") == 0
        and failure.get("failed_qualification_solver_step_count") == 0
        and failure.get("failed_qualification_failure_raw_sha256")
        == "7af1a52dc8a87ef5cce0011226fd864c5b5adf0fcb13f490f755484c32e42153"
        and failure.get("failed_provenance_gate_receipt_raw_sha256")
        == "ff4b2cb40b2266f732bb3e2d8f4231a39763000dff0086cd35ed8ca9b4a91558"
        and failure.get("failed_provenance_gate_stderr_raw_sha256")
        == "c86307962f5f9a2eddceca51702956d89c049e2c142fa59947ad830ebb098dca"
        and failure.get("failed_qualification_retained_file_count") == 13
        and failure.get("failed_qualification_retained_byte_count") == 12653
        and failure.get("current_gitattributes_raw_sha256")
        == current_attributes_sha256
        and checkout_filter_migration.get("current_gitattributes_raw_sha256")
        == current_attributes_sha256
        and failure.get("current_gitattributes_byte_length")
        == ATTRIBUTES.stat().st_size
        and failure.get("top_level_current_identity_rebound") is True
        and failure.get("historical_rule_extension_receipt_rewritten") is False
        and failure.get("historical_r23d67_qualification_result_rewritten")
        is False
        and failure.get("failed_qualification_retained") is True
        and failure.get("failed_qualification_reusable") is False
        and failure.get("same_source_qualification_rerun_allowed") is False
        and failure.get(
            "qualification_retry_requires_distinct_corrected_clean_pushed_source"
        )
        is True
        and failure.get(
            "threshold_selector_evaluator_result_or_interpretation_change_count"
        )
        == 0
        and failure.get("r23d78_physical_world_count") == 0
        and failure.get("r23d78_turning_claim_changed") is False
        and failure.get("physical_acceptance_authority") is False
        and failure.get("release_authority") is False
        and late_inventory.get("maintenance_question_class")
        == "equivalence_non_inferiority"
        and late_inventory.get("physical_question_class_inherited_unchanged")
        == "finite_decision"
        and late_inventory.get("r23d76_closure_audit_creation_commit")
        == "ae73563261654d9d272e1ede14336d64eb5a1fcc"
        and late_inventory.get("r23d78_failed_qualification_source_commit")
        == failure.get("failed_source_commit")
        and late_inventory.get(
            "r23d78_failed_qualification_reached_inventory_assertion"
        )
        is False
        and late_inventory.get(
            "detected_during_distinct_corrected_successor_preparation"
        )
        is True
        and late_inventory.get("inventory_population_compared_completely") is True
        and late_inventory.get("inventory_sampling_claimed") is False
        and late_inventory.get("pre_reconciliation_audit_count") == 183
        and late_inventory.get("post_reconciliation_audit_count") == 184
        and late_inventory.get("added_audit_count") == 1
        and late_inventory.get("changed_audit_count") == 0
        and late_inventory.get("removed_audit_count") == 0
        and late_inventory.get("manual_review_required_count_delta") == 1
        and inventory.get("audit_count") == 184
        and inventory.get("manual_review_required_count") == 28
        and isinstance(added_entry, dict)
        and added_entry in inventory.get("entries", [])
        and late_inventory.get("historical_r23d76_result_reinterpreted") is False
        and late_inventory.get("r23d78_physical_world_count") == 0
        and late_inventory.get("r23d78_turning_claim_changed") is False
        and late_inventory.get("physical_acceptance_authority") is False
        and late_inventory.get("release_authority") is False
    )
    if not exact:
        raise ManifestError("R23D78_ATTESTATION_PROVENANCE_RECONCILIATION_INVALID")
    return failure, late_inventory


def _gate(
    ordinal: int,
    gate_id: str,
    role: str,
    path: Path,
    arguments: list[str],
    marker: str,
) -> dict[str, Any]:
    return {
        "ordinal": ordinal,
        "gate_id": gate_id,
        "role": role,
        "invocation_kind": "powershell_file",
        "path": _relative(path),
        "arguments": arguments,
        "terminal_marker_prefix": marker,
        "raw_sha256": _raw_sha256(path),
    }


def compose() -> dict[str, Any]:
    implementation = _load_implementation()
    declaration = _load_declaration()
    qualification_failure, late_inventory = _load_provenance_reconciliation()
    implementation_hash = _raw_sha256(IMPLEMENTATION)
    role_hash = _raw_sha256(ROLE_GATE)
    lineage = [
        _gate(
            1,
            "R23D78-COMPLETE-ZERO-WORLD",
            "lineage",
            ZERO_WORLD_GATE,
            [
                "-Godot",
                "<canonical-godot>",
                "-PowerShell",
                "pwsh",
                "-ExpectProductionConformanceLockHeld",
            ],
            "[turning/3e] R23D78 complete zero-world PASS ",
        )
    ]
    roles = [
        _gate(
            2,
            "R23D78-WORKER-ROLE",
            "worker",
            ROLE_GATE,
            [
                "-Role",
                "worker",
                "-Python",
                "<python>",
                "-Godot",
                "<canonical-godot>",
                "-PowerShell",
                "pwsh",
            ],
            "QSDK_R23D78_CAMPAIGN_WORKER_ROLE_PASS ",
        ),
        _gate(
            3,
            "R23D78-EVALUATOR-ROLE",
            "evaluator",
            ROLE_GATE,
            [
                "-Role",
                "evaluator",
                "-Python",
                "<python>",
                "-Godot",
                "<canonical-godot>",
                "-PowerShell",
                "pwsh",
            ],
            "QSDK_R23D78_CAMPAIGN_EVALUATOR_ROLE_PASS ",
        ),
        _gate(
            4,
            "R23D78-SUPERVISOR-ROLE",
            "supervisor",
            ROLE_GATE,
            [
                "-Role",
                "supervisor",
                "-Python",
                "<python>",
                "-Godot",
                "<canonical-godot>",
                "-PowerShell",
                "pwsh",
            ],
            "QSDK_R23D78_CAMPAIGN_SUPERVISOR_ROLE_PASS ",
        ),
    ]
    role_bindings = [
        {
            "role": "worker",
            "source_path": _relative(IMPLEMENTATION),
            "source_raw_sha256": implementation_hash,
            "test_gate_id": "R23D78-WORKER-ROLE",
            "test_path": _relative(ROLE_GATE),
            "test_raw_sha256": role_hash,
        },
        {
            "role": "evaluator",
            "source_path": _relative(EVALUATOR),
            "source_raw_sha256": _raw_sha256(EVALUATOR),
            "test_gate_id": "R23D78-EVALUATOR-ROLE",
            "test_path": _relative(ROLE_GATE),
            "test_raw_sha256": role_hash,
        },
        {
            "role": "supervisor",
            "source_path": _relative(SUPERVISOR),
            "source_raw_sha256": _raw_sha256(SUPERVISOR),
            "test_gate_id": "R23D78-SUPERVISOR-ROLE",
            "test_path": _relative(ROLE_GATE),
            "test_raw_sha256": role_hash,
        },
    ]
    source_digests = dict(implementation["dependency_digests"])
    for path in (
        IMPLEMENTATION,
        DECLARATION,
        SELF,
        ZERO_WORLD_GATE,
        ROLE_GATE,
        EVALUATOR,
        SUPERVISOR,
        PROVENANCE_CONTRACT,
        PROVENANCE_INVENTORY,
        PROVENANCE_GATE,
    ):
        source_digests[_relative(path)] = _raw_sha256(path)
    source_bindings = [
        {"path": path, "raw_sha256": source_digests[path]}
        for path in sorted(source_digests)
    ]
    smoke = declaration["post_zero_world_native_smoke"]
    return {
        "schema_version": "sporespore_locomotion_campaign_attestation_manifest_v1",
        "status": "prospective_zero_world_physical_candidate",
        "campaign_id": CAMPAIGN_ID,
        "question_class": "finite_decision",
        "declared_physical_world_count": 9,
        "physical_launch_candidate": True,
        "godot_including": True,
        "skip_godot": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "declared_lineage_gate_count": 1,
        "declared_campaign_gate_count": 3,
        "declared_total_gate_count": 4,
        "declared_role_binding_count": 3,
        "lineage_gates": lineage,
        "campaign_gates": roles,
        "campaign_role_bindings": role_bindings,
        "dependency_authority": {
            "path": _relative(IMPLEMENTATION),
            "raw_sha256": implementation_hash,
        },
        "native_smoke_waiver": {
            "declaration_path": _relative(DECLARATION),
            "declaration_raw_sha256": _raw_sha256(DECLARATION),
            "new_smoke_required": False,
            "r23d76_complete_native_horizon_count": smoke[
                "r23d76_complete_native_horizon_count_used_for_route_adequacy"
            ],
            "r23d76_reused_as_r23d78_result": False,
            "maximum_world_count": 0,
            "maximum_solver_step_count": 0,
            "behavior_outcome_evaluated": False,
            "precise_invalidation": smoke["precise_invalidation"],
        },
        "qualification_runtime_partition": {
            "outer_commissioned_runtime_python_recorded_by_attestation": True,
            "lineage_outer_python_argument_forwarded": False,
            "lineage_mujoco_python_resolution": (
                "tests/test_qsdk_r23d78_zero_world.ps1 default "
                "sdk/adapters/mujoco/.venv/Scripts/python.exe"
            ),
            "reason": (
                "The generic commissioned Python identifies and executes the outer "
                "attestation kernel. The complete R23D78 lineage gate exercises the "
                "native MuJoCo route and therefore resolves its already-qualified "
                "repository MuJoCo environment instead of overriding it with the "
                "outer interpreter."
            ),
            "first_test_only_ghost": {
                "status": "retained_non_official_runtime_partition_failure",
                "root": (
                    "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
                    "r23d78-successor-campaign-gates-testonly-20260826T1725Z"
                ),
                "source_commit": "0e47997990617ee5582b6ebacd552ad4a29378af",
                "test_only": True,
                "global_gates_skipped": True,
                "failed_gate_ordinal": 1,
                "failed_gate_id": "R23D78-COMPLETE-ZERO-WORLD",
                "failure_code": "outer_system_python_missing_mujoco_module",
                "retained_file_count": 4,
                "retained_byte_count": 4355,
                "failure_raw_sha256": (
                    "sha256:bfa100397caad4cf8ebc8b8b70f86e0ab0a7b9a588ef03e56318b90d3f2c670c"
                ),
                "gate_receipt_raw_sha256": (
                    "sha256:cdae0556fb9095423ee6b1c918ed8af6d1901babdf20ed928432da87cdd95989"
                ),
                "stderr_raw_sha256": (
                    "sha256:ffd344ab7dd1809845e18994625dfd8686165c94b828c941733a599a5ab2f042"
                ),
                "physical_process_launch_count": 0,
                "physical_world_count": 0,
                "model_construction_count": 0,
                "solver_step_count": 0,
                "physical_acceptance_authority": False,
                "release_authority": False,
            },
            "correction": (
                "Remove only the outer <python> override from the lineage-gate "
                "arguments so the unchanged zero-world gate resolves its declared "
                "MuJoCo environment."
            ),
            "campaign_semantics_changed": False,
            "threshold_selector_evaluator_result_or_interpretation_change_count": 0,
            "physical_world_count": 0,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "qualification_predecessor_failure": {
            "status": "retained_failed_closed_global_gate_4_before_campaign_roles",
            "process_question_class": qualification_failure[
                "qualification_process_question_class"
            ],
            "physical_question_class_inherited_unchanged": qualification_failure[
                "physical_question_class_inherited_unchanged"
            ],
            "source_commit": qualification_failure["failed_source_commit"],
            "source_tree_git_oid": qualification_failure[
                "failed_source_tree_git_oid"
            ],
            "qualification_root": qualification_failure[
                "failed_qualification_root"
            ],
            "passed_global_gate_count": qualification_failure[
                "failed_qualification_passed_gate_count"
            ],
            "failed_gate_ordinal": 4,
            "failed_gate_id": qualification_failure[
                "failed_qualification_gate_id"
            ],
            "campaign_role_gate_count": qualification_failure[
                "failed_qualification_campaign_role_gate_count"
            ],
            "model_construction_count": qualification_failure[
                "failed_qualification_model_construction_count"
            ],
            "world_attempt_count": qualification_failure[
                "failed_qualification_world_attempt_count"
            ],
            "world_build_count": qualification_failure[
                "failed_qualification_world_build_count"
            ],
            "solver_step_count": qualification_failure[
                "failed_qualification_solver_step_count"
            ],
            "failure_code": qualification_failure["failure_code"],
            "retained_file_count": qualification_failure[
                "failed_qualification_retained_file_count"
            ],
            "retained_byte_count": qualification_failure[
                "failed_qualification_retained_byte_count"
            ],
            "critical_evidence": [
                {
                    "path": qualification_failure[
                        "failed_qualification_failure_path"
                    ],
                    "raw_sha256": "sha256:"
                    + qualification_failure[
                        "failed_qualification_failure_raw_sha256"
                    ],
                    "byte_length": qualification_failure[
                        "failed_qualification_failure_byte_length"
                    ],
                },
                {
                    "path": qualification_failure[
                        "failed_provenance_gate_receipt_path"
                    ],
                    "raw_sha256": "sha256:"
                    + qualification_failure[
                        "failed_provenance_gate_receipt_raw_sha256"
                    ],
                    "byte_length": qualification_failure[
                        "failed_provenance_gate_receipt_byte_length"
                    ],
                },
                {
                    "path": qualification_failure[
                        "failed_provenance_gate_stderr_path"
                    ],
                    "raw_sha256": "sha256:"
                    + qualification_failure[
                        "failed_provenance_gate_stderr_raw_sha256"
                    ],
                    "byte_length": qualification_failure[
                        "failed_provenance_gate_stderr_byte_length"
                    ],
                },
            ],
            "same_source_rerun_allowed": False,
            "distinct_corrected_clean_pushed_source_required": True,
            "threshold_selector_evaluator_result_or_interpretation_change_count": 0,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "provenance_reconciliation": {
            "contract_path": _relative(PROVENANCE_CONTRACT),
            "contract_raw_sha256": _raw_sha256(PROVENANCE_CONTRACT),
            "inventory_path": _relative(PROVENANCE_INVENTORY),
            "inventory_raw_sha256": _raw_sha256(PROVENANCE_INVENTORY),
            "gate_path": _relative(PROVENANCE_GATE),
            "gate_raw_sha256": _raw_sha256(PROVENANCE_GATE),
            "current_gitattributes_raw_sha256": "sha256:"
            + qualification_failure["current_gitattributes_raw_sha256"],
            "complete_inventory_population_size": late_inventory[
                "inventory_population_size"
            ],
            "complete_inventory_population_compared": True,
            "added_audit_count": late_inventory["added_audit_count"],
            "changed_audit_count": late_inventory["changed_audit_count"],
            "removed_audit_count": late_inventory["removed_audit_count"],
            "added_entry": late_inventory["added_entry"],
            "historical_result_reinterpreted": False,
            "physical_world_count": 0,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "source_bindings": source_bindings,
        "claims": {
            "campaign_local_qualification_passed": False,
            "cold_commissioning_complete": False,
            "physical_launch_prerequisite_satisfied": False,
            "physical_campaign_executed": False,
            "scientific_result": False,
            "walking_acceptance": False,
            "turning_acceptance": False,
            "cross_engine_equivalence": False,
            "arbitrary_quadruped_coverage": False,
            "release_authority": False,
            "physical_acceptance_authority": False,
        },
    }


def _raw_document(value: dict[str, Any]) -> bytes:
    return (
        json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            indent=2,
            sort_keys=False,
        )
        + "\n"
    ).encode("utf-8")


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("write", "check", "print"))
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    value = compose()
    raw = _raw_document(value)
    if arguments.command == "write":
        OUTPUT.write_bytes(raw)
    elif arguments.command == "check":
        if not OUTPUT.is_file() or OUTPUT.read_bytes() != raw:
            raise ManifestError("R23D78_ATTESTATION_MANIFEST_MATERIALIZATION_DRIFT")
    else:
        sys.stdout.buffer.write(raw)
        return 0
    print(
        "QSDK_R23D78_ATTESTATION_MANIFEST "
        + json.dumps(
            {
                "path": _relative(OUTPUT),
                "raw_sha256": _raw_sha256(OUTPUT),
                "source_binding_count": len(value["source_bindings"]),
                "lineage_gate_count": 1,
                "campaign_gate_count": 3,
                "native_smoke_waiver_bound": True,
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "physical_execution_authorized": False,
                "physical_acceptance_authority": False,
            },
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
