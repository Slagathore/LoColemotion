"""Compile AEC0-AEC7 zero-world experience-encyclopedia conformance."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable

try:
    from sporespore_locomotion import LocomotionCore
except ImportError:
    from python.sporespore_locomotion import LocomotionCore

from .experience_encyclopedia import (
    CONTRACT_PATH,
    AppendOnlyExperienceEncyclopedia,
    ExperienceEncyclopediaError,
    build_experience_entry,
    canonical_sha256,
    characterize_online_window,
    load_experience_encyclopedia_contract,
    validate_experience_entry,
)


SDK_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = SDK_ROOT.parent
REPORT_SCHEMA = (
    "sporespore_adaptation_experience_encyclopedia_conformance_report_v1"
)


class ExperienceConformanceFailure(RuntimeError):
    """An AEC0-AEC7 conformance invariant failed."""


def _require(condition: bool, code: str, detail: object = "") -> None:
    if not condition:
        raise ExperienceConformanceFailure(f"{code}:{detail}")


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
        "status", "--porcelain=v1", "--untracked-files=all"
    )
    return {
        "commit": head if head_ok else None,
        "origin_main": origin if origin_ok else None,
        "clean": status_ok and status == "",
        "matches_origin_main": head_ok and origin_ok and head == origin,
        "status_entries": status.splitlines() if status else [],
    }


def _request() -> dict[str, Any]:
    samples = []
    for index, values in enumerate(
        (
            (0.20, 0.18, 0.42, 0.03, 4, False, True),
            (0.20, 0.16, 0.41, -0.05, 3, False, True),
            (0.20, 0.19, 0.40, 0.04, 4, True, False),
        )
    ):
        requested, observed, height, tilt, contacts, fallback, influence = values
        samples.append(
            {
                "schema_version": (
                    "sporespore_online_characterization_sample_v1"
                ),
                "step_index": 120 + index,
                "time_seconds": 1.0 + index / 120.0,
                "requested_forward_velocity_m_s": requested,
                "observed_forward_velocity_m_s": observed,
                "torso_height_m": height,
                "torso_tilt_rad": tilt,
                "qualified_contact_count": contacts,
                "fallback_active": fallback,
                "provider_influence_applied": influence,
            }
        )
    return {
        "schema_version": "sporespore_online_characterization_request_v1",
        "session_id": "aec_fixture_session",
        "morphology_descriptor_sha256": "sha256:" + "1" * 64,
        "provider_id": "aec_fixture_provider",
        "model_id": "aec_fixture_model",
        "corpus_sha256": "sha256:" + "2" * 64,
        "task_id": "bounded_forward_walk",
        "environment_id": "canonical_observation_fixture",
        "support_status": "supported",
        "seed": 9301,
        "support_contact_capacity": 4,
        "ordered_samples": samples,
        "candidate_only": True,
        "physical_acceptance_authority": False,
    }


def _candidate(index: int) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_adaptation_candidate_experience_v1",
        "candidate_event_id": f"aec_candidate_{index}",
        "lesson_family_id": "bounded_forward_tracking",
        "candidate_only": True,
        "encyclopedia_promotion_authority": False,
        "physical_acceptance_authority": False,
    }


def _entry(
    core: LocomotionCore,
    characterization: dict[str, Any],
    index: int,
    result_class: str,
) -> dict[str, Any]:
    markers = "34567"
    return build_experience_entry(
        core,
        candidate_experience=_candidate(index),
        characterization=characterization,
        provider_request_sha256="sha256:" + markers[index] * 64,
        provider_response_sha256="sha256:" + "8" * 64,
        resolution_receipt_sha256="sha256:" + "9" * 64,
        result_class=result_class,
        reason_code=(
            None if result_class == "positive" else f"retained_{result_class}"
        ),
    )


def _expect_error(
    callback: Callable[[], object], expected_prefix: str
) -> bool:
    try:
        callback()
    except ExperienceEncyclopediaError as error:
        return str(error).startswith(expected_prefix)
    return False


def run_experience_encyclopedia_conformance() -> dict[str, Any]:
    core = LocomotionCore()
    contract = load_experience_encyclopedia_contract()
    cells: list[dict[str, Any]] = []
    cells.append(
        {
            "cell_id": "aec0_contract",
            "passed": True,
            "contract_id": contract["contract_id"],
            "contract_file_sha256": _file_sha256(CONTRACT_PATH),
            "contract_canonical_sha256": canonical_sha256(core, contract),
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    request = _request()
    first = characterize_online_window(core, request)
    second = characterize_online_window(core, copy.deepcopy(request))
    _require(first == second, "AEC1_NONDETERMINISTIC")
    _require(
        canonical_sha256(core, first) == canonical_sha256(core, second),
        "AEC1_DIGEST_NONDETERMINISTIC",
    )
    cells.append(
        {
            "cell_id": "aec1_deterministic_characterization",
            "passed": True,
            "characterization_sha256": canonical_sha256(core, first),
            "sample_count": first["sample_count"],
            "thresholds_applied": first["thresholds_applied"],
            "outcome_classified": first["outcome_classified"],
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    unknown = copy.deepcopy(request)
    unknown["unknown"] = True
    nonfinite = copy.deepcopy(request)
    nonfinite["ordered_samples"][1]["torso_tilt_rad"] = float("nan")
    reordered = copy.deepcopy(request)
    reordered["ordered_samples"][1]["step_index"] = 120
    mutation_results = {
        "unknown_field": _expect_error(
            lambda: characterize_online_window(core, unknown),
            "CHARACTERIZATION_REQUEST_FIELDS:",
        ),
        "nonfinite": _expect_error(
            lambda: characterize_online_window(core, nonfinite),
            "CHARACTERIZATION_NUMERIC:",
        ),
        "reordered": _expect_error(
            lambda: characterize_online_window(core, reordered),
            "CHARACTERIZATION_STEP_ORDER:",
        ),
    }
    _require(all(mutation_results.values()), "AEC2_MUTATION_ACCEPTED")
    cells.append(
        {
            "cell_id": "aec2_characterization_negative_controls",
            "passed": True,
            "rejected_mutations": mutation_results,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    result_classes = [
        "positive",
        "negative",
        "rejected",
        "invalid",
        "incomplete",
    ]
    entries = [
        _entry(core, first, index, result_class)
        for index, result_class in enumerate(result_classes)
    ]
    with tempfile.TemporaryDirectory(prefix="sporespore_aec_") as directory:
        store = AppendOnlyExperienceEncyclopedia(core, directory)
        tail = None
        receipt: dict[str, Any] | None = None
        for entry in entries:
            receipt = store.append(entry, expected_tail_sha256=tail)
            tail = receipt["tail_event_sha256"]
        _require(receipt is not None, "AEC3_NO_RECEIPT")
        _require(receipt["event_count"] == 5, "AEC3_EVENT_COUNT")
        _require(
            all(receipt["result_counts"][value] == 1 for value in result_classes),
            "AEC3_RESULT_RETENTION",
        )
        cells.append(
            {
                "cell_id": "aec3_append_all_result_classes",
                "passed": True,
                "event_count": receipt["event_count"],
                "object_count": receipt["object_count"],
                "result_counts": receipt["result_counts"],
                "tail_event_sha256": receipt["tail_event_sha256"],
                "world_build_count": 0,
                "physical_acceptance_authority": False,
            }
        )

        duplicate_rejected = _expect_error(
            lambda: store.append(entries[0], expected_tail_sha256=tail),
            "EXPERIENCE_DUPLICATE_APPEND:",
        )
        stale_rejected = _expect_error(
            lambda: store.append(
                _entry(core, first, 0, "negative"),
                expected_tail_sha256="sha256:" + "a" * 64,
            ),
            "EXPERIENCE_STALE_PARENT:",
        )
        _require(duplicate_rejected and stale_rejected, "AEC4_APPEND_CONTROL")
        _require(store.validate() == receipt, "AEC4_STORE_CHANGED")
        cells.append(
            {
                "cell_id": "aec4_duplicate_and_stale_parent_refusal",
                "passed": True,
                "duplicate_rejected": duplicate_rejected,
                "stale_parent_rejected": stale_rejected,
                "store_unchanged": True,
                "world_build_count": 0,
                "physical_acceptance_authority": False,
            }
        )

        corrupt_root = Path(directory).with_name(Path(directory).name + "_corrupt")
        shutil.copytree(directory, corrupt_root)
        try:
            corrupt_store = AppendOnlyExperienceEncyclopedia(core, corrupt_root)
            first_event = sorted((corrupt_root / "events").iterdir())[0]
            event = json.loads(first_event.read_text(encoding="utf-8"))
            event["result_class"] = "invalid"
            first_event.write_text(
                json.dumps(event, sort_keys=True, separators=(",", ":")) + "\n",
                encoding="utf-8",
                newline="\n",
            )
            event_mutation_rejected = _expect_error(
                corrupt_store.validate, "EXPERIENCE_EVENT_DIGEST:"
            )
        finally:
            shutil.rmtree(corrupt_root)
        object_corrupt_root = Path(directory).with_name(
            Path(directory).name + "_object_corrupt"
        )
        shutil.copytree(directory, object_corrupt_root)
        try:
            object_corrupt_store = AppendOnlyExperienceEncyclopedia(
                core, object_corrupt_root
            )
            first_experience = receipt["ordered_experience_sha256"][0]
            object_path = (
                object_corrupt_root
                / "objects"
                / "sha256"
                / first_experience.removeprefix("sha256:")
                / "payload.json"
            )
            payload = json.loads(object_path.read_text(encoding="utf-8"))
            payload["experience_id"] += "_mutated"
            object_path.write_text(
                json.dumps(payload, sort_keys=True, separators=(",", ":"))
                + "\n",
                encoding="utf-8",
                newline="\n",
            )
            object_mutation_rejected = _expect_error(
                object_corrupt_store.validate, "EXPERIENCE_OBJECT_DIGEST:"
            )
        finally:
            shutil.rmtree(object_corrupt_root)
        embedded_mutation = copy.deepcopy(entries[0])
        embedded_mutation["candidate_experience"][
            "candidate_event_id"
        ] = "aec_candidate_mutated"
        embedded_binding_rejected = _expect_error(
            lambda: validate_experience_entry(core, embedded_mutation),
            "EXPERIENCE_ENTRY_CANDIDATE_DIGEST:",
        )
        _require(
            event_mutation_rejected
            and object_mutation_rejected
            and embedded_binding_rejected,
            "AEC5_MUTATION_ACCEPTED",
        )
        cells.append(
            {
                "cell_id": "aec5_event_and_object_mutation_controls",
                "passed": True,
                "event_mutation_rejected": True,
                "object_mutation_rejected": True,
                "embedded_binding_mutation_rejected": True,
                "world_build_count": 0,
                "physical_acceptance_authority": False,
            }
        )

        incomplete_root = Path(directory).with_name(
            Path(directory).name + "_incomplete"
        )
        shutil.copytree(directory, incomplete_root)
        try:
            orphan = incomplete_root / "objects" / "sha256" / ("b" * 64)
            orphan.mkdir()
            (orphan / "payload.json").write_text("{}\n", encoding="utf-8")
            incomplete_store = AppendOnlyExperienceEncyclopedia(core, incomplete_root)
            incomplete = incomplete_store.validate()
            _require(
                incomplete["complete"] is False
                and incomplete["orphan_object_count"] == 1,
                "AEC6_ORPHAN_NOT_RETAINED",
            )
            incomplete_append_rejected = _expect_error(
                lambda: incomplete_store.append(
                    _entry(core, first, 0, "rejected"),
                    expected_tail_sha256=incomplete["tail_event_sha256"],
                ),
                "EXPERIENCE_STORE_INCOMPLETE:",
            )
        finally:
            shutil.rmtree(incomplete_root)
        _require(incomplete_append_rejected, "AEC6_INCOMPLETE_APPEND_ACCEPTED")
        cells.append(
            {
                "cell_id": "aec6_incomplete_store_retention",
                "passed": True,
                "orphan_object_count": 1,
                "incomplete_append_rejected": True,
                "world_build_count": 0,
                "physical_acceptance_authority": False,
            }
        )

        _require(
            receipt["candidate_only"] is True
            and receipt["training_data_authority"] is False
            and receipt["encyclopedia_promotion_authority"] is False
            and receipt["physical_acceptance_authority"] is False,
            "AEC7_AUTHORITY",
        )
        cells.append(
            {
                "cell_id": "aec7_authority_boundary",
                "passed": True,
                "candidate_only": True,
                "training_data_authority": False,
                "encyclopedia_promotion_authority": False,
                "scientific_result": False,
                "release_authority": False,
                "world_build_count": 0,
                "physical_acceptance_authority": False,
            }
        )

    return {
        "schema_version": REPORT_SCHEMA,
        "ok": True,
        "contract_id": contract["contract_id"],
        "source": _source_receipt(),
        "core": {
            "version": core.version,
            "library_path_execution_only": str(core.library_path),
            "library_sha256": _file_sha256(core.library_path),
        },
        "cells": cells,
        "passed_cells": len(cells),
        "failed_cells": 0,
        "deterministic_online_characterization_implemented": True,
        "append_only_experience_store_implemented": True,
        "positive_negative_rejected_invalid_incomplete_retained": True,
        "self_contained_experience_objects": True,
        "mutation_control_count": 9,
        "training_data_authority": False,
        "encyclopedia_promotion_authority": False,
        "scientific_result": False,
        "world_build_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _retain_report(report: dict[str, Any], path: Path) -> None:
    _require(path.name == "report.json", "AEC_REPORT_NAME")
    _require(not path.exists(), "AEC_REPORT_EXISTS", path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name("report.json.tmp")
    _require(not temporary.exists(), "AEC_REPORT_TEMP_EXISTS")
    temporary.write_text(
        json.dumps(report, indent=2, allow_nan=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    os.replace(temporary, path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        report = run_experience_encyclopedia_conformance()
        if args.output is not None:
            _retain_report(report, args.output.resolve())
        print(json.dumps(report, sort_keys=True, allow_nan=False))
    except Exception as error:  # pragma: no cover - CLI terminal boundary
        print(f"ADAPTATION_EXPERIENCE_ENCYCLOPEDIA_FAILURE {error}", file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
