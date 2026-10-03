#!/usr/bin/env python3
"""Compile a deterministic, zero-world description of retained R23D65 traces.

This tool does not run a model, construct a physics world, step a solver,
evaluate the historical turning gate, or test cross-engine equivalence. It
rehashes a closed retained population and describes the only matched
cross-engine trace pair that population contains.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib
from typing import Any, Sequence


EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
EXPECTED_CONTRACT_SCHEMA = (
    "sporespore_r23d65_retained_trace_descriptive_divergence_contract_v1"
)
REPORT_SCHEMA = "sporespore_r23d65_retained_trace_descriptive_divergence_report_v1"
FOOT_IDS = ("front_left", "front_right", "rear_left", "rear_right")
OUTPUT_FILES = (
    "README.md",
    "report.json",
    "summary.csv",
    "per_step_reference_zero.csv",
    "contact_events.csv",
)


class AnalysisError(RuntimeError):
    """Fail-closed analysis error with a stable diagnostic code."""


def fail(code: str, detail: str) -> None:
    raise AnalysisError(f"{code}: {detail}")


def require(condition: bool, code: str, detail: str) -> None:
    if not condition:
        fail(code, detail)


def sha256_bytes(payload: bytes) -> str:
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return "sha256:" + digest.hexdigest()


def artifact_identity(path: Path) -> dict[str, Any]:
    require(path.is_file(), "INPUT_FILE_MISSING", str(path))
    return {
        "path": str(path),
        "byte_length": path.stat().st_size,
        "sha256": sha256_file(path),
    }


def read_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as stream:
            return json.load(stream)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        fail("JSON_READ_INVALID", f"{path}: {exc}")


def read_ndjson(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    try:
        with path.open("r", encoding="utf-8", newline="") as stream:
            for line_number, line in enumerate(stream, start=1):
                if not line.strip():
                    fail("NDJSON_BLANK_LINE", f"{path}:{line_number}")
                value = json.loads(line)
                if not isinstance(value, dict):
                    fail("NDJSON_ROW_NOT_OBJECT", f"{path}:{line_number}")
                rows.append(value)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        fail("NDJSON_READ_INVALID", f"{path}: {exc}")
    return rows


def canonical_json_bytes(value: Any) -> bytes:
    try:
        text = json.dumps(
            value,
            ensure_ascii=False,
            allow_nan=False,
            indent=2,
            sort_keys=True,
        )
    except (TypeError, ValueError) as exc:
        fail("JSON_SERIALIZATION_INVALID", str(exc))
    return (text + "\n").encode("utf-8")


def write_bytes(path: Path, payload: bytes) -> None:
    with path.open("xb") as stream:
        stream.write(payload)


def run_git(repo_root: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        cwd=repo_root,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if completed.returncode != 0:
        fail(
            "GIT_COMMAND_FAILED",
            f"git {' '.join(args)} exited {completed.returncode}: {completed.stderr.strip()}",
        )
    return completed.stdout.strip()


def validate_repository(repo_root: Path, expected_source_commit: str) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    observed_root = Path(run_git(repo_root, "rev-parse", "--show-toplevel")).resolve()
    require(observed_root == repo_root, "REPO_ROOT_MISMATCH", str(observed_root))
    remote = run_git(repo_root, "remote", "get-url", "origin")
    require(remote == EXPECTED_REMOTE, "REPO_REMOTE_MISMATCH", remote)
    branch = run_git(repo_root, "branch", "--show-current")
    require(branch == "main", "REPO_BRANCH_MISMATCH", branch)
    status = run_git(repo_root, "status", "--porcelain=v1")
    require(status == "", "REPO_WORKTREE_DIRTY", status)
    head = run_git(repo_root, "rev-parse", "HEAD")
    require(head == expected_source_commit, "SOURCE_COMMIT_MISMATCH", head)
    origin_main = run_git(repo_root, "rev-parse", "origin/main")
    require(origin_main == head, "ORIGIN_MAIN_MISMATCH", origin_main)
    return {
        "repo_root": str(repo_root),
        "origin_url": remote,
        "branch": branch,
        "source_commit": head,
        "origin_main_commit": origin_main,
        "worktree_clean": True,
    }


def canonical_population_manifest(root: Path) -> tuple[bytes, list[dict[str, Any]]]:
    require(root.is_dir(), "ATTEMPT_ROOT_MISSING", str(root))
    records: list[dict[str, Any]] = []
    for path in sorted(
        (candidate for candidate in root.rglob("*") if candidate.is_file()),
        key=lambda candidate: candidate.relative_to(root).as_posix(),
    ):
        relative_path = path.relative_to(root).as_posix()
        records.append(
            {
                "relative_path": relative_path,
                "byte_length": path.stat().st_size,
                "sha256": sha256_file(path),
            }
        )
    text = "".join(
        f"{record['relative_path']}\t{record['byte_length']}\t{record['sha256']}\n"
        for record in records
    )
    return text.encode("utf-8"), records


def is_finite_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def exact_false_map(value: Any, path: str) -> None:
    require(isinstance(value, dict) and value, "FALSE_CLAIM_MAP_INVALID", path)
    for key, item in value.items():
        require(item is False, "FALSE_CLAIM_PROMOTED", f"{path}.{key}={item!r}")


def validate_contract(contract: dict[str, Any]) -> None:
    require(
        contract.get("schema_version") == EXPECTED_CONTRACT_SCHEMA,
        "CONTRACT_SCHEMA_INVALID",
        repr(contract.get("schema_version")),
    )
    require(
        contract.get("status") == "frozen_retrospective_descriptive_development_analysis",
        "CONTRACT_STATUS_INVALID",
        repr(contract.get("status")),
    )
    scope = contract.get("ledger_scope")
    require(isinstance(scope, dict), "LEDGER_SCOPE_MISSING", "ledger_scope")
    require(scope.get("question_class") == "development", "QUESTION_CLASS_INVALID", repr(scope))
    authority = contract.get("authority_classification")
    require(isinstance(authority, dict), "AUTHORITY_CLASSIFICATION_MISSING", "authority")
    require(authority.get("outcome_aware") is True, "OUTCOME_AWARENESS_MISSING", repr(authority))
    for key in (
        "prospective",
        "threshold_bearing",
        "selection_bearing",
        "equivalence_or_non_inferiority_test",
        "superiority_test",
        "population_inference",
        "gate_advancement",
        "historical_campaign_reinterpretation",
    ):
        require(authority.get(key) is False, "AUTHORITY_BOUNDARY_INVALID", key)
    require(authority.get("descriptive_only") is True, "DESCRIPTIVE_SCOPE_MISSING", "descriptive_only")
    require(authority.get("non_authoritative") is True, "NON_AUTHORITY_MISSING", "non_authoritative")

    traces = contract.get("trace_sources")
    require(isinstance(traces, list) and len(traces) == 4, "TRACE_SOURCE_COUNT_INVALID", repr(traces))
    identities = {(item.get("engine_id"), item.get("arm_id")) for item in traces if isinstance(item, dict)}
    require(
        identities
        == {
            ("godot_jolt", "reference_zero"),
            ("godot_jolt", "positive_heading"),
            ("godot_jolt", "negative_heading"),
            ("rapier_parry", "reference_zero"),
        },
        "TRACE_SOURCE_IDENTITIES_INVALID",
        repr(sorted(identities)),
    )
    reference_roles = [
        item
        for item in traces
        if item.get("comparison_role") == "matched_cross_engine_reference"
    ]
    require(len(reference_roles) == 2, "MATCHED_PAIR_COUNT_INVALID", str(len(reference_roles)))
    context_roles = [
        item
        for item in traces
        if item.get("comparison_role") == "within_godot_command_context_only"
    ]
    require(len(context_roles) == 2, "CONTEXT_TRACE_COUNT_INVALID", str(len(context_roles)))

    availability = contract.get("requested_measurement_availability")
    require(isinstance(availability, list) and len(availability) == 4, "AVAILABILITY_TABLE_INVALID", repr(availability))
    by_name = {item.get("requested_measurement"): item for item in availability if isinstance(item, dict)}
    require(
        by_name.get("per-step joint-angle RMS between engines", {}).get("status")
        == "unavailable_not_recorded",
        "JOINT_AVAILABILITY_INVALID",
        repr(by_name.get("per-step joint-angle RMS between engines")),
    )
    require(
        by_name.get("center-of-mass trajectory drift", {}).get("status")
        == "unavailable_not_recorded",
        "COM_AVAILABILITY_INVALID",
        repr(by_name.get("center-of-mass trajectory drift")),
    )
    require(
        by_name.get("per-step joint-angle RMS between engines", {}).get("substitution_permitted")
        is False,
        "JOINT_SUBSTITUTION_INVALID",
        "joint angles",
    )
    require(
        by_name.get("center-of-mass trajectory drift", {}).get("substitution_permitted")
        is False,
        "COM_SUBSTITUTION_INVALID",
        "center of mass",
    )
    exact_false_map(contract.get("claim_boundary"), "claim_boundary")

    output = contract.get("output_contract")
    require(isinstance(output, dict), "OUTPUT_CONTRACT_MISSING", "output_contract")
    declared_outputs = tuple(item.get("path") for item in output.get("files", []))
    require(
        declared_outputs == (*OUTPUT_FILES, "bundle-manifest.tsv"),
        "OUTPUT_FILE_SET_INVALID",
        repr(declared_outputs),
    )


def validate_closure_and_population(
    repo_root: Path,
    attempt_root: Path,
    contract: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    campaign = contract["source_campaign"]
    closure_path = repo_root / campaign["closure_path"]
    closure_identity = artifact_identity(closure_path)
    require(
        closure_identity["byte_length"] == campaign["closure_byte_length"],
        "CLOSURE_BYTE_LENGTH_MISMATCH",
        repr(closure_identity),
    )
    require(
        closure_identity["sha256"] == campaign["closure_sha256"],
        "CLOSURE_DIGEST_MISMATCH",
        repr(closure_identity),
    )
    closure = read_json(closure_path)
    require(isinstance(closure, dict), "CLOSURE_NOT_OBJECT", str(closure_path))
    require(closure.get("campaign_id") == campaign["campaign_id"], "CLOSURE_CAMPAIGN_MISMATCH", "campaign_id")
    require(closure.get("source_commit") == campaign["source_commit"], "CLOSURE_SOURCE_MISMATCH", "source_commit")
    require(closure.get("status") == campaign["campaign_status"], "CLOSURE_STATUS_MISMATCH", repr(closure.get("status")))
    official = closure.get("official_result")
    require(isinstance(official, dict), "CLOSURE_OFFICIAL_RESULT_MISSING", "official_result")
    for key in (
        "scientific_result_exists",
        "physical_result_exists",
        "finite_three_engine_turning",
        "portable_basic_turning",
        "posthoc_trace_evaluation_performed",
        "release_authority",
        "physical_acceptance_authority",
    ):
        require(official.get(key) is False, "CLOSURE_OFFICIAL_RESULT_PROMOTED", key)

    retained = contract["retained_population"]
    expected_attempt = Path(retained["attempt_root"]).resolve()
    require(attempt_root.resolve() == expected_attempt, "ATTEMPT_ROOT_MISMATCH", str(attempt_root.resolve()))
    physical = closure.get("physical_evidence")
    require(isinstance(physical, dict), "CLOSURE_PHYSICAL_EVIDENCE_MISSING", "physical_evidence")
    require(Path(physical.get("attempt_root", "")).resolve() == expected_attempt, "CLOSURE_ATTEMPT_ROOT_MISMATCH", repr(physical.get("attempt_root")))
    for closure_key, contract_key in (
        ("complete_retained_file_population_count", "complete_file_count"),
        ("complete_retained_file_population_byte_count", "complete_byte_count"),
        ("canonical_population_manifest_byte_length", "canonical_manifest_byte_length"),
        ("canonical_population_manifest_sha256", "canonical_manifest_sha256"),
    ):
        require(
            physical.get(closure_key) == retained[contract_key],
            "CLOSURE_POPULATION_BINDING_MISMATCH",
            closure_key,
        )

    manifest_bytes, records = canonical_population_manifest(attempt_root)
    observed_population = {
        "attempt_root": str(attempt_root.resolve()),
        "file_count": len(records),
        "byte_count": sum(record["byte_length"] for record in records),
        "canonical_manifest_byte_length": len(manifest_bytes),
        "canonical_manifest_sha256": sha256_bytes(manifest_bytes),
        "first_relative_path": records[0]["relative_path"] if records else None,
        "last_relative_path": records[-1]["relative_path"] if records else None,
    }
    for observed_key, contract_key in (
        ("file_count", "complete_file_count"),
        ("byte_count", "complete_byte_count"),
        ("canonical_manifest_byte_length", "canonical_manifest_byte_length"),
        ("canonical_manifest_sha256", "canonical_manifest_sha256"),
    ):
        require(
            observed_population[observed_key] == retained[contract_key],
            "RETAINED_POPULATION_DRIFT",
            f"{observed_key}: expected {retained[contract_key]!r}, observed {observed_population[observed_key]!r}",
        )
    return closure_identity, observed_population


def read_prefixed_json(path: Path, prefix: str) -> dict[str, Any]:
    try:
        text = path.read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError) as exc:
        fail("PREFIXED_JSON_READ_INVALID", f"{path}: {exc}")
    require(text.startswith(prefix), "PREFIXED_JSON_MARKER_MISSING", str(path))
    try:
        value = json.loads(text[len(prefix) :])
    except json.JSONDecodeError as exc:
        fail("PREFIXED_JSON_PAYLOAD_INVALID", f"{path}: {exc}")
    require(isinstance(value, dict), "PREFIXED_JSON_NOT_OBJECT", str(path))
    return value


def validate_runtime_provenance(
    repo_root: Path,
    attempt_root: Path,
    contract: dict[str, Any],
) -> dict[str, Any]:
    campaign = contract["source_campaign"]
    declared_runtime = contract["runtime_identity"]

    freeze_path = attempt_root / "physical-freeze.json"
    freeze = read_json(freeze_path)
    require(isinstance(freeze, dict), "PHYSICAL_FREEZE_NOT_OBJECT", str(freeze_path))
    require(freeze.get("source_commit") == campaign["source_commit"], "PHYSICAL_FREEZE_SOURCE_MISMATCH", "source_commit")
    external = {
        item.get("name"): item
        for item in freeze.get("external_runtime_bindings", [])
        if isinstance(item, dict)
    }
    godot_host = external.get("godot_jolt_host")
    require(isinstance(godot_host, dict), "GODOT_HOST_BINDING_MISSING", "physical-freeze.json")
    require(
        godot_host.get("raw_sha256")
        == declared_runtime["godot_jolt"]["host_executable_sha256"],
        "GODOT_HOST_DIGEST_MISMATCH",
        repr(godot_host),
    )

    source_bindings = {
        item.get("path"): item
        for item in freeze.get("source_bindings", [])
        if isinstance(item, dict)
    }
    cargo_binding = source_bindings.get(declared_runtime["rapier_parry"]["cargo_lock_path"])
    require(isinstance(cargo_binding, dict), "CARGO_LOCK_BINDING_MISSING", "physical-freeze.json")
    require(
        cargo_binding.get("raw_sha256")
        == declared_runtime["rapier_parry"]["cargo_lock_sha256"],
        "CARGO_LOCK_FREEZE_DIGEST_MISMATCH",
        repr(cargo_binding),
    )
    cargo_lock_path = repo_root / declared_runtime["rapier_parry"]["cargo_lock_path"]
    require(
        sha256_file(cargo_lock_path)
        == declared_runtime["rapier_parry"]["cargo_lock_sha256"],
        "CARGO_LOCK_CHECKOUT_DIGEST_MISMATCH",
        str(cargo_lock_path),
    )
    try:
        with cargo_lock_path.open("rb") as stream:
            cargo_lock = tomllib.load(stream)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        fail("CARGO_LOCK_PARSE_INVALID", f"{cargo_lock_path}: {exc}")
    locked_versions = {
        item.get("name"): item.get("version")
        for item in cargo_lock.get("package", [])
        if isinstance(item, dict)
    }
    require(
        locked_versions.get("rapier3d")
        == declared_runtime["rapier_parry"]["rapier3d_version"],
        "RAPIER_VERSION_MISMATCH",
        repr(locked_versions.get("rapier3d")),
    )
    require(
        locked_versions.get("parry3d")
        == declared_runtime["rapier_parry"]["parry3d_version"],
        "PARRY_VERSION_MISMATCH",
        repr(locked_versions.get("parry3d")),
    )

    godot_terminal_path = (
        attempt_root
        / "cells/godot_jolt__s23175__selected_profile__reference_zero/terminal.json"
    )
    godot_terminal = read_json(godot_terminal_path)
    require(isinstance(godot_terminal, dict), "GODOT_TERMINAL_NOT_OBJECT", str(godot_terminal_path))
    require(godot_terminal.get("engine_id") == "godot_jolt", "GODOT_TERMINAL_ENGINE_MISMATCH", "engine_id")
    require(godot_terminal.get("source_commit") == campaign["source_commit"], "GODOT_TERMINAL_SOURCE_MISMATCH", "source_commit")
    require(godot_terminal.get("campaign_id") == campaign["campaign_id"], "GODOT_TERMINAL_CAMPAIGN_MISMATCH", "campaign_id")
    require(godot_terminal.get("campaign_seed") == campaign["campaign_seed"], "GODOT_TERMINAL_SEED_MISMATCH", "campaign_seed")
    require(godot_terminal.get("profile_id") == campaign["actuator_cap_profile_id"], "GODOT_TERMINAL_PROFILE_MISMATCH", "profile_id")
    godot_summary = godot_terminal.get("raw_sdk_authority_summary")
    require(isinstance(godot_summary, dict), "GODOT_RUNTIME_SUMMARY_MISSING", "raw_sdk_authority_summary")
    require(
        godot_summary.get("controller_policy_id") == campaign["controller_policy_id"],
        "GODOT_POLICY_MISMATCH",
        repr(godot_summary.get("controller_policy_id")),
    )
    adapter = godot_summary.get("adapter_manifest")
    require(isinstance(adapter, dict), "GODOT_ADAPTER_MANIFEST_MISSING", "adapter_manifest")
    require(adapter.get("godot_api_version") == "4.7", "GODOT_VERSION_MISMATCH", repr(adapter.get("godot_api_version")))
    require(adapter.get("physics_engine") == "Jolt Physics", "JOLT_IDENTITY_MISMATCH", repr(adapter.get("physics_engine")))
    require(
        adapter.get("solver_velocity_steps")
        == declared_runtime["godot_jolt"]["solver_velocity_steps"],
        "GODOT_VELOCITY_STEPS_MISMATCH",
        repr(adapter.get("solver_velocity_steps")),
    )
    require(
        adapter.get("solver_position_steps")
        == declared_runtime["godot_jolt"]["solver_position_steps"],
        "GODOT_POSITION_STEPS_MISMATCH",
        repr(adapter.get("solver_position_steps")),
    )

    rapier_stdout_path = (
        attempt_root
        / "cells/rapier_parry__s23175__selected_profile__reference_zero/stdout.txt"
    )
    rapier_terminal = read_prefixed_json(
        rapier_stdout_path, "QSDK_R23D65_RAPIER_TERMINAL "
    )
    require(rapier_terminal.get("engine_id") == "rapier_parry", "RAPIER_TERMINAL_ENGINE_MISMATCH", "engine_id")
    require(rapier_terminal.get("source_commit") == campaign["source_commit"], "RAPIER_TERMINAL_SOURCE_MISMATCH", "source_commit")
    require(rapier_terminal.get("campaign_id") == campaign["campaign_id"], "RAPIER_TERMINAL_CAMPAIGN_MISMATCH", "campaign_id")
    require(rapier_terminal.get("campaign_seed") == campaign["campaign_seed"], "RAPIER_TERMINAL_SEED_MISMATCH", "campaign_seed")
    require(rapier_terminal.get("profile_id") == campaign["actuator_cap_profile_id"], "RAPIER_TERMINAL_PROFILE_MISMATCH", "profile_id")
    require(
        rapier_terminal.get("controller_policy_id") == campaign["controller_policy_id"],
        "RAPIER_POLICY_MISMATCH",
        repr(rapier_terminal.get("controller_policy_id")),
    )
    rapier_mapping = rapier_terminal.get("actuator_cap_profile_host_mapping_receipt")
    require(isinstance(rapier_mapping, dict), "RAPIER_MAPPING_RECEIPT_MISSING", "host mapping")
    require(
        rapier_mapping.get("rapier_solver_iteration_count")
        == declared_runtime["rapier_parry"]["solver_iteration_count"],
        "RAPIER_SOLVER_ITERATION_MISMATCH",
        repr(rapier_mapping.get("rapier_solver_iteration_count")),
    )

    return {
        "physical_freeze": artifact_identity(freeze_path),
        "godot_terminal": artifact_identity(godot_terminal_path),
        "rapier_terminal_stdout": artifact_identity(rapier_stdout_path),
        "shared_source_commit": campaign["source_commit"],
        "shared_campaign_id": campaign["campaign_id"],
        "shared_campaign_seed": campaign["campaign_seed"],
        "shared_controller_policy_id": campaign["controller_policy_id"],
        "shared_actuator_cap_profile_id": campaign["actuator_cap_profile_id"],
        "godot_host_executable_sha256": godot_host["raw_sha256"],
        "godot_api_version": adapter["godot_api_version"],
        "godot_physics_engine": adapter["physics_engine"],
        "godot_solver_velocity_steps": adapter["solver_velocity_steps"],
        "godot_solver_position_steps": adapter["solver_position_steps"],
        "cargo_lock_sha256": cargo_binding["raw_sha256"],
        "rapier3d_version": locked_versions["rapier3d"],
        "parry3d_version": locked_versions["parry3d"],
        "rapier_solver_iteration_count": rapier_mapping[
            "rapier_solver_iteration_count"
        ],
        "all_runtime_bindings_match": True,
    }


def expected_segment_for_step(segments: Sequence[dict[str, Any]], step: int) -> str:
    matches = [
        item["segment_id"]
        for item in segments
        if item["first_step"] <= step <= item["last_step"]
    ]
    require(len(matches) == 1, "SEGMENT_PARTITION_INVALID", f"step={step}, matches={matches}")
    return matches[0]


def expected_heading_offset(spec: dict[str, Any], segment_id: str) -> float:
    if segment_id == "commanded_turn":
        return float(spec["desired_heading_offset_rad"])
    return 0.0


def validate_contact_map(value: Any, path: str) -> dict[str, bool]:
    require(isinstance(value, dict), "CONTACT_MAP_NOT_OBJECT", path)
    require(set(value) == set(FOOT_IDS), "CONTACT_KEYS_INVALID", f"{path}: {sorted(value)}")
    for foot in FOOT_IDS:
        require(isinstance(value[foot], bool), "CONTACT_VALUE_INVALID", f"{path}.{foot}")
    return value


def validate_rows(
    rows: Any,
    spec: dict[str, Any],
    segments: Sequence[dict[str, Any]],
    campaign: dict[str, Any],
) -> dict[str, Any]:
    require(isinstance(rows, list), "TRACE_NOT_ARRAY", spec["path"])
    require(len(rows) == spec["row_count"], "TRACE_ROW_COUNT_MISMATCH", spec["path"])
    expected_cell = (
        f"{spec['engine_id']}__s{campaign['campaign_seed']}__selected_profile__{spec['arm_id']}"
    )
    previous_after: dict[str, bool] | None = None
    reanchor_steps: list[int] = []
    union_fields: set[str] = set()
    for index, row in enumerate(rows):
        path = f"{spec['path']}[{index}]"
        require(isinstance(row, dict), "TRACE_ROW_NOT_OBJECT", path)
        union_fields.update(row)
        require(row.get("schema_version") == spec["row_schema_version"], "TRACE_SCHEMA_MISMATCH", path)
        require(row.get("cell_id") == expected_cell, "TRACE_CELL_ID_MISMATCH", path)
        require(row.get("semantic_step") == index, "TRACE_STEP_NOT_CONTIGUOUS", path)
        expected_segment = expected_segment_for_step(segments, index)
        require(row.get("segment_id") == expected_segment, "TRACE_SEGMENT_MISMATCH", path)
        desired = row.get("desired_heading_offset_rad")
        require(is_finite_number(desired), "TRACE_DESIRED_HEADING_NONFINITE", path)
        require(
            float(desired) == expected_heading_offset(spec, expected_segment),
            "TRACE_DESIRED_HEADING_MISMATCH",
            path,
        )
        require(is_finite_number(row.get("measured_yaw_rad")), "TRACE_YAW_NONFINITE", path)
        require(is_finite_number(row.get("torso_tilt_rad")), "TRACE_TILT_NONFINITE", path)
        require(isinstance(row.get("torso_ground_contact"), bool), "TRACE_TORSO_CONTACT_INVALID", path)
        position = row.get("torso_position_world_m")
        require(isinstance(position, list) and len(position) == 3, "TRACE_POSITION_INVALID", path)
        require(all(is_finite_number(value) for value in position), "TRACE_POSITION_NONFINITE", path)
        before = validate_contact_map(row.get("ordered_foot_contacts_before"), path + ".before")
        after = validate_contact_map(row.get("ordered_foot_contacts_after"), path + ".after")
        if previous_after is not None:
            require(before == previous_after, "TRACE_CONTACT_DISCONTINUITY", path)
        previous_after = dict(after)
        limb_phase = row.get("ordered_limb_phase_before")
        require(isinstance(limb_phase, list) and len(limb_phase) == 4, "TRACE_LIMB_PHASE_INVALID", path)
        require(
            {item.get("limb_id") for item in limb_phase if isinstance(item, dict)} == set(FOOT_IDS),
            "TRACE_LIMB_PHASE_IDS_INVALID",
            path,
        )
        require(
            row.get("task_frame_origin_policy_id")
            == "warmup_preserving_command_onset_origin_reanchor_v1",
            "TRACE_ORIGIN_POLICY_MISMATCH",
            path,
        )
        origin = row.get("task_frame_origin_world_m")
        require(isinstance(origin, list) and len(origin) == 3, "TRACE_ORIGIN_INVALID", path)
        require(all(is_finite_number(value) for value in origin), "TRACE_ORIGIN_NONFINITE", path)
        reanchored = row.get("task_frame_origin_reanchored_this_step")
        require(isinstance(reanchored, bool), "TRACE_REANCHOR_FLAG_INVALID", path)
        if reanchored:
            reanchor_steps.append(index)
    require(reanchor_steps == [600, 1800, 2400], "TRACE_REANCHOR_STEPS_INVALID", repr(reanchor_steps))
    return {
        "cell_id": expected_cell,
        "row_count": len(rows),
        "first_semantic_step": 0,
        "last_semantic_step": len(rows) - 1,
        "contact_continuity_mismatch_count": 0,
        "task_frame_origin_transition_steps": reanchor_steps,
        "top_level_field_count": len(union_fields),
        "top_level_fields": sorted(union_fields),
    }


def load_and_validate_trace(
    attempt_root: Path,
    spec: dict[str, Any],
    segments: Sequence[dict[str, Any]],
    campaign: dict[str, Any],
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    path = attempt_root / Path(spec["path"])
    identity = artifact_identity(path)
    require(identity["byte_length"] == spec["byte_length"], "TRACE_BYTE_LENGTH_MISMATCH", spec["path"])
    require(identity["sha256"] == spec["sha256"], "TRACE_DIGEST_MISMATCH", spec["path"])
    if spec["format"] == "json_array":
        rows = read_json(path)
    elif spec["format"] == "ndjson":
        rows = read_ndjson(path)
    else:
        fail("TRACE_FORMAT_UNSUPPORTED", repr(spec["format"]))
    validation = validate_rows(rows, spec, segments, campaign)
    identity.update(
        {
            "relative_path": spec["path"],
            "engine_id": spec["engine_id"],
            "arm_id": spec["arm_id"],
            "comparison_role": spec["comparison_role"],
            "format": spec["format"],
            "row_schema_version": spec["row_schema_version"],
            "validation": validation,
        }
    )
    return rows, identity


def unwrap_angles(rows: Sequence[dict[str, Any]]) -> list[float]:
    raw = [float(row["measured_yaw_rad"]) for row in rows]
    unwrapped = [raw[0]]
    for previous, current in zip(raw, raw[1:]):
        delta = math.atan2(math.sin(current - previous), math.cos(current - previous))
        unwrapped.append(unwrapped[-1] + delta)
    return unwrapped


def vector_sub(left: Sequence[float], right: Sequence[float]) -> list[float]:
    return [float(a) - float(b) for a, b in zip(left, right)]


def vector_norm(values: Sequence[float]) -> float:
    return math.sqrt(math.fsum(float(value) * float(value) for value in values))


def rms(values: Sequence[float]) -> float:
    require(bool(values), "EMPTY_METRIC_SERIES", "rms")
    return math.sqrt(math.fsum(float(value) * float(value) for value in values) / len(values))


def mean(values: Sequence[float]) -> float:
    require(bool(values), "EMPTY_METRIC_SERIES", "mean")
    return math.fsum(float(value) for value in values) / len(values)


def quantile(values: Sequence[float], probability: float) -> float:
    require(bool(values), "EMPTY_METRIC_SERIES", "quantile")
    require(0.0 <= probability <= 1.0, "QUANTILE_PROBABILITY_INVALID", str(probability))
    ordered = sorted(float(value) for value in values)
    index = (len(ordered) - 1) * probability
    lower = math.floor(index)
    upper = math.ceil(index)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] + (index - lower) * (ordered[upper] - ordered[lower])


def radians_to_degrees(value: float) -> float:
    return math.degrees(value)


def path_length(rows: Sequence[dict[str, Any]]) -> float:
    positions = [row["torso_position_world_m"] for row in rows]
    return math.fsum(
        vector_norm(vector_sub(current, previous))
        for previous, current in zip(positions, positions[1:])
    )


def detect_contact_events(
    rows: Sequence[dict[str, Any]],
    engine_id: str,
    hz: int,
) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    for row in rows:
        step = int(row["semantic_step"])
        before = row["ordered_foot_contacts_before"]
        after = row["ordered_foot_contacts_after"]
        for foot in FOOT_IDS:
            if before[foot] != after[foot]:
                transition = "touchdown" if after[foot] else "liftoff"
                events.append(
                    {
                        "event_id": f"{engine_id}:{foot}:{transition}:{step}",
                        "engine_id": engine_id,
                        "foot_id": foot,
                        "transition": transition,
                        "semantic_step": step,
                        "semantic_time_s": step / hz,
                        "segment_id": row["segment_id"],
                    }
                )
    return events


def add_nearest_event_relationships(
    godot_events: list[dict[str, Any]],
    rapier_events: list[dict[str, Any]],
    hz: int,
) -> list[dict[str, Any]]:
    all_events = godot_events + rapier_events
    lookup: dict[tuple[str, str, str], list[dict[str, Any]]] = {}
    for event in all_events:
        lookup.setdefault(
            (event["engine_id"], event["foot_id"], event["transition"]), []
        ).append(event)

    nearest_by_id: dict[str, str | None] = {}
    for event in all_events:
        other_engine = "rapier_parry" if event["engine_id"] == "godot_jolt" else "godot_jolt"
        candidates = lookup.get((other_engine, event["foot_id"], event["transition"]), [])
        if not candidates:
            nearest_by_id[event["event_id"]] = None
            continue
        nearest = min(
            candidates,
            key=lambda item: (
                abs(int(item["semantic_step"]) - int(event["semantic_step"])),
                int(item["semantic_step"]),
            ),
        )
        nearest_by_id[event["event_id"]] = nearest["event_id"]

    by_id = {event["event_id"]: event for event in all_events}
    enriched: list[dict[str, Any]] = []
    for event in all_events:
        nearest_id = nearest_by_id[event["event_id"]]
        item = dict(event)
        if nearest_id is None:
            item.update(
                {
                    "nearest_other_event_id": None,
                    "nearest_other_step": None,
                    "signed_godot_minus_rapier_steps": None,
                    "absolute_offset_steps": None,
                    "absolute_offset_ms": None,
                    "mutual_nearest": False,
                }
            )
        else:
            other = by_id[nearest_id]
            if event["engine_id"] == "godot_jolt":
                signed = int(event["semantic_step"]) - int(other["semantic_step"])
            else:
                signed = int(other["semantic_step"]) - int(event["semantic_step"])
            item.update(
                {
                    "nearest_other_event_id": nearest_id,
                    "nearest_other_step": int(other["semantic_step"]),
                    "signed_godot_minus_rapier_steps": signed,
                    "absolute_offset_steps": abs(signed),
                    "absolute_offset_ms": abs(signed) * 1000.0 / hz,
                    "mutual_nearest": nearest_by_id.get(nearest_id) == event["event_id"],
                }
            )
        enriched.append(item)
    return sorted(
        enriched,
        key=lambda item: (
            int(item["semantic_step"]),
            item["engine_id"],
            item["foot_id"],
            item["transition"],
        ),
    )


def contact_count(events: Sequence[dict[str, Any]], engine_id: str, foot: str | None = None) -> int:
    return sum(
        1
        for event in events
        if event["engine_id"] == engine_id and (foot is None or event["foot_id"] == foot)
    )


def event_offset_summary(events: Sequence[dict[str, Any]]) -> dict[str, Any]:
    available = [
        event
        for event in events
        if event.get("absolute_offset_steps") is not None
    ]
    absolute_steps = [float(event["absolute_offset_steps"]) for event in available]
    signed_steps = [float(event["signed_godot_minus_rapier_steps"]) for event in available]
    if not absolute_steps:
        return {
            "event_observation_count": 0,
            "median_absolute_offset_steps": None,
            "p90_absolute_offset_steps": None,
            "maximum_absolute_offset_steps": None,
            "median_signed_godot_minus_rapier_steps": None,
        }
    return {
        "event_observation_count": len(absolute_steps),
        "median_absolute_offset_steps": quantile(absolute_steps, 0.5),
        "p90_absolute_offset_steps": quantile(absolute_steps, 0.9),
        "maximum_absolute_offset_steps": max(absolute_steps),
        "median_signed_godot_minus_rapier_steps": quantile(signed_steps, 0.5),
    }


def add_millisecond_fields(summary: dict[str, Any], hz: int) -> dict[str, Any]:
    enriched = dict(summary)
    for key in (
        "median_absolute_offset_steps",
        "p90_absolute_offset_steps",
        "maximum_absolute_offset_steps",
        "median_signed_godot_minus_rapier_steps",
    ):
        value = summary.get(key)
        enriched[key.replace("_steps", "_ms")] = None if value is None else float(value) * 1000.0 / hz
    return enriched


def trace_summary(
    rows: Sequence[dict[str, Any]],
    engine_id: str,
    arm_id: str,
    desired_heading_offset_rad: float,
    hz: int,
) -> dict[str, Any]:
    unwrapped = unwrap_angles(rows)
    first_position = [float(value) for value in rows[0]["torso_position_world_m"]]
    last_position = [float(value) for value in rows[-1]["torso_position_world_m"]]
    terminal_displacement = vector_sub(last_position, first_position)
    events = detect_contact_events(rows, engine_id, hz)
    turn_boundary_change = unwrapped[1800] - unwrapped[600]
    return {
        "engine_id": engine_id,
        "arm_id": arm_id,
        "desired_turn_window_heading_offset_rad": desired_heading_offset_rad,
        "desired_turn_window_heading_offset_deg": radians_to_degrees(desired_heading_offset_rad),
        "first_raw_yaw_rad": float(rows[0]["measured_yaw_rad"]),
        "last_raw_yaw_rad": float(rows[-1]["measured_yaw_rad"]),
        "terminal_start_aligned_heading_change_rad": unwrapped[-1] - unwrapped[0],
        "terminal_start_aligned_heading_change_deg": radians_to_degrees(unwrapped[-1] - unwrapped[0]),
        "turn_window_boundary_to_boundary_heading_change_rad": turn_boundary_change,
        "turn_window_boundary_to_boundary_heading_change_deg": radians_to_degrees(turn_boundary_change),
        "first_torso_position_world_m": first_position,
        "last_torso_position_world_m": last_position,
        "terminal_start_aligned_torso_displacement_xyz_m": terminal_displacement,
        "terminal_start_aligned_torso_displacement_3d_m": vector_norm(terminal_displacement),
        "torso_path_length_m": path_length(rows),
        "maximum_torso_tilt_rad": max(abs(float(row["torso_tilt_rad"])) for row in rows),
        "maximum_torso_tilt_deg": radians_to_degrees(
            max(abs(float(row["torso_tilt_rad"])) for row in rows)
        ),
        "torso_ground_contact_step_count": sum(
            1 for row in rows if row["torso_ground_contact"]
        ),
        "contact_event_count": len(events),
        "contact_event_count_by_foot": {
            foot: sum(1 for event in events if event["foot_id"] == foot)
            for foot in FOOT_IDS
        },
    }


def matched_analysis(
    godot_rows: Sequence[dict[str, Any]],
    rapier_rows: Sequence[dict[str, Any]],
    segments: Sequence[dict[str, Any]],
    hz: int,
) -> tuple[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]]]:
    require(len(godot_rows) == len(rapier_rows), "MATCHED_ROW_COUNT_MISMATCH", "reference_zero")
    godot_unwrapped = unwrap_angles(godot_rows)
    rapier_unwrapped = unwrap_angles(rapier_rows)
    godot_heading = [value - godot_unwrapped[0] for value in godot_unwrapped]
    rapier_heading = [value - rapier_unwrapped[0] for value in rapier_unwrapped]
    heading_separation = [left - right for left, right in zip(godot_heading, rapier_heading)]

    godot_origin = [float(value) for value in godot_rows[0]["torso_position_world_m"]]
    rapier_origin = [float(value) for value in rapier_rows[0]["torso_position_world_m"]]
    per_step: list[dict[str, Any]] = []
    torso_vectors: list[list[float]] = []
    torso_separation_3d: list[float] = []
    torso_separation_horizontal: list[float] = []
    contact_mismatch_samples = 0
    per_foot_mismatch = {foot: 0 for foot in FOOT_IDS}

    for index, (godot_row, rapier_row) in enumerate(zip(godot_rows, rapier_rows)):
        require(
            godot_row["segment_id"] == rapier_row["segment_id"],
            "MATCHED_SEGMENT_MISMATCH",
            str(index),
        )
        godot_displacement = vector_sub(godot_row["torso_position_world_m"], godot_origin)
        rapier_displacement = vector_sub(rapier_row["torso_position_world_m"], rapier_origin)
        torso_difference = vector_sub(godot_displacement, rapier_displacement)
        torso_vectors.append(torso_difference)
        separation_3d = vector_norm(torso_difference)
        separation_horizontal = math.hypot(torso_difference[0], torso_difference[2])
        torso_separation_3d.append(separation_3d)
        torso_separation_horizontal.append(separation_horizontal)
        mismatch_count = 0
        contact_columns: dict[str, Any] = {}
        for foot in FOOT_IDS:
            godot_contact = bool(godot_row["ordered_foot_contacts_after"][foot])
            rapier_contact = bool(rapier_row["ordered_foot_contacts_after"][foot])
            mismatch = godot_contact != rapier_contact
            contact_columns[f"godot_{foot}_contact"] = godot_contact
            contact_columns[f"rapier_{foot}_contact"] = rapier_contact
            contact_columns[f"{foot}_contact_mismatch"] = mismatch
            if mismatch:
                mismatch_count += 1
                contact_mismatch_samples += 1
                per_foot_mismatch[foot] += 1
        per_step.append(
            {
                "semantic_step": index,
                "semantic_time_s": index / hz,
                "segment_id": godot_row["segment_id"],
                "desired_heading_offset_rad": float(godot_row["desired_heading_offset_rad"]),
                "godot_raw_yaw_rad": float(godot_row["measured_yaw_rad"]),
                "rapier_raw_yaw_rad": float(rapier_row["measured_yaw_rad"]),
                "godot_start_aligned_heading_rad": godot_heading[index],
                "rapier_start_aligned_heading_rad": rapier_heading[index],
                "signed_heading_separation_rad": heading_separation[index],
                "absolute_heading_separation_deg": abs(radians_to_degrees(heading_separation[index])),
                "godot_torso_dx_m": godot_displacement[0],
                "godot_torso_dy_m": godot_displacement[1],
                "godot_torso_dz_m": godot_displacement[2],
                "rapier_torso_dx_m": rapier_displacement[0],
                "rapier_torso_dy_m": rapier_displacement[1],
                "rapier_torso_dz_m": rapier_displacement[2],
                "signed_torso_dx_difference_m": torso_difference[0],
                "signed_torso_dy_difference_m": torso_difference[1],
                "signed_torso_dz_difference_m": torso_difference[2],
                "torso_separation_3d_m": separation_3d,
                "torso_separation_horizontal_xz_m": separation_horizontal,
                "godot_torso_tilt_rad": float(godot_row["torso_tilt_rad"]),
                "rapier_torso_tilt_rad": float(rapier_row["torso_tilt_rad"]),
                "contact_mismatch_count": mismatch_count,
                **contact_columns,
            }
        )

    godot_events = detect_contact_events(godot_rows, "godot_jolt", hz)
    rapier_events = detect_contact_events(rapier_rows, "rapier_parry", hz)
    events = add_nearest_event_relationships(godot_events, rapier_events, hz)
    overall_event_offsets = add_millisecond_fields(event_offset_summary(events), hz)
    foot_summaries: list[dict[str, Any]] = []
    for foot in FOOT_IDS:
        foot_events = [event for event in events if event["foot_id"] == foot]
        foot_summaries.append(
            {
                "foot_id": foot,
                "godot_event_count": contact_count(events, "godot_jolt", foot),
                "rapier_event_count": contact_count(events, "rapier_parry", foot),
                "godot_liftoff_count": sum(
                    1
                    for event in foot_events
                    if event["engine_id"] == "godot_jolt" and event["transition"] == "liftoff"
                ),
                "godot_touchdown_count": sum(
                    1
                    for event in foot_events
                    if event["engine_id"] == "godot_jolt" and event["transition"] == "touchdown"
                ),
                "rapier_liftoff_count": sum(
                    1
                    for event in foot_events
                    if event["engine_id"] == "rapier_parry" and event["transition"] == "liftoff"
                ),
                "rapier_touchdown_count": sum(
                    1
                    for event in foot_events
                    if event["engine_id"] == "rapier_parry" and event["transition"] == "touchdown"
                ),
                "contact_state_mismatch_step_count": per_foot_mismatch[foot],
                "contact_state_mismatch_fraction": per_foot_mismatch[foot] / len(godot_rows),
                "nearest_same_transition_timing": add_millisecond_fields(
                    event_offset_summary(foot_events), hz
                ),
            }
        )

    segment_summaries: list[dict[str, Any]] = []
    for segment in segments:
        first = int(segment["first_step"])
        last = int(segment["last_step"])
        indexes = range(first, last + 1)
        segment_events = [
            event for event in events if first <= int(event["semantic_step"]) <= last
        ]
        segment_contact_mismatches = sum(
            int(per_step[index]["contact_mismatch_count"]) for index in indexes
        )
        incremental_heading = (
            (godot_heading[last] - godot_heading[first])
            - (rapier_heading[last] - rapier_heading[first])
        )
        incremental_torso = vector_sub(
            vector_sub(
                godot_rows[last]["torso_position_world_m"],
                godot_rows[first]["torso_position_world_m"],
            ),
            vector_sub(
                rapier_rows[last]["torso_position_world_m"],
                rapier_rows[first]["torso_position_world_m"],
            ),
        )
        segment_summaries.append(
            {
                "segment_id": segment["segment_id"],
                "first_step": first,
                "last_step": last,
                "row_count": last - first + 1,
                "duration_s": (last - first + 1) / hz,
                "heading_rms_separation_rad": rms([heading_separation[index] for index in indexes]),
                "heading_rms_separation_deg": radians_to_degrees(
                    rms([heading_separation[index] for index in indexes])
                ),
                "heading_end_signed_separation_rad": heading_separation[last],
                "heading_end_signed_separation_deg": radians_to_degrees(heading_separation[last]),
                "heading_incremental_signed_separation_rad": incremental_heading,
                "heading_incremental_signed_separation_deg": radians_to_degrees(incremental_heading),
                "torso_rms_3d_separation_m": rms([torso_separation_3d[index] for index in indexes]),
                "torso_end_3d_separation_m": torso_separation_3d[last],
                "torso_incremental_3d_separation_m": vector_norm(incremental_torso),
                "contact_state_mismatch_count": segment_contact_mismatches,
                "contact_state_sample_count": (last - first + 1) * len(FOOT_IDS),
                "contact_state_mismatch_fraction": segment_contact_mismatches
                / ((last - first + 1) * len(FOOT_IDS)),
                "godot_contact_event_count": contact_count(segment_events, "godot_jolt"),
                "rapier_contact_event_count": contact_count(segment_events, "rapier_parry"),
            }
        )

    terminal_torso = torso_vectors[-1]
    heading_rms = rms(heading_separation)
    overall = {
        "row_count": len(godot_rows),
        "duration_s": len(godot_rows) / hz,
        "heading": {
            "godot_terminal_start_aligned_change_rad": godot_heading[-1],
            "godot_terminal_start_aligned_change_deg": radians_to_degrees(godot_heading[-1]),
            "rapier_terminal_start_aligned_change_rad": rapier_heading[-1],
            "rapier_terminal_start_aligned_change_deg": radians_to_degrees(rapier_heading[-1]),
            "terminal_signed_godot_minus_rapier_rad": heading_separation[-1],
            "terminal_signed_godot_minus_rapier_deg": radians_to_degrees(heading_separation[-1]),
            "root_mean_square_separation_rad": heading_rms,
            "root_mean_square_separation_deg": radians_to_degrees(heading_rms),
            "mean_absolute_separation_rad": mean([abs(value) for value in heading_separation]),
            "mean_absolute_separation_deg": radians_to_degrees(
                mean([abs(value) for value in heading_separation])
            ),
            "maximum_absolute_separation_rad": max(abs(value) for value in heading_separation),
            "maximum_absolute_separation_deg": radians_to_degrees(
                max(abs(value) for value in heading_separation)
            ),
        },
        "torso_reference_point": {
            "terminal_signed_godot_minus_rapier_xyz_m": terminal_torso,
            "terminal_3d_separation_m": torso_separation_3d[-1],
            "root_mean_square_3d_separation_m": rms(torso_separation_3d),
            "root_mean_square_horizontal_xz_separation_m": rms(torso_separation_horizontal),
            "mean_3d_separation_m": mean(torso_separation_3d),
            "maximum_3d_separation_m": max(torso_separation_3d),
            "per_axis_root_mean_square_separation_xyz_m": [
                rms([vector[axis] for vector in torso_vectors]) for axis in range(3)
            ],
        },
        "foot_contacts": {
            "godot_event_count": len(godot_events),
            "rapier_event_count": len(rapier_events),
            "event_count_difference_godot_minus_rapier": len(godot_events) - len(rapier_events),
            "contact_state_mismatch_count": contact_mismatch_samples,
            "contact_state_sample_count": len(godot_rows) * len(FOOT_IDS),
            "contact_state_mismatch_fraction": contact_mismatch_samples
            / (len(godot_rows) * len(FOOT_IDS)),
            "nearest_same_foot_same_transition_timing": overall_event_offsets,
            "nearest_event_pairing_is_one_to_one": False,
            "per_foot": foot_summaries,
        },
        "segments": segment_summaries,
    }
    return overall, per_step, events


def observed_instrumentation(
    trace_identities: Sequence[dict[str, Any]],
    traces: dict[tuple[str, str], list[dict[str, Any]]],
) -> dict[str, Any]:
    godot_fields = set(traces[("godot_jolt", "reference_zero")][0])
    rapier_fields = set(traces[("rapier_parry", "reference_zero")][0])
    rapier_observation = traces[("rapier_parry", "reference_zero")][0].get(
        "actuator_phase_observation", {}
    )
    applications = (
        rapier_observation.get("ordered_applications", [])
        if isinstance(rapier_observation, dict)
        else []
    )
    rapier_application_fields = sorted(applications[0]) if applications else []
    measured_joint_candidates = {
        "ordered_measured_joint_angles_rad",
        "measured_joint_angles_rad",
        "ordered_joint_positions_rad",
        "joint_positions_rad",
    }
    com_candidates = {
        "center_of_mass_world_m",
        "whole_system_center_of_mass_world_m",
        "center_of_mass_position_world_m",
    }
    return {
        "matched_common_top_level_fields": sorted(godot_fields & rapier_fields),
        "godot_top_level_field_count": len(godot_fields),
        "rapier_top_level_field_count": len(rapier_fields),
        "measured_joint_angle_series_field_present_in_godot": bool(
            godot_fields & measured_joint_candidates
        ),
        "measured_joint_angle_series_field_present_in_rapier": bool(
            rapier_fields & measured_joint_candidates
        ),
        "center_of_mass_series_field_present_in_godot": bool(godot_fields & com_candidates),
        "center_of_mass_series_field_present_in_rapier": bool(rapier_fields & com_candidates),
        "torso_position_series_present_in_both": "torso_position_world_m" in godot_fields
        and "torso_position_world_m" in rapier_fields,
        "rapier_actuator_application_fields": rapier_application_fields,
        "rapier_retains_targets_not_measured_joint_angles": (
            "clamped_target_position_rad" in rapier_application_fields
            and not bool(rapier_fields & measured_joint_candidates)
        ),
        "trace_identities": list(trace_identities),
    }


def bool_csv(value: bool) -> str:
    return "true" if value else "false"


def number_csv(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    if isinstance(value, bool):
        return bool_csv(value)
    if isinstance(value, int):
        return str(value)
    return format(float(value), ".17g")


def render_summary_csv(report: dict[str, Any]) -> bytes:
    overall = report["matched_reference_zero"]["overall"]
    heading = overall["heading"]
    torso = overall["torso_reference_point"]
    contacts = overall["foot_contacts"]
    godot = report["trace_summaries"]["godot_jolt/reference_zero"]
    rapier = report["trace_summaries"]["rapier_parry/reference_zero"]
    rows = [
        {
            "metric_id": "joint_angle_rms",
            "availability": "unavailable_not_recorded",
            "plain_english": "RMS difference in measured joint angles at each step",
            "godot_value": "",
            "rapier_value": "",
            "cross_engine_value": "",
            "unit": "radian",
            "caveat": "Neither trace retained per-step measured joint angles; targets are not substituted.",
        },
        {
            "metric_id": "terminal_start_aligned_heading_change",
            "availability": "available",
            "plain_english": "Heading change from the first retained sample to the last",
            "godot_value": number_csv(heading["godot_terminal_start_aligned_change_deg"]),
            "rapier_value": number_csv(heading["rapier_terminal_start_aligned_change_deg"]),
            "cross_engine_value": number_csv(heading["terminal_signed_godot_minus_rapier_deg"]),
            "unit": "degree",
            "caveat": "Positive cross-engine value means Godot ended more positive after start alignment.",
        },
        {
            "metric_id": "heading_rms_separation",
            "availability": "available",
            "plain_english": "Typical heading separation across all 2,992 retained steps",
            "godot_value": "",
            "rapier_value": "",
            "cross_engine_value": number_csv(heading["root_mean_square_separation_deg"]),
            "unit": "degree",
            "caveat": "Descriptive RMS, not an equivalence or pass/fail statistic.",
        },
        {
            "metric_id": "torso_terminal_forward_displacement",
            "availability": "available",
            "plain_english": "Forward X displacement of the tracked torso point",
            "godot_value": number_csv(godot["terminal_start_aligned_torso_displacement_xyz_m"][0]),
            "rapier_value": number_csv(rapier["terminal_start_aligned_torso_displacement_xyz_m"][0]),
            "cross_engine_value": number_csv(torso["terminal_signed_godot_minus_rapier_xyz_m"][0]),
            "unit": "meter",
            "caveat": "Torso reference point, not whole-body center of mass.",
        },
        {
            "metric_id": "torso_terminal_3d_separation",
            "availability": "available_proxy_not_com",
            "plain_english": "Final distance between start-aligned torso reference points",
            "godot_value": "",
            "rapier_value": "",
            "cross_engine_value": number_csv(torso["terminal_3d_separation_m"]),
            "unit": "meter",
            "caveat": "This is deliberately not labeled COM drift.",
        },
        {
            "metric_id": "torso_rms_3d_separation",
            "availability": "available_proxy_not_com",
            "plain_english": "Typical 3D separation between start-aligned torso reference points",
            "godot_value": "",
            "rapier_value": "",
            "cross_engine_value": number_csv(torso["root_mean_square_3d_separation_m"]),
            "unit": "meter",
            "caveat": "This is deliberately not labeled COM drift.",
        },
        {
            "metric_id": "contact_event_count",
            "availability": "available",
            "plain_english": "Total observed lift-offs plus touchdowns",
            "godot_value": str(contacts["godot_event_count"]),
            "rapier_value": str(contacts["rapier_event_count"]),
            "cross_engine_value": str(contacts["event_count_difference_godot_minus_rapier"]),
            "unit": "event",
            "caveat": "Different counts mean ordinal event pairing would be misleading.",
        },
        {
            "metric_id": "contact_state_disagreement",
            "availability": "available",
            "plain_english": "Share of all foot-step samples where contact state differed",
            "godot_value": "",
            "rapier_value": "",
            "cross_engine_value": number_csv(contacts["contact_state_mismatch_fraction"] * 100.0),
            "unit": "percent",
            "caveat": "Exact time-aligned comparison with no warping.",
        },
        {
            "metric_id": "nearest_contact_event_median_distance",
            "availability": "available_with_caveat",
            "plain_english": "Median time to the closest same-foot event of the same kind in the other engine",
            "godot_value": "",
            "rapier_value": "",
            "cross_engine_value": number_csv(
                contacts["nearest_same_foot_same_transition_timing"][
                    "median_absolute_offset_ms"
                ]
            ),
            "unit": "millisecond",
            "caveat": "Nearest events are not asserted to be unique corresponding gait cycles.",
        },
        {
            "metric_id": "center_of_mass_trajectory_drift",
            "availability": "unavailable_not_recorded",
            "plain_english": "Difference in whole-body center-of-mass path",
            "godot_value": "",
            "rapier_value": "",
            "cross_engine_value": "",
            "unit": "meter",
            "caveat": "Neither trace retained a per-step whole-body COM series.",
        },
    ]
    columns = (
        "metric_id",
        "availability",
        "plain_english",
        "godot_value",
        "rapier_value",
        "cross_engine_value",
        "unit",
        "caveat",
    )
    from io import StringIO

    buffer = StringIO(newline="")
    writer = csv.DictWriter(buffer, fieldnames=columns, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return buffer.getvalue().encode("utf-8")


def render_per_step_csv(rows: Sequence[dict[str, Any]]) -> bytes:
    from io import StringIO

    columns = list(rows[0])
    buffer = StringIO(newline="")
    writer = csv.writer(buffer, lineterminator="\n")
    writer.writerow(columns)
    for row in rows:
        writer.writerow([number_csv(row[column]) for column in columns])
    return buffer.getvalue().encode("utf-8")


def render_contact_events_csv(events: Sequence[dict[str, Any]]) -> bytes:
    from io import StringIO

    columns = (
        "event_id",
        "engine_id",
        "foot_id",
        "transition",
        "semantic_step",
        "semantic_time_s",
        "segment_id",
        "nearest_other_event_id",
        "nearest_other_step",
        "signed_godot_minus_rapier_steps",
        "absolute_offset_steps",
        "absolute_offset_ms",
        "mutual_nearest",
    )
    buffer = StringIO(newline="")
    writer = csv.writer(buffer, lineterminator="\n")
    writer.writerow(columns)
    for event in events:
        writer.writerow([number_csv(event.get(column)) for column in columns])
    return buffer.getvalue().encode("utf-8")


def fmt(value: float, digits: int = 3) -> str:
    return f"{value:.{digits}f}"


def render_readme(report: dict[str, Any]) -> bytes:
    matched = report["matched_reference_zero"]
    overall = matched["overall"]
    heading = overall["heading"]
    torso = overall["torso_reference_point"]
    contacts = overall["foot_contacts"]
    summaries = report["trace_summaries"]
    godot = summaries["godot_jolt/reference_zero"]
    rapier = summaries["rapier_parry/reference_zero"]
    nearest = contacts["nearest_same_foot_same_transition_timing"]

    lines: list[str] = [
        "# Retained-trace solver divergence: Godot/Jolt versus Rapier/Parry",
        "",
        "> **Status:** descriptive development artifact; retrospective, outcome-aware, non-authoritative, and not an equivalence, superiority, release, or physics-gate result.",
        "",
        "This report compares the only truly matched cross-engine pair retained by the consumed R23D65 attempt: the `reference_zero` run in Godot/Jolt and Rapier/Parry. Both used seed 23175, the same frozen feedback-policy identity, the same actuator-cap profile, a zero requested heading offset, a 120 Hz outer clock, and 2,992 retained steps (about 24.93 seconds). Because the controller uses live state and contact feedback, the policy is identical but its later per-step commands can diverge after the engines produce different states.",
        "",
        "## The short answer",
        "",
        f"After aligning each engine to its own first retained pose, the final headings were **{fmt(abs(heading['terminal_signed_godot_minus_rapier_deg']), 2)} degrees apart** and the tracked torso points were **{fmt(torso['terminal_3d_separation_m'], 3)} m apart**. Across the full trace, heading separation was {fmt(heading['root_mean_square_separation_deg'], 2)} degrees RMS and torso-point separation was {fmt(torso['root_mean_square_3d_separation_m'], 3)} m RMS. Foot-contact state differed in {fmt(contacts['contact_state_mismatch_fraction'] * 100.0, 2)}% of the {contacts['contact_state_sample_count']:,} time-aligned foot-step samples. This describes a large observed separation in one retained two-engine run; it does not say which engine is more correct and it does not estimate a population.",
        "",
        "| Requested quantity | Honest answer from these traces | What is published |",
        "|---|---|---|",
        "| Per-step joint-angle RMS | **Cannot be computed.** Neither matched trace retained measured angles for all eight joints. | The gap and the exact required successor instrumentation are recorded. Targets and maximum-error scalars are not substituted for measured angles. |",
        f"| Contact-event timing offset | **Can be described, with a correspondence caveat.** Event counts differ ({contacts['godot_event_count']} versus {contacts['rapier_event_count']}). | Every event is published. The median distance to the nearest same-foot event of the same kind was {fmt(nearest['median_absolute_offset_ms'], 1)} ms; no unique gait-cycle pairing is claimed. |",
        f"| Terminal heading error/separation | **Available after removing incompatible host yaw zero-points.** | Godot changed {fmt(heading['godot_terminal_start_aligned_change_deg'], 2)} degrees; Rapier changed {fmt(heading['rapier_terminal_start_aligned_change_deg'], 2)} degrees; signed Godot-minus-Rapier separation was {fmt(heading['terminal_signed_godot_minus_rapier_deg'], 2)} degrees. |",
        "| Center-of-mass trajectory drift | **Cannot be computed.** Neither trace retained whole-body COM at every step. | A separately named torso-reference-point comparison is published. It is not relabeled as COM. |",
        "",
        "## Runtime and comparison identity",
        "",
        "| Item | Godot/Jolt | Rapier/Parry |",
        "|---|---|---|",
        "| Host / library | Godot 4.7 stable; bundled Jolt Physics | Rapier3D 0.34.0; Parry3D 0.29.0 |",
        "| Solver settings retained by the campaign | 20 velocity steps; 7 position steps | 16 solver iterations |",
        "| Host scalar note | Geometry in binary32 `real_t`; portable core in binary64 | Rapier host in `f32`; portable core in binary64 |",
        "| Engine trace | `godot_jolt__s23175__selected_profile__reference_zero` | `rapier_parry__s23175__selected_profile__reference_zero` |",
        "| High-level instruction | Zero desired heading offset | Zero desired heading offset |",
        "| Retained rows | 2,992, contiguous 0 through 2,991 | 2,992, contiguous 0 through 2,991 |",
        "",
        "## Matched reference-run measurements",
        "",
        "| Measurement | Godot/Jolt | Rapier/Parry | Cross-engine reading |",
        "|---|---:|---:|---:|",
        f"| Final heading change from first retained sample | {fmt(heading['godot_terminal_start_aligned_change_deg'], 3)} deg | {fmt(heading['rapier_terminal_start_aligned_change_deg'], 3)} deg | {fmt(heading['terminal_signed_godot_minus_rapier_deg'], 3)} deg signed G-R |",
        f"| Final forward X displacement of torso point | {fmt(godot['terminal_start_aligned_torso_displacement_xyz_m'][0], 4)} m | {fmt(rapier['terminal_start_aligned_torso_displacement_xyz_m'][0], 4)} m | {fmt(torso['terminal_signed_godot_minus_rapier_xyz_m'][0], 4)} m signed G-R |",
        f"| Final lateral Z displacement of torso point | {fmt(godot['terminal_start_aligned_torso_displacement_xyz_m'][2], 4)} m | {fmt(rapier['terminal_start_aligned_torso_displacement_xyz_m'][2], 4)} m | {fmt(torso['terminal_signed_godot_minus_rapier_xyz_m'][2], 4)} m signed G-R |",
        f"| Torso-point path length | {fmt(godot['torso_path_length_m'], 4)} m | {fmt(rapier['torso_path_length_m'], 4)} m | {fmt(godot['torso_path_length_m'] - rapier['torso_path_length_m'], 4)} m signed G-R |",
        f"| Lift-off plus touchdown events | {contacts['godot_event_count']} | {contacts['rapier_event_count']} | {contacts['event_count_difference_godot_minus_rapier']:+d} events G-R |",
        f"| Torso-ground-contact steps | {godot['torso_ground_contact_step_count']} | {rapier['torso_ground_contact_step_count']} | {godot['torso_ground_contact_step_count'] - rapier['torso_ground_contact_step_count']:+d} steps G-R |",
        "",
        "| Cross-engine separation across all 2,992 steps | Value | Lay reading |",
        "|---|---:|---|",
        f"| Heading RMS | {fmt(heading['root_mean_square_separation_deg'], 3)} deg | Typical magnitude of the start-aligned heading gap. |",
        f"| Heading mean absolute | {fmt(heading['mean_absolute_separation_deg'], 3)} deg | Average absolute heading gap. |",
        f"| Heading maximum absolute | {fmt(heading['maximum_absolute_separation_deg'], 3)} deg | Largest single-step heading gap. |",
        f"| Torso-point 3D RMS | {fmt(torso['root_mean_square_3d_separation_m'], 4)} m | Typical distance between the two start-aligned torso points. |",
        f"| Torso-point horizontal RMS | {fmt(torso['root_mean_square_horizontal_xz_separation_m'], 4)} m | Same comparison using forward/lateral axes only. |",
        f"| Torso-point maximum 3D | {fmt(torso['maximum_3d_separation_m'], 4)} m | Largest single-step torso-point gap. |",
        f"| Contact-state disagreement | {contacts['contact_state_mismatch_count']:,} / {contacts['contact_state_sample_count']:,} ({fmt(contacts['contact_state_mismatch_fraction'] * 100.0, 2)}%) | Exact same-step comparison over four feet, with no time warping. |",
        "",
        "## Where separation accumulated",
        "",
        "The historical segment names are retained. On the zero-command reference arm, `commanded_turn` is only the campaign's schedule-window name; the requested heading offset remains zero.",
        "",
        "| Window (steps) | Heading RMS gap | Heading gap at window end | Torso 3D RMS gap | Torso gap at window end | Contact disagreement | Events G / R |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for segment in overall["segments"]:
        lines.append(
            "| "
            + f"{segment['segment_id']} ({segment['first_step']}-{segment['last_step']})"
            + f" | {fmt(segment['heading_rms_separation_deg'], 2)} deg"
            + f" | {fmt(segment['heading_end_signed_separation_deg'], 2)} deg"
            + f" | {fmt(segment['torso_rms_3d_separation_m'], 3)} m"
            + f" | {fmt(segment['torso_end_3d_separation_m'], 3)} m"
            + f" | {fmt(segment['contact_state_mismatch_fraction'] * 100.0, 2)}%"
            + f" | {segment['godot_contact_event_count']} / {segment['rapier_contact_event_count']} |"
        )

    lines.extend(
        [
            "",
            "## Foot-contact detail",
            "",
            "An event is a within-step boolean transition: contact-before differs from contact-after. For each event, the timing-distance statistic finds the nearest event for the same foot and same transition type in the other engine. A counterpart may be reused; this avoids inventing one-to-one correspondence when the engines produce different event counts. The complete event table is in `contact_events.csv`.",
            "",
            "| Foot | Events G / R | Lift-offs G / R | Touchdowns G / R | Contact-state disagreement | Median nearest-event distance | 90th percentile | Maximum |",
            "|---|---:|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for foot in contacts["per_foot"]:
        timing = foot["nearest_same_transition_timing"]
        lines.append(
            f"| {foot['foot_id']}"
            f" | {foot['godot_event_count']} / {foot['rapier_event_count']}"
            f" | {foot['godot_liftoff_count']} / {foot['rapier_liftoff_count']}"
            f" | {foot['godot_touchdown_count']} / {foot['rapier_touchdown_count']}"
            f" | {foot['contact_state_mismatch_step_count']} / 2,992 ({fmt(foot['contact_state_mismatch_fraction'] * 100.0, 2)}%)"
            f" | {fmt(timing['median_absolute_offset_ms'], 1)} ms"
            f" | {fmt(timing['p90_absolute_offset_ms'], 1)} ms"
            f" | {fmt(timing['maximum_absolute_offset_ms'], 1)} ms |"
        )

    lines.extend(
        [
            "",
            "## The other two retained Godot traces are context, not cross-engine pairs",
            "",
            "R23D65 retained positive- and negative-heading Godot traces but never opened their Rapier counterparts. They show the within-Godot scale and asymmetry of this particular run; comparing either one directly with Rapier's zero-command trace would mix solver difference with a different instruction.",
            "",
            "| Godot arm | Requested offset during steps 600-1799 | Boundary-to-boundary heading change (600 to 1800) | Final heading change | Final forward torso displacement | Torso path length | Contact events |",
            "|---|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for key in (
        "godot_jolt/reference_zero",
        "godot_jolt/positive_heading",
        "godot_jolt/negative_heading",
    ):
        summary = summaries[key]
        lines.append(
            f"| {summary['arm_id']}"
            f" | {fmt(summary['desired_turn_window_heading_offset_deg'], 2)} deg"
            f" | {fmt(summary['turn_window_boundary_to_boundary_heading_change_deg'], 2)} deg"
            f" | {fmt(summary['terminal_start_aligned_heading_change_deg'], 2)} deg"
            f" | {fmt(summary['terminal_start_aligned_torso_displacement_xyz_m'][0], 3)} m"
            f" | {fmt(summary['torso_path_length_m'], 3)} m"
            f" | {summary['contact_event_count']} |"
        )

    population = report["input_integrity"]["retained_population"]
    lines.extend(
        [
            "",
            "## What engine maintainers should take from this",
            "",
            "The two engines did not merely differ at the final pass/fail boundary. Under the same frozen closed-loop policy and zero heading request, their contact sequences, feedback-driven phase histories, forward progress, and heading paths separated materially. The largest numerical difference here is dominated by forward torso displacement, while heading and contact timing also diverge. This artifact does **not** isolate a single cause: host coordinate conventions, contact generation, constraint solving, motor-cap mapping, binary32 rounding, and the controller's response to earlier state differences all remain coupled.",
            "",
            "The most useful next instrumentation change is straightforward: every engine trace should retain ordered measured joint angles and a mass-weighted whole-system COM vector at every semantic step, with stable IDs, frame definitions, validity, and wrapped/unwrapped angle semantics. A fresh three-engine matched campaign, not a rerun of consumed R23D65, would then support the four originally requested measurements. Formal equivalence would still require prospective engineering margins and an explicit statistical decision contract.",
            "",
            "## Provenance and limits",
            "",
            f"- Retained source campaign: `{report['source_campaign']['campaign_id']}` at `{report['source_campaign']['source_commit']}`.",
            f"- Retained population verified byte-for-byte: {population['file_count']} files, {population['byte_count']:,} bytes, manifest `{population['canonical_manifest_sha256']}`.",
            f"- Analysis compiler source: `{report['compiler']['source_commit']}`; compiler digest `{report['compiler']['sha256']}`.",
            "- R23D65 remains consumed and invalid/incomplete. This report does not repair its trace-retention/supervisor failures, run its historical evaluator, or create an official physical result.",
            "- MuJoCo is absent because the attempt stopped before any MuJoCo world opened. Therefore this is a two-engine reference description, not the requested complete three-solver answer.",
            "- The sample unit is one retained campaign seed and one matched zero-command arm. Values are exact descriptions of those rows, with no population extrapolation.",
            "- `per_step_reference_zero.csv` carries every matched row-derived value; `contact_events.csv` carries every transition and nearest-event annotation; `report.json` carries all definitions, inputs, and results.",
            "",
        ]
    )
    return ("\n".join(lines)).encode("utf-8")


def build_report(
    contract: dict[str, Any],
    repository: dict[str, Any],
    closure_identity: dict[str, Any],
    population: dict[str, Any],
    runtime_provenance: dict[str, Any],
    trace_identities: list[dict[str, Any]],
    traces: dict[tuple[str, str], list[dict[str, Any]]],
    compiler_identity: dict[str, Any],
) -> tuple[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]]]:
    campaign = contract["source_campaign"]
    hz = int(campaign["outer_control_step_hz"])
    segments = contract["matched_comparison"]["segments"]
    overall, per_step, events = matched_analysis(
        traces[("godot_jolt", "reference_zero")],
        traces[("rapier_parry", "reference_zero")],
        segments,
        hz,
    )
    summaries: dict[str, Any] = {}
    specs = {
        (item["engine_id"], item["arm_id"]): item for item in contract["trace_sources"]
    }
    for engine_id, arm_id in (
        ("godot_jolt", "reference_zero"),
        ("rapier_parry", "reference_zero"),
        ("godot_jolt", "positive_heading"),
        ("godot_jolt", "negative_heading"),
    ):
        spec = specs[(engine_id, arm_id)]
        summaries[f"{engine_id}/{arm_id}"] = trace_summary(
            traces[(engine_id, arm_id)],
            engine_id,
            arm_id,
            float(spec["desired_heading_offset_rad"]),
            hz,
        )

    instrumentation = observed_instrumentation(trace_identities, traces)
    require(
        instrumentation["measured_joint_angle_series_field_present_in_godot"] is False
        and instrumentation["measured_joint_angle_series_field_present_in_rapier"] is False,
        "JOINT_INSTRUMENTATION_CONTRACT_STALE",
        repr(instrumentation),
    )
    require(
        instrumentation["center_of_mass_series_field_present_in_godot"] is False
        and instrumentation["center_of_mass_series_field_present_in_rapier"] is False,
        "COM_INSTRUMENTATION_CONTRACT_STALE",
        repr(instrumentation),
    )

    report = {
        "schema_version": REPORT_SCHEMA,
        "analysis_id": contract["analysis_id"],
        "status": "complete_descriptive_development_artifact",
        "ledger_scope": contract["ledger_scope"],
        "authority_classification": contract["authority_classification"],
        "source_campaign": campaign,
        "repository": repository,
        "compiler": compiler_identity,
        "input_integrity": {
            "closure": closure_identity,
            "retained_population": population,
            "runtime_provenance": runtime_provenance,
            "trace_sources": trace_identities,
            "all_bound_inputs_match": True,
        },
        "runtime_identity": contract["runtime_identity"],
        "matched_reference_zero": {
            "comparison_contract": contract["matched_comparison"],
            "metric_contract": contract["metric_contract"],
            "overall": overall,
        },
        "trace_summaries": summaries,
        "requested_measurement_availability": contract[
            "requested_measurement_availability"
        ],
        "observed_instrumentation": instrumentation,
        "instrumentation_successor_requirements": contract[
            "instrumentation_successor_requirements"
        ],
        "execution": {
            "retained_input_file_count_hashed": population["file_count"],
            "retained_trace_count_parsed": 4,
            "retained_trace_row_count_total": sum(len(rows) for rows in traces.values()),
            "matched_step_comparison_count": len(per_step),
            "contact_event_observation_count": len(events),
            "model_construction_count": 0,
            "physics_world_build_count": 0,
            "solver_step_count": 0,
            "native_read_count": 0,
            "historical_evaluator_invocation_count": 0,
            "physical_outcome_reinterpreted": False,
        },
        "claim_boundary": contract["claim_boundary"],
    }
    return report, per_step, events


def write_bundle(
    output_dir: Path,
    report: dict[str, Any],
    per_step: list[dict[str, Any]],
    events: list[dict[str, Any]],
) -> dict[str, Any]:
    require(not output_dir.exists(), "OUTPUT_ALREADY_EXISTS", str(output_dir))
    parent = output_dir.parent
    require(parent.is_dir(), "OUTPUT_PARENT_MISSING", str(parent))
    staging = Path(
        tempfile.mkdtemp(prefix=f".{output_dir.name}.staging-", dir=str(parent))
    )
    try:
        payloads = {
            "README.md": render_readme(report),
            "report.json": canonical_json_bytes(report),
            "summary.csv": render_summary_csv(report),
            "per_step_reference_zero.csv": render_per_step_csv(per_step),
            "contact_events.csv": render_contact_events_csv(events),
        }
        for name in OUTPUT_FILES:
            write_bytes(staging / name, payloads[name])
        records = []
        for name in OUTPUT_FILES:
            identity = artifact_identity(staging / name)
            records.append(
                {
                    "relative_path": name,
                    "byte_length": identity["byte_length"],
                    "sha256": identity["sha256"],
                }
            )
        manifest_text = "".join(
            f"{item['relative_path']}\t{item['byte_length']}\t{item['sha256']}\n"
            for item in records
        )
        write_bytes(staging / "bundle-manifest.tsv", manifest_text.encode("utf-8"))
        os.replace(staging, output_dir)
    except Exception:
        if staging.exists():
            shutil.rmtree(staging)
        raise

    all_records = []
    for path in sorted(output_dir.iterdir(), key=lambda item: item.name):
        identity = artifact_identity(path)
        all_records.append(
            {
                "relative_path": path.name,
                "byte_length": identity["byte_length"],
                "sha256": identity["sha256"],
            }
        )
    manifest_identity = artifact_identity(output_dir / "bundle-manifest.tsv")
    return {
        "output_dir": str(output_dir),
        "file_count": len(all_records),
        "byte_count": sum(item["byte_length"] for item in all_records),
        "bundle_manifest": manifest_identity,
        "files": all_records,
    }


def ensure_output_outside_repo(repo_root: Path, output_dir: Path) -> None:
    resolved_repo = repo_root.resolve()
    resolved_output = output_dir.resolve()
    require(
        resolved_output != resolved_repo and resolved_repo not in resolved_output.parents,
        "OUTPUT_INSIDE_REPOSITORY",
        str(resolved_output),
    )


def self_test() -> dict[str, Any]:
    checks = 0

    angles = [3.13, -3.13, -3.00]
    rows = [{"measured_yaw_rad": value} for value in angles]
    unwrapped = unwrap_angles(rows)
    require(unwrapped[1] > unwrapped[0], "SELF_TEST_UNWRAP_FAILED", repr(unwrapped))
    checks += 1

    require(quantile([0.0, 10.0], 0.9) == 9.0, "SELF_TEST_QUANTILE_FAILED", "p90")
    checks += 1

    synthetic_godot = [
        {
            "semantic_step": index,
            "segment_id": "synthetic",
            "ordered_foot_contacts_before": {
                foot: not (foot == "front_left" and index > 0) for foot in FOOT_IDS
            },
            "ordered_foot_contacts_after": {
                foot: not (foot == "front_left" and index >= 0) for foot in FOOT_IDS
            },
        }
        for index in range(1)
    ]
    synthetic_rapier = [
        {
            "semantic_step": 2,
            "segment_id": "synthetic",
            "ordered_foot_contacts_before": {foot: True for foot in FOOT_IDS},
            "ordered_foot_contacts_after": {
                foot: False if foot == "front_left" else True for foot in FOOT_IDS
            },
        }
    ]
    godot_events = detect_contact_events(synthetic_godot, "godot_jolt", 120)
    rapier_events = detect_contact_events(synthetic_rapier, "rapier_parry", 120)
    enriched = add_nearest_event_relationships(godot_events, rapier_events, 120)
    require(
        len(enriched) == 2
        and enriched[0]["absolute_offset_steps"] == 2
        and enriched[1]["absolute_offset_steps"] == 2,
        "SELF_TEST_EVENT_NEAREST_FAILED",
        repr(enriched),
    )
    checks += 1

    sample_contract = {
        "schema_version": EXPECTED_CONTRACT_SCHEMA,
        "status": "frozen_retrospective_descriptive_development_analysis",
        "ledger_scope": {"question_class": "development"},
        "authority_classification": {
            "outcome_aware": True,
            "prospective": False,
            "descriptive_only": True,
            "non_authoritative": True,
            "threshold_bearing": False,
            "selection_bearing": False,
            "equivalence_or_non_inferiority_test": False,
            "superiority_test": False,
            "population_inference": False,
            "gate_advancement": False,
            "historical_campaign_reinterpretation": False,
        },
        "trace_sources": [
            {"engine_id": "godot_jolt", "arm_id": "reference_zero", "comparison_role": "matched_cross_engine_reference"},
            {"engine_id": "rapier_parry", "arm_id": "reference_zero", "comparison_role": "matched_cross_engine_reference"},
            {"engine_id": "godot_jolt", "arm_id": "positive_heading", "comparison_role": "within_godot_command_context_only"},
            {"engine_id": "godot_jolt", "arm_id": "negative_heading", "comparison_role": "within_godot_command_context_only"},
        ],
        "requested_measurement_availability": [
            {"requested_measurement": "per-step joint-angle RMS between engines", "status": "unavailable_not_recorded", "substitution_permitted": False},
            {"requested_measurement": "contact-event timing offset", "status": "available", "substitution_permitted": True},
            {"requested_measurement": "terminal heading error", "status": "available", "substitution_permitted": True},
            {"requested_measurement": "center-of-mass trajectory drift", "status": "unavailable_not_recorded", "substitution_permitted": False},
        ],
        "claim_boundary": {"cross_engine_equivalence_claimed": False},
        "output_contract": {
            "files": [
                {"path": name} for name in (*OUTPUT_FILES, "bundle-manifest.tsv")
            ]
        },
    }
    validate_contract(sample_contract)
    checks += 1

    per_step_csv = render_per_step_csv(
        [
            {
                "semantic_step": 0,
                "segment_id": "synthetic",
                "contact": True,
                "value": 0.25,
            }
        ]
    ).decode("utf-8")
    require(
        "0,synthetic,true,0.25\n" in per_step_csv,
        "SELF_TEST_PER_STEP_CSV_FAILED",
        per_step_csv,
    )
    checks += 1

    contact_csv = render_contact_events_csv(
        [
            {
                "event_id": "godot_jolt:front_left:liftoff:0",
                "engine_id": "godot_jolt",
                "foot_id": "front_left",
                "transition": "liftoff",
                "semantic_step": 0,
                "semantic_time_s": 0.0,
                "segment_id": "synthetic",
                "nearest_other_event_id": None,
                "nearest_other_step": None,
                "signed_godot_minus_rapier_steps": None,
                "absolute_offset_steps": None,
                "absolute_offset_ms": None,
                "mutual_nearest": False,
            }
        ]
    ).decode("utf-8")
    require(
        "godot_jolt:front_left:liftoff:0,godot_jolt,front_left,liftoff,0,0,synthetic" in contact_csv,
        "SELF_TEST_CONTACT_CSV_FAILED",
        contact_csv,
    )
    checks += 1

    mutated = json.loads(json.dumps(sample_contract))
    mutated["claim_boundary"]["cross_engine_equivalence_claimed"] = True
    refused = False
    try:
        validate_contract(mutated)
    except AnalysisError as exc:
        refused = str(exc).startswith("FALSE_CLAIM_PROMOTED")
    require(refused, "SELF_TEST_CLAIM_MUTATION_NOT_REFUSED", "equivalence")
    checks += 1

    with tempfile.TemporaryDirectory(prefix="sporespore-r23d65-divergence-self-test-") as temporary:
        root = Path(temporary)
        (root / "b.txt").write_bytes(b"b")
        (root / "a.txt").write_bytes(b"a")
        manifest, records = canonical_population_manifest(root)
        expected = (
            f"a.txt\t1\t{sha256_bytes(b'a')}\n"
            f"b.txt\t1\t{sha256_bytes(b'b')}\n"
        ).encode("utf-8")
        require(manifest == expected and len(records) == 2, "SELF_TEST_MANIFEST_FAILED", repr(records))
    checks += 1

    return {
        "schema_version": "sporespore_r23d65_retained_trace_descriptive_divergence_self_test_v1",
        "ok": True,
        "check_count": checks,
        "model_construction_count": 0,
        "physics_world_build_count": 0,
        "solver_step_count": 0,
        "native_read_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--repo-root", type=Path)
    parser.add_argument("--contract", type=Path)
    parser.add_argument("--attempt-root", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--source-commit")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        if args.self_test:
            print(json.dumps(self_test(), sort_keys=True, separators=(",", ":")))
            return 0
        for name in ("repo_root", "contract", "attempt_root", "output_dir", "source_commit"):
            require(getattr(args, name) is not None, "REQUIRED_ARGUMENT_MISSING", name)
        repo_root = args.repo_root.resolve()
        contract_path = args.contract.resolve()
        attempt_root = args.attempt_root.resolve()
        output_dir = args.output_dir.resolve()
        ensure_output_outside_repo(repo_root, output_dir)
        repository = validate_repository(repo_root, args.source_commit)
        require(
            contract_path == (repo_root / "sdk/turning/r23d65_retained_trace_descriptive_divergence_contract_v1.json").resolve(),
            "CONTRACT_PATH_INVALID",
            str(contract_path),
        )
        contract = read_json(contract_path)
        require(isinstance(contract, dict), "CONTRACT_NOT_OBJECT", str(contract_path))
        validate_contract(contract)
        closure_identity, population = validate_closure_and_population(
            repo_root, attempt_root, contract
        )
        runtime_provenance = validate_runtime_provenance(
            repo_root, attempt_root, contract
        )
        traces: dict[tuple[str, str], list[dict[str, Any]]] = {}
        trace_identities: list[dict[str, Any]] = []
        segments = contract["matched_comparison"]["segments"]
        campaign = contract["source_campaign"]
        for spec in contract["trace_sources"]:
            rows, identity = load_and_validate_trace(
                attempt_root, spec, segments, campaign
            )
            traces[(spec["engine_id"], spec["arm_id"])] = rows
            trace_identities.append(identity)
        compiler_identity = artifact_identity(Path(__file__).resolve())
        compiler_identity["source_commit"] = args.source_commit
        compiler_identity["contract_path"] = str(contract_path)
        compiler_identity["contract_sha256"] = sha256_file(contract_path)
        report, per_step, events = build_report(
            contract,
            repository,
            closure_identity,
            population,
            runtime_provenance,
            trace_identities,
            traces,
            compiler_identity,
        )
        bundle = write_bundle(output_dir, report, per_step, events)
        print(
            json.dumps(
                {
                    "schema_version": "sporespore_r23d65_retained_trace_descriptive_divergence_compiler_receipt_v1",
                    "ok": True,
                    "analysis_id": contract["analysis_id"],
                    "source_commit": args.source_commit,
                    "output_bundle": bundle,
                    "model_construction_count": 0,
                    "physics_world_build_count": 0,
                    "solver_step_count": 0,
                    "native_read_count": 0,
                    "physical_acceptance_authority": False,
                    "release_authority": False,
                },
                sort_keys=True,
                separators=(",", ":"),
            )
        )
        return 0
    except AnalysisError as exc:
        print(
            json.dumps(
                {
                    "schema_version": "sporespore_r23d65_retained_trace_descriptive_divergence_compiler_failure_v1",
                    "ok": False,
                    "failure": str(exc),
                    "model_construction_count": 0,
                    "physics_world_build_count": 0,
                    "solver_step_count": 0,
                    "native_read_count": 0,
                    "physical_acceptance_authority": False,
                    "release_authority": False,
                },
                sort_keys=True,
                separators=(",", ":"),
            ),
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
