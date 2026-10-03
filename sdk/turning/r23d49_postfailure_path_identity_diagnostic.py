"""Diagnose R23D49 after its frozen Windows-path verifier false negative.

This program is deliberately post-failure and non-authoritative.  It does not
change the frozen R23D49 evaluator, report, classification, or claims.  It
re-evaluates the three retained terminal entries after replacing only the
known-bad path-text comparison with an existing-file identity comparison.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence

import r23d49_rapier_retention_repair_replay_evaluator as evaluator


MARKER = "QSDK_R23D49_POSTFAILURE_PATH_IDENTITY_DIAGNOSTIC "
ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
MANIFEST_SCHEMA = "sporespore_content_addressed_artifact_manifest_v1"
OFFICIAL_CLASSIFICATION = (
    "invalid_or_incomplete_outcome_exposed_rapier_retention_repair_replay"
)
OFFICIAL_FAILURE = "R23D48_TRACE_ARTIFACT_CAS_PATH"


class R23D49PostFailureDiagnosticError(RuntimeError):
    """The retained input or diagnostic boundary is invalid."""


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _same_existing_file(left: Path, right: Path) -> bool:
    """Compare file identity rather than Windows namespace spelling."""

    try:
        return os.path.samefile(os.fspath(left), os.fspath(right))
    except OSError:
        return False


def _artifact_paths(
    artifact: Mapping[str, Any], authority_repo_root: Path
) -> tuple[Path, Path, Path, Path]:
    digest = str(artifact.get("sha256", ""))
    digest_hex = digest.removeprefix("sha256:")
    directory = (
        authority_repo_root.parent
        / "SporeSpore_Evidence"
        / "artifacts"
        / "sha256"
        / digest_hex
    )
    return (
        Path(str(artifact.get("payload_path", ""))),
        Path(str(artifact.get("manifest_path", ""))),
        directory / "payload.bin",
        directory / "manifest.json",
    )


def _make_file_identity_verifier(
    authority_repo_root: Path,
) -> tuple[
    Callable[[Mapping[str, Any]], list[str]],
    list[dict[str, Any]],
]:
    observations: list[dict[str, Any]] = []

    def verify(entry: Mapping[str, Any]) -> list[str]:
        artifact = entry.get("trace_artifact")
        if (
            not isinstance(artifact, dict)
            or artifact.get("schema_version") != ARTIFACT_SCHEMA
        ):
            return ["R23D49_DIAGNOSTIC_TRACE_ARTIFACT_RECEIPT"]
        digest = str(artifact.get("sha256", ""))
        digest_hex = digest.removeprefix("sha256:")
        if (
            len(digest_hex) != 64
            or any(character not in "0123456789abcdef" for character in digest_hex)
            or artifact.get("test_only") is True
            or artifact.get("physical_acceptance_authority") is not False
        ):
            return ["R23D49_DIAGNOSTIC_TRACE_ARTIFACT_IDENTITY"]
        recorded_payload, recorded_manifest, payload, manifest_path = _artifact_paths(
            artifact, authority_repo_root
        )
        payload_same_file = _same_existing_file(recorded_payload, payload)
        manifest_same_file = _same_existing_file(recorded_manifest, manifest_path)
        observation = {
            "cell_id": entry.get("cell_id"),
            "trace_sha256": digest,
            "recorded_payload_path": os.fspath(recorded_payload),
            "expected_payload_path": os.fspath(payload),
            "payload_path_text_equal": os.fspath(recorded_payload) == os.fspath(payload),
            "payload_same_existing_file": payload_same_file,
            "recorded_manifest_path": os.fspath(recorded_manifest),
            "expected_manifest_path": os.fspath(manifest_path),
            "manifest_path_text_equal": (
                os.fspath(recorded_manifest) == os.fspath(manifest_path)
            ),
            "manifest_same_existing_file": manifest_same_file,
        }
        observations.append(observation)
        if not payload_same_file or not manifest_same_file:
            return ["R23D49_DIAGNOSTIC_TRACE_ARTIFACT_CAS_FILE_IDENTITY"]
        try:
            raw = payload.read_bytes()
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            return [
                "R23D49_DIAGNOSTIC_TRACE_ARTIFACT_UNREADABLE:"
                + type(error).__name__
            ]
        observed = "sha256:" + hashlib.sha256(raw).hexdigest()
        if (
            observed != digest
            or len(raw) != artifact.get("byte_length")
            or manifest.get("schema_version") != MANIFEST_SCHEMA
            or manifest.get("algorithm") != "sha256"
            or manifest.get("sha256") != digest
            or manifest.get("byte_length") != len(raw)
            or manifest.get("payload_name") != "payload.bin"
            or manifest.get("media_type") != "application/x-ndjson"
        ):
            return ["R23D49_DIAGNOSTIC_TRACE_ARTIFACT_BYTES"]
        return []

    return verify, observations


def _load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D49PostFailureDiagnosticError(
            f"R23D49_DIAGNOSTIC_JSON_UNREADABLE:{path}:{type(error).__name__}"
        ) from error


def diagnose(
    *,
    terminal_paths_path: Path,
    official_report_path: Path,
    expected_source_commit: str,
    authority_repo_root: Path,
) -> dict[str, Any]:
    authority_repo_root = authority_repo_root.resolve()
    if not (authority_repo_root / ".git").exists():
        raise R23D49PostFailureDiagnosticError(
            "R23D49_DIAGNOSTIC_AUTHORITY_REPO_ROOT_INVALID"
        )
    official = _load_json(official_report_path)
    complete = official.get("complete_evaluation", {})
    cell_evaluations = complete.get("cell_evaluations", [])
    if (
        official.get("source_commit") != expected_source_commit
        or official.get("result_classification") != OFFICIAL_CLASSIFICATION
        or complete.get("classification") != OFFICIAL_CLASSIFICATION
        or len(cell_evaluations) != 3
        or any(
            item.get("failed_gate_ids") != [OFFICIAL_FAILURE]
            for item in cell_evaluations
        )
    ):
        raise R23D49PostFailureDiagnosticError(
            "R23D49_DIAGNOSTIC_OFFICIAL_FAILURE_BOUNDARY_INVALID"
        )
    terminal_paths = _load_json(terminal_paths_path)
    if not isinstance(terminal_paths, list) or len(terminal_paths) != 3:
        raise R23D49PostFailureDiagnosticError(
            "R23D49_DIAGNOSTIC_TERMINAL_PATHS_INVALID"
        )
    entries: list[dict[str, Any]] = []
    terminal_receipts = official.get("ordered_matrix_cells", [])
    if len(terminal_receipts) != 3:
        raise R23D49PostFailureDiagnosticError(
            "R23D49_DIAGNOSTIC_TERMINAL_RECEIPTS_INVALID"
        )
    for path_text, receipt_entry in zip(
        terminal_paths, terminal_receipts, strict=True
    ):
        path = Path(str(path_text))
        receipt = receipt_entry.get("terminal_entry_cas", {})
        receipt_path = Path(str(receipt.get("payload_path", "")))
        if (
            not _same_existing_file(path, receipt_path)
            or raw_sha256(path) != receipt.get("sha256")
            or path.stat().st_size != receipt.get("byte_length")
        ):
            raise R23D49PostFailureDiagnosticError(
                "R23D49_DIAGNOSTIC_TERMINAL_CAS_BINDING_INVALID"
            )
        entry = _load_json(path)
        if not isinstance(entry, dict):
            raise R23D49PostFailureDiagnosticError(
                "R23D49_DIAGNOSTIC_TERMINAL_ENTRY_INVALID"
            )
        entries.append(entry)

    verifier, observations = _make_file_identity_verifier(authority_repo_root)
    frozen_verifier = evaluator.parent._cas_binding_failures
    try:
        evaluator.parent._cas_binding_failures = verifier
        recomputed = evaluator.evaluate_complete_entries(
            entries,
            expected_source_commit=expected_source_commit,
            authority_repo_root=authority_repo_root,
        )
    finally:
        evaluator.parent._cas_binding_failures = frozen_verifier

    if len(observations) != 3:
        raise R23D49PostFailureDiagnosticError(
            "R23D49_DIAGNOSTIC_FILE_IDENTITY_OBSERVATION_COUNT_INVALID"
        )
    return {
        "schema_version": (
            "sporespore_qsdk_r23d49_postfailure_path_identity_diagnostic_v1"
        ),
        "campaign_id": evaluator.design.CAMPAIGN_ID,
        "source_commit": expected_source_commit,
        "authority": "post_failure_diagnostic_only",
        "diagnostic_question": (
            "What would the frozen complete evaluator report if its sole "
            "Windows namespace path-text comparison used existing-file identity?"
        ),
        "single_diagnostic_substitution": (
            "R23D48 path-text equality replaced by os.path.samefile for the "
            "recorded and expected CAS payload and manifest paths"
        ),
        "official_report_path": os.fspath(official_report_path.resolve()),
        "official_report_raw_sha256": raw_sha256(official_report_path),
        "official_classification": OFFICIAL_CLASSIFICATION,
        "official_failed_gate_id": OFFICIAL_FAILURE,
        "official_result_reclassified": False,
        "official_r23d49_classification_unchanged": True,
        "may_be_promoted_to_official_result": False,
        "creates_turning_claim": False,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "retained_terminal_entry_count": len(entries),
        "file_identity_observations": observations,
        "all_recorded_paths_textually_equal_to_expected": all(
            item["payload_path_text_equal"]
            and item["manifest_path_text_equal"]
            for item in observations
        ),
        "all_recorded_paths_identify_expected_files": all(
            item["payload_same_existing_file"]
            and item["manifest_same_existing_file"]
            for item in observations
        ),
        "diagnostic_recomputed_evaluation": recomputed,
    }


def _parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--terminal-paths", type=Path, required=True)
    parser.add_argument("--official-report", type=Path, required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _parse_args(argv)
    result = diagnose(
        terminal_paths_path=args.terminal_paths,
        official_report_path=args.official_report,
        expected_source_commit=args.source_commit,
        authority_repo_root=args.repo_root,
    )
    encoded = (json.dumps(result, sort_keys=True, separators=(",", ":")) + "\n").encode(
        "utf-8"
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    try:
        with args.output.open("xb") as stream:
            stream.write(encoded)
    except FileExistsError as error:
        raise R23D49PostFailureDiagnosticError(
            "R23D49_DIAGNOSTIC_OUTPUT_ALREADY_EXISTS"
        ) from error
    print(MARKER + encoded.decode("utf-8").rstrip("\n"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
