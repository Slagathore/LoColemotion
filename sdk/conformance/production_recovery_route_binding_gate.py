#!/usr/bin/env python3
"""Compact reusable source gate for a production recovery-route binding."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    exact,
    git,
    load,
    require,
    require_ordered_markers,
    resolve_prospective_source_freeze,
    sha256,
    verify_legacy_live_authority_projection,
)


def _verify_bound_file(root: Path, binding: dict[str, Any]) -> None:
    path = root / str(binding["path"])
    raw = path.read_bytes()
    exact(len(raw), binding["byte_length"], f"BOUND_LENGTH:{path}")
    exact(sha256(raw), binding["raw_sha256"], f"BOUND_HASH:{path}")


def _function_scope(source: str, start: str, end: str, code: str) -> str:
    start_index = source.find(start)
    require(start_index >= 0, f"{code}_START")
    end_index = source.find(end, start_index + len(start))
    require(end_index > start_index, f"{code}_END")
    return source[start_index:end_index]


def _verify_source_checks(root: Path, checks: list[dict[str, Any]]) -> None:
    for spec in checks:
        relative = str(spec["path"])
        source = (root / relative).read_text(encoding="utf-8")
        require_ordered_markers(
            source,
            tuple(str(value) for value in spec.get("ordered_markers", [])),
            f"ORDERED_MARKERS:{relative}",
        )
        for token, expected in spec.get("exact_substring_counts", {}).items():
            exact(source.count(str(token)), expected, f"TOKEN_COUNT:{relative}:{token}")
        for scope_spec in spec.get("function_scopes", []):
            scope = _function_scope(
                source,
                str(scope_spec["start_marker"]),
                str(scope_spec["end_marker"]),
                f"FUNCTION_SCOPE:{relative}",
            )
            for marker in scope_spec.get("required_markers", []):
                require(str(marker) in scope, f"FUNCTION_REQUIRED:{relative}:{marker}")
            for marker in scope_spec.get("forbidden_markers", []):
                require(str(marker) not in scope, f"FUNCTION_FORBIDDEN:{relative}:{marker}")


def validate_contract(
    root: Path,
    contract_relative_path: str,
    contract_schema: str,
    gate_id: str,
) -> tuple[dict[str, Any], bool]:
    contract = load(root / contract_relative_path)
    exact(
        (contract["schema_version"], contract["gate_id"]),
        (contract_schema, gate_id),
        "CONTRACT_IDENTITY",
    )
    exact(contract["question_class"], "development", "QUESTION_CLASS")
    exact(contract["physical_question_declared"], False, "PHYSICAL_QUESTION")
    exact(contract["physical_execution_authorized"], False, "PHYSICAL_AUTHORITY")
    for key in (
        "finite_decision_declared",
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        exact(contract[key], False, f"DECLARATION:{key}")
    gate = contract["complete_zero_world_gate"]
    exact(
        {
            key: gate[key]
            for key in (
                "must_pass_before_physics",
                "model_construction_count",
                "world_attempt_count",
                "world_build_count",
                "solver_step_count",
                "physics_state_modified",
            )
        },
        {
            "must_pass_before_physics": True,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
        "ZERO_WORLD_COUNTS",
    )
    inventory = [str(value) for value in contract["source_inventory"]]
    exact(len(inventory), len(set(inventory)), "SOURCE_INVENTORY_UNIQUE")
    require(bool(inventory), "SOURCE_INVENTORY_EMPTY")
    require(all((root / value).is_file() for value in inventory), "SOURCE_INVENTORY")
    for binding in contract["immutable_bindings"]:
        _verify_bound_file(root, binding)

    audit = contract["audit_configuration"]
    _, closure_published = resolve_prospective_source_freeze(
        root=root,
        contract=contract,
        closure_path=root / str(audit["closure_path"]),
        closure_schema=str(audit["closure_schema"]),
        gate_id=gate_id,
    )
    _verify_source_checks(root, contract["source_checks"])
    expected = contract["live_authority"][
        "qualified_expected" if closure_published else "prospective_expected"
    ]
    verify_legacy_live_authority_projection(
        root,
        tuple(str(value) for value in contract["live_authority_paths"]),
        record_key=str(contract["live_authority"]["record_key"]),
        expected=expected,
        prefix=f"{gate_id.replace('-', '_')}_LIVE",
    )
    return contract, closure_published


def run_cli(
    root: Path,
    contract_relative_path: str,
    contract_schema: str,
    gate_id: str,
    pass_marker: str,
    failure_marker: str,
) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    try:
        contract, closure_published = validate_contract(
            root, contract_relative_path, contract_schema, gate_id
        )
        if args.core_library is not None:
            require(args.core_library.is_file(), "CORE_LIBRARY_MISSING")
        receipt = {
            "schema_version": str(contract["audit_configuration"]["preflight_schema"]),
            "gate_id": gate_id,
            "ok": True,
            "runtime_id": str(contract["exact_runtime"]["runtime_profile_id"]),
            "runtime_version": str(contract["exact_runtime"]["runtime_version"]),
            "closure_published": closure_published,
            "source_check_count": len(contract["source_checks"]),
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
        print(pass_marker, json.dumps(receipt, separators=(",", ":"), sort_keys=True))
        print(json.dumps(receipt, separators=(",", ":"), sort_keys=True))
        return 0
    except (ClosureAuditError, KeyError, OSError, UnicodeDecodeError, ValueError) as error:
        print(f"{failure_marker} {error}", file=sys.stderr)
        return 1
