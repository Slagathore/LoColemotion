#!/usr/bin/env python3
"""Prove QSDK-R10E's complete declared local source closure at zero worlds."""

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
MANIFEST_PATH = ROOT / "sdk/qsdk_r10e_dependency_manifest_v4.json"
SCHEMA_VERSION = "sporespore_qsdk_r10e_dependency_manifest_v4"
POLICY_ID = "qsdk_r10e_declared_roots_recursive_gdscript_and_rust_build_closure_v4"
PASS_MARKER = "QSDK_R10E_DEPENDENCY_CLOSURE_PASS "
DISCOVERY_MARKER = "QSDK_R10E_DEPENDENCY_DISCOVERY_PASS "
LOCAL_SOURCE_SUFFIXES = {
    ".gd",
    ".godot",
    ".gdextension",
    ".json",
    ".lock",
    ".ps1",
    ".py",
    ".rs",
    ".toml",
}
NATIVE_SUFFIXES = {".dll", ".dylib", ".exe", ".so"}
RES_LITERAL = re.compile(r"res://([^\"'\s)\],}]+)")
REQUIRED_RESOURCE = re.compile(
    r"(?:\b(?:preload|load)\s*\(\s*[\"']res://([^\"']+)[\"']\s*\))"
    r"|(?:\bextends\s+[\"']res://([^\"']+)[\"'])"
)
EXPECTED_PROSPECTIVE_RUNTIME_AUTHORITY_PATHS = [
    "sdk/qsdk_r10e_development_route_ghost_execution_authority_v2.json",
    "sdk/qsdk_r10e_development_route_ghost_zero_world_qualification_closure_v2.json",
    "sdk/qsdk_r10e_held_out_finite_decision_execution_authority_v3.json",
    "sdk/qsdk_r10e_held_out_finite_decision_zero_world_qualification_closure_v3.json",
]


class ClosureFailure(RuntimeError):
    """The declared R10E source closure is not exact."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureFailure(code)


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ClosureFailure(f"R10E_DEPENDENCY_MANIFEST_UNREADABLE:{exc}") from exc
    require(isinstance(value, dict), "R10E_DEPENDENCY_MANIFEST_NOT_OBJECT")
    return value


def exact_string_list(value: Any, code: str, *, allow_empty: bool = False) -> list[str]:
    require(
        isinstance(value, list)
        and (allow_empty or bool(value))
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
        raise ClosureFailure(f"R10E_DEPENDENCY_ESCAPES_REPOSITORY:{path}") from exc


def resolve_source(relative: str) -> Path:
    require(
        relative == relative.strip()
        and not Path(relative).is_absolute()
        and ".." not in Path(relative).parts,
        f"R10E_DEPENDENCY_PATH_INVALID:{relative}",
    )
    path = (ROOT / relative).resolve()
    relative_path(path)
    require(path.is_file(), f"R10E_DEPENDENCY_MISSING:{relative}")
    require(
        path.suffix.lower() in LOCAL_SOURCE_SUFFIXES or path.name == ".gitattributes",
        f"R10E_DEPENDENCY_NOT_LOCAL_SOURCE:{relative}",
    )
    return path


def resource_references(path: Path) -> tuple[set[str], set[str]]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise ClosureFailure(
            f"R10E_DEPENDENCY_RESOURCE_UNREADABLE:{relative_path(path)}:{exc}"
        ) from exc
    required = {
        (first or second).replace("\\", "/")
        for first, second in REQUIRED_RESOURCE.findall(text)
    }
    literals = {literal.replace("\\", "/") for literal in RES_LITERAL.findall(text)}
    return required, literals


def resource_edges(path: Path, excluded_runtime_authorities: set[str]) -> set[Path]:
    required, literals = resource_references(path)
    edges: set[Path] = set()
    for literal in sorted(required | literals):
        if not literal or literal.endswith("/") or "{" in literal:
            continue
        if literal in excluded_runtime_authorities:
            require(
                literal not in required,
                f"R10E_DEPENDENCY_REQUIRED_RESOURCE_EXCLUDED:{relative_path(path)}:{literal}",
            )
            continue
        target = (ROOT / literal).resolve()
        if target.is_file():
            if target.suffix.lower() in NATIVE_SUFFIXES:
                continue
            relative_path(target)
            edges.add(target)
        elif literal in required:
            raise ClosureFailure(
                "R10E_DEPENDENCY_REQUIRED_RESOURCE_UNRESOLVED:"
                f"{relative_path(path)}:{literal}"
            )
    return edges


def compose_gdscript_closure(
    direct_paths: Iterable[str], excluded_runtime_authorities: set[str]
) -> list[str]:
    queue = sorted(resolve_source(value) for value in direct_paths)
    discovered: set[Path] = set()
    while queue:
        current = queue.pop(0)
        if current in discovered:
            continue
        discovered.add(current)
        for edge in sorted(resource_edges(current, excluded_runtime_authorities)):
            if edge not in discovered and edge not in queue:
                queue.append(edge)
        queue.sort()
    return sorted(relative_path(path) for path in discovered)


def path_set_digest(paths: Iterable[str]) -> str:
    return "sha256:" + hashlib.sha256("\n".join(paths).encode("utf-8")).hexdigest()


def assert_exact_set(actual: list[str], expected: list[str], code: str) -> None:
    require(actual == sorted(set(actual)), f"{code}_ACTUAL_ORDER")
    require(expected == sorted(set(expected)), f"{code}_EXPECTED_ORDER")
    if actual != expected:
        raise ClosureFailure(
            f"{code}:"
            + json.dumps(
                {
                    "discovered_not_declared": sorted(set(actual) - set(expected)),
                    "declared_not_discovered": sorted(set(expected) - set(actual)),
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
    require(result.returncode == 0, "R10E_DEPENDENCY_GIT_LS_FILES_FAILED")
    return set(result.stdout.splitlines())


def checkout_eol_attributes(paths: list[str]) -> dict[str, str]:
    result = subprocess.run(
        ("git", "-C", str(ROOT), "check-attr", "-z", "eol", "--", *paths),
        check=False,
        capture_output=True,
    )
    require(result.returncode == 0, "R10E_DEPENDENCY_GIT_CHECK_ATTR_FAILED")
    try:
        fields = result.stdout.decode("utf-8").split("\0")
    except UnicodeDecodeError as exc:
        raise ClosureFailure("R10E_DEPENDENCY_GIT_CHECK_ATTR_NOT_UTF8") from exc
    if fields and fields[-1] == "":
        fields.pop()
    require(
        len(fields) == len(paths) * 3,
        "R10E_DEPENDENCY_GIT_CHECK_ATTR_FIELD_COUNT",
    )
    attributes: dict[str, str] = {}
    for index in range(0, len(fields), 3):
        path, attribute, value = fields[index : index + 3]
        require(attribute == "eol", "R10E_DEPENDENCY_GIT_CHECK_ATTR_NAME")
        require(path not in attributes, "R10E_DEPENDENCY_GIT_CHECK_ATTR_DUPLICATE")
        attributes[path] = value
    require(sorted(attributes) == paths, "R10E_DEPENDENCY_GIT_CHECK_ATTR_PATH_SET")
    return attributes


def mutation_controls(paths: list[str]) -> int:
    require(len(paths) >= 2, "R10E_DEPENDENCY_MUTATION_FIXTURE_TOO_SMALL")
    mutations = (
        paths[1:],
        sorted([*paths, "tests/undeclared_r10e_dependency.gd"]),
        [*reversed(paths)],
        [*paths, paths[-1]],
    )
    rejected = 0
    for mutation in mutations:
        try:
            assert_exact_set(paths, list(mutation), "R10E_DEPENDENCY_MUTATION")
        except ClosureFailure:
            rejected += 1
    require(rejected == len(mutations), "R10E_DEPENDENCY_MUTATION_ACCEPTED")
    return rejected


def _validate_manifest_header(
    manifest: dict[str, Any]
) -> tuple[dict[str, Any], dict[str, Any]]:
    require(
        set(manifest)
        == {
            "schema_version",
            "status",
            "gate_id",
            "repair_id",
            "design_authority",
            "ledger_scope",
            "policy",
            "claim_boundary",
        },
        "R10E_DEPENDENCY_MANIFEST_KEYS",
    )
    require(manifest.get("schema_version") == SCHEMA_VERSION, "R10E_DEPENDENCY_SCHEMA")
    require(manifest.get("gate_id") == "QSDK-R10E", "R10E_DEPENDENCY_GATE")
    require(manifest.get("repair_id") == "QSDK-R10E-L3", "R10E_DEPENDENCY_REPAIR")
    require(
        manifest.get("design_authority") == "QSDK-R10E-observer-minimized-successor",
        "R10E_DEPENDENCY_DESIGN_AUTHORITY",
    )
    require(
        manifest.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "prospective_recursive_dependency_closure",
            "question_class": "development",
        },
        "R10E_DEPENDENCY_LEDGER_SCOPE",
    )
    policy = manifest.get("policy")
    claim = manifest.get("claim_boundary")
    require(isinstance(policy, dict), "R10E_DEPENDENCY_POLICY_NOT_OBJECT")
    require(isinstance(claim, dict), "R10E_DEPENDENCY_CLAIM_NOT_OBJECT")
    require(policy.get("policy_id") == POLICY_ID, "R10E_DEPENDENCY_POLICY_ID")
    return policy, claim


def audit(*, require_tracked: bool, allow_unfinalized: bool) -> dict[str, Any]:
    manifest = read_json(MANIFEST_PATH)
    policy, claim = _validate_manifest_header(manifest)
    direct = exact_string_list(
        policy.get("gdscript_direct_entry_paths"), "R10E_DEPENDENCY_DIRECT_PATHS"
    )
    expected_gdscript = exact_string_list(
        policy.get("expected_gdscript_transitive_paths"),
        "R10E_DEPENDENCY_GDSCRIPT_PATHS",
        allow_empty=allow_unfinalized,
    )
    rust = exact_string_list(
        policy.get("rust_build_paths"), "R10E_DEPENDENCY_RUST_PATHS"
    )
    process = exact_string_list(
        policy.get("process_and_audit_paths"), "R10E_DEPENDENCY_PROCESS_PATHS"
    )
    active_runtime = exact_string_list(
        policy.get("active_runtime_artifact_paths"),
        "R10E_DEPENDENCY_ACTIVE_RUNTIME_PATHS",
    )
    inactive_runtime = exact_string_list(
        policy.get("inactive_declared_runtime_artifact_paths"),
        "R10E_DEPENDENCY_INACTIVE_RUNTIME_PATHS",
    )
    prospective_runtime_authorities = exact_string_list(
        policy.get("prospective_runtime_authority_paths"),
        "R10E_DEPENDENCY_PROSPECTIVE_RUNTIME_AUTHORITY_PATHS",
    )
    require(
        active_runtime == ["sdk/target/debug/sporespore_godot_adapter.dll"]
        and inactive_runtime == ["sdk/target/release/sporespore_godot_adapter.dll"],
        "R10E_DEPENDENCY_RUNTIME_ARTIFACT_CLASSIFICATION",
    )
    require(
        prospective_runtime_authorities == EXPECTED_PROSPECTIVE_RUNTIME_AUTHORITY_PATHS,
        "R10E_DEPENDENCY_PROSPECTIVE_RUNTIME_AUTHORITY_CLASSIFICATION",
    )

    prospective_runtime_authority_set = set(prospective_runtime_authorities)
    discovered_gdscript = compose_gdscript_closure(
        direct, prospective_runtime_authority_set
    )
    observed_runtime_authority_literals: set[str] = set()
    for relative in discovered_gdscript:
        required, literals = resource_references(resolve_source(relative))
        require(
            not (required & prospective_runtime_authority_set),
            "R10E_DEPENDENCY_PROSPECTIVE_AUTHORITY_USED_AS_REQUIRED_RESOURCE",
        )
        observed_runtime_authority_literals.update(
            literals & prospective_runtime_authority_set
        )
    require(
        observed_runtime_authority_literals == prospective_runtime_authority_set,
        "R10E_DEPENDENCY_PROSPECTIVE_AUTHORITY_LITERAL_SET",
    )
    finalized = (
        manifest.get("status")
        == "prospective_complete_transitive_source_closure_zero_world"
        and bool(expected_gdscript)
        and isinstance(policy.get("expected_qualified_source_count"), int)
        and policy.get("expected_qualified_source_count", 0) > 0
        and isinstance(policy.get("expected_qualified_source_path_sha256"), str)
        and re.fullmatch(
            r"sha256:[0-9a-f]{64}",
            policy.get("expected_qualified_source_path_sha256", ""),
        )
        is not None
    )
    require(finalized or allow_unfinalized, "R10E_DEPENDENCY_MANIFEST_NOT_FINALIZED")
    if finalized:
        assert_exact_set(
            discovered_gdscript,
            expected_gdscript,
            "R10E_DEPENDENCY_GDSCRIPT_CLOSURE",
        )
    else:
        require(
            manifest.get("status")
            == "prospective_unfinalized_transitive_source_closure_zero_world"
            and expected_gdscript == []
            and policy.get("expected_qualified_source_count") == 0
            and policy.get("expected_qualified_source_path_sha256") == "",
            "R10E_DEPENDENCY_UNFINALIZED_SENTINEL_DRIFT",
        )

    expected_core_rust = sorted(
        path.relative_to(ROOT).as_posix()
        for path in (ROOT / "sdk/core/src").rglob("*.rs")
        if path.is_file()
    )
    declared_core_rust = [path for path in rust if path.startswith("sdk/core/src/")]
    assert_exact_set(
        expected_core_rust,
        declared_core_rust,
        "R10E_DEPENDENCY_CORE_RUST_CLOSURE",
    )
    require(
        [path for path in rust if not path.startswith("sdk/core/src/")]
        == [
            "sdk/Cargo.lock",
            "sdk/Cargo.toml",
            "sdk/adapters/godot/Cargo.toml",
            "sdk/adapters/godot/src/lib.rs",
            "sdk/adapters/rapier/Cargo.toml",
            "sdk/core/Cargo.toml",
        ],
        "R10E_DEPENDENCY_NONCORE_RUST_BUILD_INPUTS",
    )

    qualified = sorted(set(discovered_gdscript) | set(rust) | set(process))
    for relative in qualified:
        resolve_source(relative)
    non_lf_paths = [
        relative
        for relative in qualified
        if b"\r" in resolve_source(relative).read_bytes()
    ]
    require(
        not non_lf_paths,
        "R10E_DEPENDENCY_NON_LF_WORKTREE_BYTES:"
        + json.dumps(non_lf_paths, separators=(",", ":")),
    )
    if finalized:
        require(
            len(qualified) == policy.get("expected_qualified_source_count"),
            "R10E_DEPENDENCY_QUALIFIED_COUNT",
        )
        require(
            path_set_digest(qualified)
            == policy.get("expected_qualified_source_path_sha256"),
            "R10E_DEPENDENCY_QUALIFIED_PATH_DIGEST",
        )
    require(
        not (set(qualified) & (set(active_runtime) | set(inactive_runtime))),
        "R10E_DEPENDENCY_RUNTIME_MISCLASSIFIED_AS_SOURCE",
    )
    require(
        not (set(qualified) & prospective_runtime_authority_set),
        "R10E_DEPENDENCY_PROSPECTIVE_AUTHORITY_MISCLASSIFIED_AS_SOURCE",
    )
    eol = checkout_eol_attributes(qualified)
    non_lf_policy = {path: value for path, value in eol.items() if value != "lf"}
    require(
        not non_lf_policy,
        "R10E_DEPENDENCY_NON_LF_CHECKOUT_POLICY:"
        + json.dumps(non_lf_policy, sort_keys=True, separators=(",", ":")),
    )
    tracked = tracked_paths()
    if require_tracked:
        require(
            all(path in tracked for path in qualified),
            "R10E_DEPENDENCY_UNTRACKED_AFTER_SOURCE_FREEZE",
        )
    expected_claim = {
        "complete_transitive_local_gdscript_resource_closure_claimed": finalized,
        "complete_local_rust_build_input_closure_claimed": finalized,
        "cargo_registry_sources_identified_by_lockfile_not_copied_into_repository": True,
        "active_runtime_artifact_requires_separate_qualification_binding": True,
        "external_toolchain_requires_separate_qualification_binding": True,
        "prospective_runtime_authority_documents_excluded_from_source_closure": True,
        "r10d_development_finite_negative_is_source_authority_not_r10e_behavior_evidence": True,
        "r10d_held_out_invalid_is_source_authority_not_r10e_behavior_evidence": True,
        "r05e_walking_support_is_start_qualification_not_push_recovery_evidence": True,
        "r10e_trace_change_is_measurement_only_and_behavior_neutral": True,
        "r10e_scalar_allowances_are_operation_derived_not_outcome_derived": True,
        "predecessor_failed_qualification_identity_bound": True,
        "predecessor_failed_qualification_carries_no_physical_or_behavior_evidence": True,
        "predecessor_physical_supervisor_refusal_bound": True,
        "predecessor_physical_supervisor_refusal_carries_no_physical_or_behavior_evidence": True,
        "predecessor_supervisor_refusal_physical_attempt_identity_unconsumed": True,
        "predecessor_supervisor_refusal_authority_graph_rerun_prohibited": True,
        "l2_held_out_failure_closure_bound": True,
        "l2_held_out_physical_identity_consumed": True,
        "l2_held_out_behavioral_conclusion_available": False,
        "l2_held_out_same_identity_rerun_prohibited": True,
        "l3_numeric_repair_replays_declared_host_real_operation": True,
        "l3_retained_l2_outcome_used_to_select_allowance": False,
        "l3_effect_floor_changed": False,
        "l3_behavior_threshold_changed": False,
        "l3_population_changed": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    require(claim == expected_claim, "R10E_DEPENDENCY_CLAIM_BOUNDARY")
    active_artifact = ROOT / active_runtime[0]
    require(active_artifact.is_file(), "R10E_DEPENDENCY_ACTIVE_RUNTIME_MISSING")
    return {
        "schema_version": "sporespore_qsdk_r10e_dependency_closure_zero_world_v4",
        "gate_id": "QSDK-R10E",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_recursive_dependency_closure",
            "question_class": "development",
        },
        "ok": True,
        "failure_code": "",
        "policy_id": POLICY_ID,
        "qualification_finalized": finalized,
        "gdscript_direct_entry_count": len(direct),
        "gdscript_transitive_path_count": len(discovered_gdscript),
        "gdscript_transitive_paths": discovered_gdscript,
        "rust_build_path_count": len(rust),
        "process_and_audit_path_count": len(process),
        "prospective_runtime_authority_path_count": len(
            prospective_runtime_authorities
        ),
        "prospective_runtime_authority_paths": prospective_runtime_authorities,
        "all_prospective_runtime_authority_literals_observed": True,
        "qualified_source_path_count": len(qualified),
        "qualified_source_path_sha256": path_set_digest(qualified),
        "qualified_source_paths": qualified,
        "active_runtime_artifact_path": active_runtime[0],
        "active_runtime_artifact_raw_sha256": "sha256:"
        + hashlib.sha256(active_artifact.read_bytes()).hexdigest(),
        "active_runtime_artifact_byte_length": active_artifact.stat().st_size,
        "inactive_runtime_artifact_count": len(inactive_runtime),
        "mutation_rejection_count": mutation_controls(qualified),
        "all_qualified_paths_lf_checkout_policy": True,
        "all_qualified_paths_tracked": all(path in tracked for path in qualified),
        "tracked_source_required": require_tracked,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-tracked", action="store_true")
    parser.add_argument("--allow-unfinalized", action="store_true")
    parser.add_argument("--discover", action="store_true")
    args = parser.parse_args()
    try:
        receipt = audit(
            require_tracked=args.require_tracked,
            allow_unfinalized=args.allow_unfinalized or args.discover,
        )
    except ClosureFailure as exc:
        print(f"QSDK_R10E_DEPENDENCY_CLOSURE_FAIL {exc}", file=sys.stderr)
        return 1
    marker = DISCOVERY_MARKER if args.discover else PASS_MARKER
    print(marker + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
