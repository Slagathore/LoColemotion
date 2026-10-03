"""Shared R23D74 trace-retention receipt projection and Python validator.

This module changes no trace row, behavior gate, threshold, or selector.  It
projects the already-validated nested ``trace_summary.row_count`` to the one
top-level integer required by all three native consumers, then verifies the
complete receipt identity.
"""

from __future__ import annotations

import copy
import hashlib
from pathlib import Path
from typing import Any, Mapping


ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"


class R23D74ReceiptContractError(RuntimeError):
    """Fail-closed receipt-contract error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R23D74ReceiptContractError(code)


def _exact_nonnegative_integer(value: Any) -> bool:
    return type(value) is int and value >= 0


def project_retention_receipt(
    receipt: Mapping[str, Any],
    *,
    expected_row_count: int | None = None,
) -> dict[str, Any]:
    """Return the successor receipt with one validated top-level row count."""

    _require(isinstance(receipt, Mapping), "R23D74_RECEIPT_NOT_OBJECT")
    summary = receipt.get("trace_summary")
    artifact = receipt.get("trace_artifact")
    _require(isinstance(summary, Mapping), "R23D74_TRACE_SUMMARY_NOT_OBJECT")
    _require(isinstance(artifact, Mapping), "R23D74_TRACE_ARTIFACT_NOT_OBJECT")
    nested = summary.get("row_count")
    _require(
        _exact_nonnegative_integer(nested),
        "R23D74_NESTED_ROW_COUNT_NOT_INTEGER",
    )
    if expected_row_count is not None:
        _require(
            _exact_nonnegative_integer(expected_row_count)
            and nested == expected_row_count,
            "R23D74_NESTED_ROW_COUNT_UNEXPECTED",
        )
    if "row_count" in receipt:
        _require(
            _exact_nonnegative_integer(receipt["row_count"])
            and receipt["row_count"] == nested,
            "R23D74_EXISTING_TOP_LEVEL_ROW_COUNT_MISMATCH",
        )
    _require(
        artifact.get("schema_version") == ARTIFACT_SCHEMA
        and summary.get("raw_sha256") == artifact.get("sha256")
        and summary.get("byte_length") == artifact.get("byte_length"),
        "R23D74_TRACE_SUMMARY_ARTIFACT_IDENTITY_MISMATCH",
    )
    value = copy.deepcopy(dict(receipt))
    value["row_count"] = nested
    return value


def validate_retention_receipt(
    receipt: Mapping[str, Any],
    *,
    expected_schema: str,
    expected_stage_id: str,
    expected_cell_id: str,
    expected_engine_id: str,
    expected_campaign_seed: int,
    expected_profile_id: str,
    expected_host_mapping_id: str,
    expected_row_count: int,
    expected_test_only: bool,
    verify_artifact_bytes: bool = False,
) -> list[str]:
    """Return exact contract failures; an empty list is acceptance."""

    if not isinstance(receipt, Mapping):
        return ["R23D74_RECEIPT_NOT_OBJECT"]
    failures: list[str] = []
    expected = {
        "schema_version": expected_schema,
        "stage_id": expected_stage_id,
        "cell_id": expected_cell_id,
        "engine_id": expected_engine_id,
        "campaign_seed": expected_campaign_seed,
        "profile_id": expected_profile_id,
        "host_mapping_id": expected_host_mapping_id,
    }
    for field, value in expected.items():
        if receipt.get(field) != value:
            failures.append(f"R23D74_{field.upper()}_MISMATCH")
    top_level = receipt.get("row_count")
    summary = receipt.get("trace_summary")
    nested = summary.get("row_count") if isinstance(summary, Mapping) else None
    if not _exact_nonnegative_integer(top_level):
        failures.append("R23D74_TOP_LEVEL_ROW_COUNT_NOT_INTEGER")
    elif top_level != expected_row_count:
        failures.append("R23D74_TOP_LEVEL_ROW_COUNT_UNEXPECTED")
    if not _exact_nonnegative_integer(nested):
        failures.append("R23D74_NESTED_ROW_COUNT_NOT_INTEGER")
    elif nested != expected_row_count:
        failures.append("R23D74_NESTED_ROW_COUNT_UNEXPECTED")
    if _exact_nonnegative_integer(top_level) and _exact_nonnegative_integer(nested):
        if top_level != nested:
            failures.append("R23D74_ROW_COUNT_PROJECTIONS_DIVERGED")
    if receipt.get("retained_before_terminal_entry") is not True:
        failures.append("R23D74_RETAINED_BEFORE_TERMINAL_INVALID")
    if receipt.get("world_attempt_count") != 0:
        failures.append("R23D74_WORLD_ATTEMPT_COUNT_INVALID")
    if receipt.get("world_build_count") != 0:
        failures.append("R23D74_WORLD_BUILD_COUNT_INVALID")
    if receipt.get("physical_acceptance_authority") is not False:
        failures.append("R23D74_PHYSICAL_AUTHORITY_INVALID")
    artifact = receipt.get("trace_artifact")
    if not isinstance(artifact, Mapping):
        failures.append("R23D74_TRACE_ARTIFACT_NOT_OBJECT")
    else:
        if artifact.get("schema_version") != ARTIFACT_SCHEMA:
            failures.append("R23D74_TRACE_ARTIFACT_SCHEMA_MISMATCH")
        if artifact.get("test_only") is not expected_test_only:
            failures.append("R23D74_TRACE_ARTIFACT_TEST_ONLY_MISMATCH")
        if isinstance(summary, Mapping):
            if artifact.get("sha256") != summary.get("raw_sha256"):
                failures.append("R23D74_TRACE_ARTIFACT_SHA_MISMATCH")
            if artifact.get("byte_length") != summary.get("byte_length"):
                failures.append("R23D74_TRACE_ARTIFACT_LENGTH_MISMATCH")
        if verify_artifact_bytes:
            try:
                payload = Path(str(artifact.get("payload_path", ""))).read_bytes()
                raw = "sha256:" + hashlib.sha256(payload).hexdigest()
            except OSError:
                failures.append("R23D74_TRACE_ARTIFACT_UNREADABLE")
            else:
                if raw != artifact.get("sha256"):
                    failures.append("R23D74_TRACE_ARTIFACT_BYTES_SHA_MISMATCH")
                if len(payload) != artifact.get("byte_length"):
                    failures.append("R23D74_TRACE_ARTIFACT_BYTES_LENGTH_MISMATCH")
                if payload.count(b"\n") != expected_row_count or not payload.endswith(b"\n"):
                    failures.append("R23D74_TRACE_ARTIFACT_ROW_COUNT_MISMATCH")
    return failures


def receipt_contract_mutations(receipt: Mapping[str, Any]) -> dict[str, dict[str, Any]]:
    """Return the four prospectively frozen malformed receipt controls."""

    missing = copy.deepcopy(dict(receipt))
    missing.pop("row_count", None)
    wrong_integer = copy.deepcopy(dict(receipt))
    wrong_integer["row_count"] = int(receipt.get("row_count", 0)) + 1
    wrong_type = copy.deepcopy(dict(receipt))
    wrong_type["row_count"] = str(receipt.get("row_count", ""))
    nested_mismatch = copy.deepcopy(dict(receipt))
    nested_mismatch["trace_summary"]["row_count"] = int(receipt.get("row_count", 0)) - 1
    return {
        "top_level_row_count_missing": missing,
        "top_level_row_count_wrong_integer": wrong_integer,
        "top_level_row_count_wrong_type": wrong_type,
        "top_level_and_nested_row_count_mismatch": nested_mismatch,
    }
