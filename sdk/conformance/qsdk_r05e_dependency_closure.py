#!/usr/bin/env python3
"""Prove the complete declared local source closure for QSDK-R05E at zero worlds."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "sdk/qsdk_r05e_dependency_manifest_v1.json"
SCHEMA_VERSION = "sporespore_qsdk_r05e_dependency_manifest_v1"
POLICY_ID = "qsdk_r05e_declared_roots_recursive_gdscript_and_rust_build_closure_v1"
PASS_MARKER = "QSDK_R05E_DEPENDENCY_CLOSURE_PASS "
LOCAL_SOURCE_SUFFIXES = {
    ".gd",
    ".gdextension",
    ".godot",
    ".json",
    ".lock",
    ".ps1",
    ".py",
    ".rs",
    ".toml",
    ".tscn",
    ".tres",
}
NATIVE_SUFFIXES = {".dll", ".dylib", ".exe", ".so"}
RES_LITERAL = re.compile(r"res://([^\"'\s)\],}]+)")
REQUIRED_RESOURCE = re.compile(
    r"(?:\b(?:preload|load)\s*\(\s*[\"']res://([^\"']+)[\"']\s*\))"
    r"|(?:\bextends\s+[\"']res://([^\"']+)[\"'])"
)


class ClosureFailure(RuntimeError):
    """The declared R05E source closure is not exact."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureFailure(code)


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ClosureFailure(f"R05E_DEPENDENCY_MANIFEST_UNREADABLE:{exc}") from exc
    require(isinstance(value, dict), "R05E_DEPENDENCY_MANIFEST_NOT_OBJECT")
    return value


def exact_string_list(value: Any, code: str) -> list[str]:
    require(
        isinstance(value, list)
        and value
        and all(isinstance(item, str) and item and "\\" not in item for item in value),
        code,
    )
    result = list(value)
    require(result == sorted(set(result)), f"{code}_ORDER_OR_DUPLICATE")
    return result


def relative_path(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError as exc:
        raise ClosureFailure(f"R05E_DEPENDENCY_ESCAPES_REPOSITORY:{path}") from exc


def resolve_source(relative: str) -> Path:
    require(
        relative == relative.strip()
        and not Path(relative).is_absolute()
        and ".." not in Path(relative).parts,
        f"R05E_DEPENDENCY_PATH_INVALID:{relative}",
    )
    path = (ROOT / relative).resolve()
    relative_path(path)
    require(path.is_file(), f"R05E_DEPENDENCY_MISSING:{relative}")
    require(
        path.suffix.lower() in LOCAL_SOURCE_SUFFIXES or path.name == ".gitattributes",
        f"R05E_DEPENDENCY_NOT_LOCAL_SOURCE:{relative}",
    )
    return path


def resource_edges(path: Path) -> set[Path]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise ClosureFailure(
            f"R05E_DEPENDENCY_RESOURCE_UNREADABLE:{relative_path(path)}:{exc}"
        ) from exc
    required = {first or second for first, second in REQUIRED_RESOURCE.findall(text)}
    literals = set(RES_LITERAL.findall(text))
    edges: set[Path] = set()
    for literal in sorted(required | literals):
        normalized = literal.replace("\\", "/")
        if not normalized or normalized.endswith("/") or "{" in normalized:
            continue
        target = (ROOT / normalized).resolve()
        if target.is_file():
            if target.suffix.lower() in NATIVE_SUFFIXES:
                continue
            relative_path(target)
            edges.add(target)
        elif literal in required:
            raise ClosureFailure(
                "R05E_DEPENDENCY_REQUIRED_RESOURCE_UNRESOLVED:"
                f"{relative_path(path)}:{literal}"
            )
    return edges


def compose_gdscript_closure(direct_paths: Iterable[str]) -> list[str]:
    queue = sorted(resolve_source(value) for value in direct_paths)
    discovered: set[Path] = set()
    while queue:
        current = queue.pop(0)
        if current in discovered:
            continue
        discovered.add(current)
        for edge in sorted(resource_edges(current)):
            if edge not in discovered and edge not in queue:
                queue.append(edge)
        queue.sort()
    return sorted(relative_path(path) for path in discovered)


def path_set_digest(paths: Iterable[str]) -> str:
    payload = "\n".join(paths).encode("utf-8")
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def assert_exact_set(actual: list[str], expected: list[str], code: str) -> None:
    require(actual == sorted(set(actual)), f"{code}_ACTUAL_ORDER")
    require(expected == sorted(set(expected)), f"{code}_EXPECTED_ORDER")
    missing = sorted(set(actual) - set(expected))
    surplus = sorted(set(expected) - set(actual))
    if missing or surplus:
        raise ClosureFailure(
            f"{code}:"
            + json.dumps(
                {
                    "discovered_not_declared": missing,
                    "declared_not_discovered": surplus,
                },
                sort_keys=True,
                separators=(",", ":"),
            )
        )


def tracked_paths() -> set[str]:
    result = subprocess.run(
        ("git", "-C", str(ROOT), "ls-files"),
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    require(result.returncode == 0, "R05E_DEPENDENCY_GIT_LS_FILES_FAILED")
    return set(result.stdout.splitlines())


def checkout_eol_attributes(paths: list[str]) -> dict[str, str]:
    result = subprocess.run(
        (
            "git",
            "-C",
            str(ROOT),
            "check-attr",
            "-z",
            "eol",
            "--",
            *paths,
        ),
        check=False,
        capture_output=True,
    )
    require(result.returncode == 0, "R05E_DEPENDENCY_GIT_CHECK_ATTR_FAILED")
    try:
        fields = result.stdout.decode("utf-8").split("\0")
    except UnicodeDecodeError as exc:
        raise ClosureFailure("R05E_DEPENDENCY_GIT_CHECK_ATTR_NOT_UTF8") from exc
    if fields and fields[-1] == "":
        fields.pop()
    require(
        len(fields) == len(paths) * 3,
        "R05E_DEPENDENCY_GIT_CHECK_ATTR_FIELD_COUNT",
    )
    attributes: dict[str, str] = {}
    for index in range(0, len(fields), 3):
        path, attribute, value = fields[index : index + 3]
        require(attribute == "eol", "R05E_DEPENDENCY_GIT_CHECK_ATTR_NAME")
        require(path not in attributes, "R05E_DEPENDENCY_GIT_CHECK_ATTR_DUPLICATE")
        attributes[path] = value
    require(sorted(attributes) == paths, "R05E_DEPENDENCY_GIT_CHECK_ATTR_PATH_SET")
    return attributes


def run_mutation_controls(paths: list[str]) -> int:
    mutations = (
        paths[1:],
        sorted([*paths, "tests/undeclared_r05e_dependency.gd"]),
        [*reversed(paths)],
        [*paths, paths[-1]],
    )
    rejected = 0
    for mutation in mutations:
        try:
            assert_exact_set(paths, list(mutation), "R05E_DEPENDENCY_MUTATION")
        except ClosureFailure:
            rejected += 1
    require(rejected == len(mutations), "R05E_DEPENDENCY_MUTATION_ACCEPTED")
    return rejected


def audit(require_tracked: bool) -> dict[str, Any]:
    manifest = read_json(MANIFEST_PATH)
    require(
        set(manifest)
        == {
            "schema_version",
            "status",
            "gate_id",
            "ledger_scope",
            "policy",
            "claim_boundary",
        },
        "R05E_DEPENDENCY_MANIFEST_KEYS",
    )
    require(manifest.get("schema_version") == SCHEMA_VERSION, "R05E_DEPENDENCY_SCHEMA")
    require(manifest.get("gate_id") == "QSDK-R05E", "R05E_DEPENDENCY_GATE")
    require(
        manifest.get("status")
        == "prospective_complete_transitive_source_closure_zero_world",
        "R05E_DEPENDENCY_STATUS",
    )
    policy = manifest.get("policy")
    claim = manifest.get("claim_boundary")
    require(isinstance(policy, dict), "R05E_DEPENDENCY_POLICY_NOT_OBJECT")
    require(isinstance(claim, dict), "R05E_DEPENDENCY_CLAIM_NOT_OBJECT")
    require(policy.get("policy_id") == POLICY_ID, "R05E_DEPENDENCY_POLICY_ID")

    direct = exact_string_list(
        policy.get("gdscript_direct_entry_paths"), "R05E_DEPENDENCY_DIRECT_PATHS"
    )
    expected_gdscript = exact_string_list(
        policy.get("expected_gdscript_transitive_paths"),
        "R05E_DEPENDENCY_GDSCRIPT_PATHS",
    )
    rust = exact_string_list(
        policy.get("rust_build_paths"), "R05E_DEPENDENCY_RUST_PATHS"
    )
    process = exact_string_list(
        policy.get("process_and_audit_paths"), "R05E_DEPENDENCY_PROCESS_PATHS"
    )
    active_runtime = exact_string_list(
        policy.get("active_runtime_artifact_paths"),
        "R05E_DEPENDENCY_ACTIVE_RUNTIME_PATHS",
    )
    inactive_runtime = exact_string_list(
        policy.get("inactive_declared_runtime_artifact_paths"),
        "R05E_DEPENDENCY_INACTIVE_RUNTIME_PATHS",
    )
    require(
        active_runtime == ["sdk/target/debug/sporespore_godot_adapter.dll"]
        and inactive_runtime == ["sdk/target/release/sporespore_godot_adapter.dll"],
        "R05E_DEPENDENCY_RUNTIME_ARTIFACT_CLASSIFICATION",
    )

    discovered_gdscript = compose_gdscript_closure(direct)
    assert_exact_set(
        discovered_gdscript, expected_gdscript, "R05E_DEPENDENCY_GDSCRIPT_CLOSURE"
    )
    expected_core_rust = sorted(
        path.relative_to(ROOT).as_posix()
        for path in (ROOT / "sdk/core/src").rglob("*.rs")
        if path.is_file()
    )
    declared_core_rust = [path for path in rust if path.startswith("sdk/core/src/")]
    assert_exact_set(
        expected_core_rust, declared_core_rust, "R05E_DEPENDENCY_CORE_RUST_CLOSURE"
    )

    qualified_paths = sorted(set(expected_gdscript) | set(rust) | set(process))
    for relative in qualified_paths:
        resolve_source(relative)
    non_lf_worktree_paths = sorted(
        relative
        for relative in qualified_paths
        if b"\r" in resolve_source(relative).read_bytes()
    )
    require(
        not non_lf_worktree_paths,
        "R05E_DEPENDENCY_NON_LF_WORKTREE_BYTES:"
        + json.dumps(non_lf_worktree_paths, separators=(",", ":")),
    )
    require(
        len(qualified_paths) == policy.get("expected_qualified_source_count") == 80,
        "R05E_DEPENDENCY_QUALIFIED_COUNT",
    )
    require(
        path_set_digest(qualified_paths)
        == policy.get("expected_qualified_source_path_sha256"),
        "R05E_DEPENDENCY_QUALIFIED_DIGEST",
    )
    require(
        not (set(qualified_paths) & (set(active_runtime) | set(inactive_runtime))),
        "R05E_DEPENDENCY_RUNTIME_MISCLASSIFIED_AS_SOURCE",
    )
    eol_attributes = checkout_eol_attributes(qualified_paths)
    non_lf_paths = sorted(
        path for path, value in eol_attributes.items() if value != "lf"
    )
    require(
        not non_lf_paths,
        "R05E_DEPENDENCY_NON_LF_CHECKOUT_POLICY:"
        + json.dumps(non_lf_paths, separators=(",", ":")),
    )
    tracked = tracked_paths()
    if require_tracked:
        require(
            all(path in tracked for path in qualified_paths),
            "R05E_DEPENDENCY_UNTRACKED_AFTER_SOURCE_FREEZE",
        )
    require(
        claim.get("complete_transitive_local_gdscript_resource_closure_claimed") is True
        and claim.get("complete_local_rust_build_input_closure_claimed") is True
        and claim.get("active_runtime_artifact_requires_separate_qualification_binding")
        is True
        and claim.get("external_toolchain_requires_separate_qualification_binding")
        is True
        and claim.get("model_construction_count") == 0
        and claim.get("world_attempt_count") == 0
        and claim.get("world_build_count") == 0
        and claim.get("solver_step_count") == 0
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False,
        "R05E_DEPENDENCY_CLAIM_BOUNDARY",
    )
    mutation_count = run_mutation_controls(qualified_paths)
    return {
        "schema_version": "sporespore_qsdk_r05e_dependency_closure_zero_world_v1",
        "gate_id": "QSDK-R05E",
        "ok": True,
        "policy_id": POLICY_ID,
        "gdscript_direct_entry_count": len(direct),
        "gdscript_transitive_path_count": len(discovered_gdscript),
        "rust_build_path_count": len(rust),
        "process_and_audit_path_count": len(process),
        "qualified_source_path_count": len(qualified_paths),
        "qualified_source_path_sha256": path_set_digest(qualified_paths),
        "active_runtime_artifact_count": len(active_runtime),
        "inactive_runtime_artifact_count": len(inactive_runtime),
        "mutation_rejection_count": mutation_count,
        "all_qualified_paths_lf_checkout_policy": True,
        "all_qualified_paths_tracked": all(path in tracked for path in qualified_paths),
        "tracked_source_required": require_tracked,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-tracked", action="store_true")
    arguments = parser.parse_args()
    try:
        receipt = audit(arguments.require_tracked)
        print(PASS_MARKER + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
        return 0
    except (ClosureFailure, KeyError, OSError, TypeError) as exc:
        print(f"QSDK_R05E_DEPENDENCY_CLOSURE_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
