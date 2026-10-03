#!/usr/bin/env python3
"""Reusable compact qualification for deterministic Godot zero-world workers.

Campaign bindings provide only a declarative contract.  This module owns the
shared source/runtime/predecessor binding, worker execution, zero-authority
checks, compact receipt construction, and content-addressed closure audit.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import subprocess
import sys
from typing import Any

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    canonical_bytes,
    exact,
    frozen_manifest,
    git,
    load,
    require,
    sha256,
    source_bytes,
)
from sdk.conformance.godot_recovery_route_zero_world_controls import (
    ControlError,
    require_fields,
    require_zero_authority,
    run_godot_worker,
)


def _utc_now() -> str:
    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


def _file_identity(path: Path) -> dict[str, Any]:
    value = path.read_bytes()
    return {
        "path": path.as_posix(),
        "raw_sha256": sha256(value),
        "byte_length": len(value),
    }


def _relative_identity(root: Path, relative: str) -> dict[str, Any]:
    value = (root / relative).read_bytes()
    return {
        "path": relative,
        "raw_sha256": sha256(value),
        "byte_length": len(value),
    }


def _require_bound_file(root: Path, binding: dict[str, Any], label: str) -> None:
    exact(
        _relative_identity(root, str(binding["path"])),
        {
            "path": binding["path"],
            "raw_sha256": binding["raw_sha256"],
            "byte_length": binding["byte_length"],
        },
        label,
    )


def _require_runtime(contract: dict[str, Any]) -> dict[str, Any]:
    expected = contract["exact_runtime"]
    path = Path(str(expected["console_path"]))
    require(path.is_file(), "RUNTIME_MISSING")
    identity = _file_identity(path)
    exact(identity["raw_sha256"], expected["console_sha256"], "RUNTIME_SHA256")
    exact(identity["byte_length"], expected["console_byte_length"], "RUNTIME_LENGTH")
    receipt = {
        **identity,
        "runtime_profile_id": expected["runtime_profile_id"],
        "runtime_version": expected["runtime_version"],
    }
    engine_path_value = expected.get("engine_path")
    if engine_path_value is not None:
        require(
            "engine_sha256" in expected and "engine_byte_length" in expected,
            "RUNTIME_ENGINE_IDENTITY_INCOMPLETE",
        )
        engine_path = Path(str(engine_path_value))
        require(engine_path.is_file(), "RUNTIME_ENGINE_MISSING")
        engine_identity = _file_identity(engine_path)
        exact(
            engine_identity["raw_sha256"],
            expected["engine_sha256"],
            "RUNTIME_ENGINE_SHA256",
        )
        exact(
            engine_identity["byte_length"],
            expected["engine_byte_length"],
            "RUNTIME_ENGINE_LENGTH",
        )
        receipt["engine_binary"] = engine_identity
        receipt["binary_pair_complete"] = True
    return receipt


def _require_retained_build_artifacts(
    contract: dict[str, Any],
) -> list[dict[str, Any]]:
    """Bind exact durable cold-build outputs without rerunning the build.

    The optional declaration is shared campaign machinery: binaries and logs
    are content-addressed, and text logs may carry a minimal completion marker.
    This proves which completed build was retained; it does not promote the
    build or any later worker to physical evidence.
    """

    retained: list[dict[str, Any]] = []
    for specification in contract.get("retained_build_artifacts", []):
        path = Path(str(specification["path"])).resolve()
        require(path.is_file(), f"RETAINED_BUILD_ARTIFACT_MISSING:{specification['id']}")
        identity = _file_identity(path)
        exact(
            identity["raw_sha256"],
            specification["raw_sha256"],
            f"RETAINED_BUILD_ARTIFACT_SHA256:{specification['id']}",
        )
        exact(
            identity["byte_length"],
            specification["byte_length"],
            f"RETAINED_BUILD_ARTIFACT_LENGTH:{specification['id']}",
        )
        required_text = list(specification.get("required_utf8_substrings", []))
        forbidden_text = list(specification.get("forbidden_utf8_substrings", []))
        if required_text or forbidden_text:
            text = path.read_text(encoding="utf-8", errors="strict")
            for expected in required_text:
                require(
                    str(expected) in text,
                    f"RETAINED_BUILD_ARTIFACT_REQUIRED_TEXT:{specification['id']}",
                )
            for forbidden in forbidden_text:
                require(
                    str(forbidden) not in text,
                    f"RETAINED_BUILD_ARTIFACT_FORBIDDEN_TEXT:{specification['id']}",
                )
        retained.append(
            {
                "id": specification["id"],
                "role": specification["role"],
                **identity,
                "required_utf8_substrings": required_text,
                "forbidden_utf8_substrings": forbidden_text,
            }
        )
    return retained


def _require_source_text_controls(
    root: Path,
    contract: dict[str, Any],
    source_commit: str,
    *,
    observed_checkout: bool,
) -> list[dict[str, Any]]:
    """Apply compact declarative source-shape controls without bespoke auditors."""

    retained: list[dict[str, Any]] = []
    inventory = set(str(path) for path in contract["source_inventory"])
    for specification in contract.get("source_text_controls", []):
        relative = str(specification["path"])
        require(relative in inventory, f"SOURCE_TEXT_NOT_IN_INVENTORY:{relative}")
        raw = (
            (root / relative).read_bytes()
            if observed_checkout
            else source_bytes(root, source_commit, relative)
        )
        text = raw.decode("utf-8", errors="strict")
        required = [str(value) for value in specification.get("required", [])]
        forbidden = [str(value) for value in specification.get("forbidden", [])]
        exact_counts = {
            str(value): int(count)
            for value, count in specification.get("exact_counts", {}).items()
        }
        for value in required:
            require(value in text, f"SOURCE_TEXT_REQUIRED:{relative}:{value}")
        for value in forbidden:
            require(value not in text, f"SOURCE_TEXT_FORBIDDEN:{relative}:{value}")
        for value, count in exact_counts.items():
            exact(text.count(value), count, f"SOURCE_TEXT_COUNT:{relative}:{value}")
        retained.append(
            {
                "id": str(specification["id"]),
                "path": relative,
                "raw_sha256": sha256(raw),
                "byte_length": len(raw),
                "required": required,
                "forbidden": forbidden,
                "exact_counts": exact_counts,
            }
        )
    return retained


def _run_checked(
    command: list[str],
    root: Path,
    label: str,
) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        command,
        cwd=root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
        check=False,
    )
    require(
        completed.returncode == 0,
        f"{label}_FAILED:{completed.returncode}:{completed.stdout}:{completed.stderr}",
    )
    return completed


def _require_exact_external_source(
    root: Path,
    contract: dict[str, Any],
) -> dict[str, Any] | None:
    """Bind one exact dirty dependency checkout without making it permanent state.

    This optional shared control is for source-built runtimes whose upstream
    checkout is intentionally modified by repository-owned patches. The live
    checkout is required only while qualifying. Its complete diff identity,
    changed-path population, selected final source blobs, and patch chain are
    retained so later closure audits do not depend on that mutable checkout.
    """

    specification = contract.get("exact_external_source")
    if specification is None:
        return None

    checkout = Path(str(specification["checkout_path"])).resolve()
    require(checkout.is_dir(), "EXTERNAL_SOURCE_ROOT_MISSING")
    exact(
        checkout.as_posix(),
        Path(str(specification["checkout_path"])).resolve().as_posix(),
        "EXTERNAL_SOURCE_ROOT",
    )
    head = _run_checked(
        ["git", "rev-parse", "HEAD"], checkout, "EXTERNAL_SOURCE_HEAD"
    ).stdout.strip()
    origin = _run_checked(
        ["git", "remote", "get-url", "origin"],
        checkout,
        "EXTERNAL_SOURCE_ORIGIN",
    ).stdout.strip()
    exact(head, specification["upstream_commit"], "EXTERNAL_SOURCE_UPSTREAM")
    exact(origin, specification["origin_url"], "EXTERNAL_SOURCE_ORIGIN")

    diff = subprocess.run(
        ["git", "diff", "--binary", "--full-index", "--no-ext-diff"],
        cwd=checkout,
        capture_output=True,
        check=True,
    ).stdout
    exact(len(diff), specification["diff_byte_length"], "EXTERNAL_SOURCE_DIFF_LENGTH")
    exact(sha256(diff), specification["diff_raw_sha256"], "EXTERNAL_SOURCE_DIFF_HASH")
    names = _run_checked(
        ["git", "diff", "--name-only", "--no-ext-diff"],
        checkout,
        "EXTERNAL_SOURCE_NAMES",
    ).stdout.splitlines()
    exact(names, specification["changed_paths"], "EXTERNAL_SOURCE_CHANGED_PATHS")
    _run_checked(["git", "diff", "--check"], checkout, "EXTERNAL_SOURCE_DIFF_CHECK")

    patches: list[dict[str, Any]] = []
    for binding in specification["bound_patches"]:
        _require_bound_file(root, binding, "EXTERNAL_SOURCE_PATCH")
        patches.append(_relative_identity(root, str(binding["path"])))

    source_files: list[dict[str, Any]] = []
    for binding in specification["source_files"]:
        relative = str(binding["path"])
        path = checkout / relative
        require(path.is_file(), f"EXTERNAL_SOURCE_FILE_MISSING:{relative}")
        raw = path.read_bytes()
        observed = {
            "path": relative,
            "raw_sha256": sha256(raw),
            "byte_length": len(raw),
            "git_blob_oid": _run_checked(
                ["git", "hash-object", "--", relative],
                checkout,
                "EXTERNAL_SOURCE_BLOB",
            ).stdout.strip(),
        }
        exact(observed, binding, f"EXTERNAL_SOURCE_FILE:{relative}")
        source_files.append(observed)

    reverse_apply_patches: list[str] = []
    for relative in specification["reverse_apply_patch_paths"]:
        patch_path = (root / str(relative)).resolve()
        require(patch_path.is_relative_to(root.resolve()), "EXTERNAL_PATCH_PATH_ESCAPE")
        _run_checked(
            [
                "git",
                "apply",
                "--reverse",
                "--check",
                "--whitespace=error-all",
                "--",
                str(patch_path),
            ],
            checkout,
            "EXTERNAL_SOURCE_REVERSE_APPLY",
        )
        reverse_apply_patches.append(str(relative))

    for link in specification["patch_blob_chain"]:
        patch_text = (root / str(link["patch_path"])).read_text(encoding="utf-8")
        exact(
            patch_text.count(str(link["index_line"])),
            1,
            "EXTERNAL_SOURCE_PATCH_INDEX",
        )
        final_blob = _run_checked(
            ["git", "hash-object", "--", str(link["final_source_path"])],
            checkout,
            "EXTERNAL_SOURCE_FINAL_BLOB",
        ).stdout.strip()
        exact(final_blob, link["final_blob_oid"], "EXTERNAL_SOURCE_FINAL_BLOB")

    receipt = {
        "schema_version": "sporespore_compact_exact_external_source_receipt_v1",
        "checkout_path": checkout.as_posix(),
        "upstream_commit": head,
        "origin_url": origin,
        "diff_raw_sha256": sha256(diff),
        "diff_byte_length": len(diff),
        "changed_paths": names,
        "bound_patches": patches,
        "source_files": source_files,
        "reverse_apply_patch_paths": reverse_apply_patches,
        "patch_blob_chain": specification["patch_blob_chain"],
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    receipt["mutation_rejection_count"] = specification[
        "expected_mutation_rejection_count"
    ]
    _verify_exact_external_source_receipt(root, contract, receipt)

    mutations: list[dict[str, Any]] = []
    for _ in range(7):
        mutations.append(json.loads(json.dumps(contract)))
    mutations[0]["exact_external_source"]["upstream_commit"] = "0" * 40
    mutations[1]["exact_external_source"]["diff_raw_sha256"] = "sha256:" + "0" * 64
    mutations[2]["exact_external_source"]["diff_byte_length"] += 1
    mutations[3]["exact_external_source"]["changed_paths"] = list(reversed(names))
    mutations[4]["exact_external_source"]["source_files"][0]["git_blob_oid"] = "0" * 40
    mutations[5]["exact_external_source"]["bound_patches"][-1]["raw_sha256"] = (
        "sha256:" + "0" * 64
    )
    mutations[6]["exact_external_source"]["patch_blob_chain"][0][
        "final_blob_oid"
    ] = "0" * 40
    rejected = 0
    for mutated in mutations:
        try:
            _verify_exact_external_source_receipt(root, mutated, receipt)
        except ClosureAuditError:
            rejected += 1
    exact(
        rejected,
        specification["expected_mutation_rejection_count"],
        "EXTERNAL_SOURCE_MUTATION_CONTROLS",
    )
    receipt["mutation_rejection_count"] = rejected
    return receipt


def _verify_exact_external_source_receipt(
    root: Path,
    contract: dict[str, Any],
    receipt: dict[str, Any],
) -> None:
    """Audit a frozen external-source receipt without consulting live source."""

    specification = contract["exact_external_source"]
    exact(
        receipt.get("schema_version"),
        "sporespore_compact_exact_external_source_receipt_v1",
        "CLOSURE_EXTERNAL_SOURCE_SCHEMA",
    )
    for key in (
        "checkout_path",
        "upstream_commit",
        "origin_url",
        "diff_raw_sha256",
        "diff_byte_length",
        "changed_paths",
        "source_files",
        "reverse_apply_patch_paths",
        "patch_blob_chain",
    ):
        exact(receipt.get(key), specification[key], f"CLOSURE_EXTERNAL_SOURCE:{key}")
    exact(
        receipt.get("mutation_rejection_count"),
        specification["expected_mutation_rejection_count"],
        "CLOSURE_EXTERNAL_SOURCE_MUTATION_CONTROLS",
    )
    expected_patches: list[dict[str, Any]] = []
    for binding in specification["bound_patches"]:
        _require_bound_file(root, binding, "CLOSURE_EXTERNAL_SOURCE_PATCH")
        expected_patches.append(_relative_identity(root, str(binding["path"])))
    exact(
        receipt.get("bound_patches"),
        expected_patches,
        "CLOSURE_EXTERNAL_SOURCE_PATCHES",
    )
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(receipt.get(key), 0, f"CLOSURE_EXTERNAL_SOURCE_ZERO:{key}")
    for key in ("physical_acceptance_authority", "release_authority"):
        exact(receipt.get(key), False, f"CLOSURE_EXTERNAL_SOURCE_AUTHORITY:{key}")


def _run_host_extension_build(
    root: Path,
    contract: dict[str, Any],
) -> dict[str, Any] | None:
    """Build and hash the exact host extension used by a Godot worker.

    The binding is optional for historical compact contracts. New contracts
    can make stale local extension binaries impossible without growing a new
    campaign-specific build audit.
    """
    specification = contract.get("host_extension_build")
    if specification is None:
        return None
    workspace_manifest = root / str(specification["workspace_manifest"])
    focused_test_manifest = root / str(specification["focused_test_manifest"])
    artifact = root / str(specification["artifact_path"])
    require(workspace_manifest.is_file(), "HOST_BUILD_WORKSPACE_MANIFEST")
    require(focused_test_manifest.is_file(), "HOST_BUILD_TEST_MANIFEST")
    test_command = [
        "cargo",
        "test",
        "--locked",
        "--manifest-path",
        str(focused_test_manifest),
        str(specification["focused_test_filter"]),
        "--lib",
    ]
    test = _run_checked(test_command, root, "HOST_FOCUSED_TEST")
    build_command = [
        "cargo",
        "build",
        "--locked",
        "--manifest-path",
        str(workspace_manifest),
        "-p",
        str(specification["package"]),
    ]
    build = _run_checked(build_command, root, "HOST_EXTENSION_BUILD")
    require(artifact.is_file(), "HOST_EXTENSION_ARTIFACT_MISSING")
    artifact_identity = _relative_identity(root, str(specification["artifact_path"]))
    return {
        "schema_version": "sporespore_compact_godot_host_extension_build_receipt_v1",
        "workspace_manifest": specification["workspace_manifest"],
        "focused_test_manifest": specification["focused_test_manifest"],
        "focused_test_filter": specification["focused_test_filter"],
        "package": specification["package"],
        "artifact": artifact_identity,
        "test_command": test_command,
        "test_stdout_sha256": sha256(test.stdout.encode("utf-8")),
        "test_stderr_sha256": sha256(test.stderr.encode("utf-8")),
        "build_command": build_command,
        "build_stdout_sha256": sha256(build.stdout.encode("utf-8")),
        "build_stderr_sha256": sha256(build.stderr.encode("utf-8")),
        "source_build_executed": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _qualification_toolchain() -> dict[str, Any]:
    python_identity = _file_identity(Path(sys.executable))
    return {
        "python": {
            **python_identity,
            "version": sys.version,
            "implementation": platform.python_implementation(),
        },
        "git_version": subprocess.run(
            ["git", "--version"],
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
        ).stdout.strip(),
        "cargo_version": subprocess.run(
            ["cargo", "--version", "--verbose"],
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
        ).stdout.strip(),
        "rustc_version": subprocess.run(
            ["rustc", "--version", "--verbose"],
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
        ).stdout.strip(),
        "platform": platform.platform(),
    }


def _live_source_identity(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    exact(
        git(root, "rev-parse", "--show-toplevel").replace("\\", "/"),
        root.as_posix(),
        "REPOSITORY_ROOT",
    )
    exact(
        git(root, "remote", "get-url", "origin"),
        contract["repository"]["origin_url"],
        "ORIGIN_URL",
    )
    exact(
        git(root, "branch", "--show-current"),
        contract["repository"]["branch"],
        "BRANCH",
    )
    head = str(git(root, "rev-parse", "HEAD"))
    origin = str(git(root, "rev-parse", "origin/main"))
    live_line = str(git(root, "ls-remote", "origin", "refs/heads/main"))
    require(bool(live_line), "LIVE_REMOTE_MISSING")
    live = live_line.split()[0]
    return {
        "commit": head,
        "origin_main_commit": origin,
        "live_main_commit": live,
        "branch": contract["repository"]["branch"],
        "origin_url": contract["repository"]["origin_url"],
        "clean": str(git(root, "status", "--porcelain=v1")) == "",
        "local_origin_live_equal": head == origin == live,
    }


def _require_official_freeze(
    root: Path,
    contract: dict[str, Any],
    source: dict[str, Any],
) -> None:
    require(source["clean"], "OFFICIAL_SOURCE_DIRTY")
    require(source["local_origin_live_equal"], "OFFICIAL_SOURCE_NOT_LIVE_EQUAL")
    closure = root / str(contract["closure"]["path"])
    require(not closure.exists(), "OFFICIAL_QUALIFICATION_ALREADY_PUBLISHED")
    parent = str(contract["authored_parent_commit"])
    exact(
        str(contract["implementation_source_commit"]),
        parent,
        "IMPLEMENTATION_PARENT",
    )
    git(root, "merge-base", "--is-ancestor", parent, str(source["commit"]))
    changed = str(git(root, "diff", "--name-only", f"{parent}..{source['commit']}"))
    exact(
        changed.splitlines(), contract["authored_source_paths"], "AUTHORED_SOURCE_PATHS"
    )


def _source_manifest(
    root: Path,
    source_commit: str,
    paths: list[str],
    *,
    observed_checkout: bool = False,
) -> dict[str, Any]:
    if observed_checkout:
        entries = []
        for relative in paths:
            value = (root / relative).read_bytes()
            entries.append(
                {
                    "path": relative,
                    "blob_oid": str(git(root, "hash-object", relative)),
                    "byte_length": len(value),
                    "raw_sha256": sha256(value),
                }
            )
    else:
        entries = frozen_manifest(root, source_commit, paths)
    encoded = canonical_bytes(entries)
    return {
        "raw_representation": (
            "observed_checkout" if observed_checkout else "git_blob"
        ),
        "entry_count": len(entries),
        "canonical_sha256": sha256(encoded),
        "canonical_byte_length": len(encoded),
        "entries": entries,
    }


def _run_workers(
    root: Path,
    runtime: Path,
    contract: dict[str, Any],
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    retained: list[dict[str, Any]] = []
    positive = 0
    forced = 0
    for specification in contract["workers"]:
        receipt = run_godot_worker(
            root,
            runtime,
            root / str(specification["path"]),
            str(specification["marker"]),
            runtime_args=tuple(
                str(value) for value in specification.get("runtime_arguments", [])
            ),
        )
        require_fields(
            receipt, specification["expected_fields"], str(specification["id"])
        )
        require_zero_authority(receipt)
        require(
            receipt.get("physics_state_modified") is False,
            f"{specification['id']}:PHYSICS_STATE",
        )
        require(
            receipt.get("physical_question_opened") is False,
            f"{specification['id']}:PHYSICAL_QUESTION",
        )
        encoded = canonical_bytes(receipt)
        selected = {key: receipt[key] for key in specification["retained_fields"]}
        worker_record: dict[str, Any] = {
            "id": specification["id"],
            "path": specification["path"],
            "marker": specification["marker"],
            "receipt_canonical_sha256": sha256(encoded),
            "receipt_canonical_byte_length": len(encoded),
            "selected_receipt": selected,
        }
        if bool(specification.get("retain_full_receipt", False)):
            worker_record["full_receipt"] = receipt
        retained.append(worker_record)
        positive += int(receipt["positive_case_count"])
        forced += int(receipt["forced_failure_case_count"])
    return retained, {
        "worker_count": len(retained),
        "positive_case_count": positive,
        "forced_failure_case_count": forced,
        "historical_closure_audits_executed_count": 0,
        "bespoke_physical_canary_count": 0,
        "full_seeded_ghost_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "body_impulse_write_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _validate_prospective_physical_question(
    contract: dict[str, Any],
) -> dict[str, Any] | None:
    """Validate an optional compact one-world/two-step physical declaration.

    The shared qualifier supports two deliberately small development profiles:
    an established production-route ghost and a native field-population
    observation.  Keeping the bounds here prevents each successor from growing
    a bespoke source audit while preserving distinct authorization semantics.
    """

    declared = contract["physical_question_declared"]
    require(isinstance(declared, bool), "PHYSICAL_QUESTION_DECLARATION_TYPE")
    if not declared:
        return None
    for key in (
        "finite_decision_declared",
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        exact(contract[key], False, f"PHYSICAL_QUESTION:{key}")
    question = contract["prospective_physical_question"]
    question_kind = str(question["physical_question_kind"])
    require(
        question_kind in ("integration_ghost", "native_observation_smoke"),
        "PHYSICAL_QUESTION_KIND",
    )
    seed_label = str(question["seed_label"])
    seed_digest = sha256(seed_label.encode("utf-8"))
    profile = (
        {
            "physical_question_kind": "integration_ghost",
            "portable_collection_count": 2,
            "portable_control_plan_count": 2,
            "portable_command_application_count": 1,
            "valid_complete_status": "valid_complete_integration_ghost",
            "invalid_or_incomplete_status": "invalid_or_incomplete_integration_ghost",
        }
        if question_kind == "integration_ghost"
        else {
            "physical_question_kind": "native_observation_smoke",
            "portable_collection_count": 0,
            "portable_control_plan_count": 0,
            "portable_command_application_count": 0,
            "native_observation_count": 2,
            "valid_complete_status": "valid_complete_native_observation_smoke",
            "invalid_or_incomplete_status": (
                "invalid_or_incomplete_native_observation_smoke"
            ),
        }
    )
    expected_question = {
        **question,
        "question_class": "development",
        "physical_question_kind": profile["physical_question_kind"],
        "seed_derivation_rule": (
            "uint32(first_8_sha256_hex_of_utf8_seed_label) & 0x7fffffff"
        ),
        "seed": int(seed_digest[7:15], 16) & 0x7FFFFFFF,
        "seed_sha256": seed_digest,
        "held_out": False,
        "world_count": 1,
        "maximum_model_construction_attempt_count": 1,
        "maximum_model_construction_count": 1,
        "maximum_world_attempt_count": 1,
        "maximum_world_build_count": 1,
        "maximum_outer_solver_steps": 2,
        "minimum_completed_solver_steps_for_valid_route": 2,
        "physics_ticks_per_second": 120,
        "outer_step_duration_s": 1.0 / 120.0,
        "portable_collection_count": profile["portable_collection_count"],
        "portable_control_plan_count": profile["portable_control_plan_count"],
        "portable_command_application_count": profile[
            "portable_command_application_count"
        ],
        "behavior_evaluator_invocation_count": 0,
        "new_physical_threshold_count": 0,
        "new_equivalence_margin_count": 0,
        "physical_population_claim_count": 0,
        "full_seeded_world_demo": False,
        "matched_zero_arm_required": False,
        "additional_seed_required": False,
        "recovery_success_required": False,
        "same_source_attempt_limit": 1,
        "same_identity_rerun_permitted": False,
        "physical_execution_authorized": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    if question_kind == "native_observation_smoke":
        expected_question["native_observation_count"] = profile[
            "native_observation_count"
        ]
    exact(question, expected_question, "PHYSICAL_QUESTION")
    runner = contract["physical_runner"]
    require(
        (Path(str(runner["script_path"]))).as_posix() in contract["source_inventory"],
        "PHYSICAL_RUNNER_NOT_IN_INVENTORY",
    )
    require(
        (Path(str(runner["worker_path"]))).as_posix() in contract["source_inventory"],
        "PHYSICAL_WORKER_NOT_IN_INVENTORY",
    )
    exact(
        runner["physical_question_kind"],
        profile["physical_question_kind"],
        "PHYSICAL_RUNNER_KIND",
    )
    exact(runner["maximum_outer_solver_steps"], 2, "PHYSICAL_RUNNER_STEPS")
    exact(runner["maximum_world_build_count"], 1, "PHYSICAL_RUNNER_WORLDS")
    exact(runner["seed"], question["seed"], "PHYSICAL_RUNNER_SEED")
    exact(runner["seed_sha256"], question["seed_sha256"], "PHYSICAL_RUNNER_SEED_SHA")
    exact(
        runner["valid_complete_status"],
        profile["valid_complete_status"],
        "PHYSICAL_RUNNER_VALID_STATUS",
    )
    exact(
        runner["invalid_or_incomplete_status"],
        profile["invalid_or_incomplete_status"],
        "PHYSICAL_RUNNER_INVALID_STATUS",
    )
    if "worker_gate_id" in runner:
        worker_gate_id = runner["worker_gate_id"]
        require(
            isinstance(worker_gate_id, str) and worker_gate_id.startswith("QSDK-R24D"),
            "PHYSICAL_RUNNER_WORKER_GATE_ID",
        )
    if "evidence_directory_name" in runner:
        evidence_directory_name = runner["evidence_directory_name"]
        require(
            isinstance(evidence_directory_name, str)
            and evidence_directory_name
            and evidence_directory_name[0]
            in "abcdefghijklmnopqrstuvwxyz0123456789"
            and all(
                character in "abcdefghijklmnopqrstuvwxyz0123456789-"
                for character in evidence_directory_name
            ),
            "PHYSICAL_RUNNER_EVIDENCE_DIRECTORY_NAME",
        )
    return question


def _run_process_controls(
    root: Path,
    contract: dict[str, Any],
) -> tuple[list[dict[str, Any]], dict[str, int]]:
    """Run compact declarative process controls without opening physics."""

    retained: list[dict[str, Any]] = []
    forced_failures = 0
    for specification in contract.get("process_controls", []):
        command = [str(value) for value in specification["command"]]
        completed = subprocess.run(
            command,
            cwd=root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="strict",
            check=False,
        )
        exact(
            completed.returncode,
            specification["expected_exit_code"],
            f"PROCESS_CONTROL:{specification['id']}:EXIT",
        )
        if specification.get("stderr_empty", False):
            exact(completed.stderr, "", f"PROCESS_CONTROL:{specification['id']}:STDERR")
        if "stderr_contains" in specification:
            require(
                str(specification["stderr_contains"]) in completed.stderr,
                f"PROCESS_CONTROL:{specification['id']}:STDERR_CONTAINS",
            )
        if "stdout_forbidden_text" in specification:
            require(
                str(specification["stdout_forbidden_text"]) not in completed.stdout,
                f"PROCESS_CONTROL:{specification['id']}:STDOUT_FORBIDDEN",
            )
        selected_receipt: dict[str, Any] | None = None
        marker = specification.get("marker")
        if marker is not None:
            lines = [
                line
                for line in completed.stdout.splitlines()
                if line.startswith(str(marker))
            ]
            exact(len(lines), 1, f"PROCESS_CONTROL:{specification['id']}:MARKER")
            value = json.loads(lines[0][len(str(marker)):])
            require(isinstance(value, dict), f"PROCESS_CONTROL:{specification['id']}:RECEIPT")
            require_fields(value, specification["expected_fields"], str(specification["id"]))
            require_zero_authority(value)
            selected_receipt = {
                key: value[key] for key in specification["expected_fields"]
            }
        forced = bool(specification.get("forced_failure", False))
        forced_failures += int(forced)
        retained.append(
            {
                "id": specification["id"],
                "command": command,
                "exit_code": completed.returncode,
                "forced_failure": forced,
                "stdout_raw_sha256": sha256(completed.stdout.encode("utf-8")),
                "stdout_byte_length": len(completed.stdout.encode("utf-8")),
                "stderr_raw_sha256": sha256(completed.stderr.encode("utf-8")),
                "stderr_byte_length": len(completed.stderr.encode("utf-8")),
                "selected_receipt": selected_receipt,
            }
        )
    return retained, {
        "process_control_count": len(retained),
        "forced_failure_process_control_count": forced_failures,
    }


def _verify_process_controls(
    contract: dict[str, Any],
    retained: Any,
) -> None:
    specifications = contract.get("process_controls", [])
    require(isinstance(retained, list), "CLOSURE_PROCESS_CONTROLS_TYPE")
    exact(len(retained), len(specifications), "CLOSURE_PROCESS_CONTROLS_COUNT")
    for specification, observed in zip(specifications, retained, strict=True):
        exact(observed["id"], specification["id"], "CLOSURE_PROCESS_CONTROL_ID")
        exact(
            observed["exit_code"],
            specification["expected_exit_code"],
            "CLOSURE_PROCESS_CONTROL_EXIT",
        )
        exact(
            observed["forced_failure"],
            bool(specification.get("forced_failure", False)),
            "CLOSURE_PROCESS_CONTROL_FORCED",
        )
        if "expected_fields" in specification:
            exact(
                observed["selected_receipt"],
                specification["expected_fields"],
                "CLOSURE_PROCESS_CONTROL_RECEIPT",
            )


def qualify(
    root: Path,
    contract_path: Path,
    mode: str,
) -> dict[str, Any]:
    contract = load(contract_path)
    exact(contract["question_class"], "development", "QUESTION_CLASS")
    physical_question = _validate_prospective_physical_question(contract)
    require(
        contract["physical_execution_authorized"] is False,
        "PHYSICAL_EXECUTION_AUTHORIZED",
    )
    source = _live_source_identity(root, contract)
    if mode == "qualify":
        _require_official_freeze(root, contract, source)
    _require_bound_file(root, contract["bound_predecessor"], "PREDECESSOR")
    runtime = _require_runtime(contract)
    retained_build_artifacts = _require_retained_build_artifacts(contract)
    external_source = _require_exact_external_source(root, contract)
    host_extension_build = _run_host_extension_build(root, contract)
    manifest = _source_manifest(
        root,
        str(source["commit"]),
        list(contract["source_inventory"]),
        observed_checkout=mode != "qualify",
    )
    source_text_controls = _require_source_text_controls(
        root,
        contract,
        str(source["commit"]),
        observed_checkout=mode != "qualify",
    )
    if "source_text_control_count" in contract["qualification"]:
        exact(
            len(source_text_controls),
            contract["qualification"]["source_text_control_count"],
            "SOURCE_TEXT_CONTROL_COUNT",
        )
    workers, aggregate = _run_workers(
        root,
        Path(str(contract["exact_runtime"]["console_path"])),
        contract,
    )
    process_controls, process_counts = _run_process_controls(root, contract)
    aggregate.update(process_counts)
    for key in (
        "worker_count",
        "positive_case_count",
        "forced_failure_case_count",
        "historical_closure_audits_executed_count",
        "bespoke_physical_canary_count",
        "full_seeded_ghost_count",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(aggregate[key], contract["qualification"][key], f"AGGREGATE:{key}")
    for key in ("process_control_count", "forced_failure_process_control_count"):
        if key in contract["qualification"]:
            exact(aggregate[key], contract["qualification"][key], f"AGGREGATE:{key}")
    contract_raw = contract_path.read_bytes()
    receipt = {
        "schema_version": contract["qualification"]["receipt_schema"],
        "gate_id": contract["gate_id"],
        "status": (
            "passed_clean_pushed_zero_world_qualification"
            if mode == "qualify"
            else "passed_repeatable_zero_world_development_rehearsal"
        ),
        "recorded_at_utc": _utc_now(),
        "ledger_scope": {
            **contract["ledger_scope"],
            "authority_mode": (
                "clean_pushed_zero_world_implementation_qualification"
                if mode == "qualify"
                else "repeatable_zero_world_development_rehearsal"
            ),
        },
        "official_qualification": mode == "qualify",
        "source": source,
        "contract": {
            "path": contract_path.relative_to(root).as_posix(),
            "raw_sha256": sha256(contract_raw),
            "byte_length": len(contract_raw),
        },
        "bound_predecessor": contract["bound_predecessor"],
        "exact_runtime": runtime,
        "retained_build_artifacts": retained_build_artifacts,
        "qualification_toolchain": _qualification_toolchain(),
        "source_manifest": manifest,
        "source_text_controls": source_text_controls,
        "workers": workers,
        "process_controls": process_controls,
        "aggregate": aggregate,
        "physical_question_declared": physical_question is not None,
        "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    if external_source is not None:
        receipt["exact_external_source"] = external_source
    if host_extension_build is not None:
        receipt["host_extension_build"] = host_extension_build
    return receipt


def verify_closure(
    root: Path,
    contract_path: Path,
) -> dict[str, Any]:
    contract = load(contract_path)
    physical_question = _validate_prospective_physical_question(contract)
    closure_path = root / str(contract["closure"]["path"])
    closure = load(closure_path)
    exact(
        (closure["schema_version"], closure["gate_id"], closure["status"]),
        (
            contract["closure"]["schema"],
            contract["gate_id"],
            "closed_passing_zero_world_implementation_qualification",
        ),
        "CLOSURE_IDENTITY",
    )
    receipt = closure["qualification_receipt"]
    exact(receipt["official_qualification"], True, "CLOSURE_OFFICIAL")
    _verify_process_controls(contract, receipt.get("process_controls", []))
    source_commit = str(receipt["source"]["commit"])
    git(root, "cat-file", "-e", f"{source_commit}^{{commit}}")
    for reference in ("HEAD", "origin/main"):
        git(
            root,
            "merge-base",
            "--is-ancestor",
            source_commit,
            str(git(root, "rev-parse", reference)),
        )
    manifest = _source_manifest(root, source_commit, list(contract["source_inventory"]))
    exact(manifest, receipt["source_manifest"], "CLOSURE_SOURCE_MANIFEST")
    exact(
        receipt.get("source_text_controls", []),
        _require_source_text_controls(
            root,
            contract,
            source_commit,
            observed_checkout=False,
        ),
        "CLOSURE_SOURCE_TEXT_CONTROLS",
    )
    contract_at_freeze = source_bytes(
        root, source_commit, contract_path.relative_to(root).as_posix()
    )
    exact(
        sha256(contract_at_freeze),
        receipt["contract"]["raw_sha256"],
        "CLOSURE_CONTRACT_SHA256",
    )
    exact(
        len(contract_at_freeze),
        receipt["contract"]["byte_length"],
        "CLOSURE_CONTRACT_LENGTH",
    )
    _require_bound_file(root, contract["bound_predecessor"], "PREDECESSOR")
    _require_runtime(contract)
    exact(
        receipt.get("retained_build_artifacts", []),
        _require_retained_build_artifacts(contract),
        "CLOSURE_RETAINED_BUILD_ARTIFACTS",
    )
    if "exact_external_source" in contract:
        external_source = receipt.get("exact_external_source")
        require(isinstance(external_source, dict), "CLOSURE_EXTERNAL_SOURCE_MISSING")
        _verify_exact_external_source_receipt(root, contract, external_source)
    if "host_extension_build" in contract:
        build = receipt.get("host_extension_build")
        require(isinstance(build, dict), "CLOSURE_HOST_BUILD_MISSING")
        exact(
            build.get("schema_version"),
            "sporespore_compact_godot_host_extension_build_receipt_v1",
            "CLOSURE_HOST_BUILD_SCHEMA",
        )
        require(
            build.get("source_build_executed") is True, "CLOSURE_HOST_BUILD_EXECUTED"
        )
        exact(
            build.get("artifact", {}).get("path"),
            contract["host_extension_build"]["artifact_path"],
            "CLOSURE_HOST_BUILD_ARTIFACT",
        )
    aggregate = receipt["aggregate"]
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "body_impulse_write_count",
        "native_readback_count",
        "solver_step_count",
    ):
        exact(aggregate[key], 0, f"CLOSURE_ZERO:{key}")
    for key in (
        "physics_state_modified",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(aggregate[key], False, f"CLOSURE_AUTHORITY:{key}")
    if physical_question is not None:
        exact(closure["question_class"], "development", "CLOSURE_QUESTION_CLASS")
        exact(closure["physical_question_declared"], True, "CLOSURE_PHYSICAL_DECLARED")
        exact(
            closure["source"]["source_freeze_commit"],
            source_commit,
            "CLOSURE_SOURCE_FREEZE",
        )
        exact(
            closure["qualification"],
            {
                **closure["qualification"],
                "official_zero_world_qualification_passed": True,
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
            },
            "CLOSURE_QUALIFICATION",
        )
        decision = closure["decision"]
        exact(decision["physical_execution_authorized"], True, "CLOSURE_PHYSICAL_AUTH")
        if physical_question["physical_question_kind"] == "integration_ghost":
            exact(
                decision["physical_route_ghost_authorized"], True, "CLOSURE_ROUTE_AUTH"
            )
            exact(decision["physical_ghost_authorized"], True, "CLOSURE_GHOST_AUTH")
        else:
            exact(
                decision["physical_native_observation_authorized"],
                True,
                "CLOSURE_NATIVE_OBSERVATION_AUTH",
            )
            exact(
                decision.get("physical_route_ghost_authorized", False),
                False,
                "CLOSURE_ROUTE_AUTH",
            )
            exact(
                decision.get("physical_ghost_authorized", False),
                False,
                "CLOSURE_GHOST_AUTH",
            )
        exact(decision["authorized_world_count"], 1, "CLOSURE_AUTHORIZED_WORLDS")
        for key in (
            "maximum_world_build_count",
            "maximum_outer_solver_steps",
            "physics_ticks_per_second",
            "outer_step_duration_s",
            "seed",
            "seed_label",
            "seed_sha256",
            "held_out",
        ):
            expected_key = "world_count" if key == "maximum_world_build_count" else key
            exact(decision[key], physical_question[expected_key], f"CLOSURE_DECISION:{key}")
        exact(
            closure["claim_boundary"],
            {
                **closure["claim_boundary"],
                "complete_zero_world_gate_passed": True,
                "physical_execution_authorized": True,
                "physical_attempted": False,
                "prone_to_standing_claimed": False,
                "physical_acceptance_authority": False,
                "release_authority": False,
            },
            "CLOSURE_CLAIM_BOUNDARY",
        )
    return {
        "schema_version": contract["closure"]["audit_receipt_schema"],
        "gate_id": contract["gate_id"],
        "ok": True,
        "closure_path": contract["closure"]["path"],
        "source_freeze_commit": source_commit,
        "source_manifest_entry_count": manifest["entry_count"],
        "source_manifest_canonical_sha256": manifest["canonical_sha256"],
        "worker_count": aggregate["worker_count"],
        "positive_case_count": aggregate["positive_case_count"],
        "forced_failure_case_count": aggregate["forced_failure_case_count"],
        "historical_closure_audits_executed_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def run_cli(root: Path, contract_relative: str) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mode",
        choices=("development", "qualify", "verify-closure"),
        default="development",
    )
    parser.add_argument("--core-library", default="")
    arguments = parser.parse_args()
    contract_path = root / contract_relative
    contract: dict[str, Any] = {}
    try:
        contract = load(contract_path)
        receipt = (
            verify_closure(root, contract_path)
            if arguments.mode == "verify-closure"
            else qualify(root, contract_path, arguments.mode)
        )
        marker = (
            contract["closure"]["audit_marker"]
            if arguments.mode == "verify-closure"
            else contract["qualification"]["pass_marker"]
        )
        print(marker + " " + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
        return 0
    except (
        ClosureAuditError,
        ControlError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        json.JSONDecodeError,
    ) as error:
        marker = contract.get("qualification", {}).get(
            "fail_marker", "QSDK_COMPACT_GODOT_ZERO_WORLD_QUALIFICATION_FAIL"
        )
        print(
            marker
            + " "
            + json.dumps(
                {"ok": False, "error": str(error)},
                sort_keys=True,
                separators=(",", ":"),
            )
        )
        return 1
