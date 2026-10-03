#!/usr/bin/env python3
"""Prove the complete local QSDK-R10F source closure at zero worlds."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "sdk/qsdk_r10f_dependency_manifest_v19.json"
SCHEMA_VERSION = "sporespore_qsdk_r10f_dependency_manifest_v19"
POLICY_ID = "qsdk_r10f_declared_roots_recursive_gdscript_and_rust_build_closure_v19"
PASS_MARKER = "QSDK_R10F_DEPENDENCY_CLOSURE_PASS "
DISCOVERY_MARKER = "QSDK_R10F_DEPENDENCY_DISCOVERY_PASS "
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
EXPECTED_RUNTIME_AUTHORITIES = [
    "sdk/qsdk_r10f_development_route_ghost_execution_authority_v15.json",
    "sdk/qsdk_r10f_development_route_ghost_zero_world_qualification_closure_v15.json",
]
L15_MANIFEST_PATH = ROOT / "sdk/qsdk_r10f_dependency_manifest_v20.json"
L15_RUNTIME_AUTHORITIES = [
    "sdk/qsdk_r10f_development_route_ghost_execution_authority_v16.json",
    "sdk/qsdk_r10f_development_route_ghost_zero_world_qualification_closure_v16.json",
]
L15_OWNED_DIRECTORIES = (
    "sdk",
    "sdk/conformance",
    "sdk/adapters/godot/gdscript",
    "tests",
    "tests/fixtures",
)
L15_PREDECESSOR_MANIFEST = {
    "path": "sdk/qsdk_r10f_dependency_manifest_v19.json",
    "byte_length": 22_462,
    "raw_sha256": "sha256:aa962abd055507bd3c9797458352d1cde5947a0faa07f4fcd1a146821afb0dee",
}


class ClosureFailure(RuntimeError):
    """The declared R10F local source closure is not exact."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureFailure(code)


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ClosureFailure(f"R10F_DEPENDENCY_MANIFEST_UNREADABLE:{exc}") from exc
    require(isinstance(value, dict), "R10F_DEPENDENCY_MANIFEST_NOT_OBJECT")
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
        raise ClosureFailure(f"R10F_DEPENDENCY_ESCAPES_REPOSITORY:{path}") from exc


def resolve_source(relative: str) -> Path:
    require(
        relative == relative.strip()
        and not Path(relative).is_absolute()
        and ".." not in Path(relative).parts,
        f"R10F_DEPENDENCY_PATH_INVALID:{relative}",
    )
    path = (ROOT / relative).resolve()
    relative_path(path)
    require(path.is_file(), f"R10F_DEPENDENCY_MISSING:{relative}")
    require(
        path.suffix.lower() in LOCAL_SOURCE_SUFFIXES or path.name == ".gitattributes",
        f"R10F_DEPENDENCY_NOT_LOCAL_SOURCE:{relative}",
    )
    return path


def resource_references(path: Path) -> tuple[set[str], set[str]]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise ClosureFailure(
            f"R10F_DEPENDENCY_RESOURCE_UNREADABLE:{relative_path(path)}:{exc}"
        ) from exc
    required = {
        (first or second).replace("\\", "/")
        for first, second in REQUIRED_RESOURCE.findall(text)
    }
    literals = {literal.replace("\\", "/") for literal in RES_LITERAL.findall(text)}
    return required, literals


def resource_edges(path: Path, excluded_authorities: set[str]) -> set[Path]:
    required, literals = resource_references(path)
    edges: set[Path] = set()
    for literal in sorted(required | literals):
        if not literal or literal.endswith("/") or "{" in literal:
            continue
        if literal in excluded_authorities:
            require(
                literal not in required,
                f"R10F_DEPENDENCY_REQUIRED_AUTHORITY_EXCLUDED:{relative_path(path)}:{literal}",
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
                "R10F_DEPENDENCY_REQUIRED_RESOURCE_UNRESOLVED:"
                f"{relative_path(path)}:{literal}"
            )
    return edges


def compose_gdscript_closure(
    direct_paths: Iterable[str], excluded_authorities: set[str]
) -> list[str]:
    queue = sorted(resolve_source(value) for value in direct_paths)
    discovered: set[Path] = set()
    while queue:
        current = queue.pop(0)
        if current in discovered:
            continue
        discovered.add(current)
        for edge in sorted(resource_edges(current, excluded_authorities)):
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
    require(result.returncode == 0, "R10F_DEPENDENCY_GIT_LS_FILES_FAILED")
    return set(result.stdout.splitlines())


def checkout_eol_attributes(paths: list[str]) -> dict[str, str]:
    result = subprocess.run(
        ("git", "-C", str(ROOT), "check-attr", "-z", "eol", "--", *paths),
        check=False,
        capture_output=True,
    )
    require(result.returncode == 0, "R10F_DEPENDENCY_GIT_CHECK_ATTR_FAILED")
    fields = result.stdout.decode("utf-8").split("\0")
    if fields and fields[-1] == "":
        fields.pop()
    require(len(fields) == len(paths) * 3, "R10F_DEPENDENCY_EOL_FIELD_COUNT")
    attributes: dict[str, str] = {}
    for index in range(0, len(fields), 3):
        path, attribute, value = fields[index : index + 3]
        require(attribute == "eol", "R10F_DEPENDENCY_EOL_ATTRIBUTE")
        require(path not in attributes, "R10F_DEPENDENCY_EOL_DUPLICATE")
        attributes[path] = value
    require(sorted(attributes) == paths, "R10F_DEPENDENCY_EOL_PATH_SET")
    return attributes


def mutation_controls(paths: list[str]) -> int:
    require(len(paths) >= 2, "R10F_DEPENDENCY_MUTATION_FIXTURE_TOO_SMALL")
    mutations = (
        paths[1:],
        sorted([*paths, "tests/undeclared_r10f_dependency.gd"]),
        [*reversed(paths)],
        [*paths, paths[-1]],
    )
    rejected = 0
    for mutation in mutations:
        try:
            assert_exact_set(paths, list(mutation), "R10F_DEPENDENCY_MUTATION")
        except ClosureFailure:
            rejected += 1
    require(rejected == len(mutations), "R10F_DEPENDENCY_MUTATION_ACCEPTED")
    return rejected


def local_python_import_closure(paths: Iterable[str]) -> list[str]:
    """Resolve campaign-local imports without importing or executing their code.

    Dynamic L15 test/script entrypoints are covered separately by the complete
    owned-file inventory. Standard-library and third-party modules belong to
    the separately qualified toolchain, not this local source population.
    """
    queue = sorted(path for path in paths if path.endswith(".py"))
    discovered: set[str] = set()
    while queue:
        relative = queue.pop(0)
        if relative in discovered:
            continue
        source = resolve_source(relative)
        discovered.add(relative)
        try:
            tree = ast.parse(source.read_text(encoding="utf-8"))
        except (SyntaxError, UnicodeError) as exc:
            raise ClosureFailure(f"R10F_DEPENDENCY_PYTHON_PARSE:{relative}") from exc
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names = [alias.name for alias in node.names]
            elif isinstance(node, ast.ImportFrom) and node.module:
                names = [node.module]
            else:
                continue
            for name in names:
                if not name.startswith(("qsdk_", "test_qsdk_")):
                    continue
                require(
                    not isinstance(node, ast.ImportFrom) or node.level == 0,
                    f"R10F_DEPENDENCY_RELATIVE_CAMPAIGN_IMPORT:{relative}:{name}",
                )
                candidates = {
                    (parent / (name.replace(".", "/") + ".py")).resolve()
                    for parent in (
                        source.parent,
                        ROOT / "sdk/conformance",
                        ROOT / "tests",
                        ROOT,
                    )
                    if (parent / (name.replace(".", "/") + ".py")).is_file()
                }
                require(
                    len(candidates) == 1,
                    f"R10F_DEPENDENCY_LOCAL_IMPORT_UNRESOLVED_OR_AMBIGUOUS:{relative}:{name}",
                )
                target = relative_path(next(iter(candidates)))
                if target not in discovered and target not in queue:
                    queue.append(target)
        queue.sort()
    return sorted(discovered)


def l15_source_population() -> dict[str, Any]:
    """Extend the immutable v19 roots; never refresh the observed manifest."""
    import qsdk_r10f_l15_collection_retention as packet

    raw = MANIFEST_PATH.read_bytes()
    require(
        len(raw) == L15_PREDECESSOR_MANIFEST["byte_length"]
        and "sha256:" + hashlib.sha256(raw).hexdigest()
        == L15_PREDECESSOR_MANIFEST["raw_sha256"],
        "R10F_L15_PREDECESSOR_MANIFEST_BYTES",
    )
    legacy = packet.parse_json(raw.decode("utf-8"))["policy"]
    owned = sorted(
        relative_path(path)
        for directory in L15_OWNED_DIRECTORIES
        for path in (ROOT / directory).glob("*r10f_l15*")
        if path.is_file() and path.suffix in LOCAL_SOURCE_SUFFIXES
    )
    direct = sorted(
        set(legacy["gdscript_direct_entry_paths"])
        | {path for path in owned if path.endswith(".gd")}
    )
    process = (
        set(legacy["process_and_audit_paths"])
        | {path for path in owned if not path.endswith(".gd")}
        | set(EXPECTED_RUNTIME_AUTHORITIES)
        | {
            L15_MANIFEST_PATH.relative_to(ROOT).as_posix(),
            "sdk/qsdk_r10f_development_route_ghost_physical_closure_v15.json",
        }
    )
    python_paths = local_python_import_closure(process)
    process.update(python_paths)
    return {
        "owned_source_directories": list(L15_OWNED_DIRECTORIES),
        "owned_source_paths": owned,
        "local_python_import_paths": python_paths,
        "gdscript_direct_entry_paths": direct,
        "process_and_audit_paths": sorted(process),
        "rust_build_paths": legacy["rust_build_paths"],
    }


def validate_l15_source_population(policy: Any, *, expected: dict[str, Any]) -> None:
    """Require the separately discovered population, not a self-declared set."""
    import qsdk_r10f_l15_collection_retention as packet

    require(type(policy) is dict, "R10F_DEPENDENCY_POLICY_NOT_OBJECT")
    for field, paths in expected.items():
        require(
            packet.same(policy.get(field), paths),
            "R10F_L15_SOURCE_POPULATION:" + field,
        )


def audit(
    *, require_tracked: bool, allow_unfinalized: bool, require_l15_sources: bool = False
) -> dict[str, Any]:
    require(type(require_l15_sources) is bool, "R10F_DEPENDENCY_L15_MODE_KIND")
    manifest_path = L15_MANIFEST_PATH if require_l15_sources else MANIFEST_PATH
    if require_l15_sources:
        import qsdk_r10f_l15_collection_retention as packet

        try:
            raw_manifest = manifest_path.read_bytes()
            manifest = packet.parse_json(raw_manifest.decode("utf-8"))
        except (ValueError, OSError, UnicodeError) as exc:
            raise ClosureFailure(f"R10F_L15_MANIFEST_UNREADABLE:{exc}") from exc
        require(type(manifest) is dict, "R10F_DEPENDENCY_MANIFEST_NOT_OBJECT")
    else:
        manifest = read_json(manifest_path)
    extra_keys = {"predecessor_manifest_binding"} if require_l15_sources else set()
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
        }
        | extra_keys,
        "R10F_DEPENDENCY_MANIFEST_KEYS",
    )
    require(
        manifest.get("schema_version")
        == (
            "sporespore_qsdk_r10f_dependency_manifest_v20"
            if require_l15_sources
            else SCHEMA_VERSION
        ),
        "R10F_DEPENDENCY_SCHEMA",
    )
    require(manifest.get("gate_id") == "QSDK-R10F", "R10F_DEPENDENCY_GATE")
    require(
        manifest.get("repair_id")
        == ("QSDK-R10F-L15" if require_l15_sources else "QSDK-R10F-L14"),
        "R10F_DEPENDENCY_REPAIR",
    )
    require(
        manifest.get("design_authority")
        == (
            "QSDK-R10F-L15-SOURCE-BOUND-LAUNCH-CANONICAL-OWNER-AND-SINGLE-PUBLICATION"
            if require_l15_sources
            else "QSDK-R10F-L14-terminal-boundaries-and-no-resume-addendum"
        ),
        "R10F_DEPENDENCY_DESIGN_AUTHORITY",
    )
    require(
        manifest.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "prospective_recursive_dependency_closure",
            "question_class": "development",
        },
        "R10F_DEPENDENCY_LEDGER_SCOPE",
    )
    policy = manifest.get("policy")
    claim = manifest.get("claim_boundary")
    require(isinstance(policy, dict), "R10F_DEPENDENCY_POLICY_NOT_OBJECT")
    require(isinstance(claim, dict), "R10F_DEPENDENCY_CLAIM_NOT_OBJECT")
    require(
        policy.get("policy_id")
        == (
            "qsdk_r10f_declared_roots_recursive_gdscript_and_rust_build_closure_v20"
            if require_l15_sources
            else POLICY_ID
        ),
        "R10F_DEPENDENCY_POLICY_ID",
    )
    l15_population: dict[str, Any] = {}
    if require_l15_sources:
        require(
            packet.same(
                manifest["predecessor_manifest_binding"], L15_PREDECESSOR_MANIFEST
            ),
            "R10F_L15_PREDECESSOR_MANIFEST_BINDING",
        )
        l15_population = l15_source_population()
        require(
            set(policy)
            == {
                "policy_id",
                "gdscript_direct_entry_paths",
                "expected_gdscript_transitive_paths",
                "rust_build_paths",
                "process_and_audit_paths",
                "prospective_runtime_authority_paths",
                "expected_qualified_source_count",
                "expected_qualified_source_path_sha256",
                "active_runtime_artifact_paths",
                "inactive_declared_runtime_artifact_paths",
                "owned_source_directories",
                "owned_source_paths",
                "local_python_import_paths",
            },
            "R10F_L15_POLICY_KEYS",
        )
        validate_l15_source_population(policy, expected=l15_population)
    direct = exact_string_list(
        policy.get("gdscript_direct_entry_paths"), "R10F_DEPENDENCY_DIRECT_PATHS"
    )
    expected_gdscript = exact_string_list(
        policy.get("expected_gdscript_transitive_paths"),
        "R10F_DEPENDENCY_GDSCRIPT_PATHS",
        allow_empty=allow_unfinalized,
    )
    rust = exact_string_list(
        policy.get("rust_build_paths"), "R10F_DEPENDENCY_RUST_PATHS"
    )
    process = exact_string_list(
        policy.get("process_and_audit_paths"), "R10F_DEPENDENCY_PROCESS_PATHS"
    )
    active_runtime = exact_string_list(
        policy.get("active_runtime_artifact_paths"),
        "R10F_DEPENDENCY_ACTIVE_RUNTIME_PATHS",
    )
    inactive_runtime = exact_string_list(
        policy.get("inactive_declared_runtime_artifact_paths"),
        "R10F_DEPENDENCY_INACTIVE_RUNTIME_PATHS",
    )
    runtime_authorities = exact_string_list(
        policy.get("prospective_runtime_authority_paths"),
        "R10F_DEPENDENCY_RUNTIME_AUTHORITY_PATHS",
    )
    require(
        runtime_authorities
        == (
            L15_RUNTIME_AUTHORITIES
            if require_l15_sources
            else EXPECTED_RUNTIME_AUTHORITIES
        ),
        "R10F_RUNTIME_AUTHORITIES",
    )
    require(
        active_runtime == ["sdk/target/debug/sporespore_godot_adapter.dll"]
        and inactive_runtime == ["sdk/target/release/sporespore_godot_adapter.dll"],
        "R10F_DEPENDENCY_RUNTIME_ARTIFACT_CLASSIFICATION",
    )

    discovered = compose_gdscript_closure(direct, set(runtime_authorities))
    finalized = (
        manifest.get("status")
        == "prospective_complete_transitive_source_closure_zero_world"
        and bool(expected_gdscript)
        and isinstance(policy.get("expected_qualified_source_count"), int)
        and policy.get("expected_qualified_source_count", 0) > 0
        and re.fullmatch(
            r"sha256:[0-9a-f]{64}",
            str(policy.get("expected_qualified_source_path_sha256", "")),
        )
        is not None
    )
    require(finalized or allow_unfinalized, "R10F_DEPENDENCY_MANIFEST_NOT_FINALIZED")
    if finalized:
        assert_exact_set(
            discovered, expected_gdscript, "R10F_DEPENDENCY_GDSCRIPT_CLOSURE"
        )
    else:
        require(
            manifest.get("status")
            == "prospective_unfinalized_transitive_source_closure_zero_world"
            and expected_gdscript == []
            and policy.get("expected_qualified_source_count") == 0
            and policy.get("expected_qualified_source_path_sha256") == "",
            "R10F_DEPENDENCY_UNFINALIZED_SENTINEL_DRIFT",
        )

    expected_core_rust = sorted(
        path.relative_to(ROOT).as_posix()
        for path in (ROOT / "sdk/core/src").rglob("*.rs")
        if path.is_file()
    )
    assert_exact_set(
        expected_core_rust,
        [path for path in rust if path.startswith("sdk/core/src/")],
        "R10F_DEPENDENCY_CORE_RUST_CLOSURE",
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
        "R10F_DEPENDENCY_NONCORE_RUST_BUILD_INPUTS",
    )
    qualified = sorted(set(discovered) | set(rust) | set(process))
    for relative in qualified:
        resolve_source(relative)
    if finalized:
        require(
            len(qualified) == policy.get("expected_qualified_source_count"),
            "R10F_DEPENDENCY_QUALIFIED_COUNT",
        )
        require(
            path_set_digest(qualified)
            == policy.get("expected_qualified_source_path_sha256"),
            "R10F_DEPENDENCY_QUALIFIED_PATH_DIGEST",
        )
    require(
        not (set(qualified) & (set(active_runtime) | set(inactive_runtime))),
        "R10F_DEPENDENCY_RUNTIME_MISCLASSIFIED_AS_SOURCE",
    )
    require(
        not (set(qualified) & set(runtime_authorities)),
        "R10F_DEPENDENCY_AUTHORITY_MISCLASSIFIED_AS_SOURCE",
    )
    eol = checkout_eol_attributes(qualified)
    non_lf_policy = {path: value for path, value in eol.items() if value != "lf"}
    require(
        not non_lf_policy,
        "R10F_DEPENDENCY_NON_LF_CHECKOUT_POLICY:"
        + json.dumps(non_lf_policy, sort_keys=True, separators=(",", ":")),
    )
    tracked = tracked_paths()
    if require_tracked:
        require(all(path in tracked for path in qualified), "R10F_DEPENDENCY_UNTRACKED")
    expected_claim = {
        "complete_transitive_local_gdscript_resource_closure_claimed": finalized,
        "complete_local_rust_build_input_closure_claimed": finalized,
        "cargo_registry_sources_identified_by_lockfile_not_copied_into_repository": True,
        "active_runtime_artifact_requires_separate_qualification_binding": True,
        "external_toolchain_requires_separate_qualification_binding": True,
        "prospective_runtime_authority_documents_excluded_from_source_closure": True,
        "superseded_pre_physics_supervisor_refusal_count": 2,
        "superseded_unconsumed_authorities_retired": True,
        "consumed_invalid_physical_closure_count": 12,
        "consumed_l13_physical_identity_preserved": True,
        "l14_original_design_and_branch_addendum_separately_required": True,
        "l14_walking_evaluator_version": 2,
        "l14_frozen_v1_evaluator_preserved": True,
        "l14_complete_no_resume_terminal_source_proof_required": True,
        "l14_additional_native_reads_or_solver_steps_permitted": False,
        "l14_incomplete_or_unhealthy_child_may_qualify_as_negative": False,
        "l14_m07_or_recovery_success_inferred_from_negative": False,
        "consumed_l2_physical_identity_preserved": True,
        "consumed_l3_physical_identity_preserved": True,
        "consumed_l4_physical_identity_preserved": True,
        "consumed_l5_physical_identity_preserved": True,
        "consumed_l6_physical_identity_preserved": True,
        "consumed_l7_physical_identity_preserved": True,
        "consumed_l8_physical_identity_preserved": True,
        "consumed_l9_physical_identity_preserved": True,
        "consumed_l10_physical_identity_preserved": True,
        "consumed_l11_physical_identity_preserved": True,
        "consumed_l12_physical_identity_preserved": True,
        "consumed_l13_official_zero_world_qualification_failure_preserved": True,
        "qualification_receipt_completeness_only_repair": True,
        "qualified_l13_source_retired_before_stage_preserved": True,
        "root_design_current_adapter_equals_historical_adapter_required": False,
        "root_design_historical_adapter_and_exact_l13_successor_separately_bound": True,
        "bootstrap_consumer_only_repair_preserved": True,
        "joint_geometry_consumer_only_repair_preserved": True,
        "joint_geometry_source_measurement_shape_changed": False,
        "joint_geometry_outcome_derived_correction": False,
        "collection_solver_counter_consumer_only_repair": True,
        "collection_solver_counter_source_measurement_shape_changed": False,
        "collection_solver_counter_cumulative_source_semantics_preserved": True,
        "collection_solver_counter_aggregate_step_delta": 1,
        "collection_solver_counter_outcome_derived_correction": False,
        "precondition_pair_barrier_only_repair": True,
        "precondition_solver_lockstep_preserved": True,
        "precondition_threshold_crossing_frame_lockstep_required": False,
        "precondition_terminal_sources_arm_local": True,
        "precondition_early_arm_wait_motors_disabled": True,
        "precondition_common_no_actuation_release_frame_count": 1,
        "precondition_behavioral_terms_changed": False,
        "precondition_outcome_derived_readiness": False,
        "precondition_terminal_disposition_retention_only_repair": True,
        "precondition_failed_arm_stops_without_peer_terminal": True,
        "precondition_terminal_disposition_both_arms_retained": True,
        "precondition_generic_terminal_frame_lockstep_label_permitted": False,
        "precondition_additional_solver_step_after_failure_permitted": False,
        "precondition_terminal_disposition_outcome_derived_correction": False,
        "integer_valued_native_step_domain_only_repair": True,
        "integer_valued_native_step_source_measurement_preserved": True,
        "integer_valued_native_step_source_rewrite_permitted": False,
        "integer_valued_native_step_fraction_permitted": False,
        "integer_valued_native_step_nonfinite_permitted": False,
        "integer_valued_native_step_minimum": 1,
        "integer_valued_native_step_maximum": 3842,
        "process_isolated_matched_arm_execution_only_repair": True,
        "one_arm_per_child_process": True,
        "one_world_per_child_process": True,
        "ordered_child_process_count": 2,
        "child_process_lifetimes_overlap": False,
        "child_retry_or_replacement_permitted": False,
        "world_or_body_state_transferred_between_children": False,
        "pair_alignment_uses_phase_local_source_receipts": True,
        "global_step_rewrite_for_pair_alignment_permitted": False,
        "pair_evaluator_positive_control_count": 3,
        "pair_evaluator_mutation_rejection_count": 35,
        "nullable_terminal_failure_code_consumer_only_repair": True,
        "nullable_terminal_failure_code_source_domain": ["null", "nonempty String"],
        "complete_terminal_failure_source_requires_null": True,
        "failed_or_refused_terminal_failure_source_requires_nonempty_string": True,
        "nullable_terminal_failure_code_nested_memory_preserved": True,
        "nullable_terminal_failure_code_generic_string_conversion_permitted": False,
        "nullable_terminal_failure_code_receipt_schema_changed": False,
        "nullable_terminal_failure_code_positive_control_count": 7,
        "nullable_terminal_failure_code_mutation_rejection_count": 17,
        "precondition_release_owner_source_projection_only_repair": True,
        "precondition_release_full_terminal_receipt_retained": True,
        "precondition_release_full_recovery_step_receipt_retained": True,
        "precondition_release_broad_outcome_guard_changed": False,
        "precondition_release_receipt_schema_advanced": True,
        "precondition_release_terminal_receipt_schema_changed": False,
        "precondition_release_interaction_source_schema_changed": False,
        "precondition_release_owner_source_positive_control_count": 9,
        "precondition_release_owner_source_mutation_rejection_count": 23,
        "walking_actuation_handoff_only_repair": True,
        "walking_actuation_handoff_evaluation_segments": [
            "walking_prefix",
            "matched_continuation",
            "walking_resume",
        ],
        "walking_actuation_handoff_precommand_motor_enable_count": 8,
        "walking_actuation_handoff_precommand_zero_target_count": 8,
        "walking_actuation_handoff_extra_solver_step_count": 0,
        "walking_host_cap_projection_count": 8,
        "walking_host_cap_existing_r69_projection_reused": True,
        "walking_host_cap_override_complete": True,
        "walking_shared_adapter_enable_behavior_changed": False,
        "walking_published_cap_profile_changed": False,
        "walking_new_tolerance_or_margin_added": False,
        "walking_actuation_handoff_positive_control_count": 5,
        "walking_actuation_handoff_mutation_rejection_count": 22,
        "walking_ledger_transport_projection_failure_retention_only_repair": True,
        "walking_native_preparse_transport_verification_required": True,
        "walking_raw_native_step_response_rewritten": False,
        "walking_postparse_controller_receipt_rehash_is_authority": False,
        "walking_native_transport_verification_contains_floating_measurements": False,
        "walking_binary32_host_target_projection_count": 8,
        "walking_controller_binary64_target_retained_separately": True,
        "walking_expected_binary32_host_target_retained_separately": True,
        "walking_host_target_projection_rule": (
            "float(PackedFloat32Array([controller_target_velocity_rad_s])[0])"
        ),
        "walking_application_readback_equals_binary32_projection_exactly": True,
        "walking_population_readback_equals_binary32_projection_exactly": True,
        "walking_controller_command_rounded_before_write": False,
        "walking_host_write_changed": False,
        "walking_solver_input_changed": False,
        "walking_named_predicate_receipt_required": True,
        "walking_failed_step_sources_retained": True,
        "walking_additional_native_readback": False,
        "walking_additional_solver_step": False,
        "walking_l13_positive_control_count": 15,
        "walking_l13_mutation_group_count": 16,
        "walking_failure_retention_positive_control_count": 1,
        "walking_failure_retention_mutation_rejection_count": 15,
        "walking_production_fixture_segment_count": 3,
        "walking_detached_hinge_parameter_container_count": 24,
        "walking_controller_caps_thresholds_schedule_changed": False,
        "maximum_solver_steps_per_arm": 3842,
        "maximum_total_solver_steps": 7684,
        "r10e_l3_finite_negative_preserved": True,
        "r172_exact_nominal_positive_preserved": True,
        "r173_three_engine_prone_to_standing_preserved": True,
        "r10f_event_triggered_passive_not_force_aware": True,
        "r10f_behavior_observed": False,
        "l14_exact_selected_runtime_images_required": True,
        "l14_selected_runtime_image_count": 5,
        "l14_current_images_reopened_before_qualification_and_each_child": True,
        "l14_retained_runtime_record_required_by_physical_closer": True,
        "l14_whole_operating_system_image_snapshot_claimed": False,
        "l14_passed_qualification_8a05eddb_preserved_and_retired_before_stage": True,
        "l14_actual_producer_to_qualification_directory_reader_control_required": True,
        "l14_old_qualification_may_be_adopted_by_changed_source": False,
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
    if require_l15_sources:
        expected_claim.update(
            {
                "consumed_invalid_physical_closure_count": 13,
                "consumed_l14_physical_identity_preserved": True,
                "l15_all_owned_source_paths_enumerated": True,
                "l15_local_campaign_python_import_closure_checked": True,
                "l15_dynamic_entrypoints_covered_by_owned_source_inventory": True,
                "l15_component_rollup_is_not_complete_implementation_qualification": True,
                "l15_complete_wrapper_directory_and_context_origin_handoff_required": True,
                "l15_new_physical_question_declared_here": False,
                "l15_official_qualification_executed_here": False,
                "physical_execution_authorized": False,
            }
        )
        require(packet.same(claim, expected_claim), "R10F_DEPENDENCY_CLAIM_BOUNDARY")
    else:
        require(claim == expected_claim, "R10F_DEPENDENCY_CLAIM_BOUNDARY")
    active_artifact = ROOT / active_runtime[0]
    require(active_artifact.is_file(), "R10F_DEPENDENCY_ACTIVE_RUNTIME_MISSING")
    return {
        "schema_version": "sporespore_qsdk_r10f_dependency_closure_zero_world_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L15" if require_l15_sources else "QSDK-R10F-L14",
        **(
            {
                "manifest_path": L15_MANIFEST_PATH.relative_to(ROOT).as_posix(),
                "manifest_raw_sha256": "sha256:"
                + hashlib.sha256(raw_manifest).hexdigest(),
                "manifest_byte_length": len(raw_manifest),
                "predecessor_manifest_binding": dict(L15_PREDECESSOR_MANIFEST),
                "l15_owned_source_path_count": len(
                    l15_population["owned_source_paths"]
                ),
                "l15_local_python_import_path_count": len(
                    l15_population["local_python_import_paths"]
                ),
                "official_qualification_executed_here": False,
                "physical_execution_authorized": False,
            }
            if require_l15_sources
            else {}
        ),
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_recursive_dependency_closure",
            "question_class": "development",
        },
        "ok": True,
        "qualification_finalized": finalized,
        "gdscript_direct_entry_count": len(direct),
        "gdscript_transitive_path_count": len(discovered),
        "gdscript_transitive_paths": discovered,
        "rust_build_path_count": len(rust),
        "process_and_audit_path_count": len(process),
        "prospective_runtime_authority_path_count": len(runtime_authorities),
        "qualified_source_path_count": len(qualified),
        "qualified_source_path_sha256": path_set_digest(qualified),
        "qualified_source_paths": qualified,
        "active_runtime_artifact_path": active_runtime[0],
        "active_runtime_artifact_raw_sha256": "sha256:"
        + hashlib.sha256(active_artifact.read_bytes()).hexdigest(),
        "active_runtime_artifact_byte_length": active_artifact.stat().st_size,
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
    parser.add_argument("--require-l15-sources", action="store_true")
    arguments = parser.parse_args()
    try:
        receipt = audit(
            require_tracked=arguments.require_tracked,
            allow_unfinalized=arguments.allow_unfinalized or arguments.discover,
            require_l15_sources=arguments.require_l15_sources,
        )
    except ClosureFailure as exc:
        print(f"QSDK_R10F_DEPENDENCY_CLOSURE_FAIL {exc}", file=sys.stderr)
        return 1
    marker = DISCOVERY_MARKER if arguments.discover else PASS_MARKER
    print(marker + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
