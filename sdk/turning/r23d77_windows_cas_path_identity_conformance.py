"""Zero-world and retained-receipt conformance for R23D77."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any, Mapping, Sequence

import r23d76_production_route_three_engine_turning_evaluator as r23d76
from r23d77_windows_cas_file_identity import (
    R23D65_PATH_SPELLING_FAILURE,
    R23D77_FILE_IDENTITY_FAILURE,
    alternate_windows_spelling,
    expected_cas_paths,
    same_existing_file,
    verify_with_existing_file_identity,
)


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parent.parent
CONTRACT_PATH = ROOT / "r23d77_windows_cas_path_identity_conformance_v1.json"
R23D76_CLOSURE_PATH = (
    ROOT / "r23d76_production_route_three_engine_turning_validation_closure_v1.json"
)
MARKER = "QSDK_R23D77_WINDOWS_CAS_PATH_IDENTITY "
RESULT_SCHEMA = "sporespore_qsdk_r23d77_windows_cas_path_identity_result_v1"
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
RAPIER_ARMS = ("reference_zero", "positive_heading", "negative_heading")


class R23D77ConformanceError(RuntimeError):
    """The R23D77 contract, source, or retained receipt is invalid."""


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R23D77ConformanceError(code)


def _load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D77ConformanceError(
            f"JSON_UNREADABLE:{path.name}:{type(error).__name__}"
        ) from error
    _require(isinstance(value, dict), f"JSON_ROOT_INVALID:{path.name}")
    return value


def _verify_binding(binding: Mapping[str, Any]) -> None:
    path = REPO_ROOT / str(binding.get("path", ""))
    _require(path.is_file(), f"LINEAGE_PATH_MISSING:{path}")
    _require(path.stat().st_size == binding.get("byte_length"), f"LINEAGE_BYTES:{path}")
    _require(raw_sha256(path) == binding.get("raw_sha256"), f"LINEAGE_SHA256:{path}")


def load_contract() -> dict[str, Any]:
    contract = _load_json(CONTRACT_PATH)
    _require(
        contract.get("schema_version")
        == "sporespore_qsdk_r23d77_windows_cas_path_identity_conformance_v1",
        "CONTRACT_SCHEMA",
    )
    _require(contract.get("question_class") == "development", "QUESTION_CLASS")
    lineage = contract.get("immutable_lineage")
    _require(isinstance(lineage, dict), "LINEAGE_TYPE")
    for name in (
        "accepted_semantic_source",
        "accepted_positive_closure",
        "consumed_r23d76_closure",
        "frozen_verifier",
    ):
        binding = lineage.get(name)
        _require(isinstance(binding, dict), f"LINEAGE_BINDING:{name}")
        _verify_binding(binding)
    _require(lineage.get("r23d76_campaign_and_seed_consumed") is True, "CONSUMED")
    _require(lineage.get("r23d76_reclassification_forbidden") is True, "IMMUTABLE")
    _require(
        lineage.get("same_identity_or_selective_rerun_forbidden") is True,
        "RERUN_BOUNDARY",
    )
    repair = contract.get("single_permitted_repair")
    _require(isinstance(repair, dict), "REPAIR_TYPE")
    _require(repair.get("modify_r23d65_evaluator") is False, "FROZEN_R23D65")
    _require(repair.get("modify_r23d76_evaluator") is False, "FROZEN_R23D76")
    _require(repair.get("modify_r23d76_result") is False, "FROZEN_RESULT")
    _require(
        repair.get("threshold_selector_controller_schedule_or_physics_change") is False,
        "SCIENTIFIC_SEMANTICS_CHANGED",
    )
    return contract


def _git(*arguments: str) -> str:
    process = subprocess.run(
        ["git", "-C", os.fspath(REPO_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if process.returncode != 0:
        raise R23D77ConformanceError(
            "GIT_FAILED:" + " ".join(arguments) + ":" + process.stderr.strip()
        )
    return process.stdout.strip()


def run_zero_world_preflight() -> dict[str, Any]:
    contract = load_contract()
    alternate = alternate_windows_spelling(CONTRACT_PATH)
    _require(CONTRACT_PATH.is_file(), "POSITIVE_CONTROL_SOURCE_MISSING")
    _require(same_existing_file(CONTRACT_PATH, alternate), "ALIAS_POSITIVE_REJECTED")
    _require(
        not same_existing_file(CONTRACT_PATH, R23D76_CLOSURE_PATH),
        "WRONG_EXISTING_FILE_ACCEPTED",
    )

    sentinel_entry = {
        "trace_artifact": {
            "schema_version": "sporespore_content_addressed_artifact_receipt_v1",
            "sha256": "sha256:" + ("0" * 64),
            "payload_path": os.fspath(alternate),
            "manifest_path": os.fspath(alternate),
        }
    }

    def non_path_failure(
        _entry: Mapping[str, Any], *, authority_repo_root: Path
    ) -> list[str]:
        _require(authority_repo_root == REPO_ROOT, "FAKE_AUTHORITY_ROOT")
        return ["FROZEN_NON_PATH_FAILURE"]

    _require(
        verify_with_existing_file_identity(
            sentinel_entry,
            authority_repo_root=REPO_ROOT,
            frozen_verifier=non_path_failure,
        )
        == ["FROZEN_NON_PATH_FAILURE"],
        "NON_PATH_FAILURE_NOT_PRESERVED",
    )
    controls = contract["required_zero_world_controls"]
    _require(controls.get("model_construction_count") == 0, "MODEL_COUNT")
    _require(controls.get("world_attempt_count") == 0, "WORLD_ATTEMPT_COUNT")
    _require(controls.get("world_build_count") == 0, "WORLD_BUILD_COUNT")
    _require(controls.get("solver_step_count") == 0, "SOLVER_STEP_COUNT")
    return {
        "schema_version": "sporespore_qsdk_r23d77_zero_world_preflight_v1",
        "conformance_id": contract["conformance_id"],
        "question_class": "development",
        "lineage_binding_count": 4,
        "ordinary_and_extended_same_file_positive_count": 1,
        "wrong_existing_file_negative_count": 1,
        "non_path_frozen_failure_passthrough_count": 1,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
    }


def _source_identity() -> dict[str, Any]:
    root = Path(_git("rev-parse", "--show-toplevel")).resolve()
    remote = _git("remote", "get-url", "origin")
    branch = _git("branch", "--show-current")
    head = _git("rev-parse", "HEAD")
    origin_main = _git("rev-parse", "origin/main")
    status = _git("status", "--short")
    _require(same_existing_file(root, REPO_ROOT), "SOURCE_ROOT")
    _require(remote == EXPECTED_REMOTE, "SOURCE_REMOTE")
    _require(branch == "main", "SOURCE_BRANCH")
    _require(not status, "SOURCE_DIRTY")
    _require(head == origin_main, "SOURCE_REMOTE_DRIFT")
    return {
        "root": root.as_posix(),
        "remote": remote,
        "branch": branch,
        "source_commit": head,
        "origin_main": origin_main,
        "clean": True,
        "live_remote_equal": True,
    }


def _rapier_cells(closure: Mapping[str, Any]) -> list[dict[str, Any]]:
    attempt = closure.get("retained_physical_attempt")
    _require(isinstance(attempt, Mapping), "R23D76_ATTEMPT")
    cells = attempt.get("retained_cells")
    _require(isinstance(cells, list), "R23D76_CELLS")
    selected = [
        dict(cell)
        for cell in cells
        if isinstance(cell, Mapping) and cell.get("engine_id") == "rapier_parry"
    ]
    _require(len(selected) == 3, "RAPIER_CELL_COUNT")
    _require(
        tuple(cell.get("arm_id") for cell in selected) == RAPIER_ARMS,
        "RAPIER_ARM_ORDER",
    )
    return selected


def _load_exact_terminal(cell: Mapping[str, Any]) -> dict[str, Any]:
    terminal_binding = cell.get("terminal")
    _require(isinstance(terminal_binding, Mapping), "TERMINAL_BINDING")
    path = Path(str(terminal_binding.get("path", "")))
    _require(path.is_file(), f"TERMINAL_MISSING:{cell.get('cell_id')}")
    _require(path.stat().st_size == terminal_binding.get("byte_length"), "TERMINAL_BYTES")
    _require(raw_sha256(path) == terminal_binding.get("raw_sha256"), "TERMINAL_SHA256")
    return _load_json(path)


def _focused_cell_check(cell: Mapping[str, Any]) -> dict[str, Any]:
    entry = _load_exact_terminal(cell)
    r23d76._configure_inherited_evaluator()
    frozen = r23d76.inherited._cas_binding_failures
    original = frozen(entry, authority_repo_root=REPO_ROOT)
    _require(original == [R23D65_PATH_SPELLING_FAILURE], "ORIGINAL_FAILURE_NOT_REPRODUCED")

    expected = expected_cas_paths(entry, authority_repo_root=REPO_ROOT)
    _require(expected is not None, "EXPECTED_CAS_PATHS")
    expected_payload, expected_manifest = expected
    artifact = entry.get("trace_artifact")
    _require(isinstance(artifact, dict), "TRACE_ARTIFACT")
    recorded_payload = Path(str(artifact.get("payload_path", "")))
    recorded_manifest = Path(str(artifact.get("manifest_path", "")))
    _require(str(recorded_payload).startswith("\\\\?\\"), "PAYLOAD_NOT_EXTENDED")
    _require(str(recorded_manifest).startswith("\\\\?\\"), "MANIFEST_NOT_EXTENDED")
    _require(same_existing_file(recorded_payload, expected_payload), "PAYLOAD_ALIAS")
    _require(same_existing_file(recorded_manifest, expected_manifest), "MANIFEST_ALIAS")

    repaired = verify_with_existing_file_identity(
        entry,
        authority_repo_root=REPO_ROOT,
        frozen_verifier=frozen,
    )
    _require(repaired == [], "EXTENDED_RECEIPT_REJECTED")

    ordinary = copy.deepcopy(entry)
    ordinary["trace_artifact"]["payload_path"] = os.fspath(expected_payload)
    ordinary["trace_artifact"]["manifest_path"] = os.fspath(expected_manifest)
    _require(
        verify_with_existing_file_identity(
            ordinary,
            authority_repo_root=REPO_ROOT,
            frozen_verifier=frozen,
        )
        == [],
        "ORDINARY_RECEIPT_REJECTED",
    )

    controls: dict[str, list[str]] = {}
    for control_id, field, value in (
        ("wrong_payload", "payload_path", expected_manifest),
        ("wrong_manifest", "manifest_path", expected_payload),
        ("missing_payload", "payload_path", expected_payload.with_suffix(".missing")),
        ("missing_manifest", "manifest_path", expected_manifest.with_suffix(".missing")),
    ):
        mutation = copy.deepcopy(entry)
        mutation["trace_artifact"][field] = os.fspath(value)
        failures = verify_with_existing_file_identity(
            mutation,
            authority_repo_root=REPO_ROOT,
            frozen_verifier=frozen,
        )
        _require(failures == [R23D77_FILE_IDENTITY_FAILURE], control_id.upper())
        controls[control_id] = failures

    return {
        "cell_id": cell["cell_id"],
        "arm_id": cell["arm_id"],
        "terminal_raw_sha256": cell["terminal"]["raw_sha256"],
        "trace_sha256": artifact["sha256"],
        "trace_byte_length": artifact["byte_length"],
        "recorded_payload_path": os.fspath(recorded_payload),
        "expected_payload_path": os.fspath(expected_payload),
        "recorded_manifest_path": os.fspath(recorded_manifest),
        "expected_manifest_path": os.fspath(expected_manifest),
        "payload_same_existing_file": True,
        "manifest_same_existing_file": True,
        "frozen_failure_codes": original,
        "successor_failure_codes": repaired,
        "ordinary_spelling_failure_codes": [],
        "negative_controls": controls,
        "complete_frozen_byte_verifier_replayed": True,
        "behavior_measurement_invoked": False,
    }


def run_focused_check() -> dict[str, Any]:
    preflight = run_zero_world_preflight()
    source = _source_identity()
    closure = _load_json(R23D76_CLOSURE_PATH)
    _require(
        closure.get("status")
        == "closed_consumed_invalid_complete_rapier_windows_extended_cas_path_identity_failure",
        "R23D76_STATUS",
    )
    official = closure.get("official_result")
    _require(isinstance(official, Mapping), "R23D76_OFFICIAL_RESULT")
    _require(official.get("campaign_identity_consumed") is True, "R23D76_CONSUMED")
    _require(official.get("historical_result_reinterpreted") is False, "REINTERPRETATION")
    results = [_focused_cell_check(cell) for cell in _rapier_cells(closure)]
    return {
        "schema_version": RESULT_SCHEMA,
        "conformance_id": "QSDK-R23D77-WINDOWS-CAS-PATH-IDENTITY",
        "status": "passed_complete_zero_world_retained_receipt_conformance",
        "question_class": "development",
        "source_authority": source,
        "contract": {
            "path": CONTRACT_PATH.relative_to(REPO_ROOT).as_posix(),
            "byte_length": CONTRACT_PATH.stat().st_size,
            "raw_sha256": raw_sha256(CONTRACT_PATH),
        },
        "preflight": preflight,
        "retained_r23d76": {
            "closure_path": R23D76_CLOSURE_PATH.relative_to(REPO_ROOT).as_posix(),
            "closure_raw_sha256": raw_sha256(R23D76_CLOSURE_PATH),
            "official_classification_preserved": official["classification"],
            "historical_result_reinterpreted": False,
            "campaign_identity_consumed": True,
        },
        "complete_rapier_receipt_population_count": len(results),
        "extended_receipt_acceptance_count": len(results),
        "ordinary_receipt_acceptance_count": len(results),
        "negative_control_count": len(results) * 4,
        "negative_control_rejection_count": len(results) * 4,
        "complete_frozen_byte_verifier_replay_count": len(results) * 2,
        "cell_results": results,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "behavior_measurement_invocation_count": 0,
        "r23d76_reclassified": False,
        "finite_turning_evidence_created": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _write_new(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=False)
    payload = json.dumps(value, allow_nan=False, indent=2, sort_keys=True) + "\n"
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(payload)


def _arguments(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("preflight")
    focused = commands.add_parser("focused-check")
    focused.add_argument("--output", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(argv)
    try:
        if arguments.command == "preflight":
            value = run_zero_world_preflight()
        else:
            value = run_focused_check()
            _write_new(arguments.output, value)
            value = {
                "status": value["status"],
                "output": arguments.output.resolve().as_posix(),
                "output_raw_sha256": raw_sha256(arguments.output),
                "rapier_receipts": value["complete_rapier_receipt_population_count"],
                "negative_controls": value["negative_control_rejection_count"],
                "worlds": value["world_build_count"],
            }
        print(MARKER + json.dumps(value, allow_nan=False, sort_keys=True))
        return 0
    except R23D77ConformanceError as error:
        print(MARKER + json.dumps({"status": "failed", "failure": str(error)}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
