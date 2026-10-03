"""Deterministic, fail-closed source dependency closure for QSDK-R23D65.

R23D65 uses the recursive discovery layer first qualified by R23D60 and
extends it across the matched Godot/Jolt, Rapier/Parry, and MuJoCo routes.  A campaign contract declares its direct entry
points and whole-source prefixes; this module recursively discovers local
Python imports, GDScript resource loads, and static PowerShell script/file
references.  The discovered set must exactly equal the contract's frozen
expected path set before it can be used as physical-freeze authority.

This module never constructs a model or physics world.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Iterable, Mapping, Sequence


SCHEMA_VERSION = "sporespore_qsdk_r23d65_dependency_inventory_v1"
POLICY_ID = "r23d65_declared_roots_recursive_local_language_closure_v1"
CONTRACT_SCHEMA = "sporespore_qsdk_r23d65_selected_profile_three_engine_turning_validation_implementation_v1"
REPOSITORY_REMOTE = "https://github.com/Slagathore/sporespore.git"
SOURCE_SUFFIXES = {
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
REPO_PREFIXES = ("sdk/", "tests/", "scripts/", "addons/", "docs/")
RES_LITERAL = re.compile(r"res://([^\"'\s)\],}]+)")
GDSCRIPT_LOAD = re.compile(r"\b(?:preload|load)\s*\(\s*[\"']res://([^\"']+)[\"']\s*\)")
GDSCRIPT_EXTENDS = re.compile(r"\bextends\s+[\"']res://([^\"']+)[\"']")
POWERSHELL_STRING = re.compile(
    r"'((?:[^']|'')*)'|\"((?:[^\"`]|`.)*)\"",
    re.MULTILINE,
)


class DependencyClosureError(RuntimeError):
    """The declared dependency closure is incomplete or internally invalid."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise DependencyClosureError(code)


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _canonical_json_sha256(value: Any) -> str:
    raw = json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _relative(repo_root: Path, path: Path) -> str:
    try:
        relative = path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as error:
        raise DependencyClosureError(
            f"R23D65_DEPENDENCY_ESCAPES_REPOSITORY:{path}"
        ) from error
    _require(relative not in {"", "."}, "R23D65_DEPENDENCY_REPOSITORY_ROOT")
    return relative


def _resolve_declared_path(repo_root: Path, value: Any) -> Path:
    _require(
        isinstance(value, str) and value == value.strip() and value,
        "R23D65_DEPENDENCY_PATH_INVALID",
    )
    _require(
        "\\" not in value and not Path(value).is_absolute(),
        f"R23D65_DEPENDENCY_PATH_NOT_CANONICAL:{value}",
    )
    target = (repo_root / value).resolve()
    _relative(repo_root, target)
    _require(target.is_file(), f"R23D65_DEPENDENCY_MISSING:{value}")
    return target


def _git(repo_root: Path, *arguments: str) -> str:
    process = subprocess.run(
        ["git", "-C", str(repo_root), *arguments],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if process.returncode != 0:
        raise DependencyClosureError(
            "R23D65_DEPENDENCY_GIT_FAILURE:"
            + " ".join(arguments)
            + ":"
            + process.stderr.strip()
        )
    return process.stdout.strip()


def _resolve_python_candidate(
    repo_root: Path,
    current: Path,
    module_parts: Sequence[str],
    search_roots: Sequence[Path],
    *,
    relative_level: int = 0,
) -> list[Path]:
    if relative_level:
        anchor = current.parent
        for _ in range(relative_level - 1):
            anchor = anchor.parent
        roots = [anchor]
    else:
        roots = [current.parent, *search_roots]
    candidates: list[Path] = []
    for root in roots:
        base = root.joinpath(*module_parts) if module_parts else root
        for candidate in (base.with_suffix(".py"), base / "__init__.py"):
            if candidate.is_file():
                resolved = candidate.resolve()
                _relative(repo_root, resolved)
                if resolved not in candidates:
                    candidates.append(resolved)
    return candidates


def _python_edges(
    repo_root: Path,
    path: Path,
    search_roots: Sequence[Path],
) -> tuple[set[Path], set[str]]:
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except (OSError, UnicodeError, SyntaxError) as error:
        raise DependencyClosureError(
            f"R23D65_DEPENDENCY_PYTHON_PARSE:{_relative(repo_root, path)}:{type(error).__name__}"
        ) from error
    local: set[Path] = set()
    external: set[str] = set()
    for node in ast.walk(tree):
        requests: list[tuple[tuple[str, ...], int]] = []
        top_level_names: set[str] = set()
        if isinstance(node, ast.Import):
            for alias in node.names:
                requests.append((tuple(alias.name.split(".")), 0))
                top_level_names.add(alias.name.split(".")[0])
        elif isinstance(node, ast.ImportFrom):
            base = tuple((node.module or "").split(".")) if node.module else ()
            requests.append((base, node.level))
            for alias in node.names:
                if alias.name != "*":
                    requests.append((base + tuple(alias.name.split(".")), node.level))
            top_level_names.add(base[0] if base else "relative")
        else:
            continue
        resolved_any = False
        for parts, level in requests:
            candidates = _resolve_python_candidate(
                repo_root,
                path,
                parts,
                search_roots,
                relative_level=level,
            )
            _require(
                len(candidates) <= 1,
                "R23D65_DEPENDENCY_PYTHON_IMPORT_AMBIGUOUS:"
                + _relative(repo_root, path)
                + ":"
                + ".".join(parts),
            )
            if candidates:
                local.add(candidates[0])
                resolved_any = True
        if not resolved_any:
            external.update(top_level_names)
    return local, external


def assert_expected_path_set(
    discovered_paths: Sequence[str], expected_paths: Sequence[str]
) -> None:
    """Require the exact sorted finite closure; used by production and canaries."""

    _require(
        list(expected_paths) == sorted(set(expected_paths)),
        "R23D65_DEPENDENCY_EXPECTED_PATH_ORDER",
    )
    missing = sorted(set(discovered_paths) - set(expected_paths))
    surplus = sorted(set(expected_paths) - set(discovered_paths))
    if missing or surplus:
        raise DependencyClosureError(
            "R23D65_DEPENDENCY_EXPECTED_SET_MISMATCH:"
            + json.dumps(
                {
                    "discovered_not_declared": missing,
                    "declared_not_discovered": surplus,
                },
                separators=(",", ":"),
                sort_keys=True,
            )
        )


def assert_receipt_closure(
    ordered_paths: Sequence[str], receipts: Sequence[Mapping[str, Any]]
) -> None:
    """Prove one unique well-formed byte receipt for every dependency path."""

    observed: dict[str, str] = {}
    for receipt in receipts:
        _require(isinstance(receipt, Mapping), "R23D65_DEPENDENCY_RECEIPT_SHAPE")
        path = receipt.get("path")
        digest = receipt.get("raw_sha256")
        _require(
            isinstance(path, str)
            and path not in observed
            and isinstance(digest, str)
            and re.fullmatch(r"sha256:[0-9a-f]{64}", digest) is not None,
            "R23D65_DEPENDENCY_RECEIPT_IDENTITY",
        )
        observed[path] = digest
    _require(
        list(observed) == list(ordered_paths),
        "R23D65_DEPENDENCY_RECEIPT_CLOSURE",
    )


def _resource_edges(repo_root: Path, path: Path, text: str) -> set[Path]:
    edges: set[Path] = set()
    # ``--script`` runs the declared SceneTree worker and does not instantiate
    # the editor main scene or icon from project.godot.  The project file itself
    # is a direct frozen input; following those UI-only references would make a
    # locomotion result depend on unrelated editor code.
    if path.name == "project.godot":
        return edges
    required_literals = set(GDSCRIPT_LOAD.findall(text)) | set(
        GDSCRIPT_EXTENDS.findall(text)
    )
    all_literals = set(RES_LITERAL.findall(text))
    for literal in sorted(all_literals | required_literals):
        normalized = literal.replace("\\", "/")
        if not normalized or normalized.endswith("/") or "{" in normalized:
            continue
        target = (repo_root / normalized).resolve()
        if target.is_file():
            # Native libraries are runtime artifacts, not source.  The R23D65
            # supervisor binds the one actually loaded debug adapter separately
            # with its reproducible build receipt and raw digest.
            if target.suffix.lower() in {".dll", ".dylib", ".exe", ".so"}:
                continue
            _relative(repo_root, target)
            edges.add(target)
        elif literal in required_literals:
            raise DependencyClosureError(
                f"R23D65_DEPENDENCY_GDSCRIPT_RESOURCE_UNRESOLVED:{_relative(repo_root, path)}:{literal}"
            )
    return edges


def _powershell_strings(text: str) -> Iterable[str]:
    for match in POWERSHELL_STRING.finditer(text):
        if match.group(1) is not None:
            yield match.group(1).replace("''", "'")
        else:
            value = match.group(2)
            value = re.sub(r"`(.)", r"\1", value)
            yield value


def _powershell_edges(repo_root: Path, path: Path, text: str) -> set[Path]:
    """Resolve dot-sourced modules; subprocess entries are contract-declared.

    Treating every file-looking string in a shared PowerShell module as an
    executed dependency pulls in dormant functions and eventually the whole
    conformance catalog.  Dot-sourcing really does load the referenced module,
    so it is recursive here.  R23D65 subprocess entry points are separately
    explicit in ``powershell_subprocess_paths_by_entry`` and are added by the
    composer below.
    """

    edges: set[Path] = set()
    bases = {
        "PSScriptRoot": path.parent,
        "repoRoot": repo_root,
        "sdkRoot": repo_root / "sdk",
        "turningRoot": repo_root / "sdk" / "turning",
    }
    variables: dict[str, Path] = {}
    assignment = re.compile(r"\$(\w+)\s*=\s*Join-Path\s+\$(\w+)\s+[\"']([^\"']+)[\"']")
    for match in assignment.finditer(text):
        name, base_name, literal = match.groups()
        base = bases.get(base_name) or variables.get(base_name)
        if base is not None:
            variables[name] = (base / literal.replace("\\", "/")).resolve()

    direct_variable = re.compile(r"(?m)^\s*\.\s+\$(\w+)\s*(?:#.*)?$")
    for match in direct_variable.finditer(text):
        candidate = variables.get(match.group(1))
        if candidate is not None and candidate.is_file():
            _relative(repo_root, candidate)
            edges.add(candidate)

    join_source = re.compile(
        r"(?m)^\s*\.\s*\(\s*Join-Path\s+\$(\w+)\s+[\"']([^\"']+)[\"']\s*\)"
    )
    for match in join_source.finditer(text):
        base_name, literal = match.groups()
        base = bases.get(base_name) or variables.get(base_name)
        if base is None:
            continue
        candidate = (base / literal.replace("\\", "/")).resolve()
        if candidate.is_file():
            _relative(repo_root, candidate)
            edges.add(candidate)
    return edges


def _scan_edges(
    repo_root: Path,
    path: Path,
    search_roots: Sequence[Path],
) -> tuple[set[Path], set[str]]:
    suffix = path.suffix.lower()
    if suffix == ".py":
        return _python_edges(repo_root, path, search_roots)
    if suffix not in {".gd", ".gdextension", ".godot", ".ps1", ".tscn", ".tres"}:
        return set(), set()
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        raise DependencyClosureError(
            f"R23D65_DEPENDENCY_TEXT_UNREADABLE:{_relative(repo_root, path)}:{type(error).__name__}"
        ) from error
    if suffix == ".ps1":
        return _powershell_edges(repo_root, path, text), set()
    return _resource_edges(repo_root, path, text), set()


def _contract_value(contract_path: Path) -> dict[str, Any]:
    try:
        value = json.loads(contract_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise DependencyClosureError(
            f"R23D65_DEPENDENCY_CONTRACT_UNREADABLE:{type(error).__name__}"
        ) from error
    _require(isinstance(value, dict), "R23D65_DEPENDENCY_CONTRACT_SHAPE")
    _require(
        value.get("schema_version") == CONTRACT_SCHEMA,
        "R23D65_DEPENDENCY_CONTRACT_SCHEMA",
    )
    return value


def compose_inventory(
    *,
    repo_root: Path,
    contract_path: Path,
    require_expected_paths: bool = True,
    require_clean_git_bytes: bool = False,
) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    contract_path = contract_path.resolve()
    _require(repo_root.is_dir(), "R23D65_DEPENDENCY_REPOSITORY_MISSING")
    _require(
        contract_path.is_file() and contract_path.is_relative_to(repo_root),
        "R23D65_DEPENDENCY_CONTRACT_PATH_INVALID",
    )
    contract = _contract_value(contract_path)
    policy = contract.get("dependency_closure", {})
    _require(isinstance(policy, dict), "R23D65_DEPENDENCY_POLICY_SHAPE")
    _require(policy.get("policy_id") == POLICY_ID, "R23D65_DEPENDENCY_POLICY_ID")
    direct_values = policy.get("direct_entry_paths")
    prefix_values = policy.get("whole_source_prefixes")
    prefix_exclusion_values = policy.get("whole_source_prefix_exclusions", [])
    search_values = policy.get("python_local_search_roots")
    expected_values = policy.get("expected_transitive_paths")
    subprocess_values = policy.get("powershell_subprocess_paths_by_entry")
    _require(
        isinstance(direct_values, list) and direct_values,
        "R23D65_DEPENDENCY_DIRECT_ROOTS",
    )
    _require(isinstance(prefix_values, list), "R23D65_DEPENDENCY_PREFIXES")
    _require(
        isinstance(prefix_exclusion_values, list),
        "R23D65_DEPENDENCY_PREFIX_EXCLUSIONS",
    )
    _require(
        isinstance(search_values, list) and search_values,
        "R23D65_DEPENDENCY_SEARCH_ROOTS",
    )
    _require(
        isinstance(subprocess_values, dict),
        "R23D65_DEPENDENCY_POWERSHELL_SUBPROCESS_MAP",
    )
    _require(
        not require_expected_paths or isinstance(expected_values, list),
        "R23D65_DEPENDENCY_EXPECTED_PATHS_REQUIRED",
    )

    search_roots: list[Path] = []
    for value in search_values:
        _require(
            isinstance(value, str) and value and "\\" not in value,
            "R23D65_DEPENDENCY_SEARCH_ROOT_INVALID",
        )
        root = (repo_root / value).resolve()
        _relative(repo_root, root / "sentinel")
        _require(root.is_dir(), f"R23D65_DEPENDENCY_SEARCH_ROOT_MISSING:{value}")
        search_roots.append(root)

    roots: set[Path] = {
        _resolve_declared_path(repo_root, value) for value in direct_values
    }
    explicit_subprocess_edges: dict[str, set[Path]] = {}
    for source_value, targets_value in subprocess_values.items():
        source = _resolve_declared_path(repo_root, source_value)
        _require(
            source.suffix.lower() == ".ps1"
            and isinstance(targets_value, list)
            and targets_value,
            "R23D65_DEPENDENCY_POWERSHELL_SUBPROCESS_ENTRY",
        )
        targets = {
            _resolve_declared_path(repo_root, target_value)
            for target_value in targets_value
        }
        _require(
            len(targets) == len(targets_value),
            "R23D65_DEPENDENCY_POWERSHELL_SUBPROCESS_DUPLICATE",
        )
        explicit_subprocess_edges[_relative(repo_root, source)] = targets
        roots.add(source)
    normalized_exclusions: list[str] = []
    for exclusion_value in prefix_exclusion_values:
        _require(
            isinstance(exclusion_value, str)
            and exclusion_value.endswith("/")
            and "\\" not in exclusion_value
            and not Path(exclusion_value).is_absolute(),
            "R23D65_DEPENDENCY_PREFIX_EXCLUSION_INVALID",
        )
        _require(
            any(exclusion_value.startswith(prefix) for prefix in prefix_values),
            f"R23D65_DEPENDENCY_PREFIX_EXCLUSION_OUTSIDE_ROOT:{exclusion_value}",
        )
        normalized_exclusions.append(exclusion_value)
    _require(
        normalized_exclusions == sorted(set(normalized_exclusions)),
        "R23D65_DEPENDENCY_PREFIX_EXCLUSION_ORDER",
    )

    for prefix_value in prefix_values:
        _require(
            isinstance(prefix_value, str)
            and prefix_value.endswith("/")
            and "\\" not in prefix_value
            and not Path(prefix_value).is_absolute(),
            "R23D65_DEPENDENCY_PREFIX_INVALID",
        )
        prefix = (repo_root / prefix_value).resolve()
        _relative(repo_root, prefix / "sentinel")
        _require(prefix.is_dir(), f"R23D65_DEPENDENCY_PREFIX_MISSING:{prefix_value}")
        expanded = [
            item.resolve()
            for item in prefix.rglob("*")
            if item.is_file()
            and not any(
                _relative(repo_root, item).startswith(exclusion)
                for exclusion in normalized_exclusions
            )
        ]
        _require(expanded, f"R23D65_DEPENDENCY_PREFIX_EMPTY:{prefix_value}")
        roots.update(expanded)

    queue = sorted(roots, key=lambda item: _relative(repo_root, item))
    discovered: set[Path] = set()
    graph: dict[str, list[str]] = {}
    external_imports: set[str] = set()
    while queue:
        current = queue.pop(0)
        if current in discovered:
            continue
        discovered.add(current)
        edges, external = _scan_edges(repo_root, current, search_roots)
        edges.update(
            explicit_subprocess_edges.get(_relative(repo_root, current), set())
        )
        external_imports.update(external)
        current_relative = _relative(repo_root, current)
        graph[current_relative] = sorted(_relative(repo_root, edge) for edge in edges)
        for edge in sorted(edges, key=lambda item: _relative(repo_root, item)):
            if edge not in discovered and edge not in queue:
                queue.append(edge)
        queue.sort(key=lambda item: _relative(repo_root, item))

    paths = sorted(_relative(repo_root, item) for item in discovered)
    _require(
        set(explicit_subprocess_edges).issubset(paths),
        "R23D65_DEPENDENCY_POWERSHELL_SUBPROCESS_SOURCE_UNREACHED",
    )
    _require(len(paths) == len(set(paths)), "R23D65_DEPENDENCY_DUPLICATE")
    if require_expected_paths and isinstance(expected_values, list):
        _require(
            all(isinstance(item, str) for item in expected_values),
            "R23D65_DEPENDENCY_EXPECTED_PATH_SHAPE",
        )
        assert_expected_path_set(paths, expected_values)

    tracked = set(_git(repo_root, "ls-files").splitlines())
    if require_expected_paths:
        _require(
            all(path in tracked for path in paths),
            "R23D65_DEPENDENCY_UNTRACKED_OR_CASE_MISMATCH",
        )
    receipts: list[dict[str, Any]] = []
    for relative in paths:
        absolute = repo_root / relative
        receipt: dict[str, Any] = {
            "path": relative,
            "raw_sha256": _raw_sha256(absolute),
        }
        if require_clean_git_bytes:
            blob = _git(repo_root, "rev-parse", f"HEAD:{relative}")
            checkout = _git(repo_root, "hash-object", "--no-filters", "--", relative)
            _require(
                blob == checkout, f"R23D65_DEPENDENCY_CHECKOUT_BLOB_MISMATCH:{relative}"
            )
            receipt.update(
                git_blob_oid=blob,
                raw_checkout_equals_git_blob=True,
            )
        receipts.append(receipt)
    assert_receipt_closure(paths, receipts)

    graph_edges = [
        {"from": source, "to": target}
        for source in sorted(graph)
        for target in graph[source]
    ]
    projection = {
        "policy_id": POLICY_ID,
        "ordered_direct_entry_paths": sorted(
            _relative(repo_root, item) for item in roots
        ),
        "ordered_whole_source_prefix_exclusions": normalized_exclusions,
        "ordered_transitive_paths": paths,
        "ordered_edges": graph_edges,
        "ordered_external_python_import_roots": sorted(external_imports),
    }
    projection_sha256 = _canonical_json_sha256(projection)
    expected_projection_sha256 = policy.get("expected_inventory_projection_sha256")
    if require_expected_paths:
        _require(
            isinstance(expected_projection_sha256, str)
            and re.fullmatch(r"sha256:[0-9a-f]{64}", expected_projection_sha256)
            is not None,
            "R23D65_DEPENDENCY_EXPECTED_PROJECTION_REQUIRED",
        )
        _require(
            expected_projection_sha256 == projection_sha256,
            "R23D65_DEPENDENCY_PROJECTION_MISMATCH",
        )
    return {
        "schema_version": SCHEMA_VERSION,
        "campaign_id": contract.get("campaign_id"),
        "gate_id": contract.get("gate_id"),
        "policy_id": POLICY_ID,
        "contract_path": _relative(repo_root, contract_path),
        "contract_raw_sha256": _raw_sha256(contract_path),
        "direct_entry_count": len(roots),
        "transitive_path_count": len(paths),
        "edge_count": len(graph_edges),
        "ordered_paths": paths,
        "ordered_edges": graph_edges,
        "ordered_external_python_import_roots": sorted(external_imports),
        "source_receipts": receipts,
        "inventory_projection_sha256": projection_sha256,
        "recursive_local_python_import_inventory_complete": True,
        "recursive_gdscript_preload_and_load_inventory_complete": True,
        "powershell_static_dot_source_and_subprocess_path_inventory_complete": True,
        "whole_source_prefix_exclusions_exact": True,
        "declaration_bound_source_inventory_complete": True,
        "expected_transitive_path_set_exact": (
            require_expected_paths and isinstance(expected_values, list)
        ),
        "all_paths_tracked_with_exact_case": all(path in tracked for path in paths),
        "checkout_bytes_equal_git_blobs": require_clean_git_bytes,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--discovery-only", action="store_true")
    parser.add_argument("--require-clean-git-bytes", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        value = compose_inventory(
            repo_root=args.repo_root,
            contract_path=args.contract,
            require_expected_paths=not args.discovery_only,
            require_clean_git_bytes=args.require_clean_git_bytes,
        )
        print(
            "QSDK_R23D65_DEPENDENCY_INVENTORY "
            + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 0
    except (
        DependencyClosureError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
    ) as error:
        print(f"QSDK_R23D65_DEPENDENCY_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
