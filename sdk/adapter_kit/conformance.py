"""Compile the public SporeSpore adapter-authoring A0-A6 conformance report."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable

try:
    from sporespore_locomotion import (
        LocomotionCore,
        LocomotionCoreError,
        SELECTED_BALANCED_WAVE_POLICY_ID,
    )
except ImportError:
    from python.sporespore_locomotion import (
        LocomotionCore,
        LocomotionCoreError,
        SELECTED_BALANCED_WAVE_POLICY_ID,
    )

from .reference_adapter import (
    CONTRACT_PATH,
    REFERENCE_MANIFEST_PATH,
    AdapterContractError,
    ReferenceHostAdapter,
    canonical_sha256,
    load_adapter_contract,
    load_reference_manifest,
)


SDK_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = SDK_ROOT.parent
REFERENCE_ADAPTER_PATH = Path(__file__).resolve().with_name(
    "reference_adapter.py"
)
REPORT_SCHEMA = "sporespore_adapter_authoring_conformance_report_v1"


class ConformanceFailure(RuntimeError):
    """A failed adapter-authoring conformance cell."""


def _require(condition: bool, code: str, detail: str = "") -> None:
    if not condition:
        raise ConformanceFailure(f"{code}:{detail}")


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return f"sha256:{digest.hexdigest()}"


def _git(*arguments: str) -> tuple[bool, str]:
    result = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return result.returncode == 0, result.stdout.strip()


def _source_receipt() -> dict[str, Any]:
    head_ok, head = _git("rev-parse", "HEAD")
    origin_ok, origin = _git("rev-parse", "origin/main")
    status_ok, status = _git(
        "status",
        "--porcelain=v1",
        "--untracked-files=all",
    )
    return {
        "commit": head if head_ok else None,
        "origin_main": origin if origin_ok else None,
        "clean": status_ok and status == "",
        "matches_origin_main": head_ok and origin_ok and head == origin,
        "status_entries": status.splitlines() if status else [],
    }


def _expect_core_failure(
    callback: Callable[[], object],
    expected_failure_code: str,
) -> str:
    try:
        callback()
    except LocomotionCoreError as error:
        _require(
            error.failure_code == expected_failure_code,
            "ADAPTER_NEGATIVE_FAILURE_CODE_MISMATCH",
            (
                f"expected={expected_failure_code} "
                f"actual={error.failure_code}"
            ),
        )
        return error.failure_code
    raise ConformanceFailure(
        f"ADAPTER_NEGATIVE_PATH_ACCEPTED:{expected_failure_code}"
    )


def _expect_safe_failure(
    callback: Callable[[], dict[str, Any]],
    expected_failure_code: str,
) -> str:
    output = callback()
    actuation = output.get("actuation", {})
    _require(
        actuation.get("safe_no_actuation") is True,
        "ADAPTER_NEGATIVE_PATH_NOT_SAFE_ZERO",
        expected_failure_code,
    )
    _require(
        actuation.get("failure_codes") == [expected_failure_code],
        "ADAPTER_NEGATIVE_SAFE_FAILURE_CODE_MISMATCH",
        (
            f"expected={expected_failure_code} "
            f"actual={actuation.get('failure_codes')}"
        ),
    )
    _require(
        all(
            entry.get("target_velocity_rad_s") == 0.0
            and entry.get("residual_contribution_rad_s") == 0.0
            and entry.get("safety_contribution_rad_s") == 0.0
            for entry in actuation.get("ordered_commands", [])
        ),
        "ADAPTER_NEGATIVE_SAFE_FRAME_HAS_AUTHORITY",
        expected_failure_code,
    )
    return expected_failure_code


def _cell_a0_contract(core: LocomotionCore) -> dict[str, Any]:
    contract = load_adapter_contract()
    manifest = load_reference_manifest(contract)
    core_contract = core.canonicalize_json(contract)
    core_manifest = core.canonicalize_json(manifest)
    required_fields = contract["capability_manifest"][
        "required_top_level_fields"
    ]
    _require(
        list(sorted(manifest)) == list(sorted(required_fields)),
        "ADAPTER_A0_MANIFEST_FIELD_MISMATCH",
    )
    _require(core.version == "0.1.0", "ADAPTER_A0_CORE_VERSION_MISMATCH")
    _require(
        core_contract["sha256"] == canonical_sha256(contract)
        and core_manifest["sha256"] == canonical_sha256(manifest),
        "ADAPTER_A0_CANONICAL_DIGEST_MISMATCH",
    )
    return {
        "cell_id": "a0_contract",
        "passed": True,
        "contract_schema": contract["schema_version"],
        "manifest_schema": manifest["schema_version"],
        "contract_file_sha256": _file_sha256(CONTRACT_PATH),
        "contract_canonical_sha256": canonical_sha256(contract),
        "manifest_file_sha256": _file_sha256(REFERENCE_MANIFEST_PATH),
        "manifest_canonical_sha256": canonical_sha256(manifest),
        "public_canonical_digest_entrypoint": "ss_canonicalize_json",
        "local_and_core_canonical_digests_match": True,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_a1_named_policy(core: LocomotionCore) -> dict[str, Any]:
    adapter = ReferenceHostAdapter(core)
    first = adapter.advance()
    output = first["controller_output"]
    _require(
        adapter.profile["policy_id"] == SELECTED_BALANCED_WAVE_POLICY_ID,
        "ADAPTER_A1_PROFILE_POLICY_MISMATCH",
    )
    _require(
        output["actuation"]["receipt"]["policy_id"]
        == SELECTED_BALANCED_WAVE_POLICY_ID,
        "ADAPTER_A1_STEP_POLICY_MISMATCH",
    )
    _require(
        output["actuation"]["safe_no_actuation"] is False,
        "ADAPTER_A1_UNEXPECTED_SAFE_ZERO",
    )
    return {
        "cell_id": "a1_named_policy",
        "passed": True,
        "selected_policy_id": SELECTED_BALANCED_WAVE_POLICY_ID,
        "legacy_unnamed_entrypoint_used": False,
        "ordered_actuator_count": len(adapter.ordered_actuator_ids),
        "controller_receipt_sha256": output["actuation"]["receipt_sha256"],
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_a2_order_and_time(core: LocomotionCore) -> dict[str, Any]:
    adapter = ReferenceHostAdapter(core)
    first = adapter.advance()
    second = adapter.advance()
    first_output = first["controller_output"]
    second_output = second["controller_output"]
    _require(
        first_output["actuation"]["semantic_step"] == 0
        and second_output["actuation"]["semantic_step"] == 1,
        "ADAPTER_A2_SEMANTIC_STEP_MISMATCH",
    )
    _require(
        [
            entry["actuator_id"]
            for entry in second_output["actuation"]["ordered_commands"]
        ]
        == adapter.ordered_actuator_ids,
        "ADAPTER_A2_ACTUATOR_ORDER_MISMATCH",
    )
    return {
        "cell_id": "a2_order_and_time",
        "passed": True,
        "semantic_steps": [0, 1],
        "sample_times_s": [0.0, 1.0 / 120.0],
        "ordered_joint_count": len(adapter.ordered_joint_ids),
        "ordered_contact_count": len(adapter.ordered_contact_site_ids),
        "ordered_actuator_count": len(adapter.ordered_actuator_ids),
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_a3_applied_feedback(core: LocomotionCore) -> dict[str, Any]:
    adapter = ReferenceHostAdapter(core)
    first = adapter.advance()
    previous = first["previous_applied_actuation"]
    _require(
        previous["source_semantic_step"] == 0,
        "ADAPTER_A3_PREVIOUS_STEP_MISMATCH",
    )
    _require(
        [entry["actuator_id"] for entry in previous["ordered_commands"]]
        == adapter.ordered_actuator_ids,
        "ADAPTER_A3_APPLIED_ORDER_MISMATCH",
    )
    _require(
        previous["adapter_receipt_sha256"]
        == first["adapter_receipt_sha256"],
        "ADAPTER_A3_RECEIPT_DIGEST_MISMATCH",
    )
    second_request = adapter.build_step_request(
        1,
        previous_applied_actuation=previous,
    )
    second = core.balanced_wave_policy_step(
        SELECTED_BALANCED_WAVE_POLICY_ID,
        second_request,
    )
    _require(
        second["actuation"]["receipt"]["semantic_step"] == 1,
        "ADAPTER_A3_FEEDBACK_NOT_ACCEPTED",
    )
    return {
        "cell_id": "a3_applied_feedback",
        "passed": True,
        "adapter_receipt_schema": first["adapter_receipt"][
            "schema_version"
        ],
        "adapter_receipt_sha256": first["adapter_receipt_sha256"],
        "host_clamped_count": sum(
            1
            for entry in previous["ordered_commands"]
            if entry["host_clamped"]
        ),
        "next_step_consumed_previous_applied_actuation": True,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_a4_safe_zero(core: LocomotionCore) -> dict[str, Any]:
    adapter = ReferenceHostAdapter(core)
    adapter.advance()
    safe = adapter.advance(contacts_available=False)
    actuation = safe["controller_output"]["actuation"]
    _require(
        actuation["safe_no_actuation"] is True,
        "ADAPTER_A4_SAFE_ZERO_NOT_SELECTED",
    )
    _require(
        all(
            entry["target_velocity_rad_s"] == 0.0
            and entry["residual_contribution_rad_s"] == 0.0
            and entry["safety_contribution_rad_s"] == 0.0
            for entry in actuation["ordered_commands"]
        ),
        "ADAPTER_A4_SAFE_ZERO_HAS_AUTHORITY",
    )
    _require(
        safe["adapter_receipt"]["safe_no_actuation_preserved"] is True,
        "ADAPTER_A4_HOST_DID_NOT_PRESERVE_SAFE_ZERO",
    )
    return {
        "cell_id": "a4_safe_zero",
        "passed": True,
        "contact_quality": "unavailable",
        "ordered_safe_zero_count": len(actuation["ordered_commands"]),
        "host_preserved_safe_zero": True,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_a5_negative_paths(core: LocomotionCore) -> dict[str, Any]:
    adapter = ReferenceHostAdapter(core)
    reversed_request = adapter.build_step_request(0)
    reversed_request["state"]["ordered_joint_observations"][0], (
        reversed_request["state"]["ordered_joint_observations"][1]
    ) = (
        reversed_request["state"]["ordered_joint_observations"][1],
        reversed_request["state"]["ordered_joint_observations"][0],
    )
    reversed_code = _expect_safe_failure(
        lambda: core.balanced_wave_policy_step(
            SELECTED_BALANCED_WAVE_POLICY_ID,
            reversed_request,
        ),
        "ORDER_INVALID",
    )

    first = adapter.advance()
    stale = first["previous_applied_actuation"]
    stale["source_semantic_step"] = 1
    stale_request = adapter.build_step_request(
        1,
        previous_applied_actuation=stale,
    )
    stale_code = _expect_safe_failure(
        lambda: core.balanced_wave_policy_step(
            SELECTED_BALANCED_WAVE_POLICY_ID,
            stale_request,
        ),
        "TIME_INVALID",
    )
    unknown_code = _expect_core_failure(
        lambda: core.balanced_wave_policy_profile(
            "sporespore_unknown_policy_v1",
            adapter.descriptor,
        ),
        "IDENTITY_INVALID",
    )
    return {
        "cell_id": "a5_negative_paths",
        "passed": True,
        "reordered_joint_failure_code": reversed_code,
        "stale_applied_feedback_failure_code": stale_code,
        "unknown_policy_failure_code": unknown_code,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_a6_import_boundary() -> dict[str, Any]:
    source = REFERENCE_ADAPTER_PATH.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(REFERENCE_ADAPTER_PATH))
    imported_roots: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported_roots.update(
                alias.name.split(".", maxsplit=1)[0]
                for alias in node.names
            )
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported_roots.add(node.module.split(".", maxsplit=1)[0])
    allowed_roots = {
        "__future__",
        "copy",
        "hashlib",
        "json",
        "pathlib",
        "python",
        "re",
        "sporespore_locomotion",
        "typing",
    }
    forbidden = sorted(imported_roots - allowed_roots)
    _require(
        not forbidden,
        "ADAPTER_A6_FORBIDDEN_IMPORT",
        ",".join(forbidden),
    )
    _require(
        not any(
            token in source
            for token in (
                "scripts.lab",
                "project.godot",
                "res://",
            )
        ),
        "ADAPTER_A6_LAB_REFERENCE",
    )
    return {
        "cell_id": "a6_import_boundary",
        "passed": True,
        "reference_source_path": "adapter_kit/reference_adapter.py",
        "imported_roots": sorted(imported_roots),
        "forbidden_imports": forbidden,
        "lab_import_count": 0,
        "game_tree_import_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def run_adapter_authoring_conformance() -> dict[str, Any]:
    core = LocomotionCore()
    cells = [
        _cell_a0_contract(core),
        _cell_a1_named_policy(core),
        _cell_a2_order_and_time(core),
        _cell_a3_applied_feedback(core),
        _cell_a4_safe_zero(core),
        _cell_a5_negative_paths(core),
        _cell_a6_import_boundary(),
    ]
    source = _source_receipt()
    return {
        "schema_version": REPORT_SCHEMA,
        "ok": True,
        "adapter_id": "sporespore_reference_external_adapter",
        "contract_id": "sporespore_engine_adapter_boundary_v1",
        "selected_policy_id": SELECTED_BALANCED_WAVE_POLICY_ID,
        "source": source,
        "core": {
            "version": core.version,
            "library_path_execution_only": str(core.library_path),
            "library_sha256": _file_sha256(core.library_path),
        },
        "contract_file_sha256": _file_sha256(CONTRACT_PATH),
        "manifest_file_sha256": _file_sha256(REFERENCE_MANIFEST_PATH),
        "manifest_canonical_sha256": canonical_sha256(
            load_reference_manifest()
        ),
        "cells": cells,
        "passed_cells": len(cells),
        "failed_cells": 0,
        "third_party_fixture_uses_public_surfaces_only": True,
        "legacy_unnamed_entrypoint_used": False,
        "world_build_count": 0,
        "controller_policy_authority": False,
        "walking_acceptance": False,
        "physical_acceptance_authority": False,
        "completed_engine_neutral_sdk": False,
    }


def _retain_report(report: dict[str, Any], path: Path) -> None:
    _require(path.name == "report.json", "ADAPTER_REPORT_NAME_INVALID")
    _require(not path.exists(), "ADAPTER_REPORT_ALREADY_EXISTS", str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name("report.json.tmp")
    _require(
        not temporary.exists(),
        "ADAPTER_REPORT_TEMPORARY_EXISTS",
        str(temporary),
    )
    serialized = json.dumps(report, indent=2, allow_nan=False) + "\n"
    temporary.write_text(serialized, encoding="utf-8", newline="\n")
    os.replace(temporary, path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        report = run_adapter_authoring_conformance()
        if args.output is not None:
            output = args.output.resolve()
            _retain_report(report, output)
            print(
                f"retained adapter-authoring report: {output}",
                file=sys.stderr,
            )
        print(json.dumps(report, indent=2, allow_nan=False))
    except (
        AdapterContractError,
        ConformanceFailure,
        LocomotionCoreError,
        OSError,
        ValueError,
    ) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
