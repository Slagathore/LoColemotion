"""Compile the public SporeSpore SDK versioning V0-V6 report."""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
import re
import subprocess
import sys
import tomllib
import warnings
from pathlib import Path
from typing import Any, Callable

try:
    from sporespore_locomotion import (
        ABI_GENERATION,
        SDK_VERSION,
        LocomotionCore,
    )
except ImportError:
    from python.sporespore_locomotion import (
        ABI_GENERATION,
        SDK_VERSION,
        LocomotionCore,
    )

from adapter_kit.reference_adapter import ReferenceHostAdapter

from .migrations import (
    LEGACY_BALANCED_WAVE_POLICY_ID,
    SchemaMigrationError,
    load_schema_registry,
    migrate_record,
)


VERSIONING_ROOT = Path(__file__).resolve().parent
SDK_ROOT = VERSIONING_ROOT.parent
REPO_ROOT = SDK_ROOT.parent
POLICY_PATH = VERSIONING_ROOT / "compatibility_policy_v1.json"
ABI_MANIFEST_PATH = VERSIONING_ROOT / "c_abi_manifest_v1.json"
SCHEMA_REGISTRY_PATH = VERSIONING_ROOT / "schema_registry_v1.json"
DEPRECATION_REGISTRY_PATH = (
    VERSIONING_ROOT / "deprecation_registry_v1.json"
)
HEADER_PATH = SDK_ROOT / "include" / "sporespore_locomotion.h"
REPORT_SCHEMA = "sporespore_sdk_versioning_conformance_report_v1"


class VersioningConformanceError(RuntimeError):
    """A failed public compatibility conformance cell."""


def _require(condition: bool, code: str, detail: str = "") -> None:
    if not condition:
        raise VersioningConformanceError(f"{code}:{detail}")


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise VersioningConformanceError(
            f"VERSIONING_JSON_INVALID:{path}:{error}"
        ) from error
    _require(
        isinstance(value, dict),
        "VERSIONING_JSON_NOT_OBJECT",
        str(path),
    )
    return value


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
        "status",
        "--porcelain=v1",
        "--untracked-files=all",
    )
    return {
        "commit": head if head_ok else None,
        "origin_main": origin if origin_ok else None,
        "clean": status_ok and status == "",
        "matches_origin_main": head_ok and origin_ok and head == origin,
        "status_entries": status.splitlines() if status else [],
    }


def _semver(value: str) -> tuple[int, int, int]:
    match = re.fullmatch(
        r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)",
        value,
    )
    _require(match is not None, "VERSIONING_SEMVER_INVALID", value)
    assert match is not None
    return tuple(int(group) for group in match.groups())


def _load_policy() -> dict[str, Any]:
    policy = _read_json(POLICY_PATH)
    _require(
        policy.get("schema_version")
        == "sporespore_sdk_compatibility_policy_v1",
        "VERSIONING_POLICY_SCHEMA_INVALID",
    )
    _require(
        policy.get("sdk_version") == SDK_VERSION
        and policy.get("abi_generation") == ABI_GENERATION,
        "VERSIONING_POLICY_IDENTITY_MISMATCH",
    )
    return policy


def _load_abi_manifest() -> dict[str, Any]:
    manifest = _read_json(ABI_MANIFEST_PATH)
    _require(
        manifest.get("schema_version") == "sporespore_c_abi_manifest_v1",
        "VERSIONING_ABI_MANIFEST_SCHEMA_INVALID",
    )
    symbols = manifest.get("symbols")
    _require(
        isinstance(symbols, list)
        and all(isinstance(entry, dict) for entry in symbols),
        "VERSIONING_ABI_SYMBOLS_INVALID",
    )
    names = [entry.get("name") for entry in symbols]
    _require(
        len(names) == len(set(names))
        and all(isinstance(name, str) and name for name in names),
        "VERSIONING_ABI_SYMBOL_NAMES_INVALID",
    )
    return manifest


def _load_deprecations() -> dict[str, Any]:
    registry = _read_json(DEPRECATION_REGISTRY_PATH)
    _require(
        registry.get("schema_version")
        == "sporespore_sdk_deprecation_registry_v1",
        "VERSIONING_DEPRECATION_SCHEMA_INVALID",
    )
    items = registry.get("items")
    _require(
        isinstance(items, list)
        and all(isinstance(entry, dict) for entry in items),
        "VERSIONING_DEPRECATION_ITEMS_INVALID",
    )
    identities = [
        (entry.get("surface_kind"), entry.get("surface_id"))
        for entry in items
    ]
    _require(
        len(identities) == len(set(identities)),
        "VERSIONING_DEPRECATION_DUPLICATE",
    )
    return registry


def _cell_v0_policy() -> dict[str, Any]:
    policy = _load_policy()
    _require(
        policy["release_version_rules"]["patch_release"][
            "may_break_active_public_c_abi"
        ]
        is False,
        "VERSIONING_PATCH_BREAK_ALLOWED",
    )
    _require(
        policy["schema_rules"]["implicit_cross_version_coercion_allowed"]
        is False
        and policy["schema_rules"][
            "breaking_record_change_requires_new_schema_id"
        ]
        is True,
        "VERSIONING_SCHEMA_POLICY_WEAK",
    )
    _require(
        all(
            value is False
            for value in policy["authority_boundary"].values()
        ),
        "VERSIONING_POLICY_AUTHORITY_ESCALATION",
    )
    return {
        "cell_id": "v0_compatibility_policy",
        "passed": True,
        "sdk_version": policy["sdk_version"],
        "abi_generation": policy["abi_generation"],
        "version_tuple": list(_semver(policy["sdk_version"])),
        "policy_file_sha256": _file_sha256(POLICY_PATH),
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cargo_package_version(path: Path) -> str:
    with path.open("rb") as stream:
        document = tomllib.load(stream)
    package = document.get("package")
    _require(
        isinstance(package, dict)
        and isinstance(package.get("version"), str),
        "VERSIONING_CARGO_PACKAGE_VERSION_MISSING",
        str(path),
    )
    return package["version"]


def _cell_v1_version_lockstep(core: LocomotionCore) -> dict[str, Any]:
    paths = [
        SDK_ROOT / "core" / "Cargo.toml",
        SDK_ROOT / "adapters" / "godot" / "Cargo.toml",
        SDK_ROOT / "adapters" / "rapier" / "Cargo.toml",
    ]
    cargo_versions = {
        str(path.relative_to(REPO_ROOT)).replace("\\", "/"):
        _cargo_package_version(path)
        for path in paths
    }
    header = HEADER_PATH.read_text(encoding="utf-8")
    version_match = re.search(
        r'#define\s+SS_SDK_VERSION\s+"([^"]+)"',
        header,
    )
    abi_match = re.search(
        r"#define\s+SS_ABI_GENERATION\s+([0-9]+)",
        header,
    )
    _require(
        version_match is not None and abi_match is not None,
        "VERSIONING_HEADER_IDENTITY_MISSING",
    )
    assert version_match is not None and abi_match is not None
    observed_versions = set(cargo_versions.values()) | {
        SDK_VERSION,
        core.version,
        version_match.group(1),
        _load_policy()["sdk_version"],
        _load_abi_manifest()["sdk_version"],
        _read_json(
            SDK_ROOT / "adapter_kit" / "adapter_contract_v1.json"
        )["sdk_version"],
    }
    _require(
        observed_versions == {"0.1.0"},
        "VERSIONING_COMPONENT_VERSION_DRIFT",
        str(sorted(observed_versions)),
    )
    _require(
        int(abi_match.group(1)) == ABI_GENERATION == 1,
        "VERSIONING_ABI_GENERATION_DRIFT",
    )
    rust_library_source = (
        SDK_ROOT / "core" / "src" / "lib.rs"
    ).read_text(encoding="utf-8")
    _require(
        re.search(
            r"pub\s+const\s+SDK_ABI_GENERATION:\s*u32\s*=\s*1\s*;",
            rust_library_source,
        )
        is not None,
        "VERSIONING_RUST_ABI_GENERATION_DRIFT",
    )
    return {
        "cell_id": "v1_version_lockstep",
        "passed": True,
        "sdk_version": SDK_VERSION,
        "abi_generation": ABI_GENERATION,
        "cargo_versions": cargo_versions,
        "runtime_core_version": core.version,
        "header_version": version_match.group(1),
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_v2_c_abi(core: LocomotionCore) -> dict[str, Any]:
    manifest = _load_abi_manifest()
    header = HEADER_PATH.read_text(encoding="utf-8")
    header_symbols = sorted(
        set(re.findall(r"\b(ss_[a-z0-9_]+)\s*\(", header))
    )
    manifest_symbols = sorted(
        entry["name"] for entry in manifest["symbols"]
    )
    _require(
        header_symbols == manifest_symbols,
        "VERSIONING_ABI_HEADER_MANIFEST_MISMATCH",
        f"header={header_symbols} manifest={manifest_symbols}",
    )
    expected_discriminants = manifest["status_discriminants"]
    for name, value in expected_discriminants.items():
        _require(
            re.search(rf"\b{re.escape(name)}\s*=\s*{value}\b", header)
            is not None,
            "VERSIONING_STATUS_DISCRIMINANT_DRIFT",
            name,
        )
    signature_patterns = {
        "version_static_utf8_v1": (
            r"SS_API\s+const\s+char\s+\*\s*{name}\s*"
            r"\(\s*void\s*\)\s*;"
        ),
        "json_input_buffer_v1": (
            r"SS_API\s+ss_status\s+{name}\s*\(\s*"
            r"const\s+uint8_t\s+\*input\s*,\s*"
            r"size_t\s+input_length\s*,\s*"
            r"uint8_t\s+\*output\s*,\s*"
            r"size_t\s+output_capacity\s*,\s*"
            r"size_t\s+\*output_length\s*\)\s*;"
        ),
        "json_output_buffer_v1": (
            r"SS_API\s+ss_status\s+{name}\s*\(\s*"
            r"uint8_t\s+\*output\s*,\s*"
            r"size_t\s+output_capacity\s*,\s*"
            r"size_t\s+\*output_length\s*\)\s*;"
        ),
        "controller_session_create_json_v1": (
            r"SS_API\s+ss_status\s+{name}\s*\(\s*"
            r"const\s+uint8_t\s+\*input\s*,\s*"
            r"size_t\s+input_length\s*,\s*"
            r"uint64_t\s+\*session_handle\s*\)\s*;"
        ),
        "controller_session_step_json_v1": (
            r"SS_API\s+ss_status\s+{name}\s*\(\s*"
            r"uint64_t\s+session_handle\s*,\s*"
            r"const\s+uint8_t\s+\*input\s*,\s*"
            r"size_t\s+input_length\s*,\s*"
            r"uint8_t\s+\*output\s*,\s*"
            r"size_t\s+output_capacity\s*,\s*"
            r"size_t\s+\*output_length\s*\)\s*;"
        ),
        "controller_session_destroy_v1": (
            r"SS_API\s+ss_status\s+{name}\s*\(\s*"
            r"uint64_t\s+session_handle\s*\)\s*;"
        ),
    }
    for entry in manifest["symbols"]:
        signature_class = entry["signature_class"]
        _require(
            signature_class in signature_patterns,
            "VERSIONING_ABI_SIGNATURE_CLASS_UNKNOWN",
            signature_class,
        )
        pattern = signature_patterns[signature_class].format(
            name=re.escape(entry["name"])
        )
        _require(
            re.search(pattern, header, flags=re.MULTILINE) is not None,
            "VERSIONING_ABI_SIGNATURE_DRIFT",
            entry["name"],
        )
    library = ctypes.CDLL(str(core.library_path))
    unresolved = [
        name for name in manifest_symbols if not hasattr(library, name)
    ]
    _require(
        not unresolved,
        "VERSIONING_ABI_SYMBOL_UNRESOLVED",
        ",".join(unresolved),
    )
    return {
        "cell_id": "v2_c_abi_manifest",
        "passed": True,
        "symbol_count": len(manifest_symbols),
        "resolved_symbol_count": len(manifest_symbols),
        "unresolved_symbols": unresolved,
        "abi_manifest_sha256": _file_sha256(ABI_MANIFEST_PATH),
        "header_sha256": _file_sha256(HEADER_PATH),
        "library_sha256": _file_sha256(core.library_path),
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_v3_schema_registry() -> dict[str, Any]:
    registry = load_schema_registry()
    abi = _load_abi_manifest()
    schema_entries = {
        entry["schema_id"]: entry for entry in registry["schemas"]
    }
    abi_inputs = sorted(
        {
            entry["input_schema"]
            for entry in abi["symbols"]
            if entry.get("input_schema") is not None
        }
    )
    missing = [
        schema_id for schema_id in abi_inputs
        if schema_id not in schema_entries
    ]
    _require(
        not missing,
        "VERSIONING_PUBLIC_INPUT_SCHEMA_UNREGISTERED",
        ",".join(missing),
    )
    migration_ids = [
        entry["migration_id"] for entry in registry["migrations"]
    ]
    for migration in registry["migrations"]:
        _require(
            migration["source_schema"] in schema_entries
            and migration["target_schema"] in schema_entries
            and migration["source_schema"]
            != migration["target_schema"],
            "VERSIONING_MIGRATION_REGISTRY_INVALID",
            migration["migration_id"],
        )
    return {
        "cell_id": "v3_schema_registry",
        "passed": True,
        "registered_schema_count": len(schema_entries),
        "public_abi_input_schema_count": len(abi_inputs),
        "unregistered_public_inputs": missing,
        "registered_migration_ids": migration_ids,
        "schema_registry_sha256": _file_sha256(SCHEMA_REGISTRY_PATH),
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_v4_semantic_migration(
    core: LocomotionCore,
) -> dict[str, Any]:
    adapter = ReferenceHostAdapter(core)
    legacy_request = adapter.build_step_request(0)
    legacy_request["schema_version"] = (
        "sporespore_balanced_wave_step_request_v1"
    )
    legacy_output = core.balanced_wave_step(legacy_request)
    receipt = migrate_record(
        legacy_request,
        "sporespore_balanced_wave_policy_step_request_v1",
        core=core,
    )
    migrated = receipt["migrated_record"]
    named_output = core.balanced_wave_policy_step(
        migrated["policy_id"],
        migrated,
    )
    _require(
        migrated["policy_id"] == LEGACY_BALANCED_WAVE_POLICY_ID,
        "VERSIONING_MIGRATION_POLICY_SUBSTITUTED",
    )
    _require(
        legacy_output == named_output,
        "VERSIONING_MIGRATION_SEMANTICS_DRIFT",
    )
    _require(
        legacy_output["actuation"]["receipt"]["policy_id"]
        == LEGACY_BALANCED_WAVE_POLICY_ID,
        "VERSIONING_LEGACY_POLICY_IDENTITY_DRIFT",
    )
    return {
        "cell_id": "v4_semantic_migration",
        "passed": True,
        "migration_path": receipt["migration_path"],
        "source_schema": receipt["source_schema_version"],
        "target_schema": receipt["target_schema_version"],
        "preserved_policy_id": LEGACY_BALANCED_WAVE_POLICY_ID,
        "legacy_and_named_outputs_equal": True,
        "source_sha256": receipt["source_sha256"],
        "target_sha256": receipt["target_sha256"],
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _cell_v5_deprecations(core: LocomotionCore) -> dict[str, Any]:
    deprecations = _load_deprecations()
    abi = _load_abi_manifest()
    schemas = load_schema_registry()
    abi_by_name = {
        entry["name"]: entry for entry in abi["symbols"]
    }
    schema_by_id = {
        entry["schema_id"]: entry for entry in schemas["schemas"]
    }
    deprecated_abi = {
        name
        for name, entry in abi_by_name.items()
        if entry["status"] == "deprecated"
    }
    registered_abi = {
        entry["surface_id"]
        for entry in deprecations["items"]
        if entry["surface_kind"] == "c_abi_symbol"
    }
    _require(
        deprecated_abi == registered_abi,
        "VERSIONING_DEPRECATED_ABI_REGISTRY_MISMATCH",
    )
    for entry in deprecations["items"]:
        _require(
            entry["status"] == "deprecated"
            and _semver(entry["not_before_removal_version"])
            >= (0, 3, 0)
            and isinstance(entry.get("replacement"), str)
            and entry["replacement"],
            "VERSIONING_DEPRECATION_NOTICE_INVALID",
            entry["surface_id"],
        )
        surface_kind = entry["surface_kind"]
        if surface_kind == "c_abi_symbol":
            _require(
                entry["replacement"] in abi_by_name
                and abi_by_name[entry["replacement"]]["status"]
                == "active",
                "VERSIONING_ABI_REPLACEMENT_INVALID",
                entry["surface_id"],
            )
        elif surface_kind == "json_schema":
            _require(
                entry["surface_id"] in schema_by_id
                and schema_by_id[entry["surface_id"]]["status"]
                == "deprecated"
                and entry["replacement"] in schema_by_id,
                "VERSIONING_SCHEMA_REPLACEMENT_INVALID",
                entry["surface_id"],
            )
        elif surface_kind == "python_method":
            _require(
                hasattr(LocomotionCore, entry["surface_id"])
                and hasattr(LocomotionCore, entry["replacement"]),
                "VERSIONING_PYTHON_REPLACEMENT_INVALID",
                entry["surface_id"],
            )
        else:
            raise VersioningConformanceError(
                "VERSIONING_DEPRECATION_SURFACE_KIND_INVALID:"
                + str(surface_kind)
            )
    _require(
        deprecations["removed_items"] == [],
        "VERSIONING_UNEXPECTED_REMOVAL",
    )
    adapter = ReferenceHostAdapter(core)
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always", DeprecationWarning)
        core.balanced_wave_profile(adapter.descriptor)
    deprecation_warnings = [
        warning
        for warning in caught
        if issubclass(warning.category, DeprecationWarning)
    ]
    _require(
        len(deprecation_warnings) == 1
        and "balanced_wave_policy_profile"
        in str(deprecation_warnings[0].message),
        "VERSIONING_PYTHON_DEPRECATION_WARNING_MISSING",
    )
    return {
        "cell_id": "v5_deprecation_registry",
        "passed": True,
        "deprecated_abi_symbol_count": len(deprecated_abi),
        "deprecated_schema_count": sum(
            1
            for entry in deprecations["items"]
            if entry["surface_kind"] == "json_schema"
        ),
        "deprecated_python_method_count": sum(
            1
            for entry in deprecations["items"]
            if entry["surface_kind"] == "python_method"
        ),
        "python_deprecation_warning_count": len(
            deprecation_warnings
        ),
        "removed_item_count": 0,
        "deprecation_registry_sha256": _file_sha256(
            DEPRECATION_REGISTRY_PATH
        ),
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _expect_migration_failure(
    callback: Callable[[], object],
    failure_code: str,
) -> str:
    try:
        callback()
    except SchemaMigrationError as error:
        _require(
            error.failure_code == failure_code,
            "VERSIONING_NEGATIVE_FAILURE_CODE_MISMATCH",
            f"expected={failure_code} actual={error.failure_code}",
        )
        return error.failure_code
    raise VersioningConformanceError(
        f"VERSIONING_NEGATIVE_PATH_ACCEPTED:{failure_code}"
    )


def _cell_v6_negative_paths(core: LocomotionCore) -> dict[str, Any]:
    adapter = ReferenceHostAdapter(core)
    legacy_request = adapter.build_step_request(0)
    legacy_request["schema_version"] = (
        "sporespore_balanced_wave_step_request_v1"
    )
    unknown_target = _expect_migration_failure(
        lambda: migrate_record(
            legacy_request,
            "sporespore_unknown_schema_v1",
            core=core,
        ),
        "MIGRATION_TARGET_SCHEMA_UNKNOWN",
    )
    unavailable = _expect_migration_failure(
        lambda: migrate_record(
            {
                "schema_version": (
                    "sporespore_canonical_json_request_v1"
                ),
                "value": {},
            },
            "sporespore_bounded_quadruped_descriptor_v1",
            core=core,
        ),
        "MIGRATION_UNAVAILABLE",
    )
    malformed = dict(legacy_request)
    malformed["unknown"] = True
    unknown_field = _expect_migration_failure(
        lambda: migrate_record(
            malformed,
            "sporespore_balanced_wave_policy_step_request_v1",
            core=core,
        ),
        "MIGRATION_SOURCE_FIELDS_INVALID",
    )
    identity = _expect_migration_failure(
        lambda: migrate_record(
            legacy_request,
            "sporespore_balanced_wave_step_request_v1",
            core=core,
        ),
        "MIGRATION_NOT_REQUIRED",
    )
    return {
        "cell_id": "v6_negative_paths",
        "passed": True,
        "unknown_target_failure_code": unknown_target,
        "unavailable_migration_failure_code": unavailable,
        "unknown_field_failure_code": unknown_field,
        "identity_migration_failure_code": identity,
        "implicit_coercion_used": False,
        "world_build_count": 0,
        "walking_acceptance": False,
        "physical_acceptance_authority": False,
        "completed_engine_neutral_sdk": False,
    }


def run_versioning_conformance() -> dict[str, Any]:
    core = LocomotionCore()
    cells = [
        _cell_v0_policy(),
        _cell_v1_version_lockstep(core),
        _cell_v2_c_abi(core),
        _cell_v3_schema_registry(),
        _cell_v4_semantic_migration(core),
        _cell_v5_deprecations(core),
        _cell_v6_negative_paths(core),
    ]
    return {
        "schema_version": REPORT_SCHEMA,
        "ok": True,
        "sdk_version": SDK_VERSION,
        "abi_generation": ABI_GENERATION,
        "source": _source_receipt(),
        "core": {
            "version": core.version,
            "library_path_execution_only": str(core.library_path),
            "library_sha256": _file_sha256(core.library_path),
        },
        "policy_file_sha256": _file_sha256(POLICY_PATH),
        "abi_manifest_sha256": _file_sha256(ABI_MANIFEST_PATH),
        "schema_registry_sha256": _file_sha256(SCHEMA_REGISTRY_PATH),
        "deprecation_registry_sha256": _file_sha256(
            DEPRECATION_REGISTRY_PATH
        ),
        "cells": cells,
        "passed_cells": len(cells),
        "failed_cells": 0,
        "public_versioning_policy": True,
        "public_abi_manifest": True,
        "public_schema_migration": True,
        "public_deprecation_registry": True,
        "world_build_count": 0,
        "release_ready": False,
        "package_authorized": False,
        "publication_authorized": False,
        "walking_acceptance": False,
        "physical_acceptance_authority": False,
        "completed_engine_neutral_sdk": False,
    }


def _retain_report(report: dict[str, Any], path: Path) -> None:
    _require(path.name == "report.json", "VERSIONING_REPORT_NAME_INVALID")
    _require(
        not path.exists(),
        "VERSIONING_REPORT_ALREADY_EXISTS",
        str(path),
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name("report.json.tmp")
    _require(
        not temporary.exists(),
        "VERSIONING_REPORT_TEMPORARY_EXISTS",
        str(temporary),
    )
    payload = json.dumps(report, indent=2, allow_nan=False) + "\n"
    temporary.write_text(payload, encoding="utf-8", newline="\n")
    os.replace(temporary, path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        report = run_versioning_conformance()
        if args.output is not None:
            output = args.output.resolve()
            _retain_report(report, output)
            print(
                f"retained versioning report: {output}",
                file=sys.stderr,
            )
        print(json.dumps(report, indent=2, allow_nan=False))
    except (
        OSError,
        SchemaMigrationError,
        ValueError,
        VersioningConformanceError,
    ) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
