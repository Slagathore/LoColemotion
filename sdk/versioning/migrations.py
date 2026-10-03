"""Strict, receipt-bearing migrations for public SporeSpore JSON records."""

from __future__ import annotations

import argparse
import copy
import json
import os
import sys
from pathlib import Path
from typing import Any, Mapping

try:
    from sporespore_locomotion import LocomotionCore
except ImportError:
    try:
        from python.sporespore_locomotion import LocomotionCore
    except ImportError:
        from sdk.python.sporespore_locomotion import LocomotionCore


VERSIONING_ROOT = Path(__file__).resolve().parent
SCHEMA_REGISTRY_PATH = VERSIONING_ROOT / "schema_registry_v1.json"
MIGRATION_RECEIPT_SCHEMA = "sporespore_schema_migration_receipt_v1"
LEGACY_BALANCED_WAVE_POLICY_ID = "sporespore_balanced_wave_v1"


class SchemaMigrationError(RuntimeError):
    """A typed refusal to perform an undeclared or malformed migration."""

    def __init__(self, failure_code: str, detail: str) -> None:
        super().__init__(f"{failure_code}:{detail}")
        self.failure_code = failure_code
        self.detail = detail


def _require(condition: bool, failure_code: str, detail: str = "") -> None:
    if not condition:
        raise SchemaMigrationError(failure_code, detail)


def _read_json_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SchemaMigrationError(
            "MIGRATION_REGISTRY_INVALID",
            f"{path}:{error}",
        ) from error
    _require(
        isinstance(value, dict),
        "MIGRATION_REGISTRY_NOT_OBJECT",
        str(path),
    )
    return value


def load_schema_registry() -> dict[str, Any]:
    """Load and minimally validate the frozen public schema registry."""

    registry = _read_json_object(SCHEMA_REGISTRY_PATH)
    _require(
        registry.get("schema_version")
        == "sporespore_sdk_schema_registry_v1",
        "MIGRATION_REGISTRY_SCHEMA_INVALID",
    )
    schemas = registry.get("schemas")
    migrations = registry.get("migrations")
    _require(
        isinstance(schemas, list)
        and isinstance(migrations, list)
        and all(isinstance(entry, dict) for entry in schemas + migrations),
        "MIGRATION_REGISTRY_CONTENT_INVALID",
    )
    schema_ids = [entry.get("schema_id") for entry in schemas]
    _require(
        len(schema_ids) == len(set(schema_ids))
        and all(isinstance(value, str) and value for value in schema_ids),
        "MIGRATION_REGISTRY_SCHEMA_IDS_INVALID",
    )
    migration_ids = [entry.get("migration_id") for entry in migrations]
    _require(
        len(migration_ids) == len(set(migration_ids))
        and all(isinstance(value, str) and value for value in migration_ids),
        "MIGRATION_REGISTRY_MIGRATION_IDS_INVALID",
    )
    return registry


def _balanced_wave_legacy_step_to_named_policy(
    source: Mapping[str, Any],
    migration: Mapping[str, Any],
) -> dict[str, Any]:
    required = set(migration["source_required_fields"])
    _require(
        set(source) == required,
        "MIGRATION_SOURCE_FIELDS_INVALID",
        f"actual={sorted(source)} expected={sorted(required)}",
    )
    target = copy.deepcopy(dict(source))
    target["schema_version"] = migration["target_schema"]
    target["policy_id"] = LEGACY_BALANCED_WAVE_POLICY_ID
    return target


def migrate_record(
    record: Mapping[str, Any],
    target_schema_version: str,
    *,
    core: LocomotionCore | None = None,
) -> dict[str, Any]:
    """Migrate one exact public record or fail closed with a typed error.

    Cross-version migration occurs only when the frozen schema registry names
    an exact transform. Same-schema input is refused because migration is not
    a substitute for validating that schema.
    """

    _require(
        isinstance(record, Mapping),
        "MIGRATION_SOURCE_NOT_OBJECT",
    )
    source = copy.deepcopy(dict(record))
    source_schema = source.get("schema_version")
    _require(
        isinstance(source_schema, str) and source_schema,
        "MIGRATION_SOURCE_SCHEMA_MISSING",
    )
    _require(
        isinstance(target_schema_version, str) and target_schema_version,
        "MIGRATION_TARGET_SCHEMA_MISSING",
    )
    registry = load_schema_registry()
    registered_schemas = {
        entry["schema_id"] for entry in registry["schemas"]
    }
    _require(
        source_schema in registered_schemas,
        "MIGRATION_SOURCE_SCHEMA_UNKNOWN",
        source_schema,
    )
    _require(
        target_schema_version in registered_schemas,
        "MIGRATION_TARGET_SCHEMA_UNKNOWN",
        target_schema_version,
    )

    _require(
        source_schema != target_schema_version,
        "MIGRATION_NOT_REQUIRED",
        source_schema,
    )
    matches = [
        entry
        for entry in registry["migrations"]
        if entry.get("source_schema") == source_schema
        and entry.get("target_schema") == target_schema_version
    ]
    _require(
        len(matches) == 1,
        "MIGRATION_UNAVAILABLE",
        f"{source_schema}->{target_schema_version}",
    )
    migration = matches[0]
    transform = migration.get("transform")
    _require(
        transform == "inject_explicit_legacy_bw2_a_policy_identity",
        "MIGRATION_TRANSFORM_UNKNOWN",
        str(transform),
    )
    migrated = _balanced_wave_legacy_step_to_named_policy(
        source,
        migration,
    )
    migration_path = [migration["migration_id"]]
    semantic_scope = migration["semantic_equivalence_scope"]

    active_core = core if core is not None else LocomotionCore()
    source_digest = active_core.canonicalize_json(source)["sha256"]
    target_digest = active_core.canonicalize_json(migrated)["sha256"]
    return {
        "schema_version": MIGRATION_RECEIPT_SCHEMA,
        "source_schema_version": source_schema,
        "target_schema_version": target_schema_version,
        "migration_path": migration_path,
        "source_sha256": source_digest,
        "target_sha256": target_digest,
        "migrated_record": migrated,
        "semantic_equivalence_scope": semantic_scope,
        "implicit_coercion_used": False,
        "world_build_count": 0,
        "walking_acceptance": False,
        "physical_acceptance_authority": False,
        "completed_engine_neutral_sdk": False,
    }


def _retain_json(value: Mapping[str, Any], path: Path) -> None:
    _require(path.name == "migration.json", "MIGRATION_OUTPUT_NAME_INVALID")
    _require(not path.exists(), "MIGRATION_OUTPUT_ALREADY_EXISTS", str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name("migration.json.tmp")
    _require(
        not temporary.exists(),
        "MIGRATION_OUTPUT_TEMPORARY_EXISTS",
        str(temporary),
    )
    payload = json.dumps(value, indent=2, allow_nan=False) + "\n"
    temporary.write_text(payload, encoding="utf-8", newline="\n")
    os.replace(temporary, path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--target-schema", required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        source = _read_json_object(args.input.resolve())
        receipt = migrate_record(source, args.target_schema)
        if args.output is not None:
            output = args.output.resolve()
            _retain_json(receipt, output)
            print(f"retained schema migration: {output}", file=sys.stderr)
        print(json.dumps(receipt, indent=2, allow_nan=False))
    except (SchemaMigrationError, OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
