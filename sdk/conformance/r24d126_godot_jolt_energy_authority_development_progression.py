#!/usr/bin/env python3
"""Compact R126 source audit and real-library malformed-route preflight."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    load,
    loads,
    require,
    sha256,
    source_bytes,
    verify_legacy_live_authority_projection,
    verify_zero_world_qualification_closure,
)
from sdk.python.sporespore_locomotion import (  # noqa: E402
    SS_CORE_ERROR,
    LocomotionCore,
    LocomotionCoreError,
)

CONTRACT = ROOT / (
    "sdk/recovery/"
    "r24d126_godot_jolt_energy_authority_development_progression_contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/"
    "r24d126_godot_jolt_energy_authority_development_progression_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE_PASS = (
    "QSDK_R24D126_GODOT_JOLT_ENERGY_AUTHORITY_DEVELOPMENT_PROGRESSION_SOURCE_PASS"
)
SOURCE_FAIL = (
    "QSDK_R24D126_GODOT_JOLT_ENERGY_AUTHORITY_DEVELOPMENT_PROGRESSION_SOURCE_FAIL"
)
CLOSURE_PASS = (
    "QSDK_R24D126_GODOT_JOLT_ENERGY_AUTHORITY_DEVELOPMENT_PROGRESSION_"
    "QUALIFICATION_CLOSURE_PASS"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_incomplete_energy_authority_development_"
    "progression_qualified_successor_declaration_required"
)
EXPECTED_CHECKS = (
    "source_manifest_frozen",
    "core_dynamic_library_rebuilt",
    "core_targeted_tests_passed",
    "godot_adapter_binding_check_passed",
    "godot_adapter_debug_build_passed",
    "godot_production_worker_parse_passed",
    "native_zero_world_gate_passed",
    "python_binding_smoke_passed",
    "versioning_conformance_passed",
    "source_contract_audit_passed",
    "production_preflight_passed",
    "worktree_unchanged",
)


def _identity(path: Path) -> tuple[str, int]:
    raw = path.read_bytes()
    return sha256(raw), len(raw)


def _audit_source() -> dict[str, object]:
    contract = load(CONTRACT)
    exact(
        contract["schema_version"],
        "sporespore_qsdk_r24d126_godot_jolt_energy_authority_development_progression_contract_v1",
        "CONTRACT_SCHEMA",
    )
    exact(contract["gate_id"], "QSDK-R24D126", "GATE_ID")
    exact(contract["question_class"], "development", "QUESTION_CLASS")
    exact(
        contract["ledger_scope"],
        {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": (
                "prospective_zero_world_versioned_energy_authority_"
                "development_progression_implementation"
            ),
            "question_class": "development",
        },
        "LEDGER_SCOPE",
    )
    for field in (
        "physical_question_declared",
        "finite_decision_declared",
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
        "physical_execution_authorized",
    ):
        exact(contract[field], False, f"ZERO_AUTHORITY:{field}")

    predecessor = contract["predecessor"]
    predecessor_path = ROOT / predecessor["path"]
    exact(
        _identity(predecessor_path),
        (predecessor["raw_sha256"], predecessor["byte_length"]),
        "PREDECESSOR_IDENTITY",
    )
    authority = contract["registered_authority_profile"]
    exact(
        _identity(ROOT / authority["authority_source_path"])[0],
        authority["authority_source_raw_sha256"],
        "ENERGY_AUTHORITY_SOURCE",
    )
    exact(authority["component_partition_complete"], False, "PARTITION_COMPLETE")
    exact(authority["exact_balance_safety_authority"], False, "EXACT_AUTHORITY")
    exact(authority["unclosed_energy_residual_preserved"], True, "RESIDUAL")
    exact(authority["residual_balancing_permitted"], False, "RESIDUAL_BALANCING")
    exact(authority["development_progression_permitted"], True, "DEVELOPMENT")
    exact(authority["physical_acceptance_authority"], False, "ACCEPTANCE")
    exact(authority["release_authority"], False, "RELEASE")

    inventory = contract["source_inventory"]
    require(len(inventory) == len(set(inventory)), "SOURCE_INVENTORY_DUPLICATE")
    require(all((ROOT / item).is_file() for item in inventory), "SOURCE_INVENTORY")

    abi = load(ROOT / "sdk/versioning/c_abi_manifest_v1.json")
    symbols = {item["name"]: item for item in abi["symbols"]}
    exact(
        symbols["ss_recovery_step_v5_json"]["input_schema"],
        "sporespore_recovery_step_request_v5",
        "V5_ABI_SCHEMA",
    )
    registry = load(ROOT / "sdk/versioning/schema_registry_v1.json")
    schema_ids = {item["schema_id"] for item in registry["schemas"]}
    expected_schemas = {
        "sporespore_recovery_energy_partition_authority_v1",
        "sporespore_recovery_step_request_v5",
        "sporespore_recovery_step_receipt_v2",
        "sporespore_recovery_development_progression_receipt_v1",
    }
    require(expected_schemas <= schema_ids, "R126_SCHEMA_REGISTRY")

    runtime = contract["exact_runtime"]
    exact(
        _identity(Path(runtime["console_path"])),
        (runtime["console_sha256"], runtime["console_byte_length"]),
        "EXACT_RUNTIME",
    )
    zero_world = contract["complete_zero_world_gate"]
    exact(zero_world["forced_failure_production_preflight_count"], 1, "PREFLIGHT_COUNT")
    for field in (
        "historical_closure_audits_executed_count",
        "bespoke_physical_canary_count",
        "full_seeded_ghost_count",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(zero_world[field], 0, f"ZERO_WORLD:{field}")
    exact(zero_world["physics_state_modified"], False, "PHYSICS_STATE")
    return {
        "schema_version": "sporespore_qsdk_r24d126_source_audit_receipt_v1",
        "gate_id": "QSDK-R24D126",
        "ok": True,
        "source_inventory_count": len(inventory),
        "registered_schema_count": len(expected_schemas),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _preflight(core_library: Path) -> dict[str, object]:
    core = LocomotionCore(core_library)
    try:
        core.recovery_step_v5({})
    except LocomotionCoreError as error:
        exact(error.status, SS_CORE_ERROR, "PREFLIGHT_STATUS")
        exact(error.failure_code, "SCHEMA_INVALID", "PREFLIGHT_FAILURE_CODE")
        require("schema_version" in error.detail, "PREFLIGHT_DETAIL")
    else:
        raise ClosureAuditError("PREFLIGHT_MALFORMED_REQUEST_ACCEPTED")
    return {
        "schema_version": "sporespore_qsdk_r24d126_production_preflight_v1",
        "gate_id": "QSDK-R24D126",
        "ok": True,
        "runtime_id": "sporespore_locomotion_core_c_abi",
        "runtime_version": core.version,
        "malformed_request_refused": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _verify_qualification_closure() -> dict[str, object]:
    closure = load(CLOSURE)
    exact(
        (
            closure["schema_version"],
            closure["gate_id"],
            closure["closure_status"],
            closure["question_class"],
        ),
        (
            (
                "sporespore_qsdk_r24d126_godot_jolt_energy_authority_"
                "development_progression_zero_world_qualification_closure_v1"
            ),
            "QSDK-R24D126",
            QUALIFIED_STATUS,
            "development",
        ),
        "CLOSURE_IDENTITY",
    )
    for field in (
        "physical_question_declared",
        "finite_decision_declared",
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        exact(closure[field], False, f"CLOSURE_AUTHORITY:{field}")

    source = closure["source"]
    source_commit = source["commit"]
    exact(git(ROOT, "rev-parse", f"{source_commit}^"), source["parent_commit"], "PARENT")
    exact(git(ROOT, "show", "-s", "--format=%T", source_commit), source["tree"], "TREE")
    exact(
        git(ROOT, "show", "-s", "--format=%s", source_commit),
        source["subject"],
        "SUBJECT",
    )
    for reference in ("HEAD", "origin/main"):
        git(ROOT, "merge-base", "--is-ancestor", source_commit, reference)
    exact(
        git(ROOT, "rev-parse", f"{source_commit}:{source['contract_path']}"),
        source["contract_git_blob_oid"],
        "CONTRACT_BLOB",
    )

    predecessor = closure["predecessor"]
    predecessor_path = ROOT / predecessor["path"]
    exact(
        _identity(predecessor_path),
        (predecessor["raw_sha256"], predecessor["byte_length"]),
        "CLOSURE_PREDECESSOR",
    )
    exact(load(predecessor_path)["status"], predecessor["status"], "PREDECESSOR_STATUS")

    frozen_contract = loads(source_bytes(ROOT, source_commit, source["contract_path"]))
    qualification = closure["qualification"]
    _attempt, receipt, preflight = verify_zero_world_qualification_closure(
        root=ROOT,
        closure=closure,
        gate_id="QSDK-R24D126",
        source_commit=source_commit,
        attempt_schema=qualification["attempt_schema"],
        receipt_schema=qualification["receipt_schema"],
        qualification_directory_prefix=(
            "qsdk-r24d126-godot-jolt-energy-authority-development-"
            "progression-qualification-"
        ),
        contract_inventory=frozen_contract["source_inventory"],
        expected_checks=EXPECTED_CHECKS,
        source_manifest_raw_representation=qualification[
            "source_manifest_raw_representation"
        ],
    )
    exact(
        (
            receipt["contract_raw_sha256"],
            receipt["source_manifest"][0]["raw_sha256"],
            receipt["source_manifest"][0]["byte_length"],
        ),
        (
            source["contract_observed_checkout_raw_sha256"],
            source["contract_observed_checkout_raw_sha256"],
            source["contract_observed_checkout_byte_length"],
        ),
        "CONTRACT_CHECKOUT_IDENTITY",
    )
    native = receipt["native_zero_world"]
    exact(
        (
            native["ok"],
            native["authority_profile_id"],
            native["mutation_control_count"],
            native["mutation_rejection_count"],
            preflight["malformed_request_refused"],
        ),
        (
            True,
            "godot_jolt_r24d126_incomplete_energy_partition_authority_v1",
            7,
            7,
            True,
        ),
        "QUALIFIED_CONTROLS",
    )
    exact(
        (
            qualification["check_count"],
            qualification["checks_passed"],
            qualification["forced_failure_production_preflight_count"],
            qualification["historical_closure_audits_executed_count"],
            qualification["bespoke_physical_canary_count"],
            qualification["full_seeded_ghost_count"],
            qualification["physical_execution_count"],
        ),
        (len(EXPECTED_CHECKS), len(EXPECTED_CHECKS), 1, 0, 0, 0, 0),
        "QUALIFICATION_COUNTS",
    )
    runtime = closure["runtime_identity_projection"]
    exact(
        _identity(Path(runtime["godot_runtime_path"]))[0],
        runtime["godot_runtime_raw_sha256"],
        "RUNTIME",
    )

    decision = closure["decision"]
    exact(decision["development_progression_route_qualified"], True, "ROUTE_QUALIFIED")
    for field in (
        "component_partition_complete",
        "exact_balance_safety_authority",
        "residual_balancing_permitted",
        "incomplete_authority_can_accrue_completion_dwell",
        "incomplete_authority_can_authorize_physical_result",
        "incomplete_authority_can_claim_prone_to_standing",
        "physical_execution_authorized",
    ):
        exact(decision[field], False, f"DECISION:{field}")
    claim = closure["claim_boundary"]
    exact(claim["zero_world_source_implementation_qualified"], True, "QUALIFIED_CLAIM")
    for field, value in claim.items():
        if field != "zero_world_source_implementation_qualified" and isinstance(value, bool):
            exact(value, False, f"CLAIM:{field}")

    closure_raw = CLOSURE.read_bytes()
    closure_relative = CLOSURE.relative_to(ROOT).as_posix()
    audit_relative = Path(__file__).resolve().relative_to(ROOT).as_posix()
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d126_contract_path",
        expected={
            "r24d126_source_status": QUALIFIED_STATUS,
            "r24d126_source_commit": source_commit,
            "r24d126_zero_world_qualification_required": False,
            "r24d126_zero_world_qualification_complete": True,
            "r24d126_zero_world_qualified": True,
            "r24d126_zero_world_closure_path": closure_relative,
            "r24d126_zero_world_closure_raw_sha256": sha256(closure_raw),
            "r24d126_zero_world_closure_byte_length": len(closure_raw),
            "r24d126_zero_world_evidence_root": qualification["evidence_root"],
            "r24d126_qualification_attempt_raw_sha256": qualification[
                "attempt_raw_sha256"
            ],
            "r24d126_qualification_receipt_raw_sha256": qualification[
                "receipt_raw_sha256"
            ],
            "r24d126_qualification_check_count": len(EXPECTED_CHECKS),
            "r24d126_qualification_checks_passed": len(EXPECTED_CHECKS),
            "r24d126_qualification_model_construction_count": 0,
            "r24d126_qualification_world_attempt_count": 0,
            "r24d126_qualification_world_build_count": 0,
            "r24d126_qualification_solver_step_count": 0,
            "r24d126_physical_execution_authorized": False,
            "r24d126_prone_to_standing_claimed": False,
            "r24d126_sdk1_milestone_advanced": False,
            "r24d127_declaration_required": True,
            "next_gate_id": "QSDK-R24D127",
            "r24d126_qualification_closure_audit_path": audit_relative,
        },
        prefix="LIVE_R24D126_QUALIFICATION",
    )
    return {
        "schema_version": "sporespore_qsdk_r24d126_qualification_closure_audit_v1",
        "gate_id": "QSDK-R24D126",
        "ok": True,
        "source_commit": source_commit,
        "retained_file_count": qualification["retained_tree"]["file_count"],
        "check_count": len(EXPECTED_CHECKS),
        "mutation_control_count": native["mutation_control_count"],
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--core-library", type=Path)
    parser.add_argument("--verify-closure", action="store_true")
    arguments = parser.parse_args()
    try:
        source_receipt = _audit_source()
        if arguments.verify_closure:
            receipt = _verify_qualification_closure()
            print(CLOSURE_PASS + " " + json.dumps(receipt, sort_keys=True))
            return 0
        print(SOURCE_PASS + " " + json.dumps(source_receipt, sort_keys=True))
        if arguments.core_library is not None:
            print(json.dumps(_preflight(arguments.core_library), sort_keys=True))
        return 0
    except (
        ClosureAuditError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(SOURCE_FAIL + " " + json.dumps({"ok": False, "error": str(error)}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
