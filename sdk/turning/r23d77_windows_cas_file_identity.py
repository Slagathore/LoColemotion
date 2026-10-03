"""R23D77 successor semantics for content-addressed path identity.

The consumed R23D76 evaluator compared two existing Windows paths by their
``pathlib.Path`` spelling.  Rapier records the extended-length spelling
(``\\\\?\\C:\\...``), while Python constructs the ordinary spelling
(``C:\\...``).  R23D50 had already established that an existing CAS object is
identified with ``os.path.samefile`` instead.

This module does not modify either frozen evaluator.  A successor calls the
frozen verifier first, admits only its exact path-spelling failure, proves that
the recorded and expected paths name the same existing files, substitutes the
expected spellings in a private copy, and then reruns the complete frozen
verifier.  Every non-path check therefore remains owned by the frozen verifier.
"""

from __future__ import annotations

import copy
import os
from pathlib import Path
from typing import Any, Callable, Mapping


R23D65_PATH_SPELLING_FAILURE = "R23D65_TRACE_ARTIFACT_CAS_PATH"
R23D77_FILE_IDENTITY_FAILURE = "R23D77_TRACE_ARTIFACT_CAS_FILE_IDENTITY"
ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"

FrozenCasVerifier = Callable[..., list[str]]


def same_existing_file(left: Path, right: Path) -> bool:
    """Return whether two path spellings identify the same existing file."""

    try:
        return os.path.samefile(os.fspath(left), os.fspath(right))
    except (OSError, TypeError, ValueError):
        return False


def alternate_windows_spelling(path: Path) -> Path:
    """Return the ordinary/extended Windows alias for an absolute path."""

    absolute = os.path.abspath(os.fspath(path))
    if os.name != "nt":
        return Path(absolute)
    if absolute.startswith("\\\\?\\UNC\\"):
        return Path("\\\\" + absolute[8:])
    if absolute.startswith("\\\\?\\"):
        return Path(absolute[4:])
    if absolute.startswith("\\\\"):
        return Path("\\\\?\\UNC\\" + absolute[2:])
    return Path("\\\\?\\" + absolute)


def expected_cas_paths(
    entry: Mapping[str, Any], *, authority_repo_root: Path
) -> tuple[Path, Path] | None:
    """Project the frozen SporeSpore CAS payload and manifest locations."""

    artifact = entry.get("trace_artifact")
    if not isinstance(artifact, Mapping):
        return None
    digest = str(artifact.get("sha256", ""))
    digest_hex = digest.removeprefix("sha256:")
    if (
        artifact.get("schema_version") != ARTIFACT_SCHEMA
        or len(digest_hex) != 64
        or any(character not in "0123456789abcdef" for character in digest_hex)
    ):
        return None
    directory = (
        authority_repo_root.resolve().parent
        / "SporeSpore_Evidence"
        / "artifacts"
        / "sha256"
        / digest_hex
    ).resolve()
    return directory / "payload.bin", directory / "manifest.json"


def verify_with_existing_file_identity(
    entry: Mapping[str, Any],
    *,
    authority_repo_root: Path,
    frozen_verifier: FrozenCasVerifier,
) -> list[str]:
    """Run a frozen CAS verifier with only path spelling repaired.

    The complete frozen verifier runs before and after the repair.  No failure
    other than its exact R23D65 path-spelling failure is eligible for repair.
    A missing path or a path to any other existing file fails closed.
    """

    original_failures = list(
        frozen_verifier(entry, authority_repo_root=authority_repo_root)
    )
    if original_failures != [R23D65_PATH_SPELLING_FAILURE]:
        return original_failures

    expected = expected_cas_paths(entry, authority_repo_root=authority_repo_root)
    artifact = entry.get("trace_artifact")
    if expected is None or not isinstance(artifact, Mapping):
        return [R23D77_FILE_IDENTITY_FAILURE]
    expected_payload, expected_manifest = expected
    recorded_payload = Path(str(artifact.get("payload_path", "")))
    recorded_manifest = Path(str(artifact.get("manifest_path", "")))
    if not same_existing_file(
        recorded_payload, expected_payload
    ) or not same_existing_file(recorded_manifest, expected_manifest):
        return [R23D77_FILE_IDENTITY_FAILURE]

    normalized = copy.deepcopy(dict(entry))
    normalized_artifact = normalized.get("trace_artifact")
    if not isinstance(normalized_artifact, dict):
        return [R23D77_FILE_IDENTITY_FAILURE]
    normalized_artifact["payload_path"] = os.fspath(expected_payload)
    normalized_artifact["manifest_path"] = os.fspath(expected_manifest)
    return list(
        frozen_verifier(normalized, authority_repo_root=authority_repo_root)
    )
