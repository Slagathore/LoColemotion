#!/usr/bin/env python3
"""Compact source/preflight authority for R24D93 native-engine health."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "sdk/recovery/r24d93_godot_jolt_native_engine_health_contract_v1.json"
EXPECTED_ROOT = "C:/Users/Cole/CodeStuff/games/SporeSpore"
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
PASS_MARKER = "QSDK_R24D93_GODOT_JOLT_NATIVE_ENGINE_HEALTH_SOURCE_PASS"
PS_MARKER = "SPORESPORE_GODOT_ENGINE_HEALTH_PROJECTION_PASS "


class AuditFailure(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditFailure(code)


def _reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        require(key not in value, f"DUPLICATE_KEY:{key}")
        value[key] = item
    return value


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_bytes(), object_pairs_hook=_reject_duplicates)
    require(isinstance(value, dict), f"JSON_ROOT:{path.as_posix()}")
    return value


def sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(
        ["git", *args], cwd=ROOT, text=True, encoding="utf-8", errors="strict"
    ).strip()


def require_tokens(path: Path, tokens: tuple[str, ...], label: str) -> None:
    text = path.read_text(encoding="utf-8")
    for token in tokens:
        require(token in text, f"{label}_TOKEN:{token}")


def validate_contract() -> dict[str, Any]:
    require(Path(git("rev-parse", "--show-toplevel")).as_posix() == EXPECTED_ROOT, "ROOT")
    require(git("remote", "get-url", "origin") == EXPECTED_REMOTE, "REMOTE")
    contract = load(CONTRACT)
    fixed = {
        "schema_version": "sporespore_qsdk_r24d93_godot_jolt_native_engine_health_contract_v1",
        "gate_id": "QSDK-R24D93",
        "status": "declared_zero_world_native_engine_health_coverage_physics_blocked",
        "question_class": "development",
        "physical_question_declared": False,
        "finite_decision_declared": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False,
    }
    for key, expected in fixed.items():
        require(contract.get(key) == expected, f"CONTRACT:{key}")
    require(
        contract["ledger_scope"]
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "prospective_zero_world_source_qualification",
            "question_class": "development",
        },
        "LEDGER_SCOPE",
    )

    inventory = tuple(contract["source_inventory"])
    physical = tuple(contract["qualified_physical_paths"])
    publication = tuple(contract["publication_only_paths"])
    authored = tuple(contract["authored_source_paths"])
    require((len(inventory), len(set(inventory))) == (65, 65), "SOURCE_COUNT")
    require((len(physical), len(set(physical))) == (47, 47), "PHYSICAL_COUNT")
    require((len(publication), len(set(publication))) == (18, 18), "PUBLICATION_COUNT")
    require((len(authored), len(set(authored))) == (16, 16), "AUTHORED_COUNT")
    require(tuple(sorted(inventory)) == inventory, "SOURCE_ORDER")
    require(tuple(sorted(physical)) == physical, "PHYSICAL_ORDER")
    require(tuple(sorted(publication)) == publication, "PUBLICATION_ORDER")
    require(tuple(sorted(authored)) == authored, "AUTHORED_ORDER")
    require(set(physical).isdisjoint(publication), "PATH_ROLE_OVERLAP")
    require(set(inventory) == set(physical) | set(publication), "PATH_ROLE_UNION")
    require(set(authored).issubset(inventory), "AUTHORED_SUBSET")
    for relative in inventory:
        require((ROOT / relative).is_file(), f"SOURCE_MISSING:{relative}")

    predecessor = contract["bound_predecessor"]
    predecessor_path = ROOT / predecessor["path"]
    require(predecessor_path.stat().st_size == predecessor["byte_length"], "PREDECESSOR_LENGTH")
    require(sha256(predecessor_path) == predecessor["raw_sha256"], "PREDECESSOR_HASH")
    require(predecessor["same_identity_rerun_permitted"] is False, "R92_RERUN")

    gate = contract["complete_zero_world_gate"]
    expected_gate = {
        "must_pass_before_physics": True,
        "official_qualification_attempt_maximum": 1,
        "powershell_positive_case_count": 2,
        "powershell_forced_failure_case_count": 5,
        "native_positive_case_count": 2,
        "native_forced_failure_case_count": 8,
        "production_worker_parse_count": 1,
        "historical_closure_audits_executed_count": 0,
        "full_seeded_ghost_count": 0,
        "bespoke_physical_canary_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_opened": False,
        "held_out_cell_access_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    for key, expected in expected_gate.items():
        require(gate.get(key) == expected, f"ZERO_WORLD:{key}")

    adequacy = contract["threshold_margin_cohort_and_population_adequacy"]
    require(adequacy["engine_limit_is_campaign_authored_threshold"] is False, "LIMIT_ORIGIN")
    require(adequacy["comparison_margin_rad_s"] == 0.0, "LIMIT_MARGIN")
    require(adequacy["zero_world_positive_case_count"] == 4, "POSITIVE_ADEQUACY")
    require(adequacy["zero_world_forced_failure_case_count"] == 13, "NEGATIVE_ADEQUACY")
    require(contract["claim_boundary"]["physical_execution_authorized"] is False, "PHYSICS")
    return contract


def validate_source_integration() -> None:
    require_tokens(
        ROOT / "sdk/godot_receipt_terminated_process.ps1",
        (
            "function Get-SporeSporeGodotEngineHealthProjection",
            'selector_id = "godot_typed_fatal_diagnostic_selector_v1"',
            '$trimmed.StartsWith("ERROR:"',
            '"Jolt Physics assertion"',
            '"at: jolt_assert"',
            "passed = $fatalLines.Count -eq 0",
        ),
        "POWERSHELL_ENGINE_HEALTH",
    )
    require_tokens(
        ROOT / "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1",
        (
            "$engineHealth = Get-SporeSporeGodotEngineHealthProjection",
            "[bool]$engineHealth.passed -and",
            "engine_health = $engineHealth",
            "native_engine_health_passed = [bool]$engineHealth.passed",
        ),
        "SHARED_SUPERVISOR",
    )
    require_tokens(
        ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
        (
            '"physics/jolt_physics_3d/limits/max_angular_velocity"',
            "static func jolt_angular_velocity_limit_runtime_projection_v1()",
            "static func body_angular_velocity_limit_receipt_v1(",
            '"QSDK_R24D93_ANGULAR_VELOCITY_LIMIT_EXCEEDED"',
            '"native_engine_health_receipt": native_engine_health_receipt',
            '"native_engine_health_receipt_sha256": native_engine_health_receipt_sha256',
        ),
        "NATIVE_WORLD",
    )
    require_tokens(
        ROOT / "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd",
        (
            '"native_engine_health_receipt": native_engine_health_receipt.duplicate(true)',
            '"native_engine_health_receipt_sha256": String(',
            "func _native_engine_health_receipt_valid(",
            "NativeWorldScript.BODY_ANGULAR_VELOCITY_LIMIT_RECEIPT_SCHEMA",
        ),
        "PRODUCTION_WORKER",
    )
    require_tokens(
        ROOT / "sdk/run_qsdk_r24d93_godot_jolt_force_based_recovery_behavior.ps1",
        (
            'throw "QSDK_R24D93_PHYSICAL_QUESTION_NOT_DECLARED"',
            'GateId = "QSDK-R24D93"',
            'SourceAuditRelativePath =',
            '"sdk/conformance/r24d93_godot_jolt_native_engine_health.py"',
        ),
        "R93_WRAPPER",
    )


def run_powershell_projection_test() -> dict[str, Any]:
    completed = subprocess.run(
        ["pwsh", "-NoProfile", "-File", "tests/test_godot_engine_health_projection.ps1"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
        check=False,
    )
    require(completed.returncode == 0, f"PS_TEST_EXIT:{completed.stderr}")
    lines = [line for line in completed.stdout.splitlines() if line.startswith(PS_MARKER)]
    require(len(lines) == 1, "PS_TEST_MARKER")
    receipt = json.loads(lines[0][len(PS_MARKER) :])
    expected = {
        "schema_version": "sporespore_godot_engine_health_projection_test_v1",
        "ok": True,
        "positive_case_count": 2,
        "forced_failure_case_count": 5,
        "typed_fatal_selector_count": 6,
        "jolt_assertion_failure_line_count": 2,
        "jolt_assertion_site_line_count": 2,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    require(receipt == expected, "PS_TEST_RECEIPT")
    return receipt


def run_wrapper_controls(contract: dict[str, Any]) -> dict[str, Any]:
    wrapper = "sdk/run_qsdk_r24d93_godot_jolt_force_based_recovery_behavior.ps1"
    refused = subprocess.run(
        ["pwsh", "-NoProfile", "-File", wrapper, "-Mode", "Physical", "-RunPhysical"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
        check=False,
    )
    require(refused.returncode != 0, "PHYSICAL_REFUSAL_EXIT")
    require("QSDK_R24D93_PHYSICAL_QUESTION_NOT_DECLARED" in refused.stderr, "PHYSICAL_REFUSAL")

    runtime = contract["exact_runtime"]
    require(Path(runtime["console_path"]).is_file(), "CONSOLE_MISSING")
    require(Path(runtime["console_path"]).stat().st_size == runtime["console_byte_length"], "CONSOLE_LENGTH")
    require(sha256(Path(runtime["console_path"])) == runtime["console_sha256"], "CONSOLE_HASH")
    return {
        "physical_refusal_count": 1,
        "runtime_id": runtime["runtime_profile_id"],
        "runtime_version": runtime["runtime_version"],
    }


def validate_live_authorities() -> None:
    expected = {
        "r24d93_question_class": "development",
        "r24d93_physical_question_declared": False,
        "r24d93_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
        "r24d93_shared_engine_diagnostic_invariant_required": True,
        "r24d93_complete_body_angular_velocity_limit_invariants_required": True,
        "r24d93_physical_execution_authorized": False,
        "held_out_cells_remain_sealed": True,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    for relative in (
        "sdk/release/quadruped_release_contract.json",
        "sdk/release/quadruped_support_matrix.json",
    ):
        raw = (ROOT / relative).read_text(encoding="utf-8")
        for key in expected:
            if key.startswith("r24d93_") or key.startswith(
                "physical_execution_blocked_until_r24d93"
            ):
                require(raw.count(json.dumps(key)) == 1, f"LIVE_KEY_COUNT:{relative}:{key}")
        authority = json.loads(raw)
        record = authority
        # Both live files use a large nested record; recursively find the unique R93 contract key.
        matches: list[dict[str, Any]] = []

        def visit(value: Any) -> None:
            if isinstance(value, dict):
                if value.get("r24d93_contract_path") == expected["r24d93_contract_path"]:
                    matches.append(value)
                for child in value.values():
                    visit(child)
            elif isinstance(value, list):
                for child in value:
                    visit(child)

        visit(record)
        require(len(matches) == 1, f"LIVE_RECORD:{relative}")
        for key, value in expected.items():
            require(matches[0].get(key) == value, f"LIVE:{relative}:{key}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--core-library", default="")
    args = parser.parse_args()
    contract = validate_contract()
    validate_source_integration()
    ps_receipt = run_powershell_projection_test()
    wrapper = run_wrapper_controls(contract)
    validate_live_authorities()
    counts = {
        "source_inventory_count": 65,
        "qualified_physical_path_count": 47,
        "publication_only_path_count": 18,
        "authored_source_path_count": 16,
        "powershell_positive_case_count": ps_receipt["positive_case_count"],
        "powershell_forced_failure_case_count": ps_receipt["forced_failure_case_count"],
        "wrapper_physical_refusal_count": wrapper["physical_refusal_count"],
        "native_positive_case_count": 2,
        "native_forced_failure_case_count": 8,
        "production_worker_parse_count": 1,
        "historical_closure_audits_executed_count": 0,
        "full_seeded_ghost_count": 0,
        "bespoke_physical_canary_count": 0,
    }
    print(PASS_MARKER + " " + json.dumps(counts, sort_keys=True))
    if args.core_library:
        core = (ROOT / args.core_library).resolve()
        require(core.is_file(), "CORE_LIBRARY")
        print(
            json.dumps(
                {
                    "schema_version": "sporespore_qsdk_r24d93_native_engine_health_preflight_v1",
                    "gate_id": "QSDK-R24D93",
                    "ok": True,
                    "runtime_id": wrapper["runtime_id"],
                    "runtime_version": wrapper["runtime_version"],
                    "core_library_path": core.as_posix(),
                    "core_library_raw_sha256": sha256(core),
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "physics_state_modified": False,
                    "physical_question_opened": False,
                    "prone_to_standing_claimed": False,
                    "physical_acceptance_authority": False,
                    "release_authority": False,
                },
                separators=(",", ":"),
            )
        )


if __name__ == "__main__":
    try:
        main()
    except (AuditFailure, OSError, subprocess.SubprocessError, json.JSONDecodeError) as exc:
        print(f"{PASS_MARKER}_FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
